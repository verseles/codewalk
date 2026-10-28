import 'dart:async';
import 'dart:convert';

import 'package:codewalk/app/app_dependencies.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/session_live_page.dart';
import 'package:codewalk/platform/sessions/session_draft_store.dart';
import 'package:codewalk/platform/sessions/workspace_draft_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/platform/storage/payload_store.dart';
import 'package:codewalk/shared/l10n/l10n_context.dart';
import 'package:codewalk/shared/sessions/session_actions.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../hosts/fakes.dart';
import '../storage/storage_fakes.dart';
import 'composer_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';

final class _PayloadReadGate implements PayloadStore {
  _PayloadReadGate(this.base, this.prefix);
  final PayloadStore base;
  final String prefix;
  final entered = Completer<void>();
  final release = Completer<void>();
  bool held = false;
  @override
  Future<bool> contains(String key) async {
    if (!held && key.startsWith(prefix)) {
      held = true;
      entered.complete();
      await release.future;
    }
    return base.contains(key);
  }

  @override
  Future<String?> read(String key) => base.read(key);
  @override
  Future<PayloadWriteResult> write(String key, String value) =>
      base.write(key, value);
  @override
  Future<void> remove(String key) => base.remove(key);
}

final class _ConfirmingWriteFailure implements PayloadStore {
  _ConfirmingWriteFailure(this.base);
  final PayloadStore base;
  bool failing = true;
  int failures = 0;

  @override
  Future<PayloadWriteResult> write(String key, String value) async {
    if (failing &&
        (jsonDecode(value) as Map<String, Object?>)['status'] == 'confirming') {
      failures++;
      throw StateError('controlled post-create write failure');
    }
    return base.write(key, value);
  }

  @override
  Future<bool> contains(String key) => base.contains(key);
  @override
  Future<String?> read(String key) => base.read(key);
  @override
  Future<void> remove(String key) => base.remove(key);
}

void main() {
  late CatalogRig rig;
  late CatalogSource source;
  late FakeActionSource actions;
  late LiveDirectory directory;
  late AppDependencies app;
  late WorkspaceDraftStore store;

  Future<void> open(
    WidgetTester tester, {
    bool empty = false,
    Size size = const Size(390, 844),
    Locale locale = const Locale('en'),
    double scale = 1,
    PayloadStore Function(PayloadStore)? workspacePayloads,
    PayloadStore Function(PayloadStore)? sessionPayloads,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    rig = CatalogRig(withFeed: false);
    addTearDown(rig.dispose);
    await rig.save('a');
    actions = FakeActionSource(
      endpointSupport: const SessionActionSupport(SessionActionReason.none),
    );
    directory = LiveDirectory();
    final metadata = V2MetadataStore(backend: FakeMetadataBackend());
    final payloads = PreferencesPayloadStore(metadata);
    store = WorkspaceDraftStore(
      payloads: workspacePayloads?.call(payloads) ?? payloads,
      index: metadata,
    );
    app = createAppDependencies(
      initialLink: Uri(path: '/sessions'),
      metadataStore: metadata,
      profileRepository: rig.repository,
      endpointProber: FakeProber(),
      sessionCatalogFactory: rig.create,
      sessionActionFactory: (_, _) => actions,
      sessionLiveDirectory: () => directory,
      draftStore: SessionDraftStore(
        payloads: sessionPayloads?.call(payloads) ?? payloads,
        index: metadata,
      ),
      workspaceDraftStore: store,
    );
    app.preferences.setLocale(locale);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: CodeWalkV2Bootstrap(dependencies: app),
      ),
    );
    for (var i = 0; i < 10 && rig.sources.isEmpty; i++) {
      await tester.pump();
    }
    source = rig.sources.single;
    source.respond(empty ? [] : [source.row('old', directory: '/work/alpha')]);
    await tester.pumpAndSettle();
    // The project context opened on the rows above; later reads are driven
    // by hand.
    source.autoContexts = false;
    await tester.tap(find.byKey(const ValueKey('workspace-new-chat')));
    await tester.pumpAndSettle();
  }

  Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
    for (var i = 0; i < 50 && !ready(); i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(ready(), isTrue);
  }

  Future<void> startSend(WidgetTester tester, {bool waitForRead = true}) async {
    await tester.pump(const Duration(milliseconds: 300));
    if (!source.tasks.last.completion.isCompleted) {
      source.respond([source.row('old', directory: '/work/alpha')]);
      await tester.pumpAndSettle();
    }
    actions.createdSessionRef = source
        .row('created', directory: '/work/alpha')
        .info
        .ref;
    await tester.enterText(
      find.byKey(const ValueKey('workspace-draft-text')),
      '  first prompt\n',
    );
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('workspace-draft-send')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('workspace-draft-send')));
    if (waitForRead) await waitFor(tester, () => source.reads.isNotEmpty);
  }

  testWidgets('post-create write failure permits explicit recovery in place', (
    tester,
  ) async {
    late _ConfirmingWriteFailure storage;
    await open(
      tester,
      workspacePayloads: (base) => storage = _ConfirmingWriteFailure(base),
    );
    await startSend(tester, waitForRead: false);
    await waitFor(
      tester,
      () => actions.created.isNotEmpty && !app.workspaceDrafts!.sending,
    );
    expect(storage.failures, 1);
    expect(actions.created, ['/work/alpha']);
    expect(source.reads, isEmpty);
    final key = app.workspaceDrafts!.currentKey!;
    final fenced = (await store.read(key))!;
    expect(fenced.status, WorkspaceDraftStatus.creating);
    expect(fenced.fenceCommandId, isNotEmpty);
    expect(fenced.text, '  first prompt\n');
    expect(app.workspaceDrafts!.canSend, isFalse);
    final l10n = tester
        .element(find.byKey(const ValueKey('workspace-draft')))
        .v2L10n;
    expect(find.text(l10n.workspaceDraftUncertain), findsOneWidget);
    expect(find.text(l10n.composerNoticeNotSaved), findsNothing);
    final reset = find.byKey(const ValueKey('workspace-draft-reset'));
    expect(tester.widget<TextButton>(reset).onPressed, isNotNull);
    storage.failing = false;
    await tester.tap(reset);
    await waitFor(
      tester,
      () => app.workspaceDrafts!.status == WorkspaceDraftStatus.ready,
    );
    expect(app.workspaceDrafts!.draft.text, '  first prompt\n');
    expect((await store.read(key))?.fenceCommandId, isNull);
    expect(actions.calls.where((call) => call == 'create'), hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('New Chat shows a draft immediately without a session or tab', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(const ValueKey('workspace-draft')), findsOneWidget);
    expect(find.byKey(const ValueKey('workspace-empty')), findsNothing);
    // Only the opened project's latest session has a tab; New Chat adds none.
    expect(app.sessionTabs!.tabs.map((tab) => tab.ref), [
      source.row('old').info.ref,
    ]);
    expect(actions.calls.where((call) => call == 'create'), isEmpty);
    await tester.enterText(
      find.byKey(const ValueKey('workspace-draft-text')),
      'keep me',
    );
    final refresh = app.sessions!.refresh();
    await tester.pump();
    source.respond([source.row('different', directory: '/other')]);
    await refresh;
    await tester.pumpAndSettle();
    expect(app.workspaceDrafts!.draft.text, 'keep me');
    expect(app.workspaceDrafts!.currentKey!.canonicalDirectory, '/work/alpha');
    expect(find.byKey(const ValueKey('workspace-draft')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Settings during a local draft read does not strand loading', (
    tester,
  ) async {
    late _PayloadReadGate gate;
    await open(
      tester,
      workspacePayloads: (base) =>
          gate = _PayloadReadGate(base, 'cw2.ws_drafts.'),
    );
    expect(gate.entered.isCompleted, isTrue);
    expect(app.workspaceDrafts!.loading, isTrue);
    app.workspaceDrafts!.draft.text = 'Edited while restoring';
    unawaited(app.router.push<void>('/settings'));
    await tester.pumpAndSettle();
    gate.release.complete();
    await tester.pumpAndSettle();
    app.router.pop();
    await tester.pumpAndSettle();
    expect(app.workspaceDrafts!.loading, isFalse);
    expect(app.workspaceDrafts!.draft.text, 'Edited while restoring');
    expect(find.byKey(const ValueKey('workspace-draft')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'first prompt resumes when the empty session draft read settles last',
    (tester) async {
      late _PayloadReadGate gate;
      await open(
        tester,
        sessionPayloads: (base) =>
            gate = _PayloadReadGate(base, 'cw2.drafts.v1.'),
      );
      await startSend(tester);
      final summary = source.row('created', directory: '/work/alpha');
      source.reads.single.$2.completion.complete(summary);
      await waitFor(tester, () => directory.opens.isNotEmpty);
      final outbox = FakeOutbox();
      final handle = directory.grant(summary.info.ref, outbox: outbox);
      handle.emit(
        SessionLiveView(
          session: summary.info.ref,
          phase: SessionLivePhase.live,
          state: liveState(summary.info.ref),
          lastSyncedAt: DateTime.utc(2026, 10, 25),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(gate.entered.isCompleted, isTrue);
      expect(outbox.list, isEmpty);
      gate.release.complete();
      await waitFor(tester, () => outbox.list.isNotEmpty);
      expect(outbox.list.single.text, '  first prompt\n');
      expect(
        outbox.calls.where((call) => call.startsWith('submit ')),
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'navigation while the first outbox write waits cancels delivery',
    (tester) async {
      await open(tester);
      await startSend(tester);
      final summary = source.row('created', directory: '/work/alpha');
      source.reads.single.$2.completion.complete(summary);
      await waitFor(tester, () => directory.opens.isNotEmpty);
      final outbox = FakeOutbox()..holdSubmit = Completer<void>();
      final handle = directory.grant(summary.info.ref, outbox: outbox);
      handle.emit(
        SessionLiveView(
          session: summary.info.ref,
          phase: SessionLivePhase.live,
          state: liveState(summary.info.ref),
          lastSyncedAt: DateTime.utc(2026, 10, 25),
        ),
      );
      await waitFor(
        tester,
        () => outbox.calls.any((call) => call.startsWith('submit ')),
      );
      unawaited(app.router.push<void>('/settings'));
      await tester.pump(const Duration(milliseconds: 400));
      outbox.holdSubmit!.complete();
      await tester.pumpAndSettle();
      expect(app.router.state.uri.path, '/settings');
      expect(outbox.list, isEmpty);
      expect(actions.calls.where((call) => call == 'create'), hasLength(1));
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final edited in [false, true]) {
    testWidgets(
      'recorded first prompt consumes a reopened draft; later edit $edited',
      (tester) async {
        await open(tester);
        await startSend(tester);
        final summary = source.row('created', directory: '/work/alpha');
        source.reads.single.$2.completion.complete(summary);
        await waitFor(tester, () => directory.opens.isNotEmpty);
        final outbox = FakeOutbox()..holdAfterRecord = Completer<void>();
        final handle = directory.grant(summary.info.ref, outbox: outbox);
        handle.emit(
          SessionLiveView(
            session: summary.info.ref,
            phase: SessionLivePhase.live,
            state: liveState(summary.info.ref),
            lastSyncedAt: DateTime.utc(2026, 10, 25),
          ),
        );
        await waitFor(tester, () => outbox.list.isNotEmpty);
        await tester.pump(const Duration(milliseconds: 300));
        if (!source.tasks.last.completion.isCompleted) {
          source.respond([
            source.row('old', directory: '/work/alpha'),
            summary,
          ]);
        }
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('workspace-drawer')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          tester
              .widget<IconButton>(find.byKey(const ValueKey('sessions-create')))
              .onPressed,
          isNotNull,
        );
        await tester.tap(find.byKey(const ValueKey('sessions-create')));
        await tester.pumpAndSettle();
        expect(app.router.state.uri.path, '/sessions');
        expect(find.byKey(const ValueKey('workspace-draft')), findsOneWidget);
        expect(app.workspaceDrafts!.draft.text, '  first prompt\n');
        if (edited) app.workspaceDrafts!.draft.text = 'Later new message';
        outbox.holdAfterRecord!.complete();
        await tester.pumpAndSettle();
        expect(
          app.workspaceDrafts!.draft.text,
          edited ? 'Later new message' : '',
        );
        expect(actions.calls.where((call) => call == 'create'), hasLength(1));
        expect(
          outbox.calls.where((call) => call.startsWith('submit ')),
          hasLength(1),
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('New Chat from a live session settles its local draft', (
    tester,
  ) async {
    await open(tester);
    final summary = source.row('old', directory: '/work/alpha');
    app.router.go('/s/profile_a/ses_old');
    await waitFor(tester, () => directory.opens.isNotEmpty);
    final handle = directory.grant(summary.info.ref, outbox: FakeOutbox());
    handle.emit(
      SessionLiveView(
        session: summary.info.ref,
        phase: SessionLivePhase.live,
        state: liveState(summary.info.ref),
        lastSyncedAt: DateTime.utc(2026, 10, 25),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('workspace-drawer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sessions-create')));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, '/sessions');
    expect(find.byKey(const ValueKey('workspace-draft')), findsOneWidget);
    expect(app.workspaceDrafts!.loading, isFalse);
    expect(app.workspaceDrafts!.currentKey!.canonicalDirectory, '/work/alpha');
    expect(actions.calls.where((call) => call == 'create'), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Settings and Back preserve the active draft and text', (
    tester,
  ) async {
    await open(tester);
    await tester.pump(const Duration(milliseconds: 300));
    if (!source.tasks.last.completion.isCompleted) {
      source.respond([source.row('old', directory: '/work/alpha')]);
      await tester.pumpAndSettle();
    }
    await tester.enterText(
      find.byKey(const ValueKey('workspace-draft-text')),
      'Keep this draft',
    );
    await tester.pump();
    expect(app.workspaceDrafts!.canSend, isTrue);
    unawaited(app.router.push<void>('/settings'));
    await tester.pumpAndSettle();
    expect(app.workspaceDrafts!.canSend, isFalse);
    expect(
      await app.workspaceDrafts!.sendFirstPrompt(
        onBound: (_, _, _) => fail('Hidden draft must not send'),
      ),
      isFalse,
    );
    app.router.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('workspace-draft')), findsOneWidget);
    expect(app.workspaceDrafts!.draft.text, 'Keep this draft');
    expect(actions.calls.where((call) => call == 'create'), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reopening projects keeps edits before their debounce', (
    tester,
  ) async {
    await open(tester);
    final drafts = app.workspaceDrafts!;
    drafts.draft.text = 'Latest alpha text';
    await drafts.openDraft(directory: '/work/beta');
    expect(drafts.draft.text, isEmpty);
    drafts.draft.text = 'Latest beta text';
    await drafts.openDraft(directory: '/work/alpha');
    expect(drafts.draft.text, 'Latest alpha text');
    await drafts.openDraft(directory: '/work/alpha');
    expect(drafts.draft.text, 'Latest alpha text');
    await drafts.openDraft(directory: '/work/beta');
    expect(drafts.draft.text, 'Latest beta text');
    expect(actions.calls.where((call) => call == 'create'), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  for (final submission in [
    SubmissionKind.admitted,
    SubmissionKind.uncertain,
  ]) {
    testWidgets(
      'first send reads exact identity then submits once: $submission',
      (tester) async {
        await open(tester);
        await startSend(tester);
        expect(directory.opens, isEmpty);
        final id = app.workspaceDrafts!.entry!.fenceCommandId;
        final summary = source.row('created', directory: '/work/alpha');
        expect(source.reads.single.$1, summary.info.ref);
        source.reads.single.$2.completion.complete(summary);
        await waitFor(tester, () => directory.opens.isNotEmpty);
        final outbox = FakeOutbox()..submitState = submission;
        final handle = directory.grant(summary.info.ref, outbox: outbox);
        handle.emit(
          SessionLiveView(
            session: summary.info.ref,
            phase: SessionLivePhase.live,
            state: liveState(summary.info.ref),
            lastSyncedAt: DateTime.utc(2026, 10, 25),
          ),
        );
        await waitFor(tester, () => outbox.list.isNotEmpty);
        await tester.pump(const Duration(milliseconds: 200));
        expect(actions.calls.where((call) => call == 'create'), hasLength(1));
        expect(
          outbox.calls.where((call) => call.startsWith('submit ')),
          hasLength(1),
        );
        expect(outbox.list.single.commandId.value, id);
        expect(outbox.list.single.text, '  first prompt\n');
        expect(app.router.state.uri.path, '/s/profile_a/ses_created');
        expect(find.byKey(const ValueKey('session-tabs')), findsOneWidget);
        // The created session's tab follows the opened project's latest
        // one, and is the selected tab.
        expect(app.sessionTabs!.tabs.map((tab) => tab.ref), [
          source.row('old').info.ref,
          summary.info.ref,
        ]);
        expect(
          app.sessionTabs!.selectedFor(summary.info.ref.host),
          summary.info.ref,
        );
        expect(
          tester
              .widget<SessionLivePage>(find.byType(SessionLivePage))
              .controller
              .draft
              .text,
          isEmpty,
        );
        await store.flush();
        expect(
          await store.read(
            const WorkspaceDraftKey(
              profileId: 'profile_a',
              harnessId: 'profile_a',
              canonicalDirectory: '/work/alpha',
            ),
          ),
          isNull,
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'navigation during exact read keeps text and never takes over Settings',
    (tester) async {
      await open(tester);
      await startSend(tester);
      unawaited(app.router.push<void>('/settings'));
      await tester.pumpAndSettle();
      source.reads.single.$2.completion.complete(
        source.row('created', directory: '/work/alpha'),
      );
      await tester.pumpAndSettle();
      expect(app.router.state.uri.path, '/settings');
      expect(directory.opens, isEmpty);
      app.router.go('/sessions');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('workspace-draft')), findsOneWidget);
      expect(app.workspaceDrafts!.status, WorkspaceDraftStatus.uncertain);
      expect(app.workspaceDrafts!.draft.text, '  first prompt\n');
      expect(
        find.byKey(const ValueKey('workspace-draft-reset')),
        findsOneWidget,
      );
      final send = tester.widget<IconButton>(
        find.byKey(const ValueKey('workspace-draft-send')),
      );
      expect(send.onPressed, isNull);
      expect(actions.calls.where((call) => call == 'create'), hasLength(1));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'empty server requires an explicit absolute directory before send',
    (tester) async {
      await open(tester, empty: true);
      await tester.enterText(
        find.byKey(const ValueKey('workspace-draft-text')),
        'unspecified text',
      );
      await tester.enterText(
        find.byKey(const ValueKey('workspace-draft-directory')),
        'relative',
      );
      await tester.tap(
        find.byKey(const ValueKey('workspace-draft-project-confirm')),
      );
      await tester.pumpAndSettle();
      expect(actions.calls.where((call) => call == 'create'), isEmpty);
      expect(app.workspaceDrafts!.needsDirectory, isTrue);
      await tester.enterText(
        find.byKey(const ValueKey('workspace-draft-directory')),
        '/work/new',
      );
      await tester.tap(
        find.byKey(const ValueKey('workspace-draft-project-confirm')),
      );
      await tester.pumpAndSettle();
      expect(app.workspaceDrafts!.currentKey?.canonicalDirectory, '/work/new');
      expect(app.workspaceDrafts!.draft.text, 'unspecified text');
      expect(actions.calls.where((call) => call == 'create'), isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('the draft composer takes the focus only when asked', (
    tester,
  ) async {
    await open(tester);
    final field = find.byKey(const ValueKey('workspace-draft-text'));
    bool focused() =>
        tester.widget<TextField>(field).focusNode?.hasFocus ?? false;
    // Showing a draft never raises the keyboard by itself.
    expect(focused(), isFalse);
    app.workspaceDrafts!.focusComposer();
    await tester.pumpAndSettle();
    expect(focused(), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  for (final width in [360.0, 840.0]) {
    for (final language in ['ar', 'ur']) {
      testWidgets('draft fits width$width / $language / 2x', (tester) async {
        await open(
          tester,
          size: Size(width, 800),
          locale: Locale(language),
          scale: 2,
        );
        await tester.enterText(
          find.byKey(const ValueKey('workspace-draft-text')),
          'draft',
        );
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('workspace-draft-send')),
          findsOneWidget,
        );
        expect(actions.calls.where((call) => call == 'create'), isEmpty);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets(
    'a physical Enter sends the first prompt (#174)',
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
    (tester) async {
      await open(tester);
      await tester.pump(const Duration(milliseconds: 300));
      if (!source.tasks.last.completion.isCompleted) {
        source.respond([source.row('old', directory: '/work/alpha')]);
        await tester.pumpAndSettle();
      }
      actions.createdSessionRef = source
          .row('created', directory: '/work/alpha')
          .info
          .ref;
      final field = find.byKey(const ValueKey('workspace-draft-text'));
      await tester.tap(field);
      await tester.enterText(field, 'first prompt');
      await tester.pump();
      // Shift+Enter breaks the line instead.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(actions.calls.where((call) => call == 'create'), isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await waitFor(tester, () => actions.calls.contains('create'));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('the draft composer stays whole above the keyboard (#278)', (
    tester,
  ) async {
    const size = Size(360, 640);
    await open(tester, size: size);
    app.workspaceDrafts!.focusComposer();
    await tester.pumpAndSettle();
    // The keyboard opens: the harness's own media query carries it.
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: size,
          viewInsets: EdgeInsets.only(bottom: 300),
        ),
        child: CodeWalkV2Bootstrap(dependencies: app),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final visible = Rect.fromLTRB(0, 0, size.width, size.height - 300);
    for (final key in ['workspace-draft-text', 'workspace-draft-send']) {
      final box = tester.getRect(find.byKey(ValueKey(key)));
      expect(visible.contains(box.topLeft), isTrue, reason: key);
      expect(
        visible.contains(box.bottomRight - const Offset(1, 1)),
        isTrue,
        reason: key,
      );
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a / command on the draft runs locally, never as the first '
      'prompt (#137)', (tester) async {
    await open(tester);
    final text = find.byKey(const ValueKey('workspace-draft-text'));
    final send = find.byKey(const ValueKey('workspace-draft-send'));
    await tester.enterText(text, '/mo');
    await tester.pump();
    expect(find.byKey(const ValueKey('live-command-model')), findsOneWidget);
    await tester.enterText(text, '/model');
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This command works inside a conversation. Send a first message to '
        'start one.',
      ),
      findsOneWidget,
    );
    expect(app.workspaceDrafts!.draft.text, isEmpty);
    await tester.tap(find.byKey(const ValueKey('app-snack-bar-dismiss')));
    await tester.pumpAndSettle();

    await tester.enterText(text, '/thinking');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('live-command-thinking')));
    await tester.pumpAndSettle();
    expect(app.preferences.showReasoning, isFalse);
    expect(actions.calls.where((c) => c.startsWith('create')), isEmpty);
    expect(find.byKey(const ValueKey('workspace-draft')), findsOneWidget);
  });

  testWidgets('the draft picker keeps the field above the keyboard (#278)', (
    tester,
  ) async {
    const size = Size(360, 640);
    await open(tester, size: size);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: size,
          viewInsets: EdgeInsets.only(bottom: 300),
        ),
        child: CodeWalkV2Bootstrap(dependencies: app),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('workspace-draft-text')),
      '/',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('live-command-picker')), findsOneWidget);
    // Hit tests honour the page's clip: the field and the highlighted
    // command are really shown.
    for (final key in ['workspace-draft-text', 'live-command-new']) {
      expect(
        find.byKey(ValueKey(key)).hitTestable(),
        findsOneWidget,
        reason: key,
      );
    }
    await tester.pumpWidget(const SizedBox());
  });
}
