# Feature 009 - Automated Test Suite and CI Quality Gates

## Goal
Build durable automated confidence through unit, widget, and integration tests, then enforce quality gates in CI.

## Scope
- Unit tests for core business logic and data mapping
- Widget tests for chat UX and responsive states
- Integration tests for API interactions with controllable server behavior
- CI pipeline for analyze/test/coverage enforcement

## Out of Scope
- Full performance benchmarking suite

## Prerequisites
- Feature 006 complete (API contracts stable)
- Feature 007 complete (responsive architecture stable)
- Feature 008 complete (manual defects mostly stabilized)

## Current Findings (2026-02-09)
- Existing tests are minimal and outdated (`test/widget_test.dart` still counter-template based).
- Baseline `flutter test` fails due DI/bootstrap mismatch in current app architecture.
- Baseline `flutter analyze` reports high issue count, so CI gating should be phased.

## Implementation Stages

### Stage 1 - Testability Refactor
- Decouple app bootstrap for test mode.
- Expose deterministic dependency injection setup for unit/widget/integration tests.

### Stage 2 - Unit Test Layer
- Add tests for:
  - model serialization/parsing,
  - repository mapping and failure conversion,
  - provider state transitions.

### Stage 3 - Widget Test Layer
- Add tests for:
  - chat page rendering states,
  - session selection behavior,
  - send-message UI transitions,
  - responsive breakpoints (mobile vs desktop shell).

### Stage 4 - Integration Test Layer
- Stand up mock/fake OpenCode server behavior for:
  - session CRUD,
  - provider fetch,
  - streaming event simulation.
- Validate end-to-end chat flow under expected error cases.

### Stage 5 - CI and Quality Gates
- Add CI workflow for:
  - `flutter analyze`
  - `flutter test` (unit + widget)
  - integration tests on supported runner where possible
  - coverage report and minimum threshold
- Phase quality gates to avoid immediate hard failures from legacy debt.

## Deliverables
- Multi-layer automated test suite
- CI workflow files with documented quality policy
- Coverage baseline and target thresholds

## Risks and Mitigations
- Risk: flaky integration tests (network/async timing).
  - Mitigation: deterministic fake server and controlled clocks/timeouts.
- Risk: strict CI gates block progress too early.
  - Mitigation: phased threshold strategy with explicit ratchet plan.

## Definition of Done
- `flutter test` runs meaningful suites (not template tests)
- CI enforces non-trivial quality gates
- Coverage trend is visible and improving

## Research Log

### External Sources
- Flutter testing docs overview:
  - https://docs.flutter.dev/testing
- Flutter continuous integration docs:
  - https://docs.flutter.dev/testing/continuous-integration
- Flutter integration testing docs:
  - https://docs.flutter.dev/testing/integration-tests

### Key Takeaways
- Flutter official guidance supports layered testing strategy.
- CI should combine analysis, tests, and artifacts for long-term maintainability.
