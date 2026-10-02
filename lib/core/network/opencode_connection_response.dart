import 'dart:convert';

import '../errors/exceptions.dart';

Map<String, dynamic> decodeOpenCodeObject(Object? body, String endpoint) {
  if (body is String) {
    try {
      body = jsonDecode(body);
    } on FormatException {
      throw ParseException('Expected OpenCode JSON from $endpoint.');
    }
  }
  if (body is! Map<String, dynamic>) {
    throw ParseException('Expected an OpenCode JSON object from $endpoint.');
  }
  return body;
}

Map<String, dynamic> decodeOpenCodePath(Object? body) {
  final path = decodeOpenCodeObject(body, '/path');
  // The v1 Path contract requires these four strings; keep existing aliases.
  if (path['config'] is! String ||
      path['state'] is! String ||
      (path['worktree'] ?? path['root']) is! String ||
      (path['directory'] ?? path['cwd']) is! String ||
      (path['home'] != null && path['home'] is! String)) {
    throw const ParseException('Invalid OpenCode path response from /path.');
  }
  return path;
}

bool decodeOpenCodeHealth(Object? body) {
  final health = decodeOpenCodeObject(body, '/global/health');
  if (health['healthy'] == false) return false;
  if (health['healthy'] is! bool || health['version'] is! String) {
    throw const ParseException(
      'Invalid OpenCode health response from /global/health.',
    );
  }
  return health['healthy'] as bool;
}
