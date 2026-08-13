import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/presentation/services/car_messaging/car_messaging_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runs in release when background alerts allow network', () {
    final enabled = ExperienceSettings.defaults();

    expect(
      shouldRunCarMessagingBackground(
        settings: enabled,
        isCellularTransport: false,
      ),
      isTrue,
    );
    expect(
      shouldRunCarMessagingBackground(
        settings: enabled,
        isCellularTransport: true,
      ),
      isFalse,
    );
    final disabled = enabled.copyWith(androidBackgroundAlertsEnabled: false);
    expect(
      shouldRunCarMessagingBackground(
        settings: disabled,
        isCellularTransport: false,
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
