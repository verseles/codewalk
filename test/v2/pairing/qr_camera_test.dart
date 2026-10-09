import 'dart:async';

import 'package:codewalk/platform/pairing/qr_camera_page.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class _Camera extends MobileScannerPlatform {
  _Camera(this.captures);
  final StreamController<BarcodeCapture?> captures;
  int starts = 0;
  int stops = 0;
  int disposals = 0;
  @override
  Stream<BarcodeCapture?> get barcodesStream => captures.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const SizedBox.expand();
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    starts++;
    expect(options.formats, [BarcodeFormat.qrCode]);
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      size: Size(640, 480),
    );
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }

  @override
  Future<void> updateScanWindow(Rect? window) async {}
}

void main() {
  testWidgets('camera capture completes once and releases native ownership', (
    tester,
  ) async {
    final previous = MobileScannerPlatform.instance;
    final captures = StreamController<BarcodeCapture?>.broadcast();
    final camera = _Camera(captures);
    MobileScannerPlatform.instance = camera;
    addTearDown(() async {
      MobileScannerPlatform.instance = previous;
      MobileScannerController.resetPlatformSessionOwner();
      await captures.close();
    });
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        localizationsDelegates: V2Localizations.localizationsDelegates,
        supportedLocales: V2Localizations.supportedLocales,
        home: const Scaffold(),
      ),
    );
    final task = CameraQrTask(navigator, supported: true);
    await tester.pumpAndSettle();
    const capture = BarcodeCapture(
      barcodes: [
        Barcode(format: BarcodeFormat.qrCode, rawValue: 'fake-test-link'),
      ],
    );
    camera.captures.add(capture);
    camera.captures.add(capture);
    await tester.pumpAndSettle();
    expect(await task.result, 'fake-test-link');
    expect(camera.starts, 1);
    expect(camera.stops, greaterThanOrEqualTo(1));
    expect(camera.disposals, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
