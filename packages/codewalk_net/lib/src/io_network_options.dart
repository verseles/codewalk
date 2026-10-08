import 'dart:io' as io;

/// Narrow socket/proxy extension hooks; TLS verification remains SDK-owned.
/// A socket factory must honor non-null proxy host/port supplied by the SDK.
final class IoNetworkOptions {
  const IoNetworkOptions({this.findProxy, this.connectionFactory});

  final String Function(Uri)? findProxy;
  final Future<io.ConnectionTask<io.Socket>> Function(Uri, String?, int?)?
  connectionFactory;

  void apply(io.HttpClient client) {
    if (findProxy != null) client.findProxy = findProxy;
    if (connectionFactory != null) {
      client.connectionFactory = connectionFactory;
    }
  }
}
