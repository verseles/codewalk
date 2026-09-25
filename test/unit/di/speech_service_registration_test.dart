import 'package:codewalk/core/di/injection_container.dart' as di;
import 'package:codewalk/presentation/services/speech_input_service_api.dart';
import 'package:codewalk/presentation/services/speech_model_residency_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('API speech service instances are isolated per composer', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await di.sl.reset();
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await di.sl.reset();
    });
    await di.init();
    expect(di.sl<SpeechModelResidencyController>(), same(SpeechModelResidencyController.instance));

    final first = di.sl<ApiSpeechInputService>();
    final second = di.sl<ApiSpeechInputService>();

    expect(first, isNot(same(second)));
    debugDefaultTargetPlatformOverride = null;
    await di.sl.reset();
  });
}
