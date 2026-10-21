# Codex observed captures

Immutable native captures of the Codex app-server, versioned by Codex version
(`<codex-version>/<capture-name>/`). They are the Codex side of the G1 gate,
tracked by [#245](https://github.com/verseles/codewalk/issues/245) (V2-006).
The Claude Code side of G1 is a different work item
([#246](https://github.com/verseles/codewalk/issues/246), V2-007) and has no
capture in this directory.

**Boundary.** A capture here is *partial* evidence of one topology and one
server version. It never satisfies G1 on its own: G1 needs the full
`v2-plan.md` §13.1 scenario matrix observed against real Codex and Claude Code
sessions. Each capture states its own limits in its `README.md`.

**Rules.**

- A capture directory is immutable. Its `SHA256SUMS` covers its own files, and
  `provenance.json` records the source, the version, the topology and the
  capture time. Do not edit, reorder or regenerate them; a new observation is a
  new capture directory, not an edit.
- `README.md` states what was observed, what was not, and what the evidence
  does not prove. Keep that distinction when citing a capture.
- The captures are inputs for the gate work items and the live contract
  checks. They are not fixtures of a passing test: a test that reads them must
  assert the observation they record, not a generic shape.

**Current captures.**

| Capture | Codex | Host | Feeds |
|---|---|---|---|
| `0.160.1/initialization-linux/` | 0.160.1 | Linux | #245 — native initialize/initialized and the owned-project query |
| `0.160.1/transport-upgrade-linux/` | 0.160.1 | Linux aarch64 | #245 — HTTP WebSocket-upgrade statuses per topology |
| `0.160.1/owned-thread-corrected-linux/` | 0.160.1 | Linux ARM64 | #245 — the corrected owned-thread lifecycle |
