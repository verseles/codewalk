import 'dart:async';

import 'package:codewalk/domain/entities/session_tab_icon_overrides.dart';
import 'package:codewalk/presentation/services/session_tab_icon_override_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  test(
    'mutation after a failed load preserves existing disk entries',
    () async {
      final dataSource = _FailFirstIconReadLocalDataSource();
      await dataSource.saveSessionTabIconOverridesJson(
        SessionTabIconOverridesState(
          entries: <SessionTabIconOverride>[
            SessionTabIconOverride(
              serverId: 'server-a',
              directory: '/work/a',
              sessionId: 'session-a',
              presetId: 'code',
              updatedAtMs: 1,
            ),
          ],
        ).encode(),
        serverId: 'server-a',
      );
      final store = SessionTabIconOverrideStore(localDataSource: dataSource);

      await expectLater(store.load('server-a'), throwsStateError);
      final state = await store.setPreset(
        serverId: 'server-a',
        directory: '/work/b',
        sessionId: 'session-b',
        presetId: 'bug',
        updatedAtMs: 2,
      );

      expect(state.entries, hasLength(2));
      expect(
        state.entries.map((entry) => entry.sessionId),
        containsAll(<String>['session-a', 'session-b']),
      );
    },
  );

  test('identity removal reads disk before the server was hydrated', () async {
    final dataSource = InMemoryAppLocalDataSource();
    await dataSource.saveSessionTabIconOverridesJson(
      SessionTabIconOverridesState(
        entries: <SessionTabIconOverride>[
          SessionTabIconOverride(
            serverId: 'server-a',
            directory: '/work/a',
            sessionId: 'session-a',
            presetId: 'code',
            updatedAtMs: 1,
          ),
        ],
      ).encode(),
      serverId: 'server-a',
    );
    final store = SessionTabIconOverrideStore(localDataSource: dataSource);

    final state = await store.removeIdentity(
      serverId: 'server-a',
      directory: r'\work\a\',
      sessionId: ' session-a ',
    );

    expect(state.entries, isEmpty);
    expect(
      SessionTabIconOverridesState.decode(
        await dataSource.getSessionTabIconOverridesJson(serverId: 'server-a'),
      ).entries,
      isEmpty,
    );
  });

  test('server removal waits for writes and blocks resurrection', () async {
    final dataSource = _DelayedIconSaveLocalDataSource();
    final store = SessionTabIconOverrideStore(localDataSource: dataSource);

    final write = store.setPreset(
      serverId: 'server-a',
      directory: '/work/a',
      sessionId: 'session-a',
      presetId: 'code',
      updatedAtMs: 1,
    );
    await dataSource.saveStarted.future;
    final removal = store.removeServer('server-a');
    dataSource.releaseSave.complete();

    await write;
    await removal;
    expect(
      await dataSource.getSessionTabIconOverridesJson(serverId: 'server-a'),
      isNull,
    );
    await expectLater(
      store.setPreset(
        serverId: 'server-a',
        directory: '/work/a',
        sessionId: 'session-a',
        presetId: 'bug',
        updatedAtMs: 2,
      ),
      throwsStateError,
    );
  });
}

class _FailFirstIconReadLocalDataSource extends InMemoryAppLocalDataSource {
  var _failed = false;

  @override
  Future<String?> getSessionTabIconOverridesJson({required String serverId}) {
    if (!_failed) {
      _failed = true;
      throw StateError('icon read failed');
    }
    return super.getSessionTabIconOverridesJson(serverId: serverId);
  }
}

class _DelayedIconSaveLocalDataSource extends InMemoryAppLocalDataSource {
  final Completer<void> saveStarted = Completer<void>();
  final Completer<void> releaseSave = Completer<void>();

  @override
  Future<void> saveSessionTabIconOverridesJson(
    String stateJson, {
    required String serverId,
  }) async {
    if (!saveStarted.isCompleted) saveStarted.complete();
    await releaseSave.future;
    await super.saveSessionTabIconOverridesJson(stateJson, serverId: serverId);
  }
}
