class VehicleModel {
  final String id;
  final String name;
  final String plateNumber;
  final String vehicleType; // 'normal', 'vip', 'disabled'
  final String color;

  VehicleModel({
    required this.id,
    required this.name,
    required this.plateNumber,
    required this.vehicleType,
    this.color = '',
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      plateNumber: json['plate_number']?.toString() ?? '',
      vehicleType: json['vehicle_type']?.toString() ?? 'normal',
      color: json['color']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'plate_number': plateNumber,
      'vehicle_type': vehicleType,
      'color': color,
    };
  }

  VehicleModel copyWith({
    String? id,
    String? name,
    String? plateNumber,
    String? vehicleType,
    String? color,
  }) {
    return VehicleModel(
      id: id ?? this.id,
      name: name ?? this.name,
      plateNumber: plateNumber ?? this.plateNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      color: color ?? this.color,
    );
  }

  // Badge label for UI
  String get typeLabel {
    switch (vehicleType) {
      case 'vip':
        return 'VIP';
      case 'disabled':
        return 'Disabled';
      default:
        return 'Normal';
    }
  }
}