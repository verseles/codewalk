import 'package:codewalk_core/codewalk_core.dart';
import '../../shared/sessions/session_actions.dart';
import 'hidden_session_store.dart';

SessionActionSource createSessionActionSource(
  EndpointProfile profile,
  EndpointCredential credential,
  EndpointProber prober, {
  HiddenSessionStore? hidden,
}) => _UnsupportedSource(profile, hidden);

/// The platform has no transport to the endpoint, so no native action is
/// available. The local hide still is.
final class _UnsupportedSource implements SessionActionSource {
  _UnsupportedSource(EndpointProfile profile, this._hidden)
    : harness = HarnessRef(HostId(profile.id), HarnessInstanceId(profile.id));

  @override
  final HarnessRef harness;
  final HiddenSessionStore? _hidden;

  @override
  Future<SessionActionSupport> support() async =>
      const SessionActionSupport(SessionActionReason.unsupportedPlatform);

  @override
  SessionViewState viewState(SessionSummary row) => SessionViewState.unknown;

  @override
  Future<int?> childCount(SessionSummary row) async => null;

  @override
  Future<SessionCreateResult> create({
    required String directory,
    String? title,
  }) async => const SessionCreateResult(SessionActionOutcome.unavailable);

  @override
  Future<SessionActionOutcome> rename(SessionSummary row, String title) async =>
      SessionActionOutcome.unavailable;

  @override
  Future<SessionActionOutcome> delete(SessionSummary row) async =>
      SessionActionOutcome.unavailable;

  @override
  Future<SessionActionOutcome> fork(SessionSummary row) async =>
      SessionActionOutcome.unavailable;

  @override
  Future<SessionActionOutcome> markViewed(SessionSummary row) async =>
      SessionActionOutcome.unavailable;

  @override
  bool get hideAvailable => _hidden?.loaded == true && !(_hidden?.unreadable ?? true);

  @override
  bool get hideUnreadable => _hidden?.unreadable ?? false;

  @override
  bool isHidden(SessionSummary row) =>
      _hidden?.isHidden(row.info.ref.storageKey) ?? false;

  @override
  Future<bool> setHidden(
    SessionSummary row, {
    required bool hidden,
  }) async => _hidden?.setHidden(row.info.ref.storageKey, hidden: hidden) ?? false;

  @override
  void close() {}
}
