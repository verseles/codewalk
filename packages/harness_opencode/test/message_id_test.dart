import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

import 'support/fixture_replay.dart';

final _shape = RegExp(r'^msg_[0-9a-f]{12}[0-9A-Za-z]{14}$');

List<Map<String, Object?>> _events() {
  final file = File(
    '${OpenCodeFixtures().root.path}/b/matrix-events.json',
  ).readAsStringSync();
  return ((jsonDecode(file) as Map)['events'] as List)
      .cast<Map<String, Object?>>();
}

void main() {
  test('a captured server event id carries its creation time', () {
    final timed = _events().where((e) => e['created'] != null).toList();
    expect(timed, isNotEmpty);
    for (final event in timed) {
      final ordinal = openCodeIdOrdinal(event['id']! as String)!;
      expect(ordinal ~/ 0x1000, (event['created']! as int) % 0x1000000000);
      expect(ordinal % 0x1000, greaterThan(0));
    }
    // Captured client ids are longer than the official shape: opaque data.
    expect(openCodeIdOrdinal('msg_1a1053e7ad3000a8b22017a68214'), isNull);
  });

  test('mints the official shape, strictly ascending in one millisecond', () {
    final now = DateTime.utc(2026, 10, 15);
    final ids = OpenCodeMessageIds(now: () => now, random: Random(1));
    final minted = [for (var i = 0; i < 5000; i++) ids.mint()];
    for (final id in minted) {
      expect(id, matches(_shape));
    }
    for (var i = 1; i < minted.length; i++) {
      expect(
        openCodeIdOrdinal(minted[i])! > openCodeIdOrdinal(minted[i - 1])!,
        isTrue,
      );
      expect(minted[i].compareTo(minted[i - 1]), greaterThan(0));
    }
    final first = openCodeIdOrdinal(minted.first)!;
    expect(first ~/ 0x1000, now.millisecondsSinceEpoch % 0x1000000000);
    expect(first % 0x1000, 1);
  });

  test('a slow local clock still mints after every observed server id', () {
    final events = _events().where((e) => e['created'] != null).toList();
    final last = events.last;
    final created = last['created']! as int;
    // Local clock an hour behind the server.
    final local = DateTime.fromMillisecondsSinceEpoch(created - 3600000);
    final ids = OpenCodeMessageIds(now: () => local, random: Random(2));
    for (final event in events) {
      ids.observe(
        event['id']! as String,
        created: event['created']! as int,
        receivedAt: local,
      );
    }
    expect(ids.offsetMs, 3600000);
    final id = ids.mint();
    expect(id.substring(4).compareTo((last['id']! as String).substring(4)), 1);
  });

  test('a backward or mismatched sample never lowers offset or order', () {
    final base = DateTime.utc(2026, 10, 15);
    final ids = OpenCodeMessageIds(now: () => base, random: Random(3));
    String event(int created, {int counter = 1}) =>
        'evt_${((created % 0x1000000000) * 0x1000 + counter).toRadixString(16).padLeft(12, '0')}'
        'AAAAAAAAAAAAAA';
    final ahead = base.millisecondsSinceEpoch + 5000;
    ids.observe(event(ahead), created: ahead, receivedAt: base);
    expect(ids.offsetMs, 5000);
    final behind = base.millisecondsSinceEpoch - 5000;
    ids.observe(event(behind), created: behind, receivedAt: base);
    expect(ids.offsetMs, 5000);
    // An id that does not carry its created time is not a clock sample.
    ids.observe(
      event(ahead + 99999),
      created: ahead + 999999,
      receivedAt: base,
    );
    expect(ids.offsetMs, 5000);
    // But its ordinal still raises the floor.
    final minted = ids.mint();
    expect(
      openCodeIdOrdinal(minted)! > openCodeIdOrdinal(event(ahead + 99999))!,
      isTrue,
    );
  });
}
