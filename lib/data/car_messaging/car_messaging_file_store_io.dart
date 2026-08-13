// ignore_for_file: avoid_slow_async_io

import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

import 'car_messaging_file_store_base.dart';

CarMessagingFileStore createCarMessagingFileStore() =>
    _IoCarMessagingFileStore();

class _IoCarMessagingFileStore implements CarMessagingFileStore {
  static const Duration _staleLockAge = Duration(minutes: 2);
  Future<File>? _fileFuture;

  @override
  Future<T> synchronized<T>(Future<T> Function() operation) async {
    final target = await _file();
    await target.parent.create(recursive: true);
    final owner = File('${target.path}.lock');
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (true) {
      try {
        await owner.create(exclusive: true);
        await owner.writeAsString(
          DateTime.now().millisecondsSinceEpoch.toString(),
          flush: true,
        );
        break;
      } on FileSystemException {
        try {
          final modified = await owner.lastModified();
          if (DateTime.now().difference(modified) >= _staleLockAge) {
            final suffix = Random.secure().nextInt(1 << 32).toRadixString(16);
            final stale = File('${owner.path}.stale.$suffix');
            await owner.rename(stale.path);
            await stale.delete();
            continue;
          }
        } on FileSystemException {
          // The owner changed between stat and cleanup; retry acquisition.
        }
        if (DateTime.now().isAfter(deadline)) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    }
    try {
      return await operation();
    } finally {
      if (await owner.exists()) await owner.delete();
    }
  }

  @override
  Future<String?> read() async {
    final file = await _file();
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<void> writeAtomically(String value) async {
    final target = await _file();
    await target.parent.create(recursive: true);
    final suffix = List<int>.generate(
      12,
      (_) => Random.secure().nextInt(256),
      growable: false,
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final temporary = File('${target.path}.tmp.$suffix');
    try {
      await temporary.writeAsString(value, flush: true);
      await temporary.rename(target.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  @override
  Future<void> delete() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }

  Future<File> _file() {
    _fileFuture ??= _resolveFile();
    return _fileFuture!;
  }

  Future<File> _resolveFile() async {
    final support = await getApplicationSupportDirectory();
    return File(
      '${support.path}${Platform.pathSeparator}car_messaging_v1'
      '${Platform.pathSeparator}state.json',
    );
  }
}
