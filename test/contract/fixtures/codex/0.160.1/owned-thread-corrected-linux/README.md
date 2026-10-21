# Corrected owned-thread lifecycle — Linux ARM64 / shared daemon UDS

**Status:** observed partial prerequisite, accepted by the owner on2026-10-06.
Recorded once on 2026-10-06, after explicit owner authorization, against the
existing shared Codex app-server0.160.1. This is a new isolated zero-turn
thread; it does not replace or resolve the earlier failed unit's evidence.

The owner's literal `sim` accepts this bounded unit's live two-client
metadata access and scoped cleanup. The full-gate and historical-resource
limits below remain unchanged.

## Native observations

| Observation | Result | Retained frame evidence |
| --- | --- | --- |
| Exact fresh-cwd baseline is empty | observed | first connection3–4 |
| Correlated owned non-ephemeral start, read-only/never, environments=[] | observed | first connection5–6 |
| Actual returned source | `vscode` | first connection6,8; second connection4 |
| Owner's metadata-only read | observed | first connection7–8 |
| State-DB-only discovery before any turn | observed absent | first connection9–10 |
| Second client's metadata-only read with owner close deferred | observed | second connection3–4 |
| One targeted owned-thread deletion acknowledgement | observed | second connection5–6 |
| Exact-cwd state-DB-only list after delete | observed empty | second connection7–8 |

The native diagnostic exited0 in1.670s. Its fresh project was removed, no
private recovery remained, and the parent reaped the process. Before/after
alias/socket/parent identities and daemon/default CLI versions matched;
peer UID and executable SHA-256 were verified. No RPC errors were observed.
The primary connection received14 messages, dropped9, and retained11 client
and server frames; the second received10, dropped6, and retained9 frames.
Dropped notifications/foreign traffic were not retained or answered.

The `vscode` value is the returned native source classification, not evidence
that a real IDE or TUI client participated. All three scoped lists explicitly
requested the ten contractual source kinds. Absence from state-DB-only listing
does not contradict the successful live metadata-only reads.

## Provenance and redaction

- Topology: caller-owned private UDS on an existing shared daemon, Linux
  `aarch64`; no daemon/listener lifecycle or account configuration changes.
- Server/managed/daemon-client version0.160.1; default CLI0.160.0.
- Connected executable SHA-256:
  `fbbaec80443919f86dd63648a0b62759cf6f1d0e09310602fde96885e0bceb3e`.
- Reviewed diagnostic SHA-256:
  `079651f74bdfdfb6d99316f2d7974fdb610cb396e603f56cbc763ba2651d0fe4`.
- Reference source pin:
  `d27764b82f7118f674371e6d6e76271d9d606edb`; installed build commit unverified.

`native-probe.public.json` contains the allowlisted native observation,
redacted as it was collected. It is whitespace-reformatted only; parsed JSON
must match the retained original public capture exactly. Provenance records
both hashes separately. Raw thread IDs, project/home/rollout paths, user agent,
cursors, arbitrary error text and foreign payloads are excluded.

The diagnostic passed Dart analysis and19 synthetic offline controls before
execution; twelve independent helpers approved its code with no actionable
findings. Those checks are not native evidence. No code changed for this run.
For this static recording, validation checks JSON equality, frame correlation,
allowlisted methods, counters, source/filter consistency, redaction, hashes,
and actual removal of this invocation's project.

Budget and exact commands were recorded before execution in
[#245 comment6015961836](https://github.com/verseles/codewalk/issues/245#issuecomment-6015961836).
Hard outer limit150s, start20s/delete15s/other RPCs5s. There was exactly one
start and one delete attempt, two metadata-only reads, three scoped lists,
two initialize requests and two initialized notifications. Zero turns and
provider/model inference requests were sent; expected incremental inference
spendUSD0. Subscription monetary value remains unknown.

## Explicit limits

This proves live two-client access and scoped cleanup for this own zero-turn
thread using the deferred owner-close strategy. It does not prove durable
history after owner disconnect, state-only discovery, real TUI discovery,
text/tools/approvals/questions/children/usage/reconnect coverage, other OSs,
historical resource deletion, full G1/G2/G5, SP04 or downstream gate acceptance.
The earlier private owned-resource recovery remains preserved separately.
No commit, push, release or deployment accompanies this local recording.
