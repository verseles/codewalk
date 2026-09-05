import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/domain/entities/session_attention_overlay/session_attention_models.dart';
import 'package:codewalk/presentation/services/session_attention/session_attention_host_protocol.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

SessionAttentionItem _item() => const SessionAttentionItem(
  schemaVersion: 1,
  revision: 1,
  identity: SessionAttentionIdentity(
    serverId: 'server-a',
    directory: '/repo/a',
    rootSessionId: 'session-a',
  ),
  title: 'Session',
  projectLabel: 'Project',
  kind: RootSessionAttentionKind.completed,
  startedAtEpochMs: 1,
  lastObservedAtEpochMs: 2,
  observableBusyElapsedMs: 3,
  assistantMessageId: 'message-a',
  displayText: 'Response',
  speechText: 'Response',
  displayTruncated: false,
  speechTruncated: false,
  completedAtEpochMs: 4,
  opened: false,
  dismissed: false,
  transportCapability: SessionAttentionTransportCapability.live,
  contentDigest: 'digest',
);

void main() {
  test('codec preserves exact identity and snapshot ID', () {
    final snapshot = SessionAttentionHostSnapshot(
      generation: 'generation-a',
      revision: 2,
      presentation: SessionAttentionPresentation.panel,
      bubbleScale: 1.0,
      appInForeground: true,
      activeServerId: 'server-a',
      items: <SessionAttentionItem>[_item()],
      fullResynchronization: true,
      producer: 'restore',
    );

    final json = snapshot.toJson();
    final decoded = SessionAttentionHostSnapshot.fromJson(json);

    expect(decoded.items.single.identity, _item().identity);
    expect((json['items'] as List).single['snapshotId'], _item().snapshotId);
    expect(decoded.presentation, SessionAttentionPresentation.panel);
    expect(decoded.bubbleScale, 1.0);
    expect(decoded.appInForeground, isTrue);
    expect(decoded.producer, 'restore');
  });

  test(
    'rejects stale revisions and requires full resync across generations',
    () {
      final current = SessionAttentionHostSnapshot(
        generation: 'generation-a',
        revision: 4,
        presentation: SessionAttentionPresentation.bubble,
        activeServerId: 'server-a',
        items: const <SessionAttentionItem>[],
      );
      final stale = SessionAttentionHostSnapshot(
        generation: 'generation-a',
        revision: 4,
        presentation: SessionAttentionPresentation.panel,
        activeServerId: 'server-a',
        items: const <SessionAttentionItem>[],
      );
      final wrongGeneration = SessionAttentionHostSnapshot(
        generation: 'generation-b',
        revision: 1,
        presentation: SessionAttentionPresentation.panel,
        activeServerId: 'server-a',
        items: const <SessionAttentionItem>[],
      );
      final resync = SessionAttentionHostSnapshot(
        generation: 'generation-b',
        revision: 1,
        presentation: SessionAttentionPresentation.panel,
        activeServerId: 'server-a',
        items: const <SessionAttentionItem>[],
        fullResynchronization: true,
      );

      expect(stale.supersedes(current), isFalse);
      expect(wrongGeneration.supersedes(current), isFalse);
      expect(resync.supersedes(current), isTrue);
    },
  );

  test('durable snapshot path is mobile-only (issue #176)', () {
    expect(
      sessionAttentionHostNeedsDurableSnapshot(TargetPlatform.android),
      isTrue,
    );
    expect(
      sessionAttentionHostNeedsDurableSnapshot(TargetPlatform.iOS),
      isTrue,
    );
    expect(
      sessionAttentionHostNeedsDurableSnapshot(TargetPlatform.linux),
      isFalse,
    );
    expect(
      sessionAttentionHostNeedsDurableSnapshot(TargetPlatform.windows),
      isFalse,
    );
    expect(
      sessionAttentionHostNeedsDurableSnapshot(TargetPlatform.macOS),
      isFalse,
    );
  });
}
