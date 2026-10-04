import 'dart:convert';
import 'dart:io';

import 'package:json_schema/json_schema.dart';

const contractPath = 'contracts/codewalk-host-v1';
const provisionalCanonicalRevision = 'cw-canonical-1-provisional.1';
const canonicalModelCommit = 'df3ed903c6c6ed6700ebb1b2fcbb2329db6c2e5e';

Map<String, Object?> readContractObject(String relativePath) =>
    Map<String, Object?>.from(
      jsonDecode(File('$contractPath/$relativePath').readAsStringSync()) as Map,
    );

Map<String, Object?> loadRootSchema() => readContractObject('schema.json');

final _schemas = <String, JsonSchema>{};

JsonSchema schemaFor(String name) => _schemas.putIfAbsent(name, () {
  final root = loadRootSchema();
  final definitions = root['definitions'] as Map;
  if (!definitions.containsKey(name)) {
    throw ArgumentError.value(name, 'name', 'Unknown canonical definition');
  }
  return JsonSchema.create({
    r'$schema': root[r'$schema'],
    'definitions': definitions,
    r'$ref': '#/definitions/$name',
  });
});

ValidationResults validateDefinition(String name, Object? instance) =>
    schemaFor(name).validate(instance, validateFormats: true);

bool isValidDefinition(String name, Object? instance) =>
    validateDefinition(name, instance).isValid;

Map<String, Object?> loadExample(String name) =>
    readContractObject('examples/$name.json');

Map<String, Object?> cloneObject(Map<String, Object?> value) =>
    Map<String, Object?>.from(jsonDecode(jsonEncode(value)) as Map);

/// Cross-field routing checks are separate from JSON Schema shape validation.
/// The real model constructor checks are exercised in model_parity_test.dart.
List<String> eventRoutingIssues(Map<String, Object?> envelope) {
  final event = envelope['event'] as Map;
  final meta = event['meta'] as Map;
  final owner = meta['owner'] as Map;
  final issues = <String>[];
  if (envelope['session'] != null &&
      (owner['type'] != 'session' ||
          !_same(envelope['session'], owner['session']))) {
    issues.add('envelopeSessionMismatch');
  }
  Object? ownerHarness;
  switch (owner['type']) {
    case 'session':
      final session = owner['session'] as Map;
      ownerHarness = {
        'version': 1,
        'host': session['host'],
        'harness': session['harness'],
      };
    case 'project' || 'host' || 'global':
      ownerHarness = owner['harness'];
  }
  final sourceHarness = (meta['source'] as Map)['harness'];
  if (ownerHarness != null && !_same(ownerHarness, sourceHarness)) {
    issues.add('sourceHarnessMismatch');
  }
  return issues;
}

bool _same(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && _same(a[key], b[key]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(a.length, (i) => i).every((i) => _same(a[i], b[i]));
  }
  return a == b;
}
