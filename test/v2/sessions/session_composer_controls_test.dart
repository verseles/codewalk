import 'package:codewalk/features/sessions/session_composer_controls.dart';
import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/platform/sessions/permission_mode_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/permission_mode.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_selection.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';

final _alpha = ModelEntry(
  id: 'alpha',
  providerId: 'prov',
  label: 'Alpha',
  variants: ['low', 'high'],
);
final _build = CatalogEntry(
  id: 'build',
  kind: const OpenValue.known(CatalogKind.agent),
  label: 'Build',
);
final _plan = CatalogEntry(
  id: 'plan',
  kind: const OpenValue.known(CatalogKind.agent),
  label: 'Plan',
);

InteractionRequest _permission(SessionRef ref, String id) => InteractionRequest(
  id: InteractionId(id),
  owner: SessionOwner(ref),
  kind: const OpenValue.known(InteractionKind.permission),
  title: 'Run a command',
  autoApprovable: false,
  choices: [
    ApprovalChoice(
      id: 'once',
      label: 'Allow once',
      allows: true,
      scope: const OpenValue.known(ApprovalScope.once),
      resolutionScope: const OpenValue.known(ResolutionScope.request),
    ),
  ],
);

void main() {
  late CatalogRig rig;
  late LiveDirectory directory;
  late PermissionModeStore policy;

  setUp(() async {
    rig = CatalogRig();
    await rig.save('a');
    await rig.sessions.initialize();
    directory = LiveDirectory();
    policy = PermissionModeStore(
      store: V2MetadataStore(backend: FakeMetadataBackend()),
    );
    await policy.initialize();
  });

  tearDown(() {
    policy.dispose();
    rig.dispose();
  });

  /// A live session showing [selection], with [permissions] waiting, under
  /// the composer's controls.
  Future<(SessionLiveController, LiveHandle)> open(
    WidgetTester tester, {
    String id = 'one',
    String? parent,
    int permissions = 0,
    Size size = const Size(800, 900),
    double keyboard = 0,
    bool nestedNavigator = false,
    Alignment alignment = Alignment.bottomCenter,
    Locale locale = const Locale('en'),
    double textScale = 1,
  }) async {
    final source = CatalogSource(profile('a'));
    final summary = source.row(id, parent: parent);
    final ref = summary.info.ref;
    final live = SessionLiveController(
      hosts: rig.hosts,
      profile: profile('a'),
      summary: summary,
      directory: directory,
      permissionModes: policy,
    );
    addTearDown(live.dispose);
    final opening = live.start();
    final handle = directory.grant(ref)
      ..selectionAvailable = true
      ..selectionState = SessionSelectionState(
        selection: const Selection(
          modelId: 'alpha',
          modelProviderId: 'prov',
          modelVariant: 'high',
          agentId: 'build',
        ),
        models: [_alpha],
        agents: [_build, _plan],
      );
    await opening;
    handle.emit(
      SessionLiveView(
        session: ref,
        phase: SessionLivePhase.live,
        state: liveState(
          ref,
          interactions: [
            for (var i = 0; i < permissions; i++) _permission(ref, 'p$i'),
          ],
        ),
      ),
    );
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);
    final controls = Align(
      alignment: alignment,
      child: SessionComposerControls(live: live),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: V2Localizations.localizationsDelegates,
        supportedLocales: V2Localizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: nestedNavigator
              ? Row(
                  children: [
                    const SizedBox(width: 260),
                    Expanded(
                      child: Navigator(
                        onGenerateRoute: (_) =>
                            MaterialPageRoute<void>(builder: (_) => controls),
                      ),
                    ),
                  ],
                )
              : controls,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (live, handle);
  }

  Finder chip(String key, String text) =>
      find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text));

  testWidgets('the agent, model and variant chips show the selection', (
    tester,
  ) async {
    await open(tester, permissions: 2);
    expect(chip('live-agent-chip', 'Build'), findsOneWidget);
    expect(chip('live-model-chip', 'Alpha'), findsOneWidget);
    expect(chip('live-variant-chip', 'high'), findsOneWidget);
    // The permissions waiting for the user are counted on the agent chip.
    final badge = tester.widget<Badge>(
      find.byKey(const ValueKey('live-agent-badge')),
    );
    expect(badge.isLabelVisible, isTrue);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('live-agent-badge')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the agent menu picks an agent over an auto-approve footer', (
    tester,
  ) async {
    final (live, handle) = await open(tester);
    final l10n = V2Localizations.of(
      tester.element(find.byType(SessionComposerControls)),
    );
    await tester.tap(find.byKey(const ValueKey('live-agent-chip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('live-agent-menu')), findsOneWidget);
    expect(find.byKey(const ValueKey('live-agent-menu-plan')), findsOneWidget);
    // The footer starts on the acknowledged default (auto-approve), turns
    // it off for this session and keeps the menu open.
    final footer = find.byKey(const ValueKey('live-auto-approve'));
    expect(tester.widget<SwitchListTile>(footer).value, isTrue);
    expect(find.text(l10n.chatPermissionAutoApproveOn), findsOneWidget);
    await tester.tap(footer);
    await tester.pumpAndSettle();
    expect(live.permissionModeState.mode, PermissionMode.ask);
    expect(tester.widget<SwitchListTile>(footer).value, isFalse);
    expect(find.text(l10n.chatPermissionAutoApproveOff), findsOneWidget);
    expect(find.byKey(const ValueKey('live-agent-menu')), findsOneWidget);
    await tester.tap(footer);
    await tester.pumpAndSettle();
    expect(live.permissionModeState.mode, PermissionMode.allowAll);
    // Picking an agent sends one switch and closes the menu.
    await tester.tap(find.byKey(const ValueKey('live-agent-menu-plan')));
    await tester.pumpAndSettle();
    expect(handle.selectionCalls, contains('agent:plan'));
    expect(find.byKey(const ValueKey('live-agent-menu')), findsNothing);
  });

  testWidgets('the variant menu picks a variant or the default', (
    tester,
  ) async {
    final (_, handle) = await open(tester);
    await tester.tap(find.byKey(const ValueKey('live-variant-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('live-variant-low')));
    await tester.pumpAndSettle();
    expect(handle.selectionCalls, contains('model:prov/alpha:low'));
    await tester.tap(find.byKey(const ValueKey('live-variant-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('live-variant-default')));
    await tester.pumpAndSettle();
    expect(handle.selectionCalls, contains('model:prov/alpha'));
  });

  testWidgets('a sub-conversation keeps its parent\'s choice', (tester) async {
    await open(tester, id: 'child', parent: 'one');
    expect(find.byKey(const ValueKey('live-agent-chip')), findsNothing);
    expect(
      tester
          .widget<ActionChip>(find.byKey(const ValueKey('live-model-chip')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<ActionChip>(find.byKey(const ValueKey('live-variant-chip')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('the agent menu shares root coordinates above an inset shell', (
    tester,
  ) async {
    await open(tester, nestedNavigator: true, keyboard: 300);
    final anchor = tester.getRect(
      find.byKey(const ValueKey('live-agent-chip')),
    );
    await tester.tap(find.byKey(const ValueKey('live-agent-chip')));
    await tester.pumpAndSettle();
    final menu = tester.getRect(find.byKey(const ValueKey('live-agent-menu')));
    expect(menu.left, closeTo(anchor.left, 1));
    expect(menu.bottom, closeTo(anchor.top - 4, 1));
    expect(menu.top, greaterThanOrEqualTo(8));
    expect(menu.bottom, lessThanOrEqualTo(600));
    await tester.tap(find.byKey(const ValueKey('live-agent-menu-plan')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a short keyboard viewport keeps agents and footer reachable', (
    tester,
  ) async {
    final (_, handle) = await open(
      tester,
      size: const Size(800, 240),
      keyboard: 100,
    );
    await tester.tap(find.byKey(const ValueKey('live-agent-chip')));
    await tester.pumpAndSettle();
    final menu = tester.getRect(find.byKey(const ValueKey('live-agent-menu')));
    expect(menu.top, greaterThanOrEqualTo(8));
    expect(menu.bottom, lessThanOrEqualTo(132));
    final footer = find.byKey(const ValueKey('live-auto-approve'));
    await tester.tap(footer);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(footer).value, isFalse);
    final plan = find.byKey(const ValueKey('live-agent-menu-plan'));
    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('live-agent-menu')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(plan, 48, scrollable: scrollable);
    await tester.pumpAndSettle();
    // The list may show less than one whole tile above its fixed footer.
    final visible = tester.getRect(plan).intersect(tester.getRect(scrollable));
    expect(visible.height, greaterThan(0));
    await tester.tapAt(visible.center);
    await tester.pumpAndSettle();
    expect(handle.selectionCalls, contains('agent:plan'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the agent menu opens below a chip near the top', (tester) async {
    await open(tester, alignment: Alignment.topCenter);
    final anchor = tester.getRect(
      find.byKey(const ValueKey('live-agent-chip')),
    );
    await tester.tap(find.byKey(const ValueKey('live-agent-chip')));
    await tester.pumpAndSettle();
    final menu = tester.getRect(find.byKey(const ValueKey('live-agent-menu')));
    expect(menu.top, closeTo(anchor.bottom + 4, 1));
    expect(menu.bottom, lessThanOrEqualTo(892));
    expect(tester.takeException(), isNull);
  });

  for (final (size, keyboard, locale) in [
    (const Size(390, 844), 350.0, const Locale('ar')),
    (const Size(800, 360), 140.0, const Locale('en')),
  ]) {
    testWidgets('menu stays usable at 2x text: $size/$locale', (tester) async {
      await open(
        tester,
        size: size,
        keyboard: keyboard,
        locale: locale,
        textScale: 2,
      );
      await tester.tap(find.byKey(const ValueKey('live-agent-chip')));
      await tester.pumpAndSettle();
      final menu = tester.getRect(
        find.byKey(const ValueKey('live-agent-menu')),
      );
      expect(menu.top, greaterThanOrEqualTo(8));
      expect(menu.bottom, lessThanOrEqualTo(size.height - keyboard - 8));
      expect(menu.left, greaterThanOrEqualTo(8));
      expect(menu.right, lessThanOrEqualTo(size.width - 8));
      final footer = find.byKey(const ValueKey('live-auto-approve'));
      await tester.tap(footer);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(footer).value, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the model chip retains selection status in its semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final (_, handle) = await open(tester);
    final l10n = V2Localizations.of(
      tester.element(find.byType(SessionComposerControls)),
    );
    final initial = handle.selectionState;
    for (final (phase, notice, expected) in [
      (
        SessionSelectionPhase.pending,
        SessionSelectionNotice.none,
        l10n.liveSelectionPending,
      ),
      (
        SessionSelectionPhase.unconfirmed,
        SessionSelectionNotice.none,
        l10n.liveSelectionUnconfirmed,
      ),
      (
        initial.phase,
        SessionSelectionNotice.changedElsewhere,
        l10n.liveSelectionChangedElsewhere,
      ),
    ]) {
      handle.selectionState = SessionSelectionState(
        selection: initial.selection,
        models: initial.models,
        agents: initial.agents,
        phase: phase,
        notice: notice,
      );
      handle.emit(handle.current);
      // The fake broadcasts asynchronously; deliver the update before the
      // frame that rebuilds the chips (pending has a repeating spinner).
      await tester.pump();
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(expected))),
        findsOneWidget,
      );
      final tooltip = tester.widget<Tooltip>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('live-model-chip')),
              matching: find.byType(Tooltip),
            )
            .first,
      );
      expect(tooltip.message, contains(expected));
      expect(tooltip.message, contains('Alpha#high'));
    }
    semantics.dispose();
  });

  testWidgets('an unreadable permission policy is unavailable, not off', (
    tester,
  ) async {
    policy.dispose();
    policy = PermissionModeStore(
      store: V2MetadataStore(backend: FakeMetadataBackend()..failRead = true),
    );
    await policy.initialize();
    await open(tester);
    final l10n = V2Localizations.of(
      tester.element(find.byType(SessionComposerControls)),
    );
    await tester.tap(find.byKey(const ValueKey('live-agent-chip')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.livePermissionModeUnavailable), findsOneWidget);
    expect(find.text(l10n.chatPermissionAutoApproveOff), findsNothing);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('live-auto-approve')),
          )
          .onChanged,
      isNull,
    );
  });
}
