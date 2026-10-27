@TestOn('vm')
library;

import 'package:codewalk/app/app_keyboard_shortcuts.dart';
import 'package:codewalk/app/app_preferences_controller.dart';
import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/features/sessions/session_live_page.dart';
import 'package:codewalk/features/sessions/session_selection_cycle.dart';
import 'package:codewalk/platform/sessions/model_preference_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_selection.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';
import 'composer_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';

final _alpha = ModelEntry(
  id: 'alpha',
  providerId: 'prov',
  label: 'Alpha',
  variants: ['low', 'high'],
);
final _beta = ModelEntry(
  id: 'beta',
  providerId: 'prov',
  label: 'Beta',
  variants: ['high'],
);
final _gamma = ModelEntry(id: 'gamma', providerId: 'other', label: 'Gamma');
CatalogEntry _agent(String id) => CatalogEntry(
  id: id,
  kind: const OpenValue.known(CatalogKind.agent),
  label: id,
);
const _project = '/work/app';
final _server = profile('a').id;

void main() {
  group('the Alt+Tab cycle', () {
    late DateTime now;
    late SelectionCycle cycle;
    setUp(() {
      now = DateTime.utc(2026, 10, 27);
      cycle = SelectionCycle(now: () => now);
    });

    String? press(
      String? current, {
      List<String> candidates = const ['a', 'b', 'c', 'd'],
      List<String> history = const [],
      bool reverse = false,
      SelectionCycleDomain domain = SelectionCycleDomain.model,
    }) {
      final next = cycle.next(
        domain,
        current: current,
        candidates: candidates,
        history: history,
        reverse: reverse,
      );
      now = now.add(const Duration(seconds: 1));
      return next;
    }

    test('the first press goes back to the item used before', () {
      expect(press('b', history: ['b', 'a']), 'a');
    });

    test('quick presses go on past two, most recent first', () {
      var current = 'b';
      final seen = [
        for (var i = 0; i < 4; i++)
          current = press(current, history: ['b', 'a', 'd'])!,
      ];
      expect(seen, ['a', 'd', 'c', 'b']);
    });

    test('a pause longer than three seconds starts over', () {
      expect(press('b', history: ['b', 'a']), 'a');
      // Within the window the burst goes on to the third item.
      final within = SelectionCycle(now: () => now)
        ..next(
          SelectionCycleDomain.model,
          current: 'b',
          candidates: const ['a', 'b', 'c', 'd'],
          history: const ['b', 'a'],
        );
      expect(
        within.next(
          SelectionCycleDomain.model,
          current: 'a',
          candidates: const ['a', 'b', 'c', 'd'],
          history: const ['a', 'b'],
        ),
        'c',
      );
      now = now.add(const Duration(seconds: 3));
      expect(press('a', history: ['a', 'b']), 'b');
    });

    test('without two remembered items it steps through in order', () {
      expect(press('b'), 'c');
      expect(press('c'), 'd');
      expect(press('d'), 'a');
      final back = SelectionCycle(now: () => now);
      expect(
        back.next(
          SelectionCycleDomain.agent,
          current: 'b',
          candidates: const ['a', 'b', 'c'],
          history: const [],
          reverse: true,
        ),
        'a',
      );
    });

    test('one or no candidate', () {
      expect(press('a', candidates: ['a']), isNull);
      expect(press('x', candidates: ['a']), 'a');
      expect(press('a', candidates: []), isNull);
      expect(press(null), 'a');
    });

    test('each domain keeps its own burst', () {
      expect(press('b', history: ['b', 'a']), 'a');
      expect(
        press(
          'y',
          candidates: ['x', 'y', 'z'],
          history: ['y', 'z'],
          domain: SelectionCycleDomain.agent,
        ),
        'z',
      );
      expect(press('a', history: ['a', 'b']), 'c');
    });

    test('an item gone during a burst is skipped', () {
      expect(press('b', history: ['b', 'a', 'd']), 'a');
      expect(press('a', candidates: ['a', 'b', 'c']), 'c');
    });
  });

  group('the session controller', () {
    late CatalogRig rig;
    late LiveDirectory directory;
    late ModelPreferenceStore preferences;
    late DateTime now;

    setUp(() async {
      rig = CatalogRig();
      await rig.save('a');
      await rig.sessions.initialize();
      directory = LiveDirectory();
      preferences = ModelPreferenceStore(
        store: V2MetadataStore(backend: FakeMetadataBackend()),
      );
      await preferences.initialize();
      now = DateTime.utc(2026, 10, 27);
    });

    tearDown(() {
      preferences.dispose();
      rig.dispose();
    });

    /// A live session on Alpha with Build whose server takes every switch;
    /// [onAgent] decides the selection an agent switch leaves.
    Future<(SessionLiveController, LiveHandle)> open({
      List<ModelEntry>? models,
      Selection Function(Selection current, String agent)? onAgent,
      bool composer = false,
    }) async {
      final offered = models ?? [_alpha, _beta, _gamma];
      final agents = [_agent('build'), _agent('plan'), _agent('docs')];
      final summary = CatalogSource(
        profile('a'),
      ).row('one', directory: _project);
      final live = SessionLiveController(
        hosts: rig.hosts,
        profile: profile('a'),
        summary: summary,
        directory: directory,
        modelPreferences: preferences,
        now: () => now,
      );
      addTearDown(live.dispose);
      final opening = live.start();
      final handle =
          directory.grant(
              summary.info.ref,
              outbox: composer ? FakeOutbox() : null,
            )
            ..selectionAvailable = true
            ..selectionState = SessionSelectionState(
              selection: const Selection(
                modelId: 'alpha',
                modelProviderId: 'prov',
                agentId: 'build',
              ),
              models: offered,
              agents: agents,
            );
      await opening;
      handle
        ..emit(
          SessionLiveView(
            session: summary.info.ref,
            phase: SessionLivePhase.live,
            state: liveState(summary.info.ref),
          ),
        )
        ..selectionAction = (change) async {
          final current = handle.selectionState.selection!;
          final Selection next;
          if (change.startsWith('model:')) {
            final [ref, ...variant] = change.substring(6).split(':');
            final [provider, model] = ref.split('/');
            next = Selection(
              modelId: model,
              modelProviderId: provider,
              modelVariant: variant.firstOrNull,
              agentId: current.agentId,
            );
          } else if (change.startsWith('agent:')) {
            final agent = change.substring(6);
            next =
                onAgent?.call(current, agent) ??
                Selection(
                  modelId: current.modelId,
                  modelProviderId: current.modelProviderId,
                  modelVariant: current.modelVariant,
                  agentId: agent,
                );
          } else {
            return handle.selectionState;
          }
          return SessionSelectionState(
            selection: next,
            models: offered,
            agents: agents,
          );
        };
      await pumpEventQueue();
      return (live, handle);
    }

    List<String> switches(LiveHandle handle) =>
        handle.selectionCalls.where((c) => c != 'refresh').toList();

    test('a model switch remembers the one before it', () async {
      final (live, _) = await open();
      await live.selectModel(_beta);
      expect(preferences.recents(_server, _project), [
        'prov/beta',
        'prov/alpha',
      ]);
    });

    test('mod+m goes back, then on through favorites and recents', () async {
      final (live, handle) = await open();
      await preferences.setFavorite(_server, 'other/gamma', favorite: true);
      await live.selectModel(_beta);
      handle.selectionCalls.clear();
      for (var i = 0; i < 3; i++) {
        await live.cycleModel();
        now = now.add(const Duration(seconds: 1));
      }
      expect(switches(handle), [
        'model:prov/alpha',
        'model:other/gamma',
        'model:prov/beta',
      ]);
      // After a pause the first press goes back to the previous model.
      now = now.add(const Duration(seconds: 4));
      await live.cycleModel();
      expect(switches(handle).last, 'model:other/gamma');
    });

    test('mod+t cycles the variants, Auto among them', () async {
      final (live, handle) = await open();
      await live.cycleVariant();
      now = now.add(const Duration(seconds: 1));
      await live.cycleVariant();
      expect(switches(handle), [
        'model:prov/alpha:low',
        'model:prov/alpha:high',
      ]);
      expect(preferences.variantRecents(_server, _project, 'prov/alpha'), [
        'high',
        'low',
        ModelPreferenceStore.autoVariant,
      ]);
      now = now.add(const Duration(seconds: 4));
      await live.cycleVariant();
      expect(switches(handle).last, 'model:prov/alpha:low');
      // The variant goes back to Auto, which clears it.
      now = now.add(const Duration(seconds: 1));
      await live.cycleVariant();
      expect(switches(handle).last, 'model:prov/alpha');
    });

    test('alt+shift+j and k cycle the agents', () async {
      final (live, handle) = await open();
      await live.cycleAgent();
      expect(switches(handle), ['agent:plan']);
      now = now.add(const Duration(seconds: 4));
      await live.cycleAgent(reverse: true);
      expect(switches(handle).last, 'agent:build');
      expect(preferences.agentRecents(_server, _project), ['build', 'plan']);
    });

    test('switching back to an agent restores its model and variant', () async {
      final (live, handle) = await open();
      await live.selectModel(_beta, variant: 'high');
      await live.selectAgent(_agent('plan'));
      // Plan has no model of its own yet: nothing is restored.
      expect(switches(handle), ['model:prov/beta:high', 'agent:plan']);
      await live.selectModel(_gamma);
      await live.selectAgent(_agent('build'));
      expect(switches(handle).skip(3), ['agent:build', 'model:prov/beta:high']);
      await live.selectAgent(_agent('plan'));
      expect(switches(handle).last, 'model:other/gamma');
    });

    test('an agent left keeps the model it was using', () async {
      final (live, handle) = await open();
      await live.selectAgent(_agent('plan'));
      await live.selectModel(_gamma);
      await live.selectAgent(_agent('build'));
      // Build was on Alpha, which it never picked here.
      expect(switches(handle).last, 'model:prov/alpha');
    });

    test('a variant the model no longer lists is not restored', () async {
      await preferences.rememberAgentModel(
        _server,
        _project,
        'plan',
        'prov/beta',
        'max',
      );
      final (live, handle) = await open();
      await live.selectAgent(_agent('plan'));
      expect(switches(handle), ['agent:plan', 'model:prov/beta']);
    });

    test('a model the server set with the agent wins', () async {
      await preferences.rememberAgentModel(
        _server,
        _project,
        'plan',
        'prov/beta',
        null,
      );
      final (live, handle) = await open(
        onAgent: (current, agent) => Selection(
          modelId: 'gamma',
          modelProviderId: 'other',
          agentId: agent,
        ),
      );
      await live.selectAgent(_agent('plan'));
      expect(switches(handle), ['agent:plan']);
    });

    test('a model the location does not offer is not restored', () async {
      await preferences.rememberAgentModel(
        _server,
        _project,
        'plan',
        'gone/model',
        null,
      );
      final (live, handle) = await open();
      await live.selectAgent(_agent('plan'));
      expect(switches(handle), ['agent:plan']);
    });

    test('a refused agent switch restores nothing', () async {
      await preferences.rememberAgentModel(
        _server,
        _project,
        'plan',
        'prov/beta',
        null,
      );
      final (live, handle) = await open();
      handle.selectionAction = (change) async => SessionSelectionState(
        selection: handle.selectionState.selection,
        models: handle.selectionState.models,
        agents: handle.selectionState.agents,
        notice: SessionSelectionNotice.refused,
      );
      await live.selectAgent(_agent('plan'));
      expect(switches(handle), ['agent:plan']);
      expect(preferences.agentRecents(_server, _project), isEmpty);
    });

    test('the restore waits for the server to report the agent', () async {
      await preferences.rememberAgentModel(
        _server,
        _project,
        'plan',
        'prov/beta',
        null,
      );
      final (live, handle) = await open();
      final serve = handle.selectionAction!;
      // The answer arrives before session.agent.selected: the next pick
      // waits for that report, as the selection lane does.
      handle.selectionAction = (change) async {
        final next = await serve(change);
        if (change.startsWith('agent:')) handle.awaitingEcho = true;
        return next;
      };
      await live.selectAgent(_agent('plan'));
      expect(switches(handle), ['agent:plan']);
      handle
        ..awaitingEcho = false
        ..emit(handle.current);
      await pumpEventQueue();
      expect(switches(handle), ['agent:plan', 'model:prov/beta']);
    });

    test('a new lease drops a restore still waiting', () async {
      await preferences.rememberAgentModel(
        _server,
        _project,
        'plan',
        'prov/beta',
        null,
      );
      final (live, handle) = await open();
      final serve = handle.selectionAction!;
      handle.selectionAction = (change) async {
        final next = await serve(change);
        if (change.startsWith('agent:')) handle.awaitingEcho = true;
        return next;
      };
      await live.selectAgent(_agent('plan'));
      handle.emit(
        SessionLiveView(
          session: live.session,
          phase: SessionLivePhase.degraded,
        ),
      );
      await pumpEventQueue();
      final retry = live.retry();
      final next = directory.grant(live.session)
        ..selectionAvailable = true
        ..selectionState = SessionSelectionState(
          selection: handle.selectionState.selection,
          models: handle.selectionState.models,
          agents: handle.selectionState.agents,
        );
      await retry;
      next.emit(
        SessionLiveView(
          session: live.session,
          phase: SessionLivePhase.live,
          state: liveState(live.session),
        ),
      );
      await pumpEventQueue();
      expect(next.selectionCalls.where((c) => c != 'refresh'), isEmpty);
      expect(switches(handle), ['agent:plan']);
    });

    test('a model set and set back during the switch still wins', () async {
      await preferences.rememberAgentModel(
        _server,
        _project,
        'plan',
        'prov/beta',
        null,
      );
      final (live, handle) = await open();
      final serve = handle.selectionAction!;
      SessionSelectionState withModel(String id, String provider) =>
          SessionSelectionState(
            selection: Selection(
              modelId: id,
              modelProviderId: provider,
              agentId: 'build',
            ),
            models: handle.selectionState.models,
            agents: handle.selectionState.agents,
          );
      handle.selectionAction = (change) async {
        if (change.startsWith('agent:')) {
          // Another client sets Gamma, then Alpha again, meanwhile.
          handle
            ..selectionState = withModel('gamma', 'other')
            ..emit(handle.current);
          await pumpEventQueue();
          handle
            ..selectionState = withModel('alpha', 'prov')
            ..emit(handle.current);
          await pumpEventQueue();
        }
        return serve(change);
      };
      await live.selectAgent(_agent('plan'));
      await pumpEventQueue();
      expect(switches(handle), ['agent:plan']);
    });

    testWidgets('the shortcut reaches the session from its composer', (
      tester,
    ) async {
      late (SessionLiveController, LiveHandle) opened;
      await tester.runAsync(() async => opened = await open(composer: true));
      final (live, handle) = opened;
      final settings = AppPreferencesController();
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: V2Localizations.localizationsDelegates,
          supportedLocales: V2Localizations.supportedLocales,
          home: AppKeyboardShortcuts(
            preferences: settings,
            openSettings: () {},
            child: SessionLivePage(controller: live),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(switches(handle), ['model:prov/beta']);
    });
  });
}
