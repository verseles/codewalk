# OpenCode v2 — Web Contract Anchor

> **Scope:** new CodeWalk v2 browser/connection consumers. Retained legacy implementation and `v1` maintenance use [the v1 Web anchor](../ai-docs/opencode_web.md). This is a curated pinned reference; it does not claim a CodeWalk v2 browser build or a passing platform experiment.

## Provenance

| Source | Versioned evidence |
|---|---|
| Official Web documentation | [Live page](https://opencode.ai/docs/cli/web/), MDX source [`services/site/src/docs/content/cli/web.mdx`](https://github.com/anomalyco/opencode/blob/c0ad18b402eb2827fc1ee71c171b1177b3fc02d1/services/site/src/docs/content/cli/web.mdx), rechecked 2026-11-22 |
| Docs route | `/docs/` is the V2 docs root and `/v1/docs/` holds the legacy set; `/v2/docs/` only answers `301` to `/docs/`. The old `services/www/src/docs/content/` path no longer exists at this pin |
| Server/client source pin | `v2.3.2` → `c0ad18b402eb2827fc1ee71c171b1177b3fc02d1`: [web shell](https://github.com/anomalyco/opencode/blob/c0ad18b402eb2827fc1ee71c171b1177b3fc02d1/packages/cli/src/services/web-ui.ts), [auth](https://github.com/anomalyco/opencode/blob/c0ad18b402eb2827fc1ee71c171b1177b3fc02d1/packages/server/src/auth.ts), [CORS](https://github.com/anomalyco/opencode/blob/c0ad18b402eb2827fc1ee71c171b1177b3fc02d1/packages/server/src/cors.ts) |
| Acceptance owners | SP-01 for pairing/auth; `V2-008` / SP-04 for real Chrome/Safari streaming, CORS/mixed content and PTY |

The V2 Web page lives at `/docs/cli/web/`. There is no dedicated `/docs/server/` page in the served index; use the [v2 server anchor](opencode_v2_server.md) and its primary protocol/handler sources.

## Shared service and sign-in

The official Web client and TUI can use the same per-user service. The default port is channel-derived and platform-specific: `49374` on macOS, Linux and WSL, and `28894` on Windows, where the channel port is remapped into `0x7000–0x7FFF` to avoid the dynamic range Windows reserves from `49152` up. `opencode service status` prints the address in use. A standalone foreground server is a distinct process/topology. A session-sharing claim must name the service actually connected, not merely the executable or URL.

`opencode pair` displays a one-time link and QR with a five-minute lifetime. Browser redemption signs in with a session cookie and redirects to the Web UI; the official app can also connect by scanning the QR or pasting the link into its server address field. The pinned auth implementation issues 30-day sessions signed with a key derived from the password, so changing the password signs every session out, and the cookie name carries the port so several local servers stay separate. A non-browser request accepting JSON receives a token usable in the Basic password position, with the fixed username `opencode`. See [server protocol](https://github.com/anomalyco/opencode/blob/c0ad18b402eb2827fc1ee71c171b1177b3fc02d1/packages/protocol/src/groups/server.ts) and the [server anchor](opencode_v2_server.md).

`opencode pair --remote` exposes the service through an OpenTunnel address instead of loopback. The first run asks before exposing the server to the internet and later runs skip the prompt, even after remote access is turned off; without an interactive terminal it needs `--yes`. Remote access is a service setting (`opencode service set remote`), not something a client toggles while connecting.

The docs call the Web UI password-protected. The pinned [web shell handler](https://github.com/anomalyco/opencode/blob/c0ad18b402eb2827fc1ee71c171b1177b3fc02d1/packages/cli/src/services/web-ui.ts) still serves the sign-in/static shell before API authentication: `/api/`, `/auth/` and `/openapi.json` go to the API handler, and everything else is served from the static bundle. Authenticated API access and publicly served HTML/assets are different boundaries, and HTML 200 alone is not authentication, readiness or protocol detection.

## Browser transport and origin boundary

- A browser must satisfy the server's CORS/origin policy. Native clients without an Origin header are a different transport case.
- The pinned policy accepts `http://localhost:<port>` and `http://127.0.0.1:<port>` origins, `oc://renderer`, the three Tauri origins, `https://opencode.ai` and its subdomains, and exact origins configured with `opencode service set cors <a,b>`; a request whose origin host equals the server host also passes. Inspect [CORS source](https://github.com/anomalyco/opencode/blob/c0ad18b402eb2827fc1ee71c171b1177b3fc02d1/packages/server/src/cors.ts) rather than infer access from successful native HTTP calls.
- Authenticated HTTP/SSE requests need their header/cookie strategy established on the actual target. CodeWalk's planned browser path uses fetch streaming with an Authorization header; SP-04 verifies Chrome/Safari behavior and preflight.
- An HTTPS Web page reaching plain HTTP on a LAN is a browser mixed-content question, not evidence that the OpenCode server is offline. Test the actual scheme/origin/topology; CORS configuration alone does not establish mixed-content support.
- PTY WebSockets use short-lived single-use tickets, sent in the `ticket` query when custom headers cannot be sent or in `x-opencode-ticket`. Upstream query-token support does not authorize putting long-lived CodeWalk credentials into URLs, logs or exported links.
- A closed browser tab does not keep the direct v2 client connected. Host-backed attention/push is later CodeWalk architecture, not a capability inferred from this Web documentation.

Changing shared-service settings can stop/restart it; the official page describes applying configuration before restarting. These are operator-owned actions, not commands performed by this documentation unit. User-managed SSH/VPN/TLS connectivity remains distinct from the app's API protocol.

## Observed Linux Chromium subset

[E native 2.0.22 captures](../test/contract/fixtures/opencode/2.0.22/e/README.md)
record authenticated `/api/info` and fetch-streamed global SSE from an allowed
localhost origin in Chromium151. The foreign-origin browser reads were blocked;
the fixture preserves actual HTTP/preflight headers separately from browser
readability. Shared-service settings were not changed. This is a loopback Chrome
subset on 2.0.22, not Safari, HTTPS-to-LAN mixed-content, custom-origin
configuration or PTY-ticket acceptance; SP-04 owns those remaining checks and a
revalidation on the 2.3.2 pin.

## Observed compiled Flutter Web subset

[SP-04 Chromium fixtures](../test/contract/fixtures/opencode/2.0.22/web/README.md)
record a compiled standalone Flutter app using Dart package:web Authorization
fetch, ReadableStream SSE and ticket WebSockets against native 2.0.22 on Linux
localhost. The browser recovered a stream gap from an authoritative snapshot,
then received live events. PTY reconnect replayed the missed marker once using
the native UTF-16 cursor, then accepted live input/output. Mint-header enforcement,
consumed/wrong-PTY/expired tickets and actual 62-second expiry were observed with
live targets. Foreign-origin Dart info/SSE/mint reads were blocked by preflight.
No native UTF-8 read boundary split was observed; controlled one-byte decoder
rechunking is labelled separately. Immutable 2.0.22 source excerpts and hashes
are in the fixture's `source-evidence.json`.

This standalone spike does not implement CodeWalk's production transport or
accept Safari, trusted HTTPS-to-actual-HTTP-LAN mixed content, configured-origin
service restart, foreground/background recovery or the terminal-on-Web product
decision. V2-008 remains partial. Browser origin, scheme and TLS checks were
preserved; the Chromium process sandbox was disabled for the disposable container.

## Observed configured-origin native HTTP subset

[The 2026-10-05 native diagnostic](https://github.com/verseles/codewalk/issues/247#issuecomment-5992914771)
records Linux ARM64 OpenCode 2.0.22 on an isolated loopback service. Setting the
exact origin `https://main.codewalk.pages.dev` stopped the owned initial process;
the next start and an additional stop/start retained the exact allow-origin header
on OPTIONS and authenticated `/api/info`. A lookalike origin received no
allow-origin header, unauthenticated GET returned 401, and a rejected trailing-slash
configuration left the running service and configuration metadata unchanged.
The issue preserves package hashes and separate immutable 2.0.22 source provenance.

Origin headers were supplied by a Python HTTP client. This observes native CORS
configuration/restart/persistence, not browser readability or configured-origin
Flutter streaming. The current `opencode service set cors` path writes the same
exact-origin list and still stops the service for the change to apply. Those
browser checks and the other SP-04 gates remain pending; the disposable service
and private runtime roots were cleaned up.

## Reference client and policy separation

The [official event reducer](../plan/opencode-v2-src/client-solid-data.reference-reducer.ts) is implementation evidence for native event reconciliation, not a dependency the Flutter UI imports. The canonical reducer and capability-driven screens belong to CodeWalk; wire DTOs stay inside its adapter.

Record which parts are source-verified versus actually observed: pairing redemption and expiry, CORS preflight, authenticated SSE, rejected origin, mixed content, disconnect/foreground recovery and PTY expiry/reconnect. Missing browser/native resources stay pending; they do not pass SP-01, SP-04 or the platform gates.

## Companion references

- [Official V2 documentation](https://opencode.ai/docs/) and [Web page](https://opencode.ai/docs/cli/web/).
- [HTTP transport/auth evidence](../plan/11-opencode-v2-server-api.md).
- [Server anchor](opencode_v2_server.md) and [model/agent anchor](opencode_v2_models.md).
- [Implementation plan](../v2-plan.md), §§5.1, 6.10, 11.3 and 15.4.
- [ADR registry](../ADR.md), ADR-023 principle and ADR-058 scoped v2 architecture.
