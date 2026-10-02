# CodeWalk v2 implementation plan

## Status and recommendation

This plan uses the read-only research snapshot from 2026-10-02 and repository revision `14fbf519`. No files, services, or tests were changed or run.

Build v2 as a new Flutter app skeleton in this repository, with a separate **CodeWalk Host** companion for harnesses that lack a suitable network API. Keep OpenCode v2 as a direct, official HTTP/SSE integration. The Host should own local harness processes, their adapters, a small authenticated CodeWalk protocol, and bounded reconnect storage. It must not impersonate OpenCode or claim capabilities that a harness does not provide.

Use a **hybrid connection architecture**:

- CodeWalk connects directly to an OpenCode v2 `opencode service` over the user’s LAN, VPN/Tailscale, SSH tunnel, or TLS reverse proxy.
- CodeWalk Host connects to local harness APIs or owns local harness subprocesses. It provides mobile, desktop, and browser clients with a separate, versioned CodeWalk API.
- Grok Build can also expose its native ACP WebSocket endpoint directly.
- No CodeWalk-hosted relay is part of this plan. iOS and Android background completion notifications are best-effort unless the user configures a self-hosted push path.

Use **TypeScript on Node.js 22 LTS** for the Host. It aligns with the official Claude Agent SDK, Pi SDK, Muse SDK, and ACP TypeScript tooling. Keep harness drivers small and native to each protocol; share only session identity, event provenance, capability reporting, and the client-facing Host transport. Dart AOT would reuse the app language but would forgo these official SDKs or require more custom protocol maintenance. Go or Rust would help with a compact supervisor, but would add language and packaging overhead without removing the need for Node-based SDK adapters.

Release OpenCode v2 and shared-daemon Codex support first. Include Claude session discovery and resume in the first release because external Claude history is an essential requirement; ship live Claude control only after the SDK, concurrency, authentication, and terms spikes pass. Add Grok and Pi next, then Muse. Offer DSH only as an explicitly experimental opt-in while it remains a developer preview.

The key blocker to settle early is whether CodeWalk can manage an isolated OpenCode v2 service and configuration without overwriting or confusing another per-user OpenCode installation. Official service APIs support a custom registration file and command, but CodeWalk must verify its exact configuration, database, and process behavior before promising coexistence.

## Intended final behavior

A user selects a **host**, **workspace**, and **harness** when creating a session. The app presents sessions from that host and workspace together, with a harness badge and external-origin label. Supported sessions can be resumed; live attachment, history-only resume, and local transcript discovery are shown as distinct behaviors.

The timeline presents user and assistant messages, reasoning when available, tool calls and outputs, file changes, plans or todos, child tasks, approval requests, and forms. It follows the selected harness’s authoritative event ordering and reconciles against history after a gap. Commands are retried only when the protocol provides an idempotency guarantee; an ambiguous send is displayed as **delivery unknown** until reconciled.

Approval, sandbox, undo, queue, and notification controls describe the selected harness’s real behavior. Capability snapshots determine which actions appear. Cost, token usage, context window, and provider quotas remain separate measurements.

The main OpenCode contract follows v2’s flat typed messages, async prompt admission, global live SSE, `session.execution.*`, and session-level model and agent selection. V1 routes are not used. OpenCode’s experimental session log and experimental file write stay visibly gated.

## Decision Assessment: D01–D16

The user’s selected answers remain the baseline. Recommendations below do not change that baseline without the user’s later decision.

| ID | Verdict and recommendation | Evidence and argument | Concrete alternative and tradeoff | Confidence and verification |
|---|---|---|---|---|
| D01 | **Unresolved; recommend hybrid.** | OpenCode v2 offers an official service and HTTP/SSE API. Codex’s shared daemon is on a local socket; its separate WebSocket listener does not share daemon sessions and rejects browser `Origin`. Claude, Pi, and Muse require a host process for their best official APIs. ACP’s remote transport is not stable. | Direct integration for every harness would leave several inaccessible to mobile. A universal CodeWalk proxy would centralize OpenCode behavior and lifecycle unnecessarily. The hybrid keeps OpenCode’s official contract direct while using a Host only for harnesses that need it. | High. Prototype the service registration/config isolation, Codex socket proxy, and browser-to-Host transport before committing to the topology. |
| D02 | **Unresolved; recommend phased rollout.** | OpenCode v2, Codex, and Claude have the strongest remote-client surfaces and external-session requirements. Grok has native ACP WebSocket. Pi has a stable RPC mode. Muse MSP is rich but still marked Developer Preview; `dsh` ACP is preview and deliberately sparse. | **v2.0:** OpenCode v2, Codex shared daemon, Claude discovery/resume, then full Claude live control after its gates pass. **v2.1:** Grok and Pi. **v2.2:** Muse. DSH remains experimental and opt-in. Shipping all seven together adds several unstable protocol and packaging risks. | Medium-high. Verify Claude history resume and terms, Codex daemon skew, and desktop host packaging in bounded spikes; then finalize phase gates. |
| D03 | **Keep.** | A new skeleton is justified by the v1 code’s OpenCode-shaped domain and large coupled `ChatProvider`/`ChatPage`; retaining the same repository preserves reusable UI and history. | A separate repository would isolate v2 but make selective reuse and maintenance less direct. Retain the same repo, create a v1 maintenance branch at the last v1 release, and replace the v2 mainline only after the branch/tag is safe. | High. Before implementation, verify the v1 tag and worktree state and identify code that is genuinely UI-only. |
| D04 | **Keep with an explicit rollback limit.** | Android currently uses `com.verseles.codewalk`; same app ID permits updater replacement. It prevents side-by-side v1/v2 installs. The current build number is `1790827338`, so v2 must remain above installed/published build numbers. | A `.v2` app ID permits side-by-side use and safer rollback but prevents a seamless updater replacement and splits device state. Keep the selected ID; treat legacy v1 downloads as archival/manual installs, not a guaranteed in-place downgrade. | Medium. Verify Android signing, update metadata, desktop updater behavior, local database migration, and the final v1 artifact’s installability after upgrade. |
| D05 | **Change recommended for discussion.** | The meanings differ sharply. OpenCode’s wildcard allow overrides deny rules and is inherited by children; Codex approval policy and filesystem sandbox are separate; Grok’s `--yolo` changes sandboxing as well as approval; Pi has no built-in permission system; DSH is unaudited preview. A single “allow all” default can imply unsafe guarantees. | Default new sessions to the harness’s explicit ask/on-request mode; keep allow-all available as a clearly named, per-harness opt-in with global and session scopes. Preserve an existing user’s explicit v1 auto-approve setting during migration. This changes the default but retains the requested control. | High. Verify every harness’s current approval and sandbox modes, then test the UI against each native request/response. |
| D06 | **Keep.** | Native usage exists for OpenCode cost/tokens/context, Codex rate limits, Claude rate-limit events, and Muse windows; other harnesses have gaps. No single usage API means one normalized “quota” model would be misleading. | Vendor endpoint polling can expose more windows but adds credential and drift risk. Keep the opt-in; perform host-side queries only after user enablement and explicit refresh or a cached refresh of at most once per minute. Never move credentials to the client. | High. For each endpoint, verify ownership, auth source, response shape, and provider terms before enabling it. |
| D07 | **Unresolved; recommend local, best-effort notifications first.** | Native events can drive notifications while a host or client is running. A sleeping iOS client cannot keep a socket alive; Android background workers also have OS limits. Reliable remote push generally needs a push relay. | Notify on desktop when the Host is running, and locally on mobile/browser when events are received. Show pending attention after reconnect. Defer remote push to an optional user-managed push service. This respects D08 and avoids promising delivery the platform cannot guarantee. | Medium-high. Verify current iOS/Android background behavior on actual devices; test any optional self-hosted push path separately. |
| D08 | **Keep.** | Direct user-managed routes work with OpenCode and a secured Host. Codex’s listener lacks TLS and browser Origin support; Grove’s server is plain WebSocket. | A hosted relay could simplify NAT and background push but contradicts the selected network direction and creates service/security scope. Use Tailscale/VPN, SSH forwarding, or TLS reverse proxy. | High. Validate pairing, TLS, CORS, and token rotation on each supported transport. |
| D09 | **Keep with staged parity gates.** | Android/desktop/Web currently exist; iOS has no project folder. Browser access needs CORS and a browser-compatible Host transport. Android/iOS should connect to a host rather than install these CLIs. | Dropping Web or iOS would simplify early delivery but contradicts the selected platform scope. Keep all six targets, phase host-management features to desktop, and validate remote chat on Android, Web, and iOS before calling them supported. | Medium. Verify iOS signing/build setup, platform plugins, web auth/origin rules, and release runners. |
| D10 | **Keep, subject to the service-isolation spike.** | OpenCode’s v2 update metadata supplies official binary URLs and SHA-256 values; `opencode service` supports port, password, CORS, and pairing. V2 uses paths that can collide with v1; default service state/config/database are per-user. | Installing to the default `~/.opencode/bin` path can replace v1. Prefer a versioned CodeWalk-managed binary and a custom service registration/config/database where official environment options allow it. If isolation fails, require an existing v2 server or explicit replacement confirmation. | Medium. Test a pinned v2 binary, checksum verification, registration path, custom config/DB, port 49374, restart, and pairing without touching an unrelated service. |
| D11 | **Keep with platform ownership boundaries.** | Local protocols require a host; Android/iOS/Web cannot own desktop CLIs. Official installers vary by platform and harness. | Installing all harnesses by default increases setup size and auth complexity. Offer opt-in installation per supported harness through official channels; Web/iOS/Android connect to an already managed host. | High. Test each official installer and updater on Linux, macOS, and Windows before listing it as supported. |
| D12 | **Process-only: keep.** | The final `v2-plan.md` is requested in English. | No alternative needed. | High. Review the delivered plan for English and ensure labels preserve exact source names. |
| D13 | **Keep, with honest live-attachment distinctions.** | OpenCode’s shared service and Codex’s daemon support peer clients. Claude provides local history and resume, but no generally usable public daemon for third-party live attachment. | Treating Claude history resume as a live TUI attachment would be a false promise. Keep it essential, but label it “resume from local history” and block concurrent continuation when ownership is uncertain. | Medium-high. Test OpenCode TUI, Codex TUI/daemon, and Claude CLI-created session discovery/resume/concurrency on pinned versions. |
| D14 | **Keep.** | OpenCode and Codex can list sessions across projects; Claude, Pi, Muse, and Grok have session/history surfaces with varying completeness. Capability-aware grouping fits the requested unified view. | Separate per-harness lists would simplify presentation but break the selected common workspace workflow. Preserve host/workspace grouping and make unsupported actions unavailable with a reason. | High. Validate stable identity keys and no cross-host/project state leakage. |
| D15 | **Change recommended: TypeScript/Node 22 LTS.** | The official Claude SDK is TypeScript and supports Node; Pi and Muse have TypeScript SDKs; ACP also has TypeScript tooling. Flutter remains Dart. This gives the host the best official SDK coverage. | Dart AOT avoids another runtime but means protocol maintenance or semi-public stream parsing. Go/Rust provide compact services but add language boundaries and still need Node SDK workers for Claude/Muse/Pi. Bundle/pin Node or make it a managed prerequisite, then measure packaging cost in the spike. | Medium-high. Build a minimal signed host service for Linux/macOS/Windows x64 and ARM64 where harnesses support it; verify Node packaging and upgrades. |
| D16 | **Process-only: keep.** | This is a planning-workflow constraint and does not affect product architecture. | None. | High. The orchestrator owns compliance with helper scheduling, persistence, and synthesis instructions. |

### Recommended changes to reconsider

1. **D05:** Change the new-session default from allow-all to ask/on-request. Keep global and per-session allow-all controls, but explain each harness’s sandbox and policy scope separately.
2. **D10:** Keep official binaries and `opencode service`, but do not install over a user’s existing OpenCode path until the isolated-service spike proves safe coexistence.
3. **D04:** Keep the same app ID, while documenting that a legacy v1 APK is not a guaranteed downgrade or side-by-side install path.
4. **D09:** Keep all six platforms in scope and stage feature parity. Do not label iOS/Web supported until their build, auth, and reconnect gates pass.

## Harness capability matrix

Snapshot versions below are research pins, not compatibility promises for future releases. `N` = native official surface; `B` = CodeWalk Host bridge; `X` = vendor extension; `E` = experimental/preview; `U` = unsupported or not established. Features remain hidden or disabled unless the negotiated adapter advertises them.

| Harness and preferred surface | Session discovery, resume, live attachment | Streaming, tasks and turn controls | Permissions, questions, plans | Usage | Files, terminal, undo | Commands, skills, mentions, attachments, model |
|---|---|---|---|---|---|---|
| **OpenCode v2** — `opencode service`; HTTP `/api/*` + global SSE. Pinned source snapshot v2.0.21; current dossier also records 2.0.22. | **N:** global session list with cursors; create, resume, fork, delete. Same service shares TUI/Desktop/Web sessions. Live events are shared; SSE has no replay. Experimental session log can catch up. No HTTP archive endpoint; fork creates a new root. | **N:** flat messages; text/reasoning/tool-input deltas; execution events; async prompts with steer/queue; interrupt/background. Native `subagent` child sessions and parent continuation. No todo API. Known nested-background bug. | **N:** ordered permission rules; `once/always/reject`; forms support typed questions. `always` saves project-wide permission and wildcard allow can override deny/inherit into children. Allow-all is a server policy change, not a sandbox. | **N:** cost, tokens, model limits/context. No quota-remaining endpoint. Go/Zen limits appear in error payloads. | **N:** list/find/read; experimental write; PTY and shell. Revert is staged/committed and Git-dependent. No file-search-by-content route. | **N:** session agent/model/variant; command registry/dispatch; skills and agent mentions. Text/images supported with documented URI limits; PDFs are not sent. |
| **OpenAI Codex** — app-server v2, attached through the shared daemon socket. CLI 0.159.3 and daemon 0.160.0 were observed; protocol is experimental. | **N:** `thread/list` with explicit `sourceKinds`, read/resume/fork/archive/unarchive/delete. Shared daemon sessions include CLI/TUI. `thread/resume` rejoins active threads and replays pending approvals. Separate `--listen ws://` process does not share these sessions. | **N:** streamed message/reasoning/tool items, child threads, plan updates, goals, interrupt and steer. Queue and running-turn settings are experimental. PTY `command/exec` dies with connection close; background terminal APIs are experimental. | **N:** server approval requests and decisions, replay, sandbox policy. User-input questions and plan mode are experimental. Approval policy and sandbox are separate controls. | **N:** token/context updates and primary/secondary account limits for ChatGPT auth. API-key usage may have no account windows. | **N:** host file read/write and diffs. No file undo; `thread/rollback` removed. Conversation rewind is a fork before a turn. `command/exec` has connection-scoped lifetime. | **N:** model and reasoning effort, skills, file suggestions. No server slash-command registry; custom prompts deprecated. Images use data/local input, not HTTP image URLs. |
| **Claude Code** — official TypeScript Agent SDK 0.3.287 with CLI 2.1.287; host-owned long-lived SDK query. | **B/N:** SDK session list, resume, fork, rename/tag/delete local history. Can resume CLI-created history. **No public network daemon and no direct live attachment to a running TUI process.** Each active session is a subprocess. | **N:** streaming text/thinking/tools, stop/interrupt, queued mid-turn input, background tasks/subagents, todos on supported models. Host provides file browsing/search, diff, PTY, event journal. | **N:** `canUseTool`, permission mode changes, AskUserQuestion and elicitation. Explicitly set permission mode. Allow-all does not equal OS sandbox. | **N:** subscription `rate_limit_event`; experimental usage pull; token/cost/context fields. Pull API may change. | **N/B:** SDK readFile/checkpoint rewind, with tracked edits limited to Write/Edit/NotebookEdit—not Bash/subagent edits. No redo. Host provides file tree/search, git diff, PTY. Images stream; other files need host transfer and `@path`. | **N:** model, effort, agent, slash commands, skills, `@path`; terminal-only commands must be hidden. Use host search/autocomplete. Legal/auth configuration is a ship gate. |
| **Pi** — official `pi --mode rpc` or TypeScript SDK; host bridge required. Pinned v1.0.0. | **N/B:** SDK `SessionManager.listAll`, history entries, continue/resume/fork. RPC has one active session per process; Host can manage one process per active session. No API to attach to another running RPC process. | **N:** text/thinking/tool streams, steer/follow-up/queue, abort/retry, shell command. No built-in subagent or todo system; extensions supply them. | **U/B:** no built-in permission system; extension UI can ask questions/confirmations. Default “YOLO” behavior means allow-all UI cannot add a native policy guarantee. | **N:** token/cost/context stats. No quota windows. | **B/N:** Host supplies browse/search and optional PTY. RPC exposes Bash command output, not a durable interactive terminal. Fork is conversation history only; no file snapshots. | **N/B:** models, thinking levels, extension commands and skills. File `@` references are not handled by RPC; Host can search/read and insert text. Images supported; no generic PDF guarantee. |
| **Muse Code** — MSP v1 through `muse serve`/official TS SDK; host bridge required. Pinned dossier 1.4.2; Developer Preview docs. | **N/B:** list/start/read/resume/fork/rename/delete; cursor-based view resume and gap recovery. Session leases exist; external TUI/store sharing needs verification. | **N:** text/reasoning/tool streams, queue/steer/replace, background tasks, child subagents/workflows, cancel, todos and goals. | **N:** staged approvals with server choices, user input forms, native allow-all mode subject to policy. | **N:** token/context/cost and 5-hour/weekly windows. | **B/N:** MSP lacks browse/search. Supports one-shot user shell, not a general interactive PTY. Fork is available; file rewind is not established. | **N:** models, reasoning effort, skills, `@relative/path`; no stable agent selector. Images supported. Built-in slash commands are not exposed by the stable MSP surface. |
| **Grok Build** — native ACP v1 WebSocket `grok agent serve` plus `x.ai/*`; snapshot 1.0.46, registry version differs. | **N/X:** list/load/resume and native reconnecting server; XAI extensions add fork/rename/delete/history. TUI can attach to its remote server. Local TUI history outside that server needs verification. | **N/X:** message/thought/tool streams, child/background subagents, interrupt/cancel, interject and queue extensions, plans. | **N/X:** ACP permission requests and XAI question method. Approval mode and optional OS sandbox are distinct. | **N/X:** token/cost/session usage; billing/credits extension shape remains unverified. | **X:** file search/read/write, Git, terminal/PTY. Rewind changes conversation only, not files. | **N/X:** model/config modes, reasoning effort, skills, commands and fuzzy search. Images supported. Pin and test the `x.ai/*` extensions; they evolve. |
| **DeepSeek Harness (`dsh`)** — official ACP v1 stdio, `@deepseek-ai/dsh` 0.2.0-rc.2; preview. | **N/E:** ACP `session/list` and resume persisted inactive sessions, but resume does not replay old updates. No fork/delete. `dsh web` API is private/internal; external web sessions may not be discoverable through ACP. | **N/E:** committed message/tool updates, one prompt at a time; no guaranteed token stream, steer/queue, plan/todo, terminal, or subagent surface through ACP. | **N/E:** one-shot allow/reject; no elicitation/questions through this profile. The harness’s broader UI features are not evidence of ACP support. | **N/E:** context and usage updates may exist; no quota-window endpoint established. | **U/B:** ACP exposes no client file browser/search, terminal, or undo. | **N/E:** model/reasoning config options; no commands, modes, plans, or skill UI established in ACP. Images depend on durable attachment storage and exact route support. Defer to opt-in preview. |

### External session handling

- **OpenCode:** list through the shared service, including all projects; filter roots/children using the API. Sessions from the same service are peer sessions and may be controlled live. A `--standalone` process is a different service and cannot be assumed to share state.
- **Codex:** explicitly request all relevant `sourceKinds`, including `cli`, `vscode`, `exec`, `appServer`, and child sources. The shared daemon owns threads; CodeWalk attaches as another client. Route every event by `threadId`; pending approvals can replay and are resolved across clients.
- **Claude:** discover local sessions through the SDK and resume by native session ID. This is local history continuation, not a live attachment to a currently running TUI. Block concurrent resume if a session is held or ownership cannot be established. Never read or forward OAuth credential files.
- **Pi:** discover with SDK session managers and resume/fork from stored sessions. CodeWalk must start its own RPC process; it cannot attach to another Pi RPC process.
- **Muse:** use MSP’s list/resume cursors and session leases. Verify that TUI-created sessions appear and test the lock behavior before advertising external-session continuity.
- **Grok:** resume through the ACP server and supported XAI session methods. Treat the remote server’s session as the shared live owner.
- **DSH:** show persisted sessions that ACP lists; resume only when inactive. Label replay and live attachment as unavailable until the preview contract adds them.

## Architecture and interfaces

### Repository layout

Replace the v1 root app on the v2 mainline only after preserving the final v1 tag/maintenance branch. Keep Flutter as the product client and place the Host in its own package:

```text
lib/
  app/                         # bootstrap, routing, DI, platform services
  domain/
    identity/                  # HostId, HarnessId, WorkspaceRef, SessionRef
    session/                   # SessionSummary, Turn, TimelineItem, TaskRef
    interaction/               # PermissionRequest, UserForm, ErrorInfo
    capability/                # CapabilitySnapshot and support levels
    usage/                     # Tokens, CostEstimate, ContextWindow, QuotaWindow
    ports/                     # SessionRepository, HostRepository, FileRepository
  data/
    adapters/opencode_v2/      # OpenAPI-derived DTOs, HTTP, SSE, reducer
    adapters/host_bridge/      # CodeWalk Host API and stream client
    storage/                    # versioned preferences, bounded cache
  presentation/
    features/
      onboarding/
      sessions/
      timeline/
      composer/
      permissions/
      tasks/
      files/
      terminal/
      settings/
host/
  package.json
  src/
    server/                    # CodeWalk /v1/info, /v1/harnesses, /v1/stream
    adapters/{codex,claude,pi,muse,acp}/
    processes/                 # spawn, stop, update, health, resource limits
    journal/                   # event cursor, snapshots, replay retention
    workspace/                 # host file and PTY services where required
test/
  contract/opencode_v2/
  contract/host_protocol/
```

Keep `provider`/`get_it` initially; create feature-scoped controllers instead of extending the v1 god objects. Avoid a state-management rewrite during the protocol rewrite.

### Identity, capabilities, and event boundaries

Use a stable scoped identity:

```text
SessionRef {
  hostId, harnessId, workspaceKey, nativeSessionId,
  protocolVersion, origin: codewalk | terminal | otherClient
}
```

`workspaceKey` is scoped by host and normalizes the harness’s project root. Never merge two hosts because their project paths match. Persist tabs, drafts, pins, and attention under `(hostId, harnessId, workspaceKey, sessionId)`.

Expose capability descriptors, not a flat boolean table:

```text
CapabilityDescriptor {
  id, support: native | bridge | extension | experimental | unsupported,
  scope: host | workspace | session | turn,
  limits?, requirements?, sourceVersion?, explanation?
}
```

Examples include `session.list`, `session.liveAttach`, `message.queue`, `message.steer`, `permission.once`, `permission.persist`, `permission.allowAll`, `question.form`, `usage.quotaWindows`, `file.write`, `terminal.interactive`, `session.fileRevert`, `session.fork`, `tasks.subagents`, `attachments.pdf`, `model.reasoningEffort`. A changed harness version refreshes the snapshot. Unsupported and unknown enum values remain safe, visible data; they never crash the reducer.

Normalize events while retaining provenance:

```text
EventEnvelope {
  hostId, harnessId, nativeSessionId, sourceProtocol, sourceVersion,
  nativeEventId?, nativeSequence?, bridgeSequence?, nativeCursor?,
  receivedAt, kind, canonicalPayload, rawType, rawPayload?
}
```

The canonical event union should cover message accepted, turn state, message/reasoning delta, tool lifecycle, file change, permission, form, usage, task/subagent link, and protocol error. Keep source-specific DTOs inside each adapter. Store bounded raw payloads only in local diagnostics; redact secrets and avoid content logs. The presentation layer consumes domain events, never `Map<String,dynamic>` wire payloads or OpenCode tool names.

Use two command paths: **read/query** and **mutate/control**. A `PromptReceipt` records the native ID, delivery disposition, and receipt status (`accepted`, `completed`, `rejected`, `unknown`). The Host records a client command ID before dispatch. It retries automatically only when the adapter confirms native idempotency; otherwise it reconciles history and reports an ambiguous delivery without sending a duplicate.

### Stream ownership, replay, and concurrency

- OpenCode’s official SSE is live-only and may drop a slow consumer. Store native event cursors where supported. On reconnect, use the experimental per-session log only after a feature check; otherwise reload the visible session’s messages, forms, permissions, and active state. Never poll every session while a healthy stream is active.
- Codex resumes against the shared daemon and paginates turns/items. It is the live owner, not CodeWalk; approval resolution is shared across clients.
- Muse uses `viewCursor`, `view/gap`, and resume/page APIs. Pi uses `get_entries(since)` and authoritative message end records. ACP v1 lacks reliable incremental replay; reload supported history and keep limitations visible.
- For Claude, SDK queries and their CLI subprocesses own active sessions. The Host writes a bounded journal for events that mobile clients miss. Do not confuse that journal with a native transcript or resume cursor.
- Give the Host journal a bounded retention, for example 7 days and 64 MiB per session, with snapshots and pruning. Official harness history remains authoritative. Disconnecting the client must not kill a running turn; explicit stop/cancel is a separate command.
- Serialize competing CodeWalk writes to an adapter session where the harness does not support multi-client coordination. For concurrent external clients, surface stale state and reconcile before destructive actions. Never automatically replay a pending approval or prompt after reconnect.

### Normalized state models

- **Turn state:** `idle`, `starting`, `running`, `waitingForPermission`, `waitingForInput`, `cancelling`, `completed`, `failed`, `interrupted`, `unknown`. Derive from native lifecycle events and status reads; absence of an event is not proof of idle.
- **Timeline item:** stable native ID when available; parent turn; kind; revision/status; text or structured content; tool name; raw source metadata. Final/complete item content replaces deltas authoritatively.
- **Task/subagent:** `TaskRef {parentSession, childSession?, taskId?, status, objective?, progress?, outputCursor?}`. Navigate only from explicit IDs. Children do not mark a parent unread unless the parent receives a native continuation message. Preserve existing viewport/scroll behavior.
- **Permission:** request ID, action/subject, source session, offered native choices, expiry, policy scope, sandbox facts, current pending/resolved status. Never invent “always” where the protocol offers only once.
- **Question/form:** typed fields, options, required state, current values, native answer shape, cancel semantics. Dismissal cancels only when the source contract says so. Do not flatten multi-select or numeric input to strings.
- **Usage:** separate `TokenUsage`, `CostEstimate {amount, currency, partial, source}`, `ContextWindow {used, limit, sampledAt}`, `QuotaWindow {id, usedPercent, resetAt, duration, source, sampledAt}`. Missing quota is “unavailable,” not zero.
- **Error:** preserve transport/protocol/harness type, status, retryability, retry-after, native message, and safe details. Map UI categories without dropping the source error.

## UX and complete chat lifecycle

1. **Onboarding and host setup**
   - Desktop can install the pinned OpenCode v2 binary from official update metadata, verify its advertised SHA-256, and launch `opencode service` on port `49374` with password and pairing. Avoid `curl | bash` and do not overwrite the default OpenCode path until isolation is proven.
   - Pairing follows OpenCode’s five-minute one-time code and 30-day token semantics; store tokens in OS secure storage and send them only to the paired origin.
   - The desktop app offers per-harness official installation, update, auth status, and removal controls. Use each vendor’s normal login in its own CLI/SDK; CodeWalk must not collect vendor OAuth tokens.
   - Android, iOS, and Web connect to a host. Browser clients use exact CORS/origin allowlists and secure WebSocket/HTTPS. Codex’s raw listener is not a browser endpoint; use the CodeWalk Host.
   - Detect OpenCode v1 by validating JSON and version from `/api/info`, not HTTP status alone. A v1 route can return HTML with status 200; show a clear unsupported-server error.

2. **Session home and creation**
   - Group by host, then workspace/project; show harness badge, origin, last activity, and honest online/stale state.
   - Session creation asks for harness and workspace. The model/agent/effort controls then use that harness’s advertised options.
   - Support list/create/resume/fork/delete only where available. If a backend lacks archive, offer local “hide on this device” rather than calling it server archive. Confirm deletion and explain child-session cascade.
   - Allow tabs, drafts, search, pins, and recent sessions to retain their value, but key them to the new host/harness/workspace/session identity.

3. **Composer, commands, and attachments**
   - Preserve draft autosave, file chips, paste/drop/picker paths, voice input, and keyboard behavior. The composer shows current session agent/model/variant/effort when the harness supports them.
   - Distinguish **steer**, **queue**, **replace**, and **send next** from protocol behavior. Do not label an adapter’s follow-up queue as a native turn queue.
   - Use each harness’s native command and skill discovery. Add only genuinely portable CodeWalk commands locally; do not send `/compact` or `/model` as free text when a direct method exists.
   - `@` autocomplete uses the host’s file-search capability. OpenCode uses file attachments/agent/skill references; Codex uses paths for file references and reserves structured mentions for app/plugin targets; Pi’s RPC has no file mention expansion. Preserve per-harness semantics.
   - Preserve image/PDF selection UI, but gate formats using advertised capability and per-harness size/input limits. OpenCode supports images but not PDF in its prompt API. Do not silently turn a PDF into text.

4. **Streaming, task output, forms, and approvals**
   - Show streaming text and tool input/output updates with a final authoritative update. Reasoning visibility follows the harness and user setting.
   - Display child/background work in a task surface with native status, output, parent/child navigation, and the correct cancel target. OpenCode task IDs/child session IDs and Codex child thread IDs replace v1 positional task-to-child pairing.
   - Render permission cards with offered choices and the effective native scope. Render questions as accessible typed forms. Keep both visible when terminal/composer panels alter the compact layout.
   - Keep native task lists/plans where returned. OpenCode v2 has no todo endpoint; do not fabricate a list when it exposes none.

5. **Errors, history, and attention**
   - Categorize auth, connection, busy/conflict, rate/quota, provider, process, and unsupported-feature failures while retaining the native error for diagnostics.
   - Retry read requests with bounded backoff. Retry mutations only with a proven idempotency key. A rate-limit retry uses the provider’s `Retry-After` when available.
   - On disconnect, show the last event cursor and reconnect state. Resume/reconcile first, then restore pending forms and permissions from the backend. Resolved prompts must not reappear from stale snapshots.
   - Desktop notifications work while the Host is running. Mobile/browser notifications work while an event is received. On iOS suspension and terminated mobile processes, show accumulated attention after reconnect; make no remote-push guarantee. A user-managed push integration can be a later optional feature with minimal, encrypted notification payloads.

6. **Files, terminal, and undo**
   - Retain file tree, file viewer, editor drafts, and preview where a negotiated read/write capability exists. Replace hidden shell-session file writes with native write or a separately consented Host workspace service; preserve root/symlink checks and atomic replacement. OpenCode write remains experimental until verified.
   - Keep terminal separate from composer shell commands. Show interactive PTY only when the adapter can keep and reconnect its process. Codex’s connection-scoped PTY must visibly warn if the connection closes.
   - Do not create one universal Undo/Redo button. Offer “Stage revert” for OpenCode’s native staged Git revert; “Fork before turn” for Codex conversation history; Claude file rewind with its documented operation limits; and conversation fork/rewind where supported. Explain that reverting conversation history does not restore files.

## Rewrite, reuse, and migration map

| Decision | Existing area | v2 plan |
|---|---|---|
| Rewrite | `lib/data/datasources/chat_remote_datasource.dart`, `project_remote_datasource.dart`, `quota_remote_datasource.dart`, OpenCode v1 data models, raw SSE reducers in `chat_provider.dart` and its parts | Replace with an OpenCode v2 adapter that follows pinned OpenAPI/schema/event sources and independent Codex/Claude/ACP adapters. Remove v1 route fallbacks and permissive multi-shape parsing. |
| Rewrite | `lib/presentation/providers/chat_provider.dart` and `lib/presentation/pages/chat_page.dart` plus `part` files | Build feature-scoped session, timeline, task, composer, permission, file, and connection controllers against domain DTOs. Reuse leaf widgets only after wire type/tool-name dependencies are removed. |
| Replace | `local_opencode_server_runtime*`, setup wizard/debug page, updater hooks | Use a versioned CodeWalk host/runtime manager, verified official OpenCode binary metadata, service discovery, explicit pairing, and staged process updates. Keep user-installed/external server connection. |
| Replace | `chat_title_generator.dart`, `workspace_file_operations_service.dart`, `quota_remote_datasource.dart` hidden shell sessions | Use supported title/session APIs or leave the feature unavailable; native/explicit workspace service for edits; opt-in host usage queries. No hidden sessions for unrelated operations. |
| Replace | three overlapping Android session/overlay/WorkManager attention paths | Use one foreground connection/attention path plus notification surfaces. Keep Android Auto and overlays only after a platform-specific v2 capability review. |
| Keep and scope | Material You themes, markdown/LaTeX/Mermaid/highlighting, accessibility, localization, speech, terminal renderer, file viewer, exports, image export, logs, settings, drafts, tabs, pins, attention snapshot presentation | Reuse UI-only and app-local features, migrate their state keys to host/harness/workspace/session scopes, and revalidate every platform. |
| Remove or defer | v1 `prompt_async` matching/polling, dual SSE dedupe, positional task mapping, fake `__codewalk` config agent, v1 route/schema fallback logic, shell probes, share APIs, TODO assumptions | Replace with v2 IDs/events/cursors/capabilities or explicitly mark unsupported. Preserve no v1 behavior through undocumented emulation. |

### Local data, app identity, and rollback

- Keep `com.verseles.codewalk` and use a v2 semantic version with an Android `versionCode` greater than the latest distributed build; current `pubspec.yaml` is `1.265.0+1790827338` and `android/app/build.gradle.kts` uses `flutter.versionCode`.
- Create a versioned local schema. Migrate safe preferences, theme/locale/accessibility/speech settings, drafts, tabs, pins, exports, and connection profile metadata. Re-key state to the new identity tuple.
- Preserve server secrets only in secure storage. Revalidate each OpenCode profile against JSON `/api/info`; prompt for pairing or reauthentication when its old v1 credential cannot connect. Never silently treat a v1 HTML response as success.
- Keep remote sessions on their authoritative host. Migrate local caches as optional display snapshots only; do not import them into OpenCode sessions.
- Keep the final v1 release artifact and v1 maintenance branch. Because the app ID is shared, warn that rollback may require uninstall/reinstall and local export; v1 and v2 cannot be side-by-side on Android.
- If true in-place downgrade or parallel installation becomes a requirement, reopen D04 before implementation.

## Ordered implementation stages

1. **Decision and compatibility spike**
   - Pin the first supported OpenCode v2 version and generate test fixtures from its OpenAPI and schemas.
   - Prototype managed service isolation: versioned binary path, custom service registration/config/database, password, port `49374`, pair/redeem, upgrade and restart.
   - Prototype Codex daemon socket attachment through `codex app-server proxy`; test CLI/daemon version skew, all session source kinds, pending approvals, and Web access through the Host.
   - Prototype Claude SDK history listing/resume from CLI-created sessions, live query control, concurrent ownership, official auth flow, and current terms.
   - Define pass/fail gates for Node distribution, iOS setup, Web CORS/origin, and no-relay notification behavior.

2. **New skeleton and OpenCode v2 vertical slice**
   - Create the new domain, data, and presentation boundaries while preserving v1 under its maintenance branch.
   - Implement direct connect, `/api/info` detection, pairing-token storage, session list/create/resume, streaming, async prompt, turn state, and paginated history.
   - Acceptance: terminal/TUI-created sessions from the same service list and open; an interrupted connection reconciles without duplicate messages; unknown events are retained safely.

3. **Shared Codex and Claude history/live**
   - Add the Node Host protocol, adapter lifecycle, authentication/pairing, bounded event journal, child-process supervision, and update mechanism.
   - Add Codex shared daemon support with source-kind discovery and live resume.
   - Add Claude history discovery/resume. Enable live SDK sessions after policy, session ownership, file handling, and concurrency gates pass.
   - Acceptance: external Codex thread approval appears on rejoin; external Claude session resumes once without corrupting a live CLI owner.

4. **Complete OpenCode v2 interaction slice**
   - Add native permissions, forms, async child/background subagents, queue/steer, model/agent selection, command/skill integration, usage, files, terminal, and staged revert.
   - Keep archive, PDF, todo, share, and file write features capability-gated according to the official contract.
   - Acceptance: child lineage, attention scope, viewport restoration, and cancellation target remain correct under concurrent children.

5. **Grok and Pi**
   - Add Grok’s native ACP WebSocket with a tested version pin and selective `x.ai/*` extension support.
   - Add Pi’s RPC/SDK bridge; surface no native permission, task, or todo controls unless an explicit extension provides them.
   - Acceptance: reconnect resumes from native history/cursor or clearly reports the gap; unknown vendor extensions do not break ACP v1 behavior.

6. **Muse and DSH**
   - Add Muse MSP behind a schema fingerprint check; verify session leases, external history, and host-owned file browsing.
   - Add DSH ACP as a disabled-by-default preview with a compatibility banner and no unsupported UI controls.
   - Acceptance: feature matrix matches the negotiated contracts; DSH’s preview status and missing replay controls are visible.

7. **Platform rollout and release**
   - Keep Android, Linux, macOS, Windows, Web, and iOS in the product scope.
   - Desktop manages host tools. Mobile and Web connect. Validate target-specific auth, files, notifications, keyboard, accessibility, and build support.
   - Release v2 only after migration, all required platform gates, update rollback, and review of the complete code stage. Do not start v1/v2 updates that could overwrite each other’s service/process.

## Testing and validation plan

### Adapter and lifecycle fixtures

Create pinned protocol fixtures for OpenCode v2 OpenAPI/events, Codex daemon app-server v2, Claude SDK messages/control requests, Pi RPC JSONL, Muse MSP v1, ACP v1/Grok extensions, and DSH’s pinned ACP profile. Verify:

- Missing, extra, and unknown event fields/enums; malformed JSON; incomplete stream frames; batched deltas followed by authoritative final messages.
- Session/turn/item ordering, duplicate delivery, cursor replay, event gaps, replay reset, history pagination, child-session lineage, and bounded cache restoration.
- Permission races: two clients answer one request; stale or repeated answer; multi-stage approval; child approval; user disconnect while waiting; form cancelled versus already settled.
- Ambiguous send result after transport break. Verify that only native idempotency permits replay and that all other paths reconcile before a retry prompt.
- Background task completion/failure/cancellation, nested OpenCode background bug behavior, child unread isolation, and external-client status updates.
- Every harness’s external session discovery, resume, live-attach, session ownership, and concurrent operation behavior from the matrix.
- Model capability changes, unsupported image/PDF attachments, missing quotas, partial cost, unknown rate-limit windows, and non-USD/estimated costs.

### Host, platform, security, accessibility

- Test host process start/stop/restart, child process exit, daemon update while active, token revoke/rotation, bounded journal pruning, and WebSocket Origin enforcement.
- Test OpenCode pairing expiry/reuse, wrong password, HTTPS/TLS proxy, CORS allowlist, server version detection, isolated service config/database, and v1 HTML `200`.
- Test web and iOS foreground/background transitions, Android reconnect and notification permission, desktop notification delivery, and battery/network traffic under idle, active stream, and disconnected backoff.
- Test keyboard navigation, screen reader labels, focus for forms/approval cards, reduced motion, RTL layouts, narrow phone dimensions, wide desktop panes, and translation completeness.
- Set budgets before implementation: coalesce presentation updates to at most one frame per 50–100 ms during token streams; no session polling while live streams are healthy; reconnect backoff capped at 60 seconds; stop background retry work after the app/host policy says it is idle.

### Project gates

Use narrow commands during implementation and stable gates before a code commit:

```bash
export PATH="$HOME/flutter/bin:$PATH"
flutter analyze <changed Dart paths>
flutter test <focused unit/widget/contract tests>
make check
make test-web
make android
flutter build ios --no-codesign
flutter build macos
flutter build linux
```

Run Windows builds on Windows CI. Run iOS builds on macOS CI with signing checks for release. `make android` is not a reliable ARM64 Linux release build; use the project’s GitHub Actions runner for release APKs on such hosts. The project explicitly prefers `make check` and `make android` separately; do not run `make precommit` directly. Run targeted code review after each complete, verified non-documentation stage.

## Risks, assumptions, and unresolved verification

| Risk or assumption | Mitigation and fallback |
|---|---|
| OpenCode v2’s API/OpenAPI is described as experimental and its release cadence is rapid. SSE has no replay and may drop lagging clients. | Pin a tested server version, tolerate unknown events, maintain contract fixtures, feature-detect experimental routes, reconcile from history, and expose server compatibility status. |
| CodeWalk-managed OpenCode service may contend with the user’s existing install/service/database. | Run the Stage 1 isolation spike first. If it fails, ask before replacing the user service; keep “connect to existing v2 server” as the supported path. |
| Codex app-server/daemon protocol is labeled experimental; daemon can differ from CLI version. | Negotiate the actual daemon protocol; pin supported ranges, ignore unknown notifications, gate experimental operations, and make session control fail visibly rather than silently. |
| Claude third-party authentication and resuming active sessions require policy and concurrency care. | Use the unmodified official binary/SDK and user-owned auth. Never implement Claude.ai OAuth or collect tokens. Gate OAuth/subscription use on current official terms and counsel/vendor confirmation; API key or supported cloud provider is the strict fallback. |
| Claude history discovery does not imply live attachment to a running TUI. | Label discovery, resume, and live attach independently; detect held sessions; fall back to read-only history until safe. |
| ACP v1 lacks generic replay, quotas, filesystem browsing, terminal, and subagent semantics; ACP v2 remains draft. | Use ACP only where suitable; preserve native extensions and raw provenance; do not build around draft remote transport. |
| Pi provides no built-in permission policy; DSH is unaudited preview; Muse has preview status; Grok extensions change quickly. | Capability and trust labels per adapter; isolate preview integrations behind opt-in and version checks. |
| Same app ID makes v1 rollback and parallel install difficult. | Preserve v1 artifact/branch, migrate/export local state, advance build number, and document reinstall steps. Reopen app ID only if rollback becomes a firm requirement. |
| iOS project and Node host packaging are not established in this repo. | Stage platform setup and package spikes before announcing full support. Keep mobile remote-only. |
| User-managed networking conflicts with reliable push when a mobile OS suspends the app. | No default promise of push. Surface attention on reconnect; allow an optional user-managed push target later. |

## Evidence and source references

Evidence is a 2026-10-02 snapshot; the official source takes precedence over the secondary community example.

- Project decisions and research map: [`plan/02-decisions.md`](/home/ubuntu/MEGA/WORK/codewalk/plan/02-decisions.md:19), [`plan/README.md`](/home/ubuntu/MEGA/WORK/codewalk/plan/README.md:1).
- v1 architecture, UI features, workaround inventory, target/platform constraints: [`plan/00-codewalk-v1-inventory.md`](/home/ubuntu/MEGA/WORK/codewalk/plan/00-codewalk-v1-inventory.md:20), [`plan/01-codewalk-v1-opencode-contract.md`](/home/ubuntu/MEGA/WORK/codewalk/plan/01-codewalk-v1-opencode-contract.md:18).
- Existing implemented behavior: [`BEHAVIOR.md`](/home/ubuntu/MEGA/WORK/codewalk/BEHAVIOR.md:1815) permissions/forms; `:1880` file explorer; `:2396` attention; `:2444` notifications; `:2532` lifecycle; `:2887` reconciliation; `:2924` child attention; `:2936` child navigation.
- Architecture invariants: [`ADR.md`](/home/ubuntu/MEGA/WORK/codewalk/ADR.md:1103) ADR-023 contract-first; `:1593` ADR-029 quota; `:2587` ADR-043 file mutation exception; `:3184` ADR-049 attention surfaces.
- OpenCode v2 official evidence: [`plan/10-opencode-v2-overview.md`](/home/ubuntu/MEGA/WORK/codewalk/plan/10-opencode-v2-overview.md:1); [`plan/11-opencode-v2-server-api.md`](/home/ubuntu/MEGA/WORK/codewalk/plan/11-opencode-v2-server-api.md:52), `:764` session lifecycle, `:970` prompts, `:1268` permissions, `:1433` files, `:1954` usage, `:1969` install; [`plan/12-opencode-v2-events-and-schemas.md`](/home/ubuntu/MEGA/WORK/codewalk/plan/12-opencode-v2-events-and-schemas.md:9), `:456` stream sequence, `:542` permissions, `:640` forms, `:946` subagents; [`plan/13-opencode-v2-vs-v1-diff.md`](/home/ubuntu/MEGA/WORK/codewalk/plan/13-opencode-v2-vs-v1-diff.md:7). Raw source is pinned to `anomalyco/opencode` v2.0.21 under `plan/opencode-v2-src/`; official v2 documentation is archived under `plan/opencode-v2-docs/`.
- OpenCode pairing/service specifics: `plan/opencode-v2-src/server/auth.ts`, `server/pairing.ts`, `server/handlers_server.ts`, `cli/service-registration.ts`, `cli/service-config.ts`, and `plan/opencode-v2-docs/docs-build-client.md:140-176`.
- Codex: [`plan/20-codex.md`](/home/ubuntu/MEGA/WORK/codewalk/plan/20-codex.md:62) surfaces, `:112` daemon, `:170` sessions, `:264` events, `:313` approvals, `:356` quota, `:460` remote, `:546` capability mapping; raw official types and methods under `plan/codex-src/`.
- Claude: [`plan/21-claude-code.md`](/home/ubuntu/MEGA/WORK/codewalk/plan/21-claude-code.md:19) SDK, `:317` permissions, `:356` controls, `:362` sessions, `:369` rewind, `:377` subagents, `:403` usage, `:413` remote, `:427` installation/auth. Current Anthropic documentation says third-party products using the SDK should use API-key or supported cloud-provider auth, disallows offering Claude.ai login or collecting/intermediating its credentials, and permits a user signing into an unmodified Claude Code binary under stated terms: [Anthropic legal and compliance](https://code.claude.com/docs/en/legal-and-compliance). Its hosting guide documents long-lived SDK queries with host-owned subprocesses and session state: [Agent SDK hosting](https://code.claude.com/docs/en/agent-sdk/hosting).
- Pi, Muse, Grok, DSH: [`plan/22-pi.md`](/home/ubuntu/MEGA/WORK/codewalk/plan/22-pi.md:8), `:53`, `:189`; [`plan/23-muse-code.md`](/home/ubuntu/MEGA/WORK/codewalk/plan/23-muse-code.md:8), `:56`, `:214`; [`plan/24-grok-build.md`](/home/ubuntu/MEGA/WORK/codewalk/plan/24-grok-build.md:8), `:37`, `:53`, `:144`; [`plan/25-deepseek-dsh.md`](/home/ubuntu/MEGA/WORK/codewalk/plan/25-deepseek-dsh.md:7), `:40`, `:51`, `:111`.
- ACP and secondary comparison: [`plan/30-acp-and-unifying-protocols.md`](/home/ubuntu/MEGA/WORK/codewalk/plan/30-acp-and-unifying-protocols.md:17), `:95` transport, `:610` registry matrix, `:662` gaps; [`plan/31-multi-harness-clients.md`](/home/ubuntu/MEGA/WORK/codewalk/plan/31-multi-harness-clients.md:73) OpenChamber, `:946` observed patterns. OpenChamber is secondary evidence only; source was pinned to `fc012ae0029fa2ac8d1d52b4af37040fc536258e`.

## Execution start

Start with the service-isolation, Codex-daemon, Claude-history/auth, and Node-packaging spikes before building broad UI. Then freeze the v1 branch/tag, create the v2 skeleton, and implement the OpenCode v2 session/chat vertical slice. Update `ADR-023`, the contract matrix, OpenCode v2 anchors, and later `BEHAVIOR.md`/`CODEBASE.md` as the new behavior becomes real. Any intentional departure from official OpenCode semantics needs a documented ADR exception before implementation.