# CodeWalk v2 implementation plan

## 1. Status, objective, and architectural recommendation

**Status:** planning complete against the supplied research snapshot and selectively inspected source. No implementation, installation, tests, commits, or external mutations were performed.

**Objective:** replace CodeWalk v1 with a maintainable, mobile-first client for OpenCode v2 and selected additional coding harnesses. Preserve valuable app-local behavior while replacing the v1 transport, message reconciliation, lifecycle, permission, installation, and background-monitoring architecture.

The principal recommendation is:

> **Use one user-owned CodeWalk Host as the client-facing network endpoint. Inside it, integrate rich harnesses through their official native surfaces and attach to their existing shared services wherever available. Use ACP for suitable additional harnesses, not as a compulsory translation layer for every harness.**

This is a universal **gateway**, not a replacement for the OpenCode or Codex daemon. OpenCode continues to own OpenCode execution and durable sessions. Codex continues to own Codex execution and shared threads. CodeWalk Host owns its network connection, app-specific metadata, replay buffer, command receipts, and subprocesses for harnesses without a public shared service.

Flutter receives a CodeWalk domain protocol. It does not parse seven upstream protocols or make another harness imitate OpenCode.

### 1.1 Why this direction

The decisive constraints are different for each harness:

- OpenCode v2 already has a shared authenticated HTTP/SSE service.
- Codex has a shared local daemon, but its separate TCP listener is not that daemon and rejects browser `Origin` headers.
- Claude Code requires a host-side SDK process for a rich third-party GUI.
- Pi and Muse primarily expose local stdio interfaces.
- Grok has its own network surface, with vendor extensions and transport limitations.
- `dsh` exposes a deliberately limited automation protocol.

These differences make a network-only Flutter abstraction insufficient. A host component is already necessary for essential parts of the requested product. Putting normalization there avoids replicating session ownership, permissions, replay, and protocol adapters across six client targets. [C-DAEMON, CC-SDK, PI, MSP, GROK, DSH]

### 1.2 Intended final behavior

A user installs or connects to CodeWalk Host on the machine containing their projects. Android, iOS, Web, and desktop clients pair with that host over the user’s LAN, VPN, TLS proxy, or SSH tunnel.

The client provides:

- A unified host/project session list with harness badges.
- Native discovery and continuation of externally created sessions where supported.
- Accurate streaming text, reasoning, tools, questions, permissions, usage, and background work.
- Persistent drafts, tabs, preferences, attention state, exports, and accessible navigation.
- Explicit capability differences rather than controls that fail after being pressed.
- Recovery from phone disconnection without pretending that upstream execution stopped.
- Official harness authentication on the host; provider credentials do not travel to the phone.

The first production release should concentrate on **OpenCode v2 and shared-daemon Codex**. Claude and Pi follow through separate, gated vertical slices. Muse and Grok follow once their ownership and extension contracts pass their respective qualification gates. `dsh` remains an experimental candidate.

All six selected client platforms remain in scope. Platform readiness is a release gate, not an assumption.

### 1.3 Consequential alternatives

| Architecture | Benefits | Costs and limitations | Assessment |
|---|---|---|---|
| Direct official servers only | Lowest installation burden for OpenCode; few app-owned host components | Cannot provide the requested Claude/Pi/Muse integration alone; does not solve browser access to shared Codex or common host facilities | Insufficient for the requested product |
| Hybrid direct OpenCode plus CodeWalk bridge for others | Existing OpenCode users can connect immediately; bridge remains optional for simple usage | Two authentication/reconnect paths; duplicate normalization or two client protocols; different notification/file capabilities by connection mode | Viable alternative if optional host installation is a stronger product priority |
| Universal CodeWalk Host gateway | One client protocol, common replay/receipts, consistent browser access, host-owned approvals and subprocess lifetime | Every installation needs an additional component, including OpenCode-only users; runtime and packaging obligations | **Recommended** for maintainability and the complete selected scope |

A direct OpenCode mode should be added later only if usage demonstrates that avoiding the host is worth maintaining the second path. It should not be included reflexively in the rewrite.

### 1.4 Evidence corrections that affect implementation

Three supplied summary statements need qualification:

1. **OpenCode has no stable file-write endpoint, but the inspected v2.0.21 protocol does declare an experimental one:** `POST /api/experimental/fs/write`. It accepts raw bytes and explicitly allows targets outside the location. This is verified in `plan/opencode-v2-src/protocol-groups/fs.ts:75–89`. Runtime behavior still needs qualification before enabling it.
2. **Dart ACP packages exist.** `plan/30-acp-and-unifying-protocols.md:80–94` records `dart_acp_sdk`, `acp_dart`, and alternatives. The “none found” statements in other dossiers are incomplete searches, not proof of absence. The proposed architecture does not need a Dart ACP dependency.
3. **`dsh` can list and resume persisted sessions, but cannot replay their transcript through ACP.** Its raw README makes that distinction explicit at lines 60–76. Resume is not complete historical GUI continuity.

### 1.5 Exact blockers and limits

There is no blocker to producing this plan. There are implementation or product-claim blockers:

- **Arbitrary live Claude TUI takeover:** no inspected public third-party API supports attaching to and controlling every running ordinary TUI process. Inactive-history resume is feasible; universal live takeover is not established.
- **Native iOS closed-app notification delivery without sender infrastructure:** the ordinary native build requires an appropriately authorized APNs sender. A persistent VPN socket is not a substitute.
- **Managed macOS setup in the current sandboxed distribution:** `macos/Runner/Release.entitlements` enables App Sandbox. Installing and supervising external harnesses must be proven in the intended distribution or moved to a separately installed host component.
- **`dsh` full history continuity:** unsupported by the chosen official ACP surface.
- **Muse redistribution:** official installation is described, but permission to bundle or redistribute the proprietary CLI has not been established.

These limits must appear in capability and support documentation.

---

## 2. Decision Assessment: D01–D16

The selected answers remain the baseline. Recommendations to change them are advisory and require discussion before the final direction changes.

| Decision | Verdict | Evidence and argument | Recommendation or concrete alternative | Confidence and verification |
|---|---|---|---|---|
| **D01 — connection architecture** | **Keep open; recommend universal gateway** | Stdio harnesses require host ownership; shared Codex is local-socket based; Web cannot use its ordinary TCP listener directly. A common gateway reduces client-side protocol duplication. [C-DAEMON, CC-SDK, PI, MSP] | CodeWalk Host exposes its own versioned protocol and attaches to official services. Alternative: direct OpenCode plus bridge, trading installation convenience for two connectivity stacks. | **High** on need for a host; **medium** on universal versus hybrid product fit. Validate a six-platform pairing/reconnect slice before committing to packaging. |
| **D02 — release phases** | **Keep open; recommend qualification phases** | The native protocols differ in stability, ownership, and completeness. Seven simultaneous adapters would delay learning about the core client/host design. | First production scope: OpenCode v2 + shared Codex. Then Claude + Pi; then Muse + Grok. `dsh` remains experimental until history requirements are resolved. | **Medium.** Revise estimates after the first two adapters and platform packaging spikes. |
| **D03 — new skeleton, same repository** | **Keep** | Current wire semantics permeate `ChatProvider`, `ChatPage`, and presentation services. Patching these around seven adapters would retain the main complexity. [V1] | Build a new skeleton, selectively port widgets/services, and preserve v1 in an immutable reference and future maintenance branch before removing its implementation. | **High.** Confirm a bounded reuse inventory and dependency graph before moving code. |
| **D04 — same application ID** | **Keep, with explicit migration obligations** | This preserves updater continuity and existing local settings. It also means v2 replaces v1, and production Android downgrade is constrained by signing and version codes. | Retain `com.verseles.codewalk`. Provide recoverable local-data migration and clear manual legacy-download instructions. Alternative: separate v2 ID, which enables coexistence but splits updates and storage. | **High** on feasibility; **medium** on rollback convenience. Test signed v1→v2 upgrades and an actual legacy-return procedure on Android. |
| **D05 — allow-all ON, native where supported** | **Change recommended; preserve baseline until accepted** | A native OpenCode wildcard overrides explicit agent denies; Codex `never` does not equal sandbox bypass; Pi lacks a permission system. A single toggle can conceal materially different effects. [O-PERM, C-PROTOCOL, PI] | Prefer “automatically answer eligible approval requests” while preserving native deny rules and sandbox settings. Keep unrestricted execution a separate explicit control. Baseline plan below still permits native modes, but displays their exact effect and never changes sandbox implicitly. | **High** on semantic differences. Qualify every mapping, especially OpenCode deny inheritance and Claude mandatory interaction. |
| **D06 — native usage + experimental vendor queries** | **Keep** | Codex, Claude, and Muse have useful native signals. OpenCode exposes tokens/cost but no unified remaining quota. [O-EVENT, C-PROTOCOL, CC-SDK, MSP] | Use native data first. Experimental host query plugins require explicit opt-in, provenance, bounded refresh, and policy-compatible authentication. Remove credential-refresh/writeback probes. | **High** for native-first; **medium** for individual vendor plugins. Qualify each endpoint and credential mechanism independently. |
| **D07 — notifications/background** | **Keep open; recommend host attention + Web Push** | The host can detect authoritative attention independently of clients. Android foreground-service limits and iOS suspension prevent a universal always-connected mobile model. | First: host attention inbox, desktop/local notifications, one bounded Android monitor, and host-originated Web Push. Native iOS push remains gated on sender architecture. | **High** on platform limits; **medium** on delivery packaging. Test actual background and force-quit behavior. |
| **D08 — user-managed networking, no hosted relay** | **Keep** | Matches local service ownership and avoids adding a shared data intermediary. It is compatible with the official local-service surfaces. | LAN/VPN/tunnel/TLS-proxy recipes. Host binds loopback by default; remote listening is explicit. Optional user-selected notifier integration is separate from session transport. | **High.** Test IPv4/IPv6, reverse-proxy paths, VPN reconnects, and TLS trust across all targets. |
| **D09 — six platforms** | **Keep** | Flutter remains appropriate; existing IO conditionals are reusable. iOS has no current platform directory and several native facilities lack parity. [V1] | Define a shared chat baseline, then per-platform facilities and build/signing gates. Do not promise managed harness installation on mobile/Web. | **High** on scope; **medium** on schedule. Build an iOS skeleton and Web protocol slice early. |
| **D10 — official OpenCode binary, SHA-256, shared service** | **Keep** | Official artifacts, service commands, authentication, and pairing are verified. GitHub “latest release” currently points to v1 and is unsuitable for v2 installation. [O-API] | Download pinned official artifacts using official update metadata; require a checksum; use `opencode service`, explicit location, and local pairing. | **High.** Verify target metadata, including Windows ARM64 discrepancies, and service startup from an app-managed binary path. |
| **D11 — desktop manages host and harness installation** | **Keep, constrained by ownership** | Desktop can install official channels; some packaging, sandbox, and updater interactions remain unverified. [V1, C-DAEMON, CC-SDK] | Desktop manages CodeWalk-owned installations, discovers user-owned installations, and does not silently replace them. Android/iOS/Web connect and show host-side setup progress. | **Medium.** Qualify macOS distribution and Windows service startup before promising one-click setup. |
| **D12 — English final plan** | **Keep** | Product/documentation preference, independent of feasibility. | English plan and technical contracts. Preserve the existing app’s 14-language UI scope. | **High.** Verify final document language and localization migration separately. |
| **D13 — external sessions are essential** | **Keep, with precise supported semantics** | OpenCode and shared Codex support shared sessions. Claude supports history discovery/resume; arbitrary live attachment is not established. Pi/Muse/Grok have their own ownership limits. | Separate discovery, historical read, inactive resume, live observation, live control, and concurrent control in the capability model. Never advertise them as one “resume” feature. | **High** for OpenCode/Codex; **medium or low** for live sharing elsewhere. Run a TUI/client ownership qualification per harness. |
| **D14 — unified list with accurate capabilities** | **Keep** | The UI can be coherent without equalizing backend semantics. Local identity must include host, harness instance, and native ID. | Unified list by host/project with provenance badges, operation-specific capability availability, and truthful disabled reasons. | **High.** Test identity collisions, aliases, external sessions, and mixed capability sessions. |
| **D15 — daemon language/runtime** | **Keep open; recommend TypeScript/Node** | Claude’s complete official SDK is TypeScript; Muse and Pi offer TS support; ACP has an official TS SDK. Other languages would reimplement SDK behavior or add worker runtimes. | TypeScript on one certified Node LTS runtime, at least satisfying Pi’s Node ≥22.19 requirement. Bundle or install an exact verified runtime. Bun is a later qualified alternative. | **High** on ecosystem fit; **medium** on packaging. Qualify native PTY and persistence modules on Linux ARM64, macOS, and Windows. |
| **D16 — planning process** | **Process-only** | Concurrency, independent investigation, budget, and recoverable retention do not determine the product architecture. A requested budget does not remove a transport deadline. | Preserve the prescribed scheduling and deliverable-retention contract; report deadline failures accurately. | **High.** Verify runner timeouts and that each returned deliverable is retained before continuation. |

### 2.1 Changes recommended for reconsideration

1. **D05:** separate automatic approval from unrestricted permissions and sandbox bypass. The concrete effect is that turning on the usual approval toggle would not erase explicit native deny rules or expand filesystem/network access.
2. **D13:** qualify “continue external sessions” by ownership state. Ordinary live Claude sessions should initially be read-only or require the user to stop them before SDK resume.
3. **D04:** accept that manual legacy download is not equivalent to easy in-place Android downgrade. A tested rescue artifact or export/import procedure is needed.
4. **D07/D08:** if native iOS closed-app notifications are mandatory, select a narrowly scoped authorized push sender or user-operated distribution. This is an additional infrastructure decision, not something a VPN solves.
5. **D11:** distinguish the desktop client from the installable host companion on macOS. A signed native app may connect to a separately installed host even when it cannot perform the installation itself.

The rest of this plan follows the existing product selections and makes these differences visible.

---

## 3. Harness capability and integration matrix

### 3.1 Versions and preferred surfaces

These are research pins, not a promise to accept every later version automatically.

| Harness | Integration baseline | Preferred official surface | Host relationship | Qualification status |
|---|---|---|---|---|
| **OpenCode** | v2.0.21, commit `8a8bd622…`; v2.0.22 source differences at `05018b88…` | Native `/api/*`, global SSE, generated client/schema | Attach to shared per-user `opencode service` | Source inspected; live contract qualification required |
| **OpenAI Codex** | CLI-generated types 0.159.3; shared daemon/source 0.160.0 | App-server protocol v2 over shared daemon UDS | Attach; do not substitute a separate TCP process | Source/types inspected; regenerate fixtures against actual daemon version |
| **Claude Code** | Agent SDK 0.3.287; CLI 2.1.287 | Official TS SDK, streaming input/output | Host owns SDK query/subprocess | Type contract inspected; live ordering and ownership qualification required |
| **Pi** | 1.0.0 | Official RPC JSONL and selected SDK session-discovery helpers | Host owns one RPC subprocess per active session | Documented RPC; no general shared-daemon guarantee |
| **Muse Code** | 1.4.2, MSP schema v1 | `muse serve` / official TS SDK | Host owns MSP process and loaded session leases | Published schema; supplied golden transcripts are hand-authored, not live captures |
| **Grok Build** | CLI 1.0.46; registry pin differs at 1.0.47 | ACP v1 plus qualified `x.ai/*`; native WS or stdio | Prefer host-owned connector to existing native server | Native extension claims source-backed; extension availability needs live negotiation |
| **DeepSeek Harness** | 0.2.0-rc.2 | Official ACP stdio profile | Host owns ACP process | Preview; incomplete history surface blocks ordinary full-client qualification |

Muse’s inspected stable manifest reports schema version `1` and fingerprint:

```text
sha256:61afea3112e0906e9dc3a536144278a74cb4b36fc6e20901a91d4432ba3568e2
```

Compare this with the installed SDK/CLI handshake; do not assume it is unchanged.

### 3.2 Legend

- **N:** native official surface.
- **B:** CodeWalk Host supplies an app-owned facility.
- **X:** official vendor extension.
- **C:** community extension/adapter; separate optional dependency.
- **E:** experimental, preview, or version-gated.
- **—:** unavailable in the selected surface.
- **?:** not established by inspected evidence.

All stdio and local-socket integrations still require the host network boundary.

### 3.3 Sessions and execution

| Capability | OpenCode | Codex | Claude | Pi | Muse | Grok | `dsh` |
|---|---|---|---|---|---|---|---|
| List external sessions | N, shared service | N, explicit source filters | N, SDK history functions | B using official session helpers | N, session list | N/X, session list/history | N, resumable roots |
| Read existing transcript | N, cursor pages | N, thread/turn/item pages | N, SDK history | N, messages/entries/tree | N, view pages | N/X, load history | **— for resumed history** |
| Create/resume | N | N | N | N | N | N | N |
| Live shared attachment | N, same service | N, same daemon | — for arbitrary TUI; N for host-owned query | ?; no standard shared RPC owner | Lease-dependent; qualify `sessionInUse` | X/leader; qualify restrictions | —; resume requires inactive ownership |
| Fork | N, new root with fork lineage | N, boundary fork | N, SDK fork | N, fork/clone | N, cut point | X | — |
| Rename/delete | N/N, delete descendants | N/N, native cascade | N/N, policy/ownership checks | N/—; local hide instead | N/N | X/X | —/— |
| Archive | B local metadata | N | B local metadata | B local metadata | B unless native support established | B unless qualified extension | B local metadata |
| Steer/queue | N/N | N/E queue | N native queue timing; exact priorities partly unverified | N/N | N/N, unqueue | X/X | —; one prompt at a time |
| Interrupt/stop | N, execution interrupt | N, turn interrupt | N, query interrupt; task stop separately | N, abort/retry/bash controls | N, turn/task controls | N/X | N cancel |
| Stop background work | Child interrupt; session-wide background transition | Native child controls vary; capability-gate | N task stop, per-task affordance | C only for subagents | N task/subagent/workflow controls | X | Internal work not structurally exposed |

### 3.4 Timeline, interaction, and usage

| Capability | OpenCode | Codex | Claude | Pi | Muse | Grok | `dsh` |
|---|---|---|---|---|---|---|---|
| Streaming text/reasoning | N, started/delta/ended | N, item deltas/finals | N, partial messages | N, message events | N, item deltas | N ACP updates | Committed chunks, not token deltas |
| Tool input/output/errors | N, structured lifecycle | N, item lifecycle/output | N, tool blocks/results/progress | N, execution events | N, output references | N/X | N, generic lifecycle |
| Permission requests | N ordered rules/replies | N JSON-RPC server requests | N callbacks, modes/rules | — natively | N minted choices/stages | N ACP options | N once/reject |
| Questions/forms | N typed forms | N/E user-input requests; MCP forms | N AskUserQuestion/dialogs/elicitation | Extension UI only | N user-input requests | X `ask_user_question` | — |
| Tasks/plans/goals | No native todo list | N plan updates/goals; E plan mode | N model-dependent task tools | C extension | N todo/goals/workflows | N/X plan | — in ACP |
| Subagent transcript/linkage | N child sessions | N child threads | N task IDs/subagent messages | C only | N subagent items/control | X | — in ACP |
| Token/cost/context usage | N; not unified quota | N tokens/context; cost availability differs | N, cost estimates/context | N stats | N, including partial cost | N/X, partial flags | Context usage; other fields limited |
| Remaining quota/rate windows | Go/Zen errors; no unified quota API | N account limits/credits | N rate events; E usage read | — | N usage windows | X billing/usage, shape partly uncertain | — |
| Error/retry signal | N typed error + scheduled retry | N `willRetry` + terminal error | N result/error/rate events | N auto-retry/errors | N retry/terminal errors | N/X notifications | Native errors; limited retry detail |

### 3.5 Workspace, composer, and selection

| Capability | OpenCode | Codex | Claude | Pi | Muse | Grok | `dsh` |
|---|---|---|---|---|---|---|---|
| Browse/read/find files | N; content search requires B | N filesystem/fuzzy search | N read; B tree/search | B | B | X | B |
| Write files | E native write, or B host files | N filesystem; sandbox restriction uncertain | B host files or agent tools | B host files or agent tools | B | X | B |
| Filesystem undo | N staged revert when requested | **—** | N checkpoints, limited coverage | — | — established in MSP | Rewind does **not** restore files | — |
| Conversation rewind | N stage/clear/commit | N fork; revert currently constrained | N fork/resume boundary | N fork | N fork/retract | X truncate/rewind | — |
| User shell / embedded PTY | N shell + PTY | N command/exec, connection-owned | N Bash; B interactive PTY | N Bash; B PTY | N userShell; B PTY | X terminal/PTY | B independent host terminal |
| Slash commands | N registry + command endpoint | B local RPC palette | N supported headless commands | N extension/template commands; B built-ins | Skills + B local operations | N/X command registry | — |
| Skills | N structured attachments; E activation | N list + structured skill input | N commands/Skill tool | N `/skill:name` | N skill input/list | X | — |
| `@` mentions | N file/agent attachment semantics | File path context; native mention means app/plugin | N CLI path/resource expansion | B explicit file context; no RPC CLI expansion | Native text path mentions | N/X resource/file search | Resource links; no guaranteed content expansion |
| Images | N, model-gated | N data/local images | N base64 images | N base64 images | N images | N implemented; advertised capability mismatch | N only for qualifying attachment store/model |
| PDFs/other files | N file attachments, model/tool dependent | B host reference; direct PDF input unverified | B host reference; tool/model dependent | B explicit context; PDF interpretation unverified | B path reference; direct document input unverified | Resource/file reference; exact PDF handling unverified | Resource links; direct PDF handling unsupported/unverified |
| Agent selection | N primary agent | No equivalent global agent registry; native model/config behavior | N supported agent | — | — established | Partial agent profile | — |
| Model/variant/effort | N model + variants | N model + advertised effort; E live settings | N model/effort | N model/thinking levels | N model/effort | N config options | N advertised model/effort |

**Notifications, drafts, tabs, exports, themes, localization, accessibility, and voice are client/host facilities for every harness.** Their availability depends on platform support and connection state, not an upstream promise.

### 3.6 External-session ownership rules

| Harness | Discover/read | Resume inactive session | Live attachment and concurrency |
|---|---|---|---|
| OpenCode | Query the same shared service, across its projects | Native session prompt/resume semantics | Shared service owns execution. Multiple clients can observe and mutate; CodeWalk must reconcile their changes. |
| Codex | Use shared daemon lists, including appropriate `sourceKinds` | `thread/resume` | Rejoins live daemon threads and replays pending requests. A separate `--listen ws://` process must never be presented as the same live owner. |
| Claude | SDK `listSessions`, `getSessionMessages`, subagent history | SDK resume/fork | Only host-owned queries are fully controlled. Arbitrary TUI process takeover is not supported by inspected evidence. `claude agents --json` can inform background-session state, not provide a general GUI control API. |
| Pi | SDK session listing plus RPC history | Launch/switch the persisted session through official surfaces | No verified shared process ownership. Do not open the same file for concurrent mutation based merely on its existence. |
| Muse | MSP list/read | MSP resume, respecting lease errors | Treat `sessionInUse` as authoritative. Do not bypass leases or assume the TUI shares a `muse serve` process. |
| Grok | Native ACP/history extensions | Native load/resume | Leader/shared-server semantics need qualification. Its documented leader/sandbox restriction matters. |
| `dsh` | ACP summaries | Inactive session resume | Cannot show the old transcript through ACP. Do not advertise live takeover or full history continuity. |

If activity/ownership cannot be established, offer **read history** and **fork where supported**. Do not silently start a second mutating owner.

### 3.7 Allow-all and sandbox semantics

The baseline remains allow-all ON for newly created CodeWalk sessions. Existing external sessions retain their current upstream policy until the user explicitly changes it.

| Harness | Baseline implementation | Mandatory distinction |
|---|---|---|
| OpenCode | Native per-session wildcard if the selected baseline is retained; save the prior ruleset and show effective policy | It overrides agent denies and is inherited by new children. OFF cannot simply erase rules changed by another client. `always` replies persist project-wide and must not be used as routine auto-approval. |
| Codex | Apply a qualified approval policy and handle eligible approval requests | `never` is not “approve everything”: operations outside sandbox authority may fail. Keep `danger-full-access` separate; respect `configRequirements/read`. |
| Claude | Explicit native permission mode when permitted; otherwise host callback policy | `bypassPermissions`, `auto`, `acceptEdits`, `dontAsk`, and `default` differ. Preserve mandatory interaction and explicit rules; never auto-answer AskUserQuestion or plan/user dialogs. |
| Pi | Show native unrestricted behavior | OFF has no native enforcement meaning. Disable the toggle with an explanation until a separately qualified extension provides enforcement. Project trust is not a tool-permission system. |
| Muse | Select preconfigured `allowAll` if allowed | The client selects a host-defined mode; it cannot invent rules. An already pending action is not necessarily retroactively decided by a mode change. |
| Grok | Qualified YOLO/approval mode | Managed requirements may forbid it; native sandbox profile remains distinct. |
| `dsh` | Host answers eligible ACP requests once | No native allow-all mode is established. Its `never` approval policy means deterministic rejection, not unrestricted execution. |

The global setting is a **default policy preference**, not proof that every harness can honor it.

---

## 4. Architecture, modules, interfaces, and state boundaries

### 4.1 Proposed layout

Use a small monorepo addition, not a fleet of microservices.

```text
host/
  package.json
  package-lock.json
  src/
    cli.ts
    host_service.ts
    runtime/
      process_owner.ts
      harness_installers.ts
      service_supervisor.ts
      runtime_versions.ts
    protocol/
      schema.ts
      commands.ts
      events.ts
      capabilities.ts
      errors.ts
    transport/
      http_server.ts
      websocket_sessions.ts
      pairing.ts
      client_auth.ts
      origin_policy.ts
    sessions/
      session_registry.ts
      session_runtime.ts
      command_dispatcher.ts
      command_receipts.ts
      projection_store.ts
      replay_store.ts
      external_session_discovery.ts
      attention_store.ts
    adapters/
      adapter.ts
      opencode_v2/
        client.ts
        mapper.ts
        reducer.ts
        recovery.ts
        permissions.ts
      codex/
        daemon_connector.ts
        rpc_client.ts
        mapper.ts
        recovery.ts
      claude/
        sdk_session.ts
        mapper.ts
        permissions.ts
        history.ts
      pi/
        rpc_session.ts
        mapper.ts
        history.ts
      muse/
        msp_session.ts
        mapper.ts
      grok/
        acp_session.ts
        extensions.ts
        mapper.ts
      acp/
        connection.ts
        mapper.ts
        capability_negotiation.ts
    workspace/
      project_registry.ts
      files.ts
      search.ts
      uploads.ts
      terminals.ts
    usage/
      native_usage.ts
      experimental_vendor_usage.ts
    notifications/
      attention_policy.ts
      web_push.ts
      notifier_webhooks.ts
    storage/
      database.ts
      migrations.ts
    diagnostics/
      redaction.ts
      health.ts
  test/
    contracts/
    fixtures/
    integration/

lib/
  main.dart
  app/
    codewalk_app.dart
    app_bootstrap.dart
    app_router.dart
  domain/
    hosts/
    harnesses/
    projects/
    sessions/
    timeline/
    requests/
    usage/
  data/
    host/
      codewalk_host_client.dart
      host_event_connection.dart
      protocol/
    local/
      local_store.dart
      migration_v1_to_v2.dart
      draft_store.dart
      preferences_store.dart
  application/
    hosts/host_controller.dart
    sessions/session_list_controller.dart
    sessions/session_controller.dart
    sessions/session_projection.dart
    composer/composer_controller.dart
    requests/request_controller.dart
    attention/attention_controller.dart
    workspace/workspace_controller.dart
  presentation/
    shell/
    onboarding/
    sessions/
    chat/
    composer/
    requests/
    workspace/
    settings/
    widgets/
    theme/
  platform/
    desktop/
    notifications/
    speech/
    connectivity/
```

Do not retain one 20,000-line class divided into `part` files. Each controller owns a bounded state object with explicit inputs and subscriptions.

A temporary `lib/main_v2.dart` is acceptable during implementation. Remove that transitional entrypoint at cutover; production does not contain a v1/v2 runtime switch.

### 4.2 Responsibilities

| Boundary | Owns | Must not own |
|---|---|---|
| Native harness | Actual execution, native credentials, native session history, tool/sandbox semantics | CodeWalk UI state |
| Harness adapter | Native requests/events, source mapping, native recovery, capability qualification | Widgets, notifications UI, generic app settings |
| CodeWalk Host | Process ownership, normalized projections, client auth, receipts/replay, host facilities, attention policy | Fabricated upstream capabilities or silent credential migration |
| Flutter data layer | Gateway transport, generated DTO decoding, local persistence | Upstream tool-name interpretation |
| Application controllers | Session state, composer state, request lifecycle, navigation intent | Raw JSON, Dio calls inside widgets |
| Presentation | Rendering, gestures, focus, accessibility | Network protocols or approval-drain policy |

### 4.3 Minimal adapter contract

Use one required session contract and optional capability groups. Avoid hundreds of one-line use-case wrappers and a giant method with arbitrary `Map` payloads.

```ts
interface HarnessAdapter {
  readonly descriptor: HarnessDescriptor;

  connect(context: HostContext): Promise<HarnessConnection>;
  discover(query: SessionQuery): Promise<Page<SessionSummary>>;
  open(ref: NativeSessionRef, intent: OpenIntent): Promise<SessionHandle>;
  create(input: CreateSession): Promise<SessionHandle>;
}

interface SessionHandle {
  readonly identity: SessionIdentity;
  capabilities(): Promise<SessionCapabilities>;
  snapshot(request: SnapshotRequest): Promise<SessionSnapshot>;
  subscribe(listener: (event: AdapterEvent) => void): Dispose;

  send(input: SendInput): Promise<NativeAdmission>;
  interrupt(target: InterruptTarget): Promise<InterruptReceipt>;

  lifecycle?: SessionLifecycleOperations;
  requests?: RequestOperations;
  selections?: SelectionOperations;
  commands?: CommandOperations;
  tasks?: TaskOperations;
  rewind?: RewindOperations;

  detach(): Promise<void>;
}
```

`detach()` means CodeWalk stopped observing. It does not inherently kill the session.

Workspace operations have a separate interface because they may be native or CodeWalk Host facilities:

```ts
interface WorkspaceServices {
  files?: FileOperations;
  search?: FileSearch;
  terminals?: TerminalOperations;
  uploads: UploadOperations;
}
```

The adapter selects the appropriate implementation; the UI sees provenance and constraints.

### 4.4 Identity

Use four identities:

```ts
type HostId = string;              // stable random ID persisted by CodeWalk Host
type HarnessInstanceId = string;   // harness + native user/profile/store/service identity
type ProjectId = string;           // host-issued project identity
type NativeSessionId = string;

interface SessionIdentity {
  hostId: HostId;
  harnessInstanceId: HarnessInstanceId;
  nativeSessionId: NativeSessionId;
}
```

Key local records by this tuple, not by a bare session ID or URL.

Important rules:

- A URL is an endpoint alias, not a host identity.
- A native session can move projects without becoming a different session.
- Canonical native paths, Windows case behavior, drive roots, UNC paths, and symlink identity need host-side handling.
- Fork lineage and parent-child lineage are separate fields.
- Changing a host’s native data directory creates a different harness instance unless a supported migration establishes continuity.
- A copied host installation must not silently share the same identity with the original.

### 4.5 Domain model

Do not force every native protocol into “one user message, one assistant message, one turn.”

```ts
interface SessionSummary {
  identity: SessionIdentity;
  projectId: ProjectId;
  title?: string;
  origin: "codewalk" | "external" | "unknown";
  parent?: SessionIdentity;
  forkedFrom?: ForkReference;
  ownership: SessionOwnership;
  execution: ExecutionState;
  attention: AttentionSummary;
  selections: SelectionState;
  nativeUpdatedAt?: number;
}

interface TimelineEntry {
  id: string;
  nativeId?: string;
  kind:
    | "user" | "assistant" | "synthetic" | "tool"
    | "shell" | "selection" | "compaction"
    | "executionOutcome" | "notice" | "unknown";
  nativeTurnId?: string;
  runId?: string;
  segments: TimelineSegment[];
  origin: Provenance;
  revision: number;
}

type TimelineSegment =
  | TextSegment
  | ReasoningSegment
  | ToolSegment
  | AttachmentSegment
  | FileChangeSegment
  | ChildReferenceSegment
  | UnknownSegment;
```

Preserve native display distinctions:

- OpenCode selection, synthetic, idle, and compaction rows.
- Codex item and turn boundaries.
- Claude tool-use/result linkage and background-task ownership.
- Pi branch entries and leaf identity.
- Muse view cursors, revisions, retracted items, and approval stages.
- Grok extension provenance.

`runId` is a CodeWalk execution-observation identity when an upstream protocol lacks an equivalent. It must not be presented as an official native turn ID.

### 4.6 Event envelope and provenance

```ts
interface EventEnvelope<T> {
  protocolVersion: 1;
  streamId: string;
  epoch: string;
  seq: number;                   // CodeWalk stream ordering
  hostId: HostId;
  session?: SessionIdentity;
  receivedAt: number;
  source: {
    harness: string;
    version?: string;
    method?: string;
    eventId?: string;
    cursor?: string;
    aggregateId?: string;
    aggregateSeq?: number;
    schemaVersion?: number;
  };
  durability: "fact" | "draft";
  payload: T;
  rawRef?: string;               // bounded host diagnostic artifact
}
```

Canonical payloads include:

```text
session.upserted / session.removed
ownership.changed / selections.changed
execution.changed / retry.scheduled
entry.upserted / entry.removed
segment.delta / segment.replaced
permission.pending / permission.resolved
form.pending / form.resolved
task.upserted / child.linked
usage.updated / quota.updated
attention.updated
projection.reset / replay.gap
connection.health
unknown.native
```

Raw provenance preserves interpretation and version-drift diagnostics. It is not a license to retain all transcript content indefinitely.

### 4.7 Capability negotiation

A boolean per feature is too weak. Use operation descriptors:

```ts
interface Capability {
  availability: "available" | "unavailable" | "experimental" | "conditional";
  source: "native" | "vendorExtension" | "host" | "communityExtension";
  reason?: string;
  constraints?: Record<string, string | number | boolean>;
  semantics?: string;
}

interface SessionCapabilities {
  readHistory: Capability;
  resumeInactive: Capability;
  observeLive: Capability;
  controlLive: Capability;
  concurrentControl: Capability;
  sendSteer: Capability;
  sendQueue: Capability;
  cancelQueuedInput: Capability;
  interruptTurn: Capability;
  stopBackgroundWork: Capability;
  fileRewind: Capability;
  conversationFork: Capability;
  approvalPolicy: Capability;
  forms: Capability;
  tasks: Capability;
  // Remaining supported operations use the same descriptor.
}
```

Effective capability is the intersection of:

1. Qualified adapter/version support.
2. Upstream handshake and methods.
3. Session ownership and administrator restrictions.
4. Selected model/agent capabilities.
5. Host and client platform facilities.

Do not probe mutating methods to discover whether they exist. Prefer schema/version/handshake evidence; a returned `methodNotFound` disables that operation and invalidates the relevant capability cache.

The descriptor must expose semantic limits such as:

- “Conversation fork; files unchanged.”
- “Checkpoint rewind excludes shell and subagent edits.”
- “Historical resume only.”
- “Stop current turn; background tasks continue.”
- “Host terminal; independent of agent sandbox.”

### 4.8 Execution and connection state machines

Keep connection state independent from execution.

```text
Connection:
unpaired → authenticating → connecting → hydrating → live
                                           ↓          ↓
                                        degraded ← disconnected
                                           ↓
                                        recovering → live

Execution:
inactive → starting → running ↔ waitingForPermission
                         ↔ waitingForInput
                         ↔ retryScheduled
                         → interruptRequested
                         → succeeded | failed | interrupted | unknown
```

An upstream restart or lost connection can make execution **unknown**. It cannot justify inventing a terminal outcome.

Task state is independent:

```text
queued → running → waitingForAction → completed | failed | cancelled
                  ↘ backgroundRunning ↗
```

A parent can become inactive while children remain active. “Parent turn ended” must not mean “all work finished.”

### 4.9 Recovery and ordering

**CodeWalk sequencing is ingestion/projection order, not proof of a global upstream causal order.**

The host maintains:

- A durable projection and durable normalized facts.
- A bounded in-memory draft/delta buffer.
- A durable command-receipt journal.
- Native source cursors where available.
- Per-session recovery generation and projection revision.

Clients reconnect with `{streamId, epoch, afterSeq}`. The host either returns a suffix or an explicit `replay.gap` followed by an authoritative snapshot at a CodeWalk watermark.

#### OpenCode recovery

The raw source verifies that global SSE is live-only, uses `data:` frames, and drops slow subscribers after 4,096 queued frames. It does not support `Last-Event-ID`. [O-EVENT]

Recovery must:

1. Establish the live stream first and buffer session events.
2. Hydrate active execution, session metadata, recent messages, inbox, permissions, and forms.
3. Apply buffered lifecycle changes over snapshots; follow the reference reducer’s active-hydration protection.
4. Use the experimental durable session log where qualified, with the native `after` cursor and `log.synced` watermark.
5. Repair ephemeral state separately: deltas, permissions, forms, and usage are not recovered merely by reading the durable log.

Do not require consecutive native durable sequence numbers. Internal events share that sequence space; `log.synced.seq` may exceed the last delivered public event.

The inspected reference reducer also documents an inbox/history hydration race at `client-solid-data.reference-reducer.ts:631–640`. Preserve admissions observed in live events while repairing that boundary. Permit a bounded reread; never delete an acknowledged user input just because two non-atomic snapshots missed it.

A text stream interrupted during disconnection may lack its earlier draft prefix. Display a syncing/incomplete state until authoritative ended content arrives. Do not append suffix deltas to a known incomplete prefix and call it complete.

#### Other adapters

- **Codex:** initialize, enumerate loaded threads, resume relevant threads, recover pages and pending requests. Completed items replace drafts. There is no established arbitrary event replay guarantee.
- **Claude:** keep the SDK query and its transport alive across phone disconnects. Client replay comes from CodeWalk Host. `Query.reinitialize()` is for an actual SDK/CLI transport gap, not every phone reconnect.
- **Pi:** recover durable entries and leaf identity; snapshot active RPC state. Historical entry cursors do not reconstruct all ephemeral deltas.
- **Muse:** use native cursor suffix/recovery, pending-request pointers, and view gap/page semantics.
- **Grok:** qualify its updates/history extension; do not assume ACP itself supplies replay.
- **`dsh`:** retain CodeWalk-observed history for CodeWalk-created sessions, but label it as host-observed. It cannot fill missing external history.

### 4.10 Sends, receipts, and ambiguous mutations

```ts
interface CommandEnvelope<T> {
  commandId: string;             // CodeWalk UUID
  clientId: string;
  target: SessionIdentity;
  expectedProjectionRevision?: number;
  expectedNativeTurnId?: string;
  payload: T;
}

interface CommandReceipt {
  commandId: string;
  state:
    | "received" | "admitted" | "applied"
    | "rejected" | "ambiguous" | "cancelled";
  nativeInputId?: string;
  nativeTurnId?: string;
  retrySafety: "sameNativeId" | "readOnly" | "unsafe";
  error?: OperationError;
}
```

Rules:

- Persist receipt intent before dispatch; repeated client transport commands reuse that receipt.
- An RPC correlation ID is not necessarily an idempotency key.
- Host crash after native submission but before receipt confirmation is still ambiguous if the native API lacks idempotent admission.
- OpenCode can use its native `msg_` prompt ID and identical payload for qualified retry.
- Muse uses native `commandId` replay semantics.
- Codex turn starts, Claude UUIDs, and Pi request IDs must not be treated as safe duplicate-submit handles without additional evidence.
- An ambiguous send remains visible with “delivery unknown.” Offer reconciliation, not an automatic resend.
- Identical prompts are distinct commands. Never content-dedupe them.
- Preserve draft text until admission is established; separately retain attachments whose upload succeeded.

### 4.11 Multi-client mutations and approvals

Serialize CodeWalk-originated commands per session. Pass native expected-turn guards where supported. This does not make external TUI mutations atomic with CodeWalk.

For approvals:

- CodeWalk Host is the sole responder among its clients.
- Request identity includes harness instance, session, upstream connection generation, and native request identity.
- Replayed native requests map back to an existing pending request using stable native anchors and payload identity.
- Store a pending/submitting/resolved state and native resolution.
- First accepted decision wins within CodeWalk; all clients receive resolution.
- If a TUI resolves it first, dismiss the app card from the native resolution or reconciled snapshot.
- A lost approval response must not cause the client to invent an approval result.
- Unknown approval options never receive automatic replies.

Global/session allow-all preferences are evaluated at the host. Questions, elicitation, secrets, plan decisions, and explicitly mandatory interaction remain separate.

Native policy restoration must preserve external edits. If the rules differ from the rules CodeWalk installed, show a conflict rather than overwriting them. OpenCode lacks an established atomic compare-and-swap for that update; document this limit.

### 4.12 Forms, tasks, usage, and errors

**Forms:** preserve field keys, types, required constraints, options, defaults, conditional visibility, and native cancel semantics. OpenCode’s `global` MCP elicitation owner also needs location provenance; it is not a real session.

**Tasks:** store structured native task/plan updates. Do not parse Markdown checkboxes or arbitrary tool text into authoritative tasks. Optional CodeWalk-controlled task tools would be a later, explicitly enabled extension.

**Usage:** separate these records:

```text
TokenUsage: input/output/cache/reasoning, cumulative or last-run, coverage
ContextUsage: used/limit, model, as-of, approximate/native
CostUsage: currency, amount, estimate/notional/billed, partial
QuotaWindow: account/provider/window, used amount or percent, reset, limits
Credits: amount, unit/currency, unlimited flag
```

Unknown data is unknown, not zero. Session token totals are not “quota remaining,” and lifetime token counts are not necessarily context occupancy.

**Errors:** normalize category and action while retaining native details:

```text
transport / authentication / authorization / capability
admission / ownershipConflict / nativeExecution / tool
rateLimit / quota / context / cancelled / unsupported / unknown
```

Include retry ownership: `upstreamScheduled`, `clientReadRetry`, `safeSameId`, or `manual`. A client reconnect must not duplicate an upstream model retry.

### 4.13 Runtime and dependency choices

Recommend TypeScript/Node because it uses the official rich SDKs without a separate SDK worker language.

Start with:

- Existing official SDKs where they materially reduce maintenance.
- Official ACP TS SDK for ACP connectors.
- A small qualified WebSocket library.
- Node cryptography and filesystem primitives.
- One local persistence engine.
- Optional PTY dependency isolated behind `TerminalOperations`.

Do not select package versions from memory. Pin exact packages after platform qualification.

For persistence, qualify `node:sqlite` on the selected supported Node runtime. If its stability/platform characteristics are unsuitable, select a supported SQLite binding with tested prebuilt artifacts. A bounded append-only journal plus atomic snapshots is an acceptable first vertical-slice fallback, but must pass crash recovery before production. Do not introduce both persistence systems permanently.

Go/Rust offer attractive executable distribution, but would either reimplement Claude SDK control logic or retain a Node worker. Dart AOT similarly saves language count on the client while adding upstream protocol maintenance. Bun may simplify packaging, but should be qualified after the Node implementation rather than becoming an additional first-release runtime.

---

## 5. UX and behavior

### 5.1 Mobile-first navigation

Use Material You with three primary destinations:

1. **Sessions:** unified list, host/project filters, harness badge, status/attention.
2. **Chat:** timeline, composer, request dock, task/background-work access.
3. **Host and settings:** connectivity, installation, credentials status, app preferences.

On compact screens, files, terminal, usage, and background work open in focused sheets/pages. On wide screens they occupy an optional utility pane. The same domain controllers power both layouts.

Maintain one timeline scroll owner. Preserve message-anchor position on prepend, background updates, child navigation, and return. A child update must not move a parent’s reading anchor.

### 5.2 Onboarding and installation

#### Desktop

Offer:

- Connect to an existing CodeWalk Host.
- Set up CodeWalk Host on this computer.
- View manual host setup instructions.

Managed setup follows an explicit installation plan:

```text
diagnose → choose ownership/install channel → download/verify
→ install runtime/host → discover or install harness
→ start/attach → authenticate harness on host
→ pair client → choose project → verify chat readiness
```

For OpenCode:

- Obtain v2 metadata from the official update surface, not GitHub’s v1 “latest.”
- Choose the actual OS/architecture target and verify SHA-256 before extraction.
- Use a versioned app-owned installation directory; never silently overwrite an existing user-managed binary.
- Prove that the official shared service starts from that binary and is reachable by the intended TUI.
- Use `opencode service` with native port 49374 and authentication.
- Use supported local service discovery/password commands privately, issue a pairing code, and redeem it with JSON `Accept`.
- Keep upstream service credentials on the host.
- Send `location.directory` explicitly when creating sessions; the service default working directory is the user’s home.

The host has its own configurable network endpoint, distinct from OpenCode’s port.

Upgrades are staged and checksummed. Installation and activation are different states. Do not restart an active user-owned daemon merely because a new binary downloaded.

#### Android, iOS, and Web

These targets connect; they do not install host harnesses locally.

Onboarding accepts a host pairing link/QR or host address. A host-side setup job can report progress and copyable instructions. Any harness login that requires terminal interaction remains an action on the host.

Do not rewrite `localhost` heuristically as an emulator address for real mobile profiles. An explicit development-emulator shortcut is sufficient.

### 5.3 Authentication layers

Keep three layers independent:

| Layer | Purpose |
|---|---|
| Network/proxy authentication | User’s VPN, SSH, TLS proxy, or optional identity proxy |
| CodeWalk Host authentication | Pairing and per-client access to the host gateway |
| Harness/provider authentication | Official CLI/SDK login or API-key configuration on the host |

For CodeWalk Host:

- Loopback bind by default.
- Single-use short-lived pairing codes.
- Separate per-client credentials and revocation.
- Store token hashes on the host; native clients use OS secure storage.
- Use exact-origin checks and scoped proxy authentication.
- Browser connections mint short-lived one-use WebSocket tickets through authenticated `fetch`, avoiding long-lived credentials in socket URLs.
- Default Web credential persistence to session memory; persistent storage requires an explicit choice and clear limits.

For harnesses:

- **Codex:** existing host login first; official device-code login where qualified. Do not use the private first-party remote-control relay.
- **Claude:** user authenticates the unmodified CLI through Anthropic’s flow or uses an API key. CodeWalk does not provide claude.ai OAuth or collect/forward its tokens.
- **Muse/Grok/Pi:** use qualified official host login/configuration surfaces; do not infer that a loopback browser OAuth flow works from a phone.

Claude and Codex policy interpretations are release-time verification gates, not permanent legal guarantees.

### 5.4 Unified session list

Group by host/project, with optional cross-host recents. Each row shows:

- Harness and origin.
- Running, waiting, retrying, inactive, or unknown state.
- Attention badge.
- External ownership/control availability.

Opening a session first shows a bounded cached preview, then revalidates. The composer stays unavailable until mutating ownership is established.

Create-session flow chooses project and harness before model/agent options. Remember the most recent compatible selection per harness/project, not one cross-harness model string.

Archive semantics must be explicit:

- Native archive where supported.
- “Hide in CodeWalk” for local archive metadata.
- Delete remains native deletion, with native descendant scope shown.

Do not hide external sessions solely because they lack a title or resemble v1 internal sessions.

### 5.5 Composer and complete chat lifecycle

The composer displays:

- Current harness.
- Effective model/variant/effort/agent selections.
- Steer or queue delivery choice when supported.
- Attachment and mention chips.
- Approval mode with separate sandbox/access details.

Busy sending behavior:

- OpenCode: explicit steer/queue, native inbox entries, editable delivery when supported.
- Codex: explicit steer with expected native turn; queue only after experimental qualification.
- Claude: describe native delivery as “send during current work” rather than falsely guaranteeing precise queue boundaries.
- Pi/Muse/Grok: expose their native delivery choices.
- `dsh`: preserve a local draft while busy; do not call that an upstream queue.

The send button changes to an admission-progress state, not “completed.” Queued items are shown separately from delivered transcript rows. Cancellation and editing are available only when actually supported.

Empty-send continuation should be a deliberate “Continue” action, avoiding accidental double-tap heuristics.

### 5.6 Commands, skills, and mentions

Create a typed command catalog with source:

```text
client operation / native harness command / skill / extension command
```

Keep app actions such as new session, session picker, model picker, help, and export separate from harness commands.

- OpenCode uses native command execution and structured skill/agent/file attachments.
- Codex’s TUI commands are not an app-server command registry; map supported client actions to RPCs.
- Claude hides terminal-only commands and uses the supported command catalog.
- Pi distinguishes skills, templates, extensions, and app-local built-ins.
- Muse exposes skills; do not fabricate all TUI commands.
- Grok enables only negotiated qualified commands/extensions.
- `dsh` does not display a native command/skill catalog.

A selected file mention must retain semantic provenance. It is not automatically the same across protocols:

- Structured native file reference where supported.
- Explicit host path reference where supported.
- Explicit bounded text context where needed, with preview and size budget.

Codex native `mention` inputs for apps/plugins must not be confused with file mentions.

### 5.7 Asynchronous children and background work

Provide a compact **Background work** surface with a tree of verified relationships:

```text
Parent session
  Child: running / waiting / completed / failed / cancelled
    Nested child, if supported
  Shell task: running / completed / failed
```

Each item has native identity, source, model/agent where known, status, and the controls supported for that item.

For OpenCode:

- Discover children from native metadata, `parentID` listing, active sessions, and events.
- Preserve child association across reconnect; do not use positional pairing or regex guessing.
- Treat native synthetic completion as a parent timeline event.
- A background child can wake the parent after the parent’s previous execution ended.
- “Move blocking work to background” acts on all backgroundable work in the session; do not label it as per-child backgrounding.
- Show the known nested-background completion defect as an upstream qualification concern. Do not counteract it with invented terminal states.

For Codex, child threads may be observe-only; direct input is not universally allowed.

For Claude, enable `perTaskStopAffordance` only when the UI actually provides task stop controls. Partial parent interrupts must not strand background work without an accessible control.

Notification defaults:

- Child completion updates the work surface quietly.
- Child permission/question/error can create root-level attention with an origin badge.
- A real parent continuation can create parent attention.
- Completion of the parent turn alone does not announce that all children finished.

### 5.8 Stop, cancel, rewind, and files

Use separate operations:

| Action | Meaning |
|---|---|
| Stop current turn | Interrupt the current native execution scope |
| Cancel queued input | Remove a still-pending native input |
| Stop background item | Target one child/task when supported |
| Stop all session work | Explicit broader action with a displayed target scope |
| Disconnect | Detach the client; work may continue |
| Delete session | Native removal, including its defined descendants |

For Claude, the public `Query.interrupt()` signature does not expose every raw queue-cancellation field found in the types. Do not promise “Stop clears every queued message” without a qualified public control. The receipt must explain work that may remain queued.

Rewind uses separate labels:

- OpenCode: stage boundary, optionally restore files, clear staged revert, commit.
- Codex/Pi/Muse: fork from boundary; files unchanged unless a separate supported action is used.
- Claude: checkpoint file rewind with explicit exclusions; conversation branching separately.
- Grok: conversation rewind; files unchanged.
- `dsh`: unavailable.

Do not implement automatic `git apply -R`, checkout, stash, or a universal filesystem undo behind a chat “Undo” button.

For file editing:

- Retain focused editing, syntax highlighting, line-ending preservation, explicit save, and local editor undo/redo.
- Default autosave OFF.
- Use content revision checks and report external changes.
- Explain that native APIs without atomic compare-and-swap cannot guarantee conflict-free concurrent editing.
- Keep host file authority and agent sandbox authority separate.
- No hidden shell sessions for ordinary file operations.

### 5.9 Attachments

Use HTTP upload, not large inline gateway WebSocket frames.

- Validate MIME from bytes and apply adapter/model limits.
- Keep originals in host-owned attachment storage; do not scatter temporary uploads into projects.
- Bind references to host/session identity.
- Preserve upload receipts and hashes for safe retry.
- Do not delete attachments still referenced by durable history.
- Translate into native data/image/file references.
- Enable PDF-specific behavior only after actual model/tool qualification.
- Optional local document extraction is a separately advertised host capability; it must not silently send content to a cloud converter.

Existing 10 MB UI limits are a useful initial ceiling, but the effective ceiling must also account for native encoded-frame limits such as Muse’s 10 MiB protocol frame.

### 5.10 Usage and quotas

Keep the current compact/mobile popover and wide-screen utility-pane pattern. Display distinct sections:

```text
Context
Tokens
Estimated/notional cost
Account limits and credits
```

Show data source, account/provider, timestamp, coverage, and partial/stale state.

For experimental vendor queries:

- Explicit opt-in per host/provider.
- Prefer official documented authentication mechanisms.
- Never refresh or rewrite vendor credential stores.
- Claude OAuth usage scraping is not an assumed supported plugin.
- Codex’s native rate-limit surface removes the need for its private usage endpoint.
- Cache per account/provider; do not query once per session.
- Respect `Retry-After` and disable repeatedly incompatible plugins.
- No token, cookie, or credential data enters Flutter or logs.

### 5.11 Notifications and background delivery

**Recommendation:** use a durable host attention inbox as the primary system. Delivery channels are projections of that inbox.

The host emits attention for authoritative permission, question, terminal failure, and qualifying completion events. Notification identity includes host, session, run/request, and category.

Suppress duplicate alerts while an authenticated client is actually focused on the affected session. Use a short expiring presence lease; a stale browser heartbeat must not suppress alerts indefinitely.

| Platform | Initial delivery | Limit |
|---|---|---|
| Desktop | Local notifications and tray while app runs; host attention retained otherwise | Closed app cannot display local notifications without an independently running delivery component |
| Android | One opt-in foreground monitor while permitted; local notifications; opportunistic scheduled catch-up | Not a permanent always-on guarantee |
| Web/PWA | Host sends standards-based Web Push; visible app uses in-app attention | Requires supported browser, permission, service worker, and reachable push service |
| Native iOS | In-app attention and resume catch-up | Closed-app push remains gated on authorized APNs sender infrastructure |
| iOS PWA | Web Push where the installed Home Screen app supports it | Separate from native-app notifications |

Android 15+ imposes a six-hour-per-24-hour background limit on `dataSync` foreground services. Implement timeout handling and stop cleanly; do not retain the current service as an unlimited monitor. [Android foreground-service timeouts](https://developer.android.com/develop/background-work/services/fgs/timeout?hl=en)

Web Push is available for qualifying iOS/iPadOS Home Screen web apps and does not require distributing native-app APNs signing keys. This provides a practical optional delivery route under the no-hosted-relay baseline. [WebKit Web Push documentation](https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/)

Native APNs credentials are tied to an authorized developer team/topic and must remain private. They cannot be shipped to arbitrary hosts as a shared secret. Background notifications also have throttling and delivery limits. [APNs token authentication](https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns), [background notification delivery](https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app)

Push is an alert hint, not execution truth. A tap opens the exact scoped session and revalidates the underlying request before enabling an approval action.

### 5.12 App-local behavior

Retain:

- Drafts, attachment drafts, composer history.
- Tabs, pins, recent-session navigation, and undo-close.
- Markdown, code, LaTeX, Mermaid, and the existing safe HTML subset.
- Exports, message images, copy/share/read-aloud.
- Localization, RTL, focus traversal, semantics, keyboard shortcuts.
- Theme preferences, dynamic color, density, contrast, text sizing.
- Voice input/output through platform-qualified backends.
- Sanitized diagnostics and release history.

Simplify canned answers into templates with explicit replacement/append and visible optional selection overrides. Forwarding creates a new explicit send command per target; ambiguous delivery is tracked per target.

Advanced attention overlays, Android Auto, specialized voice backends, and embedded Tailscale can follow the core release. Their persisted preferences should be retained and shown as temporarily unavailable, not silently discarded.

---

## 6. Rewrite, reuse, discard, documentation, and migration

### 6.1 Reuse map

| Existing area | Decision | Likely files | Proposed destination/reason |
|---|---|---|---|
| Markdown/math/HTML/Mermaid rendering | **Keep and adapt** | `chat_message_text_part.dart`, `math_markdown.dart`, `basic_html_markdown.dart`, `mermaid_diagram_widget.dart` | `presentation/chat/rendering/`; mostly app-local, but remove raw OpenCode part dependencies |
| Theme tokens and responsive utilities | **Keep; simplify choices gradually** | `presentation/theme/*`, window-size and visual-style utilities | Preserve user settings; remove automatic upstream theme-registry dependency from protocol work |
| Tabs, MRU, icon/color presentation | **Keep UX; rewrite state ownership** | `app_tab_strip.dart`, `session_tab_strip.dart`, `chat_provider_session_tab_ops.dart` | `application/sessions/` + `presentation/sessions/`; use new identity tuple |
| Chat timeline/viewport | **Reuse algorithms/tests selectively** | `chat_page_scroll_coordinator.dart`, `chat_page_timeline_viewport.dart`, runtime support | New timeline model and one scroll owner; avoid porting the whole page class |
| File viewer/editor/diff parser | **Keep UI; replace services** | `chat_page_file_viewer.dart`, `session_diff_viewer.dart`, `diff_parser.dart` | Dedicated workspace controller; native/host file services |
| Terminal renderer/extra keys | **Keep** | `third_party/xterm`, `codewalk_terminal_panel.dart`, extra-key widget | Replace transport and lifetime controller |
| Speech/TTS abstractions | **Keep; platform-qualify** | `speech_input_service*`, `speech_engine_platform_support.dart`, `services/tts/*` | `platform/speech/`; no harness dependency |
| Notifications/tray/sound presentation | **Keep shell; rewrite event policy** | `notification_service.dart`, `sound_service.dart`, desktop tray services | One attention controller; host-derived identity and state |
| Secure storage/redaction/path utilities | **Keep after audit** | `core/auth/*`, `app_logger.dart`, path helpers | Separate gateway/proxy auth from harness auth |
| Managed runtime | **Rewrite** | `local_opencode_server_runtime*` | Host installer/runtime supervisor with explicit ownership |
| ChatProvider/ChatPage and raw wire models | **Replace** | `chat_provider.dart` and parts; `chat_page.dart` and parts; v1 data models | New domain and bounded controllers |
| Quota shell probe/title/file mutation services | **Discard implementation** | `quota_remote_datasource*`, `chat_title_generator.dart`, `workspace_file_operations_service.dart` | Native usage/title behavior and explicit host services |

The existing `LocalOpencodeServerRuntime` interface at `local_opencode_server_runtime_types.dart:1–30` is useful as an inventory of lifecycle needs. Its old process ownership and installer strategies are not suitable for direct reuse.

### 6.2 Disposition of v1 workarounds

The 25 inventory rows should receive explicit migration checkboxes in implementation tracking.

| Inventory rows | Disposition |
|---|---|
| 1, 4–7, 11, 13, 15 | Remove dual SSE, completion polling, per-delta refetch, fuzzy optimistic matching, growing-limit history, v1 event aliases, and legacy route/shape fallbacks |
| 8–10, 14 | Replace synthetic completion/error stamps, string cancellation suppression, busy heuristics, and ad hoc tombstone/grace logic with typed adapter state and authoritative repair |
| 16, 18 | Remove v1 config-write deferral and fake-agent preference sync; use native session selections and CodeWalk-owned metadata |
| 17, 20, 21, 22, 24, 25 | Remove hidden title/quota/file sessions, heuristic child resolution, command filesystem scanning, assumed native archive, resident-message cost math, and unknown-part-as-text fallback |
| 2, 3, 12, 19, 23 | Replace with bounded liveness/recovery, scoped invalidation, native diff semantics, and one attention-delivery architecture; these needs do not vanish merely because v2 exists |

Keep bounded caches, generation guards, notification batching, and non-active-host health checks where they solve genuine client concerns.

### 6.3 Documentation migration

Coordinate these changes at the corresponding implementation boundary:

- **ADR-023:** retain contract-first policy; update official v2 references and applicability. Supersede v1-only optimistic-ID and lifecycle invariants for the v2 implementation using inspected native idempotency evidence.
- **ADR-023 EXC-001:** rewrite the auto-approval exception for actual v2 scope, persistence, deny overrides, child inheritance, and multi-client behavior.
- **ADR-029:** replace hidden quota shell strategy with native usage and explicit experimental host plugins.
- **ADR-033:** keep proxy authentication separate from host and upstream auth; qualify Web/iOS support.
- **ADR-043/052:** supersede shell-based file mutation transport; preserve focused editor and explicit-save policy.
- **New ADRs:** gateway/native ownership, canonical domain/replay, external-session control, capability negotiation, platform/background delivery, and local-data migration.
- **Official anchors:** update `ai-docs/opencode_server.md`, `opencode_web.md`, and `opencode_models.md` to clearly pinned v2 obligations at cutover. Preserve historical v1 material through Git/v1 maintenance documentation.
- **CONTRACT_MATRIX.md:** replace v1-only statements with per-harness, per-version contracts and fixture links.
- **CODEBASE.md:** reflect actual new modules and commands after they exist.
- **BEHAVIOR.md:** update only implemented behavior after verified stages.
- **README.md:** distinguish client, host, harness installation, network setup, and platform limits.
- **CHANGELOG.md:** preserve machine-readable release headings and existing announcements.

Do not recreate `ROADMAP.md`; GitHub Issues remain the project tracker.

Intentional divergence from official semantics requires an ADR exception with rationale, risk, rollback/feature flag, and regression tests. App-owned host services must be labeled as such; they must not appear in an “official OpenCode API” contract.

### 6.4 Local-data migration

Create a new versioned namespace:

```text
v2 settings
host profiles
harness instances
project mappings
session UI metadata
drafts
tabs and pins
local attention
cache schema
migration journal
```

Migration is idempotent and restartable.

Import:

- App appearance, locale, accessibility, keyboard, voice, and notification preferences.
- Canned answers as templates.
- Server profile metadata as migration candidates.
- Draft text and readable attachment references.
- Tabs/pins only after a native session mapping is established.

Do not reinterpret v1 message snapshots as v2 wire messages. They can remain a clearly labeled legacy cache/export, but they do not establish current server state.

A v1 OpenCode URL becomes an **unverified upstream connection candidate**, not a silently valid CodeWalk Host. A JSON v1 response yields a legacy-server explanation and setup path.

For native v1→v2 OpenCode session migration, use upstream migration status and session identities. Do not invent an old/new ID mapping from titles.

Keep the original local payloads until migration is confirmed successful. Do not put large payloads back into shared preferences; preserve ADR-016’s bounded-storage intent.

### 6.5 Upgrade and rollback

Current `pubspec.yaml` is `1.265.0+1790827338`. Production v2:

- Uses the same Android application ID and signing key.
- Must have a strictly larger Android version code.
- Must not reset the build suffix to `1`.
- Uses an appropriate first major release, not a minor release from v1.
- Adds independently validated iOS and Windows build metadata where their formats differ.

A manual legacy APK may have a lower version code and may not install over v2. Document the actual tested procedure; do not promise a one-click downgrade.

Possible mitigation, for discussion: publish a signed legacy rescue build with a higher build code and document its updater behavior. The rejected final-v1 updater guard must not be silently introduced.

App rollback does not guarantee upstream OpenCode database rollback. Let OpenCode own its migration. For a major host migration, provide an official export/backup procedure before changing versions; never copy a live database and call it a valid backup.

---

## 7. Ordered implementation stages and rollout

### 7.1 Bounded prerequisite spikes

These spikes resolve the highest-risk assumptions before a broad rewrite. Each returns a fixture, observed behavior, supported version/platform table, and a concrete go/no-go result.

| Spike | Budget | Required result |
|---|---:|---|
| **A — OpenCode shared service and recovery** | 2 working days | Official binary/checksum/service/pairing on representative hosts; TUI/client continuity; prompt idempotency; snapshot/inbox race; experimental log and file-write qualification |
| **B — Shared Codex connector** | 2 working days | UDS WebSocket connection, daemon-version discovery, TUI live rejoin, pending approval replay, browser gateway access, restart/version skew |
| **C — Claude external ownership and SDK lifecycle** | 2 working days | TUI history discovery/resume, active-session restrictions, canonical session ID, streaming query lifetime, interrupt receipt/race behavior, background task stop |
| **D — Platform packaging and storage** | 2 working days | macOS host installation strategy; Windows startup; Linux ARM64 runtime; selected SQLite/PTY dependencies; iOS skeleton and signing path |
| **E — Notification delivery** | 1 working day | Host Web Push proof, Android timeout behavior, iOS native limitations, exact delivery-support labels |

No spike should “succeed” by bypassing a native ownership lock, using a private relay, or spoofing client identity.

### 7.2 Implementation stages

Estimates below are engineering effort ranges, not calendar commitments. A first rewrite estimate has low confidence until spikes A–D complete.

| Stage | Dependencies | Deliverable and acceptance criteria | Validation |
|---|---|---|---|
| **S0 — Contract baseline** | Planning direction settled | Version pins, source/schema catalog, capability definitions, ADR migration decisions, v1 preservation reference, scoped issues | Read-only contract audit; no broad builds needed |
| **S1 — New client skeleton and gateway protocol** | S0, storage/platform spike | New bounded controllers, generated gateway DTOs, local identity/drafts, six-target compile skeleton; no v1 wire imports in new presentation | Domain/controller tests, targeted analysis, Web and iOS compile gates |
| **S2 — Host lifecycle and OpenCode vertical slice** | S1, spike A | Pair/connect, explicit project, create/list/open/send/stream/interrupt; official shared service used; work survives client disconnect | Adapter fixtures, disposable live service integration, focused widget tests |
| **S3 — Complete OpenCode lifecycle** | S2 | Forms/permissions, children/background, queue/inbox, model/agent/variants, native revert, paging, files/PTY, usage, external TUI continuity | Recovery/race tests, child navigation tests, native contract smoke |
| **S4 — Shared Codex slice** | S2, spike B | Same client UX over daemon; external/live threads, approvals, skills, effort, usage, fork semantics, connection-preserved terminal | Codex fixtures, multi-client live integration, Web-origin tests |
| **S5 — Migration and app-local parity** | S3/S4 | Signed v1→v2 upgrade; drafts/tabs/settings/locale; exports/rendering/voice baseline; attention and platform-specific support states | Migration interruption tests, accessibility/RTL, real upgrade tests |
| **S6 — v2.0 qualification** | S3–S5, spike E | OpenCode + Codex production qualification across all six targets; documented background limits; no approved review blockers | Stable `make check`, `make test-web`, platform builds, coherent-stage review loop |
| **S7 — Claude and Pi qualification** | S6 architecture proven, spike C | Claude rich SDK integration and honest external ownership; Pi native RPC including steer/follow-up and extension UI | Native adapter fixtures, ownership/lifecycle integration, focused reviews |
| **S8 — Muse and Grok qualification** | Stable host/client contract | MSP cursors/leases/approvals and Grok negotiated extensions; distribution/auth/ownership support tables | Vendor-specific conformance and real protocol captures |
| **S9 — Experimental ACP candidates** | ACP connector qualified | `dsh` only with explicit history limitations, or after upstream improves the contract | ACP fixtures; no claimed parity without upstream evidence |

A reasonable initial planning envelope is roughly **10–16 engineering weeks** for the first qualified release, including platform work and review, with substantial uncertainty. Optional integrations add separate effort and should not block learning from the first two complete adapters.

### 7.3 Minimum viable production scope

The first production version is not just “send text successfully.” It must include:

- OpenCode v2 and shared-daemon Codex.
- External-session discovery, read, and supported continuation.
- Streaming/reasoning/tools, permissions/forms, interruption, errors/retries, reconnect repair.
- Unified sessions, project selection, model/effort controls, drafts/tabs, attachment handling.
- Files, truthful rewind/fork behavior, usage separation, exports, localization, accessibility.
- Background child visibility and attention.
- Six-platform support with explicit facility differences.

Defer by qualification, not by arbitrary feature deletion:

- Experimental Codex queue/plan controls.
- Native iOS closed-app push pending sender decision.
- Advanced Android overlays/Auto and embedded Tailscale.
- Experimental quota plugins.
- Full specialized voice-backend matrix.
- Muse/Grok and `dsh` integration phases.

The user can choose to move a particular deferred facility earlier, but it must carry its dependency and test cost.

### 7.4 Release handling

This planning task authorizes no release.

When implementation is later authorized:

- Commit verified coherent stages.
- Run the required reviewer loop at those boundaries.
- Use an explicitly authorized major release for initial v2.
- Use the project’s `make release` workflow and approved announcement text.
- Build Android release artifacts on appropriate x64/GitHub Actions runners, not ARM64 Linux.
- Add signed iOS distribution gates before claiming a downloadable native iOS release.
- Monitor publication/CI through the project’s prescribed workflow.

---

## 8. Testing, validation, and performance budgets

### 8.1 Adapter contract fixture suite

Store pinned sanitized fixtures under `host/test/fixtures/<harness>/<version>/`.

For each supported version include:

- Handshake/capabilities.
- Session list/read/create/resume/fork/delete behavior.
- Text/reasoning/tool lifecycle.
- Permission and form requests/resolutions.
- Error, retry, interrupt, and process shutdown.
- Usage and quota updates.
- Child/background work.
- Unknown fields/types and malformed frames.
- Native history/recovery boundary.
- Unsupported-method and administrator restriction responses.

Keep source provenance with fixtures. Muse’s supplied conformance transcripts are schema-validated examples, not proof of live behavior; supplement them with sanitized live captures.

### 8.2 Mandatory correctness scenarios

| Area | Required cases |
|---|---|
| Framing | UTF-8 split across byte chunks; SSE comments/multiline data; JSONL CR/LF; U+2028/U+2029 inside JSON strings; oversized/truncated frames |
| Ordering | Delta before start; ended before delayed delta; replayed completion; retry reusing an assistant ID; stale snapshot after live events |
| Admission | Repeated identical prompts; safe same-ID OpenCode/Muse retry; host crash after dispatch; lost response; inbox promotion during hydration |
| Recovery | Phone sleep, socket drop, host restart, native daemon restart, replay eviction, native-log internal sequence gaps |
| Permissions | Two app clients answer; external TUI resolves first; replayed RPC request; policy toggle during pending request; unknown choices; explicit denies |
| Forms | Conditional fields, arbitrary keys, multiselect values, cancellation, stale form, global owner/location, secret/external fields |
| Children/tasks | Parent idle while child runs; child permission; nested background completion; parent restart; stop one child; stop parent with background children |
| External sessions | TUI-created session before/after connect; read versus live control; inactive resume; ownership conflict; new SDK identity; source filters |
| Files/undo | External editor change, symlink escape, Windows roots/UNC/case, partial checkpoint coverage, native staged revert/clear/commit, unsupported file undo |
| Selection | Native catalog invalidation, unavailable variant, external model switch, model-dependent images/tasks/effort, busy selection boundary |
| Usage | Sparse quota update, unknown reset/duration, partial cost, subscription notional cost, native quota failure, stale/failed plugin |
| Scope isolation | Same native ID on two hosts, URL alias, host switch during request, moved session, child from another project, stale notification tap |

### 8.3 Real integration scenarios

Mocks cannot establish shared ownership.

For OpenCode:

- Start a session in TUI, attach CodeWalk, send from each client, interrupt, and reconnect.
- Repeat with permissions, forms, children, background shells, and a parent continuation.
- Test managed service restart separately from foreground `serve`; restart continuity differs.
- Verify v1 detection cannot be fooled by v2’s HTML 200 fallback.

For Codex:

- Confirm CodeWalk attaches to the actual shared daemon.
- Start and continue a TUI thread, replay pending approvals, and test simultaneous observation.
- Test daemon/CLI version skew and native updater restart.
- Confirm terminal behavior when the native connection—not merely the phone connection—closes.
- Verify browser access through the gateway and rejection of unintended origins.

For Claude:

- List terminal-created history, resume after terminal ownership ends, and preserve canonical identity.
- Confirm CodeWalk-owned streaming queries continue while the phone disconnects.
- Verify background tasks survive the intended parent interrupt behavior.
- Test queued-message receipt behavior and the documented interrupt race.
- Confirm host auth works without CodeWalk reading or forwarding OAuth credentials.

For Pi/Muse/Grok:

- Qualify inactive resume and active-owner conflict independently.
- Verify branch/leaf, MSP cursor/lease, and Grok extension semantics respectively.

### 8.4 Client/platform gates

| Target | Gate |
|---|---|
| Android | x64 runner builds arm64 APK; signed upgrade; notification permission; timeout; background/force-stop; microphone; attachment picker; RTL |
| Linux | Desktop build and host integration; x64 release plus ARM64 qualification; tray, microphone, files, TLS |
| macOS | Native build; signed/notarized distribution strategy; sandbox/host companion; Keychain; microphone; service lifetime |
| Windows | Windows runner; path/UNC handling; UDS/daemon path limits; detached startup; terminal/PTY; native updater |
| Web | Chrome tests plus Safari/Firefox smoke; CORS/Origin; auth tickets; HTTPS/mixed-content; refresh/reconnect; uploads/downloads; PWA push |
| iOS | Xcode build, simulator and physical device; signing/distribution; Keychain; microphone; pairing/deep links; resume recovery; truthful push support |

The absence of `ios/` in v1 means iOS setup is new work, not merely enabling an existing platform flag.

### 8.5 Proposed validation commands

These are future execution commands; none were run during planning.

Focused Flutter checks:

```bash
source ~/paths
export PATH="$HOME/flutter/bin:$PATH"
rtk flutter analyze lib/domain lib/application lib/data/host
rtk flutter test --no-pub test/unit/v2
rtk flutter test --no-pub test/widget/v2
```

Host checks, after defining the package scripts:

```bash
source ~/paths
rtk npm --prefix host run typecheck
rtk npm --prefix host test -- --runInBand
rtk npm --prefix host run test:contracts
```

Final stable gates:

```bash
source ~/paths
export PATH="$HOME/flutter/bin:$PATH"
rtk make check
rtk make test-web
```

Platform builds run on their appropriate hosts. For a useful test APK after checks pass, use a specific `HEY_CAPTION` with `make android` on a supported runner.

Do not use `make precommit` directly for normal CodeWalk validation. After review micro-fixes, use focused checks unless shared/build/generated/l10n changes invalidate the full gate.

Add host typecheck/contract tests to the project’s final check gate before host code can ship.

### 8.6 Performance and battery targets

These are proposed acceptance budgets to measure, not current results:

- Initial transcript page: approximately 50 entries; bounded resident timeline, initially around 200–500 entries.
- Render flush: at most once per display frame, with streaming updates ordinarily coalesced to 50–100 ms.
- Background clients receive attention and lightweight summaries, not every text delta.
- No full-message network fetch per delta.
- No all-host health polling every few seconds.
- Gateway JSON frames remain bounded; attachments use binary HTTP uploads.
- Terminal output has a byte cap, ring buffer, and explicit truncation/artifact access.
- Initial replay retention: bounded by both time and bytes, with explicit gap/reset behavior; start with a host-wide configurable budget rather than unlimited per-session logs.
- App caches preserve bounded entries, size, and TTL; shared preferences hold metadata only.
- Benchmark session switches, large Markdown/code blocks, 10,000-entry histories, many child sessions, and sustained terminal output.
- Measure Android background-monitor battery cost over an eight-hour controlled run; set a ship threshold after the first implementation measurement.

Never increase cache or buffer limits to conceal an unbounded reducer or rebuild problem.

### 8.7 Polling policy

| Purpose | Policy | Cost/invalidation |
|---|---|---|
| Active gateway/native stream | Event-driven | No recurring transcript poll during healthy streaming |
| Idle host health | Approximately 60 seconds while visible; longer while inactive | One small host request; stream failures trigger immediate recovery |
| Reconnect repair | Immediate bounded snapshot/replay | Coalesced per session; stop when recovery completes or reports a blocker |
| Native external history without events | Filesystem invalidation where possible; otherwise visible-list refresh around 30 seconds | Bounded pages, not repeated full transcript scans |
| Experimental vendor quota | On open/manual refresh; minimum shared TTL; optional visible pane interval around 20 minutes | Per account/provider, respect `Retry-After`, no background refresh loop |
| Android scheduled catch-up | OS-scheduled opportunistic task | One gateway attention query, not seven native polling stacks |
| Pending native mutation reconciliation | Bounded attempts with backoff | No automatic resubmission of unsafe mutations |

If a specific adapter needs polling beyond this policy, document its exact missing upstream signal, scope, maximum duration, and byte/request cost.

---

## 9. Risks, unresolved facts, sources, and execution start

### 9.1 Principal risks and mitigations

| Risk | Mitigation |
|---|---|
| Universal host increases onboarding burden | Ship a small signed companion, one clear pairing flow, manual setup recipes, and ownership-aware diagnostics; measure setup abandonment before adding a direct mode |
| Upstream protocols change rapidly | Pin certified versions, retain fixtures/raw provenance, use open decoding, gate experimental methods, and qualify upgrades before activation |
| External ownership is overstated | Separate read/resume/observe/control/concurrent-control capabilities; respect native leases and document unsupported TUI takeover |
| Default approval policy expands authority unexpectedly | Separate approval and sandbox/access controls; retain external policies; expose exact native effects; discuss D05 alternative |
| Reconnect loses transient content or requests | Host replay plus native repair; authoritative finals; explicit gaps; pending-request snapshots; no fabricated completion |
| Local schema/app replacement strands v1 users | Idempotent migration, untouched legacy data until confirmed, signed upgrade testing, documented legacy download/rollback limits |
| Notification promises exceed OS facilities | Host attention truth, channel-specific support labels, Android timeout handling, Web Push, native iOS sender gate |
| Host file/terminal services bypass harness restrictions | Distinct user-authorized host facilities, scoped roots, provenance, and separate permission model |
| Packaging introduces native dependency failures | Early ARM64/macOS/Windows spikes; optional PTY module; certified runtime and install artifacts |
| Protocol adapters become another giant provider | Bounded adapter/session interfaces, pure mappers, shared canonical reducer, independent controllers, measured complexity and review boundaries |

### 9.2 Assumptions and fallback behavior

1. **Shared Codex UDS is connectable from the selected Node runtime on Windows.**  
   The official daemon supports Windows, but runtime integration is untested here. If false, qualify the official `codex app-server proxy` path; do not replace it with a separate daemon and claim shared live sessions.

2. **OpenCode service commands work from an app-managed binary path and preserve intended TUI sharing.**  
   If false, use a qualified official install channel or user-managed installation. Do not silently replace a v1 global binary.

3. **Selected Node persistence/PTY dependencies ship on all host targets.**  
   If false, change those isolated dependencies or make PTY conditional. Do not rewrite the whole daemon in a second language merely for one optional facility.

4. **Muse SDK/CLI can be installed through a supported official channel for each host.**  
   If redistribution is not allowed or platform details remain unclear, support user-installed Muse only.

5. **Claude inactive-session resume can establish reliable ownership.**  
   If active ownership cannot be proved, disable mutating resume while ambiguous; allow historical read/fork where supported. Do not scrape internal job files as authority.

6. **Grok extensions and leader semantics match the inspected source.**  
   If handshake/version qualification fails, expose the verified ACP subset and hide the affected extensions.

7. **`dsh` remains limited to the documented ACP surface.**  
   If unchanged, it does not graduate into ordinary full-client support. Do not integrate its internal Web API to manufacture parity.

8. **Native iOS closed-app push is not mandatory for initial release acceptance.**  
   If it is mandatory, sender authorization and infrastructure become a prerequisite decision; the current no-relay networking choice alone is insufficient.

### 9.3 Unresolved verification register

Before implementation commitments, resolve:

- Universal gateway versus optional direct OpenCode product priority.
- D05 approval semantics and whether native OpenCode deny-overriding wildcard is acceptable.
- Exact certified Codex daemon schema/version; do not rely only on CLI 0.159.3-generated types.
- Native external-session ownership for Claude, Pi, Muse, and Grok.
- macOS host installation/distribution model.
- Native iOS signing and notification distribution.
- Muse proprietary-binary installation/redistribution terms.
- OpenCode experimental file write and durable log qualification.
- PDF behavior per model/harness.
- SDK credential sharing on macOS without credential collection.
- Exact persistence/runtime/PTY package versions.
- A tested same-ID Android legacy-return procedure.

No unresolved item authorizes protocol invention. A chosen workaround that intentionally changes native semantics needs a documented ADR exception.

### 9.4 Source references

The following references were used. Local research is a **2026-10-02 snapshot**; source verification and runtime qualification are different claims.

**[V1] Existing CodeWalk inventory and implementation**

- `plan/00-codewalk-v1-inventory.md:20–185`, architecture, persistence, platforms, dependencies.
- `plan/00-codewalk-v1-inventory.md:248–414`, feature inventory and 25 workarounds.
- `plan/00-codewalk-v1-inventory.md:452–512`, candidate seams and wire leakage.
- `plan/01-codewalk-v1-opencode-contract.md:9–25`, current transport/admission/reconciliation.
- `lib/data/datasources/chat_remote_datasource.dart:20–95`, v1-shaped data contract.
- `lib/domain/repositories/chat_repository.dart:9–95`, repository coupling.
- `lib/presentation/services/local_opencode_server_runtime_types.dart:1–30`, runtime interface.
- `BEHAVIOR.md:1815–1935`, prompts/tasks; `2887–2965`, reconciliation and child navigation.
- `ADR.md:1103–1255`, ADR-023; `1593–1635`, quotas; `1889–1910`, proxy auth; `2587–2636`, file-operation exception.
- `pubspec.yaml:19`, current version; `Makefile:244–294`, checks; platform/release sections and `.github/workflows/`.
- `macos/Runner/Release.entitlements`, current App Sandbox entitlement.

**[O-API] OpenCode HTTP, auth, installation**

- `plan/11-opencode-v2-server-api.md:9–106`, pins, transport/auth/location.
- `plan/11-opencode-v2-server-api.md:764–903`, session lifecycle.
- `plan/11-opencode-v2-server-api.md:972–1000`, prompt admission/idempotency.
- `plan/11-opencode-v2-server-api.md:1198–1232`, revert stages.
- `plan/opencode-v2-src/server/auth.ts:16–65`, token lifetime and password revocation.
- `plan/opencode-v2-src/server/pairing.ts:7–31`, one-use pairing.
- `plan/opencode-v2-src/protocol-groups/fs.ts:75–89`, experimental write contract.
- Official [OpenCode v2 documentation](https://opencode.ai/v2/docs/), [migration guide](https://opencode.ai/v2/docs/migrate-v1/), and [v2.0.21 source](https://github.com/anomalyco/opencode/tree/v2.0.21).

**[O-EVENT] OpenCode events, reducer, children**

- `plan/12-opencode-v2-events-and-schemas.md:9–54`, SSE and durable log.
- `plan/12-opencode-v2-events-and-schemas.md:425–542`, reduction, execution, errors.
- `plan/12-opencode-v2-events-and-schemas.md:726–745`, todo absence and session model.
- `plan/12-opencode-v2-events-and-schemas.md:946–1005`, children/background/cancellation.
- `plan/opencode-v2-src/server/handlers_event.ts:9–38`, framing/heartbeat.
- `plan/opencode-v2-src/server/event-feed.ts:8–79`, overflow behavior.
- `plan/opencode-v2-src/client-solid-data.reference-reducer.ts:593–640`, hydration protections and race.
- Same reducer at `749–789`, inbox lifecycle.
- `plan/opencode-v2-src/schema/form.ts:18–174`, typed form semantics.
- Official [reference reducer](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/client/src/solid/data.ts).

**[O-PERM] OpenCode permissions**

- `plan/12-opencode-v2-events-and-schemas.md:544–638`.
- `plan/opencode-v2-src/core/permission.ts:87–99`, last-match rules.
- Same file at `148–178`, native rules and project-saved grants.
- Same file at `299–322`, persistent `always` behavior.
- Official [permission implementation](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/core/src/permission.ts).

**[C-DAEMON] Codex shared service**

- `plan/20-codex.md:24–131`, surfaces, shared daemon, multi-client behavior.
- `plan/20-codex.md:460–546`, network, install, authentication-policy context.
- `plan/codex-src/app-server-daemon-README.md:12–29`, Windows and environment behavior; `44–75`, versions/updating.
- Official [daemon source](https://github.com/openai/codex/tree/rust-v0.160.0/codex-rs/app-server-daemon) and [app-server documentation](https://learn.chatgpt.com/docs/app-server).

**[C-PROTOCOL] Codex capabilities**

- `plan/20-codex.md:170–264`, thread/turn behavior.
- `plan/20-codex.md:313–452`, approvals, usage, skills, rewind, children, files/terminal.
- `plan/20-codex.md:597–632`, version gaps.
- `plan/codex-src/key-types.ts:1–57`, initialization; later pinned generated method types.
- Official [protocol source](https://github.com/openai/codex/tree/rust-v0.160.0/codex-rs/app-server-protocol).

**[CC-SDK] Claude**

- `plan/21-claude-code.md:19–92`, surfaces and host pattern.
- `plan/21-claude-code.md:317–408`, permissions, sessions, tasks, commands, usage.
- `plan/21-claude-code.md:427–474`, install/auth and policy evidence.
- `plan/21-claude-code.md:522–551`, unverified behavior and pitfalls.
- `plan/claude-code-src/agent-sdk-0.3.287-key-types-with-docs.d.ts:1914–1935`, public interrupt/mode interface.
- Same file at `2043–2067`, reinitialization; `2753–2796`, permission options.
- Official [Agent SDK documentation](https://code.claude.com/docs/en/agent-sdk/overview) and [legal/authentication guidance](https://code.claude.com/docs/en/legal-and-compliance).

**[PI] Pi**

- `plan/22-pi.md:8–182`, official RPC, lifecycle, extension UI, security.
- `plan/22-pi.md:182–242`, history and capabilities.
- `plan/harness-src/pi/rpc-types.ts:20–76`, native commands.
- Official [Pi repository](https://github.com/earendil-works/pi) and [documentation](https://pi.dev/docs/latest).

**[MSP] Muse**

- `plan/23-muse-code.md:8–124`, versions, transports, cursors, methods.
- `plan/23-muse-code.md:214–264`, capability limits.
- `plan/harness-src/muse/msp-v1-stable.d.ts:1464–1528`, resume and policy/selection outcomes.
- `plan/harness-src/muse/msp-stable-manifest.json`, inspected fingerprint.
- `plan/harness-src/muse/transcripts/README.md:1–13`, fixture provenance.
- Official [Muse SDK repository](https://github.com/meta-models/muse-code-sdk) and [MSP documentation](https://meta-models.github.io/muse-code-sdk/next/guides/msp-wire/).

**[GROK] Grok**

- `plan/24-grok-build.md:8–122`, transport/auth/ACP/extensions.
- Same dossier at `129–138`, storage and conversation-only rewind.
- Official [Grok Build source](https://github.com/xai-org/grok-build); agent-mode source pin recorded as `2bdd1d6a…` in the ACP dossier.

**[DSH] DeepSeek Harness**

- `plan/25-deepseek-dsh.md`, preview and surface limitations.
- `plan/harness-src/dsh/dsh-acp-README.md:60–76`, list/resume without history replay.
- Same file at `88–113`, committed updates and ownership/teardown.
- Official [DeepSeek Harness repository](https://github.com/deepseek-ai/deepseek-harness).

**[ACP] Common protocol**

- `plan/30-acp-and-unifying-protocols.md:17–66`, stable/draft distinctions.
- Same dossier at `80–94`, SDK/version evidence including Dart.
- Same dossier at `95–211`, transports and method distinctions.
- `plan/acp-src/rfds/streamable-http-websocket-transport.mdx`.
- Official [ACP protocol](https://agentclientprotocol.com/) and [schema repository](https://github.com/agentclientprotocol/agent-client-protocol).

**[COMMUNITY] Required secondary reference**

- `plan/31-multi-harness-clients.md:73–198`, OpenChamber at `fc012ae0029fa2ac8d1d52b4af37040fc536258e`.
- Same dossier at `946–1015`, comparative patterns.
- [OpenChamber](https://github.com/openchamber/openchamber) demonstrates projection seams, bounded replay, and host attention patterns. Its extensions do not redefine OpenCode’s official contract.

### 9.5 Execution start

The first implementation action should establish the contract and preservation boundary, not start moving the entire UI.

Within the first two minutes of an authorized implementation session:

```bash
source ~/paths
rtk git status --short
rtk git log -1 --oneline
rg -n 'ADR-023|EXC-001|ADR-029|ADR-043' ADR.md
rg -n 'session.prompt|experimental.fs.write|session.log' \
  plan/opencode-v2-src/protocol-groups
```

Then:

1. Confirm the final D01/D05/D07/D15 direction and external-session acceptance wording.
2. Preserve the v1 revision and define the new host/client protocol fixtures.
3. Run prerequisite spikes A–D before selecting permanent packaging dependencies.
4. Start `host/src/adapters/opencode_v2/` and the new session domain/controller as one complete vertical slice.
5. Validate and review that slice before porting the remaining chat surfaces.

The immediate next action is to settle the gateway and approval semantics from this plan; the first code milestone is **pair → select project → continue a TUI-created OpenCode v2 session → disconnect → recover without duplicate input**.