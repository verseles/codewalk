import 'dart:async';

import 'package:codewalk/core/i18n/l10n_bridge.dart';
import 'package:codewalk/data/datasources/quota_remote_datasource.dart';
import 'package:codewalk/domain/entities/quota.dart';
import 'package:codewalk/presentation/providers/quota_provider.dart';
import 'package:codewalk/presentation/widgets/quota/quota_entry_row.dart';
import 'package:codewalk/presentation/widgets/quota/quota_popup_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/fakes.dart' as support;
import '../../support/pump_localized_app.dart';

class _FakeQuotaRemoteDataSource implements QuotaRemoteDataSource {
  _FakeQuotaRemoteDataSource(this.results);

  final List<QuotaProviderResult> results;

  @override
  Future<List<QuotaProviderResult>> fetchQuotaResults() async => results;
}

class _QueuedQuotaRemoteDataSource implements QuotaRemoteDataSource {
  _QueuedQuotaRemoteDataSource(this.responses);

  final List<Future<List<QuotaProviderResult>>> responses;
  int callCount = 0;

  @override
  Future<List<QuotaProviderResult>> fetchQuotaResults() {
    if (callCount >= responses.length) {
      return Future<List<QuotaProviderResult>>.value(
        const <QuotaProviderResult>[],
      );
    }
    return responses[callCount++];
  }
}

QuotaProviderResult _buildOpenRouterResult() {
  return const QuotaProviderResult(
    providerId: 'openrouter',
    providerName: 'OpenRouter',
    ok: true,
    configured: true,
    usage: QuotaProviderUsage(
      windows: {
        'credits': UsageWindow(
          usedPercent: null,
          remainingPercent: null,
          windowSeconds: null,
          resetAfterSeconds: null,
          resetAt: null,
          resetAtFormatted: null,
          resetAfterFormatted: null,
          valueLabel: r'$12.00 remaining',
        ),
      },
      models: {},
    ),
    error: null,
    fetchedAt: 1,
  );
}

void main() {
  test(
    'QuotaProvider clears obsolete OpenCode Go dashboard credentials',
    () async {
      final localDataSource = support.InMemoryAppLocalDataSource();
      localDataSource.scopedStrings['opencode_go_workspace_id::srv_test'] =
          'wrk_test';
      localDataSource.scopedStrings['opencode_go_auth_cookie::srv_test'] =
          'auth=secret';
      localDataSource.scopedStrings['opencode_go_workspace_id::srv_other'] =
          'wrk_other';
      localDataSource.scopedStrings['opencode_go_auth_cookie::srv_other'] =
          'auth=other';
      localDataSource.scopedStrings['opencode_go_auth_cookie'] =
          'auth=unscoped';
      localDataSource.scopedStrings['unrelated'] = 'preserved';
      final provider = QuotaProvider(
        remoteDataSource: _FakeQuotaRemoteDataSource(const []),
        localDataSource: localDataSource,
      );

      await provider.ensureLoaded(serverId: 'srv_test');

      expect(localDataSource.scopedStrings, <String, String>{
        'unrelated': 'preserved',
      });
    },
  );

  test('QuotaEntry treats zero remaining currency labels as exhausted', () {
    const entry = QuotaEntry(
      providerId: 'openrouter',
      providerName: 'OpenRouter',
      label: 'Credits',
      usedPercent: null,
      remainingPercent: null,
      windowSeconds: null,
      resetAfterSeconds: null,
      resetAt: null,
      valueLabel: r'$0.00 remaining',
      paceInfo: null,
    );

    expect(entry.hasZeroRemainingValueLabel, isTrue);
    expect(entry.effectiveUsedPercent, 100);
    expect(entry.severityScore, 100);
  });

  test(
    'QuotaProvider orders mixed windows by highest used percent first',
    () async {
      final provider = QuotaProvider(
        remoteDataSource: _FakeQuotaRemoteDataSource([
          const QuotaProviderResult(
            providerId: 'codex',
            providerName: 'Codex',
            ok: true,
            configured: true,
            usage: QuotaProviderUsage(
              windows: {
                'weekly': UsageWindow(
                  usedPercent: 35,
                  remainingPercent: 65,
                  windowSeconds: 7 * 86400,
                  resetAfterSeconds: 3600,
                  resetAt: 1,
                  resetAtFormatted: null,
                  resetAfterFormatted: null,
                  valueLabel: null,
                ),
                '5h': UsageWindow(
                  usedPercent: 80,
                  remainingPercent: 20,
                  windowSeconds: 5 * 3600,
                  resetAfterSeconds: 1800,
                  resetAt: 1,
                  resetAtFormatted: null,
                  resetAfterFormatted: null,
                  valueLabel: null,
                ),
              },
              models: {},
            ),
            error: null,
            fetchedAt: 1,
          ),
        ]),
      );

      await provider.ensureLoaded(serverId: 'srv_test');

      expect(provider.groups, hasLength(1));
      expect(provider.groups.first.entries, hasLength(2));
      expect(provider.groups.first.leadingEntry.label, '5-Hour');
      expect(provider.groups.first.entries.first.label, '5-Hour');
      expect(provider.groups.first.entries.last.label, 'Weekly Limit');
    },
  );

  testWidgets('QuotaPopupSection keeps Codex label with single 5-hour window', (
    tester,
  ) async {
    final provider = QuotaProvider(
      remoteDataSource: _FakeQuotaRemoteDataSource(const [
        QuotaProviderResult(
          providerId: 'codex',
          providerName: 'Codex',
          ok: true,
          configured: true,
          usage: QuotaProviderUsage(
            windows: {
              '5h': UsageWindow(
                usedPercent: 40,
                remainingPercent: 60,
                windowSeconds: 5 * 3600,
                resetAfterSeconds: 1800,
                resetAt: 1,
                resetAtFormatted: null,
                resetAfterFormatted: null,
                valueLabel: null,
              ),
            },
            models: {},
          ),
          error: null,
          fetchedAt: 1,
        ),
      ]),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<QuotaProvider>.value(
        value: provider,
        child: _buildApp(
          home: const Scaffold(body: QuotaPopupSection(serverId: 'srv_test')),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text(L10nBridge.current!.quotaRateLimits), findsOneWidget);
    expect(find.text('Codex'), findsOneWidget);
    expect(find.text('5-Hour'), findsOneWidget);
  });

  testWidgets(
    'QuotaPopupSection shows both 5-Hour and Weekly Limit for Codex without expand interaction',
    (tester) async {
      final provider = QuotaProvider(
        remoteDataSource: _FakeQuotaRemoteDataSource(const [
          QuotaProviderResult(
            providerId: 'codex',
            providerName: 'Codex',
            ok: true,
            configured: true,
            usage: QuotaProviderUsage(
              windows: {
                '5h': UsageWindow(
                  usedPercent: 80,
                  remainingPercent: 20,
                  windowSeconds: 5 * 3600,
                  resetAfterSeconds: 1800,
                  resetAt: 1,
                  resetAtFormatted: null,
                  resetAfterFormatted: null,
                  valueLabel: null,
                ),
                'weekly': UsageWindow(
                  usedPercent: 35,
                  remainingPercent: 65,
                  windowSeconds: 7 * 86400,
                  resetAfterSeconds: 3600,
                  resetAt: 1,
                  resetAtFormatted: null,
                  resetAfterFormatted: null,
                  valueLabel: null,
                ),
              },
              models: {},
            ),
            error: null,
            fetchedAt: 1,
          ),
        ]),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<QuotaProvider>.value(
          value: provider,
          child: _buildApp(
            home: const Scaffold(body: QuotaPopupSection(serverId: 'srv_test')),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text(L10nBridge.current!.quotaRateLimits), findsOneWidget);
      expect(find.text('Codex'), findsOneWidget);
      expect(find.text('5-Hour'), findsOneWidget);
      expect(find.text('Weekly Limit'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    },
  );

  test('QuotaProvider hides zero-credit only groups', () async {
    final provider = QuotaProvider(
      remoteDataSource: _FakeQuotaRemoteDataSource(const [
        QuotaProviderResult(
          providerId: 'openrouter',
          providerName: 'OpenRouter',
          ok: true,
          configured: true,
          usage: QuotaProviderUsage(
            windows: {
              'credits': UsageWindow(
                usedPercent: null,
                remainingPercent: null,
                windowSeconds: null,
                resetAfterSeconds: null,
                resetAt: null,
                resetAtFormatted: null,
                resetAfterFormatted: null,
                valueLabel: r'$0.00 remaining',
              ),
            },
            models: {},
          ),
          error: null,
          fetchedAt: 1,
        ),
      ]),
    );

    await provider.ensureLoaded(serverId: 'srv_test');

    expect(provider.groups, isEmpty);
  });

  test(
    'QuotaProvider keeps mixed groups and drops zero-credit entries',
    () async {
      final provider = QuotaProvider(
        remoteDataSource: _FakeQuotaRemoteDataSource([
          const QuotaProviderResult(
            providerId: 'codex',
            providerName: 'Codex',
            ok: true,
            configured: true,
            usage: QuotaProviderUsage(
              windows: {
                'weekly': UsageWindow(
                  usedPercent: 35,
                  remainingPercent: 65,
                  windowSeconds: 7 * 86400,
                  resetAfterSeconds: 3600,
                  resetAt: 1,
                  resetAtFormatted: null,
                  resetAfterFormatted: null,
                  valueLabel: null,
                ),
                '5h': UsageWindow(
                  usedPercent: 80,
                  remainingPercent: 20,
                  windowSeconds: 5 * 3600,
                  resetAfterSeconds: 1800,
                  resetAt: 1,
                  resetAtFormatted: null,
                  resetAfterFormatted: null,
                  valueLabel: null,
                ),
                'credits': UsageWindow(
                  usedPercent: null,
                  remainingPercent: null,
                  windowSeconds: null,
                  resetAfterSeconds: null,
                  resetAt: null,
                  resetAtFormatted: null,
                  resetAfterFormatted: null,
                  valueLabel: r'$0.00 remaining',
                ),
              },
              models: {},
            ),
            error: null,
            fetchedAt: 1,
          ),
        ]),
      );

      await provider.ensureLoaded(serverId: 'srv_test');

      expect(provider.groups, hasLength(1));
      expect(provider.groups.first.providerId, 'codex');
      expect(provider.groups.first.entries, hasLength(2));
      expect(
        provider.groups.first.entries.any(
          (entry) => entry.hasZeroRemainingValueLabel,
        ),
        isFalse,
      );
      expect(
        provider.groups.first.entries.map((entry) => entry.label).toList(),
        <String>['5-Hour', 'Weekly Limit'],
      );
    },
  );

  testWidgets('QuotaEntryRow shows determinate full bar for zero remaining', (
    tester,
  ) async {
    const entry = QuotaEntry(
      providerId: 'openrouter',
      providerName: 'OpenRouter',
      label: 'Credits',
      usedPercent: null,
      remainingPercent: null,
      windowSeconds: null,
      resetAfterSeconds: null,
      resetAt: null,
      valueLabel: r'$0.00 remaining',
      paceInfo: null,
    );

    await tester.pumpWidget(
      _buildApp(
        home: const Scaffold(body: QuotaEntryRow(entry: entry)),
      ),
    );

    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, 1.0);
  });

  testWidgets(
    'QuotaPopupSection shows subtle first-load state and then hides when empty',
    (tester) async {
      final firstLoad = Completer<List<QuotaProviderResult>>();
      final provider = QuotaProvider(
        remoteDataSource: _QueuedQuotaRemoteDataSource([firstLoad.future]),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<QuotaProvider>.value(
          value: provider,
          child: _buildApp(
            home: const Scaffold(body: QuotaPopupSection(serverId: 'srv_test')),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(L10nBridge.current!.quotaRateLimits), findsOneWidget);
      expect(find.text(L10nBridge.current!.quotaRefreshing), findsOneWidget);
      expect(
        find.byKey(const ValueKey('quota-initial-loading-state')),
        findsOneWidget,
      );

      firstLoad.complete(const <QuotaProviderResult>[]);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text(L10nBridge.current!.quotaRateLimits), findsNothing);
      expect(
        find.byKey(const ValueKey('quota-initial-loading-state')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'QuotaPopupSection distinguishes OpenCode Go authentication failures',
    (tester) async {
      final provider = QuotaProvider(
        remoteDataSource: _FakeQuotaRemoteDataSource(const [
          QuotaProviderResult(
            providerId: 'opencode-go',
            providerName: 'OpenCode Go',
            ok: false,
            configured: true,
            usage: null,
            error: 'OpenCode Go authentication failed',
            fetchedAt: 1,
            errorCode: 'authentication',
          ),
        ]),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<QuotaProvider>.value(
          value: provider,
          child: _buildApp(
            home: const Scaffold(body: QuotaPopupSection(serverId: 'srv_test')),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text(L10nBridge.current!.quotaRateLimits), findsOneWidget);
      expect(find.text(L10nBridge.current!.errorAuthRequired), findsOneWidget);
      expect(
        find.byKey(const ValueKey('opencode-go-quota-failure-card')),
        findsOneWidget,
      );
      expect(find.text('OpenCode Go authentication failed'), findsOneWidget);
    },
  );

  testWidgets(
    'QuotaPopupSection does not call a parsing failure stale credentials',
    (tester) async {
      final provider = QuotaProvider(
        remoteDataSource: _FakeQuotaRemoteDataSource(const [
          QuotaProviderResult(
            providerId: 'opencode-go',
            providerName: 'OpenCode Go',
            ok: false,
            configured: true,
            usage: null,
            error: 'OpenCode Go usage data could not be parsed',
            fetchedAt: 1,
            errorCode: 'invalid_response',
          ),
        ]),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<QuotaProvider>.value(
          value: provider,
          child: _buildApp(
            home: const Scaffold(body: QuotaPopupSection(serverId: 'srv_test')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(L10nBridge.current!.errorAnErrorOccurred),
        findsOneWidget,
      );
      expect(
        find.text(L10nBridge.current!.quotaOpenCodeGoNeedsReconnect),
        findsNothing,
      );
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets(
    'QuotaPopupSection swaps refresh button for refreshing label during reload',
    (tester) async {
      final refreshLoad = Completer<List<QuotaProviderResult>>();
      final provider = QuotaProvider(
        remoteDataSource: _QueuedQuotaRemoteDataSource([
          Future<List<QuotaProviderResult>>.value([_buildOpenRouterResult()]),
          refreshLoad.future,
        ]),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<QuotaProvider>.value(
          value: provider,
          child: _buildApp(
            home: const Scaffold(body: QuotaPopupSection(serverId: 'srv_test')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text(L10nBridge.current!.quotaRateLimits), findsOneWidget);
      expect(
        find.byKey(const ValueKey('quota-refresh-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('quota-refreshing-label')),
        findsNothing,
      );

      await tester.tap(find.text(L10nBridge.current!.chatRefresh));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byKey(const ValueKey('quota-refresh-button')), findsNothing);
      expect(
        find.byKey(const ValueKey('quota-refreshing-label')),
        findsOneWidget,
      );

      refreshLoad.complete([_buildOpenRouterResult()]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byKey(const ValueKey('quota-refresh-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('quota-refreshing-label')),
        findsNothing,
      );
    },
  );
}

Widget _buildApp({required Widget home}) {
  return localizedMaterialApp(home: home);
}
