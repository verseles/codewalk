import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/session_live_page.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_stop.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../hosts/fakes.dart';
import 'composer_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    for (final locale in V2Localizations.supportedLocales) {
      testWidgets(
        'live read-only view from the catalog $size/${locale.languageCode}',
        (tester) async {
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
          await tester.pumpWidget(
            CodeWalkV2Bootstrap(dependencies: dependencies),
          );
          await tester.pumpAndSettle();
          final l10n = dependencies.localizations.current;
          final read = dependencies.sessions!.selectProfile('profile_a');
          final catalog = rig.sources.single;
          final row = catalog.row('one', title: '<b>Plain title</b>');
          catalog.respond([row]);
          await read;
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(ValueKey(row.info.ref)));
          await tester.pumpAndSettle();
          final button = find.byKey(
            ValueKey('live-open-${row.info.ref.storageKey}'),
          );
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pump();
          await tester.pump();
          expect(find.byType(SessionLivePage), findsOneWidget);
          expect(find.text(l10n.liveConnecting), findsWidgets);
          final ref = row.info.ref;
          final handle = directory.grant(ref);
          await tester.pump();
          handle.emit(
            SessionLiveView(
              session: ref,
              phase: SessionLivePhase.live,
              lastSyncedAt: DateTime.utc(2026, 10, 15, 12),
              state: liveState(
                ref,
                hasMore: true,
                // More history the lease cannot page in: the limit shows.
                cursor: 'older',
                execution: const ExecutionState(
                  kind: OpenValue.known(ExecutionKind.interruptedPendingResume),
                  lastOutcome: ExecutionOutcome(
                    OpenValue.known(ExecutionOutcomeKind.failed),
                  ),
                ),
                interactions: [
                  InteractionRequest(
                    id: const InteractionId('perm'),
                    owner: SessionOwner(ref),
                    kind: const OpenValue.known(InteractionKind.permission),
                    title: 'do-not-answer',
                  ),
                ],
                items: [
                  AssistantText(
                    meta: liveMeta(ref, 'a1'),
                    text: '<b>Bold body</b>',
                    complete: false,
                    prefixMissing: true,
                  ),
                  ToolCall(
                    meta: liveMeta(ref, 't1'),
                    kind: const OpenValue.known(ToolKind.read),
                    rawName: 'read',
                    output: CanonicalValue({'private': 'do-not-render'}),
                  ),
                  TurnOutcome(
                    meta: liveMeta(ref, 'o1'),
                    kind: const OpenValue.known(OutcomeKind.interrupted),
                  ),
                ],
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(l10n.liveLive), findsOneWidget);
          expect(find.text(l10n.liveResuming), findsOneWidget);
          expect(find.text(l10n.liveOutcomeFailed), findsOneWidget);
          expect(find.text(l10n.liveOutcomeInterrupted), findsOneWidget);
          expect(find.byKey(const ValueKey('live-needs-you')), findsOneWidget);
          expect(find.text(l10n.historyLimit), findsOneWidget);
          expect(find.textContaining(l10n.liveLastSynced), findsOneWidget);
          // V2-071A: <b> renders rich (bold) with … prefix, not literal tags.
          expect(find.textContaining('Bold body'), findsWidgets);
          expect(find.text('…<b>Bold body</b>'), findsNothing);
          expect(find.textContaining('do-not-render'), findsNothing);
          expect(find.textContaining('do-not-answer'), findsNothing);
          expect(find.byType(TextField), findsNothing);
          expect(find.byKey(const ValueKey('live-composer')), findsOneWidget);
          expect(find.byKey(const ValueKey('live-retry')), findsNothing);
          final status = find.byKey(const ValueKey('live-status'));
          expect(tester.getSemantics(status), isNotNull);
          // The clock changes on every event; only phase changes announce.
          expect(
            find.descendant(
              of: status,
              matching: find.textContaining(l10n.liveLastSynced),
            ),
            findsNothing,
          );

          // Stop does not depend on a prompt ledger, and shutdown-resuming
          // above never offered it. Keep the projected partial output.
          expect(find.byKey(const ValueKey('live-stop')), findsNothing);
          handle.stopAvailable = true;
          handle.stopAction = (_) async =>
              const SessionStopState(phase: SessionStopPhase.idle);
          handle.emit(
            SessionLiveView(
              session: ref,
              phase: SessionLivePhase.live,
              state: liveState(
                ref,
                items: handle.current.state!.timeline,
                execution: const ExecutionState(
                  kind: OpenValue.known(ExecutionKind.running),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final stop = find.byKey(const ValueKey('live-stop'));
          expect(stop, findsOneWidget);
          await tester.tap(stop);
          await tester.pumpAndSettle();
          expect(handle.stops, hasLength(1));
          expect(find.text(l10n.liveStopIdle), findsOneWidget);
          expect(find.textContaining('Bold body'), findsWidgets);

          // A set-aside session keeps its resident state visible, marked stale.
          handle.emit(
            SessionLiveView(
              session: ref,
              phase: SessionLivePhase.degraded,
              failure: SessionLiveFailure.unavailable,
              stale: true,
              lastSyncedAt: DateTime.utc(2026, 10, 15, 12),
              state: handle.current.state,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(l10n.liveStale), findsOneWidget);
          // A session set aside says so, not that it never opened.
          expect(find.text(l10n.liveDegraded), findsOneWidget);
          expect(find.text(l10n.liveUnavailable), findsNothing);
          expect(find.textContaining('Bold body'), findsWidgets);
          final retry = find.byKey(const ValueKey('live-retry'));
          expect(retry, findsOneWidget);
          await tester.tap(retry);
          await tester.pump();
          expect(directory.opens, hasLength(2));
          expect(handle.closes, 1);
          final again = directory.grant(ref);

          final context = tester.element(find.byType(SessionLivePage));
          expect(
            Directionality.of(context),
            {'ar', 'ur'}.contains(locale.languageCode)
                ? TextDirection.rtl
                : TextDirection.ltr,
          );
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.byType(SessionLivePage), findsNothing);
          expect(again.closes, 1);
          expect(
            dependencies.router.routeInformationProvider.value.uri.path,
            '/sessions',
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          expect(directory.closes, 1);
          rig.dispose();
        },
      );
    }
  }
  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final locale in V2Localizations.supportedLocales) {
      testWidgets('live composer $size/${locale.languageCode}', (tester) async {
        // The catalog is reached upright; the live screen is checked at
        // [size].
        tester.view.physicalSize = size.width > size.height
            ? size.flipped
            : size;
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
        await tester.pumpWidget(
          CodeWalkV2Bootstrap(dependencies: dependencies),
        );
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
        final button = find.byKey(
          ValueKey('live-open-${row.info.ref.storageKey}'),
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
        await tester.pump();
        tester.view.physicalSize = size;
        final ref = row.info.ref;
        final long = 'A long queued message ' * 20;
        final outbox = FakeOutbox()
          ..list.addAll([
            entryOf(
              ref,
              'mine',
              'msg_0001',
              long,
              Delivery.queue,
              SubmissionKind.admitted,
            ),
            entryOf(
              ref,
              'lost',
              'msg_0003',
              'Lost',
              Delivery.steer,
              SubmissionKind.uncertain,
            ),
          ]);
        final handle = directory.grant(ref, outbox: outbox);
        await tester.pump();
        handle.emit(
          SessionLiveView(
            session: ref,
            phase: SessionLivePhase.live,
            lastSyncedAt: DateTime.utc(2026, 10, 15, 12),
            state: liveState(
              ref,
              pending: [
                pendingRow(ref, 'msg_0001', long),
                pendingRow(ref, 'msg_0002', 'Theirs', delivery: Delivery.steer),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (size.width > size.height) {
          // A keyboard over a landscape phone leaves the body little room.
          tester.view.viewInsets = const FakeViewPadding(bottom: 200);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // The field and its send button stay whole above the keyboard.
          final visible = Rect.fromLTRB(0, 0, size.width, size.height - 200);
          for (final key in ['live-composer-input', 'live-composer-send']) {
            final box = tester.getRect(find.byKey(ValueKey(key)));
            expect(visible.contains(box.topLeft), isTrue, reason: key);
            expect(
              visible.contains(box.bottomRight - const Offset(1, 1)),
              isTrue,
              reason: key,
            );
            expect(box.height, greaterThanOrEqualTo(40), reason: key);
          }
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();
        }
        expect(find.text(l10n.composerLiveSession), findsOneWidget);
        expect(find.text(l10n.liveSendUnavailable), findsNothing);
        expect(find.byKey(const ValueKey('live-composer')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('live-chip-cancel-mine')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('live-chip-switch-mine')),
          findsOneWidget,
        );
        expect(find.textContaining(l10n.composerOtherClient), findsOneWidget);
        expect(
          find.byKey(const ValueKey('live-row-check-lost')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('live-row-again-lost')),
          findsOneWidget,
        );
        expect(
          Directionality.of(tester.element(find.byType(TextField))),
          locale.languageCode == 'ar' || locale.languageCode == 'ur'
              ? TextDirection.rtl
              : TextDirection.ltr,
        );
        final send = find.byKey(const ValueKey('live-composer-send'));
        await tester.tap(find.byKey(const ValueKey('live-delivery-queue')));
        await tester.enterText(find.byType(TextField), 'Hello');
        await tester.pump();
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(
          outbox.calls.where((c) => c.startsWith('submit')).single,
          endsWith(' queue Hello'),
        );
        expect(find.text('Hello'), findsNothing);
        final cancel = find.byKey(const ValueKey('live-chip-cancel-mine'));
        await tester.ensureVisible(cancel);
        await tester.pumpAndSettle();
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(outbox.calls, contains('cancel mine'));
        expect(tester.takeException(), isNull);

        // All 14 locales and three layouts exercise the v1-style Send/Stop
        // slot swap, without changing draft text or canonical execution.
        handle.stopAvailable = true;
        handle.stopAction = (_) async =>
            const SessionStopState(phase: SessionStopPhase.idle);
        handle.emit(
          SessionLiveView(
            session: ref,
            phase: SessionLivePhase.live,
            state: liveState(
              ref,
              execution: const ExecutionState(
                kind: OpenValue.known(ExecutionKind.running),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('live-stop')), findsOneWidget);
        expect(find.byKey(const ValueKey('live-composer-send')), findsNothing);
        await tester.enterText(find.byType(TextField), 'Keep');
        await tester.pump();
        expect(find.byKey(const ValueKey('live-stop')), findsNothing);
        expect(
          find.byKey(const ValueKey('live-composer-send')),
          findsOneWidget,
        );
        await tester.enterText(find.byType(TextField), '');
        // Focus scrolls the field into view asynchronously. Let that scroll
        // settle before hit-testing the replacement trailing action.
        await tester.pumpAndSettle();
        final stopRect = tester.getRect(
          find.byKey(const ValueKey('live-stop')),
        );
        expect((Offset.zero & size).contains(stopRect.center), isTrue);
        await tester.tap(find.byKey(const ValueKey('live-stop')));
        await tester.pumpAndSettle();
        expect(handle.stops, hasLength(1));
        expect(find.text(l10n.liveStopIdle), findsOneWidget);
        expect(find.text(l10n.liveRunning), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (locale.languageCode != 'en') return;
        await tester.enterText(find.byType(TextField), 'Keep');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(find.text(l10n.liveStopEscapeHint), findsOneWidget);
        expect(handle.stops, hasLength(1));
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(handle.stops, hasLength(2));
        expect(find.text('Keep'), findsOneWidget);
        // A draft survives a reopened lease.
        await tester.enterText(find.byType(TextField), 'Draft');
        handle.emit(
          SessionLiveView(
            session: ref,
            phase: SessionLivePhase.degraded,
            failure: SessionLiveFailure.unavailable,
          ),
        );
        await tester.pumpAndSettle();
        final retry = find.byKey(const ValueKey('live-retry'));
        await tester.ensureVisible(retry);
        await tester.tap(retry);
        await tester.pump();
        expect(find.byType(TextField), findsNothing);
        final again = directory.grant(ref, outbox: outbox);
        await tester.pump();
        again.emit(
          SessionLiveView(
            session: ref,
            phase: SessionLivePhase.live,
            lastSyncedAt: DateTime.utc(2026, 10, 15, 12),
            state: liveState(ref),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Draft'), findsOneWidget);
      });
    }
  }
}
