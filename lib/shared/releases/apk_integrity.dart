import 'dart:convert';

/// The Android package that may replace itself with an update.
const String codewalkAndroidApplicationId = 'com.verseles.codewalk';

/// The production Android signing certificate (SHA-256 of the DER cert).
///
/// Published releases must carry this signer; a manifest that claims another
/// signer is refused before any download.
const String codewalkAndroidSignerSha256 =
    '7361852522a3c5baf7eefef3285cf3aa90b6431604f52ee66e92da46b4f846c9';

/// The only ABI the v2 Android release ships.
const String codewalkAndroidAbi = 'arm64-v8a';

final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');
final RegExp _sumLine = RegExp(r'^([0-9a-f]{64})  (.+)$');

/// Returns the digest declared for [assetName] in a `SHA256SUMS` body.
///
/// The file uses the GNU two-space form (`<sha256>  <name>`). A duplicate
/// entry for the same asset, a different digest case or any other shape is
/// rejected by returning null.
String? parseSha256Sums(String body, String assetName) {
  String? digest;
  for (final raw in const LineSplitter().convert(body)) {
    final line = raw.trimRight();
    if (line.isEmpty) continue;
    final match = _sumLine.firstMatch(line);
    if (match == null) continue;
    if (match.group(2) != assetName) continue;
    if (digest != null) return null;
    digest = match.group(1);
  }
  return digest;
}

/// One release asset entry from `release-manifest.json`.
final class ReleaseAssetManifest {
  const ReleaseAssetManifest({
    required this.abi,
    required this.applicationId,
    required this.sha256,
    required this.signerSha256,
    required this.size,
    required this.versionCode,
    required this.versionName,
  });

  final String abi;
  final String applicationId;
  final String sha256;
  final String signerSha256;
  final int size;
  final int versionCode;
  final String versionName;
}

/// The verified release manifest for one tag.
final class ReleaseManifest {
  const ReleaseManifest({
    required this.tag,
    required this.version,
    required this.asset,
  });

  final String tag;
  final String version;
  final ReleaseAssetManifest asset;
}

/// Parses and validates `release-manifest.json` for [tag] and [assetName].
///
/// Returns null for any malformed, mismatched or unsafe manifest. The caller
/// must also compare [ReleaseAssetManifest.sha256] and `.size` with the
/// `SHA256SUMS` entry and the streamed bytes.
ReleaseManifest? parseReleaseManifest(
  String body, {
  required String tag,
  required String assetName,
}) {
  try {
    final root = jsonDecode(body);
    if (root is! Map<String, dynamic>) return null;
    if (root['schema'] != 1) return null;
    final releaseTag = root['tag'];
    final version = root['version'];
    if (releaseTag is! String || releaseTag != tag || version is! String) {
      return null;
    }
    final assets = root['assets'];
    if (assets is! Map) return null;
    final asset = assets[assetName];
    if (asset is! Map) return null;
    final abi = asset['abi'];
    final applicationId = asset['application_id'];
    final sha256 = asset['sha256'];
    final signerSha256 = asset['signer_sha256'];
    final size = asset['size'];
    final versionCode = asset['version_code'];
    final versionName = asset['version_name'];
    if (abi is! String ||
        applicationId is! String ||
        sha256 is! String ||
        signerSha256 is! String ||
        size is! int ||
        versionCode is! int ||
        versionName is! String) {
      return null;
    }
    if (!_hex64.hasMatch(sha256) || !_hex64.hasMatch(signerSha256)) {
      return null;
    }
    if (signerSha256 != codewalkAndroidSignerSha256) return null;
    if (size <= 0 || versionCode <= 0) return null;
    if (abi != codewalkAndroidAbi) return null;
    if (applicationId != codewalkAndroidApplicationId) return null;
    return ReleaseManifest(
      tag: releaseTag,
      version: version,
      asset: ReleaseAssetManifest(
        abi: abi,
        applicationId: applicationId,
        sha256: sha256,
        signerSha256: signerSha256,
        size: size,
        versionCode: versionCode,
        versionName: versionName,
      ),
    );
  } on FormatException {
    return null;
  }
}
