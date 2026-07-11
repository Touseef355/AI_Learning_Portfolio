import 'package:flutter/foundation.dart';
import 'payment_gateway_interface.dart';
import 'mock_payment_service.dart';
import 'simpaisa_payment_service.dart';
import '../../api_service.dart';
import '../../utils/error_utils.dart';

/// Active gateway — fetched from backend on app boot.
/// Default: mock (safe fallback if fetch fails)
String _activeGateway = 'mock';

/// Call this once in main.dart / app init — after login or on splash screen.
/// Backend controls the switch — no app update needed to go to production.
Future<void> initPaymentGateway() async {
  try {
    final config = await ApiService.getAppConfig();
    _activeGateway = config['payment_gateway']?.toString() ?? 'mock';
    if (kDebugMode) {
      print('[Payment] Gateway: $_activeGateway');
    }
  } catch (e, st) {
    // Fallback to mock if config fetch fails
    ErrorUtils.logError('initPaymentGateway', e, st);
    _activeGateway = 'mock';
  }
}

/// Returns the active payment service.
/// Screens import this function only — never a specific service.
PaymentGatewayInterface getPaymentService() {
  return _activeGateway == 'simpaisa'
      ? SimpaisaPaymentService()
      : MockPaymentService();
}
