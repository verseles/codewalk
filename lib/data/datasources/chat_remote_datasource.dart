import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/config/feature_flags.dart';
import '../../core/errors/exceptions.dart';
import '../../core/i18n/l10n_bridge.dart';
import '../../core/logging/app_logger.dart';
import '../models/chat_message_model.dart';
import '../models/chat_realtime_model.dart';
import '../models/chat_session_model.dart';
import '../models/session_lifecycle_model.dart';

part 'chat_remote_datasource_helpers.dart';

/// Chat remote data source
abstract class ChatRemoteDataSource {
  /// Get session list
  Future<List<ChatSessionModel>> getSessions({
    String? directory,
    String? search,
    bool? rootsOnly,
    int? startEpochMs,
    int? limit,
  });

  /// Get session details
  Future<ChatSessionModel> getSession(
    String projectId,
    String sessionId, {
    String? directory,
  });

  /// Create session
  Future<ChatSessionModel> createSession(
    String projectId,
    SessionCreateInputModel input, {
    String? directory,
  });

  /// Update session
  Future<ChatSessionModel> updateSession(
    String projectId,
    String sessionId,
    SessionUpdateInputModel input, {
    String? directory,
  });

  /// Delete session
  Future<void> deleteSession(
    String projectId,
    String sessionId, {
    String? directory,
  });

  /// Share session
  Future<ChatSessionModel> shareSession(
    String projectId,
    String sessionId, {
    String? directory,
  });

  /// Unshare session
  Future<ChatSessionModel> unshareSession(
    String projectId,
    String sessionId, {
    String? directory,
  });

  /// Fork session
  Future<ChatSessionModel> forkSession(
    String projectId,
    String sessionId, {
    String? messageId,
    String? directory,
  });

  /// Get session status map
  Future<Map<String, SessionStatusModel>> getSessionStatus({String? directory});

  /// Get session children
  Future<List<ChatSessionModel>> getSessionChildren(
    String projectId,
    String sessionId, {
    String? directory,
  });

  /// Get session todos
  Future<List<SessionTodoModel>> getSessionTodo(
    String projectId,
    String sessionId, {
    String? directory,
  });

  /// Get session diff
  Future<List<SessionDiffModel>> getSessionDiff(
    String projectId,
    String sessionId, {
    String? messageId,
    String? directory,
  });

  /// Get session messages
  Future<List<ChatMessageModel>> getMessages(
    String projectId,
    String sessionId, {
    String? directory,
    int? limit,
  });

  /// Get message details
  Future<ChatMessageModel> getMessage(
    String projectId,
    String sessionId,
    String messageId, {
    String? directory,
  });

  /// Send chat message (streaming)
  Stream<ChatMessageModel> sendMessage(
    String projectId,
    String sessionId,
    ChatInputModel input, {
    String? directory,
  });

  /// Subscribe to realtime event stream.
  Stream<ChatEventModel> subscribeEvents({String? directory});

  /// Subscribe to global realtime event stream.
  Stream<ChatEventModel> subscribeGlobalEvents({
    void Function()? onConnected,
    void Function()? onDisconnected,
  });

  /// List pending permission requests.
  Future<List<ChatPermissionRequestModel>> listPermissions({String? directory});

  /// Reply to a permission request.
  Future<void> replyPermission({
    required String sessionId,
    required String requestId,
    required String reply,
    String? message,
    String? directory,
  });

  /// List pending question requests.
  Future<List<ChatQuestionRequestModel>> listQuestions({String? directory});

  /// Reply to a question request.
  Future<void> replyQuestion({
    required String requestId,
    required List<List<String>> answers,
    String? directory,
  });

  /// Reject a question request.
  Future<void> rejectQuestion({required String requestId, String? directory});

  /// Abort session
  Future<void> abortSession(
    String projectId,
    String sessionId, {
    String? directory,
  });

  /// Revert message
  Future<void> revertMessage(
    String projectId,
    String sessionId,
    String messageId, {
    String? directory,
  });

  /// Unrevert messages
  Future<void> unrevertMessages(
    String projectId,
    String sessionId, {
    String? directory,
  });

  /// Initialize session
  Future<void> initSession(
    String projectId,
    String sessionId, {
    required String messageId,
    required String providerId,
    required String modelId,
    String? directory,
  });

  /// Summarize session
  Future<void> summarizeSession(
    String projectId,
    String sessionId, {
    required String providerId,
    required String modelId,
    String? directory,
  });
}

/// Chat remote data source implementation
class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  ChatRemoteDataSourceImpl({required this.dio, Dio? sseDio}) : _sseDio = sseDio;

  static const String _traceFinalPrefix = 'CW_TRACE_FINAL';
  static const int _assistantMessageTailLimit = 120;
  static const int _idleStatusPollAttempts = 90;
  static const Duration _idleStatusPollInterval = Duration(seconds: 2);
  static const int _idleSettleListAttempts = 12;
  static const Duration _idleSettleListInterval = Duration(seconds: 1);
  static const int _resolveAssistantIdAttempts = 12;
  static const Duration _resolveAssistantIdRetryDelay = Duration(seconds: 2);
  static const int _knownAssistantIdsCacheMaxSessions = 64;

  /// Minimum seconds an SSE stream must stay alive before the
  /// reconnect-attempt counter is reset. Prevents infinite tight
  /// reconnection loops when a server accepts connections but
  /// immediately drops them.
  static const int _sseReconnectResetThresholdSeconds = 5;

  final Dio dio;

  /// Dedicated Dio for SSE streams, isolated from the regular HTTP pool.
  /// Falls back to [dio] when not provided (tests, web).
  final Dio? _sseDio;
  Dio get _effectiveSseDio => _sseDio ?? dio;
  final Map<String, Set<String>> _knownAssistantIdsCacheBySession =
      <String, Set<String>>{};

  Map<String, String> _withMessageTailLimit(Map<String, String> queryParams) {
    final merged = Map<String, String>.from(queryParams);
    // Intentionally force a bounded tail to avoid data-heavy full history fetches
    // during prompt_async completion reconciliation.
    merged['limit'] = '$_assistantMessageTailLimit';
    return merged;
  }

  void _cacheKnownAssistantIds(String sessionId, Set<String> ids) {
    if (ids.isEmpty) {
      _knownAssistantIdsCacheBySession.remove(sessionId);
      return;
    }
    _knownAssistantIdsCacheBySession.remove(sessionId);
    _knownAssistantIdsCacheBySession[sessionId] = Set<String>.from(ids);
    while (_knownAssistantIdsCacheBySession.length >
        _knownAssistantIdsCacheMaxSessions) {
      final oldestSessionId = _knownAssistantIdsCacheBySession.keys.first;
      _knownAssistantIdsCacheBySession.remove(oldestSessionId);
    }
  }

  void _invalidateKnownAssistantIdsCache(String sessionId) {
    _knownAssistantIdsCacheBySession.remove(sessionId);
  }

  void _traceFinalSend({
    required String sessionId,
    required String event,
    String? details,
  }) {
    final suffix = details == null || details.trim().isEmpty
        ? ''
        : ' details=${details.trim()}';
    AppLogger.info(
      '$_traceFinalPrefix datasource event=$event session=$sessionId$suffix',
    );
  }

  @override
  Future<List<ChatSessionModel>> getSessions({
    String? directory,
    String? search,
    bool? rootsOnly,
    int? startEpochMs,
    int? limit,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (directory != null) {
        queryParams['directory'] = directory;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (rootsOnly == true) {
        queryParams['roots'] = 'true';
      }
      if (startEpochMs != null) {
        queryParams['start'] = '$startEpochMs';
      }
      if (limit != null) {
        queryParams['limit'] = '$limit';
      }

      // Per updated API spec, session list endpoint is /session and does not require projectId in path
      final response = await dio.get(
        '/session',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => ChatSessionModel.fromJson(json)).toList();
      } else {
        throw const ServerException('Failed to load sessions');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage: 'Failed to load sessions',
      );
    } catch (e) {
      throw const ServerException('Failed to load sessions');
    }
  }

  @override
  Future<ChatSessionModel> getSession(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (directory != null) {
        queryParams['directory'] = directory;
      }

      // Per updated API spec, single session endpoint is /session/{id} and does not require projectId in path
      final response = await dio.get(
        '/session/$sessionId',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        return ChatSessionModel.fromJson(response.data);
      } else {
        throw const ServerException('Failed to load session');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage: 'Failed to load session',
      );
    } catch (e) {
      throw const ServerException('Failed to load session');
    }
  }

  @override
  Future<ChatSessionModel> createSession(
    String projectId,
    SessionCreateInputModel input, {
    String? directory,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (directory != null) {
        queryParams['directory'] = directory;
      }

      // Per updated API spec, create session endpoint is /session and does not require projectId in path
      final response = await dio.post(
        '/session',
        data: input.toJson(),
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        return ChatSessionModel.fromJson(response.data);
      } else {
        throw const ServerException('Failed to create session');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw const ValidationException('Invalid input parameters');
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage: 'Failed to create session',
      );
    } catch (e) {
      throw const ServerException('Failed to create session');
    }
  }

  @override
  Future<ChatSessionModel> updateSession(
    String projectId,
    String sessionId,
    SessionUpdateInputModel input, {
    String? directory,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (directory != null) {
        queryParams['directory'] = directory;
      }

      // Per updated API spec, update session endpoint is /session/{id} and does not require projectId in path
      final response = await dio.patch(
        '/session/$sessionId',
        data: input.toJson(),
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        return ChatSessionModel.fromJson(response.data);
      } else {
        throw const ServerException('Failed to update session');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      if (e.response?.statusCode == 400) {
        throw const ValidationException('Invalid input parameters');
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage: 'Failed to update session',
      );
    } catch (e) {
      throw const ServerException('Failed to update session');
    }
  }

  @override
  Future<void> deleteSession(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (directory != null) {
        queryParams['directory'] = directory;
      }

      // Per updated API spec, delete session endpoint is /session/{id} and does not require projectId in path
      final response = await dio.delete(
        '/session/$sessionId',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode != 200) {
        throw const ServerException('Failed to delete session');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage: 'Failed to delete session',
      );
    } catch (e) {
      throw const ServerException('Failed to delete session');
    }
  }

  @override
  Future<ChatSessionModel> shareSession(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (directory != null) {
        queryParams['directory'] = directory;
      }

      // Per updated API spec, share session endpoint is /session/{id}/share and does not require projectId in path
      final response = await dio.post(
        '/session/$sessionId/share',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        return ChatSessionModel.fromJson(response.data);
      } else {
        throw const ServerException('Failed to share session');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage: 'Failed to share session',
      );
    } catch (e) {
      throw const ServerException('Failed to share session');
    }
  }

  @override
  Future<ChatSessionModel> unshareSession(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (directory != null) {
        queryParams['directory'] = directory;
      }

      // Per updated API spec, unshare session endpoint is /session/{id}/share and does not require projectId in path
      final response = await dio.delete(
        '/session/$sessionId/share',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        return ChatSessionModel.fromJson(response.data);
      } else {
        throw const ServerException('Failed to unshare session');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage: 'Failed to unshare session',
      );
    } catch (e) {
      throw const ServerException('Failed to unshare session');
    }
  }

  @override
  Future<ChatSessionModel> forkSession(
    String projectId,
    String sessionId, {
    String? messageId,
    String? directory,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (directory != null) {
        queryParams['directory'] = directory;
      }
      final body = <String, dynamic>{};
      if (messageId != null && messageId.trim().isNotEmpty) {
        body['messageID'] = messageId.trim();
      }

      final response = await dio.post(
        '/session/$sessionId/fork',
        data: body.isEmpty ? null : body,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        return ChatSessionModel.fromJson(response.data);
      }
      throw const ServerException('Failed to fork session');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      if (e.response?.statusCode == 400) {
        throw const ValidationException('Invalid input parameters');
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage: 'Failed to fork session',
      );
    } catch (e) {
      throw const ServerException('Failed to fork session');
    }
  }

  @override
  Future<Map<String, SessionStatusModel>> getSessionStatus({
    String? directory,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (directory != null) {
        queryParams['directory'] = directory;
      }

      final response = await dio.get(
        '/session/status',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.statusCode != 200) {
        throw const ServerException('Failed to load session status');
      }
      final raw = response.data;
      if (raw is! Map) {
        return const <String, SessionStatusModel>{};
      }
      final map = <String, SessionStatusModel>{};
      raw.forEach((key, value) {
        if (value is Map) {
          map['$key'] = SessionStatusModel.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      });
      return map;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage: 'Failed to load session status',
      );
    } catch (_) {
      throw const ServerException('Failed to load session status');
    }
  }

  @override
  Future<List<ChatSessionModel>> getSessionChildren(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (directory != null) {
        queryParams['directory'] = directory;
      }

      final response = await dio.get(
        '/session/$sessionId/children',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.statusCode != 200) {
        throw const ServerException('Failed to load session children');
      }
      final data = response.data as List<dynamic>? ?? const <dynamic>[];
      return data
          .whereType<Map>()
          .map(
            (item) =>
                ChatSessionModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage: 'Failed to load session children',
      );
    } catch (_) {
      throw const ServerException('Failed to load session children');
    }
  }

  @override
  Future<List<SessionTodoModel>> getSessionTodo(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (directory != null) {
        queryParams['directory'] = directory;
      }

      final response = await dio.get(
        '/session/$sessionId/todo',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.statusCode != 200) {
        throw const ServerException('Failed to load session todo');
      }
      final data = response.data as List<dynamic>? ?? const <dynamic>[];
      return data
          .whereType<Map>()
          .map(
            (item) =>
                SessionTodoModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage: 'Failed to load session todo',
      );
    } catch (_) {
      throw const ServerException('Failed to load session todo');
    }
  }

  @override
  Future<List<SessionDiffModel>> getSessionDiff(
    String projectId,
    String sessionId, {
    String? messageId,
    String? directory,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (directory != null) {
        queryParams['directory'] = directory;
      }
      if (messageId != null && messageId.trim().isNotEmpty) {
        queryParams['messageID'] = messageId.trim();
      }

      final response = await dio.get(
        '/session/$sessionId/diff',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.statusCode != 200) {
        throw const ServerException('Failed to load session diff');
      }
      final data = response.data as List<dynamic>? ?? const <dynamic>[];
      return data
          .whereType<Map>()
          .map(
            (item) =>
                SessionDiffModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage: 'Failed to load session diff',
      );
    } catch (_) {
      throw const ServerException('Failed to load session diff');
    }
  }

  @override
  Future<List<ChatMessageModel>> getMessages(
    String projectId,
    String sessionId, {
    String? directory,
    int? limit,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (directory != null) {
        queryParams['directory'] = directory;
      }
      if (limit != null && limit > 0) {
        queryParams['limit'] = '$limit';
      }

      final response = await dio.get(
        '/session/$sessionId/message',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: Options(
          // Session history can be large; increase receive timeout to avoid 60-second interruption
          receiveTimeout: const Duration(minutes: 3),
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        // Each item follows { info: MessageObject, parts: Part[] }
        // Flatten to a single map compatible with ChatMessageModel.fromJson
        return data.map((item) {
          final map = item as Map<String, dynamic>;
          final info =
              (map['info'] as Map<String, dynamic>?) ?? <String, dynamic>{};
          final parts = (map['parts'] as List<dynamic>?) ?? <dynamic>[];
          return ChatMessageModel.fromJson({...info, 'parts': parts});
        }).toList();
      } else {
        throw const ServerException('Failed to load message list');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage: 'Failed to load message list',
      );
    } catch (e) {
      throw const ServerException('Failed to load message list');
    }
  }

  @override
  Future<ChatMessageModel> getMessage(
    String projectId,
    String sessionId,
    String messageId, {
    String? directory,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (directory != null) {
        queryParams['directory'] = directory;
      }

      final response = await dio.get(
        '/session/$sessionId/message/$messageId',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: Options(
          // Single message fetch can also be slow; increase receive timeout consistently
          receiveTimeout: const Duration(minutes: 3),
        ),
      );

      if (response.statusCode == 200) {
        final map = response.data as Map<String, dynamic>;
        final info =
            (map['info'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        final parts = (map['parts'] as List<dynamic>?) ?? <dynamic>[];
        return ChatMessageModel.fromJson({...info, 'parts': parts});
      } else {
        throw const ServerException('Failed to load message');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage: 'Failed to load message',
      );
    } catch (e) {
      throw const ServerException('Failed to load message');
    }
  }

  @override
  Stream<ChatMessageModel> sendMessage(
    String projectId,
    String sessionId,
    ChatInputModel input, {
    String? directory,
  }) async* {
    final eventController = StreamController<ChatMessageModel>();
    try {
      void trace(String event, {String? details}) {
        final baseDetails = 'messageId=${input.messageId ?? "-"}';
        final combined = details == null || details.trim().isEmpty
            ? baseDetails
            : '$baseDetails ${details.trim()}';
        _traceFinalSend(sessionId: sessionId, event: event, details: combined);
      }

      void emitCompletionMetric({
        required String mode,
        required String outcome,
        DateTime? startedAt,
        String? details,
      }) {
        final elapsedMs = startedAt == null
            ? -1
            : DateTime.now().difference(startedAt).inMilliseconds;
        final suffix = details == null || details.trim().isEmpty
            ? ''
            : ' ${details.trim()}';
        AppLogger.info(
          'CW_METRIC prompt_async_completion session=$sessionId messageId=${input.messageId ?? "-"} mode=$mode outcome=$outcome elapsedMs=$elapsedMs$suffix',
        );
      }

      final queryParams = <String, String>{};
      if (directory != null) {
        queryParams['directory'] = directory;
      }
      final sendStartMs = DateTime.now().millisecondsSinceEpoch;

      AppLogger.info(
        'Chat send start session=$sessionId provider=${input.providerId} model=${input.modelId} variant=${input.variant ?? "auto"} directory=${directory ?? "-"}',
      );
      AppLogger.info('Request messageID=${input.messageId ?? "<none>"}');
      trace(
        'send-start',
        details:
            'provider=${input.providerId} model=${input.modelId} variant=${input.variant ?? "auto"} mode=${input.mode ?? "-"} parts=${input.parts.length} sendStartMs=$sendStartMs',
      );

      if (input.mode == 'command') {
        final commandMessage = await _sendSlashCommand(
          sessionId,
          input,
          directory: directory,
        );
        yield commandMessage;
        return;
      }

      if (input.mode == 'shell') {
        final shellMessage = await _sendShellCommand(
          sessionId,
          input,
          directory: directory,
        );
        yield shellMessage;
        return;
      }

      var messageCompleted = false;
      String? activeAssistantMessageId;
      var fallbackCompletionWatchStarted = false;
      final knownAssistantMessageIds = <String>{
        ...?_knownAssistantIdsCacheBySession[sessionId],
      };
      var hasKnownAssistantBaseline = knownAssistantMessageIds.isNotEmpty;
      // Accept a small skew between client and server clocks when correlating
      // assistant messages to the current send.
      const freshnessLeewayMs = 5000;
      // Timestamp used to distinguish new messages from stale ones.
      // Without per-send SSE, resolveAssistantMessageId must skip
      // completed messages from previous sends.

      Future<void> loadKnownAssistantMessageIds() async {
        if (hasKnownAssistantBaseline) {
          trace(
            'known-assistant-baseline-cache-hit',
            details: 'count=${knownAssistantMessageIds.length}',
          );
          return;
        }
        try {
          final response = await dio.get(
            '/session/$sessionId/message',
            queryParameters: _withMessageTailLimit(queryParams),
          );
          if (response.statusCode != 200) {
            return;
          }
          final list = response.data as List<dynamic>? ?? const <dynamic>[];
          for (final raw in list) {
            if (raw is! Map) {
              continue;
            }
            final item = Map<String, dynamic>.from(raw);
            final infoRaw = item['info'];
            final info = infoRaw is Map<String, dynamic> ? infoRaw : item;
            final role = info['role'] as String?;
            final id = info['id'] as String?;
            if (role == 'assistant' && id != null && id.isNotEmpty) {
              knownAssistantMessageIds.add(id);
            }
          }
          hasKnownAssistantBaseline = true;
          _cacheKnownAssistantIds(sessionId, knownAssistantMessageIds);
          trace(
            'known-assistant-baseline-loaded',
            details: 'count=${knownAssistantMessageIds.length}',
          );
        } catch (error) {
          AppLogger.warn(
            'Failed to load known assistant message IDs before async send',
            error: error,
          );
          trace(
            'known-assistant-baseline-failed',
            details: 'error=${error.runtimeType}',
          );
        }
      }

      int extractCreatedTimeMs(dynamic timeValue) {
        if (timeValue is Map<String, dynamic>) {
          final created = timeValue['created'];
          if (created is num) {
            return created.toInt();
          }
        } else if (timeValue is num) {
          return timeValue.toInt();
        }
        return 0;
      }

      bool isFreshAssistantCandidate({
        required String messageId,
        required int createdMs,
        required int? completedMs,
      }) {
        if (activeAssistantMessageId != null &&
            activeAssistantMessageId == messageId) {
          return true;
        }
        final canUseClockLeeway =
            hasKnownAssistantBaseline && knownAssistantMessageIds.isNotEmpty;
        final freshnessThreshold = canUseClockLeeway
            ? sendStartMs - freshnessLeewayMs
            : sendStartMs;
        if (completedMs != null && completedMs > 0) {
          return completedMs >= freshnessThreshold;
        }
        if (createdMs > 0) {
          return createdMs >= freshnessThreshold;
        }
        return false;
      }

      bool isFreshAssistantMessageModel(ChatMessageModel message) {
        final createdMs = message.time.millisecondsSinceEpoch;
        final completedMs = message.completedTime?.millisecondsSinceEpoch;
        return isFreshAssistantCandidate(
          messageId: message.id,
          createdMs: createdMs,
          completedMs: completedMs,
        );
      }

      Future<String?> resolveAssistantMessageId() async {
        if (activeAssistantMessageId != null &&
            activeAssistantMessageId!.isNotEmpty) {
          trace(
            'resolve-assistant-id-reuse-active',
            details: 'activeAssistantMessageId=$activeAssistantMessageId',
          );
          return activeAssistantMessageId;
        }

        try {
          final response = await dio.get(
            '/session/$sessionId/message',
            queryParameters: _withMessageTailLimit(queryParams),
          );

          if (response.statusCode != 200) {
            AppLogger.warn(
              'Failed to resolve assistant message ID: unexpected status ${response.statusCode}',
            );
            return null;
          }

          final list = response.data as List<dynamic>? ?? const <dynamic>[];

          // Prefer incomplete messages (from current send) over completed
          // ones (from previous sends). Without per-send SSE, the latest
          // completed message can belong to an earlier request.
          String? incompleteId;
          var incompleteCreated = -1;
          String? freshCompletedId;
          var freshCompletedCreated = -1;
          var knownIdFilteredCount = 0;
          var staleTimeFilteredCount = 0;

          for (final raw in list) {
            if (raw is! Map) {
              continue;
            }
            final item = Map<String, dynamic>.from(raw);
            final infoRaw = item['info'];
            final info = infoRaw is Map<String, dynamic> ? infoRaw : item;

            final role = info['role'] as String?;
            final id = info['id'] as String?;
            if (role != 'assistant' || id == null || id.isEmpty) {
              continue;
            }
            if (knownAssistantMessageIds.contains(id)) {
              knownIdFilteredCount += 1;
              continue;
            }

            final created = extractCreatedTimeMs(info['time']);
            final hasCreatedTime = created > 0;
            final matchesActiveAssistantId =
                activeAssistantMessageId != null &&
                activeAssistantMessageId == id;
            final canUseClockLeeway =
                hasKnownAssistantBaseline &&
                knownAssistantMessageIds.isNotEmpty;
            final freshnessThreshold = canUseClockLeeway
                ? sendStartMs - freshnessLeewayMs
                : sendStartMs;
            final isFreshByTime = hasCreatedTime
                ? created >= freshnessThreshold
                : matchesActiveAssistantId;
            if (!isFreshByTime) {
              staleTimeFilteredCount += 1;
              continue;
            }
            final timeMap = info['time'];
            final completedMs = timeMap is Map<String, dynamic>
                ? (timeMap['completed'] as num?)?.toInt()
                : null;
            final isCompleted = completedMs != null && completedMs > 0;

            if (!isCompleted) {
              // In-progress message — likely from the current send.
              if (created >= incompleteCreated) {
                incompleteCreated = created;
                incompleteId = id;
              }
            } else {
              // Completed AFTER send started — fresh, not stale.
              if (created >= freshCompletedCreated) {
                freshCompletedCreated = created;
                freshCompletedId = id;
              }
            }
          }

          final candidateId = incompleteId ?? freshCompletedId;
          trace(
            'resolve-assistant-id-candidates',
            details:
                'knownBaseline=$hasKnownAssistantBaseline knownCount=${knownAssistantMessageIds.length} knownFiltered=$knownIdFilteredCount staleFiltered=$staleTimeFilteredCount incompleteId=${incompleteId ?? "-"} freshCompletedId=${freshCompletedId ?? "-"} candidate=${candidateId ?? "-"}',
          );
          if (candidateId != null) {
            activeAssistantMessageId = candidateId;
            knownAssistantMessageIds.add(candidateId);
            _cacheKnownAssistantIds(sessionId, knownAssistantMessageIds);
            AppLogger.info(
              'Resolved assistant message ID from session list: $candidateId',
            );
          } else {
            AppLogger.warn(
              'Unable to resolve assistant message ID from session list',
            );
          }
          return candidateId;
        } catch (error) {
          AppLogger.warn(
            'Failed to resolve assistant message ID from session list',
            error: error,
          );
          return null;
        }
      }

      bool isBusyStatusType(String? type) {
        final normalized = type?.trim().toLowerCase();
        return normalized == 'busy' || normalized == 'retry';
      }

      Future<SessionStatusModel?> loadCurrentSessionStatus() async {
        try {
          final response = await dio.get(
            '/session/status',
            queryParameters: queryParams.isNotEmpty ? queryParams : null,
          );
          if (response.statusCode != 200 || response.data is! Map) {
            return null;
          }
          final map = Map<String, dynamic>.from(response.data as Map);
          final rawStatus = map[sessionId];
          if (rawStatus is! Map) {
            return null;
          }
          return SessionStatusModel.fromJson(
            Map<String, dynamic>.from(rawStatus),
          );
        } catch (_) {
          return null;
        }
      }

      Future<List<Map<String, dynamic>>> loadSessionMessageEntries() async {
        try {
          final response = await dio.get(
            '/session/$sessionId/message',
            queryParameters: _withMessageTailLimit(queryParams),
          );
          if (response.statusCode != 200) {
            return const <Map<String, dynamic>>[];
          }
          final list = response.data as List<dynamic>? ?? const <dynamic>[];
          return list
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false);
        } catch (_) {
          return const <Map<String, dynamic>>[];
        }
      }

      ChatMessageModel? toChatMessageModel(Map<String, dynamic> entry) {
        final infoRaw = entry['info'];
        final info = infoRaw is Map<String, dynamic>
            ? infoRaw
            : (infoRaw is Map ? Map<String, dynamic>.from(infoRaw) : null);
        if (info == null || info.isEmpty) {
          return null;
        }
        final parts = (entry['parts'] as List<dynamic>?) ?? const <dynamic>[];
        return ChatMessageModel.fromJson({...info, 'parts': parts});
      }

      String? selectAssistantMessageIdFromEntries(
        List<Map<String, dynamic>> entries,
      ) {
        if (entries.isEmpty) {
          return null;
        }

        final assistantCandidates = <Map<String, dynamic>>[];
        for (final entry in entries) {
          final infoRaw = entry['info'];
          final info = infoRaw is Map<String, dynamic>
              ? infoRaw
              : (infoRaw is Map ? Map<String, dynamic>.from(infoRaw) : null);
          if (info == null) {
            continue;
          }
          final role = info['role'] as String?;
          final id = info['id'] as String?;
          if (role != 'assistant' || id == null || id.isEmpty) {
            continue;
          }

          final created = extractCreatedTimeMs(info['time']);
          final completedMs = info['time'] is Map<String, dynamic>
              ? ((info['time'] as Map<String, dynamic>)['completed'] as num?)
                    ?.toInt()
              : null;
          assistantCandidates.add(<String, dynamic>{
            'id': id,
            'created': created,
            'completedMs': completedMs ?? 0,
          });
        }

        if (assistantCandidates.isEmpty) {
          return null;
        }

        assistantCandidates.sort(
          (a, b) => (a['created'] as int).compareTo(b['created'] as int),
        );

        if (activeAssistantMessageId != null &&
            activeAssistantMessageId!.isNotEmpty) {
          final activeCandidate = assistantCandidates.firstWhere(
            (candidate) => candidate['id'] == activeAssistantMessageId,
            orElse: () => const <String, dynamic>{},
          );
          if (activeCandidate.isNotEmpty &&
              isFreshAssistantCandidate(
                messageId: activeCandidate['id'] as String,
                createdMs: activeCandidate['created'] as int,
                completedMs: activeCandidate['completedMs'] as int?,
              )) {
            return activeAssistantMessageId;
          }
        }

        final freshestUnknown = assistantCandidates.lastWhere((candidate) {
          final id = candidate['id'] as String;
          if (knownAssistantMessageIds.contains(id)) {
            return false;
          }
          return isFreshAssistantCandidate(
            messageId: id,
            createdMs: candidate['created'] as int,
            completedMs: candidate['completedMs'] as int?,
          );
        }, orElse: () => const <String, dynamic>{});
        if (freshestUnknown.isNotEmpty) {
          return freshestUnknown['id'] as String;
        }

        return null;
      }

      Future<ChatMessageModel?> resolveAssistantMessageFromSessionIdle(
        String reason,
      ) async {
        // Prefer OpenCode-like completion semantics: prompt_async accepts the
        // request, then session transitions to idle when the turn is finished.
        const statusPollAttempts = _idleStatusPollAttempts;
        const statusPollInterval = _idleStatusPollInterval;
        const settleListAttempts = _idleSettleListAttempts;
        const settleListInterval = _idleSettleListInterval;
        const idleBeforeBusyGrace = Duration(seconds: 3);

        var sawBusy = false;
        for (var attempt = 0; attempt < statusPollAttempts; attempt += 1) {
          if (messageCompleted || eventController.isClosed) {
            return null;
          }
          final status = await loadCurrentSessionStatus();
          if (isBusyStatusType(status?.type)) {
            sawBusy = true;
          }
          final isIdle = !isBusyStatusType(status?.type);
          if (!isIdle) {
            await Future<void>.delayed(statusPollInterval);
            continue;
          }

          final elapsedSinceSendMs =
              DateTime.now().millisecondsSinceEpoch - sendStartMs;
          if (!sawBusy &&
              elapsedSinceSendMs < idleBeforeBusyGrace.inMilliseconds) {
            trace(
              'fallback-watch-idle-before-busy-grace',
              details:
                  'reason=$reason idleAttempt=${attempt + 1} elapsedMs=$elapsedSinceSendMs',
            );
            await Future<void>.delayed(statusPollInterval);
            continue;
          }

          var candidateMessageId = activeAssistantMessageId;
          for (
            var settleAttempt = 0;
            settleAttempt < settleListAttempts;
            settleAttempt += 1
          ) {
            if (messageCompleted || eventController.isClosed) {
              return null;
            }
            final entries = await loadSessionMessageEntries();
            final selectedId = selectAssistantMessageIdFromEntries(entries);
            if (selectedId != null && selectedId.isNotEmpty) {
              candidateMessageId = selectedId;
              break;
            }
            await Future<void>.delayed(settleListInterval);
          }

          if (candidateMessageId == null || candidateMessageId.isEmpty) {
            // If no assistant candidate is visible yet, keep waiting for idle
            // convergence to avoid concluding too early on stale snapshots.
            trace(
              'fallback-watch-idle-no-candidate',
              details:
                  'reason=$reason idleAttempt=${attempt + 1} sawBusy=$sawBusy',
            );
            await Future<void>.delayed(statusPollInterval);
            continue;
          }

          ChatMessageModel? completed;
          for (
            var completionAttempt = 0;
            completionAttempt < 60;
            completionAttempt += 1
          ) {
            completed = await _getCompleteMessage(
              projectId,
              sessionId,
              candidateMessageId,
              directory: directory,
            );
            if (completed?.completedTime != null) {
              break;
            }
            await Future<void>.delayed(const Duration(seconds: 1));
          }
          if (completed != null) {
            if (!isFreshAssistantMessageModel(completed)) {
              trace(
                'fallback-watch-reject-stale-complete',
                details:
                    'reason=$reason candidateId=${completed.id} createdMs=${completed.time.millisecondsSinceEpoch} completedMs=${completed.completedTime?.millisecondsSinceEpoch ?? 0} sendStartMs=$sendStartMs',
              );
              await Future<void>.delayed(statusPollInterval);
              continue;
            }
            return completed;
          }

          final entries = await loadSessionMessageEntries();
          var rejectedStaleEntry = false;
          for (final entry in entries.reversed) {
            final infoRaw = entry['info'];
            final info = infoRaw is Map<String, dynamic>
                ? infoRaw
                : (infoRaw is Map ? Map<String, dynamic>.from(infoRaw) : null);
            if (info == null) {
              continue;
            }
            if ((info['id'] as String?) != candidateMessageId) {
              continue;
            }
            final parsed = toChatMessageModel(entry);
            if (parsed != null) {
              if (!isFreshAssistantMessageModel(parsed)) {
                rejectedStaleEntry = true;
                trace(
                  'fallback-watch-reject-stale-entry',
                  details:
                      'reason=$reason candidateId=${parsed.id} createdMs=${parsed.time.millisecondsSinceEpoch} completedMs=${parsed.completedTime?.millisecondsSinceEpoch ?? 0} sendStartMs=$sendStartMs',
                );
                continue;
              }
              return parsed;
            }
          }

          if (rejectedStaleEntry) {
            await Future<void>.delayed(statusPollInterval);
            continue;
          }

          trace(
            'fallback-watch-idle-candidate-not-ready',
            details:
                'reason=$reason idleAttempt=${attempt + 1} candidateId=$candidateMessageId',
          );
          await Future<void>.delayed(statusPollInterval);
          continue;
        }

        trace(
          'fallback-watch-idle-timeout',
          details: 'reason=$reason attempts=$statusPollAttempts',
        );
        return null;
      }

      Future<ChatMessageModel?> pollCompleteMessage(
        String messageId, {
        int maxAttempts = 120,
      }) async {
        AppLogger.info(
          'Polling assistant message completion id=$messageId attempts=$maxAttempts',
        );
        ChatMessageModel? latest;
        for (var attempt = 0; attempt < maxAttempts; attempt += 1) {
          if (attempt == 0 || (attempt + 1) % 10 == 0) {
            trace(
              'poll-complete-attempt',
              details: 'messageId=$messageId attempt=${attempt + 1}',
            );
          }
          final fetched = await _getCompleteMessage(
            projectId,
            sessionId,
            messageId,
            directory: directory,
          );
          if (fetched != null) {
            latest = fetched;
            if (fetched.completedTime != null) {
              trace(
                'poll-complete-success',
                details:
                    'messageId=$messageId attempt=${attempt + 1} completed=${fetched.completedTime?.millisecondsSinceEpoch ?? 0}',
              );
              AppLogger.info(
                'Assistant message completed via polling id=$messageId attempt=${attempt + 1}',
              );
              return fetched;
            }
          }
          if ((attempt + 1) % 15 == 0) {
            AppLogger.info(
              'Polling still waiting for completion id=$messageId attempt=${attempt + 1}',
            );
          }
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        AppLogger.warn('Polling ended without completion id=$messageId');
        trace('poll-complete-timeout', details: 'messageId=$messageId');
        return latest;
      }

      void maybeCloseEventController({Duration delay = Duration.zero}) {
        Future<void>.delayed(delay, () {
          if (eventController.isClosed || !messageCompleted) {
            return;
          }
          trace(
            'event-controller-close',
            details: 'delayMs=${delay.inMilliseconds}',
          );
          eventController.close();
        });
      }

      void emitPromptAsyncFailure({
        required String message,
        required String reason,
      }) {
        if (eventController.isClosed) {
          return;
        }
        trace(
          'fallback-watch-failure',
          details: 'reason=$reason message=$message',
        );
        eventController.addError(ServerException(message));
      }

      void startFallbackCompletionWatch({
        required String reason,
        Duration initialDelay = const Duration(seconds: 12),
      }) {
        if (fallbackCompletionWatchStarted) {
          return;
        }
        fallbackCompletionWatchStarted = true;

        unawaited(() async {
          if (initialDelay > Duration.zero) {
            await Future<void>.delayed(initialDelay);
          }

          if (messageCompleted || eventController.isClosed) {
            return;
          }

          final mode = FeatureFlags.promptAsyncIdleCompletion
              ? 'idle'
              : 'polling';
          final startedAt = DateTime.now();
          ChatMessageModel? completed;
          if (FeatureFlags.promptAsyncIdleCompletion) {
            trace('fallback-watch-mode-idle', details: 'reason=$reason');
            completed = await resolveAssistantMessageFromSessionIdle(reason);
          }

          if (completed == null) {
            if (FeatureFlags.promptAsyncIdleCompletion) {
              trace(
                'fallback-watch-idle-escalate-poll',
                details: 'reason=$reason',
              );
            }

            var fallbackMessageId = activeAssistantMessageId;
            for (
              var attempt = 0;
              (fallbackMessageId == null || fallbackMessageId.isEmpty) &&
                  attempt < _resolveAssistantIdAttempts;
              attempt += 1
            ) {
              fallbackMessageId = await resolveAssistantMessageId();
              if (fallbackMessageId != null && fallbackMessageId.isNotEmpty) {
                break;
              }
              await Future<void>.delayed(_resolveAssistantIdRetryDelay);
            }

            if (fallbackMessageId == null || fallbackMessageId.isEmpty) {
              AppLogger.warn(
                'Completion fallback aborted: message ID unresolved reason=$reason',
              );
              trace('fallback-watch-no-message-id', details: 'reason=$reason');
              emitCompletionMetric(
                mode: mode,
                outcome: 'no_message_id',
                startedAt: startedAt,
                details: 'reason=$reason',
              );
              _invalidateKnownAssistantIdsCache(sessionId);
              emitPromptAsyncFailure(
                message:
                    L10nBridge.current?.chatNoResponseFromServer ??
                    'No response from server. Please try again.',
                reason: 'no_message_id',
              );
              messageCompleted = true;
              maybeCloseEventController(
                delay: const Duration(milliseconds: 200),
              );
              return;
            }

            AppLogger.info(
              'Starting completion fallback reason=$reason id=$fallbackMessageId',
            );
            trace(
              'fallback-watch-start-poll',
              details: 'reason=$reason fallbackMessageId=$fallbackMessageId',
            );
            completed = await pollCompleteMessage(fallbackMessageId);
          }

          if (completed != null && !eventController.isClosed) {
            eventController.add(completed);
            knownAssistantMessageIds.add(completed.id);
            _cacheKnownAssistantIds(sessionId, knownAssistantMessageIds);
            trace(
              'fallback-watch-emitted-message',
              details:
                  'messageId=${completed.id} completed=${completed.completedTime?.millisecondsSinceEpoch ?? 0}',
            );
            emitCompletionMetric(
              mode: mode,
              outcome: 'completed',
              startedAt: startedAt,
              details: 'assistantMessageId=${completed.id}',
            );
          } else {
            trace('fallback-watch-no-message', details: 'reason=$reason');
            emitCompletionMetric(
              mode: mode,
              outcome: 'no_message',
              startedAt: startedAt,
              details: 'reason=$reason',
            );
            _invalidateKnownAssistantIdsCache(sessionId);
            emitPromptAsyncFailure(
              message:
                  L10nBridge.current?.chatNoResponseFromModel ??
                  'No response from model. Please try again.',
              reason: 'no_message',
            );
          }

          messageCompleted = true;
          maybeCloseEventController(delay: const Duration(milliseconds: 200));
        }());
      }

      // Per-send SSE intentionally skipped for prompt_async path.
      // The server monitors per-send SSE connections and aborts the AI agent
      // when it detects disconnection (e.g. half-open TCP after background
      // resume). Without per-send SSE, prompt_async processes fully async
      // and the provider-level SSE + polling handle message delivery.

      // Use async send endpoint to avoid cross-session abort coupling.
      await loadKnownAssistantMessageIds();
      trace(
        'prompt-async-request',
        details:
            'knownBaseline=$hasKnownAssistantBaseline knownCount=${knownAssistantMessageIds.length}',
      );
      final response = await dio.post(
        '/session/$sessionId/prompt_async',
        data: input.toJson(),
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode != 204 && response.statusCode != 200) {
        trace(
          'prompt-async-unexpected-status',
          details: 'status=${response.statusCode}',
        );
        throw ServerException(
          L10nBridge.current?.chatProviderErrorSendMessage ??
              'Failed to send message',
        );
      }

      final responseData = response.data;
      if (responseData is Map) {
        final payload = Map<String, dynamic>.from(responseData);
        final infoRaw = payload['info'];
        final info = infoRaw is Map<String, dynamic>
            ? infoRaw
            : infoRaw is Map
            ? Map<String, dynamic>.from(infoRaw)
            : payload;
        final responseMessageId = info['id'] as String?;
        if (responseMessageId != null && responseMessageId.trim().isNotEmpty) {
          activeAssistantMessageId = responseMessageId.trim();
          trace(
            'prompt-async-response-message-id',
            details: 'activeAssistantMessageId=$activeAssistantMessageId',
          );
        }

        // Some recent servers return the completed assistant payload directly
        // on prompt_async. When that happens, prefer the authoritative payload
        // instead of entering the fallback polling path.
        final responseParts = payload['parts'];
        final completedMs = (info['time'] is Map)
            ? ((info['time'] as Map)['completed'] as num?)?.toInt()
            : null;
        final isCompletedAssistantResponse =
            (info['role'] as String?) == 'assistant' &&
            responseParts is List &&
            completedMs != null &&
            completedMs > 0;
        if (isCompletedAssistantResponse) {
          final directMessage = ChatMessageModel.fromJson({
            ...Map<String, dynamic>.from(info),
            'parts': List<dynamic>.from(responseParts),
          });
          messageCompleted = true;
          emitCompletionMetric(
            mode: 'prompt_async',
            outcome: 'direct-response',
          );
          trace(
            'prompt-async-direct-complete',
            details:
                'messageId=${directMessage.id} completed=${directMessage.completedTime?.millisecondsSinceEpoch ?? 0}',
          );
          yield directMessage;
          return;
        }
      }

      AppLogger.info('Async send request accepted for session=$sessionId');
      trace('prompt-async-accepted', details: 'status=${response.statusCode}');

      // Polling delivers the response; provider-level SSE handles realtime.
      startFallbackCompletionWatch(
        reason: 'prompt-async-polling',
        initialDelay: Duration.zero,
      );

      await for (final message in eventController.stream) {
        trace(
          'event-controller-yield',
          details:
              'messageId=${message.id} role=${message.role} completed=${message.completedTime?.millisecondsSinceEpoch ?? 0} parts=${message.parts.length}',
        );
        yield message;
      }
    } on DioException catch (e) {
      AppLogger.info(
        'CW_TRACE_FINAL datasource event=dio-exception session=$sessionId status=${e.response?.statusCode ?? -1} messageId=${input.messageId ?? "-"}',
      );
      if (e.response?.statusCode == 404) {
        throw NotFoundException(
          L10nBridge.current?.chatProviderErrorSessionNotFound ??
              'Session not found',
        );
      }
      if (e.response?.statusCode == 400 || e.response?.statusCode == 422) {
        throw _validationExceptionFromDio(
          e,
          fallbackMessage:
              L10nBridge.current?.chatProviderErrorInvalidMessageFormat ??
              'Invalid message format',
        );
      }
      if (e.response?.statusCode == 409) {
        final message = _extractServerMessage(e.response?.data);
        throw ConflictException(
          message.isEmpty
              ? _fallbackServerMessageForStatus(
                  statusCode: 409,
                  fallbackMessage:
                      L10nBridge.current?.chatProviderErrorSendMessage ??
                      'Failed to send message',
                )
              : message,
          409,
        );
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage:
            L10nBridge.current?.chatProviderErrorSendMessage ??
            'Failed to send message',
      );
    } catch (e) {
      AppLogger.error('Message send exception', error: e);
      AppLogger.info(
        'CW_TRACE_FINAL datasource event=send-exception session=$sessionId messageId=${input.messageId ?? "-"} error=${e.runtimeType}',
      );
      if (e is ServerException ||
          e is ConflictException ||
          e is NotFoundException ||
          e is ValidationException) {
        rethrow;
      }
      throw ServerException(
        L10nBridge.current?.chatProviderErrorSendMessage ??
            'Failed to send message',
      );
    } finally {
      AppLogger.info('Chat send flow finalized for session=$sessionId');
      AppLogger.info(
        'CW_TRACE_FINAL datasource event=send-finalized session=$sessionId messageId=${input.messageId ?? "-"} eventControllerClosed=${eventController.isClosed}',
      );
      if (!eventController.isClosed) {
        eventController.close();
      }
    }
  }

  @override
  Stream<ChatEventModel> subscribeEvents({String? directory}) {
    return _subscribeEventStream(
      path: '/event',
      directory: directory,
      logLabel: 'Realtime event stream',
    );
  }

  @override
  Stream<ChatEventModel> subscribeGlobalEvents({
    void Function()? onConnected,
    void Function()? onDisconnected,
  }) {
    return _subscribeEventStream(
      path: '/global/event',
      logLabel: 'Global realtime event stream',
      onConnected: onConnected,
      onDisconnected: onDisconnected,
    );
  }

  Stream<ChatEventModel> _subscribeEventStream({
    required String path,
    String? directory,
    required String logLabel,
    void Function()? onConnected,
    void Function()? onDisconnected,
  }) {
    final queryParams = <String, String>{};
    if (directory != null && directory.trim().isNotEmpty) {
      queryParams['directory'] = directory;
    }

    final controller = StreamController<ChatEventModel>();
    StreamSubscription<String>? lineSubscription;
    CancelToken? requestCancelToken;
    Completer<void>? activeConnectionDone;
    var cancelled = false;

    Future<void> connectLoop() async {
      var reconnectAttempt = 0;
      while (!cancelled) {
        try {
          final cancelToken = CancelToken();
          requestCancelToken = cancelToken;
          final response = await _effectiveSseDio.get(
            path,
            queryParameters: queryParams.isNotEmpty ? queryParams : null,
            options: Options(
              headers: {
                'Accept': 'text/event-stream',
                'Cache-Control': 'no-cache',
              },
              responseType: ResponseType.stream,
              connectTimeout: const Duration(seconds: 5),
              // SSE should stay open for long periods.
              receiveTimeout: const Duration(hours: 2),
            ),
            cancelToken: cancelToken,
          );

          if (response.statusCode != 200) {
            throw const ServerException('Failed to subscribe to events');
          }
          onConnected?.call();

          final streamAliveStart = DateTime.now();
          final responseBody = response.data as ResponseBody;
          final streamDone = Completer<void>();
          activeConnectionDone = streamDone;
          lineSubscription = responseBody.stream
              .transform(
                StreamTransformer.fromHandlers(
                  handleData: (Uint8List data, EventSink<String> sink) {
                    sink.add(utf8.decode(data));
                  },
                ),
              )
              .transform(const LineSplitter())
              .where((line) => line.startsWith('data: '))
              .map((line) => line.substring(6))
              .where((data) => data.isNotEmpty && data != '[DONE]')
              .listen(
                (eventData) {
                  if (cancelled || controller.isClosed) {
                    return;
                  }
                  try {
                    final eventJson = jsonDecode(eventData);
                    if (eventJson is Map<String, dynamic>) {
                      final event = ChatEventModel.fromJson(eventJson);
                      controller.add(event);
                    }
                  } catch (error) {
                    AppLogger.warn(
                      'Failed to decode SSE event payload',
                      error: error,
                    );
                  }
                },
                onError: (error) {
                  if (cancelled) {
                    if (!streamDone.isCompleted) {
                      streamDone.complete();
                    }
                    return;
                  }
                  AppLogger.warn('$logLabel failure', error: error);
                  if (!streamDone.isCompleted) {
                    streamDone.complete();
                  }
                },
                onDone: () {
                  if (!streamDone.isCompleted) {
                    streamDone.complete();
                  }
                },
              );

          await streamDone.future;

          // Only reset the reconnect counter when the SSE stream survived
          // long enough to prove it was healthy. Without this guard, a
          // server that accepts connections but immediately drops them
          // keeps the counter at 0 → always 600ms delay → ~500 reconnects
          // in 5 min instead of the intended ~38.
          final streamAliveDuration = DateTime.now().difference(
            streamAliveStart,
          );
          if (streamAliveDuration.inSeconds >=
              _sseReconnectResetThresholdSeconds) {
            reconnectAttempt = 0;
          }
        } catch (error) {
          final isCancelledRequest =
              error is DioException && error.type == DioExceptionType.cancel;
          if (cancelled || isCancelledRequest) {
            // Subscription was intentionally cancelled while switching context.
          } else {
            final isClosedHttpStream =
                error is HttpException &&
                error.message.contains(
                  'Connection closed while receiving data',
                );
            final isExpectedReconnect =
                error is DioException &&
                (error.type == DioExceptionType.connectionTimeout ||
                    error.type == DioExceptionType.connectionError ||
                    error.type == DioExceptionType.receiveTimeout ||
                    error.type == DioExceptionType.unknown);
            if (isExpectedReconnect || isClosedHttpStream) {
              AppLogger.info(
                '$logLabel reconnecting after transient failure',
                error: error,
              );
            } else {
              AppLogger.warn('Failed to connect to $logLabel', error: error);
            }
          }
        } finally {
          onDisconnected?.call();
          requestCancelToken = null;
          activeConnectionDone = null;
          await lineSubscription?.cancel();
          lineSubscription = null;
        }

        if (cancelled) {
          break;
        }

        reconnectAttempt += 1;
        final clampedPower = reconnectAttempt > 5 ? 5 : reconnectAttempt;
        final delayMs = 300 * (1 << clampedPower);
        final boundedDelayMs = delayMs > 8000 ? 8000 : delayMs;
        // Apply ±20% jitter to prevent thundering-herd on coordinated
        // reconnects when multiple clients reconnect simultaneously.
        final jitterFactor = 1.0 + (0.4 * (_microsecondJitter() - 0.5));
        final jitteredMs = (boundedDelayMs * jitterFactor).round();
        await Future<void>.delayed(Duration(milliseconds: jitteredMs));
      }

      if (!controller.isClosed) {
        await controller.close();
      }
    }

    controller.onListen = () {
      unawaited(connectLoop());
    };
    controller.onCancel = () {
      cancelled = true;
      requestCancelToken?.cancel('event-stream-cancelled');
      final pendingDone = activeConnectionDone;
      if (pendingDone != null && !pendingDone.isCompleted) {
        pendingDone.complete();
      }
      unawaited(lineSubscription?.cancel());
      lineSubscription = null;
    };

    return controller.stream;
  }

  @override
  Future<List<ChatPermissionRequestModel>> listPermissions({
    String? directory,
  }) async {
    final queryParams = <String, String>{};
    if (directory != null && directory.trim().isNotEmpty) {
      queryParams['directory'] = directory;
    }

    try {
      final response = await dio.get(
        '/permission',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.statusCode != 200) {
        throw const ServerException('Failed to list permissions');
      }
      final data = response.data as List<dynamic>? ?? const <dynamic>[];
      return data
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .map(ChatPermissionRequestModel.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Permission route not found');
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage: 'Failed to list permissions',
      );
    } catch (_) {
      throw const ServerException('Failed to list permissions');
    }
  }

  @override
  Future<void> replyPermission({
    required String sessionId,
    required String requestId,
    required String reply,
    String? message,
    String? directory,
  }) async {
    final queryParams = <String, String>{};
    if (directory != null && directory.trim().isNotEmpty) {
      queryParams['directory'] = directory;
    }

    try {
      final body = <String, dynamic>{'response': reply};
      if (reply == 'always') {
        body['remember'] = true;
      }
      if (message != null && message.trim().isNotEmpty) {
        body['message'] = message.trim();
      }
      try {
        final response = await dio.post(
          '/session/$sessionId/permissions/$requestId',
          data: body,
          queryParameters: queryParams.isNotEmpty ? queryParams : null,
        );
        if (response.statusCode != 200) {
          throw const ServerException('Failed to reply permission');
        }
        return;
      } on DioException catch (e) {
        if (e.response?.statusCode == 404 || e.response?.statusCode == 405) {
          // Fallback to legacy route
          final legacyBody = <String, dynamic>{'reply': reply};
          if (reply == 'always') {
            legacyBody['remember'] = true;
          }
          if (message != null && message.trim().isNotEmpty) {
            legacyBody['message'] = message.trim();
          }
          final legacyResponse = await dio.post(
            '/permission/$requestId/reply',
            data: legacyBody,
            queryParameters: queryParams.isNotEmpty ? queryParams : null,
          );
          if (legacyResponse.statusCode != 200) {
            throw const ServerException('Failed to reply permission');
          }
          return;
        }
        rethrow;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Permission request not found');
      }
      if (e.response?.statusCode == 400 || e.response?.statusCode == 422) {
        throw _validationExceptionFromDio(
          e,
          fallbackMessage: 'Invalid permission reply',
        );
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage: 'Failed to reply permission',
      );
    } catch (_) {
      throw const ServerException('Failed to reply permission');
    }
  }

  @override
  Future<List<ChatQuestionRequestModel>> listQuestions({
    String? directory,
  }) async {
    final queryParams = <String, String>{};
    if (directory != null && directory.trim().isNotEmpty) {
      queryParams['directory'] = directory;
    }

    try {
      final response = await dio.get(
        '/question',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.statusCode != 200) {
        throw const ServerException('Failed to list questions');
      }
      final data = response.data as List<dynamic>? ?? const <dynamic>[];
      return data
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .map(ChatQuestionRequestModel.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Question route not found');
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage: 'Failed to list questions',
      );
    } catch (_) {
      throw const ServerException('Failed to list questions');
    }
  }

  @override
  Future<void> replyQuestion({
    required String requestId,
    required List<List<String>> answers,
    String? directory,
  }) async {
    final queryParams = <String, String>{};
    if (directory != null && directory.trim().isNotEmpty) {
      queryParams['directory'] = directory;
    }

    try {
      final response = await dio.post(
        '/question/$requestId/reply',
        data: {'answers': answers},
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.statusCode != 200) {
        throw const ServerException('Failed to reply question');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Question request not found');
      }
      if (e.response?.statusCode == 400 || e.response?.statusCode == 422) {
        throw _validationExceptionFromDio(
          e,
          fallbackMessage: 'Invalid question reply',
        );
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage: 'Failed to reply question',
      );
    } catch (_) {
      throw const ServerException('Failed to reply question');
    }
  }

  @override
  Future<void> rejectQuestion({
    required String requestId,
    String? directory,
  }) async {
    final queryParams = <String, String>{};
    if (directory != null && directory.trim().isNotEmpty) {
      queryParams['directory'] = directory;
    }

    try {
      final response = await dio.post(
        '/question/$requestId/reject',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.statusCode != 200) {
        throw const ServerException('Failed to reject question');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Question request not found');
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage: 'Failed to reject question',
      );
    } catch (_) {
      throw const ServerException('Failed to reject question');
    }
  }

  /// Get complete message payload (including parts)
  Future<ChatMessageModel?> _getCompleteMessage(
    String projectId,
    String sessionId,
    String messageId, {
    String? directory,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (directory != null && directory.trim().isNotEmpty) {
        queryParams['directory'] = directory;
      }

      final response = await dio.get(
        '/session/$sessionId/message/$messageId',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        final payload = response.data;
        if (payload is! Map) {
          return null;
        }
        final normalizedPayload = Map<String, dynamic>.from(payload);
        final infoRaw = normalizedPayload['info'];
        final partsRaw = normalizedPayload['parts'];
        if (infoRaw is! Map || partsRaw is! List) {
          return null;
        }
        final info = Map<String, dynamic>.from(infoRaw);
        final parts = List<dynamic>.from(partsRaw);

        return ChatMessageModel.fromJson({...info, 'parts': parts});
      }
    } catch (e) {
      AppLogger.warn('Failed to fetch complete message', error: e);
    }
    return null;
  }

  @override
  Future<void> abortSession(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (directory != null) {
        queryParams['directory'] = directory;
      }

      final response = await dio.post(
        '/session/$sessionId/abort',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode != 200) {
        throw const ServerException('Failed to abort session');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage: 'Failed to abort session',
      );
    } catch (e) {
      throw const ServerException('Failed to abort session');
    }
  }

  @override
  Future<void> revertMessage(
    String projectId,
    String sessionId,
    String messageId, {
    String? directory,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (directory != null) {
        queryParams['directory'] = directory;
      }

      final response = await dio.post(
        '/session/$sessionId/revert',
        data: {'messageID': messageId},
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode != 200) {
        throw const ServerException('Failed to revert message');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage: 'Failed to revert message',
      );
    } catch (e) {
      throw const ServerException('Failed to revert message');
    }
  }

  @override
  Future<void> unrevertMessages(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (directory != null) {
        queryParams['directory'] = directory;
      }

      final response = await dio.post(
        '/session/$sessionId/unrevert',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode != 200) {
        throw const ServerException('Failed to restore messages');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage: 'Failed to restore messages',
      );
    } catch (e) {
      throw const ServerException('Failed to restore messages');
    }
  }

  @override
  Future<void> initSession(
    String projectId,
    String sessionId, {
    required String messageId,
    required String providerId,
    required String modelId,
    String? directory,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (directory != null) {
        queryParams['directory'] = directory;
      }

      final response = await dio.post(
        '/session/$sessionId/init',
        data: {
          'messageID': messageId,
          'providerID': providerId,
          'modelID': modelId,
        },
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode != 200) {
        throw const ServerException('Failed to initialize session');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      if (e.response?.statusCode == 400) {
        throw const ValidationException('Invalid input parameters');
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage: 'Failed to initialize session',
      );
    } catch (e) {
      throw const ServerException('Failed to initialize session');
    }
  }

  @override
  Future<void> summarizeSession(
    String projectId,
    String sessionId, {
    required String providerId,
    required String modelId,
    String? directory,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (directory != null) {
        queryParams['directory'] = directory;
      }

      final response = await dio.post(
        '/session/$sessionId/summarize',
        data: {'providerID': providerId, 'modelID': modelId},
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode != 200) {
        throw ServerException(
          L10nBridge.current?.chatProviderErrorCompactSessionContext ??
              'Failed to compact session context',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw NotFoundException(
          L10nBridge.current?.chatProviderErrorNotFound ?? 'Resource not found',
        );
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage:
            L10nBridge.current?.chatProviderErrorCompactSessionContext ??
            'Failed to compact session context',
      );
    } catch (e) {
      throw ServerException(
        L10nBridge.current?.chatProviderErrorCompactSessionContext ??
            'Failed to compact session context',
      );
    }
  }

  /// Returns a deterministic-ish jitter value in [0, 1) derived from
  /// the current microsecond clock. Used to spread SSE reconnection
  /// attempts across time and avoid thundering-herd effects.
  double _microsecondJitter() {
    return (DateTime.now().microsecondsSinceEpoch % 1000) / 1000.0;
  }
}
