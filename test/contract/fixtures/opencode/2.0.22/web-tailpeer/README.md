# SP-04 private Tailscale peer diagnostic

Opt-in diagnostic for one Chrome/compiled-Dart capture from a distinct machine:
trusted private HTTPS on port 8443 to native OpenCode 2.0.22 HTTP on the peer's
Tailscale IPv4 port 45131. Python static serving is loopback-only on port 45130.
It requires the owner's exact remote-command approval and pre-capture review.

This is not the production client or a public Pages-origin LAN/LNA observation.
The native inference budget is zero. Existing Serve routes and managed services
must remain unchanged. Blocked fetch/SSE/ticket operations are retained as
browser observations; they do not pass #358 or imply a tested WebSocket.
No control-plane ticket fallback, certificate override or browser security
workaround is used.

## Preparation and verification

`prepare.py --prepare` creates its own private `/tmp/opencode` root, verifies
both accepted package hashes, checks the isolated native version/help, and
builds offline with Flutter 3.44.1/Dart 3.12.1 and `package:web` 1.1.1.
The compiled input reuses `../web/flutter_main.dart.txt`, with four narrowly
defined changes: reject redirects, retain terminal handles only after their
WebSocket constructor/open succeeds, preserve non-200 REST status without JSON
decoding, and abort/return on non-200 SSE responses before waiting for connection.
Earlier fixtures are immutable. Preflight and offline validation require the
same four recorded build inputs; their hashes are checked before remote transfer.

Offline checks: `python3 -B -m unittest test_semantics test_supervisor`
(47 negative mutation controls, foreground admission, typed transport and
deadline regressions, plus eight disposable-process supervisor tests) and
`node test_cdp.mjs` (including typed remote failures and
never-attempted versus unknown-resource cleanup admission).
Actual execution: `node <prepared-root>/capture.mjs --run-approved`.
Validate retained evidence with `python3 -B validate.py <capture-root>`.
The runtime limit is 180 seconds, setup/execution/validation 1200 seconds, and
cleanup 120 seconds. Code development and helper review use a separate budget.

Cleanup clears browser credentials, deletes only the owned native session/PTY
and verifies 404, stops owned process groups, restores the exact Serve baseline,
and removes only the invocation's remote and Snap-private roots. Failure leaves
the capture inconclusive and preserves recovery material. Local evidence is
retained for validation/archival before the local invocation root is removed.

## Observation

The single authorized run on 2026-10-07, from 11:44:20.788Z to
11:44:41.199Z, returned **inconclusive**. Its unmodified, sanitized output is
retained in `evidence/capture.json`. The owned native listener returned one
`ReadinessInfo` HTTP 200; startup then failed with `remote control failed`,
before browser launch or session/PTY creation. There are no browser operations,
network rows or bootstrap observations. Native inference and cost were zero.
This capture does not pass the observation validator or #358.

Source investigation identified an admission defect in `peer.py`: the default
foreground Serve command at line 188 is followed by checks for top-level `TCP`
and `Web` entries at lines 191–199. In the installed Tailscale 1.102.4 contract,
foreground configurations live under an IPN session key in `Foreground`:

- [Pinned `ServeConfig` definition](https://github.com/tailscale/tailscale/blob/v1.102.4/ipn/serve.go#L68-L74).
- [Pinned CLI foreground assignment](https://github.com/tailscale/tailscale/blob/v1.102.4/cmd/tailscale/cli/serve_v2.go#L505-L509).

The 16.394-second collection duration and sole readiness call are consistent
with the 15-second admission wait. The live foreground configuration and CLI
stderr were not retained, so the capture alone does not prove the exact runtime
failure. The corrected diagnostic admits one exact new `Foreground` session,
preserves the complete baseline, checks its child process and revalidates the
route before browser operations. Cleanup stops only owned processes and waits
for baseline parity, without issuing `serve off`. Remote failure evidence is
limited to allowlisted phase/type and numeric command/exit facts. Focused tests
and the eight-helper R7 review passed before the owner's authorized fresh run.

Independent post-run checks confirmed that the owned native PID and processes
were absent, ports 45130/45131/8443 had no listeners, and the original remote
Serve routes (3001/4097) and local route (443) were unchanged. The collector
retained the private remote invocation root because session/PTY absence flags
were unavailable after this early startup failure. At 11:58:14.732539Z, guarded
recovery verified the exact caller-owned root, binary, empty project, process
absence and Serve baseline before removing only that remote invocation root;
root/port absence and baseline parity were verified again afterward. This later
cleanup is recorded in `evidence/recovery.json`; the frozen capture is unchanged.
The local prepared root remains available for build-provenance inspection.

### Authorized fresh attempt

The corrected diagnostic ran once from 13:16:38.440Z to 13:16:43.577Z on
2026-10-07. `evidence/capture-2.json` retains its unmodified **inconclusive**
result: after one owned `ReadinessInfo` HTTP 200, the foreground Serve child
exited with code 1. The recorded failure is `foreground-admission/AssertionError`
with command ID 1 and `serveExitCode: 1`; collection stopped after 1.475 seconds.
No browser, session or PTY creation was reached. The exact CLI exit reason
remains unknown: raw CLI output is intentionally not retained, and neither an
operator-permission problem nor an environment-variable cause is established.

This run's cleanup distinguished never-attempted resources and removed the
owned remote root automatically. Independent checks confirmed root/native PID
and invocation-process absence, free selected ports and unchanged local/remote
Serve baselines; see `evidence/recovery-2.json`. Normal and restricted PATHs
resolve the same Tailscale 1.102.4 binary, excluding a different-binary/version
explanation. The compiled Dart/JavaScript hashes match the first attempt.
Inference and cost remain zero. Both runs remain rejected as transport
observations; #358 is still pending. Further execution required renewed
authorization at this checkpoint; the later authorized attempt is recorded below.

### Read-only authorization diagnosis

At 13:52:40 UTC, a separate `GET /localapi/v0/check-prefs` over the daemon's
Unix socket returned HTTP 403 with the exact fixed `checkprefs access denied`
response for caller UID 1001; see `evidence/authorization.json`.
The pinned [handler checks `PermitWrite` before rejecting non-POST methods](https://github.com/tailscale/tailscale/blob/v1.102.4/ipn/localapi/localapi.go#L1047-L1055),
so this GET verifies the write-authorization gate without changing preferences
or creating a Serve session. [Setting Serve configuration requires the same gate](https://github.com/tailscale/tailscale/blob/v1.102.4/ipn/localapi/serve.go#L45-L49).

The current diagnostic caller therefore cannot create the temporary HTTPS route.
This is an established prerequisite blocker, not a reconstruction of the
discarded stderr from attempt 2. Its exact exit reason remains unproven. At that
checkpoint the next step was execution authority for the owned route and cleanup.
No privilege, operator preference,
existing route or managed service was changed by this authorization check.

### Authorized privileged attempt and deferred remainder

The owner subsequently authorized sudo on the required machines. The diagnostic
now starts only the fixed private Serve command through `serve_supervisor.py`
using `sudo -n /usr/bin/python3 -I -S`. The native server and static HTTP process
remain unprivileged. This is an operator-run diagnostic using an account that
already has sudo authority, not a restricted privilege-delegation service.
The supervisor owns its child and responds to stop, controller EOF, a 10-second
heartbeat lease, signals and a 180-second lifetime. It sends TERM, escalates to
KILL after three seconds when necessary, and reports reaping. External SIGKILL
of the supervisor remains an exceptional case requiring guarded manual recovery;
the diagnostic does not claim a dead supervisor can enforce its lease.

Attempt 3 ran from **16:05:25.053Z to 16:05:37.814Z on 2026-10-07**.
Its frozen output is `evidence/capture-3.json`, SHA-256
`f82250338862fbc6aba4672bb1ecfee8f836ce4c24a5acbf8bf34e33728f4772`.
Chrome 154 loaded the compiled Dart probe through trusted TLS 1.3 and observed:

- Authenticated HTTP 200 for native info and the owned session snapshot.
- SSE 200 with `server.connected`, then the owned Unicode rename in a later read.
- A browser-obtained PTY ticket (200), WebSocket upgrade (101), native ready text
  and `ECHO:TAILPEER_PING`.

There were no browser security overrides or native model turns. Both endpoints
were classified as `Local` by Chrome. These are **private Tailnet observations**,
not a public Pages-to-physical-LAN/LNA result or a terminal product-policy decision.

The raw capture remains **inconclusive**: after the root child was reaped and the
Serve baseline restored, a port-bind cleanup check raised `OSError`. Its errno
and port were not retained, so the exact cause is unproven. The raw validator
correctly rejects this capture; it has not been rewritten into a passing result.
Session and PTY deletion/404 checks and PTY process absence were already recorded.
Independent recovery subsequently verified all known PIDs absent, no socket rows
for ports 45130/45131/8443, successful binds, unchanged local/remote Serve baselines
and no invocation processes, then removed only the guarded remote invocation root.
See `evidence/recovery-3.json`; `evidence/validation-3.json` records the separately
checked browser subset and source hashes without accepting the raw capture.
After archival and verification of the compiled hash, regenerable Dart source
and retained input fixtures, the new local invocation root was also removed;
see `evidence/local-cleanup-3.json`. Earlier captured roots were left untouched.

Twenty local Python tests and the Node controls passed before this attempt.
All eight available reviewers were consulted; the main-agent judgment required
no code correction after verifying existing sudo authority and direct-child
reaping semantics. The exceptional supervisor-death limit remains explicit.

The remaining #358 validation is deferred after this bounded attempt, as the
owner allowed. Do not repeat the capture merely to replace its cleanup result.
Public-origin/LAN evidence, the terminal policy and checkpoint acceptance remain
pending, and #270 remains gated. A separate dependency-ready next candidate is
#304 (themes/Material You), whose foundation dependency #254 is closed.
