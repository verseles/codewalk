# OpenCode 2.0.22 observed contract capture — V2-005A

Captured on 2026-10-04 from the official native `@opencode/cli@2.0.22`
installation and its connected 2.0.22 managed service on Linux x86_64.
The isolated service listens at `http://127.0.0.1:49374`; config, data,
state, cache, temporary files and the disposable workspace are under
`/workspace/.cloud-runtime/opencode-v2/`.

Tracking: [V2-005A, Issue #240](https://github.com/verseles/codewalk/issues/240).
Checkout: `main`, `5b782e2a0c0a595059a9c5f811b2a5e072d0cac6`.
These are observed native responses and provider events, with the redactions
described below. They are not schema-generated response examples.

## Observed result

One prompt used `opencode/fledge-alpha-free#low`, displayed by the native TUI
as **Fledge Alpha Free / OpenCode Zen**. It required no authenticated provider
integration. The native catalog announced zero cost; both completed assistant
steps and the session reported **US$ 0**.

The model used `read` on the generated `capture-marker.txt` and returned exactly
`SP01_NATIVE_V2_FREE_MODEL_OK`. The stream contained two reasoning sequences,
one completed tool call and one text sequence, then
`session.execution.succeeded`. Projected history contains the user input,
two completed assistant messages and an idle record; the session outcome is
`succeeded`. The native TUI was open before admission and displayed the
thought labels, `Explored: 1 read`, the final marker and the free-model label
for that same session.

Authentication checks rejected anonymous and invalid-token requests. JSON
pairing produced a token accepted as the Basic password; redeeming the same
code again returned 401. A fresh pairing yielded another valid token. A paired
token also successfully called `POST /api/pair` to mint its successor: the
new token authenticates, its expiry timestamp advances, and the previous
token remains valid. This is observed renewal through pairing, not observed
expiration or revocation.

## Evidence files

| File | Observed evidence |
|---|---|
| `info.json` | Connected server identity, URLs and isolated temporary path |
| `auth-pairing.json` | Anonymous/invalid rejection, single-use redemption and fresh pairing; native CLI operations are labelled by exit code |
| `token-renewal.json` | Authenticated pairing with a paired token, successor redemption and accepted successor |
| `model.json` | Native enabled free-model metadata, tools, variant and announced cost |
| `session-created.json`, `session-completed.json` | Same session, location/model, usage and successful terminal outcome |
| `prompt-admission.json` | Exact authored input and durable native inbox admission |
| `input.txt` | Authored disposable file content supplied to the model's read tool |
| `events.json`, `events.sse` | 27 observed session events, retaining native IDs/timestamps/durable metadata; SSE is re-encoded after JSON redaction |
| `messages.json` | Authoritative projected history after the turn |
| `tui.ansi`, `tui-screen.txt` | Native terminal recording through the completed display, and its decoded 80×24 screen |
| `capture-result.json` | Collector timings/counts and its terminal-wait diagnostic |
| `provenance.json`, `validation.json`, `validate.py`, `SHA256SUMS` | Runtime/input provenance, 38 passed consistency checks and fixture integrity |

`validation.json` checks authentication outcomes, session/admission/message
correlation, unique event IDs, successful execution, zero cost, text/reasoning
delta concatenation versus authoritative ended values and projected history,
tool input/result versus completed history, the source-file marker and TUI
display, matching sanitized SSE/JSON, and redacted credential fields.
The committed `validate.py` reproduces these checks without changing fixtures;
`--write-report` explicitly regenerates the report when a capture changes.

## Initial compatibility and anchor check

| Surface | Observed on 2.0.22 | Primary preserved reference |
|---|---|---|
| Detection | Authenticated JSON `/api/info` identifies 2.0.22 | `protocol-groups/server.ts` |
| Authentication | Fixed Basic user `opencode`; paired token accepted; missing/invalid token rejected | `server/auth.ts`, `server/middleware_authorization.ts` |
| Pairing / renewal | Five-minute advertised code TTL, single-use redemption, paired-token successor issuance | `server/pairing.ts`, `server/auth.ts` |
| Admission / history | POST admits a durable inbox item; subsequent projected history contains its native message ID | `protocol-groups/session.ts`, `protocol-groups/message.ts` |
| Streaming | Native `type`/`data` envelope; text and reasoning started/delta/ended values match history | `schema/session-event.ts`, official reference reducer |
| Tool lifecycle | Input started/ended, called and success events correlate with completed `read` history | `schema/session-event.ts`, `schema/session-message.ts` |
| Completion | `session.execution.succeeded`, session `outcome: succeeded` and completed assistant timestamps agree | `schema/session-event.ts`, `schema/session.ts` |
| Shared TUI | API-driven turn appears live in the native TUI opened on the same session | Managed service plus captured native terminal |

References are preserved under `plan/opencode-v2-src/`; the scoped official
anchor is `ai-docs/opencode_v2_server.md`. Its primary source pin is
`anomalyco/opencode@v2.0.21`, commit
`8a8bd622a3d7dc29ccf30ec17f84e363ed95ed72`; the later research pin for 2.0.22 is
`05018b8862a8fc198ec9810aafd397c96bb7d86e`. This capture ran **2.0.22 only**.
The observed subset agrees with those preserved contracts; it does not
establish a multi-version compatibility window.

Keep the native fields verbatim: both a reasoning part and a text part can
have `ordinal: 0` in one assistant message. That ordinal is not an index into
the combined projected `content` array. This short turn emitted no
`session.tool.input.delta`; its complete input is present in the ended value.
The native tool's `executed: false` is retained alongside its success event
and completed result, without reinterpreting that flag as a failure.

## Commands and capture limits

Commands ran in the disposable workspace using the fixed `opencode2` wrapper:

```sh
opencode2 --version
opencode2 auth list
opencode2 api GET /api/info
opencode2 api GET /api/model
opencode2 api POST /api/pair
opencode2 api POST /api/session --data '{"title":"V2-005A observed free model capture","location":{"directory":"/workspace/.cloud-runtime/opencode-v2/workspace"},"model":{"id":"fledge-alpha-free","providerID":"opencode","variant":"low"}}'
opencode2 --session ses_efad87538ffeM1l1gJnGdlhjE0 .
```

An environment-local Python collector redeemed pairing codes in memory,
authenticated the global `/api/event` stream before sending the exact request
in `prompt-admission.json`, and fetched native session/message state afterward.
The native TUI was recorded with util-linux `script`; `pyte 0.8.2` decoded
the saved completed screen. Focused validation ran as
`python3 test/contract/fixtures/opencode/2.0.22/validate.py` from the repository root.

The original collector waited for the nonexistent `session.execution.ended`
and timed out after three minutes, although the native success event had
already arrived in about 3.5 seconds. Its later abort probe of the idle
session did not change the successful outcome. The collector was corrected
to use native succeeded/failed/interrupted events. Validation uses the
recorded native success and authoritative history independently; the prompt
was not repeated.

Codes/tokens and provider API-key settings are replaced by `[REDACTED]`; Authorization headers were never
saved. Opaque provider state is omitted with an explicit structural marker.
Native IDs, epoch times, public model metadata, literal content, tool results
and durable metadata are retained. The recorded file was authored only for
this capture; the model did not read repository or credential files.

Real-time 30-day token expiry, unused-code expiry, password rotation,
browser-cookie/CORS behavior, replay/conflicts, disconnect/restart, approvals,
forms, children, filesystem containment, and other models/platforms remain
outside this capture. V2-005B/C/D/E and application/device/release gates remain
separate. No application source, existing tests or lockfiles were changed;
no commit, push or release was performed during the original capture.
