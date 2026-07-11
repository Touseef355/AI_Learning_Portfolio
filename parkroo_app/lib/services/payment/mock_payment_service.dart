import 'dart:async';
import 'payment_gateway_interface.dart';
import '../../api_service.dart';
import '../../utils/error_utils.dart';

/// Mock payment service — used during development/testing.
/// Simulates a real payment flow:
///   1. initiateTopUp → returns a URL (our backend mock confirm page)
///   2. User "pays" on that page → redirected back
///   3. verifyPayment → backend credits wallet
///
/// No real money involved. Switch to SimpaisaPaymentService for production.
class MockPaymentService implements PaymentGatewayInterface {

  @override
  Future<PaymentInitResult> initiateTopUp({
    required double amount,
    required String userEmail,
  }) async {
    try {
      // Call backend — backend uses MockGateway to generate fake payment URL
      final result = await ApiService.initiateTopUp(amount: amount);

      if (result['payment_url'] != null) {
        return PaymentInitResult(
          success:       true,
          transactionId: result['transaction_id']?.toString(),
          paymentUrl:    result['payment_url'].toString(),
        );
      }
      return PaymentInitResult(
        success: false,
        error:   result['error'] ?? 'Failed to initiate payment',
      );
    } catch (e, st) {
      ErrorUtils.logError('MockPaymentService.initiateTopUp', e, st);
      return PaymentInitResult(success: false, error: ErrorUtils.friendlyMessage(e));
    }
  }

  @override
  Future<PaymentVerifyResult> verifyPayment({
    required String transactionId,
  }) async {
    // Mock: backend already credited wallet on callback
    // Just fetch updated wallet balance
    try {
      final wallet = await ApiService.getWallet();
      if (wallet.containsKey('error')) {
        // getWallet() reports failure via an 'error' key rather than
        // throwing — treat it as a failed verification, not a success.
        return PaymentVerifyResult(success: false, error: wallet['error'].toString());
      }
      return PaymentVerifyResult(
        success:       true,
        transactionId: transactionId,
        amount:        double.tryParse(wallet['balance']?.toString() ?? '0'),
      );
    } catch (e, st) {
      ErrorUtils.logError('MockPaymentService.verifyPayment', e, st);
      return PaymentVerifyResult(success: false, error: ErrorUtils.friendlyMessage(e));
    }
  }
}
