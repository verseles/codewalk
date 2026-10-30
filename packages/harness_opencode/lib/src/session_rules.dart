import 'dart:async';
import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';

import 'session_projection.dart';
import 'version_policy.dart';

/// One native 2.0.22 session permission rule. `action` and `resource` are
/// wildcard patterns evaluated upstream; nothing here interprets them.
final class OpenCodePermissionRule {
  const OpenCodePermissionRule({
    required this.action,
    required this.resource,
    required this.effect,
  });

  /// The rule Unrestricted appends: allow every action on every resource.
  static const wildcardAllow = OpenCodePermissionRule(
    action: '*',
    resource: '*',
    effect: 'allow',
  );

  final String action;
  final String resource;
  final String effect;

  bool get isWildcardAllow =>
      action == '*' && resource == '*' && effect == 'allow';

  Map<String, String> toJson() => {
    'action': action,
    'resource': resource,
    'effect': effect,
  };

  @override
  bool operator ==(Object other) =>
      other is OpenCodePermissionRule &&
      other.action == action &&
      other.resource == resource &&
      other.effect == effect;

  @override
  int get hashCode => Object.hash(action, resource, effect);
}

/// A session's own ruleset as read from `Session.Info.permissions`. Upstream
/// evaluates it after the agent rules and the last match wins, so only a
/// trailing wildcard allow is in effect for everything.
final class OpenCodeSessionRules {
  const OpenCodeSessionRules._(this.rules, {required this.recognized});

  /// Never throws: an unexpected shape is unrecognized, so no write is built
  /// from a ruleset that would be re-sent truncated or altered.
  factory OpenCodeSessionRules.parse(Object? permissions) {
    // Never set and cleared both mean no session rules; PATCH can only send
    // `[]` back, and both evaluate the same.
    if (permissions == null) return empty;
    if (permissions is! List || permissions.length > maxRules) {
      return unrecognized;
    }
    final rules = <OpenCodePermissionRule>[];
    for (final row in permissions) {
      if (row is! Map || row.length != 3) return unrecognized;
      final action = row['action'];
      final resource = row['resource'];
      final effect = row['effect'];
      if (!_text(action) || !_text(resource) || !_text(effect)) {
        return unrecognized;
      }
      if (effect != 'allow' && effect != 'deny' && effect != 'ask') {
        return unrecognized;
      }
      rules.add(
        OpenCodePermissionRule(
          action: action as String,
          resource: resource as String,
          effect: effect as String,
        ),
      );
    }
    return OpenCodeSessionRules._(List.unmodifiable(rules), recognized: true);
  }

  static const empty = OpenCodeSessionRules._([], recognized: true);

  static const unrecognized = OpenCodeSessionRules._([], recognized: false);

  /// Local bounds, not upstream limits.
  static const maxRules = 1024;
  static const maxTextBytes = 4096;

  final List<OpenCodePermissionRule> rules;
  final bool recognized;

  bool get endsWithWildcardAllow =>
      recognized && rules.isNotEmpty && rules.last.isWildcardAllow;

  bool get containsWildcardAllow =>
      recognized && rules.any((rule) => rule.isWildcardAllow);

  /// Deterministic encoding in native order, used for fingerprints.
  String get canonical => jsonEncode([for (final rule in rules) rule.toJson()]);

  OpenCodeSessionRules withWildcardAllow() {
    _requireRecognized();
    return OpenCodeSessionRules._(
      List.unmodifiable([...rules, OpenCodePermissionRule.wildcardAllow]),
      recognized: true,
    );
  }

  /// The rules before a trailing wildcard allow, exactly as they were.
  OpenCodeSessionRules withoutTrailingWildcardAllow() {
    if (!endsWithWildcardAllow) {
      throw StateError('No trailing wildcard allow to remove.');
    }
    return OpenCodeSessionRules._(
      List.unmodifiable(rules.sublist(0, rules.length - 1)),
      recognized: true,
    );
  }

  void _requireRecognized() {
    if (!recognized) throw StateError('Unrecognized rules cannot be written.');
  }

  // A lone surrogate would be re-encoded differently, altering the rule.
  static bool _text(Object? value) =>
      value is String &&
      value.length <= maxTextBytes &&
      utf8.encode(value).length <= maxTextBytes &&
      utf8.decode(utf8.encode(value)) == value;
}

/// A receipt for one ruleset replacement, not proof of the stored rules: the
/// caller confirms by reading the session again.
final class OpenCodeSessionRulesAttempt {
  const OpenCodeSessionRulesAttempt({
    required this.command,
    required this.receipt,
  });
  final OriginalCommand command;
  final CommandReceipt receipt;
}

/// Caller-invoked replacement of a session's own permission rules through
/// `PATCH /api/session/{id}`. Upstream replaces the whole array and has no
/// compare-and-set, so the caller must build [rules] from a fresh read. One
/// attempt, never retried; title and metadata are never sent.
final class OpenCodeSessionRulesClient {
  OpenCodeSessionRulesClient(
    this.transport, {
    required this.harness,
    required this.connectedVersion,
    this.deadline = const Duration(seconds: 20),
  }) {
    if (deadline <= Duration.zero) {
      throw ArgumentError('Session rules deadline must be positive.');
    }
  }

  final EndpointHttpTransport transport;
  final HarnessRef harness;
  final String connectedVersion;
  final Duration deadline;

  Future<OpenCodeSessionRulesAttempt> replace({
    required SessionRef session,
    required OpenCodeSessionRules rules,
    required String change,
    required CommandId id,
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
      operation: OpenValue.unknown('sessionPermissions'),
      connectedVersion: connectedVersion,
      intent: CanonicalValue({
        'change': change,
        'ruleCount': rules.rules.length,
      }),
    );
    OpenCodeSessionRulesAttempt finish(CommandReceipt receipt) =>
        OpenCodeSessionRulesAttempt(command: command, receipt: receipt);
    OpenCodeSessionRulesAttempt unavailable(String reason) => finish(
      CommandReceipt.unavailable(
        id: id,
        owner: owner,
        unavailable: CapabilityUnavailable(
          'sessionPermissions',
          reason: reason,
        ),
      ),
    );
    OpenCodeSessionRulesAttempt uncertain(String reason) =>
        finish(CommandReceipt.uncertain(id: id, owner: owner, reason: reason));
    OpenCodeSessionRulesAttempt rejected(
      ErrorKind kind,
      String type, {
      ErrorAction? action,
      bool retryable = false,
    }) => finish(
      CommandReceipt.rejected(
        id: id,
        owner: owner,
        error: ErrorInfo(
          kind: OpenValue.known(kind),
          rawType: type,
          rawMessage: '',
          retryable: retryable,
          action: action == null ? null : OpenValue.known(action),
        ),
      ),
    );
    if (!OpenCodeCompatibility.supportsV2(connectedVersion)) {
      return unavailable('unverifiedVersion');
    }
    try {
      openCodeSessionId(session.nativeId);
    } on FormatException {
      return unavailable('invalidSession');
    }
    if (!rules.recognized) return unavailable('unrecognizedRules');
    if (cancellation?.isCancelled ?? false) {
      return unavailable('cancelledBeforeSend');
    }
    if (transport.isClosed) return unavailable('closed');

    final encoded = jsonEncode({
      'permissions': [for (final rule in rules.rules) rule.toJson()],
    });
    final token = RequestCancellation();
    final expired = Completer<Never>();
    expired.future.ignore();
    var timedOut = false;
    void stop(TransportFailure failure) {
      token.cancel();
      if (!expired.isCompleted) {
        expired.completeError(TransportException(failure));
      }
    }

    final timer = Timer(deadline, () {
      timedOut = true;
      stop(TransportFailure.timeout);
    });
    final parent = cancellation?.onCancel.listen(
      (_) => stop(TransportFailure.cancelled),
    );
    TransportResponse? receipt;
    try {
      final sending = transport.send(
        TransportRequest(
          method: 'PATCH',
          path: Uri(
            pathSegments: ['api', 'session', session.nativeId],
          ).toString(),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: utf8.encode(encoded),
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
      receipt = current;
      return switch (current.statusCode) {
        204 => finish(CommandReceipt.accepted(id: id, owner: owner)),
        400 => rejected(ErrorKind.protocol, 'InvalidRequestError'),
        401 || 403 => rejected(
          ErrorKind.auth,
          'UnauthorizedError',
          action: ErrorAction.authenticate,
        ),
        404 => rejected(
          ErrorKind.protocol,
          'SessionNotFoundError',
          action: ErrorAction.refresh,
        ),
        429 => rejected(ErrorKind.rateLimit, 'RateLimited', retryable: true),
        final status => uncertain('status$status'),
      };
    } on TransportException catch (error) {
      if (timedOut) return uncertain('timeout');
      if (receipt == null &&
          (error.failure == TransportFailure.invalidTarget ||
              error.failure == TransportFailure.invalidRequest)) {
        return unavailable(error.failure.name);
      }
      return uncertain(error.failure.name);
    } on Object {
      return uncertain(timedOut ? 'timeout' : 'unexpectedTransportFailure');
    } finally {
      timer.cancel();
      unawaited(parent?.cancel());
      receipt?.cancel();
    }
  }
}
