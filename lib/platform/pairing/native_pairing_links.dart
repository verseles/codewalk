import 'dart:async';

import 'package:flutter/services.dart';

import 'native_link_support_stub.dart'
    if (dart.library.io) 'native_link_support_io.dart';

/// Raw URIs remain private; only the caller's sanitized route is navigated.
final class NativePairingLinks {
  NativePairingLinks(this.onLink, {MethodChannel? channel, bool? enabled})
    : channel =
          channel ?? const MethodChannel('com.verseles.codewalk/v2-pairing'),
      enabled = enabled ?? nativePairingLinksAvailable;
  final void Function(Uri) onLink;
  final MethodChannel channel;
  final bool enabled;
  bool _disposed = false;
  bool _draining = false;
  bool _needsDrain = false;
  final _accepted = <int>{};
  Future<void> start() async {
    if (!enabled) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'pending') {
        if (_draining) {
          _needsDrain = true;
        } else {
          await _drain();
        }
      }
      return null;
    });
    for (var attempt = 0; attempt < 10 && !_disposed; attempt++) {
      if (await _drain()) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<bool> _drain() async {
    if (_disposed || _draining) return true;
    _draining = true;
    try {
      for (var i = 0; i < 4 && !_disposed; i++) {
        final value = await channel.invokeMethod<Object?>('getPending');
        if (_disposed || value == null) return true;
        if (value is! Map || value['id'] is! int || value['uri'] is! String) {
          return true;
        }
        final id = value['id'] as int;
        if (_accepted.add(id)) {
          if (_accepted.length > 16) _accepted.remove(_accepted.first);
          final raw = value['uri'] as String;
          final uri = raw.length <= 4096 ? Uri.tryParse(raw) : null;
          if (uri?.scheme == 'codewalk' && uri?.host == 'pair') onLink(uri!);
        }
        await channel.invokeMethod<void>('ack', id);
      }
      return true;
    } on MissingPluginException {
      return false;
    } on Object {
      /* No raw URI or plugin exception reaches diagnostics. */
      return true;
    } finally {
      _draining = false;
      if (_needsDrain && !_disposed) {
        _needsDrain = false;
        unawaited(
          Future<void>.microtask(() async {
            await _drain();
          }),
        );
      }
    }
  }

  void dispose() {
    _disposed = true;
    if (enabled) channel.setMethodCallHandler(null);
    _accepted.clear();
  }
}
