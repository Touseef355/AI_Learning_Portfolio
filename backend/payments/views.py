from decimal import Decimal

from django.conf import settings
from django.utils import timezone
from django.db import transaction as db_transaction
from django.db.models import Q, Sum
from django.db.models.functions import TruncMonth

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated, AllowAny

from accounts.permissions import IsAdmin
from bookings.models import Booking
from .models import (
    Payment, Wallet, WalletTransaction,
    TopUpTransaction, WithdrawalRequest,
    PLATFORM_COMMISSION,
)
from .serializers import PaymentSerializer
from .gateway import get_payment_gateway


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────

def get_or_create_wallet(user):
    wallet, _ = Wallet.objects.get_or_create(user=user)
    return wallet


def _tx_data(tx):
    return {
        "id": str(tx.id),
        "amount": str(tx.amount),
        "type": tx.type,
        "status": tx.status,
        "description": tx.description,
        "created_at": tx.created_at.isoformat(),
    }


# ─────────────────────────────────────────────────────────────────────────────
# PAYMENT VIEWS (original booking-payment flow)
# ─────────────────────────────────────────────────────────────────────────────

class PaymentView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        payments = Payment.objects.filter(booking__user=request.user)
        serializer = PaymentSerializer(payments, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request):
        with db_transaction.atomic():
            serializer = PaymentSerializer(data=request.data)
            if serializer.is_valid():
                payment = serializer.save()
                booking = payment.booking
                if booking:
                    booking.payment_status = "paid"
                    booking.save()
                payment.status = "success"
                payment.paid_at = timezone.now()
                payment.save()
                return Response(serializer.data, status=status.HTTP_201_CREATED)
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class PaymentDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get_object(self, pk, user):
        try:
            return Payment.objects.get(pk=pk, booking__user=user)
        except Payment.DoesNotExist:
            return None

    def get(self, request, pk):
        payment = self.get_object(pk, request.user)
        if payment is None:
            return Response({"error": "Payment not found"}, status=status.HTTP_404_NOT_FOUND)
        return Response(PaymentSerializer(payment).data, status=status.HTTP_200_OK)

    def put(self, request, pk):
        with db_transaction.atomic():
            payment = self.get_object(pk, request.user)
            if payment is None:
                return Response({"error": "Payment not found"}, status=status.HTTP_404_NOT_FOUND)
            if payment.status != "success":
                return Response({"error": "Only successful payments can be refunded"}, status=status.HTTP_400_BAD_REQUEST)
            refund_amount = request.data.get("refund_amount")
            if not refund_amount:
                return Response({"error": "Refund amount required"}, status=status.HTTP_400_BAD_REQUEST)
            if float(refund_amount) > float(payment.amount):
                return Response({"error": "Refund cannot exceed original amount"}, status=status.HTTP_400_BAD_REQUEST)
            payment.status = "refunded"
            payment.refund_amount = refund_amount
            payment.save()
            if payment.booking:
                payment.booking.payment_status = "failed"
                payment.booking.save()
            return Response({"message": "Payment refunded successfully"}, status=status.HTTP_200_OK)


# ─────────────────────────────────────────────────────────────────────────────
# WALLET — USER
# ─────────────────────────────────────────────────────────────────────────────

class WalletView(APIView):
    """GET /api/payments/wallet/ — balance + last 20 transactions"""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        wallet = get_or_create_wallet(request.user)
        txs = wallet.transactions.all()[:20]
        return Response({
            "balance": str(wallet.balance),
            "transactions": [_tx_data(t) for t in txs],
        }, status=status.HTTP_200_OK)


class WalletTopUpInitView(APIView):
    """
    POST /api/payments/wallet/topup/initiate/
    Initiates a top-up via active gateway (mock or Simpaisa).

    Request:  { "amount": 500 }
    Response: { "payment_url": "...", "transaction_id": "..." }

    Flutter opens payment_url in WebView.
    On return, Flutter calls /api/payments/wallet/topup/callback/
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            amount = float(request.data.get("amount", 0))
        except (ValueError, TypeError):
            return Response({"error": "Invalid amount"}, status=status.HTTP_400_BAD_REQUEST)

        if amount < 100:
            return Response({"error": "Minimum top-up is Rs. 100"}, status=status.HTTP_400_BAD_REQUEST)
        if amount > 50_000:
            return Response({"error": "Maximum top-up is Rs. 50,000"}, status=status.HTTP_400_BAD_REQUEST)

        txn = TopUpTransaction.objects.create(
            user=request.user,
            amount=amount,
            status="initiated",
        )

        backend_url = getattr(settings, 'BACKEND_URL', 'http://localhost:8000')
        return_url = f"{backend_url}/api/payments/wallet/topup/callback/?txn_id={txn.id}"

        gateway = get_payment_gateway()
        result = gateway.initiate_topup(
            user_email=request.user.email,
            amount_pkr=amount,
            order_id=str(txn.id),
            return_url=return_url,
        )

        if not result.success:
            txn.status = "failed"
            txn.save()
            return Response({"error": result.error or "Payment gateway error"}, status=status.HTTP_503_SERVICE_UNAVAILABLE)

        txn.gateway_ref = result.transaction_id
        txn.save()

        return Response({
            "transaction_id": str(txn.id),
            "payment_url": result.payment_url,
            "amount": str(amount),
        }, status=status.HTTP_200_OK)


class WalletTopUpCallbackView(APIView):
    """
    GET  /api/payments/wallet/topup/callback/ — user redirected back from gateway
    POST /api/payments/wallet/topup/callback/ — webhook from gateway

    Both verify payment and credit wallet. AllowAny because the gateway
    posts without an auth token.
    """
    permission_classes = [AllowAny]

    def get(self, request):
        txn_id = request.query_params.get("txn_id")
        try:
            txn = TopUpTransaction.objects.get(id=txn_id)
        except TopUpTransaction.DoesNotExist:
            return Response({"error": "Transaction not found"}, status=status.HTTP_404_NOT_FOUND)

        if txn.status == "success":
            return Response({
                "message": "Already credited",
                "balance": str(get_or_create_wallet(txn.user).balance),
            })

        gateway = get_payment_gateway()
        result = gateway.verify_payment(
            transaction_id=txn.gateway_ref or str(txn.id),
            # .dict() (not dict()) — QueryDict's plain dict() wraps every
            # value in a list, which broke float() in the gateway below.
            gateway_payload=request.query_params.dict(),
        )

        if result.success:
            self._credit_wallet(txn)
            return Response({
                "message": f"Rs. {txn.amount:.0f} added to your wallet!",
                "balance": str(get_or_create_wallet(txn.user).balance),
            })
        txn.status = "failed"
        txn.save()
        return Response({"error": "Payment was not successful"}, status=status.HTTP_400_BAD_REQUEST)

    def post(self, request):
        txn_id = request.query_params.get("txn_id") or request.data.get("order_id")
        try:
            txn = TopUpTransaction.objects.get(id=txn_id)
        except TopUpTransaction.DoesNotExist:
            return Response({"error": "Not found"}, status=status.HTTP_404_NOT_FOUND)

        if txn.status == "success":
            return Response({"message": "Already processed"})

        gateway = get_payment_gateway()
        result = gateway.verify_payment(
            transaction_id=txn.gateway_ref or str(txn.id),
            gateway_payload=request.data,
        )

        if result.success:
            self._credit_wallet(txn)
            return Response({"message": "Wallet credited"})

        txn.status = "failed"
        txn.save()
        return Response({"message": "Payment failed"})

    def _credit_wallet(self, txn):
        with db_transaction.atomic():
            locked_txn = TopUpTransaction.objects.select_for_update().get(pk=txn.pk)
            if locked_txn.status == "success":
                return  # already credited — idempotent

            wallet = get_or_create_wallet(locked_txn.user)
            wallet.balance = Decimal(str(wallet.balance)) + Decimal(str(locked_txn.amount))
            wallet.save()
            WalletTransaction.objects.create(
                wallet=wallet,
                amount=locked_txn.amount,
                type="topup",
                status="success",
                description=f"Top-up — Rs. {locked_txn.amount:.0f}",
            )
            locked_txn.status = "success"
            locked_txn.completed_at = timezone.now()
            locked_txn.save()


class MockPaymentConfirmView(APIView):
    """
    GET /api/payments/mock/confirm/
    Only meaningful in mock mode. Flutter WebView opens this page, user sees
    a "Confirm Payment" button, redirected back to app with success status.
    """
    permission_classes = [AllowAny]

    def get(self, request):
        order_id = request.query_params.get("order_id")
        amount = request.query_params.get("amount")
        return_url = request.query_params.get("return_url")

        html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>Confirm Payment</title>
            <style>
                body {{ font-family: sans-serif; display: flex; flex-direction: column;
                        align-items: center; justify-content: center; height: 100vh;
                        background: #f5f5f5; margin: 0; }}
                .card {{ background: white; padding: 32px; border-radius: 16px;
                         text-align: center; box-shadow: 0 4px 20px rgba(0,0,0,0.1); }}
                h2 {{ color: #1a1a1a; margin-bottom: 8px; }}
                p  {{ color: #666; margin-bottom: 24px; font-size: 18px; }}
                .amount {{ color: #4F6EF7; font-size: 28px; font-weight: bold; }}
                button {{ background: #4F6EF7; color: white; border: none;
                          padding: 16px 40px; border-radius: 50px; font-size: 16px;
                          font-weight: bold; cursor: pointer; width: 100%; }}
                .note {{ color: #999; font-size: 12px; margin-top: 16px; }}
            </style>
        </head>
        <body>
            <div class="card">
                <h2>Test Payment</h2>
                <p>Amount to add:</p>
                <div class="amount">Rs. {amount}</div>
                <br>
                <button onclick="confirmPayment()">Confirm Top-Up</button>
                <p class="note">This is a test payment screen.<br>No real money is deducted.</p>
            </div>
            <script>
                function confirmPayment() {{
                    window.location.href = "{return_url}&status=success";
                }}
            </script>
        </body>
        </html>
        """
        from django.http import HttpResponse
        return HttpResponse(html)


class WalletDeductView(APIView):
    """
    POST /api/payments/wallet/deduct/
    Pay for parking from the user's wallet.
    90% goes to the site owner's wallet, 10% platform commission.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        booking_id = request.data.get("booking_id")
        try:
            amount = Decimal(str(request.data.get("amount", 0)))
        except Exception:
            return Response({"error": "Invalid amount"}, status=status.HTTP_400_BAD_REQUEST)

        if not booking_id:
            return Response({"error": "booking_id is required"}, status=status.HTTP_400_BAD_REQUEST)

        try:
            booking = Booking.objects.select_related(
                "parking_slot__parking_site__owner"
            ).get(pk=booking_id, user=request.user)
        except Booking.DoesNotExist:
            return Response({"error": "Booking not found"}, status=status.HTTP_404_NOT_FOUND)

        if booking.payment_status == "paid":
            return Response({"error": "Booking already paid"}, status=status.HTTP_400_BAD_REQUEST)

        with db_transaction.atomic():
            user_wallet = get_or_create_wallet(request.user)

            if user_wallet.balance < amount:
                return Response({
                    "error": f"Insufficient balance. Available: Rs. {user_wallet.balance:.0f}"
                }, status=status.HTTP_400_BAD_REQUEST)

            user_wallet.balance -= amount
            user_wallet.save()
            WalletTransaction.objects.create(
                wallet=user_wallet,
                amount=amount,
                type="payment",
                status="success",
                description=f"Parking — {str(booking_id)[:8].upper()}",
            )

            owner_share = amount * (Decimal('1') - PLATFORM_COMMISSION)
            owner = (
                booking.parking_slot.parking_site.owner
                if booking.parking_slot and booking.parking_slot.parking_site
                else None
            )

            if owner:
                owner_wallet = get_or_create_wallet(owner)
                owner_wallet.balance = Decimal(str(owner_wallet.balance)) + owner_share
                owner_wallet.save()
                WalletTransaction.objects.create(
                    wallet=owner_wallet,
                    amount=owner_share,
                    type="payment",
                    status="success",
                    description=f"Parking revenue — {str(booking_id)[:8].upper()} (after 10% commission)",
                )

            booking.payment_status = "paid"
            if booking.status == "pending_payment":
                booking.status = "confirmed"
            booking.save()

        return Response({
            "message": "Payment successful",
            "balance": str(user_wallet.balance),
            "amount_charged": str(amount),
            "owner_credited": str(owner_share) if owner else "0",
        }, status=status.HTTP_200_OK)


# ─────────────────────────────────────────────────────────────────────────────
# WALLET — OWNER
# ─────────────────────────────────────────────────────────────────────────────

class OwnerWalletView(APIView):
    """GET /api/payments/owner/wallet/ — owner balance + transactions"""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.role != "parking_owner":
            return Response({"error": "Only parking owners can access this"}, status=status.HTTP_403_FORBIDDEN)

        wallet = get_or_create_wallet(request.user)
        txs = wallet.transactions.all()[:30]
        pending = WithdrawalRequest.objects.filter(owner=request.user, status="pending")

        return Response({
            "balance": str(wallet.balance),
            "transactions": [_tx_data(t) for t in txs],
            "pending_withdrawals": [
                {
                    "id": str(w.id),
                    "amount": str(w.amount),
                    "account_detail": w.account_detail,
                    "created_at": w.created_at.isoformat(),
                }
                for w in pending
            ],
        }, status=status.HTTP_200_OK)


class WithdrawalRequestView(APIView):
    """
    POST /api/payments/owner/withdraw/
    Owner requests a payout of their wallet balance.
    Mock mode: auto-approved + paid out immediately.
    Simpaisa mode: real payout via disbursement API.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if request.user.role != "parking_owner":
            return Response({"error": "Only parking owners can request withdrawals"}, status=status.HTTP_403_FORBIDDEN)

        try:
            amount = Decimal(str(request.data.get("amount", 0)))
        except Exception:
            return Response({"error": "Invalid amount"}, status=status.HTTP_400_BAD_REQUEST)

        account_detail = request.data.get("account_detail", "").strip()
        account_title = request.data.get("account_title", "").strip()

        if amount < 500:
            return Response({"error": "Minimum withdrawal is Rs. 500"}, status=status.HTTP_400_BAD_REQUEST)
        if not account_detail or not account_title:
            return Response({"error": "Account detail and title are required"}, status=status.HTTP_400_BAD_REQUEST)

        wallet = get_or_create_wallet(request.user)
        if wallet.balance < amount:
            return Response({
                "error": f"Insufficient balance. Available: Rs. {wallet.balance:.0f}"
            }, status=status.HTTP_400_BAD_REQUEST)

        already_pending = WithdrawalRequest.objects.filter(
            owner=request.user, status="pending"
        ).exists()
        if already_pending:
            return Response({"error": "You already have a pending withdrawal request"}, status=status.HTTP_400_BAD_REQUEST)

        with db_transaction.atomic():
            wallet.balance -= amount
            wallet.save()

            wr = WithdrawalRequest.objects.create(
                owner=request.user,
                amount=amount,
                account_detail=account_detail,
                account_title=account_title,
            )

            WalletTransaction.objects.create(
                wallet=wallet,
                amount=amount,
                type="withdrawal",
                status="pending",
                description=f"Withdrawal to {account_detail}",
            )

            gateway = get_payment_gateway()
            payout_result = gateway.payout_to_owner(
                owner_account=account_detail,
                amount_pkr=float(amount),
                reference=str(wr.id),
            )

            if payout_result.success:
                wr.status = "approved"
                wr.processed_at = timezone.now()
                wr.admin_note = f"Auto-processed. Ref: {payout_result.reference}"
                wr.save()
                WalletTransaction.objects.filter(
                    wallet=wallet, type="withdrawal", status="pending", amount=amount
                ).update(status="success")
                msg = "Withdrawal processed successfully"
            else:
                wallet.balance += amount
                wallet.save()
                WalletTransaction.objects.create(
                    wallet=wallet, amount=amount, type="refund",
                    status="success", description="Withdrawal failed — refunded",
                )
                wr.status = "rejected"
                wr.admin_note = payout_result.error or "Payout failed"
                wr.save()
                msg = f"Withdrawal failed: {payout_result.error}"

        return Response({
            "message": msg,
            "request_id": str(wr.id),
            "amount": str(amount),
            "remaining_balance": str(wallet.balance),
            "payout_reference": payout_result.reference,
        }, status=status.HTTP_201_CREATED)


# ─────────────────────────────────────────────────────────────────────────────
# APP CONFIG — Flutter fetches this on boot
# ─────────────────────────────────────────────────────────────────────────────

class AppConfigView(APIView):
    """
    GET /api/config/
    Flutter fetches this on app boot — gets the active payment gateway.
    To switch gateway remotely: change PAYMENT_GATEWAY in settings/.env.
    No app update needed.
    """
    permission_classes = [AllowAny]

    def get(self, request):
        gateway = getattr(settings, "PAYMENT_GATEWAY", "mock")
        return Response({
            "payment_gateway": gateway,
            "min_topup": 100,
            "max_topup": 50000,
            "min_withdrawal": 500,
            "platform_commission": float(PLATFORM_COMMISSION),
            "reservation_timeout_minutes": 15,
            "booking_buffer_minutes": 15,
        }, status=status.HTTP_200_OK)


# ─────────────────────────────────────────────────────────────────────────────
# ADMIN — All payments across all sites (backend_friend)
# ─────────────────────────────────────────────────────────────────────────────

class AdminPaymentListView(APIView):
    permission_classes = [IsAuthenticated, IsAdmin]

    def get(self, request):
        payments = (
            Payment.objects
            .select_related(
                "booking__user",
                "booking__vehicle",
                "booking__parking_slot__parking_site",
                "booking__parking_slot__parking_site__owner",
            )
            .order_by("-paid_at")
        )

        status_filter = request.query_params.get("status")
        method_filter = request.query_params.get("method")
        site_filter = request.query_params.get("site_id")
        date_from = request.query_params.get("date_from")
        date_to = request.query_params.get("date_to")
        search = request.query_params.get("search")

        if status_filter:
            payments = payments.filter(status=status_filter)
        if method_filter:
            payments = payments.filter(payment_method__iexact=method_filter)
        if site_filter:
            payments = payments.filter(
                booking__parking_slot__parking_site__id=site_filter
            )
        if date_from:
            payments = payments.filter(paid_at__date__gte=date_from)
        if date_to:
            payments = payments.filter(paid_at__date__lte=date_to)
        if search:
            payments = payments.filter(
                # Was Q(transaction_id__icontains=...) — not a real field on
                # Payment (pre-existing bug from the merge audit). The actual
                # reference field is payment_reference.
                Q(payment_reference__icontains=search) |
                Q(booking__vehicle__plate_number__icontains=search) |
                Q(booking__legacy_vehicle_plate__icontains=search) |
                Q(booking__parking_slot__parking_site__owner__full_name__icontains=search) |
                Q(booking__parking_slot__parking_site__name__icontains=search) |
                Q(id__icontains=search)
            )

        data = []
        for p in payments:
            try:
                site_name = p.booking.parking_slot.parking_site.name
                owner_name = p.booking.parking_slot.parking_site.owner.full_name
                plate = p.booking.vehicle_plate or '—'
                user_name = p.booking.user.full_name if p.booking.user else "—"
                user_email = p.booking.user.email if p.booking.user else "—"
                slot_number = p.booking.parking_slot.slot_number
            except Exception:
                site_name = "—"
                owner_name = "—"
                plate = "—"
                user_name = "—"
                user_email = "—"
                slot_number = "—"

            data.append({
                "id": str(p.id),
                "booking_id": str(p.booking.id) if p.booking else "—",
                "site": site_name,
                "owner": owner_name,
                "user": user_name,
                "user_email": user_email,
                "plate": plate,
                "amount": str(p.amount),
                "refund_amount": str(p.refund_amount) if p.refund_amount else None,
                "method": p.payment_method or "—",
                "payment_type": p.payment_type,
                "status": p.status,
                "currency": p.currency,
                "paid_at": p.paid_at,
                "slot_number": slot_number,
            })

        return Response(data, status=status.HTTP_200_OK)


class AdminPaymentRefundView(APIView):
    """Admin can refund any payment regardless of who made it."""
    permission_classes = [IsAuthenticated, IsAdmin]

    def patch(self, request, pk):
        with db_transaction.atomic():
            try:
                payment = Payment.objects.get(pk=pk)
            except Payment.DoesNotExist:
                return Response(
                    {"error": "Payment not found"},
                    status=status.HTTP_404_NOT_FOUND,
                )

            if payment.status != "success":
                return Response(
                    {"error": "Only successful payments can be refunded"},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            refund_amount = request.data.get("refund_amount")
            if not refund_amount:
                return Response(
                    {"error": "refund_amount is required"},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            if float(refund_amount) > float(payment.amount):
                return Response(
                    {"error": "Refund amount cannot exceed original amount"},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            payment.status = "refunded"
            payment.refund_amount = refund_amount
            payment.save()

            if payment.booking:
                payment.booking.payment_status = "failed"
                payment.booking.save()

            return Response(
                {"message": "Payment refunded successfully"},
                status=status.HTTP_200_OK,
            )


class OwnerPaymentsView(APIView):
    """GET /api/payments/owner/ — payments across all sites this owner owns."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.role != 'parking_owner':
            return Response({'error': 'Unauthorized'}, status=status.HTTP_403_FORBIDDEN)

        from parking.models import ParkingSite

        sites = ParkingSite.objects.filter(owner=request.user)
        payments = Payment.objects.filter(
            booking__parking_slot__parking_site__in=sites
        ).select_related(
            'booking',
            'booking__vehicle',
            'booking__parking_slot__parking_site'
        ).order_by('-paid_at')

        monthly = payments.filter(status='success').annotate(
            month=TruncMonth('paid_at')
        ).values('month').annotate(
            total=Sum('amount')
        ).order_by('month')

        data = []
        for p in payments:
            try:
                plate = p.booking.vehicle_plate or '—'
                site = p.booking.parking_slot.parking_site.name
            except Exception:
                plate = '—'
                site = '—'
            data.append({
                'id': str(p.id),
                'plate_number': plate,
                'site_name': site,
                'amount': str(p.amount),
                'status': p.status,
                'payment_method': p.payment_method,
                'paid_at': p.paid_at,
            })

        return Response({
            'payments': data,
            'monthly_revenue': [
                {'month': m['month'], 'total': str(m['total'])}
                for m in monthly
            ]
        })
