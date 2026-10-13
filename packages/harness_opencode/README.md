# harness_opencode

The production boundary exports the endpoint probe delivered by
[V2-040 / #272](https://github.com/verseles/codewalk/issues/272):
`OpenCodeEndpointProbe`, strict server-info parsing, the compatibility policy and
manual `RetryAfterHint` presentation. Features consume canonical core results;
wire DTOs remain at the adapter edge.

[V2-041 / #273](https://github.com/verseles/codewalk/issues/273) adds
`OpenCodePairing`: validated pairing inputs, single-use JSON redemption and
explicit, version-gated successor renewal. The bounded session reader below is
delivered separately; realtime hydration and full lifecycle remain work items.

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
Cancellation fences stale results. Stream hydration remains with its owning
work item.

## Read-only session catalog and metadata

[V2-043A / #364](https://github.com/verseles/codewalk/issues/364) adds
`OpenCodeSessionReader`, which borrows an already-authenticated,
endpoint-scoped transport and a canonical `HarnessRef`:

- `listSessions(SessionQuery)` reads `GET /api/session`, preserving server order
  and returning immutable canonical `Page<SessionSummary>` results. The initial
  page uses descending order; continuations forward the server cursor without
  interpreting it. Returned continuation tokens belong to that reader instance.
- `readSession(SessionRef)` reads one matching session. Host, harness and native
  identity remain distinct; supplied native IDs follow the official `ses`
  prefix rather than assuming every ID has the generated `ses_` form.
- Reads default to 20 seconds, a 1-MiB collected-body cap and at most 200 items.
  These bound application-level work, not OS buffers or arbitrary asynchronous
  transport cleanup. Disposing the reader cancels its operations while leaving
  the borrowed transport and caller cancellation signal intact.
- Errors contain finite categories and HTTP status codes, not raw server
  messages, URLs, headers, bodies or stacks. Gateway failures are unavailable;
  HTTP 408 and total deadline expiry are timeouts. Reads are never retried
  automatically and do not mark a session viewed or resume execution.
- Project and active-only queries are explicitly unsupported in this producer.
  Ownership stays unknown, project/execution state stays absent, and the page
  has no invented snapshot boundary. Whitelisted native directory/project and
  fork annotations do not establish canonical project identity or turn a native
  message boundary into a timeline item.

The catalog is wired to the app's read-only Conversations list by
[V2-043B / #365](https://github.com/verseles/codewalk/issues/365). The history
producer below is not yet wired to a message screen. Streaming, sending and
lifecycle mutations retain their own criteria.
Tests replay an accepted 2.0.22 B metadata GET over authenticated loopback IO;
page and failure/race fixtures are explicitly source-shaped test data, not
additional native G1 recordings. Natural provider retry/quota remains pending.

## Read-only flat history

[V2-044A1 / #366](https://github.com/verseles/codewalk/issues/366) extends the
same reader with `readHistory(SessionRef, sourceVersion: ..., limit: ..., cursor:
..., cancellation: ...)`, returning an immutable `Page<TimelineItem>`:

- Supply the version observed for the authenticated endpoint; the reader checks
  the existing compatibility policy but does not probe or invent a version.
  One call reads `GET /api/session/{id}/message`. The first page requests ascending
  order; continuations send the native cursor without `order` or a type filter.
  Empty or short pages with a continuation remain pageable. History tokens bind
  the reader, complete session identity, version and limit, separately from the
  unchanged catalog tokens. Neither operation follows pages or retries itself.
- The native limit counts messages (50 by default, at most 200), while a message
  can expand into several timeline items. Server and block order are preserved;
  text and reasoning have independent ordinals, and tools retain their native
  call IDs within the full session/message identity. No turn ID, event ID,
  snapshot boundary or durable replay claim is invented. History generations
  are adapter bookkeeping, not live-stream generations or hydration barriers.
- User text, assistant text/reasoning/tools, synthetic/system notices and explicit
  idle outcomes use canonical types. Delivery stays unknown without evidence.
  `streamed` or `completed` timestamps can end provider text without ending a
  running tool or a turn; `finish` and history presence alone cannot. Only the
  verified `read` tool name is classified; other names remain `ToolKind.other`.
- Empty assistants, native assistant errors/retry metadata, future types and
  currently unsupported selection/skill/shell/compaction records remain explicit
  minimized `UnknownItem` markers. User file/context manifests and tool file
  outputs do not retain base64, URIs or names and cannot resolve content. Nothing
  fetches a referenced file or URL.
- Structured tool arguments redact a finite credential-key set, including
  `x-api-key`. Streaming argument fragments are omitted with an explicit
  `inputNotProjected` flag because incomplete JSON cannot safely use that policy.
  Provider state, arbitrary metadata, snapshots and error response bodies are
  omitted; only the known tool `truncated` boolean is retained. Conversation text
  and textual tool output are application content, not diagnostics; this is not
  a universal secret-removal guarantee.
- Reads retain the 20-second deadline and 1-MiB body limit. Projection fails
  atomically rather than truncating: at most 128 assistant blocks per message,
  2,000 projected items per page (`maxHistoryItems` may lower this), depth 16,
  16,384 selected node visits, 256 KiB per text, 64 KiB per structured field and
  1 MiB of selected-content accounting. Values ultimately retained in a canonical
  manifest are charged there rather than again during string validation. These
  are application guards, not an absolute process-memory or OS-buffer quota.

The official contract is pinned to OpenCode `05018b8862a8fc198ec9810aafd397c96bb7d86e`
(`2.0.22`, `packages/protocol/src/groups/message.ts` and
`packages/schema/src/session-message.ts`). Tests check A's four captured messages
against six semantic items, replay an actual B HTTP exchange over authenticated
loopback, and distinguish D/E observed subsets from source-shaped edge cases.
The A body retains its real continuation; it is not a newly captured HTTP wrapper.
No fixture/provenance is rewritten and no test establishes new G1, installed
device or MVP acceptance.

Focused checks from this package:

```sh
export PATH="$HOME/flutter/bin:$PATH"
dart analyze --fatal-infos
dart test test/history_projection_test.dart test/history_reader_test.dart test/session_reader_test.dart
```

## Native text and reasoning event projection

[V2-044A2 / #368](https://github.com/verseles/codewalk/issues/368) exports
`projectOpenCodeTextReasoningEvent(value, current, sourceVersion: ..., position:
..., receivedAt: ...)`. This synchronous, pure function returns a canonical
`SessionEvent?`; the caller must project and reduce each observation against the
latest `SessionState`, rather than project a batch against an old state.

- The six `session.text.*` and `session.reasoning.*` started/delta/ended variants
  map to streaming items, field-specific deltas and completed full-value upserts.
  An authoritative end replaces the prefix and completes only that block.
  Missing-start deltas retain the Core's refetch behavior; starts for a resident
  item are skipped to preserve its prefix or history content.
- Item IDs match the history producer's full session/message/kind/ordinal
  identity. Live generations include the caller's stream ID and epoch and differ
  from history generations. Native event ID, creation scalar and durable aggregate
  sequence remain provenance, separate from caller order and receipt time; no
  turn, execution outcome, snapshot boundary or replay cursor is inferred.
- This producer verifies the `2.0.22` schema, including valid build metadata but
  excluding prereleases. It does not change endpoint compatibility policy.
  Unrelated types and valid foreign sessions return null. Malformed selected
  fields, unsupported versions, limits and resident item-kind collisions produce
  finite `OpenCodeTextProjectionException` categories without native error text.
  Opaque provider state, location and arbitrary metadata are never read or copied.
- IDs and caller identity strings are limited to 4 KiB UTF-8; selected text and
  each applicable open block are limited to 256 KiB, with Unicode scalar checks
  and atomic rejection rather than truncation. Project-then-reduce is essential
  to the cumulative bound. It runs before the Core's finite deduplication, so an
  otherwise over-limit duplicate may be rejected while preserving the prefix.
  These limits do not bound upstream decoding, OS buffers or total process memory.

The official schema pin remains OpenCode `05018b8862a8fc198ec9810aafd397c96bb7d86e`.
Offline A replay decodes its 27 actual frames, maps ten updates and compares three
completed content blocks with history. B retains its incomplete text after the
two recorded reconnect events; it supplies no replayed end. Caller positions and
receipt clocks are synthetic test inputs, while source-shaped edge cases are
labelled separately from observed captures. Fixtures and provenance are unchanged.
No new native observation, installed-device or MVP acceptance is established.
Live stream/hydration and chat wiring remain separate work items.

Focused checks from this package:

```sh
export PATH="$HOME/flutter/bin:$PATH"
dart analyze --fatal-infos
dart test test/text_reasoning_projection_test.dart test/text_reasoning_replay_test.dart \
  test/history_projection_test.dart test/fake_opencode_stream_test.dart test/public_surface_test.dart
```

## Native tool event projection

[V2-044A3 / #369](https://github.com/verseles/codewalk/issues/369) exports
`projectOpenCodeToolEvent(value, current, sourceVersion: ..., position: ...,
receivedAt: ...)`. Like the text/reasoning projector, it is synchronous and pure,
returns a canonical `SessionEvent?`, and must be applied project-then-reduce
against the latest `SessionState`.

- It covers the seven pinned `session.tool.*` phases. `input.started` creates a
  streaming `ToolCall` with the observed name and never erases a compatible
  resident prefix. `called` carries structured input; `success` and `failed`
  carry only their current terminal content. An aborted failure becomes
  interrupted, with an empty raw message and no retry inference.
- `input.delta`, `input.ended` and `progress` are validated and return null: raw
  argument fragments are never JSON-parsed or retained, and arbitrary progress
  metadata is omitted. Structured `called.input` and output use the same
  normalized 14-key credential redaction as history.
- Item IDs match history identity and live generations use the caller's stream
  epoch. A missing start, a mismatched observed name, or a resident item whose
  aggregate owner differs from the session or lacks a durable sequence returns a
  fixed `ResyncRequired`; history and prior-epoch rows are never adopted and no
  tool name is invented.
- Provider state, location, error message/status/response/body and file URI/name
  are never read. Files keep only MIME and an unavailable marker; terminal
  metadata keeps only the `truncated` flag. An empty error type is unsupported.
  Failures are finite `OpenCodeToolProjectionException` categories.
- Selected IDs, name, MIME and error type are limited to 4 KiB; raw argument
  strings to 64 KiB. Structured input and output each have a 64 KiB JSON-escaped
  budget (including redaction expansion), depth 16, 16384 shared node visits and
  at most 128 output parts; text's 256 KiB cap is subordinate. Rejection is atomic,
  without truncation. These guards do not bound upstream decoding or process memory.

Offline A replay projects the 27 actual frames and yields four history-matching
content items. B captures verify that progress supplies no terminal content, that
aborted failures stay interrupted, and that reconnect keeps the completed tool and
incomplete text without replay. Fixtures and the schema pin are unchanged; no new
native, installed-device or MVP acceptance is established.

Focused checks from this package:

```sh
export PATH="$HOME/flutter/bin:$PATH"
dart analyze --fatal-infos
dart test test/tool_projection_test.dart test/tool_replay_test.dart
```

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
