import 'dart:convert';

import 'package:codewalk/features/sessions/session_builtin_commands.dart'
    as builtin;
import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/shared/sessions/session_turn_actions.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'live_fakes.dart';

final class _FakePort implements SessionTurnActionPort {
  @override
  SessionTurnState state = const SessionTurnState();
  SessionTurnUnavailable? refusal;
  final List<ItemId> staged = [];
  int redoNextCalls = 0;
  int redoAllCalls = 0;
  int compactCalls = 0;

  @override
  SessionTurnUnavailable? unavailable(SessionTurnAction action) => refusal;

  @override
  Future<SessionTurnResult> stage(ItemId boundary, {required CommandId id}) async {
    staged.add(boundary);
    state = SessionTurnState(
      phase: SessionTurnPhase.idle,
      revert: RevertState(
        kind: const OpenValue.known(RevertKind.staged),
        boundary: boundary,
        anchor: MessageAnchor(
          message: MessageRef('msg_target'),
          orderKey: 'msg_target',
        ),
      ),
    );
    return const SessionTurnResult(applied: true);
  }

  @override
  Future<SessionTurnResult> redoNext({required CommandId id}) async {
    redoNextCalls++;
    state = const SessionTurnState();
    return const SessionTurnResult(applied: true, cleared: true);
  }

  @override
  Future<SessionTurnResult> redoAll({required CommandId id}) async {
    redoAllCalls++;
    state = const SessionTurnState();
    return const SessionTurnResult(applied: true, cleared: true);
  }

  @override
  Future<SessionTurnResult> compact({required CommandId id}) async {
    compactCalls++;
    return const SessionTurnResult(applied: true);
  }

  @override
  Future<void> refresh() async {}
}

UserInput _turn(
  String message, {
  required SessionRef ref,
  String? text,
  bool confirmed = true,
}) =>
    UserInput(
      meta: ItemMeta(
        id: ItemId(jsonEncode([ref.storageKey, message, 'user', 0])),
        generation: 'history',
        status: const OpenValue.known(ItemStatus.completed),
        source: SourceProvenance(
          harness: ref.harnessRef,
          version: '2.0.22',
          nativeType: 'user',
        ),
        anchor: MessageAnchor(message: MessageRef(message), orderKey: message),
      ),
      text: text ?? 'text of $message',
      delivery: const OpenValue.known(DeliveryState.delivered),
      confirmed: confirmed,
    );

void main() {
  test('stageUndo restores target text and tracks revision/provenance', () async {
    final rig = CatalogRig();
    await rig.save('a');
    await rig.sessions.initialize();
    final directory = LiveDirectory();
    final summary = CatalogSource(profile('a')).row('one');
    final ref = summary.info.ref;
    final live = SessionLiveController(
      hosts: rig.hosts,
      profile: profile('a'),
      summary: summary,
      directory: directory,
    );
    addTearDown(live.dispose);

    final port = _FakePort();
    final start = live.start();
    directory.grant(ref, turnActions: port);
    await start;

    final turn = live.turn;
    final target = _turn('msg_1', ref: ref, text: 'Original prompt text');

    expect(live.draft.text, isEmpty);
    final result = await turn.stageUndo(target: target);

    expect(result.applied, isTrue);
    expect(port.staged, [target.id]);
    expect(live.draft.text, 'Original prompt text');
    expect(turn.restoredText, 'Original prompt text');
    expect(turn.hasUntouchedRestoredText, isTrue);
  });

  test('stageUndo confirms before overwriting a non-empty user draft', () async {
    final rig = CatalogRig();
    await rig.save('a');
    await rig.sessions.initialize();
    final directory = LiveDirectory();
    final summary = CatalogSource(profile('a')).row('one');
    final ref = summary.info.ref;
    final live = SessionLiveController(
      hosts: rig.hosts,
      profile: profile('a'),
      summary: summary,
      directory: directory,
    );
    addTearDown(live.dispose);

    final port = _FakePort();
    final start = live.start();
    directory.grant(ref, turnActions: port);
    await start;

    final turn = live.turn;
    final target = _turn('msg_1', ref: ref, text: 'Restored prompt');

    live.draft.text = 'Unsent user draft';
    var confirmCalls = 0;
    turn.confirmReplaceDraft = () async {
      confirmCalls++;
      return false; // User cancels
    };

    final cancelled = await turn.stageUndo(target: target);
    expect(cancelled.applied, isFalse);
    expect(confirmCalls, 1);
    expect(live.draft.text, 'Unsent user draft');
    expect(port.staged, isEmpty);

    // Now user confirms
    turn.confirmReplaceDraft = () async {
      confirmCalls++;
      return true;
    };
    final accepted = await turn.stageUndo(target: target);
    expect(accepted.applied, isTrue);
    expect(confirmCalls, 2);
    expect(live.draft.text, 'Restored prompt');
    expect(turn.hasUntouchedRestoredText, isTrue);
  });

  test('CAS protection: concurrent edit during RPC wait is not overwritten', () async {
    final rig = CatalogRig();
    await rig.save('a');
    await rig.sessions.initialize();
    final directory = LiveDirectory();
    final summary = CatalogSource(profile('a')).row('one');
    final ref = summary.info.ref;
    final live = SessionLiveController(
      hosts: rig.hosts,
      profile: profile('a'),
      summary: summary,
      directory: directory,
    );
    addTearDown(live.dispose);

    final port = _FakePort();
    final start = live.start();
    directory.grant(ref, turnActions: port);
    await start;

    final turn = live.turn;
    final target = _turn('msg_1', ref: ref, text: 'Restored prompt');

    live.draft.text = 'Initial draft';
    turn.confirmReplaceDraft = () async {
      // User types while confirmation was pending
      live.draft.text = 'New concurrent edit';
      return true;
    };

    final result = await turn.stageUndo(target: target);
    expect(result.applied, isTrue);
    // Draft was NOT overwritten because revision changed during wait
    expect(live.draft.text, 'New concurrent edit');
  });

  test('redoAll clears draft only when restored text is untouched', () async {
    final rig = CatalogRig();
    await rig.save('a');
    await rig.sessions.initialize();
    final directory = LiveDirectory();
    final summary = CatalogSource(profile('a')).row('one');
    final ref = summary.info.ref;
    final live = SessionLiveController(
      hosts: rig.hosts,
      profile: profile('a'),
      summary: summary,
      directory: directory,
    );
    addTearDown(live.dispose);

    final port = _FakePort();
    final start = live.start();
    directory.grant(ref, turnActions: port);
    await start;

    final turn = live.turn;
    final target = _turn('msg_1', ref: ref, text: 'Restored prompt');

    await turn.stageUndo(target: target);
    expect(turn.hasUntouchedRestoredText, isTrue);

    // 1. User edited the restored text -> redoAll must NOT clear it
    live.draft.text = 'Restored prompt with user additions';
    expect(turn.hasUntouchedRestoredText, isFalse);
    await turn.redoAll();
    expect(live.draft.text, 'Restored prompt with user additions');

    // 2. Untouched restored text -> redoAll clears draft
    turn.confirmReplaceDraft = () async => true;
    await turn.stageUndo(target: target);
    expect(turn.hasUntouchedRestoredText, isTrue);
    await turn.redoAll();
    expect(live.draft.text, isEmpty);
    expect(turn.restoredText, isNull);
  });

  test('redoNext clears draft when untouched and clears staged cut', () async {
    final rig = CatalogRig();
    await rig.save('a');
    await rig.sessions.initialize();
    final directory = LiveDirectory();
    final summary = CatalogSource(profile('a')).row('one');
    final ref = summary.info.ref;
    final live = SessionLiveController(
      hosts: rig.hosts,
      profile: profile('a'),
      summary: summary,
      directory: directory,
    );
    addTearDown(live.dispose);

    final port = _FakePort();
    final start = live.start();
    directory.grant(ref, turnActions: port);
    await start;

    final turn = live.turn;
    final target = _turn('msg_1', ref: ref, text: 'Restored prompt');

    await turn.stageUndo(target: target);
    expect(turn.hasUntouchedRestoredText, isTrue);

    await turn.redoNext();
    expect(port.redoNextCalls, 1);
    expect(live.draft.text, isEmpty);
  });

  test('builtin slash commands map unavailable reasons and execute when available', () async {
    final rig = CatalogRig();
    await rig.save('a');
    await rig.sessions.initialize();
    final directory = LiveDirectory();
    final summary = CatalogSource(profile('a')).row('one');
    final ref = summary.info.ref;
    final live = SessionLiveController(
      hosts: rig.hosts,
      profile: profile('a'),
      summary: summary,
      directory: directory,
    );
    addTearDown(live.dispose);

    final port = _FakePort();
    final start = live.start();
    directory.grant(ref, turnActions: port);
    await start;

    final turn = live.turn;

    // When port is available
    expect(turn.canUndo, isTrue);
    expect(turn.unavailable(builtin.SessionTurnAction.undo), isNull);

    // When port is busy
    port.refusal = SessionTurnUnavailable.busy;
    expect(turn.unavailable(builtin.SessionTurnAction.undo),
        builtin.SessionTurnActionUnavailable.busy);

    // When compacting
    port.state = const SessionTurnState(compacting: true);
    expect(turn.unavailable(builtin.SessionTurnAction.compact),
        builtin.SessionTurnActionUnavailable.compacting);

    // When revert staged
    port.state = const SessionTurnState();
    port.refusal = SessionTurnUnavailable.revertStaged;
    expect(turn.unavailable(builtin.SessionTurnAction.compact),
        builtin.SessionTurnActionUnavailable.revertStaged);

    // When no turn to undo / target unknown
    port.refusal = SessionTurnUnavailable.targetUnknown;
    expect(turn.unavailable(builtin.SessionTurnAction.undo),
        builtin.SessionTurnActionUnavailable.nothingToUndo);
    expect(turn.unavailable(builtin.SessionTurnAction.redo),
        builtin.SessionTurnActionUnavailable.nothingToRedo);

    // Run slash actions
    port.refusal = null;
    await turn.run(builtin.SessionTurnAction.compact);
    expect(port.compactCalls, 1);
  });
}
