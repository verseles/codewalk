import 'package:codewalk_core/codewalk_core.dart';
import '../../shared/sessions/session_actions.dart';

SessionActionSource createSessionActionSource(
  EndpointProfile profile,
  EndpointCredential credential,
  EndpointProber prober,
) => _UnsupportedSource(profile);

/// The platform has no transport to the endpoint, so no native action is
/// available.
final class _UnsupportedSource implements SessionActionSource {
  _UnsupportedSource(EndpointProfile profile)
    : harness = HarnessRef(HostId(profile.id), HarnessInstanceId(profile.id));

  @override
  final HarnessRef harness;

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
    Selection? initialSelection,
  }) async => const SessionCreateResult(SessionActionOutcome.unavailable);

  @override
  Future<SessionActionOutcome> rename(SessionSummary row, String title) async =>
      SessionActionOutcome.unavailable;

  @override
  Future<SessionActionOutcome> delete(SessionSummary row) async =>
      SessionActionOutcome.unavailable;

  @override
  Future<SessionCreateResult> fork(
    SessionSummary row, {
    ItemId? before,
  }) async => const SessionCreateResult(SessionActionOutcome.unavailable);

  @override
  Future<SessionActionOutcome> markViewed(SessionSummary row) async =>
      SessionActionOutcome.unavailable;

  @override
  void close() {}
}
