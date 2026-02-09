# Feature 001 - Baseline Audit, Safety Rails, and Deletion Policy

## Goal
Create a factual baseline of the fork so every next feature can be executed safely, with rollback points and clear scope boundaries.

## Why This Is First
Every requested change (license, renaming, API migration, desktop support, testing) is broad and cross-cutting. Without a baseline, regressions and accidental deletions become very likely.

## Scope
- Repository inventory and risk classification
- Baseline quality snapshot (analyze/test)
- Documentation retention policy (what can be removed, what must survive)
- Feature dependency graph and execution gates

## Out of Scope
- Actual implementation changes for license/rebrand/API/layout/testing

## Current Findings (2026-02-09)
- Markdown files currently present: 5 (`README.md`, `DEV.md`, `CHAT_API_ANALYSIS.md`, `BUGFIX_SUMMARY.md`, `AI_CHAT_IMPLEMENTATION.md`).
- Non-English content is extensive: 38 files under `lib/` contain CJK text.
- Platform folders present: `android`, `web`; missing: `ios`, `windows`, `macos`, `linux`.
- Legacy naming appears in runtime/build metadata (`open_mode`, `OpenMode`, Android namespace, web manifest, test import).
- Baseline tooling:
  - `flutter --version`: 3.38.9 (stable)
  - `flutter analyze`: fails with 167 issues (warnings/info; no blocker-level fix attempted here)
  - `flutter test`: fails (default counter test not compatible with current app bootstrap/DI)

## Implementation Stages

### Stage 1 - Baseline Snapshot
- Capture counts and paths for docs, locales, platform targets, and branding references.
- Capture current API endpoint usage from data sources.
- Save baseline command outputs for comparison after each feature.

### Stage 2 - Deletion Safety Rules
- Define file classes:
  - Runtime critical: never delete without replacement.
  - Historical reference: merge then delete.
  - Disposable: delete once equivalent content exists elsewhere.
- Define rollback strategy (`git` checkpoints per feature).

### Stage 3 - Feature Execution Gates
- Define entry/exit criteria per feature (build/test/docs checks).
- Define strict dependency order (no skipping hard prerequisites).

### Stage 4 - Handoff-Ready Format
- Ensure each feature doc is executable as a standalone work packet.
- Ensure command trigger clarity: "implement feat XXX".

## Deliverables
- `ROADMAP.md` with ordered features and dependencies
- `ROADMAP.feat001.md` to `ROADMAP.feat009.md` fully populated
- Baseline metrics embedded in relevant feature docs

## Risks and Mitigations
- Risk: accidental deletion of important knowledge from markdown cleanup.
  - Mitigation: classify docs first, merge before delete, require grep-based references check.
- Risk: noisy baseline obscures true regressions.
  - Mitigation: store exact baseline failures and compare deltas only.

## Definition of Done
- Baseline metrics documented and reproducible
- Deletion and rollback rules agreed in roadmap artifacts
- Every downstream feature has explicit prerequisites and acceptance criteria

## Research Log

### Local Research
- Repository scan via `rg --files`, `rg --files -g '*.md'`, and naming searches.
- Endpoint extraction from `lib/data/datasources/*.dart`.
- Platform folder detection from root directory.
- Baseline quality run via `flutter analyze` and `flutter test`.

### External Research
- No external dependency required for this feature; this feature is grounded in repository facts.
