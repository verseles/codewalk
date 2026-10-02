# 12 — OpenCode v2: events, streaming, status, errors, schemas, permissions, forms, subagents

> Source-verified against `anomalyco/opencode@v2.0.21` (commit `8a8bd622`). **V2** = `https://github.com/anomalyco/opencode/blob/v2.0.21/`, **V1** = `https://github.com/anomalyco/opencode/blob/v1.18.34/`.
> TypeScript blocks marked *generated* are verbatim from V2 `packages/client/src/promise/generated/types.ts` (the encoded wire shapes); blocks marked *Effect schema* are verbatim from V2 `packages/schema/src/*.ts`. Anything not read directly in code is marked **(inferred)**.
> The official reference implementation of "events → client state" is V2 `packages/client/src/solid/data.ts` (`handleEvent`, line 593; saved as `plan/opencode-v2-src/client-solid-data.reference-reducer.ts`). CodeWalk should port its logic.

---

## 1. The SSE stream: `GET /api/event`

### 1.1 Framing (V2 `packages/server/src/handlers/event.ts#L9-L38`, `packages/server/src/event-feed.ts#L29-L31`)

- One **global** stream for the whole server (all directories/locations, all sessions). There is no per-directory stream any more and no `/global/event` wrapper.
- Headers: `content-type: text/event-stream`, `Cache-Control: no-cache, no-transform`, `X-Accel-Buffering: no`.
- Each event is exactly one frame **`data: <JSON>\n\n`** — no `event:` field, no `id:` field (so `Last-Event-ID` resumption does not exist).
- **Heartbeat** = SSE *comment* line **`: heartbeat\n\n` every 15 s** (not a JSON event; v1 sent `server.heartbeat` JSON events every 10 s).
- First frame is always `{"id":"evt_…","type":"server.connected","data":{}}`.
- Volatile by contract: per-subscriber bounded queue of **4 096** frames; a slow consumer is **disconnected** (stream fails with `EventFeed.SubscriberOverflow`), and events emitted while disconnected are lost (V2 `packages/server/src/event-feed.ts#L8`, `#L48-L70`; endpoint description V2 `packages/protocol/src/groups/event.ts#L44-L55`).
- The generated client parser (useful as a spec for a Dart parser): splits on blank lines, concatenates `data:` lines, ignores comment lines, max 16 MiB per event (V2 `packages/client/src/promise/generated/client.ts#L360-L416`).
- Reference reconnect policy: connect timeout 2 s, reconnect delay 1 s, **idle watchdog 45 s** (no bytes, including heartbeats → abort and reconnect), foreground re-check at 20 s after device sleep (V2 `packages/client/src/solid/connection.ts#L31-L38`).

### 1.2 Event envelope (*generated*, every member of the `V2Event` union has this shape)

```ts
type V2EventEnvelope = {
  id: string                         // "evt_…" (ascending)
  created: number                    // epoch ms
  metadata?: { [x: string]: any }    // host annotations
  type: string                       // discriminator, e.g. "session.text.delta"
  durable?: { aggregateID: string; seq: number; version: number } // present ONLY on durable events
  location?: { directory: string; workspaceID?: string }          // set for location-scoped events
  data: { … }                        // event-specific payload (table §2)
}
```
Construction: `Event.durable(...)` / `Event.ephemeral(...)` in V2 `packages/schema/src/event.ts#L83-L148`. **Durable** events are persisted in the session's (or worktree's) append-only log with a monotonically increasing `durable.seq` per `aggregateID` (= `sessionID` for all `session.*` durable events) and are folded by the server projector into the queryable message/session tables. **Ephemeral** events (all `*.delta`, `session.tool.progress`, `session.usage.updated`, `permission.*`, `form.*`, catalog `*.updated`, …) are live-only.

v1 envelope for comparison: `{id, type, properties}` (and `{directory, project?, workspace?, payload}` on `/global/event`) (V1 `packages/opencode/src/server/routes/instance/httpapi/handlers/event.ts#L37-L44`).

### 1.3 Which events are on the stream

The public union is `EventManifest.ServerDefinitions` + `rpc.*` + `server.connected` (V2 `packages/schema/src/event-manifest.ts#L71-L84`, `packages/protocol/src/groups/event.ts#L14-L38`). Server-side filter `isOpenCodeEvent` drops everything else (e.g. `lsp.*`, `workspace.*`, legacy v1 events, `session.compacted`, `global.disposed`, internal `session.usage.recorded`, `session.message.content.updated`). Clients filter by `data.sessionID` and/or `location.directory` themselves.

### 1.4 Gap-free resync: the durable session log

`GET /api/experimental/session/{sessionID}/log?after=<seq>&follow=true|false` (SSE, same `data:` framing) streams `SessionLogItem = Session.Event.Durable | {type:"log.synced", aggregateID, seq?}`: all durable events with `durable.seq > after`, then exactly one `log.synced` marker at the captured watermark, then (if `follow=true`) live durable events (V2 `packages/protocol/src/groups/session.ts#L724-L743`, core contract V2 `packages/core/src/session.ts#L159-L169`). The marker's `seq` may exceed the last emitted event (internal durable events share the sequence space). Ephemeral deltas are never in the log.

**Recommended CodeWalk strategy (inferred from the above + reference client):**
1. On (re)connect to `/api/event` wait for `server.connected`, then re-hydrate: `GET /api/session/active`, `GET /api/session/{id}` + `GET /api/session/{id}/message?order=desc&limit=…` + `GET /api/session/{id}/inbox` + `GET /api/session/{id}/permission` + `GET /api/session/{id}/form` for the visible session(s) (the reference client does this through invalidate/sync, V2 `packages/client/src/solid/data.ts#L593-L627`).
2. Track the highest `durable.seq` seen per session; for a session that matters, optionally call the log endpoint with `after=<lastSeq>&follow=false` to apply missed durable events exactly once (experimental endpoint).
3. Text/reasoning that was mid-stream during the gap: projected history only contains `text.started` (empty part) until `text.ended` (deltas are not projected — V2 `packages/core/src/session/projector.ts#L699-L707`); new deltas after reconnect append to an incomplete prefix, and `session.text.ended` replaces the whole text with the authoritative value. Render "…" until then.

---

## 2. Complete event catalogue (94 types on `/api/event`)

`data` shapes are verbatim (*generated*); referenced types are defined in §3–§10. Durable vN = schema version in `durable.version`.

| type | durability | `data` | client handling / notes |
|---|---|---|---|
| `location.shutdown` | ephemeral | `{}` | Published when a location is shut down/rebuilt (`/api/location/reload`, eviction); refetch location catalogs. `location` = affected dir. |
| `models-dev.refreshed` | ephemeral | `{}` | models.dev catalog refreshed → refetch `/api/model`. |
| `credential.updated` | ephemeral | `{}` | Global (`{global:true}`) → refetch integrations/models/providers. |
| `credential.switched` | ephemeral | `{ integrationID: string; credentialID: string \| null }` | Active credential for an integration changed. |
| `integration.updated` | ephemeral | `{}` | Refetch `/api/integration`, `/api/model`, `/api/provider` for `location`. |
| `provider.updated` | ephemeral | `{}` | Refetch `/api/provider`. |
| `model.updated` | ephemeral | `{}` | Refetch `/api/model`. |
| `agent.updated` | ephemeral | `{}` | Refetch `/api/agent`. |
| `session.created` | durable v1 | `{ sessionID: string projectID: string location: LocationRef subpath?: string parentID?: string slug: string title?: string agent?: string model?: ModelRef metadata?: SessionMetadata permissions?: PermissionRuleset version: string }` | New session (incl. subagent children: `parentID` set). Not emitted for forks. |
| `session.agent.selected` | durable v1 | `{ sessionID: string; agent: string; previous?: string }` | Projects an `agent-switched` message (id = msg_ of event id). |
| `session.model.selected` | durable v1 | `{ sessionID: string; model: ModelRef; previous?: ModelRef }` | Projects a `model-switched` message. |
| `session.moved` | durable v1 | `{ sessionID: string; location: LocationRef; projectID: string; subpath?: string }` | Projects a `location-switched` message; update Session.Info.location/projectID/subpath. |
| `session.renamed` | durable v1 | `{ sessionID: string; title: string }` | Title changed (incl. automatic title generation). |
| `session.metadata.updated` | durable v1 | `{ sessionID: string; metadata: SessionMetadata }` |  |
| `session.permissions` | durable v1 | `{ sessionID: string; permissions: PermissionRuleset }` | Session ruleset replaced. |
| `session.viewed` | durable v1 | `{ sessionID: string; idle: number }` | Unread watermark updated. |
| `session.usage.updated` | ephemeral | `{ sessionID: string; cost: MoneyUSD; tokens: TokenUsageInfo }` | Running totals for Session.Info.cost/tokens. |
| `session.deleted` | durable v2 | `{ sessionID: string }` | Remove session (children get their own events). |
| `session.forked` | durable v2 | `{ sessionID: string parentID: string boundary: SessionForkBoundary instructions?: { [x: string]: string } instructionEntries?: InstructionEntrySnapshot }` | New fork session (root, `fork.sessionID` = source) — fetch it with `GET /api/session/{sessionID}`. |
| `session.inbox.delivered` | durable v1 | `{ sessionID: string; inboxID: string }` | Pending input promoted into history (user/synthetic message now part of the turn; set its time.created = event.created and move it to the end). |
| `session.inbox.enqueued` | durable v1 | `{ sessionID: string; inboxID: string; item: SessionInboxItem }` | Input admitted (`item.type` user / synthetic / compaction / move, `delivery`). User/synthetic items are shown immediately. |
| `session.inbox.cancelled` | durable v1 | `{ sessionID: string; inboxID: string }` | Remove pending input (and its optimistic row). |
| `session.inbox.delivery.changed` | durable v1 | `{ sessionID: string; inboxID: string; delivery: SessionInboxDelivery }` | steer↔queue. |
| `session.execution.started` | durable v1 | `{ sessionID: string }` | Session became BUSY (process-local execution started). |
| `session.execution.succeeded` | durable v1 | `{ sessionID: string }` | Session IDLE; projects `idle {outcome:"succeeded"}` marker. |
| `session.execution.failed` | durable v1 | `{ sessionID: string; error: SessionStructuredError }` | Session IDLE with error; projects `idle {outcome:"failed"}`. |
| `session.execution.interrupted` | durable v1 | `{ sessionID: string; reason: "user" \| "shutdown" \| "superseded" \| "inactivity" }` | Session IDLE; reason user / shutdown / superseded / inactivity. `shutdown` keeps the claim (turn resumes on next server start) and projects no idle marker. |
| `session.instructions.updated` | durable v2 | `{ sessionID: string; delta: { [x: string]: string \| "removed" }; text?: string }` | Projects a `system` message when `text` present. |
| `session.synthetic` | durable v1 | `{ sessionID: string; text: string; description?: string; metadata?: { [x: string]: any } }` | Projects a `synthetic` message (used for subagent/shell completion notices). |
| `session.skill.activated` | durable v1 | `{ sessionID: string; id: string; name: string; text: string }` | Projects a `skill` message. |
| `session.shell.started` | durable v1 | `{ sessionID: string; shell: ShellInfo }` | Projects a `shell` message (status running). |
| `session.shell.ended` | durable v1 | `{ sessionID: string shell: ShellInfo output: { output: string; cursor: number; size: number; truncated: boolean } }` | Completes the `shell` message (status, exit, output preview). |
| `session.step.started` | durable v1 | `{ sessionID: string assistantMessageID: string agent: string model: ModelRef snapshot?: string started: number }` | Creates the ASSISTANT message `assistantMessageID` (one per model call/step); also re-used on retry. |
| `session.step.streamed` | durable v1 | `{ sessionID: string; assistantMessageID: string }` | Provider response body ended (assistant.time.streamed). |
| `session.step.ended` | durable v1 | `{ sessionID: string assistantMessageID: string finish: "stop" \| "length" \| "tool-calls" \| "content-filter" \| "error" \| "unknown" rawFinish?: string providerState?: SessionMessageProviderState1 cost: MoneyUSD tokens: TokenUsageInfo snapshot?: string files?: Array<string> }` | Step finished: finish reason, cost, tokens, snapshot (assistant.time.completed). |
| `session.step.failed` | durable v1 | `{ sessionID: string assistantMessageID: string error: SessionStructuredError finish?: "content-filter" rawFinish?: string providerState?: SessionMessageProviderState1 cost?: MoneyUSD tokens?: TokenUsageInfo snapshot?: string files?: Array<string> }` | Step failed: assistant.error (+ optional usage). |
| `session.text.started` | durable v1 | `{ sessionID: string; assistantMessageID: string; ordinal: number }` | Append `{type:"text", text:""}` to assistant.content. |
| `session.text.delta` | ephemeral | `{ sessionID: string; assistantMessageID: string; ordinal: number; delta: string }` | Append `delta` to the LAST text part (batched ~100 ms). |
| `session.text.ended` | durable v1 | `{ sessionID: string assistantMessageID: string ordinal: number text: string state?: SessionMessageProviderState1 }` | Replace that text part with the full `text` (authoritative). |
| `session.reasoning.started` | durable v1 | `{ sessionID: string; assistantMessageID: string; ordinal: number; state?: SessionMessageProviderState1 }` | Append `{type:"reasoning", text:""}`. |
| `session.reasoning.delta` | ephemeral | `{ sessionID: string; assistantMessageID: string; ordinal: number; delta: string }` | Append to last open reasoning part. |
| `session.reasoning.ended` | durable v1 | `{ sessionID: string assistantMessageID: string ordinal: number text: string state?: SessionMessageProviderState1 }` | Replace with full text; set time.completed. |
| `session.tool.input.started` | durable v1 | `{ sessionID: string; assistantMessageID: string; id: string; name: string }` | Append tool part `{id, name, state:{status:"streaming", input:""}}`. |
| `session.tool.input.delta` | ephemeral | `{ sessionID: string; assistantMessageID: string; id: string; delta: string }` | Append raw JSON fragment to `state.input`. |
| `session.tool.input.ended` | durable v1 | `{ sessionID: string; assistantMessageID: string; id: string; text: string }` | Final raw input string. |
| `session.tool.called` | durable v1 | `{ sessionID: string assistantMessageID: string id: string input: { [x: string]: any } executed: boolean state?: SessionMessageProviderState1 }` | state → `running {input (parsed), metadata:{}}`; time.ran. |
| `session.tool.progress` | ephemeral | `{ sessionID: string; assistantMessageID: string; id: string; metadata: { [x: string]: JsonValue } }` | Replace running `state.metadata` (ephemeral; e.g. subagent `{sessionID,status}`, shell output preview). |
| `session.tool.success` | durable v2 | `{ sessionID: string assistantMessageID: string id: string content: [ToolContent1, ...Array<ToolContent1>] metadata?: { [x: string]: JsonValue } executed: boolean resultState?: SessionMessageProviderState1 }` | state → `completed {input, content[], metadata}`; time.completed. |
| `session.tool.failed` | durable v2 | `{ sessionID: string assistantMessageID: string id: string error: SessionStructuredError content?: [ToolContent1, ...Array<ToolContent1>] metadata?: { [x: string]: JsonValue } executed: boolean resultState?: SessionMessageProviderState1 }` | state → `error {input, error, content?, metadata?}`. |
| `session.retry.scheduled` | durable v1 | `{ sessionID: string; assistantMessageID: string; attempt: number; at: number; error: SessionStructuredError }` | assistant.retry = {attempt, at, error}; cleared by next step.started / execution end. |
| `session.compaction.started` | durable v1 | `{ sessionID: string; reason: "auto" \| "manual"; recent: string; inputID?: string }` | Projects a running `compaction` message (id = inputID or msg_ of event). |
| `session.compaction.delta` | ephemeral | `{ sessionID: string; text: string }` | Append to running compaction summary. |
| `session.compaction.ended` | durable v1 | `{ sessionID: string reason: "auto" \| "manual" model?: ModelRef providerState?: SessionMessageProviderState1 providerContext?: SessionProviderContext text: string recent: string cost?: MoneyUSD tokens?: TokenUsageInfo }` | Compaction completed (summary + usage). |
| `session.compaction.failed` | durable v1 | `{ sessionID: string reason: "auto" \| "manual" error: SessionStructuredError inputID?: string cost?: MoneyUSD tokens?: TokenUsageInfo }` | Compaction failed. |
| `session.revert.staged` | durable v1 | `{ sessionID: string; revert: SessionRevert }` | Session.Info.revert set. |
| `session.revert.cleared` | durable v1 | `{ sessionID: string }` | Session.Info.revert cleared. |
| `session.revert.committed` | durable v1 | `{ sessionID: string; to: string }` | Drop messages and pending inputs with id ≥ `to`. |
| `filesystem.changed` | ephemeral | `{ file: string; event: "add" \| "change" \| "unlink" }` | File watcher (v1 `file.watcher.updated`). |
| `reference.updated` | ephemeral | `{}` | Refetch `/api/reference`. |
| `permission.asked` | ephemeral | `{ id: string sessionID: string action: string resources: Array<string> save?: Array<string> metadata?: { [x: string]: any } source?: PermissionSource message?: string }` | Pending permission request (see §7). |
| `permission.replied` | ephemeral | `{ sessionID: string; requestID: string; reply: PermissionReply }` | Request resolved (`reply` once / always / reject); remove it. |
| `plugin.updated` | ephemeral | `{}` | Refetch `/api/plugin`. |
| `project.updated` | ephemeral | `{ id: string canonical: string vcs?: ProjectVcs name?: string icon?: ProjectIcon commands?: ProjectCommands time: ProjectTime sandboxes: Array<string> }` | Full Project payload. |
| `worktree.updated` | ephemeral | `{ projectID: string }` | Refetch `/api/worktree`. |
| `worktree.resolved` | durable v1 | `{ projectID: string; directory: string; previous: string; adopted?: Array<string> }` | Durable; worktree canonicalization (sessions may change projectID/subpath). |
| `command.updated` | ephemeral | `{}` | Refetch `/api/command`. |
| `config.updated` | ephemeral | `{}` | Refetch `/api/config`. |
| `skill.updated` | ephemeral | `{}` | Refetch `/api/skill`. |
| `pty.created` | ephemeral | `{ info: Pty }` | PTY lifecycle. |
| `pty.updated` | ephemeral | `{ info: Pty }` | PTY lifecycle. |
| `pty.exited` | ephemeral | `{ id: string; exitCode: number }` | PTY lifecycle. |
| `pty.deleted` | ephemeral | `{ id: string }` | PTY lifecycle. |
| `persistent-pty.added` | ephemeral | `{ sessionID: string; terminal: PersistentPtyInfo }` | Experimental session terminals. |
| `persistent-pty.removed` | ephemeral | `{ sessionID: string; ptyID: string }` | Experimental session terminals. |
| `shell.created` | ephemeral | `{ info: ShellInfo }` | Non-interactive shell job lifecycle. |
| `shell.exited` | ephemeral | `{ id: string; exit?: number; status: "running" \| "exited" \| "timeout" \| "killed" }` | Shell job lifecycle. |
| `shell.deleted` | ephemeral | `{ id: string }` | Shell job lifecycle. |
| `form.created` | ephemeral | `{ form: FormInfo1 }` | Pending form (question tool `metadata.kind:"question"`, `websearch.provider`, `mcp-elicitation`). |
| `form.replied` | ephemeral | `{ id: string; sessionID: string; answer: FormAnswer2 }` | Form answered. |
| `form.cancelled` | ephemeral | `{ id: string; sessionID: string }` | Form cancelled. |
| `websearch.updated` | ephemeral | `{}` | Refetch websearch providers. |
| `session.status` | ephemeral | `{ sessionID: string; status: SessionStatus }` | **Declared but no publisher in v2.0.21 core/server** (inferred legacy; use execution/retry events). |
| `session.idle` | ephemeral | `{ sessionID: string }` | Declared "deprecated"; **no publisher found** (inferred). |
| `tui.prompt.append` | ephemeral | `{ text: string }` | **No publisher found in v2 packages** (TUI remote-control legacy; inferred). |
| `tui.command.execute` | ephemeral | `{ command: \| "session.list" \| "session.new" \| "session.share" \| "session.interrupt" \| "session.background" \| "session.compact" \| "session.page.up" \| "session.page.down" \| "session.line.up" \| "session.line.down" \| "session.half.page.up" \| "session.half.page.down" \| "session.first" \| "session.last" \| "prompt.clear" \| "prompt.submit" \| "agent.cycle" \| (string & {}) }` | No publisher found (inferred). |
| `tui.toast.show` | ephemeral | `{ title?: string message: string variant: "info" \| "success" \| "warning" \| "error" duration?: number \| undefined }` | No publisher found (inferred). |
| `tui.session.select` | ephemeral | `{ sessionID: string }` | No publisher found (inferred). |
| `installation.updated` | ephemeral | `{ version: string }` | Published by the managed service after an update. |
| `installation.update-available` | ephemeral | `{ version: string }` | Published by the managed service. |
| `vcs.branch.updated` | ephemeral | `{ branch?: string }` | Branch changed for `location`. |
| `mcp.status.changed` | ephemeral | `{ server: string }` | One per MCP server status change → refetch `/api/mcp`. |
| `mcp.resources.changed` | ephemeral | `{ server: string }` | Refetch `/api/mcp/resource`. |
| ``${"rpc."}${string}`` | ephemeral | `{ [x: string]: any }` |  |
| `server.connected` | ephemeral | `{}` | First frame of every stream (resync trigger). |

---

## 3. Message model (what `GET /api/session/{id}/message` returns and what events build)

v2 has **no Message+Part split and no `role`**: a session timeline is a flat, ordered list of typed messages. An assistant message = **one model call ("step")** and owns an ordered `content[]` of `text` / `reasoning` / `tool` items. Defined in V2 `packages/schema/src/session-message.ts` (union at `#L295-L320`), public variant in V2 `packages/protocol/src/groups/message.ts#L52-L64`.

```ts
// generated (packages/client/src/promise/generated/types.ts)
export type SessionMessageInfo =
  | SessionMessageAgentSelected
  | SessionMessageModelSelected
  | SessionMessageLocationSwitched
  | SessionMessageUser
  | SessionMessageSynthetic
  | SessionMessageSystem
  | SessionMessageSkill
  | SessionMessageShell
  | SessionMessageAssistant
  | SessionMessageCompaction
  | SessionMessageIdle

export type SessionMessageAgentSelected = {
  id: string
  metadata?: { [x: string]: JsonValue }
  time: { created: number }
  type: "agent-switched"
  agent: string
  previous?: string
}

export type SessionMessageModelSelected = {
  id: string
  metadata?: { [x: string]: JsonValue }
  time: { created: number }
  type: "model-switched"
  model: ModelRef
  previous?: ModelRef
}

export type SessionMessageLocationSwitched = {
  id: string
  metadata?: { [x: string]: JsonValue }
  time: { created: number }
  type: "location-switched"
  projectID?: string
  subpath?: string
  location: LocationPublicRef
  previous?: { location: LocationPublicRef; projectID?: string; subpath?: string } | null
}

export type SessionMessageUser = {
  id: string
  metadata?: { [x: string]: JsonValue }
  time: { created: number }
  text: string
  files?: Array<PromptFileAttachment>
  agents?: Array<PromptAgentAttachment>
  skills?: Array<PromptSkillAttachment>
  type: "user"
}

export type SessionMessageSynthetic = {
  id: string
  metadata?: { [x: string]: JsonValue }
  time: { created: number }
  text: string
  description?: string
  type: "synthetic"
}

export type SessionMessageSystem = {
  id: string
  metadata?: { [x: string]: JsonValue }
  time: { created: number }
  type: "system"
  text: string
  description?: string
}

export type SessionMessageSkill = {
  id: string
  metadata?: { [x: string]: JsonValue }
  time: { created: number }
  type: "skill"
  skill: string
  name: string
  text: string
}

export type SessionMessageShell = {
  id: string
  metadata?: { [x: string]: JsonValue }
  time: { created: number; completed?: number }
  type: "shell"
  shellID: string
  command: string
  status: "running" | "exited" | "timeout" | "killed"
  exit?: number | "Infinity" | "-Infinity" | "NaN"
  output?: { output: string; cursor: number; size: number; truncated: boolean }
}

export type SessionMessageAssistant = {
  id: string
  metadata?: { [x: string]: JsonValue }
  time: { created: number; streamed?: number; completed?: number }
  type: "assistant"
  agent: string
  model: ModelRef
  content: Array<SessionMessageAssistantText | SessionMessageAssistantReasoning | SessionMessageAssistantTool>
  snapshot?: { start?: string; end?: string; files?: Array<string> }
  finish?: "stop" | "length" | "tool-calls" | "content-filter" | "error" | "unknown"
  rawFinish?: string
  providerState?: SessionMessageProviderState
  cost?: MoneyUSD
  tokens?: TokenUsageInfo
  error?: SessionStructuredError
  retry?: SessionMessageAssistantRetry
}

export type SessionMessageAssistantText = { type: "text"; text: string; state?: SessionMessageProviderState }

export type SessionMessageAssistantReasoning = {
  type: "reasoning"
  text: string
  state?: SessionMessageProviderState
  time?: { created: number; completed?: number }
}

export type SessionMessageAssistantTool = {
  type: "tool"
  id: string
  name: string
  executed?: boolean
  providerState?: SessionMessageProviderState
  providerResultState?: SessionMessageProviderState
  state:
    | SessionMessageToolStateStreaming
    | SessionMessageToolStateRunning
    | SessionMessageToolStateCompleted
    | SessionMessageToolStateError
  time: { created: number; ran?: number; completed?: number }
}

export type SessionMessageToolStateStreaming = { status: "streaming"; input: string }

export type SessionMessageToolStateRunning = {
  status: "running"
  input: { [x: string]: JsonValue }
  metadata: { [x: string]: JsonValue }
}

export type SessionMessageToolStateCompleted = {
  status: "completed"
  input: { [x: string]: JsonValue }
  content: [ToolContent, ...Array<ToolContent>]
  metadata?: { [x: string]: JsonValue }
}

export type SessionMessageToolStateError = {
  status: "error"
  input: { [x: string]: JsonValue }
  error: SessionStructuredError
  content?: [ToolContent, ...Array<ToolContent>]
  metadata?: { [x: string]: JsonValue }
}

export type SessionMessageAssistantRetry = { attempt: number; at: number; error: SessionStructuredError }

export type SessionMessageCompaction =
  | SessionMessageCompactionRunning
  | SessionMessageCompactionCompleted
  | SessionMessageCompactionFailed

export type SessionMessageCompactionRunning = {
  type: "compaction"
  id: string
  metadata?: { [x: string]: JsonValue }
  time: { created: number }
  status: "running"
  reason: "auto" | "manual"
  summary: string
  recent: string
}

export type SessionMessageCompactionCompleted = {
  type: "compaction"
  id: string
  metadata?: { [x: string]: JsonValue }
  time: { created: number }
  status: "completed"
  reason: "auto" | "manual"
  model?: ModelRef
  providerState?: SessionMessageProviderState
  summary: string
  recent: string
  providerContext?: SessionProviderContext
  cost?: MoneyUSD
  tokens?: TokenUsageInfo
}

export type SessionMessageCompactionFailed = {
  type: "compaction"
  id: string
  metadata?: { [x: string]: JsonValue }
  time: { created: number }
  status: "failed"
  reason: "auto" | "manual"
  error: SessionStructuredError
  cost?: MoneyUSD
  tokens?: TokenUsageInfo
}

export type SessionMessageIdle = {
  id: string
  metadata?: { [x: string]: JsonValue }
  time: { created: number }
  type: "idle"
  outcome: "succeeded" | "failed" | "interrupted"
}

export type ToolContent = ToolTextContent | ToolFileContent

export type ToolTextContent = { type: "text"; text: string }

export type ToolFileContent = { type: "file"; uri: string; mime: string; name?: string | null }

export type PromptFileAttachment = {
  data: PromptBase64
  mime: string
  source: PromptFileSource
  name?: string
  description?: string
  mention?: PromptMention
}

export type PromptFileSource = { type: "inline" } | { type: "uri"; uri: string }

export type PromptMention = { start: number; end: number; text: string }

export type PromptAgentAttachment = { name: string; mention?: PromptMention }

export type PromptSkillAttachment = { id: string; name: string; text?: string; mention?: PromptMention }

export type SessionStructuredError = { type: string; message: string; status?: number; response?: { body: string } }

export type TokenUsageInfo = {
  input: number
  output: number
  reasoning: number
  cache: { read: number; write: number }
}
```

Notes on encoding:
- `SessionMessageProviderState` = `Record<string, unknown>` opaque provider metadata (cache/thought signatures) — clients must preserve but never interpret.
- Numbers declared `number | "Infinity" | "-Infinity" | "NaN"` (e.g. `shell.exit`) come from Effect's `Schema.Number` encoding of non-finite values; a Dart decoder must accept those strings.
- `PromptFileAttachment.data` is **base64 of the full file** embedded in user messages (images are normalized/resized server-side, V2 `packages/core/src/session/prompt.ts#L135-L150`) — paginate message lists on mobile.
- `ToolFileContent.uri` refers to a server-side file; fetch bytes via `GET /api/fs/read/*` when relative to the location (inferred).

### 3.1 Message IDs

| Message type | `id` |
|---|---|
| `user` | the inbox/prompt id (`msg_…`, client-mintable via `POST …/prompt {id}`) |
| `synthetic`, `system` (instructions), `agent-switched`, `model-switched`, `location-switched`, `skill`, `shell`, `idle` | `msg_` + suffix of the event id that created it (`SessionMessage.ID.fromEvent`, V2 `packages/schema/src/session-message.ts#L23-L30`); `shell` may reuse the optimistic id passed to `POST …/shell {id}` |
| `assistant` | `assistantMessageID` from `session.step.started` |
| `compaction` | `inputID` (manual compaction request id) or `msg_`+event suffix (auto) |

IDs are time-ordered (`msg_` ascending), and the reference client relies on `id >= to` comparisons for revert commits (V2 `packages/client/src/solid/data.ts#L1076-L1092`).

### 3.2 Event → projection rules (port of the reference reducer)

| Event | Effect on client state (V2 `packages/client/src/solid/data.ts` lines) |
|---|---|
| `session.inbox.enqueued` | add to `pending[sessionID]`; for `user`/`synthetic` items also insert a visible row `{id: inboxID, type, ...payload, time.created: event.created}` (L773-L790) |
| `session.inbox.delivered` | remove from pending; move the existing row to the end of the timeline and set `time.created = event.created` (L749-L764) |
| `session.inbox.cancelled` | remove from pending and remove its row (L768-L772) |
| `session.step.started` | if `assistantMessageID` exists (retry) reset agent/model/retry/error/finish/times; else mark the previous unfinished assistant `time.completed = event.created` and append `{id: assistantMessageID, type:"assistant", agent, model, content: [], snapshot:{start}, time:{created: data.started}}` (L838-L872) |
| `session.text.started` / `.delta` / `.ended` | push `{type:"text", text:""}` / append `delta` to the **last** text item / set its `text` to the full value (L904-L918) |
| `session.reasoning.*` | same with the last *unfinished* reasoning item; `.ended` sets `time.completed` (L982-L1003) |
| `session.tool.input.started` / `.delta` / `.ended` | push tool `{id, name, time.created, state:{status:"streaming", input:""}}` / append raw JSON / set raw JSON (L919-L939) |
| `session.tool.called` | `state = {status:"running", input: parsed, metadata:{}}`, `time.ran`, `executed`, `providerState` (L940-L947) |
| `session.tool.progress` | if running: `state.metadata = data.metadata` (replace) (L948-L952) |
| `session.tool.success` | if running: `state = {status:"completed", input, metadata, content}`; `time.completed` (L953-L966) |
| `session.tool.failed` | if streaming/running: `state = {status:"error", error, input (object or {}), metadata, content}`; `time.completed` (L967-L981) |
| `session.step.streamed` | `assistant.time.streamed` (L873-L877) |
| `session.step.ended` | `time.completed`, `finish`, `rawFinish`, `providerState`, `cost`, `tokens`, `snapshot.end` (L878-L889) |
| `session.step.failed` | `time.completed`, `finish = data.finish ?? "error"`, `error`, clear `retry`, usage if present (L890-L903) |
| `session.retry.scheduled` | `assistant.retry = {attempt, at, error}` (L1004-L1008) |
| `session.execution.started` | session status = running (L1009-L1011) |
| `session.execution.succeeded/failed/interrupted` | status = idle; clear `retry`; unless `reason:"shutdown"` append `{type:"idle", outcome}` row; if tools still streaming/running, refetch messages; refetch Session.Info (L1025-L1062) |
| `session.compaction.started/delta/ended/failed` | running → completed/failed compaction row (L1012-L1024, L1093-L1159) |
| `session.revert.*` | Session.Info.revert set/cleared; on commit drop rows and pending items with `id >= to` (L1068-L1092) |
| `session.agent.selected` / `session.model.selected` / `session.moved` / `session.synthetic` / `session.instructions.updated` / `session.shell.*` | insert the corresponding row (L652-L837) |
| `session.created` / `deleted` / `renamed` / `permissions` / `usage.updated` / `viewed` | update session list / Session.Info (L628-L703, L1063-L1067) |
| `permission.asked` / `permission.replied` | add / remove pending permission (L1160-L1169) |
| `form.created` / `form.replied` / `form.cancelled` | add / remove pending form (L1170-L1174, L1238-L1244) |
| catalog `*.updated`, `mcp.*`, `credential.*`, `vcs.branch.updated`, `shell.*` | invalidate + refetch the location catalog (L1176-L1296) |

---

## 4. How an in-progress assistant turn streams (exact sequence)

Producer: V2 `packages/core/src/session/runner/publish-llm-event.ts` (one publisher per step; invariant comment at `#L64-L76`: "consumers fold by id/ordinal rather than global position").

A **turn** = from the first admitted prompt after idle until the next `idle` marker; it may contain several **steps** (one assistant message each: model call → tool calls → next model call…). Typical sequence for `POST /api/session/S/prompt {text}` on an idle session:

```
session.inbox.enqueued      {sessionID:S, inboxID:msg_U, item:{type:"user", payload:{text,…}, delivery:"steer"}}   (durable)
session.execution.started   {sessionID:S}                                                                          (durable)
session.inbox.delivered     {sessionID:S, inboxID:msg_U}                                                           (durable)
session.step.started        {assistantMessageID:msg_A1, agent, model, snapshot?, started}                          (durable)
  session.reasoning.started {ordinal:0}  → session.reasoning.delta* → session.reasoning.ended {text}
  session.text.started      {ordinal:0}  → session.text.delta {delta}* (batched every 100 ms) → session.text.ended {text}
  session.tool.input.started {id:call_1, name:"read"} → session.tool.input.delta* → session.tool.input.ended {text}
  session.tool.called       {id:call_1, input:{…}, executed:false}
  session.tool.progress*    {id:call_1, metadata:{…}}          (ephemeral, optional)
  [permission.asked / permission.replied]  (ephemeral, if the tool needs approval)
  session.tool.success      {id:call_1, content:[…], metadata?} | session.tool.failed {error}
session.step.streamed       {assistantMessageID:msg_A1}       (provider body ended; may precede tool settlement)
session.step.ended          {finish:"tool-calls", cost, tokens, snapshot?, files?}
session.usage.updated       {cost, tokens}                    (ephemeral running totals)
session.step.started        {assistantMessageID:msg_A2, …}    (next step of the same turn)
  … text …
session.step.ended          {finish:"stop", …}
session.execution.succeeded {sessionID:S}                     (→ client appends idle{outcome:"succeeded"})
session.renamed             {title}                           (first turn: title agent, async)
```

Facts that matter for the renderer:
- **Deltas are append-only fragments**; `*.ended` carries the **authoritative full value** (`text`) — always replace on `ended` (V2 `packages/schema/src/session-event.ts#L394-L470`). Deltas are coalesced server-side every **100 ms** (`deltaBatchInterval`, V2 `packages/core/src/session/runner/publish-llm-event.ts#L78`, batching loop `#L127-L200`).
- `ordinal` numbers text (resp. reasoning) blocks within one assistant message (0,1,2…); the reference reducer simply targets the last text / last unfinished reasoning item.
- Tool calls are keyed by provider call id `data.id`, unique within the assistant message. Tool events come from concurrent fibers; ordering is guaranteed per tool and per text/reasoning stream, **not** across them.
- There is **no `time.end` on parts** any more. Completion markers: text = `session.text.ended` (no timestamp field on the item), reasoning = `time.completed`, tool = `time.completed`, assistant = `time.completed` (set by `step.ended`/`step.failed`, or by the next `step.started` / execution end), plus `time.streamed`.
- `finish`: `"stop" | "length" | "tool-calls" | "content-filter" | "error" | "unknown"` (V2 `packages/schema/src/llm.ts#L5`); `rawFinish` = provider string.
- Retries: `session.retry.scheduled` (`at` = epoch ms of next attempt) then a new `session.step.started` with the **same** `assistantMessageID` (reset in place).
- Steering: a prompt admitted while busy with `delivery:"steer"` gets `session.inbox.delivered` at the next step boundary and becomes part of the same turn; `queue` items wait for the turn to end.
- Interrupt: `POST …/interrupt` → unsettled tools get `session.tool.failed {error:{type:"aborted",message:"Tool execution interrupted"}}`, the step gets `session.step.failed {error:{type:"aborted",message:"Step interrupted"}}` (V2 `packages/core/src/session/runner/step.ts#L61-L63`, `#L198-L218`), then `session.execution.interrupted {reason:"user"}`.

---

## 5. Session status (busy / idle / retry)

| Need | v2 mechanism |
|---|---|
| Is session running *now* (snapshot) | `GET /api/session/active` → `{data: {[sessionID]: {type:"running"}}}` (process-local; children included) |
| Busy transition | `session.execution.started` (durable) |
| Idle transition + outcome | `session.execution.succeeded` / `.failed {error}` / `.interrupted {reason}` (durable); projected `idle` message `{outcome: "succeeded"\|"failed"\|"interrupted"}`; `Session.Info.outcome` + `Session.Info.time.idle` |
| Retrying | `session.retry.scheduled {attempt, at, error}` → `assistant.retry`; cleared on next `step.started`/execution end |
| Unread | `Session.Info.time.viewed < time.idle` → badge; mark with `POST /api/session/{id}/view {idle}` |
| Legacy `session.status` / `session.idle` | Declared in the event union (`SessionStatus = {type:"idle"} \| {type:"retry", attempt, message, action?, next} \| {type:"busy"}`, V2 `packages/schema/src/session-status-event.ts#L9-L50`) but **no publisher exists in v2.0.21 core/server** (repo-wide search for `SessionStatusEvent`; inferred legacy). Do not depend on it. |

Interruption reasons: `user` (API), `shutdown` (server stopping — claim kept; the managed service resumes the turn on next boot with a synthetic "The server restarted while you were working…" and up to 10 attempts, V2 `packages/core/src/session/execution/restart.ts#L15-L33`), `superseded`, `inactivity`. Restart continuity is installed only for the managed service lifecycle (`if (lifecycle) installRestartContinuity`, V2 `packages/server/src/process.ts#L104-L108`) — a plain foreground `opencode serve` does **not** auto-resume orphaned turns (inferred from that branch).

---

## 6. Errors

```ts
// Effect schema — V2 packages/schema/src/session-error.ts#L7-L12
export const Error = Schema.Struct({
  type: Schema.String,
  message: Schema.String,
  status: Schema.Int.check(Schema.isBetween({ minimum: 100, maximum: 599 })).pipe(optional),
  response: Schema.Struct({ body: Schema.String }).pipe(optional),
}).annotate({ identifier: "Session.StructuredError" })
```

`type` values produced in v2 core (V2 `packages/core/src/session/to-session-error.ts#L28-L96`, `packages/core/src/session/runner/step.ts#L61-L63`, `packages/core/src/session/runner/publish-llm-event.ts`, `packages/core/src/session/compaction.ts`):

| `type` | Meaning / v1 equivalent |
|---|---|
| `provider.rate-limit` | 429 throttle (retried) — v1 `APIError` retryable |
| `provider.quota` | account/billing cap (not retried; Zen Go/Free limits, `insufficient_quota`) — v1 `APIError` + retry `action` |
| `provider.auth` | bad/missing credentials — v1 `ProviderAuthError` |
| `provider.content-filter` | blocked by policy — v1 `ContentFilterError` |
| `provider.transport`, `provider.timeout`, `provider.internal`, `provider.invalid-output`, `provider.invalid-request`, `provider.unsupported-operation`, `provider.no-route` (no model selected / unavailable / bad variant), `provider.unknown`, `provider.error` | provider failures — v1 `APIError`/`UnknownError` |
| `aborted` | interrupted step/tool, declined tool ("The user declined this tool call"), restart budget exhausted — v1 `MessageAbortedError` |
| `permission.rejected` | denied by rule, or rejected with feedback message |
| `tool.execution`, `tool.unknown`, `tool.input-json`, `tool.result-missing` | tool failures (shown on tool state, not the whole message) |
| `compaction.failed`, `compaction.interrupted`, `compaction.unavailable` | compaction failures |
| `unknown` | anything else — v1 `UnknownError` |

Context overflow is no longer an error the client sees by default: the runner recovers with automatic compaction (`isContextOverflowFailure → Outcome.Compacted()`, V2 `packages/core/src/session/runner/step.ts#L147-L159`) **(inferred: no dedicated `ContextOverflowError` type exists in v2)**. Output-length truncation surfaces as `finish:"length"` rather than `MessageOutputLengthError`.

---

## 7. Permissions

### 7.1 Schemas (*generated*)

```ts
export type PermissionRequest = {
  id: string
  sessionID: string
  action: string
  resources: Array<string>
  save?: Array<string>
  metadata?: { [x: string]: JsonValue }
  source?: PermissionSource
  message?: string
}

export type PermissionSource = { type: "tool"; messageID: string; id: string }

export type PermissionReply = "once" | "always" | "reject"

export type PermissionRule = { action: string; resource: string; effect: PermissionEffect }

export type PermissionRuleset = Array<PermissionRule>

export type PermissionEffect = "allow" | "deny" | "ask"

export type PermissionSavedInfo = {
  id: string
  projectID: string
  action: string
  resource: string
  time: { created: number; updated: number }
}
```
Effect sources: V2 `packages/schema/src/permission.ts#L10-L66`, `packages/schema/src/permission-saved.ts#L14-L23`.

Events: `permission.asked` (data = the full `PermissionRequest`), `permission.replied {sessionID, requestID, reply}`; `session.permissions {sessionID, permissions}` when a session ruleset changes. Pending requests live **in memory** per location; on location reload/shutdown every pending request is auto-replied `reject` (`close`, V2 `packages/core/src/permission.ts#L133-L149`) and they do not survive a server restart (inferred).

### 7.2 Evaluation (V2 `packages/core/src/permission.ts#L87-L215`)

```ts
export function evaluate(action: string, resource: string, ...rulesets: Permission.Ruleset[]): Permission.Rule {
  return (
    rulesets
      .flat()
      .findLast((rule) => Wildcard.match(action, rule.action) && Wildcard.match(resource, rule.resource)) ?? {
      action,
      resource: "*",
      effect: "ask",
    }
  )
}
```
- Rules = `agent.permissions ++ session.permissions` (agent missing → `[*:*:deny]`); **last matching rule wins**; no match → `ask`.
- If any requested resource evaluates to `deny` under those rules → immediate `Permission.BlockedError` (tool fails with `permission.rejected`), no prompt.
- Otherwise saved approvals (`PermissionSaved` rows of the project, turned into `allow` rules) are appended; any resource still `ask` → a pending request is created and the tool fiber waits; plugins may override via the `permission.evaluate` hook.
- Built-in defaults for every agent (V2 `packages/schema/src/agent.ts#L39-L55`): `*:*:allow`, `external_directory:*:ask`, `read:*.env:ask`, `read:*.env.*:ask`, `read:*.env.example:allow` + allow for OpenCode's own data/tmp/config dirs (V2 `packages/core/src/agent.ts#L58-L64`). `build` adds `question:*:allow`; `general` denies `question` and `subagent`; `explore` is read-only (`*:*:deny` then allow grep/glob/webfetch/websearch/read) (V2 `packages/core/src/plugin/agent.ts#L87-L130`). `plan` agent restricts edits to a plan file (V2 `packages/core/src/plugin/plan.ts`).
- Config: `permissions: Permission.Rule[]` at top level and per agent (`agents.<id>.permissions`); v1 `permission`/`tools` maps are migrated with action renames `bash→shell`, `task→subagent`, `write|patch→edit` (V2 `packages/core/src/v1/config/migrate.ts#L116-L122`). Managed `experimental.policies[{action:"provider.use"|"permission", resource, effect}]` also exist.

### 7.3 Action / resource vocabulary used by built-in tools (v2.0.21)

| Tool | `action` | `resources` | `save` (persisted by "always") | `metadata` worth rendering |
|---|---|---|---|---|
| any file tool touching a path outside the location | `external_directory` (asked first) | `<abs dir>/*` | `<project root of that dir>/*` | — (V2 `packages/core/src/file-access.ts#L113-L142`) |
| `read` | `read` | relative path (or abs if external) | `["*"]` → "always" allows **all reads** in the project | — (V2 `packages/core/src/file-access.ts#L144-L161`) |
| `edit` / `write` / `patch` | `edit` | relative path(s) | `["*"]` → "always" allows **all edits** | `files: FileDiff.Info[]` preview of the change (V2 `packages/core/src/tool/plugin/edit.ts#L180-L188`, `write.ts#L78-L86`, `patch.ts#L196-L208`; `patch` also sends `filepath` and unified `diff`) |
| `glob` / `grep` | `glob` / `grep` | `[pattern]` | `["*"]` | `{root, path, …}` (V2 `packages/core/src/tool/plugin/glob.ts#L68-L82`) |
| `shell` | `shell` | parsed commands (`command.resource`) | per-command prefixes (`command.save`) (V2 `packages/core/src/tool/plugin/shell.ts#L134-L142`) | — |
| `webfetch` | `webfetch` | `[url]` | `["*"]` | tool input |
| `websearch` | `websearch` | `[query]` | `["*"]` | tool input |
| `question` | `question` | `["*"]` | — | — |
| `skill` | `skill` | `[skillID]` | `[skillID]` | — (V2 `packages/core/src/tool/plugin/skill.ts#L51-L58`) |
| `subagent` | `subagent` | `[agentID]` | `[agentID]` | — |
| MCP tools | `<server>_<tool>` (sanitized, V2 `packages/core/src/tool/mcp.ts#L16-L17`) | `["*"]` | `["*"]` | `{}` (V2 `packages/core/src/tool/mcp.ts#L51-L61`) |
| MCP resource tools | `opencode_list_mcp_resources`, `opencode_read_mcp_resource` | server names | server names | `{}` (V2 `packages/core/src/tool/plugin/mcp-resource.ts#L36-L44`) |

UI hint: show `action` + `resources` (and the `files` diff preview for `edit`) and explain that **"Always" grants the `save` patterns for the whole project** (for most tools that is `*`, i.e. every future call of that action).

### 7.4 Replying (V2 `packages/core/src/permission.ts#L265-L330`)

`POST /api/session/{sessionID}/permission/{requestID}/reply` body `{ decision: "once" | "always" | "reject", message?: string }` → 204.
- `once`: resolves this request only.
- `always`: resolves it **and** persists `PermissionSaved {projectID, action, resource}` for every pattern in `request.save` (if `save` is empty, behaves like `once`); then re-evaluates all other pending requests and auto-resolves those now allowed (each gets `permission.replied {reply:"always"}`). Scope = **project-wide, all sessions**, until `DELETE /api/permission/saved/{id}`.
- `reject` **without** `message`: the tool fails as "The user declined this tool call" (`aborted`) and **the step/turn ends** (decline is tunnelled as a defect, V2 `packages/core/src/permission.ts#L235-L248`, `packages/core/src/session/runner/step.ts#L198-L218`). `reject` **with** `message`: becomes `CorrectedError` → tool fails with `permission.rejected` + the feedback and **the model continues**. Either way, **all other pending requests of the same session are rejected too**.

### 7.5 "Allow all" options for a remote client

1. **Client-side auto-approve (what the official TUI and web app do):** on every `permission.asked`, immediately `POST …/reply {decision:"once"}` (TUI `autoaccept` mode, V2 `packages/tui/src/routes/session/index.tsx#L259-L277`; web app setting `permissions.autoApprove`, V2 `packages/app/src/session/requests/model.ts#L64-L67`; CLI `--auto`/`--yolo`/`--dangerously-skip-permissions` for `opencode run`, V2 `packages/cli/src/run/noninteractive.ts#L160-L185`). Explicit `deny` rules still block (they never produce `permission.asked`). Works only while the client is connected.
2. **Server-side per session:** `PATCH /api/session/{id} {permissions:[{action:"*",resource:"*",effect:"allow"}]}` (or pass it at `POST /api/session`). Because session rules are evaluated after agent rules and the last match wins, this **overrides agent `deny`/`ask` rules too** (including `external_directory` and `.env` reads); child (subagent) sessions **inherit** the parent's `permissions` at creation (V2 `packages/core/src/session.ts#L272-L276`). Revert by PATCHing the previous ruleset. A narrower form, e.g. `[{action:"edit",resource:"*",effect:"allow"},{action:"shell",resource:"*",effect:"allow"}]`, is also possible.
3. **Project-wide persistent:** reply `always` (persists `save` patterns); manage via `/api/permission/saved`.
4. **Global config:** `permissions` in `opencode.json` (no HTTP write endpoint except `PATCH /api/experimental/config`, which only accepts `shell`).

### 7.6 Subagent permissions

Child sessions ask with their **own** `sessionID`. The web app gathers pending permissions/forms over the whole session tree (`sessionTreeIDs`, V2 `packages/app/src/session/requests/model.ts#L30-L35`) — CodeWalk should surface child requests in the parent view.

---

## 8. Questions = Forms

v2 has no `question.*` events or `/question` routes. The `question` tool creates a **Form**.

```ts
// generated
export type FormInfo = { id: string; sessionID: string; title: string; metadata?: FormMetadata; fields: FormFields }

export type FormDetail = {
  id: string
  sessionID: string
  title: string
  metadata?: FormMetadata
  fields: FormFields
  state: FormState
}

export type FormState =
  | { status: "pending" }
  | { status: "answered"; answer: FormAnswer }
  | { status: "cancelled"; message?: string }

export type FormField =
  | FormStringField
  | FormNumberField
  | FormIntegerField
  | FormBooleanField
  | FormMultiselectField
  | FormExternalField

export type FormStringField = {
  key: string
  title?: string
  description?: string
  required?: boolean
  hidden?: boolean
  when?: Array<FormWhen>
  type: "string"
  format?: "email" | "uri" | "date" | "date-time"
  minLength?: number
  maxLength?: number
  pattern?: string
  placeholder?: string
  default?: string
  options?: Array<FormOption>
  custom?: boolean
}

export type FormMultiselectField = {
  key: string
  title?: string
  description?: string
  required?: boolean
  hidden?: boolean
  when?: Array<FormWhen>
  type: "multiselect"
  options: Array<FormOption>
  minItems?: number
  maxItems?: number
  custom?: boolean
  default?: Array<string>
}

export type FormOption = { value: string; label: string; description?: string }

export type FormWhen = {
  key: string
  op: "eq" | "neq"
  value: string | number | "Infinity" | "-Infinity" | "NaN" | boolean
}

export type FormAnswer = { [x: string]: FormValue }

export type FormValue = string | number | "Infinity" | "-Infinity" | "NaN" | boolean | Array<string>
```
Effect sources: V2 `packages/schema/src/form.ts#L1-L174`. Events: `form.created {form: FormInfo}`, `form.replied {id, sessionID, answer}`, `form.cancelled {id, sessionID}`.

`question` tool mapping (V2 `packages/core/src/tool/plugin/question.ts#L23-L132`):
- Tool input `{questions: [{question, header, options:[{label, description}], multiple?}]}` (V2 `packages/schema/src/question.ts#L6-L20`).
- Form: `title:"Questions"`, `metadata: {kind:"question", tool:{messageID, id}}`, one field per question: `key:"q<i>"`, `title: header`, `description: question`, `type: multiple ? "multiselect" : "string"`, `options: [{value: label, label, description}]`, `custom: true` (free text allowed).
- Reply: `POST /api/session/{sid}/form/{fid}/reply {answer: {q0: "Label", q1: ["A","B"], …}}`. The tool result to the model is `User has answered your questions: "<question>"="<answers>", …` with `metadata.answers: string[][]`.
- Cancel: `DELETE /api/session/{sid}/form/{fid}?message=…` → with message the tool fails softly with that text and the model continues; without message it is a dismissal ("The user dismissed this question") that **ends the step** like a declined permission.
- Other form kinds: `metadata.kind:"websearch.provider"` (choose a web-search provider, V2 `packages/core/src/tool/plugin/websearch.ts#L72-L115`), `"mcp-elicitation"` (MCP servers; may use the sentinel `sessionID:"global"`, V2 `packages/core/src/mcp/index.ts#L80`, `#L236-L266`), and integration auth forms (`Integration.*Method.form`). Field types: `string` (format email|uri|date|date-time, min/maxLength, pattern, placeholder, options, custom), `number`, `integer`, `boolean`, `multiselect`, `external` (a URL to open). `when` conditions hide/show fields. Settled forms are retained 10 min (V2 `packages/core/src/form.ts#L8`).

---

## 9. Todo

**Not present in v2.** No todo tool, no `todo.updated` event, no `/session/{id}/todo` route in v2.0.21 (`rg -i todo packages/{core,schema,protocol}/src` finds only code comments). The v2 TUI renders no todo panel. (v1: `Todo {content, status, priority}`, event `todo.updated`, V1 `packages/sdk/js/src/v2/gen/types.gen.ts#L6845`.)

---

## 10. Sessions, inbox, tokens/cost, models, providers, agents

```ts
// generated
export type SessionInfo = {
  id: string
  parentID?: string
  fork?: { sessionID: string; boundary: SessionForkBoundary }
  projectID: string
  agent?: string
  model?: ModelRef
  cost: MoneyUSD
  tokens: TokenUsageInfo
  outcome?: "succeeded" | "failed" | "interrupted"
  time: { created: number; updated: number; idle?: number; viewed?: number; archived?: number }
  title?: string
  subpath?: string
  metadata?: SessionMetadata
  permissions?: PermissionRuleset
  revert?: SessionRevert
  location: LocationPublicRef
}

export type SessionRevert = { messageID: string; partID?: string; snapshot?: string; files?: Array<FileDiffInfo> }

export type SessionInboxInfo = SessionInboxUser | SessionInboxSynthetic | SessionInboxCompaction | SessionInboxMove

export type SessionInboxUser = {
  id: string
  sessionID: string
  time: { created: number }
  type: "user"
  payload: SessionInboxUserPayload
  delivery: SessionInboxDelivery
}

export type SessionInboxUserPayload = {
  text: string
  files?: Array<PromptFileAttachment>
  agents?: Array<PromptAgentAttachment>
  skills?: Array<PromptSkillAttachment>
  metadata?: { [x: string]: JsonValue }
}

export type SessionInboxSynthetic = {
  id: string
  sessionID: string
  time: { created: number }
  type: "synthetic"
  payload: SessionInboxSyntheticPayload
  delivery: SessionInboxDelivery
}

export type SessionInboxCompaction = {
  id: string
  sessionID: string
  time: { created: number }
  type: "compaction"
  payload: SessionInboxCompactionPayload
  delivery: SessionInboxDelivery
}

export type SessionInboxMove = {
  id: string
  sessionID: string
  time: { created: number }
  type: "move"
  delivery: SessionInboxDelivery
  payload: SessionInboxMovePayload
}

export type SessionInboxDelivery = "steer" | "queue"

export type SessionInboxItem =
  | { type: "user"; payload: SessionInboxUserPayload1; delivery: SessionInboxDelivery }
  | { type: "synthetic"; payload: SessionInboxSyntheticPayload1; delivery: SessionInboxDelivery }
  | { type: "compaction"; payload: SessionInboxCompactionPayload; delivery: SessionInboxDelivery }
  | { type: "move"; payload: SessionInboxMovePayload1; delivery: SessionInboxDelivery }

export type SessionStatus =
  | { type: "idle" }
  | {
      type: "retry"
      attempt: number
      message: string
      action?: { reason: string; provider: string; title: string; message: string; label: string; link?: string }
      next: number
    }
  | { type: "busy" }

export type EventLogSynced = { type: "log.synced"; aggregateID: string; seq?: number }

export type ModelInfo = {
  id: string
  modelID: string
  providerID: string
  canonical?: string
  family?: string
  name: string
  compatibility?: ModelCompatibility
  package?: string
  settings?: ModelSettings
  headers?: { [x: string]: string }
  body?: { [x: string]: any }
  capabilities: ModelCapabilities
  variants: Array<ModelVariant>
  time: { released: number }
  cost: Array<ModelCost>
  status: "alpha" | "beta" | "deprecated" | "active"
  enabled: boolean
  limit: { context: number; input?: number; output: number }
}

export type ModelRef = { id: string; providerID: string; variant?: string }

export type ModelVariant = {
  id: string
  settings?: ModelSettings
  headers?: { [x: string]: string }
  body?: { [x: string]: any }
}

export type ModelCost = {
  tier?: { type: "context"; size: number }
  input: MoneyUSDPerMillionTokens
  output: MoneyUSDPerMillionTokens
  cache: { read: MoneyUSDPerMillionTokens; write: MoneyUSDPerMillionTokens }
}

export type ModelCapabilities = { tools: boolean; input: Array<string>; output: Array<string> }

export type ProviderInfo = {
  id: string
  canonical?: string
  integrationID?: string
  name: string
  activation: "auto" | "enabled" | "disabled"
  package: string
  settings?: ProviderSettings
  headers?: { [x: string]: string }
  body?: { [x: string]: any }
}

export type AgentInfo = {
  id: string
  name: string
  model?: ModelRef
  request: ProviderRequest
  system?: string
  description?: string
  mode: "subagent" | "primary" | "all"
  hidden: boolean
  color?: AgentColor
  steps?: number
  permissions: PermissionRuleset
}

export type CommandInfo = { name: string; description?: string }

export type SkillInfo = {
  id: string
  name: string
  description?: string
  autoinvoke?: boolean
  path: string
  content: string
}

export type ShellInfo = {
  id: string
  status: "running" | "exited" | "timeout" | "killed"
  command: string
  cwd: string
  shell: string
  file: string
  pid?: number
  exit?: number
  signal?: string
  metadata: { [x: string]: any }
  time: { started: number; completed?: number }
}

export type Pty = {
  id: string
  title: string
  command: string
  args: Array<string>
  cwd: string
  status: "running" | "exited"
  pid: number
  exitCode?: number
}

export type FileDiffInfo = {
  file: string
  patch: string
  additions: number
  deletions: number
  status: "added" | "deleted" | "modified"
}

export type ServerInfo = { version: string; pid: number; urls: Array<string>; paths: { tmp: string } }

export type LocationPublicInfo = { directory: string; project: { id: string; directory: string; canonical: string } }
```

- **Tokens** per assistant message: `{input, output, reasoning, cache:{read, write}}`; `total = sum of all five` (V2 `packages/schema/src/token-usage.ts#L17-L20`). Session totals accumulate step usage plus title/compaction usage.
- **Cost**: `Money.USD` number; model prices `Model.Info.cost[]` are USD per 1M tokens with optional context-size tiers.
- **Limits**: `Model.Info.limit {context, input?, output}` — the only "limit" data exposed (no usage-left/quota).
- **Variants**: `Model.Info.variants[] {id, settings?, headers?, body?}`; select with `Model.Ref.variant` via `POST /api/session/{id}/model`.
- `Provider.Info` no longer contains models; `Model.Info` is flat with `providerID`.

---

## 11. SUBAGENTS in v2 (task tool → `subagent` tool)

### 11.1 The tool (V2 `packages/core/src/tool/plugin/subagent.ts`)

```ts
// Effect schema — V2 packages/core/src/tool/plugin/subagent.ts#L29-L54
export const Input = Schema.Struct({
  agent: Schema.String,          // subagent id (agent.mode must not be "primary")
  description: Schema.String,    // 3-5 word label → child session title
  prompt: Schema.String,
  model: Schema.optionalKey(Schema.String),     // "providerID/modelID" or "providerID/modelID#variant"
  sessionID: Schema.optionalKey(SessionSchema.ID), // continue an existing child (must be a child of the caller)
  background: Schema.optionalKey(Schema.Boolean),  // async mode
})
export const Output = Schema.Struct({
  sessionID: SessionSchema.ID,
  status: Schema.Literals(["completed", "running"]),
  output: Schema.String,
})
```
Execution (`#L108-L270`):
1. Depth limit `experimental.subagent_depth` (default **1** → a subagent cannot spawn subagents) (`#L118-L133`); unknown agent / `mode:"primary"` agent → tool failure (`#L134-L137`).
2. Permission `assert({action:"subagent", resources:[agentID], save:[agentID]})` against the **caller** session (`#L138-L150`).
3. Child session: `sessions.create({parentID: caller, title: description, agent, model: override ?? agent.model ?? parent.model})` — location, `metadata` and `permissions` are inherited from the parent (V2 `packages/core/src/session.ts#L251-L282`). Emits `session.created` with `parentID`.
4. `context.progress({sessionID: child.id, status:"running"})` → **ephemeral** `session.tool.progress` on the parent's tool item with `metadata {sessionID, status:"running"}` (`#L201`).
5. Child prompt admitted with text `"You are a subagent spawned by another session.\n" + prompt` (background + new child: `resume:false`, the job starts it).
6. A **Job** (id = child sessionID, type `subagent`) runs `sessions.resume(child)` and returns the text of the child's last completed assistant message (V2 `packages/core/src/session/subagent-job.ts#L37-L53`).
7. **Foreground (default):** the parent tool fiber blocks on `jobs.block` (`#L234-L243`); when done the tool succeeds with content `<subagent sessionID="ses_…" state="completed">\n…final text…\n</subagent>` and `metadata {sessionID, status:"completed"}` (`#L255-L268`); child error/cancel → tool failure `Subagent failed (sessionID: …): …` / `Subagent cancelled (sessionID: …)`. Interrupting the parent while blocked interrupts the child and cancels its job (`Effect.onInterrupt`, `#L234-L240`); the failed tool error message gets `(sessionID: …)` appended (V2 `packages/core/src/session/runner/publish-llm-event.ts#L349-L354`).
8. **Background (`background:true`) or later backgrounded:** the tool returns immediately: `output = "The subagent is working in the background (sessionID: …). You will be notified automatically when it finishes. …"`, `metadata {sessionID, status:"running"}` (`#L19-L27`, `#L227-L230`). The parent turn continues (or ends).
9. **Completion delivery** (V2 `packages/core/src/session/subagent-completion.ts#L20-L45`): when the background job settles, a **synthetic message** is admitted to the PARENT (delivery `steer`, resume default → **the parent auto-wakes/resumes**):
   ```
   text: <subagent sessionID="ses_child" state="completed|error|cancelled" description="…">\n<output | error | "Subagent cancelled">\n</subagent>
   metadata: { source: "subagent", childID: "ses_child", agent: "<agent>", state: "completed"|"error"|"cancelled" }
   ```
   Appears as `session.inbox.enqueued` → `session.inbox.delivered` → `synthetic` row in the parent. Background jobs are durably recorded (`job.background/…` KV, `COMPLETED_LIMIT 25`) so pending notifications survive restarts (V2 `packages/core/src/job.ts#L10-L40`).
10. Continuing a child: the model passes `sessionID` (must be a child of the caller); if the agent differs the child is switched (`session.agent.selected`).
11. Tool description lists available subagents = agents with `mode != "primary"`, not hidden, and not denied by the caller's `subagent` rule (`#L285-L307`).
12. Config commands with `subagent: true` (or whose agent is `mode:"subagent"`) also spawn a **background** child the same way (V2 `packages/core/src/config/plugin/command.ts#L75-L121`).

### 11.2 SYNC vs ASYNC and the "background" button

- Sync = default foreground tool call (parent blocked). Async = `background:true` chosen by the model.
- A user can convert all currently blocking backgroundable work (foreground `subagent` calls and `shell` tool calls) of a session into background jobs with **`POST /api/session/{parentID}/background`** (V2 `packages/core/src/session.ts#L430-L447`): blocked tools return the background result immediately, and a synthetic message "User requested that active blocking work be moved to the background. … Backgrounded work: - subagent: <title> …" is admitted. Per-child backgrounding does not exist (V2 `packages/tui/src/mini/stream-v2.subagent.ts#L15-L17`). The shell tool has the same `background` input and completion-notification pattern (V2 `packages/core/src/tool/plugin/shell.ts#L25-L60`).

### 11.3 How a client discovers and follows subagents

Official approach (V2 `packages/tui/src/mini/stream-v2.subagent.ts#L1-L17`): discover children from (1) the parent's projected `subagent` tool items `state.metadata.sessionID` (present on completed/background results; **only ephemeral `tool.progress` carries it while a foreground call runs**, so after a reconnect use (2)), (2) `GET /api/session?parentID=<parent>`, (3) `GET /api/session/active` (running children are listed), (4) live events from unknown sessions whose `session.created.data.parentID` is the parent. Then follow a child exactly like any session: its own `session.step.*`/`text.*`/`tool.*` events on the global stream, `GET /api/session/{child}/message`, its own `permission.asked` / `form.created` (ask the user in the parent view).
- Running/finished: `session.execution.started` / `.succeeded|failed|interrupted` with the child's `sessionID`; `Session.Info.outcome`.
- Parent-side signals: tool item `subagent` (`input: {agent, description, prompt, background?}`), its `metadata.status` `running|completed`; completion synthetic row with `metadata.source:"subagent"` + `childID` (the session-ui makes it clickable, V2 `packages/session-ui/src/timeline/session-timeline-row.tsx#L364-L450`).
- There are **no dedicated job/subagent events or job HTTP endpoints**; `Job` is internal (V2 `packages/core/src/job.ts#L128-L140` has no bus publishes).

### 11.4 Cancelling

- Cancel one subagent: **`POST /api/session/{childID}/interrupt`**. The child emits `session.execution.interrupted {reason:"user"}` and its job is cancelled (`jobs.cancel(sessionID)` for non-shutdown interrupts, V2 `packages/core/src/session/execution.ts#L127-L136`). Foreground: the parent's tool fails "Subagent cancelled (sessionID: …)" and the parent continues. Background: the parent receives the synthetic `<subagent … state="cancelled">Subagent cancelled</subagent>` and wakes.
- Interrupting the parent cancels **foreground** children (tool `onInterrupt`); background children keep running **(inferred**: `jobs.cancel(parentID)` only targets a job whose id is the parent's own session id).
- Deleting a parent deletes its children (`session.remove` recursion).

### 11.5 v1 comparison (task tool)

v1.18.34 already had `task` with `background`: input `{description, prompt, subagent_type, task_id?, command?, background?}`; tool metadata `{parentSessionId, sessionId, model, background?}`; result tags `<task id=… state=…>` / `task_result|task_error` (V1 `packages/opencode/src/tool/task.ts#L43-L75`, `#L180-L195`); permission `task` with `patterns:[subagent_type]`. v2 renames tool → `subagent`, `subagent_type → agent`, `task_id → sessionID`, adds `model`, metadata keys `sessionId → sessionID` + `status`, permission action `task → subagent`, completion notice `<subagent …>` synthetic message with `metadata.source:"subagent"`.
