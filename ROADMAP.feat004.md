# Feature 004 - Full English Standardization

## Goal
Convert all remaining non-English content to clear technical English across user-visible text, runtime logs/errors, comments/docblocks, and retained documentation.

## Scope
- Translate user-facing strings and runtime error/log messages in `lib/`
- Translate non-English comments/docblocks in `lib/`
- Translate retained technical markdown docs
- Add an automated guardrail to prevent mixed-language regressions

## Out of Scope
- Full i18n/l10n framework and multi-language UI
- Changes to API contracts, endpoint names, protocol keys, or model field names

## Current Findings (2026-02-09)
- `607` Han-character matches across `lib/` (`rg -n "[\\p{Han}]" lib --glob "*.dart"`)
- `38` Dart files with non-English content (`rg -l "[\\p{Han}]" lib --glob "*.dart"`)
- Highest concentration files:
  - `lib/data/datasources/chat_remote_datasource.dart` (117)
  - `lib/presentation/providers/chat_provider.dart` (89)
  - `lib/data/repositories/chat_repository_impl.dart` (63)
  - `lib/presentation/theme/app_theme.dart` (35)
  - `lib/presentation/providers/project_provider.dart` (29)
- Non-English markdown docs still present:
  - `DEV.md`
  - `AI_CHAT_IMPLEMENTATION.md`
  - `CHAT_API_ANALYSIS.md`
  - `BUGFIX_SUMMARY.md`

## Progress Snapshot (2026-02-09)
- Batch A completed for these files:
  - `lib/data/datasources/chat_remote_datasource.dart`
  - `lib/presentation/providers/chat_provider.dart`
  - `lib/data/repositories/chat_repository_impl.dart`
  - `lib/core/errors/failures.dart`
  - `lib/core/network/dio_client.dart`
- Han-character count in `lib/`: `607 -> 314`
- Dart files with Han in `lib/`: `38 -> 33`
- Batch A target check: `rg -n "[\\p{Han}]" <5 target files>` returns zero matches
- Validation:
  - `flutter analyze`: completed with existing baseline warnings/infos (no new compile errors)
  - `flutter test`: passing
- Current total in `lib/` after Batch B + C:
  - Han-character matches: `0`
  - Dart files with Han: `0`
- Technical markdown translation for `4.03` completed:
  - `DEV.md`
  - `AI_CHAT_IMPLEMENTATION.md`
  - `CHAT_API_ANALYSIS.md`
  - `BUGFIX_SUMMARY.md`
- Han-character check on root markdown:
  - `rg -n "[\\p{Han}]" *.md` returns zero matches

## Execution Plan

### Stage 1 - Freeze Rules and Translation Policy
- Define translation rules before edits:
  - translate strings, comments, log/error text only
  - never translate identifiers, enum values, API payload keys, endpoint paths
  - preserve behavior and punctuation semantics in thrown errors where matching is possible
- Add a small glossary for repeated terms (session, provider, repository, datasource, failover, timeout).

### Stage 2 - P1 Runtime/User-Visible Translation
- Translate runtime-facing text first (high user impact):
  - `presentation/providers/`
  - `data/datasources/`
  - `data/repositories/`
  - `core/errors/`
- Validate after each batch:
  - `flutter analyze`
  - `flutter test`

### Stage 3 - P2 Comment/Docblock Translation in `lib/`
- Translate remaining non-English comments/docblocks across:
  - `core/`, `data/`, `domain/`, `presentation/`
- Normalize to concise technical English and remove redundant comment noise.

### Stage 4 - P3 Documentation Translation
- Execute after Feature 005 keep/delete decisions are finalized.
- Translate only docs that remain in the final doc set; avoid translating files scheduled for deletion.

### Stage 5 - Guardrail and Exit Validation
- Status: cancelled by user decision (deemed unnecessary).
- Keep manual validation command available when needed:
  - `rg -n "[\\p{Han}]" lib docs README.md ROADMAP.md`

## Operational Batches (Implementation-Ready)

### Batch A - Runtime Hot Path (start here)
- Goal: reduce most user-visible non-English text quickly.
- Target files:
  - `lib/data/datasources/chat_remote_datasource.dart`
  - `lib/presentation/providers/chat_provider.dart`
  - `lib/data/repositories/chat_repository_impl.dart`
  - `lib/core/errors/failures.dart`
  - `lib/core/network/dio_client.dart`
- Exit checks:
  - `rg -n "[\\p{Han}]" lib/data/datasources/chat_remote_datasource.dart lib/presentation/providers/chat_provider.dart lib/data/repositories/chat_repository_impl.dart lib/core/errors/failures.dart lib/core/network/dio_client.dart`
  - `flutter analyze`
  - `flutter test`

### Batch B - Remaining Runtime + Domain Strings
- Goal: finish `4.01` by clearing runtime-facing text in non-core files.
- Target areas:
  - `lib/presentation/providers/`
  - `lib/presentation/pages/`
  - `lib/data/datasources/` (remaining files)
  - `lib/data/repositories/` (remaining files)
  - `lib/domain/entities/` and `lib/domain/repositories/` where string literals are runtime-facing
- Exit checks:
  - `rg -n "[\\p{Han}]" lib --glob "*.dart"`
  - mark `4.01` as `[x]` when no runtime-facing Han text remains

### Batch C - Comment/Docblock Cleanup in Source
- Goal: complete `4.02` by translating all remaining non-English comments/docblocks.
- Target areas:
  - all remaining `lib/**/*.dart` with Han matches after Batch B
- Exit checks:
  - `rg -n "[\\p{Han}]" lib --glob "*.dart"` returns zero
  - `flutter analyze`
  - `flutter test`

### Batch D - Retained Docs
- Goal: complete `4.03`.
- Sequence:
  - wait for Feature 005 keep/delete decisions
  - translate retained docs only
- Exit checks:
  - `rg -n "[\\p{Han}]" README.md docs ROADMAP.md` (or agreed retained-doc set)

## Task Breakdown Mapping to ROADMAP.md
- 4.01 Convert all UI strings and runtime errors/log messages to English
  - Inputs: Stage 1 + Stage 2
  - Exit: No user-facing/runtime Han text in `lib/`
- 4.02 Translate non-English comments/docblocks in `lib/` to concise technical English
  - Inputs: Stage 3
  - Exit: No Han content in comments/docblocks under `lib/`
- 4.03 Translate technical markdown that must be kept after cleanup
  - Inputs: Stage 4 + Feature 005 doc decisions
  - Exit: Retained markdown docs are English-only
- 4.04 Add a language consistency check step to prevent regressions
  - Status: `[!]` Won't do (user decision: unnecessary)

## Deliverables
- English-only runtime/user-visible text in active source
- English technical comments/docblocks in active source
- English retained docs
- Optional manual language check command for audits

## Risks and Mitigations
- Risk: translated text changes debugging meaning or expected UX wording.
  - Mitigation: prioritize high-impact files and review translated errors/messages side by side.
- Risk: accidental translation of protocol/contract fields.
  - Mitigation: hard rule to preserve identifiers/keys and review diffs focusing on literals only.
- Risk: wasted effort translating docs that Feature 005 later removes.
  - Mitigation: defer doc translation until post-pruning decisions.

## Definition of Done
- `rg -n "[\\p{Han}]" lib --glob "*.dart"` returns 0 relevant matches
- Retained markdown docs contain no non-English text
- `flutter analyze` passes with no new errors
- `flutter test` passes
- Guardrail automation waived by user decision (`4.04` marked `[!]`)

## Current Status
- 2026-02-09: Planning finalized and execution batches defined.
- 2026-02-09: `ROADMAP.md` task `4.01` set to `[~]` (in progress).
- 2026-02-09: Batch A implementation completed; next step is Batch B runtime/domain translation cleanup.
- 2026-02-09: Batch B and Batch C completed; `ROADMAP.md` tasks `4.01` and `4.02` marked `[x]`.
- 2026-02-09: `ROADMAP.md` task `4.04` marked `[!]` by user decision (unnecessary).
- 2026-02-09: `ROADMAP.md` task `4.03` marked `[x]` after translating technical markdown docs to English.
- 2026-02-09: Feature 004 task status is now: `4.01 [x]`, `4.02 [x]`, `4.03 [x]`, `4.04 [!]`.

## Research Log

### Local Research
- Enumerated non-English content by file and frequency with `rg`.
- Identified highest-risk clusters in chat data flow and provider layer.
- Verified non-English root docs requiring translation decision alignment with Feature 005.

### External Sources
- No external web research required for this feature.
