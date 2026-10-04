# V2-005B: observed retry, inbox and reconnect contract

These are observed native OpenCode **2.0.22** responses and global SSE frames,
captured on Linux x86_64 using the official `@opencode/cli@2.0.22` managed service
at `http://127.0.0.1:49374`. The sibling A evidence establishes the native
info/auth/pairing/full-turn producer. B uses its own disposable directory and
sessions and never retrieves `/api/credential`.

The directory had `git init` without an initial commit, so OpenCode resolved
`projectID: "global"`. This is a directory-scoped capture, **not evidence of
distinct-project isolation**. B changed no saved permission rules. For a future
distinct-project capture, create an initial Git commit before the first native
location lookup, in a new disposable directory.

## Verification

From the repository root:

```sh
python3 test/contract/fixtures/opencode/2.0.22/b/validate.py
```

The validator contacts no server or model. `validation.json` records **125 named
checks**, **174 distinct observed live events**, and observed session/assistant
cost of **US$ 0**. `provenance.json` records fixture SHA-256 digests, source pin,
runtime, commands and limits. The capture used twelve execution-waking prompt
POSTs, producing nine observed `execution.started` frames and one automatic
restart recovery that began before the new subscriber attached; non-executing
`resume: false` admission/replay probes are separate. Provider steps can span
multiple requests within an execution.

Fledge Alpha Free returned actual `provider.auth` 403 failures during B, with
the provider message that its free tier can only be used within OpenCode.
`queue-steer-fledge-policy-denial.json` preserves those failures. The enabled,
zero-cost **Space Bunny Free / low** model then ran the successful live captures;
there was no paid fallback or authentication/header workaround.

## Observed matrix

| Operation/scenario | Evidence and result |
|---|---|
| Create, same native ID and payload | `create-matrix.json`: 200 with the original session. |
| Create, same ID and changed title/metadata | 200 with the original session; changed fields were ignored. A supplied ID is not a payload-conflict detector. |
| Prompt, same ID while pending | `prompt-matrix.json`: 200 with the original admission. Changed text and delivery also returned the original admission. |
| Prompt, reused ID in another session | 409 `ConflictError`. This is an identity/lifecycle conflict, not proof of changed-text rejection in the same session. |
| Identical prompt text with different IDs | Two distinct pending admissions. Content matching must not merge them. |
| Create/prompt timeout before forwarding | A controlled local HTTP proxy withheld the request; the client saw `TimeoutError`, authoritative lookup showed absence, and a same-ID retry admitted it. |
| Create/prompt timeout after admission | The proxy forwarded to native OpenCode and withheld its real 200 response; the client saw `TimeoutError`, authoritative lookup found the admitted object, and same-ID replay returned it. |
| Pending cancel and repeat cancel | `cancel-matrix.json`: 204, then 204 no-op. Reposting the cancelled ID **re-enqueued it**; `matrix-events.json` records enqueued → cancelled → enqueued at aggregate sequences 1 → 5 → 6. Cancellation does not preserve a permanent prompt deduplication tombstone. |
| Queue, explicit steer, queue-to-steer change | `queue-steer-space-bunny.json`: one owned active execution; history promotion order was first prompt, changed-to-steer prompt, explicit steer, then queued next-turn prompt. The cancelled item was absent from history. All completed successfully. |
| Replay after delivery | Same-ID changed text retained the projected original user content. Cancel was a 204 no-op; patching delivered input was 409. |
| Delivery in replay response after promotion | `promoted-delivery-replay.json`: replay of a promoted queue item with requested `steer` returned `delivery: "steer"`, while history stayed unchanged. Do not require byte-identical admission responses across pending/promoted states. |
| Interrupt with `resume=true` | `interrupt-resume.json`: native `execution.interrupted {reason:"user"}`, interrupted tool/step, then steering resumed in a new successful execution. Queued input stayed parked until explicit cleanup. Idle interrupt returned `interrupted:false`. |
| Disconnect during a native delta | `disconnect-reconnect.json`: one subscriber closed exactly at its first delta; an uninterrupted subscriber recorded the matching prefix plus authoritative text ended and success. Hydration restored the completed marker/history. |
| SSE reconnect with `Last-Event-ID` | The new stream contained a fresh `server.connected` and the subsequently triggered rename event, with no replay of the lost completion events. Reconnect requires hydration. |
| Managed service stop/start | `service-restart.json`: real native service commands exited zero, PID changed, version/address remained fixed, the prior paired token authenticated, pending inbox input and an existing terminal transcript survived, and the interrupted foreground work resumed to a successful native tool/text result. |

The native calls and exact request/response payloads are in each fixture's
`calls` array. Stream objects retain JSON events and their captured SSE frame
lines. Controlled-proxy diagnostics are labelled separately from the native
body/status. Tokens and codes stayed in memory; credential fields and opaque
provider state were sanitized.

## Retry and interruption boundaries

Preserve a stable request ID and the original payload before a send. During an
uncertain admission, reconcile authoritative inbox/history/session state before
same-ID replay. Changed text is not verified by a 409 check on this version.
Once cancellation is requested, suspend replay of the original send while the
cancel is submitting or its outcome is uncertain. Keep that fence until
authoritative inbox/history reconciliation establishes the lifecycle outcome;
do not resume send retries merely because the cancel response was lost. After
confirmed cancellation, blindly retrying the old ID can recreate work. A replay
may also wake execution unless `resume:false` is used; it does not establish
that every other mutation is replay-safe.

Do not infer process-wide active state from session history alone. The active
list is ownership of the current native process. A reconnect or service restart
requires refreshing active sessions, inbox, history and pending interactions.
In sibling C's
[`post-restart-question-recovery.json`](../c/post-restart-question-recovery.json),
a question dismissal that had emitted an interruption with reason `shutdown`
was followed by a new native question after this coordinated restart. Explicit
feedback settled it; the earlier interruption was not permanent cancellation.

## Limits and diagnostics

- The old SSE subscriber closed before it received the shutdown interruption;
  the new subscriber attached after startup recovery began. Specific shutdown
  reason and startup `execution.started` are not asserted as observed live
  events. History contains the aborted assistant, synthetic continuation and
  successful recovery, and the native PID/state evidence establishes restart.
- Experimental durable-log reads with default and zero cursors returned only
  `log.synced` at sequence 29. Their raw responses are retained in
  `restart-durable-log*.json`; durable replay/cursor acceptance belongs to
  V2-005E and is not passed here.
- No `session.retry.scheduled` event was emitted. This matrix measures admission
  retry, not provider retry scheduling/backoff.
- The first Space Bunny shell probe succeeded but its collector looked for a
  tool name on `tool.called`; the actual name is on `tool.input.started`.
  `shell-probe-space-bunny.json` preserves that trace and the initial diagnostic
  flag. Subsequent live orchestration used the actual called input and native
  terminal event types.
- Final native inspection found **11 owned sessions, zero pending inbox items
  and zero owned active executions**. It is a capture-time observation, not a
  promise that all forms of interruption are permanent across future restarts.
- No other OS/browser/network target, physical filesystem containment, app
  reducer, transport adapter or aggregate G1/parent V2-005 acceptance is claimed.
