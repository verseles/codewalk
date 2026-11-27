import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../app/app_navigation_controller.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/widgets/app_indeterminate_progress.dart';
import '../../shared/widgets/modal_primary_action_shortcuts.dart';
import '../pairing/pairing_controller.dart';
import 'endpoint_status_view.dart';
import 'hosts_controller.dart';

/// Opens the one add-server screen (#506), the `/pair` page on every width.
/// [prepare] sets up pairing for an existing server (Pair again, Renew);
/// without it a new server is added.
Future<void> showAddServer(
  BuildContext context, {
  void Function(PairingController pairing)? prepare,
}) async {
  final pairing = context.read<PairingController>();
  if (prepare == null) {
    pairing.empty();
  } else {
    prepare(pairing);
  }
  await context.push('/pair');
}

/// The harness, then a pairing link or QR, or a manual URL and password
/// (#504, #506). Opens on the pairing link; a server already saved (Pair
/// again, Renew) only pairs. It never shows the server version.
class AddServerPanel extends StatefulWidget {
  const AddServerPanel({super.key, required this.onDone, this.linkRevision});

  /// Called once the server is saved while this screen is current.
  final VoidCallback onDone;

  /// Changes when a pairing link arrives for this screen, which then drops
  /// any manual attempt and shows the link mode again.
  final int? linkRevision;

  @override
  State<AddServerPanel> createState() => _AddServerPanelState();
}

class _AddServerPanelState extends State<AddServerPanel> {
  final _form = GlobalKey<FormState>();
  final _link = TextEditingController();
  final _label = TextEditingController();
  final _url = TextEditingController();
  final _secret = TextEditingController();
  HostsController? _hosts;
  PairingController? _pairing;
  AppNavigationController? _navigation;
  int? _ownedRevision;
  String? _kind;
  HarnessConnectMethod? _method;
  EndpointAssessment? _failure;
  // The server's Retry-After for the checked input; it outlives a failed save.
  EndpointAssessment? _fence;
  // Only a check this screen has in flight is cancelled when it is dropped.
  bool _ownsProbe = false;
  // The generation of this screen's last completed check, whose save
  // authorization (and password) the hosts controller holds until then.
  int? _checkedGeneration;
  // Each manual attempt; a link or leaving the screen drops older ones.
  int _attempt = 0;
  // The pairing link revision when the current attempt started.
  int? _attemptRevision;
  bool _saving = false;
  bool _saveFailed = false;
  bool _labelInvalid = false;
  // Saved while another screen covered this one; close once it is back.
  bool _pendingDone = false;
  Timer? _retryTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _hosts = context.read<HostsController>();
    _pairing = context.read<PairingController>();
    _navigation = context.read<AppNavigationController?>();
    _ownedRevision ??= _navigation?.pairingRevision;
  }

  @override
  void didUpdateWidget(AddServerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.linkRevision != oldWidget.linkRevision) {
      // This screen now owns the newer link, even mid-attempt.
      _ownedRevision = _navigation?.pairingRevision;
      _drop();
      _method = null;
      // A save that ended under another page no longer closes this one.
      _pendingDone = false;
    }
  }

  Set<HarnessConnectMethod> _methods(HostsController hosts) =>
      hosts.harnesses?.resolve(_kind)?.methods ??
      const {
        HarnessConnectMethod.pairingLink,
        HarnessConnectMethod.manualPassword,
      };

  HarnessConnectMethod _currentMethod(
    HostsController hosts,
    PairingController pairing,
  ) {
    if (pairing.target != null) return HarnessConnectMethod.pairingLink;
    final methods = _methods(hosts);
    final chosen = _method;
    if (chosen != null && methods.contains(chosen)) return chosen;
    return methods.contains(HarnessConnectMethod.pairingLink)
        ? HarnessConnectMethod.pairingLink
        : methods.first;
  }

  bool _retryFenced(EndpointAssessment? assessment) =>
      assessment?.retryDeferred == true ||
      (assessment?.retryAt?.isAfter(DateTime.now().toUtc()) ?? false);

  // Current among its own navigator's routes; a dialog over the whole app
  // does not stop this screen from closing under it.
  bool get _current => ModalRoute.isCurrentOf(context) ?? true;

  // False once this screen is popped and animating away.
  bool get _active => ModalRoute.of(context)?.isActive ?? true;

  // Drops any manual attempt: its check is cancelled and a late result can
  // neither save nor navigate.
  void _drop() {
    _attempt++;
    _retryTimer?.cancel();
    if (_ownsProbe) _hosts?.cancelProbe();
    _ownsProbe = false;
    if (_checkedGeneration case final generation?) {
      _hosts?.forgetVerification(generation);
    }
    _checkedGeneration = null;
    _saving = false;
    _failure = null;
    _fence = null;
    _saveFailed = false;
  }

  void _invalidate() => setState(_drop);

  // The revision this screen shows, not the live one: a link prepared before
  // the rebuild already supersedes an attempt started from the old form.
  int _startAttempt() {
    _attemptRevision = _ownedRevision;
    return ++_attempt;
  }

  // A link counts from the moment it is prepared, before this screen
  // rebuilds with it.
  bool _superseded(int attempt) =>
      attempt != _attempt || _navigation?.pairingRevision != _attemptRevision;

  static bool _validLabel(String text) =>
      text.trim().isEmpty ||
      (text.length <= 160 && !text.runes.any((c) => c < 32 || c == 127));

  Future<bool> _add(
    HostsController hosts,
    String url,
    String secret,
    EndpointAssessment assessment, {
    bool acceptFailure = false,
  }) async {
    try {
      return await hosts.add(
        Uri.parse(url),
        _label.text,
        secret,
        assessment,
        harnessKind: _kind,
        acceptFailure: acceptFailure,
      );
    } on Object {
      return false;
    }
  }

  Future<void> _saveManual(HostsController hosts) async {
    if (_saving || !_form.currentState!.validate()) return;
    final attempt = _startAttempt();
    if (_superseded(attempt)) return;
    final url = _url.text.trim();
    final secret = _secret.text;
    setState(() {
      _saving = true;
      _failure = null;
      _saveFailed = false;
    });
    _ownsProbe = true;
    final result = await hosts.probe(Uri.parse(url), secret);
    if (!mounted || attempt != _attempt) return;
    _ownsProbe = false;
    if (result != null) _checkedGeneration = hosts.checkGeneration;
    // The newer link's rebuild drops this attempt and settles its state.
    if (_superseded(attempt)) return;
    if (result == null || !_active) {
      // Superseded, or the screen is closing: nothing is saved or opened.
      setState(() => _saving = false);
      return;
    }
    if (result.canUse) {
      _finish(attempt, await _add(hosts, url, secret, result));
      return;
    }
    setState(() {
      _saving = false;
      _failure = result;
      _fence = _retryFenced(result) ? result : null;
    });
    final retryAt = result.retryAt;
    if (retryAt != null) {
      _retryTimer?.cancel();
      final delay = retryAt.difference(DateTime.now().toUtc());
      if (!delay.isNegative) {
        _retryTimer = Timer(delay, () {
          if (mounted) setState(() {});
        });
      }
    }
    if (result.status == EndpointStatus.legacyServer) {
      // Full screen above the app shell, as before the add screen merged.
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute(builder: (_) => const LegacyEndpointPage()),
      );
    }
  }

  Future<void> _saveAnyway(HostsController hosts) async {
    final failure = _failure;
    if (_saving || failure == null || !_form.currentState!.validate()) return;
    final attempt = _startAttempt();
    if (_superseded(attempt)) return;
    setState(() => _saving = true);
    _finish(
      attempt,
      await _add(
        hosts,
        _url.text.trim(),
        _secret.text,
        failure,
        acceptFailure: true,
      ),
    );
  }

  Future<void> _savePairing(PairingController pairing) async {
    if (!_validLabel(_label.text)) {
      setState(() => _labelInvalid = true);
      return;
    }
    setState(() => _labelInvalid = false);
    final saved = await pairing.save(_label.text, harnessKind: _kind);
    if (saved) _complete();
  }

  void _finish(int attempt, bool saved) {
    if (!mounted) return;
    // A newer link took over this screen and its own attempt owns the state.
    if (_superseded(attempt)) return;
    if (saved) {
      _complete();
      return;
    }
    setState(() {
      _saving = false;
      _saveFailed = true;
      _failure = null;
    });
  }

  // Navigates only while this screen is its navigator's current route; a
  // save that ends under another page closes this one when it is back.
  void _complete() {
    if (!mounted || !_active) return;
    if (_current) {
      widget.onDone();
      return;
    }
    setState(() {
      _saving = false;
      _pendingDone = true;
    });
  }

  @override
  void dispose() {
    _attempt++;
    _retryTimer?.cancel();
    if (_ownsProbe) _hosts?.cancelProbe();
    if (_checkedGeneration case final generation?) {
      _hosts?.forgetVerification(generation);
    }
    // A newer pairing link owns the controller now; leave it to its page.
    if (_navigation?.pairingRevision == _ownedRevision) _pairing?.close();
    _secret.clear();
    for (final controller in [_link, _label, _url, _secret]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.v2L10n;
    final hosts = context.watch<HostsController>();
    final pairing = context.watch<PairingController>();
    final options = hosts.harnesses;
    final repairing = pairing.target != null;
    final methods = _methods(hosts);
    final method = _currentMethod(hosts, pairing);
    final locked = _saving || pairing.busy;
    if (_pendingDone && _current) {
      _pendingDone = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onDone();
      });
    }
    return PopScope(
      canPop: !locked,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!repairing && options != null) ...[
            DropdownButtonFormField<String>(
              key: const ValueKey('add-harness'),
              isExpanded: true,
              initialValue: _kind ?? options.defaultKind,
              decoration: InputDecoration(labelText: l.serversHarness),
              items: [
                for (final option in options.options)
                  DropdownMenuItem(
                    value: option.kind,
                    enabled: option.selectable,
                    child: Text(
                      option.selectable
                          ? option.displayName
                          : '${option.displayName} · ${l.serversComingSoon}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: locked
                  ? null
                  : (kind) => setState(() {
                      _kind = kind;
                      _failure = null;
                    }),
            ),
            const SizedBox(height: 16),
          ],
          if (!repairing && methods.length > 1) ...[
            SegmentedButton<HarnessConnectMethod>(
              key: const ValueKey('add-method'),
              showSelectedIcon: false,
              segments: [
                if (methods.contains(HarnessConnectMethod.pairingLink))
                  ButtonSegment(
                    value: HarnessConnectMethod.pairingLink,
                    icon: const Icon(Symbols.qr_code),
                    label: Text(
                      l.pairingLink,
                      key: const ValueKey('add-method-link'),
                    ),
                  ),
                if (methods.contains(HarnessConnectMethod.manualPassword))
                  ButtonSegment(
                    value: HarnessConnectMethod.manualPassword,
                    icon: const Icon(Symbols.edit),
                    label: Text(
                      l.serversMethodManual,
                      key: const ValueKey('add-method-manual'),
                    ),
                  ),
              ],
              selected: {method},
              onSelectionChanged: locked
                  ? null
                  : (selection) => setState(() => _method = selection.single),
            ),
            const SizedBox(height: 16),
          ],
          if (method == HarnessConnectMethod.pairingLink)
            _linkForm(context, pairing)
          else
            _manualForm(context, hosts),
        ],
      ),
    );
  }

  Widget _linkForm(BuildContext context, PairingController pairing) {
    final l = context.v2L10n;
    final candidate = pairing.candidate;
    final profile = pairing.target;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            key: const ValueKey('pairing-label'),
            maxLength: 160,
            decoration: InputDecoration(
              labelText: l.onboardingLabel,
              errorText: _labelInvalid ? l.hostsEditInvalidLabel : null,
            ),
            onChanged: (_) {
              if (_labelInvalid) setState(() => _labelInvalid = false);
            },
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
                icon: const Icon(Symbols.qr_code_scanner),
                label: Text(l.pairingScanQr),
              ),
            OutlinedButton.icon(
              onPressed: pairing.busy
                  ? null
                  : () => pairing.capture(camera: false),
              icon: const Icon(Symbols.image),
              label: Text(l.pairingImageQr),
            ),
          ],
        ),
        if (candidate != null || profile != null) ...[
          const SizedBox(height: 16),
          SelectableText((profile?.endpoint ?? candidate!.endpoint).toString()),
        ],
        if (pairing.busy) const AppIndeterminateBar(),
        if (pairing.captureError != null) Text(l.pairingCaptureError),
        if (pairing.storageError) Text(l.hostsProfileStorageError),
        if (pairing.receipt case final receipt?) ...[
          if (receipt.assessment case final assessment?)
            EndpointStatusView(assessment: assessment, showVersion: false),
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
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
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
                onPressed: pairing.busy ? null : () => _savePairing(pairing),
                child: Text(l.commonSave),
              ),
          ],
        ),
      ],
    );
  }

  Widget _manualForm(BuildContext context, HostsController hosts) {
    final l = context.v2L10n;
    final failure = _failure;
    final saveAnyway =
        failure != null && HostsController.canSaveDespite(failure);
    final fenced = _retryFenced(_fence);
    // A failure, or the Retry-After that still holds Save after one.
    final shown = failure ?? (fenced ? _fence : null);
    return ModalPrimaryActionShortcuts(
      enabled: !_saving && !fenced,
      onPrimaryAction: () => _saveManual(hosts),
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
              validator: (text) =>
                  _validLabel(text ?? '') ? null : l.hostsEditInvalidLabel,
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
              validator: (text) {
                if (text == null || text.isEmpty) {
                  return l.onboardingPasswordRequired;
                }
                if (text.length > 16384 ||
                    text.runes.any((c) => c < 32 || c == 127)) {
                  return l.hostsAuthRequired;
                }
                return null;
              },
            ),
            if (_saving)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: AppIndeterminateBar(),
              ),
            if (shown != null) ...[
              EndpointStatusView(assessment: shown, showVersion: false),
              // A server that asked to wait over a day is not checked
              // again automatically, so it gets no such promise.
              if (saveAnyway && !failure.retryDeferred)
                Text(l.hostsSaveAnywayHint),
            ],
            if (_saveFailed) Text(l.hostsProfileStorageError),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  key: const ValueKey('save-endpoint'),
                  onPressed: _saving || fenced
                      ? null
                      : () => _saveManual(hosts),
                  child: Text(l.commonSave),
                ),
                if (saveAnyway)
                  OutlinedButton(
                    key: const ValueKey('save-endpoint-anyway'),
                    onPressed: _saving ? null : () => _saveAnyway(hosts),
                    child: Text(l.hostsSaveAnyway),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
