import uuid
from django.db import models
from django.conf import settings


class ParkingSite(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="owned_sites"
    )
    name = models.CharField(max_length=100)
    location = models.CharField(max_length=255)
    capacity = models.IntegerField()
    address = models.TextField(null=True, blank=True)
    phone = models.CharField(max_length=20, null=True, blank=True)
    email = models.CharField(max_length=100, null=True, blank=True)
    total_slots = models.IntegerField(null=True, blank=True)
    total_floors = models.IntegerField(null=True, blank=True)
    opening_time = models.TimeField(null=True, blank=True)
    closing_time = models.TimeField(null=True, blank=True)
    status = models.CharField(max_length=50, null=True, blank=True)
    price_per_hour = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    contact_number = models.CharField(max_length=20, null=True, blank=True)
    city = models.TextField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "parking_sites"

    def __str__(self):
        return self.name


class ParkingSlot(models.Model):
    SLOT_TYPE_CHOICES = (
        ("normal", "Normal"),
        ("vip", "VIP"),
        ("disabled", "Disabled")
    )
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    parking_site = models.ForeignKey(
        ParkingSite,
        on_delete=models.CASCADE,
        related_name="slots",
        db_column="site_id"
    )
    slot_number = models.CharField(max_length=20)
    slot_type = models.CharField(max_length=20, choices=SLOT_TYPE_CHOICES)
    is_occupied = models.BooleanField(default=False)
    is_reserved = models.BooleanField(default=False)
    # Base price per hour for this slot
    price_per_hour = models.DecimalField(max_digits=8, decimal_places=2, null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "parking_slots"
        unique_together = ("parking_site", "slot_number")

    def __str__(self):
        return f"{self.slot_number} ({self.slot_type})"


class Vehicle(models.Model):
    VEHICLE_TYPE_CHOICES = (
        ("car", "Car"),     
        ("truck", "Truck"),
    )
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="vehicles"
    )
    name = models.CharField(max_length=100, null=True, blank=True)
    plate_number = models.CharField(max_length=20, unique=True)
    vehicle_type = models.CharField(max_length=20, choices=VEHICLE_TYPE_CHOICES, default="car")
    color = models.CharField(max_length=50, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "vehicles"
        indexes = [
            models.Index(fields=['plate_number']),
        ]

    def __str__(self):
        return f"{self.name} ({self.plate_number})"

class SystemSettings(models.Model):
    """
    Singleton table — only ever one row (id=1).
    Stores all admin-configurable system settings.
    Use SystemSettings.get() to always get-or-create the single instance.
    """

    # ── Parking / Overstay ─────────────────────────────────────────────
    grace_period_minutes     = models.IntegerField(default=10)
    overstay_rate_per_hour   = models.DecimalField(max_digits=8, decimal_places=2, default=20.00)
    reservation_lock_minutes = models.IntegerField(default=10)
    max_booking_days         = models.IntegerField(default=7)

    # ── Payment Methods ────────────────────────────────────────────────
    cash_enabled             = models.BooleanField(default=True)
    easypaisa_enabled        = models.BooleanField(default=True)
    card_enabled             = models.BooleanField(default=True)

    # ── Refund Policy ─────────────────────────────────────────────────
    refund_100_before_start  = models.BooleanField(default=True)
    refund_percent           = models.IntegerField(default=50)
    refund_window_minutes    = models.IntegerField(default=30)

    # ── Notifications ──────────────────────────────────────────────────
    notify_new_owner         = models.BooleanField(default=True)
    notify_overstay          = models.BooleanField(default=True)
    notify_payment_received  = models.BooleanField(default=True)
    notify_manual_override   = models.BooleanField(default=False)

    # ── Security ──────────────────────────────────────────────────────
    require_phone_otp        = models.BooleanField(default=True)
    session_timeout_minutes  = models.IntegerField(default=60)
    max_login_attempts       = models.IntegerField(default=5)

    # ── Display ───────────────────────────────────────────────────────
    show_confidence_score    = models.BooleanField(default=True)
    show_owner_revenue       = models.BooleanField(default=True)

    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "system_settings"

    def __str__(self):
        return "System Settings"

    @classmethod
    def get(cls):
        """Always returns the single settings instance, creating it if needed."""
        obj, _ = cls.objects.get_or_create(pk=1)
        return obj
