// lib/features/sync/presentation/sync_controller.dart
import 'dart:async';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/database/database_service.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../client/device_service.dart';
import '../client/server_discovery_client.dart';
import '../client/sync_engine.dart';
import '../domain/sync_state.dart';

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final deviceService = ref.watch(deviceServiceProvider);
  final engine = SyncEngine(db: db, deviceService: deviceService);

  ref.onDispose(() {
    engine.dispose();
  });

  return engine;
});

final syncStatusProvider = StreamProvider<SyncStatusInfo>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return engine.statusStream;
});

final syncControllerProvider =
    StateNotifierProvider<SyncController, SyncStatusInfo>((ref) {
      final engine = ref.watch(syncEngineProvider);
      final authState = ref.watch(authControllerProvider);
      return SyncController(engine: engine, authState: authState);
    });

class SyncController extends StateNotifier<SyncStatusInfo> {
  final SyncEngine _engine;
  final AuthState _authState;
  StreamSubscription? _statusSub;

  SyncController({required SyncEngine engine, required AuthState authState})
    : _engine = engine,
      _authState = authState,
      super(engine.currentStatus) {
    _statusSub = _engine.statusStream.listen((status) {
      state = status;
    });

    _autoInitialize();
  }

  Future<void> _autoInitialize() async {
    final school = _authState.currentSchool;
    if (school != null) {
      await _engine.initialize(schoolId: school.id);
    }
  }

  Future<bool> connectToServer(String serverUrl) async {
    final school = _authState.currentSchool;
    if (school == null) return false;

    return await _engine.configureServer(serverUrl);
  }

  Future<bool> discoverAndConnect() async {
    state = state.copyWith(connectivity: SyncConnectivityState.syncing);
    final discovered = await ServerDiscoveryClient.discover();
    if (discovered != null) {
      return await connectToServer(discovered.httpUrl);
    } else {
      state = state.copyWith(
        connectivity: SyncConnectivityState.localOnly,
        errorMessage: 'Could not find School Server on Wi-Fi',
      );
      return false;
    }
  }

  Future<void> syncNow() async {
    await _engine.syncNow();
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }
}
