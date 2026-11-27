import 'package:codewalk_core/codewalk_core.dart';

/// The harnesses this build offers when adding a server (#504). Concrete
/// harness keys live here, at the platform seam, never in features.
HarnessOptions createConnectOptions() => HarnessOptions(const [
  HarnessOption(
    kind: 'opencode',
    displayName: 'OpenCode',
    availability: HarnessAvailability.available,
    methods: {
      HarnessConnectMethod.pairingLink,
      HarnessConnectMethod.manualPassword,
    },
  ),
  HarnessOption(
    kind: 'codex',
    displayName: 'Codex',
    availability: HarnessAvailability.comingSoon,
  ),
], defaultKind: 'opencode');
