// lib/core/logging/app_logger.dart
import 'dart:developer' as developer;

enum LogLevel { debug, info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String module;
  final String operation;
  final String? message;
  final Map<String, dynamic>? context;
  final Object? error;
  final StackTrace? stackTrace;
  final String? userId;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.module,
    required this.operation,
    this.message,
    this.context,
    this.error,
    this.stackTrace,
    this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name.toUpperCase(),
      'module': module,
      'operation': operation,
      if (message != null) 'message': message,
      if (context != null) 'context': _maskSensitiveData(context!),
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stackTrace': stackTrace.toString(),
      if (userId != null) 'userId': userId,
    };
  }

  static Map<String, dynamic> _maskSensitiveData(Map<String, dynamic> input) {
    const sensitiveKeys = {
      'password',
      'passwordHash',
      'salt',
      'secret',
      'token',
      'candidatePassword',
    };

    final result = <String, dynamic>{};
    for (final entry in input.entries) {
      if (sensitiveKeys.contains(entry.key.toLowerCase())) {
        result[entry.key] = '***REDACTED***';
      } else if (entry.value is Map<String, dynamic>) {
        result[entry.key] = _maskSensitiveData(
          entry.value as Map<String, dynamic>,
        );
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write(
      '[${timestamp.toIso8601String()}] [${level.name.toUpperCase()}] ',
    );
    buffer.write('[$module::$operation]');
    if (userId != null) buffer.write(' [User: $userId]');
    if (message != null) buffer.write(' $message');
    if (context != null && context!.isNotEmpty) {
      buffer.write(' Context: ${_maskSensitiveData(context!)}');
    }
    if (error != null) buffer.write(' Error: $error');
    return buffer.toString();
  }
}

class AppLogger {
  static final List<LogEntry> _inMemoryLogs = [];
  static const int _maxInMemoryLogs = 200;

  static List<LogEntry> get recentLogs => List.unmodifiable(_inMemoryLogs);

  static void debug(
    String module,
    String operation, {
    String? message,
    Map<String, dynamic>? context,
    String? userId,
  }) {
    _log(
      LogLevel.debug,
      module,
      operation,
      message: message,
      context: context,
      userId: userId,
    );
  }

  static void info(
    String module,
    String operation, {
    String? message,
    Map<String, dynamic>? context,
    String? userId,
  }) {
    _log(
      LogLevel.info,
      module,
      operation,
      message: message,
      context: context,
      userId: userId,
    );
  }

  static void warning(
    String module,
    String operation, {
    String? message,
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
    String? userId,
  }) {
    _log(
      LogLevel.warning,
      module,
      operation,
      message: message,
      context: context,
      error: error,
      stackTrace: stackTrace,
      userId: userId,
    );
  }

  static void error(
    String module,
    String operation, {
    String? message,
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
    String? userId,
  }) {
    _log(
      LogLevel.error,
      module,
      operation,
      message: message,
      context: context,
      error: error,
      stackTrace: stackTrace,
      userId: userId,
    );
  }

  static void _log(
    LogLevel level,
    String module,
    String operation, {
    String? message,
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
    String? userId,
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now().toUtc(),
      level: level,
      module: module,
      operation: operation,
      message: message,
      context: context,
      error: error,
      stackTrace: stackTrace,
      userId: userId,
    );

    _inMemoryLogs.add(entry);
    if (_inMemoryLogs.length > _maxInMemoryLogs) {
      _inMemoryLogs.removeAt(0);
    }

    developer.log(
      entry.toString(),
      name: 'SMS.$module',
      level: _levelToInt(level),
      error: error,
      stackTrace: stackTrace,
    );
  }

  static int _levelToInt(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }

  static void clearLogs() {
    _inMemoryLogs.clear();
  }
}
