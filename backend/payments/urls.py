from django.urls import path
from .views import (
    PaymentView, PaymentDetailView,
    WalletView, WalletTopUpInitView,
    WalletTopUpCallbackView, MockPaymentConfirmView,
    WalletDeductView, OwnerWalletView, WithdrawalRequestView,
    AdminPaymentListView, AdminPaymentRefundView, OwnerPaymentsView,
)

urlpatterns = [
    # Payments
    path("", PaymentView.as_view(), name="payment"),
    path("<uuid:pk>/", PaymentDetailView.as_view(), name="payment-detail"),

    # User Wallet
    path("wallet/", WalletView.as_view(), name="wallet"),
    path("wallet/topup/initiate/", WalletTopUpInitView.as_view(), name="wallet-topup-init"),
    path("wallet/topup/callback/", WalletTopUpCallbackView.as_view(), name="wallet-topup-callback"),
    path("wallet/deduct/", WalletDeductView.as_view(), name="wallet-deduct"),

    # Mock gateway only (harmless if PAYMENT_GATEWAY=simpaisa — just unused)
    path("mock/confirm/", MockPaymentConfirmView.as_view(), name="mock-confirm"),

    # Owner — wallet/payout
    path("owner/wallet/", OwnerWalletView.as_view(), name="owner-wallet"),
    path("owner/withdraw/", WithdrawalRequestView.as_view(), name="owner-withdraw"),

    # Owner — payments list (dashboard)
    path("owner/", OwnerPaymentsView.as_view(), name="owner-payments"),

    # Admin
    path("admin/", AdminPaymentListView.as_view(), name="admin-payment-list"),
    path("admin/<uuid:pk>/refund/", AdminPaymentRefundView.as_view(), name="admin-payment-refund"),
]
