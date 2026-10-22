import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codewalk/platform/sessions/session_draft_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/platform/storage/payload_io.dart';
import 'package:codewalk/platform/storage/payload_store.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';

SessionRef _ref(String id, {String host = 'a'}) =>
    SessionRef(HostId(host), HarnessInstanceId(host), id);

/// A device: the same backend read by every store built on it, as a relaunch
/// reads what the killed process wrote.
final class _Device {
  final backend = FakeMetadataBackend();
  late final metadata = V2MetadataStore(backend: backend);

  SessionDraftStore store() => SessionDraftStore(
    payloads: PreferencesPayloadStore(metadata),
    index: metadata,
    delay: const Duration(milliseconds: 10),
  );

  Object? raw(SessionRef ref) => backend.values[SessionDraftStore.keyFor(ref)];

  List<String> index() =>
      SessionDraftStore.decodeIndex(
        backend.values[SessionDraftStore.indexKey],
      ) ??
      const [];

  int writesOf(SessionRef ref) => backend.writes
      .where((key) => key == SessionDraftStore.keyFor(ref))
      .length;
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 40));

void main() {
  test('a draft survives a new store on the same device', () async {
    final device = _Device();
    final ref = _ref('s1');
    final first = device.store();
    expect(await first.read(ref), isNull);
    first.save(ref, 'half a prompt');
    await _settle();

    // The process is gone: a new store reads what was written.
    expect(await device.store().read(ref), 'half a prompt');
    expect(device.index(), [ref.storageKey]);
  });

  test('a draft survives a relaunch on the native file store', () async {
    final directory = await Directory.systemTemp.createTemp('cw2_drafts_');
    addTearDown(() => directory.delete(recursive: true));
    final device = _Device();
    SessionDraftStore store() => SessionDraftStore(
      payloads: FilePayloadStore(
        beforeMutation: () async {},
        backend: NativePayloadFileBackend(directory: () async => directory),
      ),
      index: device.metadata,
      delay: const Duration(milliseconds: 10),
    );
    final ref = _ref('s1');
    final first = store();
    expect(await first.read(ref), isNull);
    // Real file I/O has no bounded duration, so the test waits for the write
    // itself rather than a fixed delay (which could see the temporary file).
    first.save(ref, '旧🙂 half a prompt');
    await first.flush();
    expect(await directory.list().length, 1);

    expect(await store().read(ref), '旧🙂 half a prompt');
    first.save(ref, '');
    for (var i = 0; i < 500 && !await directory.list().isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(await directory.list().length, 0);
    expect(await store().read(ref), isNull);

    // A file the payload store discards as corrupt is gone: nothing is left
    // to keep, so the session's drafts are saved again.
    final file = File(
      '${directory.path}/'
      '${sha256.convert(utf8.encode(SessionDraftStore.keyFor(ref)))}.json',
    );
    await file.writeAsBytes([0xff, 0xfe, 0xfd]);
    final next = store();
    expect(await next.read(ref), isNull);
    next.save(ref, 'after the corrupt one');
    await next.flush();
    expect(await store().read(ref), 'after the corrupt one');
  });

  test('drafts of two servers with the same session id stay apart', () async {
    final device = _Device();
    final a = _ref('s1');
    final b = _ref('s1', host: 'b');
    final store = device.store();
    await store.read(a);
    await store.read(b);
    store.save(a, 'for a');
    store.save(b, 'for b');
    await _settle();

    final relaunched = device.store();
    expect(await relaunched.read(a), 'for a');
    expect(await relaunched.read(b), 'for b');
  });

  test('typing is written once per delay, not per key', () async {
    final device = _Device();
    final ref = _ref('s1');
    final store = device.store();
    await store.read(ref);
    for (final text in ['h', 'he', 'hel', 'hell', 'hello']) {
      store.save(ref, text);
    }
    await _settle();
    expect(device.writesOf(ref), 1);
    expect(await device.store().read(ref), 'hello');
  });

  test('flush writes what is pending at once', () async {
    final device = _Device();
    final ref = _ref('s1');
    final store = SessionDraftStore(
      payloads: PreferencesPayloadStore(device.metadata),
      index: device.metadata,
      delay: const Duration(hours: 1),
    );
    await store.read(ref);
    store.save(ref, 'before the app leaves');
    await store.flush();
    expect(await device.store().read(ref), 'before the app leaves');
  });

  test('an empty text removes the draft without waiting', () async {
    final device = _Device();
    final ref = _ref('s1');
    final store = device.store();
    await store.read(ref);
    store.save(ref, 'sent soon');
    await _settle();
    store.save(ref, '');
    await store.flush();
    await Future<void>.delayed(Duration.zero);
    expect(device.raw(ref), isNull);
    expect(device.index(), isEmpty);
    expect(await device.store().read(ref), isNull);
  });

  test('forget removes a draft only while it holds the sent text', () async {
    final device = _Device();
    final ref = _ref('s1');
    final store = device.store();
    await store.read(ref);
    store.save(ref, 'sent');
    await _settle();
    store.forget(ref, 'something else');
    await _settle();
    expect(await device.store().read(ref), 'sent');

    store.forget(ref, 'sent');
    await _settle();
    expect(await device.store().read(ref), isNull);
  });

  test('a draft that could not be read is never written over', () async {
    final device = _Device();
    final ref = _ref('s1');
    final key = SessionDraftStore.keyFor(ref);
    device.backend.values[key] = '{not json';
    final store = device.store();
    expect(await store.read(ref), isNull);
    store.save(ref, 'new text');
    store.save(ref, '');
    await _settle();
    expect(device.backend.values[key], '{not json');
  });

  test(
    'a read that failed once does not stop saving after one succeeds',
    () async {
      final device = _Device();
      final ref = _ref('s1');
      final store = device.store();
      device.backend.failRead = true;
      expect(await store.read(ref), isNull);
      store.save(ref, 'not yet');
      await _settle();
      expect(device.raw(ref), isNull);

      device.backend.failRead = false;
      expect(await store.read(ref), isNull);
      store.save(ref, 'saved now');
      await _settle();
      expect(await device.store().read(ref), 'saved now');
    },
  );

  test(
    'text typed after a failed read is saved once the read passes',
    () async {
      final device = _Device();
      final ref = _ref('s1');
      final store = SessionDraftStore(
        payloads: PreferencesPayloadStore(device.metadata),
        index: device.metadata,
        delay: const Duration(hours: 1),
      );
      device.backend.failRead = true;
      expect(await store.read(ref), isNull);
      store.save(ref, 'typed meanwhile');
      await store.flush();
      expect(device.raw(ref), isNull);

      // Nothing reads the session again and nothing more is typed: the next
      // flush, as when the app leaves the foreground, reads it and writes.
      device.backend.failRead = false;
      await store.flush();
      await _settle();
      expect(await device.store().read(ref), 'typed meanwhile');
    },
  );

  test('a draft of another session under the key is not shown', () async {
    final device = _Device();
    final ref = _ref('s1');
    device.backend.values[SessionDraftStore.keyFor(ref)] =
        SessionDraftStore.encode(_ref('s2'), 'not yours');
    expect(await device.store().read(ref), isNull);
  });

  test('an oversized draft is not written and the last one stays', () async {
    final device = _Device();
    final ref = _ref('s1');
    final store = device.store();
    await store.read(ref);
    store.save(ref, 'short');
    await _settle();
    store.save(ref, 'x' * (SessionDraftStore.maxDraftBytes + 1));
    await _settle();
    expect(await device.store().read(ref), 'short');
  });

  test('the draft written longest ago is evicted past the bound', () async {
    final device = _Device();
    final store = device.store();
    final refs = [
      for (var i = 0; i <= SessionDraftStore.maxDrafts; i++) _ref('s$i'),
    ];
    for (final ref in refs) {
      await store.read(ref);
      store.save(ref, 'draft ${ref.nativeId}');
      await _settle();
    }
    expect(device.index(), [for (final ref in refs.skip(1)) ref.storageKey]);
    expect(device.raw(refs.first), isNull);
    expect(await device.store().read(refs.last), 'draft s32');
  });

  test('a draft written while it is evicted keeps its text', () async {
    final device = _Device();
    final store = device.store();
    final refs = [
      for (var i = 0; i < SessionDraftStore.maxDrafts; i++) _ref('s$i'),
    ];
    for (final ref in refs) {
      await store.read(ref);
      store.save(ref, 'draft ${ref.nativeId}');
      await _settle();
    }
    // The oldest draft is being written when a new session's draft evicts
    // it from the index.
    final oldest = refs.first;
    final newest = _ref('new');
    await store.read(newest);
    device.backend
      ..blockedKey = SessionDraftStore.keyFor(oldest)
      ..entered = Completer<void>()
      ..release = Completer<void>();
    store
      ..save(oldest, 'edited')
      ..save(newest, 'new draft');
    await device.backend.entered!.future;
    await _settle();
    device.backend.release!.complete();
    await _settle();

    final relaunched = device.store();
    expect(await relaunched.read(oldest), 'edited');
    expect(await relaunched.read(newest), 'new draft');
    expect(device.index(), contains(oldest.storageKey));
    expect(device.index(), hasLength(SessionDraftStore.maxDrafts));
    // The next oldest made room instead.
    expect(device.raw(refs[1]), isNull);
  });

  test(
    'forget tells the session\'s owner only when it removed the text',
    () async {
      final device = _Device();
      final ref = _ref('s1');
      final store = device.store();
      final told = <String>[];
      void owner(String text) => told.add(text);
      store.attach(ref, owner);
      await store.read(ref);
      store.save(ref, 'sent');
      await _settle();
      store.forget(ref, 'other');
      await _settle();
      expect(told, isEmpty);
      store.forget(ref, 'sent');
      await _settle();
      expect(told, ['sent']);

      store
        ..detach(ref, owner)
        ..save(ref, 'again');
      await _settle();
      store.forget(ref, 'again');
      await _settle();
      expect(told, ['sent']);
    },
  );

  test('an unreadable index is neither pruned nor rewritten', () async {
    final device = _Device();
    device.backend.values[SessionDraftStore.indexKey] = 'garbage';
    final ref = _ref('s1');
    final store = device.store();
    await store.read(ref);
    store.save(ref, 'still saved');
    await _settle();
    expect(device.backend.values[SessionDraftStore.indexKey], 'garbage');
    expect(await device.store().read(ref), 'still saved');
  });

  test('recovered drafts of the importer are left untouched', () async {
    final device = _Device();
    const recovered = 'cw2.recoveredDrafts.drafts-1';
    final value = jsonEncode({'text': 'imported'});
    device.backend.values[recovered] = value;
    final store = device.store();
    for (var i = 0; i <= SessionDraftStore.maxDrafts; i++) {
      final ref = _ref('s$i');
      await store.read(ref);
      store.save(ref, 'draft $i');
      await _settle();
      store.save(ref, '');
    }
    await _settle();
    expect(device.backend.values[recovered], value);
    expect(device.backend.writes, isNot(contains(recovered)));
    expect(device.backend.removals, isNot(contains(recovered)));
  });
}
