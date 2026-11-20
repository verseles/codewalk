import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net_io.dart';
import 'package:harness_opencode/harness_opencode.dart';
import '../../shared/sessions/session_attachments.dart';
import '../../shared/sessions/session_history_source.dart';
import '../../shared/sessions/session_live_source.dart';
import '../storage/attachment_blob_store.dart';
import 'opencode_attachment_lane.dart';

SessionHistorySource createSessionHistorySource(
  EndpointProfile profile,
  EndpointCredential credential,
  SessionRef session, {
  AttachmentBlobRepository? blobs,
}) => _NativeHistory(profile, credential, session, blobs: blobs);

final class _NativeHistory
    implements SessionHistorySource, SessionAttachmentSource {
  _NativeHistory(
    EndpointProfile profile,
    EndpointCredential credential,
    this.session, {
    AttachmentBlobRepository? blobs,
  }) {
    if (session.harnessRef !=
        HarnessRef(HostId(profile.id), HarnessInstanceId(profile.id))) {
      throw const SessionHistoryException(
        SessionHistoryFailure.incompatibleResponse,
      );
    }
    _transport = IoEndpointHttpTransport(
      endpoint: profile.endpoint,
      headers: basicEndpointHeaders(
        endpoint: profile.endpoint,
        username: 'opencode',
        secret: () => credential.secret,
      ),
    );
    _attachments = OpenCodeAttachmentLane(
      transport: _transport,
      harness: session.harnessRef,
      connectedVersion: '2.0.22',
      blobs: blobs ?? MemoryAttachmentBlobStore(),
      temporaryPath: null,
      view: (ref) =>
          SessionLiveView(session: ref, phase: SessionLivePhase.closed),
      modelInputModalities: (_) => const {},
      currentBinding: () => !_closed,
    );
    _reader = OpenCodeSessionReader(
      _transport,
      harness: session.harnessRef,
      maxHistoryItems: 500,
      onInlineMedia: _attachments.cacheInlineMedia,
    );
  }
  @override
  final SessionRef session;
  late final IoEndpointHttpTransport _transport;
  late final OpenCodeAttachmentLane _attachments;
  late final OpenCodeSessionReader _reader;
  final _tasks = <_HistoryTask>{};
  String? _version;
  bool _closed = false;

  @override
  AttachmentFacet? get attachments => _closed ? null : _attachments;

  @override
  bool get supportsStageUpload => false;

  @override
  bool get supportsMediaRead => !_closed;

  @override
  SessionHistoryTask read({String? cursor}) {
    if (_closed) {
      throw const SessionHistoryException(SessionHistoryFailure.cancelled);
    }
    final task = _HistoryTask();
    _tasks.add(task);
    task.result = _read(cursor, task).whenComplete(() => _tasks.remove(task));
    return task;
  }

  Future<SessionHistoryPageResult> _read(
    String? cursor,
    _HistoryTask task,
  ) async {
    final token = task.token;
    try {
      final assessment = await OpenCodeEndpointProbe(
        _transport,
      ).detect(cancellation: token);
      if (_closed || task.cancelled) {
        throw const SessionHistoryException(SessionHistoryFailure.cancelled);
      }
      // The probe deadline cancels its token, not the caller's task. Keep a
      // real deadline distinct from an explicit Back/disposal cancellation.
      if (token.isCancelled) {
        throw SessionHistoryException(
          assessment.status == EndpointStatus.unreachable
              ? SessionHistoryFailure.timeout
              : SessionHistoryFailure.cancelled,
        );
      }
      if (assessment.status == EndpointStatus.authenticationRequired) {
        throw const SessionHistoryException(
          SessionHistoryFailure.authenticationRequired,
        );
      }
      final version = assessment.version;
      if (!assessment.canUse || version == null) {
        throw const SessionHistoryException(SessionHistoryFailure.unavailable);
      }
      if (_version != null && version != _version) {
        throw const SessionHistoryException(
          SessionHistoryFailure.sourceChanged,
        );
      }
      _version = version;
      final page = await _reader.readHistory(
        session,
        sourceVersion: version,
        limit: 50,
        cursor: cursor,
        cancellation: token,
      );
      return SessionHistoryPageResult(session, version, page);
    } on SessionHistoryException {
      rethrow;
    } on OpenCodeSessionReadException catch (e) {
      throw SessionHistoryException(switch (e.failure) {
        OpenCodeSessionReadFailure.authenticationRequired =>
          SessionHistoryFailure.authenticationRequired,
        OpenCodeSessionReadFailure.rateLimited =>
          SessionHistoryFailure.rateLimited,
        OpenCodeSessionReadFailure.timeout => SessionHistoryFailure.timeout,
        OpenCodeSessionReadFailure.invalidCursor =>
          SessionHistoryFailure.invalidCursor,
        OpenCodeSessionReadFailure.notFound => SessionHistoryFailure.notFound,
        OpenCodeSessionReadFailure.cancelled ||
        OpenCodeSessionReadFailure.closed => SessionHistoryFailure.cancelled,
        OpenCodeSessionReadFailure.connection =>
          SessionHistoryFailure.connection,
        OpenCodeSessionReadFailure.unavailable =>
          SessionHistoryFailure.unavailable,
        _ => SessionHistoryFailure.incompatibleResponse,
      });
    } on Object {
      throw const SessionHistoryException(SessionHistoryFailure.connection);
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    for (final task in _tasks.toList()) {
      task.cancel();
    }
    _attachments.dispose();
    _reader.dispose();
    _transport.close();
  }
}

final class _HistoryTask implements SessionHistoryTask {
  final token = RequestCancellation();
  bool cancelled = false;
  @override
  late final Future<SessionHistoryPageResult> result;
  @override
  void cancel() {
    cancelled = true;
    token.cancel();
  }
}
