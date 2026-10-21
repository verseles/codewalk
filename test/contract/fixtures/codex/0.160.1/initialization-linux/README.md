# Codex 0.160.1: Linux native initialization subset

Captured at 2026-10-05T23:02:41.389111+00:00. This immutable subset is partial evidence for [#245](https://github.com/verseles/codewalk/issues/245). It follows the [HTTP-upgrade subset](../transport-upgrade-linux/README.md) and was [declared before native execution](https://github.com/verseles/codewalk/issues/245#issuecomment-6004979870). Full G1, G2, G5 and SP04 acceptance remain false.

## Observed native results

| Topology | Initialization | Subsequent owned-project query |
| --- | --- | --- |
| Existing daemon, direct Unix control socket | Correlated initialize result; initialized sent | thread/list data [] |
| Existing daemon, official raw stdio proxy via private Unix bridge | Correlated initialize result; initialized sent | thread/list data [] |
| Fresh capability-token loopback listener | Authenticated WebSocket; correlated initialize result; initialized sent | thread/list data [] |
| Fresh signed-bearer JWT loopback listener | Authenticated WebSocket; correlated initialize result; initialized sent | thread/list data [] |

The four connections retained 20 sanitized native frames: initialize request/result, initialized notification and thread/list request/result for each connection. String request IDs and local positions are preserved. The query uses a newly created empty owned cwd, sourceKinds [cli, appServer], useStateDbOnly:true and limit1; no foreign rows or non-null cursors were accepted. This empty result is not proof of TUI discovery or live thread sharing.

Initialize supplied clientInfo and experimentalApi:true. The response retained platformFamily unix/platformOs linux, with codexHome/userAgent redacted; query cwd is replaced by <owned-project>. Unknown notifications, server requests and uncorrelated IDs are discarded before persistence; no server requests were answered. The received-message counts were 5,5,4,4 and dropped counts 3,3,2,2; discarded content and reasons were not exported. The client sent initialized as a notification and did not wait for an acknowledgment. Successful thread/list confirms a subsequent scoped RPC; no serverVersion or capability echo is invented.

Native execution took 2.683083 seconds plus 0.037834 seconds for cleanup, within the declared 180+30-second budget. At most 12 outbound application messages were sent. No threads, turns, provider inference or model calls were requested; expected native model spend is USD0 and subscription monetary value is unknown.

## Provenance and method

The installed managed daemon/server executable is 0.160.1; the official proxy CLI is 0.160.0. Binary and source hashes are in provenance.json. The existing daemon reported the same running 0.160.1 version before/after. The pinned public source is a reference; the installed build commit is unverified. Runtime version is established independently of initialize. The official protocol documentation is [Codex App Server](https://learn.chatgpt.com/docs/app-server); pinned implementation and installed schemas control version-specific details.

The Dart 3.12.1 diagnostic uses the built-in WebSocket client and HttpClient Unix socket connection factory. It has connect/RPC deadlines of 5 seconds and a process guard of 25 seconds. Its 32-message/8192-UTF8-byte input checks apply after SDK assembly, not before allocation. The private Python bridge forwards at most 131072 raw bytes to the official stdio proxy, has 20-second accept/forward bounds, and adds no TCP listener or JSONL framing. Private child homes/TMP/XDG directories and generated 0600 transport credentials were confined to a 0700 owned runtime. Credentials, bearer values, raw stderr, account files and raw headers were never exported. Listener process/socket ownership was verified before supplying generated credentials.

The first one-off orchestration stopped at read-only metadata preflight before any connection or listener: it expected a direct socket, while Codex intentionally advertises a symlink to a protected Unix socket. That owned runtime was removed. preflight.json preserves the failed observation and explains why its absent before-baseline comparisons do not establish daemon mutation. The revised check verified the owned alias and owned 0600 socket in an owned 0700 directory, tracked both identities before/after, and passed. No daemon, socket path, account or host configuration was modified.

## Source, offline checks and review

The four frozen diagnostic files are stored with .txt suffixes to keep them outside application/test discovery. Their bytes match the reviewed source hashes. Copy them to a new private scratch directory and remove only the final .txt suffix for diagnostic reproduction; supply fresh runtime/transport credentials and the declared command arguments. Never reuse the immutable output folder or existing secrets.

Dart analysis and nine offline controls plus five Python controls passed once after judged fixes. All 12 helpers completed initial review; the re-review dispatched all 12 and obtained 11 approvals with zero remaining findings. helperCodex-6-luna-max-3 failed twice with SESSION_CODEX_ERROR: turn failed, so it did not approve re-review. All 12 sessions were then closed. Judged fixes handle disappearing owned process groups, early EOF in the test and retaining terminal failure classes. Exact review coverage is in provenance.json; native results were observed afterward.

The focused offline command was: dart analyze initialize.dart self_test.dart; dart self_test.dart; python3 -B -m unittest -v test_proxy_bridge. Frozen source must first be copied under its original filename; use the documented Flutter/Dart PATH when necessary. These are standalone diagnostics and sanitized fixture data; application-wide make check and Android builds were not needed or run for this unit.

## Cleanup and acceptance limits

Seven directly owned processes were reaped. The bridge's separate official raw-proxy child was observed through owned parent ancestry and confirmed gone. Both dedicated ports closed, the private bridge socket disappeared, and the complete owned runtime and transport-secret files were removed. Default alias/resolved socket identities and reported daemon version were unchanged; no unchanged-PID claim is made. See cleanup.json.

Verify bytes with sha256sum --check SHA256SUMS, parse all JSON, and inspect matrix.json. It references the five earlier HTTP-only rows, advances initialize to observed-partial, and retains fifteen remaining rows as pending. The frozen earlier subset is unchanged.

Live TUI discovery/resume/sharing, approval replay and second-client resolution, text/reasoning/tools, questions/input, plans, steer/interrupt, children/background work, usage/quota, native errors/retries, remote TUI, disconnect/rejoin, authenticated nonloopback acceptance and per-OS recommendations remain pending. macOS/Windows, Safari, trusted HTTPS to actual HTTP LAN and the terminal-on-Web product decision are unestablished. No production adapter, application transport, publication, commit, push, release or deployment occurred.
