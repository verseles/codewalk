# CodeWalk v2 — Planning Research Pack

> **Historical research snapshot, not the execution contract.** The current product decisions are in [`../v2-plan.md` §2](../v2-plan.md#2-decision-record-d01d16); execution readiness and per-Issue rules are in its §§11.5, 12 and 20. Applicable project rules and verified official contracts govern implementation. This folder preserves the research and planning inputs as collected; later corrections are recorded in the plan's §17 change log.

Research snapshot collected on **2026-10-02** to support planning **CodeWalk v2**: OpenCode v2 only (no v1 compatibility; v1 stays in legacy CodeWalk v1) plus a multi-harness architecture. Every dossier tags its claims as Verified (with a source) or Unverified/inferred. Use pinned excerpts as versioned evidence, not as proof of current upstream or workspace state. Recheck a fact through its owning spike before implementing its consumers; official sources take precedence over community summaries.

**User decisions:** [`02-decisions.md`](02-decisions.md) preserves the original 16 answers and critique request, before the final discussion. Its open D01/D02 and initial D04/D05 wording are historical; do not use them to replace the subsequently approved decisions in `v2-plan.md` §2. Original helper proposals are advisory historical inputs too.

**Known superseded summary claims below (2026-10-03).** The OpenCode bullet saying no write endpoint omits the experimental write route; that route is unconfined in the pinned source, so client lexical checks alone do not authorize write (§5.12/§6.10). Windows ARM64 binaries are listed in the later verified plan (§3.1). Codex's native authenticated app-server and dedicated-listener/TUI topology were rechecked against 0.160.0 (§3.3); the Host remains the chosen integration route. Resolve these claims in the current plan rather than copying this snapshot into implementation.

## Reading order

| # | File | What it gives you |
|---|------|-------------------|
| 1 | `00-codewalk-v1-inventory.md` | Current CodeWalk v1 architecture, a feature inventory of about 110 rows with file paths, v1-only workarounds, size metrics, and adapter boundaries |
| 2 | `01-codewalk-v1-opencode-contract.md` | Every OpenCode v1 endpoint and event CodeWalk uses today (file:line), SSE handling, Dart models, and the permission flow |
| 2a | `02-decisions.md` | User-selected directions, decisions left open to planners, and the required independent critique of all 16 answers |
| 2b | `03-planner-brief.md` | Canonical read-only planning payload, shared identically with every authorized helper |
| 3 | `10-opencode-v2-overview.md` | OpenCode v2 from the official docs: install, server/auth, events, permissions, subagents, usage, removed features, and a v1→v2 table |
| 4 | `11-opencode-v2-server-api.md` | Authoritative v2 HTTP API from the source: 140 routes, auth/pairing, directory scoping, quotas, install |
| 5 | `12-opencode-v2-events-and-schemas.md` | All 94 v2 event types, the flat message model, streaming deltas, execution status, errors, permissions, forms, subagents |
| 6 | `13-opencode-v2-vs-v1-diff.md` | Route, event, and schema diff between v1.18.34 and v2.0.21, plus the install diff |
| 7 | `20-codex.md` | OpenAI Codex app-server v2 protocol, the shared daemon, remote access options, terms, and a capability mapping |
| 8 | `21-claude-code.md` | Claude Agent SDK / stream-json protocol, the host-bridge pattern, policy/ToS constraints, and a capability mapping |
| 9 | `22-pi.md` | Pi (Earendil) RPC mode, plus "Other notable harnesses" (Gemini, Copilot, Kimi, Goose, Amp, …) |
| 10 | `23-muse-code.md` | Meta Muse Code and its Muse Session Protocol v1 |
| 11 | `24-grok-build.md` | xAI Grok Build, which speaks ACP over WebSocket (`grok agent serve`) |
| 12 | `25-deepseek-dsh.md` | DeepSeek Harness (`dsh`), a developer preview with thin ACP |
| 13 | `30-acp-and-unifying-protocols.md` | Agent Client Protocol v1 (stable) and v2 (draft), the remote transport RFD, AG-UI/A2A/MCP, and which agents support ACP |
| 14 | `31-multi-harness-clients.md` | Architecture of OpenChamber, Happy, Zed, t3code, Paseo, Reemoat, vibe-kanban, and others, with the patterns they share |

## Raw evidence folders

- `opencode-v2-docs/`: 54 official v2 doc pages (verbatim), `openapi.json`, the install script, and per-release commit lists (`INDEX.md` maps the pages).
- `opencode-v2-src/`: 108 source extracts. They include generated SDK types and client, `openapi.json`, and the official event reducer `client-solid-data.reference-reducer.ts`.
- `codex-src/`: `methods.md` (every method and notification, marked stable or experimental), `key-types.ts` (generated from codex 0.159.3), and official doc extracts.
- `claude-code-src/`: Agent SDK 0.3.287 typings, tool schemas, and `claude --help` for 2.1.287.
- `harness-src/`: Pi RPC docs and types, the Muse protocol types and sample sessions, the Grok user guide, DeepSeek Harness READMEs, and ACP registry entries.
- `acp-src/`: ACP v1/v2 spec pages, RFDs, JSON Schemas with field digests, the registry snapshot, codex-acp's AIR contract, and Agmente/Reemoat compatibility data.

## Key facts at a glance (see dossiers for citations)

### OpenCode v2 (2.0.0 released 2026-09-11; latest 2.0.22; repo `anomalyco/opencode`, branch `v2`; npm `@opencode/cli`)
- **No compatibility with v1.** Every route lives under `/api/*`, and old paths return HTML with status 200. Detect v2 with `GET /api/info`. The OpenAPI document is served live at `GET /openapi.json`.
- **Auth is always on.** HTTP Basic auth uses the fixed user `opencode` with the password as the password. Pairing works like this:
  - `opencode pair` (or `POST /api/pair`) produces a single-use code valid for 5 minutes.
  - The client redeems it at `GET /auth/connect/{code}` with `Accept` not `text/html`, which returns `{"token": …}`.
  - The token is used as the Basic password and lasts 30 days. Rotating the server password revokes all tokens.
- **One shared background service per user.** It listens on port 49374 (localhost by default) and is configured with `opencode service set` for hostname, port, password, CORS, and env. It registers itself in `~/.local/state/opencode/service.json`. The foreground alternative is `opencode serve`. `opencode serve --stdio` prints `{"url":…}` and exits when stdin closes.
- **Events.** There is a single global SSE stream at `GET /api/event`, with `data:`-only frames and a heartbeat comment every 15 s.
  - It has no replay, and a client more than 4096 events behind is dropped.
  - Catch-up is possible through the experimental `GET /api/experimental/session/{id}/log?after=`.
- **Messages.** The message list is flat and typed; there is no more Message+Part split. Streaming events are `session.{text,reasoning,tool.input}.{started,delta,ended}`. Deltas are batched every 100 ms, and `ended` carries the authoritative final text.
- **Prompting is async only.**
  - `POST /api/session/{id}/prompt` takes `{text, files, delivery: steer|queue, resume}`.
  - Agent and model are set on the session (`POST …/agent`, `POST …/model`), not per prompt.
- **Busy/idle state** comes from `session.execution.*` events and `GET /api/session/active`. `session.status` is declared but never published.
- **Permissions** are ordered `{action, resource, effect}` rules where the last match wins.
  - Requests carry `{action, resources, save}`, and replies are `{decision: once|always|reject, message?}`.
  - "Always" saves an approval for the whole project.
  - **Allow-all on the server:** `PATCH /api/session/{id}` with `{permissions:[{action:"*",resource:"*",effect:"allow"}]}`. It overrides agent `deny` rules and is inherited by subagent sessions. The official apps instead auto-reply `once` on the client.
- **Questions became Forms** (`/api/session/{id}/form`, with answers keyed `q0…qN`).
- **Subagents** are the `subagent` tool and can run with `background: true`.
  - Children are found with `?parentID=` and cancelled with `POST /api/session/{child}/interrupt`.
  - When a background child finishes, the parent gets a synthetic message and resumes on its own.
  - `POST /api/session/{id}/background` detaches running subagents or shell commands.
  - Open bug #48826: nested background work reports completion too early.
- **Undo/redo** is a staged revert: `POST …/revert/stage`, `POST …/revert/commit`, and `DELETE …/revert`.
- **Other endpoints:** PTY over WebSocket using a short-lived connect token (`/api/pty`, and an experimental persistent PTY); shell (`/api/shell`, `/api/session/{id}/shell`); files (`/api/fs/find`, `/api/fs/list`, `/api/fs/read/*`, read-only); `/api/vcs/status`; `/api/session/{id}/diff`; `/api/skill`; `/api/command`; `/api/agent`; `/api/model`; `/api/provider`; integrations/OAuth connect; credentials.
- **Removed:** todo, share, init (now a command), text and symbol search, LSP/formatter status, TUI-control routes, `POST /log`, mDNS, and the `CLAUDE.md` fallback. **There is no endpoint for writing files.**
- **Usage and quotas.** Cost and tokens are available per session and step, plus experimental stats and model context/output limits. There is **no quota-remaining endpoint.** OpenCode Go/Zen limit errors appear only inside `error.response.body`.
- **Install.**
  - Script: `curl -fsSL https://opencode.ai/v2/install | bash`.
  - Direct binaries: `https://opencode.ai/files/bin/<ver>/opencode-<target>` (12 targets, including linux-arm64 and musl) with sha256 from the update API.
  - Other channels: brew `anomalyco/tap/opencode-v2`, Docker `ghcr.io/anomalyco/opencode:2.0.x` (`:latest` is still v1).
  - It overwrites `~/.opencode/bin`. There is no windows-arm64 build and no Termux support.
  - Auto-update is controlled by `update: disable|notify|auto` and `opencode upgrade`.
- **ACP** is still available in v2 (`opencode acp`). OpenChamber v2.0.0 requires OpenCode 2.0.20 or later and is OpenCode-only.

### Other harnesses
| Harness | Best official surface | Network-reachable? | Notes |
|---|---|---|---|
| OpenAI Codex | `codex app-server` protocol v2 (JSON-RPC); shared per-machine daemon on a Unix socket since 0.157 | Through SSH plus `codex app-server proxy`, an optional `--listen ws://` with a capability token (no TLS; requests with an Origin header get 403), or a host bridge | Rich: steer and interrupt, approvals, rate limits, skills, file search, subagents, PTY. No file undo and no server-side slash commands. Marked experimental and changes weekly. ToS allows local/open-source clients; hosted or commercial use needs a partnership. |
| Claude Code | `@anthropic-ai/claude-agent-sdk` (TS) on the host, or raw `claude -p` stream-json | No official daemon; a host bridge is required | Rich: permission modes, AskUserQuestion, mid-turn queue, background tasks, rate-limit events, file rewind. Policy: the user logs in on the host with the official binary. No in-app Claude login, no token forwarding, no "Claude Code" branding. Offer an API-key mode. |
| Pi (Earendil, MIT, 1.0) | `pi --mode rpc` (JSONL over stdio) or the community `pi-acp` | A host bridge is required | No permissions, todos, or subagents by design; a Pi extension could add them |
| Muse Code (Meta, 1.4.2) | Muse Session Protocol v1 (`muse serve`, stdio) | A host bridge is required | Most GUI-complete protocol, including quota windows. The CLI is closed source. |
| Grok Build (xAI, Apache-2.0) | ACP over WebSocket via `grok agent serve --bind --secret`, plus `x.ai/*` extensions | Yes (`ws://`, shared secret, no TLS) | Its extensions may change between releases |
| DeepSeek Harness `dsh` (0.2.0-rc) | ACP over stdio (`dsh --profile acp`), thin | A host bridge is required | Preview with breaking changes; the dossier recommends deferring it |
| Long tail (Gemini CLI, Copilot CLI, Cursor, Kimi, Qwen, Goose, Junie, Mistral Vibe, Cline, Amp…) | ACP, natively or via an adapter | Mostly stdio, so a host bridge is required | The ACP registry lists 42 agents |

### Cross-cutting patterns observed in existing multi-harness products (see `31`)
1. A host daemon owns the agent processes and is the source of truth. The phone is a thin client that attaches over a direct WebSocket, a tunnel, or an (often E2E-encrypted) relay.
2. Each product normalizes into its own canonical event union, with raw passthrough and open enums, using per-harness adapters.
3. There are two camps: ACP for everything, or native protocols for the major harnesses with ACP for the long tail.
4. Capability flags are declared per adapter, on top of what ACP negotiates.
5. History is kept as a sequence-numbered event log, with bounded replay plus full catch-up pages.
6. Approval policy (auto-accept, YOLO) lives in the client or daemon, not in the protocol.
7. Quotas bypass the agent protocol: products call vendor usage endpoints or read rate-limit events.

### CodeWalk v1 pain points that v2 may remove (see `00` §3 and `01`)
- `ChatProvider` (~22.8k LOC) and `ChatPage` (~27.5k LOC) are each one class split into `part` files. OpenCode v1 wire types leak all the way into widgets, and 26 presentation files call Dio directly.
- Sending uses `prompt_async`, then polls `/session/status` and the message list for up to about 3 minutes. Optimistic bubbles are matched to the server's copy by content.
- Two SSE streams run at once with a dedupe ring. Every reconnect triggers a full refetch, and every delta triggers a refetch of the whole message.
- Hidden throwaway sessions handle titles. `/shell` scripts handle file writes. `/shell` running `node -e <base64>` reads the host `auth.json` for quotas.
- Auto-approve of permissions is on by default (EXC-001).
- Android uses three completion detectors: in-app SSE, a foreground service, and WorkManager polling.
- Managed install is desktop-only. It uses npm/bun `opencode-ai` or a v1 binary, then runs `opencode serve` on 127.0.0.1:4096 with no password, no update path, and a likely orphaned process.
