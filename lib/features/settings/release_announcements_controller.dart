import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../platform/storage/metadata_store.dart';
import '../../shared/releases/app_version.dart';
import '../../shared/releases/installed_release_state.dart';
import '../../shared/releases/release_catalog.dart';
import 'update_check_controller.dart';

final class ReleaseAnnouncementsController extends ChangeNotifier {
  ReleaseAnnouncementsController({
    required V2MetadataStore store,
    required UpdateCheckController checks,
    required Future<String> Function() installedVersion,
    required Future<bool> existingInstallation,
  }) : _store = store,
       _checks = checks,
       _installedVersion = installedVersion,
       _existingInstallation = existingInstallation {
    _checks.addListener(_changed);
  }

  static const stateKey = 'cw2.updates.installedRelease';
  final V2MetadataStore _store;
  final UpdateCheckController _checks;
  final Future<String> Function() _installedVersion;
  final Future<bool> _existingInstallation;
  final Set<String> _presented = {};
  final Set<String> _presentedNewsTags = {};
  InstalledReleaseState? _state;
  Future<void>? _starting;
  Future<void> _writes = Future.value();
  bool _disposed = false;
  bool _failed = false;

  bool get failed => _failed;
  bool get initialized => _state != null || _failed;
  String? get pendingKey => _state?.pending == true ? _state!.key : null;
  bool shouldNotifyNews(String tag) {
    // Dialog acknowledgment and news dismissal are independent. Avoid only a
    // same-process duplicate of an announcement already presented in a dialog.
    return _state != null && !_presentedNewsTags.contains(tag);
  }

  List<ReleaseCatalogEntry>? get pendingAnnouncements {
    final state = _state;
    final catalog = _checks.catalog;
    if (state == null || catalog == null || _presented.contains(state.key)) {
      return null;
    }
    return state.announcements(catalog);
  }

  Future<void> start() => _starting ??= _start();

  Future<void> _start() async {
    try {
      await _checks.restore();
      final installed = AppVersion.tryParse(await _installedVersion());
      if (installed == null || installed.major != BigInt.two) return;
      final raw = await _store.read(stateKey);
      InstalledReleaseState? prior;
      if (raw is String) {
        prior = InstalledReleaseState.tryParse(jsonDecode(raw));
      }
      if (raw != null && prior == null) {
        throw const FormatException('Invalid installed release state');
      }
      final state =
          prior?.observe(installed) ??
          InstalledReleaseState.first(
            installed,
            existing: await _existingInstallation,
          );
      if (_disposed) return;
      await _save(state);
    } on Object {
      _failed = true;
    }
    if (!_disposed) notifyListeners();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void markPresented(String key) {
    if (_state?.key == key) {
      _presentedNewsTags.addAll(
        pendingAnnouncements?.map((entry) => entry.tag) ?? const <String>[],
      );
    }
    _presented.add(key);
  }

  void presentationClosed() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> acknowledge(String key) async {
    await start();
    final result = Completer<bool>();
    _writes = _writes.then((_) async {
      final state = _state;
      final catalog = _checks.catalog;
      if (_disposed ||
          state == null ||
          state.key != key ||
          catalog == null ||
          state.announcements(catalog) == null) {
        result.complete(false);
        return;
      }
      try {
        await _save(state.acknowledge(key));
        result.complete(true);
      } on Object {
        _failed = true;
        result.complete(false);
      }
      if (!_disposed) notifyListeners();
    });
    return result.future;
  }

  Future<void> _save(InstalledReleaseState state) async {
    await _store.write(stateKey, jsonEncode(state.toJson()));
    if (!_disposed) {
      _state = state;
      _failed = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _checks.removeListener(_changed);
    super.dispose();
  }
}
