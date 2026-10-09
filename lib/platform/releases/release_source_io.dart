import 'dart:async';
import 'dart:convert';

import 'package:codewalk_net/codewalk_net_io.dart';

import '../../shared/releases/release_source.dart';

ReleaseSource createReleaseSource() => NativeReleaseSource();

/// Separate public-origin transport; it has no profile or credential dependency.
final class NativeReleaseSource implements ReleaseSource {
  NativeReleaseSource({EndpointHttpTransport? transport})
    : _transport =
          transport ??
          IoEndpointHttpTransport(
            endpoint: Uri.parse('https://raw.githubusercontent.com'),
            connectionTimeout: const Duration(seconds: 10),
            headerTimeout: const Duration(seconds: 10),
          );

  final EndpointHttpTransport _transport;
  final Set<_NativeTask> _tasks = {};
  bool _closed = false;

  @override
  ReleaseSourceTask start() {
    final task = _NativeTask(this);
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
  _NativeTask(this.owner);
  final NativeReleaseSource owner;
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
      final response = await owner._transport.send(
        TransportRequest(
          method: 'GET',
          path: '/verseles/codewalk/main/CHANGELOG.md',
          headers: const {
            'Accept': 'text/plain',
            'Accept-Encoding': 'identity',
          },
        ),
        cancellation: _cancellation,
      );
      final encoding = response.header('content-encoding');
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
        maxBytes: ReleaseSource.maxBodyBytes,
        inactivityTimeout: const Duration(seconds: 10),
      );
      complete(ReleaseSourceResult.success(utf8.decode(bytes)));
    } on Object {
      complete(
        const ReleaseSourceResult.failure(ReleaseSourceFailure.unavailable),
      );
    }
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
