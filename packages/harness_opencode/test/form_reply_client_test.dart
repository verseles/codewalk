import 'dart:async';
import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

import 'history_test_data.dart' show historyHarness;

const _id = CommandId('cmd_form_reply');

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
    return handle(request, cancellation);
  }

  @override
  void close() => isClosed = true;
}

TransportResponse _response(int status) => TransportResponse(
  statusCode: status,
  headers: const {},
  body: const Stream.empty(),
  cancel: () {},
);

OpenCodeFormReplyClient _client(
  EndpointHttpTransport transport, {
  String version = '2.0.22',
  Duration deadline = const Duration(seconds: 20),
}) => OpenCodeFormReplyClient(
  transport,
  harness: historyHarness,
  connectedVersion: version,
  deadline: deadline,
);

InteractionRequest _formRequest({
  DomainOwner? owner,
  String formId = 'frm_1053fc672001AtFDTcma2Hwsr4',
}) {
  final session = SessionRef(
    historyHarness.host,
    historyHarness.harness,
    'ses_1053fb81f00162494yM524zGq1',
  );
  return InteractionRequest(
    id: InteractionId(formId),
    owner: owner ?? SessionOwner(session),
    kind: const OpenValue.known(InteractionKind.form),
    title: 'Question',
    form: FormSpec(
      fields: [
        FormField(
          key: 'q0',
          kind: const OpenValue.known(FormFieldKind.string),
          title: 'Color',
          required: true,
        ),
      ],
    ),
    requiresInput: true,
  );
}

void main() {
  test('reply sends POST with answer body and accepts on 204', () async {
    late TransportRequest sent;
    final transport = _Transport((request, _) {
      sent = request;
      return _response(204);
    });
    final client = _client(transport);
    final request = _formRequest();
    final response = FormResponse(
      FormAnswers({'q0': const StringAnswer('Blue')}),
    );

    final attempt = await client.reply(
      request: request,
      response: response,
      id: _id,
    );

    expect(attempt.receipt.state.known, ReceiptState.accepted);
    expect(sent.method, 'POST');
    expect(
      sent.path,
      'api/session/ses_1053fb81f00162494yM524zGq1/form/frm_1053fc672001AtFDTcma2Hwsr4/reply',
    );
    expect(jsonDecode(utf8.decode(sent.body!)), {
      'answer': {'q0': 'Blue'},
    });
  });

  test('dismiss sends DELETE with no body and accepts on 204', () async {
    late TransportRequest sent;
    final transport = _Transport((request, _) {
      sent = request;
      return _response(204);
    });
    final client = _client(transport);
    final request = _formRequest();

    final attempt = await client.dismiss(request: request, id: _id);

    expect(attempt.receipt.state.known, ReceiptState.accepted);
    expect(sent.method, 'DELETE');
    expect(
      sent.path,
      'api/session/ses_1053fb81f00162494yM524zGq1/form/frm_1053fc672001AtFDTcma2Hwsr4',
    );
    expect(sent.body, isNull);
  });

  test('dismiss succeeds even when form spec is null', () async {
    final transport = _Transport((request, _) => _response(204));
    final client = _client(transport);
    final session = SessionRef(
      historyHarness.host,
      historyHarness.harness,
      'ses_1053fb81f00162494yM524zGq1',
    );
    final request = InteractionRequest(
      id: const InteractionId('frm_1053fc672001AtFDTcma2Hwsr4'),
      owner: SessionOwner(session),
      kind: const OpenValue.known(InteractionKind.form),
      title: 'Spec-less Form',
    );

    final attempt = await client.dismiss(request: request, id: _id);
    expect(attempt.receipt.state.known, ReceiptState.accepted);
  });

  test('global owner routes path segment to "global"', () async {
    late TransportRequest sent;
    final transport = _Transport((request, _) {
      sent = request;
      return _response(204);
    });
    final client = _client(transport);
    final request = _formRequest(owner: GlobalOwner(historyHarness));

    final attempt = await client.dismiss(request: request, id: _id);

    expect(attempt.receipt.state.known, ReceiptState.accepted);
    expect(
      sent.path,
      'api/session/global/form/frm_1053fc672001AtFDTcma2Hwsr4',
    );
  });

  test('maps error status codes correctly', () async {
    for (final (status, kind, rawType) in [
      (400, ErrorKind.protocol, 'InvalidRequestError'),
      (401, ErrorKind.auth, 'UnauthorizedError'),
      (403, ErrorKind.auth, 'UnauthorizedError'),
      (404, ErrorKind.protocol, 'NotFoundError'),
      (409, ErrorKind.protocol, 'FormAlreadySettledError'),
      (429, ErrorKind.rateLimit, 'RateLimited'),
    ]) {
      final transport = _Transport((_, _) => _response(status));
      final client = _client(transport);
      final attempt = await client.dismiss(request: _formRequest(), id: _id);
      expect(attempt.receipt.state.known, ReceiptState.rejected);
      expect(attempt.receipt.error?.kind.known, kind);
      expect(attempt.receipt.error?.rawType, rawType);
    }
  });

  test('validates version, requestId, form answers, and cancellation', () async {
    final transport = _Transport((_, _) => _response(204));
    final client = _client(transport, version: '1.0.0');
    final attempt = await client.dismiss(request: _formRequest(), id: _id);
    expect(attempt.receipt.state.known, ReceiptState.unavailable);
    expect(attempt.receipt.unavailable?.reason, 'unverifiedVersion');

    final validClient = _client(transport);
    final invalidId = await validClient.dismiss(
      request: _formRequest(formId: 'not_a_form'),
      id: _id,
    );
    expect(invalidId.receipt.unavailable?.reason, 'invalidRequestId');

    final invalidAnswers = await validClient.reply(
      request: _formRequest(),
      response: FormResponse(FormAnswers({})), // missing required q0
      id: _id,
    );
    expect(invalidAnswers.receipt.unavailable?.reason, 'invalidFormAnswers');

    final cancellation = RequestCancellation();
    cancellation.cancel();
    final cancelled = await validClient.dismiss(
      request: _formRequest(),
      id: _id,
      cancellation: cancellation,
    );
    expect(cancelled.receipt.unavailable?.reason, 'cancelledBeforeSend');
  });
}
