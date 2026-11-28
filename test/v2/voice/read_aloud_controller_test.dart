import 'dart:async';
import 'dart:typed_data';

import 'package:codewalk/features/voice/read_aloud_actions.dart';
import 'package:codewalk/features/voice/read_aloud_controller.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/media/audio_playback.dart';
import 'package:codewalk/shared/voice/memory_speech_keys.dart';
import 'package:codewalk/shared/voice/read_aloud.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';

// #541: one reading at a time, cached, with no provider swap on failure.

final class FakeSynth implements SpeechSynthesizer {
  final requests = <SpeechRequest>[];
  SpeechException? failure;
  Completer<void>? gate;

  @override
  Future<SpeechAudio> synthesize(
    SpeechRequest request,
    SpeechCancel cancel,
  ) async {
    requests.add(request);
    await gate?.future;
    if (failure case final failure?) throw failure;
    return SpeechAudio(Uint8List.fromList([1, 2, 3]), 'audio/mpeg');
  }

  @override
  Future<List<SpeechVoice>> voices(SpeechRequest request) async => const [
    SpeechVoice(id: 'v1', label: 'Voice one', locale: 'en-US'),
  ];
}

final class FakePlayer implements AudioPlaybackPort {
  final _updates = StreamController<AudioPlaybackState>.broadcast();
  final played = <String>[];
  int stops = 0;

  /// Whether starting an audio fails, as a codec the platform lacks.
  bool fail = false;

  @override
  AudioPlaybackState current = const AudioPlaybackState();

  @override
  bool get supported => true;

  @override
  Stream<AudioPlaybackState> get updates => _updates.stream;

  void emit(AudioPlaybackState state) {
    current = state;
    _updates.add(state);
  }

  @override
  Future<void> togglePlay({
    required String id,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (current.activeId == id &&
        current.status == AudioPlaybackStatus.playing) {
      emit(current.copyWith(status: AudioPlaybackStatus.paused));
      return;
    }
    if (current.activeId == id &&
        current.status == AudioPlaybackStatus.paused) {
      emit(current.copyWith(status: AudioPlaybackStatus.playing));
      return;
    }
    played.add(id);
    emit(
      AudioPlaybackState(
        activeId: id,
        status: fail ? AudioPlaybackStatus.error : AudioPlaybackStatus.playing,
      ),
    );
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> stop() async {
    stops++;
    emit(const AudioPlaybackState());
  }

  @override
  Future<void> dispose() => _updates.close();
}

void main() {
  late FakeSynth synth;
  late FakePlayer player;
  late MemorySpeechKeys keys;
  late FakeMetadataBackend backend;
  late ReadAloudController controller;

  setUp(() {
    synth = FakeSynth();
    player = FakePlayer();
    keys = MemorySpeechKeys();
    backend = FakeMetadataBackend();
    controller = ReadAloudController(
      metadata: V2MetadataStore(backend: backend),
      keys: keys,
      synthesizer: (provider) =>
          provider == SpeechProvider.system ? null : synth,
      locale: () => 'pt-BR',
      player: player,
    );
  });

  tearDown(() => controller.dispose());

  test('Edge is the default, and only real providers are offered', () async {
    await controller.load();
    expect(controller.settings.provider, SpeechProvider.edge);
    expect(controller.offered, isTrue);
    expect(controller.providers, isNot(contains(SpeechProvider.system)));
  });

  test('a message is read once, then replayed from memory', () async {
    expect(await controller.read('s|a', '**Hello** there'), isNull);
    await pumpEventQueue();
    expect(synth.requests.single.text, 'Hello there');
    expect(synth.requests.single.locale, 'pt-BR');
    expect(controller.active, 's|a');
    expect(controller.phase, ReadAloudPhase.playing);
    // Pause and resume go through the shared player.
    await controller.pause();
    await pumpEventQueue();
    expect(controller.phase, ReadAloudPhase.paused);
    expect(await controller.resume(), isNull);
    await pumpEventQueue();
    expect(controller.phase, ReadAloudPhase.playing);
    await controller.stop();
    expect(controller.active, isNull);
    expect(player.stops, 1);
    await controller.read('s|a', '**Hello** there');
    expect(synth.requests, hasLength(1));
    expect(player.played, hasLength(2));
  });

  test('another audio taking the player ends the reading', () async {
    await controller.read('s|a', 'Hello');
    await pumpEventQueue();
    player.emit(
      const AudioPlaybackState(
        activeId: 'attachment',
        status: AudioPlaybackStatus.playing,
      ),
    );
    await pumpEventQueue();
    expect(controller.phase, ReadAloudPhase.idle);
  });

  test('a failure is reported, and nothing else reads instead', () async {
    synth.failure = const SpeechException(SpeechFailure.unauthorized);
    expect(await controller.read('s|a', 'Hello'), SpeechFailure.unauthorized);
    expect(controller.phase, ReadAloudPhase.idle);
    expect(player.played, isEmpty);
    expect(
      await controller.read('s|b', '```\ncode\n```'),
      SpeechFailure.noAudio,
    );
  });

  test('a newer reading wins over one still being prepared', () async {
    final gate = synth.gate = Completer<void>();
    final first = controller.read('s|a', 'First');
    await pumpEventQueue();
    expect(controller.phase, ReadAloudPhase.preparing);
    synth.gate = null;
    await controller.read('s|b', 'Second');
    await pumpEventQueue();
    expect(controller.active, 's|b');
    expect(player.played, ['read-aloud:s|b']);
    // The first one's audio, ready late, never plays.
    gate.complete();
    await first;
    expect(player.played, ['read-aloud:s|b']);
    expect(controller.active, 's|b');
  });

  test('a reading that plays to its end is over', () async {
    await controller.read('s|a', 'Hello');
    await pumpEventQueue();
    expect(controller.phase, ReadAloudPhase.playing);
    // The player rests, paused, at the end of what played through.
    player.emit(
      const AudioPlaybackState(
        activeId: 'read-aloud:s|a',
        status: AudioPlaybackStatus.paused,
        position: Duration(seconds: 3),
        duration: Duration(seconds: 3),
      ),
    );
    await pumpEventQueue();
    expect(controller.active, isNull);
    expect(controller.phase, ReadAloudPhase.idle);
    // Read again, it starts over rather than resuming the end.
    await controller.read('s|a', 'Hello');
    await pumpEventQueue();
    expect(player.stops, 1);
    expect(controller.phase, ReadAloudPhase.playing);
  });

  test('a player that cannot play says so', () async {
    player.fail = true;
    expect(await controller.read('s|a', 'Hello'), SpeechFailure.unavailable);
    await pumpEventQueue();
    expect(controller.active, isNull);
  });

  test('a reading stopped or replaced reports no failure', () async {
    final gate = synth.gate = Completer<void>();
    synth.failure = const SpeechException(SpeechFailure.offline);
    final first = controller.read('s|a', 'First');
    await pumpEventQueue();
    await controller.stop();
    gate.complete();
    expect(await first, isNull);
  });

  test(
    'an audio started while a reading is prepared keeps the player',
    () async {
      final gate = synth.gate = Completer<void>();
      final first = controller.read('s|a', 'First');
      await pumpEventQueue();
      player.emit(
        const AudioPlaybackState(
          activeId: 'attachment',
          status: AudioPlaybackStatus.playing,
        ),
      );
      await pumpEventQueue();
      expect(controller.phase, ReadAloudPhase.idle);
      gate.complete();
      expect(await first, isNull);
      expect(player.played, isEmpty);
    },
  );

  test('the newest choice is the one stored', () async {
    await controller.read('s|a', 'Hello');
    final first = controller.update(
      controller.settings.copyWith(provider: SpeechProvider.openAi),
    );
    final second = controller.update(
      controller.settings.copyWith(enabled: false),
    );
    await Future.wait([first, second]);
    final stored = ReadAloudSettings.decode(
      backend.values[ReadAloudController.settingsKey]! as String,
    )!;
    expect(stored.enabled, isFalse);
    expect(stored.provider, SpeechProvider.openAi);
  });

  test('a page that goes stops its reading once the tree is free', () async {
    const session = SessionRef(HostId('h'), HarnessInstanceId('h'), 'ses_1');
    final key = readAloudKey(session, const ItemId('a'));
    await controller.read(key, 'Hello');
    stopReadingAfter(controller, session);
    // Nothing changes while the page is still being taken down.
    expect(controller.active, key);
    await pumpEventQueue();
    expect(controller.active, isNull);
  });

  test('a session closing stops only its own reading', () async {
    await controller.read('one|a', 'Hello');
    await controller.stopWhere((key) => key.startsWith('two|'));
    expect(controller.active, 'one|a');
    await controller.stopWhere((key) => key.startsWith('one|'));
    expect(controller.active, isNull);
  });

  test(
    'choices persist without keys; changing voice stops the reading',
    () async {
      await keys.write(SpeechProvider.openAi, 'sk-secret');
      await controller.read('s|a', 'Hello');
      await controller.update(
        controller.settings.copyWith(provider: SpeechProvider.openAi),
      );
      expect(controller.active, isNull);
      final stored = backend.values[ReadAloudController.settingsKey]! as String;
      expect(stored, contains('openAi'));
      expect(stored, isNot(contains('sk-secret')));
      await controller.read('s|a', 'Hello');
      expect(synth.requests.last.apiKey, 'sk-secret');
      expect(await controller.voices(), hasLength(1));
    },
  );
}
