# CodeWalk v1 ↔ OpenCode v1 — consumed contract (as implemented)

> Scope: exactly what CodeWalk **1.265.0** sends to and reads from an OpenCode **v1.x** server. Paths and line numbers are from the repository as of 2026-10-02 (`HEAD` 14fbf519).
> Sources: code in `lib/`, `ai-docs/opencode_server.md` (local snapshot of the official server docs), `CONTRACT_MATRIX.md`, `ADR.md` (ADR-003/009/018/019/023/027/029/030/031/041/043/055), `BEHAVIOR.md`.
> Convention: `DS` = `lib/data/datasources/chat_remote_datasource.dart`, `DSH` = `chat_remote_datasource_helpers.dart`, `ADS` = `lib/data/datasources/app_remote_datasource.dart`, `PDS` = `lib/data/datasources/project_remote_datasource.dart`, `CP` = `lib/presentation/providers/chat_provider.dart`, `CPD` = `lib/presentation/providers/chat_provider/`. Anything not stated by code or docs is marked **(inferred)**.

---

## 0. TL;DR for v2 planners

1. **Transport**: plain HTTP JSON over Dio, plus two concurrent SSE streams (`/event?directory=…` and `/global/event`), plus one WebSocket per terminal (`/pty/:id/connect`). No SDK, no OpenAPI codegen: every model is hand-parsed, tolerant of many shapes (camelCase/PascalCase IDs, envelopes, legacy schemas).
2. **Scoping**: always the `directory` **query parameter**. `x-opencode-directory` is never used. Discovery and config calls also send `workspace=<directory>`.
3. **Send path**: `POST /session/:id/prompt_async` (never the blocking `/message`). The client deliberately does **not** send `messageID`, but it **does** generate part IDs (`prt_<µs>_<seq>_<i>`). Completion is detected by a **polling watcher** (`/session/status` + `/session/:id/message?limit=120` + `/session/:id/message/:mid`), in parallel with SSE.
4. **SSE is treated as lossy**. There is no `Last-Event-ID` replay (upstream issue #25657, quoted in `CPD/chat_provider_realtime_aux_ops.dart:356-360`). Every `message.updated`/`message.created` and many `message.part.*` events trigger an HTTP re-fetch of the whole message. On reconnect the client re-lists sessions, statuses, permissions and questions.
5. **Lifecycle truth**: `session.status` (`idle|busy|retry`) and `session.idle` drive busy/idle. "In-progress assistant" means `info.time.completed` is absent. Many heuristics sit on top (§6).
6. **Already v2-aware in a few spots**: the reducers accept `permission.v2.*`, `question.v2.*` and `session.next.{moved,revert.staged,revert.cleared,revert.committed}` events. Their payloads are unwrapped from `request`/`permission`/`question`/`info` envelopes.
7. **Hacks that piggy-back on chat sessions**:
   - title generation: hidden `_title_gen` session using the `title` agent
   - file write/rename/delete: hidden session + `/session/:id/shell` running an encoded script
   - quota probing: hidden session + `/shell` running `node -e <base64 JS>`
   - optional multi-device selection sync: a fake agent `__codewalk` written through `PATCH /config`

---

## 1. HTTP client setup

| Item | Value | Where |
|---|---|---|
| Default base URL | `http://127.0.0.1:4096` | `lib/core/constants/api_constants.dart:4-6` |
| Timeouts (regular Dio) | connect 30 s, receive 60 s, send 30 s | `api_constants.dart:35-37`, `lib/core/network/dio_client.dart:13-23` |
| Timeouts (SSE Dio) | connect 10 s (5 s per request), receive 2 h, send 10 s; own `HttpClient` with `idleTimeout` 2 h and `maxConnectionsPerHost` 4 | `dio_client.dart:28-36`, `dio_sse_adapter_io.dart:9-19`, `DS:1836-1845` |
| Message-list receive timeout | 3 min (`getMessages`, `getMessage`) | `DS:774-777`, `DS:823-826` |
| Content-Type | `application/json` | `dio_client.dart:22` |
| Basic auth | `Authorization: Basic b64(user:pass)`, sent **only** to the exact configured origin | `dio_client.dart:101-113, 326-346` |
| OAuth (Cloudflare Access) | `Authorization: Bearer <token>`, same-origin only; overrides Basic | `dio_client.dart:131-148, 317-339`; ADR-033 |
| Sticky header | `X-Session-Id`: echoes whatever value the server returned; reset on base-URL change or auth clear | `dio_client.dart:52, 348-358` |
| Tailscale | swaps `httpClientAdapter` on both Dio instances (userspace tailnet) | `dio_client.dart:67-81`, `lib/core/tailscale/tailscale_http_adapter.dart` |
| Health-check Dio | separate instance; copies headers and adapter | `dio_client.dart:83-98`, `lib/presentation/providers/app_provider.dart:2215-2251` |

Error mapping (`DSH:160-382`):
- `401`/`403` → "Authentication failed"
- `409` → "Session is busy" (`ConflictException`)
- `429` → rate limit
- `503` → "server starting up"
- `>=500` → provider unavailable

Structured server errors are flattened from `{name, code, message|data.message, details|meta, errors[]}` into one string.

---

## 2. Every HTTP endpoint CodeWalk calls

`?directory` = the active project directory is sent as a query parameter (when known).

### 2.1 Health and bootstrap

| Method / path | Params / body | Fields read | Call site(s) |
|---|---|---|---|
| `GET /global/health` | — | status 200 only (`version` ignored) | `app_provider.dart:2255` (polled every 10 s; data saver changes this); `pages/opencode_setup_debug_page.dart:169` (doc text only) |
| `GET /path` | `?directory` | `config, state, worktree\|root, directory\|cwd, home` | `ADS:181, 201` (readiness probe); `app_provider.dart:2284` (health fallback) |
| `GET /app` (legacy) | `?directory` | `AppInfoModel` (`hostname, git, path{config,data,root,cwd,state}, time`) | `ADS:189`, only when `/path` fails |
| `POST /app/init` (legacy) | `?directory` | `success` | `ADS:206-209`, only when `/path` fails |

### 2.2 Catalog and config

| Method / path | Params / body | Fields read | Call site(s) |
|---|---|---|---|
| `GET /provider` | `?directory&workspace`; retried with directory only, then unscoped | `all[]` (or legacy `providers[]`), `default{}`, `connected[]`. Per provider: `id, name, env, npm, api, options, models{}`. Per model: `id, name, release_date, last_updated, attachment, reasoning, temperature, tool_call, knowledge, open_weights, cost{input,output,cache_read,cache_write}, limit{context,output}, modalities{input,output}, capabilities{…}, variants{}, options, hidden, status` | `ADS:226-233`; `settings_provider_opencode_defaults.dart:22` |
| `GET /agent` | same 3-step fallback; accepts a list, `{agents\|items\|data\|results:[]}`, grouped maps, or keyed maps | `name, mode, hidden, native, color` (description/model/prompt/permission **ignored**) | `ADS:118-126, 236-279`; `settings_provider_opencode_defaults.dart:35` |
| `GET /config` | `?directory&workspace` (same fallback) | `model, small_model, default_agent, username, snapshot, autoupdate, share, notifications.*`, and `agent.__codewalk.options.codewalk` (selection sync) | `ADS:282-289`; `settings_provider.dart:2192`; `settings_provider_opencode_defaults.dart:15`; `CPD/chat_provider_selection_sync_ops.dart:99` |
| `PATCH /config` | `{model}` / `{small_model}` / `{default_agent}` / `{username}` / `{snapshot}` / `{autoupdate}` / `{share}` | — | `settings_provider_opencode_defaults.dart:105,131,157,185,208,231,254` |
| `PATCH /config` | `{notifications:{<k>:bool}}` or `{<k>:bool}` | — | `settings_provider.dart:2288, 2295` |
| `PATCH /config` | `{agent:{__codewalk:{options:{codewalk:{selection…, variantByAgentAndModel, variantByModel, sessionSelections, updatedAtEpochMs}}}}}` with `?directory&workspace` | — | `CPD/chat_provider_selection_helpers.dart:375-397`. Only when the experimental multi-device sync setting is on (`CP:1449-1451`, default **false** in `experience_settings.dart:921`). Deferred while busy (ADR-019): v1 `Config.update()` disposes the instance and aborts running sessions. |
| `GET /command` | none (no directory!) | `name, source, description` | `pages/chat_page/chat_page_command_query.dart:105` |
| `GET /file?path=.opencode/commands` | `?directory` | `type=='file'`, `name` ending in `.md` | `chat_page_command_query.dart:182-189`. Client-side discovery of project commands; duplicates `/command` **(v1 workaround)**. |

### 2.3 Projects, files, search, VCS, worktrees

| Method / path | Params / body | Fields read | Call site(s) |
|---|---|---|---|
| `GET /project` | — | list or `{projects:[]}`. Per project: `id, name\|title\|label, path\|directory\|worktree\|root\|cwd, time\|createdAt\|updatedAt` | `PDS:79, 97` |
| `GET /project/current` | `?directory` | same | `PDS:88-92, 107` |
| `GET /vcs` | `?directory` | `branch` (non-empty ⇒ git) | `PDS:207-219` |
| `GET /file` | `?directory&path` | `name, path, absolute, type(file\|directory), children, id, file` | `PDS:179-249`; `services/project_icon_discovery_service_io.dart:315`; `chat_page_command_query.dart:184` |
| `GET /file/content` | `?directory&path` | `content\|text\|body\|data\|value`, `type`, `encoding`, `mime\|mimeType`, `binary` (base64 handling) | `PDS:354-368`; `project_icon_discovery_service_io.dart:400` |
| `GET /find/file` | `?directory&query&limit=50[&type]` | `string[]` or `FileNode` maps | `PDS:251-296`; `project_icon_discovery_service_io.dart:353` |
| `GET /find` | `?directory&pattern&limit=50` | `path, lines, line_number\|lineNumber\|line, absolute_offset, submatches` | `PDS:298-322` |
| `GET /find/symbol` | `?directory&query&limit=10` | `name, kind, path, uri, location` | `PDS:324-352` |
| `GET /experimental/worktree` | `?directory` | list or `{worktrees:[]}`: `id\|worktreeID\|workspaceID, name, path\|directory\|root, projectID, active, createdAt` | `PDS:111-140` |
| `POST /experimental/worktree` | body `{name}`, `?directory` | worktree | `PDS:142-154` |
| `POST /experimental/worktree/reset` | body `{id}`, `?directory` | — | `PDS:156-167` |
| `DELETE /experimental/worktree` | `?id&directory` | — | `PDS:169-176` |

### 2.4 Sessions

| Method / path | Params / body | Fields read | Call site(s) |
|---|---|---|---|
| `GET /session` | `?directory[&search][&roots=true][&start=<ms>][&limit]`. The main list sends **only `directory`** (unbounded, includes children: `CP:3563-3567`). `roots`/`limit` are used by the forward-message picker (`services/forward_message_service.dart:238-240`). | `id, title\|name\|sessionTitle, parentID\|parentId, directory, version, workspaceId, time{created,updated,archived}, share{url}\|shared, summary (string or {additions,deletions}), path{root,workspace}, revert{messageID,partID,snapshot,diff}` | `DS:274-323`; `services/session_attention/session_overlay_entrypoint.dart:461`; `services/android_background_alert_worker.dart:1230` |
| `GET /session/:id` | `?directory` | same | `DS:325-359` |
| `POST /session` | `{parentID?, title?}` (title defaults to `"New chat"`) | session | `DS:361-396`; hidden sessions in `services/chat_title_generator.dart:112`, `services/workspace_file_operations_service.dart:729`, `data/datasources/quota_remote_datasource.dart:291` |
| `PATCH /session/:id` | `{title?, time:{archived:<ms>}?}` | session | `DS:398-437`. Archive goes through `time.archived` **(undocumented in the snapshot, which lists `{title?}` only)**. |
| `DELETE /session/:id` | `?directory` | status 200 | `DS:439-471`; hidden-session cleanup at `chat_title_generator.dart:177`, `workspace_file_operations_service.dart:712`, `quota_remote_datasource.dart:276` |
| `POST /session/:id/share` / `DELETE …/share` | — | session (`share.url`) | `DS:473-543` |
| `POST /session/:id/fork` | `{messageID?}` | session | `DS:545-586` |
| `GET /session/status` | `?directory` | map `sessionID → {type: idle\|busy\|retry, attempt?, message?, next?}`; missing ⇒ idle | `DS:588-629, 1153-1173`; `android_background_alert_worker.dart:1197`; `session_overlay_entrypoint.dart:460` |
| `GET /session/:id/children` | `?directory` | sessions | `DS:631-669` |
| `GET /session/:id/todo` | `?directory` | `id, content, status, priority` | `DS:671-709` |
| `GET /session/:id/diff` | `?directory[&messageID]` | `file, before, after, additions, deletions, patch` | `DS:711-753`. Without `messageID` upstream returns `[]`, so "Review changes" scans up to 25 user turns one call each (`CP:737-740, 2270-2302`) **(v1 workaround)**. |
| `POST /session/:id/abort` | `?directory` | 200 | `DS:2246-2277` |
| `POST /session/:id/revert` | `{messageID}` (`partID` never sent) | 200 | `DS:2279-2312` (undo, inline rewind; ADR-031) |
| `POST /session/:id/unrevert` | — | 200 | `DS:2314-2345` (redo) |
| `POST /session/:id/summarize` | `{providerID, modelID}` | 200 | `DS:2391-2435` (`/compact`) |
| `POST /session/:id/init` | `{messageID, providerID, modelID}` | 200 | `DS:2347-2389`. **Wired in data/domain only; no UI caller.** |

### 2.5 Messages and sending

| Method / path | Params / body | Fields read | Call site(s) |
|---|---|---|---|
| `GET /session/:id/message` | `?directory[&limit]`. Cold open 51; older pages = `resident+50+1` (**re-fetches the whole tail**, no cursor); SWR tail 200; completion watcher 120 | `[{info, parts}]` flattened to `ChatMessageModel` (§4) | `DS:755-805`; `DS:944, 1039, 1177` (watcher); `CP:4613-4660` (older pages); `chat_title_generator.dart:157`; `car_messaging_dispatch_worker.dart:277` (`limit=20`) |
| `GET /session/:id/message/:mid` | `?directory` | `{info, parts}` | `DS:807-849` (`getMessage`, the main SSE re-fetch path); `DS:2206-2244` (`_getCompleteMessage`, watcher) |
| `POST /session/:id/prompt_async` | body from `ChatInputModel.toJson()` (`data/models/chat_session_model.dart:376-399`): `{parts:[…], model:{providerID,modelID}, noReply:false, variant?, agent?, system?, tools?}`. **No `messageID`** (ADR-023 P-001). Each part carries a client id `prt_<µs>_<seq>_<i>` (`chat_session_model.dart:401-419`). | 204/200 accepted. If the response is a **completed** assistant `{info,parts}`, it is used directly (`DS:1656-1704`). | `DS:1639-1654`; `services/car_messaging/car_messaging_dispatch_worker.dart:78` (Android Auto reply: `{parts:[{type:text,text}]}` only, no model or agent) |
| `POST /session/:id/command` | `{command, arguments, model?:"provider/model"}` (`messageID`/`agent` never sent) | `{info, parts}` | `DSH:70-158`. Used when composer mode is `command`. |
| `POST /session/:id/shell` | `{agent:"build", command}` (agent hard-coded) | `{info, parts}` | `DSH:5-68` (`!` shell mode); `workspace_file_operations_service.dart:685`; `quota_remote_datasource.dart:177` |
| `POST /session/:id/message` (blocking) | `{agent:"title", parts:[{type:text,text}], noReply:false}` | — | `chat_title_generator.dart:130` (hidden title session only) |

Input part shapes (`chat_session_model.dart:458-517`):
- `text`: `{type, text, id}`
- `file`: `{type, mime, url, filename?, source?:{path, text:{value,start,end}, type}, id}`
  - `url` is a `data:<mime>;base64,…` URI for attachments (`widgets/chat_input/chat_input_attachment_controller.dart:217`)
  - or `file://<path>?start=&end=` for file-viewer selections (`pages/chat_page/chat_page_file_viewer.dart:1072-1080`)
- `agent`: `{type, name, id, source?}`. Defined but **never constructed by the UI**. `@agent` and `@file` mentions are inserted as plain text `@value ` (`widgets/chat_input/chat_input_mentions_controller.dart:27-50`), so the server receives text, not file/agent parts. Whether OpenCode expands them server-side: **(inferred: no; the official TUI converts mentions to parts client-side)**.

### 2.6 Permissions and questions

| Method / path | Params / body | Fields read | Call site(s) |
|---|---|---|---|
| `GET /permission` | `?directory` | `id, sessionID, permission, patterns[], always[], metadata{}, tool{messageID,callID}` | `DS:1992-2026`; `android_background_alert_worker.dart:1287`; `session_overlay_entrypoint.dart:503` |
| `POST /session/:sid/permissions/:pid` (canonical) | `{response: once\|always\|reject, remember?: true (only for always), message?}` | 200 | `DS:2041-2058`; `android_background_alert_worker.dart:962` |
| `POST /permission/:pid/reply` (legacy) | `{reply, remember?, message?}`. Used only after 404/405 on the canonical route. | 200 | `DS:2060-2078`; `android_background_alert_worker.dart:978` |
| `GET /question` | `?directory` | tolerant: `id\|requestID, sessionID\|sessionId, questions[{question, header, options[{label,description}], multiple, custom}], tool{messageID,callID}`, optionally wrapped in `question\|request\|info` | `DS:2100-2134`, model at `data/models/chat_realtime_model.dart:227-265`; background worker `:1327`; overlay `:504` |
| `POST /question/:rid/reply` | `{answers: List<List<String>>}` (one list of selected labels/free text per question). **No `sessionID`.** | 200 | `DS:2136-2173` |
| `POST /question/:rid/reject` | — | 200 | `DS:2175-2204` |

The local `ai-docs/opencode_server.md` snapshot documents **only** the session-scoped permission reply (`:149`). `/permission`, `/question*` and `/permission/:id/reply` are **not in the snapshot** (`CONTRACT_MATRIX.md` "Permissions/questions" row marks them "needs verification").

### 2.7 Terminal (PTY): not in the local doc snapshot

| Method / path | Params / body | Fields read | Call site(s) |
|---|---|---|---|
| `POST /pty` | body `{cwd: directory}`, `?directory` | `id, pid, command, args, cwd, title, status` | `data/datasources/terminal_remote_datasource.dart:26-58` |
| `PUT /pty/:id` | `{size:{rows, cols}}`, `?directory` | 200 | `terminal_remote_datasource.dart:60-87` |
| `DELETE /pty/:id` | `?directory` (404 ignored) | 200 | `terminal_remote_datasource.dart:89-106` |
| `WS /pty/:id/connect` | `?directory[&cursor=<n>]`; `ws`/`wss` from the base URL; auth headers are passed to `WebSocket.connect`; over Tailscale a hand-rolled RFC 6455 client runs on a tailnet TCP dial | raw terminal bytes | `services/codewalk_terminal_url.dart:1-20`; `services/codewalk_terminal_socket_io.dart:13-16, 80-112, 205-580` |

### 2.8 Non-OpenCode or host-shell endpoints reached through the OpenCode base URL

| Call | Purpose | Where |
|---|---|---|
| `GET /api/quota/providers`, `GET /api/quota/:providerId` | **OpenChamber** quota REST, tried first | `quota_remote_datasource.dart:92, 145` |
| `POST /session` → `POST /session/:id/shell` (`node -e "eval(Buffer.from('<b64>','base64')…)"`) → `DELETE /session/:id` | Quota probe: reads the host `auth.json` and calls provider usage APIs; parses the `CW_QUOTA_JSON:` line | `quota_remote_datasource.dart:177, 276, 291`; JS in `quota_remote_datasource.part.js.dart`; ADR-029 |
| `POST /session` → `POST /session/:id/shell` (`printf <encoded script> \| <decoder> \| <ENV> sh`, 48 KiB env chunks) → `DELETE /session/:id` | File create/rename/delete/write; result parsed from the `CW_FILE_OP_JSON:` sentinel in `parts[].state.output` | `workspace_file_operations_service.dart:664-734`; ADR-043 (ADR-023 exception) |

### 2.9 Official endpoints NOT consumed (from `ai-docs/opencode_server.md`)

- `/instance/dispose`
- `/config/providers`
- `/provider/auth`, `/provider/{id}/oauth/authorize`, `/provider/{id}/oauth/callback`
- `PUT /auth/:id`
- `/file/status`
- `/experimental/tool/ids`, `/experimental/tool`
- `/lsp`, `/formatter`, `GET /mcp`, `POST /mcp`
- `POST /log`
- all `/tui/*`
- `/doc` (mentioned only as a troubleshooting hint)

So CodeWalk has **no** provider login, MCP status, LSP/diagnostics or formatter UI.

---

## 3. Realtime (SSE)

### 3.1 Streams and lifecycle

**Two streams run at the same time** in the foreground (`CPD/chat_provider_realtime_ops.dart:194-373`):
1. `GET /event?directory=<current>`: the "session stream", reduced by `_applyChatEvent`.
2. `GET /global/event`: the "global stream", routed by `_handleGlobalEvent` (`CPD/chat_provider_event_reducer_global_ops.dart:4-106`).
   - Not opened under the aggressive cellular data saver (`realtime_ops.dart:304-307`).

Request details:
- Headers `Accept: text/event-stream` and `Cache-Control: no-cache`.
- Response is streamed with `responseType: stream` (`DS:1833-1847`).
- Only the **dedicated SSE Dio** is used (ADR-018: pool isolation stops Android evicting SSE, which the server saw as a disconnect and answered with a false `MessageAborted`).

Parser (`DS:1858-1905`):
- Bytes are `utf8.decode`d **per chunk**. A multi-byte character split across TCP chunks would throw or garble that chunk; the decode is not streaming **(inferred risk)**.
- Lines are split; only lines starting with `data: ` are kept. `event:`, `id:` and `retry:` are ignored, and multi-line `data:` is **not** concatenated.
- `[DONE]` is skipped. Each data line is decoded as JSON into `ChatEventModel`.
- Envelope handling (`data/models/chat_realtime_model.dart:13-39`):
  - Global events `{directory?, project?, workspace?, payload:{type, properties}}` are unwrapped, and the **outer** `directory/project/workspace` are copied into `properties`. Outer context wins (CONTRACT_MATRIX).
  - Instance events are `{type, properties}`.

Reconnect loop (`DS:1827-1968`):
- Runs while subscribed; `onListen` starts it and `onCancel` cancels the token.
- Backoff is `300ms·2^min(attempt,5)`, capped at 8 s, with ±20 % jitter (`DS:1959-1967`).
- The attempt counter resets only if the stream lived ≥ 5 s (`DS:220-224, 1909-1920`).
- Expected transient errors are logged at info level.

Provider-level health (`CPD/chat_provider_realtime_aux_ops.dart:350-503`, `CPD/chat_provider_realtime_ops.dart:49-123`):
- Every event marks `_lastRealtimeSignalAt`.
- A health timer runs every **5 s**. No signal for **20 s** ⇒ `ChatSyncState.delayed` plus **degraded mode**.
- 3 consecutive stream failures ⇒ degraded mode.
- Degraded mode polls every **30 s**: `loadSessions` + `refreshActiveSessionView` + `/permission` + `/question` + `GET /config` selection sync.
- Defaults are in `CP:192-201`.
- Resume grace suppresses false alarms after the app returns to the foreground.

Heartbeats:
- `server.heartbeat` is accepted and ignored (`global_ops.dart:21-23`; `session_ops.dart:126-127`).
- It still refreshes the liveness timestamp, because any event calls `_markRealtimeSignal` (`realtime_ops.dart:262-266, 326-332`).

Reconnect recovery:
- The first signal after failures ⇒ `_runPostReconnectRecovery`: pending interactions + active session view (with status) + `loadSessions` (`realtime_aux_ops.dart:400-461`).
- Reason: "OpenCode server does NOT support Last-Event-ID replay (upstream issue #25657)" (`:356-360, 412`).

Mutations are blocked while reconnecting (`_guardTransportForAction`, `realtime_ops.dart:33-47`; ADR-030):
- send, delete, rename, permission/question replies
- the draft is preserved

Generation counters (`_eventStreamGeneration`) drop callbacks from superseded subscriptions. A restart while one is in flight is queued (`realtime_ops.dart:199-213`).

When the app goes to the background (`CPD/chat_provider_lifecycle_ops.dart:4-75`):
- UI rebuilds are suppressed, and the deferred notify is flushed on resume (`CP:768-791`).
- Automatic network work pauses.
- SSE streams are closed only when cellular data saver disables background network (`:41-54`).
- Android keeps realtime for a short hold during an active response (BEHAVIOR "Android short-hold resume reconciliation").
- Longer monitoring moves to the Android foreground service plus the WorkManager polling worker (§7).
- On resume, one coalesced reconciliation runs: restart SSE, then pending interactions, sessions, the active session, insights and the selection (`realtime_ops.dart:125-192`).

### 3.2 Deduplication and ordering

Because both streams deliver many identical events, `_claimRecentlyProcessedEvent` keeps a **256-entry ring** of keys (`CPD/chat_provider_event_reducer_helpers.dart:163-330`; `CP:678-689`):
- Key = `type:sessionID:messageID:partID:requestID:<payload hash>`.
- The hash is FNV-1a over canonical sorted JSON of `info` / `{part,delta,field}` / the revert mutation (`helpers.dart:224-310`).
- Events with no fine-grained ID (e.g. `session.status`) are **not** deduped.

Global-stream routing (`global_ops.dart`):
- Event for the active context (`serverId::directory`, or no directory) ⇒ applied incrementally if it is in the 31-type allow-list (`:108-153`).
- Otherwise ⇒ a 300 ms debounced context refresh (`:155-176, 720-760`).
- Event for an inactive context ⇒ patched into that context's cached snapshot (`:178-…`) or marked dirty for SWR.

Ordering protections:
- Stale `session.updated` events are ignored when `time.updated` is older than the local copy (`session_ops.dart:158-167`).
- A pending local rename wins until the server echoes the same title (`:176-187`).
- Recently removed message and part keys are remembered (ring of 256) so late fetches cannot resurrect them (`CP:682-686`; `message_merge_ops.dart:81-88`).
- A per-message `localDeltaVersion` invalidates HTTP fallbacks scheduled before newer deltas. A stale fallback may only merge completion/metadata (ADR-041; `message_merge_ops.dart:25-120`).
- Completed messages are never regressed to incomplete (ADR-023 P-002).
- Timeline order is anchored on neighbouring IDs, never on device-vs-server clocks (`CPD/message_timeline_order.dart`, `CPD/message_reconciliation.dart`; BEHAVIOR "Message Reconciliation").
- Delta notifications are batched: 16 ms on mobile/web, 120 ms on desktop. They are flushed immediately on `session.idle`, idle status, or error (`CP:742-936`).

### 3.3 Event types handled

All in `CPD/chat_provider_event_reducer_session_ops.dart` (`S:`) unless noted. The global allow-list is at `global_ops.dart:113-147`.

| Event | Properties read | Effect | Where |
|---|---|---|---|
| `server.connected` | — | refresh active session view; force remote selection sync | `S:128-149` |
| `server.heartbeat` | — | ignored (liveness only) | `S:126`, `global_ops:21` |
| `session.created` / `session.updated` | `info` (Session) | upsert into list; replace current session (re-render on `revert` change); dismiss notifications; skip stale or ephemeral `_title_gen` | `S:150-206`; inactive snapshot `global_ops:195-219` |
| `session.deleted` | `info.id` \| `sessionID` \| `id` | remove session + caches; reload if it was current | `S:207-226` |
| `session.status` | `sessionID`, `status{type,attempt,message,next}` | `_sessionStatusById`; busy/retry clears unread; busy→idle on a non-visible root ⇒ unread + attention; flush on idle | `S:227-280`; inactive `global_ops:242-280` |
| `session.idle` | `sessionID` | **terminal turn signal**: flush deltas; status=idle; `_markIncompleteAssistantMessagesAsCompleted` (stamps a local `completedTime`!); end the composer "sending" state; cancel pending message fallbacks; unread/attention; notify the title generator | `S:357-453`; `global_ops:5-13, 281-318` |
| `session.error` | `sessionID`, `error{name, message, data{message, code, statusCode\|status}}` | non-current ⇒ idle + error attention (not for child sessions); current ⇒ abort-like errors suppressed or turned into an inline "aborted" message; others ⇒ `_presentServerErrorForCurrentSession` | `S:454-549`; helpers `:459-486` |
| `session.diff` | `sessionID`, `diff[]` | current session only; keep the known-good diff when the payload is empty or has no content | `S:281-334` |
| `todo.updated` | `sessionID`, `todos[{id,content,status,priority}]` | current session only | `S:335-356` |
| `message.created` / `message.updated` | `info{id\|messageID, sessionID}` | **does not apply `info`**: schedules `GET /session/:id/message/:mid` (`_fetchMessageFallback`); skips when the local copy is already completed (created) | `S:550-590`; `CPD/chat_provider_message_merge_ops.dart:48-…` |
| `message.part.updated` | `part` (full Part), optional `delta` | upsert part; merge `delta` when present; unknown message ⇒ fetch whole message; a delta on an unknown part ⇒ fetch | `S:591-770` |
| `message.part.delta` | `sessionID, messageID, partID, field, delta` (or `part`) | appends `delta` to `text` of TextPart/ReasoningPart only (`field=='text'`, `message_state_ops.dart:483-520`); other fields or unknown part ⇒ full message fetch; **every delta also schedules a 120 ms debounced full-message fetch** for assistant messages (`message_merge_ops.dart:25-46`) | `S:591-684` |
| `message.part.removed` | `sessionID, messageID, partID` | remove part, remember tombstone | `S:771-798` |
| `message.removed` | `sessionID, messageID` | remove message, remember tombstone | `S:799-817` |
| `permission.asked` / `permission.updated` / `permission.v2.asked` / `permission.v2.updated` | payload or `permission\|request\|info` envelope → `ChatPermissionRequest` | upsert per session; parse failure ⇒ re-list `/permission` | `S:818-860` |
| `permission.replied` / `permission.v2.replied` | `requestID\|id`, sessionID | remove; dismiss notifications; tell the background worker | `S:861-909` |
| `question.asked` / `question.updated` / `question.v2.asked` / `question.v2.updated` | as above → `ChatQuestionRequest` | upsert; first-seen timestamp | `S:910-952` |
| `question.replied` / `question.rejected` / `question.v2.replied` / `question.v2.rejected` | `requestID\|id` | remove; 15 s "recently resolved" grace so stale list responses don't resurrect it | `S:953-1005` |
| `session.next.moved` | — | full context refresh (sessions + status + active) | `S:1006-1014` |
| `session.next.revert.staged` / `.cleared` / `.committed` | `sessionID?` | serialized server-authoritative refresh | `S:1015-1033`; dedup `helpers.dart:268-275` |
| `catalog.updated` (global) | — | `initializeProviders()` (re-GET `/provider`, `/agent`, `/config`) | `global_ops:16-19` |
| `project.*`, `worktree.*` (global) | `directory` | not reduced; trigger a debounced session/status refresh | `global_ops:26-33, 155-176` |

Any other event type is ignored (`S:1034`). The notification side-channel (`services/event_feedback_dispatcher.dart:160-200`) handles permission/question asked/updated (v1+v2), `session.error` and `session.idle`, plus a synthetic idle derived from a busy→idle `session.status` (`helpers.dart:404-433`).

Session-ID extraction (`presentation/utils/chat_event_property_extractors.dart:1-94`) checks, in order:
1. `sessionID` / `sessionId`
2. `info.{sessionID|sessionId|id}`
3. `request|permission|question|session|part.{sessionID|sessionId}` (v2 puts the owner under `request`)

Directory extraction checks `directory`, then `info|session|project.directory`.

---

## 4. Data models mirrored in Dart

| OpenCode concept | Data model (JSON) | Domain entity | Notes |
|---|---|---|---|
| Session | `ChatSessionModel` — `lib/data/models/chat_session_model.dart:13-202` (+ `SessionTimeModel`, `SessionShareModel`, `SessionPathModel`, `SessionRevertModel`) | `ChatSession` — `lib/domain/entities/chat_session.dart:6` (+ `SessionPath`, `SessionRevert` in `session.dart:57`) | `summary` is flattened to a string `"additions: X, deletions: Y"`; `workspaceId` defaults to `'default'` |
| Session create/update input | `SessionCreateInputModel`, `SessionUpdateInputModel` (`chat_session_model.dart:521-579`) | `SessionCreateInput`, `SessionUpdateInput` | — |
| Prompt input | `ChatInputModel`, `ChatInputPartModel` (`chat_session_model.dart:327-517`) | `ChatInput`, `TextInputPart`, `FileInputPart`, `AgentInputPart` (`chat_session.dart:138-275`) | `mode` doubles as agent name, or the sentinels `command` / `shell` |
| Message | `ChatMessageModel` (`lib/data/models/chat_message_model.dart:10-263`, `.g.dart`) | `UserMessage` / `AssistantMessage` (`lib/domain/entities/chat_message.dart:4-80`) | reads `id, sessionID, role, time{created,completed}, providerID, modelID, variant\|variantID, cost, tokens, error, mode, system, path, summary` (bool for assistant; an object for user is synthesized into a text part). **User `agent`/`model` fields are not mapped.** |
| Part | `MessagePartModel` (`chat_message_model.dart:267-951`) | 12 subclasses (`chat_message.dart:83-335`) | types: `text, file, tool, agent, reasoning, step-start\|step_start, step-finish\|step_finish, snapshot, patch, subtask, retry, compaction`. **Unknown types fall back to `text`** (`:698`). Tool `state.status`: `pending\|running\|completed\|error` with `input, output (string/list/map flattened), title, metadata, time{start,end}, error`. File `source`: `file` or `symbol` (with LSP range). |
| Tokens / error | `MessageTokensModel` (`:954`), `MessageErrorModel` (`:1025`) | `MessageTokens`, `MessageError` (`chat_message.dart:566-612`) | tokens `input, output, reasoning, cache{read,write}`; error `name, message\|data.message, statusCode, isRetryable` |
| Legacy duplicate | — | `lib/domain/entities/message.dart` (`Message`, `ProviderAuthError`, …) | **dead code**: only `test/unit/models/message_entity_test.dart` imports it |
| Session status | `SessionStatusModel` (`chat_realtime_model.dart:50-86`) | `SessionStatusInfo`, `SessionStatusType{idle,busy,retry}` (`domain/entities/chat_realtime.dart:14-32`) | — |
| Event | `ChatEventModel` (`chat_realtime_model.dart:13-48`) | `ChatEvent{type, properties}` | untyped map; every reducer re-parses it |
| Permission | `ChatPermissionRequestModel` (`chat_realtime_model.dart:109-163`) | `ChatPermissionRequest` (`chat_realtime.dart:46-75`) | `permission, patterns, always, metadata, tool{messageID,callID}` |
| Question | `ChatQuestionRequestModel` / `…InfoModel` / `…OptionModel` (`chat_realtime_model.dart:165-288`) | `ChatQuestionRequest/Info/Option` (`chat_realtime.dart:77-124`) | `custom` defaults to **true** |
| Todo / Diff | `SessionTodoModel`, `SessionDiffModel` (`lib/data/models/session_lifecycle_model.dart`) | `SessionTodo`, `SessionDiff` (`chat_session.dart:297-346`) | — |
| Provider / Model / Variant | `ProvidersResponseModel`, `ProviderModel`, `ModelModel`, `ModelVariantModel` (`lib/data/models/provider_model.dart`) | `Provider`, `Model`, `ModelVariant`, `ModelCost`, `ModelLimit`, `ProvidersResponse` (`domain/entities/provider.dart`) | accepts old `{providers, default}` and new `{all, default, connected}` |
| Agent | `AgentModel` (`lib/data/models/agent_model.dart`) | `Agent` (`domain/entities/agent.dart`) | 5 fields only |
| Project / Worktree | `ProjectModel`, `WorktreeModel` | `Project`, `Worktree` | very tolerant key aliases |
| File / search | `FileNodeModel`, `FileContentModel`, `FileSearchMatchModel`, `WorkspaceSymbolModel` | `FileNode`, `FileContent`, `FileSearchMatch`, `WorkspaceSymbol` (`domain/entities/file_node.dart`) | — |
| PTY | `PtySessionModel` (`lib/data/models/pty_session_model.dart`) | (none: used directly by the presentation layer) | — |
| App/path | `AppInfoModel` (+ `.g.dart`) | `AppInfo` (`domain/entities/app_info.dart`) | legacy `/app` shape |
| Command | (no model) raw `Map` in `chat_page_command_query.dart:105-125` | `ChatComposerSlashCommandSuggestion` (UI type) | — |
| Quota | (raw JSON from OpenChamber or the shell probe) | `domain/entities/quota.dart` | not an OpenCode concept |

The interface boundary is `lib/domain/repositories/chat_repository.dart` (25 methods), `app_repository.dart` (6) and `project_repository.dart` (14). Return types are `Either<Failure, T>` (dartz). Many presentation services bypass them and use `DioClient` directly (see `00-…-inventory.md` §5).

---

## 5. Permission request → reply flow

1. **Discovery**:
   - SSE `permission.asked|updated|v2.asked|v2.updated` ⇒ `_pendingPermissionsBySession[sessionID]` (`S:818-860`).
   - `GET /permission` on session switch, reconnect, degraded poll and resume (`realtime_aux_ops.dart:513-697`).
   - Locally dismissed IDs are kept as tombstones (ring of 256) so an in-flight list response cannot resurrect them (`:603-607, 789-800`).
2. **Display**:
   - `widgets/permission_request_card.dart`: buttons `reject`, `always`, `once` (`:120-128`).
   - Shows `permission`, `patterns`, and tool metadata.
   - Child-session (subagent) requests are mirrored into the parent thread.
3. **Auto-approve (ADR-023 EXC-001)**:
   - Setting `composerAutoApprovePermissions`, **default `true`** (`domain/entities/experience_settings.dart:910`).
   - Toggled from the agent menu (`pages/chat_page/chat_page_model_selector_runtime.dart:819-885`).
   - The drain runs in the **page layer** (`pages/chat_page/chat_page_lifecycle.dart:240-310`).
   - It always replies `always` + `remember:true` (`services/permission_auto_approve_runtime.dart:3-14`).
   - The Android background worker auto-approves too, limited to primed session IDs, and treats 404 as already resolved (`android_background_alert_worker.dart:950-990`).
   - **Questions are never auto-answered.**
4. **Reply** (`CP:2630-2679` → `ReplyPermission` usecase → `DS:2028-2098`):
   - `POST /session/:sid/permissions/:pid {response, remember?, message?}`.
   - On 404/405, falls back to `POST /permission/:pid/reply {reply, remember?, message?}`.
   - On success, removes the request locally. The `permission.replied` event does the same idempotently.
5. **Questions**:
   - `CP:2681-…` → `POST /question/:id/reply {answers:[[…]]}` or `/reject`.
   - A failed submit keeps the card with an error marker for 30 s (OpenChamber parity).
   - A list refresh failure retries twice: 5 s, then 10 s (`realtime_aux_ops.dart:770-787`).

---

## 6. How busy/idle/retry and "in progress" are detected

**Server signals**
- `GET /session/status` (map) and SSE `session.status{status.type}`.
  - `busy` and `retry` both count as busy (`DS:1148-1151`).
  - `retry` carries `attempt`, `message`, `next` (epoch ms).
  - A missing entry means idle (`chat_realtime_model.dart:54`).
- SSE `session.idle` is the terminal signal (`S:357-453`).

**Message-level signal**
- An `AssistantMessage` is in progress while `completedTime == null`, i.e. `info.time.completed` is absent or 0 (`chat_message_model.dart:144-153`; `domain/entities/chat_message.dart:62`).

**`isSessionActivelyResponding(sessionId)`** (`CPD/chat_provider_session_attention_ops.dart:404-470`)
- Non-current session: true when status is busy/retry.
- Current session: true when any of these holds:
  1. a send stream is open
  2. state is `sending`
  3. there is an incomplete assistant message
  4. status is busy/retry **and** the latest message is a user message, or an assistant message containing tool/patch parts ("tool-only busy turn")

Further heuristics:
- `isLatestTailSettledRevealable` / `hasCompletedRevealableAssistantMessage` (`presentation/utils/chat_assistant_settlement.dart`) hide Stop/progress once a completed text/reasoning answer is the tail, **even if a stale busy status lingers**.
- After an SSE idle, REST "busy" readings are ignored for 4 s (`_sseSettledAtBySessionId`, `CP:2165`; ADR-037).
- Abort suppression: for 8 s after a send stream ends or Stop is pressed, `session.error` messages that look like aborts (or contain "retry", "cancelled by user") are swallowed (`CPD/chat_provider_abort_policy_ops.dart:3-17`; `CP:202`). A synthetic inline assistant message `msg_inline_abort_<µs>` with error `MessageAborted` is appended instead (`:19-52`). Server errors become `msg_inline_server_error_<µs>` (`:54-…`).
- `_markIncompleteAssistantMessagesAsCompleted` **fabricates `completedTime = now`** on `session.idle`, stream done or abort (`CPD/chat_provider_message_state_ops.dart:568-605`).

**Send-completion watcher** (`DS:851-1785`), which replaced per-send SSE:
1. Before the send: load known assistant IDs (`GET …/message?limit=120`, cached per session, LRU 64).
2. After the 204: poll `/session/status` every 2 s, up to 90 times.
3. Require a busy reading, or a 3 s grace if idle comes first.
4. Once idle: list up to 12× at 1 s intervals to pick the freshest **unknown** assistant ID.
   - Freshness uses the send timestamp with a 5 s clock-skew leeway.
5. Poll `GET …/message/:mid` up to 60× at 1 s until it is completed.
6. If the idle path fails: resolve the ID (12× at 2 s) and poll up to 120× at 1 s.
7. If still nothing: emit "No response from server/model".

Flag: `FeatureFlags.promptAsyncIdleCompletion` (`lib/core/config/feature_flags.dart:22-30`).

**Why per-send SSE was removed:** the v1 server aborts the agent when the per-send SSE socket drops, e.g. on half-open TCP after a mobile resume (`DS:1626-1630`; ADR-018).

---

## 7. Background / out-of-app consumers (same contract, separate code paths)

| Consumer | Calls | Where |
|---|---|---|
| Android WorkManager alert worker | `GET /session/status`, `GET /session`, `GET /permission`, `GET /question`, permission reply (canonical + legacy) | `presentation/services/android_background_alert_worker.dart:950-990, 1197, 1230, 1287, 1327` |
| Android session-attention overlay (separate FlutterEngine) | `GET /session/status`, `GET /session`, `GET /permission`, `GET /question`, one bounded post-idle message fetch | `services/session_attention/session_overlay_entrypoint.dart:435-504, 800-812` |
| Android Auto reply | `POST /session/:root/prompt_async {parts:[text]}` (no model/agent/messageID; no idempotency, ADR-055), then `GET …/message?limit=20` to find the final answer | `services/car_messaging/car_messaging_dispatch_worker.dart:78-100, 270-285` |
| Title generator | hidden session + `POST …/message {agent:"title"}`; waits for SSE `session.idle` (15 s timeout) → `GET …/message` → `DELETE` | `services/chat_title_generator.dart:95-190`; ADR-009 |
| Project icon discovery | `GET /file`, `GET /find/file`, `GET /file/content` | `services/project_icon_discovery_service_io.dart:315-400` |

These consumers each build or receive their own `Dio`, duplicating parsing that already exists in the data layer.

---

## 8. Things not covered (or wrong) in `CONTRACT_MATRIX.md`

1. **Dual-stream SSE + content-hash dedup** (§3.2). The matrix mentions "cross-stream deduplication" but not that **both** streams are always open (except under aggressive data saver).
2. **`message.updated`/`created` never apply `info` directly**; each one causes an HTTP `GET …/message/:mid`. Every text delta also schedules a debounced whole-message GET. This is the main network cost of streaming.
3. **Polling completion watcher** with its exact budgets (§6): up to ~3 min of 1-2 s polling per send. **(inferred: duplicated by SSE in the happy path)**
4. **Pagination has no cursor**: older history re-fetches `limit = resident + 51` (`CP:4613-4660`). Main session list is unbounded (`CP:3563-3567`).
5. **`PATCH /session/:id {time:{archived}}`** for archiving: not in the doc snapshot.
6. **`roots`, `start`, `search`, `limit` on `GET /session`**: not in the doc snapshot.
7. **`workspace` query parameter** duplicated with `directory` on `/provider`, `/agent`, `/config` and with 3-step fallbacks (`ADS:37-171`).
8. **`X-Session-Id` sticky header** (`dio_client.dart:52, 348-358`).
9. **Hidden-session piggy-backing**: title, file ops, quota (§2.8, §7). Hidden-session filtering (`ChatTitleGenerator.ephemeralSessionIds` and the title `_title_gen`) is load-bearing in reducers (`global_ops.dart:14, 203`; `realtime_aux_ops.dart:700-703`).
10. **`/session/:id/shell` hard-codes `agent:"build"`** (`DSH:27`; `workspace_file_operations_service.dart:686`).
11. **Client-generated part IDs `prt_…`** sent in `prompt_async` (`chat_session_model.dart:7-9, 401-419`). The only server-format IDs the client mints; it never sends message IDs.
12. **Selection sync via a fake agent in config** (`__codewalk`, `CP:724-731`; selection helpers): experimental, off by default.
13. **Local `.opencode/commands` listing** via `/file` to supplement `/command`.
14. **Synthetic messages** `msg_inline_abort_*` / `msg_inline_server_error_*`, plus fabricated `completedTime` on idle.
15. **Mentions are sent as plain text**: no file/agent/symbol parts are created from `@` (§2.5).
16. **Unknown part types are rendered as `text`** (`chat_message_model.dart:698`). A new v2 part type would silently show as an empty or odd text bubble.
17. **v2 event names already handled**: `permission.v2.*`, `question.v2.*`, `session.next.*`, `catalog.updated`. The matrix mentions `session.next.revert.*` and `catalog.updated` only.
18. **Skills**: no code anywhere reads skills (`grep -ri skill lib/` → none). Skills only appear if the server lists them in `GET /command` **(inferred)**.
19. **Context-window %** is computed client-side: (`input+output+reasoning+cache.read+cache.write` of the latest assistant message with tokens) ÷ `model.limit.context`. Session cost = sum of **resident** messages only, so it under-counts long sessions (`pages/chat_page/chat_page_status_presenter.dart:136-230`).
