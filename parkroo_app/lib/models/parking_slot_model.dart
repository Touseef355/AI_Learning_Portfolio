import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
enum SlotType { normal, vip, disabled }
enum SlotStatus { available, booked, selected, maintenance }

class ParkingSlotModel {
  final String id;
  final String slotNumber;
  final SlotType type;
  final SlotStatus status;
  final double pricePerHour;
  final String? bookedBy;
  final DateTime? bookedUntil;
  final bool isOverstay;

  ParkingSlotModel({
    required this.id,
    required this.slotNumber,
    required this.type,
    required this.status,
    required this.pricePerHour,
    this.bookedBy,
    this.bookedUntil,
    this.isOverstay = false,
  });

  factory ParkingSlotModel.normal(String id, String slotNumber) {
    return ParkingSlotModel(
      id: id,
      slotNumber: slotNumber,
      type: SlotType.normal,
      status: SlotStatus.available,
      pricePerHour: 50.0,
    );
  }

  factory ParkingSlotModel.vip(String id, String slotNumber) {
    return ParkingSlotModel(
      id: id,
      slotNumber: slotNumber,
      type: SlotType.vip,
      status: SlotStatus.available,
      pricePerHour: 100.0,
    );
  }

  factory ParkingSlotModel.disabled(String id, String slotNumber) {
    return ParkingSlotModel(
      id: id,
      slotNumber: slotNumber,
      type: SlotType.disabled,
      status: SlotStatus.available,
      pricePerHour: 40.0,
    );
  }

  ParkingSlotModel copyWith({
    String? id,
    String? slotNumber,
    SlotType? type,
    SlotStatus? status,
    double? pricePerHour,
    String? bookedBy,
    DateTime? bookedUntil,
    bool? isOverstay,
  }) {
    return ParkingSlotModel(
      id: id ?? this.id,
      slotNumber: slotNumber ?? this.slotNumber,
      type: type ?? this.type,
      status: status ?? this.status,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      bookedBy: bookedBy ?? this.bookedBy,
      bookedUntil: bookedUntil ?? this.bookedUntil,
      isOverstay: isOverstay ?? this.isOverstay,
    );
  }

  IconData get slotIcon {
    switch (type) {
      case SlotType.vip:
        return Icons.star;
      case SlotType.disabled:
        return Icons.accessible;
      default:
        return Icons.directions_car;
    }
  }

  Color get statusColor {
    switch (status) {
      case SlotStatus.available:
        return AppColors.accent;
      case SlotStatus.booked:
        return AppColors.danger;
      case SlotStatus.selected:
        return AppColors.primary;
      case SlotStatus.maintenance:
        return AppColors.warning;
    }
  }
}