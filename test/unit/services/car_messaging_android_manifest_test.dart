import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ships car descriptor in release and keeps receiver non-exported', () {
    final mainManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final debugManifest = File(
      'android/app/src/debug/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      RegExp(
        r'<receiver\s+[^>]*android:name="com\.dexterous\.flutterlocalnotifications\.ActionBroadcastReceiver"[^>]*android:exported="false"[^>]*/>',
        dotAll: true,
      ).hasMatch(mainManifest),
      isTrue,
    );
    expect(mainManifest, contains('com.google.android.gms.car.application'));
    expect(mainManifest, contains('@xml/automotive_app_desc'));
    expect(
      debugManifest,
      isNot(contains('com.google.android.gms.car.application')),
    );
    expect(
      File('android/app/src/main/res/xml/automotive_app_desc.xml').existsSync(),
      isTrue,
    );
    expect(
      File(
        'android/app/src/debug/res/xml/automotive_app_desc.xml',
      ).existsSync(),
      isFalse,
    );
  });
}
