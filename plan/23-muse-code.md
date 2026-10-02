# 23 — Muse Code (Meta) as a CodeWalk harness

Research date: 2026-10-02. Tags: **[V]** = Verified (source cited), **[U]** = Unverified / inferred.
Raw extracts for offline planners: `plan/harness-src/muse/` — `msp-v1-stable.d.ts` (complete generated stable
wire types, 2529 lines), `msp-stable-manifest.json` (schema fingerprint), `sdk-ts-README.md`, and recorded
golden wire sessions in `transcripts/*.ndjson` (`{"dir":"client"|"server","raw":"<exact JSON-RPC frame>"}` per line).

## TL;DR

- **Exists and is official.** Muse Code is **Meta's** terminal coding agent (Meta Superintelligence Labs),
  launched **2026-08-05/06**, powered by the **Muse Spark** models; current release **1.4.2** (late Sept 2026). [V]
- **The CLI is proprietary/closed source**; the **SDK + protocol schema are MIT** (`meta-models/muse-code-sdk`). [V]
- **Official programmatic API: the Muse Session Protocol (MSP) v1** — JSON-RPC 2.0, NDJSON framing, served by
  **`muse serve` over stdio only**; stable since Muse Code 1.0.1, schema-fingerprinted, with official TS
  (`@muse-code/sdk`) and Python (`muse-code-sdk`) clients and recorded conformance transcripts. [V]
- **No network transport and no auth in MSP v1** ("Future transports (unix socket, websocket) are designed but
  deferred past v1"; "hosts must reject connections from non-spawning parties") → CodeWalk needs a host-side bridge. [V]
- MSP is unusually complete for a GUI client: session list/resume-by-cursor/fork/delete, **approvals with
  server-minted choices**, **agent questions (`userInput/request`)**, todo list, goals, subagents, user shell,
  steer/queue/unqueue/interrupt with retract, model + reasoning-effort, **subscription quota windows
  (5-hour + weekly) via `usage/read`/`usage/changed`**, context pressure, token usage. [V]
- ACP: **no documented official ACP command**; community adapters (BrokkAi/muse-acp in Rust, av/muse-code-acp in Node)
  translate ACP↔MSP. Not in the official ACP registry. [V]
- Verdict: **Integrable, best surface = MSP via a host bridge; medium–high effort; medium risk** (young protocol,
  "Developer Preview" docs label, proprietary + Meta account/subscription gated).

## 1. Identity

| Item | Value | Tag |
|---|---|---|
| Vendor | Meta Platforms (Meta Superintelligence Labs, led by Alexandr Wang) | [V] CNBC 2026-08-05; The Register 2026-08-06 |
| Product page / docs | https://developer.meta.com/ai/products/muse-code/ → 302 to https://dev.meta.ai/products/muse-code/ · user docs https://dev.meta.ai/docs/muse-code/ · developer (SDK/protocol) docs https://meta-models.github.io/muse-code-sdk/ (`next/`) | [V] |
| What it is | Terminal (TUI) coding agent / "agent orchestrator": multiple agents per task (workers in parallel, reviewers in background), worktrees, event-logged crash recovery, 1M-token context, MCP, hooks, skills, plugins, sandbox, voice, web search, computer use | [V] product page, CNBC, The Register, docs |
| License | CLI: proprietary (no public source; the SDK repo states files are mirrored from an internal "producing repository"; press: "proprietary and closed-weight"). SDK/protocol repo: **MIT** | [V] https://github.com/meta-models/muse-code-sdk README; The Register |
| Latest version | **1.4.2** — `@muse-code/sdk` "versions in lockstep with Muse Code" and 1.4.2 was published 2026-09-30; CHANGELOG top = 1.4.2. History: 0.2.1 → 1.0.1 (MSP + SDK published) → 1.0.2/1.0.3 → 1.1.1 → 1.2.1 → 1.4.0 → 1.4.1 → 1.4.2 | [V] npm view; CHANGELOG.md (mirrored) |
| Maturity | ~2 months public. Docs + SDK carry a **"Developer Preview"** banner ("no stability promise yet"), yet MSP stable surface promises additive evolution with deprecation path. | [V] SDK README, sdk-ts README |
| Default model | `muse-spark-1.2` (docs). Unofficial site musecodes.io claims Muse Spark 1.3 — unverified | [V]/[U] |
| Install | Product page: `curl https://dev.meta.ai/install.sh \| bash`. Docs page renders `curl -fsSL https://dev.ai/install.sh \| sh` and Windows `irm https://dev.ai/install.ps1 \| iex` (host discrepancy — **use dev.meta.ai**). Installer fetches `https://api.meta.ai/muse-launcher.sh`. Binary: `muse` (`muse --version`). | [V] (script inspected, not executed) |
| Platforms | Launcher supports `aarch64_macos`, `x86_macos`, **`aarch64_linux`**, `x86_linux`; Windows via PowerShell (x64 + ARM64 mentioned in changelog; WSL works). Product page says only "Available for MacOS and Windows" (stale). Windows lacks voice input and session messaging. | [V] muse-launcher.sh platform switch; docs |
| Auth | Browser sign-in with a Meta developer account (SSO) for subscription plans — Everyday $5/mo, High $15/mo, Power $50/mo (prompts per 5-hour window, e.g. 10–50) — **or** `META_API_KEY` pay-as-you-go (Muse Spark API $1.25/M input, $4.25/M output). `muse login`, `muse auth set`. A `muse serve` host started logged-out picks up a later device-code login. | [V] product page; CNBC; docs; CHANGELOG |

## 2. Programmatic surfaces

| Surface | How | Official? | Notes |
|---|---|---|---|
| **MSP v1 (`muse serve`)** | Spawn `muse serve` (optionally `--provider`, `--model`), write JSON-RPC 2.0 to stdin, read stdout. `muse schema` prints the schema. | Yes, **stable v1** (since 1.0.1: "`muse serve` and `muse schema` are available by default … The session protocol has a published, stable v1 schema") | **Primary**. stdio only; one connection per process; no auth |
| TS SDK | `npm install @muse-code/sdk` (Node ≥ 20, zero deps) — `MuseClient.spawn({museBin:"muse", args:["serve"], clientInfo})`, `client.startSession({workspaceRoot})`, `session.sendUserTurn({input:[{type:"text",text}]})`, `turn.items()`, `turn.deltas()`, `turn.completed`, `session.onApproval(...)`, client-side fold with gap recovery + idempotent retry | Yes (MIT) | Useful if the bridge is Node |
| Python SDK | `pip install muse-code-sdk` (module `muse_code`; sync + asyncio facades) — spawns `muse` from `PATH` or `muse_bin=` | Yes (MIT) | Bridge option |
| Headless | `muse exec "<prompt>"`, `--prompt-file`, `--json` (JSONL events), `--disable-approval` (keeps sandbox), `--yolo` (no approval, no sandbox), `--max-model-steps N`, `--session-id <uuid>` (resume), `--allow-workspace-switch`. Exit codes 0 done, 1 failed/cancelled, 2 usage, 130/143 signals | Yes | One-shot only |
| ACP | No documented `muse acp`. CHANGELOG line (1.2.x era): "Zed (ACP) adapter: session/set_mode now works" and "MSP/ACP clients get the permission prompt" — suggests an adapter exists somewhere, but no public command/doc found. Community: **BrokkAi/muse-acp** (Rust, one long-lived `muse serve`, ACP↔MSP), **av/muse-code-acp** (Node, ACP; needs Muse ≥ 1.1.1; no thinking stream). Not in the ACP registry. | Community | [V] community; official ACP **[U]** |
| MCP | Agent-side MCP client: `settings.json` `mcp_servers` (`stdio` / `streamable_http`), `muse mcp login|logout`; per-session `config.mcpServers` over MSP (capability `sessionMcp`) | Yes | |
| Extensibility | Hooks (`.muse/hooks.json`; events SessionStart, UserPromptSubmit, PreToolUse, PermissionRequest, PostToolUse, PostToolUseFailure, PreLLMCall, PostLLMCall, PreCompact, PostCompact, SubagentStart, SubagentStop, Notification, Stop, SessionEnd), skills (`.agents/skills/<id>/SKILL.md`, `~/.agents/skills`, `muse skills list|inspect|enable|validate`), plugins (can import Claude Code/Codex plugins) | Yes | |

Sources: https://dev.meta.ai/docs/muse-code/ · https://dev.meta.ai/docs/muse-code/extending · https://meta-models.github.io/muse-code-sdk/next/guides/msp-wire/ · …/framing-and-caps/ · https://github.com/meta-models/muse-code-sdk · https://github.com/BrokkAi/muse-acp · https://github.com/av/muse-code-acp [V]

## 3. MSP v1 protocol detail (verbatim)

### 3.1 Transport, framing, handshake [V] (msp-wire guides)

- "Stdio is the primary v1 transport. The client spawns `muse serve`, owns its stdin/stdout … Future transports
  (unix socket, websocket) are designed but deferred past v1." An in-process transport exists for the TUI only.
- "**No authentication mechanism exists in v1.** … hosts must reject connections from non-spawning parties.
  The `clientInfo` handshake parameter serves diagnostics and attribution only."
- NDJSON: one UTF-8 JSON-RPC message per line + single LF; CR tolerated on input, never emitted; empty lines ignored;
  every message carries `"jsonrpc":"2.0"`. Server frames totally ordered; view events cursor-ordered.
- Frame cap **10 MiB** both directions (`inputTooLarge` -32002, not retryable).
- Handshake: `initialize` → result → client notification `initialized`; nothing else is accepted before.
  Capabilities are fixed for the connection ("to change them, reconnect").

```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":{"name":"conformance","version":"0.0.0"},"capabilities":{"requestedCapabilities":["userShell"]}}}
{"id":1,"jsonrpc":"2.0","result":{"experimentalApi":false,"grantedCapabilities":["userShell"],"museHome":"/home/fixture/.muse","platformFamily":"unix","platformOs":"linux","schema":{"fingerprint":"sha256:c8d1…","version":1},"serverInfo":{"name":"muse-session-server","version":"0.0.0-fixture"},"sessionDurability":"durable","userAgent":"muse-session-server/0.0.0-fixture (linux; x86_64)"}}
{"jsonrpc":"2.0","method":"initialized"}
```

`ClientCapabilities`: `experimentalApi?`, `optOutNotificationMethods?`, `requestedCapabilities?` (registry:
`userShell`, `sessionMcp`, `sessionListStream`, `feedback`; docs also list `rawlog`), `userInputDialogs?` (absent = capable).

### 3.2 Commands, idempotency, cursors (concepts) [V] (msp.d.ts doc comments)

- Every mutating call carries a client-minted **`commandId` (UUIDv7)**; replaying the same command is
  value-identical (safe retry, never double-submits). Acks report **admission** (`status:"accepted"`); the
  authoritative outcome arrives on the **view stream**.
- Every view notification carries `sessionId`, opaque strictly-monotonic **`viewCursor`** (e.g. `"v:<sessionId>:7"`),
  usually `sourceRange` (durable records it folded from) and `emittedAtMs`.
- Reconnect: `session/resume {cursor}` returns only the suffix after a previously seen cursor and re-issues pending
  approvals/questions; `view/gap` signals dropped deliveries; `view/page` pages history; `approval/listPending`
  is the pull dual. → **Ideal for a phone that drops connections.**
- Item kinds are an **open enum**: render unknown kinds generically (kind + status + `fallbackText`).

### 3.3 Complete stable method index (verbatim `MspMethod`) [V]

`initialize` · `session/start` · `session/resume` · `session/fork` · `session/list` · `session/read` ·
`session/compact` · `session/delete` · `session/setModel` · `session/rename` · `session/setReasoningEffort` ·
`session/userShell` · `session/setApprovalMode` · `turn/start` · `turn/steer` · `turn/interrupt` · `turn/cancel` ·
`turn/unqueue` · `model/list` · `skill/list` · `task/background` · `task/stop` · `task/stopAll` · `goal/set` ·
`goal/edit` · `goal/clear` · `goal/pause` · `goal/resume` · `workflow/cancel` · `workflow/childControl` ·
`subagent/sendMessage` · `subagent/followupTask` · `subagent/interrupt` · `subagent/stop` · `subagent/resume` ·
`subagent/reopen` · `subagent/close` · `subagent/readResult` · `view/subscribe` · `view/unsubscribe` · `view/page` ·
`item/readOutput` · `approval/decide` · `approval/listPending` · `userInput/answer` · `userInput/cancel` ·
`userInput/clarify` · `usage/read` · `feedback/submit`.
(Docs also have pages for `account/loginStart|loginCancel|logout|read`, `hook/list`, `plugin/list` — not in the
stable index → experimental, require `experimentalApi:true`. [U])

**Notifications** (`MspNotification`): `initialized`, `session/started`, `session/closed`, `session/deleteCompleted`,
`skill/changed`, `turn/started`, `turn/completed`, `turn/retracted`, `turn/retryScheduled`, `turn/unqueued`,
`item/started`, `item/updated`, `item/delta`, `item/completed`, `view/gap`, `approval/requested`,
`approval/updated`, `approval/resolved`, `userInput/requested`, `userInput/settled`, `session/modelChanged`,
`session/reasoningEffortChanged`, `session/statusChanged`, `session/goalChanged`, `session/todoListChanged`,
`session/branchChanged`, `session/tokenUsage`, `session/contextUsage`, `session/approvalModeChanged`,
`session/modelRouteUnserved`, `session/nameChanged`, `session/viewHealthChanged`, `session/listChanged`, `usage/changed`.

**Server→client requests** (`MspServerRequest`): `approval/request`, `userInput/request`.

**Errors** (JSON-RPC codes; docs pages): parseError -32700, invalidRequest -32600, methodNotFound -32601,
invalidParams -32602, internal -32603, overloaded -32001, inputTooLarge -32002, capabilityRequired -32010,
notFound -32011, interrupted -32013, cancelled -32014, sessionNotFound -32020, sessionInUse -32021,
sessionAmbiguous -32022, forkBoundaryInvalid -32023, sessionNotLoaded -32024, sessionStreamMismatch -32025,
commandRejected -32030, backpressured -32031, skillNotFound -32032, viewTruncated -32040, outputUnavailable -32041,
boundaryPruned -32042, approvalNotFound -32050, approvalAlreadyResolved -32051, approvalChoiceInvalid -32052,
approvalRequirementStale -32053, approvalReviewerUnavailable -32054, userInputNotFound -32055,
userInputAlreadySettled -32056, userInputAnswerInvalid -32057, missingAnchor -32060, prunedPrefix -32061,
wrongStream -32062, unknownStream -32063, unknownProjection -32064.

### 3.4 Key payloads (from golden transcripts, verbatim, shortened with …)

Session start:
```json
{"jsonrpc":"2.0","id":2,"method":"session/start","params":{"commandId":"0198f0ab-9999-7000-8000-0000000000c1","workspaceRoot":"/home/me/src/proj"}}
{"jsonrpc":"2.0","method":"session/started","params":{"session":{"sessionId":"0198f0aa-…-0000000000aa","status":"idle","turnCount":0,"path":"/home/fixture/.muse/sessions/2026/08/07/0198f0aa-…/session.jsonl","createdAt":"2026-08-07T18:02:11.412Z","updatedAt":"…","workspaceRoot":"/home/me/src/proj","providerId":"muse","modelId":"muse-large-2","approvalMode":{"mode":"promptUnmatched","source":"startup","lastCommandId":null},"forkedFrom":null,"activeTurnId":null}},"emittedAtMs":1754590931500}
{"jsonrpc":"2.0","id":2,"result":{"session":{…},"viewCursor":"v:0198f0aa-…-0000000000aa:3"}}
```
`SessionStartParams`: `commandId` (req), `workspaceRoot?`, `workspaceRoots?` (multi-root, 1.4.2), `sessionId?`,
`modelId?`, `providerId?`, `approvalMode?`, `config?.mcpServers`.

Models:
```json
{"id":4,"jsonrpc":"2.0","method":"model/list","params":{"sessionId":"0198f0aa-…"}}
{"id":4,"jsonrpc":"2.0","result":{"providerId":"muse","profileId":null,"source":"bundledCatalog","models":[{"modelId":"muse-large-2","displayLabel":"Muse Large 2","providerId":"muse","profileId":null,"releaseDate":"2026-06-01","description":null,"contextLimit":200000,"outputLimit":64000,"cost":null,"isActive":true,"isDefault":true}, …]}}
```

Turn + streaming:
```json
{"jsonrpc":"2.0","id":3,"method":"turn/start","params":{"sessionId":"0198f0aa-…","commandId":"018f6a1e-9b3c-7c21-a54a-2f30bd3c9f10","input":[{"type":"text","text":"Run the agent test suite and summarize failures"}]}}
{"jsonrpc":"2.0","id":3,"result":{"commandId":"018f6a1e-…","status":"accepted","turnId":"018f6a1e-…","startedNewTurn":true,"disposition":"started"}}
{"jsonrpc":"2.0","method":"turn/started","params":{"sessionId":"…","viewCursor":"v:…:4","sourceRange":{…},"turnId":"018f6a1e-…","commandId":"018f6a1e-…"},"emittedAtMs":1754590940000}
{"jsonrpc":"2.0","method":"item/started","params":{"sessionId":"…","viewCursor":"v:…:6","item":{"itemId":"0198f0ac-4242-…","kind":"agentMessage","turnId":"018f6a1e-…","revision":1,"status":"inProgress","text":""}},"emittedAtMs":1754590941000}
{"jsonrpc":"2.0","method":"item/delta","params":{"sessionId":"…","viewCursor":"v:…:7","itemId":"0198f0ac-4242-…","field":"text","delta":"All 214 tests pass"},"emittedAtMs":1754590941100}
{"jsonrpc":"2.0","method":"item/completed","params":{"sessionId":"…","viewCursor":"v:…:9","sourceRange":{…},"item":{"itemId":"0198f0ac-4242-…","kind":"agentMessage","turnId":"018f6a1e-…","revision":2,"status":"completed","recordedAt":"2026-08-07T18:42:31.400Z","text":"All 214 tests pass except two in tbh-agent..."}},"emittedAtMs":1754590942000}
{"jsonrpc":"2.0","method":"turn/completed","params":{"sessionId":"…","viewCursor":"v:…:10","sourceRange":{…},"turnId":"018f6a1e-…","terminal":"completed","durationMs":48211,"timeToFirstTokenMs":902,"usage":{"inputTokens":48210,"outputTokens":1211,"cachedTokens":40100,"reasoningTokens":384}},"emittedAtMs":1754590990000}
```
Tool output streams as `item/delta` with `"field":"output"`. `TurnTerminal`: `completed` | `failed` | `cancelled`.
`TurnStartParams`: `commandId`, `sessionId`, `input: TurnInputPart[]`, `ifBusy?: "queue"|"steer"|"replace"` (default
`queue`), `reasoningEffort?`, `displayText?`, `workspaceRoots?`. `TurnStartDisposition`: `started` | `queued` | `steered`.
`TurnInputPart.type`: `"text"` | `"image"` (`base64Data`, `mediaType`, optional `width`+`height`) | `"skill"`
(`selector` from `skill/list`, `arguments?`). "**File mentions are text, not a part type: write `@relative/path` in a
text part.** A structured `mention` part is reserved and currently rejected."

Item kinds (`ItemKind`): `userMessage`, `agentMessage`, `reasoning`, `toolCall`, `userShell`, `subagent`, `workflow`,
`reminderChild`, `compaction` (open). `ItemStatus`: `inProgress`, `completed`, `failed`, `cancelled`, `rejected`, `timedOut`.
`toolCall` items carry `tool`, `callId`, `args` (verbatim JSON string), `approvalId`, `visibleOutput`, `outputRef`
and `patchRef` (structured patch → fetch via `item/readOutput` → diffs), `background`, `failureKind/Reason`.
`subagent` items carry `childSessionId` (drill down with `session/read`/`view/page`), `objective`, `depth`, `controlStatus`.

Approval round trip:
```json
{"jsonrpc":"2.0","id":1,"method":"approval/request","params":{"sessionId":"…","viewCursor":"v:…:7","approvalId":"0198f0ac-7777-…-0000000000e1","turnId":"018f6a1e-…","taskId":"0198f0ac-4000-…","itemId":"0198f0ac-4242-…","toolCallId":"call_9f21","toolName":"write_file","rawArgs":"{\"path\":\"Cargo.toml\"}","subject":{"kind":"fileAccess","toolName":"write_file","path":"/home/me/src/proj/Cargo.toml","access":"write"},"currentRequirementId":{"approvalId":"0198f0ac-7777-…","sourceIndex":0},"availableChoices":[{"choiceId":"allow_once","label":"Allow once","decision":"approved","scope":"once"},{"choiceId":"allow_session","label":"Allow for this session","decision":"approvedForSession","scope":"session","rulePreview":"write /home/me/src/proj/Cargo.toml"},{"choiceId":"abort","label":"Reject","decision":"abort","scope":"once","acceptsFeedback":true}],"protectedWrite":false,"judgeEscalated":false}}
{"jsonrpc":"2.0","id":1,"result":{}}
{"jsonrpc":"2.0","id":"b9","method":"approval/decide","params":{"sessionId":"…","commandId":"018f6a2a-3333-7abc-8def-00000000d001","approvalId":"0198f0ac-7777-…","requirementId":{"approvalId":"0198f0ac-7777-…","sourceIndex":0},"choiceId":"allow_session"}}
{"jsonrpc":"2.0","id":"b9","result":{"commandId":"018f6a2a-…","status":"accepted","approvalId":"0198f0ac-7777-…","terminal":true}}
{"jsonrpc":"2.0","method":"approval/resolved","params":{…,"decision":"approvedForSession","policyResult":"allow","amendment":{"durability":"session","rulePreview":"write /home/me/src/proj/Cargo.toml"},"resolvedBy":"user…"}}
```
Notes: the client answers the server request with an empty result, then decides via `approval/decide`.
Choices are **server-minted** (client must pick one of `availableChoices`; `feedback` only if `acceptsFeedback`).
Multi-stage approvals: a non-terminal decide is followed by an updated `approval/request` with a new `currentRequirementId`.
`ApprovalSubject.kind` ∈ `shell | fileAccess | network | unixSocket | process | tool`. `ApprovalDecision`: `approved`,
`approvedForSession`, `approvedPolicyAmendment`, `denied`, `deniedPolicyAmendment`, `timedOut`, `abort`.
Subagent approvals are projected onto the parent session with `subagentOrigin`.
**`ApprovalMode`** (closed enum, `session/setApprovalMode` / `session/start.approvalMode`): `"allowAll"` (global
allow-all) | `"promptUnmatched"` | `"onRequest"` | `"denyUnmatched"`. User-facing profiles: "Ask me", "Auto-review"
(model-based reviewer pre-clears safe requests), "Unrestricted" (= `--yolo`), "Read-only"; enterprise policy can restrict.
Sandbox: Seatbelt (macOS), bundled bubblewrap (Linux), Windows sandbox.

Cancel mid-turn:
```json
{"jsonrpc":"2.0","id":4,"method":"turn/cancel","params":{"sessionId":"…","commandId":"018f6a21-0f0f-7aaa-bbbb-0123456789ab","turnId":"018f6a1e-…"}}
{"jsonrpc":"2.0","id":4,"result":{"commandId":"018f6a21-…","status":"accepted","turnId":"018f6a1e-…"}}
```
`turn/interrupt {commandId, sessionId, turnId?, retract?}` — with `retract:true`, if nothing was committed the
submission is retracted (`turn/retracted`) so the UI can restore the prompt text. Done when `turn/completed` has `terminal:"cancelled"`.

Resume after reconnect:
```json
{"jsonrpc":"2.0","id":9,"method":"session/resume","params":{"commandId":"0198f0ab-8888-…","sessionId":"0198f0aa-…","cursor":"v:0198f0aa-…:405"}}
{"jsonrpc":"2.0","id":9,"result":{"session":{"sessionId":"…","status":"running","activeTurnId":"018f6a1e-…","turnCount":12,…}, …}}
{"jsonrpc":"2.0","method":"item/delta","params":{…,"viewCursor":"v:…:413","field":"text","delta":" and the fix is ready"}}
```
`SessionResumeParams`: `commandId`, `sessionId`, `cursor?`, `excludeItems?`, `history?` (mode preference;
served `HistoryMode` ∈ `inline` | `snapshot` | `anchoredSnapshot` | `none`), `config?`.

Other signatures:
- `session/list {cursor?, limit? (default 50, max 200), filter? {branch, sessionId, text}, updatedAfter?, workspaceRoot?}` → `{sessions…, nextCursor, appliedFilter?}`, ordered `updatedAt` desc; live row updates via `session/listChanged` (capability `sessionListStream`). `SessionStatus`: `notLoaded` | `idle` | `running`; `session/statusChanged` includes an attention flag when an approval/input is pending.
- `session/fork {commandId, sessionId, cutPoint?, excludeItems?}` → new session (`forkedFrom` provenance).
- `turn/steer {commandId, sessionId, expectedTurnId, input, reasoningEffort?}` (race-safe exact-target steering); `turn/unqueue` + `turn/unqueued` (reclaim a queued prompt).
- `ReasoningEffort`: `"none" | "minimal" | "low" | "medium" | "high" | "xhigh" | "max" | "ultra"`; `session/setReasoningEffort`, per-turn override.
- `session/userShell {commandId, sessionId, commandText}` (capability `userShell`) → `userShell` item (`exitCode`, `exitSignal`, `outputRef`).
- `userInput/request` (agent questions): `{userInputId, sessionId, turnId, itemId, toolCallId, toolName, questions:[{id, header, question, options[], selection:{mode:"single"|"multiple", maxSelections?…}}], autoResolutionMs?}`; answer with `userInput/answer` (`selectedLabel` | `selectedLabels` | `freeText` ≤500 chars, optional `note`), or `userInput/cancel` / `userInput/clarify`; outcome `userInput/settled` (`answered|cancelled|interrupted|clarified|timedOut|aborted`).
- `session/todoListChanged {todos:[{text, status:"pending"|"inProgress"|"completed"|"cancelled", activeForm?}]}`.
- `session/tokenUsage {cumulative, promptTokens, totalTokens, usage, modelId, turnId, finishReason?, durationMs?}`; `session/contextUsage {usedTokens, windowTokens?, pressure}`.
- `usage/read` → `{usage?: {tier, observedAtMs, weekly:{usedPercent, resetsAtMs}, window:{usedPercent, resetsAtMs, windowDurationMins}}}` (`window` = "the provider's 5-hour-class block"; percentages may exceed 100); `usage/changed` pushes the same `SubscriptionUsage` shape ("returns the last-seen 5-hour and weekly windows without spending a prompt").
- `CumulativeTokenUsage {promptTokens, outputTokens, totalTokens, cacheReadTokens?, cacheWriteTokens?, cost?: {usd, partial}}` — server-computed estimated session cost (absent when unpriced).
- `skill/list` → `{skills:[…]}`; `skill/changed`.

## 4. Capability mapping (CodeWalk needs → Muse Code / MSP)

| Capability | Mechanism | Status |
|---|---|---|
| Network reachability from phone | stdio only, no auth (v1) → host bridge (relay stdio ↔ authenticated WebSocket) | **Missing → bridge** |
| Multiple sessions per connection | Every call carries `sessionId`; leases (`sessionInUse`) | Native |
| New / list / resume / read / rename / delete | `session/start`, `session/list` (+`listChanged`), `session/resume` (cursor), `session/read`, `session/rename`, `session/delete` | Native |
| Reconnect without loss | `viewCursor` + `session/resume {cursor}` + `view/gap` + `view/page` + `approval/listPending` | Native (excellent) |
| Fork | `session/fork {cutPoint}` | Native |
| Undo / rewind | TUI double-Esc rewind; over MSP only fork-at-cutPoint and interrupt+retract | Partial |
| Prompt + text/reasoning stream | `turn/start`; `item/delta` (`field:"text"`); `reasoning` items | Native |
| Tool calls / results / diffs | `toolCall` items; `item/delta field:"output"`; `item/readOutput` (`outputRef`, `patchRef`) | Native |
| Permission requests | `approval/request` (server→client) + `approval/decide`; multi-stage; subagent projection | Native |
| Global allow-all | `session/setApprovalMode {mode:"allowAll"}` (policy may forbid) | Native |
| Agent questions | `userInput/request` / `userInput/answer` | Native |
| Errors | JSON-RPC error codes table; `turn/completed terminal:"failed"`; `turn/retryScheduled` | Native |
| Tokens / context | `turn/completed.usage`, `session/tokenUsage`, `session/contextUsage` | Native |
| Cost | `CumulativeTokenUsage.cost {usd, partial}` (server-estimated session cost); `model/list.cost` | Native |
| Quotas / rate limits | `usage/read`, `usage/changed` (5-hour + weekly windows, %) | **Native (maps to CodeWalk quota popover)** |
| Interrupt / stop | `turn/interrupt` (retract), `turn/cancel`, `task/stop`, `task/stopAll` | Native |
| Mid-turn messages | `turn/start ifBusy:"queue"|"steer"|"replace"`, `turn/steer`, `turn/unqueue` | Native |
| Slash commands | Skills only (`skill/list` + `skill` input part); built-in TUI commands not exposed | Partial |
| Skills | `skill/list`, `skill/changed`, `TurnInputPart{type:"skill"}` | Native |
| @file mentions | `@relative/path` inside text | Native (text-only) |
| File search / browse | None in MSP | Missing (bridge) |
| Images | `TurnInputPart{type:"image", base64Data, mediaType}` | Native |
| Model selection | `model/list`, `session/setModel`, `session/modelChanged`, `session/modelRouteUnserved` | Native |
| Agent selection | No agent/persona selector in stable MSP | Missing [U] |
| Thinking effort | `session/setReasoningEffort`, per-turn `reasoningEffort` (`none…ultra`) | Native |
| Subagents | `subagent` items + `subagent/*` methods; workflows (`workflow/*`); background tasks | Native |
| Todo / plan / goals | `session/todoListChanged`; `goal/*` + `session/goalChanged` | Native |
| Terminal / user shell | `session/userShell` (capability) | Native |
| Compaction | `session/compact`; `compaction` items | Native |
| MCP per session | `session/start.config.mcpServers` (capability `sessionMcp`) | Native |

## 5. Verdict

**Integrable — best surface is MSP v1 (`muse serve`) behind a host-side bridge.** The bridge can be a dumb
authenticated stdio↔WebSocket relay (MSP already handles cursors, gap recovery, idempotent retries, late-joiner
approval replay), plus process supervision (keep `muse serve` alive while the phone sleeps), file browsing/search
(missing from MSP), and optional TLS. Alternatively a Node bridge using `@muse-code/sdk`.

- Effort: **medium–high** (protocol is large; Dart needs UUIDv7 command ids, a fold of item revisions, cursor
  bookkeeping, approval stage guards). Functionally it is the closest of the four to CodeWalk's OpenCode feature set,
  including quota windows.
- Risk: **medium** — proprietary binary, Meta account/subscription or `META_API_KEY` required, ~2-month-old
  protocol, "Developer Preview" docs label; but the stable surface is fingerprinted (`schema.fingerprint`) and
  evolution is additive. Use the fingerprint check (`EXPECTED_SCHEMA_FINGERPRINT` in the SDK) to detect drift.
- If CodeWalk instead adopts a generic ACP client, the community `BrokkAi/muse-acp` adapter is a lossy fallback.

## 6. Sources

- https://developer.meta.com/ai/products/muse-code/ (→ https://dev.meta.ai/products/muse-code/) · https://dev.meta.ai/docs/muse-code/ · https://dev.meta.ai/docs/muse-code/extending · https://dev.meta.ai/docs/muse-code/permissions
- https://www.cnbc.com/2026/08/05/meta-debuts-muse-code-to-take-on-anthropic-and-openai-.html · https://www.theregister.com/ai-and-ml/2026/08/06/meta-wants-to-get-inside-your-terminal-with-its-new-coding-agent/5283717
- https://github.com/meta-models/muse-code-sdk (README, CHANGELOG.md, schema/msp/msp.d.ts, schema/msp/stable/manifest.json, schema/msp/transcripts/*) · https://www.npmjs.com/package/@muse-code/sdk
- https://meta-models.github.io/muse-code-sdk/next/ · …/next/guides/msp-wire/ · …/next/guides/msp-wire/framing-and-caps/ · …/next/generated/msp/methods/ · …/next/generated/msp/errors/
- https://dev.meta.ai/install.sh → https://api.meta.ai/muse-launcher.sh (platform switch inspected, not executed)
- https://github.com/BrokkAi/muse-acp · https://github.com/av/muse-code-acp · https://github.com/agentclientprotocol/registry (no muse entry)
- Secondary: https://www.sitepoint.com/muse-code-meta-terminal-coding-agent/ · https://innfactory.ai/en/ai-harness/muse/ (conflicting open-source claims; Meta sources win)
