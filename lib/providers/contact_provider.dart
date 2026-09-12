import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../config/enums.dart';
import '../data/app_database.dart';
import '../services/contact_service.dart';
import 'database_provider.dart';

/// Provider for ContactService
final contactServiceProvider = Provider<ContactService>((ref) {
  final db = ref.watch(databaseProvider);
  return ContactService(db);
});

/// Filter state for selected source type (null = All)
class SelectedContactSourceTypeNotifier extends Notifier<ContactSourceType?> {
  @override
  ContactSourceType? build() => null;

  void setType(ContactSourceType? type) => state = type;
}

final selectedContactSourceTypeFilterProvider =
    NotifierProvider<SelectedContactSourceTypeNotifier, ContactSourceType?>(
      SelectedContactSourceTypeNotifier.new,
    );

/// Filter state for search query
class ContactSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final contactSearchQueryProvider =
    NotifierProvider<ContactSearchQueryNotifier, String>(
      ContactSearchQueryNotifier.new,
    );

/// Filter state for emergency-only toggle
class EmergencyOnlyFilterNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void setEmergencyOnly(bool value) => state = value;
}

final emergencyOnlyFilterProvider =
    NotifierProvider<EmergencyOnlyFilterNotifier, bool>(
      EmergencyOnlyFilterNotifier.new,
    );

/// Stream provider for all contacts directly from database
final allContactsStreamProvider = StreamProvider<List<Contact>>((ref) {
  final service = ref.watch(contactServiceProvider);
  return service.watchAllContacts();
});

/// Filtered contacts provider combining source filter, emergency toggle, and search query
final filteredContactsProvider = Provider<AsyncValue<List<Contact>>>((ref) {
  final contactsAsync = ref.watch(allContactsStreamProvider);
  final sourceType = ref.watch(selectedContactSourceTypeFilterProvider);
  final emergencyOnly = ref.watch(emergencyOnlyFilterProvider);
  final query = ref.watch(contactSearchQueryProvider).trim().toLowerCase();

  return contactsAsync.whenData((contacts) {
    return contacts.where((contact) {
      // 1. Source type filter
      if (sourceType != null && contact.sourceType != sourceType) {
        return false;
      }

      // 2. Emergency only filter
      if (emergencyOnly && !contact.isEmergency) {
        return false;
      }

      // 3. Search query filter
      if (query.isNotEmpty) {
        final matchesName = contact.name.toLowerCase().contains(query);
        final matchesPhone = contact.phone.toLowerCase().contains(query);
        final matchesRelation =
            contact.relation?.toLowerCase().contains(query) ?? false;
        final matchesSource =
            contact.sourceName?.toLowerCase().contains(query) ?? false;
        final matchesEmail =
            contact.email?.toLowerCase().contains(query) ?? false;
        final matchesOccupation =
            contact.occupation?.toLowerCase().contains(query) ?? false;

        if (!matchesName &&
            !matchesPhone &&
            !matchesRelation &&
            !matchesSource &&
            !matchesEmail &&
            !matchesOccupation) {
          return false;
        }
      }

      return true;
    }).toList();
  });
});

/// Stream provider for emergency contacts
final emergencyContactsStreamProvider = StreamProvider<List<Contact>>((ref) {
  final service = ref.watch(contactServiceProvider);
  return service.watchEmergencyContacts();
});

/// Stream provider for contacts belonging to a specific source
final contactsBySourceProvider =
    StreamProvider.family<List<Contact>, ({ContactSourceType type, int? id})>((
      ref,
      arg,
    ) {
      final service = ref.watch(contactServiceProvider);
      return service.watchContactsBySource(arg.type, arg.id);
    });

/// Provider for student list to link contacts
final studentsListProvider = FutureProvider<List<Student>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.getAllStudents();
});

/// Provider for employee list to link contacts
final employeesListForContactsProvider = FutureProvider<List<Employee>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.getAllEmployees();
});
