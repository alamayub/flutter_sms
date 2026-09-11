import 'package:drift/native.dart';
import 'package:sms/data/app_database.dart';
import 'package:sms/services/contact_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ContactService service;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    service = ContactService(db);
    // Clear pre-seeded contacts for clean test isolation
    await db.customStatement('DELETE FROM contacts;');
  });

  tearDown(() async {
    await db.close();
  });

  group('ContactService Validation Tests', () {
    test('rejects empty or whitespace-only name', () {
      expect(
        () => service.validateContact(name: '', phone: '9841223344'),
        throwsA(isA<ContactValidationException>()),
      );
      expect(
        () => service.validateContact(name: '   ', phone: '9841223344'),
        throwsA(isA<ContactValidationException>()),
      );
    });

    test('rejects name shorter than 2 characters', () {
      expect(
        () => service.validateContact(name: 'A', phone: '9841223344'),
        throwsA(isA<ContactValidationException>()),
      );
    });

    test('rejects empty or invalid phone number', () {
      expect(
        () => service.validateContact(name: 'Valid Name', phone: ''),
        throwsA(isA<ContactValidationException>()),
      );
      expect(
        () => service.validateContact(name: 'Valid Name', phone: '12'),
        throwsA(isA<ContactValidationException>()),
      );
      expect(
        () => service.validateContact(
          name: 'Valid Name',
          phone: 'invalid-phone-abc',
        ),
        throwsA(isA<ContactValidationException>()),
      );
    });

    test('accepts valid phone numbers in different formats', () {
      expect(
        () => service.validateContact(name: 'Valid Name', phone: '9841223344'),
        returnsNormally,
      );
      expect(
        () => service.validateContact(
          name: 'Valid Name',
          phone: '+977-9841223344',
        ),
        returnsNormally,
      );
      expect(
        () => service.validateContact(
          name: 'Valid Name',
          phone: '+1 800 555 1234',
        ),
        returnsNormally,
      );
    });

    test('validates email format when provided', () {
      expect(
        () => service.validateContact(
          name: 'Valid Name',
          phone: '9841223344',
          email: 'not-an-email',
        ),
        throwsA(isA<ContactValidationException>()),
      );
      expect(
        () => service.validateContact(
          name: 'Valid Name',
          phone: '9841223344',
          email: 'valid.user@example.com',
        ),
        returnsNormally,
      );
    });
  });

  group('Contact Database CRUD & Source Tests', () {
    test('creates and retrieves student contact with details', () async {
      final id = await service.createContact(
        sourceType: ContactSourceType.student,
        sourceId: 101,
        sourceName: 'Aarav Sharma (Student)',
        name: 'Mukesh Sharma',
        phone: '9841223344',
        relation: 'Father',
        email: 'mukesh@example.com',
        address: 'Kathmandu-3',
        occupation: 'Civil Engineer',
        isEmergency: true,
        isPrimary: true,
        notes: 'Call between 9 AM and 5 PM',
      );

      expect(id, isPositive);

      final contacts = await service.getAllContacts();
      expect(contacts.length, 1);
      final c = contacts.first;
      expect(c.name, 'Mukesh Sharma');
      expect(c.phone, '9841223344');
      expect(c.relation, 'Father');
      expect(c.sourceType, ContactSourceType.student);
      expect(c.sourceId, 101);
      expect(c.sourceName, 'Aarav Sharma (Student)');
      expect(c.isEmergency, isTrue);
      expect(c.isPrimary, isTrue);
      expect(c.occupation, 'Civil Engineer');
      expect(c.notes, 'Call between 9 AM and 5 PM');
    });

    test('creates employee contact and general contact', () async {
      await service.createContact(
        sourceType: ContactSourceType.employee,
        sourceId: 201,
        sourceName: 'Ram Shrestha (EMP-001)',
        name: 'Sharmila Shrestha',
        phone: '9851011223',
        relation: 'Spouse',
        isEmergency: true,
      );

      await service.createContact(
        sourceType: ContactSourceType.other,
        sourceName: 'Emergency Services',
        name: 'Red Cross Ambulance',
        phone: '102',
        relation: 'Ambulance',
        isEmergency: true,
      );

      final all = await service.getAllContacts();
      expect(all.length, 2);

      final empContacts = await service.getContactsBySource(
        ContactSourceType.employee,
        201,
      );
      expect(empContacts.length, 1);
      expect(empContacts.first.name, 'Sharmila Shrestha');

      final generalContacts = await service.getContactsBySource(
        ContactSourceType.other,
        null,
      );
      expect(generalContacts.length, 1);
      expect(generalContacts.first.name, 'Red Cross Ambulance');
    });

    test('enforces single primary contact for the same entity', () async {
      final id1 = await service.createContact(
        sourceType: ContactSourceType.student,
        sourceId: 101,
        name: 'Father Contact',
        phone: '9841111111',
        relation: 'Father',
        isPrimary: true,
      );

      final id2 = await service.createContact(
        sourceType: ContactSourceType.student,
        sourceId: 101,
        name: 'Mother Contact',
        phone: '9842222222',
        relation: 'Mother',
        isPrimary: true, // Should unmark id1 as primary
      );

      final contacts = await service.getContactsBySource(
        ContactSourceType.student,
        101,
      );
      final c1 = contacts.firstWhere((c) => c.id == id1);
      final c2 = contacts.firstWhere((c) => c.id == id2);

      expect(c1.isPrimary, isFalse);
      expect(c2.isPrimary, isTrue);
    });

    test('updates existing contact correctly', () async {
      final id = await service.createContact(
        sourceType: ContactSourceType.employee,
        sourceId: 50,
        name: 'Initial Name',
        phone: '9841000000',
        relation: 'Brother',
      );

      final success = await service.updateContact(
        id: id,
        sourceType: ContactSourceType.employee,
        sourceId: 50,
        name: 'Updated Name',
        phone: '9841999999',
        relation: 'Sibling',
        isEmergency: true,
      );

      expect(success, isTrue);

      final contacts = await service.getAllContacts();
      final updated = contacts.firstWhere((c) => c.id == id);
      expect(updated.name, 'Updated Name');
      expect(updated.phone, '9841999999');
      expect(updated.relation, 'Sibling');
      expect(updated.isEmergency, isTrue);
    });

    test('deletes contact by ID and by source entity', () async {
      final id1 = await service.createContact(
        sourceType: ContactSourceType.student,
        sourceId: 77,
        name: 'Contact 1',
        phone: '9841000001',
      );
      await service.createContact(
        sourceType: ContactSourceType.student,
        sourceId: 77,
        name: 'Contact 2',
        phone: '9841000002',
      );
      final id3 = await service.createContact(
        sourceType: ContactSourceType.student,
        sourceId: 88,
        name: 'Contact 3',
        phone: '9841000003',
      );

      expect((await service.getAllContacts()).length, 3);

      // Delete by ID
      await service.deleteContact(id1);
      expect((await service.getAllContacts()).length, 2);

      // Delete all contacts for student 77
      await service.deleteContactsBySource(ContactSourceType.student, 77);
      final remaining = await service.getAllContacts();
      expect(remaining.length, 1);
      expect(remaining.first.id, id3);
    });

    test('filters emergency contacts', () async {
      await service.createContact(
        sourceType: ContactSourceType.student,
        name: 'Normal Contact',
        phone: '9841000001',
        isEmergency: false,
      );
      await service.createContact(
        sourceType: ContactSourceType.other,
        name: 'Emergency Doctor',
        phone: '9841000002',
        isEmergency: true,
      );

      final emergencies = await service.watchEmergencyContacts().first;
      expect(emergencies.length, 1);
      expect(emergencies.first.name, 'Emergency Doctor');
    });

    test('searches contacts by name, phone, relation, or sourceName', () async {
      await service.createContact(
        sourceType: ContactSourceType.student,
        sourceName: 'Aarav Sharma',
        name: 'Mukesh Sharma',
        phone: '9841223344',
        relation: 'Father',
      );
      await service.createContact(
        sourceType: ContactSourceType.employee,
        sourceName: 'Gita Adhikari (TCH-004)',
        name: 'Rajan Adhikari',
        phone: '9851044556',
        relation: 'Brother',
      );

      // Match name
      final matchName = await service.searchContacts('mukesh');
      expect(matchName.length, 1);
      expect(matchName.first.name, 'Mukesh Sharma');

      // Match phone
      final matchPhone = await service.searchContacts('044556');
      expect(matchPhone.length, 1);
      expect(matchPhone.first.name, 'Rajan Adhikari');

      // Match relation
      final matchRelation = await service.searchContacts('father');
      expect(matchRelation.length, 1);
      expect(matchRelation.first.relation, 'Father');

      // Match sourceName
      final matchSource = await service.searchContacts('TCH-004');
      expect(matchSource.length, 1);
      expect(matchSource.first.name, 'Rajan Adhikari');
    });
  });
}
