import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps car descriptor debug-only and receiver non-exported', () {
    final mainManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final debugManifest = File(
      'android/app/src/debug/AndroidManifest.xml',
    ).readAsStringSync();
    final profileManifest = File(
      'android/app/src/profile/AndroidManifest.xml',
    ).readAsStringSync();

    expect(mainManifest, contains('ActionBroadcastReceiver'));
    expect(mainManifest, contains('android:exported="false"'));
    expect(
      mainManifest,
      isNot(contains('com.google.android.gms.car.application')),
    );
    expect(debugManifest, contains('com.google.android.gms.car.application'));
    expect(debugManifest, contains('@xml/automotive_app_desc'));
    expect(profileManifest, isNot(contains('automotive_app_desc')));
    expect(
      File(
        'android/app/src/debug/res/xml/automotive_app_desc.xml',
      ).existsSync(),
      isTrue,
    );
    expect(
      File('android/app/src/main/res/xml/automotive_app_desc.xml').existsSync(),
      isFalse,
    );
  });
}
