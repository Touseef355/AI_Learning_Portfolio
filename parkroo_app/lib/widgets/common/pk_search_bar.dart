import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';
import '../../theme/app_text_styles.dart';

/// Parkroo Premium Search Bar
/// Consistent search experience across the app.
class PkSearchBar extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onFilterTap;
  final VoidCallback? onSubmitted;
  final TextEditingController? controller;
  final bool autofocus;

  const PkSearchBar({
    super.key,
    required this.hint,
    required this.onChanged,
    this.onFilterTap,
    this.onSubmitted,
    this.controller,
    this.autofocus = false,
  });

  @override
  State<PkSearchBar> createState() => _PkSearchBarState();
}

class _PkSearchBarState extends State<PkSearchBar> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(
          color: _isFocused
              ? AppColors.primary.withOpacity(0.5)
              : AppColors.border,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: AppConstants.sp16),
          Icon(
            Icons.search_rounded,
            size: 20,
            color: _isFocused ? AppColors.primary : AppColors.textHint,
          ),
          const SizedBox(width: AppConstants.sp12),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: AppTextStyles.bodyMd,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.textHint,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: widget.onChanged,
              onSubmitted: (_) => widget.onSubmitted?.call(),
            ),
          ),
          if (_controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _controller.clear();
                widget.onChanged('');
              },
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.textHint,
              ),
            ),
          if (widget.onFilterTap != null) ...[
            const SizedBox(width: AppConstants.sp8),
            Container(
              width: 1,
              height: 24,
              color: AppColors.border,
            ),
            GestureDetector(
              onTap: widget.onFilterTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.sp12,
                ),
                child: Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ] else
            const SizedBox(width: AppConstants.sp16),
        ],
      ),
    );
  }
}