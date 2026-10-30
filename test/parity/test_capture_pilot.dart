import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pilot capture to PNG', (tester) async {
    final key = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(400, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            appBar: AppBar(title: const Text('Parity Test Pilot')),
            body: const Center(child: Text('Hello Parity')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1.0));
    expect(image, isNotNull);
    final byteData = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
    expect(byteData, isNotNull);

    const outPath = '/home/ubuntu/codewalk-cp5-evidence/run_20261030_cp5/pilot.png';
    File(outPath).writeAsBytesSync(byteData!.buffer.asUint8List());
    expect(File(outPath).existsSync(), isTrue);
    expect(File(outPath).lengthSync(), greaterThan(100));
  });
}
