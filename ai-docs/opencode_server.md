Title: Server

URL Source: https://opencode.ai/docs/server/

Markdown Content:
Server | OpenCode
===============
[Skip to content](https://opencode.ai/docs/server/#_top)

[![Image 1](https://opencode.ai/docs/_astro/logo-dark.DOStV66V.svg)![Image 2](https://opencode.ai/docs/_astro/logo-light.B0yzR0O5.svg) OpenCode](https://opencode.ai/docs/)

[app.header.home](https://opencode.ai/)[app.header.docs](https://opencode.ai/docs/)

[](https://github.com/anomalyco/opencode)[](https://opencode.ai/discord)

Search Ctrl K

 Cancel 

*   [Intro](https://opencode.ai/docs/)
*   [Config](https://opencode.ai/docs/config/)
*   [Providers](https://opencode.ai/docs/providers/)
*   [Network](https://opencode.ai/docs/network/)
*   [Enterprise](https://opencode.ai/docs/enterprise/)
*   [Troubleshooting](https://opencode.ai/docs/troubleshooting/)
*   [Windows (WSL)](https://opencode.ai/docs/windows-wsl/)
*   
Usage 
    *   [TUI](https://opencode.ai/docs/tui/)
    *   [CLI](https://opencode.ai/docs/cli/)
    *   [Web](https://opencode.ai/docs/web/)
    *   [IDE](https://opencode.ai/docs/ide/)
    *   [Zen](https://opencode.ai/docs/zen/)
    *   [Share](https://opencode.ai/docs/share/)
    *   [GitHub](https://opencode.ai/docs/github/)
    *   [GitLab](https://opencode.ai/docs/gitlab/)

*   
Configure 
    *   [Tools](https://opencode.ai/docs/tools/)
    *   [Rules](https://opencode.ai/docs/rules/)
    *   [Agents](https://opencode.ai/docs/agents/)
    *   [Models](https://opencode.ai/docs/models/)
    *   [Themes](https://opencode.ai/docs/themes/)
    *   [Keybinds](https://opencode.ai/docs/keybinds/)
    *   [Commands](https://opencode.ai/docs/commands/)
    *   [Formatters](https://opencode.ai/docs/formatters/)
    *   [Permissions](https://opencode.ai/docs/permissions/)
    *   [LSP Servers](https://opencode.ai/docs/lsp/)
    *   [MCP servers](https://opencode.ai/docs/mcp-servers/)
    *   [ACP Support](https://opencode.ai/docs/acp/)
    *   [Agent Skills](https://opencode.ai/docs/skills/)
    *   [Custom Tools](https://opencode.ai/docs/custom-tools/)

*   
Develop 
    *   [SDK](https://opencode.ai/docs/sdk/)
    *   [Server](https://opencode.ai/docs/server/)
    *   [Plugins](https://opencode.ai/docs/plugins/)
    *   [Ecosystem](https://opencode.ai/docs/ecosystem/)

[GitHub](https://github.com/anomalyco/opencode)[Discord](https://opencode.ai/discord)

Select theme Select language 

On this page

*   [Overview](https://opencode.ai/docs/server/#_top)
    *   [Usage](https://opencode.ai/docs/server/#usage)
    *   [Authentication](https://opencode.ai/docs/server/#authentication)
    *   [How it works](https://opencode.ai/docs/server/#how-it-works)

*   [Spec](https://opencode.ai/docs/server/#spec)
*   [APIs](https://opencode.ai/docs/server/#apis)
    *   [Global](https://opencode.ai/docs/server/#global)
    *   [Project](https://opencode.ai/docs/server/#project)
    *   [Path & VCS](https://opencode.ai/docs/server/#path--vcs)
    *   [Instance](https://opencode.ai/docs/server/#instance)
    *   [Config](https://opencode.ai/docs/server/#config)
    *   [Provider](https://opencode.ai/docs/server/#provider)
    *   [Sessions](https://opencode.ai/docs/server/#sessions)
    *   [Messages](https://opencode.ai/docs/server/#messages)
    *   [Commands](https://opencode.ai/docs/server/#commands)
    *   [Files](https://opencode.ai/docs/server/#files)
    *   [Tools (Experimental)](https://opencode.ai/docs/server/#tools-experimental)
    *   [LSP, Formatters & MCP](https://opencode.ai/docs/server/#lsp-formatters--mcp)
    *   [Agents](https://opencode.ai/docs/server/#agents)
    *   [Logging](https://opencode.ai/docs/server/#logging)
    *   [TUI](https://opencode.ai/docs/server/#tui)
    *   [Auth](https://opencode.ai/docs/server/#auth)
    *   [Events](https://opencode.ai/docs/server/#events)
    *   [Docs](https://opencode.ai/docs/server/#docs)

On this page
------------

*   [Overview](https://opencode.ai/docs/server/#_top)
    *   [Usage](https://opencode.ai/docs/server/#usage)
    *   [Authentication](https://opencode.ai/docs/server/#authentication)
    *   [How it works](https://opencode.ai/docs/server/#how-it-works)

*   [Spec](https://opencode.ai/docs/server/#spec)
*   [APIs](https://opencode.ai/docs/server/#apis)
    *   [Global](https://opencode.ai/docs/server/#global)
    *   [Project](https://opencode.ai/docs/server/#project)
    *   [Path & VCS](https://opencode.ai/docs/server/#path--vcs)
    *   [Instance](https://opencode.ai/docs/server/#instance)
    *   [Config](https://opencode.ai/docs/server/#config)
    *   [Provider](https://opencode.ai/docs/server/#provider)
    *   [Sessions](https://opencode.ai/docs/server/#sessions)
    *   [Messages](https://opencode.ai/docs/server/#messages)
    *   [Commands](https://opencode.ai/docs/server/#commands)
    *   [Files](https://opencode.ai/docs/server/#files)
    *   [Tools (Experimental)](https://opencode.ai/docs/server/#tools-experimental)
    *   [LSP, Formatters & MCP](https://opencode.ai/docs/server/#lsp-formatters--mcp)
    *   [Agents](https://opencode.ai/docs/server/#agents)
    *   [Logging](https://opencode.ai/docs/server/#logging)
    *   [TUI](https://opencode.ai/docs/server/#tui)
    *   [Auth](https://opencode.ai/docs/server/#auth)
    *   [Events](https://opencode.ai/docs/server/#events)
    *   [Docs](https://opencode.ai/docs/server/#docs)

Server
======

Interact with opencode server over HTTP.

The `opencode serve` command runs a headless HTTP server that exposes an OpenAPI endpoint that an opencode client can use.

* * *

### [Usage](https://opencode.ai/docs/server/#usage)

Terminal window

`opencode serve [--port <number>] [--hostname <string>] [--cors <origin>]`

#### [Options](https://opencode.ai/docs/server/#options)

| Flag | Description | Default |
| --- | --- | --- |
| `--port` | Port to listen on | `4096` |
| `--hostname` | Hostname to listen on | `127.0.0.1` |
| `--mdns` | Enable mDNS discovery | `false` |
| `--mdns-domain` | Custom domain name for mDNS service | `opencode.local` |
| `--cors` | Additional browser origins to allow | `[]` |

`--cors` can be passed multiple times:

Terminal window

`opencode serve --cors http://localhost:5173 --cors https://app.example.com`

* * *

### [Authentication](https://opencode.ai/docs/server/#authentication)

Set `OPENCODE_SERVER_PASSWORD` to protect the server with HTTP basic auth. The username defaults to `opencode`, or set `OPENCODE_SERVER_USERNAME` to override it. This applies to both `opencode serve` and `opencode web`.

Terminal window

`OPENCODE_SERVER_PASSWORD=your-password opencode serve`

* * *

### [How it works](https://opencode.ai/docs/server/#how-it-works)

When you run `opencode` it starts a TUI and a server. Where the TUI is the client that talks to the server. The server exposes an OpenAPI 3.1 spec endpoint. This endpoint is also used to generate an [SDK](https://opencode.ai/docs/sdk).

Tip

Use the opencode server to interact with opencode programmatically.

This architecture lets opencode support multiple clients and allows you to interact with opencode programmatically.

You can run `opencode serve` to start a standalone server. If you have the opencode TUI running, `opencode serve` will start a new server.

* * *

#### [Connect to an existing server](https://opencode.ai/docs/server/#connect-to-an-existing-server)

When you start the TUI it randomly assigns a port and hostname. You can instead pass in the `--hostname` and `--port`[flags](https://opencode.ai/docs/cli). Then use this to connect to its server.

The [`/tui`](https://opencode.ai/docs/server/#tui) endpoint can be used to drive the TUI through the server. For example, you can prefill or run a prompt. This setup is used by the OpenCode [IDE](https://opencode.ai/docs/ide) plugins.

* * *

[Spec](https://opencode.ai/docs/server/#spec)
---------------------------------------------

The server publishes an OpenAPI 3.1 spec that can be viewed at:

`http://<hostname>:<port>/doc`

For example, `http://localhost:4096/doc`. Use the spec to generate clients or inspect request and response types. Or view it in a Swagger explorer.

* * *

[APIs](https://opencode.ai/docs/server/#apis)
---------------------------------------------

The opencode server exposes the following APIs.

* * *

### [Global](https://opencode.ai/docs/server/#global)

| Method | Path | Description | Response |
| --- | --- | --- | --- |
| `GET` | `/global/health` | Get server health and version | `{ healthy: true, version: string }` |
| `GET` | `/global/event` | Get global events (SSE stream) | Event stream |

* * *

### [Project](https://opencode.ai/docs/server/#project)

| Method | Path | Description | Response |
| --- | --- | --- | --- |
| `GET` | `/project` | List all projects | [`Project[]`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |
| `GET` | `/project/current` | Get the current project | [`Project`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |

* * *

### [Path & VCS](https://opencode.ai/docs/server/#path--vcs)

| Method | Path | Description | Response |
| --- | --- | --- | --- |
| `GET` | `/path` | Get the current path | [`Path`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |
| `GET` | `/vcs` | Get VCS info for the current project | [`VcsInfo`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |

* * *

### [Instance](https://opencode.ai/docs/server/#instance)

| Method | Path | Description | Response |
| --- | --- | --- | --- |
| `POST` | `/instance/dispose` | Dispose the current instance | `boolean` |

* * *

### [Config](https://opencode.ai/docs/server/#config)

| Method | Path | Description | Response |
| --- | --- | --- | --- |
| `GET` | `/config` | Get config info | [`Config`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |
| `PATCH` | `/config` | Update config | [`Config`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |
| `GET` | `/config/providers` | List providers and default models | `{ providers:`[Provider[]](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts)`, default: { [key: string]: string } }` |

* * *

### [Provider](https://opencode.ai/docs/server/#provider)

| Method | Path | Description | Response |
| --- | --- | --- | --- |
| `GET` | `/provider` | List all providers | `{ all:`[Provider[]](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts)`, default: {...}, connected: string[] }` |
| `GET` | `/provider/auth` | Get provider authentication methods | `{ [providerID: string]:`[ProviderAuthMethod[]](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts)`}` |
| `POST` | `/provider/{id}/oauth/authorize` | Authorize a provider using OAuth | [`ProviderAuthAuthorization`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |
| `POST` | `/provider/{id}/oauth/callback` | Handle OAuth callback for a provider | `boolean` |

* * *

### [Sessions](https://opencode.ai/docs/server/#sessions)

| Method | Path | Description | Notes |
| --- | --- | --- | --- |
| `GET` | `/session` | List all sessions | Returns [`Session[]`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |
| `POST` | `/session` | Create a new session | body: `{ parentID?, title? }`, returns [`Session`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |
| `GET` | `/session/status` | Get session status for all sessions | Returns `{ [sessionID: string]:`[SessionStatus](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts)`}` |
| `GET` | `/session/:id` | Get session details | Returns [`Session`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |
| `DELETE` | `/session/:id` | Delete a session and all its data | Returns `boolean` |
| `PATCH` | `/session/:id` | Update session properties | body: `{ title? }`, returns [`Session`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |
| `GET` | `/session/:id/children` | Get a session’s child sessions | Returns [`Session[]`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |
| `GET` | `/session/:id/todo` | Get the todo list for a session | Returns [`Todo[]`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |
| `POST` | `/session/:id/init` | Analyze app and create `AGENTS.md` | body: `{ messageID, providerID, modelID }`, returns `boolean` |
| `POST` | `/session/:id/fork` | Fork an existing session at a message | body: `{ messageID? }`, returns [`Session`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |
| `POST` | `/session/:id/abort` | Abort a running session | Returns `boolean` |
| `POST` | `/session/:id/share` | Share a session | Returns [`Session`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |
| `DELETE` | `/session/:id/share` | Unshare a session | Returns [`Session`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |
| `GET` | `/session/:id/diff` | Get the diff for this session | query: `messageID?`, returns [`FileDiff[]`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |
| `POST` | `/session/:id/summarize` | Summarize the session | body: `{ providerID, modelID }`, returns `boolean` |
| `POST` | `/session/:id/revert` | Revert a message | body: `{ messageID, partID? }`, returns `boolean` |
| `POST` | `/session/:id/unrevert` | Restore all reverted messages | Returns `boolean` |
| `POST` | `/session/:id/permissions/:permissionID` | Respond to a permission request | body: `{ response, remember? }`, returns `boolean` |

* * *

### [Messages](https://opencode.ai/docs/server/#messages)

| Method | Path | Description | Notes |
| --- | --- | --- | --- |
| `GET` | `/session/:id/message` | List messages in a session | query: `limit?`, returns `{ info:`[Message](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts)`, parts:`[Part[]](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts)`}[]` |
| `POST` | `/session/:id/message` | Send a message and wait for response | body: `{ messageID?, model?, agent?, noReply?, system?, tools?, parts }`, returns `{ info:`[Message](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts)`, parts:`[Part[]](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts)`}` |
| `GET` | `/session/:id/message/:messageID` | Get message details | Returns `{ info:`[Message](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts)`, parts:`[Part[]](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts)`}` |
| `POST` | `/session/:id/prompt_async` | Send a message asynchronously (no wait) | body: same as `/session/:id/message`, returns `204 No Content` |
| `POST` | `/session/:id/command` | Execute a slash command | body: `{ messageID?, agent?, model?, command, arguments }`, returns `{ info:`[Message](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts)`, parts:`[Part[]](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts)`}` |
| `POST` | `/session/:id/shell` | Run a shell command | body: `{ agent, model?, command }`, returns `{ info:`[Message](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts)`, parts:`[Part[]](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts)`}` |

* * *

### [Commands](https://opencode.ai/docs/server/#commands)

| Method | Path | Description | Response |
| --- | --- | --- | --- |
| `GET` | `/command` | List all commands | [`Command[]`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |

* * *

### [Files](https://opencode.ai/docs/server/#files)

| Method | Path | Description | Response |
| --- | --- | --- | --- |
| `GET` | `/find?pattern=<pat>` | Search for text in files | Array of match objects with `path`, `lines`, `line_number`, `absolute_offset`, `submatches` |
| `GET` | `/find/file?query=<q>` | Find files and directories by name | `string[]` (paths) |
| `GET` | `/find/symbol?query=<q>` | Find workspace symbols | [`Symbol[]`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |
| `GET` | `/file?path=<path>` | List files and directories | [`FileNode[]`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |
| `GET` | `/file/content?path=<p>` | Read a file | [`FileContent`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |
| `GET` | `/file/status` | Get status for tracked files | [`File[]`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |

#### [`/find/file` query parameters](https://opencode.ai/docs/server/#findfile-query-parameters)

*   `query` (required) — search string (fuzzy match)
*   `type` (optional) — limit results to `"file"` or `"directory"`
*   `directory` (optional) — override the project root for the search
*   `limit` (optional) — max results (1–200)
*   `dirs` (optional) — legacy flag (`"false"` returns only files)

* * *

### [Tools (Experimental)](https://opencode.ai/docs/server/#tools-experimental)

| Method | Path | Description | Response |
| --- | --- | --- | --- |
| `GET` | `/experimental/tool/ids` | List all tool IDs | [`ToolIDs`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |
| `GET` | `/experimental/tool?provider=<p>&model=<m>` | List tools with JSON schemas for a model | [`ToolList`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |

* * *

### [LSP, Formatters & MCP](https://opencode.ai/docs/server/#lsp-formatters--mcp)

| Method | Path | Description | Response |
| --- | --- | --- | --- |
| `GET` | `/lsp` | Get LSP server status | [`LSPStatus[]`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |
| `GET` | `/formatter` | Get formatter status | [`FormatterStatus[]`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |
| `GET` | `/mcp` | Get MCP server status | `{ [name: string]:`[MCPStatus](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts)`}` |
| `POST` | `/mcp` | Add MCP server dynamically | body: `{ name, config }`, returns MCP status object |

* * *

### [Agents](https://opencode.ai/docs/server/#agents)

| Method | Path | Description | Response |
| --- | --- | --- | --- |
| `GET` | `/agent` | List all available agents | [`Agent[]`](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/gen/types.gen.ts) |

* * *

### [Logging](https://opencode.ai/docs/server/#logging)

| Method | Path | Description | Response |
| --- | --- | --- | --- |
| `POST` | `/log` | Write log entry. Body: `{ service, level, message, extra? }` | `boolean` |

* * *

### [TUI](https://opencode.ai/docs/server/#tui)

| Method | Path | Description | Response |
| --- | --- | --- | --- |
| `POST` | `/tui/append-prompt` | Append text to the prompt | `boolean` |
| `POST` | `/tui/open-help` | Open the help dialog | `boolean` |
| `POST` | `/tui/open-sessions` | Open the session selector | `boolean` |
| `POST` | `/tui/open-themes` | Open the theme selector | `boolean` |
| `POST` | `/tui/open-models` | Open the model selector | `boolean` |
| `POST` | `/tui/submit-prompt` | Submit the current prompt | `boolean` |
| `POST` | `/tui/clear-prompt` | Clear the prompt | `boolean` |
| `POST` | `/tui/execute-command` | Execute a command (`{ command }`) | `boolean` |
| `POST` | `/tui/show-toast` | Show toast (`{ title?, message, variant }`) | `boolean` |
| `GET` | `/tui/control/next` | Wait for the next control request | Control request object |
| `POST` | `/tui/control/response` | Respond to a control request (`{ body }`) | `boolean` |

* * *

### [Auth](https://opencode.ai/docs/server/#auth)

| Method | Path | Description | Response |
| --- | --- | --- | --- |
| `PUT` | `/auth/:id` | Set authentication credentials. Body must match provider schema | `boolean` |

* * *

### [Events](https://opencode.ai/docs/server/#events)

| Method | Path | Description | Response |
| --- | --- | --- | --- |
| `GET` | `/event` | Server-sent events stream. First event is `server.connected`, then bus events | Server-sent events stream |

* * *

### [Docs](https://opencode.ai/docs/server/#docs)

| Method | Path | Description | Response |
| --- | --- | --- | --- |
| `GET` | `/doc` | OpenAPI 3.1 specification | HTML page with OpenAPI spec |

[Edit page](https://github.com/anomalyco/opencode/edit/dev/packages/web/src/content/docs/server.mdx)[Found a bug? Open an issue](https://github.com/anomalyco/opencode/issues/new)[Join our Discord community](https://opencode.ai/discord)Select language 

© [Anomaly](https://anoma.ly/)

Last updated: Feb 13, 2026
