import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/logging/app_logger.dart';

class Semver implements Comparable<Semver> {
  const Semver(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  static Semver? tryParse(String input) {
    var cleaned = input.trim().replaceFirst(RegExp(r'^v'), '');
    // Strip prerelease/build metadata before splitting
    final dashIndex = cleaned.indexOf('-');
    if (dashIndex != -1) cleaned = cleaned.substring(0, dashIndex);
    final plusIndex = cleaned.indexOf('+');
    if (plusIndex != -1) cleaned = cleaned.substring(0, plusIndex);
    final parts = cleaned.split('.');
    if (parts.length != 3) return null;
    final major = int.tryParse(parts[0]);
    final minor = int.tryParse(parts[1]);
    final patch = int.tryParse(parts[2]);
    if (major == null || minor == null || patch == null) return null;
    return Semver(major, minor, patch);
  }

  bool isNewerThan(Semver other) => compareTo(other) > 0;

  @override
  int compareTo(Semver other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';

  @override
  bool operator ==(Object other) =>
      other is Semver &&
      major == other.major &&
      minor == other.minor &&
      patch == other.patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);
}

final RegExp _stableReleaseTagPattern = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$');

/// Parses a stable release tag: `vMAJOR.MINOR.PATCH` or `MAJOR.MINOR.PATCH`
/// with integer parts and no suffix.
///
/// Unlike [Semver.tryParse], prerelease, build and cohort suffixes such as
/// `v2.0.0-beta.1` or `v1.266.0-native.1` are rejected instead of stripped,
/// so they can never be offered as ordinary updates.
Semver? parseStableReleaseTag(String tag) {
  final match = _stableReleaseTagPattern.firstMatch(tag);
  if (match == null) return null;
  final major = int.tryParse(match.group(1)!);
  final minor = int.tryParse(match.group(2)!);
  final patch = int.tryParse(match.group(3)!);
  if (major == null || minor == null || patch == null) return null;
  return Semver(major, minor, patch);
}

/// Which releases the v1 updater may offer.
///
/// [stable] follows the repository's latest stable release and asks through
/// the major-update gate before crossing to CodeWalk 2. [v1] only ever
/// offers stable `v1.*` releases.
enum UpdateChannel {
  stable,
  v1;

  /// Missing or unknown stored values fall back to [stable]; the gate still
  /// asks before any major update, so this is the safe default.
  static UpdateChannel fromStorage(String? value) =>
      UpdateChannel.values.asNameMap()[value] ?? UpdateChannel.stable;
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.latestVersion,
    this.releaseTag,
    this.releaseUrl,
    this.releaseNotes,
    this.announcement,
    this.apkUrl,
    required this.isNewer,
    this.isMajorUpgrade = false,
  });

  final String latestVersion;
  // The release's original `tag_name`, never rebuilt from [latestVersion].
  final String? releaseTag;
  final String? releaseUrl;
  final String? releaseNotes;
  // Optional informal announcement extracted from the leading `> 📣` block
  // of the release body. Shown verbatim in the author's language.
  final String? announcement;
  // Direct download URL for the .apk asset from the GitHub release, if present.
  final String? apkUrl;
  final bool isNewer;
  // True when the release's major version is above the installed one; such a
  // release goes through the major-update gate, never the ordinary prompt.
  final bool isMajorUpgrade;
}

/// Extracts the leading `> 📣 ...` announcement block from a release body.
///
/// The block starts at the first `>` line containing `📣` (after blank
/// lines) and absorbs following `>` continuation lines, with or without the
/// emoji. Anything else — including a `📣` in the middle of the notes —
/// is ignored and yields null.
String? parseReleaseAnnouncement(String? body) {
  final block = _announcementBlock(body);
  return block.text;
}

bool _isAnnouncementStart(String trimmedLeft) {
  return trimmedLeft.startsWith('>') && trimmedLeft.contains('📣');
}

/// Shared boundary scan: returns how many leading lines form the
/// announcement block and its cleaned text (null when there is no block).
({int count, String? text}) _announcementBlock(String? body) {
  if (body == null) return (count: 0, text: null);
  final lines = body.split('\n');
  var index = 0;
  while (index < lines.length && lines[index].trim().isEmpty) {
    index++;
  }
  if (index >= lines.length || !_isAnnouncementStart(lines[index].trimLeft())) {
    return (count: 0, text: null);
  }
  final buffer = <String>[];
  final start = index;
  while (index < lines.length) {
    final trimmed = lines[index].trimLeft();
    if (!trimmed.startsWith('>')) break;
    buffer.add(
      trimmed.replaceFirst(RegExp(r'^>\s?'), '').replaceFirst('📣', '').trim(),
    );
    index++;
  }
  final text = buffer.where((line) => line.isNotEmpty).join('\n').trim();
  return (count: index - start, text: text.isEmpty ? null : text);
}

/// Returns [body] without its leading announcement block, if any.
String? stripReleaseAnnouncement(String? body) {
  if (body == null) return null;
  final block = _announcementBlock(body);
  if (block.count == 0) return body;
  final lines = body.split('\n');
  var drop = 0;
  while (drop < lines.length && lines[drop].trim().isEmpty) {
    drop++;
  }
  drop += block.count;
  while (drop < lines.length && lines[drop].trim().isEmpty) {
    drop++;
  }
  final rest = lines.sublist(drop).join('\n').trim();
  return rest.isEmpty ? null : rest;
}

class UpdateCheckService {
  UpdateCheckService({Dio? dio}) : _dio = dio;

  final Dio? _dio;

  static const String _repoOwner = 'verseles';
  static const String _repoName = 'codewalk';
  static const String _defaultApiBase = 'https://api.github.com';
  static const String _debugApiBase = String.fromEnvironment(
    'CODEWALK_UPDATE_API_BASE',
  );
  static const Duration _cooldown = Duration(hours: 1);
  static const int _legacyMajor = 1;
  static const int _releasesPerPage = 100;

  /// Upper bound of release-list pages the v1-only selector reads.
  static const int maxV1ReleasePages = 10;

  final Map<String, _CachedCheck> _cache = <String, _CachedCheck>{};
  UpdateCheckResult? _cachedResult;

  UpdateCheckResult? get cachedResult => _cachedResult;

  /// Debug builds may point update checks at a local mock API through
  /// `--dart-define=CODEWALK_UPDATE_API_BASE=...`; release builds always use
  /// the GitHub API.
  @visibleForTesting
  static String resolveApiBase({
    required bool debugMode,
    String override = _debugApiBase,
  }) {
    final trimmed = override.trim();
    if (!debugMode || trimmed.isEmpty) return _defaultApiBase;
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  String get _repoApi =>
      '${resolveApiBase(debugMode: kDebugMode)}/repos/$_repoOwner/$_repoName';

  /// Checks the repository's latest stable release.
  Future<UpdateCheckResult?> check(
    String currentVersion, {
    bool ignoreCooldown = false,
  }) {
    return _checkCached(
      UpdateChannel.stable,
      currentVersion,
      ignoreCooldown: ignoreCooldown,
      fetch: _fetchLatest,
    );
  }

  /// Selects the highest stable `v1.*` release from the paginated releases
  /// list. Fails closed (null) instead of falling back to `/releases/latest`.
  Future<UpdateCheckResult?> checkV1Only(
    String currentVersion, {
    bool ignoreCooldown = false,
  }) {
    return _checkCached(
      UpdateChannel.v1,
      currentVersion,
      ignoreCooldown: ignoreCooldown,
      fetch: _fetchHighestV1,
    );
  }

  Future<UpdateCheckResult?> _checkCached(
    UpdateChannel channel,
    String currentVersion, {
    required bool ignoreCooldown,
    required Future<UpdateCheckResult?> Function(Dio dio, Semver current) fetch,
  }) async {
    final key = '${channel.name}|$currentVersion';
    final cached = _cache[key];
    if (!ignoreCooldown &&
        cached != null &&
        DateTime.now().difference(cached.checkedAt) < _cooldown) {
      return cached.result;
    }

    try {
      final currentSemver = Semver.tryParse(currentVersion);
      if (currentSemver == null) return null;

      final result = await fetch(_dio ?? Dio(), currentSemver);
      if (result == null) return null;

      _cache[key] = _CachedCheck(DateTime.now(), result);
      _cachedResult = result;
      return result;
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Update check failed',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<Object?> _get(
    Dio dio,
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await dio.get<Object?>(
      '$_repoApi$path',
      queryParameters: queryParameters,
      options: Options(
        headers: <String, String>{
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'CodeWalk',
        },
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 5),
      ),
    );
    return response.data;
  }

  Future<UpdateCheckResult?> _fetchLatest(Dio dio, Semver current) async {
    final data = await _get(dio, '/releases/latest');
    if (data is! Map<String, dynamic>) return null;
    return _resultFromRelease(data, current);
  }

  Future<UpdateCheckResult?> _fetchHighestV1(Dio dio, Semver current) async {
    Map<String, dynamic>? best;
    Semver? bestVersion;
    for (var page = 1; page <= maxV1ReleasePages; page++) {
      final data = await _get(
        dio,
        '/releases',
        queryParameters: <String, dynamic>{
          'per_page': _releasesPerPage,
          'page': page,
        },
      );
      if (data is! List) return null;
      for (final release in data) {
        if (release is! Map<String, dynamic>) return null;
        final draft = release['draft'];
        final prerelease = release['prerelease'];
        final tag = release['tag_name'];
        if (draft is! bool || prerelease is! bool || tag is! String) {
          return null;
        }
        if (draft || prerelease) continue;
        final version = parseStableReleaseTag(tag);
        if (version == null || version.major != _legacyMajor) continue;
        if (bestVersion == null || version.isNewerThan(bestVersion)) {
          best = release;
          bestVersion = version;
        }
      }
      if (data.length < _releasesPerPage) {
        return best == null ? null : _resultFromRelease(best, current);
      }
    }
    // Every allowed page was full, so older releases may remain unseen.
    return null;
  }

  /// Builds a result for one eligible stable release, or null when the
  /// release is a draft, a prerelease or carries a suffixed tag.
  UpdateCheckResult? _resultFromRelease(
    Map<String, dynamic> data,
    Semver current,
  ) {
    if (data['draft'] != false || data['prerelease'] != false) return null;

    final tagName = data['tag_name'];
    if (tagName is! String) return null;

    final latestSemver = parseStableReleaseTag(tagName);
    if (latestSemver == null) return null;

    // Extract the APK asset URL from the release assets list.
    String? apkUrl;
    final assets = data['assets'];
    if (assets is List) {
      for (final asset in assets) {
        final name = (asset['name'] as String?) ?? '';
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          break;
        }
      }
    }

    return UpdateCheckResult(
      latestVersion: latestSemver.toString(),
      releaseTag: tagName,
      releaseUrl: data['html_url'] as String?,
      releaseNotes: data['body'] as String?,
      announcement: parseReleaseAnnouncement(data['body'] as String?),
      apkUrl: apkUrl,
      isNewer: latestSemver.isNewerThan(current),
      isMajorUpgrade: latestSemver.major > current.major,
    );
  }

  void clearCache() {
    _cache.clear();
    _cachedResult = null;
  }
}

class _CachedCheck {
  const _CachedCheck(this.checkedAt, this.result);

  final DateTime checkedAt;
  final UpdateCheckResult result;
}
