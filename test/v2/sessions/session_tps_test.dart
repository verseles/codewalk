import 'package:codewalk/app/app_preferences_controller.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/app/workspace_chrome.dart';
import 'package:codewalk/features/sessions/session_live_scroll.dart';
import 'package:codewalk/features/sessions/session_live_timeline.dart';
import 'package:codewalk/features/sessions/session_message_info.dart';
import 'package:codewalk/features/sessions/session_timeline_tile.dart';
import 'package:codewalk/features/settings/appearance_settings_page.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/theme/app_theme.dart';
import 'package:codewalk/shared/theme/chat_appearance.dart';
import 'package:codewalk_core/codewalk_core.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../hosts/fakes.dart';
import '../storage/storage_fakes.dart';
import 'fakes.dart';
import 'history_fakes.dart';
import 'live_fakes.dart';
import 'workspace_support.dart';

const _host = HostId('host-1');
const _harness = HarnessInstanceId('inst-1');
const _session = SessionRef(_host, _harness, 'ses-tps');

DateTime _ms(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

MessageContext _step(
  String id, {
  int createdMs = 1000,
  int? firstTokenMs,
  int? streamedMs,
  int? completedMs,
  num? output,
  num? reasoning,
}) => MessageContext(
  message: MessageRef(id),
  created: _ms(createdMs),
  firstToken: firstTokenMs == null ? null : _ms(firstTokenMs),
  streamed: streamedMs == null ? null : _ms(streamedMs),
  completed: completedMs == null ? null : _ms(completedMs),
  tokens: output == null && reasoning == null
      ? null
      : TokenBreakdown(input: 100, output: output, reasoning: reasoning),
  finish: completedMs == null ? null : 'stop',
);

ItemMeta _meta(
  String id, {
  MessageContext? message,
  ItemStatus status = ItemStatus.completed,
}) => ItemMeta(
  id: ItemId('tps/$id'),
  generation: 'g1',
  status: OpenValue.known(status),
  source: SourceProvenance(
    harness: _session.harnessRef,
    version: '2.3.2',
    nativeType: 'assistant',
  ),
  message: message,
);

Widget _wrap(
  Widget child, {
  AppPreferencesController? preferences,
  bool showTokensPerSecond = false,
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) {
  Widget app = MaterialApp(
    theme: AppTheme.lightFrom(
      ColorScheme.fromSeed(seedColor: AppTheme.seedColor),
    ),
    localizationsDelegates: V2Localizations.localizationsDelegates,
    supportedLocales: V2Localizations.supportedLocales,
    locale: locale,
    builder: (context, inner) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: ChatAppearance(
        mathRendering: true,
        conversationTextScale: 1,
        showTokensPerSecond: showTokensPerSecond,
        child: inner ?? const SizedBox.shrink(),
      ),
    ),
    home: child,
  );
  if (preferences != null) {
    app = ChangeNotifierProvider<AppPreferencesController>.value(
      value: preferences,
      child: app,
    );
  }
  return app;
}

List<TimelineItem> _multiTurnItems() {
  // Turn 1: Reasoning + ToolCall open msg_1, followed by final AssistantText
  // in the SAME msg_1 (so AssistantText has messageHeader: false!).
  // 100 tokens / 2.0 s = 50.0 tok/s.
  final t1 = _step(
    'msg_1',
    createdMs: 1000,
    firstTokenMs: 1500,
    streamedMs: 3500,
    completedMs: 4000,
    output: 60,
    reasoning: 40,
  );
  // Turn 2: Direct AssistantText opening msg_2 (messageHeader: true).
  // 85 tokens / 2.0 s = 42.5 tok/s.
  final t2 = _step(
    'msg_2',
    createdMs: 10000,
    firstTokenMs: 10500,
    streamedMs: 12500,
    completedMs: 13000,
    output: 85,
  );
  // Turn 3: Missing streamed timestamp (must not show TPS).
  final t3 = _step('msg_3', createdMs: 20000, completedMs: 22000, output: 40);
  return <TimelineItem>[
    UserInput(
      meta: _meta('u1'),
      text: 'Turn 1 prompt',
      delivery: const OpenValue.known(DeliveryState.delivered),
      confirmed: true,
    ),
    Reasoning(
      meta: _meta('r1', message: t1),
      text: 'Thinking',
      complete: true,
    ),
    ToolCall(
      meta: _meta('tc1', message: t1),
      kind: const OpenValue.known(ToolKind.read),
      rawName: 'read',
    ),
    AssistantText(
      meta: _meta('a1', message: t1),
      text: 'Answer after reasoning',
      complete: true,
    ),
    UserInput(
      meta: _meta('u2'),
      text: 'Turn 2 prompt',
      delivery: const OpenValue.known(DeliveryState.delivered),
      confirmed: true,
    ),
    AssistantText(
      meta: _meta('a2', message: t2),
      text: 'Direct answer',
      complete: true,
    ),
    UserInput(
      meta: _meta('u3'),
      text: 'Turn 3 prompt',
      delivery: const OpenValue.known(DeliveryState.delivered),
      confirmed: true,
    ),
    AssistantText(
      meta: _meta('a3', message: t3),
      text: 'No streamed time',
      complete: true,
    ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Display menu toggles showTokensPerSecond (default OFF) and Appearance settings has no toggle',
    (tester) async {
      final prefs = AppPreferencesController(
        store: V2MetadataStore(backend: FakeMetadataBackend()),
      );
      addTearDown(prefs.dispose);
      await prefs.initialize();
      expect(prefs.showTokensPerSecond, isFalse);

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    key: const ValueKey('open-display'),
                    onPressed: () => showWorkspaceDisplayMenu(context),
                    child: const Text('Display'),
                  ),
                  const Expanded(child: AppearanceSettingsPage()),
                ],
              ),
            ),
          ),
          preferences: prefs,
        ),
      );
      await tester.pumpAndSettle();

      // Confirm AppearanceSettingsPage does NOT expose a TPS toggle.
      expect(find.text('Tokens per second'), findsNothing);
      expect(find.byKey(const ValueKey('display-toggle-tps')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('open-display')));
      await tester.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('display-toggle-tps'));
      expect(toggle, findsOneWidget);
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(prefs.showTokensPerSecond, isTrue);
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    },
  );

  testWidgets(
    'SessionLiveTimeline hides TPS when OFF and shows turn TPS on every completed turn when ON',
    (tester) async {
      tester.view.physicalSize = const Size(500, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final scroll = SessionLiveScroll();
      addTearDown(scroll.dispose);
      final items = _multiTurnItems();

      // Default OFF: no TPS chips rendered.
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: SessionLiveTimeline(
              items: items,
              scroll: scroll,
              settled: true,
              headerBuilder: (_) => const SizedBox.shrink(),
            ),
          ),
          showTokensPerSecond: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MessageTokensPerSecondChip), findsNothing);

      // Toggle ON: Turn 1 (messageHeader == false) and Turn 2 (alongside elapsed)
      // both show TPS chips; Turn 3 (missing streamed) does not.
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: SessionLiveTimeline(
              items: items,
              scroll: scroll,
              settled: true,
              headerBuilder: (_) => const SizedBox.shrink(),
            ),
          ),
          showTokensPerSecond: true,
        ),
      );
      await tester.pumpAndSettle();

      final chip1 = find.byKey(const ValueKey('message-tps-msg_1'));
      final chip2 = find.byKey(const ValueKey('message-tps-msg_2'));
      final chip3 = find.byKey(const ValueKey('message-tps-msg_3'));
      expect(chip1, findsOneWidget);
      expect(chip2, findsOneWidget);
      expect(chip3, findsNothing);

      expect(
        find.descendant(of: chip1, matching: find.text('50.0 tok/s')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: chip2, matching: find.text('42.5 tok/s')),
        findsOneWidget,
      );
      // Turn 2 also keeps its elapsed chip beside TPS.
      expect(
        find.byKey(const ValueKey('message-elapsed-msg_2')),
        findsOneWidget,
      );
      // Hit target meets 48x48 minimum.
      final box = tester.getSize(chip2);
      expect(box.width, greaterThanOrEqualTo(48));
      expect(box.height, greaterThanOrEqualTo(48));

      // Tapping TPS chip opens Message Info with Speed row.
      await tester.tap(chip2);
      await tester.pumpAndSettle();
      expect(find.text('Message Info'), findsOneWidget);
      expect(find.text('Speed: 42.5 tok/s'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('message-info-close')));
      await tester.pumpAndSettle();

      // Tapping elapsed chip also shows the same Speed row.
      await tester.tap(find.byKey(const ValueKey('message-elapsed-msg_2')));
      await tester.pumpAndSettle();
      expect(find.text('Speed: 42.5 tok/s'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('message-info-close')));
      await tester.pumpAndSettle();

      // While the session runs, the trailing turn is not whole yet: its
      // finished step shows no rate, earlier turns keep theirs.
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: SessionLiveTimeline(
              items: items.sublist(0, 6),
              scroll: scroll,
              settled: false,
              headerBuilder: (_) => const SizedBox.shrink(),
            ),
          ),
          showTokensPerSecond: true,
        ),
      );
      await tester.pump();
      expect(chip1, findsOneWidget);
      expect(chip2, findsNothing);
    },
  );

  testWidgets('SessionHistoryPage shows turn TPS when Display toggle is ON', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final rig = CatalogRig();
    await rig.save('a');
    final sources = <HistorySource>[];
    final dependencies = createAppDependencies(
      initialLink: Uri(path: '/sessions'),
      profileRepository: rig.repository,
      endpointProber: FakeProber(),
      sessionCatalogFactory: rig.create,
      sessionLiveDirectory: LiveDirectory.new,
      sessionHistoryFactory: (p, c, ref) {
        final source = HistorySource(ref);
        sources.add(source);
        return source;
      },
    );
    addTearDown(dependencies.dispose);
    dependencies.preferences.setShowTokensPerSecond(true);

    await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: dependencies));
    await showSessionList(tester);
    final read = dependencies.sessions!.selectProfile('profile_a');
    final catalog = rig.sources.single;
    final row = catalog.row('one', title: 'History TPS');
    catalog.respond([row]);
    await read;
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(ValueKey('live-open-${row.info.ref.storageKey}')),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(
      ValueKey('history-open-${row.info.ref.storageKey}'),
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    final source = sources.single;
    final stepCtx = _step(
      'msg_hist',
      createdMs: 1000,
      firstTokenMs: 1500,
      streamedMs: 3500,
      completedMs: 4000,
      output: 120,
    );
    ItemMeta historyMeta(int id, {MessageContext? message}) => ItemMeta(
      id: ItemId('${source.session.storageKey}/$id'),
      generation: 'history',
      status: const OpenValue.known(ItemStatus.completed),
      source: SourceProvenance(
        harness: source.session.harnessRef,
        version: '2.0.22',
        nativeType: 'assistant',
      ),
      message: message,
    );
    source.respond([
      UserInput(
        meta: historyMeta(1),
        text: 'History prompt',
        delivery: const OpenValue.known(DeliveryState.delivered),
        confirmed: true,
      ),
      Reasoning(
        meta: historyMeta(2, message: stepCtx),
        text: 'History reasoning',
        complete: true,
      ),
      AssistantText(
        meta: historyMeta(3, message: stepCtx),
        text: 'History answer',
        complete: true,
      ),
    ]);
    await tester.pumpAndSettle();

    final chip = find.byKey(const ValueKey('message-tps-msg_hist'));
    expect(chip, findsOneWidget);
    expect(
      find.descendant(of: chip, matching: find.text('60.0 tok/s')),
      findsOneWidget,
    );
  });

  testWidgets(
    'formats decimal per locale (pt), handles RTL (ar), and avoids overflow on 320px at 200% text scale',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final ctx = _step(
        'msg_locale',
        createdMs: 1000,
        firstTokenMs: 1500,
        streamedMs: 3500,
        completedMs: 5000,
        output: 85,
      );

      for (final (locale, expected) in [
        (const Locale('pt'), '42,5 tok/s'),
        (const Locale('ar'), 'tok/s'),
      ]) {
        await tester.pumpWidget(
          _wrap(
            Scaffold(
              body: SingleChildScrollView(
                child: SessionTimelineTile(
                  item: AssistantText(
                    meta: _meta('a_loc', message: ctx),
                    text: 'Answer text',
                    complete: true,
                  ),
                  messageHeader: true,
                  turnTokensPerSecond: 42.5,
                ),
              ),
            ),
            showTokensPerSecond: true,
            locale: locale,
            textScale: 2.0,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'locale=$locale');
        expect(
          find.textContaining(expected),
          findsOneWidget,
          reason: 'locale=$locale',
        );
      }
    },
  );
}
