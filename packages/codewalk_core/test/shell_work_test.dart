import 'package:codewalk_core/codewalk_core.dart';
import 'package:test/test.dart';

void main() {
  const host = HostId('h1');
  const harness = HarnessInstanceId('inst1');
  const session = SessionRef(host, harness, 'ses_parent');
  const child = SessionRef(host, harness, 'ses_child');
  const foreignSession = SessionRef(host, harness, 'ses_other');
  const foreignHarness = HarnessRef(HostId('h2'), HarnessInstanceId('inst2'));

  StreamPosition pos(int seq) =>
      StreamPosition(id: 'stream', epoch: 'e1', seq: BigInt.from(seq));

  SourceProvenance source([HarnessRef? customHarness]) => SourceProvenance(
    harness: customHarness ?? session.harnessRef,
    version: '2.0.22',
    nativeType: 'shell.created',
  );

  EventMeta eventMeta(int seq) => EventMeta(
    owner: SessionOwner(session),
    position: pos(seq),
    receivedAt: DateTime.utc(2026, 11, 19),
    source: source(),
  );

  SnapshotBoundary boundary(int seq) => SnapshotBoundary(
    owner: SessionOwner(session),
    hydrationGeneration: 'g1',
    readStart: pos(seq),
    readStartedAt: DateTime.utc(2026, 11, 19, 0, 0, 1),
    readCompletedAt: DateTime.utc(2026, 11, 19, 0, 0, 2),
    authority: const OpenValue.known(SnapshotAuthority.authoritative),
  );

  ShellWork shell(
    String id, {
    DomainOwner? owner,
    ShellStatus status = ShellStatus.running,
    SourceProvenance? customSource,
    int? exitCode,
  }) => ShellWork(
    id: id,
    owner: owner ?? SessionOwner(session),
    command: 'npm test',
    status: OpenValue.known(status),
    startedAt: DateTime.utc(2026, 11, 19, 1, 0, 0),
    exitCode: exitCode,
    source: customSource ?? source(),
  );

  WorkItem childWork() => WorkItem(
    id: const WorkId('w_child'),
    owner: SessionOwner(child, origin: session),
    child: child,
    parent: session,
    status: const OpenValue.known(WorkStatus.running),
    completionScope: const OpenValue.known(CompletionScope.child),
    title: 'Subagent',
  );

  test(
    'ShellWork and ShellOutputPage enforce invariants and value equality',
    () {
      final a = shell('sh_1');
      final b = shell('sh_1');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a.isRunning, isTrue);
      expect(
        shell('sh_2', status: ShellStatus.exited, exitCode: 0).isRunning,
        isFalse,
      );
      expect(
        () => ShellWork(
          id: '',
          owner: SessionOwner(session),
          command: 'echo hi',
          status: const OpenValue.known(ShellStatus.running),
        ),
        throwsArgumentError,
      );
      expect(
        () => ShellWork(
          id: 'sh_bad',
          owner: SessionOwner(session),
          command: 'echo hi',
          status: const OpenValue.known(ShellStatus.exited),
          startedAt: DateTime.utc(2026, 11, 19, 1, 0, 5),
          completedAt: DateTime.utc(2026, 11, 19, 1, 0, 1),
        ),
        throwsArgumentError,
      );

      final page = ShellOutputPage(
        output: 'line1\n',
        cursor: 6,
        size: 12,
        truncated: false,
      );
      expect(page.hasMore, isTrue);
      expect(
        ShellOutputPage(
          output: '',
          cursor: 12,
          size: 12,
          truncated: true,
        ).hasMore,
        isFalse,
      );
      expect(
        () =>
            ShellOutputPage(output: '', cursor: -1, size: 0, truncated: false),
        throwsArgumentError,
      );
      expect(ShellCapabilities.observe, 'shell.observe');
      expect(ShellCapabilities.stop, 'shell.stop');
    },
  );

  test('ShellChanged and WorkChanged stay completely isolated in reducer', () {
    var state = SessionState(session, streamPosition: pos(0));
    state = reduce(
      state,
      WorkChanged(meta: eventMeta(1), items: [childWork()]),
    ).state;
    state = reduce(
      state,
      ShellChanged(meta: eventMeta(2), items: [shell('sh_1')]),
    ).state;
    expect(state.work, hasLength(1));
    expect(state.shells, [shell('sh_1')]);

    // Clearing subagent work never alters shells.
    state = reduce(
      state,
      WorkChanged(meta: eventMeta(3), items: const []),
    ).state;
    expect(state.work, isEmpty);
    expect(state.shells, [shell('sh_1')]);

    // Clearing shells never alters subagent work.
    state = reduce(
      state,
      WorkChanged(meta: eventMeta(4), items: [childWork()]),
    ).state;
    state = reduce(
      state,
      ShellChanged(meta: eventMeta(5), items: const []),
    ).state;
    expect(state.work, hasLength(1));
    expect(state.shells, isEmpty);
  });

  test('hydration isolates shells from work and enforces scope/completeness', () {
    var state = beginHydration(
      SessionState(session, streamPosition: pos(0)),
      generation: 'g1',
      readStart: pos(0),
    );
    // Hydrate shells first, then hydrate work-only snapshot: shells survive.
    state = hydrate(
      state,
      SessionSnapshot(
        ref: session,
        hydrationGeneration: 'g1',
        shells: SnapshotCollection(
          values: [shell('sh_live')],
          boundary: boundary(0),
          complete: true,
        ),
      ),
    ).state;
    expect(state.shells, [shell('sh_live')]);

    state = hydrate(
      state,
      SessionSnapshot(
        ref: session,
        hydrationGeneration: 'g1',
        work: SnapshotCollection(
          values: [childWork()],
          boundary: boundary(0),
          complete: true,
        ),
      ),
    ).state;
    expect(state.work, hasLength(1));
    expect(state.shells, [shell('sh_live')]);

    // Foreign session owner in ShellChanged is rejected with shellScopeMismatch.
    final foreignResult = reduce(
      state,
      ShellChanged(
        meta: eventMeta(1),
        items: [shell('sh_bad', owner: SessionOwner(foreignSession))],
      ),
    );
    expect(foreignResult.state.shells, [shell('sh_live')]);
    expect(
      foreignResult.effects.whereType<Refetch>().single.collection,
      SessionCollection.shells,
    );
    expect(
      foreignResult.effects.whereType<Refetch>().single.reason,
      'shellScopeMismatch',
    );

    // Foreign harness provenance in ShellChanged is also rejected.
    final wrongHarness = reduce(
      state,
      ShellChanged(
        meta: eventMeta(2),
        items: [shell('sh_bad2', customSource: source(foreignHarness))],
      ),
    );
    expect(
      wrongHarness.effects.whereType<Refetch>().single.reason,
      'shellScopeMismatch',
    );

    // Incomplete shell snapshot triggers shellSnapshotIncomplete refetch.
    final incomplete = hydrate(
      beginHydration(state, generation: 'g2', readStart: pos(2)),
      SessionSnapshot(
        ref: session,
        hydrationGeneration: 'g2',
        shells: SnapshotCollection(
          values: [shell('sh_partial')],
          boundary: SnapshotBoundary(
            owner: SessionOwner(session),
            hydrationGeneration: 'g2',
            readStart: pos(2),
            readStartedAt: DateTime.utc(2026, 11, 19, 0, 0, 3),
            authority: const OpenValue.known(SnapshotAuthority.authoritative),
          ),
          complete: false,
        ),
      ),
    );
    expect(
      incomplete.effects.whereType<Refetch>().single.reason,
      'shellSnapshotIncomplete',
    );
  });

  test(
    'hydration preserves resident terminal ShellWork on running-only snapshots and ShellRun preserves shellId',
    () {
      var state = beginHydration(
        SessionState(session, streamPosition: pos(0)),
        generation: 'g1',
        readStart: pos(0),
      );
      final done = shell('sh_done', status: ShellStatus.exited, exitCode: 0);
      final stillRunning = shell('sh_run1', status: ShellStatus.running);
      final vanishedRunning = shell('sh_run2', status: ShellStatus.running);
      state = hydrate(
        state,
        SessionSnapshot(
          ref: session,
          hydrationGeneration: 'g1',
          shells: SnapshotCollection(
            values: [done, stillRunning, vanishedRunning],
            boundary: boundary(0),
            complete: true,
          ),
        ),
      ).state;
      expect(state.shells.map((s) => s.id), ['sh_done', 'sh_run1', 'sh_run2']);

      // Subsequent running-only snapshot omits sh_done and sh_run2:
      // sh_done (terminal) survives, sh_run2 (running) is dropped, sh_run1 stays.
      final g2State = hydrate(
        beginHydration(state, generation: 'g2', readStart: pos(2)),
        SessionSnapshot(
          ref: session,
          hydrationGeneration: 'g2',
          shells: SnapshotCollection(
            values: [stillRunning],
            boundary: SnapshotBoundary(
              owner: SessionOwner(session),
              hydrationGeneration: 'g2',
              readStart: pos(2),
              readStartedAt: DateTime.utc(2026, 11, 19, 0, 0, 3),
              readCompletedAt: DateTime.utc(2026, 11, 19, 0, 0, 4),
              authority: const OpenValue.known(SnapshotAuthority.authoritative),
            ),
            complete: true,
          ),
        ),
      ).state;
      expect(g2State.shells.map((s) => s.id), ['sh_done', 'sh_run1']);

      // ShellRun retains harness-neutral shellId across withMeta and equality.
      final meta1 = ItemMeta(
        id: const ItemId('item_shell_1'),
        generation: 'gen1',
        status: const OpenValue.known(ItemStatus.completed),
        source: source(),
      );
      final meta2 = ItemMeta(
        id: const ItemId('item_shell_1'),
        generation: 'gen2',
        status: const OpenValue.known(ItemStatus.completed),
        source: source(),
      );
      final run = ShellRun(
        meta: meta1,
        command: 'echo ok',
        shellId: 'custom_shell_42',
        shellStatus: const OpenValue.known(ShellStatus.exited),
        exitCode: 0,
      );
      expect(run.shellId, 'custom_shell_42');
      expect((run.withMeta(meta2) as ShellRun).shellId, 'custom_shell_42');
      expect(
        run ==
            ShellRun(
              meta: meta1,
              command: 'echo ok',
              shellId: 'other_shell',
              shellStatus: const OpenValue.known(ShellStatus.exited),
              exitCode: 0,
            ),
        isFalse,
      );
    },
  );

  test(
    'terminal-preserving shell hydration respects maxObservations without tripping residentCollectionLimit, tracks shellsObserved, and redactCredentialSlice protects boundaries',
    () {
      final initial = SessionState(
        session,
        limits: const ReducerLimits(maxObservations: 3),
        streamPosition: pos(0),
      );
      expect(initial.shellsObserved, isFalse);

      // Hydrate 3 terminal shells (at exact maxObservations cap).
      var state = hydrate(
        beginHydration(initial, generation: 'g1', readStart: pos(0)),
        SessionSnapshot(
          ref: session,
          hydrationGeneration: 'g1',
          shells: SnapshotCollection(
            values: [
              shell('sh_t1', status: ShellStatus.exited, exitCode: 0),
              shell('sh_t2', status: ShellStatus.exited, exitCode: 0),
              shell('sh_t3', status: ShellStatus.exited, exitCode: 0),
            ],
            boundary: boundary(0),
            complete: true,
          ),
        ),
      ).state;
      expect(state.shellsObserved, isTrue);
      expect(state.shells.map((s) => s.id), ['sh_t1', 'sh_t2', 'sh_t3']);

      // Re-hydrating with 1 running shell preserves the 2 newest terminals
      // (total = 3 == maxObservations) and emits ZERO Refetch effects!
      final next = hydrate(
        beginHydration(state, generation: 'g2', readStart: pos(2)),
        SessionSnapshot(
          ref: session,
          hydrationGeneration: 'g2',
          shells: SnapshotCollection(
            values: [shell('sh_live', status: ShellStatus.running)],
            boundary: SnapshotBoundary(
              owner: SessionOwner(session),
              hydrationGeneration: 'g2',
              readStart: pos(2),
              readStartedAt: DateTime.utc(2026, 11, 19, 0, 0, 3),
              readCompletedAt: DateTime.utc(2026, 11, 19, 0, 0, 4),
              authority: const OpenValue.known(SnapshotAuthority.authoritative),
            ),
            complete: true,
          ),
        ),
      );
      expect(next.effects.whereType<Refetch>(), isEmpty);
      expect(next.state.shells.map((s) => s.id), ['sh_t2', 'sh_t3', 'sh_live']);

      // redactCredentialSlice: credential & PEM spanning sliceStart and sliceEnd.
      const full =
          'hdr\nAuthorization: Bearer super_secret_split_12345\n'
          'middle\n'
          '-----BEGIN PRIVATE KEY-----\n'
          'MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSj\n'
          '-----END PRIVATE KEY-----\n'
          'tail\n';
      final splitInsideBearer = full.indexOf('split_12345');
      final splitInsidePem = full.indexOf('BgkqhkiG');
      final page1 = redactCredentialSlice(full, 0, splitInsideBearer);
      final page2 = redactCredentialSlice(
        full,
        splitInsideBearer,
        splitInsidePem,
      );
      final page3 = redactCredentialSlice(full, splitInsidePem, full.length);
      expect(page1, contains('[redacted]'));
      expect(page1, isNot(contains('super_secret')));
      expect(page2, isNot(contains('split_12345')));
      expect(page2, contains('middle'));
      expect(page2, contains('[redacted]'));
      expect(page2, isNot(contains('MIIEvQIBADAN')));
      expect(page3, isNot(contains('BgkqhkiG')));
      expect(page3, contains('tail'));

      // Unconfirmed shells are NOT preserved as terminal when omitted by reconcile.
      final unconf = ShellWork(
        id: 'sh_unconf',
        owner: SessionOwner(session),
        command: 'echo x',
        status: OpenValue<ShellStatus>.unknown('reconcileUnconfirmed'),
      );
      expect(
        mergeShellObservations([unconf], const [], maxObservations: 3),
        isEmpty,
      );

      // Live ShellChanged at cap trims oldest confirmed terminals cleanly
      // without emitting residentCollectionLimit, and only shell.list sets shellsObserved.
      final createdEv = reduce(
        next.state,
        ShellChanged(
          meta: eventMeta(5),
          items: [...next.state.shells, shell('sh_live2')],
        ),
      );
      expect(createdEv.effects.whereType<Refetch>(), isEmpty);
      expect(createdEv.state.shells.map((s) => s.id), [
        'sh_t3',
        'sh_live',
        'sh_live2',
      ]);

      final rehydrating = beginHydration(
        createdEv.state,
        generation: 'g3',
        readStart: pos(6),
      );
      expect(rehydrating.shellsObserved, isFalse);
      final afterCreateOnly = reduce(
        rehydrating,
        ShellChanged(meta: eventMeta(7), items: [shell('sh_only_sse')]),
      ).state;
      expect(afterCreateOnly.shellsObserved, isFalse);
    },
  );
}
