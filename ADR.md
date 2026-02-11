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

---

## ADR-010: Multi-Server Profile Orchestration and Scoped Persistence

Status: Accepted  
Date: 2026-02-09

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
- Isolated persistence prevents cross-server data contamination, a critical correctness requirement.
- Health-aware activation aligns UX with upstream behavior and reduces invalid switch failures.
- Idempotent migration preserves backward compatibility while enabling new architecture.

### Consequences

- Positive: users can manage multiple servers (add/edit/remove, active/default) with deterministic routing behavior.
- Positive: cached sessions/current session/model selections no longer bleed across servers.
- Positive: server switch UX is available from settings and chat app bar, reducing context-switch friction.
- Trade-off: provider and local-storage logic became more complex due to scoped key strategy and migration support.
- Trade-off: temporary fallback handling for legacy keys must be maintained until a future cleanup window.

### Key Files

- `lib/domain/entities/server_profile.dart` - server profile entity model
- `lib/core/constants/app_constants.dart` - v2 multi-server/scoped storage keys
- `lib/data/datasources/app_local_datasource.dart` - scoped persistence API and profile storage
- `lib/presentation/providers/app_provider.dart` - server orchestration, migration, health checks
- `lib/presentation/providers/chat_provider.dart` - server-scoped chat/session/model cache handling
- `lib/presentation/pages/server_settings_page.dart` - server manager UI
- `lib/presentation/pages/chat_page.dart` - quick server switch control

### References

- `ROADMAP.feat011.md`
- `ROADMAP.md`
- https://opencode.ai/docs/server/

---

## ADR-011: Model Selection and Variant Preference Orchestration

Status: Accepted  
Date: 2026-02-09

### Context

After Feature 011 established multi-server state isolation, CodeWalk still lacked parity for model control: no in-app provider/model picker, no variant (reasoning effort) controls, and no persistence strategy for recent/frequent model usage. Without this, users could not reliably steer model behavior and outbound prompt payloads could not express variant-specific intent.

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
   - recent model keys
   - model usage counts (frequent model signal)
5. Add composer-level controls in chat UI for provider/model selection and reasoning cycle.

### Rationale

- Model/variant selection is a direct parity requirement with upstream OpenCode Desktop/Web.
- Variant-aware payloads are necessary to control reasoning effort where models expose multiple variants.
- Recent/frequent persistence improves recovery when defaults or provider inventories change across restarts.
- Server/context scoping preserves isolation guarantees introduced in Feature 011.

### Consequences

- Positive: users can choose provider/model from chat UI and cycle reasoning variant when available.
- Positive: outbound prompt bodies include `variant`, achieving payload parity for current send flow.
- Positive: restored preferences now account for both explicit selection and historical usage.
- Trade-off: `ChatProvider` state machine complexity increased with preference loading/fallback logic.
- Trade-off: additional persisted keys require migration-aware maintenance in future storage refactors.

### Key Files

- `lib/domain/entities/provider.dart`
- `lib/data/models/provider_model.dart`
- `lib/domain/entities/chat_session.dart`
- `lib/data/models/chat_session_model.dart`
- `lib/data/datasources/app_local_datasource.dart`
- `lib/presentation/providers/chat_provider.dart`
- `lib/presentation/pages/chat_page.dart`

### References

- `ROADMAP.feat012.md`
- `ROADMAP.md`
- https://opencode.ai/docs/models/

---

## ADR-012: Realtime Event Reducer and Interactive Prompt Orchestration

Status: Accepted  
Date: 2026-02-09

### Context

CodeWalk handled message updates mostly inside `sendMessage()` with a narrow SSE subset, limited part rendering, and no user-action flow for `permission.*` and `question.*` events. This caused parity gaps with current OpenCode clients: missing lifecycle/status synchronization, weak resilience under stream reconnects, and no in-app interactive approval/question handling.

### Decision

1. Introduce a dedicated realtime event subscription path in chat data/repository layers with reconnect + bounded backoff behavior.
2. Move high-value event handling into a provider-level reducer in `ChatProvider` for:
   - `session.*` status and metadata updates
   - `message.*` updates/removals
   - `permission.*` and `question.*` ask/reply lifecycle queues
3. Add targeted message fallback fetch (`GetChatMessage`) when event payloads are partial/delta-based.
4. Expand message part taxonomy support in parser + UI for:
   - `agent`, `step-start`, `step-finish`, `snapshot`, `subtask`, `retry`, `compaction`, `patch`
   - Note (2026-02-10): `step-start` and `step-finish` details were later moved from inline rendering to the assistant info menu to reduce visual noise in the message flow.
5. Add interactive UI cards for pending permission/question requests and connect them to response endpoints.

### Rationale

- Event handling must be centralized and deterministic to avoid state drift across long sessions.
- Delta/partial event payloads are common and require fallback fetch to prevent lost data.
- Permission/question flows are blocking interaction paths; without in-app actions, user tasks stall.
- Rendering extended part taxonomy avoids silent data loss and improves parity/debug visibility.

### Consequences

- Positive: realtime state reflects broader OpenCode event surface with reconnect tolerance.
- Positive: interactive permission/question requests are now actionable directly in mobile UI.
- Positive: message lifecycle fidelity improved via reducer + targeted fallback fetch.
- Trade-off: `ChatProvider` gained additional orchestration complexity and larger in-memory state maps.
- Trade-off: test surface increased (unit/widget/integration), requiring stronger regression discipline.

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

- `ROADMAP.feat013.md`
- `ROADMAP.md`
- https://opencode.ai/docs/server/
- https://github.com/anomalyco/opencode

---

## ADR-013: Session Lifecycle Orchestration with Optimistic Mutations and Insight Hydration

Status: Accepted  
Date: 2026-02-10

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
4. Introduce lifecycle insight orchestration in `ChatProvider` to hydrate and maintain `status`, `children`, `todo`, and `diff` maps, including reducer handling for `todo.updated` and `session.diff`.
5. Expand session list UX to include filter/sort/search/load-more controls and add lifecycle action menu coverage in widget/integration tests.

### Rationale

- Lifecycle mutation latency should not block UX responsiveness, so optimistic local updates are required.
- Rollback paths are mandatory to preserve state correctness when API operations fail.
- Insight hydration aligns mobile behavior with OpenCode Desktop/Web visibility for session state beyond message text.
- Query windowing controls are needed to keep session history navigation performant as data volume grows.
- Dedicated lifecycle endpoint coverage in the mock server and integration tests prevents regressions in parity-critical flows.

### Consequences

- Positive: session management now supports parity-level lifecycle operations and metadata.
- Positive: users get immediate UI feedback on lifecycle actions with automatic recovery on failures.
- Positive: session insight data is now visible and synchronized through both API pulls and realtime events.
- Trade-off: `ChatProvider` state orchestration became more complex (optimistic state + rollback + insight caches).
- Trade-off: larger test surface area increases maintenance cost but improves confidence against regressions.

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

- `ROADMAP.md`
- https://opencode.ai/docs/server/
- https://github.com/anomalyco/opencode

---

## ADR-014: Project/Workspace Context Orchestration with Global Event Sync

Status: Accepted  
Date: 2026-02-10

### Context

After multi-server/model/session parity improvements, CodeWalk still risked context bleed between directories/projects because not all calls/events were consistently scoped. Workspace/worktree lifecycle operations were also missing, and project switching lacked deterministic state restoration for open/closed contexts.

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

- OpenCode parity requires directory-aware orchestration, not only server-aware persistence.
- Context-keyed snapshots allow fast switching without leaking stale state across directories.
- Global event routing gives low-latency cross-context coherence while keeping active-context updates lightweight.
- Worktree endpoints are required to expose upstream workspace workflows in mobile UX.
- Bounded cancellation protects responsiveness when SSE streams are slow/unstable.

### Consequences

- Positive: project/workspace switching is deterministic and directory-isolated.
- Positive: workspace/worktree lifecycle actions are available in app where server supports routes.
- Positive: non-active contexts are refreshed only when needed (dirty-bit model), reducing unnecessary reloads.
- Trade-off: provider orchestration complexity increased (snapshot map + dirty context set + global stream coordination).
- Trade-off: additional test/mocking surface required for `/global/event` and worktree endpoints.

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

- `ROADMAP.feat015.md`
- `ROADMAP.md`
- https://opencode.ai/docs/server/
- https://github.com/anomalyco/opencode

---

## ADR-015: Parity Wave Release Gate and QA Evidence Contract

Status: Accepted  
Date: 2026-02-10

### Context

Features 011-015 introduced cross-cutting changes in server orchestration, model selection, realtime event handling, session lifecycle, and project/workspace context isolation. A final release wave needed one consistent quality contract to avoid shipping regressions caused by route/event/state interactions that are hard to validate with isolated unit checks only.

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
- Scenario IDs provide repeatable regression tracking and make failures easier to triage across future iterations.
- Enforcing evidence-first signoff in docs (`QA`, `ROADMAP`, `RELEASE_NOTES`) avoids undocumented release decisions.

### Consequences

- Positive: release decisions are reproducible, auditable, and tied to objective artifacts.
- Positive: parity regressions are detected earlier through targeted matrix coverage.
- Positive: known limitations become explicit, reducing ambiguity during rollout.
- Trade-off: release cadence is slower due to additional QA and documentation gates.
- Trade-off: maintaining matrix artifacts increases process overhead for each parity release wave.

### Post-Gate Note (2026-02-10)

After the Feature 016 release gate was finalized, a series of post-release enhancements were shipped on the same wave: composer attachments (image/PDF), speech-to-text input, text selection unification, navigation restructure to chat-first layout, and project context dialog improvements. These changes followed the same quality discipline (precommit gate, test coverage, doc updates) but were not gated by a formal QA matrix. Future waves may benefit from defining a lightweight post-gate enhancement contract to track these incremental improvements.

### Key Files

- `QA.feat016.release-readiness.md`
- `ROADMAP.md`
- `CODEBASE.md`
- `RELEASE_NOTES.md`
- `Makefile`

### References

- `ROADMAP.md`
- `QA.feat016.release-readiness.md`

---

## ADR-016: Chat-First Navigation Architecture

Status: Accepted
Date: 2026-02-10

### Context

CodeWalk used a traditional multi-destination layout: `AppShellPage` was a `StatefulWidget` managing a `NavigationBar` (mobile) and `NavigationRail` (desktop) with three equal-weight destinations (Chat, Logs, Settings). This gave equal visual priority to all three sections, even though Chat is used ~95% of the time while Logs and Settings are accessed occasionally.

### Decision

1. Reduce `AppShellPage` to a `StatelessWidget` that renders `ChatPage` as the sole root.
2. Move Logs and Settings access into the chat sidebar as tonal button pairs above the session list.
3. Open Logs and Settings as push routes (`Navigator.push`) with native back navigation.
4. Remove `NavigationBar`, `NavigationRail`, and the `_selectedIndex` state machine entirely.

### Rationale

- Chat-first layout matches actual usage patterns: the primary interaction is always chat.
- Eliminating the navigation state machine reduces widget tree complexity and removes a class of index-based bugs.
- Push routes for secondary pages provide clear entry/exit semantics and work consistently across mobile (drawer close + push) and desktop (sidebar + push).
- Sidebar placement keeps Logs/Settings discoverable without competing for primary screen real estate.

### Consequences

- Positive: simpler `AppShellPage` (StatelessWidget, single child), fewer test permutations.
- Positive: chat always occupies full screen, no tab-switching latency or state restoration needed.
- Positive: Logs/Settings pages can be opened from both drawer and permanent sidebar with the same code path.
- Trade-off: users lose one-tap tab switching between Chat/Logs/Settings; secondary pages now require a back action to return.
- Trade-off: sidebar mixes app navigation (Logs/Settings buttons) with session management (session list), coupling two concerns in one panel.

### Key Files

- `lib/presentation/pages/app_shell_page.dart`
- `lib/presentation/pages/chat_page.dart`
- `test/widget/app_shell_page_test.dart`

### References

- `ROADMAP.md`
- `CODEBASE.md`

---

## ADR-018: Refreshless Realtime Sync with Lifecycle and Degraded Fallback

Status: Accepted
Date: 2026-02-10

### Context

Feature 017 required removing manual refresh interactions from chat/context flows and making SSE the primary sync mechanism. Before this change, the app still depended on explicit refresh actions and a periodic 5-second foreground polling loop. The prior behavior worked, but it increased network churn, duplicated responsibilities between UI polling and realtime events, and made lifecycle transitions (background/resume) less deterministic.

### Decision

1. Adopt refreshless-by-default behavior guarded by a runtime feature flag:
   - `CODEWALK_REFRESHLESS_ENABLED` (default `true`).
2. Introduce provider-level sync state machine:
   - `connected`, `reconnecting`, `delayed`.
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

- SSE-first parity with upstream behavior reduces redundant polling and improves responsiveness.
- Lifecycle-aware control prevents long-lived subscriptions from running while the app is backgrounded.
- Degraded mode gives controlled resilience under unstable networks without reverting to aggressive polling.
- Scoped reconciliation keeps state fresh while minimizing unnecessary requests.
- Feature flag provides immediate rollback capability without code reversion.

### Consequences

- Positive: chat/context flows now update without explicit manual refresh actions.
- Positive: background/resume behavior is deterministic and test-covered.
- Positive: sync state is visible in UI and logs (`connected`, `reconnecting`, `delayed`).
- Positive: degraded polling is controlled and only active during stream-health degradation.
- Trade-off: `ChatProvider` orchestration complexity increased (state machine + timers + lifecycle branching).
- Trade-off: feature-flag split path needs ongoing test coverage to prevent regressions when toggled.

### Key Files

- `lib/core/config/feature_flags.dart`
- `lib/presentation/providers/chat_provider.dart`
- `lib/presentation/pages/chat_page.dart`
- `test/unit/providers/chat_provider_test.dart`
- `test/widget/chat_page_test.dart`

### References

- `ROADMAP.md`
- `CODEBASE.md`

---

## ADR-019: Prompt Power Composer Triggers (`@`, `!`, `/`)

Status: Accepted
Date: 2026-02-10

### Context

Feature 018 required parity in the chat composer with OpenCode prompt-productivity triggers:

- `@` mention suggestions while typing,
- `!` at offset 0 to enter shell mode with dedicated send route,
- `/` slash command catalog with builtin and server-provided commands.

Before this change, the mobile composer only supported plain text, attachments, and voice dictation. It lacked trigger grammar, contextual suggestion popovers, and shell routing, which made advanced workflows slower and inconsistent with upstream behavior.

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
- Shell mode requires a dedicated route contract; reusing `/session/{id}/message` would diverge from server semantics.
- Keeping `@`/`/` as text-compatible grammar avoids risky payload schema changes while still delivering UX parity (popover + keyboard + insertion behavior).
- Fetching slash/mention catalogs from server endpoints keeps command/agent lists aligned with runtime capabilities (including skill/MCP-sourced commands).

### Consequences

- Positive: composer now supports `@`, `!`, and `/` productivity flows with keyboard and touch interaction.
- Positive: shell commands are sent through the proper shell endpoint and represented in chat timeline.
- Positive: slash catalog exposes command sources, improving discoverability for builtin vs server-provided commands.
- Trade-off: mention handling remains text-token based (not fully structured token serialization in payload).
- Trade-off: slash builtin coverage is intentionally scoped; richer agent/command integrations continue in follow-up features.

### Key Files

- `lib/presentation/widgets/chat_input_widget.dart`
- `lib/presentation/pages/chat_page.dart`
- `lib/presentation/providers/chat_provider.dart`
- `lib/data/datasources/chat_remote_datasource.dart`
- `test/widget_test.dart`
- `test/unit/providers/chat_provider_test.dart`

### References

- `ROADMAP.md`
- `CODEBASE.md`

---

## ADR-017: Composer Multimodal Input Pipeline

Status: Accepted
Date: 2026-02-10

### Context

The chat composer only supported plain text input. OpenCode server accepts file parts (images, PDFs) in message payloads and exposes model capability metadata that indicates which input modalities each model supports. Without multimodal input, CodeWalk could not leverage image/document-aware models. Additionally, mobile users benefit from voice dictation as an alternative text input method, but the app had no speech integration.

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

- File part schema (`mime` + `url`) aligns with the server's expected payload format and enables future media types without entity changes.
- Capability-aware UI prevents users from attaching files to models that cannot process them, avoiding silent server errors.
- Normalizing capabilities from both list and map formats handles server API inconsistencies observed in practice.
- Speech-to-text is a platform capability that significantly improves mobile input ergonomics without adding server-side complexity.
- Lazy speech initialization avoids blocking app startup on devices without microphone support.

### Consequences

- Positive: users can send images and PDFs to capable models directly from the composer.
- Positive: voice input is available on supported devices with automatic fallback messaging.
- Positive: composer UI adapts dynamically to model capabilities, preventing invalid payloads.
- Trade-off: `FileInputPart` contract change is not backward-compatible; existing serialized data with only `source` field will not deserialize correctly (mitigated by the field being used only in transient input, not persisted).
- Trade-off: `speech_to_text` introduces a native platform dependency with per-platform permission requirements (Android manifest, iOS Info.plist).
- Trade-off: `ChatInputWidget` state grew significantly (attachment queue, speech state machine, hold timer).

### Key Files

- `lib/domain/entities/chat_session.dart` - `FileInputPart` entity with `mime`/`url`
- `lib/data/models/provider_model.dart` - `_normalizeModalityList`, `_modalitiesFromCapabilities`
- `lib/data/models/chat_session_model.dart` - file part serialization
- `lib/presentation/providers/chat_provider.dart` - `sendMessage` with attachments
- `lib/presentation/widgets/chat_input_widget.dart` - attachment picker, speech-to-text, hold-to-newline
- `android/app/src/main/AndroidManifest.xml` - `RECORD_AUDIO` permission
- `pubspec.yaml` - `speech_to_text` and `file_picker` dependencies

### References

- `ROADMAP.md`
- `CODEBASE.md`

---

## ADR-020: File Explorer State and Context-Scoped Viewer Orchestration

Status: Accepted
Date: 2026-02-11

### Context

Feature 019 required parity for file navigation inside chat:

- expandable file tree (`/file`),
- quick-open search (`/find/file`),
- file viewer tabs (`/file/content`) with binary/error fallbacks.

CodeWalk already keeps project/session context scoped by `serverId::directory`. Without explicit explorer scoping, file trees/tabs could leak across contexts and show stale file content after session diffs or context switching.

### Decision

1. Introduce explicit file domain contracts in the project layer:
   - `FileNode` and `FileContent` entities
   - `ProjectRepository` methods: `listFiles`, `findFiles`, `readFileContent`
2. Keep explorer UI state local to `ChatPage`, keyed by `ProjectProvider.contextKey`, with:
   - directory tree cache per context,
   - tab state (`open/active`) per context,
   - lazy loading per directory node.
3. Add quick-open ranking/reducer utilities in a separate presentation utility module (`file_explorer_logic.dart`) for deterministic behavior and testability.
4. Reconcile viewer/tree state with `session.diff` by:
   - reloading matching open tabs,
   - invalidating affected directory nodes,
   - refreshing root tree lazily.
5. Use path-resolution fallback (absolute + context-relative candidates) for list/read operations to tolerate server differences around `path` handling.

### Rationale

- Context-keyed explorer state aligns with existing chat/provider context isolation and prevents cross-project contamination.
- Keeping explorer orchestration in `ChatPage` avoids coupling file-view UI lifecycle with global provider state not needed outside chat.
- Utility extraction for ranking/tab reducers improves reuse and keeps logic unit-testable independently of widget lifecycle.
- Diff-aware refresh minimizes expensive full reloads while preserving correctness for open files.

### Consequences

- Positive: users can explore, quick-open, and read files directly in chat with tab continuity.
- Positive: file explorer/viewer state remains isolated across server/directory contexts.
- Positive: fallback handling for binary/empty/error content prevents viewer crashes on unsupported files.
- Trade-off: `ChatPage` state complexity increased due to file orchestration and context caches.
- Trade-off: path fallback logic introduces extra request attempts in some server setups.

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

- `ROADMAP.md`
- `CODEBASE.md`
