import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../services/storage_service.dart';

/// Overridden at app launch in main.dart
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError(
    'storageServiceProvider must be initialized in main()',
  );
});
