from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils import timezone
from django.utils.dateparse import parse_datetime
from django.utils.timezone import make_aware, is_naive
from django.db import transaction

from decimal import Decimal

from .models import Booking
from .serializers import BookingSerializer
from parking.models import ParkingSlot, SystemSettings
from parking.pricing import preview_for_slot
from notifications.services import notify
from payments.services import process_booking_refund
from sps_backend.events import emit


def compute_refund(booking):
    """
    Proposal refund policy, driven by admin-configurable SystemSettings:
        - not yet paid                   → cancellable, nothing to refund
        - paid, vehicle not entered     → 100% (refund_100_before_start)
        - paid, within refund window
          after entry                   → refund_percent (default 50%)
        - paid, past the window         → NOT cancellable (exit normally)
    Returns a dict used by both the preview endpoint and the cancel view,
    so the number the user sees in the dialog is always the number that
    gets refunded.
    """
    s = SystemSettings.get()
    paid = booking.payment_status == "paid"
    amount = Decimal(str(booking.estimated_amount or 0))

    def result(cancellable, percent, reason):
        refund = (amount * Decimal(percent) / Decimal(100)).quantize(
            Decimal("0.01")) if (paid and cancellable) else Decimal("0.00")
        return {
            "cancellable": cancellable,
            "refund_percent": percent if paid else 0,
            "refund_amount": refund,
            "paid": paid,
            "reason": reason,
        }

    status_ = booking.status
    if status_ == "pending_payment":
        return result(True, 0, "No payment made — nothing to refund.")

    if status_ == "confirmed":
        pct = 100 if s.refund_100_before_start else s.refund_percent
        return result(True, pct, "Vehicle has not entered — full refund.")

    if status_ == "active":
        window = timezone.timedelta(minutes=s.refund_window_minutes)
        # entry_time should always be set for active bookings; if it somehow
        # isn't, err in the user's favour and treat as within the window.
        if booking.entry_time is None or timezone.now() <= booking.entry_time + window:
            return result(True, s.refund_percent,
                          f"Within {s.refund_window_minutes} min of entry — "
                          f"{s.refund_percent}% refund.")
        return result(False, 0,
                      f"More than {s.refund_window_minutes} minutes since entry — "
                      "no refund. Please exit normally.")

    return result(False, 0, f"A {status_} booking cannot be cancelled.")

# Adopted from backend_ali: if a booking is created but payment isn't made
# within this window, the slot is auto-released next time anyone hits the
# booking list/create endpoints — a stand-in for a scheduled job.
RESERVATION_TIMEOUT_MINUTES = 15

# Cleanup runs at most once per this many seconds, no matter how many
# requests come in — keeps housekeeping out of the request hot path.
_CLEANUP_THROTTLE_SECONDS = 30
_last_cleanup_ts = 0.0


def release_expired_reservations():
    global _last_cleanup_ts
    import time as _time
    now_ts = _time.monotonic()
    if now_ts - _last_cleanup_ts < _CLEANUP_THROTTLE_SECONDS:
        return
    _last_cleanup_ts = now_ts

    cutoff = timezone.now() - timezone.timedelta(minutes=RESERVATION_TIMEOUT_MINUTES)
    expired = Booking.objects.filter(
        status='pending_payment',
        created_at__lt=cutoff,
    )
    slot_ids = list(expired.values_list('parking_slot_id', flat=True))
    if not slot_ids:
        return
    # Two bulk UPDATEs instead of 2 queries per expired booking.
    ParkingSlot.objects.filter(id__in=slot_ids).update(
        is_reserved=False, is_occupied=False)
    expired.update(status='expired')


class BookingView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        release_expired_reservations()
        bookings = Booking.objects.filter(user=request.user).select_related(
            'user', 'vehicle', 'parking_slot', 'parking_slot__parking_site'
        ).order_by("-created_at")
        serializer = BookingSerializer(bookings, many=True, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request):
        release_expired_reservations()

        with transaction.atomic():
            slot_id = request.data.get('parking_slot')
            try:
                slot = ParkingSlot.objects.select_for_update().get(pk=slot_id)
            except ParkingSlot.DoesNotExist:
                return Response(
                    {"error": "Slot not found"},
                    status=status.HTTP_404_NOT_FOUND
                )

            if slot.is_occupied:
                return Response(
                    {"error": "Slot is already occupied"},
                    status=status.HTTP_400_BAD_REQUEST
                )

            serializer = BookingSerializer(data=request.data, context={'request': request})
            if serializer.is_valid():
                # estimated_amount is server-computed (read-only on the
                # serializer) — always priced by the site's pricing_type,
                # never trusted from the client. Same formula the gate will
                # charge at actual exit, so the quote and the bill match.
                entry = serializer.validated_data.get('entry_time')
                exit_ = serializer.validated_data.get('exit_time')
                vehicle = serializer.validated_data.get('vehicle')
                vehicle_type = vehicle.vehicle_type if vehicle else "car"

                estimated_amount = None
                if entry and exit_:
                    estimated_amount = preview_for_slot(
                        slot, entry, exit_, vehicle_type=vehicle_type
                    )

                # New booking = pending_payment (slot reserved, awaiting payment)
                booking = serializer.save(
                    user=request.user,
                    status="pending_payment",
                    estimated_amount=estimated_amount,
                )
                slot.is_reserved = True
                slot.is_occupied = False
                emit("slots.changed", site_id=slot.parking_site_id)
                emit("bookings.changed", site_id=slot.parking_site_id)
                slot.save()
                return Response(serializer.data, status=status.HTTP_201_CREATED)

            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class BookingDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get_object(self, pk, user):
        try:
            return Booking.objects.get(pk=pk, user=user)
        except Booking.DoesNotExist:
            return None

    def get(self, request, pk):
        booking = self.get_object(pk, request.user)
        if booking is None:
            return Response(
                {"error": "Booking not found"},
                status=status.HTTP_404_NOT_FOUND
            )
        serializer = BookingSerializer(booking, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)

    def put(self, request, pk):
        with transaction.atomic():
            booking = self.get_object(pk, request.user)
            if booking is None:
                return Response(
                    {"error": "Booking not found"},
                    status=status.HTTP_404_NOT_FOUND
                )

            if booking.status != "active":
                return Response(
                    {"error": "Only active bookings can be completed"},
                    status=status.HTTP_400_BAD_REQUEST
                )

            serializer = BookingSerializer(booking, data=request.data, partial=True, context={'request': request})
            if serializer.is_valid():
                serializer.save(status="completed")
                slot = booking.parking_slot
                slot.is_occupied = False
                slot.is_reserved = False
                slot.save()
                return Response(serializer.data, status=status.HTTP_200_OK)

            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        with transaction.atomic():
            booking = self.get_object(pk, request.user)
            if booking is None:
                return Response(
                    {"error": "Booking not found"},
                    status=status.HTTP_404_NOT_FOUND
                )

            # Refund policy decides cancellability now (proposal §1.4):
            # unpaid/confirmed always cancellable; active only within the
            # refund window after entry; past that — exit normally.
            policy = compute_refund(booking)
            if not policy["cancellable"]:
                return Response(
                    {"error": policy["reason"]},
                    status=status.HTTP_400_BAD_REQUEST
                )

            slot = booking.parking_slot
            slot.is_reserved = False
            slot.is_occupied = False
            slot.save()
            emit("slots.changed", site_id=slot.parking_site_id)
            emit("bookings.changed", site_id=slot.parking_site_id)

            booking.status = "cancelled"
            booking.save()

            # Same atomic block as the cancel itself — if the refund fails,
            # the cancellation rolls back with it (no cancelled-but-unrefunded
            # bookings, no refunded-but-still-active ones).
            refund_amount = policy["refund_amount"]
            if refund_amount > 0:
                process_booking_refund(
                    booking, refund_amount, policy["refund_percent"]
                )

            notify(
                request.user,
                "Booking Cancelled",
                f"Booking #{str(booking.id)[:8].upper()} — slot {slot.slot_number} has been cancelled.",
                "booking_cancelled",
            )

            return Response(
                {
                    "message": "Booking cancelled successfully",
                    "refund_percent": policy["refund_percent"],
                    "refund_amount": str(refund_amount),
                },
                status=status.HTTP_200_OK
            )


class BookingExtendView(APIView):
    permission_classes = [IsAuthenticated]

    def get_object(self, pk, user):
        try:
            return Booking.objects.get(pk=pk, user=user)
        except Booking.DoesNotExist:
            return None

    def put(self, request, pk):
        with transaction.atomic():
            booking = self.get_object(pk=pk, user=request.user)
            if booking is None:
                return Response(
                    {"error": "Booking not found"},
                    status=status.HTTP_404_NOT_FOUND
                )

            if booking.status != "active":
                return Response(
                    {"error": "Only active bookings can be extended"},
                    status=status.HTTP_400_BAD_REQUEST
                )

            if booking.extension_count >= 3:
                return Response(
                    {"error": "Maximum extension limit reached"},
                    status=status.HTTP_400_BAD_REQUEST
                )

            new_exit_time = parse_datetime(request.data.get("extended_exit_time", ""))
            if not new_exit_time:
                return Response(
                    {"error": "Invalid date format. Use ISO 8601 UTC e.g. 2025-06-01T14:00:00Z"},
                    status=status.HTTP_400_BAD_REQUEST
                )

            if is_naive(new_exit_time):
                new_exit_time = make_aware(new_exit_time)

            if new_exit_time < timezone.now():
                return Response(
                    {"error": "Extended time cannot be in the past"},
                    status=status.HTTP_400_BAD_REQUEST
                )

            current_exit = booking.actual_exit_time
            if current_exit and new_exit_time <= current_exit:
                return Response(
                    {"error": "Extended time must be after current exit time"},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Find the next booking on this slot that starts after the
            # current exit time, so we don't extend into someone else's
            # reservation. FIX: 'confirmed'/'pending_payment' bhi upcoming
            # reservations hain — sirf 'active' dekhne se paid booking ke
            # window me extend ho jata tha.
            next_booking = Booking.objects.filter(
                parking_slot=booking.parking_slot,
                status__in=['active', 'confirmed', 'pending_payment'],
                entry_time__gt=current_exit,
            ).exclude(pk=booking.pk).order_by('entry_time').first()

            if next_booking and new_exit_time > next_booking.entry_time:
                max_extend_until = next_booking.entry_time.strftime('%I:%M %p')
                max_extend_date = next_booking.entry_time.strftime('%d %b %Y')
                return Response(
                    {
                        "error": (
                            f"Cannot extend until {new_exit_time.strftime('%I:%M %p')} — "
                            f"slot is booked by another user from {max_extend_until} on {max_extend_date}. "
                            f"You can only extend up to {max_extend_until}."
                        ),
                        "max_extend_until": next_booking.entry_time.isoformat(),
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            booking.extended_exit_time = new_exit_time
            booking.extension_count += 1
            booking.save()

            notify(
                request.user,
                "Booking Extended",
                f"Exit time moved to {new_exit_time.strftime('%I:%M %p, %d %b')} "
                f"(extension {booking.extension_count}/3).",
                "booking_extended",
            )

            return Response(
                {"message": "Time extended successfully"},
                status=status.HTTP_200_OK
            )


class OwnerBookingView(APIView):
    """
    GET /api/bookings/owner/
    Returns all bookings for parking sites owned by the authenticated user.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.role != 'parking_owner':
            return Response({'error': 'Permission denied. Must be a parking owner.'}, status=status.HTTP_403_FORBIDDEN)

        from parking.models import ParkingSite

        sites = ParkingSite.objects.filter(owner=request.user)

        bookings = Booking.objects.filter(
            parking_slot__parking_site__in=sites
        ).select_related(
            'user', 'vehicle', 'parking_slot', 'parking_slot__parking_site'
        ).order_by('-created_at')

        serializer = BookingSerializer(bookings, many=True, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)


class AdminBookingView(APIView):
    """
    GET /api/bookings/admin/
    Returns all bookings for the admin.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.role != 'admin':
            return Response({'error': 'Permission denied. Must be an admin.'}, status=status.HTTP_403_FORBIDDEN)

        bookings = Booking.objects.select_related(
            'user', 'vehicle', 'parking_slot', 'parking_slot__parking_site'
        ).order_by('-created_at')

        serializer = BookingSerializer(bookings, many=True, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)


class BookingPriceEstimateView(APIView):
    """
    POST /api/bookings/estimate/
    Body: { "slot_id": "...", "entry_time": ISO, "exit_time": ISO, "vehicle_id": "..." (optional) }
    Lets the app show the exact price it will be charged BEFORE booking —
    same formula (parking.pricing.calculate_amount) used at booking-create
    time and at the gate, so this number and the eventual charge match.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        slot_id = request.data.get("slot_id")
        entry_s = request.data.get("entry_time")
        exit_s = request.data.get("exit_time")
        vehicle_id = request.data.get("vehicle_id")

        if not all([slot_id, entry_s, exit_s]):
            return Response(
                {"error": "slot_id, entry_time and exit_time are required"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        entry = parse_datetime(entry_s)
        exit_ = parse_datetime(exit_s)
        if not entry or not exit_:
            return Response(
                {"error": "entry_time/exit_time must be ISO 8601"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if is_naive(entry):
            entry = make_aware(entry)
        if is_naive(exit_):
            exit_ = make_aware(exit_)
        if exit_ <= entry:
            return Response({"error": "exit_time must be after entry_time"}, status=status.HTTP_400_BAD_REQUEST)

        try:
            slot = ParkingSlot.objects.select_related("parking_site").get(pk=slot_id)
        except (ParkingSlot.DoesNotExist, ValueError):
            return Response({"error": "Slot not found"}, status=status.HTTP_404_NOT_FOUND)

        vehicle_type = "car"
        if vehicle_id:
            from parking.models import Vehicle
            try:
                vehicle_type = Vehicle.objects.get(pk=vehicle_id).vehicle_type
            except (Vehicle.DoesNotExist, ValueError):
                pass

        amount = preview_for_slot(slot, entry, exit_, vehicle_type=vehicle_type)
        site = slot.parking_site

        return Response({
            "estimated_amount": amount,
            "pricing_type": site.pricing_type if site else "flat",
            "flat_hours": site.flat_hours if site else None,
        }, status=status.HTTP_200_OK)


class RefundPreviewView(APIView):
    """
    GET /api/bookings/<uuid:pk>/refund-preview/
    Called by the app's cancel dialog BEFORE cancelling, so the user sees
    exactly what they'll get back. Uses the same compute_refund() as the
    cancel view — the previewed number is the refunded number.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        try:
            booking = Booking.objects.get(pk=pk, user=request.user)
        except Booking.DoesNotExist:
            return Response(
                {"error": "Booking not found"},
                status=status.HTTP_404_NOT_FOUND
            )

        policy = compute_refund(booking)
        return Response({
            "cancellable": policy["cancellable"],
            "paid": policy["paid"],
            "refund_percent": policy["refund_percent"],
            "refund_amount": str(policy["refund_amount"]),
            "reason": policy["reason"],
        }, status=status.HTTP_200_OK)


# ═══════════════════════ PARKING PASSES ═══════════════════════
# Weekly commuter passes — dedicated slot, daily time window,
# one discounted upfront payment, AI gate recognises the plate.

from datetime import datetime, timedelta as _timedelta

from django.conf import settings as django_settings

from .models import ParkingPass
from .serializers import ParkingPassSerializer
from parking.models import Vehicle
from payments.services import (
    charge_wallet_split, process_pass_refund, InsufficientBalance,
)

# Discount tiers by duration — override in settings.py if needed.
PASS_DISCOUNTS = getattr(django_settings, "PARKING_PASS_DISCOUNTS", {1: 10, 2: 15, 4: 25})


def _compute_pass_price(slot, duration_weeks, daily_start, daily_end):
    """
    gross  = hourly rate × window hours × days
    net    = gross − tier discount
    Returns (gross, net, discount_percent, daily_hours, days).
    """
    rate = slot.price_per_hour or slot.parking_site.rate_per_hour or Decimal("0")
    rate = Decimal(str(rate))

    window_seconds = (
        datetime.combine(datetime.today(), daily_end)
        - datetime.combine(datetime.today(), daily_start)
    ).total_seconds()
    daily_hours = Decimal(str(window_seconds / 3600))

    days = duration_weeks * 7
    gross = (rate * daily_hours * days).quantize(Decimal("0.01"))
    discount = PASS_DISCOUNTS.get(duration_weeks, 0)
    net = (gross * (Decimal(100 - discount) / Decimal(100))).quantize(Decimal("0.01"))
    return gross, net, discount, daily_hours, days


def _parse_pass_request(request):
    """Shared validation for preview and purchase. Returns (data, error)."""
    slot_id = request.data.get("slot_id")
    duration_weeks = request.data.get("duration_weeks")
    daily_start_s = request.data.get("daily_start")  # "HH:MM"
    daily_end_s = request.data.get("daily_end")
    start_date_s = request.data.get("start_date")    # optional, default today

    if not all([slot_id, duration_weeks, daily_start_s, daily_end_s]):
        return None, "slot_id, duration_weeks, daily_start and daily_end are required"

    try:
        duration_weeks = int(duration_weeks)
    except (TypeError, ValueError):
        return None, "duration_weeks must be a number"
    if duration_weeks not in PASS_DISCOUNTS:
        return None, f"duration_weeks must be one of {sorted(PASS_DISCOUNTS)}"

    try:
        daily_start = datetime.strptime(daily_start_s, "%H:%M").time()
        daily_end = datetime.strptime(daily_end_s, "%H:%M").time()
    except ValueError:
        return None, "daily_start/daily_end must be HH:MM (24h)"
    if daily_end <= daily_start:
        return None, "daily_end must be after daily_start"

    if start_date_s:
        try:
            start_date = datetime.strptime(start_date_s, "%Y-%m-%d").date()
        except ValueError:
            return None, "start_date must be YYYY-MM-DD"
        if start_date < timezone.localdate():
            return None, "start_date cannot be in the past"
    else:
        start_date = timezone.localdate()

    try:
        slot = ParkingSlot.objects.select_related("parking_site").get(pk=slot_id)
    except (ParkingSlot.DoesNotExist, ValueError, Exception):
        return None, "Slot not found"

    return {
        "slot": slot,
        "duration_weeks": duration_weeks,
        "daily_start": daily_start,
        "daily_end": daily_end,
        "start_date": start_date,
        "end_date": start_date + _timedelta(weeks=duration_weeks) - _timedelta(days=1),
    }, None


class PassPreviewView(APIView):
    """POST /api/bookings/passes/preview/ — price breakdown before purchase."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        data, err = _parse_pass_request(request)
        if err:
            return Response({"error": err}, status=status.HTTP_400_BAD_REQUEST)

        slot = data["slot"]
        gross, net, discount, daily_hours, days = _compute_pass_price(
            slot, data["duration_weeks"], data["daily_start"], data["daily_end"]
        )

        slot_taken = slot.is_reserved or slot.is_occupied
        return Response({
            "available": not slot_taken,
            "site_name": slot.parking_site.name,
            "slot_number": slot.slot_number,
            "start_date": str(data["start_date"]),
            "end_date": str(data["end_date"]),
            "days": days,
            "daily_hours": float(daily_hours),
            "hourly_total": str(gross),
            "discount_percent": discount,
            "pass_price": str(net),
            "savings": str((gross - net).quantize(Decimal("0.01"))),
        }, status=status.HTTP_200_OK)


class PassView(APIView):
    """
    GET  /api/bookings/passes/  — my passes (lazy-expires stale ones)
    POST /api/bookings/passes/  — purchase: reserve slot + pay from wallet
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        passes = (ParkingPass.objects
                  .filter(user=request.user)
                  .select_related("parking_slot", "parking_slot__parking_site", "vehicle")
                  .order_by("-created_at"))
        for p in passes:
            p.expire_if_needed()
        serializer = ParkingPassSerializer(passes, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request):
        data, err = _parse_pass_request(request)
        if err:
            return Response({"error": err}, status=status.HTTP_400_BAD_REQUEST)

        vehicle_id = request.data.get("vehicle_id")
        if not vehicle_id:
            return Response({"error": "vehicle_id is required"},
                            status=status.HTTP_400_BAD_REQUEST)
        try:
            vehicle = Vehicle.objects.get(pk=vehicle_id, user=request.user)
        except (Vehicle.DoesNotExist, ValueError, Exception):
            return Response({"error": "Vehicle not found"},
                            status=status.HTTP_404_NOT_FOUND)

        # One active pass per vehicle — the gate check is plate-driven,
        # two simultaneous passes for one plate would be ambiguous.
        if ParkingPass.objects.filter(vehicle=vehicle, status="active").exists():
            return Response({"error": "This vehicle already has an active pass"},
                            status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            # Lock the slot row — two users buying the same slot at the
            # same moment must serialise here.
            slot = ParkingSlot.objects.select_for_update().select_related(
                "parking_site").get(pk=data["slot"].pk)
            if slot.is_reserved or slot.is_occupied:
                return Response({"error": "Slot is no longer available"},
                                status=status.HTTP_400_BAD_REQUEST)

            gross, net, discount, _, _ = _compute_pass_price(
                slot, data["duration_weeks"], data["daily_start"], data["daily_end"]
            )

            pass_obj = ParkingPass.objects.create(
                user=request.user,
                vehicle=vehicle,
                parking_slot=slot,
                start_date=data["start_date"],
                end_date=data["end_date"],
                daily_start=data["daily_start"],
                daily_end=data["daily_end"],
                duration_weeks=data["duration_weeks"],
                amount=net,
                discount_percent=discount,
            )

            try:
                charge_wallet_split(
                    user=request.user,
                    owner=slot.parking_site.owner,
                    amount=net,
                    description=(f"Parking pass ({data['duration_weeks']}w) — "
                                 f"slot {slot.slot_number}, #{str(pass_obj.id)[:8].upper()}"),
                    notify_title="Parking Pass Activated",
                    notify_message=(f"Your {data['duration_weeks']}-week pass for slot "
                                    f"{slot.slot_number} at {slot.parking_site.name} is active "
                                    f"({data['start_date']} to {data['end_date']})."),
                    notify_type="payment_success",
                )
            except InsufficientBalance:
                # atomic block rolls the pass + slot back automatically on raise,
                # but we return a clean 400 instead of a 500:
                transaction.set_rollback(True)
                return Response(
                    {"error": "Insufficient wallet balance. Please top up first."},
                    status=status.HTTP_400_BAD_REQUEST)

            # Dedicated slot: reserved for the entire pass duration.
            slot.is_reserved = True
            slot.save()
            emit("slots.changed", site_id=slot.parking_site_id)

        serializer = ParkingPassSerializer(pass_obj)
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class PassDetailView(APIView):
    """DELETE /api/bookings/passes/<uuid:pk>/ — cancel with prorated refund."""
    permission_classes = [IsAuthenticated]

    def delete(self, request, pk):
        with transaction.atomic():
            try:
                pass_obj = (ParkingPass.objects.select_for_update()
                            .select_related("parking_slot", "parking_slot__parking_site")
                            .get(pk=pk, user=request.user))
            except ParkingPass.DoesNotExist:
                return Response({"error": "Pass not found"},
                                status=status.HTTP_404_NOT_FOUND)

            pass_obj.expire_if_needed()
            if pass_obj.status != "active":
                return Response({"error": f"A {pass_obj.status} pass cannot be cancelled"},
                                status=status.HTTP_400_BAD_REQUEST)

            # Prorated refund on remaining full days (today counts as used).
            today = timezone.localdate()
            total_days = (pass_obj.end_date - pass_obj.start_date).days + 1
            remaining_days = max((pass_obj.end_date - today).days, 0)
            refund = (Decimal(str(pass_obj.amount)) * remaining_days / total_days
                      ).quantize(Decimal("0.01"))
            percent = int(remaining_days * 100 / total_days) if total_days else 0

            pass_obj.status = "cancelled"
            pass_obj.save()

            slot = pass_obj.parking_slot
            if not slot.is_occupied:
                slot.is_reserved = False
                slot.save()
                emit("slots.changed", site_id=slot.parking_site_id)

            if refund > 0:
                process_pass_refund(pass_obj, refund, percent)

            return Response({
                "message": "Pass cancelled",
                "refund_amount": str(refund),
                "remaining_days": remaining_days,
            }, status=status.HTTP_200_OK)