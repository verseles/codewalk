import 'dart:async';
import 'dart:typed_data';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';

/// Header sent on message/inbox reads to opt into `media:<64-hex>` refs when
/// the server enables `experimental.media_blob`.
const openCodeCapabilitiesHeader = 'X-OpenCode-Capabilities';
const openCodeMediaUriCapability = 'experimental-media-uri';

final _mediaRefPattern = RegExp(r'^media:([0-9a-f]{64})$');
final _hexHashPattern = RegExp(r'^[0-9a-f]{64}$');

/// Extracts the 64-character lowercase SHA-256 hex digest from a `media:<hash>`
/// URI, or returns `null` if [uri] is not a strict media reference.
String? openCodeMediaHashFromUri(String? uri) {
  if (uri == null) return null;
  return _mediaRefPattern.firstMatch(uri)?.group(1);
}

/// Bounded in-memory LRU media cache and on-demand reader for OpenCode
/// `GET /api/experimental/media/{hash}` blobs plus inline extracted media.
///
/// Implements [AttachmentFacet] so timeline widgets fetch bytes cleanly without
/// embedding large binaries inside canonical [TimelineItem] state.
final class OpenCodeMediaClient implements AttachmentFacet {
  OpenCodeMediaClient(
    this.transport, {
    this.deadline = const Duration(seconds: 30),
    this.maxReadBytes = 24 * 1024 * 1024,
    this.maxCacheEntries = 24,
    this.maxCacheBytes = 32 * 1024 * 1024,
    Future<AttachmentMedia?> Function(String contentId)? localFallback,
  }) : _localFallback = localFallback {
    if (deadline <= Duration.zero ||
        maxReadBytes <= 0 ||
        maxCacheEntries <= 0 ||
        maxCacheBytes <= 0) {
      throw ArgumentError('Media client bounds must be positive.');
    }
  }

  final EndpointHttpTransport transport;
  final Duration deadline;
  final int maxReadBytes;
  final int maxCacheEntries;
  final int maxCacheBytes;
  final Future<AttachmentMedia?> Function(String contentId)? _localFallback;

  final _cache = <String, AttachmentMedia>{};
  final _inFlight = <String, Future<AttachmentMedia?>>{};
  int _cachedBytes = 0;
  bool _disposed = false;

  /// Returns cached bytes without performing network I/O.
  AttachmentMedia? peek(String contentId) {
    final hit = _cache.remove(contentId);
    if (hit == null) return null;
    _cache[contentId] = hit;
    return hit;
  }

  /// Stores extracted inline bytes under [contentId] within the LRU budget.
  void putInline(String contentId, Uint8List bytes, String mimeType) {
    if (_disposed || bytes.length > maxCacheBytes) return;
    _store(contentId, AttachmentMedia(bytes: bytes, mimeType: mimeType));
  }

  @override
  Future<AttachmentMedia?> read(AttachmentRef ref) async {
    if (_disposed) return null;
    final id = ref.content.id;
    final hit = peek(id);
    if (hit != null) return hit;
    if (_localFallback case final local?) {
      final found = await local(id);
      if (found != null) {
        _store(id, found);
        return found;
      }
    }
    final hash = openCodeMediaHashFromUri(id);
    if (hash == null) return null;
    return fetchByHash(hash, mimeType: ref.mimeType);
  }

  /// Fetches immutable stored media bytes from `GET /api/experimental/media/{hash}`.
  Future<AttachmentMedia?> fetchByHash(
    String hash, {
    String mimeType = 'application/octet-stream',
    RequestCancellation? cancellation,
  }) {
    if (_disposed || !_hexHashPattern.hasMatch(hash)) {
      return Future.value(null);
    }
    final key = 'media:$hash';
    final cached = peek(key);
    if (cached != null) return Future.value(cached);
    final existing = _inFlight[key];
    if (existing != null) return existing;
    final future = _fetch(key, hash, mimeType, cancellation).whenComplete(() {
      _inFlight.remove(key);
    });
    _inFlight[key] = future;
    return future;
  }

  Future<AttachmentMedia?> _fetch(
    String key,
    String hash,
    String fallbackMime,
    RequestCancellation? cancellation,
  ) async {
    if (_disposed || transport.isClosed || (cancellation?.isCancelled ?? false)) {
      return null;
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
      final sending = transport.send(
        TransportRequest(
          method: 'GET',
          path: Uri(
            pathSegments: ['api', 'experimental', 'media', hash],
          ).toString(),
          headers: const {'Accept': '*/*'},
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
      if (current.statusCode != 200) return null;
      final bytes = await Future.any<Uint8List>([
        current.readBytes(maxBytes: maxReadBytes, inactivityTimeout: deadline),
        expired.future,
      ]);
      if (_disposed) return null;
      final headerMime = current
          .header('content-type')
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      final mime =
          (headerMime != null &&
              headerMime.isNotEmpty &&
              headerMime != 'application/octet-stream')
          ? headerMime
          : fallbackMime;
      final media = AttachmentMedia(bytes: bytes, mimeType: mime);
      _store(key, media);
      return media;
    } on Object {
      return null;
    } finally {
      timer.cancel();
      unawaited(parent?.cancel());
      response?.cancel();
    }
  }

  void _store(String key, AttachmentMedia media) {
    final previous = _cache.remove(key);
    if (previous != null) _cachedBytes -= previous.bytes.length;
    if (media.bytes.length > maxCacheBytes) return;
    while (_cache.isNotEmpty &&
        (_cache.length >= maxCacheEntries ||
            _cachedBytes + media.bytes.length > maxCacheBytes)) {
      final oldestKey = _cache.keys.first;
      final evicted = _cache.remove(oldestKey);
      if (evicted != null) _cachedBytes -= evicted.bytes.length;
    }
    _cache[key] = media;
    _cachedBytes += media.bytes.length;
  }

  void dispose() {
    _disposed = true;
    _cache.clear();
    _inFlight.clear();
    _cachedBytes = 0;
  }
}
