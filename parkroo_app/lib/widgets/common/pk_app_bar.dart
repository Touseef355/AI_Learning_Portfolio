import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Parkroo Premium App Bar
/// Consistent, minimal, professional navigation header.
class PkAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;
  final Color? backgroundColor;
  final bool transparent;
  final Widget? leading;

  const PkAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.showBack = true,
    this.onBack,
    this.backgroundColor,
    this.transparent = false,
    this.leading,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return AppBar(
      backgroundColor: transparent
          ? Colors.transparent
          : (backgroundColor ?? AppColors.bg1),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: leading ??
          (showBack
              ? InkWell(
                  onTap: onBack ?? () => Navigator.maybePop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.bg3,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                )
              : null),
      title: titleWidget ??
          (title != null
              ? Text(title!, style: AppTextStyles.titleLg)
              : null),
      actions: actions != null
          ? [
              ...actions!,
              const SizedBox(width: 8),
            ]
          : null,
    );
  }
}

/// Compact icon action button for app bar
class PkAppBarAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int? badgeCount;

  const PkAppBarAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: AppColors.bg3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Stack(
          children: [
            Center(child: Icon(icon, size: 18, color: AppColors.textPrimary)),
            if (badgeCount != null && badgeCount! > 0)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
