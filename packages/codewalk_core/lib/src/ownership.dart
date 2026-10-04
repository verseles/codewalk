/// Ownership describes evidence about a session, not permission to mutate it.
enum OwnershipKind {
  liveShared,
  hostOwned,
  savedHistory,
  runningElsewhere,
  unknown,
}

/// An adapter-supplied observation. Core neither verifies topology nor performs
/// I/O; the caller supplies the clock and its explicit freshness policy.
final class OwnershipProof {
  const OwnershipProof({
    required this.source,
    required this.observedAt,
    this.expiresAt,
    this.reference,
  }) : assert(source != '');

  factory OwnershipProof.fromJson(Object? value) {
    final json = _object(value, 'OwnershipProof');
    final observedAt = _instant(json['observedAt'], 'observedAt');
    final expiresAt = json['expiresAt'] == null
        ? null
        : _instant(json['expiresAt'], 'expiresAt');
    if (expiresAt != null && expiresAt.isBefore(observedAt)) {
      throw const FormatException('Ownership proof expires before observation');
    }
    return OwnershipProof(
      source: _string(json['source'], 'source'),
      observedAt: observedAt,
      expiresAt: expiresAt,
      reference: json['reference'] == null
          ? null
          : _string(json['reference'], 'reference'),
    );
  }

  final String source;
  final DateTime observedAt;
  final DateTime? expiresAt;
  final String? reference;

  bool isFreshAt(DateTime now, {required Duration maxAge}) {
    if (maxAge.isNegative) {
      throw ArgumentError.value(maxAge, 'maxAge', 'Must not be negative');
    }
    return !now.isBefore(observedAt) &&
        now.difference(observedAt) <= maxAge &&
        (expiresAt == null || now.isBefore(expiresAt!));
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'source': source,
    'observedAt': observedAt.toUtc().toIso8601String(),
    if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().toIso8601String(),
    if (reference != null) 'reference': reference,
  };

  @override
  bool operator ==(Object other) =>
      other is OwnershipProof &&
      source == other.source &&
      observedAt.isAtSameMomentAs(other.observedAt) &&
      expiresAt?.microsecondsSinceEpoch ==
          other.expiresAt?.microsecondsSinceEpoch &&
      reference == other.reference;

  @override
  int get hashCode => Object.hash(
    source,
    observedAt.microsecondsSinceEpoch,
    expiresAt?.microsecondsSinceEpoch,
    reference,
  );
}

final class OwnershipInfo {
  const OwnershipInfo.known(this.kind, {required OwnershipProof this.proof})
    : assert(kind != OwnershipKind.unknown),
      unknownReason = null,
      rawKind = null;

  const OwnershipInfo.unknown({required String reason, this.rawKind})
    : assert(reason != ''),
      kind = OwnershipKind.unknown,
      proof = null,
      unknownReason = reason;

  factory OwnershipInfo.fromJson(Object? value) {
    final json = _object(value, 'OwnershipInfo');
    final raw = _string(json['kind'], 'kind');
    final kind = switch (raw) {
      'liveShared' => OwnershipKind.liveShared,
      'hostOwned' => OwnershipKind.hostOwned,
      'savedHistory' => OwnershipKind.savedHistory,
      'runningElsewhere' => OwnershipKind.runningElsewhere,
      'unknown' => OwnershipKind.unknown,
      _ => null,
    };
    if (kind == null) {
      return OwnershipInfo.unknown(
        reason: json['reason'] == null
            ? 'unrecognizedOwnershipKind'
            : _string(json['reason'], 'reason'),
        rawKind: raw,
      );
    }
    if (kind == OwnershipKind.unknown) {
      return OwnershipInfo.unknown(
        reason: _string(json['reason'], 'reason'),
        rawKind: json['rawKind'] == null
            ? null
            : _string(json['rawKind'], 'rawKind'),
      );
    }
    return OwnershipInfo.known(
      kind,
      proof: OwnershipProof.fromJson(json['proof']),
    );
  }

  final OwnershipKind kind;
  final OwnershipProof? proof;
  final String? unknownReason;

  /// Unrecognized canonical values remain diagnostic data, never live authority.
  final String? rawKind;

  OwnershipKind effectiveKindAt(DateTime now, {required Duration maxAge}) {
    if (maxAge.isNegative) {
      throw ArgumentError.value(maxAge, 'maxAge', 'Must not be negative');
    }
    return proof?.isFreshAt(now, maxAge: maxAge) == true
        ? kind
        : OwnershipKind.unknown;
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'kind': kind.name,
    if (proof != null) 'proof': proof!.toJson(),
    if (unknownReason != null) 'reason': unknownReason,
    if (rawKind != null) 'rawKind': rawKind,
  };

  @override
  bool operator ==(Object other) =>
      other is OwnershipInfo &&
      kind == other.kind &&
      proof == other.proof &&
      unknownReason == other.unknownReason &&
      rawKind == other.rawKind;

  @override
  int get hashCode => Object.hash(kind, proof, unknownReason, rawKind);
}

String _string(Object? value, String field) {
  if (value is! String || value.isEmpty) {
    throw FormatException('$field must be a nonempty string');
  }
  return value;
}

Map<String, Object?> _object(Object? value, String type) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException('$type must be an object');
  }
  final json = Map<String, Object?>.from(value);
  if (json['version'] is! int || json['version'] != 1) {
    throw FormatException('Unsupported $type version');
  }
  return json;
}

DateTime _instant(Object? value, String field) {
  final text = _string(value, field);
  final parts = RegExp(
    r'^([+-]?\d{4,6})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$',
  ).firstMatch(text);
  final instant = DateTime.tryParse(text);
  if (parts == null || instant == null) {
    throw FormatException('$field must include an ISO-8601 time zone');
  }
  final year = int.parse(parts[1]!);
  final month = int.parse(parts[2]!);
  final day = int.parse(parts[3]!);
  final leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
  final days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  final zone = parts[7]!;
  if (month < 1 ||
      month > 12 ||
      day < 1 ||
      day > days[month - 1] ||
      int.parse(parts[4]!) > 23 ||
      int.parse(parts[5]!) > 59 ||
      int.parse(parts[6]!) > 59 ||
      (zone != 'Z' &&
          (int.parse(zone.substring(1, 3)) > 23 ||
              int.parse(zone.substring(4, 6)) > 59))) {
    throw FormatException('$field contains an invalid date or time');
  }
  return instant.toUtc();
}
