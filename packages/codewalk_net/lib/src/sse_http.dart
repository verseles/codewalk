import 'http_transport.dart';
import 'sse_decoder.dart';

/// Open an SSE body without interpreting event JSON or scheduling reconnects.
/// Cancel [cancellation] while waiting for headers; cancelling the returned
/// stream subscription releases the underlying IO body.
Future<Stream<SseFrame>> openSseStream(
  EndpointHttpTransport transport,
  String path, {
  Map<String, String> headers = const {},
  RequestCancellation? cancellation,
  SseDecoder? decoder,
}) async {
  final response = await transport.send(
    TransportRequest(
      method: 'GET',
      path: path,
      headers: {...headers, 'Accept': 'text/event-stream'},
    ),
    cancellation: cancellation,
  );
  if (response.statusCode != 200) {
    response.cancel();
    throw TransportException(
      TransportFailure.unexpectedStatus,
      statusCode: response.statusCode,
    );
  }
  final mediaType = response.header('content-type')?.split(';').first.trim();
  if (mediaType?.toLowerCase() != 'text/event-stream') {
    response.cancel();
    throw const TransportException(TransportFailure.unsupportedContentType);
  }
  return response.body.transform(decoder ?? SseDecoder());
}
