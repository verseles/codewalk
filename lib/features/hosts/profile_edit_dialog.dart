import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';

import '../../shared/l10n/l10n_context.dart';
import 'hosts_controller.dart';

class ProfileEditDialog extends StatefulWidget {
  const ProfileEditDialog({
    required this.hosts,
    required this.profile,
    super.key,
  });
  final HostsController hosts;
  final EndpointProfile profile;

  @override
  State<ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<ProfileEditDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _url;
  late EndpointProfile _expected;
  late int _revision;
  bool _busy = false;
  bool _failed = false;
  bool _reconciled = false;
  bool _exists = true;

  @override
  void initState() {
    super.initState();
    _expected = widget.profile;
    _revision = widget.hosts.catalogRevision;
    _label = TextEditingController(text: _expected.label);
    _url = TextEditingController(text: _expected.endpoint.toString());
  }

  Future<void> _save() async {
    if (_busy || !_exists || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final saved = await widget.hosts.updateProfile(
      _expected,
      label: _label.text.trim(),
      endpoint: Uri.parse(_url.text.trim()),
      expectedRevision: _revision,
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _failed = true;
        _reconciled = false;
      });
    }
  }

  Future<void> _reload() async {
    if (_busy || widget.hosts.savingProfile || widget.hosts.loading) return;
    setState(() => _busy = true);
    await widget.hosts.load();
    if (!mounted) return;
    final current = widget.hosts.profiles
        .where((profile) => profile.id == _expected.id)
        .firstOrNull;
    if (widget.hosts.storageError ||
        widget.hosts.loading ||
        widget.hosts.savingProfile ||
        current == null) {
      setState(() {
        _busy = false;
        _failed = true;
        _exists = current != null;
      });
      return;
    }
    Uri? proposed;
    try {
      proposed = EndpointProfile.validateEndpoint(Uri.parse(_url.text.trim()));
    } on FormatException {
      // Keep the typed URL and its validation message.
    }
    if (current.label == _label.text.trim() && current.endpoint == proposed) {
      // Readback can confirm a save whose acknowledgement was lost.
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _expected = current;
      _revision = widget.hosts.catalogRevision;
      _busy = false;
      _failed = false;
      _reconciled = true;
      _exists = true;
    });
  }

  @override
  void dispose() {
    _label.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.v2L10n;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(l.serversEdit),
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
                  key: const ValueKey('edit-endpoint-label'),
                  controller: _label,
                  enabled: !_busy,
                  maxLength: 160,
                  decoration: InputDecoration(labelText: l.onboardingLabel),
                  validator: (value) {
                    final label = value?.trim() ?? '';
                    return label.isEmpty ||
                            label.length > 160 ||
                            label.runes.any((c) => c < 32 || c == 127)
                        ? l.hostsEditInvalidLabel
                        : null;
                  },
                ),
                TextFormField(
                  key: const ValueKey('edit-endpoint-url'),
                  controller: _url,
                  enabled: !_busy,
                  keyboardType: TextInputType.url,
                  textDirection: TextDirection.ltr,
                  autocorrect: false,
                  decoration: InputDecoration(labelText: l.onboardingServerUrl),
                  validator: (value) {
                    try {
                      EndpointProfile.validateEndpoint(
                        Uri.parse((value ?? '').trim()),
                      );
                      return null;
                    } on FormatException {
                      return l.onboardingInvalidUrl;
                    }
                  },
                ),
                if (_busy) const LinearProgressIndicator(),
                if (_failed) ...[
                  Text(l.hostsEditChanged),
                  TextButton(
                    key: const ValueKey('edit-endpoint-reload'),
                    onPressed: _busy ? null : _reload,
                    child: Text(l.chatRetry),
                  ),
                ],
                if (_reconciled) ...[
                  const SizedBox(height: 12),
                  Text(l.hostsEditSavedProfile),
                  Text('${l.onboardingLabel}: ${_expected.label}'),
                  SelectableText(
                    _expected.endpoint.toString(),
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            key: const ValueKey('edit-endpoint-save'),
            onPressed: _busy || !_exists ? null : _save,
            child: Text(l.commonSave),
          ),
        ],
      ),
    );
  }
}
