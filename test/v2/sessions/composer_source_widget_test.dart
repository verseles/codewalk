import 'package:codewalk/features/sessions/session_composer.dart';
import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/prompt_outbox.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'composer_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';

void main() {
  for (final (locale, width, scale, source) in [
    ('en', 390.0, 1.0, OutboxSource.changed),
    ('ar', 390.0, 2.0, OutboxSource.unknown),
    ('en', 1280.0, 2.0, OutboxSource.unknown),
    ('ur', 1280.0, 2.0, OutboxSource.changed),
  ]) {
    testWidgets(
      'local-only prompt remains inspectable and dismissible: $locale/$width/$scale',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final rig = CatalogRig();
        await rig.save('a');
        await rig.sessions.initialize();
        final directory = LiveDirectory();
        final summary = CatalogSource(profile('a')).row('one');
        final live = SessionLiveController(
          hosts: rig.hosts,
          profile: profile('a'),
          summary: summary,
          directory: directory,
        );
        final text = TextEditingController();
        final fullText = '${'Preserved local text. ' * 30}END';
        final outbox = FakeOutbox()
          ..list.add(
            entryOf(
              summary.info.ref,
              'old',
              'msg_0001',
              fullText,
              Delivery.queue,
              SubmissionKind.admitted,
              source: source,
            ),
          );
        final opening = live.start();
        final handle = directory.grant(live.session, outbox: outbox);
        await opening;
        handle.emit(
          SessionLiveView(
            session: live.session,
            phase: SessionLivePhase.live,
            state: liveState(live.session),
          ),
        );
        try {
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(locale),
              localizationsDelegates: V2Localizations.localizationsDelegates,
              supportedLocales: V2Localizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SessionComposer(
                  controller: live.composer,
                  text: text,
                  maxHeight: 600,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const ValueKey('live-row-check-old')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('live-row-again-old')),
            findsNothing,
          );
          final inspect = find.byKey(const ValueKey('live-row-inspect-old'));
          await tester.ensureVisible(inspect);
          await tester.tap(inspect);
          await tester.pumpAndSettle();
          expect(find.text(fullText), findsOneWidget);
          expect(tester.takeException(), isNull);
          final l10n = lookupV2Localizations(Locale(locale));
          await tester.tap(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.text(l10n.commonCancel),
            ),
          );
          await tester.pumpAndSettle();
          final discard = find.byKey(const ValueKey('live-row-discard-old'));
          await tester.ensureVisible(discard);
          await tester.tap(discard);
          await tester.pumpAndSettle();
          expect(outbox.calls, ['dismiss old']);
          expect(find.byKey(const ValueKey('live-row-old')), findsNothing);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          live.dispose();
          text.dispose();
          rig.dispose();
        }
      },
    );
  }
}
