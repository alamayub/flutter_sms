import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/app_database.dart';
import '../services/certificate_service.dart';
import 'database_provider.dart';

/// Provider for CertificateService
final certificateServiceProvider = Provider<CertificateService>((ref) {
  final db = ref.watch(databaseProvider);
  return CertificateService(db);
});

/// Certificate Type Filter ('all', 'tc', 'cc', 'bonafide', 'marksheet', 'custom')
class CertificateTypeFilterNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  void setType(String type) => state = type;
}

final certificateTypeFilterProvider =
    NotifierProvider<CertificateTypeFilterNotifier, String>(
      CertificateTypeFilterNotifier.new,
    );

/// Search Query Filter for Certificates
class CertificateSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final certificateSearchQueryProvider =
    NotifierProvider<CertificateSearchQueryNotifier, String>(
      CertificateSearchQueryNotifier.new,
    );

/// Class Filter for Certificates
class CertificateClassFilterNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void setClassId(int? classId) => state = classId;
}

final certificateClassFilterProvider =
    NotifierProvider<CertificateClassFilterNotifier, int?>(
      CertificateClassFilterNotifier.new,
    );

/// Academic Year Filter for Certificates
class CertificateAcademicYearFilterNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void setYearId(int? yearId) => state = yearId;
}

final certificateAcademicYearFilterProvider =
    NotifierProvider<CertificateAcademicYearFilterNotifier, int?>(
      CertificateAcademicYearFilterNotifier.new,
    );

/// Stream provider for all certificates matching filters
final certificatesStreamProvider = StreamProvider<List<CertificateWithDetails>>(
  (ref) {
    final service = ref.watch(certificateServiceProvider);
    final type = ref.watch(certificateTypeFilterProvider);
    final query = ref.watch(certificateSearchQueryProvider);
    final classId = ref.watch(certificateClassFilterProvider);
    final yearId = ref.watch(certificateAcademicYearFilterProvider);

    return service.watchCertificates(
      certificateType: type,
      query: query,
      classId: classId,
      academicYearId: yearId,
    );
  },
);

/// Future provider for certificate summary metrics
final certificateSummaryProvider = FutureProvider<CertificateSummary>((
  ref,
) async {
  final service = ref.watch(certificateServiceProvider);
  // Recompute when certificates stream changes
  ref.watch(certificatesStreamProvider);
  return service.getCertificateSummary();
});
