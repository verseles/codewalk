import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'speech_model_residency_controller.dart';

final _installingModels = <String>{};

/// Downloads into a sibling directory so incomplete files cannot look installed.
Future<void> installSttModelArchive({
  required Dio dio,
  required String url,
  required Directory destination,
  required List<String> files,
  String? additionalUrl,
  String? additionalFile,
  void Function(double)? onProgress,
}) async {
  if (!_installingModels.add(destination.path)) {
    throw StateError('Model download already in progress');
  }
  final parent = destination.parent;
  Directory? workspace;
  Directory? backup;
  try {
    await parent.create(recursive: true);
    workspace = await parent.createTemp('.stt-install-');
    final archivePath = '${workspace.path}/model.tar.bz2';
    final tarPath = '${workspace.path}/model.tar';
    final staged = Directory('${workspace.path}/model');
    await staged.create();

    final archiveWeight = additionalUrl == null ? 0.9 : 0.75;
    await dio.download(
      url,
      archivePath,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          onProgress?.call((received / total).clamp(0.0, 1.0) * archiveWeight);
        }
      },
    );
    // Only plain data crosses the isolate boundary. An inline closure here can
    // retain the caller's progress callback (and its entire widget tree).
    await compute(_extractArchiveTask, (
      archivePath,
      tarPath,
      staged.path,
      List<String>.of(files),
    ));
    if (additionalUrl != null && additionalFile != null) {
      await dio.download(
        additionalUrl,
        '${staged.path}/$additionalFile',
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress?.call(
              archiveWeight +
                  (received / total).clamp(0.0, 1.0) * (0.99 - archiveWeight),
            );
          }
        },
      );
    }
    for (final name in [...files, ?additionalFile]) {
      if (File('${staged.path}/$name').lengthSync() == 0) {
        throw FormatException('Empty model file: $name');
      }
    }
    await SpeechModelResidencyController.instance.mutateModel(
      destination.path,
      () async {
        if (destination.existsSync()) {
          backup = await parent.createTemp('.stt-previous-');
          await backup!.delete();
          await destination.rename(backup!.path);
        }
        try {
          await staged.rename(destination.path);
        } catch (_) {
          if (backup != null) {
            try {
              await backup!.rename(destination.path);
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
    onProgress?.call(1);
  } finally {
    try {
      if (workspace != null && workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
      // If restoration failed, the backup may be the only surviving model copy.
      final previous = backup;
      if (previous != null &&
          destination.existsSync() &&
          previous.existsSync()) {
        await previous.delete(recursive: true);
      }
    } finally {
      _installingModels.remove(destination.path);
    }
  }
}

void _extractArchiveTask((String, String, String, List<String>) task) {
  _extractArchive(task.$1, task.$2, task.$3, task.$4);
}

void _extractArchive(
  String archivePath,
  String tarPath,
  String destinationPath,
  List<String> files,
) {
  final input = InputFileStream(archivePath);
  final output = OutputFileStream(tarPath);
  bool decoded;
  try {
    decoded = BZip2Decoder().decodeStream(input, output, verify: true);
  } finally {
    input.closeSync();
    output.closeSync();
  }
  if (!decoded) {
    throw const FormatException('Invalid bzip2 model archive');
  }
  File(archivePath).deleteSync();

  final tarInput = InputFileStream(tarPath);
  Archive? archive;
  try {
    archive = TarDecoder().decodeStream(tarInput);
    final expected = files.toSet();
    final found = <String>{};
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name.split('/').last;
      if (!expected.contains(name)) continue;
      if (!found.add(name)) {
        throw FormatException('Duplicate model file: $name');
      }
      final fileOutput = OutputFileStream('$destinationPath/$name');
      try {
        entry.writeContent(fileOutput);
      } finally {
        fileOutput.closeSync();
      }
    }
    if (found.length != expected.length) {
      throw const FormatException('Missing model files in archive');
    }
  } finally {
    archive?.clear();
    tarInput.closeSync();
  }
}
