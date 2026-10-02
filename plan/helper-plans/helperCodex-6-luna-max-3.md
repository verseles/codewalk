# CodeWalk v2 implementation plan

## 1. Status and architectural recommendation

**Recommendation:** build CodeWalk v2 as a new Flutter app skeleton in the existing repository, with an OpenCode v2 adapter and a small host companion for harnesses that only expose local process or socket protocols. Use OpenCode’s official HTTP/SSE service directly when it is reachable and appropriate; use a versioned CodeWalk gateway for host-owned processes and shared local daemons. Do not make other harnesses imitate OpenCode’s API.

The baseline is the user’s recorded decisions in [plan/02-decisions.md](/home/ubuntu/MEGA/WORK/codewalk/plan/02-decisions.md). This plan recommends a hybrid connection design, phased harness rollout, and a TypeScript/Node host. It also identifies two selected choices—default-on allow-all and the v1/v2 update path—that should be reconsidered before implementation. Those recommendations do not replace the selected baseline silently.

The intended client presents a unified session list, chat timeline, composer, usage display, and attention states. Each harness supplies only the features its own protocol supports. The UI shows unsupported or experimental capabilities accurately, while retaining harness-specific details where normalization would lose important meaning.

The research snapshot is dated **2026-10-02**. Material facts below refer to pinned evidence and need rechecking against the exact versions chosen for release.

## 2. Decision Assessment D01–D16

| ID | Verdict | Assessment and concrete recommendation | Confidence and verification |
|---|---|---|---|
| **D01** | **Change direction to hybrid** | The hybrid best fits the combination of OpenCode’s shared HTTP service, Codex’s shared Unix-socket daemon, and the stdio-only protocols. Keep OpenCode as a first-class direct adapter. Use a CodeWalk host gateway for local process/socket adapters, Web access to those adapters, and host-owned notifications. A universal daemon would simplify the client transport but duplicate OpenCode’s service, complicate remote OpenCode servers, and create broader process ownership. Direct-only would leave mobile/Web unable to reach most local-only protocols. | **High** on the shape; **medium** on transport details. Spike host pairing, TLS/reverse-proxy behavior, Codex UDS proxying, and WebSocket auth across desktop, mobile, and Web before fixing the gateway protocol. |
| **D02** | **Change to staged rollout** | Do not release all seven harnesses at once. Recommended sequence: v2.0 OpenCode v2 and platform foundations; v2.1 Codex and Claude; v2.2 Pi and Grok; v2.3 Muse after maturity checks; defer DeepSeek Harness until its preview becomes stable enough. Keep all selected platforms as targets; phase harness support and platform-specific capabilities independently. | **Medium-high.** Recheck current protocol maturity, vendor policy, platform binaries, and support burden at each release gate. |
| **D03** | **Keep** | A new skeleton in this repository allows a clean domain boundary while preserving selected widgets and app-local services. A future v1 maintenance branch is a reasonable archive, but avoid running two app architectures in parallel in the same `lib/` tree. Reuse should be selective and proven by adapter-neutral tests. | **High.** Before the rewrite, map current feature owners and capture local-data migration fixtures. |
| **D04** | **Keep with a migration caveat; reconsider legacy update policy** | Keeping `com.verseles.codewalk` supports in-place app updates and preserves the existing identity. A manual v1 APK can remain available, but it cannot be installed over a newer Android package with a higher version code; users must remove v2 first, and any app data or OpenCode state rollback needs an explicit backup/recovery path. A legacy v1 updater also needs an explicit channel/freeze policy, or its “manual legacy” build may immediately offer v2 again. | **High** on package/version behavior; **medium** on current updater-feed behavior. Verify Android update/uninstall/reinstall, desktop replacement, Web storage, signing continuity, and the v1 update feed in release fixtures. |
| **D05** | **Change default; retain controls** | Keep global and per-session controls, but reconsider **allow-all ON by default**. OpenCode’s server-side wildcard session rule can override agent deny/ask rules and is inherited by children. Other harnesses use different approval and sandbox rules, or provide no permission system. Recommend “Ask” by default, with a deliberate, clearly scoped allow-all opt-in. Preserve the selected default-on behavior as the current baseline until the user decides; do not imply that approval bypass also disables sandboxing. | **High** on risk and semantics. Verify current per-harness permission modes, root/policy restrictions, child inheritance, and whether toggles change approval only or sandbox policy too. |
| **D06** | **Keep with strict source limits** | Native usage signals are the primary source. Keep vendor-host usage probes opt-in, user-triggered or sparsely refreshed, labeled with their source and reliability. Do not read or forward vendor OAuth tokens or scrape harness auth files. For Claude, prefer SDK `rate_limit_event`; defer its experimental subscription-usage endpoint until policy and API stability are verified. | **High** on native surfaces in the dossiers; **medium** on evolving vendor policy and endpoint availability. Recheck each vendor’s official API terms before enabling an opt-in probe. |
| **D07** | **Recommend in-app and host-local attention; no reliable phone push** | OpenCode has no push service. With D08’s no-CodeWalk-relay direction, use live in-app updates, desktop tray/local notifications from the host, and best-effort opt-in Android background checks. iOS should promise in-app attention only; do not claim reliable delivery after suspension or force quit. | **High** on platform constraints and OpenCode transport. Verify Android background behavior on supported OS versions and iOS lifecycle behavior on physical devices. |
| **D08** | **Keep with secure-transport requirement** | LAN, user VPN/Tailscale, SSH tunnel, and a user-managed TLS reverse proxy are workable. Do not expose password-protected HTTP or an unauthenticated WebSocket directly to the public internet. A hosted CodeWalk relay would materially change trust, privacy, operations, and policy assumptions. | **High.** Test exact origin, CORS, TLS, token revocation, and pairing behavior for each chosen connection type. |
| **D09** | **Keep as target platforms; gate claims per platform** | Android, Linux, macOS, Windows, Web, and iOS can remain targets without claiming identical native functionality. iOS has no current runner; Web cannot install host programs; mobile cannot own CLI processes. Report a platform as supported only after its release build and relevant network/auth, accessibility, notification, and lifecycle tests pass. | **High** that iOS and Web have extra prerequisites; **medium** on vendor/package support at release. Verify iOS toolchain/signing, Flutter plugin parity, and desktop architecture coverage. |
| **D10** | **Keep, but pin installation carefully** | Use official OpenCode v2 binaries and verify their SHA-256 from the official update metadata. Use `opencode service`, not the v1-style unmanaged `serve` subprocess. The service should default to loopback and only bind to a user network after explicit configuration. OpenCode v2 uses the same `~/.opencode/bin` path as v1 and migrates shared history, so installation is a meaningful upgrade step. | **High** from pinned source. Verify the selected update API, platform/architecture archive names, SHA handling, service password/pairing behavior, and v1-data migration for the release version. |
| **D11** | **Keep with platform split** | Desktop may install/update the host daemon and eligible harnesses through official channels. Android, iOS, and Web are clients only. Never require a mobile build to install Node, OpenCode, Codex, or another CLI. Do not update a running harness process in the middle of a turn. | **High** on division of responsibility; **medium** on each harness’s supported install channels. Verify each supported OS/architecture and installer update behavior. |
| **D12** | **Keep** | English is suitable for the plan and architecture terms. Preserve app localization separately. | **High.** Review English source names and protocol labels against official docs before publication. |
| **D13** | **Keep as essential; scope the meaning of “continue”** | Session discovery and continuation are feasible but differ by harness. OpenCode’s shared service and Codex’s shared daemon can share live state. Claude, Pi, and some other harnesses can list and resume history, but history resume is not proof of live attachment to a running TUI. The UI must label live-shared, history-resumable, read-only, and CodeWalk-owned sessions separately. | **High** on OpenCode/Codex; **medium** on live ownership for Claude, Pi, Muse, and Grok. Run one bounded external-TUI/live-process attachment spike for each before enabling a “continue live” action. |
| **D14** | **Keep** | A unified session list by host/project with harness badges works if the composite identity includes host, harness, location, and native session ID. Display capability-gated actions and lifecycle states; never infer support from a badge or a tool name. | **High.** Verify source/store identity collisions and multi-host scope isolation in adapter fixtures. |
| **D15** | **Recommend TypeScript on Node LTS** | Node/TypeScript directly fits Claude’s official Agent SDK, Pi’s SDK, Muse’s SDK, ACP’s TypeScript SDK, and process/WebSocket hosting. Prefer Node LTS over Bun because vendor SDK and native-package behavior should follow their documented Node support. Go or Rust would package well but would add either a separate TypeScript worker for Claude or hand-maintained protocol code for several harnesses. Dart AOT would align with Flutter but has less verified coverage for these protocol SDKs. | **Medium-high.** Verify SDK runtime compatibility, bundled Node size, code signing, native dependencies, and Node LTS availability across each desktop target with a small cross-platform host spike. |
| **D16** | **Process-only** | The selected planning concurrency and retention constraints affect the planning workflow, not the product architecture. Preserve recoverability and the requested budget through the orchestrator’s planning records; they do not justify technical design changes. | **High.** Verify that the final plan and task record are preserved before implementation begins. |

### Changes recommended for user discussion

1. **D05:** change the default from allow-all to Ask, while keeping allow-all available as an explicit, scoped setting. This reduces the risk that the default bypasses harness denials or is mistaken for sandbox control.
2. **D04:** keep the same app ID and v2 in-place update, but define a concrete legacy v1 updater policy and a tested uninstall/restore procedure. A manual download alone does not guarantee a usable downgrade path.
3. **D01/D15:** proceed with the hybrid host gateway and Node LTS proposal only after the bounded transport and packaging spikes below.

## 3. Capability matrix

Legend: **Native** = provided by the harness protocol; **Bridge** = CodeWalk host service needed; **Extension** = vendor extension or CodeWalk-supplied extension; **Partial** = limited or non-equivalent; **Experimental** = unstable API; **—** = not available on the cited surface.

Pins are the research snapshot, not a permanent compatibility promise. OpenCode source verification is v2.0.21 commit `8a8bd622`; the dossier records npm 2.0.22 differences. Codex CLI 0.159.3 has a daemon observed at 0.160.0, so negotiate against the daemon. Claude Code 2.1.287 / Agent SDK 0.3.287; Pi 1.0.0; Muse 1.4.2; Grok Build 1.0.46 (the ACP registry snapshot pins 1.0.47); `dsh` 0.2.0-rc.2.

| Area | OpenCode v2 | Codex | Claude Code | Pi | Muse Code | Grok Build | DeepSeek `dsh` |
|---|---|---|---|---|---|---|---|
| **Transport / ownership** | Native HTTP+SSE; shared `opencode service`; pair/auth. Direct connection works when reachable. | App-server v2 JSON-RPC; shared daemon over owner-only Unix socket; host gateway or SSH proxy needed for phone/Web access. Protocol is experimental. | Official Agent SDK/stream-json over host subprocess; no third-party network daemon. Bridge required. | Official RPC JSONL stdio or SDK; bridge required. | Official MSP v1 JSON-RPC NDJSON stdio; bridge required; no MSP auth/network transport. | ACP stdio or native ACP WebSocket server; `ws://` has no TLS, use VPN/SSH/TLS proxy. `x.ai/*` extensions evolve. | Thin ACP v1 over stdio; bridge required; preview. |
| **External sessions / history** | Shared service/TUI state; `/api/session` lists across projects, with pagination. Live global events. | Shared daemon threads include CLI/TUI sessions; `thread/list` must request source kinds as needed; `thread/resume` reattaches and replays pending approvals. | SDK can list/read/resume local transcript history. No official shared daemon; do not claim live attachment to a running TUI. | RPC itself lacks a session-list call; SDK/session files can list and reopen. One active session per RPC process; avoid concurrent owner assumptions. | `session/list`, `session/resume` with cursor/gap recovery and pending request replay; session leases can reject concurrent use. | ACP load/resume/list plus extensions for history; server preserves state across WS reconnects. Confirm exact multi-client ownership per version. | ACP list/resume exists; resume restores history but does not replay prior updates. No live replay guarantee. |
| **Messages / streaming / errors** | Typed text, reasoning, tool-input deltas and authoritative `ended` content; global SSE is live-only. Durable execution/error/retry events; structured errors. | Turn and item lifecycle, text/reasoning/tool/command/diff deltas; completed items authoritative; JSON-RPC/server requests; typed turn failures and retry signals. | Stream-json text, reasoning, tool-use/results, system/retry/error events; subagent content is not uniformly token-streamed. | RPC JSONL text/thinking/tool events; `agent_settled` is the settled boundary, not prompt acceptance. | MSP items/deltas, turn lifecycle, retry and failure events; cursor-based recovery. | ACP text/thought/tool updates; extension notifications add richer lifecycle. | ACP emits committed text/thought chunks, not token-level deltas; SDK JSON notifications are separate. |
| **Permissions / allow-all / sandbox** | Ordered rules and `once|always|reject`; `always` may save project-wide. Wildcard session allow overrides agent deny/ask and is inherited by children. Sandbox is separate. | Native approval requests, approval policy and explicit sandbox policy are distinct. Allow decisions and “full access” must not be conflated. | `canUseTool`/permission updates and permission modes; bypass mode has restrictions and some actions remain unapprovable. Do not handle Claude OAuth tokens. | No native permission system. Project trust controls loading `.pi` resources, not filesystem/process permission. A CodeWalk extension can gate tool calls, but must not claim sandboxing. | Native approval requests, choices and approval mode; policy may prohibit allow-all. `--yolo` differs from disable-approval, which preserves sandbox. | ACP approval requests and `x.ai/*` modes; `--always-approve` exists. Sandbox is separate and requires explicit capability/policy checks. | ACP one-shot allow/reject only. `approvalPolicy: never` means deterministic reject, not allow-all. Linux sandbox limitations are documented. |
| **Forms / questions / plans / tasks** | Questions are Forms with typed fields/conditional visibility. No native todo endpoint/tool in cited v2. Subagents are child sessions. Nested background work has a known upstream bug. | Server-to-client user-input requests; plans/todos and subagent child threads; some plan/queue APIs are experimental. | `AskUserQuestion`, plan-mode approval, background tasks/subagents, todo tools. Todo availability depends on model/config. | No built-in questions, plan, todo, or subagent system; extension UI/todo/subagent additions would be CodeWalk-owned and optional. | Native user questions, todo, goals, subagents and background tasks. | ACP questions plus `x.ai/ask_user_question`; plans/todos/subagents through ACP or vendor extensions. | ACP omits elicitation, plans, todos, and subagent projection, even if the runtime has internal agents. |
| **Usage / quotas / context** | Cost and token totals per session/step; model context/output limits; no remaining-quota endpoint. Quota errors may contain provider details. Stats endpoint is experimental. | Token usage, context window, account rate-limit windows/credits through native account methods and updates. | Cost/tokens/context from result and SDK; `rate_limit_event`; direct usage API is experimental and policy-sensitive. | Token/cost/context session stats; no native subscription quota windows. | Token/context/cost and native 5-hour/weekly usage windows. | Token/cost via ACP and extensions; `x.ai/billing` shape is not fully verified. | Context/usage partial; no cost or quota surface on the cited ACP profile. |
| **Session controls / undo / queue** | Async prompt accepts client message ID for idempotency; steer/queue/inbox, interrupt, fork, delete. No archive route in cited API. Undo is staged revert/commit; canceling staged revert is not universal redo. | Start/steer/interrupt; queue APIs experimental; fork. No file undo. `thread/revert` is limited and rollback was removed. | Push mid-turn input, interrupt, queue behavior, fork/resume. File rewind is partial and does not undo Bash/subagent edits; no redo. | Prompt/steer/follow-up/abort and queue; fork at entry. No file undo. | Start/steer/queue/retract/interrupt, fork at cut point. No general file undo. | Cancel plus extension interject/queue; `x.ai/rewind` rewinds conversation only, not files. | Cancel active prompt only; no steer/queue/fork/delete/undo. |
| **Commands / skills / mentions** | `/api/command`, `/api/skill`, prompt command/skill attachments. File/directory fuzzy search, but no text/symbol search. Mentions are not a general file-search API. | Skills native; no server command registry or custom prompt registry. Fuzzy file search. `@` mentions are paths in text; structured mentions serve app/plugin targets. | Slash commands, custom commands/skills native; bridge supplies file search/listing. CLI expands `@path`. | `get_commands` includes extension commands/templates/skills, not all built-ins; `/skill:name` works. No file search or file mention API. | Skills and command discovery supported by MSP; mentions are text `@relative/path`; verify exact command enumeration on the pinned protocol. | Skills/commands and fuzzy/content search through `x.ai/*`; extension schemas are non-exhaustive. | Commands/skills unsupported on cited ACP surface. |
| **Files / terminal / attachments** | Stable list/find/read, no stable write endpoint; `experimental.fs.write` is not confined to location. PTY uses short-lived connect token; persistent PTY is experimental. Images supported by model; PDF is not a documented attachment type. | Filesystem APIs and PTY/command execution exist; `command/exec` terminal dies with connection. Inline/local images supported; model modalities gate availability. | SDK file read and image blocks; bridge required for tree/search, other file uploads, and PTY. | Bash execution and image input; filesystem view/search and interactive PTY require a bridge; no file snapshots. | Native user shell and image content; host bridge supplies remote file UI and process supervision. | Vendor file/search/git/terminal extensions and image content available; verify capabilities before showing them. | ACP terminal/filesystem operations unsupported; images conditional on the attachment store and route. |
| **Agent/model/reasoning selection** | Agents and models from API; session agent/model selected separately; model variants supported. | Models and reasoning effort dynamically listed; collaboration agents/features include experimental contracts. | Supported models, effort/thinking, and agents via SDK. | Models and thinking levels; no native agent/persona selector. | Model and reasoning effort native; agent/workflow distinctions need version-specific validation. | Model/reasoning config options; agent profile is an extension/launch option. | Provider/model/reasoning effort config options; no agent selector on cited ACP. |

## 4. Architecture and contracts

### 4.1 Boundaries

Use a small number of concrete components:

```text
Flutter application
  app/                 startup, routing, dependency registration
  domain/harness/      IDs, capabilities, sessions, events, permissions, usage
  data/opencode_v2/    HTTP, auth/pairing, SSE, REST mapping, reducers
  data/host_gateway/   CodeWalk gateway client, cursor/replay, host pairing
  features/chat/       timeline, composer, session controller, drafts
  features/sessions/   host/project/harness index and session navigation
  features/files/      capability-gated browser/viewer
  features/terminal/   PTY UI where the adapter exposes it
  features/settings/   connections, capabilities, permissions, theme, locale

packages/host-daemon/
  src/protocol/        versioned client ↔ host contract
  src/runtime/         process supervision, auth boundary, event store
  src/adapters/        codex, claude, pi, muse, grok, acp
  src/platform/        installers, service lifecycle, filesystem, PTY
```

Keep the OpenCode adapter in Dart for direct server connections. The host daemon owns only local processes/sockets and host-only operations; it is not an OpenCode replacement server. Do not put HTTP/Dio calls in presentation widgets, and do not share OpenCode wire DTOs with generic timeline widgets.

### 4.2 Identity, capabilities, and transport

Use composite identity at every persistence and routing boundary:

```text
HostRef      = stable host installation or remote server identity
HarnessRef   = (hostId, adapterId, nativeProfileId)
ProjectRef   = (hostId, harnessId, location/projectId, subpath?)
SessionRef   = (hostId, harnessId, nativeSessionId, locationKey)
```

Never key sessions by native session ID alone. The same ID can appear in different hosts or harnesses.

Each connection handshake returns:

```text
ConnectionDescriptor {
  host, harness, protocolVersion, adapterVersion,
  authState, networkTransport, capabilities, catalogRevision
}
```

`HarnessCapabilities` must be data, not scattered `if (harness == …)` checks. Include explicit support levels and reasons for sessions, history/replay, prompt delivery, queue/steer, interrupt, permissions, forms, plans/tasks, subagents, models/effort, skills/commands, usage, file operations, terminal, attachments, archive/fork/delete, and undo. A capability may be native, bridge-provided, extension-provided, experimental, unavailable, or unknown.

Use a single small adapter boundary with typed operations. Unsupported operations return a typed `CapabilityUnavailable` result; never fake an OpenCode endpoint or pretend an unsupported action succeeded.

### 4.3 Canonical event and timeline model

Keep a neutral projection while preserving protocol provenance:

```text
EventEnvelope {
  eventKey,
  hostSequence?, nativeEventId?, nativeCursor?,
  sessionRef?, occurredAt?,
  durability: durable | ephemeral | unknown,
  protocol: {harness, protocolName, version, nativeType},
  type: open string,
  data: typed union,
  rawReference?     // redacted, size-limited diagnostic reference only
}
```

Canonical event variants should cover session created/renamed/deleted, turn started/settled, user input accepted/delivered/cancelled, text/reasoning delta and final message upsert, tool lifecycle, permission requested/resolved, form requested/resolved, plan/todo snapshot, child task/session lifecycle, usage/context change, retry, structured error, and unknown event.

Represent messages as user/assistant/system/synthetic roles with typed parts: text, reasoning, tool call, diff, attachment, plan, compaction, terminal display, status, or unknown. Keep separate identifiers for session, turn, message, part/tool, task, permission, form, and command. Do not flatten a harness turn into an OpenCode step or treat every tool as an OpenCode tool.

Keep raw provenance available to diagnostics, but do not persist credentials, full terminal streams, or arbitrary raw payloads by default. Unknown event types should remain display-safe and must not crash reducers.

### 4.4 Ordering, replay, and ambiguous mutations

Use the strongest ordering/recovery contract available for each adapter:

- **OpenCode:** one global `/api/event` SSE stream, no SSE replay. Track `durable.seq` per session where present; do not rely on it for ephemeral deltas. Reconnect by reloading active sessions, messages, inbox, permissions, and forms; optionally use the experimental session log behind a capability flag. Treat `text.ended` and message fetches as authoritative after a gap.
- **Codex:** route every notification by thread ID. Resume visible threads after reconnect, page turns/items, and dedupe by stable item IDs. Pending approval requests may replay; do not assume old deltas replay.
- **Claude:** use SDK event order and final messages; on reinitialize recover current permission/dialog requests. Transcript reads are history, not a live-event cursor.
- **Pi:** use `get_entries {since}` and leaf ID, then rehydrate from session messages.
- **Muse:** use view cursors, `view/gap`, `view/page`, and pending approval/input recovery.
- **Grok:** use supported session-update/history methods; treat `x.ai/*` as versioned extensions.
- **ACP v1 / dsh:** no transport-level message replay; resume history does not imply prior updates replay. ACP v2 is still draft and must not be the production baseline.

Every client-generated mutation gets a request ID where supported. For OpenCode prompt retries, reuse the same `msg_` ID; do not retry a prompt without a native idempotency guarantee after an ambiguous timeout. The UI must show “delivery unknown” with a refresh/reconcile action instead of sending a duplicate. Host-gateway mutations use a command ID and an accepted/completed receipt; reconnecting must not replay a mutation automatically.

For multi-client conflicts, apply native settled events and server conflicts. If another client resolves an approval, remove it from all views. Do not resolve or resend stale requests on behalf of the user. Scope cache invalidation to host/project/session so a switch cannot leak drafts or attention state.

### 4.5 State models

Use explicit state machines:

- **Connection:** disconnected → connecting → ready; separate states for degraded, auth-required, incompatible-version, and unavailable. Heartbeat failure triggers reconnect, not turn cancellation.
- **Session:** unloaded, idle, running, waiting-for-user, retrying, failed, interrupted, unknown. Preserve each adapter’s source status and map only clear equivalents.
- **Mutation:** not-sent, accepted, running, completed, failed, delivery-unknown. An HTTP/WebSocket acknowledgment of admission is not equivalent to a completed turn.
- **Permission:** pending, submitting, resolved, stale, unavailable. Render only choices the harness supplied.
- **Question/form:** pending, submitting, answered, cancelled, stale. Dismissal semantics must match the native form, including whether dismissing ends a turn.
- **Child task:** parent/child identity, task kind, state, last update, cancellation capability, and source. Do not infer a child from output text when structured IDs exist.

### 4.6 Host daemon and pairing

Use a TypeScript/Node LTS service with an explicit supported Node version pinned after the runtime spike. Run one per-user daemon, supervise child processes, keep stdout protocol-only and stderr diagnostic, and shut children down by documented lifecycle rather than killing arbitrary process trees. Use official SDKs where materially beneficial; use raw documented protocols where SDK parity is missing.

Expose a versioned CodeWalk protocol over authenticated HTTPS/WebSocket for host adapters. Bind to loopback by default. Pair with a short-lived, single-use code; issue revocable host-scoped credentials; enforce origin allowlists for browsers; store native client credentials in secure storage. For remote access, require the user’s LAN/VPN/SSH/TLS proxy. Do not put long-lived credentials in URL parameters or logs.

The daemon’s event store should be a bounded recovery/notification index, not a substitute for each harness’s native session history. Use a versioned SQLite-backed store only after confirming a cross-platform Node LTS package/build path; otherwise start with a versioned append-only event store plus checkpointing. The spike must decide the storage engine before locking the host wire format.

### 4.7 OpenCode v2 connection contract

- Detect with `GET /api/info`; do not probe v1 paths because the v2 web fallback may return HTML 200.
- Use Basic auth as user `opencode`, with the user-provided password or paired 30-day token as password. Keep tokens in secure storage. Pairing codes are one-use and expire after five minutes.
- Scope location requests with `location[directory]` or `x-opencode-directory`; include `location.directory` explicitly when creating a session.
- Use paginated session/message cursors, session agent/model selection, async prompt admission, `/api/session/active`, and typed execution events. `session.status` is declared but not a reliable publisher.
- Model each inbox item’s steer/queue delivery explicitly. Separate interrupting a running turn from deleting a queued item.
- Map ordered permission rules and preserve exact `once|always|reject` meaning. Explain that “always” can save project-wide approval. Forms must support all field types, conditional fields, custom values, and external URLs or be hidden when unsupported.
- Render `session.execution.*`, retry, structured errors, text/reasoning/tool deltas, and tool final states. Batch high-frequency deltas in the client; do not refetch the entire message for each delta.
- Use native child-session IDs from `parentID` and tool metadata. Surface child permissions/forms in the parent attention view with a source badge. Do not rely on v1 task-ID regex heuristics.
- Do not expose file mutations through `/api/experimental/fs/write` by default: it is experimental and not confined to the selected location. Keep OpenCode file browsing read-only unless a separately reviewed host-side filesystem capability safely enforces root containment.
- Mark stats, session log, persistent PTY, and other experimental routes in the capability set and retain a fallback to stable APIs.

## 5. UX and behavior

### 5.1 Onboarding and connection

Present two primary paths:

1. **Connect to a host/server:** scan or enter an OpenCode pairing URL/code, or pair with the CodeWalk host daemon. Explain when the connection uses a VPN, SSH tunnel, or user-managed TLS proxy.
2. **Set up this desktop:** download a pinned official OpenCode v2 binary for the detected architecture, verify SHA-256, configure/start `opencode service`, confirm `/api/info`, then offer a pairing QR. Also install/update the host daemon and only the harnesses supported on that OS.

The service is loopback-only until the user chooses a network exposure method. A connection test distinguishes DNS/network failure, TLS/certificate issue, pairing expiry, authentication rejection, v1/incompatible server, and service boot failure. Never label an HTML 200 response as a healthy v2 server.

Mobile, Web, and iOS are clients. They never install harness binaries or daemon packages. Web must use HTTPS/WSS in production, correct CORS/origin configuration, and browser-compatible pairing. Keep browser tokens memory/session-scoped by default; do not put them in URLs. iOS support requires a native runner, signed builds, privacy/plugin audit, and physical-device tests before claiming release support.

### 5.2 Unified session home and outside sessions

Group by host → project/location → harness. Include title, harness badge, source/ownership badge, last activity, unread/attention state, and capability-aware menu.

“Continue” has distinct actions:

- **Attach live:** only when the protocol supports safe shared observation/control.
- **Resume history:** start a harness-owned continuation from a native session store.
- **Open read-only history:** show messages without claiming control.
- **Fork:** create a distinct native session/branch.

OpenCode sessions from the shared service and Codex daemon threads are the primary external/live continuity cases. Claude, Pi, Muse, and Grok must be labeled according to their verified ownership behavior. Do not write hooks or mutate a user’s harness config merely to discover sessions without explicit opt-in.

OpenCode v2’s cited HTTP surface has no archive property update. Hide archive for that adapter until an official route is verified; keep delete separate and destructive. Session deletion may recursively delete children.

### 5.3 Chat lifecycle, composer, and timeline

The composer keeps drafts per composite `SessionRef`, attachments, keyboard history, canned answers, voice input, and accessible focus/semantics. Model/agent/reasoning selections are per session or turn exactly as the harness supports. The UI must show whether a selection applies to this turn, subsequent turns, or the session.

Support harness-specific send modes:

- **OpenCode:** prompt ID, text/files/agents/skills, steer or queue; acknowledge admission separately from output.
- **Codex:** start/steer; experimental queue only when negotiated.
- **Claude:** mid-turn user input and cancellation semantics from SDK.
- **Pi:** steer/follow-up/queue and settled event.
- **Muse:** `ifBusy` disposition, steer, queue, unqueue, retract.
- **Grok:** standard cancel plus extension interject/queue when advertised.
- **dsh:** one active prompt and cancellation only.

Expose stop/interrupt separately from canceling queued input. Preserve partial output and show whether a process is interrupted, retrying, or still running. Empty-send “continue” remains only for adapters with a native continuation operation or a tested prompt mapping.

### 5.4 Permissions, forms, and agent-controlled work

Permission cards show the native action, resources, source session, actual native choices, and whether a grant is once/session/project/permanent. Do not add an “Always” button if the protocol did not offer it. If auto-approval is retained, show it per harness and distinguish “approval bypass” from filesystem/network/process sandbox.

Render native forms as typed accessible controls, including validation, conditionals, multi-select/custom answer, and URL hand-off. Preserve native cancel/dismiss effects. A pending form must remain visible while the composer or terminal panel is hidden.

Show agent-controlled plans/todos only if the adapter provides them. OpenCode v2 does not expose the v1 todo surface. Codex plans, Claude todos, Muse goals/todos, and Grok plans should remain distinct source features under a common read-only view model. Never fabricate a task list for a harness that lacks one.

Subagents/background work should appear in a child-session/task panel: parent and child names, harness-native status, live output when available, pending permission/question count, and a cancel control only when supported. Opening a child should preserve the return path to the parent. Warn when the upstream source documents a nested-background limitation.

### 5.5 Usage, files, terminal, and attachments

Show separate values for cost, input/output/reasoning/cache tokens, context occupancy, model limits, and vendor quota windows. Each value includes source and observation time. Do not call context usage “remaining quota.” Sparse quota updates merge by window ID; do not erase a weekly window when only the primary window updates.

Use native file browsing/search and model attachment capability. OpenCode v2 provides path search/read, not content grep or symbol search. Provide content search only through a separate host filesystem capability. File mutations are hidden unless that capability is present and path-confined.

Keep image picking, paste, drag/drop, and model modality gating. PDF is not a documented OpenCode v2 attachment type; preserve PDF viewing/export and offer explicit text extraction only where a tested local extractor can produce a bounded, previewable prompt. Do not silently upload a PDF as an unsupported image/file.

Keep the terminal emulator where a PTY exists, but label “agent terminal output” separately from an interactive shell. OpenCode PTY tokens are short-lived; Codex `command/exec` is not a reconnectable terminal. Do not display terminal controls the protocol cannot execute.

### 5.6 Commands, skills, mentions, and accessibility

Build command suggestions from each harness’s actual catalog and capabilities. OpenCode commands and skills are server-discovered. Codex has no server slash-command registry; map only commands with documented RPCs and expose its skills separately. Claude and Pi expose different command lists and built-ins. Never treat every slash-prefixed input as a CodeWalk command.

Show skills with source/scope and vendor activation behavior. File mentions should insert a native file attachment or resource reference when the harness supports it; otherwise insert a path string only with a clear indication that it is plain text. Do not imply a path was attached when it was merely typed.

Preserve Material You, dark/light/system themes, semantic contrast, screen-reader labels, keyboard navigation, RTL/localized layout, and responsive density across phone, tablet, and desktop/Web. Keep localized interface strings; never translate model or harness content.

## 6. Rewrite, reuse, simplify, defer, discard

| Area | Existing modules / behavior | v2 decision |
|---|---|---|
| App structure/state | `lib/presentation/providers/chat_provider.dart` and parts; `lib/presentation/pages/chat_page.dart` and parts; 22.8k/27.5k LOC god objects | **Rewrite.** New feature controllers and repositories with typed domain state; avoid another class split across `part` files. Preserve viewport/scroll logic only where tests demonstrate reusable behavior. |
| Wire/API | `lib/data/datasources/chat_remote_datasource.dart`, app/project/quota datasources, `lib/domain/repositories/` | **Rewrite OpenCode adapter for v2.** Remove v1 DTOs, routes, payload retries, and compatibility fallbacks. Put all transport behind data adapters; remove the ~26 presentation-side Dio calls. |
| Event/reconciliation | dual SSE, hash dedupe, polling, local IDs matched by text/time, full message refetch per delta | **Discard v1 workarounds.** Use native event IDs, session durable sequence where available, authoritative completion, history rehydration, and explicit ambiguous-send state. Retain bounded reconnect/backoff and backpressure handling. |
| Session/title handling | hidden `_title_gen` sessions and cleanup filters | **Discard.** Use server-native title updates or a local title from the first prompt; manual rename remains. Do not create hidden harness turns. |
| Subagents/tasks | task-ID/output regex and Nth-child matching; OpenCode v1 todo panel | **Rewrite.** Use native lineage IDs and capability-gated task view. No todo pane for OpenCode v2 unless upstream exposes one. |
| File editor/mutations | `workspace_file_operations_service.dart`; shell-script ephemeral sessions; ADR-043 | **Rewrite or hide per connection.** Host filesystem service only when installed on that host with canonical root containment. OpenCode direct mode defaults to read-only browsing because v2 has no stable confined write API. Update ADR-043 or retire its v1 contract. |
| Permissions | `experience_settings.dart`, composer auto-approve and Android background path | **Rewrite per adapter.** Preserve visible cards, but represent exact native options. Revisit default-on allow-all. Never conflate it with sandbox mode. |
| Quotas | `quota_remote_datasource.dart`, encoded JS shell probe, `quota_provider.dart`; ADR-029 | **Simplify.** Native per-harness signals first; opt-in bounded vendor probes with provenance. Remove credential-file scraping and hidden shell probing from the v2 core. |
| Notifications/attention | `notification_service.dart`, `android_background_alert_worker.dart`, session attention services/overlay | **Keep and simplify.** One foreground realtime path, desktop tray/OS notifications, one Android best-effort worker. Keep attention snapshots privacy-limited and encrypted. No claim of iOS push. |
| Sessions/tabs/drafts | `chat_provider` tab/cache/draft parts; `app_local_datasource.dart` | **Keep with new keys/schema.** Scope by host+harness+project+session. Preserve drafts, tabs, pins, recent sessions, local search, and cache-first restore. |
| Rendering/export | `chat_message_*`, `tool_presentation.dart`, `session_export_service.dart`, image export | **Keep rendering; rewrite dispatch.** Render neutral parts and generic unknown tool cards; add native details by adapter. Preserve Markdown/math/code and Markdown/JSON exports with harness metadata. |
| Speech/voice/themes/i18n | STT/TTS services, `lib/presentation/theme/`, `lib/l10n/` | **Keep selectively.** Maintain on-device/client-local voice features, Material You/themes, accessibility, and 14 locales. Recheck plugin support for iOS/Web. |
| Terminal/third-party packages | `terminal_remote_datasource.dart`, CodeWalk PTY socket, vendored xterm/Tailscale | **Keep xterm where supported; rewrite connector.** Tailscale remains optional transport only on validated platforms; iOS may use the OS VPN app. |
| Documentation/contracts | `BEHAVIOR.md`, `ADR.md`, `CODEBASE.md`, `CONTRACT_MATRIX.md`, `ai-docs/opencode_*` | **Coordinate after implementation stages.** Replace v1 claims, update contract matrix, document v2-only support and ADR exceptions, remove obsolete route maps. |

### Local-data and app upgrade

Keep `com.verseles.codewalk` and make the new app build number strictly greater than the current `1.265.0+1790827338`. Retain Android signing identity, macOS bundle ID, desktop update identity, and Web origin. Add a versioned migration for server profiles, secure-storage references, drafts, tabs, preferences, pins, and cached session summaries. Migrate old OpenCode profiles as “unverified”; only mark them OpenCode v2 after `/api/info`. Never silently send credentials to a different origin.

Before the first managed OpenCode v2 start, show a clear one-time migration notice and offer an export/backup path. OpenCode v2 uses the shared `~/.opencode` location and can migrate v1 history; rollback to a v1 server may require restoring a compatible data backup. Keep the legacy v1 download available, but state that Android v1 may require uninstalling v2 and that app data recovery must be tested. A separate v1 update channel or frozen updater policy is required if the legacy build is intended to remain usable after v2 ships.

## 7. Ordered implementation stages

### Stage 0 — bounded feasibility spikes and decision gate

Resolve D01, D04, D05, and D15 proposals before fixing public contracts. Verify the selected OpenCode v2 OpenAPI/schema, pair flow, service lifecycle, and install hashes. Build tiny throwaway prototypes—not shipped abstractions—for:

1. OpenCode service pairing and reconnect/resync against a TUI-created session.
2. Codex shared-daemon UDS proxy and protocol version mismatch.
3. Host gateway authentication from Flutter desktop, Android, iOS, and Web, including TLS proxy and browser origin.
4. Claude SDK session list/resume versus a running terminal/TUI session, without reading or forwarding credentials.
5. Node LTS/SDK packaging and signing across Linux, macOS, and Windows.

**Gate:** no host protocol commitment until process ownership, event recovery, auth, and platform packaging are demonstrated.

### Stage 1 — new app skeleton and local migration

Create the Flutter app/domain/data/feature boundaries, typed IDs/capabilities, storage schema version, routing, localization plumbing, and fixture-test harness. Add the desktop host-daemon package skeleton and its protocol version negotiation. Do not port the old ChatProvider wholesale.

**Acceptance:** profile/draft/tab migration fixtures pass; no cross-host draft/cache leakage; startup works with zero connections; all target platform runners can compile their supported baseline.

### Stage 2 — OpenCode v2 vertical slice

Implement `/api/info`, pairing/basic auth, server profiles, project/session cursor paging, create/open/resume, model/agent selection, text/image send, async prompt receipt, text/reasoning/tool stream projection, stop, and session error states.

**Acceptance:** a TUI-created session appears in CodeWalk; a CodeWalk message appears in the TUI; ambiguous prompt timeout never creates a duplicate; reconnect restores visible history and state; v1 endpoints are rejected as incompatible.

### Stage 3 — OpenCode interaction and workspace slice

Add permissions, Forms, inbox queue/steer, child-session/subagent view, usage/cost/context, terminal PTY, read-only file tree/viewer, session fork, and staged revert UI. Put experimental endpoints behind capability flags. Keep file writes hidden unless a confined host service is present.

**Acceptance:** permissions and forms survive disconnect/reopen; child identity is exact; `session.execution.*` drives busy/idle; nested background limitation is surfaced; revert stages/commits/cancels accurately.

### Stage 4 — host gateway and Codex/Claude

Add authenticated pairing, reconnectable host event log, process supervision, Codex shared daemon adapter, and Claude Agent SDK adapter. Support external session discovery before adding new-session flows. Require Codex schema/version negotiation and Claude auth/policy disclosure.

**Acceptance:** Codex TUI threads are visible and can be safely resumed through the daemon; pending approvals resolve consistently across clients. Claude terminal history is listed; live TUI attachment is shown only if a safe supported ownership mode is verified. API-key users can run without CodeWalk reading auth files.

### Stage 5 — Pi/Grok, then Muse; defer `dsh`

Implement Pi RPC with explicit optional CodeWalk extension support; Grok ACP plus only negotiated `x.ai/*` extensions; Muse MSP v1 with cursor/idempotency and native usage windows. Keep `dsh` on the deferred list until its preview contract and session replay/lifecycle meet the core gate. Add generic ACP v1 only as an isolated long-tail adapter, not as a replacement for richer native protocols. Do not base production on ACP v2 draft transport.

### Stage 6 — platform, attention, and release gates

Enable features by actual platform and adapter capability. Finish iOS runner and signing before calling it supported. Validate Web pairing and secure storage limits. Add Android best-effort notifications and desktop tray behavior; do not promise phone push without a user-managed push service.

Release order is by readiness, not dates: v2.0 OpenCode v2 foundation, then Codex/Claude, Pi/Grok, Muse, and a fresh `dsh` decision. Do not block Android/Linux/macOS/Windows/Web platform work on later harness phases; do gate each platform’s release claims separately.

## 8. Testing and validation plan

Planning-only work has run no tests or builds. Implementation validation should combine adapter fixtures, focused Flutter tests, host-daemon tests, and platform CI.

### Adapter and lifecycle fixtures

- Pin fixture transcripts and schemas by harness/protocol version. Test unknown event types, extra fields, malformed frames, oversized payloads, duplicate IDs, missing optional fields, and forward-compatible enum values.
- OpenCode: pairing expiry/reuse, v1 HTML 200 response, location scoping, cursor paging, duplicate prompt ID, lost prompt response, 4,096-event overflow, missing ephemeral deltas, `log.synced` watermark, late final text/tool result, Forms, permission rejection, and `SessionBusyError`.
- Codex: daemon/CLI version skew, all-thread subscription, external TUI thread discovery, resume approval replay, sparse rate-limit merge, unsupported experimental method, origin rejection, overload backoff, and command/terminal disconnect.
- Claude: running terminal/TUI session list versus SDK resume, permission update/cancel ordering, queued-message receipt after interrupt, restart/reinitialize, task stop, file rewind limits, rate-limit event and no-auth failure. Validate policy text and supported login flow.
- Pi: LF-only JSONL parsing, stdout/stderr separation, `agent_settled`, queue disposition, session cursor recovery, extension approval timeout, and no native permission fallback.
- Muse: UUIDv7 command-id retry, session lease conflict, cursor gap/page, pending approval/question replay, queue retraction, usage sparse merge, `disable-approval` versus `yolo`.
- Grok: WS reconnect state, secret/TLS boundary, ACP capability negotiation, unknown extension, ask-user request, session history update replay, and conversation rewind leaving files untouched.
- `dsh`: one-shot allow/reject, cancellation, no history replay, missing questions/commands/terminal, and committed-chunk behavior.

### UI, storage, and platform checks

Test ordering and reducer races, active-session switch during deltas, two clients resolving the same approval, stale forms, process death during sending, reconnect while a child task runs, and isolated multi-host/project caches. Add performance tests for long timelines, bursty tool output, and background battery use. Cap message residency and attachment parsing; stream large output rather than buffering it all.

Test accessibility semantics, keyboard/focus order, RTL, large text, contrast, responsive phone/tablet/desktop/Web layout, and notification payload privacy. Test iOS suspension/force quit, Android background restrictions/Data Saver, browser CORS/origin and secure-context behavior, and desktop service shutdown/update while a harness is active.

### Commands and gates

- During implementation: focused `flutter test test/unit/...` and `flutter analyze <changed paths>`, with `export PATH="$HOME/flutter/bin:$PATH"` in shell commands.
- Host daemon: pinned Node LTS typecheck, unit/fixture tests, package/signing checks for each supported OS.
- Web: `make test-web` with Chrome and `make web`.
- Release validation: run `make check` once the code is stable and before the first code commit; run `make android` only on a supported non-ARM64 Linux host. Android release APKs for ARM64 Linux hosts should come from GitHub Actions. Build iOS on macOS runners, Windows/macOS/Linux targets on their native CI runners.
- Do not use `make precommit` directly for normal CodeWalk validation. Run platform builds again if the final code changes invalidate the passing gate.

After each coherent code stage and focused verification, run the required reviewer workflow. This task is planning-only, so no review or validation command was executed.

## 9. Risks, assumptions, sources, and execution start

### Risks and mitigations

- **Protocol churn:** Codex app-server is experimental; Muse is young; Grok extensions evolve; `dsh` is a preview. Pin tested versions, negotiate capabilities, retain unknown events, and run contract fixtures before version upgrades.
- **False cross-harness equivalence:** permission, sandbox, undo, queue, terminal, quota, and session ownership differ. Show native options and capability source; do not normalize away effects.
- **OpenCode gaps:** no stable file write or remaining-quota API; SSE is not replayable; nested background completion has a known bug. Use rehydration and stable endpoints, and hide unsupported UI.
- **Credentials and policy:** credentials stay on the host and inside official harnesses. Never collect/forward Claude OAuth tokens or scrape auth databases. Recheck official policies before vendor usage probes.
- **Network exposure:** OpenCode Basic auth and some native WebSocket servers need VPN/TLS protection. Require explicit network binding, narrow origins, short-lived pairing, and redacted diagnostics.
- **No push relay:** background alerts are best-effort on Android and unavailable as reliable remote push on iOS under the selected D08 direction.
- **Migration/rollback:** same app identity enables updates but complicates legacy downgrade; OpenCode v2 migrates shared server data and replaces the v1 binary path. Test backup/restore before release.
- **File path escape:** OpenCode experimental write is not location-confined. Keep direct mode read-only unless a host-side operation validates canonical paths and symlinks under an authorized root.
- **Source/version drift:** the evidence pack includes v2.0.21 source and npm 2.0.22 differences, plus harness version discrepancies. Re-fetch current official schemas and pinned binaries before implementation.

### Assumptions and fallbacks

- The host daemon runs only on supported desktop hosts. If Node LTS packaging or Claude SDK support fails the spike, evaluate a Go daemon with a narrowly scoped official Node worker for Claude; do not replace SDK contracts with shell scraping.
- If Codex UDS proxy cannot preserve the shared daemon session safely, expose Codex history as read-only and defer live control; do not create a second server against the same `CODEX_HOME` without evidence.
- If Claude SDK cannot safely resume a terminal-created session while another process owns it, list/read the history and enable continuation only after the owner exits.
- If iOS background delivery cannot be reliably tested without a hosted relay, retain in-app-only attention.
- If OpenCode experimental session log changes, use REST rehydration and retain the last stable event/message projection.
- If a harness has no native file search, omit search or use the explicit host filesystem capability. Never invent a server endpoint.

### Unresolved questions

1. Does each selected OpenCode v2 release expose the same pairing, service registration, event/log, and session migration behavior as v2.0.21?
2. Can Codex daemon UDS be securely and reliably proxied across SSH, VPN, and Web gateway without breaking its WebSocket framing or shared-session semantics?
3. Can Claude SDK resume/history operations safely coexist with a running TUI session, and what official hooks permit observation without takeover?
4. Which vendor usage probes are policy-compliant and stable without reading private auth files?
5. Which supported Flutter plugins and signing workflows make iOS a releasable target, and what Tailscale/VPN behavior is delegated to the OS?
6. Which exact Node LTS and storage package can ship on all supported desktop targets without an unsupported native dependency?
7. What will the final v1 updater do after v2 is published, and what exact backup/uninstall procedure preserves user data when returning to v1?

### Source references

Primary local evidence:

- [plan/00-codewalk-v1-inventory.md](/home/ubuntu/MEGA/WORK/codewalk/plan/00-codewalk-v1-inventory.md) §§1–5: app structure, 110-feature inventory, v1-only workarounds, reuse seams.
- [plan/01-codewalk-v1-opencode-contract.md](/home/ubuntu/MEGA/WORK/codewalk/plan/01-codewalk-v1-opencode-contract.md) §§2–6: current v1 routes/events/sending/permissions and gaps.
- [plan/10-opencode-v2-overview.md](/home/ubuntu/MEGA/WORK/codewalk/plan/10-opencode-v2-overview.md), [plan/11-opencode-v2-server-api.md](/home/ubuntu/MEGA/WORK/codewalk/plan/11-opencode-v2-server-api.md), [plan/12-opencode-v2-events-and-schemas.md](/home/ubuntu/MEGA/WORK/codewalk/plan/12-opencode-v2-events-and-schemas.md), [plan/13-opencode-v2-vs-v1-diff.md](/home/ubuntu/MEGA/WORK/codewalk/plan/13-opencode-v2-vs-v1-diff.md): pinned OpenCode contract and migration.
- [plan/20-codex.md](/home/ubuntu/MEGA/WORK/codewalk/plan/20-codex.md), [plan/21-claude-code.md](/home/ubuntu/MEGA/WORK/codewalk/plan/21-claude-code.md), [plan/22-pi.md](/home/ubuntu/MEGA/WORK/codewalk/plan/22-pi.md), [plan/23-muse-code.md](/home/ubuntu/MEGA/WORK/codewalk/plan/23-muse-code.md), [plan/24-grok-build.md](/home/ubuntu/MEGA/WORK/codewalk/plan/24-grok-build.md), [plan/25-deepseek-dsh.md](/home/ubuntu/MEGA/WORK/codewalk/plan/25-deepseek-dsh.md): harness protocols, versions, capabilities, and gaps.
- [plan/30-acp-and-unifying-protocols.md](/home/ubuntu/MEGA/WORK/codewalk/plan/30-acp-and-unifying-protocols.md), [plan/31-multi-harness-clients.md](/home/ubuntu/MEGA/WORK/codewalk/plan/31-multi-harness-clients.md): ACP maturity, remote transport, client patterns, and the pinned secondary OpenChamber reference.
- [BEHAVIOR.md](/home/ubuntu/MEGA/WORK/codewalk/BEHAVIOR.md): current interactive prompts (§ around line 1815), task list (1895), session attention (2396), notifications (2444), lifecycle (2532), reconciliation (2887), and subagent behavior (2924–2936).
- [ADR.md](/home/ubuntu/MEGA/WORK/codewalk/ADR.md): ADR-023 contract-first policy (1103–1255), ADR-029 quota probes (1593 onward), ADR-033 reverse-proxy auth (1889 onward), ADR-043 shell-backed file operations (2587 onward).
- [CODEBASE.md](/home/ubuntu/MEGA/WORK/codewalk/CODEBASE.md), [CONTRACT_MATRIX.md](/home/ubuntu/MEGA/WORK/codewalk/CONTRACT_MATRIX.md), [Makefile](/home/ubuntu/MEGA/WORK/codewalk/Makefile), [pubspec.yaml](/home/ubuntu/MEGA/WORK/codewalk/pubspec.yaml), and `.github/workflows/`: current modules, app identity, build/release gates.

Official source anchors to recheck before implementation:

- OpenCode v2 docs: <https://opencode.ai/v2/docs/>; pinned source tree: <https://github.com/anomalyco/opencode/tree/v2.0.21>; v2 install: <https://opencode.ai/v2/install>.
- Codex app-server docs: <https://developers.openai.com/codex/app-server/>; protocol and generated schema must match the daemon’s reported version.
- Claude Agent SDK: <https://code.claude.com/docs/en/agent-sdk/overview>; policy: <https://code.claude.com/docs/en/legal-and-compliance>.
- Pi RPC docs and pinned release: <https://github.com/earendil-works/pi/tree/v1.0.0/packages/coding-agent>.
- Muse SDK/MSP: <https://github.com/meta-models/muse-code-sdk>.
- Grok Build source pin: <https://github.com/xai-org/grok-build/tree/2bdd1d6a6369de0e8c68132ea4539e9abd9e14a8>.
- ACP stable/v2 status: <https://agentclientprotocol.com/>.
- OpenChamber secondary reference is pinned at `fc012ae0029fa2ac8d1d52b4af37040fc536258e`; it remains a community UX reference, not the OpenCode contract.

### Execution start

The orchestrator should first verify the clean/task-scoped diff and current revision, then re-fetch the selected official schemas and run the five Stage 0 spikes. No implementation should start until the host gateway transport, Node packaging, D04 rollback/update policy, and D05 approval-default decision are recorded. First implementation files should be the new typed domain contracts and adapter fixtures, followed by the OpenCode v2 vertical slice.