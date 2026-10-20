import 'package:codewalk_core/codewalk_core.dart';

import '../../shared/l10n/generated/v2_localizations.dart';

/// How long a proven ownership stays displayable.
const sessionOwnershipProofMaxAge = Duration(minutes: 5);

/// The ownership a row may show.
///
/// A row shows only the ownership its adapter proved. An unproven, stale or
/// expired proof, and a list that is not the endpoint's current answer, show
/// [OwnershipKind.unknown]. No topology is inferred: the endpoint URI, the
/// port and the profile label are not evidence.
OwnershipKind displayedSessionOwnership(
  OwnershipInfo ownership, {
  required DateTime now,
  required bool current,
  Duration maxAge = sessionOwnershipProofMaxAge,
}) {
  if (!current) return OwnershipKind.unknown;
  // A proof without a source names no observation, so it proves nothing.
  final proof = ownership.proof;
  if (proof == null || proof.source.isEmpty) return OwnershipKind.unknown;
  return ownership.effectiveKindAt(now, maxAge: maxAge);
}

/// The delay until the label of a row can change.
///
/// The proof leaves its freshness window, it expires, or it becomes usable.
/// The delay is bounded: a deadline far away would exceed the timer a
/// platform can hold, so the caller re-arms it in steps. It is null when the
/// label can no longer change.
Duration? ownershipLabelDelay(
  OwnershipInfo ownership, {
  required DateTime now,
  Duration maxAge = sessionOwnershipProofMaxAge,
}) {
  final proof = ownership.proof;
  // A proof without a source proves nothing, so its label never changes.
  if (proof == null || proof.source.isEmpty) return null;
  final start = proof.observedAt;
  if (now.isBefore(start)) {
    final until = start.difference(now);
    if (until <= Duration.zero) return null;
    return until > maxAge ? maxAge : until;
  }
  final expiresAt = proof.expiresAt;
  if (expiresAt != null && !now.isBefore(expiresAt)) return null;
  // The proof stays fresh while its age is at most the window, so it goes
  // stale one tick later.
  var delay =
      start.add(maxAge).difference(now) + const Duration(microseconds: 1);
  if (expiresAt != null) {
    final expiry = expiresAt.difference(now);
    if (expiry < delay) delay = expiry;
  }
  // A deadline that has already passed needs no wake-up: the label changed
  // with it, and a zero delay would re-arm the timer forever.
  return delay > Duration.zero ? delay : null;
}

/// The label of one ownership kind.
///
/// The vocabulary is the plan's: live shared, owned by this host, saved
/// history, running elsewhere and ownership unknown. The mapping is
/// exhaustive, so a new kind fails the analyzer instead of silently falling
/// back to a wrong label.
String sessionOwnershipLabel(V2Localizations l10n, OwnershipKind kind) =>
    switch (kind) {
      OwnershipKind.liveShared => l10n.sessionsOwnershipLiveShared,
      OwnershipKind.hostOwned => l10n.sessionsOwnershipHostOwned,
      OwnershipKind.savedHistory => l10n.sessionsOwnershipSavedHistory,
      OwnershipKind.runningElsewhere => l10n.sessionsOwnershipRunningElsewhere,
      OwnershipKind.unknown => l10n.sessionsOwnershipUnknown,
    };
