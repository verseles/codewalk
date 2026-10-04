import 'package:codewalk/platform/migration/legacy_readers.dart';
import 'package:codewalk/platform/migration/legacy_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class RecordingRawPreferences implements SharedPreferencesAsync {
  RecordingRawPreferences(this.values);
  final Map<String, Object> values;
  final reads = <Set<String>?>[];
  final _failure = [false];
  bool get failRead => _failure.single;
  set failRead(bool value) => _failure[0] = value;

  @override
  Future<Set<String>> getKeys({Set<String>? allowList}) async {
    if (failRead) throw StateError('disposable private native failure');
    return values.keys.where((key) => allowList?.contains(key) ?? true).toSet();
  }

  @override
  Future<Map<String, Object?>> getAll({Set<String>? allowList}) async {
    reads.add(allowList);
    if (failRead) throw StateError('disposable private native failure');
    return {
      for (final entry in values.entries)
        if (allowList?.contains(entry.key) ?? true) entry.key: entry.value,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('No legacy mutation available');
}

void main() {
  test(
    'classic physical prefix maps exact filtered keys without loading values at enumeration',
    () async {
      final original = <String, Object>{
        'flutter.experience_settings':
            '{"composerAutoApprovePermissions":false}',
        'flutter.session_composer_draft::ses%2F1::srv%3A1': '{"text":"draft"}',
        'flutter.canned_answers::srv': '[]',
        'flutter.server_profiles': '[]',
        'flutter.flutter.experience_settings': 'lookalike',
        'flutter.cached_sessions': 'unimported',
        'cw2.settings.themeMode': 'dark',
        'experience_settings': 'wrong-backend-key',
      };
      final plugin = RecordingRawPreferences(Map.of(original));
      final reader = RawLegacyPreferencesReader(
        preferences: plugin,
        physicalPrefix: 'flutter.',
      );
      expect(await reader.keys(), {
        'experience_settings',
        'session_composer_draft::ses%2F1::srv%3A1',
        'canned_answers::srv',
        'server_profiles',
      });
      expect(plugin.reads, isEmpty);
      expect(
        await reader.read('experience_settings'),
        original['flutter.experience_settings'],
      );
      expect(plugin.reads, [
        {'flutter.experience_settings'},
      ]);
      expect(plugin.values, original);
    },
  );

  test(
    'raw unprefixed bridge is explicit, not accidental prefix removal',
    () async {
      final plugin = RecordingRawPreferences({
        'experience_settings': '{}',
        'flutter.experience_settings': 'wrong',
      });
      final reader = RawLegacyPreferencesReader(
        preferences: plugin,
        physicalPrefix: '',
      );
      expect(await reader.keys(), {'experience_settings'});
      expect(await reader.read('experience_settings'), '{}');
      expect(plugin.reads, [
        {'experience_settings'},
      ]);
    },
  );

  test(
    'unsupported cache/native/cw2 keys never query the raw bridge',
    () async {
      final plugin = RecordingRawPreferences({});
      final reader = RawLegacyPreferencesReader(
        preferences: plugin,
        physicalPrefix: 'flutter.',
      );
      for (final key in [
        'cw2.schema',
        'cached_sessions',
        'session_composer_draftish',
        'experience_settings\u0000',
      ]) {
        await expectLater(reader.read(key), throwsArgumentError);
      }
      expect(plugin.reads, isEmpty);
      expect(
        () => RawLegacyPreferencesReader(
          preferences: plugin,
          physicalPrefix: 'other.',
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'character cap refuses source without removing or truncating it',
    () async {
      final plugin = RecordingRawPreferences({
        'flutter.experience_settings': 'ééé',
      });
      final reader = RawLegacyPreferencesReader(
        preferences: plugin,
        physicalPrefix: 'flutter.',
        maxValueChars: 2,
      );
      await expectLater(
        reader.read('experience_settings'),
        throwsA(
          isA<LegacyReadException>().having(
            (error) => error.failure,
            'failure',
            LegacyReadFailure.oversized,
          ),
        ),
      );
      expect(plugin.values['flutter.experience_settings'], 'ééé');
    },
  );

  test(
    'source bridge failures never expose native values and remain retryable',
    () async {
      final plugin = RecordingRawPreferences({'flutter.theme_mode': 'dark'})
        ..failRead = true;
      final reader = RawLegacyPreferencesReader(
        preferences: plugin,
        physicalPrefix: 'flutter.',
      );
      await expectLater(
        reader.read('theme_mode'),
        throwsA(
          isA<LegacyReadException>().having(
            (error) => error.toString(),
            'safe diagnostic',
            isNot(contains('private')),
          ),
        ),
      );
      await expectLater(reader.keys(), throwsA(isA<LegacyReadException>()));
      plugin.failRead = false;
      expect(await reader.read('theme_mode'), 'dark');
    },
  );
}
