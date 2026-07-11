import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/micro_animations.dart';
import '../../api_service.dart';
import '../../services/realtime_service.dart';
import '../../utils/error_utils.dart';
import '../../models/user_model.dart';
import '../auth/login_screen.dart';
import '../profile/profile_screen.dart';
import '../booking/book_slot_screen.dart';
import '../booking/my_bookings_screen.dart';
import '../notifications/notifications_screen.dart';
import '../wallet/wallet_screen.dart';
import '../booking/book_parking_tab.dart';
import '../passes/my_passes_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  DASHBOARD SCREEN — Shell + Bottom Navigation
// ═══════════════════════════════════════════════════════════════

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  UserModel? _user;
  List<dynamic> _parkingSites = [];
  bool _isLoadingSites = true;
  Map<String, dynamic>? _activeBooking;
  bool _isLoadingActiveBooking = true;

  late final AnimationController _animCtrl;
  Timer? _autoRefreshTimer;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _loadUserData();
    _loadParkingSites();
    _loadActiveBooking();
    _animCtrl.forward();

    // ── Silent auto-refresh: har 20s data chupchaap update hota hai. ──
    // Loading flags ko touch nahi karte, is liye koi skeleton/spinner
    // flash nahi hota — user ko sirf fresh numbers dikhte hain.
    // Realtime events primary hain — yeh timer ab fallback hai (60s).
    RealtimeService.instance.connect();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted) return;
      _silentRefresh();
    });

    ApiService.onSessionExpired = () {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  /// Background refresh — sites + active booking bina kisi loading state ke.
  Future<void> _silentRefresh() async {
    try {
      final results = await Future.wait([
        ApiService.getParkingSites(),
        ApiService.getBookings(),
      ]);
      if (!mounted) return;
      final sites = results[0];
      final bookings = results[1];
      final active = bookings.firstWhere(
        (b) {
          final status = (b['status'] ?? '').toString().toLowerCase();
          return status == 'active' || status == 'pending' || status == 'confirmed';
        },
        orElse: () => null,
      );
      setState(() {
        _parkingSites = sites;
        _activeBooking = active;
      });
    } catch (e, st) {
      // Silent refresh kabhi UI disturb nahi karta — fail hua toh purana
      // data dikhta rehta hai, agla tick phir try karega.
      ErrorUtils.logError('DashboardScreen._silentRefresh', e, st);
    }
  }

  Future<void> _loadUserData() async {
    final data = await ApiService.getProfile();
    if (mounted && data['id'] != null) {
      setState(() => _user = UserModel.fromJson(data));
    } else {
      if (data.containsKey('error')) {
        ErrorUtils.logError('DashboardScreen._loadUserData', data['error']);
      }
      final name = await ApiService.getUserName();
      if (mounted && name.isNotEmpty) {
        setState(() => _user = UserModel(
              id: '',
              fullName: name,
              email: '',
              phoneNumber: '',
            ));
      }
    }
  }

  Future<void> _loadParkingSites() async {
    if (!_isLoadingSites) setState(() => _isLoadingSites = true);
    try {
      final sites = await ApiService.getParkingSites();
      if (mounted) {
        setState(() {
          _parkingSites = sites;
          _isLoadingSites = false;
        });
      }
    } catch (e, st) {
      ErrorUtils.logError('DashboardScreen._loadParkingSites', e, st);
      if (!mounted) return;
      setState(() => _isLoadingSites = false);
      final message = e is ApiException ? e.message : ErrorUtils.friendlyMessage(e);
      final retryable = e is ApiException ? e.error.retryable : true;
      ErrorUtils.showErrorSnack(context, message, onRetry: retryable ? _loadParkingSites : null);
    }
  }

  Future<void> _loadActiveBooking() async {
    if (!mounted) return;
    setState(() => _isLoadingActiveBooking = true);
    try {
      final bookings = await ApiService.getBookings();
      if (mounted) {
        final active = bookings.firstWhere(
          (b) {
            final status = (b['status'] ?? '').toString().toLowerCase();
            return status == 'active' || status == 'pending' || status == 'confirmed';
          },
          orElse: () => null,
        );
        setState(() {
          _activeBooking = active;
          _isLoadingActiveBooking = false;
        });
      }
    } catch (e, st) {
      // Active-booking card is a nice-to-have on the home tab — degrade
      // quietly (log only) rather than interrupt the whole dashboard.
      ErrorUtils.logError('DashboardScreen._loadActiveBooking', e, st);
      if (mounted) setState(() => _isLoadingActiveBooking = false);
    }
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      _loadParkingSites(),
      _loadActiveBooking(),
    ]);
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.of(context).bgBase,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _HomeTab(
            user: _user,
            greeting: _greeting,
            parkingSites: _parkingSites,
            isLoading: _isLoadingSites,
            onRefresh: _onRefresh,
            fadeAnim: _fadeAnim,
            slideAnim: _slideAnim,
            activeBooking: _activeBooking,
            isLoadingActiveBooking: _isLoadingActiveBooking,
          ),
          const MyBookingsScreen(),
          const BookParkingTab(),
          const WalletScreen(),
          ProfileScreen(
            user: _user,
            onLogout: _logout,
            onProfileUpdated: _loadUserData,
          ),
        ],
      ),
      bottomNavigationBar: _PremiumBottomNav(
        selectedIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PREMIUM BOTTOM NAVIGATION
// ═══════════════════════════════════════════════════════════════

class _PremiumBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _PremiumBottomNav({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
return Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.of(context).bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border(top: BorderSide(color: AppColors.of(context).border, width: 0.5)),
        boxShadow: AppShadows.bottomNav,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                isActive: selectedIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.bookmark_border_rounded,
                activeIcon: Icons.bookmark_rounded,
                label: 'Bookings',
                isActive: selectedIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavBookButton(
                isActive: selectedIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.account_balance_wallet_outlined,
                activeIcon: Icons.account_balance_wallet_rounded,
                label: 'Wallet',
                isActive: selectedIndex == 3,
                onTap: () => onTap(3),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                isActive: selectedIndex == 4,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    )
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppConstants.durationNormal,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.25),
                          blurRadius: 10,
                        ),
                      ]
                    : [],
              ),
              child: Icon(
                isActive ? activeIcon : icon,
                color: isActive ? AppColors.primary : AppColors.of(context).textHint,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : AppColors.of(context).textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBookButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  const _NavBookButton({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.primaryGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.local_parking_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Book',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isActive ? AppColors.primary : AppColors.of(context).textHint,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  HOME TAB — Premium Minimal
// ═══════════════════════════════════════════════════════════════

class _HomeTab extends StatelessWidget {
  final UserModel? user;
  final String greeting;
  final List<dynamic> parkingSites;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final Animation<double> fadeAnim;
  final Animation<Offset> slideAnim;
  final Map<String, dynamic>? activeBooking;
  final bool isLoadingActiveBooking;

  const _HomeTab({
    required this.user,
    required this.greeting,
    required this.parkingSites,
    required this.isLoading,
    required this.onRefresh,
    required this.fadeAnim,
    required this.slideAnim,
    required this.activeBooking,
    required this.isLoadingActiveBooking,
  });

  @override
  Widget build(BuildContext context) {
return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      backgroundColor: AppColors.of(context).bgCard,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: SlideTransition(
              position: slideAnim,
              child: FadeTransition(
                opacity: fadeAnim,
                child: _PremiumHeader(
                  userName: user?.fullName?.split(' ').first ?? 'User',
                  initials: user?.initials ?? 'U',
                  greeting: greeting,
                ),
              ),
            ),
          ),

          // ✅ Small spacing after header
          const SliverToBoxAdapter(child: SizedBox(height: 6)),

          if (isLoadingActiveBooking || activeBooking != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: isLoadingActiveBooking
                    ? const _ShimmerCard(height: 120)
                    : _ActiveBookingCard(booking: activeBooking!, onRefresh: onRefresh),
              ),
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Available Parking',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.of(context).textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    '${parkingSites.length} locations',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.of(context).textHint,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isLoading)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: const _ShimmerCard(height: 180),
                  ),
                  childCount: 3,
                ),
              ),
            )
          else if (parkingSites.isEmpty)
            const SliverToBoxAdapter(child: _PremiumEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => SpringSlideIn(
                    delay: Duration(milliseconds: 60 * index),
                    child: _PremiumParkingCard(site: parkingSites[index], onRefresh: onRefresh),
                  ),
                  childCount: parkingSites.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PREMIUM HEADER — With Background Image + Reduced Blur
// ═══════════════════════════════════════════════════════════════

class _PremiumHeader extends StatelessWidget {
  final String userName, initials, greeting;

  const _PremiumHeader({
    required this.userName,
    required this.initials,
    required this.greeting,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.of(context);

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: Container(
        height: 210,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1A2340),
                    const Color(0xFF252060),
                  ]
                : [
                    AppColors.primary,
                    AppColors.gradientEnd,
                  ],
          ),
        ),
        child: Stack(
          children: [
            // Subtle pattern overlay
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              right: 40,
              bottom: -40,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Book parking in seconds', // ✅ Changed subtitle
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MyPassesScreen()),
                      ),
                      child: Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25),
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.card_membership_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                      ),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25),
                          ),
                        ),
                        child: Stack(
                          children: [
                            const Center(
                              child: Icon(
                                Icons.notifications_outlined,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppColors.warning,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.primaryGradient,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
     )
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ACTIVE BOOKING CARD — Slower Pulse Animation
// ═══════════════════════════════════════════════════════════════

class _ActiveBookingCard extends StatefulWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onRefresh;
  const _ActiveBookingCard({required this.booking, required this.onRefresh});

  @override
  State<_ActiveBookingCard> createState() => _ActiveBookingCardState();
}

class _ActiveBookingCardState extends State<_ActiveBookingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200), // ✅ Slower pulse (was 1500)
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
final siteName = widget.booking['parking_site_name']?.toString() ??
        widget.booking['site_name']?.toString() ??
        'Parking Site';
    final slotLabel = widget.booking['slot_number']?.toString() ??
        widget.booking['parking_slot_detail']?['slot_number']?.toString() ??
        widget.booking['slot_label']?.toString() ??
        widget.booking['slot']?.toString() ??
        '--';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.success.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.success.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1 + _pulseAnim.value * 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.success.withOpacity(0.2 + _pulseAnim.value * 0.15),
                ),
              ),
              child: const Icon(
                Icons.directions_car_rounded,
                color: AppColors.success,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withOpacity(0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Active Booking',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  siteName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.of(context).textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Slot $slotLabel',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.of(context).textSecondary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
              );
              if (context.mounted) widget.onRefresh();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withOpacity(0.2)),
              ),
              child: const Text(
                'Track',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
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
//  PREMIUM PARKING CARD — Reduced Glow + Smaller Button
// ═══════════════════════════════════════════════════════════════

class _PremiumParkingCard extends StatefulWidget {
  final Map<String, dynamic> site;
  final VoidCallback onRefresh;
  const _PremiumParkingCard({required this.site, required this.onRefresh});

  @override
  State<_PremiumParkingCard> createState() => _PremiumParkingCardState();
}

class _PremiumParkingCardState extends State<_PremiumParkingCard>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails details) {
    HapticFeedback.selectionClick();
    setState(() => _scale = 0.97);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _scale = 1.0);
  }

  void _onTapCancel() {
    setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
final name = widget.site['name']?.toString() ?? 'Parking Lot';
    final address = widget.site['address']?.toString() ??
        widget.site['location']?.toString() ??
        'Location not set';
    final available = widget.site['available_slots'];
    final rate = widget.site['rate_per_hour']?.toString() ?? '0';
    // Per-slot pricing: rate = site ki cheapest slot price ("From ₨ X").
    final isHourly =
        (widget.site['pricing_type']?.toString() ?? 'flat') == 'hourly';
    final availableCount = available is int
        ? available
        : int.tryParse(available?.toString() ?? '0') ?? 0;
    final bool hasSlots = availableCount > 0;

    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BookSlotScreen(site: widget.site)),
            );
            if (context.mounted) widget.onRefresh();
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.of(context).bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.of(context).border, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Reduced top height (80 → 70)
                Container(
                  height: 70,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withOpacity(0.15),
                        AppColors.primaryDark.withOpacity(0.08),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: -30,
                        bottom: -30,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.03),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -20,
                        top: -20,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withOpacity(0.08),
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.2),
                              width: 1,
                            ),
                            // ✅ Reduced glow (blurRadius: 18 → 8, spreadRadius: 1 → 0)
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.25),
                                blurRadius: 8,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.local_parking_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: hasSlots
                                ? AppColors.success.withOpacity(0.9)
                                : AppColors.danger.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            hasSlots ? '$availableCount spots' : 'Full',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.of(context).textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: AppColors.of(context).textHint,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              address,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.of(context).textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            size: 14,
                            color: AppColors.of(context).textHint,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rate == '0' || rate == 'null'
                                ? 'Rate not set'
                                : 'From ₨ $rate${isHourly ? '/hour' : ''}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const Spacer(),
                          if (hasSlots)
                            Container(
                              // ✅ Reduced button size (horizontal: 16→14, vertical: 8→7)
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: AppColors.primaryGradient,
                                ),
                                borderRadius: BorderRadius.circular(11),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Book Now',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.of(context).bgElevated,
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(color: AppColors.of(context).border),
                              ),
                              child: Text(
                                'Unavailable',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.of(context).textHint,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PREMIUM EMPTY STATE
// ═══════════════════════════════════════════════════════════════

class _PremiumEmptyState extends StatelessWidget {
  const _PremiumEmptyState();

  @override
  Widget build(BuildContext context) {
return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 60),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withOpacity(0.15),
                    AppColors.primaryDark.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.of(context).border),
              ),
              child: Icon(
                Icons.local_parking_outlined,
                size: 48,
                color: AppColors.of(context).textHint,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No parking sites found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.of(context).textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pull down to refresh',
              style: TextStyle(fontSize: 13, color: AppColors.of(context).textHint),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SHIMMER SKELETON
// ═══════════════════════════════════════════════════════════════

class _ShimmerCard extends StatefulWidget {
  final double height;
  const _ShimmerCard({required this.height});

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
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
return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + _anim.value * 3.0, 0),
              end: Alignment(0 + _anim.value * 3.0, 0),
              colors: [
                AppColors.of(context).bgCard,
                AppColors.of(context).bgElevated,
                AppColors.of(context).bgCard,
              ],
            ),
          ),
        );
      },
    );
  }
}