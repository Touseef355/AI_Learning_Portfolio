import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/pk_button.dart';
import '../../widgets/common/pk_input.dart';
import '../../api_service.dart';
import '../../utils/error_utils.dart';
import 'otp_verification_screen.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  late final AnimationController _staggerCtrl;
  late final AnimationController _glowCtrl;
  late final Animation<double> _bgFade;
  late final Animation<double> _topFade;
  late final Animation<double> _formFade;
  late final Animation<Offset> _formSlide;
  late final Animation<double> _glowPulse;

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
  }

  @override
  void dispose() {
    _emailController.dispose();
    _staggerCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  void _setStatusBar(AppColorScheme colors) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: colors.statusBarLight
          ? Brightness.dark
          : Brightness.light,
    ));
  }

  Future<void> _sendResetCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.requestPasswordReset(
          _emailController.text.trim());
      if (!mounted) return;
      if (result.containsKey('message') ||
          result['status'] == 'success' ||
          result['detail'] != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OTPVerificationScreen(
              phoneNumber: _emailController.text.trim(),
              isPasswordReset: true,
              email: _emailController.text.trim(),
            ),
          ),
        );
      } else {
        _showError(
          ErrorUtils.messageFrom(result, fallback: 'Failed to send reset code. Please try again.'),
          onRetry: ErrorUtils.isRetryable(result) ? _sendResetCode : null,
        );
      }
    } catch (e, st) {
      ErrorUtils.logError('ForgotPasswordScreen._sendResetCode', e, st);
      if (mounted) _showError(ErrorUtils.friendlyMessage(e), onRetry: _sendResetCode);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message, {VoidCallback? onRetry}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTextStyles.bodySm.copyWith(color: AppColors.white),
        ),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppConstants.sp16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        duration: Duration(seconds: onRetry != null ? 6 : 4),
        action: onRetry == null
            ? null
            : SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: onRetry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final size = MediaQuery.of(context).size;

    _setStatusBar(colors);

    return Scaffold(
      backgroundColor: colors.authScaffold,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Premium background with blurred orbs
          FadeTransition(
            opacity: _bgFade,
            child: _ForgotPasswordBackground(
              size: size,
              colors: colors,
              glowPulse: _glowPulse,
            ),
          ),

          // Main content
          SafeArea(
            child: LayoutBuilder(
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
                                // Top area with small logo
                                FadeTransition(
                                  opacity: _topFade,
                                  child: const _ForgotPasswordTopArea(),
                                ),

                                const SizedBox(height: 40),

                                // Form fields
                                SlideTransition(
                                  position: _formSlide,
                                  child: FadeTransition(
                                    opacity: _formFade,
                                    child: Column(
                                      children: [
                                        // Email input
                                        PkInput(
                                          controller: _emailController,
                                          label: 'Email address',
                                          hint: 'you@example.com',
                                          prefixIcon: Icons.alternate_email_rounded,
                                          keyboardType: TextInputType.emailAddress,
                                          textInputAction: TextInputAction.done,
                                          validator: (v) {
                                            if (v == null || v.trim().isEmpty)
                                              return 'Please enter your email';
                                            if (!v.contains('@') || !v.contains('.'))
                                              return 'Enter a valid email address';
                                            return null;
                                          },
                                          onSubmitted: (_) => _sendResetCode(),
                                        ),

                                        const SizedBox(height: AppConstants.sp32),

                                        // Send Reset Code button
                                        PkButton(
                                          label: 'Send Reset Code',
                                          icon: Icons.send_rounded,
                                          iconTrailing: true,
                                          isLoading: _isLoading,
                                          onPressed: _sendResetCode,
                                        ),

                                        const SizedBox(height: AppConstants.sp32),

                                        // Back to login link
                                        Center(
                                          child: GestureDetector(
                                            onTap: () => Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => const LoginScreen(),
                                              ),
                                            ),
                                            child: RichText(
                                              text: TextSpan(
                                                text: "Remember your password?  ",
                                                style: AppTextStyles.bodySm.copyWith(
                                                  color: colors.authSubtitle,
                                                ),
                                                children: [
                                                  TextSpan(
                                                    text: 'Sign in',
                                                    style: AppTextStyles.labelMd.copyWith(
                                                      color: AppColors.primary,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
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
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Premium Background — Blurred Glass Orbs (Reduced Glow)
// ═══════════════════════════════════════════════════════════════

class _ForgotPasswordBackground extends StatelessWidget {
  final Size size;
  final AppColorScheme colors;
  final Animation<double> glowPulse;

  const _ForgotPasswordBackground({
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

          // Blurred glass orb top-right
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

          // Blurred glass orb bottom-left
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

          // Subtle top glow — Reduced (0.03 instead of 0.05)
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

// ═══════════════════════════════════════════════════════════════
// Premium Top Area — Small Logo (Reduced Glow)
// ═══════════════════════════════════════════════════════════════

class _ForgotPasswordTopArea extends StatelessWidget {
  const _ForgotPasswordTopArea();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Small premium logo — Reduced glow
        Container(
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
              Icons.local_parking_rounded,
              size: 45,
              color: AppColors.primary,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Heading
        Center(
          child: Text(
            'Forgot Password?',
            textAlign: TextAlign.center,
            style: AppTextStyles.h1.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Subtitle
        Center(
          child: Text(
            'Enter your registered email to receive a reset code',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.of(context).authSubtitle,
              height: 1.5,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}