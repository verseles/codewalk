import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

import 'execution_replay_test.dart' show eventLists, refOf;
import 'history_test_data.dart' show historyHarness;
import 'interaction_test_data.dart';
import 'support/fixture_replay.dart';
import 'text_reasoning_test_data.dart' show observedPosition;

const _id = CommandId('cmd_reply');

final class _Transport implements EndpointHttpTransport {
  _Transport(this.handle);
  final FutureOr<TransportResponse> Function(
    TransportRequest,
    RequestCancellation?,
  )
  handle;
  final requests = <TransportRequest>[];
  @override
  Uri endpoint = Uri.parse('http://127.0.0.1/proxy/');
  @override
  bool isClosed = false;
  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    RequestCancellation? cancellation,
  }) async {
    requests.add(request);
    expect(requests, hasLength(1), reason: 'permission replies never replay');
    return handle(request, cancellation);
  }

  @override
  void close() => isClosed = true;
}

TransportResponse _response(
  int status, {
  void Function()? onRead,
  void Function()? onCancel,
}) => TransportResponse(
  statusCode: status,
  headers: const {},
  body: Stream.multi((_) {
    onRead?.call();
  }),
  cancel: onCancel ?? () {},
);

OpenCodePermissionReplyClient _client(
  EndpointHttpTransport transport, {
  String version = '2.0.22',
  Duration deadline = const Duration(seconds: 20),
  int maxNoteBytes = 64 * 1024,
}) => OpenCodePermissionReplyClient(
  transport,
  harness: historyHarness,
  connectedVersion: version,
  deadline: deadline,
  maxNoteBytes: maxNoteBytes,
);

InteractionRequest _ask({List<String>? save = const ['read:*']}) =>
    (projectInteraction(
              interactionFrame('permission.asked', askData(save: save)),
            )
            as InteractionOpened)
        .request;

InteractionRequest _with(
  InteractionRequest request, {
  DomainOwner? owner,
  OpenValue<InteractionKind>? kind,
  List<ApprovalChoice>? choices,
  bool? autoApprovable,
  bool? requiresInput,
  String? requestId,
}) => InteractionRequest(
  id: requestId == null ? request.id : InteractionId(requestId),
  owner: owner ?? request.owner,
  kind: kind ?? request.kind,
  title: request.title,
  choices: choices ?? request.choices,
  subject: request.subject,
  autoApprovable: autoApprovable ?? request.autoApprovable,
  requiresInput: requiresInput ?? request.requiresInput,
);

void main() {
  test(
    'recorded C replies match projected owner, path, exact JSON and status',
    () async {
      const names = [
        'native-interactions',
        'provider-once',
        'provider-always',
        'provider-reject-note-space-bunny-free',
        'provider-reject-none-space-bunny-free',
      ];
      final decisions = <String>{};
      final statuses = <int>{};
      var replayed = 0;
      for (final name in names) {
        final capture =
            jsonDecode(
                  File(
                    '${OpenCodeFixtures().root.path}/c/$name.json',
                  ).readAsStringSync(),
                )
                as Map<String, Object?>;
        final asks = <String, InteractionRequest>{};
        for (final events in eventLists(capture)) {
          for (var i = 0; i < events.length; i++) {
            final frame = events[i];
            if (frame['type'] != 'permission.asked') continue;
            final data = frame['data']! as Map;
            final ref = refOf(data['sessionID']! as String);
            final opened =
                projectOpenCodeInteractionEvent(
                      frame,
                      SessionState(ref),
                      sourceVersion: '2.0.22',
                      position: observedPosition(i + 1),
                      receivedAt: DateTime.utc(2026, 10, 16),
                    )
                    as InteractionOpened;
            asks[opened.request.identityKey] = opened.request;
          }
        }
        for (final raw
            in (capture['calls']! as List).cast<Map<String, Object?>>()) {
          final exchange = FixtureExchange.fromCapture(raw, 'c/$name');
          final segments = exchange.target.pathSegments;
          if (exchange.method != 'POST' ||
              segments.length != 6 ||
              segments[3] != 'permission' ||
              segments.last != 'reply') {
            continue;
          }
          final ref = refOf(segments[2]);
          final key = InteractionRequest(
            id: InteractionId(segments[4]),
            owner: SessionOwner(ref),
            kind: const OpenValue.known(InteractionKind.permission),
            title: '',
          ).identityKey;
          final ask = asks[key];
          // A deliberately nonexistent-ID probe is not an observed pending ask.
          if (ask == null) continue;
          final body = exchange.request! as Map;
          final decision = body['decision']! as String;
          var read = false;
          final transport = _Transport(
            (_, _) => _response(exchange.status, onRead: () => read = true),
          );
          final result = await _client(transport).reply(
            request: ask,
            response: ApprovalResponse(
              decision,
              note: body['message'] as String?,
            ),
            id: _id,
          );
          final sent = transport.requests.single;
          expect(
            exchange.matches(
              sent.method,
              Uri.parse('/${sent.path}'),
              jsonDecode(utf8.decode(sent.body!)),
              sent.body != null,
            ),
            isTrue,
            reason: name,
          );
          expect(result.payload, utf8.decode(sent.body!));
          expect(result.command.owner.hasSameScope(ask.owner), isTrue);
          expect(result.command.operation.known, MutationOperation.respond);
          // Same mapping as the client: listed refusals reject, any other
          // unlisted status stays uncertain instead of accepted.
          expect(
            result.receipt.state.known,
            exchange.status == 204
                ? ReceiptState.accepted
                : const {400, 401, 403, 404, 429}.contains(exchange.status)
                ? ReceiptState.rejected
                : ReceiptState.uncertain,
          );
          expect(read, isFalse);
          decisions.add(decision);
          statuses.add(exchange.status);
          replayed++;
        }
      }
      expect(replayed, greaterThanOrEqualTo(8));
      expect(decisions, {'once', 'always', 'reject'});
      expect(statuses, containsAll([204, 404]));
    },
  );

  test(
    'automatic entry sends exactly eligible once without a note or grant',
    () async {
      final transport = _Transport((_, _) => _response(204));
      final request = _ask();
      final result = await _client(
        transport,
      ).approveOnce(request: request, id: _id);
      expect(result.receipt.state.known, ReceiptState.accepted);
      expect(jsonDecode(utf8.decode(transport.requests.single.body!)), {
        'decision': 'once',
      });
      expect((result.command.intent.value as Map)['automatic'], isTrue);
      expect(transport.requests.single.headers, {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      });
    },
  );

  test(
    'automatic never answers non-eligible/input/unknown interactions',
    () async {
      final ask = _ask();
      final denied = [
        _with(ask, autoApprovable: false),
        _with(ask, requiresInput: true),
        _with(ask, choices: ask.choices.where((c) => c.id != 'once').toList()),
        for (final kind in InteractionKind.values.where(
          (k) => k != InteractionKind.permission,
        ))
          _with(ask, kind: OpenValue.known(kind)),
        _with(ask, kind: OpenValue.unknown('future')),
        _with(ask, owner: UnknownOwner(reason: 'unknown')),
        _with(ask, owner: const GlobalOwner(historyHarness)),
      ];
      for (final request in denied) {
        final transport = _Transport(
          (_, _) => throw StateError('must not send'),
        );
        final result = await _client(
          transport,
        ).approveOnce(request: request, id: _id);
        expect(result.receipt.state.known, ReceiptState.unavailable);
        expect(result.payload, isNull);
        expect(transport.requests, isEmpty);
      }
    },
  );

  test('manual choice does not require automatic eligibility', () async {
    final transport = _Transport((_, _) => _response(204));
    final result = await _client(transport).reply(
      request: _with(_ask(), autoApprovable: false),
      response: ApprovalResponse('once'),
      id: _id,
    );
    expect(result.receipt.state.known, ReceiptState.accepted);
  });

  test(
    'null, empty, whitespace and Unicode notes keep their exact native meaning',
    () async {
      for (final note in [null, '', '  ', 'feedback 漢字 😀\nkeep this']) {
        final transport = _Transport((_, _) => _response(204));
        final result = await _client(transport).reply(
          request: _ask(),
          response: ApprovalResponse('reject', note: note),
          id: _id,
        );
        final body =
            jsonDecode(utf8.decode(transport.requests.single.body!)) as Map;
        expect(body, {'decision': 'reject', 'message': ?note});
        expect(result.receipt.state.known, ReceiptState.accepted);
        expect(
          (result.command.intent.value as Map).containsKey('message'),
          isFalse,
        );
      }
    },
  );

  test(
    'invalid and oversized notes send nothing, never replace UTF16 data',
    () async {
      for (final note in ['abcdef', '😀😀', String.fromCharCode(0xd800)]) {
        final transport = _Transport(
          (_, _) => throw StateError('must not send'),
        );
        final result = await _client(transport, maxNoteBytes: 4).reply(
          request: _ask(),
          response: ApprovalResponse('reject', note: note),
          id: _id,
        );
        expect(result.receipt.state.known, ReceiptState.unavailable);
        expect(result.payload, isNull);
        expect(transport.requests, isEmpty);
      }
    },
  );

  test(
    'unoffered, mismatched and future choice semantics fail closed',
    () async {
      final ask = _ask();
      final bad = [
        for (final (scope, resolution, allows) in [
          (ApprovalScope.persistentProject, ResolutionScope.project, true),
          (ApprovalScope.once, ResolutionScope.request, false),
          (ApprovalScope.once, ResolutionScope.session, true),
        ])
          _with(
            ask,
            choices: [
              ApprovalChoice(
                id: 'once',
                label: 'once',
                allows: allows,
                scope: OpenValue.known(scope),
                resolutionScope: OpenValue.known(resolution),
              ),
            ],
          ),
        _with(
          ask,
          choices: [
            ApprovalChoice(
              id: 'future',
              label: 'once',
              allows: true,
              scope: const OpenValue.known(ApprovalScope.once),
              resolutionScope: const OpenValue.known(ResolutionScope.request),
            ),
          ],
        ),
        _with(
          ask,
          choices: [
            ApprovalChoice(
              id: 'once',
              label: 'once',
              allows: true,
              scope: OpenValue.unknown('future'),
              resolutionScope: const OpenValue.known(ResolutionScope.request),
            ),
          ],
        ),
      ];
      for (final request in bad) {
        final transport = _Transport(
          (_, _) => throw StateError('must not send'),
        );
        final result = await _client(
          transport,
        ).approveOnce(request: request, id: _id);
        expect(result.receipt.state.known, ReceiptState.unavailable);
        expect(transport.requests, isEmpty);
      }
      for (final response in [
        ApprovalResponse('always'),
        ApprovalResponse('future'),
        ApprovalResponse('once', note: 'not allowed'),
      ]) {
        final transport = _Transport(
          (_, _) => throw StateError('must not send'),
        );
        final result = await _client(
          transport,
        ).reply(request: _ask(save: null), response: response, id: _id);
        expect(result.receipt.state.known, ReceiptState.unavailable);
        expect(transport.requests, isEmpty);
      }
    },
  );

  test(
    'manual always requires a nonempty matching native project preview',
    () async {
      final ask = _ask();
      for (final preview in [
        null,
        CanonicalValue({'patterns': []}),
        CanonicalValue({
          'patterns': [''],
        }),
      ]) {
        final request = _with(
          ask,
          choices: [
            ApprovalChoice(
              id: 'always',
              label: 'always',
              allows: true,
              scope: const OpenValue.known(ApprovalScope.persistentProject),
              resolutionScope: const OpenValue.known(ResolutionScope.project),
              scopePreview: preview,
            ),
          ],
        );
        final transport = _Transport(
          (_, _) => throw StateError('must not send'),
        );
        final result = await _client(transport).reply(
          request: request,
          response: ApprovalResponse('always'),
          id: _id,
        );
        expect(result.receipt.state.known, ReceiptState.unavailable);
        expect(transport.requests, isEmpty);
      }
    },
  );

  for (final status in [204, 200, 400, 401, 403, 404, 409, 429, 500, 503]) {
    test(
      'status $status alone decides receipt; no body or resolution inferred',
      () async {
        var read = false;
        var cancelled = false;
        final transport = _Transport(
          (_, _) => _response(
            status,
            onRead: () => read = true,
            onCancel: () => cancelled = true,
          ),
        );
        final result = await _client(
          transport,
        ).reply(request: _ask(), response: ApprovalResponse('once'), id: _id);
        expect(read, isFalse);
        expect(cancelled, isTrue);
        expect(
          result.receipt.state.known,
          status == 204
              ? ReceiptState.accepted
              : [400, 401, 403, 404, 429].contains(status)
              ? ReceiptState.rejected
              : ReceiptState.uncertain,
        );
        expect(result.receipt.error?.rawMessage ?? '', isEmpty);
        if (status == 404) {
          expect(result.receipt.error?.rawType, 'NotFoundError');
          expect(result.receipt.error?.action?.known, ErrorAction.refresh);
        }
      },
    );
  }

  test(
    'preflight version/owner/id/cancel/closed guards perform no request',
    () async {
      final ask = _ask();
      for (final reason in [
        'version',
        'session',
        'request',
        'cancelled',
        'closed',
      ]) {
        final transport = _Transport(
          (_, _) => throw StateError('must not send'),
        );
        final token = RequestCancellation();
        if (reason == 'cancelled') token.cancel();
        if (reason == 'closed') transport.close();
        final request = reason == 'session'
            ? _with(ask, owner: SessionOwner(refOf('bad')))
            : reason == 'request'
            ? _with(ask, requestId: 'bad')
            : ask;
        final result =
            await _client(
              transport,
              version: reason == 'version' ? '3.0.0' : '2.0.22',
            ).reply(
              request: request,
              response: ApprovalResponse('once'),
              id: _id,
              cancellation: token,
            );
        expect(result.receipt.state.known, ReceiptState.unavailable);
        expect(transport.requests, isEmpty);
      }
    },
  );

  test(
    'child and reserved native ids stay in the owning-session path',
    () async {
      final transport = _Transport((_, _) => _response(204));
      final request = _with(
        _ask(),
        owner: SessionOwner(refOf('ses_child/opaque')),
        requestId: 'per_opaque?x',
      );
      await _client(
        transport,
      ).reply(request: request, response: ApprovalResponse('once'), id: _id);
      final uri = Uri.parse(transport.requests.single.path);
      expect(uri.pathSegments, [
        'api',
        'session',
        'ses_child/opaque',
        'permission',
        'per_opaque?x',
        'reply',
      ]);
      expect(uri.hasQuery, isFalse);
    },
  );

  test('wrong harness cannot be redirected through the client', () async {
    final transport = _Transport((_, _) => throw StateError('must not send'));
    final request = _with(
      _ask(),
      owner: const SessionOwner(
        SessionRef(HostId('other'), HarnessInstanceId('other'), 'ses_child'),
      ),
    );
    await expectLater(
      _client(transport).approveOnce(request: request, id: _id),
      throwsArgumentError,
    );
    expect(transport.requests, isEmpty);
  });

  test(
    'timeout is uncertain and disposes a late response without replay',
    () async {
      final pending = Completer<TransportResponse>();
      final transport = _Transport((_, _) => pending.future);
      final result = await _client(
        transport,
        deadline: const Duration(milliseconds: 20),
      ).approveOnce(request: _ask(), id: _id);
      expect(result.receipt.state.known, ReceiptState.uncertain);
      expect(result.receipt.reason, 'timeout');
      var cancelled = false;
      pending.complete(_response(204, onCancel: () => cancelled = true));
      await pumpEventQueue();
      expect(cancelled, isTrue);
    },
  );

  test('cancellation after send is uncertain, not an unsent reply', () async {
    final transport = _Transport(
      (_, _) => Completer<TransportResponse>().future,
    );
    final token = RequestCancellation();
    final pending = _client(
      transport,
    ).approveOnce(request: _ask(), id: _id, cancellation: token);
    await pumpEventQueue();
    token.cancel();
    final result = await pending;
    expect(result.receipt.state.known, ReceiptState.uncertain);
    expect(result.receipt.reason, 'cancelled');
    expect(result.payload, isNotNull);
  });

  test(
    'transport loss keeps uncertainty and payload; pre-wire failure sends nothing',
    () async {
      Future<OpenCodePermissionReplyAttempt> attempt(TransportFailure failure) {
        final transport = _Transport(
          (_, _) => throw TransportException(failure),
        );
        return _client(transport).approveOnce(request: _ask(), id: _id);
      }

      for (final failure in [
        TransportFailure.connection,
        TransportFailure.closed,
      ]) {
        final result = await attempt(failure);
        expect(result.receipt.state.known, ReceiptState.uncertain);
        expect(result.receipt.reason, failure.name);
        expect(result.payload, isNotNull);
      }
      final prewire = await attempt(TransportFailure.invalidTarget);
      expect(prewire.receipt.state.known, ReceiptState.unavailable);
      expect(prewire.receipt.reason, 'invalidTarget');
      expect(prewire.payload, isNull);
    },
  );

  test(
    'default note bound and build-suffixed versions follow the stated contract',
    () async {
      final exact = 'n' * (64 * 1024);
      final accepted = await _client(_Transport((_, _) => _response(204)))
          .reply(
            request: _ask(),
            response: ApprovalResponse('reject', note: exact),
            id: _id,
          );
      expect(accepted.receipt.state.known, ReceiptState.accepted);
      final multibyte = 'é' * (32 * 1024);
      final acceptedWide = await _client(_Transport((_, _) => _response(204)))
          .reply(
            request: _ask(),
            response: ApprovalResponse('reject', note: multibyte),
            id: _id,
          );
      expect(acceptedWide.receipt.state.known, ReceiptState.accepted);
      final refused =
          await _client(
            _Transport((_, _) => throw StateError('must not send')),
          ).reply(
            request: _ask(),
            response: ApprovalResponse('reject', note: '${exact}n'),
            id: _id,
          );
      expect(refused.receipt.state.known, ReceiptState.unavailable);
      expect(refused.payload, isNull);
      for (final version in ['2.0.22', '2.0.22+build.1']) {
        final transport = _Transport((_, _) => _response(204));
        final result = await _client(
          transport,
          version: version,
        ).approveOnce(request: _ask(), id: _id);
        expect(
          result.receipt.state.known,
          ReceiptState.accepted,
          reason: version,
        );
      }
    },
  );
}
