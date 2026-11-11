# CodeWalk Project Rules

> General rules from the main `AGENTS.md` apply. This file holds only CodeWalk-specific rules and overrides.

## Owner commands

The owner is short on time. These orders are enough; do not ask for routine technical choices.

| Order | What the agent does |
|---|---|
| `avançar` / `continuar` | Resumes unfinished work, otherwise runs the first open line of `ROADMAP.md`, from issue to push. No beta. |
| `avançar N` | Runs the next N lines, one review boundary each. No beta. |
| `beta` | Publishes the next `v2.0.0-beta.N`. Never happens without this order. |
| `apk` | Builds the Android APK here and sends it to `@VerselesBot`. No version, no tag. |
| `status` | Reports the next lines of the queue, local state and the latest runs, with at most one `gh` call. |
| `prioriza #N` | Moves that line to the top of `ROADMAP.md`. |
| `adiciona: <ideia>` | Creates the Issue under `gh-helper` and adds its line to the fitting block. |

Ask only for a product decision or a required human action, with lettered options and a recommendation. Findings outside the current line become an Issue plus a line in the queue, never scope growth.

## Sources of truth

- `ROADMAP.md`: the order of work and the only file the owner needs to read.
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
- Pixel-level visual parity with v1 is not a goal (owner, 2026-11-05).

## `avançar`, unit by unit

1. Read the Issue and apply the v1 filter. Load `planner` only under its triggers: architectural impact, broad cross-module scope, consequential tradeoffs or an explicit request.
2. Implement. While iterating, use the narrowest validation: focused tests and targeted `flutter analyze <paths>`.
3. Commit the stage as the review boundary, with only intended files plus the `.task-memory/` snapshot.
4. In parallel, run the local gate and all eligible reviewers under the `reviewer` skill.
5. Judge the reports and apply the accepted findings in one commit. Re-review only when the fixes touch concurrency, security, interfaces, persistence or architecture; otherwise validate them with focused checks.
6. Update `BEHAVIOR.md` and the Issue, delete the line from `ROADMAP.md`, and squash the loop under the general conditions.
7. `git push origin main`, then `make watch-ci`, then finish with a `hey` stating the outcome and next line.

A blocked line stays in place with its blocker noted; take the next line that does not depend on it, or report the pending owner action.

## `beta`

1. Rewrite `release-notes/v2-beta.md` for this beta: what changed since the previous beta tag, led by one `> 📣` line in English of at most 300 characters. Ask for approval as soon as the beta is ordered, before the gate or any remaining work, so the owner can answer while it runs. When the beta waits on work still in progress, draft the notes from its planned scope, and ask again only if the delivered scope changes them. Never cut a beta with stale or unapproved notes. Commit them before the release, which reads them from the tag; a notes-only commit needs no new gate.
2. Require a clean tree, `main == origin/main`, and a green local gate on that exact SHA. Never run the release in parallel with the gate.
3. `make release V=beta`: bumps the version, commits, creates the tag and pushes atomically. A dry run is `DRY_RUN=1`.
4. `make watch-release`, then finish with a `hey`. The Release workflow builds, verifies and publishes on its own in about 12 minutes.
5. Red run: fix it and cut `beta.N+1`; a published tag never moves. Stable and GA releases need their own explicit order.

The normal delivery of a beta is the in-app Beta channel. Send an APK link only for a first install, a recovery, or a device without the updater.

## CI: never watch it

This overrides the general `cimonitor` and 60-second rechecks in this project. Tokens must not be spent on something that runs by itself.

- `make watch-ci` and `make watch-release` start a detached script with no agent. It waits for the run of the current commit and reports through `hey`: CI only on failure, Release always.
- After starting a watcher, end the turn. Do not use `cimonitor` or `gh run watch`, and do not poll.
- Look at CI only when `status` is ordered, when a failure was reported, or at the start of the next unit after a reported failure.
- The local gate decides whether a commit is ready. CI is a safety net.

## `apk`: send a test build through `tdl`

This host (x86_64, 20 threads) builds faster than CI. A test APK is not a release: no version bump, no tag, and the updater is not involved. `hey -f` cannot deliver it because the APK exceeds the Telegram Bot API upload limit.

```bash
export PATH="$HOME/flutter/bin:$PATH"
flutter build apk --release --target lib/main_v2.dart --target-platform android-arm64 --split-per-abi --build-number "$(date +%s)"
```

- Do not pass `--no-pub`: the build then keeps dev plugins in the registrant and fails. Without `--split-per-abi` the APK grows from about 90 MB to about 148 MB.
- `--build-number` keeps the versionCode above the installed one, so Android accepts the update, and below the next beta, whose number also comes from the clock.
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
- `v1` is frozen, except the final stable `v1.266.0` with Windows and macOS. Check the branch before editing, and never merge whole trees between lines.
- v2 betas ship Android arm64 and Linux x64/arm64. Web, iOS, Windows and macOS come later in the queue. v2 does not import v1 data.
- #476 removed the v1-only dependencies. Each returns only with the v2 feature that uses it: voice #307, notifications and tray #309 (`tray_manager`), terminal #291 (`xterm`), Tailscale #317, and `window_manager` with the desktop window #474.

## Web origins

- Stable v1 Web: `https://codewalk.pages.dev`. `main` preview: `https://main.codewalk.pages.dev`.
- A local change reaches Pages only after a push and a successful deployment. Compare the deployment commit with `origin/main` before validating; an app version or an HTML 200 is not commit evidence.
- Revalidate this section whenever origins, routing or deployment change.

## Contract

- Read `BEHAVIOR.md` before substantial planning.
- Behavior changes follow ADR-023 (contract first) and ADR-058, anchored on `ai-docs-for-opencode-v2/opencode_v2_server.md`, `opencode_v2_web.md` and `opencode_v2_models.md`. The v1 anchors `ai-docs/opencode_*.md` live on the `v1` branch and do not constrain v2.
- The official OpenCode clients `https://github.com/anomalyco/opencode/tree/dev/packages/cli` and `https://github.com/anomalyco/opencode/tree/dev/packages/app` are the crucial reference for the most correct way to use the v2 API and events. Check how they do it before implementing or changing API calls or event handling.
- Consult `https://github.com/openchamber/openchamber` only when the official contract is ambiguous; it never overrides official docs or source.
- For OpenCode or OpenChamber source, inspect GitHub URLs, raw files, commits and pull requests directly, not through the `researcher` subagent.
- A behavior that cannot align with the official contract is blocked unless an ADR exception documents rationale, risk, rollback or flag, and regression tests.

## Validation

- Prepend `export PATH="$HOME/flutter/bin:$PATH"` to Flutter commands in every shell.
- The local gate is `make check TEST_JOBS=$(nproc)`, plus `make v2-native-check` when `packages/`, the architecture rules or the CHP changed. Run it once the code is stable.
- Do not use `make precommit`. After reviewer micro-fixes, use focused checks; rerun the gate only when a fix touches shared infrastructure, dependencies, generated files, l10n or build configuration.
- Static text and docs changes need no gate unless they affect build or release instructions.
- Golden references are x86_64 renders. `test/flutter_test_config.dart` accepts up to 0.01% differing pixels, so ARM64 passes the same goldens (#465); larger drift still fails. APKs do not build reliably on ARM64.
- Coverage floor: 85% of app lines under `lib/`, plus the file floors in `tool/ci/coverage_baseline.tsv`. Package coverage is not gated yet (#477). Never lower a floor to get a green check.

## Helper budget

- Each planning or review helper has a hard 45-minute limit. With the unified runner, use `--timeout 2690` under a 2700-second outer limit, and terminate the owned process groups at the deadline.
- When another helper or usable report exists, ignore a timed-out helper for that round, without retry or replacement, and record it as a technical failure. Resume it only when nothing else is available.
- All other participation, Task Memory, judgment and validation rules stay in force. CI and test budgets are not affected.

## Releases on `main`

- `make release` accepts only `V=beta`. Betas never write `CHANGELOG.md`, because installed v1 apps parse it with stable headings only.
- `make release` commits only the version bump, so commit all code first. A plain `push` is not a release.
- Keep `CHANGELOG.md` machine-readable: unique `## vX.Y.Z - YYYY-MM-DD` headings, newest first, `###` for subsections. Each release may have one leading `> 📣` line in English, up to 300 characters. Preserve prior sections.
- Release rules for v1 live in the `AGENTS.md` of the `v1` branch.

## Known pitfalls

- Workmanager 0.10 may run real `systemctl` commands in Linux tests that default to Android. Use a no-op fake or select the test platform explicitly, restoring it in teardown.
- Translations: change only the needed keys, keep ARB and generated code in sync, and inspect the diff after any regeneration for unintended removals.
- If `/tmp` is full, export `TMPPREFIX`, `TMPDIR`, `TEMP` and `TMP` to a directory with space on the same filesystem instead of deleting other processes' files.
- After `dart format`, inspect the hunks and revert churn outside the intended change; reformatting other code goes in its own commit, never mixed with a feature or fix.

## Keeping this file current

- At the end of a unit, when something changed or must be known by every later session (a new rule, a removed or moved fact, a recurring pitfall), recommend the exact update to this file in the final message, and add it only after the owner approves.
