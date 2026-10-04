import '../identity.dart';

enum SessionCollection {
  timeline,
  pending,
  interactions,
  work,
  plan,
  usage,
  execution,
  info,
  selection,
  revert,
}

/// Pure descriptions: executing reads or notifications belongs to the caller.
sealed class ReducerEffect {
  const ReducerEffect(this.ref);
  final SessionRef ref;
}

final class Notify extends ReducerEffect {
  const Notify(super.ref);
}

final class Refetch extends ReducerEffect {
  const Refetch(super.ref, this.collection, this.reason);
  final SessionCollection collection;
  final String reason;
}

final class Rehydrate extends ReducerEffect {
  const Rehydrate(super.ref, this.reason);
  final String reason;
}
