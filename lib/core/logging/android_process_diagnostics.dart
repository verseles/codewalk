import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// Persists a small, local-only ring buffer for Android process diagnostics.
///
/// Records contain system metadata only. They intentionally exclude messages,
/// prompts, credentials, URLs, clipboard contents, and full stack traces.
class AndroidProcessDiagnostics {
  AndroidProcessDiagnostics._();

  static const MethodChannel _channel = MethodChannel('codewalk/system');
  static const int _maxRecords = 12;
  static Future<void> _writeQueue = Future<void>.value();

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> recordStartup() {
    if (!isSupported) {
      return Future<void>.value();
    }
    return _enqueue(() async {
      Map<String, dynamic>? native;
      try {
        native = await _channel.invokeMapMethod<String, dynamic>(
          'getAndroidProcessDiagnostics',
        );
      } catch (_) {
        // Diagnostics must never block application startup.
      }

      final record = <String, Object?>{
        'kind': 'startup',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'nativeAvailable': native != null,
        if (native != null) ...normalizeNativeDiagnostics(native),
      };
      await _append(record);
    });
  }

  static Future<void> recordDartError({
    required String source,
    required String errorType,
    required String stackHash,
  }) {
    if (!isSupported) {
      return Future<void>.value();
    }
    return _enqueue(
      () => _append(<String, Object?>{
        'kind': 'dart_error',
        'source': source,
        'errorType': errorType.trim().isEmpty ? 'unknown' : errorType.trim(),
        'stackHash': stackHash.trim().isEmpty ? '<empty>' : stackHash.trim(),
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  static Future<List<Map<String, Object?>>> readRecords() async {
    if (!isSupported) {
      return const <Map<String, Object?>>[];
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(
        AppConstants.androidProcessDiagnosticsKey,
      );
      if (raw == null || raw.trim().isEmpty) {
        return const <Map<String, Object?>>[];
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <Map<String, Object?>>[];
      }
      return decoded
          .whereType<Map>()
          .map(
            (record) => <String, Object?>{
              for (final entry in record.entries)
                entry.key.toString(): entry.value,
            },
          )
          .toList(growable: false);
    } catch (_) {
      return const <Map<String, Object?>>[];
    }
  }

  @visibleForTesting
  static Map<String, Object?> normalizeNativeDiagnostics(
    Map<Object?, Object?> raw,
  ) {
    const integerKeys = <String>{
      'pid',
      'activityId',
      'engineId',
      'lastTrimMemoryLevel',
      'lastExitReason',
      'lastExitStatus',
      'lastExitImportance',
      'lastExitPssKb',
      'lastExitRssKb',
      'lastExitTimestampEpochMs',
    };
    final normalized = <String, Object?>{};
    for (final entry in raw.entries) {
      final key = entry.key?.toString();
      if (key == null) {
        continue;
      }
      final value = entry.value;
      if (key == 'activityRecreated' && value is bool) {
        normalized[key] = value;
      } else if (integerKeys.contains(key) && value is num) {
        normalized[key] = value.toInt();
      }
    }
    return normalized;
  }

  static Future<void> _append(Map<String, Object?> record) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final records = <Map<String, Object?>>[];
      final existing = preferences.getString(
        AppConstants.androidProcessDiagnosticsKey,
      );
      if (existing != null && existing.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(existing);
          if (decoded is List) {
            records.addAll(
              decoded.whereType<Map>().map(
                (item) => <String, Object?>{
                  for (final entry in item.entries)
                    entry.key.toString(): entry.value,
                },
              ),
            );
          }
        } catch (_) {
          // Replace malformed diagnostics with a fresh ring buffer.
        }
      }
      records.add(record);
      if (records.length > _maxRecords) {
        records.removeRange(0, records.length - _maxRecords);
      }
      await preferences.setString(
        AppConstants.androidProcessDiagnosticsKey,
        jsonEncode(records),
      );
    } catch (_) {
      // Diagnostics are best effort and must never affect the app lifecycle.
    }
  }

  static Future<void> _enqueue(Future<void> Function() action) {
    final task = _writeQueue.then((_) => action());
    _writeQueue = task.catchError((_) {});
    return task;
  }
}
