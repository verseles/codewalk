import 'package:codewalk/features/sessions/session_tab_projection.dart';
import 'package:codewalk/platform/sessions/session_tabs_store.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

SessionTab _tab(String id, String directory, {String host = 'a'}) => SessionTab(
  ref: SessionRef(HostId(host), const HarnessInstanceId('h'), id),
  project: ProjectRef(HostId(host), directory),
  title: id,
  lastOpenedAtMs: 0,
);

void main() {
  test(
    'pins lead, regular groups are stable, and saved order stays intact',
    () {
      final tabs = [
        _tab('p1', '/p'),
        _tab('q1', '/q'),
        _tab('p2', '/p'),
        _tab('pin', '/q'),
        _tab('other', '/p', host: 'b'),
      ];
      final projection = SessionTabProjection(
        tabs: tabs,
        host: const HostId('a'),
        isPinned: (tab) => tab.ref.nativeId == 'pin',
      );
      expect(projection.ordered.map((t) => t.ref.nativeId), [
        'pin',
        'p1',
        'p2',
        'q1',
      ]);
      expect(tabs.map((t) => t.ref.nativeId), [
        'p1',
        'q1',
        'p2',
        'pin',
        'other',
      ]);
      expect(projection.neighbour(tabs[2].ref), tabs[1].ref);
      expect(projection.neighbour(tabs[1].ref), tabs[2].ref);
      expect(projection.neighbour(tabs[3].ref), tabs[0].ref);
      expect(projection.neighbour(tabs[4].ref), isNull);
    },
  );
}
