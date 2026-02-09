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
