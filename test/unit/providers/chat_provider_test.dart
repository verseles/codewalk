import 'dart:async';
import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/data/models/chat_message_model.dart';
import 'package:codewalk/data/models/chat_session_model.dart';
import 'package:codewalk/domain/entities/agent.dart';
import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/domain/entities/project.dart';
import 'package:codewalk/domain/entities/provider.dart';
import 'package:codewalk/domain/usecases/create_chat_session.dart';
import 'package:codewalk/domain/usecases/delete_chat_session.dart';
import 'package:codewalk/domain/usecases/fork_chat_session.dart';
import 'package:codewalk/domain/usecases/abort_chat_session.dart';
import 'package:codewalk/domain/usecases/get_chat_message.dart';
import 'package:codewalk/domain/usecases/get_chat_messages.dart';
import 'package:codewalk/domain/usecases/get_agents.dart';
import 'package:codewalk/domain/usecases/get_chat_sessions.dart';
import 'package:codewalk/domain/usecases/get_providers.dart';
import 'package:codewalk/domain/usecases/get_session_children.dart';
import 'package:codewalk/domain/usecases/get_session_diff.dart';
import 'package:codewalk/domain/usecases/get_session_status.dart';
import 'package:codewalk/domain/usecases/get_session_todo.dart';
import 'package:codewalk/domain/usecases/list_pending_permissions.dart';
import 'package:codewalk/domain/usecases/list_pending_questions.dart';
import 'package:codewalk/domain/usecases/reject_question.dart';
import 'package:codewalk/domain/usecases/reply_permission.dart';
import 'package:codewalk/domain/usecases/reply_question.dart';
import 'package:codewalk/domain/usecases/send_chat_message.dart';
import 'package:codewalk/domain/usecases/share_chat_session.dart';
import 'package:codewalk/domain/usecases/unshare_chat_session.dart';
import 'package:codewalk/domain/usecases/update_chat_session.dart';
import 'package:codewalk/domain/usecases/watch_chat_events.dart';
import 'package:codewalk/domain/usecases/watch_global_chat_events.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/providers/project_provider.dart';
import 'package:codewalk/presentation/services/chat_title_generator.dart';

import '../../support/fakes.dart';

class _RecordingDioClient extends DioClient {
  _RecordingDioClient({Map<String, dynamic>? configResponse})
    : _configResponse = configResponse ?? <String, dynamic>{},
      super(baseUrl: 'http://localhost');

  final Map<String, dynamic> _configResponse;
  final List<Map<String, dynamic>?> getQueries = <Map<String, dynamic>?>[];
  final List<Map<String, dynamic>?> patchQueries = <Map<String, dynamic>?>[];
  final List<dynamic> patchBodies = <dynamic>[];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (path == '/config') {
      getQueries.add(queryParameters);
      return Response<T>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: _configResponse as T,
      );
    }
    throw UnimplementedError('Unexpected GET path in test: $path');
  }

  @override
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (path == '/config') {
      patchQueries.add(queryParameters);
      patchBodies.add(data);
      return Response<T>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: _configResponse as T,
      );
    }
    throw UnimplementedError('Unexpected PATCH path in test: $path');
  }
}

void main() {
  group('ChatProvider', () {
    late FakeChatRepository chatRepository;
    late FakeAppRepository appRepository;
    late InMemoryAppLocalDataSource localDataSource;
    late ChatProvider provider;

    ChatProvider buildProvider({
      DioClient? dioClient,
      Duration syncHealthCheckInterval = const Duration(seconds: 5),
    }) {
      return ChatProvider(
        sendChatMessage: SendChatMessage(chatRepository),
        abortChatSession: AbortChatSession(chatRepository),
        getChatSessions: GetChatSessions(chatRepository),
        createChatSession: CreateChatSession(chatRepository),
        getChatMessages: GetChatMessages(chatRepository),
        getChatMessage: GetChatMessage(chatRepository),
        getAgents: GetAgents(appRepository),
        getProviders: GetProviders(appRepository),
        deleteChatSession: DeleteChatSession(chatRepository),
        updateChatSession: UpdateChatSession(chatRepository),
        shareChatSession: ShareChatSession(chatRepository),
        unshareChatSession: UnshareChatSession(chatRepository),
        forkChatSession: ForkChatSession(chatRepository),
        getSessionStatus: GetSessionStatus(chatRepository),
        getSessionChildren: GetSessionChildren(chatRepository),
        getSessionTodo: GetSessionTodo(chatRepository),
        getSessionDiff: GetSessionDiff(chatRepository),
        watchChatEvents: WatchChatEvents(chatRepository),
        watchGlobalChatEvents: WatchGlobalChatEvents(chatRepository),
        listPendingPermissions: ListPendingPermissions(chatRepository),
        replyPermission: ReplyPermission(chatRepository),
        listPendingQuestions: ListPendingQuestions(chatRepository),
        replyQuestion: ReplyQuestion(chatRepository),
        rejectQuestion: RejectQuestion(chatRepository),
        projectProvider: ProjectProvider(
          projectRepository: FakeProjectRepository(),
          localDataSource: localDataSource,
        ),
        localDataSource: localDataSource,
        dioClient: dioClient,
        syncHealthCheckInterval: syncHealthCheckInterval,
      );
    }

    setUp(() {
      chatRepository = FakeChatRepository(
        sessions: <ChatSession>[
          ChatSession(
            id: 'ses_1',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            title: 'Session 1',
          ),
        ],
      );
      appRepository = FakeAppRepository();
      localDataSource = InMemoryAppLocalDataSource();
      localDataSource.activeServerId = 'srv_test';

      provider = buildProvider();
    });

    test(
      'initializeProviders chooses first connected provider and default model',
      () async {
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
              Provider(
                id: 'provider_b',
                name: 'Provider B',
                env: const <String>[],
                models: <String, Model>{'model_b': _model('model_b')},
              ),
            ],
            defaultModels: const <String, String>{'provider_b': 'model_b'},
            connected: const <String>['provider_b'],
          ),
        );

        await provider.initializeProviders();

        expect(provider.providers, hasLength(2));
        expect(provider.selectedProviderId, 'provider_b');
        expect(provider.selectedModelId, 'model_b');
      },
    );

    test(
      'initializeProviders prioritizes server config model over local persisted selection',
      () async {
        await localDataSource.saveSelectedProvider(
          'provider_a',
          serverId: 'srv_test',
          scopeId: 'default',
        );
        await localDataSource.saveSelectedModel(
          'model_a',
          serverId: 'srv_test',
          scopeId: 'default',
        );

        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
              Provider(
                id: 'provider_b',
                name: 'Provider B',
                env: const <String>[],
                models: <String, Model>{'model_b': _model('model_b')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a'],
          ),
        );

        final dioClient = _RecordingDioClient(
          configResponse: <String, dynamic>{'model': 'provider_b/model_b'},
        );
        provider = buildProvider(dioClient: dioClient);

        await provider.initializeProviders();

        expect(provider.selectedProviderId, 'provider_b');
        expect(provider.selectedModelId, 'model_b');
      },
    );

    test(
      'setSelectedModelByProvider syncs model selection to server config',
      () async {
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
              Provider(
                id: 'provider_b',
                name: 'Provider B',
                env: const <String>[],
                models: <String, Model>{'model_b': _model('model_b')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a'],
          ),
        );

        final dioClient = _RecordingDioClient(
          configResponse: <String, dynamic>{'model': 'provider_a/model_a'},
        );
        provider = buildProvider(dioClient: dioClient);

        await provider.initializeProviders();
        dioClient.patchBodies.clear();

        await provider.setSelectedModelByProvider(
          providerId: 'provider_b',
          modelId: 'model_b',
        );

        final hasModelPatch = dioClient.patchBodies.whereType<Map>().any(
          (body) => body['model'] == 'provider_b/model_b',
        );
        expect(hasModelPatch, isTrue);
      },
    );

    test(
      'initializeProviders prioritizes server default_agent over local persisted agent',
      () async {
        await localDataSource.saveSelectedAgent(
          'plan',
          serverId: 'srv_test',
          scopeId: 'default',
        );

        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a'],
          ),
        );
        appRepository.agentsResult = const Right(<Agent>[
          Agent(name: 'build', mode: 'primary', hidden: false, native: false),
          Agent(name: 'plan', mode: 'primary', hidden: false, native: false),
        ]);

        final dioClient = _RecordingDioClient(
          configResponse: <String, dynamic>{
            'model': 'provider_a/model_a',
            'default_agent': 'build',
          },
        );
        provider = buildProvider(dioClient: dioClient);

        await provider.initializeProviders();

        expect(provider.selectedAgentName, 'build');
      },
    );

    test('setSelectedAgent syncs agent selection to server config', () async {
      appRepository.providersResult = Right(
        ProvidersResponse(
          providers: <Provider>[
            Provider(
              id: 'provider_a',
              name: 'Provider A',
              env: const <String>[],
              models: <String, Model>{'model_a': _model('model_a')},
            ),
          ],
          defaultModels: const <String, String>{'provider_a': 'model_a'},
          connected: const <String>['provider_a'],
        ),
      );
      appRepository.agentsResult = const Right(<Agent>[
        Agent(name: 'build', mode: 'primary', hidden: false, native: false),
        Agent(name: 'plan', mode: 'primary', hidden: false, native: false),
      ]);

      final dioClient = _RecordingDioClient(
        configResponse: <String, dynamic>{
          'model': 'provider_a/model_a',
          'default_agent': 'build',
        },
      );
      provider = buildProvider(dioClient: dioClient);

      await provider.initializeProviders();
      dioClient.patchBodies.clear();

      await provider.setSelectedAgent('plan');

      final hasAgentPatch = dioClient.patchBodies.whereType<Map>().any(
        (body) => body['default_agent'] == 'plan',
      );
      expect(hasAgentPatch, isTrue);
    });

    test(
      'initializeProviders prioritizes remote variant map over local variant map',
      () async {
        await localDataSource.saveSelectedVariantMap(
          json.encode(<String, String>{'provider_a/model_reasoning': 'low'}),
          serverId: 'srv_test',
          scopeId: 'default',
        );

        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{
                  'model_reasoning': _model(
                    'model_reasoning',
                    variants: const <String, ModelVariant>{
                      'low': ModelVariant(id: 'low', name: 'Low'),
                      'high': ModelVariant(id: 'high', name: 'High'),
                    },
                  ),
                },
              ),
            ],
            defaultModels: const <String, String>{
              'provider_a': 'model_reasoning',
            },
            connected: const <String>['provider_a'],
          ),
        );
        appRepository.agentsResult = const Right(<Agent>[
          Agent(name: 'build', mode: 'primary', hidden: false, native: false),
          Agent(name: 'plan', mode: 'primary', hidden: false, native: false),
        ]);

        final dioClient = _RecordingDioClient(
          configResponse: <String, dynamic>{
            'model': 'provider_a/model_reasoning',
            'default_agent': 'build',
            'agent': <String, dynamic>{
              'build': <String, dynamic>{
                'options': <String, dynamic>{
                  'codewalk': <String, dynamic>{
                    'variantByModel': <String, String>{
                      'provider_a/model_reasoning': 'high',
                    },
                  },
                },
              },
            },
          },
        );
        provider = buildProvider(dioClient: dioClient);

        await provider.initializeProviders();

        expect(provider.selectedVariantId, 'high');
      },
    );

    test(
      'initializeProviders resolves remote variant value case-insensitively',
      () async {
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{
                  'model_reasoning': _model(
                    'model_reasoning',
                    variants: const <String, ModelVariant>{
                      'low': ModelVariant(id: 'low', name: 'Low'),
                      'high': ModelVariant(id: 'high', name: 'High'),
                    },
                  ),
                },
              ),
            ],
            defaultModels: const <String, String>{
              'provider_a': 'model_reasoning',
            },
            connected: const <String>['provider_a'],
          ),
        );
        appRepository.agentsResult = const Right(<Agent>[
          Agent(name: 'build', mode: 'primary', hidden: false, native: false),
        ]);

        final dioClient = _RecordingDioClient(
          configResponse: <String, dynamic>{
            'model': 'provider_a/model_reasoning',
            'default_agent': 'build',
            'agent': <String, dynamic>{
              'build': <String, dynamic>{
                'options': <String, dynamic>{
                  'codewalk': <String, dynamic>{
                    'variantByModel': <String, String>{
                      'provider_a/model_reasoning': 'HIGH',
                    },
                  },
                },
              },
            },
          },
        );
        provider = buildProvider(dioClient: dioClient);

        await provider.initializeProviders();

        expect(provider.selectedVariantId, 'high');
      },
    );

    test(
      'initializeProviders ignores remote variant display names and expects canonical id',
      () async {
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{
                  'model_reasoning': _model(
                    'model_reasoning',
                    variants: const <String, ModelVariant>{
                      'reasoning_low': ModelVariant(
                        id: 'reasoning_low',
                        name: 'Low',
                      ),
                      'reasoning_high': ModelVariant(
                        id: 'reasoning_high',
                        name: 'High',
                      ),
                    },
                  ),
                },
              ),
            ],
            defaultModels: const <String, String>{
              'provider_a': 'model_reasoning',
            },
            connected: const <String>['provider_a'],
          ),
        );
        appRepository.agentsResult = const Right(<Agent>[
          Agent(name: 'build', mode: 'primary', hidden: false, native: false),
        ]);

        final dioClient = _RecordingDioClient(
          configResponse: <String, dynamic>{
            'model': 'provider_a/model_reasoning',
            'default_agent': 'build',
            'agent': <String, dynamic>{
              'build': <String, dynamic>{
                'options': <String, dynamic>{
                  'codewalk': <String, dynamic>{
                    'variantByModel': <String, String>{
                      'provider_a/model_reasoning': 'High',
                    },
                  },
                },
              },
            },
          },
        );
        provider = buildProvider(dioClient: dioClient);

        await provider.initializeProviders();

        expect(provider.selectedVariantId, isNull);
      },
    );

    test('setSelectedVariant syncs variant map to server config', () async {
      appRepository.providersResult = Right(
        ProvidersResponse(
          providers: <Provider>[
            Provider(
              id: 'provider_a',
              name: 'Provider A',
              env: const <String>[],
              models: <String, Model>{
                'model_reasoning': _model(
                  'model_reasoning',
                  variants: const <String, ModelVariant>{
                    'low': ModelVariant(id: 'low', name: 'Low'),
                    'high': ModelVariant(id: 'high', name: 'High'),
                  },
                ),
              },
            ),
          ],
          defaultModels: const <String, String>{
            'provider_a': 'model_reasoning',
          },
          connected: const <String>['provider_a'],
        ),
      );
      appRepository.agentsResult = const Right(<Agent>[
        Agent(name: 'build', mode: 'primary', hidden: false, native: false),
      ]);

      final dioClient = _RecordingDioClient(
        configResponse: <String, dynamic>{
          'model': 'provider_a/model_reasoning',
          'default_agent': 'build',
        },
      );
      provider = buildProvider(dioClient: dioClient);

      await provider.initializeProviders();
      dioClient.patchBodies.clear();

      await provider.setSelectedVariant('high');

      final variantPatch = dioClient.patchBodies
          .whereType<Map<String, dynamic>>()
          .where((body) => body.containsKey('agent'))
          .cast<Map<String, dynamic>>()
          .first;
      final agentMap =
          (variantPatch['agent'] as Map<String, dynamic>)['build']
              as Map<String, dynamic>;
      final options = agentMap['options'] as Map<String, dynamic>;
      final codewalk = options['codewalk'] as Map<String, dynamic>;
      final variantByModel = codewalk['variantByModel'] as Map<String, dynamic>;

      expect(variantByModel['provider_a/model_reasoning'], 'high');
    });

    test(
      'deferred variant sync flushes on health tick when local work is idle',
      () async {
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{
                  'model_reasoning': _model(
                    'model_reasoning',
                    variants: const <String, ModelVariant>{
                      'low': ModelVariant(id: 'low', name: 'Low'),
                      'high': ModelVariant(id: 'high', name: 'High'),
                    },
                  ),
                },
              ),
            ],
            defaultModels: const <String, String>{
              'provider_a': 'model_reasoning',
            },
            connected: const <String>['provider_a'],
          ),
        );
        appRepository.agentsResult = const Right(<Agent>[
          Agent(name: 'build', mode: 'primary', hidden: false, native: false),
        ]);

        final dioClient = _RecordingDioClient(
          configResponse: <String, dynamic>{
            'model': 'provider_a/model_reasoning',
            'default_agent': 'build',
          },
        );
        provider = buildProvider(
          dioClient: dioClient,
          syncHealthCheckInterval: const Duration(milliseconds: 50),
        );

        await provider.initializeProviders();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        dioClient.patchBodies.clear();

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.status',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'status': <String, dynamic>{'type': 'busy'},
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        await provider.setSelectedVariant('high');

        final hasImmediateVariantPatch = dioClient.patchBodies
            .whereType<Map<String, dynamic>>()
            .any((body) {
              final agent = body['agent'];
              if (agent is! Map<String, dynamic>) {
                return false;
              }
              final build = agent['build'];
              if (build is! Map<String, dynamic>) {
                return false;
              }
              final options = build['options'];
              if (options is! Map<String, dynamic>) {
                return false;
              }
              final codewalk = options['codewalk'];
              if (codewalk is! Map<String, dynamic>) {
                return false;
              }
              final variantByModel = codewalk['variantByModel'];
              return variantByModel is Map<String, dynamic> &&
                  variantByModel['provider_a/model_reasoning'] == 'high';
            });
        expect(hasImmediateVariantPatch, isFalse);

        await Future<void>.delayed(const Duration(milliseconds: 180));

        final hasFlushedVariantPatch = dioClient.patchBodies
            .whereType<Map<String, dynamic>>()
            .any((body) {
              final agent = body['agent'];
              if (agent is! Map<String, dynamic>) {
                return false;
              }
              final build = agent['build'];
              if (build is! Map<String, dynamic>) {
                return false;
              }
              final options = build['options'];
              if (options is! Map<String, dynamic>) {
                return false;
              }
              final codewalk = options['codewalk'];
              if (codewalk is! Map<String, dynamic>) {
                return false;
              }
              final variantByModel = codewalk['variantByModel'];
              return variantByModel is Map<String, dynamic> &&
                  variantByModel['provider_a/model_reasoning'] == 'high';
            });
        expect(hasFlushedVariantPatch, isTrue);
      },
    );

    test('variant sync is not blocked after a completed send stream', () async {
      appRepository.providersResult = Right(
        ProvidersResponse(
          providers: <Provider>[
            Provider(
              id: 'provider_a',
              name: 'Provider A',
              env: const <String>[],
              models: <String, Model>{
                'model_reasoning': _model(
                  'model_reasoning',
                  variants: const <String, ModelVariant>{
                    'low': ModelVariant(id: 'low', name: 'Low'),
                    'high': ModelVariant(id: 'high', name: 'High'),
                  },
                ),
              },
            ),
          ],
          defaultModels: const <String, String>{
            'provider_a': 'model_reasoning',
          },
          connected: const <String>['provider_a'],
        ),
      );
      appRepository.agentsResult = const Right(<Agent>[
        Agent(name: 'build', mode: 'primary', hidden: false, native: false),
      ]);

      final dioClient = _RecordingDioClient(
        configResponse: <String, dynamic>{
          'model': 'provider_a/model_reasoning',
          'default_agent': 'build',
        },
      );
      provider = buildProvider(
        dioClient: dioClient,
        syncHealthCheckInterval: const Duration(milliseconds: 50),
      );

      await provider.initializeProviders();
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);

      await provider.sendMessage('first send');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      dioClient.patchBodies.clear();

      await provider.setSelectedVariant('high');
      await Future<void>.delayed(const Duration(milliseconds: 80));

      final hasVariantPatch = dioClient.patchBodies
          .whereType<Map<String, dynamic>>()
          .any((body) {
            final agent = body['agent'];
            if (agent is! Map<String, dynamic>) {
              return false;
            }
            final build = agent['build'];
            if (build is! Map<String, dynamic>) {
              return false;
            }
            final options = build['options'];
            if (options is! Map<String, dynamic>) {
              return false;
            }
            final codewalk = options['codewalk'];
            if (codewalk is! Map<String, dynamic>) {
              return false;
            }
            final variantByModel = codewalk['variantByModel'];
            return variantByModel is Map<String, dynamic> &&
                variantByModel['provider_a/model_reasoning'] == 'high';
          });
      expect(hasVariantPatch, isTrue);
    });

    test(
      'model sync is deferred while response is active and flushed on idle',
      () async {
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
              Provider(
                id: 'provider_b',
                name: 'Provider B',
                env: const <String>[],
                models: <String, Model>{'model_b': _model('model_b')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a', 'provider_b'],
          ),
        );

        final dioClient = _RecordingDioClient(
          configResponse: <String, dynamic>{'model': 'provider_a/model_a'},
        );
        provider = buildProvider(dioClient: dioClient);

        await provider.initializeProviders();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        dioClient.patchBodies.clear();

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.status',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'status': <String, dynamic>{'type': 'busy'},
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        await provider.setSelectedModelByProvider(
          providerId: 'provider_b',
          modelId: 'model_b',
        );

        final hasImmediateModelPatch = dioClient.patchBodies
            .whereType<Map>()
            .any((body) => body['model'] == 'provider_b/model_b');
        expect(hasImmediateModelPatch, isFalse);

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.status',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'status': <String, dynamic>{'type': 'idle'},
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        final hasFlushedModelPatch = dioClient.patchBodies.whereType<Map>().any(
          (body) => body['model'] == 'provider_b/model_b',
        );
        expect(hasFlushedModelPatch, isTrue);
      },
    );

    test('session selection override wins when switching sessions', () async {
      chatRepository.sessions.add(
        ChatSession(
          id: 'ses_2',
          workspaceId: 'default',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          title: 'Session 2',
        ),
      );

      appRepository.providersResult = Right(
        ProvidersResponse(
          providers: <Provider>[
            Provider(
              id: 'provider_a',
              name: 'Provider A',
              env: const <String>[],
              models: <String, Model>{'model_a': _model('model_a')},
            ),
            Provider(
              id: 'provider_b',
              name: 'Provider B',
              env: const <String>[],
              models: <String, Model>{'model_b': _model('model_b')},
            ),
          ],
          defaultModels: const <String, String>{'provider_a': 'model_a'},
          connected: const <String>['provider_a', 'provider_b'],
        ),
      );

      await provider.initializeProviders();
      await provider.loadSessions();

      final session1 = provider.sessions.firstWhere((s) => s.id == 'ses_1');
      final session2 = provider.sessions.firstWhere((s) => s.id == 'ses_2');

      await provider.selectSession(session1);
      await provider.setSelectedModelByProvider(
        providerId: 'provider_b',
        modelId: 'model_b',
      );

      await provider.selectSession(session2);
      await provider.setSelectedModelByProvider(
        providerId: 'provider_a',
        modelId: 'model_a',
      );

      await provider.selectSession(session1);

      expect(provider.selectedProviderId, 'provider_b');
      expect(provider.selectedModelId, 'model_b');
    });

    test(
      'session selection override persists across provider restart',
      () async {
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_2',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(2000),
            title: 'Session 2',
          ),
        );

        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
              Provider(
                id: 'provider_b',
                name: 'Provider B',
                env: const <String>[],
                models: <String, Model>{'model_b': _model('model_b')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a', 'provider_b'],
          ),
        );

        await provider.initializeProviders();
        await provider.loadSessions();
        final session1 = provider.sessions.firstWhere((s) => s.id == 'ses_1');
        await provider.selectSession(session1);
        await provider.setSelectedModelByProvider(
          providerId: 'provider_b',
          modelId: 'model_b',
        );

        provider = buildProvider();
        await provider.initializeProviders();
        await provider.loadSessions();
        final restoredSession = provider.sessions.firstWhere(
          (s) => s.id == 'ses_1',
        );
        await provider.selectSession(restoredSession);

        expect(provider.selectedProviderId, 'provider_b');
        expect(provider.selectedModelId, 'model_b');
      },
    );

    test(
      'setSelectedModelByProvider syncs session selection override map to server config',
      () async {
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
              Provider(
                id: 'provider_b',
                name: 'Provider B',
                env: const <String>[],
                models: <String, Model>{'model_b': _model('model_b')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a', 'provider_b'],
          ),
        );

        final dioClient = _RecordingDioClient(
          configResponse: <String, dynamic>{'model': 'provider_a/model_a'},
        );
        provider = buildProvider(dioClient: dioClient);

        await provider.initializeProviders();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        dioClient.patchBodies.clear();

        await provider.setSelectedModelByProvider(
          providerId: 'provider_b',
          modelId: 'model_b',
        );

        final overridePatch = dioClient.patchBodies
            .whereType<Map<String, dynamic>>()
            .where((body) {
              final agent = body['agent'];
              return agent is Map && agent.containsKey('__codewalk');
            })
            .cast<Map<String, dynamic>>()
            .first;
        final agent = overridePatch['agent'] as Map<String, dynamic>;
        final syncAgent = agent['__codewalk'] as Map<String, dynamic>;
        final options = syncAgent['options'] as Map<String, dynamic>;
        final codewalk = options['codewalk'] as Map<String, dynamic>;
        final sessionSelections =
            codewalk['sessionSelections'] as Map<String, dynamic>;
        final sessionOverride =
            sessionSelections['ses_1'] as Map<String, dynamic>;

        expect(sessionOverride['providerId'], 'provider_b');
        expect(sessionOverride['modelId'], 'model_b');
      },
    );

    test(
      'initializeProviders applies remote session selection override after restart',
      () async {
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
              Provider(
                id: 'provider_b',
                name: 'Provider B',
                env: const <String>[],
                models: <String, Model>{'model_b': _model('model_b')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a', 'provider_b'],
          ),
        );

        final dioClient = _RecordingDioClient(
          configResponse: <String, dynamic>{
            'model': 'provider_a/model_a',
            'default_agent': 'build',
            'agent': <String, dynamic>{
              '__codewalk': <String, dynamic>{
                'options': <String, dynamic>{
                  'codewalk': <String, dynamic>{
                    'sessionSelections': <String, dynamic>{
                      'ses_1': <String, dynamic>{
                        'providerId': 'provider_b',
                        'modelId': 'model_b',
                        'agentName': 'build',
                        'variantId': '__auto__',
                        'updatedAt': 10,
                      },
                    },
                  },
                },
              },
            },
          },
        );
        provider = buildProvider(dioClient: dioClient);

        await provider.initializeProviders();
        await provider.loadSessions();
        final session = provider.sessions.firstWhere((s) => s.id == 'ses_1');
        await provider.selectSession(session);

        expect(provider.selectedProviderId, 'provider_b');
        expect(provider.selectedModelId, 'model_b');
      },
    );

    test(
      'open-session realtime events reconcile model agent and variant selects',
      () async {
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{
                  'model_a': _model(
                    'model_a',
                    variants: const <String, ModelVariant>{
                      'low': ModelVariant(id: 'low', name: 'Low'),
                    },
                  ),
                },
              ),
              Provider(
                id: 'provider_b',
                name: 'Provider B',
                env: const <String>[],
                models: <String, Model>{
                  'model_b': _model(
                    'model_b',
                    variants: const <String, ModelVariant>{
                      'high': ModelVariant(id: 'high', name: 'High'),
                    },
                  ),
                },
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a', 'provider_b'],
          ),
        );
        appRepository.agentsResult = const Right(<Agent>[
          Agent(name: 'build', mode: 'primary', hidden: false, native: false),
          Agent(name: 'plan', mode: 'primary', hidden: false, native: false),
        ]);

        final config = <String, dynamic>{
          'model': 'provider_a/model_a',
          'default_agent': 'build',
          'agent': <String, dynamic>{
            'build': <String, dynamic>{
              'options': <String, dynamic>{
                'codewalk': <String, dynamic>{
                  'variantByModel': <String, String>{
                    'provider_a/model_a': 'low',
                  },
                },
              },
            },
          },
        };

        final dioClient = _RecordingDioClient(configResponse: config);
        provider = buildProvider(dioClient: dioClient);

        await provider.initializeProviders();
        expect(provider.selectedProviderId, 'provider_a');
        expect(provider.selectedModelId, 'model_a');
        expect(provider.selectedAgentName, 'build');
        expect(provider.selectedVariantId, 'low');

        config
          ..['model'] = 'provider_b/model_b'
          ..['default_agent'] = 'plan'
          ..['agent'] = <String, dynamic>{
            'plan': <String, dynamic>{
              'options': <String, dynamic>{
                'codewalk': <String, dynamic>{
                  'variantByModel': <String, String>{
                    'provider_b/model_b': 'high',
                  },
                },
              },
            },
          };

        await Future<void>.delayed(const Duration(milliseconds: 2100));
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.status',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'status': <String, dynamic>{'type': 'idle'},
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(provider.selectedProviderId, 'provider_b');
        expect(provider.selectedModelId, 'model_b');
        expect(provider.selectedAgentName, 'plan');
        expect(provider.selectedVariantId, 'high');
      },
    );

    test(
      'initializeProviders restores persisted agent and filters selector',
      () async {
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a'],
          ),
        );
        appRepository.agentsResult = const Right(<Agent>[
          Agent(name: 'plan', mode: 'primary', hidden: false, native: false),
          Agent(name: 'build', mode: 'primary', hidden: false, native: false),
          Agent(name: 'support', mode: 'all', hidden: false, native: false),
          Agent(
            name: 'internal',
            mode: 'subagent',
            hidden: false,
            native: true,
          ),
          Agent(name: 'hidden', mode: 'primary', hidden: true, native: false),
        ]);

        await localDataSource.saveSelectedAgent(
          'plan',
          serverId: 'srv_test',
          scopeId: 'default',
        );

        await provider.initializeProviders();

        expect(provider.selectedAgentName, 'plan');
        expect(provider.selectableAgents.map((agent) => agent.name), <String>[
          'build',
          'plan',
          'support',
        ]);
      },
    );

    test('setSelectedAgent and cycleAgent update payload mode', () async {
      appRepository.providersResult = Right(
        ProvidersResponse(
          providers: <Provider>[
            Provider(
              id: 'provider_a',
              name: 'Provider A',
              env: const <String>[],
              models: <String, Model>{'model_a': _model('model_a')},
            ),
          ],
          defaultModels: const <String, String>{'provider_a': 'model_a'},
          connected: const <String>['provider_a'],
        ),
      );
      appRepository.agentsResult = const Right(<Agent>[
        Agent(name: 'build', mode: 'primary', hidden: false, native: false),
        Agent(name: 'plan', mode: 'primary', hidden: false, native: false),
      ]);

      await provider.initializeProviders();
      expect(provider.selectedAgentName, 'build');

      await provider.setSelectedAgent('plan');
      expect(provider.selectedAgentName, 'plan');

      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);
      await provider.sendMessage('agent payload');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(chatRepository.lastSendInput?.mode, 'plan');

      await provider.cycleAgent(reverse: true);
      expect(provider.selectedAgentName, 'build');
    });

    test(
      'setSelectedModel and cycleVariant update selection and payload',
      () async {
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{
                  'model_reasoning': _model(
                    'model_reasoning',
                    variants: const <String, ModelVariant>{
                      'low': ModelVariant(id: 'low', name: 'Low'),
                      'high': ModelVariant(id: 'high', name: 'High'),
                    },
                  ),
                },
              ),
            ],
            defaultModels: const <String, String>{
              'provider_a': 'model_reasoning',
            },
            connected: const <String>['provider_a'],
          ),
        );

        await provider.initializeProviders();
        expect(provider.selectedVariantId, isNull);

        await provider.cycleVariant();
        expect(provider.selectedVariantId, 'low');

        await provider.cycleVariant();
        expect(provider.selectedVariantId, 'high');

        await provider.cycleVariant();
        expect(provider.selectedVariantId, isNull);

        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.setSelectedVariant('high');
        await provider.sendMessage('variant payload');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(chatRepository.lastSendInput?.variant, 'high');
        expect(chatRepository.lastSendInput?.messageId, isNull);
      },
    );

    test(
      'setSelectedModelByProvider updates provider and model together',
      () async {
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
              Provider(
                id: 'provider_b',
                name: 'Provider B',
                env: const <String>[],
                models: <String, Model>{'model_b': _model('model_b')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a'],
          ),
        );

        await provider.initializeProviders();
        expect(provider.selectedProviderId, 'provider_a');
        expect(provider.selectedModelId, 'model_a');

        await provider.setSelectedModelByProvider(
          providerId: 'provider_b',
          modelId: 'model_b',
        );

        expect(provider.selectedProviderId, 'provider_b');
        expect(provider.selectedModelId, 'model_b');
      },
    );

    test(
      'onServerScopeChanged restores model selection per server scope',
      () async {
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
              Provider(
                id: 'provider_b',
                name: 'Provider B',
                env: const <String>[],
                models: <String, Model>{'model_b': _model('model_b')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a', 'provider_b'],
          ),
        );

        await provider.projectProvider.initializeProject();
        await provider.initializeProviders();
        expect(provider.selectedProviderId, 'provider_a');
        expect(provider.selectedModelId, 'model_a');

        await provider.setSelectedModelByProvider(
          providerId: 'provider_b',
          modelId: 'model_b',
        );
        expect(provider.selectedProviderId, 'provider_b');
        expect(provider.selectedModelId, 'model_b');

        localDataSource.activeServerId = 'srv_other';
        await provider.onServerScopeChanged();
        expect(provider.selectedProviderId, 'provider_a');
        expect(provider.selectedModelId, 'model_a');

        await provider.setSelectedModelByProvider(
          providerId: 'provider_a',
          modelId: 'model_a',
        );
        localDataSource.activeServerId = 'srv_test';
        await provider.onServerScopeChanged();
        expect(provider.selectedProviderId, 'provider_b');
        expect(provider.selectedModelId, 'model_b');
      },
    );

    test(
      'onServerScopeChanged restores agent selection per server scope',
      () async {
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a'],
          ),
        );
        appRepository.agentsResult = const Right(<Agent>[
          Agent(name: 'build', mode: 'primary', hidden: false, native: false),
          Agent(name: 'plan', mode: 'primary', hidden: false, native: false),
        ]);

        await provider.projectProvider.initializeProject();
        await provider.initializeProviders();
        expect(provider.selectedAgentName, 'build');

        await provider.setSelectedAgent('plan');
        expect(provider.selectedAgentName, 'plan');

        localDataSource.activeServerId = 'srv_other';
        await provider.onServerScopeChanged();
        expect(provider.selectedAgentName, 'build');

        localDataSource.activeServerId = 'srv_test';
        await provider.onServerScopeChanged();
        expect(provider.selectedAgentName, 'plan');
      },
    );

    test('cycleVariant is no-op when current model has no variants', () async {
      appRepository.providersResult = Right(
        ProvidersResponse(
          providers: <Provider>[
            Provider(
              id: 'provider_a',
              name: 'Provider A',
              env: const <String>[],
              models: <String, Model>{'model_plain': _model('model_plain')},
            ),
          ],
          defaultModels: const <String, String>{'provider_a': 'model_plain'},
          connected: const <String>['provider_a'],
        ),
      );

      await provider.initializeProviders();
      expect(provider.selectedVariantId, isNull);

      await provider.cycleVariant();
      expect(provider.selectedVariantId, isNull);
    });

    test(
      'initializeProviders restores recent/frequent model preference from local storage',
      () async {
        final scopeId =
            provider.projectProvider.currentProject?.path ??
            provider.projectProvider.currentProjectId;

        await localDataSource.saveRecentModelsJson(
          jsonEncode(<String>['provider_b/model_hot']),
          serverId: 'srv_test',
          scopeId: scopeId,
        );
        await localDataSource.saveModelUsageCountsJson(
          jsonEncode(<String, int>{'provider_b/model_hot': 7}),
          serverId: 'srv_test',
          scopeId: scopeId,
        );

        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
              Provider(
                id: 'provider_b',
                name: 'Provider B',
                env: const <String>[],
                models: <String, Model>{'model_hot': _model('model_hot')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>[],
          ),
        );

        await provider.initializeProviders();

        expect(provider.selectedProviderId, 'provider_b');
        expect(provider.selectedModelId, 'model_hot');
        expect(provider.recentModelKeys.first, 'provider_b/model_hot');
        expect(provider.modelUsageCounts['provider_b/model_hot'], 7);
      },
    );

    test('loadSessions merges cache startup with remote refresh', () async {
      await provider.projectProvider.initializeProject();

      final cachedSession = ChatSession(
        id: 'cached_1',
        workspaceId: 'default',
        time: DateTime.fromMillisecondsSinceEpoch(500),
        title: 'Cached Session',
      );
      final cachedJson = jsonEncode(<Map<String, dynamic>>[
        ChatSessionModel.fromDomain(cachedSession).toJson(),
      ]);
      await localDataSource.saveCachedSessions(
        cachedJson,
        serverId: 'srv_test',
        scopeId: '/tmp',
      );

      await provider.loadSessions();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(provider.state, ChatState.loaded);
      expect(provider.sessions.first.id, anyOf('cached_1', 'ses_1'));

      final savedScoped =
          localDataSource.scopedStrings['cached_sessions::srv_test::/tmp'];
      expect(savedScoped, isNotNull);
      final savedCache = jsonDecode(savedScoped!) as List<dynamic>;
      expect(
        (savedCache.first as Map<String, dynamic>)['id'],
        anyOf('cached_1', 'ses_1'),
      );
    });

    test(
      'loadSessions restores cached last-session snapshot and revalidates silently',
      () async {
        await provider.projectProvider.initializeProject();

        final snapshotSession = chatRepository.sessions.first;
        final snapshotMessage = AssistantMessage(
          id: 'msg_cached',
          sessionId: snapshotSession.id,
          time: DateTime.fromMillisecondsSinceEpoch(1010),
          completedTime: DateTime.fromMillisecondsSinceEpoch(1011),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_cached',
              messageId: 'msg_cached',
              sessionId: 'ses_1',
              text: 'cached assistant reply',
            ),
          ],
        );
        final snapshotPayload = jsonEncode(<String, dynamic>{
          'session': ChatSessionModel.fromDomain(snapshotSession).toJson(),
          'messages': <Map<String, dynamic>>[
            ChatMessageModel.fromDomain(snapshotMessage).toJson(),
          ],
        });

        await localDataSource.saveCurrentSessionId(
          snapshotSession.id,
          serverId: 'srv_test',
          scopeId: '/tmp',
        );
        await localDataSource.saveLastSessionSnapshot(
          snapshotPayload,
          serverId: 'srv_test',
          scopeId: '/tmp',
        );
        await localDataSource.saveLastSessionSnapshotUpdatedAt(
          DateTime.now().millisecondsSinceEpoch,
          serverId: 'srv_test',
          scopeId: '/tmp',
        );

        chatRepository.getMessagesFailure = const NetworkFailure(
          'offline',
          503,
        );

        await provider.loadSessions();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(provider.state, ChatState.loaded);
        expect(provider.currentSession?.id, snapshotSession.id);
        expect(provider.messages, hasLength(1));
        expect(
          (provider.messages.first as AssistantMessage).parts
              .whereType<TextPart>()
              .single
              .text,
          'cached assistant reply',
        );
        expect(provider.errorMessage, isNull);
        expect(chatRepository.getMessagesCallCount, greaterThan(0));
      },
    );

    test(
      'createNewSession selects created session in directory-scoped context',
      () async {
        final scopedRepository = FakeChatRepository(
          sessions: <ChatSession>[
            ChatSession(
              id: 'ses_scoped_1',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              title: 'Scoped Session',
              directory: '/tmp',
            ),
          ],
        );
        final scopedProvider = ChatProvider(
          sendChatMessage: SendChatMessage(scopedRepository),
          getChatSessions: GetChatSessions(scopedRepository),
          createChatSession: CreateChatSession(scopedRepository),
          getChatMessages: GetChatMessages(scopedRepository),
          getChatMessage: GetChatMessage(scopedRepository),
          getAgents: GetAgents(appRepository),
          getProviders: GetProviders(appRepository),
          deleteChatSession: DeleteChatSession(scopedRepository),
          updateChatSession: UpdateChatSession(scopedRepository),
          shareChatSession: ShareChatSession(scopedRepository),
          unshareChatSession: UnshareChatSession(scopedRepository),
          forkChatSession: ForkChatSession(scopedRepository),
          getSessionStatus: GetSessionStatus(scopedRepository),
          getSessionChildren: GetSessionChildren(scopedRepository),
          getSessionTodo: GetSessionTodo(scopedRepository),
          getSessionDiff: GetSessionDiff(scopedRepository),
          watchChatEvents: WatchChatEvents(scopedRepository),
          watchGlobalChatEvents: WatchGlobalChatEvents(scopedRepository),
          listPendingPermissions: ListPendingPermissions(scopedRepository),
          replyPermission: ReplyPermission(scopedRepository),
          listPendingQuestions: ListPendingQuestions(scopedRepository),
          replyQuestion: ReplyQuestion(scopedRepository),
          rejectQuestion: RejectQuestion(scopedRepository),
          projectProvider: ProjectProvider(
            projectRepository: FakeProjectRepository(),
            localDataSource: localDataSource,
          ),
          localDataSource: localDataSource,
        );

        await scopedProvider.projectProvider.initializeProject();
        await scopedProvider.loadSessions();
        expect(scopedProvider.currentSession?.id, 'ses_scoped_1');

        await scopedProvider.createNewSession();

        expect(scopedProvider.state, ChatState.loaded);
        expect(scopedProvider.currentSession, isNotNull);
        expect(scopedProvider.currentSession?.id, isNot('ses_scoped_1'));
        expect(
          scopedProvider.sessions.any(
            (session) => session.id == scopedProvider.currentSession?.id,
          ),
          isTrue,
        );
        expect(scopedProvider.messages, isEmpty);

        final storedCurrent = await localDataSource.getCurrentSessionId(
          serverId: 'srv_test',
          scopeId: '/tmp',
        );
        expect(storedCurrent, scopedProvider.currentSession?.id);
      },
    );

    test(
      'sendMessage appends user message and final assistant reply',
      () async {
        final assistantPartial = AssistantMessage(
          id: 'msg_assistant_1',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          parts: const <MessagePart>[
            TextPart(
              id: 'prt_partial',
              messageId: 'msg_assistant_1',
              sessionId: 'ses_1',
              text: 'draft',
            ),
          ],
        );
        final assistantCompleted = AssistantMessage(
          id: 'msg_assistant_1',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(2200),
          parts: const <MessagePart>[
            TextPart(
              id: 'prt_done',
              messageId: 'msg_assistant_1',
              sessionId: 'ses_1',
              text: 'final answer',
            ),
          ],
        );

        chatRepository.sendMessageHandler = (_, __, ___, ____) async* {
          yield Right(assistantPartial);
          await Future<void>.delayed(const Duration(milliseconds: 1));
          yield Right(assistantCompleted);
        };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.sendMessage('hello provider');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(provider.state, ChatState.loaded);
        expect(provider.messages.length, 2);
        expect((provider.messages.first as UserMessage).parts, hasLength(1));
        final assistant = provider.messages.last as AssistantMessage;
        expect((assistant.parts.single as TextPart).text, 'final answer');
        expect(
          chatRepository.lastSendInput?.parts.single,
          const TextInputPart(text: 'hello provider'),
        );
        expect(chatRepository.lastSendInput?.messageId, isNull);
        expect(
          chatRepository.lastSendDirectory,
          provider.projectProvider.currentProject?.path,
        );
      },
    );

    test('sendMessage sends shell mode payload when requested', () async {
      final assistantCompleted = AssistantMessage(
        id: 'msg_shell_done',
        sessionId: 'ses_1',
        time: DateTime.fromMillisecondsSinceEpoch(2000),
        completedTime: DateTime.fromMillisecondsSinceEpoch(2100),
        parts: const <MessagePart>[
          TextPart(
            id: 'prt_shell_done',
            messageId: 'msg_shell_done',
            sessionId: 'ses_1',
            text: 'shell output',
          ),
        ],
      );
      chatRepository.sendMessageHandler = (_, __, ___, ____) async* {
        yield Right(assistantCompleted);
      };

      await provider.projectProvider.initializeProject();
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);

      await provider.sendMessage('pwd', shellMode: true);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(provider.state, ChatState.loaded);
      expect(chatRepository.lastSendInput?.mode, 'shell');
      expect(
        chatRepository.lastSendInput?.parts.single,
        const TextInputPart(text: 'pwd'),
      );
      final userMessage = provider.messages.first as UserMessage;
      expect((userMessage.parts.first as TextPart).text, '!pwd');
    });

    test(
      'does not generate AI titles when server toggle is disabled',
      () async {
        final titleGenerator = _FakeChatTitleGenerator();
        final providerWithAutoTitle = ChatProvider(
          sendChatMessage: SendChatMessage(chatRepository),
          abortChatSession: AbortChatSession(chatRepository),
          getChatSessions: GetChatSessions(chatRepository),
          createChatSession: CreateChatSession(chatRepository),
          getChatMessages: GetChatMessages(chatRepository),
          getChatMessage: GetChatMessage(chatRepository),
          getAgents: GetAgents(appRepository),
          getProviders: GetProviders(appRepository),
          deleteChatSession: DeleteChatSession(chatRepository),
          updateChatSession: UpdateChatSession(chatRepository),
          shareChatSession: ShareChatSession(chatRepository),
          unshareChatSession: UnshareChatSession(chatRepository),
          forkChatSession: ForkChatSession(chatRepository),
          getSessionStatus: GetSessionStatus(chatRepository),
          getSessionChildren: GetSessionChildren(chatRepository),
          getSessionTodo: GetSessionTodo(chatRepository),
          getSessionDiff: GetSessionDiff(chatRepository),
          watchChatEvents: WatchChatEvents(chatRepository),
          watchGlobalChatEvents: WatchGlobalChatEvents(chatRepository),
          listPendingPermissions: ListPendingPermissions(chatRepository),
          replyPermission: ReplyPermission(chatRepository),
          listPendingQuestions: ListPendingQuestions(chatRepository),
          replyQuestion: ReplyQuestion(chatRepository),
          rejectQuestion: RejectQuestion(chatRepository),
          projectProvider: ProjectProvider(
            projectRepository: FakeProjectRepository(),
            localDataSource: localDataSource,
          ),
          localDataSource: localDataSource,
          titleGenerator: titleGenerator,
        );

        chatRepository.sendMessageHandler = (_, __, ___, ____) async* {
          yield Right(
            AssistantMessage(
              id: 'msg_assistant_toggle_off',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(2000),
              completedTime: DateTime.fromMillisecondsSinceEpoch(2100),
              parts: const <MessagePart>[
                TextPart(
                  id: 'prt_assistant_toggle_off',
                  messageId: 'msg_assistant_toggle_off',
                  sessionId: 'ses_1',
                  text: 'reply',
                ),
              ],
            ),
          );
        };

        await providerWithAutoTitle.projectProvider.initializeProject();
        await providerWithAutoTitle.loadSessions();
        await providerWithAutoTitle.selectSession(
          providerWithAutoTitle.sessions.first,
        );
        await providerWithAutoTitle.sendMessage('hello');
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(titleGenerator.callCount, 0);
      },
    );

    test(
      'generates title after each user/assistant turn until 3+3 messages',
      () async {
        localDataSource.serverProfilesJson = jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'srv_test',
            'url': 'http://127.0.0.1:4096',
            'createdAt': 1,
            'updatedAt': 1,
            'aiGeneratedTitlesEnabled': true,
          },
        ]);
        final titleGenerator = _FakeChatTitleGenerator();
        final providerWithAutoTitle = ChatProvider(
          sendChatMessage: SendChatMessage(chatRepository),
          abortChatSession: AbortChatSession(chatRepository),
          getChatSessions: GetChatSessions(chatRepository),
          createChatSession: CreateChatSession(chatRepository),
          getChatMessages: GetChatMessages(chatRepository),
          getChatMessage: GetChatMessage(chatRepository),
          getAgents: GetAgents(appRepository),
          getProviders: GetProviders(appRepository),
          deleteChatSession: DeleteChatSession(chatRepository),
          updateChatSession: UpdateChatSession(chatRepository),
          shareChatSession: ShareChatSession(chatRepository),
          unshareChatSession: UnshareChatSession(chatRepository),
          forkChatSession: ForkChatSession(chatRepository),
          getSessionStatus: GetSessionStatus(chatRepository),
          getSessionChildren: GetSessionChildren(chatRepository),
          getSessionTodo: GetSessionTodo(chatRepository),
          getSessionDiff: GetSessionDiff(chatRepository),
          watchChatEvents: WatchChatEvents(chatRepository),
          watchGlobalChatEvents: WatchGlobalChatEvents(chatRepository),
          listPendingPermissions: ListPendingPermissions(chatRepository),
          replyPermission: ReplyPermission(chatRepository),
          listPendingQuestions: ListPendingQuestions(chatRepository),
          replyQuestion: ReplyQuestion(chatRepository),
          rejectQuestion: RejectQuestion(chatRepository),
          projectProvider: ProjectProvider(
            projectRepository: FakeProjectRepository(),
            localDataSource: localDataSource,
          ),
          localDataSource: localDataSource,
          titleGenerator: titleGenerator,
        );

        var responseCounter = 0;
        chatRepository.sendMessageHandler = (_, __, ___, ____) async* {
          responseCounter += 1;
          yield Right(
            AssistantMessage(
              id: 'msg_assistant_$responseCounter',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(2000 + responseCounter),
              completedTime: DateTime.fromMillisecondsSinceEpoch(
                2100 + responseCounter,
              ),
              parts: <MessagePart>[
                TextPart(
                  id: 'prt_assistant_$responseCounter',
                  messageId: 'msg_assistant_$responseCounter',
                  sessionId: 'ses_1',
                  text: 'assistant reply $responseCounter',
                ),
              ],
            ),
          );
        };

        await providerWithAutoTitle.projectProvider.initializeProject();
        await providerWithAutoTitle.loadSessions();
        await providerWithAutoTitle.selectSession(
          providerWithAutoTitle.sessions.first,
        );

        await providerWithAutoTitle.sendMessage('user 1');
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await providerWithAutoTitle.sendMessage('user 2');
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await providerWithAutoTitle.sendMessage('user 3');
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(titleGenerator.callCount, 6);
        final lastBatch = titleGenerator.payloads.last;
        expect(lastBatch.length, 6);
        expect(lastBatch.where((item) => item.role == 'user').length, 3);
        expect(lastBatch.where((item) => item.role == 'assistant').length, 3);

        await providerWithAutoTitle.sendMessage('user 4');
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(titleGenerator.callCount, 6);
      },
    );

    test(
      'does not apply stale auto-title result after switching sessions',
      () async {
        localDataSource.serverProfilesJson = jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'srv_test',
            'url': 'http://127.0.0.1:4096',
            'createdAt': 1,
            'updatedAt': 1,
            'aiGeneratedTitlesEnabled': true,
          },
        ]);
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_2',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1100),
            title: 'Session 2',
          ),
        );

        final completer = Completer<String?>();
        final titleGenerator = _BlockingChatTitleGenerator(completer);
        final providerWithAutoTitle = ChatProvider(
          sendChatMessage: SendChatMessage(chatRepository),
          abortChatSession: AbortChatSession(chatRepository),
          getChatSessions: GetChatSessions(chatRepository),
          createChatSession: CreateChatSession(chatRepository),
          getChatMessages: GetChatMessages(chatRepository),
          getChatMessage: GetChatMessage(chatRepository),
          getAgents: GetAgents(appRepository),
          getProviders: GetProviders(appRepository),
          deleteChatSession: DeleteChatSession(chatRepository),
          updateChatSession: UpdateChatSession(chatRepository),
          shareChatSession: ShareChatSession(chatRepository),
          unshareChatSession: UnshareChatSession(chatRepository),
          forkChatSession: ForkChatSession(chatRepository),
          getSessionStatus: GetSessionStatus(chatRepository),
          getSessionChildren: GetSessionChildren(chatRepository),
          getSessionTodo: GetSessionTodo(chatRepository),
          getSessionDiff: GetSessionDiff(chatRepository),
          watchChatEvents: WatchChatEvents(chatRepository),
          watchGlobalChatEvents: WatchGlobalChatEvents(chatRepository),
          listPendingPermissions: ListPendingPermissions(chatRepository),
          replyPermission: ReplyPermission(chatRepository),
          listPendingQuestions: ListPendingQuestions(chatRepository),
          replyQuestion: ReplyQuestion(chatRepository),
          rejectQuestion: RejectQuestion(chatRepository),
          projectProvider: ProjectProvider(
            projectRepository: FakeProjectRepository(),
            localDataSource: localDataSource,
          ),
          localDataSource: localDataSource,
          titleGenerator: titleGenerator,
        );

        final updatedSessionIds = <String>[];
        chatRepository.updateSessionHandler = (_, sessionId, input, __) async {
          updatedSessionIds.add(sessionId);
          final index = chatRepository.sessions.indexWhere(
            (item) => item.id == sessionId,
          );
          final updated = chatRepository.sessions[index].copyWith(
            title: input.title,
          );
          chatRepository.sessions[index] = updated;
          return Right(updated);
        };

        chatRepository.sendMessageHandler = (_, __, ___, ____) async* {
          yield Right(
            AssistantMessage(
              id: 'msg_assistant_stale',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(2000),
              completedTime: DateTime.fromMillisecondsSinceEpoch(2100),
              parts: const <MessagePart>[
                TextPart(
                  id: 'prt_assistant_stale',
                  messageId: 'msg_assistant_stale',
                  sessionId: 'ses_1',
                  text: 'reply',
                ),
              ],
            ),
          );
        };

        await providerWithAutoTitle.projectProvider.initializeProject();
        await providerWithAutoTitle.loadSessions();
        await providerWithAutoTitle.selectSession(
          providerWithAutoTitle.sessions
              .where((item) => item.id == 'ses_1')
              .first,
        );

        await providerWithAutoTitle.sendMessage('hello');
        await providerWithAutoTitle.selectSession(
          providerWithAutoTitle.sessions
              .where((item) => item.id == 'ses_2')
              .first,
        );

        completer.complete('Stale title');
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(titleGenerator.callCount, 1);
        expect(updatedSessionIds, isEmpty);
        expect(
          chatRepository.sessions
              .where((item) => item.id == 'ses_1')
              .first
              .title,
          'Session 1',
        );
      },
    );

    test(
      'does not regenerate title on reopen when transcript is already 3+3',
      () async {
        localDataSource.serverProfilesJson = jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'srv_test',
            'url': 'http://127.0.0.1:4096',
            'createdAt': 1,
            'updatedAt': 1,
            'aiGeneratedTitlesEnabled': true,
          },
        ]);

        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          UserMessage(
            id: 'msg_user_1',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_user_1',
                messageId: 'msg_user_1',
                sessionId: 'ses_1',
                text: 'user 1',
              ),
            ],
          ),
          AssistantMessage(
            id: 'msg_assistant_1',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1100),
            completedTime: DateTime.fromMillisecondsSinceEpoch(1150),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_assistant_1',
                messageId: 'msg_assistant_1',
                sessionId: 'ses_1',
                text: 'assistant 1',
              ),
            ],
          ),
          UserMessage(
            id: 'msg_user_2',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1200),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_user_2',
                messageId: 'msg_user_2',
                sessionId: 'ses_1',
                text: 'user 2',
              ),
            ],
          ),
          AssistantMessage(
            id: 'msg_assistant_2',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1300),
            completedTime: DateTime.fromMillisecondsSinceEpoch(1350),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_assistant_2',
                messageId: 'msg_assistant_2',
                sessionId: 'ses_1',
                text: 'assistant 2',
              ),
            ],
          ),
          UserMessage(
            id: 'msg_user_3',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1400),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_user_3',
                messageId: 'msg_user_3',
                sessionId: 'ses_1',
                text: 'user 3',
              ),
            ],
          ),
          AssistantMessage(
            id: 'msg_assistant_3',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1500),
            completedTime: DateTime.fromMillisecondsSinceEpoch(1550),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_assistant_3',
                messageId: 'msg_assistant_3',
                sessionId: 'ses_1',
                text: 'assistant 3',
              ),
            ],
          ),
        ];

        final titleGenerator = _FakeChatTitleGenerator();
        final providerWithAutoTitle = ChatProvider(
          sendChatMessage: SendChatMessage(chatRepository),
          abortChatSession: AbortChatSession(chatRepository),
          getChatSessions: GetChatSessions(chatRepository),
          createChatSession: CreateChatSession(chatRepository),
          getChatMessages: GetChatMessages(chatRepository),
          getChatMessage: GetChatMessage(chatRepository),
          getAgents: GetAgents(appRepository),
          getProviders: GetProviders(appRepository),
          deleteChatSession: DeleteChatSession(chatRepository),
          updateChatSession: UpdateChatSession(chatRepository),
          shareChatSession: ShareChatSession(chatRepository),
          unshareChatSession: UnshareChatSession(chatRepository),
          forkChatSession: ForkChatSession(chatRepository),
          getSessionStatus: GetSessionStatus(chatRepository),
          getSessionChildren: GetSessionChildren(chatRepository),
          getSessionTodo: GetSessionTodo(chatRepository),
          getSessionDiff: GetSessionDiff(chatRepository),
          watchChatEvents: WatchChatEvents(chatRepository),
          watchGlobalChatEvents: WatchGlobalChatEvents(chatRepository),
          listPendingPermissions: ListPendingPermissions(chatRepository),
          replyPermission: ReplyPermission(chatRepository),
          listPendingQuestions: ListPendingQuestions(chatRepository),
          replyQuestion: ReplyQuestion(chatRepository),
          rejectQuestion: RejectQuestion(chatRepository),
          projectProvider: ProjectProvider(
            projectRepository: FakeProjectRepository(),
            localDataSource: localDataSource,
          ),
          localDataSource: localDataSource,
          titleGenerator: titleGenerator,
        );

        await providerWithAutoTitle.projectProvider.initializeProject();
        await providerWithAutoTitle.loadSessions();
        await providerWithAutoTitle.selectSession(
          providerWithAutoTitle.sessions.first,
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(titleGenerator.callCount, 0);
      },
    );

    test(
      'session.error with aborted message after stop does not replace chat with global error',
      () async {
        final streamController =
            StreamController<Either<Failure, ChatMessage>>();
        addTearDown(() async {
          await streamController.close();
        });
        chatRepository.sendMessageHandler = (_, __, ___, ____) =>
            streamController.stream;

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.sendMessage('stop me');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final stopped = await provider.abortActiveResponse();
        expect(stopped, isTrue);

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.error',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'error': <String, dynamic>{
                'message': 'The operation was aborted.',
              },
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(provider.state, ChatState.loaded);
        expect(provider.errorMessage, isNull);
      },
    );

    test(
      'session.error with retry marker after stop does not replace chat with global error',
      () async {
        final streamController =
            StreamController<Either<Failure, ChatMessage>>();
        addTearDown(() async {
          await streamController.close();
        });
        chatRepository.sendMessageHandler = (_, __, ___, ____) =>
            streamController.stream;

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.sendMessage('stop me');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final stopped = await provider.abortActiveResponse();
        expect(stopped, isTrue);

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.error',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'error': <String, dynamic>{'message': 'retry'},
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(provider.state, ChatState.loaded);
        expect(provider.errorMessage, isNull);
      },
    );

    test(
      'sending again immediately after stop keeps provider stable and delivers next reply',
      () async {
        final firstStreamController =
            StreamController<Either<Failure, ChatMessage>>();
        addTearDown(() async {
          await firstStreamController.close();
        });
        final assistantAfterStop = AssistantMessage(
          id: 'msg_after_stop',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(3000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(3100),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_after_stop',
              messageId: 'msg_after_stop',
              sessionId: 'ses_1',
              text: 'new reply after stop',
            ),
          ],
        );
        var sendCalls = 0;
        chatRepository.sendMessageHandler = (_, __, ___, ____) {
          sendCalls += 1;
          if (sendCalls == 1) {
            return firstStreamController.stream;
          }
          return Stream<Either<Failure, ChatMessage>>.value(
            Right(assistantAfterStop),
          );
        };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.sendMessage('first prompt');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final stopped = await provider.abortActiveResponse();
        expect(stopped, isTrue);

        await provider.sendMessage('prompt after stop');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(provider.state, ChatState.loaded);
        expect(provider.errorMessage, isNull);
        final sentAfterStop = provider.messages.whereType<UserMessage>().any((
          message,
        ) {
          return message.parts.whereType<TextPart>().any(
            (part) => part.text == 'prompt after stop',
          );
        });
        expect(sentAfterStop, isTrue);
        final assistant = provider.messages.last as AssistantMessage;
        expect(
          (assistant.parts.single as TextPart).text,
          'new reply after stop',
        );
      },
    );

    test('session.error after stop still surfaces non-abort errors', () async {
      final streamController = StreamController<Either<Failure, ChatMessage>>();
      addTearDown(() async {
        await streamController.close();
      });
      chatRepository.sendMessageHandler = (_, __, ___, ____) =>
          streamController.stream;

      await provider.projectProvider.initializeProject();
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);

      await provider.sendMessage('stop me');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final stopped = await provider.abortActiveResponse();
      expect(stopped, isTrue);

      chatRepository.emitEvent(
        const ChatEvent(
          type: 'session.error',
          properties: <String, dynamic>{
            'sessionID': 'ses_1',
            'error': <String, dynamic>{'message': 'Rate limit exceeded'},
          },
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(provider.state, ChatState.error);
      expect(provider.errorMessage, 'Rate limit exceeded');
    });

    test(
      'sendMessage replaces optimistic local user message with server user message',
      () async {
        final now = DateTime.now();
        final serverUserMessage = UserMessage(
          id: 'msg_server_user_1',
          sessionId: 'ses_1',
          time: now.add(const Duration(seconds: 1)),
          parts: const <MessagePart>[
            TextPart(
              id: 'prt_user_server_1',
              messageId: 'msg_server_user_1',
              sessionId: 'ses_1',
              text: 'hello dedupe',
            ),
          ],
        );
        final assistantCompleted = AssistantMessage(
          id: 'msg_assistant_dedupe',
          sessionId: 'ses_1',
          time: now.add(const Duration(seconds: 2)),
          completedTime: now.add(const Duration(seconds: 3)),
          parts: const <MessagePart>[
            TextPart(
              id: 'prt_assistant_dedupe',
              messageId: 'msg_assistant_dedupe',
              sessionId: 'ses_1',
              text: 'dedupe ok',
            ),
          ],
        );

        chatRepository.sendMessageHandler = (_, __, ___, ____) async* {
          yield Right(serverUserMessage);
          await Future<void>.delayed(const Duration(milliseconds: 1));
          yield Right(assistantCompleted);
        };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.sendMessage('hello dedupe');
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(provider.state, ChatState.loaded);
        expect(provider.messages.length, 2);
        expect(provider.messages.first.id, 'msg_server_user_1');
        expect((provider.messages.first as UserMessage).parts, hasLength(1));
        expect(
          ((provider.messages.first as UserMessage).parts.first as TextPart)
              .text,
          'hello dedupe',
        );
        expect(provider.messages.last.id, 'msg_assistant_dedupe');
      },
    );

    test(
      'sendMessage works when recent models are restored from local storage',
      () async {
        final scopeId =
            provider.projectProvider.currentProject?.path ??
            provider.projectProvider.currentProjectId;
        await localDataSource.saveRecentModelsJson(
          jsonEncode(<String>['provider_a/model_a']),
          serverId: 'srv_test',
          scopeId: scopeId,
        );

        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a'],
          ),
        );

        final assistantCompleted = AssistantMessage(
          id: 'msg_assistant_recent_storage',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(2200),
          parts: const <MessagePart>[
            TextPart(
              id: 'prt_recent_storage_done',
              messageId: 'msg_assistant_recent_storage',
              sessionId: 'ses_1',
              text: 'answer from restored recent model',
            ),
          ],
        );
        chatRepository.sendMessageHandler = (_, __, ___, ____) async* {
          yield Right(assistantCompleted);
        };

        await provider.projectProvider.initializeProject();
        await provider.initializeProviders();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.sendMessage('hello from restored recent storage');
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(provider.state, ChatState.loaded);
        expect(
          chatRepository.lastSendInput?.parts.single,
          const TextInputPart(text: 'hello from restored recent storage'),
        );
        final assistant = provider.messages.last as AssistantMessage;
        expect(
          (assistant.parts.single as TextPart).text,
          'answer from restored recent model',
        );
      },
    );

    test(
      'sendMessage continues when local selection persistence fails',
      () async {
        final failingLocalDataSource = _ThrowingPersistenceLocalDataSource();
        failingLocalDataSource.activeServerId = 'srv_test';

        final resilientProvider = ChatProvider(
          sendChatMessage: SendChatMessage(chatRepository),
          getChatSessions: GetChatSessions(chatRepository),
          createChatSession: CreateChatSession(chatRepository),
          getChatMessages: GetChatMessages(chatRepository),
          getChatMessage: GetChatMessage(chatRepository),
          getAgents: GetAgents(appRepository),
          getProviders: GetProviders(appRepository),
          deleteChatSession: DeleteChatSession(chatRepository),
          updateChatSession: UpdateChatSession(chatRepository),
          shareChatSession: ShareChatSession(chatRepository),
          unshareChatSession: UnshareChatSession(chatRepository),
          forkChatSession: ForkChatSession(chatRepository),
          getSessionStatus: GetSessionStatus(chatRepository),
          getSessionChildren: GetSessionChildren(chatRepository),
          getSessionTodo: GetSessionTodo(chatRepository),
          getSessionDiff: GetSessionDiff(chatRepository),
          watchChatEvents: WatchChatEvents(chatRepository),
          watchGlobalChatEvents: WatchGlobalChatEvents(chatRepository),
          listPendingPermissions: ListPendingPermissions(chatRepository),
          replyPermission: ReplyPermission(chatRepository),
          listPendingQuestions: ListPendingQuestions(chatRepository),
          replyQuestion: ReplyQuestion(chatRepository),
          rejectQuestion: RejectQuestion(chatRepository),
          projectProvider: ProjectProvider(
            projectRepository: FakeProjectRepository(),
            localDataSource: failingLocalDataSource,
          ),
          localDataSource: failingLocalDataSource,
        );

        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a'],
          ),
        );

        final assistantCompleted = AssistantMessage(
          id: 'msg_assistant_resilient',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(2200),
          parts: const <MessagePart>[
            TextPart(
              id: 'prt_resilient_done',
              messageId: 'msg_assistant_resilient',
              sessionId: 'ses_1',
              text: 'resilient answer',
            ),
          ],
        );
        chatRepository.sendMessageHandler = (_, __, ___, ____) async* {
          yield Right(assistantCompleted);
        };

        await resilientProvider.projectProvider.initializeProject();
        await resilientProvider.initializeProviders();
        await resilientProvider.loadSessions();
        await resilientProvider.selectSession(resilientProvider.sessions.first);

        await resilientProvider.sendMessage('hello with persistence failure');
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(resilientProvider.state, ChatState.loaded);
        expect(
          chatRepository.lastSendInput?.parts.single,
          const TextInputPart(text: 'hello with persistence failure'),
        );
        expect(chatRepository.lastSendInput?.messageId, isNull);
        final assistant = resilientProvider.messages.last as AssistantMessage;
        expect((assistant.parts.single as TextPart).text, 'resilient answer');
      },
    );

    test('renameSession applies persisted title on success', () async {
      await provider.loadSessions();
      final session = provider.sessions.first;

      final ok = await provider.renameSession(session, 'Renamed Session');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(ok, isTrue);
      expect(
        provider.sessions.where((item) => item.id == session.id).first.title,
        'Renamed Session',
      );
      expect(
        chatRepository.sessions
            .where((item) => item.id == session.id)
            .first
            .title,
        'Renamed Session',
      );
    });

    test(
      'renameSession returns true for no-op rename with same title',
      () async {
        await provider.loadSessions();
        final session = provider.sessions.first;

        final ok = await provider.renameSession(session, 'Session 1');

        expect(ok, isTrue);
        expect(
          provider.sessions.where((item) => item.id == session.id).first.title,
          'Session 1',
        );
      },
    );

    test('renameSession rolls back optimistic title on failure', () async {
      await provider.loadSessions();
      final session = provider.sessions.first;
      chatRepository.updateSessionFailure = const ServerFailure(
        'update failed',
      );

      final ok = await provider.renameSession(session, 'Broken Rename');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(ok, isFalse);
      expect(
        provider.sessions.where((item) => item.id == session.id).first.title,
        'Session 1',
      );
      expect(provider.state, ChatState.error);
    });

    test(
      'share/archive/fork lifecycle operations update provider state',
      () async {
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_2',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1200),
            title: 'Session 2',
          ),
        );

        await provider.loadSessions();
        await provider.selectSession(
          provider.sessions.where((item) => item.id == 'ses_1').first,
        );

        final shared = await provider.toggleSessionShare(
          provider.currentSession!,
        );
        expect(shared, isTrue);
        expect(provider.currentSession?.shared, isTrue);
        expect(provider.currentSession?.shareUrl, isNotNull);

        final archived = await provider.setSessionArchived(
          provider.currentSession!,
          true,
        );
        expect(archived, isTrue);
        final archivedSession = provider.sessions
            .where((item) => item.id == 'ses_1')
            .first;
        expect(archivedSession.archived, isTrue);

        final unarchived = await provider.setSessionArchived(
          archivedSession,
          false,
        );
        expect(unarchived, isTrue);
        final unarchivedSession = provider.sessions
            .where((item) => item.id == 'ses_1')
            .first;
        expect(unarchivedSession.archived, isFalse);

        final forked = await provider.forkSession(unarchivedSession);
        expect(forked, isNotNull);
        expect(forked?.parentId, 'ses_1');
        expect(provider.currentSession?.id, forked?.id);
      },
    );

    test(
      'loadSessionInsights updates children, todo, diff and status maps',
      () async {
        final child = ChatSession(
          id: 'ses_child_1',
          workspaceId: 'default',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          title: 'Child Session',
          parentId: 'ses_1',
        );
        chatRepository.sessionChildrenById['ses_1'] = <ChatSession>[child];
        chatRepository.sessionTodoById['ses_1'] = const <SessionTodo>[
          SessionTodo(
            id: 'todo_1',
            content: 'Implement feature',
            status: 'in_progress',
            priority: 'high',
          ),
        ];
        chatRepository.sessionDiffById['ses_1'] = const <SessionDiff>[
          SessionDiff(
            file: 'lib/main.dart',
            before: '',
            after: '',
            additions: 10,
            deletions: 2,
            status: 'modified',
          ),
        ];
        chatRepository.sessionStatusById = const <String, SessionStatusInfo>{
          'ses_1': SessionStatusInfo(type: SessionStatusType.busy),
        };

        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.loadSessionInsights('ses_1');

        expect(provider.currentSessionChildren, hasLength(1));
        expect(provider.currentSessionChildren.single.id, 'ses_child_1');
        expect(provider.currentSessionTodo, hasLength(1));
        expect(provider.currentSessionTodo.single.id, 'todo_1');
        expect(provider.currentSessionDiff, hasLength(1));
        expect(provider.currentSessionDiff.single.file, 'lib/main.dart');
        expect(provider.currentSessionStatus?.type, SessionStatusType.busy);
      },
    );

    test(
      'deleteSession clears current session when deleting active one',
      () async {
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        expect(provider.currentSession?.id, 'ses_1');

        await provider.deleteSession('ses_1');
        await Future<void>.delayed(const Duration(milliseconds: 5));

        expect(provider.sessions, isEmpty);
        expect(provider.currentSession, isNull);
        expect(provider.messages, isEmpty);
      },
    );

    test('loadSessions surfaces mapped failure state', () async {
      chatRepository.getSessionsFailure = const NetworkFailure('no network');

      await provider.loadSessions();

      expect(provider.state, ChatState.error);
      expect(
        provider.errorMessage,
        'Network connection failed. Please check network settings',
      );
    });

    test(
      'applies realtime message.updated fallback fetch and session status',
      () async {
        final draft = AssistantMessage(
          id: 'msg_ai_live',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          parts: const <MessagePart>[
            TextPart(
              id: 'prt_draft',
              messageId: 'msg_ai_live',
              sessionId: 'ses_1',
              text: 'draft',
            ),
          ],
        );
        final completed = AssistantMessage(
          id: 'msg_ai_live',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(1500),
          parts: const <MessagePart>[
            TextPart(
              id: 'prt_done',
              messageId: 'msg_ai_live',
              sessionId: 'ses_1',
              text: 'done',
            ),
          ],
        );
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[draft];

        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a'],
          ),
        );

        await provider.initializeProviders();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        expect(
          ((provider.messages.single as AssistantMessage).parts.single
                  as TextPart)
              .text,
          'draft',
        );

        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[completed];
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'message.updated',
            properties: <String, dynamic>{
              'info': <String, dynamic>{
                'id': 'msg_ai_live',
                'sessionID': 'ses_1',
              },
            },
          ),
        );
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.status',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'status': <String, dynamic>{'type': 'busy'},
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        final message = provider.messages.single as AssistantMessage;
        expect((message.parts.single as TextPart).text, 'done');
        expect(message.isCompleted, isTrue);
        expect(provider.currentSessionStatus?.type, SessionStatusType.busy);
      },
    );

    test('refreshes active session when realtime stream reconnects', () async {
      final draft = AssistantMessage(
        id: 'msg_ai_live',
        sessionId: 'ses_1',
        time: DateTime.fromMillisecondsSinceEpoch(1000),
        parts: const <MessagePart>[
          TextPart(
            id: 'prt_draft',
            messageId: 'msg_ai_live',
            sessionId: 'ses_1',
            text: 'draft',
          ),
        ],
      );
      final updated = AssistantMessage(
        id: 'msg_ai_live',
        sessionId: 'ses_1',
        time: DateTime.fromMillisecondsSinceEpoch(1000),
        completedTime: DateTime.fromMillisecondsSinceEpoch(1800),
        parts: const <MessagePart>[
          TextPart(
            id: 'prt_done',
            messageId: 'msg_ai_live',
            sessionId: 'ses_1',
            text: 'done after reconnect',
          ),
        ],
      );
      chatRepository.messagesBySession['ses_1'] = <ChatMessage>[draft];
      chatRepository.sessionStatusById = const <String, SessionStatusInfo>{
        'ses_1': SessionStatusInfo(type: SessionStatusType.idle),
      };

      appRepository.providersResult = Right(
        ProvidersResponse(
          providers: <Provider>[
            Provider(
              id: 'provider_a',
              name: 'Provider A',
              env: const <String>[],
              models: <String, Model>{'model_a': _model('model_a')},
            ),
          ],
          defaultModels: const <String, String>{'provider_a': 'model_a'},
          connected: const <String>['provider_a'],
        ),
      );

      await provider.initializeProviders();
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);
      expect(
        ((provider.messages.single as AssistantMessage).parts.single
                as TextPart)
            .text,
        'draft',
      );

      chatRepository.messagesBySession['ses_1'] = <ChatMessage>[updated];
      chatRepository.sessionStatusById = const <String, SessionStatusInfo>{
        'ses_1': SessionStatusInfo(type: SessionStatusType.busy),
      };
      chatRepository.emitEvent(
        const ChatEvent(
          type: 'server.connected',
          properties: <String, dynamic>{},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));

      final message = provider.messages.single as AssistantMessage;
      expect((message.parts.single as TextPart).text, 'done after reconnect');
      expect(provider.currentSessionStatus?.type, SessionStatusType.busy);
    });

    test(
      'enters degraded mode after repeated stream failures and recovers on signal',
      () async {
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a'],
          ),
        );

        await provider.initializeProviders();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        chatRepository.emitEventFailure(const NetworkFailure('stream down 1'));
        chatRepository.emitEventFailure(const NetworkFailure('stream down 2'));
        chatRepository.emitEventFailure(const NetworkFailure('stream down 3'));
        await Future<void>.delayed(const Duration(milliseconds: 60));

        expect(provider.isInDegradedMode, isTrue);
        expect(provider.syncState, ChatSyncState.delayed);

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.status',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'status': <String, dynamic>{'type': 'idle'},
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 60));

        expect(provider.isInDegradedMode, isFalse);
        expect(provider.syncState, ChatSyncState.connected);
      },
    );

    test(
      'resume foreground re-subscribes and reconciles session state',
      () async {
        final nextMessage = AssistantMessage(
          id: 'msg_resume',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(2100),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_resume',
              messageId: 'msg_resume',
              sessionId: 'ses_1',
              text: 'after resume',
            ),
          ],
        );
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[nextMessage];

        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a'],
          ),
        );

        await provider.initializeProviders();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        final sessionsBefore = chatRepository.getSessionsCallCount;
        final messagesBefore = chatRepository.getMessagesCallCount;

        await provider.setForegroundActive(false);
        await provider.setForegroundActive(true);
        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(
          chatRepository.getSessionsCallCount,
          greaterThan(sessionsBefore),
        );
        expect(
          chatRepository.getMessagesCallCount,
          greaterThan(messagesBefore),
        );
        expect(
          ((provider.messages.single as AssistantMessage).parts.single
                  as TextPart)
              .text,
          'after resume',
        );
      },
    );

    test(
      'global session.updated applies incrementally without broad session reload',
      () async {
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a'],
          ),
        );

        await provider.initializeProviders();
        await provider.loadSessions();
        final sessionsBefore = chatRepository.getSessionsCallCount;
        final activeDirectory = provider.projectProvider.currentDirectory;

        chatRepository.emitGlobalEvent(
          ChatEvent(
            type: 'session.updated',
            properties: <String, dynamic>{
              if (activeDirectory != null) 'directory': activeDirectory,
              'info': <String, dynamic>{
                'id': 'ses_1',
                'workspaceId': 'default',
                'title': 'Session 1 renamed',
                'time': <String, dynamic>{'created': 1000, 'updated': 2000},
              },
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(provider.sessions.first.title, 'Session 1 renamed');
        expect(chatRepository.getSessionsCallCount, sessionsBefore);
      },
    );

    test(
      'ignores conflicting session.updated events while rename is pending',
      () async {
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a'],
          ),
        );

        final renameCompleter = Completer<Either<Failure, ChatSession>>();
        chatRepository.updateSessionHandler = (_, sessionId, input, __) {
          return renameCompleter.future;
        };

        await provider.initializeProviders();
        await provider.loadSessions();
        final session = provider.sessions.first;
        final activeDirectory = provider.projectProvider.currentDirectory;

        final renameFuture = provider.renameSession(session, 'Local Rename');
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(provider.sessions.first.title, 'Local Rename');

        chatRepository.emitGlobalEvent(
          ChatEvent(
            type: 'session.updated',
            properties: <String, dynamic>{
              if (activeDirectory != null) 'directory': activeDirectory,
              'info': <String, dynamic>{
                'id': session.id,
                'workspaceId': session.workspaceId,
                'title': 'Remote Old Title',
                'time': <String, dynamic>{
                  'created': session.time.millisecondsSinceEpoch,
                  'updated': session.time.millisecondsSinceEpoch,
                },
              },
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(provider.sessions.first.title, 'Local Rename');

        final renamedSession = session.copyWith(title: 'Local Rename');
        renameCompleter.complete(Right(renamedSession));
        final ok = await renameFuture;
        await Future<void>.delayed(const Duration(milliseconds: 5));

        expect(ok, isTrue);
        expect(provider.sessions.first.title, 'Local Rename');
      },
    );

    test(
      'loads and responds to pending permission and question requests',
      () async {
        chatRepository.pendingPermissions = const <ChatPermissionRequest>[
          ChatPermissionRequest(
            id: 'perm_1',
            sessionId: 'ses_1',
            permission: 'edit',
            patterns: <String>['lib/**'],
            always: <String>[],
            metadata: <String, dynamic>{},
          ),
        ];
        chatRepository.pendingQuestions = const <ChatQuestionRequest>[
          ChatQuestionRequest(
            id: 'q_1',
            sessionId: 'ses_1',
            questions: <ChatQuestionInfo>[
              ChatQuestionInfo(
                question: 'Proceed?',
                header: 'Confirm',
                options: <ChatQuestionOption>[
                  ChatQuestionOption(label: 'Yes', description: 'continue'),
                ],
              ),
            ],
          ),
        ];
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a'],
          ),
        );

        await provider.initializeProviders();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        expect(provider.currentPermissionRequest?.id, 'perm_1');
        expect(provider.currentQuestionRequest?.id, 'q_1');

        await provider.respondPermissionRequest(
          requestId: 'perm_1',
          reply: 'once',
        );
        expect(chatRepository.lastPermissionRequestId, 'perm_1');
        expect(chatRepository.lastPermissionReply, 'once');

        await provider.submitQuestionAnswers(
          requestId: 'q_1',
          answers: const <List<String>>[
            <String>['Yes'],
          ],
        );
        expect(chatRepository.lastQuestionReplyRequestId, 'q_1');
        expect(chatRepository.lastQuestionAnswers, const <List<String>>[
          <String>['Yes'],
        ]);
      },
    );

    test(
      'rejectQuestionRequest removes pending question from provider state',
      () async {
        chatRepository.pendingQuestions = const <ChatQuestionRequest>[
          ChatQuestionRequest(
            id: 'q_reject_1',
            sessionId: 'ses_1',
            questions: <ChatQuestionInfo>[
              ChatQuestionInfo(
                question: 'Reject this?',
                header: 'Confirm',
                options: <ChatQuestionOption>[
                  ChatQuestionOption(label: 'Yes', description: 'Reject'),
                ],
              ),
            ],
          ),
        ];
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a'],
          ),
        );

        await provider.initializeProviders();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        expect(provider.currentQuestionRequest?.id, 'q_reject_1');

        await provider.rejectQuestionRequest(requestId: 'q_reject_1');

        expect(chatRepository.lastQuestionRejectRequestId, 'q_reject_1');
        expect(provider.currentQuestionRequest, isNull);
      },
    );

    test(
      'switches project context with isolated directory session state',
      () async {
        final scopedRepository = FakeChatRepository(
          sessions: <ChatSession>[
            ChatSession(
              id: 'ses_a',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              title: 'Session A',
            ),
          ],
        );
        final scopedLocal = InMemoryAppLocalDataSource()
          ..activeServerId = 'srv_test';
        final scopedProvider = ChatProvider(
          sendChatMessage: SendChatMessage(scopedRepository),
          getChatSessions: GetChatSessions(scopedRepository),
          createChatSession: CreateChatSession(scopedRepository),
          getChatMessages: GetChatMessages(scopedRepository),
          getChatMessage: GetChatMessage(scopedRepository),
          getAgents: GetAgents(appRepository),
          getProviders: GetProviders(appRepository),
          deleteChatSession: DeleteChatSession(scopedRepository),
          updateChatSession: UpdateChatSession(scopedRepository),
          shareChatSession: ShareChatSession(scopedRepository),
          unshareChatSession: UnshareChatSession(scopedRepository),
          forkChatSession: ForkChatSession(scopedRepository),
          getSessionStatus: GetSessionStatus(scopedRepository),
          getSessionChildren: GetSessionChildren(scopedRepository),
          getSessionTodo: GetSessionTodo(scopedRepository),
          getSessionDiff: GetSessionDiff(scopedRepository),
          watchChatEvents: WatchChatEvents(scopedRepository),
          watchGlobalChatEvents: WatchGlobalChatEvents(scopedRepository),
          listPendingPermissions: ListPendingPermissions(scopedRepository),
          replyPermission: ReplyPermission(scopedRepository),
          listPendingQuestions: ListPendingQuestions(scopedRepository),
          replyQuestion: ReplyQuestion(scopedRepository),
          rejectQuestion: RejectQuestion(scopedRepository),
          projectProvider: ProjectProvider(
            projectRepository: FakeProjectRepository(
              currentProject: Project(
                id: 'proj_a',
                name: 'Project A',
                path: '/repo/a',
                createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              ),
              projects: <Project>[
                Project(
                  id: 'proj_a',
                  name: 'Project A',
                  path: '/repo/a',
                  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                ),
                Project(
                  id: 'proj_b',
                  name: 'Project B',
                  path: '/repo/b',
                  createdAt: DateTime.fromMillisecondsSinceEpoch(1),
                ),
              ],
            ),
            localDataSource: scopedLocal,
          ),
          localDataSource: scopedLocal,
        );

        await scopedProvider.projectProvider.initializeProject();
        await scopedProvider.initializeProviders();
        await scopedProvider.loadSessions();
        expect(scopedRepository.lastGetSessionsDirectory, '/repo/a');
        expect(scopedProvider.sessions.first.id, 'ses_a');

        scopedRepository.sessions
          ..clear()
          ..add(
            ChatSession(
              id: 'ses_b',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(2000),
              title: 'Session B',
            ),
          );
        await scopedProvider.projectProvider.switchProject('proj_b');
        await scopedProvider.onProjectScopeChanged();
        expect(scopedRepository.lastGetSessionsDirectory, '/repo/b');
        expect(scopedProvider.sessions.first.id, 'ses_b');

        await scopedProvider.projectProvider.switchProject('proj_a');
        await scopedProvider.onProjectScopeChanged();
        expect(scopedProvider.sessions.first.id, 'ses_a');
      },
    );

    test(
      'switching project restores last session for each directory automatically',
      () async {
        final scopedRepository = FakeChatRepository(
          sessions: <ChatSession>[
            ChatSession(
              id: 'ses_a_old',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              title: 'Session A Old',
            ),
            ChatSession(
              id: 'ses_a_new',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(3000),
              title: 'Session A New',
            ),
          ],
        );
        final scopedLocal = InMemoryAppLocalDataSource()
          ..activeServerId = 'srv_test';
        final scopedProvider = ChatProvider(
          sendChatMessage: SendChatMessage(scopedRepository),
          getChatSessions: GetChatSessions(scopedRepository),
          createChatSession: CreateChatSession(scopedRepository),
          getChatMessages: GetChatMessages(scopedRepository),
          getChatMessage: GetChatMessage(scopedRepository),
          getAgents: GetAgents(appRepository),
          getProviders: GetProviders(appRepository),
          deleteChatSession: DeleteChatSession(scopedRepository),
          updateChatSession: UpdateChatSession(scopedRepository),
          shareChatSession: ShareChatSession(scopedRepository),
          unshareChatSession: UnshareChatSession(scopedRepository),
          forkChatSession: ForkChatSession(scopedRepository),
          getSessionStatus: GetSessionStatus(scopedRepository),
          getSessionChildren: GetSessionChildren(scopedRepository),
          getSessionTodo: GetSessionTodo(scopedRepository),
          getSessionDiff: GetSessionDiff(scopedRepository),
          watchChatEvents: WatchChatEvents(scopedRepository),
          watchGlobalChatEvents: WatchGlobalChatEvents(scopedRepository),
          listPendingPermissions: ListPendingPermissions(scopedRepository),
          replyPermission: ReplyPermission(scopedRepository),
          listPendingQuestions: ListPendingQuestions(scopedRepository),
          replyQuestion: ReplyQuestion(scopedRepository),
          rejectQuestion: RejectQuestion(scopedRepository),
          projectProvider: ProjectProvider(
            projectRepository: FakeProjectRepository(
              currentProject: Project(
                id: 'proj_a',
                name: 'Project A',
                path: '/repo/a',
                createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              ),
              projects: <Project>[
                Project(
                  id: 'proj_a',
                  name: 'Project A',
                  path: '/repo/a',
                  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                ),
                Project(
                  id: 'proj_b',
                  name: 'Project B',
                  path: '/repo/b',
                  createdAt: DateTime.fromMillisecondsSinceEpoch(1),
                ),
              ],
            ),
            localDataSource: scopedLocal,
          ),
          localDataSource: scopedLocal,
        );

        await scopedProvider.projectProvider.initializeProject();
        await scopedProvider.initializeProviders();
        await scopedProvider.loadSessions();

        expect(scopedProvider.currentSession?.id, 'ses_a_new');
        expect(
          scopedLocal.scopedStrings['current_session_id::srv_test::/repo/a'],
          'ses_a_new',
        );

        scopedRepository.sessions
          ..clear()
          ..addAll(<ChatSession>[
            ChatSession(
              id: 'ses_b_old',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(1500),
              title: 'Session B Old',
            ),
            ChatSession(
              id: 'ses_b_new',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(2500),
              title: 'Session B New',
            ),
          ]);
        await scopedProvider.projectProvider.switchProject('proj_b');
        await scopedProvider.onProjectScopeChanged();

        expect(scopedProvider.currentSession?.id, 'ses_b_new');
        expect(
          scopedLocal.scopedStrings['current_session_id::srv_test::/repo/b'],
          'ses_b_new',
        );

        final oldSessionB = scopedProvider.sessions
            .where((session) => session.id == 'ses_b_old')
            .first;
        await scopedProvider.selectSession(oldSessionB);
        expect(scopedProvider.currentSession?.id, 'ses_b_old');
        expect(
          scopedLocal.scopedStrings['current_session_id::srv_test::/repo/b'],
          'ses_b_old',
        );

        await scopedProvider.projectProvider.switchProject('proj_a');
        await scopedProvider.onProjectScopeChanged();
        expect(scopedProvider.currentSession?.id, 'ses_a_new');

        await scopedProvider.projectProvider.switchProject('proj_b');
        await scopedProvider.onProjectScopeChanged();
        expect(scopedProvider.currentSession?.id, 'ses_b_old');
      },
    );

    test(
      'filters mixed session list to active directory when server returns unscoped data',
      () async {
        final scopedRepository = FakeChatRepository(
          sessions: <ChatSession>[
            ChatSession(
              id: 'ses_a',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(3000),
              title: 'Session A',
              directory: '/repo/a',
            ),
            ChatSession(
              id: 'ses_b',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(2000),
              title: 'Session B',
              directory: '/repo/b',
            ),
            ChatSession(
              id: 'ses_unknown',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              title: 'Session Unknown',
            ),
          ],
        );

        final scopedLocal = InMemoryAppLocalDataSource()
          ..activeServerId = 'srv_test';
        final scopedProvider = ChatProvider(
          sendChatMessage: SendChatMessage(scopedRepository),
          getChatSessions: GetChatSessions(scopedRepository),
          createChatSession: CreateChatSession(scopedRepository),
          getChatMessages: GetChatMessages(scopedRepository),
          getChatMessage: GetChatMessage(scopedRepository),
          getAgents: GetAgents(appRepository),
          getProviders: GetProviders(appRepository),
          deleteChatSession: DeleteChatSession(scopedRepository),
          updateChatSession: UpdateChatSession(scopedRepository),
          shareChatSession: ShareChatSession(scopedRepository),
          unshareChatSession: UnshareChatSession(scopedRepository),
          forkChatSession: ForkChatSession(scopedRepository),
          getSessionStatus: GetSessionStatus(scopedRepository),
          getSessionChildren: GetSessionChildren(scopedRepository),
          getSessionTodo: GetSessionTodo(scopedRepository),
          getSessionDiff: GetSessionDiff(scopedRepository),
          watchChatEvents: WatchChatEvents(scopedRepository),
          watchGlobalChatEvents: WatchGlobalChatEvents(scopedRepository),
          listPendingPermissions: ListPendingPermissions(scopedRepository),
          replyPermission: ReplyPermission(scopedRepository),
          listPendingQuestions: ListPendingQuestions(scopedRepository),
          replyQuestion: ReplyQuestion(scopedRepository),
          rejectQuestion: RejectQuestion(scopedRepository),
          projectProvider: ProjectProvider(
            projectRepository: FakeProjectRepository(
              currentProject: Project(
                id: 'proj_a',
                name: 'Project A',
                path: '/repo/a',
                createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              ),
              projects: <Project>[
                Project(
                  id: 'proj_a',
                  name: 'Project A',
                  path: '/repo/a',
                  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                ),
                Project(
                  id: 'proj_b',
                  name: 'Project B',
                  path: '/repo/b',
                  createdAt: DateTime.fromMillisecondsSinceEpoch(1),
                ),
              ],
            ),
            localDataSource: scopedLocal,
          ),
          localDataSource: scopedLocal,
        );

        await scopedProvider.projectProvider.initializeProject();
        await scopedProvider.initializeProviders();
        await scopedProvider.loadSessions();

        expect(scopedRepository.lastGetSessionsDirectory, '/repo/a');
        expect(scopedProvider.sessions.map((item) => item.id), <String>[
          'ses_a',
        ]);

        await scopedProvider.projectProvider.switchProject('proj_b');
        await scopedProvider.onProjectScopeChanged();

        expect(scopedRepository.lastGetSessionsDirectory, '/repo/b');
        expect(scopedProvider.sessions.map((item) => item.id), <String>[
          'ses_b',
        ]);
      },
    );

    test(
      'global event marks non-active context dirty and reloads on return',
      () async {
        final scopedRepository = FakeChatRepository(
          sessions: <ChatSession>[
            ChatSession(
              id: 'ses_a_old',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              title: 'Session A Old',
            ),
          ],
        );
        final scopedLocal = InMemoryAppLocalDataSource()
          ..activeServerId = 'srv_test';
        final scopedProvider = ChatProvider(
          sendChatMessage: SendChatMessage(scopedRepository),
          getChatSessions: GetChatSessions(scopedRepository),
          createChatSession: CreateChatSession(scopedRepository),
          getChatMessages: GetChatMessages(scopedRepository),
          getChatMessage: GetChatMessage(scopedRepository),
          getAgents: GetAgents(appRepository),
          getProviders: GetProviders(appRepository),
          deleteChatSession: DeleteChatSession(scopedRepository),
          updateChatSession: UpdateChatSession(scopedRepository),
          shareChatSession: ShareChatSession(scopedRepository),
          unshareChatSession: UnshareChatSession(scopedRepository),
          forkChatSession: ForkChatSession(scopedRepository),
          getSessionStatus: GetSessionStatus(scopedRepository),
          getSessionChildren: GetSessionChildren(scopedRepository),
          getSessionTodo: GetSessionTodo(scopedRepository),
          getSessionDiff: GetSessionDiff(scopedRepository),
          watchChatEvents: WatchChatEvents(scopedRepository),
          watchGlobalChatEvents: WatchGlobalChatEvents(scopedRepository),
          listPendingPermissions: ListPendingPermissions(scopedRepository),
          replyPermission: ReplyPermission(scopedRepository),
          listPendingQuestions: ListPendingQuestions(scopedRepository),
          replyQuestion: ReplyQuestion(scopedRepository),
          rejectQuestion: RejectQuestion(scopedRepository),
          projectProvider: ProjectProvider(
            projectRepository: FakeProjectRepository(
              currentProject: Project(
                id: 'proj_a',
                name: 'Project A',
                path: '/repo/a',
                createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              ),
              projects: <Project>[
                Project(
                  id: 'proj_a',
                  name: 'Project A',
                  path: '/repo/a',
                  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                ),
                Project(
                  id: 'proj_b',
                  name: 'Project B',
                  path: '/repo/b',
                  createdAt: DateTime.fromMillisecondsSinceEpoch(1),
                ),
              ],
            ),
            localDataSource: scopedLocal,
          ),
          localDataSource: scopedLocal,
        );

        await scopedProvider.projectProvider.initializeProject();
        await scopedProvider.initializeProviders();
        await scopedProvider.loadSessions();
        expect(scopedProvider.sessions.first.id, 'ses_a_old');

        scopedRepository.sessions
          ..clear()
          ..add(
            ChatSession(
              id: 'ses_b',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(2000),
              title: 'Session B',
            ),
          );
        await scopedProvider.projectProvider.switchProject('proj_b');
        await scopedProvider.onProjectScopeChanged();
        expect(scopedProvider.sessions.first.id, 'ses_b');

        scopedRepository.emitGlobalEvent(
          const ChatEvent(
            type: 'session.updated',
            properties: <String, dynamic>{'directory': '/repo/a'},
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        scopedRepository.sessions
          ..clear()
          ..add(
            ChatSession(
              id: 'ses_a_new',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(3000),
              title: 'Session A New',
            ),
          );
        await scopedProvider.projectProvider.switchProject('proj_a');
        await scopedProvider.onProjectScopeChanged();

        expect(scopedProvider.sessions.first.id, 'ses_a_new');
      },
    );
  });
}

Model _model(
  String id, {
  Map<String, ModelVariant> variants = const <String, ModelVariant>{},
}) {
  return Model(
    id: id,
    name: id,
    releaseDate: '2025-01-01',
    attachment: false,
    reasoning: false,
    temperature: true,
    toolCall: false,
    cost: const ModelCost(input: 0.001, output: 0.002),
    limit: const ModelLimit(context: 1000, output: 100),
    options: const <String, dynamic>{},
    variants: variants,
  );
}

class _ThrowingPersistenceLocalDataSource extends InMemoryAppLocalDataSource {
  @override
  Future<void> saveSelectedProvider(
    String providerId, {
    String? serverId,
    String? scopeId,
  }) async {
    throw Exception('saveSelectedProvider failed');
  }

  @override
  Future<void> saveSelectedModel(
    String modelId, {
    String? serverId,
    String? scopeId,
  }) async {
    throw Exception('saveSelectedModel failed');
  }

  @override
  Future<void> saveRecentModelsJson(
    String recentModelsJson, {
    String? serverId,
    String? scopeId,
  }) async {
    throw Exception('saveRecentModelsJson failed');
  }

  @override
  Future<void> saveModelUsageCountsJson(
    String usageCountsJson, {
    String? serverId,
    String? scopeId,
  }) async {
    throw Exception('saveModelUsageCountsJson failed');
  }

  @override
  Future<void> saveSelectedVariantMap(
    String variantMapJson, {
    String? serverId,
    String? scopeId,
  }) async {
    throw Exception('saveSelectedVariantMap failed');
  }
}

class _FakeChatTitleGenerator implements ChatTitleGenerator {
  int callCount = 0;
  final List<List<ChatTitleGeneratorMessage>> payloads =
      <List<ChatTitleGeneratorMessage>>[];

  @override
  Future<String?> generateTitle(
    List<ChatTitleGeneratorMessage> messages, {
    int maxWords = 6,
  }) async {
    callCount += 1;
    payloads.add(List<ChatTitleGeneratorMessage>.from(messages));
    return 'Auto title $callCount';
  }
}

class _BlockingChatTitleGenerator implements ChatTitleGenerator {
  _BlockingChatTitleGenerator(this._completer);

  final Completer<String?> _completer;
  int callCount = 0;

  @override
  Future<String?> generateTitle(
    List<ChatTitleGeneratorMessage> messages, {
    int maxWords = 6,
  }) {
    callCount += 1;
    return _completer.future;
  }
}
