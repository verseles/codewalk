# Feature 005 - Documentation Restructure and Markdown Pruning

## Goal
Remove unnecessary markdown clutter while preserving essential project knowledge, and deliver a clean CodeWalk README with explicit attribution to the original OpenMode project.

## Scope
- Define and apply keep/merge/delete policy for markdown files
- Rewrite README for CodeWalk identity
- Add explicit acknowledgment to original project:
  - https://github.com/easychen/openMode
- Merge unique content into CODEBASE.md (no `docs/` directory -- too little content to justify)

## Out of Scope
- API contract implementation updates (handled in Feature 006)

## Document Classification

| File | Decision | Rationale |
|------|----------|-----------|
| README.md | REWRITE | Task 5.03 - new CodeWalk identity and OpenMode attribution |
| CODEBASE.md | KEEP + receives merge | Single source of truth for technical reference |
| ROADMAP.md | KEEP | Active roadmap |
| ADR.md | KEEP | Architectural decision records |
| LICENSE-COMMERCIAL.md | KEEP | Legal terms |
| NOTICE | KEEP | Legal attribution |
| ROADMAP.feat001-009.md | KEEP | Audit trail (completed) + operational (pending) |
| DEV.md | MERGE -> DELETE | ~80% overlap with CODEBASE.md; ~30 unique lines (Module Overview) |
| AI_CHAT_IMPLEMENTATION.md | MERGE -> DELETE | Core entities and streaming flow details useful for feat006 context |
| BUGFIX_SUMMARY.md | DELETE | Purely historical, fixes already applied in code |
| CHAT_API_ANALYSIS.md | MERGE -> DELETE | 1 note about API design (no-history payload), rest is historical |

## Implementation Tasks

### Task 5.01 - Document Classification
- [x] Classify all markdown files into keep/merge/delete buckets
- [x] Record classification table in this file

### Task 5.02 - Merge Unique Content into CODEBASE.md
- [x] From DEV.md: Module Overview (~20 lines) covering Auth/Server Config, Session, Chat, Settings modules
- [x] From AI_CHAT_IMPLEMENTATION.md: Core entities (ChatMessage typed parts, ChatSession metadata) and streaming flow (~12 lines)
- [x] From CHAT_API_ANALYSIS.md: API note about POST /session/{id}/message requiring only current payload (~2 lines)
- [x] Update CODEBASE.md references (remove AI_CHAT_IMPLEMENTATION.md mention, update .md count)

### Task 5.03 - Rewrite README.md
- [x] Remove WIP and Vibe Project banners
- [x] Remove emojis from headers
- [x] Remove video/screenshot placeholder
- [x] Remove placeholder clone URL (your-username)
- [x] Correct "iOS and Android" to "Android and web"
- [x] Simplify architecture section (reference CODEBASE.md)
- [x] Add explicit Origin and Acknowledgment section (OpenMode/easychen attribution)

### Task 5.04 - Delete Redundant Files and Verify Integrity
- [x] Delete: DEV.md, AI_CHAT_IMPLEMENTATION.md, BUGFIX_SUMMARY.md, CHAT_API_ANALYSIS.md
- [x] Verify zero .dart references to deleted files
- [x] Run make precommit (flutter test passed, analyze baseline unchanged at 167 info/warning)
- [x] Update ROADMAP.md (mark 5.01-5.04 as [x])
- [x] Confirm final .md count: 14

## Completion Summary

Feature 005 completed. Markdown footprint reduced from 18 to 14 files.

**Commits:**
- `8562850` feat(005): classify markdown docs into keep/merge/delete buckets
- `7c72e70` feat(005): merge unique content from historical docs into CODEBASE.md
- `b219a2b` feat(005): rewrite README.md with CodeWalk identity and OpenMode attribution
- (current) feat(005): delete redundant historical markdown files

**Files deleted:** DEV.md, AI_CHAT_IMPLEMENTATION.md, BUGFIX_SUMMARY.md, CHAT_API_ANALYSIS.md
**Files modified:** README.md (rewritten), CODEBASE.md (merged content + updated refs), ROADMAP.md (tasks marked), ROADMAP.feat005.md (completion summary)

## Risks and Mitigations
- Risk: deleting docs that still contain unique troubleshooting details.
  - Mitigation: extract unique knowledge before deletion via merge step (Task 5.02).
- Risk: roadmap files conflict with markdown reduction goal.
  - Mitigation: keep roadmap feature files active during execution; condense/remove when feature is fully complete.

## Definition of Done
- Markdown footprint is intentional and minimal (18 -> 14 files)
- README reflects current product, license, and origin correctly
- No stale docs remain in root except intentional control files
- `make precommit` passes

## Research Log

### Local Research
- Root markdown inventory captured and reviewed.
- Significant overlap found across chat/API historical notes.
- Unique content from DEV.md, AI_CHAT_IMPLEMENTATION.md, CHAT_API_ANALYSIS.md identified for merge.

### External Sources
- Original project URL to cite in README acknowledgment:
  - https://github.com/easychen/openMode
