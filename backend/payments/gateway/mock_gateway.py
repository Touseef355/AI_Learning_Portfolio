import uuid
import time
from .base import BasePaymentGateway, PaymentInitResult, PaymentVerifyResult, PayoutResult


class MockGateway(BasePaymentGateway):
    """
    Mock payment gateway for development and testing.

    Behaviour:
    - initiate_topup  → returns a fake payment URL (our own confirm endpoint)
    - verify_payment  → always succeeds instantly
    - payout_to_owner → always succeeds instantly

    To use: set PAYMENT_GATEWAY = 'mock' in settings.py (default)
    To switch to Simpaisa: set PAYMENT_GATEWAY = 'simpaisa'
    """

    def initiate_topup(
        self,
        user_email: str,
        amount_pkr: float,
        order_id: str,
        return_url: str,
    ) -> PaymentInitResult:
        # Simulate slight delay like a real API call
        time.sleep(0.1)

        # Mock payment URL — points to our own confirm endpoint
        # Flutter opens this, user sees a simple "Confirm Payment" screen
        from django.conf import settings
        backend_url = getattr(settings, 'BACKEND_URL', 'http://localhost:8000')
        payment_url = (
            f"{backend_url}/api/payments/mock/confirm/"
            f"?order_id={order_id}&amount={amount_pkr}&return_url={return_url}"
        )

        return PaymentInitResult(
            success=True,
            transaction_id=str(uuid.uuid4()),
            payment_url=payment_url,
        )

    def verify_payment(
        self,
        transaction_id: str,
        gateway_payload: dict,
    ) -> PaymentVerifyResult:
        # Mock: always successful — amount comes from our DB record
        amount = float(gateway_payload.get('amount', 0))
        return PaymentVerifyResult(
            success=True,
            transaction_id=transaction_id,
            amount=amount,
        )

    def payout_to_owner(
        self,
        owner_account: str,
        amount_pkr: float,
        reference: str,
    ) -> PayoutResult:
        # Mock: always succeeds
        time.sleep(0.1)
        return PayoutResult(
            success=True,
            reference=f"MOCK-PAYOUT-{reference[:8].upper()}",
        )
