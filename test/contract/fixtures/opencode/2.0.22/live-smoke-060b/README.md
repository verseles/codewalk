# V2-060B — minimal live OpenCode flow on a disposable host

> **Scope:** private development validation of the CodeWalk v2 client against a
> real OpenCode `2.0.22` server. This is not a G1–G5 gate, a public beta
> record, an installed-native acceptance or an MVP acceptance.
> Owner issue: [#300](https://github.com/verseles/codewalk/issues/300).

## What was observed

The launcher (`tool/ci/live_smoke_v2_opencode.py`) fetched the official
`@opencode/cli-linux-arm64@2.0.22` package, verified its SHA-512 integrity
and the pinned SHA-256 digests, and ran it as an **owned foreground**
`opencode serve` on `127.0.0.1` with an ephemeral port, an isolated
`HOME`/`XDG_*` tree, a fresh password and a committed disposable project. The
only provider it could reach was a **loopback stub** (deterministic tokens,
`cost` 0), so the run spent nothing and used no provider credential.

| Capability | Result | How it was observed |
|---|---|---|
| Pairing | `passed` | `POST /api/pair` → single-use redemption → paired token; the same code is rejected on a second attempt |
| Send | `passed` | The real composer sent a prompt; the stub streamed `CW060B_STUB_SEND_OK` through the real screens; the native turn reports `cost` 0 |
| Approval (tool-originated) | `passed` | The stub emitted a tool call, the real agent loop paused, the real card rendered, one `once` tap settled it and the turn continued |
| Approval (manual, API-created) | `passed` | A native request created over the wire needed the manual reply; the reply settled it and wrote no persistent rule |
| Approval (automatic) | `passed` | With Allow all (the new-install default) the client answered a resident request by itself, once, without a tap and without a saved rule |
| Reconnect | `passed` | The transport was cut mid-turn: the client observed `reconnecting` while the server-side execution kept running, then recovered to a live, current view |
| Stop | `passed` | A running execution was stopped exactly once; the execution left `running` and the draft survived |
| Stop (idle) | `passed` | An idle interrupt returned `interrupted: false` — a confirmed no-op, never counted as a Stop pass |

## Zero-spend and isolation evidence

- `egress.json`: no non-loopback peer was ever observed on the server socket;
  the run fails closed on any violation.
- `stub-ledger.json`: every provider request is recorded with its scenario
  marker; the cap is 12 requests and the run used 4.
- `cleanup.json`: the owned server exited, the temporary tree was removed, the
  host's own OpenCode processes and listening ports were unchanged, and every
  owned port was released.

## Limitations

- The disposable server ran on this Linux aarch64 host. No Android device, no
  installed client and no Windows/macOS target was exercised.
- The provider was a loopback stub with `cost` 0. No real model turn and no
  provider credential were used, so this evidence proves the **CodeWalk client
  contract**, not provider behaviour.
- The turn behind the tool-originated permission was produced by the stub, so
  the post-approval continuation is stub behaviour.
- The same screens through the fake harness are covered by V2-060A
  (accepted); installed-native acceptance stays with the platform checkpoints.

## Files

| File | Content |
|---|---|
| `results.json` | Per-capability result states and the limitations |
| `provenance.json` | Version, artifact digests, topology, cost, wall clock |
| `events.json` | The phase markers of the run and the client exit code |
| `markers.txt` | The same markers, one per line |
| `stub-ledger.json` | Every provider request the stub served |
| `egress.json` | The egress audit result |
| `cleanup.json` | The isolation and cleanup proof |
| `validate.py` | Read-only cross-checks over this directory |

Reproduce with:

```bash
python3 tool/ci/live_smoke_v2_opencode.py run \
  --root /tmp/opencode/v2-060b-run \
  --evidence-out /tmp/opencode/v2-060b-evidence \
  --flutter-test test/v2/sessions/live_flow_smoke_test.dart
python3 test/contract/fixtures/opencode/2.0.22/live-smoke-060b/validate.py
```
