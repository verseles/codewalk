# V2-005E — observed Linux filesystem, log, attachment and CORS subset

These fixtures were recorded on native OpenCode **2.0.22**, Linux x86_64, the isolated managed loopback service at port 49374. The disposable project had an initial Git commit before native access, giving it its own project identity. V2-005B is accepted at `7d8c690ef2b6ea89061892a41795d2923db96312`. The bounded preflight and evergreen acceptance belong to [#244](https://github.com/verseles/codewalk/issues/244#issuecomment-5976884700); these files do not accept aggregate SP-01 or a release gate.

## Observations and safe consumer boundaries

| Surface | Observed result | Consumer boundary |
|---|---|---|
| Service credential | Official `opencode2 service get password`, captured only in memory, authenticated `/api/info`; unauthenticated API rejected; native config/registration modes 0600. | Supported local adoption only on tested Linux namespace. No provider credential files or `/api/credential` accessed. |
| Durable log | Two global SSE renames at sequences 1/2 match authoritative title reads. Default, `after=0` and known cursor reads yield only `log.synced`; follow also fails to deliver the confirmed second rename. | **Durable replay unavailable** on this stock runtime. Hydrate snapshots; do not interpret a watermark alone as replay proof. |
| File write | Raw-body normal write works. Traversal, absolute and real symlink targets write outside the project into the owned sibling directory. Atomic symlink replacement races write outside on 66 of 95 requests whose precheck resolved inside. | **Physical file-write containment unavailable**, even with experimental setting ON. Read-only browsing; no shell workaround. |
| File read/list/find | Normal read succeeds; tested symlink/traversal reads return empty 500. Listing supports sibling paths. Find initially returns an empty new-file result; later returns both committed baseline and new file, plus symlink-relative entries. | Do not equate list/find disclosure or lexical paths with write containment. Tested read cases do not prove race-proof reads. |
| PNG | Valid generated inline PNG containing an attachment-only marker; Space Bunny Free returns the exact marker. One provider step, no tools, cost zero. | Native PNG admission and model recognition observed for this version/model. |
| PDF | Valid generated PDF admitted and stored as `application/pdf`. The enabled free model declaring PDF input, Muse Spark 1.3 Free, fails with native `provider.auth` 403 / `FreeTierError`. | **PDF model recognition blocked**, not a discard/unsupported-format proof. The approved product PDF-disabled policy remains unchanged. No header/authentication bypass or paid fallback. |
| CORS | Localhost origin gets ACAO and Chromium reads `/api/info` and first SSE `server.connected`. Foreign mapped-loopback origin gets no ACAO; native GET still returns 200 and OPTIONS 204, while Chromium blocks both reads. | Browser-readable CORS boundary is observed; HTTP status alone is insufficient. Service configuration was not changed. |
| Three-session bandwidth | Three Space Bunny Free text turns overlap for 1,933 ms. One global SSE stream consumes 22,686 HTTP-body bytes over 2.339 s, including 22,673 selected frame bytes and 13 comment bytes; no ambient events in that turn window. | Loopback measurement only; excludes HTTP headers, TCP/IP and cellular conditions. No hourly/mobile extrapolation. |
| Idle observation | A separate 32-second global-stream observation measures three 13-byte comments. Eight ambient events occurred while owned-session cleanup ran; their payloads are not retained. | Distinguish comment traffic from ambient event bytes. This is not a quiet cellular baseline. |

The source evidence corrects an older research inference: **both pinned 2.0.21 and 2.0.22 source forward PDF media** in `session/runner/to-llm-message.ts:75–82`: [2.0.21 / `8a8bd622a3d7dc29ccf30ec17f84e363ed95ed72`](https://github.com/anomalyco/opencode/blob/8a8bd622a3d7dc29ccf30ec17f84e363ed95ed72/packages/core/src/session/runner/to-llm-message.ts#L75-L82) and [2.0.22 / `05018b8862a8fc198ec9810aafd397c96bb7d86e`](https://github.com/anomalyco/opencode/blob/05018b8862a8fc198ec9810aafd397c96bb7d86e/packages/core/src/session/runner/to-llm-message.ts#L75-L82), directly inspected. This is a static source fact, separate from admission and provider recognition. Stock CLI does not pass `events.persist`; `core/bus.ts` defaults persistence to false. That static configuration is consistent with watermark-only live log results; no patched server or invented flag was used.

## Evidence layout

- `service-credentials.json`, `model*.json`: version, supported retrieval/mode checks and authoritative zero-cost enabled model metadata. No credential value, digest or Authorization header is saved.
- `durable-log.json`: real rename calls, authoritative reads, global events and experimental default/cursor/follow responses.
- `filesystem.json`: raw-body request hashes, actual bytes/destinations, read/list/find responses and real atomic replacement observations. All outside-project writes remain inside the explicitly owned `capture-e/outside` sibling.
- `attachment-png.json`, `attachment-pdf.json` and generated binaries: native admission/history/events, actual provider results, attachment digest and marker relationship. API inputs use `files[].uri`; stored normalized files use MIME/data/source.
- `loopback-bandwidth.json`, `loopback-idle.json`, `cors.json`: measured stream counters/intervals, ambient boundary and real Chromium/native transport observations.
- `cleanup.json`: six owned sessions deleted and then 404; empty inboxes before deletion; disposable Git worktree clean and sibling files removed; shared service PID preserved.
- `source-evidence.json`: immutable official URLs, source hashes and cited excerpts. `capture_source.py` preserves the collector with explicitly recorded post-review safeguards; its phases intentionally contact/mutate the authorized disposable runtime and are **not** the offline validation command.
- `provenance.json`, `SHA256SUMS`, `validate.py`: evidence relationships, limits and portable integrity/semantic checks. `validation.json` is a derived optional report excluded from immutable digest checks.

## Validation and repeatability

Run from any checkout, without server access or environment setup:

```sh
python3 test/contract/fixtures/opencode/2.0.22/e/validate.py
```

Default validation only reads fixtures. Explicit `--write-report` writes derived `validation.json`. It checks digests, native version/auth, marker/admission/model relationships, owned paths and race writes, native versus browser CORS, log/snapshot divergence, execution overlap/cost/budget and final cleanup. It does not replay live requests. The PNG/PDF collector is intentionally guarded against repeated provider execution; any new capture requires a new bounded preflight and disposable state.

Budget: 90 minutes, at most six actual free provider executions including continuations. Observed **five admissions/five provider steps/five native execution starts**, no tools, continuations or retry scheduling, US$ 0. The sixth execution was unused because the only enabled free model declaring PDF support returned the native authentication restriction. These are native event observations, not a count of invisible provider transport attempts. A cold new-project catalog was initially unsettled before the successful catalog refresh; no provider request occurred during that preparation.

Independent review confirmed the observed evidence and found two reusable-collector limits. Model `apiKey` fields, including public placeholders, are now redacted and included in the offline credential audit. The archived collector adds an owned-session ledger, a pre-admission batch limit and best-effort `finally` interruption/reconciliation. Its provider-step accounting remains **retrospective after terminal turns**: it cannot guarantee six under native automatic continuations/retries. Before reproducing, establish a fresh live execution ledger, stop new admissions and interrupt owned work on the agreed threshold, with `finally` cleanup and verified accounting; do not treat this archive as proven hard enforcement. These source safeguards were reviewed statically, without another live provider call, and do not alter the observed five-step capture or completed cleanup.

## Remaining acceptance

Windows junctions and native non-Linux service adoption, Safari, configured custom-origin restart behavior, HTTPS-to-LAN mixed content and **cellular bandwidth with three concurrent sessions** remain pending their resources/owning work. Durable replay and physically contained direct write are explicitly unavailable on this observed runtime. Provider PDF recognition remains blocked; changing product PDF policy still requires its decision owner. These fixtures support the Linux subset and honest capability fallbacks; they do not close full #244 or parent #239 automatically.
