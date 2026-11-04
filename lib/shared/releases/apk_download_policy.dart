/// The Android asset name published for every CodeWalk 2 release.
const String codewalkAndroidAssetName = 'codewalk-android-arm64.apk';

/// Release assets the v2 Android updater may read.
const String releaseChecksumsAssetName = 'SHA256SUMS';
const String releaseManifestAssetName = 'release-manifest.json';

/// Hard ceiling for the APK transfer, independent of the manifest claim.
const int maxApkBytes = 256 * 1024 * 1024;

/// Ceiling for the small integrity files.
const int maxIntegrityBytes = 256 * 1024;

/// Every hop of the download must use one of these hosts.
///
/// Observed on 2026-11-04: the GitHub release URL redirects to
/// `release-assets.githubusercontent.com`. A different host fails closed and
/// requires an explicit policy update.
const Set<String> releaseDownloadHosts = <String>{
  'github.com',
  'release-assets.githubusercontent.com',
};

const String _repositoryPath = '/verseles/codewalk/releases/download/';

/// Builds the exact release asset URL for [tag] and [name].
Uri releaseAssetUri(String tag, String name) =>
    Uri.parse('https://github.com$_repositoryPath$tag/$name');

/// Whether [uri] is an HTTPS URL on an allowed release host.
bool isAllowedReleaseUri(Uri uri) {
  if (uri.scheme != 'https') return false;
  if (uri.host.isEmpty || !releaseDownloadHosts.contains(uri.host)) {
    return false;
  }
  if (uri.userInfo.isNotEmpty) return false;
  return !uri.hasFragment;
}

/// Whether [uri] is the exact initial asset URL for [tag] and [name].
///
/// The initial request never carries a query; signed queries are only allowed
/// on redirect hops, which [isAllowedReleaseUri] accepts.
bool isExactReleaseAssetUri(
  Uri uri, {
  required String tag,
  required String name,
}) {
  if (!isAllowedReleaseUri(uri)) return false;
  if (uri.host != 'github.com') return false;
  if (uri.hasQuery) return false;
  return uri.path == '$_repositoryPath$tag/$name';
}

/// Whether a progress update should notify listeners.
///
/// The v1 rule, reimplemented: completion always notifies; otherwise at least
/// [minDelta] progress and [minInterval] since the previous notification are
/// required. Dio-style per-chunk callbacks must not rebuild the app shell at
/// network speed.
bool shouldNotifyApkProgress({
  required double previous,
  required double next,
  required DateTime? lastNotifiedAt,
  required DateTime now,
  double minDelta = 0.01,
  Duration minInterval = const Duration(milliseconds: 100),
}) {
  if (next >= 1.0) return true;
  if (next - previous < minDelta) return false;
  if (lastNotifiedAt == null) return true;
  return now.difference(lastNotifiedAt) >= minInterval;
}
