import 'dart:async';

/// Only the new namespace can be mutated by authored v2 storage.
void requireV2Key(String key) {
  if (!key.startsWith('cw2.') || key.length == 4 || key.contains('\u0000')) {
    throw ArgumentError.value(key, 'key', 'Expected a nonempty cw2.* key');
  }
}

/// Serializes mutations and awaited reads for each key, without poisoning the
/// queue after an error. Different keys do not wait for one another.
final class KeySerialExecutor {
  final Map<String, Future<void>> _tails = {};

  Future<T> run<T>(String key, Future<T> Function() operation) {
    final previous = _tails[key] ?? Future<void>.value();
    final result = previous.then((_) => operation());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _tails[key] = tail;
    unawaited(
      tail.then((_) {
        if (identical(_tails[key], tail)) _tails.remove(key);
      }),
    );
    return result;
  }

  /// Callers stop staging new mutations before awaiting this lifecycle boundary.
  Future<void> drain() => Future.wait(_tails.values.toList());
}
