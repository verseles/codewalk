import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'android_process_diagnostics.dart';

/// Centralized logger with debug gating and lightweight redaction.
class AppLogger {
  AppLogger._();

  static const String _name = 'CodeWalk';
  static const int _maxEntries = 1000;
  static const String performanceTag = 'performance';
  static const String phaseStartTag = 'phase:start';
  static const String phaseEndTag = 'phase:end';
  static final ValueNotifier<UnmodifiableListView<LogEntry>> _entries =
      ValueNotifier<UnmodifiableListView<LogEntry>>(
        UnmodifiableListView<LogEntry>(const <LogEntry>[]),
      );
  static final List<LogEntry> _buffer = <LogEntry>[];
  static final Object _taskZoneKey = Object();
  static DateTime _sessionStartedAt = DateTime.now();
  static bool _globalHandlersInstalled = false;
  static bool _loggingEnabled = false;
  static bool _performanceLoggingEnabled = false;
  static int _taskSequence = 0;

  static DateTime get sessionStartedAt => _sessionStartedAt;
  static bool get loggingEnabled => _loggingEnabled;
  static bool get performanceLoggingEnabled =>
      _loggingEnabled && _performanceLoggingEnabled;
  static bool get _canRecordLogs => _loggingEnabled;

  static void setLoggingEnabled(bool enabled) {
    if (_loggingEnabled == enabled) {
      return;
    }
    _loggingEnabled = enabled;
    if (!enabled) {
      clearEntries();
    }
  }

  static void setPerformanceLoggingEnabled(bool enabled) {
    _performanceLoggingEnabled = enabled;
  }

  static String safeContextId(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return '<empty>';
    }
    return _shortHash(_sanitize(raw));
  }

  static String safePathShape(Uri uri) {
    if (uri.pathSegments.isEmpty) {
      return '/';
    }
    return '/${uri.pathSegments.map(_safePathSegment).join('/')}';
  }

  static void installGlobalHandlers() {
    if (_globalHandlersInstalled) {
      return;
    }

    _globalHandlersInstalled = true;
    _sessionStartedAt = DateTime.now();

    final previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      previousFlutterHandler?.call(details);
      error(
        'Unhandled Flutter framework exception',
        error: details.exception,
        stackTrace: details.stack,
      );
      _recordUnhandledDiagnostic(
        source: 'flutter',
        errorType: details.exception.runtimeType.toString(),
        stackTrace: details.stack,
      );
    };

    final dispatcher = ui.PlatformDispatcher.instance;
    final previousDispatcherHandler = dispatcher.onError;
    dispatcher.onError = (errorObject, stackTrace) {
      error(
        'Unhandled platform exception',
        error: errorObject,
        stackTrace: stackTrace,
      );
      _recordUnhandledDiagnostic(
        source: 'platform',
        errorType: errorObject.runtimeType.toString(),
        stackTrace: stackTrace,
      );
      final handledByPrevious =
          previousDispatcherHandler?.call(errorObject, stackTrace) ?? false;
      return handledByPrevious;
    };
  }

  static void recordZoneError(Object errorObject, StackTrace stackTrace) {
    error(
      'Unhandled zone exception',
      error: errorObject,
      stackTrace: stackTrace,
    );
    _recordUnhandledDiagnostic(
      source: 'zone',
      errorType: errorObject.runtimeType.toString(),
      stackTrace: stackTrace,
    );
  }

  static void _recordUnhandledDiagnostic({
    required String source,
    required String errorType,
    required StackTrace? stackTrace,
  }) {
    unawaited(
      AndroidProcessDiagnostics.recordDartError(
        source: source,
        errorType: errorType,
        stackHash: safeContextId(stackTrace),
      ),
    );
  }

  static void debug(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Set<String>? tags,
    Map<String, Object?>? metrics,
  }) {
    if (kReleaseMode || !_canRecordLogs) {
      return;
    }
    _record(
      level: LogLevel.debug,
      message: message,
      error: error,
      stackTrace: stackTrace,
      tags: tags,
      metrics: metrics,
    );
    developer.log(
      _formatDeveloperMessage(_sanitize(message), tags),
      name: _name,
      level: 500,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void info(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Set<String>? tags,
    Map<String, Object?>? metrics,
  }) {
    if (!_canRecordLogs) {
      return;
    }
    _record(
      level: LogLevel.info,
      message: message,
      error: error,
      stackTrace: stackTrace,
      tags: tags,
      metrics: metrics,
    );
    developer.log(
      _formatDeveloperMessage(_sanitize(message), tags),
      name: _name,
      level: 800,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void warn(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Set<String>? tags,
    Map<String, Object?>? metrics,
  }) {
    if (!_canRecordLogs) {
      return;
    }
    _record(
      level: LogLevel.warn,
      message: message,
      error: error,
      stackTrace: stackTrace,
      tags: tags,
      metrics: metrics,
    );
    developer.log(
      _formatDeveloperMessage(_sanitize(message), tags),
      name: _name,
      level: 900,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Set<String>? tags,
    Map<String, Object?>? metrics,
  }) {
    if (!_canRecordLogs) {
      return;
    }
    _record(
      level: LogLevel.error,
      message: message,
      error: error,
      stackTrace: stackTrace,
      tags: tags,
      metrics: metrics,
    );
    developer.log(
      _formatDeveloperMessage(_sanitize(message), tags),
      name: _name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static TaskHandle beginTask(
    String name, {
    Set<String>? tags,
    Map<String, Object?>? context,
  }) {
    if (kReleaseMode || !_canRecordLogs) {
      return TaskHandle._disabled(name: name, tags: tags, context: context);
    }

    final zoneParent = Zone.current[_taskZoneKey];
    final parent = zoneParent is TaskHandle && !zoneParent.isClosed
        ? zoneParent
        : null;
    final taskId = _nextTaskId();
    final normalizedName = _normalizeTagValue(name);
    final handle = TaskHandle._(
      name: name,
      normalizedName: normalizedName,
      taskId: taskId,
      parentTaskId: parent?.taskId,
      tags: <String>{
        'task:$normalizedName',
        ...?tags,
        if (parent != null) 'parent:${parent.taskId}',
      },
      context: context,
    );
    _recordTaskPhase(
      handle: handle,
      phase: 'start',
      status: 'started',
      elapsed: Duration.zero,
    );
    return handle;
  }

  static T runTask<T>(
    String name,
    T Function(TaskHandle task) body, {
    Set<String>? tags,
    Map<String, Object?>? context,
  }) {
    final task = beginTask(name, tags: tags, context: context);
    try {
      final result = runZoned(
        () => body(task),
        zoneValues: <Object, Object>{_taskZoneKey: task},
      );
      if (result is Future) {
        return result.then(
              (value) {
                task.end();
                return value;
              },
              onError: (Object error, StackTrace stackTrace) {
                task.end(status: 'error', error: error, stackTrace: stackTrace);
                Error.throwWithStackTrace(error, stackTrace);
              },
            )
            as T;
      }
      task.end();
      return result;
    } catch (error, stackTrace) {
      task.end(status: 'error', error: error, stackTrace: stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  static Future<T> runPerformanceTask<T>(
    String operation,
    Future<T> Function() body, {
    Set<String>? tags,
    Map<String, Object?>? context,
    Map<String, Object?> Function()? contextBuilder,
  }) async {
    if (!performanceLoggingEnabled) {
      return body();
    }

    final stopwatch = Stopwatch()..start();
    try {
      final result = await body();
      stopwatch.stop();
      if (performanceLoggingEnabled) {
        recordPerformanceTask(
          operation: operation,
          elapsed: stopwatch.elapsed,
          status: 'ok',
          tags: tags,
          context: _buildPerformanceContext(context, contextBuilder),
        );
      }
      return result;
    } catch (error, stackTrace) {
      stopwatch.stop();
      if (performanceLoggingEnabled) {
        recordPerformanceTask(
          operation: operation,
          elapsed: stopwatch.elapsed,
          status: 'error',
          tags: tags,
          context: _buildPerformanceContext(context, contextBuilder),
          error: error,
          stackTrace: stackTrace,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  static T measurePerformance<T>(
    String operation,
    T Function() body, {
    Set<String>? tags,
    Map<String, Object?>? context,
    Map<String, Object?> Function()? contextBuilder,
  }) {
    if (!performanceLoggingEnabled) {
      return body();
    }

    final stopwatch = Stopwatch()..start();
    try {
      final result = body();
      stopwatch.stop();
      if (performanceLoggingEnabled) {
        recordPerformanceTask(
          operation: operation,
          elapsed: stopwatch.elapsed,
          status: 'ok',
          tags: tags,
          context: _buildPerformanceContext(context, contextBuilder),
        );
      }
      return result;
    } catch (error, stackTrace) {
      stopwatch.stop();
      if (performanceLoggingEnabled) {
        recordPerformanceTask(
          operation: operation,
          elapsed: stopwatch.elapsed,
          status: 'error',
          tags: tags,
          context: _buildPerformanceContext(context, contextBuilder),
          error: error,
          stackTrace: stackTrace,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  static void recordPerformanceTask({
    required String operation,
    required Duration elapsed,
    required String status,
    Set<String>? tags,
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!performanceLoggingEnabled) {
      return;
    }
    final normalizedOperation = _normalizeTagValue(operation);
    final taskId = _nextTaskId();
    final entryTags = <String>{
      performanceTag,
      'task:$normalizedOperation',
      phaseEndTag,
      'status:$status',
      ...?tags,
    };
    final metrics = <String, Object?>{
      'taskId': taskId,
      'operation': operation,
      'elapsedMs': elapsed.inMilliseconds,
      'status': status,
      if (context != null && context.isNotEmpty) 'context': context,
    };
    final message =
        'performance task=$operation status=$status elapsed=${elapsed.inMilliseconds}ms';
    final level = status == 'error' ? LogLevel.error : LogLevel.debug;
    _record(
      level: level,
      message: message,
      error: error,
      stackTrace: stackTrace,
      tags: entryTags,
      metrics: metrics,
    );
    developer.log(
      _formatDeveloperMessage(_sanitize(message), entryTags),
      name: _name,
      level: status == 'error' ? 1000 : 500,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static String _sanitize(String input) {
    final basicAuth = RegExp(r'(Basic\s+)[A-Za-z0-9+/=]+');
    final bearerAuth = RegExp(r'(Bearer\s+)[A-Za-z0-9\-._~+/=]+');
    return input
        .replaceAllMapped(basicAuth, (m) => '${m.group(1)}***')
        .replaceAllMapped(bearerAuth, (m) => '${m.group(1)}***');
  }

  static String _nextTaskId() {
    final sequence = (_taskSequence = (_taskSequence + 1) & 0xfffff);
    final micros = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    return '${micros}_${sequence.toRadixString(16)}';
  }

  static void _endTask(
    TaskHandle handle, {
    required String status,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? extraContext,
  }) {
    if (handle._closed) {
      return;
    }
    handle._closed = true;
    handle._stopwatch.stop();
    if (!handle._enabled || kReleaseMode || !_canRecordLogs) {
      return;
    }
    _recordTaskPhase(
      handle: handle,
      phase: 'end',
      status: _normalizeTaskStatus(status),
      elapsed: handle._stopwatch.elapsed,
      error: error,
      stackTrace: stackTrace,
      extraContext: extraContext,
    );
  }

  static String _normalizeTaskStatus(String status) {
    final normalized = _normalizeTagValue(status);
    return switch (normalized) {
      'error' => 'error',
      'canceled' || 'cancelled' => 'canceled',
      _ => 'ok',
    };
  }

  static void _recordTaskPhase({
    required TaskHandle handle,
    required String phase,
    required String status,
    required Duration elapsed,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? extraContext,
  }) {
    final isEnd = phase == 'end';
    final entryTags = <String>{
      ...handle.tags,
      isEnd ? phaseEndTag : phaseStartTag,
      if (isEnd) 'status:$status',
    };
    final mergedContext = <String, Object?>{
      ...?handle.context,
      ...?extraContext,
    };
    final metrics = <String, Object?>{
      'taskId': handle.taskId,
      if (handle.parentTaskId != null) 'parentTaskId': handle.parentTaskId,
      'operation': handle.name,
      'phase': phase,
      if (isEnd) 'elapsedMs': elapsed.inMilliseconds,
      if (isEnd) 'status': status,
      if (mergedContext.isNotEmpty) 'context': mergedContext,
    };
    final message = isEnd
        ? 'task=${handle.name} status=$status elapsed=${elapsed.inMilliseconds}ms taskId=${handle.taskId}'
        : 'task=${handle.name} phase=start taskId=${handle.taskId}';
    final level = switch (status) {
      'error' => LogLevel.error,
      'canceled' => LogLevel.warn,
      _ => LogLevel.debug,
    };
    _record(
      level: level,
      message: message,
      error: error,
      stackTrace: stackTrace,
      tags: entryTags,
      metrics: metrics,
    );
    developer.log(
      _formatDeveloperMessage(_sanitize(message), entryTags),
      name: _name,
      level: switch (level) {
        LogLevel.error => 1000,
        LogLevel.warn => 900,
        LogLevel.info => 800,
        LogLevel.debug => 500,
      },
      error: error,
      stackTrace: stackTrace,
    );
  }

  static Map<String, Object?>? _buildPerformanceContext(
    Map<String, Object?>? context,
    Map<String, Object?> Function()? contextBuilder,
  ) {
    if (contextBuilder == null) {
      return context;
    }
    try {
      return contextBuilder();
    } catch (_) {
      return context;
    }
  }

  static String _formatDeveloperMessage(String message, Set<String>? tags) {
    final safeTags = _sanitizeTags(tags);
    if (safeTags.isEmpty) {
      return message;
    }
    return '[${safeTags.join(' ')}] $message';
  }

  static Set<String> _sanitizeTags(Set<String>? tags) {
    if (tags == null || tags.isEmpty) {
      return const <String>{};
    }
    return tags
        .map((tag) => _sanitize(tag.trim()))
        .where((tag) => tag.isNotEmpty)
        .toSet();
  }

  static String _normalizeTagValue(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_\-]+'),
      '_',
    );
    return normalized.isEmpty ? 'unknown' : normalized;
  }

  static String _safePathSegment(String segment) {
    final lower = segment.toLowerCase();
    if (lower.startsWith('ses_') ||
        lower.startsWith('msg_') ||
        lower.startsWith('part_') ||
        lower.length > 24 ||
        RegExp(r'^[a-f0-9]{16,}$').hasMatch(lower)) {
      return ':id';
    }
    return _sanitize(segment);
  }

  static String _shortHash(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static Map<String, Object?>? _sanitizeMetrics(Map<String, Object?>? metrics) {
    if (metrics == null || metrics.isEmpty) {
      return null;
    }
    return <String, Object?>{
      for (final entry in metrics.entries)
        entry.key: _sanitizeMetricValue(entry.value, key: entry.key),
    };
  }

  static Object? _sanitizeMetricValue(Object? value, {String? key}) {
    if (key != null && _isSensitiveMetricKey(key)) {
      return '***';
    }
    if (value == null || value is bool || value is num) {
      return value;
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is Uri) {
      return _sanitize(value.toString());
    }
    if (value is Map) {
      return <String, Object?>{
        for (final entry in value.entries)
          entry.key.toString(): _sanitizeMetricValue(
            entry.value,
            key: entry.key.toString(),
          ),
      };
    }
    if (value is Iterable) {
      return value.map(_sanitizeMetricValue).toList(growable: false);
    }
    return _sanitize(value.toString());
  }

  static bool _isSensitiveMetricKey(String key) {
    final normalized = key.toLowerCase();
    return normalized.contains('authorization') ||
        normalized.contains('token') ||
        normalized.contains('password') ||
        normalized.contains('secret') ||
        normalized.contains('cookie') ||
        normalized.contains('apikey') ||
        normalized.contains('api_key');
  }

  static void _record({
    required LogLevel level,
    required String message,
    Object? error,
    StackTrace? stackTrace,
    Set<String>? tags,
    Map<String, Object?>? metrics,
  }) {
    if (!_canRecordLogs) {
      return;
    }
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: _sanitize(message),
      error: error == null ? null : _sanitize(error.toString()),
      stackTrace: stackTrace?.toString(),
      tags: Set<String>.unmodifiable(_sanitizeTags(tags)),
      metrics: _sanitizeMetrics(metrics),
    );
    _buffer.add(entry);
    if (_buffer.length > _maxEntries) {
      _buffer.removeRange(0, _buffer.length - _maxEntries);
    }
    _entries.value = UnmodifiableListView<LogEntry>(
      List<LogEntry>.from(_buffer),
    );
  }

  static ValueListenable<UnmodifiableListView<LogEntry>> get entries =>
      _entries;

  static List<LogEntry> filteredEntries({
    Duration? timeRange,
    Set<LogLevel>? levels,
    Set<String>? tags,
    String? query,
  }) {
    final normalizedQuery = query?.trim().toLowerCase() ?? '';
    final activeLevels = levels;
    final activeTags = _sanitizeTags(tags);
    final cutoff = timeRange == null
        ? null
        : DateTime.now().subtract(timeRange);
    return _buffer
        .where((entry) {
          if (cutoff != null && entry.timestamp.isBefore(cutoff)) {
            return false;
          }
          if (activeLevels != null &&
              activeLevels.isNotEmpty &&
              !activeLevels.contains(entry.level)) {
            return false;
          }
          if (activeTags.isNotEmpty &&
              entry.tags.intersection(activeTags).isEmpty) {
            return false;
          }
          if (normalizedQuery.isEmpty) {
            return true;
          }
          return entry.message.toLowerCase().contains(normalizedQuery) ||
              (entry.error?.toLowerCase().contains(normalizedQuery) ?? false) ||
              (entry.stackTrace?.toLowerCase().contains(normalizedQuery) ??
                  false) ||
              entry.tags.join(' ').toLowerCase().contains(normalizedQuery) ||
              (entry.metrics == null
                  ? false
                  : entry.metrics.toString().toLowerCase().contains(
                      normalizedQuery,
                    ));
        })
        .toList(growable: false);
  }

  static String _encodeMetrics(Map<String, Object?> metrics) {
    try {
      return jsonEncode(metrics);
    } catch (_) {
      return metrics.toString();
    }
  }

  static String exportEntries({List<LogEntry>? entries}) {
    final exportEntries = entries ?? _buffer;
    final buffer = StringBuffer()
      ..writeln('=== CodeWalk Debug Logs ===')
      ..writeln('Session started: ${_sessionStartedAt.toIso8601String()}')
      ..writeln('Platform: ${_platformLabel()}')
      ..writeln('Exported: ${DateTime.now().toIso8601String()}')
      ..writeln('Total entries: ${exportEntries.length}')
      ..writeln();

    for (final entry in exportEntries) {
      buffer.writeln(entry.toExportLine());
    }
    return buffer.toString();
  }

  static String _platformLabel() {
    if (kIsWeb) {
      return 'web';
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.linux => 'linux',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      _ => 'unknown',
    };
  }

  static void clearEntries() {
    _buffer.clear();
    _entries.value = UnmodifiableListView<LogEntry>(const <LogEntry>[]);
  }
}

enum LogLevel { debug, info, warn, error }

class TaskHandle {
  TaskHandle._({
    required this.name,
    required this.normalizedName,
    required this.taskId,
    required this.parentTaskId,
    required Set<String> tags,
    required Map<String, Object?>? context,
  }) : _enabled = true,
       tags = Set<String>.unmodifiable(tags),
       context = context == null
           ? null
           : Map<String, Object?>.unmodifiable(context),
       _stopwatch = Stopwatch()..start();

  TaskHandle._disabled({
    required String name,
    Set<String>? tags,
    Map<String, Object?>? context,
  }) : name = name,
       normalizedName = AppLogger._normalizeTagValue(name),
       taskId = 'disabled',
       parentTaskId = null,
       tags = Set<String>.unmodifiable(tags ?? const <String>{}),
       context = context == null
           ? null
           : Map<String, Object?>.unmodifiable(context),
       _enabled = false,
       _stopwatch = Stopwatch()..start();

  final String name;
  final String normalizedName;
  final String taskId;
  final String? parentTaskId;
  final Set<String> tags;
  final Map<String, Object?>? context;
  final bool _enabled;
  final Stopwatch _stopwatch;
  bool _closed = false;

  Duration get elapsed => _stopwatch.elapsed;
  bool get isClosed => _closed;

  void end({
    String status = 'ok',
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? extraContext,
  }) {
    AppLogger._endTask(
      this,
      status: status,
      error: error,
      stackTrace: stackTrace,
      extraContext: extraContext,
    );
  }

  void cancel({String? reason}) {
    end(
      status: 'canceled',
      extraContext: reason == null || reason.trim().isEmpty
          ? null
          : <String, Object?>{'reason': reason},
    );
  }
}

class LogEntry {
  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
    this.tags = const <String>{},
    this.metrics,
  });
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? error;
  final String? stackTrace;
  final Set<String> tags;
  final Map<String, Object?>? metrics;

  bool get isPerformance => tags.contains(AppLogger.performanceTag);
  bool get isTask => tags.any((tag) => tag.startsWith('task:'));
  bool get isTaskStart => tags.contains(AppLogger.phaseStartTag);
  bool get isTaskEnd => tags.contains(AppLogger.phaseEndTag);

  int? get elapsedMs {
    final value = metrics?['elapsedMs'];
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  String? get performanceOperation => metrics?['operation']?.toString();
  String? get performanceStatus => metrics?['status']?.toString();
  String? get taskOperation =>
      metrics?['operation']?.toString() ?? _taskTagName;
  String? get taskStatus => metrics?['status']?.toString();
  String? get taskId => metrics?['taskId']?.toString();
  String? get parentTaskId => metrics?['parentTaskId']?.toString();

  String? get _taskTagName {
    for (final tag in tags) {
      if (tag.startsWith('task:')) {
        return tag.substring('task:'.length);
      }
    }
    return null;
  }

  Map<String, Object?> toJson() {
    final sortedTags = tags.toList(growable: false)..sort();
    return <String, Object?>{
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'message': message,
      if (error != null) 'error': error,
      if (stackTrace != null) 'stackTrace': stackTrace,
      if (sortedTags.isNotEmpty) 'tags': sortedTags,
      if (metrics != null && metrics!.isNotEmpty) 'metrics': metrics,
    };
  }

  static LogEntry fromJson(Map<String, dynamic> json) {
    final tagsJson = json['tags'];
    final metricsJson = json['metrics'];
    return LogEntry(
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      level: LogLevel.values.firstWhere(
        (level) => level.name == json['level']?.toString(),
        orElse: () => LogLevel.info,
      ),
      message: json['message']?.toString() ?? '',
      error: json['error']?.toString(),
      stackTrace: json['stackTrace']?.toString(),
      tags: tagsJson is Iterable
          ? tagsJson.map((tag) => tag.toString()).toSet()
          : const <String>{},
      metrics: metricsJson is Map
          ? <String, Object?>{
              for (final entry in metricsJson.entries)
                entry.key.toString(): entry.value,
            }
          : null,
    );
  }

  String toExportLine() {
    final base =
        '[${timestamp.toIso8601String()}] ${level.name.toUpperCase()} $message';
    final buffer = StringBuffer(base);
    if (tags.isNotEmpty) {
      final sortedTags = tags.toList(growable: false)..sort();
      buffer.write('\n  Tags: ${sortedTags.join(', ')}');
    }
    if (metrics != null && metrics!.isNotEmpty) {
      buffer.write('\n  Metrics: ${AppLogger._encodeMetrics(metrics!)}');
    }
    if (error != null && error!.isNotEmpty) {
      buffer.write('\n  Error: $error');
    }
    if (stackTrace != null && stackTrace!.isNotEmpty) {
      buffer.write('\n  Stack:\n$stackTrace');
    }
    return buffer.toString();
  }
}
