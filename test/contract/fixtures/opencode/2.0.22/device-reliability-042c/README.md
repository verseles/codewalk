# V2-042C device reliability matrix (OpenCode 2.0.22)

Observed device evidence for V2-042C (#408, §11.6 Seq 3.4), not a synthetic
fixture. A cell is `pending` until it runs; scripted suites never fill one.
`tool/ci/validate_device_matrix.py` checks the matrix (`--final` once every
cell ran).

## What is tested

The app reconnects its endpoint stream at once when it returns from the
background or the network changes (`v2-plan.md` §6.10 step 7), instead of
waiting for the 1–30 s retry delay or the 45 s stall watchdog. Android reports
transports through connectivity_plus; Linux reads NetworkManager's primary
connection, so a handover between two working links is seen. Every reconnect
hydrates from authoritative reads: nothing is resent, replayed or invented.

Each cell runs one fresh session and one unique prompt marker on one target.

| Scenario | Disturbance during a running turn (`CW-SLOW` prompt, 30 s) |
|---|---|
| `drop` | No network for 15 s (airplane mode, or `nmcli networking off`), then the same network returns |
| `handover` | Wi-Fi off with mobile data on, then Wi-Fi back; on Linux, Wi-Fi to the phone's USB tether and back |
| `background` | The app in the background for 60 s (Home and screen off on a phone; minimized on Linux) |
| `restart` | `restart` on the server console: SIGTERM of the owned `serve`, started again on the same state |
| `tui` | With the catalog open, the official TUI (or, on the emulator, another HTTP client) starts a session |

## Pass, fail, inconclusive

A cell passes when the prompt shows exactly once, the server records no
duplicate, nothing stays running after the server settles, the view is live
again within the bound below, and evidence is referenced. A handover also
needs the observed transport change (Android `dumpsys connectivity`, Linux
`nmcli` and `ip route get`); without it the cell is inconclusive.

| Scenario | Bound, from the end of the disturbance |
|---|---|
| `drop`, `handover`, `background` | live again within 10 s |
| `restart` | live again within 30 s of the server answering `/api/info` |
| `tui` | the new session listed within 10 s, without a refresh |

Fail and inconclusive cells carry their reason. A target without a second
transport records the handover as inconclusive; it is never inferred from the
drop.

## Server

`tool/ci/v2_device_server.py` runs the pinned 2.0.22 build (linux-arm64, or
linux-x64 on the CI runner, each verified against the registry integrity and
the pinned digests) in an isolated home, with a zero-cost loopback stub
provider. Devices reach it only through a relay that records request metadata
(time, method, route template, status, stream open and close, a per-run client
alias), never bodies, headers, credentials or addresses. Its `report` command
gives the prompts per session, duplicates, the active sessions and the
event-stream reconnect gaps per client.

On 2.0.22, SIGTERM of `opencode serve` ends a running step as an aborted
assistant message ("Step interrupted") and the restarted server does not
continue it; the restart continuation recorded in `../c/README.md` came from
the managed service, which this disposable run never touches. The restart
cell therefore checks that the session survives, the prompt shows once and the
view settles to the server's state without a stuck running turn.

The durable event log stays off: on the stock 2.0.22 runtime its reads return
only `log.synced` (`../e/README.md`), so every reconnect hydrates instead.

## Records

`matrix.json` holds the 20 cells. A cell records the build commit, the steps,
UTC start and end, `recovery_seconds`, `prompt_shown`, `duplicates`,
`stuck_running`, the handover `transport_proof`, the reason when not passed
and the evidence files. The emulator cells come from
`.github/workflows/v2-device-reliability.yml`
(`tool/ci/device_reliability_android.py`); the owner's cells from the runbook
on #408, transcribed without changing the owner's verdicts. Addresses,
passwords, Authorization headers, pairing data and real prompts are never
recorded.
