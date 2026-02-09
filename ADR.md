# Architecture Decision Records (ADR)

This document tracks technical decisions for CodeWalk.

## Index

- ADR-001: Branch Strategy and Rollback Checkpoints (2026-02-09) [Accepted]
- ADR-002: Makefile as Development and Pre-Commit Gatekeeper (2026-02-09) [Accepted]
- ADR-003: CI Parallel Quality/Build Matrix with Final Aggregator (2026-02-09) [Accepted]
- ADR-004: Coverage Gate with Generated-Code Filtering (2026-02-09) [Accepted]
- ADR-005: Centralized Structured Logging (2026-02-09) [Accepted]
- ADR-006: Session SWR Cache and Async Race Guards (2026-02-09) [Accepted]
- ADR-007: Hybrid Auto-Save in Server Settings (2026-02-09) [Accepted]
- ADR-008: Unified Cross-Platform Icon Pipeline and Asset Size Policy (2026-02-09) [Accepted]
- ADR-009: OpenCode v2 Parity Contract Freeze and Storage Migration Baseline (2026-02-09) [Accepted]

---

## ADR-001: Branch Strategy and Rollback Checkpoints

Status: Accepted  
Date: 2026-02-09

### Context

CodeWalk executes a feature-based migration with cross-cutting changes (legal, API, desktop, test infra). A failed feature should not contaminate the stable `main` branch.

### Decision

1. Tag before each feature (`pre-feat-XXX`).
2. Branch per feature (`feat/XXX-description`).
3. Squash merge into `main` after acceptance gates pass.
4. Roll back by discarding branch and returning to the tag.
5. Feature 001 exception: documentation-only work on `main`.

### Consequences

- Positive: stable rollback points and isolated implementation risk.
- Negative: squash merges hide micro-history (mitigated by keeping feature branch until next feature).

---

## ADR-002: Makefile as Development and Pre-Commit Gatekeeper

Status: Accepted  
Date: 2026-02-09

### Context

Running ad hoc commands leads to inconsistent local validation and missed release checks.

### Decision

Adopt a standardized Makefile workflow:

- `make check`: `deps + gen + analyze + test`
- `make precommit`: `check + android`
- `make android`: arm64 release APK build with deterministic output path

### Consequences

- Positive: repeatable local quality gate before commit.
- Trade-off: `precommit` is slower, but catches integration/build issues earlier.

---

## ADR-003: CI Parallel Quality/Build Matrix with Final Aggregator

Status: Accepted  
Date: 2026-02-09

### Context

A single CI job hides which quality or build stage failed and increases total runtime.

### Decision

Use parallel CI jobs:

- `quality`: generation, analyze budget, tests, coverage gate
- `build-linux`
- `build-web`
- `build-android`
- `ci-status`: aggregate and fail pipeline if any required job fails

Enable `concurrency` with `cancel-in-progress`.

### Consequences

- Positive: faster feedback and clearer failure boundaries.
- Trade-off: more workflow complexity and artifact volume.

---

## ADR-004: Coverage Gate with Generated-Code Filtering

Status: Accepted  
Date: 2026-02-09

### Context

Raw LCOV includes generated files and bootstrap artifacts that distort real test signal.

### Decision

Filter LCOV before threshold checks (e.g., `*.g.dart`, generated registrants, l10n-generated paths), then enforce the minimum coverage target.

### Consequences

- Positive: coverage threshold reflects authored code more accurately.
- Trade-off: requires `lcov` availability in CI/local environments.

---

## ADR-005: Centralized Structured Logging

Status: Accepted  
Date: 2026-02-09

### Context

Scattered `print` calls produce inconsistent diagnostics, leak formatting details, and conflict with lint policy.

### Decision

Introduce `AppLogger` (`debug`, `info`, `warn`, `error`) and replace `print` usage across core data flow and providers. Include lightweight token redaction patterns.

### Consequences

- Positive: consistent logs and cleaner production behavior.
- Trade-off: migration overhead and log-level discipline required.

---

## ADR-006: Session SWR Cache and Async Race Guards

Status: Accepted  
Date: 2026-02-09

### Context

Session and message loads can race (stale response overwrite), and users benefit from immediate cached data while refreshing in background.

### Decision

- Add fetch-generation guards for providers/sessions/messages.
- Keep local session cache with timestamp metadata.
- Apply SWR behavior: load cache first, refresh from server, and discard stale async results.

### Consequences

- Positive: fewer UI races and faster perceived load.
- Trade-off: more state bookkeeping and cache metadata handling.

---

## ADR-007: Hybrid Auto-Save in Server Settings

Status: Accepted  
Date: 2026-02-09

### Context

Manual-only save is slower for users; immediate save on every keystroke is noisy and error-prone.

### Decision

Apply hybrid auto-save:

- Text fields save on blur/submit.
- Toggle changes save immediately.
- Keep explicit `Save` for manual confirmation and visible feedback.
- Add deduped signature tracking to avoid redundant writes.

### Consequences

- Positive: smoother settings UX and lower accidental config drift.
- Trade-off: more save-path logic and validation guards.

---

## ADR-008: Unified Cross-Platform Icon Pipeline and Asset Size Policy

Status: Accepted  
Date: 2026-02-09

### Context

Icon generation was fragmented across platforms (Android, Linux, Windows, macOS), causing inconsistent visual framing and manual rework. At the same time, broad asset inclusion in `pubspec.yaml` inflated APK size by bundling source/work files that are not needed at runtime.

### Decision

Adopt a single source-of-truth icon workflow based on `assets/images/original.png` with deterministic Make targets:

1. `make icons` regenerates all platform icons (Android adaptive + standard, Linux PNG, Windows ICO, macOS app icon set) using controlled crop/resize parameters.
2. Android adaptive icon uses explicit full-bleed foreground (`adaptive_icon_foreground_inset: 0`) to allow intentional edge crop under launcher masks.
3. `make icons-check` validates required icon artifacts and critical dimensions quickly.
4. `make precommit` includes `icons-check` to prevent committing broken or inconsistent icon outputs.
5. Runtime asset policy is tightened to explicit inclusion (`assets/images/icon.png`) instead of bundling the full image folder.

### Rationale

- A unified pipeline removes per-platform drift and preserves the same composition intent from one master image.
- Full-bleed adaptive foreground matches the product requirement to consume available icon area even when launcher masks crop edges.
- Fast validation in precommit catches icon regressions early without forcing costly regeneration every commit.
- Explicit asset inclusion prevents accidental APK growth from design/source images.

### Consequences

- Positive: consistent icon identity across Android/Linux/Windows/macOS with one reproducible command.
- Positive: smaller APKs by excluding non-runtime image artifacts from Flutter asset bundling.
- Positive: predictable adaptive icon behavior (`inset=0%`) aligned with edge-to-edge visual strategy.
- Trade-off: `make icons` now depends on ImageMagick (`magick`) availability in contributor environments.
- Trade-off: aggressive crop can clip details on some launcher masks by design; updates should be previewed on real devices.

### Key Files

- `Makefile` - `icons`, `icons-check`, and precommit integration
- `pubspec.yaml` - adaptive icon configuration and explicit runtime asset policy
- `linux/CMakeLists.txt` - Linux icon installation into bundle data
- `linux/runner/my_application.cc` - Linux runtime icon loading
- `android/app/src/main/res/mipmap-anydpi-v26/launcher_icon.xml` - adaptive icon foreground inset configuration

---

## ADR-009: OpenCode v2 Parity Contract Freeze and Storage Migration Baseline

Status: Accepted  
Date: 2026-02-09

### Context

The OpenCode server/app surface expanded significantly after the original CodeWalk fork (multi-server orchestration, broader event taxonomy, model variant controls, advanced session lifecycle). Implementation work for features 011-016 requires a stable contract boundary; otherwise feature scope can drift and introduce regressions. CodeWalk also stores user state in flat keys today, which is incompatible with upcoming server-scoped and directory-scoped behavior.

### Decision

1. Lock parity planning to upstream snapshot `anomalyco/opencode@24fd8c1` and the corresponding OpenAPI (`packages/sdk/openapi.json`) as the baseline contract for this migration wave.
2. Classify parity scope into:
   - Required (delivery wave 011-015): route/event/part/UX coverage needed for Desktop/Web parity goals.
   - Optional (post-wave): lower-priority or experimental route families.
3. Adopt a migration baseline for persistence:
   - move from flat keys (`server_host`, `selected_model`, `cached_sessions`, etc.) to server-scoped and directory-scoped namespaced keys,
   - keep idempotent migration with one-release fallback reads from legacy keys.

### Rationale

- A contract freeze converts research into executable scope, reducing churn while implementation is in progress.
- Required-vs-optional classification prevents parity work from ballooning into non-critical surfaces.
- Namespaced persistence is mandatory to avoid cross-server and cross-directory state pollution once multi-server support is introduced.

### Consequences

- Positive: upcoming features can be implemented with a stable API/event target and explicit acceptance criteria.
- Positive: migration risk is controlled by idempotent rollout and rollback-safe fallback reads.
- Trade-off: some newer upstream capabilities remain intentionally deferred until after parity wave completion.
- Trade-off: maintaining temporary legacy key fallback increases short-term storage access complexity.

### Key Files

- `ROADMAP.feat010.md` - frozen parity contract, Required vs Optional matrix, migration checklist
- `ROADMAP.md` - execution tracking for Feature 010 tasks and dependencies
- `CODEBASE.md` - updated v2 route/event/part taxonomy baseline
- `lib/core/constants/app_constants.dart` - current flat-key source set considered in migration plan
