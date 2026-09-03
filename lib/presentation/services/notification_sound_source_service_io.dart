import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/logging/app_logger.dart';
import 'notification_sound_source_service_types.dart';

NotificationSoundSourceService createNotificationSoundSourceService() {
  return _NotificationSoundSourceServiceIo();
}

class _NotificationSoundSourceServiceIo
    implements NotificationSoundSourceService {
  static const MethodChannel _androidChannel = MethodChannel(
    'codewalk/system_sounds',
  );

  static const List<String> _audioExtensions = <String>[
    'aac',
    'flac',
    'm4a',
    'mp3',
    'oga',
    'ogg',
    'wav',
    'wma',
  ];

  @override
  bool get supportsSystemSoundPicker {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  Future<List<SystemSoundChoice>> listSystemSounds() async {
    if (!supportsSystemSoundPicker) {
      return const <SystemSoundChoice>[];
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _listAndroidSystemSounds();
    }
    if (defaultTargetPlatform == TargetPlatform.linux) {
      return _listLinuxSystemSounds();
    }
    return const <SystemSoundChoice>[];
  }

  @override
  Future<RegisteredSoundFile?> pickAndRegisterCustomFile() async {
    if (kIsWeb) {
      return null;
    }

    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _audioExtensions,
    );
    final picked = files.isEmpty ? null : files.first;
    if (picked == null) {
      return null;
    }

    final bytes = await _resolveFileBytes(picked);
    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    final supportDir = await getApplicationSupportDirectory();
    final soundsDir = Directory('${supportDir.path}/notification_sounds');
    if (!soundsDir.existsSync()) {
      await soundsDir.create(recursive: true);
    }

    final extension = _resolveExtension(picked.name);
    final safeLabel = _sanitizeFileName(_stripExtension(picked.name));
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath =
        '${soundsDir.path}/$timestamp-$safeLabel${extension == null ? '' : '.$extension'}';

    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(bytes, flush: true);

    return RegisteredSoundFile(source: outputFile.path, label: picked.name);
  }

  Future<List<SystemSoundChoice>> _listAndroidSystemSounds() async {
    try {
      final raw = await _androidChannel.invokeListMethod<dynamic>(
        'listNotificationSounds',
      );
      if (raw == null) {
        return const <SystemSoundChoice>[];
      }

      final dedupe = <String>{};
      final sounds = <SystemSoundChoice>[];
      for (final item in raw) {
        if (item is! Map) {
          continue;
        }
        final source = item['source']?.toString().trim();
        final label = item['label']?.toString().trim();
        if (source == null ||
            source.isEmpty ||
            label == null ||
            label.isEmpty) {
          continue;
        }
        if (!dedupe.add(source)) {
          continue;
        }
        sounds.add(
          SystemSoundChoice(
            id: item['id']?.toString() ?? source,
            label: label,
            source: source,
          ),
        );
      }
      return sounds;
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to load Android system sounds',
        error: error,
        stackTrace: stackTrace,
      );
      return const <SystemSoundChoice>[];
    }
  }

  Future<List<SystemSoundChoice>> _listLinuxSystemSounds() async {
    final entries = <SystemSoundChoice>[];
    final candidates = <Directory>[];

    for (final root in _linuxSoundRoots()) {
      final directory = Directory(root);
      if (!directory.existsSync()) {
        continue;
      }
      candidates.add(directory);
    }

    for (final directory in candidates) {
      final files = directory.listSync(followLinks: false);
      for (final entity in files) {
        if (entity is! File) {
          continue;
        }
        final name = _fileName(entity.path);
        final extension = _resolveExtension(name);
        if (extension == null || !_audioExtensions.contains(extension)) {
          continue;
        }
        final baseName = _stripExtension(name);
        if (baseName.isEmpty) {
          continue;
        }
        entries.add(
          SystemSoundChoice(
            id: 'linux:$baseName',
            label: _humanize(baseName),
            source: entity.path,
          ),
        );
      }
    }

    final dedupe = <String, SystemSoundChoice>{};
    for (final entry in entries) {
      dedupe.putIfAbsent(entry.id, () => entry);
    }
    final result = dedupe.values.toList(growable: false)
      ..sort((a, b) => a.label.compareTo(b.label));
    return result;
  }

  Iterable<String> _linuxSoundRoots() sync* {
    final home = Platform.environment['HOME'];
    if (home != null && home.trim().isNotEmpty) {
      yield '$home/.local/share/sounds/freedesktop/stereo';
    }

    final xdgDataDirs = Platform.environment['XDG_DATA_DIRS'];
    final roots = (xdgDataDirs == null || xdgDataDirs.trim().isEmpty)
        ? const <String>['/usr/local/share', '/usr/share']
        : xdgDataDirs.split(':');
    for (final root in roots) {
      final trimmed = root.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      yield '$trimmed/sounds/freedesktop/stereo';
    }
  }

  Future<List<int>?> _resolveFileBytes(PlatformFile file) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) {
        return bytes;
      }
    } on Exception {
      // Fall through to the local-path fallback below.
    }

    final path = file.path;
    if (path == null || path.trim().isEmpty) {
      return null;
    }
    final ioFile = File(path);
    if (!ioFile.existsSync()) {
      return null;
    }
    return ioFile.readAsBytes();
  }

  String _fileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final slashIndex = normalized.lastIndexOf('/');
    if (slashIndex < 0) {
      return normalized;
    }
    return normalized.substring(slashIndex + 1);
  }

  String _stripExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0) {
      return fileName;
    }
    return fileName.substring(0, dotIndex);
  }

  String? _resolveExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == fileName.length - 1) {
      return null;
    }
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  String _sanitizeFileName(String value) {
    final buffer = StringBuffer();
    for (final codeUnit in value.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      final isAlphaNum =
          (codeUnit >= 48 && codeUnit <= 57) ||
          (codeUnit >= 65 && codeUnit <= 90) ||
          (codeUnit >= 97 && codeUnit <= 122);
      if (isAlphaNum || char == '_' || char == '-') {
        buffer.write(char);
      } else if (char == ' ') {
        buffer.write('_');
      }
    }
    final sanitized = buffer.toString().trim();
    if (sanitized.isEmpty) {
      return 'sound';
    }
    return sanitized;
  }

  String _humanize(String value) {
    final withSpaces = value.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    if (withSpaces.isEmpty) {
      return value;
    }
    final words = withSpaces.split(' ');
    return words
        .map((word) {
          if (word.isEmpty) {
            return word;
          }
          return '${word[0].toUpperCase()}${word.substring(1)}';
        })
        .join(' ');
  }
}
