# 31 — Multi-harness and remote clients: architecture evidence

> Research date: **2026-10-02**. Evidence only, no app design. Companion to `30-acp-and-unifying-protocols.md`.
> Tags: **Verified (src)** means read in source or official docs at the cited commit or date. **Verified (gh)** means from GitHub API, issue or PR text. **Unverified** means secondary, inferred, or not reproduced.
> Some sections were gathered by parallel sub-research passes at pinned commits and cross-checked for consistency. Where I re-checked a fact myself it says "re-verified".
> Raw extracts: `plan/acp-src/ecosystem/` (Reemoat events and measured ACP behaviour, Grok/Cursor extension shapes, codex-acp AIR contract, Agmente compatibility matrix, ACP registry snapshot).

**Permalink bases (pinned commits):**

| Key | Base URL |
|---|---|
| OC (OpenChamber) | `https://github.com/openchamber/openchamber/blob/fc012ae0029fa2ac8d1d52b4af37040fc536258e/` (2026-10-01) |
| OCv2 (OpenCode v2) | `https://github.com/anomalyco/opencode/blob/v2.0.21/` |
| HP (Happy) | `https://github.com/slopus/happy/blob/4cf54d18488cba4787cc251cc37010f31125af29/` (2026-09-27) |
| PS (Paseo) | `https://github.com/getpaseo/paseo/blob/bd3986d964b3ff528a8adf045a062dde10616934/` (2026-10-02) |
| RM (Reemoat) | `https://github.com/rends-east/reemoat/blob/568beecb2e4ff3acff1be75690f68af462b6a483/` (2026-10-01) |
| RN (Runmote) | `https://github.com/Raza-learner/Runmote/blob/e21841f1db4d8e59020a5dac828da23d845aefce/` (2026-09-16) |
| AG (Agmente) | `https://github.com/rebornix/Agmente/blob/87f224e7d5884d450f4d54cc1d72724416e6d750/` (2026-03-21) |
| Z (Zed) | `https://github.com/zed-industries/zed/blob/2a97fbf22bd6c500a3968b79fb5b02adee68c975/` |
| T (Toad) | `https://github.com/batrachianai/toad/blob/dd4f90e8b3700c3de80ad4b0eaa488ad0105e2c1/` |
| VK (vibe-kanban) | `https://github.com/BloopAI/vibe-kanban/blob/d5cbb5380fa0b32e98ef9b8d987f63decce4be3a/` |
| CR (Crystal) | `https://github.com/stravu/crystal/blob/1e18e0bc981225f75b5226f82a300fa741970c6f/` |
| NB (Nimbalyst) | `https://github.com/nimbalyst/nimbalyst/blob/9f13b2794d6d37ab005af6302cfe2a8540cfcdb6/` |
| OL (Omnara legacy) | `https://github.com/omnara-ai/omnara/blob/500a82ad85ba35d0a478810bb00e944ba93071b1/` |

---

## 0. TL;DR

1. **OpenChamber** (11k stars) is still **OpenCode-only**, and since **v2.0.0 (2026-09-23)** it runs on **OpenCode 2.x only**.
   - It uses `@opencode/client` 2.0.21 and gates on `MINIMUM_OPENCODE_VERSION = '2.0.20'`, major === 2.
   - All OpenCode wire knowledge is confined to about five files. A server hub converts OpenCode's volatile SSE into WebSocket, with replay and delta coalescing.
   - Multi-harness exists only as open issues (#2010 ACP, #1422 AgentRuntime, #3654 Pi), a community ACP proof of concept in a fork working with `pi-acp` (2026-09-30), and OpenCode-API-impersonating proxies.
   - Verified (src, gh).
2. **Products that drive several harnesses split into two camps:**
   - **ACP-first:** Zed, JetBrains, Toad, Codeg, Reemoat, Runmote, Mobvibe, Agmente (also Codex app-server), Ferngeist, and many more.
   - **Native protocol per harness, then normalized into their own model:** Happy, Paseo, Nimbalyst, vibe-kanban, Conductor, **t3code** (six drivers, 49-type `ProviderRuntimeEvent`, event-sourced), CloudCLI and Superset; CodexMonitor is Codex-only. Several of these also have an **ACP fallback adapter** (Paseo `GenericACPAgentClient`, Happy `AcpBackend`, Nimbalyst `*ACPProtocol`, and t3code's ACP runtime for Cursor/Grok/Antigravity).
   - The fidelity products state their reasons: richer diffs from Codex app-server, Claude SDK `canUseTool`, and OpenCode's own HTTP+SSE.
3. **Every remote or mobile product puts a host daemon or gateway next to the harnesses.** Clients reach it either directly (WebSocket, optionally over a tunnel or SSH) or through a relay, which is often **E2E-encrypted**:
   - Happy: NaCl/AES-GCM.
   - Paseo: NaCl box.
   - Reemoat: Noise_IK.
   - OpenChamber relay: ECDH P-256/AES-GCM.
   - Nimbalyst: AES-GCM.
   - Mobvibe: E2EE gateway.
4. **Canonical event models converge on the same shape:** a timeline of items (user/assistant text, reasoning, tool-call lifecycle, plan/todo, permission/question, turn start/end with usage, subagent links), carried as a **seq-numbered log** with bounded replay and authoritative catch-up pages. Seq logs are used by Happy (v3 `after_seq`), Paseo (`seqStart/seqEnd`, epoch), Reemoat (`StoredEvent.seq`, `ATTACH_REPLAY_MAX` 2000) and OpenChamber (event ids plus `replayReset`).
5. **Recurring pitfalls:**
   - Hung or invisible permission and question requests.
   - CLI and protocol version drift.
   - Lost events on reconnect or mobile background.
   - Huge transcripts exhausting memory.
   - Stuck "running" state.
   - Per-harness enum mismatches (permission modes, approval policies).

---

## 1. Harness-side integration surfaces (what a multi-harness client actually talks to)

> Detail from a sub-research pass is in section 15. Facts here are cross-checked.

| Harness | Surfaces used by products | Evidence |
|---|---|---|
| **OpenCode 1.x** | `opencode serve` HTTP + SSE (`/event`, `/global/event`), `@opencode-ai/sdk` (has a `./v2` subpath that is still the 1.x API); `opencode acp` | Verified (npm; Paseo baseline doc) |
| **OpenCode 2.x** | New server on branch `v2`, tags `v2.0.0`…`v2.0.21`; npm `@opencode/cli`/`@opencode/client`/`@opencode/schema` **2.0.22** (2026-10-02). All routes under `/api/*`. `GET /api/event` is *"Volatile by contract … events during disconnection are missed"*. Durable catch-up via `GET /api/experimental/session/:id/log?after=<seq>&follow=true`. Permissions reply `{decision: once\|always\|reject}`. Question tool replaced by typed **forms**. ACP still shipped. | Verified (subagent: OCv2 `packages/protocol/src/groups/*.ts`, `packages/schema/src/*.ts`; npm re-verified) |
| **Claude Code** | Claude Agent SDK `query()` + `canUseTool` (Happy remote, Paseo, Nimbalyst, Conductor); `claude -p --output-format stream-json --input-format stream-json` (vibe-kanban, Crystal); PTY + JSONL tail (Happy local, Omnara legacy); ACP adapter `claude-agent-acp` (Zed, JetBrains, Codeg, Reemoat, Runmote) | Verified (sources below) |
| **Codex** | `codex app-server` JSON-RPC (Happy, Paseo, Nimbalyst default, vibe-kanban, t3code, CodexMonitor, Agmente, Superset; also the base of `codex-acp`). Transports: stdio, unix, `--listen ws://` (experimental; auth required off loopback; `Origin` rejected). `codex exec --json` / `@openai/codex-sdk` (Crystal, CloudCLI; Superset calls it lossy) | Verified (15.1) |
| **Pi** | `pi --mode rpc` JSONL (Paseo, Sculptor, `pi-acp`, OpenChamber community connector, vacp_bridge); no native ACP yet; no built-in permission system | Verified (15.3) |
| **Grok Build** | Native ACP `grok agent stdio`, **`grok agent serve --bind … --secret …` (WebSocket ACP server)**, `grok agent headless --grok-ws-url` (relay); vendor `x.ai/*` / `_x.ai/*` methods (Reemoat, Nimbalyst `GrokACPProtocol`, Codeg, Toad, t3code) | Verified (15.4) |
| **Gemini CLI / Copilot / Cursor / Kimi / Qwen** | Native ACP (`--acp`, `cursor-agent acp`, `kimi acp`); Cursor also stream-json (Nimbalyst) | Verified |

---

## 2. OpenChamber (`openchamber/openchamber`), REQUIRED

### 2.1 Overview
- **What it is:** *"an open-source workspace for running and reviewing AI coding work on desktop, web, VS Code, and mobile"*. Verified (OC `README.md`).
- **Releases:** v2.1.0 (2026-10-01, "Search across your conversations"); v2.0.4 "Enterprise mode for teams"; v2.0.0 (2026-09-23) "OpenCode 2 and instant settings". 11,014 stars. Verified (gh, re-verified).
- **Monorepo** (Bun workspaces):
  - `packages/ui`: shared React 19 UI, Zustand, sync.
  - `packages/web`: Express 5 server, CLI, OpenCode lifecycle.
  - `packages/electron`: backend in-process, *"never as a sidecar"*.
  - `packages/vscode`.
  - `packages/mobile`: Capacitor 8. It *"does not embed the OpenChamber web server or OpenCode server"*; it connects to an existing OpenChamber server.
  - `packages/sdk`: third-party panel contract.
  - Verified (OC `AGENTS.md`, `packages/mobile/README.md`).

### 2.2 How it connects to OpenCode (and OpenCode v2 status)
- **Managed or external `opencode serve`:**
  - The desktop app bundles the CLI (`opencodeCli.version: "2.0.21"`).
  - Binary resolution order: settings → env → bundled → PATH → known locations → shell.
  - OpenCode runs in its own process group.
  - Readiness probe is `GET /api/info` (*"OpenCode 2.0.8 removed `/api/health`"*).
  - Basic auth with user `opencode` and password from `OPENCODE_SERVER_PASSWORD`.
  - Verified (OC `packages/web/server/lib/opencode/DOCUMENTATION.md`).
- **v2-only gate:** `MINIMUM_OPENCODE_VERSION = '2.0.20'`; `isSupportedOpenCodeVersion` requires major === 2. Verified (OC `packages/web/server/lib/opencode/compatibility.js:14`).
- **Cutover PR #3837** "feat: move OpenChamber to OpenCode 2.x" (merged 2026-09-22, +37,964/−33,201, about 750 files). Verified (gh, re-verified). From the PR body:
  - *"everything lives under `/api/*`, sessions come as a paginated list with cursors, messages carry their parts inline, live updates are `session.*` events on one global stream, plugins are hot-reloaded"*
  - Gaps worked around: archive (local `sessions-archive.json`); session metadata (`PATCH /api/session` arrived in 2.0.15); credentials (`GET /api/credential` arrived in 2.0.20).
  - *"Prompt optimizer plugin is gone: v2 has no system-prompt transform hook"*
  - A one-shot v1→v2 session migration top-up (`v1-migration-topup.js`).
- **Migration history:**
  - Tracking issue **#3259** "productionize OpenCode V2 Beta alongside stable V1" (closed). *"Policy change (2026-09-03). The target architecture changes from capability-by-capability V1→V2 migration inside one mixed runtime to two explicit, mutually exclusive modes: Stable/V1 (`opencode`) and opt-in Beta/V2 (`opencode2`)."*
  - About three weeks later, PR #3837 dropped V1 entirely and v2.0.0 shipped as v2-only.
  - Verified (gh, re-verified).
- **Event pipeline** (OC `packages/web/server/lib/event-stream/DOCUMENTATION.md`, `packages/ui/src/sync/event-pipeline.ts`). Verified.
  - The server reads upstream SSE once (a "global hub") and fans out over **WebSocket** `/api/global/event/ws`, with SSE as fallback.
  - *"OpenCode 2.x sends no `id:` SSE lines: the event id is `payload.id`"*
  - Bounded replay buffer of **2,048 events or 8 MiB**. The client reconnects with `lastEventId`. When the cursor is unknown, the server sends `ready{replayReset:true}` and the client does an authoritative repair.
  - **Delta coalescing:** a 50 ms window over `session.text.delta`, `session.reasoning.delta` and `session.tool.input.delta`. Measured: *"3,402 delta events of 1.7 characters each … cut that stream to 483 frames and 197 KB."*
  - WS frame schema: `{type: "ready"|"event"|"error"|"backpressure", replayReset?, payload?, eventId?, directory?, message?}`.
  - Client constants: `FLUSH_FRAME_MS=100`, `DEFAULT_HEARTBEAT_TIMEOUT_MS=30_000`, `WS_FALLBACK_WINDOW_MS=60_000`. Retry backoff caps at 5 s when visible and 60 s when hidden.
- **Abstraction:** *"These files are the only place that knows 2.x wire shapes. Rendering and stores read the domain model."* Verified (OC `.agents/skills/opencode-v2/SKILL.md`). The files:
  - `packages/ui/src/lib/opencode/client.ts` (2,116 lines; one scoped client per directory via the `x-opencode-directory` header)
  - `projection.ts` (wire → domain), `model.ts` (domain), `events.ts` (wire → `SyncEvent`)
  - server `translate-v2.js`, `proxy.js`

### 2.3 OpenCode v2 wire vocabulary (as consumed by OpenChamber)
`translateWireEvent` in OC `packages/ui/src/lib/opencode/events.ts:221` handles these. Verified.
- **Sessions:** `session.created|deleted|forked|renamed|metadata.updated|moved|agent.selected|model.selected|usage.updated|permissions|viewed`
- **Revert:** `session.revert.staged|cleared|committed`
- **Status and execution:** `session.status`, `session.idle` (deprecated), `session.execution.started|succeeded|interrupted|failed`
- **Inbox:** `session.inbox.enqueued|delivered|cancelled`
- **Steps:** `session.step.started|streamed|ended|failed`, `session.retry.scheduled`
- **Streaming content:** `session.text.*`, `session.reasoning.*`, `session.tool.input.*`
- **Tools:** `session.tool.called|progress|success|failed`
- **Shell and compaction:** `session.shell.*`, `session.compaction.*`
- **User requests:** `permission.asked|replied`, `form.created|replied|cancelled`
- **Catalog:** `config|agent|command|skill|plugin|provider|model|websearch.updated`, `credential.*`, `vcs.branch.updated`, `mcp.status.changed`
- **Terminals:** `shell.*`, `pty.*`
- **TUI:** `tui.*`

Internal domain (OC `model.ts`), Verified:
```ts
// message roles: user | assistant | synthetic | system | skill | shell | compaction | agent-switched | model-switched | location-switched | idle
// parts: text | reasoning | file | agent | tool ; part ids deterministic: `${messageID}:text:${ordinal}`, tool = callID
ToolStatePending   { status:"pending";   input; raw: string }
ToolStateRunning   { status:"running";   input; metadata?; time:{start} }
ToolStateCompleted { status:"completed"; input; output: string; metadata?; time:{start,end}; attachments?: FilePart[] }
ToolStateError     { status:"error";     input; error: string; output?; metadata?; time:{start,end} }
```
- v2 has no turn outcome on assistant messages. Status is synthesized from `session.execution.*`, and `interrupted{reason:"shutdown"}` maps to nothing because OpenCode resumes the turn. Verified.

### 2.4 UX: permissions, subagents, quotas, terminal, attachments, notifications
- **Permission card:** buttons Reject / "Always allow [patterns]" / Allow once. Reply via `permission.reply({sessionID, requestID, decision, message})`.
  - **Server-side auto-accept:** per-session modes `ask | safety | auto` (`safety` uses an LLM classifier). Children inherit the nearest explicit ancestor. *"the sole responder"* means it works with no UI connected. It fails closed to `ask`.
  - The composer shield cycles ask → safety → auto.
  - Verified (OC `PermissionCard.tsx`, `permission-auto-accept/DOCUMENTATION.md`).
- **Questions:** OpenCode v2 forms, `FormDock.tsx`, reply `session.form.reply({sessionID, formID, answer})`. Verified.
- **Subagents and background:**
  - *"OpenCode 2.x runs a command configured with `subagent: true`, and a `subagent` tool call with `background: true`, as a job in a child session … When the job settles, OpenCode appends one synthetic message … `<subagent …>` envelope."* (OC `subagent-run.ts`). Run states: `running|completed|error|cancelled`.
  - Background shell: `shell` tool with `background:true` returns `metadata.status:"running"` plus `shellID`; `/api/shell` lists running shells.
  - Verified.
- **Quotas:** a server-side provider quota service `packages/web/server/lib/quota/` covering about 23 providers. Verified.
  - Normalized type (OC `packages/ui/src/types/quota.ts`):
    ```ts
    interface UsageWindow { usedPercent; remainingPercent; windowSeconds; resetAfterSeconds; resetAt; resetAtFormatted; resetAfterFormatted; valueLabel? }
    interface ProviderResult { providerId; providerName; ok; configured; error?; planLabel?; usage: { windows: Record<string,UsageWindow>; models?: Record<string,{windows}> } | null; fetchedAt }
    ```
  - **Claude:** `GET https://api.anthropic.com/api/oauth/usage`. Credentials are read-only from Keychain, `~/.claude/.credentials.json`, OpenCode, or env. It *never refreshes* the token (*"refreshing here would sign the user out of Claude Code"*). `limits[]` maps to `5h`/`7d`/per-model `7d`. A 429 cooldown honours `Retry-After`.
  - **Codex:** `GET https://chatgpt.com/backend-api/wham/usage` (`rate_limit.primary_window/secondary_window{used_percent, limit_window_seconds, reset_at}`, `credits`).
  - **Copilot:** `api.github.com/copilot_internal/user`. **OpenCode Go:** `opencode.ai/zen/go/v1/usage`.
  - Token and cost stats via `GET /api/experimental/session/stats`.
- **Terminal:** OpenChamber's own PTY. One WS `/api/terminal/ws` with v3 binary frames; every attach starts with an authoritative `snapshot`; monotonic sequence numbers; `GET /api/terminal/sessions` lets another device adopt a terminal. Verified.
- **Attachments:** images and PDF passed through; HEIC→JPEG; Office documents extracted to text (20 MB / 500k character limits); large pastes become `pasted-context-N.txt`. Verified.
- **Remote access:**
  - Options: LAN (`--lan`, `--ui-password`), Cloudflare/ngrok tunnel (`openchamber tunnel start --provider cloudflare --mode quick --qr`), SSH (desktop), and **Private Relay**.
  - Relay design: outbound WS to a Cloudflare Worker, self-hostable. E2EE *"ECDH P-256 -> HKDF-SHA-256 -> two AES-256-GCM keys (one per direction)"*. Multiplexes HTTP/SSE/WS. Pairing QR carries `{type:'relay', relayUrl, serverId, hostEncPubJwk}`.
  - WebSockets authenticate with a short-lived `oc_url_token` query parameter, because WS can't send headers.
  - Verified (OC `packages/web/server/lib/relay/DOCUMENTATION.md`, `crypto.ts`).
- **Notifications:** Web Push (VAPID) plus APNs via a relay `https://api.openchamber.dev/v1/push/send`. Triggers: completion, error, question, permission. Suppressed while a UI heartbeat reports a focused client. Verified.

### 2.5 Multi-harness status
- **No ACP, Claude, Codex or Pi backend in code.** Verified (code search).
- **Issue #2010 "Add Agent Client Protocol (ACP) support"** (open, 2026-07-02). Re-verified (gh).
  - Acceptance criteria: a stdio ACP client *"gated behind a feature flag so the OpenCode backend stays the default"*. "Should" items include remote HTTP/WebSocket transport, mapping `session/list|resume|close|delete`, slash commands, plans, terminal/fs, and MCP forwarding.
  - Discussion: *"single active client vs parallel clients"*. *"everything that is currently global but would become per-client: providers, models, skills, slash commands, capabilities, auth"* (tomzx, 2026-07-03).
  - Status: a proof of concept in `TomzxForks/openchamber`. A contributor reports (2026-09-30) that with `pi-acp` *"it now works end to end in the UI with Pi. Turns stream with tool calls, and sessions stay listed under their project. They also survive a reload."*
  - No maintainer decision visible beyond bot triage.
- **#1422 "AgentRuntime abstraction"** (open): proposes `listSessions/createSession/sendMessage/abort/streamEvents/getConfig`. **#3654 "Support Pi Harness"** (open). Verified (gh).
- **Community workaround: proxies that impersonate the OpenCode HTTP API** while driving another harness. Verified (gh comments, re-verified):
  - `ftiasch/openchamber-omp-proxy`, `alvins82/omp-openchamber-server` (oh-my-pi)
  - `qingzhu521/openchamber-pi-connector` (one `pi --mode rpc` per session)
  - `qingzhu521/openchamber-mcode-connector`
  - The same idea exists generically as `vacp_bridge` (ACP or Pi RPC → OpenCode REST facade); see doc 30, section 2.3.

### 2.6 Pitfalls from OpenChamber issues (Verified, gh)
- **#1294:** the health check restarted `opencode serve` under heavy load (5 s timeout), losing work.
- **#1869 / #1843:** sessions stuck "busy" because the watchdog was per-directory. Fixed with status reconciliation.
- **#2421 (open):** stale "active" sessions after restart.
- **#2881 (open):** renderer freeze with a 2 GB heap. One reporter had a 4 GB `opencode.db` whose event table held 3.6 GB / 75k rows.
- **#3740 (open):** heavy terminal output blocks the Electron main process.
- **#4288 (open):** startup hang after a transient `agent.list` 500.
- **#2130:** Android saved connections dropped after backgrounding.
- **WS 403 on Android:** the Capacitor WebView origin `https://localhost` was missing from the origin allowlist, and WKWebView custom schemes give `origin: "null"` (OC `sync-context.tsx:2282-2287`).

---

## 3. Happy (`slopus/happy`): Claude Code + Codex (+ ACP) mobile client with E2EE relay

### 3.1 Layout and harnesses
- **Repos:** `happy-cli` and `happy-server` were archived and merged into the monorepo `slopus/happy`. Packages: `happy-app` (Expo 55 / RN 0.83), `happy-cli` (npm `happy` 1.2.5, 2026-09-22), `happy-server` (Fastify 5 + Socket.IO 4 + Prisma/Postgres + Redis + S3/MinIO), `happy-wire` (Zod schemas), `happy-agent`. About 24k stars. Verified (gh, src).
- **Harness types** (HP `packages/happy-cli/src/agent/core/AgentBackend.ts:49-51`): `AgentId = 'claude'|'codex'|'gemini'|'opencode'|'openclaw'|'agy'|'claude-acp'|'codex-acp'`; `AgentTransport = 'native-claude'|'mcp-codex'|'acp'`. Verified.
- **Claude:**
  - *Local mode* spawns the real `claude` TUI and tails its session JSONL (`claude/utils/sessionScanner.ts`), with a `SessionStart` hook injected through a temp settings file.
  - *Remote mode* uses Claude Agent SDK `query()` plus `canUseTool` (`claude/sdk/query.ts`, `claudeRemote.ts`).
  - `loop.ts` switches between them: *"When you want to control your coding agent from your phone, it restarts the session in remote mode. To switch back to your computer, just press any key"*.
  - Verified.
- **Codex:** a hand-rolled JSON-RPC client to **`codex app-server --listen stdio://`** (`codexAppServerClient.ts`). Rationale: *"@openai/codex-sdk … only wraps `codex exec` … NO support for `app-server`, interactive approvals … We need app-server for mobile approval routing"*. Verified.
  - Methods used: `thread/start|resume|fork|read|rollback`, `thread/goal/set|clear`, `turn/start|interrupt`.
  - Notifications used: `thread/tokenUsage/updated`, `item/started|completed`, `item/commandExecution/requestApproval`, `item/fileChange/requestApproval`, `mcpServer/elicitation/request`.
- **Generic ACP:** `agent/acp/AcpBackend.ts` with `@agentclientprotocol/sdk` ^0.14.1. Known agents: `gemini --experimental-acp`, `opencode acp`; anything else via `happy acp -- <cmd>`. OpenCode first-class support is an open issue (#1631). Verified.

### 3.2 Backend-neutral interface and wire schema (verbatim, Verified)
```ts
interface AgentBackend { startSession(initialPrompt?): Promise<{sessionId}>; sendPrompt(sessionId, prompt): Promise<void>;
  cancel(sessionId): Promise<void>; onMessage(handler); offMessage?(handler);
  respondToPermission?(requestId, approved: boolean): Promise<void>; waitForResponseComplete?(timeoutMs?): Promise<void>; dispose(): Promise<void>; }
type AgentMessage =
 | { type:'model-output'; textDelta?; fullText? } | { type:'status'; status:'starting'|'running'|'idle'|'stopped'|'error'; detail? }
 | { type:'tool-call'; toolName; args; callId } | { type:'tool-result'; toolName; result; callId }
 | { type:'permission-request'; id; reason; payload } | { type:'permission-response'; id; approved }
 | { type:'fs-edit'; description; diff?; path? } | { type:'terminal-output'; data } | { type:'event'; name; payload }
 | { type:'token-count'; ... } | { type:'exec-approval-request'; call_id; ... } | { type:'patch-apply-begin'|'patch-apply-end'; ... }
```
`happy-wire` session protocol (HP `packages/happy-wire/src/sessionProtocol.ts`):
```ts
sessionEventSchema = discriminatedUnion('t', [ {t:'text', text, thinking?}, {t:'service', text},
  {t:'tool-call-start', call, name, title, description, args}, {t:'tool-call-end', call},
  {t:'file', ref, name, size, mimeType?, image?:{width,height,thumbhash}}, {t:'turn-start'}, {t:'start', title?},
  {t:'turn-end', status:'completed'|'failed'|'cancelled'}, {t:'stop'} ])
sessionEnvelopeSchema = { id, time, role:'user'|'agent', turn?, subagent?(cuid2), claudeUuid?, codexItemId?,
  usage?: {input_tokens, cache_creation_input_tokens?, cache_read_input_tokens?, output_tokens, context_window?, service_tier?}, ev }
```
- **The maintainers froze it.** Header: *"UNDER REVIEW - NEEDS MORE CAREFUL DESIGN … look at how pi.dev standardizes their agent protocol … Types are kept here for reference but are frozen. Do not add new consumers."*
- **Drafted redesigns** (HP `docs/plans/session-protocol-v2.md`, `provider-envelope-redesign.md`):
  - On v1: *"No permissions in the protocol — permissions use a separate agent state + RPC side-channel, invisible in the chat transcript"*.
  - Proposed direction: *"Adopt OpenCode's message+parts shape … copying this almost verbatim"*, with a `blocked` tool status carrying `PermissionBlock | QuestionBlock`.
  - Also: *"Subagents are child sessions"*, *"Patchable canonical messages, not delta replay"*, *"Every provider adapter normalizes into this exact format at the CLI boundary"*.
  - Verified (docs).
- **The app still fans in several formats** (`sync/typesRaw.ts`): raw Claude JSONL `output`, `codex`, `acp{provider}`, `event`, `session`. Tool views are harness-specific (`CodexBashView.tsx`, `GeminiEditView.tsx`, `knownTools.tsx`). Verified.

### 3.3 Relay, storage, E2EE
- **Transport:** Socket.IO at `/v1/updates`. Handshake `auth:{token, clientType:"user-scoped"|"session-scoped"|"machine-scoped"}`. Verified (HP `docs/protocol.md`).
  - Persistent `update{id, seq, body:{t:…}}` events.
  - Ephemeral `activity`, `usage`, `machine-status`.
  - RPC via `rpc-register/rpc-call` rooms. The CLI registers `permission, abort, switch, bash, readFile, writeFile, listDirectory, getDirectoryTree, ripgrep, difftastic, killSession, spawn-happy-session, …`, with payloads encrypted.
  - **Reliable messages API** `GET /v3/sessions/:id/messages?after_seq|before_seq&limit`, plus POST deduplicated by `localId`. Socket.IO becomes invalidation only. Motivation: *"Known bug: Messages silently lost when socket disconnected"*.
- **Storage:** Postgres `SessionMessage{content:{t:"encrypted", c}, seq, localId}`. Attachments use presigned S3 URLs, or encrypted blobs stored locally. Verified.
- **E2EE** (HP `docs/encryption.md`):
  - Legacy: `tweetnacl.secretbox`.
  - dataKey: AES-256-GCM with a per-session or per-machine DEK wrapped by `tweetnacl.box`.
  - Encrypted: metadata, agentState, messages, artifacts, KV.
  - Plaintext: ids, seq, timestamps, `active`, and ephemeral `usage`/`activity`.
  - Pairing: the CLI shows a QR of `happy://terminal?<base64url(publicKey)>`; the phone answers with an encrypted account secret.
  - **Open issue #1503:** *"Content Key is delivered unauthenticated"*, so a malicious relay could forge the pairing response. Verified (gh).

### 3.4 Permissions, subagents, usage, misc.
- **Permission mode set:** `default|acceptEdits|bypassPermissions|plan|read-only|safe-yolo|yolo` (+`auto`).
  - Claude: `yolo→bypassPermissions`.
  - Codex: `default→untrusted+workspace-write`, `yolo→never`.
  - Pending requests live in the encrypted `agentState.requests`; the phone answers via RPC `'permission'{id, approved, mode?, allowTools?, decision?, updatedInput?}`.
  - Buttons per harness: Claude "Yes / Yes, allow all edits / Yes, allow everything / Yes for this tool / No, tell Claude"; Codex "Yes / Yes for session / Stop and explain".
  - Verified (HP `docs/permission-resolution.md`, `PermissionFooter.tsx`).
- **Subagents:** the envelope's `subagent` cuid2. Claude `Task` and Codex `collabAgentToolCall` (`spawnAgent`/`sendInput`/`wait`/`closeAgent`) are mapped in `codex/utils/sessionProtocolMapper.ts` and rendered by `TaskView.tsx`. Verified.
- **Usage and limits:** `AgentState.usageLimits = {capturedAt, windows:[{id, label?, status?:'allowed'|'allowed_warning'|'rejected', utilization?, resetsAt?}]}`, built from the Claude SDK `rate_limit_event` and `get_usage` (`claude/utils/usageLimits.ts`). UI in `UsageBar.tsx`. Verified.
- **Push and voice:** the CLI sends Expo push (`done|permission|question`), with title and body plaintext to Expo. Voice is an ElevenLabs agent. Verified.
- **Issues** (Verified, gh):
  - #1759: codex ≥0.153 removed `on-failure`, so every session crashed.
  - #1841: `sessionScanner` re-reads JSONL every 3 s, costing 20–40% CPU.
  - #988: silently dead daemon socket.
  - #1682: lost RPC registration during relay degradation.
  - #1453: whole-session history prefetch on web.

---

## 4. Paseo (`getpaseo/paseo`): daemon + WebSocket + E2EE relay, many harnesses

### 4.1 Overview
- *"Orchestrate multiple coding agents from desktop and mobile"*. About 19.2k stars; v0.10.2 (2026-09-29). Verified (gh).
- **Packages:** `packages/server` (Node daemon), `packages/app` (Expo iOS/Android/web), `packages/desktop` (Electron, bundles the daemon), `packages/cli`, `packages/relay`, `packages/protocol`. Verified (PS `docs/architecture.md`).
- **System view** (verbatim): clients connect to the daemon over *"WebSocket (direct or via relay)"*. The daemon fronts *"Claude Agent SDK │ Codex Agent Server │ Copilot ACP │ OpenCode │ Pi"*.

### 4.2 Harness abstraction (PS `packages/server/src/server/agent/`), Verified
- **Two adapter patterns** (PS `docs/providers.md`):
  - *"ACP (Agent Client Protocol) -- recommended. Extend `ACPAgentClient` … The base class handles process spawning, stdio transport, session lifecycle, streaming, permissions, and model discovery."* Built-in ACP providers: `copilot`, plus shims `cursor-acp-agent.ts`, `kimi-acp-agent.ts`, `kiro-acp-agent.ts`, `trae-acp-agent.ts`, and `GenericACPAgentClient` for user-defined `extends: "acp"` providers.
  - *"Direct. Implement the `AgentClient` and `AgentSession` interfaces … Core direct providers: `claude` (`providers/claude/agent.ts`), `codex` (`codex-app-server-agent.ts`), `opencode` (`opencode/runtime-client.ts`), `pi` (`providers/pi/agent.ts`), and `omp`."*
- **Capability flags** (verbatim, `agent-sdk-types.ts`):
```ts
export interface AgentCapabilityFlags {
  [capability: string]: boolean | undefined;
  supportsStreaming: boolean; supportsSessionPersistence: boolean; supportsSessionListing?: boolean;
  supportsDynamicModes: boolean; supportsMcpServers: boolean; supportsNativePaseoTools?: boolean;
  supportsReasoningStream: boolean; supportsToolInvocations: boolean;
  supportsRewindConversation?: boolean; supportsRewindFiles?: boolean; supportsRewindBoth?: boolean; }
export interface AgentPersistenceHandle { provider; sessionId; /** Codex thread id, Claude resume token, etc */ nativeHandle?; metadata? }
export interface AgentUsage { inputTokens?; cachedInputTokens?; outputTokens?; totalCostUsd?; contextWindowMaxTokens?; contextWindowUsedTokens? }
```
- **Canonical stream and timeline** (verbatim, trimmed):
```ts
export type AgentTimelineItem =
  | { type: "user_message"; text; messageId?; clientMessageId? } | { type: "assistant_message"; text; messageId? }
  | { type: "reasoning"; text } | ToolCallTimelineItem /* status: running|completed|failed|canceled + ToolCallDetail */
  | { type: "todo"; items } | { type: "error"; message } | { type: "notification"; level: "info"|"warning"|"error"; message }
  | CompactionTimelineItem { type:"compaction"; status:"loading"|"completed"; trigger?:"auto"|"manual"; preTokens? } | PluginTimelineItem;
export type ToolCallDetail = {type:"shell"; command; cwd?; output?; exitCode?} | {type:"read"; filePath; content?; offset?; limit?}
  | {type:"edit"; filePath; oldString?; newString?; unifiedDiff?} | {type:"write"; filePath; content?}
  | {type:"search"; query; toolName?: "search"|"grep"|"glob"|"web_search"; ...} | {type:"fetch"; url; ...} | {type:"worktree_setup"; ...} | ...
export type AgentStreamEvent =
  | { type: "thread_started"; sessionId; provider } | { type: "turn_started"; provider; turnId? }
  | { type: "turn_completed"; provider; usage?; turnId? } | { type: "usage_updated"; provider; usage; turnId? }
  | { type: "mode_changed"; currentModeId; availableModes } | { type: "model_changed"; runtimeInfo } | { type: "thinking_option_changed"; thinkingOptionId }
  | { type: "turn_failed"; error; code?; diagnostic?; turnId? } | { type: "turn_canceled"; reason; turnId? }
  | { type: "timeline"; item: AgentTimelineItem; turnId?; timestamp? }
  | { type: "permission_requested"; request: AgentPermissionRequest; turnId? } | { type: "permission_resolved"; requestId; resolution; turnId? }
  | { type: "attention_required"; reason: "finished"|"error"|"permission"; timestamp }
  | { type: "provider_subagent"; event: ProviderSubagentInputEvent };
export type AgentPermissionRequestKind = "tool" | "plan" | "question" | "mode" | "other";
export interface AgentPermissionAction { id; label; behavior: "allow"|"deny"; variant?: "primary"|"secondary"|"danger"; intent?: "implement"|"implement_resume"|"dismiss" }
export interface AgentPermissionRequest { id; provider; name; kind; title?; description?; input?; detail?: ToolCallDetail; suggestions?; actions?; metadata? }
export type AgentPermissionResponse = { behavior: "allow"; selectedActionId?; updatedInput?; updatedPermissions? }
                                    | { behavior: "deny"; selectedActionId?; message?; interrupt? };
```
- **`AgentSession` operations:** `run`, `startTurn`, `steerActiveTurn?` (returns `{status:"accepted"|"unavailable"}`), `subscribe`, `streamHistory`, `getAvailableModes/setMode`, `getPendingPermissions`, `respondToPermission`, `describePersistence`, `interrupt`, `close`, `listCommands?`, `setModel?`, `setThinkingOption?`, `setFeature?`, `revertConversation?/revertFiles?/revertBoth?({messageId})`, `tryHandleOutOfBand?`.
- **`AgentClient` operations:** `createSession`, `resumeSession(handle)`, `fetchCatalog` (models plus modes), `listImportableSessions?`, `importSession?`, `isAvailable`, `archiveNativeSession?`, `shutdown?`.
- Verified (PS `agent-sdk-types.ts` L168-797).

### 4.3 Notable rules from Paseo docs (verbatim), Verified (PS `docs/providers.md`)
- *"ACP permission options are rendered as ordered actions and Paseo returns the selected option's exact `optionId`. Agents can therefore encode a single-choice question as multiple options of the same allow kind. Auto-accept does not resolve those chooser requests"*.
- **Pi:** *"talks to it through `pi --mode rpc` … Pi import discovery reads Pi's persisted JSONL session files because Pi RPC does not expose a recent-session listing command"*. *"Pi RPC extension UI dialog requests (`select`, `input`, `editor`, `confirm`) are bridged into Paseo question permissions"*.
- **OpenCode:**
  - *"OpenCode adapters target v1.14.46 and v2.0.10. V2 rejects binaries older than the tested 2.0.10 SDK"*.
  - *"Use OpenCode v2 execution events to trigger turn completion, with active-state and durable-log reconciliation … Do not use `session.wait`"*.
  - *"OpenCode owns user message IDs. Do not pass Paseo-generated IDs to OpenCode prompt APIs"*.
  - An earlier migration moved from per-directory `/event` to `/global/event` (PS `docs/opencode-global-event-baseline.md`, 2026-05-11).
- **Steering:** *"Active-turn steering is an optional `AgentSession.steerActiveTurn` operation … falls back to the normal interrupt-and-replace path only when the adapter reports `unavailable`"*. *"Codex clears pending input when it aborts a turn; Claude does not"*.
- **Turn termination:** *"Provider adapters must terminalize every transient timeline row before emitting the turn's terminal event. Codex may omit the completed `contextCompaction` item"*.
- **Cursor:** *"Cursor uses `cursor/list_available_models` because switching models during discovery writes its saved CLI preferences"*.

### 4.4 Timeline sync to remote clients (PS `docs/timeline-sync.md`), Verified
- **Two delivery paths:**
  - *"Live stream — `agent_stream` WebSocket messages for immediacy. These may be delta-shaped"*.
  - *"Authoritative history — `fetch_agent_timeline_request` for correctness. This always returns full projected timeline items, never lifecycle deltas."*
- **Bounded output:** *"Canonical shell tool output is sliced to 64 KiB"*.
- **Gap recovery:** *"Large unbounded timeline responses can exceed relay frame limits, so catch-up uses bounded pages. Bounded does not mean partial."* Responses carry `seqStart`, `seqEnd`, `sourceSeqRanges`, `collapsed`. The client pages `direction:"after"` until `hasNewer:false`.
- **Heartbeat:** *"Presence is not delivery … Heartbeat is used for notification routing. It must not be used as a correctness gate"*.
- **Durable anchors:** forks use timeline `epoch` + `seqEnd`.
- **Foregrounding:** *"Foregrounding probes a nominally connected session immediately … a failed three-second probe starts reconnecting … This cannot keep a mobile socket alive after the operating system suspends it."*
- **Retry:** backoff from 1 s up to a 30 s ceiling.

### 4.5 Relay and access
- **Relay** (PS `docs/architecture.md`):
  - *"Curve25519 establishes the relay-session secret; NaCl `box` protects each payload with XSalsa20-Poly1305"*.
  - *"The relay is zero-knowledge"*.
  - *"Pairing via QR code transfers the daemon's public key to the client"*.
  - The production relay is a separate Elixir service, `getpaseo/paseo-relay`.
  - Verified.
- **Daemon permissions** (PS `docs/permissions.md`): semantic grants `daemon.read|manage`, `tunnel.manage`, `access.manage`, `workspace.read|write|manage`, `automation.manage`, `hub.execute`. *"Agents and terminals use workspace authority … separate write permissions would claim an isolation boundary the daemon cannot enforce."* Verified.

---

## 5. Codeg (`xintaofei/codeg`): ACP-normalized workspace with server and native mobile apps
- About 3.8k stars; Rust; Apache-2.0. Verified (gh).
- **Architecture** (Verified, [docs.codeg.app/reference/architecture](https://docs.codeg.app/reference/architecture)):
  - Three binaries from the `codeg_lib` crate: `codeg` (Tauri desktop), `codeg-server` (*"Standalone HTTP + WebSocket server"*), and `codeg-mcp` (per-session stdio MCP companion with tools `delegate_to_agent`, `task_progress`, `task_complete`).
  - Desktop UI uses Tauri IPC. Browser UI and the native SwiftUI/Compose apps use *"authenticated HTTP + WebSocket API"*.
  - Agent execution: *"orchestrates agent CLIs as subprocesses using the Agent Client Protocol (ACP)"*.
  - State in `~/.codeg/` (SQLite).
- **Harnesses** (Verified, [supported agents](https://docs.codeg.app/guide/supported-agents); per-agent native session store shown):

| Agent | Launch | Native session store |
|---|---|---|
| Claude Code | `@agentclientprotocol/claude-agent-acp` | `~/.claude/projects/` JSONL |
| Codex | `@agentclientprotocol/codex-acp` | `~/.codex/sessions/` JSONL |
| OpenCode | bundled binary | `~/.local/share/opencode/opencode.db` |
| Grok | native ACP | `~/.grok/sessions/` |
| Pi | listed as "Native CLI (speaks ACP natively)" | `~/.pi/agent/sessions/` |
| Cursor | bundled | `~/.cursor/chats/` (SQLite) |
| Others | Gemini, Cline, Hermes, Kimi, Qoder, Antigravity, DeepSeek Harness, … | — |

  - The Pi "native ACP" claim conflicts with the ACP registry, which lists the `pi-acp` adapter. Unverified.
- **Aggregation:** *"aggregates your sessions from every supported agent CLI into one searchable workspace"* by reading each agent's on-disk store. *"`@`-mention an old session and the agent you're talking to can read it, even when a different agent wrote it"*. Verified (README).
- **Subagents:** *"when an agent spawns sub-agents of its own — Claude Code, Codex, Grok and OpenCode all do — each child gets a card that fills in while it works"*. Verified (README).
- **Errors:** *"on Claude Code and Codex it names the kind: a connection issue, an access issue, a limit reached, a request rejected, a service issue"*. Verified (README).
- **Mobile:** native apps `xintaofei/codeg-ios` and `codeg-android` connect to desktop "Web Service" or `codeg-server` (URL + token; token in Keychain/Keystore). *"Nothing moves onto the phone"*. Verified (README).

---

## 6. Reemoat (`rends-east/reemoat`): ACP daemon with a normalized event log, Noise E2EE relay
- **Positioning:** *"Run Claude Code, Codex, OpenCode, Kimi Code, Grok Build and Cursor on your own machines, and supervise them from your laptop or your phone. Self-hosted, end-to-end encrypted."* AGPL-3.0; a small project (12 stars) but with an unusually detailed decision record (about 34k lines, `docs/DECISIONS.md`). Verified (README).
- **Architecture** (README, verbatim):
  - *"The daemon owns the sessions. It spawns `claude`, `codex`, `kimi`, `opencode`, `grok` or `cursor-agent` over ACP, normalizes all six into one event stream, and exposes them over HTTP and WebSocket."*
  - The control plane issues identity and short-lived capabilities whose `aud` is one machine.
  - The relay *"forwards bytes it holds no key for"*.
  - The daemon dials out, so no open ports.
  - Agent-to-agent messaging uses an injected MCP server with tools `list_agents` and `send_message`.
- **Launch commands** (RM `src/acp/agents.ts`), Verified:
  - `claude-agent-acp` (vendored or on PATH), `kimi acp`, `codex-acp`, `opencode acp`, `grok --no-auto-update agent stdio`, `cursor-agent --disable-auto-update acp`.
  - Logins run as PTY wizards: `claude auth login`, `codex login --device-auth`, `grok --no-auto-update login --device-auth`.
- **E2EE:** `Noise_IK_25519_ChaChaPoly_BLAKE2s` (RM `packages/protocol/src/noise.ts`), tested against the published vectors. The device static key stays in the OS keyring. Verified.
- **Canonical events** (RM `src/events.ts`; full copy in `plan/acp-src/ecosystem/reemoat-events.ts.txt`):
  - *"Every agent collapses into this union. Optional data is T | null, never ?:, so every event serializes to a stable shape."*
  - The union: `session_started | agent_config | text{role, thought, text, messageId} | tool_call{…, parentToolCallId, subagent} | tool_call_update{…, parentToolCallId, backgrounded} | file_change{path, oldText, newText, source:"diff"|"fs_write", toolCallId} | permission_request{permissionId, toolCallId, title, options, decision} | permission_resolved{…, outcome, optionId, by} | elicitation_request | elicitation_resolved | plan | prompt | status{status, exit} | workspace | turn_end{stopReason, usage} | agent_log | context_cleared | other{sessionUpdate, raw} | error`.
  - `SessionStatus = starting|idle|running|blocked|stopping|exited|failed|interrupted|parked` (*"Derived, never stored. `blocked` outranks `running`."*).
  - `StoredEvent { seq; ts; event }`.
  - Verified.
- **Log and replay decisions** (RM `docs/DECISIONS.md` Q5.46-Q5.53), Verified:
  - *"A session's log [is] never truncated"*: prefix eviction had left a conversation starting with the characters `" for"`.
  - Attach replays the newest **2000** events, then `lagged{reason:"backlog"}`. The rest is paged from `GET /sessions/:id/events`.
  - *"Why is attach one synchronous block? … That is the entire reason resume has no gaps and no duplicates"*.
- **Measured ACP agent behaviour** (RM `docs/DECISIONS.md` Q6.x, measured July–Aug 2026; raw excerpt in `plan/acp-src/ecosystem/`). Summarized in doc 30, section 8.3. Key points:
  - Five notifications per simple tool call.
  - 715 streamed argument updates for one `Write`.
  - Subagent lineage is missing on 40–50% of child updates.
  - `usage_update` arrives per token.
  - `available_commands_update` arrives outside turns.
  - Kimi permission text appears only in content blocks.
- **Vendor ACP extensions handled:** Grok `_x.ai/ask_user_question|exit_plan_mode|mcp/elicit|session_notification`; Cursor `cursor/ask_question|create_plan|update_todos|task|generate_image`, plus `subagent_spawned`/`subagent_state_update`; JetBrains AIR `asyncTasks` (*"ACP has no such concept"*). Verified (RM `src/acp/{xai,cursor,asynctasks}.ts`).

---

## 7. Mobile ACP clients and bridges (official "Mobile clients" list plus connectors)

| Product | Platform / stack | How it reaches host agents | Notable details | Evidence |
|---|---|---|---|---|
| **Runmote** | **Flutter** app + FastAPI relay + Python daemon (+ Tauri desktop) | App ↔ relay ↔ daemon over WSS. Daemon pipes ACP stdio. Pairing by QR or 8-digit code. Relay is TLS-only (no E2E claim; *"Session data lives on your machine, not the relay"*). | Daemon quirks layer (RN `src/daemon/main.py`): merges `session/list` with on-disk stores because *"some agents advertise session/list but never answer it (opencode's ACP silently drops the request)"*. Treats `-32601` on `session/close` as success (*"cursor, copilot"*). Maps resume failures (`-32603`, *"codex's 'no rollout found'"*) to "create new". Pre-authenticates Cursor. Out-of-band `filesystem/list_drives` and directory listing for a cwd picker. Dart models: `SegmentKind {message, thought, toolCall, plan}`; `AgentUsage` from `usage_update` plus prompt-result `usage`. | Verified (src) |
| **Agmente** | iOS (Swift); `ACPClient/` and `AppServerClient/` packages | `wss://` to `@rebornix/stdio-to-ws --persist --grace-period 604800` wrapping either an ACP agent or `codex app-server`; Cloudflare Access service tokens supported | `ServerViewModelProtocol`: *"Allows AppViewModel to work with both ACP and Codex server types polymorphically"*. Methods: `fetchSessionList`, `sendNewSession`, `openSession`, `deleteSession`, `archiveSession` (*"Codex app-server only; no-op for ACP"*), `sendPrompt(promptText, images, commandName)`, `sendLoadSession` (*"ACP-specific, no-op for Codex"*). Ships an ACP compatibility matrix (copied to `plan/acp-src/ecosystem/`). | Verified (AG src) |
| **Mobvibe** | Web/PWA + Tauri v2 desktop/mobile; `apps/gateway`, `apps/mobvibe-cli` (has `src/wal/`, `src/e2ee/`) | `npx @mobvibe/cli start` daemon → hosted gateway `api.mobvibe.net` | *"Session content is encrypted on the CLI and decrypted on the WebUI. The gateway routes events but cannot read your content."* Auto-detects agents via the ACP Registry. File explorer with Tree-sitter outline; `@`-mention picker; git changes preview; worktrees. | Verified (README, repo tree) |
| **Ferngeist** | Android (Kotlin/Compose, ACP Kotlin SDK) | Optional `ferngeist-acp-gateway` on `127.0.0.1:5788` with pairing code plus ngrok/cloudflared; or a manual `stdio-to-ws` endpoint | FCM push in the `google` flavour; the `foss` flavour has *"push notifications don't work"*. Phone, 7" and 10" tablet layouts. | Verified (README) |
| **ACP UI** (formulahendry) | Vue; desktop/Android/web | *"Mobile and web builds connect to remote agents over WebSocket"*; `https://` pages require `wss://` | — | Verified (subagent report) |
| **Aptove bridge** | Rust lib/binary | stdio → WebSocket; QR pairing; TLS cert pinning; Local/Cloudflare/Tailscale | *"Push Notifications: Wake the mobile app when the agent responds while backgrounded"*; `AgentPool` keep-alive | Verified (README) |
| **vacp_bridge** (VACP Android, voice) | Go/Rust binary | Exposes ACP Streamable HTTP and an **OpenCode REST facade** over ACP or Pi RPC agents | Pi RPC ↔ ACP mapping table (doc 30, section 2.3) | Verified (README) |
| **VibeAround** | Rust desktop + CLI + web hub + messaging | Same session across desktop, CLI/TUI, web, mobile browser, IM; API bridge between OpenAI/Anthropic/Gemini API shapes | Usage/cost tracking: "🚧 Roadmap" | Verified (README) |
| **tlbx**, **Superlite**, **Shellular**, **TermFold** | browser control station; Rust desktop with browser remote and push; mobile terminals + agents; on-device Debian | — | Listed only | Verified (ACP clients page) |

---

## 8. Zed (reference ACP client)

> From a sub-research pass at Z @`2a97fbf2`. Paths verified there.

- **Crates:**
  - `crates/acp_thread`: thread model shared by native and external agents. `trait AgentConnection` at `connection.rs:91`.
  - `crates/agent_servers`: `AcpConnection` (stdio JSON-RPC) and `custom.rs` with ids `gemini`, `claude-acp`, `codex-acp`, `cursor`.
  - `crates/project/src/agent_server_store.rs`: `ExternalAgentSource {Custom, Registry}`; implementations `LocalRegistryArchiveAgent|LocalRegistryNpxAgent|LocalCustomAgent|RemoteExternalAgentServer`.
  - `agent_registry_store.rs`: fetches the registry CDN JSON.
  - Pins `agent-client-protocol = "=2.2.0"` with `unstable`, `unstable_protocol_v2`.
- **Capability pattern:** optional `Option<Rc<dyn Trait>>` getters on `AgentConnection` (`truncate`, `retry`, `set_title`, `model_selector`, `session_modes`, `session_config_options`, `session_list`, `request_elicitations`, …). External `AcpConnection` **does not** implement truncate, retry, set_title, model_selector or client_user_message_ids; the native agent does.
- **Normalized entries** (verbatim):
  - `enum AgentThreadEntry { UserMessage, AssistantMessage, ToolCall, Elicitation, ContextCompaction }`
  - `enum ToolCallStatus { Pending, WaitingForConfirmation, InProgress, Completed, Failed, Rejected, Canceled }`
  - `enum ToolCallContent { ContentBlock, Diff, LegacyDiff, Terminal, DiffPatch, Other }`
  - `struct TokenUsage { max_tokens, used_tokens, input_tokens, output_tokens, max_output_tokens }`
  - `TOKEN_USAGE_WARNING_THRESHOLD = 0.8`
  - `SubagentSessionInfo { session_id, message_start_index, message_end_index }`
- **Advertised client capabilities:** `fs.read/write_text_file`, `terminal`, `auth.terminal`, `session.config_options.boolean` (beta: compaction, notices), `elicitation{form,url}`, and `_meta{"terminal_output":true,"terminal-auth":true}`.
- **Docs on external-agent gaps:**
  - *"Restoring threads from history, checkpoints, token usage display, and similar features depend on the agent integration."*
  - *"Steering is only available for the Zed Agent, since Zed can't detect turn boundaries for external agents"*.
- **Fallback for non-ACP CLIs:** "Terminal Threads" run any CLI in a PTY and read BEL/OSC for notifications.
- **Remote:** ACP stdio runs over the SSH exec channel (`RemoteClient::build_command`). *"external agents over collab not implemented"*.
- **Issues** (zed-industries/zed):
  - #64391: OAuth loopback fails remotely
  - #64511: secrets visible in the process list
  - #61702: replay retries exhaust memory
  - #60509: tens of GB restoring a large Codex session
  - #64538: updates dropped after resume (kimi)
  - #54602: subagent status not reflected
  - #41357: Codex approval didn't reach the UI

## 9. Other ACP clients (brief; sub-research pass)
- **JetBrains AI Assistant** (2026.2):
  - Registry install or `~/.jetbrains/acp.json` (`agent_servers{name:{command,args,env}}`, `default_mcp_settings`).
  - Registry co-launch with Zed on 2026-01-28 (Unverified, blog summary).
  - *"ACP agents currently lack support in Windows Subsystem for Linux"*.
  - Owns the "AIR" `_meta.jetbrains.air` extension set (doc 30, section 13).
- **CodeCompanion.nvim:**
  - One Lua adapter per agent (`lua/codecompanion/adapters/acp/*.lua`).
  - Claude adapter `commands = { default = {"claude-agent-acp"}, yolo = {"claude-agent-acp","--yolo"} }`.
  - Advertises fs only (no terminal).
- **avante.nvim:** `acp_providers` for gemini, claude-code, goose, codex, opencode, kimi; reconnect counter and heartbeat.
- **Emacs agent-shell:** one file per agent; companion packages `agent-shell-to-go` (Slack mobile) and `agent-shell-tramp` (remote).
- **marimo:** browser to stdio agents through `npx stdio-to-ws "<agent>" --port N`, one port per agent.
- **Obsidian plugins:** Agent Client, Agent Console, Copilot for Obsidian, Obsidian Harness (`.session` vault files).

## 10. Toad (`batrachianai/toad`, Python/Textual TUI, AGPL-3.0)
- **ACP client:** `src/toad/acp/agent.py`. Advertises `{"fs": {"readTextFile": True, "writeTextFile": True}, "terminal": True}`.
  - Handles chunks, `tool_call`, `tool_call_update` (synthesizes the call when an update arrives first, with the comment "*rolls eyes*"), `plan`, `available_commands_update`, `current_mode_update`, `usage_update` (status line `"12.3K (45%) • $0.12"`).
  - Does not handle `config_option_update` or `session_info_update` at the pinned commit.
- **Catalog:** one TOML per agent (`src/toad/data/agents/*.toml`; schema `identity, run_command{OS}, actions{install,login,…}`). Examples: Grok `grok agent stdio`, Claude `claude-agent-acp`, Codex `npx @zed-industries/codex-acp` (a stale package name), OpenCode `opencode acp`. No Pi.
- **Permissions:** keys `a`/`A`/`r`/`R` map to `allow_once`/`allow_always`/`reject_once`/`reject_always`.
- **Terminals:** `terminal/create` runs in a **local PTY** with its own ANSI emulator.
- **Sessions:** SQLite `sessions(… agent_session_id …)`; resume via `session/load`. `toad serve` serves the TUI to a browser.
- **Issues:**
  - #51: crash on `/`
  - #83: duplicate permission keys
  - #307: Grok slash commands

## 11. vibe-kanban (`BloopAI/vibe-kanban`, Rust; **sunsetting**, cloud relay shut down 2026)
- **Executor abstraction** (VK `crates/executors/src/executors/mod.rs`, verbatim):
  - `enum CodingAgent { ClaudeCode, Amp, Gemini, Codex, Opencode, CursorAgent, QwenCode, Copilot, Droid, … }`
  - `enum BaseAgentCapability { SessionFork, SetupHelper, ContextUsage }`
  - `trait StandardCodingAgentExecutor { spawn; spawn_follow_up(session_id, reset_to_message_id); normalize_logs(raw: Arc<MsgStore>, worktree); discover_options; get_availability_info; … }`
- **Transport per harness:**
  - Claude: `-p --output-format=stream-json --input-format=stream-json --include-partial-messages --replay-user-messages --permission-prompt-tool=stdio`.
  - Codex: `app-server`.
  - OpenCode: `serve --port 0` HTTP+SSE.
  - Gemini, Qwen, Copilot: ACP (`acp/harness.rs`).
  - Amp, Cursor, Droid: stream-json.
- **Normalization** (VK `crates/executors/src/logs/mod.rs`):
  - `NormalizedEntry{timestamp, entry_type, content, metadata}`
  - `NormalizedEntryType = UserMessage|UserFeedback|AssistantMessage|ToolUse{tool_name, action_type, status}|SystemMessage|ErrorMessage|Thinking|Loading|NextAction|TokenUsageInfo{total_tokens, model_context_window}|UserAnsweredQuestions`
  - `ToolStatus = Created|Success|Failed|Denied{reason}|PendingApproval{approval_id}|TimedOut`
  - `ActionType = FileRead|FileEdit{changes: Write|Delete|Rename|Edit{unified_diff}}|CommandRun|Search|WebFetch|Tool|TaskCreate{subagent_type}|PlanPresentation|TodoManagement|AskUserQuestion|Other`
  - Streamed as **JSON-Patch** ops over WebSocket. Only raw logs are persisted; the normalized form is re-derived.
- **Approvals:** `PermissionPolicy{Auto, Supervised, Plan}` mapped per harness. Default profiles are **YOLO for every harness**.
- **ACP agents:** no native resume, so it replays its own JSONL as "RESUME CONTEXT" text.
- **Issues:**
  - #858/#769: Codex output drift
  - #3218: 55–60 GB RAM re-normalizing Codex logs
  - #3227: mobile WS doesn't reconnect after tab suspend
  - #2495: Claude sessions stuck "running"
  - #2993: resume keyed by cwd
  - #2365: request for Zed-style generic ACP

## 12. Crystal → Nimbalyst
- **Crystal** (`stravu/crystal`):
  - `AbstractCliManager` with static `CliToolCapabilities{supportsResume, supportsMultipleModels, supportsPermissions}`; node-pty + Claude stream-json / `codex exec --json`.
  - `UnifiedMessage{role, segments: text|tool_call|tool_result|system_info|thinking|diff|error}`.
  - Permissions via an MCP permission-prompt tool bridged over a Unix socket.
  - Issue #18: no rate-limit handling.
- **Nimbalyst** (`nimbalyst/nimbalyst`, MIT; Electron + native iOS/Android):
  - One adapter per protocol: `ClaudeSDKProtocol`, `CodexAppServerProtocol` (default; *"fileChange notifications carry full diffs"*), `CodexACPProtocol`, `CopilotACPProtocol`, `GrokACPProtocol`, `OpenCodeSDKProtocol`, `CursorAgentProtocol` (stream-json).
  - The headless NDJSON path is *"deliberately not an ACP client"* because Cursor/Grok *"report strictly more about their file edits"* there.
  - **Static capability table:** `{slashCommands, skills, compaction: 'rpc'|'slash-command'|'unsupported', contextReporting: 'none'|'token-counts'|'context-window'}`. Examples: claude-code `context-window`; grok-build and cursor `token-counts`; copilot `none`.
  - **Transcript:** `TranscriptEventType = user_message|assistant_message|system_message|tool_call|tool_progress|interactive_prompt|subagent|turn_ended`.
  - `PermissionRequestPayload{decision?: allow|deny, scope?: once|session|always|always-all, respondedBy?: desktop|mobile}`; `PermissionMode = ask|allow-all|bypass-all`.
  - **Mobile sync:** Cloudflare Worker relay with E2E AES-256-GCM. *"The phones render transcripts by running the same TypeScript parsers in a WebView."*
  - **Issues:**
    - #1563: OpenCode `permission.updated` ignored, so turns hang
    - #1348: permissions auto-denied unseen
    - #1391: sync cursor advanced past failed pushes
    - #1438: stuck running queues mobile prompts

## 13. Conductor (conductor.build; closed source, macOS)
- **Harnesses:** bundles Claude Code, Codex and OpenCode; Cursor via its API. Claude via Agent SDK; a Codex "alternative SDK" toggle.
- **Workspaces:** one worktree per workspace; checkpoints revert code and chat.
- **"Big Terminal Mode":** runs raw TUIs with YOLO flags for harnesses lacking native chat.
- **Conductor Cloud:** REST `api.conductor.build/v0`, polling `after=<id>`, *no SSE/WebSocket documented*.
- **Changelog pitfalls:** interactive questions stuck (0.63.0); "Session not found" after restart.
- Verified (docs per sub-research pass).

## 14. Omnara (legacy wrapper; pivoted)
- **Deprecation notice:** *"built as a wrapper around the Claude Code CLI, which became unfeasible to maintain with Claude Code's constant updates"*.
- **Legacy design:**
  - PTY + JSONL tail for Claude. **Permission prompts were screen-scraped** and keystrokes typed back.
  - A patched Codex fork.
  - A flat `Message{sender_type, content, requires_user_input}` schema.
  - SSE via Postgres `LISTEN/NOTIFY`; Expo push.
- **Issues:**
  - #276/#183: scraped popups hang
  - #187: subagent permission prompts not shown
  - #215: resume re-sent old notifications
  - #200: users asked for ACP
- Verified (OL README and issues per sub-research pass).

---

## 15. Codex-first and other clients; harness programmatic interfaces

> From a sub-research pass at pinned commits:
> - CODEX = `openai/codex@7135b303`
> - CSDK = npm `@anthropic-ai/claude-agent-sdk@0.3.287` `sdk.d.ts`
> - PI = `earendil-works/pi@7fbbd5f4` (`badlogic/pi-mono` redirects here)
> - GROK = `xai-org/grok-build@2bdd1d6a`
> - GEM = `google-gemini/gemini-cli@c9096a84`
> - T3 = `pingdotgg/t3code@20012ebd`
> - CM = `Dimillian/CodexMonitor@dd61b9ab`
> - AA = `coder/agentapi@7c468d5b`
> - CCUI = `siteboon/claudecodeui@dc7cb6c6`
> - SS = `superset-sh/superset@ae0d3e05`
> - EM = `generalaction/emdash@a39d9c83`
> - SC = `imbue-ai/sculptor@f847102a`
> - OPC = `winfunc/opcode@d1ca30a3`
> - XUM = `coder/xum@5169ca04`
>
> Tags are as reported, with source paths given.

### 15.1 Harness interface: OpenAI Codex `codex app-server` (JSON-RPC, "v2" API)

**Transports** (Verified, CODEX `codex-rs/app-server-transport/src/transport/mod.rs` L81-120, `websocket.rs` L61-155):
- `AppServerTransport { Stdio, UnixSocket{socket_path}, WebSocket{bind_address}, Off }`; listen URLs `stdio://` (default), `unix://`, `ws://IP:PORT`.
- WebSocket refuses non-loopback binds without auth (*"configure `--ws-auth capability-token` or `--ws-auth signed-bearer-token`"*).
- It **rejects requests carrying an `Origin` header**, so browsers cannot connect directly.
- Serves `/readyz` and `/healthz`.
- Docs: *"WebSocket transport is experimental and unsupported."* ([learn.chatgpt.com/docs/app-server](https://learn.chatgpt.com/docs/app-server)).
- Schema generation: `codex app-server generate-ts --out DIR` / `generate-json-schema`.

**Daemon and Remote Control** (Verified, CODEX `codex-rs/app-server-daemon/README.md`; `transport/remote_control/protocol.rs` L10-80, L300-354):
- `codex app-server daemon start|restart|update|enable-remote-control|…` backs *"remote clients such as the desktop and mobile apps"*.
- The app-server dials **outbound** to `wss://chatgpt.com/backend-api/wham/remote/control/server`, with `/enroll` and `/pair` (`pairing_code`).
- RPCs: `remoteControl/enable|disable|status/read|pairing/start|pairing/status|client/list|client/revoke`.
- The relay is OpenAI-owned; nothing shows third-party clients can use it. Unverified.

**Handshake:**
- `initialize {clientInfo:{name,title,version}, capabilities:{experimentalApi, optOutNotificationMethods}}` → `initialized`.
- Superset: *"Codex's `initialize` response advertises no capabilities, so the only handshake signal is the version inside `userAgent`"*. Verified (SS `packages/chat-runtime/README.md`).

**Methods** (selected, verbatim; Verified, CODEX `codex-rs/app-server-protocol/src/protocol/common.rs`):
- **Threads:** `thread/start|resume|fork|archive|unarchive|delete|unsubscribe`, `thread/name/set`, `thread/list|search|read`, `thread/turns/list`, `thread/items/list`, `thread/loaded/list`, `thread/compact/start`, `thread/revert`, `thread/shellCommand`, `thread/queue/add|list|update|delete|reorder|start`, `thread/goal/set|get|clear`, `thread/attachment/add|list|remove`, `thread/backgroundTerminals/list|terminate|clean`.
- **Turns:** `turn/start`, `turn/steer`, `turn/interrupt`, `turn/settings/update`, `review/start`.
- **Models, config, account:** `model/list`, `collaborationMode/list`, `permissionProfile/list`, `config/read`, `config/value/write`, `account/read`, `account/login/start|cancel`, `account/logout`, `account/rateLimits/read`, `account/usage/read`.
- **Execution and files:** `command/exec`, `process/spawn|writeStdin|kill|resizePty`, `fs/readFile|writeFile|readDirectory|watch`, `fuzzyFileSearch*`, `gitDiffToRemote`.
- **Extensions:** `skills/list`, `plugin/*`, `mcpServerStatus/list`.

**Server → client requests:** `item/commandExecution/requestApproval`, `item/fileChange/requestApproval`, `item/permissions/requestApproval`, `item/tool/requestUserInput`, `mcpServer/elicitation/request`, `item/tool/call`, `account/chatgptAuthTokens/refresh`.

**Server → client notifications:**
- Thread: `thread/started`, `thread/status/changed`, `thread/tokenUsage/updated`, `thread/queue/changed`, `thread/compacted`
- Turn: `turn/started`, `turn/completed`, `turn/diff/updated`, `turn/plan/updated`
- Items: `item/started`, `item/completed`, `item/agentMessage/delta`, `item/reasoning/*Delta`, `item/commandExecution/outputDelta`, `item/fileChange/outputDelta|patchUpdated`, `item/mcpToolCall/progress`
- Other: `serverRequest/resolved`, `account/rateLimits/updated`, `model/rerouted`, `error`, `warning`

**Lifecycle:** `turn/started` → `item/started` → `item/*/delta` → `item/completed` → `turn/completed`.

**Approvals:** the client replies to the server's request with `{decision}`. Verified (CODEX `v2/item.rs` L1625-1652):
```rust
pub enum CommandExecutionApprovalDecision { Accept, AcceptForSession, AcceptWithExecpolicyAmendment { execpolicy_amendment },
  ApplyNetworkPolicyAmendment { network_policy_amendment }, Decline, Cancel }
pub enum FileChangeApprovalDecision { Accept, AcceptForSession, Decline, Cancel }
```

**Policy and status enums** (Verified, CODEX `v2/shared.rs`, `v2/thread.rs`):
- `AskForApproval = untrusted | on-request | Granular{…} | never`. `on-failure` was removed, which broke Happy (#1759).
- `SandboxMode = read-only | workspace-write | danger-full-access`.
- `ApprovalsReviewer = user | auto_review`.
- `ThreadStatus = NotLoaded | Idle | SystemError | Active{active_flags}` with `ThreadActiveFlag = WaitingOnApproval | WaitingOnUserInput`.

**Items** (verbatim, Verified, CODEX `v2/item.rs` L236-430):
```
ThreadItem = UserMessage{id, client_id, content: Vec<UserInput>} | HookPrompt | AgentMessage{id, text, phase, …} | FunctionCallOutput | Plan{id, text}
 | Reasoning{id, summary, content} | CommandExecution{id, command, cwd, process_id, status, aggregated_output, exit_code, duration_ms, …}
 | FileChange{id, changes, status} | McpToolCall{id, server, tool, status, arguments, result, error, …} | DynamicToolCall
 | CollabAgentToolCall{id, tool, status, sender_thread_id, receiver_thread_ids, prompt, model, reasoning_effort, agents_states}
 | SubAgentActivity{id, kind, agent_thread_id, agent_path} | WebSearch | ImageView | Sleep | ImageGeneration | EnteredReviewMode | ExitedReviewMode | ContextCompaction
CollabAgentTool = SpawnAgent | SendInput | ResumeAgent | Wait | CloseAgent | SendMessage | FollowupTask | InterruptAgent | ListAgents
UserInput = Text | Image | LocalImage | Audio | LocalAudio | Skill{name,path} | Mention{name,path}
TurnStatus = Completed | Interrupted | Failed | InProgress
```
Subagents are separate threads, linked by `parent_thread_id` and `receiver_thread_ids`.

**Quotas** (Verified, CODEX `v2/account.rs`):
```
GetAccountRateLimitsResponse { ordinary_usage_allowed, rate_limits: RateLimitSnapshot, rate_limits_by_limit_id: Map<limit_id, RateLimitSnapshot>, rate_limit_reset_credits, account_id, … }
RateLimitSnapshot { limit_id, limit_name, primary: RateLimitWindow?, secondary?, credits: {has_credits, unlimited, balance}?, plan_type, rate_limit_reached_type, … }
RateLimitWindow { used_percent: i32, window_duration_mins, resets_at }
thread/tokenUsage/updated { thread_id, turn_id, token_usage: { total, last, model_context_window } }
```
- `account/rateLimits/updated` is partial (sparse), so it must be merged by id.

**Lighter alternative:** `@openai/codex-sdk` wraps `codex exec --experimental-json` (events `thread.started|turn.*|item.*|error`). Superset rejected it because it *"drops tool arguments and diff text"*.

**Upstream pitfalls** (openai/codex): reconnect loop #18960; "queued follow-up no longer exists" #44781/#45019; long-thread memory #21134.

### 15.2 Harness interface: Claude Code (Agent SDK, stream-json control protocol, Remote Control)

**SDK message union** (Verified, CSDK `sdk.d.ts` L5326):
- `SDKAssistantMessage | SDKUserMessage | SDKUserMessageReplay | SDKResultMessage | SDKSystemMessage | SDKPartialAssistantMessage | SDKCompactBoundaryMessage | SDKStatusMessage | SDKAPIRetryMessage | SDKToolProgressMessage | SDKAuthStatusMessage | SDKTaskNotificationMessage | SDKTaskStartedMessage | SDKTaskUpdatedMessage | SDKTaskProgressMessage | SDKBackgroundTasksChangedMessage | SDKSessionStateChangedMessage | SDKCommandsChangedMessage | SDKRateLimitEvent | SDKPermissionDeniedMessage | SDKElicitationCompleteMessage | …`

**Key shapes:**
- **`system/init`:** `{apiKeySource, claude_code_version, cwd, tools[], mcp_servers[{name,status}], model, permissionMode, slash_commands[], skills[], plugins[], capabilities?: string[]}`. Capabilities are used for feature detection, e.g. `interrupt_receipt_v1`.
- **`assistant`:** `{message: BetaMessage, parent_tool_use_id, uuid, session_id, subagent_type?, context_usage?}`.
- **`stream_event`:** requires `--include-partial-messages`.
- **`result`:** `success|error_during_execution|error_max_turns|error_max_budget_usd|…` with `total_cost_usd`, `usage`, `modelUsage`, `permission_denials[]`.
- **`rate_limit_event`:**
  ```
  {rate_limit_info:{status:'allowed'|'allowed_warning'|'rejected', resetsAt?, rateLimitType?:'five_hour'|'seven_day'|'seven_day_opus'|'seven_day_sonnet'|'seven_day_overage_included'|'overage', utilization?, …}}
  ```
  It is sparse: one window per event.
- **Subagents and background tasks:** `task_started{task_id, tool_use_id?, description, subagent_type?, is_backgrounded?, spawn_depth?}`, `task_updated{patch:{status: pending|running|completed|failed|killed|paused}}`, `task_progress{usage:{total_tokens, tool_uses, duration_ms}}`, `task_notification{status, output_file, summary}`.
  - Subagent messages carry `parent_tool_use_id`. Text and thinking require `--forward-subagent-text`.

**Permissions** (Verified, CSDK):
```ts
export declare type PermissionMode = 'default' | 'acceptEdits' | 'bypassPermissions' | 'plan' | 'dontAsk' | 'auto';
export declare type CanUseTool = (toolName: string, input: Record<string, unknown>, options: { signal: AbortSignal; suggestions?: PermissionUpdate[];
  blockedPath?: string; decisionReason?; title?; displayName?; description?; … }) => Promise<PermissionResult>;
export declare type PermissionResult = { behavior: 'allow'; updatedInput?; updatedPermissions?: PermissionUpdate[]; toolUseID? }
  | { behavior: 'deny'; message: string; interrupt?: boolean; toolUseID? };
```

**Control protocol under the SDK (stream-json):**
- Envelopes: `{type:'control_request', request_id, request}` and `{type:'control_response', response}`.
- Request subtypes: `can_use_tool`, `initialize`, `interrupt`, `set_permission_mode`, `set_model`, `get_usage` (*"a usage meter"*), `rewind_files`, `stop_task`, `background_tasks`, `get_task_output`, `mcp_*`, `elicitation`.
- Query methods: `interrupt()`, `setPermissionMode()`, `setModel()`, `supportedModels()`, `supportedCommands()`, `getContextUsage()`, `accountInfo()`, `rewindFiles()`, `streamInput()`, `stopTask()`, `backgroundTasks()`.
- Session helpers: `listSessions`, `getSessionMessages`, `forkSession`, `deleteSession`, `renameSession`, `listSubagents`, `getSubagentMessages`.
- CLI equivalent: `claude -p --output-format stream-json --input-format stream-json --verbose --include-partial-messages`, plus `--permission-prompt-tool <mcp tool>`, `--resume <id>`, `--bare`.
- Transcripts live in `~/.claude/projects/**/*.jsonl`.
- Verified (CSDK; [code.claude.com/docs/en/headless](https://code.claude.com/docs/en/headless)).

**Official Remote Control** (Verified, [code.claude.com/docs/en/remote-control](https://code.claude.com/docs/en/remote-control)):
- Started with `claude remote-control` (server mode: `--spawn same-dir|worktree|session`, `--capacity N` default 32, `--permission-mode`) or `/remote-control`.
- Clients are claude.ai/code and the Claude iOS/Android apps.
- *"outbound HTTPS requests only and never opens inbound ports… registers with the Anthropic API and polls for work."*
- *"Pro, Max, Team, and Enterprise plans. API keys are not supported."*
- Permission prompts and `AskUserQuestion` stay open; other dialogs expire after 5 minutes.
- No public third-party protocol was found. Unverified.

**Policy risk:**
- The Agent SDK docs reportedly say *"Unless previously approved, Anthropic does not allow third party developers to offer claude.ai login or rate limits for their products"*. Unverified (secondary).
- CloudCLI #300: the SDK path required an API key, so a fork spawned the `claude` CLI for subscription auth.

**stream-json pitfalls** (anthropics/claude-code): missing `result` #8126; hangs #39700; undocumented `--input-format stream-json` #24594; elicitation hooks not fired #38755.

### 15.3 Harness interface: Pi (`pi --mode rpc`)
- *"RPC mode runs Pi as a long-lived subprocess controlled through JSON records on stdin and stdout"* with strict JSONL.
  - Framing pitfall: *"Node.js `readline` also splits on `U+2028` and `U+2029`, which are valid inside JSON strings."*
  - Verified (PI `packages/coding-agent/docs/rpc.md`).
- **Commands:** `prompt`, `steer`, `follow_up`, `abort`, `bash`, `new_session`, `switch_session`, `fork`, `clone`, `get_state`, `get_messages`, `get_entries`, `get_tree`, `get_session_stats`, `get_available_models`, `get_available_thinking_levels`, `get_commands`, `set_model`, `set_thinking_level`, `set_steering_mode`, `set_follow_up_mode`, `set_auto_compaction`, `compact`, `clear_queue`, `export_html`. Verified (PI `src/modes/rpc/rpc-types.ts`).
- **Events:** `agent_start|end|settled`, `turn_start|end`, `message_start|update|end` (with `text_*`, `thinking_*`, `toolcall_*`), `tool_execution_start|update|end`, `queue_update{steering, followUp}`, `compaction_start|end`, `auto_retry_start|end`, `session_info_changed`. Verified (PI `docs/json.md`).
- **Extension UI:** `extension_ui_request{id, method: select|confirm|input|editor|notify|setStatus}` and `extension_ui_response`. Verified (PI `docs/rpc-extension-ui.md`).
- **No permission system:** *"Pi does not include a built-in permission system… runs with the permissions of the user"*. Verified (PI `README.md` L42).
- **No session listing over RPC.** Paseo reads Pi's JSONL files for import. Verified (Paseo docs).

### 15.4 Harness interface: Grok Build (xAI)
- **Source and launch:** open source `xai-org/grok-build`, Apache-2.0, about 27k stars. *"Grok Build also provides full ACP support to build your own bots and agent orchestration apps."* Verified ([x.ai/news/grok-build-cli](https://x.ai/news/grok-build-cli), repo).
- **Agent mode** (Verified, GROK `crates/codegen/xai-grok-pager/docs/user-guide/15-agent-mode.md`):
  - `grok agent [--always-approve|--yolo] [-m MODEL] stdio`
  - **`grok agent serve --bind 127.0.0.1:2419 --secret <token>`**: a **WebSocket ACP server** that *"keeps state across client reconnects"*
  - `grok agent headless --grok-ws-url wss://relay/ws` (relay)
  - `--leader` (a shared process)
- **ACP specifics:**
  - Per-session `_meta` on `session/new`: `{yoloMode, autoMode, rules, systemPromptOverride, agentProfile}`.
  - `configOptions` `model` and `reasoning_effort`.
  - Vendor methods `x.ai/fs/*`, `x.ai/git/*`, `x.ai/terminal/*`, `x.ai/session/fork`, `x.ai/rewind/*`, `x.ai/auth/*`; notifications `x.ai/session_notification`, `x.ai/fs_notify`.
  - Reemoat additionally observed the `_x.ai/ask_user_question|exit_plan_mode|mcp/elicit` requests (section 6).
- **Headless:** `--output-format plain|json|streaming-json|streaming-messages-json`. The last is Claude-stream-json-compatible. Verified (GROK `…/14-headless-mode.md`).

### 15.5 Harness interfaces: Gemini CLI, OpenCode, Kiro, Cursor
- **Gemini CLI:** `gemini --acp` (older `--experimental-acp`). Methods include `setSessionMode` (*"changing the approval level… e.g. auto-approve"*) and `unstable_setSessionModel`. Headless `--output-format json|stream-json` (`init, message, tool_use, tool_result, error, result`). Verified (GEM `docs/cli/acp-mode.md`, `docs/cli/headless.md`).
- **OpenCode 1.x:**
  - `opencode serve` route groups: `event` (`/event`), `global` (`/global/event`, `/global/health`), `permission`, `question`, `session`, `pty`, `provider`, `mcp`, `file`, `project`, `workspace`, `sync`.
  - `opencode acp` wraps its own HTTP API via SDK v2. Permission options are `{optionId:"once", kind:"allow_once"}`, `{optionId:"always", kind:"allow_always"}`, `{optionId:"reject", kind:"reject_once"}`.
  - Verified (OpenCode `packages/opencode/src/acp/permission.ts` L21-23).
  - Pitfalls: `opencode serve` holds the shared SQLite and hangs CLI runs (t3code #9065); orphaned serve processes (t3code #5241); a closed event enum broke on `question.asked` (vibe-kanban #2088).
  - OpenCode 2.x is covered in sections 1 and 2.
- **Kiro CLI:**
  - `kiro-cli acp`: `session/new|load|prompt|cancel|set_mode|set_model`; v3 uses `session/set_config_option`.
  - Extensions: `_kiro.dev/commands/*`, `_kiro.dev/mcp/oauth_request`, `_kiro.dev/compaction/status`.
  - Sessions in `~/.kiro/sessions/cli/<id>.json(l)`.
  - Verified ([kiro.dev/docs/cli/acp](https://kiro.dev/docs/cli/acp/)).
- **Cursor:**
  - `cursor-agent acp`; legacy `-p --output-format stream-json`.
  - **Cloud Agents API:** `POST/GET /v1/agents`, `POST /v1/agents/{id}/runs`, `GET …/runs/{runId}/stream` (SSE `status, assistant, thinking, tool_call, result, error, done, heartbeat`), `GET /v1/agents/{id}/usage`.
  - Verified ([cursor.com/docs/cloud-agent/api/endpoints](https://cursor.com/docs/cloud-agent/api/endpoints)).

### 15.6 t3code (`pingdotgg/t3code`): the most complete multi-harness reference
- **Surfaces:** mobile (Expo), hosted web, Electron, `t3` CLI server.
- **Six built-in drivers** (`apps/server/src/provider/builtInDrivers.ts`):

| Driver | Integration |
|---|---|
| Codex | app-server stdio, schemas generated from upstream `codex-rs/app-server-protocol` at a pinned `UPSTREAM_REF` |
| Claude | `@anthropic-ai/claude-agent-sdk` with `canUseTool` (`Layers/ClaudeAdapter.ts`, about 5.7k lines) |
| Cursor, Grok, Antigravity | ACP (`acp/AcpSessionRuntime.ts`, `packages/effect-acp`) |
| OpenCode | `opencode serve` + `@opencode-ai/sdk/v2` |

- **Adapter interface** (verbatim, abridged; T3 `apps/server/src/provider/Services/ProviderAdapter.ts`):
```ts
export interface ProviderAdapterCapabilities { readonly sessionModelSwitch: "in-session" | "unsupported";
  readonly promptlessTurnContinuation?: boolean; readonly supportsConversationRollback?: boolean; }
export interface ProviderAdapterShape<TError> { readonly provider; readonly capabilities: ProviderAdapterCapabilities;
  startSession(input); sendTurn(input); compaction?: {type:"native"; start(...)} | {type:"slash-command"; command: `/${string}`};
  interruptTurn(threadId, turnId?); respondToRequest(threadId, requestId, decision: ProviderApprovalDecision);
  respondToUserInput(threadId, requestId, answers); stopSession; listSessions; hasSession; readThread; rollbackThread(threadId, numTurns);
  stopAll; readonly streamEvents: Stream.Stream<ProviderRuntimeEvent>; }
```
- **Driver vs instance:** *"two accounts using the same driver do not share mutable session or catalog state"* (`ProviderDriver.ts`).
- **Canonical event union `ProviderRuntimeEvent`** (49 types; T3 `packages/contracts/src/providerRuntime.ts`):
  - Base: `{eventId, provider, providerInstanceId?, threadId, createdAt, turnId?, itemId?, requestId?, providerRefs?, raw?: {source, method?, messageType?, payload}}`.
  - `raw.source` is one of `codex.app-server.notification|request`, `claude.sdk.message|permission`, `opencode.sdk.event`, `acp.jsonrpc`, `acp.<x>.extension`.
  - Types:
    - Session and thread: `session.started|configured|state.changed|exited`, `thread.started|state.changed|metadata.updated|token-usage.updated`
    - Turn: `turn.started|completed|aborted|plan.updated|proposed.delta|proposed.completed|diff.updated`
    - Items and content: `item.started|updated|completed`, `content.delta`
    - Requests and input: `request.opened|resolved`, `user-input.requested|resolved`
    - Tasks and tools: `task.started|progress|updated|completed`, `hook.*`, `tool.progress|summary|denied`
    - Account and runtime: `auth.status`, `account.updated`, `account.rate-limits.updated`, `mcp.status.updated`, `model.rerouted`, `runtime.warning|error`
  - `CanonicalItemType = user_message|assistant_message|reasoning|plan|command_execution|file_change|mcp_tool_call|dynamic_tool_call|collab_agent_tool_call|web_search|image_view|review_entered|review_exited|context_compaction|error|unknown`
  - `CanonicalRequestType = command_execution_approval|file_read_approval|file_change_approval|apply_patch_approval|exec_command_approval|mcp_elicitation_approval|permission_approval|tool_user_input|dynamic_tool_call|auth_tokens_refresh|unknown`
  - `RuntimeContentStreamKind = assistant_text|reasoning_text|reasoning_summary_text|plan_text|command_output|file_change_output|unknown`
  - Subagent linkage fields: `agentKind: "agent"|"background"`, `agentId`, `parentToolUseId`, `parentAgentId`, `agentPath`. Comment: *"Claude reports per-activation deltas; Codex reports cumulative totals — the merge strategy is provider-specific"*.
- **Orchestration is event-sourced** (T3 `packages/contracts/src/orchestration.ts`, `docs/internals/overview.md`):
  - *"The event log is the source of truth… Events, persisted projections, and the accepted command receipt commit in one database transaction… A command acknowledgement… means the intent committed, not that the provider… finished."*
  - SQLite table `orchestration_events(sequence, event_id, aggregate_kind, stream_id, stream_version, event_type, …, payload_json)` plus projections; 54 migrations; checkpoints in hidden Git refs.
- **Modes:**
  - `RuntimeMode = approval-required | auto-accept-edits | auto | full-access` (default `full-access`); `ProviderInteractionMode = default | plan`; `ProviderApprovalDecision = accept | acceptForSession | acceptAlways | decline | cancel`.
  - Codex mapping: `approval-required → untrusted/read-only`, `auto → on-request/workspace-write/auto_review`, `full-access → never/danger-full-access`.
  - *"Auto… providers without an equivalent, including OpenCode and Antigravity, fall back to asking."*
- **Wire:** Effect RPC JSON over WebSocket `/ws` with a short-lived `wsTicket`; about 150 methods (`orchestration.dispatchCommand|subscribeShell|subscribeThread|getTurnDiff`, `terminal.open|attach|write|resize`, `attachments.createUploadUrl`, `agentSessions.scan|import`, `provider.auth.*`). Shell stream resumes `afterSequence`.
- **Capabilities:** the `ServerProvider` snapshot carries `showInteractionModeToggle`, `reportsContextWindow`, `requiresNewThreadForModelChange`, `supportsConversationRollback`, `setup{canAuthenticate, canInstall}`, `usageLimits`, `compatibilityAdvisory`. *"Clients must use advertised capabilities and handle their absence"*; `ForwardCompatibleArray` exists so an *"older client must not fail the whole config decode"*.
- **Quotas:** `ServerProviderUsageWindow{id, kind: session|weekly|monthly|other, label, usedPercent, resetsAt?, windowDurationMins?}` with per-driver normalizers (`codexUsageLimits.ts`, `claudeUsageLimits.ts`, `cursorUsageLimits.ts`, `grokUsageLimits.ts`, `openCodeUsageLimits.ts`). Sparse updates are merged by `id`.
- **Terminal:** node-pty (5,000 lines / 8 MiB). **Attachments:** 100 per turn; images 10 MiB; *"A path in the prompt does not grant filesystem access."*
- **Remote and mobile:**
  - Access: `t3 serve --host` + `t3 pair` (QR), `--tailscale-serve`, SSH, or T3 Connect (Clerk + Cloudflare tunnels; *"relay Worker does not proxy their HTTP or WebSocket sessions"*; DPoP-bound credentials).
  - *"A long mobile background suspension forces replacement because the OS can kill a socket without reporting closure."*
  - *"Reconnection does not automatically replay mutations."*
  - Push requires T3 Connect.
- **Issues** (pingdotgg/t3code):
  - #11799: pending approval never resolves when the provider dies.
  - #14391: resumed Claude session re-sent every earlier turn.
  - Subagent display drift: #8499 (Codex), #14006 (Cursor), #9892 (Grok), #14003 (Claude token counts).
  - #12170: sparse `rate_limit_event` mis-published.
  - #14516: reconnect loop.
  - #13995: iOS send queue.
  - #11458: OpenCode auto ignored user patterns.
- All Verified per the sub-research pass (paths above).

### 15.7 CodexMonitor (`Dimillian/CodexMonitor`): Codex only; stale since 2026-03-26
- **Stack and scope:** Tauri (Rust + React). Other harnesses are *"Not planned"* (#86).
- **app-server use:** spawns `codex app-server` over stdio and calls `initialize {"clientInfo":{"name":"codex_monitor"},"capabilities":{"experimentalApi":true}}`. One process serves several workspaces, routing events per thread.
  - Unhandled `mcpServer/elicitation/request` makes approvals look hung (#612).
  - It checks both camelCase and snake_case fields because of schema drift.
- **`AccessMode`** mapping:

  | Mode | `sandboxPolicy` | `approvalPolicy` |
  |---|---|---|
  | `full-access` | `dangerFullAccess` | `never` |
  | `read-only` | `readOnly` | `on-request` |
  | `current` | `workspaceWrite{writableRoots, networkAccess}` | `on-request` |

  "Remember" writes a `prefix_rule(pattern=[…], decision="allow")` to the Codex rules file.
- **Usage display:** rate limits come from `account/rateLimits/read|updated` (primary/secondary windows plus credits), token history from scanning rollout JSONL, and the context ring from `thread/tokenUsage/updated`. Subagents are shown as a thread tree.
- **Remote:** `codex_monitor_daemon` speaks NDJSON-RPC over TCP `127.0.0.1:4732`, with auth as the first call. Only idempotent methods are retried after a disconnect. iOS works over Tailscale only (*"Hosted relay providers are out of scope"*).
- **Issue #598:** remote mode validated paths on the client filesystem.
- Verified (CM paths per sub-research pass).

### 15.8 CloudCLI / claudecodeui (`siteboon/claudecodeui`): Claude, Codex, Cursor, OpenCode
- **Size and scope:** about 13.9k stars. `LLMProvider = 'claude' | 'codex' | 'cursor' | 'opencode'`.
- **Seven provider facets:** `IProviderRuntime`, `IProviderModels`, `IProviderAuth`, `IProviderMcp`, `IProviderSkills`, `IProviderSessions`, `IProviderSessionSynchronizer`, at `server/modules/providers/list/<p>/<p>-*.provider.ts`.
- **Runtimes:**

  | Provider | Runtime |
  |---|---|
  | Claude | Agent SDK `query` |
  | Codex | `@openai/codex-sdk` for runs; minimal app-server client for auxiliary calls |
  | Cursor | `cursor-agent --output-format stream-json [-f]` |
  | OpenCode | per-turn `opencode run --format json` plus reading `opencode.db` |

  OpenCode note: *"In non-interactive `run` mode any `ask` rule is denied"*.
- **Normalized message** (verbatim; CCUI `server/shared/types.ts`):
```ts
export type MessageKind = 'text'|'tool_use'|'tool_result'|'thinking'|'stream_delta'|'stream_end'|'error'|'complete'|'status'
  |'permission_request'|'permission_resolved'|'permission_cancelled'|'session_created'|'history_truncated'|'task_notification'|'task_status';
export type NormalizedMessage = { id; sessionId; timestamp; provider: LLMProvider; kind: MessageKind; seq?; role?; content?; model?;
  toolName?; toolInput?; toolId?; toolResult?: {content?; isError?}; requestId?; status?; subagentTools?; subagent?; taskId?; usage?: {totalTokens; toolUses; durationMs}; … };
```
- **WebSocket `/ws`:**
  - Client verbs: `chat.send|abort|stop-task|subscribe|permission-response|edit-send`.
  - Exactly one `complete` per run.
  - A per-run `seq` with a 5,000-chunk replay buffer; `chat.subscribe{sessions:[{sessionId,lastSeq}]}`; refresh over REST if the buffer no longer covers it.
  - `chat_subscribed` carries `pendingPermissions`.
- **Session indexing:** scans `~/.claude/projects`, `~/.codex/sessions`, `~/.cursor/projects`, and `opencode.db`.
- **Issues:** #300 (SDK needed an API key); #1261 (Codex should use app-server); #1366 (Codex history drops user prompts); #187 (SSH remote requested).

### 15.9 coder/agentapi: HTTP over terminal emulation (PTY), plus experimental ACP
- **Endpoints:** `GET /status`, `GET /messages`, `POST /message`, `POST /upload`, `GET /events` (SSE).
- **Model** (verbatim, AA `lib/httpapi/models.go`, `events.go`):
```go
type MessageType string  // "user" | "raw"
type Transport string    // "pty" | "acp"
type Message struct { Id int; Content string /* "as it appears in the agent's terminal…" */; Role; Time }
StatusResponse.Body { Status AgentStatus /* "running" | "stable" */; AgentType; Transport }
// SSE: "message_update" {id, role, message, time} | "status_change" {status, agent_type} | "screen_update" {screen} | "agent_error"
```
- **Agent types:** `claude, goose, aider, codex, gemini, copilot, amp, cursor, auggie, amazonq, opencode, custom`.
- **How it works:** *"runs an in-memory terminal emulator… any new text that appears below the initial content is treated as the agent's next message."*
- **ACP mode** (`--experimental-acp`): auto-approves every permission (*"Phase 1"*).
- **Issues:** screen-stability timeout #123; first line trimmed #126; messages merged into the same id #205; SSE buffering behind proxies #69.

### 15.10 Superset, emdash, Sculptor, opcode, Xum, VibeTunnel (brief)
- **Superset** (`superset-sh/superset`):
  - Today: PTY "terminal agents" with YOLO flags; status comes from hooks.
  - New `@superset/chat-runtime` (flag `chat-v3`) for claude-code and Codex app-server.
  - **Chat Protocol v1** (SS `plans/chat-protocol-v1.md`, verbatim, abridged):
    ```ts
    type Cursor = { epoch: string; seq: number };   // cross-epoch cursor => reset, never partial replay
    Envelope = {v:1; sessionId; cursor; ts; event: DurableEvent} | {v:1; sessionId; ts; delta: Delta} | {v:1; sessionId; ts; reset: Reset}
    SessionState.status = "starting"|"running"|"awaiting_input"|"idle"|"not_loaded"|"offline"|"dead"
    ToolCall { toolKind: "read"|"edit"|"delete"|"move"|"search"|"execute"|"think"|"fetch"|"other"; status: "running"|"completed"|"failed"|"declined"|"canceled"; content: (text|diff|terminal)[] }
    ApprovalRequest { targetItemId|null; title; options?: {optionId,label}[]; status: "pending"|"answered"|"stale"; decision? }
    Decision = {type:"accept"}|{type:"accept_for_session"}|{type:"decline"}|{type:"cancel"}|{type:"option"; optionId}
    ```
  - Invariants: *"In-flight turns do not survive host death… pending approvals → `stale`"*; *"a dropped socket means nothing about user intent"*; *"All unions are open"*.
  - Per-harness quota routes `usage/{claude,codex,grok-quota,opencode-quota,agy-quota}.ts`; Relay (Pro) plus an Expo mobile app.
  - Issue #7395: idle shown while waiting on subagents.
- **emdash:**
  - 37 providers, 23 via ACP; `definePlugin(meta, caps)` with caps `acp, autoApprove, auth, models, hooks, mcp, prompt, sessions`.
  - Per-provider `enrich` shims (*"codex-acp represents startup diagnostics as synthetic failed tool calls"*).
  - *"Emdash does not infer agent status from terminal output"*.
  - ACP permission broker *"never automatically chooses an option"*.
- **Sculptor** (Imbue):
  - Claude via stream-json control protocol; Pi via RPC with injected ask and plan tools.
  - `HarnessCapabilities` (15 bools: `supports_chat_interface, supports_interactive_backchannel, supports_skills, supports_sub_agents, supports_image_input, supports_fast_mode, supports_context_reset, supports_compaction, supports_background_tasks, supports_session_resume, supports_tool_use_rendering, supports_file_attachments, supports_interruption, supports_file_references, supports_model_selection`).
  - Terminal agents report status via a local HTTP signal API (*"never parses a terminal agent's output"*).
- **opcode** (formerly Claudia): Claude only. Always runs `--dangerously-skip-permissions`, so there is no approval UX (#292). Axum web server for phone browsers.
- **Xum** (formerly coder/mux): its own agent loop; exposes `xum acp` (acts as an ACP agent); bearer or device-flow server access.
- **VibeTunnel:** PTY sharing to the web (asciinema), with active/idle indicators. Not structured.

### 15.11 First-party remote products (context)
- **Claude Remote Control:** see 15.2.
- **Codex Remote:**
  - The ChatGPT mobile app controls Codex on Mac or Windows via a relay; pairing by QR from the ChatGPT desktop app.
  - Backed by the app-server `remoteControl/*` RPCs and an outbound WSS to `chatgpt.com/backend-api/wham/remote/control/server`.
  - Docs page exists ([developers.openai.com/codex/remote](https://developers.openai.com/codex/remote)); other details are Unverified (press).
- **Cursor Cloud Agents API:** see 15.5.
- **Brief list:**
  - Kanna: Claude SDK, Codex app-server, Cursor, Grok, Pi; event-sourced JSONL; trycloudflare QR.
  - Jean: Tauri; Claude, Codex, Cursor, OpenCode, Pi, Grok, Kimi; HTTP/WS web access.
  - agent-deck: tmux plus web.
  - Claude Squad: `--autoyes` TUI scraping.
  - Dead or removed: Terragon (shutdown snapshot 2026-01-16), wandb/catnip (404).

---

## 16. Cross-product comparison

| Product | Harnesses | Harness transport | Canonical model | Client transport / remote | E2EE | Permission UX | Quotas / usage |
|---|---|---|---|---|---|---|---|
| OpenChamber | OpenCode 2.x only | OpenCode HTTP+SSE (`/api/*`) | OpenCode v2 message+parts (`model.ts`) | WS (+SSE) via own server; LAN, tunnel, SSH, relay | Relay: ECDH P-256 + AES-GCM | once/always/reject + server-side ask/safety/auto | ~23 provider quota APIs + session stats |
| Happy | Claude, Codex, Gemini/OpenCode via ACP, OpenClaw, agy | Claude SDK/PTY, Codex app-server, ACP | `happy-wire` envelopes (frozen; redesign → OpenCode-style parts) | Socket.IO + v3 seq HTTP via relay | NaCl/AES-GCM | shared mode enum mapped per harness; RPC side-channel | Claude `rate_limit_event` windows; token usage |
| Paseo | Claude, Codex, OpenCode (v1+v2), Pi, OMP, Copilot (+ACP generic, Cursor, Kimi, Kiro, …) | Native per harness + `ACPAgentClient` | `AgentStreamEvent` / `AgentTimelineItem` + `AgentCapabilityFlags` | WS direct or relay; seq pages | NaCl box (Curve25519/XSalsa20) | actions `allow/deny` + `intent`; kinds tool/plan/question/mode | `AgentUsage` (tokens, cost, context); "usage sources" plugin contract |
| Codeg | 15 built in + any ACP | ACP only (adapters for Claude/Codex) | ACP-normalized + SQLite | HTTP + WS server; native iOS/Android | token auth (no E2EE claim) | ACP options; chat channels | token-usage report |
| Reemoat | Claude, Codex, OpenCode, Kimi, Grok, Cursor (+ACP plugin) | ACP only | `SessionEvent` union + seq log | HTTP + WS via relay | Noise_IK | ACP options; registry ordering | `usage_update` → `contextUsage`; `turn_end.usage` |
| Runmote | OpenCode, Cursor, Claude, Codex, Copilot, Gemini | ACP only | ACP passthrough + Dart segments | WSS relay | TLS only | ACP options | `usage_update` + prompt `usage` |
| Agmente | ACP agents + Codex app-server | ACP / app-server over WS | per-protocol view models | `wss://` via stdio-to-ws / tunnel | TLS / CF Access | per protocol | — |
| Zed | any ACP + native | ACP stdio (SSH exec remote) | `AgentThreadEntry` | local / SSH | n/a | ACP options; pattern rules (native only) | `TokenUsage` from `usage_update` |
| vibe-kanban | Claude, Codex, OpenCode, Gemini, Qwen, Copilot, Amp, Cursor, Droid | stream-json, app-server, HTTP+SSE, ACP | `NormalizedEntry` + JSON Patch | WS (relay shut down) | — | Auto/Supervised/Plan (default YOLO) | `TokenUsageInfo` |
| Nimbalyst | Claude, Codex, OpenCode, Copilot, Grok, Cursor, Antigravity | SDK, app-server, ACP, NDJSON, PTY+proxy | `TranscriptEvent` (rebuilt from raw) | relay sync of raw messages | AES-GCM | ask/allow-all/bypass-all; scope once/session/always | `contextReporting` capability |
| t3code | Codex, Claude, OpenCode, Cursor, Grok, Antigravity | app-server, Agent SDK, `opencode serve`+SDK v2, ACP | `ProviderRuntimeEvent` (49 types, with `raw` passthrough); event-sourced SQLite | Effect RPC over WS `/ws`; QR pairing, Tailscale, SSH, T3 Connect tunnels | TLS / DPoP (no E2E relay) | `RuntimeMode` 4 levels mapped per driver; decisions accept/acceptForSession/acceptAlways/decline/cancel | `ServerProviderUsageWindow` per driver, sparse merge |
| CodexMonitor | Codex only | app-server | Codex items | NDJSON-RPC over TCP + token; iOS via Tailscale | — | 3 access modes; prefix rules | `account/rateLimits/*` primary/secondary + credits |
| CloudCLI | Claude, Codex, Cursor, OpenCode | Agent SDK, codex-sdk, stream-json, `opencode run` | `NormalizedMessage{kind}` | WS `/ws` with per-run seq replay (5k) | — | permission_request/resolved/cancelled kinds | task usage |
| Superset (chat-v3) | Claude, Codex (PTY agents for others) | Claude control protocol, app-server | Chat Protocol v1 envelopes `{epoch, seq}` | tRPC/WS + Relay (Pro) + Expo | — | Decision incl. `option{optionId}`; approvals become `stale` | per-harness quota routes |

---

## 17. Patterns observed (synthesis of evidence; not a design)

1. **A host-side daemon owns harness processes, sessions and the source of truth; thin clients attach.**
   - Seen in: Happy CLI daemon, Paseo daemon, Reemoat daemon, Codeg server, Runmote daemon, Mobvibe CLI, OpenChamber server, Ferngeist gateway, Aptove bridge.
   - Mobile apps never spawn agents. *"Nothing moves onto the phone"* (Codeg). Paseo mobile apps don't embed the server (OpenChamber mobile README).
   - Reemoat: *"Close the lid or drop to LTE: the daemon is the source of truth, and the agent never notices you left."*
2. **A canonical event schema plus per-harness adapters (anti-corruption layer) at the daemon boundary.**
   - Unions: Happy `AgentMessage`/`happy-wire`, Paseo `AgentStreamEvent`/`AgentTimelineItem`, Reemoat `SessionEvent`, vibe-kanban `NormalizedEntry`, Nimbalyst `TranscriptEvent`, Zed `AgentThreadEntry`, Crystal `UnifiedMessage`.
   - Recurring members:
     - user/assistant text with message ids
     - reasoning
     - a tool-call lifecycle keyed by id (pending/running/completed/failed/canceled) with typed detail (shell/read/edit/search/fetch)
     - plan/todo
     - permission and question requests and resolutions
     - turn start/end with stop reason and usage
     - mode/model/config changes
     - subagent linkage (parent id or child session)
     - errors/notices
     - an "other/raw" escape hatch (Reemoat `other{sessionUpdate, raw}`, OpenChamber "translated to nothing", AG-UI `Raw`)
   - Happy's maintainers froze their first schema and drafted a move to **OpenCode-style message+parts with permissions folded into tool state** (`blocked` status). Paseo and Nimbalyst keep raw provider history as durable truth and rebuild projections.
3. **ACP-first with a fallback or native fast path.** Two strategies coexist:
   - **(a) ACP everywhere:** Codeg, Reemoat, Runmote, Mobvibe, Toad, Zed. Claude and Codex go through adapters (`claude-agent-acp`, `codex-acp`).
   - **(b) Native per harness for the big three plus generic ACP for the long tail:** Paseo (*"ACP … recommended"* for new providers, but Claude/Codex/OpenCode/Pi are direct), Happy, Nimbalyst (*"deliberately not an ACP client"* where NDJSON is richer), vibe-kanban.
   - Stated reasons for native: fuller diffs (Codex app-server), approvals (`canUseTool`), steering, rewind, model/catalog control, vendor features ACP lacks.
4. **Capability negotiation or capability matrices.**
   - ACP `initialize` capabilities, plus static per-adapter tables: Paseo `AgentCapabilityFlags`, Nimbalyst `{compaction, contextReporting, slashCommands}`, vibe-kanban `BaseAgentCapability`, Crystal `CliToolCapabilities`, Zed `Option<Rc<dyn Trait>>` getters.
   - Vendor `_meta` capability namespaces (`jetbrains.air.capabilities`, `zed.dev`).
5. **Durable, sequenced logs with bounded replay plus authoritative catch-up pages.** Live deltas are optimistic; correctness comes from a re-fetchable projection.
   - Happy: v3 `after_seq` HTTP; Socket.IO is invalidation only.
   - Paseo: `seqStart/seqEnd`, `hasNewer`, epoch.
   - Reemoat: `StoredEvent.seq`; attach replay 2000 then page.
   - OpenChamber: event ids, 2,048-event / 8 MiB buffer, `replayReset`.
   - OpenCode v2 itself: volatile `/api/event` plus durable `/session/:id/log?after=<seq>`.
   - The ACP remote transport has none of this in v1.
6. **Delta coalescing and draft suppression** to protect mobile links and relays.
   - OpenChamber: 50 ms delta coalescer, 3,402 → 483 frames.
   - Reemoat: holds streamed tool-argument drafts, saving 55.6% of bytes.
   - Paseo: shell output sliced to 64 KiB; stream coalescer.
7. **E2E-encrypted relays with QR/code pairing that carries the host public key**, so the relay is "zero-knowledge". Push notifications are sent by the host or a push relay.
   - Crypto: NaCl/AES-GCM (Happy), NaCl box (Paseo), Noise_IK (Reemoat), ECDH P-256/AES-GCM (OpenChamber), AES-GCM (Nimbalyst).
   - Push: Happy via Expo; OpenChamber via APNs relay; Aptove; Ferngeist FCM. Push titles may leak plaintext (Happy).
8. **Permission policy lives in the client or daemon, not the protocol.**
   - Auto-accept or YOLO modes sit above per-harness mappings: OpenChamber server-side ask/safety/auto that works with no UI; Paseo intents; vibe-kanban Auto/Supervised/Plan; Nimbalyst allow-all vs bypass-all; Happy's shared mode enum mapped to Claude/Codex specifics.
   - Questions are a distinct request kind (OpenCode v2 forms, ACP elicitation, Grok/Cursor vendor methods, Pi extension UI dialogs).
9. **Session history aggregation reads vendor on-disk stores**, because protocol listing is missing or unreliable.
   - Codeg: per-agent store table. Runmote: `session_sources.py`. Paseo: Pi JSONL import.
10. **Quota and rate-limit display bypasses the agent protocol.** Products call vendor usage endpoints with the user's existing credentials, read-only (OpenChamber Claude/Codex/Copilot/…; Codex app-server `account/rateLimits/updated`), or read SDK rate-limit events (Happy).
11. **Compatibility shims** (OpenCode-API impersonation) let an OpenCode-speaking client drive other harnesses unchanged: OpenChamber community proxies, `vacp_bridge`.
12. **Event sourcing and command receipts on the host.**
    - t3code: *"The event log is the source of truth… A command acknowledgement… means the intent committed, not that the provider… finished."* *"Reconnection does not automatically replay mutations."*
    - CodexMonitor retries only idempotent methods.
    - Superset: *"a dropped socket means nothing about user intent"*.
13. **Raw passthrough alongside the canonical event, plus open unions.**
    - Raw passthrough: t3code `raw{source, method, payload}`, Reemoat `other{raw}`.
    - Open unions: Superset (*"All unions are open"*), ACP v2 `_`-prefixed variants.
    - Motivation: closed-enum breakages (vibe-kanban #2088).
14. **Harness-native network servers are appearing, but are experimental or vendor-relayed.**
    - `codex app-server --listen ws://` needs auth off loopback and rejects `Origin`.
    - `grok agent serve --bind --secret` is a WebSocket ACP server that keeps state across reconnects.
    - `goose serve` speaks ACP over HTTP/WS.
    - `opencode serve` speaks HTTP+SSE.
    - Vendor-owned relays: Claude Remote Control (Anthropic polling), Codex Remote (`chatgpt.com/…/remote/control/server`).
15. **Quotas are normalized into windows merged by id from sparse updates.**
    - t3code `ServerProviderUsageWindow{id, kind: session|weekly|monthly|other, usedPercent, resetsAt}`.
    - OpenChamber `UsageWindow{usedPercent, windowSeconds, resetAt}`.
    - Happy `usageLimits.windows[{id, status, utilization, resetsAt}]`.
    - Sources: Codex `RateLimitSnapshot{primary, secondary, credits}`, Claude `rate_limit_event` (one window per event), Claude `get_usage`.
16. **Status from hooks or signals instead of output parsing** for PTY-run agents: emdash, Sculptor's local HTTP signal API, Superset hooks, Zed Terminal Threads (BEL/OSC).

## 18. Pitfalls catalogue (evidence)

| Pitfall | Evidence |
|---|---|
| Permission or question requests that hang, are invisible, or are auto-denied | Nimbalyst #1563/#1348; Omnara #276/#183/#187; Zed #41357; Conductor 0.63.0; Reemoat Q5.54 (ordering of settle → resolve → log) |
| CLI/protocol drift breaks parsers or enums | Happy #1759 (`on-failure` removed); vibe-kanban #858/#769/#3123; Omnara deprecation; OpenChamber v2 cutover (+38k/−33k lines) |
| Events lost on disconnect or mobile background | Happy "Messages silently lost when socket disconnected"; vibe-kanban #3227; ACP v1 remote transport "In-flight messages are not replayed"; OpenCode v2 `/api/event` "Volatile by contract" |
| Huge transcripts and replays exhaust memory | Zed #60509/#61702; vibe-kanban #3218; OpenChamber #2881; Happy #1453 |
| Stuck "running" or "busy" state | OpenChamber #1869/#1843/#2421; vibe-kanban #2495; Nimbalyst #1438 |
| Remote auth flows assume a local browser | Zed #64391; ACP registry Agent Auth (local HTTP server + browser); Reemoat PTY device-auth wizards |
| Agents that advertise a capability but don't honour it | Runmote: OpenCode ACP `session/list` (Unverified today), Cursor/Copilot `session/close`, Codex resume "no rollout found"; Nimbalyst #1252 (Codex slash commands) |
| Subagent lineage incomplete | Reemoat Q6.3 (parent missing on 40–50% of child updates); Zed #54602; Omnara #144 |
| Pairing or key-exchange weaknesses | Happy #1503 (content key delivered unauthenticated) |
| Default YOLO configurations | vibe-kanban default profiles; Conductor "no sandbox by default"; Reemoat "There is no sandbox"; t3code default `full-access`; opcode always `--dangerously-skip-permissions` |
| Unhandled server-request types look like hangs | CodexMonitor #612 (`mcpServer/elicitation/request`); Happy MCP-era hangs #302 |
| Pending approvals orphaned when the harness dies | t3code #11799; Superset marks them `stale` |
| PTY scraping is fragile | agentapi #123/#126/#205; Omnara deprecation; Claude Squad `--autoyes` |
| Sparse quota events mis-merged | t3code #12170 (Claude `rate_limit_event`) |
| Shared native stores conflict | t3code #9065 (`opencode serve` holds SQLite) |
| Subscription and auth policy for Claude in third-party apps | Claude Remote Control rejects API keys; Agent SDK third-party login policy (Unverified); CloudCLI #300 |

## 19. Uncertainties
- Section 15 relies on a parallel sub-research pass; see its tags.
- Codeg's claim that Pi is native ACP conflicts with the ACP registry and Pi discussion #4444.
- Runmote's claim that OpenCode's ACP drops `session/list` is from a code comment; current OpenCode advertises `list`.
- Conductor is closed source; its transport details are partially Unverified.
- Star counts and versions are as of 2026-10-02.
