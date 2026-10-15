import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/session_live_page.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../hosts/fakes.dart';
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
                    text: '<b>Plain body</b>',
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
          expect(find.text('…<b>Plain body</b>'), findsOneWidget);
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
          expect(find.text('…<b>Plain body</b>'), findsOneWidget);
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
}
