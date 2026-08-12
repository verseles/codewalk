import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/l10n_bridge.dart';
import '../../../domain/entities/experience_settings.dart';
import 'session_attention_host_contract.dart';
import 'session_attention_host_protocol.dart';

SessionAttentionHostService createSessionAttentionHostService() {
  return _IoSessionAttentionHostService();
}

class _IoSessionAttentionHostService
    implements
        SessionAttentionHostService,
        SessionAttentionSnapshotHostService {
  static const _androidChannel = MethodChannel('codewalk/session_overlay_host');

  bool _iosHostActive = false;
  Timer? _androidHeartbeatTimer;

  @override
  Future<SessionAttentionHostCapability> capability() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final stopState =
          await _invokeAndroid<Map<Object?, Object?>>(
            'consumeOverlayStopState',
          ) ??
          const <Object?, Object?>{};
      final permissionGranted =
          await _invokeAndroid<bool>('canDrawOverlays') ?? false;
      final running =
          await _invokeAndroid<bool>('isOverlayServiceRunning') ?? false;
      return SessionAttentionHostCapability(
        kind: SessionAttentionHostKind.androidExternal,
        supported: true,
        permissionGranted: permissionGranted,
        running: running,
        topmostSupported: true,
        stoppedByUser: stopState['stoppedByUser'] == true,
        permissionRevoked: stopState['permissionRevoked'] == true,
        explanation: permissionGranted
            ? null
            : L10nBridge.current?.sessionAttentionOverlayPermissionRequired ??
                  'Display-over-other-apps permission is required.',
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return SessionAttentionHostCapability(
        kind: SessionAttentionHostKind.iosInApp,
        supported: true,
        permissionGranted: true,
        running: _iosHostActive,
        topmostSupported: false,
        explanation:
            L10nBridge.current?.sessionAttentionIosInAppOnly ??
            'Session attention is available only inside CodeWalk.',
      );
    }
    return SessionAttentionHostCapability(
      kind: SessionAttentionHostKind.unsupported,
      supported: false,
      permissionGranted: false,
      running: false,
      topmostSupported: false,
      explanation:
          L10nBridge.current?.settingsSessionAttentionUnavailable ??
          'Session attention is unavailable on this platform.',
    );
  }

  @override
  Future<SessionAttentionHostActivationResult> activate(
    SessionAttentionPresentation presentation,
  ) async {
    if (presentation == SessionAttentionPresentation.off) {
      await stop();
      return SessionAttentionHostActivationResult.success(await capability());
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final current = await capability();
      if (!current.permissionGranted) {
        await openSystemSettings();
        return SessionAttentionHostActivationResult.failure(
          current,
          L10nBridge.current?.sessionAttentionOverlayPermissionGrantPrompt ??
              'Grant display-over-other-apps permission, then try again.',
        );
      }
      final started =
          await _invokeAndroid<bool>('startOverlayService') ?? false;
      var next = await capability();
      for (
        var attempt = 0;
        started && !next.running && attempt < 10;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        next = await capability();
      }
      return started && next.running
          ? SessionAttentionHostActivationResult.success(
              _startAndroidHeartbeat(next),
            )
          : SessionAttentionHostActivationResult.failure(
              next,
              L10nBridge.current?.sessionAttentionAndroidStartFailed ??
                  'The Android session attention service could not start.',
            );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _iosHostActive = true;
      return SessionAttentionHostActivationResult.success(await capability());
    }
    final current = await capability();
    return SessionAttentionHostActivationResult.failure(
      current,
      current.explanation,
    );
  }

  @override
  Future<void> openSystemSettings() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _invokeAndroid<void>('requestOverlayPermission');
    }
  }

  @override
  Future<void> stop() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      _androidHeartbeatTimer?.cancel();
      _androidHeartbeatTimer = null;
      await _invokeAndroid<void>('stopOverlayService');
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _iosHostActive = false;
    }
  }

  SessionAttentionHostCapability _startAndroidHeartbeat(
    SessionAttentionHostCapability capability,
  ) {
    _androidHeartbeatTimer?.cancel();
    unawaited(_invokeAndroid<void>('overlayHeartbeat'));
    _androidHeartbeatTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_invokeAndroid<void>('overlayHeartbeat')),
    );
    return capability;
  }

  @override
  Future<void> publishSnapshot(SessionAttentionHostSnapshot snapshot) async {
    SessionAttentionHostSnapshotBus.emit(snapshot);
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _invokeAndroid<void>('updateOverlaySnapshot', snapshot.toJson());
      return;
    }
  }

  Future<T?> _invokeAndroid<T>(String method, [Object? arguments]) {
    return _androidChannel
        .invokeMethod<T>(method, arguments)
        .timeout(const Duration(seconds: 2));
  }
}
