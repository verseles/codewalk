# OpenCode v2 — Server Contract Anchor

> **Scope:** new CodeWalk v2 consumers on `main`. The retained legacy implementation and `v1` maintenance use [the v1 server anchor](../ai-docs/opencode_server.md). This is a curated, source-pinned upstream contract reference, not a claim that CodeWalk v2 or its live acceptance checks are implemented.

## Provenance and authority

| Evidence | Pin / location |
|---|---|
| Official protocol/server/client source | `anomalyco/opencode@v2.3.2`, commit `c0ad18b402eb2827fc1ee71c171b1177b3fc02d1`, tagged 2026-11-18 |
| Official documentation | [Live V2 docs](https://opencode.ai/docs/), MDX source `services/site/src/docs/content/` at the same tag; rechecked 2026-11-22 |
| Docs routes | `/v2/docs/` now answers a `301` to `/docs/`; the legacy docs moved to `/v1/docs/`. A stored `/v2/docs/` URL is an alias, not a current route |
| Frozen local snapshot | [Snapshot index](../plan/opencode-v2-docs/INDEX.md): the 2026-10-02 capture against docs commit `bb381e8bdd1ff22c7329e07c068ec0099031f382`. It is history, not current documentation |
| Live deploy drift | 2026-11-22: the tag's `packages/protocol/openapi.json` has 142 paths / 173 operations; the served `https://opencode.ai/docs/openapi.json` has 146 paths / 178 operations plus one later Enterprise line. The site deploys from `dev`, so read the tag for version claims and the served file for what users see today |
| Older source snapshots | npm `@opencode/cli@2.0.22` at `05018b8862a8fc198ec9810aafd397c96bb7d86e`; the 2.0.22 fixtures under `test/contract/fixtures/opencode/2.0.22/` remain the runtime evidence cited below |
| Live verification owner | `V2-005` / SP-01 and its children; this document does not pass those checks |

Primary references are the [official protocol groups](https://github.com/anomalyco/opencode/tree/c0ad18b402eb2827fc1ee71c171b1177b3fc02d1/packages/protocol/src/groups), [schemas](https://github.com/anomalyco/opencode/tree/c0ad18b402eb2827fc1ee71c171b1177b3fc02d1/packages/schema/src) and server implementation. The [HTTP evidence dossier](../plan/11-opencode-v2-server-api.md) maps original paths to the preserved extracts; its older inferences must be reconciled with the primary source and the current [implementation plan](../v2-plan.md).

The pinned `packages/protocol/openapi.json` is generated from the protocol groups and now covers pairing (`/api/pair`), redemption (`/auth/connect/{code}`) and credential routes (`/api/credential…`), which earlier pins omitted. Do not treat its presence as a stable contract: the document still describes itself as an "Experimental HttpApi surface for selected instance routes". Inspect the owning protocol/schema/handler when generated descriptions disagree, and never use a rolling docs URL or an OpenAPI version string as a tested compatibility window.

## Service, detection and authentication

- The shared background service uses loopback and the channel-default port `49374` (`0xC0DE`) on macOS, Linux and WSL. Windows reserves ports from `49152` up, so the same channel port is remapped into `0x7000–0x7FFF`, which makes `49374` become `28894` there. `opencode service status` prints the address actually in use; foreground `opencode serve` starts with port `4096` and can advance when occupied. See the [service configuration](https://github.com/anomalyco/opencode/blob/c0ad18b402eb2827fc1ee71c171b1177b3fc02d1/packages/cli/src/services/service-config.ts) and [server process](https://github.com/anomalyco/opencode/blob/c0ad18b402eb2827fc1ee71c171b1177b3fc02d1/packages/cli/src/server-process.ts).
- `opencode service set` writes hostname, port, password, CORS origins, environment variables, remote access and the disabled flag. Changing a setting stops the background server; `opencode service start` applies it. These are operator-owned actions, not something a connected client should perform.
- Probe authenticated `GET /api/info` and validate JSON/media type, not an arbitrary HTTP 200. The pinned [ServerInfo schema](https://github.com/anomalyco/opencode/blob/c0ad18b402eb2827fc1ee71c171b1177b3fc02d1/packages/protocol/src/groups/server.ts) has `version`, `pid`, `urls` and `paths.tmp`, an optional `hostname`, and an optional `capabilities` object whose only current member is `persistentPty`. `pid` can be zero for a runtime without an OS process identity. Treat every capability field as optional and absent-by-default; do not invent CodeWalk Host coordination fields in this payload.
- Old routes such as `/global/health`, `/session` and `/event` can fall through to the unauthenticated web shell and return HTML 200 on a v2 server. They are not v2 API success or a v1 fallback.
- The server requires authentication. HTTP Basic uses the fixed username `opencode`; the password position accepts either the server password or a pairing session token. `OPENCODE_PASSWORD` supplies a fixed password to `opencode serve` and to `opencode --server`. See [auth](https://github.com/anomalyco/opencode/blob/c0ad18b402eb2827fc1ee71c171b1177b3fc02d1/packages/server/src/auth.ts).
- Pairing session tokens carry an expiry and an HMAC signature derived from the server password, so rotating the password revokes every issued session. The pinned TTL is 30 days, and the browser session cookie name includes the port so several local servers on one host stay separate.
- Authenticated `POST /api/pair` produces `{code, expires_in}`: a single-use code with a five-minute lifetime. `GET /auth/connect/{code}` redeems it without prior credentials; a browser receives a session cookie and a redirect to the web app, while a request accepting JSON receives `{token}` for the Basic password position. `opencode pair` prints that link and its QR, and the official app can connect by scanning the QR or pasting the link into its server address field. Renewal and failure scenarios still need SP-01 evidence.
- `opencode pair --remote` exposes the service through an [OpenTunnel](https://github.com/anomalyco/opentunnel) address after an explicit confirmation prompt; without an interactive terminal it requires `--yes`. Remote access is a per-service setting, visible in `opencode service set remote`, and is not implied by local pairing.
- Boot/shutdown responses include `503` service-state bodies and `retry-after`; they are distinct from normal `_tag` error envelopes. Follow the source and recorded fixtures rather than interpreting every 503 identically.

These describe upstream surfaces; this unit performs no installation, service mutation, credential retrieval or pairing experiment.

## Location, session and request boundaries

Location-scoped calls use `location[directory]` or the URI-encoded `x-opencode-directory` header, with the server working directory as fallback. Their responses wrap `location` and `data`. Session-scoped routes derive location from the session. Creation takes `location.directory` in its JSON payload. Use the pinned [location implementation](https://github.com/anomalyco/opencode/blob/c0ad18b402eb2827fc1ee71c171b1177b3fc02d1/packages/server/src/location.ts) and protocol schemas; v1 query/header conventions are not v2 constraints.

| Surface | Pinned meaning / consumer boundary |
|---|---|
| `GET /api/session`, `GET /api/session/{id}` | Native session index/state; cursor-based history is authoritative |
| `POST /api/session` | Create in the supplied location; an accepted native ID is not proof of replay safety |
| `PATCH /api/session/{id}` | Optional `title`, `metadata`, `permissions` and `archived`; repeating the archived state is a no-op |
| `POST /api/session/{id}/fork` | Child session copying projected history before a message, or the full history when `before` is omitted |
| `POST /api/session/{id}/prompt` | Durably admit input into the inbox and schedule execution; admission is not turn completion |
| Session `/model` and `/agent` POST routes | No-content selection for subsequent provider turns; see [model/agent anchor](opencode_v2_models.md) |
| Session `/inbox` and message routes | Reconcile admitted/queued input and projected history after uncertainty or disconnection |
| Session `/shell`, `/compact`, `/synthetic` | Separate admission paths: one shell command with `shell.started`/`shell.ended` events, a steering compaction request, and synthetic input |
| Session `/move`, `/background`, `/environment`, `/view`, `/context`, `/diff` | Move across project directories, background blocking tools, replace the shell environment, mark idle as viewed, read active context, and read per-file turn diffs |
| Permission/form routes | Native interaction choices, ownership and resolution; forms remain a separate contract |
| Revert stage / clear / commit | Different file/history effects; stage can already apply file changes and running work can produce 409 |
| File list/find/read; experimental write | Reads and experimental raw-body writes are different capabilities; the source write route is not project-confined |
| PTY ticket and connection routes | Browser-compatible, short-lived connection authorization (`ticket` query or `x-opencode-ticket` header); verify cursor/reconnect behavior separately |

Exact payloads, errors and response wrappers come from the [session protocol](https://github.com/anomalyco/opencode/blob/c0ad18b402eb2827fc1ee71c171b1177b3fc02d1/packages/protocol/src/groups/session.ts), [filesystem protocol](https://github.com/anomalyco/opencode/blob/c0ad18b402eb2827fc1ee71c171b1177b3fc02d1/packages/protocol/src/groups/fs.ts), the generated client and the owning schemas. This table is not an exhaustive API inventory.

Prompt replay/conflict behavior and create replay/conflict behavior are separate experiments. [V2-005B native Linux 2.0.22 evidence](../test/contract/fixtures/opencode/2.0.22/b/README.md) establishes the following bounded matrix on that version; it is not an automatic compatibility claim for the v2.3.2 pin or later versions.

- Same-ID create returns the original session, ignoring changed title/metadata; controlled lost-response probes reconcile it without creating another session.
- Pending same-ID prompt replay returns the original admission, including changed text/delivery; cross-session ID reuse yields 409. Changed content in one pending session is not a verified conflict detector.
- Cancelling pending input returns 204, and repeating cancellation is a no-op. Reposting the cancelled ID **re-enqueues** it; there is no permanent deduplication tombstone.
- Promoted replay preserves original user history but can echo the requested delivery; replay may wake execution unless `resume:false`. Do not compare admission responses byte-for-byte or assume an echoed mode changed delivered work.

Preserve the exact original payload, identity and scope. Reconcile authoritative state; automatic replay requires a verified operation/version/lifecycle-phase guarantee for an unresolved command. Cancellation requested, submitting or uncertain fences original-send replay until reconciled; known cancellation or settlement never automatically resends. Otherwise retain uncertainty rather than create another turn/session. Experimental file write remains unavailable without verified remote physical containment, including symlinks/junctions and concurrent path replacement; lexical checks alone are insufficient. [V2-005E Linux 2.0.22 captures](../test/contract/fixtures/opencode/2.0.22/e/README.md) observe actual traversal, absolute-path and symlink escapes plus concurrent path replacement into owned disposable outside space. That connected version's write capability is **unavailable**, even when the product experimental setting is enabled. Windows junctions and other native targets are not passed by Linux evidence, and no later fixture has re-tested the route.

## Event stream and lifecycle

- `GET /api/event` is one global SSE stream across every server location. Frames use `data: <JSON>` and heartbeat comments; there is no SSE `id`/`Last-Event-ID` replay contract.
- The pinned subscriber queue is bounded to 4,096 events and fails the stream on overflow; the protocol states the volatility directly: a slow consumer overflows, and events during disconnection are missed. Reconnect requires authoritative hydration, not assumed replay.
- An optional `types` query filters the stream to selected event types plus the initial `server.connected` event. That filter is a bandwidth choice, not a subscription with durable positions.
- The envelope carries `id`, `type`, `created` and `data`, plus optional `location` and `metadata`; durable definitions add a `durable` block with `aggregateID`, `seq` and `version`, and `rpc.*` events from plugin RPCs share the stream. Do not reuse the v1 `properties`/global-event wrapper as the v2 DTO.
- Streaming text/reasoning/tool input uses started/delta/ended events. The authoritative ended value replaces an incomplete prefix; execution uses `session.execution.*` and the active list. The declared `session.status` event is not a substitute publisher.
- Parent idle does not prove child completion. Keep parent/child lineage and each child's execution/interaction ownership explicit.
- [V2-005C](../test/contract/fixtures/opencode/2.0.22/c/README.md) observes native permissions/forms and restart recovery on 2.0.22: interruption with reason `shutdown` can resume and re-ask a dismissed question after service restart. Refresh interactions during authoritative hydration; interruption is not permanent queued-work cancellation. A Git directory without an initial commit can resolve to upstream `projectID: "global"`; key projects by host plus canonical directory, and require a committed disposable project to prove saved-approval isolation.
- The experimental durable session log does not replay ephemeral deltas. Its per-aggregate sequence may include internal-record skips; those are not automatically a lost public event. SP-01 owns replay/cursor acceptance before enabling it. E observes only `log.synced` watermarks on the stock 2.0.22 CLI despite confirmed global events/renames, including follow mode. Its source defaults bus persistence to false and the CLI does not enable it; durable replay remains unavailable on that topology and authoritative hydration is required.

Use the preserved [official reference reducer](../plan/opencode-v2-src/client-solid-data.reference-reducer.ts) and [event/schema dossier](../plan/12-opencode-v2-events-and-schemas.md), with native schema/handler citations. The CodeWalk domain, receipt states and CHP stream sequence remain CodeWalk contracts, not additional OpenCode wire fields.

## Version-scoped children, interruption and revert

[D Linux 2.0.22 fixtures](../test/contract/fixtures/opencode/2.0.22/d/README.md)
observe native parent→child→grandchild lineage under an explicitly bounded
project test-agent/depth configuration; this does not assert stock agents allow
nested delegation. A real foreground child moves to background while the parent
becomes idle. Idle parent interruption preserves that active child; direct child
interruption terminates its own execution and produces native parent notification
and continuation. A child completion notice can arrive before the child's own
terminal event; preserve independent child lifecycle and notification provenance.

An actual tracked-file edit followed by stage(files=true), clear,
stage(files=false), repeated stage and commit preserves each recorded physical
byte/digest effect and native history boundary. **Clear calls `execution.wake`**:
two clear operations produced empty native execution-start/success drains with
no additional assistant/provider output. Do not treat every execution start as
a new provider message or assume uncertain revert mutations are replay-safe.
D records 11 actual executions including two collector diagnostics and those two
empty drains, within its ceiling12 and USD0; natural retry/quota evidence remains
pending, so the whole child/aggregate acceptance is not passed. Version-scoped
fixtures do not replace SP-01 revalidation on the pinned 2.3.2 server.

## Version-scoped attachments and service access

[E fixtures](../test/contract/fixtures/opencode/2.0.22/e/README.md) use the supported
`opencode service get password` CLI path only in memory to authenticate the local
service; credential values are never retained. This is distinct from the
provider-secret endpoint `/api/credential`, which remains outside CodeWalk's
supported surface even though it appears in the generated OpenAPI.

The official [2.0.21 attachment projection](https://github.com/anomalyco/opencode/blob/8a8bd622a3d7dc29ccf30ec17f84e363ed95ed72/packages/core/src/session/runner/to-llm-message.ts#L75)
and [2.3.2 projection](https://github.com/anomalyco/opencode/blob/c0ad18b402eb2827fc1ee71c171b1177b3fc02d1/packages/core/src/session/runner/to-llm-message.ts#L66)
forward `application/pdf` as media; the older summary claim was a mistaken
inference, not a version difference. E proves PNG recognition with tools disabled
and native PDF admission/history MIME. The free PDF-model call returned
provider.auth 403, so provider PDF recognition is unverified.

The current V2 documentation says a prompt attachment is a `uri` with optional
`name`/`description`: absolute `file:` URLs for files and directories, `data:`
URLs for inline content, and no HTTP/HTTPS URLs. UTF-8 text, directories,
PNG/JPEG/GIF/WebP images and PDFs reach the model, each read before admission and
rejected above 20 MiB, with unsupported binaries replaced by a short note. Image
normalization is configured under `media.image` (`auto_resize`, `max_width`,
`max_height`, `max_base64_bytes`). Those are documentation claims at the 2.3.2
pin; CodeWalk's approved PDF-disabled product policy remains separate and
unchanged, and must not be described as an upstream inability to forward PDF.

## Consumer readiness and companion anchors

`V2-002` establishes versioned reference paths. SP-01 revalidates auth/info/turn/interaction/retry/reconnect/file/log facts before consumers; compatibility evidence records the actual server version, topology and fixtures. A source-pinned fact is not a measured runtime/platform pass.

- [Official V2 documentation](https://opencode.ai/docs/) and [API reference](https://opencode.ai/docs/api/) (served [OpenAPI](https://opencode.ai/docs/openapi.json)).
- [Browser/Web contract anchor](opencode_v2_web.md).
- [Model/agent contract anchor](opencode_v2_models.md).
- [ADR registry](../ADR.md), ADR-023 contract-first principle and ADR-058 implementation-line architecture.
- [Legacy server contract](../ai-docs/opencode_server.md), retained for v1 and the reference implementation only.
