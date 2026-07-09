import requests
from django.conf import settings
from .base import BasePaymentGateway, PaymentInitResult, PaymentVerifyResult, PayoutResult


class SimpaisaGateway(BasePaymentGateway):
    """
    Simpaisa payment gateway — production implementation.

    Required settings.py keys (get from Simpaisa merchant portal):
        SIMPAISA_API_KEY       = "your_api_key"
        SIMPAISA_SECRET_KEY    = "your_secret_key"
        SIMPAISA_MERCHANT_ID   = "your_merchant_id"
        SIMPAISA_BASE_URL      = "https://sandbox.simpaisa.com/api/v1"  # sandbox
                               # "https://api.simpaisa.com/api/v1"       # production
        PAYMENT_GATEWAY        = "simpaisa"

    NOTE: Exact endpoint paths, request/response field names, and
    authentication method must be confirmed from official Simpaisa API docs.
    This skeleton follows standard payment gateway patterns.
    Fill in the TODOs once you have Simpaisa merchant credentials + documentation.
    """

    def __init__(self):
        self.api_key     = getattr(settings, 'SIMPAISA_API_KEY',    '')
        self.secret_key  = getattr(settings, 'SIMPAISA_SECRET_KEY', '')
        self.merchant_id = getattr(settings, 'SIMPAISA_MERCHANT_ID','')
        self.base_url    = getattr(settings, 'SIMPAISA_BASE_URL',
                                   'https://sandbox.simpaisa.com/api/v1')

    def _headers(self):
        # TODO: confirm exact auth header format from Simpaisa docs
        # Common patterns: Bearer token, Basic auth, HMAC signature
        return {
            'Content-Type':  'application/json',
            'Authorization': f'Bearer {self.api_key}',
            'X-Merchant-ID': self.merchant_id,
        }

    def initiate_topup(
        self,
        user_email: str,
        amount_pkr: float,
        order_id: str,
        return_url: str,
    ) -> PaymentInitResult:
        # TODO: replace with actual Simpaisa collect/pay-in endpoint + payload
        # Reference: Simpaisa Pay-In API docs
        try:
            payload = {
                'merchant_id':  self.merchant_id,
                'order_id':     str(order_id),
                'amount':       int(amount_pkr * 100),  # confirm if paisa or PKR
                'currency':     'PKR',
                'customer_email': user_email,
                'return_url':   return_url,
                'webhook_url':  f"{getattr(settings, 'BACKEND_URL', '')}/api/payments/webhook/",
                # TODO: add any other required fields
            }

            resp = requests.post(
                f"{self.base_url}/payments/initiate",  # TODO: confirm endpoint
                json=payload,
                headers=self._headers(),
                timeout=15,
            )
            data = resp.json()

            if resp.status_code == 200 and data.get('status') == 'success':
                return PaymentInitResult(
                    success=True,
                    transaction_id=data.get('transaction_id', str(order_id)),
                    payment_url=data.get('payment_url'),  # TODO: confirm field name
                )
            return PaymentInitResult(
                success=False,
                transaction_id=str(order_id),
                payment_url=None,
                error=data.get('message', 'Payment initiation failed'),
            )
        except Exception as e:
            return PaymentInitResult(
                success=False,
                transaction_id=str(order_id),
                payment_url=None,
                error=str(e),
            )

    def verify_payment(
        self,
        transaction_id: str,
        gateway_payload: dict,
    ) -> PaymentVerifyResult:
        # TODO: implement Simpaisa webhook signature verification
        # Simpaisa will POST to /api/payments/webhook/ with payment status
        # Verify HMAC/signature to prevent fake webhook calls
        try:
            # TODO: verify signature using self.secret_key + gateway_payload
            # signature = hmac.new(self.secret_key, payload_string, sha256)

            status = gateway_payload.get('status', '').lower()
            amount = float(gateway_payload.get('amount', 0)) / 100  # convert paisa → PKR

            if status in ('success', 'completed', 'paid'):
                return PaymentVerifyResult(
                    success=True,
                    transaction_id=transaction_id,
                    amount=amount,
                )
            return PaymentVerifyResult(
                success=False,
                transaction_id=transaction_id,
                amount=0,
                error=f"Payment status: {status}",
            )
        except Exception as e:
            return PaymentVerifyResult(
                success=False,
                transaction_id=transaction_id,
                amount=0,
                error=str(e),
            )

    def payout_to_owner(
        self,
        owner_account: str,
        amount_pkr: float,
        reference: str,
    ) -> PayoutResult:
        # TODO: implement Simpaisa Disbursement/Pay-Out API
        # This is Simpaisa's key differentiator — single API for collecting + paying out
        try:
            payload = {
                'merchant_id':      self.merchant_id,
                'reference_id':     reference,
                'amount':           int(amount_pkr * 100),  # confirm paisa or PKR
                'currency':         'PKR',
                'beneficiary':      owner_account,          # JazzCash/EasyPaisa/bank
                # TODO: add required beneficiary type, bank code, etc.
            }

            resp = requests.post(
                f"{self.base_url}/payouts/disburse",  # TODO: confirm endpoint
                json=payload,
                headers=self._headers(),
                timeout=15,
            )
            data = resp.json()

            if resp.status_code == 200 and data.get('status') == 'success':
                return PayoutResult(
                    success=True,
                    reference=data.get('payout_reference'),
                )
            return PayoutResult(
                success=False,
                error=data.get('message', 'Payout failed'),
            )
        except Exception as e:
            return PayoutResult(success=False, error=str(e))
