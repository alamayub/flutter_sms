import 'dart:convert';

/// Complete model representing an institution's profile, contact details,
/// and administrative credentials.
class SchoolProfile {
  final String name;
  final String code;
  final String address;
  final String phone;
  final String email;
  final String website;
  final String principalName;
  final String establishedYear;
  final String? logoPath;
  final String tagline;
  final String idCardFooter;
  final String adminUsername;
  final String adminPasswordHash;
  final String adminPinHash;
  final bool isRegistered;
  final DateTime? registeredAt;
  final DateTime? lastBackupAt;

  const SchoolProfile({
    required this.name,
    this.code = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.principalName = '',
    this.establishedYear = '',
    this.logoPath,
    this.tagline = '',
    this.idCardFooter = '',
    this.adminUsername = '',
    required this.adminPasswordHash,
    this.adminPinHash = '',
    this.isRegistered = false,
    this.registeredAt,
    this.lastBackupAt,
  });

  /// Factory for a clean, unregistered profile with no demo data or credentials.
  factory SchoolProfile.initial() {
    return SchoolProfile(
      name: '',
      adminPasswordHash: '',
      adminPinHash: '',
      isRegistered: false,
    );
  }

  /// Offline deterministic password hash generator (FNV-1a 64-bit with salt)
  static String hashPassword(
    String password, [
    String salt = 'sms_school_salt_2026',
  ]) {
    var hash = 0xcbf29ce484222325;
    final bytes = utf8.encode('$salt:$password:$salt');
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  bool verifyPassword(String inputPassword) {
    return adminPasswordHash == hashPassword(inputPassword);
  }

  bool verifyPin(String inputPin) {
    if (adminPinHash.isEmpty) return false;
    return adminPinHash == hashPassword(inputPin);
  }

  bool verifyPasswordOrPin(String input) {
    return verifyPassword(input) || verifyPin(input);
  }

  SchoolProfile copyWith({
    String? name,
    String? code,
    String? address,
    String? phone,
    String? email,
    String? website,
    String? principalName,
    String? establishedYear,
    String? logoPath,
    String? tagline,
    String? idCardFooter,
    String? adminUsername,
    String? adminPasswordHash,
    String? adminPinHash,
    bool? isRegistered,
    DateTime? registeredAt,
    DateTime? lastBackupAt,
  }) {
    return SchoolProfile(
      name: name ?? this.name,
      code: code ?? this.code,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      principalName: principalName ?? this.principalName,
      establishedYear: establishedYear ?? this.establishedYear,
      logoPath: logoPath ?? this.logoPath,
      tagline: tagline ?? this.tagline,
      idCardFooter: idCardFooter ?? this.idCardFooter,
      adminUsername: adminUsername ?? this.adminUsername,
      adminPasswordHash: adminPasswordHash ?? this.adminPasswordHash,
      adminPinHash: adminPinHash ?? this.adminPinHash,
      isRegistered: isRegistered ?? this.isRegistered,
      registeredAt: registeredAt ?? this.registeredAt,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'address': address,
      'phone': phone,
      'email': email,
      'website': website,
      'principalName': principalName,
      'establishedYear': establishedYear,
      'logoPath': logoPath,
      'tagline': tagline,
      'idCardFooter': idCardFooter,
      'adminUsername': adminUsername,
      'adminPasswordHash': adminPasswordHash,
      'adminPinHash': adminPinHash,
      'isRegistered': isRegistered,
      'registeredAt': registeredAt?.toIso8601String(),
      'lastBackupAt': lastBackupAt?.toIso8601String(),
    };
  }

  factory SchoolProfile.fromJson(Map<String, dynamic> json) {
    return SchoolProfile(
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      address: json['address'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      website: json['website'] as String? ?? '',
      principalName: json['principalName'] as String? ?? '',
      establishedYear: json['establishedYear'] as String? ?? '',
      logoPath: json['logoPath'] as String?,
      tagline: json['tagline'] as String? ?? '',
      idCardFooter: json['idCardFooter'] as String? ?? '',
      adminUsername: json['adminUsername'] as String? ?? '',
      adminPasswordHash: json['adminPasswordHash'] as String? ?? '',
      adminPinHash: json['adminPinHash'] as String? ?? '',
      isRegistered: json['isRegistered'] as bool? ?? false,
      registeredAt:
          json['registeredAt'] != null
              ? DateTime.tryParse(json['registeredAt'] as String)
              : null,
      lastBackupAt:
          json['lastBackupAt'] != null
              ? DateTime.tryParse(json['lastBackupAt'] as String)
              : null,
    );
  }
}
