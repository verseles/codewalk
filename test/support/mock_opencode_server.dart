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
  Map<String, dynamic>? lastSendMessagePayload;

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
  }

  Map<String, dynamic> _session(String id, {required String title}) {
    return <String, dynamic>{
      'id': id,
      'workspaceId': 'default',
      'time': <String, dynamic>{
        'created': 1739079900000,
        'updated': 1739079900000,
      },
      'title': title,
    };
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
      if (!streamMessageUpdates) {
        await _writeJson(request.response, 404, <String, dynamic>{
          'error': 'disabled',
        });
        return;
      }

      request.response.statusCode = 200;
      request.response.headers.set('content-type', 'text/event-stream');
      request.response.headers.set('cache-control', 'no-cache');
      request.response.headers.set('connection', 'keep-alive');

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
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await request.response.close();
      return;
    }

    if (segments.length == 1 && segments[0] == 'session') {
      if (method == 'GET') {
        await _writeJson(request.response, 200, _sessionsById.values.toList());
        return;
      }

      if (method == 'POST') {
        final payload = await _readJsonBody(request);
        final title = (payload['title'] as String?) ?? 'New Session';
        _sessionCounter += 1;
        final id = 'ses_$_sessionCounter';
        final created = _session(id, title: title);
        _sessionsById[id] = created;
        _messagesBySession[id] = <Map<String, dynamic>>[];
        await _writeJson(request.response, 200, created);
        return;
      }
    }

    if (segments.length == 2 && segments[0] == 'session') {
      final sessionId = segments[1];

      if (method == 'DELETE') {
        _sessionsById.remove(sessionId);
        _messagesBySession.remove(sessionId);
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
    }

    if (segments.length == 4 &&
        segments[0] == 'session' &&
        segments[2] == 'message') {
      final messageId = segments[3];

      if (method == 'GET') {
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
