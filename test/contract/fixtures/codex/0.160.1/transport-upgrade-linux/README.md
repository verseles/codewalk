# Codex 0.160.1: Linux HTTP-upgrade subset

This immutable native subset records HTTP WebSocket-upgrade responses on Linux aarch64 at 2026-10-05T21:11:43Z. It is partial evidence for [#245](https://github.com/verseles/codewalk/issues/245), declared before execution in [the bounded unit comment](https://github.com/verseles/codewalk/issues/245#issuecomment-6002965632).

The unit sent HTTP requests and closed immediately after the response headers. It sent zero application messages, created zero threads/turns and requested zero provider inference. It did not perform initialize/initialized, negotiate capabilities or observe model/session behavior. Subscription monetary value was not measured.

## Observed results

| Topology | Native cases | Observed HTTP statuses |
| --- | --- | --- |
| Existing daemon, direct Unix socket | Valid upgrade | 101 |
| Existing daemon, official raw stdio proxy | Valid upgrade | 101 |
| Dedicated capability-token listener | Missing, wrong, valid bearer | 401, 401, 101 |
| Dedicated capability-token listener | Valid bearer with Origin: null or https://origin.invalid | 403, 403 |
| Dedicated signed-bearer JWT listener | Missing, wrong signature, expired, future nbf, wrong issuer, wrong audience | 401 in each case |
| Dedicated signed-bearer JWT listener | Valid JWT; valid JWT with Origin | 101; 403 |

All four 101 responses had the correct Sec-WebSocket-Accept digest for the fresh request key. Each request has an observed timestamp and local index in native-http.json. These indices are capture positions, not upstream durable sequence numbers.

A third dedicated process attempted `app-server --listen ws://192.0.2.1:0` without transport auth. It exited 1 with the explicit refusal to start a nonloopback listener without authentication. The unassigned TEST-NET address exercised the source-backed guard before binding. It does not establish authenticated nonloopback acceptance, real LAN connectivity, TLS or browser behavior.

## Provenance and method

The existing daemon reported appServerVersion 0.160.1 before and after the unit. Dedicated listeners used the installed 0.160.1 managed executable; the official proxy used CLI 0.160.0. Their executable hashes are in provenance.json. The public source pin is a reference, not a claim about the installed binary's exact build commit.

The official proxy transfers raw bytes through its stdin/stdout to the Unix socket. The probe performed the same HTTP upgrade through those pipes; JSONL was not sent to the proxy.

Each dedicated child had a private fresh HOME/CODEX_HOME/TMP/XDG environment. Runtime-generated transport tokens/signing secrets were mode 0600. They authenticate the test listener, independently of ChatGPT/model login. Credentials, Authorization headers, JWTs, request keys, raw stderr and raw response headers were never exported. Private paths in retained command arguments use placeholders.

The probe used installed Python standard-library HTTP/socket/process operations without implementing WebSocket frames or installing dependencies. It bounded headers/startup text to 8192 bytes and checked the actual 101 Accept digest. Before sending credentials, it matched the dedicated child's socket inode and loopback port in /proc. That check was an orchestrator assertion; the fixture contains no raw process-descriptor dump.

For reproduction, generate new transport credentials in a new private invocation, verify executable versions/hashes, and use the argument arrays in provenance.json. Send GET / HTTP/1.1 with Host: localhost, Connection: Upgrade, Upgrade: websocket, Sec-WebSocket-Version: 13 and a new 16-byte base64 Sec-WebSocket-Key. Vary only the auth/Origin cases above. Use the declared commands and bounds in the linked issue comment. Do not reuse existing accounts, tokens, test homes or an immutable output directory.

## Validation and cleanup

All 15 statuses and four Accept checks matched the declared expectations. No native retry was needed. The recorded execution lasted 0.272 seconds within the 180-second native deadline.

The owned proxy, capability listener, JWT listener and negative guard process were reaped. Both dedicated ports refused connections afterward. The existing daemon remained running with the same reported version and control-socket inode; no unchanged-PID claim is made. The invocation runtime and test secrets were removed. See cleanup.json.

Validate retained bytes with `sha256sum --check SHA256SUMS`. All JSON must parse, contain the 15 actual observations and retain pending matrix rows as pending. No reusable capture implementation or production code is included, so implementation review/build checks do not apply to this static evidence unit.

## Acceptance limits

This subset establishes HTTP-upgrade/auth controls only. It does not establish initialized protocol framing, TUI-source discovery, live sharing/resume, approval replay or second-client resolution, text/reasoning/tools, typed questions/input, plans, steer/interrupt, children/background work, usage/quotas/errors/retries, authenticated dedicated remote TUI or disconnect/rejoin recovery. The complete matrix.json keeps these rows pending.

macOS/Windows, native Safari, trusted HTTPS to actual HTTP LAN, terminal-on-Web acceptance, G1/G2/G5 acceptance and full SP04 acceptance remain unestablished. Dedicated test listeners were separate from the existing daemon. No production adapter, Host transport implementation or publication occurred.
