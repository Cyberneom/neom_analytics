import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/utils/neom_error_logger.dart';

import '../../domain/models/flow_log_entry.dart';

/// Reads flow tracking data from Firestore for the flow monitor dashboard.
class FlowLogFirestore {

  static const String _flowCollection = 'flowLogs';
  static const String _screenCollection = 'screenLogs';

  final _flowRef = FirebaseFirestore.instance.collection(_flowCollection);
  final _screenRef = FirebaseFirestore.instance.collection(_screenCollection);

  /// Retrieves all flow logs sorted by totalCompletions descending.
  Future<List<FlowLogEntry>> getAllFlows() async {
    try {
      final snapshot = await _flowRef
          .orderBy('totalCompletions', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => FlowLogEntry.fromJSON(doc.data()))
          .toList();
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_analytics', operation: 'getAllFlows');
      return [];
    }
  }

  /// Retrieves screen logs for the last N days.
  Future<List<ScreenLogEntry>> getScreenLogs({int days = 7}) async {
    try {
      final snapshot = await _screenRef
          .orderBy('date', descending: true)
          .limit(days)
          .get();

      return snapshot.docs
          .map((doc) => ScreenLogEntry.fromJSON(doc.data()))
          .toList();
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_analytics', operation: 'getScreenLogs');
      return [];
    }
  }
}
