import 'package:flutter_test/flutter_test.dart';
import 'package:neom_analytics/domain/models/error_log_entry.dart';

void main() {
  group('ErrorLogEntry.fromJSON', () {
    test('parses minimal empty JSON', () {
      final e = ErrorLogEntry.fromJSON({});
      expect(e.module, '');
      expect(e.totalErrors, 0);
      expect(e.operations, isEmpty);
      expect(e.recentErrors, isEmpty);
      expect(e.lastErrorAt, isNull);
    });

    test('parses operations with int counts', () {
      final e = ErrorLogEntry.fromJSON({
        'module': 'neom_chat',
        'totalErrors': 5,
        'operations': {'send': 3, 'receive': 2},
      });
      expect(e.module, 'neom_chat');
      expect(e.totalErrors, 5);
      expect(e.operations['send'], 3);
      expect(e.operations['receive'], 2);
    });

    test('coerces double counts in operations to int', () {
      final e = ErrorLogEntry.fromJSON({
        'operations': {'op': 7.5},
      });
      expect(e.operations['op'], 7);
    });

    test('parses recentErrors list', () {
      final e = ErrorLogEntry.fromJSON({
        'recentErrors': [
          {'operation': 'load', 'message': 'oops'},
          {'operation': 'save'},
        ],
      });
      expect(e.recentErrors.length, 2);
      expect(e.recentErrors.first.operation, 'load');
      expect(e.recentErrors.first.message, 'oops');
      // Defaults respected.
      expect(e.recentErrors.last.message, '');
    });

    test('totalErrors as double is coerced to int', () {
      final e = ErrorLogEntry.fromJSON({'totalErrors': 12.9});
      expect(e.totalErrors, 12);
    });
  });

  group('sortedOperations', () {
    test('sorts descending by count', () {
      final e = ErrorLogEntry(
        operations: {'a': 5, 'b': 20, 'c': 1, 'd': 10},
      );
      expect(e.sortedOperations.map((m) => m.key).toList(),
          ['b', 'd', 'a', 'c']);
    });

    test('handles empty operations', () {
      final e = ErrorLogEntry();
      expect(e.sortedOperations, isEmpty);
    });
  });

  group('displayName', () {
    test('strips neom_ prefix', () {
      expect(ErrorLogEntry(module: 'neom_chat').displayName, 'chat');
    });

    test('keeps name without neom_ prefix', () {
      expect(ErrorLogEntry(module: 'core').displayName, 'core');
    });

    test('empty module returns empty', () {
      expect(ErrorLogEntry(module: '').displayName, '');
    });

    test('only the prefix returns empty', () {
      expect(ErrorLogEntry(module: 'neom_').displayName, '');
    });

    test('does not strip mid-string occurrence', () {
      expect(ErrorLogEntry(module: 'foo_neom_bar').displayName, 'foo_neom_bar');
    });
  });

  group('RecentError.fromJSON', () {
    test('parses minimal entry with defaults', () {
      final e = RecentError.fromJSON({});
      expect(e.operation, '');
      expect(e.message, '');
      expect(e.timestamp, isNull);
    });

    test('coerces non-string operation to string', () {
      final e = RecentError.fromJSON({'operation': 42});
      expect(e.operation, '42');
    });
  });
}
