import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';

import 'session_projection.dart';
import 'session_reader.dart';
import 'shell_observation.dart';
import 'shell_projection.dart';
import 'version_policy.dart';

const _safeInteger = 9007199254740991;
const _redactionMarginBytes = 4096;
const _maxReconcileGetChecks = 8;
const _reconcileGetBudget = Duration(seconds: 3);

/// Receipt for one deliberate `DELETE /api/shell/:id` stop attempt.
final class OpenCodeShellStopAttempt {
  const OpenCodeShellStopAttempt({
    required this.command,
    required this.receipt,
    this.notFound = false,
  });

  final OriginalCommand command;
  final CommandReceipt receipt;

  /// True when the server returned 404 (the shell already exited/was deleted).
  final bool notFound;
}

/// Bounded HTTP client for OpenCode v2 `/api/shell` routes (`list`, `get`,
/// `output`, `remove`), never reading or surfacing host paths (`file`, `cwd`)
/// or OS `pid`s and always surrogate-validating, bounding, and redacting text.
final class OpenCodeShellClient {
  OpenCodeShellClient(
    this.transport, {
    required this.harness,
    required this.connectedVersion,
    this.deadline = const Duration(seconds: 20),
    this.maxBodyBytes = 256 * 1024,
    this.maxEntries = 256,
    this.maxOutputLimit = 64 * 1024,
  }) {
    if (deadline <= Duration.zero ||
        maxBodyBytes <= 0 ||
        maxEntries <= 0 ||
        maxOutputLimit <= 0) {
      throw ArgumentError('Shell client bounds must be positive.');
    }
  }

  final EndpointHttpTransport transport;
  final HarnessRef harness;
  final String connectedVersion;
  final Duration deadline;
  final int maxBodyBytes;
  final int maxEntries;
  final int maxOutputLimit;

  /// Lists currently running shells for [session] at [directory] (or the
  /// endpoint's default location when null), strictly filtered by
  /// `info.metadata.sessionID == session.nativeId`.
  Future<List<ShellWork>> listRunning({
    required SessionRef session,
    String? directory,
    RequestCancellation? cancellation,
  }) async => (await _listRunningWithLocation(
    session: session,
    directory: directory,
    cancellation: cancellation,
  )).shells;

  Future<({List<ShellWork> shells, String location})> _listRunningWithLocation({
    required SessionRef session,
    String? directory,
    RequestCancellation? cancellation,
  }) async {
    _checkSession(session);
    _checkDirectory(directory);
    final path = Uri(
      path: 'api/shell',
      queryParameters: {'location[directory]': ?directory},
    ).toString();
    final body = await _readJson(path, cancellation: cancellation);
    final (resolvedDir, data) = _unwrapLocation(body, directory);
    if (data is! List || data.length > maxEntries) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.incompatibleResponse,
      );
    }
    final result = <ShellWork>[];
    final seen = <String>{};
    try {
      for (final entry in data) {
        final work = openCodeShellInfoToWork(
          entry,
          session: session,
          sourceVersion: connectedVersion,
          nativeType: 'shell.list',
        );
        if (work != null && seen.add(work.id)) {
          result.add(work);
        }
      }
    } on Object {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.incompatibleResponse,
      );
    }
    return (
      shells: List<ShellWork>.unmodifiable(result),
      location: resolvedDir,
    );
  }

  /// Reconciles running shells for hydration or shell-only refresh, returning
  /// verified per-shell directories and recovering terminal states for up to
  /// [_maxReconcileGetChecks] previously running/unconfirmed shells that left
  /// `/api/shell`.
  ///
  /// All lookup checks execute concurrently under a short shared budget
  /// ([_reconcileGetBudget]) so a slow server never stalls hydration. Only a
  /// confirmed absence (404 or foreign session) drops a missing shell; a
  /// transient lookup error preserves the observation with reduced confidence
  /// (`reconcileUnconfirmed`) so later refreshes can recover it.
  Future<({List<ShellWork> shells, Map<String, String> locations})>
  reconcileHydration({
    required SessionRef session,
    String? directory,
    Iterable<ShellWork> residentShells = const [],
    Map<String, String> knownLocations = const {},
    RequestCancellation? cancellation,
  }) async {
    final listed = await _listRunningWithLocation(
      session: session,
      directory: directory,
      cancellation: cancellation,
    );
    final locations = <String, String>{};
    final runningIds = <String>{};
    for (final shell in listed.shells) {
      runningIds.add(shell.id);
      locations[shell.id] = listed.location;
    }
    final candidates = <ShellWork>[];
    final unchecked = <ShellWork>[];
    for (final prior in residentShells) {
      if (!(prior.isRunning || prior.status.known == null) ||
          runningIds.contains(prior.id)) {
        continue;
      }
      if (candidates.length < _maxReconcileGetChecks) {
        candidates.add(prior);
      } else {
        unchecked.add(prior);
      }
    }
    if (candidates.isEmpty && unchecked.isEmpty) {
      return (
        shells: listed.shells,
        locations: Map<String, String>.unmodifiable(locations),
      );
    }
    final sharedCancel = RequestCancellation();
    final parentSub = cancellation?.onCancel.listen(
      (_) => sharedCancel.cancel(),
    );
    if (cancellation?.isCancelled ?? false) sharedCancel.cancel();
    final budget = deadline < _reconcileGetBudget
        ? deadline
        : _reconcileGetBudget;
    final budgetTimer = Timer(budget, sharedCancel.cancel);
    final recovered = <ShellWork>[];
    ShellWork asUnconfirmed(ShellWork prior) => ShellWork(
      id: prior.id,
      owner: prior.owner,
      command: prior.command,
      status: OpenValue<ShellStatus>.unknown('reconcileUnconfirmed'),
      startedAt: prior.startedAt,
      completedAt: prior.completedAt,
      exitCode: prior.exitCode,
      exitToken: prior.exitToken,
      signal: prior.signal,
      source: prior.source,
    );
    try {
      final results = await Future.wait(
        candidates.map((prior) async {
          final dir = knownLocations[prior.id] ?? directory;
          try {
            final found = await _getShellWithLocation(
              session: session,
              shellId: prior.id,
              directory: dir,
              cancellation: sharedCancel,
            );
            return (prior: prior, dir: dir, found: found, transient: false);
          } on OpenCodeSessionReadException catch (error) {
            if (error.failure == OpenCodeSessionReadFailure.cancelled &&
                (cancellation?.isCancelled ?? false)) {
              rethrow;
            }
            return (prior: prior, dir: dir, found: null, transient: true);
          }
        }),
      );
      for (final item in results) {
        if (item.found != null) {
          recovered.add(item.found!.shell);
          locations[item.found!.shell.id] = item.found!.location;
        } else if (item.transient) {
          recovered.add(asUnconfirmed(item.prior));
          if (item.dir != null) locations[item.prior.id] = item.dir!;
        }
      }
      for (final extra in unchecked) {
        recovered.add(asUnconfirmed(extra));
        final dir = knownLocations[extra.id] ?? directory;
        if (dir != null) locations[extra.id] = dir;
      }
    } finally {
      budgetTimer.cancel();
      unawaited(parentSub?.cancel());
    }
    return (
      shells: List<ShellWork>.unmodifiable([...recovered, ...listed.shells]),
      locations: Map<String, String>.unmodifiable(locations),
    );
  }

  /// Reads one shell record by [shellId], returning `null` on 404 or if the
  /// shell belongs to a different session.
  Future<ShellWork?> getShell({
    required SessionRef session,
    required String shellId,
    String? directory,
    RequestCancellation? cancellation,
  }) async => (await _getShellWithLocation(
    session: session,
    shellId: shellId,
    directory: directory,
    cancellation: cancellation,
  ))?.shell;

  Future<({ShellWork shell, String location})?> _getShellWithLocation({
    required SessionRef session,
    required String shellId,
    String? directory,
    RequestCancellation? cancellation,
  }) async {
    _checkSession(session);
    _checkDirectory(directory);
    final checkedId = _requireShellId(shellId);
    final path = Uri(
      pathSegments: ['api', 'shell', checkedId],
      queryParameters: {'location[directory]': ?directory},
    ).toString();
    final body = await _readJson(
      path,
      cancellation: cancellation,
      allowNotFound: true,
    );
    if (body == null) return null;
    final (resolvedDir, data) = _unwrapLocation(body, directory);
    try {
      final work = openCodeShellInfoToWork(
        data,
        session: session,
        sourceVersion: connectedVersion,
        nativeType: 'shell.get',
      );
      if (work == null) return null;
      return (shell: work, location: resolvedDir);
    } on Object {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.incompatibleResponse,
      );
    }
  }

  /// Pages captured combined output for [shellId] starting at raw byte [cursor]
  /// (default 0) up to [limit] bytes (default 16 KiB, capped at
  /// [maxOutputLimit]). Returns `null` on 404 (shell removed/expired).
  ///
  /// Fetches bounded surrounding context (from byte 0 when
  /// `cursor + limit <= maxOutputLimit`, otherwise a 4 KiB lookbehind plus 4
  /// KiB lookahead) so credentials and multi-line private-key blocks spanning
  /// page boundaries are redacted whole via [redactCredentialSlice]. Returns an
  /// honest raw source byte `cursor` independent of redaction expansion or
  /// display clipping.
  Future<ShellOutputPage?> readOutput({
    required SessionRef session,
    required String shellId,
    String? directory,
    int? cursor,
    int limit = 16 * 1024,
    RequestCancellation? cancellation,
  }) async {
    _checkSession(session);
    _checkDirectory(directory);
    final checkedId = _requireShellId(shellId);
    final rawStart = cursor ?? 0;
    if (rawStart < 0 ||
        rawStart >= maxOutputLimit ||
        limit <= 0 ||
        limit > maxOutputLimit) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidRequest,
      );
    }
    // Always fetch from byte 0 within [maxOutputLimit] + lookahead margin so
    // every page has complete preceding redaction context (including multi-line
    // private-key blocks starting arbitrarily earlier in the bounded window).
    final pageBytes = min(limit, maxOutputLimit - rawStart);
    final requestLimit = rawStart + pageBytes + _redactionMarginBytes;
    return _fetchOutputPage(
      checkedId: checkedId,
      directory: directory,
      requestedCursor: rawStart,
      requestLimit: requestLimit,
      pageBytes: pageBytes,
      cancellation: cancellation,
    );
  }

  /// Convenience alias reading the leading bounded prefix from raw byte 0.
  Future<ShellOutputPage?> readBoundedPrefix({
    required SessionRef session,
    required String shellId,
    String? directory,
    int maxBytes = 16 * 1024,
    RequestCancellation? cancellation,
  }) => readOutput(
    session: session,
    shellId: shellId,
    directory: directory,
    cursor: 0,
    limit: maxBytes,
    cancellation: cancellation,
  );

  Future<ShellOutputPage?> _fetchOutputPage({
    required String checkedId,
    required String? directory,
    required int requestedCursor,
    required int requestLimit,
    required int pageBytes,
    required RequestCancellation? cancellation,
  }) async {
    final path = Uri(
      pathSegments: ['api', 'shell', checkedId, 'output'],
      queryParameters: {
        'location[directory]': ?directory,
        'cursor': '0',
        'limit': '$requestLimit',
      },
    ).toString();
    final body = await _readJson(
      path,
      cancellation: cancellation,
      allowNotFound: true,
    );
    if (body == null) return null;
    final (_, data) = _unwrapLocation(body, directory);
    if (data is! Map<String, Object?>) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.incompatibleResponse,
      );
    }
    final rawOutput = data['output'];
    final rawCursor = data['cursor'];
    final rawSize = data['size'];
    final truncated = data['truncated'];
    if (rawOutput is! String ||
        rawCursor is! num ||
        !rawCursor.isFinite ||
        rawCursor < 0 ||
        rawCursor > _safeInteger ||
        rawCursor != rawCursor.truncate() ||
        rawSize is! num ||
        !rawSize.isFinite ||
        rawSize < 0 ||
        rawSize > _safeInteger ||
        rawSize != rawSize.truncate() ||
        rawCursor > rawSize ||
        truncated is! bool) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.incompatibleResponse,
      );
    }
    final String validatedOutput;
    try {
      validatedOutput = openCodeCheckedShellText(rawOutput, requestLimit);
    } on Object {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.incompatibleResponse,
      );
    }
    final sliceStart = _utf8ByteToCodeUnitIndex(
      validatedOutput,
      requestedCursor,
    );
    final sliceEnd = _utf8ByteToCodeUnitIndex(
      validatedOutput,
      requestedCursor + pageBytes,
    );
    final redactedSlice = redactCredentialSlice(
      validatedOutput,
      sliceStart,
      sliceEnd,
    );
    // Bound to maxOutputLimit (not raw pageBytes) so redaction expansion on a
    // 16 KiB page never drops ordinary trailing text before the next page's
    // raw cursor; callers enforce cumulative display caps.
    final kept = openCodeBoundedText(redactedSlice, maxOutputLimit);
    final serverCursor = rawCursor.toInt();
    final serverSize = rawSize.toInt();
    // Advance cursor honestly in raw source bytes aligned to the exact UTF-8
    // scalar boundary served by [sliceEnd], never landing mid-rune.
    final consumedRawBytes = sliceEnd == validatedOutput.length
        ? serverCursor
        : utf8.encode(validatedOutput.substring(0, sliceEnd)).length;
    final reportedCursor = min(serverCursor, consumedRawBytes);
    return ShellOutputPage(
      output: kept.text,
      cursor: reportedCursor,
      size: serverSize,
      truncated: truncated || kept.cut,
    );
  }

  /// Returns the UTF-16 code-unit index at or immediately before [targetBytes]
  /// UTF-8 bytes in surrogate-validated [text] without splitting a pair.
  int _utf8ByteToCodeUnitIndex(String text, int targetBytes) {
    if (targetBytes <= 0) return 0;
    var bytes = 0;
    for (var i = 0; i < text.length; i++) {
      final unit = text.codeUnitAt(i);
      final pair = unit >= 0xd800 && unit <= 0xdbff && i + 1 < text.length;
      final size = pair ? 4 : (unit < 0x80 ? 1 : (unit < 0x800 ? 2 : 3));
      if (bytes + size > targetBytes) return i;
      bytes += size;
      if (pair) i++;
    }
    return text.length;
  }

  /// Terminates and removes [shellId] via `DELETE /api/shell/:id`.
  ///
  /// Both `204 No Content` and `404 Not Found` settle cleanly (`notFound: true`
  /// on 404 so the caller can drop a stale row without surfacing a failure).
  Future<OpenCodeShellStopAttempt> stop({
    required SessionRef session,
    required String shellId,
    required CommandId id,
    String? directory,
    RequestCancellation? cancellation,
  }) async {
    if (session.harnessRef != harness) {
      throw ArgumentError('Session belongs to another harness.');
    }
    final owner = SessionOwner(session);
    final command = OriginalCommand(
      id: id,
      harness: harness,
      owner: owner,
      operation: const OpenValue.known(MutationOperation.shellStop),
      connectedVersion: connectedVersion,
      intent: CanonicalValue({'shellId': shellId}),
    );
    OpenCodeShellStopAttempt finish(
      CommandReceipt receipt, {
      bool notFound = false,
    }) => OpenCodeShellStopAttempt(
      command: command,
      receipt: receipt,
      notFound: notFound,
    );
    OpenCodeShellStopAttempt unavailable(String reason) => finish(
      CommandReceipt.unavailable(
        id: id,
        owner: owner,
        unavailable: CapabilityUnavailable(
          ShellCapabilities.stop,
          reason: reason,
        ),
      ),
    );
    OpenCodeShellStopAttempt uncertain(String reason) =>
        finish(CommandReceipt.uncertain(id: id, owner: owner, reason: reason));
    OpenCodeShellStopAttempt rejected(ErrorKind kind, String type) => finish(
      CommandReceipt.rejected(
        id: id,
        owner: owner,
        error: ErrorInfo(
          kind: OpenValue.known(kind),
          rawType: type,
          rawMessage: '',
          retryable: false,
        ),
      ),
    );

    if (!OpenCodeCompatibility.supportsV2(connectedVersion)) {
      return unavailable('unverifiedVersion');
    }
    final String checkedId;
    try {
      openCodeSessionId(session.nativeId);
      checkedId = openCodeShellId(shellId);
      if (directory != null &&
          (directory.isEmpty || utf8.encode(directory).length > 4096)) {
        return unavailable('invalidLocation');
      }
    } on Object {
      return unavailable('invalidShellTarget');
    }
    if (cancellation?.isCancelled ?? false) {
      return unavailable('cancelledBeforeSend');
    }
    if (transport.isClosed) return unavailable('closed');

    final token = RequestCancellation();
    final expired = Completer<Never>();
    expired.future.ignore();
    var timedOut = false;
    void cancelNow(TransportFailure failure) {
      token.cancel();
      if (!expired.isCompleted) {
        expired.completeError(TransportException(failure));
      }
    }

    final timer = Timer(deadline, () {
      timedOut = true;
      cancelNow(TransportFailure.timeout);
    });
    final parent = cancellation?.onCancel.listen(
      (_) => cancelNow(TransportFailure.cancelled),
    );
    TransportResponse? response;
    try {
      final path = Uri(
        pathSegments: ['api', 'shell', checkedId],
        queryParameters: {'location[directory]': ?directory},
      ).toString();
      final sending = transport.send(
        TransportRequest(
          method: 'DELETE',
          path: path,
          headers: const {'Accept': 'application/json'},
        ),
        cancellation: token,
      );
      unawaited(
        sending.then((late) {
          if (token.isCancelled) late.cancel();
        }, onError: (Object _) {}),
      );
      final current = await Future.any<TransportResponse>([
        sending,
        expired.future,
      ]);
      response = current;
      return switch (current.statusCode) {
        200 || 204 => finish(CommandReceipt.accepted(id: id, owner: owner)),
        404 => finish(
          CommandReceipt.accepted(id: id, owner: owner),
          notFound: true,
        ),
        400 => rejected(ErrorKind.protocol, 'InvalidRequestError'),
        401 || 403 => rejected(ErrorKind.auth, 'UnauthorizedError'),
        429 => rejected(ErrorKind.rateLimit, 'RateLimited'),
        final status => uncertain('status$status'),
      };
    } on TransportException catch (error) {
      if (timedOut) return uncertain('timeout');
      if (response == null &&
          (error.failure == TransportFailure.invalidTarget ||
              error.failure == TransportFailure.invalidRequest)) {
        return unavailable(error.failure.name);
      }
      return uncertain(error.failure.name);
    } on Object {
      if (timedOut) return uncertain('timeout');
      return uncertain('unexpectedTransportFailure');
    } finally {
      timer.cancel();
      unawaited(parent?.cancel());
      response?.cancel();
    }
  }

  void _checkSession(SessionRef session) {
    if (session.harnessRef != harness) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidScope,
      );
    }
    if (!OpenCodeCompatibility.supportsV2(connectedVersion)) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.incompatibleResponse,
      );
    }
    try {
      openCodeSessionId(session.nativeId);
    } on FormatException {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidRequest,
      );
    }
  }

  void _checkDirectory(String? directory) {
    if (directory != null &&
        (directory.isEmpty || utf8.encode(directory).length > 4096)) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidRequest,
      );
    }
  }

  String _requireShellId(String shellId) {
    try {
      return openCodeShellId(shellId);
    } on Object {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidRequest,
      );
    }
  }

  (String, Object?) _unwrapLocation(Object? body, String? requestedDirectory) {
    if (body is! Map<String, Object?>) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.incompatibleResponse,
      );
    }
    final location = body['location'];
    if (location is! Map<String, Object?> ||
        location['directory'] is! String ||
        (location['directory']! as String).isEmpty) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.incompatibleResponse,
      );
    }
    final dir = location['directory']! as String;
    if (requestedDirectory != null && dir != requestedDirectory) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.incompatibleResponse,
      );
    }
    return (dir, body['data']);
  }

  Future<Object?> _readJson(
    String path, {
    RequestCancellation? cancellation,
    bool allowNotFound = false,
  }) async {
    if (transport.isClosed) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.closed,
      );
    }
    if (cancellation?.isCancelled ?? false) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.cancelled,
      );
    }
    final token = RequestCancellation();
    final expired = Completer<Never>();
    expired.future.ignore();
    var timedOut = false;
    void stopNow(TransportFailure failure) {
      token.cancel();
      if (!expired.isCompleted) {
        expired.completeError(TransportException(failure));
      }
    }

    final timer = Timer(deadline, () {
      timedOut = true;
      stopNow(TransportFailure.timeout);
    });
    final parent = cancellation?.onCancel.listen(
      (_) => stopNow(TransportFailure.cancelled),
    );
    TransportResponse? response;
    try {
      final sending = transport.send(
        TransportRequest(
          method: 'GET',
          path: path,
          headers: const {'Accept': 'application/json'},
        ),
        cancellation: token,
      );
      unawaited(
        sending.then((late) {
          if (token.isCancelled) late.cancel();
        }, onError: (Object _) {}),
      );
      final current = await Future.any<TransportResponse>([
        sending,
        expired.future,
      ]);
      response = current;
      if (current.statusCode == 404 && allowNotFound) return null;
      if (current.statusCode != 200) {
        throw OpenCodeSessionReadException(switch (current.statusCode) {
          400 => OpenCodeSessionReadFailure.invalidRequest,
          401 || 403 => OpenCodeSessionReadFailure.authenticationRequired,
          404 => OpenCodeSessionReadFailure.notFound,
          429 => OpenCodeSessionReadFailure.rateLimited,
          >= 500 && < 600 => OpenCodeSessionReadFailure.unavailable,
          _ => OpenCodeSessionReadFailure.incompatibleResponse,
        });
      }
      final bytes = await Future.any<Uint8List>([
        current.readBytes(maxBytes: maxBodyBytes, inactivityTimeout: deadline),
        expired.future,
      ]);
      return jsonDecode(utf8.decode(bytes));
    } on OpenCodeSessionReadException {
      rethrow;
    } on TransportException catch (error) {
      if (timedOut) {
        throw const OpenCodeSessionReadException(
          OpenCodeSessionReadFailure.timeout,
        );
      }
      throw OpenCodeSessionReadException(switch (error.failure) {
        TransportFailure.cancelled => OpenCodeSessionReadFailure.cancelled,
        TransportFailure.timeout => OpenCodeSessionReadFailure.timeout,
        TransportFailure.closed => OpenCodeSessionReadFailure.closed,
        TransportFailure.invalidTarget || TransportFailure.invalidRequest =>
          OpenCodeSessionReadFailure.invalidRequest,
        _ => OpenCodeSessionReadFailure.connection,
      });
    } on FormatException {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.incompatibleResponse,
      );
    } finally {
      timer.cancel();
      unawaited(parent?.cancel());
      response?.cancel();
    }
  }
}
