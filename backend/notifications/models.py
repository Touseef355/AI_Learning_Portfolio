import uuid
from django.db import models
from django.conf import settings


class Notification(models.Model):
    """
    In-app notification shown in parkroo_app's NotificationsScreen.

    notification_type values map to emoji/colors in the Flutter _typeMap:
        booking_confirmed, booking_cancelled, overstay_alert,
        payment_success, refund, wallet_topup
    Unknown types fall back to a generic bell icon in the app, so new
    types can be added backend-first without an app release.
    """
    TYPE_CHOICES = (
        ("booking_confirmed", "Booking Confirmed"),
        ("booking_cancelled", "Booking Cancelled"),
        ("booking_extended",  "Booking Extended"),
        ("overstay_alert",    "Overstay Alert"),
        ("payment_success",   "Payment Success"),
        ("refund",            "Refund"),
        ("wallet_topup",      "Wallet Top-Up"),
        ("general",           "General"),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="notifications",
    )
    title = models.CharField(max_length=120)
    message = models.CharField(max_length=255, blank=True, default="")
    notification_type = models.CharField(
        max_length=30, choices=TYPE_CHOICES, default="general"
    )
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "notifications"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["user", "is_read"]),
            models.Index(fields=["created_at"]),
        ]

    def __str__(self):
        return f"{self.notification_type} → {self.user} : {self.title}"
