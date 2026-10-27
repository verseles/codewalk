import 'package:codewalk_core/codewalk_core.dart';

import 'session_projection.dart';

/// The native tool that runs a subagent in a child session.
const openCodeSubagentTool = 'subagent';

/// What the metadata of a subagent call says about its child: nothing when
/// the key is absent, else the child, or null for a value that cannot name a
/// child of [parent] (not a bounded session id, or [parent] itself).
({bool present, SessionRef? child}) openCodeSubagentChild(
  Map<String, Object?> metadata,
  SessionRef parent,
) {
  if (!metadata.containsKey('sessionID')) return (present: false, child: null);
  final value = metadata['sessionID'];
  try {
    if (openCodeSessionId(value) == parent.nativeId) {
      return (present: true, child: null);
    }
  } on FormatException {
    return (present: true, child: null);
  }
  return (
    present: true,
    child: SessionRef(parent.host, parent.harness, value as String),
  );
}

/// The child of one observation of a subagent call, given the call as it
/// stands in the same [generation]: a refusal sticks for the generation, and
/// a child other than the one already observed is refused, never switched.
({SessionRef? child, ToolChildEvidence evidence}) openCodeChildEvidence({
  required SessionRef? named,
  required ToolCall? prior,
  required SourceProvenance origin,
  required String generation,
}) {
  final known = prior?.generation == generation ? prior?.childEvidence : null;
  ToolChildEvidence evidence(ToolChildEvidenceKind kind) =>
      ToolChildEvidence(kind: kind, origin: origin, generation: generation);
  if (known?.kind == ToolChildEvidenceKind.rejected ||
      named == null ||
      (known?.kind == ToolChildEvidenceKind.observed &&
          prior?.child != named)) {
    return (child: null, evidence: evidence(ToolChildEvidenceKind.rejected));
  }
  return (child: named, evidence: evidence(ToolChildEvidenceKind.observed));
}
