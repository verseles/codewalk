import 'package:codewalk_core/codewalk_core.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';

String endpointStatusText(V2Localizations l, EndpointStatus status) =>
    switch (status) {
      EndpointStatus.compatible => l.onboardingReady,
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

const legacyDownloadUrl =
    'https://github.com/verseles/codewalk/releases/tag/v1.265.1';

class EndpointStatusView extends StatelessWidget {
  const EndpointStatusView({
    super.key,
    required this.assessment,
    this.showVersion = true,
  });
  final EndpointAssessment assessment;

  /// The add flow never shows the server version (#504).
  final bool showVersion;
  @override
  Widget build(BuildContext context) {
    final l = context.v2L10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Chip(
            label: Text(
              '${endpointStatusText(l, assessment.status)}${!showVersion || assessment.version == null ? '' : ' · ${assessment.version}'}',
            ),
          ),
          if (assessment.status == EndpointStatus.belowMinimum)
            Text(l.hostsUpgradeInstructions),
          if (assessment.retryDeferred || assessment.retryAt != null) ...[
            Text(l.hostsRetryLater),
            if (assessment.retryAt != null)
              Text(assessment.retryAt!.toLocal().toString()),
          ],
        ],
      ),
    );
  }
}

class LegacyEndpointPage extends StatefulWidget {
  const LegacyEndpointPage({super.key});
  @override
  State<LegacyEndpointPage> createState() => _LegacyEndpointPageState();
}

class _LegacyEndpointPageState extends State<LegacyEndpointPage> {
  bool _instructions = false;
  Future<void> _download() async {
    try {
      await launchUrl(
        Uri.parse(legacyDownloadUrl),
        mode: LaunchMode.externalApplication,
      );
    } on Object {
      // The selectable URL remains available when no external app opens it.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.v2L10n;
    return Scaffold(
      appBar: AppBar(title: const Text('OpenCode 1')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                l.hostsLegacyExplanation,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => setState(() {
                  _instructions = !_instructions;
                }),
                child: Text(l.hostsUpgradeRequired),
              ),
              if (_instructions)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: SelectableText(l.hostsUpgradeInstructions),
                ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const ValueKey('legacy-download'),
                onPressed: _download,
                child: Text(l.hostsLegacyDownload),
              ),
              const SelectableText(legacyDownloadUrl),
            ],
          ),
        ),
      ),
    );
  }
}
