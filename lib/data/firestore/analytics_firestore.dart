import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:geolocator/geolocator.dart';
import 'package:neom_commons/utils/app_utilities.dart';
import 'package:neom_commons/utils/device_utilities.dart';
import 'package:neom_commons/utils/file_system_utilities.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/app_properties.dart';
import 'package:neom_core/data/firestore/constants/app_firestore_collection_constants.dart';
import 'package:neom_core/data/firestore/constants/app_firestore_constants.dart';
import 'package:neom_core/data/firestore/profile_firestore.dart';
import 'package:neom_core/data/firestore/user_firestore.dart';
import 'package:neom_core/domain/model/app_coupon.dart';
import 'package:neom_core/domain/model/app_profile.dart';
import 'package:neom_core/domain/model/app_user.dart';
import 'package:neom_core/domain/model/user_locations.dart';
import 'package:neom_core/domain/repository/analytics_repository.dart';
import 'package:neom_core/utils/neom_error_logger.dart';
import 'package:neom_core/utils/position_utilities.dart';

import '../../utils/constants/analytic_translation_constants.dart';
import 'owner_only_file.dart';

class AnalyticsFirestore implements AnalyticsRepository {
  static const int maxBatchChunkSize = 450;
  static const int maxClipboardExportChars = 256 * 1024;

  static final RegExp _unsafeControlOrBidi = RegExp(
    r'[\x00-\x1F\x7F-\x9F\u0085\u061C\u200B-\u200F\u2028\u2029\u202A-\u202E\u2060\u2066-\u2069\uFEFF]',
  );

  static final RegExp _gemma4ThoughtPattern = RegExp(
    r'<\|(?:channel|turn)\s*>?\s*thought\b[\s\S]*?(?:<(?:channel|turn)\|>|$)',
    caseSensitive: false,
  );

  static final RegExp _internalBlockPattern = RegExp(
    r'<\s*(think|thought|memory_recall|auto_memory|system_context)\b[^>]*>[\s\S]*?(?:<\s*/\s*\1\s*>|$)'
    r'|\[\s*(BIOCHIP|MEMORY_RECALL)\b[^\]]*\][\s\S]*?(?:\[\s*/\s*\2\s*\]|$)',
    caseSensitive: false,
  );

  static final RegExp _danglingInternalTagPattern = RegExp(
    r'<\s*/?\s*(think|thought|memory_recall|auto_memory|system_context)\b[^>]*>'
    r'|\[\s*/?\s*(BIOCHIP|MEMORY_RECALL)\b[^\]]*\]'
    r'|<\|(?:turn|channel|eot|im_start|im_end)[^>]*\|?>'
    r'|<(?:turn|channel)\|>',
    caseSensitive: false,
  );

  static final RegExp _closingContentBoundary = RegExp(
    r'<\s*/\s*content\s*>',
    caseSensitive: false,
  );

  static final RegExp _encodedTraversalPattern = RegExp(
    r'(?:%2e|%2f|%5c|%00)',
    caseSensitive: false,
  );

  static final RegExp _csvRawDangerousPrefix = RegExp(
    r'^(?:[\t\r\n]+|[ \t\r\n]*[=+\-@;|])',
  );
  static final RegExp _csvFormulaPrefix = RegExp(r'^[=+\-@;|\t\r]');
  static final RegExp _windowsReservedDeviceStem = RegExp(
    r'^(?:con|prn|aux|nul|com[1-9]|lpt[1-9])$',
    caseSensitive: false,
  );
  static final RegExp _windowsDrivePrefix = RegExp(r'^[A-Za-z]:/');

  static bool _isReservedKey(String key) {
    final lower = key.toLowerCase();
    return lower == '__proto__' ||
        lower == 'constructor' ||
        lower == 'prototype' ||
        (key.startsWith('__') && key.endsWith('__'));
  }

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

  @visibleForTesting
  static String sanitizeCsvCell(String raw) {
    final hadRawDangerousPrefix = _csvRawDangerousPrefix.hasMatch(raw);
    final cleaned = raw
        .replaceAll(_gemma4ThoughtPattern, ' ')
        .replaceAll(_internalBlockPattern, ' ')
        .replaceAll(_danglingInternalTagPattern, ' ')
        .replaceAll(_closingContentBoundary, '[content_end]')
        .replaceAll(_unsafeControlOrBidi, '')
        .trim();
    if (cleaned.isEmpty) return '';
    if (hadRawDangerousPrefix || _csvFormulaPrefix.hasMatch(cleaned)) {
      return "'$cleaned";
    }
    return cleaned;
  }

  @visibleForTesting
  static String sanitizeAppFilenamePrefix(String raw) {
    var cleaned = raw
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (cleaned.isEmpty) return 'neom_app';
    if (_windowsReservedDeviceStem.hasMatch(cleaned) ||
        _isReservedKey(cleaned)) {
      cleaned = '_$cleaned';
    }
    return cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
  }

  @visibleForTesting
  static String sanitizeLocationFieldName(String raw) {
    var cleaned = raw
        .replaceAll(_gemma4ThoughtPattern, ' ')
        .replaceAll(_internalBlockPattern, ' ')
        .replaceAll(_danglingInternalTagPattern, ' ')
        .replaceAll(_closingContentBoundary, '[content_end]')
        .replaceAll(_unsafeControlOrBidi, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.length > 120) {
      cleaned = _truncateUtf16Safe(cleaned, 120).trimRight();
    }
    if (cleaned.isEmpty || _isReservedKey(cleaned)) {
      return '';
    }
    return cleaned;
  }

  CollectionReference<Map<String, dynamic>> get analyticsReference =>
      FirebaseFirestore.instance
          .collection(AppFirestoreCollectionConstants.analytics);

  @override
  Future<List<UserLocations>> getUserLocations() async {
    AppConfig.logger.d("Get all Users");

    List<UserLocations> userLocationsList = [];
    try {
      final userAnalyticsReference = analyticsReference.doc(AppFirestoreCollectionConstants.usersAnalytics);
      final userLocationsReferences = userAnalyticsReference.collection(AppFirestoreCollectionConstants.userLocations);
      QuerySnapshot querySnapshot = await userLocationsReferences.get();
      for (var queryDocumentSnapshot in querySnapshot.docs) {
        UserLocations userLocations = UserLocations.fromJSON(queryDocumentSnapshot.data());
        userLocations.dateId = queryDocumentSnapshot.id;
        userLocationsList.add(userLocations);
      }

    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_analytics', operation: 'getUserLocations');
    }

    return userLocationsList;

  }
  
  @override
  Future<Map<String, AppCoupon>> getUserAnalytics() async {
    AppConfig.logger.d("");
    Map<String, AppCoupon> coupons = {};
    return coupons;
  }


  @override
  Future<AppCoupon> getAnalyticsByType(String couponCode) async {
    return AppCoupon();

  }

  @override
  Future<void> setUserLocations({bool getEmailsAsText = false}) async {
      AppConfig.logger.d("Setting App Analytics for fast access.");


      try {

        final userAnalyticsReference = analyticsReference.doc(AppFirestoreCollectionConstants.usersAnalytics);
        final userLocationsReferences = userAnalyticsReference.collection(AppFirestoreCollectionConstants.userLocations);
        /// List<AppUser> users = await UserFirestore().getAll();
        /// Map<String, AppProfile> profiles = await ProfileFirestore().retrieveAllProfiles();
        final now = DateTime.now();
        final dateId = "${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.year}";
        final userAnalyticsDocRef = userLocationsReferences.doc(dateId);

        // Ejecutar la obtención de usuarios y perfiles en paralelo.
        final results = await Future.wait([
          UserFirestore().getAll(),
          ProfileFirestore().retrieveAllProfiles(),
        ]);
        List<AppUser> users = results[0] as List<AppUser>;
        Map<String, AppProfile> profiles = results[1] as Map<String, AppProfile>;

        List<String> totalLocations = [];


        /// List<Position> positions = [];
        // for (var profile in profiles.values) {
        //   if(profile.position!.latitude > 0.000000) {
        //     positions.add(profile.position!);
        //   }
        // }

        // Filtrar perfiles que tengan una posición válida.
        List<Position> positions = profiles.values
            .where((profile) =>
                profile.position != null &&
                profile.position!.latitude.isFinite &&
                profile.position!.longitude.isFinite &&
                profile.position!.latitude > 0)
            .map((profile) => profile.position!)
            .toList();

        totalLocations = await PositionUtilities.getAddressesFromPositions(positions);

        await userLocationsReferences.doc(dateId)
            .set({
              AppFirestoreConstants.totalUsers: "${users.length}",
              AppFirestoreConstants.totalLocations: "${totalLocations.length}"
            });


        final Map<String, int> locationTimes = <String, int>{};
        for (final location in totalLocations) {
          final safeLoc = sanitizeLocationFieldName(location);
          if (safeLoc.isEmpty) continue;
          locationTimes[safeLoc] = (locationTimes[safeLoc] ?? 0) + 1;
        }
        AppConfig.logger.d("${locationTimes.length} different locations were found.");

        final entries = locationTimes.entries.toList(growable: false);
        for (var i = 0; i < entries.length; i += maxBatchChunkSize) {
          final end = (i + maxBatchChunkSize) < entries.length
              ? (i + maxBatchChunkSize)
              : entries.length;
          final batch = FirebaseFirestore.instance.batch();
          final updateData = <Object, Object?>{};
          for (final entry in entries.sublist(i, end)) {
            updateData[FieldPath(<String>[entry.key])] = '${entry.value}';
          }
          batch.update(userAnalyticsDocRef, updateData);
          await batch.commit();
        }

        await getUserEmailsAsText(getEmailsAsText, users);

      } catch (e, st) {
        NeomErrorLogger.recordError(e, st, module: 'neom_analytics', operation: 'setUserLocations');
        AppUtilities.showSnackBar(title: AnalyticTranslationConstants.analytics,
            message: "Hubo un error al actualizar las analíticas");
        return;
      }
      
      AppUtilities.showSnackBar(title: AnalyticTranslationConstants.analytics,
          message: "Las analíticas han sido actualizadas");

  }

  @visibleForTesting
  static bool isSafeExportPath(String rawPath) {
    if (rawPath.isEmpty ||
        rawPath.length > 4096 ||
        _unsafeControlOrBidi.hasMatch(rawPath) ||
        _encodedTraversalPattern.hasMatch(rawPath)) {
      return false;
    }
    final trimmed = rawPath.trim();
    if (trimmed != rawPath ||
        trimmed.isEmpty ||
        trimmed.startsWith('-') ||
        trimmed.startsWith('//') ||
        trimmed.startsWith(r'\\') ||
        trimmed.startsWith(r'\??\') ||
        _unsafeControlOrBidi.hasMatch(trimmed)) {
      return false;
    }
    final norm = trimmed.replaceAll('\\', '/');
    final withoutDrive = _windowsDrivePrefix.hasMatch(norm)
        ? norm.substring(2)
        : norm;
    if (withoutDrive.contains(':')) return false;
    final segments = norm.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.any((s) => s == '.' || s == '..')) return false;
    final lower = norm.toLowerCase();
    if (lower.startsWith('/etc/') ||
        lower == '/etc' ||
        lower.startsWith('/private/etc/') ||
        lower.startsWith('/proc/') ||
        lower.startsWith('/sys/') ||
        lower.startsWith('/dev/')) {
      return false;
    }
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i].toLowerCase();
      final stem = s.split('.').first;
      if (_windowsReservedDeviceStem.hasMatch(stem)) return false;
      if (s == '.ssh' ||
          s == '.aws' ||
          s == '.gnupg' ||
          s == '.kube' ||
          s == '.docker' ||
          s == '.git' ||
          s == 'keychains' ||
          s == '.env' ||
          s.startsWith('.env.') ||
          s == '.secret.local' ||
          s.contains('firebase-adminsdk')) {
        return false;
      }
      if (s == '.config' &&
          i + 1 < segments.length &&
          segments[i + 1].toLowerCase() == 'gcloud') {
        return false;
      }
    }
    return true;
  }

  @visibleForTesting
  static Map<String, String> sanitizeSubprocessEnv([
    Map<String, String>? source,
  ]) {
    final env = source ?? (kIsWeb ? const <String, String>{} : readPlatformEnvironment());
    const allowed = <String>{
      'PATH',
      'HOME',
      'TMPDIR',
      'TEMP',
      'TMP',
      'LANG',
      'LC_ALL',
      'SYSTEMROOT',
      'WINDIR',
    };
    final clean = <String, String>{};
    for (final key in allowed) {
      final val = env[key];
      if (val != null && !_unsafeControlOrBidi.hasMatch(val)) {
        clean[key] = val;
      }
    }
    if ((clean['PATH'] ?? '').trim().isEmpty) {
      clean['PATH'] = '/usr/bin:/bin';
    }
    return clean;
  }

  @visibleForTesting
  static Future<void> writeOwnerOnlyFile(String path, String contents) =>
      _writeOwnerOnlyFile(path, contents);

  static Future<void> _writeOwnerOnlyFile(String path, String contents) async {
    if (!isSafeExportPath(path)) {
      throw ArgumentError.value(path, 'path', 'Unsafe PII export path');
    }
    if (kIsWeb) return;
    final trimmed = path.trim();
    final norm = trimmed.replaceAll('\\', '/');
    await writeOwnerOnlyFileNative(
      trimmed,
      norm,
      contents,
      sanitizeSubprocessEnv(),
    );
  }

  Future<void> getUserEmailsAsText(bool getEmailsAsText, List<AppUser> users) async {

    // PII guard: email export only runs when explicitly requested (getEmailsAsText == true).
    // Never force this on analytics updates — dumping all user emails to local
    // files and the clipboard is a data-leak vector (GDPR/privacy risk).
    if(getEmailsAsText) {
      StringBuffer emailList = StringBuffer();

      List<List<dynamic>> rows = [];
      rows.add(['Email']);


      for (var user in users) {
        final cleanEmail = user.email.replaceAll(_unsafeControlOrBidi, '').trim();
        if(cleanEmail.isNotEmpty &&
            cleanEmail.length <= 254 &&
            !cleanEmail.contains("@privaterelay.appleid.com")) {
          emailList.write("$cleanEmail, ");
          rows.add([sanitizeCsvCell(cleanEmail)]);
        }
      }

      if(emailList.isNotEmpty) {
        final exportedText = emailList.toString();
        if (exportedText.length <= maxClipboardExportChars) {
          DeviceUtilities.copyToClipboard(text: exportedText);
        }
        if (!kIsWeb) {
          String localPath = await FileSystemUtilities.getLocalPath();
          if (localPath.isNotEmpty &&
              !isLinkSyncSafe(localPath)) {
            final safePrefix = sanitizeAppFilenamePrefix(
              AppProperties.getAppName(),
            );
            String emailListPath = "$localPath/${safePrefix}_email_list.txt";
            await _writeOwnerOnlyFile(emailListPath, exportedText);
            AppConfig.logger.i("Email List created to path $emailListPath successfully.");

            String csv = const CsvEncoder().convert(rows);
            String emailCsvPath = '$localPath/${safePrefix}_emails_list.csv';
            await _writeOwnerOnlyFile(emailCsvPath, csv);
            AppConfig.logger.i("Email CSV created to path $emailCsvPath successfully.");
          }
        }
      }
    }
  }

}
