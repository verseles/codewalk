import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/experience_settings.dart';
import 'stt_model_archive_installer_io.dart';
import 'stt_model_download_tracker.dart';

class _MoonshineModelSpec {
  const _MoonshineModelSpec({
    required this.id,
    required this.label,
    required this.sizeMb,
    required this.packageName,
    required this.files,
  });

  final String id;
  final String label;
  final int sizeMb;
  final String packageName;
  final List<String> files;
}

// Native implementation of Moonshine model management for IO platforms.
// Models are downloaded on demand from official sherpa-onnx release assets and
// extracted under getApplicationSupportDirectory().
class MoonshineModelManager {
  static const _releaseBase =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models';
  static const _vadFile = 'silero_vad.onnx';
  static const _models = <String, _MoonshineModelSpec>{
    kMoonshineModelTiny: _MoonshineModelSpec(
      id: kMoonshineModelTiny,
      label: 'Tiny (English)',
      sizeMb: 118,
      packageName: 'sherpa-onnx-moonshine-tiny-en-int8',
      files: <String>[
        'preprocess.onnx',
        'encode.int8.onnx',
        'uncached_decode.int8.onnx',
        'cached_decode.int8.onnx',
        'tokens.txt',
      ],
    ),
    kMoonshineModelBase: _MoonshineModelSpec(
      id: kMoonshineModelBase,
      label: 'Base (English)',
      sizeMb: 272,
      packageName: 'sherpa-onnx-moonshine-base-en-int8',
      files: <String>[
        'preprocess.onnx',
        'encode.int8.onnx',
        'uncached_decode.int8.onnx',
        'cached_decode.int8.onnx',
        'tokens.txt',
      ],
    ),
  };

  String? _cachedBaseDir;
  String? _preferredModelId;
  final Dio _dio = Dio();

  String normalizeModelId(String? modelId) {
    final raw = modelId?.trim().toLowerCase();
    if (raw != null && _models.containsKey(raw)) {
      return raw;
    }
    return kMoonshineModelTiny;
  }

  void setPreferredModelId(String modelId) {
    _preferredModelId = normalizeModelId(modelId);
  }

  String getPreferredModelId() {
    return normalizeModelId(_preferredModelId);
  }

  Future<String?> findInstalledModelId() async {
    for (final id in _models.keys) {
      if (await hasModel(id)) {
        return id;
      }
    }
    return null;
  }

  Future<bool> hasModel(String modelId) async {
    final spec = _specFor(modelId);
    final dir = Directory(await getModelDir(spec.id));
    if (!dir.existsSync()) {
      return false;
    }
    for (final file in spec.files) {
      if (!File('${dir.path}/$file').existsSync()) {
        return false;
      }
    }
    return File('${dir.path}/$_vadFile').existsSync();
  }

  Future<void> downloadModel(
    String modelId, {
    void Function(double)? onProgress,
  }) async {
    await SttModelDownloadTracker.instance.run(
      engine: SpeechToTextEngine.moonshine,
      modelId: normalizeModelId(modelId),
      onProgress: onProgress,
      download: (report) => _downloadModel(modelId, report),
    );
  }

  Future<void> _downloadModel(
    String modelId,
    void Function(double) onProgress,
  ) async {
    final spec = _specFor(modelId);
    final dir = Directory(await getModelDir(spec.id));
    await installSttModelArchive(
      dio: _dio,
      url: '$_releaseBase/${spec.packageName}.tar.bz2',
      destination: dir,
      files: spec.files,
      additionalUrl: '$_releaseBase/$_vadFile',
      additionalFile: _vadFile,
      onProgress: onProgress,
    );
  }

  Future<void> deleteModel(String modelId) async {
    final dir = Directory(await getModelDir(modelId));
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  Future<String> getModelDir(String modelId) async {
    final base = await _getAppSupportDir();
    final normalized = normalizeModelId(modelId);
    return '$base/moonshine_models/$normalized';
  }

  Future<String> _getAppSupportDir() async {
    if (_cachedBaseDir != null) {
      return _cachedBaseDir!;
    }
    final dir = await getApplicationSupportDirectory();
    _cachedBaseDir = dir.path;
    return _cachedBaseDir!;
  }

  _MoonshineModelSpec _specFor(String modelId) {
    final normalized = normalizeModelId(modelId);
    return _models[normalized]!;
  }

}
