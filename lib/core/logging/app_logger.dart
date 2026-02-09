import 'dart:developer' as developer;
import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Centralized logger with debug gating and lightweight redaction.
class AppLogger {
  AppLogger._();

  static const String _name = 'CodeWalk';
  static const int _maxEntries = 500;
  static final ValueNotifier<UnmodifiableListView<LogEntry>> _entries =
      ValueNotifier<UnmodifiableListView<LogEntry>>(
        UnmodifiableListView<LogEntry>(const <LogEntry>[]),
      );
  static final List<LogEntry> _buffer = <LogEntry>[];

  static void debug(String message, {Object? error, StackTrace? stackTrace}) {
    if (kReleaseMode) {
      return;
    }
    _record(
      level: LogLevel.debug,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
    developer.log(
      _sanitize(message),
      name: _name,
      level: 500,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void info(String message, {Object? error, StackTrace? stackTrace}) {
    _record(
      level: LogLevel.info,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
    developer.log(
      _sanitize(message),
      name: _name,
      level: 800,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void warn(String message, {Object? error, StackTrace? stackTrace}) {
    _record(
      level: LogLevel.warn,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
    developer.log(
      _sanitize(message),
      name: _name,
      level: 900,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    _record(
      level: LogLevel.error,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
    developer.log(
      _sanitize(message),
      name: _name,
      level: 1000,
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

  static void _record({
    required LogLevel level,
    required String message,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: _sanitize(message),
      error: error == null ? null : _sanitize(error.toString()),
      stackTrace: stackTrace?.toString(),
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

  static void clearEntries() {
    _buffer.clear();
    _entries.value = UnmodifiableListView<LogEntry>(const <LogEntry>[]);
  }
}

enum LogLevel { debug, info, warn, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? error;
  final String? stackTrace;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
  });
}
