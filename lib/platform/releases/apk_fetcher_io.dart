import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../shared/releases/apk_download_policy.dart';
import '../../shared/releases/apk_update.dart';

/// Streams release assets from GitHub and its CDN over HTTPS.
///
/// The transport deliberately does not follow redirects by itself: every hop
/// is validated against [releaseDownloadHosts] before its body is read.
final class HttpClientApkFetcher implements ApkAssetFetcher {
  HttpClientApkFetcher({HttpClient? client, this.maxRedirects = 3})
    : _client = client ?? HttpClient() {
    _client.connectionTimeout = _connectTimeout;
  }

  final HttpClient _client;
  final int maxRedirects;
  bool _closed = false;
  HttpClientRequest? _activeRequest;
  HttpClientResponse? _activeResponse;

  static const Duration _connectTimeout = Duration(seconds: 15);
  static const Duration _headerTimeout = Duration(seconds: 15);
  static const Duration _inactivity = Duration(seconds: 30);
  static const Duration _overall = Duration(minutes: 15);

  @override
  Future<String> fetchText(Uri uri, {int maxBytes = maxIntegrityBytes}) async {
    final response = await _open(uri);
    if (response.statusCode != 200) {
      await _discardResponse(response);
      throw const ApkDownloadException(ApkUpdateFailure.http);
    }
    final bytes = <int>[];
    try {
      await for (final chunk in response.timeout(_inactivity)) {
        if (bytes.length + chunk.length > maxBytes) {
          throw const ApkDownloadException(ApkUpdateFailure.tooLarge);
        }
        bytes.addAll(chunk);
      }
    } on TimeoutException {
      throw const ApkDownloadException(ApkUpdateFailure.timeout);
    } on SocketException catch (error) {
      throw ApkDownloadException(ApkUpdateFailure.network, error);
    }
    _activeResponse = null;
    return utf8.decode(bytes);
  }

  @override
  Future<ApkDownloadResult> download(
    Uri uri,
    String partPath, {
    required void Function(int received, int? total) onProgress,
    required bool Function() isCancelled,
  }) async {
    final response = await _open(uri);
    if (response.statusCode != 200) {
      await _discardResponse(response);
      throw const ApkDownloadException(ApkUpdateFailure.http);
    }
    final total = response.contentLength >= 0 ? response.contentLength : null;
    if (total != null && total > maxApkBytes) {
      await _discardResponse(response);
      throw const ApkDownloadException(ApkUpdateFailure.tooLarge);
    }

    final file = File(partPath);
    await file.parent.create(recursive: true);
    final digestSink = _DigestSink();
    final input = sha256.startChunkedConversion(digestSink);
    RandomAccessFile? handle;
    var received = 0;
    final watch = Stopwatch()..start();
    try {
      handle = await file.open(mode: FileMode.write);
      await for (final chunk in response.timeout(_inactivity)) {
        if (_closed || isCancelled()) {
          throw const ApkDownloadException(ApkUpdateFailure.cancelled);
        }
        received += chunk.length;
        if (received > maxApkBytes) {
          throw const ApkDownloadException(ApkUpdateFailure.tooLarge);
        }
        if (watch.elapsed > _overall) {
          throw const ApkDownloadException(ApkUpdateFailure.timeout);
        }
        await handle.writeFrom(chunk);
        input.add(chunk);
        onProgress(received, total);
      }
      input.close();
      await handle.flush();
      await handle.close();
      handle = null;
    } on ApkDownloadException {
      await _discard(handle, file);
      rethrow;
    } on TimeoutException {
      await _discard(handle, file);
      throw const ApkDownloadException(ApkUpdateFailure.timeout);
    } on SocketException catch (error) {
      await _discard(handle, file);
      throw ApkDownloadException(ApkUpdateFailure.network, error);
    } on FileSystemException catch (error) {
      await _discard(handle, file);
      throw ApkDownloadException(ApkUpdateFailure.storage, error);
    } catch (error) {
      await _discard(handle, file);
      throw ApkDownloadException(ApkUpdateFailure.network, error);
    }
    _activeResponse = null;
    final digest = digestSink.value;
    if (digest == null) {
      throw const ApkDownloadException(ApkUpdateFailure.checksumUnavailable);
    }
    return ApkDownloadResult(bytes: received, sha256: digest.toString());
  }

  Future<void> _discard(RandomAccessFile? handle, File file) async {
    try {
      await handle?.close();
    } on Object {
      // Best effort: the file is removed below.
    }
    try {
      await file.delete();
    } on Object {
      // Best effort: a missing part is already clean.
    }
  }

  Future<HttpClientResponse> _open(Uri uri) async {
    var current = uri;
    for (var hop = 0; hop <= maxRedirects; hop++) {
      if (!isAllowedReleaseUri(current)) {
        throw const ApkDownloadException(ApkUpdateFailure.http);
      }
      final HttpClientRequest request;
      try {
        request = await _client.getUrl(current).timeout(_connectTimeout);
      } on TimeoutException {
        throw const ApkDownloadException(ApkUpdateFailure.timeout);
      } on SocketException catch (error) {
        throw ApkDownloadException(ApkUpdateFailure.network, error);
      }
      request.followRedirects = false;
      _activeRequest = request;
      request.headers.set(HttpHeaders.userAgentHeader, 'CodeWalk');
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      final HttpClientResponse response;
      try {
        response = await request.close().timeout(_headerTimeout);
      } on TimeoutException {
        throw const ApkDownloadException(ApkUpdateFailure.timeout);
      } on SocketException catch (error) {
        throw ApkDownloadException(ApkUpdateFailure.network, error);
      }
      _activeRequest = null;
      if (!response.isRedirect) {
        _activeResponse = response;
        return response;
      }
      final location = response.headers.value(HttpHeaders.locationHeader);
      await _discardResponse(response);
      _activeResponse = null;
      if (location == null) {
        throw const ApkDownloadException(ApkUpdateFailure.http);
      }
      current = current.resolve(location);
    }
    throw const ApkDownloadException(ApkUpdateFailure.http);
  }

  /// Aborts a response we will not read, without waiting for its body.
  Future<void> _discardResponse(HttpClientResponse response) async {
    try {
      final socket = await response.detachSocket();
      socket.destroy();
    } on Object {
      // The response was already consumed or the socket is gone.
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _client.close(force: true);
  }

  @override
  void cancelActive() {
    _activeRequest?.abort();
    final response = _activeResponse;
    if (response == null) return;
    _activeResponse = null;
    unawaited(
      response
          .detachSocket()
          .then<void>((socket) => socket.destroy())
          .catchError((Object _) {}),
    );
  }
}

ApkAssetFetcher createApkFetcher() => HttpClientApkFetcher();

final class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
