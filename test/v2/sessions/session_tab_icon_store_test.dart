import 'dart:convert';

import 'package:codewalk/features/sessions/session_tab_icons.dart';
import 'package:codewalk/platform/sessions/session_tab_icon_store.dart';
import 'package:codewalk/platform/sessions/session_tabs_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';

SessionTab _tab(
  String id, {
  String host = 'a',
  String harness = 'a',
  String project = '/p',
}) => SessionTab(
  ref: SessionRef(HostId(host), HarnessInstanceId(harness), id),
  project: ProjectRef(HostId(host), project),
  title: id,
  lastOpenedAtMs: 0,
);

final class _LostAck implements MetadataBackend {
  final backend = FakeMetadataBackend();
  bool loseNext = false;
  @override
  Future<Object?> read(String key) => backend.read(key);
  @override
  Future<void> remove(String key) => backend.remove(key);
  @override
  Future<void> write(String key, Object value) async {
    await backend.write(key, value);
    if (key == SessionTabIconStore.key && loseNext) {
      loseNext = false;
      throw StateError('acknowledgement lost after commit');
    }
  }
}

void main() {
  SessionTabIconStore store(MetadataBackend backend) =>
      SessionTabIconStore(store: V2MetadataStore(backend: backend));

  test('choices survive restart and use complete session identity', () async {
    final backend = FakeMetadataBackend();
    final first = store(backend);
    final a = _tab('same');
    final b = _tab('same', host: 'b');
    final c = _tab('same', harness: 'other');
    expect(await first.set(a, 'code'), isTrue);
    expect(await first.set(b, 'bug'), isTrue);
    expect(await first.set(c, 'tools'), isTrue);
    first.dispose();
    final restored = store(backend);
    await restored.initialize();
    expect(restored.presetFor(a.ref), 'code');
    expect(restored.presetFor(b.ref), 'bug');
    expect(restored.presetFor(c.ref), 'tools');
    expect(await restored.set(a, null), isTrue);
    expect(restored.presetFor(a.ref), isNull);
    expect(restored.presetFor(b.ref), 'bug');
    restored.dispose();
  });

  test(
    'a later write preserves a choice committed before a lost ack',
    () async {
      final backend = _LostAck();
      final icons = store(backend);
      backend.loseNext = true;
      expect(await icons.set(_tab('a'), 'code'), isFalse);
      expect(await icons.set(_tab('b'), 'bug'), isTrue);
      final restored = store(backend);
      await restored.initialize();
      expect(restored.presetFor(_tab('a').ref), 'code');
      expect(restored.presetFor(_tab('b').ref), 'bug');
      restored.dispose();
      icons.dispose();
    },
  );

  test('capacity refuses a new choice and never evicts another', () async {
    final backend = FakeMetadataBackend();
    backend.values[SessionTabIconStore.key] = jsonEncode({
      'version': 1,
      'icons': {
        for (var i = 0; i < SessionTabIconStore.maxIcons; i++)
          _tab('$i').ref.storageKey: {'preset': 'code'},
      },
    });
    final icons = store(backend);
    expect(await icons.set(_tab('new'), 'bug'), isFalse);
    expect(icons.presetFor(_tab('0').ref), 'code');
    expect(await icons.set(_tab('0'), 'bug'), isTrue);
    expect(await icons.set(_tab('0'), null), isTrue);
    expect(await icons.set(_tab('new'), 'tools'), isTrue);
    icons.dispose();
  });

  test('bad envelopes are preserved and bad glyphs safely fall back', () async {
    final backend = FakeMetadataBackend();
    const malformed = '{"version":2,"icons":{}}';
    backend.values[SessionTabIconStore.key] = malformed;
    final blocked = store(backend);
    expect(await blocked.set(_tab('a'), 'bug'), isFalse);
    expect(blocked.unreadable, isTrue);
    expect(backend.values[SessionTabIconStore.key], malformed);
    blocked.dispose();
    backend.values[SessionTabIconStore.key] = jsonEncode({
      'version': 1,
      'icons': {
        'bad key': {'preset': 'code'},
        _tab('a').ref.storageKey: {'preset': 'unknown future glyph'},
        _tab('b').ref.storageKey: {'preset': 42},
      },
    });
    final icons = store(backend);
    await icons.initialize();
    expect(icons.unreadable, isFalse);
    expect(SessionTabIconPreset.fromId(icons.presetFor(_tab('a').ref)), isNull);
    expect(icons.presetFor(_tab('b').ref), isNull);
    icons.dispose();
  });

  test('project cleanup is scoped and includes non-open tab choices', () async {
    final icons = store(FakeMetadataBackend());
    final a = _tab('a');
    final otherProject = _tab('b', project: '/q');
    final otherHost = _tab('c', host: 'b');
    for (final tab in [a, otherProject, otherHost]) {
      await icons.set(tab, 'code');
    }
    expect(
      await icons.removeWhere(
        (ref, project) => ref.host == a.ref.host && project == a.project,
      ),
      isTrue,
    );
    expect(icons.presetFor(a.ref), isNull);
    expect(icons.presetFor(otherProject.ref), 'code');
    expect(icons.presetFor(otherHost.ref), 'code');
    icons.dispose();
  });
}
