# codewalk_net

Harness-neutral transport primitives. Import `codewalk_net.dart` for portable
contracts and `codewalk_net_io.dart` for native Dart IO implementations.
The Android/Linux V2-028D producer is implemented at package level; the v2 app's
profiles, pairing and authoritative session hydration are separate consumers.

## Native endpoint and authentication boundary

Each `IoEndpointHttpTransport` owns one validated HTTP(S) endpoint and optional
path prefix. Relative routes cannot change its origin or escape its prefix,
including encoded traversal through separators or nested percent encoding.
Requests never follow redirects or automatically retry. HTTP statuses and bodies
are preserved for the harness adapter, and errors omit credentials/native causes.

`basicEndpointHeaders` and `bearerEndpointHeaders` bind credential lookup to the
validated endpoint; `composeEndpointHeaders` merges providers case-insensitively.
They store no secrets and do not add authentication URL parameters. The harness
chooses the scheme and username: OpenCode v2 uses Basic with username `opencode`
and either its password **or pairing token in the password position**, not Bearer.
Gateway header providers can compose without replacing origin authorization.

`IoNetworkOptions` exposes typed proxy discovery and socket-connection hooks for
caller-provided network integrations. A connection factory must honor non-null
proxy host/port parameters. No permissive TLS callback or general client
configurator is provided; an embedded tunnel implementation is not part of this
package. Dart IO's proxy/VPN behavior still needs target-specific validation.

## WebSocket

`IoEndpointWebSocketTransport` takes the same HTTP(S) endpoint and relative route.
It performs a no-redirect HTTP Upgrade, verifies the 101 response and RFC6455
Accept value, and uses the public detached socket API. No compression, extensions
or subprotocol is negotiated. A raw incremental parser rejects oversized declared
payloads and aggregate fragmented messages before their payload is accumulated;
it validates UTF-8, masking direction, opcodes, control frames and close codes.
Every outgoing client frame, including Pong and Close, is securely masked.

The default data-message limit is 16 MiB; queued incoming and outgoing payloads
are separately limited to 32 MiB and 256 messages. Controls retain their RFC
125-byte limit even with a smaller data cap. Queue saturation fails explicitly;
a Pong that cannot be queued closes the connection rather than being dropped.
Handshake cancellation includes asynchronous credential lookup and cleans up
late sockets. Cancellation of an established connection also owns its socket.

Sending awaits bounded **local flushing**, not remote admission. Uncertain writes
are never automatically replayed. Close shares one future, reads the peer's
closing handshake and TCP cleanup, and falls back to destruction after a bounded
2-second default deadline. Ping is answered until a peer Close is received.

## SSE parsing and recovery

`SseDecoder` and `SseFrameParser` share strict chunk-safe UTF-8 framing, multiline
data, comments, 16 MiB default frame/line limits and incomplete-EOF discard.
`openSseStream` remains a one-shot status/media-type-checked operation.

`parseSseInIsolate` runs framing in an IO isolate. Explicit input and output ACKs
bound outstanding work to one 64 KiB transferred input chunk and one batch
(default 64 frames / 16 MiB). Pause gates the input pump even when comments or
partial input produce no events. Cancellation wakes idle ports, releases credits
and disposes owned subscriptions/ports; worker shutdown has a bounded fallback.

`IoSseRecovery` borrows an endpoint HTTP client and owns only its GET response and
parser worker. It emits generation-tagged `SseConnected`, `SseBatch` and
`SseDisconnected` updates. An optional adapter `connectedWhen` predicate selects
the readiness control frame; earlier frames are discarded. The consumer must
hydrate authoritative state and call `releaseGeneration(generation)` before
subsequent frames are released. Stale releases/queued data cannot apply to a new
generation. The package interprets no event JSON or session identity.

Default recovery policy:

- 45 seconds without raw bytes triggers a gap; heartbeat comments count.
- Jittered exponential backoff stays between 1 and 30 seconds; `wake()` handles
  explicit resume/network-change signals. Permanent auth/configuration failures,
  including unexpected 2xx responses, stop automatic retries until wake.
- Batches are emitted at most once per 100 ms globally, so a session cannot
  exceed that frequency. Session-specific projection remains adapter work.
- Retained frames, including readiness control payloads and queued deliveries,
  are bounded by 32 MiB / 4,096 frames and a separate update-count cap. Overflow
  abandons the generation and signals recovery without silently applying a prefix.
- Consumer pause propagates upstream and suspends local watchdog/retry timers.
  Recovery never closes the borrowed HTTP client or replays a mutation.

There is no `Last-Event-ID` replay or durable-log guarantee. The caller must
reconcile gaps through authoritative snapshots and preserve operation-specific
uncertainty and cancellation barriers.

## Verification and limits

From this package directory:

```sh
source ~/paths && export PATH="$HOME/flutter/bin:$PATH" && dart analyze lib test
source ~/paths && export PATH="$HOME/flutter/bin:$PATH" && dart test
```

From the **repository root**:

```sh
source ~/paths && export PATH="$HOME/flutter/bin:$PATH" && dart run tool/ci/import_rules.dart
```

Tests exercise loopback HTTP/WebSocket upgrades, coalesced 101/first-frame socket
handoff, cancellation, strict targets/auth, fragmented framing, oversized length
headers without huge payload allocation, control/close semantics, isolate credits,
frame-independent pause, generation hydration and byte/count overflow.

These checks provide Dart VM package evidence on Linux ARM64 / Dart 3.12.1.
They do not establish installed Android/Linux app, signing, migration or MVP
acceptance. Browser transport/parity remains separate post-MVP work. Byte limits
count retained encoded fields/payloads and object counts, not exact VM heap,
already-allocated source chunks or kernel/socket memory.

Primary implementation references: [Dart public upgrade API](https://api.dart.dev/stable/3.12.1/dart-io/HttpClientResponse/detachSocket.html),
[RFC6455](https://www.rfc-editor.org/rfc/rfc6455), and the versioned
[OpenCode v2 contract anchor](../../ai-docs/opencode_v2_server.md) for adapter consumers.
