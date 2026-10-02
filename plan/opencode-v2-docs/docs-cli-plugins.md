# Plugins

- Source URL: https://opencode.ai/v2/docs/cli/plugins/
- Source file: https://github.com/anomalyco/opencode/blob/bb381e8bdd1ff22c7329e07c068ec0099031f382/services/www/src/docs/content/cli/plugins.mdx
- Fetched: 2026-10-02 (OpenCode V2 docs; branch `v2` @ `bb381e8bdd`; latest release at fetch time: 2.0.21)
- Note: content is the verbatim MDX source rendered at the URL above; MDX components (CodeTabs, Callout, Card, PlanTabs, table wrappers) were flattened to Markdown and docs-relative links made absolute. No text was summarized or omitted.

---
Plugins configured in `opencode.json(c)` that expose a TUI component are loaded automatically by the CLI. To learn how
to build plugins, see [Building plugins](https://opencode.ai/v2/docs/build/plugins). You do not need to add the same package to `cli.json`. The CLI
gets the active plugin list from the connected OpenCode server, so this also works when the server is remote.

Use `cli.json` for CLI-only plugins. These plugins run locally in the terminal and remain active when the CLI connects
to a remote server:

```json title="cli.json"
{
  "plugins": [
    "opencode.example",
    "opencode.example@1.0.0",
    "@example/opencode-tui",
    "@example/opencode-tui@1.0.0",
    "./plugins/status",
    "../plugins/status",
    "/home/user/plugins/status",
    "file:///home/user/plugins/status"
  ]
}
```

Entries are processed in order. Prefix an ID or wildcard with `-` to disable matching plugins:

```json title="cli.json"
{
  "plugins": ["*", "-opencode.notifications", "-team.*"]
}
```

Pass plugin options with the object form:

```json title="cli.json"
{
  "plugins": [
    {
      "package": "@example/opencode-tui",
      "options": {
        "compact": true
      }
    }
  ]
}
```

OpenCode also discovers plugins under the global config directory and project `.opencode` directories. Each plugin uses
the same layout as a published package, with server and TUI entrypoints kept together.

```text title="Plugin discovery paths"
<global-config>/plugins/status/index.ts
<global-config>/plugins/status/tui.ts
<project>/.opencode/plugins/status/index.ts
<project>/.opencode/plugins/status/tui.ts
```

Discovered plugins can import `@opencode/plugin/tui` directly; OpenCode resolves the package at runtime. See
[Building CLI plugins](https://opencode.ai/v2/docs/build/plugins/cli) for examples.
