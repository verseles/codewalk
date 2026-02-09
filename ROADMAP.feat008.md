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

## Manual QA Matrix (Task 8.01)

### Severity Model
- P0: blocks core usage (cannot connect/chat/manage sessions)
- P1: high-impact stability or security issue with workaround
- P2: non-blocking UX/polish issue

### Matrix Axes Used in This Round
- Platform target: Linux desktop runtime, Web build, Android build
- Network profile:
  - Normal: real server reachable
  - Timeout constrained: very small client timeout against heavy endpoint
  - Intermittent disconnect: invalid host/port then recovery to valid host
- Critical flows:
  - F1: settings/connection
  - F2: provider/session listing
  - F3: session lifecycle (create/select/delete)
  - F4: chat send + stream + summarize
  - F5: error recovery after network failure

### Test Cases

| ID | Profile | Platform | Flow | Steps Summary | Expected Result | Severity if Fail |
|----|---------|----------|------|---------------|-----------------|------------------|
| QA-001 | Normal | Linux runtime | F1/F2 | Launch app and load providers/sessions from server | App starts and loads remote data | P0 |
| QA-002 | Normal | API smoke | F3 | Create session, list sessions, delete session | CRUD succeeds without API schema errors | P0 |
| QA-003 | Normal | API smoke | F4 | Send message, receive assistant response, summarize | Chat pipeline completes successfully | P0 |
| QA-004 | Timeout constrained | API smoke | F2 | Call `/provider` with strict timeout | Timeout is handled without crash/hang | P1 |
| QA-005 | Intermittent disconnect | API smoke | F5 | Fail request on invalid endpoint then retry valid endpoint | Recovery works and next request succeeds | P1 |
| QA-006 | Normal | Build | Platform gate | Build Linux and Web artifacts | Builds complete successfully | P1 |
| QA-007 | Normal | Build | Platform gate | Build Android debug APK | Build completes successfully | P1 |

## Execution Results (Tasks 8.02/8.03/8.04)

### Task 8.02 - Execution evidence

- API smoke script created and executed:
  - Script: `tool/qa/feat008_smoke.sh`
  - Latest successful run: `/tmp/codewalk_feat008/20260209_032152`
  - Result: `PASS_COUNT=5`, `FAIL_COUNT=0`
- Platform/build validations executed:
  - `flutter test` -> pass
  - `flutter build linux` -> pass
  - `flutter build web` -> pass
  - `flutter build apk --debug` -> pass (after defect fix loop below)
- Linux runtime smoke executed with log capture:
  - log file: `/tmp/codewalk_feat008_runtime_after.log`

### Task 8.03 - P0/P1 defect triage and fixes

| Defect ID | Severity | Description | Status | Fix |
|-----------|----------|-------------|--------|-----|
| D-008-01 | P1 | Sensitive HTTP debug logging could expose payload secrets and produce excessive logs | Fixed | Removed raw `LogInterceptor` dumping; added safe concise logs in `lib/core/network/dio_client.dart` |
| D-008-02 | P1 | Android debug build failed due AGP version mismatch (`8.7.3`) | Fixed | Updated AGP to `8.9.1` in `android/settings.gradle.kts` |

### Task 8.04 - Release readiness artifact

- Published: `QA.feat008.release-readiness.md`
- Contents: matrix coverage, evidence paths, fixed defects, known limitations, and go/no-go decision.
