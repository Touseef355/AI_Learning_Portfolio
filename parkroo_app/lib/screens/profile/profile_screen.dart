import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../api_service.dart';
import '../../utils/error_utils.dart';
import '../../models/user_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';
import '../auth/login_screen.dart';
import '../vehicles/vehicles_screen.dart';
import '../settings/settings_screen.dart';
import '../../widgets/common/micro_animations.dart';
import '../../widgets/common/pk_skeleton.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel? user;
  final VoidCallback? onLogout;
  final VoidCallback? onProfileUpdated;

  const ProfileScreen({
    super.key,
    this.user,
    this.onLogout,
    this.onProfileUpdated,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  UserModel? _user;
  bool _isLoading = true;
  bool _isUploadingPhoto = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    final cachedUser = ApiService.currentUser;
    if (cachedUser != null) {
      _user = cachedUser;
      _isLoading = false;
    }

    if (widget.user != null) {
      _user = widget.user;
      _isLoading = false;
    }

    _loadProfile();
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getProfile();
    if (mounted) {
      if (data['id'] != null) {
        setState(() {
          _user = UserModel.fromJson(data);
          _isLoading = false;
        });
        widget.onProfileUpdated?.call();
      } else {
        setState(() => _isLoading = false);
        // Only bother the user if we don't already have a cached profile to
        // show — otherwise the existing data stays on screen silently.
        if (_user == null) {
          ErrorUtils.showErrorSnack(
            context,
            ErrorUtils.messageFrom(data, fallback: 'Could not load your profile.'),
            onRetry: ErrorUtils.isRetryable(data) ? _loadProfile : null,
          );
        }
      }
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PhotoPickerSheet(),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 800,
    );

    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);

    final result = await ApiService.uploadProfilePhoto(File(picked.path));

    if (mounted) {
      setState(() => _isUploadingPhoto = false);
      if (result['id'] != null || result['profile_photo'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated!'), backgroundColor: AppColors.success),
        );
        _loadProfile();
      } else {
        ErrorUtils.showErrorSnack(
          context,
          ErrorUtils.messageFrom(result, fallback: 'Upload failed'),
          onRetry: ErrorUtils.isRetryable(result) ? _pickAndUploadPhoto : null,
        );
      }
    }
  }

  void _showEditSheet() {
    final nameCtrl = TextEditingController(text: _user?.fullName ?? '');
    final phoneCtrl = TextEditingController(text: _user?.phoneNumber ?? '');
    final addressCtrl = TextEditingController(text: _user?.address ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PremiumEditSheet(
        nameCtrl: nameCtrl,
        phoneCtrl: phoneCtrl,
        addressCtrl: addressCtrl,
        isSaving: false,
        onSave: () async {
          final result = await ApiService.updateProfile(
            fullName: nameCtrl.text.trim(),
            phoneNumber: phoneCtrl.text.trim(),
            address: addressCtrl.text.trim(),
          );

          if (result['id'] != null || result['full_name'] != null) {
            _loadProfile();
          } else if (mounted) {
            ErrorUtils.showErrorSnack(
              context,
              ErrorUtils.messageFrom(result, fallback: 'Failed to update profile'),
            );
          }
        },
      ),
    ).whenComplete(() {
      nameCtrl.dispose();
      phoneCtrl.dispose();
      addressCtrl.dispose();
    });
  }

  Future<void> _logout() async {
    HapticFeedback.lightImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.of(context).bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusXl)),
        title: Text('Sign out?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.of(context).textPrimary)),
        content: Text('You will be returned to the login screen.', style: TextStyle(fontSize: 13, color: AppColors.of(context).textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: AppColors.of(context).textHint))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (confirmed != true) return;

    if (widget.onLogout != null) {
      widget.onLogout!();
      return;
    }
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: colors.bgBase,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [AppColors.primary.withOpacity(0.04), colors.bgBase],
          ),
        ),
        child: _isLoading
            ? const _ProfileSkeleton()
            : RefreshIndicator(
                onRefresh: _loadProfile,
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        _TopAppBar(
                          colors: colors,
                          topPadding: topPadding,
                          onSettings: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                            if (mounted) _loadProfile();
                          },
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: FadeSlideAnimation(
                            delay: const Duration(milliseconds: 100),
                            child: _PremiumUserCard(
                              user: _user,
                              isUploadingPhoto: _isUploadingPhoto,
                              onPhotoTap: _pickAndUploadPhoto,
                              colors: colors,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: FadeSlideAnimation(
                            delay: const Duration(milliseconds: 180),
                            child: _PersonalInfoSection(
                              user: _user,
                              colors: colors,
                              onEditTap: _showEditSheet,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: FadeSlideAnimation(
                            delay: const Duration(milliseconds: 260),
                            child: _MyVehiclesSection(
                              user: _user,
                              colors: colors,
                              onAddVehicle: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const VehiclesScreen()),
                                );
                                if (mounted) _loadProfile();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 24),
                          child: FadeSlideAnimation(
                            delay: const Duration(milliseconds: 340),
                            child: _LogOutTile(
                              onTap: _logout,
                              colors: colors,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TOP APP BAR
// ═══════════════════════════════════════════════════════════════

class _TopAppBar extends StatelessWidget {
  final AppColorScheme colors;
  final double topPadding;
  final VoidCallback onSettings;

  const _TopAppBar({
    required this.colors,
    required this.topPadding,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final colorsTheme = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.only(top: topPadding + 12, left: 20, right: 20, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Profile',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: colors.textPrimary, letterSpacing: -0.5),
          ),
          TapScale(
            onTap: onSettings,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Icon(Icons.settings_outlined, size: 18, color: colorsTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PREMIUM USER CARD — gradient header with proper theme awareness
// ═══════════════════════════════════════════════════════════════

class _PremiumUserCard extends StatelessWidget {
  final UserModel? user;
  final bool isUploadingPhoto;
  final VoidCallback onPhotoTap;
  final AppColorScheme colors;

  const _PremiumUserCard({
    required this.user,
    required this.isUploadingPhoto,
    required this.onPhotoTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final photoUrl = user?.profileImageUrl ?? '';
    final hasPhoto = photoUrl.isNotEmpty;

    // Hero gradient: rich blue-purple in dark, soft blue-indigo in light
    final headerGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.bg3, AppColors.bg4],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.gradientEnd],
          );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: headerGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? const Color(0x30FFFFFF)
              : const Color(0x40FFFFFF),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(isDark ? 0.25 : 0.35),
            blurRadius: 28,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 130,
                height: 130,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x30FFFFFF), Colors.transparent],
                  ),
                ),
              ),
              TapScale(
                onTap: onPhotoTap,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.35), width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 12,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: isUploadingPhoto
                        ? Container(
                            color: Colors.white.withOpacity(0.1),
                            child: const Center(
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              ),
                            ),
                          )
                        : hasPhoto
                            ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildInitialsPlaceholder())
                            : _buildInitialsPlaceholder(),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: TapScale(
                  onTap: onPhotoTap,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Icon(Icons.camera_alt_rounded, size: 14, color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            user?.fullName ?? 'User',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.email_outlined, size: 12, color: Colors.white.withOpacity(0.8)),
                const SizedBox(width: 6),
                Text(
                  user?.email ?? 'user@parkroo.com',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialsPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          user?.initials ?? 'U',
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PERSONAL INFORMATION SECTION
// ═══════════════════════════════════════════════════════════════

class _PersonalInfoSection extends StatelessWidget {
  final UserModel? user;
  final AppColorScheme colors;
  final VoidCallback onEditTap;

  const _PersonalInfoSection({
    required this.user,
    required this.colors,
    required this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorsTheme = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal Information',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textSecondary),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: colors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            children: [
              _InfoTile(icon: Icons.phone_outlined, title: 'Phone', value: user?.phoneNumber ?? 'Not set', colors: colors),
              Divider(height: 1, color: colorsTheme.border),
              _InfoTile(icon: Icons.location_on_outlined, title: 'Address', value: user?.address?.isNotEmpty == true ? user!.address : 'Not set', colors: colors),
              Divider(height: 1, color: colorsTheme.border),
              _EditProfileTile(icon: Icons.person_outline_rounded, title: 'Edit Profile', onTap: onEditTap, colors: colors),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final AppColorScheme colors;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: colors.textHint)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 14, color: colors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final AppColorScheme colors;

  const _EditProfileTile({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.textPrimary),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: colors.textHint),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MY VEHICLES SECTION
// ═══════════════════════════════════════════════════════════════

class _MyVehiclesSection extends StatelessWidget {
  final UserModel? user;
  final AppColorScheme colors;
  final VoidCallback onAddVehicle;

  const _MyVehiclesSection({
    required this.user,
    required this.colors,
    required this.onAddVehicle,
  });

  @override
  Widget build(BuildContext context) {
    final colorsTheme = AppColors.of(context);
    final vehicles = user?.vehicles ?? [];
    final hasVehicle = vehicles.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Vehicles',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textSecondary),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: colors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: hasVehicle
              ? Column(
                  children: vehicles.asMap().entries.map((entry) {
                    final index = entry.key;
                    final vehicle = entry.value;
                    return Column(
                      children: [
                        _VehicleTile(vehicle: vehicle),
                        if (index != vehicles.length - 1)
                          Divider(
                            height: 1,
                            color: colorsTheme.border,
                          ),
                      ],
                    );
                  }).toList(),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.directions_car_outlined,
                          size: 22,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'No vehicle added',
                          style: TextStyle(fontSize: 14, color: colors.textSecondary),
                        ),
                      ),
                      TapScale(
                        onTap: onAddVehicle,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Add',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _VehicleTile extends StatelessWidget {
  final Map<String, dynamic> vehicle;

  const _VehicleTile({
    super.key,
    required this.vehicle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return TapScale(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VehiclesScreen()),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.directions_car_rounded,
              size: 24,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                vehicle['vehicle_name'] ?? 'Vehicle',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
            ),
            Text(
              vehicle['plate_number'] ?? '',
              style: TextStyle(
                fontSize: 12,
                color: colors.textHint,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: colors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// LOG OUT TILE
// ═══════════════════════════════════════════════════════════════

class _LogOutTile extends StatelessWidget {
  final VoidCallback onTap;
  final AppColorScheme colors;

  const _LogOutTile({required this.onTap, required this.colors});

  @override
  Widget build(BuildContext context) {
    final colorsTheme = AppColors.of(context);
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.logout_rounded, size: 22, color: AppColors.danger),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Log Out',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.danger),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: colorsTheme.textHint),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PHOTO PICKER SHEET
// ═══════════════════════════════════════════════════════════════

class _PhotoPickerSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(color: colors.bgCard, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Choose Photo Source', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary)),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.camera_alt_outlined, color: AppColors.primary)),
              title: Text('Camera', style: TextStyle(color: colors.textPrimary)),
              subtitle: Text('Take a photo now', style: TextStyle(color: colors.textHint, fontSize: 12)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.photo_library_outlined, color: AppColors.success)),
              title: Text('Gallery', style: TextStyle(color: colors.textPrimary)),
              subtitle: Text('Choose from gallery', style: TextStyle(color: colors.textHint, fontSize: 12)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PREMIUM EDIT SHEET
// ═══════════════════════════════════════════════════════════════

class _PremiumEditSheet extends StatefulWidget {
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController addressCtrl;
  final bool isSaving;
  final Future<void> Function() onSave;

  const _PremiumEditSheet({
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.addressCtrl,
    required this.isSaving,
    required this.onSave,
  });

  @override
  State<_PremiumEditSheet> createState() => _PremiumEditSheetState();
}

class _PremiumEditSheetState extends State<_PremiumEditSheet> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        decoration: BoxDecoration(color: colors.bgCard, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        child: Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: AppColors.primaryGradient), borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.edit_outlined, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Text('Edit Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: colors.textPrimary, letterSpacing: -0.5)),
                ],
              ),
              const SizedBox(height: 24),
              _PremiumEditField(controller: widget.nameCtrl, label: 'Full Name', icon: Icons.person_outline_rounded, colors: colors),
              const SizedBox(height: 14),
              _PremiumEditField(controller: widget.phoneCtrl, label: 'Phone Number', icon: Icons.phone_outlined, keyboardType: TextInputType.phone, colors: colors),
              const SizedBox(height: 14),
              _PremiumEditField(controller: widget.addressCtrl, label: 'Address', icon: Icons.location_on_outlined, colors: colors),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: _isSaving
                      ? null
                      : () async {
                          HapticFeedback.lightImpact();
                          setState(() => _isSaving = true);
                          await widget.onSave();
                          setState(() => _isSaving = false);
                          if (mounted) Navigator.pop(context);
                        },
                  child: _isSaving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumEditField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;
  final AppColorScheme colors;

  const _PremiumEditField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.colors,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: colors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.textHint, fontSize: 13),
        prefixIcon: Icon(icon, color: colors.textHint, size: 20),
        filled: true,
        fillColor: colors.bgInput,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: colors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: colors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PROFILE SKELETON — replaces spinner on load
// ═══════════════════════════════════════════════════════════════
class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          // Header area
          Container(
            height: 260,
            color: colors.bgDeep,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                PkSkeleton(width: 88, height: 88, borderRadius: 44),
                const SizedBox(height: 16),
                PkSkeleton(width: 140, height: 18, borderRadius: 9),
                const SizedBox(height: 8),
                PkSkeleton(width: 100, height: 13, borderRadius: 6),
                const SizedBox(height: 12),
                PkSkeleton(width: 80, height: 28, borderRadius: 14),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Stats row
                Row(children: [
                  Expanded(child: PkSkeleton(width: double.infinity, height: 72, borderRadius: 16)),
                  const SizedBox(width: 12),
                  Expanded(child: PkSkeleton(width: double.infinity, height: 72, borderRadius: 16)),
                  const SizedBox(width: 12),
                  Expanded(child: PkSkeleton(width: double.infinity, height: 72, borderRadius: 16)),
                ]),
                const SizedBox(height: 24),
                // Section
                PkSkeleton(width: 120, height: 14, borderRadius: 7),
                const SizedBox(height: 14),
                ...List.generate(4, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PkSkeleton(width: double.infinity, height: 56, borderRadius: 14),
                )),
                const SizedBox(height: 16),
                PkSkeleton(width: 120, height: 14, borderRadius: 7),
                const SizedBox(height: 14),
                ...List.generate(3, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PkSkeleton(width: double.infinity, height: 56, borderRadius: 14),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
