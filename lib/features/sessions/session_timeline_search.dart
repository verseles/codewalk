import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';

/// Find in the open conversation (#462). It searches the conversation as
/// loaded here, in the harness-neutral items every harness gives, so it
/// needs no capability: the user's messages, the answers and, while shown,
/// the reasoning, ignoring case.
///
/// Matches run from the newest, as a reader at the bottom meets them: the
/// first is the newest, and the next one is older. The current match is
/// kept by its item, so content arriving meanwhile never moves it.
class SessionTimelineSearch extends ChangeNotifier {
  bool _open = false;
  String _query = '';
  ItemId? _current;
  int _reveals = 0;
  int _focuses = 0;

  /// Whether the search bar is shown.
  bool get open => _open;
  String get query => _query;

  /// The match shown to the reader.
  ItemId? get current => _current;

  /// Grows each time the current match should be scrolled into view.
  int get reveals => _reveals;

  /// Grows each time the search field should take the focus again.
  int get focuses => _focuses;

  /// Opens the search, or takes the focus back to its field.
  void show() {
    _open = true;
    _focuses++;
    notifyListeners();
  }

  void close() {
    if (!_open) return;
    _open = false;
    _query = '';
    _current = null;
    _lowered.clear();
    notifyListeners();
  }

  /// Searches [items] for [query] and shows the newest match.
  void search(
    String query,
    List<TimelineItem> items, {
    bool reasoning = true,
    Set<ItemId> held = const {},
  }) {
    _query = query;
    _current = matches(items, reasoning: reasoning, held: held).firstOrNull;
    _reveals++;
    notifyListeners();
  }

  /// Moves to the next older match ([older]) or the next newer one, wrapping
  /// at either end.
  void step(
    List<TimelineItem> items, {
    bool older = true,
    bool reasoning = true,
    Set<ItemId> held = const {},
  }) {
    final found = matches(items, reasoning: reasoning, held: held);
    if (found.isEmpty) return;
    final at = _current == null ? -1 : found.indexOf(_current!);
    final next = at < 0
        ? 0
        : (at + (older ? 1 : -1) + found.length) % found.length;
    _current = found[next];
    _reveals++;
    notifyListeners();
  }

  /// The items of [items] that hold the query, newest first. The answers and
  /// reasoning in [held], which the Block render mode does not show yet, are
  /// not found yet either.
  List<ItemId> matches(
    List<TimelineItem> items, {
    bool reasoning = true,
    Set<ItemId> held = const {},
  }) {
    final last = _last;
    // Read on every build while a reply streams: the same items and query
    // are not searched again.
    if (last != null &&
        identical(last.items, items) &&
        last.query == _query &&
        last.reasoning == reasoning &&
        setEquals(last.held, held)) {
      return last.found;
    }
    if (last != null && !identical(last.items, items)) {
      // Items that left the conversation as loaded are not kept.
      final resident = {for (final item in items) item.id};
      _lowered.removeWhere((id, _) => !resident.contains(id));
    }
    final query = _query.trim().toLowerCase();
    final found = query.isEmpty
        ? const <ItemId>[]
        : List<ItemId>.unmodifiable([
            for (final item in items.reversed)
              if (!held.contains(item.id) &&
                  _lower(item, reasoning: reasoning).contains(query))
                item.id,
          ]);
    _last = (
      items: items,
      query: _query,
      reasoning: reasoning,
      held: held,
      found: found,
    );
    return found;
  }

  ({
    List<TimelineItem> items,
    String query,
    bool reasoning,
    Set<ItemId> held,
    List<ItemId> found,
  })?
  _last;

  /// Each item's text in lower case, kept while its text is the same, so a
  /// streamed chunk lowers only the text that changed.
  final _lowered = <ItemId, (String, String)>{};

  String _lower(TimelineItem item, {required bool reasoning}) {
    final text = searchableText(item, reasoning: reasoning);
    if (text == null) return '';
    final kept = _lowered[item.id];
    if (kept != null && identical(kept.$1, text)) return kept.$2;
    final lower = text.toLowerCase();
    _lowered[item.id] = (text, lower);
    return lower;
  }

  /// The text of [item] a search reads, or null when it reads none.
  static String? searchableText(TimelineItem item, {bool reasoning = true}) =>
      switch (item) {
        UserInput(:final text) => text,
        AssistantText(:final text) => text,
        Reasoning(:final text) when reasoning => text,
        _ => null,
      };
}
