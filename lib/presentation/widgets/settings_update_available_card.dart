import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/i18n/l10n_context.dart';
import '../providers/settings_provider.dart';
import '../services/update_check_service.dart';
import 'app_indeterminate_progress.dart';

class SettingsUpdateAvailableCard extends StatelessWidget {
  const SettingsUpdateAvailableCard({
    super.key,
    required this.settings,
    required this.result,
    this.currentVersion,
    this.currentBuildNumber,
    this.showReleaseNotes = false,
    this.isNews = false,
    this.onDismiss,
  });

  final SettingsProvider settings;
  final UpdateCheckResult result;
  final String? currentVersion;
  final String? currentBuildNumber;
  final bool showReleaseNotes;

  /// When true, the card renders the What's-new announcement surface instead
  /// of the update/install surface (no install controls).
  final bool isNews;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onContainer = colorScheme.onPrimaryContainer;
    final notesPreview = showReleaseNotes
        ? stripReleaseAnnouncement(result.releaseNotes)
        : null;
    // The installed-vs-available comparison only makes sense for updates;
    // What's-new cards for up-to-date users omit it.
    final versionSummary = isNews ? null : _versionSummary(context);
    return Card(
      key: ValueKey<String>(
        isNews
            ? 'settings_whats_new_banner'
            : 'settings_update_available_banner',
      ),
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isNews ? Symbols.campaign : Symbols.system_update,
                  color: onContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isNews
                        ? context.l10n.settingsAboutWhatsNew(
                            result.latestVersion,
                          )
                        : context.l10n.settingsAboutUpdateAvailable(
                            result.latestVersion,
                          ),
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: onContainer),
                  ),
                ),
              ],
            ),
            if (versionSummary case final summary?) ...[
              const SizedBox(height: 6),
              Text(
                summary,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: onContainer),
              ),
            ],
            if (result.announcement != null &&
                result.announcement!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(
                    AppConstants.smallBorderRadius,
                  ),
                ),
                child: Text(
                  result.announcement!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
            if (notesPreview != null && notesPreview.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                notesPreview.length > 400
                    ? '${notesPreview.substring(0, 400)}...'
                    : notesPreview,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: onContainer),
              ),
            ],
            const SizedBox(height: 8),
            if (isNews)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed:
                        onDismiss ??
                        () => settings.dismissNews(result.latestVersion),
                    child: Text(context.l10n.settingsAboutDismiss),
                  ),
                ],
              )
            else
              _buildInstallControl(context),
          ],
        ),
      ),
    );
  }

  String? _versionSummary(BuildContext context) {
    final version = currentVersion?.trim();
    if (version == null || version.isEmpty) {
      return null;
    }
    final buildNumber = currentBuildNumber?.trim();
    final installed = buildNumber == null || buildNumber.isEmpty
        ? version
        : context.l10n.settingsAboutVersionBuild(buildNumber, version);
    return context.l10n.settingsAboutUpdateVersionSummary(
      installed,
      result.latestVersion,
    );
  }

  Widget _buildInstallControl(BuildContext context) {
    final installState = settings.installState;
    final color = Theme.of(context).colorScheme.onPrimaryContainer;
    if (installState == UpdateInstallState.downloading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          settings.installProgress > 0
              ? LinearProgressIndicator(value: settings.installProgress)
              : const AppIndeterminateBar(),
          const SizedBox(height: 4),
          Text(
            context.l10n.settingsAboutDownloading(
              (settings.installProgress * 100).toStringAsFixed(0),
            ),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      );
    }

    if (installState == UpdateInstallState.installing) {
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: AppIndeterminateRing(size: 16, strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            context.l10n.settingsAboutInstalling,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      );
    }

    if (installState == UpdateInstallState.done) {
      return Text(
        context.l10n.settingsAboutUpdateInstalled,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (settings.canInstallUpdateDirectly(result))
          FilledButton.icon(
            onPressed: () => unawaited(settings.startInstall()),
            icon: Icon(
              installState == UpdateInstallState.failed
                  ? Symbols.refresh
                  : Symbols.download,
              size: 16,
            ),
            label: Text(
              installState == UpdateInstallState.failed
                  ? context.l10n.settingsAboutRetryInstall
                  : context.l10n.settingsAboutInstallUpdate,
            ),
          )
        else if (result.releaseUrl != null)
          FilledButton.icon(
            onPressed: () => unawaited(_openReleaseUrl(result.releaseUrl!)),
            icon: const Icon(Symbols.open_in_new, size: 16),
            label: Text(context.l10n.aboutGitHub),
          ),
        OutlinedButton(
          onPressed: () => settings.dismissUpdate(result.latestVersion),
          child: Text(context.l10n.settingsAboutDismiss),
        ),
      ],
    );
  }

  Future<void> _openReleaseUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
