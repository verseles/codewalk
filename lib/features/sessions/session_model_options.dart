import 'package:codewalk_core/codewalk_core.dart';

/// What the pick lists for its models (#515), as OpenCode's own clients
/// do: favorites, then recents, then one group per provider, each model
/// once. A search replaces them with one list ranked by relevance.
final class ModelPickOptions {
  const ModelPickOptions({
    required this.favorites,
    required this.recents,
    required this.groups,
    required this.matches,
  });

  final List<ModelEntry> favorites;
  final List<ModelEntry> recents;

  /// Provider id and its models, in the order shown.
  final List<(String, List<ModelEntry>)> groups;

  /// The search results, best first; null while nothing is searched.
  final List<ModelEntry>? matches;
}

/// Builds the pick's lists from the offered [models]. [favoriteKeys] and
/// [recentKeys] are saved keys in their saved order; [current] is the
/// session's model, which stays in reach whatever thins the list.
ModelPickOptions modelPickOptions({
  required List<ModelEntry> models,
  required String Function(ModelEntry model) keyOf,
  required List<String> favoriteKeys,
  required List<String> recentKeys,
  required Map<String, String> providerNames,
  required String query,
  ModelEntry? current,
}) {
  final byKey = {for (final model in models) keyOf(model): model};
  final favoriteSet = favoriteKeys.toSet();
  // Saved names the location does not offer are not shown.
  final favorites = [for (final key in favoriteKeys) ?byKey[key]];
  final recents = [
    for (final key in recentKeys)
      if (!favoriteSet.contains(key)) ?byKey[key],
  ];
  final search = _normalize(query);
  if (search.isNotEmpty) {
    return ModelPickOptions(
      favorites: favorites,
      recents: recents,
      groups: const [],
      matches: _ranked(
        models,
        search,
        providerNames,
        favorite: (model) => favoriteSet.contains(keyOf(model)),
        current: current,
      ),
    );
  }
  final listed = {...favorites, ...recents}.map(keyOf).toSet();
  final older = _olderReleases(models);
  final byProvider = <String, List<ModelEntry>>{};
  for (final model in models) {
    if (listed.contains(keyOf(model))) continue;
    // A retired model, or a release a newer one of its line replaced, is
    // only found by a search; the session's own model always shows.
    if (!identical(model, current) &&
        (model.deprecated || older.contains(model))) {
      continue;
    }
    (byProvider[model.providerId] ??= []).add(model);
  }
  String name(String provider) =>
      (providerNames[provider] ?? provider).toLowerCase();
  int rank(String provider) =>
      byProvider[provider]!.first.providerRank ?? _unranked;
  final providers = byProvider.keys.toList()
    ..sort(
      (a, b) => switch (rank(a).compareTo(rank(b))) {
        0 => switch (name(a).compareTo(name(b))) {
          0 => a.compareTo(b),
          final order => order,
        },
        final order => order,
      },
    );
  return ModelPickOptions(
    favorites: favorites,
    recents: recents,
    groups: [
      for (final provider in providers)
        (provider, _newestFirst(byProvider[provider]!)),
    ],
    matches: null,
  );
}

const _unranked = 1 << 30;

/// Every dated release that a newer one of the same provider, family and
/// price replaced. Undated models and models without a family stay.
Set<ModelEntry> _olderReleases(List<ModelEntry> models) {
  final newest = <(String, String, bool), ModelEntry>{};
  for (final model in models) {
    final (family, released) = (model.family, model.released);
    if (family == null || released == null || model.deprecated) continue;
    final line = (model.providerId, family, model.free);
    final best = newest[line];
    if (best == null || released.isAfter(best.released!)) newest[line] = model;
  }
  return {
    for (final model in models)
      if (model.family case final family?
          when model.released != null &&
              !model.deprecated &&
              !identical(newest[(model.providerId, family, model.free)], model))
        model,
  };
}

/// Free models first, then the newest release; undated models keep the
/// order they came in, after the dated ones.
List<ModelEntry> _newestFirst(List<ModelEntry> models) {
  final order = {for (final (i, model) in models.indexed) model: i};
  int compare(ModelEntry a, ModelEntry b) {
    if (a.free != b.free) return a.free ? -1 : 1;
    final (x, y) = (a.released, b.released);
    if (x != null && y != null && x != y) return y.compareTo(x);
    if ((x == null) != (y == null)) return x == null ? 1 : -1;
    return order[a]!.compareTo(order[b]!);
  }

  return [...models]..sort(compare);
}

/// Lowercase letters and digits of any script, every other run of
/// characters one space, as OpenCode's Web search reads names.
String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(_separators, ' ')
    .trim()
    .replaceAll(_spaces, ' ');

final _separators = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
final _spaces = RegExp(r'\s+');

List<ModelEntry> _ranked(
  List<ModelEntry> models,
  String search,
  Map<String, String> providerNames, {
  required bool Function(ModelEntry model) favorite,
  ModelEntry? current,
}) {
  final scored = <(int, int, int, ModelEntry)>[];
  for (final (index, model) in models.indexed) {
    if (model.deprecated && !identical(model, current)) continue;
    final score = _score(model, search, providerNames);
    if (score == null) continue;
    scored.add((score, favorite(model) ? 0 : 1, index, model));
  }
  scored.sort(
    (a, b) => switch (a.$1.compareTo(b.$1)) {
      0 => switch (a.$2.compareTo(b.$2)) {
        0 => a.$3.compareTo(b.$3),
        final order => order,
      },
      final order => order,
    },
  );
  return [for (final (_, _, _, model) in scored) model];
}

/// How well [model] answers [search], lower first: the name or id itself,
/// its start, the start of its words, anywhere in it, every word anywhere
/// with the provider's name, then its letters in order.
int? _score(
  ModelEntry model,
  String search,
  Map<String, String> providerNames,
) {
  final compact = search.replaceAll(' ', '');
  final names = [_normalize(model.label), _normalize(model.id)];
  final squeezed = [for (final name in names) name.replaceAll(' ', '')];
  if (names.contains(search) || squeezed.contains(compact)) return 0;
  if (names.any((name) => name.startsWith(search)) ||
      squeezed.any((name) => name.startsWith(compact))) {
    return 1;
  }
  final terms = search.split(' ');
  final words = [for (final name in names) ...name.split(' ')];
  if (terms.every((term) => words.any((word) => word.startsWith(term)))) {
    return 2;
  }
  if (names.any((name) => name.contains(search)) ||
      squeezed.any((name) => name.contains(compact))) {
    return 3;
  }
  final everything = [
    ...names,
    _normalize(model.providerId),
    _normalize(providerNames[model.providerId] ?? ''),
  ].join(' ');
  if (terms.every(everything.contains)) return 4;
  if (compact.length > 1 && squeezed.any((name) => _inOrder(compact, name))) {
    return 5;
  }
  return null;
}

/// Whether every character of [needle] appears in [haystack] in order.
bool _inOrder(String needle, String haystack) {
  var at = 0;
  for (final unit in haystack.codeUnits) {
    if (at < needle.length && needle.codeUnitAt(at) == unit) at++;
  }
  return at == needle.length;
}
