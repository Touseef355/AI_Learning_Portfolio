import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';
import '../../theme/app_text_styles.dart';

/// Parkroo Premium Input Field
/// Replaces CustomInputField with a consistent, polished component.
class PkInput extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int maxLines;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;

  const PkInput({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<PkInput> createState() => _PkInputState();
}

class _PkInputState extends State<PkInput> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(() {
      if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppTextStyles.labelLg.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          inputFormatters: widget.inputFormatters,
          maxLength: widget.maxLength,
          maxLines: widget.maxLines,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          validator: widget.validator,
          style: AppTextStyles.bodyLg.copyWith(color: colors.textPrimary),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: AppTextStyles.bodyLg.copyWith(color: colors.textHint),
            counterText: '',
            prefixIcon: widget.prefixIcon != null
                ? Icon(
                    widget.prefixIcon,
                    size: 20,
                    color: _isFocused ? AppColors.primary : colors.textHint,
                  )
                : null,
            suffixIcon: widget.suffix,
            filled: true,
            fillColor: widget.enabled ? colors.bgInput : colors.bgCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              borderSide: BorderSide(color: colors.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              borderSide: const BorderSide(color: AppColors.danger, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              borderSide: BorderSide(color: colors.border, width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}