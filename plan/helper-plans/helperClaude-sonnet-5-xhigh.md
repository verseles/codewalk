# CodeWalk v2 — Independent Implementation Plan

> Basis: repository `14fbf519` (v1.265.0), research pack in `plan/` (snapshot 2026-10-02), plus targeted reads of `ADR.md`, `AGENTS.md`, `Makefile`, `pubspec.yaml`, `.github/workflows/*.yml` and `lib/presentation/services/update_check_service.dart`.
> **[V]** = checked in an inspected file or pinned source. **[U]** = inference or unverified, with a verification step. Alternatives to a user-selected baseline are labelled **ALT** and are proposals for discussion only. The baseline plan uses the user's choices unchanged.

---

## 1. Status, objective, recommendation, intended behaviour

### 1.1 Status

No hard blocker prevents the OpenCode-v2-only v2.0 path. Everything after v2.0 depends on bounded spikes (§7). Items that need a user answer or an external fact before the affected stage:

| ID | Blocker or confirmation | Affects | Resolution |
|---|---|---|---|
| B1 | Apple Developer Program account and App Store Connect API key. Without them iOS is build-only: unsigned CI builds plus 7-day dev signing on one device. | D09 iOS release | User confirms. Otherwise iOS stays a CI compile and test gate. |
| B2 | Redistribution terms of `@anthropic-ai/claude-agent-sdk` (the dossier lists the ACP adapter as proprietary; the SDK licence was not inspected). | Host packaging (D15) | Do not bundle. Install on demand from npm on the user's host. Counsel check before any bundling. |
| B3 | Whether macOS release builds are notarized and non-sandboxed. `macos/Runner/Release.entitlements` is sandboxed per `plan/00 §1.1` **[V as read by the inventory]**. | D10 managed install on macOS | Spike S3 (§7). |
| B4 | The next user-facing release after this plan must keep v1 reachable: `release.yml` publishes every `v*` tag as a non-prerelease (`release.yml` `prerelease: false`). | D04 | See §2.3. |

### 1.2 Objective

Replace the v1 OpenCode-v1 client with a clean, capability-driven client. It speaks **OpenCode v2 directly** and adds other harnesses only through a small optional **CodeWalk Host** for protocols that are stdio-only or Unix-socket-only. Intended final product:

- One **unified session list** (project × machine, harness badges). Each session has an *ownership/control level* (full, continue-only, read-only, in-use).
- A **canonical timeline** built by pure reducers from typed events. Raw provenance is kept; unknown items render generically.
- **Capability-driven UI.** Controls are hidden when never applicable and disabled with a reason when temporarily unavailable.
- **Honest delivery.** Foreground event streaming everywhere. Android gets an opt-in foreground service. Host-side notifier sinks (ntfy/UnifiedPush/webhook) arrive later. Native APNs/FCM is explicitly out of scope unless the user later approves a CodeWalk-operated relay.

### 1.3 Architectural recommendation (answers D01, D02, D07, D15)

**Direct-first, hybrid by necessity.**

1. **OpenCode v2 always connects directly** to the official shared service (`/api/*`, Basic or pairing token). No wrapper in the data path.
2. **CodeWalk Host (`codewalk-host`)** is an optional per-machine process. It owns processes and sockets for harnesses without a network-capable shared server:
   - Codex shared daemon: a UDS bridge.
   - Claude Agent SDK: host process.
   - Pi RPC, Muse MSP, ACP stdio agents (dsh, long tail).
   - Grok `agent serve` as an ACP client, optional.
3. The host also provides **gap services** only where a harness lacks them: file list/read/write/search, git status/diff, PTY, notifier sinks, install/update assist. Each service is a capability flag.
4. The host emits a **CodeWalk Host Protocol (CHP)**: canonical events plus raw provenance, a bounded live ring for gap bridging, and idempotent command receipts. **Durable history stays in each harness's own store.** The host is not a database of record.
5. The app's Dart domain package defines the canonical model. Two mappers feed it: the OpenCode v2 mapper (direct) and the CHP client mapper (near-identity).
6. **Language for the host: TypeScript on Node 22** (Bun optional). Ship it as an npm package and, for the desktop bundle, as a compiled single binary if spike S5 passes. Dart AOT is the fallback. Go is justified only if S5 shows the Node packaging path is unworkable.

**Rollout (D02).** Stage names do not imply semver; see §7 for acceptance gates.

| Release | Content |
|---|---|
| v2.0 | OpenCode v2 foundation on Android, Linux, macOS, Windows, Web. iOS builds from the first skeleton stage; TestFlight when B1 is resolved. |
| v2.1 | CodeWalk Host, CHP and Codex. Codex uses the shared daemon and yields the first notifier. |
| v2.2 | Claude through the Agent SDK. |
| v2.3 | Muse and Pi. |
| v2.4 | Grok and the generic ACP adapter. `dsh` is an experimental registry entry, not a named deliverable. |

**ALT-D02:** Claude before Codex (user-base argument). Cost: the host must ship gap services (file/search/git/PTY) before it can show value. Codex first exercises transport, auth and notifier with mostly pass-through semantics, because Codex already has `fs/*`, `fuzzyFileSearch`, `command/exec` PTY, rate limits and subagents.

### 1.4 Why not the alternatives (consequential, labelled for discussion)

| ALT | Description | Benefit | Cost | Verdict |
|---|---|---|---|---|
| ALT-D01-U | Universal daemon fronting every harness including OpenCode | One protocol, one replay log, one notifier, TLS and CORS and mixed-content story for Web, delta coalescing for mobile data (OpenChamber measured 3,402 deltas → 483 frames, `plan/31 §2.2`) | Must mirror OpenCode semantics (inbox, forms, saved-permission rules, revert) or lose them. Duplicates OpenCode's durable log. Host install becomes mandatory for the simplest scenario. Re-couples to upstream churn (OpenAPI `0.0.1`, experimental). | Reject for v2.0. Keep an optional **OpenCode relay mode** in the host as a gated fallback (gate G-BW, §7). |
| ALT-D01-D | Direct only: OpenCode HTTP, Grok `serve` WS, Codex `--listen ws://` | No host | Codex `--listen ws://` is a separate process that does **not** share the daemon's live threads **[V `plan/20 §4.1`]**. This breaks D13 for Codex. Claude, Pi, Muse and dsh are stdio only. | Reject. |
| ALT-D01-SSH | In-app SSH plus `codex app-server proxy` | No open port, no token management | dartssh2 dependency, no Web, no iOS parity, key management UX | Defer. Document `ssh -L` as user-managed (D08). |

---

## 2. Decision Assessment D01–D16

### 2.1 Summary table

Confidence: H = high, M = medium, L = low. "Verify" lists the step that resolves unknowns.

| ID | Baseline | Verdict | Evidence and argument | Alternative and tradeoffs | Conf. | Verify |
|---|---|---|---|---|---|---|
| D01 | open | **Recommend hybrid** (§1.3) | The OpenCode shared service is already the daemon with durable events and an experimental log **[V `plan/12 §1.4`]**. Codex needs the daemon UDS for shared threads **[V `plan/20 §2.4`]**. Claude, Pi and Muse are stdio only **[V `plan/21 §1`, `22 §2`, `23 §2`]**. | ALT-D01-U and ALT-D01-D (§1.4) | M-H | G-BW bandwidth gate; S6 Codex bridge |
| D02 | open | **Recommend** staged rollout (§1.3, §7) | Codex's native network surface and daemon give the cheapest host proof. Claude carries a policy gray zone. dsh is a preview with gaps **[V `plan/25`]**. | ALT-D02 (Claude first) | M | S6, S7 |
| D03 | 3A | **Keep, with branch and gate changes** | v1's god objects (22.8k and 27.5k LOC, 83% presentation, 26 files calling Dio) **[V `plan/00 §0`]** make incremental migration costlier than rewrite. Reuse leaf widgets and services. Details in §2.2. | In-place on `main` was rejected: `main` push deploys production Web (`web-pages.yml`: `wrangler pages deploy … --branch=main`). | H | none |
| D04 | 4A | **Keep with 5 mitigations (§2.3)** | The updater picks `releases/latest` and the first `.apk` asset, compares semver ignoring prerelease **[V `update_check_service.dart:14,161-200`]**. A v2 release auto-offers itself to all v1 installs, which can then no longer talk to their OpenCode v1 servers, and Android cannot downgrade without uninstall. | ALT-D04-guard: one last v1 release that warns before updating | H | Android install-over test |
| D05 | 5A | **Keep default ON; split into 3 levels; never use `always`** (§2.4) | v2 `always` persists project-wide saved rules **[V `plan/12 §7.4`]**, so v1 EXC-001's "session-scoped, doesn't survive restart" no longer holds **[V `ADR.md:1241`]**. A session `*:*:allow` ruleset overrides the plan agent's denies, `.env` and `external_directory` asks, and is inherited by children **[V `plan/12 §7.5`]**. | ALT-D05-narrow: auto-approve ordinary asks but keep prompting sensitive categories | H | S1 probe of session-ruleset precedence |
| D06 | 6A | **Keep, restrict the experimental probe (§2.5)** | Native signals exist for Codex, Claude (SDK events), Muse and Grok billing. OpenCode has none **[V `plan/10 §f`]**. v1's `node -e` and token write-back is not acceptable. Claude policy forbids collecting or intermediating claude.ai credentials **[V `plan/21 §6`]**. | Drop the probe entirely | M-H | policy re-read per release |
| D07 | open | **Recommend phased honest delivery (§2.6, §5.9)** | Foreground SSE is reliable everywhere. Android 15 limits dataSync FGS **[U]**. APNs/FCM need a CodeWalk-owned sender, which contradicts D08's spirit. | ALT: CodeWalk push relay (separate user decision) | M | S9 |
| D08 | 8A | **Keep; narrow in-app scope** | OpenCode, Codex WS and Grok serve have no TLS **[V]**. A hosted Web page cannot call plain-http LAN endpoints (mixed content) **[U]**. Keep direct URL and embedded Tailscale; SSH stays user-managed. | In-app SSH later | H | S2 |
| D09 | base+web+iOS | **Keep; define support tiers and gates** (§5.1) | No `ios/` dir exists today **[V]**. iOS is remote-only with foreground-only delivery. Web is limited by CORS and mixed content. Release builds today: linux-x64, windows-x64, macos-arm64, android-arm64 **[V `release.yml`]**. | iOS GA after TestFlight proof | H | S2, S4 |
| D10 | 10A | **Keep with 5 refinements (§2.7)** | The update API serves per-target sha256 **[V `plan/opencode-v2-docs/docs-install-script.md:614+`]**, but it comes from the same origin as the binary. v2.0.22 self-checks for updates every 10 minutes **[V commit subject]**. The shared service may already exist. | npm `@opencode/cli` path as a second verified channel | M-H | S3, S1 |
| D11 | 11A | **Keep as assisted install** (§2.8) | Several official installers are `curl\|sh` or `irm\|iex` (Claude, Muse, Grok, Pi). Silent execution from an app is a supply-chain and consent problem. Most harnesses self-update. | none | H | none |
| D12 | 12B | **Keep (process)** | English plan. App localization is a separate matter (§6.6). | none | H | none |
| D13 | 13A | **Keep as essential; define per-harness levels** (§4.9) | Only OpenCode and the Codex daemon share live sessions with a terminal client. Others give history plus continue, with lease and ownership caveats. | none | H | S1, S6, S7 |
| D14 | 14A | **Keep; add ownership and control badges** | Unified list is feasible. Listing mechanics differ (Pi and Claude need a host for list). | none | H | none |
| D15 | open | **Recommend TypeScript on Node 22** (§2.9) | Official SDKs exist in TS for Claude, Muse and Pi, plus the ACP TS SDK. Codex needs only JSON-RPC. | Dart AOT (single-language) or Go (single static binary) | M | S5 |
| D16 | 16A | **Process-only** | Scheduling must not influence technical conclusions. | none | n/a | none |

### 2.2 D03 detail (branching and gates)

The `main` branch publishes the live Web app on every push, and workflows trigger on it **[V `web-pages.yml`]**.

- Create `v1` from `main@14fbf519` or the tag `v1.265.0` before any deletion.
- Develop v2 on a long-lived `v2-dev` branch. Preview Web deployments go to `--branch=v2-dev`.
- Cut over by renaming branches: current `main` becomes `v1`, `v2-dev` becomes `main`.
- Re-baseline the gates that exist today. `make check` currently depends on an analyzer budget of 337 issues and a 35% coverage gate **[V `plan/00 §4`]**. On the rewrite set analyzer budget = 0 and a fresh coverage floor.
- Use a Dart **pub workspace** (`packages/*`). It enforces layering mechanically: the core and harness packages cannot import Flutter, and Dio is allowed only in client packages.

### 2.3 D04 consequences and mitigations

- **Fact:** `UpdateCheckService` fetches `/repos/verseles/codewalk/releases/latest`, parses `tag_name` with a `Semver` that strips prerelease and build metadata, and takes the first `.apk` asset **[V `update_check_service.dart:14,161-200`]**.
- **v1 users' fate:** every v1 install offers v2.0.0 as an update. Android upgrades in place because the app ID is unchanged. After that the app cannot use their OpenCode v1 servers. Downgrade needs uninstall, which loses local data.
- **Android versionCode:** the build code is epoch-based (`pubspec.yaml: 1.265.0+1790827338`). A later v1 maintenance build therefore has a *higher* versionCode than v2.0.0 and installs silently over v2. That is a free rollback path, but v1 hotfix releases can also become `latest`.

Mitigations, all compatible with the baseline except the optional guard:

1. v1-branch release workflow must set `make_latest: false` (and v2 tags `prerelease: true` until GA). The v2 updater ignores releases with major ≠ 2.
2. v2 updater implements true semver ordering including prerelease. v1's comparison treats `2.0.0-beta.1` as equal to `2.0.0`, so beta users would never be offered the final.
3. Non-destructive migration (§6.3): v2 uses a new key namespace, imports a subset, and never deletes v1 keys for at least two releases. A v1 downgrade then keeps working.
4. Legacy Web: deploy the v1 Web build to a stable alias (for example `v1.codewalk.<domain>` via `--branch=v1`) before replacing production Web. Otherwise Web users with v1 servers break immediately.
5. Pre-release testing: a beta flavor with `applicationIdSuffix ".next"` allows side-by-side install. GA flips to the real ID. This does not change D04.

**ALT-D04-guard (proposal, not baseline):** one last v1 release (v1.266.x) that checks the update target and shows "v2 requires OpenCode v2, here is the legacy download" before offering it. Benefit: fewer stranded users. Cost: one more v1 release before v2.0. The user declined the guard previously; this plan lists it for explicit re-discussion.

### 2.4 D05 detail: approval and sandbox semantics per harness

User preference: allow-all ON by default, global and per-session controls. The exact semantics differ per harness. Approval policy and sandbox are separate dimensions and must never be toggled together implicitly.

Define **three levels** in the app policy engine:

- **L1 Ask**: show every request.
- **L2 Approve requests (default ON)**: answer ordinary approval requests with the narrowest allow option; never persistent.
- **L3 Unrestricted**: harness-native bypass, explicit opt-in, with warnings.

Exclusions at L2 by default: questions and forms, plan-exit approvals, MCP `requires_user_interaction`, and "sensitive escalations" (§2.4.1). An explicit "also approve sensitive escalations" toggle exists. This narrowing is **ALT-D05-narrow** and is flagged for user discussion.

| Harness | L2 mapping (default) | L3 mapping | Notes and pitfalls |
|---|---|---|---|
| OpenCode v2 | On every `permission.asked`, immediately `POST …/permission/{id}/reply {decision:"once"}`, as the official TUI/web do **[V `plan/12 §7.5`]**. Explicit `deny` rules never produce asks, so they still apply. Works only while a client is connected. | `PATCH /api/session/{id} {permissions:[{action:"*",resource:"*",effect:"allow"}]}`. Per-session server-side, works unattended, **overrides agent denies** including `plan`, `.env` reads and `external_directory`, and is inherited by subagent children. | Never reply `always` for auto-approve. In v2 it persists `PermissionSaved` rows project-wide for **all sessions** until deleted **[V `plan/12 §7.4`]**. EXC-001 must be superseded. UI copy for L3: "Bypasses agent restrictions such as the Plan agent". |
| Codex | Keep the user's configured sandbox (default `workspace-write`). Auto-answer command and fileChange approvals with `accept`. Do **not** use `acceptForSession` or execpolicy-amendment answers (persisted rules). | `approvalPolicy:"never"` plus `sandbox:"danger-full-access"` (CLI `--dangerously-bypass-approvals-and-sandbox`). | Check `configRequirements/read` for admin constraints. Wire enums differ from the docs (`on-request`, `workspace-write`, camelCase `sandboxPolicy`) **[V `plan/20 §3.3`]**. Network approvals (`networkApprovalContext`) and `item/permissions/requestApproval` are sensitive. |
| Claude | Host answers `can_use_tool` allow without `updatedPermissions` (no persistent rules). Use `permissionMode:"default"` or `acceptEdits`, passed explicitly because SDK ≥0.3.286 no longer forces `default`. | `bypassPermissions` (needs `allowDangerouslySkipPermissions`; refuses as root outside a sandbox; some actions are never auto-approved). | Never auto-answer `AskUserQuestion` or `ExitPlanMode`. `canUseTool` does not fire for auto-approved tools. Respect `suppress_always_allow_rule` and `requires_user_interaction`. |
| Pi | n/a. No permission system by design **[V `plan/22 §3.5`]**. | n/a | Show a read-only badge "No approvals by design". A CodeWalk Pi extension that gates `tool_call` via `extension_ui_request` is a later optional add-on. |
| Muse | Choose the narrowest `availableChoices` with scope `once`. | `session/setApprovalMode {mode:"allowAll"}` (policy may forbid). | The sandbox is separate (`--disable-approval` keeps the sandbox; `--yolo` removes it). Whether `allowAll` keeps the sandbox is **[U]**; verify in S8. |
| Grok | Answer `session/request_permission` with `allow_once`. | `session/set_mode` bypassPermissions, `_meta.yoloMode`, or `x.ai/yolo_mode_changed`. | `deny` rules and hooks still apply. Admins can lock it off. Sandbox profiles are separate. |
| dsh | Answer the only options (`allow once` or `reject`). | Not exposed over ACP **[V `plan/25 §4`]**. | Capability hidden. |

#### 2.4.1 Sensitive escalation categories (default: still prompt)

Defined per harness from the reason fields the harness already reports:

- OpenCode: action `external_directory`; `read` on `*.env*`.
- Codex: network approval contexts; `additionalPermissions`.
- Claude: `decision_reason_type ∈ {safetyCheck, sandboxOverride, workingDir}`; `blocked_path`.
- Muse and Grok: network or unixSocket subjects, and protected writes (`protectedWrite:true`).

### 2.5 D06 detail: quota and usage

- **Separate** per-session *usage* (tokens, cost, context) from account *quota* windows.
- **Native sources:**

| Source | Signal |
|---|---|
| Codex | `account/rateLimits/read` and sparse `account/rateLimits/updated` |
| Claude | SDK `rate_limit_event`; experimental `usage_EXPERIMENTAL…` (SDK call, no token handling by CodeWalk) |
| Muse | `usage/read` and `usage/changed` |
| Grok | `x.ai/billing` (shape **[U]**) |
| OpenCode | tokens and cost per session and step; model `limit`; errors typed `provider.quota` and `provider.rate-limit` with body in `error.response.body`; no remaining-quota API **[V `plan/10 §f`]** |

- **Experimental vendor probe (opt-in) rules:**
  1. Executes **host-side** only, never from the phone.
  2. Never refreshes or writes tokens. v1 wrote refreshed tokens back to host files **[V `plan/00 §2.10`]**.
  3. Never ships credentials to the phone. `GET /api/credential` returns secret values to any authenticated client **[V `plan/11 §1.7`]**, so the app must never call it.
  4. Per-provider allowlist with a consent screen and TTL ≥20 minutes while the quota panel is visible.
  5. **No Claude OAuth endpoint probe.** The legal text prohibits collecting or intermediating claude.ai credentials **[V `plan/21 §6`]**. Claude quota comes from SDK events only.
- Merge sparse updates **by window id**. t3code #12170 mis-merged Claude's one-window-per-event updates **[V `plan/31 §18`]**.

### 2.6 D07 detail: notification and background delivery

Evaluated mechanisms:

1. **Foreground SSE or WS** per endpoint: reliable on all platforms.
2. **Android foreground service** (opt-in) keeps the same single SSE connection alive. v1 had three overlapping detectors **[V `plan/00 §3 #23`]**. v2 keeps one. Android 15 restricts `dataSync` FGS runtime **[U]**; verify in S9 and handle the timeout callback by restarting or degrading.
3. **WorkManager sparse poll** (≥15 min): `GET /api/session/active` plus per-known-location permission and form lists. This is a "check occasionally" fallback, not a completion-detection promise.
4. **Host notifier** (v2.1+): the host observes OpenCode's `/api/event` and harness events and sends minimal-payload messages to **user-chosen sinks** (ntfy / UnifiedPush / webhook). No CodeWalk server. For OpenCode users this is a *watch-only observer adapter*, not a proxy.
5. **iOS:** foreground only, plus the ntfy iOS app as the notification surface with a deep link `codewalk://s/<host>/<session>`. The CodeWalk iOS app itself cannot receive APNs without a sender holding the team's APNs key.
6. **APNs and FCM** need a CodeWalk-operated sender. This stays **out of scope** unless the user later approves a relay (D07b).

Payload policy for sinks: no assistant content by default. Show the session title only if the user opts in. Happy's push titles leaked plaintext **[V `plan/31 §17 #7`]**.

### 2.7 D10 detail: official binary, sha256, `opencode service`

Refinements:

1. **Adopt before install.** If `~/.local/state/opencode/service.json` shows a live service with a compatible version, reuse it (`{id, version, url, pid, password}` **[V `plan/13 §1`]**). Do not stop or replace a service the user started.
2. **Install into a private directory** (`~/.codewalk/opencode/<version>/`), not `~/.opencode/bin`. The official curl installer overwrites the v1 binary in `~/.opencode/bin` **[V `plan/10 §a`]**. Never touch the user's existing install.
3. **Checksum source.** sha256 is served by `https://opencode.ai/update/api/latest/cli` (undocumented endpoint, same trust root as the binary). It detects corruption, not origin compromise. Also fetch the matching `@opencode/cli-<target>` npm tarball metadata, which carries an integrity digest. Offer an npm channel (`npm i -g @opencode/cli@<pinned>`) when Node exists.
4. **Pin a tested window.** For example `min 2.0.20`, `tested 2.0.21–2.0.22`. Newer versions show an "untested version" banner. The API is explicitly experimental (OpenAPI `0.0.1`) **[V `plan/10 §Executive summary 6`]**, with near-daily releases. Do not auto-upgrade past the tested window.
5. **Reconfiguring the service restarts it.** To expose it to Android the app must run `opencode service set hostname <addr>`, `set cors <origin>` and restart. Running turns are interrupted; the managed service resumes them (`session.execution.interrupted {reason:"shutdown"}`, up to 10 attempts **[V `plan/12 §5`]**). Warn first.
6. **macOS:** managed install needs a non-sandboxed, notarized build. The current release is sandboxed **[V inventory]**. See S3.
7. **Port 49374** may conflict; detect via `service.json` and the probe instead of assuming.
8. Windows: use the Windows zip. `windows-arm64` exists on npm and in the zip list but is rejected by the curl script **[V `plan/10 §a`]**.

### 2.8 D11 detail

- "Install through official channels" becomes **assisted install**: show the exact official command and source URL, run it only after explicit confirmation in a visible console panel, capture the output.
- Per-harness native updaters (Claude native installer auto-updates, Codex daemon self-updates, `grok update`) stay in charge. CodeWalk only reads versions and shows compatibility banners.
- Android and iOS: connect only. Web: connect only. Setup instructions are shown with copyable commands and a pairing QR for the desktop or host.

### 2.9 D15 detail: host language and runtime

| Criterion | TypeScript on Node 22 | Dart AOT | Go | Rust |
|---|---|---|---|---|
| Official SDKs for the harnesses | Claude Agent SDK TS **[V]**, `@muse-code/sdk` (Node ≥20, zero deps) **[V]**, Pi `RpcClient` and SDK **[V]**, `@agentclientprotocol/sdk` **[V]** | none; would re-implement all | `coder/acp-go-sdk`; the rest re-implemented | Codex crates, ACP Rust SDK; the rest re-implemented |
| Codex | hand-written JSON-RPC with generated types | same | same (structs from JSON Schema) | native crate use is possible **[U]** |
| Claude | official, lock-stepped SDK | raw stream-json (third parties already do it **[V `plan/21 #98713`]**) | raw stream-json | raw stream-json |
| Shared code with the app | JSON-schema plus golden fixtures | **full** model and reducer reuse | none | none |
| Single-file distribution | Node SEA or Bun compile **[U]**, or npm | `dart compile exe`, cross-compile for Linux only, CI matrix for macOS and Windows | trivial | easy |
| PTY | `node-pty` native addon (prebuilds needed) | FFI only **[U]** | `creack/pty` | `portable-pty` |
| Idle memory | ~50–80 MB | ~20–30 MB **[U]** | ~10–20 MB | ~10 MB |
| Update path via official channels (matches D11 pattern) | npm | none | none | none |

**Recommendation: TypeScript on Node 22.** The deciding factor is not language preference. It is that the best official client for the richest harness (Claude) and for Muse and Pi are TS libraries, and that the host can be fixed and re-released through npm without an App Store review cycle.

Honest costs:

- The CHP schema must be defined once (JSON Schema) and mirrored by hand in Dart models, kept honest by shared golden fixtures.
- Single-file packaging is **[U]**: the Claude SDK locates its native CLI via optionalDependencies, so a compiled host should use `pathToClaudeCodeExecutable` pointing at the user's `claude`.
- `node-pty` prebuilds per target.

**ALT-D15-Dart:** keep one language. Wins on model and reducer reuse and on hiring and tooling continuity. Loses the SDKs and npm distribution.

**Kill switch (spike S5, decide before the v2.1 start):** if S5 cannot produce a ≤150 MB single binary for five targets with working PTY, ship npm-only with "requires Node 22". If PTY or packaging fails everywhere, fall back to Dart AOT for the host.

### 2.10 Changes recommended for reconsideration (summary)

| # | Reconsider | Concrete effect |
|---|---|---|
| 1 | D05 semantics (3 levels, no `always`, sensitive exclusions) | Default ON is kept. Auto-approve no longer writes project-wide permanent rules. Plan-agent restrictions are preserved unless L3 is chosen. |
| 2 | D04 add-ons (§2.3): `make_latest: false` for v1, full-semver updater, legacy Web alias, beta suffix; optionally the ALT-D04-guard release | Prevents v1 stranding and hotfix-becomes-latest regressions. |
| 3 | D13 acceptance wording | "Essential" is satisfiable only as defined in §4.9. Live attach to a running terminal session exists only for OpenCode and the Codex daemon, and conditionally for Grok `serve`. Claude, Pi, Muse and dsh give history plus continue. |
| 4 | D09 | iOS GA gated on B1, Web limited to HTTPS endpoints or localhost, no embedded Tailscale on iOS in v2.0. |
| 5 | D06 | Experimental probe is host-side, never refreshes tokens, excludes Claude OAuth. |
| 6 | D10 | Adopt existing service, private install directory, pinned tested window. |
| 7 | D11 | Assisted rather than silent installs. |
| 8 | D07 | No native APNs/FCM in this direction. |

---

## 3. Capability matrix (seven harnesses)

Legend: **N** native official surface · **B** host-provided (CodeWalk Host fills the gap) · **E** vendor extension, community adapter, or extension-only · **X** experimental flag · **P** partial or caveat · **—** unsupported.

Pins: OpenCode tag `v2.0.21` (`8a8bd622`, npm 2.0.22 `05018b88`), minimum gate 2.0.20; Codex `rust-v0.160.0` (local CLI 0.159.3, daemon 0.160.0); Claude SDK 0.3.287 with CLI 2.1.287; Pi 1.0.0; Muse 1.4.2 (MSP v1); Grok 1.0.46 (ACP registry pins 1.0.47); dsh 0.2.0-rc.2; ACP schema v1 (`schema-v1.24.1`); v2 is draft.

| Area | OpenCode v2 | Codex | Claude Code | Pi | Muse Code | Grok Build | dsh |
|---|---|---|---|---|---|---|---|
| Surface | HTTP+SSE `/api/*` | app-server v2 JSON-RPC (daemon UDS, `ws`, stdio) | Agent SDK TS / stream-json | RPC JSONL | MSP v1 over `muse serve` stdio | ACP v1 + `x.ai/*` (stdio, `agent serve` WS) | ACP v1 stdio, thin |
| Network-reachable without host | N (Basic/pair token, no TLS) | P (`--listen ws://` is a separate process; UDS needs SSH or bridge) | — | — | — | N (`serve` WS + secret, no TLS) | — |
| Session list | N cursor, all projects | N `thread/list` + `thread/loaded/list` | N SDK `listSessions` (disk, host) | B (not in RPC; read session dir) | N `session/list` | N `session/list`, `x.ai/sessions/list` | N roots only |
| External/terminal sessions (D13) | N live, shared service | N live via daemon; history if standalone | P history + continue; no live | P history + continue | P read always; continue if writer lease free | P live only if both use `serve`/`--leader`; else history | P resume, no replay |
| History on open | N cursor pages | N `thread/turns/list` | N `getSessionMessages` | N `get_messages`/`get_entries` | N cursor + `view/page` | N `session/load` replays | — |
| Live catch-up after drop | P volatile SSE; exp. log; snapshot refetch | N rejoin via `thread/resume`, approvals replayed | B host ring + `reinitialize()` | N `get_entries {since}` | N `viewCursor` + gap | P persistent process + `session/load` | — |
| Text/reasoning stream | N 100 ms batches; `ended` authoritative | N | N partial messages | N | N | N | P committed chunks |
| Tools/output | N typed tool states | N items | N + `tool_use_result` | N | N | N | P generic |
| Diffs | N `session/{id}/diff`, `vcs/diff` | N `fileChange`, `turn/diff/updated` | P per-tool `structuredPatch`; repo diff B | P tool results; git B | N `patchRef` | N + `x.ai/git/*` | P |
| Approvals | N once/always/reject±message | N accept/session/decline/cancel/amend | N `can_use_tool` + suggestions | E ext `ctx.ui.confirm` | N server-minted choices | N 4 option kinds | P allow/reject once |
| Allow-all | N session ruleset override; or client `once` | N `never`+`danger-full-access` | N `bypassPermissions` | — (by absence) | N `allowAll` | N always-approve | — |
| Questions/forms | N forms (`q0…`) | X `requestUserInput` + elicitation | N AskUserQuestion, elicitation | E ext UI dialogs | N `userInput/*` | E `x.ai/ask_user_question` | — |
| Agent tasks/todos | — (removed in v2) | N `turn/plan/updated` | P TodoWrite/Task*, model-dependent | E | N `todoListChanged`, goals | N `plan` update | — |
| Subagents/background | N child sessions; bg; bug #48826 | N child threads; direct input rejected | N `task_*`, `stopTask` | — (ext; #10315) | N `subagent/*`, `task/*` | N `x.ai/subagent/*` | — |
| Steer/queue | N `delivery`, inbox edit/cancel | N `turn/steer`; queue X | N push message; `priority:"now"` | N steer/follow_up/clear | N `ifBusy`, `unqueue` | E `x.ai/interject`, queue | — one prompt at a time |
| Interrupt | N `interrupt?resume` | N `turn/interrupt` | N `interrupt()` (race #98713) | N `abort`, `clear_queue` | N interrupt+retract, cancel | N `session/cancel` | N cancel |
| Undo/redo | N stage/clear/commit (idle only); redo = clear | P fork `beforeTurnId` (new thread); no file undo; no redo | P `rewindFiles` (Write/Edit only) + fork; no redo | P fork `entryId` (new session) | P fork `cutPoint`; retract | P `x.ai/rewind` (conversation only) | — |
| Fork | N | N | N `forkSession` | N `fork`/`clone` | N `session/fork` | N `x.ai/session/fork` | — |
| Rename/archive/delete | N rename/delete; archive — | N all three | N rename/tag/delete; archive — | N rename; delete B; archive B | N rename/delete | N rename/delete | — |
| Slash commands | N `GET /api/command` (name+description) | B client-mapped | N init list + send text | P `get_commands` (ext/skills only) | P skills only | N `available_commands_update` | — |
| Skills | N `GET /api/skill`, `skills[]` | N `$name` text + `skill` item | N `/skill-name` or `Skill` tool | N `/skill:name` text | N `skill` input part | N `x.ai/skills/*` | — |
| @mentions | N `files[]` + `mention{start,end}`, `agents[]` | P path text; `mention` items for app/plugin only | P `@path` text (CLI expands) | — (RPC rejects `@file`) | N `@rel/path` in text | N `resource_link` | P `resource_link` |
| File browse/read | N list/find/read | N `fs/*`, `fuzzyFileSearch` | P `readFile`; listing B | B | B | N `x.ai/fs/*`, search | — |
| File write | X `fs/write` (experimental, unconfined) | N `fs/writeFile` | B | B | B | N `x.ai/fs/write_file` | — |
| Terminal | N PTY + ticketed WS | N `command/exec tty` (connection-scoped) | B host PTY | N `bash` (user shell) | N `session/userShell` | N `x.ai/terminal/*` | — |
| Images | N `data:`/`file:` | N data URL, `localImage` | N base64 blocks | N | N | N | P conditional |
| PDF | — (not sent to model **[V docs-attachments]**) | P [U] | P `document` block [U] | — | — | — | — |
| Model catalog | N `/api/model` + variants | N `model/list` | N `supportedModels()` | N | N | N | N config option |
| Agent/persona | N `/api/agent` | — (plan/default X) | N `supportedAgents`, `agent` | — | — | P profiles/modes | — |
| Reasoning control | N `Model.Ref.variant` | N `effort` open set | N `effort`/`thinking` | N levels `off…max` | N `none…ultra` | N `reasoning_effort` | N |
| Plan mode | N plan agent | X `collaborationMode` | N `permissionMode:"plan"` | — | — | N `x.ai/toggle_plan_mode` | — |
| Tokens/cost/context | N step/session tokens, cost, `limit` | N `tokenUsage/updated` | N `result`, `getContextUsage` | N `get_session_stats` | N `session/tokenUsage`, cost | N `usage_update`, `x.ai/session/usage` | P `usage_update` |
| Quota windows | — native (errors only) | N `account/rateLimits/*` | P `rate_limit_event`; exp. `get_usage` | — | N `usage/read` | P `x.ai/billing` [U] | — |
| Errors | N typed `{type,message,status,response.body}` | N `codexErrorInfo` camelCase | N error enums + `api_retry` | N `stopReason:"error"`, `auto_retry_*` | N JSON-RPC codes + `turn/retryScheduled` | N JSON-RPC + `stopReason` | N |
| Auth from client | N integrations/oauth connect | N device-code flow | — host-side only (policy) | — | — | P `x.ai/auth/*` | — |
| Install/update surface | brew/npm/curl/zip | npm/curl/brew | native/npm/brew/winget | npm/curl | curl | curl/npm/winget | npx/npm |
| Effort/risk, stage | low, v2.0 | medium, v2.1 (experimental API churn) | medium-high, v2.2 (policy gray) | medium, v2.3 | medium-high, v2.3 (proprietary, young) | medium, v2.4 | high (preview), experimental ACP entry |

Notes tied to the dossiers:

- OpenCode `/api/experimental/fs/write` is **not** in the README's key-facts list, which says there is no write endpoint. `plan/11 §A10` and `plan/10 §g` list it as experimental, raw body, and **not confined to the location** **[V]**. The plan uses it only with client-side path validation and a feature flag.
- OpenCode archive: `PATCH /api/session` has no archive field **[V `plan/11 §A6`]**. OpenChamber keeps a local `sessions-archive.json`, so "archive" is client-local state for OpenCode.
- OpenCode todos: no todo tool or route exists in v2 **[V `plan/12 §9`]**.
- OpenCode PDF: not included in model requests **[V docs-attachments]**. This is a regression versus v1 and must be gated by capability.
- Claude TodoWrite and Task tools are off by default on newer models unless opted in **[V `plan/21 §3.10`]**.
- Dart ACP SDK evidence conflicts. `plan/30 §1.3` lists `dart_acp_sdk` 0.1.1 (FlutterFlow) and `acp_dart` 0.5.0, while `plan/21 §8 #12` found none. This plan avoids the issue: the host (TypeScript) speaks ACP, the app does not.
- Grok `serve` endpoint path and token transport: `plan/24` records `ws://<bind>/ws` with Bearer or `?server-key=` **[V server.rs]**, while `plan/30` marks them undocumented. Treat `plan/24` as the source and confirm in S8.

---

## 4. Architecture and interfaces

### 4.1 Layout

```
codewalk/
├── pubspec.yaml                        # pub workspace root
├── packages/
│   ├── codewalk_core/                  # pure Dart: ids, domain, events, reducers, capabilities, policy engine
│   │   └── lib/src/{ids,domain,events,reduce,caps,policy,errors,usage,attention,tasks}/
│   ├── harness_opencode_v2/            # wire DTOs (~50 ops), HTTP/SSE client, wire→core mapper
│   │   └── lib/src/{wire,client,sse,mapper,detect,pairing}/
│   ├── harness_host/                   # CHP DTOs + WS client + mapper (phase 2)
│   ├── codewalk_net/                   # HttpTransport interface; Dio, Web fetch-stream, Tailscale impls; WS transport
│   ├── xterm/  tailscale/              # moved from third_party/
├── host/                               # TypeScript CodeWalk Host (phase 2+)
│   ├── protocol/chp.schema.json  fixtures/*.jsonl
│   └── src/{server,auth,ring,receipts,adapters/{codex,claude,pi,muse,grok,acp,opencode_observer},services/{files,search,git,pty,notify,usage,install}}
├── lib/                                # Flutter app
│   ├── main.dart  app/{bootstrap,di,router,shell}/
│   ├── features/{machines,onboarding,sessions,chat,composer,attention,tasks,files,terminal,usage,settings,voice,export,updater,migration}/
│   ├── platform/{android,desktop,web,ios}/
│   └── shared/{widgets,theme,markdown,l10n,utils}/
├── test/{unit,widget,contract,integration,web}  # contract fixtures live in packages/*/test/fixtures
├── tool/{contract,drift,ci,release,i18n}
└── docs/v2/                            # ADRs, CONTRACT_MATRIX-v2, ai-docs anchors
```

State management keeps `provider` with small `ChangeNotifier` controllers: `MachineRegistry`, `SessionIndexController`, `SessionController` (one per open session), `AttentionController`, `UsageController`. `get_it` is used only in the composition root. v1 had 56 `sl<>` call sites in widgets **[V `plan/00 §1.4`]**.

Add `go_router` for routing. v1 had no named routes and no deep links **[V `plan/00 §1.5`]**. v2 needs `codewalk://pair?…`, `codewalk://s/<host>/<session>` and Web URLs.

**Boundary lint (CI, `tool/ci/import_rules.dart`):**

- `codewalk_core` imports no Flutter, Dio or `dart:io`.
- `package:dio` appears only in `codewalk_net` and `harness_*` packages.
- Presentation never imports `harness_*` wire DTOs.
- No `sl<>` in widgets.

### 4.2 Identity and storage

```dart
typedef MachineId = String;                 // user-visible machine; 1..n endpoints
typedef EndpointId = String;                // base URL + auth + transport
enum HarnessId { opencode, codex, claude, pi, muse, grok, acp }   // acp carries registryId separately

final class SessionKey {                    // globally unique, stable in storage
  final EndpointId endpoint; final HarnessId harness;
  final String instanceId;                  // default "default" (future: multiple CODEX_HOMEs/accounts)
  final String nativeId;                    // ses_… / thread uuid / claude uuid / path or id / …
}
final class ProjectKey { final MachineId machine; final String canonicalDir; }
```

- A **Machine** groups endpoints on the same physical host (for example OpenCode direct plus CodeWalk Host). Automatic linking is offered when hostnames match and the user confirms. This replaces v1's `serverId::directory` (ADR-002).
- **Directory canonicalization:** keep the raw path and a normalized form. Use the harness-provided canonical value when present (OpenCode `location.directory` and `project.canonical`, Codex `cwd`, Muse `workspaceRoot`). Case-fold on Windows hosts, normalize separators, and compare normalized. Do not resolve symlinks on the client.
- **Persistence keys:** `cw2.<endpoint>.<harness>.<kind>…` in a new namespace. `LocalStore` has a `schemaVersion` key and per-feature migrators.
- **Secrets:** `flutter_secure_storage`, keyed by endpoint. Tokens are never logged. The URL-embedded token form is not used.
- Do not add SQLite in v2.0. The existing key-value plus file payload store (ADR-016 limits) is enough. Reconsider only if cache complexity grows.

### 4.3 Canonical domain and events (`codewalk_core`)

```dart
sealed class TimelineItem { String id; DateTime at; RawRef? raw; }
final class UserMessage        extends TimelineItem { String text; List<AttachmentRef> files; List<Mention> mentions; DeliveryState delivery; }
final class AssistantText      extends TimelineItem { String text; bool complete; }
final class Reasoning          extends TimelineItem { String text; bool complete; }
final class ToolCall           extends TimelineItem { ToolKind kind; String name; ToolState state; Map input; ToolOutput? output; DiffSet? diff; SubagentRef? subagent; }
final class ShellRun           extends TimelineItem { String command; ShellState state; int? exit; String? outputPreview; }
final class TaskListSnapshot   extends TimelineItem { List<TaskEntry> entries; }
final class Compaction         extends TimelineItem { CompactionState state; String? summary; }
final class Notice             extends TimelineItem { NoticeLevel level; String text; ErrorInfo? error; }
final class UnknownItem        extends TimelineItem { String wireType; String fallbackText; }

sealed class SessionEvent {                          // ordered per session
  // lifecycle
  SessionUpserted, SessionRemoved, RunStateChanged(RunState, outcome?), RetryScheduled(attempt, at, ErrorInfo),
  // content (upserts by id; deltas append)
  ItemUpserted(TimelineItem), ItemDelta(itemId, field, append), ItemsDropped(fromIdInclusive),
  // pending input
  PendingInputChanged(List<PendingInput>), // queued/steered inbox chips
  // attention
  AttentionRaised(AttentionItem), AttentionResolved(id, by: user|other|timeout|server),
  // usage
  UsageUpdated(SessionUsage),                         // tokens, cost, contextUsed/contextWindow
  // anything else
  UnknownEvent(RawRef)
}
sealed class EndpointEvent { QuotaUpdated(QuotaSnapshot), CatalogInvalidated(kind), ConnectionChanged(...) }
```

Rules:

- Items are **upserts by stable id**. Deltas only append to open items. A `complete` event replaces text with the authoritative value. This matches OpenCode's `*.ended` and Muse's item revisions.
- `RawRef {harness, wireType, protocolVersion, seq?, payload? }`. The payload is retained only in developer mode (bounded per item) or for items mapped to `UnknownItem`.
- The reducer is **pure**: `(SessionState, SessionEvent) → (SessionState, List<Effect>)`. Effects such as `RefetchMessages` and `RehydrateAttention` are executed by the controller. This makes property testing straightforward.
- `RunState` and `AttentionItem`:

```dart
enum RunState { unknown, idle, running, waitingApproval, waitingInput, retrying, interruptedPendingResume }
final class AttentionItem {
  AttentionId id; AttentionKind kind;        // approval | form | planApproval | auth | error
  SessionKey session; SessionKey root; SessionKey? originChild;
  ApprovalRequest? approval; FormRequest? form;
}
final class ApprovalRequest {
  String action; List<String> resources; List<ApprovalOption> options;     // options carry scope: once|session|persistent(projectWide)
  Sensitivity sensitivity;                   // ordinary | external | secret | network | sandbox | planExit
  String? message; ToolRef? source;
}
final class ApprovalOption { String id; String label; bool allow; Scope scope; bool acceptsFeedback; String? rulePreview; }
final class FormRequest { String id; String title; List<FormField> fields; FormOrigin origin; }  // question | elicitation | auth | custom
final class FormField  { String key; FieldType type; String? title; List<Option>? options; bool custom; bool required; List<When>? when; }
```

- **Error model:**

```dart
final class ErrorInfo {
  ErrorKind kind;          // auth | quota | rateLimit | contentFilter | network | aborted | permissionRejected | toolFailure | contextOverflow | unsupported | protocol | unknown
  bool retryable; String? userMessage; String rawType; String rawMessage; int? httpStatus; DateTime? resetsAt; ErrorAction? action;
}
```

Mapping tables:

- OpenCode: `provider.rate-limit`, `provider.quota`, `provider.auth`, `provider.content-filter`, `provider.*`, `aborted`, `permission.rejected`, `tool.*`, `compaction.*` **[V `plan/12 §6`]**.
- Codex: `codexErrorInfo` camelCase **[V `plan/20 §3.7`]**.
- Claude: `SDKAssistantMessageError` values and `system/api_retry`.
- Muse: JSON-RPC codes plus `turn/completed terminal`.
- Pi: `stopReason:"error"` plus `auto_retry_*`.
- v1's string-matching abort suppression (8 s, including the buggy "retry" match) is **deleted**. Abort is typed.

### 4.4 Adapter interfaces

```dart
abstract interface class HarnessAdapter {
  HarnessId get id; EndpointId get endpoint;
  Stream<ConnectionState> get connection;
  Future<EffectiveCapabilities> capabilities();          // claims ∧ probe evidence, refreshable
  Future<Page<SessionSummary>> listSessions(SessionQuery q);
  Stream<SessionIndexEvent> watchIndex(SessionQuery q);
  Future<SessionHandle> open(SessionKey k, {OpenMode mode});   // attach: snapshot + live stream
  Future<SessionHandle> create(NewSession spec);
  Stream<EndpointEvent> get endpointEvents;
  T? cap<T extends Capability>();                       // null ⇒ hide control
}
abstract interface class SessionHandle {
  SessionKey get key;
  Future<SessionSnapshot> snapshot();                   // authoritative page(s) + cursor
  Stream<SessionEvent> get events;
  Future<SendReceipt> send(OutgoingInput input);        // idempotent via ClientMutationId
  Future<void> interrupt({bool resume = false});
  Future<void> resolve(AttentionId id, Resolution r);
  Future<void> close();
}
```

Capability objects (optional) carry parameters:

```
Delivery{steer, queue, edit, cancel, retractSubmit}   UndoCap{scope: conversation|files|both, mechanism: stage|forkBefore|rewindFiles, redo, newSession, requiresIdle}
FilesCap{list, read, write, mutate, searchName, searchContent, watch, vcs}   TerminalCap{kind: native|hostPty}   UsageCap{tokens, cost, contextMeter: exact|estimated|none}
QuotaCap{source: native|probe}   TaskCap{todo, subagents, background, cancel}   SubagentCap{openChild, sendToChild, cancel}
CommandsCap   SkillsCap{encoding}   MentionsCap{file, agent, search}   ModelsCap   AgentsCap   ReasoningCap{kind: variant|effort|thinking}
PlanModeCap   PermissionModeCap{levels:[L1,L2,L3], sandboxSeparate}   ForkCap   ArchiveCap{native|local|none}   DeleteCap   RenameCap
AttachmentsCap{mimeTypes, perModel}   ExternalSessionsCap{liveAttach, continue, readOnlyWhileInUse}   AuthCap{loginFlow}
```

**Capability negotiation:**

- Static claims per (harness, version range), from `compat.json` on the host or `packages/*/compat.dart`.
- Runtime evidence from probes: `GET /api/info` plus a per-operation OpenAPI check for OpenCode, `initialize.userAgent` for Codex, `system/init.capabilities` for Claude, `schema.fingerprint` for Muse, ACP `initialize` capabilities.
- Effective = claims ∧ evidence. On `-32601`, `"requires experimentalApi capability"` or `unsupported`, the capability is downgraded at runtime and the diagnostic is recorded.
- Unknown enum values never fail a decode. Use open enums everywhere (ForwardCompatibleArray, as t3code does **[V `plan/31 §15.6`]**).

### 4.5 OpenCode v2 specifics (the v2.0 core)

**Transport (`harness_opencode_v2`):**

- `detect()` = `GET /api/info` only. Never infer v2 from status codes: old paths return HTML **200** because the static web app serves everything outside `/api`, `/auth`, `/openapi.json` **[V `plan/11 §1.1`]**. Handle `503 {"code":"service_starting|service_failed|service_stopping"}` with `retry-after` (not the `_tag` envelope).
- Auth: `Authorization: Basic base64("opencode:<secret>")` where the secret is the password or a pairing token. Redeem pairing with `GET /auth/connect/{code}` and `Accept: application/json`, which returns `{token}` valid 30 days **[V `plan/11 §1.2`]**. Rotating the server password revokes every token. Never put credentials in URLs on native. Web uses `fetch` streaming with the Authorization header, not `EventSource ?auth_token=`.
- Location scoping: `location[directory]` query or `x-opencode-directory`. `POST /api/session` takes `location.directory` **in the body only** and falls back to server cwd (HOME for the service) if omitted, so always send it **[V `plan/11 §A6`]**.
- **SSE reader** (own parser, UTF-8 chunk-safe; v1's per-chunk decode bug is listed in `plan/00 §6`). It runs in a dedicated isolate on IO platforms and posts batches to the UI at ≤1 per 100 ms per session. This prevents the 4,096-frame overflow disconnect when the UI janks **[V `plan/12 §1.1`]**. Idle watchdog 45 s (the heartbeat is an SSE comment every 15 s). Reconnect delay 1 s doubling to a 30 s cap visible and 60 s hidden, with jitter (OpenChamber and Paseo use these shapes **[V `plan/31`]**). Max event 16 MiB.
- **Rehydrate on every `server.connected`:**
  1. `GET /api/session/active`.
  2. For each open session: `GET /api/session/{id}`, newest message page (`order=desc&limit`), `GET …/inbox`, `GET …/permission`, `GET …/form`.
  3. For each known directory of open sessions: `GET /api/permission/request?location[directory]` and `GET /api/form`. These list endpoints are **location-scoped only**, so there is no global permission list **[V `plan/11 §A8`]**.
  4. Optionally apply `GET /api/experimental/session/{id}/log?after=<lastSeq>&follow=false` for exact catch-up of durable events. This endpoint is experimental, feature-flagged, with snapshot refetch as the fallback.
- A text or reasoning block that was mid-stream across a gap is rendered "…" until its `ended` event; deltas are not projected into history **[V `plan/12 §1.4`]**.

**Reducer** is a Dart port of the official `packages/client/src/solid/data.ts` `handleEvent` (`plan/opencode-v2-src/client-solid-data.reference-reducer.ts`), per the rules in `plan/12 §3.2`. Key behaviours:

| Event | Effect |
|---|---|
| `session.inbox.enqueued` | Pending chip; also a visible row for user and synthetic items. |
| `session.inbox.delivered` | Move the row to the end and set its time to the event time. |
| `session.inbox.cancelled` | Remove the chip and row. |
| `session.step.started` | Create assistant row `assistantMessageID`; reset in place on retry. |
| `session.text|reasoning|tool.input.{started,delta,ended}` | Append; `ended` replaces with the authoritative value. |
| `session.tool.called` / `.progress` / `.success` / `.failed` | Update tool state. |
| `session.retry.scheduled` | `RetryScheduled`; clear on next `step.started`. |
| `session.execution.started` / `succeeded|failed|interrupted` | `RunStateChanged`; unless `reason:"shutdown"`, append an idle marker. If tools were still streaming or running, refetch messages. |
| `session.revert.staged|cleared|committed` | Set or clear `Session.revert`; on commit drop rows and pending inputs with id ≥ `to`. |
| `permission.asked|replied`, `form.created|replied|cancelled` | Attention add or remove. |
| catalog `*.updated`, `mcp.*`, `credential.*`, `vcs.branch.updated` | Invalidate and refetch. |

- `session.status` and `session.idle` are declared but have no publisher in 2.0.21 **[V `plan/12 §5`]**. Do not depend on them.
- Unknown event types become `UnknownEvent`, never an exception.

**Sending (replaces v1 workaround #4 and #7):**

1. Mint `msg_<12hex>(ms*4096+counter)<14 base62 random>` client-side. The id format is documented **[V `plan/11 §1.5`]** and `prompt {id?}` is documented as the idempotency key.
2. **Evidence conflict:** Paseo states "OpenCode owns user message IDs. Do not pass Paseo-generated IDs" **[V `plan/31 §4.3`]**. The OpenAPI says `id` is client-mintable. Spike S1 decides. Fallback: omit `id`, use the synchronous `{data: Session.Inbox.User}` response, and correlate with `metadata.cw.mid` for ambiguity recovery.
3. Flow: optimistic `UserMessage(delivery: sending)` → POST with `{id?, text, files[], agents[], skills[], metadata:{cw:{mid}}, delivery, resume}` → `admitted` → `delivered` (via `inbox.delivered`).
4. **Ambiguous outcome** (timeout or disconnect after POST): retry once with the same body and id. If unresolved, look up `GET …/inbox` and `…/message/{id}` or search by `metadata.cw.mid`. If found, mark admitted. If not, mark `failed` with a user-triggered retry. **Never silently re-send with a new id.**
5. `409 ConflictError` is treated as already admitted if the lookup finds the item.
6. `delivery` default is `steer`. While running, the composer offers **Steer** (Enter) and **Queue**, shows inbox chips, and supports `PATCH` delivery change and `DELETE` cancel.

**Subagents and background tasks (OpenCode):**

- Discovery: `GET /api/session?parentID=<parent>`; `session.created` with `parentID`; tool metadata `{sessionID,status}` (ephemeral `tool.progress` only while a foreground call runs); `GET /api/session/active`; synthetic completion messages with `metadata {source:"subagent", childID, agent, state}` **[V `plan/12 §11.3`]**.
- Cancel one child: `POST /api/session/{childID}/interrupt`. Interrupting the parent cancels foreground children only; background children keep running **[inferred, `plan/12 §11.4`]**. `POST /api/session/{id}/background` moves *all* blocking tools of that session to the background; there is no per-child backgrounding.
- **Open upstream bug #48826:** nested background work can be reported complete too early **[V `plan/10 §e`]**. Rule: the `SubagentRun` state comes from the child's own execution events and `/api/session/active`. The synthetic message is a hint only. Nested runs show a "may still be working" badge until the child's own idle is observed.
- Child permissions and forms (child `sessionID`) are surfaced in the root with an origin badge, as in v1.

**Undo/redo:** `revert/stage {messageID, files?}` (409 while running), `DELETE …/revert` is redo, `revert/commit` is automatic on the next prompt. UI copy distinguishes conversation-only from files restored. Requires git snapshots **[V `plan/10 §g`]**, so the capability is hidden if the session has no snapshot support.

### 4.6 CodeWalk Host Protocol (CHP), phase 2

**Transports and auth**

- HTTPS or WSS (TLS is user-managed; self-signed plus fingerprint pin as a later option). Default bind `127.0.0.1`. Non-loopback bind prints a warning and requires explicit `--bind`.
- Pairing mirrors OpenCode's pattern: single-use code (5 min) → token (30 days), stored hashed on the host.
- Browsers cannot set WebSocket headers. Use `POST /v1/ws-ticket` (Bearer, requires a preflight header) → `?ticket=` single use, like OpenCode PTY **[V `plan/11 §A12`]**. Origin allowlist; `Host` header validation against DNS rebinding.

**Frames**

```ts
type Frame =
 | { v:1; t:"req"; id:string; method:string; params?:unknown; mid?:string }       // mid = ClientMutationId (UUIDv7) for mutations
 | { v:1; t:"res"; id:string; ok:true; result?:unknown } | { v:1; t:"res"; id:string; ok:false; error:ChpError }
 | { v:1; t:"evt"; seq:number; sess?:SessionKey; kind:string; at:number; data:unknown; raw?:RawRef }  // seq per endpoint, monotone
 | { v:1; t:"ping"|"pong" }
```

- `subscribe {afterSeq}` replays the bounded **live ring** (default 2,000 events or 8 MiB, like OpenChamber and Reemoat). If `afterSeq` is too old the server returns `replayReset:true` and the client re-snapshots.
- **Authoritative pages** (`GET /v1/sessions/{key}/timeline?after=&limit=`) return canonical items produced by the **same mapper** used for live events, from the harness's own history: Codex `thread/turns/list`, Claude `getSessionMessages`, Muse `session/read` and `view/page`, Pi `get_entries`, Grok `session/load`. The host does not store history of record.
- **Command receipts:** every mutation carries `mid`. The host keeps `CommandReceipt {mid, status: accepted|rejected|duplicate, admittedAt, ref}` for 24 h. An ack means admitted, not completed. Reconnect never replays mutations automatically (t3code principle **[V `plan/31 §15.6`]**).

**Host adapters (TypeScript)**

```ts
interface HostAdapter {
  id: HarnessId; detect(): Promise<Detected>;                 // installed? version? authed? compat level
  capabilities(session?: SessionKey): Capabilities;
  list(q: Query): Promise<Page<SessionSummary>>;
  open(k: SessionKey, mode: OpenMode): Promise<Attached>;     // returns snapshot + live Observable<CanonicalEvent>
  create(spec: NewSession): Promise<Attached>;
  send(k, input, mid): Promise<Receipt>; interrupt(k): Promise<void>; resolve(k, id, r): Promise<void>;
  setOption(k, key, value): Promise<void>;                    // model|agent|effort|permissionMode|…
  fork?(…); undo?(…); rename?(…); delete?(…);
}
```

Per-adapter essentials:

| Adapter | Essentials |
|---|---|
| Codex | Spawn `codex app-server proxy` over stdio (official; works on all OSes) **or** `ws+unix` to the daemon socket; speak WebSocket framing; `initialize` with `experimentalApi:true` only when needed; route **everything by `threadId`**; keep a pending map of server requests; dismiss on `serverRequest/resolved`; backoff on `-32001`. The daemon auto-updates, so negotiate against the **daemon's** `userAgent`, not the CLI's. Unknown notifications, item types and enums are ignored. |
| Claude | SDK `query()` in streaming-input mode, one long-lived query per session. Pass explicitly: `permissionMode`, `includePartialMessages:true`, `enableFileCheckpointing:true` with `extraArgs{'replay-user-messages':null}`, `perTaskStopAffordance:true`, `forwardSubagentText:true`, `env:{...process.env}`. `canUseTool` and `onElicitation` become CHP attention items; `reinitialize()` after a gap redelivers pending prompts. Do **not** use `--bare`. Never implement claude.ai login or forward credentials. Guard against the interrupt race (#98713): re-send interrupt after the turn's `system/init`. |
| Pi | Process per session (`pi --mode rpc --approve|--no-approve`), strict LF-delimited JSONL, split on `0x0A` only, read stdout continuously (backpressure stalls Pi). Wait for `agent_settled`, not `agent_end`. Session listing is host-provided by reading the session dir or `SessionManager.list`. |
| Muse | `@muse-code/sdk` or raw MSP. Every mutation carries `commandId` (UUIDv7). Use the `schema.fingerprint` drift check. Handle `sessionInUse` (-32021) as `controlLevel: readOnlyWhileInUse`. |
| Grok | ACP client to `grok agent stdio`, or to a user-started `agent serve --leader` for shared live state. Implement `session/request_permission`, `x.ai/ask_user_question` and `x.ai/interject`. |
| ACP generic | `@agentclientprotocol/sdk` over stdio, driven by the ACP registry. `dsh` enters here, marked experimental with capability flags reflecting the missing features (no replay on resume, no commands, plans or terminals). |
| OpenCode observer | Watch-only. Subscribes to `/api/event` and `/api/session/active`, evaluates attention rules and drives the notifier. It is not in the data path. |

**Gap services (all capability-gated, workspace-root allowlisted):**

- Files: list/read/write/search/watch with ripgrep if available, else a bounded walk honouring ignore files. Reject symlink escapes and enforce size caps. Windows path handling is explicit.
- Git: status and diff (bounded).
- PTY: `node-pty`, with snapshot-plus-cursor attach.
- Notifier sinks.
- Usage probe (opt-in, §2.5).
- Install assist (§2.8).

**Host lifecycle:** single-instance lock; user-level service registration (`systemd --user`, launchd agent, Windows scheduled task) by `codewalk-host install-service`; lazily spawned harness processes; idle reaping; pid files and orphan cleanup on start; graceful stop sends `interrupt` first (Claude SIGTERM leaves turns unfinished **[V `plan/21 §3.5`]**); resource caps for concurrent processes; log redaction.

**Version drift:** `host/compat.json` `{harness: {min, tested, knownGoodMax}}`. Banner levels: unsupported (<min), untested (>tested), ok. A nightly `tool/drift` job runs against the latest versions with fixtures, diffs OpenCode's `/openapi.json` for **used operations only**, diffs Codex `generate-json-schema` output, and opens an issue.

### 4.7 State machines

**Connection (per endpoint):** `idle → connecting → handshaking → resyncing → live → degraded (no bytes >45 s) → reconnecting(backoff) → failed{auth|incompatible|unreachable|starting}`. The foreground probe times out at 3 s (Paseo). On app resume, probe immediately instead of trusting the old socket **[V `plan/31 §4.4`]**.

**Run state per session:** see `RunState` above. For OpenCode:

- `Running` from `session.execution.started` or `/api/session/active`.
- `Idle` from `execution.succeeded|failed|interrupted`. `shutdown` maps to `interruptedPendingResume`, not idle.
- `waiting*` is derived from pending permission and form lists.
- Reconcile with `/api/session/active` after every reconnect. The server is authoritative.

**Mutation (outgoing):** `drafted → sending → admitted → delivered | cancelled | failed(retryable) | unknown(reconciling)`.

### 4.8 Ordering, reconciliation, multi-client conflicts

- Per-session reducers key by id and ordinal. Tool and text ordering is guaranteed per stream, not across streams **[V `plan/12 §4`]**.
- Pending permission or form: the **first reply wins**. Others get `AttentionResolved(by: other)` and the card disappears. A late reply gets 404 or 409, which is treated as already resolved.
- Concurrent sends: both are admitted (steer or queue); the inbox chips show both.
- `revert/stage` while another client is running returns 409 `SessionBusyError`, shown as "Another client is running this session".
- Permission reject semantics, shown in the UI copy: *reject without message ends the step and rejects all other pending requests of that session*; *reject with a message lets the model continue* **[V `plan/12 §7.4`]**. Form cancel is the same: without a message it ends the step. The default button is **"Decline with note"**. A secondary **"Dismiss and stop"** exists.

### 4.9 External sessions (D13) — per-harness contract

| Harness | Discover | Read history | Continue | Live attach to a running terminal session | Ownership and concurrency |
|---|---|---|---|---|---|
| OpenCode | `GET /api/session` (all projects) | pages | yes, native | **yes**, when the TUI uses the shared service (default). `--standalone`, `opencode acp` and private `serve` processes are invisible [U] | Server arbitrates; first approver wins; both prompts admitted. Migrated v1 sessions may be hidden (#51176 **[V]**). |
| Codex | `thread/list` (default sourceKinds cli+vscode; pass others explicitly) | `thread/turns/list` | `thread/resume` | **yes** via daemon: auto-subscribed events; `thread/loaded/list` shows running; pending approvals replayed on rejoin | Steer from either client. A `--no-daemon` TUI is a separate process; two processes writing one rollout is a risk [U]. |
| Claude | SDK `listSessions` (disk; SDK-created sessions are hidden from the terminal `/resume` unless `includeProgrammatic`) | `getSessionMessages` | `resume` | **no** (a hooks plus JSONL-tail observer mode is a later experiment) | No writer lock info; concurrent TUI and SDK on one transcript is risky [U]. Show "may be open in a terminal". |
| Pi | host reads session dir | `get_entries` / `get_messages` | `switch_session` | no | JSONL tree; conflicts [U] |
| Muse | `session/list` (read-only, no lease) | `session/read` (no lease) | `session/resume` takes the **writer lease** | no | `sessionInUse` → `readOnlyWhileInUse` until released |
| Grok | `session/list`, `x.ai/session/*` | `session/load` replay | `session/load` / `resume` | only if both clients use the same `serve` or `--leader` | persistent process; standalone TUI sessions are history only |
| dsh | `session/list` roots only | **none** (no replay) | `session/resume` | no | `session/close` quiesces |

UI contract: `SessionSummary.ownership ∈ {shared, hostSpawned, external}` and `control ∈ {full, continueOnly, readOnly, inUse}`. Copy: "Resume" (not "Attach") whenever live attach is not supported.

### 4.10 Quota, tokens, context

- `SessionUsage {tokens{input,output,reasoning,cacheRead,cacheWrite,total}, cost?, contextUsed?, contextWindow?, meter: exact|estimated|none}`.
- OpenCode context percent uses the model `limit.context` and the **last step's** total tokens (sum of the five fields **[V `plan/12 §10`]**). v1 had two inconsistent "total token" definitions and summed only resident messages **[V `plan/00 §2.5`]**; v2 uses server-provided running totals via `session.usage.updated` and `Session.Info`.
- `QuotaSnapshot {windows: Map<id, Window{label, usedPercent, resetsAt, windowMins}>, planLabel?, source}` merged by id, with `sparse` merges.
- Quota **never** blocks sending. It informs.

### 4.11 Bounded polling (the only polling in the app)

| Purpose | Cadence | Stop condition | Cost |
|---|---|---|---|
| Non-active endpoint health (`/api/info`) | 60 s while foreground | background | ≤1 req/min/endpoint |
| Permission and form catch-up per known location | on connect and on resume only | n/a | ≤N location calls per resume |
| Claude and Pi session index | `fs.watch` in host; fallback 15 s while the list is visible | list hidden | one directory scan |
| Android background fallback | WorkManager ≥15 min | FGS active | ≤2 requests/endpoint/run |
| Vendor quota probe (opt-in) | ≥20 min TTL while panel visible | panel hidden | per provider |
| Reconnect backoff | 1→30 s (60 s hidden) with jitter | connected | n/a |

v1's busy heuristics, 2 s status polling, completion polling and message refetch per delta are deleted.

---

## 5. UX and behaviour

### 5.1 Platform support tiers (D09)

| Capability | Android | Linux/macOS/Windows | Web | iOS |
|---|---|---|---|---|
| Connect (direct URL, pairing) | yes | yes | yes, HTTPS or localhost only (mixed content, CORS, Private Network Access) **[U, S2]** | yes; ATS and Local Network permission to verify **[U, S4]** |
| Managed local OpenCode | no (not supported by OpenCode **[V]**) | yes (macOS needs a non-sandboxed build **[U, S3]**) | no | no |
| Embedded Tailscale | yes (existing) | Linux/macOS yes, Windows no (existing) | no | deferred (Go c-archive build **[U]**); system Tailscale app works with plain IP |
| PTY terminal | yes | yes | feasible in v2 (ticketed WS) **[V ticket flow]**; verify CORS | yes |
| Foreground events | yes | yes | yes | yes |
| Background delivery | opt-in FGS; WorkManager fallback | tray, process stays alive | none (tab only) | none; ntfy app surface |
| Voice STT/TTS | existing engines | existing (Windows STT per ADR-044) | native Web speech only | speech_to_text; sherpa on iOS **[U]** |
| Self-update | APK via installer | install.sh/ps1 | n/a | store or TestFlight |
| CI gate | `flutter build apk` (CI runner only; ARM64 hosts are unreliable **[V AGENTS.md]**) | `flutter build linux|macos|windows` | `make test-web` plus build | `flutter build ios --no-codesign` on a macOS runner from stage 1; signed upload gated on B1 |

### 5.2 Onboarding, pairing, install, update

- Chooser: **Connect OpenCode** (URL, paste link or scan QR) · **Set up on this computer** (desktop only) · **Add Codex/Claude/… host** (v2.1+) · **Show setup steps**.
- **Pairing:** deep link `codewalk://pair?u=<url>&c=<code>`; `GET /auth/connect/{code}` redeems the token; store in secure storage. The desktop app can display a QR from `POST /api/pair` with the externally reachable URL (`opencode pair --url` equivalent). The code is single-use and expires in 5 minutes **[V]**.
- **Managed local install (desktop):** adopt-or-install as in §2.7. Steps: detect service → check version window → download to a private directory → verify sha256 → `opencode service start` → read `service.json` → pair locally. The result is an endpoint "This computer".
- **Version gate states:** unsupported (<2.0.20, or a v1 server detected via JSON `/global/health`), untested (> tested), ok. v1 servers get an actionable screen with upgrade steps and a legacy-download link.
- **Updater:** full semver incl. prerelease; channel setting stable/beta; ignores major ≠ 2; shows What's-new from the existing `CHANGELOG.md` parser.

### 5.3 Unified sessions

- List grouped by project (machine + canonical directory), children nested, with harness badges and ownership chips (see §4.9). Filters: Active / Archived (local for OpenCode) / All; sort recent / title; search.
- **Creation:** choose harness (disabled with reason if not installed or authenticated), directory, optional model, agent, reasoning level. Lazy creation on first send is preserved. For OpenCode it posts `POST /api/session` with `location.directory`.
- Unread state for OpenCode uses server-side `time.viewed < time.idle` and `POST /api/session/{id}/view` instead of local-only read state.
- Tabs, pins and recent sessions are kept (rewritten smaller).

### 5.4 Chat, composer, mid-turn

- Timeline renders canonical items. Unknown items show a generic row (kind, status, fallback text). Reasoning is collapsible. Tool cards use `ToolKind` (shell/read/edit/search/fetch/mcp/subagent/other) rather than OpenCode tool-name switches. Keep markdown, LaTeX and Mermaid renderers, scroll ownership (ADR-028/037/041), and the settled-work disclosure (ADR-025).
- **Composer** states: idle → *Send*; running → split **Steer** / **Queue** (if the capability exists), inbox chips with cancel and mode toggle, **Interrupt**. For harnesses with one prompt at a time (dsh), the Send control becomes "Interrupt and send". Draft per session persists. `!` shell mode calls `POST /api/session/{id}/shell {id?, command}` (no agent field).
- **Model, agent, reasoning** chips come from `ModelsCap`, `AgentsCap`, `ReasoningCap` (labels "variant", "effort" or "thinking" per harness). Selection applies to the session (OpenCode: `POST …/agent`, `POST …/model`), and mid-turn effects are described per harness (Claude `setModel` applies from the next API call).
- **Commands and skills** share one palette opened by `/`. Entries carry origin badges (client, server, skill, MCP). Adapters encode: OpenCode `session/command {name,text}` and `skills:[{id}]`; Codex `$name` text plus a `skill` input item; Claude `/name` text; Muse `skill` part; Pi `/skill:name` text.
- **Mentions** use `@` for files (OpenCode `files[].uri` with `?start&end` plus `mention {start,end,text}`; other harnesses encode per §3), agents, and later symbols. v1 inserted plain text only **[V `plan/00 §2.6`]**.
- **Attachments:** image picker, drag-drop and paste remain; gate by `AttachmentsCap` per model. OpenCode PDF is disabled with "PDFs are not sent to the model in OpenCode v2; convert a page to an image" **[V docs-attachments]**. Non-image files are uploaded (OpenCode `experimental/fs/write` then a `file://` URI; host upload for others).
- **Forms and approvals:** a form is a step wizard (reuse the question-stepper concept). Approvals show action, resources, diff preview when provided, scope chips (once, this session, project-wide) and the sensitivity label. The auto-approve shield chip shows the level (L1/L2/L3) with a one-tap pause.

### 5.5 Async subagents and background tasks

- **Tasks tray** (bottom sheet on phones, side panel ≥ medium width). Rows: running first; each shows agent, description, state, elapsed, last activity line, background badge, depth.
- **Timeline card** for a subagent tool call: a live status chip and the open-child action.
- **Navigation:** open the child session as a full view with a "Back to parent" banner. Composer availability follows `SubagentCap` (Codex v2 sub-agents reject direct input **[V]**, so read-only there).
- **Cancel:** OpenCode `POST /api/session/{child}/interrupt`; Claude `stopTask`; Muse `subagent/interrupt|stop`.
- A completed background run adds a notice in the parent timeline with a link. The synthetic "wake the parent" message is shown as a normal notice, never hidden.
- Nested runs show the early-completion warning described in §4.5.

### 5.6 Files, terminal, diff, undo

- File tree and viewer reuse v1 UI. Data comes from `FilesCap`. Mutations (new, rename, duplicate, delete) are shown only when a probe succeeds. For OpenCode, write uses `fs/write` (path validated to stay under the location); other mutations use non-session `POST /api/shell` jobs and the `shell.*` events, replacing v1's hidden-session `/shell` script (ADR-043 exception to be re-based).
- Diff viewer: `GET /api/session/{id}/diff?from&to` structured per-turn diffs replace v1's 25-call scan.
- **Undo copy by mechanism:** "Undo (can redo until your next message)" for OpenCode; "Fork conversation from here (new session; files not restored)" for Codex, Pi, Muse, Grok; "Rewind files to here" with a dry-run preview plus "Fork conversation here" for Claude. Redo exists only for OpenCode.

### 5.7 Quotas, errors, retries

- Quota popover shows windows with source badges (native or probe) and merges sparse updates. Context ring shows `contextUsed/contextWindow` only when the meter is exact or estimated.
- Errors: inline notice with typed kind, retry affordance when `retryable`, countdown for `retry.at`, and links such as "Open credits" when `ErrorInfo.action` exists. Quota errors name the provider and reset time when parseable from the body; otherwise show the raw message.

### 5.8 Accessibility and localization

- Keep the 14-locale ARB pipeline and `L10nBridge`. New keys are English-first. A CI gate lists missing keys per locale (English and Portuguese complete at release, others fall back and are tracked). Prune obsolete keys.
- Add live-region announcements for streaming (throttled), semantic labels explaining disabled capabilities, large-font and RTL (ar, ur) widget tests for new surfaces, and keep reduced-motion behaviour (ADR-056).

### 5.9 Notifications and process death

- Foreground: in-app attention banner plus system notification when the app is unfocused but running (desktop tray, Web notifications).
- Android FGS (opt-in): one SSE connection for the active endpoint; honest copy "delivery may be delayed or stop when Android restricts background work".
- Process death: on restart, rehydrate from persisted cursors and drafts; attention items are re-listed from the server (§4.5). Nothing is promised for a killed process beyond what the FGS or the host notifier provides.
- Host notifier (v2.1+): sinks configured per endpoint; payload minimal; deep link `codewalk://s/<endpoint>/<session>`.

---

## 6. Rewrite, reuse, discard map

### 6.1 Reuse, rewrite, simplify, defer, discard (by v1 inventory section)

| v1 area (`plan/00 §2`) | Decision | Reason and target |
|---|---|---|
| Server profiles, Basic auth (`app_provider.dart` 2,663 LOC, `servers_settings_section.dart`) | **Rewrite** as `Machine` + `Endpoint` | v1 had no harness type. Split the god object. |
| Health checks (10 s polling) | **Simplify** | Replace with SSE state plus a 60 s probe for inactive endpoints. |
| Cloudflare Access OAuth (ADR-033, `oauth_service_io.dart` 1,224 LOC) | **Defer** | Optional advanced transport. Port later if demanded. Stays on `v1`. |
| Tailscale embedded (`third_party/tailscale`) | **Keep** (moved to `packages/tailscale`) | Valuable, already working. iOS deferred. |
| Cellular Data Saver | **Simplify** to one "Reduce background traffic" toggle | v2's SSE cannot be filtered server-side; use backgrounding and delta coalescing. |
| `X-Session-Id` sticky routing | **Discard** unless needed | Undocumented **[V `plan/00 §2.1`]**. Re-add only on evidence. |
| Setup wizard | **Rewrite** | New chooser, pairing, adopt-or-install. |
| Managed install (`local_opencode_server_runtime_io.dart` 1,280 LOC) | **Rewrite**, keep the interface | `LocalOpencodeServerRuntime` already looks like a harness runtime. New install and `service` semantics (D10). |
| Setup debug page | **Simplify** | Keep sanitized log export. |
| Projects, icons, tab colors | **Rewrite data, keep UI** | Port to `/api/project`, `fs/*`. Worktrees (`/api/worktree`) deferred. |
| Sessions list, create, rename, delete, fork, compact | **Rewrite** | Cursor pagination, `parentID`, `compact`. Share discarded (unsupported upstream). |
| Archive | **Re-scope** | Client-local for OpenCode. |
| Auto titles via hidden `_title_gen` session (`chat_title_generator.dart`) | **Discard** | v2 emits `session.renamed` including automatic titles **[V `plan/12 §2`]**. For harnesses without titles use a first-message fallback (no LLM). |
| Session tabs and MRU switcher (`chat_provider_session_tab_ops.dart` 2,366 LOC) | **Keep concept, rewrite smaller** | High user value. |
| SWR cache, file payload store | **Keep** (ADR-016, ADR-020 limits) | Not v1 workarounds **[V `plan/00 §3`]**. |
| Chat provider and reducers (`chat_provider*` ~22.8k LOC) | **Discard**, replaced by core reducers | Largest simplification. |
| Chat page (`chat_page*` ~27.5k LOC) | **Rewrite shell**, **keep** leaf widgets (timeline viewport, scroll coordinator, markdown, tool cards) after decoupling from raw part types | |
| Streaming, tool groups, settlement heuristics | **Rewrite** | Use typed events and authoritative `ended`. |
| Abort policy (string matching) | **Discard** | Typed errors. |
| Undo/redo | **Rewrite** capability-driven | |
| Subagents resolver (heuristics) | **Discard** | Explicit parent/child links. |
| Slash commands, `@` mentions, `!` shell | **Rewrite** | Structured parts, shared palette. |
| Skills | **New** | |
| Attachments, drafts, canned answers, STT | **Keep** | Client-only; adjust gating. |
| Model selector, favorites, recent, shortcuts | **Keep UI, rewrite data** | Variants become `ReasoningCap`. |
| OpenCode defaults editor (`GET/PATCH /config`) | **Discard in v2.0** | `PATCH /api/experimental/config` only accepts `{shell}` **[V]**. |
| Selection sync via fake `__codewalk` agent | **Discard** | Possible future: per-session `metadata`. |
| Permission cards, auto-approve (`permission_auto_approve_runtime.dart`, page-layer logic) | **Rewrite** into the core policy engine | Fixes layering (logic lived in the page **[V `plan/00 §5.2`]**). |
| Question cards | **Rewrite** as generic forms | |
| Todo panel | **Capability-gated** | OpenCode has none. |
| Files UI, editor | **Keep UI, rewrite data**; mutations rebuilt | |
| Terminal (xterm, `codewalk_terminal_*`) | **Keep**; new ticket flow | |
| Quota (`quota_remote_datasource.part.js.dart` 1,742 LOC JS-in-Dart) | **Discard**; native plus host probe | |
| Voice STT/TTS (ADR-006/038/039/044/047/048/053) | **Keep as is** | Large, client-only reuse. |
| Notifications, 3 Android detectors | **Rewrite** into one attention model, one FGS, one sparse fallback | |
| Session attention overlay (ADR-049, ~973 LOC + `SessionOverlayService.kt` 720 LOC) | **Defer** | Revisit after the attention model stabilizes. |
| Android Auto messaging (ADR-055) | **Defer** | |
| Desktop tray, window chrome | **Keep** | |
| Settings shell, theming, 37 theme presets, shortcuts | **Keep** | Verify `make theme-sync` against v2 sources; freeze the registry if the sync source moved **[U]**. |
| Self-update | **Keep, fix** (§2.3) | |
| Release history | **Keep** | |
| Logs | **Keep** | |
| Deep links | **New** | |
| Session export | **Rewrite** over the canonical model | Optionally add native export `/api/experimental/session/{id}/export`. |

### 6.2 v1-only workarounds removed or replaced (`plan/00 §3`)

| # | Workaround | v2 replacement |
|---|---|---|
| 1, 2, 3 | Dual SSE plus dedupe ring; degraded polling; post-reconnect recovery | One `/api/event`; watchdog; rehydrate plus optional durable log. |
| 4 | Send-completion watcher | `prompt` returns the inbox item; execution events. |
| 5, 6 | Refetch on every delta; non-regressive merge | `ended` authoritative; reducer. |
| 7 | Optimistic echo reconciliation by content | Client message id or `metadata.cw.mid`. |
| 8, 9 | Fabricated completion; abort suppression | Typed outcomes and typed errors. |
| 10 | Busy heuristics | `execution.*` plus `/session/active`. |
| 11 | Growing-limit pagination | Cursor pagination. |
| 12, 13 | Global-event fallbacks; `session.next.*` refresh | Real reducers. |
| 14 | Pending-question retry and tombstones | Forms plus rehydrate. |
| 15 | Legacy route fallbacks | Deleted. |
| 16 | Config-write deferral (ADR-019) | No config writes in v2.0. |
| 17 | Hidden-session titles, file ops, quota | Native titles, `fs/write` and `/api/shell`, native or host quota. |
| 18 | Fake-agent selection sync | Deleted. |
| 19 | Diff scan of 25 turns | `session/{id}/diff?from&to`. |
| 20 | Child-session resolver heuristics | `parentID` and metadata. |
| 21 | Project commands scan via `/file` | `GET /api/command`. |
| 22 | Archive cascade | Client-local archive. |
| 23 | Android three-detector stack | One FGS plus sparse fallback. |
| 24 | Client-side context math | Server running totals. |
| 25 | Unknown part → text | Typed `UnknownItem`. |

### 6.3 Local data migration and rollback

- v2 reads a v1 install through `V1Importer` (idempotent, resumable). It imports app-level settings, secure keys for TTS and STT, theme, shortcuts, canned answers and the host list (as "needs OpenCode v2" endpoints). It does **not** import session caches, tabs or drafts scoped to v1 sessions.
- v2 never deletes v1 keys for at least two releases. `cw2.import.v1.done=<timestamp>` marks completion. The native `CodeWalkApplication.kt` pre-engine prefs purge must be updated for the new key namespace **[V `plan/00 §1.6`]**.
- Rollback: Android allows install-over by a v1 maintenance build because the epoch-based versionCode is higher. Desktop reinstalls v1 from the legacy download. Web uses the v1 alias.
- The import is marked "once, non-destructive" in the UI with an explicit legacy-download link.

### 6.4 Version, build number, app ID, legacy download (concrete)

- App ID unchanged (`com.verseles.codewalk` **[V `android/app/build.gradle.kts`]**); the same Android keystore secrets are mandatory or updates fail.
- `pubspec.yaml`: `2.0.0+<epoch>` via the existing release tooling (`make release V=major`). Pre-releases are tagged `v2.0.0-beta.N` and marked `prerelease: true`. Both are flagged in `release.yml`, which currently sets `prerelease: false` unconditionally.
- The v1 branch must use `make_latest: false` in its own `release.yml`.
- The legacy v1 download is a pinned link to the last v1 GitHub release; the in-app screens link to it.

### 6.5 Documentation and ADR work (coordinated, not blind)

| Doc | Action |
|---|---|
| `BEHAVIOR.md` | Per AGENTS.md it documents implemented behaviour only. On the v2 branch reset it and grow it stage by stage. Planned behaviour lives in `docs/v2/`. |
| `ADR.md` | New ADR-058 (v2 architecture: workspace packages, canonical model, host). New ADR-059 (v2 contract matrix and exception register). Amend ADR-023 to name the official v2 docs and OpenAPI as the contract and list local anchors. Supersede or retire ADR-003 (dual SSE), 009 (hidden-session titles), 018 (SSE Dio), 019 (config deferral), 029 (quota via shell), 041 (delta reconciliation → new invariants), and revise 017, 031, 043, 049, 055. **EXC-001 is superseded** by §2.4. |
| `CONTRACT_MATRIX.md` | Rewrite for v2 (per-operation matrix keyed by `operationId`). |
| `ai-docs/` | Add `opencode_v2_*.md` anchors from `plan/opencode-v2-docs/`. v1 anchors stay on `v1`. |
| `CODEBASE.md` | Regenerate at structural milestones. |

Intentional divergences from the official contract that require an ADR exception:

- Using `experimental.fs.write` and `POST /api/shell` for file mutations (extends ADR-043).
- Using the experimental `session/{id}/log` for catch-up.
- Local-only archive state.
- Opt-in host-side vendor quota probes (rewrite of ADR-029).

---

## 7. Ordered implementation stages and dependencies

### 7.1 Bounded spikes (parallelizable; each ≤3 working days; output = a short result note plus fixtures)

| ID | Question | Method | Gate impact |
|---|---|---|---|
| S1 | OpenCode 2.0.22 live contract | Run the service on a scratch host. Capture `/api/info`, pairing, a full SSE turn with permission, form, background subagent, revert and interrupt; test `session/{id}/log` replay; client-minted `id` idempotency (Paseo conflict); session `permissions` override against the plan agent and child inheritance; `GET /api/session` including TUI-created sessions; `POST /api/shell`; `fs/write` confinement; PDF behaviour; bytes per minute with several concurrent sessions | Reducer fixtures; D05; G-BW |
| S2 | Web feasibility | Browser matrix for fetch-stream SSE with an Authorization header, CORS with `service set cors`, mixed content, Private Network Access, PTY ticket flow | D08, D09 |
| S3 | macOS managed install | Sandboxed vs non-sandboxed notarized build; download, exec, `service start` | D10 on macOS |
| S4 | iOS bring-up | `flutter create --platforms=ios`, plugin audit (workmanager, tray, window_manager, desktop_drop are desktop-only), ATS and Local Network on a real device against a plain-http Tailscale IP, Keychain, privacy manifest | D09 |
| S5 | Host packaging and language | An "echo host" with WebSocket, child process, PTY and one SDK, built five ways (Node SEA, Bun compile, Dart AOT, Go, npm-only); measure size, RSS, startup | D15 kill switch |
| S6 | Codex shared daemon bridge | `codex app-server proxy` over stdio vs `ws+unix`; Windows path limits; `initialize.userAgent` parsing; `thread/list` includes TUI threads; `thread/resume` rejoin with approvals replayed; concurrent steer; two-process rollout risk | D13, v2.1 |
| S7 | Claude capture | Scripted `query()` capture of full streams (text, tools, `task_*`, `rate_limit_event`, interrupt race), TUI session listing and resume vs a live TUI, uuid acceptance for `rewindFiles`, Todo tools opt-in | v2.2 |
| S8 | Muse, Pi, Grok smoke | Muse `allowAll` vs sandbox; Grok `serve` endpoint and token transport; Pi session list | v2.3, v2.4 |
| S9 | Notification feasibility | ntfy and UnifiedPush end to end on Android 15; FGS `dataSync` timeout behaviour; iOS ntfy deep link | D07 |

### 7.2 Stages and acceptance

| Stage | Scope | Depends on | Acceptance and validation |
|---|---|---|---|
| 0 Freeze and prepare | `v1` branch and tag; `v2-dev` branch; legacy Web alias; ADR-058/059 drafts; `release.yml` flags; `docs/v2/` | none | v1 builds unchanged; Pages preview from `v2-dev` works |
| 1 Skeleton | pub workspace, packages, DI, router, lint boundaries, theme/markdown/l10n carry-over, `LocalStore`, CI for all six targets including `flutter build ios --no-codesign` | 0, S4 start | `make check` green with analyzer budget 0; import-rule tests pass |
| 2 OpenCode connection | detect, auth, pairing, SSE reader and watchdog, DTOs for ~50 operations, fake server with fault injection, fixtures from S1 | 1, S1 | contract tests against recorded fixtures and the pinned `openapi.json` |
| 3 Canonical core vertical slice | domain, OpenCode mapper, reducers, session list → open → history → send → stream → interrupt | 2 | chat MVP on Android and desktop; reducer property tests pass |
| 4 Attention and input | approvals and L1/L2/L3, forms, steer/queue/inbox, typed errors and retry, usage and context | 3, S1 (D05 probe) | race tests (double answer, reconnect mid-request) |
| 5 Subagents and features | subagents tray, undo/redo, fork, compact, commands, skills, mentions, attachments, model/agent/reasoning, files, terminal, diff | 4 | nested background fixtures; feature acceptance per §5 |
| 6 Platform and lifecycle | managed install (desktop), pairing UX, updater and migration (§2.3, §6.3), Web and iOS parity, Android FGS and fallback, a11y and l10n gates | 5, S2, S3, S4, S9 | upgrade test; `make test-web`; TestFlight build if B1 |
| 7 Hardening and release | perf and battery budgets, docs and ADRs, beta (`.next` suffix), v2.0 GA | 6 | all gates in §8.4 |
| 8 Host and Codex (v2.1) | host skeleton, CHP, auth/pairing, notifier, Codex adapter, OpenCode observer | S5, S6; G-BW decides relay mode | CHP golden fixtures shared by TS and Dart; D13 Codex acceptance |
| 9 Claude (v2.2) | Claude adapter, gap services, policy disclosures | S7 | captured stream fixtures; policy checklist |
| 10 Muse and Pi (v2.3) | adapters | S8 | MSP transcript conformance; Pi RPC fixtures |
| 11 Grok and ACP (v2.4) | Grok, generic ACP client, dsh experimental | S8 | ACP TCK-style tests |

**Minimum viable v2.0:** stages 0–7 without the attention overlay, Android Auto, worktrees, provider login, Cloudflare Access, or iOS public release (build gate plus TestFlight). Nothing user-requested is deleted; items are deferred with a stage.

**Gate G-BW:** if S1 shows unacceptable mobile bandwidth or battery from the unfiltered global stream, add the host's OpenCode **relay mode** (single upstream connection, 50 ms delta coalescing, 2,048-event or 8 MiB replay ring, `replayReset`) as a v2.1 item, with the app switching endpoints transparently.

### 7.3 First files and commands (execution start)

1. `git branch v1 14fbf519 && git tag v1-final-candidate` (the orchestrator performs Git writes).
2. Create `v2-dev`; add `packages/codewalk_core` and `packages/harness_opencode_v2` with empty exports and the import-rule script.
3. First code: `packages/harness_opencode_v2/lib/src/sse/sse_parser.dart` (UTF-8 safe), then `wire/` DTOs for `session`, `message`, `event`; then `mapper/`.
4. Record S1 fixtures into `packages/harness_opencode_v2/test/fixtures/events/*.jsonl`.
5. Focused validation commands (run later, not now):
   - `export PATH="$HOME/flutter/bin:$PATH"`
   - `dart test packages/codewalk_core`
   - `dart test packages/harness_opencode_v2`
   - `flutter analyze <paths>`
   - `flutter test test/unit/...`
   - `make check` at gates; `make test-web` for Web.
   - `make android` only on a non-ARM64 host or via CI.

**Strict prerequisites:** branch and workflow protections from stage 0 before any push to `main`; S1 before the reducer is frozen; B1 before any iOS signing work.

---

## 8. Testing and validation

### 8.1 Adapter and contract fixtures

- **OpenCode:** `FakeOpenCodeV2Server` (replaces `test/support/mock_opencode_server.dart`, 1,335 LOC) serves the used `/api` subset with scripted event timelines and fault injection: disconnect mid-delta, 4,096-frame overflow, `503 service_starting`, 401 body, HTML-200 for v1 paths, malformed JSON, 16 MiB frame, duplicate and reordered events.
- **Recorded fixtures** from S1 are the reducer truth. A contract script checks every `operationId` and parameter the app uses against the pinned `plan/opencode-v2-docs/openapi.json` (`tool/contract/check_openapi_usage.dart`).
- **Codex:** snapshot tests against generated `generate-json-schema` output, including `-32601` and `requires experimentalApi capability` downgrade paths. **Claude:** captured stream fixtures (S7). **Muse:** the official transcripts under `plan/harness-src/muse/transcripts/`. **Pi:** JSONL command and event fixtures. **ACP:** protocol-level tests with a fake agent.
- **CHP:** one fixture set shared by TS host tests and Dart client tests (golden `.jsonl` plus JSON-Schema validation).

### 8.2 Behaviour and race cases (must pass)

- Reducer: random permutations of delta batching, duplicates after reconnect and `ended` arrival converge to the snapshot.
- Reconnect during streaming, permission and form; reconnect during revert; `shutdown` interrupt and resume.
- Permission races: double answer from two clients; reply after a child completes; reject-cascades.
- Prompt: ambiguous POST then retry; 409; id mint conflict fallback.
- External sessions: TUI-created OpenCode session appears; Codex daemon thread appears and rejoin replays approvals; Muse `sessionInUse`; Claude concurrent TUI risk behaviour documented.
- Nested background subagents and the #48826 early completion warning.
- Malformed and unknown events never throw. Unknown enum values decode.
- Multi-host scope isolation: two endpoints with identical session ids never collide (`SessionKey` includes the endpoint).
- Web: origin, CORS, fetch-stream auth, mixed-content detection, PTY ticket. iOS: foreground resume reconnect, no background promises, local-network permission denial.

### 8.3 Upgrade and migration tests

- Android install-over from a real v1 APK to the v2 APK (same signature); v1 data intact; `V1Importer` idempotence; downgrade by a higher-versionCode v1 build.
- Updater: semver with prerelease; ignores major ≠ 2; "latest" flag behaviour on the v1 branch.
- `service.json` adoption: existing service with a compatible version is reused, an older version triggers the version-gate screen.

### 8.4 Performance, battery and accessibility budgets

- Cached session open to first render ≤150 ms (ADR-057 style frame budget); streaming UI notify ≤1 per 100 ms per session; resident messages per session capped (for example 300) with paging; do not keep base64 `PromptFileAttachment.data` in lists.
- Background: no network when backgrounded without the FGS. FGS holds one SSE per endpoint. Sparse fallback ≤2 requests per endpoint per run.
- Accessibility: TalkBack and VoiceOver smoke on core flows, large-font goldens, RTL for ar and ur, keyboard navigation on desktop.

### 8.5 Project gates (per AGENTS.md)

- Focused tests and `flutter analyze <paths>` while iterating. `make check` only at validation gates. Do **not** run `make precommit` directly; run `make check` and `make android` separately.
- Platform builds: `make web` plus `make test-web`; desktop builds via CI and local `make desktop`; Android release APKs through GitHub Actions (ARM64 hosts are unreliable **[V AGENTS.md]**); iOS compile gate on a macOS runner.
- CI additions: `opencode-smoke.yml` switches from npm `opencode-ai` to `@opencode/cli@<pinned>` plus a nightly drift run against latest; a new `harness-drift.yml` for Codex and ACP schema checks.
- A code review is required later, after coherent implementation. It is not part of this planning work.

---

## 9. Risks, assumptions, fallbacks, open questions

### 9.1 Risks and mitigations

| Risk | Mitigation |
|---|---|
| OpenCode v2 API churn (OpenAPI `0.0.1`, near-daily releases, experimental endpoints) | Pin tested window; nightly OpenAPI-usage diff; feature flags for experimental calls; open enums. |
| Unfiltered global SSE bandwidth and overflow disconnects | Isolate reader, rehydrate on reconnect, G-BW relay mode. |
| Auto-approve safety | L1/L2/L3 split, sensitive exclusions, no `always`. |
| Claude policy drift (changed four times in 2026 **[V `plan/21 §6`]**) | Run only the unmodified binary on the user's host; no credential handling; API-key mode documented; disclosure UI; per-release policy re-read. |
| Codex protocol churn (weekly) | Schema-snapshot CI, lenient parsing, version negotiation against the daemon. |
| Host as remote code execution surface | Auth always on, loopback default, origin and Host checks, workspace allowlist, no credential forwarding, token rotation. |
| v1 users stranded by auto-update | §2.3 mitigations; optional guard release. |
| iOS delivery limits | Foreground-only claims; ntfy surface; B1. |
| macOS sandbox blocks managed install | S3; ship notarized non-sandboxed desktop build or disable managed install on macOS. |
| Experimental `fs/write` is unconfined | Client-side path validation; feature flag; shell fallback. |

### 9.2 Assumptions (unverified) and what to do if false

- **[U] `prompt {id}` is client-mintable** (Paseo claims otherwise). If false, use the synchronous inbox response and `metadata.cw.mid` correlation.
- **[U] Session `permissions` precedence** as documented (agent ++ session, last wins). If different, L3 is redesigned or removed.
- **[U] TUI sessions share the service by default.** If not, add a host observer or document `--standalone` limits.
- **[U] Node single-file packaging works with the Claude SDK.** If not, npm-only or Dart AOT fallback.
- **[U] Codex `ws+unix` and `proxy` stdio paths both work on all OSes.** If not, SSH or loopback fallback.
- **[U] Android 15 FGS timing** and ATS handling for Tailscale IPs. Fall back to the sparse poll and `NSAllowsLocalNetworking` exploration.
- **[U] OpenChamber-style behaviours** are not contract. They are patterns only.

### 9.3 Unresolved questions (explicit, with owner step)

1. Apple Developer account availability (B1).
2. Whether to publish the optional last-v1 guard release (D04).
3. Whether the user accepts narrowing auto-approve to non-sensitive requests (D05 ALT-D05-narrow).
4. Whether a CodeWalk-operated push relay is ever acceptable (D07b).
5. Host language final call after S5 (D15).
6. Whether to bundle or only install the Claude SDK (B2).

### 9.4 Source references

- Local: `plan/00` (inventory) · `plan/01` · `plan/02` · `plan/10`–`13` · `plan/20`–`25` · `plan/30`, `31` · `plan/opencode-v2-docs/{docs-attachments,docs-install-script,docs-network}.md` · `plan/harness-src/muse/` · `ADR.md` (ADR-023 lines 1103–1255, EXC-001 line 1241) · `AGENTS.md` · `Makefile` (`check`, `android`, `release`) · `.github/workflows/{release,web-pages,ci}.yml` · `lib/presentation/services/update_check_service.dart:14,161-200` · `pubspec.yaml:19` (version `1.265.0+1790827338`) · `android/app/build.gradle.kts`.
- Official OpenCode v2: https://opencode.ai/v2/docs/ · migrate-v1 · `anomalyco/opencode` branch `v2` tag `v2.0.21` (`8a8bd622`) · npm 2.0.22 (`05018b88`).
- Codex `openai/codex` tag `rust-v0.160.0`; Claude Agent SDK 0.3.287 (CLI 2.1.287); Pi 1.0.0 `earendil-works/pi`; Muse `meta-models/muse-code-sdk` (MSP v1); Grok `xai-org/grok-build` 1.0.46; `deepseek-ai/deepseek-harness` 0.2.0-rc.2; ACP `agentclientprotocol/agent-client-protocol` (v1 stable, v2 draft).
- Secondary patterns only: OpenChamber `fc012ae0029fa2ac8d1d52b4af37040fc536258e` (`plan/31 §2`), Paseo, t3code, Happy, Reemoat, Agmente.
- Evidence conflicts to resolve during spikes: (a) README "no endpoint for writing files" vs `experimental.fs.write` (§3 notes); (b) Dart ACP SDK availability (`plan/21` vs `plan/30`); (c) Grok `serve` endpoint documentation (`plan/24` vs `plan/30`); (d) client-minted OpenCode message ids (OpenAPI vs Paseo).