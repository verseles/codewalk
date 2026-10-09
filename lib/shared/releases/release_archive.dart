final class ReleaseVersion implements Comparable<ReleaseVersion> {
  ReleaseVersion._(this.major, this.minor, this.patch);

  factory ReleaseVersion.parse(String text) {
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(text)) {
      throw const FormatException('Invalid stable version');
    }
    final parts = text.split('.').map(BigInt.parse).toList();
    return ReleaseVersion._(parts[0], parts[1], parts[2]);
  }

  final BigInt major;
  final BigInt minor;
  final BigInt patch;

  @override
  int compareTo(ReleaseVersion other) {
    final first = major.compareTo(other.major);
    if (first != 0) return first;
    final second = minor.compareTo(other.minor);
    return second != 0 ? second : patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';

  @override
  bool operator ==(Object other) =>
      other is ReleaseVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);
}

final class ReleaseArchiveEntry {
  const ReleaseArchiveEntry({
    required this.version,
    required this.date,
    required this.notes,
    this.announcement,
  });

  final ReleaseVersion version;
  final String date;
  final String notes;
  final String? announcement;
}

/// Pure v2 parser. Markdown is kept as selectable source, not executed/rendered.
List<ReleaseArchiveEntry> parseReleaseArchive(String source) {
  final lines = source.replaceFirst(RegExp(r'^\uFEFF'), '').split('\n');
  final heading = RegExp(r'^## v(\d+\.\d+\.\d+) - (\d{4}-\d{2}-\d{2})$');
  final entries = <ReleaseArchiveEntry>[];
  final versions = <ReleaseVersion>{};
  ReleaseVersion? version;
  String? date;
  final body = <String>[];
  void finish() {
    final current = version;
    if (current == null) return;
    final text = body.join('\n').trim();
    if (text.isEmpty) throw const FormatException('Empty release section');
    final block = _announcement(text);
    if (block.notes.isEmpty && block.announcement == null) {
      throw const FormatException('Empty release section');
    }
    entries.add(
      ReleaseArchiveEntry(
        version: current,
        date: date!,
        notes: block.notes,
        announcement: block.announcement,
      ),
    );
    body.clear();
  }

  for (final raw in lines) {
    final line = raw.trimRight();
    if (RegExp(r'^##(?:\s|$)').hasMatch(line)) {
      finish();
      final match = heading.firstMatch(line);
      if (match == null) throw const FormatException('Invalid release heading');
      version = ReleaseVersion.parse(match.group(1)!);
      date = match.group(2)!;
      final parsed = DateTime.tryParse(date);
      if (!versions.add(version) ||
          parsed == null ||
          parsed.toIso8601String().substring(0, 10) != date) {
        throw const FormatException('Invalid or duplicate release');
      }
    } else if (version != null) {
      body.add(line);
    }
  }
  finish();
  if (entries.isEmpty) throw const FormatException('No release sections');
  entries.sort((a, b) => b.version.compareTo(a.version));
  return List.unmodifiable(entries);
}

({String? announcement, String notes}) _announcement(String body) {
  final lines = body.split('\n');
  var index = 0;
  while (index < lines.length && lines[index].trim().isEmpty) {
    index++;
  }
  if (index == lines.length ||
      !lines[index].trimLeft().startsWith('>') ||
      !lines[index].contains('📣')) {
    return (announcement: null, notes: body);
  }
  final announcement = <String>[];
  while (index < lines.length && lines[index].trimLeft().startsWith('>')) {
    announcement.add(
      lines[index]
          .trimLeft()
          .replaceFirst(RegExp(r'^>\s?'), '')
          .replaceFirst('📣', '')
          .trim(),
    );
    index++;
  }
  final text = announcement.where((line) => line.isNotEmpty).join('\n').trim();
  return (
    announcement: text.isEmpty ? null : text,
    notes: lines.sublist(index).join('\n').trim(),
  );
}
