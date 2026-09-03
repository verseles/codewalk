import 'dart:io';

import 'package:codewalk/presentation/services/message_image_export_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

  late Directory shareDirectory;
  late List<MethodCall> methodCalls;

  setUp(() {
    shareDirectory = Directory.systemTemp.createTempSync(
      'codewalk_message_share_test_',
    );
    methodCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (call) async {
          methodCalls.add(call);
          return 'dev.fluttercommunity.plus/share/unavailable';
        });
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, null);
    if (shareDirectory.existsSync()) {
      shareDirectory.deleteSync(recursive: true);
    }
  });

  test('Windows shares only the PNG file payload', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    final result = await MessageImageExportService.sharePngBytesForTesting(
      pngBytes: Uint8List.fromList(<int>[0, 1, 2, 3]),
      subject: 'Mensagem do CodeWalk',
      shareDirectory: shareDirectory,
      now: DateTime.utc(2026, 6, 22, 12),
    );

    expect(result, MessageImageExportResult.shared);
    expect(methodCalls, hasLength(1));
    expect(methodCalls.single.method, 'share');

    final arguments = methodCalls.single.arguments as Map<dynamic, dynamic>;
    expect(arguments.containsKey('subject'), isFalse);
    expect(arguments.containsKey('text'), isFalse);
    expect(arguments['mimeTypes'], <String>['image/png']);

    final paths = arguments['paths'] as List<dynamic>;
    expect(paths, hasLength(1));
    final sharedFile = File(paths.single as String);
    expect(sharedFile.existsSync(), isTrue);
    expect(sharedFile.readAsBytesSync(), <int>[0, 1, 2, 3]);
    expect(
      sharedFile.uri.pathSegments.last,
      startsWith('codewalk_message_share_'),
    );
    expect(sharedFile.uri.pathSegments.last, endsWith('.png'));
  });

  test('non-Windows shares keep the localized subject', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    final result = await MessageImageExportService.sharePngBytesForTesting(
      pngBytes: Uint8List.fromList(<int>[4, 5, 6]),
      subject: 'CodeWalk message',
      shareDirectory: shareDirectory,
      now: DateTime.utc(2026, 6, 22, 12, 1),
    );

    expect(result, MessageImageExportResult.shared);
    expect(methodCalls, hasLength(1));

    final arguments = methodCalls.single.arguments as Map<dynamic, dynamic>;
    expect(arguments['subject'], 'CodeWalk message');
    expect(arguments.containsKey('text'), isFalse);
    expect(arguments['mimeTypes'], <String>['image/png']);

    final paths = arguments['paths'] as List<dynamic>;
    expect(paths, hasLength(1));
    final sharedFile = File(paths.single as String);
    expect(sharedFile.existsSync(), isTrue);
    expect(sharedFile.readAsBytesSync(), <int>[4, 5, 6]);
  });

  test('old CodeWalk share images are pruned lazily', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    final oldFile = File(
      '${shareDirectory.path}${Platform.pathSeparator}'
      'codewalk_message_share_old.png',
    );
    await oldFile.writeAsBytes(<int>[1]);
    await oldFile.setLastModified(DateTime.utc(2026, 6, 20));

    final recentFile = File(
      '${shareDirectory.path}${Platform.pathSeparator}'
      'codewalk_message_share_recent.png',
    );
    await recentFile.writeAsBytes(<int>[2]);
    await recentFile.setLastModified(DateTime.utc(2026, 6, 22, 11));

    await MessageImageExportService.sharePngBytesForTesting(
      pngBytes: Uint8List.fromList(<int>[7, 8, 9]),
      subject: 'Mensagem do CodeWalk',
      shareDirectory: shareDirectory,
      now: DateTime.utc(2026, 6, 22, 12),
    );

    expect(oldFile.existsSync(), isFalse);
    expect(recentFile.existsSync(), isTrue);
  });
}
