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
- Markdown files currently present: 5 original (`README.md`, `DEV.md`, `CHAT_API_ANALYSIS.md`, `BUGFIX_SUMMARY.md`, `AI_CHAT_IMPLEMENTATION.md`) + roadmap files.
- Non-English content: 14 files under `lib/` contain CJK text (comments and string literals).
- Platform folders present: `android`, `web`; missing: `ios`, `windows`, `macos`, `linux`.
- Legacy naming appears in 8 locations: pubspec, app constants, test import, web manifest, Android namespace, README, AI_CHAT_IMPLEMENTATION.md.
- Baseline tooling:
  - `flutter --version`: 3.38.9 (stable)
  - `flutter analyze`: 167 issues (164 info, 3 warnings, 0 errors)
  - `flutter test`: 1 test, all passed
- Full baseline captured in `CODEBASE.md` (commit `b9de67f`)

## Document and Artifact Classification

| File | Class | Action | When |
|------|-------|--------|------|
| `README.md` | Runtime | Keep, rewrite for CodeWalk | Feature 005 |
| `DEV.md` | Historical reference | Merge useful content into CODEBASE.md, then delete | Feature 005 |
| `AI_CHAT_IMPLEMENTATION.md` | Historical reference | Merge into CODEBASE.md, then delete | Feature 005 |
| `BUGFIX_SUMMARY.md` | Historical reference | Archive in commit history, then delete | Feature 005 |
| `CHAT_API_ANALYSIS.md` | Historical reference | Merge into API docs for Feature 006, then delete | Feature 005/006 |
| `ROADMAP.md` | Active | Keep | Permanent |
| `ROADMAP.feat*.md` | Active | Keep during execution, archive after completion | Permanent |
| `CODEBASE.md` | Active | Keep, update per feature | Permanent |
| `ADR.md` | Active | Keep, append new decisions | Permanent |
| `Makefile` | Active | Keep, extend as needed | Permanent |
| `.g.dart` (5 files) | Generated | Regenerate via `build_runner` when models change | As needed |
| `build/`, `.dart_tool/` | Generated | Gitignored, never commit | N/A |

## Deletion Safety Rules

1. **Never delete** a file without first running `grep` to verify no other file references it
2. **Merge before delete** — for historical docs, extract all useful content into the appropriate destination before removing the source
3. **Checkpoint before bulk deletion** — create a git tag (`pre-feat-XXX`) before any feature that involves file deletion
4. **One commit per logical unit** — deletions should be in dedicated commits with clear messages explaining what was removed and where the content went
5. **Verify after deletion** — run `flutter analyze` and `flutter test` after any deletion to confirm no regressions

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

## Rollback and Branch Strategy

Defined in `ADR.md` (ADR-001). Summary:
- Tag `pre-feat-XXX` on main before each feature starts
- Feature branches: `feat/XXX-description`
- Squash merge to main after acceptance gates pass
- Rollback by discarding branch; main stays at tag state
- Feature 001 is exception: direct to main (docs only)

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

## Completion Summary

Feature 001 completed on 2026-02-09. All four tasks delivered:

| Task | Deliverable | Commit |
|------|-------------|--------|
| 1.01 | `Makefile` + `CODEBASE.md` with full baseline | `7d7e6f6`, `b9de67f` |
| 1.02 | Doc classification table + deletion safety rules in this file | `3640fb2` |
| 1.03 | `ADR.md` with ADR-001 (branch strategy) | `d307731` |
| 1.04 | Acceptance gates table in `ROADMAP.md` + tasks marked complete | (this commit) |

No source code was modified. Zero risk of regression.
