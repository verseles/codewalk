/// OpenCode v2 wire boundary, independent of the Flutter app.
///
/// This public library intentionally has no implementation in V2-020A.
library;

export 'src/endpoint_probe.dart';
export 'src/server_info.dart';
export 'src/version_policy.dart';
export 'src/retry_after.dart';
export 'src/pairing_client.dart';
export 'src/item_ids.dart';
export 'src/message_id.dart';
export 'src/prompt_client.dart';
export 'src/interrupt_client.dart';
export 'src/permission_reply_client.dart';
export 'src/session_reader.dart';
export 'src/stream_owner.dart';
export 'src/event_projection.dart';
export 'src/execution_projection.dart';
export 'src/inbox_projection.dart' hide openCodeInboxRow;
export 'src/interaction_projection.dart'
    hide openCodePendingForm, openCodePendingPermission;
export 'src/notice_projection.dart';
export 'src/revert_projection.dart' hide openCodeStagedRevert;
export 'src/session_lifecycle_projection.dart';
export 'src/step_usage_projection.dart';
export 'src/text_reasoning_projection.dart';
export 'src/tool_projection.dart';
