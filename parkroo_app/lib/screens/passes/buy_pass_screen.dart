import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/error_utils.dart';

/// Purchase a weekly Parking Pass: dedicated slot at a site, daily time
/// window, 1/2/4-week duration with tiered discounts, paid from wallet.
class BuyPassScreen extends StatefulWidget {
  /// Optionally pre-selected site (when opened from a site's page).
  final Map<String, dynamic>? site;
  const BuyPassScreen({super.key, this.site});

  @override
  State<BuyPassScreen> createState() => _BuyPassScreenState();
}

class _BuyPassScreenState extends State<BuyPassScreen> {
  // Data
  List<dynamic> _sites = [];
  List<dynamic> _slots = [];
  List<dynamic> _vehicles = [];

  // Selection
  Map<String, dynamic>? _site;
  Map<String, dynamic>? _slot;
  Map<String, dynamic>? _vehicle;
  TimeOfDay _dailyStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _dailyEnd = const TimeOfDay(hour: 18, minute: 0);
  int _weeks = 4;

  // Preview
  Map<String, dynamic>? _preview;
  bool _loading = true;
  bool _previewLoading = false;
  bool _purchasing = false;

  static const _durations = [
    (1, '1 Week', '10% off'),
    (2, '2 Weeks', '15% off'),
    (4, '4 Weeks', '25% off'),
  ];

  @override
  void initState() {
    super.initState();
    _site = widget.site;
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      widget.site == null ? ApiService.getParkingSites() : Future.value(<dynamic>[]),
      ApiService.getVehicles(),
    ]);
    if (!mounted) return;
    setState(() {
      _sites = results[0];
      _vehicles = results[1];
      if (_vehicles.length == 1) _vehicle = _vehicles.first;
      _loading = false;
    });
    if (_site != null) _loadSlots();
  }

  Future<void> _loadSlots() async {
    final siteId = _site?['id']?.toString();
    if (siteId == null) return;
    final slots = await ApiService.getSlots(siteId);
    if (!mounted) return;
    setState(() {
      _slots = slots
          .where((s) => s['is_occupied'] != true && s['is_reserved'] != true)
          .toList();
      _slot = null;
      _preview = null;
    });
  }

  String _hm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _fetchPreview() async {
    if (_slot == null) return;
    if (_endBeforeStart) return;
    setState(() => _previewLoading = true);
    final res = await ApiService.previewPass(
      slotId: _slot!['id'].toString(),
      durationWeeks: _weeks,
      dailyStart: _hm(_dailyStart),
      dailyEnd: _hm(_dailyEnd),
    );
    if (!mounted) return;
    setState(() {
      _previewLoading = false;
      _preview = res.containsKey('error') ? null : res;
    });
  }

  bool get _endBeforeStart =>
      _dailyEnd.hour * 60 + _dailyEnd.minute <=
      _dailyStart.hour * 60 + _dailyStart.minute;

  bool get _ready => _slot != null && _vehicle != null && !_endBeforeStart;

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _dailyStart : _dailyEnd,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _dailyStart = picked;
      } else {
        _dailyEnd = picked;
      }
      _preview = null;
    });
    _fetchPreview();
  }

  Future<void> _purchase() async {
    if (!_ready || _preview == null) return;
    HapticFeedback.mediumImpact();

    final price = _preview!['pass_price']?.toString() ?? '—';
    final savings = _preview!['savings']?.toString() ?? '0';

    final c = AppColors.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Confirm Pass',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary)),
        content: Text(
          'Rs. $price will be deducted from your wallet for a $_weeks-week pass '
          'on slot ${_slot!['slot_number']} '
          '(${_hm(_dailyStart)}–${_hm(_dailyEnd)} daily).\n\n'
          'You save Rs. $savings vs paying hourly.',
          style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pay & Activate',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _purchasing = true);
    final res = await ApiService.createPass(
      slotId: _slot!['id'].toString(),
      vehicleId: _vehicle!['id'].toString(),
      durationWeeks: _weeks,
      dailyStart: _hm(_dailyStart),
      dailyEnd: _hm(_dailyEnd),
    );
    if (!mounted) return;
    setState(() => _purchasing = false);

    if (res['id'] != null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Pass activated — slot ${_slot!['slot_number']} is yours for $_weeks week(s)!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              ErrorUtils.messageFrom(res, fallback: 'Could not activate pass')),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // ─────────────────────────── UI ───────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: c.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Buy Parking Pass',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (widget.site == null) ...[
                  _sectionTitle('Parking Site'),
                  _sitePicker(c),
                  const SizedBox(height: 20),
                ],
                if (_site != null) ...[
                  _sectionTitle('Your Dedicated Slot'),
                  _slotGrid(c),
                  const SizedBox(height: 20),
                ],
                _sectionTitle('Vehicle'),
                _vehiclePicker(c),
                const SizedBox(height: 20),
                _sectionTitle('Daily Time Window'),
                Row(children: [
                  Expanded(child: _timeChip(c, 'From', _dailyStart, () => _pickTime(true))),
                  const SizedBox(width: 12),
                  Expanded(child: _timeChip(c, 'To', _dailyEnd, () => _pickTime(false))),
                ]),
                if (_endBeforeStart)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('End time must be after start time',
                        style: TextStyle(fontSize: 12, color: AppColors.danger)),
                  ),
                const SizedBox(height: 20),
                _sectionTitle('Duration'),
                Row(
                  children: _durations
                      .map((d) => Expanded(child: _durationChip(c, d)))
                      .toList(),
                ),
                const SizedBox(height: 24),
                if (_previewLoading)
                  const Center(
                      child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2),
                  ))
                else if (_preview != null)
                  _priceCard(c),
                const SizedBox(height: 20),
                _payButton(c),
              ],
            ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: AppColors.of(context).textSecondary)),
      );

  Widget _sitePicker(dynamic c) {
    if (_sites.isEmpty) {
      return Text('No parking sites available',
          style: TextStyle(fontSize: 13, color: c.textSecondary));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _site?['id']?.toString(),
          hint: Text('Select a site',
              style: TextStyle(fontSize: 14, color: c.textHint)),
          dropdownColor: c.bgElevated,
          style: TextStyle(fontSize: 14, color: c.textPrimary),
          items: _sites
              .map<DropdownMenuItem<String>>((s) => DropdownMenuItem(
                    value: s['id'].toString(),
                    child: Text(s['name']?.toString() ?? 'Site'),
                  ))
              .toList(),
          onChanged: (id) {
            setState(() {
              _site = _sites.firstWhere((s) => s['id'].toString() == id);
            });
            _loadSlots();
          },
        ),
      ),
    );
  }

  Widget _slotGrid(dynamic c) {
    if (_slots.isEmpty) {
      return Text('No free slots at this site right now',
          style: TextStyle(fontSize: 13, color: c.textSecondary));
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _slots.map<Widget>((s) {
        final selected = _slot?['id'] == s['id'];
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _slot = s;
              _preview = null;
            });
            _fetchPreview();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : c.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected ? AppColors.primary : c.border,
                  width: selected ? 1.5 : 0.5),
            ),
            child: Text(
              s['slot_number']?.toString() ?? '?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : c.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _vehiclePicker(dynamic c) {
    if (_vehicles.isEmpty) {
      return Text('Add a vehicle first from the Vehicles screen',
          style: TextStyle(fontSize: 13, color: AppColors.warning));
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _vehicles.map<Widget>((v) {
        final selected = _vehicle?['id'] == v['id'];
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _vehicle = v);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : c.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected ? AppColors.primary : c.border,
                  width: selected ? 1.5 : 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    (v['vehicle_type'] == 'truck')
                        ? Icons.local_shipping_rounded
                        : Icons.directions_car_rounded,
                    size: 16,
                    color: selected ? Colors.white : c.textSecondary),
                const SizedBox(width: 6),
                Text(
                  v['plate_number']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : c.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _timeChip(dynamic c, String label, TimeOfDay t, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: c.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 16, color: c.textSecondary),
            const SizedBox(width: 8),
            Text('$label  ',
                style: TextStyle(fontSize: 12, color: c.textSecondary)),
            Text(_hm(t),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _durationChip(dynamic c, (int, String, String) d) {
    final selected = _weeks == d.$1;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _weeks = d.$1;
          _preview = null;
        });
        _fetchPreview();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : c.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? AppColors.primary : c.border,
              width: selected ? 1.5 : 0.5),
        ),
        child: Column(
          children: [
            Text(d.$2,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : c.textPrimary)),
            const SizedBox(height: 2),
            Text(d.$3,
                style: TextStyle(
                    fontSize: 11,
                    color: selected
                        ? Colors.white.withOpacity(0.85)
                        : AppColors.success)),
          ],
        ),
      ),
    );
  }

  Widget _priceCard(dynamic c) {
    final p = _preview!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.10),
            AppColors.success.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          _priceRow(c, 'Hourly total (${p['days']} days × ${p['daily_hours']}h)',
              'Rs. ${p['hourly_total']}',
              strike: true),
          const SizedBox(height: 8),
          _priceRow(c, 'Pass discount', '−${p['discount_percent']}%',
              valueColor: AppColors.success),
          Divider(height: 20, color: c.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pass Price',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary)),
              Text('Rs. ${p['pass_price']}',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text('You save Rs. ${p['savings']}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success)),
          ),
          Text('Valid ${p['start_date']} → ${p['end_date']}',
              style: TextStyle(fontSize: 11.5, color: c.textSecondary)),
        ],
      ),
    );
  }

  Widget _priceRow(dynamic c, String label, String value,
      {bool strike = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
            child: Text(label,
                style: TextStyle(fontSize: 12.5, color: c.textSecondary))),
        Text(value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? c.textPrimary,
              decoration: strike ? TextDecoration.lineThrough : null,
            )),
      ],
    );
  }

  Widget _payButton(dynamic c) {
    final enabled = _ready && _preview != null && !_purchasing;
    return GestureDetector(
      onTap: enabled ? _purchase : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        decoration: BoxDecoration(
          color: enabled ? AppColors.primary : c.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: enabled ? null : Border.all(color: c.border, width: 0.5),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                ]
              : null,
        ),
        child: Center(
          child: _purchasing
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : Text(
                  _preview != null
                      ? 'Pay Rs. ${_preview!['pass_price']} from Wallet'
                      : 'Select slot & vehicle',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: enabled ? Colors.white : c.textHint,
                  ),
                ),
        ),
      ),
    );
  }
}
