# Feature 005 - Documentation Restructure and Markdown Pruning

## Goal
Remove unnecessary markdown clutter while preserving essential project knowledge, and deliver a clean CodeWalk README with explicit attribution to the original OpenMode project.

## Scope
- Define and apply keep/merge/delete policy for markdown files
- Rewrite README for CodeWalk identity
- Add explicit acknowledgment to original project:
  - https://github.com/easychen/openMode
- Consolidate important technical docs into a compact `docs/` structure

## Out of Scope
- API contract implementation updates (handled in Feature 006)

## Current Findings (2026-02-09)
Current markdown files at repository root:
- `README.md`
- `DEV.md`
- `CHAT_API_ANALYSIS.md`
- `BUGFIX_SUMMARY.md`
- `AI_CHAT_IMPLEMENTATION.md`

These overlap in content and contain mixed language/outdated assumptions.

## Implementation Stages

### Stage 1 - Documentation Classification
- Keep:
  - `README.md`
  - License files
  - `ROADMAP.md` + active feature logs
- Merge then remove:
  - historical implementation notes with overlapping API/chat content
- Delete:
  - stale one-off analysis docs after merged replacement exists.

### Stage 2 - README Rewrite (CodeWalk)
- Rewrite intro, setup, architecture, and status sections.
- Add explicit origin/acknowledgment section:
  - state that CodeWalk is forked/derived from OpenMode,
  - link to original repository,
  - clarify ongoing independent maintenance.

### Stage 3 - Documentation IA Cleanup
- Move persistent technical docs under `docs/` by topic:
  - `docs/api/`
  - `docs/architecture/`
  - `docs/testing/`
- Remove duplicate and contradictory content.

### Stage 4 - Link and Content Validation
- Validate all internal links.
- Ensure no required onboarding/API/testing information was lost.

## Deliverables
- Clean top-level docs
- Updated `README.md` with origin acknowledgment
- Structured `docs/` tree for retained long-form technical content

## Risks and Mitigations
- Risk: deleting docs that still contain unique troubleshooting details.
  - Mitigation: extract unique knowledge before deletion and cross-link in new docs.
- Risk: roadmap files conflict with markdown reduction goal.
  - Mitigation: keep roadmap feature files active during execution; condense/remove when feature is fully complete.

## Definition of Done
- Markdown footprint is intentional and minimal
- README reflects current product, license, and origin correctly
- No stale docs remain in root except intentional control files

## Research Log

### Local Research
- Root markdown inventory captured and reviewed.
- Significant overlap found across chat/API historical notes.

### External Sources
- Original project URL to cite in README acknowledgment:
  - https://github.com/easychen/openMode
