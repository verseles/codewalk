/// Technical comment translated to English.
class ApiConstants {
  // Technical comment translated to English.
  static const String defaultHost = '127.0.0.1';
  static const int defaultPort = 4096;
  static const String defaultBaseUrl = 'http://$defaultHost:$defaultPort';

  // Technical comment translated to English.
  static const String projectEndpoint = '/project';
  static const String providerEndpoint = '/provider';
  static const String configEndpoint = '/config';
  static const String sessionEndpoint = '/session';
  static const String agentEndpoint = '/agent';
  static const String fileEndpoint = '/file';
  static const String findEndpoint = '/find';
  static const String eventEndpoint = '/event';
  static const String authEndpoint = '/auth';
  static const String tuiEndpoint = '/tui';
  static const String logEndpoint = '/log';

  // Technical comment translated to English.
  static const String get = 'GET';
  static const String post = 'POST';
  static const String put = 'PUT';
  static const String patch = 'PATCH';
  static const String delete = 'DELETE';

  // Technical comment translated to English.
  static const String contentType = 'Content-Type';
  static const String applicationJson = 'application/json';
  static const String authorization = 'Authorization';

  // Technical comment translated to English.
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);
  static const Duration sendTimeout = Duration(seconds: 30);
}
