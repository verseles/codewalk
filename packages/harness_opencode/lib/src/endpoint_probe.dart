import 'dart:async';
import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';

import 'retry_after.dart';
import 'server_info.dart';
import 'version_policy.dart';

/// Read-only detection: one info request and, only for a missing/HTML route, one
/// bounded legacy health request. Credential and transport ownership stay outside.
final class OpenCodeEndpointProbe {
  OpenCodeEndpointProbe(
    this.transport, {
    DateTime Function()? now,
    this.deadline = const Duration(seconds: 20),
    this.maxBodyBytes = 64 * 1024,
  }) : now = now ?? DateTime.now {
    if (deadline <= Duration.zero || maxBodyBytes <= 0) {
      throw ArgumentError('Invalid probe limits.');
    }
  }
  final EndpointHttpTransport transport;
  final DateTime Function() now;
  final Duration deadline;
  final int maxBodyBytes;

  Future<EndpointAssessment> detect({RequestCancellation? cancellation}) async {
    final token = cancellation ?? RequestCancellation();
    if (token.isCancelled) {
      return const EndpointAssessment(EndpointStatus.cancelled);
    }
    var timedOut = false;
    final timer = Timer(deadline, () {
      timedOut = true;
      token.cancel();
    });
    try {
      final info = await _get('/api/info', token);
      if (token.isCancelled) {
        return EndpointAssessment(
          timedOut ? EndpointStatus.unreachable : EndpointStatus.cancelled,
        );
      }
      if (info.status == 401 || info.status == 403) {
        return const EndpointAssessment(EndpointStatus.authenticationRequired);
      }
      final server = OpenCodeServerInfo.tryParse(info.json);
      if (info.status == 500 || info.status == 503) {
        final hint = RetryAfterHint.parse(info.retryAfter, now());
        final code = info.json is Map ? (info.json as Map)['code'] : null;
        final status = switch (code) {
          'service_starting' => EndpointStatus.serviceStarting,
          'service_stopping' => EndpointStatus.serviceStopping,
          'service_failed' => EndpointStatus.serviceFailed,
          _ =>
            server != null && info.status == 500
                ? EndpointStatus.serviceFailed
                : EndpointStatus.serviceUnavailable,
        };
        return EndpointAssessment(
          status,
          version: server == null
              ? null
              : (OpenCodeCompatibility.parse(server.version) != null
                    ? server.version
                    : null),
          retryAt: hint.at,
          retryDeferred: hint.deferred,
        );
      }
      if (info.status == 200 && server != null) {
        return OpenCodeCompatibility.assess(server.version);
      }
      // Auth, readiness and valid-but-unknown JSON are not permission to downgrade.
      if (info.status != 404 && !(info.status == 200 && info.html)) {
        return const EndpointAssessment(EndpointStatus.unrecognized);
      }
      final health = await _get('/global/health', token);
      if (token.isCancelled) {
        return EndpointAssessment(
          timedOut ? EndpointStatus.unreachable : EndpointStatus.cancelled,
        );
      }
      if (health.status == 401 || health.status == 403) {
        return const EndpointAssessment(EndpointStatus.authenticationRequired);
      }
      if (health.status == 200 && health.json is Map) {
        final data = health.json as Map;
        final version = data['version'];
        if (data['healthy'] == true &&
            version is String &&
            OpenCodeCompatibility.parse(version)?.major == 1) {
          return EndpointAssessment(
            EndpointStatus.legacyServer,
            version: version,
          );
        }
      }
      return const EndpointAssessment(EndpointStatus.unrecognized);
    } on TransportException {
      return EndpointAssessment(
        token.isCancelled && !timedOut
            ? EndpointStatus.cancelled
            : EndpointStatus.unreachable,
      );
    } on Object {
      return const EndpointAssessment(EndpointStatus.unrecognized);
    } finally {
      timer.cancel();
    }
  }

  Future<_Reply> _get(String path, RequestCancellation token) async {
    final response = await transport.send(
      TransportRequest(
        method: 'GET',
        path: path,
        headers: const {'Accept': 'application/json'},
      ),
      cancellation: token,
    );
    try {
      final bytes = await response.readBytes(
        maxBytes: maxBodyBytes,
        inactivityTimeout: deadline,
      );
      final media = response
          .header('content-type')
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      Object? json;
      if (media == 'application/json' ||
          (media?.startsWith('application/') == true &&
              media!.endsWith('+json'))) {
        try {
          json = jsonDecode(utf8.decode(bytes));
        } on FormatException {
          /* Not API success. */
        }
      }
      return _Reply(
        response.statusCode,
        json,
        media == 'text/html',
        response.header('retry-after'),
      );
    } finally {
      response.cancel();
    }
  }
}

final class _Reply {
  const _Reply(this.status, this.json, this.html, this.retryAfter);
  final int status;
  final Object? json;
  final bool html;
  final String? retryAfter;
}
