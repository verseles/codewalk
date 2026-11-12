import 'dart:async';

import 'package:codewalk/features/sessions/session_composer.dart';
import 'package:codewalk/features/sessions/session_composer_controller.dart';
import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/platform/sessions/session_draft_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/platform/storage/payload_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/prompt_outbox.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';
import 'composer_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';

/// Messages the harness holds but has not taken yet (#486).
void main() {
  late CatalogRig rig;
  late SessionLiveController live;
  late FakeOutbox outbox;
  late V2Localizations l10n;

  setUp(() async {
    SessionComposerController.clearHandOffs();
    rig = CatalogRig();
    await rig.save('a');
    await rig.sessions.initialize();
    outbox = FakeOutbox();
  });

  tearDown(() => rig.dispose());

  /// The session's own draft, which the live page gives its composer.
  TextEditingController text() => live.draft;

  OutboxEntry mine(String command, String message, String body) => entryOf(
    live.session,
    command,
    message,
    body,
    Delivery.queue,
    SubmissionKind.admitted,
  );

  /// [entry] after the harness answered, keeping what the ledger recorded.
  OutboxEntry settled(
    OutboxEntry entry,
    SubmissionKind state,
    CancellationFence fence,
  ) => entryOf(
    live.session,
    entry.commandId.value,
    entry.messageId,
    entry.text,
    entry.delivery,
    state,
    fence: fence,
    takenBack: entry.takenBack,
  );

  /// The composer of a live session holding [pending], this device having
  /// sent [entries].
  Future<void> open(
    WidgetTester tester, {
    required List<(String, String)> pending,
    List<OutboxEntry> Function()? entries,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final directory = LiveDirectory();
    final summary = CatalogSource(profile('a')).row('one');
    live = SessionLiveController(
      hosts: rig.hosts,
      profile: profile('a'),
      summary: summary,
      directory: directory,
    );
    addTearDown(live.dispose);
    outbox.list.addAll(entries?.call() ?? const []);
    final opening = live.start();
    final handle = directory.grant(live.session, outbox: outbox);
    await opening;
    handle.emit(
      SessionLiveView(
        session: live.session,
        phase: SessionLivePhase.live,
        lastSyncedAt: DateTime.utc(2026, 11, 12),
        state: liveState(
          live.session,
          pending: [
            for (final (message, body) in pending)
              pendingRow(live.session, message, body),
          ],
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: V2Localizations.localizationsDelegates,
        supportedLocales: V2Localizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SessionComposer(
              controller: live.composer,
              text: live.draft,
              maxHeight: 600,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    l10n = V2Localizations.of(tester.element(find.byType(SessionComposer)));
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  Finder line(String body) => find.ancestor(
    of: find.textContaining(body),
    matching: find.byType(InkWell),
  );

  testWidgets('a waiting message is one line with cancel and send now', (
    tester,
  ) async {
    final long = 'First line\n${'then a long tail ' * 20}END';
    await open(
      tester,
      pending: [('msg_0001', long), ('msg_0002', 'theirs')],
      entries: () => [mine('mine', 'msg_0001', long)],
    );
    expect(find.text(l10n.composerInbox), findsNothing);
    final shown = tester.widget<Text>(find.textContaining('First line'));
    expect(shown.maxLines, 1);
    expect(shown.overflow, TextOverflow.ellipsis);
    expect(shown.data, isNot(contains('\n')));
    expect(shown.data, endsWith('…'));
    expect(tester.getSize(line('First line')).height, lessThan(56));
    // Another client's message says so, with no action of this device.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip &&
            widget.message ==
                '${l10n.composerQueued} · ${l10n.composerOtherClient}',
      ),
      findsOneWidget,
    );
    expect(find.byTooltip(l10n.composerCancel), findsOneWidget);
    expect(find.byTooltip(l10n.composerSendNow), findsOneWidget);
    expect(find.byTooltip(l10n.composerMoveToQueue), findsNothing);
    await tester.tap(find.byKey(const ValueKey('live-waiting-send-mine')));
    await tester.pumpAndSettle();
    expect(outbox.calls, contains('switch mine steer'));
    await tester.tap(find.byKey(const ValueKey('live-waiting-cancel-mine')));
    await tester.pumpAndSettle();
    expect(outbox.calls, contains('cancel mine'));
  });

  testWidgets('a steering message offers no send now', (tester) async {
    await open(
      tester,
      pending: [('msg_0001', 'steering')],
      entries: () => [
        entryOf(
          live.session,
          'mine',
          'msg_0001',
          'steering',
          Delivery.steer,
          SubmissionKind.admitted,
        ),
      ],
    );
    expect(find.byTooltip(l10n.composerSteering), findsOneWidget);
    expect(find.byTooltip(l10n.composerSendNow), findsNothing);
    expect(find.byTooltip(l10n.composerCancel), findsOneWidget);
  });

  testWidgets('tapping it takes the text back only once cancelled', (
    tester,
  ) async {
    await open(
      tester,
      pending: [('msg_0001', 'fix the test'), ('msg_0002', 'run it')],
      entries: () => [
        mine('a', 'msg_0001', 'fix the test'),
        mine('b', 'msg_0002', 'run it'),
      ],
    );
    text().text = 'Typed';
    outbox.onCancel = (entry) =>
        settled(entry, SubmissionKind.cancelled, CancellationFence.cancelled);
    await tester.tap(line('fix the test'));
    await tester.pumpAndSettle();
    // The ledger records the take-back, then forgets the entry.
    expect(
      outbox.calls,
      containsAllInOrder(['cancel a takeBack', 'dismiss a']),
    );
    // Nothing typed is lost; the text follows it.
    expect(text().text, 'Typed\nfix the test');
    expect(live.composer.notice, ComposerNotice.none);
    // Delivered first: the text is not copied.
    outbox.onCancel = (entry) =>
        settled(entry, SubmissionKind.delivered, CancellationFence.settled);
    await tester.tap(line('run it'));
    await tester.pumpAndSettle();
    expect(outbox.calls, contains('cancel b takeBack'));
    expect(outbox.calls, isNot(contains('dismiss b')));
    expect(text().text, 'Typed\nfix the test');
    expect(live.composer.notice, ComposerNotice.deliveredFirst);
  });

  testWidgets('a harness that can neither steer nor cancel offers neither', (
    tester,
  ) async {
    outbox
      ..steersPending = false
      ..cancelsPending = false;
    await open(
      tester,
      pending: [('msg_0001', 'waits its turn')],
      entries: () => [mine('mine', 'msg_0001', 'waits its turn')],
    );
    expect(find.byTooltip(l10n.composerQueued), findsOneWidget);
    expect(find.byTooltip(l10n.composerSendNow), findsNothing);
    expect(find.byTooltip(l10n.composerCancel), findsNothing);
    await tester.tap(find.text('waits its turn'));
    await tester.pumpAndSettle();
    expect(outbox.calls.where((call) => call.startsWith('cancel')), isEmpty);
    expect(text().text, isEmpty);
  });

  testWidgets('past three messages the list scrolls, oldest on top', (
    tester,
  ) async {
    await open(
      tester,
      pending: [for (var i = 1; i <= 6; i++) ('msg_000$i', 'message $i')],
    );
    final box = tester.getSize(find.byKey(const ValueKey('live-waiting')));
    expect(box.height, lessThanOrEqualTo(132));
    expect(
      tester.getTopLeft(find.text('message 1')).dy,
      lessThan(tester.getTopLeft(find.text('message 2')).dy),
    );
    expect(find.text('message 6').hitTestable(), findsNothing);
  });

  testWidgets('a cancel that settles later still brings the text back once', (
    tester,
  ) async {
    await open(
      tester,
      pending: [('msg_0001', 'fix the test')],
      entries: () => [mine('a', 'msg_0001', 'fix the test')],
    );
    outbox.onCancel = (entry) =>
        settled(entry, SubmissionKind.admitted, CancellationFence.uncertain);
    await tester.tap(line('fix the test'));
    await tester.pumpAndSettle();
    // Unsettled: it stays waiting, says so and offers Check again.
    expect(text().text, isEmpty);
    expect(live.composer.notice, ComposerNotice.cancelPending);
    expect(find.byTooltip(l10n.composerCancelling), findsOneWidget);
    final check = find.byKey(const ValueKey('live-waiting-check-a'));
    expect(check, findsOneWidget);
    outbox.onReconcile = (entry) =>
        settled(entry, SubmissionKind.cancelled, CancellationFence.cancelled);
    await tester.tap(check);
    await tester.pumpAndSettle();
    expect(text().text, 'fix the test');
    // The text back in the field says it.
    expect(live.composer.notice, ComposerNotice.none);
    // Gone from the list before the harness says so.
    expect(line('fix the test'), findsNothing);
    // Once only, whatever reads it again.
    await live.composer.reload();
    await tester.pumpAndSettle();
    expect(text().text, 'fix the test');
  });

  testWidgets('a draft of spaces is kept before the taken-back text', (
    tester,
  ) async {
    await open(
      tester,
      pending: [('msg_0001', 'again')],
      entries: () => [mine('a', 'msg_0001', 'again')],
    );
    text().text = '  ';
    outbox.onCancel = (entry) =>
        settled(entry, SubmissionKind.cancelled, CancellationFence.cancelled);
    await tester.tap(line('again'));
    await tester.pumpAndSettle();
    expect(text().text, '  \nagain');
  });

  testWidgets('nothing is taken back while a send runs', (tester) async {
    await open(
      tester,
      pending: [('msg_0001', 'waiting')],
      entries: () => [mine('a', 'msg_0001', 'waiting')],
    );
    final hold = outbox.holdSubmit = Completer<void>();
    text().text = 'Hello';
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('live-composer-send')));
    await tester.pump();
    expect(live.composer.sending, isTrue);
    await tester.tap(line('waiting'), warnIfMissed: false);
    await tester.pump();
    expect(await live.composer.takeBack(const CommandId('a')), isFalse);
    expect(outbox.calls.where((call) => call.startsWith('cancel')), isEmpty);
    hold.complete();
    await tester.pumpAndSettle();
    expect(text().text, isEmpty);
  });

  /// A live session over [outbox] without a screen, its ledger read.
  Future<SessionLiveController> session() async {
    final directory = LiveDirectory();
    final opened = SessionLiveController(
      hosts: rig.hosts,
      profile: profile('a'),
      summary: CatalogSource(profile('a')).row('one'),
      directory: directory,
    );
    final opening = opened.start();
    directory.grant(opened.session, outbox: outbox);
    await opening;
    // The composer reads the ledger when it is first asked for.
    expect(opened.composer.available, isTrue);
    await pumpEventQueue();
    return opened;
  }

  test(
    'a take-back settled after the session closed returns on reopening',
    () async {
      live = await session();
      outbox.list.add(mine('a', 'msg_0001', 'keep me'));
      await live.composer.reload();
      outbox.onCancel = (entry) =>
          settled(entry, SubmissionKind.admitted, CancellationFence.uncertain);
      expect(await live.composer.takeBack(const CommandId('a')), isFalse);
      expect(live.draft.text, isEmpty);
      live.dispose();
      // Settled later, with no screen open.
      outbox.list.add(
        settled(
          outbox.list.removeAt(0),
          SubmissionKind.cancelled,
          CancellationFence.cancelled,
        ),
      );
      live = await session();
      addTearDown(live.dispose);
      expect(live.draft.text, 'keep me');
      expect(outbox.calls, contains('dismiss a'));
      expect(outbox.list, isEmpty);
      // A third view finds nothing left to put back.
      live.dispose();
      live = await session();
      expect(live.draft.text, isEmpty);
    },
  );

  testWidgets('a take-back settled during a send returns once it ends', (
    tester,
  ) async {
    await open(
      tester,
      pending: [('msg_0001', 'fix the test')],
      entries: () => [mine('a', 'msg_0001', 'fix the test')],
    );
    outbox.onCancel = (entry) =>
        settled(entry, SubmissionKind.admitted, CancellationFence.uncertain);
    await tester.tap(line('fix the test'));
    await tester.pumpAndSettle();
    final hold = outbox.holdSubmit = Completer<void>();
    text().text = 'Hello';
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('live-composer-send')));
    await tester.pump();
    expect(live.composer.sending, isTrue);
    outbox.onReconcile = (entry) =>
        settled(entry, SubmissionKind.cancelled, CancellationFence.cancelled);
    await tester.tap(find.byKey(const ValueKey('live-waiting-check-a')));
    await tester.pump();
    // The send still holds the field.
    expect(text().text, 'Hello');
    hold.complete();
    await tester.pumpAndSettle();
    // What was sent left; the taken-back text came back alone.
    expect(text().text, 'fix the test');
  });

  testWidgets('a line cut past 200 characters ends in an ellipsis', (
    tester,
  ) async {
    final exact = 'a' * 200;
    final over = 'b' * 201;
    await open(tester, pending: [('msg_0001', exact), ('msg_0002', over)]);
    expect(tester.widget<Text>(find.text(exact)).data, exact);
    expect(find.text('${'b' * 200}…'), findsOneWidget);
  });

  testWidgets(
    'a failed read after the ledger forgot it puts nothing back twice',
    (tester) async {
      await open(
        tester,
        pending: [('msg_0001', 'once')],
        entries: () => [mine('a', 'msg_0001', 'once')],
      );
      outbox.onCancel = (entry) =>
          settled(entry, SubmissionKind.cancelled, CancellationFence.cancelled);
      await tester.tap(line('once'));
      await tester.pumpAndSettle();
      expect(text().text, 'once');
      outbox.entriesError = StateError('unreadable');
      await live.composer.reload();
      live.notifyListeners();
      await tester.pumpAndSettle();
      expect(text().text, 'once');
    },
  );

  test(
    'a ledger that cannot forget it loses nothing, at most one more copy',
    () async {
      final device = FakeMetadataBackend();
      final metadata = V2MetadataStore(backend: device);
      final drafts = SessionDraftStore(
        payloads: PreferencesPayloadStore(metadata),
        index: metadata,
        delay: const Duration(milliseconds: 1),
      );
      Future<SessionLiveController> withDrafts() async {
        final directory = LiveDirectory();
        final opened = SessionLiveController(
          hosts: rig.hosts,
          profile: profile('a'),
          summary: CatalogSource(profile('a')).row('one'),
          directory: directory,
          drafts: drafts,
        );
        final opening = opened.start();
        directory.grant(opened.session, outbox: outbox);
        await opening;
        expect(opened.composer.available, isTrue);
        await pumpEventQueue();
        return opened;
      }

      outbox
        ..dismissOk = false
        ..list.add(
          withTakenBack(
            entryOf(
              CatalogSource(profile('a')).row('one').info.ref,
              'a',
              'msg_0001',
              'keep me',
              Delivery.queue,
              SubmissionKind.cancelled,
              fence: CancellationFence.cancelled,
            ),
          ),
        );
      live = await withDrafts();
      expect(live.draft.text, 'keep me');
      // Written with the draft before the ledger is asked to forget it.
      await pumpEventQueue();
      expect(await drafts.read(live.session), 'keep me');
      expect(outbox.calls, contains('dismiss a'));
      // Read again in this view: never put back twice here.
      await live.composer.reload();
      expect(live.draft.text, 'keep me');
      live.dispose();
      outbox.dismissOk = true;
      live = await withDrafts();
      await pumpEventQueue();
      expect(live.draft.text, 'keep me\nkeep me');
      expect(outbox.list, isEmpty);
      live.dispose();
      live = await withDrafts();
      addTearDown(live.dispose);
      expect(live.draft.text, 'keep me\nkeep me');
    },
  );

  test(
    'a view opened while another hands a take-back over adds no copy',
    () async {
      final device = FakeMetadataBackend();
      final metadata = V2MetadataStore(backend: device);
      final drafts = SessionDraftStore(
        payloads: PreferencesPayloadStore(metadata),
        index: metadata,
        delay: const Duration(milliseconds: 1),
      );
      Future<SessionLiveController> withDrafts() async {
        final directory = LiveDirectory();
        final opened = SessionLiveController(
          hosts: rig.hosts,
          profile: profile('a'),
          summary: CatalogSource(profile('a')).row('one'),
          directory: directory,
          drafts: drafts,
        );
        final opening = opened.start();
        directory.grant(opened.session, outbox: outbox);
        await opening;
        expect(opened.composer.available, isTrue);
        await pumpEventQueue();
        return opened;
      }

      final hold = outbox.holdDismiss = Completer<void>();
      outbox.list.add(
        withTakenBack(
          entryOf(
            CatalogSource(profile('a')).row('one').info.ref,
            'a',
            'msg_0001',
            'keep me',
            Delivery.queue,
            SubmissionKind.cancelled,
            fence: CancellationFence.cancelled,
          ),
        ),
      );
      live = await withDrafts();
      expect(live.draft.text, 'keep me');
      await pumpEventQueue();
      // Written, while the ledger has not forgotten it yet.
      expect(await drafts.read(live.session), 'keep me');
      live.dispose();
      live = await withDrafts();
      addTearDown(live.dispose);
      expect(live.draft.text, 'keep me');
      hold.complete();
      await pumpEventQueue();
      // A live change before any new read finds nothing owed here.
      live.notifyListeners();
      await pumpEventQueue();
      expect(live.draft.text, 'keep me');
      await live.composer.reload();
      expect(live.draft.text, 'keep me');
      expect(outbox.list, isEmpty);
    },
  );

  testWidgets('every take-back comes back, even the same text or a tail', (
    tester,
  ) async {
    await open(
      tester,
      pending: [
        ('msg_0001', 'run tests'),
        ('msg_0002', 'run tests'),
        ('msg_0003', 'again'),
      ],
      entries: () => [
        mine('a', 'msg_0001', 'run tests'),
        mine('b', 'msg_0002', 'run tests'),
        mine('c', 'msg_0003', 'again'),
      ],
    );
    text().text = 'do not run tests';
    outbox.onCancel = (entry) =>
        settled(entry, SubmissionKind.admitted, CancellationFence.uncertain);
    for (final command in ['a', 'b', 'c']) {
      expect(await live.composer.takeBack(CommandId(command)), isFalse);
    }
    // All three settle in one read.
    for (var i = 0; i < outbox.list.length; i++) {
      outbox.list[i] = settled(
        outbox.list[i],
        SubmissionKind.cancelled,
        CancellationFence.cancelled,
      );
    }
    await live.composer.reload();
    await tester.pumpAndSettle();
    expect(text().text, 'do not run tests\nrun tests\nrun tests\nagain');
    expect(outbox.list, isEmpty);
  });

  test('a harness that cannot cancel never sends one to take back', () async {
    outbox.cancelsPending = false;
    live = await session();
    addTearDown(live.dispose);
    outbox.list.add(mine('a', 'msg_0001', 'stays'));
    await live.composer.reload();
    expect(await live.composer.takeBack(const CommandId('a')), isFalse);
    expect(outbox.calls.where((call) => call.startsWith('cancel')), isEmpty);
  });
}
