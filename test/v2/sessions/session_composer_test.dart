import 'dart:async';
import 'dart:math';

import 'package:codewalk/features/sessions/session_composer_controller.dart';
import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/platform/sessions/prompt_outbox_store.dart';
import 'package:codewalk/shared/sessions/prompt_outbox.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_selection.dart';
import 'package:codewalk/shared/sessions/session_stop.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harness_opencode/harness_opencode.dart';

import 'composer_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';
import 'outbox_fakes.dart';

OutboxEntry _with(
  OutboxEntry e, {
  SubmissionKind? state,
  CancellationFence? fence,
  Delivery? delivery,
  String? reason,
}) => entryOf(
  e.session,
  e.commandId.value,
  e.messageId,
  e.text,
  delivery ?? e.delivery,
  state ?? e.state,
  reason: reason,
  fence: fence ?? e.fence,
);

SessionState withPending(SessionRef ref, List<PendingInput> pending) =>
    liveState(ref, pending: pending);

void main() {
  late CatalogRig rig;
  late LiveDirectory directory;
  late SessionLiveController live;
  late SessionComposerController composer;
  late SessionRef ref;
  late LiveHandle handle;
  var commands = 0;

  Future<void> open(PromptOutbox? outbox, {SessionState? state}) async {
    final opening = live.start();
    handle = directory.grant(ref, outbox: outbox);
    await opening;
    handle.emit(
      SessionLiveView(
        session: ref,
        phase: SessionLivePhase.live,
        lastSyncedAt: DateTime.utc(2026, 10, 15),
        state: state ?? liveState(ref),
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
    live = SessionLiveController(
      hosts: rig.hosts,
      profile: profile('a'),
      summary: summary,
      directory: directory,
    );
    commands = 0;
    composer = SessionComposerController(
      live: live,
      commandIds: () => CommandId('cmd_${++commands}'),
    );
  });
  tearDown(() {
    composer.dispose();
    live.dispose();
    rig.dispose();
  });

  group('sending', () {
    test(
      'Stop fences new sends without writing or clearing the prompt ledger',
      () async {
        final outbox = FakeOutbox();
        await open(
          outbox,
          state: liveState(
            ref,
            execution: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.running),
            ),
          ),
        );
        handle.stopAvailable = true;
        final pending = Completer<SessionStopState>();
        handle.stopAction = (_) => pending.future;
        final stop = live.stopCurrentTurn();
        expect(composer.canSend, isFalse);
        expect(await composer.send('keep this draft'), isFalse);
        expect(outbox.calls, isEmpty);
        pending.complete(
          const SessionStopState(phase: SessionStopPhase.unconfirmed),
        );
        await stop;
        expect(composer.canSend, isTrue);
      },
    );
    test('no outbox keeps the screen read-only', () async {
      await open(null);
      expect(composer.available, isFalse);
      expect(composer.canSend, isFalse);
      expect(await composer.send('hi'), isFalse);
    });

    test(
      'steer by default, queue only when picked, one command each',
      () async {
        final outbox = FakeOutbox();
        await open(outbox);
        expect(composer.delivery, Delivery.steer);
        expect(await composer.send('  hi\n'), isTrue);
        composer.setDelivery(Delivery.queue);
        expect(await composer.send('hi'), isTrue);
        expect(composer.delivery, Delivery.steer);
        expect(await composer.send('   '), isFalse);
        expect(outbox.calls, [
          'submit cmd_1 steer   hi\n',
          'submit cmd_2 queue hi',
        ]);
        composer.setDelivery(Delivery.immediate);
        expect(composer.delivery, Delivery.steer);
      },
    );

    test('a second tap while sending sends nothing', () async {
      final outbox = FakeOutbox()..holdSubmit = Completer();
      await open(outbox);
      final first = composer.send('hi');
      await pumpEventQueue();
      expect(composer.sending, isTrue);
      expect(await composer.send('hi'), isFalse);
      outbox.holdSubmit!.complete();
      expect(await first, isTrue);
      expect(outbox.calls.where((c) => c.startsWith('submit')), hasLength(1));
    });

    test('a refusal keeps the draft and the ledger', () async {
      final outbox = FakeOutbox()..submitRefusal = 'full';
      await open(outbox);
      expect(await composer.send('hi'), isFalse);
      expect(composer.notice, ComposerNotice.full);
      expect(outbox.calls.where((c) => c.startsWith('dismiss')), isEmpty);
    });

    test('a rejection keeps the draft and forgets the entry', () async {
      final outbox = FakeOutbox()
        ..submitState = SubmissionKind.rejected
        ..submitReason = 'ConflictError';
      await open(outbox);
      expect(await composer.send('hi'), isFalse);
      expect(composer.notice, ComposerNotice.conflict);
      expect(outbox.calls, ['submit cmd_1 steer hi', 'dismiss cmd_1']);
      expect(composer.entries, isEmpty);
    });

    test('a fresh uncertain send is checked once, then by the user', () async {
      final outbox = FakeOutbox()..submitState = SubmissionKind.uncertain;
      await open(outbox);
      expect(await composer.send('hi'), isTrue);
      expect(outbox.calls, ['submit cmd_1 steer hi', 'reconcile cmd_1']);
      expect(composer.notice, ComposerNotice.unconfirmed);
      expect(
        composer.rows(live.state).single.commandId,
        const CommandId('cmd_1'),
      );
    });

    test(
      'the text cannot be sent again while its uncertain send is checked',
      () async {
        final outbox = FakeOutbox()
          ..submitState = SubmissionKind.uncertain
          ..holdReconcile = Completer();
        await open(outbox);
        final first = composer.send('hi');
        await pumpEventQueue();
        expect(outbox.calls, ['submit cmd_1 steer hi', 'reconcile cmd_1']);
        expect(composer.sending, isTrue);
        expect(composer.canSend, isFalse);
        expect(await composer.send('hi'), isFalse);
        outbox.holdReconcile!.complete();
        expect(await first, isTrue);
        expect(composer.sending, isFalse);
        expect(outbox.calls.where((c) => c.startsWith('submit')), hasLength(1));
      },
    );

    test('a check that ends rejected keeps the draft', () async {
      final outbox = FakeOutbox()
        ..submitState = SubmissionKind.uncertain
        ..onReconcile = (e) => _with(
          e,
          state: SubmissionKind.rejected,
          reason: 'InvalidRequestError',
        );
      await open(outbox);
      expect(await composer.send('hi'), isFalse);
      expect(composer.notice, ComposerNotice.rejected);
      expect(outbox.calls.last, 'dismiss cmd_1');
      expect(composer.entries, isEmpty);
    });

    test('a queue choice made during a send is kept for the next', () async {
      final outbox = FakeOutbox()..holdSubmit = Completer();
      await open(outbox);
      final first = composer.send('hi');
      await pumpEventQueue();
      composer.setDelivery(Delivery.queue);
      outbox.holdSubmit!.complete();
      await first;
      expect(composer.delivery, Delivery.queue);
    });

    test(
      'a rejected check keeps the draft even if the ledger read fails',
      () async {
        late FakeOutbox outbox;
        outbox = FakeOutbox()
          ..submitState = SubmissionKind.uncertain
          ..onReconcile = (e) {
            outbox.entriesError = StateError('unreadable');
            return _with(e, state: SubmissionKind.rejected);
          };
        await open(outbox);
        expect(await composer.send('hi'), isFalse);
        expect(outbox.calls.last, 'dismiss cmd_1');
      },
    );

    test('a send that ends after dispose reports nothing to clear', () async {
      final outbox = FakeOutbox()
        ..submitState = SubmissionKind.uncertain
        ..holdReconcile = Completer();
      await open(outbox);
      final first = composer.send('hi');
      await pumpEventQueue();
      composer.dispose();
      outbox.holdReconcile!.complete();
      expect(await first, isFalse);
    });

    test('a check that ends rejected keeps the queue choice', () async {
      final outbox = FakeOutbox()
        ..submitState = SubmissionKind.uncertain
        ..onReconcile = (e) => _with(e, state: SubmissionKind.rejected);
      await open(outbox);
      composer.setDelivery(Delivery.queue);
      expect(await composer.send('hi'), isFalse);
      expect(composer.delivery, Delivery.queue);
    });

    test(
      'a lease reopened during a send still clears the posted text',
      () async {
        final outbox = FakeOutbox()..holdSubmit = Completer();
        await open(outbox);
        final first = composer.send('hi');
        await pumpEventQueue();
        handle.outbox = null;
        handle.emit(handle.current);
        await pumpEventQueue();
        expect(composer.available, isFalse);
        expect(composer.sending, isTrue);
        outbox.holdSubmit!.complete();
        expect(await first, isTrue);
      },
    );

    test('a send refused as unreadable offers the re-read', () async {
      final outbox = FakeOutbox()..submitRefusal = 'unreadable';
      await open(outbox);
      expect(await composer.send('hi'), isFalse);
      expect(composer.unreadable, isTrue);
      expect(composer.canSend, isFalse);
    });

    test('a ledger that reads again re-enables sending', () async {
      final outbox = FakeOutbox()..entriesError = StateError('unreadable');
      await open(outbox);
      expect(composer.unreadable, isTrue);
      outbox.entriesError = null;
      await composer.reload();
      expect(composer.unreadable, isFalse);
      expect(composer.notice, ComposerNotice.none);
      expect(composer.canSend, isTrue);
    });

    test('restored uncertain entries are never checked on open', () async {
      final outbox = FakeOutbox()
        ..list.add(
          entryOf(
            ref,
            'old',
            'msg_0001',
            'hi',
            Delivery.steer,
            SubmissionKind.uncertain,
            reason: 'interrupted',
          ),
        );
      await open(outbox);
      expect(outbox.calls, isEmpty);
      expect(composer.rows(live.state), hasLength(1));
      await composer.checkAgain(const CommandId('old'));
      expect(outbox.calls, ['reconcile old']);
    });

    test('send again forgets the old command before a new one', () async {
      final outbox = FakeOutbox()
        ..list.addAll([
          entryOf(
            ref,
            'old',
            'msg_0009',
            'hi',
            Delivery.queue,
            SubmissionKind.uncertain,
            reason: 'replayExhausted',
          ),
          entryOf(
            ref,
            'old2',
            'msg_0010',
            'x',
            Delivery.steer,
            SubmissionKind.uncertain,
          ),
        ]);
      await open(outbox);
      await composer.sendAgain(const CommandId('old'));
      expect(outbox.calls, ['dismiss old', 'submit cmd_1 queue hi']);
      outbox
        ..calls.clear()
        ..dismissOk = false;
      await composer.sendAgain(const CommandId('old2'));
      expect(outbox.calls, ['dismiss old2']);
      expect(composer.notice, ComposerNotice.notSaved);
    });

    test('send again gives the text back when the new send fails', () async {
      final outbox = FakeOutbox()
        ..list.add(
          entryOf(
            ref,
            'old',
            'msg_0009',
            'keep me',
            Delivery.steer,
            SubmissionKind.uncertain,
          ),
        )
        ..submitState = SubmissionKind.rejected
        ..submitReason = 'RateLimited';
      await open(outbox);
      expect(await composer.sendAgain(const CommandId('old')), 'keep me');
      expect(composer.notice, ComposerNotice.rateLimited);
      outbox
        ..submitState = SubmissionKind.admitted
        ..list.add(
          entryOf(
            ref,
            'old2',
            'msg_0010',
            'x',
            Delivery.steer,
            SubmissionKind.uncertain,
          ),
        );
      await composer.discard(const CommandId('none'));
      expect(await composer.sendAgain(const CommandId('old2')), isNull);
    });

    test('send again holds the field from the start', () async {
      final outbox = FakeOutbox()
        ..list.add(
          entryOf(
            ref,
            'old',
            'msg_0009',
            'hi',
            Delivery.steer,
            SubmissionKind.uncertain,
          ),
        )
        ..holdDismiss = Completer();
      await open(outbox);
      final again = composer.sendAgain(const CommandId('old'));
      await pumpEventQueue();
      expect(composer.sending, isTrue);
      expect(await composer.send('other'), isFalse);
      outbox.holdDismiss!.complete();
      expect(await again, isNull);
      expect(composer.sending, isFalse);
      expect(outbox.calls, ['dismiss old', 'submit cmd_1 steer hi']);
    });

    test(
      'send again hands the text back when the lease was reopened',
      () async {
        final outbox = FakeOutbox()
          ..list.add(
            entryOf(
              ref,
              'old',
              'msg_0009',
              'hi',
              Delivery.steer,
              SubmissionKind.uncertain,
            ),
          )
          ..holdDismiss = Completer();
        await open(outbox);
        final again = composer.sendAgain(const CommandId('old'));
        await pumpEventQueue();
        handle.outbox = FakeOutbox();
        handle.emit(handle.current);
        await pumpEventQueue();
        outbox.holdDismiss!.complete();
        expect(await again, 'hi');
        expect(outbox.calls, ['dismiss old']);
      },
    );

    test('checking an open cancel that lost to delivery says so', () async {
      final outbox = FakeOutbox()
        ..list.add(
          entryOf(
            ref,
            'c',
            'msg_0003',
            'c',
            Delivery.queue,
            SubmissionKind.admitted,
            fence: CancellationFence.uncertain,
          ),
        )
        ..onReconcile = (e) => _with(
          e,
          state: SubmissionKind.delivered,
          fence: CancellationFence.settled,
        );
      await open(outbox);
      await composer.checkAgain(const CommandId('c'));
      expect(composer.notice, ComposerNotice.deliveredFirst);
    });

    test(
      'sending waits for a live, current view and a readable ledger',
      () async {
        final outbox = FakeOutbox();
        await open(outbox);
        expect(composer.canSend, isTrue);
        handle.emit(
          SessionLiveView(
            session: ref,
            phase: SessionLivePhase.reconnecting,
            lastSyncedAt: DateTime.utc(2026, 10, 15),
            stale: true,
            state: liveState(ref),
          ),
        );
        await pumpEventQueue();
        expect(composer.canSend, isFalse);
        expect(await composer.send('hi'), isFalse);
        expect(outbox.calls, isEmpty);
      },
    );

    test('a pending or unconfirmed model change holds sending', () async {
      final outbox = FakeOutbox();
      await open(outbox);
      expect(composer.canSend, isTrue);
      for (final phase in [
        SessionSelectionPhase.pending,
        SessionSelectionPhase.unconfirmed,
      ]) {
        handle.selectionState = SessionSelectionState(phase: phase);
        handle.emit(handle.current);
        await pumpEventQueue();
        expect(composer.canSend, isFalse, reason: phase.name);
        expect(await composer.send('hi'), isFalse);
      }
      expect(outbox.calls, isEmpty);
      handle.selectionState = const SessionSelectionState();
      handle.emit(handle.current);
      await pumpEventQueue();
      expect(composer.canSend, isTrue);
    });

    test('an unreadable ledger disables sending', () async {
      final outbox = FakeOutbox()..entriesError = StateError('unreadable');
      await open(outbox);
      expect(composer.unreadable, isTrue);
      expect(composer.notice, ComposerNotice.unreadable);
      expect(composer.canSend, isFalse);
    });
  });

  group('inbox chips', () {
    test(
      'own admitted rows can be cancelled or switched; others cannot',
      () async {
        final outbox = FakeOutbox()
          ..list.add(
            entryOf(
              ref,
              'mine',
              'msg_0001',
              'mine',
              Delivery.queue,
              SubmissionKind.admitted,
            ),
          );
        await open(
          outbox,
          state: withPending(ref, [
            pendingRow(ref, 'msg_0001', 'mine'),
            pendingRow(ref, 'msg_0002', 'theirs'),
          ]),
        );
        final chips = composer.chips(live.state);
        expect(chips, hasLength(2));
        expect(chips.first.entry?.commandId, const CommandId('mine'));
        expect(canCancel(chips.first.entry!), isTrue);
        expect(canSwitch(chips.first.entry!), isTrue);
        expect(chips.last.entry, isNull);
        expect(composer.rows(live.state), isEmpty);
      },
    );

    test('a cancel shows what the server shows', () async {
      final outbox = FakeOutbox()
        ..list.addAll([
          entryOf(
            ref,
            'a',
            'msg_0001',
            'a',
            Delivery.queue,
            SubmissionKind.admitted,
          ),
          entryOf(
            ref,
            'b',
            'msg_0002',
            'b',
            Delivery.queue,
            SubmissionKind.admitted,
          ),
          entryOf(
            ref,
            'c',
            'msg_0003',
            'c',
            Delivery.queue,
            SubmissionKind.admitted,
          ),
        ]);
      await open(outbox);
      outbox.onCancel = (e) => _with(
        e,
        state: SubmissionKind.delivered,
        fence: CancellationFence.settled,
      );
      await composer.cancel(const CommandId('a'));
      expect(composer.notice, ComposerNotice.deliveredFirst);
      outbox.onCancel = (e) => _with(
        e,
        state: SubmissionKind.cancelled,
        fence: CancellationFence.cancelled,
      );
      await composer.cancel(const CommandId('b'));
      expect(composer.notice, ComposerNotice.cancelled);
      outbox.onCancel = (e) => _with(e, fence: CancellationFence.uncertain);
      await composer.cancel(const CommandId('c'));
      expect(composer.notice, ComposerNotice.cancelPending);
      final pending = composer.rows(live.state).single;
      expect(pending.commandId, const CommandId('c'));
      expect(canCancel(pending), isFalse);
    });

    test('a switch reports the delivery the server shows', () async {
      final outbox = FakeOutbox()
        ..list.add(
          entryOf(
            ref,
            'a',
            'msg_0001',
            'a',
            Delivery.queue,
            SubmissionKind.admitted,
          ),
        );
      await open(outbox);
      outbox.onSwitch = (e, d) => _with(e, delivery: d);
      await composer.switchDelivery(const CommandId('a'), Delivery.steer);
      expect(outbox.calls, ['switch a steer']);
      expect(composer.notice, ComposerNotice.switched);
      outbox.onSwitch = (e, _) =>
          _with(e, state: SubmissionKind.delivered, reason: 'ConflictError');
      await composer.switchDelivery(const CommandId('a'), Delivery.queue);
      expect(composer.notice, ComposerNotice.switchNotApplied);
    });
  });

  group('parent criteria on the real outbox', () {
    late OutboxServer server;
    late OpenCodePromptOutbox outbox;

    setUp(() {
      server = OutboxServer();
      outbox = OpenCodePromptOutbox(
        store: OutboxStore(),
        client: OpenCodePromptClient(
          server.transport,
          harness: ref.harnessRef,
          connectedVersion: '2.0.22',
          deadline: const Duration(milliseconds: 200),
        ),
        reader: OpenCodeSessionReader(
          server.transport,
          harness: ref.harnessRef,
        ),
        ids: OpenCodeMessageIds(random: Random(1)),
        wait: (_) async {},
      );
    });

    test('a timeout after admission ends as one admitted message', () async {
      await open(outbox);
      server.loseResponse = true;
      expect(await composer.send('Hello'), isTrue);
      expect(server.transport.bodies, hasLength(1));
      expect(server.inbox, hasLength(1));
      expect(composer.entries.single.state, SubmissionKind.admitted);
      expect(composer.notice, ComposerNotice.none);
    });

    test('the same text sent twice is two messages', () async {
      await open(outbox);
      await composer.send('Hello');
      await composer.send('Hello');
      final ids = [for (final b in server.transport.bodies) b['id']];
      expect(ids.toSet(), hasLength(2));
      expect(server.inbox, hasLength(2));
      expect(composer.entries, hasLength(2));
    });

    test('a cancel racing delivery shows the delivery', () async {
      await open(outbox);
      composer.setDelivery(Delivery.queue);
      await composer.send('Later');
      final entry = composer.entries.single;
      server.beforeChange = () => server.promote(entry.messageId);
      await composer.cancel(entry.commandId);
      expect(composer.notice, ComposerNotice.deliveredFirst);
      expect(composer.entries.single.state, SubmissionKind.delivered);
      expect(server.transport.bodies, hasLength(1));
    });

    test('a cancel that wins shows the cancellation', () async {
      await open(outbox);
      composer.setDelivery(Delivery.queue);
      await composer.send('Later');
      await composer.cancel(composer.entries.single.commandId);
      expect(composer.notice, ComposerNotice.cancelled);
      expect(server.inbox, isEmpty);
    });
  });
}
