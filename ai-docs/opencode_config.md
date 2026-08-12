Title: Config

URL Source: https://opencode.ai/docs/config/

Markdown Content:
You can configure OpenCode using a JSON config file.

* * *

## [Format](https://opencode.ai/docs/config/#format)

OpenCode supports both **JSON** and **JSONC** (JSON with Comments) formats.

`{  "$schema": "https://opencode.ai/config.json",  "model": "anthropic/claude-sonnet-4-5",  "autoupdate": true,  "server": {    "port": 4096,  },}`

* * *

## [Locations](https://opencode.ai/docs/config/#locations)

You can place your config in a couple of different locations and they have a different order of precedence.

Configuration files are merged together, not replaced. Settings from the following config locations are combined. Later configs override earlier ones only for conflicting keys. Non-conflicting settings from all configs are preserved.

For example, if your global config sets `autoupdate: true` and your project config sets `model: "anthropic/claude-sonnet-4-5"`, the final configuration will include both settings.

* * *

### [Precedence order](https://opencode.ai/docs/config/#precedence-order)

Config sources are loaded in this order (later sources override earlier ones):

1.   **Remote config** (from `.well-known/opencode`) - organizational defaults
2.   **Global config** (`~/.config/opencode/opencode.json`) - user preferences
3.   **Custom config** (`OPENCODE_CONFIG` env var) - custom overrides
4.   **Project config** (`opencode.json` in project) - project-specific settings
5.   **`.opencode` directories** - agents, commands, plugins
6.   **Inline config** (`OPENCODE_CONFIG_CONTENT` env var) - runtime overrides
7.   **Managed config files** (`/Library/Application Support/opencode/` on macOS) - admin-controlled
8.   **macOS managed preferences** (`.mobileconfig` via MDM) - highest priority, not user-overridable

This means project configs can override global defaults, and global configs can override remote organizational defaults. Managed settings override everything.

* * *

### [Remote](https://opencode.ai/docs/config/#remote)

Organizations can provide default configuration via the `.well-known/opencode` endpoint. This is fetched automatically when you authenticate with a provider that supports it.

Remote config is loaded first, serving as the base layer. All other config sources (global, project) can override these defaults.

For example, if your organization provides MCP servers that are disabled by default:

`{  "mcp": {    "jira": {      "type": "remote",      "url": "https://jira.example.com/mcp",      "enabled": false    }  }}`

You can enable specific servers in your local config:

`{  "mcp": {    "jira": {      "type": "remote",      "url": "https://jira.example.com/mcp",      "enabled": true    }  }}`

* * *

### [Global](https://opencode.ai/docs/config/#global)

Place your global OpenCode config in `~/.config/opencode/opencode.json`. Use global config for user-wide server/runtime preferences like providers, models, and permissions.

For TUI-specific settings, use `~/.config/opencode/tui.json`.

Global config overrides remote organizational defaults.

* * *

### [Per project](https://opencode.ai/docs/config/#per-project)

Add `opencode.json` in your project root. Project config has the highest precedence among standard config files - it overrides both global and remote configs.

For project-specific TUI settings, add `tui.json` alongside it.

When OpenCode starts up, it first looks for a config file in the current directory, then traverses up to the nearest Git directory.

This is also safe to be checked into Git and uses the same schema as the global one.

* * *

### [Custom path](https://opencode.ai/docs/config/#custom-path)

Specify a custom config file path using the `OPENCODE_CONFIG` environment variable.

`export OPENCODE_CONFIG=/path/to/my/custom-config.jsonopencode run "Hello world"`

Custom config is loaded between global and project configs in the precedence order.

* * *

### [Custom directory](https://opencode.ai/docs/config/#custom-directory)

Specify a custom config directory using the `OPENCODE_CONFIG_DIR` environment variable. This directory will be searched for agents, commands, modes, and plugins just like the standard `.opencode` directory, and should follow the same structure.

`export OPENCODE_CONFIG_DIR=/path/to/my/config-directoryopencode run "Hello world"`

The custom directory is loaded after the global config and `.opencode` directories, so it **can override** their settings.

* * *

### [Managed settings](https://opencode.ai/docs/config/#managed-settings)

Organizations can enforce configuration that users cannot override. Managed settings are loaded at the highest priority tier.

#### [File-based](https://opencode.ai/docs/config/#file-based)

Drop an `opencode.json` or `opencode.jsonc` file in the system managed config directory:

| Platform | Path |
| --- | --- |
| macOS | `/Library/Application Support/opencode/` |
| Linux | `/etc/opencode/` |
| Windows | `%ProgramData%\opencode` |

These directories require admin/root access to write, so users cannot modify them.

#### [macOS managed preferences](https://opencode.ai/docs/config/#macos-managed-preferences)

On macOS, OpenCode reads managed preferences from the `ai.opencode.managed` preference domain. Deploy a `.mobileconfig` via MDM (Jamf, Kandji, FleetDM) and the settings are enforced automatically.

OpenCode checks these paths:

1.   `/Library/Managed Preferences/<user>/ai.opencode.managed.plist`
2.   `/Library/Managed Preferences/ai.opencode.managed.plist`

The plist keys map directly to `opencode.json` fields. MDM metadata keys (`PayloadUUID`, `PayloadType`, etc.) are stripped automatically.

**Creating a `.mobileconfig`**

Use the `ai.opencode.managed` PayloadType. The OpenCode config keys go directly in the payload dict:

`<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"  "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict>  <key>PayloadContent</key>  <array>    <dict>      <key>PayloadType</key>      <string>ai.opencode.managed</string>      <key>PayloadIdentifier</key>      <string>com.example.opencode.config</string>      <key>PayloadUUID</key>      <string>GENERATE-YOUR-OWN-UUID</string>      <key>PayloadVersion</key>      <integer>1</integer>      <key>share</key>      <string>disabled</string>      <key>server</key>      <dict>        <key>hostname</key>        <string>127.0.0.1</string>      </dict>      <key>permission</key>      <dict>        <key>*</key>        <string>ask</string>        <key>bash</key>        <dict>          <key>*</key>          <string>ask</string>          <key>rm -rf *</key>          <string>deny</string>        </dict>      </dict>    </dict>  </array>  <key>PayloadType</key>  <string>Configuration</string>  <key>PayloadIdentifier</key>  <string>com.example.opencode</string>  <key>PayloadUUID</key>  <string>GENERATE-YOUR-OWN-UUID</string>  <key>PayloadVersion</key>  <integer>1</integer></dict></plist>`

Generate unique UUIDs with `uuidgen`. Customize the settings to match your organization’s requirements.

**Deploying via MDM**

*   **Jamf Pro:** Computers > Configuration Profiles > Upload > scope to target devices or smart groups
*   **FleetDM:** Add the `.mobileconfig` to your gitops repo under `mdm.macos_settings.custom_settings` and run `fleetctl apply`

**Verifying on a device**

Double-click the `.mobileconfig` to install locally for testing (shows in System Settings > Privacy & Security > Profiles), then run:

`opencode debug config`

All managed preference keys appear in the resolved config and cannot be overridden by user or project configuration.

* * *

## [Schema](https://opencode.ai/docs/config/#schema)

The server/runtime config schema is defined in [**`opencode.ai/config.json`**](https://opencode.ai/config.json).

TUI config uses [**`opencode.ai/tui.json`**](https://opencode.ai/tui.json).

Your editor should be able to validate and autocomplete based on the schema.

* * *

### [TUI](https://opencode.ai/docs/config/#tui)

Use a dedicated `tui.json` (or `tui.jsonc`) file for TUI-specific settings.

`{  "$schema": "https://opencode.ai/tui.json",  "scroll_speed": 3,  "scroll_acceleration": {    "enabled": true  },  "diff_style": "auto",  "cursor": {    "style": "block",    "blinking": true  },  "mouse": true,  "attention": {    "enabled": true,    "notifications": true,    "sound": true,    "volume": 0.4  }}`

Use `OPENCODE_TUI_CONFIG` to point to a custom TUI config file.

When `cursor.style` is `"default"`, the terminal default cursor is restored, so `cursor.blinking` has no effect.

Set `attention.enabled` to turn on TUI desktop notifications and sounds. See [TUI attention](https://opencode.ai/docs/tui#attention).

Legacy `theme`, `keybinds`, and `tui` keys in `opencode.json` are deprecated and automatically migrated when possible.

* * *

### [Server](https://opencode.ai/docs/config/#server)

You can configure server settings for the `opencode serve` and `opencode web` commands through the `server` option.

`{  "$schema": "https://opencode.ai/config.json",  "server": {    "port": 4096,    "hostname": "0.0.0.0",    "mdns": true,    "mdnsDomain": "myproject.local",    "cors": ["http://localhost:5173"]  }}`

Available options:

*   `port` - Port to listen on.
*   `hostname` - Hostname to listen on. When `mdns` is enabled and no hostname is set, defaults to `0.0.0.0`.
*   `mdns` - Enable mDNS service discovery. This allows other devices on the network to discover your OpenCode server.
*   `mdnsDomain` - Custom domain name for mDNS service. Defaults to `opencode.local`. Useful for running multiple instances on the same network.
*   `cors` - Additional origins to allow for CORS when using the HTTP server from a browser-based client. Values must be full origins (scheme + host + optional port), eg `https://app.example.com`.

[Learn more about the server here](https://opencode.ai/docs/server).

* * *

### [Shell](https://opencode.ai/docs/config/#shell)

You can configure the shell used for the interactive terminal using the `shell` option. Compatible shells are also used for agent tool calls.

`{  "$schema": "https://opencode.ai/config.json",  "shell": "pwsh"}`

If not specified, OpenCode will automatically discover and use a sensible default based on your operating system (e.g. `pwsh` or `cmd.exe` on Windows, `/bin/zsh` or `/bin/bash` on macOS/Linux). You can provide an absolute path or a short name.

* * *

### [Tools](https://opencode.ai/docs/config/#tools)

You can manage the tools an LLM can use through the `tools` option.

`{  "$schema": "https://opencode.ai/config.json",  "tools": {    "write": false,    "bash": false  }}`

[Learn more about tools here](https://opencode.ai/docs/tools).

* * *

### [Models](https://opencode.ai/docs/config/#models)

You can configure the providers and models you want to use in your OpenCode config through the `provider`, `model` and `small_model` options.

`{  "$schema": "https://opencode.ai/config.json",  "provider": {},  "model": "anthropic/claude-sonnet-4-5",  "small_model": "anthropic/claude-haiku-4-5"}`

The `small_model` option configures a separate model for lightweight tasks like title generation. By default, OpenCode tries to use a cheaper model if one is available from your provider, otherwise it falls back to your main model.

Provider options can include `timeout`, `chunkTimeout`, and `setCacheKey`:

`{  "$schema": "https://opencode.ai/config.json",  "provider": {    "anthropic": {      "options": {        "timeout": 600000,        "chunkTimeout": 30000,        "setCacheKey": true      }    }  }}`

*   `timeout` - Request timeout in milliseconds (default: 300000). Set to `false` to disable.
*   `chunkTimeout` - Timeout in milliseconds between streamed response chunks. If no chunk arrives in time, the request is aborted.
*   `setCacheKey` - Ensure a cache key is always set for designated provider.

You can also configure [local models](https://opencode.ai/docs/models#local). [Learn more](https://opencode.ai/docs/models).

* * *

### [Policies](https://opencode.ai/docs/config/#policies)

Use the `experimental.policies` option to allow or deny OpenCode actions on configured resources. Currently, policies can control which providers OpenCode may use.

`{  "$schema": "https://opencode.ai/config.json",  "experimental": {    "policies": [      {        "effect": "deny",        "action": "provider.use",        "resource": "openai"      }    ]  }}`

[Learn more about policies here](https://opencode.ai/docs/policies).

* * *

### [Image attachments](https://opencode.ai/docs/config/#image-attachments)

OpenCode normalizes image attachments before sending them to the model. By default, images are resized when they exceed `2000x2000` pixels or `5242880` base64 bytes.

Configure image attachment limits with the `attachment.image` option:

`{  "$schema": "https://opencode.ai/config.json",  "attachment": {    "image": {      "auto_resize": true,      "max_width": 2000,      "max_height": 2000,      "max_base64_bytes": 5242880    }  }}`

*   `auto_resize` - Resize images that exceed the configured limits before provider requests. Set to `false` to reject oversized images instead.
*   `max_width` - Maximum image width in pixels before resizing or rejection.
*   `max_height` - Maximum image height in pixels before resizing or rejection.
*   `max_base64_bytes` - Maximum encoded image payload size. This is the base64 payload size, not the original file size.

If an image still cannot fit after resizing, OpenCode omits oversized tool-result images or fails oversized user-provided images with an image size error.

* * *

#### [Provider-Specific Options](https://opencode.ai/docs/config/#provider-specific-options)

Some providers support additional configuration options beyond the generic `timeout` and `apiKey` settings.

##### [Amazon Bedrock](https://opencode.ai/docs/config/#amazon-bedrock)

Amazon Bedrock supports AWS-specific configuration:

`{  "$schema": "https://opencode.ai/config.json",  "provider": {    "amazon-bedrock": {      "options": {        "region": "us-east-1",        "profile": "my-aws-profile",        "endpoint": "https://bedrock-runtime.us-east-1.vpce-xxxxx.amazonaws.com"      }    }  }}`

*   `region` - AWS region for Bedrock (defaults to `AWS_REGION` env var or `us-east-1`)
*   `profile` - AWS named profile from `~/.aws/credentials` (defaults to `AWS_PROFILE` env var)
*   `endpoint` - Custom endpoint URL for VPC endpoints. This is an alias for the generic `baseURL` option using AWS-specific terminology. If both are specified, `endpoint` takes precedence.

[Learn more about Amazon Bedrock configuration](https://opencode.ai/docs/providers#amazon-bedrock).

* * *

### [Themes](https://opencode.ai/docs/config/#themes)

Set your UI theme in `tui.json`.

`{  "$schema": "https://opencode.ai/tui.json",  "theme": "tokyonight"}`

[Learn more here](https://opencode.ai/docs/themes).

* * *

### [Agents](https://opencode.ai/docs/config/#agents)

You can configure specialized agents for specific tasks through the `agent` option.

`{  "$schema": "https://opencode.ai/config.json",  "agent": {    "code-reviewer": {      "description": "Reviews code for best practices and potential issues",      "model": "anthropic/claude-sonnet-4-5",      "prompt": "You are a code reviewer. Focus on security, performance, and maintainability.",      "tools": {        // Disable file modification tools for review-only agent        "write": false,        "edit": false,      },    },  },}`

You can also define agents using markdown files in `~/.config/opencode/agents/` or `.opencode/agents/`. [Learn more here](https://opencode.ai/docs/agents).

* * *

### [Default agent](https://opencode.ai/docs/config/#default-agent)

You can set the default agent using the `default_agent` option. This determines which agent is used when none is explicitly specified.

`{  "$schema": "https://opencode.ai/config.json",  "default_agent": "plan"}`

The default agent must be a primary agent (not a subagent). This can be a built-in agent like `"build"` or `"plan"`, or a [custom agent](https://opencode.ai/docs/agents) you’ve defined. If the specified agent doesn’t exist or is a subagent, OpenCode will fall back to `"build"` with a warning.

This setting applies across all interfaces: TUI, CLI (`opencode run`), desktop app, and GitHub Action.

* * *

### [Subagent depth](https://opencode.ai/docs/config/#subagent-depth)

You can control how deeply subagents can invoke other subagents using the `subagent_depth` option.

`{  "$schema": "https://opencode.ai/config.json",  "subagent_depth": 2}`

The default is `1`, which allows primary agents to launch subagents but prevents those subagents from launching additional subagents. Set it to `2` to allow one additional level of nested subagents, or `0` to prevent all subagent launches.

* * *

### [Sharing](https://opencode.ai/docs/config/#sharing)

You can configure the [share](https://opencode.ai/docs/share) feature through the `share` option.

`{  "$schema": "https://opencode.ai/config.json",  "share": "manual"}`

This takes:

*   `"manual"` - Allow manual sharing via commands (default)
*   `"auto"` - Automatically share new conversations
*   `"disabled"` - Disable sharing entirely

By default, sharing is set to manual mode where you need to explicitly share conversations using the `/share` command.

* * *

### [Commands](https://opencode.ai/docs/config/#commands)

You can configure custom commands for repetitive tasks through the `command` option.

`{  "$schema": "https://opencode.ai/config.json",  "command": {    "test": {      "template": "Run the full test suite with coverage report and show any failures.\nFocus on the failing tests and suggest fixes.",      "description": "Run tests with coverage",      "agent": "build",      "model": "anthropic/claude-haiku-4-5",    },    "component": {      "template": "Create a new React component named $ARGUMENTS with TypeScript support.\nInclude proper typing and basic structure.",      "description": "Create a new component",    },  },}`

You can also define commands using markdown files in `~/.config/opencode/commands/` or `.opencode/commands/`. [Learn more here](https://opencode.ai/docs/commands).

* * *

### [Keybinds](https://opencode.ai/docs/config/#keybinds)

Customize TUI keyboard shortcuts in `tui.json` with `keybinds`.

`{  "$schema": "https://opencode.ai/tui.json",  "keybinds": {    "command_list": "ctrl+p"  }}`

`keybinds` is merged with built-in defaults, so you only need to configure the shortcuts you want to change.

[Learn more here](https://opencode.ai/docs/keybinds).

* * *

### [Snapshot](https://opencode.ai/docs/config/#snapshot)

OpenCode uses snapshots to track file changes during agent operations, enabling you to undo and revert changes within a session. Snapshots are enabled by default.

For large repositories or projects with many submodules, the snapshot system can cause slow indexing and significant disk usage as it tracks all changes using an internal git repository. You can disable snapshots using the `snapshot` option.

`{  "$schema": "https://opencode.ai/config.json",  "snapshot": false}`

Note that disabling snapshots means changes made by the agent cannot be rolled back through the UI.

* * *

### [Autoupdate](https://opencode.ai/docs/config/#autoupdate)

OpenCode will automatically download any new updates when it starts up. You can disable this with the `autoupdate` option.

`{  "$schema": "https://opencode.ai/config.json",  "autoupdate": false}`

If you don’t want updates but want to be notified when a new version is available, set `autoupdate` to `"notify"`. Notice that this only works if it was not installed using a package manager such as Homebrew.

* * *

### [Formatters](https://opencode.ai/docs/config/#formatters)

You can enable and configure code formatters through the `formatter` option. Omit it to keep formatters disabled.

`{  "$schema": "https://opencode.ai/config.json",  "formatter": true}`

Use an object to keep built-ins enabled while configuring overrides or custom formatters.

`{  "$schema": "https://opencode.ai/config.json",  "formatter": {    "prettier": {      "disabled": true    },    "custom-prettier": {      "command": ["npx", "prettier", "--write", "$FILE"],      "environment": {        "NODE_ENV": "development"      },      "extensions": [".js", ".ts", ".jsx", ".tsx"]    }  }}`

[Learn more about formatters here](https://opencode.ai/docs/formatters).

* * *

### [LSP Servers](https://opencode.ai/docs/config/#lsp-servers)

You can enable and configure LSP servers through the `lsp` option. Omit it to keep LSP disabled.

`{  "$schema": "https://opencode.ai/config.json",  "lsp": true}`

Use an object to keep built-ins enabled while configuring overrides or custom LSP servers.

`{  "$schema": "https://opencode.ai/config.json",  "lsp": {    "typescript": {      "disabled": true    }  }}`

[Learn more about LSP servers here](https://opencode.ai/docs/lsp).

* * *

### [Permissions](https://opencode.ai/docs/config/#permissions)

By default, opencode **allows all operations** without requiring explicit approval. You can change this using the `permission` option.

For example, to ensure that the `edit` and `bash` tools require user approval:

`{  "$schema": "https://opencode.ai/config.json",  "permission": {    "edit": "ask",    "bash": "ask"  }}`

[Learn more about permissions here](https://opencode.ai/docs/permissions).

* * *

### [Compaction](https://opencode.ai/docs/config/#compaction)

You can control context compaction behavior through the `compaction` option.

`{  "$schema": "https://opencode.ai/config.json",  "compaction": {    "auto": true,    "prune": false,    "reserved": 10000  }}`

*   `auto` - Automatically compact the session when context is full (default: `true`).
*   `prune` - Remove old tool outputs to save tokens (default: `false`). Set to `true` to enable pruning.
*   `reserved` - Token buffer for compaction. Leaves enough window to avoid overflow during compaction.

* * *

### [Watcher](https://opencode.ai/docs/config/#watcher)

You can configure file watcher ignore patterns through the `watcher` option.

`{  "$schema": "https://opencode.ai/config.json",  "watcher": {    "ignore": ["node_modules/**", "dist/**", ".git/**"]  }}`

Patterns follow glob syntax. Use this to exclude noisy directories from file watching.

* * *

### [MCP servers](https://opencode.ai/docs/config/#mcp-servers)

You can configure MCP servers you want to use through the `mcp` option.

`{  "$schema": "https://opencode.ai/config.json",  "mcp": {}}`

[Learn more here](https://opencode.ai/docs/mcp-servers).

* * *

### [Plugins](https://opencode.ai/docs/config/#plugins)

[Plugins](https://opencode.ai/docs/plugins) extend OpenCode with custom tools, hooks, and integrations.

Place plugin files in `.opencode/plugins/` or `~/.config/opencode/plugins/`. You can also load plugins from npm through the `plugin` option.

`{  "$schema": "https://opencode.ai/config.json",  "plugin": ["opencode-helicone-session", "@my-org/custom-plugin"]}`

[Learn more here](https://opencode.ai/docs/plugins).

* * *

### [Instructions](https://opencode.ai/docs/config/#instructions)

You can configure the instructions for the model you’re using through the `instructions` option.

`{  "$schema": "https://opencode.ai/config.json",  "instructions": ["CONTRIBUTING.md", "docs/guidelines.md", ".cursor/rules/*.md"]}`

This takes an array of paths and glob patterns to instruction files. [Learn more about rules here](https://opencode.ai/docs/rules).

* * *

### [Disabled providers](https://opencode.ai/docs/config/#disabled-providers)

You can disable providers that are loaded automatically through the `disabled_providers` option. This is useful when you want to prevent certain providers from being loaded even if their credentials are available.

`{  "$schema": "https://opencode.ai/config.json",  "disabled_providers": ["openai", "gemini"]}`

The `disabled_providers` option accepts an array of provider IDs. When a provider is disabled:

*   It won’t be loaded even if environment variables are set.
*   It won’t be loaded even if API keys are configured through the `/connect` command.
*   The provider’s models won’t appear in the model selection list.

* * *

### [Enabled providers](https://opencode.ai/docs/config/#enabled-providers)

You can specify an allowlist of providers through the `enabled_providers` option. When set, only the specified providers will be enabled and all others will be ignored.

`{  "$schema": "https://opencode.ai/config.json",  "enabled_providers": ["anthropic", "openai"]}`

This is useful when you want to restrict OpenCode to only use specific providers rather than disabling them one by one.

If a provider appears in both `enabled_providers` and `disabled_providers`, the `disabled_providers` takes priority for backwards compatibility.

* * *

### [Experimental](https://opencode.ai/docs/config/#experimental)

The `experimental` key contains options that are under active development.

`{  "$schema": "https://opencode.ai/config.json",  "experimental": {}}`

* * *

## [Variables](https://opencode.ai/docs/config/#variables)

You can use variable substitution in your config files to reference environment variables and file contents.

* * *

### [Env vars](https://opencode.ai/docs/config/#env-vars)

Use `{env:VARIABLE_NAME}` to substitute environment variables:

`{  "$schema": "https://opencode.ai/config.json",  "model": "{env:OPENCODE_MODEL}",  "provider": {    "anthropic": {      "models": {},      "options": {        "apiKey": "{env:ANTHROPIC_API_KEY}"      }    }  }}`

If the environment variable is not set, it will be replaced with an empty string.

* * *

### [Files](https://opencode.ai/docs/config/#files)

Use `{file:path/to/file}` to substitute the contents of a file:

`{  "$schema": "https://opencode.ai/config.json",  "instructions": ["./custom-instructions.md"],  "provider": {    "openai": {      "options": {        "apiKey": "{file:~/.secrets/openai-key}"      }    }  }}`

File paths can be:

*   Relative to the config file directory
*   Or absolute paths starting with `/` or `~`

These are useful for:

*   Keeping sensitive data like API keys in separate files.
*   Including large instruction files without cluttering your config.
*   Sharing common configuration snippets across multiple config files.
