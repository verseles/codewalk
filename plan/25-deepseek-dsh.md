# 25 — DeepSeek Harness (`dsh`) as a CodeWalk harness

Research date: 2026-10-02. Tags: **[V]** = Verified (source cited), **[U]** = Unverified / inferred.
Raw extracts for offline planners: `plan/harness-src/dsh/` (dsh-acp-README.md, dsh-sdk-jsonrpc-server-README.md,
dsh-headless-README.md, dsh-cli-README.md, dsh-web-app-README.md).

## TL;DR

- **Exists and is official DeepSeek** — `deepseek-ai/deepseek-harness` (MIT, homepage deepseek.com/harness),
  npm scope `@deepseek-ai`; first npm rc 2026-08-10, public repo 2026-08-13 [V]; press says it launched
  alongside DeepSeek V4 Pro [secondary sources only].
- **Developer preview**: latest `@deepseek-ai/dsh` **0.2.0-rc.2 (2026-09-29)**; README: "THERE WILL BE
  COMPATIBILITY-BREAKING CHANGES"; SAFETY.md: "has not undergone a security audit". [V]
- Surfaces are **profiles** of one `dsh` launcher: `dsh web` (own browser GUI, HTTP + WebSocket, loopback only),
  `dsh --profile acp` (**standard ACP v1 over stdio, "automation-only"**), `dsh --profile sdk|sdk-minimal`
  (SDK JSON-RPC over stdio; Python/TS clients), `dsh --profile headless` (one-shot, `--json` NDJSON), Electron desktop. [V]
- No network API intended for third-party clients: the Web UI's `/api` + WebSocket protocol is internal to its SPA;
  `dsh web` binds 127.0.0.1 and rejects `--host 0.0.0.0`. [V]
- ACP surface is deliberately thin: **no `session/load` (no history replay), no modes, no slash commands, no plans/todos,
  no terminals, no elicitation, no fork/delete**; permission prompts are one-shot allow/reject. [V]
- Verdict: **Technically integrable via ACP stdio + host bridge (reuse a generic ACP client), but feature-poor and
  unstable → low priority / defer**, or offer its own Web UI through a tunnel as a stopgap. Effort medium, risk high.

## 1. Identity

| Item | Value | Tag |
|---|---|---|
| Vendor | DeepSeek AI (official org `deepseek-ai`; README: "an open-source agent harness developed by DeepSeek AI") | [V] https://github.com/deepseek-ai/deepseek-harness |
| Repo / site / docs | https://github.com/deepseek-ai/deepseek-harness (default branch `master`, created 2026-08-13) · https://deepseek.com/harness · docs https://deepseek-harness.github.io/deepseek-harness/ · Discord / GitHub Discussions | [V] gh API, README |
| License | MIT | [V] |
| Popularity | ~242k GitHub stars (press: ~66k within a day of launch) | [V] gh API; https://composio.dev/content/deepseek-harness-vd-pi-agent |
| Versions | npm `@deepseek-ai/dsh`: first `0.0.1-rc.1` 2026-08-10, `0.1.0-rc.7` 2026-08-17 (used by DataCamp tutorial and an arXiv cost study), **`latest`/`next` = 0.2.0-rc.2 (2026-09-29)**, `alpha` 0.1.7-alpha.2. GitHub prereleases `dsh-v0.2.0-rc.2` … PyPI `deepseek-harness-sdk` 0.1.5rc1 | [V] npm view; gh releases; PyPI JSON |
| Maturity | Developer preview, rapid iteration, explicit breaking changes, persistence-format change log with upgrade guides | [V] README; docs/persistence-changes/ |
| Architecture | "Everything is a plugin", built on the **Cordis** composition framework (paper arXiv 2608.25512); profiles = ordered stacks of plugin bundles + `cordis.patch.yml`; uses **Pi's `pi-ai` model layer / provider catalog** | [V] README; `.agents/notes/archived/architecture/2026-08-03-pi-ai-declared-provider-catalog.md`; Composio |
| Install | `npx @deepseek-ai/dsh web` (Web UI at http://127.0.0.1:3080) · `npm install -g @deepseek-ai/dsh` · from source `pnpm install && pnpm run build && pnpm dsh web` · Python `pip install deepseek-harness-sdk` (bundles a native runtime wheel + `dsh`; no system Node needed) · Desktop (Electron, `apps/desktop`) | [V] README; docs/user/guide/python-sdk.md |
| Platforms | Native packages linux-x64, **linux-arm64**, darwin-x64, darwin-arm64 (static Landlock launcher on Linux); Windows lacks the Landlock launcher/POSIX addon (keeps a Windows semaphore implementation); Python SDK: Linux x64/arm64, macOS 14+ arm64, Windows x64 | [V] native/system/docs/support-matrix.md; python-sdk.md |
| Auth / models | API keys only (no subscription login): `DEEPSEEK_API_KEY` (+ `DEEPSEEK_BASE_URL`), or provider credentials entered in Web UI Settings → Models (credentials YAML); model-agnostic (DeepSeek, Anthropic, OpenAI, Gemini, Bedrock, Vertex, Azure, Codex… via pi-ai). Default ACP route `deepseek-official` / `deepseek-v4-flash` | [V] docs/user/guide/*; acp-app README |
| Features | 53 built-in tools (press), MCP, subagents/agent team, LSP, web search, scheduling, sandboxing (Landlock/Seatbelt), workflows, todo, user questions, voice input, SSH remote-execution provider, GitHub review webhook overlay, run modes Standard / Minimal / Code ("PTC") / Creator | [V] docs/subsystems/*; https://apidog.com/blog/what-is-deepseek-harness/ |

## 2. Programmatic surfaces

| Surface | Command | Official? | Notes |
|---|---|---|---|
| **ACP (automation-only)** | `dsh --profile acp` (stdio; stdout = newline-delimited ACP JSON-RPC frames) | Yes | "intentionally omits DSH-specific presentation data and interactive UI features"; no auth (`authenticate` succeeds immediately) |
| SDK JSON-RPC | `dsh --profile sdk` / `sdk-minimal` (stdio); Python `DeepSeekHarness(...).run(...)`, TS client in `packages/sdk/client` | Yes | Protocol package `dsh-sdk-protocol` [method shapes partially U]; no cancel/close |
| Headless | `dsh --profile headless "task"` (or stdin), `--json` (NDJSON events), `--session-id <id>` | Yes | One-shot |
| Web UI | `dsh web` / `dsh --profile web [--port N] [--trusted-host H] [--no-open]` → authenticated URL with a fresh process token → signed cookie | Yes (GUI) | **Internal** API: `POST /api/<method>` + WebSocket downlink, `POST /api/respond`; not a public contract |
| Desktop | Electron app reusing the web client over IPC | Yes | Not a remote API |
| MCP | Agent-side (stdio + Streamable HTTP via ACP `mcpServers`) | Yes | |

## 3. Protocol detail (verbatim)

### 3.1 ACP profile contract [V] (packages/acp/acp/README.md)

| Call | Behavior |
|---|---|
| `initialize` | "Stable ACP v1 plus `session/list`, `session/resume`, `session/close`, and Streamable HTTP MCP support; image prompts only when the durable attachment store and configured exact route support them." |
| `authenticate` | "Immediate success; the server requires no authentication." |
| `session/new` | "A fresh persistent agent whose absolute workspace and stdio or HTTP MCP servers are validated before publication, plus its complete configuration-option state." |
| `session/list` | "Deterministic newest-first pages of persisted, resumable root sessions; an optional absolute `cwd` filter" (page size config `sessionListPageSize`, default 100) |
| `session/resume` | "A persisted inactive session … its log is restored **without replaying old updates**." |
| `session/close` | Quiescent cancellation, update draining, descendant disposal, persistence flush |
| `session/set_config_option` | `model` or `reasoning_effort`, returns complete resulting state; a prompt pins its route for the whole turn |
| `session/prompt` | "Ordered text, resource links, and supported images, **one prompt at a time per session**" (PNG/JPEG/WebP/GIF) |
| `session/cancel` / `$/cancel_request` | prompt-owned cancellation; without a prompt in flight it cancels autonomous work |
| `session/update` | "Committed assistant messages and thoughts, generic tool lifecycle, configuration changes, and context usage" — **committed** (not token-level) chunks |
| `session/request_permission` | "A permission prompt with one-shot allow/reject choices" |

"Unsupported surfaces are omitted or rejected: `session/load`, deletion, fork, additional directories, SSE or
ACP-transport MCP, modes, commands, plans, terminals, client filesystem operations, and elicitation."
One connection can run several sessions concurrently. Config: `provider`, `model`, `sessionListPageSize`.

ACP v1 names for reference (schema v1): updates `agent_message_chunk`, `agent_thought_chunk`, `tool_call`,
`tool_call_update`, `config_option_update`, `usage_update`; permission option kinds `allow_once`, `reject_once`
(dsh offers only one-shot) [V schema; exact dsh option ids U].

### 3.2 SDK JSON-RPC server [V] (packages/sdk/server/README.md)

- `initialize` stores the SDK route (provider/model, optional `reasoningEffort`, optional `maxTokens`) and returns
  identity `deepseek-harness-sdk-runtime`; it waits for the plugin tree (e.g., MCP discovery) to settle.
- `session/prompt` (rejected until `initialize` completes) queues one identified user message and returns `{ messageId }`
  immediately; the server then streams every durable fact as **`session.event`** and every agent lifecycle transition as
  **`session.status`** notifications. One agent per `sessionId` on first use.
- `shutdown` disposes the runtime and exits 0.
- Limits: "The wire has no per-session close or prompt-cancel method"; "There is no per-prompt result".

### 3.3 Headless `--json` [V] (packages/bundle/headless/README.md)

NDJSON on stdout: opens with `session` (identity), then `status`, `text`, `thinking`, `tool_call`, `tool_result`,
closes with `final` (lossless answer); `error` for runner failures; strings capped at 8 KiB, lines at 32 KiB;
`text`/`thinking` arrive per committed step, not per token. Exit 0 = completed `turn/end`; 1 otherwise.
`--session-id <id>` adopts a persisted session (fails if unknown).

### 3.4 Web UI internal protocol (not public) [V] (`.agents/notes/archived/architecture/2026-07-19-gui-layering-and-rpc-protocol.md`, docs/subsystems/web-server.md, web-app README)

"Four quadrants": `ClientRequest` = `POST /api/<method>` body `{type:"client-request", rpcId, method, payload}`;
`ServerResponse` = that POST's body (always HTTP 200) `{type:"server-response", rpcId, result:{ok:true,value}|{ok:false,error}}`;
`ServerRequest` = WebSocket text message (`session/event`, `approval/requested`, `question/requested`);
`ClientResponse` = `POST /api/respond` → `RpcReceipt {accepted:true}|{accepted:false, reason:"not-pending"|"bad-response"}`.
Auth: process token in the startup URL → signed cookie; Host/Origin checks; `dsh web` "cannot bind all network
interfaces" (`--host 0.0.0.0` rejected); `--trusted-host` adds hosts; over SSH it prints the URL for port forwarding.
Methods are generated from `@Remote` decorators (Typert API gateway) and change freely in the preview.

### 3.5 Approval / safety [V] (docs/subsystems/approval.md, SAFETY.md)

`ApprovalPolicy = 'ask' | 'never'` per session (`never` = deterministic reject — "the strict headless stance");
outcomes `'allowed-once' | 'rejected' | 'cancelled' | 'unavailable'` (fail-closed). Permission presets UI in the
Web client; sandboxing via Landlock (Linux) with documented limitations ("do not guarantee isolation").
The `sdk-minimal` profile pins `danger-full-access`.

## 4. Capability mapping (CodeWalk needs → dsh, best public surface = ACP profile)

| Capability | Mechanism | Status |
|---|---|---|
| Network reachability from phone | stdio only (ACP/SDK) → host bridge; Web UI is loopback/browser-only | **Missing → bridge** |
| New / list / resume / close | `session/new`, `session/list`, `session/resume`, `session/close` | Native |
| History replay on open | Not supported ("without replaying old updates"; no `session/load`) | **Missing** |
| Fork / delete / rename | Unsupported over ACP | Missing |
| Undo / rewind | None over ACP | Missing |
| Prompt + streaming | `session/prompt`; committed `agent_message_chunk` / `agent_thought_chunk` (not token-level) | Partial |
| Tool calls | generic `tool_call` / `tool_call_update` | Native |
| Permission requests | `session/request_permission` (one-shot allow/reject only) | Partial |
| Global allow-all | Not exposed over ACP (policy is `ask`/`never`; profile config) | Missing [U] |
| Agent questions | Web UI only (`question/requested`); ACP omits elicitation | Missing |
| Errors | JSON-RPC errors; stop reasons | Native |
| Tokens / context | `usage_update` / "context usage" updates | Partial |
| Cost / quotas | Not exposed | Missing |
| Interrupt | `session/cancel`, `$/cancel_request` | Native |
| Mid-turn steer / queue | One prompt at a time per session; no steer | Missing |
| Slash commands / skills | Commands unsupported over ACP | Missing |
| @file mentions | `resource_link` blocks ("[resource_link name=… uri=…]" given to the model) | Partial |
| File search | None | Missing |
| Images | Raster images when attachment store + image-capable route | Native (conditional) |
| Model selection | `configOptions` `model` via `session/set_config_option` | Native |
| Thinking effort | `reasoning_effort` config option (model-declared) | Native |
| Subagents | Exist internally; not surfaced as ACP structure | Missing |
| Todo / plan | "plans" unsupported over ACP | Missing |
| Terminal / shell | Unsupported over ACP | Missing |
| MCP per session | `mcpServers` (stdio + Streamable HTTP) in `session/new` | Native |

## 5. Verdict

**Exists and is official, but not a good CodeWalk target yet.** If CodeWalk ships a generic ACP v1 client plus a
host-side stdio→WebSocket bridge (the same one used for other stdio ACP agents), dsh can be added cheaply
(`dsh --profile acp`), yielding chat + tools + one-shot approvals + model/effort switching + session list/resume —
but **no transcript replay on resume**, no slash commands, todos, questions, steer, fork or rewind. Its rich features
(questions, approvals UI, todos, subagents, workflows) live only behind the **internal** Web UI protocol, which is
unstable during the preview and bound to loopback.

- Effort: **low–medium** incremental (given a generic ACP client), **high** for parity (would require targeting the internal web API).
- Risk: **high** (rc releases, explicit breaking changes, no security audit, persistence-format churn).
- Recommendation: defer native integration; optionally document "open dsh Web UI via SSH/Tailscale tunnel" as a
  stopgap; re-evaluate at dsh 1.0 or when the ACP surface gains `session/load`/commands/plans.

## 6. Sources

- https://github.com/deepseek-ai/deepseek-harness — README.md, SAFETY.md, apps/cli/README.md, packages/acp/acp/README.md, packages/bundle/{acp-app,sdk-app,headless,web-app}/README.md, packages/sdk/server/README.md, docs/subsystems/{approval,web-server,ssh}.md, docs/user/guide/{index,python-sdk}.md, native/system/docs/support-matrix.md, `.agents/notes/archived/architecture/2026-07-19-gui-layering-and-rpc-protocol.md`, `2026-08-03-pi-ai-declared-provider-catalog.md`
- https://www.npmjs.com/package/@deepseek-ai/dsh · https://pypi.org/project/deepseek-harness-sdk/
- https://www.datacamp.com/tutorial/deepseek-harness (tested 0.1.0-rc.7; "a developer preview in August 2026") · https://composio.dev/content/deepseek-harness-vd-pi-agent · https://apidog.com/blog/what-is-deepseek-harness/ · https://arxiv.org/pdf/2608.01347 (used "dsh-jsonrpc-agent", 0.1.0rc7)
- Warning from secondary sources: look-alike packages/sites appeared after launch (e.g. deepseekharness.io, open-harness.net are third-party); trust only `deepseek-ai/deepseek-harness` and the `@deepseek-ai` npm scope.
- https://github.com/agentclientprotocol/registry (no dsh entry as of 2026-10-01)
