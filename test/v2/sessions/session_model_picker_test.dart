@TestOn('vm')
library;

import 'dart:async';

import 'package:codewalk/features/sessions/session_composer_controls.dart';
import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/features/sessions/session_selection_chip.dart';
import 'package:codewalk/platform/sessions/model_preference_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_selection.dart';
import 'package:codewalk_core/codewalk_core.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../storage/storage_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';

ModelCost _price(double value) =>
    ModelCost(input: value, output: value, cacheRead: value, cacheWrite: value);

final _alpha = ModelEntry(
  id: 'alpha',
  providerId: 'prov',
  label: 'Alpha',
  variants: ['low', 'high'],
  cost: [_price(3)],
);
final _beta = ModelEntry(id: 'beta', providerId: 'prov', label: 'Beta');
final _zen = ModelEntry(
  id: 'zen',
  providerId: 'opencode',
  label: 'Zen',
  cost: [_price(0)],
);
final _gamma = ModelEntry(id: 'gamma', providerId: 'other', label: 'Gamma');
const _project = '/work/app';
final _server = profile('a').id;

Selection _selection(ModelEntry model, [String? variant]) => Selection(
  modelId: model.id,
  modelProviderId: model.providerId,
  modelVariant: variant,
  agentId: 'build',
);

void main() {
  late CatalogRig rig;
  late LiveDirectory directory;
  late FakeMetadataBackend backend;
  late ModelPreferenceStore preferences;
  final l10n = lookupV2Localizations(const Locale('en'));

  setUp(() async {
    rig = CatalogRig();
    await rig.save('a');
    await rig.sessions.initialize();
    directory = LiveDirectory();
    backend = FakeMetadataBackend();
  });

  tearDown(() => rig.dispose());

  /// Saved favorites and recents, then the composer of a session in
  /// [_project] showing Alpha#high.
  Future<(SessionLiveController, LiveHandle)> open(
    WidgetTester tester, {
    List<String> favorites = const [],
    List<String> recents = const [],
    Size size = const Size(800, 900),
    Locale locale = const Locale('en'),
    ThemeData? theme,
    SessionSelectionState? state,
  }) async {
    final seed = ModelPreferenceStore(store: V2MetadataStore(backend: backend));
    await seed.initialize();
    for (final model in favorites) {
      await seed.setFavorite(_server, model, favorite: true);
    }
    for (final model in recents.reversed) {
      await seed.recordRecent(_server, _project, model);
    }
    seed.dispose();
    preferences = ModelPreferenceStore(
      store: V2MetadataStore(backend: backend),
    );
    addTearDown(preferences.dispose);
    await preferences.initialize();
    final summary = CatalogSource(profile('a')).row('one', directory: _project);
    final ref = summary.info.ref;
    final live = SessionLiveController(
      hosts: rig.hosts,
      profile: profile('a'),
      summary: summary,
      directory: directory,
      modelPreferences: preferences,
    );
    addTearDown(live.dispose);
    final opening = live.start();
    final handle = directory.grant(ref)
      ..selectionAvailable = true
      ..selectionState =
          state ??
          SessionSelectionState(
            selection: _selection(_alpha, 'high'),
            models: [_alpha, _beta, _zen, _gamma],
          );
    await opening;
    handle.emit(
      SessionLiveView(
        session: ref,
        phase: SessionLivePhase.live,
        state: liveState(ref),
      ),
    );
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        theme: theme,
        localizationsDelegates: V2Localizations.localizationsDelegates,
        supportedLocales: V2Localizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SessionModelChip(live: live),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (live, handle);
  }

  /// Opens the one pick, as the chip, `/model` and `/agent` do (#485).
  Future<void> openPicker(WidgetTester tester) async {
    final chip = find.byKey(const ValueKey('live-model-chip'));
    final live = tester.widget<SessionModelChip>(find.byType(SessionModelChip));
    unawaited(showSessionSelection(tester.element(chip), live.live));
    await tester.pumpAndSettle();
  }

  Finder row(String key) => find.byKey(ValueKey('live-selection-$key'));

  /// The model switches sent, without the reads made on open.
  List<String> switches(LiveHandle handle) =>
      handle.selectionCalls.where((call) => call != 'refresh').toList();

  testWidgets('favorites, then recents, then every model by provider', (
    tester,
  ) async {
    await open(
      tester,
      favorites: ['opencode/zen', 'gone/model'],
      recents: ['other/gamma', 'opencode/zen', 'gone/recent'],
    );
    await openPicker(tester);
    // One pick (#485): the models first, the agents in the footer below; no
    // title takes their room (beta.21), though the panel names its route.
    expect(find.text(l10n.liveSelection), findsNothing);
    expect(find.bySemanticsLabel(l10n.liveSelection), findsOneWidget);
    expect(find.text(l10n.liveSelectionAgent), findsOneWidget);
    expect(
      tester.getTopLeft(row('favorite-opencode/zen')).dy,
      lessThan(tester.getTopLeft(find.text(l10n.liveSelectionAgent)).dy),
    );
    expect(row('favorite-opencode/zen'), findsOneWidget);
    // A saved name the location does not offer is not shown.
    expect(row('favorite-gone/model'), findsNothing);
    expect(row('recent-gone/recent'), findsNothing);
    // A favorite is not repeated among the recents.
    expect(row('recent-opencode/zen'), findsNothing);
    expect(row('recent-other/gamma'), findsOneWidget);
    // Nor are favorites and recents repeated in their provider's group
    // (#515).
    expect(row('model-opencode/zen'), findsNothing);
    expect(row('model-other/gamma'), findsNothing);
    double top(Finder finder) => tester.getTopLeft(finder).dy;
    expect(
      top(find.text(l10n.liveModelFavorites)),
      lessThan(top(find.text(l10n.liveModelRecent))),
    );
    expect(
      top(row('recent-other/gamma')),
      lessThan(top(row('model-prov/alpha'))),
    );
    // Outside its provider's group a model names its provider.
    expect(
      find.descendant(
        of: row('favorite-opencode/zen'),
        matching: find.text('opencode'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the composer chip shortens the name; its tooltip keeps it', (
    tester,
  ) async {
    final long = ModelEntry(
      id: 'opus',
      providerId: 'prov',
      label: 'Claude Opus 5.5 Free',
      variants: ['high'],
    );
    await open(
      tester,
      state: SessionSelectionState(
        selection: _selection(long, 'high'),
        models: [long, _beta],
      ),
    );
    final chip = find.byKey(const ValueKey('live-model-chip'));
    final text = tester.widget<Text>(
      find.descendant(of: chip, matching: find.byType(Text)).first,
    );
    expect(text.textSpan!.toPlainText(), contains('Opus 5.5 high'));
    expect(text.textSpan!.toPlainText(), endsWith(' high'));
    expect(text.textSpan!.toPlainText(), isNot(contains('Claude')));
    // The name said Free: the chip draws the icon instead (#524).
    expect(
      find.descendant(
        of: chip,
        matching: find.byKey(const ValueKey('live-model-chip-free')),
      ),
      findsOneWidget,
    );
    final tooltip = tester.widget<Tooltip>(
      find.ancestor(of: chip, matching: find.byType(Tooltip)).first,
    );
    expect(tooltip.message, contains('Claude Opus 5.5 Free'));
    // The button itself is announced by the full name.
    expect(text.semanticsLabel, 'Claude Opus 5.5 Free high');
    // The pick keeps the full name.
    await openPicker(tester);
    expect(
      find.descendant(
        of: row('model-prov/opus'),
        matching: find.text('Claude Opus 5.5 Free'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a default model is shortened before its variant', (
    tester,
  ) async {
    await open(
      tester,
      state: SessionSelectionState(
        selection: const Selection(agentId: 'build'),
        models: [_alpha],
        defaultModel: 'Kimi K3.1 Pro Highspeed#max',
      ),
    );
    final chip = find.byKey(const ValueKey('live-model-chip'));
    expect(
      find.descendant(of: chip, matching: find.text('K3.1 Pro HS#max')),
      findsOneWidget,
    );
  });

  testWidgets('Free marks only a stated zero price', (tester) async {
    await open(tester);
    await openPicker(tester);
    Finder free(String key) => find.descendant(
      of: row('model-$key'),
      matching: find.text(l10n.liveModelFree),
    );
    expect(free('opencode/zen'), findsOneWidget);
    expect(free('prov/alpha'), findsNothing);
    expect(free('prov/beta'), findsNothing);
  });

  testWidgets('a star saves a favorite without picking the model', (
    tester,
  ) async {
    final (_, handle) = await open(tester);
    await openPicker(tester);
    final star = find.byKey(
      const ValueKey('live-selection-star-model-prov/beta'),
    );
    expect(tester.widget<IconButton>(star).isSelected, isFalse);
    await tester.tap(star);
    await tester.pumpAndSettle();
    expect(switches(handle), isEmpty);
    expect(preferences.favorites(_server), ['prov/beta']);
    // A favorite leaves its provider's group: each model shows once (#515).
    expect(star, findsNothing);
    expect(row('model-prov/beta'), findsNothing);
    final starred = find.byKey(
      const ValueKey('live-selection-star-favorite-prov/beta'),
    );
    expect(tester.widget<IconButton>(starred).isSelected, isTrue);
    // The star shows filled: a Material Symbols glyph is outlined unless it
    // is filled (#485).
    expect(
      find.descendant(
        of: starred,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Icon && widget.icon == Symbols.star && widget.fill == 1,
        ),
      ),
      findsOneWidget,
    );
    expect(row('favorite-prov/beta'), findsOneWidget);
    // Unstarring from the favorites returns it to its provider.
    await tester.tap(starred);
    await tester.pumpAndSettle();
    expect(preferences.favorites(_server), isEmpty);
    expect(row('favorite-prov/beta'), findsNothing);
    expect(row('model-prov/beta'), findsOneWidget);
    expect(switches(handle), isEmpty);
  });

  group('on a compact screen (#516)', () {
    const phone = Size(390, 844);

    testWidgets('a long press toggles a favorite and the sheet says so', (
      tester,
    ) async {
      final (_, handle) = await open(tester, size: phone);
      await openPicker(tester);
      expect(find.byType(BottomSheet), findsOneWidget);
      // No star takes the row's room.
      expect(
        find.byKey(const ValueKey('live-selection-star-model-prov/beta')),
        findsNothing,
      );
      await tester.longPress(row('model-prov/beta'));
      await tester.pumpAndSettle();
      expect(preferences.favorites(_server), ['prov/beta']);
      expect(switches(handle), isEmpty);
      // The toast shows inside the sheet, which stays open.
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(l10n.liveModelFavoriteAdded),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('live-selection-favorite-favorite-prov/beta'),
        ),
        findsOneWidget,
      );
      final bar = tester.widget<DecoratedBox>(
        find.byKey(
          const ValueKey('live-selection-favorite-favorite-prov/beta'),
        ),
      );
      final border =
          (bar.decoration as BoxDecoration).border! as BorderDirectional;
      expect(border.start.width, 4);
      expect(border.end, BorderSide.none);
      // A plain row carries no bar.
      expect(
        find.byKey(const ValueKey('live-selection-favorite-model-prov/alpha')),
        findsNothing,
      );
      await tester.longPress(row('favorite-prov/beta'));
      await tester.pumpAndSettle();
      expect(preferences.favorites(_server), isEmpty);
      expect(find.text(l10n.liveModelFavoriteRemoved), findsOneWidget);
      expect(row('model-prov/beta'), findsOneWidget);
      // A tap still picks the model.
      await tester.tap(row('model-prov/beta'));
      await tester.pumpAndSettle();
      expect(switches(handle), ['model:prov/beta']);
    });

    testWidgets('a long press still favorites while the switch is locked', (
      tester,
    ) async {
      final (live, handle) = await open(tester, size: phone);
      await openPicker(tester);
      // The stream drops with the pick open: rows can no longer switch.
      handle.emit(
        SessionLiveView(
          session: live.summary.info.ref,
          phase: SessionLivePhase.reconnecting,
          state: liveState(live.summary.info.ref),
        ),
      );
      await tester.pumpAndSettle();
      expect(live.canChangeSelection, isFalse);
      expect(tester.widget<ListTile>(row('model-prov/beta')).enabled, isFalse);
      await tester.longPress(row('model-prov/beta'));
      await tester.pumpAndSettle();
      expect(preferences.favorites(_server), ['prov/beta']);
      expect(switches(handle), isEmpty);
    });

    testWidgets('a favorite that cannot be saved says nothing new', (
      tester,
    ) async {
      backend.values[ModelPreferenceStore.key] = 'not json';
      await open(tester, size: phone);
      await openPicker(tester);
      await tester.longPress(row('model-prov/beta'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveModelFavoriteAdded), findsNothing);
      expect(backend.values[ModelPreferenceStore.key], 'not json');
    });

    testWidgets('a screen reader can toggle the favorite', (tester) async {
      final semantics = tester.ensureSemantics();
      await open(tester, size: phone);
      await openPicker(tester);
      tester.semantics.customAction(
        find.semantics.byLabel(RegExp('Beta')),
        CustomSemanticsAction(label: l10n.liveModelFavoriteAdd),
      );
      await tester.pumpAndSettle();
      expect(preferences.favorites(_server), ['prov/beta']);
      semantics.dispose();
    });
  });

  testWidgets('providers by name, and the model a default session runs', (
    tester,
  ) async {
    await open(
      tester,
      favorites: ['opencode/zen'],
      state: SessionSelectionState(
        selection: const Selection(agentId: 'build'),
        models: [_alpha, _beta, _zen, _gamma],
        defaultModel: 'Beta',
        providers: const {'prov': 'Provider One', 'opencode': 'OpenCode Zen'},
      ),
    );
    // Without a model of its own the session names the one the server runs.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('live-model-chip')),
        matching: find.text('Beta'),
      ),
      findsOneWidget,
    );
    await openPicker(tester);
    expect(find.text('Provider One'), findsOneWidget);
    // A provider the location does not name shows its id.
    expect(find.text('other'), findsOneWidget);
    expect(
      find.descendant(
        of: row('favorite-opencode/zen'),
        matching: find.text('OpenCode Zen'),
      ),
      findsOneWidget,
    );
    // A search finds a model by its provider's name too.
    await tester.enterText(
      find.byKey(const ValueKey('live-selection-search')),
      'provider one',
    );
    await tester.pumpAndSettle();
    expect(row('model-prov/alpha'), findsOneWidget);
    expect(row('model-other/gamma'), findsNothing);
  });

  testWidgets('a search narrows by name, id or provider', (tester) async {
    await open(tester, favorites: ['prov/alpha']);
    await openPicker(tester);
    final search = find.byKey(const ValueKey('live-selection-search'));
    await tester.enterText(search, 'OTHER');
    await tester.pumpAndSettle();
    expect(row('model-other/gamma'), findsOneWidget);
    expect(row('model-prov/alpha'), findsNothing);
    // While searching, the matches show once.
    expect(find.text(l10n.liveModelFavorites), findsNothing);
    await tester.enterText(search, 'zen');
    await tester.pumpAndSettle();
    expect(row('model-opencode/zen'), findsOneWidget);
    await tester.enterText(search, 'nothing like it');
    await tester.pumpAndSettle();
    expect(row('no-match'), findsOneWidget);
  });

  testWidgets('a switch the server took becomes the most recent', (
    tester,
  ) async {
    final (_, handle) = await open(tester, recents: ['other/gamma']);
    // Only a switch changes the selection; the reads on open keep it.
    handle.selectionAction = (change) async => change == 'refresh'
        ? handle.selectionState
        : SessionSelectionState(
            selection: _selection(_beta),
            models: [_alpha, _beta, _zen, _gamma],
          );
    await openPicker(tester);
    await tester.tap(row('model-prov/beta'));
    await tester.pumpAndSettle();
    expect(switches(handle), ['model:prov/beta']);
    expect(preferences.recents(_server, _project), [
      'prov/beta',
      // The model switched away from follows it.
      'prov/alpha',
      'other/gamma',
    ]);
    // A refused switch is not recorded.
    handle.selectionAction = (change) async => change == 'refresh'
        ? handle.selectionState
        : SessionSelectionState(
            selection: _selection(_beta),
            models: [_alpha, _beta, _zen, _gamma],
            notice: SessionSelectionNotice.refused,
          );
    await openPicker(tester);
    await tester.tap(row('model-opencode/zen'));
    await tester.pumpAndSettle();
    expect(switches(handle).last, 'model:opencode/zen');
    expect(preferences.recents(_server, _project).first, 'prov/beta');
  });

  testWidgets('a switch that was not sent records nothing', (tester) async {
    final (live, handle) = await open(tester);
    // A stale lease cannot switch: picking the current model sends nothing
    // and must not make it recent.
    handle.emit(
      SessionLiveView(
        session: live.session,
        phase: SessionLivePhase.live,
        stale: true,
        state: liveState(live.session),
      ),
    );
    await tester.pump();
    expect(live.canChangeSelection, isFalse);
    await live.selectModel(_alpha);
    expect(switches(handle), isEmpty);
    expect(preferences.recents(_server, _project), isEmpty);
  });

  testWidgets('an unconfirmed switch becomes recent once it is confirmed', (
    tester,
  ) async {
    final (live, handle) = await open(tester);
    final models = [_alpha, _beta, _zen, _gamma];
    handle.selectionAction = (change) async => SessionSelectionState(
      selection: _selection(_alpha, 'high'),
      models: models,
      phase: SessionSelectionPhase.unconfirmed,
    );
    await live.selectModel(_beta);
    expect(switches(handle), ['model:prov/beta']);
    expect(preferences.recents(_server, _project), isEmpty);
    // A later read settles it as applied.
    handle
      ..selectionState = SessionSelectionState(
        selection: _selection(_beta),
        models: models,
      )
      ..emit(handle.current);
    await tester.pumpAndSettle();
    expect(preferences.recents(_server, _project), ['prov/beta', 'prov/alpha']);
    // One settled as not applied records nothing.
    handle.selectionAction = (change) async => SessionSelectionState(
      selection: _selection(_beta),
      models: models,
      phase: SessionSelectionPhase.unconfirmed,
    );
    await live.selectModel(_gamma);
    handle
      ..selectionState = SessionSelectionState(
        selection: _selection(_beta),
        models: models,
        notice: SessionSelectionNotice.notApplied,
      )
      ..emit(handle.current);
    await tester.pumpAndSettle();
    expect(preferences.recents(_server, _project), ['prov/beta', 'prov/alpha']);
  });

  testWidgets('a pick that is not sent leaves an earlier one waiting', (
    tester,
  ) async {
    final (live, handle) = await open(tester);
    final models = [_alpha, _beta, _zen, _gamma];
    handle.selectionAction = (change) async => SessionSelectionState(
      selection: _selection(_alpha, 'high'),
      models: models,
      phase: SessionSelectionPhase.unconfirmed,
    );
    await live.selectModel(_beta);
    // A stale lease cannot send the next pick.
    handle.emit(
      SessionLiveView(
        session: live.session,
        phase: SessionLivePhase.live,
        stale: true,
        state: liveState(live.session),
      ),
    );
    await tester.pump();
    await live.selectModel(_gamma);
    expect(switches(handle), ['model:prov/beta']);
    handle
      ..selectionState = SessionSelectionState(
        selection: _selection(_beta),
        models: models,
      )
      ..emit(
        SessionLiveView(
          session: live.session,
          phase: SessionLivePhase.live,
          state: liveState(live.session),
        ),
      );
    await tester.pumpAndSettle();
    expect(preferences.recents(_server, _project), ['prov/beta', 'prov/alpha']);
  });

  testWidgets('an earlier pick ending after a newer one replaces nothing', (
    tester,
  ) async {
    final (live, handle) = await open(tester);
    final models = [_alpha, _beta, _zen, _gamma];
    final late = Completer<SessionSelectionState>();
    handle.selectionAction = (change) => change == 'model:prov/beta'
        ? late.future
        : Future.value(
            SessionSelectionState(
              selection: _selection(_alpha, 'high'),
              models: models,
              phase: SessionSelectionPhase.unconfirmed,
            ),
          );
    // Beta's answer is still being verified when Gamma is picked.
    final beta = live.selectModel(_beta);
    await tester.pump();
    await live.selectModel(_gamma);
    late.complete(
      SessionSelectionState(
        selection: _selection(_alpha, 'high'),
        models: models,
        phase: SessionSelectionPhase.unconfirmed,
      ),
    );
    await beta;
    // Gamma, the newer pick, is the one confirmed.
    handle
      ..selectionState = SessionSelectionState(
        selection: _selection(_gamma),
        models: models,
      )
      ..emit(handle.current);
    await tester.pumpAndSettle();
    expect(preferences.recents(_server, _project), [
      'other/gamma',
      'prov/alpha',
    ]);
  });

  testWidgets('a new lease settles nothing the old one sent', (tester) async {
    final (live, handle) = await open(tester);
    final models = [_alpha, _beta, _zen, _gamma];
    handle.selectionAction = (change) async => SessionSelectionState(
      selection: _selection(_alpha, 'high'),
      models: models,
      phase: SessionSelectionPhase.unconfirmed,
    );
    await live.selectModel(_beta);
    handle.emit(
      SessionLiveView(session: live.session, phase: SessionLivePhase.degraded),
    );
    await tester.pump();
    expect(live.canRetry, isTrue);
    final retry = live.retry();
    final next = directory.grant(live.session)
      ..selectionAvailable = true
      ..selectionState = SessionSelectionState(
        selection: _selection(_beta),
        models: models,
      );
    await retry;
    next.emit(
      SessionLiveView(
        session: live.session,
        phase: SessionLivePhase.live,
        state: liveState(live.session),
      ),
    );
    await tester.pumpAndSettle();
    expect(preferences.recents(_server, _project), isEmpty);
  });

  testWidgets('Auto still clears a variant the model no longer lists', (
    tester,
  ) async {
    final (_, handle) = await open(tester);
    final plain = ModelEntry(id: 'alpha', providerId: 'prov', label: 'Alpha');
    handle
      ..selectionState = SessionSelectionState(
        selection: _selection(plain, 'high'),
        models: [plain, _beta],
      )
      ..emit(handle.current);
    await tester.pumpAndSettle();
    // The current model's variant menu offers Auto.
    await openPicker(tester);
    await tester.tap(row('variant-menu-model-prov/alpha'));
    await tester.pumpAndSettle();
    await tester.tap(row('auto-prov/alpha'));
    await tester.pumpAndSettle();
    expect(switches(handle), ['model:prov/alpha']);
  });

  testWidgets('Auto reads the same in every language (#517)', (tester) async {
    for (final locale in const [Locale('pt'), Locale('es'), Locale('ja')]) {
      await open(
        tester,
        locale: locale,
        state: SessionSelectionState(
          selection: _selection(_alpha),
          models: [_alpha, _beta],
        ),
      );
      await openPicker(tester);
      final menu = find.byKey(
        const ValueKey('live-selection-variant-menu-model-prov/alpha'),
      );
      expect(
        find.descendant(of: menu, matching: find.text('Auto')),
        findsOneWidget,
        reason: '$locale',
      );
      expect(find.text('Automático'), findsNothing);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('live-selection-auto-prov/alpha')),
          matching: find.text('Auto'),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('the current model keeps its variant; only Auto clears it', (
    tester,
  ) async {
    final (_, handle) = await open(tester);
    await openPicker(tester);
    // The model's own menu names its variant (#485).
    expect(
      find.descendant(
        of: row('variant-menu-model-prov/alpha'),
        matching: find.text('high'),
      ),
      findsOneWidget,
    );
    await tester.tap(row('model-prov/alpha'));
    await tester.pumpAndSettle();
    expect(row('model-prov/alpha'), findsNothing);
    expect(switches(handle), isEmpty);
    await openPicker(tester);
    await tester.tap(row('variant-menu-model-prov/alpha'));
    await tester.pumpAndSettle();
    await tester.tap(row('auto-prov/alpha'));
    await tester.pumpAndSettle();
    expect(switches(handle), ['model:prov/alpha']);
  });

  testWidgets('an unreadable record shows no stars to save and says so', (
    tester,
  ) async {
    backend.values[ModelPreferenceStore.key] = 'not json';
    await open(tester);
    await openPicker(tester);
    expect(row('preferences-unsaved'), findsOneWidget);
    final star = find.byKey(
      const ValueKey('live-selection-star-model-prov/beta'),
    );
    expect(tester.widget<IconButton>(star).onPressed, isNull);
    expect(backend.values[ModelPreferenceStore.key], 'not json');
  });

  for (final (name, size, locale, finder) in [
    ('mobile_light', const Size(390, 844), const Locale('en'), BottomSheet),
    ('mobile_ar_rtl', const Size(390, 844), const Locale('ar'), BottomSheet),
    ('desktop_light', const Size(1280, 800), const Locale('en'), Dialog),
  ]) {
    testWidgets('model picker, $name', (tester) async {
      await open(
        tester,
        favorites: ['opencode/zen'],
        recents: ['other/gamma'],
        size: size,
        locale: locale,
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      );
      await openPicker(tester);
      await expectLater(
        find.byType(finder),
        matchesGoldenFile('goldens/model_picker_$name.png'),
      );
    });
  }
}
