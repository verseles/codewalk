# 13 — OpenCode v1 (v1.18.34) → v2 (v2.0.21) diff for a remote client

> Compared tags: **`v1.18.34`** (`aec0b9a6`, last v1, 2026-09-30) vs **`v2.0.21`** (`8a8bd622`, latest v2 git tag, 2026-09-30; npm `2.0.22` from untagged commit `05018b88` adds only `session.create.parentID` + provider timeouts).
> **V1** = `https://github.com/anomalyco/opencode/blob/v1.18.34/`, **V2** = `https://github.com/anomalyco/opencode/blob/v2.0.21/`.
> v1 ground truth: V1 `packages/sdk/openapi.json` (162 paths) and V1 `packages/sdk/js/src/v2/gen/types.gen.ts`; v2 ground truth: V2 `packages/protocol/src/groups/*.ts`, V2 `packages/client/src/promise/generated/types.ts`. Details of every v2 route/event: files 11 and 12. Items not read directly in code are marked **(inferred)**.

## 0. The 20 changes that break a v1 client

| # | Area | v1.18.34 | v2.0.21 |
|---|---|---|---|
| 1 | Route namespace | root paths (`/session`, `/event`, `/global/*`, …) + an `/api/*` preview | **only `/api/*`** (+ `/auth/connect/:code`, `/openapi.json`); every other path serves the web app HTML with **200** (V2 `packages/cli/src/services/web-ui.ts#L16-L27`) |
| 2 | Auth | optional (`OPENCODE_SERVER_PASSWORD` unset ⇒ open, V1 `packages/opencode/src/cli/cmd/serve.ts#L16`); username `OPENCODE_SERVER_USERNAME` (default `opencode`, V1 `packages/opencode/src/server/auth.ts#L17-L20`) | **always required** (random password printed if none, V2 `packages/server/src/process.ts#L52`); username fixed `opencode`; env `OPENCODE_PASSWORD` (legacy name still read); pairing tokens via `/api/pair` + `/auth/connect/{code}` |
| 3 | Directory scoping | `?directory=` / `?workspace=` / `x-opencode-directory` | `?location[directory]=` or `x-opencode-directory`; no workspace; session routes need none; `POST /api/session` reads `location` from the body only |
| 4 | Event stream | per-directory `GET /event` + `GET /global/event` (`{directory, project?, workspace?, payload}`), JSON `server.heartbeat` every 10 s (V1 `packages/opencode/src/server/routes/instance/httpapi/handlers/event.ts#L63-L67`, `handlers/global.ts#L35-L42`) | single global `GET /api/event`; frames `data: {id, created, type, data, location?, durable?, metadata?}`; heartbeat = SSE comment every 15 s; 4096-event overflow disconnect |
| 5 | Event envelope key | `properties` | `data` (+ `created`, `durable.seq`) |
| 6 | Message model | `{info: UserMessage\|AssistantMessage, parts: Part[]}` with `role` | flat typed union (`user`, `assistant`, `synthetic`, `system`, `shell`, `compaction`, `idle`, `agent-switched`, `model-switched`, `location-switched`, `skill`); assistant `content[]` = text/reasoning/tool |
| 7 | Streaming | `message.part.updated` (full part) + `message.part.delta {partID, field, delta}` | `session.text\|reasoning\|tool.input.{started,delta,ended}`, `session.tool.{called,progress,success,failed}`, `session.step.{started,streamed,ended,failed}` keyed by `assistantMessageID` + `ordinal` / tool `id` |
| 8 | Prompt | `POST /session/{id}/message` (sync, returns assistant) or `/prompt_async`; body `{parts[], model{providerID,modelID}, agent, variant, system, tools, noReply, format, messageID}` | `POST /api/session/{id}/prompt` (async only) body `{id?, text, files?[{uri}], agents?, skills?, metadata?, delivery?: "steer"\|"queue", resume?}`; agent/model/variant set on the session via `/agent` and `/model` |
| 9 | Status | `session.status {busy\|retry\|idle}`, `session.idle`, `GET /session/status` | `session.execution.*`, `session.retry.scheduled`, `GET /api/session/active`, `idle` timeline marker (legacy `session.status` declared but not published) |
| 10 | Errors | named `{name, data}` (`ProviderAuthError`, `APIError`, `ContextOverflowError`, `MessageAbortedError`, …) | `{type, message, status?, response?.body}` with dotted type strings |
| 11 | Model refs | `{providerID, modelID}` | `{providerID, id, variant?}` |
| 12 | Permissions | request `{permission, patterns, always, metadata, tool{messageID,callID}}`; rule `{permission, pattern, action}`; reply `POST /permission/{id}/reply {reply, message?}` | request `{action, resources, save?, metadata?, source?{type:"tool",messageID,id}, message?}`; rule `{action, resource, effect}`; reply `POST /api/session/{sid}/permission/{rid}/reply {decision, message?}` |
| 13 | Questions | `question.asked/replied/rejected`, `/question/*`, answers `string[][]` | Forms: `form.created/replied/cancelled`, `/api/session/{id}/form/*`, answer `Record<"q0"…, string\|string[]>` |
| 14 | Todos | `todo.updated`, `GET /session/{id}/todo` | **removed** |
| 15 | Share | `POST/DELETE /session/{id}/share`, `Session.share.url` | **removed** |
| 16 | Session list | `Session[]` | `{data, cursor:{previous,next}}`; roots via `parentID=null`; children via `parentID=<id>` |
| 17 | Session fields | `title` required, `directory`, `summary`, `share`, `permission`, `time.compacting` | `title?`, `location{directory}`, `subpath`, `permissions`, `fork`, `outcome`, `time.idle/viewed` |
| 18 | Provider auth | `PUT /auth/{providerID}`, `/provider/auth`, `/provider/{id}/oauth/*`, `/mcp/{name}/auth*` | `/api/integration/*` + `/api/credential/*` |
| 19 | Files | `/file`, `/file/content` (JSON), `/file/status`, `/find`, `/find/file`, `/find/symbol` | `/api/fs/list`, `/api/fs/read/*` (raw bytes), `/api/vcs/status`, `/api/fs/find`; **no grep, no symbols** |
| 20 | Install/distribution | npm `opencode-ai`, GitHub Releases, `opencode.ai/install` | npm `@opencode/cli` + `@opencode/cli-<target>`, `opencode.ai/files/bin/<ver>/…`, `opencode.ai/v2/install`, update API; same `~/.opencode/bin/opencode` path |

---

## 1. Server / transport / auth

| Aspect | v1.18.34 | v2.0.21 | Permalinks |
|---|---|---|---|
| Serve flags | `--port` (default 0 → try 4096 then random), `--hostname` (127.0.0.1), `--mdns`, `--mdns-domain`, `--cors` | `--hostname` (127.0.0.1), `--port` (4096, 4097… if busy), `--cors`, `--service`, `--stdio`; no mDNS | V1 `packages/opencode/src/cli/network.ts#L6-L33`, V1 `packages/opencode/src/server/server.ts#L120-L121`; V2 `packages/cli/src/commands/commands.ts#L537-L551`, V2 `packages/server/src/process.ts#L139-L149` |
| Config-file server section | `server.{port,hostname,mdns,cors}` in opencode.json honoured | ignored (`server` is an unsupported top-level key, V2 `packages/core/src/config/normalize.ts#L46`); use `opencode service set …` | |
| Background service | none | `opencode service start\|stop\|status\|get\|set`, port 49374, registration `~/.local/state/opencode/service.json {id,version,url,pid,password}` | V2 `packages/cli/src/services/service-config.ts#L35-L39`, `service-registration.ts#L23-L30` |
| Health/version | `GET /global/health` → `{healthy:true, version}` | `GET /api/info` → `{version, pid, urls, paths:{tmp}}` (auth required; 503 while booting) | V1 `packages/sdk/openapi.json#L275`; V2 `packages/protocol/src/groups/server.ts#L36-L45` |
| Basic auth username | `OPENCODE_SERVER_USERNAME` or `opencode` | always `opencode` | V1 `packages/opencode/src/server/auth.ts#L17-L20`; V2 `packages/server/src/auth.ts#L18-L26` |
| Query-string auth | `?auth_token=base64(user:pass)` | same, plus pairing token as password and same-origin cookie `opencode_session_<port>` | V2 `packages/server/src/middleware/authorization.ts#L11-L39` |
| 401 body | empty (`HttpApiError.UnauthorizedNoContent`, V1 `packages/opencode/src/server/routes/instance/httpapi/middleware/authorization.ts#L19-L24`) | JSON `{_tag:"UnauthorizedError", message}` | V2 `packages/server/src/middleware/authorization.ts#L50-L55` |
| Error body | Effect HttpApi errors (`{name,data}`-style for session errors) | `{_tag, message, …}` tagged errors | V2 `packages/protocol/src/errors.ts` |
| SSE heartbeat | JSON event `server.heartbeat` every 10 s | `: heartbeat` comment every 15 s | V1 `…/handlers/event.ts#L63-L67`; V2 `packages/server/src/handlers/event.ts#L22` |
| SSE scope | per directory (filtered by `location.directory` + workspace), terminated by `server.instance.disposed` | global, never filtered; `location.shutdown` instead | V1 `…/handlers/event.ts#L33-L61`; V2 `packages/server/src/event-feed.ts#L48-L70` |
| OpenAPI | `packages/sdk/openapi.json` (162 paths, `info.version 1.0.0`) | `packages/protocol/openapi.json` (136 ops, `0.0.1`), live `/openapi.json` | |
| Web UI | `opencode web` command | served by `opencode serve` at `/` | V2 `packages/cli/src/services/web-ui.ts` |
| Data dir/DB | `~/.local/share/opencode/opencode.db` | same DB file; v1 history migrated into v2 event store (`GET /api/experimental/migration/v1`) | V2 `packages/core/src/database/v1-migration.bun.ts`, `packages/cli/src/database-path.ts#L4-L13` |

---

## 2. Route-by-route mapping (all v1.18.34 root routes)

"removed" = no v2 HTTP equivalent in v2.0.21. Permalink "v1" points to the path in V1 `packages/sdk/openapi.json`; "v2" to the endpoint definition in V2 `packages/protocol/src/groups/`.

| v1.18.34 route | v2.0.21 route | change notes | permalinks |
|---|---|---|---|
| `PUT /auth/{providerID}` | `POST /api/integration/{integrationID}/connect/key` | API keys now stored as integration credentials; body `{key, answer?, label?}` | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L9) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/integration.ts#L62) |
| `DELETE /auth/{providerID}` | `DELETE /api/credential/{credentialID}` | delete by credential id (list via `GET /api/integration` connections or `GET /api/credential`) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L9) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/credential.ts#L61) |
| `POST /log` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L124)  |
| `POST /experimental/control-plane/move-session` | `POST /api/session/{sessionID}/move` | body `{directory, delivery?}` | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L215) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L378) |
| `GET /global/health` | `GET /api/info` | `{healthy,version}` → `{version,pid,urls,paths}`; requires auth | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L275) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/server.ts#L36) |
| `GET /global/event` | `GET /api/event` | no `{directory,payload}` wrapper; envelope `{id,created,type,data,location?,durable?}` | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L324) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/event.ts#L44) |
| `GET /global/config` | `GET /api/config` | returns ordered documents, not merged config | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L361) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/config.ts#L9) |
| `PATCH /global/config` | `PATCH /api/experimental/config` | only `{shell}` accepted | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L361) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/config.ts#L35) |
| `POST /global/dispose` | `POST /api/location/reload` | reloads all locations | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L449) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/location.ts#L51) |
| `POST /global/upgrade` | **removed** | removed (CLI `opencode upgrade` only) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L487)  |
| `GET /event` | `GET /api/event` | global stream; filter client-side by `data.sessionID` / `location.directory` | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L577) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/event.ts#L44) |
| `GET /config` | `GET /api/config` | documents (`Config.Entry[]`) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L621) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/config.ts#L9) |
| `PATCH /config` | **removed** | removed (no general config write) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L621)  |
| `GET /config/providers` | `GET /api/provider` | + `GET /api/model` (flat models) + `GET /api/model/default` | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L743) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/provider.ts#L10) |
| `GET /experimental/capabilities` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L814)  |
| `GET /experimental/console` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L868)  |
| `GET /experimental/console/orgs` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L932)  |
| `POST /experimental/console/switch` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L1029)  |
| `GET /experimental/tool` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L1093)  |
| `GET /experimental/tool/ids` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L1170)  |
| `GET /experimental/worktree` | `GET /api/worktree` |  | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L1231) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/worktree.ts#L22) |
| `POST /experimental/worktree` | `POST /api/worktree` |  | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L1231) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/worktree.ts#L36) |
| `DELETE /experimental/worktree` | `DELETE /api/worktree` |  | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L1231) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/worktree.ts#L50) |
| `POST /experimental/worktree/reset` | `POST /api/worktree/refresh` | semantics differ (refresh/discover) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L1433) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/worktree.ts#L64) |
| `GET /experimental/session` | `GET /api/session` | global listing with cursors | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L1504) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L181) |
| `POST /experimental/session/{sessionID}/background` | `POST /api/session/{sessionID}/background` |  | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L1626) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L765) |
| `GET /experimental/resource` | `GET /api/mcp/resource` |  | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L1697) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/mcp.ts#L90) |
| `GET /find` | **removed** | removed (no text/content search) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L1755)  |
| `GET /find/file` | `GET /api/fs/find` | `query`, `type?`, `limit?` | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L1881) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/fs.ts#L62) |
| `GET /find/symbol` | **removed** | removed (no LSP symbols) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L1975)  |
| `GET /file` | `GET /api/fs/list` | `path` relative or absolute | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L2041) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/fs.ts#L47) |
| `GET /file/content` | `GET /api/fs/read/*` | raw bytes (v1 returned JSON `{type, content, diff?…}`) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L2107) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/fs.ts#L32) |
| `GET /file/status` | `GET /api/vcs/status` |  | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L2169) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/vcs.ts#L55) |
| `POST /instance/dispose` | `DELETE /api/debug/location` | or `POST /api/location/reload` | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L2227) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/debug.ts#L19) |
| `GET /path` | `GET /api/location` | `{directory, project:{id,directory,canonical}}` (+ `GET /api/info` paths.tmp) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L2282) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/location.ts#L36) |
| `GET /vcs` | `GET /api/vcs` |  | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L2336) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/vcs.ts#L25) |
| `GET /vcs/status` | `GET /api/vcs/status` |  | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L2390) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/vcs.ts#L55) |
| `GET /vcs/diff` | `GET /api/vcs/diff` | structured FileDiff[] | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L2448) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/vcs.ts#L83) |
| `GET /vcs/diff/raw` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L2524)  |
| `POST /vcs/apply` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L2578)  |
| `GET /command` | `GET /api/command` | only `{name, description}` | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L2663) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/command.ts#L9) |
| `GET /agent` | `GET /api/agent` | Agent.Info reshaped | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L2721) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/agent.ts#L10) |
| `GET /skill` | `GET /api/skill` | `location`→`path` | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L2779) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/skill.ts#L9) |
| `GET /lsp` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L2853)  |
| `GET /formatter` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L2911)  |
| `GET /mcp` | `GET /api/mcp` | list of `{name,status,integrationID?}` instead of map | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L2969) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/mcp.ts#L10) |
| `POST /mcp` | `PUT /api/experimental/mcp/{server}` | runtime-only, experimental | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L2969) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/mcp.ts#L24) |
| `POST /mcp/{name}/auth` | `POST /api/integration/{integrationID}/connect/oauth` | MCP OAuth via integrations | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L3116) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/integration.ts#L83) |
| `DELETE /mcp/{name}/auth` | `DELETE /api/credential/{credentialID}` |  | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L3116) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/credential.ts#L61) |
| `POST /mcp/{name}/auth/callback` | `POST /api/integration/{integrationID}/connect/oauth/{attemptID}/complete` |  | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L3285) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/integration.ts#L120) |
| `POST /mcp/{name}/auth/authenticate` | `POST /api/integration/{integrationID}/connect/oauth` |  | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L3380) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/integration.ts#L83) |
| `POST /mcp/{name}/connect` | `POST /api/experimental/mcp/{server}/connect` | experimental | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L3459) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/mcp.ts#L58) |
| `POST /mcp/{name}/disconnect` | `POST /api/experimental/mcp/{server}/disconnect` | experimental | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L3531) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/mcp.ts#L74) |
| `GET /project` | `GET /api/project` |  | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L3603) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/project.ts#L11) |
| `GET /project/current` | `GET /api/location` | use `.project` | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L3661) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/location.ts#L36) |
| `POST /project/git/init` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L3715)  |
| `PATCH /project/{projectID}` | `PATCH /api/project/{projectID}` |  | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L3769) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/project.ts#L22) |
| `GET /project/{projectID}/directories` | **removed** | removed (see worktrees) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L3869)  |
| `POST /experimental/project/{projectID}/copy/generate-name` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L3931)  |
| `GET /pty/shells` | `GET /api/config/shell` |  | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L4015) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/config.ts#L24) |
| `GET /pty` | `GET /api/pty` |  | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L4086) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/pty.ts#L23) |
| `POST /pty` | `POST /api/pty` |  | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L4086) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/pty.ts#L37) |
| `GET /pty/{ptyID}` | `GET /api/pty/{ptyID}` |  | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L4236) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/pty.ts#L52) |
| `PUT /pty/{ptyID}` | `PUT /api/pty/{ptyID}` |  | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L4236) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/pty.ts#L68) |
| `DELETE /pty/{ptyID}` | `DELETE /api/pty/{ptyID}` |  | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L4236) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/pty.ts#L85) |
| `POST /pty/{ptyID}/connect-token` | `POST /api/pty/{ptyID}/connect-token` | requires header `x-opencode-ticket: 1` | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L4489) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/pty.ts#L101) |
| `GET /question` | `GET /api/form` | forms (pending) per location; or `GET /api/session/{id}/form` | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L4572) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/form.ts#L12) |
| `POST /question/{requestID}/reply` | `POST /api/session/{sessionID}/form/{formID}/reply` | `{answers: string[][]}` → `{answer: {q0: …}}` | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L4630) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L840) |
| `POST /question/{requestID}/reject` | `DELETE /api/session/{sessionID}/form/{formID}` | optional `?message=` | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L4731) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L856) |
| `GET /permission` | `GET /api/permission/request` | or per session `GET /api/session/{sessionID}/permission` | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L4812) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/permission.ts#L23) |
| `POST /permission/{requestID}/reply` | `POST /api/session/{sessionID}/permission/{requestID}/reply` | `{reply,message?}` → `{decision,message?}`; needs sessionID | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L4870) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/permission.ts#L117) |
| `GET /provider` | `GET /api/provider` | providers no longer embed models; use `GET /api/model` | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L4971) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/provider.ts#L10) |
| `GET /provider/auth` | `GET /api/integration` | auth methods per integration | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L5048) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/integration.ts#L16) |
| `POST /provider/{providerID}/oauth/authorize` | `POST /api/integration/{integrationID}/connect/oauth` | returns Attempt {attemptID,url,instructions,mode} | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L5109) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/integration.ts#L83) |
| `POST /provider/{providerID}/oauth/callback` | `POST /api/integration/{integrationID}/connect/oauth/{attemptID}/complete` | `{code?}`; poll status endpoint | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L5201) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/integration.ts#L120) |
| `GET /session` | `GET /api/session` | returns `{data, cursor}`; filters `directory\|project+subpath`, `parentID`, `search`, `order`, `limit`, `cursor` (v1: `roots`, `start`, `path`, `scope`) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L5291) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L181) |
| `POST /session` | `POST /api/session` | `permission`→`permissions`, `location` in body; no `parentID`/`workspaceID` (2.0.22 adds `parentID`) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L5291) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L220) |
| `GET /session/status` | `GET /api/session/active` | only running sessions; retry state via events | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L5513) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L271) |
| `GET /session/{sessionID}` | `GET /api/session/{sessionID}` | Session.Info reshaped; wrapped in `{data}` | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L5578) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L283) |
| `DELETE /session/{sessionID}` | `DELETE /api/session/{sessionID}` | 204 | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L5578) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L296) |
| `PATCH /session/{sessionID}` | `PATCH /api/session/{sessionID}` | `{title?, metadata?, permissions?}`; no `time.archived` | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L5578) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L358) |
| `GET /session/{sessionID}/children` | `GET /api/session` | `?parentID={sessionID}` | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L5845) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L181) |
| `GET /session/{sessionID}/todo` | **removed** | removed (no todo in v2) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L5929)  |
| `GET /session/{sessionID}/diff` | `GET /api/session/{sessionID}/diff` | `?from&to&context` (user message ids) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L6013) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L580) |
| `GET /session/{sessionID}/message` | `GET /api/session/{sessionID}/message` | typed message union + cursors (v1: `{info, parts}[]`, `limit`, `before`) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L6089) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/message.ts#L68) |
| `POST /session/{sessionID}/message` | `POST /api/session/{sessionID}/prompt` | no sync reply; returns inbox item | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L6089) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L392) |
| `GET /session/{sessionID}/message/{messageID}` | `GET /api/session/{sessionID}/message/{messageID}` |  | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L6364) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L781) |
| `DELETE /session/{sessionID}/message/{messageID}` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L6364)  |
| `POST /session/{sessionID}/fork` | `POST /api/session/{sessionID}/fork` | `messageID`→`before`; fork is a new root session with `fork` field | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L6565) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L309) |
| `POST /session/{sessionID}/abort` | `POST /api/session/{sessionID}/interrupt` | returns `{interrupted}`; `?resume=` | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L6661) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L744) |
| `POST /session/{sessionID}/init` | `POST /api/session/{sessionID}/command` | `{name:"init", text:""}` | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L6732) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L414) |
| `POST /session/{sessionID}/share` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L6836)  |
| `DELETE /session/{sessionID}/share` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L6836)  |
| `POST /session/{sessionID}/summarize` | `POST /api/session/{sessionID}/compact` | no providerID/modelID; `{id?, delivery?}` | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L7000) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L496) |
| `POST /session/{sessionID}/prompt_async` | `POST /api/session/{sessionID}/prompt` | body reshaped (text/files/agents/skills/delivery/resume) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L7103) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L392) |
| `POST /session/{sessionID}/command` | `POST /api/session/{sessionID}/command` | `command`→`name`, `arguments`→`text`, `parts`→`files`; no agent/model/variant; 204 | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L7246) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L414) |
| `POST /session/{sessionID}/shell` | `POST /api/session/{sessionID}/shell` | `{id?, command}` only; 204 | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L7400) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L476) |
| `POST /session/{sessionID}/revert` | `POST /api/session/{sessionID}/revert/stage` | `{messageID, files?}`; partID not accepted | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L7540) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L531) |
| `POST /session/{sessionID}/unrevert` | `DELETE /api/session/{sessionID}/revert` |  | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L7651) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L547) |
| `POST /session/{sessionID}/permissions/{permissionID}` | `POST /api/session/{sessionID}/permission/{requestID}/reply` | `{response}`→`{decision}` | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L7741) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/permission.ts#L117) |
| `DELETE /session/{sessionID}/message/{messageID}/part/{partID}` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L7856)  |
| `PATCH /session/{sessionID}/message/{messageID}/part/{partID}` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L7856)  |
| `POST /sync/start` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L8058)  |
| `POST /sync/replay` | **removed** | removed (see durable session log) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L8113)  |
| `POST /sync/steal` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L8226)  |
| `POST /sync/history` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L8313)  |
| `POST /tui/append-prompt` | **removed** | removed (TUI remote control) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L8412)  |
| `POST /tui/open-help` | **removed** | removed (TUI remote control) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L8490)  |
| `POST /tui/open-sessions` | **removed** | removed (TUI remote control) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L8545)  |
| `POST /tui/open-themes` | **removed** | removed (TUI remote control) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L8600)  |
| `POST /tui/open-models` | **removed** | removed (TUI remote control) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L8655)  |
| `POST /tui/submit-prompt` | **removed** | removed (TUI remote control) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L8710)  |
| `POST /tui/clear-prompt` | **removed** | removed (TUI remote control) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L8765)  |
| `POST /tui/execute-command` | **removed** | removed (TUI remote control) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L8820)  |
| `POST /tui/show-toast` | **removed** | removed (TUI remote control) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L8898)  |
| `POST /tui/publish` | **removed** | removed (TUI remote control) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L8980)  |
| `POST /tui/select-session` | **removed** | removed (TUI remote control) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L9064)  |
| `GET /tui/control/next` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L9154)  |
| `POST /tui/control/response` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L9217)  |
| `GET /experimental/workspace/adapter` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L9279)  |
| `GET /experimental/workspace` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L9350)  |
| `POST /experimental/workspace` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L9350)  |
| `POST /experimental/workspace/sync-list` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L9508)  |
| `GET /experimental/workspace/status` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L9555)  |
| `DELETE /experimental/workspace/{id}` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L9613)  |
| `POST /experimental/workspace/warp` | **removed** | removed | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L9683)  |
| `POST /experimental/project/{projectID}/copy` | **removed** | removed (replaced by worktrees `POST /api/worktree`) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L14937)  |
| `DELETE /experimental/project/{projectID}/copy` | **removed** | removed (`DELETE /api/worktree`) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L14937)  |
| `POST /experimental/project/{projectID}/copy/refresh` | **removed** | removed (`POST /api/worktree/refresh`) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L15109)  |
| `GET /pty/{ptyID}/connect` | `GET /api/pty/{ptyID}/connect` | WebSocket; `ticket`/`cursor` query; meta frame 0x00+JSON | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L15172) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/pty.ts#L120) |

### 2.1 v1.18.34 `/api/*` preview routes (only relevant if CodeWalk already used them)

v1.18.34 shipped an early `/api` surface with operationIds prefixed `v2.` (V1 `packages/sdk/openapi.json#L9781-L14900`). Paths mostly survived but schemas were audited and changed (operation prefixes removed, field renames: `session.command.command → name`, `session.permission.reply.reply → decision`, `session.interrupt` `continue → resume`, `skill.location → path`, inbox delivery consolidation — V2 `V2_HTTP_API_AUDIT.md`).

| v1.18.34 `/api` preview route | v2.0.21 | notes | permalinks |
|---|---|---|---|
| `GET /api/health` | `GET /api/info` | renamed+merged | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L9781) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/server.ts#L36) |
| `GET /api/location` | `GET /api/location` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L9837) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/location.ts#L36) |
| `GET /api/agent` | `GET /api/agent` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L9905) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/agent.ts#L10) |
| `GET /api/session` | `GET /api/session` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L9986) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L181) |
| `POST /api/session` | `POST /api/session` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L9986) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L220) |
| `GET /api/session/active` | `GET /api/session/active` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L10191) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L271) |
| `GET /api/session/{sessionID}` | `GET /api/session/{sessionID}` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L10251) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L283) |
| `POST /api/session/{sessionID}/agent` | `POST /api/session/{sessionID}/agent` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L10333) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L326) |
| `POST /api/session/{sessionID}/model` | `POST /api/session/{sessionID}/model` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L10418) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L342) |
| `POST /api/session/{sessionID}/prompt` | `POST /api/session/{sessionID}/prompt` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L10503) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L392) |
| `POST /api/session/{sessionID}/compact` | `POST /api/session/{sessionID}/compact` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L10623) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L496) |
| `POST /api/session/{sessionID}/wait` | `POST /api/experimental/session/{sessionID}/wait` | moved under experimental | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L10701) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L516) |
| `POST /api/session/{sessionID}/revert/stage` | `POST /api/session/{sessionID}/revert/stage` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L10779) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L531) |
| `POST /api/session/{sessionID}/revert/clear` | `DELETE /api/session/{sessionID}/revert` | POST→DELETE | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L10895) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L547) |
| `POST /api/session/{sessionID}/revert/commit` | `POST /api/session/{sessionID}/revert/commit` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L10972) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L556) |
| `GET /api/session/{sessionID}/context` | `GET /api/session/{sessionID}/context` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L11039) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L567) |
| `GET /api/session/{sessionID}/history` | `GET /api/session/{sessionID}/message` | removed; use message list / context | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L11134) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/message.ts#L68) |
| `GET /api/session/{sessionID}/event` | `GET /api/experimental/session/{sessionID}/log` | durable log (experimental) | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L11225) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L724) |
| `POST /api/session/{sessionID}/interrupt` | `POST /api/session/{sessionID}/interrupt` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L11382) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L744) |
| `GET /api/session/{sessionID}/message/{messageID}` | `GET /api/session/{sessionID}/message/{messageID}` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L11450) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L781) |
| `GET /api/session/{sessionID}/message` | `GET /api/session/{sessionID}/message` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L11544) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/message.ts#L68) |
| `GET /api/model` | `GET /api/model` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L11662) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/model.ts#L10) |
| `GET /api/provider` | `GET /api/provider` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L11753) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/provider.ts#L10) |
| `GET /api/provider/{providerID}` | `GET /api/provider/{providerID}` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L11844) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/provider.ts#L25) |
| `GET /api/integration` | `GET /api/integration` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L11950) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/integration.ts#L16) |
| `GET /api/integration/{integrationID}` | `GET /api/integration/{integrationID}` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L12031) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/integration.ts#L30) |
| `POST /api/integration/{integrationID}/connect/key` | `POST /api/integration/{integrationID}/connect/key` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L12117) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/integration.ts#L62) |
| `POST /api/integration/{integrationID}/connect/oauth` | `POST /api/integration/{integrationID}/connect/oauth` |  | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L12213) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/integration.ts#L83) |
| `GET /api/integration/attempt/{attemptID}` | `GET /api/integration/{integrationID}/connect/oauth/{attemptID}` | path reshaped | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L12332) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/integration.ts#L104) |
| `DELETE /api/integration/attempt/{attemptID}` | `DELETE /api/integration/{integrationID}/connect/oauth/{attemptID}` | path reshaped | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L12332) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/integration.ts#L141) |
| `POST /api/integration/attempt/{attemptID}/complete` | `POST /api/integration/{integrationID}/connect/oauth/{attemptID}/complete` | path reshaped | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L12485) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/integration.ts#L120) |
| `PATCH /api/credential/{credentialID}` | `PATCH /api/credential/{credentialID}` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L12577) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/credential.ts#L33) |
| `DELETE /api/credential/{credentialID}` | `DELETE /api/credential/{credentialID}` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L12577) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/credential.ts#L61) |
| `GET /api/permission/request` | `GET /api/permission/request` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L12730) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/permission.ts#L23) |
| `GET /api/permission/saved` | `GET /api/permission/saved` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L12811) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/permission.ts#L37) |
| `DELETE /api/permission/saved/{id}` | `DELETE /api/permission/saved/{id}` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L12878) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/permission.ts#L49) |
| `POST /api/session/{sessionID}/permission` | `POST /api/session/{sessionID}/permission` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L12928) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/permission.ts#L63) |
| `GET /api/session/{sessionID}/permission` | `GET /api/session/{sessionID}/permission` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L12928) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/permission.ts#L89) |
| `GET /api/session/{sessionID}/permission/{requestID}` | `GET /api/session/{sessionID}/permission/{requestID}` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L13146) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/permission.ts#L102) |
| `POST /api/session/{sessionID}/permission/{requestID}/reply` | `POST /api/session/{sessionID}/permission/{requestID}/reply` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L13240) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/permission.ts#L117) |
| `GET /api/fs/read/*` | `GET /api/fs/read/*` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L13340) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/fs.ts#L32) |
| `GET /api/fs/list` | `GET /api/fs/list` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L13409) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/fs.ts#L47) |
| `GET /api/fs/find` | `GET /api/fs/find` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L13498) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/fs.ts#L62) |
| `GET /api/command` | `GET /api/command` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L13604) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/command.ts#L9) |
| `GET /api/skill` | `GET /api/skill` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L13685) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/skill.ts#L9) |
| `GET /api/event` | `GET /api/event` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L13766) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/event.ts#L44) |
| `GET /api/pty` | `GET /api/pty` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L13814) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/pty.ts#L23) |
| `POST /api/pty` | `POST /api/pty` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L13814) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/pty.ts#L37) |
| `GET /api/pty/{ptyID}` | `GET /api/pty/{ptyID}` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L14005) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/pty.ts#L52) |
| `PUT /api/pty/{ptyID}` | `PUT /api/pty/{ptyID}` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L14005) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/pty.ts#L68) |
| `DELETE /api/pty/{ptyID}` | `DELETE /api/pty/{ptyID}` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L14005) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/pty.ts#L85) |
| `POST /api/pty/{ptyID}/connect-token` | `POST /api/pty/{ptyID}/connect-token` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L14306) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/pty.ts#L101) |
| `GET /api/pty/{ptyID}/connect` | `GET /api/pty/{ptyID}/connect` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L14413) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/pty.ts#L120) |
| `GET /api/question/request` | `GET /api/form` | questions → forms | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L14520) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/form.ts#L12) |
| `GET /api/session/{sessionID}/question` | `GET /api/session/{sessionID}/form` | questions → forms | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L14601) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L794) |
| `POST /api/session/{sessionID}/question/{requestID}/reply` | `POST /api/session/{sessionID}/form/{formID}/reply` | questions → forms | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L14686) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L840) |
| `POST /api/session/{sessionID}/question/{requestID}/reject` | `DELETE /api/session/{sessionID}/form/{formID}` | questions → forms | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L14776) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/session.ts#L856) |
| `GET /api/reference` | `GET /api/reference` | path kept; re-check schema against v2 generated types | [v1](https://github.com/anomalyco/opencode/blob/v1.18.34/packages/sdk/openapi.json#L14856) [v2](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/protocol/src/groups/reference.ts#L24) |

New in v2 with no v1 counterpart: `/api/pair`, `/auth/connect/{code}`, `/api/location/reload`, `/api/plugin*`, `/api/model/default`, `/api/experimental/generate`, `/api/integration/*/connect/command*`, `/api/experimental/integration/wellknown`, `/api/credential` (list/create/activate), `/api/mcp/resource`, `/api/websearch*`, `/api/config/shell`, `/api/session/{id}/synthetic|shell|background|view|environment|generate|move|inbox*|form*`, `/api/experimental/session/{id}/skill|wait|log|export|instructions/*`, `/api/experimental/session/import|stats`, `/api/experimental/fs/write`, `/api/shell*`, `/api/experimental/persistent-pty*`, `/api/experimental/session/{id}/terminal*`, `/api/vcs/base|branch`, `/api/worktree/refresh`, `/api/debug/location`, `/api/experimental/migration/v1`, `/api/rpc/{rpcID}/{method}`.

---

## 3. Event mapping

| v1.18.34 event (`type` → `properties`) | v2.0.21 replacement (`type` → `data`) |
|---|---|
| `server.connected {}` | `server.connected {}` (first frame) |
| `server.heartbeat {}` | SSE comment `: heartbeat` (no event) |
| `server.instance.disposed {directory}` / `global.disposed` | `location.shutdown {}` (with `location`) / not on the stream |
| `session.created {sessionID, info: Session}` | `session.created {sessionID, projectID, location, subpath?, parentID?, slug, title?, agent?, model?, metadata?, permissions?, version}` (durable) — not a Session.Info; refetch `GET /api/session/{id}` if needed |
| `session.updated {sessionID, info}` | split into `session.renamed`, `session.metadata.updated`, `session.permissions`, `session.agent.selected`, `session.model.selected`, `session.moved`, `session.usage.updated`, `session.viewed`, `session.revert.staged\|cleared\|committed` |
| `session.deleted {sessionID, info}` | `session.deleted {sessionID}` |
| `session.status {sessionID, status: busy\|retry\|idle}` / `session.idle` | `session.execution.started` / `.succeeded` / `.failed {error}` / `.interrupted {reason}` + `session.retry.scheduled {assistantMessageID, attempt, at, error}` (`session.status`/`session.idle` still in the union but **not published**) |
| `session.error {sessionID?, error}` | `session.execution.failed {error}` and/or `session.step.failed {assistantMessageID, error}` |
| `session.compacted {sessionID}` | `session.compaction.ended {…}` (+ `started`, `delta`, `failed`) |
| `session.diff {sessionID, diff}` | none — use `session.step.ended.files` + `GET /api/session/{id}/diff` |
| `message.updated {sessionID, info: Message}` | user: `session.inbox.enqueued` + `session.inbox.delivered`; assistant: `session.step.started` / `.streamed` / `.ended` / `.failed`; others: `session.synthetic`, `session.shell.*`, `session.skill.activated`, `session.instructions.updated`, `session.agent\|model.selected`, `session.moved` |
| `message.removed {sessionID, messageID}` | `session.revert.committed {to}` (drop ids ≥ to) / `session.inbox.cancelled` |
| `message.part.updated {sessionID, part, time}` | `session.text.started\|ended`, `session.reasoning.started\|ended`, `session.tool.input.started\|ended`, `session.tool.called\|success\|failed`, `session.retry.scheduled`, `session.compaction.*` |
| `message.part.delta {sessionID, messageID, partID, field, delta}` | `session.text.delta {assistantMessageID, ordinal, delta}`, `session.reasoning.delta`, `session.tool.input.delta {id, delta}`, `session.compaction.delta {text}` |
| `message.part.removed` | none |
| `permission.asked {id, sessionID, permission, patterns, metadata, always, tool?}` | `permission.asked {id, sessionID, action, resources, save?, metadata?, source?, message?}` |
| `permission.replied {sessionID, requestID, reply}` | same name/shape |
| `permission.v2.asked\|replied` (preview) | `permission.asked\|replied` |
| `question.asked {id, sessionID, questions, tool?}`, `question.replied {answers}`, `question.rejected` (+ `question.v2.*`) | `form.created {form}`, `form.replied {id, sessionID, answer}`, `form.cancelled {id, sessionID}` |
| `todo.updated {sessionID, todos}` | **none** |
| `file.edited {file}` | none (use tool metadata `files`, `step.ended.files`) |
| `file.watcher.updated {file, event}` | `filesystem.changed {file, event}` |
| `lsp.updated` | not on the stream |
| `mcp.tools.changed {server}` / `mcp.browser.open.failed` | `mcp.status.changed {server}`, `mcp.resources.changed {server}` / none |
| `command.executed {name, sessionID, arguments, messageID}` | none |
| `project.updated {id, worktree, …}` | `project.updated {id, canonical, vcs?, name?, icon?, commands?, time, sandboxes}` (`worktree` → `canonical`) |
| `project.directories.updated {projectID}`, `worktree.ready\|failed`, `workspace.ready\|failed\|status` | `worktree.updated {projectID}`, `worktree.resolved {…}` (durable) |
| `vcs.branch.updated {branch?}` | same |
| `installation.updated\|update-available {version}` | same |
| `pty.created\|updated\|exited\|deleted` | same (+ `persistent-pty.added\|removed`) |
| `tui.prompt.append\|command.execute\|toast.show\|session.select` | still in the union, **no publisher** |
| `integration.updated`, `integration.connection.updated`, `catalog.updated`, `models-dev.refreshed`, `plugin.added`, `reference.updated` | `integration.updated`, `credential.updated\|switched`, `provider.updated`, `model.updated`, `agent.updated`, `command.updated`, `skill.updated`, `config.updated`, `models-dev.refreshed`, `plugin.updated`, `reference.updated`, `websearch.updated` |
| `session.next.*` (v1 preview of the v2 session events) | `session.*` with renames: `textID`/`reasoningID` → `ordinal`, `callID` → `id`, `timestamp` → envelope `created`, `tool.called.tool` → `tool.input.started.name`, `provider.executed` → `executed`, `structured` → `metadata`, `next.retried` → `retry.scheduled`, `next.prompted\|prompt.admitted` → `inbox.enqueued\|delivered`, `context.updated` → `instructions.updated` |
| — | new: `session.execution.*`, `session.inbox.*`, `session.step.streamed`, `session.tool.progress`, `session.usage.updated`, `session.viewed`, `session.forked`, `session.permissions`, `session.metadata.updated`, `session.skill.activated`, `session.shell.*`, `shell.*`, `form.*`, `credential.*`, `location.shutdown`, `rpc.*` |

v1 event types: V1 `packages/sdk/js/src/v2/gen/types.gen.ts#L730` (`GlobalEvent`) and `Event*` types (e.g. `EventMessagePartDelta` #L6658, `EventTodoUpdated` #L6845); v2: V2 `packages/client/src/promise/generated/types.ts#L2413-L2508`.

---

## 4. Schema changes

### 4.1 Session

| Field | v1 `Session` (V1 `packages/sdk/js/src/v2/gen/types.gen.ts#L170-L236`) | v2 `Session.Info` (V2 `packages/schema/src/session.ts#L31-L56`) |
|---|---|---|
| id / parent | `id`, `parentID?` | `id` (`ses_`, descending), `parentID?`, **new** `fork?: {sessionID, boundary:{type:"before"\|"through", messageID}}` (forks are roots) |
| identity | `slug`, `projectID`, `workspaceID?`, `version` | `projectID` only (slug/version only in `session.created` event) |
| location | `directory`, `path?` | `location: {directory}`, `subpath?` |
| title | `title: string` (required) | `title?: string` |
| agent/model | `agent?`, `model?: {id, providerID, variant?}` | same shape |
| usage | `cost?`, `tokens?` | `cost` and `tokens` required |
| summary | `summary?: {additions, deletions, files, diffs?}` | **removed** (use `/diff`) |
| share | `share?: {url}` | **removed** |
| time | `{created, updated, compacting?, archived?}` | `{created, updated, idle?, viewed?, archived?}` |
| status | — | **new** `outcome?: "succeeded"\|"failed"\|"interrupted"` |
| permissions | `permission?: PermissionRule[]` (`{permission, pattern, action}`) | `permissions?: Permission.Rule[]` (`{action, resource, effect}`) |
| revert | `{messageID, partID?, snapshot?, diff?: string}` | `{messageID, partID?, snapshot?, files?: FileDiff[]}` |
| metadata | `metadata?` | `metadata?` |

### 4.2 Messages and parts

| v1 (V1 `types.gen.ts#L239-L560`) | v2 (file 12 §3) |
|---|---|
| `UserMessage {role:"user", agent, model:{providerID, modelID, variant?}, system?, tools?, format?, summary?}` + parts | `user {id, text, files?, agents?, skills?, metadata?, time.created}` (agent/model are not on user messages; switches are separate `agent-switched`/`model-switched` rows) |
| `AssistantMessage {role:"assistant", parentID, modelID, providerID, mode, agent, path{cwd,root}, summary?, cost, tokens{total?,…}, structured?, variant?, finish?, error?, time{created, completed?}}` | `assistant {id, agent, model{id, providerID, variant?}, content[], snapshot?{start,end,files}, finish?, rawFinish?, providerState?, cost?, tokens?, error?, retry?, time{created, streamed?, completed?}}` |
| `TextPart {id, text, synthetic?, ignored?, time{start,end?}, metadata?}` | `{type:"text", text, state?}` inside `assistant.content` (no id/time); user text is `user.text`; synthetic text is a `synthetic` message |
| `ReasoningPart {text, metadata?, time{start,end?}}` | `{type:"reasoning", text, state?, time?{created, completed?}}` |
| `ToolPart {callID, tool, state, metadata?}` | `{type:"tool", id (call id), name, executed?, providerState?, providerResultState?, state, time{created, ran?, completed?}}` |
| `ToolStatePending {input, raw}` | `streaming {input: string}` (raw JSON) |
| `ToolStateRunning {input, title?, metadata?, time{start}}` | `running {input, metadata}` |
| `ToolStateCompleted {input, output: string, title, metadata, time{start,end,compacted?}, attachments?: FilePart[]}` | `completed {input, content: [ToolContent,…] (text \| file{uri,mime,name?}), metadata?}` — **no `output`, no `title`, no `attachments`** |
| `ToolStateError {input, error: string, metadata?, time}` | `error {input, error: StructuredError, content?, metadata?}` |
| `FilePart {mime, filename?, url, source?}` (user) | `user.files[]: {data (base64), mime, source:{type:"inline"} \| {type:"uri", uri}, name?, description?, mention?}` |
| `AgentPart {name, source?}` | `user.agents[]: {name, mention?{start,end,text}}` |
| `SubtaskPart {prompt, description, agent, model?, command?}` | removed (subagents are `subagent` tool calls / background children) |
| `StepStartPart` / `StepFinishPart {reason, cost, tokens, snapshot}` | folded into the assistant message (`finish`, `cost`, `tokens`, `snapshot`) — one assistant message per step |
| `SnapshotPart`, `PatchPart {hash, files}` | `assistant.snapshot.{start,end,files}` |
| `RetryPart {attempt, error: APIError, time}` | `assistant.retry {attempt, at, error}` |
| `CompactionPart {auto, overflow?, tail_start_id?}` | `compaction` message `{status: running\|completed\|failed, reason: auto\|manual, summary, recent, …}` |
| — | new rows: `synthetic`, `system`, `skill`, `shell`, `idle`, `agent-switched`, `model-switched`, `location-switched` |

### 4.3 Errors

| v1 (`{name, data}`, V1 `types.gen.ts#L317-L376`) | v2 `{type, message, status?, response?}` |
|---|---|
| `ProviderAuthError {providerID, message}` | `provider.auth` |
| `APIError {message, statusCode?, isRetryable, responseHeaders?, responseBody?, metadata?}` | `provider.rate-limit` / `provider.quota` / `provider.internal` / `provider.transport` / `provider.timeout` / `provider.invalid-request` / … with `status` + `response.body` (no response headers) |
| `ContextOverflowError` | none — auto-compaction (inferred: never surfaced) |
| `MessageOutputLengthError` | `finish: "length"` |
| `MessageAbortedError` | `aborted` |
| `StructuredOutputError` | none (no `format`/structured output in v2 prompt) |
| `ContentFilterError` | `provider.content-filter` (+ `finish:"content-filter"`) |
| `UnknownError {message, ref?}` | `unknown` |
| — | `permission.rejected`, `tool.*`, `compaction.*` |

### 4.4 Session status

v1 `SessionStatus = {type:"idle"} | {type:"retry", attempt, message, action?{reason, provider, title, message, label, link?}, next} | {type:"busy"}` (V1 `types.gen.ts#L673-L693`) with Go/Zen upsell `action` produced in V1 `packages/opencode/src/session/retry.ts#L85-L150`. v2: identical type still declared (V2 `packages/schema/src/session-status-event.ts#L9-L34`) but **unpublished**; use execution/retry events (file 12 §5). The upsell `action` has no v2 producer; parse `error.response.body` (file 11 §D).

### 4.5 Models / providers / agents / commands / skills

| | v1 | v2 |
|---|---|---|
| Provider listing | `GET /provider` → `{all: Provider[] (with models map), default, connected}`; `Provider {id, name, source, env, key?, options, models}` (V1 `types.gen.ts#L2118`) | `GET /api/provider` → `Provider.Info {id, canonical?, integrationID?, name, activation: auto\|enabled\|disabled, package, settings?, headers?, body?}`; models separate |
| Model | `{id, providerID, api{id,url,npm}, name, family?, capabilities{temperature, reasoning, attachment, toolcall, input{text,audio,image,video,pdf}, output{…}, interleaved}, cost{input, output, cache{read,write}, tiers?, experimentalOver200K?}, limit{context, input?, output}, status, options, headers, release_date, variants?: Record<string, options>}` (V1 `types.gen.ts#L2035-L2117`) | `Model.Info {id, modelID, providerID, canonical?, family?, name, compatibility?, package?, settings?, headers?, body?, capabilities{tools, input[], output[]}, variants: [{id, settings?, headers?, body?}], time{released}, cost: [{tier?, input, output, cache{read,write}}], status, enabled, limit{context, input?, output}}` |
| Default model | `GET /provider` `default` map | `GET /api/model/default` |
| Agent | `{name, description?, mode, native?, hidden?, topP?, temperature?, color?, permission: Rule[], model?{modelID, providerID}, variant?, prompt?, options, steps?}` (V1 `types.gen.ts#L2353`) | `Agent.Info {id, name, model?{id, providerID, variant?}, request{settings, headers, body}, system?, description?, mode, hidden, color?, steps?, permissions}`; built-ins build/plan/general/explore |
| Command | `{name, description?, agent?, model?, source?: command\|mcp\|skill, template, subtask?, hints[]}` (V1 `types.gen.ts#L2342`) | `{name, description?}`; MCP prompts named `server:prompt`; built-ins `init`, `review` |
| Skill | `{name, description?, location, content}` (V1 `types.gen.ts#L8364-L8374`) | `{id, name, description?, autoinvoke?, path, content}` |

---

## 5. Permission model changes

| Aspect | v1.18.34 | v2.0.21 |
|---|---|---|
| Request | `PermissionRequest {id, sessionID, permission, patterns[], metadata, always[], tool?{messageID, callID}}` (V1 `types.gen.ts#L2471-L2490`) | `Permission.Request {id ("per_…"), sessionID, action, resources[], save?[], metadata?, source?{type:"tool", messageID, id}, message?}` (V2 `packages/schema/src/permission.ts#L16-L39`) |
| Rule | `{permission, pattern, action: allow\|deny\|ask}` (V1 `types.gen.ts#L162-L168`) | `{action, resource, effect: allow\|deny\|ask}` (V2 `packages/schema/src/permission.ts#L55-L66`) |
| Config | `permission: "allow" \| {edit: "ask", bash: {"git *": "allow"}, …}`, `tools: {name: bool}` | `permissions: Rule[]` (top level and per agent); v1 config auto-migrated (`bash→shell`, `task→subagent`, `write\|patch→edit`, V2 `packages/core/src/v1/config/migrate.ts#L116-L122`) |
| Action names | `edit`, `bash`, `webfetch`, `task`, `external_directory`, `doom_loop`, `read`, … (inferred list) | `edit`, `shell`, `webfetch`, `websearch`, `subagent`, `external_directory`, `read`, `glob`, `grep`, `question`, `skill`, `<mcp>_<tool>` (file 12 §7.3) |
| Reply route | `POST /permission/{requestID}/reply {reply, message?}` (V1 `packages/sdk/openapi.json#L4870`) or legacy `POST /session/{id}/permissions/{pid} {response}` | `POST /api/session/{sessionID}/permission/{requestID}/reply {decision, message?}` |
| Listing | `GET /permission` | `GET /api/permission/request` (location) / `GET /api/session/{id}/permission` |
| "always" | stores `always` patterns (scope inferred) | stores `save` patterns as `PermissionSaved` rows per **project**; list/remove via `/api/permission/saved` |
| Session override | `PATCH /session/{id} {permission}` | `PATCH /api/session/{id} {permissions}` (evaluated after agent rules; last match wins; inherited by subagent children) |
| Reject cascade | (inferred similar) | reject → all other pending requests of the session rejected; without message the step ends, with message the model continues |

---

## 6. Prompt / execution semantics

| | v1 | v2 |
|---|---|---|
| Sync prompt | `POST /session/{id}/message` blocks until the assistant finishes and returns `{info, parts}` | none; `POST …/prompt` returns `{data: Session.Inbox.User}` immediately; block with `POST /api/experimental/session/{id}/wait` |
| Busy session | second prompt queued (inferred) | `delivery:"steer"` (default) injects at next step boundary; `"queue"` waits for turn end; manage via `/inbox` |
| No-reply | `noReply: true` | `resume: false` |
| Per-prompt agent/model/variant/system/tools/format | yes | no — `POST /agent`, `POST /model` (with `variant`) beforehand; system prompts via agents/instructions entries; structured output removed |
| Attachments | `FilePartInput {mime, filename?, url (file:// or data:), source?}` | `{uri: file://…[?start=&end=] \| data:…, name?, description?, mention?}`; mime sniffed; 20 MiB max |
| Subtasks from prompt | `SubtaskPartInput` | removed; use `@agent` mention (`agents[]`) or commands with `subagent:true` |
| Abort | `POST /session/{id}/abort` → boolean | `POST /api/session/{id}/interrupt[?resume=true]` → `{interrupted}` |
| Shell `!cmd` | `POST /session/{id}/shell {agent, model?, command}` → message | `POST /api/session/{id}/shell {id?, command}` → 204 + events |
| Slash command | `POST /session/{id}/command {command, arguments, agent?, model?, variant?, parts?}` → message | `POST /api/session/{id}/command {name, text, files?, agents?, skills?, delivery?}` → 204 |
| Compaction | `POST /session/{id}/summarize {providerID, modelID, auto?}` | `POST /api/session/{id}/compact {id?, delivery?}` |
| Revert | `POST /revert {messageID, partID?}`, `POST /unrevert` | `POST /revert/stage {messageID, files?}`, `DELETE /revert`, `POST /revert/commit`; staged revert auto-commits on next prompt |
| Restart continuity | none (inferred) | managed service resumes orphaned turns after restart (≤10 attempts) |

---

## 7. Subagents

| | v1 `task` tool | v2 `subagent` tool |
|---|---|---|
| Input | `{description, prompt, subagent_type, task_id?, command?, background?}` (V1 `packages/opencode/src/tool/task.ts#L43-L62`) | `{agent, description, prompt, model?, sessionID?, background?}` (V2 `packages/core/src/tool/plugin/subagent.ts#L29-L48`) |
| Tool metadata | `{parentSessionId, sessionId, model, background?}` (V1 `task.ts#L185-L195`) | progress `{sessionID, status:"running"}` (ephemeral), result `{sessionID, status: "running"\|"completed"}` |
| Result text | `<task id=… state=…>` / `task_result` / `task_error` | `<subagent sessionID=… state="completed">…</subagent>` |
| Completion of background | notification (v1 BackgroundJob) | synthetic message to parent with `metadata {source:"subagent", childID, agent, state}`; parent auto-resumes |
| Permission action | `task` (patterns `[subagent_type]`) | `subagent` (resources/save `[agentID]`) |
| Nesting | (inferred unlimited/config) | `experimental.subagent_depth`, default 1 |
| Move to background | `POST /experimental/session/{id}/background` | `POST /api/session/{id}/background` |

---

## 8. Install / distribution

| | v1.18.34 | v2.0.21 / 2.0.22 |
|---|---|---|
| Script URL | `https://opencode.ai/install` (V1 `install#L1-L30`) | `https://opencode.ai/v2/install` (V2 `install#L1-L30`) |
| Version source | GitHub API `releases/latest` (V1 `install#L184-L186`) | `https://opencode.ai/update/api/latest/cli/npm` (V2 `install#L171`) |
| Artifact | `https://github.com/anomalyco/opencode/releases/download/v<ver>/opencode-<target>.{zip\|tar.gz}` | npm tarball `@opencode/cli-<target>@<ver>` (script) or `https://opencode.ai/files/bin/<ver>/opencode-<target>.{tar.gz\|zip}` with sha256 from the update API |
| Targets | linux/darwin/windows × x64/arm64, `-baseline`, `-musl` (same naming) | same 12 targets incl. `windows-arm64` (V2 `packages/cli/script/build.ts#L33-L51`) |
| Install dir | `$HOME/.opencode/bin/opencode` | same path (overwrites v1) + `opencode2` shim |
| npm | `opencode-ai` | `@opencode/cli` (+ `@opencode/cli-node` on non-latest channels) |
| Homebrew | `anomalyco/tap/opencode` (inferred) | `anomalyco/tap/opencode-v2` |
| Upgrade | `opencode upgrade`, HTTP `POST /global/upgrade` | `opencode upgrade [--method curl\|npm\|pnpm\|bun\|yarn\|vp\|brew]`; no HTTP upgrade |
| GitHub Releases | yes (Latest = v1.18.34) | **no release objects for v2 tags** (verified with `gh release list`) |

---

## 9. Migration checklist for CodeWalk (derived)

1. Detect v2 with `GET /api/info` (auth) — reject v1 servers (no `/api/info`; `/global/health` JSON).
2. Replace auth setup with: user `opencode` + password, or **pairing** (`/auth/connect/{code}` → token).
3. Replace every route per §2; send `location[directory]` for location-scoped calls and `location.directory` in `POST /api/session`.
4. Rewrite the SSE layer: single global stream, `data:`-only frames, comment heartbeats, 45 s idle watchdog, resync on `server.connected`, optional durable log replay.
5. Rewrite the message store as the event reducer in file 12 §3.2 (port of V2 `packages/client/src/solid/data.ts`).
6. Replace busy/idle/retry with execution/retry events + `/api/session/active`.
7. Rebuild permission UI on `Permission.Request` (`action`/`resources`), reply with `decision`; implement auto-accept client-side or via session `permissions`.
8. Rebuild question UI on Forms (q0…qN keys).
9. Drop todo, share, LSP/formatter status, symbol/text search, TUI control, log.
10. Subagents: discover via `parentID`, follow child sessions, cancel via child interrupt, background via `/background`.
11. Managed install: switch to `@opencode/cli` / `opencode.ai/files/bin` + update API; launch with `opencode serve --stdio` or the managed service.
