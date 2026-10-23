/// A strict SemVer 2.0 version. Precedence follows the specification:
/// prerelease identifiers compare numerically or lexically, a prerelease
/// ranks below its release, and build metadata never affects ordering.
final class AppVersion implements Comparable<AppVersion> {
  AppVersion._(this.major, this.minor, this.patch, this.prerelease);

  static final _pattern = RegExp(
    r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
    r'(?:-((?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*)'
    r'(?:\.(?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*))*))?'
    r'(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
  );

  static AppVersion? tryParse(String text) {
    final match = _pattern.firstMatch(text);
    if (match == null) return null;
    return AppVersion._(
      BigInt.parse(match.group(1)!),
      BigInt.parse(match.group(2)!),
      BigInt.parse(match.group(3)!),
      List.unmodifiable(match.group(4)?.split('.') ?? const <String>[]),
    );
  }

  final BigInt major;
  final BigInt minor;
  final BigInt patch;
  final List<String> prerelease;

  bool get isPrerelease => prerelease.isNotEmpty;

  @override
  int compareTo(AppVersion other) {
    for (final (a, b) in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
    ]) {
      final order = a.compareTo(b);
      if (order != 0) return order;
    }
    if (prerelease.isEmpty || other.prerelease.isEmpty) {
      return other.prerelease.length.sign - prerelease.length.sign;
    }
    for (var i = 0; i < prerelease.length && i < other.prerelease.length; i++) {
      final order = _compareIdentifier(prerelease[i], other.prerelease[i]);
      if (order != 0) return order;
    }
    return prerelease.length.compareTo(other.prerelease.length);
  }

  static int _compareIdentifier(String a, String b) {
    // Only all-digit identifiers are numeric; "-1" is alphanumeric.
    final digits = RegExp(r'^\d+$');
    final x = digits.hasMatch(a) ? BigInt.parse(a) : null;
    final y = digits.hasMatch(b) ? BigInt.parse(b) : null;
    if (x != null && y != null) return x.compareTo(y);
    if (x != null) return -1;
    if (y != null) return 1;
    return a.compareTo(b);
  }

  @override
  String toString() =>
      '$major.$minor.$patch${isPrerelease ? '-${prerelease.join('.')}' : ''}';

  @override
  bool operator ==(Object other) =>
      other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode =>
      Object.hash(major, minor, patch, Object.hashAll(prerelease));
}
