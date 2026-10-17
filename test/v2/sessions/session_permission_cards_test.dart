import 'dart:async';

import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/session_composer.dart';
import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/features/sessions/session_live_page.dart';
import 'package:codewalk/features/sessions/session_permission_card.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations_en.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_permission_reply.dart';
import 'package:codewalk/shared/sessions/session_stop.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../hosts/fakes.dart';
import 'composer_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';

ApprovalChoice _once() => ApprovalChoice(
  id: 'once',
  label: 'once',
  allows: true,
  scope: const OpenValue.known(ApprovalScope.once),
  resolutionScope: const OpenValue.known(ResolutionScope.request),
);

ApprovalChoice _reject() => ApprovalChoice(
  id: 'reject',
  label: 'reject',
  allows: false,
  scope: const OpenValue.known(ApprovalScope.once),
  resolutionScope: const OpenValue.known(ResolutionScope.session),
  acceptsNote: true,
);

ApprovalChoice _always(List<String> patterns) => ApprovalChoice(
  id: 'always',
  label: 'always',
  allows: true,
  scope: const OpenValue.known(ApprovalScope.persistentProject),
  resolutionScope: const OpenValue.known(ResolutionScope.project),
  scopePreview: patterns.isEmpty
      ? null
      : CanonicalValue({'patterns': patterns}),
);

InteractionRequest _ask(
  SessionRef ref,
  String id, {
  List<ApprovalChoice>? choices,
  Map<String, Object?>? subject,
}) => InteractionRequest(
  id: InteractionId(id),
  owner: SessionOwner(ref),
  kind: const OpenValue.known(InteractionKind.permission),
  title: 'read src/file.txt',
  choices: choices ?? [_once(), _reject()],
  subject: subject == null ? null : CanonicalValue(subject),
);

/// Flushes the multi-turn stream/notify cascade behind a reply without
/// waiting on the persistent requested spinner (which never settles).
Future<void> _settleFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Mounts the live page for one catalog session with a reply-capable lease
/// already granted, so a test only has to emit the view it wants.
Future<
  ({
    CatalogRig rig,
    SessionRef ref,
    LiveHandle handle,
    V2Localizations l10n,
  })
>
_mountLivePage(
  WidgetTester tester, {
  required Size size,
  required Locale locale,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final rig = CatalogRig();
  await rig.save('a');
  final directory = LiveDirectory();
  final dependencies = createAppDependencies(
    initialLink: Uri(path: '/sessions'),
    profileRepository: rig.repository,
    endpointProber: FakeProber(),
    sessionCatalogFactory: rig.create,
    sessionLiveDirectory: () => directory,
  );
  dependencies.preferences.setLocale(locale);
  await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: dependencies));
  await tester.pumpAndSettle();
  final l10n = dependencies.localizations.current;
  final read = dependencies.sessions!.selectProfile('profile_a');
  final catalog = rig.sources.single;
  final row = catalog.row('one');
  catalog.respond([row]);
  await read;
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey(row.info.ref)));
  await tester.pumpAndSettle();
  final button = find.byKey(ValueKey('live-open-${row.info.ref.storageKey}'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
  await tester.pump();
  final ref = row.info.ref;
  final handle = directory.grant(ref);
  handle.replyAvailable = true;
  await tester.pump();
  return (rig: rig, ref: ref, handle: handle, l10n: l10n);
}

void main() {
  group('notice copy mapping', () {
    final l10n = V2LocalizationsEn();

    test('maps every phase to finite copy', () {
      SessionPermissionReplyState at(SessionPermissionReplyPhase phase) =>
          SessionPermissionReplyState(phase: phase);
      expect(
        permissionNoticeText(l10n, at(SessionPermissionReplyPhase.ready)),
        isNull,
      );
      expect(
        permissionNoticeText(l10n, at(SessionPermissionReplyPhase.requesting)),
        l10n.livePermissionSending,
      );
      expect(
        permissionNoticeText(l10n, at(SessionPermissionReplyPhase.requested)),
        l10n.livePermissionSent,
      );
      expect(
        permissionNoticeText(l10n, at(SessionPermissionReplyPhase.unconfirmed)),
        l10n.livePermissionUnconfirmed,
      );
      expect(
        permissionNoticeText(l10n, at(SessionPermissionReplyPhase.refused)),
        l10n.livePermissionRefused,
      );
    });

    test('refused maps known error types without raw text', () {
      CommandReceipt refused(String type) => CommandReceipt.rejected(
        id: const CommandId('cmd_notice'),
        owner: const SessionOwner(
          SessionRef(HostId('h'), HarnessInstanceId('i'), 'ses_notice'),
        ),
        error: ErrorInfo(
          kind: const OpenValue.known(ErrorKind.auth),
          rawType: type,
          rawMessage: 'never shown',
        ),
      );
      SessionPermissionReplyState refusedWith(String type) =>
          SessionPermissionReplyState(
            phase: SessionPermissionReplyPhase.refused,
            receipt: refused(type),
          );
      expect(
        permissionNoticeText(l10n, refusedWith('UnauthorizedError')),
        l10n.hostsAuthRequired,
      );
      expect(
        permissionNoticeText(l10n, refusedWith('RateLimited')),
        l10n.sessionsRateLimited,
      );
      expect(
        permissionNoticeText(l10n, refusedWith('NotFoundError')),
        l10n.livePermissionRefused,
      );
    });
  });

  group('controller reply gating', () {
    late CatalogRig rig;
    late LiveDirectory directory;
    late SessionLiveController live;
    late SessionRef ref;
    late LiveHandle handle;
    var commands = 0;

    Future<void> open({SessionLiveView? view}) async {
      final opening = live.start();
      handle = directory.grant(ref);
      handle.replyAvailable = true;
      await opening;
      handle.emit(
        view ??
            SessionLiveView(
              session: ref,
              phase: SessionLivePhase.live,
              state: liveState(ref, interactions: [_ask(ref, 'per_1')]),
            ),
      );
      await pumpEventQueue();
    }

    setUp(() async {
      rig = CatalogRig();
      await rig.save('a');
      await rig.sessions.initialize();
      directory = LiveDirectory();
      final summary = CatalogSource(profile('a')).row('one');
      ref = summary.info.ref;
      commands = 0;
      live = SessionLiveController(
        hosts: rig.hosts,
        profile: profile('a'),
        summary: summary,
        directory: directory,
        commandIds: () => CommandId('cmd_${++commands}'),
      );
    });
    tearDown(() {
      live.dispose();
      rig.dispose();
    });

    test('requires live current state, never a running execution', () async {
      await open();
      expect(live.canReply(_ask(ref, 'per_1')), isTrue);
      for (final phase in SessionLivePhase.values) {
        handle.emit(
          SessionLiveView(
            session: ref,
            phase: phase,
            state: liveState(ref, interactions: [_ask(ref, 'per_1')]),
          ),
        );
        await pumpEventQueue();
        expect(
          live.canReply(_ask(ref, 'per_1')),
          phase == SessionLivePhase.live,
          reason: phase.name,
        );
      }
      handle.emit(
        SessionLiveView(
          session: ref,
          phase: SessionLivePhase.live,
          stale: true,
          state: liveState(ref, interactions: [_ask(ref, 'per_1')]),
        ),
      );
      await pumpEventQueue();
      expect(live.canReply(_ask(ref, 'per_1')), isFalse);
    });

    test(
      'one command per deliberate reply; uncertainty never replays',
      () async {
        await open();
        final pending = Completer<SessionPermissionReplyState>();
        handle.replyAction = (_, _) => pending.future;
        final first = live.replyToPermission(
          request: _ask(ref, 'per_1'),
          response: ApprovalResponse('once'),
        );
        await live.replyToPermission(
          request: _ask(ref, 'per_1'),
          response: ApprovalResponse('once'),
        );
        expect(handle.replies, hasLength(1));
        expect(live.replyState(const InteractionId('per_1')).busy, isTrue);
        pending.complete(
          const SessionPermissionReplyState(
            phase: SessionPermissionReplyPhase.unconfirmed,
          ),
        );
        await first;
        await pumpEventQueue();
        expect(handle.replies, hasLength(1));
        handle.replyAction = (_, _) async => const SessionPermissionReplyState(
          phase: SessionPermissionReplyPhase.idle,
        );
        await live.replyToPermission(
          request: _ask(ref, 'per_1'),
          response: ApprovalResponse('once'),
        );
        expect(handle.replies, hasLength(2));
        expect(handle.replies[0].$4, isNot(handle.replies[1].$4));
      },
    );

    test('credential removal drops a late reply result', () async {
      await open();
      final pending = Completer<SessionPermissionReplyState>();
      handle.replyAction = (_, _) => pending.future;
      final reply = live.replyToPermission(
        request: _ask(ref, 'per_1'),
        response: ApprovalResponse('once'),
      );
      await rig.hosts.remove(rig.hosts.profiles.single);
      pending.complete(
        const SessionPermissionReplyState(
          phase: SessionPermissionReplyPhase.requested,
        ),
      );
      await reply;
      expect(
        live.replyState(const InteractionId('per_1')).phase,
        SessionPermissionReplyPhase.ready,
      );
      expect(handle.replies, hasLength(1));
    });

    test('non-permission interactions are never actionable', () async {
      await open();
      final form = InteractionRequest(
        id: const InteractionId('frm_1'),
        owner: SessionOwner(ref),
        kind: const OpenValue.known(InteractionKind.form),
        title: 'Pick one',
      );
      expect(live.canReply(form), isFalse);
      await live.replyToPermission(
        request: form,
        response: ApprovalResponse('once'),
      );
      expect(handle.replies, isEmpty);
    });
  });

  group('card surface gating', () {
    late CatalogRig rig;
    late LiveDirectory directory;
    late SessionLiveController live;
    late SessionRef ref;
    late LiveHandle handle;

    Future<void> open(
      List<InteractionRequest> interactions, {
      bool replyPort = true,
    }) async {
      final opening = live.start();
      handle = directory.grant(ref);
      handle.replyAvailable = replyPort;
      await opening;
      handle.emit(
        SessionLiveView(
          session: ref,
          phase: SessionLivePhase.live,
          state: liveState(ref, interactions: interactions),
        ),
      );
    }

    Future<void> pump(WidgetTester tester, {double maxHeight = 300}) =>
        tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: V2Localizations.localizationsDelegates,
            supportedLocales: V2Localizations.supportedLocales,
            home: Scaffold(
              body: SessionPermissionCards(live: live, maxHeight: maxHeight),
            ),
          ),
        );

    SessionLiveView view(List<InteractionRequest> interactions, {bool stale = false}) =>
        SessionLiveView(
          session: ref,
          phase: SessionLivePhase.live,
          stale: stale,
          state: liveState(ref, interactions: interactions),
        );

    setUp(() async {
      rig = CatalogRig();
      await rig.save('a');
      await rig.sessions.initialize();
      directory = LiveDirectory();
      final summary = CatalogSource(profile('a')).row('one');
      ref = summary.info.ref;
      live = SessionLiveController(
        hosts: rig.hosts,
        profile: profile('a'),
        summary: summary,
        directory: directory,
      );
    });
    tearDown(() {
      live.dispose();
      rig.dispose();
    });

    testWidgets('a lease without a reply port keeps the read-only contract', (
      tester,
    ) async {
      await open([_ask(ref, 'per_1')], replyPort: false);
      await pump(tester);
      expect(
        find.byKey(const ValueKey('live-permission-per_1')),
        findsNothing,
      );
    });

    testWidgets('always is offered only with a nonempty native preview', (
      tester,
    ) async {
      await open([
        _ask(ref, 'per_1', choices: [_once(), _always(['src/**'])]),
      ]);
      await pump(tester);
      final always = find.byKey(const ValueKey('live-permission-always-per_1'));
      expect(always, findsOneWidget);
      expect(find.text('src/**'), findsOneWidget);
    });

    testWidgets('an empty note never sends; text enables the send', (
      tester,
    ) async {
      await open([_ask(ref, 'per_1')]);
      await pump(tester);
      await tester.tap(
        find.byKey(const ValueKey('live-permission-reject-note-per_1')),
      );
      await tester.pump();
      final send = find.byKey(
        const ValueKey('live-permission-note-send-per_1'),
      );
      expect(tester.widget<FilledButton>(send).onPressed, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('live-permission-note-per_1')),
        'why',
      );
      await tester.pump();
      expect(tester.widget<FilledButton>(send).onPressed, isNotNull);
      expect(handle.replies, isEmpty);
    });

    testWidgets('a stale lease keeps the card, its note and disables actions', (
      tester,
    ) async {
      await open([_ask(ref, 'per_1')]);
      await pump(tester);
      await tester.tap(
        find.byKey(const ValueKey('live-permission-reject-note-per_1')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('live-permission-note-per_1')),
        'keep me',
      );
      await tester.pump();

      handle.emit(view([_ask(ref, 'per_1')], stale: true));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('live-permission-per_1')),
        findsOneWidget,
      );
      expect(find.text('keep me'), findsOneWidget);
      for (final key in [
        'live-permission-allow-per_1',
        'live-permission-reject-stop-per_1',
        'live-permission-note-send-per_1',
      ]) {
        expect(
          tester.widget<ButtonStyleButton>(find.byKey(ValueKey(key))).onPressed,
          isNull,
          reason: key,
        );
      }
      expect(handle.replies, isEmpty);
    });

    testWidgets('reject and stop sends a note-less reject without Stop', (
      tester,
    ) async {
      await open([_ask(ref, 'per_1')]);
      await pump(tester);
      await tester.tap(
        find.byKey(const ValueKey('live-permission-reject-stop-per_1')),
      );
      await tester.pump();
      await tester.pump();
      expect(handle.replies, hasLength(1));
      expect(handle.replies.single.$2, 'reject');
      expect(handle.replies.single.$3, isNull);
      expect(handle.stops, isEmpty);
    });

    testWidgets('a short body keeps the footer inside its budget', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 240);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: V2Localizations.localizationsDelegates,
          supportedLocales: V2Localizations.supportedLocales,
          home: SessionLivePage(controller: live),
        ),
      );
      await tester.pump();
      handle = directory.grant(ref);
      handle.replyAvailable = true;
      await tester.pump();
      handle.emit(
        SessionLiveView(
          session: ref,
          phase: SessionLivePhase.live,
          lastSyncedAt: DateTime.utc(2026, 10, 15, 12),
          state: liveState(ref, interactions: [_ask(ref, 'per_1')]),
        ),
      );
      await _settleFrames(tester);
      for (final key in [
        'live-permission-per_1',
        'live-permission-allow-per_1',
        'live-permission-reject-note-per_1',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty save pattern is not offered as always', (
      tester,
    ) async {
      await open([
        _ask(ref, 'per_1', choices: [_once(), _always(const [''])]),
      ]);
      await pump(tester);
      expect(
        find.byKey(const ValueKey('live-permission-always-per_1')),
        findsNothing,
      );
      // One non-native choice poisons the request for the reply client, so no
      // action is offered at all.
      expect(
        find.byKey(const ValueKey('live-permission-allow-per_1')),
        findsNothing,
      );
    });

    testWidgets('the note editor needs a reject that accepts notes', (
      tester,
    ) async {
      await open([
        _ask(
          ref,
          'per_1',
          choices: [
            _once(),
            ApprovalChoice(
              id: 'reject',
              label: 'reject',
              allows: false,
              scope: const OpenValue.known(ApprovalScope.once),
              resolutionScope: const OpenValue.known(ResolutionScope.session),
            ),
          ],
        ),
      ]);
      await pump(tester);
      expect(
        find.byKey(const ValueKey('live-permission-reject-note-per_1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('live-permission-reject-stop-per_1')),
        findsNothing,
      );
      // A request carrying a non-native choice is refused end to end by the
      // reply client, so no action is offered, not even the native allow.
      expect(
        find.byKey(const ValueKey('live-permission-allow-per_1')),
        findsNothing,
      );
    });

    testWidgets('a refused Stop notice does not overflow the short footer', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 240);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: V2Localizations.localizationsDelegates,
          supportedLocales: V2Localizations.supportedLocales,
          home: SessionLivePage(controller: live),
        ),
      );
      await tester.pump();
      // No outbox: the footer renders the Stop notice beside the cards.
      handle = directory.grant(ref);
      handle.replyAvailable = true;
      handle.stopState = const SessionStopState(phase: SessionStopPhase.refused);
      await tester.pump();
      handle.emit(
        SessionLiveView(
          session: ref,
          phase: SessionLivePhase.live,
          lastSyncedAt: DateTime.utc(2026, 10, 15, 12),
          state: liveState(ref, interactions: [_ask(ref, 'per_1')]),
        ),
      );
      await _settleFrames(tester);
      expect(
        find.byKey(const ValueKey('live-permission-per_1')),
        findsOneWidget,
      );
      expect(find.text(V2LocalizationsEn().liveStopFailed), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a mixed save preview offers nothing, like the client', (
      tester,
    ) async {
      await open([
        _ask(ref, 'per_1', choices: [_once(), _always(['src/**', ''])]),
      ]);
      await pump(tester);
      expect(
        find.byKey(const ValueKey('live-permission-always-per_1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('live-permission-allow-per_1')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('live-permission-per_1')), findsOneWidget);
    });

    testWidgets('a hydrating card body keeps the footer bounded', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 240);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: V2Localizations.localizationsDelegates,
          supportedLocales: V2Localizations.supportedLocales,
          home: SessionLivePage(controller: live),
        ),
      );
      await tester.pump();
      handle = directory.grant(ref);
      handle.replyAvailable = true;
      await tester.pump();
      handle.emit(
        SessionLiveView(
          session: ref,
          // Loading renders the 4px bar the footer shares its column with.
          phase: SessionLivePhase.hydrating,
          lastSyncedAt: DateTime.utc(2026, 10, 15, 12),
          state: liveState(ref, interactions: [_ask(ref, 'per_1')]),
        ),
      );
      await _settleFrames(tester);
      expect(
        find.byKey(const ValueKey('live-permission-per_1')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('resources render as chips with an overflow marker', (
      tester,
    ) async {
      await open([
        _ask(
          ref,
          'per_1',
          subject: {
            'resources': ['a', 'b', 'c', 'd', 'e', 'f'],
          },
        ),
      ]);
      await pump(tester);
      for (final resource in ['a', 'b', 'c', 'd', 'e']) {
        expect(find.text(resource), findsOneWidget, reason: resource);
      }
      expect(find.text('+1'), findsOneWidget);
    });

    testWidgets('a typed note survives a lease re-open and dies with the request', (
      tester,
    ) async {
      await open([_ask(ref, 'per_1')]);
      await pump(tester);
      await tester.tap(
        find.byKey(const ValueKey('live-permission-reject-note-per_1')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('live-permission-note-per_1')),
        'keep me',
      );
      await tester.pump();
      expect(live.permissionNote(const InteractionId('per_1')), 'keep me');

      handle.emit(
        SessionLiveView(session: ref, phase: SessionLivePhase.connecting),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('live-permission-per_1')),
        findsNothing,
      );

      handle.emit(view([_ask(ref, 'per_1')]));
      await tester.pump();
      expect(find.text('keep me'), findsOneWidget);

      handle.emit(view(const []));
      await tester.pump();
      expect(live.permissionNote(const InteractionId('per_1')), isEmpty);
    });

    for (final size in [const Size(390, 844), const Size(1280, 800)]) {
      testWidgets('a pending card leaves the composer usable at $size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: V2Localizations.localizationsDelegates,
            supportedLocales: V2Localizations.supportedLocales,
            home: SessionLivePage(controller: live),
          ),
        );
        await tester.pump();
        handle = directory.grant(ref, outbox: FakeOutbox());
        handle.replyAvailable = true;
        await tester.pump();
        handle.emit(
          SessionLiveView(
            session: ref,
            phase: SessionLivePhase.live,
            lastSyncedAt: DateTime.utc(2026, 10, 15, 12),
            state: liveState(ref, interactions: [_ask(ref, 'per_1')]),
          ),
        );
        await _settleFrames(tester);
        expect(
          find.byKey(const ValueKey('live-permission-per_1')),
          findsOneWidget,
        );
        final input = find.byKey(const ValueKey('live-composer-input'));
        expect(input, findsOneWidget);
        // The field's own laid-out height stays positive even when its viewport
        // is clipped, so assert the composer's owned height and hittability.
        expect(
          tester.getSize(find.byType(SessionComposer)).height,
          greaterThanOrEqualTo(56),
        );
        await tester.tap(input);
        expect(find.text(V2LocalizationsEn().composerLiveSession), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    for (final locale in [const Locale('en'), const Locale('ar')]) {
      testWidgets('manual permission cards $size/${locale.languageCode}', (
        tester,
      ) async {
        final mounted = await _mountLivePage(
          tester,
          size: size,
          locale: locale,
        );
        final rig = mounted.rig;
        final ref = mounted.ref;
        final handle = mounted.handle;
        final l10n = mounted.l10n;
        handle.emit(
          SessionLiveView(
            session: ref,
            phase: SessionLivePhase.live,
            lastSyncedAt: DateTime.utc(2026, 10, 15, 12),
            state: liveState(
              ref,
              interactions: [_ask(ref, 'per_1'), _ask(ref, 'per_2')],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('live-permission-per_1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('live-permission-per_2')),
          findsOneWidget,
        );
        expect(find.text(l10n.livePermissionBatchScope), findsNWidgets(2));
        expect(find.text(l10n.liveNeedsYou), findsOneWidget);
        expect(
          Directionality.of(tester.element(find.byType(SessionLivePage))),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );

        await tester.ensureVisible(
          find.byKey(const ValueKey('live-permission-allow-per_1')),
        );
        await tester.tap(
          find.byKey(const ValueKey('live-permission-allow-per_1')),
        );
        await _settleFrames(tester);
        expect(handle.replies, hasLength(1));
        expect(handle.replies.single.$2, 'once');
        expect(handle.replies.single.$3, isNull);
        final pageController = tester
            .widget<SessionLivePage>(find.byType(SessionLivePage))
            .controller;
        expect(
          pageController.replyState(const InteractionId('per_1')).phase,
          SessionPermissionReplyPhase.requested,
        );
        expect(
          find.byType(LinearProgressIndicator).evaluate().isNotEmpty,
          isTrue,
          reason: 'a rebuild must have happened after the tap',
        );
        expect(find.text('read src/file.txt'), findsNWidgets(2));

        await tester.ensureVisible(
          find.byKey(const ValueKey('live-permission-reject-note-per_2')),
        );
        await tester.tap(
          find.byKey(const ValueKey('live-permission-reject-note-per_2')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.enterText(
          find.byKey(const ValueKey('live-permission-note-per_2')),
          '  fix it  ',
        );
        await tester.pump();
        await tester.ensureVisible(
          find.byKey(const ValueKey('live-permission-note-send-per_2')),
        );
        await tester.tap(
          find.byKey(const ValueKey('live-permission-note-send-per_2')),
        );
        await _settleFrames(tester);
        expect(handle.replies, hasLength(2));
        expect(handle.replies.last.$2, 'reject');
        expect(handle.replies.last.$3, '  fix it  ');
        handle.emit(
          SessionLiveView(
            session: ref,
            phase: SessionLivePhase.live,
            lastSyncedAt: DateTime.utc(2026, 10, 15, 12),
            state: liveState(ref),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('live-permission-per_1')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        rig.dispose();
      });
    }
  }
}
