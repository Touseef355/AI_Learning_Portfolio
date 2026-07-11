import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';
import '../../theme/app_text_styles.dart';
import '../../main.dart';
import '../auth/login_screen.dart';
import '../../api_service.dart';
import '../../utils/error_utils.dart';
import '../../models/user_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  // ── Toggles ────────────────────────────────────────────────
  bool _pushNotifications = true;
  bool _smsAlerts = false;
  bool _emailUpdates = false;
  bool _biometric = false;

  // ── Theme ──────────────────────────────────────────────────
  ThemeMode _themeMode = ParkrooApp.currentMode;

  // ── Animation Controllers ──────────────────────────────────
  late final AnimationController _staggerCtrl;
  late final Animation<double> _headerFade;
  late final Animation<double> _accountFade;
  late final Animation<double> _appearanceFade;
  late final Animation<double> _notificationsFade;
  late final Animation<double> _securityFade;
  late final Animation<double> _supportFade;
  late final Animation<double> _aboutFade;
  late final Animation<double> _dangerFade;

  @override
  void initState() {
    super.initState();

    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _headerFade = CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.0, 0.2, curve: Curves.easeOut),
    );
    _accountFade = CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.1, 0.3, curve: Curves.easeOut),
    );
    _appearanceFade = CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.2, 0.4, curve: Curves.easeOut),
    );
    _notificationsFade = CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.3, 0.5, curve: Curves.easeOut),
    );
    _securityFade = CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.4, 0.6, curve: Curves.easeOut),
    );
    _supportFade = CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.5, 0.7, curve: Curves.easeOut),
    );
    _aboutFade = CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.6, 0.8, curve: Curves.easeOut),
    );
    _dangerFade = CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.7, 0.9, curve: Curves.easeOut),
    );

    _staggerCtrl.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ParkrooApp.currentMode;
    if (_themeMode != current) setState(() => _themeMode = current);
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  void _setTheme(ThemeMode mode) {
    setState(() => _themeMode = mode);
    ParkrooApp.setTheme(mode);
    final isDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));
    HapticFeedback.lightImpact();
  }

  void _showChangePasswordSheet() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _PremiumPasswordSheet(
        currentCtrl: currentCtrl,
        newCtrl: newCtrl,
        confirmCtrl: confirmCtrl,
        isSaving: isSaving,
        onSave: (oldPwd, newPwd, confirmPwd) async {
          try {
            final result = await ApiService.changePassword(
              currentPassword: oldPwd,
              newPassword: newPwd,
              confirmPassword: confirmPwd,
            );
            if (!context.mounted) return;
            if (result['message'] != null) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Password changed successfully'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ErrorUtils.messageFrom(result, fallback: 'Failed to change password')),
                  backgroundColor: AppColors.danger,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            }
          } catch (e, st) {
            ErrorUtils.logError('SettingsScreen.changePassword', e, st);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(ErrorUtils.friendlyMessage(e)),
                backgroundColor: AppColors.danger,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        },
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false, VoidCallback? onRetry}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
          color: Colors.white,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            msg,
            style: const TextStyle(fontSize: 13, color: Colors.white),
          ),
        ),
      ]),
      backgroundColor: isError ? AppColors.danger : AppColors.success,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(AppConstants.sp16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      duration: Duration(seconds: onRetry != null ? 6 : 4),
      action: onRetry == null
          ? null
          : SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: onRetry),
    ));
  }

  Future<void> _confirmDeleteAccount() async {
    HapticFeedback.mediumImpact();
    final passwordCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.of(context).bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusXl)),
        title: Text(
          'Delete Account?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.danger),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete your account, bookings, and data. This cannot be undone.',
              style: TextStyle(fontSize: 13, color: AppColors.of(context).textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Enter your password to confirm',
                hintStyle: TextStyle(color: AppColors.of(context).textHint, fontSize: 13),
                filled: true,
                fillColor: AppColors.of(context).bgBase,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.of(context).border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.of(context).textHint)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final password = passwordCtrl.text.trim();
    passwordCtrl.dispose();

    if (password.isEmpty) {
      _showSnack('Password is required', isError: true);
      return;
    }

    final result = await ApiService.deleteAccount(password);

    if (!mounted) return;

    if (result['message'] != null) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } else {
      _showSnack(
        ErrorUtils.messageFrom(result, fallback: 'Failed to delete account'),
        isError: true,
        onRetry: ErrorUtils.isRetryable(result) ? _confirmDeleteAccount : null,
      );
    }
  }

  Future<void> _confirmSignOut() async {
    HapticFeedback.lightImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.of(context).bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        ),
        title: Text(
          'Sign out?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.of(context).textPrimary,
          ),
        ),
        content: Text(
          'You will be returned to the login screen.',
          style: TextStyle(fontSize: 13, color: AppColors.of(context).textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.of(context).textHint),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sign out',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  UserModel? get _currentUser => ApiService.currentUser;

  @override
  Widget build(BuildContext context) {
final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bgBase,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [
              AppColors.primary.withValues(alpha: 0.04),
              colors.bgBase,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Premium Header ─────────────────────────────────────
              FadeTransition(
                opacity: _headerFade,
                child: _PremiumHeader(colors: colors),
              ),

              // ── Scrollable content ──────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppConstants.sp16,
                    0,
                    AppConstants.sp16,
                    AppConstants.sp32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ══ ACCOUNT CARD ══════════════════════════════════
                      FadeTransition(
                        opacity: _accountFade,
                        child: _PremiumAccountCard(
                          colors: colors,
                          user: _currentUser,
                        ),
                      ),

                      const SizedBox(height: AppConstants.sp20),

                      // ══ APPEARANCE ════════════════════════════════════
                      FadeTransition(
                        opacity: _appearanceFade,
                        child: Column(
                          children: [
                            _GroupLabel('Appearance', colors: colors),
                            const SizedBox(height: AppConstants.sp8),
                            _PremiumSettingsGroup(colors: colors, children: [
                              _PremiumThemeSelector(
                                current: _themeMode,
                                onChanged: _setTheme,
                                colors: colors,
                              ),
                            ]),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppConstants.sp20),

                      // ══ NOTIFICATIONS ═════════════════════════════════
                      FadeTransition(
                        opacity: _notificationsFade,
                        child: Column(
                          children: [
                            _GroupLabel('Notifications', colors: colors),
                            const SizedBox(height: AppConstants.sp8),
                            _PremiumSettingsGroup(colors: colors, children: [
                              _PremiumToggleRow(
                                icon: Icons.notifications_outlined,
                                iconColor: AppColors.primary,
                                title: 'Push notifications',
                                subtitle: 'Booking updates and alerts',
                                value: _pushNotifications,
                                onChanged: (v) {
                                  HapticFeedback.lightImpact();
                                  setState(() => _pushNotifications = v);
                                },
                                colors: colors,
                              ),
                              _Divider(colors: colors),
                              _PremiumToggleRow(
                                icon: Icons.sms_outlined,
                                iconColor: AppColors.success,
                                title: 'SMS alerts',
                                subtitle: 'Receive text messages',
                                value: _smsAlerts,
                                onChanged: (v) {
                                  HapticFeedback.lightImpact();
                                  setState(() => _smsAlerts = v);
                                },
                                colors: colors,
                              ),
                              _Divider(colors: colors),
                              _PremiumToggleRow(
                                icon: Icons.mail_outline_rounded,
                                iconColor: AppColors.gradientEnd,
                                title: 'Email updates',
                                subtitle: 'Receipts and summaries',
                                value: _emailUpdates,
                                onChanged: (v) {
                                  HapticFeedback.lightImpact();
                                  setState(() => _emailUpdates = v);
                                },
                                colors: colors,
                                isLast: true,
                              ),
                            ]),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppConstants.sp20),

                      // ══ SECURITY ══════════════════════════════════════
                      FadeTransition(
                        opacity: _securityFade,
                        child: Column(
                          children: [
                            _GroupLabel('Security', colors: colors),
                            const SizedBox(height: AppConstants.sp8),
                            _PremiumSettingsGroup(colors: colors, children: [
                              _PremiumToggleRow(
                                icon: Icons.fingerprint_rounded,
                                iconColor: AppColors.primary,
                                title: 'Biometric login',
                                subtitle: 'Face ID or fingerprint',
                                value: _biometric,
                                onChanged: (v) {
                                  HapticFeedback.lightImpact();
                                  setState(() => _biometric = v);
                                },
                                colors: colors,
                              ),
                              _Divider(colors: colors),
                              _PremiumArrowRow(
                                icon: Icons.lock_reset_rounded,
                                iconColor: AppColors.warning,
                                title: 'Change password',
                                colors: colors,
                                onTap: _showChangePasswordSheet,
                                isLast: true,
                              ),
                            ]),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppConstants.sp20),

                      // ══ SUPPORT ═══════════════════════════════════════
                      FadeTransition(
                        opacity: _supportFade,
                        child: Column(
                          children: [
                            _GroupLabel('Support', colors: colors),
                            const SizedBox(height: AppConstants.sp8),
                            _PremiumSettingsGroup(colors: colors, children: [
                              _PremiumArrowRow(
                                icon: Icons.help_outline_rounded,
                                iconColor: AppColors.primary,
                                title: 'Help centre',
                                colors: colors,
                                onTap: () {},
                              ),
                              _Divider(colors: colors),
                              _PremiumArrowRow(
                                icon: Icons.chat_bubble_outline_rounded,
                                iconColor: AppColors.success,
                                title: 'Contact support',
                                colors: colors,
                                onTap: () {},
                                isLast: true,
                              ),
                            ]),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppConstants.sp20),

                      // ══ ABOUT ═════════════════════════════════════════
                      FadeTransition(
                        opacity: _aboutFade,
                        child: Column(
                          children: [
                            _GroupLabel('About', colors: colors),
                            const SizedBox(height: AppConstants.sp8),
                            _PremiumSettingsGroup(colors: colors, children: [
                              _PremiumArrowRow(
                                icon: Icons.privacy_tip_outlined,
                                iconColor: AppColors.primary,
                                title: 'Privacy policy',
                                colors: colors,
                                onTap: () {},
                              ),
                              _Divider(colors: colors),
                              _PremiumArrowRow(
                                icon: Icons.description_outlined,
                                iconColor: AppColors.primary,
                                title: 'Terms of service',
                                colors: colors,
                                onTap: () {},
                              ),
                              _Divider(colors: colors),
                              _PremiumArrowRow(
                                icon: Icons.info_outline_rounded,
                                iconColor: AppColors.of(context).textHint,
                                title: 'App version',
                                colors: colors,
                                trailing: Text(
                                  'v1.0.0',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.textHint,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                onTap: null,
                                isLast: true,
                                showChevron: false,
                              ),
                            ]),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppConstants.sp20),

                      // ══ DANGER ZONE ═══════════════════════════════════
                      FadeTransition(
                        opacity: _dangerFade,
                        child: Column(
                          children: [
                            _GroupLabel('Danger zone', colors: colors),
                            const SizedBox(height: AppConstants.sp8),
                            _PremiumDangerGroup(colors: colors, children: [
                              _PremiumArrowRow(
                                icon: Icons.delete_forever_rounded,
                                iconColor: AppColors.danger,
                                title: 'Delete account',
                                titleColor: AppColors.danger,
                                colors: colors,
                                onTap: _confirmDeleteAccount,
                                isLast: false,
                                showChevron: false,
                              ),
                              _PremiumArrowRow(
                                icon: Icons.logout_rounded,
                                iconColor: AppColors.danger,
                                title: 'Sign out securely',
                                titleColor: AppColors.danger,
                                colors: colors,
                                onTap: _confirmSignOut,
                                isLast: true,
                                showChevron: false,
                              ),
                            ]),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppConstants.sp28),

                      // Premium footer
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.local_parking_rounded,
                              size: 24,
                              color: colors.textHint.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Parkroo · Smart Parking',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.textHint.withValues(alpha: 0.5),
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Version 1.0.0',
                              style: TextStyle(
                                fontSize: 10,
                                color: colors.textHint.withValues(alpha: 0.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppConstants.sp16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PREMIUM HEADER
// ═══════════════════════════════════════════════════════════════

class _PremiumHeader extends StatelessWidget {
  final AppColorScheme colors;
  const _PremiumHeader({required this.colors});

  @override
  Widget build(BuildContext context) {
return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            colors.bgCard,
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.bgElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: AppTextStyles.h1.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage your preferences',
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PREMIUM ACCOUNT CARD
// ═══════════════════════════════════════════════════════════════

class _PremiumAccountCard extends StatelessWidget {
  final AppColorScheme colors;
  final UserModel? user;
  const _PremiumAccountCard({required this.colors, this.user});

  @override
  Widget build(BuildContext context) {
return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            colors.bgCard,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.primaryGradient,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: Icon(
                Icons.person_rounded,
                size: 28,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.fullName?.split(' ').first ?? 'Premium User',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? 'user@parkroo.com',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user != null ? 'Verified User' : 'Guest',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Text(
              'View',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  GROUP LABEL
// ═══════════════════════════════════════════════════════════════

class _GroupLabel extends StatelessWidget {
  final String label;
  final AppColorScheme colors;
  const _GroupLabel(this.label, {required this.colors});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: colors.textHint,
            letterSpacing: 1.2,
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════
//  PREMIUM SETTINGS GROUP (Glassmorphic)
// ═══════════════════════════════════════════════════════════════

class _PremiumSettingsGroup extends StatelessWidget {
  final List<Widget> children;
  final AppColorScheme colors;
  const _PremiumSettingsGroup({required this.children, required this.colors});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: colors.bgCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(children: children),
      );
}

class _Divider extends StatelessWidget {
  final AppColorScheme colors;
  const _Divider({required this.colors});

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        thickness: 0.5,
        color: colors.border,
        indent: AppConstants.sp16 + 36 + AppConstants.sp12,
      );
}

// ═══════════════════════════════════════════════════════════════
//  PREMIUM THEME SELECTOR (Card-based)
// ═══════════════════════════════════════════════════════════════

class _PremiumThemeSelector extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;
  final AppColorScheme colors;

  const _PremiumThemeSelector({
    required this.current,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.25),
                        AppColors.primary.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.palette_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Theme',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _ThemeCard(
                icon: Icons.wb_sunny_outlined,
                label: 'Light',
                mode: ThemeMode.light,
                current: current,
                colors: colors,
                onTap: () => onChanged(ThemeMode.light),
              ),
              const SizedBox(width: 12),
              _ThemeCard(
                icon: Icons.dark_mode_outlined,
                label: 'Dark',
                mode: ThemeMode.dark,
                current: current,
                colors: colors,
                onTap: () => onChanged(ThemeMode.dark),
              ),
              const SizedBox(width: 12),
              _ThemeCard(
                icon: Icons.phone_android_rounded,
                label: 'System',
                mode: ThemeMode.system,
                current: current,
                colors: colors,
                onTap: () => onChanged(ThemeMode.system),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeMode mode;
  final ThemeMode current;
  final AppColorScheme colors;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.icon,
    required this.label,
    required this.mode,
    required this.current,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
final isSelected = current == mode;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.12)
                : colors.bgInput.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : colors.border,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 24,
                color: isSelected ? AppColors.primary : colors.textHint,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : colors.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PREMIUM TOGGLE ROW
// ═══════════════════════════════════════════════════════════════

class _PremiumToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final AppColorScheme colors;
  final bool isLast;

  const _PremiumToggleRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    required this.colors,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
return GestureDetector(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.sp16,
          vertical: AppConstants.sp12,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    iconColor.withValues(alpha: 0.25),
                    iconColor.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.12),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: AppConstants.sp12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textHint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.white,
              activeTrackColor: AppColors.primary,
              inactiveThumbColor: colors.textHint,
              inactiveTrackColor: colors.bgInput,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PREMIUM ARROW ROW
// ═══════════════════════════════════════════════════════════════

class _PremiumArrowRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final AppColorScheme colors;
  final bool isLast;
  final bool showChevron;

  const _PremiumArrowRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.titleColor,
    this.trailing,
    required this.onTap,
    required this.colors,
    this.isLast = false,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
return InkWell(
      onTap: () {
        if (onTap != null) {
          HapticFeedback.lightImpact();
          onTap!();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.sp16,
          vertical: AppConstants.sp12,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    iconColor.withValues(alpha: 0.25),
                    iconColor.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.12),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: AppConstants.sp12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: titleColor ?? colors.textPrimary,
                ),
              ),
            ),
            if (trailing != null) trailing!,
            if (showChevron && trailing == null)
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.textHint,
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PREMIUM DANGER GROUP
// ═══════════════════════════════════════════════════════════════

class _PremiumDangerGroup extends StatelessWidget {
  final List<Widget> children;
  final AppColorScheme colors;
  const _PremiumDangerGroup({required this.children, required this.colors});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(children: children),
      );
}

// ═══════════════════════════════════════════════════════════════
//  PREMIUM PASSWORD SHEET
// ═══════════════════════════════════════════════════════════════

class _PremiumPasswordSheet extends StatefulWidget {
  final TextEditingController currentCtrl;
  final TextEditingController newCtrl;
  final TextEditingController confirmCtrl;
  final bool isSaving;
  final Future<void> Function(String, String, String) onSave;

  const _PremiumPasswordSheet({
    required this.currentCtrl,
    required this.newCtrl,
    required this.confirmCtrl,
    required this.isSaving,
    required this.onSave,
  });

  @override
  State<_PremiumPasswordSheet> createState() => _PremiumPasswordSheetState();
}

class _PremiumPasswordSheetState extends State<_PremiumPasswordSheet> {
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    widget.newCtrl.addListener(_rebuild);
  }

  void _rebuild() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    widget.newCtrl.removeListener(_rebuild);
    super.dispose();
  }

  double _getPasswordStrength(String password) {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#\$%^&*]'))) score++;
    return score / 4;
  }

  String _getStrengthLabel(double strength) {
    if (strength <= 0.25) return 'Weak';
    if (strength <= 0.5) return 'Fair';
    if (strength <= 0.75) return 'Good';
    return 'Strong';
  }

  Color _getStrengthColor(double strength) {
    if (strength <= 0.25) return AppColors.danger;
    if (strength <= 0.5) return AppColors.warning;
    if (strength <= 0.75) return AppColors.primary;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
final colors = AppColors.of(context);
    final strength = _getPasswordStrength(widget.newCtrl.text);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        decoration: BoxDecoration(
          color: colors.bgCard.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.primaryGradient,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Change Password',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _PremiumPassField(
                controller: widget.currentCtrl,
                label: 'Current password',
                obscure: _obscureCurrent,
                onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                colors: colors,
              ),
              const SizedBox(height: 14),
              _PremiumPassField(
                controller: widget.newCtrl,
                label: 'New password',
                obscure: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
                colors: colors,
              ),
              if (widget.newCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: strength,
                        backgroundColor: colors.bgInput,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getStrengthColor(strength),
                        ),
                        minHeight: 3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Strength: ',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textHint,
                          ),
                        ),
                        Text(
                          _getStrengthLabel(strength),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _getStrengthColor(strength),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              _PremiumPassField(
                controller: widget.confirmCtrl,
                label: 'Confirm new password',
                obscure: _obscureConfirm,
                onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                colors: colors,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isSaving
                      ? null
                      : () async {
                          HapticFeedback.lightImpact();
                          setState(() => _isSaving = true);
                          await widget.onSave(
                            widget.currentCtrl.text.trim(),
                            widget.newCtrl.text.trim(),
                            widget.confirmCtrl.text.trim(),
                          );
                          setState(() => _isSaving = false);
                        },
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Update Password',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _PremiumPassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final AppColorScheme colors;

  const _PremiumPassField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: colors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.textHint, fontSize: 13),
        prefixIcon: Icon(
          Icons.lock_outline_rounded,
          color: AppColors.of(context).textHint,
          size: 20,
        ),
        suffixIcon: GestureDetector(
          onTap: onToggle,
          child: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: colors.textHint,
            size: 20,
          ),
        ),
        filled: true,
        fillColor: colors.bgInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}