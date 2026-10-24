import 'package:codewalk/app/app_navigation_controller.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/session_history_page.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../hosts/fakes.dart';
import 'fakes.dart';
import 'history_fakes.dart';
import 'live_fakes.dart';
import 'workspace_support.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    for (final locale in V2Localizations.supportedLocales) {
      testWidgets(
        'auxiliary history entry Back and unknown markers $size/${locale.languageCode}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final rig = CatalogRig();
          await rig.save('a');
          final sources = <HistorySource>[];
          final dependencies = createAppDependencies(
            initialLink: Uri(path: '/sessions'),
            profileRepository: rig.repository,
            endpointProber: FakeProber(),
            sessionCatalogFactory: rig.create,
            sessionLiveDirectory: LiveDirectory.new,
            sessionHistoryFactory: (p, c, ref) {
              final source = HistorySource(ref);
              sources.add(source);
              return source;
            },
          );
          dependencies.preferences.setLocale(locale);
          await tester.pumpWidget(
            CodeWalkV2Bootstrap(dependencies: dependencies),
          );
          await showSessionList(tester);
          // An earlier opaque session intent must not select or start this reader.
          dependencies.navigation.prepareLink(
            Uri.parse('codewalk://s/opaque/pending'),
          );
          final intent = dependencies.navigation.pendingIntent;
          expect(intent, isA<SessionNavigationIntent>());
          final read = dependencies.sessions!.selectProfile('profile_a');
          final catalog = rig.sources.single;
          final row = catalog.row('one', title: '<b>Plain title</b>');
          catalog.respond([row]);
          await read;
          await tester.pumpAndSettle();
          // The row's menu holds its read-only history.
          await tester.longPress(
            find.byKey(ValueKey('live-open-${row.info.ref.storageKey}')),
          );
          await tester.pumpAndSettle();
          final button = find.byKey(
            ValueKey('history-open-${row.info.ref.storageKey}'),
          );
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pump();
          final source = sources.single;
          source.respond([
            source.item(1, text: '<b>Bold body</b>'),
            UserInput(
              meta: source.meta(2),
              text: 'User text',
              delivery: OpenValue.unknown('not observed'),
            ),
            Reasoning(
              meta: source.meta(3),
              text: 'Reasoning text',
              complete: false,
            ),
            Notice(
              meta: source.meta(4),
              kind: const OpenValue.known(NoticeKind.system),
              text: 'Notice text',
            ),
            ToolCall(
              meta: source.meta(5),
              kind: const OpenValue.known(ToolKind.read),
              rawName: 'read',
              output: CanonicalValue({'private': 'do-not-render'}),
            ),
            UnknownItem(
              meta: source.meta(6),
              rawType: 'future',
              raw: CanonicalValue({'hidden': 'do-not-render'}),
            ),
            TurnOutcome(
              meta: source.meta(7),
              kind: const OpenValue.known(OutcomeKind.succeeded),
            ),
            ShellRun(meta: source.meta(8), command: 'do-not-execute'),
          ]);
          await tester.pumpAndSettle();
          expect(find.byType(SessionHistoryPage), findsOneWidget);
          expect(find.byType(NavigationBar), findsNothing);
          expect(find.byType(NavigationRail), findsNothing);
          // V2-071A: <b> is rich (bold), not literal; unsafe tags stay literal.
          expect(find.textContaining('Bold body'), findsWidgets);
          expect(find.text('<b>Bold body</b>'), findsNothing);
          if (locale.languageCode == 'en' && size.width == 1280) {
            final c = tester
                .widget<SessionHistoryPage>(find.byType(SessionHistoryPage))
                .controller;
            final refresh = c.refresh();
            final limitedSource = sources.last;
            limitedSource.respond([], next: 'page0');
            await refresh;
            for (var n = 1; n < 10; n++) {
              final page = c.loadMore();
              limitedSource.respond([], next: 'page$n');
              await page;
            }
            await tester.pumpAndSettle();
            final more = find.byKey(const ValueKey('history-more'));
            final footer = find
                .ancestor(of: more, matching: find.byType(Column))
                .first;
            expect(
              find.descendant(
                of: footer,
                matching: find.text(
                  dependencies.localizations.current.historyLimit,
                ),
              ),
              findsOneWidget,
            );
          }
          expect(find.textContaining('do-not-render'), findsNothing);
          expect(find.textContaining('do-not-execute'), findsNothing);
          expect(find.byType(TextField), findsNothing);
          expect(
            find.byKey(const ValueKey('history-composer')),
            findsOneWidget,
          );
          expect(
            identical(dependencies.navigation.pendingIntent, intent),
            isTrue,
          );
          final historyContext = tester.element(
            find.byType(SessionHistoryPage),
          );
          expect(
            Directionality.of(historyContext),
            {'ar', 'ur'}.contains(locale.languageCode)
                ? TextDirection.rtl
                : TextDirection.ltr,
          );
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.byType(SessionHistoryPage), findsNothing);
          expect(source.closes, 1);
          expect(
            dependencies.router.routeInformationProvider.value.uri.path,
            '/sessions',
          );
          expect(
            identical(dependencies.navigation.pendingIntent, intent),
            isTrue,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          rig.dispose();
        },
      );
    }
  }
}
