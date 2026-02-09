# Architecture Decision Records

## ADR-001: Branch Strategy and Rollback Checkpoints

**Date:** 2026-02-09
**Status:** Accepted
**Feature:** 001

### Context

CodeWalk is a solo-developer project executing a 9-feature migration roadmap on a fork of OpenMode. Each feature touches different cross-cutting concerns (licensing, renaming, translation, API, desktop, testing). A failed feature should not contaminate the stable main branch, and rollback must be possible at any point.

### Decision

1. **Tag before each feature:** Create `pre-feat-XXX` on main before starting any feature (e.g., `pre-feat-002`). This is the rollback point.
2. **Branch per feature:** Work on `feat/XXX-description` (e.g., `feat/002-licensing`). All commits for the feature go here.
3. **Squash merge to main:** After all acceptance gates pass, squash merge the feature branch into main. This keeps main history clean and each feature as a single logical unit.
4. **Rollback:** If a feature fails acceptance, discard the branch. Main remains at the pre-feature tag state.
5. **Feature 001 exception:** Executes directly on main since it is documentation-only with zero risk of code regression.

### Consequences

- **Positive:** Clean rollback to any pre-feature state. Each feature is isolated during development. Main always represents a stable, accepted state.
- **Negative:** Squash merges lose granular commit history (mitigated by keeping feature branches until next feature completes). Solo developer must remember to create tags before starting.
- **Neutral:** Slightly more git ceremony than committing directly to main, but justified by the risk profile of the migration.

### Compliance

- Feature branches must pass all exit gates before merge
- Tags are immutable rollback points
- No force-push to main
