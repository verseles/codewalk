import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release requests largeHeap while other variants do not', () {
    final releaseManifest = File(
      'android/app/src/release/AndroidManifest.xml',
    ).readAsStringSync();
    final mainManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final debugManifest = File(
      'android/app/src/debug/AndroidManifest.xml',
    ).readAsStringSync();
    final profileManifest = File(
      'android/app/src/profile/AndroidManifest.xml',
    ).readAsStringSync();

    // Release-only heap headroom for the ~36.7 MB single-message platform
    // allocations that OOM on the default 256 MB growth limit.
    expect(releaseManifest, contains('android:largeHeap="true"'));

    // Other build types keep the default heap so debug stays comparable.
    for (final manifest in <String>[
      mainManifest,
      debugManifest,
      profileManifest,
    ]) {
      expect(manifest, isNot(contains('largeHeap')));
    }

    // The Impeller opt-out was removed: Impeller stays enabled in the main
    // manifest (validated on-device, TM decision), so no manifest may carry
    // the legacy EnableImpeller flag anymore.
    for (final manifest in <String>[
      mainManifest,
      debugManifest,
      profileManifest,
      releaseManifest,
    ]) {
      expect(manifest, isNot(contains('EnableImpeller')));
    }
  });
}
