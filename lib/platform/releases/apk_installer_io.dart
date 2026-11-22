import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../shared/releases/apk_update.dart';

const String kApkInstallChannelName = 'com.verseles.codewalk/v2-apk-install';

/// Installs a verified APK on Android using a native `PackageInstaller`
/// session over [kApkInstallChannelName].
final class MethodChannelApkInstaller implements ApkInstaller {
  MethodChannelApkInstaller({
    MethodChannel channel = const MethodChannel(kApkInstallChannelName),
    bool? isAndroid,
  }) : _channel = channel,
       _isAndroid = isAndroid ?? Platform.isAndroid {
    if (_isAndroid) {
      _channel.setMethodCallHandler(_handleCall);
    }
  }

  final MethodChannel _channel;
  final bool _isAndroid;
  final StreamController<ApkInstallSignal> _signals =
      StreamController<ApkInstallSignal>.broadcast();

  @override
  Stream<ApkInstallSignal> get signals => _signals.stream;

  Future<Object?> _handleCall(MethodCall call) async {
    if (call.method != 'status') return null;
    final args = call.arguments;
    final kind = args is Map ? args['kind'] : null;
    final signal = switch (kind) {
      'confirmation' => ApkInstallSignal.confirmation,
      'aborted' => ApkInstallSignal.aborted,
      'storage' => ApkInstallSignal.storage,
      'failed' => ApkInstallSignal.failed,
      'succeeded' => ApkInstallSignal.succeeded,
      _ => null,
    };
    if (signal != null && !_signals.isClosed) {
      _signals.add(signal);
    }
    return null;
  }

  @override
  Future<ApkInstallOutcome> open(
    String path, {
    int? versionCode,
    String? tag,
    String? notificationTitle,
    String? notificationBody,
    String? notificationChannel,
  }) async {
    if (!_isAndroid) return ApkInstallOutcome.noInstaller;
    try {
      final raw = await _channel.invokeMethod<String>('open', <String, Object?>{
        'path': path,
        'versionCode': versionCode,
        'tag': tag,
        'notificationTitle': notificationTitle,
        'notificationBody': notificationBody,
        'notificationChannel': notificationChannel,
      });
      return switch (raw) {
        'committed' => ApkInstallOutcome.committed,
        'opened' => ApkInstallOutcome.opened,
        'noInstaller' => ApkInstallOutcome.noInstaller,
        'denied' => ApkInstallOutcome.denied,
        'fileMissing' => ApkInstallOutcome.fileMissing,
        'storage' => ApkInstallOutcome.storage,
        _ => ApkInstallOutcome.failed,
      };
    } on MissingPluginException {
      return ApkInstallOutcome.noInstaller;
    } on PlatformException catch (error) {
      return switch (error.code) {
        'DENIED' => ApkInstallOutcome.denied,
        'FILE_MISSING' => ApkInstallOutcome.fileMissing,
        'STORAGE' => ApkInstallOutcome.storage,
        _ => ApkInstallOutcome.failed,
      };
    } on Object {
      return ApkInstallOutcome.failed;
    }
  }

  @override
  Future<void> clearPendingMarker() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('clearPendingMarker');
    } on Object {
      // Best effort: missing plugin in tests or non-Android is non-fatal.
    }
  }
}

ApkInstaller createApkInstaller() => MethodChannelApkInstaller();
