import 'package:codewalk_core/codewalk_core.dart';
import '../../shared/sessions/session_actions.dart';
import 'hidden_session_store.dart';
import 'session_action_source_stub.dart'
    if (dart.library.io) 'session_action_source_io.dart'
    as platform;

SessionActionSource createSessionActionSource(
  EndpointProfile profile,
  EndpointCredential credential,
  EndpointProber prober, {
  HiddenSessionStore? hidden,
}) => platform.createSessionActionSource(
  profile,
  credential,
  prober,
  hidden: hidden,
);
