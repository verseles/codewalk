@Tags(<String>['slow'])
library;

import 'dart:async';

import 'package:codewalk/core/auth/tts_api_key_storage.dart';
import 'package:codewalk/core/di/injection_container.dart' as di;
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/presentation/pages/settings/sections/text_to_speech_settings_section.dart';
import 'package:codewalk/presentation/pages/settings_page.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/moonshine_model_manager.dart';
import 'package:codewalk/presentation/services/parakeet_model_manager.dart';
import 'package:codewalk/presentation/services/read_aloud_service.dart';
import 'package:codewalk/presentation/services/sensevoice_model_manager.dart';
import 'package:codewalk/presentation/services/sherpa_model_manager.dart';
import 'package:codewalk/presentation/services/sound_service.dart';
import 'package:codewalk/presentation/services/tts/tts_backend.dart';
import 'package:codewalk/presentation/services/tts/generated_tts_audio_player.dart';
import 'package:codewalk/presentation/theme/opencode_theme_presets.dart';
import 'package:codewalk/presentation/utils/chat_abort_message.dart';
import 'package:codewalk/presentation/widgets/chat_message_widget.dart';
import 'package:codewalk/presentation/widgets/message_entrance_animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';
import '../support/pump_localized_app.dart';

class _ControlledTtsBackend implements TtsBackend {
  final Completer<TtsSynthesisResult> completer =
      Completer<TtsSynthesisResult>();
  bool stopped = false;

  @override
  ReadAloudProvider get provider => ReadAloudProvider.edgeExperimental;

  @override
  TtsPlaybackMode get playbackMode => TtsPlaybackMode.nativeEngine;

  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<List<TtsVoiceOption>> getVoices({
    String? apiKey,
    String? baseUrl,
    String? model,
  }) async => const <TtsVoiceOption>[];

  @override
  Future<List<String>> getLanguages() async => const <String>[];

  @override
  Future<TtsSynthesisResult> speakOrSynthesize(
    TtsSynthesisRequest request,
    TtsBackendCallbacks callbacks,
  ) {
    return completer.future;
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  void dispose() {}
}

class _InstantGeneratedBackend implements TtsBackend {
  _InstantGeneratedBackend({List<String>? texts})
    : texts = texts ?? <String>[];

  final List<String> texts;

  @override
  ReadAloudProvider get provider => ReadAloudProvider.edgeExperimental;

  @override
  TtsPlaybackMode get playbackMode => TtsPlaybackMode.generatedAudio;

  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<List<TtsVoiceOption>> getVoices({
    String? apiKey,
    String? baseUrl,
    String? model,
  }) async => const <TtsVoiceOption>[];

  @override
  Future<List<String>> getLanguages() async => const <String>[];

  @override
  Future<TtsSynthesisResult> speakOrSynthesize(
    TtsSynthesisRequest request,
    TtsBackendCallbacks callbacks,
  ) async {
    texts.add(request.text);
    return GeneratedTtsAudio(bytes: Uint8List(0), mimeType: 'audio/mpeg');
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  void dispose() {}
}

class _ChatFakeAudioPlayer implements TtsAudioPlayer {
  final StreamController<void> _completeController =
      StreamController<void>.broadcast(sync: true);
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast(sync: true);
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast(sync: true);

  int playCount = 0;
  int resumeCount = 0;
  bool paused = false;

  @override
  Stream<void> get onComplete => _completeController.stream;

  @override
  Stream<Duration> get onDurationChanged => _durationController.stream;

  @override
  Stream<Duration> get onPositionChanged => _positionController.stream;

  @override
  Future<void> playBytes(Uint8List bytes, {String? mimeType}) async {
    playCount += 1;
  }

  @override
  Future<void> pause() async {
    paused = true;
  }

  @override
  Future<void> resume() async {
    resumeCount += 1;
    paused = false;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class _MemoryTtsApiKeyStorageBackend implements TtsApiKeyStorageBackend {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<String?> read({required String key}) async {
    return values[key];
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}

AssistantMessage _readAloudAssistantMessage(String id) {
  return AssistantMessage(
    id: id,
    sessionId: 'ses_read_aloud_widget',
    time: DateTime.fromMillisecondsSinceEpoch(1000),
    parts: <MessagePart>[
      TextPart(
        id: 'part_$id',
        messageId: id,
        sessionId: 'ses_read_aloud_widget',
        text: 'Read this message aloud.',
      ),
    ],
  );
}

SettingsProvider _buildSettingsProviderForReadAloud() {
  return SettingsProvider(
    localDataSource: InMemoryAppLocalDataSource(),
    dioClient: DioClient(),
    soundService: SoundService(),
  );
}

void _registerSpeechSettingsDependencies() {
  di.sl.registerSingleton<SherpaModelManager>(SherpaModelManager());
  di.sl.registerSingleton<MoonshineModelManager>(MoonshineModelManager());
  di.sl.registerSingleton<ParakeetModelManager>(ParakeetModelManager());
  di.sl.registerSingleton<SenseVoiceModelManager>(SenseVoiceModelManager());
  di.sl.registerSingleton<TtsApiKeyStorage>(
    TtsApiKeyStorage(backend: _MemoryTtsApiKeyStorageBackend()),
  );
}

void main() {
  testWidgets('shows loading indicator for active loading read-aloud message', (
    WidgetTester tester,
  ) async {
    await di.sl.reset();
    addTearDown(di.sl.reset);
    final backend = _ControlledTtsBackend();
    final readAloudService = ReadAloudService(
      backends: <ReadAloudProvider, TtsBackend>{
        ReadAloudProvider.native: _ControlledTtsBackend(),
        ReadAloudProvider.edgeExperimental: backend,
      },
    );
    di.sl.registerSingleton<ReadAloudService>(readAloudService);
    addTearDown(readAloudService.dispose);
    final settingsProvider = _buildSettingsProviderForReadAloud();
    addTearDown(settingsProvider.dispose);
    final message = _readAloudAssistantMessage('msg_read_aloud_loading');

    final speakFuture = readAloudService.speak(
      messageId: message.id,
      text: 'Loading speech',
      provider: ReadAloudProvider.edgeExperimental,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settingsProvider,
        child: localizedMaterialApp(
          home: Scaffold(body: ChatMessageWidget(message: message)),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Symbols.volume_up), findsNothing);
    expect(
      find.byKey(const ValueKey('read_aloud_loading_msg_read_aloud_loading')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('read_aloud_loading_msg_read_aloud_loading')),
    );
    await tester.pump();

    expect(backend.stopped, isTrue);
    expect(readAloudService.state, ReadAloudState.idle);

    backend.completer.complete(const NativeTtsStarted());
    await speakFuture;
  });

  testWidgets('read-aloud playing shows pause/stop and can resume and stop', (
    WidgetTester tester,
  ) async {
    await di.sl.reset();
    addTearDown(di.sl.reset);
    final backend = _InstantGeneratedBackend();
    final player = _ChatFakeAudioPlayer();
    final readAloudService = ReadAloudService(
      backends: <ReadAloudProvider, TtsBackend>{
        ReadAloudProvider.edgeExperimental: backend,
      },
      audioPlayer: player,
    );
    di.sl.registerSingleton<ReadAloudService>(readAloudService);
    addTearDown(readAloudService.dispose);
    final settingsProvider = _buildSettingsProviderForReadAloud();
    addTearDown(settingsProvider.dispose);
    await settingsProvider.setReadAloudProvider(ReadAloudProvider.edgeExperimental);
    final message = _readAloudAssistantMessage('msg_read_aloud_controls');

    final speakFuture = readAloudService.speak(
      messageId: message.id,
      text: 'Read this message aloud.',
      provider: ReadAloudProvider.edgeExperimental,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settingsProvider,
        child: localizedMaterialApp(
          home: Scaffold(body: ChatMessageWidget(message: message)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    const playKey = ValueKey('read_aloud_play_msg_read_aloud_controls');
    const pauseKey = ValueKey('read_aloud_pause_msg_read_aloud_controls');
    const resumeKey = ValueKey('read_aloud_resume_msg_read_aloud_controls');
    const stopKey = ValueKey('read_aloud_stop_msg_read_aloud_controls');

    expect(readAloudService.state, ReadAloudState.playing);
    expect(find.byKey(pauseKey), findsOneWidget);
    expect(find.byKey(stopKey), findsOneWidget);
    expect(backend.texts, <String>['Read this message aloud.']);

    await tester.tap(find.byKey(pauseKey));
    await tester.pump();

    expect(readAloudService.state, ReadAloudState.paused);
    expect(find.byKey(resumeKey), findsOneWidget);

    await tester.tap(find.byKey(resumeKey));
    await tester.pump();

    expect(readAloudService.state, ReadAloudState.playing);
    expect(player.resumeCount, 1);

    await tester.tap(find.byKey(stopKey));
    await tester.pump();

    expect(readAloudService.state, ReadAloudState.idle);
    expect(find.byKey(playKey), findsOneWidget);
    await speakFuture;
  });

  testWidgets('long-pressing read-aloud button opens speech settings', (
    WidgetTester tester,
  ) async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await di.sl.reset();
    addTearDown(di.sl.reset);
    _registerSpeechSettingsDependencies();
    final backend = _ControlledTtsBackend();
    final readAloudService = ReadAloudService(
      backends: <ReadAloudProvider, TtsBackend>{
        ReadAloudProvider.native: _ControlledTtsBackend(),
        ReadAloudProvider.edgeExperimental: backend,
      },
    );
    di.sl.registerSingleton<ReadAloudService>(readAloudService);
    addTearDown(readAloudService.dispose);
    final settingsProvider = _buildSettingsProviderForReadAloud();
    addTearDown(settingsProvider.dispose);
    final message = _readAloudAssistantMessage('msg_read_aloud_settings');

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settingsProvider,
        child: localizedMaterialApp(
          home: Scaffold(body: ChatMessageWidget(message: message)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.byIcon(Symbols.volume_up));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(TextToSpeechSettingsSection), findsOneWidget);
    debugDefaultTargetPlatformOverride = previousPlatform;
  });

  testWidgets('renders historical revert action for user message callback', (
    WidgetTester tester,
  ) async {
    var tapped = 0;
    final message = UserMessage(
      id: 'msg_user_revert_widget',
      sessionId: 'ses_revert_widget',
      time: DateTime.fromMillisecondsSinceEpoch(1000),
      parts: const <MessagePart>[
        TextPart(
          id: 'part_user_revert_widget',
          messageId: 'msg_user_revert_widget',
          sessionId: 'ses_revert_widget',
          text: 'edit this older prompt',
        ),
      ],
    );

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: message,
            onInlineRevertToHere: () {
              tapped += 1;
            },
          ),
        ),
      ),
    );

    final button = find.byKey(
      const ValueKey<String>(
        'chat_message_revert_button_msg_user_revert_widget',
      ),
    );
    expect(button, findsOneWidget);
    expect(find.byIcon(Symbols.settings_backup_restore), findsOneWidget);

    await tester.tap(button);
    expect(tapped, 1);
  });

  testWidgets('does not animate part entrances for initial history render', (
    WidgetTester tester,
  ) async {
    final message = AssistantMessage(
      id: 'msg_initial_parts',
      sessionId: 'ses_initial_parts',
      time: DateTime.fromMillisecondsSinceEpoch(1000),
      parts: <MessagePart>[
        ToolPart(
          id: 'part_initial_tool',
          messageId: 'msg_initial_parts',
          sessionId: 'ses_initial_parts',
          callId: 'call_initial_tool',
          tool: 'bash',
          state: ToolStateRunning(
            input: const <String, dynamic>{'command': 'pwd'},
            time: DateTime.fromMillisecondsSinceEpoch(1000),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: message,
            isSessionActivelyResponding: true,
          ),
        ),
      ),
    );

    expect(find.byType(PartEntranceAnimation), findsNothing);
  });

  testWidgets('animates newly appended tool parts in the same message', (
    WidgetTester tester,
  ) async {
    var message = AssistantMessage(
      id: 'msg_streaming_parts',
      sessionId: 'ses_streaming_parts',
      time: DateTime.fromMillisecondsSinceEpoch(1000),
      parts: <MessagePart>[
        ToolPart(
          id: 'part_stream_tool_1',
          messageId: 'msg_streaming_parts',
          sessionId: 'ses_streaming_parts',
          callId: 'call_stream_tool_1',
          tool: 'bash',
          state: ToolStateRunning(
            input: const <String, dynamic>{'command': 'ls'},
            time: DateTime.fromMillisecondsSinceEpoch(1000),
          ),
        ),
      ],
    );
    late StateSetter setHostState;

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return ChatMessageWidget(
                message: message,
                isSessionActivelyResponding: true,
              );
            },
          ),
        ),
      ),
    );

    expect(find.byType(PartEntranceAnimation), findsNothing);

    setHostState(() {
      message = AssistantMessage(
        id: 'msg_streaming_parts',
        sessionId: 'ses_streaming_parts',
        time: DateTime.fromMillisecondsSinceEpoch(1000),
        parts: <MessagePart>[
          ToolPart(
            id: 'part_stream_tool_1',
            messageId: 'msg_streaming_parts',
            sessionId: 'ses_streaming_parts',
            callId: 'call_stream_tool_1',
            tool: 'bash',
            state: ToolStateCompleted(
              input: const <String, dynamic>{'command': 'ls'},
              output: 'README.md',
              time: ToolTime(
                start: DateTime.fromMillisecondsSinceEpoch(1000),
                end: DateTime.fromMillisecondsSinceEpoch(1200),
              ),
            ),
          ),
          ToolPart(
            id: 'part_stream_tool_2',
            messageId: 'msg_streaming_parts',
            sessionId: 'ses_streaming_parts',
            callId: 'call_stream_tool_2',
            tool: 'read',
            state: ToolStateRunning(
              input: const <String, dynamic>{'filePath': 'README.md'},
              time: DateTime.fromMillisecondsSinceEpoch(1201),
            ),
          ),
        ],
      );
    });
    await tester.pump();

    expect(find.byType(PartEntranceAnimation), findsOneWidget);
  });

  testWidgets(
    'preserves expanded tool details when message instance is replaced with same part id',
    (WidgetTester tester) async {
      AssistantMessage messageWithTool(String output) {
        return AssistantMessage(
          id: 'msg_tool_persist',
          sessionId: 'ses_tool_persist',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          parts: <MessagePart>[
            ToolPart(
              id: 'tool_persist',
              messageId: 'msg_tool_persist',
              sessionId: 'ses_tool_persist',
              callId: 'call_tool_persist',
              tool: 'bash',
              state: ToolStateCompleted(
                input: const <String, dynamic>{'command': 'pwd'},
                output: output,
                time: ToolTime(
                  start: DateTime.fromMillisecondsSinceEpoch(1000),
                  end: DateTime.fromMillisecondsSinceEpoch(1100),
                ),
              ),
            ),
          ],
        );
      }

      var message = messageWithTool('/workspace');
      late StateSetter setHostState;

      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setHostState = setState;
                return ChatMessageWidget(message: message);
              },
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('tool_part_details_button_tool_persist'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('/workspace'), findsOneWidget);
      expect(find.text('Hide'), findsOneWidget);

      setHostState(() {
        message = messageWithTool('/workspace/updated');
      });
      await tester.pumpAndSettle();

      expect(find.text('/workspace/updated'), findsOneWidget);
      expect(find.text('Hide'), findsOneWidget);
      expect(find.text('Details'), findsNothing);
    },
  );

  testWidgets(
    'preserves expanded tool details when stream replacement keeps call id but changes part id',
    (WidgetTester tester) async {
      AssistantMessage messageWithTool({
        required String partId,
        required String output,
      }) {
        return AssistantMessage(
          id: 'msg_tool_callid_persist',
          sessionId: 'ses_tool_callid_persist',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          parts: <MessagePart>[
            ToolPart(
              id: partId,
              messageId: 'msg_tool_callid_persist',
              sessionId: 'ses_tool_callid_persist',
              callId: 'call_tool_callid_persist',
              tool: 'bash',
              state: ToolStateCompleted(
                input: const <String, dynamic>{'command': 'pwd'},
                output: output,
                time: ToolTime(
                  start: DateTime.fromMillisecondsSinceEpoch(1000),
                  end: DateTime.fromMillisecondsSinceEpoch(1100),
                ),
              ),
            ),
          ],
        );
      }

      var message = messageWithTool(
        partId: 'tool_callid_persist_1',
        output: '/workspace',
      );
      late StateSetter setHostState;

      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setHostState = setState;
                return ChatMessageWidget(message: message);
              },
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'tool_part_details_button_tool_callid_persist_1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('/workspace'), findsOneWidget);
      expect(find.text('Hide'), findsOneWidget);

      setHostState(() {
        message = messageWithTool(
          partId: 'tool_callid_persist_2',
          output: '/workspace/updated',
        );
      });
      await tester.pumpAndSettle();

      expect(find.text('/workspace/updated'), findsOneWidget);
      expect(find.text('Hide'), findsOneWidget);
      expect(find.text('Details'), findsNothing);
    },
  );

  testWidgets(
    'preserves expanded tool details when call id appears after first render',
    (WidgetTester tester) async {
      AssistantMessage messageWithTool({
        required String callId,
        required String output,
      }) {
        return AssistantMessage(
          id: 'msg_tool_late_callid',
          sessionId: 'ses_tool_late_callid',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          parts: <MessagePart>[
            ToolPart(
              id: 'tool_late_callid',
              messageId: 'msg_tool_late_callid',
              sessionId: 'ses_tool_late_callid',
              callId: callId,
              tool: 'bash',
              state: ToolStateCompleted(
                input: const <String, dynamic>{'command': 'pwd'},
                output: output,
                time: ToolTime(
                  start: DateTime.fromMillisecondsSinceEpoch(1000),
                  end: DateTime.fromMillisecondsSinceEpoch(1100),
                ),
              ),
            ),
          ],
        );
      }

      var message = messageWithTool(callId: '', output: '/workspace');
      late StateSetter setHostState;

      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setHostState = setState;
                return ChatMessageWidget(message: message);
              },
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('tool_part_details_button_tool_late_callid'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('/workspace'), findsOneWidget);
      expect(find.text('Hide'), findsOneWidget);

      setHostState(() {
        message = messageWithTool(
          callId: 'call_tool_late_callid',
          output: '/workspace/updated',
        );
      });
      await tester.pumpAndSettle();

      expect(find.text('/workspace/updated'), findsOneWidget);
      expect(find.text('Hide'), findsOneWidget);
      expect(find.text('Details'), findsNothing);
    },
  );

  testWidgets(
    'pending question tool part shows view-question action as primary',
    (WidgetTester tester) async {
      final message = AssistantMessage(
        id: 'msg_question_action',
        sessionId: 'ses_question_action',
        time: DateTime.fromMillisecondsSinceEpoch(1000),
        parts: <MessagePart>[
          ToolPart(
            id: 'part_question_action',
            messageId: 'msg_question_action',
            sessionId: 'ses_question_action',
            callId: 'call_question_1',
            tool: 'question',
            state: ToolStatePending(),
          ),
        ],
      );
      ToolPart? revealedPart;
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: ChatMessageWidget(
              message: message,
              pendingQuestionCallIds: const <String>{'call_question_1'},
              onShowQuestion: (part) => revealedPart = part,
            ),
          ),
        ),
      );

      final action = find.byKey(
        const ValueKey<String>(
          'tool_part_question_action_part_question_action',
        ),
      );
      expect(action, findsOneWidget);
      expect(find.text('View question'), findsOneWidget);

      await tester.tap(action);
      expect(revealedPart?.callId, 'call_question_1');
    },
  );

  testWidgets(
    'pending question tool part keeps technical details as secondary action',
    (WidgetTester tester) async {
      final message = AssistantMessage(
        id: 'msg_question_action_details',
        sessionId: 'ses_question_action_details',
        time: DateTime.fromMillisecondsSinceEpoch(1000),
        parts: <MessagePart>[
          ToolPart(
            id: 'part_question_action_details',
            messageId: 'msg_question_action_details',
            sessionId: 'ses_question_action_details',
            callId: 'call_question_2',
            tool: 'question',
            state: ToolStateCompleted(
              input: const <String, dynamic>{'question': 'Proceed?'},
              output: '{"answers": []}',
              time: ToolTime(
                start: DateTime.fromMillisecondsSinceEpoch(1000),
                end: DateTime.fromMillisecondsSinceEpoch(1100),
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: ChatMessageWidget(
              message: message,
              pendingQuestionCallIds: const <String>{'call_question_2'},
              onShowQuestion: (_) {},
            ),
          ),
        ),
      );

      expect(
        find.byKey(
          const ValueKey<String>(
            'tool_part_question_action_part_question_action_details',
          ),
        ),
        findsOneWidget,
      );
      final detailsToggle = find.byKey(
        const ValueKey<String>(
          'tool_part_details_button_part_question_action_details',
        ),
      );
      expect(detailsToggle, findsOneWidget);

      await tester.tap(detailsToggle);
      await tester.pumpAndSettle();
      expect(find.text('Hide'), findsOneWidget);
    },
  );

  testWidgets(
    'question tool part without pending request shows no question action',
    (WidgetTester tester) async {
      final message = AssistantMessage(
        id: 'msg_question_no_pending',
        sessionId: 'ses_question_no_pending',
        time: DateTime.fromMillisecondsSinceEpoch(1000),
        parts: <MessagePart>[
          ToolPart(
            id: 'part_question_no_pending',
            messageId: 'msg_question_no_pending',
            sessionId: 'ses_question_no_pending',
            callId: 'call_question_3',
            tool: 'question',
            state: ToolStatePending(),
          ),
        ],
      );
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: ChatMessageWidget(
              message: message,
              pendingQuestionCallIds: const <String>{'call_other'},
              onShowQuestion: (_) {},
            ),
          ),
        ),
      );

      expect(
        find.byKey(
          const ValueKey<String>(
            'tool_part_question_action_part_question_no_pending',
          ),
        ),
        findsNothing,
      );
      expect(find.text('View question'), findsNothing);
    },
  );

  testWidgets('hides step blocks from assistant message body', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_1',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[
                StepStartPart(
                  id: 'part_step_start',
                  messageId: 'msg_1',
                  sessionId: 'ses_1',
                  snapshot: 'snap-1',
                ),
                StepFinishPart(
                  id: 'part_step_finish',
                  messageId: 'msg_1',
                  sessionId: 'ses_1',
                  reason: 'stop',
                  cost: 0.0012,
                  tokens: MessageTokens(input: 3, output: 4),
                ),
                TextPart(
                  id: 'part_text',
                  messageId: 'msg_1',
                  sessionId: 'ses_1',
                  text: 'Final answer',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Step started'), findsNothing);
    expect(find.text('Step finished'), findsNothing);
    expect(find.text('Final answer'), findsOneWidget);
  });

  testWidgets('normalizes abort technical text in assistant error bubble', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_abort_error',
              sessionId: 'ses_abort_error',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[],
              error: const MessageError(
                name: 'UnknownError',
                message: 'The operation was aborted.',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text(kChatAbortNoticeMessage), findsOneWidget);
    expect(find.text('The operation was aborted.'), findsNothing);
  });

  testWidgets('shows step metadata in assistant info popup', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_2',
              sessionId: 'ses_2',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              providerId: 'openai',
              modelId: 'gpt-4.1',
              cost: 0.0012,
              parts: const <MessagePart>[
                StepStartPart(
                  id: 'part_step_start_2',
                  messageId: 'msg_2',
                  sessionId: 'ses_2',
                  snapshot: 'snap-abc',
                ),
                StepFinishPart(
                  id: 'part_step_finish_2',
                  messageId: 'msg_2',
                  sessionId: 'ses_2',
                  reason: 'stop',
                  cost: 0.0012,
                  tokens: MessageTokens(input: 3, output: 4),
                ),
                TextPart(
                  id: 'part_text_2',
                  messageId: 'msg_2',
                  sessionId: 'ses_2',
                  text: 'Done',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Message Info'));
    await tester.pumpAndSettle();

    expect(find.text('Model: gpt-4.1'), findsOneWidget);
    expect(find.text('Provider: openai'), findsOneWidget);
    expect(find.text(r'Cost: $0.001200'), findsOneWidget);
    expect(find.text('Step started #1: snap-abc'), findsOneWidget);
    expect(
      find.text('Step finished #1: stop • tokens 7 • \$0.001200'),
      findsOneWidget,
    );
  });

  testWidgets('assistant text is selectable and does not show copy button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_3',
              sessionId: 'ses_3',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_text_3',
                  messageId: 'msg_3',
                  sessionId: 'ses_3',
                  text: 'Selectable assistant text',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.byTooltip('Copy'), findsNothing);
  });

  testWidgets('user text also does not show copy button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: UserMessage(
              id: 'msg_4',
              sessionId: 'ses_4',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_text_4',
                  messageId: 'msg_4',
                  sessionId: 'ses_4',
                  text: 'User text',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Copy'), findsNothing);
  });

  testWidgets('user text is not selectable and has no copy button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: UserMessage(
              id: 'msg_6',
              sessionId: 'ses_6',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_text_6',
                  messageId: 'msg_6',
                  sessionId: 'ses_6',
                  text: 'User selectable text',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SelectionArea), findsNothing);
    expect(find.byTooltip('Copy'), findsNothing);
  });

  testWidgets('file part with inline payload renders save action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: UserMessage(
              id: 'msg_file_data',
              sessionId: 'ses_file_data',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[
                FilePart(
                  id: 'part_file_data',
                  messageId: 'msg_file_data',
                  sessionId: 'ses_file_data',
                  url:
                      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX7sAAAAASUVORK5CYII=',
                  mime: 'image/png',
                  filename: 'preview.png',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Save file'), findsOneWidget);
    expect(find.byIcon(Symbols.download_rounded), findsOneWidget);
    expect(find.text('preview.png'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('file_image_preview_part_file_data')),
      findsOneWidget,
    );
  });

  testWidgets('file part data-uri preview survives rebuilds (issue #177)', (
    WidgetTester tester,
  ) async {
    Widget buildFrame() {
      return localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: UserMessage(
              id: 'msg_file_cache',
              sessionId: 'ses_file_cache',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[
                FilePart(
                  id: 'part_file_cache',
                  messageId: 'msg_file_cache',
                  sessionId: 'ses_file_cache',
                  url:
                      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX7sAAAAASUVORK5CYII=',
                  mime: 'image/png',
                  filename: 'cached.png',
                ),
              ],
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildFrame());
    await tester.pumpWidget(buildFrame());
    await tester.pumpWidget(buildFrame());

    // Second and third builds hit the decoded-bytes cache instead of
    // re-decoding base64 on the UI isolate.
    expect(
      find.byKey(const ValueKey<String>('file_image_preview_part_file_cache')),
      findsOneWidget,
    );
  });

  testWidgets('file part with source path renders open action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: UserMessage(
              id: 'msg_file_source',
              sessionId: 'ses_file_source',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[
                FilePart(
                  id: 'part_file_source',
                  messageId: 'msg_file_source',
                  sessionId: 'ses_file_source',
                  url: 'file:///tmp/report.pdf',
                  mime: 'application/pdf',
                  filename: 'report.pdf',
                  fileSource: FileSource(
                    path: '/tmp/report.pdf',
                    text: FilePartSourceText(value: '', start: 0, end: 0),
                    type: 'file',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Open file'), findsOneWidget);
    expect(find.byIcon(Symbols.open_in_new_rounded), findsOneWidget);
    expect(find.text('/tmp/report.pdf'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('file_image_preview_part_file_source')),
      findsNothing,
    );
  });

  testWidgets('background copy handler shows feedback on non-android', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_7',
              sessionId: 'ses_7',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_text_7a',
                  messageId: 'msg_7',
                  sessionId: 'ses_7',
                  text: 'First line',
                ),
                TextPart(
                  id: 'part_text_7b',
                  messageId: 'msg_7',
                  sessionId: 'ses_7',
                  text: 'Second line',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('First line'));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.text('First line'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Copied to clipboard'), findsOneWidget);
  });

  testWidgets('background copy handler does not show feedback on android', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_9',
              sessionId: 'ses_9',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_text_9',
                  messageId: 'msg_9',
                  sessionId: 'ses_9',
                  text: 'Android native clipboard feedback',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Android native clipboard feedback'));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.text('Android native clipboard feedback'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Copied to clipboard'), findsNothing);
  });

  testWidgets('user message double tap copies whole message text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: Scaffold(
          body: ChatMessageWidget(
            message: UserMessage(
              id: 'msg_user_no_double_tap',
              sessionId: 'ses_user_no_double_tap',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_text_user_no_double_tap',
                  messageId: 'msg_user_no_double_tap',
                  sessionId: 'ses_user_no_double_tap',
                  text: 'User text',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('User text'));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.text('User text'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Copied to clipboard'), findsOneWidget);
  });

  testWidgets('double tap on assistant text copies whole message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_8',
              sessionId: 'ses_8',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_text_8',
                  messageId: 'msg_8',
                  sessionId: 'ses_8',
                  text: 'Word selection should win',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final textFinder = find.text('Word selection should win');
    await tester.tap(textFinder);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(textFinder);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Copied to clipboard'), findsOneWidget);
  });

  testWidgets('single tap on markdown code copies code snippet', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_code_tap',
              sessionId: 'ses_code_tap',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_code_tap',
                  messageId: 'msg_code_tap',
                  sessionId: 'ses_code_tap',
                  text: '```dart\nfinal value = 42;\n```',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(HighlightView).first);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Copied to clipboard'), findsOneWidget);
  });

  testWidgets('single tap on inline-code file path opens file path', (
    WidgetTester tester,
  ) async {
    String? tappedPath;
    int? tappedLine;
    int? tappedColumn;

    await tester.pumpWidget(
      localizedMaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_inline_file_path_tap',
              sessionId: 'ses_inline_file_path_tap',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_inline_file_path_tap',
                  messageId: 'msg_inline_file_path_tap',
                  sessionId: 'ses_inline_file_path_tap',
                  text: 'Open `lib/presentation/pages/chat_page.dart:219`.',
                ),
              ],
            ),
            onFileTap: (path, line, col) {
              tappedPath = path;
              tappedLine = line;
              tappedColumn = col;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('lib/presentation/pages/chat_page.dart:219'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tappedPath, 'lib/presentation/pages/chat_page.dart');
    expect(tappedLine, 219);
    expect(tappedColumn, isNull);
    expect(find.text('Copied to clipboard'), findsNothing);
  });

  testWidgets('multi-line markdown code block uses themed container', (
    WidgetTester tester,
  ) async {
    final themeTokens = openCodeThemeTokensFor(
      OpenCodeThemePreset.dracula,
      Brightness.dark,
    )!;

    await tester.pumpWidget(
      localizedMaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          extensions: <ThemeExtension<dynamic>>[themeTokens],
        ),
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_themed_code',
              sessionId: 'ses_themed_code',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_themed_code',
                  messageId: 'msg_themed_code',
                  sessionId: 'ses_themed_code',
                  text: '```dart\nfinal value = 42;\nprint(value);\n```',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate((widget) {
        if (widget is! DecoratedBox) {
          return false;
        }
        final decoration = widget.decoration;
        if (decoration is! BoxDecoration) {
          return false;
        }
        return decoration.color == themeTokens.codeBlockBackground;
      }),
      findsWidgets,
    );
  });

  testWidgets('markdown blockquote uses themed decoration and text color', (
    WidgetTester tester,
  ) async {
    final themeTokens = openCodeThemeTokensFor(
      OpenCodeThemePreset.dracula,
      Brightness.dark,
    )!;

    await tester.pumpWidget(
      localizedMaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          extensions: <ThemeExtension<dynamic>>[themeTokens],
        ),
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_blockquote',
              sessionId: 'ses_blockquote',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_blockquote',
                  messageId: 'msg_blockquote',
                  sessionId: 'ses_blockquote',
                  text: '> This is a blockquote line',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate((widget) {
        if (widget is! DecoratedBox) {
          return false;
        }
        final decoration = widget.decoration;
        if (decoration is! BoxDecoration) {
          return false;
        }
        final border = decoration.border;
        if (border is! Border) {
          return false;
        }
        final leftSide = border.left;
        return decoration.color == themeTokens.surfaceRaised &&
            leftSide.color == themeTokens.markdownBlockQuote &&
            leftSide.width == 4.0;
      }),
      findsWidgets,
    );
  });

  testWidgets(
    'multi-line markdown code block keeps monospace font in classic dark theme',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        localizedMaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: ChatMessageWidget(
              message: AssistantMessage(
                id: 'msg_classic_dark_code',
                sessionId: 'ses_classic_dark_code',
                time: DateTime.fromMillisecondsSinceEpoch(1000),
                parts: const <MessagePart>[
                  TextPart(
                    id: 'part_classic_dark_code',
                    messageId: 'msg_classic_dark_code',
                    sessionId: 'ses_classic_dark_code',
                    text: '```dart\nfinal value = 42;\nprint(value);\n```',
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final highlightView = tester.widget<HighlightView>(
        find.byType(HighlightView),
      );
      expect(highlightView.textStyle?.fontFamily, 'monospace');

      expect(
        find.byWidgetPredicate((widget) {
          if (widget is! DecoratedBox) {
            return false;
          }
          final decoration = widget.decoration;
          if (decoration is! BoxDecoration) {
            return false;
          }
          return decoration.color != null;
        }),
        findsWidgets,
      );
    },
  );

  testWidgets('markdown code stays stable across parent rebuilds', (
    WidgetTester tester,
  ) async {
    var showLeadingPanel = true;

    Widget buildHost() {
      return localizedMaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Row(
                children: [
                  if (showLeadingPanel) const SizedBox(width: 120),
                  Expanded(
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                showLeadingPanel = !showLeadingPanel;
                              });
                            },
                            child: const Text('toggle panel'),
                          ),
                        ),
                        Expanded(
                          child: ChatMessageWidget(
                            message: AssistantMessage(
                              id: 'msg_code_stable',
                              sessionId: 'ses_code_stable',
                              time: DateTime.fromMillisecondsSinceEpoch(1000),
                              completedTime:
                                  DateTime.fromMillisecondsSinceEpoch(1200),
                              parts: const <MessagePart>[
                                TextPart(
                                  id: 'part_code_stable',
                                  messageId: 'msg_code_stable',
                                  sessionId: 'ses_code_stable',
                                  text:
                                      '```dart\nfinal value = 42;\nprint(value);\n```',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    await tester.pumpWidget(buildHost());
    await tester.pumpAndSettle();

    expect(find.byType(HighlightView), findsOneWidget);

    for (var i = 0; i < 4; i += 1) {
      await tester.tap(find.text('toggle panel'));
      await tester.pumpAndSettle();
      expect(find.byType(HighlightView), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('multiple inline code spans render without key collisions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_inline_code_keys',
              sessionId: 'ses_inline_code_keys',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              completedTime: DateTime.fromMillisecondsSinceEpoch(1200),
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_inline_code_keys',
                  messageId: 'msg_inline_code_keys',
                  sessionId: 'ses_inline_code_keys',
                  text: 'Use `alpha` and `beta` in sequence.',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('alpha'), findsOneWidget);
    expect(find.textContaining('beta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('multiple fenced code blocks render without key collisions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_fenced_code_keys',
              sessionId: 'ses_fenced_code_keys',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              completedTime: DateTime.fromMillisecondsSinceEpoch(1200),
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_fenced_code_keys',
                  messageId: 'msg_fenced_code_keys',
                  sessionId: 'ses_fenced_code_keys',
                  text:
                      '```dart\nfinal alpha = 1;\n```\n\n```dart\nfinal beta = 2;\n```',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(HighlightView), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('touch hold callback stays scoped to user messages', (
    WidgetTester tester,
  ) async {
    var userLongPressCount = 0;
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            onBackgroundLongPress: () {
              userLongPressCount += 1;
            },
            message: UserMessage(
              id: 'msg_user_hold',
              sessionId: 'ses_user_hold',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_text_user_hold',
                  messageId: 'msg_user_hold',
                  sessionId: 'ses_user_hold',
                  text: 'Press and hold me',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.text('Press and hold me'));
    await tester.pumpAndSettle();
    expect(userLongPressCount, 1);

    var assistantLongPressCount = 0;
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            onBackgroundLongPress: () {
              assistantLongPressCount += 1;
            },
            message: AssistantMessage(
              id: 'msg_assistant_hold',
              sessionId: 'ses_assistant_hold',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_text_assistant_hold',
                  messageId: 'msg_assistant_hold',
                  sessionId: 'ses_assistant_hold',
                  text: 'Assistant should stay selectable',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.text('Assistant should stay selectable'));
    await tester.pumpAndSettle();
    expect(assistantLongPressCount, 0);
  });

  testWidgets('tool completed output starts collapsed and can expand', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_tool_completed',
              sessionId: 'ses_tool',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'part_tool_completed',
                  messageId: 'msg_tool_completed',
                  sessionId: 'ses_tool',
                  callId: 'call_1',
                  tool: 'bash',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{'cmd': 'ls -la'},
                    output: 'line 1\nline 2\nline 3\nline 4',
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1200),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Tool Call: bash'), findsNothing);
    expect(find.text('Running command'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(
      tester
          .widget<Icon>(find.byIcon(Symbols.check_circle_outline_rounded))
          .color,
      Colors.green.shade700,
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('tool_part_details_button_part_tool_completed'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.key == const ValueKey<String>('tool_command_text') &&
            widget.text.toPlainText().contains('Command: ls -la'),
      ),
      findsOneWidget,
    );

    final outputText = tester.widget<Text>(
      find.byKey(const ValueKey<String>('tool_content_text')),
    );
    expect(outputText.maxLines, isNull);
    expect(
      find.byKey(
        const ValueKey<String>('tool_content_scroll_tool_output_diff'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tool error output starts collapsed and can expand', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_tool_error',
              sessionId: 'ses_tool',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'part_tool_error',
                  messageId: 'msg_tool_error',
                  sessionId: 'ses_tool',
                  callId: 'call_2',
                  tool: 'bash',
                  state: ToolStateError(
                    input: const <String, dynamic>{'cmd': 'cat missing.txt'},
                    error: 'error line 1\nerror line 2\nerror line 3',
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1200),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Tool Call: bash'), findsNothing);
    expect(find.text('Running command'), findsOneWidget);
    expect(find.text('Needs attention'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('tool_part_details_button_part_tool_error'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.key == const ValueKey<String>('tool_command_text') &&
            widget.text.toPlainText().contains('Command: cat missing.txt'),
      ),
      findsOneWidget,
    );

    final outputText = tester.widget<Text>(
      find.byKey(const ValueKey<String>('tool_content_text')),
    );
    expect(outputText.maxLines, isNull);
    expect(
      find.byKey(const ValueKey<String>('tool_content_scroll_tool_error_diff')),
      findsOneWidget,
    );
  });

  testWidgets('mobile tool status chip shows icon without label text', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_tool_mobile_status',
              sessionId: 'ses_tool',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'part_tool_mobile_status',
                  messageId: 'msg_tool_mobile_status',
                  sessionId: 'ses_tool',
                  callId: 'call_mobile_1',
                  tool: 'bash',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{'command': 'pwd'},
                    output: '/tmp',
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1200),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Done'), findsNothing);
    expect(find.byIcon(Symbols.check_circle_outline_rounded), findsOneWidget);
    expect(
      tester
          .widget<Icon>(find.byIcon(Symbols.check_circle_outline_rounded))
          .color,
      Colors.green.shade700,
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'tool_part_details_button_part_tool_mobile_status',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.key == const ValueKey<String>('tool_command_text') &&
            widget.text.toPlainText().contains('Command: pwd'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('completed tool status chip stays green in dark theme', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_tool_status_dark',
              sessionId: 'ses_tool',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'part_tool_status_dark',
                  messageId: 'msg_tool_status_dark',
                  sessionId: 'ses_tool',
                  callId: 'call_status_dark',
                  tool: 'bash',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{'command': 'pwd'},
                    output: '/tmp',
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1200),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Done'), findsOneWidget);
    expect(
      tester
          .widget<Icon>(find.byIcon(Symbols.check_circle_outline_rounded))
          .color,
      Colors.green.shade400,
    );
  });

  testWidgets('collapses completed tool chains and reveals them on demand', (
    WidgetTester tester,
  ) async {
    final message = AssistantMessage(
      id: 'msg_tool_chain',
      sessionId: 'ses_tool_chain',
      time: DateTime.fromMillisecondsSinceEpoch(1000),
      completedTime: DateTime.fromMillisecondsSinceEpoch(1200),
      parts: <MessagePart>[
        ToolPart(
          id: 'part_tool_chain_1',
          messageId: 'msg_tool_chain',
          sessionId: 'ses_tool_chain',
          callId: 'call_chain_1',
          tool: 'bash',
          state: ToolStateCompleted(
            input: const <String, dynamic>{'command': 'pwd'},
            output: '/tmp/project',
            time: ToolTime(
              start: DateTime.fromMillisecondsSinceEpoch(1000),
              end: DateTime.fromMillisecondsSinceEpoch(1050),
            ),
          ),
        ),
        ToolPart(
          id: 'part_tool_chain_2',
          messageId: 'msg_tool_chain',
          sessionId: 'ses_tool_chain',
          callId: 'call_chain_2',
          tool: 'read',
          state: ToolStateCompleted(
            input: const <String, dynamic>{'filePath': 'lib/main.dart'},
            output: 'line 1\nline 2',
            time: ToolTime(
              start: DateTime.fromMillisecondsSinceEpoch(1060),
              end: DateTime.fromMillisecondsSinceEpoch(1100),
            ),
          ),
        ),
        const TextPart(
          id: 'part_tool_chain_text',
          messageId: 'msg_tool_chain',
          sessionId: 'ses_tool_chain',
          text: 'Final answer',
        ),
      ],
    );

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(body: ChatMessageWidget(message: message)),
      ),
    );

    expect(find.text('Details'), findsOneWidget);
    expect(find.textContaining('Running command'), findsOneWidget);
    expect(find.textContaining('Reading file'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('tool_chain_toggle_msg_tool_chain_call_chain_1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hide'), findsNWidgets(2));
    expect(
      find.byKey(
        const ValueKey<String>('tool_part_details_button_part_tool_chain_1'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('tool_part_details_button_part_tool_chain_2'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('tool_part_details_button_part_tool_chain_1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey<String>('tool_part_details_button_part_tool_chain_2'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('tool_command_text')),
      findsNWidgets(2),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'tool_chain_bottom_toggle_msg_tool_chain_call_chain_1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Details'), findsOneWidget);
    expect(find.textContaining('Running command'), findsOneWidget);
  });

  testWidgets('uses compact collapsed labels for tool chains on mobile', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final message = AssistantMessage(
      id: 'msg_tool_chain_mobile',
      sessionId: 'ses_tool_chain_mobile',
      time: DateTime.fromMillisecondsSinceEpoch(1000),
      completedTime: DateTime.fromMillisecondsSinceEpoch(1200),
      parts: <MessagePart>[
        ToolPart(
          id: 'part_tool_chain_mobile_1',
          messageId: 'msg_tool_chain_mobile',
          sessionId: 'ses_tool_chain_mobile',
          callId: 'call_chain_mobile_1',
          tool: 'bash',
          state: ToolStateCompleted(
            input: const <String, dynamic>{'command': 'pwd'},
            output: '/tmp/project',
            time: ToolTime(
              start: DateTime.fromMillisecondsSinceEpoch(1000),
              end: DateTime.fromMillisecondsSinceEpoch(1050),
            ),
          ),
        ),
        ToolPart(
          id: 'part_tool_chain_mobile_2',
          messageId: 'msg_tool_chain_mobile',
          sessionId: 'ses_tool_chain_mobile',
          callId: 'call_chain_mobile_2',
          tool: 'read',
          state: ToolStateCompleted(
            input: const <String, dynamic>{'filePath': 'README.md'},
            output: 'Intro',
            time: ToolTime(
              start: DateTime.fromMillisecondsSinceEpoch(1060),
              end: DateTime.fromMillisecondsSinceEpoch(1100),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(body: ChatMessageWidget(message: message)),
      ),
    );

    expect(find.text('2 calls'), findsOneWidget);
    expect(find.text('Running command • Reading file'), findsNothing);
    expect(find.text('Show'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'tool_chain_toggle_msg_tool_chain_mobile_call_chain_mobile_1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hide'), findsNWidgets(2));
    expect(find.textContaining('Running command'), findsOneWidget);
    expect(find.textContaining('Reading file'), findsOneWidget);
  });

  testWidgets(
    'keeps multi-tool chain closed by default while responding and preserves manual expansion after completion',
    (WidgetTester tester) async {
      final message = AssistantMessage(
        id: 'msg_tool_chain_streaming',
        sessionId: 'ses_tool_chain_streaming',
        time: DateTime.fromMillisecondsSinceEpoch(1000),
        completedTime: DateTime.fromMillisecondsSinceEpoch(1200),
        parts: <MessagePart>[
          ToolPart(
            id: 'part_tool_chain_streaming_1',
            messageId: 'msg_tool_chain_streaming',
            sessionId: 'ses_tool_chain_streaming',
            callId: 'call_chain_streaming_1',
            tool: 'bash',
            state: ToolStateCompleted(
              input: const <String, dynamic>{'command': 'pwd'},
              output: '/tmp/project',
              time: ToolTime(
                start: DateTime.fromMillisecondsSinceEpoch(1000),
                end: DateTime.fromMillisecondsSinceEpoch(1050),
              ),
            ),
          ),
          ToolPart(
            id: 'part_tool_chain_streaming_2',
            messageId: 'msg_tool_chain_streaming',
            sessionId: 'ses_tool_chain_streaming',
            callId: 'call_chain_streaming_2',
            tool: 'read',
            state: ToolStateCompleted(
              input: const <String, dynamic>{'filePath': 'lib/main.dart'},
              output: 'line 1\nline 2',
              time: ToolTime(
                start: DateTime.fromMillisecondsSinceEpoch(1060),
                end: DateTime.fromMillisecondsSinceEpoch(1100),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: ChatMessageWidget(
              message: message,
              isSessionActivelyResponding: true,
            ),
          ),
        ),
      );

      expect(
        find.byKey(
          const ValueKey<String>(
            'tool_chain_toggle_msg_tool_chain_streaming_call_chain_streaming_1',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>(
            'tool_part_details_button_part_tool_chain_streaming_1',
          ),
        ),
        findsNothing,
      );
      expect(find.text('Details'), findsOneWidget);

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.key == const ValueKey<String>('tool_command_text'),
        ),
        findsNothing,
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'tool_chain_toggle_msg_tool_chain_streaming_call_chain_streaming_1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'tool_part_details_button_part_tool_chain_streaming_1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'tool_part_details_button_part_tool_chain_streaming_2',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('tool_command_text')),
        findsNWidgets(2),
      );

      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: ChatMessageWidget(
              message: message,
              isSessionActivelyResponding: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>(
            'tool_chain_toggle_msg_tool_chain_streaming_call_chain_streaming_1',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Hide'), findsNWidgets(4));
      expect(
        find.byKey(
          const ValueKey<String>(
            'tool_part_details_button_part_tool_chain_streaming_1',
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'keeps a manually opened tool visible when streaming transitions from single tool to multi-tool chain',
    (WidgetTester tester) async {
      AssistantMessage buildMessage({required bool includeSecondTool}) {
        return AssistantMessage(
          id: 'msg_tool_chain_transition',
          sessionId: 'ses_tool_chain_transition',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          parts: <MessagePart>[
            ToolPart(
              id: 'part_tool_chain_transition_1',
              messageId: 'msg_tool_chain_transition',
              sessionId: 'ses_tool_chain_transition',
              callId: 'call_chain_transition_1',
              tool: 'bash',
              state: ToolStateCompleted(
                input: const <String, dynamic>{'command': 'pwd'},
                output: '/tmp/project',
                time: ToolTime(
                  start: DateTime.fromMillisecondsSinceEpoch(1000),
                  end: DateTime.fromMillisecondsSinceEpoch(1050),
                ),
              ),
            ),
            if (includeSecondTool)
              ToolPart(
                id: 'part_tool_chain_transition_2',
                messageId: 'msg_tool_chain_transition',
                sessionId: 'ses_tool_chain_transition',
                callId: 'call_chain_transition_2',
                tool: 'read',
                state: ToolStateCompleted(
                  input: const <String, dynamic>{'filePath': 'README.md'},
                  output: 'hello',
                  time: ToolTime(
                    start: DateTime.fromMillisecondsSinceEpoch(1060),
                    end: DateTime.fromMillisecondsSinceEpoch(1100),
                  ),
                ),
              ),
          ],
        );
      }

      var message = buildMessage(includeSecondTool: false);
      late StateSetter setHostState;

      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setHostState = setState;
                return ChatMessageWidget(
                  message: message,
                  isSessionActivelyResponding: true,
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'tool_part_details_button_part_tool_chain_transition_1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('tool_command_text')),
        findsOneWidget,
      );

      setHostState(() {
        message = buildMessage(includeSecondTool: true);
      });
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>(
            'tool_chain_toggle_msg_tool_chain_transition_call_chain_transition_1',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Hide'), findsNWidgets(3));
      expect(
        find.byKey(const ValueKey<String>('tool_command_text')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>(
            'tool_part_details_button_part_tool_chain_transition_1',
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('keeps completed tool chain expanded after parent rebuild', (
    WidgetTester tester,
  ) async {
    final message = AssistantMessage(
      id: 'msg_tool_chain_rebuild',
      sessionId: 'ses_tool_chain_rebuild',
      time: DateTime.fromMillisecondsSinceEpoch(1000),
      completedTime: DateTime.fromMillisecondsSinceEpoch(1200),
      parts: <MessagePart>[
        ToolPart(
          id: 'part_tool_chain_rebuild_1',
          messageId: 'msg_tool_chain_rebuild',
          sessionId: 'ses_tool_chain_rebuild',
          callId: 'call_tool_chain_rebuild_1',
          tool: 'bash',
          state: ToolStateCompleted(
            input: const <String, dynamic>{'command': 'pwd'},
            output: '/tmp/project',
            time: ToolTime(
              start: DateTime.fromMillisecondsSinceEpoch(1000),
              end: DateTime.fromMillisecondsSinceEpoch(1050),
            ),
          ),
        ),
        ToolPart(
          id: 'part_tool_chain_rebuild_2',
          messageId: 'msg_tool_chain_rebuild',
          sessionId: 'ses_tool_chain_rebuild',
          callId: 'call_tool_chain_rebuild_2',
          tool: 'read',
          state: ToolStateCompleted(
            input: const <String, dynamic>{'filePath': 'README.md'},
            output: 'Intro',
            time: ToolTime(
              start: DateTime.fromMillisecondsSinceEpoch(1060),
              end: DateTime.fromMillisecondsSinceEpoch(1100),
            ),
          ),
        ),
      ],
    );

    Widget buildWidget() {
      return localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: message,
            isSessionActivelyResponding: false,
          ),
        ),
      );
    }

    await tester.pumpWidget(buildWidget());

    expect(
      find.byKey(
        const ValueKey<String>(
          'tool_part_details_button_part_tool_chain_rebuild_1',
        ),
      ),
      findsNothing,
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'tool_chain_toggle_msg_tool_chain_rebuild_call_tool_chain_rebuild_1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>(
          'tool_part_details_button_part_tool_chain_rebuild_1',
        ),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>(
          'tool_part_details_button_part_tool_chain_rebuild_1',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('uses input description while tool is running', (
    WidgetTester tester,
  ) async {
    final message = AssistantMessage(
      id: 'msg_tool_running_description',
      sessionId: 'ses_tool_running_description',
      time: DateTime.fromMillisecondsSinceEpoch(1000),
      parts: <MessagePart>[
        ToolPart(
          id: 'part_tool_running_description',
          messageId: 'msg_tool_running_description',
          sessionId: 'ses_tool_running_description',
          callId: 'call_tool_running_description',
          tool: 'bash',
          state: ToolStateRunning(
            input: const <String, dynamic>{
              'description': 'Checking project status in real time',
              'command': 'git status --short',
            },
            time: DateTime.fromMillisecondsSinceEpoch(1000),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: message,
            isSessionActivelyResponding: true,
          ),
        ),
      ),
    );

    expect(find.text('Checking project status in real time'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'tool_part_details_button_part_tool_running_description',
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey<String>(
          'tool_part_details_button_part_tool_running_description',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('Hide'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.key == const ValueKey<String>('tool_command_text') &&
            widget.text.toPlainText().contains('Command: git status --short'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows tool call descriptions in collapsed summary', (
    WidgetTester tester,
  ) async {
    final message = AssistantMessage(
      id: 'msg_tool_summary_descriptions',
      sessionId: 'ses_tool_summary_descriptions',
      time: DateTime.fromMillisecondsSinceEpoch(1000),
      completedTime: DateTime.fromMillisecondsSinceEpoch(1200),
      parts: <MessagePart>[
        ToolPart(
          id: 'part_tool_summary_descriptions_1',
          messageId: 'msg_tool_summary_descriptions',
          sessionId: 'ses_tool_summary_descriptions',
          callId: 'call_tool_summary_descriptions_1',
          tool: 'bash',
          state: ToolStateCompleted(
            input: const <String, dynamic>{'command': 'ls'},
            output: 'README.md',
            time: ToolTime(
              start: DateTime.fromMillisecondsSinceEpoch(1000),
              end: DateTime.fromMillisecondsSinceEpoch(1050),
            ),
            title: 'Listing project files',
          ),
        ),
        ToolPart(
          id: 'part_tool_summary_descriptions_2',
          messageId: 'msg_tool_summary_descriptions',
          sessionId: 'ses_tool_summary_descriptions',
          callId: 'call_tool_summary_descriptions_2',
          tool: 'read',
          state: ToolStateCompleted(
            input: const <String, dynamic>{'filePath': 'README.md'},
            output: 'Intro',
            time: ToolTime(
              start: DateTime.fromMillisecondsSinceEpoch(1060),
              end: DateTime.fromMillisecondsSinceEpoch(1100),
            ),
            title: 'Reading project docs',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(body: ChatMessageWidget(message: message)),
      ),
    );

    expect(find.text('Details'), findsOneWidget);
    expect(find.textContaining('Listing project files'), findsOneWidget);
    expect(find.textContaining('Reading project docs'), findsOneWidget);
  });

  testWidgets('shows collapsed progress summary for active multi-tool chains', (
    WidgetTester tester,
  ) async {
    final message = AssistantMessage(
      id: 'msg_tool_summary_progress',
      sessionId: 'ses_tool_summary_progress',
      time: DateTime.fromMillisecondsSinceEpoch(1000),
      parts: <MessagePart>[
        ToolPart(
          id: 'part_tool_summary_progress_1',
          messageId: 'msg_tool_summary_progress',
          sessionId: 'ses_tool_summary_progress',
          callId: 'call_tool_summary_progress_1',
          tool: 'bash',
          state: ToolStateRunning(
            input: const <String, dynamic>{
              'description': 'Inspecting repository state',
              'command': 'git status --short',
            },
            time: DateTime.fromMillisecondsSinceEpoch(1000),
          ),
        ),
        const ToolPart(
          id: 'part_tool_summary_progress_2',
          messageId: 'msg_tool_summary_progress',
          sessionId: 'ses_tool_summary_progress',
          callId: 'call_tool_summary_progress_2',
          tool: 'read',
          state: ToolStatePending(),
        ),
      ],
    );

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: message,
            isSessionActivelyResponding: true,
          ),
        ),
      ),
    );

    expect(find.text('1 running • 1 queued'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>(
          'tool_part_details_button_part_tool_summary_progress_1',
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('resets tool-chain expansion after widget remount', (
    WidgetTester tester,
  ) async {
    final message = AssistantMessage(
      id: 'msg_tool_chain_remount',
      sessionId: 'ses_tool_chain_remount',
      time: DateTime.fromMillisecondsSinceEpoch(1000),
      completedTime: DateTime.fromMillisecondsSinceEpoch(1200),
      parts: <MessagePart>[
        ToolPart(
          id: 'part_tool_chain_remount_1',
          messageId: 'msg_tool_chain_remount',
          sessionId: 'ses_tool_chain_remount',
          callId: 'call_chain_remount_1',
          tool: 'bash',
          state: ToolStateCompleted(
            input: const <String, dynamic>{'command': 'pwd'},
            output: '/tmp/project',
            time: ToolTime(
              start: DateTime.fromMillisecondsSinceEpoch(1000),
              end: DateTime.fromMillisecondsSinceEpoch(1050),
            ),
          ),
        ),
        ToolPart(
          id: 'part_tool_chain_remount_2',
          messageId: 'msg_tool_chain_remount',
          sessionId: 'ses_tool_chain_remount',
          callId: 'call_chain_remount_2',
          tool: 'read',
          state: ToolStateCompleted(
            input: const <String, dynamic>{'filePath': 'lib/main.dart'},
            output: 'line 1\nline 2',
            time: ToolTime(
              start: DateTime.fromMillisecondsSinceEpoch(1060),
              end: DateTime.fromMillisecondsSinceEpoch(1100),
            ),
          ),
        ),
      ],
    );

    Widget buildWidget() {
      return localizedMaterialApp(
        home: Scaffold(body: ChatMessageWidget(message: message)),
      );
    }

    await tester.pumpWidget(buildWidget());
    expect(find.text('Details'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'tool_chain_toggle_msg_tool_chain_remount_call_chain_remount_1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hide'), findsNWidgets(2));
    expect(find.text('Running command'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    expect(find.text('Details'), findsOneWidget);
    expect(find.textContaining('Running command'), findsOneWidget);
  });

  testWidgets('hides assistant title while keeping user header label', (
    WidgetTester tester,
  ) async {
    final userMessage = UserMessage(
      id: 'msg_user_header',
      sessionId: 'ses_header_labels',
      time: DateTime.fromMillisecondsSinceEpoch(1000),
      parts: const <MessagePart>[
        TextPart(
          id: 'part_user_header',
          messageId: 'msg_user_header',
          sessionId: 'ses_header_labels',
          text: 'User text',
        ),
      ],
    );

    final assistantMessage = AssistantMessage(
      id: 'msg_assistant_header',
      sessionId: 'ses_header_labels',
      time: DateTime.fromMillisecondsSinceEpoch(1100),
      completedTime: DateTime.fromMillisecondsSinceEpoch(1200),
      parts: const <MessagePart>[
        TextPart(
          id: 'part_assistant_header',
          messageId: 'msg_assistant_header',
          sessionId: 'ses_header_labels',
          text: 'Assistant text',
        ),
      ],
    );

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ChatMessageWidget(message: userMessage),
              ChatMessageWidget(message: assistantMessage),
            ],
          ),
        ),
      ),
    );

    expect(find.text('You'), findsOneWidget);
    expect(find.text('Assistant'), findsNothing);
    expect(find.text('Assistant text'), findsOneWidget);
  });

  testWidgets('uses narrower max width for user bubbles on wide layouts', (
    WidgetTester tester,
  ) async {
    final repeatedText = List<String>.filled(
      8,
      'This message is intentionally long to fill the bubble width.',
    ).join(' ');

    final userMessage = UserMessage(
      id: 'msg_user_dynamic_width',
      sessionId: 'ses_dynamic_width',
      time: DateTime.fromMillisecondsSinceEpoch(1000),
      parts: <MessagePart>[
        TextPart(
          id: 'part_user_dynamic_width',
          messageId: 'msg_user_dynamic_width',
          sessionId: 'ses_dynamic_width',
          text: repeatedText,
        ),
      ],
    );

    final assistantMessage = AssistantMessage(
      id: 'msg_assistant_dynamic_width',
      sessionId: 'ses_dynamic_width',
      time: DateTime.fromMillisecondsSinceEpoch(1100),
      completedTime: DateTime.fromMillisecondsSinceEpoch(1200),
      parts: <MessagePart>[
        TextPart(
          id: 'part_assistant_dynamic_width',
          messageId: 'msg_assistant_dynamic_width',
          sessionId: 'ses_dynamic_width',
          text: repeatedText,
        ),
      ],
    );

    Widget buildFrame(Widget child) {
      // Default widget-test surface is 800px wide; 900 here intentionally
      // clamps to the available viewport after scaffold/padding constraints.
      return localizedMaterialApp(
        home: Scaffold(body: SizedBox(width: 900, child: child)),
      );
    }

    await tester.pumpWidget(
      buildFrame(ChatMessageWidget(message: userMessage)),
    );
    await tester.pumpAndSettle();

    final userBubbleSize = tester.getSize(
      find.byKey(
        const ValueKey<String>('message_bubble_msg_user_dynamic_width'),
      ),
    );

    await tester.pumpWidget(
      buildFrame(ChatMessageWidget(message: assistantMessage)),
    );
    await tester.pumpAndSettle();

    final assistantBubbleSize = tester.getSize(
      find.byKey(
        const ValueKey<String>('message_bubble_msg_assistant_dynamic_width'),
      ),
    );

    expect(userBubbleSize.width, lessThan(assistantBubbleSize.width));
    expect(userBubbleSize.width, lessThanOrEqualTo(640));
  });

  testWidgets('keeps user bubble within narrow viewport constraints', (
    WidgetTester tester,
  ) async {
    final repeatedText = List<String>.filled(
      4,
      'Narrow viewport message content for wrapping behavior.',
    ).join(' ');

    final userMessage = UserMessage(
      id: 'msg_user_narrow_width',
      sessionId: 'ses_narrow_width',
      time: DateTime.fromMillisecondsSinceEpoch(1000),
      parts: <MessagePart>[
        TextPart(
          id: 'part_user_narrow_width',
          messageId: 'msg_user_narrow_width',
          sessionId: 'ses_narrow_width',
          text: repeatedText,
        ),
      ],
    );

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: ChatMessageWidget(message: userMessage),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final userBubbleWidth = tester.getSize(
      find.byKey(
        const ValueKey<String>('message_bubble_msg_user_narrow_width'),
      ),
    );

    expect(userBubbleWidth.width, lessThanOrEqualTo(280));
    expect(userBubbleWidth.width, greaterThan(160));
  });

  testWidgets('assistant header spacing follows visual density', (
    WidgetTester tester,
  ) async {
    final message = AssistantMessage(
      id: 'msg_density_spacing',
      sessionId: 'ses_density_spacing',
      time: DateTime.fromMillisecondsSinceEpoch(1100),
      completedTime: DateTime.fromMillisecondsSinceEpoch(1200),
      parts: const <MessagePart>[
        TextPart(
          id: 'part_density_spacing',
          messageId: 'msg_density_spacing',
          sessionId: 'ses_density_spacing',
          text: 'Density aware content',
        ),
      ],
    );

    Future<double> pumpAndReadSpacing(VisualDensity density) async {
      await tester.pumpWidget(
        localizedMaterialApp(
          theme: ThemeData(useMaterial3: true, visualDensity: density),
          home: Scaffold(body: ChatMessageWidget(message: message)),
        ),
      );
      await tester.pumpAndSettle();
      final spacing = tester.widget<SizedBox>(
        find.byKey(
          const ValueKey<String>('message_header_spacing_msg_density_spacing'),
        ),
      );
      return spacing.height!;
    }

    final denseHeight = await pumpAndReadSpacing(
      const VisualDensity(horizontal: -2, vertical: -2),
    );
    final normalHeight = await pumpAndReadSpacing(VisualDensity.standard);
    final spaciousHeight = await pumpAndReadSpacing(
      const VisualDensity(horizontal: 2, vertical: 2),
    );

    expect(denseHeight, lessThanOrEqualTo(normalHeight));
    expect(spaciousHeight, greaterThan(normalHeight));
  });

  testWidgets(
    'thinking starts compact, expands with bounded viewport, and previous block collapses',
    (WidgetTester tester) async {
      AssistantMessage buildMessage(List<MessagePart> parts) {
        return AssistantMessage(
          id: 'msg_thinking',
          sessionId: 'ses_thinking',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          parts: parts,
        );
      }

      Widget buildWidget(AssistantMessage message) {
        return localizedMaterialApp(
          home: Scaffold(body: ChatMessageWidget(message: message)),
        );
      }

      const reasoningOne = ReasoningPart(
        id: 'thinking_1',
        messageId: 'msg_thinking',
        sessionId: 'ses_thinking',
        text:
            'line 1\nline 2\nline 3\nline 4\nline 5\nline 6\nline 7\nline 8\nline 9\nline 10',
      );
      const reasoningTwo = ReasoningPart(
        id: 'thinking_2',
        messageId: 'msg_thinking',
        sessionId: 'ses_thinking',
        text: 'step 1\nstep 2\nstep 3\nstep 4\nstep 5\nstep 6',
      );

      await tester.pumpWidget(
        buildWidget(buildMessage(const <MessagePart>[reasoningOne])),
      );

      final firstViewportFinder = find.byKey(
        const ValueKey<String>(
          'thinking_content_viewport_msg_thinking::thinking_1',
        ),
      );
      final collapsedHeight = tester.getSize(firstViewportFinder).height;
      expect(
        find.byKey(
          const ValueKey<String>(
            'thinking_content_toggle_msg_thinking::thinking_1',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>(
            'thinking_content_scrollbar_msg_thinking::thinking_1',
          ),
        ),
        findsNothing,
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'thinking_content_toggle_msg_thinking::thinking_1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final expandedHeight = tester.getSize(firstViewportFinder).height;
      expect(expandedHeight, greaterThan(collapsedHeight));
      expect(
        find.byKey(
          const ValueKey<String>(
            'thinking_content_scrollbar_msg_thinking::thinking_1',
          ),
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(
        buildWidget(
          buildMessage(const <MessagePart>[reasoningOne, reasoningTwo]),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>(
            'thinking_content_scrollbar_msg_thinking::thinking_1',
          ),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey<String>(
            'thinking_content_viewport_msg_thinking::thinking_2',
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'hides reasoning block when first line is a markdown status marker',
    (WidgetTester tester) async {
      final message = AssistantMessage(
        id: 'msg_status_reasoning',
        sessionId: 'ses_status_reasoning',
        time: DateTime.fromMillisecondsSinceEpoch(1000),
        parts: const <MessagePart>[
          ReasoningPart(
            id: 'reasoning_status',
            messageId: 'msg_status_reasoning',
            sessionId: 'ses_status_reasoning',
            text: '**Indexing workspace**\ncollecting files...',
          ),
        ],
      );

      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(body: ChatMessageWidget(message: message)),
        ),
      );

      expect(find.text('Thinking Process'), findsNothing);
      expect(
        find.byKey(
          const ValueKey<String>(
            'thinking_content_text_msg_status_reasoning::reasoning_status',
          ),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'thinking auto-collapses when latest reasoning moves to another message',
    (WidgetTester tester) async {
      final message = AssistantMessage(
        id: 'msg_a',
        sessionId: 'ses_thinking',
        time: DateTime.fromMillisecondsSinceEpoch(1000),
        parts: const <MessagePart>[
          ReasoningPart(
            id: 'thinking_a',
            messageId: 'msg_a',
            sessionId: 'ses_thinking',
            text: 'line 1\nline 2\nline 3\nline 4\nline 5\nline 6',
          ),
        ],
      );

      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: ChatMessageWidget(
              message: message,
              activeReasoningPartKey: 'msg_a::thinking_a',
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('thinking_content_toggle_msg_a::thinking_a'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>(
            'thinking_content_scrollbar_msg_a::thinking_a',
          ),
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: ChatMessageWidget(
              message: message,
              activeReasoningPartKey: 'msg_b::thinking_b',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>(
            'thinking_content_scrollbar_msg_a::thinking_a',
          ),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('renders the active live reasoning bubble while busy', (
    WidgetTester tester,
  ) async {
    final message = AssistantMessage(
      id: 'msg_busy_reasoning',
      sessionId: 'ses_busy_reasoning',
      time: DateTime.fromMillisecondsSinceEpoch(1000),
      parts: const <MessagePart>[
        ReasoningPart(
          id: 'thinking_busy',
          messageId: 'msg_busy_reasoning',
          sessionId: 'ses_busy_reasoning',
          text: 'Inspecting the latest workspace changes',
        ),
      ],
    );

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: message,
            activeReasoningPartKey: 'msg_busy_reasoning::thinking_busy',
            isSessionActivelyResponding: true,
          ),
        ),
      ),
    );

    expect(find.text('Thinking Process'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>(
          'thinking_content_text_msg_busy_reasoning::thinking_busy',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('message_bubble_msg_busy_reasoning')),
      findsOneWidget,
    );
  });

  testWidgets(
    'renders sequential reasoning bubbles for the active collapsed tool run',
    (WidgetTester tester) async {
      final message = AssistantMessage(
        id: 'msg_busy_tool_reasoning_chain',
        sessionId: 'ses_busy_tool_reasoning_chain',
        time: DateTime.fromMillisecondsSinceEpoch(1000),
        parts: <MessagePart>[
          const ReasoningPart(
            id: 'thinking_chain_1',
            messageId: 'msg_busy_tool_reasoning_chain',
            sessionId: 'ses_busy_tool_reasoning_chain',
            text: 'Inspecting the repository structure',
          ),
          ToolPart(
            id: 'tool_chain_1',
            messageId: 'msg_busy_tool_reasoning_chain',
            sessionId: 'ses_busy_tool_reasoning_chain',
            callId: 'call_chain_1',
            tool: 'bash',
            state: ToolStateRunning(
              input: const <String, dynamic>{'command': 'git status'},
              time: DateTime.fromMillisecondsSinceEpoch(1100),
            ),
          ),
          const ReasoningPart(
            id: 'thinking_chain_2',
            messageId: 'msg_busy_tool_reasoning_chain',
            sessionId: 'ses_busy_tool_reasoning_chain',
            text: 'Comparing the latest tool results',
          ),
          ToolPart(
            id: 'tool_chain_2',
            messageId: 'msg_busy_tool_reasoning_chain',
            sessionId: 'ses_busy_tool_reasoning_chain',
            callId: 'call_chain_2',
            tool: 'read',
            state: ToolStateRunning(
              input: const <String, dynamic>{'filePath': 'README.md'},
              time: DateTime.fromMillisecondsSinceEpoch(1200),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: ChatMessageWidget(
              message: message,
              activeReasoningPartKey:
                  'msg_busy_tool_reasoning_chain::thinking_chain_2',
              isSessionActivelyResponding: true,
            ),
          ),
        ),
      );

      expect(find.text('Inspecting the repository structure'), findsOneWidget);
      expect(find.text('Comparing the latest tool results'), findsOneWidget);
      expect(find.text('Thinking Process'), findsNWidgets(2));
      expect(
        find.byKey(
          const ValueKey<String>(
            'tool_chain_toggle_msg_busy_tool_reasoning_chain_call_chain_1',
          ),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Running command'), findsOneWidget);
    },
  );

  testWidgets('renders colorized diff for apply_patch tool', (tester) async {
    const diffOutput = '''--- file.dart
+++ file.dart
@@ -1,2 +1,3 @@
 context
-old line
+new line''';

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_diff_1',
              sessionId: 'ses_diff',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'tool_diff_1',
                  messageId: 'msg_diff_1',
                  sessionId: 'ses_diff',
                  callId: 'call_diff_1',
                  tool: 'apply_patch',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{},
                    output: diffOutput,
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1100),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('tool_part_details_button_tool_diff_1'),
      ),
    );
    await tester.pumpAndSettle();

    // Linhas de diff colorizadas devem estar presentes
    expect(
      find.byKey(const ValueKey<String>('diff_line_container_0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('tool_output_diff_container_0')),
      findsOneWidget,
    );
  });

  testWidgets('applies diff foreground and background styles', (tester) async {
    const diffOutput = '''--- file.dart
+++ file.dart
@@ -1,2 +1,3 @@
 context
-old line
+new line''';

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_diff_styled_1',
              sessionId: 'ses_diff',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'tool_diff_styled_1',
                  messageId: 'msg_diff_styled_1',
                  sessionId: 'ses_diff',
                  callId: 'call_diff_styled_1',
                  tool: 'apply_patch',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{},
                    output: diffOutput,
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1100),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('tool_part_details_button_tool_diff_styled_1'),
      ),
    );
    await tester.pumpAndSettle();

    final addContainer = tester.widget<Container>(
      find.byKey(const ValueKey<String>('tool_output_diff_container_5')),
    );
    final removeContainer = tester.widget<Container>(
      find.byKey(const ValueKey<String>('tool_output_diff_container_4')),
    );
    final hunkContainer = tester.widget<Container>(
      find.byKey(const ValueKey<String>('tool_output_diff_container_2')),
    );

    final addText = tester.widget<Text>(
      find.byKey(const ValueKey<String>('tool_output_diff_text_5')),
    );
    final removeText = tester.widget<Text>(
      find.byKey(const ValueKey<String>('tool_output_diff_text_4')),
    );
    final hunkText = tester.widget<Text>(
      find.byKey(const ValueKey<String>('tool_output_diff_text_2')),
    );
    final metadataText = tester.widget<Text>(
      find.byKey(const ValueKey<String>('tool_output_diff_text_0')),
    );

    expect(addText.style?.color, isNotNull);
    expect(addContainer.color, isNotNull);
    expect(removeText.style?.color, isNotNull);
    expect(removeContainer.color, isNotNull);
    expect(hunkText.style?.color, isNotNull);
    expect(hunkContainer.color, isNotNull);
    expect(metadataText.style?.color, isNotNull);
  });

  testWidgets(
    'renders colorized diff from apply_patch input when output is empty',
    (tester) async {
      const patchInput = '''*** Begin Patch
*** Update File: lib/main.dart
@@
-old line
+new line
*** End Patch''';

      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: ChatMessageWidget(
              message: AssistantMessage(
                id: 'msg_diff_input_1',
                sessionId: 'ses_diff',
                time: DateTime.fromMillisecondsSinceEpoch(1000),
                parts: <MessagePart>[
                  ToolPart(
                    id: 'tool_diff_input_1',
                    messageId: 'msg_diff_input_1',
                    sessionId: 'ses_diff',
                    callId: 'call_diff_input_1',
                    tool: 'apply_patch',
                    state: ToolStateCompleted(
                      input: const <String, dynamic>{'patch': patchInput},
                      output: '',
                      time: ToolTime(
                        start: DateTime.fromMillisecondsSinceEpoch(1000),
                        end: DateTime.fromMillisecondsSinceEpoch(1100),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('tool_part_details_button_tool_diff_input_1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('diff_line_container_0')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('tool_output_diff_container_0')),
        findsOneWidget,
      );
    },
  );

  testWidgets('colorizes apply_patch input section when output is success', (
    tester,
  ) async {
    const patchInput = '''*** Begin Patch
*** Update File: lib/main.dart
@@
-old line
+new line
*** End Patch''';

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_diff_input_success_1',
              sessionId: 'ses_diff',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'tool_diff_input_success_1',
                  messageId: 'msg_diff_input_success_1',
                  sessionId: 'ses_diff',
                  callId: 'call_diff_input_success_1',
                  tool: 'apply_patch',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{'patchText': patchInput},
                    output: 'Success. Updated the following files:\nM file.txt',
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1100),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'tool_part_details_button_tool_diff_input_success_1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('tool_input_diff_container_0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('tool_input_diff_text_3')),
      findsOneWidget,
    );

    final removeLineContainer = tester.widget<Container>(
      find.byKey(const ValueKey<String>('tool_input_diff_container_3')),
    );
    final addLineContainer = tester.widget<Container>(
      find.byKey(const ValueKey<String>('tool_input_diff_container_4')),
    );

    expect(removeLineContainer.color, isNotNull);
    expect(addLineContainer.color, isNotNull);
  });

  testWidgets('uses MediaQuery textScaler in expanded diff lines', (
    tester,
  ) async {
    const diffOutput = '''--- file.dart
+++ file.dart
@@ -1,2 +1,3 @@
 context
-old line
+new line''';
    const expectedScaler = TextScaler.linear(1.2);
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      localizedMaterialApp(
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(
            context,
          ).copyWith(textScaler: expectedScaler);
          return MediaQuery(data: mediaQuery, child: child!);
        },
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_diff_scaler',
              sessionId: 'ses_diff',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'tool_diff_scaler',
                  messageId: 'msg_diff_scaler',
                  sessionId: 'ses_diff',
                  callId: 'call_diff_scaler',
                  tool: 'apply_patch',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{},
                    output: diffOutput,
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1100),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Future<void> ensureToolDetailsExpanded() async {
      final detailsFinder = find.text('Details');
      if (detailsFinder.evaluate().isNotEmpty) {
        await tester.tap(detailsFinder.first);
        await tester.pumpAndSettle();
      }
    }

    await ensureToolDetailsExpanded();

    Future<void> expandToolOutputIfCollapsed() async {
      expect(
        find.byKey(
          const ValueKey<String>('tool_content_scroll_tool_output_diff'),
        ),
        findsOneWidget,
      );
    }

    await expandToolOutputIfCollapsed();

    final scaledHeight = tester
        .getSize(
          find.byKey(const ValueKey<String>('tool_output_diff_container_5')),
        )
        .height;

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_diff_scaler_default',
              sessionId: 'ses_diff',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'tool_diff_scaler_default',
                  messageId: 'msg_diff_scaler_default',
                  sessionId: 'ses_diff',
                  callId: 'call_diff_scaler_default',
                  tool: 'apply_patch',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{},
                    output: diffOutput,
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1100),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Details').first);
    await tester.pumpAndSettle();
    await expandToolOutputIfCollapsed();

    final defaultHeight = tester
        .getSize(
          find.byKey(const ValueKey<String>('tool_output_diff_container_5')),
        )
        .height;

    expect(scaledHeight, greaterThan(defaultHeight));
  });

  testWidgets('detects diff in bash git diff via heuristic', (tester) async {
    const gitDiff = '''diff --git a/lib/main.dart b/lib/main.dart
--- a/lib/main.dart
+++ b/lib/main.dart
@@ -1,1 +1,2 @@
-old
+new''';

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_diff_2',
              sessionId: 'ses_diff',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'tool_diff_2',
                  messageId: 'msg_diff_2',
                  sessionId: 'ses_diff',
                  callId: 'call_diff_2',
                  tool: 'bash', // Não é apply_patch, detecta via heurística
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{'command': 'git diff'},
                    output: gitDiff,
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1150),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('tool_part_details_button_tool_diff_2'),
      ),
    );
    await tester.pumpAndSettle();

    // Deve colorizar mesmo sendo bash
    expect(
      find.byKey(const ValueKey<String>('diff_line_container_0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('tool_output_diff_container_0')),
      findsOneWidget,
    );
  });

  testWidgets('does not colorize normal bash output', (tester) async {
    const plainOutput = 'file1.txt\nfile2.txt';

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_diff_3',
              sessionId: 'ses_diff',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'tool_diff_3',
                  messageId: 'msg_diff_3',
                  sessionId: 'ses_diff',
                  callId: 'call_diff_3',
                  tool: 'bash',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{'command': 'ls'},
                    output: plainOutput,
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1050),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('tool_part_details_button_tool_diff_3'),
      ),
    );
    await tester.pumpAndSettle();

    // Texto plano curto permanece sem viewport interno dedicado.
    expect(find.text(plainOutput), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('tool_content_scroll_tool_output_diff'),
      ),
      findsNothing,
    );
  });

  testWidgets('preserves content when collapsing and expanding diff', (
    tester,
  ) async {
    const diff = '@@ -1,1 +1,2 @@\n-old\n+new';

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_diff_4',
              sessionId: 'ses_diff',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'tool_diff_4',
                  messageId: 'msg_diff_4',
                  sessionId: 'ses_diff',
                  callId: 'call_diff_4',
                  tool: 'edit',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{},
                    output: diff,
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1080),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('tool_part_details_button_tool_diff_4'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>('tool_content_scroll_tool_output_diff'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('tool_output_diff_text_2')),
      findsOneWidget,
    );
  });

  testWidgets('renders colorized diff for edit tool', (tester) async {
    const editDiff = '''diff --git a/test.dart b/test.dart
index abc123..def456 100644
--- a/test.dart
+++ b/test.dart
@@ -10,5 +10,6 @@
 normal line
-removed line
+added line
 another normal line''';

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_diff_5',
              sessionId: 'ses_diff',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'tool_diff_5',
                  messageId: 'msg_diff_5',
                  sessionId: 'ses_diff',
                  callId: 'call_diff_5',
                  tool: 'edit',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{},
                    output: editDiff,
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1120),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('tool_part_details_button_tool_diff_5'),
      ),
    );
    await tester.pumpAndSettle();

    // Diff por linha deve estar presente
    expect(
      find.byKey(const ValueKey<String>('diff_line_container_0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('tool_output_diff_container_0')),
      findsOneWidget,
    );
  });

  testWidgets('builds synthetic diff for edit tool when output is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_edit_input',
              sessionId: 'ses_diff',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'tool_edit_input',
                  messageId: 'msg_edit_input',
                  sessionId: 'ses_diff',
                  callId: 'call_edit_input',
                  tool: 'edit',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{
                      'file_path': 'lib/sample.dart',
                      'old_string': 'line old',
                      'new_string': 'line new',
                    },
                    output: '',
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1100),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('tool_part_details_button_tool_edit_input'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('diff_line_container_0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('tool_output_diff_container_0')),
      findsOneWidget,
    );
  });

  testWidgets('hides thinking bubbles when toggle is disabled', (
    WidgetTester tester,
  ) async {
    final message = AssistantMessage(
      id: 'msg_hide_thinking',
      sessionId: 'ses_hide_thinking',
      time: DateTime.fromMillisecondsSinceEpoch(1000),
      parts: const <MessagePart>[
        ReasoningPart(
          id: 'part_reasoning_hide',
          messageId: 'msg_hide_thinking',
          sessionId: 'ses_hide_thinking',
          text: 'line 1\nline 2\nline 3',
        ),
      ],
    );

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(message: message, showThinkingBubbles: false),
        ),
      ),
    );

    expect(find.text('Thinking Process'), findsNothing);
    expect(
      find.byKey(
        const ValueKey<String>(
          'thinking_content_text_msg_hide_thinking::part_reasoning_hide',
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('hides tool call bubbles when toggle is disabled', (
    WidgetTester tester,
  ) async {
    final message = AssistantMessage(
      id: 'msg_hide_tool',
      sessionId: 'ses_hide_tool',
      time: DateTime.fromMillisecondsSinceEpoch(1000),
      parts: <MessagePart>[
        ToolPart(
          id: 'part_tool_hide',
          messageId: 'msg_hide_tool',
          sessionId: 'ses_hide_tool',
          callId: 'call_hide_tool',
          tool: 'bash',
          state: ToolStateCompleted(
            input: const <String, dynamic>{'cmd': 'pwd'},
            output: '/tmp',
            time: ToolTime(
              start: DateTime.fromMillisecondsSinceEpoch(1000),
              end: DateTime.fromMillisecondsSinceEpoch(1200),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(message: message, showToolCallBubbles: false),
        ),
      ),
    );

    expect(find.text('Running command'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('tool_command_text')),
      findsNothing,
    );
    expect(find.text('Assistant'), findsNothing);
  });

  testWidgets('hides patch bubbles when tool call toggle is disabled', (
    WidgetTester tester,
  ) async {
    final message = AssistantMessage(
      id: 'msg_hide_patch',
      sessionId: 'ses_hide_patch',
      time: DateTime.fromMillisecondsSinceEpoch(1000),
      parts: const <MessagePart>[
        PatchPart(
          id: 'part_patch_hide',
          messageId: 'msg_hide_patch',
          sessionId: 'ses_hide_patch',
          files: <String>['lib/main.dart'],
          hash: 'abc123',
        ),
      ],
    );

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(message: message, showToolCallBubbles: false),
        ),
      ),
    );

    expect(find.text('Patch'), findsNothing);
    expect(find.text('Assistant'), findsNothing);
  });

  testWidgets('hides todowrite and todoread tool calls and empty bubble', (
    WidgetTester tester,
  ) async {
    final message = AssistantMessage(
      id: 'msg_hide_todo',
      sessionId: 'ses_hide_todo',
      time: DateTime.fromMillisecondsSinceEpoch(1000),
      parts: <MessagePart>[
        ToolPart(
          id: 'part_todo_write',
          messageId: 'msg_hide_todo',
          sessionId: 'ses_hide_todo',
          callId: 'call_todo_write',
          tool: 'todowrite',
          state: ToolStateCompleted(
            input: const <String, dynamic>{'tasks': []},
            output: 'ok',
            time: ToolTime(
              start: DateTime.fromMillisecondsSinceEpoch(1000),
              end: DateTime.fromMillisecondsSinceEpoch(1200),
            ),
          ),
        ),
        ToolPart(
          id: 'part_todo_read',
          messageId: 'msg_hide_todo',
          sessionId: 'ses_hide_todo',
          callId: 'call_todo_read',
          tool: 'todoread',
          state: ToolStateCompleted(
            input: const <String, dynamic>{},
            output: '[]',
            time: ToolTime(
              start: DateTime.fromMillisecondsSinceEpoch(1200),
              end: DateTime.fromMillisecondsSinceEpoch(1400),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(body: ChatMessageWidget(message: message)),
      ),
    );

    expect(find.text('Updating task list'), findsNothing);
    expect(find.text('Assistant'), findsNothing);
  });

  testWidgets('expanded tool output caps content viewport height', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.reset);

    final longOutput = List<String>.generate(
      120,
      (index) => 'output line $index',
    ).join('\n');

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_tool_height_cap',
              sessionId: 'ses_tool_height_cap',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'part_tool_height_cap',
                  messageId: 'msg_tool_height_cap',
                  sessionId: 'ses_tool_height_cap',
                  callId: 'call_tool_height_cap',
                  tool: 'bash',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{'command': 'cat big.log'},
                    output: longOutput,
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1200),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('tool_part_details_button_part_tool_height_cap'),
      ),
    );
    await tester.pumpAndSettle();

    final viewportSize = tester.getSize(
      find.byKey(
        const ValueKey<String>('tool_content_scroll_tool_output_diff'),
      ),
    );
    expect(viewportSize.height, lessThanOrEqualTo(300));
  });

  testWidgets('truncates oversized tool payload to keep UI responsive', (
    WidgetTester tester,
  ) async {
    final hugeOutput = List<String>.filled(12000, 'line payload').join('\n');

    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_huge_tool',
              sessionId: 'ses_huge_tool',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'part_huge_tool',
                  messageId: 'msg_huge_tool',
                  sessionId: 'ses_huge_tool',
                  callId: 'call_huge',
                  tool: 'bash',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{'command': 'cat huge.log'},
                    output: hugeOutput,
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1200),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey<String>('tool_part_details_button_part_huge_tool'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Large tool output preview truncated'),
      findsOneWidget,
    );
  });

  testWidgets('shows feedback for invalid markdown link format', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_link_open_failure',
              sessionId: 'ses_link_open_failure',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_link_open_failure',
                  messageId: 'msg_link_open_failure',
                  sessionId: 'ses_link_open_failure',
                  text: '[Broken link](://invalid)',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Broken link'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid link format'), findsOneWidget);
  });

  testWidgets('renders subtask navigation action when callback is provided', (
    WidgetTester tester,
  ) async {
    SubtaskPart? tappedSubtask;
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_subtask_nav',
              sessionId: 'ses_subtask_nav',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[
                SubtaskPart(
                  id: 'part_subtask_nav',
                  messageId: 'msg_subtask_nav',
                  sessionId: 'ses_subtask_nav',
                  prompt: 'Open child',
                  description: 'Inspect sub-conversation',
                  agent: 'reviewer',
                ),
              ],
            ),
            onSubtaskNavigate: (part) {
              tappedSubtask = part;
            },
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('subtask_open_session_part_subtask_nav'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tappedSubtask?.id, 'part_subtask_nav');
  });

  testWidgets('renders task tool navigation action when callback is provided', (
    WidgetTester tester,
  ) async {
    ToolPart? tappedToolPart;
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_task_tool_nav',
              sessionId: 'ses_task_tool_nav',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'part_task_tool_nav',
                  messageId: 'msg_task_tool_nav',
                  sessionId: 'ses_task_tool_nav',
                  callId: 'call_task_tool_nav',
                  tool: 'task',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{
                      'description': 'Open generated child conversation',
                    },
                    output: 'done',
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1010),
                    ),
                  ),
                ),
              ],
            ),
            onTaskToolNavigate: (part) {
              tappedToolPart = part;
            },
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('task_tool_open_session_part_task_tool_nav'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tappedToolPart?.id, 'part_task_tool_nav');
  });

  testWidgets('shows latest command for a running task tool bubble', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_task_tool_command',
              sessionId: 'ses_task_tool_command',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'part_task_tool_command',
                  messageId: 'msg_task_tool_command',
                  sessionId: 'ses_task_tool_command',
                  callId: 'call_task_tool_command',
                  tool: 'task',
                  state: ToolStateRunning(
                    input: const <String, dynamic>{
                      'description': 'Run project checks',
                      'command': 'make check',
                    },
                    time: DateTime.fromMillisecondsSinceEpoch(1000),
                  ),
                ),
              ],
            ),
            isSessionActivelyResponding: true,
          ),
        ),
      ),
    );

    expect(find.text('make check'), findsOneWidget);
  });

  testWidgets('hides task view and details controls in favor of bubble tap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_task_tool_compact',
              sessionId: 'ses_task_tool_compact',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'part_task_tool_compact',
                  messageId: 'msg_task_tool_compact',
                  sessionId: 'ses_task_tool_compact',
                  callId: 'call_task_tool_compact',
                  tool: 'task',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{
                      'description': 'Compact task bubble',
                    },
                    output: 'done',
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1010),
                    ),
                  ),
                ),
              ],
            ),
            onTaskToolNavigate: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('View'), findsNothing);
    expect(find.text('Details'), findsNothing);
    expect(find.text('Show'), findsNothing);
    expect(
      find.byKey(
        const ValueKey<String>('task_tool_open_session_part_task_tool_compact'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows total tool call count for a completed task bubble', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_task_tool_summary',
              sessionId: 'ses_task_tool_summary',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'part_task_tool_summary',
                  messageId: 'msg_task_tool_summary',
                  sessionId: 'ses_task_tool_summary',
                  callId: 'call_task_tool_summary',
                  tool: 'task',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{
                      'description': 'Summarize child tool calls',
                    },
                    output: 'done',
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1010),
                    ),
                  ),
                ),
              ],
            ),
            taskToolChildSummariesByPartId:
                const <String, TaskToolChildSummary>{
                  'part_task_tool_summary': TaskToolChildSummary(
                    latestToolLabel: 'Reading',
                    toolCallCount: 3,
                  ),
                },
          ),
        ),
      ),
    );

    expect(find.text('3 tool calls'), findsOneWidget);
  });

  testWidgets('keeps active task tool bubbles last within each task run', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_task_tool_order',
              sessionId: 'ses_task_tool_order',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                const TextPart(
                  id: 'part_task_order_intro',
                  messageId: 'msg_task_tool_order',
                  sessionId: 'ses_task_tool_order',
                  text: 'Before task run',
                ),
                ToolPart(
                  id: 'part_task_tool_running_1',
                  messageId: 'msg_task_tool_order',
                  sessionId: 'ses_task_tool_order',
                  callId: 'call_task_tool_running_1',
                  tool: 'task',
                  state: ToolStateRunning(
                    input: const <String, dynamic>{
                      'description': 'Running task one',
                    },
                    time: DateTime.fromMillisecondsSinceEpoch(1100),
                  ),
                ),
                ToolPart(
                  id: 'part_task_tool_completed_1',
                  messageId: 'msg_task_tool_order',
                  sessionId: 'ses_task_tool_order',
                  callId: 'call_task_tool_completed_1',
                  tool: 'task',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{
                      'description': 'Completed task one',
                    },
                    output: 'done',
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1100),
                      end: DateTime.fromMillisecondsSinceEpoch(1200),
                    ),
                  ),
                ),
                const TextPart(
                  id: 'part_task_order_middle',
                  messageId: 'msg_task_tool_order',
                  sessionId: 'ses_task_tool_order',
                  text: 'Between task runs',
                ),
                ToolPart(
                  id: 'part_task_tool_running_2',
                  messageId: 'msg_task_tool_order',
                  sessionId: 'ses_task_tool_order',
                  callId: 'call_task_tool_running_2',
                  tool: 'task',
                  state: ToolStateRunning(
                    input: const <String, dynamic>{
                      'description': 'Running task two',
                    },
                    time: DateTime.fromMillisecondsSinceEpoch(1300),
                  ),
                ),
                ToolPart(
                  id: 'part_task_tool_completed_2',
                  messageId: 'msg_task_tool_order',
                  sessionId: 'ses_task_tool_order',
                  callId: 'call_task_tool_completed_2',
                  tool: 'task',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{
                      'description': 'Completed task two',
                    },
                    output: 'done',
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1300),
                      end: DateTime.fromMillisecondsSinceEpoch(1400),
                    ),
                  ),
                ),
                const TextPart(
                  id: 'part_task_order_outro',
                  messageId: 'msg_task_tool_order',
                  sessionId: 'ses_task_tool_order',
                  text: 'After task run',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final introDy = tester.getTopLeft(find.text('Before task run')).dy;
    final completedOneDy = tester
        .getTopLeft(find.text('Completed task one'))
        .dy;
    final runningOneDy = tester.getTopLeft(find.text('Running task one')).dy;
    final middleDy = tester.getTopLeft(find.text('Between task runs')).dy;
    final completedTwoDy = tester
        .getTopLeft(find.text('Completed task two'))
        .dy;
    final runningTwoDy = tester.getTopLeft(find.text('Running task two')).dy;
    final outroDy = tester.getTopLeft(find.text('After task run')).dy;

    expect(introDy, lessThan(completedOneDy));
    expect(completedOneDy, lessThan(runningOneDy));
    expect(runningOneDy, lessThan(middleDy));
    expect(middleDy, lessThan(completedTwoDy));
    expect(completedTwoDy, lessThan(runningTwoDy));
    expect(runningTwoDy, lessThan(outroDy));
  });
}
