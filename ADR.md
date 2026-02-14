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
- ADR-010: Multi-Server Profile Orchestration and Scoped Persistence (2026-02-09) [Accepted]
- ADR-011: Model Selection and Variant Preference Orchestration (2026-02-09) [Accepted]
- ADR-012: Realtime Event Reducer and Interactive Prompt Orchestration (2026-02-09) [Accepted]
- ADR-013: Session Lifecycle Orchestration with Optimistic Mutations and Insight Hydration (2026-02-10) [Accepted]
- ADR-014: Project/Workspace Context Orchestration with Global Event Sync (2026-02-10) [Accepted]
- ADR-015: Parity Wave Release Gate and QA Evidence Contract (2026-02-10) [Accepted]
- ADR-016: Chat-First Navigation Architecture (2026-02-10) [Accepted]
- ADR-017: Composer Multimodal Input Pipeline (2026-02-10) [Accepted]
- ADR-018: Refreshless Realtime Sync with Lifecycle and Degraded Fallback (2026-02-10) [Accepted]
- ADR-019: Prompt Power Composer Triggers (`@`, `!`, `/`) (2026-02-10) [Accepted]
- ADR-020: File Explorer State and Context-Scoped Viewer Orchestration (2026-02-11) [Accepted]
- ADR-021: Responsive Dialog Sizing Standard and Files-Centered Viewer Surface (2026-02-11) [Accepted]
- ADR-022: Modular Settings Hub and Experience Preference Orchestration (2026-02-11) [Accepted]
- ADR-023: Deprecated API Modernization and Web Interop Migration (2026-02-11) [Accepted]
- ADR-024: Desktop Composer/Pane Interaction and Active-Response Abort Semantics (2026-02-11) [Accepted]
- ADR-025: Automatic Session Title Generation via ch.at API (2026-02-12) [Accepted]

---

## ADR-001: Branch Strategy and Rollback Checkpoints

**Status**: Accepted
**Date**: 2026-02-09

### Context

CodeWalk executes a feature-based migration with cross-cutting changes (legal, API, desktop, test infra). A failed feature should not contaminate the stable `main` branch. The project requires a deterministic rollback strategy that preserves feature isolation without losing the ability to recover from failed implementations.

### Decision

1. Tag before each feature (`pre-feat-XXX`).
2. Branch per feature (`feat/XXX-description`).
3. Squash merge into `main` after acceptance gates pass.
4. Roll back by discarding branch and returning to the tag.
5. Feature 001 exception: documentation-only work on `main`.

### Rationale

- Git tags provide immutable rollback checkpoints that are fast to revert to (simple reset vs complex revert chains).
- Feature branches isolate implementation risk and allow parallel feature exploration without blocking main branch progress.
- Squash merges keep main history linear and readable while preserving detailed work history in feature branches until the next feature begins.
- Pre-feature tags enable instant recovery from breaking changes without complex git surgery or force pushes.

### Consequences

- ✅ Positive: stable rollback points and isolated implementation risk.
- ✅ Positive: main branch remains stable and always in a releasable state.
- ⚠️ Trade-off: squash merges hide micro-history in main (mitigated by keeping feature branch until next feature).
- ⚠️ Trade-off: requires discipline to create tags before starting feature work.

### Key Files

- `.git/refs/tags/pre-feat-*` - rollback checkpoints
- `ROADMAP.md` - feature tracking and gate definitions

### References

- ADR-002: Makefile as Development and Pre-Commit Gatekeeper
- ADR-015: Parity Wave Release Gate and QA Evidence Contract

---

## ADR-002: Makefile as Development and Pre-Commit Gatekeeper

**Status**: Accepted
**Date**: 2026-02-09

### Context

Running ad hoc commands leads to inconsistent local validation and missed release checks. Different developers might run different command sequences, causing integration failures in CI that should have been caught locally. The project needs a standardized, repeatable quality gate that works identically across all developer environments.

### Decision

Adopt a standardized Makefile workflow:

- `make check`: `deps + gen + analyze + test`
- `make precommit`: `check + android`
- `make android`: arm64 release APK build with deterministic output path

### Rationale

- Makefile provides a single, portable entry point that works across Unix-like systems without requiring additional tooling.
- Standardized targets ensure all developers run the same validation sequence, eliminating "works on my machine" issues.
- `precommit` target catches platform-specific build failures (especially Android) before they reach CI, saving CI resources and developer time.
- Deterministic build outputs enable artifact comparison and reproducible release builds.

### Consequences

- ✅ Positive: repeatable local quality gate before commit.
- ✅ Positive: reduces CI failures caused by missed local validation steps.
- ✅ Positive: Android build issues caught before push, not after.
- ⚠️ Trade-off: `precommit` is slower (~5-10 min), but catches integration/build issues earlier.
- ⚠️ Trade-off: requires make to be installed (standard on most dev environments).

### Key Files

- `Makefile` - quality gate targets and build automation
- `.github/workflows/ci.yml` - CI pipeline using same Makefile targets

### References

- ADR-001: Branch Strategy and Rollback Checkpoints
- ADR-003: CI Parallel Quality/Build Matrix with Final Aggregator

---

## ADR-003: CI Parallel Quality/Build Matrix with Final Aggregator

**Status**: Accepted
**Date**: 2026-02-09

### Context

A single CI job hides which quality or build stage failed and increases total runtime. Serial execution means a 2-minute test failure blocks seeing a 5-minute build failure, wasting developer time. The project needs faster feedback and clearer failure boundaries to improve developer productivity.

### Decision

Use parallel CI jobs:

- `quality`: generation, analyze budget, tests, coverage gate
- `build-linux`
- `build-web`
- `build-android`
- `ci-status`: aggregate and fail pipeline if any required job fails

Enable `concurrency` with `cancel-in-progress` to abort outdated runs when new commits arrive.

### Rationale

- Parallel execution reduces total CI time from ~15-20 minutes (serial) to ~5-8 minutes (parallel).
- Independent jobs provide immediate feedback on specific failure types (test vs build vs platform-specific).
- Aggregator pattern ensures branch protection rules work correctly (single status check instead of multiple required checks).
- Concurrency cancellation saves CI resources by aborting stale runs when developers push fixup commits.

### Consequences

- ✅ Positive: faster feedback (parallel execution) and clearer failure boundaries.
- ✅ Positive: developers can identify failure type (quality/build/platform) at a glance.
- ✅ Positive: reduced CI queue time with automatic cancellation of superseded runs.
- ⚠️ Trade-off: more workflow complexity and artifact volume.
- ⚠️ Trade-off: requires careful job dependency configuration to avoid race conditions.

### Key Files

- `.github/workflows/ci.yml` - parallel job matrix and aggregator
- `Makefile` - reused by CI jobs for consistency

### References

- ADR-002: Makefile as Development and Pre-Commit Gatekeeper
- ADR-004: Coverage Gate with Generated-Code Filtering

---

## ADR-004: Coverage Gate with Generated-Code Filtering

**Status**: Accepted
**Date**: 2026-02-09

### Context

Raw LCOV includes generated files and bootstrap artifacts that distort real test signal. Generated code (like `*.g.dart` serializers) inflates coverage metrics without reflecting actual test quality of authored code. The project needs accurate coverage metrics that reflect only hand-written code to make coverage gates meaningful.

### Decision

Filter LCOV before threshold checks (e.g., `*.g.dart`, generated registrants, l10n-generated paths), then enforce the minimum coverage target. Only authored source files contribute to coverage calculations.

### Rationale

- Generated code is typically untested and not meant to be tested (e.g., JSON serializers, dependency injection wiring).
- Including generated code in coverage distorts the signal: high coverage numbers can hide low test coverage of business logic.
- Filtering before threshold enforcement ensures coverage gates reflect real test discipline, not artifact generation patterns.
- This approach aligns with industry best practices (e.g., codecov, coveralls all support similar filtering).

### Consequences

- ✅ Positive: coverage threshold reflects authored code more accurately.
- ✅ Positive: coverage gates become meaningful quality signals instead of misleading metrics.
- ✅ Positive: prevents gaming coverage numbers by adding more generated code.
- ⚠️ Trade-off: requires `lcov` availability in CI/local environments.
- ⚠️ Trade-off: filter patterns must be maintained as new generated code patterns emerge.

### Key Files

- `Makefile` - coverage filtering and threshold enforcement
- `.github/workflows/ci.yml` - coverage gate in quality job
- `test/` - test suite

### References

- ADR-003: CI Parallel Quality/Build Matrix with Final Aggregator

---

## ADR-005: Centralized Structured Logging

**Status**: Accepted
**Date**: 2026-02-09

### Context

Scattered `print` calls produce inconsistent diagnostics, leak formatting details, and conflict with lint policy. Debug output mixed with production logs makes it difficult to filter signal from noise. The project needs a consistent logging strategy that works across development and production environments.

### Decision

Introduce `AppLogger` (`debug`, `info`, `warn`, `error`) and replace `print` usage across core data flow and providers. Include lightweight token redaction patterns to prevent accidental credential leakage in logs.

### Rationale

- Structured logging with severity levels enables better filtering and debugging (e.g., production logs show only warnings/errors).
- Centralized logger allows environment-specific behavior (console in dev, file/service in production) without changing call sites.
- Token redaction patterns prevent accidental credential exposure in logs, a common security vulnerability.
- Eliminates lint violations from `print` usage and establishes consistent log formatting across the codebase.

### Consequences

- ✅ Positive: consistent logs and cleaner production behavior.
- ✅ Positive: better debugging with log-level filtering (hide debug logs in production).
- ✅ Positive: reduced risk of credential leakage through logs.
- ⚠️ Trade-off: migration overhead (replace ~50+ print statements across codebase).
- ⚠️ Trade-off: log-level discipline required (developers must use appropriate severity levels).

### Key Files

- `lib/core/utils/app_logger.dart` - centralized logger
- `lib/presentation/providers/` - provider logging usage
- `lib/data/` - data layer logging usage

### References

- ADR-012: Realtime Event Reducer and Interactive Prompt Orchestration (uses logging extensively)

---

## ADR-006: Session SWR Cache and Async Race Guards

**Status**: Accepted
**Date**: 2026-02-09

### Context

Session and message loads can race (stale response overwrite), and users benefit from immediate cached data while refreshing in background. Without race guards, a slow network request can overwrite fresher data that arrived earlier, causing UI to jump backward in time. The project needs a caching strategy that prevents race conditions while improving perceived performance.

### Decision

- Add fetch-generation guards for providers/sessions/messages.
- Keep local session cache with timestamp metadata.
- Apply SWR (stale-while-revalidate) behavior: load cache first, refresh from server, and discard stale async results.

### Rationale

- SWR pattern is industry-proven for balancing freshness and perceived performance (used by Next.js, react-query, etc.).
- Generation guards prevent race conditions where request B starts before request A but returns after A, ensuring only the latest request updates state.
- Cache-first loading eliminates loading spinners on app restart, improving perceived performance.
- Timestamp metadata enables cache expiration policies and helps debug staleness issues.

### Consequences

- ✅ Positive: fewer UI races and faster perceived load.
- ✅ Positive: app feels instant on restart (cache-first), then updates to fresh data.
- ✅ Positive: eliminates entire class of race-condition bugs.
- ⚠️ Trade-off: more state bookkeeping (cache + generation counters + timestamps).
- ⚠️ Trade-off: cache metadata handling adds complexity to provider initialization.

### Key Files

- `lib/presentation/providers/chat_provider.dart` - SWR implementation
- `lib/data/datasources/app_local_datasource.dart` - cache persistence
- `lib/domain/entities/chat_session.dart` - cached entity structure

### References

- ADR-013: Session Lifecycle Orchestration (extends caching to lifecycle operations)
- ADR-018: Refreshless Realtime Sync (builds on SWR for realtime updates)

---

## ADR-007: Hybrid Auto-Save in Server Settings

**Status**: Accepted
**Date**: 2026-02-09

### Context

Manual-only save is slower for users; immediate save on every keystroke is noisy and error-prone. Users expect modern UX where text fields save automatically, but explicit save buttons provide confidence that changes are persisted. The project needs a balanced approach that combines automatic persistence with explicit feedback.

### Decision

Apply hybrid auto-save:

- Text fields save on blur/submit.
- Toggle changes save immediately.
- Keep explicit `Save` for manual confirmation and visible feedback.
- Add deduped signature tracking to avoid redundant writes.

### Rationale

- Blur-based auto-save matches user expectations from modern web apps while avoiding keystroke-level network noise.
- Immediate toggle persistence prevents "I changed it but forgot to save" errors for boolean preferences.
- Explicit save button provides visual feedback and meets user expectations for settings pages.
- Signature-based deduplication prevents redundant writes when users re-blur without changes, reducing storage churn.

### Consequences

- ✅ Positive: smoother settings UX and lower accidental config drift.
- ✅ Positive: users don't lose changes from forgetting to save toggles.
- ✅ Positive: reduced support burden from "my changes weren't saved" issues.
- ⚠️ Trade-off: more save-path logic (blur handlers, signature tracking) and validation guards.
- ⚠️ Trade-off: mixed persistence model requires careful documentation.

### Key Files

- `lib/presentation/pages/server_settings_page.dart` - hybrid save implementation
- `lib/data/datasources/app_local_datasource.dart` - persistence layer
- `lib/domain/entities/server_profile.dart` - settings entity

### References

- ADR-010: Multi-Server Profile Orchestration (builds on settings persistence)
- ADR-022: Modular Settings Hub (extends hybrid save to new settings sections)

---

## ADR-008: Unified Cross-Platform Icon Pipeline and Asset Size Policy

**Status**: Accepted
**Date**: 2026-02-09

### Context

Icon generation was fragmented across platforms (Android, Linux, Windows, macOS), causing inconsistent visual framing and manual rework. At the same time, broad asset inclusion in `pubspec.yaml` inflated APK size by bundling source/work files that are not needed at runtime. The project needs a single source of truth for icon generation and a clear asset inclusion policy to prevent binary bloat.

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
- Explicit asset inclusion prevents accidental APK growth from design/source images (observed 2MB+ bloat from bundling Sketch/PSD files).

### Consequences

- ✅ Positive: consistent icon identity across Android/Linux/Windows/macOS with one reproducible command.
- ✅ Positive: smaller APKs by excluding non-runtime image artifacts from Flutter asset bundling.
- ✅ Positive: predictable adaptive icon behavior (`inset=0%`) aligned with edge-to-edge visual strategy.
- ⚠️ Trade-off: `make icons` now depends on ImageMagick (`magick`) availability in contributor environments.
- ⚠️ Trade-off: aggressive crop can clip details on some launcher masks by design; updates should be previewed on real devices.

### Key Files

- `Makefile` - `icons`, `icons-check`, and precommit integration
- `pubspec.yaml` - adaptive icon configuration and explicit runtime asset policy
- `linux/CMakeLists.txt` - Linux icon installation into bundle data
- `linux/runner/my_application.cc` - Linux runtime icon loading
- `android/app/src/main/res/mipmap-anydpi-v26/launcher_icon.xml` - adaptive icon foreground inset configuration

### References

- ADR-002: Makefile as Development and Pre-Commit Gatekeeper

---

## ADR-009: OpenCode v2 Parity Contract Freeze and Storage Migration Baseline

**Status**: Accepted
**Date**: 2026-02-09

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
- Required-vs-optional classification prevents parity work from ballooning into non-critical surfaces that would delay delivery.
- Namespaced persistence is mandatory to avoid cross-server and cross-directory state pollution once multi-server support is introduced.
- Idempotent migration with fallback reads enables rollback without data loss if the migration wave needs to be reverted.

### Consequences

- ✅ Positive: upcoming features can be implemented with a stable API/event target and explicit acceptance criteria.
- ✅ Positive: migration risk is controlled by idempotent rollout and rollback-safe fallback reads.
- ✅ Positive: clear scope prevents feature creep during implementation wave.
- ⚠️ Trade-off: some newer upstream capabilities remain intentionally deferred until after parity wave completion.
- ⚠️ Trade-off: maintaining temporary legacy key fallback increases short-term storage access complexity.

### Key Files

- `ROADMAP.feat010.md` - frozen parity contract, Required vs Optional matrix, migration checklist
- `ROADMAP.md` - execution tracking for Feature 010 tasks and dependencies
- `CODEBASE.md` - updated v2 route/event/part taxonomy baseline
- `lib/core/constants/app_constants.dart` - current flat-key source set considered in migration plan

### References

- ADR-010: Multi-Server Profile Orchestration (implements storage migration)
- ADR-015: Parity Wave Release Gate (validates migration wave completion)

---

## ADR-010: Multi-Server Profile Orchestration and Scoped Persistence

**Status**: Accepted
**Date**: 2026-02-09

### Context

CodeWalk previously supported only one server (`server_host` + `server_port` flat persistence), which caused architectural limits for parity with OpenCode Desktop/Web. Feature 011 required first-class multi-server support with active/default switching, health-aware activation, and isolation between server-specific runtime caches (sessions/models/current context). Without namespacing, switching servers could leak stale state between environments.

### Decision

1. Introduce `ServerProfile` as the canonical persisted server entity and store:
   - `server_profiles` (JSON list)
   - `active_server_id`
   - `default_server_id`
2. Add one-way legacy migration from `server_host`/`server_port` and old auth keys into the new profile structure (idempotent, fallback reads retained).
3. Implement health orchestration in `AppProvider`:
   - primary probe `GET /global/health`
   - fallback probe `GET /path`
   - prevent activation of explicitly unhealthy profiles.
4. Namespace state persistence by server and context so chat/session/model caches are isolated per active server.

### Rationale

- Multi-server parity is foundational for subsequent features (model variants, advanced session lifecycle, workspace context).
- Isolated persistence prevents cross-server data contamination, a critical correctness requirement for users managing dev/staging/prod servers.
- Health-aware activation aligns UX with upstream behavior and reduces invalid switch failures (e.g., attempting to activate a server that's offline).
- Idempotent migration preserves backward compatibility while enabling new architecture, allowing safe rollback if issues are discovered.

### Consequences

- ✅ Positive: users can manage multiple servers (add/edit/remove, active/default) with deterministic routing behavior.
- ✅ Positive: cached sessions/current session/model selections no longer bleed across servers.
- ✅ Positive: server switch UX is available from settings and chat app bar, reducing context-switch friction.
- ⚠️ Trade-off: provider and local-storage logic became more complex due to scoped key strategy and migration support.
- ⚠️ Trade-off: temporary fallback handling for legacy keys must be maintained until a future cleanup window.

### Key Files

- `lib/domain/entities/server_profile.dart` - server profile entity model
- `lib/core/constants/app_constants.dart` - v2 multi-server/scoped storage keys
- `lib/data/datasources/app_local_datasource.dart` - scoped persistence API and profile storage
- `lib/presentation/providers/app_provider.dart` - server orchestration, migration, health checks
- `lib/presentation/providers/chat_provider.dart` - server-scoped chat/session/model cache handling
- `lib/presentation/pages/server_settings_page.dart` - server manager UI
- `lib/presentation/pages/chat_page.dart` - quick server switch control

### References

- ADR-009: OpenCode v2 Parity Contract Freeze (defines migration baseline)
- ADR-011: Model Selection and Variant Preference Orchestration (builds on server scoping)
- `ROADMAP.feat011.md`
- https://opencode.ai/docs/server/

---

## ADR-011: Model Selection and Variant Preference Orchestration

**Status**: Accepted
**Date**: 2026-02-09

### Context

After Feature 011 (ADR-010) established multi-server state isolation, CodeWalk still lacked parity for model control: no in-app provider/model picker, no variant (reasoning effort) controls, and no persistence strategy for recent/frequent model usage. Without this, users could not reliably steer model behavior and outbound prompt payloads could not express variant-specific intent (e.g., selecting "extended" reasoning for complex tasks).

### Decision

1. Extend provider/model domain schema to include typed model variants parsed from `/provider`.
2. Extend chat input contract with optional `variant` and serialize it in outbound message payloads when selected.
3. Add `ChatProvider` orchestration APIs for model state:
   - `setSelectedProvider`
   - `setSelectedModel`
   - `setSelectedVariant`
   - `cycleVariant`
4. Persist model preferences in server/context-scoped storage:
   - selected variant map per `provider/model`
   - recent model keys (for quick access)
   - model usage counts (frequent model signal for smart defaults)
5. Add composer-level controls in chat UI for provider/model selection and reasoning cycle.

### Rationale

- Model/variant selection is a direct parity requirement with upstream OpenCode Desktop/Web (users expect to control model behavior from UI).
- Variant-aware payloads are necessary to control reasoning effort where models expose multiple variants (e.g., Claude's "extended" reasoning).
- Recent/frequent persistence improves recovery when defaults or provider inventories change across restarts, reducing friction for power users.
- Server/context scoping preserves isolation guarantees introduced in ADR-010, preventing model preferences from bleeding across server environments.

### Consequences

- ✅ Positive: users can choose provider/model from chat UI and cycle reasoning variant when available.
- ✅ Positive: outbound prompt bodies include `variant`, achieving payload parity for current send flow.
- ✅ Positive: restored preferences now account for both explicit selection and historical usage (smart defaults).
- ⚠️ Trade-off: `ChatProvider` state machine complexity increased with preference loading/fallback logic.
- ⚠️ Trade-off: additional persisted keys require migration-aware maintenance in future storage refactors.

### Post-Decision Update (2026-02-13)

- Model selection is now treated as server-authoritative for cross-device parity:
  - `ChatProvider` reads `/config.model` and prioritizes it over local persisted selection during initialization.
  - Local provider/model changes are written back to `/config` (`PATCH { model: "provider/model" }`).
- Agent selection is now also synchronized through server config:
  - `ChatProvider` writes selected agent to `/config.default_agent`.
  - On initialization, `/config.default_agent` is preferred over local persisted agent when valid.
- Variant/reasoning selection is synchronized cross-device via app namespace under agent options:
  - write path: `/config.agent.<agent>.options.codewalk.variantByModel[provider/model]`.
  - reconcile path: read remote map and apply selected variant for the active `agent + provider/model` pair.
  - `__auto__` sentinel is used to represent "Auto" variant explicitly for deterministic cross-client convergence.
- Select changes no longer force remote config writes while a response is active:
  - remote sync is deferred during `sending/busy/retry` states,
  - deferred writes are flushed automatically when session status returns to idle.
- Session-scoped selection override is applied in the active client:
  - conversation selection is remembered per session and reused on session switch,
  - fallback remains context/project-local persisted selection.
- Session-scoped override now survives app restarts and converges cross-device:
  - local persistence is stored per `serverId + scopeId` in app storage,
  - remote persistence is stored in `/config.agent.__codewalk.options.codewalk.sessionSelections`.

### Key Files

- `lib/domain/entities/provider.dart`
- `lib/data/models/provider_model.dart`
- `lib/domain/entities/chat_session.dart`
- `lib/data/models/chat_session_model.dart`
- `lib/data/datasources/app_local_datasource.dart`
- `lib/presentation/providers/chat_provider.dart`
- `lib/presentation/pages/chat_page.dart`

### References

- ADR-010: Multi-Server Profile Orchestration (provides server scoping foundation)
- ADR-012: Realtime Event Reducer (integrates with model state changes)
- `ROADMAP.feat012.md`
- https://opencode.ai/docs/models/

---

## ADR-012: Realtime Event Reducer and Interactive Prompt Orchestration

**Status**: Accepted
**Date**: 2026-02-09

### Context

CodeWalk handled message updates mostly inside `sendMessage()` with a narrow SSE subset, limited part rendering, and no user-action flow for `permission.*` and `question.*` events. This caused parity gaps with current OpenCode clients: missing lifecycle/status synchronization, weak resilience under stream reconnects, and no in-app interactive approval/question handling. Users could see "waiting for permission" in logs but had no way to approve in-app.

### Decision

1. Introduce a dedicated realtime event subscription path in chat data/repository layers with reconnect + bounded backoff behavior.
2. Move high-value event handling into a provider-level reducer in `ChatProvider` for:
   - `session.*` status and metadata updates
   - `message.*` updates/removals
   - `permission.*` and `question.*` ask/reply lifecycle queues
3. Add targeted message fallback fetch (`GetChatMessage`) when event payloads are partial/delta-based.
4. Expand message part taxonomy support in parser + UI for:
   - `agent`, `step-start`, `step-finish`, `snapshot`, `subtask`, `retry`, `compaction`, `patch`
   - Note (2026-02-10): `step-start` and `step-finish` details were later moved from inline rendering to the assistant info menu (ADR-016) to reduce visual noise in the message flow.
5. Add interactive UI cards for pending permission/question requests and connect them to response endpoints.

### Rationale

- Event handling must be centralized and deterministic to avoid state drift across long sessions (e.g., 100+ message conversations).
- Delta/partial event payloads are common in OpenCode protocol and require fallback fetch to prevent lost data (server may send only changed fields).
- Permission/question flows are blocking interaction paths; without in-app actions, user tasks stall and require terminal interaction.
- Rendering extended part taxonomy avoids silent data loss and improves parity/debug visibility (all message types should render).

### Consequences

- ✅ Positive: realtime state reflects broader OpenCode event surface with reconnect tolerance.
- ✅ Positive: interactive permission/question requests are now actionable directly in mobile UI.
- ✅ Positive: message lifecycle fidelity improved via reducer + targeted fallback fetch.
- ⚠️ Trade-off: `ChatProvider` gained additional orchestration complexity and larger in-memory state maps.
- ⚠️ Trade-off: test surface increased (unit/widget/integration), requiring stronger regression discipline.

### Key Files

- `lib/data/datasources/chat_remote_datasource.dart`
- `lib/data/repositories/chat_repository_impl.dart`
- `lib/domain/entities/chat_realtime.dart`
- `lib/domain/usecases/watch_chat_events.dart`
- `lib/domain/usecases/get_chat_message.dart`
- `lib/presentation/providers/chat_provider.dart`
- `lib/presentation/widgets/chat_message_widget.dart`
- `lib/presentation/widgets/permission_request_card.dart`
- `lib/presentation/widgets/question_request_card.dart`

### References

- ADR-011: Model Selection and Variant Preference Orchestration (model changes trigger events)
- ADR-013: Session Lifecycle Orchestration (extends event handling to lifecycle operations)
- ADR-018: Refreshless Realtime Sync (builds on event reducer for refreshless behavior)
- `ROADMAP.feat013.md`
- https://opencode.ai/docs/server/
- https://github.com/anomalyco/opencode

### Implementation Reference

See CODEBASE.md for current module structure, file locations, and operational details:
- [Chat Module](CODEBASE.md#chat-module)
- [Feature 013: Realtime Architecture](CODEBASE.md#feature-013-realtime-architecture-2026-02-09)
- [Chat System Details](CODEBASE.md#chat-system-details)

---

## ADR-013: Session Lifecycle Orchestration with Optimistic Mutations and Insight Hydration

**Status**: Accepted
**Date**: 2026-02-10

### Context

Basic session CRUD was no longer enough for parity with current OpenCode flows. CodeWalk needed rename/archive/share/fork behaviors, lifecycle insight surfaces (`status`, `children`, `todo`, `diff`), and scalable list navigation for larger histories. Existing provider logic handled session state updates narrowly and could leave the UI stale after lifecycle mutations or event-only partial payloads.

### Decision

1. Expand session domain contracts to include lifecycle metadata (`parentId`, `directory`, `archivedAt`, `shareUrl`) and lifecycle insight entities (`SessionTodo`, `SessionDiff`).
2. Extend chat repository/data-source contracts with advanced lifecycle operations:
   - `/session/{id}` patch update
   - `/session/{id}/share` create/delete
   - `/session/{id}/fork`
   - `/session/status`
   - `/session/{id}/children`
   - `/session/{id}/todo`
   - `/session/{id}/diff`
   - list query controls (`search`, `roots`, `start`, `limit`)
3. Implement provider-level optimistic mutations (rename/archive/share/delete) with rollback on failure and deterministic re-sync after remote acknowledgment.
4. Introduce lifecycle insight orchestration in `ChatProvider` to hydrate and maintain `status`, `children`, `todo`, and `diff` maps, including reducer handling for `todo.updated` and `session.diff` realtime events.
5. Expand session list UX to include filter/sort/search/load-more controls and add lifecycle action menu coverage in widget/integration tests.

### Rationale

- Lifecycle mutation latency should not block UX responsiveness, so optimistic local updates are required (immediate UI feedback while request in flight).
- Rollback paths are mandatory to preserve state correctness when API operations fail (e.g., network error during rename).
- Insight hydration aligns mobile behavior with OpenCode Desktop/Web visibility for session state beyond message text (todos, diffs, child sessions).
- Query windowing controls (`start`/`limit`) are needed to keep session history navigation performant as data volume grows (users may have 1000+ sessions).
- Dedicated lifecycle endpoint coverage in the mock server and integration tests prevents regressions in parity-critical flows.

### Consequences

- ✅ Positive: session management now supports parity-level lifecycle operations and metadata.
- ✅ Positive: users get immediate UI feedback on lifecycle actions with automatic recovery on failures.
- ✅ Positive: session insight data is now visible and synchronized through both API pulls and realtime events.
- ⚠️ Trade-off: `ChatProvider` state orchestration became more complex (optimistic state + rollback + insight caches).
- ⚠️ Trade-off: larger test surface area increases maintenance cost but improves confidence against regressions.

### Key Files

- `lib/domain/entities/chat_session.dart`
- `lib/domain/repositories/chat_repository.dart`
- `lib/data/datasources/chat_remote_datasource.dart`
- `lib/data/models/session_lifecycle_model.dart`
- `lib/data/repositories/chat_repository_impl.dart`
- `lib/presentation/providers/chat_provider.dart`
- `lib/presentation/pages/chat_page.dart`
- `lib/presentation/widgets/chat_session_list.dart`
- `test/integration/opencode_server_integration_test.dart`
- `test/widget/chat_session_list_test.dart`

### References

- ADR-012: Realtime Event Reducer (provides event foundation for lifecycle events)
- ADR-014: Project/Workspace Context Orchestration (extends lifecycle to workspace context)
- https://opencode.ai/docs/server/
- https://github.com/anomalyco/opencode

### Implementation Reference

See CODEBASE.md for current module structure, file locations, and operational details:
- [Session Module](CODEBASE.md#session-module)
- [Feature 014: Session Lifecycle Architecture](CODEBASE.md#feature-014-session-lifecycle-architecture-2026-02-10)
- [Chat System Details](CODEBASE.md#chat-system-details)

---

## ADR-014: Project/Workspace Context Orchestration with Global Event Sync

**Status**: Accepted
**Date**: 2026-02-10

### Context

After multi-server/model/session parity improvements (ADR-010 through ADR-013), CodeWalk still risked context bleed between directories/projects because not all calls/events were consistently scoped. Workspace/worktree lifecycle operations were also missing, and project switching lacked deterministic state restoration for open/closed contexts. Users working across multiple project directories could see stale session lists or mixed context state.

### Decision

1. Adopt canonical context identity `contextKey = <serverId>::<directory-or-projectId>` for chat/session/model state snapshots and invalidation.
2. Expand project layer contracts with worktree operations:
   - `GET/POST/DELETE /experimental/worktree`
   - `POST /experimental/worktree/reset`
3. Add project/workspace context controls in chat UX:
   - switch active project
   - close/reopen project contexts
   - create/reset/delete/open worktrees
4. Scope app/chat use cases by active directory for provider/bootstrap/session/message/event calls.
5. Introduce global synchronization stream (`/global/event`) and mark non-active contexts dirty for deterministic refresh on return.
6. Harden realtime subscription cancellation with bounded timeout to prevent server-switch deadlocks during SSE teardown.

### Rationale

- OpenCode parity requires directory-aware orchestration, not only server-aware persistence (users expect project-scoped session history).
- Context-keyed snapshots allow fast switching without leaking stale state across directories (switch project, see correct sessions instantly).
- Global event routing gives low-latency cross-context coherence while keeping active-context updates lightweight (background contexts stay fresh).
- Worktree endpoints are required to expose upstream workspace workflows in mobile UX (create feature branch worktrees from UI).
- Bounded cancellation protects responsiveness when SSE streams are slow/unstable (prevents 30s hang on server switch).

### Consequences

- ✅ Positive: project/workspace switching is deterministic and directory-isolated.
- ✅ Positive: workspace/worktree lifecycle actions are available in app where server supports routes.
- ✅ Positive: non-active contexts are refreshed only when needed (dirty-bit model), reducing unnecessary reloads.
- ⚠️ Trade-off: provider orchestration complexity increased (snapshot map + dirty context set + global stream coordination).
- ⚠️ Trade-off: additional test/mocking surface required for `/global/event` and worktree endpoints.

### Key Files

- `lib/presentation/providers/project_provider.dart`
- `lib/presentation/providers/chat_provider.dart`
- `lib/presentation/pages/chat_page.dart`
- `lib/data/datasources/project_remote_datasource.dart`
- `lib/data/datasources/chat_remote_datasource.dart`
- `lib/domain/entities/worktree.dart`
- `lib/domain/usecases/watch_global_chat_events.dart`
- `test/integration/opencode_server_integration_test.dart`
- `test/support/mock_opencode_server.dart`

### References

- ADR-013: Session Lifecycle Orchestration (session scoping extended to project context)
- ADR-015: Parity Wave Release Gate (validates context isolation correctness)
- `ROADMAP.feat015.md`
- https://opencode.ai/docs/server/
- https://github.com/anomalyco/opencode

### Implementation Reference

See CODEBASE.md for current module structure, file locations, and operational details:
- [Feature 015: Project/Workspace Context Architecture](CODEBASE.md#feature-015-projectworkspace-context-architecture-2026-02-10)
- [Module Overview](CODEBASE.md#module-overview)

---

## ADR-015: Parity Wave Release Gate and QA Evidence Contract

**Status**: Accepted
**Date**: 2026-02-10

### Context

Features 011-015 (ADR-010 through ADR-014) introduced cross-cutting changes in server orchestration, model selection, realtime event handling, session lifecycle, and project/workspace context isolation. A final release wave needed one consistent quality contract to avoid shipping regressions caused by route/event/state interactions that are hard to validate with isolated unit checks only. The scope of changes was large enough that traditional unit testing alone was insufficient to catch integration issues.

### Decision

Adopt a release-readiness contract for Feature 016 with explicit evidence requirements:

1. Expand automated parity coverage across unit/widget/integration suites for multi-server + model/variant + event + session/workspace flows.
2. Execute a parity QA matrix with scenario IDs (`PAR-001`..`PAR-008`) and persist execution evidence.
3. Gate release readiness on:
   - runtime smokes for desktop/web,
   - platform build health (`linux`, `web`, `android`),
   - local precommit gate (`make precommit`),
   - documented known limitations and defect triage.
4. Publish release notes and roadmap signoff tied to concrete artifacts.

### Rationale

- The parity wave changed behavior in multiple state scopes (`serverId`, `directory`, session lifecycle, event streams), so release confidence must come from combined scenario validation, not only API-level checks.
- Scenario IDs provide repeatable regression tracking and make failures easier to triage across future iterations (e.g., "PAR-003 failed" is more actionable than "something broke").
- Enforcing evidence-first signoff in docs (`QA`, `ROADMAP`, `RELEASE_NOTES`) avoids undocumented release decisions and creates audit trail.
- Cross-platform validation (linux/web/android) catches platform-specific regressions early.

### Consequences

- ✅ Positive: release decisions are reproducible, auditable, and tied to objective artifacts.
- ✅ Positive: parity regressions are detected earlier through targeted matrix coverage.
- ✅ Positive: known limitations become explicit, reducing ambiguity during rollout.
- ⚠️ Trade-off: release cadence is slower due to additional QA and documentation gates.
- ⚠️ Trade-off: maintaining matrix artifacts increases process overhead for each parity release wave.

### Post-Gate Note (2026-02-10)

After the Feature 016 release gate was finalized, a series of post-release enhancements were shipped on the same wave: composer attachments (image/PDF via ADR-017), speech-to-text input (ADR-017), text selection unification, navigation restructure to chat-first layout (ADR-016), and project context dialog improvements. These changes followed the same quality discipline (precommit gate, test coverage, doc updates) but were not gated by a formal QA matrix. Future waves may benefit from defining a lightweight post-gate enhancement contract to track these incremental improvements.

### Key Files

- `QA.feat016.release-readiness.md`
- `ROADMAP.md`
- `CODEBASE.md`
- `RELEASE_NOTES.md`
- `Makefile`

### References

- ADR-010 through ADR-014: features validated by this gate
- ADR-016: Chat-First Navigation (post-gate enhancement)
- ADR-017: Composer Multimodal Input Pipeline (post-gate enhancement)

---

## ADR-016: Chat-First Navigation Architecture

**Status**: Accepted
**Date**: 2026-02-10

### Context

CodeWalk used a traditional multi-destination layout: `AppShellPage` was a `StatefulWidget` managing a `NavigationBar` (mobile) and `NavigationRail` (desktop) with three equal-weight destinations (Chat, Logs, Settings). This gave equal visual priority to all three sections, even though Chat is used ~95% of the time while Logs and Settings are accessed occasionally. The navigation state machine added complexity and required careful state restoration across hot reloads.

### Decision

1. Reduce `AppShellPage` to a `StatelessWidget` that renders `ChatPage` as the sole root.
2. Move Logs and Settings access into the chat sidebar as tonal button pairs above the session list.
3. Open Logs and Settings as push routes (`Navigator.push`) with native back navigation.
4. Remove `NavigationBar`, `NavigationRail`, and the `_selectedIndex` state machine entirely.

### Rationale

- Chat-first layout matches actual usage patterns: the primary interaction is always chat (observed 95%+ usage in analytics).
- Eliminating the navigation state machine reduces widget tree complexity and removes a class of index-based bugs (e.g., index out of range after hot reload).
- Push routes for secondary pages provide clear entry/exit semantics and work consistently across mobile (drawer close + push) and desktop (sidebar + push).
- Sidebar placement keeps Logs/Settings discoverable without competing for primary screen real estate (they're visible but not dominant).

### Consequences

- ✅ Positive: simpler `AppShellPage` (StatelessWidget, single child), fewer test permutations.
- ✅ Positive: chat always occupies full screen, no tab-switching latency or state restoration needed.
- ✅ Positive: Logs/Settings pages can be opened from both drawer and permanent sidebar with the same code path.
- ⚠️ Trade-off: users lose one-tap tab switching between Chat/Logs/Settings; secondary pages now require a back action to return.
- ⚠️ Trade-off: sidebar mixes app navigation (Logs/Settings buttons) with session management (session list), coupling two concerns in one panel.

### Key Files

- `lib/presentation/pages/app_shell_page.dart`
- `lib/presentation/pages/chat_page.dart`
- `test/widget/app_shell_page_test.dart`

### References

- ADR-015: Parity Wave Release Gate (post-gate enhancement)
- ADR-022: Modular Settings Hub (builds on navigation restructure)
- `ROADMAP.md`
- `CODEBASE.md`

---

## ADR-017: Composer Multimodal Input Pipeline

**Status**: Accepted
**Date**: 2026-02-10

### Context

The chat composer only supported plain text input. OpenCode server accepts file parts (images, PDFs) in message payloads and exposes model capability metadata that indicates which input modalities each model supports. Without multimodal input, CodeWalk could not leverage image/document-aware models (e.g., Claude with vision, GPT-4 with image input). Additionally, mobile users benefit from voice dictation as an alternative text input method, but the app had no speech integration.

### Decision

1. Extend `FileInputPart` entity with required `mime` and `url` fields (replacing the previous `source`-only contract) to match the server file part schema.
2. Add a file picker action in `ChatInputWidget` using `file_picker` for images and PDFs, with queued attachment chips and remove actions.
3. Wire `ChatProvider.sendMessage` to accept an optional `attachments` list and serialize file parts in the outbound payload alongside text parts.
4. Parse model `capabilities.input`/`capabilities.output` maps into normalized `modalities` lists in `ModelModel.fromJson`, supporting both list and map formats from the server.
5. Gate attachment and speech actions on model capability: hide the attachment button when the selected model does not support image/pdf input modalities.
6. Integrate `speech_to_text` package for voice dictation:
   - Add `RECORD_AUDIO` permission and `RecognitionService` query to Android manifest.
   - Lazy-initialize speech recognition with graceful fallback when unavailable.
   - Append recognized words to existing composer text with space-aware concatenation.
   - Auto-stop dictation on send.
7. Add a 300ms hold action on the send button to insert a newline (alternative to Shift+Enter on mobile).

### Rationale

- File part schema (`mime` + `url`) aligns with the server's expected payload format and enables future media types (audio, video) without entity changes.
- Capability-aware UI prevents users from attaching files to models that cannot process them, avoiding silent server errors or confusing "model doesn't support images" messages.
- Normalizing capabilities from both list and map formats handles server API inconsistencies observed in practice (upstream uses maps, but some deployments return lists).
- Speech-to-text is a platform capability that significantly improves mobile input ergonomics without adding server-side complexity (all processing happens on-device).
- Lazy speech initialization avoids blocking app startup on devices without microphone support (graceful degradation).

### Consequences

- ✅ Positive: users can send images and PDFs to capable models directly from the composer.
- ✅ Positive: voice input is available on supported devices with automatic fallback messaging.
- ✅ Positive: composer UI adapts dynamically to model capabilities, preventing invalid payloads.
- ⚠️ Trade-off: `FileInputPart` contract change is not backward-compatible; existing serialized data with only `source` field will not deserialize correctly (mitigated by the field being used only in transient input, not persisted).
- ⚠️ Trade-off: `speech_to_text` introduces a native platform dependency with per-platform permission requirements (Android manifest, iOS Info.plist).
- ⚠️ Trade-off: `ChatInputWidget` state grew significantly (attachment queue, speech state machine, hold timer).

### Key Files

- `lib/domain/entities/chat_session.dart` - `FileInputPart` entity with `mime`/`url`
- `lib/data/models/provider_model.dart` - `_normalizeModalityList`, `_modalitiesFromCapabilities`
- `lib/data/models/chat_session_model.dart` - file part serialization
- `lib/presentation/providers/chat_provider.dart` - `sendMessage` with attachments
- `lib/presentation/widgets/chat_input_widget.dart` - attachment picker, speech-to-text, hold-to-newline
- `android/app/src/main/AndroidManifest.xml` - `RECORD_AUDIO` permission
- `pubspec.yaml` - `speech_to_text` and `file_picker` dependencies

### References

- ADR-011: Model Selection and Variant Preference Orchestration (model capabilities integration)
- ADR-015: Parity Wave Release Gate (post-gate enhancement)
- ADR-019: Prompt Power Composer Triggers (extends composer input capabilities)
- `ROADMAP.md`
- `CODEBASE.md`

---

## ADR-018: Refreshless Realtime Sync with Lifecycle and Degraded Fallback

**Status**: Accepted
**Date**: 2026-02-10

### Context

Feature 017 required removing manual refresh interactions from chat/context flows and making SSE the primary sync mechanism. Before this change, the app still depended on explicit refresh actions (pull-to-refresh) and a periodic 5-second foreground polling loop. The prior behavior worked, but it increased network churn, duplicated responsibilities between UI polling and realtime events, and made lifecycle transitions (background/resume) less deterministic.

### Decision

1. Adopt refreshless-by-default behavior guarded by a runtime feature flag:
   - `CODEWALK_REFRESHLESS_ENABLED` (default `true`).
2. Introduce provider-level sync state machine:
   - `connected`, `reconnecting`, `delayed` (visible in UI).
3. Move stream lifecycle to explicit foreground/background control:
   - background: suspend event subscriptions and timers,
   - resume: re-subscribe and run one scoped reconcile pass.
4. Add degraded mode fallback when SSE health is poor:
   - enter degraded after repeated stream failures or stale signal threshold,
   - run slow scoped polling (30s) only while degraded,
   - auto-recover and stop polling when SSE signals resume.
5. Replace broad global refresh calls with scoped reconcile intents:
   - sessions refresh only when required,
   - active-session refresh only for message-level changes,
   - status refresh only when relevant.
6. Remove manual refresh controls from target chat/context UX when refreshless flag is enabled, and surface sync state in the app bar.

### Rationale

- SSE-first parity with upstream behavior reduces redundant polling and improves responsiveness (events arrive instantly vs 5s poll delay).
- Lifecycle-aware control prevents long-lived subscriptions from running while the app is backgrounded (saves battery, respects OS lifecycle).
- Degraded mode gives controlled resilience under unstable networks without reverting to aggressive polling (30s vs 5s).
- Scoped reconciliation keeps state fresh while minimizing unnecessary requests (only refresh what changed, not everything).
- Feature flag provides immediate rollback capability without code reversion (flip flag to restore old behavior).

### Consequences

- ✅ Positive: chat/context flows now update without explicit manual refresh actions.
- ✅ Positive: background/resume behavior is deterministic and test-covered.
- ✅ Positive: sync state is visible in UI and logs (`connected`, `reconnecting`, `delayed`).
- ✅ Positive: degraded polling is controlled and only active during stream-health degradation.
- ⚠️ Trade-off: `ChatProvider` orchestration complexity increased (state machine + timers + lifecycle branching).
- ⚠️ Trade-off: feature-flag split path needs ongoing test coverage to prevent regressions when toggled.

### Post-Decision Update (2026-02-13)

- Added config-backed selection reconciliation while app is active to reduce cross-device drift in open conversations:
  - periodic reconcile on sync-health ticks,
  - forced reconcile on `server.connected`,
  - forced reconcile on foreground resume and degraded sync passes.
- Reconcile scope is intentionally targeted to config-backed selection (`model`, `default_agent`, and app-scoped variant map) to preserve refreshless behavior and avoid broad polling regression.
- Selection reconcile tick runs in foreground even when refreshless feature flag is disabled, so model/agent/variant sync still converges without requiring a new outgoing message.
- Session-level selection overrides are merged by per-session `updatedAt` timestamp to reduce cross-device overwrite conflicts and keep restart hydration deterministic.

### Key Files

- `lib/core/config/feature_flags.dart`
- `lib/presentation/providers/chat_provider.dart`
- `lib/presentation/pages/chat_page.dart`
- `test/unit/providers/chat_provider_test.dart`
- `test/widget/chat_page_test.dart`

### References

- ADR-012: Realtime Event Reducer (provides event foundation for refreshless sync)
- ADR-006: Session SWR Cache (cache-first loading complements refreshless sync)
- `ROADMAP.md`
- `CODEBASE.md`

### Implementation Reference

See CODEBASE.md for current module structure, file locations, and operational details:
- [Chat Module](CODEBASE.md#chat-module)
- [Feature 017: Realtime-First Refreshless Architecture](CODEBASE.md#feature-017-realtime-first-refreshless-architecture-2026-02-10)

---

## ADR-019: Prompt Power Composer Triggers (`@`, `!`, `/`)

**Status**: Accepted
**Date**: 2026-02-10

### Context

Feature 018 required parity in the chat composer with OpenCode prompt-productivity triggers:

- `@` mention suggestions while typing (files, agents, context),
- `!` at offset 0 to enter shell mode with dedicated send route,
- `/` slash command catalog with builtin and server-provided commands.

Before this change, the mobile composer only supported plain text, attachments (ADR-017), and voice dictation. It lacked trigger grammar, contextual suggestion popovers, and shell routing, which made advanced workflows slower and inconsistent with upstream behavior.

### Decision

1. Extend `ChatInputWidget` to support structured compose behavior:
   - composer mode: `normal | shell`,
   - popover states: `none | mention | slash`,
   - keyboard navigation for suggestions (`ArrowUp/Down`, `Enter`, `Tab`, `Esc`),
   - inline mention token chips derived from `@token` text.
2. Keep message payload compatibility by preserving text-based prompt grammar for `@` and `/` (no breaking input-part schema changes for mentions).
3. Integrate shell mode send in provider/data layers:
   - provider sets `ChatInput.mode = 'shell'`,
   - datasource routes shell submissions to `POST /session/{id}/shell`,
   - request body contract: `{ agent: "build", command: "<text>" }`.
4. Integrate contextual suggestion sources in `ChatPage`:
   - mention suggestions: `/find/file` + `/agent`,
   - slash catalog: builtin command list + `/command` (`source` badges preserved),
   - builtin slash actions executed directly in UI (`/new`, `/model`, `/agent`, `/open`, `/help`).

### Rationale

- Trigger grammar in composer is a high-frequency UX path and should be first-class in the input widget rather than ad-hoc parsing at send time.
- Shell mode requires a dedicated route contract; reusing `/session/{id}/message` would diverge from server semantics (shell commands have different lifecycle).
- Keeping `@`/`/` as text-compatible grammar avoids risky payload schema changes while still delivering UX parity (popover + keyboard + insertion behavior).
- Fetching slash/mention catalogs from server endpoints keeps command/agent lists aligned with runtime capabilities (including skill/MCP-sourced commands).

### Consequences

- ✅ Positive: composer now supports `@`, `!`, and `/` productivity flows with keyboard and touch interaction.
- ✅ Positive: shell commands are sent through the proper shell endpoint and represented in chat timeline.
- ✅ Positive: slash catalog exposes command sources (builtin vs server vs skill), improving discoverability.
- ⚠️ Trade-off: mention handling remains text-token based (not fully structured token serialization in payload).
- ⚠️ Trade-off: slash builtin coverage is intentionally scoped; richer agent/command integrations continue in follow-up features.

### Key Files

- `lib/presentation/widgets/chat_input_widget.dart`
- `lib/presentation/pages/chat_page.dart`
- `lib/presentation/providers/chat_provider.dart`
- `lib/data/datasources/chat_remote_datasource.dart`
- `test/widget_test.dart`
- `test/unit/providers/chat_provider_test.dart`

### References

- ADR-017: Composer Multimodal Input Pipeline (extends composer capabilities)
- ADR-012: Realtime Event Reducer (shell commands generate events)
- `ROADMAP.md`
- `CODEBASE.md`

### Implementation Reference

See CODEBASE.md for current module structure, file locations, and operational details:
- [Chat Module](CODEBASE.md#chat-module)
- [Feature 018: Prompt Power Composer Architecture](CODEBASE.md#feature-018-prompt-power-composer-architecture-2026-02-10)

---

## ADR-020: File Explorer State and Context-Scoped Viewer Orchestration

**Status**: Accepted
**Date**: 2026-02-11

### Context

Feature 019 required parity for file navigation inside chat:

- expandable file tree (`/file`),
- quick-open search (`/find/file`),
- file viewer tabs (`/file/content`) with binary/error fallbacks.

CodeWalk already keeps project/session context scoped by `serverId::directory` (ADR-014). Without explicit explorer scoping, file trees/tabs could leak across contexts and show stale file content after session diffs or context switching.

### Decision

1. Introduce explicit file domain contracts in the project layer:
   - `FileNode` and `FileContent` entities
   - `ProjectRepository` methods: `listFiles`, `findFiles`, `readFileContent`
2. Keep explorer UI state local to `ChatPage`, keyed by `ProjectProvider.contextKey`, with:
   - directory tree cache per context,
   - tab state (`open/active`) per context,
   - lazy loading per directory node.
3. Add quick-open ranking/reducer utilities in a separate presentation utility module (`file_explorer_logic.dart`) for deterministic behavior and testability.
4. Reconcile viewer/tree state with `session.diff` realtime events by:
   - reloading matching open tabs,
   - invalidating affected directory nodes,
   - refreshing root tree lazily.
5. Use path-resolution fallback (absolute + context-relative candidates) for list/read operations to tolerate server differences around `path` handling.

### Rationale

- Context-keyed explorer state aligns with existing chat/provider context isolation (ADR-014) and prevents cross-project contamination.
- Keeping explorer orchestration in `ChatPage` avoids coupling file-view UI lifecycle with global provider state not needed outside chat.
- Utility extraction for ranking/tab reducers improves reuse and keeps logic unit-testable independently of widget lifecycle.
- Diff-aware refresh minimizes expensive full reloads while preserving correctness for open files (only reload changed files).

### Consequences

- ✅ Positive: users can explore, quick-open, and read files directly in chat with tab continuity.
- ✅ Positive: file explorer/viewer state remains isolated across server/directory contexts.
- ✅ Positive: fallback handling for binary/empty/error content prevents viewer crashes on unsupported files.
- ⚠️ Trade-off: `ChatPage` state complexity increased due to file orchestration and context caches.
- ⚠️ Trade-off: path fallback logic introduces extra request attempts in some server setups.

### Key Files

- `lib/domain/entities/file_node.dart`
- `lib/domain/repositories/project_repository.dart`
- `lib/data/models/file_node_model.dart`
- `lib/data/models/file_content_model.dart`
- `lib/data/datasources/project_remote_datasource.dart`
- `lib/presentation/providers/project_provider.dart`
- `lib/presentation/pages/chat_page.dart`
- `lib/presentation/utils/file_explorer_logic.dart`

### References

- ADR-014: Project/Workspace Context Orchestration (provides context scoping foundation)
- ADR-021: Responsive Dialog Sizing (file viewer UX)
- `ROADMAP.md`
- `CODEBASE.md`

### Implementation Reference

See CODEBASE.md for current module structure, file locations, and operational details:
- [Chat Module](CODEBASE.md#chat-module)
- [Feature 019: File Explorer and Viewer Parity](CODEBASE.md#feature-019-file-explorer-and-viewer-parity-2026-02-11)

---

## ADR-021: Responsive Dialog Sizing Standard and Files-Centered Viewer Surface

**Status**: Accepted
**Date**: 2026-02-11

### Context

After feature 019 (ADR-020), file viewing still appeared at the top of the chat conversation while the file tree lived in a dedicated `Files` surface (desktop side pane and mobile Files dialog). On mobile, opening a file from the Files dialog could feel detached because preview content remained behind that dialog.

At the same time, multiple dialogs used different sizing rules (some fullscreen, some adaptive). The project needed a clear cross-screen standard for dialog dimensions to maintain UX consistency.

### Decision

1. Move file preview focus from chat header area to the `Files` surface:
   - desktop: file preview remains in the Files pane,
   - mobile: file preview remains inside Files-related dialogs.
2. Add an explicit `N open files` control in the Files header (between title and quick actions) to open tab-management view.
3. Standardize open-files tab management UX in an adaptive dialog:
   - mobile/compact: `Dialog.fullscreen`,
   - larger screens: centered dialog constrained to approximately 70% of viewport width and height.
4. Adopt this sizing rule as the default dialog policy for new product dialogs unless a feature needs a documented exception.

### Rationale

- Keeping tree, open-tabs count, and preview in the same visual surface removes context switching and avoids "content opened behind overlay" perception.
- A single responsive dialog policy improves UX consistency across desktop and mobile (users know what to expect).
- The 70% cap on larger layouts preserves surrounding context and avoids full-screen modal fatigue on desktop.
- Fullscreen on mobile maximizes usable space, especially for long file tabs and code content.

### Consequences

- ✅ Positive: file navigation and preview are now centered in `Files`, not mixed into chat content area.
- ✅ Positive: open-file tab management is explicit and discoverable via `N open files`.
- ✅ Positive: dialog behavior is now predictable across breakpoints (mobile fullscreen, desktop centered 70%).
- ⚠️ Trade-off: some dialog interactions now require one additional step (`N open files`) for multi-tab management.
- ⚠️ Trade-off: dialog policy must be respected by future features to keep consistency.

### Key Files

- `lib/presentation/pages/chat_page.dart`
- `test/widget/chat_page_test.dart`
- `CODEBASE.md`

### References

- ADR-020: File Explorer State (file viewer implementation)
- ADR-022: Modular Settings Hub (also uses responsive dialog sizing)
- `ROADMAP.md`

---

## ADR-022: Modular Settings Hub and Experience Preference Orchestration

**Status**: Accepted
**Date**: 2026-02-11

### Context

CodeWalk settings had become a server-centric screen (`ServerSettingsPage`) while product scope expanded to include broader operational preferences (notifications, sounds, shortcuts). This structure did not scale to future settings domains and created tight coupling between server controls and unrelated UX preferences.

Feature 022 required parity with OpenCode settings behaviors across:

- category-level notifications (`agent`, `permissions`, `errors`),
- category-level sound preferences with preview,
- dedicated shortcut management (search/edit/reset/conflict validation),
- responsive behavior for both mobile and desktop.

### Decision

1. Replace settings-as-server-screen with a modular `SettingsPage` hub:
   - section descriptors with stable IDs,
   - mobile list->detail flow,
   - desktop split layout (section list + content pane).
2. Keep server management as one section (`Servers`) and preserve existing route entry compatibility via `ServerSettingsPage` wrapper.
3. Introduce `SettingsProvider` + persisted `ExperienceSettings` schema for notification, sound, and shortcut preferences.
   - notifications read server-backed values from `/config` when known keys are exposed, with local fallback when absent.
4. Add platform adapters for experience feedback:
   - `NotificationService` using local notifications with platform fallback,
   - `SoundService` using generated in-memory WAV playback (`audioplayers`) with graceful fallback.
5. Integrate event feedback through a dedicated dispatcher (`EventFeedbackDispatcher`) wired into `ChatProvider` reducer events.
   - finish notifications use focused title format `Finished: <session title>` when session context is available.
   - notification payload carries `sessionId` to support deep-linking to the originating session on tap.
6. Move chat keyboard activation to runtime-configurable bindings resolved from persisted shortcuts (`ShortcutBindingCodec`) with conflict validation in settings UI.
   - expose shortcut-management section only on desktop/web platforms.
7. Enable Android compatibility requirements for notification plugin:
   - `POST_NOTIFICATIONS` permission,
   - core library desugaring in Gradle.
8. Expand notification controls to per-category split toggles:
   - `Notify` (system notification),
   - `Sound` (audible feedback),
   - allowing independent preference combinations per event type (`agent`, `permissions`, `errors`).
9. Consolidate sound configuration under `Notifications` and remove the standalone `Sounds` section to avoid duplicate controls.

### Rationale

- A settings hub with sections is the minimal scalable architecture for future domains (appearance, accessibility, etc.) while keeping current UX stable.
- Separating server orchestration from experience preferences reduces coupling and avoids turning settings into a single monolith page.
- Provider-backed persisted preference state enables deterministic behavior across restart and platform differences.
- Dynamic shortcut binding keeps parity with upstream keybind editing while preserving existing defaults.
- Event dispatcher centralizes feedback triggering rules and avoids spreading platform effect logic across chat state mutations.

### Consequences

- ✅ Positive: settings now support multiple independent domains without navigation redesign.
- ✅ Positive: users can control notification/sound behavior by category and adjust shortcut bindings safely.
- ✅ Positive: chat shortcut behavior and settings UI are now synchronized through one persisted source of truth.
- ✅ Positive: platform differences are handled via adapter fallback and logged diagnostics.
- ✅ Positive: notification tap can route users directly to the session that generated the event.
- ⚠️ Trade-off: additional provider/service layers increase initialization and DI complexity.
- ⚠️ Trade-off: notification plugin introduces Android build constraints (desugaring + permission maintenance).
- ⚠️ Trade-off: web notifications depend on browser permission and only emit click callbacks while app runtime is active.

### Key Files

- `lib/presentation/pages/settings_page.dart`
- `lib/presentation/pages/settings/sections/servers_settings_section.dart`
- `lib/presentation/pages/settings/sections/notifications_settings_section.dart`
- `lib/presentation/pages/settings/sections/shortcuts_settings_section.dart`
- `lib/domain/entities/experience_settings.dart`
- `lib/presentation/providers/settings_provider.dart`
- `lib/presentation/services/event_feedback_dispatcher.dart`
- `lib/presentation/services/notification_service.dart`
- `lib/presentation/services/sound_service.dart`
- `lib/presentation/utils/shortcut_binding_codec.dart`
- `lib/presentation/pages/chat_page.dart`
- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`

### References

- ADR-016: Chat-First Navigation (settings accessed from sidebar)
- ADR-021: Responsive Dialog Sizing (settings uses responsive layout)
- `ROADMAP.feat022.md`
- `CODEBASE.md`

### Implementation Reference

See CODEBASE.md for current module structure, file locations, and operational details:
- [Settings Module](CODEBASE.md#settings-module)
- [Module Overview](CODEBASE.md#module-overview)

---

## ADR-023: Deprecated API Modernization and Web Interop Migration

**Status**: Accepted
**Date**: 2026-02-11

### Context

Static analysis identified a concentrated group of deprecated API usages and one web bridge compile/runtime risk:

- deprecated color API usage (`withOpacity`, `surfaceVariant`, `background`, `onBackground`),
- deprecated form field initialization usage (`DropdownButtonFormField.value`),
- async context usage warnings in `ChatPage`,
- deprecated browser interop (`dart:html`) and invalid `window.focus` path in the web notification bridge,
- deprecated markdown dependency (`flutter_markdown`).

These issues created future-upgrade risk for Flutter SDK evolution and reduced maintainability signal in `flutter analyze` (141 issues baseline).

### Decision

1. Replace color API deprecations with current Material/Color APIs:
   - `withOpacity` -> `withValues(alpha: ...)`,
   - `surfaceVariant` -> `surfaceContainerHighest`,
   - `background` -> `surface`,
   - `onBackground` -> `onSurface`.
2. Replace deprecated `DropdownButtonFormField.value` with `initialValue` in settings sections.
3. Resolve async-context warnings in `ChatPage` by:
   - capturing providers/messenger before `await`,
   - validating the correct mounted context before post-await UI operations.
4. Replace web bridge implementation from `dart:html` to `package:web` + JS interop helpers.
5. Replace `flutter_markdown` with `flutter_markdown_plus`.

### Rationale

- Staying current with Flutter API evolution prevents tech debt accumulation and future migration pain.
- Color API migration aligns with Material Design 3 specification and ensures forward compatibility.
- Async-context fixes prevent subtle bugs where unmounted widgets try to show snackbars/dialogs.
- `package:web` is the official Dart web interop path forward (dart:html is being phased out).
- `flutter_markdown_plus` is the maintained fork with continued Flutter SDK compatibility.

### Consequences

- ✅ Positive: all target deprecations and async-context warnings for this maintenance wave are removed.
- ✅ Positive: web notification bridge no longer relies on deprecated `dart:html` and removes the previous focus-related compile issue.
- ✅ Positive: static analysis signal improves (baseline dropped from 141 to 55 issues, with residual lints outside this feature scope).
- ⚠️ Trade-off: broad UI replacement touched multiple presentation files, increasing short-term merge-conflict probability.
- ⚠️ Trade-off: analyzer is still non-zero because residual lints were intentionally left out of Feature 023 scope.

### Key Files

- `lib/presentation/pages/chat_page.dart`
- `lib/presentation/pages/home_page.dart`
- `lib/presentation/pages/logs_page.dart`
- `lib/presentation/widgets/chat_message_widget.dart`
- `lib/presentation/services/web_notification_bridge_web.dart`
- `lib/presentation/pages/settings/sections/notifications_settings_section.dart`
- `lib/presentation/pages/settings/sections/servers_settings_section.dart`
- `lib/presentation/theme/app_theme.dart`
- `pubspec.yaml`

### References

- ADR-022: Modular Settings Hub (settings sections updated with new form field API)
- `ROADMAP.md`
- `CODEBASE.md`

---

## ADR-024: Desktop Composer/Pane Interaction and Active-Response Abort Semantics

**Status**: Accepted
**Date**: 2026-02-11

### Context

Backlog prioritization highlighted friction in the desktop chat workflow:

- desktop send/newline shortcuts were not aligned with common editor/chat patterns (most users expect Enter to send, Shift+Enter for newline),
- side panes consumed horizontal space with no user-controlled collapse state,
- composer editability was blocked while assistant response was in progress,
- there was no first-class Stop action wired to session abort while streaming.

The expected behavior required preserving existing mention/slash keyboard behavior (ADR-019) and avoiding regressions in ongoing response state handling.

### Decision

1. On desktop/web targets, map composer keyboard behavior to:
   - `Enter` -> submit message,
   - `Shift+Enter` -> insert newline.
2. Keep composer text input enabled while assistant is responding, but block new sends until response completes or user presses Stop.
3. Replace `Send` action with `Stop` while response is active and route Stop to `/session/{id}/abort` through a dedicated `AbortChatSession` use case injected into `ChatProvider`.
4. Add user-controlled collapse/restore for desktop panes (`Conversations`, `Files`, `Utility`) and persist visibility in `ExperienceSettings.desktopPanes`.
5. Keep existing popover/shortcut flows intact by applying desktop send handling only when composer popovers are not consuming Enter.
6. Treat abort-originated cancellation errors (`aborted/canceled` variants) as expected outcomes for a short suppression window, keeping chat state in `loaded` instead of transitioning to global error/retry fallback.
7. Keep send-stream lifecycle race-safe across rapid `Stop -> Send` transitions by invalidating prior stream generations, ignoring stale callbacks, and preserving mutability of `_messages` after abort finalization.
8. On mobile, set composer input action to `send` and dismiss keyboard focus after successful submission to preserve viewport space for incoming messages.

### Rationale

- Enter-to-send matches user expectations from common chat applications (Slack, Discord, ChatGPT web).
- Pane collapse control is a standard desktop UX pattern (VS Code, IntelliJ) for managing screen real estate.
- Stop affordance aligns with OpenCode Desktop/Web behavior and prevents "can't stop a runaway response" frustration.
- Error suppression for user-initiated abort prevents confusing error states when stopping is an intentional action.
- Stream generation guards prevent race conditions where rapid stop/send leaves the UI in inconsistent state.

### Consequences

- ✅ Positive: desktop chat interaction now matches expected ergonomics for multi-line drafting and quick send.
- ✅ Positive: users can reclaim conversation width without losing preferred pane layout across app restarts.
- ✅ Positive: active responses can be interrupted through an explicit Stop affordance without freezing text editing.
- ✅ Positive: user-triggered Stop no longer replaces the conversation with a full-screen error/retry state for expected cancellation messages.
- ✅ Positive: immediate follow-up prompts after Stop no longer require manual `Retry` to recover conversation visibility.
- ✅ Positive: mobile message flow keeps more conversation content visible immediately after submit by dismissing keyboard/focus.
- ⚠️ Trade-off: chat input/button state machine is more complex and now depends on both local send state and provider response/abort state.
- ⚠️ Trade-off: abort-error suppression relies on a short session-scoped timing window and message pattern matching, which adds subtle provider state heuristics.
- ⚠️ Trade-off: stream-generation guards add additional provider-side state that must stay consistent with subscription cancellation points.
- ⚠️ Trade-off: additional persisted experience keys increase migration surface for settings serialization.

### Key Files

- `lib/presentation/widgets/chat_input_widget.dart`
- `lib/presentation/pages/chat_page.dart`
- `lib/presentation/providers/chat_provider.dart`
- `lib/domain/usecases/abort_chat_session.dart`
- `lib/core/di/injection_container.dart`
- `lib/domain/entities/experience_settings.dart`
- `lib/presentation/providers/settings_provider.dart`
- `test/widget/chat_page_test.dart`
- `test/widget_test.dart`
- `test/unit/providers/settings_provider_test.dart`

### References

- ADR-019: Prompt Power Composer Triggers (preserves popover keyboard behavior)
- ADR-022: Modular Settings Hub (pane preferences persisted via settings provider)
- `ROADMAP.md`
- `CODEBASE.md`

### Implementation Reference

See CODEBASE.md for current module structure, file locations, and operational details:
- [Chat Module](CODEBASE.md#chat-module)
- [Settings Module](CODEBASE.md#settings-module)

---

## ADR-025: Automatic Session Title Generation via ch.at API

**Status**: Accepted
**Date**: 2026-02-12

### Context

Sessions created without explicit titles fell back to timestamp-only labels (e.g., "2/12 14:23"), which provided no semantic context in session lists. Users had to manually rename sessions or open them to identify content. OpenCode Desktop/Web address this with background AI title generation, creating a parity gap and friction in mobile session management.

### Decision

1. Integrate external title generation service (`ch.at` API) for background session labeling.
2. Generate titles after each user/assistant turn using first 3 user + 3 assistant text messages.
3. Add per-server privacy toggle `Enable AI generated titles` (default off) in Settings > Servers.
4. Apply platform-aware word limits: 4 words on mobile, 6 on desktop.
5. Use consolidation guard to stop after 3+3 baseline is reached.
6. Add stale-guard to prevent overwrites on rapid context/session switches.

### Rationale

- AI-generated titles improve session list UX without manual intervention (mobile users benefit most).
- External service (`ch.at`) avoids bundling model inference in mobile app.
- Privacy toggle respects user preference for AI processing of conversation content.
- Platform-aware limits optimize for screen real estate (mobile = shorter).
- Consolidation guard prevents redundant API calls after baseline context is captured.

### Consequences

- ✅ Positive: session titles are semantic and require no manual naming.
- ✅ Positive: privacy-aware with explicit opt-in per server.
- ⚠️ Trade-off: external API dependency introduces network requirement for titles.
- ⚠️ Trade-off: failure fallback is timestamp label (acceptable degradation).
- ⚠️ Trade-off: titles are best-effort approximations, not perfect summaries.

### Key Files

- `lib/presentation/services/chat_title_generator.dart`
- `lib/presentation/providers/chat_provider.dart`
- `lib/domain/entities/server_profile.dart`
- Settings > Servers section

### References

- Commit: 8c49591
- CODEBASE.md: Session Module (auto-title generation)
- ADR-013: Session Lifecycle Orchestration

---
