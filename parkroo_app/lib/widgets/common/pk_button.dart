import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_shadows.dart';

enum PkButtonVariant { primary, secondary, ghost, danger, success }
enum PkButtonSize { large, medium, small }

/// Parkroo Premium Button — Phase 1 Polish
/// Spring press, haptic feedback, premium feel
class PkButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool iconTrailing;
  final bool isLoading;
  final bool fullWidth;
  final PkButtonVariant variant;
  final PkButtonSize size;

  const PkButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.iconTrailing = false,
    this.isLoading = false,
    this.fullWidth = true,
    this.variant = PkButtonVariant.primary,
    this.size = PkButtonSize.large,
  });

  @override
  State<PkButton> createState() => _PkButtonState();
}

class _PkButtonState extends State<PkButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 250),
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 0.0,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeOutBack, // spring back
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _height {
    switch (widget.size) {
      case PkButtonSize.large:  return 56;
      case PkButtonSize.medium: return AppConstants.buttonHeightSmall;
      case PkButtonSize.small:  return AppConstants.buttonHeightXs;
    }
  }

  TextStyle get _textStyle {
    switch (widget.size) {
      case PkButtonSize.large:  return AppTextStyles.button;
      case PkButtonSize.medium: return AppTextStyles.buttonSm;
      case PkButtonSize.small:  return AppTextStyles.buttonSm.copyWith(fontSize: 13);
    }
  }

  double get _iconSize {
    switch (widget.size) {
      case PkButtonSize.large:  return 20;
      case PkButtonSize.medium: return 18;
      case PkButtonSize.small:  return 16;
    }
  }

  _BtnStyle get _style {
    final disabled = widget.onPressed == null && !widget.isLoading;
    switch (widget.variant) {
      case PkButtonVariant.primary:
        return _BtnStyle(
          bg: disabled ? AppColors.bg4 : AppColors.primary,
          fg: disabled ? AppColors.textHint : AppColors.white,
          border: disabled ? AppColors.border : null,
          shadows: disabled ? [] : AppShadows.primaryGlow,
          gradient: disabled
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF5B74F8), Color(0xFF8B5CF6)],
                ),
        );
      case PkButtonVariant.secondary:
        return _BtnStyle(
          bg: AppColors.bg3,
          fg: AppColors.textPrimary,
          border: AppColors.border,
          shadows: [],
          gradient: null,
        );
      case PkButtonVariant.ghost:
        return _BtnStyle(
          bg: Colors.transparent,
          fg: AppColors.primary,
          border: AppColors.borderFocus,
          shadows: [],
          gradient: null,
        );
      case PkButtonVariant.danger:
        return _BtnStyle(
          bg: disabled ? AppColors.bg4 : AppColors.danger,
          fg: disabled ? AppColors.textHint : AppColors.white,
          border: null,
          shadows: disabled ? [] : AppShadows.dangerGlow,
          gradient: null,
        );
      case PkButtonVariant.success:
        return _BtnStyle(
          bg: disabled ? AppColors.bg4 : AppColors.success,
          fg: disabled ? AppColors.textHint : AppColors.white,
          border: null,
          shadows: disabled ? [] : AppShadows.successGlow,
          gradient: null,
        );
    }
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onPressed == null && !widget.isLoading) return;
    setState(() => _isPressed = true);
    _ctrl.forward();
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails _) {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
    _ctrl.reverse();
  }

  void _onTapCancel() {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    final isDisabled = widget.onPressed == null && !widget.isLoading;

    Widget content = widget.isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(style.fg),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null && !widget.iconTrailing) ...[
                Icon(widget.icon, size: _iconSize, color: style.fg),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: _textStyle.copyWith(
                  color: style.fg,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              if (widget.icon != null && widget.iconTrailing) ...[
                const SizedBox(width: 8),
                Icon(widget.icon, size: _iconSize, color: style.fg),
              ],
            ],
          );

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (_, child) => Transform.scale(
        scale: _scaleAnim.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: isDisabled ? null : _onTapDown,
        onTapUp: isDisabled ? null : _onTapUp,
        onTapCancel: isDisabled ? null : _onTapCancel,
        onTap: isDisabled ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: _height,
          width: widget.fullWidth ? double.infinity : null,
          padding: widget.fullWidth ? null : const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: style.gradient != null ? null : style.bg,
            gradient: style.gradient,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(
              color: style.border ?? Colors.white.withOpacity(0.06),
              width: 1,
            ),
            boxShadow: [
              ...style.shadows,
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(child: content),
        ),
      ),
    );
  }
}

class _BtnStyle {
  final Color bg;
  final Color fg;
  final Color? border;
  final List<BoxShadow> shadows;
  final Gradient? gradient;
  const _BtnStyle({
    required this.bg, required this.fg, required this.border,
    required this.shadows, required this.gradient,
  });
}
