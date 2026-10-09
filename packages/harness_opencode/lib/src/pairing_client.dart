import 'dart:async';
import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';

import 'endpoint_probe.dart';

typedef PairingTransportFactory =
    EndpointHttpTransport Function(Uri endpoint, String? secret);

/// Consumption is never replayed: losing a connect response loses its challenge.
final class OpenCodePairing implements EndpointPairing {
  OpenCodePairing(
    this.createTransport, {
    this.deadline = const Duration(seconds: 20),
  });
  final PairingTransportFactory createTransport;
  final Duration deadline;
  @override
  PairingCandidate? parse(String input) {
    if (input.length > 4096 || input.runes.any((c) => c < 32 || c == 127)) {
      return null;
    }
    try {
      var uri = Uri.parse(input.trim());
      if (uri.scheme == 'codewalk') {
        if (uri.host != 'pair' ||
            uri.path.isNotEmpty ||
            uri.hasPort ||
            uri.userInfo.isNotEmpty ||
            uri.hasFragment ||
            uri.queryParametersAll.length != 1 ||
            uri.queryParametersAll['url']?.length != 1) {
          return null;
        }
        uri = Uri.parse(uri.queryParametersAll['url']!.single);
      }
      if (!{'http', 'https'}.contains(uri.scheme) ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment) {
        return null;
      }
      final match = RegExp(
        r'^(.*)/auth/connect/([A-Za-z0-9_-]{1,128})$',
      ).firstMatch(uri.path);
      if (match == null) return null;
      final endpoint = EndpointProfile.validateEndpoint(
        uri.replace(path: '${match.group(1)!}/'),
      );
      return PairingCandidate(endpoint: endpoint, challenge: match.group(2)!);
    } on Object {
      return null;
    }
  }

  @override
  PairingTask redeem(PairingCandidate candidate) =>
      _PairingTask(this, candidate.endpoint, candidate: candidate);
  @override
  PairingTask renew(Uri endpoint, EndpointCredential credential) =>
      _PairingTask(this, endpoint, previous: credential);
}

final class _PairingTask implements PairingTask {
  _PairingTask(this.owner, Uri endpoint, {this.candidate, this.previous})
    : endpoint = EndpointProfile.validateEndpoint(endpoint) {
    result = _run();
  }
  final OpenCodePairing owner;
  final Uri endpoint;
  final PairingCandidate? candidate;
  final EndpointCredential? previous;
  final _cancel = RequestCancellation();
  final _transports = <EndpointHttpTransport>[];
  bool _consuming = false;
  bool _timedOut = false;
  @override
  late final Future<PairingResult> result;
  @override
  void cancel() => _cancel.cancel();
  EndpointHttpTransport _transport(String? secret) {
    final transport = owner.createTransport(endpoint, secret);
    _transports.add(transport);
    return transport;
  }

  Future<PairingResult> _run() async {
    final timer = Timer(owner.deadline, () {
      _timedOut = true;
      _cancel.cancel();
    });
    try {
      var code = candidate?.challenge;
      if (previous != null) {
        if (previous!.kind != EndpointAuthKind.paired) {
          return const PairingResult(PairingStatus.renewalUnavailable);
        }
        final authenticated = _transport(previous!.secret);
        final info = await OpenCodeEndpointProbe(
          authenticated,
        ).detect(cancellation: _cancel);
        if (!info.canUse || info.version != '2.0.22') {
          return PairingResult(
            PairingStatus.renewalUnavailable,
            assessment: info,
          );
        }
        _consuming = true;
        final issued = await _request(authenticated, 'POST', '/api/pair');
        if (issued.status == 401 || issued.status == 403) {
          return const PairingResult(PairingStatus.rejected);
        }
        final body = issued.body;
        if (issued.status != 200 ||
            body is! Map ||
            body['code'] is! String ||
            body['expires_in'] is! int ||
            body['expires_in'] <= 0 ||
            !RegExp(
              r'^[A-Za-z0-9_-]{1,128}$',
            ).hasMatch(body['code'] as String)) {
          return const PairingResult(PairingStatus.uncertain);
        }
        code = body['code'] as String;
      }
      if (_cancel.isCancelled) {
        return const PairingResult(PairingStatus.cancelled);
      }
      if (code == null || !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(code)) {
        return const PairingResult(PairingStatus.invalidInput);
      }
      _consuming = true;
      final reply = await _request(
        _transport(null),
        'GET',
        '/auth/connect/$code',
      );
      if (reply.status == 401 || reply.status == 403) {
        return const PairingResult(PairingStatus.rejected);
      }
      final body = reply.body;
      if (reply.status != 200 || body is! Map || body['token'] is! String) {
        return const PairingResult(PairingStatus.uncertain);
      }
      final opaque = EndpointCredential(
        kind: EndpointAuthKind.paired,
        secret: body['token'] as String,
      );
      _consuming = false;
      final info = await OpenCodeEndpointProbe(
        _transport(opaque.secret),
      ).detect(cancellation: _cancel);
      final credential = EndpointCredential(
        kind: opaque.kind,
        secret: opaque.secret,
        expiresAt: {'2.0.21', '2.0.22'}.contains(info.version)
            ? _expiry(opaque.secret)
            : null,
      );
      if (_cancel.isCancelled) {
        return PairingResult(
          _timedOut
              ? PairingStatus.verificationFailed
              : PairingStatus.cancelled,
          credential: credential,
          assessment: info,
        );
      }
      return PairingResult(
        info.canUse ? PairingStatus.ready : PairingStatus.verificationFailed,
        credential: credential,
        assessment: info,
      );
    } on Object {
      return PairingResult(
        _consuming
            ? PairingStatus.uncertain
            : _cancel.isCancelled && !_timedOut
            ? PairingStatus.cancelled
            : PairingStatus.unreachable,
      );
    } finally {
      timer.cancel();
      for (final transport in _transports) {
        transport.close();
      }
    }
  }

  Future<_PairReply> _request(
    EndpointHttpTransport transport,
    String method,
    String path,
  ) async {
    final response = await transport.send(
      TransportRequest(
        method: method,
        path: path,
        headers: const {'Accept': 'application/json'},
      ),
      cancellation: _cancel,
    );
    try {
      final bytes = await response.readBytes(
        maxBytes: 64 * 1024,
        inactivityTimeout: owner.deadline,
      );
      final media = response
          .header('content-type')
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      Object? body;
      if (media == 'application/json' ||
          (media?.startsWith('application/') == true &&
              media!.endsWith('+json'))) {
        try {
          body = jsonDecode(utf8.decode(bytes));
        } on FormatException {
          /* Unknown outcome. */
        }
      }
      return _PairReply(response.statusCode, body);
    } finally {
      response.cancel();
    }
  }

  DateTime? _expiry(String secret) {
    final match = RegExp(r'^(\d{1,13})\.[A-Za-z0-9_-]{43}$').firstMatch(secret);
    if (match == null) return null;
    final seconds = int.tryParse(match.group(1)!);
    if (seconds == null || seconds > 8640000000000) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }
}

final class _PairReply {
  const _PairReply(this.status, this.body);
  final int status;
  final Object? body;
}
