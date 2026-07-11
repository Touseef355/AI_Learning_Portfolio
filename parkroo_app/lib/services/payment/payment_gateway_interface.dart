/// Abstract contract for all payment gateways.
/// Views/screens only talk to this — never to a specific gateway.
/// To swap gateway: change getPaymentGateway() in payment_service.dart

abstract class PaymentGatewayInterface {
  /// Step 1: Initiate top-up — returns a URL to open in WebView
  Future<PaymentInitResult> initiateTopUp({
    required double amount,
    required String userEmail,
  });

  /// Step 2: Verify after WebView returns (poll or webhook)
  Future<PaymentVerifyResult> verifyPayment({
    required String transactionId,
  });
}

// ── Result models ─────────────────────────────────────────────────────────────

class PaymentInitResult {
  final bool success;
  final String? transactionId;
  final String? paymentUrl;   // open in WebView
  final String? error;

  const PaymentInitResult({
    required this.success,
    this.transactionId,
    this.paymentUrl,
    this.error,
  });
}

class PaymentVerifyResult {
  final bool success;
  final String? transactionId;
  final double? amount;
  final String? error;

  const PaymentVerifyResult({
    required this.success,
    this.transactionId,
    this.amount,
    this.error,
  });
}
