import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:neom_core/utils/neom_error_logger.dart';

import '../../domain/models/flow_log_entry.dart';

/// Reads flow tracking data from Firestore for the flow monitor dashboard.
class FlowLogFirestore {
  final FirebaseFirestore? _firestoreInstance;

  FlowLogFirestore({FirebaseFirestore? firestore})
      : _firestoreInstance = firestore;

  static const String _flowCollection = 'flowLogs';
  static const String _screenCollection = 'screenLogs';
  static const int maxFlowsLimit = 200;

  FirebaseFirestore get _db => _firestoreInstance ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _flowRef =>
      _db.collection(_flowCollection);
  CollectionReference<Map<String, dynamic>> get _screenRef =>
      _db.collection(_screenCollection);

  /// Retrieves all flow logs sorted by totalCompletions descending.
  Future<List<FlowLogEntry>> getAllFlows() async {
    try {
      final snapshot = await _flowRef
          .orderBy('totalCompletions', descending: true)
          .limit(maxFlowsLimit)
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
    if (!days.isFinite || days <= 0) return [];
    final safeDays = days > 365 ? 365 : days;
    try {
      final snapshot = await _screenRef
          .orderBy('date', descending: true)
          .limit(safeDays)
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
