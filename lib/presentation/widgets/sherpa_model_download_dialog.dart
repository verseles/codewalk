import 'dart:async';
import 'dart:convert';

import '../../core/i18n/l10n_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/di/injection_container.dart' as di;
import '../services/sherpa_model_manager.dart';
import 'modal_primary_action_shortcuts.dart';

// Model manifest entry loaded from assets/sherpa_models.json.
class _SherpaModelEntry {
  const _SherpaModelEntry({
    required this.code,
    required this.label,
    required this.sizeMb,
  });

  final String code;
  final String label;
  final int sizeMb;
}

// First-use dialog for Sherpa STT: lets the user pick a language, shows model
// size, then downloads the Kroko on-device model with a progress bar.
// Returns true via Navigator.pop() when the model is ready, null if cancelled.
class SherpaModelDownloadDialog extends StatefulWidget {
  const SherpaModelDownloadDialog({super.key});

  @override
  State<SherpaModelDownloadDialog> createState() =>
      _SherpaModelDownloadDialogState();
}

class _SherpaModelDownloadDialogState extends State<SherpaModelDownloadDialog> {
  final _manager = di.sl<SherpaModelManager>();

  List<_SherpaModelEntry> _models = [];
  String? _selectedCode;
  bool _isLoading = true;
  bool _isDownloading = false;
  double _progress = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadManifest();
  }

  // Reads sherpa_models.json from the app bundle and pre-selects system locale.
  Future<void> _loadManifest() async {
    try {
      final raw = await rootBundle.loadString('assets/sherpa_models.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final entries = (json['models'] as List).map((m) {
        final map = m as Map<String, dynamic>;
        return _SherpaModelEntry(
          code: map['code'] as String,
          label: map['label'] as String,
          sizeMb: (map['size_mb'] as num).toInt(),
        );
      }).toList();

      final systemLang = _manager.detectSystemLanguage();
      final preselect = entries.any((e) => e.code == systemLang)
          ? systemLang
          : entries.first.code;
      _manager.setPreferredLanguage(preselect);

      if (!mounted) return;
      setState(() {
        _models = entries;
        _selectedCode = preselect;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = context.l10n.speechModelListLoadFailed(
          e.toString(),
          'Sherpa',
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _startDownload() async {
    final code = _selectedCode;
    if (code == null) return;

    setState(() {
      _isDownloading = true;
      _progress = 0;
      _errorMessage = null;
    });

    try {
      _manager.setPreferredLanguage(code);
      await _manager.downloadModel(
        code,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = context.l10n.speechDownloadFailed(e.toString());
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedCode == null
        ? null
        : _models.firstWhere(
            (m) => m.code == _selectedCode,
            orElse: () => _models.first,
          );

    return ModalPrimaryActionShortcuts(
      autofocus: true,
      enabled: _selectedCode != null && !_isDownloading,
      onPrimaryAction: () {
        unawaited(_startDownload());
      },
      child: AlertDialog(
        title: Text(context.l10n.dialogVoiceInputSetup),
        content: SizedBox(
          width: 380,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildContent(selected),
        ),
        actions: _isDownloading
            ? null
            : [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text(context.l10n.commonCancel),
                ),
                FilledButton(
                  onPressed:
                      _selectedCode == null ||
                          _errorMessage != null && _isDownloading
                      ? null
                      : _startDownload,
                  child: Text(context.l10n.dialogDownload),
                ),
              ],
      ),
    );
  }

  Widget _buildContent(_SherpaModelEntry? selected) {
    if (_errorMessage != null && !_isDownloading) {
      return Text(
        _errorMessage!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.dialogSherpaVoiceSetupDescription),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedCode,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.l10n.dialogLanguage,
            border: const OutlineInputBorder(),
          ),
          items: _models
              .map((m) => DropdownMenuItem(value: m.code, child: Text(m.label)))
              .toList(),
          onChanged: _isDownloading
              ? null
              : (value) {
                  if (value == null) return;
                  _manager.setPreferredLanguage(value);
                  setState(() => _selectedCode = value);
                },
        ),
        if (selected != null) ...[
          const SizedBox(height: 8),
          Text(
            context.l10n.speechModelSizeMb(selected.sizeMb.toString()),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (_isDownloading) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 4),
          Text(
            '${(_progress * 100).toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}
