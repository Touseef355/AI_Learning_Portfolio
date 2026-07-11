class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String profileImageUrl;
  final String address;
  final String role;
  final String? createdAt;
  final List<dynamic> vehicles;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.profileImageUrl = '',
    this.address = '',
    this.role = 'user',
    this.createdAt,
    this.vehicles = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      profileImageUrl: json['profile_photo']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
      createdAt: json['created_at']?.toString(),
      vehicles: List<dynamic>.from(
        json['vehicles'] ?? [],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone_number': phoneNumber,
      'profile_photo': profileImageUrl,
      'address': address,
      'role': role,
      'created_at': createdAt,
      'vehicles': vehicles,
    };
  }

  UserModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? profileImageUrl,
    String? address,
    String? role,
    String? createdAt,

    // ADD THIS
    List<dynamic>? vehicles,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      address: address ?? this.address,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      vehicles: vehicles ?? this.vehicles,
    );
  }

  // Helper: initials for avatar
  String get initials {
    final parts = fullName.trim().split(' ');

    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }

    return fullName.isNotEmpty
        ? fullName[0].toUpperCase()
        : 'U';
  }
}