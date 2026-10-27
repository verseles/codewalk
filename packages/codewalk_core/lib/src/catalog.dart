import 'capabilities.dart';
import 'identity.dart';
import 'values.dart';

enum Stability { stable, experimental, unknown }

enum Compatibility { supported, untested, blocked, unknown }

final class HarnessDescriptor {
  HarnessDescriptor({
    required this.ref,
    required String kind,
    required String version,
    required this.stability,
    required this.compatibility,
    this.reason,
  }) : kind = requireText(kind),
       version = requireText(version);
  final HarnessRef ref;
  final String kind;
  final String version;
  final OpenValue<Stability> stability;
  final OpenValue<Compatibility> compatibility;
  final String? reason;
}

enum CatalogKind { model, agent, effort, command, skill, mention, unknown }

final class CatalogEntry {
  CatalogEntry({
    required String id,
    required this.kind,
    required this.label,
    this.description,
    this.capabilities,
    this.metadata,
  }) : id = requireText(id);
  final String id;
  final OpenValue<CatalogKind> kind;
  final String label;
  final String? description;
  final CapabilitySet? capabilities;
  final CanonicalValue? metadata;
}

final class ModelEntry {
  ModelEntry({
    required String id,
    required String providerId,
    required this.label,
    Map<String, bool?> inputModalities = const {},
    this.contextLimit,
    this.outputLimit,
    Iterable<String> variants = const [],
    Iterable<ModelCost>? cost,
    this.metadata,
  }) : id = requireText(id),
       providerId = requireText(providerId),
       inputModalities = immutableMap(inputModalities),
       variants = immutableList(variants.map(requireText)),
       cost = cost == null ? null : immutableList(cost) {
    if ((contextLimit != null && contextLimit! < 0) ||
        (outputLimit != null && outputLimit! < 0)) {
      throw ArgumentError('Model limits must not be negative');
    }
  }
  final String id;
  final String providerId;
  final String label;
  final Map<String, bool?> inputModalities;
  final int? contextLimit;
  final int? outputLimit;

  /// Variant ids in catalog order; the variant settings are never copied.
  final List<String> variants;

  /// The catalog's prices, or null when it did not state them readably.
  final List<ModelCost>? cost;
  final CanonicalValue? metadata;

  /// Free only when the catalog states one untiered price and it is zero:
  /// an unknown, empty or tiered price is not called free.
  bool get free =>
      cost != null &&
      cost!.isNotEmpty &&
      cost!.every((price) => price.contextTier == null && price.zero);
}

/// One price of a model in US dollars per million tokens. A tiered price
/// applies from [contextTier] context tokens on.
final class ModelCost {
  ModelCost({
    required this.input,
    required this.output,
    required this.cacheRead,
    required this.cacheWrite,
    this.contextTier,
  }) {
    if ([input, output, cacheRead, cacheWrite].any((v) => !v.isFinite) ||
        [input, output, cacheRead, cacheWrite].any((v) => v < 0) ||
        (contextTier != null && contextTier! < 0)) {
      throw ArgumentError('Model prices must be finite and not negative');
    }
  }
  final double input;
  final double output;
  final double cacheRead;
  final double cacheWrite;
  final int? contextTier;

  bool get zero =>
      input == 0 && output == 0 && cacheRead == 0 && cacheWrite == 0;
}

abstract interface class CatalogFacet {
  Future<List<ModelEntry>> models();
  Future<List<CatalogEntry>> entries(OpenValue<CatalogKind> kind);
}
