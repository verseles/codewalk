import 'dart:convert';
import 'dart:typed_data';

/// Where a message's words are turned into speech (#541).
enum SpeechProvider {
  /// Microsoft Edge's read-aloud voices, through its unofficial protocol;
  /// the default, with no account.
  edge,

  /// The device's own engine (Android, macOS, Windows).
  system,

  /// Any server with the OpenAI `/v1/audio/speech` route.
  openAi,
  elevenLabs,

  /// An NVIDIA Speech NIM deployment.
  nim;

  /// Whether the text leaves the device for a third party.
  bool get cloud => this != system;

  /// Whether it needs an API key the user saves.
  bool get keyed => this == openAi || this == elevenLabs || this == nim;

  static SpeechProvider? parse(Object? value) =>
      SpeechProvider.values.where((p) => p.name == value).firstOrNull;
}

/// The read-aloud choices, saved together (keys never: they live in the
/// device's secure storage).
final class ReadAloudSettings {
  const ReadAloudSettings({
    this.enabled = true,
    this.provider = SpeechProvider.edge,
    this.voice,
    this.rate = 0.5,
    this.pitch = 1.0,
    this.baseUrl,
    this.model,
    this.testPhrase,
  });

  final bool enabled;
  final SpeechProvider provider;

  /// The provider's voice; null for its default (Edge: by locale).
  final String? voice;

  /// 0.0 to 1.0, 0.5 the provider's normal speed.
  final double rate;

  /// 0.5 to 2.0, for the device's engine only.
  final double pitch;
  final String? baseUrl;
  final String? model;
  final String? testPhrase;

  ReadAloudSettings copyWith({
    bool? enabled,
    SpeechProvider? provider,
    String? voice,
    bool clearVoice = false,
    double? rate,
    double? pitch,
    String? baseUrl,
    bool clearBaseUrl = false,
    String? model,
    bool clearModel = false,
    String? testPhrase,
    bool clearTestPhrase = false,
  }) => ReadAloudSettings(
    enabled: enabled ?? this.enabled,
    provider: provider ?? this.provider,
    voice: clearVoice ? null : voice ?? this.voice,
    rate: rate ?? this.rate,
    pitch: pitch ?? this.pitch,
    baseUrl: clearBaseUrl ? null : baseUrl ?? this.baseUrl,
    model: clearModel ? null : model ?? this.model,
    testPhrase: clearTestPhrase ? null : testPhrase ?? this.testPhrase,
  );

  Map<String, Object?> toJson() => {
    'v': 1,
    'enabled': enabled,
    'provider': provider.name,
    'voice': ?voice,
    'rate': rate,
    'pitch': pitch,
    'baseUrl': ?baseUrl,
    'model': ?model,
    'testPhrase': ?testPhrase,
  };

  /// Reads [raw] tolerantly: a field of the wrong type keeps its default,
  /// and malformed JSON gives null.
  static ReadAloudSettings? decode(String? raw) {
    if (raw == null) return null;
    Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (json is! Map) return null;
    final map = json;
    String? text(String key) {
      final value = map[key];
      return value is String && value.trim().isNotEmpty ? value : null;
    }

    double number(String key, double fallback, double min, double max) {
      final value = map[key];
      return value is num && value.isFinite
          ? value.toDouble().clamp(min, max)
          : fallback;
    }

    const defaults = ReadAloudSettings();
    return ReadAloudSettings(
      enabled: json['enabled'] is bool
          ? json['enabled'] as bool
          : defaults.enabled,
      provider: SpeechProvider.parse(json['provider']) ?? defaults.provider,
      voice: text('voice'),
      rate: number('rate', defaults.rate, 0, 1),
      pitch: number('pitch', defaults.pitch, 0.5, 2),
      baseUrl: text('baseUrl'),
      model: text('model'),
      testPhrase: text('testPhrase'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReadAloudSettings &&
      other.enabled == enabled &&
      other.provider == provider &&
      other.voice == voice &&
      other.rate == rate &&
      other.pitch == pitch &&
      other.baseUrl == baseUrl &&
      other.model == model &&
      other.testPhrase == testPhrase;

  @override
  int get hashCode => Object.hash(
    enabled,
    provider,
    voice,
    rate,
    pitch,
    baseUrl,
    model,
    testPhrase,
  );
}

/// Why a reading failed, each with its own message.
enum SpeechFailure {
  offline,
  unauthorized,
  rateLimited,
  tooLong,
  noAudio,
  rejected,
  notConfigured,
  unavailable,
}

final class SpeechException implements Exception {
  const SpeechException(this.failure, [this.detail]);
  final SpeechFailure failure;

  /// A status code or a short provider note, never message text or keys.
  final String? detail;

  @override
  String toString() =>
      'SpeechException(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// One voice a provider offers.
final class SpeechVoice {
  const SpeechVoice({required this.id, required this.label, this.locale});
  final String id;
  final String label;
  final String? locale;
}

/// Lets a running synthesis know it is no longer wanted.
final class SpeechCancel {
  bool _cancelled = false;
  final _actions = <void Function()>[];
  bool get cancelled => _cancelled;

  /// Runs [action] once this is cancelled, at once if it already is, as a
  /// request that drops its connection; the returned function forgets it,
  /// once the connection is done anyway.
  void Function() onCancel(void Function() action) {
    if (_cancelled) {
      action();
      return () {};
    }
    _actions.add(action);
    return () => _actions.remove(action);
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final action in List.of(_actions)) {
      action();
    }
    _actions.clear();
  }
}

/// Whether a provider's [address] may carry message text and keys: https,
/// or plain http only to this device, the local network or a tailnet.
bool speechAddressSecure(Uri address) {
  if (address.scheme == 'https') return true;
  if (address.scheme != 'http') return false;
  final host = address.host.toLowerCase();
  if (host == 'localhost' ||
      host == '::1' ||
      host.endsWith('.local') ||
      host.endsWith('.ts.net')) {
    return true;
  }
  final parts = host.split('.').map(int.tryParse).toList();
  if (parts.length == 4 &&
      parts.every((part) => part != null && part >= 0 && part <= 255)) {
    final a = parts[0]!;
    final b = parts[1]!;
    return a == 127 ||
        a == 10 ||
        (a == 192 && b == 168) ||
        (a == 172 && b >= 16 && b <= 31) ||
        // Carrier-grade NAT, where tailnets live.
        (a == 100 && b >= 64 && b <= 127);
  }
  // IPv6 unique local and link-local addresses.
  return host.contains(':') &&
      (host.startsWith('fc') ||
          host.startsWith('fd') ||
          host.startsWith('fe80'));
}

/// Audio a provider made, ready to play.
final class SpeechAudio {
  const SpeechAudio(this.bytes, this.mimeType);
  final Uint8List bytes;
  final String mimeType;
}

/// What a request carries to a provider.
final class SpeechRequest {
  const SpeechRequest({
    required this.text,
    required this.settings,
    required this.locale,
    this.apiKey,
  });

  final String text;
  final ReadAloudSettings settings;

  /// The app's language, for a default voice.
  final String locale;
  final String? apiKey;
}

/// Turns text into audio bytes: Edge and the cloud providers.
abstract interface class SpeechSynthesizer {
  Future<SpeechAudio> synthesize(SpeechRequest request, SpeechCancel cancel);
  Future<List<SpeechVoice>> voices(SpeechRequest request);
}

/// The device's own speech engine; it speaks itself.
abstract interface class NativeSpeechEngine {
  bool get available;
  Future<List<SpeechVoice>> voices();

  /// Speaks [text] and completes when it ends, is stopped or fails.
  Future<void> speak(
    String text, {
    String? voice,
    required double rate,
    required double pitch,
  });
  Future<void> stop();
}

/// The API keys of the keyed providers, in the device's secure storage.
/// Saved API keys, each for one [speechKeyScope].
abstract interface class SpeechKeyStore {
  Future<String?> read(String scope);
  Future<void> write(String scope, String? key);
}

/// The address a service is reached at when none is set.
const speechDefaultBase = {
  SpeechProvider.openAi: 'https://api.openai.com',
  SpeechProvider.elevenLabs: 'https://api.elevenlabs.io',
};

/// What a saved key belongs to: its service and the origin it is sent to,
/// so a key saved for one server never goes to another (#541).
String speechKeyScope(SpeechProvider provider, String? baseUrl) {
  final base = baseUrl ?? speechDefaultBase[provider];
  final uri = base == null ? null : Uri.tryParse(base.trim());
  if (uri == null || uri.host.isEmpty) return provider.name;
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${provider.name}@${uri.scheme}://${uri.host.toLowerCase()}$port';
}
