from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils import timezone
from django.utils.dateparse import parse_datetime
from django.utils.timezone import make_aware, is_naive
from django.db import transaction

from .models import Booking
from .serializers import BookingSerializer
from parking.models import ParkingSlot

# Adopted from backend_ali: if a booking is created but payment isn't made
# within this window, the slot is auto-released next time anyone hits the
# booking list/create endpoints — a stand-in for a scheduled job.
RESERVATION_TIMEOUT_MINUTES = 15


def release_expired_reservations():
    cutoff = timezone.now() - timezone.timedelta(minutes=RESERVATION_TIMEOUT_MINUTES)
    expired = Booking.objects.filter(
        status='pending_payment',
        created_at__lt=cutoff,
    ).select_related('parking_slot')

    for booking in expired:
        slot = booking.parking_slot
        if slot:
            slot.is_reserved = False
            slot.is_occupied = False
            slot.save()
        booking.status = 'expired'
        booking.save()


class BookingView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        release_expired_reservations()
        bookings = Booking.objects.filter(user=request.user).order_by("-created_at")
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
                # New booking = pending_payment (slot reserved, awaiting payment)
                booking = serializer.save(user=request.user, status="pending_payment")
                slot.is_reserved = True
                slot.is_occupied = False
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

            # Only bookings that haven't physically started can be cancelled;
            # once "active" (vehicle inside), it must be completed via exit,
            # not cancelled.
            if booking.status not in ("pending_payment", "confirmed"):
                return Response(
                    {"error": "Only pending or confirmed bookings can be cancelled"},
                    status=status.HTTP_400_BAD_REQUEST
                )

            slot = booking.parking_slot
            slot.is_reserved = False
            slot.is_occupied = False
            slot.save()

            booking.status = "cancelled"
            booking.save()

            return Response(
                {"message": "Booking cancelled successfully"},
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
            # reservation.
            next_booking = Booking.objects.filter(
                parking_slot=booking.parking_slot,
                status='active',
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
