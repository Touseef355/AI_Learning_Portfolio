import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api_service.dart';
import '../../utils/error_utils.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/micro_animations.dart';
import 'booking_detail_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with TickerProviderStateMixin {
  List<dynamic> _bookings = [];
  bool _isLoading = true;
  int _selectedTab = 0; // 0 = Current, 1 = History
  final Set<String> _payingBookingIds = {};

  late final AnimationController _staggerCtrl;
  late final Animation<double> _headerFade;
  late final Animation<double> _listFade;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _headerFade = CurvedAnimation(parent: _staggerCtrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut));
    _listFade = CurvedAnimation(parent: _staggerCtrl,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOut));
    _loadBookings();
    _staggerCtrl.forward();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.getBookings();
      if (mounted) {
        setState(() {
          _bookings = result;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      ErrorUtils.logError('MyBookingsScreen._loadBookings', e, st);
      if (!mounted) return;
      setState(() => _isLoading = false);
      final message = e is ApiException ? e.message : ErrorUtils.friendlyMessage(e);
      final retryable = e is ApiException ? e.error.retryable : true;
      ErrorUtils.showErrorSnack(context, message, onRetry: retryable ? _loadBookings : null);
    }
  }

  Future<void> _payNow(Map<String, dynamic> booking) async {
    final bookingId = booking['id'].toString();
    if (_payingBookingIds.contains(bookingId)) return; // already in flight

    final amount =
        double.tryParse(
          (booking['estimated_amount'] ?? 0).toString(),
        ) ??
        0;

    setState(() => _payingBookingIds.add(bookingId));

    final result = await ApiService.deductWallet(
      bookingId: bookingId,
      amount: amount,
    );

    if (!mounted) return;
    setState(() => _payingBookingIds.remove(bookingId));

    if (result['error'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking confirmed successfully'),
        ),
      );
      _loadBookings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorUtils.messageFrom(result, fallback: 'Payment failed')),
        ),
      );
    }
  }
  List<dynamic> get _currentBookings {
    return _bookings.where((b) {
      final status = b['status']?.toString().toLowerCase() ?? '';
      return status == 'active' || status == 'confirmed' || status == 'pending_payment';
    }).toList();
  }

  List<dynamic> get _historyBookings {
    return _bookings.where((b) {
      final status = b['status']?.toString().toLowerCase() ?? '';
      return status == 'completed' || status == 'cancelled' || status == 'expired';
    }).toList();
  }

  List<dynamic> get _displayBookings => _selectedTab == 0 ? _currentBookings : _historyBookings;

  Map<String, dynamic>? get _activeBooking {
    final active = _currentBookings.firstWhere(
      (b) => b['status']?.toString().toLowerCase() == 'active',
      orElse: () => null,
    );
    return active as Map<String, dynamic>?;
  }

  String _siteName(Map<String, dynamic> b) {
    final d = b['parking_slot_detail'];
    if (d is Map) return d['site_name']?.toString() ?? 'Parking';
    return b['site_name']?.toString() ?? 'Parking';
  }

  String _slotNum(Map<String, dynamic> b) {
    final d = b['parking_slot_detail'];
    if (d is Map) return d['slot_number']?.toString() ?? '—';
    return b['slot_number']?.toString() ?? '—';
  }

  String _amount(Map<String, dynamic> b) {
    final a = b['estimated_amount'] ?? b['amount'];
    if (a == null) return '0';
    final d = double.tryParse(a.toString()) ?? 0;
    return d.toInt().toString();
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${mo[dt.month - 1]} ${dt.year}';
    } catch (_) { return iso; }
  }

  String _formatTimeRange(String? entry, String? exit) {
    if (entry == null) return '—';
    try {
      final e = DateTime.parse(entry).toLocal();
      final eh = e.hour > 12 ? e.hour - 12 : e.hour == 0 ? 12 : e.hour;
      final em = e.minute.toString().padLeft(2, '0');
      final ea = e.hour >= 12 ? 'PM' : 'AM';
      if (exit == null || exit.isEmpty) return '$eh:$em $ea';
      final x = DateTime.parse(exit).toLocal();
      final xh = x.hour > 12 ? x.hour - 12 : x.hour == 0 ? 12 : x.hour;
      final xm = x.minute.toString().padLeft(2, '0');
      final xa = x.hour >= 12 ? 'PM' : 'AM';
      return '$eh:$em $ea - $xh:$xm $xa';
    } catch (_) { return entry; }
  }

  String _duration(String? entry, String? exit) {
    if (entry == null || exit == null) return '';
    try {
      final diff = DateTime.parse(exit).difference(DateTime.parse(entry));
      final h = diff.inHours;
      final m = diff.inMinutes % 60;
      if (h == 0) return '${m}m';
      if (m == 0) return '${h}h';
      return '${h}h ${m}m';
    } catch (_) { return ''; }
  }

  String _getLiveDuration(String? entry) {
    if (entry == null) return '';
    try {
      final start = DateTime.parse(entry);
      final diff = DateTime.now().difference(start);
      final h = diff.inHours;
      final m = diff.inMinutes % 60;
      if (h == 0) return '${m}m';
      if (m == 0) return '${h}h';
      return '${h}h ${m}m';
    } catch (_) { return ''; }
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'active': return AppColors.success;
      case 'completed': return const Color(0xFF6B7280);
      case 'cancelled': return AppColors.danger;
      default: return AppColors.warning;
    }
  }

  String _statusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'active': return 'Active';
      case 'completed': return 'Completed';
      case 'cancelled': return 'Cancelled';
      default: return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final topPad = MediaQuery.of(context).padding.top;
    final activeBooking = _activeBooking;

    return Scaffold(
      backgroundColor: colors.bgBase,
      body: Column(
        children: [
          // Header
          FadeTransition(
            opacity: _headerFade,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'My Bookings',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isLoading ? 'Loading...' : 'Track your parking activity',
                    style: TextStyle(fontSize: 13, color: colors.textHint),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Active Booking Hero Card
          if (!_isLoading && activeBooking != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ActiveBookingHero(
                siteName: _siteName(activeBooking),
                slotNum: _slotNum(activeBooking),
                entryTime: _formatTimeRange(
                  activeBooking['entry_time']?.toString(),
                  null,
                ),
                liveDuration: _getLiveDuration(activeBooking['entry_time']?.toString()),
                amount: _amount(activeBooking),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookingDetailScreen(booking: activeBooking),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 20),

          // Tabs: Current | History
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.bgCard,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    _buildTab(0, 'Current', _currentBookings.length, colors),
                    _buildTab(1, 'History', _historyBookings.length, colors),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // List
          Expanded(
            child: _isLoading
                ? _LoadingSkeleton()
                : _displayBookings.isEmpty
                    ? _EmptyState(tab: _selectedTab)
                    : FadeTransition(
                        opacity: _listFade,
                        child: RefreshIndicator(
                          onRefresh: _loadBookings,
                          color: AppColors.primary,
                          backgroundColor: colors.bgCard,
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                            itemCount: _displayBookings.length,
                            itemBuilder: (ctx, i) {
                              final b = _displayBookings[i] as Map<String, dynamic>;
                              final status = b['status']?.toString() ?? '';
                              if (status.toLowerCase() == 'pending_payment') {
                                final bId = b['id']?.toString() ?? '';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _PendingPaymentCard(
                                    booking: b,
                                    isPaying: _payingBookingIds.contains(bId),
                                    onPayNow: () => _payNow(b),
                                  ),
                                );
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _HistoryCard(
                                  siteName: _siteName(b),
                                  date: _formatDate(
                                    b['entry_time']?.toString() ??
                                    b['created_at']?.toString(),
                                  ),
                                  amount: _amount(b),
                                  status: _statusLabel(status),
                                  statusColor: _statusColor(status),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BookingDetailScreen(
                                        booking: b,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label, int count, AppColorScheme colors) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(colors: AppColors.primaryGradient)
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Center(
            child: Text(
              '$label ($count)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ACTIVE BOOKING HERO CARD
// ═══════════════════════════════════════════════════════════════

class _ActiveBookingHero extends StatelessWidget {
  final String siteName, slotNum, entryTime, liveDuration, amount;
  final VoidCallback onTap;

  const _ActiveBookingHero({
    required this.siteName,
    required this.slotNum,
    required this.entryTime,
    required this.liveDuration,
    required this.amount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.success.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withOpacity(0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'ACTIVE BOOKING',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              siteName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Slot $slotNum',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Started',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entryTime,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Duration',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        liveDuration,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  '₨ $amount',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.success.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'View Details',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HISTORY CARD — Simplified
// ═══════════════════════════════════════════════════════════════

class _HistoryCard extends StatelessWidget {
  final String siteName, date, amount, status;
  final Color statusColor;
  final VoidCallback onTap;

  const _HistoryCard({
    required this.siteName,
    required this.date,
    required this.amount,
    required this.status,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                status == 'Completed' ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 24,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    siteName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textHint,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₨ $amount',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// LOADING SKELETON
// ═══════════════════════════════════════════════════════════════

class _LoadingSkeleton extends StatefulWidget {
  @override
  State<_LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<_LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final c = Color.lerp(colors.bgCard, colors.bgElevated, _anim.value)!;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          itemCount: 4,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              height: 90,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// EMPTY STATE
// ═══════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final int tab;
  const _EmptyState({required this.tab});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isCurrent = tab == 0;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child: Icon(
              isCurrent ? Icons.local_parking_rounded : Icons.history_rounded,
              size: 36,
              color: AppColors.primary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isCurrent ? 'No active bookings' : 'No booking history',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isCurrent
                ? 'Book a parking slot to see it here'
                : 'Your completed bookings will appear here',
            style: TextStyle(
              fontSize: 13,
              color: colors.textHint,
            ),
          ),
          if (isCurrent) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: AppColors.primaryGradient),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Find Parking',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingPaymentCard extends StatelessWidget {

  final Map<String, dynamic> booking;
  final VoidCallback onPayNow;
  final bool isPaying;

  const _PendingPaymentCard({
    required this.booking,
    required this.onPayNow,
    this.isPaying = false,
  });

  @override
  Widget build(BuildContext context) {

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1E00),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.orange,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
              ),
              SizedBox(width: 8),
              Text(
                'Payment Pending',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            booking['parking_slot_detail'] != null
                ? booking['parking_slot_detail']['site_name'].toString()
                : 'Parking',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Amount: Rs ${booking['estimated_amount']}',
            style: const TextStyle(
              color: Colors.white70,
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isPaying ? null : onPayNow,
              child: isPaying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Pay Now'),
            ),
          ),
        ],
      ),
    );
  }
}