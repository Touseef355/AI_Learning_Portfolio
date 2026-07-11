// lib/widgets/common/pk_empty_state_image.dart
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';
import '../../theme/app_text_styles.dart';
import 'pk_button.dart';
import '../../utils/app_images.dart';

/// Parkroo Premium Empty State with Custom Illustrations
/// Use this when you have local illustration assets.
class PkEmptyStateImage extends StatelessWidget {
  final String imagePath;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double imageSize;

  const PkEmptyStateImage({
    super.key,
    required this.imagePath,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.imageSize = 120,
  });

  // Preset factory constructors for common empty states
  factory PkEmptyStateImage.bookings({VoidCallback? onAction}) {
    return PkEmptyStateImage(
      imagePath: AppImages.emptyBookings,
      title: 'No bookings yet',
      subtitle: 'Book your first parking slot to see it here',
      actionLabel: 'Find Parking',
      onAction: onAction,
    );
  }

  factory PkEmptyStateImage.notifications({VoidCallback? onAction}) {
    return PkEmptyStateImage(
      imagePath: AppImages.emptyNotifications,
      title: 'No notifications',
      subtitle: 'We\'ll notify you when something arrives',
      imageSize: 100,
    );
  }

  factory PkEmptyStateImage.vehicles({VoidCallback? onAction}) {
    return PkEmptyStateImage(
      imagePath: AppImages.emptyVehicles,
      title: 'No vehicles added',
      subtitle: 'Add your vehicle to start booking',
      actionLabel: 'Add Vehicle',
      onAction: onAction,
    );
  }

  factory PkEmptyStateImage.search({VoidCallback? onAction}) {
    return PkEmptyStateImage(
      imagePath: AppImages.emptySearch,
      title: 'No results found',
      subtitle: 'Try adjusting your search or filters',
      actionLabel: 'Clear Filters',
      onAction: onAction,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.sp32,
          vertical: AppConstants.sp40,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              imagePath,
              width: imageSize,
              height: imageSize,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: AppConstants.sp24),
            Text(
              title,
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppConstants.sp8),
              Text(
                subtitle!,
                style: AppTextStyles.bodyMd,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppConstants.sp28),
              PkButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: PkButtonVariant.primary,
                size: PkButtonSize.medium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}