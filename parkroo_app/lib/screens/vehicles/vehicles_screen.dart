import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api_service.dart';
import '../../utils/error_utils.dart';
import '../../models/vehicle_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/pk_skeleton.dart';
import '../../widgets/common/micro_animations.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  List<VehicleModel> _vehicles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getVehicles();
      if (mounted) {
        setState(() {
          _vehicles = data.map((v) => VehicleModel.fromJson(v)).toList();
          _isLoading = false;
        });
      }
    } catch (e, st) {
      ErrorUtils.logError('VehiclesScreen._loadVehicles', e, st);
      if (!mounted) return;
      setState(() => _isLoading = false);
      final message = e is ApiException ? e.message : ErrorUtils.friendlyMessage(e);
      final retryable = e is ApiException ? e.error.retryable : true;
      ErrorUtils.showErrorSnack(context, message, onRetry: retryable ? _loadVehicles : null);
    }
  }

  Future<void> _deleteVehicle(String vehicleId, String vehicleName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.of(context).bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Remove Vehicle',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.of(context).textPrimary)),
        content: Text(
          'Are you sure you want to remove "$vehicleName"?',
          style: TextStyle(fontSize: 14, color: AppColors.of(context).textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.of(context).textHint)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ApiService.deleteVehicle(vehicleId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'Vehicle removed!' : 'Failed. Try again.'),
          backgroundColor: success ? AppColors.success : AppColors.danger,
        ));
        if (success) _loadVehicles();
      }
    }
  }

  // ✅ Backend-compatible type items (only Car and Truck)
  List<DropdownMenuItem<String>> get _typeItems => [
    DropdownMenuItem(
      value: 'car',
      child: Row(
        children: [
          Icon(Icons.directions_car_rounded, size: 18, color: AppColors.primary),
          SizedBox(width: 10),
          Text('Car', style: TextStyle(color: AppColors.of(context).textPrimary)),
        ],
      ),
    ),
    DropdownMenuItem(
      value: 'truck',
      child: Row(
        children: [
          Icon(Icons.local_shipping_rounded, size: 18, color: AppColors.warning),
          SizedBox(width: 10),
          Text('Truck', style: TextStyle(color: AppColors.of(context).textPrimary)),
        ],
      ),
    ),
  ];

void _showAddVehicleSheet() {
  final nameCtrl = TextEditingController();
  final plateCtrl = TextEditingController();
  final colorCtrl = TextEditingController();
  String selectedType = 'car';
  bool isSaving = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PremiumVehicleSheet(
      title: 'Add New Vehicle',
      nameCtrl: nameCtrl,
      plateCtrl: plateCtrl,
      colorCtrl: colorCtrl,
      selectedType: selectedType,
      typeItems: _typeItems,
      isSaving: isSaving,
      onSave: (selectedType) async {
        if (nameCtrl.text.trim().isEmpty || plateCtrl.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Name and Plate Number are required!'),
              backgroundColor: AppColors.danger,
            ),
          );
          return;
        }
        final result = await ApiService.addVehicle(
          name: nameCtrl.text.trim(),
          plateNumber: plateCtrl.text.trim().toUpperCase(),
          vehicleType: selectedType,
          color: colorCtrl.text.trim(),
        );
        if (mounted) {
          if (result['id'] != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Vehicle added successfully!'),
                backgroundColor: AppColors.success,
              ),
            );
            _loadVehicles();
          } else {
            ErrorUtils.showErrorSnack(
              context,
              ErrorUtils.messageFrom(result, fallback: 'Failed to add vehicle'),
            );
          }
        }
      },
    ),
  );
}

void _showEditVehicleSheet(VehicleModel vehicle) {
  final nameCtrl = TextEditingController(text: vehicle.name);
  final plateCtrl = TextEditingController(text: vehicle.plateNumber);
  final colorCtrl = TextEditingController(text: vehicle.color);
  String selectedType = vehicle.vehicleType;
  bool isSaving = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PremiumVehicleSheet(
      title: 'Edit Vehicle',
      nameCtrl: nameCtrl,
      plateCtrl: plateCtrl,
      colorCtrl: colorCtrl,
      selectedType: selectedType,
      typeItems: _typeItems,
      isSaving: isSaving,
      onSave: (selectedType) async {
        if (nameCtrl.text.trim().isEmpty || plateCtrl.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Name and Plate Number are required!'),
              backgroundColor: AppColors.danger,
            ),
          );
          return;
        }
        final result = await ApiService.updateVehicle(
          vehicleId: vehicle.id,
          name: nameCtrl.text.trim(),
          plateNumber: plateCtrl.text.trim().toUpperCase(),
          vehicleType: selectedType,
          color: colorCtrl.text.trim(),
        );
        if (mounted) {
          if (result['id'] != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Vehicle updated successfully!'),
                backgroundColor: AppColors.success,
              ),
            );
            _loadVehicles();
          } else {
            ErrorUtils.showErrorSnack(
              context,
              ErrorUtils.messageFrom(result, fallback: 'Failed to update vehicle'),
            );
          }
        }
      },
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: colors.bgBase,
      body: _isLoading
          ? PkSkeletonList(
              count: 4,
              padding: const EdgeInsets.all(16),
              itemBuilder: () => const PkSkeletonVehicleCard(),
            )
          : RefreshIndicator(
              onRefresh: _loadVehicles,
              color: AppColors.primary,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _PremiumHeader(
                      topPadding: topPadding,
                      vehiclesCount: _vehicles.length,
                      onAdd: _vehicles.isEmpty
                          ? () {}
                          : _showAddVehicleSheet,
                      colors: colors,
                      showAddButton: _vehicles.isNotEmpty,
                    ),
                  ),
                  if (_vehicles.isEmpty)
                    SliverFillRemaining(
                      child: _PremiumEmptyState(onAdd: _showAddVehicleSheet, colors: colors),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: SpringSlideIn(
                              delay: Duration(milliseconds: 60 * index),
                              child: TapScale(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  _showEditVehicleSheet(_vehicles[index]);
                                },
                                child: _PremiumVehicleCard(
                                  vehicle: _vehicles[index],
                                  isFirst: index == 0,
                                  onEdit: () => _showEditVehicleSheet(_vehicles[index]),
                                  onDelete: () => _deleteVehicle(_vehicles[index].id, _vehicles[index].name),
                                  colors: colors,
                                ),
                              ),
                            ),
                          ),
                          childCount: _vehicles.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PREMIUM HEADER
// ═══════════════════════════════════════════════════════════════

class _PremiumHeader extends StatelessWidget {
  final double topPadding;
  final int vehiclesCount;
  final VoidCallback onAdd;
  final AppColorScheme colors;
  final bool showAddButton;
  const _PremiumHeader({
    required this.topPadding,
    required this.vehiclesCount,
    required this.onAdd,
    required this.colors,
    required this.showAddButton,
  });

  @override
  Widget build(BuildContext context) {
return SizedBox(
      height: 200, 
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 170,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.of(context).bgDeep,
                  AppColors.of(context).bgCard,
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),
          Positioned(
            top: -60,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            top: topPadding + 10,
            left: 18,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            top: topPadding + 62,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'My Vehicles',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Manage all your registered vehicles',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
          if (showAddButton)
          Positioned(
            bottom: 8,
            right: 24,
            child: GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.primaryGradient,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 30,
                  color: Colors.white,
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
//  PREMIUM VEHICLE CARD — Backend Synced (Car/Truck)
// ═══════════════════════════════════════════════════════════════

class _PremiumVehicleCard extends StatelessWidget {
  final VehicleModel vehicle;
  final bool isFirst;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final AppColorScheme colors;

  const _PremiumVehicleCard({
    required this.vehicle,
    required this.isFirst,
    required this.onEdit,
    required this.onDelete,
    required this.colors,
  });

  // ✅ Backend-compatible colors (Car / Truck)
  Color get _typeColor {
    switch (vehicle.vehicleType) {
      case 'truck':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  // ✅ Backend-compatible icons (Car / Truck)
  IconData get _typeIcon {
    switch (vehicle.vehicleType) {
      case 'truck':
        return Icons.local_shipping_rounded;
      default:
        return Icons.directions_car_rounded;
    }
  }

  // ✅ Backend-compatible labels (Car / Truck)
  String get _typeLabel {
    switch (vehicle.vehicleType) {
      case 'truck':
        return 'Truck';
      default:
        return 'Car';
    }
  }

  @override
  Widget build(BuildContext context) {
return Container(
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isFirst ? AppColors.primary.withOpacity(0.3) : colors.border,
          width: isFirst ? 1.5 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 78,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _typeColor.withOpacity(0.16),
                  _typeColor.withOpacity(0.04),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _typeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _typeColor.withOpacity(0.2)),
                  ),
                  child: Icon(_typeIcon, size: 28, color: _typeColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              vehicle.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.of(context).textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isFirst)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Primary',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                      if (vehicle.color.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          vehicle.color,
                          style: TextStyle(fontSize: 12, color: AppColors.of(context).textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    vehicle.plateNumber,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.of(context).bgBase,
                      letterSpacing: 2.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _typeColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_typeIcon, size: 12, color: _typeColor),
                          const SizedBox(width: 4),
                          Text(
                            _typeLabel,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _typeColor),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onEdit,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: colors.bgCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.border),
                        ),
                        child: Icon(Icons.edit_outlined, size: 18, color: AppColors.of(context).textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.danger.withOpacity(0.2)),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PREMIUM VEHICLE SHEET (Add/Edit)
// ═══════════════════════════════════════════════════════════════

class _PremiumVehicleSheet extends StatefulWidget {
  final String title;
  final TextEditingController nameCtrl;
  final TextEditingController plateCtrl;
  final TextEditingController colorCtrl;
  final String selectedType;
  final List<DropdownMenuItem<String>> typeItems;
  final bool isSaving;
  final Future<void> Function(String selectedType) onSave;

  const _PremiumVehicleSheet({
    required this.title,
    required this.nameCtrl,
    required this.plateCtrl,
    required this.colorCtrl,
    required this.selectedType,
    required this.typeItems,
    required this.isSaving,
    required this.onSave,
  });

  @override
  State<_PremiumVehicleSheet> createState() => _PremiumVehicleSheetState();
}

class _PremiumVehicleSheetState extends State<_PremiumVehicleSheet> {
  String _selectedType = 'car';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.selectedType;
  }

  @override
  Widget build(BuildContext context) {
final colors = AppColors.of(context);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        decoration: BoxDecoration(
          color: colors.bgCard.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: AppColors.primaryGradient),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      widget.title == 'Add New Vehicle' ? Icons.add_rounded : Icons.edit_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.of(context).textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _PremiumSheetField(
                controller: widget.nameCtrl,
                label: 'Vehicle Name',
                hint: 'e.g., Toyota Corolla',
                icon: Icons.directions_car_outlined,
                colors: colors,
              ),
              const SizedBox(height: 14),
              _PremiumSheetField(
                controller: widget.plateCtrl,
                label: 'Plate Number',
                hint: 'e.g., LEA-1234',
                icon: Icons.credit_card_outlined,
                textCapitalization: TextCapitalization.characters,
                colors: colors,
              ),
              const SizedBox(height: 14),
              _PremiumSheetField(
                controller: widget.colorCtrl,
                label: 'Color',
                hint: 'e.g., Silver',
                icon: Icons.color_lens_outlined,
                colors: colors,
              ),
              const SizedBox(height: 14),
              _PremiumTypeDropdown(
                value: _selectedType,
                items: widget.typeItems,
                colors: colors,
                onChanged: (v) => setState(() => _selectedType = v!),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isSaving
                      ? null
                      : () async {
                          setState(() => _isSaving = true);
                          await widget.onSave(_selectedType);
                          setState(() => _isSaving = false);
                          if (mounted) Navigator.pop(context);
                        },
                  child: _isSaving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          widget.title == 'Add New Vehicle' ? 'Add Vehicle' : 'Save Changes',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumSheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextCapitalization textCapitalization;
  final AppColorScheme colors;

  const _PremiumSheetField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.colors,
    this.textCapitalization = TextCapitalization.words,
  });

  @override
  Widget build(BuildContext context) {
return TextField(
      controller: controller,
      textCapitalization: textCapitalization,
      style: TextStyle(color: colors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: colors.textHint, fontSize: 13),
        hintStyle: TextStyle(color: colors.textHint.withOpacity(0.5), fontSize: 13),
        prefixIcon: Icon(icon, color: colors.textHint, size: 20),
        filled: true,
        fillColor: colors.bgInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _PremiumTypeDropdown extends StatelessWidget {
  final String value;
  final List<DropdownMenuItem<String>> items;
  final AppColorScheme colors;
  final ValueChanged<String?> onChanged;

  const _PremiumTypeDropdown({
    required this.value,
    required this.items,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.bgInput,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: colors.bgCard,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.of(context).textHint),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PREMIUM EMPTY STATE
// ═══════════════════════════════════════════════════════════════

class _PremiumEmptyState extends StatefulWidget {
  final VoidCallback onAdd;
  final AppColorScheme colors;

  const _PremiumEmptyState({required this.onAdd, required this.colors});

  @override
  State<_PremiumEmptyState> createState() => _PremiumEmptyStateState();
}

class _PremiumEmptyStateState extends State<_PremiumEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _iconScale;
  late final Animation<double> _btnSlide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.55, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic)));
    _iconScale = Tween<double>(begin: 0.55, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.1, 0.75, curve: Curves.easeOutBack)));
    _btnSlide = CurvedAnimation(parent: _ctrl, curve: const Interval(0.45, 1.0, curve: Curves.easeOutBack));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _iconScale,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withOpacity(0.14),
                          AppColors.primaryDark.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(color: AppColors.primary.withOpacity(0.18)),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.1),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.directions_car_outlined,
                      size: 52,
                      color: AppColors.primary.withOpacity(0.7),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'No vehicles yet',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.of(context).textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Add your car once, book\nparking in seconds every time',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.of(context).textSecondary,
                    height: 1.55,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ScaleTransition(
                  scale: _btnSlide,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      widget.onAdd();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: AppColors.primaryGradient),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.add_rounded, size: 20, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Add Vehicle',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
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