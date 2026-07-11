// Legacy compatibility shim — new code should use PkInput directly
export 'pk_input.dart';

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';
import '../../theme/app_text_styles.dart';

/// Legacy CustomInputField — kept for backward compatibility.
/// New screens should use PkInput.
class CustomInputField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const CustomInputField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
  });

  @override
  State<CustomInputField> createState() => _CustomInputFieldState();
}

class _CustomInputFieldState extends State<CustomInputField> {
  late FocusNode _focus;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    _focus.addListener(() {
      if (mounted) setState(() => _isFocused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
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
          focusNode: _focus,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          validator: widget.validator,
          style: AppTextStyles.bodyLg.copyWith(color: colors.textPrimary),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: AppTextStyles.bodyLg.copyWith(color: colors.textHint),
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, size: 20,
                    color: _isFocused ? AppColors.primary : colors.textHint)
                : null,
            suffixIcon: widget.suffixIcon,
            filled: true,
            fillColor: colors.bgInput,
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}