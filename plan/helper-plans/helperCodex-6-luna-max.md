# CodeWalk v2 implementation plan

## Status and recommendation

**Planning outcome:** build CodeWalk v2 as a new Flutter client skeleton in the existing repository. OpenCode v2 remains the primary, direct integration. Add a small **TypeScript/Node host service** only for harnesses that need a local process, Unix socket, or browser-safe gateway. Keep harness APIs and state distinct behind typed adapters; do not make another harness pretend to be OpenCode.

This plan uses the user’s recorded decisions as its baseline, including the same app ID, six target platforms, user-managed networking, and D13’s external-session requirement. **D05 remains the selected baseline in the decision register, but this review recommends changing its default from allow-all to ask.** That recommendation is separated below and requires discussion before it becomes the release direction.

There is no planning blocker. Several release-critical facts need bounded verification before implementation choices are locked: OpenCode v2 auth behavior at the selected binary version, Codex shared-daemon connectivity and version drift, Claude history-resume conflicts, Node host packaging, and iOS/Web transport behavior.

Evidence below is a snapshot dated **2026-10-02**. It is not a promise that the rapidly changing protocols still have these exact versions or contracts at implementation time.

## 1. Decision Assessment: D01–D16

“Baseline” means the choice recorded by the user. The verdict evaluates that choice; it does not silently replace it.

| ID | Verdict | Evidence and argument | Alternative and tradeoff | Confidence and verification |
|---|---|---|---|---|
| **D01 — connection architecture** | **Unresolved; recommend hybrid** | OpenCode v2 provides its own shared per-user service and API. Codex’s shared daemon is a local Unix socket; ACP’s stable transport is stdio; Claude’s Agent SDK runs on the host. A single direct client cannot use all these surfaces. A universal CodeWalk proxy would duplicate OpenCode’s session and event responsibilities. See `plan/10`–`plan/12`, `plan/20` §§1–2, `plan/21` §2, `plan/30` §2. | Direct Flutter-to-OpenCode v2; CodeWalk host service for Codex and locally spawned SDK/RPC/ACP harnesses; optional host gateway for browser or secure remote access. This adds a host package and process lifecycle, but avoids proxying ordinary OpenCode traffic. | **High** for the surfaces in the snapshot. Verify by desktop, Web, and mobile connection spikes and an OpenCode version-pinned API smoke run. |
| **D02 — release phases** | **Unresolved; recommend phased rollout** | OpenCode v2 is newly released and its API is described as experimental in the OpenAPI document. Codex app-server is also labelled experimental; DSH is a preview. There is no basis for asserting all integrations have equal readiness. | v2.0: OpenCode first-class plus D13’s Codex and Claude session discovery/resume in preview. v2.1: harden Codex/Claude, add Pi and stable ACP v1. Later: Grok and Muse after protocol/auth gates; DSH after a stable history and interaction surface. Costs are extra preview maintenance; benefit is avoiding false parity. | **Medium-high.** Confirm the exact versions, policy, test coverage, and support matrix at each release gate. This sequence is a recommendation, not an accepted release decision. |
| **D03 — same repo, new skeleton** | **Keep** | The v1 inventory shows ~158k handwritten Dart LOC, 83% presentation code, very large ChatProvider/ChatPage part families, wire details leaking into UI, and 26 presentation files using Dio directly. Selective reuse is safer than extending the existing protocol-coupled structure. See [inventory §0–1](</home/ubuntu/MEGA/WORK/codewalk/plan/00-codewalk-v1-inventory.md#L20>) and `CODEBASE.md` §§ chat/data. | Separate repository would isolate release and dependency churn but duplicate localization, visual components, and maintenance. Keep one repository and establish an isolated `v2` application structure; preserve a v1 maintenance branch at its final v1 commit. | **High.** Before branch/rewrite work, confirm the exact preservation point and inventory only reusable modules. |
| **D04 — same app ID and manual legacy v1** | **Keep with migration safeguards** | `com.verseles.codewalk` is the Android application ID and macOS bundle namespace; current version is `1.265.0+1790827338`. Same ID and signing allow an in-place upgrade, but Android does not ordinarily permit installing an older APK over a higher version code. See `pubspec.yaml:19`, `android/app/build.gradle.kts:77,93`, and local Makefile build-number logic. | A distinct v1 application ID would permit side-by-side installs and simpler rollback, at the cost of changing the baseline and splitting identity/update handling. Retain the baseline, but make manual v1 downloads’ downgrade/data implications explicit. Keep version codes coordinated across branches and create a recoverable local-data export before migration. | **Medium-high.** Verify signer continuity, updater behavior on every shipped platform, the version-code sequence, and what manual v1 restoration actually requires. |
| **D05 — allow-all ON by default** | **Change recommended; 5A remains the recorded baseline pending discussion** | Harnesses do not share an allow-all control. OpenCode’s rules are ordered and “always” can persist project-wide; its wire/API does not expose one universal YOLO switch. Codex approval policy and sandbox are separate. Claude bypass mode is distinct from sandbox policy. Pi has no built-in tool permission system and is YOLO-oriented; a client extension can gate some tool calls but is a different mechanism. DSH’s ACP approval choices are one-shot. See `plan/12` §§7.2–7.6 and each harness dossier’s permissions section. | **Recommended alternative:** default to ask/host policy and offer explicit, accurately scoped “allow all” only when the adapter confirms support. Keep approval policy separate from filesystem/process sandboxing. Benefit: truthful and safer defaults. Cost: more prompts and uneven controls; Pi would need a maintained CodeWalk extension for meaningful gating. | **High** that universal semantics are false; **medium** on exact OpenCode session-rule precedence. Verify OpenCode config/agent/session precedence and each adapter’s tool coverage before a default is shipped. |
| **D06 — native usage plus opt-in vendor queries** | **Keep, with a strict boundary** | Native signals vary: Codex rate limits; Claude rate-limit events; Muse quota windows; OpenCode tokens/cost without remaining quota. A token total is not a quota. Some host-side endpoints are experimental or may require vendor credentials. See `plan/10` §g and `plan/20` §3.8, `plan/21` §3.15, `plan/23` usage sections. | Do not inspect or forward local auth databases/tokens. Allow separately opted-in queries only against documented public vendor endpoints with host-side credential handling and a visible source/freshness label. | **Medium-high.** Recheck endpoint documentation and authentication rules at implementation; Claude usage polling remains particularly uncertain. |
| **D07 — notifications/background delivery** | **Unresolved; recommend local, best-effort delivery only** | OpenCode v2’s SSE is live-only, and no OpenCode push service is documented. Android background work can be delayed by OS constraints; iOS/Web cannot promise delivery while killed or offline. Current CodeWalk attention surfaces are deliberately default-off. See [BEHAVIOR.md:2396](</home/ubuntu/MEGA/WORK/codewalk/BEHAVIOR.md#L2396>) and [BEHAVIOR.md:2444](</home/ubuntu/MEGA/WORK/codewalk/BEHAVIOR.md#L2444>). | Keep desktop/local notifications and Android opt-in bounded status checks. No CodeWalk-hosted push relay under D08. A later user-managed notification sink would add setup and privacy risk and should be a separate opt-in. | **High** on no guaranteed background delivery; **medium** on Android policy details across target versions. Validate on physical Android and iOS devices before advertising notification support. |
| **D08 — user-managed networking** | **Keep** | Codex remote access can use SSH to the shared daemon; stdio harnesses require a host. ACP’s remote transport remains an Active RFD, not a stable universal transport. No CodeWalk relay is selected. See `plan/20` §4 and `plan/30` §§2–2.4. | Default the bridge to loopback. The user may expose it using LAN, Tailscale/VPN, SSH, or their TLS reverse proxy. A hosted relay could simplify setup but changes privacy, service, and operations scope. | **High.** Verify each transport’s auth, browser Origin/CORS, and recovery behavior; do not expose unauthenticated bridge ports. |
| **D09 — Android/Linux/macOS/Windows/Web/iOS** | **Keep, with explicit support tiers** | The current inventory targets Android, desktop, and Web, but there is no `ios/` project. Web cannot spawn local processes or connect to Codex’s Origin-rejecting WebSocket. iOS cannot run desktop harness daemons or provide Android-style background services. See `plan/00` §1.1/§1.8 and `plan/20` §4. | Keep all six targets. Define core remote-client support separately from host installation, terminal, background, and local-auth capabilities. This avoids treating six target platforms as six identical execution environments. | **High** on differences. Verify plugin support, iOS signing/build, Windows ARM64 OpenCode installation, and browser auth/CORS in spikes. |
| **D10 — official OpenCode binary, SHA-256, shared service and pairing** | **Keep, with version pinning** | The official v2 installation and `opencode service` are documented; the shared service defaults to port 49374. The source pack has a source-pinned v2.0.21 implementation while npm latest was 2.0.22 on the research date. The v2 API contract is changing quickly. See `plan/10` §§a–b and `plan/11` §§1.1–1.3. | Install a tested version from the official source and verify its official hash. Stage updates rather than tracking a moving latest binary at runtime. Keep remote servers user-managed. | **High** for the cited version snapshot. Test the installer/hash source, pairing flow, and service restart behavior per OS. The wire auth scheme is confirmed by pinned source, not clearly stated in all docs; verify the selected release. |
| **D11 — desktop installs/updates host tools; mobile connects** | **Keep** | The selected harnesses’ useful surfaces are local SDKs, CLIs, sockets, or stdio; Android/iOS/Web cannot own these desktop host processes. | Use per-user, version-pinned official installs. Make install/update opt-in and show each harness’ official source and installed version. Never install on Android, iOS, or Web. | **High** on host need. Verify official installation and signing flows, especially for Claude, Muse and Windows ARM64. |
| **D12 — English plan** | **Keep** | This is a delivery preference; it does not affect product feasibility. | No technical alternative needed. Keep user-facing app strings localized independently. | **High.** Check the final planning document language. |
| **D13 — external sessions are essential** | **Keep, with honest ownership labels** | OpenCode’s shared service and Codex’s shared daemon support live shared state. Claude exposes local history discovery/resume but not a public live attachment to a running TUI. Pi, Muse, Grok, and DSH each have different persistence or replay limits. See `plan/10` §b, `plan/20` §§2.4/3.3, `plan/21` §3.6, and `plan/22`–`25` session sections. | Preserve list/continue as a release gate for OpenCode, Codex, and Claude, but label Claude as history/resume rather than live attach. If Claude cannot safely resume a history in use, list it read-only until inactive or revisit the D13 requirement explicitly. | **High** for OpenCode/Codex sharing; **medium** for Claude history concurrency. Verify each through a real host-owned process spike without collecting credentials. |
| **D14 — unified session list with harness choice** | **Keep** | `SessionKey` can unify discovery and navigation without making the protocols uniform. Capabilities can hide or disable unsupported controls. | Keep one list grouped by host/project with a harness badge and distinct states such as “live shared,” “resumable history,” and “CodeWalk-managed.” Do not imply every row has the same operations. | **High.** Contract-test identity collisions and project filtering for each adapter. |
| **D15 — daemon runtime** | **Unresolved; recommend TypeScript on Node.js 22 LTS, not Bun** | Claude’s official Agent SDK and Pi/Muse/ACP surfaces have strong TypeScript/Node integration. A Node host can use those SDKs while driving Codex/OpenCode native protocols. Go/Rust reduce deployment footprint but require a Node sidecar for Claude’s official SDK or a less direct integration. Dart AOT could simplify sharing but lacks equally mature official harness SDK coverage in the evidence pack. | Bundle a pinned, verified Node runtime with the desktop host service. If packaging, sandboxing, startup, or memory costs fail the spike, reassess Go plus a narrowly scoped official SDK child process. Bun is not the default because SDK/package compatibility was not established. | **Medium.** Package and test the runtime on Linux/macOS/Windows x64/ARM64; inspect macOS sandbox entitlements and process cleanup. |
| **D16 — planning process and artifact retention** | **Process-only** | This decision governs planning dispatch and preservation, not product architecture. | No product alternative. Preserve the resulting plan and its evidence references in the orchestrator’s designated location. | **High** for classification; verify only against the orchestration record. |

### Recommended changes to discuss before final direction

1. **D05:** change the default to ask. The current selection cannot be represented accurately as one global behavior across the named harnesses, and “always” may have broader scope than a session.
2. **D04:** keep the single app identity only if the project accepts that restoring an older v1 APK may require uninstalling and could lose v2-local data. A distinct legacy application ID is the concrete side-by-side alternative.
3. **D15:** choose Node 22 only after the packaging spike. If the host runtime cannot be bundled safely across desktop targets, reopen the runtime choice before adapter implementation.

## 2. Intended user behavior

A user installs or updates CodeWalk on a supported platform, adds an OpenCode v2 server or a desktop host, pairs securely, and sees sessions grouped by host and project. The session list distinguishes live shared sessions from history that can be resumed and sessions managed by CodeWalk. Creating a chat requires selecting a harness only when more than one is available for the chosen host.

In chat, CodeWalk renders each harness’ text, reasoning, tool output, plan/task updates, questions, approvals, usage, and failures using typed UI models. Controls appear only when the connected adapter and current session support them. Reconnecting restores the best available snapshot and identifies any unrecoverable event gap; the app does not silently resend an ambiguously delivered prompt.

The UI keeps mobile-first Material You presentation and responsive desktop/Web layouts. It does not claim parity where an upstream protocol has none: for example, an OpenCode quota meter, PDF upload, file undo for Codex, or live Claude TUI attachment.

## 3. Capability matrix

**Legend:** `N` native harness protocol/API; `B` CodeWalk host bridge or desktop service; `X` harness extension; `E` experimental, draft, or fast-changing; `P` partial/conditional; `—` absent in the inspected surface. Versions are the **2026-10-02 evidence snapshot**, not pinned implementation requirements.

| Harness / inspected surface | External discovery, resume and ownership | Stream, tools, plans and child work | Approval, question and safety | Usage | Files, undo and attachment | Control, commands, models, terminal |
|---|---|---|---|---|---|---|
| **OpenCode v2** — source v2.0.21 `8a8bd622`; npm latest 2.0.22. Official `/api/*`, shared service | `N`: project/location session list, create, resume, fork, archive/delete; sessions from TUI share service. Live shared state. | `N`: typed message/tool stream and async subagent children. `session.execution.*` and active-session API; no v2 todo endpoint. | `N`: ordered permission rules, pending request/reply, forms. “Always” may save project scope. No dedicated allow-all mode. Permission-rule precedence needs release-pinned test. | `N`: tokens, cost, context/model limits. No general remaining-quota API; provider rate failures only. | `N`: list/find/read and VCS status/diff. No stable write surface; experimental write is unsafe for arbitrary path scope. Staged revert depends on Git snapshots. Native image types; no PDF. | `N`: steer/queue prompt delivery, interrupt, commands/skills and model/agent/variant. PTY with WebSocket ticket; persistent PTY experimental. |
| **OpenAI Codex** — CLI 0.159.3; shared daemon 0.160.0; source `rust-v0.160.0` | `N+B`: app-server v2 over daemon UDS; session/thread discovery includes CLI/TUI threads; `thread/resume` reattaches and replays pending approvals. Daemon version can drift from CLI. | `N+E`: streamed text/reasoning/commands/diffs, plans and child threads/subagents. Queue/plan features are experimental. | `N`: server approval requests; experimental user-input requests. Approval policy and sandbox are distinct. | `N`: thread token/context and account rate-limit windows/credits when supported by auth. | `N`: host filesystem and file search; no file undo. Fork/rewind is conversation history, not filesystem restoration. Images via data/local references; no HTTP image URLs. | `N+E`: turn steering; queue experimental; skills/model/effort. No server slash-command registry. Command/exec terminal is connection-bound. Browser cannot connect directly to WS carrying Origin. |
| **Claude Code** — Agent SDK 0.3.287; CLI 2.1.287 | `B+N`: host SDK/CLI history enumeration and resume/fork; local JSONL history. **No public live attachment to an already-running TUI.** Guard against concurrent use of a session. | `N+B`: SDK streaming, tool output, plans, tasks/subagents; host owns running query and remote stream. | `N`: `canUseTool`, permission modes, questions. Set mode explicitly. Bypass mode is not equivalent to OS sandbox. | `N+E`: token/cost/context and rate-limit event. Usage pull is experimental; cost may be estimated. | `N+B`: SDK read/write tool events; CodeWalk needs host bridge for browse/search/PTY. File rewind covers selected writes, not Bash or subagents; no redo. Images supported. PDF requires a tested conversion path. | `N+B`: SDK interruption and mid-turn input/queue; native commands/skills/model/effort/agents. Bridge must own sessions, file index and terminal. |
| **Pi** — `@earendil-works/pi-coding-agent` 1.0.0; `pi --mode rpc` | `B+N`: SDK `SessionManager` can enumerate/resume history; RPC itself lacks list-sessions. No live attach to existing TUI. | `N`: typed JSONL text/thinking/tool events and settled state; no built-in plan/todo/subagent system. Extensions can add UI. | `X`: no built-in permission system; YOLO-style tool access. Extension UI can request confirmation, but is not a native sandbox. | `N`: token/cost/context stats; no quota window. | `B`: no native file browser/search endpoint. Fork/tree is session history, not disk undo. Images supported. | `N+B`: steer/follow-up queue, abort, model/thinking levels, extension skills/commands (not all TUI commands). `bash` is not persistent PTY. |
| **Muse Code** — 1.4.2, Session Protocol MSP v1 over stdio | `B+N`: sessions list/resume by cursor/fork/delete. No evidence of attaching to an existing TUI; `sessionInUse`/lease behavior needs spike. | `N`: typed streaming, plans/todos/goals, subagents, workflows and event cursor. | `N`: server-minted approval choices and user-input forms; actual allow-all depends on host policy. | `N`: 5-hour/weekly quota, usage changes, context and tokens. | `B`: protocol does not provide file browser/search. Fork/retract is not filesystem rollback. Image input supported. | `N+B`: busy-turn controls/queue, skills, model/effort, user shell. User shell is not a guaranteed persistent PTY. |
| **Grok Build** — 1.0.46, ACP v1 plus `x.ai/*` extensions | `N+E`: ACP sessions; Grok extensions provide history replay, list/fork/rename/delete. Live cross-TUI sharing only when both clients use the same leader/server. | `N+X`: ACP stream/tool calls; extensions add plan, subagent and task details. | `N+X`: permission requests; questions and allow mode are extension/launch-option dependent. | `N+X`: tokens/cost and partial billing/quota data. | `X`: file list/search/read/write, Git and PTY extensions. Rewind changes conversation, not disk. Image input is present but capability advertisement needs verification. | `N+X+E`: native WebSocket server can persist state across reconnects; ACP and extension config/skills/steer/model features vary. WebSocket auth/TLS and extension version are gates. |
| **DeepSeek Harness (`dsh`)** — 0.2.0-rc.2, ACP v1 preview | `B+N`: stdio ACP list/resume/close. Resume does **not** replay prior events; no live attachment guarantee. | `N+P`: committed text/reasoning/tool updates. Internal UI has richer features, but its API is not public. | `N+P`: one-shot allow/reject; no ACP form/elicitation. Internal Web UI permissions are not a public client contract. | `P`: context/token usage; no cost/quota exposed by ACP. | `—/P`: no ACP file browse/write or undo. Images conditional on durable attachment store and route. No PDF guarantee. | `N+P`: cancel supported; no steer/queue, commands, skills, plans, terminal or fork/delete through inspected ACP surface. Model/effort config is available. |

### Consequences for session lifecycle and feature parity

- **Session lifecycle must be capability-specific.** OpenCode and Codex have native archive/delete and fork operations. Claude history operations are SDK/host scoped. Pi session listing is an SDK service, not an RPC call; do not delete its files directly without a verified supported SDK method. Muse exposes session lifecycle operations, but TUI concurrency needs verification. Grok’s management methods rely on its extensions. DSH supports close/resume but not transcript replay, fork or delete in its ACP surface.
- **Live attachment is not history resume.** OpenCode’s shared service and Codex’s shared daemon are the strongest live multi-client cases. Claude can list and resume stored history but cannot attach CodeWalk to the running TUI. Pi and Muse should initially be labelled “history/resume” unless the spikes prove otherwise. Grok live sharing requires both clients to attach to the same server/leader.
- **ACP v1 is not the universal feature set.** The stable ACP surface is stdio-oriented, without quota, undo, general file search, stable subagents or multi-client replay. ACP v2 was a draft in the inspected snapshot. Use ACP for suitable agents, not as a lossy wrapper around richer native protocols.
- **“Undo” is a contract label, not a generic button promise.** OpenCode’s staged revert and Git snapshot behavior, Claude’s limited write rewind, and Codex/Pi/Grok conversation forks are different actions. Offer each with explicit effect and scope; hide unsupported undo/redo.

## 4. Architecture and protocol boundaries

### Proposed repository layout

Retain the existing Flutter/Dart toolchain and place v2 behind a new application tree rather than extending the v1 chat god objects. Names below are proposed seams; inspect existing conventions before adding each file.

```text
lib/
  app_v2/
    app.dart
    routes.dart
    bootstrap.dart
  core/
    identity/{host_id.dart, project_id.dart, session_key.dart}
    result/{adapter_error.dart, operation_result.dart}
  domain/
    harness/
      harness_id.dart
      harness_descriptor.dart
      capability_snapshot.dart
      session_models.dart
      prompt_models.dart
      event_envelope.dart
      interactions.dart
      usage_models.dart
      task_models.dart
      file_models.dart
      adapter_interfaces.dart
  data/
    transports/{http_sse_transport.dart, host_gateway_transport.dart}
    adapters/
      opencode_v2/{adapter.dart, auth_pairing.dart, session_api.dart,
                   event_feed.dart, reducer.dart, wire_models.dart}
      codex/{adapter.dart, json_rpc_client.dart, wire_models.dart}
      claude/{adapter.dart, bridge_protocol.dart}
      pi/{adapter.dart, rpc_client.dart}
      muse/{adapter.dart, msp_client.dart}
      acp/{adapter.dart, stdio_bridge_client.dart}
      grok/{adapter.dart, ws_client.dart}
    repositories/{host_repository.dart, session_repository.dart,
                  local_state_repository.dart}
  presentation/
    features/
      hosts/
      sessions/
      chat/{chat_controller.dart, timeline_projection.dart, composer/}
      interactions/{approval_cards.dart, forms.dart}
      tasks/
      files/
      terminal/
      usage/
      settings/
host/
  codewalk-host/
    package.json
    src/{main.ts, pairing.ts, journal.ts, process_supervisor.ts}
    src/adapters/{codex.ts, claude.ts, pi.ts, muse.ts, acp.ts, grok.ts}
```

The app should keep the project’s established presentation/domain/data conventions; this proposal is not a mandate for a new package per harness. The host service is a separate executable boundary so Flutter Web and mobile do not need Node process access.

### Adapter interfaces and domain models

The adapter presents capabilities and native operations without pretending every protocol implements the same methods:

```dart
abstract interface class HarnessAdapter {
  HarnessDescriptor get descriptor;
  Future<RuntimeSnapshot> connect(HostContext host);
  Future<SessionPage> listSessions(ProjectScope scope, PageRequest page);
  Future<SessionSnapshot> openSession(SessionKey key, OpenIntent intent);
  Stream<AgentEvent> watch(SessionKey key, EventCursor? after);
  Future<SendReceipt> send(SessionKey key, PromptRequest request);
  Future<OperationResult<void>> interrupt(SessionKey key);
}

abstract interface class PermissionActions {
  Future<OperationResult<void>> reply(
    SessionKey session, PermissionRequestId id, PermissionDecision decision);
}

abstract interface class SessionLifecycleActions {
  Future<OperationResult<SessionKey>> fork(SessionKey session, ForkPoint point);
  Future<OperationResult<void>> archive(SessionKey session);
  Future<OperationResult<void>> delete(SessionKey session);
}
```

Forms, usage, file access, terminal, commands, skills, and task control should be optional capability interfaces. UI controls should use a runtime `CapabilitySnapshot` and still handle a native `UnsupportedCapability` result if the protocol version changes.

Use separate types for:

- **Identity:** `HostId`, `HarnessId`, `ProjectId`, and `SessionKey(host, harness, nativeId, project)`. Never key caches, tabs, interactions, or notifications by native session ID alone.
- **Events:** canonical typed events for message upsert/delta, tool lifecycle, turn state, permission/form request and result, plan/task update, usage, session change, and warning/error. Preserve unknown native events as `UnknownNativeEvent`.
- **Provenance:** each event carries source protocol/version, host, native event/message/request IDs, and sequence/cursor if available. Raw payload storage is size-limited and opt-in; never store credentials in event journals.
- **Usage:** distinct `TokenUsage`, `ContextUsage`, `CostEstimate`, and `QuotaWindow`. Do not infer quota from token totals or cost.
- **Errors:** preserve native codes and add typed categories such as authentication, incompatible version, unsupported capability, disconnect, provider retry, quota exhaustion, permission denied, session conflict, and ambiguous delivery.
- **State:** connection (`disconnected`, `connecting`, `ready`, `degraded`, `authRequired`, `incompatible`); session (`idle`, `running`, `waitingApproval`, `waitingForm`, `retrying`, `failed`, `interrupted`, `unknown`); child task and interaction states. `unknown` is not the same as idle.

### Ordering, reconnect and ambiguous sends

OpenCode v2’s global `/api/event` stream is live-only, has no replay, and can disconnect a slow consumer. Subscribe once per server origin, buffer events while fetching session snapshots, and merge by native IDs. On reconnect, use the supported message/inbox/permission/form snapshots; use the experimental session log only behind a version capability and bounded replay cursor. Do not refetch all messages per event or trust `session.status` merely because it is declared in a schema. Treat `session.execution.*` and active-session responses as the execution state.

For bridges, assign a monotonically increasing sequence per session and persist a bounded replay log. A proposed initial cap is 10,000 events or 20 MB per session, with 24-hour retention, subject to profiling. After bridge restart, reconstruct from each native history API; if it cannot replay, mark the timeline as incomplete rather than inventing missing events.

For prompt delivery, use states `draft → admitting → accepted → streaming → terminal`. If a send times out after admission might have occurred, enter **Delivery unknown**, reconcile with native session history, and require explicit user action if delivery cannot be resolved. Use native idempotency/command IDs only where documented. Remove v1’s optimistic content matching: identical prompt text can legitimately be sent twice.

For conflicting clients, use native conflict behavior and refresh pending interactions after reconnect. Do not auto-answer a permission twice. Codex broadcasts resolved approval state; Muse session ownership and Claude single-query ownership need version-pinned conflict tests. Disable mutation controls when the adapter cannot determine whether another client currently owns the session.

### Host service and transports

Use hybrid ownership:

1. **OpenCode v2:** connect directly to the official HTTP/SSE API. Desktop may manage the official binary and shared `opencode service`; mobile and Web connect to that user’s host. Use `/api/info` to identify compatibility; reject an HTML 200 or a v1 service.
2. **Codex:** host bridge attaches to the shared app-server daemon UDS and supports its WebSocket-over-UDS proxy. Do not spawn an independent `--listen ws://` server and claim it shares TUI sessions. That listener is separate and rejects browser Origin requests in the inspected version.
3. **Claude, Pi, Muse and ACP agents:** bridge owns the SDK/RPC/stdio child process, pipes protocol records, supervises exit, and multiplexes paired clients. Do not expose raw stdio to Flutter.
4. **Grok:** use its native server only when auth, TLS/VPN, and extension version are verified. Web can use the user’s host gateway; do not put bearer secrets in URLs.
5. **Network/auth:** bridge binds loopback by default. Remote access is explicitly user-configured through LAN, VPN/Tailscale, SSH, or TLS reverse proxy. Store pairing credentials in the OS secure store. Do not log tokens, pass OAuth credentials to clients, or build a CodeWalk-hosted relay.

Use argv-based process launches, strict working-directory checks, environment allowlists, process shutdown timeouts, and per-harness version checks. The bridge must not provide a generic shell or universal filesystem endpoint to a remote client.

### TypeScript host runtime

Choose **Node.js 22 LTS** as the proposed host runtime. It matches the official TypeScript SDK surfaces for Claude and Pi and the inspected Muse/ACP ecosystem. Bundle a pinned official runtime with the desktop host package rather than requiring a separate user install. Avoid Bun until the same package and native dependency matrix passes.

A bounded spike must check code signing, macOS app sandbox process permissions, Windows/Linux packaging, launch/upgrade rollback, memory/start time, child cleanup, and architecture support. If it fails materially, reopen D15 and compare Go plus an official SDK child process; do not silently replace the Claude SDK with an unofficial protocol.

## 5. UX and behavior

### Onboarding and host setup

1. Offer **Connect OpenCode v2** or **Set up a desktop host**. Android, iOS, and Web can connect but cannot install or own the selected desktop harnesses.
2. On desktop setup, install a chosen official OpenCode binary, verify its official SHA-256, record its exact version, and start/inspect `opencode service`. Do not auto-upgrade a running service to an untested version.
3. Pair through the version-supported OpenCode pairing flow. Validate `/api/info`, then show host identity, protocol version, auth state, and available locations/projects.
4. For non-OpenCode harnesses, show the official install source, installed version, host, auth owner, and whether sessions are CodeWalk-managed or discovered from external history.

The v2.0 compatibility check should follow the current official v2 API and reject v1 clearly. The local v2.0.21 source confirms Basic auth/pairing implementation details in `plan/opencode-v2-src`; because general docs do not specify every wire detail and versions are changing quickly, pin and test this behavior against the binary actually distributed. Never assume a Bearer example in a client doc is the server’s current auth scheme.

### Session list, create, resume and ownership

Group by **host → project/location → harness**, with filters and clear badges. Support external discovery and continuation according to the matrix:

- OpenCode shared service exposes sessions started in its own CLI/TUI clients.
- Codex shared daemon lists and live-attaches threads, including CLI/TUI threads; route all events by thread ID because new threads can be delivered to every initialized client.
- Claude lists local histories and can resume them through its host SDK; it cannot promise attachment to an active TUI session. Mark a conflicting/in-use session read-only until safe to resume.
- Pi uses SDK session discovery, not an RPC list command. Muse history is cursor-based and should not be labelled live-shared until its lease behavior is verified.
- Grok history and live sharing depend on the same native service/leader. DSH can list/resume but ACP does not replay prior updates.

Create, fork, archive and delete buttons should appear only if the adapter supports the exact action. When a harness lacks remote archive, offer local **Hide from CodeWalk** as a local-only action, not a fake archive. Confirm destructive remote delete separately from local hide. Tabs and drafts are scoped by full `SessionKey`.

### Chat lifecycle, streaming and interactions

- Render assistant text, reasoning, tool inputs/outputs, diffs, retry states and final content as separate typed timeline items. Treat final native item/message updates as authoritative over deltas.
- Render asynchronous child sessions as expandable child-task cards with their own status, transcript navigation, and supported cancel action. Do not count a child as a parent completion. Test OpenCode’s reported nested-background completion bug against the pinned upstream behavior.
- OpenCode questions are typed forms; Codex input requests are experimental; Claude and Muse have native question surfaces; Pi needs an extension; Grok uses extensions; DSH ACP has no forms. Display only protocol-provided fields and choices.
- Show tool approval with the native action/resource and exact duration/scope of the decision. OpenCode’s `always` may save project-wide. Codex approval modes and sandbox are separate. Claude’s permission mode must be explicit. A client-side Pi extension is not a sandbox.
- Stop/interrupt should use the harness action and distinguish stopping the current turn, cancelling an approval/form, cancelling a child task, and closing a session. Expose only operations that the adapter can verify.

For mid-turn input, expose **Steer** or **Queue** only when the protocol supports it. OpenCode prompt delivery has `steer` and `queue`; Codex steering is native and queue experimental; Claude and Pi have distinct steering/follow-up modes; Muse has busy-turn controls; Grok has extension-based interjection/queue; DSH accepts one prompt at a time. Show queued and accepted status returned by the native harness.

### Composer, files, attachments, terminal and undo

- **Slash commands and skills:** OpenCode has command/skill endpoints and experimental activation paths. Codex has skills but no server command registry. Claude has native commands/skills. Pi command discovery does not include all built-in TUI commands. Muse MSP skills are available but no general slash registry. Grok has extension commands/skills. DSH ACP omits commands/skills. Keep CodeWalk-local commands separate from native commands.
- **`@` mentions:** use file URI/resource references where supported; otherwise insert a host-relative path as text with a visible fallback. Do not promise workspace symbols everywhere. Codex can fuzzy-search; OpenCode’s file find is not full content/symbol search.
- **Files:** represent workspace files as remote-host resources, not phone-local files. Keep safe read/list/find as adapter capabilities. OpenCode’s experimental write route is not a stable, root-confined file API. Default its editor to read-only unless a version-pinned spike proves safe path and symlink containment; document any enablement behind an ADR-023 exception. Do not revive hidden shell sessions as a universal write mechanism.
- **Terminal:** open only when the harness can provide a real remote terminal. OpenCode has native PTY and tickets; Codex command terminals are connection-bound; Claude requires bridge ownership; Pi `bash` and Muse `userShell` are not persistent PTYs; DSH ACP has none.
- **Attachments:** show supported MIME/size per adapter. OpenCode accepts raster images (PNG/JPEG/GIF/WebP) but not PDF as a PDF; Codex rejects HTTP image URLs; other harness image support varies. PDFs should be disabled with an explanation in v2.0 unless a bounded, tested host-side text extraction or page-conversion path is added. Never silently send an unsupported PDF as a different format.
- **Undo/redo:** replace the generic v1 assumption with scoped actions. OpenCode uses staged revert/commit/clear and Git snapshots. Claude rewind only covers selected file-write tools. Codex/Pi/Grok history forks or conversation rewind do not restore files. Muse session editing/retract is not general filesystem undo. Do not show redo where the protocol has no redo.

### Usage, errors and notifications

Show independent cards for context pressure, token/cost totals, and provider quota windows, with origin and freshness. OpenCode can show tokens/cost/context but not a general remaining quota. Do not poll vendor quotas unless the user opts into a documented host query. Preserve provider error/retry information and avoid automatic retries when prompt delivery is ambiguous.

Use foreground streams as the normal update path. On reconnect, repair from supported snapshots and mark gaps. For local notifications, use desktop notifications and Android system notifications with opt-in attention settings. A proposed Android status check should run no faster than WorkManager’s 15-minute periodic floor, only while the user has active tracked sessions; each wake should fetch one active-session snapshot and stop after no activity, with exponential backoff on errors. This is delayed best-effort status, not real-time push. Do not promise killed-app delivery on iOS or Web without a separately configured user-owned push endpoint.

### Existing app-local features

**Keep and adapt:** Material You/theme system, responsive layout, localization, drafts, tabs, exports, accessibility/keyboard navigation, voice input/output where platform-supported, markdown/code rendering, bookmarks/favorites, session attention surfaces, and local notification preferences. Preserve localized UI while leaving model IDs, commands, file paths, and agent-provided content untouched. Attention snapshots remain encrypted and scoped to the complete host/project/root-session identity.

## 6. Rewrite, reuse, discard and migration

| Decision | Existing areas | v2 treatment |
|---|---|---|
| **Rewrite** | `lib/presentation/providers/chat_provider.dart` and parts; `lib/presentation/pages/chat_page.dart` and parts; `lib/data/datasources/chat_remote_datasource.dart`; v1 DTOs/reducers; onboarding and session identity | Replace with session controller, typed v2/native adapters, and timeline reducer. Move wire handling out of widgets and route all network calls through repositories/adapters. |
| **Replace transport/runtime** | `lib/presentation/services/local_opencode_server_runtime*`, v1 dual-SSE/event handling, hidden title/quota/file shell sessions | Direct OpenCode v2 API and one live SSE stream; separate Node host service for harness process/socket adapters. Remove v1 route aliases, polling heuristics, content-match reconciliation and global fake PATCH behavior. |
| **Reuse selectively** | `lib/presentation/services/session_export_service.dart`, `workspace_file_operations_service.dart`, `terminal_remote_datasource.dart`, theme/rendering widgets, input controllers, localization and attention/notification services | Reuse UI primitives after decoupling protocol assumptions. Keep file/terminal code only behind explicit adapter capability and safety checks. Preserve exports and accessibility behavior. |
| **Discard or defer** | v1-only message/part/question/permission shapes; v1 route fallback; unsupported share/todo/LSP paths; hidden global-session workarounds | Do not carry OpenCode v1 support into v2. Hide unsupported share, LSP, todo, file write and quota controls rather than fabricating replacements. Keep v1 in its maintenance branch. |

Coordinate local data and release identity:

- Inspect actual v1 persistence before coding. Create a versioned v2 namespace and transactionally migrate only safe client preferences (theme, locale, accessibility, selected host/profile metadata where credentials can be securely re-bound). Do not migrate server transcript data as if CodeWalk owns it.
- Back up/export v1-local preferences and drafts before upgrade. Key new drafts/tabs by full host/project/harness/session identity; old IDs may be ambiguous and should not be auto-mapped when host identity is unclear.
- Keep `com.verseles.codewalk` and the signer for the in-place update. Maintain monotonically increasing Android build codes across `main` and v1 maintenance releases; the current build code is already timestamp-sized. Coordinate updater feeds on desktop too.
- Keep the legacy v1 download available, but document that installing it over v2 may require uninstall/downgrade steps and may not preserve v2-local data. Do not promise side-by-side installation with the same application ID.
- Refresh `BEHAVIOR.md` only after behavior exists. Update `ADR.md` for v2 contract, host ownership and exact permission/undo semantics; revise ADR-023/EXC-001 and create an explicit ADR exception for any intentional OpenCode contract divergence. Update `CONTRACT_MATRIX.md`, v2 OpenCode anchors in `ai-docs/opencode_server.md`, `opencode_web.md`, and `opencode_models.md`, plus `CODEBASE.md` and `README.md` after structure/setup changes. Keep v1-specific anchors on the v1 maintenance branch.

Current v1 behavior references include [BEHAVIOR.md sessions/composer](</home/ubuntu/MEGA/WORK/codewalk/BEHAVIOR.md#L362>), [interactive prompts](</home/ubuntu/MEGA/WORK/codewalk/BEHAVIOR.md#L1815>), [task list](</home/ubuntu/MEGA/WORK/codewalk/BEHAVIOR.md#L1895>), [attention](</home/ubuntu/MEGA/WORK/codewalk/BEHAVIOR.md#L2396>), [notifications](</home/ubuntu/MEGA/WORK/codewalk/BEHAVIOR.md#L2444>), [lifecycle](</home/ubuntu/MEGA/WORK/codewalk/BEHAVIOR.md#L2532>), and [message reconciliation/subagents](</home/ubuntu/MEGA/WORK/codewalk/BEHAVIOR.md#L2887>). ADR-023 is at `ADR.md:1103–1255`; quota, PTY, auth and filesystem decisions include ADR-027, ADR-029, ADR-033, and ADR-043 (`ADR.md:1385+`, `1593+`, `1889+`, `2587+`).

## 7. Ordered implementation stages and release phases

The proposed minimum release supports all six client targets for the OpenCode v2 remote-client core, and includes D13’s OpenCode/Codex/Claude session discovery and continuation behavior. It does **not** claim every local tool works on every platform, or that all harnesses have feature parity.

1. **Stage 0 — bounded feasibility spikes and decisions.** Verify OpenCode v2 auth/pairing, Web CORS/origin, `/api/info` version rejection, Codex daemon UDS/proxy/live TUI sharing, Claude history resume/conflict behavior, Node 22 packaging, and iOS plugin/signing viability. Resolve D05 before any production allow-all default.
2. **Stage 1 — v2 skeleton and identity.** Add new navigation, host/project/session identity, versioned local storage, secure credential storage, capability model, adapter contract fixtures, localization and platform shell. Acceptance: Android, Linux, macOS, Windows, Web, and iOS can build or have a documented runner/signing prerequisite; all store keys include host identity.
3. **Stage 2 — OpenCode v2 vertical slice.** Connect, pair, validate `/api/info`, list/create/resume sessions, send prompt, render message/tool events, stop, handle errors, reconnect and reconcile. Acceptance: no v1 fallback; no duplicate prompt on ambiguous delivery; live session from TUI appears; malformed/unknown events do not crash.
4. **Stage 3 — full OpenCode client core and D13.** Add forms/permissions, async children, command/skill/model selection, usage, file read/search, PTY, migration/exports and supported notification behavior. Add Codex live external sessions and Claude history/resume preview with exact labels. Acceptance: all D13 entry cases work or are explicitly blocked behind a documented D13 change.
5. **Stage 4 — harden core and Pi/ACP.** Stabilize Codex/Claude schemas and policies, then add Pi’s official RPC and a narrow stable ACP v1 adapter. Ship Pi only with an explicit YOLO/extension permission disclosure. No ACP v2 draft dependency.
6. **Stage 5 — Grok and Muse; DSH reassessment.** Integrate Grok native WebSocket/ACP extensions and Muse MSP only after capability/auth/replay tests. Reassess DSH after it has a stable release and history-load or equivalent replay capability. Keep later harnesses optional until their release gates pass.

**Proposed release labels, not accepted decisions:** v2.0 = OpenCode v2 GA across the six remote-client targets plus opt-in Codex/Claude preview sufficient for D13; v2.1 = harden those two and add Pi/stable ACP; v2.2 or later = Grok and Muse if their protocol gates pass; DSH deferred. If a D13-critical harness cannot list and continue safely, the release must remain incomplete or the user must explicitly revise D13.

## 8. Validation plan

Validation is for implementation time; none of these commands or tests were run for this planning deliverable.

### Adapter and reducer tests

Create version-pinned fixtures from each official raw protocol. Test handshake/version negotiation, malformed JSON/UTF-8, unknown enum/event values, duplicate IDs, out-of-order deltas, final-message authority, cursor gaps, heartbeat/stream close, reconnect backoff, server snapshot races, and bounded replay. Include identical prompt text sent twice and a timeout after native admission to ensure no blind resend.

Exercise permission/form races: user responds while another client resolves the request; reject/cancel during a reconnect; project-wide “always” scope; Codex sandbox vs approval; Claude explicit mode; Pi extension missing; Muse session in use; DSH unsupported elicitation. Verify no interaction is falsely shown as resolved.

Add session fixtures for OpenCode TUI-created sessions, Codex shared-daemon TUI threads and approval replay, Claude active/inactive JSONL histories, Pi session discovery through its SDK, Muse cursor resume, Grok leader/reconnect and DSH resume without historical replay. Include nested OpenCode background tasks and the known early-parent-completion report.

### Platform and product checks

Test file path traversal/symlinks and external directory scope; OpenCode experimental write disabled by default; remote path vs device-local attachment distinction; PTY ticket expiration; attachment size/MIME/PDF unsupported state; secure token redaction; multi-host/session-ID collisions; app upgrade/rollback and v1 preference backup.

Measure responsiveness on long timelines and coalesced event streams, accessibility semantics and keyboard navigation on all UI targets, i18n generation across the current locales, and battery behavior with no active sessions versus active Android background tracking. Web tests must cover OpenCode CORS/pairing, cookies/auth, and rejection of Codex direct WebSocket Origin.

### Project commands and release gates

Use the narrowest focused Flutter/widget/adapter tests during implementation. At a stable validation gate, run:

```bash
export PATH="$HOME/flutter/bin:$PATH" && make check
export PATH="$HOME/flutter/bin:$PATH" && make test-web
```

`make test-web` requires Chrome. Build each platform on its supported runner: `make web`; host-appropriate `make desktop`; Android on a suitable x64 runner or GitHub Actions if the available Linux host is ARM64; and an iOS build on macOS with Xcode, followed by a signed device/TestFlight gate before claiming distribution support. The current Makefile’s `make check` includes dependencies, generation, analysis and tests; use `make precommit` only if a separate project policy later requires it, not as the normal CodeWalk validation command.

No final code commit or release should occur until the full check and required reviewer loop pass. This planning work does not invoke a code review.

## 9. Risks, assumptions and execution start

| Risk or unverified assumption | Mitigation | If false |
|---|---|---|
| OpenCode API/auth/event details may drift between the source pin and installed binary. | Pin the tested release; inspect `/api/info`; run contract fixtures against that binary; compare only official source/docs. | Disable the changed capability and mark the server version incompatible until adapted. |
| OpenCode session permission-rule precedence and child inheritance are not fully settled by the dossier summary. | Test config → agent → session → child behavior for allow, deny, ask and always; do not make an allow-all claim before it passes. | Keep approval behavior native/server-defined; do not inject a CodeWalk override. |
| Codex daemon protocol can be newer than the CLI and changes weekly; it is labelled experimental. | Negotiate the daemon, not CLI version; pin compatibility ranges; attach to shared UDS and test TUI concurrency. | Keep Codex preview-only; do not fall back to the separate WS listener while claiming shared TUI state. |
| Claude history resume may conflict with a running CLI/TUI; SDK policy/auth restrictions can change. | Test inactive and active histories; use only supported official SDK/CLI auth; never copy OAuth tokens. | List history read-only or require inactive session; revisit D13 if continuation cannot be supported. |
| Node packaging or macOS sandbox may prevent safe host launch. | Test signed runtime and process lifecycle on all desktops before adapters. | Reopen D15 and choose Go plus an official SDK child process or a new explicit host prerequisite. |
| iOS, Web, Windows ARM64 and Android background differ from desktop. | Platform capability matrix and dedicated build/device gates. | Keep the target listed but mark unsupported subfeatures; do not claim host installation or guaranteed push. |
| ACP v2, Muse schema and Grok extensions can change. | Use stable ACP v1; pin MSP/extension versions; preserve unknown event provenance. | Defer that harness rather than create a private compatibility facade. |

**Immediate execution start:** first resolve D05 for the production default, then run Stage 0 spikes against the exact OpenCode/Codex/Claude versions selected for v2.0. After those results, establish the v2 skeleton and contract fixtures before moving UI features.

### Evidence references

Local evidence packs: [v1 inventory](</home/ubuntu/MEGA/WORK/codewalk/plan/00-codewalk-v1-inventory.md>), [v1 OpenCode contract](</home/ubuntu/MEGA/WORK/codewalk/plan/01-codewalk-v1-opencode-contract.md>), [OpenCode v2 overview](</home/ubuntu/MEGA/WORK/codewalk/plan/10-opencode-v2-overview.md>), [API dossier](</home/ubuntu/MEGA/WORK/codewalk/plan/11-opencode-v2-server-api.md>), [event/schema dossier](</home/ubuntu/MEGA/WORK/codewalk/plan/12-opencode-v2-events-and-schemas.md>), [v1/v2 diff](</home/ubuntu/MEGA/WORK/codewalk/plan/13-opencode-v2-vs-v1-diff.md>), [Codex](</home/ubuntu/MEGA/WORK/codewalk/plan/20-codex.md>), [Claude Code](</home/ubuntu/MEGA/WORK/codewalk/plan/21-claude-code.md>), [Pi](</home/ubuntu/MEGA/WORK/codewalk/plan/22-pi.md>), [Muse](</home/ubuntu/MEGA/WORK/codewalk/plan/23-muse-code.md>), [Grok Build](</home/ubuntu/MEGA/WORK/codewalk/plan/24-grok-build.md>), [DSH](</home/ubuntu/MEGA/WORK/codewalk/plan/25-deepseek-dsh.md>), [ACP](</home/ubuntu/MEGA/WORK/codewalk/plan/30-acp-and-unifying-protocols.md>) and [multi-client patterns](</home/ubuntu/MEGA/WORK/codewalk/plan/31-multi-harness-clients.md>). OpenChamber is only a secondary OpenCode reference, pinned in `plan/31` §2 to `fc012ae0029fa2ac8d1d52b4af37040fc536258e`.

Primary source anchors include [OpenCode v2 docs](https://opencode.ai/v2/docs/), [OpenCode pinned source](https://github.com/anomalyco/opencode/tree/8a8bd622), [Codex source `rust-v0.160.0`](https://github.com/openai/codex/tree/rust-v0.160.0), [Pi](https://github.com/earendil-works/pi), [Muse SDK/MSP](https://meta-models.github.io/muse-code-sdk/), [Grok Build](https://github.com/xai-org/grok-build), [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness), and the [ACP protocol](https://github.com/agentclientprotocol/agent-client-protocol). These reflect the 2026-10-02 evidence snapshot and must be rechecked before implementation.