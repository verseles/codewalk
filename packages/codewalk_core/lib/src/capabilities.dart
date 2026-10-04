import 'errors.dart';
import 'identity.dart';
import 'ownership.dart';
import 'values.dart';

enum Support { native, host, extension, experimental, unavailable, unknown }

final class Capability {
  Capability({
    required this.support,
    this.verified = false,
    this.reason,
    this.semantics,
    Map<String, Object?> constraints = const {},
  }) : constraints = CanonicalValue(constraints);
  final OpenValue<Support> support;
  final bool verified;
  final String? reason;
  final String? semantics;
  final CanonicalValue constraints;
  bool get isAvailable =>
      verified &&
      switch (support.known) {
        Support.native ||
        Support.host ||
        Support.extension ||
        Support.experimental => true,
        _ => false,
      };
}

/// Each required restriction must be affirmatively known; null is unavailable.
/// External authority proof is used for non-session owners, not ID inference.
final class ScopedCapabilityEvidence {
  ScopedCapabilityEvidence({
    required this.owner,
    required String connectedVersion,
    this.ownership,
    this.authorityProof,
  }) : connectedVersion = requireText(connectedVersion);
  final DomainOwner owner;
  final String connectedVersion;
  final OwnershipInfo? ownership;
  final OwnershipProof? authorityProof;
}

final class CapabilityContext {
  CapabilityContext({
    required this.owner,
    required String connectedVersion,
    required this.evidence,
    required this.now,
    required this.maxProofAge,
    this.mutating = true,
    this.negotiated,
    this.modelAllowed,
    this.policyAllowed,
    this.platformAllowed,
    this.stateAllowed,
  }) : connectedVersion = requireText(connectedVersion);
  final DomainOwner owner;
  final String connectedVersion;
  final ScopedCapabilityEvidence evidence;
  final DateTime now;
  final Duration maxProofAge;
  final bool mutating;
  final bool? negotiated;
  final bool? modelAllowed;
  final bool? policyAllowed;
  final bool? platformAllowed;
  final bool? stateAllowed;

  String? get denialReason {
    if (maxProofAge.isNegative) throw ArgumentError('Negative proof age');
    if (!owner.isKnown || owner.harness == null) return 'unknownOwner';
    if (!owner.hasSameScope(evidence.owner) ||
        connectedVersion != evidence.connectedVersion) {
      return 'evidenceScopeMismatch';
    }
    if (owner is SessionOwner) {
      final kind = evidence.ownership?.effectiveKindAt(
        now,
        maxAge: maxProofAge,
      );
      if (kind == null ||
          kind == OwnershipKind.unknown ||
          (mutating &&
              kind != OwnershipKind.liveShared &&
              kind != OwnershipKind.hostOwned)) {
        return 'ownershipUnavailable';
      }
    } else if (evidence.authorityProof?.isFreshAt(now, maxAge: maxProofAge) !=
        true) {
      return 'authorityUnverified';
    }
    if (negotiated != true) return 'featureUnverified';
    if (modelAllowed != true) return 'modelUnavailable';
    if (policyAllowed != true) return 'policyUnavailable';
    if (platformAllowed != true) return 'platformUnavailable';
    if (stateAllowed != true) return 'stateUnavailable';
    return null;
  }
}

final class CapabilitySet {
  CapabilitySet(
    Map<String, Capability> values, {
    required this.harness,
    required String connectedVersion,
    this.scope,
  }) : values = immutableMap(values),
       connectedVersion = requireText(connectedVersion) {
    if (scope != null && scope!.harness != harness) {
      throw ArgumentError('Capability scope belongs to another harness');
    }
    for (final name in this.values.keys) {
      requireText(name, 'capability');
    }
  }
  final HarnessRef harness;
  final String connectedVersion;
  final DomainOwner? scope;
  final Map<String, Capability> values;
  Capability? operator [](String name) => values[name];

  void requireAvailable(String name, {required CapabilityContext context}) {
    if (context.owner.harness != harness ||
        context.connectedVersion != connectedVersion ||
        (scope != null && !scope!.hasSameScope(context.owner))) {
      throw CapabilityUnavailable(name, reason: 'capabilityScopeMismatch');
    }
    final capability = values[name];
    final denial = capability?.isAvailable == true
        ? context.denialReason
        : capability?.reason ?? 'capabilityUnverified';
    if (denial != null) throw CapabilityUnavailable(name, reason: denial);
  }

  /// Calls the supplied boundary only after the complete capability guard.
  Future<T> invoke<T>(
    String name, {
    required CapabilityContext context,
    required Future<T> Function() mutation,
  }) {
    if (!context.mutating) {
      throw CapabilityUnavailable(name, reason: 'mutationContextRequired');
    }
    requireAvailable(name, context: context);
    return mutation();
  }
}
