import 'package:codewalk_core/codewalk_core.dart';

import '../../shared/sessions/permission_mode.dart';
import '../../shared/sessions/session_live_source.dart';
import '../../shared/sessions/session_unrestricted.dart';
import '../storage/payload_store.dart';

/// No live transport off native IO; the catalog hides the live action.
SessionLiveDirectory? createSessionLiveDirectory({
  DateTime Function()? now,
  PayloadStore? payloads,
  PermissionModePolicy? permissionModes,
  UnrestrictedOwnershipLedger? unrestrictedOwnership,
  CommandId Function()? commandIds,
}) => null;
