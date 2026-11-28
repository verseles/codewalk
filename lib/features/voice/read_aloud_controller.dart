import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../platform/storage/metadata_store.dart';
import '../../shared/media/audio_playback.dart';
import '../../shared/voice/read_aloud.dart';
import '../../shared/voice/speakable_text.dart';

/// Where a message's reading stands.
enum ReadAloudPhase { idle, preparing, playing, paused }

/// Reads messages aloud, one at a time across the app (#541).
///
/// Generated audio (Edge and the cloud providers) plays through the shared
/// audio player, so it and an audio attachment stop each other, and is kept
/// in memory for a replay (16 entries, 32 MiB). The device's engine speaks
/// by itself; it cannot resume, so Resume reads the message again. A
/// failure is reported and never read by another provider instead.
class ReadAloudController extends ChangeNotifier {
  ReadAloudController({
    required V2MetadataStore? metadata,
    required this.keys,
    required this.synthesizer,
    required this.locale,
    this.native,
    this.player,
  }) : _metadata = metadata {
    _subscription = player?.updates.listen(_playerChanged);
  }

  static const settingsKey = 'cw2.settings.readAloud';

  /// The key the settings' voice test reads under.
  static const testKey = 'read-aloud-test';
  static const _cacheEntries = 16;
  static const _cacheBytes = 32 * 1024 * 1024;

  final V2MetadataStore? _metadata;
  final SpeechKeyStore keys;

  /// Edge's or a cloud provider's synthesizer; null where it cannot run.
  final SpeechSynthesizer? Function(SpeechProvider provider) synthesizer;
  final NativeSpeechEngine? native;
  final AudioPlaybackPort? player;

  /// The app's language, as a BCP 47 tag, for default voices.
  final String Function() locale;

  StreamSubscription<AudioPlaybackState>? _subscription;
  ReadAloudSettings _settings = const ReadAloudSettings();
  bool _loaded = false;
  String? _active;
  String? _activeText;
  // Whether the reading in progress is the device engine's, whatever the
  // settings say by now.
  bool _activeNative = false;

  // The player id of the reading in progress: its own for every reading, so
  // a late step of an older one never touches a newer one's audio.
  String? _playing;

  // An audio already playing when the reading started; it keeps playing
  // until the reading's audio takes the player.
  String? _foreign;
  int _revision = 0;
  ReadAloudPhase _phase = ReadAloudPhase.idle;
  int _generation = 0;
  SpeechCancel? _cancel;
  bool _disposed = false;
  final _cache = <String, SpeechAudio>{};
  int _cachedBytes = 0;

  ReadAloudSettings get settings => _settings;
  bool get loaded => _loaded;

  /// The message being read, if any.
  String? get active => _active;
  ReadAloudPhase get phase => _phase;

  ReadAloudPhase phaseOf(String key) =>
      key == _active ? _phase : ReadAloudPhase.idle;

  /// Whether the device's engine can speak here.
  bool get nativeAvailable => native?.available ?? false;

  /// Whether the chosen provider can run on this device at all.
  bool get providerAvailable => _settings.provider == SpeechProvider.system
      ? nativeAvailable
      : synthesizer(_settings.provider) != null;

  /// Whether messages offer Read aloud.
  bool get offered => _settings.enabled && providerAvailable;

  /// The providers this device can use, in their order.
  List<SpeechProvider> get providers => [
    for (final provider in SpeechProvider.values)
      if (provider == SpeechProvider.system
          ? nativeAvailable
          : synthesizer(provider) != null)
        provider,
  ];

  /// The chosen provider's voices; empty where it lists none.
  Future<List<SpeechVoice>> voices() async {
    final settings = _settings;
    if (settings.provider == SpeechProvider.system) {
      return await native?.voices() ?? const [];
    }
    final synth = synthesizer(settings.provider);
    if (synth == null) return const [];
    return synth.voices(
      SpeechRequest(
        text: '',
        settings: settings,
        locale: locale(),
        apiKey: await _key(settings),
      ),
    );
  }

  Future<void> load() async {
    if (_disposed) return;
    Object? raw;
    try {
      raw = await _metadata?.read(settingsKey);
    } on Object {
      // Unreadable choices leave the defaults; the app still opens.
      raw = null;
    }
    final stored = ReadAloudSettings.decode(raw is String ? raw : null);
    if (_disposed) return;
    if (stored != null) _settings = stored;
    _loaded = true;
    notifyListeners();
  }

  Future<void> update(ReadAloudSettings next) async {
    if (_disposed || next == _settings) return;
    final previous = _settings;
    _settings = next;
    final revision = ++_revision;
    // What reads now no longer matches the choice.
    if (previous.provider != next.provider ||
        previous.voice != next.voice ||
        previous.model != next.model ||
        previous.baseUrl != next.baseUrl ||
        !next.enabled) {
      await stop();
    }
    if (_disposed) return;
    notifyListeners();
    // A later choice made while this one stopped the reading is stored
    // instead: an older one never overwrites it.
    if (revision != _revision) return;
    await _metadata?.write(settingsKey, jsonEncode(next.toJson()));
  }

  /// Reads [text] as message [key]; a reading of another message stops
  /// first. Resolves with the failure, if any.
  Future<SpeechFailure?> read(String key, String text) async {
    final speech = speakableText(text);
    if (speech.isEmpty) return SpeechFailure.noAudio;
    // This reading is the current one at once: a stop or another reading
    // from here on supersedes it, whatever it still awaits.
    final previous = _playing;
    final previousNative = _activeNative && _active != null;
    final generation = ++_generation;
    _cancel?.cancel();
    final cancel = _cancel = SpeechCancel();
    final settings = _settings;
    final id = _playing = 'read-aloud:$key#$generation';
    final before = player?.current;
    _foreign =
        before?.activeId != null &&
            !before!.activeId!.startsWith('read-aloud:') &&
            (before.status == AudioPlaybackStatus.playing ||
                before.status == AudioPlaybackStatus.loading)
        ? before.activeId
        : null;
    _active = key;
    _activeText = speech;
    _activeNative = settings.provider == SpeechProvider.system;
    _set(ReadAloudPhase.preparing);
    bool current() =>
        generation == _generation && !cancel.cancelled && !_disposed;
    String? cacheKey;
    try {
      await _silence(previous, native: previousNative);
      if (!current()) return null;
      if (settings.provider == SpeechProvider.system) {
        final engine = native;
        if (engine == null || !engine.available) {
          throw const SpeechException(SpeechFailure.unavailable);
        }
        _set(ReadAloudPhase.playing);
        await engine.speak(
          speech,
          voice: settings.voice,
          rate: settings.rate,
          pitch: settings.pitch,
        );
        // Ended, unless paused or replaced meanwhile.
        if (generation == _generation && _phase == ReadAloudPhase.playing) {
          _reset();
        }
        return null;
      }
      final synth = synthesizer(settings.provider);
      final output = player;
      if (synth == null || output == null || !output.supported) {
        throw const SpeechException(SpeechFailure.unavailable);
      }
      final language = locale();
      cacheKey = _cacheKey(key, speech, settings, language);
      var audio = _cache[cacheKey];
      if (audio == null) {
        final apiKey = await _key(settings);
        // Stopped meanwhile: no text leaves the device.
        if (!current()) return null;
        audio = await synth.synthesize(
          SpeechRequest(
            text: speech,
            settings: settings,
            locale: language,
            apiKey: apiKey,
          ),
          cancel,
        );
        // Only the current reading's audio is kept.
        if (!current()) return null;
      }
      _remember(cacheKey, audio);
      await output.togglePlay(
        id: id,
        bytes: audio.bytes,
        mimeType: audio.mimeType,
      );
      if (!current()) {
        // Stopped or replaced while the player started: this audio goes,
        // and only this one.
        await output.stop(id: id);
        return null;
      }
      final state = output.current;
      if (state.activeId == id && state.status == AudioPlaybackStatus.error) {
        // Audio that cannot play is made again next time.
        _forget(cacheKey);
        _reset();
        return SpeechFailure.unavailable;
      }
      if (state.activeId != id) {
        // The player never took this audio.
        _reset();
        return SpeechFailure.unavailable;
      }
      return null;
    } on SpeechException catch (error) {
      // A reading stopped or replaced on purpose reports nothing.
      if (!current()) return null;
      _reset();
      return error.failure;
    } on Object {
      if (!current()) return null;
      _reset();
      return SpeechFailure.unavailable;
    }
  }

  /// Silences the reading whose player id is [id], once another took its
  /// place.
  Future<void> _silence(String? id, {required bool native}) async {
    if (native) {
      await this.native?.stop();
    } else if (id != null) {
      await player?.stop(id: id);
    }
  }

  /// The saved key of [settings]' service at its address; none for a
  /// service that takes no key, whose reading never waits on storage.
  Future<String?> _key(ReadAloudSettings settings) async {
    if (!settings.provider.keyed) return null;
    try {
      return await keys.read(
        speechKeyScope(settings.provider, settings.baseUrl),
      );
    } on Object {
      // Unreadable storage: as if no key were saved.
      return null;
    }
  }

  Future<void> pause() async {
    final key = _active;
    if (key == null || _phase != ReadAloudPhase.playing) return;
    if (_activeNative) {
      _set(ReadAloudPhase.paused);
      await native?.stop();
      return;
    }
    await _toggle(AudioPlaybackStatus.playing);
  }

  /// Pauses or resumes the reading's own audio, when it is in [from].
  Future<void> _toggle(AudioPlaybackStatus from) async {
    final output = player;
    final id = _playing;
    final state = output?.current;
    if (output == null ||
        id == null ||
        state?.activeId != id ||
        state?.status != from) {
      return;
    }
    await output.togglePlay(
      id: id,
      bytes: Uint8List(0),
      mimeType: 'audio/mpeg',
    );
  }

  Future<SpeechFailure?> resume() async {
    final key = _active;
    if (key == null || _phase != ReadAloudPhase.paused) return null;
    if (_activeNative) {
      // The engine cannot resume: the message starts again.
      return read(key, _activeText ?? '');
    }
    final id = _playing;
    await _toggle(AudioPlaybackStatus.paused);
    // A player that cannot take it back says so, as when it cannot start.
    final now = player?.current;
    if (id != null &&
        now?.activeId == id &&
        now?.status == AudioPlaybackStatus.error) {
      return SpeechFailure.unavailable;
    }
    return null;
  }

  Future<void> stop() async {
    if (_disposed) return;
    final key = _active;
    _generation++;
    _cancel?.cancel();
    _cancel = null;
    if (key == null) return;
    final wasNative = _activeNative;
    final id = _playing;
    _reset();
    await _silence(id, native: wasNative);
  }

  /// Stops the reading of a message whose key [test] matches, as when its
  /// session closes or a prompt is sent there.
  Future<void> stopWhere(bool Function(String key) test) async {
    final key = _active;
    if (key != null && test(key)) await stop();
  }

  void _playerChanged(AudioPlaybackState state) {
    final id = _playing;
    if (_active == null || id == null || _activeNative) return;
    // An attachment that was playing as the reading started and then paused,
    // stopped or gave way loses its pass: starting it again claims the
    // player.
    if (_foreign != null &&
        (state.activeId != _foreign ||
            (state.status != AudioPlaybackStatus.playing &&
                state.status != AudioPlaybackStatus.loading))) {
      _foreign = null;
    }
    if (state.activeId != id) {
      final other =
          state.activeId != null &&
          !state.activeId!.startsWith('read-aloud:') &&
          state.activeId != _foreign &&
          (state.status == AudioPlaybackStatus.loading ||
              state.status == AudioPlaybackStatus.playing);
      if (_phase == ReadAloudPhase.playing || _phase == ReadAloudPhase.paused) {
        // Another audio took the player, or ours ended.
        _reset();
      } else if (other) {
        // Another audio started while this one was prepared: it keeps the
        // player, and this reading ends unheard.
        _generation++;
        _cancel?.cancel();
        _cancel = null;
        _reset();
      }
      return;
    }
    switch (state.status) {
      case AudioPlaybackStatus.playing:
        _set(ReadAloudPhase.playing);
      case AudioPlaybackStatus.paused:
        // The player rests at the end of an audio that played through.
        final ended =
            state.completed ||
            (state.duration > Duration.zero &&
                state.position >= state.duration);
        if (ended) {
          _reset();
        } else {
          _set(ReadAloudPhase.paused);
        }
      case AudioPlaybackStatus.idle:
        if (_phase != ReadAloudPhase.preparing) _reset();
      case AudioPlaybackStatus.error:
        _reset();
      case AudioPlaybackStatus.loading:
        break;
    }
  }

  String _cacheKey(
    String key,
    String text,
    ReadAloudSettings settings,
    String language,
  ) => jsonEncode([
    key,
    text,
    language,
    settings.provider.name,
    settings.voice,
    settings.rate,
    settings.model,
    settings.baseUrl,
  ]);

  void _remember(String key, SpeechAudio audio) {
    // Most recent last; an entry replaced counts once.
    _forget(key);
    _cache[key] = audio;
    _cachedBytes += audio.bytes.length;
    while (_cache.length > _cacheEntries || _cachedBytes > _cacheBytes) {
      final oldest = _cache.keys.first;
      _cachedBytes -= _cache.remove(oldest)!.bytes.length;
    }
  }

  void _forget(String key) {
    final old = _cache.remove(key);
    if (old != null) _cachedBytes -= old.bytes.length;
  }

  void _reset() {
    _active = null;
    _activeText = null;
    _activeNative = false;
    _playing = null;
    _foreign = null;
    _set(ReadAloudPhase.idle);
  }

  void _set(ReadAloudPhase phase) {
    if (_phase == phase || _disposed) {
      _phase = phase;
      return;
    }
    _phase = phase;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _cancel?.cancel();
    unawaited(_subscription?.cancel());
    if (_active != null && _activeNative) {
      unawaited(native?.stop());
    }
    _cache.clear();
    super.dispose();
  }
}
