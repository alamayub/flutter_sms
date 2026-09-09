// lib/core/errors/app_exceptions.dart

class AppException implements Exception {
  final String message;
  final String? technicalDetails;

  const AppException(this.message, [this.technicalDetails]);

  @override
  String toString() => message;
}

class ValidationException extends AppException {
  const ValidationException(super.message, [super.technicalDetails]);
}

class ConflictException extends AppException {
  const ConflictException(super.message, [super.technicalDetails]);
}

class NotFoundException extends AppException {
  const NotFoundException(super.message, [super.technicalDetails]);
}

class AuthException extends AppException {
  const AuthException(super.message, [super.technicalDetails]);
}

class DatabaseOperationException extends AppException {
  const DatabaseOperationException(super.message, [super.technicalDetails]);
}

class BackupException extends AppException {
  const BackupException(super.message, [super.technicalDetails]);
}
