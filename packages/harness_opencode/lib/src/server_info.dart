/// The official ServerInfo wire shape. URLs are observations, never a new target.
final class OpenCodeServerInfo {
  const OpenCodeServerInfo(
    this.version,
    this.pid,
    this.urls,
    this.temporaryPath,
  );
  final String version;
  final int pid;
  final List<String> urls;
  final String temporaryPath;

  static OpenCodeServerInfo? tryParse(Object? value) {
    if (value is! Map ||
        value['version'] is! String ||
        (value['version'] as String).isEmpty ||
        (value['version'] as String).length > 128 ||
        value['pid'] is! int ||
        (value['pid'] as int) < 0 ||
        value['urls'] is! List ||
        (value['urls'] as List).length > 64 ||
        !(value['urls'] as List).every(
          (u) => u is String && u.length <= 2048,
        ) ||
        value['paths'] is! Map ||
        (value['paths'] as Map)['tmp'] is! String) {
      return null;
    }
    return OpenCodeServerInfo(
      value['version'] as String,
      value['pid'] as int,
      List<String>.unmodifiable(value['urls'] as List),
      (value['paths'] as Map)['tmp'] as String,
    );
  }
}
