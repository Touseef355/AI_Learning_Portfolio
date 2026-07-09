from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Optional


@dataclass
class PaymentInitResult:
    """
    Returned when a payment session is initiated.
    Flutter opens payment_url in WebView.
    """
    success: bool
    transaction_id: str          # our internal GoPayFast/Simpaisa txn ID
    payment_url: Optional[str]   # URL to open in Flutter WebView
    error: Optional[str] = None


@dataclass
class PaymentVerifyResult:
    """
    Returned after webhook / callback verification.
    """
    success: bool
    transaction_id: str
    amount: float
    error: Optional[str] = None


@dataclass
class PayoutResult:
    """
    Returned when paying out to parking owner.
    """
    success: bool
    reference: Optional[str] = None  # gateway's payout reference
    error: Optional[str] = None


class BasePaymentGateway(ABC):
    """
    Abstract contract for all payment gateways.
    Every gateway (Mock, Simpaisa, etc.) must implement these 3 methods.
    Views only talk to this interface — never to the gateway directly.
    """

    @abstractmethod
    def initiate_topup(
        self,
        user_email: str,
        amount_pkr: float,
        order_id: str,
        return_url: str,
    ) -> PaymentInitResult:
        """
        Start a top-up payment session.
        Returns a URL to open in Flutter WebView.
        """
        pass

    @abstractmethod
    def verify_payment(
        self,
        transaction_id: str,
        gateway_payload: dict,
    ) -> PaymentVerifyResult:
        """
        Verify payment after webhook / redirect callback.
        Returns success + confirmed amount.
        """
        pass

    @abstractmethod
    def payout_to_owner(
        self,
        owner_account: str,   # JazzCash/EasyPaisa/bank number
        amount_pkr: float,
        reference: str,       # our withdrawal request ID
    ) -> PayoutResult:
        """
        Send money to parking owner's account.
        Mock: always succeeds.
        Simpaisa: calls disbursement API.
        """
        pass
