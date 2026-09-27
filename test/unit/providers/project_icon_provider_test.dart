import 'dart:async';

import 'package:codewalk/presentation/providers/project_icon_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/project_icon_fakes.dart';

void main() {
  test(
    'shares successful and failed extraction across identical artwork',
    () async {
      for (final color in [Colors.red, null]) {
        var calls = 0;
        final completer = Completer<Color?>();
        final provider = ProjectIconProvider(
          store: PaletteStore(paletteIcon([1])),
          discoveryService: PaletteDiscovery(),
          extractColor: (_) {
            calls++;
            return completer.future;
          },
        );
        await provider.loadStoredIcon(paletteProject());
        await provider.loadStoredIcon(paletteProject('other'));
        final a = provider.ensureColor(paletteProject());
        final b = provider.ensureColor(paletteProject('other'));
        completer.complete(color);
        await Future.wait([a, b]);
        await provider.ensureColor(paletteProject());
        expect(calls, 1);
        expect(provider.colorFor(paletteProject()), color);
        provider.dispose();
      }
    },
  );

  test('replacement and removal cannot receive an older extraction', () async {
    final stale = Completer<Color?>();
    final discovery = PaletteDiscovery();
    final provider = ProjectIconProvider(
      store: PaletteStore(paletteIcon([1])),
      discoveryService: discovery,
      extractColor: (icon) =>
          icon.bytes.first == 1 ? stale.future : Future.value(Colors.blue),
    );
    final project = paletteProject();
    await provider.loadStoredIcon(project);
    final first = provider.ensureColor(project);
    await Future<void>.delayed(Duration.zero);
    discovery.found(paletteIcon([2]));
    await provider.discoverIcon(project);
    expect(provider.colorFor(project), isNull);
    final next = provider.ensureColor(project);
    stale.complete(Colors.red);
    await Future.wait([first, next]);
    expect(provider.colorFor(project), Colors.blue);
    discovery.result = PaletteDiscovery().result;
    await provider.discoverIcon(project);
    expect(provider.colorFor(project), isNull);
    expect(provider.iconFor(project), isNull);
    provider.dispose();
  });

  test(
    'old disk read cannot overwrite discovery or resurrect a removed icon',
    () async {
      for (final found in [true, false]) {
        final store = PaletteStore(null)..read = Completer();
        final discovery = PaletteDiscovery();
        if (found) discovery.found(paletteIcon([2]));
        final provider = ProjectIconProvider(
          store: store,
          discoveryService: discovery,
        );
        final project = paletteProject();
        final read = provider.loadStoredIcon(project);
        await provider.discoverIcon(project);
        store.read!.complete(paletteIcon([1]));
        await read;
        expect(provider.iconFor(project)?.bytes.first, found ? 2 : null);
        provider.dispose();
      }
    },
  );

  test('reads started during discovery cannot restore old artwork', () async {
    for (final found in [true, false]) {
      final store = PaletteStore(null)..read = Completer();
      final discovery = PaletteDiscovery()..pending = Completer();
      if (found) discovery.found(paletteIcon([2]));
      final provider = ProjectIconProvider(
        store: store,
        discoveryService: discovery,
      );
      final project = paletteProject();
      final discovering = provider.discoverIcon(project);
      final reading = provider.loadStoredIcon(project);
      discovery.pending!.complete(discovery.result);
      await discovering;
      store.read!.complete(paletteIcon([1]));
      await reading;
      expect(provider.iconFor(project)?.bytes.first, found ? 2 : null);
      provider.dispose();
    }
  });

  test('removal prunes excess cached colors without another decode', () async {
    final store = PaletteStore(null);
    final discovery = PaletteDiscovery();
    var extractions = 0;
    final provider = ProjectIconProvider(
      store: store,
      discoveryService: discovery,
      extractColor: (_) async {
        extractions++;
        return Colors.red;
      },
    );
    for (var i = 0; i < 66; i++) {
      store.icon = paletteIcon([i]);
      await provider.loadStoredIcon(paletteProject('$i'));
      await provider.ensureColor(paletteProject('$i'));
    }
    await provider.discoverIcon(paletteProject('0'));
    await provider.discoverIcon(paletteProject('1'));
    discovery.found(paletteIcon([0]));
    await provider.discoverIcon(paletteProject('0'));
    await provider.ensureColor(paletteProject('0'));
    expect(extractions, 67, reason: 'removed palette was evicted immediately');
    provider.dispose();
  });

  test(
    'extraction completing after disposal cannot notify listeners',
    () async {
      final pending = Completer<Color?>();
      final provider = ProjectIconProvider(
        store: PaletteStore(paletteIcon([1])),
        discoveryService: PaletteDiscovery(),
        extractColor: (_) => pending.future,
      );
      await provider.loadStoredIcon(paletteProject());
      var notifications = 0;
      provider.addListener(() => notifications++);
      final color = provider.ensureColor(paletteProject());
      await Future<void>.delayed(Duration.zero);
      provider.dispose();
      pending.complete(Colors.red);
      await color;
      expect(notifications, 0);
    },
  );
}
