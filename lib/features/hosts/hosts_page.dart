import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import 'hosts_controller.dart';

const legacyDownloadUrl =
    'https://github.com/verseles/codewalk/releases/tag/v1.265.1';

class HostsPage extends StatefulWidget {
  const HostsPage({super.key});
  @override
  State<HostsPage> createState() => _HostsPageState();
}

class _HostsPageState extends State<HostsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HostsController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.v2L10n;
    final hosts = context.watch<HostsController>();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Text(
                  l.settingsServersTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                FilledButton.icon(
                  key: const ValueKey('add-endpoint'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _ProfileDialog(hosts: hosts),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(l.serversAddServer),
                ),
              ],
            ),
            if (hosts.loading) const LinearProgressIndicator(),
            if (hosts.storageError)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.hostsProfileStorageError),
                      TextButton(
                        onPressed: hosts.load,
                        child: Text(l.chatRetry),
                      ),
                    ],
                  ),
                ),
              ),
            if (!hosts.loading && !hosts.storageError && hosts.profiles.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(l.serversNoServersFound),
              ),
            for (final profile in hosts.profiles)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SelectableText(profile.endpoint.toString()),
                      if (hosts.assessments[profile.id] case final assessment?)
                        EndpointStatusView(assessment: assessment),
                      if (hosts.isChecking(profile))
                        LinearProgressIndicator(
                          key: ValueKey('endpoint-check-${profile.id}'),
                          semanticsLabel: l.hostsCheckConnection,
                        ),
                      Wrap(
                        spacing: 12,
                        children: [
                          TextButton(
                            onPressed: hosts.canCheck(profile)
                                ? () => hosts.check(profile)
                                : null,
                            child: Text(l.hostsCheckConnection),
                          ),
                          TextButton(
                            onPressed: () => hosts.remove(profile),
                            child: Text(l.commonDelete),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({required this.hosts});
  final HostsController hosts;
  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  final _form = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _label = TextEditingController();
  final _secret = TextEditingController();
  EndpointAssessment? _assessment;
  String? _testedUrl;
  String? _testedSecret;
  bool _checking = false;
  bool _saving = false;
  bool _saveFailed = false;
  Timer? _retryTimer;

  void _invalidate() {
    _retryTimer?.cancel();
    widget.hosts.cancelProbe();
    setState(() {
      _assessment = null;
      _testedUrl = null;
      _testedSecret = null;
      _checking = false;
    });
  }

  Future<void> _check() async {
    if (!_form.currentState!.validate()) return;
    final url = _url.text.trim();
    final secret = _secret.text;
    setState(() {
      _checking = true;
      _assessment = null;
      _saveFailed = false;
    });
    final result = await widget.hosts.probe(Uri.parse(url), secret);
    if (!mounted || url != _url.text.trim() || secret != _secret.text) return;
    setState(() {
      _checking = false;
      _assessment = result;
      _testedUrl = url;
      _testedSecret = secret;
    });
    final retryAt = result?.retryAt;
    if (retryAt != null) {
      _retryTimer?.cancel();
      final delay = retryAt.difference(DateTime.now().toUtc());
      if (!delay.isNegative) {
        _retryTimer = Timer(delay, () {
          if (mounted) setState(() {});
        });
      }
    }
    if (result?.status == EndpointStatus.legacyServer && mounted) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const LegacyEndpointPage()),
      );
    }
  }

  Future<void> _save() async {
    final result = _assessment;
    if (result == null ||
        !result.canUse ||
        _testedUrl != _url.text.trim() ||
        _testedSecret != _secret.text ||
        _saving) {
      return;
    }
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    final saved = await widget.hosts.add(
      Uri.parse(_testedUrl!),
      _label.text,
      _secret.text,
      result,
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _saveFailed = true;
        _assessment = null;
        _testedUrl = null;
        _testedSecret = null;
      });
    }
  }

  @override
  void dispose() {
    widget.hosts.cancelProbe();
    _retryTimer?.cancel();
    _testedSecret = null;
    _secret.clear();
    for (final controller in [_url, _label, _secret]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.v2L10n;
    return AlertDialog(
      title: Text(l.serversAddServer),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const ValueKey('endpoint-url'),
                controller: _url,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enabled: !_saving,
                decoration: InputDecoration(labelText: l.onboardingServerUrl),
                onChanged: (_) => _invalidate(),
                validator: (text) {
                  try {
                    EndpointProfile.validateEndpoint(Uri.parse(text!.trim()));
                    return null;
                  } on Object {
                    return l.onboardingInvalidUrl;
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('endpoint-label'),
                controller: _label,
                enabled: !_saving,
                maxLength: 160,
                decoration: InputDecoration(labelText: l.onboardingLabel),
              ),
              TextFormField(
                key: const ValueKey('endpoint-secret'),
                controller: _secret,
                enabled: !_saving,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(labelText: l.onboardingPassword),
                onChanged: (_) => _invalidate(),
                validator: (text) => text?.isNotEmpty == true
                    ? null
                    : l.onboardingPasswordRequired,
              ),
              if (_checking || _saving)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(),
                ),
              if (_assessment case final assessment?)
                EndpointStatusView(assessment: assessment),
              if (_saveFailed) Text(l.hostsProfileStorageError),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l.commonCancel),
        ),
        TextButton(
          key: const ValueKey('probe-endpoint'),
          onPressed:
              _checking ||
                  _saving ||
                  _assessment?.retryDeferred == true ||
                  (_assessment?.retryAt?.isAfter(DateTime.now().toUtc()) ??
                      false)
              ? null
              : _check,
          child: Text(l.hostsCheckConnection),
        ),
        FilledButton(
          key: const ValueKey('save-endpoint'),
          onPressed: !_saving && _assessment?.canUse == true ? _save : null,
          child: Text(l.commonSave),
        ),
      ],
    );
  }
}

class EndpointStatusView extends StatelessWidget {
  const EndpointStatusView({super.key, required this.assessment});
  final EndpointAssessment assessment;
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
              '${_status(l, assessment.status)}${assessment.version == null ? '' : ' · ${assessment.version}'}',
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

String _status(V2Localizations l, EndpointStatus status) => switch (status) {
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
