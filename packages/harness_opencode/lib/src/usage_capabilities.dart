import 'package:codewalk_core/codewalk_core.dart';

import 'version_policy.dart';

/// OpenCode v2 canonical capabilities for token, cost, context and quota usage.
///
/// Verified only for supported OpenCode v2 server versions. `usage.quota` stays
/// unavailable because OpenCode v2 exposes no remaining-quota API.
Map<String, Capability> openCodeUsageCapabilities(String? connectedVersion) {
  final verified =
      connectedVersion != null &&
      OpenCodeCompatibility.supportsV2(connectedVersion);
  return {
    UsageCapabilities.tokens: Capability(
      support: const OpenValue.known(Support.native),
      verified: verified,
      reason: verified ? null : 'unverifiedVersion',
    ),
    UsageCapabilities.cost: Capability(
      support: const OpenValue.known(Support.native),
      verified: verified,
      reason: verified ? null : 'unverifiedVersion',
    ),
    UsageCapabilities.context: Capability(
      support: const OpenValue.known(Support.native),
      verified: verified,
      reason: verified ? null : 'unverifiedVersion',
      semantics:
          'last completed assistant step after last completed compaction and before revert boundary',
    ),
    UsageCapabilities.quota: Capability(
      support: const OpenValue.known(Support.unavailable),
      verified: verified,
      reason: verified ? 'quotaNotExposed' : 'unverifiedVersion',
    ),
  };
}
