import 'dart:async';

import 'package:codewalk/app/app_dependencies.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/session_live_page.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_actions.dart';
import 'package:codewalk/shared/sessions/session_activity.dart';
import 'package:codewalk/shared/sessions/session_catalog_changes.dart';
import 'package:codewalk/shared/sessions/session_catalog_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../hosts/fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';
import 'workspace_support.dart';

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

final _idle = DateTime.utc(2026, 10, 22, 1);

SessionRef _ref(String id) => SessionRef(
  const HostId('profile_a'),
  const HarnessInstanceId('profile_a'),
  'ses_$id',
);

/// The rows of one profile: `one` and `two` in /work/a, `three` in /work/b.
List<SessionSummary> _rows(CatalogSource source, {DateTime? idle}) => [
  source.row(
    'one',
    directory: '/work/a',
    view: SessionViewMarker(idleAt: idle ?? _idle),
  ),
  source.row('two', directory: '/work/a'),
  source.row('three', directory: '/work/b'),
];

/// A list of [_rows] whose activity reads answer [activity].
Future<CatalogRig> _loaded({
  SessionActivity activity = const SessionActivity(),
  FakeActionSource? actions,
}) async {
  final rig = CatalogRig(actions: actions);
  addTearDown(rig.dispose);
  await rig.save('a');
  await rig.sessions.initialize();
  await _settle();
  final read = rig.sessions.selectProfile('profile_a');
  final source = rig.sources.single;
  source.activityAnswer = activity;
  source.respond(_rows(source));
  await read;
  await _settle();
  await _answer(rig);
  return rig;
}

/// Answers the rows read in flight, if any, with [_rows].
Future<void> _answer(CatalogRig rig, {DateTime? idle}) async {
  final source = rig.sources.single;
  if (source.tasks.isNotEmpty && !source.tasks.last.completion.isCompleted) {
    source.respond(_rows(source, idle: idle));
    await _settle();
  }
}

SessionSummary _row(CatalogRig rig, String id) =>
    rig.sessions.sessions.firstWhere((row) => row.info.ref == _ref(id));

List<SessionActivityMark> _marks(CatalogRig rig, String id) =>
    rig.sessions.activityMarks(_row(rig, id));

FakeActionSource _unreadOne() => FakeActionSource(
  viewStates: {_ref('one').storageKey: SessionViewState.unread},
);

void main() {
  group('the activity of the rows', () {
    test('each mark comes from its own observed source', () async {
      final rig = await _loaded(
        actions: _unreadOne(),
        activity: SessionActivity(
          running: {_ref('two'), _ref('three')},
          waiting: {_ref('one'), _ref('three')},
        ),
      );
      // The open group is /work/a: its pending lists were read.
      expect(rig.sources.single.activityRequests.last, '/work/a');
      expect(_marks(rig, 'one'), [
        SessionActivityMark.needsYou,
        SessionActivityMark.unread,
      ]);
      expect(_marks(rig, 'two'), [SessionActivityMark.running]);
      // The pending lists of /work/b were not read: no needs-you there.
      expect(_marks(rig, 'three'), [SessionActivityMark.running]);
    });

    test('a part that was not read adds no mark', () async {
      final rig = await _loaded();
      for (final id in ['one', 'two', 'three']) {
        expect(_marks(rig, id), isEmpty);
      }
    });

    test('an activity signal re-reads only the activity', () async {
      final rig = await _loaded();
      final source = rig.sources.single;
      final rows = source.tasks.length;
      final reads = source.activityRequests.length;
      source.activityAnswer = SessionActivity(running: {_ref('two')});
      for (var i = 0; i < 5; i++) {
        rig.feed.emit(const SessionActivityChanged());
      }
      await _settle();
      expect(source.tasks, hasLength(rows), reason: 'the rows are not re-read');
      expect(
        source.activityRequests,
        hasLength(reads + 1),
        reason: 'a burst is one read',
      );
      expect(_marks(rig, 'two'), [SessionActivityMark.running]);
    });

    test('a read that fails drops what the last one observed', () async {
      final rig = await _loaded(
        activity: SessionActivity(running: {_ref('two')}),
      );
      expect(_marks(rig, 'two'), [SessionActivityMark.running]);
      rig.sources.single.activityAnswer = const SessionActivity();
      rig.feed.emit(const SessionActivityChanged());
      await _settle();
      expect(_marks(rig, 'two'), isEmpty);
    });

    test('a list behind the endpoint claims no activity', () async {
      final rig = await _loaded(
        actions: _unreadOne(),
        activity: SessionActivity(
          running: {_ref('two')},
          waiting: {_ref('one')},
        ),
      );
      rig.feed.emit(const SessionCatalogChanged());
      await _settle();
      rig.sources.single.fail(SessionCatalogFailure.connection);
      await _settle();
      expect(rig.sessions.behind, isTrue);
      expect(_marks(rig, 'two'), isEmpty);
      // The unread marker is the row's own.
      expect(_marks(rig, 'one'), [SessionActivityMark.unread]);
    });

    test('the rows of a live re-read do not wait for the activity', () async {
      final rig = await _loaded();
      final source = rig.sources.single;
      final gate = source.activityGate = Completer<void>();
      rig.feed.emit(const SessionCatalogChanged());
      await _settle();
      source.respond([..._rows(source), source.row('four')]);
      await _settle();
      expect(rig.sessions.quietRefreshing, isFalse);
      expect(rig.sessions.sessions, hasLength(4));
      gate.complete();
      await _settle();
    });

    test('a read of a profile that was left yields to the new one', () async {
      final rig = CatalogRig(withFeed: false);
      addTearDown(rig.dispose);
      await rig.save('a');
      await rig.save('b');
      await rig.sessions.initialize();
      await _settle();
      final first = rig.sessions.selectProfile('profile_a');
      final left = rig.sources.single;
      final gate = left.activityGate = Completer<void>();
      left.respond(_rows(left));
      await first;
      await _settle();
      expect(left.activityRequests, hasLength(1), reason: 'held open');
      final second = rig.sessions.selectProfile('profile_b');
      final source = rig.sources.last;
      final row = source.row('four', directory: '/work/b');
      source.activityAnswer = SessionActivity(running: {row.info.ref});
      source.respond([row]);
      await second;
      await _settle();
      expect(source.activityRequests, isEmpty, reason: 'one read at a time');
      gate.complete();
      await _settle();
      expect(source.activityRequests, ['/work/b']);
      expect(rig.sessions.activityMarks(rig.sessions.sessions.single), [
        SessionActivityMark.running,
      ]);
    });

    test('another group reads its own pending lists', () async {
      final rig = await _loaded(
        activity: SessionActivity(waiting: {_ref('three')}),
      );
      expect(_marks(rig, 'three'), isEmpty);
      rig.sessions.selectProject(_row(rig, 'three').info.project);
      await _settle();
      expect(rig.sources.single.activityRequests.last, '/work/b');
      expect(_marks(rig, 'three'), [SessionActivityMark.needsYou]);
    });
  });

  group('the unread mark of the shown session', () {
    test('is marked viewed once per idle transition', () async {
      final actions = _unreadOne();
      final rig = await _loaded(actions: actions);
      final key = _ref('one').storageKey;
      expect(actions.viewed, isEmpty, reason: 'nothing is shown yet');
      rig.sessions.showing(_ref('one'));
      await _settle();
      expect(actions.viewed, [(key, _idle)]);
      // The accepted view is observed by a re-read; the same transition is
      // never sent again.
      await _answer(rig);
      rig.sessions.showing(_ref('one'));
      await _settle();
      expect(actions.viewed, hasLength(1));
      // The session went idle again while it is shown.
      final later = _idle.add(const Duration(minutes: 5));
      rig.feed.emit(const SessionCatalogChanged());
      await _settle();
      await _answer(rig, idle: later);
      expect(actions.viewed, [(key, _idle), (key, later)]);
    });

    test('a session that is no longer shown is not marked', () async {
      final actions = _unreadOne();
      final rig = await _loaded(actions: actions);
      rig.sessions.showing(_ref('two'));
      await _settle();
      expect(actions.viewed, isEmpty, reason: 'the shown row is not unread');
      rig.sessions.showing(_ref('one'));
      rig.sessions.leave(_ref('one'));
      await _settle();
      await _answer(rig);
      final later = _idle.add(const Duration(minutes: 5));
      rig.feed.emit(const SessionCatalogChanged());
      await _settle();
      await _answer(rig, idle: later);
      expect(actions.viewed.map((view) => view.$2), [_idle]);
    });

    test('a refused view keeps the mark and says nothing', () async {
      final actions = _unreadOne()
        ..outcomes['markViewed'] = SessionActionOutcome.rejected;
      final rig = await _loaded(actions: actions);
      rig.sessions.showing(_ref('one'));
      await _settle();
      expect(actions.viewed, hasLength(1));
      expect(rig.sessions.actionFailure, isNull);
      expect(_marks(rig, 'one'), [SessionActivityMark.unread]);
      // The next read of the same transition does not send it again.
      rig.feed.emit(const SessionCatalogChanged());
      await _settle();
      await _answer(rig);
      expect(actions.viewed, hasLength(1));
    });

    test('nothing is sent before the endpoint version is verified', () async {
      final actions = FakeActionSource(
        endpointSupport: const SessionActionSupport(
          SessionActionReason.versionUnverified,
        ),
        viewStates: {_ref('one').storageKey: SessionViewState.unread},
      );
      final rig = await _loaded(actions: actions);
      rig.sessions.showing(_ref('one'));
      await _settle();
      expect(actions.viewed, isEmpty);
    });
  });

  group('the sidebar', () {
    late FakeActionSource actions;
    late LiveDirectory directory;

    Future<(AppDependencies, V2Localizations, CatalogSource)> open(
      WidgetTester tester, {
      String link = '/sessions',
      Size size = const Size(1280, 800),
      Locale? locale,
      double scale = 1,
      SessionActivity activity = const SessionActivity(),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final rig = CatalogRig();
      addTearDown(rig.dispose);
      await rig.save('a');
      actions = _unreadOne();
      directory = LiveDirectory();
      final dependencies = createAppDependencies(
        initialLink: Uri.parse(link),
        profileRepository: rig.repository,
        endpointProber: FakeProber(),
        sessionCatalogFactory: rig.create,
        sessionLiveDirectory: () => directory,
        sessionActionFactory: (profile, credential) => actions,
      );
      if (locale != null) dependencies.preferences.setLocale(locale);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: CodeWalkV2Bootstrap(dependencies: dependencies),
        ),
      );
      // A spinner never settles.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // The single saved server opens on its own; a compact window shows
      // its list in the drawer.
      await showSessionList(tester);
      final source = rig.sources.single;
      source.activityAnswer = activity;
      // The read, then the catch-up read that follows the feed's opening.
      for (var read = 0; read < 2; read++) {
        if (!source.tasks.last.completion.isCompleted) {
          source.respond(_rows(source));
        }
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
      return (dependencies, dependencies.localizations.current, source);
    }

    /// Waits for the next rows read, past the list's debounce and cooldown,
    /// and answers it with [_rows]. The cooldown runs on the wall clock, so
    /// the wait is a real one.
    Future<void> reread(
      WidgetTester tester,
      CatalogSource source, {
      DateTime? idle,
    }) async {
      for (var i = 0; i < 5 && source.tasks.last.completion.isCompleted; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 700)),
        );
        await tester.pump(const Duration(milliseconds: 400));
      }
      source.respond(_rows(source, idle: idle));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    final all = SessionActivity(running: {_ref('one')}, waiting: {_ref('one')});

    testWidgets('each mark shows its label, and an unknown row shows none', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final (_, l10n, _) = await open(tester, activity: all);
      final one = _ref('one').storageKey;
      final two = _ref('two').storageKey;
      expect(find.byKey(ValueKey('session-needs-you-$one')), findsOneWidget);
      expect(find.byKey(ValueKey('session-running-$one')), findsOneWidget);
      expect(find.byKey(ValueKey('session-unread-$one')), findsOneWidget);
      for (final mark in ['needs-you', 'running', 'unread']) {
        expect(find.byKey(ValueKey('session-$mark-$two')), findsNothing);
      }
      // The labels are what a screen reader announces.
      for (final label in [
        l10n.liveNeedsYou,
        l10n.liveRunning,
        l10n.sessionsActionUnread,
      ]) {
        expect(
          find.bySemanticsLabel(RegExp(RegExp.escape(label))),
          findsWidgets,
        );
      }
      // No harness name is shown while one harness exists.
      expect(find.textContaining('OpenCode'), findsNothing);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    for (final (name, size, locale, scale) in const [
      ('compact rtl', Size(390, 844), Locale('ar'), 1.0),
      ('wide rtl', Size(1280, 800), Locale('ar'), 1.0),
      ('compact 2x', Size(390, 844), Locale('en'), 2.0),
      ('narrow pane 2x', Size(600, 800), Locale('ru'), 2.0),
      ('wide 2x', Size(1280, 800), Locale('en'), 2.0),
    ]) {
      testWidgets('the marks fit without overflow, $name', (tester) async {
        await open(
          tester,
          size: size,
          locale: locale,
          scale: scale,
          activity: all,
        );
        final one = _ref('one').storageKey;
        // The attention notice can put this lazy row below the viewport.
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('session-needs-you-$one')),
          120,
          scrollable: find
              .ancestor(
                of: find.byKey(const ValueKey('sessions-profile')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        for (final mark in ['needs-you', 'running', 'unread']) {
          expect(
            find.byKey(ValueKey('session-$mark-$one'), skipOffstage: false),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets('opening an unread session clears its mark', (tester) async {
      final (_, _, source) = await open(tester, link: '/s/profile_a/ses_one');
      final key = _ref('one').storageKey;
      expect(find.byType(SessionLivePage), findsOneWidget);
      expect(actions.viewed, [(key, _idle)]);
      // The endpoint saw the view: the next read reports the row as read.
      actions.viewStates[key] = SessionViewState.read;
      await reread(tester, source);
      expect(find.byKey(ValueKey('session-unread-$key')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a session that goes idle in the background stays unread', (
      tester,
    ) async {
      final (_, _, source) = await open(tester, link: '/s/profile_a/ses_one');
      final key = _ref('one').storageKey;
      expect(actions.viewed, hasLength(1));
      await reread(tester, source);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      final later = _idle.add(const Duration(minutes: 5));
      directory.feeds.last.emit(const SessionCatalogChanged());
      await reread(tester, source, idle: later);
      expect(actions.viewed, hasLength(1), reason: 'the app is not seen');
      expect(find.byKey(ValueKey('session-unread-$key')), findsOneWidget);
      // Back in the foreground, the shown session is seen.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));
      expect(actions.viewed.last, (key, later));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
