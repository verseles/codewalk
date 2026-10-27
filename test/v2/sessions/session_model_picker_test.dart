@TestOn('vm')
library;

import 'package:codewalk/features/sessions/session_composer_controls.dart';
import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/platform/sessions/model_preference_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_selection.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
      ..selectionState = SessionSelectionState(
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
            child: SessionComposerControls(live: live),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (live, handle);
  }

  Future<void> openPicker(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('live-model-chip')));
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
    // The model chip lists models only.
    expect(find.text(l10n.liveSelectionModel), findsOneWidget);
    expect(find.text(l10n.liveSelectionAgent), findsNothing);
    expect(row('favorite-opencode/zen'), findsOneWidget);
    // A saved name the location does not offer is not shown.
    expect(row('favorite-gone/model'), findsNothing);
    expect(row('recent-gone/recent'), findsNothing);
    // A favorite is not repeated among the recents.
    expect(row('recent-opencode/zen'), findsNothing);
    expect(row('recent-other/gamma'), findsOneWidget);
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
    expect(tester.widget<IconButton>(star).isSelected, isTrue);
    expect(row('favorite-prov/beta'), findsOneWidget);
    // Unstarring from the favorites removes it again.
    await tester.tap(
      find.byKey(const ValueKey('live-selection-star-favorite-prov/beta')),
    );
    await tester.pumpAndSettle();
    expect(preferences.favorites(_server), isEmpty);
    expect(row('favorite-prov/beta'), findsNothing);
    expect(switches(handle), isEmpty);
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

  testWidgets('the current model keeps its variant; only Auto clears it', (
    tester,
  ) async {
    final (_, handle) = await open(tester);
    await openPicker(tester);
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(
              const ValueKey('live-selection-variant-prov/alpha#high'),
            ),
          )
          .selected,
      isTrue,
    );
    await tester.tap(row('model-prov/alpha'));
    await tester.pumpAndSettle();
    expect(row('model-prov/alpha'), findsNothing);
    expect(switches(handle), isEmpty);
    await openPicker(tester);
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
