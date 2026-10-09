# harness_opencode

The production boundary exports the endpoint probe delivered by
[V2-040 / #272](https://github.com/verseles/codewalk/issues/272):
`OpenCodeEndpointProbe`, strict server-info parsing, the compatibility policy and
manual `RetryAfterHint` presentation. Features consume canonical core results;
wire DTOs remain at the adapter edge.

[V2-041 / #273](https://github.com/verseles/codewalk/issues/273) adds
`OpenCodePairing`: validated pairing inputs, single-use JSON redemption and
explicit, version-gated successor renewal. Session APIs and realtime hydration
remain separate work items.

The fixture-backed fake below is **VM-only test support**, delivered by
[V2-056A / #296](https://github.com/verseles/codewalk/issues/296). It is not
exported by `lib/harness_opencode.dart`.

## Run the checks

From `packages/harness_opencode`, with the Flutter SDK on `PATH`:

```sh
export PATH="$HOME/flutter/bin:$PATH"
dart format --output=none --set-exit-if-changed lib test
dart analyze --fatal-infos
dart test
```

The repository's `make v2-foundations` separately discovers and checks the v2
packages, architecture guards and explicit app entry point. `make check` checks
the retained root Flutter suite. No native OpenCode service, provider, model,
credentials or device is needed for this package's tests.

## Endpoint detection

An authenticated `GET /api/info` runs through the injected endpoint-scoped HTTP
transport, with a 20-second overall deadline and 64-KiB response limit. Validated
`ServerInfo` and service-error envelopes produce canonical assessments without
adopting server-published URLs, PID or ports. The limited legacy fallback checks
healthy OpenCode 1 JSON from `GET /global/health`; HTML success responses and
authentication failures never authorize profile creation.

The minimum is `2.0.20`; tested versions are `2.0.21` and `2.0.22`. Other valid
versions at or above the minimum are explicitly untested. Complete SemVer syntax
is validated before build metadata is ignored for compatibility precedence.
Retry hints inform manual checks only: there is no automatic HTTP replay, and
delays beyond the one-day presentation budget stay deferred rather than clamped.
Cancellation fences stale results. Session APIs and stream hydration remain with
their owning work items.

## Pairing

`OpenCodePairing` receives an endpoint-specific transport factory. A `null`
credential selects anonymous redemption; a non-null credential is used only for
the chosen endpoint's Basic-auth requests, with fixed username `opencode`.

- Official HTTP(S) connect links and the private `codewalk://pair?url=...`
  wrapper are parsed without traffic. UI confirmation is required before
  redemption, and profile repair binds the exact endpoint and prefix.
- `GET /auth/connect/{code}` uses `Accept: application/json`, rejects redirects
  and non-JSON results, and is never automatically replayed. Uncertain outcomes
  require a fresh challenge. A received token can instead be reverified without
  consuming that challenge again.
- The received token is verified through `/api/info`. Declared epoch expiry is
  interpreted only for the source-verified `2.0.21`/`2.0.22` token format; this is
  advisory metadata, not client-side signature validation or JWT processing.
- Manual renewal checks the connected `2.0.22` version before authenticated
  `POST /api/pair`, then redeems and verifies its successor. Captured evidence
  establishes that both the old and new tokens remain accepted.

The app stores one versioned active credential record in its secure vault and
uses expected-value/readback reconciliation for replacement. Authentication
refusal does not erase profiles or credentials. A retained V2-040 password is
read only when the active record is absent, never when it is unreadable/future.

Focused adapter checks run `dart test test/pairing_client_test.dart`. The app's
`test/v2/pairing/live_pairing_test.dart` is explicitly opt-in; it requires an
approved isolated server and a launcher coordinating private password rotation
at `CODEWALK_PAIRING_QA_ROTATE`. Merely setting its environment variables does
not start or rotate a server. The recorded ARM64 OpenCode `2.0.22` runs exercised
production Dart code with in-memory storage backends and no provider turns;
they do not certify installed cameras, keychains, OS handlers or MVP acceptance.

## Test support

| File | Responsibility |
| --- | --- |
| `test/support/fixture_replay.dart` | Immutable captured exchanges, strict request matching and finite scenario catalog. |
| `test/support/fake_auth.dart` | Explicitly synthetic Basic credentials, single-use pairing and a manual five-minute pairing clock. |
| `test/support/fake_opencode_server.dart` | Disposable IPv4 loopback HTTP/SSE server, response gates, fault controls and asynchronous teardown. |
| `test/fake_opencode_server_test.dart` | Real-transport HTTP replay, auth, matching, fault boundaries and teardown. |
| `test/fake_opencode_stream_test.dart` | Accepted SSE events, interaction identities, targeted EOF and reconnect hydration. |

Import support directly from tests. `OpenCodeFixtures()` locates the accepted
capture directory by walking upward from the current directory; an explicit
`Directory` can instead be supplied as `root`.

### Finite scenario catalog

| Factory | Accepted evidence and script |
| --- | --- |
| `observedA()` | A's `events.sse`, already reserialized after redaction. Info/auth/pairing are available alongside every scenario. |
| `admission()` | B create calls 0–2 followed by prompt calls 0–9: same-ID replay, cross-session conflict, distinct-ID admission and correlated session/inbox/history reads. |
| `lostCreate()` | B create calls 5–7: admitted create, authoritative lookup and same-ID replay. |
| `reconnect()` | All 13 B disconnect/reconnect HTTP calls; separately recorded `partialStream` and `reconnectedStream` SSE epochs. |
| `permissionOnce()`, `formReply()`, `formDismiss()` | C's guarded native permission/form exchanges and the matching observed interaction events. |

Calls must match the next recorded exchange, including method, path, decoded
query multiplicity, JSON structure and numeric types. JSON object/query key
order is irrelevant. A nonempty JSON `null` body differs from no entity;
zero-byte bodies carry no JSON entity. Extra, repeated or out-of-order calls
return an explicitly synthetic `409` without advancing the script or an armed
fault. Info and auth routes are independent of the exchange cursor.

Responses preserve captured IDs, envelopes, timestamps, native statuses and
empty `204` bodies. In particular, `/api/info` retains the **captured** URLs and
PID: connect to `server.endpoint`, not the URLs in that payload.

### Start and close a server

```dart
final fixtures = OpenCodeFixtures();
final server = await FakeOpenCodeServer.start(
  fixtures: fixtures,
  scenario: fixtures.lostCreate(),
);
final transport = IoEndpointHttpTransport(
  endpoint: server.endpoint,
  headers: (_) => {'Authorization': server.auth.authorization()},
);
try {
  // Send the scenario's captured exchanges through this real HTTP transport.
  // See test/fake_opencode_server_test.dart for complete runnable examples.
} finally {
  try {
    await server.close();
  } finally {
    transport.close();
  }
}
```

The snippet uses `codewalk_net/codewalk_net_io.dart` and the two local support
libraries `fixture_replay.dart` and `fake_opencode_server.dart`.

Credentials are unmistakably `fake-test-*` and scoped to the listening server.
HTTP Basic uses username `opencode`; bootstrap or issued token occupies the
password position. `[REDACTED]` never authenticates. `POST /api/pair` returns a
synthetic code; unauthenticated `GET /auth/connect/<code>` redeems it once.
`server.auth.advance(...)` moves the explicit clock; codes expire at exactly
five minutes. Renewal keeps the predecessor token accepted. No real-time token
expiration is simulated or claimed.

### Fault and SSE controls

- `failNextExchange()` returns one synthetic `503` before admission. The
  matching exchange remains available for retry; mismatches do not consume the
  fault.
- `holdNextExchange()` returns a `ResponseGate`. Await `gate.admitted` before
  reconciliation: `true` means the cursor already advanced; `false` means
  teardown cancelled an unused gate. `release()` sends the captured response;
  `drop()` destroys that response's socket without erasing admission.
- Opening `/api/event` consumes the next explicitly recorded connection epoch.
  A synthetic `: fake-test-ready` comment flushes headers without publishing a
  native event. Consume the client stream concurrently with
  `server.streams[index].emitNext()` or `emitRemaining()`.
- `finish()` ends only the selected connection with complete-frame EOF. A
  reconnect uses its separately recorded epoch; `Last-Event-ID` never replays
  missed events. B's disconnected hydration is supplied by its HTTP script.
- `close()` is asynchronous and idempotent, releases response gates, closes
  owned sockets and waits for tracked operations. Unexpected asynchronous
  errors remain visible through `assertHealthy()` and teardown.

Defaults cap each request body at 64 KiB and scenario requests at 256.
Malformed JSON, body-limit and request-limit failures are labelled synthetic
`400`, `413` and `429` responses. Observations store only outcome kind and
exchange index, excluding paths, headers, credentials and request bodies.

## Provenance and limits

Fixtures remain under
`test/contract/fixtures/opencode/2.0.22/` in the repository root. A/B/C were
accepted by #240/#241/#242 and their offline validators. Their provenance and
hash records remain authoritative; this utility does not rewrite them.
The versioned official contract anchor is OpenCode 2.0.21, while these captures
observed CLI 2.0.22 on Linux. This is not multiversion compatibility evidence.

The fake is a finite replay utility, not a general native state engine or
working client adapter. Manual publication/EOF and reserialized SSE do not
prove original timing, chunking or TCP-reset behavior. Full negative corpus,
adapter integration, drift guards and legacy mock retirement belong to #297
and the owning consumer Issues. Production behavior, real-host/manual tests,
platform builds and distribution acceptance remain separate evidence.
