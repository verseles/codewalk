import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/i18n/l10n_bridge.dart';
import '../../../core/logging/app_logger.dart';
import '../../../domain/entities/experience_settings.dart';
import 'edge_tts_protocol.dart';
import 'edge_tts_websocket.dart';
import 'read_aloud_default_resolver.dart';
import 'tts_backend.dart';

const String kDefaultEdgeTtsVoice = 'en-US-EmmaMultilingualNeural';
const Duration kEdgeTtsConnectTimeout = Duration(seconds: 10);
const Duration kEdgeTtsSynthesisTimeout = Duration(seconds: 45);

final RegExp _edgeTtsSpeakableContent = RegExp(
  r'[\p{L}\p{N}]',
  unicode: true,
);

typedef EdgeTtsNowProvider = DateTime Function();
typedef EdgeTtsIdProvider = String Function();

class EdgeExperimentalTtsBackend implements TtsBackend {
  EdgeExperimentalTtsBackend({
    Dio? dio,
    EdgeTtsWebSocketConnector? connector,
    EdgeTtsNowProvider? nowProvider,
    EdgeTtsIdProvider? idProvider,
  }) : _dio = dio ?? Dio(),
       _ownsDio = dio == null,
       _connector = connector ?? openEdgeTtsWebSocket,
       _nowProvider = nowProvider ?? DateTime.now,
       _idProvider = idProvider ?? edgeTtsConnectionId;

  final Dio _dio;
  final bool _ownsDio;
  final EdgeTtsWebSocketConnector _connector;
  final EdgeTtsNowProvider _nowProvider;
  final EdgeTtsIdProvider _idProvider;
  EdgeTtsWebSocketConnection? _activeConnection;
  bool _cancelled = false;
  Duration _clockSkew = Duration.zero;

  @override
  ReadAloudProvider get provider => ReadAloudProvider.edgeExperimental;

  @override
  TtsPlaybackMode get playbackMode => TtsPlaybackMode.generatedAudio;

  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<List<TtsVoiceOption>> getVoices() async {
    try {
      final response = await _dio.get<dynamic>(
        edgeTtsVoicesUri(nowUtc: _now()).toString(),
        options: Options(
          responseType: ResponseType.json,
          connectTimeout: kEdgeTtsConnectTimeout,
          receiveTimeout: kEdgeTtsSynthesisTimeout,
          headers: edgeTtsVoiceHeaders(),
        ),
      );
      return parseEdgeTtsVoices(response.data);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Edge TTS voice list request failed',
        error: error,
        stackTrace: stackTrace,
        tags: <String>{'tts', 'edge'},
      );
      return const <TtsVoiceOption>[];
    }
  }

  @override
  Future<List<String>> getLanguages() async {
    final voices = await getVoices();
    return voices
        .map((voice) => voice.locale)
        .whereType<String>()
        .toSet()
        .toList(growable: false);
  }

  @override
  Future<TtsSynthesisResult> speakOrSynthesize(
    TtsSynthesisRequest request,
    TtsBackendCallbacks callbacks,
  ) async {
    final text = stripEdgeTtsControlChars(request.text).trim();
    if (text.isEmpty) {
      throw TtsBackendException(
        TtsBackendErrorKind.invalidRequest,
        L10nBridge.current?.speechReadAloudNoText ??
            'There is no text to read aloud.',
      );
    }
    _cancelled = false;

    final voice = _effectiveVoice(request.voiceId);
    final locale = _effectiveLocale(request.voiceLocale, voice);
    try {
      return await _synthesizeAll(
        request: request,
        callbacks: callbacks,
        text: text,
        voice: voice,
        locale: locale,
      );
    } on _EdgeEmptyAudioException {
      // The configured voice no longer exists in Microsoft's catalog: the
      // server accepts the connection but closes it without any audio.
      // Retry once with the default voice for the locale before failing.
      final fallback = ReadAloudDefaultResolver.edgePreferenceForLocale(
        appLocaleCode: locale,
      );
      if (_cancelled || fallback.voiceId == voice) {
        throw _emptyAudioException();
      }
      AppLogger.warn(
        'Edge TTS voice unavailable; retrying with the default voice',
        metrics: <String, Object?>{
          'voice': voice,
          'fallbackVoice': fallback.voiceId,
        },
        tags: <String>{'tts', 'edge'},
      );
      try {
        return await _synthesizeAll(
          request: request,
          callbacks: callbacks,
          text: text,
          voice: fallback.voiceId,
          locale: fallback.locale,
        );
      } on _EdgeEmptyAudioException {
        throw _emptyAudioException();
      }
    }
  }

  Future<TtsSynthesisResult> _synthesizeAll({
    required TtsSynthesisRequest request,
    required TtsBackendCallbacks callbacks,
    required String text,
    required String voice,
    required String locale,
  }) async {
    final chunks = splitEdgeTtsTextChunks(text);
    final speakable = _withoutUnspeakableChunks(chunks);
    final effectiveChunks = speakable.isNotEmpty ? speakable : chunks;
    final audio = BytesBuilder(copy: false);

    try {
      callbacks.onStart?.call();
      for (var index = 0; index < effectiveChunks.length; index += 1) {
        _throwIfCancelled();
        await _synthesizeChunk(
          request: request,
          chunk: effectiveChunks[index],
          chunkIndex: index,
          chunkCount: effectiveChunks.length,
          voice: voice,
          locale: locale,
          audio: audio,
        );
        AppLogger.debug(
          'Edge TTS chunk synthesized',
          metrics: <String, Object?>{
            'chunk': index + 1,
            'chunks': chunks.length,
            'audioBytes': audio.length,
          },
          tags: <String>{'tts', 'edge'},
        );
      }
      final bytes = audio.takeBytes();
      if (bytes.isEmpty) {
        throw const _EdgeEmptyAudioException();
      }
      return GeneratedTtsAudio(
        bytes: bytes,
        mimeType: kEdgeTtsAudioMimeType,
      );
    } on TimeoutException catch (_) {
      throw TtsBackendException(
        TtsBackendErrorKind.network,
        L10nBridge.current?.speechEdgeTimedOut ??
            'Microsoft Edge Speech timed out.',
      );
    } on FormatException catch (_) {
      throw TtsBackendException(
        TtsBackendErrorKind.providerUnavailable,
        L10nBridge.current?.speechEdgeMalformedAudio ??
            'Microsoft Edge Speech returned malformed audio data.',
      );
    } on TtsBackendException {
      rethrow;
    } on _EdgeEmptyAudioException {
      rethrow;
    } catch (error, stackTrace) {
      if (_cancelled) {
        throw TtsBackendException(
          TtsBackendErrorKind.providerUnavailable,
          L10nBridge.current?.speechEdgeCancelled ??
              'Microsoft Edge Speech was cancelled.',
        );
      }
      AppLogger.warn(
        'Edge TTS synthesis failed',
        error: error,
        stackTrace: stackTrace,
        tags: <String>{'tts', 'edge'},
      );
      throw TtsBackendException(
        TtsBackendErrorKind.network,
        L10nBridge.current?.speechEdgeUnreachable ??
            'Microsoft Edge Speech could not be reached.',
      );
    }
  }

  /// Synthesizes one text chunk over a fresh websocket connection and
  /// appends the received audio bytes to [audio].
  Future<void> _synthesizeChunk({
    required TtsSynthesisRequest request,
    required String chunk,
    required int chunkIndex,
    required int chunkCount,
    required String voice,
    required String locale,
    required BytesBuilder audio,
  }) async {
    final connectionId = _idProvider().replaceAll('-', '');
    final connection = await _connectWithRetry(connectionId: connectionId);

    try {
      _throwIfCancelled();
      final requestId = _idProvider().replaceAll('-', '');
      connection.sendText(
        edgeTtsSpeechConfigFrame(nowUtc: _now()),
      );
      connection.sendText(
        edgeTtsSsmlFrame(
          requestId: requestId,
          ssml: buildEdgeTtsSsml(
            text: chunk,
            voice: voice,
            locale: locale,
            rate: edgeTtsRateAttribute(request.rate),
            pitch: edgeTtsPitchAttribute(1.0),
          ),
          nowUtc: _now(),
        ),
      );
      AppLogger.debug(
        'Edge TTS chunk requested',
        metrics: <String, Object?>{
          'chunk': chunkIndex + 1,
          'chunks': chunkCount,
          'chunkBytes': edgeTtsEscapedByteLength(chunk),
          'voice': voice,
        },
        tags: <String>{'tts', 'edge'},
      );
      final audioBeforeChunk = audio.length;
      var receivedTurnEnd = false;

      await for (final event in connection.stream.timeout(
        kEdgeTtsSynthesisTimeout,
      )) {
        if (_cancelled) {
          throw TtsBackendException(
            TtsBackendErrorKind.providerUnavailable,
            L10nBridge.current?.speechEdgeCancelled ??
                'Microsoft Edge Speech was cancelled.',
          );
        }
        if (event is String) {
          final frame = parseEdgeTtsTextFrame(event);
          if (frame.path == 'error') {
            AppLogger.warn(
              'Edge TTS server reported an error frame',
              metrics: <String, Object?>{
                'path': frame.path,
                'body': frame.body,
                'chunk': chunkIndex + 1,
              },
              tags: <String>{'tts', 'edge'},
            );
            throw TtsBackendException(
              TtsBackendErrorKind.providerUnavailable,
              _serverErrorMessage(frame.body),
            );
          }
          if (frame.path == 'turn.end') {
            receivedTurnEnd = true;
            break;
          }
          continue;
        }
        if (event is List<int>) {
          final frame = parseEdgeTtsBinaryFrame(event);
          if (frame.path != 'audio') {
            continue;
          }
          if (frame.contentType == null) {
            if (frame.audioBytes.isEmpty) {
              continue;
            }
            throw TtsBackendException(
              TtsBackendErrorKind.providerUnavailable,
              L10nBridge.current?.speechEdgeMalformedAudio ??
                  'Microsoft Edge Speech returned malformed audio data.',
            );
          }
          if (frame.contentType != kEdgeTtsAudioMimeType) {
            throw TtsBackendException(
              TtsBackendErrorKind.providerUnavailable,
              L10nBridge.current?.speechEdgeUnsupportedAudio ??
                  'Microsoft Edge Speech returned unsupported audio data.',
            );
          }
          if (frame.audioBytes.isNotEmpty) {
            audio.add(frame.audioBytes);
          }
          continue;
        }
        throw TtsBackendException(
          TtsBackendErrorKind.providerUnavailable,
          L10nBridge.current?.speechEdgeUnsupportedFrame ??
              'Microsoft Edge Speech returned an unsupported websocket frame.',
        );
      }

      if (_cancelled) {
        throw TtsBackendException(
          TtsBackendErrorKind.providerUnavailable,
          L10nBridge.current?.speechEdgeCancelled ??
              'Microsoft Edge Speech was cancelled.',
        );
      }
      if (!receivedTurnEnd) {
        if (audio.length == audioBeforeChunk) {
          throw const _EdgeEmptyAudioException();
        }
        throw TtsBackendException(
          TtsBackendErrorKind.providerUnavailable,
          L10nBridge.current?.speechEdgeSynthesisInterrupted ??
              'Microsoft Edge Speech ended before synthesis completed.',
        );
      }
      if (audio.length == audioBeforeChunk) {
        // A chunk with no speakable content (e.g. emoji or a separator line)
        // legitimately produces no audio. Only fail when it is the sole
        // chunk; the aggregate empty check in _synthesizeAll covers the
        // all-chunks-silent case.
        if (chunkCount == 1) {
          throw const _EdgeEmptyAudioException();
        }
        AppLogger.warn(
          'Edge TTS chunk produced no audio',
          metrics: <String, Object?>{
            'chunk': chunkIndex + 1,
            'chunks': chunkCount,
          },
          tags: <String>{'tts', 'edge'},
        );
      } else {
        AppLogger.debug(
          'Edge TTS turn.end received',
          metrics: <String, Object?>{
            'chunk': chunkIndex + 1,
            'chunks': chunkCount,
            'audioBytes': audio.length - audioBeforeChunk,
          },
          tags: <String>{'tts', 'edge'},
        );
      }
    } finally {
      if (identical(_activeConnection, connection)) {
        _activeConnection = null;
      }
      try {
        await connection.close().timeout(
          const Duration(seconds: 2),
          onTimeout: () {},
        );
      } catch (_) {}
    }
  }

  /// Opens the websocket, applying one clock-skew retry when the server
  /// rejects the handshake with HTTP 403 and provides a Date header.
  ///
  /// The returned connection is already ready and its ownership (closing)
  /// transfers to the caller. Every failed attempt is closed and detached
  /// from [_activeConnection] before returning or throwing.
  Future<EdgeTtsWebSocketConnection> _connectWithRetry({
    required String connectionId,
  }) async {
    for (var attempt = 0; attempt < 2; attempt += 1) {
      _throwIfCancelled();
      final connection = _openConnection(connectionId);
      try {
        await connection.ready.timeout(kEdgeTtsConnectTimeout);
        return connection;
      } catch (error, stackTrace) {
        if (error is EdgeTtsWebSocketUpgradeException) {
          AppLogger.warn(
            'Edge TTS websocket upgrade failed',
            error: error,
            metrics: <String, Object?>{
              'attempt': attempt + 1,
              'statusCode': error.statusCode,
              'reason': error.reasonPhrase,
              'dateHeader': error.dateHeader,
            },
            tags: <String>{'tts', 'edge'},
          );
          if (_tryAdjustClockSkew(error) && attempt == 0) {
            await _closeAndDetach(connection);
            continue;
          }
          await _closeAndDetach(connection);
          if (_cancelled) {
            throw TtsBackendException(
              TtsBackendErrorKind.providerUnavailable,
              L10nBridge.current?.speechEdgeCancelled ??
                  'Microsoft Edge Speech was cancelled.',
            );
          }
          throw TtsBackendException(
            _errorKindForStatus(error.statusCode),
            _upgradeErrorMessage(error),
            statusCode: error.statusCode,
          );
        }
        AppLogger.warn(
          'Edge TTS websocket connect failed',
          error: error,
          stackTrace: stackTrace,
          metrics: <String, Object?>{'attempt': attempt + 1},
          tags: <String>{'tts', 'edge'},
        );
        await _closeAndDetach(connection);
        if (_cancelled) {
          throw TtsBackendException(
            TtsBackendErrorKind.providerUnavailable,
            L10nBridge.current?.speechEdgeCancelled ??
                'Microsoft Edge Speech was cancelled.',
          );
        }
        if (error is TimeoutException) {
          throw TtsBackendException(
            TtsBackendErrorKind.network,
            L10nBridge.current?.speechEdgeTimedOut ??
                'Microsoft Edge Speech timed out.',
          );
        }
        throw TtsBackendException(
          TtsBackendErrorKind.network,
          L10nBridge.current?.speechEdgeUnreachable ??
              'Microsoft Edge Speech could not be reached.',
        );
      }
    }
    throw TtsBackendException(
      TtsBackendErrorKind.network,
      L10nBridge.current?.speechEdgeUnreachable ??
          'Microsoft Edge Speech could not be reached.',
    );
  }

  Future<void> _closeAndDetach(EdgeTtsWebSocketConnection connection) async {
    if (identical(_activeConnection, connection)) {
      _activeConnection = null;
    }
    try {
      await connection.close().timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
    } catch (_) {}
  }

  /// When the handshake fails with HTTP 403 and a parseable `Date` header,
  /// stores the clock skew so the next Sec-MS-GEC token is computed with the
  /// server's time. Returns whether a retry should be attempted.
  bool _tryAdjustClockSkew(EdgeTtsWebSocketUpgradeException error) {
    if (error.statusCode != 403 || error.dateHeader == null) {
      return false;
    }
    final serverTime = parseEdgeTtsHttpDate(error.dateHeader!);
    if (serverTime == null) {
      return false;
    }
    _clockSkew = serverTime.difference(_nowProvider().toUtc());
    AppLogger.info(
      'Edge TTS clock skew adjusted; retrying handshake once',
      metrics: <String, Object?>{
        'serverTime': serverTime.toIso8601String(),
        'skewSeconds': _clockSkew.inSeconds,
      },
      tags: <String>{'tts', 'edge'},
    );
    return true;
  }

  EdgeTtsWebSocketConnection _openConnection(String connectionId) {
    final connection = _connector(
      edgeTtsWebSocketUri(
        connectionId: connectionId,
        nowUtc: _now(),
      ),
    );
    _activeConnection = connection;
    return connection;
  }

  /// Current UTC time, adjusted by the last known clock skew.
  DateTime _now() => _nowProvider().toUtc().add(_clockSkew);

  /// Filters out chunks with no speakable content (e.g. emoji or separator
  /// lines) so they do not cost a websocket round trip. Returns the input
  /// unchanged when nothing would remain, preserving the original error paths.
  static List<String> _withoutUnspeakableChunks(List<String> chunks) {
    final speakable = chunks
        .where((chunk) => chunk.contains(_edgeTtsSpeakableContent))
        .toList(growable: false);
    return speakable.isEmpty ? chunks : speakable;
  }

  void _throwIfCancelled() {
    if (!_cancelled) {
      return;
    }
    throw TtsBackendException(
      TtsBackendErrorKind.providerUnavailable,
      L10nBridge.current?.speechEdgeCancelled ??
          'Microsoft Edge Speech was cancelled.',
    );
  }

  String _serverErrorMessage(String body) {
    final trimmed = body.trim();
    if (trimmed.isNotEmpty && trimmed.length <= 200) {
      return trimmed;
    }
    return L10nBridge.current?.speechEdgeSynthesisInterrupted ??
        'Microsoft Edge Speech ended before synthesis completed.';
  }

  TtsBackendErrorKind _errorKindForStatus(int statusCode) {
    if (statusCode == 429) {
      return TtsBackendErrorKind.rateLimitedOrQuota;
    }
    if (statusCode == 403) {
      return TtsBackendErrorKind.providerUnavailable;
    }
    return TtsBackendErrorKind.network;
  }

  String _upgradeErrorMessage(EdgeTtsWebSocketUpgradeException error) {
    final base = L10nBridge.current?.speechEdgeUnreachable ??
        'Microsoft Edge Speech could not be reached.';
    return '$base (HTTP ${error.statusCode})';
  }

  @override
  Future<void> stop() async {
    _cancelled = true;
    final connection = _activeConnection;
    _activeConnection = null;
    await connection?.close().timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    );
  }

  @override
  Future<void> pause() async {}

  @override
  void dispose() {
    unawaited(stop());
    if (_ownsDio) {
      _dio.close(force: true);
    }
  }

  String _effectiveVoice(String? voiceId) {
    final trimmed = voiceId?.trim();
    return trimmed != null && trimmed.isNotEmpty
        ? trimmed
        : kDefaultEdgeTtsVoice;
  }

  String _effectiveLocale(String? locale, String voice) {
    final trimmed = locale?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    final parts = voice.split('-');
    if (parts.length >= 2) {
      return '${parts[0]}-${parts[1]}';
    }
    return 'en-US';
  }

  TtsBackendException _emptyAudioException() {
    return TtsBackendException(
      TtsBackendErrorKind.providerUnavailable,
      L10nBridge.current?.speechEdgeEmptyAudio ??
          'Microsoft Edge Speech returned an empty audio response.',
    );
  }
}

/// Internal marker for a synthesis that produced no audio at all (stream
/// closed without `turn.end` or with a turn that carried zero bytes), which
/// is how the server signals a voice that is no longer in its catalog.
class _EdgeEmptyAudioException implements Exception {
  const _EdgeEmptyAudioException();
}

@visibleForTesting
List<TtsVoiceOption> parseEdgeTtsVoices(dynamic data) {
  if (data is! List) {
    return const <TtsVoiceOption>[];
  }
  return data
      .map<TtsVoiceOption?>((dynamic value) {
        if (value is! Map) {
          return null;
        }
        final id = value['ShortName']?.toString() ?? value['Name']?.toString();
        if (id == null || id.trim().isEmpty) {
          return null;
        }
        final locale = value['Locale']?.toString();
        final friendlyName = value['FriendlyName']?.toString();
        final gender = value['Gender']?.toString();
        final label = friendlyName != null && friendlyName.isNotEmpty
            ? friendlyName
            : id;
        return TtsVoiceOption(
          id: id,
          label: locale != null && locale.isNotEmpty
              ? '$label ($locale)'
              : label,
          locale: locale,
          providerMetadata: <String, String>{
            if (gender != null && gender.isNotEmpty) 'gender': gender,
          },
        );
      })
      .whereType<TtsVoiceOption>()
      .toList(growable: false);
}
