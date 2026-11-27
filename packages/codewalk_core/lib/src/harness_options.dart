import 'endpoints.dart';

/// Whether a harness can be chosen when adding a server.
enum HarnessAvailability { available, comingSoon }

/// The ways a harness lets a server be added.
enum HarnessConnectMethod { pairingLink, manualPassword }

/// One harness the add-server flow can offer (#504). Widgets read its
/// availability and methods, never its kind, to decide what to show.
final class HarnessOption {
  const HarnessOption({
    required this.kind,
    required this.displayName,
    required this.availability,
    this.methods = const {},
  });

  /// The key stored in [EndpointProfile.harnessKind].
  final String kind;

  /// The product name, shown as is in every language.
  final String displayName;
  final HarnessAvailability availability;
  final Set<HarnessConnectMethod> methods;

  bool get selectable =>
      availability == HarnessAvailability.available && methods.isNotEmpty;
}

/// The harnesses this build offers, in display order, with the one that
/// profiles saved before the choice existed belong to.
final class HarnessOptions {
  HarnessOptions(Iterable<HarnessOption> options, {required this.defaultKind})
    : options = List.unmodifiable(options) {
    final kinds = this.options.map((option) => option.kind).toSet();
    if (kinds.length != this.options.length ||
        !kinds.every(EndpointProfile.isHarnessKind) ||
        !(resolve(defaultKind)?.selectable ?? false)) {
      throw ArgumentError('Harness options need unique kinds and a default.');
    }
  }

  final List<HarnessOption> options;
  final String defaultKind;

  HarnessOption get defaultOption => resolve(defaultKind)!;

  /// The option for a saved kind; null kinds belong to [defaultKind] and an
  /// unknown kind (for example from a newer build) has no option.
  HarnessOption? resolve(String? kind) {
    final key = kind ?? defaultKind;
    for (final option in options) {
      if (option.kind == key) return option;
    }
    return null;
  }
}
