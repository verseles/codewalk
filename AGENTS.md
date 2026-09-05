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

## Required Context

- Read `BEHAVIOR.md` before substantial planning.
- For behavior changes, verify ADR-023 alignment first using `ADR.md` and local official OpenCode anchors:
  `ai-docs/opencode_server.md`, `ai-docs/opencode_web.md`, and `ai-docs/opencode_models.md`.
- For new features or bug fixes, also inspect `https://github.com/openchamber/openchamber` as a secondary community reference. It must never override official OpenCode docs/source.
- For OpenCode or OpenChamber source-code investigation, do not use the `researcher` subagent. Inspect GitHub URLs, raw files, commits, pull requests, and code directly with GitHub/URL tools.
- If a behavior change cannot align with ADR-023, it is blocked unless an explicit ADR exception documents rationale, risk, rollback/feature flag, and regression tests.

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
3. Ask at least one decision question. Present options such as A, B, or C and make the answers easy to provide—for example: `1C, 2D, 3A`. (Mandatory.)
4. Implement the changes.
5. Run focused validation while iterating. Once the code is stable, run `make check` once.
6. Commit the changes.
7. Run the reviewer loop on the commit.
8. Apply only judge-approved fixes. Validate them with focused checks by default, and repeat the review when warranted.
9. Evaluate the helpers used, identifying the best and worst, the essential and dispensable ones, the top two and bottom two, and any honorable mentions. Also send a full paragraph about, via hey.
10. Run `HEY_CAPTION="specific caption" make android` when an APK is useful and supported. Do not run it for ARM64 targets.
11. Update the documentation.
12. Create a minor release unless instructed otherwise. Monitor it every 60 seconds with `cimonitor`.
13. Notify the user and provide the final report, including the helper evaluation.
    13.1. Ask whether any related issue should be closed. When useful, suggest the next task from GitHub Issues.
    13.2. When relevant, ask whether the rules in `./AGENTS.md` should be updated to reflect the changes or introduce new rules.
    
## Release

- New versions use `make release V=patch|minor|major`.
- The release command updates `pubspec.yaml`, commits, creates a `vX.Y.Z` tag, and pushes.
- Ensure all code changes are committed before release. `make release` only commits the version bump.
- Plain `push` is not a release and must not invoke `releaser`.
- After release push/tag, CI watch belongs to `cimonitor`; `releaser` does not monitor CI.


## Known Pitfalls

- `dart tool/i18n/generate_arb.dart` is destructive to newer `.arb` keys. Never run it globally unless `arb_strings.dart` is synchronized with every existing key.
- Safe translation workflow: generate missing-key payload, translate it, then merge back with `tool/i18n/merge_back_translations.py`.
- Non-interactive shells do not always source `.bashrc`/`.zshrc`; prepend `export PATH="$HOME/flutter/bin:$PATH"` before Flutter commands in main-agent and subagent contexts.