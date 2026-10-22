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
      'session.moved',
      'session.viewed',
      'session.execution.succeeded',
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
      OpenCodeCatalogChange.moved,
      OpenCodeCatalogChange.viewed,
      OpenCodeCatalogChange.idled,
    ]);
  });

  test('the activity of an unwatched session is reported by kind', () async {
    final harness = Harness('ses_a');
    final changes = <OpenCodeCatalogChange>[];
    harness.owner.catalogChanges.listen(changes.add);
    await harness.connect(1);
    for (final (type, data) in [
      ('session.execution.started', {'sessionID': 'ses_b'}),
      ('permission.asked', {'id': 'per_1', 'sessionID': 'ses_b'}),
      ('permission.replied', {'sessionID': 'ses_b', 'requestID': 'per_1'}),
      (
        'form.created',
        {
          'form': {'id': 'frm_1', 'sessionID': 'ses_b'},
        },
      ),
      ('form.replied', {'id': 'frm_1', 'sessionID': 'ses_b'}),
      // The endpoint's own form still changes what waits for the user.
      ('form.cancelled', {'id': 'frm_2', 'sessionID': 'global'}),
    ]) {
      await harness.send([
        {'id': 'evt_$type', 'created': 1, 'type': type, 'data': data},
      ]);
    }
    expect(changes, [
      OpenCodeCatalogChange.started,
      for (var i = 0; i < 5; i++) OpenCodeCatalogChange.waiting,
    ]);
  });

  test('a moved session reaches the catalog', () async {
    final harness = Harness('ses_a');
    final changes = <OpenCodeCatalogChange>[];
    harness.owner.catalogChanges.listen(changes.add);
    await harness.connect(1);
    await harness.send([
      {
        'id': 'evt_1',
        'created': 1,
        'type': 'session.moved',
        'data': {'sessionID': 'ses_a'},
      },
    ]);
    expect(changes, [OpenCodeCatalogChange.moved]);
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
        'type': 'session.compaction.started',
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
