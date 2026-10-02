# API (HTTP API reference)

- Source URL: https://opencode.ai/v2/docs/api/ (redirects to https://opencode.ai/v2/docs/api)
- OpenAPI JSON: https://opencode.ai/v2/openapi.json (raw copy saved next to this file as `openapi.json`)
- Page source: https://github.com/anomalyco/opencode/blob/bb381e8bdd1ff22c7329e07c068ec0099031f382/services/www/src/pages/docs/api/index.astro (renders `services/www/openapi.json` via `OpenApiReference.astro`)
- Fetched: 2026-10-02 (OpenCode V2 docs; latest release at fetch time: 2.0.21)
- Note: this Markdown is a mechanical rendering of the same OpenAPI document the live page renders (operations grouped by first tag, then schemas). Nothing was summarized; deeply nested inline schemas are shown by type label only — see `openapi.json` for full detail.

_OpenCode HTTP API reference and OpenAPI specification._

---

OpenAPI 3.1.0

## HTTP API

Experimental HttpApi surface for selected instance routes.

136 operations · 245 schemas · OpenAPI JSON: https://opencode.ai/v2/openapi.json

## Endpoint index

| Method | Path | operationId | Summary |
| --- | --- | --- | --- |
| GET | `/api/info` | `server.info` | Get server info |
| GET | `/api/location` | `location.get` | Get location |
| POST | `/api/location/reload` | `location.reload` | Reload configuration |
| GET | `/api/agent` | `agent.list` | List agents |
| GET | `/api/agent/{agentID}` | `agent.get` | Get agent |
| GET | `/api/plugin` | `plugin.list` | List plugins |
| POST | `/api/plugin/check` | `plugin.check` | Check plugin updates |
| POST | `/api/plugin/update` | `plugin.update` | Update plugins |
| GET | `/api/session` | `session.list` | List sessions |
| POST | `/api/session` | `session.create` | Create session |
| GET | `/api/experimental/session/stats` | `experimental.session.stats` | Get session statistics |
| POST | `/api/experimental/session/import` | `experimental.session.import` | Import session |
| GET | `/api/experimental/session/{sessionID}/export` | `experimental.session.export` | Export session |
| GET | `/api/session/active` | `session.active` | List active sessions |
| GET | `/api/session/{sessionID}` | `session.get` | Get session |
| PATCH | `/api/session/{sessionID}` | `session.update` | Update session |
| DELETE | `/api/session/{sessionID}` | `session.remove` | Delete session |
| POST | `/api/session/{sessionID}/fork` | `session.fork` | Fork session |
| POST | `/api/session/{sessionID}/agent` | `session.switchAgent` | Switch session agent |
| POST | `/api/session/{sessionID}/model` | `session.switchModel` | Switch session model |
| POST | `/api/session/{sessionID}/move` | `session.move` | Move session |
| POST | `/api/session/{sessionID}/prompt` | `session.prompt` | Send message |
| POST | `/api/session/{sessionID}/command` | `session.command` | Run command |
| POST | `/api/experimental/session/{sessionID}/skill` | `experimental.session.skill` | Activate skill |
| POST | `/api/session/{sessionID}/synthetic` | `session.synthetic` | Add synthetic message |
| POST | `/api/session/{sessionID}/shell` | `session.shell` | Run shell command |
| POST | `/api/session/{sessionID}/compact` | `session.compact` | Compact session |
| POST | `/api/experimental/session/{sessionID}/wait` | `experimental.session.wait` | Wait for session |
| POST | `/api/session/{sessionID}/revert/stage` | `session.revert.stage` | Stage session revert |
| DELETE | `/api/session/{sessionID}/revert` | `session.revert.clear` | Clear staged revert |
| POST | `/api/session/{sessionID}/revert/commit` | `session.revert.commit` | Commit staged revert |
| GET | `/api/session/{sessionID}/context` | `session.context` | Get session context |
| GET | `/api/session/{sessionID}/diff` | `session.diff` | Diff session turns |
| GET | `/api/session/{sessionID}/inbox` | `session.inbox.list` | List session inbox |
| PATCH | `/api/session/{sessionID}/inbox/{inboxID}` | `session.inbox.update` | Update inbox item |
| DELETE | `/api/session/{sessionID}/inbox/{inboxID}` | `session.inbox.cancel` | Cancel inbox input |
| GET | `/api/experimental/session/{sessionID}/instructions/entries` | `experimental.session.instructions.entry.list` | List instruction entries |
| PUT | `/api/experimental/session/{sessionID}/instructions/entries/{key}` | `experimental.session.instructions.entry.put` | Put instruction entry |
| DELETE | `/api/experimental/session/{sessionID}/instructions/entries/{key}` | `experimental.session.instructions.entry.remove` | Remove instruction entry |
| POST | `/api/session/{sessionID}/generate` | `session.generate` | Generate text from session context |
| GET | `/api/experimental/session/{sessionID}/log` | `session.log` | Read the session log |
| POST | `/api/session/{sessionID}/interrupt` | `session.interrupt` | Interrupt session execution |
| POST | `/api/session/{sessionID}/background` | `session.background` | Background blocking session tools |
| GET | `/api/session/{sessionID}/message/{messageID}` | `session.message.get` | Get session message |
| GET | `/api/session/{sessionID}/form` | `session.form.list` | List session forms |
| POST | `/api/session/{sessionID}/form` | `session.form.create` | Create session form |
| GET | `/api/session/{sessionID}/form/{formID}` | `session.form.get` | Get session form |
| DELETE | `/api/session/{sessionID}/form/{formID}` | `session.form.cancel` | Cancel form |
| POST | `/api/session/{sessionID}/form/{formID}/reply` | `session.form.reply` | Reply to form |
| PUT | `/api/session/{sessionID}/environment` | `session.environment` | Set session environment |
| POST | `/api/session/{sessionID}/view` | `session.view` | View session |
| GET | `/api/session/{sessionID}/message` | `session.message.list` | Get session messages |
| GET | `/api/model` | `model.list` | List models |
| GET | `/api/model/default` | `model.default` | Get default model |
| POST | `/api/experimental/generate` | `experimental.generate.text` | Generate text |
| GET | `/api/provider` | `provider.list` | List providers |
| GET | `/api/provider/{providerID}` | `provider.get` | Get provider |
| GET | `/api/integration` | `integration.list` | List integrations |
| GET | `/api/integration/{integrationID}` | `integration.get` | Get integration |
| POST | `/api/experimental/integration/wellknown` | `experimental.integration.wellknown.add` | Add wellknown integration |
| POST | `/api/integration/{integrationID}/connect/key` | `integration.connect.key` | Connect with key |
| POST | `/api/integration/{integrationID}/connect/oauth` | `integration.oauth.connect` | Begin OAuth connection |
| GET | `/api/integration/{integrationID}/connect/oauth/{attemptID}` | `integration.oauth.status` | Get OAuth attempt status |
| DELETE | `/api/integration/{integrationID}/connect/oauth/{attemptID}` | `integration.oauth.cancel` | Cancel OAuth connection |
| POST | `/api/integration/{integrationID}/connect/oauth/{attemptID}/complete` | `integration.oauth.complete` | Complete OAuth connection |
| POST | `/api/integration/{integrationID}/connect/command` | `integration.command.connect` | Begin command connection |
| GET | `/api/integration/{integrationID}/connect/command/{attemptID}` | `integration.command.status` | Get command attempt status |
| DELETE | `/api/integration/{integrationID}/connect/command/{attemptID}` | `integration.command.cancel` | Cancel command connection |
| GET | `/api/mcp` | `mcp.list` | List MCP servers |
| PUT | `/api/experimental/mcp/{server}` | `experimental.mcp.add` | Add MCP server |
| DELETE | `/api/experimental/mcp/{server}` | `experimental.mcp.remove` | Remove MCP server |
| POST | `/api/experimental/mcp/{server}/connect` | `experimental.mcp.connect` | Connect MCP server |
| POST | `/api/experimental/mcp/{server}/disconnect` | `experimental.mcp.disconnect` | Disconnect MCP server |
| GET | `/api/mcp/resource` | `mcp.resource.catalog` | List MCP resources |
| PATCH | `/api/credential/{credentialID}` | `credential.update` | Update credential |
| DELETE | `/api/credential/{credentialID}` | `credential.remove` | Remove credential |
| POST | `/api/credential/{credentialID}/activate` | `credential.activate` | Activate credential |
| GET | `/api/project` | `project.list` | List projects |
| PATCH | `/api/project/{projectID}` | `project.update` | Update project |
| GET | `/api/form` | `form.list` | List pending forms |
| GET | `/api/permission/request` | `permission.request.list` | List pending permission requests |
| GET | `/api/permission/saved` | `permission.saved.list` | List saved permissions |
| DELETE | `/api/permission/saved/{id}` | `permission.saved.remove` | Remove saved permission |
| GET | `/api/session/{sessionID}/permission` | `session.permission.list` | List session permission requests |
| POST | `/api/session/{sessionID}/permission` | `session.permission.create` | Create permission request |
| GET | `/api/session/{sessionID}/permission/{requestID}` | `session.permission.get` | Get permission request |
| POST | `/api/session/{sessionID}/permission/{requestID}/reply` | `session.permission.reply` | Reply to pending permission request |
| GET | `/api/fs/read/*` | `fs.read` | Read file |
| GET | `/api/fs/list` | `fs.list` | List directory |
| GET | `/api/fs/find` | `fs.find` | Find files |
| POST | `/api/experimental/fs/write` | `experimental.fs.write` | Write file |
| GET | `/api/command` | `command.list` | List commands |
| GET | `/api/skill` | `skill.list` | List skills |
| POST | `/api/rpc/{rpcID}/{method}` | `rpc.call` | Call a plugin RPC |
| GET | `/api/event` | `event.subscribe` | Subscribe to events |
| GET | `/api/pty` | `pty.list` | List PTY sessions |
| POST | `/api/pty` | `pty.create` | Create PTY session |
| GET | `/api/pty/{ptyID}` | `pty.get` | Get PTY session |
| PUT | `/api/pty/{ptyID}` | `pty.update` | Update PTY session |
| DELETE | `/api/pty/{ptyID}` | `pty.remove` | Remove PTY session |
| POST | `/api/pty/{ptyID}/connect-token` | `pty.connect.token` | Create PTY WebSocket token |
| GET | `/api/pty/{ptyID}/connect` | `pty.connect` | Connect to PTY session |
| GET | `/api/experimental/session/{sessionID}/terminal/read` | `server.experimental.persistentPty.read` | Read the session's most recently controlled terminal |
| GET | `/api/experimental/session/{sessionID}/terminal` | `server.experimental.persistentPty.list` |  |
| POST | `/api/experimental/session/{sessionID}/terminal` | `server.experimental.persistentPty.create` |  |
| POST | `/api/experimental/persistent-pty/shutdown` | `server.experimental.persistentPty.shutdown` |  |
| POST | `/api/experimental/persistent-pty/handoff` | `server.experimental.persistentPty.handoff` |  |
| GET | `/api/experimental/persistent-pty/{ptyID}` | `server.experimental.persistentPty.get` |  |
| PUT | `/api/experimental/persistent-pty/{ptyID}` | `server.experimental.persistentPty.update` |  |
| DELETE | `/api/experimental/persistent-pty/{ptyID}` | `server.experimental.persistentPty.remove` |  |
| GET | `/api/experimental/persistent-pty/{ptyID}/snapshot` | `server.experimental.persistentPty.snapshot` |  |
| POST | `/api/experimental/persistent-pty/{ptyID}/connect-token` | `server.experimental.persistentPty.connectToken` |  |
| GET | `/api/experimental/persistent-pty/{ptyID}/connect` | `persistentPty.connect` | Connect to a persistent PTY |
| GET | `/api/shell` | `shell.list` | List running shell commands |
| POST | `/api/shell` | `shell.create` | Run shell command |
| GET | `/api/shell/{id}` | `shell.get` | Get shell command |
| DELETE | `/api/shell/{id}` | `shell.remove` | Remove shell command |
| GET | `/api/shell/{id}/output` | `shell.output` | Read shell output |
| GET | `/api/reference` | `reference.list` | List references |
| GET | `/api/worktree` | `worktree.list` | List worktrees |
| POST | `/api/worktree` | `worktree.create` | Create worktree |
| DELETE | `/api/worktree` | `worktree.remove` | Remove worktree |
| POST | `/api/worktree/refresh` | `worktree.refresh` | Refresh worktrees |
| GET | `/api/vcs` | `vcs.get` | VCS info |
| GET | `/api/vcs/base` | `vcs.base` | VCS review base |
| GET | `/api/vcs/status` | `vcs.status` | VCS status |
| GET | `/api/vcs/branch` | `vcs.branch.list` | VCS branches |
| GET | `/api/vcs/diff` | `vcs.diff` | VCS diff |
| GET | `/api/debug/location` | `debug.location.list` | List loaded locations |
| DELETE | `/api/debug/location` | `debug.location.evict` | Evict a loaded location |
| GET | `/api/experimental/migration/v1` | `experimental.migration.v1.status` | Get V1 migration status |
| GET | `/api/websearch/provider` | `websearch.providers` | List web search providers |
| POST | `/api/websearch` | `websearch.query` | Search the web |
| GET | `/api/config` | `config.get` | Get configuration |
| GET | `/api/config/shell` | `config.shells` | List available shells |
| PATCH | `/api/experimental/config` | `experimental.config.update` | Update global configuration |

## Tag: server

### GET `/api/info`

- operationId: `server.info`
- Summary: Get server info

Return the server identity, connection URLs, paths, and readiness status.

Responses:

- `200` ServerInfo — `application/json`: `ServerInfo`
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

## Tag: location

### GET `/api/location`

- operationId: `location.get`
- Summary: Get location

Resolve the requested location or the server default location.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Location.PublicInfo — `application/json`: `Location.PublicInfo`
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### POST `/api/location/reload`

- operationId: `location.reload`
- Summary: Reload configuration

Shut down and rebuild every loaded location. Pending permissions and forms are cancelled; running sessions continue with fresh services at the next step boundary. Emits location.shutdown for client recovery and responds once all replacement builds settle.

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `503` ServiceUnavailableError — `application/json`: `ServiceUnavailableErrorEncoded`

## Tag: agent

### GET `/api/agent`

- operationId: `agent.list`
- Summary: List agents

Retrieve currently registered agents.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Agent.Info`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### GET `/api/agent/{agentID}`

- operationId: `agent.get`
- Summary: Get agent

Retrieve a single currently registered agent.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `agentID` | path | yes | string |  |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Agent.Info` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` AgentNotFoundError — `application/json`: `AgentNotFoundErrorEncoded`

## Tag: plugin

_Experimental plugin routes._

### GET `/api/plugin`

- operationId: `plugin.list`
- Summary: List plugins

Retrieve enabled server plugins and their current status.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Plugin.Info`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### POST `/api/plugin/check`

- operationId: `plugin.check`
- Summary: Check plugin updates

Check one or all package plugins for available updates.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `target` | string \| null | no |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Plugin.Info`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### POST `/api/plugin/update`

- operationId: `plugin.update`
- Summary: Update plugins

Update package plugins concurrently and notify active locations to reload them. Responds once every update has finished; fails when any update fails.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `targets` | string[] | yes |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `503` ServiceUnavailableError — `application/json`: `ServiceUnavailableErrorEncoded`

## Tag: session

_Experimental session routes._

_Experimental message routes._

### GET `/api/session`

- operationId: `session.list`
- Summary: List sessions

Retrieve sessions in the requested order. Items keep that order across pages; use cursor.next or cursor.previous to move through the ordered list.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `limit` | query | no | string \| null | Maximum number of sessions to return. Defaults to the newest 50 sessions. |
| `order` | query | no | "asc" \| "desc" \| null | Session order for the first page. Use desc for newest first or asc for oldest first. |
| `search` | query | no | string \| null |  |
| `parentID` | query | no | string (pattern `^ses`) \| "null" \| null | Filter by parent session. Use null to return only root sessions. |
| `directory` | query | no | string \| null |  |
| `project` | query | no | string \| null |  |
| `subpath` | query | no | string \| null |  |
| `cursor` | query | no | string \| null | Opaque pagination cursor returned as cursor.previous or cursor.next in the previous response. |

Responses:

- `200` SessionsResponse — `application/json`: `SessionsResponse`
- `400` InvalidCursorError | InvalidRequestError — `application/json`: `InvalidCursorErrorEncoded` \| `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### POST `/api/session`

- operationId: `session.create`
- Summary: Create session

Create a session at the requested location.

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^ses`) \| null | no |  |
| `title` | string \| null | no |  |
| `agent` | string \| null | no |  |
| `model` | `Model.Ref` \| null | no |  |
| `location` | `Location.PublicRef` \| null | no |  |
| `metadata` | `Session.Metadata` \| null | no |  |
| `permissions` | `Permission.Ruleset` \| null | no |  |

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `Session.Info` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### GET `/api/experimental/session/stats`

- operationId: `experimental.session.stats`
- Summary: Get session statistics

Aggregate local session activity, usage, and tool reliability for a time range.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `from` | query | no | string \| null |  |
| `to` | query | no | string \| null |  |
| `project` | query | no | string \| null |  |
| `timezone` | query | no | string \| null |  |
| `tools` | query | no | "none" \| "summary" \| "detail" \| null |  |

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `SessionStats.Info` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### POST `/api/experimental/session/import`

- operationId: `experimental.session.import`
- Summary: Import session

Import a projected session transcript at the requested location. If parentID is supplied, the parent session must already exist; import parents before children.

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `info` | `Session.Info` | yes |  |
| `messages` | `Session.Message.Info`[] | yes |  |
| `location` | `Location.PublicRef` \| null | no |  |

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `Session.Info` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`
- `409` ConflictError — `application/json`: `ConflictErrorEncoded`

### GET `/api/experimental/session/{sessionID}/export`

- operationId: `experimental.session.export`
- Summary: Export session

Export a complete projected session transcript.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |
| `sanitize` | query | no | "true" \| "false" \| null |  |

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `SessionTransfer.Data` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`
- `500` UnknownError — `application/json`: `UnknownErrorEncoded`

### GET `/api/session/active`

- operationId: `session.active`
- Summary: List active sessions

Retrieve foreground Session drains currently owned by this OpenCode process. Sessions absent from the result are inactive.

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | object | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### GET `/api/session/{sessionID}`

- operationId: `session.get`
- Summary: Get session

Retrieve a session by ID.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `Session.Info` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`

### PATCH `/api/session/{sessionID}`

- operationId: `session.update`
- Summary: Update session

Update mutable session properties.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `title` | string \| null | no |  |
| `metadata` | `Session.Metadata` \| null | no |  |
| `permissions` | `Permission.Ruleset` \| null | no |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`

### DELETE `/api/session/{sessionID}`

- operationId: `session.remove`
- Summary: Delete session

Delete a session and its child sessions.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`

### POST `/api/session/{sessionID}/fork`

- operationId: `session.fork`
- Summary: Fork session

Create a child session by copying projected history before a message. Omit before to copy the full history.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `before` | string (pattern `^msg_`) \| null | no |  |

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `Session.Info` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError | MessageNotFoundError — `application/json`: `MessageNotFoundErrorEncoded` \| `SessionNotFoundErrorEncoded`

### POST `/api/session/{sessionID}/agent`

- operationId: `session.switchAgent`
- Summary: Switch session agent

Switch the agent used by subsequent provider turns.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `agent` | string | yes |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`

### POST `/api/session/{sessionID}/model`

- operationId: `session.switchModel`
- Summary: Switch session model

Switch the model used by subsequent provider turns.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `model` | `Model.Ref` | yes |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`

### POST `/api/session/{sessionID}/move`

- operationId: `session.move`
- Summary: Move session

Move a session to another project directory at the requested delivery boundary.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `directory` | string | yes |  |
| `delivery` | `Session.Inbox.Delivery` \| null | no |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`

### POST `/api/session/{sessionID}/prompt`

- operationId: `session.prompt`
- Summary: Send message

Durably admit one session input and schedule agent-loop execution unless resume is false.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^msg_`) \| null | no |  |
| `text` | string | yes |  |
| `files` | `PromptInput.FileAttachment`[] | no |  |
| `agents` | `Prompt.AgentAttachment`[] | no |  |
| `skills` | `PromptInput.SkillAttachment`[] | no |  |
| `metadata` | object | no |  |
| `delivery` | `Session.Inbox.Delivery` \| null | no |  |
| `resume` | boolean \| null | no |  |

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `Session.Inbox.User` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`
- `409` ConflictError — `application/json`: `ConflictErrorEncoded`

### POST `/api/session/{sessionID}/command`

- operationId: `session.command`
- Summary: Run command

Execute a slash command callback immediately.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `name` | string | yes |  |
| `text` | string | yes |  |
| `files` | `PromptInput.FileAttachment`[] | no |  |
| `agents` | `Prompt.AgentAttachment`[] | no |  |
| `skills` | `PromptInput.SkillAttachment`[] | no |  |
| `delivery` | `Session.Inbox.Delivery` \| null | no |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError | CommandNotFoundError — `application/json`: `CommandNotFoundErrorEncoded` \| `SessionNotFoundErrorEncoded`
- `500` CommandExecutionError — `application/json`: `CommandExecutionErrorEncoded`

### POST `/api/experimental/session/{sessionID}/skill`

- operationId: `experimental.session.skill`
- Summary: Activate skill

Activate a skill for a session by appending a skill message and resuming execution.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string | yes |  |
| `resume` | boolean \| null | no |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError | SkillNotFoundError — `application/json`: `SkillNotFoundErrorEncoded` \| `SessionNotFoundErrorEncoded`

### POST `/api/session/{sessionID}/synthetic`

- operationId: `session.synthetic`
- Summary: Add synthetic message

Durably admit synthetic session input and schedule execution unless resume is false.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^msg_`) \| null | no |  |
| `text` | string | yes |  |
| `description` | string \| null | no |  |
| `metadata` | object | no |  |
| `delivery` | `Session.Inbox.Delivery` \| null | no |  |
| `resume` | boolean \| null | no |  |

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `Session.Inbox.Synthetic` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`
- `409` ConflictError — `application/json`: `ConflictErrorEncoded`

### POST `/api/session/{sessionID}/shell`

- operationId: `session.shell`
- Summary: Run shell command

Execute one shell command in the session's working directory. Emits a shell.started event before execution and a shell.ended event with the merged output after.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^msg_`) \| null | no |  |
| `command` | string | yes |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`

### POST `/api/session/{sessionID}/compact`

- operationId: `session.compact`
- Summary: Compact session

Durably admit a session compaction request. Steers by default: it runs at the next step boundary instead of waiting behind queued prompts.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^msg_`) \| null | no |  |
| `delivery` | `Session.Inbox.Delivery` \| null | no |  |

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `Session.Inbox.Compaction` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`
- `409` ConflictError — `application/json`: `ConflictErrorEncoded`

### POST `/api/experimental/session/{sessionID}/wait`

- operationId: `experimental.session.wait`
- Summary: Wait for session

Wait for a session agent loop to become idle.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`
- `503` ServiceUnavailableError — `application/json`: `ServiceUnavailableErrorEncoded`

### POST `/api/session/{sessionID}/revert/stage`

- operationId: `session.revert.stage`
- Summary: Stage session revert

Stage or move a reversible session boundary and optionally apply its file changes.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `messageID` | string (pattern `^msg_`) | yes |  |
| `files` | boolean \| null | no |  |

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `Session.Revert` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` MessageNotFoundError | SessionNotFoundError — `application/json`: `MessageNotFoundErrorEncoded` \| `SessionNotFoundErrorEncoded`
- `409` SessionBusyError — `application/json`: `SessionBusyErrorEncoded`
- `500` UnknownError — `application/json`: `UnknownErrorEncoded`

### DELETE `/api/session/{sessionID}/revert`

- operationId: `session.revert.clear`
- Summary: Clear staged revert

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`
- `409` SessionBusyError — `application/json`: `SessionBusyErrorEncoded`
- `500` UnknownError — `application/json`: `UnknownErrorEncoded`

### POST `/api/session/{sessionID}/revert/commit`

- operationId: `session.revert.commit`
- Summary: Commit staged revert

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`
- `409` SessionBusyError — `application/json`: `SessionBusyErrorEncoded`

### GET `/api/session/{sessionID}/context`

- operationId: `session.context`
- Summary: Get session context

Retrieve the active context messages for a session (all messages after the last compaction).

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `Session.Message.Info`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`
- `500` UnknownError — `application/json`: `UnknownErrorEncoded`

### GET `/api/session/{sessionID}/diff`

- operationId: `session.diff`
- Summary: Diff session turns

Structured per-file diffs of the files a turn changed. A turn runs from the first prompt after the session was last idle until its next idle marker, so prompts steered in while it was busy belong to the same turn; `to` extends the range through a later turn. Compares the range's first recorded snapshot with its last; a step still running in the active session compares against the working copy. Ranges that span a location change are rejected. In sessions without any idle marker, a prompt's turn spans until the next user message.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |
| `from` | query | no | string (pattern `^msg_`) \| null | User message whose turn to diff. Defaults to the turn of the newest user message. |
| `to` | query | no | string (pattern `^msg_`) \| null | Later user message whose turn ends the range. Defaults to the turn of `from` alone. |
| `context` | query | no | string \| null | Unchanged lines around each hunk. Omit for full-file patches. |

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `FileDiff.Info`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` MessageNotFoundError | SessionNotFoundError — `application/json`: `MessageNotFoundErrorEncoded` \| `SessionNotFoundErrorEncoded`
- `500` UnknownError — `application/json`: `UnknownErrorEncoded`

### GET `/api/session/{sessionID}/inbox`

- operationId: `session.inbox.list`
- Summary: List session inbox

List durable enqueued session work not yet delivered, ordered by enqueue sequence. Includes user, synthetic, compaction, and move items.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `Session.Inbox.Info`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`

### PATCH `/api/session/{sessionID}/inbox/{inboxID}`

- operationId: `session.inbox.update`
- Summary: Update inbox item

Change a pending inbox item's delivery mode. Steering wakes session execution.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |
| `inboxID` | path | yes | string (pattern `^msg_`) |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `delivery` | `Session.Inbox.Delivery` | yes |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`
- `409` ConflictError — `application/json`: `ConflictErrorEncoded`

### DELETE `/api/session/{sessionID}/inbox/{inboxID}`

- operationId: `session.inbox.cancel`
- Summary: Cancel inbox input

Cancel an inbox item that has not yet been delivered. Unavailable items are a no-op.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |
| `inboxID` | path | yes | string (pattern `^msg_`) |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`

### GET `/api/experimental/session/{sessionID}/instructions/entries`

- operationId: `experimental.session.instructions.entry.list`
- Summary: List instruction entries

List API-managed instruction entries attached to the session.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `InstructionEntry.Info`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`

### PUT `/api/experimental/session/{sessionID}/instructions/entries/{key}`

- operationId: `experimental.session.instructions.entry.put`
- Summary: Put instruction entry

Attach or replace one durable instruction entry. Changes announce as updates at the next step boundary.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |
| `key` | path | yes | `InstructionEntry.Key` |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `value` | object | yes |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`
- `413` InstructionEntryValueTooLargeError — `application/json`: `InstructionEntryValueTooLargeErrorEncoded`

### DELETE `/api/experimental/session/{sessionID}/instructions/entries/{key}`

- operationId: `experimental.session.instructions.entry.remove`
- Summary: Remove instruction entry

Remove one instruction entry; the removal is announced to the model at the next step boundary.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |
| `key` | path | yes | `InstructionEntry.Key` |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`

### POST `/api/session/{sessionID}/generate`

- operationId: `session.generate`
- Summary: Generate text from session context

Generate transient text from the current session context without mutating session history.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `prompt` | string | yes |  |

Responses:

- `200` SessionGenerateResponse — `application/json`: `SessionGenerateResponse`
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`
- `503` ServiceUnavailableError — `application/json`: `ServiceUnavailableErrorEncoded`

### GET `/api/experimental/session/{sessionID}/log`

- operationId: `session.log`
- Summary: Read the session log

Experimental durable session event log. Reads events after an exclusive aggregate sequence and continues with live events when follow=true.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |
| `after` | query | no | string \| null |  |
| `follow` | query | no | "true" \| "false" \| null |  |

Responses:

- `200` Success — `text/event-stream`: object{id, event, data} (stream encoding: sse; failure event: `effect/httpapi/stream/failure`)

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `id` | string \| null | yes |  |
  | `event` | string | yes |  |
  | `data` | `SessionLogItemEncoded` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`

### POST `/api/session/{sessionID}/interrupt`

- operationId: `session.interrupt`
- Summary: Interrupt session execution

Interrupt active execution owned by this OpenCode process. Returns interrupted=true when an active execution was interrupted and false for the idle no-op. When resume=true, execution resumes pending steering input and next-in-line control items (manual compaction, moves) while queued prompts remain parked.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |
| `resume` | query | no | "true" \| "false" \| null |  |

Responses:

- `200` SessionInterruptResponse — `application/json`: `SessionInterruptResponse`
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`

### POST `/api/session/{sessionID}/background`

- operationId: `session.background`
- Summary: Background blocking session tools

Move active foreground backgroundable tools for this session into background observation. Idle requests are a no-op.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`

### GET `/api/session/{sessionID}/message/{messageID}`

- operationId: `session.message.get`
- Summary: Get session message

Retrieve one projected message owned by the Session.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |
| `messageID` | path | yes | string (pattern `^msg_`) |  |

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `Session.Message.Info` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError | MessageNotFoundError — `application/json`: `SessionNotFoundErrorEncoded` \| `MessageNotFoundErrorEncoded`

### GET `/api/session/{sessionID}/form`

- operationId: `session.form.list`
- Summary: List session forms

Retrieve pending forms for a session.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string |  |

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `Form.Info`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`

### POST `/api/session/{sessionID}/form`

- operationId: `session.form.create`
- Summary: Create session form

Create a form for a session.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string |  |

Request body (application/json, required): `Form.CreatePayload`

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `Form.Info` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`
- `409` ConflictError — `application/json`: `ConflictErrorEncoded`

### GET `/api/session/{sessionID}/form/{formID}`

- operationId: `session.form.get`
- Summary: Get session form

Retrieve a form and its current state for a session.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string |  |
| `formID` | path | yes | string (pattern `^frm_`) |  |

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `Form.Detail` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError | FormNotFoundError — `application/json`: `FormNotFoundErrorEncoded` \| `SessionNotFoundErrorEncoded`

### DELETE `/api/session/{sessionID}/form/{formID}`

- operationId: `session.form.cancel`
- Summary: Cancel form

Cancel a pending form, optionally telling the asker why it was not answered.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string |  |
| `formID` | path | yes | string (pattern `^frm_`) |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError | FormNotFoundError — `application/json`: `FormNotFoundErrorEncoded` \| `SessionNotFoundErrorEncoded`
- `409` FormAlreadySettledError — `application/json`: `FormAlreadySettledErrorEncoded`

### POST `/api/session/{sessionID}/form/{formID}/reply`

- operationId: `session.form.reply`
- Summary: Reply to form

Submit an answer to a pending form.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string |  |
| `formID` | path | yes | string (pattern `^frm_`) |  |
| `message` | query | no | string \| null |  |

Request body (application/json, required): `Form.Reply`

Responses:

- `204` <No Content>
- `400` FormInvalidAnswerError | InvalidRequestError — `application/json`: `FormInvalidAnswerErrorEncoded` \| `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError | FormNotFoundError — `application/json`: `FormNotFoundErrorEncoded` \| `SessionNotFoundErrorEncoded`
- `409` FormAlreadySettledError — `application/json`: `FormAlreadySettledErrorEncoded`

### PUT `/api/session/{sessionID}/environment`

- operationId: `session.environment`
- Summary: Set session environment

Replace the process environment used by local shell commands for this session.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `variables` | Record<string, string> | yes |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`

### POST `/api/session/{sessionID}/view`

- operationId: `session.view`
- Summary: View session

Mark the idle transition observed by the viewer as viewed.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `idle` | number | yes |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`

### GET `/api/session/{sessionID}/message`

- operationId: `session.message.list`
- Summary: Get session messages

Retrieve projected messages for a session, optionally filtered by type. Items keep the requested order across pages; use cursor.next or cursor.previous to move through the ordered timeline, passing the same type filter on each page.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |
| `limit` | query | no | string \| null | Maximum number of messages to return. When omitted, the endpoint returns its default page size. |
| `order` | query | no | "asc" \| "desc" \| null | Message order for the first page. Use desc for newest first or asc for oldest first. |
| `cursor` | query | no | string \| null | Opaque pagination cursor returned as cursor.previous or cursor.next in the previous response. Do not combine with order. |
| `type` | query | no | "agent-switched" \| "model-switched" \| "location-switched" \| "user" \| "synthetic" \| "system" \| "skill" \| "shell" \| "assistant" \| "compaction" \| null | Filter by message type before pagination. When omitted, all message types are returned. Pass the same type when following cursors. |

Responses:

- `200` SessionMessagesResponse — `application/json`: `SessionMessagesResponse`
- `400` InvalidCursorError | InvalidRequestError — `application/json`: `InvalidCursorErrorEncoded` \| `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`
- `500` UnknownError — `application/json`: `UnknownErrorEncoded`

## Tag: model

_Experimental model routes._

### GET `/api/model`

- operationId: `model.list`
- Summary: List models

Retrieve the current snapshot of available models ordered by release date. The snapshot may precede initial plugin settlement.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Model.Info`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `503` ServiceUnavailableError — `application/json`: `ServiceUnavailableErrorEncoded`

### GET `/api/model/default`

- operationId: `model.default`
- Summary: Get default model

Retrieve the model used when a session has no explicit model selection.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Model.Info` \| null | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `503` ServiceUnavailableError — `application/json`: `ServiceUnavailableErrorEncoded`

## Tag: generate

_Experimental one-shot generation routes._

### POST `/api/experimental/generate`

- operationId: `experimental.generate.text`
- Summary: Generate text

Run one stateless model generation using the server's base configuration and return the assistant text. Uses the base configuration's default model when none is specified.

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `prompt` | string | yes |  |
| `model` | `Model.Ref` \| null | no |  |

Responses:

- `200` GenerateTextResponse — `application/json`: `GenerateTextResponse`
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `503` ServiceUnavailableError — `application/json`: `ServiceUnavailableErrorEncoded`

## Tag: provider

_Experimental provider routes._

### GET `/api/provider`

- operationId: `provider.list`
- Summary: List providers

Retrieve active AI providers so clients can show provider availability and configuration.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Provider.Info`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `503` ServiceUnavailableError — `application/json`: `ServiceUnavailableErrorEncoded`

### GET `/api/provider/{providerID}`

- operationId: `provider.get`
- Summary: Get provider

Retrieve a single AI provider so clients can inspect its availability and endpoint settings.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `providerID` | path | yes | string |  |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Provider.Info` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` ProviderNotFoundError — `application/json`: `ProviderNotFoundErrorEncoded`
- `503` ServiceUnavailableError — `application/json`: `ServiceUnavailableErrorEncoded`

## Tag: integration

_Integration discovery and authentication routes._

### GET `/api/integration`

- operationId: `integration.list`
- Summary: List integrations

Retrieve available integrations and their authentication methods.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Integration.Info`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### GET `/api/integration/{integrationID}`

- operationId: `integration.get`
- Summary: Get integration

Retrieve one integration and its authentication methods.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `integrationID` | path | yes | string |  |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Integration.Info` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` IntegrationNotFoundError — `application/json`: `IntegrationNotFoundErrorEncoded`

### POST `/api/experimental/integration/wellknown`

- operationId: `experimental.integration.wellknown.add`
- Summary: Add wellknown integration

Discover and persist an experimental wellknown integration source.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `url` | string | yes |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### POST `/api/integration/{integrationID}/connect/key`

- operationId: `integration.connect.key`
- Summary: Connect with key

Run a key authentication method and store the resulting credential.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `integrationID` | path | yes | string |  |
| `location` | query | no | object{directory} \| null |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `key` | string | yes |  |
| `answer` | `Form.Answer` \| null | no |  |
| `label` | string \| null | no |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` IntegrationNotFoundError — `application/json`: `IntegrationNotFoundErrorEncoded`

### POST `/api/integration/{integrationID}/connect/oauth`

- operationId: `integration.oauth.connect`
- Summary: Begin OAuth connection

Start an OAuth attempt and return the authorization details.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `integrationID` | path | yes | string |  |
| `location` | query | no | object{directory} \| null |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `methodID` | string | yes |  |
| `answer` | `Form.Answer` \| null | no |  |
| `label` | string \| null | no |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Integration.AttemptEncoded` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### GET `/api/integration/{integrationID}/connect/oauth/{attemptID}`

- operationId: `integration.oauth.status`
- Summary: Get OAuth attempt status

Poll the current status of an OAuth attempt.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `integrationID` | path | yes | string |  |
| `attemptID` | path | yes | string |  |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Integration.AttemptStatus` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` IntegrationNotFoundError | IntegrationAttemptNotFoundError — `application/json`: `IntegrationNotFoundErrorEncoded` \| `IntegrationAttemptNotFoundErrorEncoded`

### DELETE `/api/integration/{integrationID}/connect/oauth/{attemptID}`

- operationId: `integration.oauth.cancel`
- Summary: Cancel OAuth connection

Cancel an OAuth attempt and release its resources.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `integrationID` | path | yes | string |  |
| `attemptID` | path | yes | string |  |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### POST `/api/integration/{integrationID}/connect/oauth/{attemptID}/complete`

- operationId: `integration.oauth.complete`
- Summary: Complete OAuth connection

Complete a code-based OAuth attempt and store the resulting credential.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `integrationID` | path | yes | string |  |
| `attemptID` | path | yes | string |  |
| `location` | query | no | object{directory} \| null |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `code` | string \| null | no |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` IntegrationNotFoundError | IntegrationAttemptNotFoundError — `application/json`: `IntegrationNotFoundErrorEncoded` \| `IntegrationAttemptNotFoundErrorEncoded`

### POST `/api/integration/{integrationID}/connect/command`

- operationId: `integration.command.connect`
- Summary: Begin command connection

Start a command authentication attempt.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `integrationID` | path | yes | string |  |
| `location` | query | no | object{directory} \| null |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `methodID` | string | yes |  |
| `label` | string \| null | no |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Integration.CommandAttempt` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` IntegrationNotFoundError | IntegrationMethodNotFoundError — `application/json`: `IntegrationNotFoundErrorEncoded` \| `IntegrationMethodNotFoundErrorEncoded`

### GET `/api/integration/{integrationID}/connect/command/{attemptID}`

- operationId: `integration.command.status`
- Summary: Get command attempt status

Poll the current status and output of a command authentication attempt.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `integrationID` | path | yes | string |  |
| `attemptID` | path | yes | string |  |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Integration.CommandAttemptStatus` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` IntegrationNotFoundError | IntegrationAttemptNotFoundError — `application/json`: `IntegrationNotFoundErrorEncoded` \| `IntegrationAttemptNotFoundErrorEncoded`

### DELETE `/api/integration/{integrationID}/connect/command/{attemptID}`

- operationId: `integration.command.cancel`
- Summary: Cancel command connection

Cancel a command authentication attempt and terminate its process.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `integrationID` | path | yes | string |  |
| `attemptID` | path | yes | string |  |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

## Tag: mcp

_MCP server and resource routes._

### GET `/api/mcp`

- operationId: `mcp.list`
- Summary: List MCP servers

Retrieve configured MCP servers and their connection status.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Mcp.Server`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### PUT `/api/experimental/mcp/{server}`

- operationId: `experimental.mcp.add`
- Summary: Add MCP server

Add an MCP server at runtime or replace an existing one, connecting it immediately.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `server` | path | yes | string |  |
| `location` | query | no | object{directory} \| null |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `config` | `Mcp.LocalConfigEncoded` \| `Mcp.RemoteConfigEncoded` | yes |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### DELETE `/api/experimental/mcp/{server}`

- operationId: `experimental.mcp.remove`
- Summary: Remove MCP server

Stop an MCP server and remove it from the runtime set until restart.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `server` | path | yes | string |  |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` McpServerNotFoundError — `application/json`: `McpServerNotFoundErrorEncoded`

### POST `/api/experimental/mcp/{server}/connect`

- operationId: `experimental.mcp.connect`
- Summary: Connect MCP server

Connect an MCP server at runtime, overriding a disabled configuration until restart.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `server` | path | yes | string |  |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` McpServerNotFoundError — `application/json`: `McpServerNotFoundErrorEncoded`

### POST `/api/experimental/mcp/{server}/disconnect`

- operationId: `experimental.mcp.disconnect`
- Summary: Disconnect MCP server

Disconnect an MCP server at runtime, removing its tools until reconnected.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `server` | path | yes | string |  |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` McpServerNotFoundError — `application/json`: `McpServerNotFoundErrorEncoded`

### GET `/api/mcp/resource`

- operationId: `mcp.resource.catalog`
- Summary: List MCP resources

Retrieve resources and resource templates from connected MCP servers.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Mcp.ResourceCatalog` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

## Tag: credential

### PATCH `/api/credential/{credentialID}`

- operationId: `credential.update`
- Summary: Update credential

Update a stored credential label.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `credentialID` | path | yes | string |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `label` | string | yes |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### DELETE `/api/credential/{credentialID}`

- operationId: `credential.remove`
- Summary: Remove credential

Remove a stored integration credential.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `credentialID` | path | yes | string |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### POST `/api/credential/{credentialID}/activate`

- operationId: `credential.activate`
- Summary: Activate credential

Activate a stored integration credential.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `credentialID` | path | yes | string |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

## Tag: project

_Project routes._

### GET `/api/project`

- operationId: `project.list`
- Summary: List projects

List known projects.

Responses:

- `200` Success — `application/json`: `Project`[]
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### PATCH `/api/project/{projectID}`

- operationId: `project.update`
- Summary: Update project

Update the project canonical directory, display metadata, and workspace commands.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `projectID` | path | yes | string |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `canonical` | string | no |  |
| `name` | string | no |  |
| `icon` | `Project.Icon` | no |  |
| `commands` | `Project.Commands` | no |  |

Responses:

- `200` Project — `application/json`: `Project`
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` ProjectNotFoundError — `application/json`: `ProjectNotFoundErrorEncoded`

## Tag: form

_Location form routes._

### GET `/api/form`

- operationId: `form.list`
- Summary: List pending forms

Retrieve pending forms for a location.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Form.Info`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

## Tag: permission

_Experimental permission routes._

### GET `/api/permission/request`

- operationId: `permission.request.list`
- Summary: List pending permission requests

Retrieve pending permission requests for a location.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Permission.Request`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### GET `/api/permission/saved`

- operationId: `permission.saved.list`
- Summary: List saved permissions

Retrieve saved permissions, optionally filtered by project.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `projectID` | query | no | string \| null |  |

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `PermissionSaved.Info`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### DELETE `/api/permission/saved/{id}`

- operationId: `permission.saved.remove`
- Summary: Remove saved permission

Remove a saved permission by ID.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `id` | path | yes | string |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### GET `/api/session/{sessionID}/permission`

- operationId: `session.permission.list`
- Summary: List session permission requests

Retrieve pending permission requests owned by a session.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `Permission.Request`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`

### POST `/api/session/{sessionID}/permission`

- operationId: `session.permission.create`
- Summary: Create permission request

Evaluate and, when approval is required, create a permission request for a session.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^per`) \| null | no |  |
| `action` | string | yes |  |
| `resources` | string[] | yes |  |
| `save` | string[] | no |  |
| `metadata` | object | no |  |
| `source` | `Permission.Source` | no |  |
| `agent` | string \| null | no |  |

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | object{id, effect} | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError — `application/json`: `SessionNotFoundErrorEncoded`

### GET `/api/session/{sessionID}/permission/{requestID}`

- operationId: `session.permission.get`
- Summary: Get permission request

Retrieve a pending permission request owned by a session.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |
| `requestID` | path | yes | string (pattern `^per`) |  |

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `Permission.Request` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError | PermissionNotFoundError — `application/json`: `PermissionNotFoundErrorEncoded` \| `SessionNotFoundErrorEncoded`

### POST `/api/session/{sessionID}/permission/{requestID}/reply`

- operationId: `session.permission.reply`
- Summary: Reply to pending permission request

Respond to a pending permission request owned by a session.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |
| `requestID` | path | yes | string (pattern `^per`) |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `decision` | `Permission.Reply` | yes |  |
| `message` | string \| null | no |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` SessionNotFoundError | PermissionNotFoundError — `application/json`: `PermissionNotFoundErrorEncoded` \| `SessionNotFoundErrorEncoded`

## Tag: filesystem

_Experimental location-scoped filesystem routes._

### GET `/api/fs/read/*`

- operationId: `fs.read`
- Summary: Read file

Serve one file relative to the requested location.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/octet-stream`: string<binary>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` FileNotFoundError — `application/json`: `FileNotFoundErrorEncoded`

### GET `/api/fs/list`

- operationId: `fs.list`
- Summary: List directory

List direct children using an absolute path or a path relative to the requested location, including parents and siblings outside its directory. Entry paths remain relative to the requested location; listing does not switch locations.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |
| `path` | query | no | string \| null | An absolute path or a path relative to the requested location. Defaults to the location directory. |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `FileSystem.Entry`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### GET `/api/fs/find`

- operationId: `fs.find`
- Summary: Find files

Find recursively ranked filesystem entries relative to the requested location.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |
| `query` | query | yes | string |  |
| `type` | query | no | "file" \| "directory" |  |
| `limit` | query | no | string \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `FileSystem.Entry`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### POST `/api/experimental/fs/write`

- operationId: `experimental.fs.write`
- Summary: Write file

Write the raw request body to an absolute path or a path relative to the requested location, creating parent directories, and return the resolved absolute path. Unlike read, the target is not confined to the location. Experimental: may change without compatibility guarantees.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |
| `path` | query | yes | string | An absolute path or a path relative to the requested location. Missing parent directories are created. |

Request body (application/octet-stream, required): string<binary>

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `FileSystem.Write` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

## Tag: command

_Experimental command routes._

### GET `/api/command`

- operationId: `command.list`
- Summary: List commands

Retrieve currently registered commands.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Command.Info`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

## Tag: skill

_Experimental skill routes._

### GET `/api/skill`

- operationId: `skill.list`
- Summary: List skills

Retrieve currently registered skills.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Skill.Info`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

## Tag: rpc

_Plugin RPC routes._

### POST `/api/rpc/{rpcID}/{method}`

- operationId: `rpc.call`
- Summary: Call a plugin RPC

Dispatch a method to the currently registered RPC at the requested location.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `rpcID` | path | yes | string |  |
| `method` | path | yes | string |  |
| `location` | query | no | object{directory} \| null |  |

Request body (application/json, required): `Rpc.Input`

Responses:

- `200` Rpc.Output — `application/json`: `Rpc.Output`
- `400` RpcError | InvalidRequestError — `application/json`: `RpcErrorEncoded` \| `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `500` RpcInternalError — `application/json`: `RpcInternalErrorEncoded`

## Tag: event

_Experimental event stream routes._

### GET `/api/event`

- operationId: `event.subscribe`
- Summary: Subscribe to events

Subscribe to native events and plugin RPC events across all server locations. Volatile by contract: a slow consumer overflows and fails the stream, and events during disconnection are missed.

Responses:

- `200` Success — `text/event-stream`: object{id, event, data} (stream encoding: sse; failure event: `effect/httpapi/stream/failure`)

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `id` | string \| null | yes |  |
  | `event` | string | yes |  |
  | `data` | `V2EventEncoded` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

## Tag: pty

_Experimental location-scoped PTY routes._

### GET `/api/pty`

- operationId: `pty.list`
- Summary: List PTY sessions

List PTY sessions for a location, including exited sessions retained until removal.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Pty`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### POST `/api/pty`

- operationId: `pty.create`
- Summary: Create PTY session

Create a pseudo-terminal session for a location.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `command` | string | no |  |
| `args` | string[] | no |  |
| `cwd` | string | no |  |
| `title` | string | no |  |
| `env` | Record<string, string> | no |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Pty` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### GET `/api/pty/{ptyID}`

- operationId: `pty.get`
- Summary: Get PTY session

Get one PTY session, including its exit code once exited.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `ptyID` | path | yes | string (pattern `^pty`) |  |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Pty` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` PtyNotFoundError — `application/json`: `PtyNotFoundErrorEncoded`

### PUT `/api/pty/{ptyID}`

- operationId: `pty.update`
- Summary: Update PTY session

Update the title or viewport size of one PTY session.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `ptyID` | path | yes | string (pattern `^pty`) |  |
| `location` | query | no | object{directory} \| null |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `title` | string | no |  |
| `size` | object{rows, cols} | no |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Pty` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` PtyNotFoundError — `application/json`: `PtyNotFoundErrorEncoded`

### DELETE `/api/pty/{ptyID}`

- operationId: `pty.remove`
- Summary: Remove PTY session

Terminate and remove one PTY session.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `ptyID` | path | yes | string (pattern `^pty`) |  |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` PtyNotFoundError — `application/json`: `PtyNotFoundErrorEncoded`

### POST `/api/pty/{ptyID}/connect-token`

- operationId: `pty.connect.token`
- Summary: Create PTY WebSocket token

Create a short-lived single-use ticket for opening a PTY WebSocket connection.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `ptyID` | path | yes | string (pattern `^pty`) |  |
| `x-opencode-ticket` | header | no | string \| null |  |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `PtyTicket.ConnectToken` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `403` ForbiddenError — `application/json`: `ForbiddenErrorEncoded`
- `404` PtyNotFoundError — `application/json`: `PtyNotFoundErrorEncoded`

### GET `/api/pty/{ptyID}/connect`

- operationId: `pty.connect`
- Summary: Connect to PTY session

Establish a WebSocket connection streaming PTY output and accepting terminal input.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `ptyID` | path | yes | string (pattern `^pty`) |  |
| `location[directory]` | query | no | string |  |
| `cursor` | query | no | string |  |
| `ticket` | query | no | string |  |

Responses:

- `200` Success — `application/json`: boolean
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `403` ForbiddenError — `application/json`: `ForbiddenErrorEncoded`
- `404` PtyNotFoundError — `application/json`: `PtyNotFoundErrorEncoded`

## Tag: persistentPty

_Prototype persistent PTY routes._

### GET `/api/experimental/session/{sessionID}/terminal/read`

- operationId: `server.experimental.persistentPty.read`
- Summary: Read the session's most recently controlled terminal

Read the last physical rows without changing selection or taking control. Omitted lines uses the live terminal height; larger counts include retained history. Blank rows are preserved. Screen dimensions and cursor remain relative to the live screen. Returns null when no current terminal exists. Selection is server-local and resets on restart. Experimental: may change without compatibility guarantees.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |
| `lines` | query | no | `PersistentPty.ReadLinesEncoded` \| null |  |

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `PersistentPty.ReadResult` \| null | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `503` ServiceUnavailableError — `application/json`: `ServiceUnavailableErrorEncoded`

### GET `/api/experimental/session/{sessionID}/terminal`

- operationId: `server.experimental.persistentPty.list`

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `PersistentPty.Info`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `503` ServiceUnavailableError — `application/json`: `ServiceUnavailableErrorEncoded`

### POST `/api/experimental/session/{sessionID}/terminal`

- operationId: `server.experimental.persistentPty.create`

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `sessionID` | path | yes | string (pattern `^ses`) |  |

Request body (application/json, required): `PersistentPty.CreateInput`

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `PersistentPty.Info` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `503` ServiceUnavailableError — `application/json`: `ServiceUnavailableErrorEncoded`

### POST `/api/experimental/persistent-pty/shutdown`

- operationId: `server.experimental.persistentPty.shutdown`

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `503` ServiceUnavailableError — `application/json`: `ServiceUnavailableErrorEncoded`

### POST `/api/experimental/persistent-pty/handoff`

- operationId: `server.experimental.persistentPty.handoff`

Responses:

- `200` Success — `application/json`: object{handoff}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `handoff` | `PersistentPty.Handoff` \| null | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `503` ServiceUnavailableError — `application/json`: `ServiceUnavailableErrorEncoded`

### GET `/api/experimental/persistent-pty/{ptyID}`

- operationId: `server.experimental.persistentPty.get`

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `ptyID` | path | yes | string (pattern `^pty`) |  |

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `PersistentPty.Info` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` PtyNotFoundError — `application/json`: `PtyNotFoundErrorEncoded`
- `503` ServiceUnavailableError — `application/json`: `ServiceUnavailableErrorEncoded`

### PUT `/api/experimental/persistent-pty/{ptyID}`

- operationId: `server.experimental.persistentPty.update`

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `ptyID` | path | yes | string (pattern `^pty`) |  |

Request body (application/json, required): `PersistentPty.UpdateInput`

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `PersistentPty.Info` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` PtyNotFoundError — `application/json`: `PtyNotFoundErrorEncoded`
- `503` ServiceUnavailableError — `application/json`: `ServiceUnavailableErrorEncoded`

### DELETE `/api/experimental/persistent-pty/{ptyID}`

- operationId: `server.experimental.persistentPty.remove`

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `ptyID` | path | yes | string (pattern `^pty`) |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` PtyNotFoundError — `application/json`: `PtyNotFoundErrorEncoded`
- `503` ServiceUnavailableError — `application/json`: `ServiceUnavailableErrorEncoded`

### GET `/api/experimental/persistent-pty/{ptyID}/snapshot`

- operationId: `server.experimental.persistentPty.snapshot`

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `ptyID` | path | yes | string (pattern `^pty`) |  |

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `PersistentPty.Snapshot` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` PtyNotFoundError — `application/json`: `PtyNotFoundErrorEncoded`
- `503` ServiceUnavailableError — `application/json`: `ServiceUnavailableErrorEncoded`

### POST `/api/experimental/persistent-pty/{ptyID}/connect-token`

- operationId: `server.experimental.persistentPty.connectToken`

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `ptyID` | path | yes | string (pattern `^pty`) |  |
| `x-opencode-ticket` | header | no | string \| null |  |

Responses:

- `200` Success — `application/json`: object{data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `data` | `PtyTicket.ConnectToken` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `403` ForbiddenError — `application/json`: `ForbiddenErrorEncoded`
- `404` PtyNotFoundError — `application/json`: `PtyNotFoundErrorEncoded`
- `503` ServiceUnavailableError — `application/json`: `ServiceUnavailableErrorEncoded`

### GET `/api/experimental/persistent-pty/{ptyID}/connect`

- operationId: `persistentPty.connect`
- Summary: Connect to a persistent PTY

Stream persistent PTY output through the OpenCode server.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `ptyID` | path | yes | string (pattern `^pty`) |  |
| `cursor` | query | no | string |  |
| `role` | query | no | string |  |
| `attachment_id` | query | no | string |  |
| `takeover` | query | no | string |  |
| `input_protocol` | query | no | string |  |
| `ticket` | query | no | string |  |

Responses:

- `200` Success — `application/json`: boolean
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `403` ForbiddenError — `application/json`: `ForbiddenErrorEncoded`
- `404` PtyNotFoundError — `application/json`: `PtyNotFoundErrorEncoded`
- `503` ServiceUnavailableError — `application/json`: `ServiceUnavailableErrorEncoded`

## Tag: shell

_Location-scoped shell command routes._

### GET `/api/shell`

- operationId: `shell.list`
- Summary: List running shell commands

List currently running shell commands for a location. Exited commands are not included.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Shell.Info`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### POST `/api/shell`

- operationId: `shell.create`
- Summary: Run shell command

Spawn one non-interactive shell command for a location. Combined stdout/stderr is captured to a file pageable via output.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `command` | string | yes |  |
| `cwd` | string | no |  |
| `timeout` | integer | no |  |
| `metadata` | object | no |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Shell.Info` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### GET `/api/shell/{id}`

- operationId: `shell.get`
- Summary: Get shell command

Get one shell command, including its status and exit code once exited.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `id` | path | yes | string (pattern `^sh_`) |  |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Shell.Info` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` ShellNotFoundError — `application/json`: `ShellNotFoundErrorEncoded`

### DELETE `/api/shell/{id}`

- operationId: `shell.remove`
- Summary: Remove shell command

Terminate and remove one shell command and its retained output.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `id` | path | yes | string (pattern `^sh_`) |  |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### GET `/api/shell/{id}/output`

- operationId: `shell.output`
- Summary: Read shell output

Page through captured combined output by absolute byte cursor.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `id` | path | yes | string (pattern `^sh_`) |  |
| `location` | query | no | object{directory} \| null |  |
| `cursor` | query | no | string (pattern `^[+-]?\d*\.?\d+(?:[Ee][+-]?\d+)?$`) |  |
| `limit` | query | no | string (pattern `^[+-]?\d*\.?\d+(?:[Ee][+-]?\d+)?$`) |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | object{output, cursor, size, truncated} | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` ShellNotFoundError — `application/json`: `ShellNotFoundErrorEncoded`

## Tag: reference

_Location-scoped project references._

### GET `/api/reference`

- operationId: `reference.list`
- Summary: List references

List references available in the requested location.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Reference.Info`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

## Tag: worktree

_Project-based worktree management routes._

### GET `/api/worktree`

- operationId: `worktree.list`
- Summary: List worktrees

Return the project's saved worktree inventory without loading configuration or running discovery.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `projectID` | query | yes | string |  |

Responses:

- `200` Worktree.List — `application/json`: `Worktree.List`
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` ProjectNotFoundError — `application/json`: `ProjectNotFoundErrorEncoded`

### POST `/api/worktree`

- operationId: `worktree.create`
- Summary: Create worktree

Load the project's canonical configuration, create a local worktree using its selected strategy, then run the project's setup script.

Request body (application/json, required): `Worktree.CreateInput`

Responses:

- `200` Worktree.Info — `application/json`: `Worktree.Info`
- `400` WorktreeError | InvalidRequestError — `application/json`: `WorktreeErrorEncoded` \| `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` ProjectNotFoundError — `application/json`: `ProjectNotFoundErrorEncoded`

### DELETE `/api/worktree`

- operationId: `worktree.remove`
- Summary: Remove worktree

Load the project's canonical configuration and remove a saved worktree using its recorded strategy.

Request body (application/json, required): `Worktree.RemoveInput`

Responses:

- `204` <No Content>
- `400` WorktreeError | InvalidRequestError — `application/json`: `WorktreeErrorEncoded` \| `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` ProjectNotFoundError — `application/json`: `ProjectNotFoundErrorEncoded`

### POST `/api/worktree/refresh`

- operationId: `worktree.refresh`
- Summary: Refresh worktrees

Load the project's canonical configuration, discover worktrees across known checkout roots using all available strategies, and reconcile saved state.

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `projectID` | string | yes |  |

Responses:

- `204` <No Content>
- `400` WorktreeError | InvalidRequestError — `application/json`: `WorktreeErrorEncoded` \| `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `404` ProjectNotFoundError — `application/json`: `ProjectNotFoundErrorEncoded`

## Tag: vcs

_Location-scoped version control routes._

### GET `/api/vcs`

- operationId: `vcs.get`
- Summary: VCS info

Get current and default branch information for the requested location.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Vcs.Info` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### GET `/api/vcs/base`

- operationId: `vcs.base`
- Summary: VCS review base

Infer a local review base from named branch creation history, or the repository default only when currently on that branch. Returns null before the first commit or when the provider lacks base metadata; ambiguous Git history requires an explicit base on diff requests.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Vcs.Base` \| null | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `503` ServiceUnavailableError — `application/json`: `ServiceUnavailableErrorEncoded`

### GET `/api/vcs/status`

- operationId: `vcs.status`
- Summary: VCS status

List uncommitted working-copy changes relative to the requested location.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Vcs.FileStatus`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### GET `/api/vcs/branch`

- operationId: `vcs.branch.list`
- Summary: VCS branches

List local and remote branches available at the requested location.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |
| `search` | query | no | string \| null |  |
| `limit` | query | no | string \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `Vcs.BranchList` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### GET `/api/vcs/diff`

- operationId: `vcs.diff`
- Summary: VCS diff

Diff HEAD to the working copy (working), the base merge-base to the working copy (branch), or the base merge-base to HEAD (committed). Omitting base preserves repository-default comparison; supplying it overrides the comparison without saving it.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |
| `mode` | query | yes | `Vcs.Mode` |  |
| `base` | query | no | string |  |
| `context` | query | no | string \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `FileDiff.Info`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `503` ServiceUnavailableError — `application/json`: `ServiceUnavailableErrorEncoded`

## Tag: debug

### GET `/api/debug/location`

- operationId: `debug.location.list`
- Summary: List loaded locations

List locations currently loaded by the server.

Responses:

- `200` Success — `application/json`: `Location.PublicRef`[]
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### DELETE `/api/debug/location`

- operationId: `debug.location.evict`
- Summary: Evict a loaded location

Dispose the requested location's cached services so its next use boots them fresh.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

## Tag: migration

### GET `/api/experimental/migration/v1`

- operationId: `experimental.migration.v1.status`
- Summary: Get V1 migration status

Return the progress of the V1 to V2 session history migration.

Responses:

- `200` Success — `application/json`: object{status} \| object{status, progress} \| object{status, error}
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

## Tag: websearch

_Location-scoped web search routes._

### GET `/api/websearch/provider`

- operationId: `websearch.providers`
- Summary: List web search providers

Return the registered web search providers.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `WebSearch.Provider`[] | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `503` ServiceUnavailableError — `application/json`: `ServiceUnavailableErrorEncoded`

### POST `/api/websearch`

- operationId: `websearch.query`
- Summary: Search the web

Run one web search through the selected provider. Specify a provider to override the configured default.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Request body (application/json, required): 

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `query` | string | yes |  |
| `providerID` | string | no |  |

Responses:

- `200` Success — `application/json`: object{location, data}

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `location` | `Location.PublicRef` | yes |  |
  | `data` | `WebSearch.ResponseEncoded` | yes |  |

- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`
- `503` ServiceUnavailableError — `application/json`: `ServiceUnavailableErrorEncoded`

## Tag: config

_Location-scoped configuration routes._

### GET `/api/config`

- operationId: `config.get`
- Summary: Get configuration

Return configuration documents and discovery sources for the requested location, from lowest to highest priority.

Parameters:

| Name | In | Required | Type | Description |
| --- | --- | --- | --- | --- |
| `location` | query | no | object{directory} \| null |  |

Responses:

- `200` Success — `application/json`: `Config.Entry`[]
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### GET `/api/config/shell`

- operationId: `config.shells`
- Summary: List available shells

Return shells available to terminal and agent execution.

Responses:

- `200` Success — `application/json`: `ConfigShell.Option`[]
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

### PATCH `/api/experimental/config`

- operationId: `experimental.config.update`
- Summary: Update global configuration

Patch supported fields in the highest-precedence global configuration document.

Request body (application/json, required): `Config.Patch`

Responses:

- `204` <No Content>
- `400` InvalidRequestError — `application/json`: `InvalidRequestErrorEncoded`
- `401` UnauthorizedError — `application/json`: `UnauthorizedErrorEncoded`

## Schemas

### `Agent.Color`

Type: string

### `Agent.Info`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string | yes |  |
| `name` | string | yes |  |
| `model` | `Model.Ref` | no |  |
| `request` | `Provider.Request` | yes |  |
| `system` | string | no |  |
| `description` | string | no |  |
| `mode` | "subagent" \| "primary" \| "all" | yes |  |
| `hidden` | boolean | yes |  |
| `color` | `Agent.Color` | no |  |
| `steps` | integer | no |  |
| `permissions` | `Permission.Ruleset` | yes |  |

### `AgentNotFoundErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "AgentNotFoundError" | yes |  |
| `agentID` | string | yes |  |
| `message` | string | yes |  |

### `Command.Info`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `name` | string | yes |  |
| `description` | string | no |  |

### `CommandExecutionErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "CommandExecutionError" | yes |  |
| `command` | string | yes |  |
| `message` | string | yes |  |

### `CommandNotFoundErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "CommandNotFoundError" | yes |  |
| `command` | string | yes |  |
| `message` | string | yes |  |

### `Config.AgentEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `model` | string (pattern `^[^/#]+\/[^#]+(?:#[^#]+)?$`) \| object{providerID, model, variant} | no |  |
| `request` | object{headers, body} | no |  |
| `system` | string | no |  |
| `description` | string | no |  |
| `mode` | "subagent" \| "primary" \| "all" | no |  |
| `hidden` | boolean | no |  |
| `color` | string (pattern `^#[0-9a-fA-F]{6}$`) | no |  |
| `steps` | integer | no |  |
| `disabled` | boolean | no |  |
| `permissions` | `Permission.Ruleset` | no |  |

### `Config.CommandEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `template` | string | yes |  |
| `description` | string | no |  |
| `agent` | string | no |  |
| `model` | string (pattern `^[^/#]+\/[^#]+(?:#[^#]+)?$`) \| object{providerID, model, variant} | no |  |
| `subagent` | boolean | no |  |
| `subtask` | boolean | no | Deprecated alias for subagent. |

### `Config.DirectoryEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `type` | "directory" | yes |  |
| `path` | string | yes |  |

### `Config.DocumentEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `type` | "document" | yes |  |
| `path` | string | no |  |
| `info` | `Config.InfoEncoded` | yes |  |

### `Config.Entry`

anyOf:

- `Config.DocumentEncoded`
- `Config.DirectoryEncoded`

### `Config.Formatter.EntryEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `disabled` | boolean | no |  |
| `command` | string[] | no |  |
| `environment` | Record<string, string> | no |  |
| `extensions` | string[] | no |  |

### `Config.InfoEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `$schema` | string | no |  |
| `shell` | string | no |  |
| `model` | string (pattern `^[^/#]+\/[^#]+(?:#[^#]+)?$`) \| object{providerID, model, variant} | no |  |
| `default_agent` | string | no |  |
| `update` | "disable" \| "notify" \| "auto" | no |  |
| `share` | "manual" \| "auto" \| "disabled" | no |  |
| `enterprise` | object{url} | no |  |
| `username` | string | no |  |
| `permissions` | `Permission.Ruleset` | no |  |
| `agents` | Record<string, `Config.AgentEncoded`> | no |  |
| `snapshots` | boolean | no |  |
| `watcher` | object{ignore} | no |  |
| `formatter` | boolean \| Record<string, `Config.Formatter.EntryEncoded`> | no |  |
| `lsp` | boolean \| Record<string, object{disabled} \| `Config.LSP.ServerEncoded`> | no |  |
| `media` | object{image} | no |  |
| `tool_output` | object{max_lines, max_bytes} | no |  |
| `mcp` | object{timeout, servers} | no |  |
| `compaction` | object{auto, keep, buffer} | no |  |
| `skills` | string[] | no |  |
| `commands` | Record<string, `Config.CommandEncoded`> | no |  |
| `instructions` | string[] | no |  |
| `references` | Record<string, string \| `Config.Reference.GitEncoded` \| `Config.Reference.LocalEncoded`> | no |  |
| `websearch` | false \| `ConfigWebSearch.InfoEncoded` | no |  |
| `plugins` | string \| `Config.Plugin.EntryEncoded`[] | no |  |
| `worktree` | `Config.Worktree` | no |  |
| `warming` | boolean \| `Config.WarmingEncoded` | no |  |
| `providers` | Record<string, `Config.ProviderEncoded`> | no |  |
| `experimental` | object{portable_shell_scanner, subagent_depth, policies} | no |  |

### `Config.LSP.ServerEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `command` | string[] | yes |  |
| `extensions` | string[] | no |  |
| `disabled` | boolean | no |  |
| `env` | Record<string, string> | no |  |
| `initialization` | object | no |  |

### `Config.Model.CostEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `tier` | object{type, size} | no |  |
| `input` | `Money.USDPerMillionTokens` | yes |  |
| `output` | `Money.USDPerMillionTokens` | yes |  |
| `cache` | object{read, write} | no |  |

### `Config.Model.Settings`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `compaction` | `Provider.Compaction` | no |  |

### `Config.ModelEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `modelID` | string | no |  |
| `family` | string | no |  |
| `name` | string | no |  |
| `compatibility` | `Model.Compatibility` | no |  |
| `package` | string | no |  |
| `settings` | `Config.Model.Settings` | no |  |
| `headers` | Record<string, string> | no |  |
| `body` | object | no |  |
| `capabilities` | `Model.Capabilities` | no |  |
| `variants` | object{id, settings, headers, body}[] | no |  |
| `cost` | `Config.Model.CostEncoded` \| `Config.Model.CostEncoded`[] | no |  |
| `disabled` | boolean | no |  |
| `limit` | object{context, input, output} | no |  |

### `Config.Patch`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `shell` | string \| null | yes |  |

### `Config.Plugin.EntryEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `package` | string | yes |  |
| `options` | object | no |  |

### `Config.Provider.Settings`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `timeout` | number \| false | no |  |
| `chunkTimeout` | number | no |  |
| `compaction` | `Provider.Compaction` | no |  |
| `transport` | `Provider.Transport` | no |  |

### `Config.ProviderEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `canonical` | string | no |  |
| `name` | string | no |  |
| `env` | string[] | no |  |
| `package` | string | no |  |
| `settings` | `Config.Provider.Settings` | no |  |
| `headers` | Record<string, string> | no |  |
| `body` | object | no |  |
| `models` | Record<string, `Config.ModelEncoded`> | no |  |

### `Config.Reference.GitEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `repository` | string | yes |  |
| `branch` | string | no |  |
| `description` | string | no |  |
| `hidden` | boolean | no |  |

### `Config.Reference.LocalEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `path` | string | yes |  |
| `description` | string | no |  |
| `hidden` | boolean | no |  |

### `Config.WarmingEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `prompt` | string | no |  |
| `interval` | string | no |  |
| `duration` | string | no |  |

### `Config.Worktree`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `directory` | string | yes |  |

### `ConfigShell.Option`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `path` | string | yes |  |
| `name` | string | yes |  |
| `acceptable` | boolean | yes |  |

### `ConfigWebSearch.InfoEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `provider` | "random" \| string | yes | Reuse a randomly selected provider until it is rate limited, then switch to another available provider. |

### `ConflictErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "ConflictError" | yes |  |
| `message` | string | yes |  |
| `resource` | string \| null | no |  |

### `Connection.CredentialInfo`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `type` | "credential" | yes |  |
| `id` | string | yes |  |
| `label` | string | yes |  |
| `method` | "key" \| "oauth" | yes |  |

### `Connection.EnvInfo`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `type` | "env" | yes |  |
| `name` | string | yes |  |

### `Connection.Info`

anyOf:

- `Connection.CredentialInfo`
- `Connection.EnvInfo`

### `FileDiff.Info`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `file` | string | yes |  |
| `patch` | string | yes |  |
| `additions` | integer | yes |  |
| `deletions` | integer | yes |  |
| `status` | "added" \| "deleted" \| "modified" | yes |  |

### `FileNotFoundErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "FileNotFoundError" | yes |  |
| `path` | string | yes |  |
| `message` | string | yes |  |

### `FileSystem.Entry`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `path` | string | yes |  |
| `type` | "file" \| "directory" | yes |  |

### `FileSystem.Write`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `path` | string | yes |  |

### `ForbiddenErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "ForbiddenError" | yes |  |
| `message` | string | yes |  |

### `Form.Answer`

Type: Record<string, `Form.Value`>

### `Form.BooleanField`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `key` | string | yes |  |
| `title` | string | no |  |
| `description` | string | no |  |
| `required` | boolean | no |  |
| `hidden` | boolean | no |  |
| `when` | `Form.When`[] | no |  |
| `type` | "boolean" | yes |  |
| `default` | boolean | no |  |

### `Form.CreatePayload`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^frm_`) \| null | no |  |
| `title` | string | yes |  |
| `metadata` | `Form.Metadata` | no |  |
| `fields` | `Form.Fields` | yes |  |

### `Form.Detail`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^frm_`) | yes |  |
| `sessionID` | string | yes |  |
| `title` | string | yes |  |
| `metadata` | `Form.Metadata` | no |  |
| `fields` | `Form.Fields` | yes |  |
| `state` | `Form.State` | yes |  |

### `Form.ExternalField`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `key` | string | yes |  |
| `type` | "external" | yes |  |
| `url` | string | yes |  |
| `title` | string | no |  |
| `description` | string | no |  |

### `Form.Field`

anyOf:

- `Form.StringField`
- `Form.NumberField`
- `Form.IntegerField`
- `Form.BooleanField`
- `Form.MultiselectField`
- `Form.ExternalField`

### `Form.Fields`

Type: `Form.Field`[]

### `Form.Fields_1`

Type: `Form.Field`[]

### `Form.Fields_2`

Type: `Form.Field`[]

### `Form.Info`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^frm_`) | yes |  |
| `sessionID` | string | yes |  |
| `title` | string | yes |  |
| `metadata` | `Form.Metadata` | no |  |
| `fields` | `Form.Fields` | yes |  |

### `Form.IntegerField`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `key` | string | yes |  |
| `title` | string | no |  |
| `description` | string | no |  |
| `required` | boolean | no |  |
| `hidden` | boolean | no |  |
| `when` | `Form.When`[] | no |  |
| `type` | "integer" | yes |  |
| `minimum` | number \| "Infinity" \| "-Infinity" \| "NaN" | no |  |
| `maximum` | number \| "Infinity" \| "-Infinity" \| "NaN" | no |  |
| `default` | number \| "Infinity" \| "-Infinity" \| "NaN" | no |  |

### `Form.Metadata`

Type: object

### `Form.MultiselectField`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `key` | string | yes |  |
| `title` | string | no |  |
| `description` | string | no |  |
| `required` | boolean | no |  |
| `hidden` | boolean | no |  |
| `when` | `Form.When`[] | no |  |
| `type` | "multiselect" | yes |  |
| `options` | `Form.Option`[] | yes |  |
| `minItems` | integer | no |  |
| `maxItems` | integer | no |  |
| `custom` | boolean | no |  |
| `default` | string[] | no |  |

### `Form.NumberField`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `key` | string | yes |  |
| `title` | string | no |  |
| `description` | string | no |  |
| `required` | boolean | no |  |
| `hidden` | boolean | no |  |
| `when` | `Form.When`[] | no |  |
| `type` | "number" | yes |  |
| `minimum` | number \| "Infinity" \| "-Infinity" \| "NaN" | no |  |
| `maximum` | number \| "Infinity" \| "-Infinity" \| "NaN" | no |  |
| `default` | number \| "Infinity" \| "-Infinity" \| "NaN" | no |  |

### `Form.Option`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `value` | string | yes |  |
| `label` | string | yes |  |
| `description` | string | no |  |

### `Form.Reply`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `answer` | `Form.Answer` | yes |  |

### `Form.State`

anyOf:

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `status` | "pending" | yes |  |

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `status` | "answered" | yes |  |
  | `answer` | `Form.Answer` | yes |  |

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `status` | "cancelled" | yes |  |
  | `message` | string | no |  |


### `Form.StringField`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `key` | string | yes |  |
| `title` | string | no |  |
| `description` | string | no |  |
| `required` | boolean | no |  |
| `hidden` | boolean | no |  |
| `when` | `Form.When`[] | no |  |
| `type` | "string" | yes |  |
| `format` | "email" \| "uri" \| "date" \| "date-time" | no |  |
| `minLength` | integer | no |  |
| `maxLength` | integer | no |  |
| `pattern` | string | no |  |
| `placeholder` | string | no |  |
| `default` | string | no |  |
| `options` | `Form.Option`[] | no |  |
| `custom` | boolean | no |  |

### `Form.Value`

anyOf:

- string
- number \| "Infinity" \| "-Infinity" \| "NaN"
- boolean
- string[]

### `Form.When`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `key` | string | yes |  |
| `op` | "eq" \| "neq" | yes |  |
| `value` | string \| number \| "Infinity" \| "-Infinity" \| "NaN" \| boolean | yes |  |

### `FormAlreadySettledErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "FormAlreadySettledError" | yes |  |
| `id` | string | yes |  |
| `message` | string | yes |  |

### `FormInvalidAnswerErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "FormInvalidAnswerError" | yes |  |
| `id` | string | yes |  |
| `message` | string | yes |  |

### `FormNotFoundErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "FormNotFoundError" | yes |  |
| `id` | string | yes |  |
| `message` | string | yes |  |

### `GenerateTextResponse`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `data` | object{text} | yes |  |

### `InstructionEntry.Info`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `key` | `InstructionEntry.Key` | yes |  |
| `value` | object | yes | JSON value attached to the session's instructions |

### `InstructionEntry.Key`

Instruction entry key (lowercase alphanumerics plus . _ -)

Type: string (pattern `^[a-z0-9][a-z0-9._-]*$`)

### `InstructionEntryValueTooLargeErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "InstructionEntryValueTooLargeError" | yes |  |
| `actualBytes` | integer | yes |  |
| `maxBytes` | integer | yes |  |
| `message` | string | yes |  |

### `Integration.AttemptEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `attemptID` | string | yes |  |
| `url` | string | yes |  |
| `instructions` | string | yes |  |
| `mode` | "auto" \| "code" | yes |  |
| `time` | object{created, expires} | yes |  |

### `Integration.AttemptStatus`

anyOf:

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `status` | "pending" | yes |  |
  | `time` | object{created, expires} | yes |  |

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `status` | "complete" | yes |  |
  | `time` | object{created, expires} | yes |  |

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `status` | "failed" | yes |  |
  | `message` | string | yes |  |
  | `time` | object{created, expires} | yes |  |

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `status` | "expired" | yes |  |
  | `time` | object{created, expires} | yes |  |


### `Integration.CommandAttempt`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `attemptID` | string | yes |  |
| `time` | object{created, expires} | yes |  |

### `Integration.CommandAttemptStatus`

anyOf:

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `status` | "pending" | yes |  |
  | `message` | string | no |  |
  | `time` | object{created, expires} | yes |  |

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `status` | "complete" | yes |  |
  | `time` | object{created, expires} | yes |  |

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `status` | "failed" | yes |  |
  | `message` | string | yes |  |
  | `time` | object{created, expires} | yes |  |

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `status` | "expired" | yes |  |
  | `time` | object{created, expires} | yes |  |


### `Integration.CommandMethod`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string | yes |  |
| `type` | "command" | yes |  |
| `label` | string | yes |  |
| `command` | string[] | yes |  |

### `Integration.EnvMethod`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `type` | "env" | yes |  |
| `names` | string[] | yes |  |

### `Integration.Info`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string | yes |  |
| `name` | string | yes |  |
| `metadata` | object | no |  |
| `methods` | `Integration.Method`[] | yes |  |
| `connections` | `Connection.Info`[] | yes |  |

### `Integration.KeyMethod`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `type` | "key" | yes |  |
| `label` | string | no |  |
| `form` | `Form.Fields_2` | no |  |

### `Integration.Method`

anyOf:

- `Integration.OAuthMethod`
- `Integration.CommandMethod`
- `Integration.KeyMethod`
- `Integration.EnvMethod`

### `Integration.OAuthMethod`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string | yes |  |
| `type` | "oauth" | yes |  |
| `label` | string | yes |  |
| `form` | `Form.Fields_1` | no |  |

### `IntegrationAttemptNotFoundErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "IntegrationAttemptNotFoundError" | yes |  |
| `integrationID` | string | yes |  |
| `attemptID` | string | yes |  |
| `message` | string | yes |  |

### `IntegrationMethodNotFoundErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "IntegrationMethodNotFoundError" | yes |  |
| `integrationID` | string | yes |  |
| `methodID` | string | yes |  |
| `message` | string | yes |  |

### `IntegrationNotFoundErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "IntegrationNotFoundError" | yes |  |
| `integrationID` | string | yes |  |
| `message` | string | yes |  |

### `InvalidCursorErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "InvalidCursorError" | yes |  |
| `message` | string | yes |  |

### `InvalidRequestErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "InvalidRequestError" | yes |  |
| `message` | string | yes |  |
| `kind` | string \| null | no |  |
| `field` | string \| null | no |  |

### `Location.PublicInfo`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `directory` | string | yes |  |
| `project` | object{id, directory, canonical} | yes |  |

### `Location.PublicRef`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `directory` | string | yes |  |

### `Mcp.LocalConfigEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `type` | "local" | yes |  |
| `command` | string[] | yes |  |
| `cwd` | string | no |  |
| `environment` | Record<string, string> | no |  |
| `disabled` | boolean | no |  |
| `codemode` | boolean | no |  |
| `timeout` | object{startup, catalog, execution} | no |  |
| `protocol` | `Mcp.Protocol` | no |  |

### `Mcp.OAuthConfigEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `client_id` | string | no |  |
| `client_secret` | string | no |  |
| `scope` | string | no |  |
| `callback_port` | integer | no |  |
| `redirect_uri` | string | no |  |
| `auth_server_metadata_url` | string | no |  |

### `Mcp.Protocol`

MCP protocol negotiation. "legacy" (default) opens with the initialize handshake and speaks protocol revisions up to 2025-11-25. "auto" probes for the 2026-07-28 revision and falls back to legacy when the server does not support it. "2026-07-28" requires that revision and fails otherwise.

Type: "legacy" \| "auto" \| "2026-07-28"

### `Mcp.RemoteConfigEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `type` | "remote" | yes |  |
| `url` | string | yes |  |
| `headers` | Record<string, string> | no |  |
| `oauth` | `Mcp.OAuthConfigEncoded` \| false | no |  |
| `disabled` | boolean | no |  |
| `codemode` | boolean | no |  |
| `timeout` | object{startup, catalog, execution} | no |  |
| `protocol` | `Mcp.Protocol` | no |  |

### `Mcp.Resource`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `server` | string | yes |  |
| `name` | string | yes |  |
| `uri` | string | yes |  |
| `description` | string | no |  |
| `mimeType` | string | no |  |

### `Mcp.ResourceCatalog`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `resources` | `Mcp.Resource`[] | yes |  |
| `templates` | `Mcp.ResourceTemplate`[] | yes |  |

### `Mcp.ResourceTemplate`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `server` | string | yes |  |
| `name` | string | yes |  |
| `uriTemplate` | string | yes |  |
| `description` | string | no |  |
| `mimeType` | string | no |  |

### `Mcp.Server`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `name` | string | yes |  |
| `status` | `Mcp.Status.Connected` \| `Mcp.Status.Pending` \| `Mcp.Status.Disabled` \| `Mcp.Status.Failed` \| `Mcp.Status.NeedsAuth` | yes |  |
| `integrationID` | string | no |  |

### `Mcp.Status.Connected`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `status` | "connected" | yes |  |

### `Mcp.Status.Disabled`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `status` | "disabled" | yes |  |

### `Mcp.Status.Failed`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `status` | "failed" | yes |  |
| `error` | string | yes |  |

### `Mcp.Status.NeedsAuth`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `status` | "needs_auth" | yes |  |
| `error` | string | yes |  |

### `Mcp.Status.Pending`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `status` | "pending" | yes |  |

### `McpServerNotFoundErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "McpServerNotFoundError" | yes |  |
| `server` | string | yes |  |
| `message` | string | yes |  |

### `MessageNotFoundErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "MessageNotFoundError" | yes |  |
| `sessionID` | string | yes |  |
| `messageID` | string | yes |  |
| `message` | string | yes |  |

### `Model.Capabilities`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `tools` | boolean | yes |  |
| `input` | string[] | yes |  |
| `output` | string[] | yes |  |

### `Model.Compatibility`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `reasoningField` | `Model.ReasoningField` | no |  |
| `requireReasoning` | boolean | no |  |
| `maxTokensField` | `Model.MaxTokensField` | no |  |
| `requireFinishReason` | boolean | no |  |
| `requireAssistantAfterTool` | boolean | no |  |
| `supportsPromptCacheKey` | boolean | no |  |

### `Model.Cost`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `tier` | object{type, size} | no |  |
| `input` | `Money.USDPerMillionTokens` | yes |  |
| `output` | `Money.USDPerMillionTokens` | yes |  |
| `cache` | object{read, write} | yes |  |

### `Model.Info`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string | yes |  |
| `modelID` | string | yes |  |
| `providerID` | string | yes |  |
| `canonical` | string | no |  |
| `family` | string | no |  |
| `name` | string | yes |  |
| `compatibility` | `Model.Compatibility` | no |  |
| `package` | string | no |  |
| `settings` | `Model.Settings` | no |  |
| `headers` | Record<string, string> | no |  |
| `body` | object | no |  |
| `capabilities` | `Model.Capabilities` | yes |  |
| `variants` | `Model.Variant`[] | yes |  |
| `time` | object{released} | yes |  |
| `cost` | `Model.Cost`[] | yes |  |
| `status` | "alpha" \| "beta" \| "deprecated" \| "active" | yes |  |
| `enabled` | boolean | yes |  |
| `limit` | object{context, input, output} | yes |  |

### `Model.MaxTokensField`

Type: "max_completion_tokens" \| "max_tokens"

### `Model.ReasoningField`

anyOf:

- "reasoning" \| "reasoning_content" \| "reasoning_text"
- string

### `Model.Ref`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string | yes |  |
| `providerID` | string | yes |  |
| `variant` | string | no |  |

### `Model.Settings`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `compaction` | `Provider.Compaction` | no |  |

### `Model.Variant`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string | yes |  |
| `settings` | `Model.Settings` | no |  |
| `headers` | Record<string, string> | no |  |
| `body` | object | no |  |

### `Money.USD`

Type: number

### `Money.USDPerMillionTokens`

Type: number

### `Permission.Effect`

Type: "allow" \| "deny" \| "ask"

### `Permission.Reply`

Type: "once" \| "always" \| "reject"

### `Permission.Request`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^per`) | yes |  |
| `sessionID` | string (pattern `^ses`) | yes |  |
| `action` | string | yes |  |
| `resources` | string[] | yes |  |
| `save` | string[] | no |  |
| `metadata` | object | no |  |
| `source` | `Permission.Source` | no |  |
| `message` | string | no |  |

### `Permission.Rule`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `action` | string | yes |  |
| `resource` | string | yes |  |
| `effect` | `Permission.Effect` | yes |  |

### `Permission.Ruleset`

Type: `Permission.Rule`[]

### `Permission.Source`

anyOf:

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `type` | "tool" | yes |  |
  | `messageID` | string | yes |  |
  | `id` | string | yes |  |


### `PermissionNotFoundErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "PermissionNotFoundError" | yes |  |
| `requestID` | string | yes |  |
| `message` | string | yes |  |

### `PermissionSaved.Info`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string | yes |  |
| `projectID` | string | yes |  |
| `action` | string | yes |  |
| `resource` | string | yes |  |
| `time` | object{created, updated} | yes |  |

### `PersistentPty.CreateInput`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `command` | string | no |  |
| `args` | string[] | yes |  |
| `cwd` | string | no |  |
| `title` | string | yes |  |
| `env` | Record<string, string> | yes |  |
| `size` | object{cols, rows} | no |  |

### `PersistentPty.Handoff`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `directory` | string | yes |  |
| `instanceID` | string | yes |  |
| `ticket` | string | yes |  |
| `expiresAt` | number \| "Infinity" \| "-Infinity" \| "NaN" | yes |  |

### `PersistentPty.Info`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^pty`) | yes |  |
| `title` | string | yes |  |
| `command` | string | yes |  |
| `args` | string[] | yes |  |
| `cwd` | string | yes |  |
| `status` | "running" \| "exited" | yes |  |
| `pid` | integer | yes |  |
| `exitCode` | integer | no |  |
| `sessionID` | string (pattern `^ses`) | yes |  |
| `foregroundProcess` | string \| null | yes |  |
| `size` | object{cols, rows} | yes |  |
| `output` | object{head, tail} | yes |  |

### `PersistentPty.ReadLinesEncoded`

Type: string

### `PersistentPty.ReadResult`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `ptyID` | string (pattern `^pty`) | yes |  |
| `title` | string | yes |  |
| `cwd` | string | yes |  |
| `foregroundProcess` | string \| null | yes |  |
| `screen` | object{text, cols, rows, cursor} | yes |  |

### `PersistentPty.Snapshot`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `info` | `PersistentPty.Info` | yes |  |
| `text` | string | yes |  |
| `checkpoint` | string<byte> | yes |  |
| `cursor` | object{x, y} | yes |  |

### `PersistentPty.UpdateInput`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `attachmentID` | string | no |  |
| `size` | object{cols, rows} | yes |  |

### `Plugin.Features`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `server` | true | no |  |
| `tui` | true | no |  |
| `rpc` | true | no |  |

### `Plugin.Info`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string | no |  |
| `source` | `Plugin.Source` | yes |  |
| `features` | `Plugin.Features` | yes |  |
| `state` | `Plugin.State` | yes |  |

### `Plugin.Source`

anyOf:

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `type` | "builtin" | yes |  |

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `type` | "package" | yes |  |
  | `target` | string | yes |  |
  | `version` | string | no |  |
  | `outdated` | true | no |  |
  | `updating` | true | no |  |

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `type` | "local" | yes |  |
  | `path` | string | yes |  |

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `type` | "sdk" | yes |  |


### `Plugin.State`

anyOf:

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `status` | "active" | yes |  |

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `status` | "failed" | yes |  |
  | `error` | string | yes |  |
  | `ref` | string | no |  |


### `Project`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string | yes |  |
| `canonical` | string | yes |  |
| `vcs` | `Project.Vcs` | no |  |
| `name` | string | no |  |
| `icon` | `Project.Icon` | no |  |
| `commands` | `Project.Commands` | no |  |
| `time` | `Project.Time` | yes |  |
| `sandboxes` | string[] | yes |  |

### `Project.Commands`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `start` | string | no | Startup script to run when creating a new workspace (worktree) |

### `Project.Icon`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `url` | string | no |  |
| `override` | string | no |  |
| `color` | string | no |  |

### `Project.Time`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `created` | integer | yes |  |
| `updated` | integer | yes |  |
| `active` | integer | yes |  |

### `Project.Vcs`

Type: string (pattern `^[a-z][a-z0-9._-]*$`)

### `ProjectNotFoundErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "ProjectNotFoundError" | yes |  |
| `projectID` | string | yes |  |
| `message` | string | yes |  |

### `Prompt.AgentAttachment`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `name` | string | yes |  |
| `mention` | `Prompt.Mention` | no |  |

### `Prompt.Base64`

Type: string (pattern `^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$`)

### `Prompt.FileAttachment`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `data` | `Prompt.Base64` | yes |  |
| `mime` | string | yes |  |
| `source` | `Prompt.FileSource` | yes |  |
| `name` | string | no |  |
| `description` | string | no |  |
| `mention` | `Prompt.Mention` | no |  |

### `Prompt.FileSource`

anyOf:

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `type` | "inline" | yes |  |

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `type` | "uri" | yes |  |
  | `uri` | string | yes |  |


### `Prompt.Mention`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `start` | number | yes |  |
| `end` | number | yes |  |
| `text` | string | yes |  |

### `Prompt.SkillAttachment`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string | yes |  |
| `name` | string | yes |  |
| `text` | string | no |  |
| `mention` | `Prompt.Mention` | no |  |

### `PromptInput.FileAttachment`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `uri` | string | yes |  |
| `name` | string | no |  |
| `description` | string | no |  |
| `mention` | `Prompt.Mention` | no |  |

### `PromptInput.SkillAttachment`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string | yes |  |
| `mention` | `Prompt.Mention` | no |  |

### `Provider.Compaction`

anyOf:

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `type` | "summary" | yes |  |

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `type` | "native" | yes |  |


### `Provider.Info`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string | yes |  |
| `canonical` | string | no |  |
| `integrationID` | string | no |  |
| `name` | string | yes |  |
| `activation` | "auto" \| "enabled" \| "disabled" | yes |  |
| `package` | string | yes |  |
| `settings` | `Provider.Settings` | no |  |
| `headers` | Record<string, string> | no |  |
| `body` | object | no |  |

### `Provider.Request`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `settings` | `Provider.Settings` | yes |  |
| `headers` | Record<string, string> | yes |  |
| `body` | object | yes |  |

### `Provider.Settings`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `timeout` | number \| false | no |  |
| `chunkTimeout` | number | no |  |
| `compaction` | `Provider.Compaction` | no |  |
| `transport` | `Provider.Transport` | no |  |

### `Provider.Transport`

Type: "http" \| "websocket"

### `ProviderNotFoundErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "ProviderNotFoundError" | yes |  |
| `providerID` | string | yes |  |
| `message` | string | yes |  |

### `Pty`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^pty`) | yes |  |
| `title` | string | yes |  |
| `command` | string | yes |  |
| `args` | string[] | yes |  |
| `cwd` | string | yes |  |
| `status` | "running" \| "exited" | yes |  |
| `pid` | integer | yes |  |
| `exitCode` | integer | no |  |

### `PtyNotFoundErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "PtyNotFoundError" | yes |  |
| `ptyID` | string | yes |  |
| `message` | string | yes |  |

### `PtyTicket.ConnectToken`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `ticket` | string | yes |  |
| `expires_in` | integer | yes |  |

### `Reference.GitSource`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `type` | "git" | yes |  |
| `repository` | string | yes |  |
| `branch` | string | no |  |

### `Reference.Info`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `name` | string | yes |  |
| `path` | string | yes |  |
| `description` | string | no |  |
| `hidden` | boolean | no |  |
| `source` | `Reference.Source` | yes |  |

### `Reference.LocalSource`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `type` | "local" | yes |  |
| `path` | string | yes |  |

### `Reference.Source`

anyOf:

- `Reference.LocalSource`
- `Reference.GitSource`

### `Rpc.Input`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `input` | object | no |  |

### `Rpc.Output`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `output` | object | no |  |

### `RpcErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "RpcError" | yes |  |
| `type` | string | yes |  |
| `message` | string | yes |  |
| `data` | object \| null | no |  |

### `RpcInternalErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "RpcInternalError" | yes |  |
| `type` | "rpc.internal" \| "rpc.invalid_output" | yes |  |
| `message` | string | yes |  |
| `data` | object \| null | no |  |

### `ServerInfo`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `version` | string | yes |  |
| `pid` | integer | yes |  |
| `urls` | string[] | yes |  |
| `paths` | object{tmp} | yes |  |

### `ServiceUnavailableErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "ServiceUnavailableError" | yes |  |
| `message` | string | yes |  |
| `service` | string \| null | no |  |

### `Session.ForkBoundary`

anyOf:

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `type` | "before" | yes |  |
  | `messageID` | string (pattern `^msg_`) | yes |  |

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `type` | "through" | yes |  |
  | `messageID` | string (pattern `^msg_`) | yes |  |


### `Session.Inbox.Compaction`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^msg_`) | yes |  |
| `sessionID` | string (pattern `^ses`) | yes |  |
| `time` | object{created} | yes |  |
| `type` | "compaction" | yes |  |
| `payload` | `Session.Inbox.CompactionPayload` | yes |  |
| `delivery` | `Session.Inbox.Delivery` | yes |  |

### `Session.Inbox.CompactionPayload`

anyOf:

- object
- empty[]

### `Session.Inbox.Delivery`

Type: "steer" \| "queue"

### `Session.Inbox.Info`

anyOf:

- `Session.Inbox.User`
- `Session.Inbox.Synthetic`
- `Session.Inbox.Compaction`
- `Session.Inbox.Move`

### `Session.Inbox.Move`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^msg_`) | yes |  |
| `sessionID` | string (pattern `^ses`) | yes |  |
| `time` | object{created} | yes |  |
| `type` | "move" | yes |  |
| `delivery` | `Session.Inbox.Delivery` | yes |  |
| `payload` | `Session.Inbox.MovePayload` | yes |  |

### `Session.Inbox.MovePayload`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `projectID` | string | yes |  |
| `subpath` | string | no |  |
| `location` | `Location.PublicRef` | yes |  |

### `Session.Inbox.Synthetic`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^msg_`) | yes |  |
| `sessionID` | string (pattern `^ses`) | yes |  |
| `time` | object{created} | yes |  |
| `type` | "synthetic" | yes |  |
| `payload` | `Session.Inbox.SyntheticPayload` | yes |  |
| `delivery` | `Session.Inbox.Delivery` | yes |  |

### `Session.Inbox.SyntheticPayload`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `text` | string | yes |  |
| `description` | string | no |  |
| `metadata` | object | no |  |

### `Session.Inbox.User`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^msg_`) | yes |  |
| `sessionID` | string (pattern `^ses`) | yes |  |
| `time` | object{created} | yes |  |
| `type` | "user" | yes |  |
| `payload` | `Session.Inbox.UserPayload` | yes |  |
| `delivery` | `Session.Inbox.Delivery` | yes |  |

### `Session.Inbox.UserPayload`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `text` | string | yes |  |
| `files` | `Prompt.FileAttachment`[] | no |  |
| `agents` | `Prompt.AgentAttachment`[] | no |  |
| `skills` | `Prompt.SkillAttachment`[] | no |  |
| `metadata` | object | no |  |

### `Session.Info`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^ses`) | yes |  |
| `parentID` | string (pattern `^ses`) | no |  |
| `fork` | object{sessionID, boundary} | no |  |
| `projectID` | string | yes |  |
| `agent` | string | no |  |
| `model` | `Model.Ref` | no |  |
| `cost` | `Money.USD` | yes |  |
| `tokens` | `TokenUsage.Info` | yes |  |
| `outcome` | "succeeded" \| "failed" \| "interrupted" | no |  |
| `time` | object{created, updated, idle, viewed, archived} | yes |  |
| `title` | string | no |  |
| `subpath` | string | no |  |
| `metadata` | `Session.Metadata` | no |  |
| `permissions` | `Permission.Ruleset` | no |  |
| `revert` | `Session.Revert` | no |  |
| `location` | `Location.PublicRef` | yes |  |

### `Session.Message.AgentSelected`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^msg_`) | yes |  |
| `metadata` | object | no |  |
| `time` | object{created} | yes |  |
| `type` | "agent-switched" | yes |  |
| `agent` | string | yes |  |
| `previous` | string | no |  |

### `Session.Message.Assistant`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^msg_`) | yes |  |
| `metadata` | object | no |  |
| `time` | object{created, streamed, completed} | yes |  |
| `type` | "assistant" | yes |  |
| `agent` | string | yes |  |
| `model` | `Model.Ref` | yes |  |
| `content` | `Session.Message.Assistant.Text` \| `Session.Message.Assistant.Reasoning` \| `Session.Message.Assistant.Tool`[] | yes |  |
| `snapshot` | object{start, end, files} | no |  |
| `finish` | "stop" \| "length" \| "tool-calls" \| "content-filter" \| "error" \| "unknown" | no |  |
| `rawFinish` | string | no |  |
| `providerState` | `Session.Message.ProviderState_4` | no |  |
| `cost` | `Money.USD` | no |  |
| `tokens` | `TokenUsage.Info` | no |  |
| `error` | `Session.StructuredError` | no |  |
| `retry` | `Session.Message.Assistant.Retry` | no |  |

### `Session.Message.Assistant.Reasoning`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `type` | "reasoning" | yes |  |
| `text` | string | yes |  |
| `state` | `Session.Message.ProviderState_1` | no |  |
| `time` | object{created, completed} | no |  |

### `Session.Message.Assistant.Retry`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `attempt` | integer | yes |  |
| `at` | number | yes |  |
| `error` | `Session.StructuredError` | yes |  |

### `Session.Message.Assistant.Text`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `type` | "text" | yes |  |
| `text` | string | yes |  |
| `state` | `Session.Message.ProviderState` | no |  |

### `Session.Message.Assistant.Tool`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `type` | "tool" | yes |  |
| `id` | string | yes |  |
| `name` | string | yes |  |
| `executed` | boolean | no |  |
| `providerState` | `Session.Message.ProviderState_2` | no |  |
| `providerResultState` | `Session.Message.ProviderState_3` | no |  |
| `state` | `Session.Message.ToolState.Streaming` \| `Session.Message.ToolState.Running` \| `Session.Message.ToolState.Completed` \| `Session.Message.ToolState.Error` | yes |  |
| `time` | object{created, ran, completed} | yes |  |

### `Session.Message.Compaction`

anyOf:

- `Session.Message.Compaction.Running`
- `Session.Message.Compaction.Completed`
- `Session.Message.Compaction.Failed`

### `Session.Message.Compaction.Completed`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `type` | "compaction" | yes |  |
| `id` | string (pattern `^msg_`) | yes |  |
| `metadata` | object | no |  |
| `time` | object{created} | yes |  |
| `status` | "completed" | yes |  |
| `reason` | "auto" \| "manual" | yes |  |
| `model` | `Model.Ref` | no |  |
| `providerState` | `Session.Message.ProviderState_5` | no |  |
| `summary` | string | yes |  |
| `recent` | string | yes |  |
| `providerContext` | `Session.ProviderContext` | no |  |
| `cost` | `Money.USD` | no |  |
| `tokens` | `TokenUsage.Info` | no |  |

### `Session.Message.Compaction.Failed`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `type` | "compaction" | yes |  |
| `id` | string (pattern `^msg_`) | yes |  |
| `metadata` | object | no |  |
| `time` | object{created} | yes |  |
| `status` | "failed" | yes |  |
| `reason` | "auto" \| "manual" | yes |  |
| `error` | `Session.StructuredError` | yes |  |
| `cost` | `Money.USD` | no |  |
| `tokens` | `TokenUsage.Info` | no |  |

### `Session.Message.Compaction.Running`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `type` | "compaction" | yes |  |
| `id` | string (pattern `^msg_`) | yes |  |
| `metadata` | object | no |  |
| `time` | object{created} | yes |  |
| `status` | "running" | yes |  |
| `reason` | "auto" \| "manual" | yes |  |
| `summary` | string | yes |  |
| `recent` | string | yes |  |

### `Session.Message.Idle`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^msg_`) | yes |  |
| `metadata` | object | no |  |
| `time` | object{created} | yes |  |
| `type` | "idle" | yes |  |
| `outcome` | "succeeded" \| "failed" \| "interrupted" | yes |  |

### `Session.Message.Info`

anyOf:

- `Session.Message.AgentSelected`
- `Session.Message.ModelSelected`
- `Session.Message.LocationSwitched`
- `Session.Message.User`
- `Session.Message.Synthetic`
- `Session.Message.System`
- `Session.Message.Skill`
- `Session.Message.Shell`
- `Session.Message.Assistant`
- `Session.Message.Compaction`
- `Session.Message.Idle`

### `Session.Message.LocationSwitched`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^msg_`) | yes |  |
| `metadata` | object | no |  |
| `time` | object{created} | yes |  |
| `type` | "location-switched" | yes |  |
| `projectID` | string | no |  |
| `subpath` | string | no |  |
| `location` | `Location.PublicRef` | yes |  |
| `previous` | object{location, projectID, subpath} \| null | no |  |

### `Session.Message.ModelSelected`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^msg_`) | yes |  |
| `metadata` | object | no |  |
| `time` | object{created} | yes |  |
| `type` | "model-switched" | yes |  |
| `model` | `Model.Ref` | yes |  |
| `previous` | `Model.Ref` | no |  |

### `Session.Message.ProviderState`

Type: object

### `Session.Message.ProviderState_1`

Type: object

### `Session.Message.ProviderState_2`

Type: object

### `Session.Message.ProviderState_3`

Type: object

### `Session.Message.ProviderState_4`

Type: object

### `Session.Message.ProviderState_5`

Type: object

### `Session.Message.Shell`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^msg_`) | yes |  |
| `metadata` | object | no |  |
| `time` | object{created, completed} | yes |  |
| `type` | "shell" | yes |  |
| `shellID` | string (pattern `^sh_`) | yes |  |
| `command` | string | yes |  |
| `status` | "running" \| "exited" \| "timeout" \| "killed" | yes |  |
| `exit` | number \| "Infinity" \| "-Infinity" \| "NaN" | no |  |
| `output` | object{output, cursor, size, truncated} | no |  |

### `Session.Message.Skill`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^msg_`) | yes |  |
| `metadata` | object | no |  |
| `time` | object{created} | yes |  |
| `type` | "skill" | yes |  |
| `skill` | string | yes |  |
| `name` | string | yes |  |
| `text` | string | yes |  |

### `Session.Message.Synthetic`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^msg_`) | yes |  |
| `metadata` | object | no |  |
| `time` | object{created} | yes |  |
| `text` | string | yes |  |
| `description` | string | no |  |
| `type` | "synthetic" | yes |  |

### `Session.Message.System`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^msg_`) | yes |  |
| `metadata` | object | no |  |
| `time` | object{created} | yes |  |
| `type` | "system" | yes |  |
| `text` | string | yes |  |
| `description` | string | no |  |

### `Session.Message.ToolState.Completed`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `status` | "completed" | yes |  |
| `input` | object | yes |  |
| `content` | `Tool.Content`[] | yes |  |
| `metadata` | object | no |  |

### `Session.Message.ToolState.Error`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `status` | "error" | yes |  |
| `input` | object | yes |  |
| `error` | `Session.StructuredError` | yes |  |
| `content` | `Tool.Content`[] | no |  |
| `metadata` | object | no |  |

### `Session.Message.ToolState.Running`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `status` | "running" | yes |  |
| `input` | object | yes |  |
| `metadata` | object | yes |  |

### `Session.Message.ToolState.Streaming`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `status` | "streaming" | yes |  |
| `input` | string | yes |  |

### `Session.Message.User`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^msg_`) | yes |  |
| `metadata` | object | no |  |
| `time` | object{created} | yes |  |
| `text` | string | yes |  |
| `files` | `Prompt.FileAttachment`[] | no |  |
| `agents` | `Prompt.AgentAttachment`[] | no |  |
| `skills` | `Prompt.SkillAttachment`[] | no |  |
| `type` | "user" | yes |  |

### `Session.Metadata`

Type: object

### `Session.ProviderContext`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `version` | 1 | yes |  |
| `provenance` | `Session.ProviderContext.Provenance` | yes |  |
| `messages` | object | yes |  |

### `Session.ProviderContext.Provenance`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `providerID` | string | yes |  |
| `provider` | string | yes |  |
| `modelID` | string | yes |  |
| `route` | string | yes |  |
| `protocol` | string | yes |  |
| `endpoint` | string | yes |  |

### `Session.Revert`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `messageID` | string (pattern `^msg_`) | yes |  |
| `partID` | string | no |  |
| `snapshot` | string | no |  |
| `files` | `FileDiff.Info`[] | no |  |

### `Session.StructuredError`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `type` | string | yes |  |
| `message` | string | yes |  |
| `status` | integer | no |  |

### `SessionActive`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `type` | "running" | yes |  |

### `SessionBusyErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "SessionBusyError" | yes |  |
| `sessionID` | string | yes |  |
| `message` | string | yes |  |

### `SessionGenerateResponse`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `data` | object{text} | yes |  |

### `SessionInterruptResponse`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `interrupted` | boolean | yes | Whether an active execution owned by this OpenCode process was interrupted. |

### `SessionLogItemEncoded`

Type: string

### `SessionMessagesResponse`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `data` | `Session.Message.Info`[] | yes |  |
| `cursor` | object{previous, next} | yes |  |

### `SessionNotFoundErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "SessionNotFoundError" | yes |  |
| `sessionID` | string | yes |  |
| `message` | string | yes |  |

### `SessionStats.Activity`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `date` | string | yes |  |
| `steps` | integer | yes |  |

### `SessionStats.Info`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `range` | object{from, to} | yes |  |
| `sessions` | integer | yes |  |
| `subagents` | integer | yes |  |
| `prompts` | integer | yes |  |
| `steps` | integer | yes |  |
| `tokens` | `TokenUsage.Info` | yes |  |
| `cost` | `Money.USD` | yes |  |
| `tools` | `SessionStats.Tools` | yes |  |
| `activeDays` | integer | yes |  |
| `streak` | integer | yes |  |
| `activity` | `SessionStats.Activity`[] | yes |  |
| `models` | `SessionStats.ModelUsage`[] | yes |  |

### `SessionStats.ModelUsage`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `model` | `Model.Ref` | yes |  |
| `steps` | integer | yes |  |
| `tokens` | `TokenUsage.Info` | yes |  |
| `cost` | `Money.USD` | yes |  |

### `SessionStats.ToolTotals`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `calls` | integer | yes |  |
| `succeeded` | integer | yes |  |
| `failed` | integer | yes |  |
| `unfinished` | integer | yes |  |

### `SessionStats.ToolUsage`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `name` | string | yes |  |
| `calls` | integer | yes |  |
| `succeeded` | integer | yes |  |
| `failed` | integer | yes |  |
| `unfinished` | integer | yes |  |
| `durationP50` | number | no |  |

### `SessionStats.Tools`

anyOf:

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `mode` | "none" | yes |  |

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `mode` | "summary" | yes |  |
  | `totals` | `SessionStats.ToolTotals` | yes |  |

- inline object:

  | Field | Type | Required | Description |
  | --- | --- | --- | --- |
  | `mode` | "detail" | yes |  |
  | `totals` | `SessionStats.ToolTotals` | yes |  |
  | `usage` | `SessionStats.ToolUsage`[] | yes |  |


### `SessionTransfer.Data`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `info` | `Session.Info` | yes |  |
| `messages` | `Session.Message.Info`[] | yes |  |

### `SessionsResponse`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `data` | `Session.Info`[] | yes |  |
| `cursor` | object{previous, next} | yes |  |

### `Shell.Info`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string (pattern `^sh_`) | yes |  |
| `status` | "running" \| "exited" \| "timeout" \| "killed" | yes |  |
| `command` | string | yes |  |
| `cwd` | string | yes |  |
| `shell` | string | yes |  |
| `file` | string | yes |  |
| `pid` | integer | no |  |
| `exit` | number | no |  |
| `metadata` | object | yes |  |
| `time` | object{started, completed} | yes |  |

### `ShellNotFoundErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "ShellNotFoundError" | yes |  |
| `id` | string | yes |  |
| `message` | string | yes |  |

### `Skill.Info`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string | yes |  |
| `name` | string | yes |  |
| `description` | string | no |  |
| `autoinvoke` | boolean | no |  |
| `path` | string | yes |  |
| `content` | string | yes |  |

### `SkillNotFoundErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "SkillNotFoundError" | yes |  |
| `skill` | string | yes |  |
| `message` | string | yes |  |

### `TokenUsage.Info`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `input` | number | yes |  |
| `output` | number | yes |  |
| `reasoning` | number | yes |  |
| `cache` | object{read, write} | yes |  |

### `Tool.Content`

anyOf:

- `Tool.TextContent`
- `Tool.FileContent`

### `Tool.FileContent`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `type` | "file" | yes |  |
| `uri` | string | yes |  |
| `mime` | string | yes |  |
| `name` | string \| null | no |  |

### `Tool.TextContent`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `type` | "text" | yes |  |
| `text` | string | yes |  |

### `UnauthorizedErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "UnauthorizedError" | yes |  |
| `message` | string | yes |  |

### `UnknownErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "UnknownError" | yes |  |
| `message` | string | yes |  |
| `ref` | string \| null | no |  |

### `V2EventEncoded`

Type: string

### `Vcs.Base`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `name` | string | yes |  |
| `ref` | string | yes |  |
| `source` | "reflog" \| "default" | yes |  |

### `Vcs.Branch`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `current` | string | no |  |
| `default` | string | no |  |

### `Vcs.BranchList`

Type: string[]

### `Vcs.FileStatus`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `file` | string | yes |  |
| `additions` | integer | yes |  |
| `deletions` | integer | yes |  |
| `status` | "added" \| "deleted" \| "modified" | yes |  |

### `Vcs.Info`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `provider` | string | no |  |
| `branch` | `Vcs.Branch` | yes |  |

### `Vcs.Mode`

Type: "working" \| "branch" \| "committed"

### `WebSearch.Provider`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string | yes |  |
| `name` | string | yes |  |

### `WebSearch.ResponseEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `providerID` | string | yes |  |
| `results` | `WebSearch.Result`[] | yes |  |

### `WebSearch.Result`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `url` | string | yes |  |
| `title` | string | no |  |
| `content` | string | no |  |
| `time` | object{published} | yes |  |

### `Worktree.CreateInput`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `projectID` | string | yes |  |
| `from` | string | no |  |
| `branch` | string | no |  |
| `directory` | string | no |  |
| `name` | string | no |  |

### `Worktree.Directory`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `directory` | string | yes |  |
| `strategy` | string | no |  |

### `Worktree.Info`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `directory` | string | yes |  |

### `Worktree.List`

Type: `Worktree.Directory`[]

### `Worktree.RemoveInput`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `projectID` | string | yes |  |
| `directory` | string | yes |  |
| `force` | boolean | yes |  |

### `WorktreeErrorEncoded`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `_tag` | "WorktreeError" | yes |  |
| `name` | "WorktreeError" | yes |  |
| `data` | object{message, forceRequired} | yes |  |

