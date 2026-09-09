// lib/features/sync/client/device_service.dart
import 'dart:io';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_service.dart';
import '../../../core/utils/uuid_generator.dart';
import '../domain/device_model.dart';

final deviceServiceProvider = Provider<DeviceService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DeviceService(db);
});

class DeviceService {
  final AppDatabase _db;
  static const String _deviceIdSettingKey = 'local_device_id';
  static const String _devicePairingCodeKey = 'local_device_pairing_code';

  DeviceService(this._db);

  /// Gets the persistent unique device ID for this installation.
  /// If not yet created, generates a UUID v4 and persists it.
  Future<String> getOrCreateDeviceId() async {
    final setting =
        await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(_deviceIdSettingKey))).getSingleOrNull();

    if (setting != null && setting.value.isNotEmpty) {
      return setting.value;
    }

    final newId = UuidGenerator.v4();
    await _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: _deviceIdSettingKey,
            value: newId,
            updatedAt: DateTime.now(),
          ),
        );
    return newId;
  }

  /// Gets or generates a 6-digit numeric pairing code (e.g. "482913")
  Future<String> getOrCreatePairingCode() async {
    final setting =
        await (_db.select(
          _db.appSettings,
        )..where((t) => t.key.equals(_devicePairingCodeKey))).getSingleOrNull();

    if (setting != null && setting.value.isNotEmpty) {
      return setting.value;
    }

    final code = (100000 + Random().nextInt(900000)).toString();
    await _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: _devicePairingCodeKey,
            value: code,
            updatedAt: DateTime.now(),
          ),
        );
    return code;
  }

  /// Determines friendly default device name based on platform
  String getDefaultDeviceName() {
    if (Platform.isMacOS) return 'Mac Desktop';
    if (Platform.isWindows) return 'Windows PC';
    if (Platform.isLinux) return 'Linux PC';
    if (Platform.isAndroid) return 'Android Phone';
    if (Platform.isIOS) return 'iPhone/iPad';
    return 'School Client Device';
  }

  /// Determines device type
  String getDeviceType() {
    if (Platform.isAndroid || Platform.isIOS) return 'mobile';
    return 'desktop';
  }

  /// Loads or initializes the current device record in the database
  Future<DeviceModel> getOrCreateCurrentDevice(String schoolId) async {
    final deviceId = await getOrCreateDeviceId();
    final pairingCode = await getOrCreatePairingCode();

    final existing =
        await (_db.select(_db.syncDevices)
          ..where((t) => t.id.equals(deviceId))).getSingleOrNull();

    if (existing != null) {
      return DeviceModel.fromTableData(existing);
    }

    final now = DateTime.now();
    final deviceName = getDefaultDeviceName();
    final deviceType = getDeviceType();

    await _db
        .into(_db.syncDevices)
        .insert(
          SyncDevicesCompanion.insert(
            id: deviceId,
            schoolId: schoolId,
            deviceName: deviceName,
            deviceType: deviceType,
            pairingCode: Value(pairingCode),
            status: const Value(DeviceStatus.pendingApproval),
            registeredAt: now,
            lastSeenAt: now,
            isCurrentDevice: const Value(true),
          ),
        );

    return DeviceModel(
      deviceId: deviceId,
      schoolId: schoolId,
      deviceName: deviceName,
      deviceType: deviceType,
      pairingCode: pairingCode,
      status: DeviceStatus.pendingApproval,
      registeredAt: now,
      lastSeenAt: now,
      isCurrentDevice: true,
    );
  }

  /// Updates status of the local device or remote devices
  Future<void> updateDeviceStatus(String deviceId, String status) async {
    await (_db.update(_db.syncDevices)
      ..where((t) => t.id.equals(deviceId))).write(
      SyncDevicesCompanion(
        status: Value(status),
        lastSeenAt: Value(DateTime.now()),
      ),
    );
  }

  /// Gets all registered devices for management in UI
  Future<List<DeviceModel>> getDevicesForSchool(String schoolId) async {
    final rows =
        await (_db.select(_db.syncDevices)
              ..where((t) => t.schoolId.equals(schoolId))
              ..orderBy([(t) => OrderingTerm.desc(t.registeredAt)]))
            .get();
    return rows.map(DeviceModel.fromTableData).toList();
  }

  /// Saves or updates a device record received from server or paired
  Future<void> upsertDevice(DeviceModel device) async {
    await _db
        .into(_db.syncDevices)
        .insertOnConflictUpdate(
          SyncDevicesCompanion.insert(
            id: device.deviceId,
            schoolId: device.schoolId,
            deviceName: device.deviceName,
            deviceType: device.deviceType,
            pairingCode: Value(device.pairingCode),
            status: Value(device.status),
            registeredAt: device.registeredAt,
            lastSeenAt: device.lastSeenAt,
            isCurrentDevice: Value(device.isCurrentDevice),
          ),
        );
  }
}
