"""
Refund money movement — kept in payments (money logic lives here),
policy computation lives in bookings.views.compute_refund().

Import chain is deliberately one-way to avoid cycles:
    bookings.views  →  payments.services  →  payments.models
                                          →  notifications.services
"""
from decimal import Decimal

from django.conf import settings

from .models import Wallet, WalletTransaction
from notifications.services import notify

PLATFORM_COMMISSION = settings.PLATFORM_COMMISSION


def _wallet_for(user):
    wallet, _ = Wallet.objects.get_or_create(user=user)
    return wallet


def process_booking_refund(booking, refund_amount, refund_percent):
    """
    Credit `refund_amount` back to the booking user's wallet and claw the
    owner's share back from the owner's wallet.

    MUST be called inside transaction.atomic() (the cancel view does this),
    so a partial refund can never commit.

    Mirrors WalletDeductView's split: the user paid 100%, the owner
    received (1 - commission); on refund the user gets `refund_amount`
    back and the owner gives up refund_amount * (1 - commission). The
    platform absorbs the commission portion of the refund — standard
    marketplace behaviour, and it keeps the user whole.

    NOTE: the owner clawback can push an owner wallet negative (e.g. the
    owner already withdrew). That's intentional — clamping at zero would
    silently make the platform eat the difference and hide it from the
    books. A negative balance nets out against future revenue.
    """
    refund_amount = Decimal(str(refund_amount))
    if refund_amount <= 0:
        return None

    short_id = str(booking.id)[:8].upper()

    # ── User: credit refund ──────────────────────────────────────────
    user_wallet = _wallet_for(booking.user)
    user_wallet.balance = Decimal(str(user_wallet.balance)) + refund_amount
    user_wallet.save()
    WalletTransaction.objects.create(
        wallet=user_wallet,
        amount=refund_amount,
        type="refund",
        status="success",
        description=f"Refund ({refund_percent}%) — booking #{short_id}",
    )

    # ── Owner: claw back their share ─────────────────────────────────
    owner = (
        booking.parking_slot.parking_site.owner
        if booking.parking_slot and booking.parking_slot.parking_site
        else None
    )
    if owner:
        owner_share = (refund_amount * (Decimal("1") - PLATFORM_COMMISSION)
                       ).quantize(Decimal("0.01"))
        owner_wallet = _wallet_for(owner)
        owner_wallet.balance = Decimal(str(owner_wallet.balance)) - owner_share
        owner_wallet.save()
        WalletTransaction.objects.create(
            wallet=owner_wallet,
            amount=owner_share,
            type="refund",
            status="success",
            description=f"Refund clawback — booking #{short_id}",
        )

    notify(
        booking.user,
        "Refund Processed",
        f"Rs. {refund_amount:.0f} ({refund_percent}%) refunded to your wallet "
        f"for booking #{short_id}.",
        "refund",
    )
    return refund_amount


class InsufficientBalance(Exception):
    """Raised when a wallet charge exceeds the user's balance."""


def charge_wallet_split(user, owner, amount, description, notify_title=None,
                        notify_message=None, notify_type="payment_success"):
    """
    Deduct `amount` from the user's wallet and credit the owner their
    (1 - commission) share — same split as WalletDeductView, reusable for
    parking passes. MUST be called inside transaction.atomic().
    Raises InsufficientBalance instead of returning an error dict, so the
    calling view's atomic block rolls back cleanly.
    """
    amount = Decimal(str(amount))
    user_wallet = _wallet_for(user)

    if Decimal(str(user_wallet.balance)) < amount:
        raise InsufficientBalance(
            f"Wallet balance Rs. {user_wallet.balance} is less than Rs. {amount}"
        )

    user_wallet.balance = Decimal(str(user_wallet.balance)) - amount
    user_wallet.save()
    WalletTransaction.objects.create(
        wallet=user_wallet,
        amount=amount,
        type="payment",
        status="success",
        description=description,
    )

    if owner:
        owner_share = (amount * (Decimal("1") - PLATFORM_COMMISSION)
                       ).quantize(Decimal("0.01"))
        owner_wallet = _wallet_for(owner)
        owner_wallet.balance = Decimal(str(owner_wallet.balance)) + owner_share
        owner_wallet.save()
        WalletTransaction.objects.create(
            wallet=owner_wallet,
            amount=owner_share,
            type="payment",
            status="success",
            description=f"Revenue — {description}",
        )

    if notify_title:
        notify(user, notify_title, notify_message or "", notify_type)


def process_pass_refund(pass_obj, refund_amount, refund_percent):
    """Prorated pass refund — same money movement as booking refunds."""
    refund_amount = Decimal(str(refund_amount))
    if refund_amount <= 0:
        return None

    short_id = str(pass_obj.id)[:8].upper()

    user_wallet = _wallet_for(pass_obj.user)
    user_wallet.balance = Decimal(str(user_wallet.balance)) + refund_amount
    user_wallet.save()
    WalletTransaction.objects.create(
        wallet=user_wallet,
        amount=refund_amount,
        type="refund",
        status="success",
        description=f"Pass refund ({refund_percent}%) — pass #{short_id}",
    )

    owner = pass_obj.parking_slot.parking_site.owner if pass_obj.parking_slot else None
    if owner:
        owner_share = (refund_amount * (Decimal("1") - PLATFORM_COMMISSION)
                       ).quantize(Decimal("0.01"))
        owner_wallet = _wallet_for(owner)
        owner_wallet.balance = Decimal(str(owner_wallet.balance)) - owner_share
        owner_wallet.save()
        WalletTransaction.objects.create(
            wallet=owner_wallet,
            amount=owner_share,
            type="refund",
            status="success",
            description=f"Pass refund clawback — pass #{short_id}",
        )

    notify(
        pass_obj.user,
        "Pass Refund Processed",
        f"Rs. {refund_amount:.0f} refunded to your wallet for parking pass #{short_id}.",
        "refund",
    )
    return refund_amount
