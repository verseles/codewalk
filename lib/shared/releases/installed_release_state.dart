import 'app_version.dart';
import 'release_catalog.dart';

/// Only v2 installation history is tracked; legacy preferences are never read.
final class InstalledReleaseState {
  const InstalledReleaseState({
    required this.from,
    required this.to,
    required this.pending,
    this.includeFrom = false,
  });

  factory InstalledReleaseState.first(
    AppVersion installed, {
    required bool existing,
  }) => InstalledReleaseState(
    from: installed,
    to: installed,
    pending: existing,
    includeFrom: existing,
  );

  final AppVersion from;
  final AppVersion to;
  final bool pending;
  final bool includeFrom;

  String get key => '$from|$to|$includeFrom';

  InstalledReleaseState observe(AppVersion installed) {
    if (installed.compareTo(to) <= 0) return this;
    return InstalledReleaseState(
      from: pending ? from : to,
      to: installed,
      pending: true,
      includeFrom: pending && includeFrom,
    );
  }

  /// Null means coverage is incomplete, rather than an empty interval.
  List<ReleaseCatalogEntry>? announcements(List<ReleaseCatalogEntry> catalog) {
    if (!pending) return const [];
    if (!catalog.any((entry) => entry.version == to) ||
        !catalog.any((entry) => entry.version == from)) {
      return null;
    }
    return List.unmodifiable(
      catalog.where((entry) {
        final lower = entry.version.compareTo(from);
        return (lower > 0 || (includeFrom && lower == 0)) &&
            entry.version.compareTo(to) <= 0 &&
            entry.announcement != null;
      }),
    );
  }

  InstalledReleaseState acknowledge(String presentedKey) =>
      presentedKey == key && pending
      ? InstalledReleaseState(from: to, to: to, pending: false)
      : this;

  Map<String, Object> toJson() => {
    'schema': 1,
    'from': '$from',
    'to': '$to',
    'pending': pending,
    'includeFrom': includeFrom,
  };

  static InstalledReleaseState? tryParse(Object? raw) {
    if (raw is! Map ||
        raw['schema'] != 1 ||
        raw['from'] is! String ||
        raw['to'] is! String ||
        raw['pending'] is! bool ||
        raw['includeFrom'] is! bool) {
      return null;
    }
    final from = AppVersion.tryParse(raw['from'] as String);
    final to = AppVersion.tryParse(raw['to'] as String);
    if (from == null ||
        to == null ||
        from.major != BigInt.two ||
        to.major != BigInt.two ||
        from.compareTo(to) > 0 ||
        '$from' != raw['from'] ||
        '$to' != raw['to']) {
      return null;
    }
    return InstalledReleaseState(
      from: from,
      to: to,
      pending: raw['pending'] as bool,
      includeFrom: raw['includeFrom'] as bool,
    );
  }
}
