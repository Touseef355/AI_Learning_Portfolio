import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
// TAP SCALE — Premium spring press effect
// ═══════════════════════════════════════════════════════════════

class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final Duration duration;

  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.95,
    this.duration = const Duration(milliseconds: 100),
  });

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeOutBack, // spring return
    ));
  }

  Future<void> _handleTap() async {
    await _controller.forward();
    await _controller.reverse();
    widget.onTap?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.translucent,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// FADE + SLIDE — Premium entrance animation
// ═══════════════════════════════════════════════════════════════

class FadeSlideAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double beginOffsetY;

  const FadeSlideAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
    this.beginOffsetY = 0.06,
  });

  @override
  State<FadeSlideAnimation> createState() => _FadeSlideAnimationState();
}

class _FadeSlideAnimationState extends State<FadeSlideAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _slide = Tween<Offset>(
      begin: Offset(0, widget.beginOffsetY),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _runAnimation();
  }

  Future<void> _runAnimation() async {
    await Future.delayed(widget.delay);
    if (mounted) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SPRING SLIDE IN — For cards, booking cards, success states
// ═══════════════════════════════════════════════════════════════

class SpringSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final double beginOffsetY;

  const SpringSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.beginOffsetY = 30.0,
  });

  @override
  State<SpringSlideIn> createState() => _SpringSlideInState();
}

class _SpringSlideInState extends State<SpringSlideIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fade = CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.7, curve: Curves.easeOut));
    _slide = Tween<double>(begin: widget.beginOffsetY, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );

    _run();
  }

  Future<void> _run() async {
    await Future.delayed(widget.delay);
    if (mounted) _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Opacity(
        opacity: _fade.value,
        child: Transform.translate(
          offset: Offset(0, _slide.value),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// STAGGERED LIST — Auto-stagger multiple children on entrance
// ═══════════════════════════════════════════════════════════════

class StaggeredList extends StatelessWidget {
  final List<Widget> children;
  final Duration staggerDelay;
  final Duration itemDuration;

  const StaggeredList({
    super.key,
    required this.children,
    this.staggerDelay = const Duration(milliseconds: 60),
    this.itemDuration = const Duration(milliseconds: 400),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < children.length; i++)
          SpringSlideIn(
            delay: staggerDelay * i,
            child: children[i],
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PULSE ANIMATION — For active booking indicator, badges
// ═══════════════════════════════════════════════════════════════

class PulseAnimation extends StatefulWidget {
  final Widget child;
  final Duration period;

  const PulseAnimation({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 1800),
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.period)
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
