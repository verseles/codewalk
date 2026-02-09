# Feature 016 - Reliability Hardening, QA, and Release Readiness for Parity Wave

## Goal
Convert parity implementation work (Features 011-015) into a production-ready release through hardening, expanded automation, structured manual QA, and explicit release gates.

## Why This Exists

Parity features touch routing, persistence, streaming, and session lifecycle simultaneously. Without a final stabilization wave, regressions are likely and hard to diagnose across mobile/desktop/web targets.

## Research Snapshot

- Upstream commit: `anomalyco/opencode@24fd8c1` (strong e2e emphasis across app domains).
- Existing local quality assets reviewed:
  - `test/unit/*`, `test/widget/*`, `test/integration/*`
  - `test/support/mock_opencode_server.dart`
  - `.github/workflows/ci.yml`
  - `tool/ci/check_analyze_budget.sh`
  - `tool/ci/check_coverage.sh`
  - `Makefile` (`check`, `precommit`, `android`)

## Current Quality Baseline (CodeWalk)

- Unit/widget/integration suite exists and runs in CI.
- Mock OpenCode server integration tests already validate core session/message paths.
- CI enforces:
  - analyze budget
  - tests with coverage threshold
  - multi-target builds

This is a strong base, but parity features require broader scenario coverage.

## Scope

### In scope

- Expand automated tests for new parity behaviors.
- Define and execute manual QA matrix for parity flows.
- Update docs/ADR/CODEBASE to reflect final architecture changes.
- Final release checklist and known-limits report.

### Out of scope

- New feature development not directly required for release quality.

## Hardening Areas

### 1. Concurrency and race safety

- server switching mid-stream.
- directory context switching during in-flight requests.
- SSE reconnect around message completion boundaries.

### 2. Persistence correctness

- migration from legacy single-server keys.
- server- and directory-scoped cache keys.
- stale cache cleanup and TTL policy.

### 3. Error handling and recovery

- transient network failures.
- malformed/partial events.
- unsupported endpoint capability fallback.

### 4. UX resilience

- clear loading/error states for server/model/session actions.
- no silent failures for share/archive/permission/question actions.
- deterministic behavior after app restart.

## Test Expansion Plan

### Unit

- server profile migration and key-scoping logic.
- model/variant selection and fallback rules.
- event reducer and part merge logic.
- session lifecycle state transitions.

### Widget

- multi-server manager flows.
- model picker + variant control.
- permission/question interaction cards.
- session actions (rename/archive/share/delete/fork).
- project/workspace switcher behavior.

### Integration

- multi-server switching with isolated caches.
- event stream chaos scenarios (disconnect/reconnect/out-of-order deltas).
- session advanced flows against mock server.
- project/workspace context transitions.

## Manual QA Campaign

Create scenario matrix with IDs (`PAR-001` ...):

1. Multi-server management and default restore.
2. Model/variant switching and payload verification.
3. Long-running thinking/tools stream stability.
4. Permission/question interactive loop.
5. Session rename/archive/share/delete/fork.
6. Project/workspace create/reset/delete/switch.
7. App restart persistence and recovery.
8. Offline/online transition behavior.

Each scenario should record:

- setup
- expected result
- observed result
- evidence (logs/screenshots/video when needed)
- severity and owner for failures

## CI and Gate Plan

Maintain current gates and add parity gates:

- no regression in analyze budget.
- maintain or increase coverage threshold when new code lands.
- integration tests for parity suite must pass in CI.
- `make precommit` must pass locally before release cut.

## Documentation and Decision Updates

Before release:

- `ADR.md`
  - add decisions introduced by parity architecture (server-scoped persistence, event reducer, context sync model) if not already captured.
- `CODEBASE.md`
  - refresh endpoint/event coverage and architecture sections.
- `ROADMAP.md`
  - mark 011-016 status and blockers with commit hashes.

## Release Checklist (Exit Gate)

1. All feature acceptance gates 011-015 satisfied.
2. Parity test suite green in CI.
3. Manual QA matrix executed with no open P0/P1 defects.
4. Docs and ADR updates completed.
5. Android build/upload validated (`make android`) and smoke tested.
6. Known limitations documented with workaround or explicit deferred task.

## Risks and Mitigations

1. Risk: broad parity changes increase regression blast radius.
   - Mitigation: staged rollout and targeted test focus per feature.
2. Risk: flaky integration tests from async streams.
   - Mitigation: deterministic mock server controls and timeouts.
3. Risk: undocumented architectural drift after rapid delivery.
   - Mitigation: enforce ADR/CODEBASE update gate in release checklist.

## Execution Plan (mapped to ROADMAP tasks)

- `16.01` automated matrix expansion.
- `16.02` manual QA campaign and defect triage.
- `16.03` documentation + ADR alignment.
- `16.04` final precommit/CI/release checklist signoff.

## Definition of Done

- Feature wave 011-015 is demonstrably stable across supported platforms.
- CI and local precommit gates pass with expanded parity coverage.
- Manual QA signoff is documented with no unresolved critical defects.
- Architecture and codebase docs reflect the new system behavior.

## Source Links

- https://github.com/anomalyco/opencode
- https://opencode.ai/docs/server/

