import 'package:codewalk_core/codewalk_core.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/theme/app_surface_tokens.dart';
import '../pairing/pairing_controller.dart';
import 'add_server_panel.dart';
import 'endpoint_health_controller.dart';
import 'endpoint_status_view.dart';

String healthStatusText(V2Localizations l, EndpointHealthStatus status) =>
    switch (status) {
      EndpointHealthStatus.checking => l.statusChecking,
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

Color healthStatusColor(BuildContext context, EndpointHealthStatus status) {
  final tokens = Theme.of(context).surfaceTokens;
  return switch (status) {
    EndpointHealthStatus.checking => tokens.statusChecking,
    EndpointHealthStatus.online => tokens.statusOnline,
    EndpointHealthStatus.delayed => tokens.statusDelayed,
    EndpointHealthStatus.offline => tokens.statusOffline,
  };
}

class EndpointHealthIndicator extends StatelessWidget {
  const EndpointHealthIndicator({
    required this.view,
    this.detail,
    this.maxLines = 1,
    super.key,
  });
  final EndpointHealthView view;

  /// Shown after the status, such as the harness and its version.
  final String? detail;

  /// Null lets the line wrap as far as it needs.
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Symbols.circle,
        size: 10,
        color: healthStatusColor(context, view.status),
      ),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          [healthStatusText(context.v2L10n, view.status), ?detail].join(' · '),
          maxLines: maxLines,
          // An ellipsis without a line limit would cut the text to one line.
          overflow: maxLines == null
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
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
      container: true,
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
                  onPressed: () => showAddServer(
                    context,
                    prepare: (pairing) => pairing.empty(profile: profile),
                  ),
                  child: Text(l.pairingAgain),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
