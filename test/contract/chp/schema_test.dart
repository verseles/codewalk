@TestOn('vm')
library;

import 'dart:io';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema/json_schema.dart';

import 'model_projection_support.dart';
import 'schema_support.dart';

void main() {
  final revision = readContractObject('revision.json');
  final manifest = readContractObject('examples/manifest.json');
  final entries = (manifest['examples'] as List)
      .map((entry) => Map<String, Object?>.from(entry as Map))
      .toList();

  group('provisional CHP artifact integrity', () {
    test(
      'revision explicitly pins accepted canonical model and pending gates',
      () {
        expect(revision['schemaVersion'], 1);
        expect(revision['canonicalRevision'], provisionalCanonicalRevision);
        expect(revision['canonicalModelCommit'], canonicalModelCommit);
        expect(revision['status'], 'provisional');
        expect(revision['providerExecutions'], 0);
        expect(revision['costUsd'], 0);
        expect((revision['gate'] as Map)['g2'], contains('pending'));
        expect((revision['gate'] as Map)['g5'], contains('pending'));
        expect(manifest['canonicalRevision'], provisionalCanonicalRevision);
        expect(manifest['schemaVersion'], 1);
        expect(manifest['origin'], 'hand-authored');
      },
    );

    test('schema digest belongs to this explicit revision', () {
      final bytes = File('$contractPath/schema.json').readAsBytesSync();
      expect(revision['schemaSha256'], sha256.convert(bytes).toString());
      final manifestBytes = File(
        '$contractPath/examples/manifest.json',
      ).readAsBytesSync();
      expect(
        revision['examplesManifestSha256'],
        sha256.convert(manifestBytes).toString(),
      );
    });

    test('checksum inventory covers the complete current artifact bundle', () {
      final root = Directory(contractPath);
      final covered = <String>{};
      for (final line in File('$contractPath/SHA256SUMS').readAsLinesSync()) {
        final match = RegExp(
          r'^([a-f0-9]{64})  ([a-zA-Z0-9/_.-]+)$',
        ).firstMatch(line);
        expect(match, isNotNull);
        final relative = match!.group(2)!;
        expect(relative.split('/'), isNot(contains('..')));
        expect(covered.add(relative), isTrue);
        expect(
          sha256
              .convert(File('$contractPath/$relative').readAsBytesSync())
              .toString(),
          match.group(1),
          reason: relative,
        );
      }
      final actual = root
          .listSync(recursive: true)
          .whereType<File>()
          .map(
            (file) => file.path
                .substring(root.path.length + 1)
                .replaceAll(Platform.pathSeparator, '/'),
          )
          .where((path) => path != 'SHA256SUMS')
          .toSet();
      expect(covered, actual);
    });

    test('all references are internal and resolve without a provider', () {
      final root = loadRootSchema();
      expect(root[r'$schema'], 'http://json-schema.org/draft-07/schema#');
      final references = _references(root).toList();
      expect(references, isNotEmpty);
      for (final reference in references) {
        expect(reference, startsWith('#/definitions/'));
        expect(_resolve(root, reference), isA<Map>());
      }
      expect(() => JsonSchema.create(root), returnsNormally);
    });

    test('every JSON example appears exactly once in the manifest', () {
      final listed = entries.map((entry) => entry['file'] as String).toList();
      expect(listed.toSet().length, listed.length);
      final actual = Directory('$contractPath/examples')
          .listSync()
          .whereType<File>()
          .map((file) => file.uri.pathSegments.last)
          .where((name) => name.endsWith('.json') && name != 'manifest.json')
          .toSet();
      expect(listed.toSet(), actual);
      for (final entry in entries) {
        expect(entry['file'], matches(r'^[a-zA-Z0-9-]+\.json$'));
        expect(entry['schemaVersion'], 1);
        expect(entry['canonicalRevision'], provisionalCanonicalRevision);
        expect(entry['origin'], 'hand-authored');
        expect(entry['family'], isA<String>());
      }
    });

    test(
      'public frames and every timeline/event variant have valid examples',
      () {
        final names = entries.map((entry) => entry['definition']).toSet();
        for (final frame in revision['publicFrames'] as List) {
          expect(names, contains('#/definitions/$frame'));
        }
        final timelineTypes = <String>{};
        final eventTypes = <String>{};
        for (final entry in entries) {
          final payload = readContractObject('examples/${entry['file']}');
          if (entry['definition'] == '#/definitions/CanonicalTimelineItem') {
            timelineTypes.add(payload['type'] as String);
          }
          if (entry['definition'] == '#/definitions/CanonicalSessionEvent') {
            eventTypes.add(payload['type'] as String);
          }
        }
        expect(timelineTypes, {
          'userInput',
          'assistantText',
          'reasoning',
          'toolCall',
          'shellRun',
          'notice',
          'turnOutcome',
          'unknownItem',
        });
        expect(eventTypes, {
          'itemUpserted',
          'itemDelta',
          'itemsRemoved',
          'executionChanged',
          'retryScheduled',
          'pendingInputChanged',
          'interactionOpened',
          'interactionResolved',
          'workChanged',
          'planChanged',
          'usageObserved',
          'selectionChanged',
          'revertChanged',
          'sessionInfoChanged',
          'resyncRequired',
          'unknownEvent',
        });
        expect(
          entries.map((entry) => entry['family']).toSet(),
          containsAll([
            'identity',
            'ordering',
            'ownership',
            'timeline',
            'interaction',
            'form',
            'work',
            'usage',
            'capability',
            'receipt',
            'snapshot',
            'event',
            'transport',
            'command',
            'unknown',
            'error',
          ]),
        );
      },
    );

    test(
      'definition map covers every named schema without invented model types',
      () {
        final map = readContractObject('definition-map.json');
        expect(map['canonicalModelCommit'], canonicalModelCommit);
        expect(map['canonicalRevision'], provisionalCanonicalRevision);
        final definitions = loadRootSchema()['definitions'] as Map;
        final mapping = map['definitions'] as Map;
        expect(mapping.keys.toSet(), definitions.keys.toSet());
        for (final value in mapping.values) {
          expect((value as Map)['category'], anyOf('canonical', 'transport'));
          expect(value['projection'], isA<String>());
        }
      },
    );
  });

  group('all hand-authored examples', () {
    for (final entry in entries) {
      test('${entry['file']} validates its explicit definition', () {
        final reference = entry['definition'] as String;
        expect(reference, startsWith('#/definitions/'));
        final name = reference.substring('#/definitions/'.length);
        final payload = readContractObject('examples/${entry['file']}');
        final result = validateDefinition(name, payload);
        expect(result.isValid, isTrue, reason: result.errors.toString());
        if (name.startsWith('Chp')) {
          final frameResult = validateDefinition('ChpFrame', payload);
          expect(
            frameResult.isValid,
            isTrue,
            reason: frameResult.errors.toString(),
          );
          expect(payload['canonicalRevision'], provisionalCanonicalRevision);
          if (name == 'ChpEvent') expect(eventRoutingIssues(payload), isEmpty);
        }
      });
    }
  });

  group('meaningful rejected wire shapes', () {
    for (final field in ['schemaVersion', 'canonicalRevision']) {
      test('wrong or absent $field is incompatible', () {
        final baseline = loadExample('chp-ping');
        expect(isValidDefinition('ChpFrame', baseline), isTrue);
        final changed = cloneObject(baseline)
          ..[field] = field == 'schemaVersion' ? 2 : 'other-revision';
        expect(isValidDefinition('ChpFrame', changed), isFalse);
        changed.remove(field);
        expect(isValidDefinition('ChpFrame', changed), isFalse);
      });
    }

    test('opaque identity cannot omit host, harness or native ID', () {
      final baseline = loadExample('identity-session');
      expect(isValidDefinition('CanonicalSessionRef', baseline), isTrue);
      for (final key in ['host', 'harness', 'nativeId']) {
        final changed = cloneObject(baseline)..remove(key);
        expect(isValidDefinition('CanonicalSessionRef', changed), isFalse);
      }
    });

    test('session timeline event rejects a substituted global owner', () {
      final baseline = loadExample('event-itemDelta');
      expect(isValidDefinition('CanonicalSessionEvent', baseline), isTrue);
      final changed = cloneObject(baseline);
      final meta = changed['meta'] as Map;
      meta['owner'] = {
        'type': 'global',
        'harness': (meta['source'] as Map)['harness'],
      };
      expect(isValidDefinition('CanonicalSessionEvent', changed), isFalse);
    });

    test('global interaction retains its real owner', () {
      final interaction = loadExample('interaction-global');
      expect(
        isValidDefinition('CanonicalInteractionRequest', interaction),
        isTrue,
      );
      expect((interaction['owner'] as Map)['type'], 'global');
      expect((interaction['owner'] as Map).containsKey('session'), isFalse);
    });

    test('unknown item cannot be coerced into incomplete assistant text', () {
      final baseline = loadExample('timeline-unknown');
      expect(isValidDefinition('CanonicalTimelineItem', baseline), isTrue);
      final changed = cloneObject(baseline)..['type'] = 'assistantText';
      expect(isValidDefinition('CanonicalTimelineItem', changed), isFalse);
      changed['type'] = 'futureUnwrappedType';
      expect(isValidDefinition('CanonicalTimelineItem', changed), isFalse);
    });

    test('unknown capability cannot inject an effective-availability flag', () {
      final baseline = loadExample('capabilities');
      expect(isValidDefinition('CanonicalCapabilitySet', baseline), isTrue);
      final changed = cloneObject(baseline);
      ((changed['values'] as Map)['future.capability'] as Map)['isAvailable'] =
          true;
      expect(isValidDefinition('CanonicalCapabilitySet', changed), isFalse);
    });

    test('known command payload and session scope are enforced separately', () {
      final baseline = loadExample('chp-command-prompt');
      expect(isValidDefinition('ChpCommand', baseline), isTrue);
      final wrongPayload = cloneObject(baseline);
      (wrongPayload['command'] as Map)['intent'] = {'unexpected': true};
      expect(isValidDefinition('ChpCommand', wrongPayload), isFalse);
      final wrongOwner = cloneObject(baseline);
      final command = wrongOwner['command'] as Map;
      command['owner'] = {'type': 'global', 'harness': command['harness']};
      expect(isValidDefinition('ChpCommand', wrongOwner), isFalse);
      final noId = cloneObject(baseline);
      (noId['command'] as Map).remove('id');
      expect(isValidDefinition('ChpCommand', noId), isFalse);
    });

    test(
      'uncertain admission cannot include an admitted handle or native ref',
      () {
        final receipt = loadExample('receipt-uncertain');
        expect(isValidDefinition('CanonicalCommandReceipt', receipt), isTrue);
        final changed = cloneObject(receipt)..['nativeRef'] = 'fabricated';
        expect(isValidDefinition('CanonicalCommandReceipt', changed), isFalse);
        changed.remove('nativeRef');
        changed['admissionKnown'] = true;
        expect(isValidDefinition('CanonicalCommandReceipt', changed), isFalse);
        final result = loadExample('create-uncertain');
        expect(isValidDefinition('CanonicalCreateResult', result), isTrue);
        result['handleRef'] = loadExample('identity-session');
        expect(isValidDefinition('CanonicalCreateResult', result), isFalse);
      },
    );

    test('duplicate of uncertain remains a valid nonadmitted receipt', () {
      final duplicate = loadExample('receipt-duplicate-uncertain');
      expect(isValidDefinition('CanonicalCommandReceipt', duplicate), isTrue);
      expect(duplicate['admissionKnown'], isFalse);
      duplicate['nativeRef'] = 'fabricated';
      expect(isValidDefinition('CanonicalCommandReceipt', duplicate), isFalse);
    });

    test('duplicate with known admission retains accepted-style fields', () {
      final baseline = loadExample('receipt-accepted')..['state'] = 'duplicate';
      expect(isValidDefinition('CanonicalCommandReceipt', baseline), isTrue);
      for (final field in ['error', 'unavailable', 'reason', 'details']) {
        final changed = cloneObject(baseline);
        changed[field] = switch (field) {
          'error' => loadExample('error'),
          'unavailable' => {'capability': 'forms', 'reason': 'unknown'},
          'reason' => 'fabricatedFailure',
          _ => {'unexpected': true},
        };
        expect(isValidDefinition('CanonicalCommandReceipt', changed), isFalse);
      }
    });

    test('recognized form default types match the canonical field kind', () {
      final baseline = <String, Object?>{
        'key': 'opaque-field',
        'kind': 'integer',
        'required': false,
        'hidden': false,
        'acceptsCustom': false,
        'options': <Object?>[],
        'defaultAnswer': 1,
      };
      expect(isValidDefinition('CanonicalFormField', baseline), isTrue);
      baseline['defaultAnswer'] = 1.5;
      expect(isValidDefinition('CanonicalFormField', baseline), isFalse);
      baseline['kind'] = 'string';
      baseline['defaultAnswer'] = 'valid';
      expect(isValidDefinition('CanonicalFormField', baseline), isTrue);
      baseline['defaultAnswer'] = <String, Object?>{};
      expect(isValidDefinition('CanonicalFormField', baseline), isFalse);
      baseline['kind'] = 'externalLink';
      baseline['externalUrl'] = 'https://example.invalid/synthetic';
      baseline['defaultAnswer'] = null;
      expect(isValidDefinition('CanonicalFormField', baseline), isTrue);
      baseline['defaultAnswer'] = 'inventedInput';
      expect(isValidDefinition('CanonicalFormField', baseline), isFalse);
      baseline['kind'] = 'futureField';
      baseline['defaultAnswer'] = {
        'unknown': [null, false],
      };
      expect(isValidDefinition('CanonicalFormField', baseline), isTrue);
    });

    test(
      'real form constructors agree with recognized default type checks',
      () {
        final integerField = FormField(
          key: 'integer-field',
          kind: const OpenValue.known(FormFieldKind.integer),
          defaultAnswer: const IntegerAnswer(1),
        );
        final stringField = FormField(
          key: 'string-field',
          kind: const OpenValue.known(FormFieldKind.string),
          defaultAnswer: const StringAnswer('exact'),
        );
        final projected = projectForm(
          FormSpec(fields: [integerField, stringField]),
        );
        expect(isValidDefinition('CanonicalFormSpec', projected), isTrue);
        expect(
          () => FormField(
            key: 'integer-field',
            kind: const OpenValue.known(FormFieldKind.integer),
            defaultAnswer: NumberAnswer(1.5),
          ),
          throwsArgumentError,
        );
        expect(
          () => FormField(
            key: 'string-field',
            kind: const OpenValue.known(FormFieldKind.string),
            defaultAnswer: CustomAnswer(CanonicalValue(<String, Object?>{})),
          ),
          throwsArgumentError,
        );
      },
    );

    test('snapshot wrapper cannot omit its own causal boundary', () {
      final baseline = loadExample('snapshot-per-read');
      expect(isValidDefinition('CanonicalSessionSnapshot', baseline), isTrue);
      final changed = cloneObject(baseline);
      (changed['pending'] as Map).remove('boundary');
      expect(isValidDefinition('CanonicalSessionSnapshot', changed), isFalse);
      final other = cloneObject(baseline);
      ((other['timeline'] as Map)['boundary'] as Map).remove('readStart');
      expect(isValidDefinition('CanonicalSessionSnapshot', other), isFalse);
    });

    test('nullable usage and a quota above 100 remain valid observations', () {
      final baseline = loadExample('usage-partial-cumulative');
      expect(isValidDefinition('CanonicalUsageObservation', baseline), isTrue);
      expect((baseline['tokens'] as Map)['output'], isNull);
      expect(
        ((baseline['quotas'] as List).single as Map)['usedPercent'],
        125.5,
      );
      final changed = cloneObject(baseline);
      (changed['tokens'] as Map)['input'] = -1;
      expect(isValidDefinition('CanonicalUsageObservation', changed), isFalse);
    });

    test('subscribe repairs observation and cannot inject command replay', () {
      final baseline = loadExample('chp-subscribe');
      expect(isValidDefinition('ChpSubscribe', baseline), isTrue);
      baseline['replayCommand'] = loadExample('chp-command-prompt');
      expect(isValidDefinition('ChpSubscribe', baseline), isFalse);
    });
  });

  group('semantic routing checks beyond JSON Schema shape', () {
    test('valid routing baseline passes shape and cross-field assertions', () {
      final baseline = loadExample('chp-event-itemDelta');
      expect(isValidDefinition('ChpEvent', baseline), isTrue);
      expect(eventRoutingIssues(baseline), isEmpty);
    });

    test(
      'different envelope session is shape-valid but fails semantic routing',
      () {
        final changed = loadExample('chp-event-itemDelta');
        (changed['session'] as Map)['nativeId'] = 'other-session';
        expect(isValidDefinition('ChpEvent', changed), isTrue);
        expect(
          eventRoutingIssues(changed),
          contains('envelopeSessionMismatch'),
        );
      },
    );

    test(
      'different source harness is shape-valid but fails semantic routing',
      () {
        final changed = loadExample('chp-event-itemDelta');
        final event = changed['event'] as Map;
        (((event['meta'] as Map)['source'] as Map)['harness']
                as Map)['harness'] =
            'other-profile';
        expect(isValidDefinition('ChpEvent', changed), isTrue);
        expect(eventRoutingIssues(changed), contains('sourceHarnessMismatch'));
      },
    );
  });
}

Iterable<String> _references(Object? value) sync* {
  if (value is Map) {
    if (value.containsKey(r'$ref')) yield value[r'$ref'] as String;
    for (final child in value.values) {
      yield* _references(child);
    }
  } else if (value is List) {
    for (final child in value) {
      yield* _references(child);
    }
  }
}

Object? _resolve(Map<String, Object?> root, String reference) {
  Object? current = root;
  for (final segment in reference.substring(2).split('/')) {
    current =
        (current as Map)[segment.replaceAll('~1', '/').replaceAll('~0', '~')];
  }
  return current;
}
