# CodeWalk Project Rules

> More general rules from the main `AGENTS.md` apply. This file contains only CodeWalk-specific overrides and context.

## Tracking

- GitHub Issues are the canonical tracker for planned work, follow-ups, acceptance criteria, and next tasks.
- Do not recreate `ROADMAP.md`; it was removed intentionally.

## Project Context

- CodeWalk is a mobile and desktop client for OpenCode.
- Design and implementation must work on both mobile and desktop. Prioritize mobile UX, Material You, and responsive layouts.
- For visual changes, confirm the exact screen/block before editing if the request is ambiguous.
- After completing a change, decide whether tests need adding or updating.
- Use descriptive commit messages when committing project work.

## Version Lines and Branches

- **`v1` is the legacy CodeWalk 1 / OpenCode 1 maintenance branch.** Implement v1 fixes and the final transition minor there, then bounded patches until the product owner accepts the usable v2 MVP. After that acceptance, freeze routine v1 development/releases; retain the legacy branch and downloads.
- **`main` is the CodeWalk v2 migration/development line.** It currently retains the v1 source, assets, tests, and build tooling as a temporary reference/reuse baseline alongside `v2-plan.md`; this is not an implemented v2 client. Build the new skeleton and port reusable pieces selectively. Remove superseded v1 code only as validated replacements land and complete the final cutover; do not empty `main` to leave only planning files.
- Check the active Git branch before editing. A checkout on `v1` means legacy work; the presence of `v2-plan.md` does not authorize implementing the v2 rewrite there. Keep `BEHAVIOR.md`, `CODEBASE.md`, and official contract anchors aligned with the implementation of the active line. Use `main` for v2 work unless the user explicitly directs otherwise; remain on `v1` when that checkout is requested.
- Do not merge the complete rewritten v2 tree into `v1`, or routinely merge legacy maintenance into `main`. Port only relevant fixes/shared installer changes individually and validate them on each affected line. Keeping source available for reuse does not authorize a v1/v2 runtime compatibility switch.
- Before publishing rewritten v2 code from `main`, implement and verify the production-Web/preview split in `V1-04`. v2 betas are opt-in prereleases, not the public stable channel. The v1 freeze at MVP and the v2 GA promotion are separate milestones; follow `v2-plan.md` for the transition gates.

## Required Context

- Read `BEHAVIOR.md` before substantial planning.
- For behavior changes, identify the implementation line and verify ADR-023's contract-first principle using `ADR.md`. New v2-authored behavior uses ADR-058 and the versioned official OpenCode anchors `ai-docs/opencode_v2_server.md`, `ai-docs/opencode_v2_web.md`, and `ai-docs/opencode_v2_models.md`. v1 maintenance and retained legacy reference paths (including legacy code still on `main`) use the original anchors `ai-docs/opencode_server.md`, `ai-docs/opencode_web.md`, and `ai-docs/opencode_models.md`, plus their applicable v1-specific invariants. Legacy details such as `local_user_*`, `prompt_async`, `/provider.connected`, and dual-SSE behavior do not constrain authored v2.
- For new features or bug fixes, also inspect `https://github.com/openchamber/openchamber` as a secondary community reference. It must never override official OpenCode docs/source.
- For OpenCode or OpenChamber source-code investigation, do not use the `researcher` subagent. Inspect GitHub URLs, raw files, commits, pull requests, and code directly with GitHub/URL tools.
- If a behavior change cannot align with the applicable official contract under ADR-023, it is blocked unless an explicit ADR exception documents rationale, risk, rollback/feature flag, and regression tests.

## Documentation

- `BEHAVIOR.md` documents current implemented behavior only.
- `ADR.md` stores architecture decisions. Use `adrkeeper`/ADR flow for ADR updates.
- `CODEBASE.md` stores structure, entry points, core modules, and command map. Use `codemapper`/CODEBASE flow for structural updates.
- Avoid duplicating ADR/CODEBASE line maps in this file.

## Commands

- Do not use `make precommit` directly for normal CodeWalk validation. Prefer `make check` and `make android` separately.
- During implementation, prefer the narrowest useful validation: focused unit/widget tests, targeted `flutter analyze <paths>`, or package-specific checks for the files changed.
- Run `make check` only at validation gates: after the code is stable and before the first code commit, before release/push when no current passing `make check` covers the final code state, or after broad/cross-cutting changes that targeted checks cannot cover.
- After reviewer-requested micro-fixes, do not automatically rerun `make check`; run focused validation for the touched area, and rerun `make check` only when the fix changes shared infrastructure, dependencies, generated files, l10n, build configuration, or otherwise invalidates the prior full check.
- If only static text/docs changed, `make check` and `make android` are not required unless the edit affects build/release instructions.
- For Flutter/Dart commands in main-agent and subagent shells, prepend `export PATH="$HOME/flutter/bin:$PATH" && ...` because non-interactive shells may not have the Flutter SDK on `PATH`.
- When the user needs a testable Android build, run `HEY_CAPTION="specific caption" make android` after checks pass.
- Use a specific upload caption. Avoid generic captions like `Latest adjustments made`.
- Android APK builds do not work reliably on ARM64 Linux hosts; use GitHub Actions for release APKs. `make check` works on ARM64.

## Tester Subagent

- The `tester` subagent must execute the delegated test command exactly once, wait for that process to finish, read its result once, and respond immediately.
- The `tester` must never rerun a command because output appears incomplete, truncated, ambiguous, or difficult to interpret. It must report the result as inconclusive and stop.
- Only a new explicit delegation from the main agent may authorize another test execution.

## Explicit `flow` Request

When the user explicitly asks for `flow`, follow this order, but adapting the user order:

1. If needed, ask the user clarifying questions. (Optional.)
2. Plan the changes using the available planning tools.
3. Ask at least one decision question. Present options such as A, B, or C and make the answers easy to provide—for example: `1C, 2D, 3A`. (Mandatory.) In the same round, propose the release announcement text in English (`ANNOUNCE`) for the final minor release and ask whether the user agrees — never ship release text the user has not approved.
4. Implement the changes.
5. Run focused validation while iterating. Once the code is stable, run `make check` once.
6. Commit the changes.
7. Run the reviewer loop on the commit.
8. Apply only judge-approved fixes. Validate them with focused checks by default, and repeat the review when warranted.
9. Evaluate the helpers used, identifying the best and worst, the essential and dispensable ones, the top two and bottom two, and any honorable mentions. Also send a full paragraph about, via hey.
10. Run `HEY_CAPTION="specific caption" make android` when an APK is useful and supported. Do not run it for ARM64 targets.
11. Create a minor release unless instructed otherwise. On `v1`, the transition minor is the last planned minor; subsequent maintenance uses patches only until the accepted v2 MVP, then routine v1 releases stop. Monitor releases every 60 seconds with `cimonitor`.
12. Update the documentation of the project while monitor release. Commit doc updates but not push.
13. Notify the user and provide the final report, including the helper evaluation.
    13.1. Ask whether any related issue should be closed. When useful, suggest the next task from GitHub Issues.
    13.2. When relevant and evergreen, ask whether the rules in `./AGENTS.md` should be updated to reflect the changes or introduce new rules.
    
## Release

- New versions use `make release V=patch|minor|major`.
- The release command updates `pubspec.yaml` and `CHANGELOG.md`, commits, creates a `vX.Y.Z` tag, and pushes.
- Optional release announcement: `ANNOUNCE="text" make release V=minor`, or answer the one-line TTY prompt (empty skips; never blocks CI).
- The announcement ships as a `> 📣` block at the top of the version section and surfaces in-app as What's-new.
- Keep `CHANGELOG.md` machine-readable for in-app release history: use unique `## vX.Y.Z - YYYY-MM-DD` headings, newest releases first. Reserve `##` headings for releases; use `###` for subsections.
- Each release may have one optional leading `> 📣` announcement, on a single line in English with at most 300 characters. Releases without an announcement are valid. Preserve prior sections and their original announcement text; verify the archive parser tests when changing the format or generator.
- Ensure all code changes are committed before release. `make release` only commits the version bump.
- Plain `push` is not a release and must not invoke `releaser`.
- After release push/tag, CI watch belongs to `cimonitor`; `releaser` does not monitor CI.
- Close flow issues only after the release CI is green, commenting version + commit.


## Known Pitfalls

- In Flutter tests on Linux, Workmanager 0.10 may execute real systemd/`systemctl` commands when the test target defaults to Android. For platform-independent tests that toggle Android-backed settings, use a no-op Workmanager fake or explicitly select the appropriate test platform, and restore any platform override in teardown; do not mask Android-specific behavior tests.
- Translations: for targeted changes, modify only the necessary keys, preserving existing messages and metadata. Keep the catalog, ARB files, and generated code synchronized. Before a full regeneration, verify that the sources contain every current key; afterward, inspect the diff for unintended removals or changes.
- Non-interactive shells do not always source `.bashrc`/`.zshrc`; prepend `export PATH="$HOME/flutter/bin:$PATH"` before Flutter commands in main-agent and subagent contexts.
- If `/tmp` is full and shell heredocs or git temp-files fail, export `TMPPREFIX=/home/ubuntu/.tmp/zsh_ TMPDIR=/home/ubuntu/.tmp TEMP=/home/ubuntu/.tmp TMP=/home/ubuntu/.tmp` (same-filesystem dir with space) for the command instead of deleting other processes' files.
- After running `dart format`, inspect the diff hunks and revert unrelated formatter churn outside the intended change so commits stay minimal and reviewable.
