import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/utils/session_tab_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

SessionTabRecord tab(
  String sessionId,
  String directory, {
  String serverId = 's1',
  String? projectId,
  bool isPinned = false,
}) {
  return SessionTabRecord(
    identity: SessionTabIdentity(
      serverId: serverId,
      directory: directory,
      sessionId: sessionId,
    ),
    projectId: projectId,
    title: sessionId,
    lastOpenedAtMs: 0,
    serverUpdatedAtMs: 0,
    status: SessionStatusType.idle,
    isPinned: isPinned,
  );
}

void main() {
  test('groups interleaved tabs by project preserving order', () {
    final tabs = [tab('a1', '/a'), tab('b1', '/b'), tab('a2', '/a')];
    final grouped = groupSessionTabsByProject(tabs);
    expect(grouped.map((t) => t.identity.sessionId).toList(), [
      'a1',
      'a2',
      'b1',
    ]);
  });

  test('pins stay first in original order', () {
    final tabs = [
      tab('r1', '/a'),
      tab('p1', '/b', isPinned: true),
      tab('r2', '/b'),
    ];
    final grouped = groupSessionTabsByProject(tabs);
    expect(grouped.first.identity.sessionId, 'p1');
  });

  test('anchors only last regular per group without draft', () {
    final tabs = [tab('a1', '/a'), tab('a2', '/a'), tab('b1', '/b')];
    final anchors = projectNewChatAnchors(groupSessionTabsByProject(tabs));
    expect(anchors.map((i) => i.sessionId).toSet(), {'a2', 'b1'});
  });

  test('group with draft has no anchor', () {
    final tabs = [tab('a1', '/a'), tab('', '/a'), tab('b1', '/b')];
    final anchors = projectNewChatAnchors(groupSessionTabsByProject(tabs));
    expect(anchors.map((i) => i.sessionId).toSet(), {'b1'});
  });

  test('root directory falls back to projectId', () {
    expect(
      sessionTabProjectGroupKey(tab('x', '/', projectId: 'p1')),
      sessionTabProjectGroupKey(tab('y', '/', projectId: 'p1')),
    );
    expect(
      sessionTabProjectGroupKey(tab('x', '/', projectId: 'p1')) ==
          sessionTabProjectGroupKey(tab('y', '/other')),
      isFalse,
    );
  });
}
