import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/error_utils.dart';
import 'buy_pass_screen.dart';

/// Lists the user's parking passes with validity progress and
/// cancel-with-prorated-refund.
class MyPassesScreen extends StatefulWidget {
  const MyPassesScreen({super.key});

  @override
  State<MyPassesScreen> createState() => _MyPassesScreenState();
}

class _MyPassesScreenState extends State<MyPassesScreen> {
  List<dynamic> _passes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final passes = await ApiService.getMyPasses();
    if (!mounted) return;
    setState(() {
      _passes = passes;
      _loading = false;
    });
  }

  Future<void> _buyPass() async {
    final bought = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const BuyPassScreen()),
    );
    if (bought == true) _load();
  }

  Future<void> _cancelPass(Map<String, dynamic> pass) async {
    HapticFeedback.mediumImpact();
    final c = AppColors.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Cancel Pass?',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary)),
        content: Text(
          'Your remaining days will be refunded to your wallet on a prorated '
          'basis, and slot ${pass['slot_number']} will be released.',
          style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep Pass', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Pass',
                style: TextStyle(
                    color: AppColors.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final res = await ApiService.cancelPass(pass['id'].toString());
    if (!mounted) return;

    if (res.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(ErrorUtils.messageFrom(res, fallback: 'Could not cancel pass')),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final refunded = double.tryParse(res['refund_amount']?.toString() ?? '') ?? 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(refunded > 0
            ? 'Pass cancelled — Rs. ${refunded.toStringAsFixed(0)} refunded to wallet'
            : 'Pass cancelled'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    _load();
  }

  // ─────────────────────────── UI ───────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: c.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Parking Passes',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _buyPass,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_card_rounded, color: Colors.white, size: 20),
        label: const Text('Buy Pass',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _passes.isEmpty
              ? _emptyState(c)
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    itemCount: _passes.length,
                    itemBuilder: (_, i) => _passCard(c, _passes[i]),
                  ),
                ),
    );
  }

  Widget _emptyState(dynamic c) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.card_membership_rounded,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 18),
          Text('No passes yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Park daily at the same place? Get a weekly pass with your own '
              'dedicated slot and save up to 25%.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 13, color: c.textSecondary, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  (Color, String) _statusStyle(String status) {
    switch (status) {
      case 'active':
        return (AppColors.success, 'ACTIVE');
      case 'expired':
        return (AppColors.warning, 'EXPIRED');
      default:
        return (AppColors.danger, 'CANCELLED');
    }
  }

  String _fmtTime(String? t) {
    if (t == null) return '--:--';
    final parts = t.split(':');
    return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : t;
  }

  double _progress(Map<String, dynamic> p) {
    try {
      final start = DateTime.parse(p['start_date']);
      final end = DateTime.parse(p['end_date']).add(const Duration(days: 1));
      final now = DateTime.now();
      if (now.isBefore(start)) return 0;
      if (now.isAfter(end)) return 1;
      return now.difference(start).inHours / end.difference(start).inHours;
    } catch (_) {
      return 0;
    }
  }

  int _daysLeft(Map<String, dynamic> p) {
    try {
      final end = DateTime.parse(p['end_date']);
      final left = end.difference(DateTime.now()).inDays + 1;
      return left < 0 ? 0 : left;
    } catch (_) {
      return 0;
    }
  }

  Widget _passCard(dynamic c, Map<String, dynamic> p) {
    final status = p['status']?.toString() ?? 'active';
    final (statusColor, statusLabel) = _statusStyle(status);
    final isActive = status == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isActive ? AppColors.primary.withOpacity(0.3) : c.border,
            width: isActive ? 1 : 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  p['slot_number']?.toString() ?? '?',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['site_name']?.toString() ?? 'Parking Site',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary)),
                    const SizedBox(height: 2),
                    Text(p['vehicle_plate']?.toString() ?? '',
                        style:
                            TextStyle(fontSize: 12, color: c.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 14, color: c.textSecondary),
              const SizedBox(width: 6),
              Text(
                  'Daily ${_fmtTime(p['daily_start']?.toString())} – ${_fmtTime(p['daily_end']?.toString())}',
                  style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
              const Spacer(),
              Text('Rs. ${p['amount']}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          Text('${p['start_date']}  →  ${p['end_date']}',
              style: TextStyle(fontSize: 11.5, color: c.textHint)),
          if (isActive) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _progress(p),
                minHeight: 6,
                backgroundColor: c.bgElevated,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_daysLeft(p)} days left',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: c.textSecondary)),
                GestureDetector(
                  onTap: () => _cancelPass(p),
                  child: Text('Cancel Pass',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
