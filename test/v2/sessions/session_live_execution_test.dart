import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/features/sessions/session_live_page.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'live_fakes.dart';

/// The live header's execution chip: each state's label, and a retry wait
/// counted down only from the deadline the harness reported.
void main() {
  late DateTime now;
  late CatalogRig rig;
  late LiveDirectory directory;
  late SessionLiveController live;
  late SessionRef ref;
  final ticking = ValueNotifier(true);

  Future<LiveHandle> mount(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    double scale = 1,
  }) async {
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
      now: () => now,
    );
    addTearDown(rig.dispose);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: V2Localizations.localizationsDelegates,
        supportedLocales: V2Localizations.supportedLocales,
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: scale,
          maxScaleFactor: scale,
          child: child!,
        ),
        home: ValueListenableBuilder(
          valueListenable: ticking,
          builder: (context, enabled, child) =>
              TickerMode(enabled: enabled, child: child!),
          child: SessionLivePage(controller: live),
        ),
      ),
    );
    await tester.pump();
    final handle = directory.grant(ref);
    await tester.pump();
    return handle;
  }

  Future<void> show(
    WidgetTester tester,
    LiveHandle handle,
    ExecutionState execution,
  ) async {
    handle.emit(
      SessionLiveView(
        session: ref,
        phase: SessionLivePhase.live,
        state: liveState(ref, execution: execution),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  String chip(WidgetTester tester) => tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('live-execution')),
          matching: find.byType(Text),
        ),
      )
      .data!;

  ErrorInfo error() => ErrorInfo(
    kind: const OpenValue.known(ErrorKind.unknown),
    rawType: 'provider.rate-limit',
    rawMessage: '',
  );

  setUp(() {
    now = DateTime.utc(2026, 10, 22, 12);
    ticking.value = true;
  });

  testWidgets('each execution state has its own label', (tester) async {
    final handle = await mount(tester);
    final l10n = await V2Localizations.delegate.load(const Locale('en'));
    for (final (kind, label) in [
      (ExecutionKind.running, l10n.liveRunning),
      (ExecutionKind.retrying, l10n.liveRetrying),
      (ExecutionKind.interrupting, l10n.liveStopping),
      (ExecutionKind.interruptedPendingResume, l10n.liveResuming),
      (ExecutionKind.waitingForInput, l10n.liveNeedsYou),
      (ExecutionKind.idle, l10n.liveIdle),
    ]) {
      await show(tester, handle, ExecutionState(kind: OpenValue.known(kind)));
      expect(chip(tester), label, reason: kind.name);
    }
  });

  testWidgets('a reported retry wait counts down, then reads Retrying', (
    tester,
  ) async {
    final handle = await mount(tester);
    final l10n = await V2Localizations.delegate.load(const Locale('en'));
    await show(
      tester,
      handle,
      ExecutionState(
        kind: const OpenValue.known(ExecutionKind.retrying),
        retryAt: now.add(const Duration(seconds: 65, milliseconds: 500)),
        error: error(),
      ),
    );
    expect(chip(tester), l10n.liveRetryingIn('1:06'));
    now = now.add(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(chip(tester), l10n.liveRetryingIn('1:05'));
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(chip(tester), l10n.liveRetryingIn('1:04'));
    now = now.add(const Duration(seconds: 64));
    await tester.pump(const Duration(seconds: 64));
    expect(chip(tester), l10n.liveRetrying);

    // Hours stay readable; a wait already past shows no count.
    await show(
      tester,
      handle,
      ExecutionState(
        kind: const OpenValue.known(ExecutionKind.retrying),
        retryAt: now.add(const Duration(hours: 2, minutes: 3, seconds: 4)),
        error: error(),
      ),
    );
    expect(chip(tester), l10n.liveRetryingIn('2:03:04'));
    await show(
      tester,
      handle,
      ExecutionState(
        kind: const OpenValue.known(ExecutionKind.retrying),
        retryAt: now.subtract(const Duration(seconds: 1)),
        error: error(),
      ),
    );
    expect(chip(tester), l10n.liveRetrying);
    // The next step start ends the wait.
    await show(
      tester,
      handle,
      const ExecutionState(kind: OpenValue.known(ExecutionKind.running)),
    );
    expect(chip(tester), l10n.liveRunning);
  });

  testWidgets('the count pauses while the page does not tick', (tester) async {
    final handle = await mount(tester);
    final l10n = await V2Localizations.delegate.load(const Locale('en'));
    await show(
      tester,
      handle,
      ExecutionState(
        kind: const OpenValue.known(ExecutionKind.retrying),
        retryAt: now.add(const Duration(seconds: 30)),
        error: error(),
      ),
    );
    expect(chip(tester), l10n.liveRetryingIn('0:30'));
    ticking.value = false;
    await tester.pump();
    now = now.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    expect(chip(tester), l10n.liveRetryingIn('0:30'));
    ticking.value = true;
    await tester.pump();
    expect(chip(tester), l10n.liveRetryingIn('0:25'));
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(chip(tester), l10n.liveRetryingIn('0:24'));
  });

  testWidgets('an idle parent shows how many of its sub-agents run', (
    tester,
  ) async {
    final handle = await mount(tester);
    final l10n = await V2Localizations.delegate.load(const Locale('en'));
    WorkItem child(String id, WorkStatus status) {
      final session = SessionRef(ref.host, ref.harness, id);
      return WorkItem(
        id: WorkId(id),
        owner: SessionOwner(session, origin: ref),
        child: session,
        parent: ref,
        status: OpenValue.known(status),
        completionScope: const OpenValue.known(CompletionScope.child),
      );
    }

    handle.emit(
      SessionLiveView(
        session: ref,
        phase: SessionLivePhase.live,
        state: liveState(
          ref,
          execution: const ExecutionState(
            kind: OpenValue.known(ExecutionKind.idle),
          ),
          work: [
            child('ses_c1', WorkStatus.running),
            child('ses_c2', WorkStatus.running),
            child('ses_c3', WorkStatus.completed),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(chip(tester), l10n.liveIdle);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('live-children')),
        matching: find.text(l10n.liveChildrenRunning(2)),
      ),
      findsOneWidget,
    );
    await show(
      tester,
      handle,
      const ExecutionState(kind: OpenValue.known(ExecutionKind.idle)),
    );
    expect(find.byKey(const ValueKey('live-children')), findsNothing);
  });

  for (final locale in const [Locale('ar'), Locale('pt')]) {
    testWidgets('the wait reads in ${locale.languageCode} at 2x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handle = await mount(tester, locale: locale, scale: 2);
      final l10n = await V2Localizations.delegate.load(locale);
      await show(
        tester,
        handle,
        ExecutionState(
          kind: const OpenValue.known(ExecutionKind.retrying),
          retryAt: now.add(const Duration(seconds: 42)),
          error: error(),
        ),
      );
      expect(chip(tester), l10n.liveRetryingIn('0:42'));
      expect(tester.takeException(), isNull);
    });
  }
}
