import 'package:codewalk_core/codewalk_core.dart';
import '../../shared/sessions/session_history_source.dart';

SessionHistorySource createSessionHistorySource(
  EndpointProfile profile,
  EndpointCredential credential,
  SessionRef session,
) => throw const SessionHistoryException(
  SessionHistoryFailure.unsupportedPlatform,
);
