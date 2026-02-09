---
roadmap: "CodeWalk Solo Migration Roadmap"
created_on: "2026-02-09"
execution_mode: "feature-by-feature"
source_project: "https://github.com/easychen/openMode"
---

## Execution Protocol

1. Trigger command pattern: `implement feat XXX now` (example: `implement feat 006 now`).
2. During execution:
   - mark active tasks as `[~]`,
   - mark completed tasks as `[x]`,
   - mark blocked tasks as `[/]` with blocker reason.
3. Complete all tasks in `ROADMAP.featXXX.md` before moving to the next feature unless a blocker is explicit.
4. After full completion of a feature, summarize implementation in `ROADMAP.md` and keep only necessary long-form notes.

## Task List

### Feature 001: Baseline Audit, Safety Rails, and Deletion Policy
Description: Build an objective baseline of the current fork (code, docs, endpoints, tests, platform support) and define hard safety rails before touching implementation. (Visit file ROADMAP.feat001.md for full research details)

- [x] 1.01 Capture baseline inventory (files, naming, endpoints, locale, platform folders, lint/test status)
- [x] 1.02 Define keep/remove rules for documents and generated artifacts
- [x] 1.03 Define rollback checkpoints and branch strategy for solo execution
- [x] 1.04 Publish feature dependency map and acceptance gates for all next features

### Feature 002: Licensing Migration to AGPLv3 + Commercial (>500M Revenue)
Description: Replace MIT with a compliant AGPLv3 setup and add a separate commercial license track for organizations above the revenue threshold. (Visit file ROADMAP.feat002.md for full research details)

- [x] 2.01 Replace root LICENSE with GNU AGPLv3 text and SPDX metadata updates - Commit: f0bc342
- [x] 2.02 Add `LICENSE-COMMERCIAL.md` with the >500M revenue trigger and commercial terms - Commit: 898889f
- [x] 2.03 Add legal notices (`NOTICE`, attribution, warranty limitations, contact path) - Commit: b5e1719
- [x] 2.04 Validate dependency/license compatibility and document unresolved legal decisions - Commit: a25cb31

### Feature 003: Rebrand OpenMode -> CodeWalk (Code, Package IDs, Metadata)
Description: Rename all product-facing and package-level identifiers from OpenMode/open_mode to CodeWalk/codewalk across app runtime, build metadata, and distribution assets. (Visit file ROADMAP.feat003.md for full research details)

- [x] 3.01 Rename app/package identifiers (`pubspec`, imports, app constants, test imports) - Commit: ede3939
- [x] 3.02 Rename Android package namespace/applicationId and Kotlin package path - Commit: a519f8f
- [x] 3.03 Update web metadata (manifest, title, PWA labels) and asset references - Commit: 63549d4
- [x] 3.04 Run compile/lint smoke checks after rename to catch broken references

### Feature 004: Full English Standardization (UI, Code Comments, Docs)
Description: Translate all remaining non-English content to English, including user-facing strings, comments, logs, and technical documentation. (Visit file ROADMAP.feat004.md for full research details)

- [x] 4.01 Convert all UI strings and runtime errors/log messages to English
- [x] 4.02 Translate non-English comments/docblocks in `lib/` to concise technical English
- [x] 4.03 Translate technical markdown that must be kept after cleanup
- [!] 4.04 Add a language consistency check step to prevent regressions - Won't do (user decision: unnecessary)

### Feature 005: Documentation Restructure and Markdown Pruning
Description: Remove unnecessary markdown files, consolidate surviving docs, and rewrite README with explicit origin attribution to OpenMode. (Visit file ROADMAP.feat005.md for full research details)

- [x] 5.01 Classify markdown docs into keep/merge/delete buckets
- [x] 5.02 Merge unique content from historical docs into CODEBASE.md
- [x] 5.03 Rewrite `README.md` for CodeWalk and add explicit acknowledgment to original project
- [x] 5.04 Delete redundant `.md` files and verify no critical knowledge was lost

### Feature 006: OpenCode Server Mode API Refresh and Documentation Update
Description: Align the client and internal API docs with the latest OpenCode Server Mode endpoints/schemas and close compatibility gaps. (Visit file ROADMAP.feat006.md for full research details)

- [x] 6.01 Build endpoint-by-endpoint gap matrix (current client vs latest docs)
- [x] 6.02 Update models/datasources/use cases for schema and endpoint drift
- [x] 6.03 Replace outdated API docs with a versioned Server Mode integration guide
- [x] 6.04 Validate chat/session/provider flows against a real server instance - Completed on 2026-02-09 against `100.68.105.54:4096`: `/path`, `/provider`, `/session`, `/event`, create/update/delete/summarize, and assistant message flow validated after compatibility fixes for nested `model` payload and message parsing

### Feature 007: Cross-Platform Desktop Enablement and Responsive UX
Description: Expand project target platforms beyond mobile and deliver a true cross experience for desktop/web/mobile with adaptive layouts and desktop-native interactions. (Visit file ROADMAP.feat007.md for full research details)

- [x] 7.01 Add desktop platforms (Windows/macOS/Linux) to Flutter project - Enabled desktop flags and generated `linux/`, `macos/`, `windows/` via Flutter tooling
- [x] 7.02 Implement responsive layout breakpoints (mobile drawer vs desktop split view) - `ChatPage` now adapts with mobile drawer (`<840`), split desktop (`>=840`), and large-desktop utility panel (`>=1200`)
- [x] 7.03 Add desktop input ergonomics (shortcuts, hover/focus polish, resize behavior) - Added `Ctrl/Cmd+N`, `Ctrl/Cmd+R`, `Ctrl/Cmd+L`, `Esc`; external input focus control; desktop hover/cursor polish in session list
- [/] 7.04 Validate build/run on each target and document platform-specific caveats - Linux/web validation passed (`flutter test`, `flutter build linux`, `flutter build web`, Linux runtime smoke). Blocked for full target matrix by host OS constraint (`flutter build windows` requires Windows host, `flutter build macos` requires macOS host)

### Feature 008: Manual QA Campaign and Stability Hardening
Description: Execute a structured manual test campaign across supported platforms and critical user journeys, then fix high-impact defects before automation is expanded. (Visit file ROADMAP.feat008.md for full research details)

- [x] 8.01 Define manual test matrix (platform x feature x network condition) - Matrix, severity model, and scenario IDs QA-001..QA-007 documented in `ROADMAP.feat008.md`
- [x] 8.02 Execute exploratory and scripted scenarios, recording reproducible evidence - Executed QA smoke script (`tool/qa/feat008_smoke.sh`) against `100.68.105.54:4096` with pass results and artifact logs under `/tmp/codewalk_feat008/*`
- [x] 8.03 Triage and fix P0/P1 defects before exit - Fixed P1 secure logging leak in `dio_client.dart` and P1 Android build blocker (AGP `8.9.1`)
- [x] 8.04 Publish a release readiness report with known limitations - Report published in `QA.feat008.release-readiness.md`

### Feature 009: Automated Test Suite and CI Quality Gates
Description: Build comprehensive automated tests (unit, widget, integration) and enforce quality gates in CI so future changes remain stable. (Visit file ROADMAP.feat009.md for full research details)

- [ ] 9.01 Create unit tests for data mapping, providers, and use cases
- [ ] 9.02 Create widget tests for chat flows and responsive behavior
- [ ] 9.03 Create integration tests with a controllable mock OpenCode server
- [ ] 9.04 Add CI pipeline with `analyze`, tests, and coverage thresholds

## Dependency Order

1. Feature 001 -> blocks all other features (baseline + safety rails)
2. Feature 002 -> should finish before publishing docs/release artifacts
3. Feature 003 -> should happen before broad documentation rewrites
4. Feature 004 -> should happen before final markdown pruning
5. Feature 005 -> should happen before API documentation refresh
6. Feature 006 -> should happen before desktop/manual/automation validation
7. Feature 007 -> should happen before full manual QA campaign
8. Feature 008 -> should happen before final CI quality thresholds
9. Feature 009 -> closes roadmap and enables long-term maintainability

## Legend

- [x] Done
- [~] In progress now
- [/] Partially done but blocked
- [!] Won't do (with reason)
- [ ] Not started

## Acceptance Gates

| Feature | Entry Gate | Exit Gate |
|---------|-----------|-----------|
| 001 | None | CODEBASE.md + Makefile + doc classification + ADR + gates defined |
| 002 | 001 complete | LICENSE AGPLv3 + LICENSE-COMMERCIAL.md + NOTICE + dep compatibility verified |
| 003 | 002 complete | All IDs renamed + `flutter analyze` no new errors + smoke test build |
| 004 | 003 complete | Zero CJK strings in `lib/` + `flutter analyze` clean |
| 005 | 004 complete | README rewritten + docs consolidated + no orphan MD files |
| 006 | 005 complete | Gap matrix closed + models updated + validated against real server |
| 007 | 006 complete | Desktop builds OK + responsive layout + keyboard shortcuts working |
| 008 | 007 complete | Test matrix executed + P0/P1 fixed + readiness report published |
| 009 | 008 complete | Unit/widget/integration tests + CI pipeline + coverage thresholds |
