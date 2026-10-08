import 'dart:async';
import 'dart:convert';

import 'package:codewalk/app/app_preferences_controller.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/shortcuts/shortcut_action.dart';
import 'package:codewalk/shared/shortcuts/shortcut_binding_codec.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppPreferencesController controller(MetadataBackend backend) =>
      AppPreferencesController(store: V2MetadataStore(backend: backend));

  test('portable modifiers and strict chords retain the imported contract', () {
    expect(ShortcutAction.values, hasLength(15));
    expect(
      ShortcutBindingCodec.parse('mod+,', platform: TargetPlatform.macOS)!.meta,
      isTrue,
    );
    expect(
      ShortcutBindingCodec.parse(
        'mod+,',
        platform: TargetPlatform.linux,
      )!.control,
      isTrue,
    );
    expect(
      ShortcutBindingCodec.parse(
        'ctrl+tab',
        platform: TargetPlatform.macOS,
      )!.control,
      isTrue,
    );
    expect(
      ShortcutBindingCodec.parse(
        'ctrl+tab',
        platform: TargetPlatform.macOS,
      )!.meta,
      isFalse,
    );
    expect(ShortcutBindingCodec.parse('mod+,')!.includeRepeats, isFalse);
    for (final binding in [
      '',
      'ctrl',
      'ctrl+a+b',
      'ctrl+ctrl+a',
      'unknown+p',
      'ctrl+',
    ]) {
      expect(ShortcutBindingCodec.parse(binding), isNull, reason: binding);
    }
    expect(
      ShortcutBindingCodec.fingerprint('Shift + Control + P'),
      ShortcutBindingCodec.fingerprint('ctrl+shift+p'),
    );
  });

  test(
    'hydration, edits and resets preserve unknown fields and legacy keys',
    () async {
      final backend = FakeMetadataBackend();
      backend.values.addAll({
        'cw2.schema': 1,
        'cw2.settings.shortcuts': jsonEncode({
          'open_settings': 'alt+x',
          'new_chat': '',
          'future_action': {'binding': 'alt+y', 'revision': 7},
        }),
        'legacy.settings': 'untouched',
      });
      final p = controller(backend);
      addTearDown(p.dispose);
      await p.initialize();
      expect(p.shortcutBindingFor(ShortcutAction.openSettings), 'alt+x');
      expect(p.shortcutBindingFor(ShortcutAction.newChat), '');
      expect(backend.writes, isEmpty);
      p.setShortcutBinding(ShortcutAction.openSettings, 'alt+z');
      await p.flush();
      p.resetAllShortcuts();
      await p.flush();
      expect(jsonDecode(backend.values['cw2.settings.shortcuts']! as String), {
        'future_action': {'binding': 'alt+y', 'revision': 7},
      });
      expect(p.shortcutBindingFor(ShortcutAction.openSettings), 'mod+,');
      expect(backend.values['legacy.settings'], 'untouched');
      expect(backend.writes.toSet(), {'cw2.settings.shortcuts'});
    },
  );

  test(
    'empty unassign differs from reset, and aliases conflict physically',
    () async {
      final backend = FakeMetadataBackend()..values['cw2.schema'] = 1;
      final p = controller(backend);
      addTearDown(p.dispose);
      await p.initialize();
      expect(
        p.shortcutConflict(ShortcutAction.openSettings, 'ctrl+n'),
        ShortcutAction.newChat,
      );
      expect(
        () => p.setShortcutBinding(ShortcutAction.openSettings, 'ctrl+n'),
        throwsArgumentError,
      );
      p.setShortcutBinding(ShortcutAction.newChat, '');
      p.setShortcutBinding(ShortcutAction.openSettings, 'ctrl+n');
      await p.flush();
      p.setShortcutBinding(ShortcutAction.newChat, null);
      await p.flush();
      expect(
        p.shortcutConflict(ShortcutAction.openSettings, 'ctrl+n'),
        ShortcutAction.newChat,
      );
      p.resetAllShortcuts();
      await p.flush();
      expect(backend.values.containsKey('cw2.settings.shortcuts'), isFalse);
      expect(p.shortcutBindingFor(ShortcutAction.newChat), 'mod+n');
    },
  );

  test(
    'unreadable metadata survives an edit and retry merges repaired data',
    () async {
      final backend = FakeMetadataBackend()
        ..values.addAll({'cw2.schema': 1, 'cw2.settings.shortcuts': '{broken'});
      final p = controller(backend);
      addTearDown(p.dispose);
      await p.initialize();
      expect(p.hasPersistenceError, isTrue);
      p.setShortcutBinding(ShortcutAction.openSettings, 'alt+x');
      await p.flush();
      expect(backend.values['cw2.settings.shortcuts'], '{broken');
      backend.values['cw2.settings.shortcuts'] = jsonEncode({'future': 'kept'});
      await p.retryPersistence();
      expect(p.hasPersistenceError, isFalse);
      expect(jsonDecode(backend.values['cw2.settings.shortcuts']! as String), {
        'future': 'kept',
        'open_settings': 'alt+x',
      });
    },
  );

  test(
    'invalid known bindings stay inactive without rewriting stored values',
    () async {
      final backend = FakeMetadataBackend()
        ..values.addAll({
          'cw2.schema': 1,
          'cw2.settings.shortcuts': jsonEncode({
            'open_settings': 'ctrl+a+b',
            'refresh': 42,
          }),
        });
      final p = controller(backend);
      addTearDown(p.dispose);
      await p.initialize();
      expect(p.shortcutIsInvalid(ShortcutAction.openSettings), isTrue);
      expect(p.shortcutIsInvalid(ShortcutAction.refresh), isTrue);
      expect(backend.writes, isEmpty);
    },
  );

  for (final dispose in [false, true]) {
    test(
      'edit racing hydration preserves unknown fields; disposal=$dispose',
      () async {
        final backend = _DelayedReadBackend();
        backend.inner.values.addAll({
          'cw2.schema': 1,
          'cw2.settings.shortcuts': jsonEncode({
            'open_settings': 'alt+y',
            'future': 'kept',
          }),
        });
        final p = controller(backend);
        final loading = p.initialize();
        await backend.entered.future;
        p.setShortcutBinding(ShortcutAction.openSettings, 'alt+x');
        if (dispose) p.dispose();
        backend.release.complete();
        await loading;
        await p.flush();
        expect(
          jsonDecode(backend.inner.values['cw2.settings.shortcuts']! as String),
          {'future': 'kept', 'open_settings': 'alt+x'},
        );
        if (!dispose) p.dispose();
      },
    );
  }

  test(
    'failed writes remain visible and retry saves the current choice',
    () async {
      final backend = FakeMetadataBackend()..values['cw2.schema'] = 1;
      final p = controller(backend);
      addTearDown(p.dispose);
      await p.initialize();
      backend.failWrite = 'cw2.settings.shortcuts';
      p.setShortcutBinding(ShortcutAction.openSettings, 'alt+x');
      await p.flush();
      expect(p.hasPersistenceError, isTrue);
      backend.failWrite = null;
      p.setShortcutBinding(ShortcutAction.openSettings, 'alt+y');
      await p.retryPersistence();
      expect(p.hasPersistenceError, isFalse);
      expect(jsonDecode(backend.values['cw2.settings.shortcuts']! as String), {
        'open_settings': 'alt+y',
      });
    },
  );
}

class _DelayedReadBackend implements MetadataBackend {
  final inner = FakeMetadataBackend();
  final entered = Completer<void>();
  final release = Completer<void>();
  bool _blocked = false;

  @override
  Future<Object?> read(String key) async {
    final snapshot = await inner.read(key);
    if (key == 'cw2.settings.shortcuts' && !_blocked) {
      _blocked = true;
      entered.complete();
      await release.future;
    }
    return snapshot;
  }

  @override
  Future<void> write(String key, Object value) => inner.write(key, value);
  @override
  Future<void> remove(String key) => inner.remove(key);
}
