import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';
import '../../api_service.dart';
import '../../utils/error_utils.dart';
import '../../widgets/common/pk_skeleton.dart';
import '../../widgets/common/micro_animations.dart';
import 'book_slot_screen.dart';

class BookParkingTab extends StatefulWidget {
  const BookParkingTab({super.key});

  @override
  State<BookParkingTab> createState() => _BookParkingTabState();
}

class _BookParkingTabState extends State<BookParkingTab>
    with TickerProviderStateMixin {
  List<dynamic> _sites = [];
  bool _isLoading = true;
  String _search = '';
  String _activeFilter = 'All';

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  final List<String> _filters = ['All', 'Available', 'Full'];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadSites();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSites() async {
    _fadeCtrl.reset();

    setState(() => _isLoading = true);

    try {
      final sites = await ApiService.getParkingSites();
      if (mounted) {
        setState(() {
          _sites = sites;
          _isLoading = false;
        });
        _fadeCtrl.forward();
      }
    } catch (e, st) {
      ErrorUtils.logError('BookParkingTab._loadSites', e, st);
      if (!mounted) return;
      setState(() => _isLoading = false);
      final message = e is ApiException ? e.message : ErrorUtils.friendlyMessage(e);
      final retryable = e is ApiException ? e.error.retryable : true;
      ErrorUtils.showErrorSnack(context, message, onRetry: retryable ? _loadSites : null);
    }
  }

  List<dynamic> get _filteredSites {
    var result = _sites;

    if (_activeFilter == 'Available') {
      result = result.where((s) {
        final a = s['available_slots'];
        final count = a is int ? a : int.tryParse(a?.toString() ?? '0') ?? 0;
        return count > 0;
      }).toList();
    } else if (_activeFilter == 'Full') {
      result = result.where((s) {
        final a = s['available_slots'];
        final count = a is int ? a : int.tryParse(a?.toString() ?? '0') ?? 0;
        return count == 0;
      }).toList();
    }

    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase();
      result = result.where((s) {
        final name = s['name']?.toString().toLowerCase() ?? '';
        final addr = s['address']?.toString().toLowerCase() ?? '';
        return name.contains(q) || addr.contains(q);
      }).toList();
    }
    return result;
  }

  int get _availableCount => _sites.where((s) {
        final a = s['available_slots'];
        final count = a is int ? a : int.tryParse(a?.toString() ?? '0') ?? 0;
        return count > 0;
      }).length;

  @override
  Widget build(BuildContext context) {
final colors = AppColors.of(context);
    final filtered = _filteredSites;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: colors.bgBase,
      body: Column(
        children: [
          // ── Premium Header ──
          Padding(
            padding: EdgeInsets.only(top: topPadding + 16, left: 20, right: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Find Parking',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.of(context).textPrimary,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isLoading ? 'Loading...' : '$_availableCount locations available',
                      style: TextStyle(fontSize: 13, color: colors.textHint),
                    ),
                  ],
                ),
                // Premium refresh button with shadow
                GestureDetector(
                  onTap: _loadSites,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.bgCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.border.withOpacity(0.4)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(Icons.refresh_rounded, size: 18, color: AppColors.of(context).textHint),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Premium Search Bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: colors.bgCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border.withOpacity(0.35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(Icons.search_rounded, size: 20, color: AppColors.of(context).textHint),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      textAlignVertical: TextAlignVertical.center,
                      style: TextStyle(fontSize: 15, color: colors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Search by name or area',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_search.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _search = ''),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Icon(Icons.close_rounded, size: 18, color: colors.textHint),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Premium Filter Chips ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isActive = _activeFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => setState(() => _activeFilter = filter),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: isActive
                              ? const LinearGradient(colors: AppColors.primaryGradient)
                              : null,
                          color: isActive ? null : colors.bgCard,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: isActive ? Colors.transparent : colors.border,
                          ),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isActive ? Colors.white : colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Sites List ──
          Expanded(
            child: _isLoading
                ? PkSkeletonList(
                    count: 4,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemBuilder: () => PkSkeletonCard(height: 160),
                  )
                : filtered.isEmpty
                    ? _EmptyState(hasSearch: _search.isNotEmpty || _activeFilter != 'All')
                    : FadeTransition(
                        opacity: _fadeAnim,
                        child: RefreshIndicator(
                          onRefresh: _loadSites,
                          color: AppColors.primary,
                          backgroundColor: colors.bgCard,
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) => SpringSlideIn(
                              delay: Duration(milliseconds: 50 * index),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _PremiumSiteCard(site: filtered[index]),
                              ),
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
//  PREMIUM SITE CARD — Micro-Polished, Production-Ready
// ═══════════════════════════════════════════════════════════════

class _PremiumSiteCard extends StatefulWidget {
  final Map<String, dynamic> site;

  const _PremiumSiteCard({required this.site});

  @override
  State<_PremiumSiteCard> createState() => _PremiumSiteCardState();
}

class _PremiumSiteCardState extends State<_PremiumSiteCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.98,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = CurvedAnimation(
      parent: _scaleCtrl,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  int get _availableCount {
    final a = widget.site['available_slots'];
    return a is int ? a : int.tryParse(a?.toString() ?? '0') ?? 0;
  }

  int get _totalCount {
    final t = widget.site['total_slots'];
    return t is int ? t : int.tryParse(t?.toString() ?? '0') ?? 0;
  }

  bool get _hasSlots => _availableCount > 0;

  @override
  Widget build(BuildContext context) {
final colors = AppColors.of(context);
    final name = widget.site['name']?.toString() ?? 'Parking Lot';
    final address = widget.site['address']?.toString() ??
        widget.site['location']?.toString() ??
        'Location not set';
    final rate = widget.site['rate_per_hour']?.toString() ?? '0';
    // Per-slot pricing: rate ab site ki cheapest slot price hai, is liye
    // "From" ke saath dikhate hain. Flat sites pe ye base price hoti hai.
    final isHourly =
        (widget.site['pricing_type']?.toString() ?? 'flat') == 'hourly';

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnim.value,
        child: child,
      ),
      child: InkWell(
        onTapDown: (_) => _scaleCtrl.reverse(),
        onTapUp: (_) => _scaleCtrl.forward(),
        onTapCancel: () => _scaleCtrl.forward(),
        onTap: _hasSlots
            ? () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BookSlotScreen(site: widget.site)),
              )
            : null,
        borderRadius: BorderRadius.circular(20),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.045),
                blurRadius: 24,
                spreadRadius: -2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _hasSlots ? AppColors.primary.withOpacity(0.08) : colors.bgInput,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.local_parking_rounded,
                      color: _hasSlots ? AppColors.primary : colors.textHint,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _hasSlots ? colors.textPrimary : colors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: _hasSlots ? AppColors.success : AppColors.danger,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _hasSlots ? 'Available' : 'Full',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _hasSlots ? AppColors.success : AppColors.danger,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 13, color: colors.textHint),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address,
                                style: TextStyle(fontSize: 12, color: colors.textHint),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '$_availableCount / $_totalCount available',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(Icons.payments_outlined, size: 16, color: colors.textHint),
                  const SizedBox(width: 6),
                  Text(
                    rate == '0' || rate == 'null'
                        ? 'Price unavailable'
                        : 'From ₨ $rate${isHourly ? ' / hour' : ''}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  if (_hasSlots)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primaryDark,
                            AppColors.primaryDark,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Book',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                        ],
                      ),
                    )
                  else
                    Text(
                      'Full',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.textHint),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  EMPTY STATE
// ═══════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final bool hasSearch;

  const _EmptyState({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
final colors = AppColors.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colors.bgCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.border),
              ),
              child: Icon(
                hasSearch ? Icons.search_off_rounded : Icons.local_parking_outlined,
                size: 36,
                color: colors.textHint,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasSearch ? 'No results found' : 'No parking sites',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              hasSearch
                  ? 'Try a different name or clear filters'
                  : 'Pull down to refresh',
              style: TextStyle(fontSize: 13, color: colors.textHint),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}