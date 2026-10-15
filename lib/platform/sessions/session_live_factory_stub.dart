import '../../shared/sessions/session_live_source.dart';
import '../storage/payload_store.dart';

/// No live transport off native IO; the catalog hides the live action.
SessionLiveDirectory? createSessionLiveDirectory({
  DateTime Function()? now,
  PayloadStore? payloads,
}) => null;
