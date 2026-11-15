import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/features/sessions/session_live_page.dart';
import 'package:codewalk/features/sessions/session_subagent_capsule.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'live_fakes.dart';

class SubagentCapsuleRig {
  SubagentCapsuleRig(this.catalog, this.live, this.parent);

  final CatalogRig catalog;
  final SessionLiveController live;
  final SessionRef parent;
  final opened = <SessionRef>[];
  late LiveHandle handle;

  static Future<SubagentCapsuleRig> mount(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    double scale = 1,
    bool fullPage = false,
    ThemeMode themeMode = ThemeMode.light,
    ThemeData? localTheme,
  }) async {
    final catalog = CatalogRig();
    await catalog.save('a');
    await catalog.sessions.initialize();
    final directory = LiveDirectory();
    final summary = CatalogSource(profile('a')).row('one');
    final live = SessionLiveController(
      hosts: catalog.hosts,
      profile: profile('a'),
      summary: summary,
      directory: directory,
    );
    final rig = SubagentCapsuleRig(catalog, live, summary.info.ref);
    addTearDown(catalog.dispose);
    addTearDown(live.dispose);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    final opening = fullPage ? null : live.start();
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        themeMode: themeMode,
        localizationsDelegates: V2Localizations.localizationsDelegates,
        supportedLocales: V2Localizations.supportedLocales,
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: scale,
          maxScaleFactor: scale,
          child: child!,
        ),
        home: Builder(
          builder: (context) {
            final page = fullPage
                ? SessionLivePage(controller: live, ownsController: false)
                : Scaffold(
                    body: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Expanded(child: SizedBox()),
                          SessionSubagentCapsule(
                            live: live,
                            onOpen: rig.opened.add,
                          ),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  );
            return localTheme == null
                ? page
                : Theme(data: localTheme, child: page);
          },
        ),
      ),
    );
    await tester.pump();
    rig.handle = directory.grant(rig.parent);
    await opening;
    await tester.pump();
    return rig;
  }

  WorkItem work(String id, WorkStatus status) {
    final child = SessionRef(parent.host, parent.harness, 'ses_$id');
    return WorkItem(
      id: WorkId(id),
      owner: SessionOwner(child, origin: parent),
      child: child,
      parent: parent,
      status: OpenValue.known(status),
      completionScope: const OpenValue.known(CompletionScope.child),
      title: id,
    );
  }

  void emit(
    List<WorkItem> work, {
    List<InteractionRequest> interactions = const [],
    SessionLivePhase phase = SessionLivePhase.live,
    bool stale = false,
    List<TimelineItem> items = const [],
  }) => handle.emit(
    SessionLiveView(
      session: parent,
      phase: phase,
      stale: stale,
      state: liveState(
        parent,
        work: work,
        interactions: interactions,
        items: items,
      ),
    ),
  );
}
