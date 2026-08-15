@Tags(<String>['slow'])
library;

import 'dart:async';
import 'dart:convert';

import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/data/models/chat_message_model.dart';
import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/domain/entities/provider.dart';
import 'package:codewalk/domain/entities/session.dart';
import 'package:codewalk/domain/usecases/abort_chat_session.dart';
import 'package:codewalk/domain/usecases/create_chat_session.dart';
import 'package:codewalk/domain/usecases/delete_chat_session.dart';
import 'package:codewalk/domain/usecases/fork_chat_session.dart';
import 'package:codewalk/domain/usecases/get_agents.dart';
import 'package:codewalk/domain/usecases/get_chat_message.dart';
import 'package:codewalk/domain/usecases/get_chat_messages.dart';
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
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/cellular_data_saver_service.dart';
import 'package:codewalk/presentation/services/chat_title_generator.dart';
import 'package:codewalk/presentation/services/event_feedback_dispatcher.dart';
import 'package:codewalk/presentation/services/notification_service.dart';
import 'package:codewalk/presentation/services/sound_service.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import 'chat_provider_test_support.dart';

void main() {
  group('ChatProvider - realtime', () {
    late FakeChatRepository chatRepository;
    late FakeAppRepository appRepository;
    late InMemoryAppLocalDataSource localDataSource;
    late ChatProvider provider;
    late SettingsProvider defaultSettingsProvider;

    ChatProvider buildProvider({
      DioClient? dioClient,
      Duration syncSignalStaleThreshold = const Duration(seconds: 20),
      Duration syncHealthCheckInterval = const Duration(seconds: 5),
      Duration abortSuppressionWindow = const Duration(milliseconds: 30),
      SettingsProvider? settingsProvider,
      CellularDataSaverService? cellularDataSaverService,
      EventFeedbackDispatcher? eventFeedbackDispatcher,
      ChatTitleGenerator? titleGenerator,
    }) {
      return buildChatProvider(
        chatRepository: chatRepository,
        appRepository: appRepository,
        localDataSource: localDataSource,
        defaultSettingsProvider: defaultSettingsProvider,
        dioClient: dioClient,
        syncSignalStaleThreshold: syncSignalStaleThreshold,
        syncHealthCheckInterval: syncHealthCheckInterval,
        abortSuppressionWindow: abortSuppressionWindow,
        settingsProvider: settingsProvider,
        cellularDataSaverService: cellularDataSaverService,
        eventFeedbackDispatcher: eventFeedbackDispatcher,
        titleGenerator: titleGenerator,
      );
    }

    setUp(() async {
      final fixtures = await buildDefaultTestFixtures();
      chatRepository = fixtures.chatRepository;
      appRepository = fixtures.appRepository;
      localDataSource = fixtures.localDataSource;
      defaultSettingsProvider = fixtures.defaultSettingsProvider;
      provider = buildProvider();
    });

    Future<void> settleUntil(
      bool Function() predicate, {
      int maxTicks = 40,
      String? reason,
    }) async {
      for (var tick = 0; tick < maxTicks; tick += 1) {
        if (predicate()) {
          return;
        }
        await pumpEventQueue();
      }
      fail(reason ?? 'Condition was not met before event queue settled.');
    }

    Future<void> emitServerConnected() async {
      await settleUntil(
        () => provider.debugHasRealtimeEventSubscription,
        reason: 'Expected realtime subscription before server.connected.',
      );
      await pumpEventQueue();
      for (var attempt = 0; attempt < 5; attempt += 1) {
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'server.connected',
            properties: <String, dynamic>{},
          ),
        );
        for (var tick = 0; tick < 16; tick += 1) {
          if (provider.syncState == ChatSyncState.connected) {
            return;
          }
          await pumpEventQueue();
        }
      }
      fail('Expected server.connected signal to mark connected.');
    }

    Future<void> initializeRealtimeProvider() async {
      await provider.projectProvider.initializeProject();
      await provider.initializeProviders();
      await provider.loadSessions();
      await provider.selectSession(
        provider.sessions.firstWhere((session) => session.id == 'ses_1'),
      );
      await provider.refresh();
      await settleUntil(
        () => provider.debugHasRealtimeEventSubscription,
        reason: 'Expected realtime subscription before compatibility event.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    test('dispose cancels pending title waiters', () {
      final titleGenerator = _FakeChatTitleGenerator();
      provider = buildProvider(titleGenerator: titleGenerator);

      provider.dispose();

      expect(titleGenerator.cancelPendingWaitersCallCount, 1);
    });

    test('project context switch cancels pending title waiters', () async {
      final titleGenerator = _FakeChatTitleGenerator();
      provider = buildProvider(titleGenerator: titleGenerator);

      await provider.onProjectScopeChanged(waitForRevalidation: false);

      expect(titleGenerator.cancelPendingWaitersCallCount, 1);
    });

    group('OpenCode v1.18.3 compatibility', () {
      for (final eventType in const <String>[
        'session.next.revert.staged',
        'session.next.revert.cleared',
        'session.next.revert.committed',
      ]) {
        test('$eventType schedules authoritative reconciliation', () async {
          await initializeRealtimeProvider();
          chatRepository.getSessionsCallCount = 0;
          chatRepository.getMessagesCallCount = 0;
          chatRepository.getSessionStatusCallCount = 0;

          chatRepository.emitEvent(
            ChatEvent(
              type: eventType,
              properties: <String, dynamic>{
                'sessionID': 'ses_1',
                'timestamp': 1000,
                if (eventType == 'session.next.revert.staged')
                  'revert': <String, dynamic>{'messageID': 'msg_user_2'},
                if (eventType == 'session.next.revert.committed')
                  'messageID': 'msg_user_2',
              },
            ),
          );

          await Future<void>.delayed(const Duration(milliseconds: 400));

          expect(chatRepository.getSessionsCallCount, greaterThan(0));
          expect(chatRepository.getMessagesCallCount, greaterThan(0));
          expect(chatRepository.getSessionStatusCallCount, greaterThan(0));
        });
      }

      test(
        'active revert refresh adopts server boundary without deleting raw messages',
        () async {
          chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
            UserMessage(
              id: 'msg_user_1',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[],
            ),
            AssistantMessage(
              id: 'msg_assistant_1',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(1100),
              parts: const <MessagePart>[],
            ),
            UserMessage(
              id: 'msg_user_2',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(1200),
              parts: const <MessagePart>[],
            ),
          ];
          await initializeRealtimeProvider();
          final messagesStarted = Completer<void>();
          final releaseMessages = Completer<void>();
          addTearDown(() {
            if (!releaseMessages.isCompleted) {
              releaseMessages.complete();
            }
          });
          chatRepository.getMessagesDelay = () async {
            if (!messagesStarted.isCompleted) {
              messagesStarted.complete();
            }
            await releaseMessages.future;
          };
          chatRepository.getMessagesCallCount = 0;
          final preexistingRefresh = provider.refreshActiveSessionView(
            reason: 'test-preexisting-refresh',
          );
          await messagesStarted.future.timeout(const Duration(seconds: 2));
          chatRepository.sessions[0] = chatRepository.sessions[0].copyWith(
            revert: const SessionRevert(messageId: 'msg_user_2'),
          );
          chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
            UserMessage(
              id: 'msg_user_1',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[],
            ),
            AssistantMessage(
              id: 'msg_assistant_1',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(1100),
              parts: const <MessagePart>[],
            ),
            AssistantMessage(
              id: 'msg_server_reconciled',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(1150),
              parts: const <MessagePart>[],
            ),
            UserMessage(
              id: 'msg_user_2',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(1200),
              parts: const <MessagePart>[],
            ),
          ];

          chatRepository.emitEvent(
            const ChatEvent(
              type: 'session.next.revert.staged',
              properties: <String, dynamic>{
                'sessionID': 'ses_1',
                'timestamp': 1000,
                'revert': <String, dynamic>{'messageID': 'msg_user_2'},
              },
            ),
          );

          await Future<void>.delayed(const Duration(milliseconds: 400));
          await settleUntil(
            () => provider.currentSessionRevert?.messageId == 'msg_user_2',
            maxTicks: 80,
            reason: 'Expected refreshed session to expose the revert boundary.',
          );
          releaseMessages.complete();
          await preexistingRefresh;
          await settleUntil(
            () => provider.rawMessages.any(
              (message) => message.id == 'msg_server_reconciled',
            ),
            maxTicks: 80,
            reason: 'Expected messages fetched after the revert boundary.',
          );

          expect(chatRepository.getMessagesCallCount, 2);
          expect(provider.rawMessages, hasLength(4));
          expect(provider.messages.map((message) => message.id), <String>[
            'msg_user_1',
            'msg_assistant_1',
            'msg_server_reconciled',
          ]);
        },
      );

      test(
        'known inactive-session revert does not refresh visible messages',
        () async {
          chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
            UserMessage(
              id: 'msg_visible_existing',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[],
            ),
          ];
          chatRepository.sessions.add(
            ChatSession(
              id: 'ses_2',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(2000),
              title: 'Session 2',
            ),
          );
          await initializeRealtimeProvider();
          chatRepository.getSessionsCallCount = 0;
          chatRepository.getMessagesCallCount = 0;
          chatRepository.getSessionStatusCallCount = 0;

          chatRepository.emitEvent(
            const ChatEvent(
              type: 'session.next.revert.cleared',
              properties: <String, dynamic>{
                'sessionID': 'ses_2',
                'timestamp': 1000,
              },
            ),
          );

          await Future<void>.delayed(const Duration(milliseconds: 400));

          expect(chatRepository.getSessionsCallCount, greaterThan(0));
          expect(chatRepository.getSessionStatusCallCount, greaterThan(0));
          expect(chatRepository.getMessagesCallCount, 0);
        },
      );

      test(
        'overlapping revert reconciliations serialize message refreshes',
        () async {
          chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
            UserMessage(
              id: 'msg_serial_existing',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[],
            ),
          ];
          await initializeRealtimeProvider();
          final firstRequestStarted = Completer<void>();
          final releaseFirstRequest = Completer<void>();
          addTearDown(() {
            if (!releaseFirstRequest.isCompleted) {
              releaseFirstRequest.complete();
            }
          });
          var requestOrdinal = 0;
          var activeRequests = 0;
          var maxActiveRequests = 0;
          chatRepository.getMessagesDelay = () async {
            requestOrdinal += 1;
            activeRequests += 1;
            if (activeRequests > maxActiveRequests) {
              maxActiveRequests = activeRequests;
            }
            try {
              if (requestOrdinal == 1) {
                firstRequestStarted.complete();
                await releaseFirstRequest.future;
              } else {
                await Future<void>.delayed(const Duration(milliseconds: 40));
              }
            } finally {
              activeRequests -= 1;
            }
          };
          chatRepository.getMessagesCallCount = 0;
          final preexistingRefresh = provider.refreshActiveSessionView(
            reason: 'test-overlapping-revert-refresh',
          );
          await firstRequestStarted.future.timeout(const Duration(seconds: 2));
          chatRepository.sessions[0] = chatRepository.sessions[0].copyWith(
            revert: const SessionRevert(messageId: 'msg_serial_existing'),
          );

          chatRepository.emitEvent(
            const ChatEvent(
              type: 'session.next.revert.staged',
              properties: <String, dynamic>{
                'sessionID': 'ses_1',
                'timestamp': 1000,
                'revert': <String, dynamic>{'messageID': 'msg_serial_existing'},
              },
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 400));
          await settleUntil(
            () =>
                provider.currentSessionRevert?.messageId ==
                'msg_serial_existing',
            reason: 'Expected the first reconciliation to update metadata.',
          );

          chatRepository.emitEvent(
            const ChatEvent(
              type: 'session.next.revert.committed',
              properties: <String, dynamic>{
                'sessionID': 'ses_1',
                'timestamp': 2000,
                'messageID': 'msg_serial_existing',
              },
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 400));
          releaseFirstRequest.complete();
          await preexistingRefresh;
          await Future<void>.delayed(const Duration(milliseconds: 250));

          expect(chatRepository.getMessagesCallCount, 3);
          expect(maxActiveRequests, 1);
        },
      );

      test(
        'revert without a session id safely refreshes visible messages',
        () async {
          await initializeRealtimeProvider();
          chatRepository.getMessagesCallCount = 0;

          chatRepository.emitEvent(
            const ChatEvent(
              type: 'session.next.revert.cleared',
              properties: <String, dynamic>{'timestamp': 1000},
            ),
          );

          await Future<void>.delayed(const Duration(milliseconds: 400));

          expect(chatRepository.getMessagesCallCount, greaterThan(0));
        },
      );

      test(
        'aggressive data saver reconciles active revert from session stream',
        () async {
          chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
            UserMessage(
              id: 'msg_user_1',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[],
            ),
            UserMessage(
              id: 'msg_user_2',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(1100),
              parts: const <MessagePart>[],
            ),
          ];
          final dataSaverService = CellularDataSaverService.disabled()
            ..debugSetDataSaverLevel(DataSaverLevel.aggressive)
            ..debugSetTransport(DataSaverTransport.cellular);
          addTearDown(dataSaverService.dispose);
          provider = buildProvider(cellularDataSaverService: dataSaverService);
          await initializeRealtimeProvider();
          expect(provider.debugHasGlobalEventSubscription, isFalse);
          chatRepository.getSessionsCallCount = 0;
          chatRepository.getMessagesCallCount = 0;
          chatRepository.getSessionStatusCallCount = 0;
          chatRepository.sessions[0] = chatRepository.sessions[0].copyWith(
            revert: const SessionRevert(messageId: 'msg_user_2'),
          );

          chatRepository.emitEvent(
            const ChatEvent(
              type: 'session.next.revert.committed',
              properties: <String, dynamic>{
                'sessionID': 'ses_1',
                'timestamp': 1000,
                'messageID': 'msg_user_2',
              },
            ),
          );

          await Future<void>.delayed(const Duration(milliseconds: 400));
          await settleUntil(
            () => provider.currentSessionRevert?.messageId == 'msg_user_2',
            reason: 'Expected aggressive mode to refresh revert metadata.',
          );

          expect(chatRepository.getMessagesCallCount, 1);
          expect(chatRepository.getSessionsCallCount, 1);
          expect(chatRepository.getSessionStatusCallCount, 0);
          expect(provider.messages.map((message) => message.id), <String>[
            'msg_user_1',
          ]);
        },
      );

      test(
        'duplicate revert across streams triggers one reconciliation',
        () async {
          chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
            UserMessage(
              id: 'msg_dedup_existing',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[],
            ),
          ];
          await initializeRealtimeProvider();
          await settleUntil(
            () => provider.debugHasGlobalEventSubscription,
            reason: 'Expected global subscription before deduplication test.',
          );
          chatRepository.getSessionsCallCount = 0;
          chatRepository.getMessagesCallCount = 0;
          chatRepository.getSessionStatusCallCount = 0;
          const sessionEvent = ChatEvent(
            type: 'session.next.revert.staged',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'timestamp': 1000,
              'revert': <String, dynamic>{'messageID': 'msg_user_2'},
            },
          );
          const globalEvent = ChatEvent(
            type: 'session.next.revert.staged',
            properties: <String, dynamic>{
              'directory': '/tmp',
              'project': 'project-id',
              'workspace': 'workspace-id',
              'sessionID': 'ses_1',
              'timestamp': 1000,
              'revert': <String, dynamic>{'messageID': 'msg_user_2'},
            },
          );

          chatRepository.emitEvent(sessionEvent);
          chatRepository.emitGlobalEvent(globalEvent);

          await Future<void>.delayed(const Duration(milliseconds: 400));

          expect(chatRepository.getSessionsCallCount, 1);
          expect(chatRepository.getMessagesCallCount, 1);
          expect(chatRepository.getSessionStatusCallCount, 1);
        },
      );

      test(
        'catalog.updated coalesces provider refresh and updates models',
        () async {
          await initializeRealtimeProvider();
          await settleUntil(
            () => provider.debugHasGlobalEventSubscription,
            reason: 'Expected global subscription before catalog event.',
          );
          final releaseRefresh = Completer<void>();
          appRepository.getProvidersDelay = () => releaseRefresh.future;
          appRepository.providersResult = Right(
            ProvidersResponse(
              providers: <Provider>[
                Provider(
                  id: 'provider_a',
                  name: 'Provider A',
                  env: const <String>[],
                  models: <String, Model>{'model_b': testModel('model_b')},
                ),
              ],
              defaultModels: const <String, String>{'provider_a': 'model_b'},
              connected: const <String>['provider_a'],
            ),
          );
          final callsBefore = appRepository.getProvidersCallCount;

          for (var index = 0; index < 3; index += 1) {
            chatRepository.emitGlobalEvent(
              const ChatEvent(
                type: 'catalog.updated',
                properties: <String, dynamic>{},
              ),
            );
          }
          await settleUntil(
            () => appRepository.getProvidersCallCount == callsBefore + 1,
            reason: 'Expected one in-flight provider refresh.',
          );
          expect(provider.providers.single.models, contains('model_a'));

          releaseRefresh.complete();
          await settleUntil(
            () => provider.providers.single.models.containsKey('model_b'),
            maxTicks: 80,
            reason: 'Expected catalog event to publish refreshed models.',
          );

          expect(appRepository.getProvidersCallCount, callsBefore + 1);
        },
      );

      test('catalog refresh failure preserves the visible catalog', () async {
        await initializeRealtimeProvider();
        await settleUntil(
          () => provider.debugHasGlobalEventSubscription,
          reason: 'Expected global subscription before catalog event.',
        );
        final providersBefore = List<Provider>.from(provider.providers);
        appRepository.providersResult = const Left(
          ServerFailure('catalog refresh failed'),
        );
        final callsBefore = appRepository.getProvidersCallCount;

        chatRepository.emitGlobalEvent(
          const ChatEvent(
            type: 'catalog.updated',
            properties: <String, dynamic>{},
          ),
        );
        await settleUntil(
          () => appRepository.getProvidersCallCount == callsBefore + 1,
          reason: 'Expected catalog refresh attempt.',
        );
        await settleUntil(
          () => !provider.isProvidersRefreshInProgress,
          reason: 'Expected failed catalog refresh to settle.',
        );

        expect(provider.providers, providersBefore);
        expect(provider.providers.single.models, contains('model_a'));
      });
    });

    test(
      'aggressive data saver keeps burst realtime and pauses idle streams',
      () async {
        final dataSaverService = CellularDataSaverService.disabled()
          ..debugSetDataSaverLevel(DataSaverLevel.aggressive)
          ..debugSetTransport(DataSaverTransport.cellular);
        addTearDown(dataSaverService.dispose);
        provider = buildProvider(cellularDataSaverService: dataSaverService);

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(
          provider.sessions.firstWhere((session) => session.id == 'ses_1'),
        );
        await provider.refresh();
        for (var tick = 0; tick < 20; tick += 1) {
          if (provider.debugHasRealtimeEventSubscription) {
            break;
          }
          await pumpEventQueue();
        }
        chatRepository.emitEvent(
          const ChatEvent(type: 'test.signal', properties: <String, dynamic>{}),
        );
        await pumpEventQueue();

        expect(provider.debugHasRealtimeEventSubscription, isTrue);
        expect(provider.debugHasGlobalEventSubscription, isFalse);
        expect(provider.syncState, ChatSyncState.connected);

        dataSaverService.debugSetDataSaverLevel(DataSaverLevel.standard);
        await provider.refresh();
        await settleUntil(
          () => provider.debugHasGlobalEventSubscription,
          reason:
              'Expected standard data saver to restore global realtime while foreground realtime stays active.',
        );

        expect(provider.debugHasRealtimeEventSubscription, isTrue);
        expect(provider.debugHasGlobalEventSubscription, isTrue);

        dataSaverService.debugSetDataSaverLevel(DataSaverLevel.aggressive);
        await settleUntil(
          () =>
              !provider.debugHasRealtimeEventSubscription &&
              !provider.debugHasGlobalEventSubscription,
          reason:
              'Expected aggressive idle data saver to pause all realtime streams.',
        );

        expect(provider.debugHasRealtimeEventSubscription, isFalse);
        expect(provider.debugHasGlobalEventSubscription, isFalse);

        dataSaverService.debugSetDataSaverLevel(DataSaverLevel.off);
        await settleUntil(
          () => provider.debugHasGlobalEventSubscription,
          reason:
              'Expected disabling aggressive data saver to restore global realtime.',
        );

        expect(provider.debugHasRealtimeEventSubscription, isTrue);
        expect(provider.debugHasGlobalEventSubscription, isTrue);
      },
    );

    test(
      'aggressive foreground resume still loads active session pending interactions',
      () async {
        final dataSaverService = CellularDataSaverService.disabled()
          ..debugSetDataSaverLevel(DataSaverLevel.aggressive)
          ..debugSetTransport(DataSaverTransport.cellular);
        addTearDown(dataSaverService.dispose);
        provider = buildProvider(cellularDataSaverService: dataSaverService);

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(
          provider.sessions.firstWhere((session) => session.id == 'ses_1'),
        );
        chatRepository.pendingPermissions = const <ChatPermissionRequest>[
          ChatPermissionRequest(
            id: 'perm_aggressive_resume',
            sessionId: 'ses_1',
            permission: 'bash',
            patterns: <String>['git status'],
            always: <String>[],
            metadata: <String, dynamic>{},
          ),
        ];

        await provider.setForegroundActive(false);
        await provider.setForegroundActive(true);
        await settleUntil(
          () => provider.currentSessionPermissions.isNotEmpty,
          reason:
              'Expected aggressive foreground sync to load active pending permission.',
        );

        expect(
          provider.currentSessionPermissions.single.id,
          'perm_aggressive_resume',
        );
      },
    );

    test(
      'aggressive data saver stops realtime while chat route is hidden',
      () async {
        final dataSaverService = CellularDataSaverService.disabled()
          ..debugSetDataSaverLevel(DataSaverLevel.aggressive)
          ..debugSetTransport(DataSaverTransport.cellular);
        addTearDown(dataSaverService.dispose);
        provider = buildProvider(cellularDataSaverService: dataSaverService);

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.refresh();
        await settleUntil(
          () => provider.debugHasRealtimeEventSubscription,
          reason:
              'Expected aggressive visible session burst to start realtime.',
        );
        expect(provider.debugHasGlobalEventSubscription, isFalse);

        provider.setChatRouteActive(false);
        await settleUntil(
          () =>
              !provider.debugHasRealtimeEventSubscription &&
              !provider.debugHasGlobalEventSubscription,
          reason:
              'Expected aggressive data saver to stop realtime off the chat route.',
        );

        provider.setChatRouteActive(true);
        await settleUntil(
          () =>
              provider.debugHasRealtimeEventSubscription &&
              !provider.debugHasGlobalEventSubscription,
          reason:
              'Expected returning to chat to restart only the local event stream.',
        );
      },
    );

    test(
      'aggressive foreground sync filters pending interactions to active session',
      () async {
        final dataSaverService = CellularDataSaverService.disabled()
          ..debugSetDataSaverLevel(DataSaverLevel.aggressive)
          ..debugSetTransport(DataSaverTransport.cellular);
        addTearDown(dataSaverService.dispose);
        final dioClient = RecordingDioClient();
        provider = buildProvider(
          dioClient: dioClient,
          cellularDataSaverService: dataSaverService,
        );
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_2',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(2000),
            title: 'Session 2',
          ),
        );
        chatRepository.messagesBySession['ses_2'] = <ChatMessage>[];

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(
          provider.sessions.firstWhere((session) => session.id == 'ses_1'),
        );
        await settleUntil(
          () => chatRepository.getSessionStatusCallCount > 0,
          reason: 'Expected initial session insights to settle before reset.',
        );
        await pumpEventQueue();
        await pumpEventQueue();
        chatRepository.getSessionsCallCount = 0;
        chatRepository.getMessagesCallCount = 0;
        chatRepository.getSessionStatusCallCount = 0;
        dioClient.getQueries.clear();
        chatRepository.pendingPermissions = const <ChatPermissionRequest>[
          ChatPermissionRequest(
            id: 'perm_visible',
            sessionId: 'ses_1',
            permission: 'bash',
            patterns: <String>['git status'],
            always: <String>[],
            metadata: <String, dynamic>{},
          ),
          ChatPermissionRequest(
            id: 'perm_inactive',
            sessionId: 'ses_2',
            permission: 'bash',
            patterns: <String>['git diff'],
            always: <String>[],
            metadata: <String, dynamic>{},
          ),
        ];
        chatRepository.pendingQuestions = const <ChatQuestionRequest>[
          ChatQuestionRequest(
            id: 'question_visible',
            sessionId: 'ses_1',
            questions: <ChatQuestionInfo>[
              ChatQuestionInfo(
                question: 'Proceed?',
                header: 'Confirm',
                options: <ChatQuestionOption>[
                  ChatQuestionOption(label: 'Yes', description: 'Continue'),
                ],
              ),
            ],
          ),
          ChatQuestionRequest(
            id: 'question_inactive',
            sessionId: 'ses_2',
            questions: <ChatQuestionInfo>[
              ChatQuestionInfo(
                question: 'Proceed elsewhere?',
                header: 'Other',
                options: <ChatQuestionOption>[
                  ChatQuestionOption(label: 'No', description: 'Skip'),
                ],
              ),
            ],
          ),
        ];

        await provider.setForegroundActive(false);
        await provider.setForegroundActive(true);
        await settleUntil(
          () =>
              provider.currentSessionPermissions.length == 1 &&
              provider.currentSessionQuestions.length == 1,
          reason:
              'Expected aggressive foreground sync to keep only visible interactions.',
        );

        expect(provider.currentSessionPermissions.single.id, 'perm_visible');
        expect(provider.currentSessionQuestions.single.id, 'question_visible');
        expect(chatRepository.getMessagesCallCount, greaterThan(0));
        expect(chatRepository.getSessionsCallCount, 0);
        expect(chatRepository.getSessionStatusCallCount, 0);
        expect(dioClient.getQueries, isEmpty);

        final inactiveSession = provider.sessions.firstWhere(
          (session) => session.id == 'ses_2',
        );
        await provider.selectSession(inactiveSession);
        await settleUntil(
          () =>
              provider.currentSessionPermissions.singleOrNull?.id ==
                  'perm_inactive' &&
              provider.currentSessionQuestions.singleOrNull?.id ==
                  'question_inactive',
          reason:
              'Expected manual session selection to load that session interactions immediately.',
        );
      },
    );

    test('aggressive data saver suppresses inactive session events', () async {
      final dataSaverService = CellularDataSaverService.disabled()
        ..debugSetDataSaverLevel(DataSaverLevel.aggressive)
        ..debugSetTransport(DataSaverTransport.cellular);
      addTearDown(dataSaverService.dispose);
      provider = buildProvider(cellularDataSaverService: dataSaverService);

      await provider.projectProvider.initializeProject();
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);
      await provider.refresh();
      await settleUntil(
        () => provider.debugHasRealtimeEventSubscription,
        reason: 'Expected aggressive visible session burst to start realtime.',
      );

      chatRepository.emitEvent(
        const ChatEvent(
          type: 'session.status',
          properties: <String, dynamic>{
            'sessionID': 'ses_2',
            'status': <String, dynamic>{'type': 'busy'},
          },
        ),
      );
      chatRepository.emitEvent(
        const ChatEvent(
          type: 'permission.asked',
          properties: <String, dynamic>{
            'id': 'perm_inactive_event',
            'sessionID': 'ses_2',
            'permission': 'bash',
            'patterns': <String>['git log'],
            'always': <String>[],
            'metadata': <String, dynamic>{},
          },
        ),
      );
      await pumpEventQueue();

      expect(provider.sessionStatusById['ses_2'], isNull);
      expect(provider.currentSessionPermissions, isEmpty);
    });

    test(
      'data saver off applies active part deltas without session id',
      () async {
        final dataSaverService = CellularDataSaverService.disabled();
        addTearDown(dataSaverService.dispose);
        provider = buildProvider(cellularDataSaverService: dataSaverService);
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          AssistantMessage(
            id: 'msg_data_saver_off_delta',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_data_saver_off_delta',
                messageId: 'msg_data_saver_off_delta',
                sessionId: 'ses_1',
                text: 'Hel',
              ),
            ],
          ),
        ];

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.refresh();
        await settleUntil(
          () => provider.debugHasRealtimeEventSubscription,
          reason: 'Expected realtime subscription with data saver disabled.',
        );

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'message.part.delta',
            properties: <String, dynamic>{
              'messageId': 'msg_data_saver_off_delta',
              'partID': 'prt_data_saver_off_delta',
              'field': 'text',
              'delta': 'lo',
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        final message = provider.messages.single as AssistantMessage;
        expect((message.parts.single as TextPart).text, 'Hello');
      },
    );

    test(
      'global distinct part delta is not deduped after session stream delta',
      () async {
        final dataSaverService = CellularDataSaverService.disabled();
        addTearDown(dataSaverService.dispose);
        provider = buildProvider(cellularDataSaverService: dataSaverService);
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          AssistantMessage(
            id: 'msg_cross_stream_delta',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_cross_stream_delta',
                messageId: 'msg_cross_stream_delta',
                sessionId: 'ses_1',
                text: 'He',
              ),
            ],
          ),
        ];

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.refresh();
        await settleUntil(
          () =>
              provider.debugHasRealtimeEventSubscription &&
              provider.debugHasGlobalEventSubscription,
          reason:
              'Expected both session and global streams before cross-stream dedupe regression.',
        );

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'message.part.delta',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'messageID': 'msg_cross_stream_delta',
              'partID': 'prt_cross_stream_delta',
              'field': 'text',
              'delta': 'l',
            },
          ),
        );
        await settleUntil(
          () =>
              ((provider.messages.single as AssistantMessage).parts.single
                      as TextPart)
                  .text ==
              'Hel',
          reason: 'Expected session stream delta to apply first.',
        );

        chatRepository.emitGlobalEvent(
          const ChatEvent(
            type: 'message.part.delta',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'messageID': 'msg_cross_stream_delta',
              'partID': 'prt_cross_stream_delta',
              'field': 'text',
              'delta': 'lo',
            },
          ),
        );
        await settleUntil(
          () =>
              ((provider.messages.single as AssistantMessage).parts.single
                      as TextPart)
                  .text ==
              'Hello',
          reason:
              'Expected distinct global delta with same message/part ids to apply.',
        );
      },
    );

    test(
      'session stream skips exact duplicate after global message update',
      () async {
        final dataSaverService = CellularDataSaverService.disabled();
        addTearDown(dataSaverService.dispose);
        provider = buildProvider(cellularDataSaverService: dataSaverService);
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          AssistantMessage(
            id: 'msg_global_first_duplicate',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            completedTime: DateTime.fromMillisecondsSinceEpoch(1200),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_global_first_duplicate',
                messageId: 'msg_global_first_duplicate',
                sessionId: 'ses_1',
                text: 'Already fetched',
              ),
            ],
          ),
        ];

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.refresh();
        await settleUntil(
          () =>
              provider.debugHasRealtimeEventSubscription &&
              provider.debugHasGlobalEventSubscription,
          reason:
              'Expected both session and global streams before exact duplicate dedupe regression.',
        );
        chatRepository.getMessageCallCount = 0;

        const event = ChatEvent(
          type: 'message.updated',
          properties: <String, dynamic>{
            'info': <String, dynamic>{
              'id': 'msg_global_first_duplicate',
              'sessionID': 'ses_1',
            },
          },
        );
        chatRepository.emitGlobalEvent(event);
        await settleUntil(
          () => chatRepository.getMessageCallCount == 1,
          reason: 'Expected global stream update to fetch the message once.',
        );

        chatRepository.emitEvent(event);
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(chatRepository.getMessageCallCount, 1);
      },
    );

    test(
      'stale fallback does not resurrect an explicitly removed message',
      () async {
        final removedMessage = AssistantMessage(
          id: 'msg_removed_fallback',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(1200),
          parts: const <MessagePart>[
            TextPart(
              id: 'prt_removed_fallback',
              messageId: 'msg_removed_fallback',
              sessionId: 'ses_1',
              text: 'Removed answer',
            ),
          ],
        );
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          removedMessage,
        ];

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.refresh();
        expect(provider.messages.single.id, removedMessage.id);

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'message.removed',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'messageID': 'msg_removed_fallback',
            },
          ),
        );
        await settleUntil(
          () => provider.messages.isEmpty,
          reason: 'Expected explicit removal to clear the visible message.',
        );

        chatRepository.getMessageCallCount = 0;
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          removedMessage,
        ];
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'message.updated',
            properties: <String, dynamic>{
              'info': <String, dynamic>{
                'id': 'msg_removed_fallback',
                'sessionID': 'ses_1',
              },
            },
          ),
        );
        await settleUntil(
          () => chatRepository.getMessageCallCount == 1,
          reason: 'Expected stale update to attempt one fallback fetch.',
        );

        expect(provider.messages, isEmpty);
      },
    );

    test('stale fallback preserves explicit part removal', () async {
      final messageWithRemovedPart = AssistantMessage(
        id: 'msg_removed_part_fallback',
        sessionId: 'ses_1',
        time: DateTime.fromMillisecondsSinceEpoch(1000),
        completedTime: DateTime.fromMillisecondsSinceEpoch(1200),
        parts: const <MessagePart>[
          TextPart(
            id: 'prt_kept_after_part_removal',
            messageId: 'msg_removed_part_fallback',
            sessionId: 'ses_1',
            text: 'Kept text',
          ),
          TextPart(
            id: 'prt_removed_part_fallback',
            messageId: 'msg_removed_part_fallback',
            sessionId: 'ses_1',
            text: 'Removed stale text',
          ),
        ],
      );
      chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
        messageWithRemovedPart,
      ];

      await provider.projectProvider.initializeProject();
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);
      await provider.refresh();

      chatRepository.emitEvent(
        const ChatEvent(
          type: 'message.part.removed',
          properties: <String, dynamic>{
            'sessionID': 'ses_1',
            'messageID': 'msg_removed_part_fallback',
            'partID': 'prt_removed_part_fallback',
          },
        ),
      );
      await settleUntil(
        () => (provider.messages.single.parts)
            .where((part) => part.id == 'prt_removed_part_fallback')
            .isEmpty,
        reason: 'Expected explicit part removal to update the visible message.',
      );

      chatRepository.getMessageCallCount = 0;
      chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
        messageWithRemovedPart,
      ];
      chatRepository.emitEvent(
        const ChatEvent(
          type: 'message.updated',
          properties: <String, dynamic>{
            'info': <String, dynamic>{
              'id': 'msg_removed_part_fallback',
              'sessionID': 'ses_1',
            },
          },
        ),
      );
      await settleUntil(
        () => chatRepository.getMessageCallCount == 1,
        reason: 'Expected stale part update to attempt one fallback fetch.',
      );

      final refreshed = provider.messages.single as AssistantMessage;
      expect(
        refreshed.parts.map((part) => part.id),
        isNot(contains('prt_removed_part_fallback')),
      );
    });

    test(
      'aggressive data saver applies active part deltas without session id',
      () async {
        final dataSaverService = CellularDataSaverService.disabled()
          ..debugSetDataSaverLevel(DataSaverLevel.aggressive)
          ..debugSetTransport(DataSaverTransport.cellular);
        addTearDown(dataSaverService.dispose);
        provider = buildProvider(cellularDataSaverService: dataSaverService);
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          AssistantMessage(
            id: 'msg_active_delta',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_active_delta',
                messageId: 'msg_active_delta',
                sessionId: 'ses_1',
                text: 'Hel',
              ),
            ],
          ),
        ];

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.refresh();
        await settleUntil(
          () => provider.debugHasRealtimeEventSubscription,
          reason:
              'Expected aggressive visible session burst to start realtime.',
        );

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'message.part.delta',
            properties: <String, dynamic>{
              'messageId': 'msg_active_delta',
              'partID': 'prt_active_delta',
              'field': 'text',
              'delta': 'lo',
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        final message = provider.messages.single as AssistantMessage;
        expect((message.parts.single as TextPart).text, 'Hello');
      },
    );

    test(
      'aggressive data saver fetches active message when id-only delta arrives first',
      () async {
        final dataSaverService = CellularDataSaverService.disabled()
          ..debugSetDataSaverLevel(DataSaverLevel.aggressive)
          ..debugSetTransport(DataSaverTransport.cellular);
        addTearDown(dataSaverService.dispose);
        provider = buildProvider(cellularDataSaverService: dataSaverService);

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.refresh();
        await settleUntil(
          () => provider.debugHasRealtimeEventSubscription,
          reason:
              'Expected aggressive visible session burst to start realtime.',
        );

        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          AssistantMessage(
            id: 'msg_missing_delta',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            completedTime: DateTime.fromMillisecondsSinceEpoch(1200),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_missing_delta',
                messageId: 'msg_missing_delta',
                sessionId: 'ses_1',
                text: 'Recovered answer',
              ),
            ],
          ),
        ];

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'message.part.delta',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'messageID': 'msg_missing_delta',
              'partID': 'prt_missing_delta',
              'field': 'text',
              'delta': 'Recovered answer',
            },
          ),
        );
        await settleUntil(
          () => provider.messages.isNotEmpty,
          reason: 'Expected id-only delta to trigger message fallback fetch.',
        );

        final message = provider.messages.single as AssistantMessage;
        expect((message.parts.single as TextPart).text, 'Recovered answer');
        expect(chatRepository.getMessageCallCount, greaterThan(0));
      },
    );

    test(
      'aggressive data saver dedupes field-only delta after coalesced part update',
      () async {
        final dataSaverService = CellularDataSaverService.disabled()
          ..debugSetDataSaverLevel(DataSaverLevel.aggressive)
          ..debugSetTransport(DataSaverTransport.cellular);
        addTearDown(dataSaverService.dispose);
        provider = buildProvider(cellularDataSaverService: dataSaverService);
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          AssistantMessage(
            id: 'msg_overlap_delta',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_overlap_delta',
                messageId: 'msg_overlap_delta',
                sessionId: 'ses_1',
                text: 'Hel',
              ),
            ],
          ),
        ];

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.refresh();
        await settleUntil(
          () => provider.debugHasRealtimeEventSubscription,
          reason:
              'Expected aggressive visible session burst to start realtime.',
        );

        const coalescedPart = TextPart(
          id: 'prt_overlap_delta',
          messageId: 'msg_overlap_delta',
          sessionId: 'ses_1',
          text: 'Hello',
        );
        chatRepository.emitEvent(
          ChatEvent(
            type: 'message.part.updated',
            properties: <String, dynamic>{
              'part': <String, dynamic>{
                'id': coalescedPart.id,
                'messageId': coalescedPart.messageId,
                'sessionId': coalescedPart.sessionId,
                'type': 'text',
                'text': coalescedPart.text,
              },
              'delta': 'lo',
            },
          ),
        );
        await settleUntil(
          () =>
              ((provider.messages.single as AssistantMessage).parts.single
                      as TextPart)
                  .text ==
              'Hello',
          reason: 'Expected coalesced part update to apply first.',
        );

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'message.part.delta',
            properties: <String, dynamic>{
              'messageID': 'msg_overlap_delta',
              'partID': 'prt_overlap_delta',
              'field': 'text',
              'delta': 'lo',
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        final message = provider.messages.single as AssistantMessage;
        expect((message.parts.single as TextPart).text, 'Hello');
      },
    );

    test(
      'foreground resume grace suppresses stale-signal delayed state until reconnect signal arrives',
      () async {
        await defaultSettingsProvider.setSyncResumeGracePeriod(
          const Duration(seconds: 1),
        );
        provider = buildProvider(
          syncSignalStaleThreshold: const Duration(milliseconds: 1),
          syncHealthCheckInterval: const Duration(milliseconds: 50),
        );

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await emitServerConnected();

        await provider.setForegroundActive(false);
        final resumeFuture = provider.setForegroundActive(true);
        await settleUntil(
          () => provider.isInResumeGrace,
          reason: 'Expected foreground return to enter resume grace.',
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(provider.isInResumeGrace, isTrue);
        expect(provider.syncState, ChatSyncState.connected);
        expect(provider.isInDegradedMode, isFalse);

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'server.connected',
            properties: <String, dynamic>{},
          ),
        );
        await resumeFuture;
        await settleUntil(() => !provider.isInResumeGrace);

        expect(provider.syncState, ChatSyncState.connected);
        expect(provider.isInDegradedMode, isFalse);
      },
    );

    test(
      'foreground resume grace eventually promotes true outage to delayed state',
      () async {
        await defaultSettingsProvider.setSyncResumeGracePeriod(
          const Duration(milliseconds: 40),
        );
        provider = buildProvider(
          syncSignalStaleThreshold: const Duration(milliseconds: 1),
          syncHealthCheckInterval: const Duration(milliseconds: 50),
        );

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await emitServerConnected();

        await provider.setForegroundActive(false);
        await provider.setForegroundActive(true);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await settleUntil(
          () =>
              !provider.isInResumeGrace &&
              provider.syncState == ChatSyncState.delayed,
          maxTicks: 80,
          reason:
              'Expected stale realtime signal after resume grace to enter delayed state.',
        );

        expect(provider.isInDegradedMode, isTrue);
      },
    );

    test(
      'backgrounding during foreground resume grace cancels pending promotion',
      () async {
        await defaultSettingsProvider.setSyncResumeGracePeriod(
          const Duration(milliseconds: 40),
        );
        provider = buildProvider(
          syncSignalStaleThreshold: const Duration(milliseconds: 1),
          syncHealthCheckInterval: const Duration(milliseconds: 50),
        );

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await emitServerConnected();

        await provider.setForegroundActive(false);
        final resumeFuture = provider.setForegroundActive(true);
        await settleUntil(
          () => provider.isInResumeGrace,
          reason: 'Expected foreground return to enter resume grace.',
        );
        await provider.setForegroundActive(false);
        await resumeFuture;
        await Future<void>.delayed(const Duration(milliseconds: 60));

        expect(provider.isInResumeGrace, isFalse);
        expect(provider.syncState, ChatSyncState.connected);
        expect(provider.isInDegradedMode, isFalse);
      },
    );

    test(
      'replays optimistic echo and assistant delta using current SSE baseline',
      () async {
        final sendStream = StreamController<Either<Failure, ChatMessage>>();
        addTearDown(() async {
          if (!sendStream.isClosed) {
            await sendStream.close();
          }
        });
        chatRepository.sendMessageHandler = (_, _, _, _) => sendStream.stream;

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        final started = await provider.sendMessage('contract replay prompt');
        expect(started, isTrue);

        await settleUntil(
          () => provider.messages.whereType<UserMessage>().length == 1,
          reason: 'Expected optimistic local user message to be appended.',
        );

        final localUser = provider.messages.single as UserMessage;
        expect(localUser.id, startsWith('local_user_'));
        expect(
          (localUser.parts.single as TextPart).text,
          'contract replay prompt',
        );

        final serverUserEcho = UserMessage(
          id: 'msg_user_server',
          sessionId: 'ses_1',
          time: localUser.time.add(const Duration(seconds: 1)),
          parts: const <MessagePart>[
            TextPart(
              id: 'prt_user_server',
              messageId: 'msg_user_server',
              sessionId: 'ses_1',
              text: 'contract replay prompt',
            ),
          ],
        );
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          serverUserEcho,
        ];
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'message.created',
            properties: <String, dynamic>{
              'info': <String, dynamic>{
                'sessionID': 'ses_1',
                'id': 'msg_user_server',
              },
            },
          ),
        );

        await settleUntil(
          () =>
              provider.messages.whereType<UserMessage>().length == 1 &&
              provider.messages.whereType<UserMessage>().single.id ==
                  'msg_user_server',
          reason: 'Expected server echo to replace optimistic local message.',
        );

        final userMessagesAfterEcho = provider.messages
            .whereType<UserMessage>()
            .toList();
        expect(userMessagesAfterEcho, hasLength(1));
        expect(userMessagesAfterEcho.single.id, 'msg_user_server');

        String? reconciledSnapshot;
        for (var tick = 0; tick < 40; tick += 1) {
          await pumpEventQueue();
          final candidate = await localDataSource.getSessionMessagesSnapshot(
            sessionId: 'ses_1',
            serverId: 'srv_test',
            scopeId: '/tmp',
          );
          if (candidate != null &&
              candidate.contains('msg_user_server') &&
              !candidate.contains(localUser.id)) {
            reconciledSnapshot = candidate;
            break;
          }
        }
        expect(reconciledSnapshot, isNotNull);

        final assistantDraft = AssistantMessage(
          id: 'msg_assistant_contract',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1200),
          parts: const <MessagePart>[
            TextPart(
              id: 'prt_assistant_contract',
              messageId: 'msg_assistant_contract',
              sessionId: 'ses_1',
              text: 'Draft answer',
            ),
          ],
        );
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          serverUserEcho,
          assistantDraft,
        ];
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'message.created',
            properties: <String, dynamic>{
              'info': <String, dynamic>{
                'sessionID': 'ses_1',
                'id': 'msg_assistant_contract',
              },
            },
          ),
        );

        await settleUntil(
          () =>
              provider.messages.whereType<AssistantMessage>().length == 1 &&
              !(provider.messages.last as AssistantMessage).isCompleted,
          reason: 'Expected draft assistant message to be loaded from replay.',
        );

        final draftAssistant = provider.messages.last as AssistantMessage;
        expect(provider.messages.whereType<AssistantMessage>(), hasLength(1));
        expect((draftAssistant.parts.single as TextPart).text, 'Draft answer');
        expect(draftAssistant.isCompleted, isFalse);

        final assistantCompleted = AssistantMessage(
          id: 'msg_assistant_contract',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1200),
          completedTime: DateTime.fromMillisecondsSinceEpoch(1500),
          parts: <MessagePart>[
            const TextPart(
              id: 'prt_assistant_contract',
              messageId: 'msg_assistant_contract',
              sessionId: 'ses_1',
              text: 'Draft answer completed',
            ),
            ToolPart(
              id: 'tool_assistant_contract',
              messageId: 'msg_assistant_contract',
              sessionId: 'ses_1',
              callId: 'call_assistant_contract',
              tool: 'bash',
              state: ToolStateCompleted(
                input: const <String, dynamic>{'command': 'pwd'},
                output: '/workspace',
                time: ToolTime(
                  start: DateTime.fromMillisecondsSinceEpoch(1300),
                  end: DateTime.fromMillisecondsSinceEpoch(1400),
                ),
              ),
            ),
          ],
        );
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          serverUserEcho,
          assistantCompleted,
        ];
        chatRepository.emitEvent(
          ChatEvent(
            type: 'message.part.updated',
            properties: <String, dynamic>{
              'part': MessagePartModel.fromDomain(
                assistantCompleted.parts.first,
              ).toJson(),
              'delta': ' completed',
            },
          ),
        );

        await settleUntil(
          () =>
              provider.messages.last is AssistantMessage &&
              ((provider.messages.last as AssistantMessage).parts
                          .whereType<TextPart>()
                          .lastOrNull
                          ?.text ??
                      '') ==
                  'Draft answer completed',
          reason: 'Expected assistant text delta replay to land.',
        );
        await sendStream.close();
        await settleUntil(
          () => provider.state == ChatState.loaded,
          reason:
              'Expected provider to leave sending state after stream close.',
        );
        await provider.refreshActiveSessionView(
          reason: 'contract-replay-test',
          includeStatus: false,
        );
        await settleUntil(
          () => provider.messages.length == 2,
          reason:
              'Expected replay baseline to stay deduplicated after refresh.',
        );
        await settleUntil(
          () {
            final assistant = provider.messages.lastOrNull;
            return assistant is AssistantMessage && assistant.isCompleted;
          },
          reason:
              'Expected assistant completion metadata to settle after refresh.',
        );

        expect(provider.state, ChatState.loaded);
        expect(provider.messages, hasLength(2));

        final finalUserMessages = provider.messages
            .whereType<UserMessage>()
            .toList();
        expect(finalUserMessages, hasLength(1));
        expect(finalUserMessages.single.id, 'msg_user_server');

        final finalAssistant = provider.messages.last as AssistantMessage;
        final textParts = finalAssistant.parts.whereType<TextPart>().toList();
        expect(finalAssistant.id, 'msg_assistant_contract');
        expect(finalAssistant.isCompleted, isTrue);
        expect(textParts, hasLength(1));
        expect(textParts.single.text, 'Draft answer completed');
      },
    );

    test(
      'send stream keeps one assistant message while parts evolve across updates',
      () async {
        final assistantStreaming = AssistantMessage(
          id: 'msg_assistant_stream_parts',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          parts: <MessagePart>[
            const TextPart(
              id: 'prt_stream_text',
              messageId: 'msg_assistant_stream_parts',
              sessionId: 'ses_1',
              text: 'Inspecting files',
            ),
            ToolPart(
              id: 'tool_stream_part',
              messageId: 'msg_assistant_stream_parts',
              sessionId: 'ses_1',
              callId: 'call_stream_part',
              tool: 'bash',
              state: ToolStateRunning(
                input: const <String, dynamic>{'command': 'ls'},
                time: DateTime.fromMillisecondsSinceEpoch(2001),
              ),
            ),
          ],
        );
        final assistantCompleted = AssistantMessage(
          id: 'msg_assistant_stream_parts',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(2300),
          parts: <MessagePart>[
            const TextPart(
              id: 'prt_stream_text',
              messageId: 'msg_assistant_stream_parts',
              sessionId: 'ses_1',
              text: 'Inspecting files complete',
            ),
            ToolPart(
              id: 'tool_stream_part',
              messageId: 'msg_assistant_stream_parts',
              sessionId: 'ses_1',
              callId: 'call_stream_part',
              tool: 'bash',
              state: ToolStateCompleted(
                input: const <String, dynamic>{'command': 'ls'},
                output: 'README.md\nlib',
                time: ToolTime(
                  start: DateTime.fromMillisecondsSinceEpoch(2001),
                  end: DateTime.fromMillisecondsSinceEpoch(2200),
                ),
              ),
            ),
          ],
        );

        chatRepository.sendMessageHandler = (_, _, _, _) async* {
          yield Right(assistantStreaming);
          await pumpEventQueue();
          yield Right(assistantCompleted);
        };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.sendMessage('show files');
        await settleUntil(
          () =>
              provider.state == ChatState.loaded &&
              provider.messages.whereType<AssistantMessage>().length == 1,
          reason:
              'Expected assistant stream updates to finish deterministically.',
        );

        expect(provider.state, ChatState.loaded);
        expect(provider.messages.whereType<UserMessage>(), hasLength(1));
        expect(provider.messages.whereType<AssistantMessage>(), hasLength(1));

        final assistant = provider.messages.last as AssistantMessage;
        final assistantPartIds = assistant.parts
            .map((part) => part.id)
            .toList();
        expect(assistantPartIds.toSet().length, assistantPartIds.length);
        expect(assistant.parts.whereType<TextPart>(), hasLength(1));
        expect(assistant.parts.whereType<ToolPart>(), hasLength(1));
        expect(
          assistant.parts.whereType<TextPart>().single.text,
          'Inspecting files complete',
        );
        expect(
          assistant.parts.whereType<ToolPart>().single.state.status,
          ToolStatus.completed,
        );
      },
    );

    test(
      'completed assistant fallback keeps server part order without regressing content',
      () async {
        final initialCompleted = AssistantMessage(
          id: 'msg_assistant_ordered_parts',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(3000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(3300),
          parts: <MessagePart>[
            const TextPart(
              id: 'part_ordered_text',
              messageId: 'msg_assistant_ordered_parts',
              sessionId: 'ses_1',
              text: 'Final answer with details',
            ),
            ToolPart(
              id: 'part_ordered_tool',
              messageId: 'msg_assistant_ordered_parts',
              sessionId: 'ses_1',
              callId: 'call_ordered_tool',
              tool: 'bash',
              state: ToolStateCompleted(
                input: const <String, dynamic>{'command': 'pwd'},
                output: '/workspace',
                time: ToolTime(
                  start: DateTime.fromMillisecondsSinceEpoch(3010),
                  end: DateTime.fromMillisecondsSinceEpoch(3200),
                ),
              ),
            ),
          ],
        );
        chatRepository.sendMessageHandler = (_, _, _, _) async* {
          yield Right(initialCompleted);
        };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.sendMessage('order parts');
        await settleUntil(
          () =>
              provider.messages.whereType<AssistantMessage>().singleOrNull !=
              null,
          reason: 'Expected the completed assistant message to load.',
        );

        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          AssistantMessage(
            id: 'msg_assistant_ordered_parts',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(3000),
            completedTime: DateTime.fromMillisecondsSinceEpoch(3400),
            parts: <MessagePart>[
              ToolPart(
                id: 'part_ordered_tool',
                messageId: 'msg_assistant_ordered_parts',
                sessionId: 'ses_1',
                callId: 'call_ordered_tool',
                tool: 'bash',
                state: ToolStateRunning(
                  input: const <String, dynamic>{'command': 'pwd'},
                  time: DateTime.fromMillisecondsSinceEpoch(3010),
                ),
              ),
              const TextPart(
                id: 'part_ordered_text',
                messageId: 'msg_assistant_ordered_parts',
                sessionId: 'ses_1',
                text: 'Final answer',
              ),
            ],
          ),
        ];
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'message.updated',
            properties: <String, dynamic>{
              'info': <String, dynamic>{
                'sessionID': 'ses_1',
                'id': 'msg_assistant_ordered_parts',
              },
            },
          ),
        );

        await settleUntil(
          () {
            final message = provider.messages
                .whereType<AssistantMessage>()
                .singleOrNull;
            return message is AssistantMessage &&
                message.parts.map((part) => part.id).toList().firstOrNull ==
                    'part_ordered_tool';
          },
          reason:
              'Expected completed fallback merge to adopt server part ordering.',
        );

        final assistant = provider.messages
            .whereType<AssistantMessage>()
            .single;
        expect(assistant.parts.map((part) => part.id), <String>[
          'part_ordered_tool',
          'part_ordered_text',
        ]);
        expect(
          assistant.parts.whereType<ToolPart>().single.state.status,
          ToolStatus.completed,
        );
        expect(
          assistant.parts.whereType<TextPart>().single.text,
          'Final answer with details',
        );
      },
    );

    test(
      'refresh keeps active tool stream visible while replay reconciles optimistic echo',
      () async {
        final sendStream = StreamController<Either<Failure, ChatMessage>>();
        addTearDown(() async {
          if (!sendStream.isClosed) {
            await sendStream.close();
          }
        });
        chatRepository.sendMessageHandler = (_, _, _, _) => sendStream.stream;

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        final started = await provider.sendMessage('inspect repo');
        expect(started, isTrue);

        await settleUntil(
          () => provider.messages.whereType<UserMessage>().length == 1,
          reason: 'Expected optimistic local user message to be appended.',
        );

        final serverUserEcho = UserMessage(
          id: 'msg_user_stream_refresh',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1100),
          parts: const <MessagePart>[
            TextPart(
              id: 'prt_user_stream_refresh',
              messageId: 'msg_user_stream_refresh',
              sessionId: 'ses_1',
              text: 'inspect repo',
            ),
          ],
        );
        final assistantStreaming = AssistantMessage(
          id: 'msg_tool_refresh_stream',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1200),
          parts: <MessagePart>[
            ToolPart(
              id: 'part_tool_refresh_stream',
              messageId: 'msg_tool_refresh_stream',
              sessionId: 'ses_1',
              callId: 'call_tool_refresh_stream',
              tool: 'bash',
              state: ToolStateRunning(
                input: const <String, dynamic>{
                  'description': 'Running command',
                  'command': 'ls',
                },
                time: DateTime.fromMillisecondsSinceEpoch(1200),
              ),
            ),
          ],
        );

        sendStream.add(Right(assistantStreaming));
        await settleUntil(
          () =>
              provider.messages.whereType<AssistantMessage>().length == 1 &&
              !(provider.messages.last as AssistantMessage).isCompleted,
          reason:
              'Expected tool-only streaming assistant message to stay visible.',
        );

        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          serverUserEcho,
          assistantStreaming,
        ];
        await provider.refreshActiveSessionView(
          reason: 'g4-streaming-tool-refresh',
          includeStatus: false,
        );

        await settleUntil(
          () =>
              provider.messages.whereType<AssistantMessage>().length == 1 &&
              provider.messages.whereType<AssistantMessage>().single.id ==
                  'msg_tool_refresh_stream',
          reason: 'Expected refresh to preserve the active tool stream.',
        );

        final refreshedAssistant = provider.messages
            .whereType<AssistantMessage>()
            .single;
        expect(refreshedAssistant.isCompleted, isFalse);
        expect(refreshedAssistant.parts.whereType<ToolPart>(), hasLength(1));
        expect(
          refreshedAssistant.parts.whereType<ToolPart>().single.state.status,
          ToolStatus.running,
        );
        final refreshedUsers = provider.messages
            .whereType<UserMessage>()
            .toList();
        expect(refreshedUsers, hasLength(2));
        expect(
          refreshedUsers.map((message) => message.id),
          contains('msg_user_stream_refresh'),
        );
        expect(
          refreshedUsers.any((message) => message.id.startsWith('local_user_')),
          isTrue,
        );
        expect(
          refreshedUsers.map(
            (message) => (message.parts.first as TextPart).text,
          ),
          everyElement(equals('inspect repo')),
        );

        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          serverUserEcho,
          AssistantMessage(
            id: 'msg_tool_refresh_stream',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1200),
            completedTime: DateTime.fromMillisecondsSinceEpoch(1400),
            parts: <MessagePart>[
              ToolPart(
                id: 'part_tool_refresh_stream',
                messageId: 'msg_tool_refresh_stream',
                sessionId: 'ses_1',
                callId: 'call_tool_refresh_stream',
                tool: 'bash',
                state: ToolStateCompleted(
                  input: const <String, dynamic>{'command': 'ls'},
                  output: 'README.md\nlib',
                  time: ToolTime(
                    start: DateTime.fromMillisecondsSinceEpoch(1200),
                    end: DateTime.fromMillisecondsSinceEpoch(1350),
                  ),
                ),
              ),
              const TextPart(
                id: 'part_tool_refresh_stream_final',
                messageId: 'msg_tool_refresh_stream',
                sessionId: 'ses_1',
                text: 'repo inspected',
              ),
            ],
          ),
        ];
        await provider.refreshActiveSessionView(
          reason: 'g4-final-tool-refresh',
          includeStatus: false,
        );

        await settleUntil(
          () =>
              provider.messages.whereType<AssistantMessage>().length == 1 &&
              provider.messages
                  .whereType<AssistantMessage>()
                  .single
                  .isCompleted,
          reason:
              'Expected idle reconcile to reveal the final assistant response.',
        );

        final finalAssistant = provider.messages
            .whereType<AssistantMessage>()
            .single;
        expect(finalAssistant.parts.whereType<ToolPart>(), hasLength(1));
        expect(
          finalAssistant.parts.whereType<TextPart>().single.text,
          'repo inspected',
        );
        await sendStream.close();
        await settleUntil(
          () => provider.state == ChatState.loaded,
          reason: 'Expected provider to leave sending state after refresh.',
        );
      },
    );

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

        chatRepository.sendMessageHandler = (_, _, _, _) async* {
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

    test('does not generate AI titles for subsessions', () async {
      localDataSource.serverProfilesJson = jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'srv_test',
          'url': 'http://127.0.0.1:4096',
          'createdAt': 1,
          'updatedAt': 1,
          'aiGeneratedTitlesEnabled': true,
        },
      ]);

      chatRepository.sessions.insert(
        0,
        ChatSession(
          id: 'ses_child',
          workspaceId: 'default',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          title: 'Child session',
          parentId: 'ses_1',
        ),
      );
      chatRepository.messagesBySession['ses_child'] = <ChatMessage>[];

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

      chatRepository.sendMessageHandler = (_, sessionId, _, _) async* {
        yield Right(
          AssistantMessage(
            id: 'msg_assistant_subsession',
            sessionId: sessionId,
            time: DateTime.fromMillisecondsSinceEpoch(3000),
            completedTime: DateTime.fromMillisecondsSinceEpoch(3100),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_assistant_subsession',
                messageId: 'msg_assistant_subsession',
                sessionId: 'ses_child',
                text: 'reply',
              ),
            ],
          ),
        );
      };

      await providerWithAutoTitle.projectProvider.initializeProject();
      await providerWithAutoTitle.loadSessions();
      await providerWithAutoTitle.selectSession(
        providerWithAutoTitle.sessions.firstWhere(
          (session) => session.id == 'ses_child',
        ),
      );
      await providerWithAutoTitle.sendMessage('hello');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(titleGenerator.callCount, 0);
      expect(
        chatRepository.sessions
            .where((session) => session.id == 'ses_child')
            .first
            .title,
        'Child session',
      );
    });

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
        chatRepository.sendMessageHandler = (_, _, _, _) async* {
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
        chatRepository.updateSessionHandler = (_, sessionId, input, _) async {
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

        chatRepository.sendMessageHandler = (_, _, _, _) async* {
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
        chatRepository.sendMessageHandler = (_, _, _, _) =>
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
        chatRepository.sendMessageHandler = (_, _, _, _) =>
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

    test('session.error remote abort appends inline message', () async {
      await provider.projectProvider.initializeProject();
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);
      await provider.initializeProviders();

      chatRepository.emitEvent(
        const ChatEvent(
          type: 'session.error',
          properties: <String, dynamic>{
            'sessionID': 'ses_1',
            'error': <String, dynamic>{
              'message': 'The operation was aborted by user',
            },
          },
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(provider.state, ChatState.loaded);
      expect(provider.errorMessage, isNull);
      expect(provider.consumePendingUiNotice(), isNull);

      final inlineAbort = provider.messages.last as AssistantMessage;
      expect(inlineAbort.error, isNotNull);
      expect(inlineAbort.error!.name, 'MessageAborted');
      expect(inlineAbort.error!.message, 'What you want to do different?');
    });

    test('session.error string payload is handled as abort error', () async {
      await provider.projectProvider.initializeProject();
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);
      await provider.initializeProviders();

      chatRepository.emitEvent(
        const ChatEvent(
          type: 'session.error',
          properties: <String, dynamic>{
            'sessionID': 'ses_1',
            'error': 'Request was aborted',
          },
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(provider.state, ChatState.loaded);
      expect(provider.errorMessage, isNull);
    });

    test('server.heartbeat is ignored without UI churn', () async {
      await provider.projectProvider.initializeProject();
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);
      await provider.initializeProviders();

      final initialState = provider.state;
      final initialMessagesLength = provider.messages.length;
      final initialSessionStatus = provider.currentSessionStatus;

      chatRepository.emitEvent(
        const ChatEvent(
          type: 'server.heartbeat',
          properties: <String, dynamic>{'timestamp': 1739079900000},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(provider.state, initialState);
      expect(provider.messages, hasLength(initialMessagesLength));
      expect(provider.currentSessionStatus, initialSessionStatus);
      expect(provider.consumePendingUiNotice(), isNull);
    });

    test(
      'session.error from non-current session only settles background status',
      () async {
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_2',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1500),
            title: 'Session 2',
          ),
        );

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(
          provider.sessions.where((item) => item.id == 'ses_1').first,
        );
        await provider.initializeProviders();

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.error',
            properties: <String, dynamic>{
              'sessionID': 'ses_2',
              'error': <String, dynamic>{'message': 'background failure'},
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(provider.currentSession?.id, 'ses_1');
        expect(provider.errorMessage, isNull);
        expect(
          provider.sessionStatusById['ses_2']?.type,
          SessionStatusType.idle,
        );
        final attention = provider.sessionAttentionFor('ses_2');
        expect(attention.hasError, isTrue);
        expect(provider.hasOutOfFocusAttention, isTrue);
        expect(provider.outOfFocusAttentionCount, 1);
        expect(provider.outOfFocusAttentionKind, SessionAttentionKind.error);
      },
    );

    test(
      'session.idle from non-current session marks unread completion',
      () async {
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_2',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1500),
            title: 'Session 2',
          ),
        );

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(
          provider.sessions.where((item) => item.id == 'ses_1').first,
        );
        await provider.initializeProviders();

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.idle',
            properties: <String, dynamic>{'sessionID': 'ses_2'},
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(provider.currentSession?.id, 'ses_1');
        expect(
          provider.sessionStatusById['ses_2']?.type,
          SessionStatusType.idle,
        );
        final attention = provider.sessionAttentionFor('ses_2');
        expect(attention.hasUnreadCompletion, isTrue);
        expect(attention.unreadCompletionAt, isNotNull);
      },
    );

    test(
      'session.idle wakes ephemeral title waiter before event filtering',
      () async {
        final titleGenerator = _FakeChatTitleGenerator();
        provider = buildProvider(titleGenerator: titleGenerator);
        ChatTitleGenerator.ephemeralSessionIds.add('ses_title_waiter');
        addTearDown(
          () =>
              ChatTitleGenerator.ephemeralSessionIds.remove('ses_title_waiter'),
        );

        await initializeRealtimeProvider();
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.idle',
            properties: <String, dynamic>{'sessionID': 'ses_title_waiter'},
          ),
        );
        await settleUntil(
          () => titleGenerator.idleSessionIds.isNotEmpty,
          reason: 'Expected ephemeral session.idle to wake title waiter.',
        );

        expect(titleGenerator.idleSessionIds, <String>['ses_title_waiter']);
        expect(titleGenerator.idleDirectories, <String?>[
          provider.projectProvider.currentDirectory,
        ]);
        expect(
          provider.sessions.any((session) => session.id == 'ses_title_waiter'),
          isFalse,
        );
      },
    );

    test(
      'global session.idle forwards its directory to ephemeral title waiter',
      () async {
        final titleGenerator = _FakeChatTitleGenerator();
        provider = buildProvider(titleGenerator: titleGenerator);
        ChatTitleGenerator.ephemeralSessionIds.add('ses_global_title_waiter');
        addTearDown(
          () => ChatTitleGenerator.ephemeralSessionIds.remove(
            'ses_global_title_waiter',
          ),
        );

        await initializeRealtimeProvider();
        await settleUntil(
          () => provider.debugHasGlobalEventSubscription,
          reason: 'Expected global subscription before title waiter event.',
        );
        chatRepository.emitGlobalEvent(
          const ChatEvent(
            type: 'session.idle',
            properties: <String, dynamic>{
              'sessionID': 'ses_global_title_waiter',
              'directory': '/workspace/global',
            },
          ),
        );
        await settleUntil(
          () => titleGenerator.idleSessionIds.isNotEmpty,
          reason: 'Expected global session.idle to wake title waiter.',
        );

        expect(titleGenerator.idleSessionIds, <String>[
          'ses_global_title_waiter',
        ]);
        expect(titleGenerator.idleDirectories, <String?>['/workspace/global']);
      },
    );

    test(
      'session.status idle for selected session not on chat route notifies once',
      () async {
        final feedbackDispatcher = _RecordingEventFeedbackDispatcher(
          settingsProvider: defaultSettingsProvider,
        );
        provider = buildProvider(eventFeedbackDispatcher: feedbackDispatcher);

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.initializeProviders();
        provider.setChatRouteActive(false);
        feedbackDispatcher.clear();

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

        var attention = provider.sessionAttentionFor('ses_1');
        expect(attention.hasUnreadCompletion, isTrue);
        expect(feedbackDispatcher.handledTypes, contains('session.idle'));
        expect(feedbackDispatcher.lastCurrentSessionId, isNull);
        feedbackDispatcher.clear();

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.idle',
            properties: <String, dynamic>{'sessionID': 'ses_1'},
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(feedbackDispatcher.handledTypes, isEmpty);
        expect(feedbackDispatcher.dismissedSessionIds, isEmpty);
        attention = provider.sessionAttentionFor('ses_1');
        expect(attention.hasUnreadCompletion, isTrue);
        expect(attention.unreadCompletionAt, isNotNull);
      },
    );

    test(
      'message.created for non-current session does not fetch background payload',
      () async {
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_2',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1500),
            title: 'Session 2',
          ),
        );
        chatRepository.messagesBySession['ses_2'] = <ChatMessage>[
          AssistantMessage(
            id: 'msg_background_done',
            sessionId: 'ses_2',
            time: DateTime.fromMillisecondsSinceEpoch(1600),
            completedTime: DateTime.fromMillisecondsSinceEpoch(1700),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_background_done',
                messageId: 'msg_background_done',
                sessionId: 'ses_2',
                text: 'done in background',
              ),
            ],
          ),
        ];

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(
          provider.sessions.where((item) => item.id == 'ses_1').first,
        );
        await provider.initializeProviders();

        final callsBeforeEvent = chatRepository.getMessageCallCount;
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'message.created',
            properties: <String, dynamic>{
              'info': <String, dynamic>{
                'id': 'msg_background_done',
                'sessionID': 'ses_2',
              },
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(provider.currentSession?.id, 'ses_1');
        expect(chatRepository.getMessageCallCount, callsBeforeEvent);
      },
    );

    test(
      'session.idle no longer triggers fallback refresh for current session completion',
      () async {
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          AssistantMessage(
            id: 'msg_tool_placeholder',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1100),
            parts: <MessagePart>[
              ToolPart(
                id: 'part_tool_placeholder',
                messageId: 'msg_tool_placeholder',
                sessionId: 'ses_1',
                callId: 'call_tool_placeholder',
                tool: 'bash',
                state: ToolStateRunning(
                  input: const <String, dynamic>{
                    'description': 'Running command',
                    'command': 'ls',
                  },
                  time: DateTime.fromMillisecondsSinceEpoch(1100),
                ),
              ),
            ],
          ),
        ];

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(
          provider.sessions.where((item) => item.id == 'ses_1').first,
        );
        await provider.initializeProviders();

        final callsBeforeIdle = chatRepository.getMessagesCallCount;

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.idle',
            properties: <String, dynamic>{'sessionID': 'ses_1'},
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));

        final latestAssistant = provider.messages
            .whereType<AssistantMessage>()
            .last;
        expect(latestAssistant.isCompleted, isTrue);
        expect(chatRepository.getMessagesCallCount, equals(callsBeforeIdle));
      },
    );

    test(
      'message.part.updated does not schedule scroll callback during busy passive updates',
      () async {
        const sessionId = 'ses_1';
        chatRepository.messagesBySession[sessionId] = <ChatMessage>[
          AssistantMessage(
            id: 'msg_busy_tool_surface',
            sessionId: sessionId,
            time: DateTime.fromMillisecondsSinceEpoch(1100),
            completedTime: DateTime.fromMillisecondsSinceEpoch(1110),
            parts: <MessagePart>[
              ToolPart(
                id: 'part_busy_tool_surface',
                messageId: 'msg_busy_tool_surface',
                sessionId: sessionId,
                callId: 'call_busy_tool_surface',
                tool: 'bash',
                state: ToolStateCompleted(
                  input: const <String, dynamic>{'command': 'pwd'},
                  output: '/tmp',
                  time: ToolTime(
                    start: DateTime.fromMillisecondsSinceEpoch(1100),
                    end: DateTime.fromMillisecondsSinceEpoch(1105),
                  ),
                ),
              ),
            ],
          ),
        ];

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.initializeProviders();

        var scrollToBottomRequests = 0;
        provider.setScrollToBottomCallback(({required reason}) {
          scrollToBottomRequests += 1;
        });

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.status',
            properties: <String, dynamic>{
              'sessionID': sessionId,
              'status': <String, dynamic>{'type': 'busy'},
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        final part = MessagePartModel.fromDomain(
          const ReasoningPart(
            id: 'part_busy_reasoning',
            messageId: 'msg_busy_tool_surface',
            sessionId: sessionId,
            text: 'Inspecting tool progress',
          ),
        );
        chatRepository.emitEvent(
          ChatEvent(
            type: 'message.part.updated',
            properties: <String, dynamic>{'part': part.toJson()},
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(scrollToBottomRequests, 0);
      },
    );

    test(
      'message.part.updated still emits passive signal during active turn when status is stale idle',
      () async {
        const sessionId = 'ses_1';
        chatRepository.messagesBySession[sessionId] = <ChatMessage>[
          AssistantMessage(
            id: 'msg_idle_tool_surface',
            sessionId: sessionId,
            time: DateTime.fromMillisecondsSinceEpoch(1100),
            parts: <MessagePart>[
              ToolPart(
                id: 'part_idle_tool_surface',
                messageId: 'msg_idle_tool_surface',
                sessionId: sessionId,
                callId: 'call_idle_tool_surface',
                tool: 'bash',
                state: ToolStateRunning(
                  input: const <String, dynamic>{'command': 'pwd'},
                  time: DateTime.fromMillisecondsSinceEpoch(1100),
                ),
              ),
            ],
          ),
        ];

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.initializeProviders();

        var scrollToBottomRequests = 0;
        provider.setScrollToBottomCallback(({required reason}) {
          scrollToBottomRequests += 1;
        });

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.status',
            properties: <String, dynamic>{
              'sessionID': sessionId,
              'status': <String, dynamic>{'type': 'idle'},
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        final part = MessagePartModel.fromDomain(
          const ReasoningPart(
            id: 'part_idle_reasoning',
            messageId: 'msg_idle_tool_surface',
            sessionId: sessionId,
            text: 'Still progressing despite stale idle status',
          ),
        );
        chatRepository.emitEvent(
          ChatEvent(
            type: 'message.part.updated',
            properties: <String, dynamic>{'part': part.toJson()},
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(scrollToBottomRequests, 1);
      },
    );

    test(
      'session.idle does not bypass lifecycle cleanup rules during abort suppression',
      () async {
        provider = buildProvider(
          abortSuppressionWindow: const Duration(seconds: 1),
        );

        chatRepository.sendMessageHandler = (_, _, _, _) async* {
          yield Right(
            AssistantMessage(
              id: 'msg_abort_window_tool_only',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(2100),
              parts: <MessagePart>[
                ToolPart(
                  id: 'part_abort_window_tool_only',
                  messageId: 'msg_abort_window_tool_only',
                  sessionId: 'ses_1',
                  callId: 'call_abort_window_tool_only',
                  tool: 'bash',
                  state: ToolStateRunning(
                    input: const <String, dynamic>{
                      'description': 'Running command',
                      'command': 'pwd',
                    },
                    time: DateTime.fromMillisecondsSinceEpoch(2100),
                  ),
                ),
              ],
            ),
          );
        };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.initializeProviders();

        await provider.sendMessage('trigger abort-suppression reconcile');
        await Future<void>.delayed(const Duration(milliseconds: 30));

        final callsBeforeIdle = chatRepository.getMessagesCallCount;

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.idle',
            properties: <String, dynamic>{'sessionID': 'ses_1'},
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(chatRepository.getMessagesCallCount, equals(callsBeforeIdle));
        final latestAssistant = provider.messages
            .whereType<AssistantMessage>()
            .last;
        expect(latestAssistant.isCompleted, isTrue);
      },
    );

    test(
      'session.idle ends active composer state while send stream drains',
      () async {
        final sendController =
            StreamController<Either<Failure, ChatMessage>>.broadcast();
        chatRepository.sendMessageHandler = (_, _, _, _) =>
            sendController.stream;

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.initializeProviders();

        await provider.sendMessage('trigger sending-state reconcile');
        await Future<void>.delayed(const Duration(milliseconds: 30));

        final callsBeforeIdle = chatRepository.getMessagesCallCount;

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.idle',
            properties: <String, dynamic>{'sessionID': 'ses_1'},
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(chatRepository.getMessagesCallCount, equals(callsBeforeIdle));
        expect(provider.currentSessionStatus?.type, SessionStatusType.idle);
        expect(provider.state, ChatState.loaded);
        expect(provider.isCurrentSessionActivelyResponding, isFalse);

        sendController.add(
          Right(
            AssistantMessage(
              id: 'msg_idle_reconcile_final',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(3100),
              completedTime: DateTime.fromMillisecondsSinceEpoch(3200),
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_idle_reconcile_final',
                  messageId: 'msg_idle_reconcile_final',
                  sessionId: 'ses_1',
                  text: 'final response resolved on stream',
                ),
              ],
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        await sendController.close();
        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(chatRepository.getMessagesCallCount, equals(callsBeforeIdle));
        expect(provider.state, ChatState.loaded);
        final latestAssistant = provider.messages
            .whereType<AssistantMessage>()
            .last;
        expect(
          (latestAssistant.parts.single as TextPart).text,
          'final response resolved on stream',
        );
      },
    );

    test(
      'monotonic completion guard: completed assistant message survives late incomplete stream event after session.idle',
      () async {
        final sendController =
            StreamController<Either<Failure, ChatMessage>>.broadcast();
        chatRepository.sendMessageHandler = (_, _, _, _) =>
            sendController.stream;

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.initializeProviders();

        await provider.sendMessage('trigger flicker test');
        await Future<void>.delayed(const Duration(milliseconds: 30));

        // Deliver an INCOMPLETE assistant message through the stream
        sendController.add(
          Right(
            AssistantMessage(
              id: 'msg_flicker_test',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(3000),
              // completedTime is null — message is incomplete
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_flicker_test',
                  messageId: 'msg_flicker_test',
                  sessionId: 'ses_1',
                  text: 'streaming response',
                ),
              ],
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Emit session.idle — _markIncompleteAssistantMessagesAsCompleted
        // stamps completedTime
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.idle',
            properties: <String, dynamic>{'sessionID': 'ses_1'},
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));

        // Assert message is now completed
        var latestAssistant = provider.messages
            .whereType<AssistantMessage>()
            .last;
        expect(latestAssistant.isCompleted, isTrue);
        final completedTimeAfterIdle = latestAssistant.completedTime;

        // Deliver a LATE incomplete version of the same message through
        // the stream (simulating stale polling snapshot) — this is the
        // exact flicker regression trigger
        sendController.add(
          Right(
            AssistantMessage(
              id: 'msg_flicker_test',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(3000),
              // completedTime is null — stale/incomplete version
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_flicker_test',
                  messageId: 'msg_flicker_test',
                  sessionId: 'ses_1',
                  text: 'streaming response',
                ),
              ],
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Assert: message stays completed, completedTime unchanged
        latestAssistant = provider.messages.whereType<AssistantMessage>().last;
        expect(latestAssistant.isCompleted, isTrue);
        expect(latestAssistant.completedTime, completedTimeAfterIdle);

        // Deliver a COMPLETE version through the stream (simulating
        // authoritative server update) — guard should allow this
        sendController.add(
          Right(
            AssistantMessage(
              id: 'msg_flicker_test',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(3000),
              completedTime: DateTime.fromMillisecondsSinceEpoch(3500),
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_flicker_test',
                  messageId: 'msg_flicker_test',
                  sessionId: 'ses_1',
                  text: 'streaming response (authoritative)',
                ),
              ],
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Assert: message IS updated to the new content
        // (complete → complete allowed through guard)
        latestAssistant = provider.messages.whereType<AssistantMessage>().last;
        expect(latestAssistant.isCompleted, isTrue);
        expect(
          (latestAssistant.parts.single as TextPart).text,
          'streaming response (authoritative)',
        );
        expect(
          latestAssistant.completedTime,
          DateTime.fromMillisecondsSinceEpoch(3500),
        );

        await sendController.close();
        await Future<void>.delayed(const Duration(milliseconds: 80));
      },
    );

    test(
      'completed assistant update preserves richer parts and terminal tool state',
      () async {
        final sendController =
            StreamController<Either<Failure, ChatMessage>>.broadcast();
        chatRepository.sendMessageHandler = (_, _, _, _) =>
            sendController.stream;

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.sendMessage('preserve completed response');
        sendController.add(
          Right(
            AssistantMessage(
              id: 'msg_completed_rich',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(3000),
              completedTime: DateTime.fromMillisecondsSinceEpoch(3500),
              parts: <MessagePart>[
                const ReasoningPart(
                  id: 'part_completed_reasoning',
                  messageId: 'msg_completed_rich',
                  sessionId: 'ses_1',
                  text: 'complete reasoning',
                ),
                const TextPart(
                  id: 'part_completed_text',
                  messageId: 'msg_completed_rich',
                  sessionId: 'ses_1',
                  text: 'complete response',
                ),
                ToolPart(
                  id: 'part_completed_tool',
                  messageId: 'msg_completed_rich',
                  sessionId: 'ses_1',
                  callId: 'call_completed_tool',
                  tool: 'bash',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{'command': 'pwd'},
                    output: '/workspace',
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(3100),
                      end: DateTime.fromMillisecondsSinceEpoch(3400),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        await settleUntil(
          () =>
              provider.messages.whereType<AssistantMessage>().lastOrNull?.id ==
              'msg_completed_rich',
        );

        sendController.add(
          Right(
            AssistantMessage(
              id: 'msg_completed_rich',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(3000),
              completedTime: DateTime.fromMillisecondsSinceEpoch(3600),
              parts: <MessagePart>[
                const TextPart(
                  id: 'part_completed_text',
                  messageId: 'msg_completed_rich',
                  sessionId: 'ses_1',
                  text: 'complete',
                ),
                ToolPart(
                  id: 'part_completed_tool',
                  messageId: 'msg_completed_rich',
                  sessionId: 'ses_1',
                  callId: 'call_completed_tool',
                  tool: 'bash',
                  state: ToolStateRunning(
                    input: const <String, dynamic>{'command': 'pwd'},
                    time: DateTime.fromMillisecondsSinceEpoch(3100),
                  ),
                ),
              ],
            ),
          ),
        );
        await pumpEventQueue();

        final assistant = provider.messages
            .whereType<AssistantMessage>()
            .lastWhere((message) => message.id == 'msg_completed_rich');
        expect(
          assistant.completedTime,
          DateTime.fromMillisecondsSinceEpoch(3600),
        );
        expect(
          assistant.parts.whereType<ReasoningPart>().single.text,
          'complete reasoning',
        );
        expect(
          assistant.parts.whereType<TextPart>().single.text,
          'complete response',
        );
        expect(
          assistant.parts.whereType<ToolPart>().single.state.status,
          ToolStatus.completed,
        );

        await sendController.close();
      },
    );

    test('debounced fallback timers cancelled on session.idle', () async {
      // Set up an assistant message in the session that would normally
      // trigger a debounced fallback fetch via message.part.updated
      const initialPart = TextPart(
        id: 'prt_debounce_cancel',
        messageId: 'msg_debounce_cancel',
        sessionId: 'ses_1',
        text: 'Draft',
      );
      chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
        AssistantMessage(
          id: 'msg_debounce_cancel',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          parts: const <MessagePart>[initialPart],
        ),
      ];

      await provider.projectProvider.initializeProject();
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);
      await provider.initializeProviders();

      // Emit message.part.updated to schedule a debounced fallback
      chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
        AssistantMessage(
          id: 'msg_debounce_cancel',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          parts: const <MessagePart>[],
        ),
      ];
      chatRepository.emitEvent(
        ChatEvent(
          type: 'message.part.updated',
          properties: <String, dynamic>{
            'part': MessagePartModel.fromDomain(
              const TextPart(
                id: 'prt_debounce_cancel',
                messageId: 'msg_debounce_cancel',
                sessionId: 'ses_1',
                text: ' Draft',
              ),
            ).toJson(),
            'delta': ' Draft',
          },
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));

      final callsBeforeIdle = chatRepository.getMessageCallCount;

      // Fire session.idle — should cancel pending debounced timers
      chatRepository.emitEvent(
        const ChatEvent(
          type: 'session.idle',
          properties: <String, dynamic>{'sessionID': 'ses_1'},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Assert: the debounced fallback timer was cancelled and no
      // extra HTTP GET was made (getMessageCallCount unchanged)
      expect(
        chatRepository.getMessageCallCount,
        equals(callsBeforeIdle),
        reason: 'debounced fallback should not fire after session.idle',
      );
    });

    test(
      'idle status pulse does not settle the current session while an assistant message is still incomplete',
      () async {
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          UserMessage(
            id: 'msg_idle_pulse_user',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            parts: const <MessagePart>[
              TextPart(
                id: 'part_idle_pulse_user',
                messageId: 'msg_idle_pulse_user',
                sessionId: 'ses_1',
                text: 'keep working',
              ),
            ],
          ),
          AssistantMessage(
            id: 'msg_idle_pulse_assistant',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1100),
            parts: const <MessagePart>[
              TextPart(
                id: 'part_idle_pulse_assistant',
                messageId: 'msg_idle_pulse_assistant',
                sessionId: 'ses_1',
                text: 'still streaming',
              ),
            ],
          ),
        ];

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.initializeProviders();

        expect(provider.isCurrentSessionActivelyResponding, isTrue);

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

        expect(provider.currentSessionStatus?.type, SessionStatusType.idle);
        expect(provider.isCurrentSessionActivelyResponding, isTrue);
      },
    );

    test(
      'busy assistant stream updates do not schedule passive provider auto-scroll',
      () async {
        final sendController =
            StreamController<Either<Failure, ChatMessage>>.broadcast();
        addTearDown(() async {
          if (!sendController.isClosed) {
            await sendController.close();
          }
        });
        chatRepository.sendMessageHandler = (_, _, _, _) =>
            sendController.stream;

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.initializeProviders();

        await provider.sendMessage('run busy tool step');
        await Future<void>.delayed(const Duration(milliseconds: 30));

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

        var scrollToBottomRequests = 0;
        provider.setScrollToBottomCallback(({required reason}) {
          scrollToBottomRequests += 1;
        });

        sendController.add(
          Right(
            AssistantMessage(
              id: 'msg_busy_stream_update',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(2100),
              completedTime: DateTime.fromMillisecondsSinceEpoch(2200),
              parts: <MessagePart>[
                ToolPart(
                  id: 'part_busy_stream_update',
                  messageId: 'msg_busy_stream_update',
                  sessionId: 'ses_1',
                  callId: 'call_busy_stream_update',
                  tool: 'bash',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{'command': 'git status'},
                    output: 'clean',
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(2100),
                      end: DateTime.fromMillisecondsSinceEpoch(2150),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(scrollToBottomRequests, 0);
      },
    );

    test(
      'non-current busy -> idle transition marks unread completion attention',
      () async {
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_2',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1500),
            title: 'Session 2',
          ),
        );

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(
          provider.sessions.where((item) => item.id == 'ses_1').first,
        );
        await provider.initializeProviders();

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.status',
            properties: <String, dynamic>{
              'sessionID': 'ses_2',
              'status': <String, dynamic>{'type': 'busy'},
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.idle',
            properties: <String, dynamic>{'sessionID': 'ses_2'},
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        final attentionBeforeSelect = provider.sessionAttentionFor('ses_2');
        expect(attentionBeforeSelect.hasUnreadCompletion, isTrue);
        expect(
          provider.outOfFocusAttentionKind,
          SessionAttentionKind.unreadCompletion,
        );

        await provider.selectSession(
          provider.sessions.where((item) => item.id == 'ses_2').first,
        );

        final attentionAfterSelect = provider.sessionAttentionFor('ses_2');
        expect(attentionAfterSelect.hasUnreadCompletion, isFalse);
        expect(provider.hasOutOfFocusAttention, isFalse);
      },
    );

    test(
      'child busy -> idle transition does not mark unread completion attention',
      () async {
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_root',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1500),
            title: 'Root Session',
          ),
        );
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_child',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1600),
            title: 'Child Session',
            parentId: 'ses_root',
          ),
        );

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(
          provider.sessions.where((item) => item.id == 'ses_1').first,
        );
        await provider.initializeProviders();

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.status',
            properties: <String, dynamic>{
              'sessionID': 'ses_child',
              'status': <String, dynamic>{'type': 'busy'},
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.idle',
            properties: <String, dynamic>{'sessionID': 'ses_child'},
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        final childAttention = provider.sessionAttentionFor('ses_child');
        expect(childAttention.hasUnreadCompletion, isFalse);
        expect(provider.outOfFocusAttentionKind, SessionAttentionKind.none);
      },
    );

    test('current session retry status keeps notice queue empty', () async {
      await provider.projectProvider.initializeProject();
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);
      await provider.initializeProviders();

      chatRepository.emitEvent(
        const ChatEvent(
          type: 'session.status',
          properties: <String, dynamic>{
            'sessionID': 'ses_1',
            'status': <String, dynamic>{
              'type': 'retry',
              'attempt': 2,
              'message': 'Provider is retrying upstream call',
            },
          },
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(provider.consumePendingUiNotice(), isNull);
    });

    test(
      'non-current retry status does not flag conversation as error',
      () async {
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_2',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1500),
            title: 'Session 2',
          ),
        );

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(
          provider.sessions.where((item) => item.id == 'ses_1').first,
        );
        await provider.initializeProviders();

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.status',
            properties: <String, dynamic>{
              'sessionID': 'ses_2',
              'status': <String, dynamic>{
                'type': 'retry',
                'attempt': 1,
                'message': 'Transient upstream retry',
              },
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        final attention = provider.sessionAttentionFor('ses_2');
        expect(attention.hasError, isFalse);
        expect(
          provider.outOfFocusAttentionKind,
          isNot(SessionAttentionKind.error),
        );
      },
    );

    test(
      'question.asked marks out-of-focus pending interaction attention',
      () async {
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_2',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1500),
            title: 'Session 2',
          ),
        );

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(
          provider.sessions.where((item) => item.id == 'ses_1').first,
        );
        await provider.initializeProviders();

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'question.asked',
            properties: <String, dynamic>{
              'id': 'question_1',
              'sessionID': 'ses_2',
              'questions': <Map<String, dynamic>>[
                <String, dynamic>{
                  'question': 'Proceed?',
                  'header': 'Header',
                  'options': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'label': 'Yes',
                      'description': 'Continue',
                    },
                  ],
                },
              ],
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        final attention = provider.sessionAttentionFor('ses_2');
        expect(attention.hasPendingInteraction, isTrue);
        expect(provider.hasOutOfFocusAttention, isTrue);
        expect(provider.outOfFocusAttentionCount, 1);
        expect(
          provider.outOfFocusAttentionKind,
          SessionAttentionKind.pendingInteraction,
        );
      },
    );

    test(
      'question.asked survives delayed pending-question reload during foreground reconnect',
      () async {
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_2',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1500),
            title: 'Session 2',
          ),
        );

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(
          provider.sessions.where((item) => item.id == 'ses_1').first,
        );
        await provider.initializeProviders();
        await provider.setForegroundActive(false);

        final reloadGate = Completer<void>();
        chatRepository.listQuestionsDelay = () => reloadGate.future;

        final resumeFuture = provider.setForegroundActive(true);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'question.asked',
            properties: <String, dynamic>{
              'id': 'question_race_1',
              'sessionID': 'ses_2',
              'questions': <Map<String, dynamic>>[
                <String, dynamic>{
                  'question': 'Persist me?',
                  'header': 'Race',
                  'options': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'label': 'Yes',
                      'description': 'Keep pending',
                    },
                  ],
                },
              ],
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        reloadGate.complete();
        await resumeFuture;
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final attention = provider.sessionAttentionFor('ses_2');
        expect(attention.hasPendingInteraction, isTrue);
        expect(provider.outOfFocusAttentionCount, 1);
      },
    );

    test(
      'sendMessage is blocked while realtime transport is reconnecting',
      () async {
        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.initializeProviders();

        chatRepository.emitEventFailure(const NetworkFailure('stream offline'));
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(provider.syncState, ChatSyncState.reconnecting);

        final sent = await provider.sendMessage('blocked while reconnecting');

        expect(sent, isFalse);
        expect(chatRepository.lastSendInput, isNull);
        expect(
          provider.consumePendingUiNotice()?.message,
          contains('Reconnecting'),
        );
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
        chatRepository.sendMessageHandler = (_, _, _, _) {
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

    test(
      'submitMessage sends a follow-up while a response is active without aborting',
      () async {
        final firstStreamController =
            StreamController<Either<Failure, ChatMessage>>();
        addTearDown(() async {
          await firstStreamController.close();
        });
        final assistantAfterFollowUp = AssistantMessage(
          id: 'msg_after_busy_follow_up',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(3000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(3200),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_after_busy_follow_up',
              messageId: 'msg_after_busy_follow_up',
              sessionId: 'ses_1',
              text: 'follow-up delivered',
            ),
          ],
        );

        var sendCalls = 0;
        chatRepository.sendMessageHandler = (_, _, _, _) {
          sendCalls += 1;
          if (sendCalls == 1) {
            return firstStreamController.stream;
          }
          return Stream<Either<Failure, ChatMessage>>.value(
            Right(assistantAfterFollowUp),
          );
        };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.sendMessage('initial prompt');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        await provider.submitMessage('follow-up prompt');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(chatRepository.abortSessionCallCount, 0);
        expect(sendCalls, 2);
        expect(provider.state, ChatState.loaded);

        final sentFollowUp = provider.messages.whereType<UserMessage>().any((
          message,
        ) {
          return message.parts.whereType<TextPart>().any(
            (part) => part.text == 'follow-up prompt',
          );
        });
        expect(sentFollowUp, isTrue);
      },
    );

    test(
      'submitMessage keeps busy follow-ups as separate sends instead of batching',
      () async {
        final firstStreamController =
            StreamController<Either<Failure, ChatMessage>>();
        addTearDown(() async {
          await firstStreamController.close();
        });

        final assistantAfterFollowUp = AssistantMessage(
          id: 'msg_after_unbatched_follow_up',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(5200),
          completedTime: DateTime.fromMillisecondsSinceEpoch(5300),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_after_unbatched_follow_up',
              messageId: 'msg_after_unbatched_follow_up',
              sessionId: 'ses_1',
              text: 'latest follow-up delivered',
            ),
          ],
        );

        var sendCalls = 0;
        final sentTexts = <String>[];
        chatRepository.sendMessageHandler = (_, _, input, _) {
          sendCalls += 1;
          final text = input.parts
              .whereType<TextInputPart>()
              .map((part) => part.text)
              .join('\n');
          sentTexts.add(text);
          if (sendCalls == 1) {
            return firstStreamController.stream;
          }
          return Stream<Either<Failure, ChatMessage>>.value(
            Right(assistantAfterFollowUp),
          );
        };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.sendMessage('initial prompt');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        await provider.submitMessage('follow-up one');
        await provider.submitMessage('follow-up two');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(chatRepository.abortSessionCallCount, 0);
        expect(sendCalls, 3);
        expect(sentTexts, <String>[
          'initial prompt',
          'follow-up one',
          'follow-up two',
        ]);
      },
    );

    test('submitMessage preserves shell mode for busy follow-ups', () async {
      final firstStreamController =
          StreamController<Either<Failure, ChatMessage>>();
      addTearDown(() async {
        await firstStreamController.close();
      });
      final assistantAfterShellFollowUp = AssistantMessage(
        id: 'msg_after_busy_shell_follow_up',
        sessionId: 'ses_1',
        time: DateTime.fromMillisecondsSinceEpoch(7200),
        completedTime: DateTime.fromMillisecondsSinceEpoch(7300),
        parts: const <MessagePart>[
          TextPart(
            id: 'part_after_busy_shell_follow_up',
            messageId: 'msg_after_busy_shell_follow_up',
            sessionId: 'ses_1',
            text: 'shell follow-up delivered',
          ),
        ],
      );

      var sendCalls = 0;
      chatRepository.sendMessageHandler = (_, _, _, _) {
        sendCalls += 1;
        if (sendCalls == 1) {
          return firstStreamController.stream;
        }
        return Stream<Either<Failure, ChatMessage>>.value(
          Right(assistantAfterShellFollowUp),
        );
      };

      await provider.projectProvider.initializeProject();
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);

      await provider.sendMessage('initial prompt');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await provider.submitMessage('ls -la', shellMode: true);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(chatRepository.abortSessionCallCount, 0);
      expect(sendCalls, 2);
      final dispatchedText = chatRepository.lastSendInput?.parts
          .whereType<TextInputPart>()
          .map((part) => part.text)
          .join('\n');
      expect(dispatchedText, 'ls -la');
      expect(chatRepository.lastSendInput?.mode, 'shell');
    });

    test(
      'abortActiveResponse suppresses abort-like errors identified by code-only payload',
      () async {
        final streamController =
            StreamController<Either<Failure, ChatMessage>>();
        addTearDown(() async {
          await streamController.close();
        });
        chatRepository.sendMessageHandler = (_, _, _, _) =>
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
                'data': <String, dynamic>{'code': 'request_aborted'},
              },
            },
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(provider.state, ChatState.loaded);
        expect(provider.errorMessage, isNull);
        final errorBubbles = provider.messages
            .whereType<AssistantMessage>()
            .where((message) => message.error != null)
            .toList(growable: false);
        expect(errorBubbles, isEmpty);
      },
    );

    test('session.error after stop still surfaces non-abort errors', () async {
      final streamController = StreamController<Either<Failure, ChatMessage>>();
      addTearDown(() async {
        await streamController.close();
      });
      chatRepository.sendMessageHandler = (_, _, _, _) =>
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

      expect(provider.state, ChatState.loaded);
      expect(provider.errorMessage, isNull);
      final inlineErrorMessage = provider.messages.last as AssistantMessage;
      expect(inlineErrorMessage.error, isNotNull);
      expect(inlineErrorMessage.error!.name, 'Rate limit exceeded');
      expect(
        inlineErrorMessage.error!.message,
        'Rate limit exceeded. Wait a moment and try again.',
      );
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

        chatRepository.sendMessageHandler = (_, _, _, _) async* {
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

    test('sendMessage does not forward local messageId to server', () async {
      final now = DateTime.now();
      String? echoedMessageId;

      chatRepository.sendMessageHandler = (_, _, input, _) async* {
        echoedMessageId = input.messageId;
        yield Right(
          UserMessage(
            id: 'msg_server_user_1',
            sessionId: 'ses_1',
            time: now.add(const Duration(seconds: 1)),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_user_server_1',
                messageId: 'msg_server_user_1',
                sessionId: 'ses_1',
                text: 'hello stable id',
              ),
            ],
          ),
        );
      };

      await provider.projectProvider.initializeProject();
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);

      await provider.sendMessage('hello stable id');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // messageId must not be sent to the server.
      expect(echoedMessageId, isNull);
      expect(provider.state, ChatState.loaded);
      // Reconciliation by content signature deduplicates the optimistic message.
      expect(provider.messages.whereType<UserMessage>(), hasLength(1));
      final userMessage = provider.messages.single as UserMessage;
      expect(userMessage.id, 'msg_server_user_1');
      expect((userMessage.parts.single as TextPart).text, 'hello stable id');
    });

    test(
      'sendMessage dedupes optimistic attachment message when server file URL differs',
      () async {
        final now = DateTime.now();
        final serverUserMessage = UserMessage(
          id: 'msg_server_user_attachment_1',
          sessionId: 'ses_1',
          time: now.add(const Duration(seconds: 1)),
          parts: const <MessagePart>[
            FilePart(
              id: 'prt_user_server_file_1',
              messageId: 'msg_server_user_attachment_1',
              sessionId: 'ses_1',
              url: 'file:///tmp/uploaded/image.png',
              mime: 'image/png',
              filename: 'image.png',
            ),
          ],
        );
        final assistantCompleted = AssistantMessage(
          id: 'msg_assistant_attachment_dedupe',
          sessionId: 'ses_1',
          time: now.add(const Duration(seconds: 2)),
          completedTime: now.add(const Duration(seconds: 3)),
          parts: const <MessagePart>[
            TextPart(
              id: 'prt_assistant_attachment_dedupe',
              messageId: 'msg_assistant_attachment_dedupe',
              sessionId: 'ses_1',
              text: 'attachment dedupe ok',
            ),
          ],
        );

        chatRepository.sendMessageHandler = (_, _, _, _) async* {
          yield Right(serverUserMessage);
          await Future<void>.delayed(const Duration(milliseconds: 1));
          yield Right(assistantCompleted);
        };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.sendMessage(
          '',
          attachments: const <FileInputPart>[
            FileInputPart(
              mime: 'image/png',
              url: 'data:image/png;base64,AA==',
              filename: 'image.png',
            ),
          ],
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(provider.state, ChatState.loaded);
        expect(provider.messages.length, 2);
        expect(provider.messages.first.id, 'msg_server_user_attachment_1');
        expect((provider.messages.first as UserMessage).parts, hasLength(1));
        final firstPart =
            (provider.messages.first as UserMessage).parts.first as FilePart;
        expect(firstPart.mime, 'image/png');
        expect(firstPart.filename, 'image.png');
        expect(provider.messages.last.id, 'msg_assistant_attachment_dedupe');
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
                models: <String, Model>{'model_a': testModel('model_a')},
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
        chatRepository.sendMessageHandler = (_, _, _, _) async* {
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
                models: <String, Model>{'model_a': testModel('model_a')},
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
        chatRepository.sendMessageHandler = (_, _, _, _) async* {
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

    test(
      'message.part.updated applies text delta locally without fallback fetch',
      () async {
        const initialPart = TextPart(
          id: 'prt_delta_text',
          messageId: 'msg_delta_text',
          sessionId: 'ses_1',
          text: 'Draft',
        );
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          AssistantMessage(
            id: 'msg_delta_text',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            parts: const <MessagePart>[initialPart],
          ),
        ];

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.initializeProviders();

        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          AssistantMessage(
            id: 'msg_delta_text',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            parts: const <MessagePart>[],
          ),
        ];

        chatRepository.emitEvent(
          ChatEvent(
            type: 'message.part.updated',
            properties: <String, dynamic>{
              'part': MessagePartModel.fromDomain(
                const TextPart(
                  id: 'prt_delta_text',
                  messageId: 'msg_delta_text',
                  sessionId: 'ses_1',
                  text: ' answer',
                ),
              ).toJson(),
              'delta': ' answer',
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        final assistant = provider.messages.single as AssistantMessage;
        final textPart = assistant.parts.single as TextPart;
        expect(textPart.text, 'Draft answer');
      },
    );

    test(
      'message.part.updated ignores the next stale overlapping delta after a coalesced snapshot',
      () async {
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          AssistantMessage(
            id: 'msg_overlap_text',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_overlap_text',
                messageId: 'msg_overlap_text',
                sessionId: 'ses_1',
                text: 'Draft',
              ),
            ],
          ),
        ];

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.initializeProviders();

        chatRepository.emitEvent(
          ChatEvent(
            type: 'message.part.updated',
            properties: <String, dynamic>{
              'part': MessagePartModel.fromDomain(
                const TextPart(
                  id: 'prt_overlap_text',
                  messageId: 'msg_overlap_text',
                  sessionId: 'ses_1',
                  text: 'Draft answer',
                ),
              ).toJson(),
              'delta': ' answer',
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        chatRepository.emitEvent(
          ChatEvent(
            type: 'message.part.updated',
            properties: <String, dynamic>{
              'part': MessagePartModel.fromDomain(
                const TextPart(
                  id: 'prt_overlap_text',
                  messageId: 'msg_overlap_text',
                  sessionId: 'ses_1',
                  text: ' answer',
                ),
              ).toJson(),
              'delta': ' answer',
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final assistant = provider.messages.single as AssistantMessage;
        final textPart = assistant.parts.single as TextPart;
        expect(textPart.text, 'Draft answer');
      },
    );

    test(
      'refreshActiveSessionView does not duplicate user message reconciled by exact id',
      () async {
        final now = DateTime.now();
        // Simulate the duplication bug: the local optimistic user message has a
        // different ID than the server-echoed version. During an active stream,
        // _mergeServerMessagesWithActiveLocalTail must not re-append the local
        // message after _mergeServerMessagesWithPendingLocalUsers reconciled it.
        final streamController =
            StreamController<Either<Failure, ChatMessage>>();
        addTearDown(() async {
          await streamController.close();
        });

        chatRepository.sendMessageHandler = (_, _, _, _) {
          // Emit the server user message echo, then keep the stream open
          // (simulating an in-progress assistant response / tool calls).
          streamController.add(
            Right(
              UserMessage(
                id: 'msg_server_user',
                sessionId: 'ses_1',
                time: now.add(const Duration(seconds: 1)),
                parts: const <MessagePart>[
                  TextPart(
                    id: 'prt_server_user',
                    messageId: 'msg_server_user',
                    sessionId: 'ses_1',
                    text: 'hello dedup active',
                  ),
                ],
              ),
            ),
          );
          // Emit a partial (in-progress) assistant to keep session "active".
          streamController.add(
            Right(
              AssistantMessage(
                id: 'msg_assistant_partial',
                sessionId: 'ses_1',
                time: now.add(const Duration(seconds: 2)),
                // No completedTime — this marks it as in-progress.
                parts: const <MessagePart>[
                  TextPart(
                    id: 'prt_assistant_partial',
                    messageId: 'msg_assistant_partial',
                    sessionId: 'ses_1',
                    text: 'thinking...',
                  ),
                ],
              ),
            ),
          );
          return streamController.stream;
        };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.sendMessage('hello dedup active');
        await Future<void>.delayed(const Duration(milliseconds: 30));

        // Verify the stream is still open and the session is actively
        // responding (prerequisite for the tail preservation code path).
        expect(provider.isCurrentSessionActivelyResponding, isTrue);

        // Set up messagesBySession to return the server-side view (different
        // user message ID, same text). This is what refreshActiveSessionView
        // will fetch from getChatMessages.
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          UserMessage(
            id: 'msg_server_user',
            sessionId: 'ses_1',
            time: now.add(const Duration(seconds: 1)),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_server_user',
                messageId: 'msg_server_user',
                sessionId: 'ses_1',
                text: 'hello dedup active',
              ),
            ],
          ),
          AssistantMessage(
            id: 'msg_assistant_partial',
            sessionId: 'ses_1',
            time: now.add(const Duration(seconds: 2)),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_assistant_partial',
                messageId: 'msg_assistant_partial',
                sessionId: 'ses_1',
                text: 'still thinking...',
              ),
            ],
          ),
        ];

        // Trigger the merge via refresh — this is where the duplication
        // happened before the fix.
        await provider.refresh();
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // There must be exactly one UserMessage (the server version).
        final userMessages = provider.messages
            .whereType<UserMessage>()
            .toList();
        expect(
          userMessages,
          hasLength(1),
          reason: 'User message was duplicated during active session refresh',
        );
        expect(userMessages.single.id, 'msg_server_user');

        // Assistant tail message must also stay de-duplicated after refresh.
        final assistantMessages = provider.messages
            .whereType<AssistantMessage>()
            .toList();
        expect(
          assistantMessages,
          hasLength(1),
          reason:
              'Assistant message was duplicated during active session refresh',
        );
        expect(assistantMessages.single.id, 'msg_assistant_partial');
        expect(
          (assistantMessages.single.parts.single as TextPart).text,
          'still thinking...',
        );
      },
    );

    test(
      'refreshActiveSessionView keeps single user bubble when snapshot user is partial and stream later updates same server id',
      () async {
        final streamController =
            StreamController<Either<Failure, ChatMessage>>();
        addTearDown(() async {
          await streamController.close();
        });

        chatRepository.sendMessageHandler = (_, _, _, _) {
          return streamController.stream;
        };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.sendMessage('hello duplicate placeholder');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(provider.isCurrentSessionActivelyResponding, isTrue);

        final localUserMessage = provider.messages
            .whereType<UserMessage>()
            .single;
        final now = localUserMessage.time;

        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          UserMessage(
            id: 'msg_server_user_partial',
            sessionId: 'ses_1',
            time: now.add(const Duration(milliseconds: 1)),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_server_user_partial',
                messageId: 'msg_server_user_partial',
                sessionId: 'ses_1',
                text: 'hello duplicate',
              ),
            ],
          ),
          AssistantMessage(
            id: 'msg_assistant_partial_race',
            sessionId: 'ses_1',
            time: now.add(const Duration(milliseconds: 2)),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_assistant_partial_race',
                messageId: 'msg_assistant_partial_race',
                sessionId: 'ses_1',
                text: 'working...',
              ),
            ],
          ),
        ];

        await provider.refresh();
        await Future<void>.delayed(const Duration(milliseconds: 10));

        var userMessages = provider.messages.whereType<UserMessage>().toList();
        expect(
          userMessages,
          hasLength(1),
          reason:
              'Transient duplicate user bubble appeared during busy snapshot merge',
        );
        expect(
          userMessages.single.id == 'msg_server_user_partial' ||
              userMessages.single.id.startsWith('local_user_'),
          isTrue,
        );

        streamController.add(
          Right(
            UserMessage(
              id: 'msg_server_user_partial',
              sessionId: 'ses_1',
              time: now.add(const Duration(milliseconds: 1)),
              parts: const <MessagePart>[
                TextPart(
                  id: 'prt_server_user_full',
                  messageId: 'msg_server_user_partial',
                  sessionId: 'ses_1',
                  text: 'hello duplicate placeholder',
                ),
              ],
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        userMessages = provider.messages.whereType<UserMessage>().toList();
        expect(
          userMessages.where(
            (message) => message.id == 'msg_server_user_partial',
          ),
          hasLength(1),
        );
        expect(userMessages.last.id, 'msg_server_user_partial');
        expect(
          (userMessages.last.parts.single as TextPart).text,
          'hello duplicate placeholder',
        );
      },
    );

    test(
      'loadMessages keeps pending reconciliation for late server user echo',
      () async {
        final now = DateTime.now();
        final streamController =
            StreamController<Either<Failure, ChatMessage>>();
        addTearDown(() async {
          await streamController.close();
        });

        chatRepository.sendMessageHandler = (_, _, _, _) {
          return streamController.stream;
        };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.sendMessage('hello late echo');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        chatRepository.messagesBySession['ses_1'] = const <ChatMessage>[];
        await provider.loadMessages('ses_1', preserveVisibleState: true);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        streamController.add(
          Right(
            UserMessage(
              id: 'msg_server_user_late',
              sessionId: 'ses_1',
              time: now.add(const Duration(seconds: 1)),
              parts: const <MessagePart>[
                TextPart(
                  id: 'prt_server_user_late',
                  messageId: 'msg_server_user_late',
                  sessionId: 'ses_1',
                  text: 'hello late echo',
                ),
              ],
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        final userMessages = provider.messages
            .whereType<UserMessage>()
            .toList();
        expect(userMessages, hasLength(1));
        expect(userMessages.single.id, 'msg_server_user_late');
      },
    );

    test(
      'refreshActiveSessionView does not duplicate user message when content-signature match fails (empty server parts)',
      () async {
        // Scenario: server echoes a UserMessage with empty parts during an
        // active session. The content-signature reconciliation fails but the
        // tail-append guard must still prevent re-adding the local copy.
        final now = DateTime.now();
        final streamController =
            StreamController<Either<Failure, ChatMessage>>();
        addTearDown(() async {
          await streamController.close();
        });

        chatRepository.sendMessageHandler = (_, _, _, _) {
          // Emit user echo with empty parts (simulates the race).
          streamController.add(
            Right(
              UserMessage(
                id: 'msg_server_user_empty',
                sessionId: 'ses_1',
                time: now.add(const Duration(seconds: 1)),
                parts: const <MessagePart>[],
              ),
            ),
          );
          // Emit partial assistant to keep session active.
          streamController.add(
            Right(
              AssistantMessage(
                id: 'msg_assistant_empty_race',
                sessionId: 'ses_1',
                time: now.add(const Duration(seconds: 2)),
                parts: const <MessagePart>[
                  TextPart(
                    id: 'prt_assistant_empty_race',
                    messageId: 'msg_assistant_empty_race',
                    sessionId: 'ses_1',
                    text: 'working...',
                  ),
                ],
              ),
            ),
          );
          return streamController.stream;
        };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.sendMessage('hello empty race');
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(provider.isCurrentSessionActivelyResponding, isTrue);

        // Server view returns the empty-parts user message.
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          UserMessage(
            id: 'msg_server_user_empty',
            sessionId: 'ses_1',
            time: now.add(const Duration(seconds: 1)),
            parts: const <MessagePart>[],
          ),
          AssistantMessage(
            id: 'msg_assistant_empty_race',
            sessionId: 'ses_1',
            time: now.add(const Duration(seconds: 2)),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_assistant_empty_race',
                messageId: 'msg_assistant_empty_race',
                sessionId: 'ses_1',
                text: 'still working...',
              ),
            ],
          ),
        ];

        await provider.refresh();
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Must not duplicate: either the local message was replaced by
        // time-proximity (Fix 2) or the tail guard skips it (Fix 1).
        final userMessages = provider.messages
            .whereType<UserMessage>()
            .toList();
        expect(
          userMessages,
          hasLength(1),
          reason:
              'User message duplicated during active refresh with empty server parts',
        );
      },
    );

    test(
      'refreshActiveSessionView preserves later optimistic turn when same-text overlap is ambiguous',
      () async {
        final firstStream = StreamController<Either<Failure, ChatMessage>>();
        final secondStream = StreamController<Either<Failure, ChatMessage>>();
        addTearDown(() async {
          await firstStream.close();
          await secondStream.close();
        });

        var sendCalls = 0;
        chatRepository.sendMessageHandler = (_, _, _, _) {
          sendCalls += 1;
          return sendCalls == 1 ? firstStream.stream : secondStream.stream;
        };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.sendMessage('same duplicate text');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await provider.sendMessage('same duplicate text');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final localUsersBeforeRefresh = provider.messages
            .whereType<UserMessage>()
            .toList();
        expect(localUsersBeforeRefresh, hasLength(2));

        final firstLocalUser = localUsersBeforeRefresh.first;
        final now = firstLocalUser.time;
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          UserMessage(
            id: 'msg_server_same_text_first',
            sessionId: 'ses_1',
            time: now.add(const Duration(milliseconds: 1)),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_server_same_text_first',
                messageId: 'msg_server_same_text_first',
                sessionId: 'ses_1',
                text: 'same duplicate text',
              ),
            ],
          ),
          AssistantMessage(
            id: 'msg_server_same_text_partial',
            sessionId: 'ses_1',
            time: now.add(const Duration(milliseconds: 2)),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_server_same_text_partial',
                messageId: 'msg_server_same_text_partial',
                sessionId: 'ses_1',
                text: 'still working...',
              ),
            ],
          ),
        ];

        await provider.refreshActiveSessionView(
          reason: 'ambiguous-same-text-optimistic-overlap',
          includeStatus: false,
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final userMessages = provider.messages
            .whereType<UserMessage>()
            .toList();
        expect(userMessages.length, inInclusiveRange(1, 2));
        expect(userMessages.first.id, 'msg_server_same_text_first');
        if (userMessages.length == 2) {
          expect(
            userMessages.last.id.startsWith('local_user_'),
            isTrue,
            reason:
                'When the optimistic turn is still visible, it must remain the trailing local entry',
          );
        }
      },
    );

    test(
      'refreshActiveSessionView does not duplicate shell-mode user message with ! prefix',
      () async {
        // Scenario: local message text is '!ls -la' (shell mode), server echoes
        // 'ls -la' (without !). The shell-aware signature normalization must
        // reconcile them so no duplicate appears.
        final now = DateTime.now();
        final streamController =
            StreamController<Either<Failure, ChatMessage>>();
        addTearDown(() async {
          await streamController.close();
        });

        chatRepository.sendMessageHandler = (_, _, _, _) {
          // Server echoes the user message without the leading '!'.
          streamController.add(
            Right(
              UserMessage(
                id: 'msg_server_user_shell',
                sessionId: 'ses_1',
                time: now.add(const Duration(seconds: 1)),
                parts: const <MessagePart>[
                  TextPart(
                    id: 'prt_server_user_shell',
                    messageId: 'msg_server_user_shell',
                    sessionId: 'ses_1',
                    text: 'ls -la',
                  ),
                ],
              ),
            ),
          );
          streamController.add(
            Right(
              AssistantMessage(
                id: 'msg_assistant_shell',
                sessionId: 'ses_1',
                time: now.add(const Duration(seconds: 2)),
                parts: const <MessagePart>[
                  TextPart(
                    id: 'prt_assistant_shell',
                    messageId: 'msg_assistant_shell',
                    sessionId: 'ses_1',
                    text: 'running command...',
                  ),
                ],
              ),
            ),
          );
          return streamController.stream;
        };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.sendMessage('ls -la', shellMode: true);
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(provider.isCurrentSessionActivelyResponding, isTrue);

        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          UserMessage(
            id: 'msg_server_user_shell',
            sessionId: 'ses_1',
            time: now.add(const Duration(seconds: 1)),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_server_user_shell',
                messageId: 'msg_server_user_shell',
                sessionId: 'ses_1',
                text: 'ls -la',
              ),
            ],
          ),
          AssistantMessage(
            id: 'msg_assistant_shell',
            sessionId: 'ses_1',
            time: now.add(const Duration(seconds: 2)),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_assistant_shell',
                messageId: 'msg_assistant_shell',
                sessionId: 'ses_1',
                text: 'running command...',
              ),
            ],
          ),
        ];

        await provider.refresh();
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final userMessages = provider.messages
            .whereType<UserMessage>()
            .toList();
        expect(
          userMessages,
          hasLength(1),
          reason:
              'Shell-mode user message duplicated during active session refresh',
        );
        expect(userMessages.single.id, 'msg_server_user_shell');
      },
    );

    test(
      'tail-append loop skips pending local user message when server has content-equivalent message',
      () async {
        // Scenario: content-signature reconciliation succeeds for the message
        // text but reconciledLocalIds is somehow not propagated (edge case).
        // The tail-append guard must independently prevent the duplication.
        final now = DateTime.now();
        final streamController =
            StreamController<Either<Failure, ChatMessage>>();
        addTearDown(() async {
          await streamController.close();
        });

        chatRepository.sendMessageHandler = (_, _, _, _) {
          streamController.add(
            Right(
              UserMessage(
                id: 'msg_server_user_tail',
                sessionId: 'ses_1',
                time: now.add(const Duration(seconds: 1)),
                parts: const <MessagePart>[
                  TextPart(
                    id: 'prt_server_user_tail',
                    messageId: 'msg_server_user_tail',
                    sessionId: 'ses_1',
                    text: 'hello tail guard',
                  ),
                ],
              ),
            ),
          );
          streamController.add(
            Right(
              AssistantMessage(
                id: 'msg_assistant_tail',
                sessionId: 'ses_1',
                time: now.add(const Duration(seconds: 2)),
                parts: const <MessagePart>[
                  TextPart(
                    id: 'prt_assistant_tail',
                    messageId: 'msg_assistant_tail',
                    sessionId: 'ses_1',
                    text: 'processing...',
                  ),
                ],
              ),
            ),
          );
          return streamController.stream;
        };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.sendMessage('hello tail guard');
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(provider.isCurrentSessionActivelyResponding, isTrue);

        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          UserMessage(
            id: 'msg_server_user_tail',
            sessionId: 'ses_1',
            time: now.add(const Duration(seconds: 1)),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_server_user_tail',
                messageId: 'msg_server_user_tail',
                sessionId: 'ses_1',
                text: 'hello tail guard',
              ),
            ],
          ),
        ];

        // Refresh — server has user message but no assistant yet. The local
        // tail must keep the in-progress assistant but NOT re-add the local
        // user message that matches the server version by content.
        await provider.refresh();
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final userMessages = provider.messages
            .whereType<UserMessage>()
            .toList();
        expect(
          userMessages,
          hasLength(1),
          reason:
              'Pending local user message leaked through tail-append despite server content match',
        );
        expect(userMessages.single.id, 'msg_server_user_tail');

        // The streamed assistant must still be preserved in the local tail.
        final assistantMessages = provider.messages
            .whereType<AssistantMessage>()
            .toList();
        expect(assistantMessages, hasLength(1));
        expect(assistantMessages.single.id, 'msg_assistant_tail');
      },
    );

    group('issue 143 - pending question rehydration', () {
      ChatQuestionRequest questionFor(String sessionId, String id) {
        return ChatQuestionRequest(
          id: id,
          sessionId: sessionId,
          questions: <ChatQuestionInfo>[
            ChatQuestionInfo(
              question: 'Proceed?',
              header: 'Confirm',
              options: <ChatQuestionOption>[
                ChatQuestionOption(label: 'Yes', description: 'Continue'),
              ],
            ),
          ],
        );
      }

      Future<void> settleEmptyInteractions() => settleUntil(
            () =>
                provider.currentSessionQuestions.isEmpty &&
                provider.currentSessionPermissions.isEmpty,
            reason: 'Expected initial interactions to settle.',
          );

      Future<void> settleRealtimeSubscription() => settleUntil(
            () => provider.debugHasRealtimeEventSubscription,
            reason: 'Expected realtime subscription to start.',
          );

      test('normal mode session re-entry reloads pending questions', () async {
        chatRepository = FakeChatRepository(
          sessions: <ChatSession>[
            ChatSession(
              id: 'ses_1',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              title: 'Session 1',
            ),
            ChatSession(
              id: 'ses_2',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(2000),
              title: 'Session 2',
            ),
          ],
        );
        provider = buildProvider();
        provider.debugPendingQuestionsRetryBaseDelay = Duration.zero;
        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        final first = provider.sessions.firstWhere((s) => s.id == 'ses_1');
        await provider.selectSession(first);
        await provider.refresh();
        await settleEmptyInteractions();

        final target = provider.sessions.firstWhere((s) => s.id == 'ses_2');
        chatRepository.pendingQuestions = <ChatQuestionRequest>[
          questionFor('ses_2', 'question_reentry'),
        ];

        await provider.selectSession(target);

        await settleUntil(
          () =>
              provider.currentSessionQuestions.singleOrNull?.id ==
              'question_reentry',
          reason:
              'Expected normal-mode session re-entry to revalidate pending questions.',
        );
      });

      test('normal mode re-selecting current session revalidates questions', () async {
        provider = buildProvider();
        provider.debugPendingQuestionsRetryBaseDelay = Duration.zero;
        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        final first = provider.sessions.firstWhere((s) => s.id == 'ses_1');
        await provider.selectSession(first);
        await provider.refresh();
        await settleEmptyInteractions();

        chatRepository.pendingQuestions = <ChatQuestionRequest>[
          questionFor('ses_1', 'question_reselect'),
        ];

        await provider.selectSession(first);

        await settleUntil(
          () =>
              provider.currentSessionQuestions.singleOrNull?.id ==
              'question_reselect',
          reason:
              'Expected re-selecting the current session to revalidate pending questions.',
        );
      });

      test('failed pending questions fetch retries with bounded backoff', () async {
        provider = buildProvider();
        provider.debugPendingQuestionsRetryBaseDelay = Duration.zero;
        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        final first = provider.sessions.firstWhere((s) => s.id == 'ses_1');
        await provider.selectSession(first);
        await provider.refresh();
        await settleEmptyInteractions();

        chatRepository.listQuestionsCallCount = 0;
        chatRepository.listQuestionsFailure = ServerFailure(
          'transient failure',
        );
        chatRepository.pendingQuestions = <ChatQuestionRequest>[
          questionFor('ses_1', 'question_retry'),
        ];

        await provider.reloadPendingInteractionsForTest();
        await settleUntil(
          () => chatRepository.listQuestionsCallCount >= 2,
          reason: 'Expected a bounded retry after the failed questions fetch.',
        );

        chatRepository.listQuestionsFailure = null;
        await provider.reloadPendingInteractionsForTest();
        await settleUntil(
          () =>
              provider.currentSessionQuestions.singleOrNull?.id ==
              'question_retry',
          reason:
              'Expected the retried fetch to surface the pending question.',
        );
      });

      test('question stays rehydratable after a failed reply attempt', () async {
        provider = buildProvider();
        provider.debugPendingQuestionsRetryBaseDelay = Duration.zero;
        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        final first = provider.sessions.firstWhere((s) => s.id == 'ses_1');
        await provider.selectSession(first);
        await provider.refresh();
        chatRepository.pendingQuestions = <ChatQuestionRequest>[
          questionFor('ses_1', 'question_retryable'),
        ];
        await provider.reloadPendingInteractionsForTest();
        await settleUntil(
          () =>
              provider.currentSessionQuestions.singleOrNull?.id ==
              'question_retryable',
          reason: 'Expected the pending question to be visible.',
        );

        // A transport-level exception (not a Left failure) must not leave a
        // tombstone behind that hides the still-pending question on the next
        // rehydration.
        chatRepository.replyQuestionThrow = StateError('transport dropped');
        await expectLater(
          provider.submitQuestionAnswers(
            requestId: 'question_retryable',
            answers: const <List<String>>[<String>['Yes']],
          ),
          throwsA(isA<StateError>()),
        );

        expect(
          provider.currentSessionQuestions.singleOrNull?.id,
          'question_retryable',
          reason:
              'Expected the failed reply to keep the question visible for retry.',
        );

        await provider.reloadPendingInteractionsForTest();
        expect(
          provider.currentSessionQuestions.singleOrNull?.id,
          'question_retryable',
          reason:
              'Rehydration must not suppress a question whose reply failed.',
        );
      });

      test('pending questions merge treats server list as authoritative', () async {
        provider = buildProvider();
        provider.debugPendingQuestionsRetryBaseDelay = Duration.zero;
        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        final first = provider.sessions.firstWhere((s) => s.id == 'ses_1');
        await provider.selectSession(first);
        await provider.refresh();
        await settleEmptyInteractions();
        await settleRealtimeSubscription();

        // A question arrives via SSE while the server list may not have
        // caught up yet.
        chatRepository.emitEvent(
          ChatEvent(
            type: 'question.asked',
            properties: <String, dynamic>{
              'question': <String, dynamic>{
                'id': 'question_sse',
                'sessionID': 'ses_1',
                'questions': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'question': 'Proceed?',
                    'header': 'Confirm',
                    'options': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'label': 'Yes',
                        'description': 'Continue',
                      },
                    ],
                    'multiple': false,
                    'custom': false,
                  },
                ],
              },
            },
          ),
        );
        await settleUntil(
          () =>
              provider.currentSessionQuestions.singleOrNull?.id ==
              'question_sse',
          reason: 'Expected the SSE question to appear.',
        );

        // Server no longer lists it (resolved elsewhere): within the grace
        // window the fresh SSE arrival survives a rehydration race.
        provider.debugQuestionServerAuthorityGrace = const Duration(hours: 1);
        chatRepository.pendingQuestions = const <ChatQuestionRequest>[];
        await provider.reloadPendingInteractionsForTest();
        expect(
          provider.currentSessionQuestions.singleOrNull?.id,
          'question_sse',
          reason:
              'Fresh SSE-arrived questions must survive within the grace window.',
        );

        // Past the grace window the server list is authoritative for removal.
        provider.debugQuestionServerAuthorityGrace = Duration.zero;
        await provider.reloadPendingInteractionsForTest();
        expect(provider.currentSessionQuestions, isEmpty);
      });
    });
  });
}

class _RecordingEventFeedbackDispatcher extends EventFeedbackDispatcher {
  _RecordingEventFeedbackDispatcher({required super.settingsProvider})
    : super(
        notificationService: NotificationService(assumeInitialized: true),
        soundService: SoundService(),
      );

  final List<String> handledTypes = <String>[];
  final List<String> dismissedSessionIds = <String>[];
  String? lastCurrentSessionId;

  void clear() {
    handledTypes.clear();
    dismissedSessionIds.clear();
    lastCurrentSessionId = null;
  }

  @override
  Future<void> handle(
    ChatEvent event, {
    String? sessionTitleHint,
    bool isRootSession = true,
    bool isAppInForeground = true,
    String? currentSessionId,
  }) async {
    handledTypes.add(event.type);
    lastCurrentSessionId = currentSessionId;
  }

  @override
  Future<void> dismissForSession(String sessionId) async {
    dismissedSessionIds.add(sessionId);
  }
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

class _FakeChatTitleGenerator extends ChatTitleGenerator {
  int callCount = 0;
  int cancelPendingWaitersCallCount = 0;
  final List<String> idleSessionIds = <String>[];
  final List<String?> idleDirectories = <String?>[];
  final List<List<ChatTitleGeneratorMessage>> payloads =
      <List<ChatTitleGeneratorMessage>>[];

  @override
  void notifySessionIdle({required String sessionId, String? directory}) {
    idleSessionIds.add(sessionId);
    idleDirectories.add(directory);
  }

  @override
  void cancelPendingWaiters() {
    cancelPendingWaitersCallCount += 1;
  }

  @override
  Future<String?> generateTitle(
    List<ChatTitleGeneratorMessage> messages, {
    int maxWords = 6,
    String? directory,
  }) async {
    callCount += 1;
    payloads.add(List<ChatTitleGeneratorMessage>.from(messages));
    return 'Auto title $callCount';
  }
}

class _BlockingChatTitleGenerator extends ChatTitleGenerator {
  _BlockingChatTitleGenerator(this._completer);

  final Completer<String?> _completer;
  int callCount = 0;

  @override
  Future<String?> generateTitle(
    List<ChatTitleGeneratorMessage> messages, {
    int maxWords = 6,
    String? directory,
  }) {
    callCount += 1;
    return _completer.future;
  }
}
