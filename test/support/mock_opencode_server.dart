import 'dart:async';
import 'dart:convert';
import 'dart:io';

class MockOpenCodeServer {
  MockOpenCodeServer({this.initialSessionTitle = 'Initial Session'});

  HttpServer? _server;
  int _sessionCounter = 1;
  final String initialSessionTitle;

  bool sendMessageValidationError = false;
  bool promptAsyncSupported = true;
  bool streamMessageUpdates = false;
  bool preserveMessageHistoryOnPromptAsync = false;
  bool promptAsyncReturnsCompletePayload = false;
  int promptAsyncSeedDelayMs = 0;
  int forceEmptySessionMessageListResponses = 0;
  bool simulateBusyThenIdleOnPromptAsync = false;
  bool simulate409OnPromptAsync = false;
  bool simulateStructuredValidationError = false;
  bool legacyPermissionRouteEnabled = true;
  int sessionPermissionRouteStatusCode = 200;
  int? promptAsyncCustomErrorStatusCode;
  Map<String, dynamic>? promptAsyncCustomErrorPayload;
  int promptAsyncBusyDurationMs = 300;
  String? requiredEventDirectory;
  String? requiredMessageDirectory;
  String? requiredProjectDirectory;
  Map<String, dynamic>? lastSendMessagePayload;
  int promptAsyncRequestCount = 0;
  int messageRequestCount = 0;
  int sessionStatusRequestCount = 0;
  int sessionMessageListRequestCount = 0;
  int messageDetailRequestCount = 0;
  String? lastSessionMessageListLimit;
  final List<int?> sessionMessageListRequestedLimits =
      <int?>[];
  Map<String, String>? lastProviderQueryParameters;
  Map<String, String>? lastAgentQueryParameters;
  Map<String, String>? lastConfigQueryParameters;
  dynamic customAgentResponsePayload;
  bool returnEmptyAgentsWhenScoped = false;
  bool failProviderWhenScoped = false;
  bool failAgentWhenScoped = false;
  bool failConfigWhenScoped = false;
  int eventConnectionCount = 0;
  int globalEventConnectionCount = 0;
  int eventCloseDelayMs = 900;
  List<Map<String, dynamic>> scriptedEvents = <Map<String, dynamic>>[];
  List<List<Map<String, dynamic>>> scriptedEventsByConnection =
      <List<Map<String, dynamic>>>[];
  List<Map<String, dynamic>> scriptedGlobalEvents = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> pendingPermissions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> pendingQuestions = <Map<String, dynamic>>[];
  String? lastPermissionReplyRequestId;
  String? lastPermissionReplySessionId;
  Map<String, dynamic>? lastPermissionReplyPayload;
  String? lastQuestionReplyRequestId;
  Map<String, dynamic>? lastQuestionReplyPayload;
  Map<String, String>? lastQuestionReplyQueryParameters;
  String? lastQuestionRejectRequestId;
  Map<String, String>? lastQuestionRejectQueryParameters;
  // ADR-023 regression tracking for /session/{id}/diff requests.
  String? lastDiffSessionId;
  String? lastDiffMessageId;
  Map<String, String>? lastDiffQueryParameters;
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
  final Map<String, Map<String, dynamic>> _projectsById =
      <String, Map<String, dynamic>>{};
  final Map<String, Map<String, dynamic>> _worktreesById =
      <String, Map<String, dynamic>>{};
  String _currentProjectId = 'proj_1';
  int _assistantMessageCounter = 0;
  String? _latestAssistantMessageId;

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
    globalEventConnectionCount = 0;
    scriptedEvents = <Map<String, dynamic>>[];
    scriptedEventsByConnection = <List<Map<String, dynamic>>>[];
    scriptedGlobalEvents = <Map<String, dynamic>>[];
    requiredEventDirectory = null;
    requiredMessageDirectory = null;
    requiredProjectDirectory = null;
    pendingPermissions = <Map<String, dynamic>>[];
    pendingQuestions = <Map<String, dynamic>>[];
    lastPermissionReplyRequestId = null;
    lastPermissionReplySessionId = null;
    lastPermissionReplyPayload = null;
    lastQuestionReplyRequestId = null;
    lastQuestionReplyPayload = null;
    lastQuestionReplyQueryParameters = null;
    lastQuestionRejectRequestId = null;
    lastQuestionRejectQueryParameters = null;
    lastDiffSessionId = null;
    lastDiffMessageId = null;
    lastDiffQueryParameters = null;
    promptAsyncSupported = true;
    preserveMessageHistoryOnPromptAsync = false;
    promptAsyncReturnsCompletePayload = false;
    promptAsyncSeedDelayMs = 0;
    forceEmptySessionMessageListResponses = 0;
    simulateBusyThenIdleOnPromptAsync = false;
    simulate409OnPromptAsync = false;
    simulateStructuredValidationError = false;
    legacyPermissionRouteEnabled = true;
    sessionPermissionRouteStatusCode = 200;
    promptAsyncCustomErrorStatusCode = null;
    promptAsyncCustomErrorPayload = null;
    promptAsyncBusyDurationMs = 300;
    promptAsyncRequestCount = 0;
    messageRequestCount = 0;
    sessionStatusRequestCount = 0;
    sessionMessageListRequestCount = 0;
    messageDetailRequestCount = 0;
    lastSessionMessageListLimit = null;
    sessionMessageListRequestedLimits.clear();
    lastProviderQueryParameters = null;
    lastAgentQueryParameters = null;
    lastConfigQueryParameters = null;
    customAgentResponsePayload = null;
    returnEmptyAgentsWhenScoped = false;
    failProviderWhenScoped = false;
    failAgentWhenScoped = false;
    failConfigWhenScoped = false;
    _assistantMessageCounter = 0;
    _latestAssistantMessageId = null;
    sessionStatusById = <String, Map<String, dynamic>>{
      'ses_1': <String, dynamic>{'type': 'idle'},
    };
    sessionTodoById
      ..clear()
      ..['ses_1'] = <Map<String, dynamic>>[];
    sessionDiffById
      ..clear()
      ..['ses_1'] = <Map<String, dynamic>>[];

    _projectsById
      ..clear()
      ..['proj_1'] = _project('proj_1', 'Project One', '/workspace/project')
      ..['proj_2'] = _project('proj_2', 'Project Two', '/workspace/alt');
    _currentProjectId = 'proj_1';

    _worktreesById
      ..clear()
      ..['wt_1'] = _worktree(
        id: 'wt_1',
        name: 'default',
        directory: '/workspace/project',
        projectId: 'proj_1',
        active: true,
      )
      ..['wt_2'] = _worktree(
        id: 'wt_2',
        name: 'alt',
        directory: '/workspace/alt',
        projectId: 'proj_2',
      );
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
      'parentID': ?parentId,
      'time': <String, dynamic>{
        'created': 1739079900000,
        'updated': 1739079900000,
        'archived': ?archivedAt,
      },
      'title': title,
      if (shareUrl != null) 'share': <String, dynamic>{'url': shareUrl},
    };
    return map;
  }

  Map<String, dynamic> _project(String id, String name, String path) {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'path': path,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _worktree({
    required String id,
    required String name,
    required String directory,
    required String projectId,
    bool active = false,
  }) {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'directory': directory,
      'projectID': projectId,
      'active': active,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  void _seedAssistantMessageForSession(String sessionId) {
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    _assistantMessageCounter += 1;
    final messageId = 'msg_ai_$_assistantMessageCounter';
    final immediate = <String, dynamic>{
      'info': <String, dynamic>{
        'id': messageId,
        'sessionID': sessionId,
        'role': 'assistant',
        'time': <String, dynamic>{
          'created': createdAt,
          'completed': streamMessageUpdates ? 0 : createdAt + 50,
        },
      },
      'parts': <dynamic>[
        <String, dynamic>{
          'id': 'prt_${messageId}_working',
          'messageID': messageId,
          'sessionID': sessionId,
          'type': 'text',
          'text': streamMessageUpdates ? 'working' : 'done',
        },
      ],
    };

    final previousMessages =
        _messagesBySession[sessionId] ?? <Map<String, dynamic>>[];
    _messagesBySession[sessionId] = preserveMessageHistoryOnPromptAsync
        ? <Map<String, dynamic>>[...previousMessages, immediate]
        : <Map<String, dynamic>>[immediate];
    _messageDetails[messageId] = <String, dynamic>{
      'info': <String, dynamic>{
        'id': messageId,
        'sessionID': sessionId,
        'role': 'assistant',
        'time': <String, dynamic>{
          'created': createdAt,
          'completed': createdAt + 100,
        },
      },
      'parts': <dynamic>[
        <String, dynamic>{
          'id': 'prt_${messageId}_done',
          'messageID': messageId,
          'sessionID': sessionId,
          'type': 'text',
          'text': 'done',
        },
      ],
    };
    _latestAssistantMessageId = messageId;
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
      lastProviderQueryParameters = request.uri.queryParameters;
      if (failProviderWhenScoped && request.uri.queryParameters.isNotEmpty) {
        await _writeJson(request.response, 500, <String, dynamic>{
          'error': 'scoped provider query failed',
        });
        return;
      }
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

    if (method == 'GET' && request.uri.path == '/agent') {
      lastAgentQueryParameters = request.uri.queryParameters;
      if (failAgentWhenScoped && request.uri.queryParameters.isNotEmpty) {
        await _writeJson(request.response, 500, <String, dynamic>{
          'error': 'scoped agent query failed',
        });
        return;
      }
      if (customAgentResponsePayload != null) {
        await _writeJson(request.response, 200, customAgentResponsePayload);
        return;
      }
      if (returnEmptyAgentsWhenScoped &&
          request.uri.queryParameters.isNotEmpty) {
        await _writeJson(request.response, 200, const <Map<String, dynamic>>[]);
        return;
      }
      await _writeJson(request.response, 200, <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'build',
          'mode': 'primary',
          'hidden': false,
          'native': false,
        },
        <String, dynamic>{
          'name': 'plan',
          'mode': 'primary',
          'hidden': false,
          'native': false,
        },
        <String, dynamic>{
          'name': 'internal-tool',
          'mode': 'subagent',
          'hidden': false,
          'native': true,
        },
        <String, dynamic>{
          'name': 'hidden-helper',
          'mode': 'primary',
          'hidden': true,
          'native': false,
        },
      ]);
      return;
    }

    if (method == 'GET' && request.uri.path == '/config') {
      lastConfigQueryParameters = request.uri.queryParameters;
      if (failConfigWhenScoped && request.uri.queryParameters.isNotEmpty) {
        await _writeJson(request.response, 500, <String, dynamic>{
          'error': 'scoped config query failed',
        });
        return;
      }
      await _writeJson(request.response, 200, <String, dynamic>{
        'model': 'mock-provider/mock-model',
        'default_agent': 'build',
      });
      return;
    }

    if (method == 'GET' && request.uri.path == '/global/event') {
      globalEventConnectionCount += 1;
      request.response.statusCode = 200;
      request.response.headers.set('content-type', 'text/event-stream');
      request.response.headers.set('cache-control', 'no-cache');
      request.response.headers.set('connection', 'keep-alive');

      for (final event in scriptedGlobalEvents) {
        request.response.write('data: ${jsonEncode(event)}\n\n');
        await request.response.flush();
      }

      await Future<void>.delayed(Duration(milliseconds: eventCloseDelayMs));
      await request.response.close();
      return;
    }

    if (method == 'GET' && request.uri.path == '/project') {
      final directory = request.uri.queryParameters['directory'];
      if (directory != null && directory.trim().isNotEmpty) {
        final filtered = _projectsById.values
            .where((project) => project['path'] == directory)
            .toList(growable: false);
        await _writeJson(request.response, 200, filtered);
        return;
      }
      await _writeJson(
        request.response,
        200,
        _projectsById.values.toList(growable: false),
      );
      return;
    }

    if (method == 'GET' && request.uri.path == '/project/current') {
      final directory = request.uri.queryParameters['directory'];
      if (requiredProjectDirectory != null &&
          directory != requiredProjectDirectory) {
        await _writeJson(request.response, 404, <String, dynamic>{
          'error': 'project directory mismatch',
        });
        return;
      }

      if (directory != null && directory.trim().isNotEmpty) {
        final byDirectory = _projectsById.values
            .where((project) => project['path'] == directory)
            .firstOrNull;
        if (byDirectory != null) {
          await _writeJson(request.response, 200, byDirectory);
          return;
        }
      }

      final current =
          _projectsById[_currentProjectId] ?? _projectsById.values.first;
      await _writeJson(request.response, 200, current);
      return;
    }

    if (method == 'GET' && request.uri.path == '/find/file') {
      final query = (request.uri.queryParameters['query'] ?? '')
          .trim()
          .toLowerCase();
      final type = request.uri.queryParameters['type']?.trim().toLowerCase();
      final directory = request.uri.queryParameters['directory']?.trim();
      final limit =
          int.tryParse(request.uri.queryParameters['limit'] ?? '') ?? 50;
      final entries = <Map<String, dynamic>>[
        <String, dynamic>{
          'path': '/workspace/project',
          'name': 'project',
          'type': 'directory',
        },
        <String, dynamic>{
          'path': '/workspace/project/lib',
          'name': 'lib',
          'type': 'directory',
        },
        <String, dynamic>{
          'path': '/workspace/project/lib/src',
          'name': 'src',
          'type': 'directory',
        },
        <String, dynamic>{
          'path': '/workspace/alt',
          'name': 'alt',
          'type': 'directory',
        },
        <String, dynamic>{
          'path': '/workspace/project/README.md',
          'name': 'README.md',
          'type': 'file',
        },
      ];
      final filtered = entries
          .where((item) {
            final path = (item['path'] as String).toLowerCase();
            final name = (item['name'] as String).toLowerCase();
            final itemType = (item['type'] as String).toLowerCase();
            if (directory != null &&
                directory.isNotEmpty &&
                !path.startsWith(directory.toLowerCase())) {
              return false;
            }
            if (type != null && type.isNotEmpty && itemType != type) {
              return false;
            }
            if (query.isEmpty) {
              return true;
            }
            return path.contains(query) || name.contains(query);
          })
          .take(limit)
          .toList(growable: false);
      await _writeJson(request.response, 200, filtered);
      return;
    }

    if (method == 'GET' && request.uri.path == '/find') {
      final pattern = (request.uri.queryParameters['pattern'] ?? '')
          .trim()
          .toLowerCase();
      final limit =
          int.tryParse(request.uri.queryParameters['limit'] ?? '') ?? 50;
      final matches = <Map<String, dynamic>>[
        <String, dynamic>{
          'path': '/workspace/project/README.md',
          'lines': <String>['CodeWalk quick open content search'],
          'line_number': 12,
          'absolute_offset': 120,
          'submatches': <Map<String, dynamic>>[
            <String, dynamic>{
              'match': <String, dynamic>{'text': 'content'},
            },
          ],
        },
      ];
      final filtered = matches
          .where((item) {
            final lines = (item['lines'] as List).join('\n').toLowerCase();
            return pattern.isEmpty || lines.contains(pattern);
          })
          .take(limit)
          .toList(growable: false);
      await _writeJson(request.response, 200, filtered);
      return;
    }

    if (method == 'GET' && request.uri.path == '/find/symbol') {
      final query = (request.uri.queryParameters['query'] ?? '')
          .trim()
          .toLowerCase();
      final limit =
          int.tryParse(request.uri.queryParameters['limit'] ?? '') ?? 10;
      final symbols = <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'CodeWalkController',
          'kind': 'class',
          'location': <String, dynamic>{
            'uri': 'file:///workspace/project/lib/codewalk_controller.dart',
          },
        },
      ];
      final filtered = symbols
          .where((item) {
            final name = (item['name'] as String).toLowerCase();
            return query.isEmpty || name.contains(query);
          })
          .take(limit)
          .toList(growable: false);
      await _writeJson(request.response, 200, filtered);
      return;
    }

    if (method == 'PATCH' && segments.length == 2 && segments[0] == 'project') {
      final projectId = segments[1];
      final project = _projectsById[projectId];
      if (project == null) {
        await _writeJson(request.response, 404, <String, dynamic>{
          'error': 'not found',
        });
        return;
      }
      _currentProjectId = projectId;
      await _writeJson(request.response, 200, project);
      return;
    }

    if (segments.length == 2 &&
        segments[0] == 'experimental' &&
        segments[1] == 'worktree') {
      if (method == 'GET') {
        final directory = request.uri.queryParameters['directory'];
        var items = _worktreesById.values.toList(growable: false);
        if (directory != null && directory.trim().isNotEmpty) {
          items = items
              .where(
                (item) => (item['directory'] as String).startsWith(directory),
              )
              .toList(growable: false);
        }
        await _writeJson(request.response, 200, items);
        return;
      }

      if (method == 'POST') {
        final payload = await _readJsonBody(request);
        final rawName = (payload['name'] as String?)?.trim();
        if (rawName == null || rawName.isEmpty) {
          await _writeJson(request.response, 400, <String, dynamic>{
            'error': 'name required',
          });
          return;
        }
        final baseDirectory =
            request.uri.queryParameters['directory'] ?? '/workspace/project';
        final slug = rawName.toLowerCase().replaceAll(' ', '-');
        final directory = '$baseDirectory/$slug';
        final id = 'wt_${_worktreesById.length + 1}';
        final projectId = 'proj_${_projectsById.length + 1}';
        final created = _worktree(
          id: id,
          name: rawName,
          directory: directory,
          projectId: projectId,
        );
        _worktreesById[id] = created;
        _projectsById[projectId] = _project(projectId, rawName, directory);
        await _writeJson(request.response, 200, created);
        return;
      }

      if (method == 'DELETE') {
        final worktreeId = request.uri.queryParameters['id'];
        if (worktreeId == null || worktreeId.isEmpty) {
          await _writeJson(request.response, 400, <String, dynamic>{
            'error': 'id required',
          });
          return;
        }
        final removed = _worktreesById.remove(worktreeId);
        if (removed == null) {
          await _writeJson(request.response, 404, <String, dynamic>{
            'error': 'not found',
          });
          return;
        }
        final removedDirectory = removed['directory'] as String?;
        if (removedDirectory != null) {
          final projectEntry = _projectsById.entries
              .where((entry) => entry.value['path'] == removedDirectory)
              .firstOrNull;
          if (projectEntry != null) {
            _projectsById.remove(projectEntry.key);
          }
        }
        await _writeJson(request.response, 200, <String, dynamic>{'ok': true});
        return;
      }
    }

    if (segments.length == 3 &&
        segments[0] == 'experimental' &&
        segments[1] == 'worktree' &&
        segments[2] == 'reset' &&
        method == 'POST') {
      final payload = await _readJsonBody(request);
      final worktreeId = payload['id'] as String?;
      if (worktreeId == null || !_worktreesById.containsKey(worktreeId)) {
        await _writeJson(request.response, 404, <String, dynamic>{
          'error': 'not found',
        });
        return;
      }
      await _writeJson(request.response, 200, <String, dynamic>{'ok': true});
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
        while ((_latestAssistantMessageId == null ||
                !_messageDetails.containsKey(_latestAssistantMessageId)) &&
            waitCycles < 60) {
          waitCycles += 1;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }

        final messageId = _latestAssistantMessageId;
        if (messageId != null) {
          final event = <String, dynamic>{
            'type': 'message.updated',
            'properties': <String, dynamic>{
              'info': <String, dynamic>{'id': messageId, 'sessionID': 'ses_1'},
            },
          };
          request.response.write('data: ${jsonEncode(event)}\n\n');
          await request.response.flush();
        }
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
        if (!legacyPermissionRouteEnabled) {
          await _writeJson(request.response, 404, <String, dynamic>{
            'error': 'Not found',
          });
          return;
        }
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

    if (segments.length == 4 &&
        segments[0] == 'session' &&
        segments[2] == 'permissions') {
      if (method == 'POST') {
        final sessionId = segments[1];
        final requestId = segments[3];
        if (sessionPermissionRouteStatusCode != 200) {
          await _writeJson(
            request.response,
            sessionPermissionRouteStatusCode,
            <String, dynamic>{'error': 'session permission route unavailable'},
          );
          return;
        }
        lastPermissionReplyRequestId = requestId;
        lastPermissionReplySessionId = sessionId;
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
      sessionStatusRequestCount += 1;
      await _writeJson(request.response, 200, sessionStatusById);
      return;
    }

    if (segments.length == 3 &&
        segments[0] == 'question' &&
        segments[2] == 'reply') {
      if (method == 'POST') {
        final requestId = segments[1];
        // The official OpenCode question endpoints accept only
        // WorkspaceRoutingQuery fields (directory, workspace).
        // Reject undocumented sessionID to enforce contract compliance.
        if (request.uri.queryParameters.containsKey('sessionID')) {
          await _writeJson(
            request.response,
            400,
            <String, dynamic>{
              'error': 'undocumented parameter: sessionID',
            },
          );
          return;
        }
        lastQuestionReplyRequestId = requestId;
        lastQuestionReplyQueryParameters = request.uri.queryParameters;
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
        // The official OpenCode question endpoints accept only
        // WorkspaceRoutingQuery fields (directory, workspace).
        // Reject undocumented sessionID to enforce contract compliance.
        if (request.uri.queryParameters.containsKey('sessionID')) {
          await _writeJson(
            request.response,
            400,
            <String, dynamic>{
              'error': 'undocumented parameter: sessionID',
            },
          );
          return;
        }
        lastQuestionRejectRequestId = requestId;
        lastQuestionRejectQueryParameters = request.uri.queryParameters;
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
                    ((session['time'] as Map<String, dynamic>)['updated']
                        as int) >=
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
      final queryParameters = request.uri.queryParameters;
      lastDiffSessionId = sessionId;
      lastDiffMessageId = queryParameters['messageID']?.trim();
      lastDiffQueryParameters = queryParameters;
      final stored = sessionDiffById[sessionId] ?? const <Map<String, dynamic>>[];
      final hasAnyMessageId = stored.any(
        (item) =>
            item is Map &&
            (item['messageID']?.toString().trim().isNotEmpty ?? false),
      );
      final requestedMessageId = queryParameters['messageID']?.trim();
      // Two behaviors:
      //  - When the test seeds per-messageID entries and passes a messageID
      //    query, the mock filters so ADR-023 regression tests can verify
      //    the user-initiated exhaustive scan.
      //  - Otherwise (unscoped request, or test seed without messageID) the
      //    mock returns the stored entries unchanged to preserve existing
      //    contract checks against the datasource layer.
      if (requestedMessageId == null ||
          requestedMessageId.isEmpty ||
          !hasAnyMessageId) {
        await _writeJson(request.response, 200, stored);
        return;
      }
      final filtered = stored
          .whereType<Map<String, dynamic>>()
          .where((item) {
            final candidate = item['messageID']?.toString().trim();
            return candidate == requestedMessageId;
          })
          .toList(growable: false);
      await _writeJson(request.response, 200, filtered);
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

    if (segments.length == 3 &&
        segments[0] == 'session' &&
        segments[2] == 'prompt_async' &&
        method == 'POST') {
      final sessionId = segments[1];
      promptAsyncRequestCount += 1;
      final payload = await _readJsonBody(request);
      lastSendMessagePayload = payload;

      if (!promptAsyncSupported) {
        await _writeJson(request.response, 404, <String, dynamic>{
          'error': 'prompt_async unsupported',
        });
        return;
      }

      if (sendMessageValidationError) {
        if (simulateStructuredValidationError) {
          await _writeJson(request.response, 400, <String, dynamic>{
            'type': 'ErrorResponse',
            'error': <String, dynamic>{
              'code': 'VALIDATION_ERROR',
              'message': 'Validation failed',
              'errors': <dynamic>[
                <String, dynamic>{
                  'field': 'messageId',
                  'message': 'Cannot be empty',
                },
              ],
            },
          });
        } else {
          await _writeJson(request.response, 400, <String, dynamic>{
            'error': 'invalid',
          });
        }
        return;
      }

      if (simulate409OnPromptAsync) {
        await _writeJson(request.response, 409, <String, dynamic>{
          'error': 'Session is busy processing another request.',
        });
        return;
      }

      if (promptAsyncCustomErrorStatusCode != null &&
          promptAsyncCustomErrorPayload != null) {
        await _writeJson(
          request.response,
          promptAsyncCustomErrorStatusCode!,
          promptAsyncCustomErrorPayload!,
        );
        return;
      }

      if (simulateBusyThenIdleOnPromptAsync) {
        sessionStatusById[sessionId] = <String, dynamic>{'type': 'busy'};
        unawaited(
          Future<void>.delayed(
            Duration(milliseconds: promptAsyncBusyDurationMs),
            () {
              sessionStatusById[sessionId] = <String, dynamic>{'type': 'idle'};
            },
          ),
        );
      }

      if (promptAsyncSeedDelayMs > 0) {
        unawaited(
          Future<void>.delayed(
            Duration(milliseconds: promptAsyncSeedDelayMs),
            () => _seedAssistantMessageForSession(sessionId),
          ),
        );
      } else {
        _seedAssistantMessageForSession(sessionId);
      }
      if (promptAsyncReturnsCompletePayload) {
        final messageId = _latestAssistantMessageId;
        final payload = messageId == null ? null : _messageDetails[messageId];
        if (payload != null) {
          await _writeJson(request.response, 200, payload);
          return;
        }
      }
      request.response.statusCode = 204;
      await request.response.close();
      return;
    }

    if (segments.length == 4 &&
        segments[0] == 'session' &&
        segments[2] == 'message') {
      final messageId = segments[3];

      if (method == 'GET') {
        messageDetailRequestCount += 1;
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
        sessionMessageListRequestCount += 1;
        final requestedLimit = int.tryParse(
          request.uri.queryParameters['limit'] ?? '',
        );
        sessionMessageListRequestedLimits.add(requestedLimit);
        lastSessionMessageListLimit = request.uri.queryParameters['limit'];
        if (forceEmptySessionMessageListResponses > 0) {
          forceEmptySessionMessageListResponses -= 1;
          await _writeJson(
            request.response,
            200,
            const <Map<String, dynamic>>[],
          );
          return;
        }
        // Official OpenCode contract: an optional `limit` returns the most
        // recent tail of the session's messages (issue #160).
        var payload =
            _messagesBySession[sessionId] ?? <Map<String, dynamic>>[];
        if (requestedLimit != null &&
            requestedLimit > 0 &&
            payload.length > requestedLimit) {
          payload = payload.sublist(payload.length - requestedLimit);
        }
        await _writeJson(request.response, 200, payload);
        return;
      }

      if (method == 'POST') {
        messageRequestCount += 1;
        final payload = await _readJsonBody(request);
        lastSendMessagePayload = payload;

        if (sendMessageValidationError) {
          await _writeJson(request.response, 400, <String, dynamic>{
            'error': 'invalid',
          });
          return;
        }

        _seedAssistantMessageForSession(sessionId);
        final immediate =
            _messagesBySession[sessionId]?.last ?? <String, dynamic>{};
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
