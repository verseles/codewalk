import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../shared/sessions/project_icon_data.dart';

/// Image URLs never borrow the endpoint's credentials, cookies or transport.
Future<ProjectIconData?> loadNetworkProjectIcon(Uri uri) async {
  if (!isProjectIconNetworkUri(uri)) return null;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    return await _read(client, uri).timeout(const Duration(seconds: 10));
  } on Object {
    return null;
  } finally {
    client.close(force: true);
  }
}

Future<ProjectIconData?> _read(HttpClient client, Uri uri) async {
  for (var redirects = 0; redirects <= 3; redirects++) {
    final request = await client.getUrl(uri);
    request.followRedirects = false;
    request.headers.set(HttpHeaders.acceptHeader, 'image/*');
    final response = await request.close();
    if (response.isRedirect) {
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.listen((_) {}).cancel();
      if (location == null) return null;
      uri = uri.resolve(location);
      if (!isProjectIconNetworkUri(uri)) return null;
      continue;
    }
    if (response.statusCode != HttpStatus.ok ||
        response.contentLength > ProjectIconData.maxBytes) {
      return null;
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response) {
      if (bytes.length + chunk.length > ProjectIconData.maxBytes) return null;
      bytes.add(chunk);
    }
    return ProjectIconData.fromBytes(
      bytes.takeBytes(),
      mediaType: response.headers.contentType?.mimeType,
    );
  }
  return null;
}
