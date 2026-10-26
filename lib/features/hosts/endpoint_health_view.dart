import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../pairing/pairing_controller.dart';
import 'endpoint_health_controller.dart';

String endpointStatusText(V2Localizations l, EndpointStatus status) =>
    switch (status) {
      EndpointStatus.compatible => l.onboardingReady,
      EndpointStatus.untested => l.hostsUntested,
      EndpointStatus.belowMinimum => l.hostsUpgradeRequired,
      EndpointStatus.legacyServer => l.hostsLegacyExplanation,
      EndpointStatus.authenticationRequired => l.hostsAuthRequired,
      EndpointStatus.serviceStarting => l.onboardingStarting,
      EndpointStatus.serviceStopping => l.onboardingStopping,
      EndpointStatus.serviceFailed => l.onboardingFailed,
      EndpointStatus.serviceUnavailable => l.onboardingNotAvailable,
      EndpointStatus.unrecognized => l.onboardingCouldNotVerify,
      EndpointStatus.unreachable => l.hostsTransportHelp,
      EndpointStatus.cancelled => l.commonCancel,
      EndpointStatus.unsupportedPlatform => l.hostsNativeOnly,
    };

String healthStatusText(V2Localizations l, EndpointHealthStatus status) =>
    switch (status) {
      EndpointHealthStatus.online => l.statusOnline,
      EndpointHealthStatus.delayed => l.statusDelayed,
      EndpointHealthStatus.offline => l.statusOffline,
    };

String? endpointHealthReason(V2Localizations l, EndpointHealthView view) =>
    switch (view.credentialFailure) {
      EndpointCredentialFailure.missing => l.healthCredentialMissing,
      EndpointCredentialFailure.unreadable => l.healthCredentialUnreadable,
      EndpointCredentialFailure.expired => l.healthCredentialExpired,
      null =>
        view.status == EndpointHealthStatus.offline
            ? endpointStatusText(l, view.assessment!.status)
            : null,
    };

class EndpointHealthIndicator extends StatelessWidget {
  const EndpointHealthIndicator({required this.view, super.key});
  final EndpointHealthView view;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Icons.circle,
        size: 10,
        color: switch (view.status) {
          EndpointHealthStatus.online => Colors.green,
          EndpointHealthStatus.delayed => Colors.orange,
          EndpointHealthStatus.offline => Theme.of(context).colorScheme.error,
        },
      ),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          healthStatusText(context.v2L10n, view.status),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

/// A confirmed endpoint failure keeps its finite reason and recovery nearby.
class EndpointHealthRecovery extends StatelessWidget {
  const EndpointHealthRecovery({
    required this.profile,
    required this.health,
    super.key,
  });
  final EndpointProfile profile;
  final EndpointHealthController health;

  @override
  Widget build(BuildContext context) {
    final l = context.v2L10n;
    final view = health.view(profile);
    final reason = endpointHealthReason(l, view);
    if (reason == null) return const SizedBox.shrink();
    final pairing = context.read<PairingController?>();
    return Semantics(
      liveRegion: true,
      child: Column(
        key: const ValueKey('endpoint-health-recovery'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(reason),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                key: const ValueKey('endpoint-health-retry'),
                onPressed: health.canRefresh(profile)
                    ? () => health.refresh(profile)
                    : null,
                child: Text(l.chatRetry),
              ),
              TextButton(
                key: const ValueKey('endpoint-health-servers'),
                onPressed: () => context.push('/hosts'),
                child: Text(l.settingsServersTitle),
              ),
              if (pairing != null &&
                  (view.credentialFailure != null ||
                      view.assessment?.status ==
                          EndpointStatus.authenticationRequired))
                TextButton(
                  key: const ValueKey('endpoint-health-pair'),
                  onPressed: () {
                    pairing.empty(profile: profile);
                    context.push('/pair');
                  },
                  child: Text(l.pairingAgain),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
