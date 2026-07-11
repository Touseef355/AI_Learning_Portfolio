import os
import uuid
import base64
import math
from decimal import Decimal
from django.utils import timezone
from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db import transaction
from django.db.models import Q, Sum
from django.conf import settings

from .models import AiLog, CameraAPIKey
from parking.models import Vehicle,ParkingSlot
from parking.pricing import calculate_amount
from bookings.models import Booking, ParkingPass
from payments.models import Payment
from sps_backend.events import emit
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync


# ── Gate-side booking lookup ─────────────────────────────────────────────
# Ek prepaid booking jo abhi gate tak nahi pohnchi normally "confirmed"
# hoti hai. Lekin agar payment kisi aise flow se aayi jo status flip karna
# bhool gaya (dekho payments.PaymentView fix), booking "pending_payment" +
# payment_status="paid" pe atki reh sakti hai. Gate ko dono ko booking
# manna chahiye — warna paid customer walk-in ban jata hai.
GATE_BOOKING_Q = Q(status="confirmed") | Q(
    status="pending_payment", payment_status="paid"
)


def find_gate_booking(vehicle, site=None):
    """Booking jo entry gate pe honour honi chahiye. Site-scoped by
    default; earliest booked window pehle (agar user ke paas multiple
    upcoming bookings hon to aaj wali pakri jaye, future wali nahi)."""
    qs = Booking.objects.filter(GATE_BOOKING_Q, vehicle=vehicle)
    if site is not None:
        qs = qs.filter(parking_slot__parking_site=site)
    return qs.order_by("entry_time").first()


def booking_paid_amount(booking):
    """Booking ke against ab tak successfully pay hua total (booking +
    extension payments; refunds/topups excluded). Fallback: agar
    payment_status 'paid' hai lekin Payment rows nahi mili (koi legacy
    flow), to booked-window ka estimated_amount hi paid maan lo."""
    total = Payment.objects.filter(
        booking=booking,
        status="success",
        payment_type="booking",
    ).aggregate(s=Sum("amount"))["s"] or Decimal("0")

    if total == 0 and booking.payment_status == "paid":
        total = booking.estimated_amount or Decimal("0")
    return float(total)


# Pending entry log itni der tak slot hold kar sakta hai — uske baad usko
# stale maan kar reservation chhor di jati hai. (Camera ke re-detections /
# OCR misreads har variant pe naya pending log + naya reserved slot bana
# dete the aur wo kabhi release nahi hota tha → jhoota "Parking Full".)
def _slot_for_entry_log(entry_log):
    """Walk-in exit pricing ke liye slot: walk-in booking ka slot, warna
    entry ke waqt assign hua slot — taake VIP/Disabled slot me khari
    walk-in car bhi usi slot ke rate se charge ho."""
    if entry_log is None:
        return None
    if entry_log.booking and entry_log.booking.parking_slot_id:
        return entry_log.booking.parking_slot
    if entry_log.assigned_slot and entry_log.parking_site_id:
        return ParkingSlot.objects.filter(
            parking_site_id=entry_log.parking_site_id,
            slot_number=entry_log.assigned_slot,
        ).first()
    return None


STALE_ENTRY_LOG_MINUTES = 15


def release_stale_entry_reservations(site):
    """Purane pending ENTRY logs ko reject-mark karo aur unke reserve kiye
    hue walk-in slots free karo. Sirf wohi slots chhoro jo occupied nahi
    hain aur jin par koi live booking/pass reservation nahi hai."""
    cutoff = timezone.now() - timezone.timedelta(minutes=STALE_ENTRY_LOG_MINUTES)
    stale = AiLog.objects.filter(
        parking_site=site,
        log_type="entry",
        status="pending",
        detected_at__lt=cutoff,
    )
    slot_numbers = [s for s in stale.values_list("assigned_slot", flat=True) if s]
    if not slot_numbers and not stale.exists():
        return

    if slot_numbers:
        # Booking/pass ke reserve kiye slots ko haath mat lagao.
        protected = set(
            Booking.objects.filter(
                GATE_BOOKING_Q | Q(status="active"),
                parking_slot__parking_site=site,
                parking_slot__slot_number__in=slot_numbers,
            ).values_list("parking_slot__slot_number", flat=True)
        ) | set(
            ParkingPass.objects.filter(
                status="active",
                parking_slot__parking_site=site,
                parking_slot__slot_number__in=slot_numbers,
            ).values_list("parking_slot__slot_number", flat=True)
        )
        releasable = [s for s in slot_numbers if s not in protected]
        if releasable:
            ParkingSlot.objects.filter(
                parking_site=site,
                slot_number__in=releasable,
                is_occupied=False,
            ).update(is_reserved=False)
            emit("slots.changed", site_id=site.id)

    stale.update(status="rejected")


VALID_SLOT_TYPES = ("normal", "vip", "disabled")


def clean_slot_type(value, default="normal"):
    """Cashier ke dropdown se aaya slot_type validate karo."""
    v = (value or "").strip().lower()
    return v if v in VALID_SLOT_TYPES else default


def reserve_walkin_slot(site, slot_type="normal"):
    """Walk-in ke liye REQUESTED TYPE ka free slot reserve karo.
    Pehle koi bhi random slot (VIP/disabled samet) utha lia jata tha —
    ab type-scoped pick hai, deterministic order me."""
    slot = ParkingSlot.objects.select_for_update().filter(
        parking_site=site,
        slot_type=slot_type,
        is_occupied=False,
        is_reserved=False,
    ).order_by("slot_number").first()
    if slot:
        slot.is_reserved = True
        slot.save()
        return slot.slot_number
    return None


def verify_api_key(request):
    """Return the CameraAPIKey (site samet) ya None. Key hi batati hai
    ke detection KIS SITE ke gate se aayi — multi-site isolation ki
    bunyaad."""
    api_key = request.headers.get("X-API-Key")
    if not api_key:
        return None
    try:
        return CameraAPIKey.objects.select_related("parking_site").get(
            key=api_key, is_active=True)
    except CameraAPIKey.DoesNotExist:
        return None


def _scope_ailogs(qs, user):
    """AiLog queryset ko user ki visibility tak scope karo:
    admin sab, owner apni sites, cashier apni site, baqi kuch nahi."""
    role = getattr(user, "role", "user")
    if role == "admin":
        return qs
    if role == "parking_owner":
        return qs.filter(parking_site__owner=user)
    if getattr(user, "site_id", None):
        return qs.filter(parking_site_id=user.site_id)
    return qs.none()


def _forbid_cross_site(user, ai_log):
    """Approve/reject se pehle: kya yeh event is user ki site ka hai?
    Response (403) return karta hai agar nahi, warna None."""
    role = getattr(user, "role", "user")
    if role == "admin":
        return None
    sid = ai_log.parking_site_id
    if sid is None:
        return None  # legacy log (site-binding se pehle ka)
    if role == "parking_owner":
        from parking.models import ParkingSite
        if ParkingSite.objects.filter(id=sid, owner=user).exists():
            return None
    elif getattr(user, "site_id", None) == sid:
        return None
    return Response(
        {"error": "This event belongs to another site"},
        status=status.HTTP_403_FORBIDDEN,
    )


def save_image(image_base64, plate_number, prefix="detected"):
    if not image_base64:
        return ""
    detected_dir = os.path.join(settings.MEDIA_ROOT, "detected")
    os.makedirs(detected_dir, exist_ok=True)

    # SECURITY FIX: plate filename me jata hai — "../" ya "/" wale input se
    # file MEDIA_ROOT ke bahar likhi ja sakti thi. Sirf safe chars rakho.
    clean_plate = "".join(
        c if (c.isalnum() or c in "-_") else "_" for c in (plate_number or "")
    )[:32] or "unknown"

    filename   = f"{prefix}_{clean_plate}_{uuid.uuid4()}.jpg"
    filepath   = os.path.join(detected_dir, filename)
    image_data = base64.b64decode(image_base64)
    with open(filepath, "wb") as f:
        f.write(image_data)
    return filename

class EntryView(APIView):
    permission_classes = []

    def post(self, request):
        camera = verify_api_key(request)
        if camera is None:
            return Response(
                {"error": "Invalid API Key"},
                status=status.HTTP_401_UNAUTHORIZED
            )
        site = camera.parking_site
        if site is None:
            return Response(
                {"error": "Camera key is not bound to a parking site. "
                          "Assign parking_site to this CameraAPIKey."},
                status=status.HTTP_403_FORBIDDEN
            )

        plate_number   = request.data.get("plate_number")
        confidence     = request.data.get("confidence", 0.0)
        vehicle_type   = request.data.get("vehicle_type", "car")
        gate           = request.data.get("gate", "Entry Gate")
        image_base64   = request.data.get("image")
        cropped_base64 = request.data.get("cropped_plate")

        if not plate_number:
            return Response(
                {"error": "No plate number detected"},
                status=status.HTTP_400_BAD_REQUEST
            )

        
        plate_number = plate_number.upper()

        filename         = save_image(image_base64, plate_number, prefix="detected")
        cropped_filename = save_image(cropped_base64, plate_number, prefix="cropped")

        # FIX (jhoota "Parking Full"): pehle stale pending entry logs ki
        # reservations chhoro — camera ke duplicate detections / OCR
        # misread variants slots hold karke pool khali kar dete the.
        release_stale_entry_reservations(site)

        # Already inside check
        last_log = AiLog.objects.filter(
            parking_site=site,
            detected_plate_number=plate_number
        ).order_by("-detected_at").first()

        if last_log and last_log.log_type == "entry" and last_log.status == "approved":
            return Response({
                "status" : "already_inside",
                "message": "Vehicle already inside parking"
            }, status=status.HTTP_400_BAD_REQUEST)

        # FIX: exit-side jaisa dedupe entry pe missing tha — same plate ka
        # pending log already khada hai to naya log + naya reserved slot
        # MAT banao, warna har detection ek aur slot kha jati hai.
        if last_log and last_log.log_type == "entry" and last_log.status == "pending":
            return Response({
                "status" : "already_pending",
                "message": "Entry already pending cashier approval"
            }, status=status.HTTP_400_BAD_REQUEST)

        # Check if vehicle is registered + has booking
        try:
            vehicle = Vehicle.objects.get(plate_number=plate_number)

            # ── Pass holder? Dedicated slot, no walk-in assignment ──
            active_pass = ParkingPass.valid_for(vehicle, site=site)
            if active_pass:
                has_booking = False
                booking = None
                booking_info = {
                    "pass_id"     : str(active_pass.id),
                    "user"        : active_pass.user.full_name if active_pass.user else None,
                    "slot"        : active_pass.parking_slot.slot_number,
                    "pass_window" : f"{active_pass.daily_start:%H:%M}–{active_pass.daily_end:%H:%M}",
                    "valid_until" : str(active_pass.end_date),
                    "vehicle_type": vehicle.vehicle_type,
                    "is_pass"     : True,
                }
                pre_assigned_slot = active_pass.parking_slot.slot_number
            else:
                # FIX: payment-aware lookup — "confirmed" ke saath saath
                # aisi booking bhi pakro jo paid to hai lekin kisi flow ne
                # status flip nahi kiya (pending_payment + paid). Warna
                # booked car walk-in ban jati thi.
                booking = find_gate_booking(vehicle, site=site)

                has_booking = booking is not None

                booking_info = None
                if booking:
                    booking_info = {
                        "booking_id"    : str(booking.id),
                        "user"          : booking.user.full_name if booking.user else None,
                        "slot"          : booking.parking_slot.slot_number,
                        "exit_time"     : str(booking.exit_time) if booking.exit_time else None,
                        "vehicle_type"  : vehicle.vehicle_type,
                        "payment_status": booking.payment_status,
                    }

                    # Pre-booked slot
                    pre_assigned_slot = booking.parking_slot.slot_number

                else:
                    # Registered but no booking — walk-in ko default
                    # "normal" type ka slot do; cashier dashboard ke
                    # dropdown se type badal kar recheck kar sakta hai.
                    with transaction.atomic():
                        pre_assigned_slot = reserve_walkin_slot(site, "normal")

        except Vehicle.DoesNotExist:
            vehicle      = None
            has_booking  = False
            booking_info = None

            # Unregistered walk-in — default "normal" type
            with transaction.atomic():
                pre_assigned_slot = reserve_walkin_slot(site, "normal")

        entry_time = timezone.now()

        # Save pending log
        ai_log = AiLog.objects.create(
            parking_site      = site,
            image_url             = filename,
            cropped_plate         = cropped_filename,
            detected_plate_number = plate_number,  
            confidence_score      = float(confidence),
            processed_model_name  = "YOLOv8 + EasyOCR",
            entry_exit_point      = gate,
            vehicle_type          = vehicle_type,
            booking               = None,
            log_type              = "entry",
            status                = "pending",
            assigned_slot     = pre_assigned_slot
        )

        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(
            f"parking_entry_{site.id}",
            {
                "type"             : "entry_detected",
                "ai_log_id"        : str(ai_log.id),
                "plate_number"     : plate_number,
                "confidence"       : float(confidence),
                "image_url"        : f"/media/detected/{filename}" if filename else "",
                "cropped_plate"    : f"/media/detected/{cropped_filename}" if cropped_filename else "",
                "has_booking"      : has_booking,
                "is_pass"          : bool(booking_info and booking_info.get("is_pass")),
                "booking_info"     : booking_info,
                "vehicle_type"     : vehicle_type,
                "pre_assigned_slot": pre_assigned_slot,
                # Walk-in ka reserve hua slot default "normal" type ka hota
                # hai — UI dropdown isi se initialize hota hai.
                "slot_type"        : ParkingSlot.objects.filter(
                                         parking_site=site,
                                         slot_number=pre_assigned_slot,
                                     ).values_list("slot_type", flat=True).first()
                                     if pre_assigned_slot else None,
                "entry_time"       : str(entry_time),
            }
        )

        return Response({
            "status"           : "pending",
            "ai_log_id"        : str(ai_log.id),
            "plate_number"     : plate_number,
            "pre_assigned_slot": pre_assigned_slot,
            "entry_time"       : str(entry_time),
            "message"          : "Waiting for cashier approval"
        }, status=status.HTTP_200_OK)
class ExitView(APIView):
    permission_classes = []

    def post(self, request):
        camera = verify_api_key(request)
        if camera is None:
            return Response({"error": "Invalid API Key"}, status=status.HTTP_401_UNAUTHORIZED)
        site = camera.parking_site
        if site is None:
            return Response(
                {"error": "Camera key is not bound to a parking site. "
                          "Assign parking_site to this CameraAPIKey."},
                status=status.HTTP_403_FORBIDDEN
            )

        plate_number   = request.data.get("plate_number")
        image_base64   = request.data.get("image")
        cropped_base64 = request.data.get("cropped_plate")
        gate           = request.data.get("gate", "Exit Gate")
        confidence     = request.data.get("confidence", 0.0)

        if not plate_number:
            return Response({"error": "No plate number detected"}, status=status.HTTP_400_BAD_REQUEST)

      
        plate_number = plate_number.upper()

        filename         = save_image(image_base64, plate_number, prefix="exit")
        cropped_filename = save_image(cropped_base64, plate_number, prefix="cropped_exit")

        # Already pending exit check
        last_log = AiLog.objects.filter(
            parking_site=site,
            detected_plate_number=plate_number
        ).order_by("-detected_at").first()

        if last_log and last_log.log_type == "exit" and last_log.status == "pending":
            return Response({
                "status" : "already_pending",
                "message": "Exit already pending cashier approval"
            }, status=status.HTTP_400_BAD_REQUEST)

        # --- Entry log check + amount calculate ---
        # FIX: parking_site filter missing tha — site A ki entry, site B ke
        # exit gate pe match ho jati thi (multi-site isolation break).
        entry_log = AiLog.objects.filter(
            parking_site=site,
            detected_plate_number=plate_number,
            log_type="entry",
            status="approved"
        ).order_by("-detected_at").first()

        booking_info  = None
        amount        = None
        vehicle_name  = ""
        vehicle_type  = "car"
        slot          = ""
        is_extended   = False
        booking_id    = ""
        entry_time_ws = ""

        if entry_log:
            actual_exit = timezone.now()

            try:
                vehicle      = Vehicle.objects.get(plate_number=plate_number)
                vehicle_name = vehicle.name
                vehicle_type = vehicle.vehicle_type

                booking = Booking.objects.filter(
                    vehicle=vehicle, status="active",
                    parking_slot__parking_site=site,
                ).first()

                if booking:
                    is_extended = booking.extension_count > 0
                    booking_id  = str(booking.id)
                    slot        = booking.parking_slot.slot_number

                    total_amount = calculate_amount(
                        site             = site,
                        vehicle_type     = vehicle.vehicle_type,
                        entry_time       = booking.entry_time,
                        exit_time        = actual_exit,
                        booked_exit_time = booking.actual_exit_time,
                        is_booking       = True,
                        is_extended      = is_extended
                        ,slot             = booking.parking_slot
                    )

                    # FIX: booking hamesha pehle prepaid hoti hai, lekin exit
                    # gate ye dekhta hi nahi tha ke kitna pay ho chuka hai —
                    # cashier ko pura amount "due" dikhta tha aur customer
                    # double charge ho jata tha. Ab due = total − already paid
                    # (on-time prepaid booking pe Rs. 0, sirf overstay bacha
                    # to sirf overstay).
                    already_paid = booking_paid_amount(booking)
                    amount_due   = round(max(0.0, float(total_amount) - already_paid), 2)
                    amount       = amount_due

                    base_amount = calculate_amount(
                        site             = site,
                        vehicle_type     = vehicle.vehicle_type,
                        entry_time       = booking.entry_time,
                        exit_time        = booking.exit_time or actual_exit,
                        booked_exit_time = booking.actual_exit_time,
                        is_booking       = True,
                        is_extended      = is_extended
                        ,slot             = booking.parking_slot
                    )

                    booking_info = {
                        "user"        : booking.user.full_name if booking.user else None,
                        "slot"        : booking.parking_slot.slot_number,
                        "entry_time"  : str(booking.entry_time),
                        "booked_exit" : str(booking.actual_exit_time) if booking.actual_exit_time else None,
                        "is_overstay" : actual_exit > booking.actual_exit_time if booking.actual_exit_time else False,
                        "base_amount" : base_amount,
                        "overstay_charge": round(
                            total_amount - base_amount, 2
                        ) if booking.exit_time and actual_exit > booking.exit_time else 0,
                        "total_amount"  : total_amount,
                        "payment_status": booking.payment_status,
                        "already_paid"  : already_paid,
                        "amount_due"    : amount_due,
                    }
                    entry_time_ws = str(booking.entry_time)

                else:
                    # ── Pass holder? Exit is free (prepaid) ──
                    exit_pass = ParkingPass.valid_for(vehicle, site=site)
                    if exit_pass is None:
                        # Window ke bahar bhi pass exit free hi hai — sirf
                        # active pass hona kaafi hai (overstay charging on
                        # passes: future work).
                        exit_pass = ParkingPass.objects.filter(
                            vehicle=vehicle, status="active",
                            parking_slot__parking_site=site,
                        ).select_related("parking_slot").first()

                    if exit_pass:
                        overstay_amt, overstay_hrs = exit_pass.overstay_amount(actual_exit)
                        amount = float(overstay_amt)
                        slot   = exit_pass.parking_slot.slot_number
                        booking_info = {
                            "user"          : exit_pass.user.full_name if exit_pass.user else None,
                            "slot"          : slot,
                            "is_pass"       : True,
                            "pass_window"   : f"{exit_pass.daily_start:%H:%M}–{exit_pass.daily_end:%H:%M}",
                            "valid_until"   : str(exit_pass.end_date),
                            "is_overstay"   : overstay_amt > 0,
                            "overstay_hours": overstay_hrs,
                            "overstay_charge": float(overstay_amt),
                            "total_amount"  : float(overstay_amt),
                        }
                        entry_time_ws = str(entry_log.detected_at)
                    else:
                        # Walk-in registered vehicle
                        amount = calculate_amount(
                            site             = site,
                            vehicle_type     = vehicle.vehicle_type,
                            entry_time       = entry_log.detected_at,
                            exit_time        = actual_exit,
                            booked_exit_time = None,
                            is_booking       = False,
                            is_extended      = False
                            ,slot             = _slot_for_entry_log(entry_log)
                        )
                        entry_time_ws = str(entry_log.detected_at)

            except Vehicle.DoesNotExist:
                # Unregistered walk-in
                amount = calculate_amount(
                    site             = site,
                    vehicle_type     = "car",
                    entry_time       = entry_log.detected_at,
                    exit_time        = actual_exit,
                    booked_exit_time = None,
                    is_booking       = False,
                    is_extended      = False
                    ,slot             = _slot_for_entry_log(entry_log)
                )
                entry_time_ws = str(entry_log.detected_at)

        # Pending exit log banao
        ai_log = AiLog.objects.create(
            parking_site      = site,
            image_url             = filename,
            cropped_plate         = cropped_filename,
            detected_plate_number = plate_number,  
            confidence_score      = float(confidence),
            processed_model_name  = "YOLOv8 + EasyOCR",
            entry_exit_point      = gate,
            vehicle_type          = vehicle_type,
            booking               = None,
            log_type              = "exit",
            status                = "pending"
        )

        # WebSocket — full data
        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(
            f"parking_exit_{site.id}",
            {
                "type"         : "exit_detected",
                "ai_log_id"    : str(ai_log.id),
                "plate_number" : plate_number,
                "confidence"   : float(confidence),
                "image_url"    : f"/media/detected/{filename}" if filename else "",
                "cropped_plate": f"/media/detected/{cropped_filename}" if cropped_filename else "",
                "vehicle_name" : vehicle_name,
                "vehicle_type" : vehicle_type,
                "slot"         : str(slot),
                "amount"       : amount,
                "entry_time"   : entry_time_ws,
                "is_extended"  : is_extended,
                "booking_id"   : booking_id,
                "booking_info" : booking_info,
                "entry_found"  : entry_log is not None,
            }
        )

        return Response({
            "status"      : "pending",
            "ai_log_id"   : str(ai_log.id),
            "plate_number": plate_number,
            "message"     : "Waiting for cashier approval"
        }, status=status.HTTP_200_OK)

class CheckPlateView(APIView):
    """Cashier plate edit karke save kare to is endpoint se re-check ho."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        plate_number = request.data.get("plate_number")
        ai_log_id    = request.data.get("ai_log_id")

        if not plate_number or not ai_log_id:
            return Response({"error": "plate_number and ai_log_id required"}, status=status.HTTP_400_BAD_REQUEST)

        # FIX: pehle ai_log ko validate kiye bina end me blind .update()
        # hota tha — na existence check, na cross-site guard. Ab pending
        # exit log fetch karke uski site ke andar hi entry dhundhte hain.
        try:
            exit_log = AiLog.objects.get(id=ai_log_id, log_type="exit", status="pending")
        except AiLog.DoesNotExist:
            return Response({"error": "Pending exit log not found"}, status=status.HTTP_404_NOT_FOUND)

        forbidden = _forbid_cross_site(request.user, exit_log)
        if forbidden:
            return forbidden

        entry_log = AiLog.objects.filter(
            parking_site=exit_log.parking_site,
            detected_plate_number=plate_number.upper(),
            log_type="entry",
            status="approved"
        ).order_by("-detected_at").first()

        if not entry_log:
            return Response({
                "entry_found": False,
                "plate_number": plate_number.upper(),
                "message": "No entry record found for this plate"
            }, status=status.HTTP_200_OK)

        actual_exit  = timezone.now()
        site         = entry_log.parking_site
        booking_info = None
        amount       = None
        vehicle_name = ""
        vehicle_type = "car"
        slot         = ""
        is_extended  = False
        booking_id   = ""

        try:
            vehicle      = Vehicle.objects.get(plate_number=plate_number.upper())
            vehicle_name = vehicle.name
            vehicle_type = vehicle.vehicle_type

            booking = Booking.objects.filter(vehicle=vehicle, status="active").first()

            if booking:
                is_extended = booking.extension_count > 0
                booking_id  = str(booking.id)
                slot        = booking.parking_slot.slot_number

                base_amount = calculate_amount(
                    site             = site,
                    vehicle_type     = vehicle.vehicle_type,
                    entry_time       = booking.entry_time,
                    exit_time        = booking.exit_time or actual_exit,
                    booked_exit_time = booking.actual_exit_time,
                    is_booking       = True,
                    is_extended      = is_extended
                    ,slot             = booking.parking_slot
                )
                amount = calculate_amount(
                    site             = site,
                    vehicle_type     = vehicle.vehicle_type,
                    entry_time       = booking.entry_time,
                    exit_time        = actual_exit,
                    booked_exit_time = booking.actual_exit_time,
                    is_booking       = True,
                    is_extended      = is_extended
                    ,slot             = booking.parking_slot
                )
                overstay_charge  = round(amount - base_amount, 2) if booking.actual_exit_time and actual_exit > booking.actual_exit_time else 0

                # FIX: prepaid amount minus karke hi due dikhao (dekho
                # ExitView) — warna paid booking pe bhi pura total "due".
                already_paid = booking_paid_amount(booking)
                amount_due   = round(max(0.0, float(amount) - already_paid), 2)

                booking_info = {
                    "user"          : booking.user.full_name if booking.user else None,
                    "slot"          : booking.parking_slot.slot_number,
                    "entry_time"    : str(booking.entry_time),
                    "booked_exit"    : str(booking.actual_exit_time) if booking.actual_exit_time else None,
                    "is_overstay"    : actual_exit > booking.actual_exit_time if booking.actual_exit_time else False,
                    "base_amount"   : base_amount,
                    "overstay_charge": overstay_charge,
                    "total_amount"  : amount,
                    "payment_status": booking.payment_status,
                    "already_paid"  : already_paid,
                    "amount_due"    : amount_due,
                }
                amount = amount_due
            else:
                amount = calculate_amount(
                    site             = site,
                    vehicle_type     = vehicle.vehicle_type,
                    entry_time       = entry_log.detected_at,
                    exit_time        = actual_exit,
                    booked_exit_time = None,
                    is_booking       = False,
                    is_extended      = False
                    ,slot             = _slot_for_entry_log(entry_log)
                )

        except Vehicle.DoesNotExist:
            amount = calculate_amount(
                site             = site,
                vehicle_type     = "car",
                entry_time       = entry_log.detected_at,
                exit_time        = actual_exit,
                booked_exit_time = None,
                is_booking       = False,
                is_extended      = False
                ,slot             = _slot_for_entry_log(entry_log)
            )

        # Pending log ka plate update karo
        AiLog.objects.filter(id=ai_log_id).update(
            detected_plate_number=plate_number.upper()
        )

        return Response({
            "entry_found" : True,
            "plate_number": plate_number.upper(),
            "amount"      : amount,
            "vehicle_name": vehicle_name,
            "vehicle_type": vehicle_type,
            "slot"        : str(slot),
            "is_extended" : is_extended,
            "booking_id"  : booking_id,
            "booking_info": booking_info,
            "entry_time"  : str(entry_log.detected_at),
        }, status=status.HTTP_200_OK)
    

class CheckEntryPlateView(APIView):
    """Cashier entry ke pending log pe plate edit karke save kare to is endpoint se re-check ho.
    CheckPlateView ka entry-side mirror — booking/pass find karta hai aur
    slot pre-assignment ko naye plate ke hisaab se refresh karta hai."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        plate_number = request.data.get("plate_number")
        ai_log_id    = request.data.get("ai_log_id")
        # Walk-in ke liye cashier ka chuna hua slot type (normal/vip/disabled)
        slot_type    = clean_slot_type(request.data.get("slot_type"))

        if not plate_number or not ai_log_id:
            return Response({"error": "plate_number and ai_log_id required"}, status=status.HTTP_400_BAD_REQUEST)

        plate_number = plate_number.upper()

        try:
            ai_log = AiLog.objects.get(id=ai_log_id, log_type="entry", status="pending")
        except AiLog.DoesNotExist:
            return Response({"error": "Pending entry log not found"}, status=status.HTTP_404_NOT_FOUND)

        forbidden = _forbid_cross_site(request.user, ai_log)
        if forbidden:
            return forbidden

        site = ai_log.parking_site

        # Already inside check (same rule as EntryView)
        last_log = AiLog.objects.filter(
            parking_site=site,
            detected_plate_number=plate_number
        ).exclude(id=ai_log.id).order_by("-detected_at").first()

        if last_log and last_log.log_type == "entry" and last_log.status == "approved":
            return Response({
                "status" : "already_inside",
                "message": "Vehicle already inside parking"
            }, status=status.HTTP_400_BAD_REQUEST)

        has_booking   = False
        booking_info  = None
        is_pass       = False
        vehicle_type  = "car"
        new_slot      = None
        booking_other_site = None

        with transaction.atomic():
            try:
                vehicle = Vehicle.objects.get(plate_number=plate_number)
                vehicle_type = vehicle.vehicle_type

                active_pass = ParkingPass.valid_for(vehicle, site=site)
                if active_pass:
                    is_pass = True
                    booking_info = {
                        "pass_id"     : str(active_pass.id),
                        "user"        : active_pass.user.full_name if active_pass.user else None,
                        "slot"        : active_pass.parking_slot.slot_number,
                        "pass_window" : f"{active_pass.daily_start:%H:%M}–{active_pass.daily_end:%H:%M}",
                        "valid_until" : str(active_pass.end_date),
                        "vehicle_type": vehicle.vehicle_type,
                        "is_pass"     : True,
                    }
                    new_slot = active_pass.parking_slot.slot_number
                else:
                    # FIX: payment-aware lookup (confirmed YA paid-but-stuck
                    # pending_payment) — dekho find_gate_booking.
                    booking = find_gate_booking(vehicle, site=site)
                    has_booking = booking is not None

                    if booking:
                        booking_info = {
                            "booking_id"    : str(booking.id),
                            "user"          : booking.user.full_name if booking.user else None,
                            "slot"          : booking.parking_slot.slot_number,
                            "exit_time"     : str(booking.exit_time) if booking.exit_time else None,
                            "vehicle_type"  : vehicle.vehicle_type,
                            "payment_status": booking.payment_status,
                        }
                        new_slot = booking.parking_slot.slot_number
                    else:
                        # Diagnostic: is vehicle ki booking KISI AUR site pe
                        # to nahi? (Camera key galat site se bind hone par
                        # cashier ko wajah dikhe, chup-chaap walk-in na bane.)
                        other = find_gate_booking(vehicle, site=None)
                        if other and other.parking_slot.parking_site_id != site.id:
                            booking_other_site = other.parking_slot.parking_site.name
                        new_slot = self._reassign_walkin_slot(site, ai_log.assigned_slot, slot_type)

            except Vehicle.DoesNotExist:
                new_slot = self._reassign_walkin_slot(site, ai_log.assigned_slot, slot_type)

            ai_log.detected_plate_number = plate_number
            ai_log.vehicle_type = vehicle_type
            ai_log.assigned_slot = new_slot
            ai_log.save(update_fields=["detected_plate_number", "vehicle_type", "assigned_slot"])

        # Assigned slot ka actual type wapas bhejo taake UI dropdown sync rahe
        assigned_slot_type = None
        if new_slot:
            assigned_slot_type = ParkingSlot.objects.filter(
                parking_site=site, slot_number=new_slot
            ).values_list("slot_type", flat=True).first()

        return Response({
            "entry_found"      : True,
            "plate_number"     : plate_number,
            "vehicle_type"     : vehicle_type,
            "has_booking"      : has_booking,
            "is_pass"          : is_pass,
            "booking_info"     : booking_info,
            "booking_other_site": booking_other_site,
            "pre_assigned_slot": new_slot,
            "slot_type"        : assigned_slot_type,
            "ai_log_id"        : str(ai_log.id),
        }, status=status.HTTP_200_OK)

    @staticmethod
    def _reassign_walkin_slot(site, previously_reserved_slot, slot_type="normal"):
        """Releases the slot the pending log was holding (if any) and reserves
        a fresh slot of the REQUESTED TYPE for a walk-in.

        Agar pehle wala slot already usi type ka hai to wahi rakho — dropdown
        change na hone par bewajah slot churn nahi hota."""
        if previously_reserved_slot:
            prev = ParkingSlot.objects.select_for_update().filter(
                parking_site=site,
                slot_number=previously_reserved_slot,
                is_occupied=False,
            ).first()
            if prev:
                if prev.slot_type == slot_type and prev.is_reserved:
                    return prev.slot_number
                prev.is_reserved = False
                prev.save()

        return reserve_walkin_slot(site, slot_type)


def _site_for_manual(user, site_id=None):
    """Manual gate action ke liye site resolve karo. Cashier apni bound
    site use karta hai; owner/admin explicit site_id bhej sakte hain
    (owner sirf apni site)."""
    if getattr(user, "site_id", None):
        return user.site
    role = getattr(user, "role", "user")
    if site_id and role in ("parking_owner", "admin"):
        from parking.models import ParkingSite
        qs = ParkingSite.objects.filter(id=site_id)
        if role == "parking_owner":
            qs = qs.filter(owner=user)
        return qs.first()
    return None


class ManualEntryView(APIView):
    """Cashier plate type karke entry process kare — camera ke bina.

    Ye sirf ek pending entry AiLog banata hai; iske baad frontend wahi
    do endpoints use karta hai jo AI flow use karta hai:
      1. POST /ai/check-entry-plate/  → booking/pass/walk-in slot resolve
      2. POST /ai/approve/ ya /ai/reject/
    Is tarah manual aur camera entries ek hi code path se guzarti hain —
    koi duplicate logic nahi, koi divergence nahi."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        plate = (request.data.get("plate_number") or "").strip().upper()
        if not plate:
            return Response({"error": "plate_number required"},
                            status=status.HTTP_400_BAD_REQUEST)
        if len(plate) > 20:
            return Response({"error": "Plate number too long (max 20 chars)"},
                            status=status.HTTP_400_BAD_REQUEST)

        site = _site_for_manual(request.user, request.data.get("site_id"))
        if site is None:
            return Response(
                {"error": "No parking site bound to your account. "
                          "Owners/admins must pass site_id."},
                status=status.HTTP_403_FORBIDDEN)

        release_stale_entry_reservations(site)

        last_log = AiLog.objects.filter(
            parking_site=site, detected_plate_number=plate
        ).order_by("-detected_at").first()

        if last_log and last_log.log_type == "entry" and last_log.status == "approved":
            return Response({
                "status" : "already_inside",
                "error"  : "Vehicle is already inside the parking"
            }, status=status.HTTP_400_BAD_REQUEST)

        # Same plate ka pending log (camera ya manual) already hai to wahi
        # reuse karo — do parallel pendings ek hi car ke liye nahi chahiye.
        if last_log and last_log.log_type == "entry" and last_log.status == "pending":
            return Response({
                "ai_log_id": str(last_log.id),
                "plate_number": plate,
                "reused": True,
            }, status=status.HTTP_200_OK)

        ai_log = AiLog.objects.create(
            parking_site          = site,
            detected_plate_number = plate,
            confidence_score      = 1.0,
            processed_model_name  = "Manual",
            entry_exit_point      = "Entry Gate (Manual)",
            vehicle_type          = request.data.get("vehicle_type", "car"),
            log_type              = "entry",
            status                = "pending",
        )
        return Response({
            "ai_log_id"   : str(ai_log.id),
            "plate_number": plate,
            "reused"      : False,
        }, status=status.HTTP_200_OK)


class ManualExitView(APIView):
    """Cashier plate type karke exit process kare — camera ke bina.

    ManualEntryView jaisa pattern: pending exit AiLog banao, phir frontend
    existing /ai/check-plate/ (amount/paid info) aur /ai/approve-exit/ ya
    /ai/reject-exit/ use kare."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        plate = (request.data.get("plate_number") or "").strip().upper()
        if not plate:
            return Response({"error": "plate_number required"},
                            status=status.HTTP_400_BAD_REQUEST)
        if len(plate) > 20:
            return Response({"error": "Plate number too long (max 20 chars)"},
                            status=status.HTTP_400_BAD_REQUEST)

        site = _site_for_manual(request.user, request.data.get("site_id"))
        if site is None:
            return Response(
                {"error": "No parking site bound to your account. "
                          "Owners/admins must pass site_id."},
                status=status.HTTP_403_FORBIDDEN)

        last_log = AiLog.objects.filter(
            parking_site=site, detected_plate_number=plate
        ).order_by("-detected_at").first()

        if last_log and last_log.log_type == "exit" and last_log.status == "pending":
            return Response({
                "ai_log_id": str(last_log.id),
                "plate_number": plate,
                "reused": True,
            }, status=status.HTTP_200_OK)

        ai_log = AiLog.objects.create(
            parking_site          = site,
            detected_plate_number = plate,
            confidence_score      = 1.0,
            processed_model_name  = "Manual",
            entry_exit_point      = "Exit Gate (Manual)",
            vehicle_type          = request.data.get("vehicle_type", "car"),
            log_type              = "exit",
            status                = "pending",
        )
        return Response({
            "ai_log_id"   : str(ai_log.id),
            "plate_number": plate,
            "reused"      : False,
        }, status=status.HTTP_200_OK)


class ApproveEntryView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        ai_log_id    = request.data.get("ai_log_id")
        plate_number = request.data.get("plate_number")

        if not ai_log_id or not plate_number:
            return Response(
                {"error": "ai_log_id and plate_number required"},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            ai_log = AiLog.objects.get(id=ai_log_id, status="pending")
        except AiLog.DoesNotExist:
            return Response(
                {"error": "Pending log not found"},
                status=status.HTTP_404_NOT_FOUND
            )

        forbidden = _forbid_cross_site(request.user, ai_log)
        if forbidden:
            return forbidden

        ai_log.detected_plate_number = plate_number.upper()

        try:
            vehicle      = Vehicle.objects.get(plate_number=plate_number.upper())
            vehicle_type = vehicle.vehicle_type
        except Vehicle.DoesNotExist:
            vehicle      = None
            vehicle_type = ai_log.vehicle_type or "car"

        booking = None
        if vehicle:
            # ── CASE 0: Pass holder — dedicated slot, reservation persists ──
            active_pass = ParkingPass.valid_for(vehicle)
            if active_pass:
                slot = active_pass.parking_slot
                slot.is_occupied = True
                # NOTE: is_reserved stays True — the slot belongs to this
                # pass for its whole duration, entry/exit only toggles
                # occupancy.
                slot.save()

                # Entry detect ke time koi aur slot auto-reserve hua ho
                # (nahi hona chahiye, defensive) toh free karo.
                if ai_log.assigned_slot and ai_log.assigned_slot != slot.slot_number:
                    ParkingSlot.objects.filter(
                        slot_number=ai_log.assigned_slot,
                        parking_site=ai_log.parking_site,
                    ).update(is_reserved=False)

                emit("slots.changed", site_id=slot.parking_site_id)

                ai_log.status   = "approved"
                ai_log.log_type = "entry"
                ai_log.save()

                return Response({
                    "status"      : "approved",
                    "plate_number": plate_number.upper(),
                    "slot"        : slot.slot_number,
                    "is_pass"     : True,
                    "pass_id"     : str(active_pass.id),
                    "valid_until" : str(active_pass.end_date),
                    "user"        : active_pass.user.full_name if active_pass.user else None,
                    "vehicle_type": vehicle_type,
                    "message"     : "Pass holder — entry approved"
                }, status=status.HTTP_200_OK)

            # FIX: payment-aware lookup — approval hi booking ko "active"
            # banata hai, is liye yahan confirmed (ya paid-but-stuck
            # pending_payment) match honi chahiye. Site-scoped taake
            # multi-site pe galat booking activate na ho.
            booking = find_gate_booking(vehicle, site=ai_log.parking_site)

        # ── CASE 1: Pre-existing booking ──
        if booking:
            slot             = booking.parking_slot
            slot.is_occupied = True
            slot.is_reserved = False
            slot.save()
            emit("slots.changed", site_id=slot.parking_site_id)
            emit("bookings.changed", site_id=slot.parking_site_id)

            # Pre-assigned slot tha toh free karo (booking slot alag hai)
            if ai_log.assigned_slot and ai_log.assigned_slot != slot.slot_number:
                ParkingSlot.objects.filter(
                    slot_number=ai_log.assigned_slot,
                    parking_site=ai_log.parking_site,
                ).update(is_reserved=False)

            # FIX: this never happened before, so the booking stayed stuck
            # at "confirmed" forever — which meant exit-side lookups
            # (status="active" in ExitView / CheckPlateView / compute_refund)
            # couldn't find it either. entry_time is left untouched since
            # pricing bills from the booked start time, not actual arrival.
            booking.status = "active"
            booking.save(update_fields=["status"])

            ai_log.booking  = booking
            ai_log.status   = "approved"
            ai_log.log_type = "entry"
            ai_log.save()

            return Response({
                "status"      : "approved",
                "plate_number": plate_number.upper(),
                "slot"        : slot.slot_number,
                "entry_time"  : str(booking.entry_time),
                "booking_id"  : str(booking.id),
                "user"        : booking.user.full_name if booking.user else None,
                "exit_time"   : str(booking.exit_time) if booking.exit_time else None,
                "vehicle_type": vehicle_type,
                "message"     : "Booking found — entry approved"
            }, status=status.HTTP_200_OK)

        # ── CASE 2: Walk-in — use pre-assigned slot ──
        with transaction.atomic():
            # Pre-assigned slot use karo
            if ai_log.assigned_slot:
                # FIX: parking_site filter missing tha — same slot_number
                # (e.g. "A-01") doosri site pe bhi ho sakta hai, aur wahan
                # ka slot occupy ho jata.
                available_slot = ParkingSlot.objects.select_for_update().filter(
                    slot_number=ai_log.assigned_slot,
                    parking_site=ai_log.parking_site,
                ).first()
            else:
                # Fallback — koi slot nahi tha detect time pe
                # FIX: yahan `site` kabhi define hi nahi hua tha — is branch
                # me aate hi NameError crash hota (jab detect time pe parking
                # full thi aur cashier ne phir bhi approve kiya).
                # Cashier ka chuna hua slot_type respect karo (default normal).
                available_slot = ParkingSlot.objects.select_for_update().filter(
                    parking_site=ai_log.parking_site,
                    slot_type=clean_slot_type(request.data.get("slot_type")),
                    is_occupied=False,
                    is_reserved=False
                ).order_by("slot_number").first()

            if not available_slot:
                return Response({
                    "status" : "full",
                    "message": "Parking is full"
                }, status=status.HTTP_200_OK)

            available_slot.is_occupied = True
            available_slot.is_reserved = False
            available_slot.save()
            emit("slots.changed", site_id=available_slot.parking_site_id)

            # ── CASE 2a: Unregistered walk-in ──
            if vehicle is None:
                ai_log.status   = "approved"
                ai_log.log_type = "entry"
                ai_log.save()

                return Response({
                    "status"      : "approved",
                    "plate_number": plate_number.upper(),
                    "slot"        : available_slot.slot_number,
                    "entry_time"  : str(timezone.now()),
                    "vehicle_type": vehicle_type,
                    "message"     : "Unregistered walk-in — slot assigned"
                }, status=status.HTTP_200_OK)

            # ── CASE 2b: Registered, no booking ──
            new_booking = Booking.objects.create(
                user         = vehicle.user,
                parking_slot = available_slot,
                vehicle      = vehicle,
                entry_time   = timezone.now(),
                status       = "active"
            )

            ai_log.booking  = new_booking
            ai_log.status   = "approved"
            ai_log.log_type = "entry"
            ai_log.save()

            return Response({
                "status"      : "approved",
                "plate_number": plate_number.upper(),
                "slot"        : available_slot.slot_number,
                "entry_time"  : str(new_booking.entry_time),
                "vehicle_type": vehicle_type,
                "message"     : "Walk-in — slot assigned"
            }, status=status.HTTP_200_OK)

class RejectEntryView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        ai_log_id = request.data.get("ai_log_id")

        if not ai_log_id:
            return Response(
                {"error": "ai_log_id required"},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            ai_log = AiLog.objects.get(id=ai_log_id, status="pending")
        except AiLog.DoesNotExist:
            return Response(
                {"error": "Pending log not found"},
                status=status.HTTP_404_NOT_FOUND
            )

        forbidden = _forbid_cross_site(request.user, ai_log)
        if forbidden:
            return forbidden

        # Pre-assigned slot free karo
        if ai_log.assigned_slot:
            ParkingSlot.objects.filter(
                slot_number=ai_log.assigned_slot,
                is_reserved=True
            ).update(is_reserved=False)

        ai_log.status = "rejected"
        ai_log.save()

        return Response({
            "status" : "rejected",
            "message": "Vehicle entry rejected"
        }, status=status.HTTP_200_OK)
class AiLogListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user

        # Site-scoped visibility: admin sab, owner apni sites, cashier
        # apni site. (Purana booking-join filter walk-ins globally leak
        # karta tha — AiLog.parking_site direct source of truth hai.)
        all_logs = _scope_ailogs(AiLog.objects.all(), user)

        # Active vehicles count
        active_count = 0
        plates = all_logs.values('detected_plate_number').distinct()
        for plate in plates:
            last_log = all_logs.filter(
                detected_plate_number=plate['detected_plate_number']
            ).order_by('-detected_at').first()
            if last_log and last_log.log_type == 'entry' and last_log.status == 'approved':
                active_count += 1

        # Slice karo
        logs = all_logs.order_by('-detected_at')[:50]

        data = [
            {
                "id"                    : str(log.id),
                "detected_plate_number" : log.detected_plate_number,
                "confidence_score"      : log.confidence_score,
                "entry_exit_point"      : log.entry_exit_point,
                "vehicle_type"          : log.vehicle_type,
                "log_type"              : log.log_type,
                "detected_at"           : log.detected_at,
                "status"                : log.status,
                "active_vehicles"       : active_count,
            }
            for log in logs
        ]
        return Response(data, status=status.HTTP_200_OK)
class PendingLogView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        # Sabse latest pending entry log
        pending = _scope_ailogs(AiLog.objects.all(), request.user).filter(
            log_type = "entry",
            status   = "pending"
        ).order_by('-detected_at').first()

        if not pending:
            return Response(None, status=status.HTTP_200_OK)

        # Vehicle aur booking info
        has_booking  = False
        booking_info = None

        try:
            vehicle = Vehicle.objects.get(
                plate_number=pending.detected_plate_number
            )
            # Payment-aware lookup — baqi entry views jaisa (confirmed YA
            # paid-but-stuck pending_payment), site-scoped.
            booking = find_gate_booking(vehicle, site=pending.parking_site)

            if booking:
                has_booking  = True
                booking_info = {
                    "booking_id"    : str(booking.id),
                    "user"          : booking.user.full_name if booking.user else None,
                    "slot"          : booking.parking_slot.slot_number,
                    "exit_time"     : booking.exit_time,
                    "vehicle_type"  : vehicle.vehicle_type,
                    "payment_status": booking.payment_status,
                }
        except Vehicle.DoesNotExist:
            pass

        return Response({
            "id"                   : str(pending.id),
            "detected_plate_number": pending.detected_plate_number,
            "confidence_score"     : pending.confidence_score,
            "image_url"            : f"/media/detected/{pending.image_url}" if pending.image_url else "",
            "cropped_plate"        : f"/media/detected/{pending.cropped_plate}" if pending.cropped_plate else "",
            "vehicle_type"         : pending.vehicle_type,
            "detected_at"          : pending.detected_at,
            "pre_assigned_slot"    : pending.assigned_slot,
            "slot_type"            : ParkingSlot.objects.filter(
                                         parking_site=pending.parking_site,
                                         slot_number=pending.assigned_slot,
                                     ).values_list("slot_type", flat=True).first()
                                     if pending.assigned_slot else None,
            "entry_time"           : str(pending.detected_at),
            "has_booking"          : has_booking,
            "booking_info"         : booking_info,
        }, status=status.HTTP_200_OK)
    
class PendingExitView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        pending = _scope_ailogs(AiLog.objects.all(), request.user).filter(
            log_type="exit",
            status="pending"
        ).order_by('-detected_at').first()

        if not pending:
            return Response(None, status=status.HTTP_200_OK)

        # site was previously referenced below without ever being assigned
        # here (NameError waiting to happen the moment a matching Vehicle
        # with an active booking was found) — pending.parking_site fixes it.
        site = pending.parking_site

        # Entry log dhundho (FIX: same-site only — multi-site isolation)
        entry_log = AiLog.objects.filter(
            parking_site=site,
            detected_plate_number=pending.detected_plate_number,
            log_type="entry",
            status="approved"
        ).order_by("-detected_at").first()

        booking_info  = None
        amount        = None
        vehicle_name  = ""
        vehicle_type  = pending.vehicle_type or "car"
        slot          = ""
        is_extended   = False
        booking_id    = ""
        entry_time_str = ""

        if entry_log:
            actual_exit = timezone.now()
            entry_time_str = str(entry_log.detected_at)

            try:
                vehicle      = Vehicle.objects.get(plate_number=pending.detected_plate_number)
                vehicle_name = vehicle.name
                vehicle_type = vehicle.vehicle_type

                booking = Booking.objects.filter(
                    vehicle=vehicle, status="active",
                    parking_slot__parking_site=site,
                ).first()

                if booking:
                    is_extended = booking.extension_count > 0
                    booking_id  = str(booking.id)
                    slot        = booking.parking_slot.slot_number

                    base_amount = calculate_amount(
                        site             = site,
                        vehicle_type     = vehicle.vehicle_type,
                        entry_time       = booking.entry_time,
                        exit_time        = booking.actual_exit_time or actual_exit,
                        booked_exit_time = booking.actual_exit_time,
                        is_booking       = True,
                        is_extended      = is_extended
                        ,slot             = booking.parking_slot
                    )
                    amount = calculate_amount(
                        site             = site,
                        vehicle_type     = vehicle.vehicle_type,
                        entry_time       = booking.entry_time,
                        exit_time        = actual_exit,
                        booked_exit_time = booking.actual_exit_time,
                        is_booking       = True,
                        is_extended      = is_extended
                        ,slot             = booking.parking_slot
                    )
                    overstay_charge = round(amount - base_amount, 2) if booking.actual_exit_time and actual_exit > booking.actual_exit_time else 0

                    # FIX: prepaid minus karke due dikhao (dekho ExitView).
                    already_paid = booking_paid_amount(booking)
                    amount_due   = round(max(0.0, float(amount) - already_paid), 2)

                    booking_info = {
                        "user"           : booking.user.full_name if booking.user else None,
                        "slot"           : booking.parking_slot.slot_number,
                        "entry_time"     : str(booking.entry_time),
                        "booked_exit"    : str(booking.actual_exit_time) if booking.actual_exit_time else None,
                        "is_overstay"    : actual_exit > booking.actual_exit_time if booking.actual_exit_time else False,
                        "base_amount"    : base_amount,
                        "overstay_charge": overstay_charge,
                        "total_amount"   : amount,
                        "payment_status" : booking.payment_status,
                        "already_paid"   : already_paid,
                        "amount_due"     : amount_due,
                    }
                    amount = amount_due
                    entry_time_str = str(booking.entry_time)
                else:
                    amount = calculate_amount(
                        site             = site,
                        vehicle_type     = vehicle.vehicle_type,
                        entry_time       = entry_log.detected_at,
                        exit_time        = actual_exit,
                        booked_exit_time = None,
                        is_booking       = False,
                        is_extended      = False
                        ,slot             = _slot_for_entry_log(entry_log)
                    )

            except Vehicle.DoesNotExist:
                amount = calculate_amount(
                    site             = site,
                    vehicle_type     = "car",
                    entry_time       = entry_log.detected_at,
                    exit_time        = actual_exit,
                    booked_exit_time = None,
                    is_booking       = False,
                    is_extended      = False
                    ,slot             = _slot_for_entry_log(entry_log)
                )

        return Response({
            "id"                   : str(pending.id),
            "detected_plate_number": pending.detected_plate_number,
            "confidence_score"     : pending.confidence_score,
            # FIX: /media/detected/ prefix add karo
            "image_url"            : f"/media/detected/{pending.image_url}" if pending.image_url else "",
            "cropped_plate"        : f"/media/detected/{pending.cropped_plate}" if pending.cropped_plate else "",
            "vehicle_type"         : vehicle_type,
            "vehicle_name"         : vehicle_name,
            "detected_at"          : pending.detected_at,
            "entry_found"          : entry_log is not None,
            "amount"               : amount,
            "entry_time"           : entry_time_str,
            "slot"                 : str(slot),
            "is_extended"          : is_extended,
            "booking_id"           : booking_id,
            "booking_info"         : booking_info,
        }, status=status.HTTP_200_OK)
class ApproveExitView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):

        ai_log_id    = request.data.get("ai_log_id")
        plate_number = request.data.get("plate_number")  
        payment_method = request.data.get("payment_method", "cash")

        if not ai_log_id or not plate_number:
            return Response(
                {"error": "ai_log_id and plate_number required"},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Get pending exit log
        try:
            ai_log = AiLog.objects.get(
                id       = ai_log_id,
                log_type = "exit",
                status   = "pending"
            )
        except AiLog.DoesNotExist:
            return Response(
                {"error": "Pending exit log not found"},
                status=status.HTTP_404_NOT_FOUND
            )

        forbidden = _forbid_cross_site(request.user, ai_log)
        if forbidden:
            return forbidden

        site = ai_log.parking_site

        # Update plate if corrected
        ai_log.detected_plate_number = plate_number.upper()

        # Check vehicle
        try:
            vehicle = Vehicle.objects.get(plate_number=plate_number.upper())
        except Vehicle.DoesNotExist:
            # Unregistered walk-in
            entry_log = AiLog.objects.filter(
                parking_site          = site,
                detected_plate_number = plate_number.upper(),
                log_type              = "entry",
                status                = "approved"
            ).order_by("-detected_at").first()

            if not entry_log:
                return Response(
                    {"error": "No entry record found"},
                    status=status.HTTP_404_NOT_FOUND
                )

            actual_exit = timezone.now()
            amount = calculate_amount(
                site             = site,
                vehicle_type     = "car",
                entry_time       = entry_log.detected_at,
                exit_time        = actual_exit,
                booked_exit_time = None,
                is_booking       = False,
                is_extended      = False
                ,slot             = _slot_for_entry_log(entry_log)
            )

            # FIX: unregistered walk-in ka koi Booking record nahi hota,
            # is liye yahan slot kabhi free hi nahi hota tha — occupied
            # reh jata tha hamesha. Entry log ke assigned_slot se free karo.
            slot_number = ""
            if entry_log.assigned_slot:
                freed = ParkingSlot.objects.filter(
                    parking_site=entry_log.parking_site,
                    slot_number=entry_log.assigned_slot,
                ).first()
                if freed:
                    freed.is_occupied = False
                    freed.is_reserved = False
                    freed.save()
                    emit("slots.changed", site_id=freed.parking_site_id)
                    slot_number = freed.slot_number

            ai_log.status = "approved"
            ai_log.save()

            return Response({
                "status"      : "exit_approved",
                "plate_number": plate_number.upper(),
                "entry_time"  : entry_log.detected_at,
                "exit_time"   : actual_exit,
                "amount"      : amount,
                "slot"        : slot_number,
                "message"     : "Unregistered walk-in exit approved"
            }, status=status.HTTP_200_OK)

        # Check active booking
        booking = Booking.objects.filter(
            vehicle = vehicle,
            status  = "active"
        ).first()

        actual_exit = timezone.now()

        if not booking:
            # ── Pass holder exit — free, occupancy off, reservation stays ──
            exit_pass = ParkingPass.objects.filter(
                vehicle=vehicle, status="active"
            ).select_related("parking_slot").first()
            if exit_pass:
                slot = exit_pass.parking_slot

                # ── Overstay charge: window + grace ke baad hourly rate ──
                overstay_amt, overstay_hrs = exit_pass.overstay_amount(actual_exit)
                paid_via = None
                if overstay_amt > 0:
                    from payments.services import charge_wallet_split, InsufficientBalance
                    from notifications.services import notify as _notify
                    try:
                        with transaction.atomic():
                            charge_wallet_split(
                                user=exit_pass.user,
                                owner=slot.parking_site.owner,
                                amount=overstay_amt,
                                description=(f"Pass overstay ({overstay_hrs}h) — "
                                             f"slot {slot.slot_number}"),
                            )
                        paid_via = "wallet"
                        _notify(
                            exit_pass.user,
                            "Overstay Charge",
                            (f"Rs. {overstay_amt:.0f} charged for staying {overstay_hrs} "
                             f"hour(s) past your pass window "
                             f"({exit_pass.daily_end:%H:%M} + grace)."),
                            "overstay_alert",
                        )
                    except InsufficientBalance:
                        # Wallet mein paisa nahi — cashier cash collect karega.
                        paid_via = "cash_due"
                        _notify(
                            exit_pass.user,
                            "Overstay Charge Due",
                            (f"Rs. {overstay_amt:.0f} overstay charge could not be "
                             f"deducted (insufficient balance) and was collected in cash."),
                            "overstay_alert",
                        )

                slot.is_occupied = False
                # is_reserved intentionally untouched — dedicated slot.
                slot.save()
                emit("slots.changed", site_id=slot.parking_site_id)

                ai_log.status = "approved"
                ai_log.save()

                return Response({
                    "status"        : "exit_approved",
                    "plate_number"  : plate_number.upper(),
                    "exit_time"     : actual_exit,
                    "amount"        : float(overstay_amt),
                    "overstay_hours": overstay_hrs,
                    "paid_via"      : paid_via,          # None | "wallet" | "cash_due"
                    "is_pass"       : True,
                    "vehicle_name"  : vehicle.name,
                    "vehicle_type"  : vehicle.vehicle_type,
                    "slot"          : slot.slot_number,
                    "message"       : ("Pass holder — exit approved, no charge"
                                       if overstay_amt == 0 else
                                       f"Pass holder — overstay Rs. {overstay_amt:.0f} "
                                       + ("deducted from wallet" if paid_via == "wallet"
                                          else "DUE IN CASH"))
                }, status=status.HTTP_200_OK)

            entry_log = AiLog.objects.filter(
                parking_site=site,
                detected_plate_number=plate_number.upper(),
                log_type="entry",
                status="approved"
            ).order_by("-detected_at").first()
        
            if not entry_log:
                return Response({"error": "No entry record found"}, status=status.HTTP_404_NOT_FOUND)
        
            amount = calculate_amount(
                site             = site,
                vehicle_type     = vehicle.vehicle_type,
                entry_time       = entry_log.detected_at,
                exit_time        = actual_exit,
                booked_exit_time = None,
                is_booking       = False,
                is_extended      = False
                ,slot             = _slot_for_entry_log(entry_log)
            )
        
            # Slot free karo — entry log se dhundho
            if entry_log.booking:
                slot             = entry_log.booking.parking_slot
                slot.is_occupied = False
                slot.save()
                emit("slots.changed", site_id=slot.parking_site_id)
                slot_number = slot.slot_number
            elif entry_log.assigned_slot:
                # Fallback: booking record nahi bana tha (edge case) —
                # entry ke waqt assign hua slot hi free karo.
                freed = ParkingSlot.objects.filter(
                    parking_site=entry_log.parking_site,
                    slot_number=entry_log.assigned_slot,
                ).first()
                if freed:
                    freed.is_occupied = False
                    freed.is_reserved = False
                    freed.save()
                    emit("slots.changed", site_id=freed.parking_site_id)
                    slot_number = freed.slot_number
                else:
                    slot_number = ""
            else:
                slot_number = ""
        
            ai_log.status = "approved"
            ai_log.save()
        
            return Response({
                "status"      : "exit_approved",
                "plate_number": plate_number.upper(),
                "entry_time"  : entry_log.detected_at,
                "exit_time"   : actual_exit,
                "amount"      : amount,
                "vehicle_name": vehicle.name,
                "vehicle_type": vehicle.vehicle_type,
                "slot"        : slot_number,
                "message"     : "Walk-in exit approved"
            }, status=status.HTTP_200_OK)

        # Booking found
        is_extended = booking.extension_count > 0

        total_amount = calculate_amount(
            site             = site,
            vehicle_type     = vehicle.vehicle_type,
            entry_time       = booking.entry_time,
            exit_time        = actual_exit,
            booked_exit_time = booking.actual_exit_time,
            is_booking       = True,
            is_extended      = is_extended
            ,slot             = booking.parking_slot
        )

        # FIX: pehle yahan pura total dobara "collect" ho jata tha aur
        # payment_method bhi overwrite — prepaid booking double charge.
        # Ab sirf bacha hua due (overstay waghera) collect hota hai aur
        # uski Payment row banti hai; kuch due nahi to method untouched.
        already_paid = booking_paid_amount(booking)
        amount_due   = round(max(0.0, float(total_amount) - already_paid), 2)

        # Complete booking
        booking.status           = "completed"
        booking.estimated_amount = total_amount
        booking.payment_status   = "paid"
        booking.exit_time        = actual_exit
        if amount_due > 0:
            booking.payment_method = payment_method
        booking.save()

        if amount_due > 0:
            Payment.objects.create(
                booking         = booking,
                amount          = Decimal(str(amount_due)),
                payment_method  = payment_method,
                payment_type    = "booking",
                payment_channel = "cash" if payment_method == "cash" else "online",
                status          = "success",
                paid_at         = actual_exit,
            )

        # Free slot
        slot             = booking.parking_slot
        slot.is_occupied = False
        slot.save()
        emit("slots.changed", site_id=slot.parking_site_id)
        emit("bookings.changed", site_id=slot.parking_site_id)

        # Update ai_log
        ai_log.status  = "approved"
        ai_log.booking = booking
        ai_log.save()

        return Response({
            "status"      : "exit_approved",
            "plate_number": plate_number.upper(),
            "entry_time"  : booking.entry_time,
            "exit_time"   : actual_exit,
            # "amount" = jo cashier ne ABHI collect kiya (due only) — receipt
            # aur UI isi pe chalte hain. Breakdown alag keys me.
            "amount"        : amount_due,
            "amount_due"    : amount_due,
            "already_paid"  : already_paid,
            "total_amount"  : total_amount,
            "vehicle_name": vehicle.name,
            "vehicle_color": vehicle.color,
            "vehicle_type": vehicle.vehicle_type,
            "slot"        : slot.slot_number,
            "is_extended" : is_extended,
            "booking_id"  : str(booking.id),
            "message"     : ("Exit approved — already paid, nothing due"
                             if amount_due == 0 else "Exit approved")
        }, status=status.HTTP_200_OK)
class RejectExitView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):

        ai_log_id = request.data.get("ai_log_id")

        if not ai_log_id:
            return Response(
                {"error": "ai_log_id required"},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Get pending exit log
        try:
            ai_log = AiLog.objects.get(
                id       = ai_log_id,
                log_type = "exit",
                status   = "pending"
            )
        except AiLog.DoesNotExist:
            return Response(
                {"error": "Pending exit log not found"},
                status=status.HTTP_404_NOT_FOUND
            )

        forbidden = _forbid_cross_site(request.user, ai_log)
        if forbidden:
            return forbidden

        # Mark as rejected
        ai_log.status = "rejected"
        ai_log.save()

        return Response({
            "status" : "rejected",
            "message": "Vehicle exit rejected"
        }, status=status.HTTP_200_OK)

# ─── Admin: Full AI / System logs list ───────────────────────────────────────
from accounts.permissions import IsAdmin
from django.db.models import Q as Q_

class AdminAiLogListView(APIView):
    """
    Returns all AI entry/exit logs for the SystemLogs admin page.
    Supports filtering and search. No record cap.

    Query params:
      event   = entry | exit
      status  = success | warning | error | overstay | pending | approved | rejected
      method  = LPD | Manual
      date_from / date_to  = YYYY-MM-DD
      search  = plate number, site name, log id, slot
      page    = integer (default 1), page_size = integer (default 50)
    """
    permission_classes = [IsAuthenticated, IsAdmin]

    def get(self, request):
        logs = (
            AiLog.objects
            .select_related(
                "booking__parking_slot__parking_site",
                "booking__parking_slot",
            )
            .order_by("-detected_at")
        )

        # ── Filters ────────────────────────────────────────────────────────
        event      = request.query_params.get("event")       # entry | exit
        status_f   = request.query_params.get("status")      # approved|pending|rejected
        date_from  = request.query_params.get("date_from")
        date_to    = request.query_params.get("date_to")
        search     = request.query_params.get("search")

        if event:
            logs = logs.filter(log_type=event)
        if status_f:
            logs = logs.filter(status=status_f)
        if date_from:
            logs = logs.filter(detected_at__date__gte=date_from)
        if date_to:
            logs = logs.filter(detected_at__date__lte=date_to)
        if search:
            logs = logs.filter(
                Q_(detected_plate_number__icontains=search) |
                Q_(booking__parking_slot__parking_site__name__icontains=search) |
                Q_(assigned_slot__icontains=search) |
                Q_(id__icontains=search)
            )

        # ── Pagination ─────────────────────────────────────────────────────
        try:
            page      = max(1, int(request.query_params.get("page", 1)))
            page_size = min(200, max(1, int(request.query_params.get("page_size", 50))))
        except ValueError:
            page, page_size = 1, 50

        total  = logs.count()
        offset = (page - 1) * page_size
        logs   = logs[offset: offset + page_size]

        # ── Serialize ──────────────────────────────────────────────────────
        data = []
        for log in logs:
            try:
                site_name   = log.booking.parking_slot.parking_site.name
                slot_number = log.booking.parking_slot.slot_number
                booking_id  = str(log.booking.id)
            except Exception:
                site_name   = "—"
                slot_number = log.assigned_slot or "—"
                booking_id  = "—"

            # Map internal status → frontend display status
            # approved entry/exit  → "success"
            # pending              → "warning"  (LPD detected, awaiting cashier)
            # rejected             → "error"
            # We also keep original status so frontend can use either
            display_status = {
                "approved": "success",
                "pending":  "warning",
                "rejected": "error",
            }.get(log.status, log.status)

            data.append({
                "id":           str(log.id),
                "plate":        log.detected_plate_number,
                "site":         site_name,
                "slot":         slot_number,
                "event":        log.log_type,          # entry | exit
                "method":       "LPD",                 # all AI logs are LPD-detected
                "status":       display_status,        # success | warning | error
                "raw_status":   log.status,            # approved | pending | rejected
                "booking_id":   booking_id,
                "confidence":   round(log.confidence_score * 100, 1),
                "vehicle_type": log.vehicle_type,
                "entry_exit_point": log.entry_exit_point or "—",
                "timestamp":    log.detected_at,
                "note": (
                    f"Confidence: {round(log.confidence_score * 100, 1)}%"
                    if log.status == "approved"
                    else "Awaiting cashier approval"
                    if log.status == "pending"
                    else "Rejected by cashier"
                ),
            })

        return Response({
            "total":     total,
            "page":      page,
            "page_size": page_size,
            "results":   data,
        }, status=status.HTTP_200_OK)