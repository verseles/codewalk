import 'package:codewalk/features/sessions/message_forward_dialog.dart';
import 'package:codewalk/features/sessions/session_timeline_tile.dart';
import 'package:codewalk/features/sessions/sessions_controller.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_catalog_source.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/widgets/app_indeterminate_progress.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/gestures.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'composer_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';

// #542: picking the conversations a message goes to, and how it went.

void main() {
  late CatalogRig rig;
  late CatalogSource source;
  late FakeOutbox outbox;
  late List<SessionRef> opened;
  late Set<SessionRef> gone;

  setUp(() {
    outbox = FakeOutbox();
    opened = [];
    gone = {};
  });

  Future<SessionLiveHandle> open(SessionRef ref) async {
    opened.add(ref);
    if (gone.contains(ref)) {
      throw const SessionLiveException(SessionLiveFailure.notFound);
    }
    return LiveHandle(ref, outbox: outbox)..emit(
      SessionLiveView(
        session: ref,
        phase: SessionLivePhase.live,
        state: liveState(ref),
      ),
    );
  }

  List<SessionSummary> rows({bool one = true}) => [
    source.row('src', title: 'Source', directory: '/work/app'),
    if (one) source.row('one', title: 'Fix the build', directory: '/work/app'),
    source.row('two', title: 'Write docs', directory: '/work/app'),
    source.row('three', title: 'Ship it', directory: '/work/lib'),
  ];

  Future<void> pump(
    WidgetTester tester, {
    bool offline = false,
    bool fail = false,
    void Function(int count)? onDone,
  }) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    rig = CatalogRig();
    await rig.save('a');
    await rig.sessions.initialize();
    final loading = rig.sessions.selectProfile('profile_a');
    source = rig.sources.single;
    if (fail) {
      source.fail(SessionCatalogFailure.authenticationRequired);
    } else {
      source.respond(rows());
    }
    await loading;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: V2Localizations.localizationsDelegates,
        supportedLocales: V2Localizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => Dialog(
                  child: SizedBox(
                    width: 560,
                    height: 640,
                    child: ForwardMessageDialog(
                      source: source.row('src').info.ref,
                      catalog: rig.sessions,
                      contexts: null,
                      provenance: 'Forwarded from: app / Source',
                      text: 'hello there',
                      open: open,
                      offline: () => offline,
                      onDone: onDone,
                    ),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder target(String id) => find.byKey(
    ValueKey('forward_target_${source.row(id).info.ref.storageKey}'),
  );

  testWidgets('pick conversations by project, then forward to all', (
    tester,
  ) async {
    int? done;
    await pump(tester, onDone: (count) => done = count);
    expect(find.text('Forwarded from: app / Source'), findsOneWidget);
    expect(find.text('hello there'), findsOneWidget);
    // Grouped by project, without the source.
    expect(find.text('app'), findsOneWidget);
    expect(find.text('lib'), findsOneWidget);
    expect(find.text('Source'), findsNothing);
    final send = find.byKey(const ValueKey('forward_send'));
    expect(tester.widget<FilledButton>(send).onPressed, isNull);
    await tester.tap(target('one'));
    await tester.tap(target('three'));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);
    // The search keeps what was picked.
    await tester.enterText(
      find.byKey(const ValueKey('forward_search')),
      'docs',
    );
    await tester.pump();
    expect(target('one'), findsNothing);
    expect(target('two'), findsOneWidget);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(outbox.calls, hasLength(2));
    expect(
      outbox.calls.first,
      endsWith('queue Forwarded from: app / Source\n\nhello there'),
    );
    expect(done, 2);
    expect(find.byKey(const ValueKey('forward_send')), findsNothing);
  });

  testWidgets('a target not sent to stays listed, with Retry', (tester) async {
    await pump(tester);
    gone.add(source.row('one').info.ref);
    await tester.tap(target('one'));
    await tester.tap(target('two'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('forward_send')));
    await tester.pumpAndSettle();
    expect(find.text('Sent to 1 of 2'), findsOneWidget);
    expect(
      find.text('Not sent: the conversation is gone or archived'),
      findsOneWidget,
    );
    expect(find.text('Queued'), findsOneWidget);
    gone.clear();
    await tester.tap(find.byKey(const ValueKey('forward_retry')));
    await tester.pumpAndSettle();
    // Only the one not sent to goes again; then the dialog closes.
    expect(outbox.calls, hasLength(2));
    expect(find.byKey(const ValueKey('forward_results')), findsNothing);
  });

  testWidgets('Forward pressed twice sends once to each', (tester) async {
    await pump(tester);
    await tester.tap(target('one'));
    await tester.pump();
    final send = tester.widget<FilledButton>(
      find.byKey(const ValueKey('forward_send')),
    );
    send.onPressed!();
    send.onPressed!();
    await tester.pumpAndSettle();
    expect(
      outbox.calls.where((call) => call.startsWith('submit')),
      hasLength(1),
    );
  });

  testWidgets('a pick that leaves the list says it is gone', (tester) async {
    await pump(tester);
    await tester.tap(target('one'));
    await tester.tap(target('two'));
    await tester.pump();
    final refreshing = rig.sessions.refresh();
    source.respond(rows(one: false));
    await refreshing;
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('forward_send')));
    await tester.pumpAndSettle();
    expect(find.text('Sent to 1 of 2'), findsOneWidget);
    expect(
      find.text('Not sent: the conversation is gone or archived'),
      findsOneWidget,
    );
  });

  testWidgets('a list that cannot be read offers Retry', (tester) async {
    await pump(tester, fail: true);
    expect(find.byType(AppIndeterminateRing), findsNothing);
    expect(find.byKey(const ValueKey('forward_retry_load')), findsOneWidget);
  });

  testWidgets('offline, nothing can be forwarded', (tester) async {
    await pump(tester, offline: true);
    expect(find.text('The server is offline'), findsOneWidget);
    await tester.tap(target('one'));
    await tester.pump();
    final send = find.byKey(const ValueKey('forward_send'));
    expect(tester.widget<FilledButton>(send).onPressed, isNull);
  });

  testWidgets('Forward follows Copy, where conversations can be opened', (
    tester,
  ) async {
    rig = CatalogRig();
    await rig.save('a');
    await rig.sessions.initialize();
    final loading = rig.sessions.selectProfile('profile_a');
    source = rig.sources.single;
    final row = source.row('src', title: 'Source', directory: '/work/app');
    source.respond([row]);
    await loading;
    final item = AssistantText(
      meta: ItemMeta(
        id: const ItemId('test/a'),
        generation: 'test',
        status: const OpenValue.known(ItemStatus.completed),
        source: SourceProvenance(
          harness: HarnessRef(row.info.ref.host, row.info.ref.harness),
          version: '2.0.22',
          nativeType: 'test',
        ),
      ),
      text: 'the answer',
      complete: true,
    );
    Future<void> show({required bool live}) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<SessionLiveDirectory?>.value(
              value: live ? LiveDirectory() : null,
            ),
            ChangeNotifierProvider<SessionsController?>.value(
              value: rig.sessions,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: V2Localizations.localizationsDelegates,
            supportedLocales: V2Localizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => SessionTimelineTile(
                  item: item,
                  actions: [
                    ?forwardMessageAction(
                      context,
                      source: row,
                      profile: rig.sessions.selectedProfile!,
                      item: item,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('the answer'));
      await tester.pumpAndSettle();
      await tester.pump(kDoubleTapTimeout);
    }

    await show(live: true);
    final copy = tester.getCenter(
      find.byKey(const ValueKey('message-action-copy')),
    );
    final forward = tester.getCenter(
      find.byKey(const ValueKey('message-action-forward')),
    );
    expect(forward.dx, greaterThan(copy.dx));
    await show(live: false);
    expect(find.byKey(const ValueKey('message-action-forward')), findsNothing);
  });
}
