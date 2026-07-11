import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api_service.dart';
import '../../utils/error_utils.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/pk_button.dart';
import '../../widgets/common/pk_input.dart';
import 'login_screen.dart';

class NewPasswordScreen extends StatefulWidget {
  final String email;
  const NewPasswordScreen({super.key, required this.email});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _success = false;

  late final AnimationController _staggerCtrl;
  late final AnimationController _glowCtrl;
  late final Animation<double> _bgFade;
  late final Animation<double> _topFade;
  late final Animation<double> _formFade;
  late final Animation<Offset> _formSlide;
  late final Animation<double> _glowPulse;

  int _strengthScore = 0;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _staggerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));

    _bgFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _topFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerCtrl,
        curve: const Interval(0.1, 0.6, curve: Curves.easeOut),
      ),
    );

    _formFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerCtrl,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _staggerCtrl,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _glowPulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _staggerCtrl.forward();

    _passwordController.addListener(() {
      _updateStrength();
      setState(() {});
    });

    _confirmController.addListener(() {
      setState(() {});
    });
  }

  void _updateStrength() {
    final p = _passwordController.text;
    int score = 0;
    if (p.length >= 8) score++;
    if (p.contains(RegExp(r'[A-Z]'))) score++;
    if (p.contains(RegExp(r'[0-9]'))) score++;
    if (p.contains(RegExp(r'[!@#\$%^&*]'))) score++;
    setState(() => _strengthScore = score);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _staggerCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  bool get _isFormValid =>
      _passwordController.text.length >= 8 &&
      _confirmController.text.isNotEmpty &&
      _passwordController.text == _confirmController.text;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.confirmPasswordReset(
        email: widget.email,
        newPassword: _passwordController.text,
        confirmPassword: _confirmController.text,
      );
      if (!mounted) return;
      if (result['status'] == 'success' || result.containsKey('message')) {
        setState(() => _success = true);
        await Future.delayed(const Duration(milliseconds: 2200));
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (r) => false,
        );
      } else {
        _showError(
          ErrorUtils.messageFrom(result, fallback: 'Failed to reset password. Please try again.'),
          onRetry: ErrorUtils.isRetryable(result) ? _submit : null,
        );
      }
    } catch (e, st) {
      ErrorUtils.logError('NewPasswordScreen._submit', e, st);
      if (mounted) _showError(ErrorUtils.friendlyMessage(e), onRetry: _submit);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message, {VoidCallback? onRetry}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: AppTextStyles.bodySm.copyWith(color: AppColors.white)),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppConstants.sp16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
        duration: Duration(seconds: onRetry != null ? 6 : 4),
        action: onRetry == null
            ? null
            : SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: onRetry),
      ),
    );
  }

  Color get _strengthColor {
    if (_strengthScore <= 1) return AppColors.danger;
    if (_strengthScore == 2) return AppColors.warning;
    return AppColors.success;
  }

  String get _strengthLabel {
    if (_strengthScore <= 1) return 'Weak';
    if (_strengthScore == 2) return 'Fair';
    if (_strengthScore == 3) return 'Good';
    return 'Strong';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: colors.authScaffold,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          FadeTransition(
            opacity: _bgFade,
            child: _NewPasswordBackground(
              size: size,
              colors: colors,
              glowPulse: _glowPulse,
            ),
          ),
          SafeArea(
            child: _success ? _buildSuccessState() : _buildForm(colors),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(AppColorScheme colors) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppConstants.sp24,
                    AppConstants.sp16,
                    AppConstants.sp24,
                    MediaQuery.of(context).viewInsets.bottom + AppConstants.sp32,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Logo
                        FadeTransition(
                          opacity: _topFade,
                          child: Container(
                            width: 100,
                            height: 100,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.04),
                                  blurRadius: 20,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/branding/splash_logo.png',
                              width: 85,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.lock_reset_rounded,
                                size: 55,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Heading
                        FadeTransition(
                          opacity: _topFade,
                          child: Column(
                            children: [
                              Text(
                                'Create New Password',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.h1.copyWith(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.8,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Your new password must be strong and secure to protect your account.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodyMd.copyWith(
                                  height: 1.6,
                                  color: AppColors.of(context).authSubtitle,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Form Fields
                        SlideTransition(
                          position: _formSlide,
                          child: FadeTransition(
                            opacity: _formFade,
                            child: Column(
                              children: [
                                // New Password
                                PkInput(
                                  controller: _passwordController,
                                  label: 'New password',
                                  hint: 'Min. 8 characters',
                                  prefixIcon: Icons.lock_outline_rounded,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.next,
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 20,
                                      color: AppColors.of(context).textHint,
                                    ),
                                    onPressed: () => setState(
                                        () => _obscurePassword = !_obscurePassword),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Please enter a password';
                                    }
                                    if (v.length < 8) {
                                      return 'Minimum 8 characters required';
                                    }
                                    if (!RegExp(r'[A-Z]').hasMatch(v)) {
                                      return 'Add at least 1 uppercase letter';
                                    }
                                    if (!RegExp(r'[0-9]').hasMatch(v)) {
                                      return 'Add at least 1 number';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 16),

                                // Confirm Password
                                PkInput(
                                  controller: _confirmController,
                                  label: 'Confirm password',
                                  hint: 'Re-enter your password',
                                  prefixIcon: Icons.lock_outline_rounded,
                                  obscureText: _obscureConfirm,
                                  textInputAction: TextInputAction.done,
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 20,
                                      color: AppColors.of(context).textHint,
                                    ),
                                    onPressed: () => setState(
                                        () => _obscureConfirm = !_obscureConfirm),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty)
                                      return 'Please confirm your password';
                                    if (v != _passwordController.text)
                                      return 'Passwords do not match';
                                    return null;
                                  },
                                  onSubmitted: (_) => _submit(),
                                ),

                                // ✅ Strength Meter moved here (below Confirm Password)
                                if (_passwordController.text.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  _buildStrengthMeter(colors),
                                ],

                                const SizedBox(height: 32),

                                // Reset Password Button
                                PkButton(
                                  label: 'Reset Password',
                                  isLoading: _isLoading,
                                  onPressed: _isFormValid ? _submit : null,
                                ),

                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStrengthMeter(AppColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            final filled = i < _strengthScore;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  color: filled
                      ? _strengthColor
                      : colors.border,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              'Password Strength: ',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.of(context).textHint,
              ),
            ),
            Text(
              _strengthLabel,
              style: AppTextStyles.caption.copyWith(
                color: _strengthColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.sp32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.18),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                ],
                gradient: RadialGradient(
                  colors: [
                    AppColors.success.withValues(alpha: 0.22),
                    AppColors.success.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 56,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: AppConstants.sp24),
            Text(
              'Password Updated!',
              textAlign: TextAlign.center,
              style: AppTextStyles.h1.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 26,
              ),
            ),
            const SizedBox(height: AppConstants.sp10),
            Text(
              'Your password has been changed successfully.\nRedirecting to login...',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.of(context).authSubtitle,
                height: 1.6,
              ),
            ),
            const SizedBox(height: AppConstants.sp32),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Premium Background — Blurred Glass Orbs
// ═══════════════════════════════════════════════════════════════

class _NewPasswordBackground extends StatelessWidget {
  final Size size;
  final AppColorScheme colors;
  final Animation<double> glowPulse;

  const _NewPasswordBackground({
    required this.size,
    required this.colors,
    required this.glowPulse,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: colors.bgDeep),

          Positioned(
            top: -120,
            right: -100,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(200),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            bottom: -140,
            left: -80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(200),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gradientEnd.withValues(alpha: 0.03),
                  ),
                ),
              ),
            ),
          ),

          AnimatedBuilder(
            animation: glowPulse,
            builder: (_, __) => Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: size.height * 0.35,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.2,
                    colors: [
                      colors.authGlowColor.withValues(
                        alpha: 0.03 + glowPulse.value * 0.015,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}