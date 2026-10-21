# Contract evidence fixtures

Observed, versioned evidence for the CodeWalk v2 contract work: the OpenCode
2.0.22 captures and the Codex native captures. Read the capture's own
`README.md` first — it states what was observed, what was not, and what the
evidence does not prove.

| Family | Index | Content |
|---|---|---|
| `opencode/2.0.22/` | `opencode/2.0.22/README.md` | the OpenCode 2.0.22 native capture and its follow-up captures |
| `codex/<codex-version>/` | `codex/README.md` | the Codex native captures |
| `native-builds/` | — | build artifacts of the native verification, not evidence |

## A capture is immutable, and that includes its publication field

A capture directory is versioned exactly as it was recorded. Its `SHA256SUMS`
manifest is hash-pinned in the acceptance record of the owning Issue, so the
capture bytes are never edited after publication: editing a file would change
the manifest and break the published record of what was accepted.

The consequence is deliberate: the `publication` field and any present-tense
sentence inside a capture describe the state **at capture time**, when the
fixture was indeed local and uncommitted. They are not a claim about the
current tree. The current state is recorded here and in the tracker.

| Capture | Versioned in | Owner Issue | State |
|---|---|---|---|
| `codex/0.160.1/initialization-linux/` | `250443e7`, `3981fb2b` | #245 | partial G1 evidence, not a G1 pass |
| `codex/0.160.1/transport-upgrade-linux/` | `250443e7`, `3981fb2b` | #245 | partial G1 evidence, not a G1 pass |
| `codex/0.160.1/owned-thread-corrected-linux/` | `250443e7`, `3981fb2b` | #245 | partial G1 evidence, not a G1 pass |
| `opencode/2.0.22/web-configured-origin/` | `250443e7`, `3981fb2b` | #247 | partial SP-04 evidence, awaiting acceptance; Web/Chrome is post-MVP |

A capture never satisfies a gate by itself. G1 needs the full `v2-plan.md`
§13.1 matrix observed against real Codex and Claude Code sessions; G2, G5 and
the platform gates have their own Issues.
