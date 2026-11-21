import 'capabilities.dart';
import 'lifecycle.dart';
import 'timeline.dart';
import 'usage.dart';
import 'values.dart';

/// Harness-neutral view of a session's context occupancy, tokens, cost and quota.
///
/// Unknown values remain `null` and are never replaced with zero.
final class SessionUsageView {
  SessionUsageView({
    required this.supportsContext,
    required this.supportsTokens,
    required this.supportsCost,
    required this.supportsQuota,
    this.quotaUnavailableReason,
    this.contextUsed,
    this.contextLimit,
    this.usagePercent,
    this.contextMeasurement = const OpenValue.known(ContextMeasurement.unknown),
    this.contextModelId,
    this.contextModelProviderId,
    this.contextTokens,
    this.cost,
    Iterable<QuotaWindow> quotas = const [],
  }) : quotas = immutableList(quotas);

  final bool supportsContext;
  final bool supportsTokens;
  final bool supportsCost;
  final bool supportsQuota;
  final String? quotaUnavailableReason;

  /// Active context-window occupancy (tokens of the latest active step).
  final num? contextUsed;

  /// Active model context limit (positive token count, else null).
  final num? contextLimit;

  /// Rounded percentage `(contextUsed / contextLimit * 100).round()` when both
  /// are known and `contextLimit > 0`. May exceed 100.
  final int? usagePercent;

  final OpenValue<ContextMeasurement> contextMeasurement;
  final String? contextModelId;
  final String? contextModelProviderId;

  /// Token breakdown of the active context step when `usage.tokens` is available.
  final TokenBreakdown? contextTokens;

  /// Authoritative session cost when `usage.cost` is available and known.
  final Cost? cost;

  /// Native quota windows when `usage.quota` is available.
  final List<QuotaWindow> quotas;

  bool get supportsAny =>
      supportsContext || supportsTokens || supportsCost || supportsQuota;

  bool get contextEstimated =>
      contextMeasurement.known == ContextMeasurement.estimated;
}

/// Resolves canonical [usage] observations, [timeline], [revert], declared
/// [capabilities], and model limits into one harness-neutral [SessionUsageView].
///
/// Context occupancy prefers an explicit [ContextMeter] observation when the
/// harness supplies one, and otherwise selects the latest assistant step with
/// complete tokens strictly after the last completed compaction and strictly
/// before any staged revert boundary.
///
/// Cost never adds cumulative session totals to earlier/equal per-step rows,
/// never invents zeroes for unknown values, and refuses a resident-only sum
/// when [hasMoreHistory] is true and no cumulative session total is present.
SessionUsageView resolveSessionUsage({
  required Iterable<UsageObservation> usage,
  required Map<String, Capability> capabilities,
  required bool hasMoreHistory,
  Iterable<TimelineItem> timeline = const [],
  RevertState? revert,
  int? Function(String modelId, String? providerId)? contextLimitForModel,
  int? fallbackContextLimit,
}) {
  final supportsContext =
      capabilities[UsageCapabilities.context]?.isAvailable ?? false;
  final supportsTokens =
      capabilities[UsageCapabilities.tokens]?.isAvailable ?? false;
  final supportsCost =
      capabilities[UsageCapabilities.cost]?.isAvailable ?? false;
  final supportsQuota =
      capabilities[UsageCapabilities.quota]?.isAvailable ?? false;
  final quotaReason = supportsQuota
      ? null
      : capabilities[UsageCapabilities.quota]?.reason;

  final list = usage.toList(growable: false);
  final stagedCut = revert?.kind.known == RevertKind.staged
      ? revert?.anchor
      : null;
  final visibleTimeline = <TimelineItem>[
    for (final item in timeline)
      if (stagedCut == null ||
          (item.meta.anchor != null &&
              item.meta.anchor!.compareTo(stagedCut) < 0))
        item,
  ];

  // --- Context occupancy ---
  num? contextUsed;
  num? contextLimit;
  int? usagePercent;
  var contextMeasurement = const OpenValue.known(ContextMeasurement.unknown);
  String? contextModelId;
  String? contextModelProviderId;
  TokenBreakdown? contextTokens;

  if (supportsContext) {
    final meterObs = _newestMatching(list, (o) => o.context != null);
    if (meterObs != null) {
      final meter = meterObs.context!;
      if (meter.measurement.known != ContextMeasurement.unknown &&
          meter.used != null) {
        contextUsed = meter.used;
        contextMeasurement = meter.measurement;
        contextModelId = meter.modelId;
        contextModelProviderId = meter.modelProviderId;
        contextTokens = supportsTokens ? meterObs.tokens : null;

        final declaredLimit = meter.limit;
        if (declaredLimit != null && declaredLimit > 0) {
          contextLimit = declaredLimit;
        } else if (meter.modelId != null && contextLimitForModel != null) {
          final lookedUp = contextLimitForModel(
            meter.modelId!,
            meter.modelProviderId,
          );
          if (lookedUp != null && lookedUp > 0) {
            contextLimit = lookedUp;
          }
        }
      }
    } else {
      // Canonical last-assistant-with-usage rule: after last completed
      // compaction and strictly before any staged revert boundary.
      final latest = _lastAssistantWithCompleteTokens(visibleTimeline);
      if (latest != null) {
        final total = _completeTokenTotal(latest.tokens);
        if (total != null) {
          contextUsed = total;
          contextMeasurement = const OpenValue.known(
            ContextMeasurement.measured,
          );
          contextModelId = latest.modelId;
          contextModelProviderId = latest.modelProviderId;
          contextTokens = supportsTokens ? latest.tokens : null;
          if (latest.modelId != null && contextLimitForModel != null) {
            final lookedUp = contextLimitForModel(
              latest.modelId!,
              latest.modelProviderId,
            );
            if (lookedUp != null && lookedUp > 0) {
              contextLimit = lookedUp;
            }
          }
        }
      }
    }

    if (contextUsed != null && contextLimit != null && contextLimit > 0) {
      final ratio = (contextUsed / contextLimit) * 100;
      if (ratio.isFinite && ratio >= 0) {
        usagePercent = ratio.round();
      }
    } else if (contextUsed == null &&
        fallbackContextLimit != null &&
        fallbackContextLimit > 0) {
      // Unknown occupancy: surface the active model's limit for reference
      // while keeping usagePercent and contextUsed unknown (null).
      contextLimit = fallbackContextLimit;
    }
  }

  // --- Session cost (sum every step once; never mix cumulative + earlier steps) ---
  Cost? resolvedCost;
  if (supportsCost) {
    final cumulativeObs = _newestMatching(
      list,
      (o) =>
          o.cumulative &&
          !o.partial &&
          o.context == null &&
          o.cost?.amount != null,
    );

    if (cumulativeObs != null) {
      final base = cumulativeObs.cost!;
      var total = base.amount!.toDouble();
      var currency = base.currency;
      var estimated = base.estimated;
      final partial = base.partial;

      // Include strictly-later completed steps that arrived after the last
      // ephemeral cumulative session total, deduplicated by step identity.
      final laterSteps = _dedupeSteps(
        list.where(
          (o) =>
              !o.cumulative &&
              o.context == null &&
              o.scope.known == UsageScope.turn &&
              o.cost?.amount != null &&
              o.observedAt.isAfter(cumulativeObs.observedAt),
        ),
      );
      for (final step in laterSteps) {
        final stepCost = step.cost!;
        if (currency != null &&
            stepCost.currency != null &&
            currency != stepCost.currency) {
          currency = null;
        }
        total += stepCost.amount!.toDouble();
        estimated = estimated || stepCost.estimated;
      }
      if (total.isFinite && total >= 0) {
        resolvedCost = Cost(
          amount: total,
          currency: currency,
          estimated: estimated,
          partial: partial,
          cumulative: true,
        );
      }
    } else if (!hasMoreHistory) {
      final stepCosts = <Object, Cost>{};
      for (final item in visibleTimeline) {
        final msg = item.meta.message;
        final cost = msg?.cost;
        if (msg != null && cost?.amount != null) {
          stepCosts['step:${msg.message.value}'] = cost!;
        }
      }
      for (final step in _dedupeSteps(
        list.where(
          (o) =>
              !o.cumulative &&
              o.context == null &&
              o.scope.known == UsageScope.turn &&
              o.cost?.amount != null,
        ),
      )) {
        final key = step.aggregationKey ?? step.id;
        stepCosts[key] = step.cost!;
      }
      if (stepCosts.isNotEmpty) {
        var total = 0.0;
        var estimated = false;
        String? currency;
        var currencySet = false;
        var currencyMismatch = false;
        for (final stepCost in stepCosts.values) {
          total += stepCost.amount!.toDouble();
          estimated = estimated || stepCost.estimated;
          if (!currencySet) {
            currency = stepCost.currency;
            currencySet = true;
          } else if (currency != stepCost.currency) {
            currencyMismatch = true;
          }
        }
        if (total.isFinite && total >= 0) {
          resolvedCost = Cost(
            amount: total,
            currency: currencyMismatch ? null : currency,
            estimated: estimated,
            partial: false,
            cumulative: true,
          );
        }
      }
    }
  }

  // --- Quota windows ---
  var quotas = const <QuotaWindow>[];
  if (supportsQuota) {
    final quotaObs = _newestMatching(list, (o) => o.quotas.isNotEmpty);
    if (quotaObs != null) quotas = quotaObs.quotas;
  }

  return SessionUsageView(
    supportsContext: supportsContext,
    supportsTokens: supportsTokens,
    supportsCost: supportsCost,
    supportsQuota: supportsQuota,
    quotaUnavailableReason: quotaReason,
    contextUsed: contextUsed,
    contextLimit: contextLimit,
    usagePercent: usagePercent,
    contextMeasurement: contextMeasurement,
    contextModelId: contextModelId,
    contextModelProviderId: contextModelProviderId,
    contextTokens: contextTokens,
    cost: resolvedCost,
    quotas: quotas,
  );
}

MessageContext? _lastAssistantWithCompleteTokens(List<TimelineItem> visible) {
  var compactionIndex = -1;
  for (var i = visible.length - 1; i >= 0; i--) {
    final item = visible[i];
    if (item is Notice &&
        item.kind.known == NoticeKind.compaction &&
        item.status.known == ItemStatus.completed) {
      compactionIndex = i;
      break;
    }
  }
  for (var i = visible.length - 1; i > compactionIndex; i--) {
    final msg = visible[i].meta.message;
    if (msg != null && _completeTokenTotal(msg.tokens) != null) {
      return msg;
    }
  }
  return null;
}

num? _completeTokenTotal(TokenBreakdown? tokens) {
  if (tokens == null) return null;
  final input = tokens.input;
  final output = tokens.output;
  final reasoning = tokens.reasoning;
  final cacheRead = tokens.cacheRead;
  final cacheWrite = tokens.cacheWrite;
  if (input == null ||
      output == null ||
      reasoning == null ||
      cacheRead == null ||
      cacheWrite == null) {
    return null;
  }
  final total =
      input.toDouble() +
      output.toDouble() +
      reasoning.toDouble() +
      cacheRead.toDouble() +
      cacheWrite.toDouble();
  return total.isFinite && total >= 0 ? total : null;
}

UsageObservation? _newestMatching(
  List<UsageObservation> list,
  bool Function(UsageObservation) predicate,
) {
  UsageObservation? best;
  for (final item in list) {
    if (!predicate(item)) continue;
    if (best == null || !item.observedAt.isBefore(best.observedAt)) {
      best = item;
    }
  }
  return best;
}

List<UsageObservation> _dedupeSteps(Iterable<UsageObservation> steps) {
  final byKey = <Object, UsageObservation>{};
  for (final step in steps) {
    final key = step.aggregationIdentity ?? step.aggregationKey ?? step.id;
    final previous = byKey[key];
    if (previous == null || !step.observedAt.isBefore(previous.observedAt)) {
      byKey[key] = step;
    }
  }
  return byKey.values.toList(growable: false);
}
