# 30 — ACP and unifying protocols: evidence dossier

> Research date: **2026-10-02**. Evidence only, no app design.
> Tags: **Verified (src)** means checked against the cited primary source on this date. **Unverified** means a secondary or single source, an inference, or not reproduced.
> Raw extracts saved locally under `plan/acp-src/`. Planners can read them offline:
> - `plan/acp-src/protocol-v1/*.mdx`: ACP v1 docs, verbatim (stable spec text)
> - `plan/acp-src/protocol-v2/*.mdx`: ACP v2 draft docs, including `migration.mdx` (53 KB) and `prompt-lifecycle.mdx`
> - `plan/acp-src/rfds/*.mdx` and `plan/acp-src/rfds/v2/*.mdx`: the RFDs cited below
> - `plan/acp-src/schema/v1/{schema.json,schema.unstable.json,meta*.json}` and `plan/acp-src/schema/v2/...`: the authoritative JSON Schemas. `DIGEST-generated.txt` is a TypeScript-like field digest I generated from them.
> - `plan/acp-src/ecosystem/`: the ACP registry snapshot, codex-acp's "AIR" extension contract, Agmente's agent compatibility matrix, and Reemoat's measured ACP behaviour plus its Grok/Cursor extension shapes
>
> ACP repository snapshot used throughout: `agentclientprotocol/agent-client-protocol` @ `9e032156545412be9bba5e092f12d0080c499b6d` (2026-10-01).
> Base URL for "src" links: `https://github.com/agentclientprotocol/agent-client-protocol/blob/9e032156545412be9bba5e092f12d0080c499b6d/`

---

## 0. TL;DR (facts that matter most)

1. **ACP means the Agent Client Protocol (Zed + JetBrains).** It is JSON-RPC 2.0 between a client (editor/UI) and a coding agent.
   - The **stable line is v1**: schema `schema-v1.24.1`, released 2026-09-30.
   - **v2 is a published Draft**: `schema-v2.0.0-alpha.7`, 2026-09-30; announced 2026-07-20.
   - Verified (src: `schema/v1/CHANGELOG.md`, `schema/v2/CHANGELOG.md`, `gh release list`).
2. **Stable transport is stdio only.** The remote transport ("Streamable HTTP & WebSocket", one `/acp` endpoint) is an **Active RFD** owned by a Transports Working Group (announced 2026-04-22).
   - Reference implementations already exist:
     - Rust crate `agent-client-protocol-http` 2.2.0
     - TypeScript SDK `createHttpStream`/`createWebSocketStream`, experimental
     - Goose `goose serve`
     - `dart_acp_sdk`, experimental
   - **In v1 the remote transport has no message replay after disconnect.** Resumability is deferred to v2.
   - Verified (src: `docs/rfds/streamable-http-websocket-transport.mdx`).
   - **Harness-native remote servers also exist outside the RFD:**
     - Grok Build `grok agent serve --bind … --secret …` (WebSocket ACP, state kept across reconnects; section 2.3)
     - Goose `goose serve` (the RFD's reference implementation)
     - Codex app-server `--listen ws://` (Codex protocol, not ACP)
3. **Agent coverage via the official ACP Registry** (41 agents in the registry JSON on 2026-10-02):
   - **Native ACP:** OpenCode (`opencode acp`), Gemini CLI (`--acp`), GitHub Copilot CLI (`--acp`), Qwen Code, Kimi CLI (`kimi acp`), Goose (`goose acp`), Cursor (`cursor-agent acp`), **Grok Build (`grok agent stdio`)**, Junie, Mistral Vibe, Cline, Factory Droid, Devin, Kilo and others.
   - **Via adapters:** Claude Code (`@agentclientprotocol/claude-agent-acp`, wraps the Claude Agent SDK), Codex (`@agentclientprotocol/codex-acp`, wraps `codex app-server`), and Pi (`pi-acp`, wraps `pi --mode rpc`).
   - Verified (src: registry JSON).
4. **Gaps that real clients fill with extensions:**
   - No rate-limit or quota method.
   - Subagents are in a Draft RFD.
   - Background tasks only exist as a JetBrains "AIR" `_meta` extension.
   - No undo/rewind.
   - No client→agent file listing or search.
   - No push notifications.
   - In v1, no multi-client observation.
   - Extensions are namespaced: `_meta.jetbrains.air`, `_x.ai/*` (Grok), `cursor/*`, `_session/steering`, `_auth/status_update`.
   - Verified (src: codex-acp docs; Reemoat source).
5. **v2 rewrites the parts that matter for a remote/mobile client:**
   - `session/prompt` returns `{messageId}` on insertion. Turn state arrives as `state_update` (`running`/`idle`/`requires_action`).
   - Everything is an upsert by ID.
   - `session/load` is merged into `session/resume` with `replayFrom`.
   - `fs/*` and `terminal/*` client methods are **removed**. The agent owns terminal display instead.
   - Diffs become structured changes plus a `git_patch`.
   - Permission requests get `title`/`subject`.
   - All enums are open (`_`-prefixed extensions).
   - Verified (src: `docs/protocol/v2/migration.mdx`).
6. **Other "unifying" protocols:**
   - **AG-UI** (CopilotKit): agent↔web-UI event stream; not a coding-agent harness protocol.
   - **A2A** (v1.0, now under the Linux Foundation's Agentic AI Foundation): agent↔agent task protocol.
   - **MCP** (spec 2026-07-28, now stateless): the tool layer.
   - **Codex app-server**: OpenAI's own JSON-RPC client protocol for the Codex harness. It has WebSocket mode, is used by all Codex surfaces, and is Codex-specific.

---

## 1. ACP identity, governance, versions

### 1.1 Name disambiguation
- **"ACP" names at least three unrelated protocols:**
  - Zed/JetBrains **Agent Client Protocol** (this document).
  - IBM/BeeAI **Agent Communication Protocol**. Merged into A2A under LF AI & Data in Aug 2025; repository archived 2025-08-27.
  - OpenAI/Stripe **Agentic Commerce Protocol**.
  - Unverified (secondary: [LF AI & Data blog](https://lfaidata.foundation/communityblog/2025/08/29/acp-joins-forces-with-a2a-under-the-linux-foundations-lf-ai-data/), [IBM explainer](https://www.ibm.com/think/topics/agent-communication-protocol)).

### 1.2 Governance
- **Interim model:** *"ACP is jointly governed by Zed and JetBrains … while working toward transitioning to an independent foundation."* Two lead maintainers (BDFL model): Ben Brandt (Zed) and Sergey Ignatov (JetBrains). Core maintainers: Agus Zubiaga, Anna Zhdan, Niko Matsakis, Vadim Briliantov. Verified (src: `docs/community/governance.mdx`, `MAINTAINERS.md`; copies in `plan/acp-src/get-started/`).
- **RFD lifecycle:** Draft → Active → Preview → Completed, or "To be removed". *"final decision is always made by the core team lead"*. Discussion happens on Zulip and in PRs. Verified (src: `docs/rfds/about.mdx`).
- **License:** Apache-2.0. GitHub org `agentclientprotocol`. Repos include `agent-client-protocol`, `typescript-sdk`, `rust-sdk`, `python-sdk`, `kotlin-sdk`, `java-sdk`, `registry`, `claude-agent-acp`, `codex-acp`, and `acp-tck` (a Test Compatibility Kit that drives an agent over stdio). Verified (src: `gh repo list agentclientprotocol`).

### 1.3 Versions and artifacts

| Artifact | Version / date | Status |
|---|---|---|
| JSON Schema v1 (stable) | `schema-v1.24.1`, 2026-09-30 | Verified (gh release) |
| JSON Schema v2 (draft) | `schema-v2.0.0-alpha.7`, 2026-09-30. alpha.1 was 2026-07-20 | Verified |
| Rust crates | Schema types crate `agent-client-protocol-schema` is `1.10.2` (2026-10-01; the spec repo's root CHANGELOG). SDK crate `agent-client-protocol` is `2.2.0` (2026-09-18, from `agentclientprotocol/rust-sdk`); Zed pins `=2.2.0` with features `unstable`, `unstable_protocol_v2`. HTTP transport crate is `agent-client-protocol-http` 2.2.0. | Verified (crates.io API; Zed `Cargo.toml` per subagent report) |
| TS SDK `@agentclientprotocol/sdk` | `v1.6.0`, 2026-10-01. 1.0 was 2026-06-25 | Verified |
| Wire protocol version integer | `protocolVersion: 1` (stable). `2` is draft and must be gated behind feature flags | Verified (src: `docs/announcements/acp-v2-draft.mdx`) |
| Dart (community) | `dart_acp_sdk` 0.1.1 (pub.dev, 2026-07-30; repo `FlutterFlow/dart_acp_project`): v1 stable plus *"explicit experimental v2 and remote entrypoints"*, transports *"In-process, NDJSON, conditional stdio, HTTP/SSE, and WebSocket"*, browser-safe. Others: `acp_dart` 0.5.0 (2026-09-24), `acp` 0.1.0-rc.3, `dart_acp` 0.1.1 (client-only) | Verified (pub.dev API, README) |

- **Release cadence (v1):** schema minors in 2026 included 1.14 (06-18), 1.17 (06-29), 1.18 (07-06), 1.20 (07-21), 1.21 (08-20), 1.22 (09-17), 1.23 (09-18) and 1.24 (09-30). New features usually land as `unstable` first. Verified (src: `schema/v1/CHANGELOG.md`).

---

## 2. Transports, including remote (critical for a phone client)

### 2.1 stdio (the only stable transport)
Verbatim rules (`docs/protocol/v1/transports.mdx`), Verified:
- *"The client launches the agent as a subprocess."*
- *"Messages are delimited by newlines (`\n`), and **MUST NOT** contain embedded newlines."*
- *"The agent **MAY** write UTF-8 strings to its standard error (`stderr`) for logging purposes."*
- *"Agents and clients **MAY** implement additional custom transport mechanisms … **MUST** ensure they preserve the JSON-RPC message format and lifecycle requirements"*
- v2 adds JSON-RPC **batch** arrays on stdio. *"Don't batch lifecycle-sensitive messages (`initialize`, `auth/login`, `session/new`, `session/resume`, `session/prompt`)."* (`protocol/v2/migration.mdx`). Verified.

**Implication (fact, not design):** a phone cannot be the stdio parent of a host agent. Every remote/mobile ACP product found uses a **host-side process** that spawns the stdio agent and re-exposes it (section 2.4).

### 2.2 Remote transport RFD: "Streamable HTTP & WebSocket Transport" (stage: **Active**)
Source: `docs/rfds/streamable-http-websocket-transport.mdx`. Full copy in `plan/acp-src/rfds/`.
- Authors: Alex Hancock and jh-block (Goose/Block). Champion: Anna Zhdan.
- Moved to Active 2026-07-02. Verified.

**Model (verbatim highlights):**
- *"A single `/acp` endpoint supports two connectivity profiles: Streamable HTTP (POST/GET/DELETE) … Requires HTTP/2. WebSocket upgrade (GET with `Upgrade: websocket`)."*
- *"Clients that support remote ACP over HTTP MUST support both Streamable HTTP and WebSocket. This allows servers to support only WebSocket if they choose."*
- *"POST requests return immediately (except initialize)"*: they return `202 Accepted`. The response arrives later on an SSE GET stream, correlated by JSON-RPC `id`. `initialize` returns `200` plus an `Acp-Connection-Id` header.
- **Two kinds of SSE GET stream:**
  - The **connection-scoped stream** (`Acp-Connection-Id`) carries responses to `session/new`/`session/load` and non-session messages.
  - **Session-scoped streams** (`Acp-Connection-Id` + `Acp-Session-Id`) carry `session/update`, `request_permission`, and responses to session POSTs.
- *"Clients MUST accept, store, and return cookies"* (for sticky sessions).
- WebSocket: *"All messages are WebSocket text frames containing JSON-RPC. Binary frames are ignored. On disconnect, the server cleans up the connection and any associated sessions."* The connection ID comes back in the `101` response headers. The client still sends `initialize` first.
- Errors:
  - `415` on wrong POST `Content-Type`; `406` if GET lacks `Accept: text/event-stream`
  - `400` on missing headers; `404` on unknown connection/session
  - `501` for batch (in this RFD revision)
- Auth: *"orthogonal and layered on top via HTTP headers, query parameters, or WebSocket subprotocols. `Acp-Connection-Id` and `Acp-Session-Id` are transport-level identifiers, not auth tokens."*

**Durability (verbatim, important):**
> **v1** … "Sessions survive disconnects … a client can reconnect and resume it via `session/load`." "Reconnect and retry are up to the implementer." "Liveness detection is up to the implementer." "**In-flight messages are not replayed.** There is no message sequencing or stream resumption, so server→client messages emitted while a client was disconnected are not redelivered on reconnect."
> **v2** (planned) … "Message IDs on streamed messages … Stream resumability. SSE `Last-Event-ID`-style resumption … Defined reconnection semantics … Standardized keepalive."

**Example flow** (verbatim excerpt):
```
POST /acp  { method: "initialize", id: 1 }            -> 200 OK, Acp-Connection-Id: <conn_id>
GET  /acp  Acp-Connection-Id; Accept: text/event-stream (connection-scoped SSE)
POST /acp  { method: "session/new", id: 2, params: { cwd, mcpServers } } -> 202
     SSE (connection stream): { id: 2, result: { sessionId: "sess_abc123" } }
GET  /acp  Acp-Connection-Id + Acp-Session-Id: sess_abc123 (session-scoped SSE)
POST /acp  { method: "session/prompt", id: 3, ... } -> 202
     SSE (session stream): AgentMessageChunk, AgentThoughtChunk, ToolCall, ToolCallUpdate, ..., { id: 3, result }
     SSE: { method: "request_permission", id: 99, params: {...} }
POST /acp  { id: 99, result: { outcome: ... } } -> 202
DELETE /acp Acp-Connection-Id -> 202
```

**Comparison with MCP:** the RFD lists its deviations from MCP Streamable HTTP. These include long-lived GET streams instead of per-request SSE, HTTP/2 being required, two headers, WebSocket, cookies, and no batch. Verified (src).
- Separately, the **MCP 2026-07-28** spec *removed* SSE resumability and `Last-Event-ID` from MCP's own transport: *"A broken response stream loses the in-flight request; clients MUST re-issue it"*. Verified ([MCP changelog](https://modelcontextprotocol.io/specification/2026-07-28/changelog)).

### 2.3 Remote transport implementations (status 2026-10-02)

| Implementation | What it does | Evidence |
|---|---|---|
| Rust `agent-client-protocol-http` (rust-sdk) | Server (`AcpHttpServer`, axum router) and client (`HttpClient`, which *"also speaks WebSocket — pass a `ws://` or `wss://` URL"*). 16 MiB POST body limit. CORS off by default. Accepts an initial batch whose first call is `initialize`. Release `agent-client-protocol-http-v2.2.0`, 2026-09-18. | Verified ([md/http-transport.md](https://github.com/agentclientprotocol/rust-sdk/blob/7ae02c50a37d79077ff331667315171731f114c1/md/http-transport.md)) |
| TS SDK (`@agentclientprotocol/sdk`) | `createHttpStream`, `createWebSocketStream`, `createNodeWebSocketUpgradeHandler`. Added in PR #155, 2026-06-17, "Experimental Streamable HTTP & WebSocket Transport". Cookie store reusable across reconnects (`AcpCookieStore`). Docs: *"browsers do not allow custom WebSocket headers. Use cookies or URL-level authentication"*. *"The included Node HTTP server is an HTTP/1.1 compatibility adapter."* | Verified ([src/examples/README.md](https://github.com/agentclientprotocol/typescript-sdk/blob/55dd3744bbd302768e79dc31d0ec77a46d82e60e/src/examples/README.md)) |
| Goose `goose serve` (reference implementation) | Listens on `127.0.0.1:3284` at `/acp`. HTTP auth uses the `X-Secret-Key` header; browser WebSockets use `?token=`. Flags `--dangerously-unauthenticated`, `--allowed-origin`, `--host/--port`. Secret via `GOOSE_SERVER__SECRET_KEY`. Goose Desktop is itself an ACP client over WebSocket to a local `goose serve`. Goose moved to org `aaif-goose`. | Verified ([goose docs](https://goose-docs.ai/docs/gdk/acp/)); history Unverified ([discussion #7309](https://github.com/aaif-goose/goose/discussions/7309)) |
| `dart_acp_sdk` (Dart) | HTTP/SSE and WebSocket transports plus server APIs behind "explicit experimental imports". | Verified (README, [FlutterFlow/dart_acp_project](https://github.com/FlutterFlow/dart_acp_project)) |
| **Grok Build** `grok agent serve` (native, harness-side) | `grok agent [--always-approve] serve --bind 127.0.0.1:2419 --secret <token>`: *"Clients connect over WebSocket and authenticate with the secret token … The process keeps state across client reconnects."* Also `grok agent headless --grok-ws-url wss://relay/ws` (relay) and `--leader` (a shared process; *"A `config_option_update` session notification mirrors it to every subscribed client"*). Endpoint path and how the token is sent are not documented on that page (Unverified). Whether it follows the ACP RFD wire shape is Unverified. | Verified ([xai-org/grok-build `15-agent-mode.md`](https://github.com/xai-org/grok-build/blob/2bdd1d6a6369de0e8c68132ea4539e9abd9e14a8/crates/codegen/xai-grok-pager/docs/user-guide/15-agent-mode.md)) |
| Codex `codex app-server --listen ws://IP:PORT` (not ACP) | Codex's own JSON-RPC over WebSocket. Refuses non-loopback binds without `--ws-auth capability-token\|signed-bearer-token`. Rejects requests with an `Origin` header, so no direct browser use. `/readyz`, `/healthz`. *"experimental and unsupported"*. | Verified (doc 31, section 15.1; CODEX `websocket.rs`) |
| `@rebornix/stdio-to-ws` (used by Agmente iOS) | `npx -y @rebornix/stdio-to-ws --persist --grace-period 604800 "copilot --acp" --port 8765`. Wraps any stdio ACP agent, or `codex app-server`, as a WebSocket. `--persist` keeps the agent alive across client reconnects. | Verified ([Agmente README](https://github.com/rebornix/Agmente)) |
| `aptove/bridge` (Rust) | Spawns a stdio ACP agent and exposes WebSocket. QR pairing, TLS with certificate pinning, Local/Cloudflare/Tailscale modes, **push notifications** ("Wake the mobile app when the agent responds while backgrounded"), keep-alive `AgentPool`. | Verified ([README](https://github.com/aptove/bridge)) |
| `acpremote` (acpkit, Python) | `acpremote expose -- <cmd>` publishes a stdio agent over WebSocket. `acpremote mirror ws://…/acp/ws` turns a remote agent back into local stdio, for clients like Toad. | Verified ([README](https://github.com/vcoderun/acpkit/tree/main/packages/transports/acpremote)) |
| `vacp_bridge` (Intellexie/acp_rpc_bridge) | Spawns an ACP **or Pi RPC** agent. Exposes **ACP Streamable HTTP `/acp`** and an **OpenCode REST API facade** (`/session`, `/event`, `/config/providers`), so an OpenCode-speaking client *"can connect to any supported agent as if it were an OpenCode server"*. Auto-detects ACP vs Pi by probing `initialize`. | Verified ([README](https://github.com/Intellexie/acp_rpc_bridge)) |

### 2.4 How shipping mobile ACP clients bridge the remote gap
Details are in `31-multi-harness-clients.md`.
- **Direct WebSocket to a host bridge:**
  - Agmente (iOS): `stdio-to-ws` plus Cloudflare Tunnel/Access or a bearer token.
  - Ferngeist (Android): its gateway at `127.0.0.1:5788` plus an ngrok/Cloudflare tunnel, or `stdio-to-ws`.
  - Aptove.
- **Relay with E2E encryption:**
  - Reemoat: Noise_IK_25519_ChaChaPoly_BLAKE2s, with the daemon dialing out.
  - Mobvibe: hosted gateway, E2EE.
  - Happy: NaCl/AES-GCM.
- **Relay with TLS only:** Runmote (Flutter app → FastAPI relay → Python daemon).
- **Own host server with HTTP+WS API:** Codeg (`codeg-server`) and OpenChamber, which is OpenCode-only.

Verified (READMEs/sources cited in doc 31).

### 2.5 Other remote patterns: SSH stdio tunnelling (Zed) and the registry auth constraint
- **Zed** runs external ACP agents on the SSH remote host. `RemoteExternalAgentServer::get_command` asks the remote server to resolve or install the agent. `spawn_stdio` wraps the command with `RemoteClient::build_command(..)`, so ACP JSON-RPC flows over the SSH exec channel's stdio. Verified (subagent report: zed @`2a97fbf2` `crates/project/src/agent_server_store.rs` L821-890, `crates/agent_servers/src/acp/transport.rs` L23-75).
- **Registry requirement:** every agent must support "Agent Auth" or "Terminal Auth". Agent Auth *"starts a **local HTTP server** on the user's machine"* and *"opens the user's default browser"*. When the agent is remote, that browser opens on the host.
  - Zed issue [#64391](https://github.com/zed-industries/zed/issues/64391): *"Remote Development: ACP agent OAuth loopback flow fails (needs loopback tunneling or port forwarding)"*.
  - Zed issue [#64511](https://github.com/zed-industries/zed/issues/64511): remote agent commands expose secret env values in the initiating machine's process list.
  - Verified (registry `AUTHENTICATION.md` and Zed issue titles per subagent report).

---

## 3. Method inventory

### 3.1 ACP v1 (from `schema/v1/meta.json` and `meta.unstable.json`), Verified

| Direction | Stable methods | Unstable-only (schema.unstable.json) |
|---|---|---|
| Client → Agent | `initialize`, `authenticate`, `session/new`, `session/load`, `session/set_mode`, `session/set_config_option`, `session/prompt`, `session/cancel` (notification), `session/list`, `session/delete`, `session/resume`, `session/close`, `logout` | `providers/list`, `providers/set`, `providers/disable`, `session/fork`, `mcp/message`, `nes/start\|suggest\|accept\|reject\|close` (NES is "To be removed"), `document/didOpen\|didChange\|didClose\|didSave\|didFocus` |
| Agent → Client | `session/request_permission`, `session/update` (notification), `fs/read_text_file`, `fs/write_text_file`, `terminal/create`, `terminal/output`, `terminal/release`, `terminal/wait_for_exit`, `terminal/kill`, `elicitation/create`, `elicitation/complete` (notification) | `mcp/message` |
| Either | `$/cancel_request` (notification) | — |

- `session/set_model` **was removed** (it was never stabilized): *"Agents should continue to expose model selection through Session Config Options."* (RFD Updates, 2026-06-01). Some agents still implement it: OpenCode's ACP service exports `setSessionModel`, and Agmente's matrix lists it for kimi, mistral-vibe, opencode and claude-code-acp. Verified (src: `docs/rfds/updates.mdx`; [OpenCode `packages/opencode/src/acp/service.ts`](https://github.com/anomalyco/opencode/blob/1ddb0873aee50d209d1a8d7f91b89c5daf692d49/packages/opencode/src/acp/service.ts)).

### 3.2 ACP v2 draft (from `schema/v2/meta.json`), Verified

| Direction | Stable-v2 baseline | Unstable v2 |
|---|---|---|
| Client → Agent | `initialize`, `auth/login`, `session/new`, `session/set_config_option`, `session/prompt`, `session/cancel`, `session/list`, `session/delete`, `session/resume`, `session/close`, `auth/logout` | `providers/*`, `mcp/message`, `session/fork`, `nes/*`, `document/*` |
| Agent → Client | `session/request_permission`, `session/update`, `elicitation/create`, `elicitation/complete` | `mcp/message` |
| Either | `$/cancel_request` | |

Removed in v2: `session/load`, `session/set_mode`, `authenticate` and `logout` (renamed to `auth/*`), all `fs/*`, and all `terminal/*`. Verified (src: `protocol/v2/migration.mdx`, "Method changes" table).

---

## 4. `initialize`, capabilities, auth, errors

### 4.1 v1 initialize (verbatim, `protocol/v1/initialization.mdx`)
```json
{ "jsonrpc": "2.0", "id": 0, "method": "initialize",
  "params": {
    "protocolVersion": 1,
    "clientCapabilities": { "fs": { "readTextFile": true, "writeTextFile": true }, "terminal": true },
    "clientInfo": { "name": "my-client", "title": "My Client", "version": "1.0.0" } } }
```
```json
{ "jsonrpc": "2.0", "id": 0,
  "result": {
    "protocolVersion": 1,
    "agentCapabilities": {
      "loadSession": true,
      "promptCapabilities": { "image": true, "audio": true, "embeddedContext": true },
      "mcpCapabilities": { "http": true, "sse": true } },
    "agentInfo": { "name": "my-agent", "title": "My Agent", "version": "1.0.0" },
    "authMethods": [] } }
```
**Negotiation rules (verbatim):**
- *"If the Agent supports the requested version, it **MUST** respond with the same version. Otherwise … the latest version it supports."*
- *"Clients and Agents **MUST** treat all capabilities omitted in the `initialize` request as **UNSUPPORTED**."*
- *"As a baseline, all Agents **MUST** support `ContentBlock::Text` and `ContentBlock::ResourceLink` in `session/prompt`"*
- *"all Agents **MUST** support `session/new`, `session/prompt`, `session/cancel`, and `session/update`."*

**Capability fields** (generated from `schema.json` / `schema.unstable.json`), Verified:
```
ClientCapabilities (stable)  { fs?: {readTextFile?, writeTextFile?}, terminal?: boolean,
                               session?: { configOptions?: { boolean?: {} } },
                               auth?: { terminal?: boolean }, elicitation?: { form?: {}, url?: {} }, _meta? }
  + unstable: subagents?: {}, plan?, nes?, positionEncodings?, session.compaction?, session.notices?
AgentCapabilities (stable)   { loadSession?: boolean, promptCapabilities?: {image?, audio?, embeddedContext?},
                               mcpCapabilities?: {http?, sse?}, sessionCapabilities?: SessionCapabilities,
                               auth?: { logout?: {} }, _meta? }
  + unstable: providers?, nes?, positionEncoding?
SessionCapabilities (stable) { list?: {}, delete?: {}, additionalDirectories?: {}, resume?: {}, close?: {}, _meta? }
  + unstable: fork?: {}
```

### 4.2 v2 initialize (verbatim, `protocol/v2/migration.mdx`)
```json
{ "jsonrpc": "2.0", "id": 0, "method": "initialize",
  "params": { "protocolVersion": 2, "info": { "name": "my-client", "title": "My Client", "version": "1.0.0" }, "capabilities": {} } }
```
```json
{ "jsonrpc": "2.0", "id": 0,
  "result": { "protocolVersion": 2, "info": { "name": "my-agent", "title": "My Agent", "version": "0.3.0" },
    "capabilities": { "session": { "prompt": { "image": {}, "embeddedContext": {} }, "mcp": { "stdio": {}, "http": {} },
                                   "delete": {}, "additionalDirectories": {} } },
    "authMethods": [] } }
```
- Every support marker is an object, not a boolean. *"advertising `capabilities.session` at all now **requires** supporting … `session/new`, `session/list`, `session/resume`, `session/close`, `session/prompt`, `session/cancel`, and `session/update`."*
- *"Stable v2 currently defines no standard Client capability fields."*
- Verified.

### 4.3 Authentication
**v1 auth method types:**
- `agent`, the default. Client calls `authenticate {methodId}`.
- `terminal`: *"tells the Client to run the configured Agent program interactively"* with extra `args`/`env`, then reconnect. Needs `clientCapabilities.auth.terminal: true`.
- `logout` is gated by `agentCapabilities.auth.logout`.
- Verified (src: `protocol/v1/authentication.mdx`, verbatim example below).

```json
{ "id": "terminal-login", "name": "Log in from the terminal", "type": "terminal",
  "args": ["--login"], "env": { "ACP_INTERACTIVE_LOGIN": "1" } }
```
- Error `-32000` is *Authentication required*.
- v2 renames: `auth/login {methodId}`, `auth/logout`, descriptor `methodId` plus a required `type`.
- Draft RFD `get-auth-state` proposes `auth/status`. codex-acp already pushes the extension `_auth/status_update`.
- Verified (src; [codex-acp docs](https://github.com/agentclientprotocol/codex-acp/blob/main/docs/air-extensions.md)).
- **Remote caveat:** terminal auth assumes the client can launch the agent binary locally. Reemoat drives vendor logins over a PTY and HTTP on the host instead (`claude auth login`, `codex login --device-auth`, `grok login --device-auth`), and never calls ACP authenticate (its Q6.20). Verified (src: `reemoat/src/acp/agents.ts`; excerpt in `plan/acp-src/ecosystem/`).

### 4.4 Errors (`ErrorCode` in `schema.json`), Verified
`-32700` Parse error, `-32600` Invalid request, `-32601` Method not found, `-32602` Invalid params, `-32603` Internal error, `-32800` Request cancelled, `-32000` Authentication required, `-32002` Resource not found, plus "Other". The docs page `error.mdx` says *"Documentation coming soon"*.

### 4.5 Cancellation
- `$/cancel_request {id}` was stabilized 2026-06-29. Either side may send it; the receiver MUST answer the original request, with a result or `-32800`.
- `session/cancel {sessionId}` is a notification. The client SHOULD mark pending tool calls `cancelled` and MUST answer pending `request_permission` with `{"outcome":"cancelled"}`. The agent MUST end the turn with `stopReason: "cancelled"` (v1), or with an idle `state_update` carrying `cancelled` (v2).
- Verified (src: `protocol/v1/cancellation.mdx`, `prompt-turn.mdx`).

---

## 5. Sessions

| Method | Request (verbatim fields) | Response | Gate |
|---|---|---|---|
| `session/new` | `{cwd (absolute), additionalDirectories?, mcpServers: McpServer[] (required in v1, optional in v2)}` | `{sessionId, modes?, configOptions?}`. v2 adds `availableCommands?` and drops `modes`. | baseline |
| `session/load` (v1) | `{sessionId, cwd, additionalDirectories?, mcpServers}` | Agent *"MUST replay the entire conversation … `session/update`"* and then returns `{}` | `loadSession: true` |
| `session/resume` | `{sessionId, cwd, additionalDirectories?, mcpServers?}`. v2 adds `replayFrom?: {type:"start"}` | `{}` (*"MUST NOT replay"* in v1) | `sessionCapabilities.resume` (v1); baseline (v2) |
| `session/close` | `{sessionId}` | `{}`. *"MUST cancel any ongoing work … then free the resources"* | `sessionCapabilities.close` (v1) |
| `session/list` | `{cwd?, cursor?}` | `{sessions: SessionInfo[], nextCursor?}` | `sessionCapabilities.list` (v1); baseline (v2) |
| `session/delete` | `{sessionId}` | `{}` | `sessionCapabilities.delete` |
| `session/fork` (unstable) | `{sessionId, cwd, additionalDirectories?, mcpServers?}` | `{sessionId, configOptions?, availableCommands?}` | `sessionCapabilities.fork` |

**`SessionInfo`** (verbatim example from `session-list.mdx`):
```json
{ "sessionId": "sess_abc123def456", "cwd": "/home/user/project",
  "title": "Implement session list API", "updatedAt": "2025-10-29T14:22:15Z",
  "_meta": { "messageCount": 12, "hasErrors": false } }
```
- Pagination is an opaque cursor. *"Clients **MUST** treat cursors as opaque tokens — do not parse, modify, or persist them"*.
- `session_info_update` patches `title`/`updatedAt`/`_meta`; `null` clears.
- MCP server config types: stdio `{name, command, args, env}`, which every agent must support; `{type:"http", name, url, headers}`; and `{type:"sse"}`, deprecated in v1 and removed in v2.
- v2 requires `type` on every config. The unstable MCP-over-ACP draft adds `{type:"acp", name, serverId}`, so a client can provide tools over the same ACP connection.
- Verified (src).

**Field evidence on session listing and resume** (Runmote daemon source; [Runmote `src/daemon/main.py`](https://github.com/Raza-learner/Runmote/blob/e21841f1db4d8e59020a5dac828da23d845aefce/src/daemon/main.py), comments):
- *"Some agents advertise session/list but never answer it (opencode's ACP silently drops the request)"*. The daemon therefore merges the agent's answer with sessions read from on-disk stores (`session_sources.py`). Verified (src comment). Whether current OpenCode still behaves this way is Unverified.
- *"session/close — some agents (cursor, copilot) don't implement it."* Verified (src comment).
- `session/resume` failures: *"-32603, e.g. codex's 'no rollout found'"*. Verified (src comment).
- Cursor needs `authenticate` before `session/new`, otherwise "Authentication required". Verified (src comment).

---

## 6. Prompt turn (v1) and prompt lifecycle (v2)

### 6.1 `session/prompt` and content blocks (v1, verbatim)
```json
{ "jsonrpc": "2.0", "id": 2, "method": "session/prompt",
  "params": { "sessionId": "sess_abc123def456",
    "prompt": [ { "type": "text", "text": "Can you analyze this code for potential issues?" },
                { "type": "resource", "resource": { "uri": "file:///home/user/project/main.py",
                    "mimeType": "text/x-python", "text": "def process_data(items):\n ..." } } ] } }
```
`ContentBlock` (same shapes as MCP; Verified, `protocol/v1/content.mdx`):

| type | fields | capability |
|---|---|---|
| `text` | `text`, `annotations?` | baseline |
| `image` | `data` (base64), `mimeType`, `uri?` | `promptCapabilities.image` |
| `audio` | `data` (base64), `mimeType` | `promptCapabilities.audio` |
| `resource` | `resource: {uri, text, mimeType?} \| {uri, blob(base64), mimeType?}` | `promptCapabilities.embeddedContext` (*"preferred way to include context … @-mentions"*) |
| `resource_link` | `uri`, `name`, `mimeType?`, `title?`, `description?`, `size?` | baseline. v2 adds `icons?` |

- Slash commands are plain text in the prompt (`"/web agent client protocol"`).
- **Stop reasons:** `end_turn`, `max_tokens`, `max_turn_requests`, `refusal`, `cancelled`. v2 makes the enum open.
- v1 response: `{ "stopReason": "end_turn" }`. Unstable v1/v2 adds `usage?: {totalTokens, inputTokens, outputTokens, thoughtTokens?, cachedReadTokens?, cachedWriteTokens?}` (Draft RFD "End-Turn Token Usage").
- Verified (src: schema unstable).

### 6.2 v2 prompt lifecycle (Draft; verbatim from `protocol/v2/migration.mdx`)

| Foreground signal | v1 | v2 |
|---|---|---|
| Prompt inserted | Implicit | `session/prompt` response with `messageId` |
| User message in history | Implicit (the request itself) | `user_message` update with agent-owned `messageId` |
| Foreground work running | `session/prompt` still pending | `state_update` with `state: "running"` |
| Foreground work waiting | Implicit (pending permission request) | `state_update` with `state: "requires_action"` |
| Foreground work ended | `session/prompt` response with `stopReason` | `state_update` with `state: "idle"` and `stopReason` |
| Cancellation confirmed | Prompt response with `stopReason: "cancelled"` | Idle `state_update` with `stopReason: "cancelled"` |

```json
{ "jsonrpc": "2.0", "id": 2, "result": { "messageId": "msg_user_8f7a1" } }
{ "jsonrpc": "2.0", "method": "session/update", "params": { "sessionId": "sess_abc123",
  "update": { "sessionUpdate": "state_update", "state": "idle", "stopReason": "end_turn" } } }
```
- *"Background activity can continue and emit other `session/update` notifications while the Agent reports `idle`."*
- *"the same message flow works for history replay on `session/resume`, multiple clients observing one session, and future agent-initiated or queued work."*
- *"A lost prompt response remains ambiguous … retrying is not automatically safe."*
- Verified.

---

## 7. `session/update` variants (complete catalogue)

Envelope (verbatim): `{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"…","update":{"sessionUpdate":"<variant>", …}}}`

| `sessionUpdate` | v1 stable | v1 unstable | v2 stable | v2 unstable | Payload |
|---|---|---|---|---|---|
| `user_message_chunk` / `agent_message_chunk` / `agent_thought_chunk` | ✓ | ✓ | ✓ (`messageId` required) | ✓ | `{content: ContentBlock, messageId?}` |
| `user_message` / `agent_message` / `agent_thought` | | | ✓ | ✓ | whole-message upsert `{messageId, content?: ContentBlock[]}` |
| `tool_call` | ✓ | ✓ | removed | | `ToolCall` |
| `tool_call_update` | ✓ | ✓ | ✓ (creates on first id) | ✓ | `ToolCallUpdate` |
| `tool_call_content_chunk` | | | ✓ | ✓ | `{toolCallId, content: ToolCallContent}` (append) |
| `terminal_update` / `terminal_output_chunk` | | | ✓ | ✓ | agent-owned display terminal (base64 bytes) |
| `plan` | ✓ | ✓ | removed | | `{entries: PlanEntry[]}` (full replace) |
| `plan_update` / `plan_removed` | | ✓ (draft) | `plan_update` ✓ | ✓ | `{plan:{type:"items", planId, entries}}` / `{planId}` |
| `available_commands_update` | ✓ | ✓ | ✓ (`input.type` required) | ✓ | `{availableCommands: [{name, description, input?}]}` |
| `current_mode_update` | ✓ | ✓ | removed | | `{currentModeId}` |
| `config_option_update` | ✓ | ✓ | ✓ | ✓ | `{configOptions: [...]}` (complete state) |
| `session_info_update` | ✓ | ✓ | ✓ | ✓ | `{title?, updatedAt?, _meta?}` |
| `usage_update` | ✓ (stabilized 2026-06-05) | ✓ | ✓ | ✓ | `{used, size, cost?: {amount, currency}}` |
| `state_update` | | | ✓ | ✓ | `{state: running\|idle\|requires_action, stopReason?}` |
| `notice` | | ✓ (Preview) | | ✓ | `{severity: info\|warning\|error, title, description?}` |
| `compaction_update` / `compaction_summary_chunk` | | ✓ (Preview) | | ✓ | `{compactionId, status: in_progress\|completed\|failed\|cancelled, summary?, error?}` |
| `subagent_update` | | ✓ (Draft) | | ✓ | `{sessionId (child), title?, description?, capabilities?: {cancel?}, state?}` |
| `session_message` / `session_message_chunk` | | ✓ (Draft) | | ✓ | inter-session messages `{messageId, senderSessionId?, recipientSessionId?, content}` |

Verified (generated from `schema/v1/schema*.json`, `schema/v2/schema*.json`; see `DIGEST-generated.txt`).

**Usage update (verbatim example):**
```json
{ "sessionUpdate": "usage_update", "used": 53000, "size": 200000, "cost": { "amount": 0.045, "currency": "USD" } }
```
- *"`used` and `size` are required … token counts for the current session context. `cost` is optional"* (ISO 4217 currency).
- Measured: with claude-agent-acp, `usage_update` *"fires on essentially every output token"*. It carries context occupancy, which is different from per-turn `Usage` counts. Verified (Reemoat DECISIONS Q6.9, measured 2026-07-31 against claude-agent-acp 0.63.0).

**Message IDs:**
- v1: optional on chunks (stabilized 2026-06-05). *"Chunks with the same `messageId` belong to the same message; a changed `messageId` indicates a new message."*
- v2: required, plus whole-message upserts. Rules: *"Omitted `content` leaves existing content unchanged … `content: null` or `content: []` clears … A concrete array replaces"*; chunks append.
- Verified.

---

## 8. Tool calls

### 8.1 v1 shapes (verbatim, `protocol/v1/tool-calls.mdx`)
```json
{ "sessionUpdate": "tool_call", "toolCallId": "call_001", "name": "read_file",
  "title": "Reading configuration file", "kind": "read", "status": "pending" }
```
```
ToolCall { toolCallId; title; name?; kind?: ToolKind; status?: ToolCallStatus;
           content?: ToolCallContent[]; locations?: {path, line?}[]; rawInput?: any; rawOutput?: any; _meta? }
ToolCallUpdate { toolCallId; (every other field optional; only changed fields) }
ToolKind = read | edit | delete | move | search | execute | think | fetch | switch_mode | other
ToolCallStatus = pending | in_progress | completed | failed          (v2 adds cancelled; open enum)
ToolCallContent = {type:"content", content: ContentBlock}
                | {type:"diff", path, oldText?: string|null, newText}
                | {type:"terminal", terminalId}
```
- `name` was stabilized 2026-09-17. *"Names are opaque, informational metadata: they do not advertise a capability or grant authorization."*
- `locations` enable *"follow-along"*.
- *"When a terminal is embedded in a tool call, the Client displays live output as it's generated and continues to display it even after the terminal is released."*
- Verified.

### 8.2 v2 changes (verbatim, `migration.mdx`)
- **One upsert:** *"The first update with an unseen `toolCallId` creates the tool call."* `tool_call_content_chunk` appends one content item.
- **Structured diffs:**
```json
{ "type": "diff",
  "changes": [ { "operation": "modify", "path": "/home/user/project/src/config.json", "fileType": "text", "mimeType": "application/json" } ],
  "patch": { "format": "git_patch", "text": "diff --git ... @@ -1,3 +1,3 @@\n {\n-  \"debug\": false\n+  \"debug\": true\n }\n" } }
```
  - Operations: `add|delete|modify` (with `path`) and `move|copy` (with `oldPath`, `path`).
  - `fileType`: `text|binary|directory|symlink`.
  - *"There is no mechanical mapping from v2 diffs back to `oldText`/`newText`."*
- **Agent-owned terminal display:**
```json
{ "sessionUpdate": "terminal_update", "terminalId": "term_001", "command": "cargo test", "cwd": "/workspace/project",
  "output": { "data": "cnVubmluZyAxMjMgdGVzdHMNCg==" }, "exitStatus": { "exitCode": 0, "signal": null } }
{ "sessionUpdate": "terminal_output_chunk", "terminalId": "term_001", "data": "cGFzc2VkDQo=" }
```
  - *"Each chunk's `data` is independently base64-encoded … Chunk boundaries may split UTF-8 code points and ANSI escape sequences … The surface is display-only: it has no input, resize, interrupt, kill, wait, release, or execution semantics."*

### 8.3 Measured adapter behaviour (Reemoat DECISIONS, Verified source; measured by them)
- **One `echo` produces five notifications,** and *"every useful field lands on a different one"*: title and `rawInput` appear on later updates, and output appears on the completing update wrapped in a markdown fence (claude-agent-acp 0.63.0).
- **Streamed tool arguments:** one `Write` produced *"715 `tool_call_update`s whose single content block grew from `{` to the finished input JSON"*. Superseded draft blocks were *"15.4% of all events and 55.8% of all bytes"*.
- **Subagent lineage:** the spawn is `tool_call` `kind:"think"` with `_meta.claudeCode.subagent === true`. Children carry `_meta.claudeCode.parentToolUseId`, but *"4 of 10 and 5 of 14 of a child's updates omit the parent"*.
- **kimi:** command text appears only in the permission request's content block (`"Requesting approval to Running: echo hello"`), with `rawInput: null`.
- **`available_commands_update`** arrives *"Always outside a turn"* (it is scheduled after the `session/new` response).
- Raw text: `plan/acp-src/ecosystem/reemoat-decisions-acp-measured-excerpt.md`.

---

## 9. Permissions

### 9.1 v1 `session/request_permission` (verbatim)
```json
{ "jsonrpc": "2.0", "id": 5, "method": "session/request_permission",
  "params": { "sessionId": "sess_abc123def456", "toolCall": { "toolCallId": "call_001" },
    "options": [ { "optionId": "allow-once", "name": "Allow once", "kind": "allow_once" },
                 { "optionId": "reject-once", "name": "Reject", "kind": "reject_once" } ] } }
```
```json
{ "jsonrpc": "2.0", "id": 5, "result": { "outcome": { "outcome": "selected", "optionId": "allow-once" } } }
{ "jsonrpc": "2.0", "id": 5, "result": { "outcome": { "outcome": "cancelled" } } }
```
- `PermissionOptionKind = allow_once | allow_always | reject_once | reject_always`. These are *"A hint to help Clients choose appropriate icons and UI treatment"*. The agent supplies the labels.
- *"Clients **MAY** automatically allow or reject permission requests according to the user settings."* "Allow all" or YOLO is therefore a client-side policy, or an agent mode or config option, not a protocol primitive.
- Example of an agent-side YOLO toggle (boolean config option, verbatim): `{ "id": "brave_mode", "name": "Brave Mode", "description": "Skip confirmation prompts and act autonomously", "type": "boolean", "currentValue": true }`.
- codex-acp exposes modes `read-only`, `workspace-write`, `agent` and `agent-full-access` (env `INITIAL_AGENT_MODE`).
- Exit-plan-mode pattern (verbatim, `session-modes.mdx`): a `switch_mode` tool call with options `"Yes, and auto-accept all actions"` (`allow_always`), `"Yes, and manually accept actions"` (`allow_once`), and `"No, stay in architect mode"` (`reject_once`).
- Verified.

### 9.2 v2 permission request (verbatim)
```json
{ "jsonrpc": "2.0", "id": 5, "method": "session/request_permission",
  "params": { "sessionId": "sess_abc123", "title": "Run this script?",
    "description": "The agent wants to execute scripts/setup.sh in your project.",
    "subject": { "type": "tool_call", "toolCall": { "toolCallId": "call_001", "title": "Execute setup script", "kind": "execute", "status": "pending" } },
    "options": [ { "optionId": "allow", "name": "Allow once", "kind": "allow_once" },
                 { "optionId": "deny", "name": "Deny", "kind": "reject_once" } ] } }
```
- Command subject: `{ "type": "command", "command": "cargo test", "cwd": "/workspace/project", "toolCallId": "call_001", "terminalId": "term_001" }`.
- *"an Agent that receives an outcome it does not understand **MUST NOT** treat it as approval."*
- While a request is pending, the agent SHOULD report `state_update` `requires_action`.
- Verified.

### 9.3 Extensions seen in the wild (Verified, source)
- **JetBrains AIR permission presentation:** `_meta.jetbrains.air.permission = {version:1, title, description?}` on the request and on options. Source: [codex-acp `docs/air-extensions.md`](https://github.com/agentclientprotocol/codex-acp/blob/main/docs/air-extensions.md).
- `is_mcp_tool_approval: true` in `_meta` marks MCP tool approvals.
- **Grok Build sends its own client-bound requests** that ACP has no method for: `_x.ai/ask_user_question`, `_x.ai/exit_plan_mode`, `_x.ai/mcp/elicit`, and `_x.ai/session_notification`. Measured on grok 1.0.40 (Reemoat [`src/acp/xai.ts`](https://github.com/rends-east/reemoat/blob/568beecb2e4ff3acff1be75690f68af462b6a483/src/acp/xai.ts)).
- **Cursor** sends `cursor/ask_question`, `cursor/create_plan`, `cursor/update_todos`, `cursor/task` and `cursor/generate_image`, plus updates `subagent_spawned`/`subagent_state_update` that sit outside the SDK union (Reemoat `src/acp/cursor.ts`).

---

## 10. Plans, commands, modes, config options

- **Plan (v1, verbatim):** `{"sessionUpdate":"plan","entries":[{"content":"Check for syntax errors","priority":"high","status":"pending"}]}`.
  - Priorities: `high|medium|low`. Status: `pending|in_progress|completed`.
  - *"The Agent **MUST** send a complete list … The Client **MUST** replace the current plan completely."*
  - v2: `plan_update {plan:{type:"items", planId, entries}}`. Draft adds markdown/file plans and `plan_removed`.
  - Measured: one Claude `TodoWrite` emits *"9 events for a 3-item list"* (Reemoat Q6.6).
- **Slash commands (verbatim):** `{"sessionUpdate":"available_commands_update","availableCommands":[{"name":"web","description":"Search the web for information","input":{"hint":"query to search for"}}]}`. v2 input is `{type:"text", hint}`. Commands run as prompt text.
- **Modes (v1, legacy):**
  - `modes: {currentModeId, availableModes:[{id,name,description?}]}`, `session/set_mode {sessionId, modeId}`, `current_mode_update`.
  - *"Dedicated session mode methods will be removed in a future version"*. They are removed in v2.
- **Session config options** (preferred; stabilized). Verbatim example:
```json
{ "id": "model", "name": "Model", "category": "model", "type": "select", "currentValue": "model-1",
  "options": [ { "value": "model-1", "name": "Model 1", "description": "The fastest model" },
               { "value": "model-2", "name": "Model 2", "description": "The most powerful model" } ] }
```
  - Categories: `mode`, `model`, `model_config`, `thought_level`, or `_custom`.
  - Types: `select` (flat or grouped `{group, name, options}`) and `boolean` (client must advertise `session.configOptions.boolean: {}`).
  - `session/set_config_option {sessionId, configId, value}` (v1). v2 uses `{sessionId, configId, type:"id"|"boolean", value}`. The response returns the **complete** option list.
  - Agent-initiated changes come as `config_option_update`, e.g. *"Falling back to a different model due to rate limits"*.
  - v2 renames `id`→`configId` and `group`→`groupId`.
  - Verified.

---

## 11. Client file system and terminal (v1 only; removed in v2)

- **`fs/read_text_file`** `{sessionId, path, line?, limit?}` → `{content}`. **`fs/write_text_file`** `{sessionId, path, content}` → `{}`. These are agent→client calls for *"unsaved editor state"*.
- **`terminal/create`** `{sessionId, command, args?, env?, cwd?, outputByteLimit?}` → `{terminalId}`.
- **`terminal/output`** → `{output, truncated, exitStatus?: {exitCode, signal}}`.
- **`terminal/wait_for_exit`**, **`terminal/kill`**, and **`terminal/release`** (the agent MUST call release).
- v2 rationale (verbatim): *"In practice this surface was inconsistently implemented outside of a few IDEs … Clients that want to expose file access, unsaved editor state, or command execution to agents should do so by providing an **MCP server**"*.
- Measured: *"kimi made five reverse-RPC calls with `fs` enabled and none with it disabled; claude never used it either way"* (Reemoat Q5.38, 2026-07-30).
- **Implication (fact):** these are agent→client capabilities. In a host-daemon architecture the daemon, not the phone, would answer them.
- Verified.

---

## 12. Elicitation (stabilized 2026-07-22)
- Based on MCP elicitation.
- **Form mode:** `{sessionId|requestId, toolCallId?, mode:"form", message, requestedSchema}`. A flat JSON Schema of primitives and enums. *"Form mode **MUST NOT** be used to request secrets"*.
- **URL mode:** `{mode:"url", elicitationId, url, message}` plus `elicitation/complete`.
- Responses: `accept` (+`content`), `decline`, or `cancel`.
- The client advertises `elicitation: {form?: {}, url?: {}}`; *"Unlike MCP, ACP does not treat `{}` as form support."*
- Verified (src: `protocol/v1/elicitation.mdx`).
- In practice, Grok and Cursor still use vendor methods for "ask user question" (section 9.3). codex-acp maps Codex `request_user_input` into elicitation schemas, adding `_meta._askUserQuestionCustomAnswer`. Verified (codex-acp AIR doc table).

---

## 13. Extensibility (how vendors fill gaps)

Verbatim rules (`protocol/v1/extensibility.mdx`):
- `_meta: {[key]: unknown}` on most types. Root keys `traceparent`, `tracestate` and `baggage` are reserved for W3C trace context. *"Implementations **MUST NOT** add any custom fields at the root of a type that's part of the specification."*
- *"The protocol reserves any method name starting with an underscore (`_`) for custom extensions"* (requests and notifications). Unknown requests get `-32601`; *"implementations **SHOULD** ignore unrecognized notifications."*
- Advertising: `agentCapabilities._meta: { "zed.dev": { "workspace": true, "fileNotifications": true } }`.
- v2: *"Every enum-like string accepts unknown values. Values beginning with `_` are reserved for implementation-specific extensions … Receivers **SHOULD** preserve unknown values"*.

**Extension namespaces observed** (Verified, source):

| Namespace / method | Owner | Purpose |
|---|---|---|
| `_meta.jetbrains.air.*`, negotiated via `clientCapabilities._meta.jetbrains.air = {version:1, capabilities:[…]}` | JetBrains AIR client; implemented by codex-acp and claude-agent-acp | `diffPatch`, `rawInputRendering`, `planContentDelta`, `recommendedValue`, `asyncTasks`, `agentFileChangeReport`, `sessionFailure`, `nativeSubagentSessions`, `goal` (`_session/goal`) |
| `_session/async_task/stop`, updates `async_task_spawned` / `async_task_progress` / `async_task_state_update` | codex-acp (AIR) | Background shell tasks. States: `running\|paused\|completed\|failed\|stopped` |
| `_meta.steering = {supported:true}` + `_session/steering` | JetBrains shared key; codex-acp | Inject input into a running turn |
| `PromptResponse._meta.quota = {token_count, model_usage[]}` | JetBrains shared key; codex-acp | Per-turn token usage. The doc says "Token usage and rate limits of the turn", but the codex-acp source sends token counts only. codex-acp tracks Codex `account/rateLimits/updated` internally (Unverified where it surfaces). |
| `_auth/status_update` (push) | codex-acp | Account status changes |
| `_meta.terminal_output`, `_meta.terminal_info`, `_meta.terminal_exit`, `_meta.terminal_output_delta` | Zed and JetBrains conventions | Streaming terminal output inside tool calls without the v1 `terminal/*` round trips |
| `clientCapabilities._meta["terminal-auth"]`, `_meta["subagent-transcript"]` | Zed convention; claude-agent-acp | Terminal login; flattened subagent transcript |
| `_meta.claudeCode.{subagent, parentToolUseId}` | claude-agent-acp | Subagent lineage (legacy, pre-RFD) |
| `_session/rewind_points`, `_session/rewind {sessionId, messageId, mode?: files\|conversation\|both, dryRun?}` | claude-agent-acp **PR #966** (proposal) | Undo/rewind. Unverified (PR status not checked) |
| `_x.ai/*`, `cursor/*` | Grok Build, Cursor | Questions, plan approvals, todos, subagents |
| `opencode/session/child_update` (notification), `_meta["opencode/child-session-updates"]`, `_meta["opencode/retry"]` | OpenCode 2.x ACP | Child/subagent session streams with depth and status; retry status. Pre-RFD and not `_`-prefixed. |

---

## 14. Draft and unstable RFDs relevant to a rich remote client

| RFD | Stage (docs.json, 2026-10-01) | Gist (verbatim where quoted) |
|---|---|---|
| Streamable HTTP & WebSocket Transport | **Active** | Section 2.2 |
| v2: prompt, enum-variant-extension, client-filesystem-terminal-capabilities, plan-variants, tool-call-updates, message-updates, permission-requests, required-session-methods, session-resume-replay, diff-file-states, terminal-output | **Active (v2)** | Section 16 |
| Subagent Sessions (#1992) | **Draft** (schema added in 1.24.0, 2026-09-30) | *"Each subagent is represented by its own ACP session ID … associates a reusable child session with its parent through an upsert-style `subagent_update`."* Client opts in with `clientCapabilities.subagents: {}` (v1). Children are observe-only except advertised `cancel`. *"Clients **MUST NOT** call `session/load` or `session/resume` on a child"*. Work states: `running`, `requires_action`, `idle`, `unknown`. Replay of child history is best-effort. Implemented early by codex-acp and claude-agent-acp behind negotiation (Verified, READMEs). |
| Session Compaction | **Preview** | `compaction_update`/`compaction_summary_chunk` |
| Session Notices | **Preview** | *"fire-and-forget `notice` … advisory information … without becoming conversation history"*. v1 landed in Zed, the Claude Agent adapter and the Codex adapter. |
| Session fork | Draft | `session/fork`. *"forking may accept a messageId for checkpoints"* (fork-at-message PR #629 discussion). |
| Plan Operations | Draft | multiple plans, markdown/file plans, `plan_removed` |
| End-Turn Token Usage | Draft | `PromptResponse.usage` (unstable) |
| Agent Authentication State Query | Draft | `auth/status` |
| Configurable LLM Providers | Draft | `providers/list\|set\|disable` |
| MCP-over-ACP | Draft | `{type:"acp", serverId}` MCP servers carried as `mcp/message` (targets MCP 2026-07-28) |
| Agent Extensions via ACP Proxies | Draft | composable proxies between client and agent |
| Next Edit Suggestions | **To be removed** (2026-09-30) | — |
| Completed (stable) | | session config options, session info update, session list, ACP agent registry, session resume, session close, logout, additional directories, `_meta` propagation, session delete, session usage, message id, model_config category, Rust SDK v1, request cancellation, boolean config option, elicitation, auth methods (terminal), tool call name |

Verified (src: `docs/docs.json` navigation groups; `docs/rfds/updates.mdx`).

**Removed RFD worth knowing:** "Agent Telemetry Export … relied on clients injecting OpenTelemetry environment variables when launching agent subprocesses, which doesn't translate to the new remote transports where agents aren't launched by the client." (2026-07-02). Verified.

---

## 15. Agent support matrix (status 2026-10-02)

Sources:
- ACP Registry JSON: `https://cdn.agentclientprotocol.com/registry/v1/latest/registry.json`, snapshot in `plan/acp-src/ecosystem/acp-registry-2026-10-02.json`; 41 agents, `version: 1.0.0`.
- Docs page `get-started/agents.mdx`.
- Vendor docs as linked.
- All rows are Verified against the registry unless marked otherwise.

| Harness | ACP mode | Launch (registry) | Notes |
|---|---|---|---|
| **OpenCode** | Native | `opencode acp` (binary, v1.18.34; repo now `anomalyco/opencode`) | Advertises `loadSession`, `sessionCapabilities {close, fork, list, resume}`, image and embeddedContext, MCP http+sse. Emits `usage_update`, `config_option_update`, `available_commands_update`. Hides `subagent`-mode agents from modes. Internally calls its own server through `@opencode-ai/sdk/v2`. Verified ([service.ts](https://github.com/anomalyco/opencode/blob/1ddb0873aee50d209d1a8d7f91b89c5daf692d49/packages/opencode/src/acp/service.ts)).<br>**OpenCode 2.x (tag v2.0.21)** still ships ACP in `packages/cli/src/acp/` (agent, catalog, config-option, connection, content, event, permission, service, tool).<br>• `agentCapabilities`: `loadSession: true`, `mcpCapabilities {http: true, sse: false}`, `promptCapabilities {embeddedContext, image}`, `sessionCapabilities {close, delete, fork, list, resume}`, `_meta {"opencode/child-session-updates": true}`.<br>• **Vendor child-session extension:** the client opts in via `clientCapabilities._meta["opencode/child-session-updates"] === true`, then receives notification `opencode/session/child_update` with `{rootSessionId, childSessionId, parentSessionId, depth, title?} & ({type:"update", update: SessionUpdate} \| {type:"status", status: "created"\|"running"\|"completed"\|"failed"\|"interrupted", error?})`.<br>• `_meta` key `opencode/retry` carries `{attempt, nextRetryAt, error}`.<br>• The method name lacks the `_` prefix that the spec reserves for extensions.<br>Verified ([OCv2 `packages/cli/src/acp/service.ts`](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/cli/src/acp/service.ts) L206-225; [`event.ts`](https://github.com/anomalyco/opencode/blob/v2.0.21/packages/cli/src/acp/event.ts) L42-68). |
| **Claude Code** | Adapter | `npx @agentclientprotocol/claude-agent-acp@0.85.0` (authors: Anthropic, Zed Industries, JetBrains; proprietary license) | Wraps the Claude Agent SDK. Features: @-mentions, images, permissions, following, edit review, TODO lists, nested subagent transcripts, interactive and background terminals, slash commands, client MCP, AIR extensions. Subagent sessions only after negotiation. Earlier names: `zed-industries/claude-code-acp` → `claude-agent-acp`. Verified ([README](https://github.com/agentclientprotocol/claude-agent-acp)). |
| **Codex** | Adapter | `npx @agentclientprotocol/codex-acp@2.1.1` (authors: OpenAI, JetBrains, Zed; Apache-2.0) | *"starts the Codex App Server, translates ACP requests into Codex operations"*. Auth: ChatGPT, API key, gateway (`NO_BROWSER=1` hides browser login). Slash commands: `/status /mcp /skills /goal /review /review-branch /review-commit /compact /logout`. Background terminal tasks (AIR), native subagent sessions. Verified ([README](https://github.com/agentclientprotocol/codex-acp)). |
| **Pi** | Adapter | `npx pi-acp@0.0.34` (svkozak) | Spawns `pi --mode rpc`. Native `pi --mode acp` is only proposed ([earendil-works/pi discussion #4444](https://github.com/earendil-works/pi/discussions/4444); repo moved to `earendil-works/pi`). Fork `victor-software-house/pi-acp` embeds the SDK in-process. Unverified beyond search summaries. Codeg's docs claim Pi "speaks ACP natively", which conflicts with the registry; treat as Unverified. |
| **Grok Build (xAI)** | Native | `npx @xai-official/grok@1.0.47 agent stdio` | Open source `xai-org/grok-build` (Apache-2.0, Rust, 1.0 on 2026-08-07: Unverified, secondary). Uses `_x.ai/*` / `x.ai/*` extension methods (section 9.3; doc 31, section 15.4). Flags: `grok agent --always-approve` (alias `--yolo`) `stdio`, and **`serve --bind … --secret …` (WebSocket)**. Per-session `_meta {yoloMode, autoMode, rules, systemPromptOverride, agentProfile}` on `session/new`. Verified ([agent-mode doc](https://github.com/xai-org/grok-build/blob/2bdd1d6a6369de0e8c68132ea4539e9abd9e14a8/crates/codegen/xai-grok-pager/docs/user-guide/15-agent-mode.md)). |
| **Gemini CLI** | Native | `npx @google/gemini-cli@0.62.0 --acp` (older `--experimental-acp`) | |
| **GitHub Copilot CLI** | Native | `npx @github/copilot@1.0.91 --acp` | public preview 2026-01-28 |
| **Cursor** | Native | `cursor-agent acp` (binary 2026.09.28) | Requires `authenticate` first (Runmote). Vendor `cursor/*` requests (Reemoat). |
| **Kimi CLI** | Native | `kimi acp` | Measured: subagent events filtered at source (Reemoat Q5.44). |
| **Qwen Code** | Native | `npx @qwen-code/qwen-code@0.24.7 --acp --experimental-skills` | |
| **Goose** | Native, plus **HTTP/WS** | `goose acp`; `goose serve` for remote | Reference implementation of the remote transport |
| **Mistral Vibe, Junie, Cline, Factory Droid, Devin, Kilo, Auggie, Qoder, Poolside, VT Code, Stakpak, fast-agent, DeepAgents, Kiro CLI** (Kiro is on the docs agents list, not in the registry) | Native | (registry) | |
| **Amp, Google Antigravity, GLM** | Community/adapter | `amp-acp`, `antigravity-acp`, `glm-acp-agent` | |

**Third-party compatibility matrix** (Agmente, dated 2026-02-28; may be stale; copy in `plan/acp-src/ecosystem/`):
- `claude-code-acp`: *"Best reference implementation in this set"*.
- OpenCode: *"Code is ahead of its ACP README"*.
- kimi: *"No `resume`/`fork`; no `configOptions`"*.
- mistral-vibe: *"Strong generalized ACP surface"*.
- Verified (src file).

---

## 16. ACP v2 draft: summary of breaking changes

Verified (src: `docs/protocol/v2/migration.mdx` "If you only remember five things"):
1. *"The `session/prompt` response no longer ends the turn."*
2. *"Updates are upserts … omitted field = unchanged, `null` = cleared, value = replaced, chunks append."*
3. *"The Client file system, terminal execution, and session modes APIs are gone."*
4. *"Capabilities were reorganized. One `capabilities` + required `info` field on both sides … a required baseline of session methods."*
5. *"Everything is extensible now. Enums and tagged unions accept unknown values."*

Further changes:
- `session/load` is replaced by `session/resume` + `replayFrom:{type:"start"}`. Cursors are *"inclusive"* and future cursor kinds are planned (message, checkpoint).
- Consistent ID naming (`methodId`, `configId`, `groupId`).
- MCP `type` is required and SSE MCP removed.
- Base64 fields are marked `contentEncoding`.
- **Coexistence guidance:** *"Adding v2 support should not mean dropping v1 … gate your implementation behind the version negotiation **AND** feature flags."*
- Subagent updates become baseline in v2 (*"support is assumed rather than negotiated"*).

---

## 17. ACP gaps for a rich remote/mobile client (evidence of status)

| Need (from the current OpenCode-based client) | ACP v1 stable | Draft / extension evidence |
|---|---|---|
| Session list / history | ✓ `session/list` (cursor, `cwd` filter) | Some agents don't answer it (Runmote comment re OpenCode, Unverified today). Codeg and Runmote read agents' on-disk stores to aggregate history. |
| Replay after reconnect | `session/load` replays the whole history; no incremental cursor | v2 `replayFrom` (start only). Transport-level resumability deferred to v2. |
| Multiple clients on one session | Not defined | v2 design goal (`messageId` correlation) |
| Turn state / busy indicator | Implicit (pending prompt) | v2 `state_update`. AIR `sessionFailure` |
| Queue / steer while running | Not defined | v2 lifecycle enables it. `_session/steering` (JetBrains/codex-acp). Zed docs: *"Steering is only available for the Zed Agent, since Zed can't detect turn boundaries for external agents"* (subagent report, `docs/src/ai/agent-panel.md`). |
| Subagents / child sessions | Flattened into tool calls (`_meta.claudeCode.*`) | Draft RFD `subagent_update` (implemented behind negotiation by codex-acp and claude-agent-acp). OpenCode 2.x uses its own `opencode/session/child_update` extension. |
| Background tasks (shells, jobs) | Not defined | AIR `async_task_*` + `_session/async_task/stop` |
| Context usage / cost | ✓ `usage_update {used,size,cost?}` | High frequency (measured) |
| Per-turn token counts | Not stable | Draft `PromptResponse.usage`; `_meta.quota` |
| Provider rate limits / quotas (5h/weekly windows) | **None** | None in ACP. Products query vendor endpoints directly (OpenChamber quota service; Happy uses the Claude SDK `rate_limit_event`; doc 31). |
| Permission "allow all" / YOLO | Client policy; agent modes or boolean options | `allow_always` option kind; mode `category:"mode"` |
| Question tool | ✓ elicitation (form/url) | Vendor-specific: `_x.ai/ask_user_question`, `cursor/ask_question` |
| Undo / revert / rewind | **None** | Fork-at-message discussion (PR #629); `_session/rewind` (claude-agent-acp PR #966). Session archive RFD proposed (PR #2161, Unverified). Zed: *"Restoring threads from history, checkpoints, token usage display, and similar features depend on the agent integration"*. Zed's git checkpoints need a truncate capability that its `AcpConnection` does not implement (subagent report). |
| File listing / search / @-mention picker on the host | None client→agent (v1 `fs/*` is agent→client; removed in v2) | Products add out-of-band methods: Runmote `filesystem/list_drives` + directory listing in its daemon; Happy RPC `listDirectory`/`ripgrep`; Codeg has its own workspace API. |
| Diffs / changed files review | `diff {path, oldText, newText}` per tool call | v2 structured changes + `git_patch`; AIR `agentFileChangeReport` |
| Interactive user terminal | None | v2 terminal is display-only. Products run their own PTY (OpenChamber, Codeg, tlbx). |
| Push notifications (phone backgrounded) | None | Bridges do it (aptove bridge, Happy via Expo, OpenChamber via APNs relay) |
| Model / provider selection | ✓ config options (`category:"model"`) | Draft `providers/*`. `session/set_model` removed. |
| Compaction visibility | — | Preview `compaction_update` |
| Agent install / auth | Registry + `authMethods` (agent/terminal) | Draft `auth/status`; `_auth/status_update`. Device-auth flows run by hosts (Reemoat). |
| Images in agent output | Content blocks (`image`) | — |

---

## 18. Other protocols (brief, one section each)

### 18.1 AG-UI (Agent–User Interaction Protocol; CopilotKit)
- **What:** *"open, lightweight, event-based protocol that standardizes how AI agents connect to user-facing applications"*. Positioned as complementary: MCP = agent↔tools, A2A = agent↔agent, AG-UI = agent↔user UI. Verified ([docs.ag-ui.com/introduction](https://docs.ag-ui.com/introduction)).
- **Transport:** `HttpAgent` POSTs `RunAgentInput` and receives an event stream over HTTP SSE or an "HTTP binary protocol"; described as "Transport Agnostic". Verified ([architecture](https://docs.ag-ui.com/concepts/architecture)).
- **Input type (verbatim):** `RunAgentInput { threadId; runId; parentRunId?; state?; messages: Message[]; tools: Tool[]; context: Context[]; forwardedProps; resume?: ResumeEntry[] }`, with `ResumeEntry { interruptId; status: "resolved"|"cancelled"; payload?; metadata? }`. Verified ([types](https://docs.ag-ui.com/sdk/js/core/types)).
- **Events** (Verified, [events](https://docs.ag-ui.com/concepts/events)):
  - `RunStarted/RunFinished(outcome: success|interrupt)/RunError`, `StepStarted/StepFinished`
  - `TextMessageStart/Content/End/Chunk`
  - `ToolCallStart/Args/End/Result/Chunk`
  - `StateSnapshot/StateDelta (RFC 6902 JSON Patch)/MessagesSnapshot`
  - `ActivitySnapshot/ActivityDelta`, `Reasoning*`
  - `SubagentStarted/Finished/Error`
  - `Raw`, `Custom`
- **Human-in-the-loop:** `RunFinished` with `outcome:{type:"interrupt", interrupts:[…]}`, resumed via `RunAgentInput.resume`.
- **Integrations:** first-party Microsoft Agent Framework, Google ADK, AWS Strands, Mastra, Pydantic AI, LlamaIndex, etc. Community: "Claude Agent SDK". Verified (intro page).
- **Fit (evidence only):** a web-frontend↔agent-backend runtime protocol built around run/thread. There is no harness registry, session list, permission-option kinds or coding-tool semantics. A bridge exists: [acp-to-agui](https://github.com/namanrajpal/acp-to-agui) *"bridges any ACP agent to web frontends via AG-UI events over SSE"* (Verified, ACP clients page).

### 18.2 A2A (Agent2Agent)
- **Version and governance:** spec **1.0.0** is "Latest Released Version" (previous 0.3.0, 0.2.6, 0.1.0). Verified ([spec](https://a2a-protocol.org/latest/specification/)). Moved to the Linux Foundation's **Agentic AI Foundation (AAIF)** on 2026-08-17. Unverified (secondary: [A2A blog](https://a2a-protocol.org/latest/blog/2026/08/27/a-new-chapter-for-a2a-joining-the-agentic-ai-foundation/), Axios).
- **Methods:** `SendMessage`, `SendStreamingMessage`, `GetTask`, `ListTasks`, `CancelTask`, `SubscribeToTask`, `Create/Get/List/DeleteTaskPushNotificationConfig`, `GetExtendedAgentCard`.
- **Task states:** `TASK_STATE_SUBMITTED|WORKING|COMPLETED|FAILED|CANCELED|INPUT_REQUIRED|REJECTED|AUTH_REQUIRED`.
- **Streaming events:** `TaskStatusUpdateEvent`, `TaskArtifactUpdateEvent`. Parts: `text|file|data`.
- **AgentCard capabilities:** `streaming`, `pushNotifications`, `extendedAgentCard`. Verified (spec page).
- **Bindings:** JSON-RPC 2.0/HTTPS, gRPC, HTTP+JSON. Push notifications go to webhooks. Unverified (secondary).
- **Fit (evidence):** an agent↔agent delegation and task protocol. No tool-call/diff/permission-option semantics for a coding UI. Codex tracks A2A only as a feature request (Unverified, secondary).

### 18.3 MCP (Model Context Protocol), the tool layer
- **Current spec 2026-07-28** (Verified, [changelog](https://modelcontextprotocol.io/specification/2026-07-28/changelog)):
  - *"Remove protocol-level sessions and the `Mcp-Session-Id` header"*
  - *"Make MCP stateless: remove the `initialize`/`notifications/initialized` handshake"*
  - `server/discover`
  - `subscriptions/listen`
  - Tasks moved to extension `io.modelcontextprotocol/tasks` (`tasks/get` polling, `tasks/update`)
  - MRTR replaces server-initiated `elicitation/create`/`sampling`/`roots`
  - Roots/Sampling/Logging deprecated
  - SSE resumability removed
  - Extensions framework (MCP Apps)
- **Role in ACP:** clients pass MCP server configs on `session/new`/`resume`. v2 tells clients to expose client-side tools as MCP servers. The Draft MCP-over-ACP tunnels MCP through the ACP connection.
- **Fit (evidence):** OpenAI tried exposing Codex *as an MCP server* for VS Code and moved away from it because IDE needs (streaming diffs, approvals, saved threads) did not fit MCP's tool model. Codex still supports MCP-server mode *"for simpler workflows"*. Unverified (secondary: [InfoQ](https://www.infoq.com/news/2026/02/opanai-codex-app-server/); the OpenAI blog "Unlocking the Codex harness", 2026-02-04, returned 403 to fetch).

### 18.4 OpenAI Codex app-server protocol (de facto standard?)
- **What:** a bidirectional JSON-RPC API (the `"jsonrpc":"2.0"` header is omitted on the wire) used by every Codex surface (desktop app, TUI, web runtime, VS Code, JetBrains, Xcode). Primitives: **thread → turn → item** (`item/started` → deltas → `item/completed`). Approvals are server→client requests (`item/commandExecution/requestApproval`, `item/fileChange/requestApproval`), answered with `{decision: accept|acceptForSession|…|decline|cancel}`. Verified against source in doc 31, section 15.1 (CODEX `codex-rs/app-server-protocol/src/protocol/{common.rs, v2/item.rs}` @`7135b303`). Background: [InfoQ](https://www.infoq.com/news/2026/02/opanai-codex-app-server/).
- **Transports:**
  - `AppServerTransport { Stdio, UnixSocket, WebSocket, Off }`. WebSocket refuses non-loopback binds without `--ws-auth capability-token|signed-bearer-token` and rejects any request with an `Origin` header.
  - `codex app-server daemon …` backs *"remote clients such as the desktop and mobile apps"*. **Remote Control** dials out to `wss://chatgpt.com/backend-api/wham/remote/control/server` with `remoteControl/pairing/*` RPCs.
  - Verified (source per doc 31, section 15.1).
  - Earlier blog claims that non-loopback listeners were unauthenticated by default are contradicted by current source. Treat as Unverified/obsolete.
- **Quotas exposed natively:** `account/rateLimits/read|updated` (`RateLimitSnapshot{primary, secondary, credits, plan_type…}`), `thread/tokenUsage/updated`. This is richer than anything in ACP. Verified (doc 31, section 15.1).
- **Standard or not?** It is Codex-harness-specific. Other projects consume it as Codex's integration API: codex-acp wraps it; Happy, Agmente, CodexMonitor and t3code drive it. No other harness implements it. Agmente supports **both** ACP and Codex app-server as server types (Verified, README). Happy's competitor review calls it the *"cleanest typed app-server model for thread, turn, item, approval, and sandbox policy"* (Verified per subagent report on `slopus/happy` `docs/competition/comparison-matrix.md`).
- More detail on app-server, the Claude Agent SDK, and Pi RPC is in doc 31.

### 18.5 Other "agent protocol" efforts
- **Agent Protocol (AI Engineer Foundation → AGI, Inc.):** REST `POST /ap/v1/agent/tasks`, `…/tasks/{id}/steps`, artifacts. Original repos archived in late 2023; no 2026 releases found. Unverified (secondary: [agentprotocol.ai](https://agentprotocol.ai/)).
- **LangGraph "Agent Protocol"** (runs/threads/store), a different project with the same name. Unverified.
- **IBM ACP:** merged into A2A (section 1.1).
- **AAIF (Agentic AI Foundation, Linux Foundation):** hosts MCP and A2A, and Goose's org is `aaif-goose`. Zed/JetBrains ACP is **not** listed there; its governance doc says "working toward … an independent foundation". Unverified (secondary sources for AAIF membership).

---

## 19. Uncertainties and open questions
- The remote transport RFD is **Active, not Completed**. Header names, HTTP/2 requirement and batch handling may change. TS SDK HTTP support is labelled experimental.
- v2 is **Draft** (alpha.7). Field names may still change; the maintainers explicitly ask implementers to feature-flag it.
- Whether current OpenCode (1.18.x / 2.0.x) answers `session/list` over ACP: Runmote's comment says it silently drops it, while OpenCode's code advertises `list`. Unverified.
- Whether Pi has gained native ACP after 2026-09-20: Unverified.
- Grok Build release history (open-sourced mid-July, 1.0 on 2026-08-07) is Unverified (secondary). The `grok agent serve` endpoint path and token transport are not documented on the page checked.
- Codex app-server facts in section 18.4 were verified at source by a sub-research pass (doc 31, section 15.1). The Codex Remote relay is OpenAI-owned; third-party use is Unverified.
