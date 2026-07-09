import os
import uuid
import base64
import math
from django.utils import timezone
from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db import transaction
from django.conf import settings

from .models import AiLog, CameraAPIKey
from parking.models import Vehicle,ParkingSlot
from bookings.models import Booking
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
BASE_PRICE     = settings.PARKING_BASE_PRICE
EXTRA_PER_HOUR = settings.PARKING_EXTRA_PER_HOUR
GRACE_PERIOD   = settings.PARKING_GRACE_PERIOD
BASE_HOURS     = settings.PARKING_BASE_HOURS


def verify_api_key(request):
    api_key = request.headers.get("X-API-Key")
    if not api_key:
        return False
    try:
        CameraAPIKey.objects.get(key=api_key, is_active=True)
        return True
    except CameraAPIKey.DoesNotExist:
        return False


def calculate_amount(vehicle_type, entry_time, exit_time,
                     booked_exit_time=None,
                     is_booking=False,
                     is_extended=False):

    total_minutes = (exit_time - entry_time).total_seconds() / 60

    # Minimum charge — base price
    if total_minutes <= GRACE_PERIOD:
        return BASE_PRICE.get(vehicle_type, 50)

    base = BASE_PRICE.get(vehicle_type, 50)

    # Extra rate based on booking and extension
    if is_booking and is_extended:
        extra_rate = 10
    else:
        extra_rate = 20

    # Booking case
    if booked_exit_time:
        booked_minutes = (booked_exit_time - entry_time).total_seconds() / 60

        # Within booked time + grace
        if total_minutes <= booked_minutes + GRACE_PERIOD:
            return base

        # Extra minutes after booked time and grace
        extra_minutes = total_minutes - booked_minutes - GRACE_PERIOD

        # Each slab = 60 min + 10 min grace
        extra_slabs = math.floor(extra_minutes / (60 + GRACE_PERIOD))
        remaining   = extra_minutes % (60 + GRACE_PERIOD)

        # If remaining exceeds grace — add one more slab
        if remaining > GRACE_PERIOD:
            extra_slabs += 1

        extra = extra_slabs * extra_rate
        return round(base + extra, 2)

    # Walk-in case
    total_hours = total_minutes / 60

    # First 4 hours flat rate
    if total_hours <= BASE_HOURS:
        return base

    # Extra minutes after 4 hours
    extra_minutes = total_minutes - (BASE_HOURS * 60)
    extra_slabs   = math.floor(extra_minutes / (60 + GRACE_PERIOD))
    remaining     = extra_minutes % (60 + GRACE_PERIOD)

    if remaining > GRACE_PERIOD:
        extra_slabs += 1

    extra = extra_slabs * extra_rate
    return round(base + extra, 2)


def save_image(image_base64, plate_number, prefix="detected"):
    if not image_base64:
        return ""
    detected_dir = os.path.join(settings.MEDIA_ROOT, "detected")
    os.makedirs(detected_dir, exist_ok=True)
    
    clean_plate = plate_number.replace(" ", "_")
    
    filename   = f"{prefix}_{clean_plate}_{uuid.uuid4()}.jpg"
    filepath   = os.path.join(detected_dir, filename)
    image_data = base64.b64decode(image_base64)
    with open(filepath, "wb") as f:
        f.write(image_data)
    return filename

class EntryView(APIView):
    permission_classes = []

    def post(self, request):
        if not verify_api_key(request):
            return Response(
                {"error": "Invalid API Key"},
                status=status.HTTP_401_UNAUTHORIZED
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

        # Already inside check
        last_log = AiLog.objects.filter(
            detected_plate_number=plate_number
        ).order_by("-detected_at").first()

        if last_log and last_log.log_type == "entry" and last_log.status == "approved":
            return Response({
                "status" : "already_inside",
                "message": "Vehicle already inside parking"
            }, status=status.HTTP_400_BAD_REQUEST)

        # Check if vehicle is registered + has booking
        try:
            vehicle = Vehicle.objects.get(plate_number=plate_number)

            booking = Booking.objects.filter(
                vehicle=vehicle,
                status="active"
            ).first()

            has_booking = booking is not None

            booking_info = None
            if booking:
                booking_info = {
                    "booking_id"  : str(booking.id),
                    "user"        : booking.user.full_name if booking.user else None,
                    "slot"        : booking.parking_slot.slot_number,
                    "exit_time"   : str(booking.exit_time) if booking.exit_time else None,
                    "vehicle_type": vehicle.vehicle_type,
                }

                # Pre-booked slot
                pre_assigned_slot = booking.parking_slot.slot_number

            else:
                # Registered but no booking
                with transaction.atomic():
                    available_slot = ParkingSlot.objects.select_for_update().filter(
                        is_occupied=False,
                        is_reserved=False
                    ).first()

                    if available_slot:
                        available_slot.is_reserved = True
                        available_slot.save()
                        pre_assigned_slot = available_slot.slot_number
                    else:
                        pre_assigned_slot = None

        except Vehicle.DoesNotExist:
            vehicle      = None
            has_booking  = False
            booking_info = None

            # Unregistered walk-in
            with transaction.atomic():
                available_slot = ParkingSlot.objects.select_for_update().filter(
                    is_occupied=False,
                    is_reserved=False
                ).first()

                if available_slot:
                    available_slot.is_reserved = True
                    available_slot.save()
                    pre_assigned_slot = available_slot.slot_number
                else:
                    pre_assigned_slot = None

        entry_time = timezone.now()

        # Save pending log
        ai_log = AiLog.objects.create(
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
            "parking_entry",
            {
                "type"             : "entry_detected",
                "ai_log_id"        : str(ai_log.id),
                "plate_number"     : plate_number,
                "confidence"       : float(confidence),
                "image_url"        : f"/media/detected/{filename}" if filename else "",
                "cropped_plate"    : f"/media/detected/{cropped_filename}" if cropped_filename else "",
                "has_booking"      : has_booking,
                "booking_info"     : booking_info,
                "vehicle_type"     : vehicle_type,
                "pre_assigned_slot": pre_assigned_slot,
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
        if not verify_api_key(request):
            return Response({"error": "Invalid API Key"}, status=status.HTTP_401_UNAUTHORIZED)

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
            detected_plate_number=plate_number
        ).order_by("-detected_at").first()

        if last_log and last_log.log_type == "exit" and last_log.status == "pending":
            return Response({
                "status" : "already_pending",
                "message": "Exit already pending cashier approval"
            }, status=status.HTTP_400_BAD_REQUEST)

        # --- Entry log check + amount calculate ---
        entry_log = AiLog.objects.filter(
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

                booking = Booking.objects.filter(vehicle=vehicle, status="active").first()

                if booking:
                    is_extended = booking.extension_count > 0
                    booking_id  = str(booking.id)
                    slot        = booking.parking_slot.slot_number

                    amount = calculate_amount(
                        vehicle_type     = vehicle.vehicle_type,
                        entry_time       = booking.entry_time,
                        exit_time        = actual_exit,
                        booked_exit_time = booking.actual_exit_time,
                        is_booking       = True,
                        is_extended      = is_extended
                    )

                    booking_info = {
                        "user"        : booking.user.full_name if booking.user else None,
                        "slot"        : booking.parking_slot.slot_number,
                        "entry_time"  : str(booking.entry_time),
                        "booked_exit" : str(booking.actual_exit_time) if booking.actual_exit_time else None,
                        "is_overstay" : actual_exit > booking.actual_exit_time if booking.actual_exit_time else False,
                        "base_amount" : calculate_amount(
                            vehicle_type     = vehicle.vehicle_type,
                            entry_time       = booking.entry_time,
                            exit_time        = booking.exit_time or actual_exit,
                            booked_exit_time = booking.actual_exit_time,
                            is_booking       = True,
                            is_extended      = is_extended
                        ),
                        "overstay_charge": round(
                            amount - calculate_amount(
                                vehicle_type     = vehicle.vehicle_type,
                                entry_time       = booking.entry_time,
                                exit_time        = booking.exit_time or actual_exit,
                                booked_exit_time = booking.actual_exit_time,
                                is_booking       = True,
                                is_extended      = is_extended
                            ), 2
                        ) if booking.exit_time and actual_exit > booking.exit_time else 0,
                        "total_amount": amount,
                    }
                    entry_time_ws = str(booking.entry_time)

                else:
                    # Walk-in registered vehicle
                    amount = calculate_amount(
                        vehicle_type     = vehicle.vehicle_type,
                        entry_time       = entry_log.detected_at,
                        exit_time        = actual_exit,
                        booked_exit_time = None,
                        is_booking       = False,
                        is_extended      = False
                    )
                    entry_time_ws = str(entry_log.detected_at)

            except Vehicle.DoesNotExist:
                # Unregistered walk-in
                amount = calculate_amount(
                    vehicle_type     = "car",
                    entry_time       = entry_log.detected_at,
                    exit_time        = actual_exit,
                    booked_exit_time = None,
                    is_booking       = False,
                    is_extended      = False
                )
                entry_time_ws = str(entry_log.detected_at)

        # Pending exit log banao
        ai_log = AiLog.objects.create(
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
            "parking_exit",
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

        entry_log = AiLog.objects.filter(
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
                    vehicle_type     = vehicle.vehicle_type,
                    entry_time       = booking.entry_time,
                    exit_time        = booking.exit_time or actual_exit,
                    booked_exit_time = booking.actual_exit_time,
                    is_booking       = True,
                    is_extended      = is_extended
                )
                amount = calculate_amount(
                    vehicle_type     = vehicle.vehicle_type,
                    entry_time       = booking.entry_time,
                    exit_time        = actual_exit,
                    booked_exit_time = booking.actual_exit_time,
                    is_booking       = True,
                    is_extended      = is_extended
                )
                overstay_charge  = round(amount - base_amount, 2) if booking.actual_exit_time and actual_exit > booking.actual_exit_time else 0

                booking_info = {
                    "user"          : booking.user.full_name if booking.user else None,
                    "slot"          : booking.parking_slot.slot_number,
                    "entry_time"    : str(booking.entry_time),
                    "booked_exit"    : str(booking.actual_exit_time) if booking.actual_exit_time else None,
                    "is_overstay"    : actual_exit > booking.actual_exit_time if booking.actual_exit_time else False,
                    "base_amount"   : base_amount,
                    "overstay_charge": overstay_charge,
                    "total_amount"  : amount,
                }
            else:
                amount = calculate_amount(
                    vehicle_type     = vehicle.vehicle_type,
                    entry_time       = entry_log.detected_at,
                    exit_time        = actual_exit,
                    booked_exit_time = None,
                    is_booking       = False,
                    is_extended      = False
                )

        except Vehicle.DoesNotExist:
            amount = calculate_amount(
                vehicle_type     = "car",
                entry_time       = entry_log.detected_at,
                exit_time        = actual_exit,
                booked_exit_time = None,
                is_booking       = False,
                is_extended      = False
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

        ai_log.detected_plate_number = plate_number.upper()

        try:
            vehicle      = Vehicle.objects.get(plate_number=plate_number.upper())
            vehicle_type = vehicle.vehicle_type
        except Vehicle.DoesNotExist:
            vehicle      = None
            vehicle_type = ai_log.vehicle_type or "car"

        booking = None
        if vehicle:
            booking = Booking.objects.filter(
                vehicle=vehicle, status="active"
            ).first()

        # ── CASE 1: Pre-existing booking ──
        if booking:
            slot             = booking.parking_slot
            slot.is_occupied = True
            slot.is_reserved = False
            slot.save()

            # Pre-assigned slot tha toh free karo (booking slot alag hai)
            if ai_log.assigned_slot and ai_log.assigned_slot != slot.slot_number:
                ParkingSlot.objects.filter(
                    slot_number=ai_log.assigned_slot
                ).update(is_reserved=False)

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
                available_slot = ParkingSlot.objects.select_for_update().filter(
                    slot_number=ai_log.assigned_slot
                ).first()
            else:
                # Fallback — koi slot nahi tha detect time pe
                available_slot = ParkingSlot.objects.select_for_update().filter(
                    is_occupied=False,
                    is_reserved=False
                ).first()

            if not available_slot:
                return Response({
                    "status" : "full",
                    "message": "Parking is full"
                }, status=status.HTTP_200_OK)

            available_slot.is_occupied = True
            available_slot.is_reserved = False
            available_slot.save()

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

        # Queryset banao — role ke hisaab se
        if user.role == "admin":
            all_logs = AiLog.objects.all()
        elif user.role == "parking_owner":
            all_logs = AiLog.objects.filter(
                booking__parking_slot__parking_site__owner=user
            )
        elif user.role == "cashier" and user.site:
            from django.db.models import Q
            all_logs = AiLog.objects.filter(
                Q(booking__parking_slot__parking_site=user.site) |
                Q(booking__parking_slot__isnull=True) |
                Q(booking__isnull=True)
            )
        else:
            all_logs = AiLog.objects.all()

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
        pending = AiLog.objects.filter(
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
            booking = Booking.objects.filter(
                vehicle=vehicle,
                status="active"
            ).first()

            if booking:
                has_booking  = True
                booking_info = {
                    "booking_id"  : str(booking.id),
                    "user"        : booking.user.full_name if booking.user else None,
                    "slot"        : booking.parking_slot.slot_number,
                    "exit_time"   : booking.exit_time,
                    "vehicle_type": vehicle.vehicle_type,
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
            "pre_assigned_slot"    : pending.assigned_slot,  # ← ADD
            "entry_time"           : str(pending.detected_at),   # ← ADD
            "has_booking"          : has_booking,
            "booking_info"         : booking_info,
        }, status=status.HTTP_200_OK)
    
class PendingExitView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        pending = AiLog.objects.filter(
            log_type="exit",
            status="pending"
        ).order_by('-detected_at').first()

        if not pending:
            return Response(None, status=status.HTTP_200_OK)

        # Entry log dhundho
        entry_log = AiLog.objects.filter(
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

                booking = Booking.objects.filter(vehicle=vehicle, status="active").first()

                if booking:
                    is_extended = booking.extension_count > 0
                    booking_id  = str(booking.id)
                    slot        = booking.parking_slot.slot_number

                    base_amount = calculate_amount(
                        vehicle_type     = vehicle.vehicle_type,
                        entry_time       = booking.entry_time,
                        exit_time        = booking.actual_exit_time or actual_exit,
                        booked_exit_time = booking.actual_exit_time,
                        is_booking       = True,
                        is_extended      = is_extended
                    )
                    amount = calculate_amount(
                        vehicle_type     = vehicle.vehicle_type,
                        entry_time       = booking.entry_time,
                        exit_time        = actual_exit,
                        booked_exit_time = booking.actual_exit_time,
                        is_booking       = True,
                        is_extended      = is_extended
                    )
                    overstay_charge = round(amount - base_amount, 2) if booking.actual_exit_time and actual_exit > booking.actual_exit_time else 0

                    booking_info = {
                        "user"           : booking.user.full_name if booking.user else None,
                        "slot"           : booking.parking_slot.slot_number,
                        "entry_time"     : str(booking.entry_time),
                        "booked_exit"    : str(booking.actual_exit_time) if booking.actual_exit_time else None,
                        "is_overstay"    : actual_exit > booking.actual_exit_time if booking.actual_exit_time else False,
                        "base_amount"    : base_amount,
                        "overstay_charge": overstay_charge,
                        "total_amount"   : amount,
                    }
                    entry_time_str = str(booking.entry_time)
                else:
                    amount = calculate_amount(
                        vehicle_type     = vehicle.vehicle_type,
                        entry_time       = entry_log.detected_at,
                        exit_time        = actual_exit,
                        booked_exit_time = None,
                        is_booking       = False,
                        is_extended      = False
                    )

            except Vehicle.DoesNotExist:
                amount = calculate_amount(
                    vehicle_type     = "car",
                    entry_time       = entry_log.detected_at,
                    exit_time        = actual_exit,
                    booked_exit_time = None,
                    is_booking       = False,
                    is_extended      = False
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

        # Update plate if corrected
        ai_log.detected_plate_number = plate_number.upper()

        # Check vehicle
        try:
            vehicle = Vehicle.objects.get(plate_number=plate_number.upper())
        except Vehicle.DoesNotExist:
            # Unregistered walk-in
            entry_log = AiLog.objects.filter(
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
                vehicle_type     = "car",
                entry_time       = entry_log.detected_at,
                exit_time        = actual_exit,
                booked_exit_time = None,
                is_booking       = False,
                is_extended      = False
            )

            ai_log.status = "approved"
            ai_log.save()

            return Response({
                "status"      : "exit_approved",
                "plate_number": plate_number.upper(),
                "entry_time"  : entry_log.detected_at,
                "exit_time"   : actual_exit,
                "amount"      : amount,
                "message"     : "Unregistered walk-in exit approved"
            }, status=status.HTTP_200_OK)

        # Check active booking
        booking = Booking.objects.filter(
            vehicle = vehicle,
            status  = "active"
        ).first()

        actual_exit = timezone.now()

        if not booking:
            entry_log = AiLog.objects.filter(
                detected_plate_number=plate_number.upper(),
                log_type="entry",
                status="approved"
            ).order_by("-detected_at").first()
        
            if not entry_log:
                return Response({"error": "No entry record found"}, status=status.HTTP_404_NOT_FOUND)
        
            amount = calculate_amount(
                vehicle_type     = vehicle.vehicle_type,
                entry_time       = entry_log.detected_at,
                exit_time        = actual_exit,
                booked_exit_time = None,
                is_booking       = False,
                is_extended      = False
            )
        
            # Slot free karo — entry log se dhundho
            if entry_log.booking:
                slot             = entry_log.booking.parking_slot
                slot.is_occupied = False
                slot.save()
                slot_number = slot.slot_number
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

        amount = calculate_amount(
            vehicle_type     = vehicle.vehicle_type,
            entry_time       = booking.entry_time,
            exit_time        = actual_exit,
            booked_exit_time = booking.actual_exit_time,
            is_booking       = True,
            is_extended      = is_extended
        )

        # Complete booking
        booking.status           = "completed"
        booking.estimated_amount = amount
        booking.payment_status   = "paid"              
        booking.payment_method   = payment_method
        booking.exit_time        = actual_exit
        booking.save()

        # Free slot
        slot             = booking.parking_slot
        slot.is_occupied = False
        slot.save()

        # Update ai_log
        ai_log.status  = "approved"
        ai_log.booking = booking
        ai_log.save()

        return Response({
            "status"      : "exit_approved",
            "plate_number": plate_number.upper(),
            "entry_time"  : booking.entry_time,
            "exit_time"   : actual_exit,
            "amount"      : amount,
            "vehicle_name": vehicle.name,
            "vehicle_color": vehicle.color,
            "vehicle_type": vehicle.vehicle_type,
            "slot"        : slot.slot_number,
            "is_extended" : is_extended,
            "booking_id"  : str(booking.id),
            "message"     : "Exit approved"
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

