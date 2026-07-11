import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';

/// Parkroo Skeleton Loader — theme-aware shimmer placeholder
class PkSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double? borderRadius;

  const PkSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  const PkSkeleton.text({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.borderRadius,
  });

  @override
  State<PkSkeleton> createState() => _PkSkeletonState();
}

class _PkSkeletonState extends State<PkSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            widget.borderRadius ?? AppConstants.radiusSm,
          ),
          gradient: LinearGradient(
            begin: Alignment(-1.5 + _anim.value * 3.0, 0),
            end: Alignment(0.5 + _anim.value * 3.0, 0),
            colors: [
              colors.bgCard,
              colors.bgElevated,
              colors.bgCard,
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable skeleton layouts ────────────────────────────────

/// Generic card skeleton — matches ParkingCard / BookingCard shape
class PkSkeletonCard extends StatelessWidget {
  final double height;
  const PkSkeletonCard({super.key, this.height = 140});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      height: height,
      padding: const EdgeInsets.all(AppConstants.sp16),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(children: [
            PkSkeleton(width: 44, height: 44, borderRadius: AppConstants.radiusMd),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PkSkeleton.text(width: 140, height: 15),
                  const SizedBox(height: 6),
                  PkSkeleton.text(width: 90, height: 12),
                ],
              ),
            ),
            PkSkeleton(width: 52, height: 24, borderRadius: 12),
          ]),
          const SizedBox(height: 12),
          const PkSkeleton.text(height: 12),
          const SizedBox(height: 6),
          PkSkeleton.text(width: 180, height: 12),
        ],
      ),
    );
  }
}

/// Booking card skeleton — matches booking list item
class PkSkeletonBookingCard extends StatelessWidget {
  const PkSkeletonBookingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppConstants.sp16),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            PkSkeleton(width: 40, height: 40, borderRadius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PkSkeleton.text(width: 160, height: 14),
                  const SizedBox(height: 5),
                  PkSkeleton.text(width: 100, height: 11),
                ],
              ),
            ),
            PkSkeleton(width: 60, height: 22, borderRadius: 20),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: PkSkeleton.text(height: 11)),
            const SizedBox(width: 12),
            Expanded(child: PkSkeleton.text(height: 11)),
          ]),
        ],
      ),
    );
  }
}

/// Notification item skeleton
class PkSkeletonNotification extends StatelessWidget {
  const PkSkeletonNotification({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.sp16, vertical: AppConstants.sp12),
      decoration: BoxDecoration(
        color: colors.bgCard,
        border: Border(bottom: BorderSide(color: colors.border, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PkSkeleton(width: 42, height: 42, borderRadius: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PkSkeleton.text(width: 180, height: 13),
                const SizedBox(height: 6),
                const PkSkeleton.text(height: 11),
                const SizedBox(height: 4),
                PkSkeleton.text(width: 120, height: 11),
                const SizedBox(height: 6),
                PkSkeleton.text(width: 70, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Transaction item skeleton (wallet)
class PkSkeletonTransaction extends StatelessWidget {
  const PkSkeletonTransaction({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.sp16, vertical: AppConstants.sp12),
      decoration: BoxDecoration(
        color: colors.bgCard,
        border: Border(bottom: BorderSide(color: colors.border, width: 0.5)),
      ),
      child: Row(children: [
        PkSkeleton(width: 40, height: 40, borderRadius: 12),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PkSkeleton.text(width: 130, height: 13),
              const SizedBox(height: 5),
              PkSkeleton.text(width: 80, height: 11),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            PkSkeleton(width: 60, height: 13),
            const SizedBox(height: 5),
            PkSkeleton(width: 40, height: 11),
          ],
        ),
      ]),
    );
  }
}

/// Vehicle card skeleton
class PkSkeletonVehicleCard extends StatelessWidget {
  const PkSkeletonVehicleCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppConstants.sp16),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: colors.border),
      ),
      child: Row(children: [
        PkSkeleton(width: 52, height: 52, borderRadius: AppConstants.radiusMd),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PkSkeleton.text(width: 120, height: 14),
              const SizedBox(height: 6),
              PkSkeleton.text(width: 80, height: 12),
              const SizedBox(height: 6),
              PkSkeleton.text(width: 60, height: 11),
            ],
          ),
        ),
        PkSkeleton(width: 28, height: 28, borderRadius: 14),
      ]),
    );
  }
}

/// A full-screen list of skeleton items
class PkSkeletonList extends StatelessWidget {
  final Widget Function() itemBuilder;
  final int count;
  final EdgeInsets padding;
  final double spacing;

  const PkSkeletonList({
    super.key,
    required this.itemBuilder,
    this.count = 5,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      itemCount: count,
      separatorBuilder: (_, __) => SizedBox(height: spacing),
      itemBuilder: (_, __) => itemBuilder(),
    );
  }
}