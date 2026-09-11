import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/school_profile.dart';
import '../services/storage_service.dart';
import 'storage_provider.dart';

class SchoolProfileNotifier extends Notifier<SchoolProfile> {
  StorageService? _storageService;

  @override
  SchoolProfile build() {
    try {
      _storageService = ref.watch(storageServiceProvider);
      return _storageService?.getSchoolProfile() ??
          SchoolProfile.defaultRegistered();
    } catch (_) {
      // Safe fallback for isolated unit/widget tests
      return SchoolProfile.defaultRegistered();
    }
  }

  Future<void> updateProfile(SchoolProfile updated) async {
    state = updated;
    try {
      await _storageService?.saveSchoolProfile(updated);
    } catch (_) {}
  }

  Future<void> reload() async {
    try {
      final loaded = _storageService?.getSchoolProfile();
      if (loaded != null) {
        state = loaded;
      }
    } catch (_) {}
  }
}

final schoolProfileProvider =
    NotifierProvider<SchoolProfileNotifier, SchoolProfile>(
      () => SchoolProfileNotifier(),
    );
