import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/auth/stt_api_key_storage.dart';
import '../../domain/entities/experience_settings.dart';
import 'speech_audio_capture.dart';
import 'speech_input_service.dart';

class ApiSpeechInputService implements SpeechInputService {
  ApiSpeechInputService({
    required SttApiKeyStorage apiKeyStorage,
    Dio? dio,
    SpeechAudioCapture? audioCapture,
  }) : _apiKeyStorage = apiKeyStorage,
       _dio = dio ?? Dio(),
       _audioCapture = audioCapture ?? SpeechAudioCapture();

  static const int sampleRate = 16000;
  static const int channels = 1;
  static const Duration maxRecordingDuration = Duration(minutes: 2);
  static const int _speechThreshold = 500;

  final SttApiKeyStorage _apiKeyStorage;
  final Dio _dio;
  final SpeechAudioCapture _audioCapture;

  SpeechApiProvider _provider = SpeechApiProvider.openAi;
  String _baseUrl = kDefaultOpenAiSttBaseUrl;
  String _model = kDefaultOpenAiSttModel;
  String? _apiKey;
  bool _isAvailable = false;
  bool _isStarting = false;
  bool _isListening = false;
  int _sessionEpoch = 0;
  Future<void>? _finalization;
  CancelToken? _cancelToken;
  String? _unavailableReason;
  String? _unavailableReasonKey;
  // Finalization paths cancel the subscription that owns the capture stream.
  // ignore: cancel_subscriptions
  StreamSubscription<Uint8List>? _subscription;
  Timer? _silenceTimer;
  Timer? _maxDurationTimer;
  final BytesBuilder _pcm = BytesBuilder(copy: false);
  bool _heardSpeech = false;
  Duration _pauseFor = const Duration(seconds: 5);
  void Function(String text, bool isFinal)? _onResult;
  void Function(String status)? _onStatus;
  void Function()? _onError;
  String? _localeId;

  void configure({
    required SpeechApiProvider provider,
    required String baseUrl,
    required String model,
  }) {
    _provider = provider;
    _baseUrl =
        (provider == SpeechApiProvider.custom
                ? baseUrl
                : defaultSpeechApiBaseUrl(provider))
            .trim()
            .replaceFirst(RegExp(r'/+$'), '');
    _model = model.trim();
    _isAvailable = false;
    _apiKey = null;
  }

  @override
  Future<bool> initialize() async {
    _clearFailure();
    if (kIsWeb) {
      return _fail(
        'API speech-to-text is unavailable on the web build.',
        'webUnavailable',
      );
    }
    final uri = Uri.tryParse(_baseUrl);
    final isLocalHttp =
        uri?.scheme == 'http' &&
        (uri?.host == 'localhost' ||
            uri?.host == '127.0.0.1' ||
            uri?.host == '::1');
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'https' && !isLocalHttp) ||
        _model.isEmpty) {
      return _fail(
        'The speech API configuration is invalid.',
        'apiConfigInvalid',
      );
    }
    try {
      _apiKey = await _apiKeyStorage.read(_provider);
    } on SttApiKeyStorageException {
      return _fail(
        'Secure speech API key storage is unavailable.',
        'apiKeyStorageUnavailable',
      );
    }
    if (_provider != SpeechApiProvider.custom && _apiKey == null) {
      return _fail('A speech API key is required.', 'apiKeyMissing');
    }
    if (!await _audioCapture.hasPermission()) {
      final failure = speechAudioCaptureFailureInfoForStatus(
        _audioCapture.lastWindowsAccessStatus,
      );
      return _fail(
        failure.reason ?? 'Microphone permission is disabled.',
        failure.reasonKey ?? 'microphoneDenied',
      );
    }
    _isAvailable = true;
    return true;
  }

  @override
  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function(String status) onStatus,
    required void Function() onError,
    Duration? pauseFor,
    String? localeId,
  }) async {
    if (!_isAvailable) {
      onError();
      return;
    }
    if (_isStarting || _isListening || _finalization != null) {
      onError();
      return;
    }
    final epoch = ++_sessionEpoch;
    _isStarting = true;
    _onResult = onResult;
    _onStatus = onStatus;
    _onError = onError;
    _localeId = _normalizeLanguage(localeId);
    _pauseFor = pauseFor ?? const Duration(seconds: 5);
    _pcm.clear();
    _heardSpeech = false;
    try {
      final stream = await _audioCapture.startPcmStream(
        sampleRate: sampleRate,
        numChannels: channels,
      );
      if (epoch != _sessionEpoch) {
        await _audioCapture.stop();
        return;
      }
      _isListening = true;
      _subscription = stream.listen(
        (chunk) => _handleAudio(epoch, chunk),
        onError: (Object error, StackTrace stackTrace) {
          unawaited(_finishWithError(epoch, error));
        },
        onDone: () => unawaited(_finishRecording(epoch)),
      );
      _armSilenceTimer(epoch);
      _maxDurationTimer = Timer(
        maxRecordingDuration,
        () => unawaited(_finishRecording(epoch)),
      );
      onStatus('listening');
    } catch (error) {
      await _finishWithError(epoch, error);
    } finally {
      _isStarting = false;
    }
  }

  void _handleAudio(int epoch, Uint8List chunk) {
    if (epoch != _sessionEpoch || !_isListening || chunk.isEmpty) return;
    _pcm.add(chunk);
    if (_containsSpeech(chunk)) {
      _heardSpeech = true;
      _armSilenceTimer(epoch);
    }
  }

  void _armSilenceTimer(int epoch) {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_pauseFor, () => unawaited(_finishRecording(epoch)));
  }

  @override
  Future<void> stopListening() => _finishRecording(_sessionEpoch);

  Future<void> _finishRecording(int epoch) {
    final running = _finalization;
    if (running != null) return running;
    if (epoch != _sessionEpoch || (!_isListening && _pcm.length == 0)) {
      return Future<void>.value();
    }
    return _runFinalization(() => _transcribeRecording(epoch));
  }

  Future<void> _transcribeRecording(int epoch) async {
    _isListening = false;
    _silenceTimer?.cancel();
    _maxDurationTimer?.cancel();
    try {
      final subscription = _subscription;
      _subscription = null;
      await subscription?.cancel();
      await _audioCapture.stop();
      if (epoch != _sessionEpoch) return;
      final pcm = _pcm.takeBytes();
      if (pcm.isEmpty || !_heardSpeech) {
        _fail('No microphone audio was captured.', 'emptyAudio');
        if (epoch == _sessionEpoch) _onError?.call();
        return;
      }
      if (epoch == _sessionEpoch) _onStatus?.call('processing');
      final cancelToken = CancelToken();
      _cancelToken = cancelToken;
      final text = await _transcribe(pcm, cancelToken: cancelToken);
      if (epoch != _sessionEpoch) return;
      if (text.isEmpty) {
        _fail(
          'The speech provider returned no transcription.',
          'emptyTranscript',
        );
        _onError?.call();
        return;
      }
      _onResult?.call(text, true);
      _onStatus?.call('done');
    } catch (error) {
      if (epoch != _sessionEpoch ||
          error is DioException && CancelToken.isCancel(error)) {
        return;
      }
      _setProviderFailure(error);
      _onError?.call();
    } finally {
      if (epoch == _sessionEpoch) _cancelToken = null;
    }
  }

  Future<String> _transcribe(
    Uint8List pcm, {
    required CancelToken cancelToken,
  }) async {
    final form = FormData.fromMap(<String, dynamic>{
      'file': MultipartFile.fromBytes(
        encodePcm16Wav(pcm, sampleRate: sampleRate, channels: channels),
        filename: 'speech.wav',
        contentType: DioMediaType('audio', 'wav'),
      ),
      'model': _model,
      'response_format': 'json',
      if (_localeId != null) 'language': _localeId,
    });
    final headers = <String, String>{'Accept': 'application/json'};
    if (_apiKey != null) headers['Authorization'] = 'Bearer $_apiKey';
    final response = await _dio.post<dynamic>(
      speechTranscriptionEndpoint(_baseUrl),
      data: form,
      cancelToken: cancelToken,
      options: Options(
        headers: headers,
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
    final data = response.data;
    if (data is Map) return data['text']?.toString().trim() ?? '';
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map) return decoded['text']?.toString().trim() ?? '';
    }
    return '';
  }

  Future<void> _finishWithError(int epoch, Object error) {
    if (epoch != _sessionEpoch) return Future<void>.value();
    return _runFinalization(() async {
      _setCaptureFailure(error);
      _isListening = false;
      _silenceTimer?.cancel();
      _maxDurationTimer?.cancel();
      final subscription = _subscription;
      _subscription = null;
      _pcm.clear();
      await subscription?.cancel();
      await _audioCapture.stop();
      if (epoch == _sessionEpoch) _onError?.call();
    });
  }

  Future<void> cancelListening() async {
    ++_sessionEpoch;
    _isListening = false;
    _silenceTimer?.cancel();
    _maxDurationTimer?.cancel();
    _cancelToken?.cancel();
    final running = _finalization;
    if (running != null) {
      await running;
      _pcm.clear();
      return;
    }
    await _runFinalization(() async {
      final subscription = _subscription;
      _subscription = null;
      _pcm.clear();
      await subscription?.cancel();
      await _audioCapture.stop();
    });
  }

  Future<void> _runFinalization(Future<void> Function() operation) {
    final running = _finalization;
    if (running != null) return running;
    late final Future<void> task;
    task = operation().whenComplete(() {
      if (identical(_finalization, task)) _finalization = null;
    });
    _finalization = task;
    return task;
  }

  void clearCallbacks() {
    _onResult = null;
    _onStatus = null;
    _onError = null;
  }

  Future<void> cancelSession() async {
    clearCallbacks();
    _isAvailable = false;
    await cancelListening();
  }

  void _setCaptureFailure(Object error) {
    final failure = speechAudioCaptureFailureInfoForError(error);
    _fail(
      failure.reason ?? 'Microphone capture failed.',
      failure.reasonKey ?? 'generic',
    );
  }

  void _setProviderFailure(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        _fail('The speech API key was rejected.', 'apiKeyRejected');
      } else if (status == 400 || status == 404 || status == 422) {
        _fail(
          'The speech endpoint or model was rejected.',
          'apiRequestInvalid',
        );
      } else if (status == 429) {
        _fail(
          'The speech provider reported a quota or rate limit.',
          'apiRateLimited',
        );
      } else if (status != null && status >= 500) {
        _fail(
          'The speech provider is temporarily unavailable.',
          'apiUnavailable',
        );
      } else {
        _fail('The speech provider could not be reached.', 'apiNetwork');
      }
      return;
    }
    _fail(
      'The speech provider returned an invalid response.',
      'apiInvalidResponse',
    );
  }

  bool _fail(String reason, String key) {
    _unavailableReason = reason;
    _unavailableReasonKey = key;
    return false;
  }

  void _clearFailure() {
    _unavailableReason = null;
    _unavailableReasonKey = null;
  }

  @override
  bool get isListening => _isStarting || _isListening || _finalization != null;

  @override
  bool get isAvailable => _isAvailable;

  @override
  String? get unavailableReason => _unavailableReason;

  @override
  String? get unavailableReasonKey => _unavailableReasonKey;
}

String speechTranscriptionEndpoint(String baseUrl) {
  return '${baseUrl.trim().replaceFirst(RegExp(r'/+$'), '')}/audio/transcriptions';
}

String? _normalizeLanguage(String? localeId) {
  final normalized = localeId?.trim().replaceAll('_', '-');
  if (normalized == null || normalized.isEmpty) return null;
  return normalized.split('-').first.toLowerCase();
}

bool _containsSpeech(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  for (var offset = 0; offset + 1 < bytes.length; offset += 2) {
    if (data.getInt16(offset, Endian.little).abs() >=
        ApiSpeechInputService._speechThreshold) {
      return true;
    }
  }
  return false;
}

Uint8List encodePcm16Wav(
  Uint8List pcm, {
  required int sampleRate,
  required int channels,
}) {
  final result = Uint8List(44 + pcm.length);
  final data = ByteData.sublistView(result);
  void writeAscii(int offset, String value) {
    result.setRange(offset, offset + value.length, ascii.encode(value));
  }

  writeAscii(0, 'RIFF');
  data.setUint32(4, 36 + pcm.length, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, channels, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * channels * 2, Endian.little);
  data.setUint16(32, channels * 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  writeAscii(36, 'data');
  data.setUint32(40, pcm.length, Endian.little);
  result.setRange(44, result.length, pcm);
  return result;
}
