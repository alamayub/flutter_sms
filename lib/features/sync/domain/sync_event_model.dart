// lib/features/sync/domain/sync_event_model.dart
import 'dart:convert';
import '../../../core/database/app_database.dart';

class SyncEventModel {
  final String eventId;
  final String schoolId;
  final String deviceId;
  final String userId;
  final String entityType;
  final String entityId;
  final String operation; // 'create', 'update', 'delete'
  final int version;
  final Map<String, dynamic> payload;
  final int? serverSequence;
  final String status; // 'pending', 'sending', 'synced', 'failed'
  final DateTime timestamp;

  const SyncEventModel({
    required this.eventId,
    required this.schoolId,
    required this.deviceId,
    required this.userId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    this.version = 1,
    required this.payload,
    this.serverSequence,
    this.status = 'pending',
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'schoolId': schoolId,
    'deviceId': deviceId,
    'userId': userId,
    'entityType': entityType,
    'entityId': entityId,
    'operation': operation,
    'version': version,
    'payload': payload,
    if (serverSequence != null) 'serverSequence': serverSequence,
    'status': status,
    'timestamp': timestamp.toIso8601String(),
  };

  factory SyncEventModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> payloadMap;
    final rawPayload = json['payload'];
    if (rawPayload is String) {
      payloadMap = jsonDecode(rawPayload) as Map<String, dynamic>;
    } else if (rawPayload is Map<String, dynamic>) {
      payloadMap = rawPayload;
    } else {
      payloadMap = {};
    }

    return SyncEventModel(
      eventId: json['eventId'] as String,
      schoolId: json['schoolId'] as String,
      deviceId: json['deviceId'] as String,
      userId: json['userId'] as String,
      entityType: json['entityType'] as String,
      entityId: json['entityId'] as String,
      operation: json['operation'] as String,
      version: json['version'] as int? ?? 1,
      payload: payloadMap,
      serverSequence: json['serverSequence'] as int?,
      status: json['status'] as String? ?? 'pending',
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  factory SyncEventModel.fromTableData(SyncEvent data) {
    Map<String, dynamic> payloadMap;
    try {
      payloadMap = jsonDecode(data.payload) as Map<String, dynamic>;
    } catch (_) {
      payloadMap = {};
    }

    return SyncEventModel(
      eventId: data.eventId,
      schoolId: data.schoolId,
      deviceId: data.deviceId,
      userId: data.userId,
      entityType: data.entityType,
      entityId: data.entityId,
      operation: data.operation,
      version: data.version,
      payload: payloadMap,
      serverSequence: data.serverSequence,
      status: data.status,
      timestamp: data.createdAt,
    );
  }

  SyncEventModel copyWith({
    String? status,
    int? serverSequence,
    Map<String, dynamic>? payload,
  }) {
    return SyncEventModel(
      eventId: eventId,
      schoolId: schoolId,
      deviceId: deviceId,
      userId: userId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      version: version,
      payload: payload ?? this.payload,
      serverSequence: serverSequence ?? this.serverSequence,
      status: status ?? this.status,
      timestamp: timestamp,
    );
  }
}
