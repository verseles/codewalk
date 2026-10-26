import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';

import '../storage/metadata_store.dart';
import '../storage/storage_support.dart';

/// One open session tab: the full session identity, the project the server
/// gave it when it was opened, and what the strip shows before the list
/// loads.
@immutable
final class SessionTab {
  const SessionTab({
    required this.ref,
    required this.project,
    required this.title,
    required this.lastOpenedAtMs,
    this.updatedAtMs,
  });

  final SessionRef ref;

  /// The project the server attributed the session to; null is the group of
  /// the sessions without one. It never takes part in the identity.
  final ProjectRef? project;
  final String title;

  /// The last time the tab was opened, for the most-recent order.
  final int lastOpenedAtMs;

  /// The session's last update the server reported, when known: with
  /// [lastOpenedAtMs] it keeps the tab among the recent ones.
  final int? updatedAtMs;

  SessionTab copyWith({
    ProjectRef? project,
    bool clearProject = false,
    String? title,
    int? lastOpenedAtMs,
    int? updatedAtMs,
  }) => SessionTab(
    ref: ref,
    project: clearProject ? null : (project ?? this.project),
    title: title ?? this.title,
    lastOpenedAtMs: lastOpenedAtMs ?? this.lastOpenedAtMs,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
  );

  @override
  bool operator ==(Object other) =>
      other is SessionTab &&
      ref == other.ref &&
      project == other.project &&
      title == other.title &&
      lastOpenedAtMs == other.lastOpenedAtMs &&
      updatedAtMs == other.updatedAtMs;

  @override
  int get hashCode =>
      Object.hash(ref, project, title, lastOpenedAtMs, updatedAtMs);
}

/// A tab the user closed: it is not listed again until the user opens it or
/// the server reports an update newer than [updatedAtMs]. Closing a tab never
/// changes the session on the server.
@immutable
final class SessionTabSuppression {
  const SessionTabSuppression({
    required this.ref,
    required this.project,
    required this.closedAtMs,
    this.updatedAtMs,
  });

  final SessionRef ref;
  final ProjectRef? project;
  final int closedAtMs;

  /// The server's last update known when it was closed; null until one is
  /// seen, and the first one seen only sets it.
  final int? updatedAtMs;

  SessionTabSuppression withUpdatedAt(int updatedAtMs) => SessionTabSuppression(
    ref: ref,
    project: project,
    closedAtMs: closedAtMs,
    updatedAtMs: updatedAtMs,
  );

  @override
  bool operator ==(Object other) =>
      other is SessionTabSuppression &&
      ref == other.ref &&
      project == other.project &&
      closedAtMs == other.closedAtMs &&
      updatedAtMs == other.updatedAtMs;

  @override
  int get hashCode => Object.hash(ref, project, closedAtMs, updatedAtMs);
}

/// The open tabs of every server in visual order, and the selected tab of
/// each server.
@immutable
final class SessionTabsState {
  SessionTabsState({
    List<SessionTab> tabs = const [],
    Map<HostId, SessionRef> selected = const {},
    List<SessionTabSuppression> suppressed = const [],
  }) : tabs = List.unmodifiable(tabs),
       selected = Map.unmodifiable(selected),
       suppressed = List.unmodifiable(suppressed);

  final List<SessionTab> tabs;
  final Map<HostId, SessionRef> selected;

  /// The tabs the user closed, oldest first.
  final List<SessionTabSuppression> suppressed;

  SessionTabsState copyWith({
    List<SessionTab>? tabs,
    Map<HostId, SessionRef>? selected,
    List<SessionTabSuppression>? suppressed,
  }) => SessionTabsState(
    tabs: tabs ?? this.tabs,
    selected: selected ?? this.selected,
    suppressed: suppressed ?? this.suppressed,
  );

  /// The closed record of [ref], if any.
  SessionTabSuppression? suppressionOf(SessionRef ref) =>
      suppressed.where((entry) => entry.ref == ref).firstOrNull;

  /// This state with [entry] recorded as closed, the oldest records leaving
  /// beyond [SessionTabsStore.maxSuppressed]: they are history, not choices.
  SessionTabsState suppressing(SessionTabSuppression entry) {
    final next = [
      for (final other in suppressed)
        if (other.ref != entry.ref) other,
      entry,
    ];
    final overflow = next.length - SessionTabsStore.maxSuppressed;
    return copyWith(suppressed: overflow > 0 ? next.sublist(overflow) : next);
  }

  /// This state without the closed record of [ref]: it was opened again.
  SessionTabsState unsuppressing(SessionRef ref) =>
      suppressed.any((entry) => entry.ref == ref)
      ? copyWith(suppressed: [...suppressed.where((e) => e.ref != ref)])
      : this;
}

/// The open session tabs, a local state the endpoint never sees.
///
/// One record holds the tabs of every server, so the order and the selection
/// change together. Reading never writes, so restoring the same record twice
/// gives the same tabs. A record that could not be read is never overwritten:
/// dropping it would lose tabs the user left open.
final class SessionTabsStore extends ChangeNotifier {
  SessionTabsStore({required V2MetadataStore store}) : _store = store;

  static const key = 'cw2.sessions.tabs';
  static const version = 1;

  /// The open tabs across every server.
  static const maxTabs = 32;

  /// The closed tabs remembered across every server.
  static const maxSuppressed = 512;
  static const maxTitleChars = 200;

  final V2MetadataStore _store;
  final _executor = KeySerialExecutor();
  SessionTabsState _state = SessionTabsState();
  Future<void>? _initialization;
  bool _loaded = false;
  bool _unreadable = false;
  bool _persistenceError = false;

  SessionTabsState get state => _state;

  /// True when the record was read.
  bool get loaded => _loaded;

  /// True when the record could not be read or parsed. Its content is
  /// unknown, so no tab is shown from it and it is never overwritten.
  bool get unreadable => _unreadable;

  /// True when the last write failed and was reverted.
  bool get hasPersistenceError => _persistenceError;

  /// Reads the record once; concurrent callers share the same read.
  Future<void> initialize() => _initialization ??= _executor.run(key, () async {
    final Object? raw;
    try {
      requireV2Key(key);
      raw = await _store.read(key);
    } on Object {
      _unreadable = true;
      _finishLoad();
      return;
    }
    final decoded = decode(raw);
    if (decoded == null) {
      _unreadable = true;
    } else {
      _state = decoded;
    }
    _finishLoad();
  });

  void _finishLoad() {
    _loaded = true;
    notifyListeners();
  }

  /// Applies [change] to the state at its turn, so concurrent changes never
  /// overwrite each other. The result is written and only then becomes the
  /// state, so a failed write leaves the tabs as they were. A null result
  /// changes nothing. False when nothing was saved.
  Future<bool> update(
    SessionTabsState? Function(SessionTabsState current) change,
  ) async {
    await initialize();
    if (_unreadable) return false;
    var written = false;
    await _executor.run(key, () async {
      final next = change(_state);
      if (next == null || next.tabs.length > maxTabs) return;
      try {
        await _store.write(key, encode(next));
      } on Object {
        _persistenceError = true;
        notifyListeners();
        return;
      }
      _state = next;
      _persistenceError = false;
      written = true;
      notifyListeners();
    });
    return written;
  }

  /// The record of [state]; titles are bounded so the record stays small.
  @visibleForTesting
  static String encode(SessionTabsState state) => jsonEncode({
    'version': version,
    'tabs': [
      for (final tab in state.tabs)
        {
          'ref': tab.ref.storageKey,
          'project': tab.project?.storageKey,
          'title': boundTitle(tab.title),
          'lastOpenedAtMs': tab.lastOpenedAtMs,
          'updatedAtMs': ?tab.updatedAtMs,
        },
    ],
    'selected': {
      for (final MapEntry(:key, :value) in state.selected.entries)
        key.value: value.storageKey,
    },
    // Added fields: an older reader ignores them and keeps its tabs.
    if (state.suppressed.isNotEmpty)
      'suppressed': [
        for (final entry in state.suppressed)
          {
            'ref': entry.ref.storageKey,
            'project': entry.project?.storageKey,
            'closedAtMs': entry.closedAtMs,
            'updatedAtMs': ?entry.updatedAtMs,
          },
      ],
  });

  /// The state of a stored record, or null when it is not one this version
  /// reads. A missing record is no tabs. Duplicates keep the first tab, and
  /// a selection that names no open tab of its server is ignored.
  @visibleForTesting
  static SessionTabsState? decode(Object? raw) {
    if (raw == null) return SessionTabsState();
    if (raw is! String || raw.isEmpty) return null;
    if (raw.length > V2MetadataStore.maxPreferenceChars) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?> || json['version'] != version) {
        return null;
      }
      final rawTabs = json['tabs'];
      final rawSelected = json['selected'];
      if (rawTabs is! List || rawSelected is! Map<String, Object?>) {
        return null;
      }
      if (rawTabs.length > maxTabs) return null;
      final tabs = <SessionTab>[];
      final seen = <SessionRef>{};
      for (final entry in rawTabs) {
        if (entry is! Map<String, Object?>) return null;
        final ref = SessionRef.fromStorageKey(entry['ref']! as String);
        final project = switch (entry['project']) {
          null => null,
          final String key => ProjectRef.fromStorageKey(key),
          _ => throw const FormatException('project'),
        };
        // A project of another server would show the tab in a set it never
        // belonged to.
        if (project != null && project.host != ref.host) return null;
        final title = entry['title']! as String;
        final opened = entry['lastOpenedAtMs']! as int;
        final updated = entry['updatedAtMs'] as int?;
        if (seen.add(ref)) {
          tabs.add(
            SessionTab(
              ref: ref,
              project: project,
              title: boundTitle(title),
              lastOpenedAtMs: opened,
              updatedAtMs: updated,
            ),
          );
        }
      }
      final selected = <HostId, SessionRef>{};
      for (final MapEntry(:key, :value) in rawSelected.entries) {
        final ref = SessionRef.fromStorageKey(value! as String);
        if (ref.host.value == key && seen.contains(ref)) {
          selected[ref.host] = ref;
        }
      }
      final rawSuppressed = json['suppressed'] ?? const <Object?>[];
      if (rawSuppressed is! List || rawSuppressed.length > maxSuppressed) {
        return null;
      }
      final suppressed = <SessionTabSuppression>[];
      final closed = <SessionRef>{};
      for (final entry in rawSuppressed) {
        if (entry is! Map<String, Object?>) return null;
        final ref = SessionRef.fromStorageKey(entry['ref']! as String);
        final project = switch (entry['project']) {
          null => null,
          final String key => ProjectRef.fromStorageKey(key),
          _ => throw const FormatException('project'),
        };
        if (project != null && project.host != ref.host) return null;
        // A session open again is not closed.
        if (seen.contains(ref) || !closed.add(ref)) continue;
        suppressed.add(
          SessionTabSuppression(
            ref: ref,
            project: project,
            closedAtMs: entry['closedAtMs']! as int,
            updatedAtMs: entry['updatedAtMs'] as int?,
          ),
        );
      }
      return SessionTabsState(
        tabs: tabs,
        selected: selected,
        suppressed: suppressed,
      );
    } on Object {
      // A wrong type, a malformed key or bad JSON: the record is not read.
      return null;
    }
  }

  /// [title] cut to [maxTitleChars] characters.
  static String boundTitle(String title) {
    final runes = title.runes;
    if (runes.length <= maxTitleChars) return title;
    return String.fromCharCodes(runes.take(maxTitleChars));
  }
}
