# V2-005D — bounded native retry/quota observation

**Outcome: inconclusive for both provider retry and quota.** This supplement
records real OpenCode 2.0.22 activity on Linux aarch64, captured on 2026-10-09.
It does not accept the remaining criteria of [#243](https://github.com/verseles/codewalk/issues/243),
parent #239, or unblock the stream consumer #274. The original
[`d/` evidence](../d/README.md) remains unchanged.

## Observed results

| Slice | Actual outcome |
|---|---|
| Initial preflight | The first `/api/agent` snapshot was empty. The collector stopped before any session or provider input: zero executions, 1.002 seconds. The diagnostic is retained. |
| Corrected preflight | A bounded wait obtained the configured agent in a fresh committed project and fresh private HOME/XDG paths. Current native catalog confirmed enabled, active `opencode/space-bunny-free#low`, with zero input/output/cache prices in every tier. |
| Observation | Two authored inputs, two native execution starts, two provider steps and two successful native terminals; 42 parsed native events without an observed stream fault. The corrected run lasted 4.311 seconds. |
| Retry/quota | No `session.retry.scheduled`, `provider.rate-limit`, or `provider.quota` occurred. Absence in this short, bounded sample is inconclusive, not proof of provider policy or remaining quota. |
| Cleanup | Both owned processes ended. Both observed sessions had empty active/inbox/permission/form state, were removed with HTTP 204 and then returned 404. The corrected loopback listener was verified closed. |

The configured **one-step agent is an experimental limit**. The first assistant
returned `Maximum agent steps were reached. No work was completed, and no tasks
remain. Next step: provide the required task details.` instead of the requested
first marker. The second returned `RQ_OBSERVATION_TWO`. These native outputs are
preserved, not replaced with expected text. Successful execution terminals do
not establish successful completion of both marker instructions or behavior of
the unrestricted/default agent.

## Authority, isolation and budget

- The owner authorized a temporary isolated official 2.0.22 runtime, at most
  30 minutes of observation including cleanup, four actual execution starts
  and US$0, using currently enabled free models. The experiment intentionally
  limited authored inputs to two; remaining execution allowance was not used
  to force quota exhaustion.
- The exact `@opencode/cli-linux-arm64@2.0.22` archive matched its registry
  SHA-512 integrity. Archive and executable SHA-256 values are retained in
  `acquisition.json`; the executable reported `opencode v2.0.22`. Registry
  integrity verification is not a claim of independently verified publisher
  signature/attestation.
- A foreground process listened only on loopback. Its allowlisted environment
  used temporary HOME/XDG/config/data/cache/runtime paths; the existing CLI,
  shared services, project settings and provider credentials were not changed.
  Each disposable project had an initial Git commit before native location
  access. The first diagnostic admitted no work and was not resumed.
- Native agent/config guards verified one step, deny rules, no title/compaction
  agents and `warming:false`. The service password and Basic header stayed in
  memory/environment; headers were never included in the saved calls. Secret
  fields were redacted before disk writes and opaque provider state was omitted.
- Provider steps and automatic attempts are distinct from execution starts.
  The two observed native step costs were zero. No provider error was induced,
  no private quota/credential endpoint was used, and no paid fallback occurred.

The official source authority is
[`05018b8862a8fc198ec9810aafd397c96bb7d86e`](https://github.com/anomalyco/opencode/tree/05018b8862a8fc198ec9810aafd397c96bb7d86e).
Its retry, structured-error, interrupt, model-cost and configuration definitions
were inspected directly. The existing anchors retain their separate primary
2.0.21 pin. OpenChamber's
[`applyRetryOverlay.ts`](https://github.com/openchamber/openchamber/blob/24dac3fb23dd025c6cff135614b96e21a8e08348/packages/ui/src/components/chat/lib/turns/applyRetryOverlay.ts)
was inspected only as secondary context: its client-generated retry notice is
not a native event and is not fixture evidence.

## Files and validation

`capture.json` retains sanitized native calls, events and history snapshots.
`diagnostic-agent-initial.json` retains the original unsuccessful preflight.
`execution-ledger.json` and `cleanup.json` are explicitly derived slices of
those observations. `provenance.json`, `acquisition.json` and `validation.json`
record source/runtime identity, limits and the completed audit.

A read-only operational audit passed **82 checks**, including native identity,
every selected price tier, independent lifecycle/ownership, unique event IDs,
redaction, budget, no tool/child activity, absence classification and cleanup.
The audit and collector were temporary operational tools; their hashes and
original command are recorded in provenance, rather than installing another
application validator or changing the historical D validator.

From this directory, verify the immutable corpus:

```sh
sha256sum -c SHA256SUMS
```

From the repository root, the historical read-only commands remain:

```sh
python3 test/contract/fixtures/opencode/2.0.22/b/validate.py
python3 test/contract/fixtures/opencode/2.0.22/d/validate.py
```

They passed 125 and 320 checks during the audit; they establish their own
historical subsets, not acceptance of this supplement's missing events.
No app code, dependency, build configuration or fixture consumer was changed.
Full Flutter/build checks and implementation review therefore use the
data/static-documentation exemption.

## Resume boundary

Further retry/quota acceptance requires **naturally observed native events**
under a new bounded preflight with appropriate authorization and resources.
Do not repeat model calls merely to manufacture a quota failure. Android,
installed-client acceptance, other platforms and the parent SP-01 gate remain
separate. This corpus was committed locally; publication is a separate action.
