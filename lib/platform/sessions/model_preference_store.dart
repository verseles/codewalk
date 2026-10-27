import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../storage/metadata_store.dart';
import '../storage/storage_support.dart';

/// Favorite and recent models, kept on this device like the retained
/// reference's (#177): favorites per server, shared by its projects; recents
/// per server and project, newest first. The server never sees them.
///
/// Models are named `provider/model`. A record that could not be read is
/// never overwritten, because dropping it would lose the user's favorites.
final class ModelPreferenceStore extends ChangeNotifier {
  ModelPreferenceStore({required V2MetadataStore store}) : _store = store;

  /// `{"favorites": {server: [model]}, "recents": [[server, project, [model]]]}`,
  /// the recents' projects least recently used first.
  static const key = 'cw2.models.preferences';

  /// The retained reference keeps eight recent models.
  static const maxRecents = 8;
  static const maxFavorites = 64;
  static const maxServers = 64;

  /// Projects with recents; the least recently used one is dropped first.
  static const maxProjects = 64;
  static const _maxText = 8193;

  final V2MetadataStore _store;
  final _executor = KeySerialExecutor();
  Map<String, List<String>> _favorites = const {};
  List<_Recents> _recents = const [];
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
      _favorites = parsed?.$1 ?? const {};
      _recents = parsed?.$2 ?? const [];
      _loaded = true;
      notifyListeners();
    });
  }

  /// The server's favorites, in the order they were starred.
  List<String> favorites(String server) => _favorites[server] ?? const [];

  /// The project's recent models on this server, newest first.
  List<String> recents(String server, String project) =>
      _recents
          .where((r) => r.server == server && r.project == project)
          .firstOrNull
          ?.models ??
      const [];

  bool isFavorite(String server, String model) =>
      favorites(server).contains(model);

  /// Stars or unstars [model] for every project of [server]. False when it
  /// was not saved, which leaves the favorites as they were.
  Future<bool> setFavorite(
    String server,
    String model, {
    required bool favorite,
  }) => _change(() {
    final current = favorites(server);
    if (current.contains(model) == favorite) return null;
    if (favorite &&
        (current.length >= maxFavorites ||
            (current.isEmpty && _favorites.length >= maxServers))) {
      return null;
    }
    final next = favorite
        ? [...current, model]
        : current.where((m) => m != model).toList();
    final saved = {..._favorites};
    if (next.isEmpty) {
      saved.remove(server);
    } else {
      saved[server] = List.unmodifiable(next);
    }
    return (saved, _recents);
  }, valid: _valid(server) && _valid(model));

  /// Puts [model] first among the project's recents, which keep
  /// [maxRecents]. False when it was not saved.
  Future<bool> recordRecent(String server, String project, String model) =>
      _change(() {
        final current = recents(server, project);
        if (current.firstOrNull == model) return null;
        final entry = _Recents(
          server,
          project,
          [
            model,
            ...current.where((m) => m != model),
          ].take(maxRecents).toList(growable: false),
        );
        final saved = [
          ..._recents.where((r) => r.server != server || r.project != project),
          entry,
        ];
        while (saved.length > maxProjects) {
          saved.removeAt(0);
        }
        return (_favorites, List<_Recents>.unmodifiable(saved));
      }, valid: _valid(server) && _valid(project) && _valid(model));

  Future<bool> _change(
    (Map<String, List<String>>, List<_Recents>)? Function() next, {
    required bool valid,
  }) async {
    if (!valid || !writable) return false;
    return _executor.run(key, () async {
      if (!writable) return false;
      final state = next();
      if (state == null) return false;
      final (favorites, recents) = state;
      try {
        await _store.write(key, _encode(favorites, recents));
      } on Object {
        _persistenceError = true;
        notifyListeners();
        return false;
      }
      _favorites = Map.unmodifiable(favorites);
      _recents = recents;
      _persistenceError = false;
      notifyListeners();
      return true;
    });
  }

  static bool _valid(String text) => text.isNotEmpty && text.length <= _maxText;

  static String _encode(
    Map<String, List<String>> favorites,
    List<_Recents> recents,
  ) => jsonEncode({
    'favorites': favorites,
    'recents': [
      for (final r in recents) [r.server, r.project, r.models],
    ],
  });

  /// Null when [raw] is not a record this store wrote.
  static (Map<String, List<String>>, List<_Recents>)? _parse(Object? raw) {
    if (raw == null) return (const {}, const []);
    if (raw is! String || raw.length > V2MetadataStore.maxPreferenceChars) {
      return null;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?> ||
        decoded.length != 2 ||
        decoded['favorites'] is! Map<String, Object?> ||
        decoded['recents'] is! List<Object?>) {
      return null;
    }
    List<String>? models(Object? value, int max) {
      if (value is! List<Object?> || value.length > max) return null;
      final list = <String>[];
      for (final model in value) {
        if (model is! String || !_valid(model) || list.contains(model)) {
          return null;
        }
        list.add(model);
      }
      return List.unmodifiable(list);
    }

    final favorites = <String, List<String>>{};
    final favoriteRows = decoded['favorites']! as Map<String, Object?>;
    if (favoriteRows.length > maxServers) return null;
    for (final MapEntry(key: server, value: value) in favoriteRows.entries) {
      final list = models(value, maxFavorites);
      if (!_valid(server) || list == null || list.isEmpty) return null;
      favorites[server] = list;
    }
    final recents = <_Recents>[];
    final recentRows = decoded['recents']! as List<Object?>;
    if (recentRows.length > maxProjects) return null;
    for (final row in recentRows) {
      if (row case [
        final String server,
        final String project,
        final Object? value,
      ] when _valid(server) && _valid(project)) {
        final list = models(value, maxRecents);
        if (list == null ||
            list.isEmpty ||
            recents.any((r) => r.server == server && r.project == project)) {
          return null;
        }
        recents.add(_Recents(server, project, list));
      } else {
        return null;
      }
    }
    return (favorites, List.unmodifiable(recents));
  }
}

final class _Recents {
  const _Recents(this.server, this.project, this.models);
  final String server;
  final String project;
  final List<String> models;
}
