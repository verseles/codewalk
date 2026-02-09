# Feature 008 - Manual QA Campaign and Stability Hardening

## Goal
Execute a structured manual test campaign to ensure functional stability across all supported platforms before relying on automation coverage.

## Scope
- Manual test matrix design
- Scripted and exploratory testing across platform/build variants
- Defect triage and high-impact fix loop
- Release-readiness summary

## Out of Scope
- Long-term CI policy definition (Feature 009)

## Prerequisites
- Feature 006 complete (API contract aligned)
- Feature 007 complete (cross-platform surfaces available)

## Test Matrix Axes
- Platform: Android, Web, Desktop (each enabled target)
- Network profile: normal, high latency, intermittent disconnect
- Flow: onboarding/settings, connection, session management, chat streaming, error recovery

## Implementation Stages

### Stage 1 - Manual Test Plan Definition
- Write scenario list with preconditions and expected outcomes.
- Assign severity model (P0/P1/P2).

### Stage 2 - Execution Round 1
- Run smoke + regression scenarios.
- Record reproducible evidence (steps, logs, screenshots where needed).

### Stage 3 - Defect Triage and Fix Loop
- Fix P0/P1 issues first.
- Re-test impacted areas only after each patch.

### Stage 4 - Final Regression Sweep
- Re-run critical user journeys end-to-end.
- Verify no blocker remains for daily usage.

### Stage 5 - Sign-off Artifact
- Publish manual QA report with:
  - tested matrix,
  - fixed issues,
  - known limitations and workarounds.

## Deliverables
- Manual QA checklist and execution log
- Prioritized bug backlog and resolution status
- Release-readiness summary

## Risks and Mitigations
- Risk: large matrix causes incomplete coverage.
  - Mitigation: prioritize critical flows and enforce minimum scenario set.
- Risk: manual runs become inconsistent over time.
  - Mitigation: template-based test cases and reproducibility checklist.

## Definition of Done
- No unresolved P0/P1 defects in core flows
- Manual report is complete and actionable for future regressions

## Research Log

### Local Research
- Baseline test instability already detected in current fork (`flutter test` failure), reinforcing need for a manual campaign before strict automation gates.

### External Sources
- No external dependency required; this is an execution-process feature built on project-specific behavior.
