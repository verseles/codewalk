import 'identity.dart';
import 'values.dart';

enum UsageScope { turn, session, sessionTree, account, model, unknown }

enum UsageSource { native, hostConnector, estimate, unknown }

enum ContextMeasurement { measured, estimated, unknown }

/// Missing components stay absent; there is no inferred total or default zero.
final class TokenBreakdown {
  TokenBreakdown({
    this.input,
    this.output,
    this.reasoning,
    this.cacheRead,
    this.cacheWrite,
  }) {
    _nonNegative(input, 'input');
    _nonNegative(output, 'output');
    _nonNegative(reasoning, 'reasoning');
    _nonNegative(cacheRead, 'cacheRead');
    _nonNegative(cacheWrite, 'cacheWrite');
  }

  final num? input;
  final num? output;
  final num? reasoning;
  final num? cacheRead;
  final num? cacheWrite;
}

/// Currency and amount are observations, not values inferred from a model.
/// Cumulative costs replace a matching series; they must never be summed.
final class Cost {
  Cost({
    this.amount,
    this.currency,
    this.estimated = false,
    this.partial = false,
    this.cumulative = false,
  }) {
    _nonNegative(amount, 'amount');
    _optionalNonempty(currency, 'currency');
  }

  final num? amount;
  final String? currency;
  final bool estimated;
  final bool partial;
  final bool cumulative;
}

final class ContextMeter {
  ContextMeter({this.used, this.limit, required this.measurement}) {
    _nonNegative(used, 'used');
    _nonNegative(limit, 'limit');
  }

  final num? used;
  final num? limit;
  final OpenValue<ContextMeasurement> measurement;
}

/// Native windows may report more than 100 percent and omit their reset time.
final class QuotaWindow {
  QuotaWindow({
    required this.id,
    required this.label,
    required this.source,
    this.usedPercent,
    this.resetsAt,
  }) {
    _nonempty(id, 'id');
    _nonNegative(usedPercent, 'usedPercent');
  }

  final String id;
  final String label;
  final num? usedPercent;
  final DateTime? resetsAt;
  final OpenValue<UsageSource> source;
}

/// A duplicate identity is distinct from a cumulative-series identity.
/// Neither identity authorizes adding observations or establishes freshness.
final class UsageObservationKey {
  const UsageObservationKey._({
    required this.owner,
    required this.scope,
    required this.source,
    required this.harness,
    required this.id,
    this.sourceVersion,
  });

  final DomainOwner owner;
  final OpenValue<UsageScope> scope;
  final OpenValue<UsageSource> source;
  final HarnessRef harness;
  final String id;
  final String? sourceVersion;

  @override
  bool operator ==(Object other) =>
      other is UsageObservationKey &&
      owner.hasSameScope(other.owner) &&
      scope == other.scope &&
      source == other.source &&
      harness == other.harness &&
      id == other.id &&
      sourceVersion == other.sourceVersion;

  @override
  int get hashCode =>
      Object.hash(owner.scopeKey, scope, source, harness, id, sourceVersion);
}

/// Matching cumulative observations can replace/reconcile the same series.
/// Partial snapshots require their source contract; this is not a summation API.
final class UsageAggregationIdentity {
  const UsageAggregationIdentity._({
    required this.owner,
    required this.scope,
    required this.source,
    required this.harness,
    required this.key,
    this.sourceVersion,
  });

  final DomainOwner owner;
  final OpenValue<UsageScope> scope;
  final OpenValue<UsageSource> source;
  final HarnessRef harness;
  final String key;
  final String? sourceVersion;

  @override
  bool operator ==(Object other) =>
      other is UsageAggregationIdentity &&
      owner.hasSameScope(other.owner) &&
      scope == other.scope &&
      source == other.source &&
      harness == other.harness &&
      key == other.key &&
      sourceVersion == other.sourceVersion;

  @override
  int get hashCode =>
      Object.hash(owner.scopeKey, scope, source, harness, key, sourceVersion);
}

/// Source values and their aggregation semantics remain explicit and nullable.
///
/// An observation may overlap a turn, its session and an account observation;
/// distinct scopes/sources are not disjoint budgets. A cumulative observation
/// (including a cumulative [cost]) must not be summed with earlier readings.
final class UsageObservation {
  UsageObservation({
    required this.id,
    required this.owner,
    required this.scope,
    required this.source,
    required this.observedAt,
    this.tokens,
    this.cost,
    this.context,
    Iterable<QuotaWindow> quotas = const [],
    this.partial = false,
    this.cumulative = false,
    this.aggregationKey,
    this.provenance,
  }) : quotas = immutableList(quotas) {
    _nonempty(id, 'id');
    _optionalNonempty(aggregationKey, 'aggregationKey');
  }

  final String id;
  final DomainOwner owner;
  final OpenValue<UsageScope> scope;
  final OpenValue<UsageSource> source;
  final DateTime observedAt;
  final TokenBreakdown? tokens;
  final Cost? cost;
  final ContextMeter? context;
  final List<QuotaWindow> quotas;
  final bool partial;
  final bool cumulative;
  final String? aggregationKey;
  final SourceProvenance? provenance;

  /// A caller-supplied clock/policy; reset metadata is not an observation time.
  bool isFreshAt(DateTime now, {required Duration maxAge}) {
    if (maxAge.isNegative) {
      throw ArgumentError.value(maxAge, 'maxAge', 'Must not be negative');
    }
    return !now.isBefore(observedAt) && now.difference(observedAt) <= maxAge;
  }

  /// Unknown scope/source/ownership cannot establish a safe merge identity.
  UsageObservationKey? get observationKey {
    final harness = _identifiedHarness;
    if (!_hasKnownScopeAndSource || harness == null) return null;
    return UsageObservationKey._(
      owner: owner,
      scope: scope,
      source: source,
      harness: harness,
      id: id,
      sourceVersion: provenance?.version,
    );
  }

  UsageAggregationIdentity? get aggregationIdentity {
    final key = aggregationKey;
    final harness = _identifiedHarness;
    if (key == null || !_hasKnownScopeAndSource || harness == null) return null;
    return UsageAggregationIdentity._(
      owner: owner,
      scope: scope,
      source: source,
      harness: harness,
      key: key,
      sourceVersion: provenance?.version,
    );
  }

  bool get _hasKnownScopeAndSource =>
      scope.known != null &&
      scope.known != UsageScope.unknown &&
      source.known != null &&
      source.known != UsageSource.unknown;

  HarnessRef? get _identifiedHarness {
    if (!owner.isKnown) return null;
    final fromOwner = owner.harness;
    final supplied = provenance?.harness;
    // Conflicting evidence is retained for diagnosis, never used for merging.
    if (fromOwner != null && supplied != null && fromOwner != supplied) {
      return null;
    }
    return fromOwner;
  }
}

void _nonNegative(num? value, String field) {
  if (value != null && (!value.isFinite || value < 0)) {
    throw ArgumentError.value(value, field, 'Must be finite and nonnegative');
  }
}

void _nonempty(String value, String field) {
  if (value.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty');
  }
}

void _optionalNonempty(String? value, String field) {
  if (value != null) _nonempty(value, field);
}
