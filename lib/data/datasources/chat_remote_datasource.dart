import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/chat_message_model.dart';
import '../models/chat_session_model.dart';
import '../../core/errors/exceptions.dart';

/// Chat remote data source
abstract class ChatRemoteDataSource {
  /// Get session list
  Future<List<ChatSessionModel>> getSessions({String? directory});

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
  Future<List<ChatSessionModel>> getSessions({String? directory}) async {
    try {
      final queryParams = <String, String>{};
      if (directory != null) {
        queryParams['directory'] = directory;
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
        return ChatMessageModel.fromJson(response.data);
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
    try {
      final queryParams = <String, String>{};
      if (directory != null) {
        queryParams['directory'] = directory;
      }

      print('=== Starting message send ===');
      print('Session ID: $sessionId');
      print('Message ID: ${input.messageId}');
      print('==================');

      // Start SSE listener for message update events
      final eventController = StreamController<ChatMessageModel>();
      late StreamSubscription eventSubscription;
      bool messageCompleted = false;

      // Create SSE listener
      try {
        final eventResponse = await dio.get(
          '/event',
          options: Options(
            headers: {
              'Accept': 'text/event-stream',
              'Cache-Control': 'no-cache',
            },
            responseType: ResponseType.stream,
          ),
        );

        if (eventResponse.statusCode == 200) {
          print('✅ Connected to event stream');

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

                    print('📨 Event received: $eventType');

                    if (eventType == 'message.updated') {
                      final properties =
                          event['properties'] as Map<String, dynamic>?;
                      final info = properties?['info'] as Map<String, dynamic>?;

                      if (info != null && info['sessionID'] == sessionId) {
                        print('Event: message.updated ${info['id']}');
                        _getCompleteMessage(
                              projectId,
                              sessionId,
                              info['id'] as String,
                            )
                            .then((message) {
                              if (message != null) {
                                eventController.add(message);
                                if (message.completedTime != null &&
                                    !messageCompleted) {
                                  messageCompleted = true;
                                  Future.delayed(
                                    const Duration(milliseconds: 500),
                                    () {
                                      eventSubscription.cancel();
                                      eventController.close();
                                    },
                                  );
                                }
                              }
                            })
                            .catchError((error) {
                              print('Failed to fetch complete message: $error');
                            });
                      }
                    } else if (eventType == 'message.part.updated') {
                      final properties =
                          event['properties'] as Map<String, dynamic>?;
                      final part = properties?['part'] as Map<String, dynamic>?;

                      if (part != null && part['sessionID'] == sessionId) {
                        print(
                          'Event: message.part.updated ${part['messageID']}',
                        );
                        _getCompleteMessage(
                              projectId,
                              sessionId,
                              part['messageID'] as String,
                            )
                            .then((message) {
                              if (message != null) {
                                eventController.add(message);
                                if (message.completedTime != null &&
                                    !messageCompleted) {
                                  messageCompleted = true;
                                  Future.delayed(
                                    const Duration(milliseconds: 500),
                                    () {
                                      eventSubscription.cancel();
                                      eventController.close();
                                    },
                                  );
                                }
                              }
                            })
                            .catchError((error) {
                              print('Failed to fetch complete message: $error');
                            });
                      }
                    } else if (eventType == 'session.updated') {
                      print('Event: session.updated');
                      // Session metadata updated - could notify provider
                    } else if (eventType == 'session.error') {
                      final properties =
                          event['properties'] as Map<String, dynamic>?;
                      final errorSessionId =
                          properties?['sessionID'] as String?;
                      if (errorSessionId == sessionId) {
                        print('Event: session.error for $sessionId');
                        final error = properties?['error']
                            as Map<String, dynamic>?;
                        if (error != null) {
                          final errorName =
                              error['name'] as String? ?? 'UnknownError';
                          eventController.addError(
                            Exception('Session error: $errorName'),
                          );
                        }
                        messageCompleted = true;
                        Future.delayed(
                          const Duration(milliseconds: 500),
                          () {
                            eventSubscription.cancel();
                            eventController.close();
                          },
                        );
                      }
                    } else if (eventType == 'session.idle') {
                      final properties =
                          event['properties'] as Map<String, dynamic>?;
                      if (properties?['sessionID'] == sessionId) {
                        print('Event: session.idle for $sessionId');
                        if (!messageCompleted) {
                          messageCompleted = true;
                          Future.delayed(
                            const Duration(milliseconds: 500),
                            () {
                              eventSubscription.cancel();
                              eventController.close();
                            },
                          );
                        }
                      }
                    } else if (eventType == 'message.removed') {
                      print('Event: message.removed');
                      // Message removed from session - UI should handle
                    } else if (eventType == 'message.part.removed') {
                      print('Event: message.part.removed');
                      // Part removed from message - UI should handle
                    } else {
                      // Other events (file.edited, permission.updated, etc.)
                      // Logged at debug level, not actionable for mobile client
                      print('Event: $eventType (ignored)');
                    }
                  } catch (e) {
                    print('Failed to parse event: $e');
                    print('Event data: $eventData');
                  }
                },
                onError: (error) {
                  print('Event stream error: $error');
                  eventController.addError(error);
                },
                onDone: () {
                  print('Event stream ended');
                  eventController.close();
                },
              );
        }
      } catch (e) {
        print('Failed to connect to event stream: $e');
      }

      // Send message request
      final response = await dio.post(
        '/session/$sessionId/message',
        data: input.toJson(),
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        print('✅ Message sent successfully');

        // Fetch initial message state
        if (input.messageId != null) {
          final initialMessage = await _getCompleteMessage(
            projectId,
            sessionId,
            input.messageId!,
          );
          if (initialMessage != null) {
            yield initialMessage;
          }
        }

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
      print('Message send exception: $e');
      throw const ServerException('Failed to send message');
    }
  }

  /// Get complete message payload (including parts)
  Future<ChatMessageModel?> _getCompleteMessage(
    String projectId,
    String sessionId,
    String messageId,
  ) async {
    try {
      final response = await dio.get('/session/$sessionId/message/$messageId');

      if (response.statusCode == 200) {
        final info = response.data['info'] as Map<String, dynamic>;
        final parts = response.data['parts'] as List<dynamic>;

        return ChatMessageModel.fromJson({...info, 'parts': parts});
      }
    } catch (e) {
      print('Failed to fetch complete message: $e');
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
        data: {
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
      throw const ServerException('Server error');
    } catch (e) {
      throw const ServerException('Server error');
    }
  }
}
