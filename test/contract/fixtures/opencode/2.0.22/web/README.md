# V2-008 — Chromium / compiled Flutter Web subset

**Partial evidence, not SP-04 acceptance.** The authorized Linux capture used
native OpenCode **2.0.22**, Flutter **3.44.0** / Dart **3.12.0**, package:web
**1.1.1** and Chromium **151.0.7922.173**. No provider/model requests were made;
cost was **USD 0**. #247 remains open.

[Approved preflight](https://github.com/verseles/codewalk/issues/247#issuecomment-5977121842).
The disposable project received Git commit
88a7e250a946a09f579ae3015c4c8c015b159a4f before native access.
The app/build lived outside the checkout. Shared-service configuration and
process were preserved.

## Observed transport

The actual compiled Dart app uses package:web window.fetch, Authorization,
AbortController and ReadableStreamDefaultReader. CDP automates and observes;
JavaScript does not substitute for Dart fetch, decoding, minting or WebSocket.

An allowed HTTP localhost page read /api/info and two incremental global SSE
streams. A native rename after opening the reader delivered **Olá 🚀** correctly.
The first stream received separate 96-byte and 345-byte reads. No observed read
boundary split a UTF-8 code point.

Explicit **client-controlled one-byte rechunking** of each received rename JSON
passed the Dart UTF-8 decoder. This is a controlled client scenario, not observed
network fragmentation.

After abort, a rename occurred during the gap. The next stream began with
server.connected; an authenticated Dart session GET recovered the current title.
A later rename arrived live. Recovery used **snapshot**, not SSE replay.

The same app on the foreign loopback-mapped cw-web-denied.test origin could not
read info, SSE or mint a ticket. Chromium reported CORS preflight rejection.
Native OPTIONS returned 204 for both origins; only localhost had
Access-Control-Allow-Origin. HTTP status and browser readability are separate.

## Observed PTY and tickets

Two native PTYs ran a fixed /bin/sh read/printf loop inside the disposable
project. Input was text, never evaluated. Native creation appended its login
shell argument; authoritative returned args are retained.

Dart fetch minted tickets with Authorization plus x-opencode-ticket: 1.
Dart WebSocket used only the ephemeral ticket query. Credentials and tickets
stayed in memory; URL/console exports redact tickets. Authenticated fetch omitted
cookies. No long-lived credential appeared in a URL, source, asset or storage.

The initial replay preceded an outbound binary **0x00 + UTF-8 JSON cursor**
frame. Dart applied it and advanced by each later text chunk's UTF-16
String.length, including echo and CRLF. Unicode and scheduling advanced cursor
**14 → 68**.

The browser disconnected after SCHEDULED. The process printed OFFLINE during the
gap. A fresh ticket and cursor 68 replayed OFFLINE once, without READY duplication;
metadata reported **84**. New input/output then arrived live, advancing to **121**.

With existing, running target PTYs, these failures were observed:

- Missing custom mint header: Dart HTTP **403**.
- Consumed ticket, ticket for the other live PTY and expired ticket: failed browser
  WebSockets; sanitized Chromium console reports handshake **403**.
- Real expiry wait **62.12 seconds**, greater than expires_in: 60.

CDP exposed only two successful **101** handshakes; it did not provide rejection
statuses. No missing/exited-target result is presented as ticket rejection.

The first PTY exited 0 after FINISH. Finally cleanup deleted both PTYs/session and
verified three GET 404s. A subsequent read-only procfs check found both owned
process IDs absent. The disposable Git project stayed clean. Native PID **126717**
and config/registration inode, size, mode and mtime remained unchanged. Credential
files were not read or hashed.

## Static contract and pending resources

Official source pin: **05018b8862a8fc198ec9810aafd397c96bb7d86e**, version 2.0.22.
source-evidence.json preserves immutable raw URLs, source hashes and numbered
excerpts:

- [Mint/origin/connect](https://github.com/anomalyco/opencode/blob/05018b8862a8fc198ec9810aafd397c96bb7d86e/packages/server/src/handlers/pty.ts#L118).
- [Single-use scope and 60-second TTL](https://github.com/anomalyco/opencode/blob/05018b8862a8fc198ec9810aafd397c96bb7d86e/packages/core/src/pty/ticket.ts#L9).
- [Binary metadata](https://github.com/anomalyco/opencode/blob/05018b8862a8fc198ec9810aafd397c96bb7d86e/packages/core/src/pty/protocol.ts#L6).
- [Cursor accounting](https://github.com/anomalyco/opencode/blob/05018b8862a8fc198ec9810aafd397c96bb7d86e/packages/core/src/pty.ts#L206).
- [Default origins](https://github.com/anomalyco/opencode/blob/05018b8862a8fc198ec9810aafd397c96bb7d86e/packages/server/src/cors.ts#L11).
- [Supported CORS setting](https://github.com/anomalyco/opencode/blob/05018b8862a8fc198ec9810aafd397c96bb7d86e/packages/cli/src/services/service-config.ts#L222)
  accepts exact comma-separated HTTP(S) origins without paths/trailing slashes
  and **stops the service** before writing. Source verified only; not executed.

Safari, trusted HTTPS page → actual HTTP LAN host, configured-origin service
restart, foreground/background browser recovery and final terminal-on-Web owner
decision remain pending. Browser web-security, mixed-content and TLS checks
were preserved. Chromium used --no-sandbox in the disposable cloud container;
this does not bypass those browser origin/scheme checks. Wrong-directory scope and foreign-origin WebSocket handshake
were not directly tested; no generic 403 claim is made.

Provisional onboarding note: this evidence supports the stated local Chromium
development topology. Diagnose rejected preflight separately from server
availability; OPTIONS 204 alone does not establish browser access. HTTPS→HTTP LAN
requires the separate mixed-content matrix. Full production configuration guidance
and terminal availability remain owned by unfinished SP-04.

## Artifacts and validation

capture.json records native calls, Dart results, selected CDP fields and sanitized
console. cleanup.json records final state. flutter_main.dart.txt, standalone
pubspec/lock, capture_source.py and build.json preserve source/build provenance.
The Dart source is archived as text so repository analysis treats it as captured
evidence. To reproduce, copy flutter_main.dart.txt byte-for-byte to the disposable
standalone Flutter project's lib/main.dart before analyze/build. Its original
source digest and the compiled bundle digest are preserved; the capture was not
rebuilt after this archive rename.
JSString conversion and abort tear-off issues were fixed before successful
analyze/build/capture; an unused-icon font-family warning is recorded.

auxiliary-assets.json is a separate browser-only investigation, with zero native
requests. It reproduced the connection-refused console condition and identified
the failed resource as external Roboto font loading; the original generic console
message was not attributed by original capture CDP. The compiled Dart bridge loaded
and served main.dart.js digest matched the capture build. This does not claim
passing remote fonts or a complete product UI.

Run **python3 /path/to/web/validate.py** from any cwd. Default validation is
read-only, Python standard library only. **--write-report** explicitly refreshes
derived validation.json, excluded from immutable SHA256SUMS. The validator never
runs Flutter, browsers, services or models. The archived live collector is not an
offline test; reproduction requires a fresh bounded preflight, supported credential
retrieval, owned ledger and finally cleanup.
