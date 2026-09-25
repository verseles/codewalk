import 'dart:async';
import 'dart:io';

import 'package:codewalk/presentation/services/sherpa_model_manager_io.dart';
import 'package:codewalk/presentation/services/speech_model_residency_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _PendingDownload extends Fake implements Dio {
  final entered = Completer<void>();
  final resume = Completer<void>();
  int count = 0;

  @override
  Future<Response> download(
    String urlPath,
    dynamic savePath, {
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool deleteOnError = true,
    FileAccessMode fileAccessMode = FileAccessMode.write,
    String lengthHeader = Headers.contentLengthHeader,
    Object? data,
    Options? options,
  }) async {
    if (count++ == 0) {
      entered.complete();
      await resume.future;
    }
    await File(savePath as String).writeAsString('model');
    return Response(requestOptions: RequestOptions(path: urlPath));
  }
}

class _Manager extends SherpaModelManager {
  _Manager(this.path, Dio dio) : super(dio: dio);
  final String path;
  @override
  Future<String> getModelDir(String lang) async => path;
}

void main() {
  test(
    'network transfer does not hold global speech queue; install is atomic',
    () async {
      final root = await Directory.systemTemp.createTemp('sherpa-mutation-');
      final dest = Directory('${root.path}/en');
      final dio = _PendingDownload();
      final manager = _Manager(dest.path, dio);
      final residency = SpeechModelResidencyController.instance;
      addTearDown(() async {
        if (!dio.resume.isCompleted) dio.resume.complete();
        await residency.dispose();
        await root.delete(recursive: true);
      });
      final download = manager.downloadModel('en');
      await dio.entered.future;
      expect(dest.existsSync(), isFalse);
      await residency.mutateModel('${root.path}/another', () async {});
      expect(dio.resume.isCompleted, isFalse);
      dio.resume.complete();
      await download;
      expect(await manager.hasModel('en'), isTrue);
      expect(dio.count, 4);
    },
  );
}
