# OpenCode 2.0.22 children, interruption and revert — V2-005D

Observed native Linux x86_64 subset for
[V2-005D #243](https://github.com/verseles/codewalk/issues/243).
Official `@opencode/cli@2.0.22` connects to the managed 2.0.22 service at
`http://127.0.0.1:49374`, PID 126717. These are sanitized real responses and
events, with their actual negative outcomes; no example events or fabricated
child sessions were substituted.

**Delivered subset:** foreground/nested children, moving foreground work to
background, explicit interruption ownership, and physical file/history
effects of revert stage/clear/commit. **Retry and quota remain inconclusive:**
no natural retry/quota event occurred. This subset does not accept all of D,
the parent SP-01 gate, an application implementation or another platform.

## Observed operations

| Scenario | Real observed evidence |
|---|---|
| Foreground and nested | A parent calls the native `subagent` tool; its child calls another native `subagent`; the grandchild reads `nested-marker.txt`. Three distinct IDs form the actual parent→child→grandchild lineage. Foreground tool results propagate `D_NESTED_MARKER_OK` through both parents; all three executions succeed. |
| Move foreground to background | A second parent starts a foreground child. The child's real `read` permission is held pending. `POST /background` completes the parent's blocking tool with metadata `status: running` and the actual child ID; the parent succeeds while that child remains active. Native history includes the backgrounding instruction. |
| Explicit interruption | Interrupting the idle parent returns `{interrupted:false}` and preserves the active child. Interrupting that child returns `{interrupted:true}`, emits `session.execution.interrupted` with literal reason `user`, and records an aborted assistant. The native child completion notification has `metadata.source: subagent`, that child ID and `state: cancelled`; it triggers one new parent execution, which succeeds. |
| Actual edit and revert | The native `write` tool changes tracked `revert-target.txt` from `D_REVERT_BEFORE\n` to `D_REVERT_AFTER\n`. Stage with `files:true` restores before bytes while retaining history; clear restores after bytes; stage with `files:false` preserves after bytes and records an empty file list; another clear preserves them; repeated true stage restores before; commit keeps before bytes, clears revert and removes boundary-and-later history/inbox. |

Stage/clear/commit evidence includes bytes, SHA-256, Git diffs, native revert
file patches, event correlation and authoritative session/history/inbox.
These are native tool writes in a scoped disposable workspace. They do not
verify containment of the separate experimental raw filesystem-write API.

The protocol retains a tool name in `session.tool.input.started`;
`session.tool.called` carries its ID/input but **no `name` or `tool` field**.
Correlation uses the tuple `(sessionID, assistantMessageID, toolID)` through
started/raw-input-ended/called, the native permission source, tool progress
and projected tool metadata. The actual child session's `parentID` confirms
ownership. `offline-tool-correlation.json` proves that mapping from saved
responses/events without another model call.

## Project, model and execution budget

The disposable project is `/workspace/.cloud-runtime/opencode-v2/capture-d`.
Its config and three public input files were committed **before first native
location access**. Initial Git commit and native project ID are both
`a8428d2df1249d57369eadf3d6205a4259f3a048`, not `global`.
Project-local config enables snapshots and subagent depth 2, disables warming,
and defines the scoped `capture-d` agent with mode `all`. Its selected model
is **Space Bunny Free / OpenCode**, `opencode/space-bunny-free#low`. Native
catalog and agent snapshots confirmed enabled/active status, tool capability,
that variant and all advertised cost components equal to zero before input
admission. Every recorded session cost and present assistant cost is US$ 0.

Only the three owned read paths, `revert-target.txt` edits and approved
`capture-d` child creation are allowed by the test agent. Child requests were
answered `once`; no `always` reply or project grant was written. Root, child
and grandchild model records retain the same guarded free model.

The preflight allowed 90 active minutes, targeted 7–8 executions and capped
**12 actual native executions**, including descendants and continuations.
The collector observed **11 `session.execution.started` events**, all with a
terminal event:

- 2 initial collector diagnostics, explicitly interrupted and disposed;
- 3 successful foreground/nested executions;
- 3 background/interruption executions: parent, child and native completion
  continuation of the parent;
- 3 revert executions: the authored write plus two native empty drains after
  clear calls.

The target estimate was exceeded; the hard ceiling was respected. No new
input was admitted after those eleven executions. Each clear wakes native
execution even when no input is queued: the official
`packages/core/src/session/session.ts` implementation ends `revert.clear`
with `execution.wake(sessionID)`. The two observed clear drains lasted only
milliseconds, appended idle records, and created no additional assistant
message. They are included in the execution budget rather than treated as
free API-only mutations. Future estimates must reserve capacity for these
native drains and completion notifications.

The first two collector attempts looked for the tool name in the wrong
event, raising `KeyError: tool` and then `KeyError: name` before child
approval. Their real starts, interruptions, history and cleanup remain in
`foreground-nested-collector-diagnostic*.json` and the ledger. Correcting the
collector after inspecting the owning schema and demonstrating the saved
correlation produced the successful scenario. Neither diagnostic is used
to pass child behavior. No provider authentication workaround, paid fallback,
forced quota exhaustion or synthetic retry was used.

## Evidence and reproducible validation

| File | Purpose |
|---|---|
| `setup.json`, public `*.txt` inputs | Exact project config, pre-access Git commit and owned input contents |
| `foreground-nested.json` | Actual three-level sessions, native subagent requests/results and successful owned histories |
| `background-interrupt.json` | Actual held child request, foreground→background move, active-map snapshots, idle-parent/active-child interrupt responses and native cancellation notification |
| `revert-file-effects.json` | Actual write, eight physical byte/digest/diff snapshots, six revert mutations and authoritative states |
| `execution-ledger.json` | Every owned native start/terminal, including both collector diagnostics and the two clear drains |
| `foreground-nested-collector-diagnostic*.json` | Original negative collector attempts; do not prove children |
| `offline-tool-correlation.json` | Derived checks of native source/tool/child ownership from saved evidence |
| `cleanup.json` | No active owned session, retained inbox/form/permission lists empty, no saved grants, disposed sessions return 404 |
| `provenance.json`, `validation.json`, `validate.py`, `SHA256SUMS` | Immutable runtime/source/limits, observed-subset checks, read-only validator and integrity |

From the repository root:

```sh
python3 test/contract/fixtures/opencode/2.0.22/d/validate.py
```

The validator uses only Python's standard library, reads checked-in files and
makes no native/model/network call. Report generation is explicitly opt-in;
ordinary validation does not rewrite evidence. Root publication/review/Issue
acceptance remains separate.

The environment-local collector was run as:

```sh
python3 /workspace/.cloud-tools/v2-005d-capture.py prepare
python3 /workspace/.cloud-tools/v2-005d-capture.py nested
python3 /workspace/.cloud-tools/v2-005d-capture.py background
python3 /workspace/.cloud-tools/v2-005d-capture.py revert
```

`nested` had the two preserved collector attempts before the corrected run.
Authenticated global `/api/event` was attached before each authored root
admission. Descendants were discovered from actual `session.created`
location/parent IDs; they were never manually created for a passing result.
Exact HTTP methods/paths/payloads/statuses and parsed native events are saved
in the phase fixtures. Events are sanitized JSON frames rather than raw SSE
bytes or replayed source-generated examples. Pairing credentials stayed in
memory; secret fields are redacted and opaque provider state explicitly
omitted. Native IDs, literal data, file patches, failure reasons and native
synthetic messages remain intact.

Final audit covers eight owned sessions: five retained and three disposed
(the two collector diagnostic roots and the interrupted background child).
No owned execution, pending inbox item, permission, form or saved project
grant remains. The collector did not restart/reconfigure the shared service
or other projects. Explicit user interruption releases the native claim;
disposed negative sessions cannot later resume in another capture's restart.

## Source authority and remaining work

Official source was inspected directly at the 2.0.22 research pin
`05018b8862a8fc198ec9810aafd397c96bb7d86e`: protocol session routes; schema
config/agent/model/experimental/warming; native subagent/job/completion;
session execution/revert/projector and per-session clear operations. The
versioned CodeWalk anchors retain their separate 2.0.21 primary pin. This
capture establishes the observed 2.0.22 subset only.

Secondary OpenChamber evidence was read directly at
`24dac3fb23dd025c6cff135614b96e21a8e08348`, particularly
`packages/ui/src/lib/opencode/subagent-run.ts` and
`components/chat/revertedMessageDockState.ts`. It distinguishes real native
completion messages from client-only running display rows; none of those
client-only rows became fixture evidence. Secondary code does not override
official source or observed outcomes.

**Concrete retry/quota resume:** capture a naturally occurring native
`session.retry.scheduled`/provider rate-limit or quota failure on an authorized
enabled free model, preserving native error/attempt/deadline and subsequent
outcome. Use another bounded unit with an execution budget. Current absence
does not prove retry behavior, remaining quota, or that quota does not exist;
no missing case is marked passed. Background success beyond the observed
cancellation, depth beyond the tested grandchild, cascaded parent stop,
other model/platform versions and parent SP-01 acceptance remain separate.
