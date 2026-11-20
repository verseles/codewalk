import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';

/// Projects one row of `GET /api/model` into a canonical [ModelEntry], or
/// returns `null` when the model is disabled.
///
/// Populates [ModelEntry.inputModalities] strictly from `capabilities.input`
/// when advertised as a JSON list; absent or malformed capability arrays stay
/// empty so unknown modalities are never treated as consent.
ModelEntry? projectOpenCodeModelRow(Object? row) {
  final model = openCodeCatalogObject(row);
  if (model['enabled'] is! bool) {
    throw const FormatException('Malformed model.');
  }
  if (model['enabled'] != true) return null;
  final limit = openCodeCatalogObject(model['limit']);
  final variants = model['variants'];
  if (variants is! List) throw const FormatException('Malformed model.');
  return ModelEntry(
    id: openCodeCatalogText(model['id']),
    providerId: openCodeCatalogText(model['providerID']),
    label: openCodeCatalogText(model['name'], empty: true),
    inputModalities: _modelInputModalities(model['capabilities']),
    contextLimit: openCodeCatalogCount(limit['context']),
    outputLimit: openCodeCatalogCount(limit['output']),
    // An empty id cannot be named (`provider/model#variant`), so that
    // variant is not offered; the rest of the catalog still is.
    variants: [
      for (final variant in variants)
        openCodeCatalogText(
          openCodeCatalogObject(variant)['id'],
          empty: true,
        ),
    ].where((id) => id.isNotEmpty),
    cost: _catalogCost(model['cost']),
  );
}

Map<String, bool?> _modelInputModalities(Object? capabilities) {
  if (capabilities is! Map<String, Object?>) return const {};
  final input = capabilities['input'];
  if (input is! List) return const {};
  final advertised = <String>{};
  for (final value in input) {
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isNotEmpty && normalized.length <= 64) {
        advertised.add(normalized);
      }
    }
  }
  return {
    'text': advertised.contains('text'),
    'image': advertised.contains('image'),
    'pdf': advertised.contains('pdf'),
    'audio': advertised.contains('audio'),
    'video': advertised.contains('video'),
  };
}

Map<String, Object?> openCodeCatalogObject(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Malformed catalog row.');
  }
  return value;
}

String openCodeCatalogText(Object? value, {bool empty = false}) {
  if (value is! String ||
      (value.isEmpty && !empty) ||
      utf8.encode(value).length > 4096 ||
      utf8.decode(utf8.encode(value)) != value) {
    throw const FormatException('Malformed catalog text.');
  }
  return value;
}

int openCodeCatalogCount(Object? value) {
  if (value is! int || value < 0) {
    throw const FormatException('Malformed catalog limit.');
  }
  return value;
}

/// A model's prices, or null when they cannot be read: a price is shown
/// only as stated, and an unreadable one never fails the catalog.
List<ModelCost>? _catalogCost(Object? value) {
  if (value is! List || value.length > 16) return null;
  double? money(Object? value) =>
      value is num && value.isFinite && value >= 0 ? value.toDouble() : null;
  final prices = <ModelCost>[];
  for (final row in value) {
    if (row is! Map<String, Object?>) return null;
    final cache = row['cache'];
    final tier = row['tier'];
    if (cache is! Map<String, Object?>) return null;
    final size = switch (tier) {
      null => null,
      {'type': 'context', 'size': final int size} when size >= 0 => size,
      _ => -1,
    };
    if (size == -1) return null;
    final input = money(row['input']);
    final output = money(row['output']);
    final read = money(cache['read']);
    final write = money(cache['write']);
    if (input == null || output == null || read == null || write == null) {
      return null;
    }
    prices.add(
      ModelCost(
        input: input,
        output: output,
        cacheRead: read,
        cacheWrite: write,
        contextTier: size,
      ),
    );
  }
  return prices;
}

/// Where `OpenCodeSessionReader.locatePrompt` found one native prompt id.
sealed class OpenCodePromptLocation {
  const OpenCodePromptLocation();
}

/// Still in the inbox: admitted, not yet delivered.
final class OpenCodePromptPending extends OpenCodePromptLocation {
  const OpenCodePromptPending({required this.text, required this.delivery});
  final String text;

  /// The native delivery (`steer` or `queue`).
  final String delivery;
}

/// Promoted to history: delivered.
final class OpenCodePromptPromoted extends OpenCodePromptLocation {
  const OpenCodePromptPromoted();
}

/// The id belongs to another kind of record.
final class OpenCodePromptOccupied extends OpenCodePromptLocation {
  const OpenCodePromptOccupied();
}

/// Neither in the inbox nor anywhere in the complete history.
final class OpenCodePromptAbsent extends OpenCodePromptLocation {
  const OpenCodePromptAbsent();
}

/// Not in the inbox nor in the history pages read, but history goes on.
final class OpenCodePromptIncomplete extends OpenCodePromptLocation {
  const OpenCodePromptIncomplete();
}
