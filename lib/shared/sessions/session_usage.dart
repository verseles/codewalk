import 'package:codewalk_core/codewalk_core.dart';

import 'session_live_source.dart';
import 'session_selection.dart';

/// Optional usage-capability contract on a [SessionLiveHandle].
///
/// Harnesses without usage reporting omit this interface (or return unavailable
/// capabilities) so the UI hides the toolbar control and never fakes metrics.
abstract interface class SessionUsageSource {
  Map<String, Capability> get usageCapabilities;
}

extension SessionLiveUsage on SessionLiveHandle {
  Map<String, Capability> get usageCapabilities {
    final handle = this;
    return handle is SessionUsageSource
        ? (handle as SessionUsageSource).usageCapabilities
        : const {};
  }
}

/// Resolves the canonical [SessionUsageView] for a live session from its
/// canonical [state], [selection], and declared [capabilities].
SessionUsageView resolveLiveSessionUsage({
  required SessionState? state,
  required SessionSelectionState selection,
  required Map<String, Capability> capabilities,
}) => resolveSessionUsage(
  usage: state?.usage ?? const [],
  timeline: state?.timeline ?? const [],
  revert: state?.revert,
  capabilities: capabilities,
  hasMoreHistory: state?.hasMoreHistory ?? false,
  contextLimitForModel: selection.contextLimitForModel,
  fallbackContextLimit: selection.activeModelContextLimit,
);
