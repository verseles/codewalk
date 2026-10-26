import 'dart:async';

import 'package:codewalk/app/app_dependencies.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/platform/sessions/session_draft_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/platform/storage/payload_store.dart';
import 'package:codewalk/platform/storage/preferences_backend.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../hosts/fakes.dart';
import 'composer_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';

typedef _App = ({
  AppDependencies dependencies,
  CatalogRig rig,
  LiveDirectory directory,
  Map<String, FakeOutbox> outboxes,
});

/// The device's storage outlives the app: every launch of a test, and every
/// store built here, reads the same preferences.
void _useMemoryPreferences() {
  final platform = SharedPreferencesAsyncPlatform.instance;
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  addTearDown(() => SharedPreferencesAsyncPlatform.instance = platform);
}

/// A store on the device's storage, as a relaunched process builds it.
SessionDraftStore _device({PayloadStore Function(PayloadStore)? payloads}) {
  final metadata = V2MetadataStore(backend: PreferencesMetadataBackend());
  final device = PreferencesPayloadStore(metadata);
  return SessionDraftStore(
    payloads: payloads?.call(device) ?? device,
    index: metadata,
  );
}

/// The device's payloads, read only once [open] completes.
final class _SlowPayloads implements PayloadStore {
  _SlowPayloads(this.inner);
  final PayloadStore inner;
  final open = Completer<void>();

  @override
  Future<bool> contains(String key) async {
    await open.future;
    return inner.contains(key);
  }

  @override
  Future<String?> read(String key) => inner.read(key);

  @override
  Future<PayloadWriteResult> write(String key, String value) =>
      inner.write(key, value);

  @override
  Future<void> remove(String key) => inner.remove(key);
}

/// Launches the app on the list with one saved profile, `profile_a`, and
/// the sessions [ids].
Future<_App> _launch(
  WidgetTester tester,
  List<String> ids, {
  SessionDraftStore? drafts,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final rig = CatalogRig();
  addTearDown(rig.dispose);
  await rig.save('a');
  final directory = LiveDirectory();
  final dependencies = createAppDependencies(
    initialLink: Uri.parse('/s/profile_a/ses_${ids.first}'),
    profileRepository: rig.repository,
    endpointProber: FakeProber(),
    sessionCatalogFactory: rig.create,
    sessionLiveDirectory: () => directory,
    draftStore: drafts ?? _device(),
  );
  await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: dependencies));
  await _settle(tester);
  final source = rig.sources.single;
  source.respond([for (final id in ids) source.row(id)]);
  await _settle(tester);
  return (
    dependencies: dependencies,
    rig: rig,
    directory: directory,
    outboxes: <String, FakeOutbox>{},
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

SessionRef _ref(_App app, String id) => app.rig.sources.single.row(id).info.ref;

/// Opens each of [ids] in turn, granting a live lease with an outbox when
/// the session's view opens one, and ends on the last. A session's view
/// shows the items of [prompts] as its sent prompts.
Future<void> _visit(
  WidgetTester tester,
  _App app,
  List<String> ids, {
  Map<String, List<String>> prompts = const {},
}) async {
  for (final id in ids) {
    app.dependencies.router.go('/s/profile_a/ses_$id');
    await _settle(tester);
    final ref = _ref(app, id);
    final opens = app.directory.opens;
    if (opens.isNotEmpty && !opens.last.isCompleted) {
      final outbox = app.outboxes[id] = FakeOutbox();
      final handle = app.directory.grant(ref, outbox: outbox);
      await tester.pump();
      handle.emit(
        SessionLiveView(
          session: ref,
          phase: SessionLivePhase.live,
          state: liveState(
            ref,
            items: [
              for (final (i, text) in (prompts[id] ?? const []).indexed)
                UserInput(
                  meta: liveMeta(ref, 'u$i'),
                  text: text,
                  delivery: const OpenValue.known(DeliveryState.delivered),
                ),
            ],
          ),
        ),
      );
      await _settle(tester);
    }
  }
}

Finder get _field => find.byType(TextField);

String _text(WidgetTester tester) =>
    tester.widget<TextField>(_field).controller!.text;

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_field, text);
  // Past the write delay of the drafts.
  await tester.pump(const Duration(milliseconds: 600));
}

/// Closes the tab of [ref] with a middle click; tabs have no close button.
Future<void> _close(WidgetTester tester, SessionRef ref) async {
  await _middleClick(tester, ref);
  await _settle(tester);
}

Future<void> _middleClick(WidgetTester tester, SessionRef ref) async {
  final tab = find.byKey(ValueKey('session-tab-${ref.storageKey}'));
  await tester.ensureVisible(tab);
  await tester.tap(
    tab,
    kind: PointerDeviceKind.mouse,
    buttons: kMiddleMouseButton,
  );
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

Future<void> _send(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('live-composer-send')));
  await _settle(tester);
}

void main() {
  testWidgets('a draft survives killing and relaunching the app', (
    tester,
  ) async {
    _useMemoryPreferences();
    var app = await _launch(tester, ['one', 'two']);
    await _visit(tester, app, ['one']);
    await _type(tester, 'half a thought');
    final one = _ref(app, 'one');
    // Written while the app still runs: a kill loses nothing typed before.
    expect(await _device().read(one), 'half a thought');

    await tester.pumpWidget(const SizedBox.shrink());
    app = await _launch(tester, ['one', 'two']);
    await _visit(tester, app, ['one']);
    expect(_text(tester), 'half a thought');
    // Another session has its own draft.
    await _visit(tester, app, ['two']);
    expect(_text(tester), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('switching tabs keeps each session\'s draft', (tester) async {
    _useMemoryPreferences();
    final app = await _launch(tester, ['one', 'two']);
    await _visit(tester, app, ['one']);
    await tester.enterText(_field, 'for one');
    await _visit(tester, app, ['two']);
    expect(_text(tester), isEmpty);
    await tester.enterText(_field, 'for two');
    await _visit(tester, app, ['one']);
    expect(_text(tester), 'for one');
    await _visit(tester, app, ['two']);
    expect(_text(tester), 'for two');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an accepted send clears the draft; a refused one keeps it', (
    tester,
  ) async {
    _useMemoryPreferences();
    final app = await _launch(tester, ['one']);
    await _visit(tester, app, ['one']);
    final one = _ref(app, 'one');
    await _type(tester, 'go');
    await _send(tester);
    expect(app.outboxes['one']!.calls.last, endsWith(' go'));
    expect(_text(tester), isEmpty);
    expect(await _device().read(one), isNull);

    app.outboxes['one']!.submitRefusal = 'notPersisted';
    await _type(tester, 'stay');
    await _send(tester);
    expect(_text(tester), 'stay');
    await tester.pump(const Duration(milliseconds: 600));
    expect(await _device().read(one), 'stay');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a send that ends after its tab closed is not a draft again', (
    tester,
  ) async {
    _useMemoryPreferences();
    final app = await _launch(tester, ['one', 'two']);
    await _visit(tester, app, ['one', 'two', 'one']);
    final one = _ref(app, 'one');
    final outbox = app.outboxes['one']!;
    final hold = outbox.holdSubmit = Completer<void>();
    await _type(tester, 'once');
    expect(await _device().read(one), 'once');
    await tester.tap(find.byKey(const ValueKey('live-composer-send')));
    await tester.pump();

    // The tab closes, and its live view with it, while the send is pending.
    await _middleClick(tester, one);
    await _settle(tester);
    hold.complete();
    await _settle(tester);
    expect(
      outbox.calls.where((call) => call.startsWith('submit')),
      hasLength(1),
    );
    expect(await _device().read(one), isNull);

    await _visit(tester, app, ['one']);
    expect(_text(tester), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('closing and reopening a tab keeps its draft', (tester) async {
    _useMemoryPreferences();
    final app = await _launch(tester, ['one', 'two']);
    await _visit(tester, app, ['one', 'two', 'one']);
    await _type(tester, 'kept');
    await _close(tester, _ref(app, 'one'));
    await _visit(tester, app, ['one']);
    expect(_text(tester), 'kept');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('text typed before the saved draft is read is kept', (
    tester,
  ) async {
    _useMemoryPreferences();
    late final _SlowPayloads slow;
    final app = await _launch(tester, [
      'one',
      'two',
    ], drafts: _device(payloads: (device) => slow = _SlowPayloads(device)));
    await _visit(tester, app, ['one', 'two', 'one']);
    await tester.enterText(_field, 'early');
    // The tab closes before its saved draft was read.
    await _close(tester, _ref(app, 'one'));
    slow.open.complete();
    await _settle(tester);
    expect(await _device().read(_ref(app, 'one')), 'early');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final edited in [false, true]) {
    testWidgets('a send that ends after its tab was reopened '
        '${edited ? 'keeps an edited field' : 'leaves the field'}', (
      tester,
    ) async {
      _useMemoryPreferences();
      final app = await _launch(tester, ['one', 'two']);
      await _visit(tester, app, ['one', 'two', 'one']);
      final one = _ref(app, 'one');
      final hold = app.outboxes['one']!.holdSubmit = Completer<void>();
      await _type(tester, 'once');
      await tester.tap(find.byKey(const ValueKey('live-composer-send')));
      await tester.pump();
      await _close(tester, one);

      // Reopened while the send is pending: the saved draft shows again.
      await _visit(tester, app, ['one']);
      expect(_text(tester), 'once');
      if (edited) await _type(tester, 'once more');
      hold.complete();
      await _settle(tester);
      expect(_text(tester), edited ? 'once more' : isEmpty);
      expect(await _device().read(one), edited ? 'once more' : isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  final desktop = TargetPlatformVariant.only(TargetPlatform.linux);

  testWidgets('Up and Down recall the session\'s prompts on a desktop', (
    tester,
  ) async {
    _useMemoryPreferences();
    final app = await _launch(tester, ['one']);
    await _visit(
      tester,
      app,
      ['one'],
      prompts: {
        'one': ['first', '  second  '],
      },
    );
    final one = _ref(app, 'one');
    await _type(tester, 'half');
    await tester.tap(_field);
    await tester.pump();

    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_text(tester), 'second');
    // A recalled prompt is not saved as the draft.
    await tester.pump(const Duration(milliseconds: 600));
    expect(await _device().read(one), 'half');
    await _press(tester, LogicalKeyboardKey.arrowUp);
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_text(tester), 'first');

    // A recalled prompt has its caret at the end, so Down shows the newer.
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_text(tester), 'second');
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_text(tester), 'half');

    // An edited prompt is the draft from then on.
    await _press(tester, LogicalKeyboardKey.arrowUp);
    await _type(tester, 'second, again');
    expect(await _device().read(one), 'second, again');
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_text(tester), 'second, again');
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: desktop);

  testWidgets('Up on a later line of the field moves the caret first', (
    tester,
  ) async {
    _useMemoryPreferences();
    final app = await _launch(tester, ['one']);
    await _visit(
      tester,
      app,
      ['one'],
      prompts: {
        'one': ['first'],
      },
    );
    await _type(tester, 'line one\nline two');
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_text(tester), 'line one\nline two');
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_text(tester), 'first');
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: desktop);

  testWidgets('Up waits until the saved draft was read', (tester) async {
    _useMemoryPreferences();
    late final _SlowPayloads slow;
    final app = await _launch(tester, [
      'one',
      'two',
    ], drafts: _device(payloads: (device) => slow = _SlowPayloads(device)));
    final one = _ref(app, 'one');
    final seed = _device();
    await seed.read(one);
    seed.save(one, 'saved draft');
    await seed.flush();

    await _visit(
      tester,
      app,
      ['one', 'two', 'one'],
      prompts: {
        'one': ['first'],
      },
    );
    await tester.tap(_field);
    await tester.pump();
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_text(tester), isEmpty);

    slow.open.complete();
    await _settle(tester);
    expect(_text(tester), 'saved draft');
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_text(tester), 'first');
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_text(tester), 'saved draft');
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: desktop);

  testWidgets('each session recalls its own prompts', (tester) async {
    _useMemoryPreferences();
    final app = await _launch(tester, ['one', 'two']);
    final prompts = {
      'one': ['for one'],
      'two': ['for two'],
    };
    await _visit(tester, app, ['one', 'two'], prompts: prompts);
    await tester.tap(_field);
    await tester.pump();
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_text(tester), 'for two');

    await _visit(tester, app, ['one']);
    await tester.tap(_field);
    await tester.pump();
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_text(tester), 'for one');
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: desktop);

  testWidgets('a phone has no recall gesture', (tester) async {
    _useMemoryPreferences();
    final app = await _launch(tester, ['one']);
    await _visit(
      tester,
      app,
      ['one'],
      prompts: {
        'one': ['first'],
      },
    );
    await tester.tap(_field);
    await tester.pump();
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_text(tester), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
