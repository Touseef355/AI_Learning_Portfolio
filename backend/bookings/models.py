import uuid
from django.db import models
from django.conf import settings


class Booking(models.Model):
    # Adopted from backend_ali — a strict superset of backend_friend's
    # active/completed/cancelled. pending_payment/confirmed/expired are
    # needed for the wallet payment flow (payments phase) to have somewhere
    # to put a booking that's reserved but not yet paid for.
    STATUS_CHOICES = (
        ("pending_payment", "Pending Payment"),
        ("confirmed",       "Confirmed"),
        ("active",          "Active"),
        ("completed",       "Completed"),
        ("cancelled",       "Cancelled"),
        ("expired",         "Expired"),
    )
    PAYMENT_STATUS = (
        ("pending", "Pending"),
        ("paid", "Paid"),
        ("failed", "Failed"),
    )
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    user = models.ForeignKey(
    settings.AUTH_USER_MODEL,
    on_delete=models.SET_NULL,
    null=True,
    blank=True,
    related_name="bookings"
    )
    parking_slot = models.ForeignKey(
        'parking.ParkingSlot',  # string reference
        on_delete=models.CASCADE, related_name="bookings"
    )

    # Real FK, restored from backend_ali — the live "vehicle_id" column is a
    # plate-number string (see legacy_vehicle_plate below), so this uses a
    # distinct db_column rather than reusing it. SET_NULL so vehicle
    # deletion doesn't lose historical booking data.
    vehicle = models.ForeignKey(
        'parking.Vehicle',
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name="bookings",
        db_column='vehicle_fk_id',
    )

    # The pre-fix column: a plain plate-number string, kept only because
    # accounts/views.py and payments/views.py already display
    # `booking.vehicle_plate` and older rows may not have a matching Vehicle
    # to backfill `vehicle` from. Not written to by new code — see the
    # vehicle_plate property below, which is what those call sites now read.
    legacy_vehicle_plate = models.CharField(
        max_length=50,
        db_column='vehicle_id',
        null=True, blank=True,
    )

    @property
    def vehicle_plate(self):
        if self.vehicle_id:
            return self.vehicle.plate_number
        return self.legacy_vehicle_plate

    entry_time = models.DateTimeField(null=True, blank=True, db_column='entry_datetime')
    exit_time = models.DateTimeField(null=True, blank=True, db_column='exit_datetime')
    extended_exit_time = models.DateTimeField(null=True, blank=True)
    extension_count = models.IntegerField(default=0)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="pending_payment")
    payment_status = models.CharField(max_length=20, choices=PAYMENT_STATUS, default="pending")
    PAYMENT_METHOD_CHOICES = (
        ("cash", "Cash"),
        ("online", "Online"),
    )
    payment_method = models.CharField(
        max_length=20, 
        choices=PAYMENT_METHOD_CHOICES, 
        null=True, blank=True
    )
    overstay_grace = models.BooleanField(default=True)
    estimated_amount = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "bookings"
        indexes = [models.Index(fields=["entry_time"])]

    @property
    def duration(self):
        if self.exit_time:
            return self.exit_time - self.entry_time
        return None
    @property
    def actual_exit_time(self):
        if self.extended_exit_time:
            return self.extended_exit_time  # Extended time use here
        return self.exit_time               # Normal exit time


    def __str__(self):
        return f"Booking {self.id} — {self.vehicle_plate}"