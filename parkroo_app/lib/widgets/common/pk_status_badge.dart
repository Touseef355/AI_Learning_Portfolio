import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';

/// Unified status badge for bookings, payments, etc.
/// Replaces all hardcoded Color(0xFF...) status checks across screens.
///
/// Usage:
///   PkStatusBadge(status: booking['status'])
///   PkStatusBadge(status: booking['payment_status'])
class PkStatusBadge extends StatelessWidget {
  final String status;
  final bool compact;

  const PkStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _resolve(status.toLowerCase());
    final double dotSize = compact ? 6 : 7;
    final double fontSize = compact ? 11 : 12;
    final double hPad = compact ? 8 : 10;
    final double vPad = compact ? 3 : 5;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: config.bg,
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
        border: Border.all(color: config.border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: config.dot,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: compact ? 5 : 6),
          Text(
            config.label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: config.text,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  _StatusConfig _resolve(String s) {
    switch (s) {
      // ── Booking statuses ─────────────────────────────────
      case 'pending_payment':
        return _StatusConfig(
          label:  'Pending Payment',
          dot:    AppColors.warning,
          text:   const Color(0xFFF59E0B),
          bg:     const Color(0x1AF59E0B),
          border: const Color(0x33F59E0B),
        );
      case 'confirmed':
        return _StatusConfig(
          label:  'Confirmed',
          dot:    AppColors.primary,
          text:   AppColors.primary,
          bg:     AppColors.primaryGlow,
          border: const Color(0x334F6EF7),
        );
      case 'active':
        return _StatusConfig(
          label:  'Active',
          dot:    AppColors.success,
          text:   AppColors.success,
          bg:     AppColors.successGlow,
          border: const Color(0x3322C55E),
        );
      case 'completed':
        return _StatusConfig(
          label:  'Completed',
          dot:    const Color(0xFF22C55E),
          text:   const Color(0xFF22C55E),
          bg:     const Color(0x1A22C55E),
          border: const Color(0x3322C55E),
        );
      case 'cancelled':
        return _StatusConfig(
          label:  'Cancelled',
          dot:    AppColors.danger,
          text:   AppColors.danger,
          bg:     AppColors.dangerGlow,
          border: const Color(0x33EF4444),
        );
      case 'expired':
        return _StatusConfig(
          label:  'Expired',
          dot:    const Color(0xFF6B7280),
          text:   const Color(0xFF6B7280),
          bg:     const Color(0x1A6B7280),
          border: const Color(0x336B7280),
        );
      // ── Payment statuses ──────────────────────────────────
      case 'paid':
        return _StatusConfig(
          label:  'Paid',
          dot:    AppColors.success,
          text:   AppColors.success,
          bg:     AppColors.successGlow,
          border: const Color(0x3322C55E),
        );
      case 'pending':
        return _StatusConfig(
          label:  'Unpaid',
          dot:    AppColors.warning,
          text:   AppColors.warning,
          bg:     AppColors.warningGlow,
          border: const Color(0x33F59E0B),
        );
      case 'failed':
        return _StatusConfig(
          label:  'Failed',
          dot:    AppColors.danger,
          text:   AppColors.danger,
          bg:     AppColors.dangerGlow,
          border: const Color(0x33EF4444),
        );
      // ── Withdrawal statuses ───────────────────────────────
      case 'approved':
        return _StatusConfig(
          label:  'Approved',
          dot:    AppColors.success,
          text:   AppColors.success,
          bg:     AppColors.successGlow,
          border: const Color(0x3322C55E),
        );
      case 'rejected':
        return _StatusConfig(
          label:  'Rejected',
          dot:    AppColors.danger,
          text:   AppColors.danger,
          bg:     AppColors.dangerGlow,
          border: const Color(0x33EF4444),
        );
      default:
        return _StatusConfig(
          label:  s.isEmpty ? 'Unknown' : '${s[0].toUpperCase()}${s.substring(1)}',
          dot:    const Color(0xFF6B7280),
          text:   const Color(0xFF6B7280),
          bg:     const Color(0x1A6B7280),
          border: const Color(0x336B7280),
        );
    }
  }
}

class _StatusConfig {
  final String label;
  final Color dot, text, bg, border;
  const _StatusConfig({
    required this.label,
    required this.dot,
    required this.text,
    required this.bg,
    required this.border,
  });
}
