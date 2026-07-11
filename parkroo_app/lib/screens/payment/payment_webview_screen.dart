import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/payment/payment_service.dart';
import '../../utils/error_utils.dart';

/// Opens payment gateway URL in WebView.
/// Works for both Mock (our own HTML page) and Simpaisa (their hosted page).
/// Returns true to wallet screen if payment was successful.
class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String transactionId;
  final double amount;

  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.transactionId,
    required this.amount,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _paymentDone = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _isLoading = true),
        onPageFinished: (url) {
          setState(() => _isLoading = false);
          _checkCallbackUrl(url);
        },
      ))
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _checkCallbackUrl(String url) {
    // Security: don't trust status=success in URL — it can be forged.
    // Instead: detect we're back on our callback URL, then ask backend
    // to verify the actual payment status from its own records.
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final isCallback = url.contains('/topup/callback') ||
        url.contains('txn_id=');

    if (isCallback && !_paymentDone) {
      _paymentDone = true;
      HapticFeedback.heavyImpact();

      // Let backend verify — it checks its own TopUpTransaction record
      // not the URL param. Mock always succeeds; Simpaisa checks real status.
     // payment_webview_screen.dart
      getPaymentService()
          .verifyPayment(transactionId: widget.transactionId.isNotEmpty
              ? widget.transactionId
              : '')
          .then((result) {
        if (!result.success) {
          ErrorUtils.logError(
            'PaymentWebViewScreen.verifyPayment',
            result.error ?? 'verification failed with no error message',
          );
        }
        if (mounted) Navigator.pop(context, result.success);
      }).catchError((Object e, StackTrace st) {
        // verifyPayment() already catches internally and shouldn't throw,
        // but don't let an unexpected exception strand the user on the
        // WebView with no way forward.
        ErrorUtils.logError('PaymentWebViewScreen.verifyPayment', e, st);
        if (mounted) Navigator.pop(context, false);
      });
    }

    // Payment explicitly cancelled by user on gateway page
    if (url.contains('status=cancelled') || url.contains('status=failed')) {
      if (!_paymentDone) {
        _paymentDone = true;
        Navigator.pop(context, false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Funds',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
            Text(
              'Rs. ${widget.amount.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
        ],
      ),
    );
  }
}
