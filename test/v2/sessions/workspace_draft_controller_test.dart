import 'dart:async';

import 'package:codewalk/features/sessions/workspace_draft_controller.dart';
import 'package:codewalk/platform/sessions/workspace_draft_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/platform/storage/payload_store.dart';
import 'package:codewalk/shared/sessions/session_actions.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';
import 'fakes.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

final class _Rig {
  _Rig() {
    actions = FakeActionSource(
      endpointSupport: const SessionActionSupport(SessionActionReason.none),
    );
    catalogRig = CatalogRig(actions: actions, withFeed: false);
    backend = FakeMetadataBackend();
    metadata = V2MetadataStore(backend: backend);
    draftStore = WorkspaceDraftStore(
      payloads: PreferencesPayloadStore(metadata),
      index: metadata,
      delay: const Duration(milliseconds: 10),
    );
    controller = WorkspaceDraftController(
      catalog: catalogRig.sessions,
      store: draftStore,
    );
  }

  late final FakeActionSource actions;
  late final CatalogRig catalogRig;
  late final FakeMetadataBackend backend;
  late final V2MetadataStore metadata;
  late final WorkspaceDraftStore draftStore;
  late final WorkspaceDraftController controller;

  Future<void> setupServerAndProjects() async {
    await catalogRig.save('srv1');
    await catalogRig.sessions.initialize();
    final select = catalogRig.sessions.selectProfile('profile_srv1');
    catalogRig.sources.single.respond([
      catalogRig.sources.single.row('s1', directory: '/work/project-a'),
      catalogRig.sources.single.row('s2', directory: '/work/project-b'),
    ]);
    await select;
    await flush();
  }

  Future<void> completeCreatedRead({
    bool fail = false,
    bool mismatch = false,
  }) async {
    final source = catalogRig.sources.single;
    for (var i = 0; i < 100 && source.reads.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(source.reads, isNotEmpty);
    if (fail) {
      source.reads.last.$2.completion.completeError(StateError('read failed'));
    } else {
      source.reads.last.$2.completion.complete(
        source.row(
          mismatch ? 'other' : 'created',
          directory: '/work/project-a',
        ),
      );
    }
  }

  void dispose() {
    controller.dispose();
    catalogRig.dispose();
  }
}

void main() {
  late _Rig rig;
  setUp(() => rig = _Rig());
  tearDown(() => rig.dispose());

  test('discard invalidates the pending first-prompt handoff', () async {
    await rig.setupServerAndProjects();
    await rig.controller.openDraft(directory: '/work/project-a');
    rig.controller.draft.text = 'Keep after discard';
    final ref = rig.catalogRig.sources.single
        .row('created', directory: '/work/project-a')
        .info
        .ref;
    rig.actions.createdSessionRef = ref;
    final sending = rig.controller.sendFirstPrompt(
      onBound: (ref, _, _) => rig.controller.locationChanged(
        Uri(pathSegments: ['', 's', ref.host.value, ref.nativeId]).path,
      ),
    );
    await rig.completeCreatedRead();
    expect(await sending, isTrue);
    final handoff = rig.controller.firstPromptFor(ref)!;
    expect(rig.controller.owns(handoff), isTrue);
    await rig.controller.discardAttempt();
    expect(rig.controller.firstPromptFor(ref), isNull);
    expect(rig.controller.owns(handoff), isFalse);
    expect(rig.controller.draft.text, 'Keep after discard');
    expect(rig.controller.status, WorkspaceDraftStatus.ready);
    expect(rig.actions.calls.where((call) => call == 'create'), hasLength(1));
  });

  test('no create on open: entering draft does not invoke create', () async {
    await rig.setupServerAndProjects();
    await rig.controller.openDraft(directory: '/work/project-a');

    expect(rig.controller.isDraftActive, isTrue);
    expect(rig.controller.currentKey?.canonicalDirectory, '/work/project-a');
    expect(rig.actions.calls, isNot(contains('create')));
  });

  test(
    'double Send: second tap while sending is ignored (single-flight)',
    () async {
      await rig.setupServerAndProjects();
      await rig.controller.openDraft(directory: '/work/project-a');
      rig.controller.draft.text = 'Hello';
      rig.actions.createdSessionRef = const SessionRef(
        HostId('profile_srv1'),
        HarnessInstanceId('profile_srv1'),
        'ses_created',
      );

      rig.actions.createDelay = const Duration(milliseconds: 50);
      final completer = Completer<SessionRef>();

      final first = rig.controller.sendFirstPrompt(
        onBound: (ref, prompt, id) => completer.complete(ref),
      );
      expect(rig.controller.sending, isTrue);

      // Second send attempt while first is in flight
      final second = await rig.controller.sendFirstPrompt(
        onBound: (ref, prompt, id) {},
      );
      expect(second, isFalse);

      await rig.completeCreatedRead();
      final ok = await first;
      expect(ok, isTrue);
      expect(rig.actions.calls.where((c) => c == 'create'), hasLength(1));
    },
  );

  test('exact bind: hands off exact SessionRef returned by create', () async {
    await rig.setupServerAndProjects();
    await rig.controller.openDraft(directory: '/work/project-a');
    rig.controller.draft.text = 'Bootstrap message';

    const expectedRef = SessionRef(
      HostId('profile_srv1'),
      HarnessInstanceId('profile_srv1'),
      'ses_created',
    );
    rig.actions.createdSessionRef = expectedRef;

    SessionRef? boundRef;
    String? boundPrompt;
    CommandId? boundId;

    final pending = rig.controller.sendFirstPrompt(
      onBound: (ref, prompt, id) {
        boundRef = ref;
        boundPrompt = prompt;
        boundId = id;
      },
    );

    await rig.completeCreatedRead();
    final sent = await pending;
    expect(sent, isTrue);
    expect(boundRef, equals(expectedRef));
    expect(boundPrompt, 'Bootstrap message');
    expect(boundId, isNotNull);
    expect(rig.controller.isDraftActive, isFalse);
    expect(rig.controller.draft.text, 'Bootstrap message');
    expect(rig.controller.status, WorkspaceDraftStatus.bound);
  });

  test(
    'refresh during draft: background catalog reload does not exit draft',
    () async {
      await rig.setupServerAndProjects();
      await rig.controller.openDraft(directory: '/work/project-a');
      rig.controller.draft.text = 'Draft during refresh';
      await flush();

      // Trigger catalog refresh
      final refresh = rig.catalogRig.sessions.refresh();
      rig.catalogRig.sources.last.respond([
        rig.catalogRig.sources.last.row('s1', directory: '/work/project-a'),
      ]);
      await refresh;

      expect(rig.controller.isDraftActive, isTrue);
      expect(rig.controller.draft.text, 'Draft during refresh');
    },
  );

  test(
    'A->B->A isolation: draft in A is isolated from B and restored on return',
    () async {
      await rig.setupServerAndProjects();

      // Open draft in project A and type text
      await rig.controller.openDraft(directory: '/work/project-a');
      rig.controller.draft.text = 'Draft for A';
      await rig.draftStore.flush();

      // Switch project to B
      rig.catalogRig.sessions.selectProject(
        const ProjectRef(HostId('profile_srv1'), '/work/project-b'),
      );
      await flush();

      // Project B should not inherit draft mode or text from A
      expect(rig.controller.isDraftActive, isFalse);
      expect(rig.controller.draft.text, isEmpty);
      expect(rig.controller.status, WorkspaceDraftStatus.ready);

      // Switch back to project A
      rig.catalogRig.sessions.selectProject(
        const ProjectRef(HostId('profile_srv1'), '/work/project-a'),
      );
      await flush();

      // Project A draft mode and text are restored
      expect(rig.controller.isDraftActive, isTrue);
      expect(rig.controller.draft.text, 'Draft for A');
    },
  );

  test(
    'switch during create: prompt is not sent to newly selected project',
    () async {
      await rig.setupServerAndProjects();
      await rig.controller.openDraft(directory: '/work/project-a');
      rig.controller.draft.text = 'In flight prompt';

      rig.actions.createDelay = const Duration(milliseconds: 60);

      var boundCalled = false;
      final sendFuture = rig.controller.sendFirstPrompt(
        onBound: (ref, prompt, id) => boundCalled = true,
      );

      // While create is in flight, user switches to project B
      rig.catalogRig.sessions.selectProject(
        const ProjectRef(HostId('profile_srv1'), '/work/project-b'),
      );

      final result = await sendFuture;
      expect(result, isFalse);
      expect(boundCalled, isFalse);

      // Returning to project A keeps the text in its draft
      rig.catalogRig.sessions.selectProject(
        const ProjectRef(HostId('profile_srv1'), '/work/project-a'),
      );
      await flush();
      expect(rig.controller.draft.text, 'In flight prompt');
    },
  );

  test(
    'lost answer (uncertain, no replay): status becomes uncertain and text kept',
    () async {
      await rig.setupServerAndProjects();
      await rig.controller.openDraft(directory: '/work/project-a');
      rig.controller.draft.text = 'Uncertain prompt';

      rig.actions.outcomes['create'] = SessionActionOutcome.uncertain;

      final pending = rig.controller.sendFirstPrompt(
        onBound: (ref, prompt, id) {},
      );

      expect(await pending, isFalse);
      expect(rig.controller.status, WorkspaceDraftStatus.uncertain);
      expect(rig.controller.notice, WorkspaceDraftNotice.uncertain);
      expect(rig.controller.draft.text, 'Uncertain prompt');
    },
  );

  test(
    'refusal: status becomes failed and prompt kept without auto-retry',
    () async {
      await rig.setupServerAndProjects();
      await rig.controller.openDraft(directory: '/work/project-a');
      rig.controller.draft.text = 'Refused prompt';

      rig.actions.outcomes['create'] = SessionActionOutcome.rejected;

      final pending = rig.controller.sendFirstPrompt(
        onBound: (ref, prompt, id) {},
      );

      expect(await pending, isFalse);
      expect(rig.controller.status, WorkspaceDraftStatus.failed);
      expect(rig.controller.notice, WorkspaceDraftNotice.rejected);
      expect(rig.controller.draft.text, 'Refused prompt');
    },
  );

  test('fence write failure: blocks create call', () async {
    await rig.setupServerAndProjects();
    await rig.controller.openDraft(directory: '/work/project-a');
    rig.controller.draft.text = 'Will fail fence';

    // Cause fence write to fail
    final key = rig.controller.currentKey!;
    rig.backend.failWrite = WorkspaceDraftStore.keyFor(key);

    final pending = rig.controller.sendFirstPrompt(
      onBound: (ref, prompt, id) {},
    );

    expect(await pending, isFalse);
    expect(rig.controller.notice, WorkspaceDraftNotice.fenceFailed);
    expect(rig.actions.calls, isNot(contains('create')));
  });

  test('discardAttempt resets uncertain/failed draft back to ready', () async {
    await rig.setupServerAndProjects();
    await rig.controller.openDraft(directory: '/work/project-a');
    rig.controller.draft.text = 'Prompt to retry';

    rig.actions.outcomes['create'] = SessionActionOutcome.uncertain;
    await rig.controller.sendFirstPrompt(onBound: (_, _, _) {});
    expect(rig.controller.status, WorkspaceDraftStatus.uncertain);

    await rig.controller.discardAttempt();
    expect(rig.controller.status, WorkspaceDraftStatus.ready);
    expect(rig.controller.notice, WorkspaceDraftNotice.none);
    expect(rig.controller.draft.text, 'Prompt to retry');
  });
  for (final mismatch in [false, true]) {
    test(
      'an exact direct read must succeed before binding: mismatch $mismatch',
      () async {
        await rig.setupServerAndProjects();
        await rig.controller.openDraft();
        rig.controller.draft.text = 'kept until verified';
        rig.actions.createdSessionRef = rig.catalogRig.sources.single
            .row('created')
            .info
            .ref;
        var bound = false;
        final pending = rig.controller.sendFirstPrompt(
          onBound: (_, _, _) => bound = true,
        );
        await rig.completeCreatedRead(fail: !mismatch, mismatch: mismatch);
        expect(await pending, isFalse);
        expect(bound, isFalse);
        expect(rig.controller.draft.text, 'kept until verified');
        expect(rig.controller.status, WorkspaceDraftStatus.uncertain);
        expect(
          await rig.controller.sendFirstPrompt(onBound: (_, _, _) {}),
          isFalse,
        );
        expect(
          rig.actions.calls.where((call) => call == 'create'),
          hasLength(1),
        );
      },
    );
  }

  test('A-B-A during create cannot revive the original send intent', () async {
    await rig.setupServerAndProjects();
    await rig.controller.openDraft();
    rig.controller.draft.text = 'original intent';
    rig.actions.createdSessionRef = rig.catalogRig.sources.single
        .row('created')
        .info
        .ref;
    rig.actions.createDelay = const Duration(milliseconds: 60);
    var bound = false;
    final pending = rig.controller.sendFirstPrompt(
      onBound: (_, _, _) => bound = true,
    );
    for (var i = 0; i < 100 && !rig.actions.calls.contains('create'); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    expect(rig.actions.calls, contains('create'));
    rig.catalogRig.sessions.selectProject(
      const ProjectRef(HostId('profile_srv1'), '/work/project-b'),
    );
    rig.catalogRig.sessions.selectProject(
      const ProjectRef(HostId('profile_srv1'), '/work/project-a'),
    );
    expect(await pending, isFalse);
    expect(bound, isFalse);
    expect(rig.controller.status, WorkspaceDraftStatus.uncertain);
    expect(rig.controller.draft.text, 'original intent');
  });

  test(
    'leaving and returning to the same route invalidates create handoff',
    () async {
      await rig.setupServerAndProjects();
      rig.controller.locationChanged('/sessions');
      await rig.controller.openDraft();
      rig.controller.draft.text = 'do not send elsewhere';
      rig.actions.createdSessionRef = rig.catalogRig.sources.single
          .row('created')
          .info
          .ref;
      rig.actions.createDelay = const Duration(milliseconds: 50);
      var bound = false;
      final pending = rig.controller.sendFirstPrompt(
        onBound: (_, _, _) => bound = true,
      );
      for (var i = 0; i < 100 && !rig.actions.calls.contains('create'); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      rig.controller.locationChanged('/settings');
      rig.controller.locationChanged('/sessions');
      expect(await pending, isFalse);
      expect(bound, isFalse);
      expect(rig.actions.calls.where((call) => call == 'create'), hasLength(1));
    },
  );
}
