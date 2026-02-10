import 'dart:async';
import 'dart:convert';
import 'dart:io';

class MockOpenCodeServer {
  MockOpenCodeServer({this.initialSessionTitle = 'Initial Session'});

  HttpServer? _server;
  int _sessionCounter = 1;
  final String initialSessionTitle;

  bool sendMessageValidationError = false;
  bool streamMessageUpdates = false;
  String? requiredEventDirectory;
  String? requiredMessageDirectory;
  Map<String, dynamic>? lastSendMessagePayload;
  int eventConnectionCount = 0;
  int eventCloseDelayMs = 900;
  List<Map<String, dynamic>> scriptedEvents = <Map<String, dynamic>>[];
  List<List<Map<String, dynamic>>> scriptedEventsByConnection =
      <List<Map<String, dynamic>>>[];
  List<Map<String, dynamic>> pendingPermissions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> pendingQuestions = <Map<String, dynamic>>[];
  String? lastPermissionReplyRequestId;
  Map<String, dynamic>? lastPermissionReplyPayload;
  String? lastQuestionReplyRequestId;
  Map<String, dynamic>? lastQuestionReplyPayload;
  String? lastQuestionRejectRequestId;
  Map<String, Map<String, dynamic>> sessionStatusById =
      <String, Map<String, dynamic>>{};
  final Map<String, List<Map<String, dynamic>>> sessionTodoById =
      <String, List<Map<String, dynamic>>>{};
  final Map<String, List<Map<String, dynamic>>> sessionDiffById =
      <String, List<Map<String, dynamic>>>{};

  final Map<String, Map<String, dynamic>> _sessionsById =
      <String, Map<String, dynamic>>{};
  final Map<String, List<Map<String, dynamic>>> _messagesBySession =
      <String, List<Map<String, dynamic>>>{};
  final Map<String, Map<String, dynamic>> _messageDetails =
      <String, Map<String, dynamic>>{};

  Future<void> start() async {
    _seedData();
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handleRequest);
  }

  Future<void> close() async {
    await _server?.close(force: true);
  }

  String get baseUrl {
    final server = _server;
    if (server == null) {
      throw StateError('Server not started');
    }
    return 'http://${server.address.host}:${server.port}';
  }

  void _seedData() {
    final session = _session('ses_1', title: initialSessionTitle);
    _sessionsById.clear();
    _sessionsById[session['id'] as String] = session;

    _messagesBySession.clear();
    _messagesBySession['ses_1'] = <Map<String, dynamic>>[];

    _messageDetails.clear();
    eventConnectionCount = 0;
    scriptedEvents = <Map<String, dynamic>>[];
    scriptedEventsByConnection = <List<Map<String, dynamic>>>[];
    requiredEventDirectory = null;
    requiredMessageDirectory = null;
    pendingPermissions = <Map<String, dynamic>>[];
    pendingQuestions = <Map<String, dynamic>>[];
    lastPermissionReplyRequestId = null;
    lastPermissionReplyPayload = null;
    lastQuestionReplyRequestId = null;
    lastQuestionReplyPayload = null;
    lastQuestionRejectRequestId = null;
    sessionStatusById = <String, Map<String, dynamic>>{
      'ses_1': <String, dynamic>{'type': 'idle'},
    };
    sessionTodoById
      ..clear()
      ..['ses_1'] = <Map<String, dynamic>>[];
    sessionDiffById
      ..clear()
      ..['ses_1'] = <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _session(
    String id, {
    required String title,
    String? parentId,
    int? archivedAt,
    String? shareUrl,
  }) {
    final map = <String, dynamic>{
      'id': id,
      'workspaceId': 'default',
      'directory': '/workspace/project',
      if (parentId != null) 'parentID': parentId,
      'time': <String, dynamic>{
        'created': 1739079900000,
        'updated': 1739079900000,
        if (archivedAt != null) 'archived': archivedAt,
      },
      'title': title,
      if (shareUrl != null) 'share': <String, dynamic>{'url': shareUrl},
    };
    return map;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final method = request.method;
    final segments = request.uri.pathSegments;

    if (method == 'GET' && request.uri.path == '/path') {
      await _writeJson(request.response, 200, <String, dynamic>{
        'config': '/tmp/config',
        'state': '/tmp/state',
        'worktree': '/workspace/project',
        'directory': '/workspace/project',
        'home': '/tmp/home',
      });
      return;
    }

    if (method == 'GET' && request.uri.path == '/global/health') {
      await _writeJson(request.response, 200, <String, dynamic>{'ok': true});
      return;
    }

    if (method == 'GET' && request.uri.path == '/provider') {
      await _writeJson(request.response, 200, <String, dynamic>{
        'all': <dynamic>[
          <String, dynamic>{
            'id': 'mock-provider',
            'name': 'Mock Provider',
            'env': <String>[],
            'models': <String, dynamic>{
              'mock-model': <String, dynamic>{
                'id': 'mock-model',
                'name': 'Mock Model',
                'release_date': '2026-01-01',
                'capabilities': <String, dynamic>{
                  'attachment': false,
                  'reasoning': true,
                  'temperature': true,
                  'toolcall': true,
                },
                'cost': <String, dynamic>{
                  'input': 0.001,
                  'output': 0.002,
                  'cache': <String, dynamic>{'read': 0.0001, 'write': 0.0002},
                },
                'limit': <String, dynamic>{'context': 128000, 'output': 4096},
              },
            },
          },
        ],
        'default': <String, String>{'mock-provider': 'mock-model'},
        'connected': <String>['mock-provider'],
      });
      return;
    }

    if (method == 'GET' && request.uri.path == '/event') {
      if (requiredEventDirectory != null &&
          request.uri.queryParameters['directory'] != requiredEventDirectory) {
        await _writeJson(request.response, 404, <String, dynamic>{
          'error': 'event directory mismatch',
        });
        return;
      }

      eventConnectionCount += 1;
      final hasScriptedEvents =
          scriptedEvents.isNotEmpty ||
          (eventConnectionCount - 1) < scriptedEventsByConnection.length;
      if (!streamMessageUpdates && !hasScriptedEvents) {
        await _writeJson(request.response, 404, <String, dynamic>{
          'error': 'disabled',
        });
        return;
      }

      request.response.statusCode = 200;
      request.response.headers.set('content-type', 'text/event-stream');
      request.response.headers.set('cache-control', 'no-cache');
      request.response.headers.set('connection', 'keep-alive');

      if (streamMessageUpdates) {
        // Wait until send endpoint creates message payload to avoid racing.
        var waitCycles = 0;
        while (!_messageDetails.containsKey('msg_ai_1') && waitCycles < 60) {
          waitCycles += 1;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }

        final event = <String, dynamic>{
          'type': 'message.updated',
          'properties': <String, dynamic>{
            'info': <String, dynamic>{'id': 'msg_ai_1', 'sessionID': 'ses_1'},
          },
        };
        request.response.write('data: ${jsonEncode(event)}\n\n');
        await request.response.flush();
      }

      final scriptedForConnection =
          (eventConnectionCount - 1) < scriptedEventsByConnection.length
          ? scriptedEventsByConnection[eventConnectionCount - 1]
          : scriptedEvents;
      for (final event in scriptedForConnection) {
        request.response.write('data: ${jsonEncode(event)}\n\n');
        await request.response.flush();
      }

      await Future<void>.delayed(Duration(milliseconds: eventCloseDelayMs));
      await request.response.close();
      return;
    }

    if (segments.length == 1 && segments[0] == 'permission') {
      if (method == 'GET') {
        await _writeJson(request.response, 200, pendingPermissions);
        return;
      }
    }

    if (segments.length == 3 &&
        segments[0] == 'permission' &&
        segments[2] == 'reply') {
      if (method == 'POST') {
        final requestId = segments[1];
        lastPermissionReplyRequestId = requestId;
        lastPermissionReplyPayload = await _readJsonBody(request);
        pendingPermissions = pendingPermissions
            .where((item) => item['id'] != requestId)
            .toList(growable: false);
        await _writeJson(request.response, 200, true);
        return;
      }
    }

    if (segments.length == 1 && segments[0] == 'question') {
      if (method == 'GET') {
        await _writeJson(request.response, 200, pendingQuestions);
        return;
      }
    }

    if (segments.length == 2 &&
        segments[0] == 'session' &&
        segments[1] == 'status' &&
        method == 'GET') {
      await _writeJson(request.response, 200, sessionStatusById);
      return;
    }

    if (segments.length == 3 &&
        segments[0] == 'question' &&
        segments[2] == 'reply') {
      if (method == 'POST') {
        final requestId = segments[1];
        lastQuestionReplyRequestId = requestId;
        lastQuestionReplyPayload = await _readJsonBody(request);
        pendingQuestions = pendingQuestions
            .where((item) => item['id'] != requestId)
            .toList(growable: false);
        await _writeJson(request.response, 200, true);
        return;
      }
    }

    if (segments.length == 3 &&
        segments[0] == 'question' &&
        segments[2] == 'reject') {
      if (method == 'POST') {
        final requestId = segments[1];
        lastQuestionRejectRequestId = requestId;
        pendingQuestions = pendingQuestions
            .where((item) => item['id'] != requestId)
            .toList(growable: false);
        await _writeJson(request.response, 200, true);
        return;
      }
    }

    if (segments.length == 1 && segments[0] == 'session') {
      if (method == 'GET') {
        var sessions = _sessionsById.values.toList(growable: false);

        final rootsOnly = request.uri.queryParameters['roots'] == 'true';
        if (rootsOnly) {
          sessions = sessions
              .where((session) => session['parentID'] == null)
              .toList(growable: false);
        }

        final search = request.uri.queryParameters['search']?.trim();
        if (search != null && search.isNotEmpty) {
          final normalized = search.toLowerCase();
          sessions = sessions
              .where(
                (session) => ((session['title'] as String?) ?? '')
                    .toLowerCase()
                    .contains(normalized),
              )
              .toList(growable: false);
        }

        final start = int.tryParse(request.uri.queryParameters['start'] ?? '');
        if (start != null) {
          sessions = sessions
              .where(
                (session) =>
                    ((session['time'] as Map<String, dynamic>)['updated'] as int) >=
                    start,
              )
              .toList(growable: false);
        }

        final limit = int.tryParse(request.uri.queryParameters['limit'] ?? '');
        if (limit != null && sessions.length > limit) {
          sessions = sessions.take(limit).toList(growable: false);
        }

        await _writeJson(request.response, 200, sessions);
        return;
      }

      if (method == 'POST') {
        final payload = await _readJsonBody(request);
        final title = (payload['title'] as String?) ?? 'New Session';
        final parentId = payload['parentID'] as String?;
        _sessionCounter += 1;
        final id = 'ses_$_sessionCounter';
        final created = _session(id, title: title, parentId: parentId);
        _sessionsById[id] = created;
        _messagesBySession[id] = <Map<String, dynamic>>[];
        sessionStatusById[id] = <String, dynamic>{'type': 'idle'};
        sessionTodoById[id] = <Map<String, dynamic>>[];
        sessionDiffById[id] = <Map<String, dynamic>>[];
        await _writeJson(request.response, 200, created);
        return;
      }
    }

    if (segments.length == 2 && segments[0] == 'session') {
      final sessionId = segments[1];

      if (method == 'DELETE') {
        _sessionsById.remove(sessionId);
        _messagesBySession.remove(sessionId);
        sessionStatusById.remove(sessionId);
        sessionTodoById.remove(sessionId);
        sessionDiffById.remove(sessionId);
        await _writeJson(request.response, 200, <String, dynamic>{'ok': true});
        return;
      }

      if (method == 'GET') {
        final found = _sessionsById[sessionId];
        if (found == null) {
          await _writeJson(request.response, 404, <String, dynamic>{
            'error': 'not found',
          });
          return;
        }
        await _writeJson(request.response, 200, found);
        return;
      }

      if (method == 'PATCH') {
        final found = _sessionsById[sessionId];
        if (found == null) {
          await _writeJson(request.response, 404, <String, dynamic>{
            'error': 'not found',
          });
          return;
        }
        final payload = await _readJsonBody(request);
        final title = payload['title'] as String?;
        final timePatch = payload['time'] as Map<String, dynamic>?;
        final archived = (timePatch?['archived'] as num?)?.toInt();

        final updated = Map<String, dynamic>.from(found);
        if (title != null) {
          updated['title'] = title;
        }
        final time = Map<String, dynamic>.from(
          updated['time'] as Map<String, dynamic>,
        );
        time['updated'] = DateTime.now().millisecondsSinceEpoch;
        if (archived != null) {
          if (archived <= 0) {
            time.remove('archived');
          } else {
            time['archived'] = archived;
          }
        }
        updated['time'] = time;
        _sessionsById[sessionId] = updated;
        await _writeJson(request.response, 200, updated);
        return;
      }
    }

    if (segments.length == 3 &&
        segments[0] == 'session' &&
        segments[2] == 'children' &&
        method == 'GET') {
      final parentId = segments[1];
      final children = _sessionsById.values
          .where((session) => session['parentID'] == parentId)
          .toList(growable: false);
      await _writeJson(request.response, 200, children);
      return;
    }

    if (segments.length == 3 &&
        segments[0] == 'session' &&
        segments[2] == 'todo' &&
        method == 'GET') {
      final sessionId = segments[1];
      await _writeJson(
        request.response,
        200,
        sessionTodoById[sessionId] ?? <Map<String, dynamic>>[],
      );
      return;
    }

    if (segments.length == 3 &&
        segments[0] == 'session' &&
        segments[2] == 'diff' &&
        method == 'GET') {
      final sessionId = segments[1];
      await _writeJson(
        request.response,
        200,
        sessionDiffById[sessionId] ?? <Map<String, dynamic>>[],
      );
      return;
    }

    if (segments.length == 3 &&
        segments[0] == 'session' &&
        segments[2] == 'share') {
      final sessionId = segments[1];
      final found = _sessionsById[sessionId];
      if (found == null) {
        await _writeJson(request.response, 404, <String, dynamic>{
          'error': 'not found',
        });
        return;
      }
      final next = Map<String, dynamic>.from(found);
      if (method == 'POST') {
        next['share'] = <String, dynamic>{
          'url': 'https://share.mock/s/$sessionId',
        };
        _sessionsById[sessionId] = next;
        await _writeJson(request.response, 200, next);
        return;
      }
      if (method == 'DELETE') {
        next.remove('share');
        _sessionsById[sessionId] = next;
        await _writeJson(request.response, 200, next);
        return;
      }
    }

    if (segments.length == 3 &&
        segments[0] == 'session' &&
        segments[2] == 'fork' &&
        method == 'POST') {
      final sessionId = segments[1];
      final source = _sessionsById[sessionId];
      if (source == null) {
        await _writeJson(request.response, 404, <String, dynamic>{
          'error': 'not found',
        });
        return;
      }

      _sessionCounter += 1;
      final nextId = 'ses_$_sessionCounter';
      final title = '${source['title']} (fork)';
      final created = _session(nextId, title: title, parentId: sessionId);
      _sessionsById[nextId] = created;
      _messagesBySession[nextId] = <Map<String, dynamic>>[];
      sessionStatusById[nextId] = <String, dynamic>{'type': 'idle'};
      sessionTodoById[nextId] = <Map<String, dynamic>>[];
      sessionDiffById[nextId] = <Map<String, dynamic>>[];
      await _writeJson(request.response, 200, created);
      return;
    }

    if (segments.length == 4 &&
        segments[0] == 'session' &&
        segments[2] == 'message') {
      final messageId = segments[3];

      if (method == 'GET') {
        if (requiredMessageDirectory != null &&
            request.uri.queryParameters['directory'] !=
                requiredMessageDirectory) {
          await _writeJson(request.response, 404, <String, dynamic>{
            'error': 'message directory mismatch',
          });
          return;
        }
        final found = _messageDetails[messageId];
        if (found == null) {
          await _writeJson(request.response, 404, <String, dynamic>{
            'error': 'not found',
          });
          return;
        }
        await _writeJson(request.response, 200, found);
        return;
      }

      await _writeJson(request.response, 405, <String, dynamic>{
        'error': 'method not allowed',
      });
      return;
    }

    if (segments.length == 3 &&
        segments[0] == 'session' &&
        segments[2] == 'message') {
      final sessionId = segments[1];

      if (method == 'GET') {
        await _writeJson(
          request.response,
          200,
          _messagesBySession[sessionId] ?? <Map<String, dynamic>>[],
        );
        return;
      }

      if (method == 'POST') {
        final payload = await _readJsonBody(request);
        lastSendMessagePayload = payload;

        if (sendMessageValidationError) {
          await _writeJson(request.response, 400, <String, dynamic>{
            'error': 'invalid',
          });
          return;
        }

        final createdAt = DateTime.now().millisecondsSinceEpoch;

        final immediate = <String, dynamic>{
          'info': <String, dynamic>{
            'id': 'msg_ai_1',
            'sessionID': sessionId,
            'role': 'assistant',
            'time': <String, dynamic>{
              'created': createdAt,
              'completed': streamMessageUpdates ? 0 : createdAt + 50,
            },
          },
          'parts': <dynamic>[
            <String, dynamic>{
              'id': 'prt_ai_working',
              'messageID': 'msg_ai_1',
              'sessionID': sessionId,
              'type': 'text',
              'text': streamMessageUpdates ? 'working' : 'done',
            },
          ],
        };

        _messagesBySession[sessionId] = <Map<String, dynamic>>[immediate];

        _messageDetails['msg_ai_1'] = <String, dynamic>{
          'info': <String, dynamic>{
            'id': 'msg_ai_1',
            'sessionID': sessionId,
            'role': 'assistant',
            'time': <String, dynamic>{
              'created': createdAt,
              'completed': createdAt + 100,
            },
          },
          'parts': <dynamic>[
            <String, dynamic>{
              'id': 'prt_ai_done',
              'messageID': 'msg_ai_1',
              'sessionID': sessionId,
              'type': 'text',
              'text': 'done',
            },
          ],
        };

        await _writeJson(request.response, 200, immediate);
        return;
      }
    }

    await _writeJson(request.response, 404, <String, dynamic>{
      'error': 'not found',
    });
  }

  Future<void> _writeJson(
    HttpResponse response,
    int statusCode,
    Object body,
  ) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }

  Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{};
  }
}
