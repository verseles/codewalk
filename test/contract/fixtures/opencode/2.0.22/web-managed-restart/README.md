# OpenCode 2.0.22 — managed CORS and Chrome restart subset

Bounded evidence for [V2-008A / #358](https://github.com/verseles/codewalk/issues/358),
under [SP-04 / #247](https://github.com/verseles/codewalk/issues/247).
This standalone diagnostic does not implement the production client transport.

## Observed result

The 2026-10-06 capture passed semantic validation and all 32 corruption controls.
Official managed-service configuration persisted across a process restart:

1. Private `service set port` / `service set cors` configured one exact allowed
   origin. Chromium read authenticated info (200) and invalid-auth info (401);
   a different origin was blocked by actual Chrome CORS checks for info and SSE.
2. The compiled Dart probe incrementally read authenticated `/api/event` and a
   real Unicode session rename. Reapplying the same managed CORS setting stopped
   the registered owned process, PID **2730197**.
3. The old reader ended naturally with **read-error**, released its lock, and the
   Dart supervisor retried automatically. One attempt was denied locally by the
   authless ownership broker while no owned listener was available; it sent no
   native Authorization request. A new owned process, PID **2730566**, used the
   same port, private credential and persisted CORS configuration.
4. The third attempt connected, hydrated the same session through an independently
   recorded Chrome GET, and read a later real rename event. Natural disconnect
   to authoritative recovery took **1,357 ms**, with a maximum of **one reader**.
5. Shutdown cleared browser credentials and cancelled retries; the owned session
   was deleted and GET returned 404. Process groups, native/static/CDP listeners,
   native runtime and Snap private root were removed. Independent `/proc` and
   listener checks confirmed cleanup. Native inference turns **0**, cost **USD 0**.

The limit is 20 seconds and 12 retries after the initial attempt (13 total).
There is no cursor/replay guarantee. Hydration follows the new connected frame;
the collector's later readiness-record timestamp is not a client recovery gate.

## Provenance and immutable records

- Official npm artifact: `@opencode/cli-linux-arm64@2.0.22`; archive SHA-256
  `49e5466de60f65001cddd7583419f842140697daead2b4d8826be54d9056e70b`;
  executable SHA-256
  `f27539d9c05c970d3eb9ad6a7724b75d3e638932c5423554f5ecbfe0ee2e8815`.
- Flutter 3.44.1, Dart 3.12.1, `web` 1.1.1; Snap Chromium 154.0.8037.57 on
  Linux ARM64. Browser sandbox/security remained enabled. Both custom `.test`
  origins and the disposable API mapped to loopback; this is not LAN evidence.
- `build-provenance.json` records compile inputs before/after the controlled
  offline analyzer/build, command arguments and the actual compiled JS hash.
  The collector verifies the current inputs and bytes served before execution.
- Successful `evidence/capture.json`: SHA-256
  `71b0ec1299d5131c0e8e111c0074cf4a231c844b6231dcb855da9387f1f6b717`.
- First attempt `evidence/failed-bootstrap-capture.json`: SHA-256
  `9c3d609adc3bcdd22cca9a51935567c5e8db2864b4c456c5aa81ba0e42b076ab`.
  It stopped before browser authentication/SSE and is retained as a failure.
  Investigation verified that the generated CanvasKit loader uses
  `WebAssembly.compileStreaming`, while the first collector served WASM as
  `application/octet-stream`. The corrected collector serves `application/wasm`,
  records pre-auth bootstrap diagnostics and starts native configuration only
  after the Dart bridge initializes. The original exception was not captured;
  do not represent its exact type as an observed fact.

Official v2 anchors are in `ai-docs-for-opencode-v2/` under ADR-023/058.
The runtime admission and correction are recorded in
[#358 admission](https://github.com/verseles/codewalk/issues/358#issuecomment-6025330111)
and [corrected admission](https://github.com/verseles/codewalk/issues/358#issuecomment-6025635908).
The MIME requirement is documented by
[MDN](https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/JavaScript_interface/compileStreaming_static).

## Offline verification

From this fixture directory, these commands execute no native/browser calls:

```sh
source ~/paths && rtk proxy python3 -B validate.py --self-test
source ~/paths && rtk proxy python3 -B -m unittest test_semantics
```

The seven synthetic tests and 32 mutations verify validator regressions; they are
not native evidence. `validate.py` checks the immutable real capture by default.
No frozen native capture needs repeating for an offline-validator correction.
Every network record has a strict boolean auth marker. Each authorized browser
request requires its own preceding positive ownership proof; after the old
listener exits, the proof must identify the replacement PID.
A recorded ownerless retry must correlate with a negative proof and have no
HTTP response, reader or event; authentication remains forbidden until another
positive proof. Future captures that reconnect immediately without this branch
are valid and run 29 general controls instead of the 32 exercised here.

## Opt-in reproduction

Obtain a new execution admission before starting native/browser resources.
Copy the source files and `app/` into a fresh private directory matching
`/tmp/opencode/codewalk-sp04-managed-*`; do not run installation or capture in
the repository. Use the pinned Flutter/Dart SDK and locked dependencies. Run
`prepare.py`, offline `flutter pub get` inside the copied `app/`, then `build.py`
from the copied root with `$HOME/flutter/bin` on PATH. The controlled build
replaces its provenance with the new actual compilation result. `capture.mjs`
requires an explicit `--run` argument and a valid private artifact admission.

The collector uses a 180-second deadline and bounded individual cleanup
operations; reserve up to 120 seconds for teardown. Setup/execution/validation
budget is 1,200 seconds excluding development/helper review. Zero inference
and USD 0 remain mandatory. Authentication is sent only after checking the
owned native PID/socket/executable through the same-origin broker. No provider
store or real credentials are read. Snap `/tmp` is a distinct mount from host
`/tmp`; its recursive cleanup removes only the invocation's private Snap root.

Do not repeat an unchanged failed capture. Preserve its result, inspect actual
diagnostics, correct the evidenced cause, validate/review and record the revised
admission before a new attempt.

## Remaining acceptance

This fixture covers the managed-service CORS/restart Chrome slice. Full #358
still needs trusted HTTPS to an actual HTTP LAN peer and mixed-content/LNA
observations, terminal/onboarding decisions and explicit acceptance. Safari/iOS,
OS sleep, full SP-04, native-platform checks and G1–G5 are not established here.
Existing captures are unchanged; this result does not close #358 or #247.
