import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../storage/metadata_store.dart';
import '../storage/storage_support.dart';

/// Favorite and recent models, kept on this device like the retained
/// reference's (#177–#181): favorites per server, shared by its projects;
/// recent models, agents and variants per server and project, newest first;
/// and each agent's last model there. The server never sees them.
///
/// Models are named `provider/model`. A record that could not be read is
/// never overwritten, because dropping it would lose the user's favorites.
final class ModelPreferenceStore extends ChangeNotifier {
  ModelPreferenceStore({required V2MetadataStore store}) : _store = store;

  /// `{"favorites": {server: [model]}, "recents": [[server, project, [model]]],
  /// "history": [[kind, server, project, scope, [value]]],
  /// "agentModels": [[server, project, agent, model, variant]]}`, each list
  /// least recently used first. The last two are absent from older records.
  static const key = 'cw2.models.preferences';

  /// The retained reference keeps eight recent models, agents and variants.
  static const maxRecents = 8;
  static const maxFavorites = 64;
  static const maxServers = 64;

  /// Rows of each kind; the least recently used one is dropped first.
  static const maxProjects = 64;

  /// The recent variant that leaves the choice to the server.
  static const autoVariant = '';
  static const _maxText = 8193;

  final V2MetadataStore _store;
  final _executor = KeySerialExecutor();
  _Saved _saved = const _Saved();
  bool _loaded = false;
  bool _unreadable = false;
  bool _persistenceError = false;

  bool get loaded => _loaded;

  /// The record could not be read or parsed: nothing is shown or saved.
  bool get unreadable => _unreadable;

  /// The last change could not be saved and was not applied.
  bool get hasPersistenceError => _persistenceError;

  /// Whether a change can be saved now.
  bool get writable => _loaded && !_unreadable;

  Future<void> initialize() async {
    if (_loaded) return;
    await _executor.run(key, () async {
      if (_loaded) return;
      Object? raw;
      var failed = false;
      try {
        raw = await _store.read(key);
      } on Object {
        failed = true;
      }
      final parsed = failed ? null : _parse(raw);
      _unreadable = parsed == null;
      _saved = parsed ?? const _Saved();
      _loaded = true;
      notifyListeners();
    });
  }

  /// The server's favorites, in the order they were starred.
  List<String> favorites(String server) => _saved.favorites[server] ?? const [];

  bool isFavorite(String server, String model) =>
      favorites(server).contains(model);

  /// The project's recent models on this server, newest first.
  List<String> recents(String server, String project) =>
      _values(_Kind.model, server, project, '');

  /// The project's recent agents on this server, newest first.
  List<String> agentRecents(String server, String project) =>
      _values(_Kind.agent, server, project, '');

  /// The variants recently used with [model], newest first; [autoVariant]
  /// stands for Auto.
  List<String> variantRecents(String server, String project, String model) =>
      _values(_Kind.variant, server, project, model);

  /// The model and variant [agent] last used in the project.
  (String model, String? variant)? agentModel(
    String server,
    String project,
    String agent,
  ) {
    final row = _saved.agentModels
        .where(
          (r) => r.server == server && r.project == project && r.agent == agent,
        )
        .firstOrNull;
    return row == null ? null : (row.model, row.variant);
  }

  List<String> _values(
    _Kind kind,
    String server,
    String project,
    String scope,
  ) =>
      _saved.history
          .where(
            (r) =>
                r.kind == kind &&
                r.server == server &&
                r.project == project &&
                r.scope == scope,
          )
          .firstOrNull
          ?.values ??
      const [];

  /// Stars or unstars [model] for every project of [server]. False when it
  /// was not saved, which leaves the favorites as they were.
  Future<bool> setFavorite(
    String server,
    String model, {
    required bool favorite,
  }) => _change(() {
    final current = favorites(server);
    if (current.contains(model) == favorite) return null;
    final all = _saved.favorites;
    if (favorite &&
        (current.length >= maxFavorites ||
            (current.isEmpty && all.length >= maxServers))) {
      return null;
    }
    final next = favorite
        ? [...current, model]
        : current.where((m) => m != model).toList();
    final saved = {...all};
    if (next.isEmpty) {
      saved.remove(server);
    } else {
      saved[server] = List.unmodifiable(next);
    }
    return _saved.copyWith(favorites: Map.unmodifiable(saved));
  }, valid: _valid(server) && _valid(model));

  /// Puts [model] first among the project's recents, then the [previous]
  /// one, so the first cycling press goes back to it. False when nothing
  /// was saved.
  Future<bool> recordRecent(
    String server,
    String project,
    String model, {
    String? previous,
  }) => _record(_Kind.model, server, project, '', model, previous);

  /// Puts [agent] first among the project's recent agents, then [previous].
  Future<bool> recordAgent(
    String server,
    String project,
    String agent, {
    String? previous,
  }) => _record(_Kind.agent, server, project, '', agent, previous);

  /// Puts [variant] first among the variants used with [model], then
  /// [previous]; [autoVariant] stands for Auto.
  Future<bool> recordVariant(
    String server,
    String project,
    String model,
    String variant, {
    String? previous,
  }) => _record(_Kind.variant, server, project, model, variant, previous);

  /// Remembers the model and variant [agent] used in the project.
  Future<bool> rememberAgentModel(
    String server,
    String project,
    String agent,
    String model,
    String? variant,
  ) => _change(
    () {
      final current = agentModel(server, project, agent);
      if (current != null && current == (model, variant)) return null;
      final rows = [
        ..._saved.agentModels.where(
          (r) => r.server != server || r.project != project || r.agent != agent,
        ),
        _AgentModel(server, project, agent, model, variant),
      ];
      while (rows.length > maxProjects) {
        rows.removeAt(0);
      }
      return _saved.copyWith(agentModels: List.unmodifiable(rows));
    },
    valid:
        _valid(server) &&
        _valid(project) &&
        _valid(agent) &&
        _valid(model) &&
        (variant == null || _valid(variant)),
  );

  Future<bool> _record(
    _Kind kind,
    String server,
    String project,
    String scope,
    String value,
    String? previous,
  ) => _change(
    () {
      final current = _values(kind, server, project, scope);
      final next = <String>[
        value,
        if (previous != null && previous != value) previous,
        ...current.where((v) => v != value && v != previous),
      ].take(maxRecents).toList(growable: false);
      if (listEquals(next, current)) return null;
      final rows = [
        ..._saved.history.where(
          (r) =>
              r.kind != kind ||
              r.server != server ||
              r.project != project ||
              r.scope != scope,
        ),
        _History(kind, server, project, scope, next),
      ];
      // Each kind keeps its own bound, dropping its least recent row.
      while (rows.where((r) => r.kind == kind).length > maxProjects) {
        rows.remove(rows.firstWhere((r) => r.kind == kind));
      }
      return _saved.copyWith(history: List.unmodifiable(rows));
    },
    valid:
        _valid(server) &&
        _valid(project) &&
        (kind == _Kind.variant ? _valid(scope) : scope.isEmpty) &&
        kind.allows(value) &&
        (previous == null || kind.allows(previous)),
  );

  Future<bool> _change(_Saved? Function() next, {required bool valid}) async {
    if (!valid || !writable) return false;
    return _executor.run(key, () async {
      if (!writable) return false;
      final state = next();
      if (state == null) return false;
      try {
        await _store.write(key, state.encode());
      } on Object {
        _persistenceError = true;
        notifyListeners();
        return false;
      }
      _saved = state;
      _persistenceError = false;
      notifyListeners();
      return true;
    });
  }

  static bool _valid(String text) => text.isNotEmpty && text.length <= _maxText;

  /// Null when [raw] is not a record this store wrote.
  static _Saved? _parse(Object? raw) {
    if (raw == null) return const _Saved();
    if (raw is! String || raw.length > V2MetadataStore.maxPreferenceChars) {
      return null;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    const known = {'favorites', 'recents', 'history', 'agentModels'};
    if (decoded is! Map<String, Object?> ||
        !decoded.keys.every(known.contains) ||
        decoded['favorites'] is! Map<String, Object?> ||
        decoded['recents'] is! List<Object?> ||
        (decoded['history'] ?? const <Object?>[]) is! List<Object?> ||
        (decoded['agentModels'] ?? const <Object?>[]) is! List<Object?>) {
      return null;
    }
    List<String>? values(Object? value, int max, bool Function(String) ok) {
      if (value is! List<Object?> || value.isEmpty || value.length > max) {
        return null;
      }
      final list = <String>[];
      for (final item in value) {
        if (item is! String || !ok(item) || list.contains(item)) return null;
        list.add(item);
      }
      return List.unmodifiable(list);
    }

    final favorites = <String, List<String>>{};
    final favoriteRows = decoded['favorites']! as Map<String, Object?>;
    if (favoriteRows.length > maxServers) return null;
    for (final MapEntry(key: server, value: value) in favoriteRows.entries) {
      final list = values(value, maxFavorites, _valid);
      if (!_valid(server) || list == null) return null;
      favorites[server] = list;
    }
    final history = <_History>[];
    bool add(
      _Kind kind,
      Object? server,
      Object? project,
      Object? scope,
      Object? value,
    ) {
      if (server is! String ||
          project is! String ||
          scope is! String ||
          !_valid(server) ||
          !_valid(project) ||
          (kind == _Kind.variant ? !_valid(scope) : scope.isNotEmpty)) {
        return false;
      }
      final list = values(value, maxRecents, kind.allows);
      if (list == null ||
          history.any(
            (r) =>
                r.kind == kind &&
                r.server == server &&
                r.project == project &&
                r.scope == scope,
          )) {
        return false;
      }
      history.add(_History(kind, server, project, scope, list));
      return true;
    }

    final recentRows = decoded['recents']! as List<Object?>;
    if (recentRows.length > maxProjects) return null;
    for (final row in recentRows) {
      if (row is! List<Object?> || row.length != 3) return null;
      if (!add(_Kind.model, row[0], row[1], '', row[2])) return null;
    }
    final historyRows = (decoded['history'] ?? const <Object?>[]) as List;
    for (final row in historyRows) {
      if (row is! List<Object?> || row.length != 5) return null;
      final kind = switch (row[0]) {
        'agent' => _Kind.agent,
        'variant' => _Kind.variant,
        _ => null,
      };
      if (kind == null || !add(kind, row[1], row[2], row[3], row[4])) {
        return null;
      }
    }
    for (final kind in _Kind.values) {
      if (history.where((r) => r.kind == kind).length > maxProjects) {
        return null;
      }
    }
    final agentModels = <_AgentModel>[];
    final agentRows = (decoded['agentModels'] ?? const <Object?>[]) as List;
    if (agentRows.length > maxProjects) return null;
    for (final row in agentRows) {
      if (row
          case [
            final String server,
            final String project,
            final String agent,
            final String model,
            final String? variant,
          ]
          when [server, project, agent, model, ?variant].every(_valid) &&
              !agentModels.any(
                (r) =>
                    r.server == server &&
                    r.project == project &&
                    r.agent == agent,
              )) {
        agentModels.add(_AgentModel(server, project, agent, model, variant));
      } else {
        return null;
      }
    }
    return _Saved(
      favorites: Map.unmodifiable(favorites),
      history: List.unmodifiable(history),
      agentModels: List.unmodifiable(agentModels),
    );
  }
}

enum _Kind {
  model,
  agent,
  variant;

  /// A variant's history holds Auto as [ModelPreferenceStore.autoVariant].
  bool allows(String value) => this == _Kind.variant && value.isEmpty
      ? true
      : ModelPreferenceStore._valid(value);
}

final class _Saved {
  const _Saved({
    this.favorites = const {},
    this.history = const [],
    this.agentModels = const [],
  });
  final Map<String, List<String>> favorites;
  final List<_History> history;
  final List<_AgentModel> agentModels;

  _Saved copyWith({
    Map<String, List<String>>? favorites,
    List<_History>? history,
    List<_AgentModel>? agentModels,
  }) => _Saved(
    favorites: favorites ?? this.favorites,
    history: history ?? this.history,
    agentModels: agentModels ?? this.agentModels,
  );

  String encode() => jsonEncode({
    'favorites': favorites,
    'recents': [
      for (final r in history.where((r) => r.kind == _Kind.model))
        [r.server, r.project, r.values],
    ],
    'history': [
      for (final r in history.where((r) => r.kind != _Kind.model))
        [r.kind.name, r.server, r.project, r.scope, r.values],
    ],
    'agentModels': [
      for (final r in agentModels)
        [r.server, r.project, r.agent, r.model, r.variant],
    ],
  });
}

final class _History {
  const _History(this.kind, this.server, this.project, this.scope, this.values);
  final _Kind kind;
  final String server;
  final String project;

  /// A variant's model; empty for models and agents.
  final String scope;
  final List<String> values;
}

final class _AgentModel {
  const _AgentModel(
    this.server,
    this.project,
    this.agent,
    this.model,
    this.variant,
  );
  final String server;
  final String project;
  final String agent;
  final String model;
  final String? variant;
}
