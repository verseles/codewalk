# 24 — Grok Build (xAI / "SpaceXAI") as a CodeWalk harness

Research date: 2026-10-02. Tags: **[V]** = Verified (source cited), **[U]** = Unverified / inferred.
Raw extracts for offline planners: `plan/harness-src/grok/` (14-headless-mode.md, 15-agent-mode.md,
16-subagents.md, 17-sessions.md, 22-permissions-and-safety.md — official user guide from the repo) and
`plan/harness-src/acp-registry/grok-build.json` + `acp-schema-v1-meta*.json` (ACP method names).

## TL;DR

- **Exists, official, open source (Apache-2.0, Rust)** — `xai-org/grok-build`, CLI `grok`. Early beta 2026-05-14,
  broadened 2026-05-25, open-sourced July 2026, npm 1.0.0 on 2026-08-07, **latest 1.0.46 (2026-09-30)**. [V]
- **Native ACP agent** (`grok agent stdio`) **and a native ACP-over-WebSocket server**
  (`grok agent serve --bind 127.0.0.1:2419 --secret <token>`) with bearer-token auth and state that survives client
  reconnects — the only one of the four harnesses a phone can reach **without a custom bridge** (still needs a
  secure network path: no TLS built in). [V]
- Large `x.ai/*` ACP extension surface: session list/fork/rename/delete/usage, rewind, interject (mid-turn),
  queue, fuzzy file search, fs, git, worktrees, terminal/PTY, billing, skills, subagents, `x.ai/ask_user_question`. [V]
- Headless `grok -p` with `--output-format json|streaming-json|streaming-messages-json` (Claude-Code-compatible stream-json). [V]
- Verdict: **Integrable, best surface = ACP over WebSocket (`grok agent serve`); medium effort, low–medium risk**
  (x.ai extensions are documented as non-exhaustive and may expand; serve auth is a single shared secret).

## 1. Identity

| Item | Value | Tag |
|---|---|---|
| Vendor | xAI, branded **SpaceXAI** in repo/docs ("SpaceXAI's coding agent harness and TUI") | [V] https://github.com/xai-org/grok-build |
| Repo / site / docs | https://github.com/xai-org/grok-build (synced periodically from the SpaceXAI monorepo, `SOURCE_REV` file) · https://x.ai/cli · https://x.ai/build · https://docs.x.ai/build/overview · changelog https://x.ai/build/changelog (403 to fetchers) | [V] |
| License | Repo **Apache-2.0** (gh API; npm `license: Apache-2.0`). Wikipedia: released under Apache License 2026-07-16 "after data upload controversy". The ACP registry entry still says `"license": "proprietary"` (stale/binary ToS) | [V] gh API, npm, Wikipedia, registry |
| Popularity | ~27k GitHub stars | [V] gh API |
| Latest version | npm `@xai-official/grok`: `latest` **1.0.46** (2026-09-30T22:11Z), `alpha` 1.0.48; `1.0.0` 2026-08-07; package created 2025-10-22 (0.1.0). ACP registry pins 1.0.47 | [V] npm view |
| Release history | Early beta **2026-05-14** (SuperGrok Heavy), expanded **2026-05-25** to all SuperGrok and X Premium+; model `grok-build-0.1` replaced `grok-code-fast-1` routing after 2026-05-15; Grok 4.5 (2026-07-08), 4.6 (2026-08-12), 4.7 (2026-09-21) available in Grok Build | [V] https://pulse2.com/xai-grok-build-launches-early-beta-coding-agent-cli/ · Wikipedia |
| Install | `curl -fsSL https://x.ai/cli/install.sh \| bash` (macOS/Linux/Git Bash; `bash -s <ver>` pins), `irm https://x.ai/cli/install.ps1 \| iex` (Windows), `winget upgrade --id xAI.GrokBuild -e`, npm `@xai-official/grok` (platform packages `grok-darwin-arm64`, `grok-darwin-x64`, `grok-linux-arm64`, `grok-linux-x64`, `grok-win32-arm64`, `grok-win32-x64`); `grok update` | [V] docs 01-getting-started.md; repo npm/ dirs; installer arch switch (`x86_64`/`aarch64`, macOS + Linux) inspected |
| Platforms | macOS (x64, arm64), **Linux x64 + arm64**, Windows x64 + arm64, WSL | [V] |
| Auth | `grok login` → SpaceXAI OAuth at `auth.x.ai` (default; subscription: SuperGrok / X Premium+ tiers), `--oidc`/external-provider login, or **`XAI_API_KEY`** (console.x.ai) as fallback when no session token. Tokens in `~/.grok/auth.json` (0600). ACP `authenticate` + `x.ai/auth/get_url|submit_code` for remote login | [V] docs 02-authentication.md, 15-agent-mode.md |
| Enterprise | managed config `/etc/grok/managed_config.toml`, `requirements.toml` locks (e.g. disable always-approve), OIDC, team ZDR | [V] docs 22; innfactory |

## 2. Programmatic surfaces

| Surface | Command | Official? | Notes |
|---|---|---|---|
| **ACP over WebSocket** | `grok agent [--always-approve] [-m MODEL] serve --bind 127.0.0.1:2419 --secret <token>` (or `GROK_AGENT_SECRET`; a token is generated and printed if omitted). Endpoint `ws://<bind>/ws`. Auth: header `Authorization: Bearer <secret>` **or** query `?server-key=<secret>`; 401 otherwise. "The process keeps state across client reconnects." The TUI itself can attach: `grok … --remote ws://host:port/ws --secret <token>`. | Yes | **Best for CodeWalk.** Plain `ws://` (axum `TcpListener`), no TLS → use Tailscale/WireGuard/SSH tunnel or a TLS reverse proxy |
| ACP over stdio | `grok agent [--always-approve] [--model M] [--agent-profile P] [--leader\|--no-leader] stdio` | Yes | Zed, Neovim (CodeCompanion, avante), Emacs agent-shell, marimo; JetBrains "coming soon" |
| WebSocket relay | `grok agent --always-approve headless --grok-ws-url wss://your-relay.example.com/ws` (agent dials out to a relay; browsers connect to the same relay) | Yes | Useful when the host cannot accept inbound connections [relay protocol details U] |
| Leader mode | `--leader` connects to a shared leader process (multi-client, `config_option_update` mirrored to every client); refused when a non-`off` sandbox profile is requested | Yes | Multi-device sharing [U details] |
| Headless | `grok -p "<prompt>"` (+ `--prompt-json`, `--prompt-file`), `--output-format plain\|json\|streaming-json\|streaming-messages-json`, `--include-partial-messages`, `-r/--resume <id\|title>`, `-c/--continue`, `-s/--session-id <uuid>` (create only), `--fork-session`, `--cwd`, `--yolo`, `--permission-mode`, `--allow`/`--deny`, `--tools`, `--disallowed-tools` (incl. `Agent(explore)`), `--max-turns`, `--reasoning-effort`/`--effort`, `--sandbox`, `--rules`, `--verbatim`, `--no-auto-update` | Yes | One-shot; fallback |
| CLI helpers | `grok sessions list [--limit N]`, `grok sessions search "<q>"`, `grok usage <session-id> [turn]` (JSON, `costUsdTicks` = 1e10/USD) | Yes | Bridge-side helpers |
| SDKs | No first-party Grok Build SDK found; ACP SDKs (TS `@agentclientprotocol/sdk`, Rust `agent-client-protocol`, Python, Go `coder/acp-go-sdk`, Kotlin) recommended by xAI docs; Vercel AI SDK harness `@ai-sdk/harness-grok-build` (ACP-based) | Partial | No Dart ACP SDK → CodeWalk writes its own [U: none found] |
| MCP | Client: stdio/HTTP/SSE servers (`grok mcp`, `.grok/config.toml`, reads Claude `.mcp.json`); ACP `mcpCapabilities.http/sse = true`; in-process SDK MCP over the ACP reverse channel (`x.ai/mcp/sdk_call`) | Yes | |
| Compatibility | Reads existing `AGENTS.md`, `CLAUDE.md`, `.claude/settings.json` (permissions `defaultMode`), hooks, skills, MCP config | Yes | [V] docs; innfactory |

Sources: docs/user-guide/15-agent-mode.md, 14-headless-mode.md, 17-sessions.md; `crates/codegen/xai-grok-shell/src/agent/server.rs` (WebSocket server: "Run the agent WebSocket server … accepts authenticated connections from remote TUI clients"; `validate_auth` Bearer / `server-key`); `agent/mvp_agent/acp_agent.rs` [V].

## 3. ACP protocol detail (as implemented by Grok)

### 3.1 Standard ACP v1 (schema v1.10.x) [V]

- JSON-RPC 2.0; stdio = newline-delimited; WebSocket = one message per text frame [U for frame granularity; standard ACP practice].
- `initialize` → `InitializeResponse(ProtocolVersion::V1)` with `agentCapabilities`: `loadSession: true`,
  `promptCapabilities.embeddedContext: true`, `mcpCapabilities {http: true, sse: true}`, `sessionCapabilities`
  `{list, resume}` (in the default branch), `_meta` advertising `"x.ai/fs_notify": true`, `"x.ai/hooks": {blockingEvents, decisions, stopSignals}`,
  `"x.ai/capabilities": {toolOverrides}`, plus response `_meta` `{grokShell: true, defaultAuthMethodId, currentWorkingDirectory, agentVersion, …}` and `authMethods`.
- Agent methods implemented (trait impls in `acp_agent.rs`): `initialize`, `authenticate`, `session/new`, `session/load`,
  `session/list`, `session/resume`, `session/close`, `session/prompt`, `session/cancel` (notification), `session/set_mode`,
  `session/set_model`, `session/set_config_option`, ext methods (`x.ai/*`), ext notifications.
- `session/new` params: `{cwd, mcpServers: [], _meta?: {rules, systemPromptOverride, agentProfile, yoloMode, autoMode, pluginDirs}}`.
  Response includes typed `configOptions` (standard ACP). Change via `session/set_config_option`:

```json
{"sessionId":"…","configId":"reasoning_effort","value":{"value":"high"}}
```
  `configId` `model` (string id, gated by `allowed_models`) and `reasoning_effort` (`minimal`,`low`,`medium`,`high`,`xhigh`;
  dropped with warning if the model lacks `supportsReasoningEffort`). Response = complete updated option list; a
  `config_option_update` notification mirrors it to all subscribed clients. Boolean options rejected.
- `session/prompt {sessionId, prompt:[{type:"text",text}, …]}` → result `{stopReason}` (`end_turn`, `max_tokens`,
  `max_turn_requests`, `refusal`, `cancelled`); `_meta.usage` carries `PromptUsage` (full prompt input sum). Image
  content blocks are accepted and uploaded (`prompt_images`) although only `embeddedContext` is advertised [V code; U advertised].
- Streaming: `session/update` notifications with `update.sessionUpdate` ∈ `agent_message_chunk`, `agent_thought_chunk`,
  `tool_call`, `tool_call_update`, `plan` (documented), plus standard `available_commands_update`, `config_option_update`,
  `current_mode_update`, `session_info_update`, `usage_update`, `user_message_chunk` (ACP v1 enum) [V schema; per-kind Grok emission partially U].
- Permissions: standard `session/request_permission` (agent → client) with options of kind `allow_once`,
  `allow_always`, `reject_once`, `reject_always`; Grok telemetry records `allow_once` / `reject_once` outcomes [V].
  Not sent when the session is always-approve.

Doc example (TypeScript ACP client):

```ts
spawn("grok", ["agent", "--always-approve", "stdio"]);
await request("initialize", { protocolVersion: 1, clientCapabilities: { fs: { readTextFile: true, writeTextFile: true }, terminal: true } });
const { sessionId } = await request("session/new", { cwd: ".", mcpServers: [], _meta: { yoloMode: true } });
write({ jsonrpc: "2.0", id: 1, method: "session/prompt", params: { sessionId, prompt: [{ type: "text", text }] } });
// data.method === "session/update" → data.params.update.sessionUpdate: "agent_message_chunk" | "agent_thought_chunk" | "tool_call" | …
```

### 3.2 `x.ai/*` extension methods (from `acp_agent.rs`, verbatim; "non-exhaustive … discover from `initialize`") [V]

Session/conversation: `x.ai/session/list`, `x.ai/sessions/list`, `x.ai/session/search`, `x.ai/session/info`,
`x.ai/session/state`, `x.ai/session/usage`, `x.ai/session/updates`, `x.ai/session/load_history`, `x.ai/session/fork`,
`x.ai/session/rename`, `x.ai/session/delete`, `x.ai/session/close`, `x.ai/session/import`, `x.ai/session/repair`,
`x.ai/session/rehydrate`, `x.ai/session/prompt_complete`, `x.ai/session/update_mcp_servers`,
`x.ai/session/add_local_workspace`, `x.ai/session/resolve_local_for_worktree_resume`, `x.ai/session_summaries/*`,
`x.ai/rewind`, `x.ai/compact_conversation`, `x.ai/prompt_history`, `x.ai/recap`, `x.ai/btw`, `x.ai/suggest`,
`x.ai/suggestPrompt`, `x.ai/share_session`.
Mid-turn & queue: **`x.ai/interject`** (`{sessionId, text, interjectionId?, content?: ContentBlock[]}` → `{"status":"queued"}`;
drained "at the next safe point"), `x.ai/queue/*`, `x.ai/task/*`, `x.ai/scheduler/*`.
Modes/permissions: `x.ai/toggle_plan_mode`, `x.ai/permissions/reset`, notification `x.ai/yolo_mode_changed`.
Discovery: `x.ai/commands/list`, `x.ai/models/list`, `x.ai/skills/*`, `x.ai/plugins/*`, `x.ai/plugins/reload`,
`x.ai/marketplace/*`, `x.ai/hooks`, `x.ai/hooks/*`, `x.ai/workflows/list`, `x.ai/workspaces/list`, `x.ai/capabilities`.
Files/code: `x.ai/fs/*` (`list`, `exists`, `read_file`, `write_file`), `x.ai/search/*` (`fuzzy/open`, `fuzzy/change`, `content`),
`x.ai/code/*`, `x.ai/git/*` (`status`, `stage`, `commit`, `diffs`, `discard`), `x.ai/git/worktree/*` (`create`, `remove`, `apply`, `list`, `gc`),
`x.ai/pr/*`, `x.ai/review`.
Terminal: `x.ai/terminal/*` (`create`, `kill`, `output`, `wait_for_exit`), `x.ai/terminal/pty/input`.
Subagents: `x.ai/subagent/*`. Account/billing: `x.ai/billing`, `x.ai/auth/*` (`get_url`, `submit_code`), `x.ai/getApiKey`,
`x.ai/setApiKey`, `x.ai/privacy/setCodingDataRetention`, `x.ai/consent/record`. Cloud: `x.ai/cloud/env/create|list|update|delete`,
`x.ai/cloud/terminate`. Telemetry/feedback: `x.ai/feedback`, `x.ai/feedback/*`, `x.ai/telemetry/*`, `x.ai/rollout/survey`.
Agent→client (client must implement): **`x.ai/ask_user_question`** (questions `[{question, options:[{label, description, preview?, id?}], multiSelect?, id?}]`,
optional timeout; answered later when the user submits/cancels) and MCP elicitation forwarding [V pager source; exact response shape U].
Notifications (agent → client): `x.ai/search/fuzzy/status`, `x.ai/git/worktree/status`, `x.ai/fs_notify`,
`x.ai/fs/index`, `x.ai/fs/index/delta`, `x.ai/session_notification` (diff review, retry state, auto-compact), `x.ai/session/update`.

### 3.3 Permissions model [V] (22-permissions-and-safety.md)

Modes: `default` (ask), `plan` (compat), `auto` (classifier auto-review; blocked calls fail in non-interactive sessions),
`bypassPermissions` = **always-approve** (`--always-approve`, alias `--yolo`, `--permission-mode bypassPermissions`,
`_meta.yoloMode: true`), `acceptEdits`, `dontAsk` (deny-by-default), via `.claude/settings.json` `defaultMode` too.
Rules `allow`/`ask`/`deny` with `Bash(...)`, `Edit(...)`, `Write(...)`, `Read(...)`, `Grep(...)`, `WebFetch(domain:…)`, `MCPTool(...)`;
`deny > ask > allow`; remembered per-project grants ("Always allow `cargo test`"); dangerous commands never honor prefixes.
Always-approve still applies `deny` rules and hooks; admins can lock it off. Optional OS sandbox profiles (`--sandbox`).
Plan mode: read-only except `plan.md`; `enter_plan_mode` needs user approval; `exit_plan_mode` presents the plan.

### 3.4 Sessions, usage, subagents [V] (17-sessions.md, 14-headless-mode.md, 16-subagents.md)

- Storage `~/.grok/sessions/<url-encoded-cwd>/<session-id>/`: `summary.json`, **`updates.jsonl` (the ACP `session/update` stream, authoritative for resume)**,
  `chat_history.jsonl`, `plan.json` (todo/task list), `rewind_points.jsonl`, `signals.json`, `compaction_checkpoints/`, `subagents/`.
  Session ids are UUIDv7. Titles auto-generated, frozen after a few turns; `/rename` wins.
- `/rewind` (alias `/undo`) truncates conversation only — "does not restore files on disk".
- Headless `json` result: `{text, stopReason, sessionId, requestId, num_turns, usage:{input_tokens, cache_read_input_tokens, cache_creation_input_tokens, output_tokens, reasoning_tokens, total_tokens}, modelUsage:{"grok-4.6":{inputTokens, outputTokens, cacheReadInputTokens, modelCalls, costUSD}}, total_cost_usd, total_cost_usd_ticks}`; `cost_is_partial`, `usage_is_incomplete` flags.
- `streaming-json` lines: `{"type":"thought","data":…}`, `{"type":"tool_call","toolCallId","title","kind","status","toolName","rawInput","content","locations"}`,
  `{"type":"tool_call_update",…}`, `{"type":"text","data":…}`, `{"type":"usage","messageId","stopReason","usage","signature"}`, `plan`, `available_commands`, `max_turns_reached`, `auto_compact_*`, `{"type":"end",…}`, `{"type":"error","message":…}`.
- Subagents: model calls `spawn_subagent {prompt, description, run_in_background (default true), isolation:"none"|"worktree", resume_from, cwd}`;
  built-in types `general-purpose`, `explore`, `plan` + project/user/plugin agents; background results via `get_command_or_subagent_output`;
  optional `send_subagent_message` with `delivery: steer|queue|interject`. Press: up to 8 parallel subagents.
- Background tasks, `/loop`, `monitor` tool, scheduler (`scheduler_create|list|delete`), agent dashboard.

## 4. Capability mapping (CodeWalk needs → Grok Build)

| Capability | Mechanism | Status |
|---|---|---|
| Network reachability from phone | `grok agent serve` WebSocket + bearer secret; or relay `--grok-ws-url` | **Native** (add TLS/VPN) |
| New / load / list / resume / close | `session/new`, `session/load`, `session/list`, `session/resume`, `session/close` (+ `x.ai/session/list`, `x.ai/sessions/list`, `x.ai/session/search`) | Native |
| History replay | `session/load` replays updates (`updates.jsonl`); `x.ai/session/load_history`, `x.ai/session/updates` | Native |
| Fork / rename / delete | `x.ai/session/fork`, `x.ai/session/rename`, `x.ai/session/delete` | Native (extension) |
| Undo / rewind | `x.ai/rewind` (conversation only; files untouched) | Partial |
| Prompt + streaming text / reasoning | `session/prompt`; `agent_message_chunk`, `agent_thought_chunk` | Native |
| Tool calls / results | `tool_call`, `tool_call_update` (kind, status, rawInput/rawOutput, locations, content incl. diffs) | Native |
| Permission requests | `session/request_permission` (`allow_once`/`allow_always`/`reject_once`/`reject_always`) | Native |
| Global allow-all | `--always-approve` / `_meta.yoloMode` / `session/set_mode` / `x.ai/yolo_mode_changed` | Native |
| Agent questions | `x.ai/ask_user_question` (agent→client ext request) | Native (extension; client must implement) |
| Errors | JSON-RPC errors; `stopReason`; `x.ai/session_notification` retry state | Native |
| Tokens / cost | `_meta.usage` on prompt result; `usage_update`; `x.ai/session/usage`; `grok usage` | Native |
| Quotas / credits | `x.ai/billing` (credits/billing) [shape U] | Partial |
| Interrupt | `session/cancel`; `$/cancel_request` | Native |
| Mid-turn messages (steer/queue) | `x.ai/interject` (+ images), `x.ai/queue/*` | Native (extension) |
| Slash commands | `available_commands_update` / `x.ai/commands/list`; send `/cmd` as prompt text [U for builtins over ACP] | Native/Partial |
| Skills | `x.ai/skills/*`; listed among commands | Native |
| @file mentions / file search | `x.ai/search/fuzzy/open|change` + `x.ai/search/fuzzy/status`; `x.ai/search/content`; ACP `resource_link`/embedded resources in prompt | Native |
| File browse / edit | `x.ai/fs/list|exists|read_file|write_file`, `x.ai/fs/index(/delta)`, `x.ai/fs_notify` | Native (useful for CodeWalk file viewer) |
| Git / diffs / worktrees | `x.ai/git/*`, `x.ai/git/worktree/*` | Native |
| Images | `image` content blocks in `session/prompt` (handled), `x.ai/interject.content` | Native (not advertised) |
| Model selection | `configOptions` `model` + `session/set_config_option` / `session/set_model`; `x.ai/models/list` | Native |
| Agent / mode selection | `session/set_mode` (permission/plan modes), `_meta.agentProfile`, `--agent-profile` | Partial |
| Thinking effort | `configId:"reasoning_effort"` (`minimal…xhigh`) | Native |
| Subagents | `x.ai/subagent/*`; subagent tool calls in stream; child sessions in sessions tree | Native |
| Todo / plan | `plan` session update; `plan.json`; `x.ai/toggle_plan_mode` | Native |
| Terminal / shell | `x.ai/terminal/*`, `x.ai/terminal/pty/input`; ACP client `terminal/*` if client advertises it | Native |
| Compaction | `x.ai/compact_conversation`; auto-compact notifications | Native |
| Multi-client | Agent persists across WS reconnects; `--leader` shared leader | Native |

## 5. Verdict

**Integrable — best surface: ACP over WebSocket via `grok agent serve` (no custom bridge strictly required).**
Recommended deployment: run `grok agent serve --bind 127.0.0.1:2419 --secret <token>` (or `--bind <tailscale-ip>:2419`)
on the host as a user service; CodeWalk connects with `Authorization: Bearer <token>` over Tailscale/WireGuard or
through a TLS reverse proxy (Caddy/Cloudflare Tunnel). Do **not** pass `--always-approve` if CodeWalk should show
approval cards; implement `session/request_permission` and `x.ai/ask_user_question`.

- Effort: **medium** — a Dart ACP v1 client (reusable for Pi via `pi-acp`, DeepSeek Harness, Gemini, Qwen, Kimi,
  Copilot, Cursor, Goose, OpenCode…) plus a Grok-specific layer for the `x.ai/*` extensions CodeWalk wants
  (sessions/fork/rename/delete, rewind, interject, fuzzy search, fs, usage/billing, ask_user_question).
- Risk: **low–medium** — open source and actively maintained (daily releases); `x.ai/*` methods are explicitly
  non-exhaustive and may change across releases; serve uses a single shared secret and plain `ws://`;
  subscription (SuperGrok / X Premium+) or `XAI_API_KEY` required.

## 6. Sources

- https://github.com/xai-org/grok-build (README; `crates/codegen/xai-grok-pager/docs/user-guide/{01,02,14,15,16,17,19,22}*.md`; `crates/codegen/xai-grok-shell/src/agent/server.rs`; `…/agent/mvp_agent/acp_agent.rs`; `…/extensions/interject.rs`; `crates/codegen/xai-grok-pager/src/app/acp_handler/interactions.rs`; `crates/codegen/xai-grok-tools/src/implementations/grok_build/ask_user_question/mod.rs`)
- https://www.npmjs.com/package/@xai-official/grok · https://x.ai/cli/install.sh (arch switch inspected, not executed)
- https://docs.x.ai/build/overview · https://x.ai/news/grok-build-cli · https://en.wikipedia.org/wiki/Grok_Build
- https://pulse2.com/xai-grok-build-launches-early-beta-coding-agent-cli/ · https://innfactory.ai/en/ai-harness/grok-cli/ · https://ai-sdk.dev/providers/ai-sdk-harnesses/grok-build
- https://github.com/agentclientprotocol/registry (`grok-build/agent.json`: `npx @xai-official/grok@1.0.47 agent stdio`) · https://github.com/agentclientprotocol/agent-client-protocol (schema v1 meta.json, schema.json)
