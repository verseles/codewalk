import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../platform/storage/metadata_store.dart';
import '../../shared/releases/app_version.dart';
import '../../shared/releases/release_catalog.dart';
import '../../shared/releases/release_source.dart';
import '../../shared/releases/update_selector.dart';

enum UpdateCheckStatus { idle, checking, upToDate, available, failed }

/// Checks CodeWalk releases without downloading or installing them.
///
/// The channel defaults to stable; beta is an explicit, persisted opt-in.
/// A null [target] means this platform has no CodeWalk 2 update route.
final class UpdateCheckController extends ChangeNotifier {
  UpdateCheckController({
    required ReleaseSource source,
    required V2MetadataStore store,
    required Future<String> Function() installedVersion,
    required this.target,
    DateTime Function()? clock,
    Future<String> Function()? installedBuild,
  }) : _source = source,
       _store = store,
       _installedVersion = installedVersion,
       _installedBuildLoader = installedBuild,
       _clock = clock ?? DateTime.now;

  static const channelKey = 'cw2.updates.channel';
  static const dismissedKey = 'cw2.updates.dismissedTag';
  static const dismissedNewsKey = 'cw2.updates.dismissedNewsTag';
  static const catalogKey = 'cw2.updates.catalog';
  static const retryAtKey = 'cw2.updates.retryAt';
  static const maxCatalogBytes = 512 * 1024;
  final ReleaseSource _source;
  final V2MetadataStore _store;
  final Future<String> Function() _installedVersion;
  final Future<String> Function()? _installedBuildLoader;
  String? _installedBuild;
  final DateTime Function() _clock;
  DateTime? _lastSuccess;
  DateTime? _retryAt;
  ReleaseSourceFailure? _failure;
  final UpdateTarget? target;
  UpdateChannel _channel = UpdateChannel.stable;
  UpdateCheckStatus _status = UpdateCheckStatus.idle;
  UpdateCandidate? _candidate;
  String? _installed;
  String? _dismissedTag;
  String? _dismissedNewsTag;
  final Set<String> _presentedNotices = {};
  String? _automaticUpdate;
  String? _automaticNews;
  List<ReleaseCatalogEntry>? _catalog;
  ReleaseSourceTask? _task;
  Future<void>? _restoring;
  Future<void>? _checking;
  bool _manualCheck = false;
  int _generation = 0;
  bool _disposed = false;

  UpdateChannel get channel => _channel;
  UpdateCheckStatus get status => _status;
  UpdateCandidate? get candidate => _candidate;
  String? get installedVersion => _installed;
  String? get installedBuild => _installedBuild;
  bool get supported => target != null;
  ReleaseSourceFailure? get failure => _failure;
  DateTime? get lastSuccessfulCheck => _lastSuccess;
  UpdateCandidate? get automaticUpdateNotice =>
      visibleCandidate?.tag == _automaticUpdate ? visibleCandidate : null;
  ReleaseCatalogEntry? get automaticNewsNotice =>
      visibleNews?.tag == _automaticNews ? visibleNews : null;
  void markNoticePresented(String tag, {required bool news}) {
    _presentedNotices.add('${news ? 'news' : 'update'}:$tag');
    if (news) {
      _automaticNews = null;
    } else {
      _automaticUpdate = null;
    }
  }

  List<ReleaseCatalogEntry>? get catalog => _catalog;
  UpdateCandidate? get visibleCandidate =>
      _candidate?.tag == _dismissedTag ? null : _candidate;
  ReleaseCatalogEntry? get visibleNews {
    final installed = AppVersion.tryParse(_installed ?? '');
    if (installed == null) return null;
    for (final entry in _catalog ?? const <ReleaseCatalogEntry>[]) {
      if (entry.version.compareTo(installed) > 0 ||
          (_channel == UpdateChannel.stable &&
              entry.version.isPrerelease &&
              entry.version != installed)) {
        continue;
      }
      return entry.announcement == null || entry.tag == _dismissedNewsTag
          ? null
          : entry;
    }
    return null;
  }

  /// Reads the saved channel once; later calls reuse the same read.
  Future<void> restore() => _restoring ??= _restore();

  Future<void> _restore() async {
    try {
      await _store.ensureSchema();
      final saved = await _store.read(channelKey);
      final dismissed = await _store.read(dismissedKey);
      final news = await _store.read(dismissedNewsKey);
      if (!_disposed && dismissed is String) _dismissedTag = dismissed;
      if (!_disposed && news is String) _dismissedNewsTag = news;
      if (!_disposed &&
          saved == UpdateChannel.beta.name &&
          _channel != UpdateChannel.beta) {
        _channel = UpdateChannel.beta;
        notifyListeners();
      }
    } on Object {
      // An unreadable preference keeps the stable default.
    }
    try {
      final saved = await _store.read(retryAtKey);
      if (saved is int) {
        final deadline = DateTime.fromMillisecondsSinceEpoch(
          saved,
          isUtc: true,
        );
        final now = _clock();
        if (deadline.isAfter(now) &&
            deadline.difference(now) <= ReleaseSource.maxRetryDelay) {
          _retryAt = deadline;
        } else {
          await _store.remove(retryAtKey);
        }
      }
    } on Object {
      // Keep a known in-memory deadline if persistence is unavailable.
    }
    try {
      final saved = await _store.read(catalogKey);
      if (saved is String && utf8.encode(saved).length <= maxCatalogBytes) {
        final envelope = jsonDecode(saved);
        if (envelope is Map && envelope['schema'] == 1) {
          final entries = parseReleaseCatalog(envelope['releases']);
          if (!_disposed) {
            _catalog = entries;
            notifyListeners();
          }
        }
      }
    } on Object {
      // Invalid history is ignored without changing the update policy.
    }
    try {
      final installed = await _installedVersion();
      if (!_disposed) {
        _installed = installed;
        notifyListeners();
      }
    } on Object {
      // Version metadata is retried by the next explicit check.
    }
    unawaited(_loadInstalledBuild());
  }

  Future<void> _loadInstalledBuild() async {
    try {
      final build = await _installedBuildLoader?.call();
      if (!_disposed && build != null) {
        _installedBuild = build;
        notifyListeners();
      }
    } on Object {
      // Optional display metadata must not block update discovery.
    }
  }

  Future<bool> dismissCandidate() async {
    final tag = _candidate?.tag;
    if (_disposed || tag == null) return false;
    try {
      await _store.write(dismissedKey, tag);
    } on Object {
      return false;
    }
    if (_disposed) return false;
    _dismissedTag = tag;
    notifyListeners();
    return true;
  }

  Future<bool> dismissNews() async {
    final tag = visibleNews?.tag;
    if (_disposed || tag == null) return false;
    try {
      await _store.write(dismissedNewsKey, tag);
    } on Object {
      return false;
    }
    if (_disposed) return false;
    _dismissedNewsTag = tag;
    notifyListeners();
    return true;
  }

  Future<void> setChannel(UpdateChannel value) async {
    await restore();
    if (_disposed || value == _channel) return;
    _channel = value;
    // A result for the other channel no longer applies.
    _cancel();
    _status = UpdateCheckStatus.idle;
    _candidate = null;
    _automaticUpdate = null;
    _automaticNews = null;
    _lastSuccess = null;
    notifyListeners();
    try {
      await _store.write(channelKey, value.name);
    } on Object {
      // The choice still applies to this session.
    }
  }

  Future<void> check({bool silent = false, bool force = true}) {
    final target = this.target;
    if (_disposed || target == null) return Future.value();
    final last = _lastSuccess;
    final now = _clock();
    if (_quotaBlocks(manual: !silent)) return Future.value();
    if (!force &&
        last != null &&
        !now.isBefore(last) &&
        now.difference(last) < const Duration(hours: 1)) {
      return Future.value();
    }
    final active = _checking;
    if (active != null) {
      if (!silent && !_manualCheck) {
        _manualCheck = true;
        _status = UpdateCheckStatus.checking;
        notifyListeners();
      }
      return active;
    }
    _manualCheck = !silent;
    final generation = ++_generation;
    if (!silent) {
      _status = UpdateCheckStatus.checking;
      notifyListeners();
    }
    final future = _runCheck(target, generation, automatic: silent && !force);
    _checking = future;
    return future.whenComplete(() {
      if (identical(_checking, future)) _checking = null;
    });
  }

  Future<void> _runCheck(
    UpdateTarget target,
    int generation, {
    required bool automatic,
  }) async {
    await restore();
    if (!_current(generation)) return;
    if (_quotaBlocks(manual: _manualCheck)) return;
    final channel = _channel;
    var outcome = UpdateCheckStatus.failed;
    UpdateCandidate? found;
    List<ReleaseCatalogEntry>? catalog;
    try {
      final installed = await _installedVersion();
      final current = AppVersion.tryParse(installed);
      if (!_current(generation)) return;
      _installed = installed;
      if (current != null) {
        final task = _task = _source.start();
        final result = await task.result;
        if (!_current(generation)) return;
        _failure = result.failure;
        _retryAt = result.retryAt;
        await _saveQuota();
        if (!_current(generation)) return;
        _task = null;
        final body = result.body;
        if (body != null) {
          final decoded = jsonDecode(body);
          found = selectUpdate(
            releases: decoded,
            channel: channel,
            current: current,
            target: target,
          );
          outcome = found == null
              ? UpdateCheckStatus.upToDate
              : UpdateCheckStatus.available;
          try {
            catalog = parseReleaseCatalog(decoded);
          } on FormatException {
            // A bad history must not turn a successful update check into an
            // error or replace a previously complete catalog.
          }
        }
      }
    } on Object {
      outcome = UpdateCheckStatus.failed;
    }
    if (!_current(generation)) return;
    if (outcome != UpdateCheckStatus.failed) {
      _failure = null;
      _lastSuccess = _clock();
      _candidate = found;
      if (catalog != null) {
        _catalog = catalog;
        final saved = jsonEncode({
          'schema': 1,
          'releases': encodeReleaseCatalog(catalog),
        });
        if (utf8.encode(saved).length <= maxCatalogBytes) {
          try {
            await _store.write(catalogKey, saved);
          } on Object {
            // Keep the complete in-memory catalog and the prior saved copy.
          }
        }
        if (!_current(generation)) return;
      }
      if (_manualCheck || found != null) {
        _status = outcome;
      } else if (_status == UpdateCheckStatus.failed ||
          _status == UpdateCheckStatus.available) {
        _status = UpdateCheckStatus.idle;
      }
      if (automatic && !_manualCheck) {
        final update = visibleCandidate;
        final news = visibleNews;
        if (update != null &&
            !_presentedNotices.contains('update:${update.tag}')) {
          _automaticUpdate = update.tag;
        }
        if (news != null && !_presentedNotices.contains('news:${news.tag}')) {
          _automaticNews = news.tag;
        }
      }
      notifyListeners();
    } else if (_manualCheck) {
      _status = outcome;
      notifyListeners();
    }
  }

  bool _quotaBlocks({required bool manual}) {
    final deadline = _retryAt;
    if (deadline == null || !_clock().isBefore(deadline)) return false;
    if (manual) {
      _status = UpdateCheckStatus.failed;
      _failure = ReleaseSourceFailure.rateLimited;
      notifyListeners();
    }
    return true;
  }

  Future<void> _saveQuota() async {
    try {
      final deadline = _retryAt;
      if (deadline == null) {
        await _store.remove(retryAtKey);
      } else {
        await _store.write(retryAtKey, deadline.millisecondsSinceEpoch);
      }
    } on Object {
      // The active process still respects the server deadline.
    }
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  void _cancel() {
    _generation++;
    _checking = null;
    _task?.cancel();
    _task = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel();
    _source.close();
    super.dispose();
  }
}
