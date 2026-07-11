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
import '../../services/payment/payment_service.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';
import '../home/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPassword  = false;
  bool _rememberMe    = false;
  bool _isLoading     = false;

  // Staggered entrance
  late final AnimationController _staggerCtrl;
  late final Animation<double>   _bgFade;
  late final Animation<double>   _logoFade;
  late final Animation<Offset>   _logoSlide;
  late final Animation<double>   _formFade;
  late final Animation<Offset>   _formSlide;

  // Ambient glow pulse
  late final AnimationController _glowCtrl;
  late final Animation<double>   _glowPulse;

  @override
  void initState() {
    super.initState();

    _staggerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));

    _bgFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _staggerCtrl,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _staggerCtrl,
            curve: const Interval(0.2, 0.65, curve: Curves.easeOut)));

    _logoSlide = Tween<Offset>(
            begin: const Offset(0, -0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _staggerCtrl,
            curve: const Interval(0.2, 0.65, curve: Curves.easeOutCubic)));

    _formFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _staggerCtrl,
            curve: const Interval(0.45, 1.0, curve: Curves.easeOut)));

    _formSlide = Tween<Offset>(
            begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _staggerCtrl,
            curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic)));

    // Ambient background glow
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat(reverse: true);
    _glowPulse = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _staggerCtrl.forward();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final data = await ApiService.getRememberMeData();
    if (mounted &&
        data['remember'] == true &&
        (data['email'] as String).isNotEmpty) {
      setState(() {
        _emailCtrl.text = data['email'];
        _rememberMe     = true;
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
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

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.login(
        email:      _emailCtrl.text.trim(),
        password:   _passwordCtrl.text,
        rememberMe: _rememberMe,
      );
      if (!mounted) return;
      if (result.containsKey('tokens') || result.containsKey('access')) {
        // Fetch remote config (payment gateway etc.) before navigating
        await initPaymentGateway();
        if (!mounted) return;
        Navigator.pushReplacement(context,
            PageRouteBuilder(
              pageBuilder:         (_, __, ___) => const DashboardScreen(),
              transitionDuration:  const Duration(milliseconds: 400),
              transitionsBuilder:  (_, anim, __, child) => FadeTransition(
                  opacity: CurvedAnimation(
                      parent: anim, curve: Curves.easeOut),
                  child: child),
            ));
      } else {
        _showSnack(
          ErrorUtils.messageFrom(result, fallback: 'Invalid credentials. Please try again.'),
          onRetry: ErrorUtils.isRetryable(result) ? _handleLogin : null,
        );
      }
    } catch (e, st) {
      ErrorUtils.logError('LoginScreen._handleLogin', e, st);
      if (mounted) {
        _showSnack(ErrorUtils.friendlyMessage(e), onRetry: _handleLogin);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {VoidCallback? onRetry}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg,
            style: AppTextStyles.bodySm.copyWith(color: AppColors.white))),
      ]),
      backgroundColor: AppColors.danger,
      behavior:        SnackBarBehavior.floating,
      margin:          const EdgeInsets.all(AppConstants.sp16),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
      duration: Duration(seconds: onRetry != null ? 6 : 4),
      action: onRetry == null
          ? null
          : SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: onRetry),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final size    = MediaQuery.of(context).size;

    _setStatusBar(colors);

    return Scaffold(
      backgroundColor: colors.authScaffold,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Cinematic background
          FadeTransition(
            opacity: _bgFade,
            child: _Background(
              size:       size,
              colors:     colors,
              glowPulse:  _glowPulse,
            ),
          ),

          // ── Scrollable content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minHeight: size.height -
                        MediaQuery.of(context).padding.top),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // Logo area
                      SlideTransition(
                        position: _logoSlide,
                        child: FadeTransition(
                          opacity: _logoFade,
                          child: _LogoArea(
                            size: size,
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Form sheet
                      SlideTransition(
                        position: _formSlide,
                        child: FadeTransition(
                          opacity: _formFade,
                          child: _FormSheet(
                            colors:           colors,
                            formKey:          _formKey,
                            emailCtrl:        _emailCtrl,
                            passwordCtrl:     _passwordCtrl,
                            showPassword:     _showPassword,
                            rememberMe:       _rememberMe,
                            isLoading:        _isLoading,
                            onTogglePass:     () => setState(
                                () => _showPassword = !_showPassword),
                            onToggleRemember: () => setState(
                                () => _rememberMe = !_rememberMe),
                            onLogin:  _handleLogin,
                            onForgot: () => Navigator.push(context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgotPasswordScreen())),
                            onSignup: () => Navigator.push(context,
                                PageRouteBuilder(
                                  pageBuilder: (_, __, ___) =>
                                      const SignupScreen(),
                                  transitionDuration:
                                      const Duration(milliseconds: 350),
                                  transitionsBuilder:
                                      (_, anim, __, child) =>
                                          SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(1.0, 0),
                                      end:   Offset.zero,
                                    ).animate(CurvedAnimation(
                                        parent: anim,
                                        curve:  Curves.easeOutCubic)),
                                    child: child,
                                  ),
                                )),
                          ),
                        ),
                      ),
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
//  BACKGROUND
// ═══════════════════════════════════════════════════════════════

class _Background extends StatelessWidget {
  final Size size;
  final AppColorScheme colors;
  final Animation<double> glowPulse;

  const _Background({
    required this.size,
    required this.colors,
    required this.glowPulse,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imgPath = isDark
        ? 'assets/images/auth/login_bg_dark.png'
        : 'assets/images/auth/login_bg_light.png';

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Positioned(
            top: 0, left: 0, right: 0,
            height: size.height * 0.58,
            child: Image.asset(
              imgPath,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: colors.bgDeep,
              ),
            ),
          ),

          // Top fade
          Positioned(
            top: 0, left: 0, right: 0,
            height: size.height * 0.22,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end:   Alignment.bottomCenter,
                  colors: [
                    colors.authScaffold.withOpacity(0.85),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Bottom cinematic fade
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: size.height * 0.66,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end:   Alignment.topCenter,
                  colors: [
                    colors.authScaffold,
                    colors.authScaffold,
                    colors.authScaffold.withOpacity(0.92),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 0.72, 1.0],
                ),
              ),
            ),
          ),

          // Ambient glow (subtle)
          AnimatedBuilder(
            animation: glowPulse,
            builder: (_, __) => Positioned(
              top: 0, left: 0, right: 0,
              height: size.height * 0.45,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topRight,
                    radius: 1.1,
                    colors: [
                      colors.authGlowColor.withOpacity(
                          isDark
                              ? 0.10 + glowPulse.value * 0.05
                              : 0.06 + glowPulse.value * 0.04),
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
//  LOGO AREA
// ═══════════════════════════════════════════════════════════════

class _LogoArea extends StatelessWidget {
  final Size size;

  const _LogoArea({
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size.height * 0.32,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 160,
              height: 160,
              child: Image.asset(
                'assets/images/branding/splash_logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: AppColors.primaryGradient),
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusXl),
                  ),
                  child: const Icon(Icons.local_parking_rounded,
                      size: 44, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  FORM SHEET
// ═══════════════════════════════════════════════════════════════

class _FormSheet extends StatelessWidget {
  final AppColorScheme colors;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl, passwordCtrl;
  final bool showPassword, rememberMe, isLoading;
  final VoidCallback onTogglePass, onToggleRemember, onLogin, onForgot,
      onSignup;

  const _FormSheet({
    required this.colors,
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.showPassword,
    required this.rememberMe,
    required this.isLoading,
    required this.onTogglePass,
    required this.onToggleRemember,
    required this.onLogin,
    required this.onForgot,
    required this.onSignup,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXl)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color:        colors.authFormBg,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppConstants.radiusXl)),
            border: Border.all(color: colors.authFormBorder, width: 1),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppConstants.sp24,
              AppConstants.sp28,
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
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color:        colors.authHandle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.sp24),

                  // Title — updated with emoji
                  Text(
                    'Welcome back 👋',
                    style: AppTextStyles.display2.copyWith(
                      fontSize:     28,
                      fontWeight:   FontWeight.w800,
                      color:        colors.textPrimary,
                      letterSpacing: -1.0,
                      height:       1.1,
                    ),
                  ),
                  const SizedBox(height: AppConstants.sp6),
                  Text(
                    'Find parking in seconds.',
                    style: AppTextStyles.bodyMd.copyWith(
                        color: colors.authSubtitle),
                  ),

                  const SizedBox(height: AppConstants.sp28),

                  // Email
                  PkInput(
                    controller:      emailCtrl,
                    label:           'Email address',
                    hint:            'you@example.com',
                    prefixIcon:      Icons.alternate_email_rounded,
                    keyboardType:    TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Please enter your email';
                      if (!v.contains('@') || !v.contains('.'))
                        return 'Enter a valid email address';
                      return null;
                    },
                  ),

                  const SizedBox(height: AppConstants.sp16),

                  // Password
                  PkInput(
                    controller:      passwordCtrl,
                    label:           'Password',
                    hint:            '••••••••',
                    prefixIcon:      Icons.lock_outline_rounded,
                    obscureText:     !showPassword,
                    textInputAction: TextInputAction.done,
                    suffix: IconButton(
                      icon: Icon(
                        showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20, color: colors.textHint,
                      ),
                      onPressed: onTogglePass,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty)
                        return 'Please enter your password';
                      if (v.length < 6)
                        return 'Password must be at least 6 characters';
                      return null;
                    },
                    onSubmitted: (_) => onLogin(),
                  ),

                  const SizedBox(height: AppConstants.sp16),

                  // Remember me + Forgot password
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: onToggleRemember,
                        child: Row(children: [
                          AnimatedContainer(
                            duration: AppConstants.durationFast,
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              color: rememberMe
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                  AppConstants.radiusXs),
                              border: Border.all(
                                color: rememberMe
                                    ? AppColors.primary
                                    : colors.border,
                                width: 1.5,
                              ),
                            ),
                            child: rememberMe
                                ? const Icon(Icons.check_rounded,
                                    size: 13, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: AppConstants.sp8),
                          Text('Remember me',
                              style: AppTextStyles.bodySm.copyWith(
                                  color: colors.authSubtitle)),
                        ]),
                      ),
                      GestureDetector(
                        onTap: onForgot,
                        child: Text('Forgot password?',
                            style: AppTextStyles.labelMd
                                .copyWith(color: AppColors.primary)),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppConstants.sp24),

                  // Sign in button
                  PkButton(
                    label:     'Sign In',
                    isLoading: isLoading,
                    onPressed: onLogin,
                  ),

                  const SizedBox(height: AppConstants.sp24),

                  // Sign up link
                  Center(
                    child: GestureDetector(
                      onTap: onSignup,
                      child: RichText(
                        text: TextSpan(
                          text: "Don't have an account?  ",
                          style: AppTextStyles.bodySm.copyWith(
                              color: colors.authSubtitle),
                          children: [
                            TextSpan(
                              text:  'Sign up',
                              style: AppTextStyles.labelMd
                                  .copyWith(color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppConstants.sp8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}