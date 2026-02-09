import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/data/models/chat_session_model.dart';
import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/domain/entities/provider.dart';
import 'package:codewalk/domain/usecases/create_chat_session.dart';
import 'package:codewalk/domain/usecases/delete_chat_session.dart';
import 'package:codewalk/domain/usecases/get_chat_messages.dart';
import 'package:codewalk/domain/usecases/get_chat_sessions.dart';
import 'package:codewalk/domain/usecases/get_providers.dart';
import 'package:codewalk/domain/usecases/send_chat_message.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/providers/project_provider.dart';

import '../../support/fakes.dart';

void main() {
  group('ChatProvider', () {
    late FakeChatRepository chatRepository;
    late FakeAppRepository appRepository;
    late InMemoryAppLocalDataSource localDataSource;
    late ChatProvider provider;

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

      provider = ChatProvider(
        sendChatMessage: SendChatMessage(chatRepository),
        getChatSessions: GetChatSessions(chatRepository),
        createChatSession: CreateChatSession(chatRepository),
        getChatMessages: GetChatMessages(chatRepository),
        getProviders: GetProviders(appRepository),
        deleteChatSession: DeleteChatSession(chatRepository),
        projectProvider: ProjectProvider(
          projectRepository: FakeProjectRepository(),
        ),
        localDataSource: localDataSource,
      );
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
