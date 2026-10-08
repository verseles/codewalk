import 'http_transport.dart';

/// One HTTP origin and optional proxy path prefix, validated before credentials.
final class EndpointTarget {
  EndpointTarget(Uri endpoint) : endpoint = _validate(endpoint);

  final Uri endpoint;

  static Uri _validate(Uri uri) {
    if (!{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.port <= 0 ||
        uri.port > 65535) {
      throw const TransportException(TransportFailure.invalidTarget);
    }
    return uri.replace(
      path: uri.path.endsWith('/') ? uri.path : '${uri.path}/',
    );
  }

  Uri resolve(String path) {
    try {
      final route = Uri.parse(path);
      if (route.hasScheme || route.hasAuthority || route.hasFragment) {
        throw const TransportException(TransportFailure.invalidTarget);
      }
      _checkSegments(route);
      final relative = route.path.startsWith('/')
          ? route.replace(path: route.path.substring(1))
          : route;
      final target = endpoint.resolveUri(relative);
      requireContains(target);
      return target;
    } on FormatException {
      throw const TransportException(TransportFailure.invalidTarget);
    }
  }

  void requireContains(Uri target) {
    if (target.scheme != endpoint.scheme ||
        target.host != endpoint.host ||
        target.port != endpoint.port ||
        target.userInfo.isNotEmpty ||
        target.hasFragment ||
        !target.path.startsWith(endpoint.path)) {
      throw const TransportException(TransportFailure.invalidTarget);
    }
    _checkSegments(target);
  }

  static void _checkSegments(Uri route) {
    for (final part in route.pathSegments) {
      var decoded = part;
      for (var depth = 0; depth < 16; depth++) {
        if (decoded.split(RegExp(r'[/\\]')).any((p) => p == '.' || p == '..')) {
          throw const TransportException(TransportFailure.invalidTarget);
        }
        if (!RegExp(r'%[0-9a-fA-F]{2}').hasMatch(decoded)) break;
        try {
          decoded = Uri.decodeComponent(decoded);
        } on FormatException {
          throw const TransportException(TransportFailure.invalidTarget);
        }
        if (depth == 15) {
          throw const TransportException(TransportFailure.invalidTarget);
        }
      }
    }
  }
}
