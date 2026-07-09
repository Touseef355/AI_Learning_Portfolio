from rest_framework import serializers
from django.utils import timezone

from .models import Booking
from parking.models import ParkingSlot, Vehicle

BUFFER_MINUTES = 15  # gap required between consecutive bookings on the same slot


class BookingSerializer(serializers.ModelSerializer):

    # ── Read-only display fields ──────────────────────────────────────────────
    user                = serializers.StringRelatedField(read_only=True)
    duration            = serializers.SerializerMethodField()
    vehicle_plate       = serializers.SerializerMethodField()
    vehicle_name        = serializers.SerializerMethodField()
    slot_number         = serializers.SerializerMethodField()
    user_name           = serializers.SerializerMethodField()
    parking_slot_detail = serializers.SerializerMethodField()

    # ── Writable FK fields ────────────────────────────────────────────────────
    parking_slot = serializers.PrimaryKeyRelatedField(
        queryset=ParkingSlot.objects.all()
    )
    vehicle = serializers.PrimaryKeyRelatedField(
        queryset=Vehicle.objects.all(),
        required=False,
        allow_null=True,
    )

    class Meta:
        model  = Booking
        fields = [
            'id', 'user', 'user_name',
            'parking_slot', 'parking_slot_detail', 'slot_number',
            'vehicle', 'vehicle_plate', 'vehicle_name',
            'entry_time', 'exit_time', 'extended_exit_time', 'extension_count',
            'status', 'payment_status', 'payment_method',
            'estimated_amount', 'overstay_grace', 'duration', 'created_at',
        ]
        read_only_fields = [
            'id', 'user', 'status', 'payment_status', 'payment_method',
            'created_at', 'parking_slot_detail', 'slot_number',
            'vehicle_plate', 'vehicle_name', 'user_name', 'duration',
        ]

    # ── Display helpers ───────────────────────────────────────────────────────

    def get_parking_slot_detail(self, obj):
        if not obj.parking_slot:
            return None
        slot = obj.parking_slot
        site = slot.parking_site
        return {
            "id": str(slot.id), "slot_number": slot.slot_number,
            "slot_type": slot.slot_type, "is_occupied": slot.is_occupied,
            "is_reserved": slot.is_reserved,
            "site_name": site.name if site else None,
            "site_id": str(site.id) if site else None,
        }

    def get_slot_number(self, obj):
        return obj.parking_slot.slot_number if obj.parking_slot else None

    def get_vehicle_plate(self, obj):
        # obj.vehicle_plate is the model property: prefers the real FK,
        # falls back to the pre-fix legacy string column.
        return obj.vehicle_plate

    def get_vehicle_name(self, obj):
        return obj.vehicle.name if obj.vehicle else None

    def get_user_name(self, obj):
        return obj.user.full_name if obj.user else 'Walk-in'

    def get_duration(self, obj):
        if obj.exit_time and obj.entry_time:
            delta = obj.exit_time - obj.entry_time
            hours, remainder = divmod(int(delta.total_seconds()), 3600)
            minutes = remainder // 60
            return f"{hours}h {minutes}m"
        return None

    # ── Validation ────────────────────────────────────────────────────────────

    def validate_entry_time(self, value):
        if value < timezone.now() - timezone.timedelta(minutes=5):
            raise serializers.ValidationError("Entry time cannot be in the past")
        return value

    def validate_exit_time(self, value):
        if value and value < timezone.now():
            raise serializers.ValidationError("Exit time cannot be in the past")
        return value

    def validate(self, data):
        slot  = data.get('parking_slot')
        entry = data.get('entry_time')
        exit_ = data.get('exit_time')
        user  = self.context['request'].user if 'request' in self.context else None

        if entry and exit_ and exit_ <= entry:
            raise serializers.ValidationError("Exit time must be after entry time")

        if entry and exit_:
            mins = (exit_ - entry).total_seconds() / 60
            if mins < 15:
                raise serializers.ValidationError("Minimum booking duration is 15 minutes")

        # One active booking per vehicle at a time
        vehicle = data.get('vehicle')
        if vehicle and user:
            active_exists = Booking.objects.filter(
                vehicle=vehicle,
                status='active',
            ).exists()
            if active_exists:
                raise serializers.ValidationError(
                    "This vehicle already has an active booking. "
                    "Cancel or complete it before making a new one."
                )

        # 15-minute buffer overlap check for the same slot. Two windows
        # overlap when: existing.entry < our_exit AND existing.exit > our_entry
        # (existing booking's exit padded by the buffer).
        if slot and entry and exit_:
            buffer = timezone.timedelta(minutes=BUFFER_MINUTES)
            overlap = Booking.objects.filter(
                parking_slot=slot,
                status='active',
                entry_time__lt=exit_,
                exit_time__gt=entry - buffer,
            ).exists()
            if overlap:
                raise serializers.ValidationError(
                    f"This slot is already booked for the selected time. "
                    f"Note: a {BUFFER_MINUTES}-minute gap is required between bookings."
                )

        if slot and slot.is_occupied:
            raise serializers.ValidationError("This slot is currently occupied")

        return data
