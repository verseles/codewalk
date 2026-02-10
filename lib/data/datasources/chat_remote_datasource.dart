import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/chat_message_model.dart';
import '../models/chat_realtime_model.dart';
import '../models/chat_session_model.dart';
import '../models/session_lifecycle_model.dart';
import '../../core/logging/app_logger.dart';
import '../../core/errors/exceptions.dart';

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

  /// List pending permission requests.
  Future<List<ChatPermissionRequestModel>> listPermissions({String? directory});

  /// Reply to a permission request.
  Future<void> replyPermission({
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
  const ChatRemoteDataSourceImpl({required this.dio});

  final Dio dio;

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
        throw const ServerException('Server error');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw const ServerException('Server error');
    } catch (e) {
      throw const ServerException('Server error');
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
        throw const ServerException('Server error');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw const ServerException('Server error');
    } catch (e) {
      throw const ServerException('Server error');
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
        throw const ServerException('Server error');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw const ValidationException('Invalid input parameters');
      }
      throw const ServerException('Server error');
    } catch (e) {
      throw const ServerException('Server error');
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
        throw const ServerException('Server error');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      if (e.response?.statusCode == 400) {
        throw const ValidationException('Invalid input parameters');
      }
      throw const ServerException('Server error');
    } catch (e) {
      throw const ServerException('Server error');
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
        throw const ServerException('Server error');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw const ServerException('Server error');
    } catch (e) {
      throw const ServerException('Server error');
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
        throw const ServerException('Server error');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw const ServerException('Server error');
    } catch (e) {
      throw const ServerException('Server error');
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
        throw const ServerException('Server error');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw const ServerException('Server error');
    } catch (e) {
      throw const ServerException('Server error');
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
      throw const ServerException('Server error');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      if (e.response?.statusCode == 400) {
        throw const ValidationException('Invalid input parameters');
      }
      throw const ServerException('Server error');
    } catch (e) {
      throw const ServerException('Server error');
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
        throw const ServerException('Server error');
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
      throw const ServerException('Server error');
    } catch (_) {
      throw const ServerException('Server error');
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
        throw const ServerException('Server error');
      }
      final data = response.data as List<dynamic>? ?? const <dynamic>[];
      return data
          .whereType<Map>()
          .map((item) => ChatSessionModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw const ServerException('Server error');
    } catch (_) {
      throw const ServerException('Server error');
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
        throw const ServerException('Server error');
      }
      final data = response.data as List<dynamic>? ?? const <dynamic>[];
      return data
          .whereType<Map>()
          .map(
            (item) => SessionTodoModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw const ServerException('Server error');
    } catch (_) {
      throw const ServerException('Server error');
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
        throw const ServerException('Server error');
      }
      final data = response.data as List<dynamic>? ?? const <dynamic>[];
      return data
          .whereType<Map>()
          .map(
            (item) => SessionDiffModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw const ServerException('Server error');
    } catch (_) {
      throw const ServerException('Server error');
    }
  }

  @override
  Future<List<ChatMessageModel>> getMessages(
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
        throw const ServerException('Server error');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw const ServerException('Server error');
    } catch (e) {
      throw const ServerException('Server error');
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
        throw const ServerException('Server error');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw const ServerException('Server error');
    } catch (e) {
      throw const ServerException('Server error');
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
    StreamSubscription<String>? eventSubscription;
    try {
      final queryParams = <String, String>{};
      if (directory != null) {
        queryParams['directory'] = directory;
      }

      AppLogger.info(
        'Chat send start session=$sessionId provider=${input.providerId} model=${input.modelId} variant=${input.variant ?? "auto"} directory=${directory ?? "-"}',
      );
      AppLogger.info('Request messageID=${input.messageId ?? "<none>"}');

      // Start SSE listener for message update events
      bool messageCompleted = false;
      bool eventStreamEnded = false;
      var pendingMessageFetches = 0;
      String? activeAssistantMessageId;
      var fallbackCompletionWatchStarted = false;

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

      Future<String?> resolveAssistantMessageId() async {
        if (activeAssistantMessageId != null &&
            activeAssistantMessageId!.isNotEmpty) {
          return activeAssistantMessageId;
        }

        try {
          final response = await dio.get(
            '/session/$sessionId/message',
            queryParameters: queryParams.isNotEmpty ? queryParams : null,
          );

          if (response.statusCode != 200) {
            AppLogger.warn(
              'Failed to resolve assistant message ID: unexpected status ${response.statusCode}',
            );
            return null;
          }

          final list = response.data as List<dynamic>? ?? const <dynamic>[];
          String? candidateId;
          var candidateCreated = -1;

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

            final created = extractCreatedTimeMs(info['time']);
            if (created >= candidateCreated) {
              candidateCreated = created;
              candidateId = id;
            }
          }

          if (candidateId != null) {
            activeAssistantMessageId = candidateId;
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

      Future<ChatMessageModel?> pollCompleteMessage(
        String messageId, {
        int maxAttempts = 120,
      }) async {
        AppLogger.info(
          'Polling assistant message completion id=$messageId attempts=$maxAttempts',
        );
        ChatMessageModel? latest;
        for (var attempt = 0; attempt < maxAttempts; attempt += 1) {
          final fetched = await _getCompleteMessage(
            projectId,
            sessionId,
            messageId,
            directory: directory,
          );
          if (fetched != null) {
            latest = fetched;
            if (fetched.completedTime != null) {
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
        return latest;
      }

      void maybeCloseEventController({Duration delay = Duration.zero}) {
        Future<void>.delayed(delay, () {
          if (eventController.isClosed) {
            return;
          }
          if (pendingMessageFetches > 0) {
            return;
          }
          if (!messageCompleted && !eventStreamEnded) {
            return;
          }

          eventSubscription?.cancel();
          if (!eventController.isClosed) {
            eventController.close();
          }
        });
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

          String? fallbackMessageId = activeAssistantMessageId;
          for (
            var attempt = 0;
            (fallbackMessageId == null || fallbackMessageId.isEmpty) &&
                attempt < 30;
            attempt += 1
          ) {
            fallbackMessageId = await resolveAssistantMessageId();
            if (fallbackMessageId != null && fallbackMessageId.isNotEmpty) {
              break;
            }
            await Future<void>.delayed(const Duration(seconds: 2));
          }

          if (fallbackMessageId == null || fallbackMessageId.isEmpty) {
            AppLogger.warn(
              'Completion fallback aborted: message ID unresolved reason=$reason',
            );
            messageCompleted = true;
            maybeCloseEventController(delay: const Duration(milliseconds: 200));
            return;
          }

          AppLogger.info(
            'Starting completion fallback reason=$reason id=$fallbackMessageId',
          );
          final completed = await pollCompleteMessage(fallbackMessageId);
          if (completed != null && !eventController.isClosed) {
            eventController.add(completed);
          }
          messageCompleted = true;
          maybeCloseEventController(delay: const Duration(milliseconds: 200));
        }());
      }

      void fetchAndEmitMessage(String messageId) {
        pendingMessageFetches += 1;
        _getCompleteMessage(
              projectId,
              sessionId,
              messageId,
              directory: directory,
            )
            .then((message) {
              if (message == null) {
                return;
              }

              if (!eventController.isClosed) {
                eventController.add(message);
              }

              if (message.completedTime != null && !messageCompleted) {
                messageCompleted = true;
                maybeCloseEventController(
                  delay: const Duration(milliseconds: 500),
                );
              }
            })
            .catchError((error) {
              AppLogger.warn('Failed to fetch complete message', error: error);
            })
            .whenComplete(() {
              pendingMessageFetches -= 1;
              if (pendingMessageFetches < 0) {
                pendingMessageFetches = 0;
              }
              maybeCloseEventController();
            });
      }

      // Create SSE listener
      try {
        final eventResponse = await dio.get(
          '/event',
          queryParameters: queryParams.isNotEmpty ? queryParams : null,
          options: Options(
            headers: {
              'Accept': 'text/event-stream',
              'Cache-Control': 'no-cache',
            },
            responseType: ResponseType.stream,
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(minutes: 5),
          ),
        );

        if (eventResponse.statusCode == 200) {
          AppLogger.info('Connected send-event stream for session=$sessionId');

          eventSubscription = (eventResponse.data as ResponseBody).stream
              .transform(
                StreamTransformer.fromHandlers(
                  handleData: (Uint8List data, EventSink<String> sink) {
                    sink.add(utf8.decode(data));
                  },
                ),
              )
              .transform(const LineSplitter())
              .where((line) => line.startsWith('data: '))
              .map((line) => line.substring(6)) // Remove "data: " prefix
              .where((data) => data.isNotEmpty && data != '[DONE]')
              .listen(
                (eventData) {
                  try {
                    final event = jsonDecode(eventData) as Map<String, dynamic>;
                    final eventType = event['type'] as String?;

                    AppLogger.debug('Event received: $eventType');

                    if (eventType == 'message.updated') {
                      final properties =
                          event['properties'] as Map<String, dynamic>?;
                      final info = properties?['info'] as Map<String, dynamic>?;

                      if (info != null && info['sessionID'] == sessionId) {
                        final messageId = info['id'] as String?;
                        if (messageId == null || messageId.isEmpty) {
                          return;
                        }
                        activeAssistantMessageId = messageId;
                        AppLogger.debug('Event: message.updated ${info['id']}');
                        fetchAndEmitMessage(messageId);
                      }
                    } else if (eventType == 'message.part.updated') {
                      final properties =
                          event['properties'] as Map<String, dynamic>?;
                      final part = properties?['part'] as Map<String, dynamic>?;

                      if (part != null && part['sessionID'] == sessionId) {
                        final messageId = part['messageID'] as String?;
                        if (messageId == null || messageId.isEmpty) {
                          return;
                        }
                        activeAssistantMessageId = messageId;
                        AppLogger.debug(
                          'Event: message.part.updated ${part['messageID']}',
                        );
                        fetchAndEmitMessage(messageId);
                      }
                    } else if (eventType == 'session.updated') {
                      AppLogger.debug('Event: session.updated');
                      // Session metadata updated - could notify provider
                    } else if (eventType == 'session.error') {
                      final properties =
                          event['properties'] as Map<String, dynamic>?;
                      final errorSessionId =
                          properties?['sessionID'] as String?;
                      if (errorSessionId == sessionId) {
                        AppLogger.warn('Event: session.error for $sessionId');
                        final error =
                            properties?['error'] as Map<String, dynamic>?;
                        if (error != null) {
                          final errorName =
                              error['name'] as String? ?? 'UnknownError';
                          if (!eventController.isClosed) {
                            eventController.addError(
                              Exception('Session error: $errorName'),
                            );
                          }
                        }
                        messageCompleted = true;
                        maybeCloseEventController(
                          delay: const Duration(milliseconds: 500),
                        );
                      }
                    } else if (eventType == 'session.idle') {
                      final properties =
                          event['properties'] as Map<String, dynamic>?;
                      if (properties?['sessionID'] == sessionId) {
                        AppLogger.debug('Event: session.idle for $sessionId');
                        if (!messageCompleted) {
                          messageCompleted = true;
                          maybeCloseEventController(
                            delay: const Duration(milliseconds: 500),
                          );
                        }
                      }
                    } else if (eventType == 'session.status') {
                      final properties =
                          event['properties'] as Map<String, dynamic>?;
                      if (properties?['sessionID'] == sessionId) {
                        final status =
                            properties?['status'] as Map<String, dynamic>?;
                        if (status?['type'] == 'idle' && !messageCompleted) {
                          messageCompleted = true;
                          maybeCloseEventController(
                            delay: const Duration(milliseconds: 500),
                          );
                        }
                      }
                    } else if (eventType == 'message.removed') {
                      AppLogger.debug('Event: message.removed');
                      // Message removed from session - UI should handle
                    } else if (eventType == 'message.part.removed') {
                      final properties =
                          event['properties'] as Map<String, dynamic>?;
                      final removedSessionId =
                          properties?['sessionID'] as String?;
                      final removedMessageId =
                          properties?['messageID'] as String?;
                      if (removedSessionId == sessionId &&
                          removedMessageId != null) {
                        activeAssistantMessageId = removedMessageId;
                        AppLogger.debug(
                          'Event: message.part.removed $removedMessageId',
                        );
                        fetchAndEmitMessage(removedMessageId);
                      }
                    } else {
                      // Other events (file.edited, permission.updated, etc.)
                      // Logged at debug level, not actionable for mobile client
                      AppLogger.debug('Event: $eventType (ignored)');
                    }
                  } catch (e) {
                    AppLogger.warn('Failed to parse event', error: e);
                    AppLogger.debug('Event data: $eventData');
                  }
                },
                onError: (error) {
                  AppLogger.warn('Event stream error', error: error);
                  if (!eventController.isClosed) {
                    eventController.addError(error);
                  }
                },
                onDone: () {
                  AppLogger.info(
                    'Send-event stream ended for session=$sessionId',
                  );
                  eventStreamEnded = true;
                  if (!messageCompleted && !eventController.isClosed) {
                    startFallbackCompletionWatch(
                      reason: 'send-event-stream-ended',
                      initialDelay: Duration.zero,
                    );
                    return;
                  }
                  maybeCloseEventController(
                    delay: const Duration(milliseconds: 200),
                  );
                },
              );
        }
      } catch (e) {
        AppLogger.warn('Failed to connect to event stream', error: e);
      }

      // Send message request
      final response = await dio.post(
        '/session/$sessionId/message',
        data: input.toJson(),
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        AppLogger.info('Send request accepted for session=$sessionId');

        // Parse immediate server response (`{info, parts}`) when available.
        final responseData = response.data;
        ChatMessageModel? immediateMessage;
        if (responseData is Map<String, dynamic>) {
          final info =
              (responseData['info'] as Map<String, dynamic>?) ??
              <String, dynamic>{};
          final parts =
              (responseData['parts'] as List<dynamic>?) ?? <dynamic>[];
          if (info.isNotEmpty) {
            activeAssistantMessageId = info['id'] as String?;
            immediateMessage = ChatMessageModel.fromJson({
              ...info,
              'parts': parts,
            });
            AppLogger.info(
              'Immediate assistant message received id=${activeAssistantMessageId ?? "-"} completed=${immediateMessage.completedTime != null}',
            );
            yield immediateMessage;
          }
        }

        // If the immediate response already completed, no streaming is needed.
        if (immediateMessage?.completedTime != null) {
          await eventSubscription?.cancel();
          if (!eventController.isClosed) {
            await eventController.close();
          }
          return;
        }

        // If stream connection is unavailable, return what we already have.
        if (eventSubscription == null) {
          final fallbackMessageId =
              activeAssistantMessageId ?? await resolveAssistantMessageId();
          if (fallbackMessageId != null) {
            AppLogger.info(
              'No send-event stream available; using polling fallback id=$fallbackMessageId',
            );
            final completed = await pollCompleteMessage(fallbackMessageId);
            if (completed != null) {
              yield completed;
            }
          } else {
            AppLogger.warn(
              'No send-event stream and assistant message ID unresolved',
            );
          }
          if (!eventController.isClosed) {
            await eventController.close();
          }
          return;
        }

        // Safety net: some servers keep /event connected but may not emit
        // message events for every request. Prevents stuck "sending".
        startFallbackCompletionWatch(reason: 'send-event-watchdog');

        // Listen for subsequent message updates
        await for (final message in eventController.stream) {
          yield message;
        }
      } else {
        throw const ServerException('Failed to send message');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Session not found');
      }
      if (e.response?.statusCode == 400) {
        throw const ValidationException('Invalid message format');
      }
      throw const ServerException('Failed to send message');
    } catch (e) {
      AppLogger.error('Message send exception', error: e);
      throw const ServerException('Failed to send message');
    } finally {
      AppLogger.info('Chat send flow finalized for session=$sessionId');
      eventSubscription?.cancel();
      if (!eventController.isClosed) {
        eventController.close();
      }
    }
  }

  @override
  Stream<ChatEventModel> subscribeEvents({String? directory}) {
    final queryParams = <String, String>{};
    if (directory != null && directory.trim().isNotEmpty) {
      queryParams['directory'] = directory;
    }

    final controller = StreamController<ChatEventModel>();
    StreamSubscription<String>? lineSubscription;
    var cancelled = false;

    Future<void> connectLoop() async {
      var reconnectAttempt = 0;
      while (!cancelled) {
        try {
          final response = await dio.get(
            '/event',
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
          );

          if (response.statusCode != 200) {
            throw const ServerException('Failed to subscribe to events');
          }

          reconnectAttempt = 0;
          final responseBody = response.data as ResponseBody;
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
                  AppLogger.warn('Realtime event stream failure', error: error);
                },
              );

          await lineSubscription?.asFuture<void>();
        } catch (error) {
          final isClosedHttpStream =
              error is HttpException &&
              error.message.contains('Connection closed while receiving data');
          final isExpectedReconnect =
              error is DioException &&
              (error.type == DioExceptionType.connectionTimeout ||
                  error.type == DioExceptionType.connectionError ||
                  error.type == DioExceptionType.receiveTimeout ||
                  error.type == DioExceptionType.unknown);
          if (isExpectedReconnect || isClosedHttpStream) {
            AppLogger.info(
              'Realtime event stream reconnecting after transient failure',
              error: error,
            );
          } else {
            AppLogger.warn(
              'Failed to connect to realtime event stream',
              error: error,
            );
          }
        } finally {
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
        await Future<void>.delayed(Duration(milliseconds: boundedDelayMs));
      }

      if (!controller.isClosed) {
        await controller.close();
      }
    }

    controller.onListen = () {
      unawaited(connectLoop());
    };
    controller.onCancel = () async {
      cancelled = true;
      await lineSubscription?.cancel();
      lineSubscription = null;
      if (!controller.isClosed) {
        await controller.close();
      }
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
          .map((item) => Map<String, dynamic>.from(item))
          .map(ChatPermissionRequestModel.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Permission route not found');
      }
      throw const ServerException('Failed to list permissions');
    } catch (_) {
      throw const ServerException('Failed to list permissions');
    }
  }

  @override
  Future<void> replyPermission({
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
      final body = <String, dynamic>{'reply': reply};
      if (message != null && message.trim().isNotEmpty) {
        body['message'] = message.trim();
      }
      final response = await dio.post(
        '/permission/$requestId/reply',
        data: body,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.statusCode != 200) {
        throw const ServerException('Failed to reply permission');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Permission request not found');
      }
      if (e.response?.statusCode == 400) {
        throw const ValidationException('Invalid permission reply');
      }
      throw const ServerException('Failed to reply permission');
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
          .map((item) => Map<String, dynamic>.from(item))
          .map(ChatQuestionRequestModel.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Question route not found');
      }
      throw const ServerException('Failed to list questions');
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
      if (e.response?.statusCode == 400) {
        throw const ValidationException('Invalid question reply');
      }
      throw const ServerException('Failed to reply question');
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
      throw const ServerException('Failed to reject question');
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
        final info = response.data['info'] as Map<String, dynamic>;
        final parts = response.data['parts'] as List<dynamic>;

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
        throw const ServerException('Server error');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw const ServerException('Server error');
    } catch (e) {
      throw const ServerException('Server error');
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
        throw const ServerException('Server error');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw const ServerException('Server error');
    } catch (e) {
      throw const ServerException('Server error');
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
        throw const ServerException('Server error');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw const ServerException('Server error');
    } catch (e) {
      throw const ServerException('Server error');
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
        throw const ServerException('Server error');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      if (e.response?.statusCode == 400) {
        throw const ValidationException('Invalid input parameters');
      }
      throw const ServerException('Server error');
    } catch (e) {
      throw const ServerException('Server error');
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
        throw const ServerException('Server error');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundException('Resource not found');
      }
      throw const ServerException('Server error');
    } catch (e) {
      throw const ServerException('Server error');
    }
  }
}
