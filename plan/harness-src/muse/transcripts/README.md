# MSP golden transcripts

Hand-authored, schema-validated wire sessions for the Muse Session Protocol
(MSP) v1 — the canned corpus a client team develops against before a live
host exists. Owning spec: `specs/210-msp-conformance-testkit/` (#210); the
scenario registry is `specs/210-msp-conformance-testkit/contracts/fixture-registry.md`.

## Layout

```
schema/msp/transcripts/<scenario-id>/transcript.ndjson   # the wire session
schema/msp/transcripts/<scenario-id>/manifest.json       # provenance + pins
schema/msp/transcripts/<scenario-id>/records.jsonl       # optional, see below
```

Scenario ids are unique keys; the directory name equals the manifest's
`scenario`.

## Transcript format (the contract)

A transcript is **pure NDJSON**: every line one standalone JSON object, in
wire order (INV-004). No consumer needs the Rust harness to read one.

```
{"dir":"client","raw":"{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",...}"}
{"dir":"server","raw":"{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{...}}"}
```

- `dir` — `"client"` (written to the host's stdin) or `"server"` (read from
  its stdout). The tdd SS7.5 `->`/`<-` arrows are direction notation; the
  file syntax is this JSON field so any language's JSON reader consumes a
  transcript (spec 210 clarification, O-1 ratified).
- `raw` — the **exact wire bytes** of one frame, UTF-8, without the trailing
  `\n`. Recover the wire by writing `raw` + `\n` per line. Client lines may
  end with `\r` (tolerated on input, SS1.1); server lines never carry one.

## Manifest

```json
{
  "kind": "mspTranscript",
  "schemaVersion": 1,
  "scenario": "handshake-usershell-granted",
  "provenance": "hand-authored",
  "fingerprint": "sha256:…",
  "viewSchemaVersion": 1,
  "serverConfig": { "frameLimitBytes": 10485760 },
  "transports": ["stdio", "in-process"],
  "normalize": ["id"],
  "seeds": { "idSeed": 7, "clockStartMs": 1754590931000 },
  "source": [ { "lines": "1", "cite": "tdd SS1.4.1 …" } ]
}
```

- `provenance` — exactly one of `hand-authored | host-generated |
  sdk-tolerance` (INV-002). A `hand-authored` transcript is a standing RED
  against the future host: once #207/#14652/#14653 land, Stage B regenerates
  it under the recorded seeds and byte-diffs; `sdk-tolerance` fixtures are
  permanently hand-authored and exempt (they carry shapes a real server
  cannot emit, tdd SS7.5).
- `fingerprint` — the stable-bundle fingerprint the transcript was authored
  under (INV-003). CI fails when it diverges from
  `schema/msp/stable/manifest.json` without regeneration or a D-019-form
  acknowledgment in `schema/msp/changelog/acknowledgments.json` naming this
  transcript's manifest path (`scripts/check-msp-transcript-staleness.sh`).
- `serverConfig` — recorded server configuration; replay always starts the
  host with it (the short-serve fixture family depends on the frame limit).
- `normalize` — the declared nondeterministic paths, drawn ONLY from the
  "Declared normalization set" table in the fixture registry. The harness
  refuses undeclared normalization (FM-003).
- `seeds` — id/clock seeds for deterministic regeneration.
- `regenerationJustification` — optional durable evidence for accepting a
  semantic host-vs-fixture change. When present, this object requires non-empty
  string fields `cite`, `rationale`, and `trackingIssue`; additive members are
  tolerated. Byte-identical regeneration needs no object.
- `source` — per-line-range citations into the normative TDD
  (`specs/13929-msp-activation/tdd.md`); every frame traces to normative
  text.

The permanent `sdk-tolerance` class has three fixtures: unknown item kind,
unknown session-state method, and OQ-I's unknown dotted
`sourceRange.stream.kind`. They are client/SDK inputs only; the host cannot
produce a vocabulary unknown to itself, so server replay, regeneration, and
reconciliation deliberately exclude this class (tdd SS7.5).

## `records.jsonl` is harness-internal, not contract

A reconciliation-bearing fixture carries the durable records its view
events were folded from. That file is input to the harness's reconciliation
check (FR-011) only: its internal record shapes carry **no cross-language
stability promise**, and clients must not parse it (FR-001).

`reconciliation-refold` is the fixture that ships one. `replay` re-folds its
records, compares every durable-sourced view event byte for byte, and prints
the refold count with both counted exemptions; a fixture without a
`records.jsonl` is reported as not-bearing rather than silently skipped
(INV-006).

## Consuming without Rust

Read `transcript.ndjson` line by line with any JSON parser; each line yields
`{dir, raw}` and each `raw` parses as a JSON-RPC 2.0 frame. Drive your
client's fold with the `server` lines; compare what your client would send
against the `client` lines under the manifest's `normalize` list (ids are
client-minted — structural matching with id unification, never byte-equality
on ids).

## Consuming with the harness

```
cargo run -p tbh-conformance --bin muse-conformance -- validate
cargo run -p tbh-conformance --bin muse-conformance -- staleness
cargo run -p tbh-conformance --bin muse-conformance -- repin
```

Run from the repo root (or pass `--root`). Exit codes: 0 conformant,
1 conformance failure, 2 usage, 3 infrastructure (FR-009). `validate`
schema-validates every frame against the bundle the manifest pins, enforces
the envelope/ordering rules of tdd SS1.1–SS1.4, and prints the INV-007
pending-dependency registrations (what is registered but blocked, and on
which issue). `replay` is the live server-side oracle described below.
`live-smoke` (FR-022) is opt-in and refuses by default: it runs
only with `TBH_CONFORMANCE_LIVE_SMOKE=1` set, and even then it only reports
its pending-dependency registration (exit 3) — the live content remains a
later #210 slice, default tests and CI never set the gate, and no invocation
today touches network or credentials. The future live path is
bound to `docs/agent-testing-secrets.md` preflight discipline. The staleness gate classifies a stale pin's drift with the
#206 classifier and directs the matching D-019 resolution: additive → run
`scripts/regen-msp-pins.sh` (one command: regenerate the bundle, re-pin every
derived copy, revalidate); non-additive → regenerate the transcript
(`muse-conformance regen`) or acknowledge in
`schema/msp/changelog/acknowledgments.json`. `repin` is that command's
rewrite half (#20521): it re-pins additive-stale manifests plus the SDK
constant, skips acknowledged pins, and leaves non-additive drift reported for
a human decision; it never edits the ledger, the release baseline, or a
`transcript.ndjson`.

## Replaying a transcript against the seeded host

```
cargo build -p tbh-conformance --features replay-host --bins
target/debug/muse-conformance replay \
  --transcript schema/msp/transcripts/handshake-usershell-granted
```

`replay` starts the dedicated conformance host beside the CLI, applies the
manifest's `serverConfig.frameLimitBytes`, `seeds.idSeed`, and
`seeds.clockStartMs`, sends every recorded client line over stdio, and
compares host output with the recorded server bytes. Only paths declared by
the manifest may differ; server-minted session, turn, and item identities
remain exact. Every server frame in an exchange is compared in order,
including frames after a response, and extra frames fail closed. A named
field diff exits 1, malformed arguments exit 2, and a spawn or premature host
death exits 3. `--muse-bin PATH` selects an explicit conformance-host
executable for development and contract tests. The `replay-host` feature is
opt-in so canned-host SDK/ACP builds do not compile the full Agent graph.

## Regenerating an already-byte-identical transcript

```
cargo build -p tbh-conformance --features replay-host --bins
target/debug/muse-conformance regen \
  --transcript schema/msp/transcripts/handshake-usershell-granted
```

`regen` drives the same seeded host and comparator as `replay`. When the
captured server stream is semantically identical under the manifest's exact
`normalize` list, it writes the captured wire bytes and flips `provenance` to
`host-generated`; an already-byte-identical capture leaves
`transcript.ndjson` untouched. A semantic divergence exits 1, prints the
named path diff and the “host wrong or fixture wrong” decision, and rewrites
nothing unless the manifest carries the complete owner-approved
`regenerationJustification` object. A complete object permits the semantic
rewrite, remains in the regenerated manifest, and is cited in the report; a
partial object fails before either file is written. A commit message or
implicit flag is never a waiver. `--muse-bin PATH` selects an explicit host
binary, matching `replay`.

## Testing your client against the canned host (`serve-fixture`)

```
cargo run -p tbh-conformance --bin muse-conformance -- \
  serve-fixture --transcript schema/msp/transcripts/handshake-usershell-granted
```

Spawn that command from your client exactly as you will spawn `muse serve`:
write your frames to its stdin (one JSON object per `\n`-terminated line;
a trailing `\r` is tolerated, SS1.1), read server frames from its stdout.
The harness plays the transcript's server side (FR-007):

- **Matching is structural.** Your frame is compared against the
  transcript's next `client` line as parsed JSON — key order and whitespace
  are free — and on a match the recorded `server` lines that follow are
  emitted **byte-exactly** from `raw`, with one exception: a response to
  one of your requests comes back under the id YOU put on that request
  (see id unification below).
- **Id unification, for the values you mint.** Exactly two declared paths
  are yours: the `id` on your own requests, and `params.commandId`. Those
  do not have to reproduce the recorded values — the first sighting pairs
  your value with the recorded one, and the pairing is held one-to-one for
  the rest of the run, so reusing one of your ids against two different
  recorded ids is a mismatch.
- **Your identity is yours.** The corpus was recorded by a client named
  `conformance`, but `params.clientInfo.name` and
  `params.clientInfo.version` on your `initialize` are unified exactly like
  your ids, and the optional `title` display member may be present or
  absent regardless of the recording (#23963) — send your client's real
  identity; it is never matched against the recording client's.
- **The corpus scripts exact dialogues; it is not a template** for the
  frames your client sends in production. In particular, some recorded
  client frames carry a `futureOptionalField` member: that is the D-042
  ignore-unknown fixture — a conforming server ignores unknown members on
  stable-surface requests — so a scripted `serve-fixture` run reproduces
  it, but it is not a member real clients send, and recorded client frames
  are never required request shapes.
- **Values you learned from the wire are matched exactly** (SS1.3). The
  `id` you echo on a response to a server-initiated request,
  `params.turnId`, `params.itemId` — the harness delivered each of these
  byte-exactly, so your echo has no freedom. Answering the wrong request,
  or cancelling the wrong turn, is a correlation bug and fails the run
  rather than being unified away.
- **Responses answer YOUR request ids** (#25143). A response to one of
  your requests is written under the id you sent — the other half of the
  unification pairing above — so your normal correlation logic just works;
  you never have to reproduce the recorded ids. Every other server byte is
  the recording: server-initiated requests, notifications, and every
  server-minted id and UUID inside any frame stay exactly as recorded.
- **Off-transcript frames are never answered.** A harness that improvises
  replies is a second server implementation (tdd SS7.5); an unexpected
  frame while the script is live stops the run with a typed failure
  instead. Frames sent after the final recorded exchange are not judged:
  the run is already complete (`serveFixtureComplete`, exit 0), so close
  stdin once you have read the last server frame.

Reports go to stderr — stdout carries wire frames only. Success leaves one
machine-readable line and exit 0:

```json
{"kind":"serveFixtureComplete","scenario":"…","clientFrames":2,"serverFrames":1}
```

A failed run leaves one machine-readable line and exits 1:

```json
{"kind":"serveFixtureFailure","problem":"frameDivergence","scenario":"…",
 "transcriptLine":3,"expectedFrame":"<recorded raw>","receivedFrame":"<your line>",
 "divergences":[{"path":"params.workspaceRoot","expected":"/home/me/src/proj",
                 "received":"/tmp","note":null}],"errors":[]}
```

`problem` is `frameDivergence` (parsed but does not match; `divergences`
lists each differing path, with `note` explaining unification conflicts and
missing/extra members), `malformedClientFrame` (`errors` carries the parse
detail), or `clientEof` (you hung up while `expectedFrame` was still owed;
`receivedFrame` is `null`). Usage errors exit 2; an unreadable or invalid
fixture exits 3 — the harness's problem, never your client's.

### User-input answer and cancel scenarios

The interactive user-input family has two explicit client-playable scripts:
`userinput-answer-round-trip` and `userinput-cancel-round-trip`. Both attach
with `session/resume { excludeItems: true }`, accept the re-issued
`userInput/request`, page history forward from genesis with `view/page`, and
then settle the same server-minted prompt id. The answer scenario sends
`userInput/answer`; the capability-less scenario sends the typed
`userInput/cancel` with its required reason.

They are separate because `serve-fixture` is an exact linear oracle. One
recorded client position cannot lawfully accept two different commands. The
original `snapshot-suffix-pending-userinput` remains the SS4.9.2 checkpoint
fixture; these two companions exercise the modern metadata-only load path
without changing that snapshot evidence.

### Testing stderr capture and process-exit handling

FR-014 also supplies a synthetic process-death variant for client spawn-path
tests; it does not load or play a transcript:

```text
muse-conformance serve-fixture --exit-code 3 --stderr-lines 128
```

The process writes exactly the requested number of non-empty diagnostic lines
to stderr, writes nothing to stdout, and exits with the requested code from 0
through 255. The diagnostic text is deliberately opaque and may change: a
client MUST capture and surface it but MUST NOT parse it (tdd SS2.11). Use
codes 0–5 plus an unrecognized code such as 77 for the seven TEST-009 arms.
`--transcript` and the process-death flags are mutually exclusive; both
`--exit-code` and `--stderr-lines` are required for this variant.

## What today's bundle can and cannot validate

The pinned stable bundle currently defines the SS1 surface (`initialize`,
`initialized`, envelopes, the SS1 error registry). Frames whose methods land
with later protocol lanes (`session/*`, `turn/*`, `item/*`, `approval/*`)
are envelope-validated and counted as such in `validate` output; full
method-schema validation tightens automatically as #206 enrolls those
surfaces and transcripts re-pin the moved fingerprint. Do not read the
envelope-only count as a defect: it is the SS1.5.4 additive-evolution
posture made visible.

## Open-enum tolerance is a harness semantic

In every transcript, whatever its `provenance`, an unknown string value on an
enum the bundle marks `"x-msp-openness": "open"` validates as conformant, with
a named warning — SS1.5.4 makes a new variant of an open enum additive, and
D-034 (`specs/13929-msp-activation/decision.md`) rules that no property of the
artifact under validation narrows that tolerance. The warning names the def,
the value, and the transcript, so an author typo in a hand-authored fixture
still surfaces loudly in CI output without being a conformance failure. This
tolerance is layered over standard JSON Schema by the harness: an
off-the-shelf validator ignores the `x-msp-openness` annotation and will
report enum violations on fixtures carrying unknown open-enum values by
design. Every `"closed"` or unmarked enum, and any non-string value, stays
strictly validated everywhere.
