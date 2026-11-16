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

  static const int _maxSafeEpochMs = 8640000000000000;

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is num) {
      if (!raw.isFinite || raw.abs() > _maxSafeEpochMs) return null;
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    if (raw is String) {
      final trimmed = raw.trim();
      final epochMs = int.tryParse(trimmed);
      if (epochMs != null && epochMs.abs() <= _maxSafeEpochMs) {
        return DateTime.fromMillisecondsSinceEpoch(epochMs);
      }
      return DateTime.tryParse(trimmed);
    }
    return null;
  }

  static int _parseSafeInt(dynamic raw) {
    if (raw is num) {
      if (!raw.isFinite) return 0;
      return raw is int ? raw : raw.toInt();
    }
    if (raw is String) {
      final t = raw.trim();
      final asInt = int.tryParse(t);
      if (asInt != null) return asInt;
      final asDouble = double.tryParse(t);
      if (asDouble != null && asDouble.isFinite) return asDouble.toInt();
    }
    return 0;
  }

  static bool _isReservedKey(String key) {
    final lower = key.toLowerCase();
    return lower == '__proto__' ||
        lower == 'constructor' ||
        lower == 'prototype' ||
        (key.startsWith('__') && key.endsWith('__'));
  }

  static const int maxOperationsEntries = 200;
  static const int maxRecentErrors = 100;
  static const int maxMessageChars = 2000;

  static final RegExp _unsafeControlOrBidi = RegExp(
    r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F\u0085\u061C\u200B-\u200F\u2028\u2029\u202A-\u202E\u2060-\u2069\uFEFF]',
  );

  static final RegExp _gemma4ThoughtPattern = RegExp(
    r'<\|(?:channel|turn)\s*>?\s*thought\b[\s\S]*?(?:<(?:channel|turn)\|>|$)|<\|tool_call>[\s\S]*?(?:<tool_call\|>|$)',
    caseSensitive: false,
  );

  static final RegExp _internalBlockPattern = RegExp(
    r'<\s*(think|thought|memory_recall|auto_memory|system_context)\b[^>]*>[\s\S]*?(?:<\s*/\s*\1\s*>|$)'
    r'|\[\s*(BIOCHIP|MEMORY_RECALL|AUTO_MEMORY|SYSTEM_CONTEXT)\b[^\]]*\][\s\S]*?\[\s*/\s*\2\b[^\]]*\]',
    caseSensitive: false,
  );

  static final RegExp _danglingInternalTagPattern = RegExp(
    r'<\s*/?\s*(think|thought|memory_recall|auto_memory|system_context)\b[^>]*>'
    r'|\[\s*/?\s*(BIOCHIP|MEMORY_RECALL|AUTO_MEMORY|SYSTEM_CONTEXT)\b[^\]]*\]'
    r'|<\|/?(?:turn|channel|tool_call|eot|im_start|im_end)[^>]*\|?>'
    r'|<(?:turn|channel|tool_call)\|>',
    caseSensitive: false,
  );

  static final RegExp _closingContentBoundary = RegExp(
    r'<\s*/\s*content\s*>',
    caseSensitive: false,
  );

  static final RegExp _sensitiveSecretPattern = RegExp(
    r'(?:Bearer\s+[A-Za-z0-9._~+/=-]+|sk-ant-[A-Za-z0-9_-]{12,}|sk-[A-Za-z0-9_-]{12,}|hf_[A-Za-z0-9]{12,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|whsec_[A-Za-z0-9_-]{12,}|rk_(?:live|test)_[A-Za-z0-9]{12,}|AIza[0-9A-Za-z_-]{20,}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|://[^/\s:@]+:[^/\s@]+@|(?:api[_-]?key|access[_-]?token|refresh[_-]?token|token|secret|password|authorization)\s*[=:]\s*[^\s&",;]+)',
    caseSensitive: false,
  );

  static String _truncateUtf16Safe(String input, int maxChars) {
    if (!maxChars.toDouble().isFinite || maxChars <= 0) return '';
    if (input.length <= maxChars) return input;
    var end = maxChars;
    if (end > 0) {
      final cu = input.codeUnitAt(end - 1);
      if (cu >= 0xD800 && cu <= 0xDBFF) end--;
    }
    if (end <= 0) return '';
    return input.substring(0, end);
  }

  static String redactSensitiveText(String raw, {int maxLength = maxMessageChars}) {
    if (raw.isEmpty || !maxLength.toDouble().isFinite || maxLength <= 0) {
      return '';
    }
    var cleaned = raw
        .replaceAll(_gemma4ThoughtPattern, ' ')
        .replaceAll(_internalBlockPattern, ' ')
        .replaceAll(_danglingInternalTagPattern, ' ')
        .replaceAll(_closingContentBoundary, '[content_end]')
        .replaceAll(_unsafeControlOrBidi, ' ')
        .replaceAll(_sensitiveSecretPattern, '[REDACTED]')
        .trim();
    if (cleaned.length > maxLength) {
      final slice = _truncateUtf16Safe(cleaned, maxLength);
      if (slice.isEmpty) return '';
      cleaned = '$slice...[TRUNCATED]';
    }
    return cleaned;
  }

  factory ErrorLogEntry.fromJSON(Map<String, dynamic> json) {
    final ops = <String, int>{};
    final opsRaw = json['operations'];
    if (opsRaw is Map) {
      for (final entry in opsRaw.entries) {
        if (ops.length >= maxOperationsEntries) break;
        final rawKey = entry.key.toString().trim();
        if (_isReservedKey(rawKey)) continue;
        final k = redactSensitiveText(rawKey, maxLength: 160);
        if (k.isEmpty || _isReservedKey(k)) continue;
        ops[k] = _parseSafeInt(entry.value);
      }
    }

    final recent = <RecentError>[];
    final recentRaw = json['recentErrors'];
    if (recentRaw is List) {
      for (final item in recentRaw) {
        if (recent.length >= maxRecentErrors) break;
        if (item is Map) {
          recent.add(RecentError.fromJSON(Map<String, dynamic>.from(item)));
        }
      }
    }

    final parsedTotal = _parseSafeInt(json['totalErrors']);
    return ErrorLogEntry(
      module: redactSensitiveText(json['module']?.toString() ?? '', maxLength: 120),
      totalErrors: parsedTotal < 0 ? 0 : parsedTotal,
      operations: ops,
      recentErrors: recent,
      lastErrorAt: _parseDateTime(json['lastErrorAt']),
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
    return RecentError(
      operation: ErrorLogEntry.redactSensitiveText(
        json['operation']?.toString() ?? '',
        maxLength: 160,
      ),
      message: ErrorLogEntry.redactSensitiveText(
        json['message']?.toString() ?? '',
      ),
      timestamp: ErrorLogEntry._parseDateTime(json['timestamp']),
    );
  }
}
