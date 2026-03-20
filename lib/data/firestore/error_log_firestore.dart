import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/utils/neom_error_logger.dart';

import '../../domain/models/error_log_entry.dart';

/// Reads aggregated error logs from Firestore for the error monitor dashboard.
class ErrorLogFirestore {

  static const String _collection = 'errorLogs';

  final _ref = FirebaseFirestore.instance.collection(_collection);

  /// Retrieves all module error logs, sorted by totalErrors descending.
  Future<List<ErrorLogEntry>> getAll() async {
    try {
      final snapshot = await _ref
          .orderBy('totalErrors', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ErrorLogEntry.fromJSON(doc.data()))
          .toList();
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_analytics', operation: 'getAll');
      return [];
    }
  }

  /// Retrieves error log for a specific module.
  Future<ErrorLogEntry?> getByModule(String module) async {
    try {
      final doc = await _ref.doc(module).get();
      if (!doc.exists) return null;
      return ErrorLogEntry.fromJSON(doc.data()!);
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_analytics', operation: 'getByModule');
      return null;
    }
  }

  /// Resets error counts for a specific module.
  Future<void> resetModule(String module) async {
    try {
      await _ref.doc(module).delete();
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_analytics', operation: 'resetModule');
    }
  }

  /// Resets all error counts.
  Future<void> resetAll() async {
    try {
      final snapshot = await _ref.get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_analytics', operation: 'resetAll');
    }
  }
}
