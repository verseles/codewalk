import 'package:dio/dio.dart';

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

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.latestVersion,
    this.releaseUrl,
    this.releaseNotes,
    this.apkUrl,
    required this.isNewer,
  });

  final String latestVersion;
  final String? releaseUrl;
  final String? releaseNotes;
  // Direct download URL for the .apk asset from the GitHub release, if present.
  final String? apkUrl;
  final bool isNewer;
}

class UpdateCheckService {
  UpdateCheckService({Dio? dio}) : _dio = dio;

  final Dio? _dio;

  static const String _repoOwner = 'verseles';
  static const String _repoName = 'codewalk';
  static const Duration _cooldown = Duration(hours: 1);

  DateTime? _lastCheck;
  UpdateCheckResult? _cachedResult;

  UpdateCheckResult? get cachedResult => _cachedResult;

  Future<UpdateCheckResult?> check(
    String currentVersion, {
    bool ignoreCooldown = false,
  }) async {
    if (!ignoreCooldown &&
        _lastCheck != null &&
        DateTime.now().difference(_lastCheck!) < _cooldown) {
      return _cachedResult;
    }

    try {
      final currentSemver = Semver.tryParse(currentVersion);
      if (currentSemver == null) return null;

      final dio = _dio ?? Dio();
      final response = await dio.get<Map<String, dynamic>>(
        'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
        options: Options(
          headers: <String, String>{
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'CodeWalk',
          },
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 5),
        ),
      );

      final data = response.data;
      if (data == null) return null;

      final tagName = data['tag_name'] as String?;
      if (tagName == null) return null;

      final latestSemver = Semver.tryParse(tagName);
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

      final result = UpdateCheckResult(
        latestVersion: latestSemver.toString(),
        releaseUrl: data['html_url'] as String?,
        releaseNotes: data['body'] as String?,
        apkUrl: apkUrl,
        isNewer: latestSemver.isNewerThan(currentSemver),
      );

      _lastCheck = DateTime.now();
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

  void clearCache() {
    _lastCheck = null;
    _cachedResult = null;
  }
}
