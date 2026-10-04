enum MigrationCategory {
  settings,
  profiles,
  credentials,
  drafts,
  cannedAnswers,
  orphanFiles,
  source,
}

enum MigrationPendingReason {
  malformed,
  oversized,
  sourceUnavailable,
  destinationFailed,
  unsupportedCredential,
  credentialOriginMismatch,
  ephemeralCredential,
  attachmentReviewRequired,
  unmappedDraft,
  orphanPayload,
  existingDestination,
  unsupportedSettings,
}

final class MigrationPendingItem {
  const MigrationPendingItem({
    required this.id,
    required this.category,
    required this.reason,
  });
  final String id;
  final MigrationCategory category;
  final MigrationPendingReason reason;

  Map<String, Object> toJson() => {
    'id': id,
    'category': category.name,
    'reason': reason.name,
  };
}

/// Only opaque IDs/counts/codes: no text, URL, path, attachment or credential.
final class MigrationReport {
  MigrationReport({
    required Map<String, int> counts,
    required List<MigrationPendingItem> pending,
  }) : counts = Map.unmodifiable(counts),
       pending = List.unmodifiable(pending);

  final Map<String, int> counts;
  final List<MigrationPendingItem> pending;

  static const externalPrerequisites = [
    'exclusive-import-before-consumers',
    'android-pre-engine-source-preservation',
    'real-v1.266-installed-upgrade',
    'settings-about-migration-ui',
  ];

  Map<String, Object> toJson() => {
    'version': 1,
    'status': 'local-partial',
    'allRequirementsAccepted': false,
    'counts': counts,
    'pending': pending.map((item) => item.toJson()).toList(),
    'externalPrerequisites': externalPrerequisites,
  };
}

enum MigrationFailure {
  exclusivityRequired,
  invalidJournal,
  checkpointFailed,
  reportFailed,
  itemLimit,
}

final class MigrationException implements Exception {
  const MigrationException(this.failure);
  final MigrationFailure failure;

  @override
  String toString() => 'MigrationException(${failure.name})';
}
