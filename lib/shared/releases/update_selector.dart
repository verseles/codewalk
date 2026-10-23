import 'app_version.dart';

/// Stable offers only final CodeWalk 2 releases; beta (explicit opt-in) also
/// offers the v2.0.0-beta.N prereleases.
enum UpdateChannel { stable, beta }

/// The native MVP targets and the release asset each one installs.
enum UpdateTarget {
  androidArm64('codewalk-android-arm64.apk'),
  linuxX64('codewalk-linux-x64.tar.gz'),
  linuxArm64('codewalk-linux-arm64.tar.gz');

  const UpdateTarget(this.assetName);
  final String assetName;
}

final class UpdateCandidate {
  const UpdateCandidate({
    required this.tag,
    required this.version,
    required this.assetUrl,
  });

  final String tag;
  final AppVersion version;
  final Uri assetUrl;
}

const _repository = 'https://github.com/verseles/codewalk';
final _betaTag = RegExp(r'^v2\.0\.0-beta\.[1-9]\d*$');

/// Picks the newest release above [current] that [channel] allows and that
/// ships [target]'s asset, from a GitHub releases listing.
///
/// Only CodeWalk 2 qualifies: other majors, the v1 native cohorts, drafts,
/// other prerelease families and releases whose prerelease flag disagrees
/// with their tag are skipped, as are assets served from anywhere but this
/// repository's download path for that exact tag.
UpdateCandidate? selectUpdate({
  required Object? releases,
  required UpdateChannel channel,
  required AppVersion current,
  required UpdateTarget target,
}) {
  if (releases is! List) throw const FormatException('Invalid release list');
  UpdateCandidate? best;
  for (final release in releases) {
    final candidate = _candidate(release, channel, target);
    if (candidate == null || candidate.version.compareTo(current) <= 0) {
      continue;
    }
    if (best == null || candidate.version.compareTo(best.version) > 0) {
      best = candidate;
    }
  }
  return best;
}

UpdateCandidate? _candidate(
  Object? release,
  UpdateChannel channel,
  UpdateTarget target,
) {
  if (release is! Map ||
      release['draft'] != false ||
      release['prerelease'] is! bool) {
    return null;
  }
  final tag = release['tag_name'];
  if (tag is! String || !tag.startsWith('v')) return null;
  final version = AppVersion.tryParse(tag.substring(1));
  if (version == null ||
      version.major != BigInt.two ||
      // A canonical tag only: no build metadata, nothing to reinterpret.
      'v$version' != tag) {
    return null;
  }
  final prerelease = release['prerelease'] as bool;
  if (version.isPrerelease) {
    if (channel != UpdateChannel.beta ||
        !prerelease ||
        !_betaTag.hasMatch(tag)) {
      return null;
    }
  } else if (prerelease) {
    return null;
  }
  final assets = release['assets'];
  if (assets is! List) return null;
  final expected = '$_repository/releases/download/$tag/${target.assetName}';
  for (final asset in assets) {
    if (asset is Map &&
        asset['name'] == target.assetName &&
        asset['browser_download_url'] == expected) {
      return UpdateCandidate(
        tag: tag,
        version: version,
        assetUrl: Uri.parse(expected),
      );
    }
  }
  return null;
}

/// The installer command that installs exactly [candidate] on Linux.
String linuxInstallCommand(UpdateCandidate candidate) =>
    'curl -fsSL https://install.cat/verseles/codewalk | '
    'CODEWALK_CHANNEL=${candidate.version.isPrerelease ? 'beta' : 'stable'} '
    'CODEWALK_VERSION=${candidate.tag} sh';
