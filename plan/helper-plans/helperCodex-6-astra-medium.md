# CodeWalk v2 implementation plan

## 1. Recommendation and status

Build a new Flutter client skeleton in this repository, with **OpenCode v2 as the first complete adapter**, and a **TypeScript/Node host bridge for protocols that need host execution or shared-daemon access**.

Use native protocols for OpenCode, Codex, Claude Code, Pi, and Muse. Use ACP v1 with explicit Grok extensions for Grok Build; keep DeepSeek Harness experimental until its public protocol can deliver the required session experience.

The client should support two connection types:

1. **Direct OpenCode v2:** connect to an existing official service without requiring another daemon.
2. **CodeWalk host:** connect to an authenticated host bridge that attaches to official services, supervises SDK/stdio harnesses, and supplies explicitly identified host facilities.

These are deployment choices behind the same client domain interfaces. Other harnesses must not impersonate the OpenCode API.

The bridge should be optional for OpenCode chat, but required for Claude, Pi, Muse, and `dsh`, and the preferred remote transport for the **shared Codex daemon**. Prefer the bridge for Grok too, avoiding a second browser-specific authentication and transport implementation.

### Intended final behavior

Users select a host and project, see sessions grouped across enabled harnesses, and continue supported external sessions. Chat presents text, reasoning, tools, requests, execution state, and background work coherently while preserving upstream semantics.

Capabilities are explicit:

- “Continue saved conversation” is different from “Control running session.”
- “Rewind conversation” is different from “Restore files.”
- “Approve requests automatically” is different from “Disable sandbox.”
- “Known token usage” is different from “Remaining account quota.”
- “Observed task finished” is different from “All descendant work finished.”

Unsupported actions are absent or disabled with a short reason. Unknown protocol items remain inspectable instead of being converted into invented text or completion events.

### Evidence and blockers

This plan is based on the supplied research snapshot and selected raw sources, not new live harness sessions. Important inspected evidence includes:

- OpenCode event handler and reference reducer.
- OpenCode prompt preparation and permission evaluation.
- Codex generated turn, sandbox, rate-limit, and conversation-revert types.
- Muse command/cursor/approval types.
- Current CodeWalk inventory, behavior documentation, ADR-023, and validation targets.

**No blocker prevents beginning the rewrite and contract spikes.** Three requirements need qualified acceptance:

1. **Claude external sessions:** saved-history discovery and resume are available; arbitrary live TUI attachment is not established by the official SDK.
2. **Background iOS notifications:** dependable delivery while suspended requires an authorized push delivery path. A direct LAN/VPN connection alone does not provide this.
3. **DeepSeek external history:** ACP resume explicitly does not replay historical updates. It cannot currently satisfy full external-session continuity.

These limitations must remain visible in release criteria.

---

## 2. Decision assessment

Confidence describes the evidence supporting this recommendation, not a guarantee about future releases.

| Decision | Verdict | Evidence and argument | Concrete alternative and tradeoff | Confidence / verification |
|---|---|---|---|---|
| **D01: connection architecture** | **Unresolved; recommend hybrid** | OpenCode has a usable authenticated HTTP service. Codex shared state lives behind a local owner-only socket. Claude/Pi/Muse require host execution. Universal direct connectivity is therefore infeasible. | Require a universal bridge for every connection: simpler transport/support matrix, but another installation prerequisite for existing OpenCode users. Hybrid preserves direct OpenCode while adding one bridge for richer deployments. | High architectural confidence. Verify direct Web authentication and shared Codex attachment before fixing transport contracts. |
| **D02: rollout** | **Unresolved; recommend capability-gated phases** | OpenCode is mandatory; Codex and Claude expose significant differences that should shape the domain before it hardens. Seven simultaneous production integrations would multiply unknowns. | Initial production release with OpenCode complete, Codex/Claude preview only when their gates pass; subsequent stable promotions for Codex/Claude, then Pi/Muse/Grok. `dsh` remains experimental. | High. Stage exits below determine release membership rather than predetermined minor-version numbers. |
| **D03: new skeleton, same repository** | **Keep** | Inventory reports large coupled provider/page classes and protocol interpretation in presentation. Incremental compatibility scaffolding would preserve much of the problem. | Extract adapters into the current provider incrementally: smaller initial patch, substantially greater risk of retaining v1 reconciliation behavior. | High. Preserve a v1 maintenance reference before source removal; reuse only components with explicit boundaries. |
| **D04: same app ID, replace v1** | **Keep, with migration requirements** | Product preference is feasible, but old server profiles and persisted wire caches cannot simply become v2 data. Android downgrade and signature rules complicate “manual legacy download.” | Separate v2 app ID permits side-by-side operation but changes the selected product direction. | High for migration need. Test upgrade with actual signed v1/v2 artifacts and representative stores. |
| **D05: allow-all ON** | **Change recommended; baseline remains ON** | OpenCode wildcard session rules can override agent denies and propagate to children. Claude, Codex, Grok, and Pi have materially different policy models. A universal “safe allow-all” does not exist. | Prefer default Ask, or retain automatic approval but preserve native denies and require a separate explicit action for broad native bypass. This changes onboarding and unattended behavior. | High for semantic mismatch. Test precedence and policy restoration per adapter. |
| **D06: native usage plus experimental host queries** | **Keep, narrow the experimental surface** | Native Codex, Claude, and Muse signals are available; OpenCode lacks a general quota API. Existing v1 quota implementation reads credentials and may refresh tokens. | Native-only is simpler and safer operationally but offers less provider coverage. | High. Experimental connectors must be independently reviewed, host-only, opt-in, and must not refresh or forward vendor OAuth credentials. |
| **D07: notifications** | **Unresolved; recommend foreground/local first, optional host push** | One host event pipeline can reliably identify attention events. Client background execution differs by platform. No hosted relay is selected. | User-operated notification endpoint or external notification service integration; dedicated CodeWalk APNs delivery would require an additional product/infrastructure decision. | High for limitation; medium for chosen deployment. Device prototypes and platform policy verification required. |
| **D08: user-managed networking** | **Keep** | Compatible with direct OpenCode and an authenticated bridge. Avoids imposing relay operation. | Hosted relay simplifies mobile reachability but contradicts the chosen direction and increases operational responsibility. | High. Test LAN, VPN, SSH forwarding, and TLS proxy separately. |
| **D09: six client targets** | **Keep** | Flutter can share UI, but current managed runtime, transport, voice, terminal, and notification services have platform gaps. | Removing Web/iOS reduces work but discards explicit product requirements. Instead publish per-platform facility support. | Medium. Browser auth, iOS signing/background operation, and native plugin audit are release gates. |
| **D10: official binary + SHA-256 + service** | **Keep** | OpenCode v2 documents service installation, pairing, port 49374, and binary checksums. Current managed installer uses v1 assumptions. | Package-manager-only installation reduces installer code but loses predictable version selection and checksum handling. | High. Verify service configuration and Windows architecture coverage against the chosen release. |
| **D11: desktop installs bridge/harnesses** | **Keep, distinguish managed from external** | SDK/stdio harnesses need host dependencies and supervision. Existing user installations must remain user-owned. | Ship every harness bundled: simpler first run, larger artifacts and more update/licensing complexity. | High. Validate official channels per supported host OS; unsupported architectures get remote-connect mode. |
| **D12: English plan** | **Keep** | Explicit delivery preference. | None needed. | High; editorial verification only. |
| **D13: external sessions** | **Keep as a capability-specific essential requirement** | OpenCode and Codex support shared sessions. Claude exposes history APIs but not a general third-party live attach API. Pi/Muse require ownership verification; `dsh` lacks history replay. | Promise saved-history continuation everywhere and live control only where proven. If live control is mandatory for every harness, several integrations must remain unreleased. | High for distinction; medium for individual ownership details. Run two-client and external-TUI tests. |
| **D14: unified sessions** | **Keep** | Host/project/harness identity is sufficient for coherent grouping without flattening capabilities. | Separate harness applications avoid normalization but fragment the selected experience. | High. Test ID collisions, nested sessions, moved projects, and multiple installations. |
| **D15: daemon language** | **Unresolved; recommend TypeScript on supported Node LTS** | Claude’s official TypeScript SDK avoids reproducing a large changing control protocol. Pi has official TS facilities; JSON/ACP/MSP integration is straightforward. | Dart AOT provides one language but requires raw Claude protocol work or a TS sidecar. Go/Rust simplify native distribution but retain that dependency problem. Bun can be evaluated later rather than made a first-release requirement. | Medium-high. Validate SDK, SQLite, PTY, subprocess, and packaging behavior on all host targets. |
| **D16: planning process** | **Process-only** | Scheduling and preservation requirements concern evidence collection, not product architecture. | None proposed. | No technical inference should depend on scheduling or number of agreeing assessments. |

### Changes recommended for reconsideration

1. **D05:** Prefer Ask by default, or a narrower automatic-approval mode that preserves native denies. If the selected ON baseline remains, display its actual effective scope and keep sandbox settings separate.
2. **D13:** Explicitly accept “resume saved history” for Claude external sessions until live control is officially supported. Do not manufacture a live attach promise.
3. **D07/D08:** Accept that native iOS alerts while suspended need an additional push arrangement; otherwise describe notifications as foreground/best-effort background.
4. **D04:** Document that returning to legacy v1 may require export, uninstall, and reinstall; a lower-version APK is not a normal in-place downgrade.

The baseline implementation below retains the selected choices while exposing these consequences.

---

## 3. Harness capability matrix

Legend:

- **N:** native selected protocol.
- **B:** explicit CodeWalk host facility.
- **X:** vendor/community extension.
- **E:** experimental or version-gated.
- **—:** unavailable through the selected integration.
- **?:** insufficient evidence; requires a spike.

### Integration and lifecycle

| Harness / pinned evidence | Surface and transport | External sessions | List/create/resume/fork/archive/delete |
|---|---|---|---|
| **OpenCode 2.0.21 `8a8bd622`; 2.0.22 differences recorded** | **N** `/api/*`, Basic auth, global SSE; direct or bridge | **N** shared per-user service. Discover native sessions and observe running work. | **N** list/create/read/resume/fork/delete. **B/local** archive: inspected PATCH lacks archive field. Delete includes descendants. |
| **Codex CLI 0.159.3 schema; daemon 0.160.0** | **N/E** app-server v2 over shared daemon UDS WebSocket; bridge or SSH proxy | **N/E** running TUI threads can be rejoined. Separate WS app-server must not be substituted for shared daemon. | **N** list/start/resume/read/fork/archive/unarchive/delete, subject to method and live-worker restrictions. |
| **Claude SDK 0.3.287 / CLI 2.1.287** | **N** TS SDK hosted by bridge; one long-lived query per active session | **N** history discovery/read/resume. **—/?** arbitrary live TUI control. Background state discovery is not live SDK ownership. | **N** list/create/resume/fork/rename/delete. **B/local** archive. Avoid concurrent writers to the same transcript. |
| **Pi 1.0** | **N** RPC JSONL stdio, supervised by bridge | Saved sessions can be switched/resumed; enumeration via documented SDK/session manager, **not** nonexistent RPC `list_sessions`. Live external TUI attachment **?**. | **N** new/switch/fork/clone/name/history. **B** discovery through official SDK. **B/local** archive. Native deletion **—** in RPC. |
| **Muse 1.4.2 / MSP v1** | **N** `muse serve` stdio behind bridge; fingerprinted schema | **N** list/read/resume; lease errors mean ownership must be respected. Concurrent TUI/live sharing **?**. | **N** list/start/resume/read/fork/rename/delete; **B/local** archive unless a negotiated native facility exists. |
| **Grok Build 1.0.46** | **N** ACP WS; **X** `x.ai/*`; bridge preferred | Session load and persistent server state; external leader/session adoption **?** until tested. | **N/X** session discovery/load; extension-backed fork/rename/delete. Archive **?**, otherwise local. |
| **DeepSeek `dsh` 0.2.0-rc.2** | **N/E** ACP stdio via bridge | **N** list/resume inactive roots, **—** transcript replay. Does not meet complete external continuity. | **N/E** new/list/resume/close. **—** load/fork/delete/rename in selected ACP surface. Local hide is not upstream archive/delete. |

### Conversation and interaction

| Harness | Streaming/tools | Approval and allow-all | Questions/forms | Mid-turn and interruption | Tasks/subagents |
|---|---|---|---|---|---|
| **OpenCode** | **N** flat messages; started/delta/ended text/reasoning/tool input; terminal content authoritative | **N** ordered rules; `once/always/reject`; `always` project-wide. Wildcard session allow can override deny and be inherited. | **N** forms; preserve field IDs and required answers | **N** steer/queue, inbox edit/cancel, interrupt, detach/background | **N** child sessions and background shells; no native todo endpoint. Nested-background completion bug requires caution. |
| **Codex** | **N** turns/items, reasoning, command output, structured diffs | **N** approval policy and requests; sandbox independently configured | **N** user-input requests; richer forms depend on negotiated APIs | **N** steer with active-turn precondition, interrupt; **E** durable queue/settings | **N** child threads and plan updates; advanced queue/goals vary by version |
| **Claude** | **N** partial text/thinking, tool blocks/results, result events | **N** permission modes/callbacks; bypass requires startup enablement and may be disallowed. Never auto-answer human questions. | **N** AskUserQuestion, dialogs, MCP elicitation | **N** queued/folded input and priority input; interrupt receipts; queued-message removal lacks ordinary SDK method | **N** background task snapshots/events, child transcripts; task tools model-dependent |
| **Pi** | **N** deltas and tools; completion is `agent_settled`, not `agent_end` | **—** base permission system; no meaningful approval toggle | **X/N transport** extension UI requests; not a universal form contract | **N** steer/follow-up/abort/clear queue | **—** base task/subagent system; extension-specific data only |
| **Muse** | **N** revisions, text/reasoning/output deltas and output references | **N** staged approvals; native allowAll subject to policy | **N** user-input requests | **N** queue/steer/replace, interrupt/retract, cancel/unqueue | **N** tasks, subagents, workflows, todos/goals |
| **Grok** | **N** ACP stream/tools/plans; **X** supplementary events | **N/X** permissions and YOLO; native denies/hooks still apply; sandbox separate | **X** `x.ai/ask_user_question` | **N** cancel; **X** interject and queue management | **X** subagents/background controls; native ACP plans |
| **dsh** | **N/E** committed chunks and generic tools; do not advertise token streaming | **N** one-shot requests; **B** auto-answer eligible requests. Native `never` means reject, not allow-all. | **—** ACP elicitation | **N** cancel; **—** steer/queue | Internal features exist but **—** structured ACP exposure |

### Workspace, selection, usage, and history operations

| Harness | Files/terminal | Attachments | Commands, skills, mentions | Model/agent/effort | Usage and rewind |
|---|---|---|---|---|---|
| **OpenCode** | **N** list/find/read, PTY; **B** writes/content search | **N** file/data URIs, images/PDF subject to model; 20 MiB native per-file limit | **N** commands, skill catalog and prompt attachments, structured agent mentions; no v1 symbol search replacement assumed | **N** session agent/model selections; variants from model contract | **N** tokens/cost/context; no general quota. **N** staged revert/clear/commit, optional file restoration |
| **Codex** | **N** filesystem/search/PT Y APIs; PTY lifetime tied to connection | **N** image inputs; use data URLs remotely. PDF support **?** by method/model | **N** skills; no server slash registry. Client commands are separate; typed file/context inputs | **N** model/effort; no universal OpenCode-style agent selector | **N** tokens/rate-limit windows. No file undo; `thread/revert` is conversation-only and restricted to paginated threads |
| **Claude** | **N** permission-aware file read; **B** browsing/search/writes/PTY/git | **N** supported SDK content blocks; PDF path must be verified against selected API/model | **N** commands/skills, terminal-only commands excluded; mentions resolved as supported context | **N** model/effort/agent settings, negotiated runtime changes | **N/E** usage/rate-limit signals and experimental pull. File checkpoints omit Bash/subagent edits; no general redo |
| **Pi** | **N** one-shot bash, not PTY; **B** files/search/PTY | **N** images; PDF native support **—/?** | **N** extension commands/templates/skills; built-in TUI commands not returned | **N** model/thinking levels; **—** base agents | **N** token/cost/context stats; conversation tree/fork is not file undo; quotas **—** |
| **Muse** | **B** browse/search/files; **N** capability-gated user shell, not automatically equivalent to persistent PTY | **N** images; PDF **?** | **N** typed skills; text `@path`; built-in TUI slash commands not generally exposed | **N** model/effort; agent selector **?** | **N** quota windows, tokens/context/partial cost; fork/retract are not full file rewind |
| **Grok** | **X** filesystem/search/git/terminal APIs | **N/X** image blocks; advertise after probe because capability declaration may lag; PDF **?** | **N/X** commands/skills/fuzzy search/resource mentions | **N/X** model/effort/modes; profile selection scope-specific | **N/X** usage; billing shape **?**. Rewind conversation only, not files |
| **dsh** | **B** optional files; **—** ACP terminal/client filesystem | **N/E** images only when store and route support them; resource links partial | **—** commands/skills; resource-link mentions do not imply file fetching | **N** model/effort config; no modes | Partial context usage; no quota/cost contract or undo |

**Notifications are client/host facilities for all seven harnesses.** Upstream events supply evidence; none of these integrations establishes universal mobile push delivery.

Source bases: `plan/11-opencode-v2-server-api.md:764–1266`, `plan/20-codex.md:19–33` and protocol sections, `plan/21-claude-code.md:319–409`, `plan/22-pi.md:64–110`, `plan/23-muse-code.md:214–260`, `plan/24-grok-build.md:120–176`, and `plan/25-deepseek-dsh.md` §§3–4.

---

## 4. Architecture and concrete interfaces

### 4.1 Layout

Retain Flutter and existing localization assets. Introduce bounded feature modules rather than another application-wide chat provider.

```text
lib/
  app/
    bootstrap.dart
    router.dart
    service_registry.dart
  core/
    identity/
    storage/
    security/
    platform/
    diagnostics/
  harness/
    domain/
      identity.dart
      capabilities.dart
      session.dart
      timeline_item.dart
      events.dart
      commands.dart
      requests.dart
      usage.dart
      execution.dart
    ports/
      harness_connection.dart
      workspace_access.dart
      installation_manager.dart
      attention_delivery.dart
    adapters/
      opencode_v2/
        transport.dart
        wire/
        decoder.dart
        projection.dart
        capabilities.dart
      codewalk_host/
        transport.dart
        wire/
        decoder.dart
  features/
    hosts/
    projects/
    sessions/
    chat/
      chat_controller.dart
      session_reducer.dart
      timeline_controller.dart
      composer_controller.dart
      widgets/
    requests/
    background_work/
    files/
    terminal/
    usage/
    attention/
    settings/
  local_features/
    drafts/
    tabs/
    exports/
    voice/
    shortcuts/
  l10n/

host/
  src/
    main.ts
    server/
      auth.ts
      pairing.ts
      websocket.ts
      commands.ts
    runtime/
      process_supervisor.ts
      installations.ts
      session_registry.ts
      command_journal.ts
    adapters/
      opencode/
      codex/
      claude/
      pi/
      muse/
      acp/
      grok/
    state/
      event_log.ts
      projections.ts
      retention.ts
    workspace/
      files.ts
      search.ts
      terminal.ts
    attention/
      dispatcher.ts
      deliveries.ts
    usage/
      native.ts
      experimental/
  protocol/
    schema/
    fixtures/
```

Avoid a general plugin runtime in the first release. Adapters are compiled, registered implementations. ACP support is another adapter, not the product’s domain model.

### 4.2 Boundaries

- **Widgets:** consume domain view models; no Dio, raw method names, or vendor tool-name matching.
- **Controllers:** coordinate user intent and subscriptions; no protocol decoding.
- **Adapters:** own wire decoding, capability discovery, command translation, and upstream-specific reconciliation.
- **Reducers:** deterministic application of domain events.
- **Transport:** bytes, authentication, framing, connection state, and backpressure.
- **Host services:** independently named facilities, never silently passed off as upstream features.

Keep `provider` and `get_it` initially. Replacing state-management packages is not required to remove architectural coupling.

### 4.3 Identity

```ts
type SessionKey = {
  hostId: string;
  installationId: string;
  harness: HarnessId;
  upstreamSessionId: string;
};

type ProjectRef = {
  hostId: string;
  installationId: string;
  upstreamProjectId?: string;
  canonicalDirectory: string;
  workspaceId?: string;
};
```

`hostId` is a persisted profile/bridge identity, not just a URL. `installationId` distinguishes separate homes or configurations on one host. Native paths remain host-native; do not lowercase Linux paths or compare Windows paths using Linux rules.

Project grouping is an index, not session identity. Moving a session between directories must not create a duplicate.

For direct and bridged access to the same OpenCode service, establish an explicit alias binding after identity verification; URL similarity is insufficient.

### 4.4 Capabilities

```ts
type Capability = {
  state: "available" | "unavailable" | "experimental" | "unknown";
  implementation: "native" | "host" | "extension" | "local";
  reason?: string;
  constraints?: Record<string, unknown>;
};

interface CapabilitySet {
  revision: string;
  features: Record<CapabilityName, Capability>;
}
```

Capability calculation intersects:

1. Pinned adapter support.
2. Actual connected version and negotiation.
3. Authentication/account availability.
4. Host OS and installed facilities.
5. Session ownership/state.
6. Selected model modalities.
7. Administrator restrictions.

A method’s presence in a schema is not enough. For example, OpenCode’s declared `session.status` does not establish publication, and Codex queue requires experimental opt-in.

Expose structured distinctions such as:

```text
history.read
history.resume
session.attachLive
session.fork
conversation.rewind
files.restoreCheckpoint
input.steer
input.queueNative
input.cancelQueued
approval.autoReply
approval.nativeBypass
terminal.persistent
```

### 4.5 Commands and event envelope

```ts
interface HarnessConnection {
  capabilities(): Promise<CapabilitySet>;
  listSessions(query: SessionQuery): Promise<Page<SessionSummary>>;
  readSession(key: SessionKey, cursor?: string): Promise<SessionSnapshot>;
  execute(command: HarnessCommand): Promise<CommandReceipt>;
  events(): AsyncIterable<DomainEvent>;
  close(): Promise<void>;
}

type CommandReceipt = {
  commandId: string;
  state: "accepted" | "rejected" | "unknown";
  upstreamReference?: string;
  error?: HarnessError;
};

type DomainEvent = {
  schemaVersion: number;
  hostEpoch: string;
  sequence?: number;             // CodeWalk host ordering only
  session?: SessionKey;
  source: {
    harness: HarnessId;
    runtimeVersion?: string;
    eventType: string;
    eventId?: string;
    durableSequence?: number;
    durableAggregate?: string;
    nativeCursor?: string;
  };
  receivedAt: string;
  occurredAt?: string;
  payload: DomainEventPayload;
};
```

Use a small canonical union:

- Session metadata/capability updates.
- Execution updates.
- Timeline item upsert/remove/delta.
- Input admission/delivery/cancellation.
- Permission/form request and resolution.
- Background-work updates.
- Usage updates.
- Connection gap/reconciliation status.
- Structured error.
- Unknown upstream item.

Do not force one timestamp or sequence to represent all upstream ordering domains.

Raw provenance should identify the original type, runtime version, and relevant IDs. Retain bounded redacted raw payloads for diagnostics; do not persist all tool output twice indefinitely.

### 4.6 Timeline, tasks, usage, and errors

Timeline items have stable identity, revision where supplied, parent/turn linkage, content blocks, status, and source. Tool output can reference a paged blob rather than reside entirely in widget state.

Background work is distinct from agent plans:

```ts
type WorkItem = {
  id: string;
  session: SessionKey;
  kind: "subagent" | "shell" | "workflow" | "unknown";
  parentWorkId?: string;
  childSession?: SessionKey;
  state: "queued" | "running" | "waiting" | "completed" |
         "failed" | "cancelled" | "unknown";
  completionScope: "self" | "descendants" | "unspecified";
};

type Usage = {
  scope: "turn" | "session" | "account" | "model";
  tokens?: TokenCounts;
  context?: { used: number; limit?: number; basis: string };
  cost?: { amount: number; currency: string; partial: boolean };
  quotaWindows?: QuotaWindow[];
  observedAt: string;
  source: "native" | "experimentalConnector";
};
```

Unknown values are `null`/absent, never zero. Preserve whether totals are cumulative, per-turn, estimated, cached, or partial.

Errors include category, native code, retryability, suggested user action, affected operation, and retry timing. Distinguish transport loss, auth expiry, version incompatibility, provider rate limit, denied permission, invalid attachment, process death, and ordinary tool failure.

### 4.7 Execution state

Do not combine connectivity and execution:

```text
Connection: disconnected → connecting → authenticating → synchronizing → ready
                                    ↘ incompatible / authenticationRequired

Execution: unknown | idle | running | waitingForApproval | waitingForInput
           | retryScheduled | interrupting | interrupted | failed
```

Track pending requests and background work alongside execution. Parent idle does not imply children idle.

For OpenCode, port the official reducer’s semantics. The inspected reference sets activity idle on terminal execution events, but omits a normal terminal timeline marker for `reason:"shutdown"`; a shutdown interruption must not become an ordinary successful completion notification. See `client-solid-data.reference-reducer.ts:1009–1048`.

### 4.8 Ordering and recovery

**Bridge mode**

- One upstream reader per installation/protocol connection where supported.
- SQLite event log plus materialized snapshots and command journal.
- Persist durable canonical events before acknowledging replay availability.
- Client resumes by `(hostEpoch, sequence)`.
- Expired cursor returns an explicit snapshot-required response.
- Initial retention proposal: 24 hours or 64 MiB per installation, whichever comes first; pending commands/requests are retained separately.
- Large text/tool blobs have independent size/age limits.
- Compact high-frequency deltas into finalized items; never drop approvals or terminal states to relieve pressure.

**Direct OpenCode**

- One `/api/event` stream per service.
- Treat heartbeat comments as liveness.
- Connect first, then hydrate active sessions, visible history, inbox, permissions, and forms.
- Buffer events during hydration.
- Use item/event identity and durable sequence where available.
- Experimental session log catch-up remains optional and version-gated.
- Do not assume contiguous durable sequence numbers: internal events share sequence space.
- A missing text prefix after reconnect remains explicitly incomplete until authoritative `ended` content arrives.
- Do not claim atomic gap-free hydration without a proven snapshot watermark.

The raw handler confirms global live SSE and 15-second heartbeat comments. The reference reducer confirms delta append and authoritative text replacement (`handlers_event.ts:9–38`; reference reducer `:903–919`).

### 4.9 Mutation safety and multi-client operation

Persist the client command ID and exact payload before submission.

- **OpenCode prompt:** use native `msg_` idempotency identity; retry the same ID and payload only.
- **Muse:** use native UUIDv7 `commandId` and replay contract.
- **Codex:** correlation IDs are not automatically idempotency guarantees; verify individual methods.
- **Claude/Pi/ACP:** after uncertain delivery, reconcile first. If no authoritative evidence exists, show “Delivery unknown” and require deliberate resend.

A bridge command journal prevents duplicate dispatch while it remains authoritative, but cannot manufacture exactly-once delivery across a crash between upstream admission and local recording.

Approval replies use a compare-and-set pending state and upstream request identity. Muse additionally preserves requirement/stage guards. Codex resolution notifications dismiss copies on all clients. If an external client wins, report “Resolved elsewhere.”

Serialize CodeWalk mutations per session, but never claim this locks native TUI clients. Use native preconditions where available; otherwise refresh after conflicts.

For OpenCode allow-all changes, preserve the prior permission rules and detect external edits before restoring them. Do not remove rules by simply overwriting the whole ruleset from a stale cache.

---

## 5. Host runtime and connectivity

### TypeScript/Node recommendation

Use the supported Node LTS at implementation time, pinned in distribution metadata. Main dependencies should be narrowly justified:

- Official Claude Agent SDK.
- Official ACP TypeScript SDK for stable stdio behavior, version-pinned.
- WebSocket library with explicit payload/backpressure limits.
- SQLite binding selected after cross-platform packaging spike.
- PTY dependency only in the optional workspace-terminal module.
- Schema validation/generation tooling for the CodeWalk host protocol.

Do not choose a Dart ACP package solely because a dossier mentions one. The pack records multiple community packages and experimental remote transports (`plan/30-acp-and-unifying-protocols.md:89,155`). The proposed architecture needs no Dart ACP dependency initially.

### Ownership

The bridge attaches to existing OpenCode and Codex services without claiming their lifecycle.

Classify installations as:

- **External:** detected and connected; never automatically replaced or stopped.
- **Managed:** installed by CodeWalk; updates occur through its installation manager.
- **Attached shared service:** controlled by its official manager; app exit only disconnects.

Bridge-owned Claude/Pi/Muse/ACP subprocesses outlive mobile disconnects. Idle processes may be unloaded only after native settlement and absence of pending requests/background work. Start with a configurable 15-minute idle timeout and a bounded concurrency limit; never evict active work to save memory.

### Bridge authentication

Bind loopback by default. Remote use requires an explicitly configured interface/tunnel and authenticated transport.

Proposed CodeWalk pairing:

- Short-lived single-use code.
- Per-device random credential.
- Revocable device registry.
- Token hashes stored server-side.
- No credentials in logs or shareable connection URLs.

For browsers, prefer hosting the Web client on the same authenticated bridge origin with secure HttpOnly cookies and CSRF/Origin validation. Alternatively mint a short-lived, single-use WS ticket over authenticated HTTPS. Browser WS cannot be designed around arbitrary `Authorization` headers.

Reject unknown origins. Do not “fix” Codex’s Origin rejection by exposing its unauthenticated local socket publicly.

---

## 6. User experience

### Onboarding and installation

Desktop onboarding offers:

1. Connect an existing host.
2. Set up a managed local host.
3. Connect directly to OpenCode v2.

Android/iOS/Web connect to a host; they do not install harness processes locally.

For managed OpenCode:

- Detect an existing service before configuring anything.
- Download a selected official v2 binary and required checksum.
- Verify before activation; fail closed on mismatch.
- Keep the prior managed binary until post-update health verification succeeds.
- Use the official service manager and pairing flow.
- Validate `/api/info`, JSON content type, and supported major version.
- Explain v1 incompatibility; an HTML 200 from an old endpoint is not health.

Do not rotate a password or overwrite service configuration belonging to an existing external installation. “Automatic pairing” means local managed setup can obtain a pairing code through the official surface; remote users still authorize their connection.

### Unified session list and ownership

Group by host/project with harness badges, native origin, activity, unread state, and pending-request count.

Distinguish:

- Active here.
- Shared live session.
- Saved history.
- Busy in another client.
- Disconnected; state last observed at a timestamp.

For Claude, use official history functions and background state commands. If a transcript is held by another process, allow reading and offer a fork when supported. Never kill the external process or claim seamless takeover.

Use local archive/hide for harnesses without native archive and label its scope. In bridge deployments, this preference can synchronize across CodeWalk clients; direct mode remains device-local unless explicit metadata support is adopted.

### Composer

Drafts persist per full session identity and per unsent new-session draft.

The composer exposes:

- Selected harness and model.
- Agent/profile only where meaningful.
- Native variant/effort options without inventing a universal scale.
- Busy-send policy: steer or queue where supported.
- Queued admissions and cancellation only when supported.
- Pending session-setting changes.

OpenCode model/agent changes are separate session operations. Confirm their result before sending input that depends on them. Do not attach obsolete per-prompt fields.

Local `/new`, `/sessions`, and `/help` are distinct from harness commands. Autocomplete identifies origin. Discover skills through native catalogs and preserve structured invocation where supported. Never turn every skill into plain prompt text.

`@` selection creates typed references when available. When a harness accepts only textual paths, expose that behavior rather than implying attached file content.

### Attachments and workspace operations

Use a capability intersection of protocol, adapter, model, client platform, MIME type, and size.

- Preview image/PDF inputs before send.
- Resolve local-device files versus remote-host files explicitly.
- Do not silently extract a PDF to text as a substitute for native PDF support.
- Offer deliberate conversion only as a separately labeled future facility.
- Bridge uploads are scoped, size-limited, content-addressed, and cleaned after retention.
- File reads support cancellation, size caps, binary detection, and pagination.
- Host writes use expected-content hashes and atomic replacement, rejecting concurrent edits.
- Resolve symlinks and root authorization on the host.

Direct OpenCode remains read-only for file editing. The optional bridge supplies writes; no hidden shell-session mutation workaround returns.

### Background work

Show a compact work tray under the session header:

- Running children.
- Waiting requests.
- Background shells.
- Failed or completed work requiring attention.

Each item includes source identity, parent navigation, known state, and supported stop action. Parent conversations and child conversations retain separate drafts, models, and request queues.

Do not derive child identity from regexes in tool output. Unknown relationships remain unknown.

For OpenCode’s nested-background bug, display observed child state and unresolved descendants separately. Do not “repair” upstream scheduling by auto-prompting the parent or falsely marking the tree complete.

### Permission and form UI

Under the selected ON baseline:

- Global preference is the default for newly controlled sessions.
- Each session has an explicit override.
- Imported/external-session effective policy is displayed before modification.
- Native policy restrictions win.
- Forms, elicitation, and AskUserQuestion remain human input.
- Auto-approved operations appear in an audit view.

OpenCode “Always” must read **“Always allow for this project”**. Native bypass, automatic request replies, and sandbox configuration need distinct labels.

Pi displays “This harness does not provide approval prompts,” not a shield suggesting protection.

### Rewind

Use action names that match effects:

- OpenCode: preview staged boundary; optionally restore files; clear stage to undo staging; commit/new admission finalizes.
- Codex: fork or supported conversation truncation, with explicit “Files unchanged.”
- Claude: checkpoint dry-run listing coverage; warn about unsupported Bash/subagent changes; conversation branch separate.
- Muse: fork/retract according to MSP, not a fabricated filesystem rewind.
- Grok: conversation rewind only.
- Pi: conversation fork/tree history; no implied file restoration.

### App-local features

Keep drafts, tabs, pinned/recent sessions, exports, themes, accessibility, localization, shortcuts, voice input/read-aloud, and attention surfaces. Rebuild their integration around domain state.

Use mobile-first Material You:

- Compact: sessions drawer, one timeline, bottom composer and request sheet.
- Expanded: resizable session/workspace panes and optional work/usage pane.
- Keyboard navigation, focus restoration, screen-reader labels, large text, and RTL are first-class.
- Reasoning is collapsible; accessibility announcements summarize state transitions rather than every token.

Retain theme presets as visual assets, without requiring live synchronization with OpenCode’s internal frontend.

### Notifications

One `AttentionCoordinator` consumes authoritative domain transitions. Dedupe by host/session/execution/request identity.

Initial support:

- Foreground in-app attention and local notifications.
- Desktop tray notifications while running.
- Android opt-in foreground monitoring with one transport owner.
- On reconnect, surface missed attention as such rather than replaying a storm of completion notifications.

Defer dependable native iOS suspended delivery until a push route is selected. A user-hosted Web Push facility can serve supported installed Web clients after platform verification; it does not automatically solve native iOS APNs delivery.

No notification transport should include conversation content by default. A generic notification can open the authenticated session.

---

## 7. Rewrite, reuse, and migration

| Current module | Decision | Proposed destination / reason |
|---|---|---|
| `lib/presentation/providers/chat_provider.dart` and parts | **Rewrite** | Feature controllers, reducer, session repositories. Preserve behavior requirements, not the large class structure. |
| `lib/presentation/pages/chat_page.dart` and parts | **Rewrite orchestration; selectively reuse widgets** | `features/chat/`; remove wire interpretation and direct networking. |
| `lib/data/datasources/chat_remote_datasource.dart` | **Replace** | `harness/adapters/opencode_v2/`; no v1 routes or DTO compatibility layer. |
| `lib/domain/entities/` wire-shaped chat types | **Replace selectively** | Harness-neutral types plus private adapter DTOs. |
| `local_opencode_server_runtime*.dart` | **Rewrite** | Managed installation interface and service-aware implementation. |
| `chat_title_generator.dart`, auto-title provider parts | **Discard hidden-session method** | Native title behavior/manual rename initially; optional explicit title generation later. |
| `workspace_file_operations_service.dart` | **Replace** | Explicit bridge filesystem service; direct OpenCode read-only. |
| `quota_remote_datasource.dart` and script parts | **Discard embedded credential/shell workflow** | Native usage adapters plus isolated opt-in connectors. |
| `android_background_alert_worker.dart`, foreground monitor, overlay SSE | **Consolidate** | One attention pipeline; overlay is presentation, not another server consumer. |
| `codewalk_terminal_controller.dart`, terminal panel/xterm widgets | **Reuse rendering selectively; replace transport** | Native PTY adapters or host terminal service. |
| Theme, markdown/math/HTML utilities, diff parser | **Reuse after widget/security tests** | Domain-input rendering modules; unknown items remain explicit. |
| Speech/read-aloud services | **Reuse behind platform ports** | Preserve supported engines; audit native dependencies for Web/iOS. |
| Export, shortcuts, release history, settings UI | **Keep behavior, adapt interfaces** | Exports preserve harness/provenance; updater understands major migration. |
| Tabs/drafts/attention stores | **Migrate data, simplify controllers** | Full session keys and schema-versioned stores. |
| Embedded Tailscale | **Defer port pending platform audit** | System VPN and user-provided URLs satisfy networking baseline first. |
| Android Auto and overlay | **Keep as gated follow-on facilities** | Route through new input/attention services with explicit ambiguous-delivery handling. |

Remove dual SSE dedupe, full-message fetch per delta, content-based optimistic matching, idle heuristics, v1 abort string matching, child-session regex matching, hidden shell sessions, and credential-refresh quota scripts.

### Local data migration

Use a one-time, restartable migration into a separate v2 namespace:

- Preserve preferences, locale, themes, shortcuts, voice settings, canned answers.
- Retain v1 connection profiles as “Needs OpenCode v2 setup”; do not rewrite port 4096 to 49374 automatically.
- Keep legacy drafts with their original host/project/session references.
- Do not reinterpret cached v1 transcripts as authoritative v2 history.
- Import pins/tabs only after session mapping succeeds; otherwise retain a recoverable legacy list.
- Cancel obsolete Android workers and monitoring registrations during migration.
- Store bridge/OpenCode credentials in platform secure storage; browser storage needs a separate threat model.

Do not mutate the original store until migration validation succeeds. Local schema rollback does not imply upstream harness database rollback.

### Application identity and release metadata

Keep `com.verseles.codewalk`, signing identity, and platform bundle identity where applicable.

Current `pubspec.yaml:19` is `1.265.0+1790827338`. The v2 build number must exceed the installed v1 build number; resetting it to `1` breaks upgrade ordering.

Preserve a clearly labeled legacy download and maintenance branch. Manual legacy installation must explain possible downgrade/uninstall and data-export requirements.

### Documentation

Before implementing v2 semantics:

- Amend ADR-023 references and contract matrix to pinned v2 sources.
- Record architecture, ownership, migration, approval policy, and notification decisions.
- Retire superseded v1 exceptions explicitly.
- Add host and per-adapter contract documentation.
- Update `BEHAVIOR.md` only after behavior exists.
- Update `CODEBASE.md` after structural changes.
- Keep planned work in GitHub Issues; do not recreate `ROADMAP.md`.

An intentional deviation from official lifecycle or permission behavior requires an ADR exception with risk, rollback/flag, and regression tests.

---

## 8. Implementation sequence and release gates

### Stage 0 — Resolve critical assumptions

Bound each spike to a small reproducible report and fixture set.

1. **OpenCode contract spike:** pairing, v1 rejection, idempotent prompt retry, snapshot/event race, staged revert, permission precedence, child cancellation.
2. **Codex shared-daemon spike:** two clients plus TUI, live resume, pending approvals, actual daemon version detection, reconnect and terminal lifetime.
3. **Claude ownership spike:** external history discovery, active-transcript conflict, canonical session ID on resume, interrupt receipts, checkpoint coverage.
4. **Platform spike:** browser direct OpenCode auth/CORS; bridge cookies/WS tickets; iOS foreground reconnect and notification limitations.
5. **Host packaging spike:** Node runtime, SDK subprocesses, SQLite, PTY, user-service management on Linux/macOS/Windows.

**Exit:** evidence-backed capability manifests and no unresolved blocker for the initial OpenCode slice. No production architecture should depend on an unproven live-attachment assumption.

### Stage 1 — Skeleton and domain

Implement identity, capabilities, canonical events, reducers, storage migration shell, connection states, diagnostics, and mock adapters.

Build responsive sessions/chat/request screens with existing localization/themes.

**Acceptance:** no presentation networking; two mock harnesses with different capabilities work in one UI; unknown events do not crash or imply success.

### Stage 2 — Complete direct OpenCode vertical slice

Implement installation/pairing, session listing/history/create, model/agent selection, streaming, input admission, steer/queue, approvals/forms, stop, child/background work, usage, and reconnect.

Then add files read/find/list, native PTY, fork, staged revert, local archive, exports, and retained app-local features.

**Acceptance:** ordinary chat and external TUI continuity survive disconnects and app restarts without duplicate sends or invented completion.

### Stage 3 — Host bridge and Codex slice

Implement bridge authentication, durable command/event bookkeeping, process ownership, capability discovery, and remote connection lifecycle.

Attach to shared Codex daemon. Deliver session discovery/live resume, streaming, approvals, input questions, steer/interrupt, models/effort, usage, and filesystem access.

**Acceptance:** terminal-created shared threads are visible and controllable; two-client approval races resolve correctly; bridge restart does not claim ownership of or stop the shared daemon.

### Stage 4 — Claude slice

Use official SDK with explicit options and host login boundaries. Add saved-session discovery/resume, ownership restrictions, requests, task snapshots, input queue, usage, and checkpoint UI.

**Acceptance:** saved terminal history continues correctly; active unsupported ownership is clearly blocked/read-only; no claude.ai token collection or private relay dependency.

### Stage 5 — Release candidate across all selected clients

Complete migration, accessibility/localization, updater compatibility, signing/build jobs, performance and background behavior documentation.

Initial production scope:

- OpenCode v2 stable on all six selected client targets.
- Host bridge supported on verified desktop host targets.
- Codex/Claude available as previews only if their acceptance gates pass.
- Full capability reporting even for preview integrations.

If iOS distribution/signing is unavailable, call the result a limited-platform preview; do not claim the selected full-platform release is complete.

### Stage 6 — Additional harnesses

Promote independently:

- **Pi:** small native RPC integration, official session discovery, explicit lack of approvals/subagents.
- **Muse:** MSP revisions/cursors/leases/approval stages; verify distribution and platform support first.
- **Grok:** ACP base plus tested extension manifest; keep unknown extensions disabled.
- **dsh:** experimental only; reassess after history replay and interactive surfaces improve.

Release order should follow verified demand and contract readiness, not force arbitrary version milestones.

### Stage 7 — Optional facilities

Experimental vendor quota connectors, self-hosted notification delivery, richer worktree operations, advanced voice engines, Android Auto, and overlay parity.

Each has its own capability and acceptance gate; none should weaken core lifecycle correctness.

---

## 9. Validation plan

### Contract fixtures

Preserve sanitized fixtures by harness/runtime version and upstream source pin.

Required cases:

- Admission response before/after corresponding event.
- Duplicate native event, unknown enum, malformed payload, oversized output.
- Delta split inside UTF-8 code points and Pi LF-only framing.
- OpenCode authoritative `ended` replacing partial text.
- OpenCode noncontiguous durable sequence and no SSE replay.
- OpenCode nested background completion and shutdown interruption.
- Codex shared-thread join and replayed approvals.
- Codex `thread/revert` affecting conversation only.
- Claude merged input UUIDs, pending requests after reinitialize, background task snapshots.
- Pi handled command without an agent run, retries/compaction before `agent_settled`.
- Muse stale approval requirement, cursor gap, item revision, value-identical command replay.
- Grok unsupported extension, denied YOLO policy, conversation-only rewind.
- `dsh` resume without historical transcript.

### State and race tests

- Snapshot arrives after newer events.
- Session switches while requests are in flight.
- Same upstream session ID on two hosts.
- Parent idle while child runs.
- Two clients answer one permission.
- Permission policy changes externally during allow-all restoration.
- Model switch races with prompt.
- Timeout before versus after upstream admission.
- Host crash between dispatch and journal update.
- Archive/hide versus native deletion.
- External transcript is busy or moved.
- Credential expiry/revocation during stream.
- Bridge replay cursor is evicted.
- File content changes before save.
- Slow client triggers bounded resync, not unbounded memory.

### Platform tests

- Android upgrade from signed v1, notification permission, process death, battery restrictions.
- iOS real-device suspension/resume, secure storage, microphone, upload handling, signed build.
- Web fetch streaming, CORS/preflight, mixed-content rejection, Origin checks, cookie/CSRF behavior, IndexedDB migration.
- Linux/macOS/Windows install/update and external-service preservation.
- Windows paths, service subprocess termination, and unsupported harness architecture messaging.
- Screen readers, RTL, 200% text scaling, keyboard-only interaction, narrow layouts, and focus recovery.

### Initial performance budgets

These are proposed measurable targets, not observed performance:

- Ordinary chat interactions stay within a 60 Hz frame budget on the selected reference Android device.
- Batch display updates at 50–100 ms while retaining immediate approval/form delivery.
- Render an initial page of 50 timeline entries; retain a bounded visible history window.
- No history fetch per token.
- One steady-state upstream event stream per installation.
- No periodic idle session-history polling.
- Limit search concurrency to one active request per field; debounce around 250 ms and cancel superseded work.
- Large tool output must be paged and excluded from routine widget rebuilds.

### Bounded polling policy

| Need | Policy |
|---|---|
| Connection health | Use stream heartbeat; OpenCode 45-second silence watchdog is grounded in the reference behavior. Reconnect with jitter and cap, not parallel health storms. |
| External session list lacking invalidation | Refresh on focus/manual request; at most every 30 seconds while the list is visible; stop when hidden. |
| Status repair after a detected gap | Immediate authoritative refresh, then a small bounded retry sequence; show stale/unknown if recovery fails. |
| Native quota pull | On opening usage UI, cached for at least 60 seconds; honor reset and Retry-After. |
| Experimental vendor quota | Opt-in, visible-dashboard refresh no faster than five minutes; long backoff on failure; no hidden background scraping. |
| Updates | Once daily or manual check; never restart busy shared services automatically. |

### Commands and project gates

During implementation, use focused commands, sourcing the user environment and setting Flutter PATH:

```sh
source ~/paths
export PATH="$HOME/flutter/bin:$PATH"
rtk flutter analyze lib/harness lib/features/chat
rtk flutter test test/unit/harness/opencode_v2
rtk flutter test test/widget/chat
```

Proposed host checks:

```sh
rtk npm --prefix host run typecheck
rtk npm --prefix host test
```

Once code is stable:

```sh
rtk make check
rtk make test-web
```

Run platform builds on appropriate runners. For a useful Android test artifact on a supported host:

```sh
HEY_CAPTION="CodeWalk v2 connection and session lifecycle preview" rtk make android
```

Use appropriate GitHub Actions runners for release APKs rather than ARM64 Linux. Add macOS/iOS signing and Windows build gates. `make precommit` is not the normal CodeWalk validation entrypoint.

Review is required after coherent implementation stages and targeted verification. This planning-only work does not require a code-review loop.

---

## 10. Risks, fallbacks, and execution prerequisites

| Risk | Mitigation / fallback |
|---|---|
| Upstream protocol drift | Pin adapter evidence and generated fixtures; negotiate actual runtime capabilities; unknown versions enter a limited mode instead of receiving guessed mutations. |
| Codex CLI and daemon versions differ | Detect the actual daemon version; never select schema solely from `codex --version`. |
| Claude live external attachment unavailable | Read saved history, refuse competing writes, support explicit fork/resume after ownership release. |
| OpenCode nested background bug | Preserve native behavior, expose unresolved descendants, track upstream fix; no synthetic client completion. |
| Browser cannot use native transport auth | Use authenticated bridge origin/tickets; direct OpenCode only after browser contract tests. |
| Node/native module packaging fails on a host | Disable optional PTY or unsupported harness locally; retain remote client support. Do not rewrite the daemon language without measuring this blocker. |
| Unbounded event/output storage | Hard retention and byte limits, blob paging, cursor-reset snapshots, redacted diagnostics. |
| Default allow-all surprises users | Effective-policy display, audit records, separate sandbox control, inherited-child scope, restoration conflict detection. Reconsider D05 before implementation. |
| No dependable iOS push under selected topology | Explicit foreground/best-effort label until an authorized push path is selected. |
| v1 upgrade strands users | Restartable migration, legacy draft export, clear server incompatibility screen, preserved legacy download and maintenance reference. |

### Source references

Primary OpenCode sources and inspected local anchors:

- [Official OpenCode v2 documentation](https://opencode.ai/v2/docs/)
- [OpenCode pinned source](https://github.com/anomalyco/opencode/tree/v2.0.21)
- `plan/opencode-v2-src/server/handlers_event.ts:9–38`
- `plan/opencode-v2-src/client-solid-data.reference-reducer.ts:903–919,1009–1048`
- `plan/opencode-v2-src/core/session_prompt.ts:20–90`
- `plan/opencode-v2-src/core/permission.ts:147–178`
- `plan/11-opencode-v2-server-api.md:812–834,972–999,1198–1230`
- `plan/12-opencode-v2-events-and-schemas.md:9–52`
- `ADR.md:1103–1165`
- Existing v1 migration anchors: `ai-docs/opencode_server.md`, `opencode_web.md`, `opencode_models.md`.

Other protocol sources:

- [Codex source at rust-v0.160.0](https://github.com/openai/codex/tree/rust-v0.160.0); `plan/codex-src/key-types.ts:509–595,696–713,838–839,1234–1284`.
- [Claude Agent SDK permissions](https://code.claude.com/docs/en/agent-sdk/permissions); `plan/21-claude-code.md:319–409` and pinned SDK declarations.
- [Pi](https://github.com/earendil-works/pi); `plan/22-pi.md` and RPC raw evidence.
- `plan/harness-src/muse/msp-v1-stable.d.ts`, particularly command IDs, requirement guards, and cursor/error definitions; `plan/23-muse-code.md:79–89,214–260`.
- [Grok Build](https://github.com/xai-org/grok-build); `plan/24-grok-build.md:120–176`.
- [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness); ACP contract reproduced in `plan/25-deepseek-dsh.md` §3.1.
- [ACP pinned specification](https://github.com/agentclientprotocol/agent-client-protocol/tree/9e032156545412be9bba5e092f12d0080c499b6d); `plan/30-acp-and-unifying-protocols.md`.
- [OpenChamber secondary reference](https://github.com/openchamber/openchamber/tree/fc012ae0029fa2ac8d1d52b4af37040fc536258e); analysis in `plan/31-multi-harness-clients.md:73–198`. Its replay hub is useful evidence, but its API facade and compatibility workarounds do not redefine official OpenCode semantics.

### Execution start

The first authorized implementation work should be **Stage 0 contract spikes and the capability schema**, not a replacement chat screen.

Start by inspecting the current revision and relevant source boundaries, then add the first contract fixtures and domain identities:

```text
test/fixtures/harness/opencode_v2/
test/fixtures/harness/codex/
test/fixtures/harness/claude/
lib/harness/domain/identity.dart
lib/harness/domain/capabilities.dart
lib/harness/domain/events.dart
```

Strict prerequisites are a preserved v1 maintenance reference, agreed interpretations of D05/D13, pinned runtime evidence, and explicit platform release gates. With those established, deliver the direct OpenCode vertical slice first, while using Codex and Claude spikes to prevent the new domain from becoming another OpenCode-shaped abstraction.