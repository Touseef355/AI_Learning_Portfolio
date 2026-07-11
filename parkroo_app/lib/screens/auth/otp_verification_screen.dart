import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/pk_button.dart';
import '../../api_service.dart';
import '../../utils/error_utils.dart';
import '../home/dashboard_screen.dart';
import 'new_password_screen.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final bool isPasswordReset;
  final String? email;
  final Map<String, dynamic>? pendingSignupData;

  const OTPVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.isPasswordReset = false,
    this.email,
    this.pendingSignupData,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen>
    with TickerProviderStateMixin {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _timerSeconds = 60;
  bool _isResendEnabled = false;
  bool _isLoading = false;

  late final AnimationController _staggerCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _shakeCtrl;
  late final Animation<double> _bgFade;
  late final Animation<double> _topFade;
  late final Animation<double> _formFade;
  late final Animation<Offset> _formSlide;
  late final Animation<double> _glowPulse;
  late final Animation<double> _shakeAnim;

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

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _startTimer();
    _staggerCtrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNodes[0].requestFocus());
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), _tick);
  }

  void _tick() {
    if (!mounted) return;
    if (_timerSeconds > 0) {
      setState(() => _timerSeconds--);
      Future.delayed(const Duration(seconds: 1), _tick);
    } else {
      setState(() => _isResendEnabled = true);
    }
  }

  void _resendCode() {
    setState(() {
      _timerSeconds = 60;
      _isResendEnabled = false;
      for (var c in _controllers) c.clear();
    });
    _startTimer();
    _focusNodes[0].requestFocus();
    ApiService.sendOtp(widget.phoneNumber);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Verification code resent',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.white)),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppConstants.sp16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
      ),
    );
  }

  Future<void> _verifyCode() async {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length < 6) {
      _shakeCtrl.forward(from: 0);
      _showError('Please enter the complete 6-digit code');
      return;
    }
    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> result;
      if (widget.isPasswordReset && widget.email != null) {
        result = await ApiService.verifyPasswordOtp(
            email: widget.email!, otpCode: otp);
      } else {
        result = await ApiService.verifyOtp(
            phoneNumber: widget.phoneNumber, otpCode: otp);
      }
      if (!mounted) return;
      if (result.containsKey('message') ||
          result['verified'] == true ||
          result.containsKey('tokens') ||
          result.containsKey('access') ||
          result['status'] == 'success') {
        if (widget.isPasswordReset && widget.email != null) {
          _showSuccess('Verification successful');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => NewPasswordScreen(email: widget.email!)),
          );
        } else if (widget.pendingSignupData != null) {
          final signupResult = await ApiService.signup(
            fullName: widget.pendingSignupData!['fullName'],
            email: widget.pendingSignupData!['email'],
            phone: widget.pendingSignupData!['phone'],
            password: widget.pendingSignupData!['password'],
            confirmPassword: widget.pendingSignupData!['confirmPassword'],
          );
          if (!mounted) return;
          if (signupResult.containsKey('tokens') ||
              signupResult.containsKey('message') ||
              signupResult.containsKey('user') ||
              signupResult['status'] == 'success') {
            _showSuccess('Account created successfully');
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
              (r) => false,
            );
          } else {
            _showError(
              ErrorUtils.messageFrom(signupResult, fallback: 'Registration failed. Please try again.'),
              onRetry: ErrorUtils.isRetryable(signupResult) ? _verifyCode : null,
            );
            _shakeCtrl.forward(from: 0);
          }
        } else {
          _showSuccess('Verification successful');
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
            (r) => false,
          );
        }
      } else {
        _showError(
          ErrorUtils.messageFrom(result, fallback: 'Invalid code. Please try again.'),
          onRetry: ErrorUtils.isRetryable(result) ? _verifyCode : null,
        );
        _shakeCtrl.forward(from: 0);
        for (var c in _controllers) c.clear();
        _focusNodes[0].requestFocus();
      }
    } catch (e, st) {
      ErrorUtils.logError('OTPVerificationScreen._verifyCode', e, st);
      if (mounted) _showError(ErrorUtils.friendlyMessage(e), onRetry: _verifyCode);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg, {VoidCallback? onRetry}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
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

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: AppColors.white, size: 18),
          const SizedBox(width: 8),
          Text(msg,
              style: AppTextStyles.bodySm.copyWith(color: AppColors.white)),
        ]),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppConstants.sp16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
      ),
    );
  }

  @override
  void dispose() {
    for (var c in _controllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    _staggerCtrl.dispose();
    _glowCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  String get _maskedContact {
    final s = widget.phoneNumber;
    if (s.contains('@')) {
      final parts = s.split('@');
      final name = parts[0];
      final masked = name.length > 3
          ? '${name.substring(0, 3)}${'•' * (name.length - 3)}'
          : name;
      return '$masked@${parts[1]}';
    }
    if (s.length > 6) {
      return '${s.substring(0, 4)}${'•' * (s.length - 6)}${s.substring(s.length - 2)}';
    }
    return s;
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
            child: _OtpBackground(
              size: size,
              colors: colors,
              glowPulse: _glowPulse,
            ),
          ),

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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              //  Logo — Same size as Forgot Password (100x100, image 85)
                              FadeTransition(
                                opacity: _topFade,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
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
                                          size: 60,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Dynamic Heading
                              FadeTransition(
                                opacity: _topFade,
                                child: Column(
                                  children: [
                                    Text(
                                      widget.isPasswordReset
                                          ? 'Verify Reset Code'
                                          : 'Verify Your Account',
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.h1.copyWith(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    RichText(
                                      textAlign: TextAlign.center,
                                      text: TextSpan(
                                        style: AppTextStyles.bodyMd.copyWith(
                                          height: 1.5,
                                          color: AppColors.of(context).authSubtitle,
                                        ),
                                        children: [
                                          const TextSpan(
                                            text: 'Enter the 6-digit verification code sent to ',
                                          ),
                                          TextSpan(
                                            text: _maskedContact,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 32),

                              // OTP Boxes - Responsive (No Overflow)
                              SlideTransition(
                                position: _formSlide,
                                child: FadeTransition(
                                  opacity: _formFade,
                                  child: AnimatedBuilder(
                                    animation: _shakeAnim,
                                    builder: (_, child) => Transform.translate(
                                      offset: Offset(_shakeAnim.value, 0),
                                      child: child,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(
                                        6,
                                        (i) => Flexible(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 4),
                                            child: AspectRatio(
                                              aspectRatio: 0.8,
                                              child: _buildOtpBox(i),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 32),

                              // Timer
                              SlideTransition(
                                position: _formSlide,
                                child: FadeTransition(
                                  opacity: _formFade,
                                  child: _buildTimer(),
                                ),
                              ),

                              const SizedBox(height: 32),

                              // Verify Button
                              SlideTransition(
                                position: _formSlide,
                                child: FadeTransition(
                                  opacity: _formFade,
                                  child: PkButton(
                                    label: 'Verify Code',
                                    isLoading: _isLoading,
                                    onPressed: _verifyCode,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Resend Section
                              SlideTransition(
                                position: _formSlide,
                                child: FadeTransition(
                                  opacity: _formFade,
                                  child: _buildResendSection(),
                                ),
                              ),

                              const SizedBox(height: 28),
                            ],
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

Widget _buildOtpBox(int i) {
  return KeyboardListener(
    focusNode: FocusNode(),
    onKeyEvent: (event) {
      // Backspace press
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.backspace) {
        // Agar current box empty hai to previous pe jao
        if (_controllers[i].text.isEmpty && i > 0) {
          _controllers[i - 1].clear();
          _focusNodes[i - 1].requestFocus();
        }
      }
    },
    child: TextFormField(
      controller: _controllers[i],
      focusNode: _focusNodes[i],
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      maxLength: 1,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.of(context).textPrimary,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        counterText: '',
        filled: true,
        fillColor: AppColors.of(context).bgInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.of(context).border,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
        contentPadding: EdgeInsets.zero,
      ),

      onChanged: (value) {
        // Next box
        if (value.isNotEmpty) {
          if (i < 5) {
            _focusNodes[i + 1].requestFocus();
          } else {
            _focusNodes[i].unfocus();
            _verifyCode();
          }
        }

        // Empty hua to previous pe move
        else if (value.isEmpty && i > 0) {
          _focusNodes[i - 1].requestFocus();
        }
      },
    ),
  );
}

  Widget _buildTimer() {
    final minutes = (_timerSeconds / 60).floor();
    final seconds = _timerSeconds % 60;
    final timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    
    return Center(
      child: Column(
        children: [
          if (_isResendEnabled)
            Text(
              'Code expired',
              style: AppTextStyles.labelMd.copyWith(
                color: AppColors.danger,
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Expires in ',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.of(context).authSubtitle,
                  ),
                ),
                Text(
                  timeString,
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildResendSection() {
    return Column(
      children: [
        if (_isResendEnabled)
          GestureDetector(
            onTap: _resendCode,
            child: Text(
              'Resend Code',
              style: AppTextStyles.labelMd.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          Text(
            "Didn't receive the code?",
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.of(context).authSubtitle,
            ),
          ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Text(
            'Edit ${widget.isPasswordReset ? 'email' : 'phone number'}',
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.of(context).textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Premium Background
// ═══════════════════════════════════════════════════════════════

class _OtpBackground extends StatelessWidget {
  final Size size;
  final AppColorScheme colors;
  final Animation<double> glowPulse;

  const _OtpBackground({
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