import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

import 'stream_owner_test.dart' show Harness;

/// The catalog observes the session lifecycle of every session of the
/// endpoint, watched or not, and the signal carries only the kind.
void main() {
  test('a lifecycle frame of an unwatched session reaches the catalog', () async {
    final harness = Harness('ses_a');
    final changes = <OpenCodeCatalogChange>[];
    harness.owner.catalogChanges.listen(changes.add);
    await harness.connect(1);
    await harness.send([
      {
        'id': 'evt_1',
        'created': 1,
        'type': 'session.created',
        'data': {'sessionID': 'ses_b', 'projectID': 'global'},
        'durable': {'aggregateID': 'ses_b', 'seq': 1, 'version': 1},
      },
    ]);
    expect(changes, [OpenCodeCatalogChange.created]);
  });

  test('every lifecycle kind is reported once', () async {
    final harness = Harness('ses_a');
    final changes = <OpenCodeCatalogChange>[];
    harness.owner.catalogChanges.listen(changes.add);
    await harness.connect(1);
    for (final type in [
      'session.created',
      'session.forked',
      'session.renamed',
      'session.deleted',
    ]) {
      await harness.send([
        {
          'id': 'evt_$type',
          'created': 1,
          'type': type,
          'data': {'sessionID': 'ses_b'},
        },
      ]);
    }
    expect(changes, [
      OpenCodeCatalogChange.created,
      OpenCodeCatalogChange.forked,
      OpenCodeCatalogChange.renamed,
      OpenCodeCatalogChange.deleted,
    ]);
  });

  test('a frame that is not a lifecycle change is not reported', () async {
    final harness = Harness('ses_a');
    final changes = <OpenCodeCatalogChange>[];
    harness.owner.catalogChanges.listen(changes.add);
    await harness.connect(1);
    await harness.send([
      {
        'id': 'evt_1',
        'created': 1,
        'type': 'session.text.delta',
        'data': {'sessionID': 'ses_a'},
      },
      {
        'id': 'evt_2',
        'created': 1,
        'type': 'permission.asked',
        'data': {'sessionID': 'ses_a'},
      },
      {
        'id': 'evt_3',
        'created': 1,
        'type': 'session.usage.updated',
        'data': {'sessionID': 'ses_a'},
      },
    ]);
    expect(changes, isEmpty);
  });

  test('a malformed frame is neither reported nor fatal', () async {
    final harness = Harness('ses_a');
    final changes = <OpenCodeCatalogChange>[];
    harness.owner.catalogChanges.listen(changes.add);
    await harness.connect(1);
    await harness.send([
      'not json at all',
      ['a list'],
      {'type': 42, 'data': <String, Object?>{}},
    ]);
    expect(changes, isEmpty);
  });
}
