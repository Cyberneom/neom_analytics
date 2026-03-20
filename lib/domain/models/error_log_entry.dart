import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents aggregated error data for a single module.
class ErrorLogEntry {
  final String module;
  final int totalErrors;
  final Map<String, int> operations;
  final List<RecentError> recentErrors;
  final DateTime? lastErrorAt;

  ErrorLogEntry({
    this.module = '',
    this.totalErrors = 0,
    this.operations = const {},
    this.recentErrors = const [],
    this.lastErrorAt,
  });

  factory ErrorLogEntry.fromJSON(Map<String, dynamic> json) {
    final opsRaw = json['operations'] as Map<String, dynamic>? ?? {};
    final ops = opsRaw.map((k, v) => MapEntry(k, (v as num).toInt()));

    final recentRaw = json['recentErrors'] as List? ?? [];
    final recent = recentRaw
        .map((e) => RecentError.fromJSON(e as Map<String, dynamic>))
        .toList();

    DateTime? lastError;
    if (json['lastErrorAt'] != null) {
      if (json['lastErrorAt'] is Timestamp) {
        lastError = (json['lastErrorAt'] as Timestamp).toDate();
      }
    }

    return ErrorLogEntry(
      module: json['module']?.toString() ?? '',
      totalErrors: (json['totalErrors'] as num?)?.toInt() ?? 0,
      operations: ops,
      recentErrors: recent,
      lastErrorAt: lastError,
    );
  }

  /// Returns operations sorted by count descending.
  List<MapEntry<String, int>> get sortedOperations {
    final entries = operations.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  /// Module display name without 'neom_' prefix.
  String get displayName {
    if (module.startsWith('neom_')) return module.substring(5);
    return module;
  }
}

class RecentError {
  final String operation;
  final String message;
  final DateTime? timestamp;

  RecentError({
    this.operation = '',
    this.message = '',
    this.timestamp,
  });

  factory RecentError.fromJSON(Map<String, dynamic> json) {
    DateTime? ts;
    if (json['timestamp'] != null) {
      if (json['timestamp'] is Timestamp) {
        ts = (json['timestamp'] as Timestamp).toDate();
      }
    }

    return RecentError(
      operation: json['operation']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      timestamp: ts,
    );
  }
}
