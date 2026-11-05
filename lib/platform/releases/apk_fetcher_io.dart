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
  bool _cancelRequested = false;
  HttpClientRequest? _activeRequest;
  HttpClientResponse? _activeResponse;

  static const Duration _connectTimeout = Duration(seconds: 15);
  static const Duration _headerTimeout = Duration(seconds: 15);
  static const Duration _inactivity = Duration(seconds: 30);
  static const Duration _overall = Duration(minutes: 15);

  @override
  Future<String> fetchText(Uri uri, {int maxBytes = maxIntegrityBytes}) async {
    _cancelRequested = false;
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
    } on IOException catch (error) {
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
    int? expectedBytes,
    String? expectedSha256,
  }) async {
    try {
      return await _download(
        uri,
        partPath,
        onProgress: onProgress,
        isCancelled: isCancelled,
        expectedBytes: expectedBytes,
        expectedSha256: expectedSha256,
      );
    } on FileSystemException catch (error) {
      throw ApkDownloadException(ApkUpdateFailure.storage, error);
    }
  }

  Future<ApkDownloadResult> _download(
    Uri uri,
    String partPath, {
    required void Function(int received, int? total) onProgress,
    required bool Function() isCancelled,
    int? expectedBytes,
    String? expectedSha256,
  }) async {
    _cancelRequested = false;
    final file = File(partPath);
    final sidecar = File('$partPath.json');
    for (final path in [partPath, sidecar.path]) {
      if (FileSystemEntity.isLinkSync(path)) {
        throw FileSystemException('Update cache must not contain links', path);
      }
    }
    await file.parent.create(recursive: true);
    var offset = 0;
    String? validator;
    final identity = <String, Object?>{
      'uri': uri.toString(),
      'bytes': expectedBytes,
      'sha256': expectedSha256,
    };
    if (expectedBytes != null && expectedBytes > 0 && expectedSha256 != null) {
      try {
        if (await sidecar.length() > 4096) {
          throw const FormatException('Oversized partial metadata');
        }
        final saved = jsonDecode(await sidecar.readAsString());
        final length = await file.length();
        if (saved is Map &&
            identity.entries.every((e) => saved[e.key] == e.value) &&
            length > 0 &&
            length < expectedBytes) {
          offset = length;
          final tag = saved['etag'];
          if (tag is String && tag.startsWith('"') && tag.endsWith('"')) {
            validator = tag;
          }
        }
      } on Object {
        // An unidentifiable partial file is replaced, never appended to.
      }
    }
    var response = await _open(uri, offset: offset, validator: validator);
    if (offset > 0 && response.statusCode == 416) {
      await _discardResponse(response);
      offset = 0;
      response = await _open(uri);
    }
    if (response.statusCode == 200) {
      offset = 0;
    } else if (offset > 0 && response.statusCode == 206) {
      final range = response.headers.value(HttpHeaders.contentRangeHeader);
      final parsed = range == null
          ? null
          : RegExp(r'^bytes (\d+)-(\d+)/(\d+)$').firstMatch(range);
      if (parsed == null ||
          int.tryParse(parsed.group(1)!) != offset ||
          int.tryParse(parsed.group(3)!) != expectedBytes ||
          int.tryParse(parsed.group(2)!) != expectedBytes! - 1 ||
          (response.contentLength >= 0 &&
              response.contentLength != expectedBytes - offset)) {
        await _discardResponse(response);
        offset = 0;
        response = await _open(uri);
        if (response.statusCode != 200) {
          await _discardResponse(response);
          throw const ApkDownloadException(ApkUpdateFailure.http);
        }
      }
    } else {
      await _discardResponse(response);
      throw const ApkDownloadException(ApkUpdateFailure.http);
    }
    final total =
        expectedBytes ??
        (response.contentLength >= 0 ? response.contentLength : null);
    if (total != null && total > maxApkBytes) {
      await _discardResponse(response);
      throw const ApkDownloadException(ApkUpdateFailure.tooLarge);
    }
    final etag = response.headers.value(HttpHeaders.etagHeader);
    await sidecar.writeAsString(
      jsonEncode({...identity, 'etag': ?etag}),
      flush: true,
    );
    final digestSink = _DigestSink();
    final input = sha256.startChunkedConversion(digestSink);
    RandomAccessFile? handle;
    var received = offset;
    final watch = Stopwatch()..start();
    try {
      if (offset > 0) {
        await for (final chunk in file.openRead(0, offset)) {
          if (_closed || isCancelled()) {
            throw const ApkDownloadException(ApkUpdateFailure.cancelled);
          }
          input.add(chunk);
        }
      }
      handle = await file.open(
        mode: offset > 0 ? FileMode.append : FileMode.write,
      );
      onProgress(received, total);
      await for (final chunk in response.timeout(_inactivity)) {
        if (_closed || isCancelled()) {
          throw const ApkDownloadException(ApkUpdateFailure.cancelled);
        }
        received += chunk.length;
        if (received > maxApkBytes || (total != null && received > total)) {
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
    } on ApkDownloadException catch (error) {
      await handle?.close();
      if (error.failure != ApkUpdateFailure.network &&
          error.failure != ApkUpdateFailure.timeout) {
        await _discard(null, file);
      }
      rethrow;
    } on TimeoutException {
      await handle?.close();
      throw const ApkDownloadException(ApkUpdateFailure.timeout);
    } on FileSystemException catch (error) {
      await handle?.close();
      throw ApkDownloadException(ApkUpdateFailure.storage, error);
    } catch (error) {
      await handle?.close();
      throw ApkDownloadException(ApkUpdateFailure.network, error);
    } finally {
      _activeResponse = null;
    }
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
      if (file.existsSync()) await file.delete();
      final sidecar = File('${file.path}.json');
      if (sidecar.existsSync()) await sidecar.delete();
    } on Object {
      // Best effort: a missing part is already clean.
    }
  }

  Future<HttpClientResponse> _open(
    Uri uri, {
    int offset = 0,
    String? validator,
  }) async {
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
      } on IOException catch (error) {
        throw ApkDownloadException(ApkUpdateFailure.network, error);
      }
      request.followRedirects = false;
      _activeRequest = request;
      if (_cancelRequested) {
        request.abort();
        throw const ApkDownloadException(ApkUpdateFailure.cancelled);
      }
      request.headers.set(HttpHeaders.userAgentHeader, 'CodeWalk');
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      if (offset > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
        if (validator != null) {
          request.headers.set(HttpHeaders.ifRangeHeader, validator);
        }
      }
      final HttpClientResponse response;
      try {
        response = await request.close().timeout(_headerTimeout);
      } on TimeoutException {
        throw const ApkDownloadException(ApkUpdateFailure.timeout);
      } on IOException catch (error) {
        throw ApkDownloadException(ApkUpdateFailure.network, error);
      }
      _activeRequest = null;
      if (_cancelRequested) {
        await _discardResponse(response);
        throw const ApkDownloadException(ApkUpdateFailure.cancelled);
      }
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
    _cancelRequested = true;
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
