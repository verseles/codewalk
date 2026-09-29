import 'dart:async';
import 'dart:convert';

import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/release_history_service.dart';
import 'package:codewalk/presentation/services/sound_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../support/fakes.dart';
import '../../support/release_history_fakes.dart';

void _version(String value) => PackageInfo.setMockInitialValues(
  appName: 'CodeWalk',
  packageName: 'codewalk',
  version: value,
  buildNumber: '1',
  buildSignature: '',
);

InMemoryAppLocalDataSource _local({String? highest}) =>
    InMemoryAppLocalDataSource()
      ..experienceSettingsJson = jsonEncode({'checkUpdatesOnOpen': false})
      ..releaseHistoryState = highest == null
          ? null
          : jsonEncode({'schema': 1, 'highest': highest});

Future<SettingsProvider> _provider(
  InMemoryAppLocalDataSource local,
  FakeReleaseHistoryService service,
) async {
  final provider = SettingsProvider(
    localDataSource: local,
    dioClient: ReleaseHistoryNoopDioClient(),
    soundService: SoundService(),
    releaseHistoryService: service,
  );
  await provider.initialize();
  await provider.loadReleaseHistory();
  return provider;
}

class _FailingState extends InMemoryAppLocalDataSource {
  bool fail = false;
  @override
  Future<void> saveReleaseHistoryState(String state) async {
    if (fail) throw StateError('Unavailable storage');
    await super.saveReleaseHistoryState(state);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    _version('1.2.0');
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'legacy current-only migration ignores dismissed release versions',
    () async {
      final local = _local()
        ..dismissedNewsVersion = '1.0.0'
        ..dismissedUpdateVersion = '1.3.0';
      final provider = await _provider(local, FakeReleaseHistoryService());
      addTearDown(provider.dispose);
      expect(
        provider.pendingReleaseAnnouncements!.entries.map(
          (e) => e.version.toString(),
        ),
        ['1.2.0'],
      );
      final key = provider.pendingReleaseAnnouncements!.key;
      provider.markReleaseAnnouncementsPresented(key);
      expect(await provider.acknowledgeReleaseAnnouncements(key), isTrue);
      expect(jsonDecode(local.releaseHistoryState!)['to'], isNull);
      expect(local.dismissedNewsVersion, '1.0.0');
      expect(local.dismissedUpdateVersion, '1.3.0');
    },
  );

  test(
    'server profiles establish legacy even without saved experience settings',
    () async {
      final local = InMemoryAppLocalDataSource()
        ..serverProfilesJson = '[{"id":"existing"}]';
      final provider = await _provider(local, FakeReleaseHistoryService());
      addTearDown(provider.dispose);
      expect(
        provider.pendingReleaseAnnouncements!.entries.single.version.toString(),
        '1.2.0',
      );
    },
  );

  for (final legacyKey in ['host', 'port', 'enabled', 'username', 'password']) {
    test(
      'legacy $legacyKey establishes existing install before profile migration',
      () async {
        final local = InMemoryAppLocalDataSource();
        switch (legacyKey) {
          case 'host':
            await local.saveServerHost('localhost');
          case 'port':
            await local.saveServerPort(4096);
          case 'enabled':
            await local.saveBasicAuthEnabled(true);
          case 'username':
            await local.saveBasicAuthUsername('test-user');
          case 'password':
            await local.saveBasicAuthPassword('test-only');
        }
        final provider = await _provider(local, FakeReleaseHistoryService());
        addTearDown(provider.dispose);
        expect(
          provider.pendingReleaseAnnouncements!.entries.single.version
              .toString(),
          '1.2.0',
        );
      },
    );
  }

  test(
    'failed maintenance-only refresh preserves pending until successful retry',
    () async {
      _version('1.1.1');
      final local = _local(highest: '1.1.0');
      final service = FakeReleaseHistoryService(
        snapshot: ReleaseHistorySnapshot(
          entries: parseReleaseHistory(releaseHistoryFixture),
          failed: true,
        ),
      );
      final provider = await _provider(local, service);
      addTearDown(provider.dispose);
      expect(provider.pendingReleaseAnnouncements, isNull);
      expect(jsonDecode(local.releaseHistoryState!)['to'], '1.1.1');
      service.snapshot = ReleaseHistorySnapshot(
        entries: parseReleaseHistory(releaseHistoryFixture),
      );
      await provider.loadReleaseHistory(forceRefresh: true);
      expect(jsonDecode(local.releaseHistoryState!)['to'], isNull);
    },
  );

  test(
    'fresh install seeds silently without loading archive automatically',
    () async {
      final local = InMemoryAppLocalDataSource();
      final service = FakeReleaseHistoryService();
      final provider = SettingsProvider(
        localDataSource: local,
        dioClient: ReleaseHistoryNoopDioClient(),
        soundService: SoundService(),
        releaseHistoryService: service,
      );
      addTearDown(provider.dispose);
      await provider.initialize();
      expect(service.calls, 0);
      expect(provider.pendingReleaseAnnouncements, isNull);
      expect(jsonDecode(local.releaseHistoryState!)['highest'], '1.2.0');
    },
  );

  test(
    'jump filters full interval, excludes future/old and maintenance announcements',
    () async {
      final provider = await _provider(
        _local(highest: '1.0.0'),
        FakeReleaseHistoryService(),
      );
      addTearDown(provider.dispose);
      expect(
        provider.pendingReleaseAnnouncements!.entries.map(
          (e) => e.version.toString(),
        ),
        ['1.2.0', '1.1.0'],
      );
    },
  );

  test(
    'unchecked or resultless close retains interval through restarts and next update',
    () async {
      final local = _local(highest: '1.0.0');
      final first = await _provider(local, FakeReleaseHistoryService());
      final key = first.pendingReleaseAnnouncements!.key;
      first.markReleaseAnnouncementsPresented(key);
      await first.loadReleaseHistory();
      expect(first.pendingReleaseAnnouncements, isNull);
      expect(jsonDecode(local.releaseHistoryState!)['from'], '1.0.0');
      first.dispose();
      _version('1.3.0');
      final second = await _provider(local, FakeReleaseHistoryService());
      addTearDown(second.dispose);
      expect(
        second.pendingReleaseAnnouncements!.entries.map(
          (e) => e.version.toString(),
        ),
        ['1.3.0', '1.2.0', '1.1.0'],
      );
    },
  );

  test(
    'offline and missing target remain pending; valid cached interval is usable',
    () async {
      final local = _local(highest: '1.0.0');
      final service = FakeReleaseHistoryService(
        snapshot: const ReleaseHistorySnapshot(failed: true),
      );
      final provider = await _provider(local, service);
      addTearDown(provider.dispose);
      expect(provider.pendingReleaseAnnouncements, isNull);
      expect(provider.releaseHistoryCoverageMissing, isTrue);
      expect(jsonDecode(local.releaseHistoryState!)['from'], '1.0.0');
      service.snapshot = ReleaseHistorySnapshot(
        entries: parseReleaseHistory(releaseHistoryFixture).skip(2).toList(),
      );
      await provider.loadReleaseHistory(forceRefresh: true);
      expect(provider.pendingReleaseAnnouncements, isNull);
      service.snapshot = ReleaseHistorySnapshot(
        entries: parseReleaseHistory(releaseHistoryFixture),
        failed: true,
      );
      await provider.loadReleaseHistory(forceRefresh: true);
      expect(provider.pendingReleaseAnnouncements!.entries.length, 2);
    },
  );

  test('maintenance-only interval resolves without a dialog', () async {
    _version('1.1.1');
    final local = _local(highest: '1.1.0');
    final provider = await _provider(local, FakeReleaseHistoryService());
    addTearDown(provider.dispose);
    expect(provider.pendingReleaseAnnouncements, isNull);
    expect(jsonDecode(local.releaseHistoryState!)['to'], isNull);
  });

  test('downgrade does not erase highwater or pending history', () async {
    final local = _local(highest: '1.0.0');
    final first = await _provider(local, FakeReleaseHistoryService());
    first.dispose();
    final state = local.releaseHistoryState;
    _version('1.1.0');
    final second = await _provider(local, FakeReleaseHistoryService());
    addTearDown(second.dispose);
    expect(second.pendingReleaseAnnouncements, isNull);
    expect(local.releaseHistoryState, state);
  });

  test(
    'acknowledgement write failure retains durable pending interval',
    () async {
      final local = _FailingState()
        ..experienceSettingsJson = '{"checkUpdatesOnOpen":false}';
      final provider = await _provider(local, FakeReleaseHistoryService());
      addTearDown(provider.dispose);
      final key = provider.pendingReleaseAnnouncements!.key;
      final state = local.releaseHistoryState;
      local.fail = true;
      expect(await provider.acknowledgeReleaseAnnouncements(key), isFalse);
      expect(local.releaseHistoryState, state);
    },
  );

  test('reset invalidates late network completion', () async {
    final local = _local(highest: '1.0.0');
    final service = FakeReleaseHistoryService();
    final provider = await _provider(local, service);
    addTearDown(provider.dispose);
    final completer = Completer<ReleaseHistorySnapshot>();
    service.pending = completer.future;
    final load = provider.loadReleaseHistory(forceRefresh: true);
    await provider.resetReleaseHistory();
    await local.clearAll();
    completer.complete(
      ReleaseHistorySnapshot(
        entries: parseReleaseHistory(releaseHistoryFixture),
      ),
    );
    await load;
    expect(provider.releaseHistory.entries, isEmpty);
    expect(provider.pendingReleaseAnnouncements, isNull);
    expect(local.releaseHistoryState, isNull);
  });
}
