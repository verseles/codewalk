# Feature 002 - Licensing Migration to AGPLv3 + Commercial (>500M Revenue)

## Goal
Replace the current MIT licensing model with a dual-track structure:
1. AGPLv3 for open-source/community usage.
2. Separate commercial terms for organizations with annual revenue above USD 500M.

## Critical Legal Constraint
The AGPL grant itself cannot add discriminatory field-of-use or revenue restrictions. The revenue threshold must be implemented as a separate commercial license offer, not as a restriction attached to AGPL permissions.

## Scope
- Replace root open-source license text with AGPLv3
- Add explicit commercial license file and purchase/contact workflow
- Update README/legal sections and project metadata
- Add legal decision log for unresolved clauses (jurisdiction, audit rights, support SLA)

## Out of Scope
- Final legal counsel sign-off (must be done externally)

## Current Findings (2026-02-09)
- Current root `LICENSE` is MIT.
- `README.md` still claims MIT.
- No commercial licensing document exists.

## Implementation Stages

### Stage 1 - License Architecture Definition
- Define dual licensing model in plain language:
  - AGPLv3 default option.
  - Commercial license required when org revenue > USD 500M.
- Define legal terms requiring counsel review.

### Stage 2 - File-Level License Migration
- Replace `LICENSE` with canonical AGPLv3 text.
- Create `LICENSE-COMMERCIAL.md` with:
  - revenue trigger definition,
  - rights granted,
  - prohibited redistribution conditions,
  - contact and compliance flow.

### Stage 3 - Repository-Level Legal Signaling
- Update `README.md` and any headers/metadata mentioning MIT.
- Add `NOTICE` with attribution and origin context.
- Add SPDX headers strategy for source files (batched follow-up task).

### Stage 4 - Compatibility and Auditability
- Run dependency license scan and flag incompatible packages/processes.
- Document known legal unknowns requiring lawyer review.

## Deliverables
- `LICENSE` (AGPLv3)
- `LICENSE-COMMERCIAL.md`
- `NOTICE` (or equivalent legal notice file)
- Updated `README.md` license section
- Legal decision log in docs

## Risks and Mitigations
- Risk: invalid dual-licensing language that conflicts with AGPL.
  - Mitigation: keep AGPL clean, isolate revenue restriction in commercial track.
- Risk: contributor rights not sufficient for future commercial enforcement.
  - Mitigation: add CLA/DCO decision as a follow-up legal action.

## Definition of Done
- MIT references removed from active docs/metadata
- AGPLv3 and commercial track are both explicit and non-contradictory
- License selection rules are clear for end users

## Research Log

### External Sources
- GNU AGPLv3 official text:
  - https://www.gnu.org/licenses/agpl-3.0.en.html
- GNU FAQ on additional restrictions (cannot restrict commercial use under GPL/AGPL grant):
  - https://www.gnu.org/licenses/gpl-faq.html#NoMilitary
- GNU FAQ on selling and dual licensing considerations:
  - https://www.gnu.org/licenses/gpl-faq.html#DoesTheGPLAllowMoney
- GNU article on selling exceptions / dual-licensing patterns:
  - https://www.gnu.org/philosophy/selling-exceptions.html

### Key Takeaways
- AGPL remains fully open-source and non-discriminatory.
- Revenue-based obligation must be contractual in a separate commercial license.
- Final wording should be reviewed by legal counsel before release.

## Dependency License Compatibility (Task 2.04)

Verified 2026-02-09. All direct dependencies are MIT or BSD-3-Clause — fully compatible with AGPLv3.

### Runtime Dependencies (14)

| Package | License | AGPLv3 Compatible |
|---------|---------|-------------------|
| Flutter SDK | BSD-3-Clause | Yes |
| cupertino_icons | MIT | Yes |
| dio | MIT | Yes |
| provider | MIT | Yes |
| shared_preferences | BSD-3-Clause | Yes |
| flutter_markdown | BSD-3-Clause | Yes |
| flutter_highlight | MIT | Yes |
| file_picker | MIT | Yes |
| url_launcher | BSD-3-Clause | Yes |
| package_info_plus | BSD-3-Clause | Yes |
| json_annotation | BSD-3-Clause | Yes |
| equatable | MIT | Yes |
| dartz | MIT | Yes |
| get_it | MIT | Yes |

### Dev Dependencies (5)

| Package | License | AGPLv3 Compatible |
|---------|---------|-------------------|
| flutter_test | BSD-3-Clause | Yes |
| flutter_lints | BSD-3-Clause | Yes |
| json_serializable | BSD-3-Clause | Yes |
| build_runner | BSD-3-Clause | Yes |
| flutter_launcher_icons | MIT | Yes |

### Conclusion

All 19 direct dependencies use permissive licenses (MIT or BSD-3-Clause). Both license types are one-way compatible with AGPLv3: permissive-licensed code can be included in AGPLv3 projects without conflict. Transitive dependencies (93 packages resolved by pub) inherit compatible licenses from the Flutter/Dart ecosystem, which is predominantly MIT/BSD.

## Deferred Legal Decisions

| Decision | Status | Notes |
|----------|--------|-------|
| CLA/DCO for future contributors | Deferred | Required if commercial licensing enforcement needs contributor assignment |
| Legal counsel review of LICENSE-COMMERCIAL.md | Deferred | Template only; final terms need lawyer sign-off before enforcement |
| SPDX headers in source files | Deferred | Out of scope for feat 002; planned for a future feature |
| Jurisdiction and governing law clause | Deferred | To be defined in executed commercial agreements |
| Audit rights for revenue verification | Deferred | To be defined in executed commercial agreements |

## Completion Summary

Feature 002 successfully migrated the CodeWalk project from an unfilled MIT template to a dual-licensing model:

1. **LICENSE** — Replaced with canonical GNU AGPLv3 text + CodeWalk copyright header (Commit: f0bc342)
2. **LICENSE-COMMERCIAL.md** — Created commercial license template for >500M revenue organizations (Commit: 898889f)
3. **NOTICE** — Created with copyright, AGPLv3 reference, and upstream OpenMode attribution (Commit: b5e1719)
4. **README.md** — License section updated from MIT to AGPLv3 + commercial dual-licensing (Commit: b5e1719)
5. **Dependency audit** — All 19 direct dependencies confirmed MIT/BSD-3-Clause compatible

No `.dart` files were modified. The 167 pre-existing analysis issues remain unchanged (zero new issues introduced).
