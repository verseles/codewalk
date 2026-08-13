import 'package:flutter/foundation.dart';

import '../../../domain/entities/experience_settings.dart';
import '../android_background_alert_logic.dart';

bool shouldRunCarMessagingBackground({
  required ExperienceSettings settings,
  required bool isCellularTransport,
  required bool featureEnabled,
  bool? debugBuild,
}) {
  final debugMode = debugBuild ?? kDebugMode;
  return debugMode &&
      featureEnabled &&
      settings.androidAutoMessagingEnabled &&
      shouldRunAndroidBackgroundAlerts(settings) &&
      !shouldDisableBackgroundNetworkForDataSaver(
        settings: settings,
        isCellularTransport: isCellularTransport,
      );
}

bool supportsCarMessagingServerProfile(Map<String, dynamic> profile) {
  return profile['oauthEnabled'] != true && profile['tailscaleEnabled'] != true;
}

bool hasRequiredBackgroundBasicCredentials({
  required bool basicAuthEnabled,
  required String username,
  required String password,
}) {
  return !basicAuthEnabled ||
      (username.trim().isNotEmpty && password.trim().isNotEmpty);
}
