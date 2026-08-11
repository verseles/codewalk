import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/logging/app_logger.dart';
import '../../core/utils/path_utils.dart';

class ChatTitleGeneratorMessage {
  const ChatTitleGeneratorMessage({required this.role, required this.text});

  final String role;
  final String text;
}

abstract class ChatTitleGenerator {
  /// Session IDs of ephemeral title-generation sessions.
  /// Event handlers should ignore events from these sessions.
  static final Set<String> ephemeralSessionIds = <String>{};

  /// Title used for ephemeral title-generation sessions.
  /// Used as fallback filter when session ID is not yet known.
  static const String ephemeralSessionTitle = '_title_gen';

  Future<String?> generateTitle(
    List<ChatTitleGeneratorMessage> messages, {
    int maxWords,
    String? directory,
  });

  void notifySessionIdle({required String sessionId, String? directory}) {}

  void cancelPendingWaiters() {}

  int get pendingWaiterCount => 0;
}

enum _TitleWaitOutcome { sse, timeout, canceled }

class _TitleWaiter {
  _TitleWaiter({required this.directory});

  final String? directory;
  final Completer<_TitleWaitOutcome> completer = Completer<_TitleWaitOutcome>();
}

class OpenCodeTitleGenerator extends ChatTitleGenerator {
  OpenCodeTitleGenerator({
    required Dio dio,
    Duration waitTimeout = const Duration(seconds: 15),
  }) : _dio = dio,
       _waitTimeout = waitTimeout;

  final Dio _dio;
  final Duration _waitTimeout;
  final Map<String, _TitleWaiter> _waiters = <String, _TitleWaiter>{};
  var _cancellationGeneration = 0;

  static const int _maxTitleLength = 80;
  static const int _defaultMaxWords = 6;

  @override
  int get pendingWaiterCount => _waiters.length;

  @override
  void notifySessionIdle({required String sessionId, String? directory}) {
    final waiter = _waiters[sessionId];
    if (waiter == null || waiter.completer.isCompleted) {
      return;
    }
    final expectedDirectory = normalizeOptionalFilePath(waiter.directory);
    final eventDirectory = normalizeOptionalFilePath(directory);
    if (expectedDirectory != null &&
        eventDirectory != null &&
        expectedDirectory != eventDirectory) {
      return;
    }
    waiter.completer.complete(_TitleWaitOutcome.sse);
  }

  @override
  void cancelPendingWaiters() {
    _cancellationGeneration += 1;
    final waiters = _waiters.values.toList(growable: false);
    _waiters.clear();
    for (final waiter in waiters) {
      if (!waiter.completer.isCompleted) {
        waiter.completer.complete(_TitleWaitOutcome.canceled);
      }
    }
  }

  @override
  Future<String?> generateTitle(
    List<ChatTitleGeneratorMessage> messages, {
    int maxWords = _defaultMaxWords,
    String? directory,
  }) async {
    if (messages.isEmpty) return null;

    String? sessionId;
    var completionReason = 'error';
    var messageGetCount = 0;
    final stopwatch = Stopwatch()..start();
    final cancellationGeneration = _cancellationGeneration;
    final normalizedDirectory = normalizeOptionalFilePath(directory);
    final queryParameters = normalizedDirectory == null
        ? null
        : <String, String>{'directory': normalizedDirectory};
    try {
      // 1. Create ephemeral session
      final createResp = await _dio.post<dynamic>(
        '/session',
        data: <String, dynamic>{'title': '_title_gen'},
        queryParameters: queryParameters,
      );
      sessionId = (createResp.data as Map<String, dynamic>)['id'] as String?;
      if (sessionId == null) return null;
      ChatTitleGenerator.ephemeralSessionIds.add(sessionId);
      if (cancellationGeneration != _cancellationGeneration) {
        completionReason = _TitleWaitOutcome.canceled.name;
        return null;
      }
      final waiter = _TitleWaiter(directory: normalizedDirectory);
      _waiters[sessionId] = waiter;

      // 2. Send prompt with agent: "title" (no model → server uses agent default)
      final effectiveMaxWords = maxWords.clamp(1, 12).toInt();
      final prompt = _buildPrompt(messages, maxWords: effectiveMaxWords);
      await _dio.post<dynamic>(
        '/session/$sessionId/message',
        data: <String, dynamic>{
          'agent': 'title',
          'parts': <Map<String, String>>[
            <String, String>{'type': 'text', 'text': prompt},
          ],
          'noReply': false,
        },
        queryParameters: queryParameters,
      );

      final outcome = await waiter.completer.future.timeout(
        _waitTimeout,
        onTimeout: () => _TitleWaitOutcome.timeout,
      );
      _waiters.remove(sessionId);
      completionReason = outcome.name;
      if (outcome == _TitleWaitOutcome.canceled) {
        return null;
      }
      if (cancellationGeneration != _cancellationGeneration) {
        completionReason = _TitleWaitOutcome.canceled.name;
        return null;
      }

      messageGetCount = 1;
      final msgResp = await _dio.get<dynamic>(
        '/session/$sessionId/message',
        queryParameters: queryParameters,
      );
      final list = msgResp.data as List<dynamic>? ?? <dynamic>[];
      final title = _extractAssistantTitle(list);
      return title == null ? null : _normalizeTitle(title);
    } catch (error, stackTrace) {
      completionReason = 'error';
      AppLogger.warn(
        'Native title generation failed',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    } finally {
      stopwatch.stop();
      if (sessionId != null) {
        _waiters.remove(sessionId);
        try {
          await _dio.delete<dynamic>(
            '/session/$sessionId',
            queryParameters: queryParameters,
          );
        } catch (_) {}
        // Keep ID in filter set briefly so trailing SSE events
        // (session.idle, session.deleted) are still filtered out.
        final id = sessionId;
        Future<void>.delayed(const Duration(seconds: 5), () {
          ChatTitleGenerator.ephemeralSessionIds.remove(id);
        });
        AppLogger.info(
          'title_generation_complete session=${AppLogger.safeContextId(sessionId)} '
          'reason=$completionReason durationMs=${stopwatch.elapsedMilliseconds} '
          'messageGets=$messageGetCount fallback=${completionReason == _TitleWaitOutcome.timeout.name}',
        );
      }
    }
  }

  String _buildPrompt(
    List<ChatTitleGeneratorMessage> messages, {
    required int maxWords,
  }) {
    final lines = StringBuffer();
    for (var index = 0; index < messages.length; index += 1) {
      final message = messages[index];
      lines.writeln(
        '${index + 1}. ${message.role.toUpperCase()}: ${message.text}',
      );
    }

    return [
      'Based on the texts below, generate a title for this conversation with at most $_maxTitleLength characters.',
      'Use at most $maxWords words.',
      'Use plain text only, no quotes, no markdown.',
      lines.toString().trimRight(),
    ].join('\n\n');
  }

  /// Extracts assistant title from message list.
  ///
  /// The API returns messages in envelope format:
  /// `[{ "info": { "role": "assistant", "time": { "completed": ms } }, "parts": [...] }]`
  String? _extractAssistantTitle(List<dynamic> messages) {
    for (final raw in messages.reversed) {
      if (raw is! Map<String, dynamic>) continue;

      // Envelope format: { info: {...}, parts: [...] }
      final info = raw['info'] as Map<String, dynamic>?;
      final role = info?['role'] as String? ?? raw['role'] as String?;
      if (role != 'assistant') continue;

      // Check completion: info.time.completed or legacy completedTime
      final time = info?['time'];
      final bool isCompleted;
      if (time is Map<String, dynamic>) {
        isCompleted = time['completed'] != null;
      } else {
        isCompleted = raw['completedTime'] != null;
      }
      if (!isCompleted) continue;

      // Parts can be at top level or inside envelope
      final parts = raw['parts'];
      if (parts is! List) continue;
      final textParts = <String>[];
      for (final part in parts) {
        if (part is! Map<String, dynamic>) continue;
        if (part['type'] != 'text') continue;
        final text = part['text'];
        if (text is String && text.trim().isNotEmpty) {
          textParts.add(text.trim());
        }
      }
      if (textParts.isNotEmpty) {
        return textParts.join(' ');
      }
    }
    return null;
  }

  String? _normalizeTitle(String raw) {
    var normalized = raw.trim();
    if (normalized.length >= 2 &&
        normalized.startsWith('"') &&
        normalized.endsWith('"')) {
      normalized = normalized.substring(1, normalized.length - 1).trim();
    }
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return null;
    if (normalized.length > _maxTitleLength) {
      normalized = normalized.substring(0, _maxTitleLength).trimRight();
    }
    return normalized;
  }
}
