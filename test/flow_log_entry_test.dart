import 'package:flutter_test/flutter_test.dart';
import 'package:neom_analytics/domain/models/flow_log_entry.dart';

void main() {
  group('FlowLogEntry.fromJSON', () {
    test('parses minimal JSON with all fields missing', () {
      final e = FlowLogEntry.fromJSON({});
      expect(e.flowName, '');
      expect(e.totalCompletions, 0);
      expect(e.totalFailures, 0);
      expect(e.avgDurationMs, 0);
      expect(e.steps, isEmpty);
      expect(e.recentFlows, isEmpty);
    });

    test('coerces numeric avgDurationMs from double to int', () {
      final e = FlowLogEntry.fromJSON({'avgDurationMs': 1234.7});
      expect(e.avgDurationMs, 1234);
    });

    test('parses steps map', () {
      final e = FlowLogEntry.fromJSON({
        'steps': {
          'login': {'count': 10, 'avgDurationMs': 500},
        },
      });
      expect(e.steps.length, 1);
      expect(e.steps['login']!.count, 10);
    });
  });

  group('totalAttempts and successRate', () {
    test('successRate is 0 when no attempts (no division by zero)', () {
      final e = FlowLogEntry(
        flowName: 'f', totalCompletions: 0, totalFailures: 0,
        avgDurationMs: 0, steps: const {}, recentFlows: const [],
      );
      expect(e.totalAttempts, 0);
      expect(e.successRate, 0);
    });

    test('successRate computes correctly with mixed', () {
      final e = FlowLogEntry(
        flowName: 'f', totalCompletions: 7, totalFailures: 3,
        avgDurationMs: 0, steps: const {}, recentFlows: const [],
      );
      expect(e.totalAttempts, 10);
      expect(e.successRate, 0.7);
    });

    test('successRate is 1.0 when all completions and no failures', () {
      final e = FlowLogEntry(
        flowName: 'f', totalCompletions: 5, totalFailures: 0,
        avgDurationMs: 0, steps: const {}, recentFlows: const [],
      );
      expect(e.successRate, 1.0);
    });
  });

  group('avgDurationFormatted', () {
    FlowLogEntry mk(int ms) => FlowLogEntry(
          flowName: 'f', totalCompletions: 0, totalFailures: 0,
          avgDurationMs: ms, steps: const {}, recentFlows: const [],
        );

    test('< 1000 returns ms', () {
      expect(mk(0).avgDurationFormatted, '0ms');
      expect(mk(999).avgDurationFormatted, '999ms');
    });

    test('exact 1000 boundary returns 1.0s (off-by-one check)', () {
      expect(mk(1000).avgDurationFormatted, '1.0s');
    });

    test('59999 returns seconds', () {
      expect(mk(59999).avgDurationFormatted, '60.0s');
    });

    test('60000 returns minutes', () {
      expect(mk(60000).avgDurationFormatted, '1.0min');
    });

    test('large value returns minutes', () {
      expect(mk(3600000).avgDurationFormatted, '60.0min');
    });
  });

  group('displayName', () {
    FlowLogEntry mk(String name) => FlowLogEntry(
          flowName: name, totalCompletions: 0, totalFailures: 0,
          avgDurationMs: 0, steps: const {}, recentFlows: const [],
        );

    test('replaces underscores and capitalizes words', () {
      expect(mk('user_login_flow').displayName, 'User Login Flow');
    });

    test('empty string yields empty', () {
      expect(mk('').displayName, '');
    });

    test('handles consecutive underscores without crash', () {
      expect(mk('a__b').displayName, isNotNull);
    });

    test('single word', () {
      expect(mk('login').displayName, 'Login');
    });

    test('handles trailing underscore', () {
      // Should not throw on the empty trailing token.
      expect(() => mk('foo_').displayName, returnsNormally);
    });
  });

  group('sortedSteps', () {
    test('sorts ascending by avgDurationMs', () {
      final e = FlowLogEntry(
        flowName: 'f', totalCompletions: 0, totalFailures: 0, avgDurationMs: 0,
        recentFlows: const [],
        steps: {
          'a': FlowStepEntry(count: 1, avgDurationMs: 500),
          'b': FlowStepEntry(count: 1, avgDurationMs: 100),
          'c': FlowStepEntry(count: 1, avgDurationMs: 300),
        },
      );
      expect(e.sortedSteps.map((m) => m.key).toList(), ['b', 'c', 'a']);
    });

    test('handles empty steps', () {
      final e = FlowLogEntry(
        flowName: 'f', totalCompletions: 0, totalFailures: 0, avgDurationMs: 0,
        steps: const {}, recentFlows: const [],
      );
      expect(e.sortedSteps, isEmpty);
    });
  });

  group('FlowStepEntry', () {
    test('formatted ms boundary', () {
      expect(FlowStepEntry(count: 1, avgDurationMs: 999).avgDurationFormatted, '999ms');
      expect(FlowStepEntry(count: 1, avgDurationMs: 1000).avgDurationFormatted, '1.0s');
      expect(FlowStepEntry(count: 1, avgDurationMs: 60000).avgDurationFormatted, '1.0min');
    });

    test('fromJSON tolerates missing fields', () {
      final e = FlowStepEntry.fromJSON({});
      expect(e.count, 0);
      expect(e.avgDurationMs, 0);
    });
  });

  group('RecentFlowEntry.fromJSON', () {
    test('parses int millisecond timestamp', () {
      final e = RecentFlowEntry.fromJSON({
        'userId': 'u1', 'durationMs': 100, 'success': false,
        'timestamp': 1700000000000,
      });
      expect(e.timestamp, isNotNull);
      expect(e.timestamp!.millisecondsSinceEpoch, 1700000000000);
      expect(e.success, isFalse);
    });

    test('null timestamp leaves it null', () {
      final e = RecentFlowEntry.fromJSON({'userId': 'u', 'durationMs': 1});
      expect(e.timestamp, isNull);
      // success defaults to true.
      expect(e.success, isTrue);
    });

    test('formatted duration boundaries', () {
      expect(RecentFlowEntry(userId: 'u', durationMs: 999, success: true).durationFormatted, '999ms');
      expect(RecentFlowEntry(userId: 'u', durationMs: 1000, success: true).durationFormatted, '1.0s');
      expect(RecentFlowEntry(userId: 'u', durationMs: 60000, success: true).durationFormatted, '1.0min');
    });
  });

  group('ScreenLogEntry', () {
    test('sortedScreens descending by visit count', () {
      final s = ScreenLogEntry(
        date: '2024-01-01',
        screens: {'home': 50, 'profile': 200, 'settings': 10},
        totalVisits: 260, uniqueUsers: 10,
      );
      expect(s.sortedScreens.map((e) => e.key).toList(),
          ['profile', 'home', 'settings']);
    });

    test('fromJSON parses screen counts', () {
      final s = ScreenLogEntry.fromJSON({
        'date': '2024-01-01',
        'screens': {'home': 50},
        'totalVisits': 50, 'uniqueUsers': 5,
      });
      expect(s.screens['home'], 50);
      expect(s.uniqueUsers, 5);
    });

    test('fromJSON tolerates missing fields', () {
      final s = ScreenLogEntry.fromJSON({});
      expect(s.date, '');
      expect(s.screens, isEmpty);
      expect(s.totalVisits, 0);
      expect(s.uniqueUsers, 0);
    });
  });
}
