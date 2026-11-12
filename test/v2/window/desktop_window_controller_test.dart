import 'dart:async';

import 'package:codewalk/app/app_preferences_controller.dart';
import 'package:codewalk/app/desktop_window_controller.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';
import 'desktop_window_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<
    ({
      FakeDesktopWindowPort port,
      AppPreferencesController preferences,
      DesktopWindowController window,
      List<String> quits,
    })
  >
  attach({bool hides = true, bool prevents = true}) async {
    final port = FakeDesktopWindowPort(hides: hides, prevents: prevents);
    final preferences = AppPreferencesController(
      store: V2MetadataStore(backend: FakeMetadataBackend()),
    );
    addTearDown(preferences.dispose);
    await preferences.initialize();
    final quits = <String>[];
    final window = DesktopWindowController(
      port: port,
      preferences: preferences,
      quit: () async => quits.add('quit'),
    );
    addTearDown(window.dispose);
    await window.attach();
    return (port: port, preferences: preferences, window: window, quits: quits);
  }

  test('attaching hides the title bar and holds the close request', () async {
    final rig = await attach();
    expect(rig.port.titleBarHidden, [true]);
    expect(rig.port.preventClose, [true]);
    expect(rig.window.active, isTrue);
  });

  test('a refused title bar keeps the system one and no band', () async {
    final rig = await attach(hides: false);
    expect(rig.port.titleBarHidden, [true]);
    expect(rig.window.active, isFalse);
  });

  test('the integrated title bar follows the setting', () async {
    final rig = await attach();
    var notified = 0;
    rig.window.addListener(() => notified++);
    rig.preferences.setIntegratedWindowChrome(false);
    await pumpEventQueue();
    expect(rig.port.titleBarHidden, [true, false]);
    expect(rig.window.active, isFalse);
    rig.preferences.setIntegratedWindowChrome(true);
    await pumpEventQueue();
    expect(rig.port.titleBarHidden, [true, false, true]);
    expect(rig.window.active, isTrue);
    expect(notified, 2);
    // Another preference does not touch the window.
    rig.preferences.setShowSessionTabs(false);
    await pumpEventQueue();
    expect(rig.port.titleBarHidden, hasLength(3));
  });

  test('closing quits by default and minimizes when chosen', () async {
    final rig = await attach();
    rig.port.requestClose();
    await pumpEventQueue();
    expect(rig.quits, ['quit']);
    expect(rig.port.minimized, 0);

    rig.preferences.setWindowCloseAction(WindowCloseAction.minimize);
    rig.port.requestClose();
    await rig.window.requestClose();
    await pumpEventQueue();
    expect(rig.quits, ['quit']);
    expect(rig.port.minimized, 2);
  });

  test('a second close while quitting is the same request', () async {
    final port = FakeDesktopWindowPort();
    final preferences = AppPreferencesController(
      store: V2MetadataStore(backend: FakeMetadataBackend()),
    );
    addTearDown(preferences.dispose);
    await preferences.initialize();
    final exit = Completer<void>();
    var quits = 0;
    final window = DesktopWindowController(
      port: port,
      preferences: preferences,
      quit: () {
        quits++;
        return exit.future;
      },
    );
    addTearDown(window.dispose);
    await window.attach();
    final first = window.requestClose();
    port.requestClose();
    await window.requestClose();
    expect(quits, 1);
    exit.complete();
    await first;
    // A refused exit leaves the window open, and the next close asks again.
    await window.requestClose();
    expect(quits, 2);
  });

  test('a window that cannot hold its close request is not followed', () async {
    final rig = await attach(prevents: false);
    rig.port.requestClose();
    await pumpEventQueue();
    expect(rig.quits, isEmpty);
    // The band's button and the shortcut still follow the choice.
    await rig.window.requestClose();
    expect(rig.quits, ['quit']);
  });

  test('the controls reach the window and dispose releases it', () async {
    final rig = await attach();
    rig.window
      ..minimize()
      ..toggleMaximize()
      ..startDragging();
    await pumpEventQueue();
    expect(rig.port.minimized, 1);
    expect(rig.port.toggled, 1);
    expect(rig.port.drags, 1);
    expect(rig.window.maximized.value, isFalse);
    rig.window.dispose();
    expect(rig.port.disposed, isTrue);
    await rig.window.requestClose();
    rig.preferences.setIntegratedWindowChrome(false);
    await pumpEventQueue();
    expect(rig.quits, isEmpty);
    expect(rig.port.titleBarHidden, [true]);
  });

  test('window choices default, persist and ignore unknown values', () async {
    final backend = FakeMetadataBackend();
    AppPreferencesController controller() =>
        AppPreferencesController(store: V2MetadataStore(backend: backend));
    final first = controller();
    addTearDown(first.dispose);
    await first.initialize();
    expect(first.integratedWindowChrome, isTrue);
    expect(first.windowCloseAction, WindowCloseAction.close);
    expect(backend.writes, ['cw2.schema']);
    first.setIntegratedWindowChrome(false);
    first.setWindowCloseAction(WindowCloseAction.minimize);
    await first.flush();
    expect(backend.values['cw2.settings.integratedWindowChrome'], isFalse);
    expect(backend.values['cw2.settings.windowCloseAction'], 'minimize');

    final second = controller();
    addTearDown(second.dispose);
    await second.initialize();
    expect(second.integratedWindowChrome, isFalse);
    expect(second.windowCloseAction, WindowCloseAction.minimize);
    second.setWindowCloseAction(WindowCloseAction.close);
    second.setIntegratedWindowChrome(true);
    await second.flush();
    expect(
      backend.values.containsKey('cw2.settings.windowCloseAction'),
      isFalse,
    );
    expect(
      backend.values.containsKey('cw2.settings.integratedWindowChrome'),
      isFalse,
    );

    backend.values['cw2.settings.windowCloseAction'] = 'tray';
    final third = controller();
    addTearDown(third.dispose);
    await third.initialize();
    expect(third.windowCloseAction, WindowCloseAction.close);
  });
}
