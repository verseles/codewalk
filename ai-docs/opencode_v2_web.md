# OpenCode v2 — Web Contract Anchor

> **Scope:** new CodeWalk v2 browser/connection consumers. Retained legacy implementation and `v1` maintenance use [the v1 Web anchor](opencode_web.md). This is a curated pinned reference; it does not claim a CodeWalk v2 browser build or a passing platform experiment.

## Provenance

| Source | Versioned evidence |
|---|---|
| Official Web documentation | [Live page](https://opencode.ai/v2/docs/cli/web/), [immutable MDX source](https://github.com/anomalyco/opencode/blob/bb381e8bdd1ff22c7329e07c068ec0099031f382/services/www/src/docs/content/cli/web.mdx), [preserved snapshot](../plan/opencode-v2-docs/docs-cli-web.md), captured 2026-10-02 |
| Official docs source pin | `bb381e8bdd1ff22c7329e07c068ec0099031f382`; source existence rechecked through GitHub on 2026-10-03 |
| Server/client source pin | `v2.0.21` → `8a8bd622a3d7dc29ccf30ec17f84e363ed95ed72`; [web shell implementation](../plan/opencode-v2-src/cli/web-ui.ts), [auth](../plan/opencode-v2-src/server/auth.ts), [CORS](../plan/opencode-v2-src/server/cors.ts) |
| Acceptance owners | SP-01 for pairing/auth; `V2-008` / SP-04 for real Chrome/Safari streaming, CORS/mixed content and PTY |

The v2 Web page lives at `/v2/docs/cli/web/`, not the old `/docs/web/` route. There is no dedicated v2 `/docs/server/` counterpart in the captured index; use the [v2 server anchor](opencode_v2_server.md) and its primary protocol/handler sources.

## Shared service and sign-in

The official Web client and TUI can use the same per-user service. The documented default is loopback port `49374`; a standalone foreground server is a distinct process/topology. A session-sharing claim must name the service actually connected, not merely the executable or URL.

`opencode pair` displays a one-time link/QR with a five-minute lifetime. Browser redemption signs in with a cookie and redirects to the Web UI. The pinned auth implementation accepts a 30-day pairing session and revokes sessions when the server password changes. A non-browser request accepting JSON receives a token usable as the HTTP Basic password. See [server protocol](../plan/opencode-v2-src/protocol-groups/server.ts) and the [server anchor](opencode_v2_server.md).

The docs call the Web UI password-protected. The pinned [web shell handler](../plan/opencode-v2-src/cli/web-ui.ts) explicitly serves the sign-in/static shell before API authentication: authenticated API access and publicly served HTML/assets are different boundaries. HTML 200 alone is not authentication, readiness or protocol detection.

## Browser transport and origin boundary

- A browser must satisfy the server's CORS/origin policy. Native clients without an Origin header are a different transport case.
- The pinned policy allows localhost origins and selected official/client origins, plus configured exact origins. Request-origin checks also distinguish the server's own host. Inspect [CORS source](../plan/opencode-v2-src/server/cors.ts) rather than infer access from successful native HTTP calls.
- Authenticated HTTP/SSE requests need their header/cookie strategy established on the actual target. CodeWalk's planned browser path uses fetch streaming with an Authorization header; SP-04 verifies Chrome/Safari behavior and preflight.
- An HTTPS Web page reaching plain HTTP on a LAN is a browser mixed-content question, not evidence that the OpenCode server is offline. Test the actual scheme/origin/topology; CORS configuration alone does not establish mixed-content support.
- PTY WebSockets use short-lived tickets when custom headers cannot be sent. Upstream query-token support does not authorize putting long-lived CodeWalk credentials into URLs, logs or exported links.
- A closed browser tab does not keep the direct v2.0 client connected. Host-backed attention/push is later CodeWalk architecture, not a capability inferred from this Web documentation.

Changing shared-service settings can stop/restart it; the official page describes applying configuration before restarting. These are operator-owned actions, not commands performed by this documentation unit. User-managed SSH/VPN/TLS connectivity remains distinct from the app's API protocol.

## Observed Linux Chromium subset

[E native 2.0.22 captures](../test/contract/fixtures/opencode/2.0.22/e/README.md)
record authenticated `/api/info` and fetch-streamed global SSE from an allowed
localhost origin in Chromium151. The foreign-origin browser reads were blocked;
the fixture preserves actual HTTP/preflight headers separately from browser
readability. Shared-service settings were not changed. This is a loopback Chrome
subset, not Safari, HTTPS-to-LAN mixed-content, custom-origin configuration or
PTY-ticket acceptance; SP-04 owns those remaining checks.

## Reference client and policy separation

The [official event reducer](../plan/opencode-v2-src/client-solid-data.reference-reducer.ts) is implementation evidence for native event reconciliation, not a dependency the Flutter UI imports. The canonical reducer and capability-driven screens belong to CodeWalk; wire DTOs stay inside its adapter.

Record which parts are source-verified versus actually observed: pairing redemption and expiry, CORS preflight, authenticated SSE, rejected origin, mixed content, disconnect/foreground recovery and PTY expiry/reconnect. Missing browser/native resources stay pending; they do not pass SP-01, SP-04 or the platform gates.

## Companion references

- [Snapshot index and provenance](../plan/opencode-v2-docs/INDEX.md).
- [HTTP transport/auth evidence](../plan/11-opencode-v2-server-api.md).
- [Server anchor](opencode_v2_server.md) and [model/agent anchor](opencode_v2_models.md).
- [Implementation plan](../v2-plan.md), §§5.1, 6.10, 11.3 and 15.4.
- [ADR registry](../ADR.md), ADR-023 principle and ADR-058 scoped v2 architecture.
