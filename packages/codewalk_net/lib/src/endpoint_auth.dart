import 'dart:async';
import 'dart:convert';

import 'endpoint_target.dart';
import 'http_transport.dart';

/// Builds Basic headers only within the bound endpoint, without storing secrets.
/// A harness chooses its username and the password/token interpretation.
EndpointHeaders basicEndpointHeaders({
  required Uri endpoint,
  required String username,
  required FutureOr<String> Function() secret,
}) {
  final target = EndpointTarget(endpoint);
  if (username.isEmpty || username.contains(':') || _hasControl(username)) {
    throw ArgumentError('Invalid Basic username.');
  }
  return (uri) async {
    target.requireContains(uri);
    final password = await secret();
    if (password.isEmpty || _hasControl(password)) {
      throw const TransportException(TransportFailure.invalidRequest);
    }
    return {
      'authorization':
          'Basic ${base64Encode(utf8.encode('$username:$password'))}',
    };
  };
}

EndpointHeaders bearerEndpointHeaders({
  required Uri endpoint,
  required FutureOr<String> Function() token,
}) {
  final target = EndpointTarget(endpoint);
  return (uri) async {
    target.requireContains(uri);
    final value = await token();
    if (!RegExp(r'^[A-Za-z0-9._~+/\-]+=*$').hasMatch(value)) {
      throw const TransportException(TransportFailure.invalidRequest);
    }
    return {'authorization': 'Bearer $value'};
  };
}

/// Later providers override earlier headers case-insensitively, as HTTP does.
/// Proxy/gateway headers can compose with origin auth without replacing it.
EndpointHeaders composeEndpointHeaders(Iterable<EndpointHeaders> providers) {
  final bound = List<EndpointHeaders>.unmodifiable(providers);
  return (uri) async {
    final headers = <String, String>{};
    for (final provider in bound) {
      for (final entry in (await provider(uri)).entries) {
        headers[entry.key.toLowerCase()] = entry.value;
      }
    }
    return headers;
  };
}

bool _hasControl(String value) => value.runes.any((c) => c < 32 || c == 127);
