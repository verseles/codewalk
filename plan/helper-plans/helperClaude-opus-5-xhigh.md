# CodeWalk v2 — Independent Implementation Plan

Evidence base: `plan/` research pack (snapshot 2026-10-02), repo at `14fbf519` (v1.265.0), root `ADR.md`, `Makefile`, `.github/workflows/`, `pubspec.yaml`, and `plan/opencode-v2-src/`. Labels: **[V]** verified in the cited dossier or source, **[I]** inferred, **[U]** unverified and needs the listed spike. Nothing was executed or modified.

---

## 1. Status, objective, recommendation, intended behavior

### 1.1 Status

- Planning only. There are no absolute blockers for a v2.0 release on Android, Linux, macOS, Windows and Web.
- Hard prerequisites exist for iOS: an Apple Developer account, a macOS CI runner and signing secrets.
- One licensing fact must be checked before the daemon bundles the Claude Agent SDK (§9.3 U-07).
- Several decisive protocol facts need short spikes (§7.1).

### 1.2 Objective

Replace CodeWalk v1 (OpenCode v1 only) with a v2 client that:

1. speaks the official OpenCode v2 contract directly and exclusively;
2. is built on a harness-neutral core, so Codex, Claude Code, Pi, Muse Code, Grok Build and ACP agents attach through adapters without impersonating OpenCode;
3. deletes the v1 workaround layer (inventory `plan/00` §3, 25 items) rather than porting it.

### 1.3 Architectural recommendation

**D01 — Hybrid, two wire protocols on the client, one canonical model.**

- **Plane A, direct:** the Flutter app talks to the official OpenCode v2 server (`/api/*` HTTP, `/api/event` SSE, PTY WebSocket). No CodeWalk process is required on the host. OpenCode is the only harness with a network server designed for third-party clients: pairing, always-on auth, CORS configuration **[V `plan/11` §1.2–1.3]**.
- **Plane B, host daemon:** a new `codewalkd` runs on the host and exposes one CodeWalk Host Protocol (CHP) over WebSocket. Inside it, per-harness adapters drive each harness's native official surface:
  - Codex: shared daemon socket via `codex app-server proxy`.
  - Claude Code: Agent SDK / stream-json.
  - Pi: RPC mode.
  - Muse: MSP.
  - Grok and the long tail: ACP.
- **Client:** one `HarnessAdapter` interface with exactly two implementations, `OpenCodeAdapter` and `ChpAdapter`. Both emit the same canonical `SessionEvent` union into one pure reducer. UI code never sees a wire type.

Why not the alternatives:

| Alternative | Why it loses |
|---|---|
| Direct-only | Fails D13 for Codex: the shared daemon is a `0600` Unix socket; `--listen ws://` is a separate process that does not share sessions **[V `plan/20` §0.2, §4.1]**. Impossible for Claude, Pi, Muse and dsh, which are stdio-only **[V `plan/21` §4, `plan/22`, `plan/23`, `plan/25`]**. |
| Universal daemon (OpenCode also proxied and normalized) | Forces every OpenCode user to install CodeWalk software on the host, discards D10's official-service direction, and puts a translation layer between the app and the contract ADR-023 tells us to follow. |
| ACP for everything | Loses quotas, subagents (Draft RFD), background tasks, undo, replay and multi-client, all of which v1 ACP lacks **[V `plan/30` §17]**. |

Grok's native WebSocket server is feasible for direct connection but is plain `ws://` with one shared secret and no in-flight replay. It goes through the daemon for uniformity; direct Grok stays a possible later optimization.

**D15 — Daemon in TypeScript**, Node-compatible, shipped as a Bun-compiled single binary plus an npm package. Rationale and the runner-up (Dart AOT) are in §2.

**D02 — Phases:**

| Release | Scope |
|---|---|
| v2.0 | New skeleton, canonical core, OpenCode v2 direct, all platforms |
| v2.1 | `codewalkd` core + Codex + Claude Code |
| v2.2 | ACP client in daemon + Grok Build + Pi + experimental "custom ACP agent" (covers dsh) |
| v2.3 | Muse Code, host PTY, file mutations via daemon |

dsh native parity is deferred until it leaves preview.

**D07 — Three notification tiers:**

1. Connected: local notifications from canonical attention events (v2.0, all platforms).
2. Android: one foreground-service path holding the live stream (v2.0).
3. Host-originated push from `codewalkd` via user-managed ntfy/webhook (v2.1). A CodeWalk-operated push gateway is an alternative for discussion, not baseline.

### 1.4 Intended final behavior

- A user adds a **Host** by QR pairing, pasted link, or URL plus password. A host has an OpenCode endpoint and/or a daemon endpoint.
- The session list is unified by host and project directory. Each row carries a harness badge, activity state, unread state and a running-task count.
- Creating a session asks for a harness only when more than one is available on that host/project. The composer shows only the controls that harness supports.
- Sessions started in a terminal appear in the list. Each is labelled with what CodeWalk can actually do: live shared, resume, or branch.
- Sending is optimistic with a client-minted idempotent id. There is no polling for completion. Reconnects hydrate from authoritative snapshots (plus the durable log when available).
- Approvals default to auto-accept for sessions CodeWalk owns. Questions and plan approvals are never auto-answered.
- Background subagents and shells appear in a Tasks tray with stop and open actions.
- The app never claims background delivery it cannot provide. iOS and Web say so in settings.

---

## 2. Decision Assessment D01–D16

| ID | Verdict | Evidence and argument | Alternative / tradeoffs | Conf. | Verification |
|---|---|---|---|---|---|
| D01 | **Recommend: hybrid** | OpenCode has a designed third-party network surface. Codex shared sessions exist only on a local socket. Claude/Pi/Muse/dsh are stdio. Every comparable remote product runs a host process **[V `plan/31` §17.1]**. | Universal daemon: uniform replay and push, but mandatory host install and a layer over the official contract. Direct-only: breaks D13. | High | SP1, SP6 |
| D02 | **Recommend: v2.0 OpenCode → v2.1 daemon+Codex+Claude → v2.2 ACP/Grok/Pi → v2.3 Muse** | OpenCode v2 is already the default installer **[V `plan/10`]**; v1 users need a v2 client first. Codex and Claude are the two harnesses with D13 value and the richest protocols. Muse is proprietary, account-gated and "Developer Preview" **[V `plan/23`]**. dsh is rc and thin **[V `plan/25`]**. | Put the daemon and Codex in v2.0: satisfies multi-harness sooner, delays the OpenCode v2 migration by the whole daemon effort. | Medium | "Two-adapter rule" gate in §7 |
| D03 | **Keep** | Data layer, reducers and domain entities are v1 wire schema one-to-one; 26 presentation files call Dio **[V `plan/00` §5.2]**. The v2 message model is structurally different **[V `plan/12` §3]**. In-place migration would touch nearly every chat file anyway. | Strangler migration inside v1: keeps tests green longer but preserves the god objects. | High | — |
| D04 | **Keep, with required safeguards** | Same ID and updater replacement are feasible: `make release V=major` exists; build code is `epoch+2001` so v2 > v1 **[V `Makefile` L10, L21–25]**. Consequences below (§2.1). | Bridge release and `.legacy` app ID, see R1. | Medium | SP8 |
| D05 | **Keep default ON; change the mechanism** | v2 `always` saves a project-wide approval for all sessions. A wildcard session rule overrides agent `deny` rules and is inherited by children **[V `plan/12` §7.4–7.5]**. Porting v1's `always`+`remember` would be materially more permissive than v1. | See R2: auto-accept replies `once`, scoped to CodeWalk-owned sessions; wildcard bypass is opt-in. | High | SP1 |
| D06 | **Keep** | Native signals exist for Codex, Claude and Muse **[V `plan/20` §3.8, `plan/21` §3.15, `plan/23`]**. OpenCode has no remaining-quota API **[V `plan/11` §D]**. Host-side probes need a host process. | See R3: v2.0 ships without host probes; private vendor endpoints stay off per provider. | High | — |
| D07 | **Recommend: three tiers, host push in v2.1** | No harness has a push API. OpenCode's stream is live-only. APNs/FCM need server-held credentials, which conflicts with D08 if CodeWalk hosts them. | CodeWalk push gateway (R4). | Medium | SP3, SP4 |
| D08 | **Keep** | Consistent with Codex terms (hosted/commercial relay raises risk) **[V `plan/20` §6]** and Anthropic's ban on intermediating credentials **[V `plan/21` §6]**. | Hosted E2EE relay: best UX, high cost and policy exposure. | High | — |
| D09 | **Keep, with tiers** | No `ios/` folder exists **[V `plan/00` §1.1]**. Web runs under HTTPS, so browsers block `http://`/`ws://` to non-loopback hosts. Codex WS rejects any `Origin` **[V `plan/20` §4.1]**. | Drop Web or iOS from v2.0: less work, contradicts the user's choice. | Medium | SP2, SP3 |
| D10 | **Keep, with refinements** | Official binaries and SHA-256 come from the update API; the endpoint is undocumented **[V `plan/10` §a]**. The official install path overwrites a v1 binary **[V `plan/11` §E.2]**. | Adopt an existing v2 install first; use the `opencode service`/`opencode pair` CLI rather than file formats. | Medium | SP1 |
| D11 | **Keep for OpenCode and `codewalkd`; narrow for other harnesses** | Silent `curl | sh` for five vendors is a security and maintenance burden. Claude login must complete in Anthropic's own flow **[V `plan/21` §6]**. | R6: detect, then run the official command in a visible embedded terminal. | Medium | — |
| D12 | **Keep** | No technical impact. App strings still need 14 ARB locales. | — | High | — |
| D13 | **Keep as essential, with honest levels** | Live attach is real for OpenCode and Codex only. Claude and Pi are history plus takeover/fork. Muse has leases. See §3.2. | Promise uniform "continue anywhere": would be false. | High | SP6, SP7 |
| D14 | **Keep** | Fits a `(host, directory)` grouping key. Needs a merged paginator over heterogeneous sources. | Per-harness tabs: simpler, worse overview. | High | — |
| D15 | **Recommend: TypeScript (Bun-compiled, Node-compatible)** | Official or first-party libraries exist for Claude (TS SDK), Muse (TS SDK, MIT), Pi (`RpcClient`, `SessionManager`), ACP (TS SDK), and Codex generates TS types **[V dossiers 20–24, 30]**. Every mature comparable daemon is TypeScript **[V `plan/31`]**. | Dart AOT: one language, shared model, about 10 MB binary, but every adapter hand-written against weekly protocol churn and on-disk formats parsed by hand. Go/Rust: best systems properties, third toolchain, no harness SDKs. | Medium | SP5 |
| D16 | **Process-only** | No technical content. | — | — | — |

### 2.1 D04 consequences under the baseline (not a change)

1. **The v2 app must use the same signing key and a higher build code.** Both already hold by construction.
2. **v1 clients will be offered v2 automatically.** The updater reads `releases/latest` and compares semver **[V `update_check_service.dart` L161–200]**. A user whose host still runs OpenCode v1 ends up with an app that cannot connect.
3. **Mitigation inside the baseline:** v2 detects a v1 server (JSON from `/global/health`; `/api/info` absent) and shows a blocking explainer with two paths: upgrade the host, or download legacy v1.
4. **Legacy releases must not become "latest".** Publish them with `make_latest: false`, otherwise v2 clients stop seeing updates.
5. **The legacy build must not self-update to v2.** Its updater has to be repointed to the `v1.` tag line. This is a property of the legacy build, not the declined guard.
6. **Timestamp build codes cut both ways.** A legacy APK built after a v2 release has a higher `versionCode` and would install over v2 on the same app ID, running v1 code on v2-era data. Therefore v2 writes only to a new key namespace (`cw2.*`) and leaves v1 keys untouched.
7. **Web flips immediately.** `web-pages.yml` deploys from a branch; it must be gated so the hosted site does not break during development, and legacy web needs a `/v1/` path.

### 2.2 Changes I recommend the user reconsider

Each is an **ALTERNATIVE FOR DISCUSSION**. The baseline plan in §4–§7 does not depend on them unless stated.

- **R1 (D04).** Ship one last v1 release before v2.0.0 that pins its updater to the v1 line and checks the active server before offering v2. Also build legacy as `com.verseles.codewalk.legacy` ("CodeWalk Legacy").
  - Effect: users with v1 hosts are not stranded; legacy and v2 can coexist on Android; no cross-install hazard.
  - Cost: one extra v1 release and a second Android identity.
- **R2 (D05).** Define three approval levels: *Ask*, *Auto-accept* (default), *Bypass*.
  - Auto-accept answers permission requests once and applies only to sessions CodeWalk created or the user has prompted from CodeWalk.
  - Bypass is the harness's native skip-everything mode, opt-in per session.
  - Effect: plan-agent and deny rules keep working; a session open in someone's terminal is not silently approved from a phone.
- **R3 (D06).** Accept that v2.0 has no provider quota bars for OpenCode (only cost, tokens, context and parsed limit errors). Host probes return with the daemon in v2.1.
  - Alternative: pull "daemon core + usage" into v2.0 at the cost of schedule.
- **R4 (D07/D08).** Reliable notifications on iOS and for a dead app need either a user-installed ntfy client or a small CodeWalk-operated push gateway holding APNs/FCM credentials. The gateway is not a session relay, but it is CodeWalk-hosted infrastructure. Decide after v2.1 usage data.
- **R5 (D09).** Treat iOS and Web as "connect-only, constrained" tiers. Do not block the v2.0 release for other platforms on App Review.
- **R6 (D11).** For non-OpenCode harnesses, show the official install/update/login command and run it in a visible terminal on confirmation. CodeWalk never handles a harness login.
- **R7 (D13).** Present Claude and Pi external sessions as "Continue here (takes over)" or "Branch", never as live attach.
- **R8 (D02).** Accept OpenCode-only v2.0.
- **R9 (D15).** Accept a second language in the repo for the daemon.

---

## 3. Capability matrix

### 3.1 Integration pins

| Harness | Surface used | Pin | Reaches client via |
|---|---|---|---|
| OpenCode v2 | HTTP `/api/*`, SSE `/api/event`, WS PTY | source v2.0.21 `8a8bd622`; npm 2.0.22 `05018b88` | Direct |
| Codex | app-server v2 JSON-RPC on the shared daemon socket | CLI 0.159.3 schema; daemon 0.160.0 | `codewalkd` |
| Claude Code | Agent SDK / `claude -p` stream-json | SDK 0.3.287, CLI 2.1.287 | `codewalkd` |
| Pi | `pi --mode rpc` JSONL | 1.0.0 | `codewalkd` |
| Muse Code | MSP v1 (`muse serve`, stdio) | 1.4.2, schema fingerprint | `codewalkd` |
| Grok Build | ACP v1 + `x.ai/*` extensions | 1.0.46 | `codewalkd` (stdio) |
| dsh | ACP v1 stdio, thin | 0.2.0-rc.2 | `codewalkd`, experimental |

Legend: **N** native official surface · **Nᵉ** native but marked experimental upstream · **X** vendor extension · **D** provided by `codewalkd`, not the harness · **C** mapped in the client/adapter · **P** partial · **–** unsupported · **?** unverified.

### 3.2 Sessions and external sessions

| | OpenCode | Codex | Claude | Pi | Muse | Grok | dsh |
|---|---|---|---|---|---|---|---|
| List | N (cursor, search) | N | N (SDK reads local store) | D (session dir) | N | N + X | N |
| Create / resume | N | N | N | N | N | N | N (resume without history) |
| Fork | N (`before` message) | N (`beforeTurnId`) | N (`upToMessageId`) | N (`entryId`) | N (`cutPoint`) | X | – |
| Rename / delete | N / N | N / N | N / N | N / D | N / N | X / X | – |
| Archive | – (no route; `time.archived` exists in schema only) **[I]** | N | – | – | – | – | – |
| Discover external sessions | N | N | N | D | N | N | N |
| Live attach to a session running elsewhere | **N** (shared service) | **N** (shared daemon; approvals replayed) | – | – | – (lease: `sessionInUse`) | P (only if both use the same `serve`/leader) | – |
| Ownership signal | none (first reply wins) | `serverRequest/resolved` | none | none | lease error | none | none |
| History paging | N cursor | N cursor | N offset | N `get_entries{since}` | N `view/page` | N (full replay on load) | – |
| Reconnect catch-up | snapshot + Nᵉ durable log | resume + replay | D event log | durable cursor | N `viewCursor` | D event log | D event log |

Notes:

- OpenCode sessions running in a `--standalone` or foreground `opencode serve` process are not "active" in the shared service; `/api/session/active` is process-local **[V `plan/11` L892–901]**. Whether a prompt from the service then starts a second execution is **[U]**.
- Claude sessions created through the SDK are hidden from the terminal `/resume` picker by default **[V `plan/21` §3.6]**. CodeWalk must not spoof the entrypoint.
- Resuming a Claude or Pi session that is still open in a terminal creates two writers on one transcript. Default action when a transcript was modified recently: offer Branch.

### 3.3 Turn, streaming and control

| | OpenCode | Codex | Claude | Pi | Muse | Grok | dsh |
|---|---|---|---|---|---|---|---|
| Text deltas | N (100 ms batches; `ended` authoritative) | N | N (main thread) | N | N | N | P (committed chunks) |
| Reasoning | N | N (summary + text) | N | N | N | N | P |
| Tool input / output streaming | N / P (`tool.progress` metadata) | – / N | N / – | N / N | – / N | N | – |
| Steer mid-turn | N (`delivery: steer`) | N (`turn/steer`) | N (fold into turn; `priority: now`) | N | N | X `interject` | – |
| Queue for next turn | N (`delivery: queue`, inbox) | Nᵉ `thread/queue/*` | N | N `follow_up` | N | X | – |
| Cancel / edit queued | N | Nᵉ | P (raw control request only) | N `clear_queue` | N `turn/unqueue` | X ? | – |
| Stop | N `interrupt` | N | N (bug #98713 open) | N | N (with retract) | N | N |
| Compaction | N | N | N (`/compact`) | N | N | X | – |
| Retry visibility | N `session.retry.scheduled` | N `willRetry` | N `api_retry` | N | N | X | – |

### 3.4 Approvals, questions, plans, tasks

| | OpenCode | Codex | Claude | Pi | Muse | Grok | dsh |
|---|---|---|---|---|---|---|---|
| Permission decisions | once / always (project-wide) / reject (± feedback) | accept / acceptForSession / decline / cancel / policy amendment | allow / deny / edit input / rule suggestions | none (no permission system) | server-minted choices | allow/reject once/always | allow/reject once |
| Native allow-all | session ruleset (wildcard overrides denies) | `approvalPolicy: never` | `bypassPermissions` (not as root) | inherent | `allowAll` | `yoloMode` (denies still apply) | – |
| Sandbox axis | – | N (read-only / workspace-write / full access) | – | – | N | N (profiles) | P |
| Questions | N forms | Nᵉ | N (via permission callback) | X (extension dialogs) | N | X | – |
| Plan / todo list | – (removed in v2) | N | P (model-dependent) | – | N | N | – |
| Plan approval | C (plan agent switch) | Nᵉ | N | – | ? | N | – |
| Async subagents | N (child sessions; parent auto-resumes) | N (child threads) | N (task events) | – | N | X | – |
| Background shell | N | Nᵉ | N | – | N | X | – |
| Stop one task | N (interrupt child) | Nᵉ | N | – | N | X | – |
| Move running work to background | N (all blocking tools of a session) | – | N (per tool) | – | N | ? | – |

Undo, sandbox and approval toggles are separate axes in the model; none substitutes for another.

### 3.5 Undo, usage, catalog, files

| | OpenCode | Codex | Claude | Pi | Muse | Grok | dsh |
|---|---|---|---|---|---|---|---|
| Conversation rewind | N stage / commit / clear | fork only | fork / resume-at | fork only | fork / retract | X (conversation only) | – |
| File restore | N (snapshots, needs Git) | – | P (edit tools only; not shell or subagent edits) | – | – | – | – |
| Redo | N (clear staged revert) | – | – | – | – | – | – |
| Tokens / cost / context | N / N / C (model limit) | N / – / N | N / estimate / N | N / N / N | N / estimate / N | N / N / N | P / – / P |
| Quota windows | – (errors only) | N | N push + Nᵉ pull | – | N | X ? | – |
| Models / effort | N (variant on model ref) | N / N | N / N | N / N | N / N | N / N | N / N |
| Agents | N | – | N | – | – | P | – |
| Slash commands | N | C (no server registry) | N | N (extension/prompt/skill) | – (skills only) | N + X | – |
| Skills | N | N | N | N | N | X | – |
| `@` file mention | N structured (`file://` + range) | N search, text insert | text (CLI expands); search D | – ; search D | text; search D | X search | P resource link |
| Images / PDF | N / – ("PDF not sent") | N / – | N / N ? | N / – | N / – | N (unadvertised) / – | P / – |
| Files list / find / read | N | N | read only; rest D | D | D | X | D |
| Content grep | – (removed) | – | D | D | D | X | D |
| File write | Nᵉ (`experimental/fs/write`, not confined to the location) | N | D | D | D | X | D |
| Turn diff | N | N | P | – | N (`patchRef`) | X | – |
| Terminal | N PTY (ticketed WS) | N (connection-scoped) | – | – | – | X | – |
| User shell `!cmd` | N | N (unsandboxed) | ? | N | N | ? | – |
| Attention signal | events | `thread/status/changed` flags | `session_state_changed` | `agent_settled`, UI requests | `session/statusChanged` | permission request, stop reason | permission request |
| Push | – | – | – | – | – | – | – |

The brief states OpenCode has no native write endpoint. The source shows an experimental one **[V `plan/11` L1468–1480]**; the plan treats it as experimental and flag-gated, not as a stable capability.

---

## 4. Architecture and interfaces

### 4.1 Layout

```
lib/
  app/            bootstrap, composition root, lifecycle, deep links
  core/
    model/        ids, session, item, request, task, usage, capability, error, event, prompt, catalog
    reduce/       session_reducer.dart, session_state.dart, index_reducer.dart   (pure Dart)
    harness/      harness_adapter.dart, harness_registry.dart
    net/          http, sse_parser, ws, backoff, auth decorators (basic, oauth proxy, tailscale)
    storage/      kv, payload store, secure store, migrations/v1_import.dart
  harness/
    opencode/     wire/ (tolerant DTOs, id minting), opencode_api, opencode_event_stream,
                  opencode_translator, opencode_adapter, opencode_pairing, opencode_pty
    chp/          chp_client, chp_codec, chp_adapter                      (v2.1)
  managed/        ManagedRuntime interface; opencode_service_runtime_io; codewalkd_runtime_io; stubs
  stores/         HostsStore, SessionIndexStore, SessionStore, ComposerController,
                  AttentionStore, CatalogStore, UsageStore, TabsController, SettingsStore
  features/       onboarding, hosts, sessions, chat/{timeline,items,composer,requests,tasks},
                  files, terminal, usage, settings, voice, attention, update
  ui/             theme, markdown, shared widgets
daemon/           TypeScript workspace (v2.1): server, auth, log, fs, attention, usage, adapters/*
protocol/
  chp/schema/     JSON Schema (source of truth for CHP)
  fixtures/       opencode-v2/, codex/, claude/, muse/, pi/, acp/   (recorded wire + expected canonical)
```

Rules:

- `harness/opencode/` is the only directory that knows OpenCode wire shapes. OpenChamber confines the same knowledge to about five files **[V `plan/31` §2.2]**.
- `core/` has no Flutter imports, so reducers and translators run in plain `dart test`.
- State management stays on `provider` with small `ChangeNotifier` stores. `dartz`, the 31 pass-through use cases and service-locator calls from widgets are removed.

### 4.2 Identity

```dart
typedef HostId = String;          // client-local UUID of a configured host
typedef HarnessId = String;       // 'opencode' | 'codex' | 'claude' | 'pi' | 'muse' | 'grok' | 'acp:<agent>'

final class SessionRef { final HostId host; final HarnessId harness; final String nativeId; }
final class ProjectRef { final HostId host; final String directory; }   // normalized absolute host path
```

- A **Host** has up to two endpoints (OpenCode, daemon) and one transport profile (plain, Cloudflare Access OAuth, embedded Tailscale).
- Every cache key, draft key, tab and notification payload uses `SessionRef`. This replaces `serverId::directory` (ADR-002) and prevents collisions between harnesses that reuse id shapes.
- OpenCode ids are minted on the client using the official format. The official reference client does this for sessions and prompts **[V `client-solid-data.reference-reducer.ts` L319–332, L1440–1456]**. Ids embed time, so the generator uses a server-clock offset estimated from event `created` timestamps.

### 4.3 Canonical model (representative)

```dart
sealed class TimelineItem { ItemId get id; String? get turnId; ItemStatus get status; RawRef? get raw; }
final class UserMessage      extends TimelineItem { String text; List<Attachment> attachments; DeliveryState delivery; }
final class AssistantText    extends TimelineItem { String text; bool prefixMissing; }
final class Reasoning        extends TimelineItem { String text; }
final class ToolCall         extends TimelineItem { ToolKind kind; String rawName; ToolDetail detail;
                                                    Object? rawInput; TaskLink? task; HarnessError? error; }
final class ShellCommand     extends TimelineItem { String command; int? exit; OutputRef? output; }
final class Notice           extends TimelineItem { NoticeKind kind; String text; }   // model/agent switch, synthetic, system
final class Compaction       extends TimelineItem { String summary; }
final class TurnBoundary     extends TimelineItem { TurnOutcome outcome; }
final class UnknownItem      extends TimelineItem { String rawType; String? fallbackText; }

enum ToolKind { shell, read, edit, write, search, fetch, webSearch, mcp, subagent, question, skill, other }

sealed class SessionEvent { EventMeta get meta; }       // meta: sessionRef, seq?, ts, raw?
// ItemUpserted(item, placement) · ItemDelta(id, field, text) · ItemRemoved(id) · ItemsTruncated(fromId)
// ItemMovedToEnd(id) · ActivityChanged · QueueChanged · RequestOpened · RequestResolved
// PlanUpdated · TasksChanged · UsageUpdated · ConfigChanged · RevertStateChanged
// SessionInfoChanged · ResyncRequired(scope) · RawEvent(type, payload)
```

Design choices:

- **Upsert-by-id plus append-delta.** Protocol-specific folding lives in adapters; the shared reducer is small. This is the shape ACP v2, MSP revisions and Codex items converge on.
- **Tool normalization** is a `ToolKind` plus a typed `ToolDetail`, with the raw name and input always retained. The v1 switch on OpenCode tool names (`tool_presentation.dart` L96–311) is deleted.
- **Open unions.** Unknown events become `RawEvent` (counted in diagnostics). Unknown message types become `UnknownItem`, rendered as a neutral "unsupported item" chip. Nothing is coerced to text.
- **Raw provenance.** `RawRef{source, type, payload?}` is kept in debug builds and behind a diagnostics toggle in release.

### 4.4 Adapter boundary

```dart
abstract interface class HarnessAdapter {
  HarnessInstanceRef get ref;
  ValueListenable<LinkState> get link;
  Capabilities get capabilities;
  Stream<HostEvent> get hostEvents;                 // index changes, catalog invalidation, attention, account usage
  Future<Page<SessionSummary>> listSessions(SessionQuery q);
  Future<SessionSummary> createSession(CreateSessionInput i);    // idempotent on i.clientId
  SessionChannel open(SessionRef ref);              // ref-counted
  CatalogFacet get catalog;
  FilesFacet? get files;  TerminalFacet? get terminal;  UsageFacet? get usage;
}

abstract interface class SessionChannel {
  Stream<SessionEvent> get events;
  Future<SessionSnapshot> hydrate({HistoryCursor? before, int limit = 50});
  Future<CommandReceipt> send(PromptDraft draft, {required CommandId id});
  Future<void> interrupt();
  Future<void> respond(RequestId id, RequestResponse r);
  Future<void> setConfig(String optionId, Object? value);
  QueueFacet? get queue;  UndoFacet? get undo;  TasksFacet? get tasks;
}
```

Optional features are nullable facets. A widget asks "is there an `UndoFacet`" and reads its declared semantics; there are no methods that throw "unsupported".

### 4.5 Capabilities

```dart
final class Capabilities {
  final SessionCaps sessions;     // fork, rename, archive{native|emulated|none}, external{discover, resume, liveAttach, ownership}
  final PromptCaps prompt;        // image, pdf, maxBytes, midTurn{steer, queue, replace}, editQueued, cancelQueued
  final ApprovalCaps approvals;   // levels supported, native modes[], sandbox modes[], scopes
  final UndoCaps undo;            // conversation{stageCommit|rewind|forkOnly|none}, files{snapshot|editToolsOnly|none}, redo
  final TaskCaps tasks;           // plan{native|modelDependent|none}, subagents{childSession|inline|none}, stop, background{all|perTask|none}
  final UsageCaps usage;          // tokens, cost{actual|estimate|none}, context, quota{native|hostProbe|none}
  final FileCaps files;           // list, read, find, grep, write{stable|experimental|none}, diff
  final TerminalCaps terminal;    // pty{persistent|connectionScoped|none}, userShell
  final CatalogCaps catalog;      // models, agents, effort, commands{server|mapped|none}, skills, mentions{…}
  final Stability stability;      // per-feature: stable | experimental
}
```

Negotiation is a static per-adapter baseline intersected with runtime probes:

- OpenCode: `/api/info` version, presence of experimental routes.
- Codex: `initialize`, plus "requires experimentalApi" errors.
- Claude: `system/init.capabilities`.
- Muse: `grantedCapabilities` and schema fingerprint.
- ACP: `agentCapabilities`.

Version policy per adapter: below the tested minimum blocks with an upgrade prompt; above the tested maximum is allowed with an "untested version" chip.

### 4.6 Interaction requests

```dart
final class InteractionRequest {
  RequestId id; SessionRef session; SessionRef? origin;       // origin = child session when surfaced in a parent
  RequestKind kind;                 // permission | question | planApproval | elicitation | other
  String title; String? detail; ToolDetail? subject;
  List<RequestAction> actions;      // adapter- or server-provided, ordered
  FormSpec? form;                   // for question / elicitation
  bool autoAcceptEligible;          // false for questions, plan approvals, "requires user interaction"
}
final class RequestAction { String id; String label; ActionBehavior behavior; ActionScope? scope;
                            bool acceptsFeedback; String? scopePreview; }
```

- Actions are data. OpenCode's adapter synthesizes *Allow once*, *Always allow for this project* (shown only when `save` is non-empty, with the saved patterns), *Reject and stop*, *Reject with feedback*. The two reject behaviors differ upstream: without a message the step ends; with one the model continues **[V `plan/12` §7.4]**.
- Forms render OpenCode field types (string, number, integer, boolean, multiselect, external link, `when` conditions). The `question` kind keeps the step-per-question wizard.
- State: `open → responding → resolved{self | elsewhere | policy | expired}`. A 404 or "already settled" on reply means resolved elsewhere, not an error.

### 4.7 Approval levels (baseline semantics for D05)

| Level | OpenCode | Codex | Claude | Pi | Muse | Grok |
|---|---|---|---|---|---|---|
| Ask | reply manually | `on-request` | `default` mode | n/a | `promptUnmatched` | `default` |
| Auto-accept (default) | narrow session rules for the built-in asks (external directory, `.env` reads) plus reply `once` to any remaining request | `on-request` + daemon accepts | daemon allows in the permission callback | inherent | `allowAll` ? | `yoloMode` |
| Bypass (opt-in) | wildcard session rule | `never` + full access | `bypassPermissions` | — | `allowAll` | — |

- Auto-accept never uses `always`.
- It applies to sessions CodeWalk created or the user has prompted from CodeWalk. Observed external sessions keep their native policy until the user opts in. Codex per-turn policy overrides persist on the thread **[V `plan/20` §3.4]**, so changing them silently would alter what the terminal user gets.
- Without a daemon, auto-accept replies only while a client is connected. With the daemon, it replies when the phone is asleep.
- Whether Muse `allowAll` keeps the sandbox is **[U]**.

### 4.8 State machines

- **Link:** `idle → connecting → authenticating → hydrating → live ⇄ stale → reconnecting`. Terminal states: `needsPairing`, `incompatible`, `offline`.
- **Outbound message:** `draft → sending → admitted(steer|queue) → delivered`. A network failure is `ambiguous → retry with the same id`. A rejection restores the text to the composer. There is no content matching.
- **Session activity:** `unknown | idle | running | awaitingInput | retrying(at)`, plus `backgroundTasksRunning`. Effective activity is running while any descendant task runs.
- **Revert (OpenCode):** `none → staged → committed | cleared`. Disabled while the session runs (server returns 409).

### 4.9 OpenCode stream, hydration and ordering

- One global stream. A 45 s idle watchdog counts heartbeat comments. Reconnect backs off from 1 s to 30 s.
- On `server.connected`: fetch `/api/session/active`, then for each open session fetch session, newest message page, inbox, permissions, forms. Events arriving during hydration are buffered and applied after the snapshot, as the reference client does **[V reducer L596–611, L1404–1413]**.
- If the experimental session log is available and a last `durable.seq` is known, replay missed durable events instead of refetching **[V `plan/12` §1.4]**.
- Text in flight during a gap is rendered with a leading ellipsis until `ended` replaces it; deltas are not projected into history **[V `plan/12` §1.4 item 3]**.
- Timeline order is the server's. The only reordering is "move to end" on inbox delivery. v1's timestamp heuristics are deleted.

### 4.10 Bounded polling

| Purpose | Cadence | Invalidation / stop | Cost |
|---|---|---|---|
| Health of non-active hosts | 60 s foreground (5 min on cellular); none in background | host removed or app backgrounded | one small GET |
| Degraded mode (stream cannot be established) | open session 5 s; index 30 s | stream recovers | banner shown |
| Background shell output | 1 s cursor read while the detail view is open | `shell.exited` or view closed | one GET |
| Provider OAuth attempt | 2 s, max 5 min | attempt settles | API is poll-based by design |
| Usage pull (Claude experimental, vendor probes) | on panel open, TTL 5 min; desktop pane 20 min | new native usage event | host-side call |

No send-completion polling, no status polling while the stream is live, no WorkManager chain.

A known cost: the global stream carries deltas for every running session on the host and cannot be filtered server-side. On cellular with no running session the stream is closed when the app backgrounds.

### 4.11 CodeWalk Host Protocol (v2.1 sketch)

- WebSocket `/chp/v1`, JSON-RPC 2.0. Auth is the first message (`hello {deviceToken}`), so browsers need no custom header and tokens never appear in URLs.
- Pairing: `codewalkd pair` prints a QR with URL and one-time code; the code is exchanged for a per-device revocable token.
- Payloads are the canonical model serialized. That serialization is already exercised by the v2.0 snapshot cache.
- Every mutation carries a `commandId` (UUIDv7) and returns a receipt. The daemon maps it to native idempotency where it exists and dedupes itself where it does not.
- Each session has a sequence-numbered event log with an `epoch`. `sessions.open {afterSeq}` replays up to 2,000 events and then requires paging. The harness's own store stays the source of truth; the daemon log is a rebuildable cache.
- Approvals are events plus a `request.respond` call, first answer wins, so several clients can share a session.
- Default bind is loopback. An origin allowlist applies to browser clients. File operations are confined to registered project roots.

### 4.12 Dependencies

- Keep: `dio`, `web_socket_channel`, `provider`, `shared_preferences`, `flutter_secure_storage`, `flutter_local_notifications`, markdown/math/mermaid stack, vendored `xterm` and `tailscale`, voice packages.
- Remove: `dartz`, `get_it` (composition root only, or removed), `workmanager` unless SP4 shows it is still needed.
- Add: a deep-link package and a UUIDv7 generator; both need a maintenance check before adoption **[U]**.
- ACP in Dart: the pack conflicts. `plan/21` §8.12 and `plan/24` say none was found; `plan/30` §1.3 lists `dart_acp_sdk` 0.1.1 and others as verified on pub.dev. This plan does not need a Dart ACP client because ACP lives in the daemon.

---

## 5. UX and behavior

### 5.1 Layout

- **Mobile first, Material You.** Session list → chat, with bottom sheets for model, tasks, usage and session options.
- **Desktop and wide Web.** Navigation rail, session list pane, chat, optional utility pane (files, terminal, tasks, usage). Existing window-size-class breakpoints (ADR-013) and tabs are kept.
- **iOS.** Same Material UI, platform back gesture and safe areas. No updater, no managed install, no overlay.

### 5.2 Onboarding, pairing, auth

1. **Chooser:** "Set up on this computer" (desktop only), "Scan pairing code", "Enter address".
2. **Desktop managed OpenCode:**
   - Detect an existing v2 `opencode`; adopt it if present.
   - Otherwise download the official binary, verify SHA-256, install to the official location. Ask before replacing a v1 binary.
   - Start `opencode service` and obtain credentials through the CLI. Port and password are read, never assumed.
   - "Use from my other devices" is a separate explicit step: it changes the bind address and shows a pairing QR.
3. **Remote pairing:** scan the `opencode pair` QR, redeem the code for a 30-day token, store it in secure storage.
   - On 401 the host shows "Pairing expired".
   - Self-renewal by calling `/api/pair` with the current token is plausible but **[U]** (SP1).
4. **Compatibility check on every new host:** v2 → proceed. v1 → explainer (upgrade host or use legacy). Unreachable → transport help.
5. **Web:** states up front that the host must be HTTPS or localhost, and that OpenCode needs `opencode service set cors <origin>`.
6. **Updates:** show the host's OpenCode version and "update available" from server events. Updating restarts the service only when no session is active or the user confirms.

### 5.3 Migration from v1 (first v2 launch)

- **Import:** host profiles, credentials, appearance, shortcuts, voice settings and keys, canned answers, locale.
- **Do not import:** message caches, provider catalog, quota state.
- **Tabs, pins, drafts:** import only if session ids survive OpenCode's own v1→v2 migration **[U]**; otherwise drop with a one-line notice.
- Each imported host is probed and marked *ready*, *needs pairing*, or *still on OpenCode v1*.
- v1 keys are left untouched.

### 5.4 Sessions and external ownership

- Grouped by host and project. Children nest under parents. Filter chips per harness. Search is server-side where the harness has it.
- Row badge states: *running*, *needs you*, *background work*, *unread*. OpenCode unread uses the server's viewed/idle watermark, so it syncs across devices.
- An external session shows an origin chip and one of three verbs, taken from capabilities: **Open live**, **Continue here**, **Branch**.

### 5.5 Subagents and background tasks

- **Inline card** in the parent timeline: agent name, description, live state, elapsed time. Tap opens the child transcript.
- **Tasks tray** above the composer ("2 running"). Opens a sheet or pane listing running and recent tasks with last activity, Stop, and Open.
- **"Move to background"** appears only where supported, with its real scope: for OpenCode it is all blocking tools of the session.
- Child permission requests and forms surface in the parent with an origin badge, as the official web app does **[V `plan/12` §7.6]**.
- OpenCode's completion notice is rendered from structured metadata (`source: subagent`, `childID`, `state`), not by parsing text.
- Child transcripts are read-only unless the harness allows direct input.
- "Finished" is announced only when the root is idle, its inbox is empty, and no descendant task runs. A banner explains that OpenCode nested background work can report completion early (upstream bug #48826 **[V `plan/10` §e]**).

### 5.6 Composer

- **Send while running** defaults to steer where supported. A long-press or split button offers "Queue for after this turn". Queued items appear as chips that can be cancelled or switched.
- **Model, agent, effort** are session state. They reflect what the server reports and change when another client changes them. OpenCode switches write a timeline row, so a change is applied lazily, just before the next send.
- **`/` palette** has Commands and Skills sections, each row labelled with its source. Client built-ins appear only when the capability exists.
- **`@`** offers files, and agents where supported. OpenCode gets structured file attachments with mention ranges, which fixes v1's plain-text mentions. Symbol mentions are gone.
- **Attachments** are gated per harness and model. PDF is disabled for OpenCode v2.
- **Per-message menu** is built from `UndoCaps`. Labels state the effect: "Revert conversation and files", "Rewind files (edits made by file tools only)", "Branch from here (files unchanged)".

### 5.7 Usage, errors

- **Usage panel:** context meter, session tokens and cost (marked "estimate" where it is one), then quota windows when the harness provides them. For OpenCode in v2.0 it shows the last limit error with its window name and reset time, and nothing invented.
- **Errors** are typed: auth, quota, rate limit, content filter, network, aborted, tool failure, version. Each has one recovery action. User-initiated stops are not errors.

### 5.8 Notifications and disconnects

- **Categories:** finished, needs approval, question, error. Tap deep-links to the session.
- **Android:** an opt-in persistent "monitoring" notification while sessions run. If the system stops the service, the notification says monitoring stopped.
- **iOS and Web:** settings state that alerts arrive only while the app is open, until host push is configured.
- **Disconnect:** a banner with the cause (offline, auth, incompatible), the last-synced time, and cached content shown read-only. The composer keeps the draft and refuses to send.
- **Host process death:** sessions show "host unavailable". OpenCode's managed service resumes interrupted turns after restart **[V `plan/12` §5]**, so the app does not mark them failed on its own.

---

## 6. Rewrite / reuse / discard map

### 6.1 Keep (move, rebind to new stores)

| Area | Existing | Proposed |
|---|---|---|
| Theme, tokens, presets | `lib/presentation/theme/*` | `lib/ui/theme/` |
| Markdown, math, Mermaid, HTML subset | `chat_message_text_part.dart`, `utils/math_markdown.dart`, `basic_html_markdown.dart`, `mermaid_diagram_widget.dart` | `lib/ui/markdown/` |
| Voice (STT, TTS) | `services/speech_input_service*`, `*_model_manager*`, `read_aloud_service.dart`, `tts/*` | `lib/features/voice/` |
| Terminal view | `third_party/xterm`, `codewalk_terminal_*` | `lib/features/terminal/` (new ticket flow) |
| Transports | `core/tailscale/*`, `core/auth/oauth_*` | `lib/core/net/` decorators |
| Payload cache, logger, l10n | `data/cache/*`, `core/logging/app_logger.dart`, `core/i18n/*` | `lib/core/storage/`, `lib/core/logging/` |
| Scroll and viewport | `chat_page_scroll_coordinator.dart`, `chat_page_timeline_viewport.dart` | `lib/features/chat/timeline/`, ported with tests |
| Diff viewer, file viewer UI | `session_diff_viewer.dart`, `chat_page_file_viewer.dart` | `lib/features/files/` |
| Tabs, switcher | `app_tab_strip.dart`, `session_tab_strip.dart` | `lib/features/sessions/`, controller rewritten |
| Notifications, sounds, tray, window chrome, updater, release history | `notification_service.dart`, `sound_service.dart`, `desktop_*`, `update_check_service.dart` | `lib/features/attention/`, `lib/features/update/` |
| Drafts, canned answers, shortcuts, export, image export, forward | various | rebound to `SessionRef` and canonical items |

### 6.2 Rewrite

- Data layer and domain entities → `core/model` + `harness/opencode`.
- `ChatProvider` (22.8k) → `SessionStore` + pure reducer.
- `ChatPage` (27.5k) → composed `features/chat` widgets.
- `AppProvider` → `HostsStore` + `managed/`.
- Onboarding wizard.
- Permission and question cards → action-driven request card and generic form.
- Tool presentation.
- Model selector.
- Quota widgets.
- Session list.
- `local_opencode_server_runtime_io.dart` → service-based runtime.

### 6.3 Simplify

- Android background: one foreground-service path.
- Cellular data saver: two rules (close the stream when idle and backgrounded; lengthen health checks).
- Settings: remove the "OpenCode defaults" editor. v2 config is read-only over HTTP apart from `shell` **[V `plan/11` §3]**.

### 6.4 Defer

- Session attention overlay and Android Auto messaging (port after core; both become simpler with idempotent prompts).
- File create/rename/delete and content search (return via the daemon).
- Worktrees UI.
- MCP status.
- Provider login from the app (OpenCode `integration/*` routes exist; schedule after v2.0).

### 6.5 Discard (v1-only workarounds, inventory §3)

- Dual SSE and dedupe ring (#1).
- Send-completion watcher (#4).
- Refetch on every delta (#5, #6).
- Optimistic echo matching and `local_user_*` ids (#7).
- Synthetic abort/error messages and string-matched aborts (#8, #9).
- Busy heuristics (#10).
- Growing-limit pagination (#11).
- Global-event fallback reconciles (#12).
- Legacy route fallbacks (#15).
- Config-write deferral (#16).
- Hidden sessions for titles, file ops and quotas, including the 1,742-line JS probe (#17).
- Fake-agent selection sync (#18).
- 25-call diff scan (#19).
- Heuristic subagent resolver (#20).
- Command directory scan (#21).
- Client-side cost sums (#24).
- Unknown-part-as-text (#25).
- Share and todo UI for OpenCode.

### 6.6 Documentation and contract

| Document | Action |
|---|---|
| ADR-023 | Supersede with a v2 "harness contract-first" ADR. Reference sources become the pinned v2 docs, source and reference reducer. P-001 and P-002 are retired; client-minted ids follow the official client, so no exception is needed. |
| EXC-001 | Replace with an exception for "auto-accept ON by default": rationale, risk, per-session rollback, tests. The mechanism (`once`) matches the official clients; the default does not. |
| Other ADRs | Supersede or mark obsolete: ADR-002 (scoping key), 003, 009, 017, 018, 019, 029, 043. |
| `CONTRACT_MATRIX.md` | Per harness: route/event × used × tested × stability. |
| `ai-docs/` | Add pinned v2 snapshots. v1 docs live on the `v1` branch. |
| `BEHAVIOR.md` | Updated slice by slice as behavior ships, not ahead of it. |
| `CODEBASE.md`, `README.md` | Regenerated at v2.0. |

Any intentional divergence from an official contract found during implementation requires its own ADR exception before merge.

### 6.7 Local data, versions, rollback

- **Storage:** all v2 keys under `cw2.`, with a `cw2.schema` integer. The v1 importer is one-shot and read-only against v1 keys. The Android pre-engine purge list in `CodeWalkApplication.kt` is updated in the same change.
- **Version:** `2.0.0+<epoch+2001>` via the existing release target. The scheme reaches Android's `versionCode` ceiling (2,100,000,000) around 2036; note it, no action now.
- **Betas:** GitHub prereleases. `releases/latest` ignores them, so v1 clients are not offered betas.
- **Rollback:** during beta, uninstall and reinstall v1 (v1 data is intact because v2 never wrote to it). After GA, rollback is forward-fix; the legacy build is the escape hatch.
- **Branching:** cut `v1` at the current tag. Legacy releases come from `v1` with `make_latest: false`. `web-pages.yml` deploys from `v1` until v2.0.0.

---

## 7. Stages

### 7.1 Spikes (bounded, before or alongside M1)

| ID | Question | Pass / decision |
|---|---|---|
| SP1 | OpenCode v2 live capture on 2.0.22: fixtures for every used route/event; client-minted ids; token self-renewal; session-log behavior; `auth_token` on SSE; CORS allows `Authorization`; session `metadata` free-form (archive emulation); service on Windows; standalone-process sessions | Fixture set committed; each **[U]** resolved or downgraded to "unsupported" |
| SP2 | Web: streaming SSE through fetch in Flutter Web; mixed-content matrix; PTY WS with ticket | Deltas render incrementally in Chrome and Safari |
| SP3 | iOS: create `ios/`, `flutter build ios --no-codesign` with the full plugin set; ATS for LAN and Tailscale IPs; socket lifetime in background | Build passes; list of excluded plugins |
| SP4 | Android: foreground-service type and time limits at the current target SDK; hold the stream over embedded Tailscale; battery per hour | Service type chosen; budget recorded |
| SP5 | Daemon runtime: Bun-compiled binary on linux x64/arm64 (glibc, musl), macOS, Windows; load the Claude SDK; Codex proxy handshake; PTY | Confirms D15, or falls back to Node SEA / Dart |
| SP6 | Codex: attach through `codex app-server proxy` while the TUI runs the same thread; approval replay; behavior with no client connected | D13 level for Codex confirmed |
| SP7 | Claude: stream-json capture; resume while the TUI is open; SDK license terms | Adapter mode chosen (SDK loaded from host install vs raw protocol) |
| SP8 | Upgrade install v1.265 → v2 beta on Android with real data; cross-install with a later-built legacy APK | Importer correct; no v1 key written |

### 7.2 v2.0 milestones

Each is a vertical slice that runs against a real server.

| # | Slice | Depends on | Acceptance |
|---|---|---|---|
| M0 | Branching, CI changes, ADR drafts, fixtures folder | — | `v1` branch releasable; web deploy gated |
| M1 | Core model, host registry, OpenCode auth/pair/info, session index, history paging, generic item rendering | SP1 | Pair by QR, list all projects' sessions, open one, page history |
| M2 | Event stream, translator, reducer, send with minted id, interrupt, activity, reconnect, snapshot cache | M1 | Kill the network mid-stream; state converges with no duplicates or stuck "running" |
| M3 | Requests (levels, forms), inbox steer/queue, config options, commands, skills, mentions, attachments | M2 | **Two-adapter gate:** recorded Codex and Claude fixtures translate into the canonical model without schema changes |
| M4 | Subagents and tasks tray, shell items, compaction, revert stage/commit/clear, fork, turn diff | M3 | Background subagent visible, stoppable, completion links to child |
| M5 | Project picker, file list/find/read, experimental save (flagged), PTY, VCS status | M2 | Terminal works on desktop, Android and Web |
| M6 | Tabs, drafts, canned answers, search, export, forward, voice, shortcuts, themes, settings, l10n prune | M3 | Feature parity list signed off against inventory §2 keep/defer map |
| M7 | Android monitoring and notifications; managed OpenCode v2 on desktop; updater; Web build; iOS build | SP2–SP4 | Platform gates in §8.5 |
| M8 | v1 import, onboarding, docs, beta prereleases, 2.0.0 | all | Upgrade test passes; `make check` green; announcement text approved by the user |

**Minimum viable v2.0:** M1–M4, M7, M8, plus from M5 the project picker and file read, and from M6 drafts, themes, settings and l10n. Terminal, tabs, voice and the rest of M6 are in scope for 2.0 but may land in 2.0.x without blocking; none is deleted.

### 7.3 Later phases

- **v2.1:** daemon core (CHP, pairing, device tokens, event log, fs, attention with ntfy/webhook, usage probes, service install, headless install script) → Codex adapter → Claude adapter → client `ChpAdapter`, unified list, harness setup screens.
  - Acceptance: a Codex thread started in the TUI opens live in CodeWalk and an approval answered on the phone dismisses in the TUI.
- **v2.2:** ACP client in the daemon, Grok adapter with the `x.ai` subset in the matrix, Pi RPC adapter, experimental custom ACP agent.
- **v2.3:** Muse adapter, host PTY, file mutations and grep via daemon, UnifiedPush receiver.

---

## 8. Testing and validation

### 8.1 Contract fixtures

- `protocol/fixtures/opencode-v2/*.jsonl`: recorded SSE plus HTTP bodies with expected canonical events.
  - Scenarios: plain turn; multi-step with tools; steer and queue; permission once/always/reject with and without feedback; form reply and dismissal; foreground and background subagent; `background` call; retry then success; quota failure with Zen body; interrupt; compaction; revert stage/clear/commit; shell; model and agent switch; fork.
- A fake OpenCode v2 server replaces `test/support/mock_opencode_server.dart` and replays fixtures.
- Drift job (replaces `opencode-smoke.yml`): install the latest v2, diff live `/openapi.json` against the pin for used operations, open an issue on change.
- Codex, Claude and Muse fixtures feed translator tests from M3 onward. Muse ships golden transcripts in the pack.

### 8.2 Reducer and translator cases

- Deltas after a snapshot with a missing prefix; `ended` replaces text.
- Tool events arriving interleaved across tools.
- Retry reusing the same assistant message id.
- Inbox delivered before the HTTP response returns.
- Revert commit truncation with a skewed client clock.
- Unknown event types, unknown message types, non-finite number strings (`"Infinity"`), 16 MiB frame bound.
- Stream overflow disconnect followed by hydration with buffered events.
- Property test: any prefix of a fixture followed by reconnect and hydration equals the full replay.

### 8.3 Races and multi-client

- Two clients reply to one permission: the loser gets "resolved elsewhere".
- Rejecting one request cascades to the session's other pending requests.
- Auto-accept does not fire for questions, plan approvals or observed external sessions.
- Ambiguous send: timeout, retry with same id, single message.
- Nested background work finishing early: tasks tray still shows the orphan.
- Two hosts with identical session ids: no cache or notification cross-talk.

### 8.4 Platform cases

- **Web:** CORS preflight with `Authorization`; rejected origin; mixed-content error message; token never in a URL except the PTY ticket.
- **iOS:** background for 60 s then foreground → reconnect and hydrate; no promise of alerts.
- **Android:** monitoring service stop is surfaced.
- **Upgrade:** v1 → v2 import; v1 host detection.
- **Accessibility:** semantics on request cards and tasks tray; streaming announced on completion, not per delta; 200 % text scale; RTL (ar, ur); keyboard-only desktop flow.
- **Budgets:**
  - Reducer applies a 100 ms delta batch within one 16 ms frame on a mid-range Android device.
  - Cached session reaches first paint in under 150 ms.
  - At most 500 resident items per session.
  - Zero network activity when backgrounded with nothing running.
  - Battery and cellular byte figures recorded in SP4 become regression thresholds.

### 8.5 Commands and gates

Focused, while iterating:

```
export PATH="$HOME/flutter/bin:$PATH"
flutter test test/unit/core test/unit/harness/opencode test/contract/opencode_v2
flutter test test/widget/chat
```

Gates:

| Gate | Command | Where |
|---|---|---|
| Full check | `make check` | Any host incl. ARM64; at validation gates only |
| Web tests | `make test-web` | CI |
| Web build | `flutter build web --release` | CI |
| Desktop builds | `flutter build linux|windows|macos` | Matching runners |
| Android APK | `make android` | GitHub Actions x64 runner; not ARM64 Linux |
| iOS | `flutter build ios --no-codesign` | macOS runner |
| Daemon (v2.1) | `bun test`, `bunx tsc --noEmit`, compile matrix | CI |

`make precommit` is not used directly. Reset the analyze budget (currently 337) downward as v1 code is deleted. Code review happens after each coherent milestone, not for this plan.

---

## 9. Risks, assumptions, open questions, sources, start

### 9.1 Risks and mitigations

| Risk | Mitigation |
|---|---|
| OpenCode v2 API is labelled experimental and ships near-daily | Pinned fixtures, drift job, tolerant decoders, min/max tested version policy |
| Canonical model fits only OpenCode | Two-adapter gate at M3 |
| v1 users stranded by the automatic update | In-app v1-host detection, legacy build, R1 |
| Auto-accept is remote code execution by design | Scoped to owned sessions, `once` only, bypass opt-in, disclosure at onboarding, always-on host auth |
| Codex protocol changes weekly; daemon version differs from CLI | Negotiate against the daemon, regenerate schema, experimental features individually detected |
| Anthropic policy changes (four times in 2026) | User logs in on the host; no token handling; API-key mode documented; plain-text naming only |
| Stuck "running" and lost events (seen across comparable products) | Activity derived from execution events plus `/session/active` on every hydrate |
| Rewrite loses scroll and viewport polish | Port the coordinator and its tests rather than rewrite |
| Dual licensing (AGPL plus commercial) versus Codex "local or open-source" terms and a proprietary Claude SDK | Legal check before v2.1; adapter can load the SDK from the host or use the raw protocol |

### 9.2 Assumptions and fallbacks

- **The experimental session log stays available.** If not, hydration falls back to snapshots; this is already the baseline path.
- **Bun-compiled binaries work on all desktop targets.** If not, ship the npm package requiring Node 22, or switch the daemon to Dart with raw protocols.
- **`dart:io` and browser streaming handle SSE as expected on Web.** If not, Web uses degraded polling with a banner.

### 9.3 Unresolved

| # | Question | Why unverified | If false |
|---|---|---|---|
| U-01 | Token-authenticated clients can create pairing codes (self-renewal) | Inferred from "accepted anywhere the password is" | Re-pair every 30 days or store the password |
| U-02 | OpenCode session `metadata` is free-form and preserved | Schema seen, semantics not | Archive is a local per-device list |
| U-03 | Session ids survive OpenCode's v1→v2 migration | Not in the pack | Tabs, pins and drafts are not imported |
| U-04 | `opencode service` works on Windows | Not in the pack | Windows managed mode uses `serve --stdio` under the app |
| U-05 | Behavior when the service prompts a session that a standalone process is running | Process-local execution noted; conflict not tested | Warn on sessions updated recently by another process |
| U-06 | Codex approval with no client connected: waits or times out | Listed open in `plan/20` §9 | Daemon stays subscribed to all loaded threads |
| U-07 | Claude Agent SDK may be redistributed inside an AGPL binary | No licence text in the pack | Load from a host install or use raw stream-json |
| U-08 | Muse `allowAll` keeps the sandbox | Docs describe CLI flags, not MSP | Label it Bypass, not Auto-accept |
| U-09 | iOS ATS allows HTTP to LAN and Tailscale IPs under local-networking exceptions | Platform detail not checked | Require HTTPS on iOS or request a broader exception |
| U-10 | What v1 clients display about a pending update | Not inspected | The v2.0.0 announcement cannot warn v1 users in-app |
| U-11 | Android foreground-service time limits at the current target SDK | From platform knowledge, not checked against this build | Shorter monitoring windows; rely on host push |

### 9.4 Sources

- **Local dossiers:**
  - `plan/00` §2–§5
  - `plan/10`
  - `plan/11` §1, §A6–A7, §A10, §3, §D, §E
  - `plan/12` §1–§11
  - `plan/13` §0, §5–§9
  - `plan/20` §0–§4, §6–§9
  - `plan/21` §0–§9
  - `plan/22`, `plan/23`, `plan/24`, `plan/25`
  - `plan/30` §0–§2, §13–§17
  - `plan/31` §0–§6, §15.6, §16–§18
- **Raw source:** `plan/opencode-v2-src/client-solid-data.reference-reducer.ts` (L593–632, L1380–1470); `schema/session.ts`.
- **Repo:**
  - `ADR.md` L1103–1255
  - `Makefile` L8–25, L244–292, L418–452
  - `pubspec.yaml` L19
  - `.github/workflows/{ci,release,web-pages}.yml`
  - `lib/presentation/services/update_check_service.dart`
  - `AGENTS.md` L36–83
  - `LICENSE`, `LICENSE-COMMERCIAL.md`
  - `macos/Runner/Release.entitlements`
- **Official references named in the dossiers:** `opencode.ai/v2/docs`, `github.com/anomalyco/opencode` (branch `v2`), `learn.chatgpt.com/docs/app-server`, `code.claude.com/docs/en/agent-sdk/*`, `agentclientprotocol.com`.

### 9.5 Execution start

Strict prerequisites:

1. User decisions on R1 and R2. They change M0 and M3.
2. Signing key continuity confirmed.
3. An OpenCode 2.0.22 host available for SP1.

First actions, in order:

1. Create the `v1` branch from the v1.265.0 tag. Set `make_latest: false` and the v1 tag filter in its release workflow. Point `web-pages.yml` at `v1`.
2. Move `plan/` research under version control as `docs/v2/research/`. Draft the superseding ADRs listed in §6.6.
3. Run SP1 and commit `protocol/fixtures/opencode-v2/`.
4. Create `lib/core/model/`, `lib/core/reduce/`, `lib/harness/opencode/wire/` and the fake v2 server under `test/support/`.
5. First green test: `flutter test test/unit/harness/opencode/translator_plain_turn_test.dart`, replaying the plain-turn fixture into the reducer.
6. Start SP2, SP3, SP4 and SP8 in parallel with M1. Run SP5–SP7 before M3 so the two-adapter gate has real fixtures.