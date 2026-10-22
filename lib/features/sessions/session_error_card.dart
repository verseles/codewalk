import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';

/// The one recovery an error card offers: its label and what it opens.
typedef SessionErrorRecovery = ({String label, VoidCallback onPressed});

/// The recovery [error]'s action offers through a surface that already
/// exists, or null when that surface is not available here: the model and
/// agent sheet for [ErrorAction.changeModel], the servers page for
/// [ErrorAction.upgrade]. The other actions have no surface, and none of them
/// replays a turn.
SessionErrorRecovery? sessionErrorRecovery(
  V2Localizations l10n,
  ErrorInfo error, {
  VoidCallback? chooseModel,
  VoidCallback? openServers,
}) {
  final action = error.action?.known;
  if (action == ErrorAction.changeModel && chooseModel != null) {
    return (label: l10n.liveErrorChooseModel, onPressed: chooseModel);
  }
  if (action == ErrorAction.upgrade && openServers != null) {
    return (label: l10n.liveErrorOpenServers, onPressed: openServers);
  }
  return null;
}

/// A failed turn's typed error, shared by the history and live views: its
/// category, the server's message and the one recovery that exists for it.
///
/// The category comes from the canonical [ErrorInfo.kind] alone, never from a
/// harness or its native type; the kinds without a card of their own, and
/// future ones, use the unknown card. The message, already redacted and
/// bounded by the harness, is plain selectable text in a bounded scroll, and
/// an empty one says that nothing was reported, so an unknown error never
/// reads as nothing or as success.
class SessionErrorCard extends StatelessWidget {
  const SessionErrorCard({super.key, required this.error, this.recovery});

  final ErrorInfo error;

  /// The card's one recovery; null when none is available here.
  final SessionErrorRecovery? recovery;

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (title, detail, icon) = _category(l10n, error.kind.known);
    final details = error.details?.value;
    final shortened = details is Map && details['messageTruncated'] == true;
    final message = error.rawMessage;
    final text = theme.textTheme;
    final on = scheme.onErrorContainer;
    final recovery = this.recovery;
    return Card(
      key: const ValueKey('live-error-card'),
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: on),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: text.titleSmall?.copyWith(color: on),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(detail, style: text.bodyMedium?.copyWith(color: on)),
            const SizedBox(height: 8),
            if (message.isEmpty)
              Text(
                l10n.liveErrorNoDetails,
                key: const ValueKey('live-error-no-details'),
                style: text.bodySmall?.copyWith(color: on),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: min(240, MediaQuery.sizeOf(context).height * 0.4),
                ),
                child: SingleChildScrollView(
                  key: const ValueKey('live-error-message'),
                  child: SelectableText(
                    message,
                    style: text.bodySmall?.copyWith(color: on),
                  ),
                ),
              ),
            if (shortened) ...[
              const SizedBox(height: 4),
              Text(
                l10n.liveErrorShortened,
                style: text.bodySmall?.copyWith(color: on),
              ),
            ],
            if (recovery != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.tonal(
                  key: const ValueKey('live-error-action'),
                  onPressed: recovery.onPressed,
                  child: Text(recovery.label, textAlign: TextAlign.center),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

(String, String, IconData) _category(V2Localizations l10n, ErrorKind? kind) =>
    switch (kind) {
      ErrorKind.auth => (
        l10n.liveErrorAuth,
        l10n.liveErrorAuthDetail,
        Icons.lock_outline,
      ),
      ErrorKind.rateLimit => (
        l10n.liveErrorRateLimit,
        l10n.liveErrorRateLimitDetail,
        Icons.hourglass_empty,
      ),
      ErrorKind.quota => (
        l10n.liveErrorQuota,
        l10n.liveErrorQuotaDetail,
        Icons.data_usage,
      ),
      ErrorKind.contextOverflow => (
        l10n.liveErrorContext,
        l10n.liveErrorContextDetail,
        Icons.unfold_less,
      ),
      ErrorKind.provider => (
        l10n.liveErrorProvider,
        l10n.liveErrorProviderDetail,
        Icons.error_outline,
      ),
      ErrorKind.network => (
        l10n.liveErrorNetwork,
        l10n.liveErrorNetworkDetail,
        Icons.cloud_off_outlined,
      ),
      ErrorKind.contentFilter => (
        l10n.liveErrorContentFilter,
        l10n.liveErrorContentFilterDetail,
        Icons.block,
      ),
      ErrorKind.versionUnsupported => (
        l10n.liveErrorVersion,
        l10n.liveErrorVersionDetail,
        Icons.system_update_alt,
      ),
      ErrorKind.permissionRejected ||
      ErrorKind.toolFailure ||
      ErrorKind.protocol ||
      ErrorKind.unknown ||
      null => (
        l10n.liveErrorUnknown,
        l10n.liveErrorUnknownDetail,
        Icons.help_outline,
      ),
    };
