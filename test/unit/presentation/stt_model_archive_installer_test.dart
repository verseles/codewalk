import 'dart:io';

import 'package:archive/archive.dart';
import 'package:codewalk/presentation/services/stt_model_archive_installer_io.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;
  late HttpServer server;
  late List<int> response;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('stt-installer-test-');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.add(response);
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await temp.delete(recursive: true);
  });

  List<int> makeArchive({bool omitTokens = false}) {
    final archive = Archive()
      ..addFile(ArchiveFile.bytes('model/encoder.onnx', [1, 2, 3]))
      ..addFile(ArchiveFile.bytes('model/ignored.txt', [9]));
    if (!omitTokens) {
      archive.addFile(ArchiveFile.bytes('model/tokens.txt', [4, 5]));
    }
    return BZip2Encoder().encodeBytes(TarEncoder().encodeBytes(archive));
  }

  Future<void> install(Directory destination, List<double> progress) {
    return installSttModelArchive(
      dio: Dio(),
      url: 'http://127.0.0.1:${server.port}/model.tar.bz2',
      destination: destination,
      files: const ['encoder.onnx', 'tokens.txt'],
      onProgress: progress.add,
    );
  }

  test('extracts selected files off the UI isolate and publishes once', () async {
    response = makeArchive();
    final destination = Directory('${temp.path}/model');
    final progress = <double>[];

    await install(destination, progress);

    expect(await File('${destination.path}/encoder.onnx').readAsBytes(), [1, 2, 3]);
    expect(await File('${destination.path}/tokens.txt').readAsBytes(), [4, 5]);
    expect(File('${destination.path}/ignored.txt').existsSync(), isFalse);
    expect(progress.last, 1);
    expect(temp.listSync().map((entry) => entry.path), [destination.path]);
  });

  test('corrupt archive leaves an existing installation intact', () async {
    response = [0, 1, 2, 3];
    final destination = Directory('${temp.path}/model')..createSync();
    File('${destination.path}/tokens.txt').writeAsBytesSync([7]);
    final progress = <double>[];

    await expectLater(install(destination, progress), throwsA(isA<Exception>()));

    expect(File('${destination.path}/tokens.txt').readAsBytesSync(), [7]);
    expect(progress, isNot(contains(1)));
    expect(temp.listSync().map((entry) => entry.path), [destination.path]);
  });

  test('missing required entry cannot publish a partial model', () async {
    response = makeArchive(omitTokens: true);
    final destination = Directory('${temp.path}/model');
    final progress = <double>[];

    await expectLater(install(destination, progress), throwsA(isA<FormatException>()));

    expect(destination.existsSync(), isFalse);
    expect(progress, isNot(contains(1)));
    expect(temp.listSync(), isEmpty);
  });
}
