import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/experience_settings.dart';
import 'speech_model_residency_controller.dart';
import 'stt_model_download_tracker.dart';

// Native implementation of sherpa-onnx model management for IO platforms.
// Handles on-demand download of Kroko streaming transducer models from
// HuggingFace, local storage under getApplicationSupportDirectory(), locale
// detection, and model lifecycle (install / check / delete).
class SherpaModelManager {
  SherpaModelManager({Dio? dio}) : _dio = dio ?? Dio();
  static const _availableLangs = ['de', 'en', 'es', 'fr', 'it', 'pt', 'tr'];

  // The 4 files required per language model (INT8 quantized Kroko 64-layer).
  static const _modelFiles = [
    'encoder.int8.onnx',
    'decoder.int8.onnx',
    'joiner.int8.onnx',
    'tokens.txt',
  ];

  static const _huggingFaceBase = 'https://huggingface.co';
  static const _repo = 'hudaiapa88/sherpa-stt-onnx';

  String? _cachedBaseDir;
  String? _preferredLanguage;
  final Dio _dio;

  // Parses language or locale (e.g. `pt-BR`, `pt_BR.UTF-8`) to a supported
  // two-letter code, defaulting to `en` when unknown.
  String normalizeLanguageCode(String? languageOrLocale) {
    if (languageOrLocale == null || languageOrLocale.trim().isEmpty) {
      return 'en';
    }
    final raw = languageOrLocale
        .split(RegExp(r'[_.\-]'))
        .first
        .trim()
        .toLowerCase();
    if (_availableLangs.contains(raw)) {
      return raw;
    }
    return 'en';
  }

  // Stores the preferred STT language for next recognition sessions.
  void setPreferredLanguage(String languageOrLocale) {
    _preferredLanguage = normalizeLanguageCode(languageOrLocale);
  }

  // Returns preferred language if set, otherwise the system locale language.
  String getPreferredLanguage() {
    final preferred = _preferredLanguage;
    if (preferred != null && _availableLangs.contains(preferred)) {
      return preferred;
    }
    return detectSystemLanguage();
  }

  // Returns the first installed model language, or null when none is present.
  Future<String?> findInstalledLanguage() async {
    for (final lang in _availableLangs) {
      if (await hasModel(lang)) {
        return lang;
      }
    }
    return null;
  }

  // Returns true when all 4 model files for [lang] exist on disk.
  Future<bool> hasModel(String lang) async {
    final dir = Directory(await getModelDir(lang));
    if (!dir.existsSync()) return false;
    for (final file in _modelFiles) {
      if (!File('${dir.path}/$file').existsSync()) return false;
    }
    return true;
  }

  // Downloads all 4 model files for [lang] from HuggingFace.
  // [onProgress] receives a value in [0.0, 1.0] aggregated across all files.
  Future<void> downloadModel(
    String lang, {
    void Function(double)? onProgress,
  }) async {
    await SttModelDownloadTracker.instance.run(
      engine: SpeechToTextEngine.sherpa,
      modelId: lang,
      onProgress: onProgress,
      download: (report) => _downloadModel(lang, report),
    );
  }

  Future<void> _downloadModel(
    String lang,
    void Function(double) onProgress,
  ) async {
    final dir = Directory(await getModelDir(lang));
    await dir.parent.create(recursive: true);
    final staged = await dir.parent.createTemp('.sherpa-install-');
    Directory? backup;
    try {
      final path = '$lang/kroko_64l';
      final base = '$_huggingFaceBase/$_repo/resolve/main/$path';
      for (var i = 0; i < _modelFiles.length; i++) {
        final file = _modelFiles[i];
        await _dio.download(
          '$base/$file',
          '${staged.path}/$file',
          options: Options(
            followRedirects: true,
            receiveTimeout: const Duration(minutes: 10),
          ),
          onReceiveProgress: (received, total) {
            if (total > 0) {
              onProgress((i + received / total) / _modelFiles.length);
            }
          },
        );
        if (File('${staged.path}/$file').lengthSync() == 0) {
          throw FormatException('Empty model file: $file');
        }
      }
      await SpeechModelResidencyController.instance.mutateModel(
        dir.path,
        () async {
          if (dir.existsSync()) {
            backup = await dir.parent.createTemp('.sherpa-previous-');
            await backup!.delete();
            await dir.rename(backup!.path);
          }
          try {
            await staged.rename(dir.path);
          } catch (_) {
            if (backup != null) {
              try {
                await backup!.rename(dir.path);
                backup = null;
              } catch (restoreError) {
                throw StateError(
                  'Could not restore previous model from ${backup?.path}: $restoreError',
                );
              }
            }
            rethrow;
          }
        },
      );
      onProgress(1.0);
    } finally {
      if (staged.existsSync()) await staged.delete(recursive: true);
      final previous = backup;
      if (previous != null && dir.existsSync() && previous.existsSync()) {
        await previous.delete(recursive: true);
      }
    }
  }

  // Removes all model files for [lang] from disk to free space.
  Future<void> deleteModel(String lang) async {
    final dir = Directory(await getModelDir(lang));
    await SpeechModelResidencyController.instance.mutateModel(
      dir.path,
      () async {
        if (dir.existsSync()) await dir.delete(recursive: true);
      },
    );
  }

  // Returns the local directory path for [lang] model files.
  Future<String> getModelDir(String lang) async {
    final base = await _getAppSupportDir();
    return '$base/sherpa_models/$lang';
  }

  // Parses the system locale (e.g. 'pt_BR.UTF-8') and returns a matching
  // language code from the available models, falling back to 'en'.
  String detectSystemLanguage() {
    return normalizeLanguageCode(Platform.localeName);
  }

  // Returns (and caches) the application support directory path.
  Future<String> _getAppSupportDir() async {
    if (_cachedBaseDir != null) return _cachedBaseDir!;
    final dir = await getApplicationSupportDirectory();
    _cachedBaseDir = dir.path;
    return _cachedBaseDir!;
  }
}
