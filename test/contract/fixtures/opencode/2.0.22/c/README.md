# OpenCode 2.0.22 permission and form capture — V2-005C

Observed native responses and provider events on Linux x86_64, using official
`@opencode/cli@2.0.22` and managed service `http://127.0.0.1:49374`.
Tracking: [V2-005C #242](https://github.com/verseles/codewalk/issues/242).
These fixtures cover this child; they do not accept parent SP-01 or an
application/device/release gate.

## Accepted observed subset

| Behavior | Actual provider evidence | Supporting native-handler evidence |
|---|---|---|
| `once` | Fledge read permission, native once reply, successful read and exact `C_PERMISSION_ALPHA` answer | Same resource asks again; no saved approval |
| `always` | Fledge read resumes and succeeds; approval saved as `read:*` in a committed disposable Git project | A different session in that same native project evaluates to allow; saved approval then removed |
| Reject with note | Space Bunny issues two read tool calls in one assistant message; both requests are simultaneously pending; one reject clears both, both fail with feedback, model returns `C_REJECT_FEEDBACK_OK` and succeeds | An API-created request in another session remains pending and is separately settled |
| Reject without note | The same real parallel-tool scenario rejects both requests, emits `session.execution.interrupted`, and records an aborted assistant with no final text | Independent session remains pending; a second reply to a removed batch request returns 404 |
| Question reply | Fledge's actual `question` tool creates a `q0` form; native answer `Blue` resumes the model and returns exactly `Blue` | Typed generic form also accepts string, integer and boolean answers |
| Question dismissal | Native dismissal without a message cancels the actual question form and interrupts the current step, with an aborted assistant and no final text | Generic form is authoritatively `cancelled`, without a message |

The no-note interruption reason is literally `shutdown` in this 2.0.22
capture; its session record has no successful outcome. Keep that native
value instead of replacing it with an invented rejection outcome.
Forms were answered by a test collector using predetermined fixture answers;
this does not implement or authorize automatic answers in CodeWalk.

## Restart and project-isolation findings

An empty `git init` directory resolves to native project ID `global`.
The original native suite and always turn therefore did not establish
isolated project grants. They are preserved as `*-global-project.json`
diagnostics. The suite and always turn were repeated after creating a new
directory and **committing the two disposable input files before its first
native API access**. Native project ID and initial Git commit both equal
`fdb157e6e688e8ab6521d2643bf6d838517fb509`. The corrected `native-interactions.json`
and `provider-always.json` prove grant scope in that project. The other
provider scenarios use distinct sessions in the original global project;
their session ownership/batch isolation remains observed, and they do not
prove isolated project configuration.

A separately coordinated shared-service restart during V2-005B resumed
three formerly interrupted C sessions. Both no-note rejection histories
gained native `synthetic` messages with `metadata.notice: restart`, followed
by successful text-only continuations that did not repeat reads. A dismissed
question session asked another question. Its new pending form was captured
in `post-restart-question-recovery.json`, then dismissed **with explicit
feedback**; the model returned `C_DISMISS_RESTART_RECOVERY_OK` and succeeded.
Original step interruption is observed; permanent cancellation across
service restart is not established. These native synthetic history records
are real server output, not manufactured fixture events.

The initial process was PID 117273; the corrected isolation captures and
post-restart recovery used PID 126717 on the same 2.0.22 managed-service URL.
The collector did not stop/restart the service. Three other disposable sessions with interrupted or failed captures were deleted after retaining their authoritative history,
to prevent further native resumption. Final audits show no pending C
interactions and no saved grants in either observed project.

## Evidence and reproducible validation

| Files | Purpose |
|---|---|
| `native-interactions.json` | Supported native permission/form APIs, real handler-generated pending requests/events, no provider executions |
| `provider-once.json`, `provider-always.json` | Actual free-provider read requests, replies, stream and authoritative history |
| `provider-reject-*-space-bunny-free.json` | Real simultaneous tool requests, batch rejection with/without note and independent-session control |
| `provider-form-reply.json`, `provider-form-dismiss.json` | Actual native question tool forms and subsequent execution lifecycle |
| `provider-reject-note.json`, `provider-reject-none.json`, `fledge-single-rejection-resolution.json` | Fledge diagnostic attempts emitted only one read, so external replies settled them; never used to pass real parallel-tool checks |
| `*-global-project.json` | Original project-scope diagnostics; corrected isolated evidence is above |
| `post-restart-question-recovery.json` | Real resumed form state plus newly observed feedback cancellation and successful recovery |
| `post-capture-checks.json` | Authoritative settled-form states, failed-collector history recovery, restart continuations, cleanup/removal responses |
| `provenance.json`, `validation.json`, `SHA256SUMS` | Capture inputs/topology/limits, semantic checks and integrity |

Run from the repository root:

```sh
python3 test/contract/fixtures/opencode/2.0.22/c/validate.py
```

The checked-in validator is read-only, has no external dependencies and makes
no server/model calls. It checks admission/history/event correlation,
real tool-request ownership and concurrency, both batch replies, independent
session preservation, form settlements, step success/interruption, recorded
zero costs, project scope/cleanup, diagnostic boundaries, redacted credential
fields and every artifact in `SHA256SUMS`.

The environment-local collector was
`python3 /workspace/.cloud-tools/v2-005c-capture.py <scenario> [free-model] [directory]`.
Scenarios were `native`, `once`, `always`, `reject-note`, `reject-none`,
`form-reply` and `form-dismiss`; corrected native/always calls supplied the
committed `capture-c-isolated` directory. Exact HTTP methods, paths, authored
payloads, response statuses, native JSON, timestamps and model metadata are
retained in each fixture. Global `/api/event` was authenticated before each
authored prompt; event records are sanitized parsed native frames, not raw
byte-for-byte SSE recordings. Generic API-created requests are labelled
separately from model-generated requests.

Fledge's first two rejection attempts did not produce parallel tools; Space
Bunny supplied the required concurrency. An earlier form-dismiss attempt
ended with native `provider.invalid-output`; the recorder failed on an
absent optional assistant `cost` field before saving its stream. Its later
authoritative history is preserved explicitly as a diagnostic; it is not a
live stream pass. The recorder was corrected to preserve absent fields,
and a separate observed dismissal succeeded in interrupting the step.
The first model-catalog probe on a fresh location was empty before plugin
settlement; a bounded wait obtained the enabled free model.

Ten authored prompts used only enabled zero-cost `opencode` models: Fledge
Alpha Free and Space Bunny Free, variant `low`. Every recorded session and
present assistant cost is US$ 0. The original ceiling was **twelve actual
provider executions**, including automatic resumptions. Ten authored prompts
plus three automatic native restart continuations produced **thirteen actual
executions: an unexpected overrun of one**. The native restart caused the
additional executions; no extra prompt was authored. The resumed work was
settled and the disposable capture sessions removed; no further provider
calls were issued. Future captures must use separate service runtimes or
dispose interrupted test sessions before a coordinated shared-service
restart, and count native automatic resumptions against the execution ceiling.

Tokens/codes/passwords/API-key fields are redacted; Authorization headers were
never saved. Opaque provider state is replaced by an explicit marker.
Native IDs, field names, public input contents, tool outputs, timestamps,
failure reasons and native synthetic notices are preserved. No repository or
credential files were read by the model. The v2 primary anchors remain pinned
to 2.0.21; this capture ran **2.0.22 only**, matching the later research source
pin `05018b8862a8fc198ec9810aafd397c96bb7d86e`. It does not establish other
versions, platforms, arbitrary form types, child interactions, permission
mode UI behavior or permanently cancelled work across restart.
