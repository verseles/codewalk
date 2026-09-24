import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/di/injection_container.dart' as di;
import '../../core/i18n/l10n_context.dart';
import '../../domain/entities/experience_settings.dart';
import '../services/nemotron_model_manager.dart';
import 'app_indeterminate_progress.dart';

class NemotronModelCard extends StatefulWidget {
  const NemotronModelCard({super.key});

  @override
  State<NemotronModelCard> createState() => _NemotronModelCardState();
}

class _NemotronModelCardState extends State<NemotronModelCard> {
  final _manager = di.sl<NemotronModelManager>();
  bool _installed = false;
  bool _busy = false;
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final installed = await _manager.hasModel(kNemotronModelDefault);
    if (!mounted) return;
    setState(() => _installed = installed);
  }

  Future<void> _download() async {
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });
    try {
      await _manager.downloadModel(
        kNemotronModelDefault,
        onProgress: (value) {
          if (!mounted) return;
          setState(() => _progress = value);
        },
      );
      final installed = await _manager.hasModel(kNemotronModelDefault);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _installed = installed;
        _error = installed
            ? null
            : context.l10n.speechDownloadFailed('incomplete archive');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _manager.deleteModel(kNemotronModelDefault);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _installed = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.speechNemotron,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(l10n.speechNemotronStaysDownloadable),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _busy || _installed ? null : _download,
                  icon: const Icon(Icons.download_rounded),
                  label: Text(l10n.speechDownload),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _busy || !_installed ? null : _delete,
                  child: Text(l10n.speechRemove),
                ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: 10),
              _progress > 0
                  ? LinearProgressIndicator(value: _progress)
                  : const AppIndeterminateBar(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NemotronModelDownloadDialog extends StatefulWidget {
  const NemotronModelDownloadDialog({super.key});

  @override
  State<NemotronModelDownloadDialog> createState() =>
      _NemotronModelDownloadDialogState();
}

class _NemotronModelDownloadDialogState
    extends State<NemotronModelDownloadDialog> {
  final _manager = di.sl<NemotronModelManager>();
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _error = null;
      _progress = 0;
    });
    try {
      await _manager.downloadModel(
        kNemotronModelDefault,
        onProgress: (value) {
          if (!mounted) return;
          setState(() => _progress = value);
        },
      );
      final installed = await _manager.hasModel(kNemotronModelDefault);
      if (!mounted) return;
      if (!installed) {
        setState(() {
          _downloading = false;
          _error = context.l10n.speechDownloadFailed('incomplete archive');
        });
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.speechNemotron),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.speechNemotronStaysDownloadable),
          if (_downloading) ...[
            const SizedBox(height: 12),
            _progress > 0
                ? LinearProgressIndicator(value: _progress)
                : const AppIndeterminateBar(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _downloading ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _downloading ? null : _download,
          child: Text(l10n.speechDownload),
        ),
      ],
    );
  }
}
