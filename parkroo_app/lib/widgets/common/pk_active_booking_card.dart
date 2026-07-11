import 'dart:async';

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';
import '../../theme/app_text_styles.dart';
import 'pk_button.dart';

/// Premium Active Booking Card for Home Screen
/// Displays current active booking with timer and extend option.
class PkActiveBookingCard extends StatefulWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onViewDetails;
  final VoidCallback onExtend;

  const PkActiveBookingCard({
    super.key,
    required this.booking,
    required this.onViewDetails,
    required this.onExtend,
  });

  @override
  State<PkActiveBookingCard> createState() => _PkActiveBookingCardState();
}

class _PkActiveBookingCardState extends State<PkActiveBookingCard> {
  Duration _remaining = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateRemaining();
    });
  }

  void _updateRemaining() {
    final exitTimeStr = widget.booking['exit_time']?.toString();
    if (exitTimeStr != null) {
      try {
        final exitTime = DateTime.parse(exitTimeStr);
        final remaining = exitTime.difference(DateTime.now());
        if (_remaining != remaining) {
          setState(() => _remaining = remaining > Duration.zero ? remaining : Duration.zero);
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTimeRemaining() {
    if (_remaining <= Duration.zero) return 'Expired';
    final hours = _remaining.inHours;
    final minutes = _remaining.inMinutes % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  double get _progress {
    final entryTimeStr = widget.booking['entry_time']?.toString();
    final exitTimeStr = widget.booking['exit_time']?.toString();
    if (entryTimeStr == null || exitTimeStr == null) return 0;
    try {
      final entry = DateTime.parse(entryTimeStr);
      final exit = DateTime.parse(exitTimeStr);
      final total = exit.difference(entry);
      final elapsed = DateTime.now().difference(entry);
      return (elapsed.inSeconds / total.inSeconds).clamp(0.0, 1.0);
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final siteName = widget.booking['parking_slot']?['parking_site']?['name']?.toString() ??
        widget.booking['parking_site_name']?.toString() ??
        widget.booking['site_name']?.toString() ??
        'Parking';

    final slotNumber = widget.booking['parking_slot']?['slot_number']?.toString() ??
        widget.booking['slot_label']?.toString() ??
        '—';

    final isExpiring = _remaining <= const Duration(minutes: 30) && _remaining > Duration.zero;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.bg2,
            isExpiring ? AppColors.warning.withOpacity(0.1) : AppColors.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(
          color: isExpiring
              ? AppColors.warning.withOpacity(0.3)
              : AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.sp16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isExpiring ? AppColors.warning : AppColors.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isExpiring ? AppColors.warning : AppColors.success).withOpacity(0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppConstants.sp8),
                Text(
                  isExpiring ? 'Parking ending soon' : 'Active parking',
                  style: AppTextStyles.labelSm.copyWith(
                    color: isExpiring ? AppColors.warning : AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.sp12),
            // Parking info
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  child: const Icon(
                    Icons.local_parking_rounded,
                    size: 24,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppConstants.sp12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        siteName,
                        style: AppTextStyles.titleMd,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppConstants.sp4),
                      Text(
                        'Slot $slotNumber',
                        style: AppTextStyles.bodySm,
                      ),
                    ],
                  ),
                ),
                // Time remaining pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.sp12,
                    vertical: AppConstants.sp6,
                  ),
                  decoration: BoxDecoration(
                    color: isExpiring
                        ? AppColors.warning.withOpacity(0.15)
                        : AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                    border: Border.all(
                      color: isExpiring
                          ? AppColors.warning.withOpacity(0.3)
                          : AppColors.success.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    _formatTimeRemaining(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isExpiring ? AppColors.warning : AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
            // Progress bar
            const SizedBox(height: AppConstants.sp16),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusXs),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 4,
                backgroundColor: AppColors.bg4,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isExpiring ? AppColors.warning : AppColors.success,
                ),
              ),
            ),
            const SizedBox(height: AppConstants.sp16),
            // Actions
            Row(
              children: [
                Expanded(
                  child: PkButton(
                    label: 'View Details',
                    variant: PkButtonVariant.secondary,
                    size: PkButtonSize.small,
                    fullWidth: true,
                    onPressed: widget.onViewDetails,
                  ),
                ),
                const SizedBox(width: AppConstants.sp12),
                Expanded(
                  child: PkButton(
                    label: 'Extend',
                    variant: PkButtonVariant.primary,
                    size: PkButtonSize.small,
                    fullWidth: true,
                    onPressed: widget.onExtend,
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