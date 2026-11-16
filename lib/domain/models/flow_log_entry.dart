/// Model for flow tracking data from Firestore `flowLogs` collection.
class FlowLogEntry {
  final String flowName;
  final int totalCompletions;
  final int totalFailures;
  final int avgDurationMs;
  final Map<String, FlowStepEntry> steps;
  final List<RecentFlowEntry> recentFlows;

  static const int maxStepsEntries = 200;
  static const int maxRecentFlowsEntries = 100;
  static const int maxScreenEntries = 500;
  static const int _maxSafeEpochMs = 8640000000000000;

  static final RegExp _unsafeControlOrBidi = RegExp(
    r'[\x00-\x1F\x7F-\x9F\u0085\u061C\u200B-\u200F\u2028\u2029\u202A-\u202E\u2060-\u2069\uFEFF]',
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

  static int parseSafeNonNegInt(dynamic raw) {
    int parsed = 0;
    if (raw is num) {
      if (raw.isFinite) {
        parsed = raw is int ? raw : raw.toInt();
      }
    } else if (raw is String) {
      final t = raw.trim();
      final asInt = int.tryParse(t);
      if (asInt != null) {
        parsed = asInt;
      } else {
        final asDouble = double.tryParse(t);
        if (asDouble != null && asDouble.isFinite) parsed = asDouble.toInt();
      }
    }
    return parsed < 0 ? 0 : parsed;
  }

  static bool isReservedKey(String key) {
    final lower = key.toLowerCase();
    return lower == '__proto__' ||
        lower == 'constructor' ||
        lower == 'prototype' ||
        (key.startsWith('__') && key.endsWith('__'));
  }

  static String sanitizeLabel(String raw, {int maxChars = 160}) {
    if (raw.isEmpty || !maxChars.toDouble().isFinite || maxChars <= 0) {
      return '';
    }
    var cleaned = raw
        .replaceAll(_gemma4ThoughtPattern, ' ')
        .replaceAll(_internalBlockPattern, ' ')
        .replaceAll(_danglingInternalTagPattern, ' ')
        .replaceAll(_closingContentBoundary, '[content_end]')
        .replaceAll(_unsafeControlOrBidi, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.length > maxChars) {
      var end = maxChars;
      if (end > 0) {
        final cu = cleaned.codeUnitAt(end - 1);
        if (cu >= 0xD800 && cu <= 0xDBFF) end--;
      }
      if (end <= 0) return '';
      cleaned = cleaned.substring(0, end).trimRight();
    }
    return cleaned;
  }

  FlowLogEntry({
    required this.flowName,
    required this.totalCompletions,
    required this.totalFailures,
    required this.avgDurationMs,
    required this.steps,
    required this.recentFlows,
  });

  factory FlowLogEntry.fromJSON(Map<String, dynamic> json) {
    final stepsMap = <String, FlowStepEntry>{};
    final rawSteps = json['steps'];
    if (rawSteps is Map) {
      for (final entry in rawSteps.entries) {
        if (stepsMap.length >= maxStepsEntries) break;
        final rawKey = entry.key.toString().trim();
        if (isReservedKey(rawKey)) continue;
        final cleanKey = sanitizeLabel(rawKey, maxChars: 120);
        if (cleanKey.isEmpty || isReservedKey(cleanKey)) continue;
        if (entry.value is Map) {
          stepsMap[cleanKey] = FlowStepEntry.fromJSON(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    }

    final recentList = <RecentFlowEntry>[];
    final rawRecent = json['recentFlows'];
    if (rawRecent is List) {
      for (final item in rawRecent) {
        if (recentList.length >= maxRecentFlowsEntries) break;
        if (item is Map) {
          recentList.add(
            RecentFlowEntry.fromJSON(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return FlowLogEntry(
      flowName: sanitizeLabel(json['flowName']?.toString() ?? ''),
      totalCompletions: parseSafeNonNegInt(json['totalCompletions']),
      totalFailures: parseSafeNonNegInt(json['totalFailures']),
      avgDurationMs: parseSafeNonNegInt(json['avgDurationMs']),
      steps: stepsMap,
      recentFlows: recentList,
    );
  }

  int get totalAttempts => totalCompletions + totalFailures;

  double get successRate => totalAttempts > 0 ? totalCompletions / totalAttempts : 0;

  String get avgDurationFormatted {
    if (avgDurationMs < 1000) return '${avgDurationMs}ms';
    final seconds = avgDurationMs / 1000;
    if (seconds < 60) return '${seconds.toStringAsFixed(1)}s';
    final minutes = seconds / 60;
    return '${minutes.toStringAsFixed(1)}min';
  }

  String get displayName {
    return flowName.replaceAll('_', ' ').split(' ').map((w) =>
      w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : ''
    ).join(' ');
  }

  List<MapEntry<String, FlowStepEntry>> get sortedSteps {
    final entries = steps.entries.toList();
    entries.sort((a, b) => (a.value.avgDurationMs).compareTo(b.value.avgDurationMs));
    return entries;
  }
}

class FlowStepEntry {
  final int count;
  final int avgDurationMs;

  FlowStepEntry({required this.count, required this.avgDurationMs});

  factory FlowStepEntry.fromJSON(Map<String, dynamic> json) {
    return FlowStepEntry(
      count: FlowLogEntry.parseSafeNonNegInt(json['count']),
      avgDurationMs: FlowLogEntry.parseSafeNonNegInt(json['avgDurationMs']),
    );
  }

  String get avgDurationFormatted {
    if (avgDurationMs < 1000) return '${avgDurationMs}ms';
    final seconds = avgDurationMs / 1000;
    if (seconds < 60) return '${seconds.toStringAsFixed(1)}s';
    final minutes = seconds / 60;
    return '${minutes.toStringAsFixed(1)}min';
  }
}

class RecentFlowEntry {
  final String userId;
  final int durationMs;
  final bool success;
  final DateTime? timestamp;

  RecentFlowEntry({
    required this.userId,
    required this.durationMs,
    required this.success,
    this.timestamp,
  });

  static DateTime? _parseTimestamp(dynamic rawTs) {
    if (rawTs == null) return null;
    if (rawTs is num) {
      if (!rawTs.isFinite || rawTs.abs() > FlowLogEntry._maxSafeEpochMs) {
        return null;
      }
      return DateTime.fromMillisecondsSinceEpoch(rawTs.toInt());
    }
    if (rawTs is String) {
      final trimmed = rawTs.trim();
      final epochMs = int.tryParse(trimmed);
      if (epochMs != null && epochMs.abs() <= FlowLogEntry._maxSafeEpochMs) {
        return DateTime.fromMillisecondsSinceEpoch(epochMs);
      }
      return DateTime.tryParse(trimmed);
    }
    try {
      final converted = (rawTs as dynamic).toDate();
      if (converted is DateTime) return converted;
    } catch (_) {}
    return null;
  }

  factory RecentFlowEntry.fromJSON(Map<String, dynamic> json) {
    return RecentFlowEntry(
      userId: FlowLogEntry.sanitizeLabel(
        json['userId']?.toString() ?? '',
        maxChars: 128,
      ),
      durationMs: FlowLogEntry.parseSafeNonNegInt(json['durationMs']),
      success: json['success'] is bool ? json['success'] as bool : true,
      timestamp: _parseTimestamp(json['timestamp']),
    );
  }

  String get durationFormatted {
    if (durationMs < 1000) return '${durationMs}ms';
    final seconds = durationMs / 1000;
    if (seconds < 60) return '${seconds.toStringAsFixed(1)}s';
    final minutes = seconds / 60;
    return '${minutes.toStringAsFixed(1)}min';
  }
}

/// Model for screen visit data from Firestore `screenLogs` collection.
class ScreenLogEntry {
  final String date;
  final Map<String, int> screens;
  final int totalVisits;
  final int uniqueUsers;

  ScreenLogEntry({
    required this.date,
    required this.screens,
    required this.totalVisits,
    required this.uniqueUsers,
  });

  factory ScreenLogEntry.fromJSON(Map<String, dynamic> json) {
    final screens = <String, int>{};
    final rawScreens = json['screens'];
    if (rawScreens is Map) {
      for (final entry in rawScreens.entries) {
        if (screens.length >= FlowLogEntry.maxScreenEntries) break;
        final rawKey = entry.key.toString().trim();
        if (FlowLogEntry.isReservedKey(rawKey)) continue;
        final cleanKey = FlowLogEntry.sanitizeLabel(rawKey, maxChars: 160);
        if (cleanKey.isEmpty || FlowLogEntry.isReservedKey(cleanKey)) continue;
        screens[cleanKey] = FlowLogEntry.parseSafeNonNegInt(entry.value);
      }
    }

    return ScreenLogEntry(
      date: FlowLogEntry.sanitizeLabel(
        json['date']?.toString() ?? '',
        maxChars: 32,
      ),
      screens: screens,
      totalVisits: FlowLogEntry.parseSafeNonNegInt(json['totalVisits']),
      uniqueUsers: FlowLogEntry.parseSafeNonNegInt(json['uniqueUsers']),
    );
  }

  List<MapEntry<String, int>> get sortedScreens {
    final entries = screens.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }
}
