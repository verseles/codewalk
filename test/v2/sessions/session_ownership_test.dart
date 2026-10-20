import 'package:codewalk/features/sessions/session_ownership.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 20, 12);

  OwnershipInfo proven(
    OwnershipKind kind, {
    Duration age = Duration.zero,
    DateTime? expiresAt,
  }) => OwnershipInfo.known(
    kind,
    proof: OwnershipProof(
      source: 'adapterObservation',
      observedAt: now.subtract(age),
      expiresAt: expiresAt,
    ),
  );

  test('a fresh proof shows its kind', () {
    for (final kind in OwnershipKind.values.where(
      (kind) => kind != OwnershipKind.unknown,
    )) {
      expect(
        displayedSessionOwnership(proven(kind), now: now, current: true),
        kind,
      );
    }
  });

  test('an unproven ownership shows unknown', () {
    expect(
      displayedSessionOwnership(
        const OwnershipInfo.unknown(reason: 'noProof'),
        now: now,
        current: true,
      ),
      OwnershipKind.unknown,
    );
  });

  test('a stale proof shows unknown', () {
    expect(
      displayedSessionOwnership(
        proven(
          OwnershipKind.liveShared,
          age: sessionOwnershipProofMaxAge + const Duration(seconds: 1),
        ),
        now: now,
        current: true,
      ),
      OwnershipKind.unknown,
    );
  });

  test('an expired proof shows unknown', () {
    expect(
      displayedSessionOwnership(
        proven(
          OwnershipKind.hostOwned,
          expiresAt: now.subtract(const Duration(seconds: 1)),
        ),
        now: now,
        current: true,
      ),
      OwnershipKind.unknown,
    );
  });

  test('a proof observed in the future shows unknown', () {
    expect(
      displayedSessionOwnership(
        proven(
          OwnershipKind.savedHistory,
          age: const Duration(minutes: -1),
        ),
        now: now,
        current: true,
      ),
      OwnershipKind.unknown,
    );
  });

  test('a list that is not the current answer shows unknown', () {
    expect(
      displayedSessionOwnership(
        proven(OwnershipKind.liveShared),
        now: now,
        current: false,
      ),
      OwnershipKind.unknown,
    );
  });

  test('the labels follow the plan vocabulary', () async {
    final l10n = await V2Localizations.delegate.load(const Locale('en'));
    expect(
      sessionOwnershipLabel(l10n, OwnershipKind.liveShared),
      'Live shared',
    );
    expect(
      sessionOwnershipLabel(l10n, OwnershipKind.hostOwned),
      'Owned by this host',
    );
    expect(
      sessionOwnershipLabel(l10n, OwnershipKind.savedHistory),
      'Saved history',
    );
    expect(
      sessionOwnershipLabel(l10n, OwnershipKind.runningElsewhere),
      'Running elsewhere',
    );
    expect(
      sessionOwnershipLabel(l10n, OwnershipKind.unknown),
      'Ownership unknown',
    );
  });

  test('a proof without a source is rejected by the domain', () {
    // The projection also refuses a sourceless proof, because the domain's
    // own check is an assertion, which a release build drops.
    expect(
      () => OwnershipProof(source: '', observedAt: now),
      throwsA(isA<AssertionError>()),
    );
  });

  test('the label deadline is the end of the freshness window', () {
    final delay = ownershipLabelDelay(
      proven(OwnershipKind.liveShared),
      now: now,
    );
    // The proof stays fresh while its age is at most the window, so the
    // label changes one tick later.
    expect(
      delay,
      sessionOwnershipProofMaxAge + const Duration(microseconds: 1),
    );
  });

  test('a proof that expires sooner sets the earlier deadline', () {
    final delay = ownershipLabelDelay(
      proven(
        OwnershipKind.liveShared,
        expiresAt: now.add(const Duration(minutes: 1)),
      ),
      now: now,
    );
    expect(delay, const Duration(minutes: 1));
  });

  test('an expired proof has no deadline left', () {
    expect(
      ownershipLabelDelay(
        proven(
          OwnershipKind.liveShared,
          expiresAt: now.subtract(const Duration(seconds: 1)),
        ),
        now: now,
      ),
      isNull,
    );
  });

  test('a proof without a source has no deadline', () {
    expect(
      ownershipLabelDelay(
        const OwnershipInfo.unknown(reason: 'noProof'),
        now: now,
      ),
      isNull,
    );
  });
}
