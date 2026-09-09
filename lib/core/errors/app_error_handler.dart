// lib/core/errors/app_error_handler.dart
import 'dart:io';
import '../logging/app_logger.dart';
import 'app_exceptions.dart';

class AppErrorHandler {
  /// Alias for toUserMessage
  static String toUserFriendlyMessage(
    Object error, {
    String module = 'System',
    String operation = 'Operation',
    StackTrace? stackTrace,
    String? userId,
  }) => toUserMessage(
        error,
        module: module,
        operation: operation,
        stackTrace: stackTrace,
        userId: userId,
      );

  /// Converts any application or database error into an understandable user message
  /// while logging the raw technical exception and stack trace.
  static String toUserMessage(
    Object error, {
    String module = 'System',
    String operation = 'Operation',
    StackTrace? stackTrace,
    String? userId,
  }) {
    AppLogger.error(
      module,
      operation,
      message: 'Exception handled by AppErrorHandler',
      error: error,
      stackTrace: stackTrace,
      userId: userId,
    );

    if (error is AuthException) {
      return error.message;
    }

    if (error is ConflictException) {
      return error.message;
    }

    if (error is ValidationException) {
      return error.message;
    }

    if (error is NotFoundException) {
      return error.message;
    }

    if (error is BackupException) {
      return error.message;
    }

    if (error is FileSystemException) {
      if (error.osError?.errorCode == 28 ||
          error.message.toLowerCase().contains('space') ||
          error.message.toLowerCase().contains('storage')) {
        return 'Unable to complete operation. There may not be enough storage available on this device. Your existing school data has not been changed.';
      }
      return 'File system error: Unable to read or write data to local storage. Please check device permissions.';
    }

    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('sqlite') || errorStr.contains('database')) {
      if (errorStr.contains('unique constraint') ||
          errorStr.contains('unique')) {
        return 'A record with this code, name, or identifier already exists in the system.';
      }
      if (errorStr.contains('foreign key') ||
          errorStr.contains('foreign_key')) {
        return 'Cannot perform this action because related records depend on this data.';
      }
      if (errorStr.contains('readonly') || errorStr.contains('disk full')) {
        return 'Storage error: Local database cannot write changes. Please check available disk space.';
      }
      return 'A local database error occurred. Your data has been protected. Please try again.';
    }

    return 'An unexpected error occurred. Please try again or contact your school technical lead.';
  }
}
