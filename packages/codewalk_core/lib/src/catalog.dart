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
    this.metadata,
  }) : id = requireText(id),
       providerId = requireText(providerId),
       inputModalities = immutableMap(inputModalities) {
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
  final CanonicalValue? metadata;
}

abstract interface class CatalogFacet {
  Future<List<ModelEntry>> models();
  Future<List<CatalogEntry>> entries(OpenValue<CatalogKind> kind);
}
