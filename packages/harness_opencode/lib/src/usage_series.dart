import 'package:codewalk_core/codewalk_core.dart';

import 'session_projection.dart';

const openCodeSessionTotalKey = 'session-total';

/// Projects `GET /api/session/{id}` `cost`/`tokens` into the cumulative
/// `session-total` series when actual usage has been reported.
///
/// Untouched sessions (and in-flight first turns before any step reports usage)
/// carry schema-default zeroes on `Session.Info`; those stay absent so unknown
/// values are never shown as zero.
UsageObservation? openCodeHydratedSessionTotal({
  required Object? record,
  required SessionRef session,
  required Iterable<TimelineItem> timeline,
  required String sourceVersion,
  required DateTime fallbackObservedAt,
}) {
  if (record is! Map<String, Object?>) return null;
  final cost = _optionalNonNegative(record['cost']);
  final tokens = _optionalTokens(record['tokens']);
  if (cost == null && tokens == null) return null;

  final hasNonZeroCost = cost != null && cost > 0;
  final tokenSum = _tokenSum(tokens);
  final hasNonZeroTokens = tokenSum != null && tokenSum > 0;
  final hasReportedStepUsage = timeline.any(
    (item) =>
        item.meta.message?.tokens != null || item.meta.message?.cost != null,
  );
  if (!hasNonZeroCost && !hasNonZeroTokens && !hasReportedStepUsage) {
    return null;
  }

  return UsageObservation(
    id: openCodeSessionTotalKey,
    owner: SessionOwner(session),
    scope: const OpenValue.known(UsageScope.session),
    source: const OpenValue.known(UsageSource.native),
    observedAt: _updatedAt(record) ?? fallbackObservedAt,
    tokens: tokens,
    cost: cost == null
        ? null
        : Cost(amount: cost, currency: 'USD', cumulative: true),
    partial: false,
    cumulative: true,
    aggregationKey: openCodeSessionTotalKey,
    provenance: SourceProvenance(
      harness: session.harnessRef,
      version: sourceVersion,
      nativeType: 'session.get',
    ),
  );
}

/// Parses the `GET /api/session/{id}` envelope into summary, raw revert,
/// selection, and raw record map while verifying session identity.
({
  SessionSummary summary,
  Object? revert,
  Selection selection,
  Map<String, Object?> data,
})
projectOpenCodeSessionEnvelope(
  Object? value,
  HarnessRef harness,
  SessionRef ref,
) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Malformed OpenCode session response.');
  }
  final data = value['data'];
  final summary = projectOpenCodeSession(data, harness);
  if (summary.info.ref != ref) {
    throw const FormatException('Session response has another identity.');
  }
  final map = data! as Map<String, Object?>;
  return (
    summary: summary,
    revert: map['revert'],
    selection: projectOpenCodeSelection(data),
    data: map,
  );
}

num? _optionalNonNegative(Object? value) =>
    value is num && value.isFinite && value >= 0 ? value : null;

num? _tokenSum(TokenBreakdown? tokens) {
  if (tokens == null) return null;
  final values = [
    tokens.input,
    tokens.output,
    tokens.reasoning,
    tokens.cacheRead,
    tokens.cacheWrite,
  ];
  if (values.every((v) => v == null)) return null;
  final sum = values.whereType<num>().fold<double>(0, (s, v) => s + v);
  return sum.isFinite && sum >= 0 ? sum : null;
}

TokenBreakdown? _optionalTokens(Object? value) {
  if (value is! Map<String, Object?>) return null;
  final cache = value['cache'];
  final input = _optionalNonNegative(value['input']);
  final output = _optionalNonNegative(value['output']);
  final reasoning = _optionalNonNegative(value['reasoning']);
  final cacheRead = cache is Map<String, Object?>
      ? _optionalNonNegative(cache['read'])
      : null;
  final cacheWrite = cache is Map<String, Object?>
      ? _optionalNonNegative(cache['write'])
      : null;
  if (input == null &&
      output == null &&
      reasoning == null &&
      cacheRead == null &&
      cacheWrite == null) {
    return null;
  }
  return TokenBreakdown(
    input: input,
    output: output,
    reasoning: reasoning,
    cacheRead: cacheRead,
    cacheWrite: cacheWrite,
  );
}

DateTime? _updatedAt(Map<String, Object?> record) {
  final time = record['time'];
  if (time is! Map<String, Object?>) return null;
  final raw = time['updated'];
  if (raw is! num || !raw.isFinite || raw.abs() > 8640000000000000) return null;
  return DateTime.fromMillisecondsSinceEpoch(raw.floor(), isUtc: true);
}
