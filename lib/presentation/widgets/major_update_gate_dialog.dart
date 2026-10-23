import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/l10n_context.dart';
import '../providers/settings_provider.dart';

enum MajorUpdateGateChoice { update, stay, later }

/// Explains a CodeWalk major update and asks the user to update, stay on the
/// current major or decide later. Back/Escape count as "later".
class MajorUpdateGateDialog extends StatelessWidget {
  const MajorUpdateGateDialog({
    super.key,
    required this.version,
    required this.onUpdate,
    required this.onStay,
    required this.onLater,
    this.onOpenReleaseNotes,
    this.showAndroidReplacementNote = false,
  });

  final String version;
  final VoidCallback onUpdate;
  final VoidCallback onStay;
  final VoidCallback onLater;

  /// Opens the candidate's release page; the link is hidden when null.
  final VoidCallback? onOpenReleaseNotes;
  final bool showAndroidReplacementNote;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final changes = <String>[
      l10n.majorUpdateGateChangeServers,
      l10n.majorUpdateGateChangeFeatures,
      l10n.majorUpdateGateChangeLater,
      l10n.majorUpdateGateChangeArchive,
    ];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onLater();
      },
      // The route ignores Escape when the barrier is not dismissible, so the
      // dialog maps it to Later itself.
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): onLater,
        },
        child: Focus(
          autofocus: true,
          child: AlertDialog(
            key: const ValueKey<String>('major_update_gate_dialog'),
            scrollable: true,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            icon: const Icon(Symbols.system_update),
            title: Text(l10n.majorUpdateGateTitle(version)),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.majorUpdateGateRequirement,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.majorUpdateGateChangesTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  for (final change in changes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•'),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              change,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (showAndroidReplacementNote) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.majorUpdateGateAndroidNote,
                      key: const ValueKey<String>(
                        'major_update_gate_android_note',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (onOpenReleaseNotes case final openNotes?) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        key: const ValueKey<String>(
                          'major_update_gate_release_notes',
                        ),
                        onPressed: openNotes,
                        icon: const Icon(Symbols.open_in_new, size: 16),
                        label: Text(l10n.majorUpdateGateReleaseNotes),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Stacked full-width actions never overflow at narrow widths or
                  // large text scales; long labels wrap instead.
                  FilledButton(
                    key: const ValueKey<String>('major_update_gate_update'),
                    onPressed: onUpdate,
                    child: Text(
                      l10n.majorUpdateGateUpdate,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const ValueKey<String>('major_update_gate_stay'),
                    onPressed: onStay,
                    child: Text(
                      l10n.majorUpdateGateStay,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const ValueKey<String>('major_update_gate_later'),
                    onPressed: onLater,
                    child: Text(
                      l10n.majorUpdateGateLater,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the gate for the provider's current major candidate and applies the
/// chosen action. Does nothing when no candidate is pending.
Future<void> showMajorUpdateGate(
  BuildContext context,
  SettingsProvider settings,
) async {
  final candidate = settings.majorUpdateCandidate;
  if (candidate == null) {
    return;
  }
  settings.acknowledgeStartupMajorUpdateGate();
  final releaseUrl = candidate.releaseUrl;
  final releaseUri = releaseUrl == null ? null : Uri.tryParse(releaseUrl);
  final choice = await showDialog<MajorUpdateGateChoice>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      void close(MajorUpdateGateChoice choice) =>
          Navigator.of(dialogContext).pop(choice);
      return MajorUpdateGateDialog(
        version: candidate.latestVersion,
        showAndroidReplacementNote:
            !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
        onOpenReleaseNotes: releaseUri == null
            ? null
            : () => unawaited(
                launchUrl(releaseUri, mode: LaunchMode.externalApplication),
              ),
        onUpdate: () => close(MajorUpdateGateChoice.update),
        onStay: () => close(MajorUpdateGateChoice.stay),
        onLater: () => close(MajorUpdateGateChoice.later),
      );
    },
  );
  switch (choice) {
    case MajorUpdateGateChoice.update:
      // Installation progress is reported through the install state; do not
      // hold the caller (e.g. the startup dialog sequence) for the download.
      unawaited(settings.approveMajorUpdate(candidate));
    case MajorUpdateGateChoice.stay:
      await settings.stayOnCodeWalk1();
    case MajorUpdateGateChoice.later:
      await settings.remindMajorUpdateLater();
    case null:
      break;
  }
}
