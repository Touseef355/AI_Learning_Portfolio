import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../api_service.dart';
import '../../utils/error_utils.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/micro_animations.dart';

class BookingDetailScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  const BookingDetailScreen({super.key, required this.booking});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen>
    with TickerProviderStateMixin {
  bool _cancelling = false;
  bool _extending = false;
  bool _paying = false; // for Pay Now wallet deduction

  late final AnimationController _staggerCtrl;
  late final Animation<double> _headerFade;
  late final Animation<double> _qrFade;
  late final Animation<double> _infoFade;
  late final Animation<double> _detailsFade;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _headerFade = CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    );
    _qrFade = CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.1, 0.4, curve: Curves.easeOut),
    );
    _infoFade = CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
    );
    _detailsFade = CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.3, 0.6, curve: Curves.easeOut),
    );

    _staggerCtrl.forward();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  String _formatDateTime(String? dt) {
    if (dt == null || dt.isEmpty) return '—';
    try {
      final d = DateTime.parse(dt).toLocal();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final h = d.hour > 12 ? d.hour - 12 : d.hour == 0 ? 12 : d.hour;
      final m = d.minute.toString().padLeft(2, '0');
      final ampm = d.hour >= 12 ? 'PM' : 'AM';
      final now = DateTime.now();
      final prefix = (d.day == now.day && d.month == now.month && d.year == now.year)
          ? 'Today'
          : '${d.day} ${months[d.month - 1]} ${d.year}';
      return '$prefix · $h:$m $ampm';
    } catch (_) { return dt; }
  }

  String _duration(String? entry, String? exit) {
    if (entry == null || exit == null) return '—';
    try {
      final diff = DateTime.parse(exit).difference(DateTime.parse(entry));
      final h = diff.inHours;
      final m = diff.inMinutes % 60;
      if (h == 0) return '$m min';
      if (m == 0) return '${h}h';
      return '${h}h ${m}m';
    } catch (_) { return '—'; }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':           return AppColors.success;
      case 'confirmed':        return AppColors.primary;
      case 'pending_payment':  return AppColors.warning;
      case 'completed':        return AppColors.success;
      case 'cancelled':        return AppColors.danger;
      case 'expired':          return const Color(0xFF6B7280);
      default:                 return AppColors.warning;
    }
  }

  String _statusText(String status) {
    switch (status.toLowerCase()) {
      case 'active': return 'Active';
      case 'completed': return 'Completed';
      case 'cancelled': return 'Cancelled';
      default:
      return status.isNotEmpty
          ? '${status[0].toUpperCase()}${status.substring(1)}'
          : 'Unknown';
        }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active': return Icons.timer_rounded;
      case 'completed': return Icons.check_circle_rounded;
      case 'cancelled': return Icons.cancel_rounded;
      default: return Icons.info_rounded;
    }
  }

  /// Builds the refund line shown inside the cancel dialog.
  String _refundLine(Map<String, dynamic> preview) {
    final paid = preview['paid'] == true;
    if (!paid) return 'No payment was made — nothing to refund.';
    final pct = preview['refund_percent'];
    final amt = double.tryParse(preview['refund_amount']?.toString() ?? '') ?? 0;
    if (amt <= 0) return 'No refund applies for this booking.';
    return pct == 100
        ? 'You will receive a full refund of Rs. ${amt.toStringAsFixed(0)} in your wallet.'
        : 'You will receive a $pct% refund of Rs. ${amt.toStringAsFixed(0)} in your wallet.';
  }

  Future<void> _cancelBooking() async {
    HapticFeedback.mediumImpact();

    final bookingId = widget.booking['id']?.toString() ?? '';

    // ── Fetch refund preview first — the dialog must show real numbers ──
    setState(() => _cancelling = true);
    final preview = await ApiService.getRefundPreview(bookingId);
    if (!mounted) return;
    setState(() => _cancelling = false);

    if (preview.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorUtils.messageFrom(preview, fallback: 'Could not load refund details')),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Past the refund window — backend won't allow cancel; tell the user why.
    if (preview['cancellable'] == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(preview['reason']?.toString() ?? 'This booking cannot be cancelled'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.of(context).bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Cancel Booking?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.of(context).textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel this booking?',
              style: TextStyle(fontSize: 13, color: AppColors.of(context).textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Text(
                _refundLine(preview),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.of(context).textPrimary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No', style: TextStyle(color: AppColors.of(context).textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _cancelling = true);

    final result = await ApiService.cancelBooking(bookingId);

    if (!mounted) return;
    setState(() => _cancelling = false);

    if (result['status'] == 'cancelled' || result['id'] != null) {
      final refunded =
          double.tryParse(result['refund_amount']?.toString() ?? '') ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(refunded > 0
              ? 'Booking cancelled — Rs. ${refunded.toStringAsFixed(0)} refunded to wallet'
              : 'Booking cancelled successfully'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorUtils.messageFrom(result, fallback: 'Failed to cancel')),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _payNow() async {
    HapticFeedback.mediumImpact();
    final b = widget.booking;
    final bookingId = b['id']?.toString() ?? '';
    final rawAmount = b['estimated_amount']?.toString() ?? b['amount']?.toString() ?? '0';
    final amount = double.tryParse(rawAmount) ?? 0.0;

    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.of(context).bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Pay from Wallet?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.of(context).textPrimary)),
        content: Text(
          'Rs. ${amount.toStringAsFixed(0)} will be deducted from your wallet.',
          style: TextStyle(fontSize: 13, color: AppColors.of(context).textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.of(context).textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pay Now', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _paying = true);

    final result = await ApiService.deductWallet(
      bookingId: bookingId,
      amount: amount,
    );

    if (!mounted) return;
    setState(() => _paying = false);

    if (result['message'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment successful! Rs. ${amount.toStringAsFixed(0)} deducted.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorUtils.messageFrom(result, fallback: 'Payment failed')),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _extendBooking() async {
    HapticFeedback.lightImpact();
    DateTime? pickedTime;

    // Show a time picker dialog
    final now = DateTime.now();
    final currentExit = widget.booking['extended_exit_time'] != null
        ? DateTime.tryParse(widget.booking['extended_exit_time'].toString()) ?? now.add(const Duration(hours: 1))
        : widget.booking['exit_time'] != null
            ? DateTime.tryParse(widget.booking['exit_time'].toString()) ?? now.add(const Duration(hours: 1))
            : now.add(const Duration(hours: 1));

    final picked = await showDateTimePicker(context, initialDate: currentExit.add(const Duration(hours: 1)));
    if (picked == null || !mounted) return;
    pickedTime = picked;

    setState(() => _extending = true);

    final bookingId = widget.booking['id']?.toString() ?? '';
    final result = await ApiService.extendBooking(
      bookingId: bookingId,
      extendedExitTime: pickedTime,
    );

    if (!mounted) return;
    setState(() => _extending = false);

    if (result['message'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Booking extended successfully'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorUtils.messageFrom(result, fallback: 'Failed to extend')),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  /// Simple date + time picker helper
  Future<DateTime?> showDateTimePicker(BuildContext ctx, {required DateTime initialDate}) async {
    final date = await showDatePicker(
      context: ctx,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (date == null || !ctx.mounted) return null;
    final time = await showTimePicker(
      context: ctx,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final status = b['status']?.toString() ?? 'active';
    // Use parking_slot_detail nested map (read-only display field from serializer)
    final detail = b['parking_slot_detail'] as Map<String, dynamic>?;
    final siteName = detail?['site_name']?.toString() ??
        b['site_name']?.toString() ?? 'Parking';
    final slotNum = detail?['slot_number']?.toString() ??
        b['slot_number']?.toString() ?? '—';
    final slotType = detail?['slot_type']?.toString() ??
        b['slot_type']?.toString() ?? 'Normal';
    final amount = b['estimated_amount']?.toString() ?? b['amount']?.toString() ?? '0';
    final bookingId = b['id']?.toString() ?? '—';
    // Compact payload for the cashier scanner. Only stable identifiers go in —
    // times/amounts are fetched live from the API on scan, so an extended
    // booking never shows a stale slip.
    final qrPayload = jsonEncode({
      't': 'parkroo_booking',
      'id': bookingId,
      'plate': b['vehicle_plate']?.toString() ?? '',
      'slot': slotNum,
    });
    final shortId = bookingId.length > 8
        ? bookingId.substring(0, 8).toUpperCase()
        : bookingId.toUpperCase();
    // confirmed = paid but not entered yet (can cancel); active = vehicle inside (can extend/cancel)
    final isActive = status.toLowerCase() == 'active' || status.toLowerCase() == 'confirmed';
    // Pay Now button: completed booking + online method + still pending
    final isPayNow = status.toLowerCase() == 'completed' &&
        (b['payment_method']?.toString() ?? '') == 'online' &&
        (b['payment_status']?.toString() ?? '') == 'pending';
    final statusColor = _statusColor(status);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.of(context).bgDeep,
      body: Column(
        children: [
          // ── Premium Header ──
          FadeTransition(
            opacity: _headerFade,
            child: Container(
              height: 180 + topPadding,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.of(context).bgBase,
                    AppColors.of(context).bgCard,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.of(context).textPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.of(context).border.withOpacity(0.5)),
                          ),
                          child: Icon(Icons.arrow_back_rounded, size: 22, color: AppColors.of(context).textPrimary),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Booking Details',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.of(context).textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '#BK-$shortId',
                                style: TextStyle(fontSize: 13, color: AppColors.of(context).textSecondary),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: statusColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_statusIcon(status), size: 14, color: statusColor),
                                const SizedBox(width: 6),
                                Text(
                                  _statusText(status),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Scrollable Content ──
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // QR Code Section
                  if (status.toLowerCase() != 'cancelled')
                    FadeTransition(
                      opacity: _qrFade,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(_qrFade),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.of(context).bgCard,
                                AppColors.of(context).bgCard,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.of(context).border),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  // Always white — QR needs dark-on-light
                                  // contrast to scan reliably in both themes.
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 20,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: QrImageView(
                                  data: qrPayload,
                                  version: QrVersions.auto,
                                  size: 168,
                                  gapless: true,
                                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: Colors.black,
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Booking #$shortId',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: AppColors.of(context).textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Show QR at entry gate',
                                style: TextStyle(fontSize: 12, color: AppColors.of(context).textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  if (status.toLowerCase() != 'cancelled') const SizedBox(height: 20),

                  // Parking Info Card
                  FadeTransition(
                    opacity: _infoFade,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(_infoFade),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.of(context).bgCard,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.of(context).border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [AppColors.primary, AppColors.gradientEnd],
                                ),
                                borderRadius: BorderRadius.all(Radius.circular(18)),
                              ),
                              child: Icon(Icons.local_parking_rounded, color: AppColors.of(context).textPrimary, size: 26),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    siteName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.of(context).textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                                        ),
                                        child: Text(
                                          'Slot $slotNum',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.of(context).border,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: AppColors.of(context).textPrimary.withOpacity(0.1)),
                                        ),
                                        child: Text(
                                          slotType.isNotEmpty ? '${slotType[0].toUpperCase()}${slotType.substring(1)}' : 'Normal',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.of(context).textSecondary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Booking Details Card
                  FadeTransition(
                    opacity: _detailsFade,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(_detailsFade),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.of(context).bgCard,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.of(context).border),
                        ),
                        child: Column(
                          children: [
                            _PremiumDetailRow(
                              label: 'Booking ID',
                              value: '#BK-$shortId',
                            ),
                            Divider(height: 24, color: AppColors.of(context).border),
                            _PremiumDetailRow(
                              label: 'Check-in',
                              value: _formatDateTime(b['entry_time']),
                            ),
                            Divider(height: 24, color: AppColors.of(context).border),
                            _PremiumDetailRow(
                              label: 'Check-out',
                              value: _formatDateTime(b['exit_time']),
                            ),
                            Divider(height: 24, color: AppColors.of(context).border),
                            _PremiumDetailRow(
                              label: 'Duration',
                              value: _duration(b['entry_time'], b['exit_time']),
                            ),
                            Divider(height: 24, color: AppColors.of(context).border),
                            _PremiumDetailRow(
                              label: 'Vehicle',
                              value: b['vehicle_name']?.toString()
                                ?? b['vehicle_plate']?.toString()
                                ?? '—',
                            ),
                            Divider(height: 24, color: AppColors.of(context).border),
                            _PremiumDetailRow(
                              label: 'Payment Method',
                              value: b['payment_method']?.toString() ?? 'Cash',
                            ),
                            Divider(height: 24, color: AppColors.of(context).border),
                            Container(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Amount',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.of(context).textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'PKR $amount',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action Buttons — Cancel + Extend
          if (isActive)
            Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
              decoration: BoxDecoration(
                color: AppColors.of(context).bgBase,
                border: Border(top: BorderSide(color: AppColors.of(context).border)),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 20, offset: Offset(0, -8)),
                ],
              ),
              child: Row(
                children: [
                  // Extend button
                  Expanded(
                    child: TapScale(
                      onTap: _extending ? null : _extendBooking,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                        ),
                        child: Center(
                          child: _extending
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.more_time_rounded, size: 20, color: AppColors.primary),
                                    SizedBox(width: 8),
                                    Text('Extend', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Cancel button
                  Expanded(
                    child: TapScale(
                      onTap: _cancelling ? null : _cancelBooking,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: AppColors.danger.withOpacity(0.4)),
                        ),
                        child: Center(
                          child: _cancelling
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppColors.danger, strokeWidth: 2))
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.cancel_rounded, size: 20, color: AppColors.danger),
                                    SizedBox(width: 8),
                                    Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.danger)),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Pay Now button — completed online booking with pending payment
          if (isPayNow)
            Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
              decoration: BoxDecoration(
                color: AppColors.of(context).bgBase,
                border: Border(top: BorderSide(color: AppColors.of(context).border)),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 20, offset: Offset(0, -8)),
                ],
              ),
              child: TapScale(
                onTap: _paying ? null : _payNow,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: _paying ? null : const LinearGradient(
                      colors: [AppColors.primary, AppColors.gradientEnd],
                    ),
                    color: _paying ? AppColors.primary : null,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Center(
                    child: _paying
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.account_balance_wallet_rounded, size: 20, color: Colors.white),
                              const SizedBox(width: 10),
                              Text(
                                'Pay Rs. ${(double.tryParse(widget.booking['estimated_amount']?.toString() ?? widget.booking['amount']?.toString() ?? '0') ?? 0).toStringAsFixed(0)} from Wallet',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PREMIUM DETAIL ROW
// ═══════════════════════════════════════════════════════════════

class _PremiumDetailRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final bool isLast;
  final double fontSize;

  const _PremiumDetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isLast = false,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: AppColors.of(context).textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.of(context).textPrimary,
          ),
        ),
      ],
    );
  }
}