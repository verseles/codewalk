import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:test/test.dart';

void main() {
  const host = HostId('host');
  const harness = HarnessInstanceId('instance');
  const session = SessionRef(host, harness, 'native');

  group('opaque identifiers', () {
    final cases = <(String, Object Function(Object?), Object)>[
      ('host', HostId.fromJson, const HostId('same')),
      ('harness', HarnessInstanceId.fromJson, const HarnessInstanceId('same')),
      ('item', ItemId.fromJson, const ItemId('same')),
      ('turn', TurnId.fromJson, const TurnId('same')),
      ('command', CommandId.fromJson, const CommandId('same')),
      ('interaction', InteractionId.fromJson, const InteractionId('same')),
      ('work', WorkId.fromJson, const WorkId('same')),
    ];
    for (final (name, decode, expected) in cases) {
      test('$name has value semantics', () {
        final restored = decode('same');
        expect(restored, expected);
        expect(restored.hashCode, expected.hashCode);
      });
      test('$name decoding rejects invalid values with runtime errors', () {
        for (final bad in <Object?>[null, '', 7, true, [], {}]) {
          expect(() => decode(bad), throwsFormatException);
        }
      });
    }
    test('different identifier types cannot merge in a map', () {
      final values = {for (final entry in cases) entry.$3: entry.$1};
      expect(values.length, 7);
      expect(values[const CommandId('same')], 'command');
      expect(values[const ItemId('same')], 'item');
    });
    test(
      'opaque values are preserved without trimming or prefix inference',
      () {
        const literal = ' \u0000é/e\u0301|: " odd-native-ID \n';
        expect(HostId.fromJson(literal).value, literal);
        expect(
          SessionRef.fromJson({
            ...session.toJson(),
            'nativeId': literal,
          }).nativeId,
          literal,
        );
        expect(const ItemId(literal).toJson(), literal);
      },
    );
  });

  group('full session identity', () {
    test('identical native IDs across hosts and instances stay isolated', () {
      const otherHost = SessionRef(HostId('other'), harness, 'native');
      const otherInstance = SessionRef(
        host,
        HarnessInstanceId('other'),
        'native',
      );
      final drafts = {
        session: 'first',
        otherHost: 'second',
        otherInstance: 'third',
      };
      expect(drafts.length, 3);
      expect(drafts[const SessionRef(host, harness, 'native')], 'first');
      expect(
        session.hashCode,
        const SessionRef(host, harness, 'native').hashCode,
      );
      expect(session.harnessRef, const HarnessRef(host, harness));
    });
    test('versioned keys remain unique over separator and Unicode tuples', () {
      const values = ['a', 'a|b', 'b|a', 'é', 'e\u0301', '"[\\]\n\u0000'];
      final keys = <String, SessionRef>{};
      for (final a in values) {
        for (final b in values) {
          for (final c in values) {
            final ref = SessionRef(HostId(a), HarnessInstanceId(b), c);
            expect(keys.containsKey(ref.storageKey), isFalse);
            keys[ref.storageKey] = ref;
            expect(SessionRef.fromStorageKey(ref.storageKey), ref);
          }
        }
      }
      expect(keys.length, values.length * values.length * values.length);
    });
    test('structured serialization restores the complete tuple', () {
      final restored = SessionRef.fromJson(
        jsonDecode(jsonEncode(session.toJson())),
      );
      expect(restored, session);
      expect(restored.hashCode, session.hashCode);
      expect(
        HarnessRef.fromJson(session.harnessRef.toJson()),
        session.harnessRef,
      );
      expect(
        HarnessRef.fromStorageKey(session.harnessRef.storageKey),
        session.harnessRef,
      );
    });
    test('decoding rejects missing, empty and wrongly typed components', () {
      for (final field in ['host', 'harness', 'nativeId']) {
        for (final bad in <Object?>[null, '', 12, [], {}]) {
          expect(
            () => SessionRef.fromJson({...session.toJson(), field: bad}),
            throwsFormatException,
          );
        }
      }
      for (final bad in <Object?>[
        null,
        '',
        [],
        {1: 'value'},
      ]) {
        expect(() => SessionRef.fromJson(bad), throwsFormatException);
      }
    });
    test(
      'key decoding rejects wrong kinds, versions, arity and components',
      () {
        for (final key in [
          'not-json',
          '{}',
          '[]',
          '["session",1,"host","instance"]',
          '["session",1,"host","instance","native","extra"]',
          '["project",1,"host","instance","native"]',
          '["session",2,"host","instance","native"]',
          '["session",1.0,"host","instance","native"]',
          '["session",1,"host","instance",""]',
          '["session",1,"host","instance",null]',
        ]) {
          expect(() => SessionRef.fromStorageKey(key), throwsFormatException);
        }
        expect(
          () => HarnessRef.fromStorageKey(session.storageKey),
          throwsFormatException,
        );
        expect(
          () => ProjectRef.fromStorageKey(session.storageKey),
          throwsFormatException,
        );
      },
    );
    test('unsupported object versions fail explicitly', () {
      for (final version in <Object?>[null, '1', 1.0, 2]) {
        expect(
          () => SessionRef.fromJson({...session.toJson(), 'version': version}),
          throwsFormatException,
        );
        expect(
          () => HarnessRef.fromJson({
            ...session.harnessRef.toJson(),
            'version': version,
          }),
          throwsFormatException,
        );
      }
    });
  });

  group('project identity', () {
    test('upstream project annotation cannot change equality, hash or key', () {
      const plain = ProjectRef(host, '/project');
      const annotated = ProjectRef(
        host,
        '/project',
        upstreamProjectId: 'global',
      );
      const changed = ProjectRef(
        host,
        '/project',
        upstreamProjectId: 'another',
      );
      expect({plain, annotated, changed}.length, 1);
      expect(plain.hashCode, annotated.hashCode);
      expect(plain.storageKey, changed.storageKey);
      final restored = ProjectRef.fromJson(
        jsonDecode(jsonEncode(annotated.toJson())),
      );
      expect(restored, plain);
      expect(restored.upstreamProjectId, 'global');
      expect(
        ProjectRef.fromStorageKey(annotated.storageKey).upstreamProjectId,
        isNull,
      );
    });
    test('same upstream ID cannot merge different hosts or directories', () {
      const projects = [
        ProjectRef(host, '/first', upstreamProjectId: 'global'),
        ProjectRef(host, '/second', upstreamProjectId: 'global'),
        ProjectRef(HostId('other'), '/first', upstreamProjectId: 'global'),
      ];
      expect(projects.toSet().length, 3);
      expect(projects.map((p) => p.storageKey).toSet().length, 3);
    });
    test('host canonical directory stays verbatim', () {
      const paths = [
        'C:\\Project',
        'c:\\project',
        '/a/b',
        '/a//b',
        '/é',
        '/e\u0301',
      ];
      final projects = paths.map((p) => ProjectRef(host, p)).toList();
      expect(projects.toSet().length, paths.length);
      for (final project in projects) {
        expect(
          ProjectRef.fromStorageKey(project.storageKey).canonicalDirectory,
          project.canonicalDirectory,
        );
      }
    });
    test('invalid project fields reject at decoding boundary', () {
      const project = ProjectRef(host, '/project', upstreamProjectId: 'global');
      for (final field in ['host', 'canonicalDirectory', 'upstreamProjectId']) {
        for (final bad in <Object?>['', 4, []]) {
          expect(
            () => ProjectRef.fromJson({...project.toJson(), field: bad}),
            throwsFormatException,
          );
        }
      }
      expect(
        () => ProjectRef.fromJson({
          ...project.toJson(),
          'canonicalDirectory': null,
        }),
        throwsFormatException,
      );
      expect(
        () => ProjectRef.fromJson({...project.toJson(), 'version': 2}),
        throwsFormatException,
      );
    });
  });

  group('independent lineage', () {
    const parent = SessionRef(host, harness, 'parent');
    const fork = ForkLineage(session, beforeItem: ItemId('boundary'));
    test('parent and fork survive serialization independently', () {
      const lineage = SessionLineage(parent: parent, fork: fork);
      final restored = SessionLineage.fromJson(
        jsonDecode(jsonEncode(lineage.toJson())),
      );
      expect(restored, lineage);
      expect(restored.hashCode, lineage.hashCode);
      expect(restored.parent, parent);
      expect(restored.fork?.source, session);
      expect(restored.fork?.beforeItem, const ItemId('boundary'));
      expect(
        const SessionLineage(parent: parent),
        isNot(const SessionLineage(fork: fork)),
      );
    });
    test(
      'empty and partially known lineage are valid without invented links',
      () {
        expect(
          SessionLineage.fromJson(const SessionLineage().toJson()),
          const SessionLineage(),
        );
        const lineage = ForkLineage(session);
        expect(ForkLineage.fromJson(lineage.toJson()), lineage);
        expect(lineage.beforeItem, isNull);
      },
    );
    test('invalid nested identities and boundaries reject at runtime', () {
      expect(
        () => SessionLineage.fromJson({'version': 1, 'parent': {}}),
        throwsFormatException,
      );
      expect(
        () => ForkLineage.fromJson({...fork.toJson(), 'beforeItem': ''}),
        throwsFormatException,
      );
      expect(
        () => ForkLineage.fromJson({...fork.toJson(), 'source': null}),
        throwsFormatException,
      );
    });
  });
}
