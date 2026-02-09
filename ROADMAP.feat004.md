# Feature 004 - Full English Standardization

## Goal
Convert all remaining non-English content to clear technical English across code comments, user-facing text, runtime logs, and retained documentation.

## Scope
- Translate comments/docblocks in `lib/`
- Translate/normalize runtime strings and error messages
- Translate retained technical markdown to English
- Add consistency checks to avoid reintroducing mixed-language content

## Out of Scope
- Internationalization/localization framework for multi-language UI

## Current Findings (2026-02-09)
- 38 files under `lib/` contain Chinese text.
- Technical docs (`DEV.md`, `AI_CHAT_IMPLEMENTATION.md`, `CHAT_API_ANALYSIS.md`, `BUGFIX_SUMMARY.md`) are largely non-English.
- Runtime error strings in data/providers include Chinese messages.

## Implementation Stages

### Stage 1 - Translation Inventory
- Build a prioritized list:
  - P1: user-visible strings and errors
  - P2: logs/comments in core data flows
  - P3: low-impact technical comments

### Stage 2 - Runtime Text Translation
- Convert UI/error strings to concise English.
- Keep semantics identical to avoid behavior regressions.

### Stage 3 - Code Comment and Docblock Translation
- Translate non-English comments in `core/`, `data/`, `domain/`, `presentation/`.
- Rewrite noisy comments into concise engineering notes.

### Stage 4 - Documentation Translation
- Translate documents that survive Feature 005 cleanup.
- Remove conflicting/outdated translated duplicates.

### Stage 5 - Guardrail
- Add CI grep check for disallowed non-English ranges in source/docs (excluding allowed files if needed).

## Deliverables
- English-only codebase (except explicitly whitelisted legacy artifacts)
- Updated docs in English
- Automated consistency check

## Risks and Mitigations
- Risk: translation alters technical meaning of API behavior.
  - Mitigation: translate in-place with side-by-side review for critical files.
- Risk: over-translation of identifiers or protocol fields.
  - Mitigation: never translate protocol keys, IDs, endpoint names, or schema fields.

## Definition of Done
- No non-English text remains in active source files and retained docs
- User-facing UX is coherent and professional in English

## Research Log

### Local Research
- Non-English content enumeration performed with Unicode range grep across `lib/`.
- Verified key clusters in providers, data sources, models, and theme comments.

### External Sources
- No external dependency required; this feature is primarily codebase translation work.
