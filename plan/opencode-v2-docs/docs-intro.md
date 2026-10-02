# Intro

- Source URL: https://opencode.ai/v2/docs/
- Source file: https://github.com/anomalyco/opencode/blob/bb381e8bdd1ff22c7329e07c068ec0099031f382/services/www/src/docs/content/index.mdx
- Fetched: 2026-10-02 (OpenCode V2 docs; branch `v2` @ `bb381e8bdd`; latest release at fetch time: 2.0.21)
- Note: content is the verbatim MDX source rendered at the URL above; MDX components (CodeTabs, Callout, Card, PlanTabs, table wrappers) were flattened to Markdown and docs-relative links made absolute. No text was summarized or omitted.

---
OpenCode is an open source AI coding agent. It’s available as a terminal-based interface, desktop app, or web app.

## CLI

**curl**

```bash
curl -fsSL https://opencode.ai/v2/install | bash
```

**homebrew**

```bash
brew install anomalyco/tap/opencode-v2
```

**npm**

```bash
npm install -g @opencode/cli
```

**bun**

```bash
bun install -g --trust @opencode/cli
```

**pnpm**

```bash
pnpm add -g --allow-build=@opencode/cli @opencode/cli
```

**yarn**

```bash
yarn global add @opencode/cli
```

**vite+**

```bash
vp install -g @opencode/cli
```

**aur**

```bash
paru -S opencode-beta
```

The npm package uses a postinstall script to select the native `opencode` binary for your platform. The Bun and pnpm commands
explicitly allow the required script; Vite+ requires no additional flag.

Windows package managers are not supported.

Download a standalone CLI binary for your platform.

- **macOS:** [Apple silicon](https://opencode.ai/files/bin/2.0.6/opencode-darwin-arm64.zip) · [Intel](https://opencode.ai/files/bin/2.0.6/opencode-darwin-x64.zip) · [Intel (baseline)](https://opencode.ai/files/bin/2.0.6/opencode-darwin-x64-baseline.zip)
- **Windows:** [ARM64](https://opencode.ai/files/bin/2.0.6/opencode-windows-arm64.zip) · [x64](https://opencode.ai/files/bin/2.0.6/opencode-windows-x64.zip) · [x64 (baseline)](https://opencode.ai/files/bin/2.0.6/opencode-windows-x64-baseline.zip)
- **Linux (glibc):** [ARM64](https://opencode.ai/files/bin/2.0.6/opencode-linux-arm64.tar.gz) · [x64](https://opencode.ai/files/bin/2.0.6/opencode-linux-x64.tar.gz) · [x64 (baseline)](https://opencode.ai/files/bin/2.0.6/opencode-linux-x64-baseline.tar.gz)
- **Linux (musl):** [ARM64](https://opencode.ai/files/bin/2.0.6/opencode-linux-arm64-musl.tar.gz) · [x64](https://opencode.ai/files/bin/2.0.6/opencode-linux-x64-musl.tar.gz) · [x64 (baseline)](https://opencode.ai/files/bin/2.0.6/opencode-linux-x64-baseline-musl.tar.gz)

## Desktop

Download the latest OpenCode Desktop build for your platform.

- **macOS:** [Apple silicon](https://opencode.ai/files/bin/2.0.6/opencode-desktop-mac-arm64.dmg) · [Intel](https://opencode.ai/files/bin/2.0.6/opencode-desktop-mac-x64.dmg)
- **Windows:** [x64](https://opencode.ai/files/bin/2.0.6/opencode-desktop-win-x64.exe) · [ARM64](https://opencode.ai/files/bin/2.0.6/opencode-desktop-win-arm64.exe)
- **Linux (.deb):** [x64](https://opencode.ai/files/bin/2.0.6/opencode-desktop-linux-amd64.deb) · [ARM64](https://opencode.ai/files/bin/2.0.6/opencode-desktop-linux-arm64.deb)
- **Linux (.rpm):** [x64](https://opencode.ai/files/bin/2.0.6/opencode-desktop-linux-x86_64.rpm) · [ARM64](https://opencode.ai/files/bin/2.0.6/opencode-desktop-linux-aarch64.rpm)
- **Linux (AppImage):** [x64](https://opencode.ai/files/bin/2.0.6/opencode-desktop-linux-x86_64.AppImage) · [ARM64](https://opencode.ai/files/bin/2.0.6/opencode-desktop-linux-arm64.AppImage)

## Web

Access the OpenCode web interface with the `opencode pair` command.

```bash
$ opencode pair

  URLs      http://127.0.0.1:49374
  Username  opencode
  Password  ********
```

## Docker

Docker images use versioned tags, for example `ghcr.io/anomalyco/opencode:2.0.0`.

---

## Connect

OpenCode has built in support for many LLM providers - you can connect to them
directly [in the TUI](https://opencode.ai/v2/docs/cli/providers) with `/connect`.

See [Providers](https://opencode.ai/v2/docs/providers) to configure custom providers.

If you'd like easy access to all the best coding models you can try out
[OpenCode Console](https://opencode.ai/v2/docs/console).

You can also try [OpenCode Go](https://opencode.ai/v2/docs/console/go) a $10/month subscription
plan that grants you access to the best open source models.

---

## Customize

Make OpenCode your own by editing the [OpenCode config](https://opencode.ai/v2/docs/config), [loading plugins](https://opencode.ai/v2/docs/plugins), [connecting MCP
servers](https://opencode.ai/v2/docs/mcp-servers), or [creating commands](https://opencode.ai/v2/docs/commands). For terminal interface themes and keybindings, see [CLI
settings](https://opencode.ai/v2/docs/cli/config).
