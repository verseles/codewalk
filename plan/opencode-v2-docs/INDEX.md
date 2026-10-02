# OpenCode V2 official docs snapshot — index

- Fetched: 2026-10-02 by a research agent (web/docs focus).
- Docs root: https://opencode.ai/v2/docs/ · machine index: https://opencode.ai/v2/llms.txt · OpenAPI: https://opencode.ai/v2/openapi.json
- Docs source of truth: `services/www/src/docs/content/**.mdx` in https://github.com/anomalyco/opencode on branch `v2` @ `bb381e8bdd1ff22c7329e07c068ec0099031f382` (navigation order from `services/www/src/docs/lib/navigation.ts`). Live pages were spot-checked against the source (identical text; binary links pinned to 2.0.6 in both).
- Release state at fetch: `@opencode/cli` latest = **2.0.22** (published 2026-10-02T04:21Z, minutes after this snapshot started; docs content unchanged between the snapshot commit and the v2.0.22 tag).
- Every file starts with its source URL, source file and fetch date. Content is verbatim; MDX components were flattened to Markdown.

## Saved pages (official nav order)

| # | Section | Page | URL | File |
| --- | --- | --- | --- | --- |
| 1 | Docs | Intro | https://opencode.ai/v2/docs/ | [docs-intro.md](docs-intro.md) |
| 2 | Docs | Config | https://opencode.ai/v2/docs/config/ | [docs-config.md](docs-config.md) |
| 3 | Docs | Migrate from V1 | https://opencode.ai/v2/docs/migrate-v1/ | [docs-migrate-v1.md](docs-migrate-v1.md) |
| 4 | Docs | Troubleshooting | https://opencode.ai/v2/docs/troubleshooting/ | [docs-troubleshooting.md](docs-troubleshooting.md) |
| 5 | Docs › Configure | Agents | https://opencode.ai/v2/docs/agents/ | [docs-agents.md](docs-agents.md) |
| 6 | Docs › Configure | Models | https://opencode.ai/v2/docs/models/ | [docs-models.md](docs-models.md) |
| 7 | Docs › Configure | Skills | https://opencode.ai/v2/docs/skills/ | [docs-skills.md](docs-skills.md) |
| 8 | Docs › Configure | Themes | https://opencode.ai/v2/docs/themes/ | [docs-themes.md](docs-themes.md) |
| 9 | Docs › Configure | Commands | https://opencode.ai/v2/docs/commands/ | [docs-commands.md](docs-commands.md) |
| 10 | Docs › Configure | Plugins | https://opencode.ai/v2/docs/plugins/ | [docs-plugins.md](docs-plugins.md) |
| 11 | Docs › Configure | Providers | https://opencode.ai/v2/docs/providers/ | [docs-providers.md](docs-providers.md) |
| 12 | Docs › Configure | Websearch | https://opencode.ai/v2/docs/websearch/ | [docs-websearch.md](docs-websearch.md) |
| 13 | Docs › Configure | Network | https://opencode.ai/v2/docs/network/ | [docs-network.md](docs-network.md) |
| 14 | Docs › Configure | Snapshots | https://opencode.ai/v2/docs/snapshots/ | [docs-snapshots.md](docs-snapshots.md) |
| 15 | Docs › Configure | Compaction | https://opencode.ai/v2/docs/compaction/ | [docs-compaction.md](docs-compaction.md) |
| 16 | Docs › Configure | Formatters | https://opencode.ai/v2/docs/formatters/ | [docs-formatters.md](docs-formatters.md) |
| 17 | Docs › Configure | References | https://opencode.ai/v2/docs/references/ | [docs-references.md](docs-references.md) |
| 18 | Docs › Configure | Attachments | https://opencode.ai/v2/docs/attachments/ | [docs-attachments.md](docs-attachments.md) |
| 19 | Docs › Configure | Tools | https://opencode.ai/v2/docs/tools/ | [docs-tools.md](docs-tools.md) |
| 20 | Docs › Configure | MCP servers | https://opencode.ai/v2/docs/mcp-servers/ | [docs-mcp-servers.md](docs-mcp-servers.md) |
| 21 | Docs › Configure | Permissions | https://opencode.ai/v2/docs/permissions/ | [docs-permissions.md](docs-permissions.md) |
| 22 | Docs › Configure | Policies | https://opencode.ai/v2/docs/policies/ | [docs-policies.md](docs-policies.md) |
| 23 | Docs › Configure | Instructions | https://opencode.ai/v2/docs/instructions/ | [docs-instructions.md](docs-instructions.md) |
| 24 | Docs › Configure | Sharing | https://opencode.ai/v2/docs/sharing/ | [docs-sharing.md](docs-sharing.md) |
| 25 | Docs › Configure | Warming | https://opencode.ai/v2/docs/warming/ | [docs-warming.md](docs-warming.md) |
| 26 | CLI | Intro | https://opencode.ai/v2/docs/cli/ | [docs-cli.md](docs-cli.md) |
| 27 | CLI | TUI | https://opencode.ai/v2/docs/cli/tui/ | [docs-cli-tui.md](docs-cli-tui.md) |
| 28 | CLI | Settings | https://opencode.ai/v2/docs/cli/config/ | [docs-cli-config.md](docs-cli-config.md) |
| 29 | CLI | Web | https://opencode.ai/v2/docs/cli/web/ | [docs-cli-web.md](docs-cli-web.md) |
| 30 | CLI | Providers | https://opencode.ai/v2/docs/cli/providers/ | [docs-cli-providers.md](docs-cli-providers.md) |
| 31 | CLI | Commands | https://opencode.ai/v2/docs/cli/commands/ | [docs-cli-commands.md](docs-cli-commands.md) |
| 32 | CLI | ACP | https://opencode.ai/v2/docs/cli/acp/ | [docs-cli-acp.md](docs-cli-acp.md) |
| 33 | CLI | Theme | https://opencode.ai/v2/docs/cli/theme/ | [docs-cli-theme.md](docs-cli-theme.md) |
| 34 | CLI | Plugins | https://opencode.ai/v2/docs/cli/plugins/ | [docs-cli-plugins.md](docs-cli-plugins.md) |
| 35 | CLI | Keybinds | https://opencode.ai/v2/docs/cli/keybinds/ | [docs-cli-keybinds.md](docs-cli-keybinds.md) |
| 36 | Build | Intro | https://opencode.ai/v2/docs/build/ | [docs-build.md](docs-build.md) |
| 37 | Build › Plugins | Overview | https://opencode.ai/v2/docs/build/plugins/ | [docs-build-plugins.md](docs-build-plugins.md) |
| 38 | Build › Plugins | RPC | https://opencode.ai/v2/docs/build/plugins/rpc/ | [docs-build-plugins-rpc.md](docs-build-plugins-rpc.md) |
| 39 | Build › Plugins | CLI | https://opencode.ai/v2/docs/build/plugins/cli/ | [docs-build-plugins-cli.md](docs-build-plugins-cli.md) |
| 40 | Build › Plugins | Migrate plugins from V1 | https://opencode.ai/v2/docs/build/plugins/migrate-v1/ | [docs-build-plugins-migrate-v1.md](docs-build-plugins-migrate-v1.md) |
| 41 | Build › Client | JavaScript | https://opencode.ai/v2/docs/build/client/ | [docs-build-client.md](docs-build-client.md) |
| 42 | Build › SDK | Overview | https://opencode.ai/v2/docs/build/sdk/ | [docs-build-sdk.md](docs-build-sdk.md) |
| 43 | Build › SDK | Cloudflare | https://opencode.ai/v2/docs/build/sdk/cloudflare/ | [docs-build-sdk-cloudflare.md](docs-build-sdk-cloudflare.md) |
| 44 | Build › Effect | Effect | https://opencode.ai/v2/docs/build/plugins/effect/ | [docs-build-plugins-effect.md](docs-build-plugins-effect.md) |
| 45 | Build › Effect | RPC | https://opencode.ai/v2/docs/build/plugins/effect/rpc/ | [docs-build-plugins-effect-rpc.md](docs-build-plugins-effect-rpc.md) |
| 46 | Build › Effect | Effect | https://opencode.ai/v2/docs/build/client/effect/ | [docs-build-client-effect.md](docs-build-client-effect.md) |
| 47 | Build › Effect | Effect | https://opencode.ai/v2/docs/build/sdk/effect/ | [docs-build-sdk-effect.md](docs-build-sdk-effect.md) |
| 48 | API | API (HTTP API reference, generated from OpenAPI) | https://opencode.ai/v2/docs/api | [docs-api.md](docs-api.md) |
| 49 | Console | Intro | https://opencode.ai/v2/docs/console/ | [docs-console.md](docs-console.md) |
| 50 | Console | Models | https://opencode.ai/v2/docs/console/models/ | [docs-console-models.md](docs-console-models.md) |
| 51 | Console | Websearch | https://opencode.ai/v2/docs/console/websearch/ | [docs-console-websearch.md](docs-console-websearch.md) |
| 52 | Console | Go | https://opencode.ai/v2/docs/console/go/ | [docs-console-go.md](docs-console-go.md) |
| 53 | Console › API | Inference API | https://opencode.ai/v2/docs/console/inference/ | [docs-console-inference.md](docs-console-inference.md) |
| 54 | Console › API | BYOK | https://opencode.ai/v2/docs/console/byok/ | [docs-console-byok.md](docs-console-byok.md) |
| 55 | Console › API | Budgets API | https://opencode.ai/v2/docs/console/budgets/ | [docs-console-budgets.md](docs-console-budgets.md) |

## Extra files

| File | What |
| --- | --- |
| [openapi.json](openapi.json) | Raw OpenAPI 3.1 document served at https://opencode.ai/v2/openapi.json (136 operations, 245 schemas). Authoritative for request/response shapes. |
| [docs-install-script.md](docs-install-script.md) | Verbatim `https://opencode.ai/v2/install` script + key facts + raw responses of the update metadata endpoint it uses. |
| [v2-release-commits.md](v2-release-commits.md) | Per-release commit subjects for v2.0.0 → v2.0.22 (no official release notes exist for 2.x). |

## V1 doc pages vs V2 (for the remote-client checklist)

V1 docs remain live at https://opencode.ai/docs/ (with a banner "OpenCode v2 is now available" linking to https://opencode.ai/v2). The V2 site has no page at the V1 slugs below (HTTP 404 checked 2026-10-02 for `/v2/docs/{server,sdk,lsp,modes,desktop,enterprise,github,custom-tools,rules,share,zen}/`).

| V1 page | V2 equivalent | Notes |
| --- | --- | --- |
| intro (install) | [docs-intro.md](docs-intro.md) | New installer URL `/v2/install`, npm `@opencode/cli`, brew `anomalyco/tap/opencode-v2`, AUR `opencode-beta`, Docker `ghcr.io/anomalyco/opencode:<2.x>`, standalone binaries, Electron desktop downloads. |
| server | [docs-cli-web.md](docs-cli-web.md), [docs-cli.md](docs-cli.md) (Background service), [docs-troubleshooting.md](docs-troubleshooting.md), [docs-api.md](docs-api.md) | No dedicated server page. `serve` flags documented: `--hostname`, `--port`, `--cors` (repeatable), `--service`. No mDNS in V2 docs. |
| sdk | [docs-build-client.md](docs-build-client.md) (`@opencode/client`, network) and [docs-build-sdk.md](docs-build-sdk.md) (`@opencode/sdk`, in-process host) | V1 `@opencode-ai/sdk` is replaced. |
| web | [docs-cli-web.md](docs-cli-web.md) | `opencode pair` one-time links + session cookie; service config via `opencode service set`. |
| tui | [docs-cli-tui.md](docs-cli-tui.md), [docs-cli-config.md](docs-cli-config.md), [docs-cli-keybinds.md](docs-cli-keybinds.md) | `tui.json` replaced by global `~/.config/opencode/cli.json`. |
| cli | [docs-cli.md](docs-cli.md), [docs-cli-commands.md](docs-cli-commands.md) | New: `service`, `pair`, `api`, `reload`, `mini`, `debug paths`, `uninstall`. |
| config | [docs-config.md](docs-config.md), [docs-migrate-v1.md](docs-migrate-v1.md) | Plural keys (`agents`, `commands`, `providers`, `permissions`, `plugins`, `snapshots`, `media`). |
| agents / modes | [docs-agents.md](docs-agents.md) | `mode` map merged into `agents` (`mode: primary|subagent|all`). |
| permissions | [docs-permissions.md](docs-permissions.md), [docs-policies.md](docs-policies.md) | Ordered rule array; actions renamed (`bash`→`shell`, `task`→`subagent`, `write/patch`→`edit`). |
| models | [docs-models.md](docs-models.md) | Variants as `provider/model#variant`. |
| providers | [docs-providers.md](docs-providers.md), [docs-cli-providers.md](docs-cli-providers.md) | Credentials in SQLite; imports legacy `auth.json`. |
| commands | [docs-commands.md](docs-commands.md) | `subtask` → `subagent` (background child). |
| skills | [docs-skills.md](docs-skills.md) | |
| tools / custom-tools | [docs-tools.md](docs-tools.md); custom tools via [docs-build-plugins.md](docs-build-plugins.md) | No `todowrite`/todo tool documented in V2. New `execute` (Code Mode), `browser` namespace. |
| mcp-servers | [docs-mcp-servers.md](docs-mcp-servers.md) | `mcp.servers.<name>`. |
| lsp | none | V2 accepts `lsp` config but does not run language servers (see migrate-v1). |
| formatters | [docs-formatters.md](docs-formatters.md) | |
| share | [docs-sharing.md](docs-sharing.md) | "OpenCode V2 does not support session sharing yet." |
| acp | [docs-cli-acp.md](docs-cli-acp.md) | |
| plugins | [docs-plugins.md](docs-plugins.md), [docs-build-plugins.md](docs-build-plugins.md), [docs-build-plugins-migrate-v1.md](docs-build-plugins-migrate-v1.md) | V1 plugins do not run in V2. |
| rules | [docs-instructions.md](docs-instructions.md) | `AGENTS.md` only; no `CLAUDE.md` fallback; `instructions` config accepted but not loaded. |
| references | [docs-references.md](docs-references.md) | |
| network | [docs-network.md](docs-network.md) | |
| troubleshooting | [docs-troubleshooting.md](docs-troubleshooting.md) | |
| themes / keybinds | [docs-themes.md](docs-themes.md), [docs-cli-theme.md](docs-cli-theme.md), [docs-cli-keybinds.md](docs-cli-keybinds.md) | |
| zen / go | [docs-console.md](docs-console.md), [docs-console-models.md](docs-console-models.md), [docs-console-go.md](docs-console-go.md), [docs-console-inference.md](docs-console-inference.md), [docs-console-byok.md](docs-console-byok.md), [docs-console-budgets.md](docs-console-budgets.md), [docs-console-websearch.md](docs-console-websearch.md) | "Zen" branding replaced by "OpenCode Console" in V2 docs (endpoints still under `opencode.ai/zen/...` and `opencode.ai/inference/...`). |
| enterprise, github, gitlab, ide, ecosystem, windows-wsl | none | No V2 pages. |
| (new in V2) | [docs-snapshots.md](docs-snapshots.md), [docs-compaction.md](docs-compaction.md), [docs-attachments.md](docs-attachments.md), [docs-warming.md](docs-warming.md), [docs-websearch.md](docs-websearch.md), [docs-policies.md](docs-policies.md), [docs-build-plugins-rpc.md](docs-build-plugins-rpc.md), [docs-build-sdk-cloudflare.md](docs-build-sdk-cloudflare.md) | |
