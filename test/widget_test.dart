import 'dart:async';
import 'dart:convert';

import 'package:codewalk/core/di/injection_container.dart' as di;
import 'package:codewalk/core/i18n/l10n_bridge.dart';
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/domain/entities/canned_answer.dart';
import 'package:codewalk/domain/entities/chat_composer_draft.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/session_attention/session_attention_host_service.dart';
import 'package:codewalk/presentation/services/sound_service.dart';
import 'package:codewalk/presentation/services/speech_input_service_stt.dart';
import 'package:codewalk/presentation/widgets/chat_input/chat_input_external_files.dart';
import 'package:codewalk/presentation/widgets/chat_input_widget.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import 'support/fakes.dart';
import 'support/pump_localized_app.dart';

Widget _buildChatInputHarness({
  required ChatInputWidget child,
  MediaQueryData? mediaQueryData,
  double? width,
  SettingsProvider? settingsProvider,
}) {
  final content = width == null ? child : SizedBox(width: width, child: child);
  Widget home = Scaffold(
    body: Align(alignment: Alignment.bottomCenter, child: content),
  );
  if (mediaQueryData != null) {
    home = MediaQuery(data: mediaQueryData, child: home);
  }
  if (settingsProvider != null) {
    home = ChangeNotifierProvider<SettingsProvider>.value(
      value: settingsProvider,
      child: home,
    );
  }
  return localizedMaterialApp(home: home);
}

class _FakeSttSpeechInputService extends SttSpeechInputService {
  int startCount = 0;
  int stopCount = 0;
  bool _listening = false;

  @override
  bool get isListening => _listening;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function(String status) onStatus,
    required void Function() onError,
    Duration? pauseFor,
    String? localeId,
  }) async {
    startCount += 1;
    _listening = true;
    onStatus('listening');
  }

  @override
  Future<void> stopListening() async {
    stopCount += 1;
    _listening = false;
  }
}

class _NoopSessionAttentionHostService implements SessionAttentionHostService {
  static const _capability = SessionAttentionHostCapability(
    kind: SessionAttentionHostKind.unsupported,
    supported: false,
    permissionGranted: false,
    running: false,
    topmostSupported: false,
  );

  @override
  Future<SessionAttentionHostActivationResult> activate(
    SessionAttentionPresentation presentation,
  ) async => const SessionAttentionHostActivationResult.failure(
    _capability,
    'unsupported',
  );

  @override
  Future<SessionAttentionHostCapability> capability() async => _capability;

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<void> stop() async {}
}

/// In-memory [FilePickerPlatform] for composer attachment tests.
///
/// file_picker v12 removed the v11 method-channel pick protocol, so tests
/// inject picked files through the platform instance instead of mocking
/// `miguelruivo.flutter.plugins.filepicker`.
class _FakeAttachmentPicker extends FilePickerPlatform {
  _FakeAttachmentPicker(this.files);

  final List<PlatformFile> files;

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    return files;
  }
}

void main() {
  testWidgets('extras button flips to an arrow while the popover is open', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildChatInputHarness(child: ChatInputWidget(onSendMessage: (_) {})),
    );
    await tester.pump();

    final button = find.byKey(const ValueKey<String>('composer_extras_button'));

    // Closed: plus icon and the "open" tooltip.
    expect(button, findsOneWidget);
    expect(
      tester.widget<IconButton>(button).tooltip,
      L10nBridge.current!.composerExtras,
    );
    expect(
      ((tester.widget<IconButton>(button).icon) as Icon).icon,
      Symbols.add_rounded,
    );

    await tester.tap(button);
    await tester.pumpAndSettle();

    // Open: arrow icon and the "hide" tooltip.
    expect(
      tester.widget<IconButton>(button).tooltip,
      L10nBridge.current!.composerExtrasHide,
    );
    expect(
      ((tester.widget<IconButton>(button).icon) as Icon).icon,
      Symbols.keyboard_arrow_down_rounded,
    );

    await tester.tap(button);
    await tester.pumpAndSettle();

    // Closing restores both.
    expect(
      tester.widget<IconButton>(button).tooltip,
      L10nBridge.current!.composerExtras,
    );
    expect(
      ((tester.widget<IconButton>(button).icon) as Icon).icon,
      Symbols.add_rounded,
    );
  });

  testWidgets('ChatInputWidget renders and sends message', (
    WidgetTester tester,
  ) async {
    ChatInputSubmission? sentSubmission;

    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (submission) {
            sentSubmission = submission;
          },
        ),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(
      find.byTooltip(L10nBridge.current!.chatStartVoiceInput),
      findsOneWidget,
    );
    expect(find.byIcon(Symbols.send_rounded), findsOneWidget);
    expect(find.byIcon(Symbols.keyboard_return_rounded), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pumpAndSettle();

    expect(find.byIcon(Symbols.send_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Symbols.send_rounded));
    await tester.pumpAndSettle();

    expect(sentSubmission?.text, 'hello');
    expect(sentSubmission?.mode, ChatComposerMode.normal);
  });

  testWidgets('extras button is visible with plus icon', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (_) {},
          cannedAnswersDataSource: InMemoryAppLocalDataSource(),
        ),
      ),
    );

    expect(find.byTooltip('Extras'), findsOneWidget);
    expect(find.byIcon(Symbols.add_rounded), findsOneWidget);
  });

  testWidgets('external voice toggle is ignored when composer is disabled', (
    WidgetTester tester,
  ) async {
    final localDataSource = InMemoryAppLocalDataSource()
      ..experienceSettingsJson = '{"checkUpdatesOnOpen": false}';
    final settingsProvider = SettingsProvider(
      localDataSource: localDataSource,
      dioClient: DioClient(),
      soundService: SoundService(),
      sessionAttentionHostService: _NoopSessionAttentionHostService(),
    );
    await settingsProvider.initialize();
    addTearDown(settingsProvider.dispose);

    final previousStt = di.sl.isRegistered<SttSpeechInputService>()
        ? di.sl<SttSpeechInputService>()
        : null;
    if (di.sl.isRegistered<SttSpeechInputService>()) {
      di.sl.unregister<SttSpeechInputService>();
    }
    final fakeStt = _FakeSttSpeechInputService();
    di.sl.registerSingleton<SttSpeechInputService>(fakeStt);
    addTearDown(() {
      if (di.sl.isRegistered<SttSpeechInputService>()) {
        di.sl.unregister<SttSpeechInputService>();
      }
      if (previousStt != null) {
        di.sl.registerSingleton<SttSpeechInputService>(previousStt);
      }
    });

    final controller = ChatInputController();
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _buildChatInputHarness(
        settingsProvider: settingsProvider,
        child: ChatInputWidget(
          controller: controller,
          focusNode: focusNode,
          enabled: false,
          onSendMessage: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.canToggleVoiceInput, isFalse);

    await controller.toggleVoiceInput();
    await tester.pump();

    expect(fakeStt.startCount, 0);
    expect(focusNode.hasFocus, isFalse);
  });

  testWidgets('composer shows block reason when offline sends are blocked', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          enabled: false,
          blockReason: 'Waiting for network connection...',
          onSendMessage: (_) {},
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('composer_block_reason_row')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('composer_block_reason_text')),
      findsOneWidget,
    );

    final inputField = tester.widget<TextField>(find.byType(TextField));
    expect(inputField.enabled, isFalse);
  });

  testWidgets('canned append inserts text at current cursor', (
    WidgetTester tester,
  ) async {
    final localDataSource = InMemoryAppLocalDataSource();
    await localDataSource.saveCannedAnswersJson(
      jsonEncode([
        {
          'id': 'append-1',
          'text': 'XYZ',
          'insertMode': 'append',
          'scopeMode': 'global',
          'updatedAtEpochMs': 1,
        },
      ]),
    );

    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (_) {},
          cannedAnswersDataSource: localDataSource,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.showKeyboard(find.byType(TextField));
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'ab',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Extras'));
    await tester.pumpAndSettle();
    expect(find.text('Extras'), findsNothing);
    expect(find.text('Quick replies'), findsNothing);
    await tester.tap(find.text('XYZ'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'aXYZb');
    expect(field.focusNode?.hasFocus, isTrue);
  });

  testWidgets('canned auto-send appends at cursor and submits result', (
    WidgetTester tester,
  ) async {
    final localDataSource = InMemoryAppLocalDataSource();
    ChatInputSubmission? sentSubmission;
    await localDataSource.saveCannedAnswersJson(
      jsonEncode([
        {
          'id': 'append-send-1',
          'text': 'XYZ',
          'insertMode': 'append',
          'sendAutomatically': true,
          'scopeMode': 'global',
          'updatedAtEpochMs': 1,
        },
      ]),
    );

    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (submission) {
            sentSubmission = submission;
          },
          cannedAnswersDataSource: localDataSource,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.showKeyboard(find.byType(TextField));
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'ab',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Extras'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('XYZ'));
    await tester.pumpAndSettle();

    expect(sentSubmission?.text, 'aXYZb');
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('opening extras preserves composer focus state', (
    WidgetTester tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          focusNode: focusNode,
          onSendMessage: (_) {},
          cannedAnswersDataSource: InMemoryAppLocalDataSource(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isTrue);

    // Found by key rather than tooltip: the tooltip now reflects the open
    // state, which is the point of #117.
    final extrasButton = find.byKey(
      const ValueKey<String>('composer_extras_button'),
    );

    await tester.tap(extrasButton);
    await tester.pumpAndSettle();

    expect(focusNode.hasFocus, isTrue);
    expect(find.text('New quick reply'), findsOneWidget);

    await tester.tap(extrasButton);
    await tester.pumpAndSettle();

    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('opening extras keeps unfocused composer unfocused', (
    WidgetTester tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          focusNode: focusNode,
          onSendMessage: (_) {},
          cannedAnswersDataSource: InMemoryAppLocalDataSource(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(focusNode.hasFocus, isFalse);

    await tester.tap(find.byTooltip('Extras'));
    await tester.pumpAndSettle();

    expect(focusNode.hasFocus, isFalse);
    expect(find.text('New quick reply'), findsOneWidget);
  });

  testWidgets('canned replace mode replaces current composer text', (
    WidgetTester tester,
  ) async {
    final localDataSource = InMemoryAppLocalDataSource();
    await localDataSource.saveCannedAnswersJson(
      jsonEncode([
        {
          'id': 'replace-1',
          'text': 'Replacement text',
          'insertMode': 'replace',
          'scopeMode': 'global',
          'updatedAtEpochMs': 2,
        },
      ]),
    );

    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (_) {},
          cannedAnswersDataSource: localDataSource,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'old text');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Extras'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replacement text'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Replacement text');
  });

  testWidgets('canned auto-send replace mode submits replaced text', (
    WidgetTester tester,
  ) async {
    final localDataSource = InMemoryAppLocalDataSource();
    ChatInputSubmission? sentSubmission;
    await localDataSource.saveCannedAnswersJson(
      jsonEncode([
        {
          'id': 'replace-send-1',
          'text': 'Replacement text',
          'insertMode': 'replace',
          'sendAutomatically': true,
          'scopeMode': 'global',
          'updatedAtEpochMs': 2,
        },
      ]),
    );

    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (submission) {
            sentSubmission = submission;
          },
          cannedAnswersDataSource: localDataSource,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'old text');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Extras'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replacement text'));
    await tester.pumpAndSettle();

    expect(sentSubmission?.text, 'Replacement text');
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('new quick reply dialog shows auto-send switch', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (_) {},
          cannedAnswersDataSource: InMemoryAppLocalDataSource(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Extras'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New quick reply'));
    await tester.pumpAndSettle();

    expect(find.text('Send automatically'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'new quick reply dialog shows agent model and variant selectors',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildChatInputHarness(
          child: ChatInputWidget(
            onSendMessage: (_) {},
            cannedAnswersDataSource: InMemoryAppLocalDataSource(),
            quickReplyAgentOptions: const <ChatQuickReplyAgentOption>[
              ChatQuickReplyAgentOption(name: 'plan', label: 'Plan'),
            ],
            quickReplyModelOptions: const <ChatQuickReplyModelOption>[
              ChatQuickReplyModelOption(
                providerId: 'provider_1',
                providerLabel: 'Provider 1',
                modelId: 'model_1',
                modelLabel: 'Model 1',
                variantOptions: <ChatQuickReplyThinkingOption>[
                  ChatQuickReplyThinkingOption(id: 'high', label: 'High'),
                ],
              ),
            ],
            quickReplyThinkingOptions: const <ChatQuickReplyThinkingOption>[
              ChatQuickReplyThinkingOption(id: 'high', label: 'High'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Extras'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New quick reply'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('canned_answer_agent_dropdown')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('canned_answer_model_dropdown')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('canned_answer_thinking_dropdown')),
        findsOneWidget,
      );
      expect(find.text('Next variant'), findsOneWidget);
      expect(find.text('Choose effort'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('new quick reply editor uses fullscreen on compact screens', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (_) {},
          cannedAnswersDataSource: InMemoryAppLocalDataSource(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Extras'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New quick reply'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('canned_answer_editor_fullscreen')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('canned_answer_editor_dialog')),
      findsNothing,
    );
  });

  testWidgets('new quick reply editor uses centered dialog on wide screens', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1000, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (_) {},
          cannedAnswersDataSource: InMemoryAppLocalDataSource(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Extras'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New quick reply'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('canned_answer_editor_dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('canned_answer_editor_fullscreen')),
      findsNothing,
    );
  });

  testWidgets('canned override applies before auto-send', (
    WidgetTester tester,
  ) async {
    final localDataSource = InMemoryAppLocalDataSource();
    var overrideApplied = false;
    var sentAfterOverride = false;
    await localDataSource.saveCannedAnswersJson(
      jsonEncode([
        {
          'id': 'override-send-1',
          'text': 'Route me',
          'insertMode': 'append',
          'sendAutomatically': true,
          'scopeMode': 'global',
          'agentName': 'plan',
          'providerId': 'provider_1',
          'modelId': 'model_1',
          'thinkingMode': 'auto',
          'updatedAtEpochMs': 1,
        },
      ]),
    );

    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (_) {
            sentAfterOverride = overrideApplied;
          },
          cannedAnswersDataSource: localDataSource,
          onApplyQuickReplySelectionOverride: (override) async {
            expect(override.agentName, 'plan');
            expect(override.providerId, 'provider_1');
            expect(override.modelId, 'model_1');
            expect(override.thinkingMode, CannedAnswerThinkingMode.auto);
            overrideApplied = true;
            return const ChatQuickReplySelectionApplyResult(applied: true);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Extras'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Route me'));
    await tester.pumpAndSettle();

    expect(overrideApplied, isTrue);
    expect(sentAfterOverride, isTrue);
  });

  testWidgets('failed canned override inserts text and blocks auto-send', (
    WidgetTester tester,
  ) async {
    final localDataSource = InMemoryAppLocalDataSource();
    ChatInputSubmission? sentSubmission;
    await localDataSource.saveCannedAnswersJson(
      jsonEncode([
        {
          'id': 'override-fail-1',
          'text': 'Manual review',
          'insertMode': 'append',
          'sendAutomatically': true,
          'scopeMode': 'global',
          'agentName': 'missing',
          'updatedAtEpochMs': 1,
        },
      ]),
    );

    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (submission) {
            sentSubmission = submission;
          },
          cannedAnswersDataSource: localDataSource,
          onApplyQuickReplySelectionOverride: (_) async {
            return const ChatQuickReplySelectionApplyResult(
              applied: false,
              message: 'Routing failed',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Extras'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manual review'));
    await tester.pumpAndSettle();

    expect(sentSubmission, isNull);
    expect(find.text('Routing failed'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Manual review');
  });

  testWidgets('extras menu shows top quick-reply and attachment actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (_) {},
          cannedAnswersDataSource: InMemoryAppLocalDataSource(),
          showAttachmentButton: true,
          showInlineAttachmentButton: false,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Extras'));
    await tester.pumpAndSettle();

    expect(find.text('Extras'), findsNothing);
    expect(find.text('Quick replies'), findsNothing);
    expect(find.text('New quick reply'), findsOneWidget);
    expect(find.text('Attach files'), findsOneWidget);
    expect(find.text('No quick replies yet.'), findsOneWidget);
  });

  testWidgets('global canned answer shows one-line globe plus label only', (
    WidgetTester tester,
  ) async {
    final localDataSource = InMemoryAppLocalDataSource();
    await localDataSource.saveCannedAnswersJson(
      jsonEncode([
        {
          'id': 'global-1',
          'label': 'Global reply',
          'text': 'Shared text',
          'insertMode': 'append',
          'scopeMode': 'global',
          'updatedAtEpochMs': 1,
        },
      ]),
    );

    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (_) {},
          cannedAnswersDataSource: localDataSource,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Extras'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Symbols.public_rounded), findsOneWidget);
    expect(find.text('Global reply'), findsOneWidget);
    expect(find.text('Shared text'), findsNothing);
  });

  testWidgets('canned routing overrides show compact indicators', (
    WidgetTester tester,
  ) async {
    final localDataSource = InMemoryAppLocalDataSource();
    await localDataSource.saveCannedAnswersJson(
      jsonEncode([
        {
          'id': 'routing-1',
          'label': 'Routed reply',
          'text': 'Hidden routed text',
          'insertMode': 'append',
          'scopeMode': 'global',
          'agentName': 'plan',
          'providerId': 'provider_1',
          'modelId': 'model_1',
          'thinkingMode': 'auto',
          'updatedAtEpochMs': 1,
        },
      ]),
    );

    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (_) {},
          cannedAnswersDataSource: localDataSource,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Extras'));
    await tester.pumpAndSettle();

    expect(find.text('Routed reply'), findsOneWidget);
    expect(find.text('Hidden routed text'), findsNothing);
    expect(find.byIcon(Symbols.support_agent_rounded), findsOneWidget);
    expect(find.byIcon(Symbols.code_rounded), findsOneWidget);
    expect(find.byIcon(Symbols.tune_rounded), findsOneWidget);
  });

  testWidgets(
    'holding send button for 300ms inserts newline instead of sending',
    (WidgetTester tester) async {
      ChatInputSubmission? sentSubmission;

      await tester.pumpWidget(
        _buildChatInputHarness(
          child: ChatInputWidget(
            onSendMessage: (submission) {
              sentSubmission = submission;
            },
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pumpAndSettle();

      final sendButtonFinder = find.byType(FilledButton);
      final gesture = await tester.startGesture(
        tester.getCenter(sendButtonFinder),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(sentSubmission, isNull);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, 'hello\n');
    },
  );

  testWidgets('typing ! enters shell mode and sends shell submission', (
    WidgetTester tester,
  ) async {
    ChatInputSubmission? sentSubmission;

    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (submission) {
            sentSubmission = submission;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '!pwd');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('composer_shell_mode_chip')),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Symbols.send_rounded));
    await tester.pumpAndSettle();

    expect(sentSubmission?.mode, ChatComposerMode.shell);
    expect(sentSubmission?.text, 'pwd');
  });

  testWidgets('prefilled draft restores attachment-only composer state', (
    WidgetTester tester,
  ) async {
    var prefilledVersion = 0;
    ChatComposerDraft? prefilledDraft;

    Widget buildHarness() {
      return _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (_) {},
          showAttachmentButton: true,
          prefilledDraft: prefilledDraft,
          prefilledDraftVersion: prefilledVersion,
        ),
      );
    }

    await tester.pumpWidget(buildHarness());

    prefilledDraft = const ChatComposerDraft(
      text: '',
      attachments: <FileInputPart>[
        FileInputPart(
          mime: 'image/png',
          url: 'data:image/png;base64,AA==',
          filename: 'image.png',
        ),
      ],
    );
    prefilledVersion = 1;
    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('composer_attachments_row')),
      findsOneWidget,
    );
    expect(find.text('image.png'), findsOneWidget);
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, isEmpty);
  });

  testWidgets('attachment picker appends multiple supported files', (
    WidgetTester tester,
  ) async {
    // file_picker v12 has no method-channel pick protocol anymore: picks
    // resolve through the registered FilePickerPlatform, so the test injects
    // an in-memory fake returning the same three names as before.
    final previousPicker = FilePickerPlatform.instance;
    FilePickerPlatform.instance = _FakeAttachmentPicker(
      <PlatformFile>[
        ComposerMemoryFile(
          name: 'screen.png',
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
        ),
        ComposerMemoryFile(
          name: 'brief.pdf',
          bytes: Uint8List.fromList(<int>[4, 5, 6, 7]),
        ),
        ComposerMemoryFile(
          name: 'notes.txt',
          bytes: Uint8List.fromList(<int>[8]),
        ),
      ],
    );
    addTearDown(() {
      FilePickerPlatform.instance = previousPicker;
    });

    ChatInputSubmission? sentSubmission;
    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (submission) {
            sentSubmission = submission;
          },
          showAttachmentButton: true,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Add attachment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Attach files'));
    await tester.pumpAndSettle();

    expect(find.text('screen.png'), findsOneWidget);
    expect(find.text('brief.pdf'), findsOneWidget);
    expect(find.text('notes.txt'), findsNothing);
    expect(
      find.text('Some selected files could not be attached.'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Symbols.send_rounded));
    await tester.pumpAndSettle();

    expect(sentSubmission?.attachments, hasLength(2));
    expect(
      sentSubmission?.attachments.map((attachment) => attachment.mime),
      <String>['image/png', 'application/pdf'],
    );
  });

  testWidgets('drop keeps target state and sends client bytes as data URL', (
    WidgetTester tester,
  ) async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      ChatInputSubmission? sentSubmission;
      await tester.pumpWidget(
        _buildChatInputHarness(
          child: ChatInputWidget(
            onSendMessage: (submission) => sentSubmission = submission,
            showAttachmentButton: true,
          ),
        ),
      );

      final dropFinder = find.byKey(
        const ValueKey<String>('composer_drop_target'),
      );
      final initialState = tester.state(dropFinder);
      tester
          .widget<DropTarget>(dropFinder)
          .onDragEntered
          ?.call(
            DropEventDetails(
              localPosition: Offset.zero,
              globalPosition: Offset.zero,
            ),
          );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('composer_drop_highlight')),
        findsOneWidget,
      );
      expect(tester.state(dropFinder), same(initialState));

      tester
          .widget<DropTarget>(dropFinder)
          .onDragDone
          ?.call(
            DropDoneDetails(
              files: <DropItem>[
                DropItemFile.fromData(
                  Uint8List.fromList(<int>[1, 2, 3]),
                  path: '/tmp/a/screen.png',
                  name: 'screen.png',
                  mimeType: 'image/png',
                ),
                DropItemFile.fromData(
                  Uint8List.fromList(<int>[3, 2, 1]),
                  path: '/tmp/b/screen.png',
                  name: 'screen.png',
                  mimeType: 'image/png',
                ),
              ],
              localPosition: Offset.zero,
              globalPosition: Offset.zero,
            ),
          );
      await tester.pumpAndSettle();

      expect(find.text('screen.png'), findsNWidgets(2));
      await tester.tap(find.byIcon(Symbols.send_rounded));
      await tester.pumpAndSettle();
      expect(sentSubmission?.attachments, hasLength(2));
      expect(sentSubmission?.attachments.map((item) => item.url), <String>[
        'data:image/png;base64,AQID',
        'data:image/png;base64,AwIB',
      ]);
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });

  testWidgets('drop target disables in shell mode and below another route', (
    WidgetTester tester,
  ) async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(
        _buildChatInputHarness(
          child: ChatInputWidget(
            onSendMessage: (_) {},
            showAttachmentButton: true,
          ),
        ),
      );
      final dropFinder = find.byKey(
        const ValueKey<String>('composer_drop_target'),
      );
      expect(tester.widget<DropTarget>(dropFinder).enable, isTrue);

      await tester.enterText(find.byType(TextField), '!pwd');
      await tester.pumpAndSettle();
      expect(tester.widget<DropTarget>(dropFinder).enable, isFalse);

      await tester.enterText(find.byType(TextField), 'normal');
      await tester.pumpAndSettle();
      final inputContext = tester.element(find.byType(ChatInputWidget));
      unawaited(
        Navigator.of(
          inputContext,
        ).push<void>(MaterialPageRoute<void>(builder: (_) => const Scaffold())),
      );
      await tester.pumpAndSettle();

      final coveredDropFinder = find.byKey(
        const ValueKey<String>('composer_drop_target'),
        skipOffstage: false,
      );
      expect(tester.widget<DropTarget>(coveredDropFinder).enable, isFalse);
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });

  testWidgets('Android content URI paste attaches resolver bytes', (
    WidgetTester tester,
  ) async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const pasteboardChannel = MethodChannel('pasteboard');
    const clipboardChannel = MethodChannel('codewalk/composer_clipboard');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pasteboardChannel, (call) async {
      if (call.method == 'files') {
        return <String>['content://provider/document/42'];
      }
      if (call.method == 'image') {
        return null;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(clipboardChannel, (call) async {
      expect(call.method, 'readContentUri');
      final arguments = call.arguments as Map<Object?, Object?>;
      expect(arguments['uri'], 'content://provider/document/42');
      return <String, Object?>{
        'name': 'brief',
        'mimeType': 'application/pdf',
        'bytes': Uint8List.fromList(<int>[4, 5, 6]),
      };
    });
    try {
      ChatInputSubmission? sentSubmission;
      await tester.pumpWidget(
        _buildChatInputHarness(
          child: ChatInputWidget(
            onSendMessage: (submission) => sentSubmission = submission,
            showAttachmentButton: true,
          ),
        ),
      );
      await tester.showKeyboard(find.byType(TextField));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.text('brief.pdf'), findsOneWidget);
      await tester.tap(find.byIcon(Symbols.send_rounded));
      await tester.pumpAndSettle();
      expect(
        sentSubmission?.attachments.single.url,
        'data:application/pdf;base64,BAUG',
      );
    } finally {
      messenger.setMockMethodCallHandler(pasteboardChannel, null);
      messenger.setMockMethodCallHandler(clipboardChannel, null);
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });

  testWidgets('prefilled shell draft restores shell mode with ! prefix', (
    WidgetTester tester,
  ) async {
    var prefilledVersion = 0;
    ChatComposerDraft? prefilledDraft;

    Widget buildHarness() {
      return _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (_) {},
          prefilledDraft: prefilledDraft,
          prefilledDraftVersion: prefilledVersion,
        ),
      );
    }

    await tester.pumpWidget(buildHarness());

    prefilledDraft = const ChatComposerDraft(text: 'ls -la', shellMode: true);
    prefilledVersion = 1;
    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('composer_shell_mode_chip')),
      findsOneWidget,
    );
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, '!ls -la');
  });

  testWidgets('desktop Enter sends and Shift+Enter inserts newline', (
    WidgetTester tester,
  ) async {
    ChatInputSubmission? sentSubmission;
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(
        _buildChatInputHarness(
          child: ChatInputWidget(
            onSendMessage: (submission) {
              sentSubmission = submission;
            },
          ),
        ),
      );

      final desktopInputField = tester.widget<TextField>(
        find.byType(TextField),
      );
      expect(desktopInputField.textInputAction, TextInputAction.newline);

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      final textFieldAfterShift = tester.widget<TextField>(
        find.byType(TextField),
      );
      expect(textFieldAfterShift.controller!.text, 'hello\n');
      expect(sentSubmission, isNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(sentSubmission?.text, 'hello');
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });

  testWidgets('desktop ESC in normal mode keeps composer focus', (
    WidgetTester tester,
  ) async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(
        _buildChatInputHarness(child: ChatInputWidget(onSendMessage: (_) {})),
      );

      await tester.showKeyboard(find.byType(TextField));
      await tester.pumpAndSettle();

      final focusedBeforeEsc = tester.widget<TextField>(find.byType(TextField));
      expect(focusedBeforeEsc.focusNode?.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      final focusedAfterEsc = tester.widget<TextField>(find.byType(TextField));
      expect(focusedAfterEsc.focusNode?.hasFocus, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });

  testWidgets('double ESC within 500ms requests stop while responding', (
    WidgetTester tester,
  ) async {
    var stopCount = 0;
    var hintCount = 0;
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(
        _buildChatInputHarness(
          child: ChatInputWidget(
            onSendMessage: (_) {},
            isResponding: true,
            onStopRequested: () {
              stopCount += 1;
            },
            onStopHintRequested: () {
              hintCount += 1;
            },
          ),
        ),
      );

      await tester.showKeyboard(find.byType(TextField));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(stopCount, 0);
      expect(hintCount, 1);

      await tester.pump(const Duration(milliseconds: 300));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(stopCount, 1);
      expect(hintCount, 2);
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });

  testWidgets(
    'mobile Enter action sends with software keyboard insets active',
    (WidgetTester tester) async {
      ChatInputSubmission? sentSubmission;
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await tester.pumpWidget(
          _buildChatInputHarness(
            mediaQueryData: const MediaQueryData(
              viewInsets: EdgeInsets.only(bottom: 320),
            ),
            child: ChatInputWidget(
              onSendMessage: (submission) {
                sentSubmission = submission;
              },
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'hello');
        await tester.pumpAndSettle();

        final mobileInputField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(mobileInputField.textInputAction, TextInputAction.send);
        expect(mobileInputField.focusNode?.hasFocus, isTrue);

        mobileInputField.onSubmitted?.call('hello');
        await tester.pumpAndSettle();

        expect(sentSubmission?.text, 'hello');

        final updatedInputField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(updatedInputField.focusNode?.hasFocus, isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = previousPlatform;
      }
    },
  );

  testWidgets(
    'mobile Enter action keeps focus when software keyboard is hidden',
    (WidgetTester tester) async {
      ChatInputSubmission? sentSubmission;
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await tester.pumpWidget(
          _buildChatInputHarness(
            child: ChatInputWidget(
              onSendMessage: (submission) {
                sentSubmission = submission;
              },
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'hello');
        await tester.pumpAndSettle();

        final mobileInputField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(mobileInputField.textInputAction, TextInputAction.send);
        expect(mobileInputField.focusNode?.hasFocus, isTrue);

        mobileInputField.onSubmitted?.call('hello');
        await tester.pumpAndSettle();

        expect(sentSubmission?.text, 'hello');

        final updatedInputField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(updatedInputField.focusNode?.hasFocus, isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = previousPlatform;
      }
    },
  );

  testWidgets(
    'desktop ArrowUp and ArrowDown navigate sent-message history with caret boundaries',
    (WidgetTester tester) async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await tester.pumpWidget(
          _buildChatInputHarness(
            child: ChatInputWidget(
              onSendMessage: (_) {},
              sentMessageHistory: const <String>[
                'first prompt',
                'second prompt',
                'third prompt',
              ],
            ),
          ),
        );

        await tester.showKeyboard(find.byType(TextField));
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        var textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller!.text, 'third prompt');
        expect(
          textField.controller!.selection.baseOffset,
          'third prompt'.length,
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller!.text, 'third prompt');
        expect(textField.controller!.selection.baseOffset, 0);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller!.text, 'second prompt');
        expect(
          textField.controller!.selection.baseOffset,
          'second prompt'.length,
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller!.selection.baseOffset, 0);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        textField = tester.widget<TextField>(find.byType(TextField));
        expect(
          textField.controller!.selection.baseOffset,
          'second prompt'.length,
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller!.text, 'third prompt');

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller!.text, '');
      } finally {
        debugDefaultTargetPlatformOverride = previousPlatform;
      }
    },
  );

  testWidgets(
    'desktop ArrowUp keeps multiline editor movement before sent-message history',
    (WidgetTester tester) async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await tester.pumpWidget(
          _buildChatInputHarness(
            child: ChatInputWidget(
              onSendMessage: (_) {},
              sentMessageHistory: const <String>['third prompt'],
            ),
          ),
        );

        await tester.showKeyboard(find.byType(TextField));
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'first line\nsecond line',
            selection: TextSelection.collapsed(offset: 22),
          ),
        );
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();

        var textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller!.text, 'first line\nsecond line');
        expect(textField.controller!.selection.baseOffset, lessThan(22));

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();

        textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller!.text, 'third prompt');
      } finally {
        debugDefaultTargetPlatformOverride = previousPlatform;
      }
    },
  );

  testWidgets(
    'desktop ArrowDown keeps multiline editor movement before sent-message history restore',
    (WidgetTester tester) async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await tester.pumpWidget(
          _buildChatInputHarness(
            child: ChatInputWidget(
              onSendMessage: (_) {},
              sentMessageHistory: const <String>[
                'older prompt',
                'first line\nsecond line',
              ],
            ),
          ),
        );

        await tester.showKeyboard(find.byType(TextField));
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();

        var textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller!.text, 'first line\nsecond line');
        expect(textField.controller!.selection.baseOffset, lessThan(22));

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();

        textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller!.text, 'first line\nsecond line');
        expect(textField.controller!.selection.baseOffset, 22);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();

        textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller!.text, '');
      } finally {
        debugDefaultTargetPlatformOverride = previousPlatform;
      }
    },
  );

  testWidgets(
    'desktop ArrowUp respects soft-wrapped multiline movement before history',
    (WidgetTester tester) async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await tester.pumpWidget(
          _buildChatInputHarness(
            width: 220,
            child: ChatInputWidget(
              onSendMessage: (_) {},
              sentMessageHistory: const <String>['third prompt'],
            ),
          ),
        );

        await tester.showKeyboard(find.byType(TextField));
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text:
                'This is a long composer line that should wrap before history navigation',
            selection: TextSelection.collapsed(offset: 71),
          ),
        );
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(
          textField.controller!.text,
          'This is a long composer line that should wrap before history navigation',
        );
        expect(textField.controller!.selection.baseOffset, lessThan(71));
      } finally {
        debugDefaultTargetPlatformOverride = previousPlatform;
      }
    },
  );

  testWidgets(
    'desktop ArrowUp and ArrowDown with modifiers keep text field behavior',
    (WidgetTester tester) async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await tester.pumpWidget(
          _buildChatInputHarness(
            child: ChatInputWidget(
              onSendMessage: (_) {},
              sentMessageHistory: const <String>['third prompt'],
            ),
          ),
        );

        await tester.showKeyboard(find.byType(TextField));
        await tester.pumpAndSettle();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();

        var textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller!.text, '');

        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'first line\nsecond line',
            selection: TextSelection.collapsed(offset: 0),
          ),
        );
        await tester.pumpAndSettle();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller!.text, 'first line\nsecond line');
        expect(textField.controller!.selection.baseOffset, 0);
      } finally {
        debugDefaultTargetPlatformOverride = previousPlatform;
      }
    },
  );

  testWidgets('shows Stop action while responding and calls callback', (
    WidgetTester tester,
  ) async {
    var stopCount = 0;
    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (_) {},
          isResponding: true,
          onStopRequested: () {
            stopCount += 1;
          },
        ),
      ),
    );

    expect(find.byIcon(Symbols.stop_rounded), findsOneWidget);
    expect(find.byIcon(Symbols.send_rounded), findsNothing);

    await tester.tap(find.byIcon(Symbols.stop_rounded));
    await tester.pumpAndSettle();

    expect(stopCount, 1);
  });

  testWidgets('microphone stays enabled while responding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (_) {},
          isResponding: true,
          onStopRequested: () {},
        ),
      ),
    );

    final micButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip(L10nBridge.current!.chatStartVoiceInput),
        matching: find.byType(IconButton),
      ),
    );

    expect(micButton.onPressed, isNotNull);
  });

  testWidgets('microphone stays enabled while send is in flight', (
    WidgetTester tester,
  ) async {
    final sendCompleter = Completer<void>();
    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (_) async {
            await sendCompleter.future;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Symbols.send_rounded));
    await tester.pump();

    final micButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip(L10nBridge.current!.chatStartVoiceInput),
        matching: find.byType(IconButton),
      ),
    );
    expect(micButton.onPressed, isNotNull);

    sendCompleter.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('send completion does not clear draft changed while sending', (
    WidgetTester tester,
  ) async {
    final sendCompleter = Completer<void>();
    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (_) async {
            await sendCompleter.future;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'initial prompt');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Symbols.send_rounded));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'new draft while sending');
    await tester.pump();

    sendCompleter.complete();
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller!.text, 'new draft while sending');
  });

  testWidgets('responding with draft switches action to send', (
    WidgetTester tester,
  ) async {
    ChatInputSubmission? sentSubmission;
    var stopCount = 0;
    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (submission) {
            sentSubmission = submission;
          },
          isResponding: true,
          onStopRequested: () {
            stopCount += 1;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'follow-up prompt');
    await tester.pumpAndSettle();

    expect(find.byIcon(Symbols.send_rounded), findsOneWidget);
    expect(find.byIcon(Symbols.stop_rounded), findsNothing);

    await tester.tap(find.byIcon(Symbols.send_rounded));
    await tester.pumpAndSettle();

    expect(sentSubmission?.text, 'follow-up prompt');
    expect(stopCount, 0);
  });

  testWidgets('composer keeps outer background transparent', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildChatInputHarness(child: ChatInputWidget(onSendMessage: (_) {})),
    );

    final rootContainer = tester.widget<Container>(
      find.byKey(const ValueKey<String>('composer_root_container')),
    );
    final rootDecoration = rootContainer.decoration as BoxDecoration;
    expect(rootDecoration.color, Colors.transparent);

    final inputBubble = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('composer_input_bubble')),
    );
    final inputBubbleDecoration = inputBubble.decoration as BoxDecoration;
    expect(inputBubbleDecoration.color, isNot(Colors.transparent));
    expect(inputBubbleDecoration.border, isNull);
  });

  testWidgets('inline attachment button uses subtle transparent style', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (_) {},
          showAttachmentButton: true,
          showInlineAttachmentButton: true,
        ),
      ),
    );

    final attachButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Add attachment'),
        matching: find.byType(IconButton),
      ),
    );
    final style = attachButton.style;

    expect(style, isNotNull);
    expect(
      style!.backgroundColor?.resolve(const <WidgetState>{}),
      Colors.transparent,
    );
    expect(
      style.backgroundColor?.resolve(const <WidgetState>{WidgetState.hovered}),
      Colors.transparent,
    );
  });

  testWidgets('composer text field disables inherited hover fill', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildChatInputHarness(child: ChatInputWidget(onSendMessage: (_) {})),
    );

    final textField = tester.widget<TextField>(find.byType(TextField));
    final decoration = textField.decoration;

    expect(decoration, isNotNull);
    expect(decoration!.filled, isFalse);
    expect(decoration.fillColor, Colors.transparent);
    expect(decoration.hoverColor, Colors.transparent);
    expect(decoration.focusColor, Colors.transparent);
  });

  testWidgets('slash popover inserts selected command prefix', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (_) {},
          onSlashQuery: (query) async {
            return const <ChatComposerSlashCommandSuggestion>[
              ChatComposerSlashCommandSuggestion(
                name: 'open',
                source: 'command',
                description: 'Open file',
              ),
            ];
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '/op');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('composer_popover_slash')),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller!.text, '/open ');
  });

  testWidgets('mention popover inserts @ token', (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (_) {},
          onMentionQuery: (query) async {
            return const <ChatComposerMentionSuggestion>[
              ChatComposerMentionSuggestion(
                value: 'README.md',
                type: ChatComposerSuggestionType.file,
                subtitle: 'file',
              ),
            ];
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '@REA');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('composer_popover_mention')),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller!.text, '@README.md ');
  });

  testWidgets(
    'mention popover stays above input when keyboard insets are active',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildChatInputHarness(
          mediaQueryData: const MediaQueryData(
            size: Size(390, 844),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: ChatInputWidget(
            onSendMessage: (_) {},
            onMentionQuery: (query) async {
              return List<ChatComposerMentionSuggestion>.generate(
                20,
                (index) => ChatComposerMentionSuggestion(
                  value: 'README_$index.md',
                  type: ChatComposerSuggestionType.file,
                  subtitle: 'file',
                ),
              );
            },
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '@REA');
      await tester.pumpAndSettle();

      final popoverFinder = find.byKey(
        const ValueKey<String>('composer_popover_mention'),
      );
      expect(popoverFinder, findsOneWidget);
      final panelFinder = find.byKey(
        const ValueKey<String>('composer_popover_panel_mention'),
      );
      expect(panelFinder, findsOneWidget);

      final inputRect = tester.getRect(find.byType(TextField));
      final popoverRect = tester.getRect(panelFinder);
      expect(popoverRect.bottom, lessThanOrEqualTo(inputRect.top));
      expect(popoverRect.height, lessThanOrEqualTo(156));
      expect(inputRect.bottom, lessThanOrEqualTo(844 - 300));

      final popoverScrollableFinder = find.descendant(
        of: panelFinder,
        matching: find.byType(Scrollable),
      );
      expect(popoverScrollableFinder, findsOneWidget);
      expect(find.text('README_19.md'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('README_19.md'),
        80,
        scrollable: popoverScrollableFinder,
      );
      await tester.pumpAndSettle();
      expect(find.text('README_19.md'), findsOneWidget);
    },
  );

  testWidgets('mention selection keeps input focused while typing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildChatInputHarness(
        child: ChatInputWidget(
          onSendMessage: (_) {},
          onMentionQuery: (query) async {
            return const <ChatComposerMentionSuggestion>[
              ChatComposerMentionSuggestion(
                value: 'lib/main.dart',
                type: ChatComposerSuggestionType.file,
                subtitle: 'file',
              ),
            ];
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '@ma');
    await tester.pumpAndSettle();

    final inputField = tester.widget<TextField>(find.byType(TextField));
    expect(inputField.focusNode?.hasFocus, isTrue);
  });

  testWidgets(
    'mention insertion guarantees space before trailing punctuation',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildChatInputHarness(
          child: ChatInputWidget(
            onSendMessage: (_) {},
            onMentionQuery: (query) async {
              return const <ChatComposerMentionSuggestion>[
                ChatComposerMentionSuggestion(
                  value: 'README.md',
                  type: ChatComposerSuggestionType.file,
                  subtitle: 'file',
                ),
              ];
            },
          ),
        ),
      );

      await tester.showKeyboard(find.byType(TextField));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '@REA?',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, '@README.md ?');
    },
  );

  test('microphone button uses transparent background when inactive', () {
    const colorScheme = ColorScheme.light();
    expect(
      microphoneButtonBackgroundColor(
        isListening: false,
        colorScheme: colorScheme,
      ),
      Colors.transparent,
    );
    expect(
      microphoneButtonForegroundColor(
        isListening: false,
        colorScheme: colorScheme,
      ),
      colorScheme.onSecondaryContainer,
    );
  });

  test('microphone button turns red while listening', () {
    const colorScheme = ColorScheme.light();
    expect(
      microphoneButtonBackgroundColor(
        isListening: true,
        colorScheme: colorScheme,
      ),
      colorScheme.error,
    );
    expect(
      microphoneButtonForegroundColor(
        isListening: true,
        colorScheme: colorScheme,
      ),
      colorScheme.onError,
    );
  });

  test('splitComposerTextAtSelection keeps trailing text at caret', () {
    final split = splitComposerTextAtSelection(
      const TextEditingValue(
        text: 'hello world',
        selection: TextSelection.collapsed(offset: 6),
      ),
    );

    expect(split.leadingText, 'hello ');
    expect(split.trailingText, 'world');
  });

  test('splitComposerTextAtSelection replaces selected range', () {
    final split = splitComposerTextAtSelection(
      const TextEditingValue(
        text: 'hello brave world',
        selection: TextSelection(baseOffset: 6, extentOffset: 11),
      ),
    );

    expect(split.leadingText, 'hello ');
    expect(split.trailingText, ' world');
  });

  test('composeComposerValueWithSuffix keeps cursor before suffix', () {
    final value = composeComposerValueWithSuffix(
      leadingText: 'hello voice',
      trailingText: ' world',
    );

    expect(value.text, 'hello voice world');
    expect(value.selection.baseOffset, 'hello voice'.length);
    expect(value.selection.extentOffset, 'hello voice'.length);
  });

  test('composer attachment style keeps transparent backgrounds', () {
    final style = composerAttachButtonStyle(
      colorScheme: const ColorScheme.light(),
    );

    expect(
      style.backgroundColor?.resolve(const <WidgetState>{}),
      Colors.transparent,
    );
    expect(
      style.backgroundColor?.resolve(const <WidgetState>{WidgetState.hovered}),
      Colors.transparent,
    );
    expect(
      style.backgroundColor?.resolve(const <WidgetState>{WidgetState.pressed}),
      Colors.transparent,
    );
  });

  test('composer bubble color falls back when preferred is too close', () {
    const surface = Color(0xFF101010);
    const preferred = Color(0xFF101010);
    const fallbackOverlay = Color(0x1FFFFFFF);

    final resolved = resolveComposerBubbleColor(
      preferredColor: preferred,
      surfaceColor: surface,
      fallbackOverlayColor: fallbackOverlay,
      minLuminanceDelta: 0.03,
    );

    expect(resolved, isNot(surface));
  });

  test('composer bubble color keeps preferred when already distinct', () {
    const surface = Color(0xFF101010);
    const preferred = Color(0xFF2A2A2A);

    final resolved = resolveComposerBubbleColor(
      preferredColor: preferred,
      surfaceColor: surface,
      fallbackOverlayColor: const Color(0x1FFFFFFF),
      minLuminanceDelta: 0.01,
    );

    expect(resolved, preferred);
  });
}
