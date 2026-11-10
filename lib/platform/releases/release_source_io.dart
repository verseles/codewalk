import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io' show HttpDate, HttpException;

import 'package:codewalk_net/codewalk_net_io.dart';

import '../../shared/releases/release_source.dart';
import '../../shared/releases/update_selector.dart';

ReleaseSource createReleaseSource() => NativeReleaseSource();

/// The CodeWalk 2 release asset for this device, if one is published.
UpdateTarget? currentUpdateTarget() => switch (Abi.current()) {
  Abi.androidArm64 => UpdateTarget.androidArm64,
  Abi.linuxX64 => UpdateTarget.linuxX64,
  Abi.linuxArm64 => UpdateTarget.linuxArm64,
  _ => null,
};

ReleaseSource createUpdateSource() => NativeReleaseSource(
  origin: Uri.parse('https://api.github.com'),
  path: ReleaseSource.updatesPath,
  // GitHub's REST API requires a User-Agent.
  headers: const {
    'Accept': 'application/vnd.github+json',
    'Accept-Encoding': 'identity',
    'User-Agent': 'CodeWalk',
  },
  maxBytes: ReleaseSource.maxUpdatesBytes,
  paginateReleases: true,
);

/// Separate public-origin transport; it has no profile or credential dependency.
final class NativeReleaseSource implements ReleaseSource {
  NativeReleaseSource({
    EndpointHttpTransport? transport,
    Uri? origin,
    this.path = '/verseles/codewalk/main/CHANGELOG.md',
    this.headers = const {
      'Accept': 'text/plain',
      'Accept-Encoding': 'identity',
    },
    this.maxBytes = ReleaseSource.maxBodyBytes,
    this.paginateReleases = false,
  }) : _transport =
           transport ??
           IoEndpointHttpTransport(
             endpoint: origin ?? Uri.parse('https://raw.githubusercontent.com'),
             connectionTimeout: const Duration(seconds: 10),
             headerTimeout: const Duration(seconds: 10),
           );

  final EndpointHttpTransport _transport;
  final String path;
  final Map<String, String> headers;
  final int maxBytes;
  final bool paginateReleases;
  final Set<_NativeTask> _tasks = {};
  bool _closed = false;

  @override
  ReleaseSourceTask start({String? until}) {
    final task = _NativeTask(this, until);
    if (_closed) {
      task.complete(
        const ReleaseSourceResult.failure(ReleaseSourceFailure.unavailable),
      );
    } else {
      _tasks.add(task);
      task.run();
    }
    return task;
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    for (final task in _tasks.toList()) {
      task.cancel();
    }
    _transport.close();
  }
}

final class _NativeTask implements ReleaseSourceTask {
  _NativeTask(this.owner, this.until);
  final NativeReleaseSource owner;
  final String? until;
  final _result = Completer<ReleaseSourceResult>();
  final _cancellation = RequestCancellation();
  Timer? _deadline;
  @override
  Future<ReleaseSourceResult> get result => _result.future;

  void run() {
    _deadline = Timer(const Duration(seconds: 30), () {
      _cancellation.cancel();
      complete(const ReleaseSourceResult.failure(ReleaseSourceFailure.timeout));
    });
    unawaited(_read());
  }

  Future<void> _read() async {
    try {
      final releases = <Object?>[];
      var remaining = owner.maxBytes;
      for (var page = 1; ; page++) {
        final response = await owner._transport.send(
          TransportRequest(
            method: 'GET',
            path: owner.paginateReleases
                ? '${owner.path}&page=$page'
                : owner.path,
            headers: owner.headers,
          ),
          cancellation: _cancellation,
        );
        final encoding = response.header('content-encoding');
        if (response.statusCode == 429 ||
            (response.statusCode == 403 &&
                (response.header('x-ratelimit-remaining') == '0' ||
                    response.header('retry-after') != null))) {
          final now = DateTime.now();
          final retry = response.header('retry-after');
          DateTime? retryAt;
          final seconds = int.tryParse(retry ?? '');
          if (seconds != null && seconds >= 0) {
            try {
              retryAt = now.add(Duration(seconds: seconds));
            } on RangeError {
              // An unrepresentable date falls back to the reset header.
            }
          } else if (retry != null) {
            try {
              retryAt = HttpDate.parse(retry);
            } on HttpException {
              /* Use the reset header or fallback below. */
            }
          }
          if (retryAt != null &&
              (retryAt.isBefore(now) ||
                  retryAt.difference(now) > ReleaseSource.maxRetryDelay)) {
            retryAt = null;
          }
          final reset = int.tryParse(
            response.header('x-ratelimit-reset') ?? '',
          );
          if (retryAt == null &&
              reset != null &&
              reset > 0 &&
              reset < 100000000000) {
            retryAt = DateTime.fromMillisecondsSinceEpoch(
              reset * 1000,
              isUtc: true,
            );
          }
          if (retryAt == null ||
              retryAt.isBefore(now) ||
              retryAt.difference(now) > ReleaseSource.maxRetryDelay) {
            retryAt = now.add(const Duration(hours: 1));
          }
          response.cancel();
          complete(
            ReleaseSourceResult.failure(
              ReleaseSourceFailure.rateLimited,
              retryAt: retryAt,
            ),
          );
          return;
        }
        if (_result.isCompleted ||
            response.statusCode != 200 ||
            (encoding != null && encoding.toLowerCase() != 'identity')) {
          response.cancel();
          complete(
            const ReleaseSourceResult.failure(
              ReleaseSourceFailure.invalidResponse,
            ),
          );
          return;
        }
        final bytes = await response.readBytes(
          maxBytes:
              owner.paginateReleases &&
                  remaining > ReleaseSource.maxUpdatePageBytes
              ? ReleaseSource.maxUpdatePageBytes
              : remaining,
          inactivityTimeout: const Duration(seconds: 10),
        );
        if (_result.isCompleted) return;
        final body = utf8.decode(bytes);
        if (!owner.paginateReleases) {
          complete(ReleaseSourceResult.success(body));
          return;
        }
        remaining -= bytes.length;
        final entries = jsonDecode(body);
        if (entries is! List || entries.length > ReleaseSource.updatePageSize) {
          throw const FormatException('Invalid release page');
        }
        releases.addAll(entries);
        // The older pages hold only CodeWalk 1 releases, about 9 KB each.
        if (entries.length < ReleaseSource.updatePageSize ||
            entries.any(
              (release) =>
                  _predatesV2(release) ||
                  (until != null &&
                      release is Map &&
                      release['tag_name'] == until),
            )) {
          complete(ReleaseSourceResult.success(jsonEncode(releases)));
          return;
        }
        if (page >= ReleaseSource.updatePageLimit || remaining <= 0) {
          throw const FormatException('Incomplete bounded release listing');
        }
      }
    } on FormatException {
      complete(
        const ReleaseSourceResult.failure(ReleaseSourceFailure.invalidResponse),
      );
    } on TransportException catch (error) {
      complete(
        ReleaseSourceResult.failure(switch (error.failure) {
          TransportFailure.timeout => ReleaseSourceFailure.timeout,
          TransportFailure.bodyTooLarge ||
          TransportFailure.invalidResponse ||
          TransportFailure.unexpectedStatus ||
          TransportFailure.unsupportedContentType =>
            ReleaseSourceFailure.invalidResponse,
          _ => ReleaseSourceFailure.unavailable,
        }),
      );
    } on Object {
      complete(
        const ReleaseSourceResult.failure(ReleaseSourceFailure.unavailable),
      );
    }
  }

  static bool _predatesV2(Object? release) {
    if (release is! Map) return false;
    final created = release['created_at'];
    final at = created is String ? DateTime.tryParse(created) : null;
    return at != null && at.isBefore(ReleaseSource.v2FirstReleaseCreated);
  }

  void complete(ReleaseSourceResult value) {
    if (_result.isCompleted) return;
    _deadline?.cancel();
    _cancellation.cancel();
    _result.complete(value);
    owner._tasks.remove(this);
  }

  @override
  void cancel() {
    _cancellation.cancel();
    complete(const ReleaseSourceResult.failure(ReleaseSourceFailure.cancelled));
  }
}
