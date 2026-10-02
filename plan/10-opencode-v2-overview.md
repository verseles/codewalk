# OpenCode V2 — official docs, releases and migration facts for a V2-only remote client

- Researched: 2026-10-02 (docs/announcements/release-metadata focus; source-code reading is done by a separate agent).
- Local reference install: opencode 1.18.33 (V1). V1 doc snapshots compared: `ai-docs/opencode_server.md`, `opencode_web.md`, `opencode_models.md`, `opencode_config.md`.
- Full verbatim docs snapshot: `plan/opencode-v2-docs/` (start at `plan/opencode-v2-docs/INDEX.md`). Raw OpenAPI: `plan/opencode-v2-docs/openapi.json`. Rendered API reference: `plan/opencode-v2-docs/docs-api.md`.
- Tags: **[Verified]** = checked directly against an official source (docs page, docs source in the official repo, npm registry, official update endpoint, GHCR, official GitHub issue text). **[Unverified]** = third-party claim, inference, or not stated in official docs. Issue/PR text in the official repo is official *data*, but the claims inside user-filed issues are tagged by what they are (bug reports, proposals).

---

## Executive summary

1. **OpenCode V2 exists and is released on the stable channel.** 2.0.0 was published to npm as `@opencode/cli` on 2026-09-11; latest is **2.0.22** (npm publish 2026-10-02T04:21Z; 2.0.21 on 2026-09-30). 23 releases in 3 weeks (near-daily). [Verified: https://registry.npmjs.org/@opencode%2Fcli (dist-tag `latest` = 2.0.22), https://opencode.ai/update/api/latest/cli/npm]
2. **V1 is still maintained in parallel.** GitHub Releases and https://opencode.ai/changelog list only V1 (latest v1.18.34, 2026-09-30); npm `opencode-ai` latest is 1.18.34. V2 lives on branch `v2` of https://github.com/anomalyco/opencode (repo moved from `sst/opencode`; `gh api repos/sst/opencode` redirects to `anomalyco/opencode`). [Verified]
3. **No official release notes or blog announcement exist for 2.x.** No GitHub Release objects for `v2.*` tags; the changelog page is generated from GitHub Releases. Closest official announcement: V1 docs banner "OpenCode v2 is now available" → https://opencode.ai/v2, and the homepage installer now points to `https://opencode.ai/v2/install`. Team posts on X (e.g. https://x.com/thdxr/status/2071007637487894883: "in OpenCode v2 all instances of the tui and desktop and web share the same backend…"). Per-release commit subjects are saved in `plan/opencode-v2-docs/v2-release-commits.md`. [Verified for absence + banner; X post Verified via search snippet only]
4. **Official migration guide exists:** https://opencode.ai/v2/docs/migrate-v1/ — "V2 has three intentional breaking changes": plugins, **server API and clients**, and `tui.json` → global `cli.json`. Config is read from the same locations and V1-shaped config is normalized in memory. [Verified]
5. **For a remote client, V2 is a different product surface:** all routes are under `/api/*` (136 operations, OpenAPI 3.1 at https://opencode.ai/v2/openapi.json), one shared per-user background **service** (default port **49374**, localhost-only, password-protected), pairing via `opencode pair` one-time links, a single cross-location SSE stream `GET /api/event` that is **live-only with no replay**, plus an **experimental durable per-session log** `GET /api/experimental/session/{id}/log?after=&follow=true`. Permissions are an ordered `{action, resource, effect}` array, replies are `once|always|reject`. Subagents can run in the **background** natively (`subagent` tool `background: true`; commands `subagent: true`). LSP, session sharing, the todo tool and the `CLAUDE.md` fallback are gone/not documented. [Verified; see sections]
6. **API stability caveat:** the OpenAPI `info` says `"version": "0.0.1"`, `"description": "Experimental HttpApi surface for selected instance routes."`, and most tags are described as "Experimental … routes"; several routes live under `/api/experimental/*`. Expect churn. [Verified: openapi.json]

---

## Release facts (task 1)

| Item | Fact | Source | Tag |
| --- | --- | --- | --- |
| Canonical repo | `anomalyco/opencode` (default branch `dev` = V1; V2 on branch `v2`; tags `v2.0.0`…`v2.0.22`) | https://github.com/anomalyco/opencode | Verified |
| Beta period | Beta published as `@opencode-ai/cli` (`next`/`beta` dist-tags, command `opencode2`) from 2026-06-04 to 2026-09-07 | https://registry.npmjs.org/@opencode-ai%2Fcli | Verified |
| Package rename | `@opencode/cli` first versions 2026-09-07 (dev) | https://registry.npmjs.org/@opencode%2Fcli | Verified |
| 2.0.0 | npm 2026-09-11T23:44Z; tag commit "fix(release): use V2 Docker artifact paths (#48571)" | npm + `git tag v2.0.0` | Verified |
| Latest | 2.0.22 (2026-10-02T04:21Z). 2.0.21 = 2026-09-30 | npm, https://opencode.ai/update/api/latest/cli/npm | Verified |
| Channels | update API channels `latest` (2.0.x), `beta` (stale 2.0.1), `dev` (`0.0.0-dev-*`); npm dist-tags `latest`, `beta`, `dev` | https://opencode.ai/update/api/latest/cli, `/update/api/dev/cli/npm` | Verified |
| GitHub Releases | none for `v2.*` (404 on `releases/tags/v2.0.0`, `v2.0.21`) | GitHub API | Verified |
| Changelog | https://opencode.ai/changelog lists V1 only (built from GitHub Releases, `packages/console/app/src/lib/changelog.ts` on `v2`) | page + source | Verified |
| Migration guide | https://opencode.ai/v2/docs/migrate-v1/ and plugin guide https://opencode.ai/v2/docs/build/plugins/migrate-v1/ | docs | Verified |
| Third-party coverage | ccleaks (2026-09-24), byteiota (2026-09-24), KuCoin/MetaEra, falcao.org; they mention Bun→Node, Tauri→Electron, "Hono/SQLite server" — dates/claims conflict | https://ccleaks.com/news/opencode-2-0-sep-2026, https://byteiota.com/opencode-2-beta-unified-ai-coding-agent/ | Unverified |
| Electron desktop | Team member post "OpenCode Desktop is now running on Electron" | https://x.com/brendonovich/status/2051572000267833718 (search snippet) | Unverified (not in docs) |

Breaking-change list (official, verbatim from migrate-v1): "V2 has three intentional breaking changes: Plugins use a new plugin API. The server API and clients have new contracts. Terminal client configuration moves from layered `tui.json(c)` files to one global `cli.json` file (auto migrated)." Plus "Accepted but unsupported fields" (ignored with warning): `logLevel`, `server`, top-level `subagent_depth`, `compaction.tail_turns`, `compaction.prune`, agent `name`, enabled-only MCP without `type`, experimental `batch_tool`/`openTelemetry`/`primary_tools`/`continue_loop_on_deny`, provider `id`/`whitelist`/`blacklist`, several provider-model fields. **[Verified: https://opencode.ai/v2/docs/migrate-v1/]**

---

## a. Installation

### Official methods (verbatim from https://opencode.ai/v2/docs/ ) [Verified]

```bash
curl -fsSL https://opencode.ai/v2/install | bash
brew install anomalyco/tap/opencode-v2
npm install -g @opencode/cli
bun install -g --trust @opencode/cli
pnpm add -g --allow-build=@opencode/cli @opencode/cli
yarn global add @opencode/cli
vp install -g @opencode/cli          # Vite+
paru -S opencode-beta                # AUR
```

- "The npm package uses a postinstall script to select the native `opencode` binary for your platform." "**Windows package managers are not supported.**" (no scoop/choco/winget for V2). [Verified]
- Standalone binaries: `https://opencode.ai/files/bin/<version>/opencode-<target>.{zip|tar.gz}`; targets: darwin-arm64, darwin-x64, darwin-x64-baseline (zip); windows-arm64, windows-x64, windows-x64-baseline (zip); linux-arm64, linux-x64, linux-x64-baseline (+ `-musl` variants) (tar.gz). The docs page links are pinned to 2.0.6. Full list with sha256/size is served by `GET https://opencode.ai/update/api/latest/cli` (distribution `opencode`). [Verified; endpoint itself is undocumented]
- Desktop (Electron per team posts): `.dmg` mac arm64/x64, `.exe` win x64/arm64, `.deb`/`.rpm`/`.AppImage` linux x64/arm64; metadata at `GET https://opencode.ai/update/api/latest/desktop`. [Verified downloads; Electron Unverified]
- Docker: "Docker images use versioned tags, for example `ghcr.io/anomalyco/opencode:2.0.0`." `ghcr.io/anomalyco/opencode:2.0.21` exists (linux/amd64 + linux/arm64). **`:latest` currently equals `1.18.34` (V1)** — always pin a 2.x tag. [Verified via GHCR registry API]
- Homebrew formula `opencode-v2` "conflicts_with "opencode", because: both install an opencode binary"; depends on `ripgrep`; uses the baseline x64 builds. [Verified: https://github.com/anomalyco/homebrew-tap/blob/HEAD/opencode-v2.rb]
- AUR `opencode-beta` = 2.0.21-1; AUR `opencode-bin` = V1 1.18.34. [Verified: AUR RPC]

### What changed vs V1 [Verified unless noted]

| Topic | V1 | V2 |
| --- | --- | --- |
| Installer URL | `https://opencode.ai/install` (307 → `raw.githubusercontent.com/anomalyco/opencode/refs/heads/dev/install`, downloads from GitHub Releases `releases/latest/download/opencode-<os>-<arch>…`) | `https://opencode.ai/v2/install` (downloads npm tarball `@opencode/cli-<target>`; version from `https://opencode.ai/update/api/latest/cli/npm`) |
| Install dir | `~/.opencode/bin/opencode` | **same** `~/.opencode/bin/opencode` (+ legacy shim `opencode2`). "the V2 curl installer replaces the V1 binary." |
| npm package | `opencode-ai` | `@opencode/cli` (+ per-platform `@opencode/cli-<target>`) — "they are different packages" so `npm update` on V1 does not reach V2 (third-party summary of migrate guide; the guide itself says "Remove a package-managed V1 installation before installing V2") |
| Side-by-side | — | "OpenCode 1 and OpenCode 2 both use the `opencode` command and are no longer installed side by side by default." |
| Update | `autoupdate` | `update`: `"disable"` / `"notify"` (default) / `"auto"`; global config only; "Automatic installation does not restart a running server. Restart it manually to activate the installed update." (https://opencode.ai/v2/docs/config/) |
| Upgrade CLI | `opencode upgrade` | `opencode upgrade [version] [--method <pm>]`, alias `update`, e.g. `opencode upgrade 2.0.21 --method bun` (https://opencode.ai/v2/docs/cli/commands/) |
| Uninstall | — | `opencode uninstall [--dry-run] [--keep-config|-c] [--keep-data|-d] [--force|-f]`; stops registered background services and persistent terminals first |
| Data | `~/.local/share/opencode` | same dirs, SQLite DB `~/.local/share/opencode/opencode.db` (override `OPENCODE_DB`; path "respects the release channel"); V1 sessions migrated (progress: `GET /api/experimental/migration/v1`); credentials imported from legacy `auth.json` into SQLite |

Commit evidence (not docs): v2.0.22 "feat(cli): check for updates every 10 minutes (#52552)"; v2.0.7 "fix(cli): keep updates client-owned"; v2.0.15 "fix(cli): keep Windows upgrades and uninstalls from fighting the running binary". [Verified as commit subjects only — see `v2-release-commits.md`]

### Headless install/update/launch for a third-party app

Recommended (derived from official docs + installer; the exact recipe is an inference) [Unverified as a recipe; each ingredient Verified]:

```bash
# Install / pin a version without touching shell rc files (Linux/macOS, x64 or arm64; also MSYS/Git-Bash on Windows x64)
curl -fsSL https://opencode.ai/v2/install | bash -s -- --version 2.0.22 --no-modify-path
# Or via npm (all 3 OSes incl. windows-arm64):
npm install -g @opencode/cli@2.0.22
# Discover latest version programmatically:
curl -fsSL https://opencode.ai/update/api/latest/cli/npm   # → {"version":"2.0.22","metadata":{"package":"@opencode/cli",...}}
# Upgrade in place:
opencode upgrade 2.0.22 --method npm      # or: opencode upgrade (latest)

# Launch a remote-reachable foreground server (supervisor-friendly):
opencode serve --hostname 0.0.0.0 --port 4096 --cors https://app.example.com
#   prints:  server listening on http://0.0.0.0:4096
#            server password <password>
# …or configure the shared per-user service instead:
opencode service set hostname 0.0.0.0
opencode service set port 49374
opencode service set password "a-long-secret"
opencode service set cors https://app.example.com
opencode service start           # changing a setting stops the service; start it again
opencode service status
opencode api get /api/info       # health check through local discovery+auth
opencode pair --url https://dev.example.com   # one-time links + QR for app pairing
```

- Installer supports only `linux-x64|linux-arm64|darwin-x64|darwin-arm64|windows-x64`; auto-picks `-baseline` (no AVX2) and `-musl` (Alpine/musl ldd). `windows-arm64` exists on npm/zip but is rejected by the curl script. [Verified: docs-install-script.md]
- `Service.ensure()` in `@opencode/client/service` defaults to command `opencode serve --service` and a standard registration file (`~/.local/state/opencode/service.json`); private service config at `~/.config/opencode/service.json`. "Do not delete or edit service files or the database." [Verified: https://opencode.ai/v2/docs/build/client/, https://opencode.ai/v2/docs/troubleshooting/]
- Env for the service process must be persisted with `opencode service set env KEY VALUE` (e.g. provider keys, proxies, `NODE_EXTRA_CA_CERTS`); `--standalone`/`serve` use their own process env. [Verified: https://opencode.ai/v2/docs/network/, https://opencode.ai/v2/docs/cli/providers/]
- **Android/Termux: not officially supported.** npm `os` = `darwin|linux|win32` only; installer drops a glibc binary. Open issues: #47612 "Add android to v2 npm package supported OS" (states the musl arm64 build runs on Termux and V2 "replaces Bun with Node.js"), #50668, #50203; community projects `nemoobc/opencode-termux` (patched musl build) and `Hope2333/opencode-termux` (bionic transplant). [Verified: npm metadata + issue texts; community claims Unverified]

---

## b. Server / connection

**Architecture** [Verified: https://opencode.ai/v2/docs/cli/]: "By default, OpenCode discovers or starts one shared background server for your user account. Every local OpenCode client connects to that server, which owns sessions, configuration, integrations, permissions, and tool execution." `--standalone` = private server; `--server <url>` = connect to a specific server; `opencode service set disabled true` makes private servers the default ("Pairing requires the shared service and is unavailable while it is disabled").

**Ports/hosts** [Verified: https://opencode.ai/v2/docs/cli/web/]: "By default the server runs on port 49374 and listens only on localhost." Port is "the channel default" (beta/dev channels may differ — Unverified). `opencode serve` flags documented: `--hostname`, `--port`, `--cors` (repeatable), `--service`; "With `serve --service`, supplied `--cors` flags override the persisted list for that process." Default port of plain `opencode serve` is not stated in docs (examples use 4096). [Unverified]

**Auth** (what the docs actually say) [Verified]:
- "It's available by default and password protected." `opencode serve` prints `server password <password>`; `opencode service set password "a-long-secret"` replaces the generated one.
- `opencode pair` "Prints one-time links, plus a QR code of the first one, that sign a browser or app in to the server. Links expire after 5 minutes and work once." Link shape: `http://127.0.0.1:49374/auth/connect/...`. "Opening a link in a browser signs it in with a session cookie… Scanning the QR code from the OpenCode app, or pasting the link into its server address field, connects the app the same way. Sessions last 30 days; changing the server password signs every session out." `--url` sets the external URL used in links.
- The Intro page's older sample still shows `opencode pair` printing `URLs / Username opencode / Password ********` (pre-2.0.17 behavior; commit v2.0.17 "feat(server): pair with one-time connect links", "feat(app): replace password pairing with one-time links").
- Client SDK: `OpenCode.make({ baseUrl, headers, fetch })`; local service helpers `Service.discover()`, `Service.ensure()`, `Service.stop()`, `Service.headers(endpoint)` ("creates the authentication headers for a client"). The docs' example header `authorization: Bearer ${process.env.OPENCODE_TOKEN}` is illustrative only.
- **Not documented in V2 docs:** the wire auth scheme (Basic vs Bearer vs cookie name), `OPENCODE_SERVER_PASSWORD`/`OPENCODE_SERVER_USERNAME` (V1 documented these), the `/auth/connect/<token>` redemption protocol for non-browser apps, and OpenAPI `securitySchemes` (none; all operations declare `security: []` yet return 401 `{"_tag":"UnauthorizedError","message":...}`). An unmerged PR describes V2 `serve` as "mandatory HTTP basic auth — generating and printing a fresh password per start when OPENCODE_SERVER_PASSWORD was unset" (https://github.com/anomalyco/opencode/pull/46270); feature request for `--no-auth` is open (https://github.com/anomalyco/opencode/issues/43039). A community client says "The redeemed token is saved as the password" (https://github.com/blazebsc/opencode-mobile-client). [Unverified — confirm in source]
- PTY WebSocket uses a separate single-use ticket: `POST /api/pty/{ptyID}/connect-token` then `GET /api/pty/{ptyID}/connect?ticket=…` (or header `x-opencode-ticket`). [Verified: openapi.json]

**CORS** [Verified: https://opencode.ai/v2/docs/troubleshooting/]: exact origins, no path/trailing slash; `opencode service set cors "http://192.168.1.10:3001, https://app.example.com"`; `opencode service get cors` prints a JSON array; `opencode service unset cors`; "CORS does not change the listening address or bypass server authentication."

**mDNS**: V1 had `--mdns`/`--mdns-domain`; no mention anywhere in V2 docs. [Verified absence in docs; runtime support Unverified]

**Directory / workspace / multi-project** [Verified: openapi.json, https://opencode.ai/v2/docs/build/client/]:
- One server serves many "Locations" (directories). Location-scoped routes take query `location[directory]=/abs/path` (deepObject; 57 operations). "Omitted location follows native request defaults: base location headers, then the server's working directory." (header name not documented — Unverified.)
- `POST /api/session` body `{ id?, title?, agent?, model?: {id, providerID, variant?}, location?: {directory}, metadata?, permissions? }`.
- `GET /api/location`, `POST /api/location/reload` (rebuilds all locations; emits `location.shutdown`; pending permissions/forms cancelled), `GET /api/project`, `PATCH /api/project/{projectID}`, `GET /api/session?directory=&project=&subpath=&parentID=&search=&order=&limit=&cursor=`, `POST /api/session/{id}/move`, worktrees `GET/POST/DELETE /api/worktree`, `POST /api/worktree/refresh`.

**OpenAPI / clients** [Verified]:
- Spec: https://opencode.ai/v2/openapi.json (OpenAPI 3.1.0; 136 operations; 245 schemas); human page https://opencode.ai/v2/docs/api. Whether a running server serves its own spec (V1: `GET /doc`) is not documented. [Unverified]
- `@opencode/client` (network, browser-compatible, generated from the same contract), `@opencode/client/service` (Node service discovery), `@opencode/client/effect`; `@opencode/sdk` = in-process host ("opens no HTTP listener"); V1 `@opencode-ai/sdk` is the V1 client. CLI: `opencode api <METHOD> <path>` or `opencode api <operationId> --param k=v --data '{…}' -H 'k: v'`.
- Health: `GET /api/info` → `ServerInfo {version, pid, urls[], paths{tmp}}`.

---

## c. Events / streaming

[Verified: https://opencode.ai/v2/docs/build/client/ and openapi.json]

- **`GET /api/event`** (`event.subscribe`), `text/event-stream`, SSE frames `{id, event, data}` where `data` is a JSON string (`V2EventEncoded`). Description: "Subscribe to native events and plugin RPC events across all server locations. **Volatile by contract: a slow consumer overflows and fails the stream, and events during disconnection are missed.**" Stream failure event name: `effect/httpapi/stream/failure`.
- Client docs: "Subscriptions are live-only, with no replay or automatic reconnection. A source failure ends current subscriptions; subscribe again after recovery. A late native subscriber receives the current `server.connected` marker, not past business events." "consumers should buffer before performing slow work."
- **Durable replay (experimental):** `GET /api/experimental/session/{sessionID}/log?after=<seq>&follow=true` — "Reads events after an exclusive aggregate sequence and continues with live events when follow=true." Item schema is an opaque JSON string in the spec.
- **Snapshots for recovery:** `GET /api/session/{id}/message?order=&limit=&cursor=&type=` (projected messages, cursor paging), `GET /api/session/{id}/message/{messageID}`, `GET /api/session/{id}/inbox`, `GET /api/session/{id}/context`, `GET /api/session/active`, `GET /api/session/{id}/permission`, `GET /api/session/{id}/form`.
- **Event type catalog is NOT documented.** Names that appear in docs: `server.connected`, `session.idle` (plugin migration example), `permission.asked` (TUI plugin example), `session.compaction.*` (compaction page), `shell.started`/`shell.ended` (shell route description), `location.shutdown` (reload route), plugin RPC envelope `rpc.<rpcID>.<event>`. [Verified]
- **Deltas vs full updates:** docs don't say. Message model is projected: `Session.Message.Assistant.content[]` of `text | reasoning | tool` items; tool `state` is `streaming {input: string}` → `running` → `completed`/`error`; assistant `time {created, streamed, completed}`, `finish`, `retry`, `error`, `tokens`, `cost`. Commit v2.0.17 "fix(core): publish batched deltas before the next block starts (#51105)" implies batched delta events exist; third-party integrations mention `session.inbox.enqueued`. [Unverified — confirm event names/payloads in source]
- V2 records "a separate assistant message for each step, so token and cost totals need to add up every assistant message in a turn" (third-party migration write-up https://www.pgupai.com/guides/opencode-v2-migration). [Unverified]

---

## d. Permissions

[Verified: https://opencode.ai/v2/docs/permissions/]

- Rules: ordered `permissions: [{ "action", "resource", "effect": "allow"|"deny"|"ask" }]`; **last match wins**; no match → `ask`; wildcards `*` (incl. `/`) and `?`, whole-value, case-insensitive on Windows; shell pattern ending ` *` also matches the bare command. Multiple resources: any deny → deny; else any ask → ask.
- Actions: `read`, `edit` (edit/write/patch), `glob`, `grep`, `shell`, `subagent`, `skill`, `question`, `webfetch`, `websearch`, `external_directory`, `<server>_<tool>` (MCP), `execute` (Code Mode); "`doom_loop` and `lsp` are not current V2 Core permission actions." V1→V2: `bash`→`shell`, `task`→`subagent`, `write`/`patch`→`edit`.
- **Default base policy (every agent):**

```jsonc
[
  { "action": "*", "resource": "*", "effect": "allow" },
  { "action": "external_directory", "resource": "*", "effect": "ask" },
  { "action": "read", "resource": "*.env", "effect": "ask" },
  { "action": "read", "resource": "*.env.*", "effect": "ask" },
  { "action": "read", "resource": "*.env.example", "effect": "allow" },
]
```

  Shipped agents append: `build` allows questions; `plan` denies edits except `~/.opencode/plan`; `general` denies questions and subagents; `explore` read-only-ish; `title`/`summary` deny all.
- **Answering:** client replies `once` | `always` | `reject` ("Reject it and every other pending permission request in that session"); "Clients may attach feedback when rejecting." API: `POST /api/session/{sessionID}/permission/{requestID}/reply` body `{ "decision": "once"|"always"|"reject", "message"?: string }` → 204. Pending: `GET /api/permission/request?location[directory]=…`, `GET /api/session/{id}/permission`. Request shape `Permission.Request {id ^per, sessionID, action, resources[], save?[], metadata?, source?{type:"tool", messageID, id}, message?}`. Saved ("always") approvals are durable project-scoped allow rules: `GET /api/permission/saved`, `DELETE /api/permission/saved/{id}`. [Verified: openapi.json]
- **"Allow all"/YOLO:** no dedicated flag/mode is documented. Documented levers: (1) config rule `{ "action": "*", "resource": "*", "effect": "allow" }` (note the default is already allow-all except external dirs and `.env`); (2) **per-session ruleset** — `POST /api/session` and `PATCH /api/session/{id}` accept `permissions: Permission.Rule[]`, and `Session.Info.permissions` is returned [Verified in schema; precedence relative to config/agent rules Unverified]; (3) client-side auto-reply `once` to every `ask` (how OpenChamber implements "Accept everything": "it simply treats every 'ask' as allowed", https://docs.openchamber.dev/permissions/ [Unverified, third-party]). `PATCH /api/experimental/config` only accepts `{ shell }` today. [Verified]
- **Policies** can hard-deny after rules/approvals and cannot be overridden by a client: `"experimental": { "policies": [{ "action": "permission", "resource": "shell:sudo *", "effect": "deny" }] }`; Console-managed policies apply to every connected V2 client "within about a minute". [Verified: https://opencode.ai/v2/docs/policies/, https://opencode.ai/v2/docs/console/]

---

## e. Subagents (sync vs async/background)

[Verified unless noted]

- Tool `subagent` (V1 `task`): "Supply the agent ID, a short `description`, and a complete `prompt`. Foreground calls wait for the result. `background: true` returns immediately and notifies the parent when the child finishes. Pass the returned `sessionID` to continue that same child conversation. Only subagent-mode agents can be used, and the default nesting depth is one." Permission action `subagent`, resource = agent ID. (https://opencode.ai/v2/docs/tools/) Depth config: `experimental.subagent_depth` (migrate-v1).
- Agents: "Subagents run with fresh context in foreground or background child sessions." A subagent "uses its configured model, or inherits the parent session's model". (https://opencode.ai/v2/docs/agents/) Commit v2.0.5: "let subagents pick a model and expose models tool".
- Commands: `subagent: true` → "runs in a background child session… The parent stays available and keeps its agent and model. OpenCode sends the child's result or failure back to the parent when the child finishes." Legacy `subtask` accepted; "delegated commands now run automatically in the background and report their results to the parent session." (https://opencode.ai/v2/docs/commands/, migrate-v1)
- Shell `background: true`: "Background calls return immediately and notify the session when they finish." (tools page)
- API levers: `POST /api/session/{id}/background` ("Move active foreground backgroundable tools for this session into background observation"); children via `GET /api/session?parentID=ses_…` and `Session.Info.parentID`; state via `Session.Info.outcome` (`succeeded|failed|interrupted`), `time.idle`, `Session.Message.Idle`; activity via `GET /api/session/active`; cancel via `POST /api/session/{childID}/interrupt` (inferred — Unverified); wait via `POST /api/experimental/session/{id}/wait`.
- Notification mechanics are not documented. Third-party adapters observe a synthetic inbox item in the parent (`<subagent sessionID=… state=…>` / `metadata.source: "subagent"`) delivered via `session.inbox.enqueued`, which wakes the parent. [Unverified: https://github.com/pingdotgg/t3code/pull/14474, search summaries]
- **Known open bug** (official repo): #48826 "V2: subagent with pending background work (task/shell, background: true) marked completed early — results never collected", re-verified on 2.0.21; it also states `OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS` "no longer exists in 2.0.21 and background subagents are core". #52456 (closed) same family. [Verified issue text]
- UI guidance: none in docs. TUI evidence: commit v2.0.8 "fix(tui): open completed subagent sessions"; v2.0.19 "fix(tui): distinguish background shell from interrupted command". OpenChamber 2.1.0: "background commands and subagents stay visible while they run… shows as running in its row with a live log, and you can stop it there. Send a running step to the background… Cmd/Ctrl+Shift+B." (https://github.com/openchamber/openchamber/releases/tag/v2.1.0) [Verified as release text; secondary reference]

---

## f. Quotas / usage / limits

- **In-server (readable by a client)** [Verified: openapi.json]: `Session.Info.cost` (USD) + `tokens {input, output, reasoning, cache{read,write}}`; per assistant message `cost`/`tokens`; `GET /api/experimental/session/stats?from=&to=&project=&timezone=&tools=none|summary|detail` → `{sessions, subagents, prompts, steps, tokens, cost, tools, activeDays, streak, activity[], models[]}`; `GET /api/model` → `Model.Info {limit{context, input, output}, cost[] (tiered, per-million), variants[], capabilities, status, enabled}`; `GET /api/session/{id}/context` (active context messages since last compaction). CLI: `opencode stats [--days N] [--models] [--cost] [--json]`.
- **Context window**: compaction auto at limit minus `buffer` (default 10% of limit), keeps `keep.tokens` (default 15000); overflow → compact + retry once. Custom models default to 200k context / 32k output. [Verified: https://opencode.ai/v2/docs/compaction/, https://opencode.ai/v2/docs/models/]
- **OpenCode Go** [Verified: https://opencode.ai/v2/docs/console/go/]: Go $10/month, Go Plus $40/month; per-model monthly dollar limits; "Each model has the following usage limits: 5-hour — 20% of the monthly limit; weekly — 50%; and monthly — 100%." "You can track your current usage in the console." Optional "Use balance" fallback. Third-party clients should send a stable `x-opencode-session` header and their own User-Agent. Model ids `opencode-go/<model-id>`.
- **Console budgets API** (service account key with All permissions): `GET https://opencode.ai/console/api/v1/budgets/members` → `[{user_id, email, limit_micro_cents, spent_micro_cents, exceeded, resets_at, source, updated_at}]`; `PUT/DELETE …/members/:user_id`. 100,000,000 microcents = $1. [Verified: https://opencode.ai/v2/docs/console/budgets/] A Console *Usage* API page was hidden (commit v2.0.17 "docs(www): hide Console Usage API documentation"). [Verified commit subject]
- **Provider subscription quotas (ChatGPT Plus/Pro, Claude Max, Copilot):** no documented API or event for remaining quota/rate-limit windows. Docs only cover login ("ChatGPT Pro/Plus (headless)" in `/connect`, GitHub Copilot device OAuth). Errors carry `Session.StructuredError {type, message, status?}`; commit v2.0.6 "classify gateway account limits as quota and keep 4xx non-retryable". Claude Pro/Max is not mentioned in V2 docs. [Verified absence in docs; runtime behavior Unverified]
- Web search providers: HTTP 429 → provider cooldown (`Retry-After` or 60 s), random selection retries another provider. [Verified: https://opencode.ai/v2/docs/websearch/]

---

## g. Other API-consumer features

| Feature | V2 contract | Source | Tag |
| --- | --- | --- | --- |
| Send prompt | `POST /api/session/{id}/prompt` `{id?: msg_…, text, files?: [{uri, name?, description?, mention?}], agents?: [{name}], skills?: [{id}], metadata?, delivery?: "steer"\|"queue", resume?}` → `{data: Session.Inbox.User}`; "Durably admit… schedule agent-loop execution unless resume is false." Idempotent by `id`. | openapi.json; build/plugins | Verified |
| Steering/queue | TUI: Enter steers active session, Ctrl+X Enter queues. API: `delivery`, `GET/PATCH/DELETE /api/session/{id}/inbox[/{inboxID}]` | cli/tui, openapi | Verified |
| Interrupt | `POST /api/session/{id}/interrupt?resume=` → `{interrupted}` (V1 `/abort`) | openapi | Verified |
| Errors/retries | `Assistant.error`, `Assistant.retry {attempt, at, error}`; provider header/chunk timeouts 5 min, "retries a timed-out request up to three times"; error bodies `{_tag, message, …}` (e.g. `SessionBusyError` 409) | providers page; openapi | Verified |
| Compaction | `POST /api/session/{id}/compact` `{id?}` (accepted, async; follow `session.compaction.*`); messages `Session.Message.Compaction.{Running,Completed,Failed}` | compaction page | Verified |
| Undo/redo | `POST /api/session/{id}/revert/stage {messageID, files?}` → `Session.Revert`; `DELETE /api/session/{id}/revert` (cancel = redo); `POST /api/session/{id}/revert/commit`; "Submitting the edited prompt commits the staged rollback"; rejected while session running (409); snapshots need Git | snapshots page; openapi | Verified |
| Fork | `POST /api/session/{id}/fork {before?: msg_…}` | openapi | Verified |
| Diff | `GET /api/session/{id}/diff` (per-turn structured diffs), `GET /api/vcs/{,base,status,branch,diff}` | openapi | Verified |
| Sharing | "OpenCode V2 does not support session sharing yet." `share` config accepted (`manual\|auto\|disabled`). | https://opencode.ai/v2/docs/sharing/ | Verified |
| Todo list | No todo tool in the V2 tools page and no todo route in the API. | tools page; openapi | Verified (absence) |
| Questions | `question` tool → **forms**: `GET /api/session/{id}/form`, `GET /api/form`, `POST …/form/{formID}/reply` body `{answer: {<key>: value}}`, `DELETE …/form/{formID}` (cancel); field types string/number/integer/boolean/multiselect/external. "A client must support the interactive form, and dismissing it cancels the question." | tools page; openapi | Verified |
| Slash commands | `GET /api/command` → `{name, description}`; `POST /api/session/{id}/command {name, text, files?, agents?, skills?, delivery?}` | openapi; commands page | Verified |
| Skills | `GET /api/skill` → `{id, name, description, autoinvoke, path, content}`; `POST /api/experimental/session/{id}/skill`; prompt `skills: [{id}]` | openapi | Verified |
| @ mentions / attachments | `file://` absolute URIs (optional `?start=&end=` lines), `data:` URLs; **no http(s)**; text, directories (non-recursive listing), PNG/JPEG/GIF/WebP; PDF not sent; 20 MiB per item; `media.image` resize config | https://opencode.ai/v2/docs/attachments/ | Verified |
| Agent/model/variant | `GET /api/agent`, `POST /api/session/{id}/agent`, `GET /api/model`, `GET /api/model/default`, `POST /api/session/{id}/model {model: {id, providerID, variant?}}`; selector string `provider/model#variant` | openapi; models page | Verified |
| Providers/auth | `GET /api/provider`, `GET /api/integration` (methods), `POST /api/integration/{id}/connect/key`, OAuth `connect/oauth` → poll `…/{attemptID}` → `…/complete`, command method; credentials `PATCH/DELETE /api/credential/{id}`, `POST …/activate` | openapi; cli/providers | Verified |
| Terminal/PTY | `GET/POST /api/pty`, `GET/PUT/DELETE /api/pty/{id}`, `POST /api/pty/{id}/connect-token`, WebSocket `GET /api/pty/{id}/connect?ticket=`; persistent PTY under `/api/experimental/persistent-pty/*` | openapi | Verified |
| Shell | `POST /api/session/{id}/shell` (emits `shell.started`/`shell.ended`), `GET/POST /api/shell`, `GET /api/shell/{id}/output?cursor=` | openapi | Verified |
| Files | `GET /api/fs/list`, `GET /api/fs/find?query=&type=file\|directory&limit=` (ranked names), `GET /api/fs/read/*`, `POST /api/experimental/fs/write`. **No content-grep route** (V1 `/find?pattern=`) and no symbol search. | openapi | Verified |
| MCP | `GET /api/mcp`, `GET /api/mcp/resource`, experimental `PUT/DELETE /api/experimental/mcp/{server}`, `…/connect`, `…/disconnect` | openapi | Verified |
| Side question | TUI `/btw <question>` (not added to history); API `POST /api/session/{id}/generate` "Generate transient text from the current session context without mutating session history." | cli/tui; openapi | Verified (mapping Unverified) |
| Session env | `PUT /api/session/{id}/environment` | openapi | Verified |
| Viewed state | `POST /api/session/{id}/view` | openapi | Verified |
| Web search | `GET /api/websearch/provider`, `POST /api/websearch` | openapi | Verified |
| Config read | `GET /api/config` (documents + sources, low→high), `GET /api/config/shell` | openapi | Verified |
| Warming | `warming: true \| {prompt, interval, duration}`; real billed requests | warming page | Verified |
| ACP | `opencode acp` stdio JSON-RPC, ACP protocol v1, private server per process | cli/acp | Verified |

---

## h. Deprecated / removed things a V1 client used

[Verified against V1 snapshot `ai-docs/opencode_server.md` and V2 openapi.json unless noted]

- **Every V1 route** (`/global/health`, `/global/event`, `/event`, `/session…`, `/session/:id/message`, `/session/:id/prompt_async`, `/session/status`, `/session/:id/abort`, `/session/:id/children`, `/session/:id/todo`, `/session/:id/init`, `/session/:id/summarize`, `/session/:id/revert`, `/session/:id/unrevert`, `/session/:id/share`, `/session/:id/permissions/:permissionID`, `/find`, `/find/file`, `/find/symbol`, `/file`, `/file/content`, `/file/status`, `/lsp`, `/formatter`, `/experimental/tool*`, `/log`, `/tui/*`, `/auth/:id`, `/provider/auth`, `/provider/{id}/oauth/*`, `/config/providers`, `/instance/dispose`, `/path`, `/project/current`, `/doc`) is gone; V2 serves only `/api/*`. A community report: "unmatched V1 paths fall through to the V2 web UI catch-all and return 200 text/html" (https://github.com/grapeot/opencode_ios_client/issues/169) — so detect V2 via `GET /api/info`, not via status codes. [catch-all behavior Unverified]
- **Removed features:** session sharing (unsupported), LSP ("accepts and preserves `lsp` configuration, but it does not run language servers, expose LSP tools, or produce LSP diagnostics"), todo tool/endpoint (absent), symbol search, text grep endpoint, `CLAUDE.md` fallback ("V2 recognizes `AGENTS.md` only"), `instructions` config ("accepts this field but does not load its entries"), `mode` map (→ `agents`), `scout` agent, `doom_loop`/`lsp` permissions, `tui.json` (→ `~/.config/opencode/cli.json`), mDNS flags (not documented), `OPENCODE_SERVER_PASSWORD`/`USERNAME` (not documented), V1 plugins ("do not run in V2"), V1 SDK `@opencode-ai/sdk` (V2 uses `@opencode/client`).
- **Renamed config** (see migrate-v1): `agent`→`agents`, `prompt`→`system`, `disable`→`disabled`, `maxSteps`→`steps`, `variant` → `model#variant`, `permission`→`permissions` (array), `command`→`commands`, `subtask`→`subagent`, `provider`→`providers` (`npm`→`package` with `aisdk:` prefix, `api`→`settings.baseURL`, `options`→`settings/headers/body`), `snapshot`→`snapshots`, `attachment`→`media`, `mcp.<name>`→`mcp.servers.<name>` (`enabled`→`disabled`, `timeout`→`{catalog, execution}`), `compaction.preserve_recent_tokens`→`keep.tokens`, `compaction.reserved`→`buffer`, `skills.{paths,urls}`→`skills[]`, `plugin`→`plugins`, `autoshare`→`share`, `autoupdate`→`update`, `small_model`→`agents.title.model`, `enabled_providers`/`disabled_providers` → policies. Provider IDs `azure-cognitive-services`→`azure`, `google-vertex-anthropic`→`google-vertex`.
- **Agent `request` overlays** are "preserved but does not yet send them with model requests". [Verified: agents page]
- **Session list scoping:** V1 "global" sessions can be hidden after migration (#51176, open). [Verified issue text]

---

## V1 → V2 differences relevant to a remote client

| Area | V1 (ai-docs snapshot) | V2 | Tag / source |
| --- | --- | --- | --- |
| Base path | `/session`, `/event`, `/global/*` … | `/api/*` only | Verified (openapi.json) |
| Health/version | `GET /global/health` → `{healthy, version}` | `GET /api/info` → `{version, pid, urls, paths}` | Verified |
| Spec | `GET /doc` on server | https://opencode.ai/v2/openapi.json (server-side URL undocumented) | Verified / Unverified |
| Server model | per-TUI server on random port; `opencode serve` port 4096 default | one shared per-user service (port 49374, localhost) + `opencode serve` foreground + `--standalone` | Verified (docs-cli, docs-cli-web) |
| Auth | opt-in Basic auth via `OPENCODE_SERVER_PASSWORD` (user `opencode` / `OPENCODE_SERVER_USERNAME`) | always password-protected; `service set password`; `opencode pair` one-time links → 30-day session cookie; header scheme undocumented | Verified / scheme Unverified |
| Discovery | `--mdns` | not documented; QR pairing via `opencode pair` | Verified absence |
| Directory | `?directory=` / per-instance | `location[directory]=` query on 57 ops; sessions carry `location` | Verified |
| Events | `GET /event` (+`/global/event`), first `server.connected` | `GET /api/event` cross-location, live-only, overflow fails stream; `server.connected` marker; experimental durable `session.log?after=&follow=` | Verified |
| Messages | `{info, parts[]}` with part types (text, tool, reasoning, file, step…) | projected message union (`user`, `assistant{content[text|reasoning|tool]}`, `synthetic`, `system`, `skill`, `shell`, `compaction`, `idle`, `agent/model/location switched`), cursor paging | Verified |
| Prompt | `POST /session/:id/message` (sync) / `prompt_async` (204), `parts[]`, `model`, `agent`, `noReply`, `system`, `tools` | `POST /api/session/{id}/prompt {text, files, agents, skills, delivery, resume}`; agent/model switched via separate routes | Verified |
| Status | `GET /session/status` | `GET /api/session/active`, `Session.Info.time.idle/outcome`, `idle` messages | Verified |
| Abort | `POST /session/:id/abort` | `POST /api/session/{id}/interrupt?resume=` | Verified |
| Permissions reply | `POST /session/:id/permissions/:pid {response, remember?}` | `POST /api/session/{sid}/permission/{rid}/reply {decision: once|always|reject, message?}` | Verified |
| Permission config | map by tool (`bash`, `edit`, `task`…) | ordered array `{action, resource, effect}`; `shell`, `subagent`, `edit` | Verified |
| Questions | question tool/events | Forms API (`/form`) | Verified |
| Revert | `/revert`, `/unrevert` | `revert/stage`, `DELETE revert`, `revert/commit` | Verified |
| Summarize | `/session/:id/summarize` | `/api/session/{id}/compact` | Verified |
| Share | `/session/:id/share` | not supported | Verified |
| Todo | `/session/:id/todo` | none | Verified absence |
| Files | `/file`, `/file/content`, `/find`, `/find/file`, `/find/symbol`, `/file/status` | `/api/fs/list`, `/api/fs/read/*`, `/api/fs/find`, `/api/vcs/status`; no text/symbol search | Verified |
| Providers/auth | `/provider`, `/provider/auth`, `/provider/{id}/oauth/*`, `PUT /auth/:id`, `/config/providers` | `/api/provider`, `/api/model`, `/api/integration/*/connect/{key,oauth,command}`, `/api/credential/*` | Verified |
| Variants | separate `variant` field | `Model.Ref {id, providerID, variant}`; strings `provider/model#variant` | Verified |
| Subagents | `task` tool, foreground; V1 background behind `OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS` | `subagent` tool with `background: true` core; commands `subagent: true` background; `POST …/background` | Verified (flag removal per issue #48826) |
| LSP | `/lsp`, LSP tools/diagnostics | not run | Verified |
| PTY | not in the V1 `ai-docs` snapshot | `/api/pty*` + ticketed WebSocket; persistent PTY (experimental) | Verified (V2) |
| Install | `opencode.ai/install` (GitHub Releases), npm `opencode-ai`, brew `opencode`, scoop/choco | `opencode.ai/v2/install` (npm tarballs), npm `@opencode/cli`, brew `anomalyco/tap/opencode-v2`, AUR `opencode-beta`; no Windows PMs; same `~/.opencode/bin` | Verified |
| Update config | `autoupdate` | `update: disable|notify|auto` (global only; server not restarted) | Verified |
| Docker | `ghcr.io/anomalyco/opencode:latest` | pin `:2.0.x` (`:latest` is still V1) | Verified |
| Client config | `tui.json` layers | global `~/.config/opencode/cli.json` (client-owned) | Verified |
| Instructions | `AGENTS.md` + `CLAUDE.md` fallback | `AGENTS.md` only | Verified |

---

## Open questions / unverified (hand to the source-code agent)

1. **Auth wire format**: Basic (`opencode:<password>`?) vs Bearer vs cookie; whether `OPENCODE_SERVER_PASSWORD` is still honored; how a native app redeems `/auth/connect/<token>` (cookie vs returned credential); what `Service.headers()` emits; whether the service password can be read via API by an authenticated client (issue #35943 was closed 2026-10-01 — check what shipped).
2. **Event catalog**: exact SSE event `type`s and payloads (message/content deltas, tool state updates, `session.inbox.*`, `permission.*`, `form.*`, `session.compaction.*`, subagent lifecycle), whether deltas are text-only or part-level, and the `session.log` item format/sequence semantics.
3. **Location selection** header name ("base location headers") and default location when omitted; multi-project event filtering.
4. **Per-session `permissions`**: precedence vs config/agent rules; whether `[{action:"*",resource:"*",effect:"allow"}]` on a session yields a true "allow all" (and whether policies/`external_directory` still ask).
5. **Background subagent notification**: event/inbox shape and how to list running background children; cancel semantics (interrupt child vs parent); status of bug #48826.
6. Default port of `opencode serve` (docs only show 49374 for the service), whether mDNS still exists, whether the server serves its own OpenAPI document, and per-channel ports.
7. **Upgrade path for managed installs**: whether `opencode upgrade` on a curl install (no package manager) downloads from `opencode.ai/files/bin` or npm; how V1 1.18.x `opencode upgrade` behaves now that the update API `latest` channel returns 2.x (could a V1 host be moved to V2 unexpectedly?).
8. The published schema at https://opencode.ai/config.json is still **V1-shaped** (has `permission`, `agent`, `mode`, `server.mdns`, no `permissions`/`agents`/`update`/`warming`), although V2 docs point `$schema` at it. A native V2 schema URL was not found. [Verified observation; intent Unverified]
9. Provider-subscription quota visibility (ChatGPT/Claude/Copilot remaining limits) — no API found; check whether usage/rate-limit headers are surfaced in assistant metadata or events.
10. Whether an official mobile "OpenCode app" exists (docs mention "Scanning the QR code from the OpenCode app"); only community mobile clients were found (https://getopencode.app/ FAQ says not official). Likely refers to the official desktop app. [Unverified]
11. Runtime claims from third parties (Bun→Node, Hono/SQLite, Electron) are not in official docs.
