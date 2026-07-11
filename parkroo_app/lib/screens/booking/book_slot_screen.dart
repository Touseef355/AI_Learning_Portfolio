import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api_service.dart';
import '../../utils/error_utils.dart';
import '../../models/vehicle_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';
import '../payment/payment_webview_screen.dart';
import '../../services/payment/payment_service.dart';
import '../../services/payment/payment_gateway_interface.dart';

class BookSlotScreen extends StatefulWidget {
  final Map<String, dynamic> site;
  const BookSlotScreen({super.key, required this.site});

  @override
  State<BookSlotScreen> createState() => _BookSlotScreenState();
}

class _BookSlotScreenState extends State<BookSlotScreen>
    with TickerProviderStateMixin {
  List<dynamic> _slots = [];
  List<VehicleModel> _vehicles = [];
  bool _isLoading = true;
  String? _selectedSlotId;
  String? _selectedSlotNumber;
  String? _selectedSlotType;
  VehicleModel? _selectedVehicle;
  DateTime _entryTime = DateTime.now().add(const Duration(minutes: 2));
  DateTime _exitTime = DateTime.now().add(const Duration(hours: 2, minutes: 2));
  bool _isBooking = false;

  late final AnimationController _staggerCtrl;
  late final Animation<double> _headerFade;
  late final Animation<double> _slotsFade;
  late final Animation<double> _vehicleFade;
  late final Animation<double> _timeFade;
  late final Animation<double> _summaryFade;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _headerFade = CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    );
    _slotsFade = CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.1, 0.4, curve: Curves.easeOut),
    );
    _vehicleFade = CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
    );
    _timeFade = CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.3, 0.6, curve: Curves.easeOut),
    );
    _summaryFade = CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
    );

    _loadData();
    _staggerCtrl.forward();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final siteId = widget.site['id']?.toString() ?? '';
    try {
      final slots = await ApiService.getSlots(siteId);
      final vehicles = await ApiService.getVehicles();
      if (mounted) {
        setState(() {
          _slots = slots;
          _vehicles = vehicles.map((v) => VehicleModel.fromJson(v)).toList();
          if (_vehicles.isNotEmpty) _selectedVehicle = _vehicles.first;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      ErrorUtils.logError('BookSlotScreen._loadData', e, st);
      if (!mounted) return;
      setState(() => _isLoading = false);
      final message = e is ApiException ? e.message : ErrorUtils.friendlyMessage(e);
      final retryable = e is ApiException ? e.error.retryable : true;
      ErrorUtils.showErrorSnack(context, message, onRetry: retryable ? _loadData : null);
    }
  }

  Future<void> _pickEntryTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _entryTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
          dialogBackgroundColor: AppColors.of(context).bgCard,
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_entryTime),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
          dialogBackgroundColor: AppColors.of(context).bgCard,
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    setState(() {
      _entryTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (_exitTime.isBefore(_entryTime)) {
        _exitTime = _entryTime.add(const Duration(hours: 2));
      }
    });
    _fetchEstimate();
  }

  Future<void> _pickExitTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _exitTime,
      firstDate: _entryTime,
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
          dialogBackgroundColor: AppColors.of(context).bgCard,
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_exitTime),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
          dialogBackgroundColor: AppColors.of(context).bgCard,
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    setState(() {
      _exitTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
    _fetchEstimate();
  }

  String get _duration {
    final diff = _exitTime.difference(_entryTime);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  int _estimatedPrice = 0;
  bool _priceLoading = false;
  int _priceRequestId = 0; // guards against stale/out-of-order responses

  Future<void> _fetchEstimate() async {
    if (_selectedSlotId == null) {
      setState(() => _estimatedPrice = 0);
      return;
    }
    final requestId = ++_priceRequestId;
    setState(() => _priceLoading = true);
    final res = await ApiService.estimateBookingPrice(
      slotId: _selectedSlotId!,
      entryTime: _entryTime,
      exitTime: _exitTime,
      vehicleId: _selectedVehicle?.id,
    );
    if (!mounted || requestId != _priceRequestId) return; // stale response, ignore
    setState(() {
      _priceLoading = false;
      if (res['error'] == null && res['estimated_amount'] != null) {
        _estimatedPrice =
            double.tryParse(res['estimated_amount'].toString())?.ceil() ??
                _estimatedPrice;
      }
      // On failure we simply keep the last known estimate rather than
      // showing 0 — a stale-but-close number beats a scary "Rs. 0".
    });
  }

  String _formatDateTime(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${months[dt.month - 1]}, $h:$m $ampm';
  }

  Future<void> _bookSlot() async {
    if (_selectedSlotId == null) {
      _showSnack('Please select a parking slot', isError: true);
      return;
    }
    if (_selectedVehicle == null) {
      _showSnack('Please select your vehicle', isError: true);
      return;
    }
    if (_exitTime.isBefore(_entryTime) || _exitTime == _entryTime) {
      _showSnack('Exit time must be after entry time', isError: true);
      return;
    }
    setState(() => _isBooking = true);
    final result = await ApiService.createBooking(
      parkingSlotId: _selectedSlotId!,
      vehicleId: _selectedVehicle!.id,
      entryTime: _entryTime,
      exitTime: _exitTime,
    );
    if (!mounted) return;
    setState(() => _isBooking = false);
    if (result['id'] != null) {
      HapticFeedback.heavyImpact();
      _showPaymentSheet(result); // ← payment sheet pehle
    } else {
      _showSnack(
        ErrorUtils.messageFrom(result, fallback: 'Booking failed. Try again.'),
        isError: true,
      );
    }
  }

  // ── Payment Method Sheet ────────────────────────────────────
  void _showPaymentSheet(Map<String, dynamic> booking) {
    final bookingId = booking['id']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.of(context).bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppColors.of(context).border.withOpacity(0.5)),
        ),
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(context).padding.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.of(context).border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Complete Payment',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.of(context).textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '₨ $_estimatedPrice  •  Slot $_selectedSlotNumber',
              style: TextStyle(
                  fontSize: 13, color: AppColors.of(context).textHint),
            ),
            const SizedBox(height: 24),

            // ── Wallet ──────────────────────────────────────
            _PaymentOption(
              icon: Icons.account_balance_wallet_rounded,
              title: 'Pay with Wallet',
              subtitle: 'Instant deduction from balance',
              color: AppColors.primary,
              onTap: () async {
                Navigator.pop(context);
                setState(() => _isBooking = true);
                final res = await ApiService.deductWallet(
                  bookingId: bookingId,
                  amount: _estimatedPrice.toDouble(),
                );
                if (!mounted) return;
                setState(() => _isBooking = false);
                if (res['error'] == null) {
                  _showSuccessSheet(booking);
                } else {
                  _showSnack(ErrorUtils.messageFrom(res, fallback: 'Payment failed'), isError: true);
                }
              },
            ),
            const SizedBox(height: 12),

            // ── Online (EasyPaisa / Card) ────────────────────
            _PaymentOption(
              icon: Icons.payment_rounded,
              title: 'Pay Online',
              subtitle: 'EasyPaisa / Card',
              color: AppColors.success,
              onTap: () async {
                Navigator.pop(context);
                final paymentService = getPaymentService();
                PaymentInitResult initResult;
                try {
                  initResult = await paymentService.initiateTopUp(
                    amount: _estimatedPrice.toDouble(),
                    userEmail: ApiService.currentUser?.email ?? '',
                  );
                } catch (e, st) {
                  ErrorUtils.logError('BookSlotScreen.initiateTopUp', e, st);
                  if (!mounted) return;
                  _showSnack(ErrorUtils.friendlyMessage(e), isError: true);
                  return;
                }
                if (!mounted) return;
                if (!initResult.success) {
                  _showSnack(initResult.error ?? 'Failed to initiate payment',
                      isError: true);
                  return;
                }
               final paid = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => PaymentWebViewScreen(
                    amount: _estimatedPrice.toDouble(),
                    paymentUrl: initResult.paymentUrl ?? '',
                    transactionId: initResult.transactionId ?? '',
                  ),
                ),
              );

                if (paid == true) {
                  if (!mounted) return;

                  setState(() => _isBooking = true);

                  final res = await ApiService.deductWallet(
                    bookingId: bookingId,
                    amount: _estimatedPrice.toDouble(),
                  );

                  if (!mounted) return;

                  setState(() => _isBooking = false);

                  if (res['error'] == null) {
                    _showSuccessSheet(booking);
                  } else {
                    _showSnack(
                      ErrorUtils.messageFrom(res, fallback: 'Unable to confirm booking'),
                      isError: true,
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: 16),
        const SizedBox(width: 8),
        Expanded(
            child: Text(msg,
                style:
                    const TextStyle(fontSize: 13, color: Colors.white))),
      ]),
      backgroundColor: isError ? AppColors.danger : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _showSuccessSheet(Map<String, dynamic> booking) {
    final bookingId = booking['id']?.toString() ?? '—';
    final shortId = bookingId.length > 8
        ? bookingId.substring(0, 8).toUpperCase()
        : bookingId.toUpperCase();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PremiumSuccessSheet(
        shortId: shortId,
        slotNumber: _selectedSlotNumber ?? '—',
        siteName: widget.site['name']?.toString() ?? 'Parking',
        entryTime: _formatDateTime(_entryTime),
        exitTime: _formatDateTime(_exitTime),
        estimatedPrice: _estimatedPrice,
        onDone: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── Per-slot pricing display helpers ─────────────────────────────
  // Pricing ab har slot pe hai: hourly site -> slot ka Rate/Hour,
  // flat site -> slot ki Base Price (first N hours ka total).
  bool get _isHourly =>
      (widget.site['pricing_type']?.toString() ?? 'flat') == 'hourly';

  int get _flatHours =>
      int.tryParse(widget.site['flat_hours']?.toString() ?? '') ?? 4;

  double? _slotPrice(dynamic slot) =>
      double.tryParse(slot?['price_per_hour']?.toString() ?? '');

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  /// Selected slot ki price — na select ho to null.
  double? get _selectedSlotPrice {
    if (_selectedSlotId == null) return null;
    for (final s in _slots) {
      if (s['id']?.toString() == _selectedSlotId) return _slotPrice(s);
    }
    return null;
  }

  /// Header ke liye: sab slots me se sasti price ("From ₨ X").
  double? get _cheapestSlotPrice {
    double? min;
    for (final s in _slots) {
      final p = _slotPrice(s);
      if (p != null && (min == null || p < min)) min = p;
    }
    return min;
  }

  @override
  Widget build(BuildContext context) {
    final siteName = widget.site['name']?.toString() ?? 'Parking';
    final siteAddress = widget.site['address']?.toString() ?? '';
    final freeCount =
        _slots.where((s) => s['is_occupied'] != true).length;

    // Header badge: cheapest slot se "From ₨ X" (fallback: backend ka
    // rate_per_hour jo ab khud cheapest-slot price return karta hai).
    final cheapest = _cheapestSlotPrice ??
        double.tryParse(widget.site['rate_per_hour']?.toString() ?? '');
    final headerRateText = cheapest == null || cheapest == 0
        ? 'Price unavailable'
        : (_isHourly
            ? 'From ₨ ${_fmt(cheapest)}/hr'
            : 'From ₨ ${_fmt(cheapest)} · $_flatHours hrs');

    // Invoice card: selected slot ki apni price.
    final slotPrice = _selectedSlotPrice;
    final invoiceRateText = slotPrice == null
        ? 'Select a slot'
        : (_isHourly
            ? '₨ ${_fmt(slotPrice)} / hour'
            : '₨ ${_fmt(slotPrice)} · first $_flatHours hrs');

    return Scaffold(
      backgroundColor: AppColors.of(context).bgBase,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                FadeTransition(
                  opacity: _headerFade,
                  child: _PremiumHeroHeader(
                    siteName: siteName,
                    siteAddress: siteAddress,
                    rateText: headerRateText,
                    freeCount: freeCount,
                    onBack: () => Navigator.pop(context),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        FadeTransition(
                          opacity: _slotsFade,
                          child: _PremiumSlotGrid(
                            slots: _slots,
                            selectedSlotId: _selectedSlotId,
                            selectedSlotNumber: _selectedSlotNumber,
                            selectedSlotType: _selectedSlotType,
                            onSlotSelected: (id, number, type) {
                              setState(() {
                                _selectedSlotId = id;
                                _selectedSlotNumber = number;
                                _selectedSlotType = type;
                              });
                              _fetchEstimate();
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        FadeTransition(
                          opacity: _vehicleFade,
                          child: _PremiumVehicleCarousel(
                            vehicles: _vehicles,
                            selectedVehicle: _selectedVehicle,
                            onVehicleSelected: (v) {
                              setState(() => _selectedVehicle = v);
                              _fetchEstimate();
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        FadeTransition(
                          opacity: _timeFade,
                          child: _PremiumTimeSection(
                            entryTime: _formatDateTime(_entryTime),
                            exitTime: _formatDateTime(_exitTime),
                            onEntryTap: _pickEntryTime,
                            onExitTap: _pickExitTime,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FadeTransition(
                          opacity: _summaryFade,
                          child: _PremiumInvoiceCard(
                            slotNumber: _selectedSlotNumber,
                            slotType: _selectedSlotType,
                            duration: _duration,
                            rateText: invoiceRateText,
                            estimatedPrice: _estimatedPrice,
                            priceLoading: _priceLoading,
                            entryTime: _entryTime,
                          ),
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomSheet: _PremiumConfirmButton(
        isBooking: _isBooking || _priceLoading,
        hasSlot: _selectedSlotId != null,
        estimatedPrice: _estimatedPrice,
        onConfirm: _bookSlot,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PAYMENT OPTION TILE
// ═══════════════════════════════════════════════════════════════

class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.of(context).bgElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.of(context).border),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.of(context).textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.of(context).textHint),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: AppColors.of(context).textHint),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PREMIUM HERO HEADER
// ═══════════════════════════════════════════════════════════════

class _PremiumHeroHeader extends StatelessWidget {
  final String siteName, siteAddress, rateText;
  final int freeCount;
  final VoidCallback onBack;

  const _PremiumHeroHeader({
    required this.siteName,
    required this.siteAddress,
    required this.rateText,
    required this.freeCount,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(28)),
          child: Stack(
            children: [
              Container(
                height: 220,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: AppColors.primaryGradient,
                  ),
                ),
              ),
              Container(
                height: 220,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onBack,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.2)),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        size: 20, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  siteName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded,
                        size: 14,
                        color: Colors.white.withOpacity(0.6)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        siteAddress,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.6)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.success.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              size: 12, color: AppColors.success),
                          const SizedBox(width: 4),
                          Text(
                            '$freeCount Available',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Text(
                        rateText,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PREMIUM SLOT GRID
// ═══════════════════════════════════════════════════════════════

class _PremiumSlotGrid extends StatelessWidget {
  final List<dynamic> slots;
  final String? selectedSlotId;
  final String? selectedSlotNumber;
  final String? selectedSlotType;
  final Function(String, String, String) onSlotSelected;

  const _PremiumSlotGrid({
    required this.slots,
    required this.selectedSlotId,
    required this.selectedSlotNumber,
    required this.selectedSlotType,
    required this.onSlotSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'SELECT A SLOT',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.of(context).textHint,
                letterSpacing: 1),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: slots.length,
            itemBuilder: (context, index) {
              final slot = slots[index] as Map<String, dynamic>;
              final slotId = slot['id']?.toString() ?? '';
              final slotNum = slot['slot_number']?.toString() ?? '?';
              final isOccupied = slot['is_occupied'] == true;
              final type = slot['slot_type']?.toString() ?? 'normal';
              final isSelected = selectedSlotId == slotId;

              Color getSlotColor() {
                if (isSelected) return AppColors.primary;
                if (isOccupied) return AppColors.danger;
                if (type == 'vip') return AppColors.warning;
                return AppColors.success;
              }

              return AnimatedScale(
                scale: isSelected ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: GestureDetector(
                  onTap: isOccupied
                      ? null
                      : () => onSlotSelected(slotId, slotNum, type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: AppColors.primaryGradient)
                          : null,
                      color: isSelected
                          ? null
                          : (isOccupied
                              ? AppColors.danger.withOpacity(0.08)
                              : AppColors.of(context).bgCard),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : getSlotColor().withOpacity(0.3),
                        width: isSelected ? 0 : 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                  color:
                                      AppColors.primary.withOpacity(0.4),
                                  blurRadius: 16,
                                  spreadRadius: 1)
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : isOccupied
                                  ? Icons.block_rounded
                                  : type == 'vip'
                                      ? Icons.star_rounded
                                      : Icons.local_parking_rounded,
                          size: 22,
                          color: isSelected
                              ? Colors.white
                              : isOccupied
                                  ? AppColors.danger.withOpacity(0.5)
                                  : getSlotColor(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          slotNum,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : (isOccupied
                                    ? AppColors.of(context).textHint
                                    : AppColors.of(context).textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PREMIUM VEHICLE CAROUSEL
// ═══════════════════════════════════════════════════════════════

class _PremiumVehicleCarousel extends StatelessWidget {
  final List<VehicleModel> vehicles;
  final VehicleModel? selectedVehicle;
  final ValueChanged<VehicleModel> onVehicleSelected;

  const _PremiumVehicleCarousel({
    required this.vehicles,
    required this.selectedVehicle,
    required this.onVehicleSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (vehicles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.of(context).bgCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.of(context).border),
          ),
          child: Row(
            children: [
              Icon(Icons.directions_car_outlined,
                  color: AppColors.of(context).textHint),
              const SizedBox(width: 12),
              Text('No vehicles registered',
                  style:
                      TextStyle(color: AppColors.of(context).textHint)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'SELECT VEHICLE',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.of(context).textHint,
                letterSpacing: 1),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final vehicle = vehicles[index];
              final isSelected = selectedVehicle?.id == vehicle.id;

              return GestureDetector(
                onTap: () => onVehicleSelected(vehicle),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 180,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: AppColors.primaryGradient)
                        : null,
                    color: isSelected
                        ? null
                        : AppColors.of(context).bgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : AppColors.of(context).border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withOpacity(0.15)
                              : AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.directions_car_rounded,
                          color: isSelected
                              ? Colors.white
                              : AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              vehicle.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.of(context).textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              vehicle.plateNumber,
                              style: TextStyle(
                                fontSize: 10,
                                color: isSelected
                                    ? Colors.white70
                                    : AppColors.of(context).textHint,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PREMIUM TIME SECTION
// ═══════════════════════════════════════════════════════════════

class _PremiumTimeSection extends StatelessWidget {
  final String entryTime, exitTime;
  final VoidCallback onEntryTap, onExitTap;

  const _PremiumTimeSection({
    required this.entryTime,
    required this.exitTime,
    required this.onEntryTap,
    required this.onExitTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'BOOKING TIME',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.of(context).textHint,
                letterSpacing: 1),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _GlassTimeCard(
                  label: 'ENTRY',
                  time: entryTime,
                  icon: Icons.login_rounded,
                  onTap: onEntryTap,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _GlassTimeCard(
                  label: 'EXIT',
                  time: exitTime,
                  icon: Icons.logout_rounded,
                  onTap: onExitTap,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassTimeCard extends StatelessWidget {
  final String label, time;
  final IconData icon;
  final VoidCallback onTap;

  const _GlassTimeCard({
    required this.label,
    required this.time,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.of(context).bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.of(context).border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.of(context).textHint),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              time,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.of(context).textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PREMIUM INVOICE CARD
// ═══════════════════════════════════════════════════════════════

class _PremiumInvoiceCard extends StatelessWidget {
  final String? slotNumber, slotType;
  final String duration, rateText;
  final int estimatedPrice;
  final bool priceLoading;
  final DateTime entryTime;

  const _PremiumInvoiceCard({
    required this.slotNumber,
    required this.slotType,
    required this.duration,
    required this.rateText,
    required this.estimatedPrice,
    this.priceLoading = false,
    required this.entryTime,
  });

  String get _dateLabel {
    final now = DateTime.now();
    if (entryTime.day == now.day &&
        entryTime.month == now.month &&
        entryTime.year == now.year) return 'Today';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${entryTime.day} ${months[entryTime.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'INVOICE SUMMARY',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.of(context).textHint,
                letterSpacing: 1),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.of(context).bgCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.of(context).border),
            ),
            child: Column(
              children: [
                _InvoiceRow(
                    label: 'Selected Slot',
                    value: slotNumber != null
                        ? 'Slot $slotNumber'
                        : 'Not selected'),
                Divider(
                    height: 20,
                    color: AppColors.of(context).border),
                _InvoiceRow(label: 'Duration', value: duration),
                Divider(
                    height: 20,
                    color: AppColors.of(context).border),
                _InvoiceRow(label: 'Date', value: _dateLabel),
                Divider(
                    height: 20,
                    color: AppColors.of(context).border),
                _InvoiceRow(
                    label: 'Rate',
                    value: rateText),
                Divider(
                    height: 20,
                    color: AppColors.of(context).border),
                Container(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Amount',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.of(context).textPrimary),
                      ),
                      priceLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.success),
                            )
                          : Text(
                              '₨ $estimatedPrice',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.success),
                            ),
                    ],
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

class _InvoiceRow extends StatelessWidget {
  final String label, value;
  const _InvoiceRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: AppColors.of(context).textHint)),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.of(context).textPrimary)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PREMIUM CONFIRM BUTTON
// ═══════════════════════════════════════════════════════════════

class _PremiumConfirmButton extends StatelessWidget {
  final bool isBooking, hasSlot;
  final int estimatedPrice;
  final VoidCallback onConfirm;

  const _PremiumConfirmButton({
    required this.isBooking,
    required this.hasSlot,
    required this.estimatedPrice,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: AppColors.of(context).bgCard,
        border:
            Border(top: BorderSide(color: AppColors.of(context).border)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, -4)),
        ],
      ),
      child: GestureDetector(
        onTap: isBooking ? null : onConfirm,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          decoration: BoxDecoration(
            gradient: hasSlot
                ? const LinearGradient(
                    colors: AppColors.primaryGradient)
                : null,
            color:
                hasSlot ? null : AppColors.of(context).bgElevated,
            borderRadius: BorderRadius.circular(24),
            boxShadow: hasSlot
                ? [
                    BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 2)
                  ]
                : [],
          ),
          child: Center(
            child: isBooking
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        hasSlot
                            ? 'Confirm Booking'
                            : 'Select a slot to continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: hasSlot
                              ? Colors.white
                              : AppColors.of(context).textHint,
                        ),
                      ),
                      if (hasSlot) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded,
                            size: 18, color: Colors.white),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PREMIUM SUCCESS SHEET
// ═══════════════════════════════════════════════════════════════

class _PremiumSuccessSheet extends StatefulWidget {
  final String shortId, slotNumber, siteName, entryTime, exitTime;
  final int estimatedPrice;
  final VoidCallback onDone;

  const _PremiumSuccessSheet({
    required this.shortId,
    required this.slotNumber,
    required this.siteName,
    required this.entryTime,
    required this.exitTime,
    required this.estimatedPrice,
    required this.onDone,
  });

  @override
  State<_PremiumSuccessSheet> createState() =>
      _PremiumSuccessSheetState();
}

class _PremiumSuccessSheetState extends State<_PremiumSuccessSheet>
    with TickerProviderStateMixin {
  late AnimationController _checkCtrl;
  late Animation<double> _checkScale;
  late Animation<double> _checkOpacity;

  late AnimationController _glowCtrl;
  late Animation<double> _glowScale;
  late Animation<double> _glowOpacity;

  late AnimationController _contentCtrl;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;
  late Animation<double> _detailsFade;
  late Animation<Offset> _detailsSlide;
  late Animation<double> _btnFade;
  late Animation<Offset> _btnSlide;

  @override
  void initState() {
    super.initState();

    _checkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut));
    _checkOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _checkCtrl,
            curve: const Interval(0.0, 0.4, curve: Curves.easeOut)));

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _glowScale = Tween<double>(begin: 0.5, end: 2.2).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeOut));
    _glowOpacity = Tween<double>(begin: 0.5, end: 0.0).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeOut));

    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _titleFade = CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut));
    _titleSlide =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _contentCtrl,
                curve: const Interval(0.0, 0.5,
                    curve: Curves.easeOutCubic)));
    _cardFade = CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.15, 0.65, curve: Curves.easeOut));
    _cardSlide =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _contentCtrl,
                curve: const Interval(0.15, 0.65,
                    curve: Curves.easeOutCubic)));
    _detailsFade = CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut));
    _detailsSlide =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _contentCtrl,
                curve: const Interval(0.3, 0.8,
                    curve: Curves.easeOutCubic)));
    _btnFade = CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOut));
    _btnSlide =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _contentCtrl,
                curve: const Interval(0.55, 1.0,
                    curve: Curves.easeOutBack)));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 80));
    _checkCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _glowCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    _contentCtrl.forward();
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    _glowCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: Container(
        decoration: BoxDecoration(
          color: colors.bgCard,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(32)),
          border:
              Border.all(color: colors.border.withOpacity(0.5)),
        ),
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).padding.bottom + 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _glowCtrl,
                    builder: (_, __) => Opacity(
                      opacity: _glowOpacity.value,
                      child: Transform.scale(
                        scale: _glowScale.value,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.success.withOpacity(0.25),
                          ),
                        ),
                      ),
                    ),
                  ),
                  FadeTransition(
                    opacity: _checkOpacity,
                    child: ScaleTransition(
                      scale: _checkScale,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            AppColors.success.withOpacity(0.2),
                            AppColors.success.withOpacity(0.05),
                          ]),
                          border: Border.all(
                            color: AppColors.success.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: AppColors.success, size: 40),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            FadeTransition(
              opacity: _titleFade,
              child: SlideTransition(
                position: _titleSlide,
                child: Column(children: [
                  Text(
                    'Booking Confirmed!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Slot ${widget.slotNumber} · ${widget.siteName}',
                    style: TextStyle(
                        fontSize: 13, color: colors.textSecondary),
                  ),
                ]),
              ),
            ),

            const SizedBox(height: 24),

            FadeTransition(
              opacity: _cardFade,
              child: SlideTransition(
                position: _cardSlide,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(children: [
                    const Icon(Icons.qr_code_2_rounded,
                        size: 100, color: Colors.black),
                    const SizedBox(height: 10),
                    Text(
                      '#BK-${widget.shortId}',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Show this QR at the entry gate',
                      style:
                          TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ]),
                ),
              ),
            ),

            const SizedBox(height: 16),

            FadeTransition(
              opacity: _detailsFade,
              child: SlideTransition(
                position: _detailsSlide,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.bgInput,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(children: [
                    _SuccessRow(
                        label: 'Check-in', value: widget.entryTime),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1),
                    ),
                    _SuccessRow(
                        label: 'Check-out', value: widget.exitTime),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1),
                    ),
                    _SuccessRow(
                      label: 'Amount',
                      value: '₨ ${widget.estimatedPrice}',
                      isHighlight: true,
                    ),
                  ]),
                ),
              ),
            ),

            const SizedBox(height: 20),

            FadeTransition(
              opacity: _btnFade,
              child: SlideTransition(
                position: _btnSlide,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    widget.onDone();
                  },
                  child: Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: AppColors.primaryGradient),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.30),
                          blurRadius: 20,
                          spreadRadius: -2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Done  ✓',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessRow extends StatelessWidget {
  final String label, value;
  final bool isHighlight;
  const _SuccessRow(
      {required this.label,
      required this.value,
      this.isHighlight = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: AppColors.of(context).textHint)),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 15 : 13,
            fontWeight:
                isHighlight ? FontWeight.w800 : FontWeight.w600,
            color: isHighlight
                ? AppColors.success
                : AppColors.of(context).textPrimary,
          ),
        ),
      ],
    );
  }
}