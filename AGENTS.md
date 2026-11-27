# CodeWalk Project Rules

> General rules from the main `AGENTS.md` apply. This file holds only CodeWalk-specific rules and overrides.

## Owner commands

The owner is short on time. These orders are enough; do not ask for routine technical choices.

| Order | What the agent does |
|---|---|
| `avançar` / `continuar` | Resumes unfinished work, otherwise runs the first open item of active priority Issue #527 (while open) or `ROADMAP.md`, from issue to push. No release. |
| `avançar N` | Runs the next N items, one review boundary each. No release. |
| `flow` | Extends the global `flow` for the requested work or current unit: plan when triggered (asking necessary clarifying questions via `hey` before implementing), implement, commit boundary, run local gate + reviewers in parallel, fix, evaluate helpers, update docs/Issue, squash, push, then cut a `minor` release by default (`make release V=stable` + `make watch-release`) unless told otherwise. |
| `apk` | Builds the Android APK here and sends it to `@VerselesBot`. No version, no tag. |
| `status` | Reports the next lines of the queue, local state and the latest runs, with at most one `gh` call. |
| `prioriza #N` | Moves that line to the top of `ROADMAP.md`. |
| `adiciona: <ideia>` | Creates the Issue under `gh-helper` and adds its line to the fitting block. |

Ask only for a product decision or a required human action, with lettered options and a recommendation. Findings outside the current line become an Issue plus a line in the queue, never scope growth.

## Sources of truth

- `ROADMAP.md`: the order of work and the only file the owner needs to read.
- **Temporary active priority — Issue #527 (Roadmap UX):** while open, work through #527's prioritized UX queue before `ROADMAP.md`. Once #527 is completed, remove this note and resume `ROADMAP.md` (next major focus: Codex harness).
- GitHub Issues: scope and acceptance of each line. Close an Issue when its line is delivered, commenting the commit.
- `BEHAVIOR.md`: current v2 behavior only.
- `ADR.md`: architecture decisions, updated through the `adr` skill.
- `v2-plan.md`: reference for product intent, invariants and architecture. Record a change of decision, order or scope in its §17.
- `plan/`: frozen research. Read it only when evidence is needed.
- Do not create or update `CODEBASE.md`; it was removed intentionally.

## v1 is a UX reference, never a source of code

- Everything v1 lives on the `v1` branch. Do not bring v1 code, text or mechanisms into `main`.
- Issue #446 indexes the 285 v1 behavior sections. Read only the section your line needs: `git show origin/v1:BEHAVIOR.md`.
- Keep what the user sees and feels: gestures, placement, flow, wording and feedback. Drop workarounds, heuristics, protocol mechanics and excess settings.
- Write what is kept as `UX to preserve` in the Issue, in v2 terms, and implement from that. When the result of the filter is a real product doubt, ask.
- Read v1's implementation for lessons (platform quirks, pinned versions, pitfalls, what failed), then write v2 code fresh: modern APIs, v2's architecture and tests. Never copy v1 code, even adapted; improve on it whenever possible.
- Pixel-level visual parity with v1 is not a goal (owner, 2026-11-05).

## `flow` / `avançar`, unit by unit

CodeWalk's `flow` extends the global `flow` (keeping necessary pre-implementation questions via `hey`, helper evaluation with `hey`, and end-of-flow evergreen `AGENTS.md` suggestions), applying these project-specific steps and overrides:

1. Read the Issue and apply the v1 filter. Load `planner` only under its triggers: architectural impact, broad cross-module scope, consequential tradeoffs or an explicit request. Before implementing, ask any necessary product/clarifying questions (lettered options + recommendation) and notify the owner via `hey`.
2. Implement. While iterating, use the narrowest validation: focused tests and targeted `flutter analyze <paths>`.
3. Commit the stage as the review boundary, with only intended files plus the `.task-memory/` snapshot.
4. In parallel, run the local gate and all eligible reviewers under the `reviewer` skill.
5. Judge the reports and apply the accepted findings in one commit. Re-review only when the fixes touch concurrency, security, interfaces, persistence or architecture; otherwise validate them with focused checks.
6. Evaluate the helpers used (per global `flow`, including the `hey` summary paragraph), update `BEHAVIOR.md` and the Issue, check off the item in #527 (while active) or delete the line from `ROADMAP.md`, and squash the loop under the general conditions.
7. `git push origin main`. For `flow`, cut a **`minor`** release by default (following `Releases on main`: commit & push `release-notes/vX.Y.Z.md`, then `make release V=stable` + `make watch-release`), unless the owner specifies `patch` or `no release`. For `avançar`, skip release and run `make watch-ci`. Finish with a `hey` stating the outcome and next line.

A blocked line stays in place with its blocker noted; take the next line that does not depend on it, or report the pending owner action.

## CI: never watch it

This overrides the general `cimonitor` and 60-second rechecks in this project. Tokens must not be spent on something that runs by itself.

- `make watch-ci` and `make watch-release` start a detached script with no agent. It waits for the run of the current commit and reports through `hey`: CI only on failure, Release always.
- After starting a watcher, end the turn. Do not use `cimonitor` or `gh run watch`, and do not poll.
- Look at CI only when `status` is ordered or a failure was reported.
- A reported CI failure never delays the queue. Fix it in parallel with the next unit, in a commit of its own.
- The local gate decides whether a commit is ready. CI is a safety net.

## `apk`: send a test build through `tdl`

Adapt to the current machine (`uname -m`): on the owner's x86_64 PC (`neo`, 20 threads), local APK builds are faster than CI; on ARM64 cloud hosts (e.g., `mercury`), APKs do not build reliably—do not build them locally there. A test APK is not a release: no version bump, no tag, and the updater is not involved. `hey -f` cannot deliver it because the APK exceeds the Telegram Bot API upload limit.

```bash
export PATH="$HOME/flutter/bin:$PATH"
flutter build apk --release --target lib/main_v2.dart --target-platform android-arm64 --split-per-abi --build-number "$(date +%s)"
```

- Do not pass `--no-pub`: the build then keeps dev plugins in the registrant and fails. Without `--split-per-abi` the APK grows from about 90 MB to about 148 MB.
- `--build-number` keeps the versionCode above the installed one, so Android accepts the update, and below the next release, whose number also comes from the clock.
- Output: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`. `android/key.properties` (ignored by git) signs it with the production key; `apksigner verify --print-certs` must show `7361852522a3c5ba…b846c9`, the only signer the updater accepts.

Send it to `@VerselesBot`, the bot `hey` uses:

```bash
mkdir -p /tmp/opencode && dir=$(mktemp -d /tmp/opencode/apk.XXXXXX)
name="codewalk-$(git rev-parse --short HEAD)-local-arm64.apk"
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk "$dir/$name"
cp ~/.tdl/data/default "$dir/default"
T="tdl --storage type=bolt,path=$dir -n default"
$T up -t 6 -c VerselesBot -p "$dir/$name" --caption '"CodeWalk local <sha> android-arm64: <o que testar>"'
$T chat export -c VerselesBot -T last -i 3 -o "$dir/verify.json" && jq -e --arg n "$name" '.messages[] | select(.file == $n)' "$dir/verify.json"
rm -rf "$dir"
```

- The owner's own `tdl` jobs often hold `~/.tdl/data/default`. Never stop them; the copy above avoids the lock. It contains the session key, so always remove it.
- `--caption` is an expression, so the text needs inner quotes.
- Never run `tdl login`. On an authentication error, ask the owner to do it.
- Follow with a `hey` naming the file, its size and what to test.

## Project

- CodeWalk is a mobile and desktop client for OpenCode. Work must fit both; prioritize mobile UX, Material You and responsive layouts.
- For visual changes, confirm the exact screen or block when the request is ambiguous.
- After a change, decide whether tests need adding or updating.
- Use descriptive commit messages. Every commit includes the current `.task-memory/` snapshot, with additions, updates and deletions from `tm`; this overrides general exclusions. The folder is gitignored, so stage it with `git add -f -A .task-memory`.

## Lines and platforms

- `main` is CodeWalk 2 and holds only v2. The entry point is `lib/main_v2.dart` until the cutover (#319).
- `v1` is 100% frozen. Check the branch before editing, and never merge whole trees between lines.
- v2 releases ship Android arm64, Linux x64/arm64, Windows x64 and macOS arm64. Web and iOS come later in the queue. v2 does not import v1 data.
- #476 removed the v1-only dependencies; `window_manager` (#474) and `speech_to_text` (native dictation slice of #307) have since returned. Remaining ones return only with the v2 feature that uses them: TTS/remaining voice #307, notifications and tray #309 (`tray_manager`), terminal #291 (`xterm`), and Tailscale #317.

## Web origins

- Stable v1 Web: `https://codewalk.pages.dev`. `main` preview: `https://main.codewalk.pages.dev`.
- A local change reaches Pages only after a push and a successful deployment. Compare the deployment commit with `origin/main` before validating; an app version or an HTML 200 is not commit evidence.
- Revalidate this section whenever origins, routing or deployment change.

## Contract

- Read `BEHAVIOR.md` before substantial planning.
- Behavior changes follow ADR-023 (contract first) and ADR-058, anchored on `ai-docs-for-opencode-v2/opencode_v2_server.md`, `opencode_v2_web.md` and `opencode_v2_models.md`. The v1 anchors `ai-docs/opencode_*.md` live on the `v1` branch and do not constrain v2.
- The official OpenCode clients `https://github.com/anomalyco/opencode/tree/dev/packages/cli` and `https://github.com/anomalyco/opencode/tree/dev/packages/app` are the crucial reference for the most correct way to use the v2 API and events. Check how they do it before implementing or changing API calls or event handling.
- `https://github.com/openchamber/openchamber` is the secondary reference, a community client that already runs on OpenCode v2. After the official clients, check how it uses the v2 API and events, especially where they are silent or ambiguous. It never overrides official docs or source, and its own server routes (`packages/web/server`) are not OpenCode's API.
- For OpenCode or OpenChamber source, inspect GitHub URLs, raw files, commits and pull requests directly, not through the `researcher` subagent.
- A behavior that cannot align with the official contract is blocked unless an ADR exception documents rationale, risk, rollback or flag, and regression tests.

## Harness diversity

CodeWalk 2 serves many harnesses. OpenCode is only the first adapter; Codex, Claude Code and others follow. Build every feature for that diversity, as ADR-058 and `v2-plan.md` already require (§4 invariants 1, 2, 10 and 12; §6.5 canonical model; §6.7 capability model; §7 capability matrix).

- Widgets and controllers read canonical types from `packages/codewalk_core` and capabilities only. No wire types above `packages/harness_*`, and no branching on the harness name.
- Gate anything a harness may lack behind a capability, with a defined fallback: a local equivalent when CodeWalk can honestly own it, otherwise no control. Never fake a native capability.
- When a feature needs data the canonical model lacks, add an optional harness-neutral field to `packages/codewalk_core`, let each adapter fill it, and record the change in `v2-plan.md` §17.
- Keep the variation at the adapter and capability seam, not in conditionals spread across screens. Defaults that do not depend on a harness, such as CodeWalk's agent colors, live in the app.
- Every Issue and plan that adds or changes behavior names its capabilities and the fallback for a harness without them.

## Validation

- Prepend `export PATH="$HOME/flutter/bin:$PATH"` to Flutter commands in every shell.
- The local gate is `make check TEST_JOBS=$(nproc)`, plus `make v2-native-check` when `packages/`, the architecture rules or the CHP changed. Run it once the code is stable.
- Do not use `make precommit`. After reviewer micro-fixes, use focused checks; rerun the gate only when a fix touches shared infrastructure, dependencies, generated files, l10n or build configuration.
- Static text and docs changes need no gate unless they affect build or release instructions.
- Golden references are x86_64 renders, regenerated with the `Goldens` workflow (`gh workflow run goldens.yml`), never on ARM. `test/flutter_test_config.dart` accepts up to 0.01% differing pixels on x86_64 (CI) and 0.3% on other hosts, where antialiasing rounds differently (#465; owner decision 2026-11-13). APKs do not build reliably on ARM64.
- When a unit changes goldens, finish it in this order: push `main`, run `gh workflow run goldens.yml --ref main`, download its artifact with `gh run download <id>`, commit only the PNGs that differ from the repo (inspect them first), push, then run the gate on that SHA before any release. Until then the stale goldens are the only accepted failures.
- While goldens are known to be stale, run `flutter test --no-pub -j $(nproc)` (no `--fail-fast`) to see every other failure; `make check` stops at the first one and reports the rest as "did not complete".
- Coverage floor: 85% of app lines under `lib/`, plus the file floors in `tool/ci/coverage_baseline.tsv`. Package coverage is not gated yet (#477). Never lower a floor to get a green check.

## Helper budget

- Each planning or review helper has a hard 45-minute limit. With the unified runner, use `--timeout 2690` under a 2700-second outer limit, and terminate the owned process groups at the deadline.
- When another helper or usable report exists, ignore a timed-out helper for that round, without retry or replacement, and record it as a technical failure. Resume it only when nothing else is available.
- All other participation, Task Memory, judgment and validation rules stay in force. CI and test budgets are not affected.

## Releases on `main`

- CodeWalk 2 has graduated to stable releases (`v2.0.0+`). Never cut a release without an explicit owner order: `flow` authorizes a default `minor` release at completion unless the owner specifies `patch` or `no release`; plain `push` and `avançar` never cut a release.
- A release requires curated release notes in `release-notes/vX.Y.Z.md` (led by one `> 📣` line in English of at most 300 characters, no `##` headings), a clean tree, `main == origin/main`, and a green local gate on that exact SHA. Never run a release in parallel with the gate; a published tag never moves.
- Curate and approve release notes autonomously by default; do not pause to ask the owner to approve the release text unless explicitly asked.
- `make release V=stable` (via `tool/release/cut_stable.py`, defaulting to `--bump minor`; invoke `python3 tool/release/cut_stable.py --bump patch` for a patch) reads the already committed and pushed `release-notes/vX.Y.Z.md`, prepends `CHANGELOG.md` automatically, bumps `pubspec.yaml`, commits both with `.task-memory`, creates the tag and pushes atomically, followed by `make watch-release`. Do not edit `CHANGELOG.md` manually before cutting; commit all code and release notes first. A plain `push` is not a release.
- Keep `CHANGELOG.md` machine-readable: unique `## vX.Y.Z - YYYY-MM-DD` headings, newest first, `###` for subsections. Each release may have one leading `> 📣` line in English, up to 300 characters. Preserve prior sections.
- Release rules for v1 live in the `AGENTS.md` of the `v1` branch.

## Known pitfalls

- Translations: change only the needed keys, keep ARB and generated code in sync, and inspect the diff after any regeneration for unintended removals.
- Localization keys live in three places that must agree: the hand-edited ARB files (`lib/shared/l10n/arb/app_*.arb`; some locales have no `@key` metadata block), the key lists in `tool/l10n/*_catalog.py` (plus any imported key set in `generate_v2_localizations.py`), and the generated code from `python3 tool/l10n/generate_v2_localizations.py`. The generator refuses any ARB key a catalog does not list; finish with `--check`.
- If `/tmp` is full, export `TMPPREFIX`, `TMPDIR`, `TEMP` and `TMP` to a directory with space on the same filesystem instead of deleting other processes' files.
- After `dart format`, inspect the hunks and revert churn outside the intended change; reformatting other code goes in its own commit, never mixed with a feature or fix.
- Credential redaction before truncation: when capping potentially sensitive strings in projections or UI, redact against the full source text with `redactCredentialSlice` before applying the byte cut—never slice with a fixed lookahead first, or credentials and PEM blocks crossing the cut boundary can leak.
- On ARM64 hosts (`mercury`), do not run `dart run tool/ci/import_rules.dart` (or `make v2-architecture`) in isolation for ordinary `lib/` edits because native build hooks can hang (`Running build hooks...`); use `make check TEST_JOBS=$(nproc)` (and `make v2-native-check` only when `packages/`, architecture rules, or the CHP change).
- Flutter 3.50.1 deprecates `package:flutter/material.dart` in favor of `package:material_ui/material_ui.dart`, which currently conflicts with third-party UI dependencies; add `// ignore: deprecated_member_use` immediately above every `import 'package:flutter/material.dart';` line in new Dart files (and keep `deprecated_member_use` enabled in `analysis_options.yaml`).
- On ARM64 hosts (`mercury`), avoid starting `make check` during the initial parallel startup spike of multiple review helpers because `test_v2_linux_preview.py` can hit the 15 s `tesseract` OCR timeout under CPU contention; start the gate after helper handshakes finish.
- No Android release build runs before the tag: ARM64 hosts cannot build release APKs and `ci.yml` builds only debug, which skips release-only tasks such as `lintVitalAnalyzeRelease` and R8 (v2.11.0 never published because AGP 9.3.1's lint crashed on JDK 17). Until #528 adds a release build to CI, when a release changes the Android toolchain (AGP, Gradle, KGP or the pinned Flutter SDK), push `main`, run `gh workflow run release.yml --ref main -f dry_run_version=X.Y.Z`, and cut the tag only after that dry run is green. Waiting for this run is the one exception to `CI: never watch it`: wait in a single background command, with no polling turns.
- The Linux preview smoke (`tool/ci/smoke_v2_linux_preview.py`, CI job `v2_native_builds (linux)`) reads real on-screen labels and walks the empty workspace, Servers and the add screen, and Settings (Appearance, Shortcuts, App Logs, Version and updates, Release history). `make check` does not run it. A unit that changes those labels, buttons or navigation updates the smoke in the same unit (v2.12.0 left `main` red by keeping the removed "Pair a server" step). On `mercury`, build in a fresh clone (the build refuses an existing `build/linux`) and check only the changed steps; later steps are unreliable on ARM64 Xvfb, so CI proves the rest.
- When a release job fails with "The job was not acquired by Runner", it is GitHub runner capacity, not code (v2.12.0's macOS build). First offer `gh run rerun <id> --failed` on the same tag, which publishes that version without a new one; cut a patch only if the owner prefers it or the rerun fails again.

## Keeping this file current

- At the end of a unit, when something changed or must be known by every later session (a new rule, a removed or moved fact, a recurring pitfall), recommend the exact update to this file in the final message, and add it only after the owner approves.
