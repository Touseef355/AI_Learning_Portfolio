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

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreeToTerms = false;
  bool _isLoading = false;

  late final AnimationController _staggerCtrl;
  late final AnimationController _glowCtrl;
   late final AnimationController _fieldsCtrl;

  late final Animation<double> _bgFade;
  late final Animation<double> _topFade;
  late final Animation<double> _formFade;
  late final Animation<Offset> _formSlide;
  late final Animation<double> _glowPulse;

  
  // Individual form field stagger animations (6 fields + button)
  final List<Animation<double>> _fieldFades = [];
  final List<Animation<Offset>> _fieldSlides = [];

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

    // Ambient glow
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _glowPulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );



    // Form fields stagger controller — starts after form sheet appears
    _fieldsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    // 6 fields staggered: name, email, phone, password, confirm, terms+button
    for (int i = 0; i < 6; i++) {
      final start = i * 0.12;
      final end = (start + 0.45).clamp(0.0, 1.0);
      _fieldFades.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _fieldsCtrl,
            curve: Interval(start, end, curve: Curves.easeOut),
          ),
        ),
      );
      _fieldSlides.add(
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _fieldsCtrl,
            curve: Interval(start, end, curve: Curves.easeOutCubic),
          ),
        ),
      );
    }

    _staggerCtrl.forward().then((_) {
      if (mounted) _fieldsCtrl.forward();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _staggerCtrl.dispose();
    _glowCtrl.dispose();
    _fieldsCtrl.dispose();
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

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      _showError('Please agree to the Terms of Service and Privacy Policy.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.sendOtp(_phoneController.text.trim());
      if (!mounted) return;
      if (!result.containsKey('error')) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OTPVerificationScreen(
              phoneNumber: _phoneController.text.trim(),
              pendingSignupData: {
                'fullName': _nameController.text.trim(),
                'email': _emailController.text.trim(),
                'phone': _phoneController.text.trim(),
                'password': _passwordController.text,
                'confirmPassword': _confirmPasswordController.text,
              },
            ),
          ),
        );
      } else {
        _showError(
          ErrorUtils.messageFrom(result, fallback: 'Failed to send OTP. Please try again.'),
          onRetry: ErrorUtils.isRetryable(result) ? _handleSignup : null,
        );
      }
    } catch (e, st) {
      ErrorUtils.logError('SignupScreen._handleSignup', e, st);
      if (mounted) _showError(ErrorUtils.friendlyMessage(e), onRetry: _handleSignup);
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
          // Premium background
          FadeTransition(
            opacity: _bgFade,
            child: _PremiumSignupBackground(
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
                    child: Column(
                      children: [
                        // Top area
                        FadeTransition(
                          opacity: _topFade,
                          child: _PremiumTopArea(),
                        ),

                        // Form sheet with staggered fields
                        SlideTransition(
                          position: _formSlide,
                          child: FadeTransition(
                            opacity: _formFade,
                            child: _PremiumSignupFormSheet(
                              colors: colors,
                              formKey: _formKey,
                              nameController: _nameController,
                              emailController: _emailController,
                              phoneController: _phoneController,
                              passwordController: _passwordController,
                              confirmPasswordController: _confirmPasswordController,
                              isPasswordVisible: _isPasswordVisible,
                              isConfirmPasswordVisible: _isConfirmPasswordVisible,
                              agreeToTerms: _agreeToTerms,
                              isLoading: _isLoading,
                              fieldFades: _fieldFades,
                              fieldSlides: _fieldSlides,
                              onTogglePassword: () =>
                                  setState(() => _isPasswordVisible = !_isPasswordVisible),
                              onToggleConfirmPassword: () => setState(
                                  () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                              onToggleTerms: () =>
                                  setState(() => _agreeToTerms = !_agreeToTerms),
                              onSignup: _handleSignup,
                              onLogin: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                              ),
                            ),
                          ),
                        ),
                      ],
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
// Premium Background
// ═══════════════════════════════════════════════════════════════

class _PremiumSignupBackground extends StatelessWidget {
  final Size size;
  final AppColorScheme colors;
  final Animation<double> glowPulse;

  const _PremiumSignupBackground({
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
                    color: AppColors.primary.withValues(alpha: 0.1),
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
                    color: AppColors.gradientEnd.withValues(alpha: 0.08),
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
                        alpha: 0.05 + glowPulse.value * 0.02,
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
// Premium Top Area — Logo
// ═══════════════════════════════════════════════════════════════

class _PremiumTopArea extends StatelessWidget {
  const _PremiumTopArea();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 22,
        left: 24,
        right: 24,
        bottom: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo — no rings
          SizedBox(
            width: 130,
            height: 130,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 38,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/branding/splash_logo.png',
                width: 130,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.local_parking_rounded,
                  size: 65,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Join Parkroo',
            textAlign: TextAlign.center,
            style: AppTextStyles.h1.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Reserve your spot in seconds 🚗',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.of(context).authSubtitle,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Premium Signup Form Sheet — with staggered field animations
// ═══════════════════════════════════════════════════════════════

class _PremiumSignupFormSheet extends StatelessWidget {
  final AppColorScheme colors;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool isPasswordVisible;
  final bool isConfirmPasswordVisible;
  final bool agreeToTerms;
  final bool isLoading;
  final List<Animation<double>> fieldFades;
  final List<Animation<Offset>> fieldSlides;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmPassword;
  final VoidCallback onToggleTerms;
  final VoidCallback onSignup;
  final VoidCallback onLogin;

  const _PremiumSignupFormSheet({
    required this.colors,
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.isPasswordVisible,
    required this.isConfirmPasswordVisible,
    required this.agreeToTerms,
    required this.isLoading,
    required this.fieldFades,
    required this.fieldSlides,
    required this.onTogglePassword,
    required this.onToggleConfirmPassword,
    required this.onToggleTerms,
    required this.onSignup,
    required this.onLogin,
  });

  Widget _field(int index, Widget child) {
    return FadeTransition(
      opacity: fieldFades[index],
      child: SlideTransition(
        position: fieldSlides[index],
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: colors.authFormBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
            border: Border.all(color: colors.authFormBorder, width: 1),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppConstants.sp24,
              AppConstants.sp24,
              AppConstants.sp24,
              MediaQuery.of(context).viewInsets.bottom + AppConstants.sp28,
            ),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.authHandle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Field 0 — Full name
                  _field(0, PkInput(
                    controller: nameController,
                    label: 'Full name',
                    hint: 'John Doe',
                    prefixIcon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Please enter your full name';
                      if (v.trim().length < 3)
                        return 'Name must be at least 3 characters';
                      return null;
                    },
                  )),
                  const SizedBox(height: 18),

                  // Field 1 — Email
                  _field(1, PkInput(
                    controller: emailController,
                    label: 'Email address',
                    hint: 'you@example.com',
                    prefixIcon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Please enter your email';
                      if (!v.contains('@') || !v.contains('.'))
                        return 'Enter a valid email address';
                      return null;
                    },
                  )),
                  const SizedBox(height: 18),

                  // Field 2 — Phone
                  _field(2, PkInput(
                    controller: phoneController,
                    label: 'Phone number',
                    hint: '+92 300 0000000',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Please enter your phone number';
                      if (v.trim().length < 10)
                        return 'Enter a valid phone number';
                      return null;
                    },
                  )),
                  const SizedBox(height: 18),

                  // Field 3 — Password
                  _field(3, PkInput(
                    controller: passwordController,
                    label: 'Password',
                    hint: 'Min. 8 characters',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: !isPasswordVisible,
                    textInputAction: TextInputAction.next,
                    suffix: IconButton(
                      icon: Icon(
                        isPasswordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: colors.textHint,
                      ),
                      onPressed: onTogglePassword,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty)
                        return 'Please enter a password';
                      if (v.length < 8)
                        return 'Password must be at least 8 characters';
                      return null;
                    },
                  )),
                  const SizedBox(height: 18),

                  // Field 4 — Confirm password
                  _field(4, PkInput(
                    controller: confirmPasswordController,
                    label: 'Confirm password',
                    hint: 'Re-enter your password',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: !isConfirmPasswordVisible,
                    textInputAction: TextInputAction.done,
                    suffix: IconButton(
                      icon: Icon(
                        isConfirmPasswordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: colors.textHint,
                      ),
                      onPressed: onToggleConfirmPassword,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty)
                        return 'Please confirm your password';
                      if (v != passwordController.text)
                        return 'Passwords do not match';
                      return null;
                    },
                    onSubmitted: (_) => onSignup(),
                  )),
                  const SizedBox(height: 24),

                  // Field 5 — Terms + button
                  _field(5, Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: onToggleTerms,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedContainer(
                              duration: AppConstants.durationFast,
                              width: 20,
                              height: 20,
                              margin: const EdgeInsets.only(top: 1),
                              decoration: BoxDecoration(
                                color: agreeToTerms
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius:
                                    BorderRadius.circular(AppConstants.radiusXs),
                                border: Border.all(
                                  color: agreeToTerms
                                      ? AppColors.primary
                                      : colors.border,
                                  width: 1.5,
                                ),
                              ),
                              child: agreeToTerms
                                  ? const Icon(Icons.check_rounded,
                                      size: 13, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: AppConstants.sp12),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  text: 'I agree to the ',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: colors.authSubtitle,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Terms of Service',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const TextSpan(text: ' and '),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      PkButton(
                        label: 'Create Account  →',
                        isLoading: isLoading,
                        onPressed: onSignup,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account?',
                            style: AppTextStyles.bodySm.copyWith(
                              color: colors.authSubtitle,
                            ),
                          ),
                          const SizedBox(width: AppConstants.sp8),
                          GestureDetector(
                            onTap: onLogin,
                            child: Text(
                              'Sign in',
                              style: AppTextStyles.labelMd.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.sp8),
                    ],
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}