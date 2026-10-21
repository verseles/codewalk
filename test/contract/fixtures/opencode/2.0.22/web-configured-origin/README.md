# Configured-origin Flutter/Chrome native evidence

**Delivered, awaiting acceptance; #247 remains partial/open.** This independent
capture ran on Linux ARM64 on 2026-10-05 with OpenCode 2.0.22, Flutter 3.44.1,
Dart 3.12.1, package:web 1.1.1 and sandboxed Chromium 154.0.8037.57. The capture
started at 15:36:53.783 UTC and was saved after cleanup at 15:36:59.797649 UTC.
It does not modify or replace the historical `../web/` evidence.

The standalone compiled Dart app performed Fetch with an Authorization header,
ReadableStream UTF-8/SSE decoding, and automatic serialized recovery from real
`document.visibilitychange` events. Node controlled browser targets through CDP
and made only admitted native info/session CRUD requests. Native inference
turns and cost were **0 / USD 0**; one disposable session was created.

## Observed controls

| Browser observation | Result |
| --- | --- |
| Allowed `http://cw-sp04-allowed.test:33389` info | Readable 200; exact ACAO |
| Same origin, invalid authentication | Readable 401; distinguishes auth from CORS |
| Allowed info/event preflights | 204, exact ACAO, `authorization` allowed |
| Allowed authenticated event stream | 200, `text/event-stream`, incremental reads |
| Denied `http://cw-sp04-denied.test:33389` info/event | Preflights 204 without ACAO; Chrome `PreflightMissingAllowOriginHeader` |

Both custom HTTP origins were mapped to loopback by browser DNS controls. The
native foreground process used `serve --hostname 127.0.0.1 --port 0 --cors`
with the exact allowed origin. This differs from a managed service configuration
or restart; it establishes browser enforcement of this configured allowlist.

The first stream observed `server.connected` on read 1 and the owned native
Unicode title rename on read 3. The server PATCH started at 1791214618640 ms;
the matching client event arrived at 1791214618698 ms. No model ran.

## Page visibility and recovery

These are client-observed epoch milliseconds, not server flush assertions:

| Milestone | Time |
| --- | --- |
| Armed page becomes hidden | 1791214618821 |
| First reader ends and releases its lock | 1791214618826 |
| Dart records completed hidden stop | 1791214618827 |
| Native hidden-gap title PATCH | 1791214618865–1791214619006 |
| Page becomes visible | 1791214619014 |
| Fresh stream connected / authoritative gap snapshot recovered | 1791214619073 / 1791214619193 |
| Later live rename arrives on fresh stream, read 3 | 1791214619263 |

CDP target activation caused actual DOM visibility events in headless Chromium.
It did not synthesize a visibility event or invoke manual recovery. An earlier
unarmed hidden event precedes the experiment; the armed reader stop above owns
the gap. The snapshot establishes recovery of the hidden title, **not replay of
the hidden rename on the fresh stream**. A later rename establishes live delivery.
Both final Dart shutdowns cleared credentials and left zero active readers.

This does not establish OS suspend, native mobile lifecycle, Safari, a trusted
HTTPS page connecting to a real HTTP LAN peer, mixed-content/LNA permissions,
in-browser service restart, terminal-on-Web policy, a production adapter or full
SP-04 acceptance. Those gates remain pending.

## Provenance and cleanup

`evidence/capture.json` preserves selected native calls, CDP fields and Dart
milestones; credentials and raw browser/native logs are not exported. The
capture SHA-256 is
`b83648a3b1cdf17302c7e347a3356a6d7133949ce12169fad62ebba7ed790542`.
`provenance.json` records versions, source/build/probe hashes, budgets and review
limitations. `SHA256SUMS` covers the retained files.

The official npm archive SHA-256 is
`49e5466de60f65001cddd7583419f842140697daead2b4d8826be54d9056e70b`;
its extracted member and executed ARM64 ELF both matched
`f27539d9c05c970d3eb9ad6a7724b75d3e638932c5423554f5ecbfe0ee2e8815`.
The registry SHA-512 was also verified. The separate official source anchor is
[OpenCode 2.0.22 server-process.ts](https://github.com/anomalyco/opencode/blob/527f0b931d1f9b3ebd34e106c51b31ce5db5b075/packages/cli/src/server-process.ts).
No exact binary build-commit equivalence is claimed.

The collector checked the owned PID/listener socket inode before authentication,
enforced the executable/archive hash chain, and ran Chromium directly inside
Snap confinement with verified private HOME/XDG/TMP roots. A bounded timeout
can be inconclusive only when no actual hidden event was observed; tooling or
reader-stop errors fail the run. Browser and cleanup child environments exclude
provider credentials. Snap platform bootstrap remains part of the installed
browser; the normal Chromium launcher/profile import and real-home init are
bypassed.

Owned session DELETE returned 204 and subsequent GET returned 404. Native PID
1398360, native port 33077, CDP port 42765, owned process groups, private native
runtime and the exact Snap invocation directory were absent after cleanup.
Main-agent checks independently confirmed PID/ports/runtime/Snap-root absence.
The host invocation, downloaded package and compiled build were removed after
retaining these sanitized bytes. No executable, archive, compiled bundle,
provider data or private runtime is retained here.

## Validation and reproduction

From this directory, validate the immutable capture without running native code:

```sh
if [ -f ~/paths ]; then source ~/paths; fi
rtk proxy timeout 30 python3 -B validate.py --self-test
rtk proxy sha256sum --check SHA256SUMS
```

The validator checks actual origins/auth/preflights, incremental owned events,
visibility/reader/gap/snapshot order, hash provenance and cleanup. Its 36 negative
controls also reject missing post-arm hidden evidence, missing or invalid page
shutdowns, absent arming, non-boolean success flags, non-integer reader counts,
divergent final observations and contradictory inconclusive recovery history.
The inconclusive positive control consistently projects every recorded allowed
state; it is an offline validator control, not a native inconclusive observation.
Both the original app layout and archived text-source layout passed.

To reproduce, first declare a new bounded invocation and verify the installed
resources. Create a private `/tmp/opencode/codewalk-sp04-*` directory; restore
`flutter_main.dart.txt` byte-for-byte to `app/lib/main.dart`, the standalone
pubspec/lock to `app/`, and `web-index.html` to `app/web/index.html`. Copy the
collector and validator there. Obtain the pinned official npm archive as
`official-2.0.22.tgz`, verify both registry hashes and safe regular-file members,
and extract `package/bin/opencode` into that invocation. Do not use a shared
service, profile or credentials. Required resources include Linux `/proc`, GNU
tar, Node with built-in WebSocket, installed Snap Chromium and cached Flutter
dependencies. Missing resources remain a stop condition.

Focused commands used, with `~/paths` sourced and Flutter PATH prepended:

```sh
node --check capture.mjs
# From app/:
export PATH="$HOME/flutter/bin:$PATH"
flutter pub get --offline
flutter analyze --no-pub
flutter build web --release --no-pub --no-web-resources-cdn
# From the owned invocation, after diagnostic review:
node capture.mjs --smoke
node capture.mjs
python3 -B validate.py --self-test
```

The declared runtime budget was 20 minutes excluding review; the collector has
a 180-second deadline, 30-second startup and bounded request/cleanup waits.
Preserve sanitized evidence, verify teardown, then remove only that invocation.
Successful native observations should not be rerun merely to add more checks.

Eight initial native reviewer reports were preserved. During recovery, eleven
replacement handshakes failed with provider usage-limit HTTP 429; four helpers
never produced initial reports. Grok completed initial review and both
re-reviews. Main accepted and fixed four evidence-backed issues, and final code
and native-evidence reviews approved without findings. This reduced reviewer
availability is recorded, not presented as full independent coverage.

After the helpers were restarted, a separate validator-only review completed
four rounds with all 12 eligible helpers. Main accepted five scoped corrections:
the armed-hidden time window, both-page shutdown evidence, the shared visible
arming prerequisite, strict shutdown scalar types, and consistent final and
inconclusive lifecycle history. The final round had 12 approvals and no new
findings. Earlier provider failures above remain historical; this new coverage
concerns the offline validator, without expanding native platform acceptance.

Formatting/transport recoveries retained the same helper sessions. An executor
interruption during round four was recovered through the same sessions after
execution was restored; all 12 sessions were closed successfully at job end.
The validator SHA-256 is
`abd9c9dbe491e548513026e4a4c532ae4a3abad4a52dc8a3453d240c81066955`.
The 36 negative controls and one synthetic positive projection passed in both
source layouts. No native capture was rerun, and its bytes remain unchanged.

No root `make check`, APK, CI, commit, push, deployment or release was run: this
unit only adds a standalone evidence fixture. Previous dirty documentation and
historical fixtures were preserved. The fixture remains local and uncommitted.
