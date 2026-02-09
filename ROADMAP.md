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
Description: Build an objective baseline of the current fork (code, docs, endpoints, tests, platform support) and define hard safety rails before touching implementation.

Completed a full baseline inventory of source/runtime/docs/platform state, defined deletion and retention policies for generated and markdown artifacts, and established rollback checkpoints plus dependency and acceptance-gate governance for all later features.
Commits: b9de67f, 7d7e6f6, 3640fb2, d307731, c96f53c

### Feature 002: Licensing Migration to AGPLv3 + Commercial (>500M Revenue)
Description: Replace MIT with a compliant AGPLv3 setup and add a separate commercial license track for organizations above the revenue threshold.

Completed legal migration from MIT to AGPLv3, added a dedicated commercial license track for organizations above the revenue threshold, published attribution/warranty notices, and validated dependency licensing compatibility with unresolved decisions documented.
Commits: 2b51dd3, f0bc342, 898889f, b5e1719, a25cb31

### Feature 003: Rebrand OpenMode -> CodeWalk (Code, Package IDs, Metadata)
Description: Rename all product-facing and package-level identifiers from OpenMode/open_mode to CodeWalk/codewalk across app runtime, build metadata, and distribution assets.

Completed product and package rebranding from OpenMode to CodeWalk across Flutter metadata, source imports, Android namespace/applicationId, and web manifest/title/PWA references, followed by smoke validation to catch rename regressions.
Commits: 9483801, ede3939, a519f8f, 63549d4

### Feature 004: Full English Standardization (UI, Code Comments, Docs)
Description: Translate all remaining non-English content to English, including user-facing strings, comments, logs, and technical documentation.

Completed English standardization for UI strings, runtime messaging, source comments, and retained technical docs. Automated language regression checks were intentionally marked as a wont-do based on product decision.
Commits: 1bc9184

### Feature 005: Documentation Restructure and Markdown Pruning
Description: Remove unnecessary markdown files, consolidate surviving docs, and rewrite README with explicit origin attribution to OpenMode.

Completed documentation triage and consolidation by classifying markdown assets, merging unique technical history into `CODEBASE.md`, rewriting `README.md` for the CodeWalk identity with origin attribution, and pruning redundant files without knowledge loss.
Commits: 8562850, 7c72e70, b219a2b, d02f486

### Feature 006: OpenCode Server Mode API Refresh and Documentation Update
Description: Align the client and internal API docs with the latest OpenCode Server Mode endpoints/schemas and close compatibility gaps.

Completed a full Server Mode compatibility refresh through endpoint gap mapping, model/datasource/use-case updates for schema drift, and replacement of obsolete integration docs with a versioned guide; validated live against `100.68.105.54:4096` across provider, session, event, and message paths including nested-model parsing fixes.
Commits: e994f39, bbadbe4, 78acc18, ad6470c

### Feature 007: Cross-Platform Desktop Enablement and Responsive UX
Description: Expand project target platforms beyond mobile and deliver a true cross experience for desktop/web/mobile with adaptive layouts and desktop-native interactions. (Visit file ROADMAP.feat007.md for full research details)

- [x] 7.01 Add desktop platforms (Windows/macOS/Linux) to Flutter project - Enabled desktop flags and generated `linux/`, `macos/`, `windows/` via Flutter tooling
- [x] 7.02 Implement responsive layout breakpoints (mobile drawer vs desktop split view) - `ChatPage` now adapts with mobile drawer (`<840`), split desktop (`>=840`), and large-desktop utility panel (`>=1200`)
- [x] 7.03 Add desktop input ergonomics (shortcuts, hover/focus polish, resize behavior) - Added `Ctrl/Cmd+N`, `Ctrl/Cmd+R`, `Ctrl/Cmd+L`, `Esc`; external input focus control; desktop hover/cursor polish in session list
- [/] 7.04 Validate build/run on each target and document platform-specific caveats - Linux/web validation passed (`flutter test`, `flutter build linux`, `flutter build web`, Linux runtime smoke). Blocked for full target matrix by host OS constraint (`flutter build windows` requires Windows host, `flutter build macos` requires macOS host)

### Feature 008: Manual QA Campaign and Stability Hardening
Description: Execute a structured manual test campaign across supported platforms and critical user journeys, then fix high-impact defects before automation is expanded.

Completed a structured QA campaign with defined matrix and scenario IDs, executed scripted smoke coverage against live server flows, fixed P1 defects (secure logging leak and Android AGP build blocker), and published release readiness with known limitations.
Commits: da2940b, cc5c78f

### Feature 009: Automated Test Suite and CI Quality Gates
Description: Build comprehensive automated tests (unit, widget, integration) and enforce quality gates in CI so future changes remain stable.

Implemented a layered automation baseline with unit tests for model parsing/use case delegation/provider state transitions, widget tests for responsive chat shell and send-message flow, and integration tests against a controllable local mock OpenCode server including session CRUD, app/provider bootstrap calls, SSE message updates, and 400 validation error mapping. Added CI workflow gates for phased static analysis budget, full test execution with coverage generation, and minimum coverage threshold enforcement scripts, plus a race-condition fix in chat SSE handling so pending message fetches are not dropped when the event stream closes.
Commits: 5125edd

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
