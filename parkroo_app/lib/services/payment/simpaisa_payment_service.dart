import 'payment_gateway_interface.dart';
import '../../api_service.dart';
import '../../utils/error_utils.dart';

/// Simpaisa payment service — production implementation.
///
/// HOW TO ACTIVATE:
/// 1. Get Simpaisa merchant credentials (API key, secret, merchant ID)
/// 2. Add to Django settings.py:
///       PAYMENT_GATEWAY    = 'simpaisa'
///       SIMPAISA_API_KEY   = '...'
///       SIMPAISA_SECRET_KEY= '...'
///       SIMPAISA_MERCHANT_ID = '...'
///       SIMPAISA_BASE_URL  = 'https://api.simpaisa.com/api/v1'
/// 3. In payment_service.dart: change getPaymentService() to return SimpaisaPaymentService()
/// 4. Fill in TODO sections in backend/payments/gateway/simpaisa.py
///
/// Flutter side stays EXACTLY the same — only this file + backend simpaisa.py change.
class SimpaisaPaymentService implements PaymentGatewayInterface {

  @override
  Future<PaymentInitResult> initiateTopUp({
    required double amount,
    required String userEmail,
  }) async {
    // TODO: Same as MockPaymentService — backend handles the gateway switch
    // Flutter code is identical — no changes needed here
    try {
      final result = await ApiService.initiateTopUp(amount: amount);

      if (result['payment_url'] != null) {
        return PaymentInitResult(
          success:       true,
          transactionId: result['transaction_id']?.toString(),
          paymentUrl:    result['payment_url'].toString(),
          // Simpaisa returns their hosted payment page URL
          // Flutter opens it in WebView — same as mock
        );
      }
      return PaymentInitResult(
        success: false,
        error:   result['error'] ?? 'Failed to initiate payment',
      );
    } catch (e, st) {
      ErrorUtils.logError('SimpaisaPaymentService.initiateTopUp', e, st);
      return PaymentInitResult(success: false, error: ErrorUtils.friendlyMessage(e));
    }
  }

  @override
  Future<PaymentVerifyResult> verifyPayment({
    required String transactionId,
  }) async {
    // TODO: Same flow — backend webhook handles Simpaisa verification
    // Flutter just fetches updated wallet balance
    try {
      final wallet = await ApiService.getWallet();
      if (wallet.containsKey('error')) {
        return PaymentVerifyResult(success: false, error: wallet['error'].toString());
      }
      return PaymentVerifyResult(
        success:       true,
        transactionId: transactionId,
        amount:        double.tryParse(wallet['balance']?.toString() ?? '0'),
      );
    } catch (e, st) {
      ErrorUtils.logError('SimpaisaPaymentService.verifyPayment', e, st);
      return PaymentVerifyResult(success: false, error: ErrorUtils.friendlyMessage(e));
    }
  }
}
