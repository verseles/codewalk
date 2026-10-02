# CodeWalk v2 — Independent Implementation Plan

**Snapshot:** 2026-10-02 · repo `14fbf519` (post v1.265.0) · planning only, nothing modified, no builds or tests run.
**Evidence tags:** **[V]** verified in the research pack or local source (path given) · **[I]** inferred from verified facts · **[U]** unverified, needs the named spike.

---

## 1. Status, objective, recommendation, final behavior

### 1.1 Status and blockers

- No blocker prevents starting v2.0 (OpenCode v2 only).
- External prerequisites:
  - A host running OpenCode ≥ 2.0.21 for the contract-capture spike.
  - An Apple Developer Program membership plus a macOS runner before any iOS distribution.
  - A decision on the items in §2.2 before the v2.1 host daemon work starts.
- Four facts found during inspection change how baseline decisions must be executed:
  1. **The v1 updater will offer v2 to every v1 user with no guard.** `lib/presentation/services/update_check_service.dart:161-191` reads GitHub `releases/latest`, compares semver, and takes the first `.apk`. `install.sh:92` does the same for desktop. [V]
  2. **A later legacy v1 APK would install over v2 as an upgrade.** Android build codes are `date +%s + offset` (`Makefile:21-25`), so a v1 maintenance build made after v2.0.0 has the higher `versionCode`. [V]
  3. **v1's allow-all reply is unsafe on v2.** v1 replies `always` (ADR-023 EXC-001, `ADR.md:1213-1255`). In v2, `always` persists a project-wide approval for all sessions, usually for `*` (`plan/12 §7.3–7.4`). [V]
  4. **Allow-all default ON plus external sessions (D13) means CodeWalk would auto-approve prompts for sessions the user is driving in a terminal**, simply by being connected. The global event stream delivers every session's `permission.asked` (`plan/12 §1.1`). [V]

### 1.2 Objective

Replace the OpenCode-v1-shaped client with a harness-neutral client whose first and best-supported harness is OpenCode v2, then add other harnesses through one optional host daemon. No harness is made to impersonate another.

### 1.3 Architectural recommendation

**Hybrid, with exactly two client-side adapters.**

1. **OpenCode v2: direct to the official server** (`/api/*` over HTTP, global SSE, PTY WebSocket). No CodeWalk host component. This is all of v2.0.
2. **Everything else: one optional CodeWalk host daemon, `codewalkd`**, written in TypeScript on Node. It owns the stdio and Unix-socket harnesses (Codex shared daemon, Claude Code, Pi, Muse, and all ACP agents including Grok Build and `dsh`). It normalizes them into one sequenced "CodeWalk Host Protocol" over an authenticated WebSocket.
3. **OpenCode is never proxied through `codewalkd`.** The daemon may optionally watch the local OpenCode service to send notifications; it does not sit in the chat data path.

Why this shape:

- OpenCode v2 is the only named harness with an official, authenticated, network-reachable, multi-client server. [V `plan/11 §1`]
- Five harnesses are stdio- or UDS-only, and Grok's WebSocket server has no TLS. Every shipping multi-harness mobile product puts a process on the host. [V `plan/31 §17.1`]
- Normalizing in the daemon keeps weekly and daily upstream churn (Codex, Claude) out of six client platforms and App Store review.
- TypeScript is where the official SDKs are: Claude Agent SDK, `@muse-code/sdk`, Pi `RpcClient`, `@agentclientprotocol/sdk`, and Codex `generate-ts`.

### 1.4 Intended final behavior

- **One app, a list of Hosts.** A Host has an OpenCode endpoint, a `codewalkd` endpoint, or both. Sessions from all harnesses on a host appear in one list grouped by project directory, each with a harness badge.
- **Creating a session asks for the harness** (remembered per project). The composer, toolbar, and menus render only what that harness's capabilities declare.
- **Sessions started in a terminal are listed.** Each shows exactly one honest label: *Live* (attach and co-drive), *Resume* (history plus continue when idle), *Fork to continue*, or *History unavailable*.
- **Streaming is event-driven.** There is no send watcher, no content-matched echo, no per-delta refetch, and no heuristic busy state. Reconnect performs one bounded snapshot resync.
- **Approvals show the harness's real choices and scopes.** Allow-all is ON by default only for sessions CodeWalk created or the user opted in.
- **Background subagents and shells appear in a persistent Background Work tray** with per-task stop. Child sessions are navigable.
- **Usage shows three separate things**, each only when a source exists: context window, session spend, and plan-limit windows.
- **Notifications make no promise the platform cannot keep.** iOS and Web say so in Settings.

---

## 2. Decision assessment (D01–D16)

### 2.1 Table

| ID | Verdict | Evidence and argument | Alternative and trade-off | Confidence | Verification |
|---|---|---|---|---|---|
| **D01** connection architecture (open) | **Recommend hybrid** (§1.3) | OpenCode has an official authenticated server with pairing [V `plan/11 §1.2`]. The Codex shared daemon is UDS-only and a separate `--listen ws://` process is not the shared daemon [V `plan/20 §2.3, §4.1`]. Claude has no third-party network surface [V `plan/21 §4`]. Pi, Muse, and dsh are stdio-only [V `plan/22–25`]. | **Universal daemon**: one client adapter, uniform replay and push. Cost: OpenCode-only users must install CodeWalk software on the host, double translation of the richest contract, weaker contract-first guarantee. **No daemon**: SSH plus `codex app-server proxy` for Codex and direct Grok WS. Cost: no Claude, Pi, or Muse at all; no Web for Codex (Origin → 403). | High | Spikes S4 and S5 prove the daemon can attach to the Codex shared daemon on Linux, macOS, and Windows. |
| **D02** rollout (open) | **Recommend** v2.0 OpenCode → v2.1 `codewalkd` + Codex + Claude → v2.2 ACP family (Grok first-class, generic ACP experimental incl. dsh) + Pi → v2.3 Muse | OpenCode alone is a full rewrite (OpenChamber's cutover was +38k/−33k lines [V `plan/31 §2.2`]). Codex and Claude are the D13-essential harnesses. Grok and dsh share one ACP adapter. Muse is closed-source, two months old, and account-gated [V `plan/23`]. dsh is a breaking-change preview whose own dossier says defer [V `plan/25`]. | Ship Claude before Codex (larger audience, higher policy and churn risk). Ship all harnesses in v2.0 (delays OpenCode v2 users by months). | Medium-high | Re-rank v2.2/v2.3 against user demand after v2.1. |
| **D03** rewrite, same repo, `v1` branch | **Keep** | 83% of 158k LOC is presentation with wire types leaking in. `ChatProvider` and `ChatPage` are single classes split by `part of` [V `plan/00 §0, §5.2`]. Most v1 realtime code compensates for gaps v2 closes [V `plan/00 §3`]. | Incremental refactor in place: reviewable diffs, but drags 25 workarounds through a different protocol. | High | — |
| **D04** same app ID, v2 replaces v1 via updater | **Keep, with four mandatory mitigations** | Finding 1 and finding 2 in §1.1. Also, GitHub marks a newly published release as "latest" by default, so a later v1 maintenance release could become `releases/latest` [U]. | Reconsider the rejected final-v1 updater guard (see §2.2). | High on the facts | Confirm GitHub `make_latest` default; dry-run both release workflows on a fork. |
| **D05** allow-all ON by default | **Keep the default; change the mechanism and scope** | See §4.7. `always` is project-wide in v2 [V]. A server-side `*:*:allow` session rule overrides agent `deny` rules and is inherited by subagents [V `plan/12 §7.5`]. Official clients auto-reply `once` [V same]. External-session hazard is finding 4. | Literal baseline (server-side rule whenever supported): works with the app closed, but silently defeats `plan`/`explore` agent restrictions. | High | S1 captures deny-rule and subagent behavior under both mechanisms. |
| **D06** native usage + experimental host-side vendor queries | **Keep, with two constraints** | No quota endpoint in OpenCode v2 [V `plan/11 §D`]. Codex, Claude, and Muse expose native windows [V]. v1 wrote refreshed tokens back to host files [V `plan/00 §2.10`]. Anthropic forbids collecting or intermediating claude.ai credentials [V `plan/21 §6`]. | Drop vendor queries entirely: simplest and policy-safe, loses plan windows for OpenCode-routed subscriptions. | Medium | Recheck Anthropic policy text at v2.1 start. |
| **D07** notifications (open) | **Recommend three tiers** (§5.8): live in-app everywhere in v2.0; one Android background monitor in v2.0; host-originated push through a user-chosen notifier (ntfy/UnifiedPush/webhook) from `codewalkd` in v2.1. Native APNs/FCM is deferred because it needs a CodeWalk-operated push gateway. | No harness offers push [V `plan/31 §17`]. D08 excludes a hosted relay. v1 runs three overlapping Android detectors [V `plan/00 §3 #23`]. | CodeWalk-operated push gateway carrying opaque wake-ups only: real iOS push, but a hosted service with credentials and uptime duty. | Medium | S3 measures iOS suspension behavior; a v2.1 spike measures ntfy delivery latency. |
| **D08** user-managed network | **Keep** | Matches official Codex and OpenCode guidance (VPN/mesh/TLS proxy) [V `plan/20 §4.1`]. | Self-hostable E2EE relay later, never CodeWalk-hosted by default. | High | — |
| **D09** six targets | **Keep, with tiers** | iOS has no `ios/` directory today [V `plan/00 §1.1`]. Vendored Tailscale supports iOS but not Windows [V `third_party/tailscale/README.md:224-228`]. Web cannot reach `http://` LAN hosts from an HTTPS origin, and Codex rejects any `Origin` [V]. | Drop Web: saves transport work but loses a shipped target. | High on constraints | S2 (Web) and S3 (iOS). |
| **D10** managed OpenCode: official binary + SHA-256 + `opencode service` | **Keep, with caveats** | Binaries and sha256 come from the update API [V `plan/11 §E.1`], which is undocumented [V `plan/10 §a`]. The hash and binary share an origin, so it proves integrity, not authenticity [I]. v2 installs to the same `~/.opencode/bin` as v1 and migrates the shared DB [V `plan/11 §E.2, E.4`]. | Run the official install script instead: fully official path, less control over pinning. | Medium-high | S1: CLI output formats, v1 coexistence behavior. |
| **D11** desktop installs/updates daemon and harnesses | **Keep for install; change "updates" to "detect and offer"** | Codex's daemon, Claude Code, and OpenCode already self-update [V `plan/20 §2.3`, `plan/21 §5`, `plan/11 §E.3`]. A second updater fights them and creates version skew. Headless hosts have no desktop app, so a CLI install path is required. | CodeWalk pins and force-updates every harness: predictable versions, high breakage and trust cost. | Medium | — |
| **D12** English | **Keep** | Product preference. | — | — | — |
| **D13** external sessions (essential) | **Keep; scope per harness** (§3.3) | OpenCode shared service and Codex shared daemon support true live attach [V]. Claude supports discovery and resume, not live attach [V `plan/21 §3.6`]. | Tail Claude JSONL for read-only live view (Happy does this, at 20–40% CPU in one report [V `plan/31 §3.4`]): defer. | High for OpenCode/Codex, medium for Claude | S5, S6. |
| **D14** unified list, badges, capability gating | **Keep** | Matches the canonical-model pattern in every multi-harness product [V `plan/31 §17`]. | Per-harness tabs: simpler, worse for multi-harness projects. | High | — |
| **D15** daemon runtime (open) | **Recommend TypeScript on Node ≥ 22**, npm-distributed; single-binary packaging evaluated in S4 | Official TS SDKs exist for Claude, Muse, Pi, and ACP; Codex emits TS types [V]. Raw Claude stream-json is "semi-public and version-sensitive" [V `plan/21 §0.4`]. | **Dart AOT**: shares model code with the app, but must re-implement the Claude SDK. **Go/Rust**: best single binary, no vendor SDKs. | Medium-high | S4. |
| **D16** helper process | **Process-only** | No technical bearing. | — | — | — |

### 2.2 Changes I recommend the user reconsider

These are proposals. The baseline plan below does not silently adopt any that contradict a recorded answer; where it deviates, the stage is labeled.

1. **D05 mechanism (consequential).** Use client or daemon auto-reply as the default allow-all mechanism and make the server-side session rule an explicit opt-in "Unattended" level. Scope the default to sessions CodeWalk created.
   - Effect: plan/explore agent restrictions keep working, and terminal sessions are not auto-approved by a phone in a pocket.
   - Cost: with the app closed, OpenCode prompts wait. This is rare, because the default OpenCode policy only asks for external directories and `.env` reads [V `plan/12 §7.2`].
2. **D04 guard (moderate).** Either ship one final v1 release with an updater guard, or accept the zero-code substitute: put the compatibility warning in the v2.0.0 release announcement line, which the v1 update UI already renders (`update_check_service.dart:72-111`).
   - The plan uses the substitute so it stays inside the recorded answer.
3. **D11 updates (moderate).** CodeWalk installs harnesses on request but leaves updating to each harness's own updater, and only reports version and compatibility.
4. **D06 scope (small).** Run host-side vendor usage queries only inside `codewalkd` (v2.1), read-only, never for Anthropic credentials. In v2.0, OpenCode shows cost, tokens, context, and parsed limit errors only.
5. **D07 iOS push (decision needed later).** Real push on iOS with the app terminated requires either the ntfy app as intermediary or a CodeWalk-operated gateway. The second contradicts the spirit of D08.

---

## 3. Capability matrix

### 3.1 Legend and pins

- **N** native and stable upstream · **Nx** native but labelled experimental upstream · **V** vendor extension · **H** supplied by `codewalkd` host services, not the harness · **C** CodeWalk client convention · **P** partial · **—** not available.

| Harness | Surface used | Pinned evidence | Reachability | CodeWalk path |
|---|---|---|---|---|
| OpenCode v2 | `/api/*` HTTP, SSE, PTY WS | 2.0.21 `8a8bd622`; npm 2.0.22 | Network, Basic auth, pairing | Direct |
| Codex | app-server v2 JSON-RPC on the shared daemon | CLI 0.159.3 schema; daemon 0.160.0 | Local UDS only | `codewalkd` |
| Claude Code | TS Agent SDK streaming input | SDK 0.3.287 / CLI 2.1.287 | None (stdio) | `codewalkd` |
| Pi | `pi --mode rpc` JSONL | 1.0.0 | None (stdio) | `codewalkd` |
| Muse Code | MSP v1 via `muse serve` | 1.4.2 | None (stdio) | `codewalkd` |
| Grok Build | ACP v1 + `x.ai/*` | 1.0.46 | `ws://` + shared secret, no TLS | `codewalkd` (ACP adapter) |
| dsh | ACP v1 stdio profile | 0.2.0-rc.2 | None (stdio) | `codewalkd` generic ACP, experimental |

### 3.2 Sessions and external ownership

| Capability | OpenCode | Codex | Claude | Pi | Muse | Grok | dsh |
|---|---|---|---|---|---|---|---|
| List | N (cursor, all projects) | N `thread/list` | N `listSessions` | H (reads session dir) | N | N | N |
| Create / rename | N / N | N / N | N / N | N / N | N / N | N / V | N / — |
| Resume with history | N | N | N | N | N (cursor) | N (replays `updates.jsonl`) | **P: no replay** |
| Live attach to a terminal session | **N** (shared service) | **N** (shared daemon; pending approvals replayed) | **—** | — | P (leases; `sessionInUse`) | P (`--leader`/`serve`) [U] | — |
| Fork | N (`before` message) | N (`beforeTurnId`) | N (`upToMessageId`) | N (entry) | N (`cutPoint`) | V | — |
| Archive | **C** via native `metadata` | N (cascades) | H (daemon-local) | H | H | H | H |
| Delete | N (cascades) | N (cascades) | N | H (file) | N | V | — |
| Multi-client reply race | N (`permission.replied`) | N (`serverRequest/resolved`) | H (daemon is sole owner) | n/a | N (`approvalAlreadyResolved`) | [U] | n/a |

### 3.3 External-session behavior (D13), stated exactly

| Harness | Discovery | What "continue" means | Label shown |
|---|---|---|---|
| OpenCode | All sessions in the shared service. | Same session, live, concurrently with the TUI. Either client may prompt, reply, or interrupt. | **Live** |
| OpenCode `--standalone` or service disabled | [U] whether another process's sessions appear and update. | Unknown. | Decided by spike S1 |
| Codex (TUI on shared daemon, default since 0.157) | `thread/list` (cli + vscode sources) and `thread/loaded/list`. | `thread/resume` rejoins the running thread and replays pending approvals. | **Live** |
| Codex `--no-daemon` or older CLI | History in `thread/list`. | Loads the thread in the daemon; concurrent use with a private process is unverified [U]. | **Resume** when idle; otherwise **Fork to continue** |
| Claude | `listSessions()` reads transcripts, including TUI sessions. | A new process resumes the same transcript. No attach to a running TUI. | **Resume** if not modified in the last 2 minutes and startup does not report `session_held_by_background`; otherwise **Fork to continue** |
| Pi | Daemon reads the session directory. | `switch_session`; no concurrency protection. | **Resume** / **Fork** |
| Muse | `session/list`. | `session/resume`; a held lease returns `sessionInUse`. | **Resume**, or **In use elsewhere → Fork** |
| Grok | `session/list`. | `session/load` replays history. | **Resume** |
| dsh | `session/list`. | `session/resume` restores state but replays nothing. | **Continue (history unavailable)** |

Claude SDK sessions are tagged `sdk-ts` and hidden from the terminal `/resume` picker by default [V `plan/21 §3.6`]. CodeWalk does not override the entrypoint; the session screen says "Started in CodeWalk; not shown in the terminal resume list".

### 3.4 Turns, interactions, tasks

| Capability | OpenCode | Codex | Claude | Pi | Muse | Grok | dsh |
|---|---|---|---|---|---|---|---|
| Text / reasoning stream | N / N | N / N | N / N (main thread only) | N / N | N / N | N / N | P (committed chunks) |
| Tool output stream | N (`tool.progress`) | N | P (30 s heartbeats) | N | N | N | P |
| Steer mid-turn | N (default) | N | N (folds at tool boundary; `priority: now`) | N | N | V `x.ai/interject` | — |
| Queue for next turn | N | Nx | N | N | N (default) | V | — |
| Edit / cancel queued | N | Nx | P (raw control only) | N (`clear_queue`) | N (`turn/unqueue`) | V | — |
| Interrupt | N | N | N (known race bug on 2.1.286) | N | N (with retract) | N | N |
| Retry visibility | N | N (`willRetry`) | N | N | N | V | — |
| Approval choices | once / always (project) / reject (+feedback) | accept / session / decline / cancel / policy amendment | allow / deny / edit input / rule suggestions | **—** (no permission system) | server-minted choices | allow/reject × once/always | allow / reject once |
| Native allow-all | Session rule (overrides deny) | `approvalPolicy: never` | `bypassPermissions` | inherent | `allowAll` mode | `yoloMode` | — |
| Sandbox control | — | N (read-only / workspace-write / full) | — | — | N (profiles) | P (`--sandbox`) | P |
| Questions / forms | N (Forms) | Nx | N (AskUserQuestion) | — | N | V | — |
| Agent task list | **—** (removed) | N (`turn/plan/updated`) | P (model-dependent) | — | N | N (`plan`) | — |
| Plan mode | N (`plan` agent) | Nx | N | — | — | N | — |
| Subagent child sessions | N | N | P (tasks + transcripts) | — | N | V | — |
| Background run / per-task stop | N / N (interrupt child) | P / N | N / N | — | N / N | V / [U] | — |
| Move running work to background | N (whole session only) | — | N | — | N | — | — |

### 3.5 Composer, tools, usage

| Capability | OpenCode | Codex | Claude | Pi | Muse | Grok | dsh |
|---|---|---|---|---|---|---|---|
| Slash commands | N (list + run) | **C** (no server registry) | N (send `/name`) | N (`get_commands`) | — (skills only) | N | — |
| Skills | N (list; structured attach) | N (`$name` + item) | N (`/skill`) | N (`/skill:name`) | N (input part) | V | — |
| `@file` | N (structured, line ranges) | P (path text; fuzzy search N) | P (text; search H) | P (text; search H) | P (text; search H) | N/V | P (`resource_link`) |
| `@agent` | N | — | — | — | — | — | — |
| Images | N | N (data URL or host path) | N | N | N | N (unadvertised) | P |
| PDF | **—** ("PDF not sent") | — | N (document blocks) | — | — | — | — |
| File browse / read / find | N | N | H (+ native `readFile`) | H | H | V | H |
| File write | **Nx** (`experimental/fs/write`) | N | H | H | H | V | H |
| Content search | — | — | H | H | H | V | H |
| Terminal (PTY) | N | N (connection-scoped) | — | — | — | V | — |
| One-shot shell (`!`) | N | N (unsandboxed) | — [U] | N | N | V | — |
| Diff of changes | N (per turn) | N | P (per edit; repo diff H) | H | N (`patchRef`) | V | H |
| Undo files | N (staged revert, needs git) | **—** | P (Write/Edit only) | — | — | — | — |
| Undo conversation | N (staged, redo before commit) | fork only | fork only | fork only | fork only | V rewind (files untouched) | — |
| Redo | N (clear staged revert) | — | — | — | — | — | — |
| Tokens / cost | N / N | N / — | N / estimate | N / N | N / estimate | N / N | P / — |
| Context meter | N (model limit) | N | N | N | N | N | P |
| Plan quota windows | **—** (limit name only inside error body) | N | N (push) + Nx (pull) | — | N | V [U] | — |
| Model / effort | N / N (variant) | N / N | N / N | N / N | N / N | N / N | N / N |
| Agent or mode selector | N (agents) | P (modes Nx) | N (agent + permission mode) | — | — | P (modes) | — |

Three distinctions the UI must never blur:

- **Resume** (history) vs **Live** (co-drive).
- **Undo files** vs **Branch conversation** vs **Rewind conversation without touching files**.
- **Approval policy** (who is asked) vs **sandbox** (what is possible) vs **allow-all** (CodeWalk answering on the user's behalf).

---

## 4. Architecture and interfaces

### 4.1 Layout

```
lib/
  app/        bootstrap, DI (get_it), shell, lifecycle, deep links
  core/       logging, storage, http/sse/ws clients, tailscale, oauth, i18n bridge
  domain/     pure Dart: ids, host, session, timeline, interactions, usage,
              capabilities, catalog, errors, events, harness_adapter (the port)
  harness/
    opencode/ api, dto, sse_decoder, projector, auth (basic/pair/renew),
              tool_mapper, capabilities      ← only place that knows OpenCode wire
    host/     codewalkd client: ws, protocol codec, adapter           (v2.1)
    fake/     scripted adapter for tests and the demo/tour
  state/      connection_manager, session_store, session_list_store,
              interaction_center, approval_policy, outbox, attention_monitor,
              catalog_cache, selection_store
  features/   onboarding, hosts, sessions, chat/{timeline,composer,interactions,
              background}, files, terminal, usage, settings, voice, tabs
  platform/   android background, tray, window chrome, updater, managed install
host/         codewalkd (TypeScript): server, auth, log, protocol,
              adapters/{codex,claude,acp,pi,muse}, services/{fs,git,notify,usage}
contracts/    opencode/{openapi-2.0.21.json, used-operations.yaml, fixtures/}
              host-protocol/{schema.json, fixtures/}; codex/, claude/ fixtures
```

Boundaries are enforced by `test/architecture/import_boundaries_test.dart`:

- `features/` may not import `harness/**` or `core/network`.
- `domain/` may not import Flutter.
- `harness/x` may not import `harness/y`.
- No `part of` class splitting; no Dart file over 1,500 lines.
- No harness-name comparisons in `features/`. UI branches on capabilities only.

Dependencies: keep `provider`, `get_it`, `dio`, `web_socket_channel`, and the existing rendering, voice, and platform packages. Remove `dartz` (use a sealed `Result`). Add no state-management framework; the v1 problem was structure, not the library. Add no ACP Dart package: the community packages are 0.x (`dart_acp_sdk` 0.1.1, `acp_dart` 0.5.0) [V `plan/30 §1.3`], and ACP runs in the daemon on the official TS SDK instead.

### 4.2 Identity and storage

```dart
extension type HostId(String v) {}          // local UUID per host profile
extension type HarnessId(String v) {}       // 'opencode' | 'codex' | 'claude' | 'pi' | 'muse' | 'grok' | 'acp:<agent>'
class SessionRef { final HostId host; final HarnessId harness; final String nativeId; }
class ProjectRef { final HostId host; final String directory; }   // host-canonical absolute path
```

- A **Host** is a machine the user reaches. It holds up to two endpoints: an OpenCode URL and a `codewalkd` URL. Credentials are per endpoint in secure storage.
- **Project grouping key** is the directory. For OpenCode use the project's canonical directory plus `subpath`; for others use the session `cwd`. Sessions from different harnesses in the same directory share one group.
- `SessionRef` is the only key used in tabs, drafts, pins, notifications, and deep links. Collisions between harnesses are impossible by construction.
- **Local storage** reuses the existing guarded prefs and file-backed payload store (ADR-016), under a new `cw2.` namespace. v1 keys are read once for import and never written (§6.4).

### 4.3 Canonical model

A session is a flat, ordered **timeline of items** plus session-level state. This sits between OpenCode's flat message list and the thread → turn → item shape of Codex and Muse.

```dart
sealed class TimelineItem { String get id; String? get turnId; ItemStatus get status; RawRef? get raw; }
// UserMessage(text, attachments, mentions, delivery, outboxState)
// AssistantText(text, complete) · Reasoning(text, complete)
// ToolCall(kind, title, input, output, detail, childSession?, background)
//   kind: shell|read|edit|write|search|fetch|subagent|mcp|skill|question|other
//   detail: ShellDetail|EditDetail(diff)|SearchDetail|… ; raw input/output always kept
// UserShell(command, output, exit) · Compaction(status, summary)
// Notice(level, text, source)       // synthetic/system rows, subagent completion
// SelectionChange(agent|model)      · TurnEnd(outcome, error?)
// Unsupported(kind, fallbackText)   // never rendered as plain text

class SessionState {
  SessionInfo info;                 // title, parent, project, times, unread, origin
  Activity activity;                // idle|running|waitingApproval|waitingInput|retrying(at,attempt)
  bool stale;                       // true while disconnected: "last known"
  List<TimelineItem> timeline;      // resident window
  List<PendingInput> queue;         // server-held steer/queue items
  List<BackgroundTask> tasks;       // running subagents/shells
  PlanState? plan; RevertState? revert;
  Selection selection; SessionUsage usage; ApprovalLevel approvalLevel;
}
```

Adapters emit canonical events; one harness-agnostic reducer folds them:

```dart
sealed class HarnessEvent { SessionRef? get session; RawRef? get raw; }
// SessionUpserted · SessionRemoved
// ItemUpserted(item)        // authoritative, idempotent by item id
// ItemDelta(itemId, field, text)   // ephemeral append; ignored once item is complete
// TimelineTruncated(fromItemId) · TimelineSnapshot(items, hasOlder)
// ActivityChanged · QueueChanged(full set) · TasksChanged(full set) · PlanUpdated
// InteractionOpened(request) · InteractionResolved(id, outcome, by)
// SelectionChanged · UsageUpdated · QuotaUpdated(scope, windows) · RevertChanged
// CatalogInvalidated(kind) · HostNotice
```

Reducer invariants (they replace ADR-023 P-001/P-002 and ADR-041):

1. `ItemUpserted` is keyed by id and is idempotent. A complete item never regresses to incomplete.
2. `ItemDelta` on a complete or unknown item is dropped.
3. Level-set events (`QueueChanged`, `TasksChanged`) replace; they are never merged.
4. Unknown wire events are counted in diagnostics and ignored. Unknown item kinds become `Unsupported`.
5. `raw` provenance (`{source, type, id}` plus a bounded payload in debug logging) travels with every item for the details dialog and bug reports.

### 4.4 The adapter port

```dart
abstract interface class HarnessAdapter {
  HarnessDescriptor get descriptor;                 // id, name, version, stability
  ValueListenable<AdapterConnection> get connection;
  ValueListenable<HarnessCapabilities> get capabilities;
  Stream<HarnessEvent> get events;
  Future<void> connect(); Future<void> dispose();

  SessionsFacet get sessions;      // list(page), get, create, rename, delete, open(ref)→snapshot
  TurnsFacet get turns;            // send(op), interrupt, queue ops
  InteractionsFacet get interactions;   // pending(session), reply
  CatalogFacet get catalog;        // models, agents, modes, commands, skills
  FilesFacet? get files; TerminalFacet? get terminal; UndoFacet? get undo;
  BackgroundFacet? get background; UsageFacet? get usage; PolicyFacet? get policy;
}
```

Optional facets are `null` when absent, so a missing feature is a compile-visible branch.

Capabilities are an immutable value built from static per-adapter defaults and refined at handshake (version, experimental flags, admin constraints). They are enums wherever semantics differ:

```dart
class HarnessCapabilities {
  final ExternalAttach externalAttach;   // live | resumeOnly | forkOnly | noHistory
  final Set<Delivery> deliveries;        // steer, queue
  final QueueControl queue;              // none | cancel | cancelAndEdit
  final UndoKind undo;                   // none | stagedRevert | rewindFiles | branchOnly
  final bool redo, taskList, planMode, forms, childSessions, backgroundTasks;
  final AllowAllMechanism allowAll;      // clientReply | nativePolicy | inherent | none
  final List<PolicyPreset> policyPresets;      // harness-native, labelled
  final AttachmentCaps attachments;      // images, pdf, files, maxBytes
  final FileCaps files;                  // browse, read, find, grep, write(experimental?)
  final bool terminal, shellMode, skills, commands, agentMention;
  final UsageCaps usage;                 // tokens, cost, context, quotaWindows
  final Set<String> experimentalInUse;   // surfaced in Settings › Diagnostics
}
```

### 4.5 OpenCode v2 adapter

**Detection and versions.**
- Probe `GET /api/info` with auth. Never infer from status codes on v1 paths, because unmatched paths return HTML 200 [V `plan/11 §1.1`].
- A JSON reply from `/global/health` means v1: show the legacy screen (§5.2).
- Supported: major 2, ≥ 2.0.21. Newer minors connect with an "untested version" notice.
- Handle `503 {code: service_starting}` with `retry-after`.

**Auth.**
- Basic with user `opencode`. The password is either the service password or a pairing token.
- Pairing: redeem `GET /auth/connect/{code}` with `Accept: application/json` and store `{token}` [V `plan/11 §1.2`].
- Renewal: when a token is within 7 days of its 30-day expiry, call `POST /api/pair` then redeem the code to mint a fresh token [I; verify in S1].
- On 401 the endpoint enters `authFailed` and the UI offers re-pair.
- Web uses the `Authorization` header on fetch; PTY uses the ticket flow.

**Scoping.**
- Send `x-opencode-directory` on location-scoped routes.
- Always send `location.directory` in the `POST /api/session` body, because the service's fallback is the user's HOME [V `plan/11 §A6`].

**Event stream.** One SSE connection per endpoint.
- Parser: `data:` frames, comment heartbeats, 16 MiB cap, chunk-safe UTF-8 decoding (v1's per-chunk decode is a suspected bug, `plan/00 §6`).
- Idle watchdog 45 s; reconnect backoff 1 s → 30 s with jitter; immediate retry on foreground or connectivity change.
- Events are filtered by session and directory in the adapter.

**Projection** is a port of the official reference reducer (`plan/opencode-v2-src/client-solid-data.reference-reducer.ts`, summarized in `plan/12 §3.2`), with one deliberate hardening. Content parts get deterministic ids (`<assistantMessageID>:text:<ordinal>`, tool call id for tools), so `*.started` is an upsert rather than a push. This makes replay over a newer snapshot harmless.

**Resync on every (re)connect:**
1. Open SSE, wait for `server.connected`, and buffer events.
2. Fetch `GET /api/session/active`, plus, for each open session: session info, newest 50 messages, inbox, pending permissions, pending forms.
3. Emit `TimelineSnapshot`, then apply the buffer through the idempotent reducer.
4. A text part that was mid-stream shows a leading "…" until `session.text.ended` replaces it. Deltas are never projected into history [V `plan/12 §1.4`].
5. Sessions not open are revalidated lazily when focused.

The experimental durable log (`/api/experimental/session/{id}/log`) is not in the baseline. It is an optional optimization behind a flag, listed in `experimentalInUse`.

**Activity** comes only from `session.execution.*`, `session.retry.scheduled`, and `/api/session/active`. `session.status` and `session.idle` are declared but have no publisher [I from source search, `plan/12 §5`]; they are ignored. `interrupted{reason: shutdown}` keeps the session "running (server restarting)", because the managed service resumes the turn.

**Sending.**
- `POST /api/session/{id}/prompt {id, text, files, agents, skills, delivery}`.
- The client mints the `msg_` id so that retries are idempotent [V `plan/11 §A7`].
- Message ids are time-ordered and revert compares ids, so the timestamp part uses server time (offset learned from event `created` values), not the device clock [I].
- Fallback if S1 shows client ids misbehave: omit `id`, use the response's id, and resolve ambiguous timeouts by reading the inbox and newest messages before allowing a resend. Paseo's rule "do not pass generated IDs" [V `plan/31 §4.3`] is the reason this is spiked first.

**Tool mapping.** `opencode_tool_mapper.dart` maps `read`, `write`, `edit`, `patch`, `glob`, `grep`, `shell`, `webfetch`, `websearch`, `question`, `skill`, `subagent`, and MCP tools to canonical kinds. This replaces `P/utils/tool_presentation.dart:96-311`.

**Client conventions on native fields (documented, not invented endpoints):**
- Archive = `metadata.codewalk.archivedAt`. No HTTP route sets `time.archived` [I `plan/11 §A6`].
- Approval level = `metadata.codewalk.approval`.
- Unread uses the native `POST …/view` watermark.

**Removed with no replacement:** todos, share, symbol and text search, LSP, config writes (only `shell` is patchable), TUI control. Titles are native (`session.renamed`).

### 4.6 `codewalkd` and the Host Protocol (v2.1)

**Runtime.** TypeScript, Node ≥ 22 (Pi requires 22.19), published to npm. Whether a single-file binary is practical is spike S4.

**Bind and auth.**
- Loopback by default; `--bind` is explicit.
- `codewalkd pair` prints a one-time code and QR (5 minutes), redeemed for a per-device token. Tokens are stored hashed and are revocable.
- Native clients send `Authorization: Bearer`. Browsers fetch a short-lived ticket and pass it on the WebSocket URL.
- TLS is the user's network layer (D08), with optional `--tls-cert/--tls-key`.
- Origin allowlist for Web. The daemon can serve the CodeWalk web build same-origin.

**Wire.** One WebSocket, JSON text frames.

```ts
// server → client
{ t:'hello', protocol:1, daemon:'x.y.z', harnesses:[{id, version, state, capabilities}] }
{ t:'event', session, seq, event }          // canonical HarnessEvent
{ t:'resync', session, reason }             // cursor older than the log
{ t:'result', opId, ok, value | error }
// client → server
{ t:'subscribe', session, afterSeq? }
{ t:'cmd', opId, name, args }               // idempotent by opId
```

- Each session has a monotonically sequenced event log: a memory ring of 2,000 events mirrored to a bounded JSONL file.
- `subscribe{afterSeq}` replays or answers `resync`; the client then fetches a paged snapshot.
- Deltas are coalesced at 50 ms.
- Commands carry an `opId`. The daemon keeps a bounded receipt table and returns the original result on retry. An acknowledgement means "accepted", never "finished".
- Pending approvals and forms live in the daemon until answered and are re-announced on subscribe.

**Adapters.**

- **Codex.** Connect to the shared daemon by spawning the official `codex app-server proxy` and performing the WebSocket handshake over its stdio. This avoids needing AF_UNIX support in the runtime on Windows [I; S5].
  - Run `codex app-server daemon start` first.
  - Negotiate against the daemon's version, not the CLI's; they differ on the research host (0.159.3 vs 0.160.0) [V `plan/20 §2.3`].
  - Route by `threadId`. Opt in to `experimentalApi` only for features gated by capability (queue, plan mode, questions).
  - Use the wire enums (`on-request`, `workspace-write`), not the doc examples [V `plan/20 §3.3`].
- **Claude Code.** One long-lived `query()` per open session in streaming-input mode, driving the user's installed unmodified `claude` binary.
  - Always pass `permissionMode`, `includePartialMessages`, `enableFileCheckpointing`, `perTaskStopAffordance`, `forwardSubagentText`, and a spread `env` [V `plan/21 §2.2`].
  - `canUseTool` and elicitation callbacks become pending interactions.
  - The daemon never reads credential files, never offers a login, and reports auth state via `claude auth status --json`.
- **ACP.** The official `@agentclientprotocol/sdk` over stdio.
  - Grok gets a profile for the `x.ai/*` extensions CodeWalk uses: sessions, interject, queue, rewind, fs, search, ask-user-question.
  - Unknown agents get the generic profile, labelled Experimental.
  - ACP v1 only; v2 draft stays behind a flag.
- **Pi.** One `pi --mode rpc --approve` per open session; sessions listed from disk. Completion is `agent_settled`, not `agent_end` [V `plan/22 §3.1`].
- **Muse.** `muse serve` through `@muse-code/sdk`. Check the schema fingerprint; map `viewCursor` to the log.

**Host services** for harnesses that lack them: `fs.list/find/read/write`, `git.status/diff`, attachment upload, notifier, usage sources. No PTY in the first daemon release. Codex's native `command/exec` terminal works because the daemon holds the connection.

### 4.7 Approvals, sandbox, and allow-all

**Model.**

```dart
class ApprovalRequest {
  String id; SessionRef session; SessionRef? origin;   // origin = child session
  ApprovalKind kind;            // shell|fileEdit|fileRead|network|subagent|mcp|skill|other
  String title; ApprovalDetail detail;                 // command, paths, diff preview
  List<ApprovalChoice> choices; // ordered; server-minted or adapter-built
  bool requiresUser;            // never auto-answered
}
class ApprovalChoice { String id; ChoiceSemantic semantic; String? scopeText; bool acceptsFeedback; }
// semantic: allowOnce|allowSession|allowAlways|deny|denyWithFeedback|abort
```

The card renders the choices the harness actually offers, in order. `allowAlways` must carry a human-readable scope, for example "Always allow all file edits in this project (all sessions)" for OpenCode's `save: ["*"]`.

**Three CodeWalk levels, per session, with a global default for new sessions:**

| Level | Meaning |
|---|---|
| **Ask** | Every request is shown. |
| **Auto-approve** (default for sessions created in CodeWalk) | CodeWalk answers the least-persistent allow choice. Deny rules still apply. Questions, plan approvals, and `requiresUser` requests are never auto-answered. |
| **Unattended** (explicit, per session, with a warning) | The harness's own no-prompt policy, which works with no client attached. |

**External sessions start at Ask** until the user sends a prompt from CodeWalk or changes the level.

| Harness | Auto-approve mechanism | Unattended mechanism | Notes |
|---|---|---|---|
| OpenCode | Client replies `once` (what the official TUI and web app do [V `plan/12 §7.5`]). **Never `always`.** | `PATCH session {permissions:[{*,*,allow}]}`. Warning text: overrides agent deny rules and is inherited by subagents. Restored by PATCHing the previous ruleset. | A reject without a message ends the step and rejects all other pending requests of that session [V `plan/12 §7.4`]; the card says so. |
| Codex | Daemon answers `accept` under `on-request`. | `approvalPolicy: never`. Sandbox is a separate selector: workspace-write by default, full access only by explicit choice. | Overrides persist on the thread and affect the TUI [V `plan/20 §3.4`]. Respect `configRequirements/read`. |
| Claude | Daemon allows in `canUseTool`. | `bypassPermissions` (must be enabled at session start; refused as root). | Native modes (`acceptEdits`, `auto`, `plan`) appear as the harness mode selector, separate from the CodeWalk level. |
| Pi | Inherent. | Inherent. | Control is locked with the text "Pi does not ask for approval". |
| Muse | Daemon picks the `once` choice. | `session/setApprovalMode allowAll` (policy may forbid). | Choices are server-minted; the daemon never fabricates one. |
| Grok | Daemon selects `allow_once`. | `yoloMode`; deny rules and hooks still apply. | Admin lock respected. |
| dsh | Daemon selects allow-once. | — | — |

Remaining rules:

- **Multi-client.** First reply wins. "Not found" or "already resolved" on reply is treated as resolved, not as an error.
- **Engine location.** Auto-approve logic lives in `state/approval_policy.dart`. In v1 it lived in the page layer (`PC/chat_page_lifecycle.dart:240-509`).
- **ADR.** This is an intentional divergence from official default behavior and needs a new ADR exception with rationale, risk, rollback toggle, and regression tests, superseding EXC-001.

### 4.8 Forms, plans, subagents, errors, usage

- **Forms.** `FormRequest{id, session, title, kind, fields[], dismissEndsTurn}` with field types string, number, integer, boolean, select, multiselect, external URL, plus `when` conditions and custom answers.
  - OpenCode Forms map natively (keys `q0…qN`).
  - Claude AskUserQuestion, Codex user-input, Muse userInput, Grok ask-user-question, and MCP elicitation map onto the same shape.
  - Cancel-with-message vs dismiss is explicit, because dismissal ends the step in OpenCode [V `plan/12 §8`].
  - Decode Effect's `"Infinity"`/`"NaN"` string numbers.
- **Plans.** `PlanState{items[{text, status}]}`, shown only when `taskList` is true. OpenCode v2 has none.
- **Subagents.** A child is a normal `SessionRef` with a parent. OpenCode discovery follows the official order [V `plan/12 §11.3`]: tool metadata, then `GET /api/session?parentID=`, then `/api/session/active`, then `session.created` with a parent.
  - Child running state comes from the child's own execution events and the active set, never from the parent tool's status. This sidesteps open bug #48826 (nested background work reported complete early).
  - Descendant approvals and forms are mirrored into the root view with an origin badge.
- **Errors.** `HarnessError{category, scope, message, retry?, action?, raw}`.
  - Categories: auth, quota, rateLimit, contextOverflow, network, providerUnavailable, contentFilter, aborted, permissionDenied, toolFailure, invalidRequest, harnessCrash, versionUnsupported, unknown.
  - Mapped from OpenCode dotted `type`, Codex `codexErrorInfo`, Claude's error enum, and JSON-RPC codes.
  - A user-initiated interrupt is an outcome, not an error. v1's 8-second string-matching suppression is deleted.
- **Usage.** `SessionUsage{tokens, cost?, context{used, limit}?}` and `QuotaWindow{id, label, usedPercent, resetsAt?, duration?, source}`, merged by id from sparse updates.
  - OpenCode's Zen/Go limits are parsed from `error.response.body` of `provider.quota` failures [I `plan/11 §D.7`] and shown as an error with the limit name, not as a window.
  - OpenCode cost totals must sum every assistant step.

### 4.9 Outbox and ambiguous mutations

Every mutation is an `Op{opId, kind, target, state}` with states `pending → acked | failed | unknown`.

- `unknown` means timeout or disconnect after the request left.
- Resolution is: retry with the same idempotency key where the protocol has one (OpenCode prompt `id`, Muse `commandId`, daemon `opId`); otherwise read authoritative state first.
- The user bubble shows Sending, Sent, Failed (retry), or "Not confirmed (checking…)". It is never silently duplicated.
- Reconnection never replays mutations automatically, except idempotent ones.

### 4.10 Polling budget

Polling exists in only three places:

| Purpose | Cadence | Stops when | Cost |
|---|---|---|---|
| Health of hosts with no live connection, for list badges | `GET /api/info` every 60 s while the host list is visible and the app is foreground | App backgrounded, or Data Saver on cellular | One small request per idle host |
| Android background check | WorkManager, 15 min minimum; 3 min chained probes only while a session is known to be running | Disabled in settings, Data Saver on cellular, or nothing running and nothing pending | `session/active` + pending permission and form lists |
| OAuth attempt status during provider login | Per upstream contract | Attempt completes | — |

Everything else is event-driven, with catalog refetches triggered by `*.updated` events.

---

## 5. UX and behavior

### 5.1 Layout

Mobile-first Material You, keeping the existing theme system (ADR-013/014/034/045). Compact width uses a session drawer and single pane. Medium and expanded widths use list + chat + optional utility pane (files, diff, terminal, usage). Web and iOS use the same layouts; iOS keeps Material styling with platform-correct back gestures and safe areas.

### 5.2 Onboarding, pairing, auth

- **Add host** offers:
  - Scan QR / paste pairing link.
  - Enter URL + password.
  - "Set up on this computer" (desktop only).
  - Reverse-proxy sign-in (Cloudflare Access, existing ADR-033).
  - Tailscale (Android, iOS, Linux, macOS).
- **Pairing link** `…/auth/connect/<code>` is recognised by host and path, redeemed, and stored as a token. The profile shows "Paired · renews automatically". Expired or revoked tokens show "Pair again"; nothing is deleted.
- **v1 server detected:** a full-screen explanation — "This server runs OpenCode 1.x. CodeWalk 2 needs OpenCode 2.x." — with two actions: upgrade instructions for the host, and a link to the legacy CodeWalk v1 download.
- **Desktop managed setup** (Linux, macOS, Windows):
  1. Detect `opencode` (PATH, `~/.opencode/bin`).
  2. If it is v2, adopt it.
  3. If it is absent, download the official binary for the target from `opencode.ai/files/bin/<ver>/`, verify SHA-256 from the update API, and install to the official location so `opencode upgrade` keeps working.
  4. If a v1 binary is present, stop and ask. Explain that v2 replaces the v1 command and migrates the shared history database.
  5. Run `opencode service start`, obtain the local credential through the CLI, and connect on `127.0.0.1:49374`.
  6. "Share with my phone" asks for consent, sets the service hostname, restarts it, calls `POST /api/pair`, and shows the QR.
- **Updates.** OpenCode's own `installation.update-available` event shows an "Update available" chip. Updating runs `opencode upgrade`, then offers a service restart, never while a session is running.
- **Platform responsibilities.**
  - Android, iOS, Web: connect only.
  - Headless hosts: a documented shell one-liner for OpenCode's official installer and, from v2.1, `npm i -g` for `codewalkd`.
  - macOS: the release build must not be sandboxed if managed setup is offered. The current Release entitlements are sandboxed [V `plan/00 §1.1`].

### 5.3 Sessions

- Drawer: Host → Project → sessions. Children are nested under roots. Filters: Active / Archived / All. Search uses the server where available.
- Each row shows a harness badge (text, no vendor logos), activity dot, unread dot, and an origin chip for external sessions.
- "New session" shows a harness picker when the host has more than one, defaulting to the last one used in that project. Unavailable harnesses are listed disabled with the reason ("not installed", "not signed in").
- Menus are built from capabilities. An unsupported action is hidden. An action that exists but is blocked now (for example, revert while running) is disabled with a reason.
- Pagination uses server cursors. v1's unbounded list is gone.

### 5.4 Chat lifecycle

- **Send** → optimistic bubble → acknowledged by the inbox event.
- While running, the send button becomes a split control: **Send now (steer)** / **Queue**, limited to the harness's delivery modes, with the harness default preselected.
- Queued inputs appear as a strip above the composer with cancel, and edit where supported.
- **Stop** interrupts the current turn. The tray then shows whatever background work is still running.
- Turn end is a `TurnEnd` row: succeeded, failed with a typed error card, or interrupted.
- Retries show attempt and countdown from the server's `at`.
- Disconnection shows a banner. Activity is marked "last known" and the composer stays usable; sends go to the outbox as pending.

### 5.5 Subagents and background work

- The parent timeline shows a subagent card: agent, description, live status, elapsed. Tap opens the child timeline with "Back to parent".
- A **Background Work tray** above the composer lists running subagents and shells, each with Stop, plus "Stop all". It remains while the parent is idle ("Idle · 2 running in background").
- "Send to background" appears while a foreground subagent or shell blocks the turn, only where supported. For OpenCode it is labelled "Move all running work to background", because per-child backgrounding does not exist [V `plan/12 §11.2`].
- When a background child finishes, the parent's synthetic message renders as a compact "Subagent finished" row linking to the child.
- Child composer is enabled only when the harness accepts direct input to children. Codex rejects it [V `plan/20 §3.14`].

### 5.6 Composer

- **Slash menu** merges client actions (mapped to capabilities), harness commands, and skills, each with a source tag.
- **Skills** are a distinct chip with their own menu section and a note when auto-invocable. The adapter serializes each harness's form: OpenCode `skills[]`, Codex `$name` + item, Claude `/name`, Pi `/skill:name`, Muse input part.
- **`@`** offers files (fuzzy find), and agents where supported. OpenCode sends structured file and agent attachments with mention ranges. Others insert path text, and the chip tooltip says so. Symbol mentions are removed.
- **Attachments.** Picker, drag-drop, paste. Images are gated by model modality. PDF is offered only where the harness accepts it, which excludes OpenCode v2 [V `plan/10 §g`]. Client cap stays 10 MB (OpenCode's is 20 MiB).
- **Selection chips.** Agent or mode, model, and variant or effort are rendered from the catalog. For OpenCode they are session state (`POST …/agent`, `…/model`), changed before sending, and reflected as `SelectionChange` rows.
- **Kept as-is:** drafts, input history, canned answers, STT.

### 5.7 Files, terminal, undo

- **Files.** Tree, quick open, viewer with highlighting.
  - Save is available only where write exists. For OpenCode it sits behind an "Experimental file writes" setting, because the endpoint is experimental and not confined to the project [V `plan/11 §A10`].
  - Rename, delete, and duplicate are deferred. There is no native endpoint and the v1 shell-script mechanism is retired.
  - Content search is hidden for OpenCode.
- **Terminal.** OpenCode PTY on all platforms including Web, via ticket. The cursor resumes after reconnect.
- **Undo.**
  - OpenCode shows a staged-revert banner with the affected files, **Redo** (clear) and **Apply** (commit). The next prompt applies it. It is disabled while running.
  - Claude shows "Rewind files to here" with a dry-run preview and the caveat that shell and subagent edits are not covered.
  - All others show "Branch from here", which opens a new session.

### 5.8 Notifications and background

| Tier | Platforms | Release | Behavior |
|---|---|---|---|
| Live | All, app open or held alive | v2.0 | Local notification on completion, error, approval, and question for root sessions; suppressed for the focused session. |
| Android background | Android | v2.0 | One `AttentionMonitor`: a foreground service holds the live connection while a session is running; WorkManager checks sparsely otherwise. Replaces three detectors. |
| Host push | Any, via the user's notifier | v2.1 | `codewalkd` posts to a user-configured ntfy/UnifiedPush topic or webhook. The payload contains a deep link and minimal text; a "private" mode sends no titles. |

Settings state the limits plainly:

- **iOS:** "Alerts arrive only while CodeWalk is open, or through your notifier app."
- **Web:** "Alerts arrive only while this tab is open."
- OAuth and Tailscale profiles keep the v1 limitation of no background network after process death.

The Android overlay and Android Auto messaging are ported in v2.1 on top of `AttentionMonitor` (§6.1).

### 5.9 Platform tiers

| Tier | Targets | Not available |
|---|---|---|
| 1 | Android, Linux, macOS, Windows | Windows: embedded Tailscale |
| 2 | Web | Managed setup, embedded Tailscale, on-device STT, plain-HTTP hosts from an HTTPS origin, self-update |
| 2 | iOS | Managed setup, overlay, Android Auto, persistent background, self-update (store-managed) |

---

## 6. Rewrite, reuse, discard

### 6.1 Feature decisions

| Feature | Decision | Reason |
|---|---|---|
| Theme system, densities, presets | Keep | UI-only, no wire coupling. |
| Markdown, LaTeX, Mermaid, code rendering | Keep | UI-only. |
| Localization (14 locales) | Keep; prune dead keys | Many strings name removed features. |
| Accessibility semantics | Keep; re-verify per new widget | — |
| Voice (STT engines, TTS backends) | Keep | Client-only. |
| Session tabs and Ctrl+Tab switcher | Keep UI; rewrite state on `SessionRef` | 2,366-line ops file is tied to `ChatProvider`. |
| Drafts, input history, canned answers | Keep; rekey to `SessionRef` | — |
| Export (Markdown/JSON), share as image, forward | Keep; rebuild from canonical items | — |
| Shortcuts, settings shell, logs, release history, tray, window chrome | Keep | — |
| Timeline viewport and scroll ownership | Rewrite against canonical items, porting the invariants and their tests | The largest complexity hotspot, coupled to v1 part types. |
| Model selector, favorites, recents | Rewrite on the catalog | v2 model list is flat with `enabled`/`status`. |
| Permission and question cards | Rewrite | New models. |
| Diff viewer, file viewer, terminal panel | Keep UI; new data sources | — |
| Quota bars and pace | Keep widgets; new sources | — |
| Android attention overlay, Android Auto | **Defer to v2.1**, rewritten on `AttentionMonitor` | Each runs its own polling path today. The v2 prompt idempotency key finally makes car replies safely retryable. |
| Cellular Data Saver | Simplify to "no background network and no idle-host polling on cellular" | SSE no longer has two streams to drop. |
| Todo panel | Keep widget; show only where `taskList` | Removed in OpenCode v2. |
| Share links, symbol mentions, OpenCode defaults editor, multi-device selection sync | Discard | Upstream removed share and config writes; the sync was a fake-agent hack. |
| File mutations via shell scripts | Discard | ADR-043 mechanism has no place in v2. |
| Auto titles via hidden session | Discard | Native in v2. |
| Vendor quota via `/shell` + `node -e` | Discard | Returns in v2.1 inside `codewalkd`. |

### 6.2 Code map

| Existing | Fate | Replacement |
|---|---|---|
| `lib/data/datasources/chat_remote_datasource*.dart`, `lib/data/models/*` | Delete | `lib/harness/opencode/*` |
| `lib/presentation/providers/chat_provider.dart` + `chat_provider/*` (22.8k) | Delete | `lib/state/session_store.dart`, `outbox.dart`, `interaction_center.dart` |
| `lib/presentation/pages/chat_page.dart` + `chat_page/*` (27.5k) | Rewrite | `lib/features/chat/*` |
| `lib/domain/entities/*`, 31 pass-through use cases | Delete | `lib/domain/*` |
| `app_provider.dart` (2,663) | Split | `state/connection_manager.dart`, `features/hosts/*`, `platform/managed_install/*` |
| `local_opencode_server_runtime_io.dart` | Rewrite | `platform/managed_install/opencode_v2_installer.dart` |
| `chat_title_generator.dart`, `workspace_file_operations_service.dart`, `quota_remote_datasource*.dart`, `permission_auto_approve_runtime.dart` | Delete | Native, facet, or `approval_policy.dart` |
| `android_background_alert_worker.dart`, `session_attention/*`, `car_messaging/*` | Rewrite | `state/attention_monitor.dart` + `platform/android/*` |
| `lib/core/network/*`, `core/tailscale`, `core/auth` | Keep and trim | Add an SSE client with a correct decoder and a WS client |
| `P/theme`, `P/widgets/chat_message/*` renderers, `P/services/tts`, speech services | Move under `features/` or `core/` | — |
| `test/support/mock_opencode_server.dart` | Replace | `test/support/fake_opencode_v2_server.dart` |

The 25 v1 workarounds in `plan/00 §3` map as follows:

- **Deleted outright:** #1, #3–#19, #21, #24, #25.
- **Replaced by one native-data implementation:** #20 (subagent resolver), #22 (archive convention).
- **Reduced:** #2 (reconnect policy only), #23 (one Android monitor).

### 6.3 Documentation and contracts

- **New ADR:** "CodeWalk v2 multi-harness, contract-first per harness". It supersedes the scope of ADR-023 and lists each harness's official sources and pinned versions.
- **New ADR exceptions:**
  - Allow-all default (supersedes EXC-001).
  - Archive and approval level stored in session metadata.
  - Experimental file write.
- **Superseded:** ADR-009 (titles), ADR-019 (config deferral), ADR-029 (quota shell), ADR-031 (revert), ADR-043 (shell-gated files), ADR-041 and P-001/P-002 (replaced by the reducer invariants in §4.3).
- **Updated:** ADR-003, ADR-017, ADR-018, ADR-049, ADR-055.
- **`CONTRACT_MATRIX.md`** becomes per-harness matrices generated from `contracts/*/used-operations.yaml`.
- **`ai-docs/`** gains v2 snapshots; v1 documents remain only on the `v1` branch.
- **`BEHAVIOR.md`** is rewritten stage by stage and describes only what has landed. `CODEBASE.md` and `README.md` follow.

### 6.4 Migration, versioning, rollback

- **Branching.** Cut `v1` from `14fbf519`. `main` becomes v2.
- **Version.** `make release V=major` yields 2.0.0. Betas are published as GitHub prereleases, which `releases/latest` excludes, so v1 clients are not offered them.
- **Legacy channel (mandatory mitigations for D04):**
  1. v1 maintenance releases are published with "latest" disabled, so `releases/latest` stays on v2.
  2. On the `v1` branch, build codes change to `previous + 1`, keeping every legacy `versionCode` below v2.0.0's. A legacy APK then cannot install over v2. This requires cutting the last timestamp-coded v1 release before the first v2 build code is fixed.
  3. Legacy install scripts pin the `v1` tag series.
  4. The v2.0.0 release body starts with a one-line announcement stating the OpenCode 2.x requirement and the legacy link.
- **Local data.** v2 writes only `cw2.*` keys and files. First run imports from v1 keys, read-only:
  - Imported: server profiles (marked "needs OpenCode 2 check"), stored passwords, OAuth and Tailscale settings, appearance, shortcuts, voice settings and API keys, notification preferences, canned answers.
  - Not imported: session caches, tabs, pins.
  - Drafts with text are imported into a one-time "Recovered drafts" list.
  - v1 keys are purged after two minor releases, at which point the native pre-engine cleanup list in `CodeWalkApplication.kt` is updated in the same change.
- **Rollback.** Desktop: reinstall legacy; v1 data is untouched. Android: uninstall then install legacy, which loses app data. The legacy screen says this before the user leaves.

---

## 7. Stages

### 7.0 Spikes (throwaway, each time-boxed to two days)

| ID | Question | Decides |
|---|---|---|
| S1 | Record OpenCode 2.0.22 traffic for: plain turn, tool + permission, form, background and nested subagent, interrupt, steer and queue, revert, retry, quota error. Verify pairing redemption and renewal, client-minted prompt ids under clock skew, `--standalone` visibility, service CLI output formats, v1 coexistence. | §4.5 send path, §3.3 row 2, D10 |
| S2 | Flutter Web: streaming SSE with an auth header, CORS, mixed-content matrix, PTY ticket WebSocket. | Web tier scope |
| S3 | iOS: skeleton build with vendored Tailscale, xterm, secure storage, Sherpa; ATS and local-network behavior; suspension timing. | iOS gate |
| S4 | `codewalkd` packaging: Node vs single binary with the Claude SDK; WebSocket over a child's stdio. | D15 packaging |
| S5 | Codex: attach to the shared daemon on three OSes, alongside a TUI; approval with no client; thread list scope. | §3.3, Codex adapter |
| S6 | Claude: live capture; resume a terminal-started session; concurrent open; file rewind; current policy text. | §3.3, Claude adapter |

S1–S3 precede Stage 1. S4–S6 precede Stage 10.

### 7.1 v2.0 — OpenCode v2

| Stage | Scope | Acceptance |
|---|---|---|
| 1 Skeleton | `v1` branch, new tree, boundary test, CI for analyze/unit/web, iOS compile job | Empty shell builds on all six targets; boundary test fails on a planted violation. |
| 2 Core + fake | Domain, reducer, outbox, `fake` adapter, timeline rendering | A scripted fake session streams, interrupts, and resyncs in widget tests. |
| 3 Connect | HTTP/SSE clients, auth, pairing, renewal, v1 detection, host list, session list | Pair by QR and by password against the fake server; a v1 server shows the legacy screen. |
| 4 Chat | Projector, snapshot resync, send/steer/queue/interrupt, errors and retry | Golden transcripts from S1 produce the expected timelines; killing the stream mid-turn recovers without duplicates. |
| 5 Interactions | Approvals with three levels, forms, child mirroring, Background Work tray | No `always` is ever sent automatically; external sessions stay at Ask. |
| 6 Composer | Catalog, selection, commands, skills, mentions, attachments | Structured attachments match the recorded request bodies. |
| 7 Tools | Files, diff, terminal, staged revert, fork, compact | Revert stage/clear/commit matches recorded events; terminal resumes by cursor. |
| 8 App features | Tabs, drafts, canned answers, export, voice, settings, shortcuts, usage, Android monitor | Existing widget tests for kept features pass after port. |
| 9 Ship | Managed setup, v1 import, updater, ADRs and docs, betas, 2.0.0 | Upgrade from a 1.265.0 profile keeps settings and profiles; release checklist in §8.4 is green. |

**Minimum viable v2.0** is stages 1–7 plus drafts, tabs, notifications, the Android monitor, managed setup, and import. Nothing the user asked for is dropped; the overlay, Android Auto, and vendor quota windows move to v2.1 for the reasons in §6.1.

iOS is compiled from Stage 1 and released to TestFlight during the v2.0 betas if the Apple prerequisites exist. General availability follows in v2.1.

### 7.2 Later releases

| Release | Stages |
|---|---|
| v2.1 | 10 `codewalkd` core (auth, log, protocol, fs/git services) + Dart host adapter · 11 Codex · 12 Claude · 13 notifier, overlay and Android Auto port, usage sources |
| v2.2 | 14 ACP adapter with the Grok profile, generic ACP (experimental, includes dsh) · 15 Pi |
| v2.3 | 16 Muse |

Each harness stage has the same acceptance: recorded fixtures → canonical events; the capability table matches §3; external-session labels match §3.3; no harness-name branch in `features/`.

---

## 8. Testing and validation

### 8.1 Contract fixtures

- `contracts/opencode/fixtures/*.jsonl`: recorded SSE plus HTTP exchanges from S1. Tests assert wire → canonical events → timeline snapshot.
- `fake_opencode_v2_server.dart`: auth, pairing, sessions, prompt idempotency, inbox, permissions, forms, SSE with heartbeats, forced drops, overflow disconnect, and `503 service_starting`.
- `tool/contract/opencode_openapi_diff.dart`: compares the pinned OpenAPI document against a live server's `/openapi.json` for the operations listed in `used-operations.yaml`. It runs in the smoke workflow against the pinned and latest OpenCode releases.
- Host protocol: JSON Schema plus fixtures validated by both the Dart codec tests and the daemon's tests.

### 8.2 Required edge cases

- **Reducer:** duplicate and out-of-order events; delta after completion; started-after-snapshot; unknown event and item types; malformed JSON frame; multi-byte characters split across chunks.
- **Reconnect:** drop mid-text, mid-tool, during a pending approval, during a revert; overflow disconnect; server restart with `reason: shutdown`.
- **Sending:** timeout after the request left (same-id retry yields one message); 409 conflict; steer vs queue while running; cancel queued.
- **Permissions:** two clients reply; reject cascade; child request mirrored; auto-approve never chooses a persistent option; an external session is not auto-approved; Unattended restores the prior ruleset.
- **Subagents:** foreground, background, nested background with the early-completion bug, interrupt of parent with background children still running, child deleted.
- **External sessions:** created, renamed, and prompted from another client while CodeWalk is attached.
- **Multi-host:** identical native ids on two hosts and two harnesses stay isolated in tabs, drafts, and notifications.
- **Upgrades:** v1 profile import; token expiry and renewal; password rotation; server newer than tested.
- **Web:** origin not allowed, mixed content, auth header on the stream, PTY ticket.
- **iOS:** suspend and resume resync; denied local-network permission.
- **Accessibility and layout:** semantics labels on new cards; text scale 200%; RTL; compact, medium, and expanded widths.

### 8.3 Budgets

- No network activity while idle and connected, apart from the stream heartbeat.
- Applying a 100 ms delta batch to a 500-item session stays within one frame on a mid-range Android device.
- Resident timeline is capped at 500 items per session with an LRU of 20 sessions. Message pages are 50; decoding pages over 256 KB happens off the UI isolate.
- Android background: at most one wake per 15 minutes when nothing is running.

### 8.4 Commands and gates

- **Focused, during iteration:** `flutter test test/unit/harness/opencode`, `flutter test test/unit/state`, `flutter test test/widget/chat`.
- **Stage gates:** `make check`, then `make test-web`.
- **Platform builds:**
  - `make desktop` on each desktop OS runner.
  - Android APK through GitHub Actions only (not on ARM64 Linux hosts, per `AGENTS.md:44`).
  - `flutter build ios --no-codesign` on a macOS runner.
- `make precommit` is not used for normal validation (`AGENTS.md:36`).
- The analyze budget (337) and coverage gate (35%) in the `Makefile` should be tightened for the new tree once Stage 2 lands. The target numbers are a project decision.
- Code review happens after each coherent stage, not for this plan.

---

## 9. Risks, assumptions, open questions, start

### 9.1 Risks

| Risk | Mitigation |
|---|---|
| OpenCode v2 API churn (OpenAPI is `0.0.1` "experimental"; 23 releases in 3 weeks) | Pinned minimum, drift check in CI, tolerant decoding, baseline uses stable routes only. |
| Reliance on experimental surfaces | Each is behind a setting and listed in Diagnostics: file write, durable log, Codex `experimentalApi`, Claude usage pull. |
| Anthropic policy shifts for third-party tools | No login, no credential access, unmodified binary, API-key mode documented, in-app disclosure, policy recheck at each release. |
| Codex terms for non-local use | Open-source, user's own install, no CodeWalk relay; `clientInfo.name = "codewalk"`. |
| v1 users auto-updating into an incompatible client | Announcement line, v1-server screen, non-destructive import. |
| Managed setup replaces a user's v1 `opencode` | Explicit confirmation; never automatic. |
| Timeline viewport regressions during rewrite | Port existing invariants and tests before deleting v1 code. |
| iOS distribution prerequisites missing | iOS gated on compile only until they exist. |

### 9.2 Assumptions and fallbacks

| Assumption | Why unverified | If false |
|---|---|---|
| A pairing token can mint its successor | Inferred from "token accepted anywhere the password is" | Prompt to re-pair every 30 days, with a 7-day warning. |
| Client-minted prompt ids are safe | A secondary source advises against it | Server-assigned ids with read-before-resend. |
| `metadata` is a suitable place for archive and approval level | Field is native, convention is ours | Device-local storage, losing cross-device consistency. |
| The service CLI exposes the local password in a parseable form | Output format not captured | Read the documented registration file, read-only. |
| Zen/Go limit details reach the client in `response.body` | Inferred from the classification chain | Show the generic quota error only. |
| GitHub marks new releases "latest" by default | Not checked against the API | No change needed, but keep the explicit flag anyway. |
| WebSocket-over-stdio to `codex app-server proxy` works | Untested | Linux/macOS use the UDS directly; Windows Codex support waits. |

### 9.3 Unresolved questions

1. Should allow-all for external sessions remain Ask-by-default (this plan), or follow the global default?
2. Is a CodeWalk-operated push gateway acceptable for iOS, or is "notifier app or app open" the permanent answer?
3. Does the macOS build drop the sandbox to keep managed setup?
4. Does `codewalkd` ship with the desktop app, or only as a separate install?
5. Are vendor logos wanted on harness badges, given trademark caution (especially Anthropic's naming rules)?

### 9.4 Sources

- **Local:** `plan/00`–`plan/31` and raw folders; `ADR.md:1103-1255`; `BEHAVIOR.md:2396-2545`; `Makefile:21-25, 244-289, 416-447`; `lib/presentation/services/update_check_service.dart:131-214`; `.github/workflows/release.yml`; `AGENTS.md:36-44`; `third_party/tailscale/README.md:224-228`.
- **Official upstream (as pinned in the dossiers):** OpenCode `anomalyco/opencode` v2.0.21; Codex `openai/codex` rust-v0.160.0; Claude Agent SDK 0.3.287 and legal/compliance pages; Pi 1.0.0 docs; Muse SDK 1.4.2; Grok Build 1.0.46 user guide; dsh 0.2.0-rc.2 READMEs; ACP `9e032156`.
- **Secondary:** OpenChamber `fc012ae0`, Paseo, t3code, Happy. Used for patterns and pitfalls only.
- I did not consult the web during this pass. Every external claim rests on the research pack's own verification labels.

### 9.5 Execution start

1. Obtain an OpenCode 2.0.22 host and run S1. Commit the recordings under `contracts/opencode/fixtures/` and the pinned OpenAPI document.
2. Run S2 and S3 in parallel.
3. Cut the last timestamp-coded v1 release if any fix is pending, then create branch `v1` and apply the legacy build-code and release-flag changes there.
4. On `main`: create the new tree and `test/architecture/import_boundaries_test.dart`, then `lib/domain/*` and `lib/harness/fake/*`.
5. Draft the new multi-harness ADR and the allow-all exception before Stage 5, so the divergence is recorded before the code exists.

Strict prerequisites before Stage 5: user answers to §2.2 item 1 and §9.3 question 1. Before Stage 10: §9.3 questions 2 and 4, and spikes S4–S6.