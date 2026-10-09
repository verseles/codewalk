import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_navigation_controller.dart';
import '../../shared/l10n/l10n_context.dart';
import '../hosts/hosts_page.dart';
import 'pairing_controller.dart';

class PairingPage extends StatefulWidget {
  const PairingPage({super.key});
  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  final _link = TextEditingController();
  final _label = TextEditingController();
  PairingController? _controller;
  int _linkRevision = -1;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = context.read<PairingController>();
  }

  @override
  Widget build(BuildContext context) {
    final navigation = context.watch<AppNavigationController>();
    if (_linkRevision != navigation.pairingRevision) {
      _linkRevision = navigation.pairingRevision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final link = navigation.consumePairingLink();
        if (link != null && link.hasQuery) _controller?.input(link.toString());
      });
    }
    final l = context.v2L10n;
    final pairing = context.watch<PairingController>();
    final candidate = pairing.candidate;
    final profile = pairing.target;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              l.pairingTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (profile != null) Text(profile.label),
            const SizedBox(height: 16),
            TextField(
              controller: _link,
              key: const ValueKey('pairing-link'),
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(labelText: l.pairingLink),
              onChanged: (value) => pairing.input(value, profile: profile),
            ),
            if (profile == null)
              TextField(
                controller: _label,
                decoration: InputDecoration(labelText: l.onboardingLabel),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (pairing.qr.cameraAvailable)
                  OutlinedButton.icon(
                    onPressed: pairing.busy
                        ? null
                        : () => pairing.capture(camera: true),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text(l.pairingScanQr),
                  ),
                OutlinedButton.icon(
                  onPressed: pairing.busy
                      ? null
                      : () => pairing.capture(camera: false),
                  icon: const Icon(Icons.image_outlined),
                  label: Text(l.pairingImageQr),
                ),
              ],
            ),
            if (candidate != null || profile != null) ...[
              const SizedBox(height: 16),
              SelectableText(
                (profile?.endpoint ?? candidate!.endpoint).toString(),
              ),
            ],
            if (pairing.busy) const LinearProgressIndicator(),
            if (pairing.captureError != null) Text(l.pairingCaptureError),
            if (pairing.storageError) Text(l.hostsProfileStorageError),
            if (pairing.receipt case final receipt?) ...[
              if (receipt.assessment case final assessment?)
                EndpointStatusView(assessment: assessment),
              if (receipt.credential?.expiresAt case final expiry?)
                Text('${l.pairingExpires}: ${expiry.toLocal()}'),
              if (!receipt.canSave && receipt.credential == null)
                Text(
                  receipt.status == PairingStatus.uncertain
                      ? l.pairingUncertain
                      : l.pairingRejected,
                ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('confirm-pairing'),
              onPressed:
                  !pairing.busy && candidate != null && pairing.receipt == null
                  ? pairing.confirm
                  : null,
              child: Text(l.pairingConfirm),
            ),
            if (pairing.receipt?.credential != null)
              FilledButton(
                key: const ValueKey('save-pairing'),
                onPressed: pairing.busy
                    ? null
                    : () async {
                        final saved = await pairing.save(_label.text);
                        if (saved && mounted) {
                          _link.clear();
                          _label.clear();
                        }
                      },
                child: Text(l.commonSave),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.close();
    _link.dispose();
    _label.dispose();
    super.dispose();
  }
}
