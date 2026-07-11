import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/pk_button.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  late final AnimationController _contentCtrl;
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowPulse;

  static const List<_Slide> _slides = [
    _Slide(
      title: 'Find parking\nin seconds',
      description:
          'See live availability near you. No more driving in circles.',
      image: 'assets/images/onboarding/onboarding_find.png',
      accentColor: Color(0xFF3B82F6),
      glowColor: Color(0xFF1D4ED8),
    ),
    _Slide(
      title: 'Book &\npay online',
      description:
          'Reserve your slot instantly. Pay securely, get confirmation right away.',
      image: 'assets/images/onboarding/onboarding_book.png',
      accentColor: Color(0xFF10B981),
      glowColor: Color(0xFF065F46),
    ),
    _Slide(
      title: 'Drive\nstraight in',
      description: 'Gate opens automatically. No tickets, no waiting.',
      image: 'assets/images/onboarding/onboarding_entry.png',
      accentColor: Color(0xFF8B5CF6),
      glowColor: Color(0xFF4C1D95),
    ),
  ];

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _glowPulse = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _contentCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _contentCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _contentCtrl.forward(from: 0.0);
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _goToLogin();
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentPage];
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.of(context).bgDeep,
      body: Stack(
        children: [
          /// ── PAGE VIEW WITH CINEMATIC TRANSITION
          PageView.builder(
            controller: _pageCtrl,
            onPageChanged: _onPageChanged,
            itemCount: _slides.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (_, index) {
              return _buildPageItem(_slides[index], index);
            },
          ),

          /// ── GLOW EFFECT
          AnimatedBuilder(
            animation: _glowCtrl,
            builder: (_, __) {
              return Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: size.height * 0.55,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.3,
                      colors: [
                        slide.glowColor.withOpacity(
                          0.18 + _glowPulse.value * 0.06,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          /// ── SKIP BUTTON
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: _goToLogin,
                  child: Text(
                    'Skip',
                    style: AppTextStyles.labelLg.copyWith(
                      color: Colors.white.withOpacity(0.55),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),

          /// ── BOTTOM SHEET
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomSheet(
              slide: slide,
              currentPage: _currentPage,
              total: _slides.length,
              contentCtrl: _contentCtrl,
              onNext: _next,
              onLogin: _goToLogin,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageItem(_Slide slide, int index) {
    return AnimatedBuilder(
      animation: _pageCtrl,
      builder: (context, _) {
        double page = _pageCtrl.hasClients
            ? (_pageCtrl.page ?? _currentPage.toDouble())
            : _currentPage.toDouble();

        final distance = page - index;
        final t = (1 - distance.abs()).clamp(0.0, 1.0);

        final scale = 0.88 + (t * 0.12);
        final opacity = 0.6 + (t * 0.4);
        final translateX = distance * 25;

        return Transform.translate(
          offset: Offset(translateX, 0),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: _HeroImage(slide: slide),
            ),
          ),
        );
      },
    );
  }
}

class _HeroImage extends StatelessWidget {
  final _Slide slide;

  const _HeroImage({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          slide.image,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.black,
            child: const Center(
              child: Icon(Icons.image_not_supported, color: Colors.white54, size: 48),
            ),
          ),
        ),

        // Top fade
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.of(context).bgDeep.withOpacity(0.7),
                Colors.transparent,
              ],
            ),
          ),
        ),

        // Bottom cinematic fade
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: MediaQuery.of(context).size.height * 0.55,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  AppColors.of(context).bgDeep,
                  AppColors.of(context).bgDeep,
                  Color(0xCC070C18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomSheet extends StatelessWidget {
  final _Slide slide;
  final int currentPage;
  final int total;
  final AnimationController contentCtrl;
  final VoidCallback onNext;
  final VoidCallback onLogin;

  const _BottomSheet({
    required this.slide,
    required this.currentPage,
    required this.total,
    required this.contentCtrl,
    required this.onNext,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = currentPage == total - 1;

    return AnimatedBuilder(
      animation: contentCtrl,
      builder: (_, __) {
        final t = Curves.easeOutCubic.transform(contentCtrl.value);

        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - t)),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                AppConstants.sp24,
                AppConstants.sp28,
                AppConstants.sp24,
                MediaQuery.of(context).padding.bottom + 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    slide.title,
                    style: AppTextStyles.display1.copyWith(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                      letterSpacing: -1.2,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    slide.description,
                    style: AppTextStyles.bodyLg.copyWith(
                      color: Colors.white.withOpacity(0.55),
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 32),

                  /// Progress bar
                  Container(
                    height: 4,
                    width: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (currentPage + 1) / total,
                      child: Container(
                        decoration: BoxDecoration(
                          color: slide.accentColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: slide.accentColor.withOpacity(0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  PkButton(
                    label: isLast ? 'Get Started' : 'Continue',
                    icon: Icons.arrow_forward_rounded,
                    iconTrailing: true,
                    onPressed: onNext,
                  ),

                  if (!isLast) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: GestureDetector(
                        onTap: onLogin,
                        child: Text(
                          'Already have an account? Sign in',
                          style: AppTextStyles.labelMd.copyWith(
                            color: Colors.white.withOpacity(0.35),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Slide {
  final String title;
  final String description;
  final String image;
  final Color accentColor;
  final Color glowColor;

  const _Slide({
    required this.title,
    required this.description,
    required this.image,
    required this.accentColor,
    required this.glowColor,
  });
}