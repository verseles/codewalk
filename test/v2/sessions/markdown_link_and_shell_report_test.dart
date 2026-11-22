import 'dart:async';
import 'dart:convert';

import 'package:codewalk/features/sessions/session_history_controller.dart';
import 'package:codewalk/features/sessions/session_history_page.dart';
import 'package:codewalk/features/sessions/session_live_scroll.dart';
import 'package:codewalk/features/sessions/session_live_timeline.dart';
import 'package:codewalk/features/sessions/session_subagent_capsule.dart';
import 'package:codewalk/features/sessions/session_timeline_projection.dart';
import 'package:codewalk/features/sessions/session_timeline_tile.dart';
import 'package:codewalk/features/sessions/session_tool_result.dart';
import 'package:codewalk/features/sessions/session_work_group.dart';
import 'package:codewalk/platform/sessions/opencode_selection_lane.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/rendering/canonical_message_body.dart';
import 'package:codewalk/shared/rendering/markdown_link_opener.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'fakes.dart';
import 'history_fakes.dart';
import 'live_fakes.dart';

const _host = HostId('h');
const _harnessId = HarnessInstanceId('i');
const _harness = HarnessRef(_host, _harnessId);
const _session = SessionRef(_host, _harnessId, 'ses_1');

ItemMeta _meta(String id, {ItemStatus status = ItemStatus.completed}) => ItemMeta(
  id: ItemId('test/$id'),
  generation: 'g1',
  status: OpenValue.known(status),
  source: SourceProvenance(
    harness: _harness,
    version: '2.3.0',
    nativeType: 'test',
  ),
);

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: V2Localizations.localizationsDelegates,
  supportedLocales: V2Localizations.supportedLocales,
  home: Scaffold(body: child),
);

/// Invokes the [TapGestureRecognizer] attached to the first inline span whose
/// text contains [substring].
void _tapLinkSpan(WidgetTester tester, String substring) {
  final found = <TapGestureRecognizer>[];
  for (final widget in tester.widgetList<RichText>(find.byType(RichText))) {
    widget.text.visitChildren((span) {
      if (span is TextSpan &&
          (span.text?.contains(substring) ?? false) &&
          span.recognizer is TapGestureRecognizer) {
        found.add(span.recognizer! as TapGestureRecognizer);
      }
      return true;
    });
  }
  expect(found, isNotEmpty, reason: 'No clickable span containing "$substring"');
  found.first.onTap!();
}

void main() {
  group('parseExternalMarkdownLink', () {
    test('accepts http, https, scheme-relative, bare www, and mailto', () {
      expect(
        parseExternalMarkdownLink('http://100.114.6.48:6080/vnc.html'),
        Uri.parse('http://100.114.6.48:6080/vnc.html'),
      );
      expect(
        parseExternalMarkdownLink('  https://example.com/docs?q=1#top  '),
        Uri.parse('https://example.com/docs?q=1#top'),
      );
      expect(
        parseExternalMarkdownLink('//example.com/path'),
        Uri.parse('https://example.com/path'),
      );
      expect(
        parseExternalMarkdownLink('www.example.com/help'),
        Uri.parse('https://www.example.com/help'),
      );
      expect(
        parseExternalMarkdownLink('mailto:dev@example.com'),
        Uri.parse('mailto:dev@example.com'),
      );
    });

    test('rejects relative paths, fragments, and unsafe schemes', () {
      for (final bad in [
        '',
        '   ',
        '#heading',
        '/relative/path',
        'README.md',
        'javascript:alert(1)',
        'file:///etc/passwd',
        'data:text/html,<script>alert(1)</script>',
        'intent://scan/#Intent;end',
        'http://',
        'https://',
        'mailto:',
      ]) {
        expect(parseExternalMarkdownLink(bad), isNull, reason: bad);
      }
    });
  });

  group('openExternalMarkdownLink', () {
    testWidgets('launches valid URI and reports errors with localized snackbar', (
      tester,
    ) async {
      final launched = <Uri>[];
      var result = true;
      var shouldThrow = false;
      late BuildContext captured;

      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final l10n = V2Localizations.of(captured);

      // Clean launch -> no snackbar.
      await openExternalMarkdownLink(
        captured,
        'http://100.114.6.48:6080/vnc.html',
        launcher: (uri) async {
          launched.add(uri);
          if (shouldThrow) throw StateError('boom');
          return result;
        },
      );
      await tester.pump();
      expect(launched, [Uri.parse('http://100.114.6.48:6080/vnc.html')]);
      expect(find.text(l10n.chatMessageUnableToOpenLink), findsNothing);

      // Unsafe scheme -> never launched, shows snackbar.
      await openExternalMarkdownLink(
        captured,
        'javascript:alert(1)',
        launcher: (uri) async {
          launched.add(uri);
          return true;
        },
      );
      await tester.pump();
      expect(launched, hasLength(1));
      expect(find.text(l10n.chatMessageUnableToOpenLink), findsOneWidget);
      ScaffoldMessenger.of(captured).clearSnackBars();
      await tester.pump();

      // Platform returns false -> shows snackbar.
      result = false;
      await openExternalMarkdownLink(
        captured,
        'https://example.com',
        launcher: (uri) async {
          launched.add(uri);
          return result;
        },
      );
      await tester.pump();
      expect(find.text(l10n.chatMessageUnableToOpenLink), findsOneWidget);
      ScaffoldMessenger.of(captured).clearSnackBars();
      await tester.pump();

      // Launcher throws -> shows snackbar.
      shouldThrow = true;
      await openExternalMarkdownLink(
        captured,
        'https://example.com',
        launcher: (uri) async {
          if (shouldThrow) throw StateError('boom');
          return true;
        },
      );
      await tester.pump();
      expect(find.text(l10n.chatMessageUnableToOpenLink), findsOneWidget);
    });
  });

  group('Markdown links across timeline surfaces', () {
    testWidgets(
      'SessionLiveTimeline invokes onTapLink across assistant, user, light note, and report group',
      (tester) async {
        final scroll = SessionLiveScroll();
        addTearDown(scroll.dispose);
        final tapped = <(String, String)>[];

        final items = <TimelineItem>[
          UserInput(
            meta: _meta('u1'),
            text: 'Check [user link](https://user.example.com)',
            delivery: const OpenValue.known(DeliveryState.delivered),
          ),
          AssistantText(
            meta: _meta('a1'),
            text:
                'Open http://100.114.6.48:6080/vnc.html or [docs](https://docs.example.com).',
            complete: true,
          ),
          Notice(
            meta: _meta('n1'),
            kind: const OpenValue.known(NoticeKind.system),
            text: 'See [note guide](https://note.example.com)',
          ),
          Notice(
            meta: _meta('r1'),
            kind: const OpenValue.known(NoticeKind.continuation),
            text: 'Report [details](https://report.example.com)',
            report: const SubagentReport(
              agent: 'Explorer',
              outcome: OutcomeKind.succeeded,
            ),
          ),
        ];

        await tester.pumpWidget(
          _app(
            SessionLiveTimeline(
              items: items,
              headerBuilder: (_) => const SizedBox.shrink(),
              scroll: scroll,
              settled: true,
              onTapLink: (text, href, _) => tapped.add((text, href)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap autolink & markdown link in assistant text and user bubble.
        _tapLinkSpan(tester, 'http://100.114.6.48:6080/vnc.html');
        _tapLinkSpan(tester, 'docs');
        _tapLinkSpan(tester, 'user link');
        expect(tapped, [
          (
            'http://100.114.6.48:6080/vnc.html',
            'http://100.114.6.48:6080/vnc.html',
          ),
          ('docs', 'https://docs.example.com'),
          ('user link', 'https://user.example.com'),
        ]);

        // Open light note, tap its link (note must stay open!), then collapse via icon.
        final note = find.byKey(const ValueKey('timeline-note-test/n1'));
        await tester.tap(note);
        await tester.pumpAndSettle();
        _tapLinkSpan(tester, 'note guide');
        await tester.pumpAndSettle();
        expect(tapped.last, ('note guide', 'https://note.example.com'));
        // Still expanded after tapping the link.
        expect(
          find.descendant(of: note, matching: find.byType(CanonicalMessageBody)),
          findsOneWidget,
        );
        await tester.tap(
          find.descendant(of: note, matching: find.byIcon(Symbols.info)),
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: note, matching: find.byType(CanonicalMessageBody)),
          findsNothing,
        );

        // Open subagent report and tap link inside it.
        await tester.tap(find.text('Explorer replied'));
        await tester.pumpAndSettle();
        _tapLinkSpan(tester, 'details');
        expect(tapped.last, ('details', 'https://report.example.com'));
      },
    );

    testWidgets(
      'SessionLiveTimeline default onTapLink handles unsafe links with snackbar',
      (tester) async {
        final scroll = SessionLiveScroll();
        addTearDown(scroll.dispose);
        await tester.pumpWidget(
          _app(
            SessionLiveTimeline(
              items: [
                AssistantText(
                  meta: _meta('a1'),
                  text: 'Click [bad](javascript:alert(1))',
                  complete: true,
                ),
              ],
              headerBuilder: (_) => const SizedBox.shrink(),
              scroll: scroll,
              settled: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = V2Localizations.of(
          tester.element(find.byType(SessionLiveTimeline)),
        );
        _tapLinkSpan(tester, 'bad');
        await tester.pump();
        expect(find.text(l10n.chatMessageUnableToOpenLink), findsOneWidget);
      },
    );

    testWidgets('SessionHistoryPage wires onTapLink for Markdown messages', (
      tester,
    ) async {
      final rig = CatalogRig();
      await rig.save('a');
      await rig.sessions.initialize();
      addTearDown(rig.dispose);
      final p = profile('a');
      final summary = CatalogSource(p).row('one');
      late HistorySource source;
      final controller = SessionHistoryController(
        hosts: rig.hosts,
        profile: p,
        summary: summary,
        sourceFactory: (_, _, ref) => source = HistorySource(ref),
      );
      final tapped = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: V2Localizations.localizationsDelegates,
          supportedLocales: V2Localizations.supportedLocales,
          home: SessionHistoryPage(
            controller: controller,
            onTapLink: (_, href, _) => tapped.add(href),
          ),
        ),
      );
      await tester.pump();
      source.respond([
        AssistantText(
          meta: source.meta(1, version: '2.3.0'),
          text: 'Visit [history](https://history.example.com)',
          complete: true,
        ),
      ], version: '2.3.0');
      await tester.pumpAndSettle();
      _tapLinkSpan(tester, 'history');
      expect(tapped, ['https://history.example.com']);
    });
  });

  group('Background shell report notices and skill activation notes', () {
    testWidgets(
      'Notice with ShellReport renders as compact SessionToolResult and opens details dialog',
      (tester) async {
        final okReport = Notice(
          meta: _meta('sh_ok'),
          kind: const OpenValue.known(NoticeKind.continuation),
          text: '',
          shellReport: ShellReport(
            command: 'nohup websockify 6080 localhost:5900',
            outcome: OutcomeKind.succeeded,
            shellId: 'sh_1',
          ),
        );
        final failedReport = Notice(
          meta: _meta('sh_fail'),
          kind: const OpenValue.known(NoticeKind.continuation),
          text: 'error output line',
          shellReport: ShellReport(
            command: 'npm test',
            outcome: OutcomeKind.failed,
            exitCode: 2,
            truncated: true,
            shellId: 'sh_2',
          ),
        );
        final timedOutReport = Notice(
          meta: _meta('sh_to'),
          kind: const OpenValue.known(NoticeKind.continuation),
          text: 'partial',
          shellReport: ShellReport(
            command: 'sleep 999',
            outcome: OutcomeKind.failed,
            timedOut: true,
          ),
        );
        final killedReport = Notice(
          meta: _meta('sh_kill'),
          kind: const OpenValue.known(NoticeKind.continuation),
          text: '',
          shellReport: ShellReport(
            command: 'tail -f log',
            outcome: OutcomeKind.interrupted,
            killed: true,
          ),
        );

        await tester.pumpWidget(
          _app(
            ListView(
              children: [
                SessionTimelineTile(item: okReport),
                SessionTimelineTile(item: failedReport),
                SessionTimelineTile(item: timedOutReport),
                SessionTimelineTile(item: killedReport),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = V2Localizations.of(
          tester.element(find.byType(ListView)),
        );

        // All four render as compact SessionToolResult rows, never as Cards or LightNotes.
        expect(find.byType(SessionToolResult), findsNWidgets(4));
        expect(find.byType(SessionLightNote), findsNothing);
        expect(find.byType(Card), findsNothing);
        // Clean success omits status badge; failed/timeout/killed show badges.
        expect(find.byKey(const ValueKey('tool-status-test/sh_ok')), findsNothing);
        expect(
          find.byKey(const ValueKey('tool-status-test/sh_fail')),
          findsOneWidget,
        );
        expect(
          find.text('${l10n.statusFailed} · ${l10n.liveShellExitCode} 2'),
          findsOneWidget,
        );
        expect(find.text(l10n.liveShellTimedOut), findsOneWidget);
        expect(find.text(l10n.liveShellKilled), findsOneWidget);

        // Tap clean report -> details dialog shows Done, Command, and localized empty output.
        await tester.tap(find.byKey(const ValueKey('tool-toggle-test/sh_ok')));
        await tester.pumpAndSettle();
        expect(find.text(l10n.liveToolDone), findsOneWidget);
        expect(
          find.text('nohup websockify 6080 localhost:5900'),
          findsOneWidget,
        );
        expect(find.text(l10n.liveShellOutputEmpty), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('tool-details-close')));
        await tester.pumpAndSettle();

        // Tap failed truncated report -> details dialog shows output & partial notice.
        await tester.tap(find.byKey(const ValueKey('tool-toggle-test/sh_fail')));
        await tester.pumpAndSettle();
        expect(find.text('error output line'), findsOneWidget);
        expect(find.text(l10n.liveShellOutputPartial), findsOneWidget);
      },
    );

    test(
      'projection compacts shell reports as commands, suppresses user-shell echoes, and capsule overlays background reports',
      () {
        final userShell = ShellRun(
          meta: _meta('sr_1'),
          command: 'ls',
          shellId: 'sh_user',
          shellStatus: const OpenValue.known(ShellStatus.exited),
          exitCode: 0,
        );
        final userEcho = Notice(
          meta: _meta('echo_1'),
          kind: const OpenValue.known(NoticeKind.continuation),
          text: 'file.txt',
          shellReport: ShellReport(
            command: 'ls',
            outcome: OutcomeKind.succeeded,
            shellId: 'sh_user',
          ),
        );
        final bgTool = ToolCall(
          meta: _meta('tool_bg'),
          kind: const OpenValue.known(ToolKind.shell),
          rawName: 'shell',
          input: CanonicalValue(const {'command': 'websockify 6080'}),
          runFacts: ToolRunFacts(
            background: true,
            shellId: 'sh_bg',
            shellStatus: const OpenValue.known(ShellStatus.running),
          ),
        );
        final bgReport = Notice(
          meta: _meta('rep_bg'),
          kind: const OpenValue.known(NoticeKind.continuation),
          text: 'listening',
          shellReport: ShellReport(
            command: 'websockify 6080',
            outcome: OutcomeKind.succeeded,
            shellId: 'sh_bg',
          ),
        );
        final detachedReport = Notice(
          meta: _meta('rep_det'),
          kind: const OpenValue.known(NoticeKind.continuation),
          text: 'failed',
          shellReport: ShellReport(
            command: 'old-job',
            outcome: OutcomeKind.failed,
            exitCode: 1,
            shellId: 'sh_old',
          ),
        );
        final answer = AssistantText(
          meta: _meta('ans_1'),
          text: 'All set.',
          complete: true,
        );

        // User-shell echo is omitted, while background-tool shell report is kept.
        final filtered = sessionTimelineItems([
          userShell,
          userEcho,
          bgTool,
          bgReport,
          detachedReport,
          answer,
        ]);
        expect(filtered, isNot(contains(userEcho)));
        expect(filtered, contains(bgReport));
        expect(filtered, contains(detachedReport));

        // Shell reports participate in activity stretch compaction & hide with showToolCalls=false.
        final presentation = SessionTimelinePresentation();
        final rows = presentation.project([bgReport, detachedReport, answer], settled: true);
        expect(rows.first, isA<SessionActivityStretchRow>());
        final stretch = rows.first as SessionActivityStretchRow;
        expect(stretch.work, [bgReport, detachedReport]);
        expect(stretch.failedCount, 1);
        final hidden = presentation.project(
          [bgReport, answer],
          settled: true,
          showToolCalls: false,
        );
        expect(hidden, hasLength(1));
        expect((hidden.single as SessionItemRow).item, answer);

        // Capsule overlays bgReport onto bgTool (by sh_bg), preserves userShell, and adds detachedReport.
        final state = liveState(
          _session,
          items: [userShell, userEcho, bgTool, bgReport, detachedReport],
        );
        final entries = sessionShellEntries(state, canObserveShells: true);
        expect(entries.map((e) => e.key), ['sh_user', 'sh_bg', 'sh_old']);
        final bgEntry = entries.firstWhere((e) => e.key == 'sh_bg');
        expect(bgEntry.isRunning, isFalse);
        expect(bgEntry.isUnconfirmed, isFalse);
        expect(bgEntry.status, ShellStatus.exited);
        expect(bgEntry.timelineItem, bgReport);
        final userEntry = entries.firstWhere((e) => e.key == 'sh_user');
        expect(userEntry.timelineItem, userShell);
        final oldEntry = entries.firstWhere((e) => e.key == 'sh_old');
        expect(oldEntry.isFailed, isTrue);
        expect(oldEntry.exitCode, 1);
      },
    );

    testWidgets(
      'NoticeKind.skillActivated renders a quiet skill note and activitySummaryParts counts shell reports as commands',
      (tester) async {
        final skill = Notice(
          meta: _meta('sk1'),
          kind: const OpenValue.known(NoticeKind.skillActivated),
          text: 'flutter-review',
        );
        final emptySkill = Notice(
          meta: _meta('sk2'),
          kind: const OpenValue.known(NoticeKind.skillActivated),
          text: '   ',
        );
        final report = Notice(
          meta: _meta('sh_cnt'),
          kind: const OpenValue.known(NoticeKind.continuation),
          text: 'ok',
          shellReport: ShellReport(
            command: 'echo hi',
            outcome: OutcomeKind.succeeded,
          ),
        );
        await tester.pumpWidget(
          _app(
            Column(
              children: [
                SessionTimelineTile(item: skill),
                SessionTimelineTile(item: emptySkill),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = V2Localizations.of(tester.element(find.byType(Column)));
        expect(find.byKey(const ValueKey('timeline-note-test/sk1')), findsOneWidget);
        expect(find.byKey(const ValueKey('timeline-note-test/sk2')), findsNothing);
        expect(find.text('${l10n.toolKindSkill} · flutter-review'), findsOneWidget);
        expect(find.byIcon(Symbols.auto_stories), findsOneWidget);
        expect(activitySummaryParts([report], l10n), [l10n.activityCommands(1)]);
      },
    );
  });

  group('OpenCodeSelectionLane directory move reload', () {
    test(
      're-reads location catalog when session.moved changes canonicalDirectory',
      () async {
        final queriedDirs = <String>[];
        final transport = _FakeSelectionTransport((req) {
          final uri = Uri.parse(req.path);
          final dir = uri.queryParameters['location[directory]'] ?? '';
          if (uri.path == 'api/model') {
            queriedDirs.add(dir);
            return _jsonResp({
              'location': {'directory': dir},
              'data': [
                {
                  'id': dir == '/dir/b' ? 'model-b' : 'model-a',
                  'providerID': 'prov',
                  'name': dir == '/dir/b' ? 'Model B' : 'Model A',
                  'enabled': true,
                  'limit': {'context': 128000, 'output': 4096},
                  'variants': <Object?>[],
                },
              ],
            });
          }
          if (uri.path == 'api/agent') {
            return _jsonResp({
              'location': {'directory': dir},
              'data': [
                {'name': 'build', 'mode': 'primary'},
              ],
            });
          }
          if (uri.path == 'api/config') {
            return _jsonResp({'data': <String, Object?>{}});
          }
          if (uri.path == 'api/model/default') {
            return _jsonResp({'data': null});
          }
          if (uri.path == 'api/provider') {
            return _jsonResp({'data': <Object?>[]});
          }
          return _jsonResp({'data': null}, status: 404);
        });

        SessionLiveView viewFor(String dir) {
          final boundary = SnapshotBoundary(
            owner: const SessionOwner(_session),
            hydrationGeneration: 'g1',
            readStart: StreamPosition(id: 's', epoch: 'e', seq: BigInt.one),
            readStartedAt: DateTime.utc(2026, 11, 22),
            authority: const OpenValue.known(SnapshotAuthority.authoritative),
          );
          final state = hydrate(
            beginHydration(
              SessionState(
                _session,
                streamPosition: StreamPosition(
                  id: 's',
                  epoch: 'e',
                  seq: BigInt.zero,
                ),
              ),
              generation: 'g1',
              readStart: StreamPosition(id: 's', epoch: 'e', seq: BigInt.one),
            ),
            SessionSnapshot(
              ref: _session,
              hydrationGeneration: 'g1',
              info: SnapshotValue(
                value: SessionInfo(
                  ref: _session,
                  title: 'Demo',
                  ownership: const OwnershipInfo.unknown(reason: 'test'),
                  project: ProjectRef(_host, dir),
                ),
                boundary: boundary,
              ),
            ),
          ).state;
          return SessionLiveView(
            session: _session,
            phase: SessionLivePhase.live,
            state: state,
          );
        }

        var currentView = viewFor('/dir/a');
        final lane = OpenCodeSelectionLane(
          reader: OpenCodeSessionReader(transport, harness: _harness),
          locations: OpenCodeLocationReader(transport, harness: _harness),
          client: OpenCodeSessionLifecycleClient(
            transport,
            harness: _harness,
            connectedVersion: '2.3.0',
          ),
          view: (_) => currentView,
          publish: (_) {},
        );
        addTearDown(lane.close);

        lane.open(_session);
        lane.consider(_session, currentView);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(queriedDirs, ['/dir/a']);
        expect(lane.state(_session).models.single.id, 'model-a');

        // Moving to the same directory does not re-read.
        lane.consider(_session, viewFor('/dir/a'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(queriedDirs, ['/dir/a']);

        // Moving to /dir/b triggers an automatic re-read for /dir/b.
        currentView = viewFor('/dir/b');
        lane.consider(_session, currentView);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(queriedDirs, ['/dir/a', '/dir/b']);
        expect(lane.state(_session).models.single.id, 'model-b');
      },
    );
  });
}

final class _FakeSelectionTransport implements EndpointHttpTransport {
  _FakeSelectionTransport(this._handler);
  final TransportResponse Function(TransportRequest) _handler;

  @override
  Uri endpoint = Uri.parse('http://127.0.0.1:4096/');

  @override
  bool isClosed = false;

  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    RequestCancellation? cancellation,
  }) async => _handler(request);

  @override
  void close() => isClosed = true;
}

TransportResponse _jsonResp(Object? body, {int status = 200}) => TransportResponse(
  statusCode: status,
  headers: const {
    'content-type': ['application/json'],
  },
  body: Stream.value(utf8.encode(jsonEncode(body))),
  cancel: () {},
);
