/// Manager model matching backend ManagerController response
class Manager {
  final String id;
  final String name;
  final String? email;
  final String phoneNumber;
  final List<String> vendorIds;
  final String? profileImageUrl;
  final String role;
  final bool phoneVerified;
  final bool emailVerified;
  final bool isActive;
  final bool isVerified;
  final String? lastLogin;
  final String? createdAt;

  Manager({
    required this.id,
    required this.name,
    this.email,
    required this.phoneNumber,
    required this.vendorIds,
    this.profileImageUrl,
    required this.role,
    required this.phoneVerified,
    required this.emailVerified,
    required this.isActive,
    required this.isVerified,
    this.lastLogin,
    this.createdAt,
  });

  factory Manager.fromJson(Map<String, dynamic> json) {
    return Manager(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      phoneNumber: json['phoneNumber'] as String,
      vendorIds: (json['vendorIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      profileImageUrl: json['profileImageUrl'] as String?,
      role: json['role'] as String? ?? 'STORE_MANAGER',
      phoneVerified: json['phoneVerified'] as bool? ?? false,
      emailVerified: json['emailVerified'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      isVerified: json['isVerified'] as bool? ?? false,
      lastLogin: json['lastLogin'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'vendorIds': vendorIds,
      'profileImageUrl': profileImageUrl,
      'role': role,
      'phoneVerified': phoneVerified,
      'emailVerified': emailVerified,
      'isActive': isActive,
      'isVerified': isVerified,
      'lastLogin': lastLogin,
      'createdAt': createdAt,
    };
  }

  /// Check if manager has access to a specific vendor/store
  bool hasAccessToVendor(String vendorId) {
    return vendorIds.contains(vendorId);
  }

  /// Returns true if manager is an admin with access to all stores
  bool get isAdmin => role == 'ADMIN' || role == 'REGIONAL_MANAGER';

  Manager copyWith({
    String? id,
    String? name,
    String? email,
    String? phoneNumber,
    List<String>? vendorIds,
    String? profileImageUrl,
    String? role,
    bool? phoneVerified,
    bool? emailVerified,
    bool? isActive,
    bool? isVerified,
    String? lastLogin,
    String? createdAt,
  }) {
    return Manager(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      vendorIds: vendorIds ?? this.vendorIds,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      role: role ?? this.role,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      emailVerified: emailVerified ?? this.emailVerified,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      lastLogin: lastLogin ?? this.lastLogin,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

