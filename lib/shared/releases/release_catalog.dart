import 'app_version.dart';
import 'release_archive.dart';

/// Metadata from a complete public release listing, independent of the
/// currently selected update channel and platform.
final class ReleaseCatalogEntry {
  const ReleaseCatalogEntry({
    required this.tag,
    required this.version,
    required this.publishedAt,
    required this.notes,
    required this.announcement,
    required this.body,
  });

  final String tag;
  final AppVersion version;
  final DateTime publishedAt;
  final String notes;
  final String? announcement;
  final String body;
}

/// Parses the complete v2 release catalog without accepting drafts or
/// ambiguous tags. A malformed eligible release invalidates the snapshot.
List<ReleaseCatalogEntry> parseReleaseCatalog(Object? source) {
  if (source is! List) throw const FormatException('Invalid release catalog');
  final entries = <ReleaseCatalogEntry>[];
  final seen = <String>{};
  final betaTag = RegExp(r'^v2\.0\.0-beta\.[1-9]\d*$');
  for (final item in source) {
    if (item is! Map || item['draft'] is! bool || item['tag_name'] is! String) {
      throw const FormatException('Invalid release record');
    }
    if (item['draft'] == true) continue;
    final tag = item['tag_name'];
    if (tag is! String || !tag.startsWith('v')) continue;
    final version = AppVersion.tryParse(tag.substring(1));
    if (version == null || version.major != BigInt.two || 'v$version' != tag) {
      continue;
    }
    final prerelease = item['prerelease'];
    if (prerelease is! bool || prerelease != version.isPrerelease) {
      throw const FormatException('Invalid release flag');
    }
    if (prerelease && !betaTag.hasMatch(tag)) {
      continue;
    }
    final rawDate = item['published_at'];
    final body = item['body'];
    final date = rawDate is String ? DateTime.tryParse(rawDate) : null;
    if (!seen.add(tag) || date == null || (body != null && body is! String)) {
      throw const FormatException('Invalid release metadata');
    }
    final parsed = parseReleaseAnnouncement(body as String? ?? '');
    entries.add(
      ReleaseCatalogEntry(
        tag: tag,
        version: version,
        publishedAt: date,
        notes: parsed.notes,
        announcement: parsed.announcement,
        body: body ?? '',
      ),
    );
  }
  entries.sort((a, b) => b.version.compareTo(a.version));
  return List.unmodifiable(entries);
}

/// Completes [fresh], read from the listing down to a release [saved] holds,
/// with the older entries of [saved], a catalog that was complete when it was
/// saved. Fresh entries win.
List<ReleaseCatalogEntry> mergeReleaseCatalog(
  List<ReleaseCatalogEntry> fresh,
  List<ReleaseCatalogEntry> saved,
) {
  final tags = {for (final entry in fresh) entry.tag};
  final merged = [
    ...fresh,
    for (final entry in saved)
      if (!tags.contains(entry.tag)) entry,
  ]..sort((a, b) => b.version.compareTo(a.version));
  return List.unmodifiable(merged);
}

List<Map<String, Object>> encodeReleaseCatalog(
  List<ReleaseCatalogEntry> entries,
) => [
  for (final entry in entries)
    {
      'tag_name': entry.tag,
      'draft': false,
      'prerelease': entry.version.isPrerelease,
      'published_at': entry.publishedAt.toUtc().toIso8601String(),
      'body': entry.body,
    },
];
