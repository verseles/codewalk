import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../shared/l10n/l10n_context.dart';

final class CameraQrTask implements QrInputTask {
  CameraQrTask(this.navigator, {required bool supported}) {
    final state = navigator.currentState;
    if (!supported || state == null) {
      result = Future.error(const QrInputException(QrInputFailure.unavailable));
    } else {
      _route = MaterialPageRoute<String>(
        builder: (_) => _CameraPage(onDisposed: _disposed.complete),
      );
      result = state.push(_route!).then((value) async {
        await _disposed.future;
        return value;
      });
    }
  }
  final GlobalKey<NavigatorState> navigator;
  MaterialPageRoute<String>? _route;
  final _disposed = Completer<void>();
  @override
  late final Future<String?> result;
  @override
  void cancel() {
    final route = _route;
    if (route != null && route.isActive) {
      navigator.currentState?.removeRoute(route);
    }
  }
}

class _CameraPage extends StatefulWidget {
  const _CameraPage({required this.onDisposed});
  final VoidCallback onDisposed;
  @override
  State<_CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<_CameraPage> with WidgetsBindingObserver {
  final _controller = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _finished = false;
  Future<void> _operations = Future.value();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _schedule(start: true));
  }

  void _schedule({required bool start}) {
    _operations = _operations
        .then((_) async {
          if (start) {
            if (mounted && !_finished) await _controller.start();
          } else {
            await _controller.stop();
          }
        })
        .catchError((Object _) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_finished || !_controller.value.hasCameraPermission) return;
    _schedule(start: state == AppLifecycleState.resumed);
  }

  void _capture(BarcodeCapture capture) {
    if (_finished || !mounted) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (barcode.format == BarcodeFormat.qrCode &&
          value != null &&
          value.isNotEmpty &&
          value.length <= 4096) {
        _finished = true;
        _schedule(start: false);
        _operations.then((_) {
          if (mounted) Navigator.of(context).pop(value);
        });
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.v2L10n.pairingScanQr)),
    body: MobileScanner(
      controller: _controller,
      useAppLifecycleState: false,
      onDetect: _capture,
      errorBuilder: (_, _) =>
          Center(child: Text(context.v2L10n.pairingCaptureError)),
    ),
  );
  @override
  void dispose() {
    _finished = true;
    WidgetsBinding.instance.removeObserver(this);
    _operations
        .then((_) => _controller.dispose())
        .catchError((Object _) {})
        .whenComplete(widget.onDisposed);
    super.dispose();
  }
}
