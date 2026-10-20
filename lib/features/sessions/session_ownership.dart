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
  return ownership.effectiveKindAt(now, maxAge: maxAge);
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
