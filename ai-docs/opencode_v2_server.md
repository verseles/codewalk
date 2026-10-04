# OpenCode v2 — Server Contract Anchor

> **Scope:** new CodeWalk v2 consumers on `main`. The retained legacy implementation and `v1` maintenance use [the v1 server anchor](opencode_server.md). This is a curated, source-pinned upstream contract reference, not a claim that CodeWalk v2 or its live acceptance checks are implemented.

## Provenance and authority

| Evidence | Pin / location |
|---|---|
| Official protocol/server/client source | `anomalyco/opencode@v2.0.21`, commit `8a8bd622a3d7dc29ccf30ec17f84e363ed95ed72` |
| Official documentation snapshot | Docs commit `bb381e8bdd1ff22c7329e07c068ec0099031f382`, captured 2026-10-02; [snapshot index](../plan/opencode-v2-docs/INDEX.md) |
| Static pin recheck | 2026-10-03: the official GitHub tag resolves to the commit above; the preserved model protocol extract matches its official blob |
| Later source snapshot | Research also records npm `@opencode/cli@2.0.22` at `05018b8862a8fc198ec9810aafd397c96bb7d86e`; keep differences labelled rather than treating it as the same source revision |
| Live verification owner | `V2-005` / SP-01 and its children; this document does not pass those checks |

Primary references are the [official protocol groups](https://github.com/anomalyco/opencode/tree/8a8bd622a3d7dc29ccf30ec17f84e363ed95ed72/packages/protocol/src/groups), [schemas](https://github.com/anomalyco/opencode/tree/8a8bd622a3d7dc29ccf30ec17f84e363ed95ed72/packages/schema/src), and server implementation. The [HTTP evidence dossier](../plan/11-opencode-v2-server-api.md) maps original paths to the preserved extracts; its older inferences must be reconciled with the primary source and current [implementation plan](../v2-plan.md).

The pinned `packages/protocol/openapi.json` describes 136 operations but omits four routes present in source/generated client: pairing, pairing redemption and credential GET/POST. Inspect the owning protocol/schema/handler when generated descriptions disagree. A rolling docs URL or an OpenAPI version string is not a tested compatibility window.

## Service, detection and authentication

- The shared background service uses loopback and channel-default port `49374`; foreground `opencode serve` starts with port `4096` and can advance when occupied. See the preserved [service configuration](../plan/opencode-v2-src/cli/service-config.ts) and [server process](../plan/opencode-v2-src/cli/server-process.ts).
- Probe authenticated `GET /api/info` and validate JSON/media type, not an arbitrary HTTP 200. The pinned [ServerInfo schema](../plan/opencode-v2-src/protocol-groups/server.ts) has `version`, `pid`, `urls`, and `paths.tmp`; `pid` can be zero for a runtime without an OS process identity. Do not invent CodeWalk Host coordination fields in this payload.
- Old routes such as `/global/health`, `/session` and `/event` can fall through to the unauthenticated web shell and return HTML 200 on a v2 server. They are not v2 API success or a v1 fallback.
- The server requires authentication. HTTP Basic uses fixed username `opencode`; a pairing token is accepted in the password position. See [auth](../plan/opencode-v2-src/server/auth.ts) and [authorization middleware](../plan/opencode-v2-src/server/middleware_authorization.ts).
- Authenticated `POST /api/pair` produces a single-use code with a five-minute lifetime. `GET /auth/connect/{code}` redeems it without prior credentials: JSON acceptance yields `{token}`; browser acceptance yields a session cookie/redirect. Tokens last 30 days in the pinned auth implementation, and password rotation revokes them. Renewal and failure scenarios still need SP-01 evidence.
- Boot/shutdown responses include `503` service-state bodies and `retry-after`; they are distinct from normal `_tag` error envelopes. Follow the source and recorded fixtures rather than interpreting every 503 identically.

These describe upstream surfaces; this unit performs no installation, service mutation, credential retrieval or pairing experiment.

## Location, session and request boundaries

Location-scoped calls use `location[directory]` or the URI-encoded `x-opencode-directory` header, with the server working directory as fallback. Their responses wrap `location` and `data`. Session-scoped routes derive location from the session. Creation takes `location.directory` in its JSON payload. Use the pinned [location implementation](../plan/opencode-v2-src/server/location.ts) and protocol schemas; v1 query/header conventions are not v2 constraints.

| Surface | Pinned meaning / consumer boundary |
|---|---|
| `GET /api/session`, `GET /api/session/{id}` | Native session index/state; cursor-based history is authoritative |
| `POST /api/session` | Create in the supplied location; an accepted native ID is not proof of replay safety |
| `POST /api/session/{id}/prompt` | Durably admit input into the inbox and schedule execution; admission is not turn completion |
| Session `/model` and `/agent` POST routes | Select for subsequent provider turns; see [model/agent anchor](opencode_v2_models.md) |
| Session `/inbox` and message routes | Reconcile admitted/queued input and projected history after uncertainty or disconnection |
| Permission/form routes | Native interaction choices, ownership and resolution; forms remain a separate contract |
| Revert stage / clear / commit | Different file/history effects; stage can already apply file changes and running work can produce 409 |
| File list/find/read; experimental write | Reads and experimental raw-body writes are different capabilities; the source write route is not project-confined |
| PTY ticket and connection routes | Browser-compatible, short-lived connection authorization; verify cursor/reconnect behavior separately |

Exact payloads, errors and response wrappers come from [session protocol](../plan/opencode-v2-src/protocol-groups/session.ts), [filesystem protocol](../plan/opencode-v2-src/protocol-groups/fs.ts), the generated client and the owning schemas. This table is not an exhaustive API inventory.

Prompt replay/conflict behavior and create replay/conflict behavior are separate experiments. [V2-005B native Linux 2.0.22 evidence](../test/contract/fixtures/opencode/2.0.22/b/README.md) establishes the following bounded matrix; it is not an automatic compatibility claim for the primary 2.0.21 pin or later versions.

- Same-ID create returns the original session, ignoring changed title/metadata; controlled lost-response probes reconcile it without creating another session.
- Pending same-ID prompt replay returns the original admission, including changed text/delivery; cross-session ID reuse yields 409. Changed content in one pending session is not a verified conflict detector.
- Cancelling pending input returns 204, and repeating cancellation is a no-op. Reposting the cancelled ID **re-enqueues** it; there is no permanent deduplication tombstone.
- Promoted replay preserves original user history but can echo the requested delivery; replay may wake execution unless `resume:false`. Do not compare admission responses byte-for-byte or assume an echoed mode changed delivered work.

Preserve the exact original payload, identity and scope. Reconcile authoritative state; automatic replay requires a verified operation/version/lifecycle-phase guarantee for an unresolved command. Cancellation requested, submitting or uncertain fences original-send replay until reconciled; known cancellation or settlement never automatically resends. Otherwise retain uncertainty rather than create another turn/session. Experimental file write remains unavailable without verified remote physical containment, including symlinks/junctions and concurrent path replacement; lexical checks alone are insufficient. [V2-005E Linux 2.0.22 captures](../test/contract/fixtures/opencode/2.0.22/e/README.md) observe actual traversal, absolute-path and symlink escapes plus concurrent path replacement into owned disposable outside space. That connected version's write capability is **unavailable**, even when the product experimental setting is enabled. Windows junctions and other native targets are not passed by Linux evidence.

## Event stream and lifecycle

- `GET /api/event` is one global SSE stream. Frames use `data: <JSON>` and heartbeat comments; there is no SSE `id`/`Last-Event-ID` replay contract.
- The pinned subscriber queue is bounded to 4,096 events; an overflowing/slow subscriber is disconnected. Reconnect requires authoritative hydration, not assumed replay.
- The event envelope uses `type`, `data`, identity/time and optional location/durable metadata. Do not reuse the v1 `properties`/global-event wrapper as the v2 DTO.
- Streaming text/reasoning/tool input uses started/delta/ended events. The authoritative ended value replaces an incomplete prefix; execution uses `session.execution.*` and the active list. The declared `session.status` event is not a substitute publisher.
- Parent idle does not prove child completion. Keep parent/child lineage and each child's execution/interaction ownership explicit.
- [V2-005C](../test/contract/fixtures/opencode/2.0.22/c/README.md) observes native permissions/forms and restart recovery: interruption with reason `shutdown` can resume and re-ask a dismissed question after service restart. Refresh interactions during authoritative hydration; interruption is not permanent queued-work cancellation. A Git directory without an initial commit can resolve to upstream `projectID: "global"`; key projects by host plus canonical directory, and require a committed disposable project to prove saved-approval isolation.
- The experimental durable session log does not replay ephemeral deltas. Its per-aggregate sequence may include internal-record skips; those are not automatically a lost public event. SP-01 owns replay/cursor acceptance before enabling it. E observes only `log.synced` watermarks on the stock 2.0.22 CLI despite confirmed global events/renames, including follow mode. Its source defaults bus persistence to false and the CLI does not enable it; durable replay remains unavailable on that topology and authoritative hydration is required.

Use the preserved [official reference reducer](../plan/opencode-v2-src/client-solid-data.reference-reducer.ts) and [event/schema dossier](../plan/12-opencode-v2-events-and-schemas.md), with native schema/handler citations. The CodeWalk domain, receipt states and CHP stream sequence remain CodeWalk contracts, not additional OpenCode wire fields.

## Version-scoped attachments and service access

[E fixtures](../test/contract/fixtures/opencode/2.0.22/e/README.md) use the supported
`opencode service get password` CLI path only in memory to authenticate the local
service; credential values are never retained. This is distinct from the forbidden
provider-secret endpoint `/api/credential`.

The official [2.0.21 attachment projection](https://github.com/anomalyco/opencode/blob/8a8bd622a3d7dc29ccf30ec17f84e363ed95ed72/packages/core/src/session/runner/to-llm-message.ts#L75)
and [2.0.22 projection](https://github.com/anomalyco/opencode/blob/05018b8862a8fc198ec9810aafd397c96bb7d86e/packages/core/src/session/runner/to-llm-message.ts#L75)
forward `application/pdf` as media, with identical file digest; the older summary
claim was a mistaken inference, not a version difference. E proves PNG recognition
with tools disabled and native PDF admission/history MIME. The free PDF-model
call returned provider.auth 403, so provider PDF recognition is unverified.
CodeWalk's approved PDF-disabled product policy remains separate and unchanged;
it must not be described as an upstream inability to forward PDF.

## Consumer readiness and companion anchors

`V2-002` establishes versioned reference paths. SP-01 revalidates auth/info/turn/interaction/retry/reconnect/file/log facts before consumers; compatibility evidence records the actual server version, topology and fixtures. A source-pinned fact is not a measured runtime/platform pass.

- [Official v2 documentation root](https://opencode.ai/v2/docs/) and [API documentation snapshot](../plan/opencode-v2-docs/docs-api.md).
- [Browser/Web contract anchor](opencode_v2_web.md).
- [Model/agent contract anchor](opencode_v2_models.md).
- [ADR registry](../ADR.md), ADR-023 contract-first principle and ADR-058 implementation-line architecture.
- [Legacy server contract](opencode_server.md), retained for v1 and the reference implementation only.
