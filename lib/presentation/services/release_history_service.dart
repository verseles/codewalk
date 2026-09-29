import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../data/datasources/app_local_datasource.dart';
import 'update_check_service.dart';

class ReleaseHistoryEntry {
  const ReleaseHistoryEntry({
    required this.version,
    required this.date,
    required this.notes,
    this.announcement,
  });

  final Semver version;
  final String date;
  final String notes;
  final String? announcement;
}

/// A changelog is an archive, not a list of arbitrary Markdown blockquotes.
/// Reject broken boundaries rather than assigning notes to the wrong version.
List<ReleaseHistoryEntry> parseReleaseHistory(String source) {
  final lines = source.replaceFirst(RegExp(r'^\uFEFF'), '').split('\n');
  final heading = RegExp(r'^## v(\d+\.\d+\.\d+) - (\d{4}-\d{2}-\d{2})$');
  final entries = <ReleaseHistoryEntry>[];
  final versions = <String>{};
  Semver? version;
  String? date;
  final body = <String>[];
  void finish() {
    if (version == null) return;
    final text = body.join('\n').trim();
    if (text.isEmpty) throw const FormatException('Empty release section');
    entries.add(
      ReleaseHistoryEntry(
        version: version,
        date: date!,
        announcement: parseReleaseAnnouncement(text),
        notes: stripReleaseAnnouncement(text) ?? '',
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
      version = Semver.tryParse(match.group(1)!);
      date = match.group(2)!;
      final parsedDate = DateTime.tryParse(date);
      if (version == null ||
          !versions.add(version.toString()) ||
          parsedDate == null ||
          parsedDate.toIso8601String().substring(0, 10) != date) {
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

class ReleaseHistorySnapshot {
  const ReleaseHistorySnapshot({
    this.entries = const [],
    this.fetchedAt,
    this.failed = false,
  });

  final List<ReleaseHistoryEntry> entries;
  final DateTime? fetchedAt;
  final bool failed;
  bool contains(Semver version) => entries.any((e) => e.version == version);
}

/// Fetches the canonical archive independently of update/installation checks.
class ReleaseHistoryService {
  ReleaseHistoryService({required AppLocalDataSource localDataSource, Dio? dio})
    : _local = localDataSource,
      _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));

  static const url =
      'https://raw.githubusercontent.com/verseles/codewalk/main/CHANGELOG.md';
  static const maxBytes = 256 * 1024;
  final AppLocalDataSource _local;
  final Dio _dio;
  ReleaseHistorySnapshot? _cached;
  Future<ReleaseHistorySnapshot>? _inFlight;
  CancelToken? _cancelToken;
  int _generation = 0;

  Future<ReleaseHistorySnapshot> load({bool forceRefresh = false}) {
    return _inFlight ??= _load(
      forceRefresh,
    ).whenComplete(() => _inFlight = null);
  }

  Future<ReleaseHistorySnapshot> _load(bool forceRefresh) async {
    final generation = _generation;
    try {
      if (_cached == null) {
        final stored = await _local.getReleaseHistoryCache();
        if (generation != _generation) return const ReleaseHistorySnapshot();
        if (stored != null && stored.length <= 512 * 1024) {
          try {
            final json = jsonDecode(stored) as Map<String, dynamic>;
            final raw = json['body'] as String;
            if (utf8.encode(raw).length <= maxBytes) {
              _cached = ReleaseHistorySnapshot(
                entries: parseReleaseHistory(raw),
                fetchedAt: DateTime.parse(json['fetchedAt'] as String),
              );
            }
          } catch (_) {
            // A corrupt cache must not prevent recovering from the source.
          }
        }
      }
      final cachedAt = _cached?.fetchedAt;
      if (!forceRefresh &&
          cachedAt != null &&
          DateTime.now().difference(cachedAt).inSeconds >= 0 &&
          DateTime.now().difference(cachedAt) < const Duration(hours: 1)) {
        return _cached!;
      }
      final token = CancelToken();
      _cancelToken = token;
      final response = await _dio.get<ResponseBody>(
        url,
        cancelToken: token,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      final bytes = <int>[];
      await for (final chunk in response.data!.stream.timeout(
        const Duration(seconds: 10),
      )) {
        if (bytes.length + chunk.length > maxBytes) {
          token.cancel('Changelog exceeds size limit');
          throw const FormatException('Changelog exceeds size limit');
        }
        bytes.addAll(chunk);
      }
      final body = utf8.decode(bytes);
      final entries = parseReleaseHistory(body);
      // Do not overwrite a complete archive with a shortened response.
      final versions = entries.map((e) => e.version).toSet();
      if (_cached?.entries.any((e) => !versions.contains(e.version)) ?? false) {
        throw const FormatException('Changelog lost cached releases');
      }
      final now = DateTime.now().toUtc();
      final snapshot = ReleaseHistorySnapshot(entries: entries, fetchedAt: now);
      if (generation != _generation) return const ReleaseHistorySnapshot();
      await _local.saveReleaseHistoryCache(
        jsonEncode({'body': body, 'fetchedAt': now.toIso8601String()}),
      );
      if (generation != _generation) return const ReleaseHistorySnapshot();
      _cached = snapshot;
      return snapshot;
    } catch (_) {
      if (generation != _generation) return const ReleaseHistorySnapshot();
      return ReleaseHistorySnapshot(
        entries: _cached?.entries ?? const [],
        fetchedAt: _cached?.fetchedAt,
        failed: true,
      );
    } finally {
      _cancelToken = null;
    }
  }

  /// Drain writes before a caller clears preferences during app reset.
  Future<void> reset() async {
    _generation++;
    _cancelToken?.cancel('Release history reset');
    await _inFlight;
    _cached = null;
  }
}
