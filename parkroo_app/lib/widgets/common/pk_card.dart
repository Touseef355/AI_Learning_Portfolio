import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';
import '../../theme/app_shadows.dart';

/// Parkroo Premium Card
/// Consistent dark card with optional border, gradient, and press feedback.
class PkCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool elevated;
  final double? borderRadius;
  final Border? customBorder;
  final bool hasBorder;

  const PkCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.elevated = false,
    this.borderRadius,
    this.customBorder,
    this.hasBorder = true,
  });

  @override
  State<PkCard> createState() => _PkCardState();
}

class _PkCardState extends State<PkCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      lowerBound: 0.98,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? AppConstants.radiusLg;

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (_, child) => Transform.scale(scale: _scaleAnim.value, child: child),
      child: GestureDetector(
        onTapDown: widget.onTap != null ? (_) => _ctrl.reverse() : null,
        onTapUp: widget.onTap != null ? (_) => _ctrl.forward() : null,
        onTapCancel: widget.onTap != null ? () => _ctrl.forward() : null,
        onTap: widget.onTap,
        child: Container(
          padding: widget.padding ?? const EdgeInsets.all(AppConstants.sp16),
          decoration: BoxDecoration(
            color: widget.color ?? AppColors.bg2,
            borderRadius: BorderRadius.circular(radius),
            border: widget.customBorder ??
                (widget.hasBorder
                    ? Border.all(color: AppColors.border, width: 1)
                    : null),
            boxShadow: widget.elevated ? AppShadows.md : AppShadows.sm,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Status badge pill — semantic color system
class PkStatusBadge extends StatelessWidget {
  final String label;
  final PkStatusType type;

  const PkStatusBadge({
    super.key,
    required this.label,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (type) {
      case PkStatusType.success:
        bg = AppColors.successGlow; fg = AppColors.success;
        break;
      case PkStatusType.warning:
        bg = AppColors.warningGlow; fg = AppColors.warning;
        break;
      case PkStatusType.danger:
        bg = AppColors.dangerGlow; fg = AppColors.danger;
        break;
      case PkStatusType.info:
        bg = AppColors.primaryGlow; fg = AppColors.primaryLight;
        break;
      case PkStatusType.neutral:
        bg = AppColors.bg4; fg = AppColors.textSecondary;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

enum PkStatusType { success, warning, danger, info, neutral }

/// Divider row for settings-style lists
class PkListTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  const PkListTile({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.sp16,
          vertical: AppConstants.sp12,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!
            else if (showChevron)
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textHint,
              ),
          ],
        ),
      ),
    );
  }
}
