import 'package:codewalk/app/app_dependencies.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/session_live_page.dart';
import 'package:codewalk/platform/sessions/session_draft_store.dart';
import 'package:codewalk/platform/sessions/workspace_draft_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/platform/storage/payload_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';

import '../hosts/fakes.dart';
import '../storage/storage_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';

typedef _App = ({
  AppDependencies dependencies,
  V2Localizations l10n,
  CatalogRig rig,
  LiveDirectory directory,
});

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The app on the parent session, live, with [tools] in its timeline.
Future<_App> _launch(
  WidgetTester tester, {
  Size size = const Size(1280, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final rig = CatalogRig();
  addTearDown(rig.dispose);
  await rig.save('a');
  final directory = LiveDirectory();
  final metadata = V2MetadataStore(backend: FakeMetadataBackend());
  final payloads = PreferencesPayloadStore(metadata);
  final dependencies = createAppDependencies(
    initialLink: Uri.parse('/s/profile_a/ses_parent'),
    metadataStore: metadata,
    profileRepository: rig.repository,
    endpointProber: FakeProber(),
    sessionCatalogFactory: rig.create,
    sessionLiveDirectory: () => directory,
    draftStore: SessionDraftStore(payloads: payloads, index: metadata),
    workspaceDraftStore: WorkspaceDraftStore(
      payloads: payloads,
      index: metadata,
    ),
  );
  // The same root as the relaunches with another text size, so those keep
  // the app's controllers.
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData.fromView(tester.view),
      child: CodeWalkV2Bootstrap(dependencies: dependencies),
    ),
  );
  await _settle(tester);
  final source = rig.sources.single;
  source.respond([source.row('parent', title: 'Parent', directory: '/w')]);
  await _settle(tester);
  return (
    dependencies: dependencies,
    l10n: dependencies.localizations.current,
    rig: rig,
    directory: directory,
  );
}

SessionRef _ref(_App app, String id) => app.rig.sources.single.row(id).info.ref;

/// Grants the open view of [id] and shows [items] in it, live.
Future<LiveHandle> _show(
  WidgetTester tester,
  _App app,
  String id,
  List<TimelineItem> items, {
  bool hasMore = false,
}) async {
  final ref = _ref(app, id);
  final source = app.rig.sources.single;
  for (final (read, task) in source.reads.toList()) {
    if (read != ref || task.completion.isCompleted) continue;
    task.completion.complete(
      source.served.firstWhere(
        (row) => row.info.ref == ref,
        orElse: () => _child(app, id),
      ),
    );
    await _settle(tester);
  }
  final handle = app.directory.grant(ref);
  await tester.pump();
  handle.emit(
    SessionLiveView(
      session: ref,
      phase: SessionLivePhase.live,
      state: liveState(ref, items: items, hasMore: hasMore),
    ),
  );
  await _settle(tester);
  return handle;
}

ToolCall _tool(
  _App app,
  String id, {
  String? child,
  ToolChildEvidenceKind? evidence,
}) {
  final meta = liveMeta(_ref(app, 'parent'), id);
  return ToolCall(
    meta: meta,
    kind: const OpenValue.known(ToolKind.subagent),
    rawName: 'subagent',
    child: child == null ? null : _ref(app, child),
    childEvidence: evidence == null
        ? null
        : ToolChildEvidence(
            kind: evidence,
            origin: meta.source,
            generation: meta.generation,
          ),
  );
}

/// A child of the parent created at [created] seconds.
SessionSummary _child(
  _App app,
  String id, {
  String parent = 'parent',
  int created = 1,
}) {
  final row = app.rig.sources.single.row(id, parent: parent, directory: '/w');
  return SessionSummary(
    info: row.info,
    updatedAt: row.updatedAt,
    createdAt: DateTime.utc(2026, 10, 12, 0, 0, created),
  );
}

String _location(_App app) =>
    app.dependencies.router.routerDelegate.currentConfiguration.uri.toString();

Future<void> _tap(WidgetTester tester, ToolCall tool) async {
  final card = find.byKey(ValueKey('subagent-open-${tool.id.value}'));
  await tester.ensureVisible(card);
  await tester.tap(card);
  await tester.pump();
}

/// Answers the newest read of [id] with [row].
Future<void> _answerRead(
  WidgetTester tester,
  _App app,
  String id,
  SessionSummary row,
) async {
  final ref = _ref(app, id);
  final (_, task) = app.rig.sources.single.reads.lastWhere(
    (read) => read.$1 == ref && !read.$2.completion.isCompleted,
  );
  task.completion.complete(row);
  await _settle(tester);
}

/// Answers the newest child list with [rows].
Future<void> _answerChildren(
  WidgetTester tester,
  _App app,
  List<SessionSummary> rows,
) async {
  final source = app.rig.sources.single;
  final at = source.queries.lastIndexWhere((query) => query.parent != null);
  expect(at, greaterThanOrEqualTo(0));
  expect(source.queries[at].parent, _ref(app, 'parent'));
  source.tasks[at].completion.complete(Page(items: rows));
  await _settle(tester);
}

void main() {
  testWidgets('an observed child opens after its direct read', (tester) async {
    final app = await _launch(tester);
    final tool = _tool(
      app,
      't1',
      child: 'kid',
      evidence: ToolChildEvidenceKind.observed,
    );
    await _show(tester, app, 'parent', [tool]);

    await _tap(tester, tool);
    // No list: the call names its child.
    expect(
      app.rig.sources.single.queries.where((q) => q.parent != null),
      isEmpty,
    );
    await _answerRead(tester, app, 'kid', _child(app, 'kid'));
    expect(_location(app), '/s/profile_a/ses_kid');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a named session that is not a direct child stays closed', (
    tester,
  ) async {
    final app = await _launch(tester);
    final tool = _tool(
      app,
      't1',
      child: 'kid',
      evidence: ToolChildEvidenceKind.observed,
    );
    await _show(tester, app, 'parent', [tool]);

    await _tap(tester, tool);
    await _answerRead(tester, app, 'kid', _child(app, 'kid', parent: 'other'));
    expect(_location(app), '/s/profile_a/ses_parent');
    expect(find.text(app.l10n.chatNoSubConversationFound), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a refused child never falls back to the list', (tester) async {
    final app = await _launch(tester);
    final tool = _tool(app, 't1', evidence: ToolChildEvidenceKind.rejected);
    await _show(tester, app, 'parent', [tool]);

    await _tap(tester, tool);
    await _settle(tester);
    final source = app.rig.sources.single;
    expect(source.queries.where((q) => q.parent != null), isEmpty);
    expect(find.text(app.l10n.chatNoSubConversationFound), findsOneWidget);
    expect(_location(app), '/s/profile_a/ses_parent');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the only child opens even beside several calls', (tester) async {
    final app = await _launch(tester);
    final first = _tool(app, 't1');
    await _show(tester, app, 'parent', [first, _tool(app, 't2')]);

    await _tap(tester, first);
    await _answerChildren(tester, app, [_child(app, 'kid')]);
    await _answerRead(tester, app, 'kid', _child(app, 'kid'));
    expect(_location(app), '/s/profile_a/ses_kid');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('calls pair with children by creation only on whole sets', (
    tester,
  ) async {
    final app = await _launch(tester);
    final first = _tool(app, 't1');
    final second = _tool(app, 't2');
    final children = [
      _child(app, 'late', created: 9),
      _child(app, 'early', created: 2),
    ];
    final handle = await _show(tester, app, 'parent', [first, second]);

    await _tap(tester, second);
    await _answerChildren(tester, app, children);
    await _answerRead(tester, app, 'late', children.first);
    expect(_location(app), '/s/profile_a/ses_late');

    // Older history may hold more calls: no pairing.
    app.dependencies.router.go('/s/profile_a/ses_parent');
    await _settle(tester);
    handle.emit(
      SessionLiveView(
        session: _ref(app, 'parent'),
        phase: SessionLivePhase.live,
        state: liveState(
          _ref(app, 'parent'),
          items: [first, second],
          hasMore: true,
        ),
      ),
    );
    await _settle(tester);
    await _tap(tester, second);
    await _answerChildren(tester, app, children);
    expect(_location(app), '/s/profile_a/ses_parent');
    expect(find.text(app.l10n.chatNoSubConversationFound), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a sibling that contradicts a pending pairing cancels it', (
    tester,
  ) async {
    final app = await _launch(tester);
    final first = _tool(app, 't1');
    final second = _tool(app, 't2');
    final children = [
      _child(app, 'late', created: 9),
      _child(app, 'early', created: 2),
    ];
    final handle = await _show(tester, app, 'parent', [first, second]);

    await _tap(tester, second);
    // While the children are read, the first call names the later child.
    final parent = _ref(app, 'parent');
    final contradicting = ToolCall(
      meta: first.meta,
      kind: first.kind,
      rawName: first.rawName,
      child: _ref(app, 'late'),
      childEvidence: ToolChildEvidence(
        kind: ToolChildEvidenceKind.observed,
        origin: first.meta.source,
        generation: first.generation,
      ),
    );
    handle.emit(
      SessionLiveView(
        session: parent,
        phase: SessionLivePhase.live,
        state: liveState(parent, items: [contradicting, second]),
      ),
    );
    await _settle(tester);
    await _answerChildren(tester, app, children);
    await _answerRead(tester, app, 'late', children.first);
    expect(_location(app), '/s/profile_a/ses_parent');
    expect(find.text(app.l10n.chatNoSubConversationFound), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('navigating away cancels the pending lookup', (tester) async {
    final app = await _launch(tester);
    final tool = _tool(app, 't1');
    await _show(tester, app, 'parent', [tool, _tool(app, 't2')]);

    await _tap(tester, tool);
    final source = app.rig.sources.single;
    final at = source.queries.lastIndexWhere((query) => query.parent != null);
    app.dependencies.router.go('/settings');
    await _settle(tester);
    expect(source.tasks[at].cancelled, isTrue);
    expect(_location(app), '/settings');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a child returns to its parent and keeps its choice locked', (
    tester,
  ) async {
    final app = await _launch(tester);
    final tool = _tool(
      app,
      't1',
      child: 'kid',
      evidence: ToolChildEvidenceKind.observed,
    );
    await _show(tester, app, 'parent', [tool]);
    await _tap(tester, tool);
    await _answerRead(tester, app, 'kid', _child(app, 'kid'));
    await _show(tester, app, 'kid', const []);

    final live = tester.widget<SessionLivePage>(find.byType(SessionLivePage));
    expect(live.controller.isChild, isTrue);
    expect(live.controller.canChangeSelection, isFalse);
    final back = find.byKey(const ValueKey('subconversation-return'));
    expect(back, findsOneWidget);
    expect(find.text(app.l10n.chatReturnToParentConversation), findsOneWidget);
    await tester.tap(back);
    await _settle(tester);
    expect(_location(app), '/s/profile_a/ses_parent');
    expect(back, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the parent shows the same rows again after it grew', (
    tester,
  ) async {
    final app = await _launch(tester, size: const Size(390, 844));
    final parent = _ref(app, 'parent');
    final tool = _tool(
      app,
      't1',
      child: 'kid',
      evidence: ToolChildEvidenceKind.observed,
    );
    List<TimelineItem> rows(int count) => [
      tool,
      for (var i = 0; i < count; i++)
        AssistantText(
          meta: liveMeta(parent, 'a$i'),
          text: 'row $i',
          complete: true,
        ),
    ];
    final handle = await _show(tester, app, 'parent', rows(40));
    await tester.dragUntilVisible(
      find.text('row 10'),
      find.byType(CustomScrollView),
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();
    final reading = tester.getTopLeft(find.text('row 10')).dy;

    // Open the child from its card's own route, as the card does.
    app.dependencies.router.go('/s/profile_a/ses_kid');
    await _settle(tester);
    await _show(tester, app, 'kid', const []);
    // The parent keeps working while the reader is away.
    handle.emit(
      SessionLiveView(
        session: parent,
        phase: SessionLivePhase.live,
        state: liveState(parent, items: rows(55)),
      ),
    );
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('subconversation-return')));
    await tester.pumpAndSettle();
    expect(_location(app), '/s/profile_a/ses_parent');
    expect(tester.getTopLeft(find.text('row 10')).dy, reading);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the return control fits a short phone at 2x text', (
    tester,
  ) async {
    final app = await _launch(tester, size: const Size(360, 480));
    final tool = _tool(
      app,
      't1',
      child: 'kid',
      evidence: ToolChildEvidenceKind.observed,
    );
    await _show(tester, app, 'parent', [tool]);
    await _tap(tester, tool);
    await _answerRead(tester, app, 'kid', _child(app, 'kid'));
    for (final language in ['en', 'ar']) {
      app.dependencies.preferences.setLocale(Locale(language));
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData.fromView(
            tester.view,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: CodeWalkV2Bootstrap(dependencies: app.dependencies),
        ),
      );
      await _settle(tester);
    }
    await _show(tester, app, 'kid', const []);
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('subconversation-return')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('on a phone, back walks from the child to its parent', (
    tester,
  ) async {
    final app = await _launch(tester, size: const Size(390, 844));
    final tool = _tool(
      app,
      't1',
      child: 'kid',
      evidence: ToolChildEvidenceKind.observed,
    );
    await _show(tester, app, 'parent', [tool]);
    await _tap(tester, tool);
    await _answerRead(tester, app, 'kid', _child(app, 'kid'));
    await _show(tester, app, 'kid', const []);

    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(_location(app), '/s/profile_a/ses_parent');
    // At the root the next back opens the drawer.
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(_location(app), '/s/profile_a/ses_parent');
    expect(
      tester.firstState<ScaffoldState>(find.byType(Scaffold)).isDrawerOpen,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
