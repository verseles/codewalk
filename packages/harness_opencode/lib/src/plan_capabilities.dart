import 'package:codewalk_core/codewalk_core.dart';

import 'version_policy.dart';

/// OpenCode v2 canonical capability for observing structured session plans.
///
/// Advertised as native for supported OpenCode v2 server versions without
/// querying `GET /api/config` (`experimental.todo`), so both config-enabled
/// and `OPENCODE_FLAGS=todo` servers work uniformly.
Map<String, Capability> openCodePlanCapabilities(String? connectedVersion) {
  final verified =
      connectedVersion != null &&
      OpenCodeCompatibility.supportsV2(connectedVersion);
  return {
    PlanCapabilities.observe: Capability(
      support: const OpenValue.known(Support.native),
      verified: verified,
      reason: verified ? null : 'unverifiedVersion',
      semantics:
          'derived from completed structured plan writes; not gated on experimental.todo',
    ),
  };
}
