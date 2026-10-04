import 'package:flutter/foundation.dart';

/// A link requests navigation; it does not establish a connection or session.
sealed class PendingNavigationIntent {
  const PendingNavigationIntent();
}

final class PairingNavigationIntent extends PendingNavigationIntent {
  const PairingNavigationIntent();

  @override
  String toString() => 'PairingNavigationIntent';
}

/// Native identifiers remain opaque until a profile supplies harness identity.
final class SessionNavigationIntent extends PendingNavigationIntent {
  const SessionNavigationIntent({required this.host, required this.session});

  final String host;
  final String session;

  @override
  String toString() => 'SessionNavigationIntent';
}

final class UnsupportedNavigationIntent extends PendingNavigationIntent {
  const UnsupportedNavigationIntent();

  @override
  String toString() => 'UnsupportedNavigationIntent';
}

class AppNavigationController extends ChangeNotifier {
  PendingNavigationIntent? _pending;
  Uri? _pairingLink;
  bool _disposed = false;

  PendingNavigationIntent? get pendingIntent => _pending;
  bool get isDisposed => _disposed;

  /// Produces a credential-free route while keeping pairing data only in memory.
  String prepareLink(Uri link) {
    _pairingLink = null;
    final List<String> segments;
    try {
      segments = link.pathSegments;
    } on FormatException {
      return _unsupportedLink();
    }
    final custom = link.scheme == 'codewalk';
    final local = link.scheme.isEmpty && !link.hasAuthority;
    final pairing =
        (custom && link.host == 'pair' && segments.isEmpty) ||
        (local && link.path == '/pair');
    if (pairing &&
        !link.hasFragment &&
        link.userInfo.isEmpty &&
        !link.hasPort) {
      _pairingLink = link;
      _pending = const PairingNavigationIntent();
      notifyListeners();
      return '/pair';
    }

    final sessionSegments = custom && link.host == 's'
        ? segments
        : local && segments.length == 3 && segments.first == 's'
        ? segments.skip(1).toList()
        : const <String>[];
    if ((custom || local) &&
        sessionSegments.length == 2 &&
        sessionSegments.every(_validIdentifier) &&
        !link.hasQuery &&
        !link.hasFragment &&
        link.userInfo.isEmpty &&
        !link.hasPort) {
      _pending = SessionNavigationIntent(
        host: sessionSegments[0],
        session: sessionSegments[1],
      );
      notifyListeners();
      return Uri(pathSegments: ['', 's', ...sessionSegments]).toString();
    }

    if (local &&
        const ['/', '/hosts', '/sessions', '/settings'].contains(link.path) &&
        !link.hasQuery &&
        !link.hasFragment) {
      _pending = null;
      notifyListeners();
      return link.path;
    }

    return _unsupportedLink();
  }

  String _unsupportedLink() {
    _pending = const UnsupportedNavigationIntent();
    notifyListeners();
    return '/unsupported';
  }

  /// Future pairing consumers take the original link once, without persisting it.
  Uri? consumePairingLink() {
    final link = _pairingLink;
    _pairingLink = null;
    return link;
  }

  static bool _validIdentifier(String value) =>
      value.isNotEmpty && !value.runes.any((c) => c < 0x20 || c == 0x7f);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pairingLink = null;
    _pending = null;
    super.dispose();
  }
}
