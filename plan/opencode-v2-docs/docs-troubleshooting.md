# Troubleshooting

- Source URL: https://opencode.ai/v2/docs/troubleshooting/
- Source file: https://github.com/anomalyco/opencode/blob/bb381e8bdd1ff22c7329e07c068ec0099031f382/services/www/src/docs/content/troubleshooting.mdx
- Fetched: 2026-10-02 (OpenCode V2 docs; branch `v2` @ `bb381e8bdd`; latest release at fetch time: 2.0.21)
- Note: content is the verbatim MDX source rendered at the URL above; MDX components (CodeTabs, Callout, Card, PlanTabs, table wrappers) were flattened to Markdown and docs-relative links made absolute. No text was summarized or omitted.

---
> **Tip:**
> You can ask OpenCode to debug itself. Describe the problem and ask it to use this troubleshooting page; it can read
> the steps below, inspect its service and logs, and help identify the issue.

OpenCode uses a client-server architecture. A background server owns sessions, plugins, permissions, and other application
state. Start by determining whether an issue is in a client, the shared server, or a specific project.

## Check the background service

Show the current server information:

```bash
opencode service status
```

Verify that its API is healthy:

```bash
opencode api get /api/info
```

If the service is stuck or unhealthy, restart it:

```bash
opencode service restart
```

You can also stop and start it explicitly:

```bash
opencode service stop
opencode service start
```

> **Note:**
> OpenCode normally discovers or starts the shared background service automatically. The service commands are only
> needed when diagnosing its lifecycle.

## Allow a browser origin

If a browser client on another origin cannot connect because of CORS, add the client's origin to the service configuration:

```bash
opencode service set cors http://192.168.1.10:3001
opencode service get cors
```

Use an exact HTTP or HTTPS origin, including the port when needed, without a path or trailing slash. To allow multiple
origins, pass a comma-separated list as one argument; whitespace around each origin is trimmed:

```bash
opencode service set cors "http://192.168.1.10:3001, https://app.example.com"
```

`service get cors` prints a JSON array. Remove the configured list with:

```bash
opencode service unset cors
```

Setting or unsetting service configuration stops the background service. Its next start picks up the new configuration;
use `opencode service start` to start it explicitly.

For a foreground server, repeat `--cors` for each additional allowed origin:

```bash
opencode serve --cors http://192.168.1.10:3001 --cors https://app.example.com
```

With `serve --service`, supplied `--cors` flags override the persisted list for that process. Without those flags, service
mode uses the persisted list. CORS does not change the listening address or bypass server authentication.

## Inspect the API

The `api` command uses the local service discovery and authentication flow. It accepts either an HTTP method and path or an
OpenAPI operation ID.

See the [API reference](https://opencode.ai/v2/docs/api) for all endpoints and operation IDs.

Pass a JSON request body with `--data` or `-d`, and add headers with `--header` or `-H`.

> **Warning:**
> Running `opencode api` may start the background service when no compatible healthy service is available.

## Read logs

Installed builds write logs to:

```text
~/.local/share/opencode/log/opencode.log
```

Follow the log while reproducing the problem:

```bash
tail -f ~/.local/share/opencode/log/opencode.log
```

Each line includes a process `run` ID and a `role` field. Use `role=server` for session, provider, plugin, permission, and
tool activity.

```bash
grep 'role=server' ~/.local/share/opencode/log/opencode.log
grep 'run=8fc3b1d5' ~/.local/share/opencode/log/opencode.log
```

## Capture CPU and memory profiles

On macOS and Linux, you can signal a running OpenCode process to capture diagnostic data. Get the background server PID
from the health endpoint:

```bash
opencode api get /api/info
```

Use the `pid` from the response with one of these signals:

- `SIGPROF` captures a ten-second CPU profile:

  ```bash
  kill -SIGPROF <pid>
  ```

  The result is written to the log directory as `cpu-<pid>-<timestamp>.cpuprofile`.

- `SIGUSR1` captures a memory (heap) snapshot:

  ```bash
  kill -SIGUSR1 <pid>
  ```

  The result is written to the log directory as `heap-<pid>-<timestamp>.heapsnapshot`.

Wait for `CPU profile written` or `heap snapshot written` in `opencode.log` before opening the file. The corresponding
log entry includes its complete path. You can inspect both file types in Chrome DevTools.

> **Note:**
> Signal-triggered profiles are not available on Windows. Writing a heap snapshot can pause the process and temporarily
> increase its memory usage.

## Service files

The shared server registers itself at:

```text
~/.local/state/opencode/service.json
```

Its private service configuration is stored separately at:

```text
~/.config/opencode/service.json
```

The database normally lives at:

```text
~/.local/share/opencode/opencode.db
```

`OPENCODE_DB` can override the database location.

> **Warning:**
> Do not delete or edit service files or the database while troubleshooting. Use the service commands to manage the
> daemon, and make a backup before inspecting persistent data with external tools.

## Report an issue

Include the following when reporting a reproducible problem:

- Output from `opencode --version`
- Output from `opencode service status`
- The smallest sequence of steps that reproduces the issue
- Whether the issue affects the shared service, a specific client, or one project
- Relevant log lines, including their `run` and `role` fields

Remove API keys, authorization headers, prompts, file contents, and other sensitive data before sharing logs.

File reproducible problems in [GitHub Issues](https://github.com/anomalyco/opencode/issues).
