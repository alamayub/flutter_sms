// lib/features/sync/domain/device_model.dart
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';

class DeviceModel {
  final String deviceId;
  final String schoolId;
  final String deviceName;
  final String deviceType; // 'mobile', 'desktop', 'server'
  final String? pairingCode;
  final String status; // 'pending_approval', 'approved', 'revoked'
  final DateTime registeredAt;
  final DateTime lastSeenAt;
  final bool isCurrentDevice;

  const DeviceModel({
    required this.deviceId,
    required this.schoolId,
    required this.deviceName,
    required this.deviceType,
    this.pairingCode,
    this.status = DeviceStatus.pendingApproval,
    required this.registeredAt,
    required this.lastSeenAt,
    this.isCurrentDevice = false,
  });

  bool get isApproved => status == DeviceStatus.approved;
  bool get isRevoked => status == DeviceStatus.revoked;
  bool get isPending => status == DeviceStatus.pendingApproval;

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'schoolId': schoolId,
    'deviceName': deviceName,
    'deviceType': deviceType,
    if (pairingCode != null) 'pairingCode': pairingCode,
    'status': status,
    'registeredAt': registeredAt.toIso8601String(),
    'lastSeenAt': lastSeenAt.toIso8601String(),
    'isCurrentDevice': isCurrentDevice,
  };

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      deviceId: json['deviceId'] as String,
      schoolId: json['schoolId'] as String,
      deviceName: json['deviceName'] as String,
      deviceType: json['deviceType'] as String,
      pairingCode: json['pairingCode'] as String?,
      status: json['status'] as String? ?? DeviceStatus.pendingApproval,
      registeredAt: DateTime.parse(json['registeredAt'] as String),
      lastSeenAt: DateTime.parse(json['lastSeenAt'] as String),
      isCurrentDevice: json['isCurrentDevice'] as bool? ?? false,
    );
  }

  factory DeviceModel.fromTableData(SyncDevice data) {
    return DeviceModel(
      deviceId: data.id,
      schoolId: data.schoolId,
      deviceName: data.deviceName,
      deviceType: data.deviceType,
      pairingCode: data.pairingCode,
      status: data.status,
      registeredAt: data.registeredAt,
      lastSeenAt: data.lastSeenAt,
      isCurrentDevice: data.isCurrentDevice,
    );
  }

  DeviceModel copyWith({
    String? status,
    String? pairingCode,
    DateTime? lastSeenAt,
    bool? isCurrentDevice,
  }) {
    return DeviceModel(
      deviceId: deviceId,
      schoolId: schoolId,
      deviceName: deviceName,
      deviceType: deviceType,
      pairingCode: pairingCode ?? this.pairingCode,
      status: status ?? this.status,
      registeredAt: registeredAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isCurrentDevice: isCurrentDevice ?? this.isCurrentDevice,
    );
  }
}
