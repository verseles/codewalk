import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/presentation/services/car_messaging/car_messaging_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requires both gates and pauses on cellular Data Saver', () {
    final enabled = ExperienceSettings.defaults().copyWith(
      androidAutoMessagingEnabled: true,
    );

    expect(
      shouldRunCarMessagingBackground(
        settings: enabled,
        isCellularTransport: false,
        featureEnabled: true,
      ),
      isTrue,
    );
    expect(
      shouldRunCarMessagingBackground(
        settings: enabled,
        isCellularTransport: true,
        featureEnabled: true,
      ),
      isFalse,
    );
    expect(
      shouldRunCarMessagingBackground(
        settings: enabled,
        isCellularTransport: false,
        featureEnabled: false,
      ),
      isFalse,
    );
    expect(
      shouldRunCarMessagingBackground(
        settings: enabled,
        isCellularTransport: false,
        featureEnabled: true,
        debugBuild: false,
      ),
      isFalse,
    );
  });

  test('rejects OAuth and Tailscale background profiles', () {
    expect(supportsCarMessagingServerProfile(<String, dynamic>{}), isTrue);
    expect(
      supportsCarMessagingServerProfile(<String, dynamic>{
        'oauthEnabled': true,
      }),
      isFalse,
    );
    expect(
      supportsCarMessagingServerProfile(<String, dynamic>{
        'tailscaleEnabled': true,
      }),
      isFalse,
    );
  });

  test('Basic auth fails closed when either credential is missing', () {
    expect(
      hasRequiredBackgroundBasicCredentials(
        basicAuthEnabled: false,
        username: '',
        password: '',
      ),
      isTrue,
    );
    expect(
      hasRequiredBackgroundBasicCredentials(
        basicAuthEnabled: true,
        username: 'user',
        password: 'secret',
      ),
      isTrue,
    );
    expect(
      hasRequiredBackgroundBasicCredentials(
        basicAuthEnabled: true,
        username: 'user',
        password: '',
      ),
      isFalse,
    );
  });
}
