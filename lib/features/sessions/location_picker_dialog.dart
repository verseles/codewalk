import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/media/location_fix_source.dart';
import '../../shared/widgets/app_indeterminate_progress.dart';

/// Opens a dialog to attach geographic coordinates via optional platform GPS
/// or manual latitude/longitude entry plus an optional label.
Future<GeoPoint?> showLocationPickerDialog(
  BuildContext context, {
  LocationFixSource? locationSource,
}) => showDialog<GeoPoint>(
  context: context,
  builder: (_) => _LocationPickerDialog(locationSource: locationSource),
);

class _LocationPickerDialog extends StatefulWidget {
  const _LocationPickerDialog({this.locationSource});

  final LocationFixSource? locationSource;

  @override
  State<_LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<_LocationPickerDialog> {
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _labelController = TextEditingController();
  double? _accuracyMeters;
  bool _locating = false;
  String? _statusMessage;
  String? _validationError;

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    final source = widget.locationSource;
    if (source == null || !source.supported || _locating) return;
    setState(() {
      _locating = true;
      _statusMessage = null;
      _validationError = null;
    });
    final result = await source.getCurrentLocation();
    if (!mounted) return;
    final l10n = context.v2L10n;
    switch (result.outcome) {
      case LocationFixOutcome.ok:
        final point = result.point!;
        _latController.text = point.latitude.toStringAsFixed(6);
        _lonController.text = point.longitude.toStringAsFixed(6);
        _accuracyMeters = point.accuracyMeters;
        setState(() {
          _locating = false;
          _statusMessage = null;
          _validationError = null;
        });
      case LocationFixOutcome.denied || LocationFixOutcome.deniedForever:
        setState(() {
          _locating = false;
          _statusMessage = l10n.composerLocationDenied;
        });
      case LocationFixOutcome.serviceDisabled ||
          LocationFixOutcome.unavailable ||
          LocationFixOutcome.timeout ||
          LocationFixOutcome.failed:
        setState(() {
          _locating = false;
          _statusMessage = l10n.composerLocationUnavailable;
        });
    }
  }

  void _submit() {
    final l10n = context.v2L10n;
    final lat = double.tryParse(_latController.text.trim().replaceAll(',', '.'));
    final lon = double.tryParse(_lonController.text.trim().replaceAll(',', '.'));
    if (lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180) {
      setState(() => _validationError = l10n.composerLocationInvalid);
      return;
    }
    final rawLabel = _labelController.text.trim();
    final safeLabel = rawLabel.isEmpty
        ? null
        : (rawLabel.length > GeoPoint.maxLabelChars
              ? rawLabel.substring(0, GeoPoint.maxLabelChars)
              : rawLabel);
    try {
      final point = GeoPoint(
        latitude: lat,
        longitude: lon,
        accuracyMeters: _accuracyMeters,
        label: safeLabel,
      );
      Navigator.of(context).pop(point);
    } on ArgumentError {
      setState(() => _validationError = l10n.composerLocationInvalid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final canLocate = widget.locationSource?.supported == true;
    return AlertDialog(
      key: const ValueKey('location-picker-dialog'),
      title: Text(l10n.composerLocationTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (canLocate) ...[
              OutlinedButton.icon(
                key: const ValueKey('location-use-current'),
                onPressed: _locating ? null : () => unawaited(_useCurrentLocation()),
                icon: _locating
                    ? const AppIndeterminateRing(size: 16, strokeWidth: 2)
                    : const Icon(Symbols.my_location, size: 18),
                label: Text(l10n.composerLocationUseCurrent),
              ),
              const SizedBox(height: 12),
            ],
            if (_statusMessage != null) ...[
              Text(
                _statusMessage!,
                key: const ValueKey('location-status'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('location-latitude'),
                    controller: _latController,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.composerLocationLatitude,
                      hintText: '-23.550520',
                    ),
                    onChanged: (_) {
                      _accuracyMeters = null;
                      if (_validationError != null) {
                        setState(() => _validationError = null);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const ValueKey('location-longitude'),
                    controller: _lonController,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.composerLocationLongitude,
                      hintText: '-46.633308',
                    ),
                    onChanged: (_) {
                      _accuracyMeters = null;
                      if (_validationError != null) {
                        setState(() => _validationError = null);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('location-label'),
              controller: _labelController,
              maxLength: GeoPoint.maxLabelChars,
              decoration: InputDecoration(
                labelText: l10n.composerLocationLabel,
                counterText: '',
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_validationError != null) ...[
              const SizedBox(height: 8),
              Text(
                _validationError!,
                key: const ValueKey('location-error'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('location-confirm'),
          onPressed: _submit,
          child: Text(l10n.composerLocationAdd),
        ),
      ],
    );
  }
}
