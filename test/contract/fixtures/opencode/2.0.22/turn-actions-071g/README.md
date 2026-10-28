# V2-071G: native turn actions (Seq 5.4c, #455)

`capture-r2.json` is a second immutable successful run after review strengthened
the collector. It waits for the busy-session compaction terminal and verifies
its admitted control ID against the start and subsequent successful end; an
ordinary execution terminal cannot stand in for that lifecycle. It records
46 calls, 154 events, seven native starts and seven zero-cost provider requests.
The latest producer-hash check uses this run; the original `capture.json` and
negative diagnostic remain unchanged. Their producer is preserved in commit
`746d5177`; the newer run records that commit as its base plus its exact dirty
producer hashes.

Observed Linux ARM64 responses and global SSE from the official, project-pinned
OpenCode **2.0.22** binary. The provider is the deterministic loopback stub in
`tool/ci/v2_device_server.py`, with advertised costs zero, all external providers
denied and all tools denied. These are real server responses and events with
test provider output; no native event was fabricated. This evidence does not
accept an application implementation, a platform build, or the owner's CP5.

`capture.json` records 46 calls, 154 events, seven native execution starts and
seven provider requests. All starts have an observed terminal, all three owned
sessions were disposed and read back as 404, the active map was empty, the owned
server was stopped, and the user's server processes were unchanged. Continuous
socket audits observed only loopback peers. Generated credentials never leave
the runtime directory. The owned root is replaced with `<owned-root>` and opaque
`providerState`/`providerContext` fields are omitted.

The producer hashes identify the actual dirty-tree collector and stub at run
time; `repo_commit` is their base, `0d15eed1`, not a claim that these new tools
were already committed. The binary SHA-256 is checked against the existing
architecture-specific pin. `SHA256SUMS` covers both JSON artifacts.

| Observation | Evidence |
| --- | --- |
| Undo and partial redo | Stage the first confirmed user message, then move the boundary to the second; both responses and authoritative session reads report the chosen boundary. Staging retains native history for redo. |
| Redo all | Clear returns 204 and emits `session.revert.cleared`; the resulting empty native execution drain has no provider response. |
| Replacement branch | Commit returns 204, clears revert and removes the boundary-and-later history before the replacement prompt is admitted. |
| Busy revert | Stage, clear and commit each return 409 with `SessionBusyError` while a real streamed execution is active. |
| Busy compact | Returns 200 with a steered `Session.Inbox.Compaction`, then emits real started/delta/ended events. The product's busy disable is a UI requirement, not a claim that this route refuses active executions. |
| Idle compact | Admission returns 200 and is followed by successful native compaction, independently verified from the terminal event. Admission is not completion. |

The existing immutable [D capture](../d/README.md) supplies the physical file
effects of `files:true`, `files:false`, clear and commit. This new fixture uses
the standard device server with snapshots disabled and makes no new claim
about file restoration or outside-directory effects.

`compaction-failed-diagnostic.json` preserves the real negative first attempt:
the generic provider answered `CW-OK`, which the server rejected as an invalid
summary after its one nudge. Both admitted compactions emitted
`session.compaction.failed` with cost zero. This is failure-path evidence, not
successful compaction. Official source at
[`05018b8862`, `packages/core/src/session/compaction.ts`](https://github.com/anomalyco/opencode/blob/05018b8862a8fc198ec9810aafd397c96bb7d86e/packages/core/src/session/compaction.ts)
defines the Markdown summary template. The stub now answers it with a fixed
structured checkpoint, which the real server accepts. The two separate runs
each observed seven native starts; their limits were 12 starts and 600 seconds
per isolated run. No paid model, shared service or production state was used.

Offline checks (no server or model):

```sh
python3 tool/ci/capture_v2_turn_actions.py --validate test/contract/fixtures/opencode/2.0.22/turn-actions-071g/capture.json
python3 tool/ci/capture_v2_turn_actions.py --validate test/contract/fixtures/opencode/2.0.22/turn-actions-071g/capture-r2.json
python3 -m unittest tool.ci.test_v2_turn_actions_capture
python3 test/contract/fixtures/opencode/2.0.22/d/validate.py
```

For a new capture, choose two **new** paths below `/tmp/opencode` and run:

```sh
python3 tool/ci/capture_v2_turn_actions.py --root /tmp/opencode/NEW-runtime --out /tmp/opencode/NEW-evidence --binary /path/to/pinned/opencode
```

The collector verifies the binary, uses its own Git project, home, data and
password, and never contacts the user's OpenCode server. Do not overwrite this
capture or present its deterministic provider output as real-model quality.
