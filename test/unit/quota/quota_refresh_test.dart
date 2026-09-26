import 'dart:async';

import 'package:codewalk/data/datasources/quota_remote_datasource.dart';
import 'package:codewalk/domain/entities/quota.dart';
import 'package:codewalk/presentation/providers/quota_provider.dart';
import 'package:codewalk/presentation/widgets/quota/quota_popup_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/pump_localized_app.dart';

class _Remote implements QuotaRemoteDataSource {
  int calls = 0;
  Future<List<QuotaProviderResult>>? next;
  List<QuotaProviderResult> results = [
    _result('xai', {
      'billing_cycle': {'usedPercent': 25},
    }),
  ];

  @override
  Future<List<QuotaProviderResult>> fetchQuotaResults() {
    calls++;
    final pending = next;
    next = null;
    return pending ?? Future.value(results);
  }
}

QuotaProviderResult _result(String provider, Map<String, Object?> windows) =>
    QuotaProviderResult.fromJson({
      'providerId': provider,
      'providerName': provider,
      'ok': true,
      'configured': true,
      'usage': {'windows': windows},
      'fetchedAt': 1,
    });

Future<void> _mount(
  WidgetTester tester,
  QuotaProvider provider,
  Widget child, {
  GlobalKey<NavigatorState>? navigator,
}) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: localizedMaterialApp(
        home: navigator == null
            ? Scaffold(body: child)
            : Navigator(
                key: navigator,
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => Scaffold(body: child),
                ),
              ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  for (final (seconds, label) in <(int?, String)>[
    (604800, 'Weekly Limit'),
    (18000, '5-Hour'),
    (7200, '2-Hour'),
    (14 * 86400, '14-Day Limit'),
    (90, '90-Second Limit'),
    (null, 'Usage Limit'),
    (0, 'Usage Limit'),
    (-1, 'Usage Limit'),
  ]) {
    test(
      'G1 Codex REST label follows $seconds seconds instead of slot',
      () async {
        final remote = _Remote()
          ..results = [
            _result('codex', {
              '5h': {
                'usedPercent': 25,
                'windowSeconds': seconds,
                'resetAt': DateTime.utc(2026, 9, 27).millisecondsSinceEpoch,
              },
              'credits': {'valueLabel': r'$10.00 remaining'},
            }),
          ];
        final provider = QuotaProvider(
          remoteDataSource: remote,
          now: () => DateTime.utc(2026, 9, 26),
        );
        addTearDown(provider.dispose);
        await provider.ensureLoaded(serverId: 'a');
        final entry = provider.groups.single.entries.firstWhere(
          (entry) => entry.usedPercent != null,
        );
        expect(entry.label, label);
        if (seconds == null || seconds <= 0) expect(entry.paceInfo, isNull);
        expect(
          provider.groups.single.entries.any(
            (entry) => entry.label == 'Credits',
          ),
          isTrue,
        );
      },
    );
  }

  test('G1 xAI Pace requires actual period duration', () async {
    final now = DateTime.utc(2026, 9, 26);
    final remote = _Remote();
    final provider = QuotaProvider(remoteDataSource: remote, now: () => now);
    addTearDown(provider.dispose);
    for (final seconds in [null, 7 * 86400, 28 * 86400]) {
      remote.results = [
        _result('xai', {
          'billing_cycle': {
            'usedPercent': 25,
            'windowSeconds': seconds,
            'resetAt': now
                .add(Duration(seconds: (seconds ?? 604800) ~/ 2))
                .millisecondsSinceEpoch,
          },
        }),
      ];
      await provider.ensureLoaded(serverId: 'a', force: true);
      final pace = provider.groups.single.entries.single.paceInfo;
      if (seconds == null) {
        expect(pace, isNull);
      } else {
        expect(pace!.totalSeconds, seconds);
        expect(pace.predictedFinalPercent, 50);
      }
    }
  });

  testWidgets('G1 sidebar refreshes at 20 minutes; popup alone does not poll', (
    tester,
  ) async {
    final remote = _Remote();
    final provider = QuotaProvider(
      remoteDataSource: remote,
      now: tester.binding.clock.now,
    );
    final sidebar = ValueNotifier(true);
    await _mount(
      tester,
      provider,
      ValueListenableBuilder(
        valueListenable: sidebar,
        builder: (_, show, _) => Column(
          children: [
            if (show)
              const QuotaPopupSection(
                key: ValueKey('sidebar'),
                serverId: 'a',
                autoRefresh: true,
              ),
            const QuotaPopupSection(key: ValueKey('popup'), serverId: 'a'),
          ],
        ),
      ),
    );
    expect(remote.calls, 1);
    await tester.pump(const Duration(minutes: 19));
    expect(remote.calls, 1);
    await tester.pump(const Duration(minutes: 1));
    await tester.pump();
    expect(remote.calls, 2);
    sidebar.value = false;
    await tester.pump();
    await tester.pump(const Duration(minutes: 40));
    expect(remote.calls, 2);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
    sidebar.dispose();
  });

  testWidgets('G1 refresh pauses for route, owner overlay and hidden app', (
    tester,
  ) async {
    final remote = _Remote();
    final provider = QuotaProvider(
      remoteDataSource: remote,
      now: tester.binding.clock.now,
    );
    final visible = ValueNotifier(true);
    final navigator = GlobalKey<NavigatorState>();
    await _mount(
      tester,
      provider,
      ValueListenableBuilder(
        valueListenable: visible,
        builder: (_, show, _) => QuotaPopupSection(
          serverId: 'a',
          autoRefresh: true,
          isVisible: show,
        ),
      ),
      navigator: navigator,
    );
    expect(remote.calls, 1);
    visible.value = false;
    await tester.pump();
    await tester.pump(const Duration(minutes: 40));
    expect(remote.calls, 1);
    visible.value = true;
    await tester.pump();
    await tester.pump();
    expect(remote.calls, 2);

    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Settings')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 40));
    expect(remote.calls, 2);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(remote.calls, 3);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump(const Duration(minutes: 40));
    expect(remote.calls, 3);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await tester.pump();
    expect(remote.calls, 4);
    await tester.pump(const Duration(minutes: 20));
    await tester.pump();
    expect(remote.calls, 5);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
    visible.dispose();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets(
    'G1 manual refresh and in-flight fetch preserve TTL and no overlap',
    (tester) async {
      final remote = _Remote();
      final provider = QuotaProvider(
        remoteDataSource: remote,
        now: tester.binding.clock.now,
      );
      await _mount(
        tester,
        provider,
        const QuotaPopupSection(serverId: 'a', autoRefresh: true),
      );
      await tester.pump(const Duration(minutes: 19));
      final pending = Completer<List<QuotaProviderResult>>();
      remote.next = pending.future;
      await tester.tap(find.byKey(const ValueKey('quota-refresh-button')));
      await tester.pump();
      expect(remote.calls, 2);
      await tester.pump(const Duration(minutes: 40));
      expect(remote.calls, 2);
      pending.complete(remote.results);
      await tester.pump();
      await tester.pump(const Duration(minutes: 19));
      expect(remote.calls, 2);
      await tester.pump(const Duration(minutes: 1));
      await tester.pump();
      expect(remote.calls, 3);
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    },
  );

  testWidgets('G1 refresh recovers from failures and stops after dispose', (
    tester,
  ) async {
    final remote = _Remote();
    final provider = QuotaProvider(
      remoteDataSource: remote,
      now: tester.binding.clock.now,
    );
    await _mount(
      tester,
      provider,
      const QuotaPopupSection(serverId: 'a', autoRefresh: true),
    );
    final pending = Completer<List<QuotaProviderResult>>();
    remote.next = pending.future;
    await tester.pump(const Duration(minutes: 20));
    pending.completeError(StateError('test failure'));
    await tester.pump();
    expect(remote.calls, 2);
    await tester.pump(const Duration(minutes: 20));
    await tester.pump();
    expect(remote.calls, 3);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
    await tester.pump(const Duration(minutes: 40));
    expect(remote.calls, 3);
    expect(tester.takeException(), isNull);
  });

  test(
    'G1 server A-null-A does not overlap or accept the old payload',
    () async {
      final remote = _Remote();
      final pending = Completer<List<QuotaProviderResult>>();
      remote.next = pending.future;
      final provider = QuotaProvider(remoteDataSource: remote);
      final first = provider.ensureLoaded(serverId: 'a');
      await Future<void>.delayed(Duration.zero);
      await provider.ensureLoaded(serverId: null);
      await provider.ensureLoaded(serverId: 'a');
      expect(remote.calls, 1);
      pending.complete([
        _result('old', {
          '5h': {'usedPercent': 99},
        }),
      ]);
      await first;
      await Future<void>.delayed(Duration.zero);
      expect(remote.calls, 2);
      expect(provider.groups.single.providerId, 'xai');
      provider.dispose();
    },
  );

  test('G1 provider disposal ignores an in-flight result', () async {
    final remote = _Remote();
    final pending = Completer<List<QuotaProviderResult>>();
    remote.next = pending.future;
    final provider = QuotaProvider(remoteDataSource: remote);
    final first = provider.ensureLoaded(serverId: 'a');
    await Future<void>.delayed(Duration.zero);
    provider.dispose();
    pending.complete(remote.results);
    await first;
    expect(remote.calls, 1);
  });

  test(
    'G1 superseded server is skipped before the remote fetch begins',
    () async {
      final remote = _Remote();
      final provider = QuotaProvider(remoteDataSource: remote);
      addTearDown(provider.dispose);
      final first = provider.ensureLoaded(serverId: 'a');
      await provider.ensureLoaded(serverId: 'b');
      await first;
      await Future<void>.delayed(Duration.zero);
      expect(remote.calls, 1);
      expect(provider.groups.single.providerId, 'xai');
    },
  );
}
