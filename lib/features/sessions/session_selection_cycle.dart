/// What a cycling shortcut moves through; each keeps its own burst.
enum SelectionCycleDomain { model, agent, variant }

/// Alt+Tab-style cycling, like the retained reference's (#179): the first
/// press goes to the item used before the current one; presses within
/// [window] continue through the order taken at the first press, most
/// recent first and not limited to two; a longer pause starts over. Without
/// two remembered items it steps through the candidates in order.
final class SelectionCycle {
  SelectionCycle({
    required DateTime Function() now,
    this.window = const Duration(seconds: 3),
  }) : _now = now;

  final DateTime Function() _now;
  final Duration window;
  final _bursts = <SelectionCycleDomain, _Burst>{};

  /// The item to switch to from [current], or null when there is none.
  /// [candidates] are what can be picked now, in their usual order;
  /// [history] is the domain's recent items, newest first.
  String? next(
    SelectionCycleDomain domain, {
    required String? current,
    required List<String> candidates,
    required List<String> history,
    bool reverse = false,
  }) {
    final options = candidates.toSet().toList();
    if (options.length < 2) {
      _bursts.remove(domain);
      final only = options.firstOrNull;
      return only == current ? null : only;
    }
    final now = _now();
    final burst = _bursts[domain];
    if (burst != null &&
        burst.reverse == reverse &&
        now.difference(burst.at) <= window &&
        current != null) {
      final order = burst.order.where(options.contains).toList();
      if (order.length >= 2 &&
          burst.index < order.length &&
          order[burst.index] == current) {
        final index = _step(burst.index, order.length, reverse);
        _bursts[domain] = _Burst(order, index, now, reverse);
        return order[index];
      }
    }
    final remembered = history.where(options.contains).toSet().toList();
    final recent = remembered.length >= 2;
    final order = recent
        ? <String>{?current, ...remembered, ...options}.toList()
        : options;
    final at = current == null ? -1 : order.indexOf(current);
    // From the current item, the first press goes to the one used before.
    final index = at == -1
        ? 0
        : recent
        ? (at + 1) % order.length
        : _step(at, order.length, reverse);
    _bursts[domain] = _Burst(order, index, now, reverse);
    return order[index];
  }

  static int _step(int index, int length, bool reverse) =>
      reverse ? (index - 1 + length) % length : (index + 1) % length;
}

final class _Burst {
  const _Burst(this.order, this.index, this.at, this.reverse);
  final List<String> order;
  final int index;
  final DateTime at;
  final bool reverse;
}
