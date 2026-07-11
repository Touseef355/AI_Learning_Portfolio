import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api_service.dart';
import '../../utils/error_utils.dart';
import '../../theme/app_colors.dart';
import '../auth/onboarding_screen.dart';
import '../home/dashboard_screen.dart';

/// Parkroo — Premium Minimal Splash Screen
///
/// Design:
///   ✦ Clean dark background with blurred glass orbs
///   ✦ Centered logo with fade + scale animation
///   ✦ Elegant thin progress loader (72px width)
///   ✦ No duplicate text (logo already has brand name)
///   ✦ Tesla/Revolut level minimalism
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _loaderCtrl;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoY;
  late final Animation<double> _loaderProgress;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
    ));

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _logoScale = Tween(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: Curves.easeOutCubic,
      ),
    );

    _logoOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: Curves.easeOut,
      ),
    );

    _logoY = Tween(begin: 18.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: Curves.easeOutCubic,
      ),
    );

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _loaderCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _loaderProgress = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _loaderCtrl,
        curve: Curves.easeInOutCubic,
      ),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    await _entryCtrl.forward();
    _loaderCtrl.forward();
    // Increased duration for premium breathing space
    await Future.delayed(const Duration(milliseconds: 2200));
    _navigate();
  }

  Future<void> _navigate() async {
    // If reading the saved session fails for any reason, fall back to
    // "logged out" rather than hanging the splash screen forever.
    String token = '';
    try {
      token = await ApiService.getAccessToken();
    } catch (e, st) {
      ErrorUtils.logError('SplashScreen._navigate', e, st);
    }
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 550),
        pageBuilder: (_, __, ___) => token.isNotEmpty
            ? const DashboardScreen()
            : const OnboardingScreen(),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _glowCtrl.dispose();
    _loaderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).bgDeep,
      body: Stack(
        children: [
          const _PremiumBackground(),
          SafeArea(
            child: Center(
              child: Column(
                children: [
                  const Spacer(flex: 1),
                  AnimatedBuilder(
                    animation: Listenable.merge([_entryCtrl, _glowCtrl]),
                    builder: (_, __) {
                      return FadeTransition(
                        opacity: _logoOpacity,
                        child: Transform.translate(
                          offset: Offset(0, _logoY.value),
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: _LogoSection(
                              glow: 0.08 + (_glowCtrl.value * 0.05),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // No duplicate "Parkroo" text — logo already has it
                  const SizedBox(height: 16),
                  // Premium tagline only
                  ShaderMask(
                    shaderCallback: (bounds) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white70,
                          Colors.white38,
                        ],
                      ).createShader(bounds);
                    },
                    child: Text(
                      'Parking, reimagined.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  AnimatedBuilder(
                    animation: _loaderCtrl,
                    builder: (_, __) {
                      return _LinearLoader(progress: _loaderProgress.value);
                    },
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Premium Background — Blurred Glass Orbs (Real Glow Effect)
// ═══════════════════════════════════════════════════════════════

class _PremiumBackground extends StatelessWidget {
  const _PremiumBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: AppColors.of(context).bgDeep),
        
        // Blurred glass orb top-left (real glow effect)
        Positioned(
          top: -180,
          left: -120,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(200),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
              ),
            ),
          ),
        ),
        
        // Blurred glass orb bottom-right (real glow effect)
        Positioned(
          bottom: -180,
          right: -100,
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
        
        // Soft blue orb center-right (extra depth)
        Positioned(
          top: 100,
          right: -80,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(150),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00D1FF).withValues(alpha: 0.04),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Logo Section — Hero with Premium Glow (Size Optimized)
// ═══════════════════════════════════════════════════════════════

class _LogoSection extends StatelessWidget {
  final double glow;

  const _LogoSection({required this.glow});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,  // Reduced from 210
      height: 190, // Reduced from 210
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: glow),
            blurRadius: 80,
            spreadRadius: 12,
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/branding/splash_logo.png',
        width: 145,  // Reduced from 165
        height: 145, // Reduced from 165
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          width: 145,
          height: 145,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.primaryGradient,
            ),
            borderRadius: BorderRadius.circular(36),
          ),
          child: const Icon(
            Icons.local_parking_rounded,
            size: 70,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Linear Loader — Elegant 72px Width (Not Too Tiny)
// ═══════════════════════════════════════════════════════════════

class _LinearLoader extends StatelessWidget {
  final double progress;

  const _LinearLoader({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,   // Increased from 44 — more elegant
      height: 3,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.08),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.gradientEnd,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}