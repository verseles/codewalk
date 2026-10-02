# CodeWalk v2 Implementation Plan (independent planning helper)

**Revision baseline:** `14fbf519`, after release v1.265.0, `pubspec.yaml` version `1.265.0+1790827338`.
**Evidence date:** 2026-10-02, from the `plan/` research pack.
**Scope of this work:** planning only. I changed no files and executed no builds or tests.
**Labels:** **[V]** means verified in the pack against a pinned source. **[I]** means inferred from verified facts. **[U]** means unverified, with a spike or check named.
**Pins:**
- OpenCode v2.0.21 (npm 2.0.22 `05018b88`)
- Codex 0.160.0 (CLI 0.159.3)
- Claude Agent SDK 0.3.287 / CLI 2.1.287
- Pi 1.0.0
- Muse 1.4.2 (MSP v1)
- Grok Build 1.0.46
- dsh 0.2.0-rc.2
- ACP schema v1.24.1 (stable), v2.0.0-alpha.7 (draft)

---

## 1. Status, objective, recommended architecture, final behavior

### 1.1 Status

There are no hard blockers for **CodeWalk v2.0 (OpenCode v2 plus the new skeleton)**. There are four soft blockers, each tied to a bounded spike (§7):
1. Does the official OpenCode TUI attach to the shared `opencode service`, which makes D13 live attachment real? (S1)
2. Does `POST /api/session/{id}/prompt` return or accept an id usable for ambiguous-send recovery? (S2)
3. Can CodeWalk's embedded Tailscale and Go build hook run on iOS? (S9)
4. Does the existing updater/versioning make "v2 replaces v1 on the same app ID" safe? (S10)

The multi-harness work needs a CodeWalk host component. The sources that decide this:
- **Codex:** its shared daemon is **UDS-only** with no auth [V `20-codex.md` §0.2].
- **Claude Code:** it has no public network daemon [V `21-claude-code.md` §0.2].
- **Pi, Muse, dsh:** they are stdio-only [V].

### 1.2 Objective

CodeWalk v2 is a mobile-first, responsive Flutter client for **OpenCode v2 first**, then other coding harnesses. Each harness is exposed through its own official, structured surface. The client never pretends a harness is OpenCode. It shows exactly what each harness can do.

### 1.3 Architecture recommendation (answers D01, D15)

**Hybrid, thick client, thin host.**

1. **OpenCode v2:** the app connects **directly** to the official server (`/api/*`, Basic or pairing token, global SSE). No CodeWalk host is needed. This preserves the official path and the "no CodeWalk-hosted anything" ethos.
2. **Grok Build:** direct to `grok agent serve` (ACP over WebSocket, bearer secret) is feasible [V `24-grok-build.md`]. A host is still recommended whenever someone has to start and supervise that process. The adapter also works against a bare URL and secret.
3. **Codex, Claude, Pi, Muse, dsh:** a **CodeWalk Host (`codewalk-host`)** runs on the user's machine. Its roles:
   - **Process owner and supervisor** for stdio harnesses (Claude, Pi, Muse, dsh, and Grok if user-managed).
   - **Transport bridge:** Codex shared-daemon UDS → authenticated WebSocket.
   - **Host services:** file tree, fuzzy search, git, PTY, session discovery from disk, and a push/notification originator.
   - **Bounded replay log:** per-channel ring buffer with sequence numbers, so phone reconnects do not lose frames.
4. **Protocol translation lives in the Dart client** (one adapter per harness plus a shared ACP-based adapter). The host **forwards native frames opaquely** with a sequence number and does not normalize them. The host contains only the small per-harness logic it must own:
   - spawning
   - Claude SDK callbacks (`canUseTool`, elicitation)
   - the approval-policy auto-reply when no client is attached
   - an attention classifier (permission, question, done, error) for push
5. **Not a universal daemon.** A normalizing universal daemon would duplicate every translator in TypeScript and Dart, couple the app to a CodeWalk-invented protocol, and force OpenCode through a layer it does not need. Keeping translation client-side puts the reducer, the fixtures, and the UI in one language (Dart), and the Web and iOS builds get it for free.
6. **Host language (D15): TypeScript on Node ≥ 22 LTS**, shipped first as an npm package (`@codewalk/host`) and later optionally as a Node SEA single binary.
   - **Why TypeScript:**
     - Official SDKs and types exist only in TypeScript for the hardest harnesses: Claude Agent SDK (the recommended surface), Pi `RpcClient`, Muse `@muse-code/sdk`, the Codex generated TS types, and the ACP TS SDK [V].
     - The harnesses themselves are installed with npm (Pi requires Node ≥ 22.19), so Node is already a host prerequisite for the same users.
     - The SDK is lock-stepped with the CLI, and the host can pin and update the pair together.
   - **Alternatives considered:**
     - **Dart AOT:**
       - Pro: one language, shared protocol DTOs, `dart compile exe` yields a single binary.
       - Con: it must reimplement the Claude SDK control protocol from the semi-public stream-json surface [V], and it has no SDK for Pi or Muse. Dart AOT does not cross-compile for every OS from one runner. The community ACP Dart packages are `dart_acp_sdk` 0.1.1 (experimental) and `acp_dart` 0.5.0 [V `30` §table]; evaluate them but do not depend on them for the host.
     - **Go or Rust:**
       - Pro: best distribution (static binary, tiny footprint).
       - Con: no official SDKs for Claude, Pi, or Muse. Every wire protocol would be reimplemented, and the churn (Claude ships almost daily) falls on CodeWalk.
     - **Bun:** treat as optional. Do not make `bun build --compile` a requirement. The Claude SDK ships native per-platform optional dependencies, and compiling them into a single-file executable is fragile [U, verify in S6].
   - **Recommendation:** TypeScript/Node for the host. Revisit the single-binary question only after the Phase 2 feature set stabilizes. Keep the host protocol (§4.5) stable and small enough that a later rewrite stays possible.

**Dependency note:** the OpenCode direct path means **v2.0 needs no host**. This is a deliberate scope cut. It keeps v2.0 shippable and prevents the host from becoming a v2.0 gate.

### 1.4 Intended final behavior (summary)

- One app. One unified session list grouped by **host → project directory**, filterable by harness, showing a harness badge and an ownership/liveness badge per session.
- "New session" asks for harness, project, and model/agent. Only installed and authenticated harnesses appear.
- Every screen reads a **capability set** for the active session. Unsupported controls are hidden or disabled with a reason. Nothing is faked.
- The timeline is a canonical, typed model fed by per-harness adapters. Raw provenance is kept for debugging and fallback rendering.
- Reconnect is gap-aware. The app never silently loses a permission request or a form.
- Subagents and background tasks appear as first-class "child session" and "background work" surfaces, with navigation, cancellation, and parent-level rollups of pending approvals.

---

## 2. Decision Assessment (D01–D16)

Legend: **User preference** = a product choice, not a feasibility question. **Feasibility** = evidence-based. Confidence: H / M / L.

| ID | Verdict | Evidence and argument | Alternative / tradeoff | Conf. | Verification |
|---|---|---|---|---|---|
| **D01** (open) | **Recommend: hybrid, thick client / thin host** | See §1.3. OpenCode and Grok are directly reachable; Codex shared daemon is UDS-only [V `20` §0.2]; Claude/Pi/Muse/dsh are stdio-only [V]. Universal daemon rejected because it duplicates translation and forces OpenCode through a custom layer. | *Alternative:* universal normalizing daemon (Happy/Paseo style [V `31` §3–4]). Pros: one wire protocol. Cons: translation duplicated in TS and Dart, harder UI-adapter test, the app can no longer talk to bare OpenCode. *Second alternative:* SSH-only Codex path (`codex app-server proxy`) with no CodeWalk host; viable on desktop, awkward on Android, and gives no push or file services. | H | S6/S7 (host–Codex bridge and Claude callback round trip). |
| **D02** (open) | **Recommend phases in §7.1** | v2.0 OpenCode-only on a harness-ready skeleton, proven by a fixture-level second-adapter check. v2.1 host + Codex + Claude (D13 essential, highest value). v2.2 Grok, Muse, Pi. dsh deferred/spike. | *Alternative:* ship Codex and Claude inside v2.0. Cost: delays the first v2 release and gates it on host plus two fast-moving upstreams. | M | Re-rank after S5/S6 spike outcomes. |
| **D03** (3A) | **Keep** | The v1 inventory shows `ChatProvider` ≈ 22.8k lines across ~30 parts and `ChatPage` ≈ 27.5k lines, with ~26 presentation files calling Dio directly [V `00` §0]. Wire types and OpenCode tool names leak into the UI. v2 events/messages differ structurally (flat typed messages, `execution.*`, forms). Rewriting skeleton + selectively reusing widgets is the right call. | *Alternative:* incremental refactor. Rejected: the v1 invariants (dual SSE, polling, optimistic matching) are the code to remove. | H | None. |
| **D04** (4A) | **Keep with consequential reconsideration** | Same app ID means in-place upgrade (good for data and signing). Risks: **(a)** v1 users with v1 servers are auto-updated into an app that cannot talk to them; **(b)** on Android the legacy v1 download cannot be installed over v2 without uninstalling (lower `versionCode`), which loses data; **(c)** rollback is impossible once local data is migrated. | **Reconsider A:** ship a final v1.x release with an in-app notice and an "update to v2" opt-in step. **Reconsider B:** give the legacy v1 build a distinct application ID (e.g. `com.verseles.codewalk.legacy`) so the two can coexist. **Reconsider C:** copy, never move, v1 data on first v2 launch. Each has costs: A needs one more v1 release; B splits users' data between two apps. | M | S10: read `settings_provider_update_install.dart`, release workflow, and Android `versionCode` derivation. |
| **D05** (5A) | **Keep default, change implementation details** | Product preference (allow-all ON) is the user's. Feasibility issues: OpenCode `always` persists a project-wide saved rule across **all sessions** [V `12` §7.4], unlike v1's remember-in-thread behavior (ADR-023 EXC-001). A session-level wildcard allow **overrides agent deny/ask rules**, including `external_directory` and `.env`, and **children inherit it** [V `12` §7.5]. Do not port v1's "reply `always` + remember". | *Alternative implementation:* default allow-all = **client/host auto-reply `once`** (deny rules still block). Offer server-side session wildcard only as an explicit "Unattended" mode with a plain warning. Costs: with `once`, a disconnected client stalls on the first permission unless the host/notifier answers. | M | S3: confirm `deny` is still enforced after a wildcard session rule, and child inheritance. |
| **D06** (6A) | **Keep, narrow the experiment** | Native signals exist for Codex rate limits [V], Claude quota events [V], Muse `usage/read`+`usage/changed` windows [V], OpenCode token/cost and `provider.quota` errors [V `11` §D]. OpenCode has **no remaining-quota API** [V]. Host-side vendor endpoints require reading local credentials and calling undocumented endpoints, which conflicts with Claude's policy position (never collect or forward OAuth tokens) [V `21` §0.5]. | Keep as default-off, host-side only, per-vendor, with an in-app disclosure; never in the client; never for Claude unless the official SDK usage API suffices. | M | Check the Claude SDK experimental usage API per release. |
| **D07** (open) | **Recommend §5.8** | No CodeWalk relay (D08). Android: one foreground path, local notifications. Host-originated push via UnifiedPush/ntfy and Web Push (VAPID, host-generated keys) in v2.1. iOS APNs requires an Apple credential and a server, so it conflicts with D08 and is deferred pending an explicit ADR exception. | *Alternative:* a minimal stateless CodeWalk push relay (content-free wakeups). Gives FCM/APNs; breaks D08 and adds an operated service. | M | S8 on Android FGS limits and iOS background behavior. |
| **D08** (8A) | **Keep, add TLS/CORS requirements** | Feasible. Hidden costs: OpenCode CORS allows only localhost, Tauri, `oc://`, and `opencode.ai` origins plus `--cors`/service `cors` [V `11` §1.3], so a Web build on another origin needs `opencode service set cors <origin>`; HTTPS pages cannot call HTTP hosts; Codex `ws://` returns **403 to any request with `Origin`** [V `20`]; iOS needs a local-network usage description and ATS exceptions. | None needed; document the topologies in onboarding. | H | S11 (Web origin matrix). |
| **D09** (base+Web+iOS) | **Keep, with a support tier table (§5.9)** | `ios/` does not exist today [V `00` §0]. iOS needs macOS runner, signing, and has no managed install, no background SSE, and an unverified embedded-Tailscale path. Web has no process/UDS/SSH. | iOS ships in v2.0 as **TestFlight beta, connect-only**; Web is connect-only. | M | S9. |
| **D10** (10A) | **Keep with safeguards** | Update API returns per-target `files{url, sha256, size}` [V `11` §E.1]. Safeguards: the SHA-256 comes from the same origin as the binary, so it guards corruption, not a compromised origin; pin a **supported range** (OpenAPI says version 0.0.1/"Experimental" [V `10` §6]; ~23 releases in 3 weeks); never overwrite a user's existing `~/.opencode/bin/opencode` (the v2 installer targets the same dir as v1 [V `11` §E.2]), so install into a CodeWalk-owned directory unless the user opts in. Do not restart the service during a running turn (managed-service restart does auto-resume a turn [V `12` §5], but avoid relying on it). | Alternative: use the official install script (`https://opencode.ai/v2/install`). Loses SHA-256 control but follows the official path. | M | S4 (service lifecycle on Windows/macOS, `service.json`/registration file). |
| **D11** (11A) | **Keep** | Desktop manages daemon and harness installs through official channels; Android connects. iOS/Web are connect-only and cannot install or update anything. Each harness's official installer is listed in §5.2. | None. | H | None. |
| **D12** (12B) | **Keep** (process) | English plan. | None. | H | None. |
| **D13** (13A, essential) | **Keep; capabilities differ sharply (§3.3)** | OpenCode: shared state, live. Codex: shared daemon, live, approvals replayed on rejoin [V]. Claude/Pi/Grok/Muse: history resume only, not live attach. | Present "Continue" vs "Take over" vs "Fork" honestly per harness. | M | S1, S5, S12. |
| **D14** (14A) | **Keep** | Matches the capability model. | None. | H | None. |
| **D15** (open) | **Recommend TypeScript/Node** | See §1.3. | Dart AOT (single toolchain) or Go/Rust (best distribution), costed above. | M | S6: confirm the SDK runs under the host process model on Linux ARM64, macOS, and Windows. |
| **D16** (process) | **Process-only** | Not a technical conclusion. Scheduling did not influence the findings. | None. | n/a | n/a |

### 2.1 Changes I recommend the user reconsider (consequential)

1. **D05 implementation:** use client/host `once` auto-reply as the allow-all default; make server-side wildcard an explicit unattended mode. *Effect:* deny rules and `.env`/external-directory protections keep working, but a disconnected client blocks until the host auto-replies.
2. **D04 migration:**
   - Ship a final v1 release with an upgrade notice.
   - Consider a distinct legacy application ID.
   - Copy v1 data rather than moving it.
   *Effect:* costs one more v1 release but avoids stranding v1-server users and data loss.
3. **D02 sequencing:** keep the host out of v2.0 and prove the abstraction with a fixture-driven second adapter before freezing the model.
4. **D07:** do not promise iOS background delivery. Any iOS push requires a D08 exception.
5. **D10:** do not overwrite a user's existing OpenCode binary, and do not install v2 over a v1 installation.

---

## 3. Capability matrix (all seven harnesses)

**Notation:** N = native official protocol. H = provided by the CodeWalk host (bridge). X = extension or community adapter. E = experimental upstream. – = unsupported/absent. "?" = unverified.

### 3.1 Integration surfaces and versions

| Harness | Primary surface | Transport | Needs host? | Version pin |
|---|---|---|---|---|
| **OpenCode v2** | HTTP `/api/*` + SSE `/api/event` + experimental durable session log | HTTP(S), Basic auth or 30-day pairing token [V] | No (direct) | 2.0.21/2.0.22 |
| **Codex** | app-server v2 JSON-RPC (experimental upstream label) [V] | WebSocket over **UDS** (shared daemon) or `--listen ws://` with capability token (separate process) | Yes for remote shared sessions (or SSH `app-server proxy`) | 0.160.0 / CLI 0.159.3 |
| **Claude Code** | Agent SDK TypeScript (`query()` streaming input); same NDJSON wire as `claude -p --input-format stream-json` [V] | stdio on host | Yes | SDK 0.3.287 / CLI 2.1.287 |
| **Pi** | `pi --mode rpc` strict JSONL, typed [V] | stdio | Yes | 1.0.0 |
| **Muse Code** | Muse Session Protocol v1 (JSON-RPC, NDJSON) via `muse serve` [V] | stdio only | Yes | 1.4.2 |
| **Grok Build** | Native ACP over WebSocket `grok agent serve` + `x.ai/*` extensions [V] | WS, bearer secret, no TLS | Optional (direct if reachable) | 1.0.46 |
| **dsh** | ACP stdio `dsh --profile acp` ("automation-only") [V] | stdio | Yes | 0.2.0-rc.2 |

### 3.2 Feature matrix

| Area | OpenCode v2 | Codex | Claude Code | Pi | Muse | Grok Build | dsh |
|---|---|---|---|---|---|---|---|
| Streaming text/reasoning/tool | N: `session.text/reasoning/tool.input.{started,delta,ended}`, `ended` authoritative, deltas batched ~100 ms [V] | N | N | N | N (`item/delta`) | N (ACP `session/update`) | N (thin) |
| Approvals | N: ordered `{action,resource,effect}` rules, reply `once/always/reject` [V] | N: JSON-RPC requests, accept/accept-for-session/decline/cancel/exec-policy amendment [V] | N: `canUseTool` callback, permission modes [V] | – (no permission system; extensions only) [V] | N: server-minted choices, `approval/decide` [V] | N: ACP `session/request_permission`, modes incl. `bypassPermissions` [V] | N one-shot allow/reject only |
| Questions/forms | N: forms API [V] | ? (check elicitation items) | N: AskUserQuestion, elicitation [V] | X (extension UI sub-protocol) | N: `userInput/request` | N: `x.ai/ask_user_question` | – |
| Tasks/plans | – (todo tool removed in v2 [V]) | N: plan/todo updates; plan mode needs `experimentalApi` [V] | model-dependent todo/task tools [V] | – | N todo list, goals | N `plan.json` | – |
| Subagents | N: `subagent` tool, child sessions, `background:true`, synthetic parent continuation [V] | N: child threads (`parentThreadId`) [V] | N: `task_*` events, background tasks [V] | X (community, 1.0 regression noted) | N | N: `spawn_subagent`, `run_in_background` [V] | ? |
| Session list | N | N `thread/list` (+`thread/loaded/list`) | N SDK `listSessions` (disk) | H/N `SessionManager.list` | N `session/list` | N `session/list` | – (no `session/load`) |
| Create/resume/fork | N / N / N | N / N / N | N / N / N | N / `switch_session` / `fork` | N / N / N | N / N / N | N / – / – |
| Archive/delete | delete N | archive+delete N (cascade to children) | delete N (SDK) | ? (file-level) | delete N | delete N | – |
| Live attach to externally running session | **Yes if the TUI uses the shared service** [U S1] | **Yes** via shared daemon [V] | **No** (history resume only) | **No** | ? | ? (state survives reconnects of the *server*; external TUI attach unverified) | – |
| Undo/redo | N: revert stage/commit/clear (files + messages) [V] | – no file undo; `thread/fork` before turn [V] | N: file checkpoint rewind; no redo [V] | fork/entry tree only | partial: fork at cut point only [V] | `x.ai/rewind` conversation only, not files [V] | – |
| Steer/queue mid-turn | N: delivery `steer|queue`; inbox list/edit/cancel [V] | N steer; queue experimental [V] | N queued mid-turn [V] | N steer/follow-up [V] | N `ifBusy: queue|steer|replace`, `turn/steer`, `turn/unqueue` | N `x.ai` interject + queue | ? |
| Slash commands / skills | N commands/skills endpoints [V] | skills; no server-side slash registry [V] | N discovery via SDK [V] | N (slash-commands.md) | `skill/list`, N | N skills | – |
| `@` mentions | N `fs.find` | fs fuzzy search N (experimental fs) | **H** (SDK lacks listing/search) | H | ? (H fallback) | N `x.ai` fuzzy search | H |
| Terminal/PTY | N: network PTY with token/ticket [V] | N PTY (dies on connection close) | **H** (node-pty) | H | `session/userShell` N | N `x.ai/terminal/*` | H |
| Files read/write | read/list/find N; **no native write endpoint** [V] | fs read/write/watch N | **H** (SDK `readFile` partial) | H | ? | N ACP fs + `x.ai` | H |
| Attachments | text/files in prompt [V] | images via data URLs; HTTP(S) URLs rejected [V] | images N | ? | N input parts | N | ? |
| Model/variant/effort | model+agent are **session selections**; variants [V] | N models + effort | N model + effort | N thinking levels `off…max` | N model + reasoning effort | N | ACP routes/models |
| Usage/quota | tokens+cost+context limits; **no remaining-quota API** [V] | N tokens + rate-limit windows [V] | N quota events (+ experimental SDK usage) | N cost stats | N 5-hour/weekly windows [V] | N `x.ai/session/usage`, billing | – |
| Notifications source | SSE events | notifications | SDK messages | RPC events | MSP events | ACP updates | ACP |
| Allow-all semantics | see §3.4 | see §3.4 | see §3.4 | none exists | `allowAll` approval mode (policy may forbid) [V] | `bypassPermissions`/`--always-approve` | n/a |

### 3.3 External-session (D13) support, exactly

| Harness | Discover | Resume/continue | Live attach | Ownership / concurrency |
|---|---|---|---|---|
| OpenCode v2 | `GET /api/session` plus `/api/session/active` [V]. All sessions are in the user's DB; per-process visibility depends on which server process reads that DB. | Prompt via API | Live events via the global SSE if the TUI uses the same service [U S1] | Server is the owner; concurrent prompts use delivery `steer`/`queue`. A separate foreground `opencode serve` is a different process: it shows sessions but not live state [I]. |
| Codex | `thread/list` (default `sourceKinds` = cli+vscode) and `thread/loaded/list` [V] | `thread/resume` | **Yes**: rejoin replays token usage, goal state, and pending approvals [V]; TUI auto-attaches since v0.157.0 [V] | Daemon owns the thread; multiple clients share it. Daemon-less TUI sessions are history-only [I]. |
| Claude | SDK `listSessions` over `~/.claude/projects/<cwd>/<id>.jsonl` [V] | `resume` / `forkSession` | No | **Two writers on one JSONL are possible.** Offer "Fork" as the safe default; "Continue" shows a warning when the file was modified recently (heuristic, one `stat` at resume). Process scan is [U]. |
| Pi | `SessionManager.list` over `~/.pi/agent/sessions/` | `switch_session`, `fork` | No | Same two-writer caution. |
| Muse | `session/list` (`sessionListStream` capability) [V] | `session/resume` with cursor | ? | TUI vs `muse serve` coexistence [U S12]. |
| Grok | `session/list`, `x.ai/session/list`; `~/.grok/sessions/...` [V] | `session/load`/`resume` | State survives client reconnects to `grok agent serve` [V]; external TUI attach [U] | Verify leader/follower mode. |
| dsh | none (no `session/load`) [V] | – | – | – |

### 3.4 Approval versus sandbox, per harness (not interchangeable)

CodeWalk exposes **two independent controls** where the harness has both, never one "YOLO" switch:

| Harness | Approval control | Sandbox / access control | "Allow-all" in CodeWalk maps to |
|---|---|---|---|
| OpenCode | rule array; `once`/`always`/`reject` | No separate sandbox concept in the API; rules *are* access | Default: client/host auto `once`. Advanced: session `*` allow (overrides deny; inherited by children). Never `always`. |
| Codex | `approvalPolicy` (`on-request`, `never`, `unlessTrusted`…) | `sandbox` `read-only`/`workspace-write`/`danger-full-access` (turn-level `sandboxPolicy` object) [V] | "Auto-approve" = keep `workspace-write`, answer approval requests `accept`. "Full access" = `danger-full-access` + `never`, shown as a separate, red control. |
| Claude | `permissionMode` (pass **explicitly**: omitted defaults to `auto`) [V], `canUseTool` | Claude sandbox settings [U] | `canUseTool` allow, or `bypassPermissions` (requires an explicit dangerous-skip option) [I, verify deny-rule behavior in S6]. |
| Pi | none | none | N/A. Show "No approval system: runs unrestricted". |
| Muse | `session/setApprovalMode` `allowAll` etc. [V] | `--disable-approval` keeps sandbox; `--yolo` removes it (CLI only) [V] | `allowAll` approval mode where policy allows. |
| Grok | modes (`bypassPermissions` = `--always-approve`); deny rules and hooks still apply; admin may lock [V] | optional `--sandbox` | mode `bypassPermissions`, disabled when locked. |
| dsh | one-shot allow/reject | Landlock/Seatbelt sandbox | client auto-allow only. |

---

## 4. Architecture and interfaces

### 4.1 Principles

1. **Contract first:** each adapter follows its harness's official schema. Divergence needs an ADR exception.
2. **Canonical domain, raw provenance:** adapters map to a small sealed domain model and attach the raw frame reference for debugging and an unknown-item fallback renderer.
3. **No UI knowledge of wire types or tool names.** A single `ToolKind` classification lives in the adapter.
4. **Capabilities are data, not subclasses.**
5. **Polling is bounded and justified** (§4.9).

### 4.2 Proposed layout (new skeleton, same repo)

```
lib/
  app/                    # bootstrap, DI (get_it kept), routing, theming entry
  core/                   # reuse: logging, errors, i18n, config, network utils
  domain/
    ids.dart              # HostId, HarnessId, ProjectKey, SessionKey
    capabilities.dart     # HarnessCapabilities, Support enum
    timeline.dart         # sealed TimelineItem
    events.dart           # sealed SessionEvent (adapter output)
    approvals.dart  forms.dart  usage.dart  tasks.dart  errors.dart
    session_summary.dart
  harness/
    harness_adapter.dart  # the port (4.3)
    registry.dart         # capabilities negotiation and version-range table
    opencode/             # OpenCodeClient, SseFeed, SessionReducer, mapper
    codex/  claude/  muse/  pi/
    acp/                  # generic ACP v1 client (+ grok/ x.ai extensions, dsh)
  transport/
    http_json.dart  sse_stream.dart  jsonrpc_ws.dart  ndjson.dart  host_channel.dart
  host_client/            # CodeWalk Host protocol client (4.5)
  store/                  # SessionStore (generic reducer), drafts, settings
  features/
    onboarding/ hosts/ sessions/ chat/ composer/ approvals/ forms/
    tasks/ files/ terminal/ usage/ settings/ notifications/ voice/
  presentation/widgets/   # reused leaf widgets
host/                     # codewalk-host (TypeScript), separate package
test/{unit,contract,fixtures,widget}/
```

The v1 tree is preserved on the `v1` maintenance branch. The v2 skeleton replaces `lib/` on main.

### 4.3 Adapter port

```dart
abstract interface class HarnessAdapter {
  HarnessId get id;
  Future<HarnessProfile> connect(HostRef host);          // version, protocol, capabilities, models, agents
  Stream<ConnectionState> get connection;                 // connected/degraded/reconnecting/lost
  // sessions
  Future<Page<SessionSummary>> listSessions(SessionQuery q);
  Future<SessionHandle> createSession(NewSession req);
  Future<SessionHandle> openSession(SessionKey key, {OpenMode mode}); // continue | fork | readOnly
  Future<void> archive(SessionKey k);  Future<void> delete(SessionKey k);
}

abstract interface class SessionHandle {
  SessionKey get key;
  SessionCapabilities get capabilities;                   // may differ per session/model
  Stream<SessionEvent> get events;                        // already reduced to domain events
  Future<Snapshot> snapshot({Cursor? around});            // bounded history page
  Future<SendResult> send(Prompt p, {Delivery delivery, String clientMsgId});
  Future<void> interrupt();                               // stop turn
  Future<void> steer(Prompt p);  Future<void> cancelQueued(String itemId);
  Future<void> replyApproval(String id, ApprovalDecision d);
  Future<void> answerForm(String id, FormAnswer a);  Future<void> cancelForm(String id);
  Future<void> setSelection(Selection s);                 // model/agent/variant/effort/permission mode
  Future<UndoState?> undo(UndoTarget t);  Future<void> redo();   // only when capability present
  Future<void> compact();  Future<SessionKey> fork(ForkPoint p);
}

// Optional capability facets, obtained only if supported:
abstract interface class FilesFacet { list/read/write/find/gitStatus/diff }
abstract interface class TerminalFacet { open/resize/input/close }
abstract interface class UsageFacet { Stream<UsageSnapshot> }
abstract interface class TaskFacet { background tasks list/stop }
```

Optional facets (`session.facet<FilesFacet>()`) keep the port small and avoid dozens of throwing no-op methods.

### 4.4 Domain model

```dart
sealed class TimelineItem { String id; DateTime at; Raw? raw; }
class UserMessage      { text; attachments; deliveryState (sending|queued|delivered|failed|ambiguous); clientMsgId }
class AssistantText    { text; streaming; finish }
class Reasoning        { text; streaming; }
class ToolCall         { kind: ToolKind; title; status; input; output; diffs; childSession?; raw }
class SubagentLink     { childSession; agent; description; background; state }
class SyntheticNotice  { source; text; childRef? }       // OpenCode synthetic parent messages
class ErrorItem        { AppError error; retry? }
class Compaction       { ... }

enum ToolKind { shell, read, edit, patch, search, fetch, mcp, subagent, plan, question, other }

sealed class SessionEvent {
  TimelineUpsert(item, rev)   TimelineAppendDelta(itemId, text)   TimelineFinalize(itemId, item)
  ExecutionChanged(running|idle|retrying, outcome, error?)
  ApprovalRequested(PendingApproval)   ApprovalResolved(id, by)
  FormRequested(PendingForm)           FormResolved(id)
  UsageUpdated(Usage)   TaskListChanged(plan)   ChildLinked(child)
  QueueChanged(items)   ResyncRequired(reason)   SessionInfoChanged(...)
}

class PendingApproval { id; sessionKey; origin: sessionKey (child); title; kind; resourceLabels;
                         choices: List<ApprovalChoice>; raw }   // choices come from the harness, not hardcoded
class Usage { tokens?; cost?; context?: {used, limit}; windows: List<QuotaWindow>?; source: native|experimental }
class AppError { category: auth|quota|rate_limit|network|server_busy|protocol|cancelled|harness; message; retryable; retryAt?; raw }
```

**Identity.**
- `SessionKey = (hostId, harnessId, nativeSessionId)`.
- `ProjectKey = (hostId, canonicalPath)`. Paths are normalized per host OS; Windows case rules are defined per host, and git worktrees are separate keys with a "same repo" grouping hint.
- Never merge sessions across harnesses by directory alone; group them under the project, label them by harness.

**Ordering and reconciliation.**
- Every adapter attaches a per-session monotonic `rev`: the harness's durable sequence where one exists (OpenCode `durable.seq`; Codex turn/item ids and cursors; Muse view cursor), otherwise a local counter.
- The generic `SessionStore` reducer is upsert-by-id plus "ended replaces streamed text". It does **not** parse protocol.
- Snapshots (history pages) replace; live events upsert. If a gap is detected (reconnect, `view/gap`, host `gap` frame), the adapter emits `ResyncRequired` and the store refetches the visible window.

**OpenCode-specific rules [V `12` §1.4, §4]:**
- Wait for `server.connected` after (re)connect, then rehydrate with `GET /api/session/active`, the session, the message window, the inbox, `…/permission`, and `…/form` for visible sessions.
- Optionally track the highest `durable.seq` and use the experimental session log with `after=<seq>&follow=false`.
- Text mid-stream during a gap shows an ellipsis until `session.text.ended`.
- Do not depend on `session.status`. Use `session.execution.*`.
- Unknown event types: ignore and record as a diagnostic counter.

**Optimistic sends and ambiguous mutations.**
- A send creates a local `UserMessage(deliveryState: sending, clientMsgId)`.
- **OpenCode:** correlate through `session.inbox.enqueued`/`delivered` and `GET /api/session/{id}/inbox` [V routes]. Whether the prompt response or request carries an id usable for exact matching is [U, S2].
- On a timeout or disconnect mid-POST, mark the item **`ambiguous`**, not failed. Resolve it with one inbox/history lookup bounded to a recent window. **Never auto-resend.** Offer "Send again" with an explicit duplicate warning.
- Matching by text is only a last-resort fallback, restricted to the session and a time window, and it is labeled a heuristic in code and tests.

**Multi-client conflicts.**
- Approvals and forms can be answered from another client. Every reply path handles "already resolved" (409/not-found) idempotently: dismiss locally and show "answered elsewhere".
- Codex replays pending requests on rejoin; dismiss on `serverRequest/resolved` [V].
- Inbox edit/cancel races on a queued prompt are handled the same way.

**Version drift.**
- `HarnessProfile.version` is checked against a registry table (`tested`, `untested-newer`, `too-old`, `blocked`). Newer-than-tested shows a dismissible notice and continues. Known-bad ranges block with an explanation.
- Unknown fields are ignored. Unknown item types render through the raw fallback.

### 4.5 CodeWalk Host (`host/`, TypeScript)

**Responsibilities and non-goals**
- Own and supervise harness processes (spawn, restart policy, resource limits, clean shutdown). Do not leak orphan processes.
- Authenticate clients (pairing code → expiring bearer token, hashed at rest; reuse the proven OpenCode pairing shape).
- Fan out to multiple clients per channel with a first-reply-wins rule for approvals.
- Provide host services (files, git, PTY, session discovery, fs watch, push).
- **Not** a normalizer. **Not** a relay. It never stores provider credentials: harness logins are done by the user with each vendor's own flow.

**Wire shape (CHP v1, minimal)**
- HTTP:
  - `GET /v1/info`: host version, OS, installed harnesses with versions and auth state.
  - `POST /v1/pair`, `GET /v1/sessions?harness=…` (disk discovery).
  - Files: `/v1/fs/list|read|write|find`.
  - Git: `/v1/git/status|diff`.
  - `/v1/pty` tickets.
- One WebSocket `/v1/ws` multiplexing channels: `{ch, seq, dir, frame}`. Frames are the harness's own JSON, untouched.
- `resume {ch, afterSeq}`. On overflow the host emits `gap {ch, firstSeq}` and the client rehydrates through the harness's native history API.
- The ring buffer is bounded per channel (e.g. 5,000 frames or 8 MB, whichever first, with a time cap). Tune this in the S6/S7 spikes; the numbers here are placeholders.

**Per-harness host adapters**
- **Codex:** one upstream WebSocket-over-UDS connection to the shared daemon (Node `ws` with `socketPath`, or `codex app-server proxy`). Host runs `codex app-server daemon start` if missing.
- **Claude:** SDK `query()` in streaming-input mode per live session. `canUseTool` and elicitation become request frames to the client and must also be answerable by the host's policy hook. Pin SDK and CLI together.
- **Pi:** `pi --mode rpc` per active session (one active session per process [V]).
- **Muse:** `muse serve` stdio; the host rejects non-spawning parties.
- **Grok:** either supervise `grok agent serve --bind 127.0.0.1:<port> --secret …` and proxy it, or pass the URL through unchanged.
- **dsh:** `dsh --profile acp` stdio. Defer.

**Host services notes**
- Claude, Pi, and dsh lack directory listing, fuzzy search, git, and PTY (the dossiers explicitly list them as host duties [V `21` §0.7]), so the host implements them once for all harnesses.
- File **write**: OpenCode has no native endpoint [V]. Define one `FileWriteStrategy`:
  1. harness-native where present (Codex fs write, ACP fs),
  2. host `/v1/fs/write` where a host exists,
  3. otherwise the v1 pattern, shell-gated (ADR-043), only behind an explicit capability probe and a per-host opt-in.
  Keep ADR-043 semantics as the fallback and restate them in the v2 ADR.
- Security of write/PTY: bind to loopback by default; refuse non-loopback binds without TLS or a user-acknowledged risk flag; per-token scopes (read-only token option); audit log of mutating calls. [I, recommended]

### 4.6 State machines (condensed)

**Connection (per host+harness):** `idle → connecting → handshaking → ready ⇄ degraded(reconnecting, backoff 1s→30s with jitter) → lost`. Auth failure and version-blocked are terminal-until-user states.
**Turn (per session):** `idle → running → {succeeded|failed|interrupted} → idle`, with `retrying(at)` while running and `awaiting_approval | awaiting_form` as overlays on `running`. **Stop** is capability-gated: OpenCode `interrupt`, Codex `turn/interrupt`, Claude `interrupt()` (known bug: interrupt right after a user message can be ignored on later turns [V `21`] → UI shows "stop requested…" with a timeout fallback), Muse `turn/interrupt|cancel`, ACP `session/cancel`.
**Queued prompt:** `composing → sending → {delivered | queued(editable) | ambiguous | failed}`.
**Approval:** `requested → {answered(local) | answered(remote) | expired}`.

### 4.7 Errors and retries

Normalize to `AppError` with a harness-specific `raw`. OpenCode `provider.rate-limit` (retried by the server; show retry countdown from `session.retry.scheduled`), `provider.quota` (not retried; may carry Go/Zen limit body with `limitName` and `retry-after` [V]), and `provider.auth` each get distinct UI treatment. Transport errors (401, `service_starting` 503 with `retry-after`, service_failed/stopping [V `11` §1.1]) are handled before domain parsing: show "Starting…", retry honoring `retry-after`, and a copyable action hint. Never parse HTML 200 responses as v1 JSON. Detect v2 via authenticated `GET /api/info`; a `/global/health` JSON response means v1 and gets an "unsupported (legacy)" screen with a link.

### 4.8 Reasoning/tool output rendering

Reuse v1's markdown, code, diff, terminal (`third_party/xterm`), mermaid, and math widgets. Tool cards render by `ToolKind` plus a structured `output` model (diff hunks for edits, exit code for shell). Large outputs are virtualized and truncated with "load more". The raw view is available for unknown or other.

### 4.9 Polling policy (the only allowed polling)

| Purpose | Trigger and cadence | Invalidation / cost |
|---|---|---|
| Session discovery on disk-backed hosts (Claude, Pi, Grok) | Host fs-watch with 2 s debounce emits `sessions.changed`; client refetches the list page only while the list is visible | None when idle |
| OpenCode resync | Once per (re)connect, plus once per session open | Per visible session only |
| Experimental vendor usage (D06) | Off by default; ≥ 5 min while foreground and the usage panel visible | Single request; backoff on error |
| Git status/diff | On demand and after a turn completes | None |
| Stop confirmation | One bounded wait (e.g. 8 s) after `interrupt`, then re-snapshot | One-shot |

No periodic message polling, no heartbeat refetching of full timelines. OpenCode SSE sends heartbeat comments and disconnects slow consumers (backpressure) [V]; the reconnect path above handles that.

---

## 5. UX and behavior

### 5.1 Layout

- Mobile-first Material You (`dynamic_color` retained). Responsive breakpoints: compact = single pane; medium = rail + list/chat; expanded = three-pane (hosts/projects, sessions, chat + side panels for files, tasks, terminal, usage).
- Web and desktop use the expanded layout. Keyboard shortcuts on desktop and Web.

### 5.2 Onboarding, install, pair, update

1. **Desktop first run:** "Use this computer" or "Connect to another host".
   - Detect an existing OpenCode: if v2, reuse; if v1, do not overwrite, offer a separate CodeWalk-managed install.
   - Managed install: download the binary for the target from the update API, verify SHA-256 and size, unpack into the CodeWalk app-data directory, then run `opencode service start`. Show the registered port (default 49374) and read the service config password (file is 0600, same user).
   - Windows/macOS service semantics: [U, S4].
2. **Remote (Android/iOS/Web):** scan the QR from `opencode pair` or paste a URL/code.
   - Redeem `GET /auth/connect/{code}` with a non-HTML `Accept`. The response is a 30-day token [V `11` §1.2]; store it in secure storage.
   - On expiry or rotation (a password change revokes tokens), show "re-pair".
3. **Other harnesses (v2.1+):** a host card lists installed harnesses and their auth state. Desktop can offer installs through each vendor's official channel (npm or official script). It never handles vendor credentials: it opens the vendor login flow on the host (`claude auth login`, `codex login`, `grok login`, `muse login`) and only reads status.
4. **Updates:** keep the app updater. Daemon/harness updates are user-initiated, shown with "update available" (OpenCode: `GET https://opencode.ai/update/api/<channel>/cli/...`), and blocked while a turn is running.

### 5.3 Unified sessions (D14)

- List grouped by host → project; per row: title, harness badge, state (running, awaiting you, idle-unread), last activity, ownership badge.
- **Ownership badges:** "Live elsewhere" (Codex loaded in the daemon, OpenCode active), "History only" (Claude/Pi/Muse resume).
- **Open actions:** *Continue* (when safe), *Fork* (default for history-only harnesses), *View only*.
- Pull-to-refresh and live row updates where native (`session/listChanged`, host `sessions.changed`).

### 5.4 Chat, composer, steer/queue

- Composer shows: harness/model/agent/variant-or-effort chips (capability-driven), permission mode chip, attachment button, `/` and `@` pickers, voice button.
- While a turn is running the primary action becomes **Send as…**: `Steer` or `Queue` (only the options the harness supports). Queued items are listed above the composer with edit and cancel where available: OpenCode inbox update/delete [V routes], Muse `turn/unqueue` [V].
- Drafts, tabs, history navigation, export, accessibility, and localization from v1 are kept (§6).

### 5.5 Subagents and background work (OpenCode primary)

- A foreground subagent appears as an expandable card in the parent. A background one appears as a "Background work" chip (count) plus a bottom sheet. Each child opens as its own session view with a breadcrumb back to the parent.
- **Discovery** follows the official order [V `12` §11.3]: parent tool-item metadata `sessionID`, then `GET /api/session?parentID=`, then `/api/session/active`, then live `session.created` with `parentID`. The `subagent` item's `metadata.sessionID` is only on ephemeral `tool.progress` while a foreground call runs, so after a reconnect use `parentID` listing.
- **Cancel one child:** `POST /api/session/{childID}/interrupt` [V]. "Move to background": `POST /api/session/{parentID}/background`; it is **session-wide** and there is no per-child backgrounding [V].
- **Permissions and forms from children** surface in the parent view with the child's label, because child sessions ask under their own `sessionID` [V `12` §7.6].
- **Completion** arrives as a synthetic parent message with `metadata.source:"subagent"` and `childID`; render as a clickable chip, not a user bubble.
- **Known upstream bug:** nested background work finishing early (listed in the pack). Surface "child finished" from `session.execution.*` of the child and show the raw outcome; do not infer success from the parent text alone. Details to confirm in S3.
- Codex child threads, Claude `task_*`, Grok `spawn_subagent`, and Muse subagents map to the same `SubagentLink`; if the adapter cannot link a child session, show an activity row without navigation.

### 5.6 Tasks, plans, forms

- Agent-controlled todo/plan (Codex, Claude when enabled, Muse, Grok `plan.json`) renders in the Tasks panel. OpenCode v2 has no todo (removed) [V], so hide the panel.
- Forms are rendered from the harness schema (choices, multi-select, free text) in an inline card. Mobile uses a bottom sheet for long forms. A form can be cancelled where `DELETE /api/session/{id}/form/{fid}` or equivalent exists.

### 5.7 Quotas versus usage

Two separate surfaces, never conflated:
- **Context/tokens/cost:** OpenCode `Session.Info.tokens/cost`, `session.usage.updated`, model `limit.context`, `step.ended`; Codex `thread/tokenUsage/updated`; Pi `get_session_stats`.
- **Quota windows:** Muse 5-hour and weekly percentages (can exceed 100) [V], Codex primary/secondary rate limits and credits [V], Claude plan-quota events [V]. For OpenCode, show only error-derived quota state ("provider quota reached; resets per limitName") and clearly say remaining quota is not exposed. The experimental host endpoint is a labeled opt-in (D06).

### 5.8 Notifications and background delivery (D07 recommendation)

**Honest model:** v2.0 delivers notifications only while the app process holds a connection. Anything beyond is v2.1+.

- **Events that notify:** turn finished, error, approval/form needed (including child sessions), background task finished. Suppress when the same session is foregrounded and focused; collapse per session.
- **Android v2.0:** one connection path replaces the three overlapping v1 paths (foreground service, WorkManager, overlay engine — see the inventory §1.8). Use a single foreground service **only while any session is running or awaiting input**, and local notifications from the SSE feed. Android 15 limits `dataSync` FGS runtime [U, S8]; the plan is to stop the service when idle and not depend on an always-on socket.
- **v2.1, host-originated push with no CodeWalk relay:**
  - **UnifiedPush/ntfy** for Android (self-hostable or user-chosen server; content-free by default).
  - **Web Push (VAPID)** generated by the host for browsers and installed PWAs.
  - OpenCode-only users who want push can run the host's lightweight "notifier" mode that subscribes to `/api/event`.
- **iOS:** no persistent background socket. Notifications work while foregrounded, and optionally via background refresh (best effort, not guaranteed). APNs requires an Apple-credentialed sender, i.e. a relay → needs an explicit ADR exception to D08 for a stateless, content-free relay. Do not market iOS background delivery until that decision is made.
- **Disconnect or process death:** on next foreground, rehydrate and show "while you were away" (finished turns, pending approvals). Pending approvals persist server-side (OpenCode/Codex replay them [V]).

### 5.9 Platform support tiers (D09)

| Platform | Tier at v2.0 | Capabilities | Limits |
|---|---|---|---|
| Android | Full | Direct OpenCode, notifications, voice, updater | no managed install |
| Linux/macOS/Windows | Full | managed install, tray, `opencode service`, voice | Windows service/permissions [U S4]; macOS notarization for updater |
| Web | Connect-only | Direct OpenCode (needs CORS config) or host | no UDS, process, SSH, local files; cleartext restrictions; Codex 403 on Origin (host fronts it) |
| iOS | Beta, connect-only | Direct OpenCode, host | no managed install, no background socket; embedded Tailscale [U S9] else system VPN; ATS/local-network entitlements; macOS CI + signing |

### 5.10 Slash commands, skills, `@`, files, terminal

- **Commands:** `GET` commands per harness; run via `POST /api/session/{id}/command` for OpenCode [V]. Codex has no server-side slash registry [V]: only client-side meta-commands plus skills. Claude and Muse list skills via protocol. Skills nuance: skills are invoked differently (explicit command, auto-selected by the model, or mention), so the picker labels the origin and does not assume that selecting a skill guarantees invocation.
- **`@` mentions:** files via the harness fuzzy search where available, else the host. OpenCode `fs.find` is name-only fuzzy; there is **no content grep or symbol search** in v2 [V]; do not carry over the v1 text-search UI.
- **Terminal:** OpenCode PTY via network ticket/token [V], Codex PTY dies when its connection closes [V], host PTY elsewhere. Reuse `third_party/xterm`.
- **Files:** browser/read from native endpoints. Write through `FileWriteStrategy` (§4.5).

### 5.11 Undo/redo semantics shown in UI

- OpenCode: **Revert** (stage, with preview), then **Commit revert** or **Restore** (clear). This is the only harness with file-and-message revert plus a redo-like clear.
- Claude: **Rewind files to checkpoint**; no redo.
- Codex/Grok/Pi/Muse: **Fork from here** (conversation only); labeled "does not restore files".
- Never call these all "Undo".

---

## 6. Rewrite / reuse / discard map

Source: `plan/00-codewalk-v1-inventory.md` §1–3, §5. Existing paths are starting points to verify during Stage 0.

| Area | Decision | Reason / target |
|---|---|---|
| `ChatProvider` (~22.8k lines, `presentation/providers/chat_provider*.dart` and ~26 parts) | **Discard** | Replaced by `store/SessionStore` + `features/chat` view models. Most of the v1 `CP/` code exists to compensate for v1 gaps (no replay, no ids, polling) [V `00` §0]. |
| `ChatPage` (~27.5k, 30 parts) | **Rewrite**, reusing leaf widgets | Split by feature (`features/chat`, `composer`, `approvals`, `forms`). |
| `data/datasources/chat_remote_datasource.dart` and models | **Discard/replace** by `harness/opencode/*` | v1 routes removed in v2 (§3 of `11`). |
| Domain entities mirroring v1 | **Replace** with `domain/*` | v1 shapes (12 part types, `SessionRevert`, `idle|busy|retry`). |
| `LocalOpencodeServerRuntime` (interface `start/diagnose/install/stop/dispose`) | **Keep interface, rewrite OpenCode implementation** | Now `opencode service` + SHA-256 verified binary; keep diagnostics/log streams. |
| `QuotaRemoteDataSource` strategy chain | **Simplify** | Use harness-native usage; experimental vendor strategy only as an opt-in plug-in. |
| `ChatTitleGenerator` | **Remove for OpenCode** (v2 sessions title natively? **[U]**, check `opencode.session_rename` tool and session title behavior); keep the interface if another harness lacks titles | Hidden shell sessions for titles are a v1 workaround. |
| `WorkspaceFileOperationsService` | **Keep as fallback strategy** behind `FileWriteStrategy` | ADR-043 shell-gated writes retained only when no native/host write. |
| `TerminalRemoteDataSource` + `CodewalkTerminalSocket` + `third_party/xterm` | **Keep and adapt** | PTY endpoints changed to token/ticket form [V `11` A12]. |
| `third_party/tailscale` (Go) | **Keep on desktop/Android; iOS decision after S9** | Embedded node [V `00` §1.8]. |
| Theme, markdown, code, diff, mermaid, math widgets | **Keep** | Pure presentation. |
| Voice (STT/TTS backends, Windows mic plugin) | **Keep** | Client-only (`§2.11`). |
| Drafts, tabs, history, export, accessibility, l10n | **Keep** (adapt keys to `SessionKey`) | App-local value, harness-independent. |
| Dual SSE streams and dedupe, 'refetch on every event', optimistic text matching, polling loops, v1-only caches | **Discard** | Replaced by single `/api/event`, rev-based reducer, ambiguous-send handling. |
| Three Android monitoring paths (FGS, WorkManager, overlay engine) | **Consolidate** into one connection service + local notifications; overlay (`SessionOverlayService`, 720 lines) → **defer** pending a usage review | Overlaps in v1 inventory. |
| Session attention (`data/session_attention`), car messaging | **Keep concept, rewire to `SessionEvent`** | Attention surface retained; car messaging reviewed for iOS/Android Auto parity [U]. |
| Direct `Dio` use in ~26 presentation files | **Discard** | All network goes through adapters/transports. |
| Todo (`todowrite`) UI | **Make capability-driven** | OpenCode v2 has no todo. |
| Share session, LSP/formatter status, TUI control routes, `/find` text search | **Remove** | No v2 endpoints [V `11` §3]. |

**Coordinated documentation updates:** `ADR.md`: a new v2 ADR superseding ADR-023 (v1 contract) and rewriting ADR-029 (quotas), ADR-033 (proxy auth), and ADR-043 (file mutation), plus new ADRs for the host, the capability model, and the D05/D08 exceptions. `BEHAVIOR.md`: rewrite sections (composer, prompts, tasks, attention 2396, notifications 2444, lifecycle 2532, reconciliation 2887, subagents 2924/2936) for v2. `CONTRACT_MATRIX.md`: v2 matrix per harness (OpenCode first). `ai-docs/opencode_*.md`: replace with pinned v2 references. `CODEBASE.md`, `README.md`, Makefile targets.

**Local-data migration and rollback:**
- Namespace v2 storage keys (`v2.*`); on first launch **copy** v1 server profiles, secure credentials, drafts, and settings into the v2 schema; mark migrated; never delete v1 keys until a later release.
- Server profiles gain `kind: opencode-v1|v2`; v1 profiles are shown as "legacy (unsupported)" with an update/legacy-download link.
- Rollback = leave v1 keys intact; because Android blocks downgrades with the same ID (D04), rollback of the app itself is not supported; legacy install needs uninstall or the distinct-ID alternative.
- **Versioning:** v2.0 gets `2.0.0` with a build number strictly greater than v1's `1790827338` to satisfy Android `versionCode` upgrade rules [I: confirm the derivation in S10]. Release assets remain per-platform; the `v1` branch publishes legacy builds under clearly separate names.

---

## 7. Implementation stages

### 7.1 Release phases (D02 recommendation)

| Release | Content | Gate |
|---|---|---|
| **v2.0** | New skeleton; OpenCode v2 direct (auth/pairing, sessions, chat, approvals, forms, subagents, files read, terminal, usage, undo); managed desktop install; Android, Linux, macOS, Windows, Web; iOS TestFlight beta (connect-only); capability engine; **fixture-level Codex/ACP adapter** proving the port | OpenCode vertical complete; second-adapter proof passes |
| **v2.1** | `codewalk-host`; **Codex** (shared daemon, D13) and **Claude Code**; host push (ntfy/UnifiedPush/Web Push); desktop harness install/update | S5, S6 resolved |
| **v2.2** | **Grok Build** (ACP over WS), **Muse Code**, **Pi**; generic ACP adapter hardening | S12 resolved |
| **Later / spike-only** | **dsh** (preview, thin ACP: no session load, no plans, no forms [V]); other ACP agents via generic adapter; iOS APNs relay (needs D08 exception) | Upstream stability |

**Minimum viable scope:** v2.0 as above. It does not drop any user-selected platform. iOS and Web are reduced to connect-only because of platform constraints, not removed.

### 7.2 Spikes (bounded, read-only/disposable)

| ID | Question | Output / fallback if false |
|---|---|---|
| S1 | Does the OpenCode v2 TUI use the shared service so that CodeWalk sees TUI sessions live? | Probe against a running service. If false, D13 = history/list only for OpenCode. |
| S2 | Does `POST /prompt` return or accept ids; what do inbox events carry? | If no id, rely on inbox/history lookup with the `ambiguous` rule. |
| S3 | Permission semantics: deny after session `*` allow; child inheritance; `always` scope; nested background finishing early | Decides D05 default and the unattended warning. |
| S4 | `opencode service` lifecycle and registration on Linux/macOS/Windows; password location; stale PID handling | If unreliable on Windows, use `serve --stdio` as owned child on desktop. |
| S5 | Codex: shared-daemon via host (UDS WS) vs SSH `proxy`; approval fan-out; Origin; version skew (CLI 0.159.3 vs daemon 0.160.0) | Fallback: separate `--listen ws://` server (sessions not shared) clearly labeled. |
| S6 | Claude: SDK in host, `canUseTool` round trip, `bypassPermissions` vs deny rules, interrupt bug, ARM64 Linux/Windows packaging | Fallback: raw stream-json child process. |
| S7 | Host replay log sizing and gap behavior under reconnect | Tune the ring buffer. |
| S8 | Android FGS limits, ntfy/UnifiedPush behavior, iOS background refresh | Reduce promises in UI. |
| S9 | Embedded Tailscale (Go hook) on iOS; build and signing | Fallback: system VPN only. |
| S10 | Updater/version/`versionCode`/legacy download plan for same app ID | Choose D04 variant. |
| S11 | Web origin/auth matrix for OpenCode CORS, Codex 403, TLS | Document setup; host fronts the rest. |
| S12 | Muse/Grok/Pi coexistence with a running TUI; attach vs resume | Mark "history only". |

### 7.3 Ordered stages (v2.0)

| Stage | Work | Depends on | Acceptance and validation |
|---|---|---|---|
| 0 | Branch `v1` cut; skeleton created; ADR drafts; CI matrices; fixtures folder; run S1–S4, S10, S11 | none | ADR-v2 accepted; spike notes recorded; `make check` green on the empty skeleton |
| 1 | `transport/`, `domain/`, `harness/opencode` client + SSE + reducer against recorded fixtures | 0 | Contract tests over `plan/opencode-v2-src` fixtures (reference reducer parity); malformed/unknown events tolerated |
| 2 | Onboarding, pairing, host profiles, detect v1 vs v2, error mapping | 1 | Wizard flow tests; 401/503/HTML-200 cases |
| 3 | Sessions list/create/open, unified list UI, ownership badges | 1–2 | Widget tests; external-session fixture |
| 4 | Chat vertical slice: stream, tool/reasoning cards, composer, stop, steer/queue, optimistic/ambiguous send | 1–3 | Reducer race tests; ambiguous send; reconnect gap |
| 5 | Approvals/forms/allow-all; child-session surfacing | 4, S3 | Policy tests per §3.4; "answered elsewhere" |
| 6 | Subagents/background UI | 4–5 | Nested + background fixtures |
| 7 | Files, mentions, commands/skills, attachments, terminal, undo | 4 | Per-capability tests |
| 8 | Usage/quota/errors; notifications v1 (single Android path) | 4–5, S8 | Battery/lifecycle checks |
| 9 | Desktop managed install (`opencode service`, SHA-256), Windows/macOS validation | S4 | Install tests with fake origin; hash mismatch case |
| 10 | Data migration (copy v1 → v2), settings/themes/drafts/export/a11y/l10n port | 2–8 | Migration tests incl. rollback keys |
| 11 | **Second-adapter proof**: Codex/ACP fixture adapter implementing the same port | 4–7 | Port needs no OpenCode-specific change; if it does, fix the port before release |
| 12 | Platform builds: Android, Linux, macOS, Windows, Web (`make test-web`), iOS beta; RC | all | Final gates §8.4 |

**v2.1 (high level):** Stage H1 host skeleton with pairing and channel mux, then H2 Codex adapter (Dart) and host Codex bridge (S5), H3 Claude adapter and host SDK runner (S6), H4 host services (fs/git/pty/discovery), H5 push (ntfy/UnifiedPush/Web Push), H6 desktop harness install/update. **v2.2:** ACP generic adapter + Grok extensions, Muse (MSP), Pi (RPC), with S12.

---

## 8. Testing and validation

### 8.1 Contract fixtures and adapter tests

- **Fixture sets** (golden NDJSON/SSE): OpenCode (`plan/opencode-v2-src/client-solid-data.reference-reducer.ts` as the oracle for reducer parity), Codex (generated schema from `codex-src`), Muse (`harness-src/muse/transcripts/*.ndjson`, recorded conformance sessions [V]), ACP (`acp-src/schema`), Claude/Pi/Grok samples.
- **Reducer cases:**
  - out-of-order and duplicate events
  - delta after `ended`
  - gap then `ended` replaces text
  - reconnect mid-stream
  - unknown event types and fields
  - malformed JSON
  - heartbeat comments
  - backpressure disconnect
- **Permission races:**
  - double reply
  - reply after resolved elsewhere
  - child permission surfacing
  - `reject` with vs without message (turn ends vs continues [V])
  - allow-all with deny rules present
- **Ambiguous prompt delivery:** timeout after POST accepted; accepted but response lost; duplicate suppression; queued edit/cancel race.
- **Nested background tasks:** the known early-finish case; synthetic completion message; reconnect discovery via `parentID`.
- **External sessions:** list includes sessions not started by CodeWalk; ownership badge per §3.3; resume of Codex loaded thread replays pending approval.
- **Multi-host isolation:** same directory on two hosts → distinct `ProjectKey`; credentials/drafts scoped by host.
- **Upgrade/migration:** v1 data copy; failed migration leaves v1 keys intact.
- **Web:** origin/CORS/auth matrix (S11), `auth_token` query for EventSource/WS, mixed-content blocking.
- **iOS:** build and run on simulator; background/foreground lifecycle; local-network permission flow; no background-socket assumption.
- **Accessibility/responsiveness:** semantics labels for approvals/forms, large-text layouts, keyboard navigation, 3 breakpoints, reduced motion.
- **Performance budgets** (targets to confirm in Stage 4): streaming UI stays responsive with ~100 ms delta batches; list virtualization for long timelines; idle app generates no periodic network traffic beyond the SSE heartbeat; Android idle wakeups: none outside the FGS window.

### 8.2 Host tests (TypeScript)

Mocked-SDK tests for Claude callbacks; Codex UDS mock; ring-buffer resume and gap; auth/pairing expiry; process supervision (crash restart, orphan cleanup); fs/PTY permission scopes; per-harness adapter conformance against fixtures.

### 8.3 Proposed focused commands (not executed here)

```
export PATH="$HOME/flutter/bin:$PATH"
flutter test test/unit/harness/opencode
flutter test test/contract
flutter test test/widget/features/chat
```
Host: `npm test` in `host/`.

### 8.4 Final project gates

`make check` (normal validation; do not call `make precommit` directly), platform builds per project instructions, `make test-web`. Android release APK builds are unreliable on ARM64 Linux, so use an appropriate runner. iOS needs a macOS runner and signing. A code review is required after a coherent implementation.

---

## 9. Risks, assumptions, unresolved questions, execution start

### 9.1 Risks and mitigations

| Risk | Mitigation |
|---|---|
| OpenCode v2 API is labeled experimental; near-daily releases | Pin tested range, `/api/info` check, contract fixtures per release, feature flags for experimental routes (session log, stats) |
| Codex app-server and daemon are "experimental", weekly churn, CLI/daemon skew | Version registry, schema regeneration per release, handshake feature detection |
| Claude policy drift (changed 4 times in 2026), protocol churn | Never touch tokens; API-key mode as strict-compliance option; pin SDK+CLI; explicit `permissionMode` |
| Host as an attack surface (PTY/file write) | Loopback default, TLS required for non-loopback, scoped tokens, audit log |
| Two writers on one session file (Claude/Pi) | Fork default, recent-modification warning |
| Same-app-ID update strands v1 users | D04 reconsideration list |
| iOS scope (signing, VPN, background) | Beta, connect-only, explicit limits |
| Muse/Grok/dsh young protocols | Defer to v2.2/later; adapters behind version gating |
| Allow-all default is dangerous | First-run disclosure; per-host/per-session toggles; `once` semantics; red full-access control |

### 9.2 Assumptions and fallbacks (unverified items)

- [U] OpenCode TUI attaches to the shared service → S1; if false, D13 for OpenCode is list/history only.
- [U] Prompt id / inbox correlation → S2; fallback: ambiguous state plus bounded lookup.
- [U] `deny` enforcement under session wildcard → S3; fallback: avoid server wildcard entirely.
- [U] Title generation in v2 → check whether `opencode.session_rename` or automatic titling replaces the hidden title session; fallback: untitled sessions show the first prompt.
- [U] Claude `bypassPermissions` honors deny rules; interrupt bug status → S6.
- [U] Muse/Grok/Pi TUI coexistence → S12.
- [U] Android 15 `dataSync` FGS limits → S8.
- [U] Embedded Tailscale on iOS → S9.
- [U] Whether the Dart ACP packages (`dart_acp_sdk` 0.1.1, `acp_dart` 0.5.0) are suitable; evidence is README-level only [V `30` §table]. If unsuitable, implement the small ACP v1 subset ourselves from `acp-src/schema/v1`.

### 9.3 ADR exceptions to document if adopted

- Any server-side wildcard allow default (D05).
- Any iOS push relay (D08).
- ADR-043 shell-gated file writes retained as fallback.
- Experimental vendor usage endpoints (D06).
- Any intentional divergence from official OpenCode semantics (e.g., treating `ambiguous` sends).

### 9.4 Unresolved questions for discussion

1. Distinct legacy application ID or one ID with uninstall (D04)?
2. Whether to ship a final v1 release with an upgrade notice.
3. Accept the D05 implementation change (`once` auto-reply default)?
4. Accept an eventual CodeWalk push relay for iOS (D08 exception) or accept "no iOS background delivery"?
5. Host distribution: npm-only at first, or require the SEA binary before v2.1 GA?

### 9.5 Execution start (first steps; strict prerequisites)

1. Confirm clean tree and the `plan/` folder is preserved; create the `v1` maintenance branch from `14fbf519`/v1.265.0 **before** any skeleton work.
2. Run the read-only inventories: updater code (`lib/presentation/providers/settings_provider_update_install.dart`), Android `versionCode` derivation, `.github/workflows/` release/build jobs, and the `Makefile` test-web target (S10).
3. Run spikes S1–S4 and S11 against a real OpenCode 2.0.2x service on Linux. Record results in `plan/`.
4. Draft the v2 ADR and the capability/contract matrix before Stage 1 code.
5. Start Stage 1 using recorded fixtures first, the live server second.

**Prerequisites:** Flutter at `$HOME/flutter/bin`; an OpenCode v2 service on a test host; macOS runner and Apple signing for iOS; an ARM64-appropriate runner for Android release builds.

### 9.6 Source references

- Local: `plan/02-decisions.md`, `00` (inventory §0, §1.8, §3, §5), `10`–`13` (esp. `11` §1, §3, §D, §E; `12` §1.4, §4, §5, §7, §11), `20` §0–§1, `21` §0, `22`–`25` TL;DRs, `30` §0, `31` §2–§4, §17; `harness-src/muse/`, `acp-src/`, `opencode-v2-src/`.
- Official: `https://opencode.ai/v2/docs/`, `https://opencode.ai/v2/docs/migrate-v1/`, `https://opencode.ai/v2/openapi.json`, `https://github.com/anomalyco/opencode` branch `v2`; Codex `github.com/openai/codex` tag `rust-v0.160.0`; ACP `agentclientprotocol/agent-client-protocol` @ `9e032156`; OpenChamber `fc012ae0029fa2ac8d1d52b4af37040fc536258e` (secondary, OpenCode-only).
- **Not independently re-verified by me:** all external claims above are taken from the local pack with its labels. I did not fetch current upstream sources.