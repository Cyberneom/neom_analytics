/// Model for flow tracking data from Firestore `flowLogs` collection.
class FlowLogEntry {
  final String flowName;
  final int totalCompletions;
  final int totalFailures;
  final int avgDurationMs;
  final Map<String, FlowStepEntry> steps;
  final List<RecentFlowEntry> recentFlows;

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
    final rawSteps = json['steps'] as Map<String, dynamic>? ?? {};
    for (final entry in rawSteps.entries) {
      stepsMap[entry.key] = FlowStepEntry.fromJSON(entry.value as Map<String, dynamic>);
    }

    final recentList = <RecentFlowEntry>[];
    final rawRecent = json['recentFlows'] as List<dynamic>? ?? [];
    for (final item in rawRecent) {
      recentList.add(RecentFlowEntry.fromJSON(item as Map<String, dynamic>));
    }

    return FlowLogEntry(
      flowName: json['flowName']?.toString() ?? '',
      totalCompletions: (json['totalCompletions'] as int?) ?? 0,
      totalFailures: (json['totalFailures'] as int?) ?? 0,
      avgDurationMs: (json['avgDurationMs'] as num?)?.toInt() ?? 0,
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
      count: (json['count'] as int?) ?? 0,
      avgDurationMs: (json['avgDurationMs'] as num?)?.toInt() ?? 0,
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

  factory RecentFlowEntry.fromJSON(Map<String, dynamic> json) {
    DateTime? ts;
    final rawTs = json['timestamp'];
    if (rawTs != null) {
      if (rawTs is int) {
        ts = DateTime.fromMillisecondsSinceEpoch(rawTs);
      } else {
        ts = (rawTs as dynamic).toDate();
      }
    }
    return RecentFlowEntry(
      userId: json['userId']?.toString() ?? '',
      durationMs: (json['durationMs'] as int?) ?? 0,
      success: (json['success'] as bool?) ?? true,
      timestamp: ts,
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
    final rawScreens = json['screens'] as Map<String, dynamic>? ?? {};
    final screens = rawScreens.map((k, v) => MapEntry(k, (v as int?) ?? 0));

    return ScreenLogEntry(
      date: json['date']?.toString() ?? '',
      screens: screens,
      totalVisits: (json['totalVisits'] as int?) ?? 0,
      uniqueUsers: (json['uniqueUsers'] as int?) ?? 0,
    );
  }

  List<MapEntry<String, int>> get sortedScreens {
    final entries = screens.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }
}
