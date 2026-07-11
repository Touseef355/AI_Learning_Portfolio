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
        ("wallet", "Wallet"),
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

class ParkingPass(models.Model):
    """
    Weekly parking pass (proposal extension — supervisor request):
    a commuter books a DEDICATED slot at a site for 1/2/4 weeks with a
    daily time window (e.g. 9:00–18:00), pays once at a discounted rate,
    and the AI entry/exit flow recognises the plate — no per-day payment.

    The slot stays is_reserved=True for the pass's whole duration, so
    hourly bookings can never collide with it. Occupancy toggles daily
    with entry/exit; reservation only releases on expiry/cancellation.
    """
    STATUS_CHOICES = (
        ("active",    "Active"),
        ("expired",   "Expired"),
        ("cancelled", "Cancelled"),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="parking_passes",
    )
    vehicle = models.ForeignKey(
        "parking.Vehicle",
        on_delete=models.CASCADE,
        related_name="parking_passes",
    )
    parking_slot = models.ForeignKey(
        "parking.ParkingSlot",
        on_delete=models.CASCADE,
        related_name="parking_passes",
    )
    start_date = models.DateField()
    end_date = models.DateField()
    daily_start = models.TimeField()
    daily_end = models.TimeField()
    duration_weeks = models.PositiveSmallIntegerField()
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    discount_percent = models.PositiveSmallIntegerField(default=0)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="active")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "parking_passes"
        indexes = [
            models.Index(fields=["vehicle", "status"]),
            models.Index(fields=["user", "status"]),
        ]

    def __str__(self):
        return f"Pass {str(self.id)[:8]} — {self.vehicle.plate_number} ({self.status})"

    # ── Validity helpers (used by app endpoints AND the AI gate flow) ──

    def expire_if_needed(self):
        """Lazy expiry — no cron/celery needed. Call before trusting status."""
        from django.utils import timezone
        if self.status == "active" and timezone.localdate() > self.end_date:
            self.status = "expired"
            self.save(update_fields=["status"])
            # Release the dedicated slot back into the pool.
            slot = self.parking_slot
            if slot.is_reserved and not slot.is_occupied:
                slot.is_reserved = False
                slot.save(update_fields=["is_reserved"])
        return self

    @classmethod
    def valid_for(cls, vehicle, at=None, site=None):
        """
        Return the vehicle's pass if it is active, in date range, and the
        current local time falls inside the daily window — else None.
        This is THE gate check used by the AI entry/exit flow.
        """
        from django.utils import timezone
        at = at or timezone.localtime()
        qs = cls.objects.filter(vehicle=vehicle, status="active",
                                start_date__lte=at.date(),
                                end_date__gte=at.date())
        if site is not None:
            # Site A ka pass Site B ke gate pe valid nahi.
            qs = qs.filter(parking_slot__parking_site=site)
        p = (qs
             .select_related("parking_slot", "parking_slot__parking_site")
             .first())
        if not p:
            return None
        p.expire_if_needed()
        if p.status != "active":
            return None
        if p.daily_start <= at.time() <= p.daily_end:
            return p
        return None

    def overstay_amount(self, at=None):
        """
        Rs. due if the pass holder exits at `at`:
            0 within the daily window + grace_period_minutes;
            afterwards, ceil-hours × SystemSettings.overstay_rate_per_hour.
        Returns (amount: Decimal, hours: int).
        """
        import math
        from datetime import datetime, timedelta
        from decimal import Decimal
        from django.utils import timezone
        from parking.models import SystemSettings

        s = SystemSettings.get()
        at_local = timezone.localtime(at or timezone.now())

        day_end = timezone.make_aware(
            datetime.combine(at_local.date(), self.daily_end),
            timezone.get_current_timezone(),
        )
        deadline = day_end + timedelta(minutes=s.grace_period_minutes)

        if at_local <= deadline:
            return Decimal("0.00"), 0

        over_seconds = (at_local - deadline).total_seconds()
        hours = max(1, math.ceil(over_seconds / 3600))
        rate = Decimal(str(s.overstay_rate_per_hour))
        return (rate * hours).quantize(Decimal("0.01")), hours
