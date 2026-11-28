import 'package:codewalk/features/sessions/session_timeline_tile.dart';
import 'package:codewalk/features/settings/read_aloud_settings_page.dart';
import 'package:codewalk/features/voice/read_aloud_actions.dart';
import 'package:codewalk/features/voice/read_aloud_controller.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/voice/memory_speech_keys.dart';
import 'package:codewalk/shared/voice/read_aloud.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/gestures.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../storage/storage_fakes.dart';
import 'read_aloud_controller_test.dart' show FakePlayer, FakeSynth;

// #541: Read aloud in the message bar, its controls and its settings.

const _session = SessionRef(HostId('h'), HarnessInstanceId('h'), 'ses_1');

AssistantText _agent(String text) => AssistantText(
  meta: ItemMeta(
    id: const ItemId('test/a'),
    generation: 'test',
    status: const OpenValue.known(ItemStatus.completed),
    source: SourceProvenance(
      harness: const HarnessRef(HostId('h'), HarnessInstanceId('test')),
      version: '2.0.22',
      nativeType: 'test',
    ),
  ),
  text: text,
  complete: true,
);

void main() {
  late FakeSynth synth;
  late FakePlayer player;
  late MemorySpeechKeys keys;
  late FakeMetadataBackend backend;
  late ReadAloudController controller;

  setUp(() {
    synth = FakeSynth();
    player = FakePlayer();
    keys = MemorySpeechKeys();
    backend = FakeMetadataBackend();
    controller = ReadAloudController(
      metadata: V2MetadataStore(backend: backend),
      keys: keys,
      synthesizer: (provider) =>
          provider == SpeechProvider.system ? null : synth,
      locale: () => 'en-US',
      player: player,
    );
  });

  tearDown(() => controller.dispose());

  Widget app(Widget child) =>
      ChangeNotifierProvider<ReadAloudController?>.value(
        value: controller,
        child: MaterialApp(
          localizationsDelegates: V2Localizations.localizationsDelegates,
          supportedLocales: V2Localizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      );

  testWidgets('the bar reads a message, and the pill pauses and stops it', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        Column(
          children: [
            Builder(
              builder: (context) => SessionTimelineTile(
                item: _agent('Hello there'),
                actions: [
                  ?readAloudAction(context, _session, _agent('Hello there')),
                ],
              ),
            ),
            const Spacer(),
            const ReadAloudPill(session: _session),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('read-aloud-pill')), findsNothing);
    await tester.tap(find.text('Hello there'));
    await tester.pumpAndSettle();
    await tester.pump(kDoubleTapTimeout);
    await tester.tap(find.byKey(const ValueKey('message-action-readAloud')));
    await tester.pumpAndSettle();
    expect(synth.requests.single.text, 'Hello there');
    expect(find.byKey(const ValueKey('read-aloud-pill')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('read-aloud-pause')));
    await tester.pumpAndSettle();
    expect(controller.phase, ReadAloudPhase.paused);
    expect(find.byKey(const ValueKey('read-aloud-resume')), findsOneWidget);
    // The message's bar now offers Stop reading.
    await tester.tap(find.text('Hello there'));
    await tester.pumpAndSettle();
    await tester.pump(kDoubleTapTimeout);
    await tester.longPress(
      find.byKey(const ValueKey('message-action-readAloud')),
    );
    await tester.pump();
    expect(find.text('Stop reading'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.tapAt(const Offset(5, 590));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('read-aloud-stop')));
    await tester.pumpAndSettle();
    expect(controller.active, isNull);
    expect(find.byKey(const ValueKey('read-aloud-pill')), findsNothing);
  });

  testWidgets('switched off, messages offer no Read aloud', (tester) async {
    await controller.update(controller.settings.copyWith(enabled: false));
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => SessionTimelineTile(
            item: _agent('Hello there'),
            actions: [
              ?readAloudAction(context, _session, _agent('Hello there')),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Hello there'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('message-action-readAloud')),
      findsNothing,
    );
  });

  testWidgets('settings choose the service and keep its key secure', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const ReadAloudSettingsPage()));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('read_aloud_provider_system')),
      findsNothing,
    );
    expect(find.textContaining('Microsoft'), findsWidgets);
    expect(find.byKey(const ValueKey('read_aloud_api_key')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('read_aloud_provider_openAi')));
    await tester.pumpAndSettle();
    expect(controller.settings.provider, SpeechProvider.openAi);
    await tester.enterText(
      find.byKey(const ValueKey('read_aloud_api_key')),
      'sk-test',
    );
    await tester.tap(find.byKey(const ValueKey('read_aloud_api_key_save')));
    await tester.pumpAndSettle();
    expect(
      await keys.read(speechKeyScope(SpeechProvider.openAi, null)),
      'sk-test',
    );
    expect(
      backend.values.values.whereType<String>().any((v) => v.contains('sk-')),
      isFalse,
    );
    expect(find.text('A key is saved on this device'), findsOneWidget);
    // The test reads the phrase with the chosen service.
    await tester.tap(find.byKey(const ValueKey('read_aloud_test')));
    await tester.pumpAndSettle();
    expect(synth.requests.last.text, 'Hello! This is how messages will sound.');
    expect(synth.requests.last.apiKey, 'sk-test');
  });
  testWidgets('an address typed but not confirmed still counts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await keys.write(
      speechKeyScope(SpeechProvider.openAi, 'https://tts.example'),
      'sk-test',
    );
    await tester.pumpWidget(app(const ReadAloudSettingsPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('read_aloud_provider_openAi')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('read_aloud_base_url')),
      'https://tts.example',
    );
    // Test voice right away, with no Enter.
    await tester.tap(find.byKey(const ValueKey('read_aloud_test')));
    await tester.pumpAndSettle();
    expect(controller.settings.baseUrl, 'https://tts.example');
    expect(synth.requests.last.settings.baseUrl, 'https://tts.example');
    // While it reads, the button stops it.
    await tester.tap(find.byKey(const ValueKey('read_aloud_test_stop')));
    await tester.pumpAndSettle();
    expect(controller.active, isNull);
    // An address in the clear beyond the network is flagged once left.
    await tester.enterText(
      find.byKey(const ValueKey('read_aloud_base_url')),
      'http://tts.example',
    );
    await tester.tap(find.byKey(const ValueKey('read_aloud_model')));
    await tester.pumpAndSettle();
    expect(
      find.text('Use https for addresses outside this device or network'),
      findsOneWidget,
    );
  });

  testWidgets('leaving settings ends the voice test', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const ReadAloudSettingsPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('read_aloud_test')));
    await tester.pumpAndSettle();
    expect(controller.active, ReadAloudController.testKey);
    await tester.pumpWidget(app(const SizedBox()));
    await tester.pumpAndSettle();
    expect(controller.active, isNull);
  });
}
