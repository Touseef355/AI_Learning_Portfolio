import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';
import '../../theme/app_text_styles.dart';
import 'pk_button.dart';

/// Parkroo Empty State Widget
/// Professional icon-based empty states — no emoji, no stock illustrations.
class PkEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  const PkEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.sp32,
          vertical: AppConstants.sp40,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: color),
            ),
            const SizedBox(height: AppConstants.sp20),
            Text(title, style: AppTextStyles.h3, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: AppConstants.sp8),
              Text(
                message!,
                style: AppTextStyles.bodyMd,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppConstants.sp24),
              PkButton(
                label: actionLabel!,
                onPressed: onAction,
                fullWidth: false,
                size: PkButtonSize.medium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
