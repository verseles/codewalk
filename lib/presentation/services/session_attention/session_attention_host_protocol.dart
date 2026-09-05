import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/entities/experience_settings.dart';
import '../../../domain/entities/session_attention_overlay/session_attention_models.dart';

/// Whether [platform] needs the durable SharedPreferences snapshot path
/// (heartbeat epoch, persisted settings re-read, snapshot-store read).
///
/// Only Android (external overlay channel) and iOS (in-app overlay) consume
/// the durable state. Desktop (Linux/Windows/macOS) and web only need the
/// in-memory bus emit, so they skip the disk I/O entirely (issue #176:
///
/// on Linux/Windows every `reload()` + `setInt()` rewrites the whole
/// preferences file synchronously on the UI isolate).
bool sessionAttentionHostNeedsDurableSnapshot(TargetPlatform platform) {
  return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
}

class SessionAttentionHostSnapshot {
  const SessionAttentionHostSnapshot({
    required this.generation,
    required this.revision,
    required this.presentation,
    required this.activeServerId,
    required this.items,
    this.fullResynchronization = false,
    this.producer = 'main',
    this.activeSpeechSnapshotId,
    this.bubbleScale = 0.7,
    this.appInForeground = false,
  });

  final String generation;
  final int revision;
  final SessionAttentionPresentation presentation;
  final String activeServerId;
  final List<SessionAttentionItem> items;
  final bool fullResynchronization;
  final String producer;
  final String? activeSpeechSnapshotId;

  /// Linear factor the Android host applies to the Bubble's base size.
  /// The Panel is unaffected and keeps its fixed dimensions.
  final double bubbleScale;

  /// True while CodeWalk itself is on screen. The external overlay hides then,
  /// so it never covers the app the user is already looking at (#128).
  final bool appInForeground;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': 1,
    'generation': generation,
    'revision': revision,
    'presentation': presentation.name,
    'bubbleScale': bubbleScale,
    'appInForeground': appInForeground,
    'activeServerId': activeServerId,
    'items': items
        .map(
          (item) => <String, dynamic>{
            ...item.toJson(),
            'snapshotId': item.snapshotId,
          },
        )
        .toList(growable: false),
    'fullResynchronization': fullResynchronization,
    'producer': producer,
    'activeSpeechSnapshotId': activeSpeechSnapshotId,
  };

  factory SessionAttentionHostSnapshot.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported session attention host schema.');
    }
    final rawPresentation = json['presentation'];
    var presentation = SessionAttentionPresentation.off;
    for (final value in SessionAttentionPresentation.values) {
      if (value.name == rawPresentation) {
        presentation = value;
        break;
      }
    }
    return SessionAttentionHostSnapshot(
      generation: json['generation'] as String? ?? '',
      revision: json['revision'] as int? ?? 0,
      presentation: presentation,
      bubbleScale: (json['bubbleScale'] as num?)?.toDouble() ?? 0.7,
      appInForeground: json['appInForeground'] as bool? ?? false,
      activeServerId: json['activeServerId'] as String? ?? '',
      items: (json['items'] as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) =>
                SessionAttentionItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      fullResynchronization: json['fullResynchronization'] as bool? ?? false,
      producer: json['producer'] as String? ?? 'main',
      activeSpeechSnapshotId: json['activeSpeechSnapshotId'] as String?,
    );
  }

  bool supersedes(SessionAttentionHostSnapshot? current) {
    if (current == null) return true;
    if (generation != current.generation) return fullResynchronization;
    return revision > current.revision;
  }
}

abstract interface class SessionAttentionSnapshotHostService {
  Future<void> publishSnapshot(SessionAttentionHostSnapshot snapshot);
}

class SessionAttentionHostCommandBus {
  SessionAttentionHostCommandBus._();

  static final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get stream => _controller.stream;

  static void emit(Map<String, dynamic> command) {
    if (!_controller.isClosed) _controller.add(command);
  }
}

class SessionAttentionHostSnapshotBus {
  SessionAttentionHostSnapshotBus._();

  static final StreamController<SessionAttentionHostSnapshot> _controller =
      StreamController<SessionAttentionHostSnapshot>.broadcast();

  static Stream<SessionAttentionHostSnapshot> get stream => _controller.stream;

  static void emit(SessionAttentionHostSnapshot snapshot) {
    if (!_controller.isClosed) _controller.add(snapshot);
  }
}
