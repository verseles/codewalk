# Web

- Source URL: https://opencode.ai/v2/docs/cli/web/
- Source file: https://github.com/anomalyco/opencode/blob/bb381e8bdd1ff22c7329e07c068ec0099031f382/services/www/src/docs/content/cli/web.mdx
- Fetched: 2026-10-02 (OpenCode V2 docs; branch `v2` @ `bb381e8bdd`; latest release at fetch time: 2.0.21)
- Note: content is the verbatim MDX source rendered at the URL above; MDX components (CodeTabs, Callout, Card, PlanTabs, table wrappers) were flattened to Markdown and docs-relative links made absolute. No text was summarized or omitted.

_Run OpenCode in the browser._

---
OpenCode ships with a web ui that is served from the same server that powers the
TUI. It's available by default and password protected.

## Access

```bash
$ opencode pair

  Open a link to connect. Links work once and expire in 5 minutes.

  http://127.0.0.1:49374/auth/connect/...

  █▀▀▀▀▀█ ...
```

Opening a link in a browser signs it in with a session cookie and loads the web
ui. Scanning the QR code from the OpenCode app, or pasting the link into its
server address field, connects the app the same way. Sessions last 30 days;
changing the server password signs every session out.

### Over SSH

When the server listens only on localhost, forward its port from your machine
and open the printed link locally:

```bash
$ ssh -L 49374:127.0.0.1:49374 my-server
```

By default the server runs on port 49374 and listens only on localhost. You can
change this config with the `opencode service` command.

## Configure

Set any option with `opencode service set`:

```bash
# Listen on every network interface
$ opencode service set hostname 0.0.0.0

# Use a fixed port instead of the channel default
$ opencode service set port 49374

# Replace the generated password
$ opencode service set password "a-long-secret"

# Allow a web client served from another origin
$ opencode service set cors https://app.example.com,https://other.example.com

# Pass an environment variable to the server process
$ opencode service set env OPENCODE_LOG_LEVEL DEBUG
```

Changing a setting stops the background server. To apply the new config

```bash
$ opencode service start
```

## Standalone

`opencode serve` runs the same server in the foreground instead of through the
shared background service.

```bash
$ opencode serve --hostname 0.0.0.0 --port 4096
server listening on http://0.0.0.0:4096
server password <password>
```

Use it when you want to:

- Run OpenCode on a shared, always-on, or remote host, then connect clients with
  `opencode --server <url>`.
- Control the hostname, port, and CORS origins for a single process.
- Run under a supervisor like systemd, Docker, or another environment that expects
  a foreground process.
- Keep a dedicated server instead of the shared background service.

Connect a client to it with `--server`:

```bash
$ opencode --server http://127.0.0.1:4096
```
