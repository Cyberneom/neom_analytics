import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:neom_core/utils/neom_error_logger.dart';

import '../../domain/models/error_log_entry.dart';

/// Reads aggregated error logs from Firestore for the error monitor dashboard.
class ErrorLogFirestore {
  final FirebaseFirestore? _firestoreInstance;

  ErrorLogFirestore({FirebaseFirestore? firestore})
      : _firestoreInstance = firestore;

  static const String _collection = 'errorLogs';
  static const int maxModulesLimit = 200;

  static final RegExp _unsafeModuleIdChars = RegExp(
    r'[\x00-\x1F\x7F-\x9F\u0085\u061C\u200B-\u200F\u2028\u2029\u202A-\u202E\u2060-\u2069\uFEFF/\\:]',
  );
  static final RegExp _encodedTraversalPattern = RegExp(
    r'%(?:2e|2f|5c|00|25|e2%80%(?:8[b-f]|a[8-e])|e2%81%a[0-9]|d8%9c|ef%bb%bf)',
    caseSensitive: false,
  );
  static final RegExp _windowsReservedStem = RegExp(
    r'^(?:con|prn|aux|nul|conin\$|conout\$|clock\$|com[1-9]|lpt[1-9])(?:\..*)?$',
    caseSensitive: false,
  );

  @visibleForTesting
  static bool isSafeModuleId(String raw) {
    if (raw.isEmpty ||
        _unsafeModuleIdChars.hasMatch(raw) ||
        _encodedTraversalPattern.hasMatch(raw)) {
      return false;
    }
    final trimmed = raw.trim();
    if (trimmed != raw || trimmed.isEmpty || trimmed.length > 128) return false;
    if (trimmed == '.' ||
        trimmed == '..' ||
        trimmed.contains('..') ||
        _windowsReservedStem.hasMatch(trimmed)) {
      return false;
    }
    final lower = trimmed.toLowerCase();
    if (lower == '__proto__' ||
        lower == 'constructor' ||
        lower == 'prototype' ||
        (trimmed.startsWith('__') && trimmed.endsWith('__'))) {
      return false;
    }
    return !_unsafeModuleIdChars.hasMatch(trimmed);
  }

  CollectionReference<Map<String, dynamic>> get _ref =>
      (_firestoreInstance ?? FirebaseFirestore.instance).collection(_collection);

  /// Retrieves all module error logs, sorted by totalErrors descending.
  Future<List<ErrorLogEntry>> getAll() async {
    try {
      final snapshot = await _ref
          .orderBy('totalErrors', descending: true)
          .limit(maxModulesLimit)
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
    if (!isSafeModuleId(module)) return null;
    final cleanModule = module.trim();
    try {
      final doc = await _ref.doc(cleanModule).get();
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return ErrorLogEntry.fromJSON(data);
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_analytics', operation: 'getByModule');
      return null;
    }
  }

  /// Resets error counts for a specific module.
  Future<void> resetModule(String module) async {
    if (!isSafeModuleId(module)) return;
    final cleanModule = module.trim();
    try {
      await _ref.doc(cleanModule).delete();
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_analytics', operation: 'resetModule');
    }
  }

  /// Resets all error counts in Firestore-safe chunks (`<= 450` per `WriteBatch`).
  Future<void> resetAll() async {
    try {
      final snapshot = await _ref.get();
      if (snapshot.docs.isEmpty) return;
      const chunkSize = 450;
      for (var i = 0; i < snapshot.docs.length; i += chunkSize) {
        final end = (i + chunkSize) < snapshot.docs.length
            ? (i + chunkSize)
            : snapshot.docs.length;
        final batch =
            (_firestoreInstance ?? FirebaseFirestore.instance).batch();
        for (final doc in snapshot.docs.sublist(i, end)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_analytics', operation: 'resetAll');
    }
  }
}
