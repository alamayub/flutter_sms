import 'package:drift/drift.dart';
import '../data/app_database.dart';

class ContactValidationException implements Exception {
  final String message;
  const ContactValidationException(this.message);

  @override
  String toString() => message;
}

class ContactService {
  final AppDatabase db;

  const ContactService(this.db);

  /// Validates contact input fields
  void validateContact({
    required String name,
    required String phone,
    String? email,
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const ContactValidationException('Contact name cannot be empty');
    }
    if (trimmedName.length < 2) {
      throw const ContactValidationException(
        'Contact name must be at least 2 characters',
      );
    }
    if (trimmedName.length > 100) {
      throw const ContactValidationException(
        'Contact name cannot exceed 100 characters',
      );
    }

    final trimmedPhone = phone.trim();
    if (trimmedPhone.isEmpty) {
      throw const ContactValidationException('Phone number cannot be empty');
    }
    // Check phone format: optional '+' followed by digits, dashes, or spaces (3 to 25 chars, allowing hotlines like 100/102)
    final phoneRegex = RegExp(r'^\+?[0-9\s\-]{3,25}$');
    if (!phoneRegex.hasMatch(trimmedPhone)) {
      throw const ContactValidationException(
        'Please enter a valid phone number (3-25 digits)',
      );
    }

    if (email != null && email.trim().isNotEmpty) {
      final emailRegex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$');
      if (!emailRegex.hasMatch(email.trim())) {
        throw const ContactValidationException(
          'Please enter a valid email address',
        );
      }
    }
  }

  /// Watch all contacts ordered alphabetically
  Stream<List<Contact>> watchAllContacts() => db.watchAllContacts();

  /// Get all contacts
  Future<List<Contact>> getAllContacts() => db.getAllContacts();

  /// Watch contacts for a specific source
  Stream<List<Contact>> watchContactsBySource(
    ContactSourceType sourceType,
    int? sourceId,
  ) => db.watchContactsBySource(sourceType, sourceId);

  /// Get contacts for a specific source
  Future<List<Contact>> getContactsBySource(
    ContactSourceType sourceType,
    int? sourceId,
  ) => db.getContactsBySource(sourceType, sourceId);

  /// Watch emergency contacts
  Stream<List<Contact>> watchEmergencyContacts() => db.watchEmergencyContacts();

  /// Search contacts by query
  Future<List<Contact>> searchContacts(String query) =>
      db.searchContacts(query);

  /// Create a new contact
  Future<int> createContact({
    required ContactSourceType sourceType,
    int? sourceId,
    String? sourceName,
    required String name,
    required String phone,
    String? relation,
    String? email,
    String? address,
    String? occupation,
    bool isEmergency = false,
    bool isPrimary = false,
    String? notes,
  }) async {
    validateContact(name: name, phone: phone, email: email);

    // If marked as primary, unmark any existing primary contacts for the same source entity
    if (isPrimary && sourceId != null) {
      await _clearExistingPrimary(sourceType, sourceId);
    }

    final companion = ContactsCompanion(
      sourceType: Value(sourceType),
      sourceId: Value(sourceId),
      sourceName: Value(
        sourceName?.trim().isEmpty == true ? null : sourceName?.trim(),
      ),
      name: Value(name.trim()),
      phone: Value(phone.trim()),
      relation: Value(
        relation?.trim().isEmpty == true ? null : relation?.trim(),
      ),
      email: Value(email?.trim().isEmpty == true ? null : email?.trim()),
      address: Value(address?.trim().isEmpty == true ? null : address?.trim()),
      occupation: Value(
        occupation?.trim().isEmpty == true ? null : occupation?.trim(),
      ),
      isEmergency: Value(isEmergency),
      isPrimary: Value(isPrimary),
      notes: Value(notes?.trim().isEmpty == true ? null : notes?.trim()),
    );

    return db.insertContact(companion);
  }

  /// Update an existing contact
  Future<bool> updateContact({
    required int id,
    required ContactSourceType sourceType,
    int? sourceId,
    String? sourceName,
    required String name,
    required String phone,
    String? relation,
    String? email,
    String? address,
    String? occupation,
    bool isEmergency = false,
    bool isPrimary = false,
    String? notes,
  }) async {
    validateContact(name: name, phone: phone, email: email);

    if (isPrimary && sourceId != null) {
      await _clearExistingPrimary(sourceType, sourceId, excludeId: id);
    }

    final entry = Contact(
      id: id,
      sourceType: sourceType,
      sourceId: sourceId,
      sourceName:
          sourceName?.trim().isEmpty == true ? null : sourceName?.trim(),
      name: name.trim(),
      phone: phone.trim(),
      relation: relation?.trim().isEmpty == true ? null : relation?.trim(),
      email: email?.trim().isEmpty == true ? null : email?.trim(),
      address: address?.trim().isEmpty == true ? null : address?.trim(),
      occupation:
          occupation?.trim().isEmpty == true ? null : occupation?.trim(),
      isEmergency: isEmergency,
      isPrimary: isPrimary,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      createdAt: DateTime.now(),
    );

    return db.updateContactEntry(entry);
  }

  /// Delete a contact
  Future<int> deleteContact(int id) => db.deleteContactEntry(id);

  /// Delete all contacts for a specific entity
  Future<int> deleteContactsBySource(
    ContactSourceType sourceType,
    int sourceId,
  ) => db.deleteContactsBySource(sourceType, sourceId);

  /// Unmarks isPrimary for existing contacts of this source entity
  Future<void> _clearExistingPrimary(
    ContactSourceType sourceType,
    int sourceId, {
    int? excludeId,
  }) async {
    final existing = await db.getContactsBySource(sourceType, sourceId);
    for (final c in existing) {
      if (c.isPrimary && (excludeId == null || c.id != excludeId)) {
        await db.updateContactEntry(c.copyWith(isPrimary: false));
      }
    }
  }
}
