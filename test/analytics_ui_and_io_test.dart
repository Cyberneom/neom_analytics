import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neom_analytics/data/firestore/analytics_firestore.dart';
import 'package:neom_analytics/data/firestore/flow_log_firestore.dart';
import 'package:neom_analytics/domain/models/flow_log_entry.dart';
import 'package:neom_analytics/ui/analytics_page.dart';
import 'package:neom_analytics/ui/flow_monitor_page.dart';
import 'package:neom_core/domain/model/user_locations.dart';
import 'package:neom_core/domain/repository/analytics_repository.dart';
import 'package:sint/sint.dart';

class _CountingAnalyticsRepo implements AnalyticsRepository {
  int queryCount = 0;
  final List<UserLocations> response;

  _CountingAnalyticsRepo(this.response);

  @override
  Future<List<UserLocations>> getUserLocations() async {
    queryCount++;
    return response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ZeroDurationFlowFirestore implements FlowLogFirestore {
  @override
  Future<List<FlowLogEntry>> getAllFlows() async {
    return [
      FlowLogEntry(
        flowName: 'instant_flow',
        totalCompletions: 3,
        totalFailures: 0,
        avgDurationMs: 0,
        steps: const {},
        recentFlows: const [],
      ),
    ];
  }

  @override
  Future<List<ScreenLogEntry>> getScreenLogs({int days = 7}) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  tearDown(() {
    Sint.reset();
  });

  testWidgets('AnalyticsPage caches getUserLocations in initState and handles empty list safely',
      (tester) async {
    final repo = _CountingAnalyticsRepo(const []);

    await tester.pumpWidget(
      SintMaterialApp(
        home: AnalyticsPage(analyticsRepository: repo),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.queryCount, equals(1));
    expect(tester.takeException(), isNull);

    // Trigger a parent rebuild and verify getUserLocations is NOT re-run inside build().
    await tester.pumpWidget(
      SintMaterialApp(
        theme: ThemeData.dark(),
        home: AnalyticsPage(analyticsRepository: repo),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.queryCount, equals(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('FlowMonitorPage guards avgDurationMs == 0 interval without fl_chart assertion',
      (tester) async {
    await tester.pumpWidget(
      SintMaterialApp(
        home: FlowMonitorPage(flowLogFirestore: _ZeroDurationFlowFirestore()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Instant Flow'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('AnalyticsFirestore.writeOwnerOnlyFile writes safely and rejects unsafe paths', () async {
    expect(
      () => AnalyticsFirestore.writeOwnerOnlyFile('../escape.txt', 'data'),
      throwsArgumentError,
    );

    final dir = await Directory.systemTemp.createTemp('neom_analytics_test_');
    addTearDown(() => dir.delete(recursive: true));
    final outPath = '${dir.path}/safe_export.txt';
    await AnalyticsFirestore.writeOwnerOnlyFile(outPath, 'user@example.com');
    expect(File(outPath).readAsStringSync(), equals('user@example.com'));
  });
}
