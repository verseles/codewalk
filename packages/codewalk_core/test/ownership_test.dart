import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:test/test.dart';

void main() {
  final observed = DateTime.utc(2026, 10, 4, 6);
  final proof = OwnershipProof(
    source: 'verified adapter observation',
    observedAt: observed,
    expiresAt: observed.add(const Duration(minutes: 5)),
    reference: 'bounded public diagnostic reference',
  );

  test('every known ownership kind requires explicit proof', () {
    for (final kind in OwnershipKind.values.where(
      (k) => k != OwnershipKind.unknown,
    )) {
      final info = OwnershipInfo.known(kind, proof: proof);
      final restored = OwnershipInfo.fromJson(
        jsonDecode(jsonEncode(info.toJson())),
      );
      expect(restored, info);
      expect(restored.hashCode, info.hashCode);
      expect(
        info.effectiveKindAt(observed, maxAge: const Duration(minutes: 1)),
        kind,
      );
      expect(
        () => OwnershipInfo.fromJson({'version': 1, 'kind': kind.name}),
        throwsFormatException,
      );
    }
  });
  test(
    'expired, stale and future observations do not establish current ownership',
    () {
      final info = OwnershipInfo.known(OwnershipKind.liveShared, proof: proof);
      expect(
        info.effectiveKindAt(
          observed.subtract(const Duration(seconds: 1)),
          maxAge: const Duration(minutes: 5),
        ),
        OwnershipKind.unknown,
      );
      expect(
        info.effectiveKindAt(
          observed.add(const Duration(minutes: 2)),
          maxAge: const Duration(minutes: 1),
        ),
        OwnershipKind.unknown,
      );
      expect(
        info.effectiveKindAt(
          observed.add(const Duration(minutes: 5)),
          maxAge: const Duration(hours: 1),
        ),
        OwnershipKind.unknown,
      );
      expect(info.kind, OwnershipKind.liveShared);
      expect(info.proof, proof);
    },
  );
  test('freshness uses an explicit age and exclusive expiry boundary', () {
    expect(proof.isFreshAt(observed, maxAge: Duration.zero), isTrue);
    expect(
      proof.isFreshAt(
        observed.add(const Duration(minutes: 1)),
        maxAge: const Duration(minutes: 1),
      ),
      isTrue,
    );
    expect(
      proof.isFreshAt(
        observed.add(const Duration(minutes: 1, microseconds: 1)),
        maxAge: const Duration(minutes: 1),
      ),
      isFalse,
    );
    expect(
      proof.isFreshAt(proof.expiresAt!, maxAge: const Duration(hours: 1)),
      isFalse,
    );
    expect(
      () => proof.isFreshAt(observed, maxAge: const Duration(seconds: -1)),
      throwsArgumentError,
    );
  });
  test('proof without a lease still requires a caller freshness limit', () {
    final observation = OwnershipProof(
      source: 'history snapshot',
      observedAt: observed,
    );
    expect(
      observation.isFreshAt(
        observed.add(const Duration(seconds: 30)),
        maxAge: const Duration(minutes: 1),
      ),
      isTrue,
    );
    expect(
      observation.isFreshAt(
        observed.add(const Duration(minutes: 2)),
        maxAge: const Duration(minutes: 1),
      ),
      isFalse,
    );
  });
  test(
    'unknown ownership retains reason and never gains topology from an ID',
    () {
      const unknown = OwnershipInfo.unknown(
        reason: 'No verified attach evidence',
      );
      expect(OwnershipInfo.fromJson(unknown.toJson()), unknown);
      expect(unknown.proof, isNull);
      expect(
        unknown.effectiveKindAt(observed, maxAge: const Duration(days: 1)),
        OwnershipKind.unknown,
      );
      expect(
        () => unknown.effectiveKindAt(
          observed,
          maxAge: const Duration(seconds: -1),
        ),
        throwsArgumentError,
      );
    },
  );
  test('future ownership values retain their raw discriminator safely', () {
    final unknown = OwnershipInfo.fromJson({
      'version': 1,
      'kind': 'future-owner',
    });
    expect(unknown.kind, OwnershipKind.unknown);
    expect(unknown.rawKind, 'future-owner');
    expect(unknown.unknownReason, isNotEmpty);
    expect(
      OwnershipInfo.fromJson(jsonDecode(jsonEncode(unknown.toJson()))),
      unknown,
    );
    expect(
      unknown.effectiveKindAt(observed, maxAge: const Duration(days: 1)),
      OwnershipKind.unknown,
    );
  });
  test('proof instant equality is independent of serialization timezone', () {
    final json = proof.toJson();
    final shifted = OwnershipProof.fromJson({
      ...json,
      'observedAt': '2026-10-04T07:00:00+01:00',
    });
    expect(shifted, proof);
    expect(shifted.hashCode, proof.hashCode);
  });
  test('malformed proof fields and unsupported versions fail at runtime', () {
    for (final (field, bad) in <(String, Object?)>[
      ('source', ''),
      ('source', 1),
      ('observedAt', null),
      ('observedAt', 'not-a-date'),
      ('observedAt', '2026-10-04T06:00:00'),
      ('observedAt', '2026-02-31T06:00:00Z'),
      ('observedAt', '2026-10-04T25:00:00Z'),
      ('observedAt', '2026-10-04T06:00:00+01:99'),
      ('expiresAt', '2026-10-04T05:59:59Z'),
      ('reference', ''),
      ('version', 2),
    ]) {
      expect(
        () => OwnershipProof.fromJson({...proof.toJson(), field: bad}),
        throwsFormatException,
      );
    }
    expect(
      () => OwnershipInfo.fromJson({
        'version': 1,
        'kind': 'unknown',
        'reason': '',
      }),
      throwsFormatException,
    );
    expect(
      () => OwnershipInfo.fromJson({'version': 1, 'kind': ''}),
      throwsFormatException,
    );
    expect(
      () => OwnershipInfo.fromJson({'version': 2, 'kind': 'future'}),
      throwsFormatException,
    );
  });
}
