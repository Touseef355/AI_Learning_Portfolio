import uuid
from decimal import Decimal
from django.db import models
from django.conf import settings

PLATFORM_COMMISSION = settings.PLATFORM_COMMISSION


class Payment(models.Model):
    STATUS_CHOICES = (
        ("initiated", "Initiated"),
        ("pending", "Pending"),
        ("success", "Success"),
        ("failed", "Failed"),
        ("cancelled", "Cancelled"),
        ("refunded", "Refunded"),
    )
    # What the payment is FOR — backend_ali's meaning, kept as the canonical
    # "payment_type" name since it's the more fundamental distinction.
    PAYMENT_TYPE_CHOICES = (
        ("booking", "Booking"),
        ("topup", "Top Up"),
        ("refund", "Refund"),
    )
    # HOW it was paid — backend_friend's original "payment_type" field,
    # renamed to stop colliding with the one above.
    PAYMENT_CHANNEL_CHOICES = (
        ("online", "Online"),
        ("cash", "Cash"),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    # Nullable/SET_NULL (backend_ali) instead of a required OneToOne
    # (backend_friend) — topup and refund payments aren't tied to a booking.
    booking = models.ForeignKey(
        'bookings.Booking',
        on_delete=models.SET_NULL,
        related_name="payment",
        null=True,
        blank=True,
    )
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    payment_method = models.CharField(max_length=50, null=True, blank=True)
    payment_type = models.CharField(
        max_length=20,
        choices=PAYMENT_TYPE_CHOICES,
        default="booking"
    )
    payment_channel = models.CharField(
        max_length=20,
        choices=PAYMENT_CHANNEL_CHOICES,
        null=True, blank=True,
    )
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default="pending"
    )
    paid_at = models.DateTimeField(null=True, blank=True)
    currency = models.CharField(max_length=10, default="PKR")
    payment_reference = models.CharField(
        max_length=100, null=True, blank=True, unique=True, db_index=True
    )
    refund_amount = models.DecimalField(
        max_digits=10, decimal_places=2, null=True, blank=True
    )
    created_at = models.DateTimeField(auto_now_add=True, null=True, blank=True)

    class Meta:
        db_table = "payments"
        indexes = [
            models.Index(fields=['status']),
            models.Index(fields=['paid_at']),
        ]

    def __str__(self):
        return f"Payment {self.id}: {self.amount} ({self.status})"


class Wallet(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="wallet")
    balance = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal('0.00'))
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "wallets"

    def __str__(self):
        return f"Wallet({self.user.email}) = {self.balance}"


class WalletTransaction(models.Model):
    TYPE_CHOICES = (
        ("topup", "Top Up"),
        ("payment", "Payment"),
        ("commission", "Commission"),
        ("refund", "Refund"),
        ("withdrawal", "Withdrawal"),
    )
    STATUS_CHOICES = (
        ("success", "Success"),
        ("failed", "Failed"),
        ("pending", "Pending"),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    wallet = models.ForeignKey(Wallet, on_delete=models.CASCADE, related_name="transactions")
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    type = models.CharField(max_length=20, choices=TYPE_CHOICES)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="success")
    description = models.CharField(max_length=255, blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "wallet_transactions"
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.type} Rs.{self.amount} — {self.wallet.user.email}"


class TopUpTransaction(models.Model):
    """
    Tracks a wallet top-up payment session through the active gateway.
    Created when the user initiates a top-up, updated via webhook/callback.
    """
    STATUS_CHOICES = (
        ("initiated", "Initiated"),
        ("success", "Success"),
        ("failed", "Failed"),
        ("expired", "Expired"),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="topup_txns")
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    gateway_token = models.CharField(max_length=500, blank=True, default="")
    gateway_ref = models.CharField(max_length=200, blank=True, default="")
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="initiated")
    created_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "topup_transactions"

    def __str__(self):
        return f"TopUp {self.amount} PKR — {self.user.email} ({self.status})"


class WithdrawalRequest(models.Model):
    """
    Parking owner requests withdrawal of their wallet balance.
    Admin approves and transfers manually, or the gateway auto-payouts
    in mock mode.
    """
    STATUS_CHOICES = (
        ("pending", "Pending"),
        ("approved", "Approved"),
        ("rejected", "Rejected"),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    owner = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="withdrawal_requests")
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    account_detail = models.CharField(max_length=255, help_text="JazzCash/EasyPaisa/Bank account number")
    account_title = models.CharField(max_length=100)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="pending")
    admin_note = models.TextField(blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)
    processed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "withdrawal_requests"
        ordering = ["-created_at"]

    def __str__(self):
        return f"Withdrawal Rs.{self.amount} by {self.owner.email} ({self.status})"
