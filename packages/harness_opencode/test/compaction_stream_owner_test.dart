import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

import 'compaction_projection_test.dart' show frame;
import 'history_test_data.dart';
import 'stream_owner_test.dart' show Harness;

void main() {
  for (final held in [true, false]) {
    test('ambiguous ${held ? 'held' : 'live'} terminal repairs once', () async {
      final h = Harness('ses_a');
      addTearDown(h.owner.close);
      h.reads.history = [
        message('new', 'compaction', {
          'status': 'running',
          'reason': 'manual',
          'summary': '',
          'recent': '',
        }),
        message('old', 'compaction', {
          'status': 'completed',
          'reason': 'manual',
          'summary': 'Old checkpoint',
          'recent': '',
        }),
      ];
      await h.connect(1);
      final gate = Completer<void>();
      if (held) h.reads.gate = gate;
      h.owner.watch(h.ref);
      await h.settle();
      await h.send([
        frame('ended', id: 'evt_old_end', data: {'text': 'Old checkpoint'}),
      ]);
      if (held) {
        h.reads.gate = null;
        gate.complete();
        await h.settle();
      }
      expect(
        h.reads.paths.where(
          (path) => Uri.parse(path).path.endsWith('/message'),
        ),
        hasLength(2),
        reason: 'initial hydration plus one bounded authoritative repair',
      );
      expect(h.connection.released, [1]);
      final notices = h.state.timeline.whereType<Notice>().toList();
      expect(notices, hasLength(2));
      expect(notices.first.text, 'Old checkpoint');
      expect(notices.last.status.known, ItemStatus.streaming);
      expect(notices.last.text, isEmpty);
      for (final update in h.updates.whereType<OpenCodeSessionUpdated>()) {
        for (final notice in update.state.timeline.whereType<Notice>()) {
          if (notice.id == notices.last.id) {
            expect(notice.status.known, ItemStatus.streaming);
            expect(notice.text, isEmpty);
          }
        }
      }
    });
  }
}
