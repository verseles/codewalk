@Tags(<String>['slow'])
library;

import 'dart:async';

import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/data/models/chat_message_model.dart';
import 'package:codewalk/domain/entities/agent.dart';
import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/domain/entities/provider.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import 'chat_provider_test_support.dart';

void main() {
  group('ChatProvider - concurrency', () {
    late FakeChatRepository chatRepository;
    late FakeAppRepository appRepository;
    late InMemoryAppLocalDataSource localDataSource;
    late ChatProvider provider;
    late SettingsProvider defaultSettingsProvider;
    final ownedProviders = <ChatProvider>[];

    ChatProvider buildProvider({
      DioClient? dioClient,
      Duration syncHealthCheckInterval = const Duration(seconds: 5),
      Duration abortSuppressionWindow = const Duration(milliseconds: 30),
      DateTime Function()? abortSuppressionNow,
      SettingsProvider? settingsProvider,
    }) {
      final created = buildChatProvider(
        chatRepository: chatRepository,
        appRepository: appRepository,
        localDataSource: localDataSource,
        defaultSettingsProvider: defaultSettingsProvider,
        dioClient: dioClient,
        syncHealthCheckInterval: syncHealthCheckInterval,
        abortSuppressionWindow: abortSuppressionWindow,
        abortSuppressionNow: abortSuppressionNow,
        settingsProvider: settingsProvider,
      );
      ownedProviders.add(created);
      return created;
    }

    setUp(() async {
      final fixtures = await buildDefaultTestFixtures();
      chatRepository = fixtures.chatRepository;
      appRepository = fixtures.appRepository;
      localDataSource = fixtures.localDataSource;
      defaultSettingsProvider = fixtures.defaultSettingsProvider;
      provider = buildProvider();
    });

    tearDown(() async {
      await pumpEventQueue();
      for (final owned in ownedProviders.reversed) {
        owned.dispose();
        owned.projectProvider.dispose();
      }
      ownedProviders.clear();
      await pumpEventQueue();
      defaultSettingsProvider.dispose();
    });

    Future<void> settleUntil(bool Function() predicate, {String? reason}) async {
      for (var tick = 0; tick < 40; tick++) {
        if (predicate()) return;
        await pumpEventQueue();
      }
      fail('Expected provider state after draining the event queue.${reason == null ? '' : ' $reason'}');
    }

    group('render gate', () {
      Future<void> prepareBackgroundUpdate() async {
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_background',
            workspaceId: 'default',
            time: DateTime.utc(2026),
            title: 'Background session',
          ),
        );
        await provider.projectProvider.initializeProject();
        await provider.initializeProviders();
        await provider.loadSessions();
        await provider.selectSession(
          provider.sessions.firstWhere((session) => session.id == 'ses_1'),
        );
        await settleUntil(() => provider.debugHasRealtimeEventSubscription);
        await pumpEventQueue();
        await provider.setForegroundActive(false);
      }

      Future<void> deleteBackgroundSession() async {
        chatRepository.sessions.removeWhere(
          (session) => session.id == 'ses_background',
        );
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.deleted',
            properties: <String, dynamic>{'sessionID': 'ses_background'},
          ),
        );
        await settleUntil(
          () => !provider.sessions.any(
            (session) => session.id == 'ses_background',
          ),
        );
      }

      test(
        'setForegroundActive(false) suppresses notifyListeners from _notifyListeners',
        () async {
          await prepareBackgroundUpdate();
          var notifyCount = 0;
          provider.addListener(() {
            notifyCount += 1;
          });
          await deleteBackgroundSession();
          expect(provider.sessions.map((session) => session.id), ['ses_1']);
          expect(notifyCount, 0);
        },
      );

      test(
        'setForegroundActive(true) flushes pending render notification',
        () async {
          await prepareBackgroundUpdate();
          final snapshots = <List<String>>[];
          provider.addListener(() {
            snapshots.add(provider.sessions.map((session) => session.id).toList());
          });
          await deleteBackgroundSession();
          expect(snapshots, isEmpty);
          expect(provider.debugHasPendingRenderFlush, isTrue);
          final resuming = provider.setForegroundActive(true);
          expect(provider.debugHasPendingRenderFlush, isFalse);
          // Gated notifications are coalesced into a microtask, not emitted
          // synchronously and not delayed until network revalidation finishes.
          await Future<void>.value();
          expect(snapshots, isNotEmpty);
          expect(snapshots.first, ['ses_1']);
          await resuming;
        },
      );

      test(
        'SSE subscription is NOT cancelled when going to background',
        () async {
          await prepareBackgroundUpdate();
          expect(provider.refreshlessRealtimeEnabled, isTrue);
          expect(provider.debugHasRealtimeEventSubscription, isTrue);
          chatRepository.emitEvent(
            const ChatEvent(
              type: 'session.status',
              properties: <String, dynamic>{
                'sessionID': 'ses_1',
                'status': <String, dynamic>{'type': 'busy'},
              },
            ),
          );
          await settleUntil(
            () => provider.sessionStatusById['ses_1']?.type ==
                SessionStatusType.busy,
          );
        },
      );
    });

    group('multi-session concurrency', () {
      test(
        'selectSession invalidates generation so stale send stream callbacks are ignored',
        () async {
          chatRepository.sessions.add(
            ChatSession(
              id: 'ses_2',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(1500),
              title: 'Session 2',
            ),
          );

          final streamController =
              StreamController<Either<Failure, ChatMessage>>();
          addTearDown(() async {
            await streamController.close();
          });

          chatRepository.sendMessageHandler =
              (projectId, sessionId, input, directory) {
                return streamController.stream;
              };

          await provider.projectProvider.initializeProject();
          await provider.loadSessions();

          final session1 = provider.sessions
              .where((item) => item.id == 'ses_1')
              .first;
          final session2 = provider.sessions
              .where((item) => item.id == 'ses_2')
              .first;

          await provider.selectSession(session1);
          await provider.sendMessage('start send in A');
          await Future<void>.delayed(const Duration(milliseconds: 20));

          // Switch to B — generation should increment making A's stream stale.
          await provider.selectSession(session2);
          await Future<void>.delayed(const Duration(milliseconds: 20));

          // Emit a message from stream A — should be ignored (stale generation).
          streamController.add(
            Right(
              AssistantMessage(
                id: 'msg_stale_from_a',
                sessionId: 'ses_1',
                time: DateTime.fromMillisecondsSinceEpoch(3000),
                parts: const <MessagePart>[
                  TextPart(
                    id: 'prt_stale_from_a',
                    messageId: 'msg_stale_from_a',
                    sessionId: 'ses_1',
                    text: 'should be ignored',
                  ),
                ],
              ),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 20));

          // Current session is B and its message list should be empty.
          expect(provider.currentSession?.id, 'ses_2');
          expect(provider.messages, isEmpty);
        },
      );

      test('canceled stale stream onDone does not set session idle', () async {
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_2',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1500),
            title: 'Session 2',
          ),
        );

        final streamController =
            StreamController<Either<Failure, ChatMessage>>();
        addTearDown(() async {
          if (!streamController.isClosed) {
            await streamController.close();
          }
        });

        chatRepository.sendMessageHandler =
            (projectId, sessionId, input, directory) {
              return streamController.stream;
            };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();

        final session1 = provider.sessions
            .where((item) => item.id == 'ses_1')
            .first;
        final session2 = provider.sessions
            .where((item) => item.id == 'ses_2')
            .first;

        // Pre-set busy status for ses_1 so it persists through init.
        chatRepository.sessionStatusById = const <String, SessionStatusInfo>{
          'ses_1': SessionStatusInfo(type: SessionStatusType.busy),
        };

        await provider.selectSession(session1);
        await provider.initializeProviders();
        await provider.sendMessage('send in A');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        await provider.selectSession(session2);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Close stream A (onDone fires) — generation is stale so provider
        // should NOT mark session A as idle or change state.
        await streamController.close();
        await Future<void>.delayed(const Duration(milliseconds: 40));

        // Session B is still current and state is not unexpectedly loaded.
        expect(provider.currentSession?.id, 'ses_2');
        // Session A was not set to idle by the stale onDone; the busy status
        // from the event persists.
        expect(
          provider.sessionStatusById['ses_1']?.type,
          SessionStatusType.busy,
        );
      });

      test(
        'session.idle for a non-current session does not disrupt the current session',
        () async {
          chatRepository.sessions.add(
            ChatSession(
              id: 'ses_2',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(1500),
              title: 'Session 2',
            ),
          );

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

          final session1 = provider.sessions
              .where((item) => item.id == 'ses_1')
              .first;
          final session2 = provider.sessions
              .where((item) => item.id == 'ses_2')
              .first;

          await provider.selectSession(session1);
          await provider.sendMessage('send in A');
          await Future<void>.delayed(const Duration(milliseconds: 20));

          await provider.selectSession(session2);
          await Future<void>.delayed(const Duration(milliseconds: 20));

          // Emit session.idle for session A after switching away from it.
          chatRepository.emitEvent(
            const ChatEvent(
              type: 'session.idle',
              properties: <String, dynamic>{'sessionID': 'ses_1'},
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 40));

          // Session B is still current and unaffected.
          expect(provider.currentSession?.id, 'ses_2');
          // Session A status is idle from the event.
          expect(
            provider.sessionStatusById['ses_1']?.type,
            SessionStatusType.idle,
          );
          // Provider state should not have been disrupted.
          expect(provider.state, isNot(ChatState.error));
        },
      );

      test(
        'session.error for a non-current session keeps the current session stable',
        () async {
          chatRepository.sessions.add(
            ChatSession(
              id: 'ses_2',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(1500),
              title: 'Session 2',
            ),
          );

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

          final session1 = provider.sessions
              .where((item) => item.id == 'ses_1')
              .first;
          final session2 = provider.sessions
              .where((item) => item.id == 'ses_2')
              .first;

          await provider.selectSession(session1);
          await provider.sendMessage('send in A');
          await Future<void>.delayed(const Duration(milliseconds: 20));

          await provider.selectSession(session2);
          await Future<void>.delayed(const Duration(milliseconds: 20));

          // Emit session.error for non-current session A after switching away.
          chatRepository.emitEvent(
            const ChatEvent(
              type: 'session.error',
              properties: <String, dynamic>{
                'sessionID': 'ses_1',
                'error': <String, dynamic>{
                  'message': 'simulated background error',
                },
              },
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 40));

          // Provider state for current session B should not be affected.
          expect(provider.currentSession?.id, 'ses_2');
          expect(provider.errorMessage, isNull);
          // Session A status was set to idle by the error handler.
          expect(
            provider.sessionStatusById['ses_1']?.type,
            SessionStatusType.idle,
          );
        },
      );

      test(
        'selectSession cancels the active stream subscription and increments generation',
        () async {
          chatRepository.sessions.add(
            ChatSession(
              id: 'ses_2',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(1500),
              title: 'Session 2',
            ),
          );

          final streamController =
              StreamController<Either<Failure, ChatMessage>>();
          var streamCancelled = false;
          streamController.onCancel = () {
            streamCancelled = true;
          };
          addTearDown(() async {
            await streamController.close();
          });

          chatRepository.sendMessageHandler = (_, _, _, _) {
            return streamController.stream;
          };

          await provider.projectProvider.initializeProject();
          await provider.loadSessions();

          final session1 = provider.sessions
              .where((item) => item.id == 'ses_1')
              .first;
          final session2 = provider.sessions
              .where((item) => item.id == 'ses_2')
              .first;

          await provider.selectSession(session1);
          await provider.sendMessage('send in A');
          await Future<void>.delayed(const Duration(milliseconds: 20));

          await provider.selectSession(session2);
          await Future<void>.delayed(const Duration(milliseconds: 20));

          // Stream should be cancelled when the user leaves the session.
          expect(streamCancelled, isTrue);

          // Messages delivered on the stale stream should be ignored.
          streamController.add(
            Right(
              AssistantMessage(
                id: 'msg_after_switch',
                sessionId: 'ses_1',
                time: DateTime.fromMillisecondsSinceEpoch(3000),
                parts: const <MessagePart>[
                  TextPart(
                    id: 'prt_after_switch',
                    messageId: 'msg_after_switch',
                    sessionId: 'ses_1',
                    text: 'stale update after switch',
                  ),
                ],
              ),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 20));

          // Session B message list should remain empty.
          expect(provider.currentSession?.id, 'ses_2');
          expect(provider.messages, isEmpty);
          // Stream stays canceled after the switch.
          expect(streamCancelled, isTrue);
        },
      );
    });

    group('selection sync deferral during abort suppression', () {
      // Shared setup: 2 providers (for model switch), agent with 'build',
      // controllable send stream via StreamController, and a short
      // abortSuppressionWindow (50ms) to keep tests fast.
      late RecordingDioClient dioClient;
      late DateTime abortNow;

      setUp(() {
        abortNow = DateTime.utc(2026, 1, 1);
      });

      /// Bootstraps the provider with controllable stream support.
      /// Returns a [StreamController] that the test can close manually
      /// to trigger onDone → _startAbortSuppression.
      Future<StreamController<Either<Failure, ChatMessage>>>
      initWithControllableStream({
        Duration abortSuppressionWindow = const Duration(milliseconds: 50),
      }) async {
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': testModel('model_a')},
              ),
              Provider(
                id: 'provider_b',
                name: 'Provider B',
                env: const <String>[],
                models: <String, Model>{'model_b': testModel('model_b')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a', 'provider_b'],
          ),
        );
        appRepository.agentsResult = const Right(<Agent>[
          Agent(name: 'build', mode: 'primary', hidden: false, native: false),
        ]);

        dioClient = RecordingDioClient(
          configResponse: <String, dynamic>{
            'model': 'provider_a/model_a',
            'default_agent': 'build',
          },
        );
        provider = buildProvider(
          dioClient: dioClient,
          syncHealthCheckInterval: const Duration(milliseconds: 50),
          abortSuppressionWindow: abortSuppressionWindow,
          abortSuppressionNow: () => abortNow,
        );

        final sendStreamController =
            StreamController<Either<Failure, ChatMessage>>();

        chatRepository.sendMessageHandler =
            (projectId, sessionId, input, directory) {
              // Emit one assistant message, then leave stream open for the test
              // to close manually.
              sendStreamController.add(
                Right(
                  AssistantMessage(
                    id: 'msg_a_1',
                    sessionId: sessionId,
                    time: DateTime.now(),
                    completedTime: DateTime.now(),
                    parts: <MessagePart>[
                      TextPart(
                        id: 'p1',
                        messageId: 'msg_a_1',
                        sessionId: sessionId,
                        text: 'ok',
                      ),
                    ],
                  ),
                ),
              );
              return sendStreamController.stream;
            };

        await provider.initializeProviders();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await settleUntil(() => provider.debugHasRealtimeEventSubscription);
        dioClient.patchBodies.clear();

        return sendStreamController;
      }

      bool hasModelBPatch() {
        return dioClient.patchBodies.whereType<Map<String, dynamic>>().any((
          body,
        ) {
          final selection = selectionPayloadFromPatch(body);
          return selection?['providerId'] == 'provider_b' &&
              selection?['modelId'] == 'model_b';
        });
      }

      test('abort suppression includes its exact expiry boundary', () async {
        final sendStream = await initWithControllableStream();
        await provider.sendMessage('hello');
        await sendStream.close();
        await pumpEventQueue();

        void emitIdle() => chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.status',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'status': <String, dynamic>{'type': 'idle'},
            },
          ),
        );

        abortNow = abortNow.add(const Duration(milliseconds: 50));
        emitIdle();
        await pumpEventQueue();
        await provider.setSelectedModelByProvider(
          providerId: 'provider_b',
          modelId: 'model_b',
        );
        expect(hasModelBPatch(), isFalse);

        abortNow = abortNow.add(const Duration(microseconds: 1));
        // A repeated idle status is deduplicated; a fresh transition retries
        // the deferred selection after the policy deadline.
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.status',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'status': <String, dynamic>{'type': 'busy'},
            },
          ),
        );
        emitIdle();
        await settleUntil(hasModelBPatch);
      });

      test(
        'selection sync deferred when abort suppression is active',
        () async {
          final sendStream = await initWithControllableStream();

          // Start a send — stream stays open while the controller is open
          await provider.sendMessage('hello');
          await Future<void>.delayed(const Duration(milliseconds: 10));

          // Close stream -> triggers onDone -> _startAbortSuppression
          await sendStream.close();
          await Future<void>.delayed(const Duration(milliseconds: 10));

          // Switch model while abort suppression is active (window = 50ms)
          await provider.setSelectedModelByProvider(
            providerId: 'provider_b',
            modelId: 'model_b',
          );

          // Patch should NOT have been sent (deferred by abort suppression)
          expect(hasModelBPatch(), isFalse);
        },
      );

      test(
        'selection sync fires after abort suppression window expires',
        () async {
          final sendStream = await initWithControllableStream();

          await provider.sendMessage('hello');
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await sendStream.close();
          await Future<void>.delayed(const Duration(milliseconds: 10));

          // Switch model while suppression is active
          await provider.setSelectedModelByProvider(
            providerId: 'provider_b',
            modelId: 'model_b',
          );
          expect(hasModelBPatch(), isFalse);

          // Expire policy time independently of host scheduling.
          abortNow = abortNow.add(const Duration(milliseconds: 51));

          // Emit session.idle to trigger _attemptPendingRemoteSelectionSync
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

          // Patch should have been flushed now
          expect(hasModelBPatch(), isTrue);
        },
      );

      test(
        'selection sync deferred when SSE reports busy after window expires',
        () async {
          final sendStream = await initWithControllableStream();

          await provider.sendMessage('hello');
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await sendStream.close();
          await pumpEventQueue();

          // Completion reconciliation also polls the authoritative status map.
          // Keep that snapshot consistent with the busy SSE transition.
          chatRepository.sessionStatusById['ses_1'] =
              const SessionStatusInfo(type: SessionStatusType.busy);
          abortNow = abortNow.add(const Duration(milliseconds: 51));

          // SSE reports busy — this guard takes over from abort suppression
          chatRepository.emitEvent(
            const ChatEvent(
              type: 'session.status',
              properties: <String, dynamic>{
                'sessionID': 'ses_1',
                'status': <String, dynamic>{'type': 'busy'},
              },
            ),
          );
          await settleUntil(
            () => provider.sessionStatusById['ses_1']?.type == SessionStatusType.busy,
            reason: 'Waiting for busy SSE status.',
          );

          // Switch model while busy
          await provider.setSelectedModelByProvider(
            providerId: 'provider_b',
            modelId: 'model_b',
          );
          expect(hasModelBPatch(), isFalse);

          // SSE reports idle — flush should happen
          chatRepository.sessionStatusById['ses_1'] =
              const SessionStatusInfo(type: SessionStatusType.idle);
          chatRepository.emitEvent(
            const ChatEvent(
              type: 'session.status',
              properties: <String, dynamic>{
                'sessionID': 'ses_1',
                'status': <String, dynamic>{'type': 'idle'},
              },
            ),
          );
          await settleUntil(hasModelBPatch, reason: 'Waiting for deferred model B PATCH after idle.');
          expect(hasModelBPatch(), isTrue);
        },
      );

      test(
        'abort suppression via abortActiveResponse also defers sync',
        () async {
          final sendStream = await initWithControllableStream();

          await provider.sendMessage('hello');
          await Future<void>.delayed(const Duration(milliseconds: 10));

          // Abort while stream is open — calls _startAbortSuppression
          await provider.abortActiveResponse();
          await Future<void>.delayed(const Duration(milliseconds: 10));

          // Close the stream (abort already cancelled the subscription
          // but the controller may still be open)
          await sendStream.close();
          await Future<void>.delayed(const Duration(milliseconds: 10));

          // Switch model while abort suppression is active
          await provider.setSelectedModelByProvider(
            providerId: 'provider_b',
            modelId: 'model_b',
          );

          expect(hasModelBPatch(), isFalse);
        },
      );

      test(
        'active session A blocks sync on session B until session A is safe',
        () async {
          // Add a second session before initializing the provider
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
                  models: <String, Model>{'model_a': testModel('model_a')},
                ),
                Provider(
                  id: 'provider_b',
                  name: 'Provider B',
                  env: const <String>[],
                  models: <String, Model>{'model_b': testModel('model_b')},
                ),
              ],
              defaultModels: const <String, String>{'provider_a': 'model_a'},
              connected: const <String>['provider_a', 'provider_b'],
            ),
          );
          appRepository.agentsResult = const Right(<Agent>[
            Agent(name: 'build', mode: 'primary', hidden: false, native: false),
          ]);

          dioClient = RecordingDioClient(
            configResponse: <String, dynamic>{
              'model': 'provider_a/model_a',
              'default_agent': 'build',
            },
          );
          provider = buildProvider(
            dioClient: dioClient,
            syncHealthCheckInterval: const Duration(seconds: 10),
            abortSuppressionWindow: const Duration(milliseconds: 500),
            abortSuppressionNow: () => abortNow,
          );

          final sendStreamController =
              StreamController<Either<Failure, ChatMessage>>();
          chatRepository.sendMessageHandler =
              (projectId, sessionId, input, directory) {
                sendStreamController.add(
                  Right(
                    AssistantMessage(
                      id: 'msg_a_1',
                      sessionId: sessionId,
                      time: DateTime.now(),
                      completedTime: DateTime.now(),
                      parts: <MessagePart>[
                        TextPart(
                          id: 'p1',
                          messageId: 'msg_a_1',
                          sessionId: sessionId,
                          text: 'ok',
                        ),
                      ],
                    ),
                  ),
                );
                return sendStreamController.stream;
              };

          await provider.initializeProviders();
          await provider.loadSessions();

          // Select ses_1 and send — abort suppression activates for ses_1
          final session1 = provider.sessions.firstWhere((s) => s.id == 'ses_1');
          await provider.selectSession(session1);
          await provider.sendMessage('hello');
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await sendStreamController.close();
          await Future<void>.delayed(const Duration(milliseconds: 10));

          // Verify abort suppression blocks sync on ses_1
          dioClient.patchBodies.clear();
          await provider.setSelectedModelByProvider(
            providerId: 'provider_b',
            modelId: 'model_b',
          );
          expect(hasModelBPatch(), isFalse);

          // Switch to ses_2. With global safety guard enabled, session A can
          // still block sync until A becomes safe (idle and suppression clear).
          chatRepository.sessionStatusById['ses_1'] =
              const SessionStatusInfo(type: SessionStatusType.busy);
          final session2 = provider.sessions.firstWhere((s) => s.id == 'ses_2');
          await provider.selectSession(session2);
          await pumpEventQueue();
          expect(provider.sessionStatusById['ses_1']?.type, SessionStatusType.busy);

          // Reset model to provider_a on ses_2 context so we can verify
          // an immediate sync when switching to provider_b.
          await provider.setSelectedModelByProvider(
            providerId: 'provider_a',
            modelId: 'model_a',
          );
          await Future<void>.delayed(const Duration(milliseconds: 20));
          dioClient.patchBodies.clear();

          await provider.setSelectedModelByProvider(
            providerId: 'provider_b',
            modelId: 'model_b',
          );
          abortNow = abortNow.add(const Duration(milliseconds: 501));
          await pumpEventQueue();

          // Still blocked because session A has not published idle yet.
          expect(hasModelBPatch(), isFalse);

          chatRepository.sessionStatusById['ses_1'] =
              const SessionStatusInfo(type: SessionStatusType.idle);
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

          expect(hasModelBPatch(), isTrue);
        },
      );

      test(
        'session.error during abort suppression does not trigger premature sync',
        () async {
          final sendStream = await initWithControllableStream();

          await provider.sendMessage('hello');
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await sendStream.close();
          await Future<void>.delayed(const Duration(milliseconds: 10));

          // Switch model — gets deferred
          await provider.setSelectedModelByProvider(
            providerId: 'provider_b',
            modelId: 'model_b',
          );
          expect(hasModelBPatch(), isFalse);

          // Emit session.error with abort-like message during suppression
          chatRepository.emitEvent(
            const ChatEvent(
              type: 'session.error',
              properties: <String, dynamic>{
                'sessionID': 'ses_1',
                'error': <String, dynamic>{'message': 'Request was aborted'},
              },
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 20));

          // Sync should still NOT have fired (suppression still active)
          expect(hasModelBPatch(), isFalse);

          abortNow = abortNow.add(const Duration(milliseconds: 51));
          chatRepository.emitEvent(
            const ChatEvent(
              type: 'session.status',
              properties: <String, dynamic>{
                'sessionID': 'ses_1',
                'status': <String, dynamic>{'type': 'busy'},
              },
            ),
          );
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

          expect(hasModelBPatch(), isTrue);
        },
      );

      test(
        'multiple selection changes during suppression are coalesced',
        () async {
          final sendStream = await initWithControllableStream();

          await provider.sendMessage('hello');
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await sendStream.close();
          await Future<void>.delayed(const Duration(milliseconds: 10));

          // Rapid-fire model switches during suppression window
          await provider.setSelectedModelByProvider(
            providerId: 'provider_b',
            modelId: 'model_b',
          );
          await provider.setSelectedModelByProvider(
            providerId: 'provider_a',
            modelId: 'model_a',
          );
          await provider.setSelectedModelByProvider(
            providerId: 'provider_b',
            modelId: 'model_b',
          );

          // Nothing flushed yet
          expect(hasModelBPatch(), isFalse);

          abortNow = abortNow.add(const Duration(milliseconds: 51));
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

          // Coalescing should flush a single PATCH with the final selection.
          final selectionPatches = dioClient.patchBodies
              .whereType<Map<String, dynamic>>()
              .where((body) => selectionPayloadFromPatch(body) != null)
              .toList();
          expect(selectionPatches, hasLength(1));

          final finalSelection = selectionPayloadFromPatch(
            selectionPatches.first,
          );
          expect(finalSelection?['providerId'], 'provider_b');
          expect(finalSelection?['modelId'], 'model_b');
        },
      );

      test(
        'completed send without active session does not defer sync',
        () async {
          // Setup providers without selecting a session
          appRepository.providersResult = Right(
            ProvidersResponse(
              providers: <Provider>[
                Provider(
                  id: 'provider_a',
                  name: 'Provider A',
                  env: const <String>[],
                  models: <String, Model>{'model_a': testModel('model_a')},
                ),
                Provider(
                  id: 'provider_b',
                  name: 'Provider B',
                  env: const <String>[],
                  models: <String, Model>{'model_b': testModel('model_b')},
                ),
              ],
              defaultModels: const <String, String>{'provider_a': 'model_a'},
              connected: const <String>['provider_a', 'provider_b'],
            ),
          );

          dioClient = RecordingDioClient(
            configResponse: <String, dynamic>{'model': 'provider_a/model_a'},
          );
          provider = buildProvider(
            dioClient: dioClient,
            abortSuppressionWindow: const Duration(milliseconds: 50),
          );

          await provider.initializeProviders();
          dioClient.patchBodies.clear();

          // Switch model without any session selected — no deferral
          await provider.setSelectedModelByProvider(
            providerId: 'provider_b',
            modelId: 'model_b',
          );
          await Future<void>.delayed(const Duration(milliseconds: 40));

          expect(hasModelBPatch(), isTrue);
        },
      );
    });

    group('messagesVersion', () {
      test('starts at zero', () {
        expect(provider.messagesVersion, 0);
      });

      test('increments when messages are loaded via loadMessages', () async {
        final assistantMessage = AssistantMessage(
          id: 'msg_1',
          sessionId: 'ses_1',
          time: DateTime.now(),
          completedTime: DateTime.now(),
          parts: const <MessagePart>[
            TextPart(
              id: 'prt_1',
              messageId: 'msg_1',
              sessionId: 'ses_1',
              text: 'hello',
            ),
          ],
        );
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          assistantMessage,
        ];

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        final versionAfterSelect = provider.messagesVersion;
        // loadMessages is called internally by selectSession, bumping the
        // version at least once (clear + load).
        expect(versionAfterSelect, greaterThan(0));
      });

      test(
        'does not increment on preserveVisibleState loadMessages semantic no-op',
        () async {
          final assistantMessage = AssistantMessage(
            id: 'msg_same_load',
            sessionId: 'ses_1',
            time: DateTime.now(),
            completedTime: DateTime.now(),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_same_load',
                messageId: 'msg_same_load',
                sessionId: 'ses_1',
                text: 'hello again',
              ),
            ],
          );
          chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
            assistantMessage,
          ];

          await provider.projectProvider.initializeProject();
          await provider.loadSessions();
          await provider.selectSession(provider.sessions.first);

          final versionBeforeRefresh = provider.messagesVersion;
          await provider.loadMessages('ses_1', preserveVisibleState: true);

          expect(provider.messagesVersion, versionBeforeRefresh);
          expect(provider.messages, hasLength(1));
        },
      );

      test(
        'does not increment on refreshActiveSessionView semantic no-op',
        () async {
          final assistantMessage = AssistantMessage(
            id: 'msg_same_refresh',
            sessionId: 'ses_1',
            time: DateTime.now(),
            completedTime: DateTime.now(),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_same_refresh',
                messageId: 'msg_same_refresh',
                sessionId: 'ses_1',
                text: 'stable tail',
              ),
            ],
          );
          chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
            assistantMessage,
          ];

          await provider.projectProvider.initializeProject();
          await provider.loadSessions();
          await provider.selectSession(provider.sessions.first);

          final versionBeforeRefresh = provider.messagesVersion;
          await provider.refreshActiveSessionView(reason: 'test-semantic-noop');

          expect(provider.messagesVersion, versionBeforeRefresh);
          expect(provider.messages, hasLength(1));
        },
      );

      test(
        'stale loadMessages keeps newer visible tail without incrementing',
        () async {
          final oldMessage = UserMessage(
            id: 'msg_old_load',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            parts: const <MessagePart>[],
          );
          final recentMessage = UserMessage(
            id: 'msg_recent_load',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(3000),
            parts: const <MessagePart>[],
          );
          chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
            oldMessage,
            recentMessage,
          ];

          await provider.projectProvider.initializeProject();
          await provider.loadSessions();
          await provider.selectSession(provider.sessions.first);

          chatRepository.messagesBySession['ses_1'] = <ChatMessage>[oldMessage];
          final versionBeforeRefresh = provider.messagesVersion;
          await provider.loadMessages('ses_1', preserveVisibleState: true);

          expect(provider.messages.map((message) => message.id), <String>[
            'msg_old_load',
            'msg_recent_load',
          ]);
          expect(provider.messagesVersion, versionBeforeRefresh);
        },
      );

      test('active refresh cannot replace a newer visible tail', () async {
        final oldMessage = UserMessage(
          id: 'msg_old_active_refresh',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          parts: const <MessagePart>[],
        );
        final recentMessage = UserMessage(
          id: 'msg_recent_active_refresh',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(3000),
          parts: const <MessagePart>[],
        );
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          oldMessage,
          recentMessage,
        ];

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[oldMessage];
        final versionBeforeRefresh = provider.messagesVersion;
        await provider.refreshActiveSessionView(reason: 'test-stale-snapshot');

        expect(provider.messages.map((message) => message.id), <String>[
          'msg_old_active_refresh',
          'msg_recent_active_refresh',
        ]);
        expect(provider.messagesVersion, versionBeforeRefresh);
      });

      test('increments on sendMessage (local user message added)', () async {
        chatRepository.sendMessageHandler = (_, _, _, _) async* {
          // Never emit — we only care about the local user message bump.
        };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        final versionBeforeSend = provider.messagesVersion;
        await provider.sendMessage('test message');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(provider.messagesVersion, greaterThan(versionBeforeSend));
        expect(provider.messages, isNotEmpty);
      });

      test(
        'increments on session delete that clears current messages',
        () async {
          chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
            AssistantMessage(
              id: 'msg_a',
              sessionId: 'ses_1',
              time: DateTime.now(),
              completedTime: DateTime.now(),
            ),
          ];

          await provider.projectProvider.initializeProject();
          await provider.loadSessions();
          await provider.selectSession(provider.sessions.first);

          final versionBeforeDelete = provider.messagesVersion;
          await provider.deleteSession('ses_1');
          await Future<void>.delayed(const Duration(milliseconds: 10));

          expect(provider.messagesVersion, greaterThan(versionBeforeDelete));
        },
      );

      test(
        'increments on message.removed event when a message is removed',
        () async {
          chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
            AssistantMessage(
              id: 'msg_a',
              sessionId: 'ses_1',
              time: DateTime.now(),
              completedTime: DateTime.now(),
            ),
          ];

          await provider.projectProvider.initializeProject();
          await provider.loadSessions();
          await provider.selectSession(provider.sessions.first);
          await provider.initializeProviders();

          final versionBeforeEvent = provider.messagesVersion;

          chatRepository.emitEvent(
            const ChatEvent(
              type: 'message.removed',
              properties: <String, dynamic>{
                'sessionID': 'ses_1',
                'messageID': 'msg_a',
              },
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 40));

          expect(provider.messagesVersion, greaterThan(versionBeforeEvent));
          expect(provider.messages, isEmpty);
        },
      );

      test('does not increment on message.removed no-op event', () async {
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          AssistantMessage(
            id: 'msg_a',
            sessionId: 'ses_1',
            time: DateTime.now(),
            completedTime: DateTime.now(),
          ),
        ];

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        final versionBeforeEvent = provider.messagesVersion;

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'message.removed',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'messageID': 'missing_message',
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(provider.messagesVersion, versionBeforeEvent);
        expect(provider.messages, hasLength(1));
      });

      test('does not increment on message.part.removed no-op event', () async {
        const initialPart = TextPart(
          id: 'prt_1',
          messageId: 'msg_a',
          sessionId: 'ses_1',
          text: 'hello',
        );
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          AssistantMessage(
            id: 'msg_a',
            sessionId: 'ses_1',
            time: DateTime.now(),
            completedTime: DateTime.now(),
            parts: const <MessagePart>[initialPart],
          ),
        ];

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        final versionBeforeEvent = provider.messagesVersion;

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'message.part.removed',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'messageID': 'msg_a',
              'partID': 'missing_part',
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(provider.messagesVersion, versionBeforeEvent);
        final message = provider.messages.single as AssistantMessage;
        expect(message.parts, hasLength(1));
      });

      test('does not increment on message.part.updated no-op event', () async {
        const initialPart = TextPart(
          id: 'prt_1',
          messageId: 'msg_a',
          sessionId: 'ses_1',
          text: 'hello',
        );
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          AssistantMessage(
            id: 'msg_a',
            sessionId: 'ses_1',
            time: DateTime.now(),
            completedTime: DateTime.now(),
            parts: const <MessagePart>[initialPart],
          ),
        ];

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        final versionBeforeEvent = provider.messagesVersion;

        chatRepository.emitEvent(
          ChatEvent(
            type: 'message.part.updated',
            properties: <String, dynamic>{
              'part': MessagePartModel.fromDomain(initialPart).toJson(),
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(provider.messagesVersion, versionBeforeEvent);
      });

      test(
        'increments on message.part.updated when part content changes',
        () async {
          const initialPart = TextPart(
            id: 'prt_1',
            messageId: 'msg_a',
            sessionId: 'ses_1',
            text: 'hello',
          );
          chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
            AssistantMessage(
              id: 'msg_a',
              sessionId: 'ses_1',
              time: DateTime.now(),
              completedTime: DateTime.now(),
              parts: const <MessagePart>[initialPart],
            ),
          ];

          await provider.projectProvider.initializeProject();
          await provider.loadSessions();
          await provider.selectSession(provider.sessions.first);
          await provider.initializeProviders();

          final versionBeforeEvent = provider.messagesVersion;
          const updatedPart = TextPart(
            id: 'prt_1',
            messageId: 'msg_a',
            sessionId: 'ses_1',
            text: 'hello updated',
          );

          chatRepository.emitEvent(
            ChatEvent(
              type: 'message.part.updated',
              properties: <String, dynamic>{
                'part': MessagePartModel.fromDomain(updatedPart).toJson(),
              },
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 40));

          expect(provider.messagesVersion, greaterThan(versionBeforeEvent));
          final message = provider.messages.single as AssistantMessage;
          final textPart = message.parts.single as TextPart;
          expect(textPart.text, 'hello updated');
        },
      );

      test('does not increment without message mutations', () async {
        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final versionAfterInit = provider.messagesVersion;

        // Wait idle — no operations that touch _messages.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(provider.messagesVersion, versionAfterInit);
      });
    });
  });
}
