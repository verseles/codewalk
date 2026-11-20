import 'package:codewalk_core/codewalk_core.dart';
import '../../shared/sessions/session_attachments.dart';
import '../../shared/sessions/session_history_source.dart';

SessionHistorySource createSessionHistorySource(
  EndpointProfile profile,
  EndpointCredential credential,
  SessionRef session, {
  AttachmentBlobRepository? blobs,
}) => throw const SessionHistoryException(
  SessionHistoryFailure.unsupportedPlatform,
);
