import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';

import 'attachment_encoding.dart';
import 'version_policy.dart';

/// Result of staging one non-inline file into OpenCode's temporary uploads dir.
sealed class OpenCodeUploadResult {
  const OpenCodeUploadResult();
}

final class OpenCodeUploadCompleted extends OpenCodeUploadResult {
  const OpenCodeUploadCompleted(this.serverPath);
  final String serverPath;
}

final class OpenCodeUploadFailed extends OpenCodeUploadResult {
  const OpenCodeUploadFailed(this.reason, {this.statusCode});
  final String reason;
  final int? statusCode;
}

/// Streams a user-selected attachment to OpenCode's temporary upload path via
/// `POST /api/experimental/fs/write?location[directory]=<dir>&path=<tmp>/uploads/<uuid>/<safeName>`.
///
/// Strictly confined to `<tmp>/uploads/<uuid>/<safeName>`; workspace writes
/// remain unavailable. Verifies the server response path equals the requested
/// temporary path before accepting it.
final class OpenCodeAttachmentUploadClient {
  OpenCodeAttachmentUploadClient(
    this.transport, {
    required this.harness,
    required this.connectedVersion,
    this.deadline = const Duration(minutes: 5),
    this.maxResponseBytes = 64 * 1024,
  }) {
    if (deadline <= Duration.zero || maxResponseBytes <= 0) {
      throw ArgumentError('Upload deadline and response cap must be positive.');
    }
  }

  final EndpointHttpTransport transport;
  final HarnessRef harness;
  final String connectedVersion;
  final Duration deadline;
  final int maxResponseBytes;

  Future<OpenCodeUploadResult> upload({
    required String sessionDirectory,
    required String temporaryPath,
    required String uploadId,
    required String filename,
    required Stream<List<int>> bytes,
    required int length,
    RequestCancellation? cancellation,
  }) async {
    if (!OpenCodeCompatibility.supportsV2(connectedVersion)) {
      return const OpenCodeUploadFailed('unverifiedVersion');
    }
    if (sessionDirectory.isEmpty ||
        utf8.encode(sessionDirectory).length > 4096) {
      return const OpenCodeUploadFailed('invalidDirectory');
    }
    if (length < 0 || length > openCodeMaxUploadBytes) {
      return const OpenCodeUploadFailed('tooLarge');
    }
    final String expectedPath;
    try {
      expectedPath = buildOpenCodeUploadPath(
        temporaryPath: temporaryPath,
        uploadId: uploadId,
        filename: filename,
      );
    } on ArgumentError {
      return const OpenCodeUploadFailed('unsafePath');
    }
    if (cancellation?.isCancelled ?? false) {
      return const OpenCodeUploadFailed('cancelledBeforeSend');
    }
    if (transport.isClosed) {
      return const OpenCodeUploadFailed('closed');
    }

    final token = RequestCancellation();
    var timedOut = false;
    final expired = Completer<Never>();
    expired.future.ignore();
    final timer = Timer(deadline, () {
      timedOut = true;
      token.cancel();
      expired.completeError(const TransportException(TransportFailure.timeout));
    });
    final parent = cancellation?.onCancel.listen((_) => token.cancel());
    TransportResponse? response;
    try {
      final route = Uri(
        pathSegments: const ['api', 'experimental', 'fs', 'write'],
        queryParameters: {
          'location[directory]': sessionDirectory,
          'path': expectedPath,
        },
      ).toString();
      final sending = transport.send(
        TransportRequest(
          method: 'POST',
          path: route,
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/octet-stream',
          },
          bodyStream: bytes,
          contentLength: length,
        ),
        cancellation: token,
      );
      unawaited(
        sending.then((late) {
          if (timedOut) late.cancel();
        }, onError: (Object _) {}),
      );
      final current = await Future.any<TransportResponse>([
        sending,
        expired.future,
      ]);
      response = current;
      final status = current.statusCode;
      if (status != 200) {
        return switch (status) {
          400 => const OpenCodeUploadFailed('invalidRequest', statusCode: 400),
          401 || 403 => OpenCodeUploadFailed(
            'UnauthorizedError',
            statusCode: status,
          ),
          404 || 405 => OpenCodeUploadFailed(
            'uploadUnavailable',
            statusCode: status,
          ),
          413 => const OpenCodeUploadFailed('tooLarge', statusCode: 413),
          429 => const OpenCodeUploadFailed('RateLimited', statusCode: 429),
          _ => OpenCodeUploadFailed('status$status', statusCode: status),
        };
      }
      final bodyBytes = await Future.any<Uint8List>([
        current.readBytes(
          maxBytes: maxResponseBytes,
          inactivityTimeout: const Duration(seconds: 30),
        ),
        expired.future,
      ]);
      final Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(bodyBytes));
      } on FormatException {
        return const OpenCodeUploadFailed('malformedResponse');
      }
      final data = decoded is Map<String, Object?> ? decoded['data'] : null;
      final returned = data is Map<String, Object?> ? data['path'] : null;
      if (returned is! String ||
          !isTrustedOpenCodeUploadPath(
            returnedPath: returned,
            expectedPath: expectedPath,
            temporaryPath: temporaryPath,
          )) {
        return const OpenCodeUploadFailed('untrustedPath');
      }
      return OpenCodeUploadCompleted(returned);
    } on TransportException catch (error) {
      if (timedOut) return const OpenCodeUploadFailed('timeout');
      return OpenCodeUploadFailed(error.failure.name);
    } on Object {
      if (timedOut) return const OpenCodeUploadFailed('timeout');
      return const OpenCodeUploadFailed('uploadFailed');
    } finally {
      timer.cancel();
      unawaited(parent?.cancel());
      response?.cancel();
    }
  }
}
