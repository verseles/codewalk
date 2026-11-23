import 'package:codewalk_core/codewalk_core.dart';

import 'session_live_source.dart';

/// Optional plan-capability contract on a [SessionLiveHandle].
///
/// Harnesses advertise structured-plan support through [PlanCapabilities].
/// Widgets still render any canonical [PlanSnapshot] delivered in session
/// state; callers that need to distinguish unsupported plans from an empty
/// plan read [planCapabilities].
abstract interface class SessionPlanSource {
  Map<String, Capability> get planCapabilities;
}

extension SessionLivePlan on SessionLiveHandle {
  Map<String, Capability> get planCapabilities {
    final handle = this;
    return handle is SessionPlanSource
        ? (handle as SessionPlanSource).planCapabilities
        : const {};
  }
}
