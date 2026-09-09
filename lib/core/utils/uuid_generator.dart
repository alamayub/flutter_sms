// lib/core/utils/uuid_generator.dart
import 'package:uuid/uuid.dart';

class UuidGenerator {
  static const Uuid _uuid = Uuid();

  static String v4() => _uuid.v4();
}
