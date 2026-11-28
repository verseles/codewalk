import 'dart:math';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/voice/read_aloud.dart';

/// The name the settings and messages give a voice service (#541).
String readAloudProviderName(V2Localizations l10n, SpeechProvider provider) =>
    switch (provider) {
      SpeechProvider.edge => l10n.readAloudProviderEdge,
      SpeechProvider.system => l10n.readAloudProviderSystem,
      SpeechProvider.openAi => l10n.readAloudProviderOpenAi,
      SpeechProvider.elevenLabs => l10n.readAloudProviderElevenLabs,
      SpeechProvider.nim => l10n.readAloudProviderNim,
    };

/// What a failed reading says.
String readAloudFailureText(V2Localizations l10n, SpeechFailure failure) =>
    switch (failure) {
      SpeechFailure.offline => l10n.readAloudFailOffline,
      SpeechFailure.unauthorized => l10n.readAloudFailUnauthorized,
      SpeechFailure.rateLimited => l10n.readAloudFailRateLimited,
      SpeechFailure.tooLong => l10n.readAloudFailTooLong,
      SpeechFailure.noAudio => l10n.readAloudFailNoAudio,
      SpeechFailure.rejected => l10n.readAloudFailRejected,
      SpeechFailure.notConfigured => l10n.readAloudFailNotConfigured,
      SpeechFailure.unavailable => l10n.readAloudFailUnavailable,
    };

/// The speed [rate] (0–1, normal in the middle) gives with [provider], as
/// a multiplier: `0.5×` to `2.0×`, or ElevenLabs' `0.7×` to `1.2×`.
String readAloudSpeed(SpeechProvider provider, double rate) {
  final speed = provider == SpeechProvider.elevenLabs
      ? 0.7 + 0.5 * rate
      : 0.5 * pow(4, rate);
  return '${speed.toStringAsFixed(1)}×';
}
