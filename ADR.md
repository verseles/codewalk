# Architecture Decision Records (Current State)

This document contains only active architectural decisions that represent the current implementation.

## Index

- ADR-001: Multi-Server Orchestration, Scoped Persistence, and Secure Credential Storage
- ADR-002: Context Isolation with `serverId::directory` and Workspace/Worktree Orchestration
- ADR-003: Realtime-First Sync Lifecycle with Degraded Fallback and Platform-Aware Background Policy
- ADR-004: Chat Architecture with Slim Orchestrators and Decomposed Clusters
- ADR-005: Composer Pipeline for Multimodal Input, Prompt Triggers, and Send/Stop Semantics
- ADR-006: Speech Input Architecture with `SpeechInputService` and Platform Policy
- ADR-007: Modular Settings Architecture for Experience, Notifications, Sounds, and Shortcuts
- ADR-008: Context-Scoped File Explorer and Viewer with Quick Open and Diff-Aware Refresh
- ADR-009: Native Session Title Generation via Internal `title` Agent
- ADR-010: Delivery Pipeline Split for CI Quality, Tagged Releases, and Minor-Tag Smoke Checks
- ADR-011: Unified Server Setup Wizard (Onboarding and Settings)
- ADR-012: Material Symbols Migration via `material_symbols_icons`
- ADR-013: MD3 WindowSizeClass Responsive Breakpoint Strategy
- ADR-014: Centralized MD3 Design Tokens for Shapes and Brand Colors
- ADR-015: Platform-Specific Icon Asset Pipeline for Tray, Android Notifications, and macOS Launcher Masking
- ADR-016: Hybrid File-Backed Cache for Large Chat Payloads
- ADR-017: Android Foreground Service for Reliable Background Monitoring
- ADR-018: Dedicated SSE Dio Instance for Connection Pool Isolation
- ADR-019: Defer Config-Mutating API Calls During Active Server Processing
- ADR-020: Session-Level SWR Cache with Persisted LRU Snapshots
- ADR-021: Context-Scoped Draft State for Project-Switch SWR
- ADR-022: Unified Project Context Controls with Sidebar Session Previews
- ADR-023: Official OpenCode Contract-First Compatibility Policy
- ADR-024: Modal Enter Keyboard Policy for Safe Dialogs
- ADR-025: Settled Assistant-Work Disclosure Ownership
- ADR-026: Cross-Platform Terminal Workspace with Local PTY Shell ⚠️ SUPERSEDED by ADR-027
- ADR-027: Server-Hosted PTY Terminal with Embedded Client Rendering
- ADR-028: Unified Scroll Ownership Model for Chat Timeline
- ADR-029: Host-Discovered Quota and Rate-Limit Monitoring for OpenChamber Parity
- ADR-030: OpenChamber-Driven Realtime Hardening and Permission Continuity
- ADR-031: Historical Inline Revert via OpenCode Session Revert Endpoint
- ADR-032: LaTeX Math Rendering with flutter_math_fork and Custom Markdown Delimiters
- ADR-033: Cloudflare Access OAuth as Optional Desktop Reverse-Proxy Auth (ADR-023 Exception)
- ADR-034: Density-Aware Spacing Tokens via `AppDensitySpacing` Static Helper
- ADR-035: Message-Derived Selection Fallback with Explicit-Override Precedence
- ADR-036: Userspace Tailscale Transport with Profile-Scoped Activation
- ADR-037: Chat Viewport and Scroll/Follow Synchronization Revamp
- ADR-038: Disable On-Device STT Engines on Windows Desktop
- ADR-039: Real Windows STT Fix — Actionable Settings Links and Typed Microphone Preflight
- ADR-040: Client-Owned Per-Project Icon Discovery
- ADR-041: Chat Stability Invariants for Delta Reconciliation and Final Reveal
- ADR-042: Global App Logs Toggle with Default-Off and Lazy Performance Instrumentation
- ADR-043: Files as a Shell-Gated Micro File Manager with Capability-Probed Mutations (ADR-023 Exception)
- ADR-044: Windows STT Final Fix — Runner-Owned WASAPI Microphone Backend and Re-Enabled On-Device Engines
- ADR-045: CodeWalk Refined Visual Layer Over Material Stack
- ADR-046: Client-Side Cloud TTS Provider Architecture ⚠️ SUPERSEDED by ADR-047
- ADR-047: Experimental Direct Microsoft Edge/Bing Read Aloud TTS via Client WebSocket
- ADR-048: Adaptive First-Run Read-Aloud TTS Defaults
- ADR-049: Cross-Platform Attention Surfaces and Secure Background Continuity
- ADR-052: Bounded Default-Off Autosave Addendum for the Focused File Editor
- ADR-053: Client-Owned Configurable API Speech-to-Text (OpenAI / Groq / Custom OpenAI-Compatible)
- ADR-054: Experimental Test-Only Android Auto Notification Messaging ⚠️ SUPERSEDED by ADR-055
- ADR-055: Production Android Auto Notification Messaging for Sideloaded APK Distribution

---



## ADR-001: Multi-Server Orchestration, Scoped Persistence, and Secure Credential Storage (2026-02-19)

**Status**: Accepted

### Context

CodeWalk must support multiple OpenCode servers with deterministic active/default routing, isolated runtime state, and secure storage for credentials. Flat global persistence causes cross-server leakage and plaintext secrets create unnecessary risk.

### Decision

Adopt a server-profile architecture with active/default selection, health-aware activation, server/context-scoped persistence keys, and secure credential storage migration to `flutter_secure_storage`.

### Rationale

- Multi-environment usage (local/dev/staging/prod) requires first-class server profiles.
- Scoped persistence avoids cache/model/session contamination across server boundaries.
- Credentials must be isolated from plaintext preference payloads.

### Consequences

- ✅ Enables deterministic multi-server operation with isolated state.
- ✅ Reduces credential exposure by moving auth secrets to secure storage.
- ⚠ Adds migration and hydration complexity between secure and non-secure stores.
- ❌ Legacy flat-key paths remain unsupported as a long-term architecture.

### Key Files

- `lib/presentation/providers/app_provider.dart`
- `lib/data/datasources/app_local_datasource.dart`
- `lib/core/constants/app_constants.dart`
- `lib/domain/entities/server_profile.dart`
- `lib/presentation/pages/server_settings_page.dart`

---

## ADR-002: Context Isolation with `serverId::directory` and Workspace/Worktree Orchestration (2026-02-19)

**Status**: Accepted

### Context

Session, selection, and file state must remain isolated per server and per workspace directory. Users also require explicit workspace/worktree operations without losing context integrity.

### Decision

Standardize context identity as `serverId::scopeId` (directory-first, project fallback), and orchestrate project/worktree lifecycle through context-aware provider flows. Project scope transitions (project switches, workspace create/delete, project close/reopen) are serialized through a single-flight queue (`_runProjectScopeTransition`) with `Completer`-based tracking to prevent race conditions from rapid user actions.

### Rationale

- A canonical context key is required for deterministic caching and reconciliation.
- Directory-level isolation matches how OpenCode sessions are scoped in practice.
- Worktree operations are part of active workspace lifecycle, not an external side flow.

### Consequences

- ✅ Prevents cross-context bleed in session/model/selection state.
- ✅ Supports explicit project switching and worktree lifecycle management.
- ⚠ Increases coordination between project and chat providers.
- ⚠ All scope-changing operations must flow through the serialization queue; bypassing it risks concurrent state corruption.
- ❌ Invalid scope keys are rejected instead of silently merged.

**Note** (commits `cb324c4`, `785eee8`): Scope transition serialization queue added.

### Key Files

- `lib/presentation/providers/project_provider.dart`
- `lib/presentation/providers/chat_provider/chat_provider_context_state_ops.dart`
- `lib/presentation/pages/chat_page/chat_page_workspace_controller.dart`
- `lib/data/datasources/project_remote_datasource.dart`
- `lib/domain/repositories/project_repository.dart`

---

## ADR-003: Realtime-First Sync Lifecycle with Degraded Fallback and Platform-Aware Background Policy (2026-02-19)

**Status**: Accepted

### Context

The app requires realtime-first behavior for session/message coherence, but it must tolerate stream instability and honor platform-specific background constraints.

### Decision

Use realtime streams as the primary sync mechanism, automatically enter degraded polling when signals fail/stale, and apply platform-aware background policies (desktop tray continuity, mobile hold/fallback strategy). Active message-response streams are preserved (not cancelled) during session navigation to maintain in-flight response continuity. Preserved streams are tracked in a dedicated set and drained on every context switch to prevent connection leaks. A generation counter (`_messageStreamGeneration`) invalidates stale preserved-stream callbacks, preventing cross-session state mutation. Session lifecycle remains server-authoritative: follow-up prompts ride the standard async send path, and the client does not invent local queued/batched send phases.

### Rationale

- Realtime provides best UX for active conversations and event-driven prompts.
- Degraded polling prevents hard desync when streams degrade.
- Desktop and mobile need distinct background lifecycle behavior.

### Consequences

- ✅ Maintains near-live UX under normal connectivity.
- ✅ Preserves functional sync under stream degradation.
- ✅ Preserves in-flight AI responses during session navigation, matching OpenCode Web continuity behavior.
- ✅ Keeps busy/idle/send lifecycle aligned with upstream server events instead of local queue orchestration.
- ⚠ Lifecycle orchestration becomes more stateful and timing-sensitive.
- ⚠ Generation-based invalidation is required to prevent stale preserved streams from mutating current session state; all preserved subscriptions must be drained on context switches.
- ❌ Continuous background streaming is not guaranteed on mobile.

**Note** (commits `acce617`, `9dcd773`, `37f0397`): Preserved stream lifecycle, drain-on-context-switch, and generation invalidation added.

**Note** (commit `77592fa`): Fixed stale-persisted-session-ID race condition where `loadSessions()` triggered by global events could read a stale session ID from disk and revert an in-memory session switch. Three defensive guards added: `selectSession()` now invalidates `_sessionsFetchId`, `loadLastSession()` prioritizes in-memory `_currentSession?.id` over persisted ID, and `_restoreLastSessionSnapshotFromCache()` guards against overwriting an already-switched session.

**Note** (commit `1fcf33e`): SSE streams are now served by a dedicated Dio instance (`_sseDio`) with an isolated connection pool, preventing Android HTTP client from evicting SSE connections when regular HTTP requests compete for TCP connections during session switches. See ADR-018.

**Note**: In polling-only background monitoring (when push notifications are unavailable), added a 5-minute tail probe after active sessions end to reduce missed notifications. Implementation uses `kBackgroundTailProbeInterval` (5 minutes) as the constant and `shouldScheduleBackgroundTailProbe()` to determine eligibility based on session state and platform support.

**Note** (commit `161b9ce`): Tightened current-session active-turn detection — incomplete `assistant`/`current` sending state remains active even if idle status arrives early, preventing premature turn completion detection. Also narrowed unsupported global `message.*` fallback reconcile — only the visible current session can trigger active-session refresh when no active local stream/compaction guard is in effect.

**Note** (issue #83): Per-session event-scope policy — the realtime stream remains authoritative, but event application is now scoped by whether the session is the current one. The **active session keeps full realtime** behavior (full messages, diffs, todos applied as they arrive). **Non-current sessions do not fetch or apply full message payloads, message diffs, or todos from SSE**; their status signals are summarized/deduped by event type rather than expanded into per-message work, keeping background contexts cheap to track. The following categories remain **alertable/indicator-producing across all sessions** (including non-current): permission/question requests (v1 and v2), `session.error`, and `session.idle` / final-completion transitions. **Inactive context snapshots now receive `session.error` and permission/question state**, so background context indicators stay coherent when the user returns. **Re-entering a session relies on cache-first SWR plus active revalidation** — see ADR-020. This is a pure client-side routing/filtering layer over existing OpenCode SSE events: no server contract changes, no new endpoints, no semantic drift from the official event stream (ADR-023 compliant).

**Note** (issue #98): ADR-049 permits the sole exception to the non-current full-message-fetch rule: after an authoritative `session.idle`, a bounded, directory-scoped final message fetch may run only for the matching root session on the active server, identified by the exact `serverId`, directory, and session ID. It is for secure attention display/speech snapshots only; it does not apply diffs, fetch child sessions, or broaden background sync.

**Note** (2026-08-17): Foreground reconciliation is now coalesced and visible-state-preserving. Android-only forced resume handles the mobile short-hold case; standard data-saver reconciliation skips stale last-session snapshot hydration; and disposal guards prevent subscription recreation. No OpenCode protocol or SSE contract semantics changed, and no ADR-023 exception is required.

**Note** (2026-08-21): Android background lifecycle boundary — see ADR-017's anti-regression rule: while background alerts are enabled, `CodeWalkForegroundService` must keep running during backgrounding so the process retains foreground-service priority; paused mode and mobile-hold expiry re-run `_applyForegroundPolicy` instead of unconditionally disabling the monitor.

### Key Files

- `lib/presentation/providers/chat_provider.dart`
- `lib/presentation/providers/chat_provider/chat_provider_event_reducer_global_ops.dart`
- `lib/presentation/providers/chat_provider/chat_provider_lifecycle_ops.dart`
- `lib/presentation/providers/chat_provider/chat_provider_realtime_ops.dart`
- `lib/presentation/providers/chat_provider/chat_provider_realtime_aux_ops.dart`
- `lib/presentation/pages/chat_page.dart`
- `lib/presentation/pages/chat_page/chat_page_lifecycle.dart`
- `lib/presentation/pages/app_shell_page.dart`
- `lib/presentation/services/desktop_tray_service.dart`
- `lib/presentation/services/android_background_alert_worker.dart`
- `lib/presentation/providers/chat_provider/chat_provider_session_ops.dart`
- `lib/presentation/providers/chat_provider/chat_provider_cache_persistence_ops.dart`

---

## ADR-004: Chat Architecture with Slim Orchestrators and Decomposed Clusters (2026-02-19)

**Status**: Accepted

### Context

Core chat surfaces were previously oversized and difficult to evolve safely. The active architecture requires stable orchestrator entry points with decomposed implementation clusters.

### Decision

Keep `chat_page.dart`, `chat_provider.dart`, and `chat_input_widget.dart` as slim orchestrators and move operational concerns into focused part files and clustered subfolders.

### Rationale

- Orchestrator shells preserve clear ownership boundaries.
- Decomposition reduces regression risk and review overhead.
- Clustered parts improve local reasoning and targeted testing.

### Consequences

- ✅ Better maintainability for high-change chat surfaces.
- ✅ Faster iteration on isolated subsystems.
- ⚠ More files and indirection require stronger naming discipline.
- ❌ Monolithic single-file workflows are no longer supported.

### Key Files

- `lib/presentation/pages/chat_page.dart`
- `lib/presentation/pages/chat_page/`
- `lib/presentation/providers/chat_provider.dart`
- `lib/presentation/providers/chat_provider/`
- `lib/presentation/widgets/chat_input_widget.dart`
- `lib/presentation/widgets/chat_input/`

**Note** (commit `8759defc`): Aggressive `part`/`part of` file split extended to four more large files beyond the original chat cluster. The five target files were reduced from 14,087 to 12,534 lines (−1,553). The split is purely mechanical refactoring to keep private members library-scoped — no new architectural pattern introduced, same part-file decomposition precedent as above.

**Note** (plan `ca14f6af`, commits `76b5de49`, `e0cd8048`, `bbcc2e71`): Second pass split three more chat-surface files: `chat_page_timeline_builder.dart` (2,436→1,158 + 2 part files), `chat_page.dart` (2,646→2,168 + 1 part file), `chat_provider.dart` (4,206→3,788 + 1 part file). **Boundary condition**: `lib/data/datasources/chat_remote_datasource.dart` (2,401 lines) could NOT be split because it `implements ChatRemoteDataSource` (22 abstract methods); Dart extensions cannot satisfy abstract class overrides, so part/extension decomposition is inapplicable when the file's primary class must honor an interface contract. This limitation applies to any class whose public API is defined by an `abstract class` or `interface` — those files must stay monolithic or use a different decomposition strategy (e.g., delegation/mixin, separate impl classes).

---

## ADR-005: Composer Pipeline for Multimodal Input, Prompt Triggers, and Send/Stop Semantics (2026-02-19)

**Status**: Accepted

### Context

The composer must combine text and attachments, support power triggers (`@`, `!`, `/`), and provide explicit response-stop behavior without breaking input continuity.

### Decision

Implement a state-driven composer pipeline with multimodal submission contracts, mention/slash trigger controllers, shell-mode trigger (`!`), and guarded send/stop interactions. Busy-session follow-up prompts use the same direct async send path as normal turns; the composer does not maintain a client-side queued/send-now subsystem, and `Stop` remains a separate explicit abort action when no draft is ready to send.

### Rationale

- Multimodal composition is a core chat capability, not an optional extension.
- Triggered flows reduce friction for file/agent/command actions.
- Stop semantics must be intentional to avoid accidental aborts.

### Consequences

- ✅ Supports rich prompt composition in a single interaction surface.
- ✅ Improves power-user speed via trigger-based flows.
- ✅ Allows direct follow-up sends during active responses without coupling them to implicit aborts or local batching.
- ⚠ State transitions are denser and require strict event handling.
- ❌ Shell mode and attachments are intentionally mutually exclusive at send time.

### Key Files

- `lib/presentation/widgets/chat_input_widget.dart`
- `lib/presentation/widgets/chat_input/chat_input_state_machine.dart`
- `lib/presentation/widgets/chat_input/chat_input_mentions_controller.dart`
- `lib/presentation/widgets/chat_input/chat_input_commands_controller.dart`
- `lib/presentation/widgets/chat_input/chat_input_attachment_controller.dart`
- `lib/presentation/widgets/chat_input/chat_input_send_controller.dart`

---

## ADR-006: Speech Input Architecture with `SpeechInputService` and Platform Policy (2026-02-19)

**Status**: Accepted

### Context

Speech input must remain pluggable while respecting platform constraints: Linux favors downloadable on-device engines, desktop can expose Moonshine, Parakeet V3 (sherpa_onnx offline NeMo transducer), or SenseVoice (sherpa_onnx offline recognition) through the existing sherpa_onnx stack, while Android uses native STT in slim builds. Linux now defaults to Parakeet for new installs; existing native selections are migrated to Parakeet because native STT is disabled on Linux.

### Decision

Use `SpeechInputService` as the abstraction contract, register native, Sherpa, desktop Moonshine, desktop Parakeet (offline NeMo transducer via sherpa_onnx), and desktop SenseVoice (sherpa_onnx offline recognition) implementations behind DI, enforce platform policy in settings/runtime selection (Linux defaults to Parakeet with automatic migration from native), and keep Android artifacts slim by excluding sherpa_onnx native libs from Android builds.

### Rationale

- A stable service interface isolates UI from backend engine specifics.
- Linux and Android have different practical/runtime constraints.
- Build-size policy must be codified in architecture, not left to manual process.

### Consequences

- ✅ Keeps speech UX stable while allowing backend specialization.
- ✅ Enforces deterministic engine policy per platform.
- ✅ SenseVoice adds a strong desktop option for Chinese, Cantonese, Japanese, Korean, and English via sherpa_onnx offline recognition.
- ✅ Linux default to Parakeet with automatic migration prevents broken native-engine state on new installs.
- ⚠ Feature parity between engines is not guaranteed at all times.
- ❌ Sherpa/Moonshine/Parakeet/SenseVoice are unavailable in Android slim build profile.

### Key Files

- `lib/presentation/services/speech_input_service.dart`
- `lib/presentation/services/speech_input_service_stt.dart`
- `lib/presentation/services/speech_input_service_sherpa.dart`
- `lib/presentation/services/speech_input_service_sherpa_io.dart`
- `lib/presentation/services/speech_input_service_moonshine_io.dart`
- `lib/presentation/services/speech_input_service_parakeet.dart`
- `lib/presentation/services/speech_input_service_parakeet_io.dart`
- `lib/presentation/services/speech_input_service_sensevoice.dart`
- `lib/presentation/services/speech_input_service_sensevoice_io.dart`
- `lib/presentation/services/speech_input_service_sensevoice_stub.dart`
- `lib/presentation/services/moonshine_model_manager_io.dart`
- `lib/presentation/services/parakeet_model_manager.dart`
- `lib/presentation/services/parakeet_model_manager_io.dart`
- `lib/presentation/services/sensevoice_model_manager_io.dart`
- `lib/presentation/widgets/sensevoice_model_download_dialog.dart`
- `lib/presentation/providers/settings_provider.dart`
- `lib/presentation/pages/settings/sections/speech_settings_section.dart`
- `lib/core/di/injection_container.dart`
- `android/app/build.gradle.kts`

---

## ADR-007: Modular Settings Architecture for Experience, Notifications, Sounds, and Shortcuts (2026-02-19)

**Status**: Accepted

### Context

Settings include cross-cutting concerns (visual density, notifications, sounds, shortcuts, speech, platform behavior) and require a coherent state/persistence model.

### Decision

Adopt `SettingsProvider` as the orchestration layer over a typed `ExperienceSettings` contract, with modular settings sections and integrated notification/sound/shortcut policies.

### Rationale

- Strongly typed settings reduce drift and migration errors.
- Provider orchestration centralizes persistence and side-effect handling.
- Modular sections keep UX scalable as settings grow.

### Consequences

- ✅ Unified settings lifecycle across desktop/mobile.
- ✅ Predictable persistence and policy application.
- ⚠ Provider complexity grows with cross-cutting preferences.
- ❌ Ad hoc local setting storage outside `ExperienceSettings` is disallowed.

### Key Files

- `lib/presentation/providers/settings_provider.dart`
- `lib/domain/entities/experience_settings.dart`
- `lib/presentation/pages/settings_page.dart`
- `lib/presentation/pages/settings/sections/notifications_settings_section.dart`
- `lib/presentation/pages/settings/sections/shortcuts_settings_section.dart`
- `lib/presentation/services/notification_service.dart`
- `lib/presentation/services/sound_service.dart`

---

## ADR-008: Context-Scoped File Explorer and Viewer with Quick Open and Diff-Aware Refresh (2026-02-19)

**Status**: Accepted

### Context

File browsing and viewing must stay scoped to the active context, support tabbed navigation, offer fast quick-open discovery, and refresh affected nodes when session diffs change.

### Decision

Implement a context-scoped file state model in chat runtime, with tree cache + tab state, ranked quick-open search, and diff-signature-based selective refresh.

### Rationale

- File UX is tightly coupled to active workspace context.
- Quick-open requires deterministic ranking to be useful at scale.
- Diff-aware invalidation avoids full refresh churn.

### Consequences

- ✅ Faster file navigation with scoped caches and quick-open.
- ✅ Reduced unnecessary reloads through selective invalidation.
- ⚠ Requires careful synchronization between file state and chat diff data.
- ❌ Global cross-context file tabs are intentionally not supported.

### Key Files

- `lib/presentation/pages/chat_page/chat_page_file_explorer_controller.dart`
- `lib/presentation/pages/chat_page/chat_page_file_viewer.dart`
- `lib/presentation/pages/chat_page/chat_page_file_runtime.dart`
- `lib/presentation/utils/file_explorer_logic.dart`
- `lib/presentation/providers/project_provider.dart`
- `lib/domain/repositories/project_repository.dart`

---

## ADR-009: Native Session Title Generation via Internal `title` Agent (2026-02-19)

**Status**: Accepted

### Context

Session title generation must be server-native and event-safe, without relying on external title services. The flow must avoid polluting user-visible session history while still participating in runtime event streams, keep requests scoped to the active directory, and avoid polling for completion.

### Decision

Generate titles through a native ephemeral session titled `_title_gen` using OpenCode agent `title`, with directory-scoped create/prompt/GET/DELETE requests. `session.idle` from the official local and global SSE streams acts only as a completion trigger and is forwarded to the generator before ephemeral event filtering. After the SSE trigger, perform exactly one authoritative message GET; if the trigger is missed, wait on a bounded 15s timeout and then issue the same single GET. The title is never derived from event parts. Context switch/dispose cancel pending waiters and skip the GET, but still DELETE the ephemeral session and keep the trailing-event prune; realtime/data-saver stream teardown without background suppression may fall back to the timeout path. Ephemeral lifecycle events are filtered from chat state, and title updates are applied only after contextual safety checks.

### Rationale

- Internal agent flow removes external dependency and alignment risk.
- Directory-scoped requests keep generation tied to the active workspace.
- `session.idle` as the sole trigger plus a single authoritative GET replaces polling and avoids event-part-derived titles.
- Ephemeral session filtering prevents UI/state contamination.
- Context safety checks prevent stale or cross-context title writes.
- Cancellation on context switch/dispose avoids wasted GETs while preserving ephemeral session cleanup.

### Consequences

- ✅ Title generation is now fully native to server capabilities.
- ✅ Eliminates external service coupling for title synthesis.
- ✅ Reduces request/byte volume versus polling: one authoritative message GET per title.
- ⚠ Adds bounded waiter/ephemeral-session complexity (waiter map, 15s timeout fallback, cancellation paths).
- ❌ External title providers are not part of the active architecture.

**Note** (issue #139): Title generation reworked from polling to an SSE-triggered flow — `session.idle` from local/global SSE (forwarded before ephemeral filtering) completes a bounded waiter with a 15s timeout fallback, followed by exactly one authoritative message GET; requests are directory-scoped; context switch/dispose cancel pending waiters and skip the GET while still deleting the ephemeral session and pruning trailing events.

### Key Files

- `lib/presentation/services/chat_title_generator.dart`
- `lib/presentation/providers/chat_provider/chat_provider_auto_title_ops.dart`
- `lib/presentation/providers/chat_provider/chat_provider_realtime_aux_ops.dart`
- `lib/presentation/providers/chat_provider/chat_provider_event_reducer_session_ops.dart`
- `lib/presentation/providers/chat_provider/chat_provider_event_reducer_global_ops.dart`
- `lib/presentation/pages/onboarding_wizard_page.dart`

---

## ADR-010: Delivery Pipeline Split for CI Quality, Tagged Releases, and Minor-Tag Smoke Checks (2026-02-19)

**Status**: Accepted

### Context

The project needs fast quality validation on normal development events, full artifact builds only for tagged releases, and targeted smoke validation for minor release tags.

### Decision

Separate workflows by intent: quality-only CI on push/PR, multi-platform release builds on version tags, and OpenCode smoke checks on minor-tag pushes.

### Rationale

- Quality checks should remain fast and always-on for iteration velocity.
- Release artifact generation is expensive and should be tag-triggered.
- Minor-tag smoke runs provide an additional operational safety net.

### Consequences

- ✅ Faster default CI feedback loop for daily development.
- ✅ Deterministic release pipeline with tag-driven artifact generation.
- ⚠ Requires disciplined tag/version management.
- ❌ Full release builds are intentionally not executed on every push/PR.

### Key Files

- `.github/workflows/ci.yml`
- `.github/workflows/release.yml`
- `.github/workflows/opencode-smoke.yml`
- `Makefile`
- `tool/ci/check_analyze_budget.sh`
- `tool/ci/check_coverage.sh`

---

## ADR-011: Unified Server Setup Wizard (Onboarding and Settings) (2026-02-19)

**Status**: Accepted

### Context

The app had no first-run experience; it opened directly to ChatPage with connection errors when no server was configured, leaving new users without guidance.

### Decision

Gate the main shell in `AppShellPage` via `Consumer2` checks on `serverProfiles` and `skipOnboardingWizard` flag. Introduce `OnboardingWizardPage` with a 3-step flow (Welcome, Server Setup, Ready). Persist the skip flag in `ExperienceSettings`. The wizard is also surfaced at the top of Server Settings as the canonical server setup entry point, consolidating the previously separate inline setup form into the same wizard flow used during onboarding.

### Rationale

- New users need guided setup to configure at least one server before using the app.
- Gating at the shell level ensures no partial UI is shown before configuration is complete.
- A persistent flag allows existing users to bypass the wizard entirely.

### Consequences

- ✅ New users see a guided setup flow that prevents unconfigured-state errors.
- ✅ Existing users are unaffected; the wizard is skipped when profiles already exist.
- ✅ "Reset app" in About allows returning to the wizard state for re-onboarding.
- ⚠ Adds a gating layer in `AppShellPage` that must stay synchronized with profile state.
- ✅ Server setup consolidated into a single wizard flow, reducing code duplication and ensuring consistent setup UX across first-run and settings contexts.
- ❌ The wizard flow is intentionally linear; non-linear onboarding is not supported.

### Key Files

- `lib/presentation/pages/app_shell_page.dart`
- `lib/presentation/pages/onboarding_wizard_page.dart`
- `lib/domain/entities/experience_settings.dart`
- `lib/presentation/providers/settings_provider.dart`
- `lib/presentation/pages/settings/sections/servers_settings_section.dart`

**Note** (commit `bd12170`): The wizard was unified to serve both first-run onboarding and settings-page server setup. The previous inline server setup form in `servers_settings_section.dart` was replaced with the wizard flow, consolidating 613 lines of duplicated setup logic.

---

## ADR-012: Material Symbols Migration via `material_symbols_icons` (2026-02-20)

**Status**: Accepted

### Context

The codebase used Flutter `Icons.*` references broadly, but feature requirements introduced symbols that are only available in Material Symbols (for example, panel-specific close icons). The project also needs broader icon coverage and a future-proof path aligned with Google's current design direction.

Related: historical `featM` workstream (commit `e05d2fb`).

### Decision

Standardize icon usage on `Symbols.*` from `material_symbols_icons` and migrate existing `Icons.*` references to symbol equivalents, keeping static symbol constants in code paths to preserve Flutter tree-shaking behavior.

### Rationale

- Material Symbols provides broader coverage than legacy Material Icons and unblocks missing-icon cases.
- The package tracks Material Symbols updates and aligns with the ecosystem direction, reducing migration risk later.
- Static references keep icon fonts optimizable during build, avoiding unnecessary asset growth from dynamic lookups.

### Consequences

- ✅ Access to the Material Symbols catalog and consistent icon language across mobile and desktop.
- ✅ Future-friendly alignment with Google's symbol-first direction for new UI work.
- ⚠ Naming adjustments are required (`Icons.*` to `Symbols.*`), including variant suffix differences in some cases.
- ⚠ Visual style parity must be reviewed case-by-case where Symbols metrics/appearance differ from previous Icons usage.
- ❌ Dynamic or computed icon indirection is intentionally discouraged to preserve static references and tree-shaking efficiency.

### Key Files

- `pubspec.yaml`
- `lib/`

---

## ADR-013: MD3 WindowSizeClass Responsive Breakpoint Strategy (2026-02-20)

**Status**: Accepted

### Context

The UI layer relied on hardcoded pixel breakpoints (e.g. `_isMobileViewport` checks against arbitrary widths) scattered across multiple widgets and pages. This made responsive behavior inconsistent and difficult to reason about, especially when distinguishing phone, tablet, and desktop layouts. The `featN` Material You revamp required a systematic approach aligned with MD3 guidelines.

Related: historical `featN` workstream.

### Decision

Introduce a `WindowSizeClass` enum with five tiers matching MD3 Window Size Classes: Compact (<600dp), Medium (600–839dp), Expanded (840–1199dp), Large (1200–1599dp), ExtraLarge (≥1600dp). Provide convenience getters (`isCompact`, `isAtLeastExpanded`, etc.) and use `WindowSizeClass.fromWidth()` as the single source of truth for responsive decisions. Replace all hardcoded breakpoint checks with `WindowSizeClass` queries.

Additionally, redefine the mobile-viewport guard: the previous `_isMobileViewport` (which only checked `isCompact`) was replaced with `!isAtLeastExpanded` to ensure mobile-oriented gestures and layouts also apply on Medium/tablet breakpoints, not just phone-sized screens.

### Rationale

- MD3 Window Size Classes are the canonical responsive framework for Material-based apps.
- A single enum centralizes all breakpoint logic, eliminating scattered magic numbers.
- The `!isAtLeastExpanded` guard correctly captures the intent: mobile gestures should work on any viewport smaller than desktop-class, including tablets in the Medium range.
- Convenience getters improve readability and reduce error-prone raw comparisons.

### Consequences

- ✅ Consistent responsive behavior across all UI surfaces via a single canonical breakpoint model.
- ✅ Mobile gesture/layout guard (`!isAtLeastExpanded`) correctly includes tablet/medium viewports.
- ✅ Aligns with MD3 specification, reducing drift as Material guidelines evolve.
- ⚠ All existing breakpoint checks must be migrated to `WindowSizeClass` queries.
- ❌ Arbitrary per-widget breakpoint overrides are intentionally discouraged; deviations must use `WindowSizeClass` tiers.

**Note** (commit `f9efd1b`): A RenderFlex overflow in the medium-breakpoint directory selector was fixed as a direct consequence of this breakpoint model — constrained Medium-width layouts require explicit flex/overflow handling that Compact and Expanded layouts did not expose.

### Key Files

- `lib/presentation/utils/window_size_class.dart`
- `lib/presentation/pages/chat_page.dart`
- `lib/presentation/pages/home_page.dart`
- `lib/presentation/pages/settings_page.dart`
- `lib/presentation/pages/chat_page/chat_page_file_explorer_controller.dart`
- `lib/presentation/widgets/chat_message_widget.dart`

---

## ADR-014: Centralized MD3 Design Tokens for Shapes and Brand Colors (2026-02-20)

**Status**: Accepted

### Context

Shape values (border radii) were scattered across 15+ widgets as magic `BorderRadius.circular(...)` literals with no consistent scale. Color seed selection for non-dynamic-color scenarios had no structured fallback. The `featN` Material You revamp required centralizing these design tokens to align with MD3 specifications.

Related: historical `featN` workstream.

### Decision

1. **AppShapes**: Introduce a centralized shape constants class implementing the MD3 shape scale — None (0), ExtraSmall (4), Small (8), Medium (12), Large (16), ExtraLarge (28), Full (999) — as static `BorderRadius` constants. Replace all scattered magic border-radius values with `AppShapes.*` references.

2. **BrandColor**: Introduce an enum providing 5 curated seed colors as a deterministic fallback palette when dynamic color (`DynamicColorBuilder`) is unavailable or disabled by the user.

3. **Touch target policy**: Global `materialTapTargetSize: MaterialTapTargetSize.padded` was evaluated and rejected because it caused cascading Row overflow issues in tight layouts. Touch target enforcement is scoped only to specific widgets that need it (e.g., model selector), rather than applied globally via theme.

### Rationale

- MD3 defines a canonical shape scale; centralizing it eliminates visual inconsistency and makes future scale adjustments atomic.
- A brand-color enum provides predictable theming when platform dynamic color is absent, without hardcoding hex values at call sites.
- Scoped tap-target enforcement avoids layout regressions while still meeting accessibility goals where they matter most.

### Consequences

- ✅ Single source of truth for shape tokens; changing the scale updates all surfaces atomically.
- ✅ Brand color fallback is explicit and testable, decoupled from dynamic color availability.
- ✅ Avoids global tap-target padding regressions in constrained layouts.
- ⚠ All existing `BorderRadius.circular(...)` literals must be migrated to `AppShapes.*` references.
- ⚠ Adding new shape tiers requires updating `AppShapes` and verifying downstream usage.
- ❌ Global `materialTapTargetSize: padded` is intentionally rejected; per-widget scoping is the accepted pattern.

**Note** (commit `f9efd1b`): Dynamic color availability detection was upgraded from a static platform heuristic (`_supportsDynamicColor()`) to runtime detection via `DynamicColorBuilder`, propagated through `SettingsProvider.dynamicColorAvailable`. As a consequence, the contrast slider is now disabled when dynamic color is active, since contrast adjustment only applies to `ColorScheme.fromSeed` (seed-based) themes.

### Key Files

- `lib/presentation/theme/app_shapes.dart`
- `lib/presentation/theme/brand_colors.dart`
- `lib/presentation/theme/app_theme.dart`
- `lib/presentation/pages/settings/sections/appearance_settings_section.dart`
- `lib/presentation/widgets/chat_input_widget.dart`
- `lib/presentation/widgets/chat_message_widget.dart`

---

## ADR-015: Platform-Specific Icon Asset Pipeline for Tray, Android Notifications, and macOS Launcher Masking (2026-02-20)

**Status**: Accepted

### Context

The app now relies on platform-specific icon constraints for desktop tray rendering and Android notification visibility. A single generic source icon does not produce consistent results across Linux/macOS/Windows tray surfaces, and Android status-bar notifications require a dedicated monochrome small icon resource. macOS launcher icons also need rounded-corner masking in generation to match expected platform appearance.

### Decision

Standardize `make icons` as the canonical image pipeline using ImageMagick to generate:

- OS-specific tray assets (`tray_icon_linux.png`, `tray_icon_macos_template.png`, `tray_icon_windows.ico`) from a shared monochrome master.
- Android notification small icons as `ic_stat_codewalk` in `android/app/src/main/res/drawable-*`.
- macOS launcher source with rounded-corner mask before generating app icon sizes.

Enforce runtime usage through platform services: Android notifications use `@drawable/ic_stat_codewalk` in `AndroidNotificationDetails`, and desktop tray service loads OS-specific tray assets.

### Rationale

- Platform-specific icon rendering rules differ and require explicit per-target outputs.
- A generated pipeline prevents manual asset drift and keeps outputs reproducible.
- Dedicated Android small-icon resources improve status-bar legibility and consistency.
- Rounded macOS launcher source aligns generated icons with native visual expectations.

### Consequences

- ✅ Predictable, reproducible icon generation for tray, notification, and launcher targets.
- ✅ Better notification icon clarity on Android via dedicated `ic_stat_codewalk` resources.
- ✅ Correct tray appearance per desktop OS using target-specific assets.
- ⚠ `make icons` now depends on ImageMagick availability in contributor/build environments.
- ❌ Ad hoc manual replacement of generated icon outputs is intentionally discouraged.

### Key Files

- `Makefile`
- `lib/presentation/services/notification_service.dart`
- `lib/presentation/services/desktop_tray_service_io.dart`
- `android/app/src/main/res/drawable-*/ic_stat_codewalk.png`
- `assets/images/tray_icon_*.png`, `assets/images/tray_icon_windows.ico`
- `assets/images/macos_appicon_source.png`

---

## ADR-016: Hybrid File-Backed Cache for Large Chat Payloads (2026-02-20, updated 2026-08-21)

**Status**: Accepted

**Related**: ADR-020 (Session-Level SWR Cache with Persisted LRU Snapshots), ADR-018 (Dedicated SSE Dio Instance)

### Context

CodeWalk caches session lists, last-session snapshots, and per-session message snapshots so project/session switching can restore a useful chat view before remote revalidation finishes. Payloads must stay scoped by server and project context, and the implementation must remain simple enough to preserve reliably across mobile and desktop targets.

The 2026-06-15 revision replaced the file-backed store with a SharedPreferences-only path. While that removed a stale abstraction, native IO targets (Windows, macOS, Linux, Android) hit the platform preference-store payload limits and suffered a measurable Windows/desktop performance regression when storing large chat payloads. Legacy snapshots from before that revision may also still be sitting in the preference store, acting as a latent compatibility risk that needs to be drained on first access.

Hot metadata paths have a separate performance and ordering risk: on Linux and Windows, the SharedPreferences plugin rewrites the whole preferences file synchronously for each `set*` or `remove`. Session-tab reconciliation can receive bursts of SSE-driven updates, and a delayed write can race an awaited load, cleanup, or provider disposal unless the pending state is flushed and ordered. Issue #152 establishes this as an anti-regression boundary for local persistence.

### Decision

Adopt a **hybrid file-backed cache** for chat payloads on native IO platforms, with SharedPreferences reserved for cache metadata, the existing SharedPreferences fallback when no file store exists, and proactive migration of any legacy large payload out of SharedPreferences into the file-backed store.

1. **File-backed store on all native IO platforms** — re-enable `ChatCachePayloadStore` (and the `_readLargeCachePayload` / `_writeLargeCachePayload` helpers) for **every** native IO target — Windows, macOS, Linux, and Android. The store writes payload bytes to app support storage under the same server/context-scoped key scheme used by `AppLocalDataSource`. The fix is intentionally not Android-only: scoping file-backed storage to a single platform would re-introduce the same regression on the others.
2. **SharedPreferences metadata only** — keep snapshot timestamps, LRU lists, and other small cache metadata in `SharedPreferences`. These values are small, rarely change, and ride the existing preference-store infrastructure.
3. **No-file-store fallback** — on targets without a `ChatCachePayloadStore` implementation, the helpers keep the existing SharedPreferences read/write fallback. This preserves current web/test behavior while the Windows/desktop fix moves native IO payloads out of the preference store.
4. **Best-effort migration of known large-payload preference keys** — at the start of `loadSessions()`, schedule a background sweep of `SharedPreferences` entries matching the known large-payload key families (`cached_sessions*`, `last_session_snapshot*`, `session_messages_snapshot::*`, defined by `AppConstants.cachedSessionsKey`, `lastSessionSnapshotKey`, and `sessionMessagesSnapshotKey`). The read path returns a legacy preference payload immediately, treats it as the newest source when a file-backed copy also exists, and queues the file write/preference removal in the background. Per-key mutation queues prevent background migration from overwriting newer cache writes; a per-process in-memory set (`_migratedLargeCacheKeys`) tracks keys cleared during the current run. There is no versioned persisted migration marker.
5. **Conditional export boundary** — the file-backed store is exposed via the existing conditional export pattern (`chat_cache_payload_store_io.dart` / `chat_cache_payload_store_stub.dart`) so web builds stay green without runtime platform checks.
6. **Guard hot-path metadata writes (issue #152)** — `AppLocalDataSource` routes `setString`, `setInt`, `setBool`, and `remove` through `_GuardedSharedPreferences`. Equality/existence checks return before calling the plugin for no-op operations. Any new metadata persistence must use the same guard or an equivalent guard at its storage boundary.
7. **Coalesce bursty metadata with explicit ordering** — session-tab state remains server-scoped under `session_tabs_state::<serverId>`. `ChatProvider` uses a trailing 750 ms debounce with latest-wins pending payloads, serializes writes per server, explicitly flushes before awaited tab-load/context-cleanup paths, and drains pending state into the write queue during provider disposal. Any future debounced metadata persistence must preserve equivalent flush and ordering guarantees.
8. **Keep write instrumentation opt-in and lazy** — the `shared_preferences_write` performance task is invoked through `AppLogger.runPerformanceTask`, and UTF-8 byte sizing is evaluated only while performance logging is enabled.
9. **Lifecycle boundaries must flush coalesced state** — pending debounced payloads are dequeued and enqueued when the app backgrounds (`flushAllSessionTabsPersistence` from `didChangeAppLifecycleState`). Enqueue-all precedes awaiting completion so one slow server write cannot expose other servers' state to process death.
10. **Retried writes require ordering guards** — failed coalesced writes are re-staged only under a per-server generation guard (retry allowed solely when no newer payload was staged or queued), preventing a stale retry from overwriting newer persisted state; completed queue entries are removed under an identity check.

**Update** (2026-08-21, commits `249eea77..8e0f6140`, v1.213.0): Rules 9–10 harden debounced session-tab persistence against process death on backgrounding (rule 9) and stale-retry overwrites of newer persisted state (rule 10).

This is an addendum to ADR-016, which owns the local persistence boundary. ADR-020 remains the related session-level SWR consumer of these helpers; it does not need a duplicate decision or a new ADR.

### Rationale

- Large chat payloads exceed the practical limit of every native platform's preference store and were the root cause of the Windows/desktop regression; restoring the file-backed store resolves this without changing the cache contract.
- Re-enabling file-backed storage on **all** native IO platforms — not Android only — matches the original architecture and ensures the fix is portable; isolating it to a single platform would have left the regression live on the others.
- Keeping small metadata in `SharedPreferences` preserves the contract that cache state is durable across app restarts and avoids file I/O on every read for the hot path.
- The no-file-store fallback keeps the code path uniform without breaking web builds or tests that inject no store; the Windows regression is addressed by ensuring all native IO targets have a real file-backed store.
- Best-effort background migration of the known large-payload key families out of `SharedPreferences` prevents the preference store from staying bloated by oversized entries written before the fix without blocking the first cache restore on Windows; the read path treats any residual `SharedPreferences` copy as newer than file-backed data and queues it for draining.
- Generic equality/existence guards prevent redundant whole-preferences-file rewrites on hot paths without changing the public local-data-source contract.
- Trailing latest-wins coalescing bounds burst cost while per-server queues and explicit flushes prevent a delayed write from being overtaken by an awaited read or cleanup operation.
- Lazy, opt-in instrumentation preserves the diagnostic signal when requested without computing payload sizes or creating performance-task overhead when logging is disabled.
- Lifecycle-boundary flushes ensure coalesced state survives process death: enqueue-all before awaiting keeps per-server write latency from serializing exposure of other servers' persisted state.
- Generation-guarded retries prevent a stale failed write from overwriting newer persisted state, preserving latest-wins semantics across failure paths.
- Keeping this rule in ADR-016 avoids duplicating the persistence boundary in ADR-020 or creating a separate ADR for an implementation constraint that applies to the same storage decision.

### Consequences

- ✅ Windows/desktop performance regression is resolved by moving large payloads off the preference store on all native IO platforms.
- ✅ The cache contract (server/context-scoped keys, metadata layout) is unchanged; only the payload backend becomes hybrid.
- ✅ Legacy chat payloads under the known large-payload keys (`cached_sessions*`, `last_session_snapshot*`, `session_messages_snapshot::*`) are drained from `SharedPreferences` in the background after `loadSessions()` starts, preventing silent loss and preference-store bloat without blocking the first restore; residual `SharedPreferences` copies win over file-backed copies and are migrated forward.
- ✅ Web/test configurations without a file store keep the existing SharedPreferences fallback semantics.
- ✅ No-op SharedPreferences metadata writes are skipped, and bursty session-tab updates are coalesced without losing the latest server-scoped state.
- ✅ Explicit flushes and per-server ordering preserve persistence visibility across awaited load/cleanup paths; provider disposal drains pending state into the same ordered write queue.
- ✅ App-backgrounding flushes coalesced session-tab state before process death can drop it, and generation-guarded retries prevent stale writes from overwriting newer persisted state (2026-08-21 hardening).
- ✅ The change is client-local persistence only: it does not change the OpenCode wire protocol, server event semantics, documented visual behavior, or ADR-023 compatibility.
- ⚠ Debouncing intentionally delays ordinary session-tab persistence by up to 750 ms; lifecycle boundaries must flush before relying on the durable value.
- ⚠ Future metadata persistence must use the guarded/coalesced boundary rather than introducing an unguarded direct SharedPreferences hot path.
- ⚠ Requires the conditional import boundary (`ChatCachePayloadStore` IO vs. stub) to keep web builds green — same pattern already used by the Tailscale adapter (ADR-036) and the SSE adapter (ADR-018).
- ⚠ The migration key list is explicit; adding a new large-payload key family requires updating `_isLargeCachePayloadPreferenceKey` so the sweep stays complete.
- ❌ Web can still persist large chat snapshots through its preference fallback; a true web no-store or IndexedDB-backed cache is a separate decision.
- ❌ Direct SharedPreferences consumers outside this boundary are not automatically coalesced; if they become hot-path metadata persistence, they must adopt an equivalent guard and ordering policy.

### Key Files

- `lib/data/datasources/app_local_datasource.dart` — `_GuardedSharedPreferences`, `AppLocalDataSourceImpl`
- `lib/data/datasources/app_local_datasource_storage_helpers.dart` — large-payload file-store/fallback helpers
- `lib/data/cache/chat_cache_payload_store_io.dart` — file-backed store implementation for native IO targets
- `lib/data/cache/chat_cache_payload_store_stub.dart` — no-file-store fallback for web/tests
- `lib/presentation/providers/chat_provider.dart` — per-server debounce state and `dispose`
- `lib/presentation/providers/chat_provider/chat_provider_session_tab_ops.dart` — `_scheduleSessionTabsPersistence`, `flushSessionTabsPersistence`, `_enqueueSessionTabsPersistenceOperation`
- `lib/core/logging/app_logger.dart` — `runPerformanceTask`
- `test/unit/datasources/app_local_datasource_impl_test.dart`
- `test/unit/providers/chat_provider_session_tabs_test.dart` — burst coalescing coverage

---

## ADR-017: Android Foreground Service for Reliable Background Monitoring (2026-02-20, updated 2026-08-21)

**Status**: Accepted

### Context

Android aggressively kills background processes and restricts background execution. The app's background alert monitoring requires a reliable mechanism to survive Android process management and deliver timely notifications even when the app is not in the foreground.

### Decision

Implement a native Kotlin foreground service (`CodeWalkForegroundService`) with `START_STICKY` restart policy, bridged to Dart via `MethodChannel('codewalk/system')`. The Dart-side orchestrator (`AndroidForegroundMonitorService`) provides idempotent `sync()` calls that always invoke the native bridge without count-based deduplication, ensuring the service is restarted if Android killed it while Dart statics were stale. The service uses a dedicated low-priority notification channel (`codewalk_background_monitor_v2`, `IMPORTANCE_MIN`) for the persistent monitoring notification, separate from the alert notification channel which uses default importance for audible alerts.

**Update** (2026-08-21, commits `249eea77..8e0f6140`, v1.213.0) — anti-regression boundary: v1.199–v1.212 shipped a regression where the app stopped `CodeWalkForegroundService` on backgrounding (immediately in paused mode, or after the 3-minute mobile-hold expired). Without the FGS the process became a cached process and aggressive Android/OEM process management killed it within seconds-to-minutes; users saw the app restart from scratch every time they switched windows and returned.

**Rule (anti-regression boundary)**: While Android background alerts are enabled and the app is backgrounded, the foreground monitor service MUST keep running so the process retains foreground-service priority. Do not stop the FGS as a battery optimization while alerts are enabled. Paused mode and mobile-hold expiry must re-run the foreground policy (`_applyForegroundPolicy`) instead of unconditionally disabling the monitor; the policy decides enabled/disabled from `shouldRunAndroidBackgroundAlerts`. The service stops only when:

- The app returns to foreground (mode = active).
- Background alerts are disabled (`_syncAndroidBackgroundAlertRuntime`).
- Cellular Data Saver disables background network.

The persistent `IMPORTANCE_MIN` notification staying visible during backgrounding with alerts enabled is intentional, documented UX (see BEHAVIOR.md), not a bug.

### Rationale

- `START_STICKY` ensures Android restarts the service after process death, maintaining monitoring continuity.
- Idempotent sync (always calling the native bridge) avoids stale Dart state from masking a killed native service.
- A dedicated low-priority notification channel keeps the mandatory foreground notification silent and non-intrusive.
- Separate alert and monitor channels allow users to configure notification preferences independently.
- `@Volatile` on the companion `instance` field ensures thread-safe access from the MethodChannel handler.

### Consequences

- ✅ Background monitoring survives Android process management via `START_STICKY`.
- ✅ Idempotent sync prevents stale-state gaps between Dart and native service lifecycle.
- ✅ Silent monitor notification with separate alert channel preserves notification UX quality.
- ✅ Foreground policy (`_applyForegroundPolicy`) keeps the FGS alive while background alerts are enabled, preserving foreground-service priority against OEM process management (2026-08-21 anti-regression rule).
- ⚠ Requires maintaining native Kotlin code alongside the Dart implementation.
- ⚠ `START_STICKY` restart is not guaranteed on all OEM Android variants with aggressive battery optimization.
- ⚠ Lifecycle changes (paused mode, mobile-hold expiry) must route through the foreground policy, never unconditionally stop the monitor — see the anti-regression boundary in Decision.
- ❌ The foreground notification is mandatory while monitoring is active (Android OS requirement); it remains visible while backgrounding with alerts enabled by design (documented in BEHAVIOR.md).

### Key Files

- `android/app/src/main/kotlin/com/verseles/codewalk/CodeWalkForegroundService.kt`
- `lib/presentation/services/android_foreground_monitor_service.dart`
- `lib/presentation/services/android_background_alert_worker.dart`
- `lib/presentation/pages/chat_page/chat_page_lifecycle.dart`
- `lib/presentation/providers/settings_provider.dart`

---

## ADR-018: Dedicated SSE Dio Instance for Connection Pool Isolation (2026-02-22)

**Status**: Accepted

**Related**: ADR-003 (Realtime-First Sync Lifecycle)

### Context

The shared Dio singleton's HTTP connection pool on Android drops per-send SSE long-lived connections when `selectSession` triggers regular HTTP requests (`loadMessages`, selection sync). The Android HTTP client aggressively reuses TCP connections; when the shared pool needs a connection for a regular request, it closes the least-recently-used connection — which is the SSE stream. The server detects the disconnection and sends `MessageAbortedError`, causing a false abort visible to the user.

Confirmed via `curl` that the server does NOT abort concurrent sessions when SSE connections stay alive — the problem is 100% client-side connection pool eviction.

### Decision

Create a second Dio instance (`_sseDio`) in `DioClient` with its own `IOHttpClientAdapter` and `HttpClient`, dedicated exclusively to SSE streams. Use conditional imports (`dio_sse_adapter.dart` → `dio_sse_adapter_io.dart` / `dio_sse_adapter_stub.dart`) for IO/web platform compatibility. The SSE `HttpClient` is configured with `idleTimeout: 2h` and `maxConnectionsPerHost: 4`.

`ChatRemoteDataSourceImpl` accepts an optional `sseDio` parameter with fallback to the regular `dio` (for tests and web). Provider-level SSE connections (`/event`, `/global/event`) route through `sseDio`. `baseUrl` and auth configuration are mirrored to both Dio instances in `updateBaseUrl()`, `setBasicAuth()`, and `clearAuth()`.

**Update (commit `61934e9`)**: Per-send SSE connections were removed entirely from the `prompt_async` path. The server monitors per-send SSE connections and aborts the AI agent when it detects disconnection (e.g. half-open TCP after background resume). Without per-send SSE, `prompt_async` processes fully async — message delivery relies on immediate polling (`startFallbackCompletionWatch` with zero delay) plus provider-level SSE. Some recent servers (e.g., OpenChamber or newer OpenCode builds) may return the completed assistant payload directly in the `200 OK` response; CodeWalk accepts this authoritative payload immediately, bypassing the fallback polling path. The dedicated SSE Dio remains in use for provider-level SSE streams.

### Rationale

- A separate `HttpClient` with its own connection pool eliminates TCP connection contention between regular HTTP requests and long-lived SSE streams entirely.
- Conditional imports provide a no-op stub on web where browsers manage connections natively.
- Optional `sseDio` injection maintains backward compatibility with all existing tests without requiring mock changes.
- Mirroring auth/baseUrl in both instances keeps configuration synchronized without requiring a shared interceptor chain.

### Consequences

- ✅ Eliminates false abort on concurrent session switch caused by connection pool eviction.
- ✅ SSE streams are never evicted by regular HTTP requests competing for connections.
- ✅ Eliminates server-side abort triggered by dead per-send SSE connections after background resume.
- ✅ Web platform is unaffected (no-op stub; browser manages connections natively).
- ⚠ Two Dio instances must stay synchronized for `baseUrl` and auth changes — all config methods in `DioClient` must update both.
- ⚠ No `dispose()` exists for either Dio instance; acceptable since `DioClient` is a `registerLazySingleton` with app-lifetime scope.
- ✅ Selection sync deferral during abort suppression eliminates server-side Instance disposal during active multi-step processing.
- ⚠ The 8s abort suppression window must be longer than typical inter-step gaps; very long tool executions may need the SSE busy-status fallback.
- ❌ Slightly higher memory footprint from the second connection pool (negligible for mobile/desktop).

**Note**: The app's selection sync (`PATCH /config`) triggers `Config.update()` on the OpenCode server, which calls `Instance.dispose()`. Instance disposal runs cleanup handlers that abort ALL active session `AbortController`s — killing any multi-step processing in progress. This was the root cause of false aborts on complex prompts (tool-calls with multiple steps). Fix: defer selection sync during the 8-second abort suppression window post-send, so `PATCH /config` never arrives while the server is still processing multi-step loops. After the window, the existing `hasBusyStatus` check (based on SSE session status) prevents premature sync. See ADR-019 for the full decision on config-mutating call deferral.

### Key Files

- `lib/core/network/dio_client.dart`
- `lib/core/network/dio_sse_adapter.dart`
- `lib/core/network/dio_sse_adapter_io.dart`
- `lib/core/network/dio_sse_adapter_stub.dart`
- `lib/data/datasources/chat_remote_datasource.dart`
- `lib/core/di/injection_container.dart`

---

## ADR-019: Defer Config-Mutating API Calls During Active Server Processing (2026-02-22)

**Status**: Accepted

**Related**: ADR-018 (Dedicated SSE Dio Instance), ADR-003 (Realtime-First Sync Lifecycle)

### Context

The app syncs user selections (model, provider, system prompt) to the OpenCode server via `PATCH /config`. On the server side, `Config.update()` calls `Instance.dispose()`, which runs cleanup handlers that abort ALL active session `AbortController`s. When the user sends a complex prompt that triggers multi-step processing (tool-calls with multiple steps), a selection sync fired during processing would kill the in-flight session — causing false aborts that appeared as server-side failures but were actually client-initiated lifecycle disruption.

This was confirmed as the root cause of false aborts on complex prompts: the client's selection sync arrived while the server was between tool-call steps, triggering Instance disposal and aborting the entire session.

### Decision

Defer all config-mutating API calls (`PATCH /config`) during the post-send abort suppression window (8 seconds). The deferral uses two complementary guards:

1. **Abort suppression window (time-based)**: For the first 8 seconds after `prompt_async` send, selection sync is suppressed entirely. This covers the critical startup phase where SSE session status may not yet reflect "busy" state.
2. **SSE busy-status check (state-based)**: After the 8s window expires, the existing `hasBusyStatus` check (derived from SSE session status events) prevents sync while the server reports an active session. This covers long-running tool executions that extend beyond the initial window.

Selection changes made during suppression are not lost — they are applied on the next eligible sync cycle once both guards clear.

### Rationale

- `PATCH /config` is the only client-initiated API call that triggers server-side `Instance.dispose()`, making it the sole vector for client-caused session abortion.
- The 8s time-based guard is necessary because SSE status events have propagation delay — the server may be processing before the client receives a "busy" status update.
- The state-based `hasBusyStatus` fallback ensures protection extends beyond the fixed window for long-running operations.
- Two-layer deferral (time + state) provides defense-in-depth without requiring server-side changes.

### Consequences

- ✅ Eliminates client-caused false aborts during multi-step server processing (tool-calls, complex prompts).
- ✅ Selection changes are preserved and applied after processing completes — no user input is lost.
- ✅ No server-side changes required; fix is entirely client-side.
- ⚠ The 8s abort suppression window must be longer than typical inter-step gaps; if the server takes longer than 8s between steps AND SSE status has not yet propagated, a race condition is theoretically possible (mitigated by the SSE busy-status fallback).
- ⚠ Selection sync latency increases by up to 8s after sending a prompt — user sees the old selection on the server briefly.
- ❌ Immediate selection sync during active processing is intentionally prohibited; this is a correctness tradeoff over responsiveness.

### Key Files

- `lib/presentation/providers/chat_provider/chat_provider_send_ops.dart`
- `lib/presentation/providers/chat_provider/chat_provider_realtime_ops.dart`
- `lib/data/datasources/chat_remote_datasource.dart`

---

## ADR-020: Session-Level SWR Cache with Persisted LRU Snapshots (2026-02-26)

**Status**: Accepted

**Related**: ADR-016 (Hybrid File-Backed Cache), ADR-003 (Realtime-First Sync Lifecycle)

### Context

Long conversations were reloading from scratch on every session switch. The provider cleared `_messages` before loading remote data, so switching to a large session frequently showed a blank/loading state and caused perceived stutter. Existing durable cache only restored a single "last session snapshot", which did not help when moving between multiple active sessions.

The "project-switch fast cache-first SWR path" (commits `f432a33`, `facd736`) optimizes the workspace transition by allowing immediate UI restoration from the per-session cache while revalidation occurs in the background.

Server APIs currently expose full message list reads (with optional `limit`) and single-message fetch, but no dedicated delta cursor/etag endpoint for historical chat synchronization.

### Decision

Adopt a cache-first SWR policy per session:

1. Add an in-memory per-session LRU message cache in `ChatProvider` (20 entries).
2. Persist recent per-session message snapshots through ADR-016 local storage helpers plus SharedPreferences metadata for recency and timestamps.
3. On `selectSession`, restore cached messages immediately when available and trigger background `loadMessages(...preserveVisibleState: true)` revalidation.
4. Project Switch Fast-Path: During workspace/project transitions (`serverId::directory`), prioritize restoring the last known session snapshot for that context from cache immediately, bypassing the full "loading" state if valid data exists.
5. Defer non-current session message payloads — full message bodies, diffs, and todos from SSE are NOT fetched or applied for non-current sessions. While a session is non-current, the realtime stream is scoped to summarized status and alertable event categories only (see ADR-003); full message payload work is deferred until the session becomes current again, at which point the cache-first SWR restore (point 3) and active revalidation take over.
6. Virtual History Loading: Implement top-scroll pagination by plumbing optional `limit` through the message read stack and adding a `loadOlderMessages()` flow. The UI maintains scroll anchor position across history injections to prevent layout shifts.

### Rationale

- Cache-first restore removes unnecessary blank reloads for recently visited long sessions.
- SWR keeps correctness by still revalidating against server state.
- Project-switch fast-path specifically targets the latency-sensitive workspace transition, where waiting for network before showing *any* chat history creates high friction.
- Per-session persistence extends ADR-016 beyond one snapshot and keeps cache useful across app restarts.
- Deferring non-current session message work keeps background contexts cheap to track; freshness for non-current sessions comes from alertable/summarized status only, with full reconciliation deferred to the next SWR restore on session re-entry (ADR-003 owns the event-scope policy).
- Top-scroll pagination enables browsing long histories without high initial memory/latency costs.
- Anchor restoration ensures a smooth reading experience when prepending messages.

### Consequences

- ✅ Session switching is significantly faster and more stable for long conversations.
- ✅ Background revalidation keeps data fresh without forcing full UI reset.
- ✅ Cache durability now covers multiple recent sessions, not only the last one.
- ✅ Support for seamless top-scroll pagination with stable scroll anchoring.
- ✅ Workspace transitions (project switches) feel instantaneous when cached session data exists.
- ⚠ Cache metadata/key management is more complex (LRU list + per-session timestamps).
- ⚠ Scroll anchor restoration logic adds complexity to the ChatPage list controller.
- ❌ No true server-side delta endpoint yet; full-fetch fallback remains necessary for correctness.

**Note** (issue #83): Per-session event-scope policy interaction — re-entering a session restores the persisted snapshot immediately (cache-first SWR) and reconciles against the server through active revalidation. While a session is non-current, the realtime stream feeds only summarized status and alertable event categories (permission/question v1/v2, `session.error`, `session.idle` / final completion); full message payloads, diffs, and todos are deferred until the session becomes current again, at which point this SWR path takes over. See ADR-003 for the full event-scope policy.

### Key Files

- `lib/presentation/providers/chat_provider.dart`
- `lib/presentation/providers/chat_provider/chat_provider_cache_persistence_ops.dart`
- `lib/presentation/providers/chat_provider/chat_provider_event_reducer_helpers.dart`
- `lib/presentation/providers/chat_provider/chat_provider_event_reducer_session_ops.dart`
- `lib/presentation/providers/chat_provider/chat_provider_event_reducer_global_ops.dart`
- `lib/presentation/providers/chat_provider/chat_provider_message_merge_ops.dart`
- `lib/presentation/pages/chat_page/chat_page_scroll_coordinator.dart`
- `lib/data/datasources/app_local_datasource.dart`
- `lib/data/datasources/chat_remote_datasource.dart`
- `lib/domain/usecases/get_chat_messages.dart`
- `lib/presentation/providers/chat_provider/chat_provider_context_state_ops.dart`

---

## ADR-021: Context-Scoped Draft State for Project-Switch SWR (2026-02-28)

**Status**: Accepted

**Related**: ADR-002 (Context Isolation), ADR-020 (Session-Level SWR Cache)

### Context

After adopting draft-first New Chat with lazy session bootstrap, project-switch fast-path (`waitForRevalidation: false`) could carry draft-only state into another `serverId::directory` context. In this leaked state, `loadLastSession()` could incorrectly short-circuit for the target context, leaving it in an empty draft flow instead of restoring that context's session/snapshot via SWR.

### Decision

Treat draft-related composer/session bootstrap state as context-scoped snapshot data:

1. `_ChatContextSnapshot` now includes `isNewChatDraftActive`, `activeSendDraft`, and `rejectedDraft`.
2. `_storeCurrentContextSnapshot()` persists this draft state per active context key.
3. `_restoreContextSnapshot()` restores draft state for known contexts and resets to non-draft for new contexts.
4. `_switchContext()` clears transient `_lazySessionBootstrapTask` to avoid in-flight bootstrap futures crossing context boundaries.
5. `createNewSession()` guards against post-await context changes and discards stale results from old contexts.

### Rationale

- Project scope in CodeWalk is `serverId::directory`; draft state must follow the same isolation boundary as sessions and selections.
- Fast project switching must remain cache-first and non-blocking without letting ephemeral draft flags block target-context restore.
- Async session bootstrap must not write stale results after a context switch.

### Consequences

- ✅ Prevents cross-project draft leakage during fast project switches.
- ✅ Preserves draft-first UX inside the originating context while restoring normal SWR behavior in other contexts.
- ✅ Adds regression coverage for project-switch + draft round-trip behavior.
- ⚠ Snapshot payload grows slightly with draft-related fields.
- ❌ Draft bootstrap tasks are intentionally not resumed across context switches.

### Key Files

- `lib/presentation/providers/chat_provider_types_part.dart`
- `lib/presentation/providers/chat_provider/chat_provider_preference_ops.dart`
- `lib/presentation/providers/chat_provider/chat_provider_session_ops.dart`
- `lib/presentation/providers/chat_provider.dart`
- `test/unit/providers/chat_provider_project_test.dart`

---

## ADR-022: Unified Project Context Controls with Sidebar Session Previews (2026-03-01)

**Status**: Accepted

**Related**: ADR-002 (Context Isolation), ADR-020 (Session-Level SWR Cache), ADR-021 (Context-Scoped Draft State)

### Context

Project context controls and conversations navigation were split across separate UI surfaces (project selector in the app bar and sessions in the sidebar). This separation increased navigation friction, especially on mobile. Users needed a unified navigation point that keeps project switching and conversation access together while preserving strict context isolation.

### Decision

1. Merge project context controls into the conversations sidebar for both mobile drawer and desktop sidebar layouts.
2. Add per-project conversation previews in the sidebar using active context sessions plus cached snapshots from previously visited contexts.
3. Keep session ownership and active state strictly scoped by `serverId::scopeId`; selecting a conversation from another project always triggers context switch first.
4. Reuse existing context-switch fast path and background revalidation strategy; no change to server API contracts.

### Rationale

- A single navigation surface reduces context-switch cognitive overhead.
- Snapshot-backed previews improve perceived speed when moving between projects.
- Preserving `serverId::scopeId` ownership avoids cross-project state leakage and protects existing invariants.
- Reusing existing SWR/cache behavior minimizes migration risk.

### Consequences

- ✅ Faster project/session navigation from one sidebar workflow.
- ✅ Better mobile/desktop consistency for context controls.
- ✅ No architectural break in context isolation semantics.
- ⚠ Sidebar UI/state management becomes more complex (project rows + previews + actions).
- ⚠ Preview availability depends on existing snapshots for non-active contexts.

### Key Files

- `lib/presentation/pages/chat_page/chat_page_scaffold.dart`
- `lib/presentation/providers/chat_provider.dart`
- `lib/presentation/pages/chat_page/chat_page_workspace_controller.dart`
- `test/widget/chat_page_test.dart`

---

## ADR-023: Official OpenCode Contract-First Compatibility Policy (2026-03-02)

**Status**: Accepted

### Context

CodeWalk's behavior must stay synchronized with official OpenCode server API and event semantics to prevent regressions and fragmentation. Lifecycle drift in areas like `prompt_async`, session state (`idle`/`busy`), and configuration mutation timing often causes subtle bugs that are difficult to debug when the client deviates from standard server expectations.

### Decision

1. **Contract First**: CodeWalk must follow official OpenCode server API/event semantics as the primary development constraint.
2. **Core Compatibility**: Client behavior must remain compatible with official OpenCode CLI and Web for core chat lifecycle semantics before adding app-specific behavior.
3. **Explicit Divergence**: Any intentional divergence from official semantics requires an explicit ADR exception including rationale, risk analysis, feature flag/rollback plan, and comprehensive tests.
4. **CI Enforcement**: Contract-breaking changes must be blocked in CI (hard fail) unless a documented ADR exception is approved.
5. **Evolution Policy**: Prefer additive and non-breaking evolution of the contract. Any removals or breaking semantic changes require a coordinated migration plan.

### Rationale

- **Regression Prevention**: Standardizing on the official contract reduces regressions caused by client/server lifecycle drift (e.g., `prompt_async` handling, session status transitions).
- **Ecosystem Alignment**: Ensures CodeWalk remains a first-class citizen in the OpenCode ecosystem, supporting features like cross-client session continuity.
- **Predictability**: Developers can rely on documented server behavior instead of guessing app-specific side effects.
- **Stability**: Hard-failing CI for contract breaks prevents accidental drift in high-velocity development.

### Consequences

- ✅ Significantly reduces regressions stemming from client-side lifecycle assumptions.
- ✅ Ensures long-term compatibility with official OpenCode server updates.
- ✅ Simplifies debugging by aligning client state transitions with server-authoritative events.
- ⚠️ May introduce friction when implementing app-specific optimizations that require non-standard API usage.
- ❌ Increases maintenance overhead for contract validation and CI enforcement.

### Reference Sources

These references are the first source of truth before implementing client behavior changes.

- **Local Docs**:
  - `ai-docs/opencode_server.md`
  - `ai-docs/opencode_web.md`
  - `ai-docs/opencode_models.md`
- **Official Docs**:
  - https://opencode.ai/docs/server/
  - https://opencode.ai/docs/web/
  - https://opencode.ai/docs/cli/
- **GitHub Sources (Canonical Behavior)**:
  - https://github.com/anomalyco/opencode
  - https://github.com/anomalyco/opencode/tree/dev/packages/opencode
  - https://github.com/anomalyco/opencode/tree/dev/packages/opencode/src/cli
  - https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/server/server.ts
  - https://github.com/anomalyco/opencode/tree/dev/packages/app
  - https://github.com/anomalyco/opencode/tree/dev/packages/opencode/src/cli/cmd/tui
- **Community / Non-Official Reference**:
  - https://github.com/openchamber/openchamber — community project, NOT an official OpenCode resource. Must never override official OpenCode docs/source. May be investigated as a secondary source for implementation details, working patterns, and bug/feature investigation ideas.

Related: ADR-003, ADR-018, ADR-019, ADR-022.

### Composer Model Selection Contract

**Note**: Composer model selection follows the official OpenCode connected/free model contract — no CodeWalk-specific model allowlist.

- **Source of truth**: User-selectable models come from `/provider.connected`, filtered to models that are neither hidden nor deprecated.
- **Dynamic free Zen models**: In addition, dynamic free Zen models are pulled from provider id `opencode` where `cost.input == 0`. These are included regardless of the connected model list, since free Zen availability is a server-discovered property, not a CodeWalk policy.
- **No hardcoded allowlist**: CodeWalk intentionally does not hardcode any model allowlist. Selection is driven entirely by the server's authoritative provider/model responses, keeping the client aligned with whatever the connected OpenCode server exposes.
- **`opencode-go` is not auto-classified as Zen**: The `opencode-go` provider is treated as Zen only when it is connected (i.e., appears in `/provider.connected`). Otherwise, it is excluded from free Zen selection even if its cost matches, since unconnected providers must not be offered to the user.

This contract is a direct application of the ADR-023 contract-first policy: the composer never invents or restricts model availability beyond what the official OpenCode server reports.

### Known Pitfalls

#### Pitfall P-001: Optimistic user message ID format (regression `b0660a2`, 2026-03-02)

**Summary**: Using a server-format ID (e.g. `msg_*`) for the optimistic user bubble, or forwarding `messageId` in the `prompt_async` send payload, breaks SSE event stream reconciliation for all conversation turns after the first — the UI update is silently discarded even though audio/notifications fire normally.

**Status (g4 update)**: g4 delivery maintains the provider-side `local_user_*` optimistic ID contract and does not forward `messageId` in `prompt_async`. This is the ADR-023-compliant baseline for CodeWalk until/unless a future ADR exception or upstream proof justifies official provider-side ID parity. Commits `5cabcf0` and `a066026` added regression coverage protecting refresh/reconcile from hiding active tool/work UI during optimistic echo replay.

**Symptom**: The app plays the "response completed" sound and notification for turns 2+, but the UI stays stuck on the previous state (e.g. "Reasoning...") — the new assistant response is received by the SSE stream but the UI update is silently discarded during merge. The session recovers only after a manual switch and return.

**Root cause**: The SSE merge logic uses the `local_user_*` prefix to identify optimistic bubbles that are candidates for duplicate-echo suppression. When the optimistic ID looks like a server message (`msg_*`), the prefix check short-circuits to `false` and the bubble is treated as a confirmed server message. On the next server event, the merge finds a conflict between the retained "server-looking" local message and the real server echo, causing the UI update for subsequent turns to be silently discarded.

**Invariant — do not violate**:
1. Optimistic user message IDs MUST use the `local_user_<timestamp>_<seq>` format.
2. The `messageId` field MUST NOT be forwarded in the `prompt_async` send payload.
3. Duplicate detection MUST use content-signature matching gated by the `local_user_` prefix check.

**Code locations** (see comments in source for details):
- `lib/presentation/providers/chat_provider.dart`:
  - `_nextLocalUserMessageId()`
  - `sendMessage()` → `ChatInput` construction (no `messageId` field)
- `lib/presentation/providers/chat_provider/chat_provider_message_merge_ops.dart` → `_shouldSkipLocalUserAppendAsDuplicateEcho()`

**See also**: BEHAVIOR.md § "Optimistic user message ID uses local prefix — never server format".

#### Pitfall P-002: Final assistant message flicker after session.idle (regression `f8d6c3c6c`, fixed 2026-05-29)

**Summary**: After `session.idle` fires, the final assistant message appears complete, then reverts to an incomplete/"still receiving" appearance, then comes back — in a visible loop. The regression was introduced by commit `f8d6c3c6c` which unconditionally nulled `_activeMessageStreamSessionId` on `session.idle` and immediately marked incomplete assistant messages as completed, without guarding against late incomplete events from the still-draining send stream.

**Status**: Fixed by monotonic completion guard in `_updateOrAddMessage` and debounced timer cleanup on `session.idle`.

**Symptom**: The final assistant message flickers between complete and incomplete appearance in a loop after `session.idle`. The user sees the response finish, then briefly revert to "still receiving", then complete again, repeatedly.

**Root cause**: `_updateOrAddMessage` performed a blind `_messages[index] = message` replacement. When `session.idle` stamped `completedTime` on the assistant message, late incomplete events from the draining send stream or stale fallback fetches could overwrite the completed message with an incomplete version, causing the visible flicker loop.

**Invariant — do not violate**: Once an `AssistantMessage` has `completedTime != null` (marked completed by `session.idle` or authoritative `message.updated`), no incomplete version of the same message may overwrite it. The guard lifts when the incoming message is also completed, allowing server-authoritative updates.

**Code locations**:
- `lib/presentation/providers/chat_provider/chat_provider_message_state_ops.dart` → `_updateOrAddMessage()` monotonic completion guard
- `lib/presentation/providers/chat_provider/chat_provider_event_reducer_session_ops.dart` → `session.idle` handler debounced timer cleanup
- `test/unit/providers/chat_provider_realtime_test.dart` → regression tests

**See also**: BEHAVIOR.md § "Post-completion reading remains stable", ADR-028 (scroll ownership).

### Exception EXC-001: Composer Permission Auto-Approve Toggle

**Status**: Approved ADR-023 exception.

**Summary**: CodeWalk exposes a composer-level toggle to the left of the agent selector that defaults to enabled, persists user opt-out, and auto-approves permission requests with `always` semantics unconditionally, sending `remember: true` to create durable session-scoped grants. Question prompts remain manual. The auto-approve behavior extends to the Android background worker continuity path, enabling pending permission resolution when the app resumes from background.

**Deviation from official behavior**: Official OpenCode currently keeps runtime permission-mode controls outside the composer and does not inherit permissive behavior across subagents/subsessions. CodeWalk intentionally extends auto-approval to the visible thread, including mirrored descendant/subsession permission requests surfaced in the root session, and always replies `always` to create durable session-scoped grants. The Android background worker continuity path further extends this to background-collected permission requests when the app is resumed.

**Rationale**:
- Reduce repeated approval friction during active coding sessions.
- Keep the user in the root conversation while descendant permission prompts are mirrored there.
- Prefer `always` for durable permission grants unconditionally; every auto-approved permission creates a session-scoped grant via `remember: true`.
- Question prompts intentionally remain manual to preserve user control over non-permission decisions.
- Android background worker continuity: when the app returns from background, pending permissions collected during background status probes can be auto-approved without requiring the user to manually revisit each session, always using `always` with `remember: true` and the same cooldown logic.
- Background auto-approve uses the same drain coordinator semantics as foreground, ensuring consistent behavior across both paths.

**Risk analysis**:
- Medium UX/safety risk (foreground): mirrored descendant prompts can be approved without a second explicit tap in the child session.
- Medium UX/safety risk (background): the background worker may approve permissions for sessions that were active when the app entered background, even if the user has since switched contexts — mitigated by scoping the auto-approve context to the exact session/thread hierarchy present at prime time and requiring the same `composerAutoApprovePermissions` toggle.
- Low contract risk: the server still receives a normal permission reply payload (`always` or `once`), and question prompts keep the official manual path in both foreground and background paths.
- Low data-risk: the background context is cleared when the chat screen is left, when the toggle is disabled, or when the device switches away from the active server.

**Rollback / feature-flag plan**:
- Immediate rollback (foreground): user disables the composer toggle locally.
- Immediate rollback (background): user disables the composer toggle locally — the background context is cleared on the next lifecycle event.
- Product rollback: revert the composer toggle and drain coordinator commits; the background context key (`codewalk.android.background.permission_auto_approve.v1`) is removed from SharedPreferences on clear.
- Safe fallback: existing inline permission cards remain available as the manual approval path in both foreground and background flows.

**`remember: true` with `always` permission replies**: When CodeWalk auto-approves a permission request, it always sends `always` with `remember: true` in the permission reply body per the documented OpenCode permission reply contract. This ensures the server persists the grant so that future identical permission requests from the same session hierarchy are automatically approved server-side, reducing repeated auto-approve round-trips. `'always'` grants are session-scoped and do not survive OpenCode process restarts — this is the safety guarantee.

**Regression coverage**:
- Widget coverage verifies default-on behavior, persisted opt-out, mirrored subsession auto-approval, and non-regression for question prompts.
- The drain coordinator always uses `always` with `remember: true`, and cools down requests that throw during auto-approval.
- Background worker tests verify that auto-approve is scoped to primed session IDs, respects 404 as success (already resolved), and correctly clears context on lifecycle changes.

**Code locations**:
- `lib/domain/entities/experience_settings.dart` — `composerAutoApprovePermissions` toggle entity
- `lib/presentation/providers/settings_provider.dart` — toggle state and persistence
- `lib/presentation/services/permission_auto_approve_runtime.dart` — shared `permissionAutoApproveReplyForAlwaysPatterns`, `PermissionAutoApproveBackgroundContext`, `collectThreadSessionIds`, `resolveThreadSessionIdsForBackgroundContext`
- `lib/presentation/services/android_background_alert_worker.dart` — background auto-approve execution via `_runPermissionAutoApproveDrain`; context prime/clear via `primePermissionAutoApproveContext`/`clearPermissionAutoApproveContext`; feature flag key `codewalk.android.background.permission_auto_approve.v1`
- `lib/presentation/pages/chat_page/chat_page_model_selector_runtime.dart` — toggle UI widget
- `lib/presentation/pages/chat_page/chat_page_lifecycle.dart` — `_backgroundPermissionAutoApproveContextSignature` lifecycle management, `_scheduleAutoApprovePermissionDrain` coordinator

---

## ADR-024: Modal Enter Keyboard Policy (2026-03-25)

**Status**: Accepted

### Context

Users expect to confirm simple, non-destructive dialogs with the Enter key
without reaching for the mouse or tapping the primary button. CodeWalk already
implements this pattern locally in Quick Open, but the behavior was not
consistent across other safe dialogs.

The app also includes modal surfaces where Enter-confirmation is inappropriate:

- destructive confirmations should require deliberate confirmation;
- shortcut-capture dialogs must receive raw Enter keystrokes;
- multiline canned-answer editing needs Enter for line breaks; and
- picker/search/selector bottom sheets use Enter for navigation or selection.

### Decision

Non-destructive dialogs with **a single, unambiguous primary action** may
respond to `Enter` and `NumpadEnter` to trigger that action.

The following modal categories are explicitly excluded from this policy:

- **Destructive confirmations** — delete/reset/eject style dialogs must not map
  Enter to the irreversible action by default.
- **Shortcut-capture dialogs** — dialogs that record keyboard shortcuts must not
  intercept Enter before capture is completed intentionally.
- **Multiline canned-answer editing** — dialogs where Enter is part of text
  editing must preserve newline behavior.
- **Picker/search/selector bottom sheets** — sheets that use Enter for item
  navigation or selection remain manual unless redesigned for keyboard-first
  confirmation.

### Key Files

- `lib/presentation/widgets/modal_primary_action_shortcuts.dart`

### Rationale

- **Ergonomics**: desktop and external-keyboard users can confirm safe dialogs
  faster.
- **Clarity**: the rule is easy to apply - safe single-action dialogs may opt
  in, excluded categories stay manual.
- **Consistency**: the reusable wrapper keeps the keyboard behavior explicit and
  centralized.
- **Safety**: the exclusion list prevents accidental destructive confirmations
  or conflicts with text editing and key capture.

### Consequences

- Eligible dialogs can opt into Enter/NumpadEnter confirmation with a single
  reusable wrapper.
- New modal surfaces must be evaluated against the exclusion list before adding
  Enter support.
- Destructive confirmations, shortcut capture, multiline canned-answer editing,
  and picker/search/selector bottom sheets remain manual until a future ADR
  changes the policy.

### ADR-023 Compatibility

This policy is additive and local to Flutter keyboard routing. It does not
change OpenCode server behavior, API contracts, realtime lifecycle, or model
semantics, so no ADR-023 exception is required.

### Code Locations

- `lib/presentation/widgets/modal_primary_action_shortcuts.dart`
- `lib/presentation/pages/chat_page/chat_page_workspace_controller.dart`
- `lib/presentation/widgets/chat_session_list.dart`
- `lib/presentation/pages/onboarding_wizard_page.dart`
- `lib/presentation/widgets/moonshine_model_download_dialog.dart`
- `lib/presentation/widgets/sherpa_model_download_dialog.dart`

## ADR-025: Settled Assistant-Work Disclosure Ownership (2026-04-01)

### Status

Accepted

### Context

Repeated regressions have shown that BEHAVIOR.md invariants alone are insufficient to prevent open/close thrash of the latest assistant-work group. Repeated scroll jumps and final-message unreadability on both mobile and desktop indicate a need for architectural ownership of disclosure state — not just behavioral documentation.

Scope is limited to **client-side disclosure ownership** for the latest settled assistant-work group in chat.

### Decision

1. **Settled disclosure ownership** belongs to the latest assistant-work group that has been explicitly revealed or collapsed by the user or by a structural visibility change.

2. **Passive data inputs only**: `session.status`, background refresh, and revalidation are data inputs only. They must **not** by themselves reopen or re-collapse a settled latest assistant-work group.

3. **On session return**, settled disclosure ownership must be **reconstructed from the currently visible message structure** before any passive busy pulse can influence viewport or collapse policy.

4. **Only the following may clear settled ownership**:
   - A newer revealable assistant message
   - A newer user turn
   - A structural visibility change that removes the group

### Rationale

- Prevents repeated open/close thrash during passive refresh cycles.
- Ensures final-message readability by stabilizing the latest group state.
- Eliminates scroll jumps on both mobile and desktop during session return.
- Architectural ownership is more robust than invariant documentation for this class of regression.

### Consequences

- ✅ Positive: Stable disclosure behavior across session return, background refresh, and revalidation cycles.
- ✅ Positive: Eliminates thrash and scroll jumps for the latest assistant-work group.
- ⚠️ Warning: Any new passive data pipeline that influences viewport must be audited against this rule.
- ⚠️ Warning: Structural visibility changes (e.g., group removal) must explicitly clear ownership — no implicit side effects.
- ❌ Trade-off: Older groups do not receive this protection; only the latest settled group is scoped.

### ADR-023 Compatibility

This ADR is fully compatible with ADR-023 and official OpenCode lifecycle semantics. It introduces no server contract change, no custom busy protocol, and no deviation from the OpenCode message lifecycle. All state is client-side reconstruction from existing message structure.

**Note** (commit `9284223`): Session return and app-resume restore behavior refined for cached sessions:
1. **Cached settled session switch/return** — reveals the latest assistant response (disclosure ownership preserved, viewport positioned on final message).
2. **Cached active session switch/return** — lands at bottom to follow ongoing streaming activity.
3. **App-resume restore waits for refresh completion** — scroll/restore consumption is deferred until background refresh finishes, preventing stale viewport reconstruction.
4. **Passive refresh callbacks promote queued latest-response restore** — instead of defaulting to bottom-following, the passive refresh callback promotes the previously queued latest-response reveal, ensuring the user sees the most recent settled content.

---

## ADR-026: Cross-Platform Terminal Workspace with Local PTY Shell (2026-04-03) ⚠️ SUPERSEDED by ADR-027

**Status**: Superseded

### Context

CodeWalk provides a chat-based UI for interacting with OpenCode servers, but some workflows benefit from direct shell access in the active project directory. Users on both desktop and mobile need a way to open a local PTY terminal without leaving the chat workspace. The feature must preserve ADR-023 parity by remaining entirely client-side — no server contract changes, no new endpoints, and no deviation from OpenCode lifecycle semantics.

### Decision

1. **Cross-platform local PTY shell**: On all supported platforms (Linux, macOS, Windows, Android), CodeWalk spawns a local PTY shell process rooted in the active project directory, displayed in an embedded terminal panel within the chat workspace.
2. **No server API changes**: The terminal is a purely local shell — it does not invoke `opencode attach` or any OpenCode CLI command. No new endpoints, events, or server-side behavior changes are required.
3. **Project directory integration**: The shell launches in the active project's working directory (the `scopeId` from the current `serverId::scopeId` context), giving users immediate access to the files and tools relevant to their conversation.
4. **Panel lifecycle with explicit actions**:
   - **Stop**: fully closes the terminal panel and terminates the running PTY process.
   - **Hide**: minimizes the panel without stopping the shell — the session persists and can be restored.
   - **Maximize/Restore**: toggles the terminal between a compact inline panel and a maximized full-workspace view.
5. **Composer visibility on compact/mobile**: On compact and mobile layouts, the composer input area is hidden while the terminal panel is open, freeing vertical space for the embedded shell. The composer reappears when the terminal is hidden or stopped.
6. **Local shell prerequisite**: The terminal uses the platform's default shell (`$SHELL` on Unix, PowerShell/CMD on Windows). No external command path configuration is required.

### Rationale

- Direct shell access in the project directory supports workflows like git operations, build commands, file inspection, and quick edits that complement the AI-driven chat conversation.
- Launching from within the chat workspace keeps the terminal discoverable and close to the conversation that is driving the work.
- A local PTY shell is simpler and more general-purpose than `opencode attach` — it works without requiring the OpenCode CLI to be installed locally and gives users full shell capability.
- No server API changes means zero contract risk and full ADR-023 compliance.
- Keeping the terminal panel client-owned preserves a simple boundary: CodeWalk manages PTY lifecycle locally while the OpenCode server remains the source of truth for shared sessions and state.
- Extending to mobile/compact layouts follows the project's mobile-first UX principle — users deserve the same embedded shell capability regardless of device, with layout-adaptive behavior (composer hide, maximize/restore) to fit smaller viewports.
- Explicit stop vs. hide semantics prevent ambiguity: users know whether they are closing the session or just minimizing it.

### Consequences

- ✅ All platforms (desktop + Android) get a local shell in the active project directory without leaving CodeWalk.
- ✅ Zero server API changes — fully compatible with ADR-023 contract-first policy.
- ✅ No external CLI dependency — uses the platform's default shell.
- ✅ Hide/restore preserves the current shell session during the active chat screen lifetime.
- ✅ Stop provides a clean, unambiguous way to fully close the panel and kill the process.
- ✅ Maximize/restore gives flexible viewport control on all screen sizes.
- ✅ Composer auto-hide on compact/mobile layouts prevents cramped UX and maximizes terminal space.
- ⚠ The shell runs with the user's local environment and permissions — CodeWalk does not sandbox or restrict shell access.
- ⚠ Long-running background processes in the shell are not managed by CodeWalk lifecycle and may outlive the chat session.
- ⚠ Mobile/compact layouts sacrifice composer visibility while the terminal is open — users must hide/stop the terminal to resume chat composition.
- ❌ None — previous mobile informational fallback has been replaced with full embedded terminal support.

### Key Files

- `lib/presentation/services/codewalk_terminal_controller.dart`
- `lib/presentation/services/codewalk_terminal_process.dart`
- `lib/presentation/services/codewalk_terminal_process_io.dart`
- `lib/presentation/widgets/codewalk_terminal_panel.dart`
- `lib/presentation/pages/chat_page/chat_page_terminal_runtime.dart`
- `lib/presentation/providers/project_provider.dart` (active project directory access)

### ADR-023 Compatibility

This feature is fully compatible with ADR-023. It introduces no server contract changes, no new API endpoints, and no deviation from OpenCode lifecycle semantics. It is a purely client-side terminal surface that spawns a local PTY shell in the active project directory, leaving session/state ownership entirely with the official OpenCode server.

---

## ADR-027: Server-Hosted PTY Terminal with Embedded Client Rendering (2026-04-03)

**Status**: Accepted

**Supersedes**: ADR-026 (Cross-Platform Terminal Workspace with Local PTY Shell)

### Context

ADR-026 specified a local PTY shell spawned on the client device using `flutter_pty`. This approach has fundamental limitations: it requires native PTY libraries on every platform (including Android), ties terminal availability to the client's local environment, and cannot leverage the OpenCode server's project directory context. The architecture has been rewritten to use a server-hosted PTY that runs on the OpenCode host in the active project directory, with the client rendering terminal output via an embedded terminal panel over a streaming transport.

### Decision

1. **Server-hosted PTY**: The PTY shell process runs on the OpenCode server host, rooted in the active project directory. The client no longer spawns local shell processes.
2. **Client rendering via embedded terminal panel**: The Flutter client renders terminal output using an embedded terminal panel (xterm.js-compatible rendering), receiving streaming data from the server over WebSocket/SSE transport.
3. **Local `flutter_pty` shell removed**: All `flutter_pty` dependencies, platform-specific PTY spawning code, and local shell lifecycle management are removed from the client codebase.
4. **Panel lifecycle semantics preserved**:
   - **Close**: terminates the server-side PTY session and removes the panel.
   - **Minimize**: hides the panel without terminating the server-side session — can be restored.
   - **Maximize**: toggles between compact inline panel and full-workspace view.
5. **Composer auto-hide on compact/mobile**: On compact and mobile layouts, the composer input area is hidden while the terminal panel is open. The composer reappears when the terminal is minimized or closed.
6. **Project directory integration**: The server-side PTY launches in the active project's working directory (the `scopeId` from the current `serverId::scopeId` context), ensuring the shell operates in the same workspace the chat conversation is about.
7. **No server API contract changes**: The terminal transport reuses existing OpenCode streaming infrastructure (WebSocket or SSE). No new dedicated terminal endpoints are introduced — the server exposes PTY data through the established event stream contract.
8. **Windows printable hardware-key fallback and AltGr support**: The vendored `xterm` `TerminalView` includes a Windows-only fallback that handles printable hardware-key events (raw scan codes) and AltGr key composition. This guards against input regression on international keyboard layouts where AltGr produces alternate characters (e.g. European layouts). The fallback is gated behind `TargetPlatform.windows` (Flutter platform gate) and does not affect other platforms.

### Rationale

- **Server-hosted PTY matches the OpenCode model**: The server already owns the project directory context, environment, and toolchain. Running the shell there eliminates client-side environment variability and ensures the terminal operates in the same context as the AI agent.
- **Removes native dependency burden**: `flutter_pty` requires platform-specific native compilation (C libraries, NDK for Android, etc.). Server-hosted PTY shifts this complexity to the server, which already has a full POSIX environment.
- **Unified experience across all clients**: Desktop, mobile, and web clients all get the same terminal capability without platform-specific code paths or feature parity gaps.
- **Preserves UX semantics**: Close/minimize/maximize and composer auto-hide behaviors from ADR-026 are retained — only the execution location changes.
- **ADR-023 alignment**: By reusing existing OpenCode streaming transport rather than introducing new endpoints, this decision stays within the contract-first policy. The server's PTY is an extension of its existing workspace management, not a new API surface.

### Consequences

- ✅ Terminal works identically on all client platforms (desktop, mobile, web) with no platform-specific native dependencies. Windows AltGr and hardware-key fallback preserves input parity for international keyboard layouts.
- ✅ Server-side PTY runs in the correct project environment with full toolchain access.
- ✅ Removes `flutter_pty` native compilation complexity from the client build pipeline.
- ✅ Close/minimize/maximize semantics and composer auto-hide on compact/mobile are preserved.
- ✅ No new server API endpoints — reuses existing streaming transport, maintaining ADR-023 compliance.
- ⚠ Terminal availability depends on the OpenCode server supporting PTY sessions — clients connecting to servers without this capability must show a graceful fallback.
- ⚠ Network latency affects terminal responsiveness compared to local PTY — acceptable for interactive use but may feel less snappy than ADR-026's local shell.
- ⚠ Server resource usage increases (one PTY process per active terminal session per client).
- ❌ Offline terminal access is no longer possible — the terminal requires an active server connection.

### Key Files

- `lib/presentation/services/codewalk_terminal_controller.dart` — client-side terminal lifecycle and state orchestration
- `lib/data/datasources/terminal_remote_datasource.dart` — remote PTY session API calls
- `lib/data/models/pty_session_model.dart` — PTY session data model and serialization
- `lib/presentation/services/codewalk_terminal_socket.dart` — WebSocket transport contract
- `lib/presentation/services/codewalk_terminal_socket_io.dart` — IO platform WebSocket implementation
- `lib/presentation/services/codewalk_terminal_socket_stub.dart` — web/no-op stub
- `lib/presentation/services/codewalk_terminal_url.dart` — terminal endpoint URL resolution
- `lib/presentation/widgets/codewalk_terminal_panel.dart` — embedded terminal panel UI
- `lib/presentation/pages/chat_page/chat_page_terminal_runtime.dart` — chat page terminal integration
- `lib/presentation/providers/project_provider.dart` (active project directory access)

### ADR-023 Compatibility

This feature is fully compatible with ADR-023. It reuses existing OpenCode streaming transport (WebSocket/SSE) for terminal I/O rather than introducing new API endpoints or contract changes. The server-side PTY is an extension of the server's workspace management, and the client acts purely as a rendering surface — session/state ownership remains entirely with the official OpenCode server. No divergence from official OpenCode CLI/Web lifecycle semantics is introduced.

---

## ADR-028: Unified Scroll Ownership Model for Chat Timeline (2026-04-04)

**Status**: Accepted

### Context

The chat timeline experienced recurrent scroll jumping across three trigger scenarios: user sending a message, app returning from background, and scrolling to load older messages. Multiple targeted fixes over time addressed individual scroll paths but the bug kept returning because each fix addressed one scroll owner without coordinating across all competing scroll sources. Five concurrent scroll owners (`_handleScrollMetricsChanged` snap, `_runScrollToBottom`, `_revealLatestMessageReturnReveal`, `_loadOlderMessagesAndRestoreAnchor`, and provider `_scheduleScrollToBottom`) raced against each other without a unified priority system.

### Decision

1. **Unified scroll ownership via `_ScrollOwner` enum** — `none`, `userDrag`, `paginationRestore`, `newMessage`, `streaming`, `returnReveal`, `contentShrinkSnap` replacing scattered boolean coordination
2. **Hardened `_handleScrollMetricsChanged` content-shrink snap gates** — blocks on return reveal in-flight, pagination restore in-flight, and any non-none scroll owner
3. **Serialized background resume scroll actions** — `_handleReturnToChat` defers reveal via `addPostFrameCallback` with mounted guard to avoid racing with provider-triggered scrolls
4. **`_runScrollToBottom` gates on `_currentScrollOwner == userDrag`** for non-force scrolls, preventing scroll hijacking during user drag
5. **`_lastKnownMaxScrollExtent` update moved to end of handler** to avoid false "content grew" detection during transitions
6. **Timeline cache invalidation logging** for future diagnosis of unnecessary repaints

### Rationale

- A single source of truth for scroll ownership eliminates race conditions between competing scroll sources
- The enum approach is more maintainable than scattered boolean flags because it makes the ownership model explicit and prevents future regressions from new scroll paths being added without coordination
- PostFrameCallback deferral ensures the widget tree is stable before initiating scroll animations on background resume
- Force scrolls (user message send, FAB tap) bypass all gates to maintain responsiveness for explicit user actions

### Consequences

- ✅ Scroll jumping eliminated across all three trigger scenarios (send message, return from background, load older messages)
- ✅ Unified `_ScrollOwner` enum replaces scattered boolean coordination
- ✅ User drag always takes priority — programmatic scrolls defer until user releases
- ✅ Force scrolls (user message send, FAB tap) bypass all gates
- ✅ Timeline cache survives passive refresh pulses without invalidation
- ✅ Widget regression tests cover all identified race conditions
- ⚠ `_isProgrammaticScrollInFlight` and `_isReturnRevealInFlight` booleans kept for backward compatibility with final assistant reveal path — should be migrated to enum in future cleanup
- ⚠ Debug logging for owner transitions not yet added — would help trace ownership handoffs during scroll races

**Note** (commits `d1cb997`, `1395955`, `042705a`): Practical guardrails tightened around four scroll-race surfaces without changing the architectural contract:
1. **Passive provider scroll suppression** — provider-triggered scroll-to-bottom requests are now suppressed when the user is actively reading near the bottom edge, preventing viewport jumps from background SSE pulses.
2. **Manual follow pause near bottom** — when the user manually scrolls near the bottom (within a small threshold), auto-follow is paused to avoid fighting intentional user positioning.
3. **Response-settle shrink-snap suppression** — content-shrink snap is suppressed during the response-settle window after a streaming response completes, preventing the viewport from jumping when the message bubble collapses from streaming to settled layout.
4. **Duplicate return-to-chat debounce scoping** (`042705a`) — the return-to-chat debounce was narrowed to deduplicate only identical signatures (same trigger source + same timestamp window), preventing unrelated return-to-chat calls from being incorrectly coalesced.

**Note** (commit `9284223`): Cached session restore now uses a single queued restore target instead of an unconditional reopen bottom snap:
1. **Settled cached restore reveals the latest assistant response** — cached session switch/return restores directly to the latest revealable assistant response instead of always snapping to bottom.
2. **Active cached restore still lands at bottom** — cached sessions that are still processing keep bottom-follow behavior.
3. **Resume restore waits for refresh completion** — app-resume restore consumption is deferred until resume revalidation finishes, so refreshed settled content is revealed once instead of bottom-snapping before the newer tail appears.
4. **Passive refresh promotion respects queued latest-response restore** — passive refresh callbacks promote a queued latest-response restore for that same session instead of requesting a competing bottom-follow scroll.

**Note** (commit `161b9ce`): Passive background reconcile now keeps the active-turn lock and scopes unsupported message fallback more narrowly:
1. **Current-session active-turn detection resists transient idle pulses** — a current-session send in progress or incomplete assistant message keeps the session in responding mode even if `session.status` briefly reports `idle` first.
2. **Unsupported global `message.*` fallback only refreshes the visible session when explicitly targeted** — active-context fallback reconcile for unsupported message events is now scoped to the current session id, and it is suppressed while a local stream or compaction guard is active.
3. **Passive latest-message signal remains semantic, not a settle override** — settled passive refreshes may still report a latest-message change for unread/latest affordances, but they no longer depend on transient idle status to unlock final reveal or collapse.

**Note** (commits `81edb30`, `4aa9a00`): Active-turn follow and final reveal were simplified for the remaining live-turn jitter/reveal bugs:
1. **Passive provider re-entry is suppressed during active response while still preserving unread/latest affordances after manual follow pause** — active turns no longer perform visible per-tool-call bottom corrections when the user is already passively following.
2. **Growth-time bottom snap keeps active turns visually pinned** — streamed tool/reasoning/text growth uses a runtime bottom snap while actively responding instead of repeated animated correction churn.
3. **Final assistant reveal uses a single reading-mode reveal** — the extra corrective final reveal pass was removed, and long final answers now enter reading mode instead of remaining pinned to bottom.
4. **Final reveal skips when the whole answer already fits and otherwise targets the clarified mid-screen contract** — the viewport math only runs when the full final message would not already be fully visible.
5. **Final reveal viewport math is guarded by mounted/hasSize checks** (`4aa9a00`) — fast navigation/unmount races now reschedule instead of touching invalid render contexts.

**Note** (2026-06-17): Reading-mode final reveal now separates "not pinned to bottom" from "unread below":
1. **Revealed final responses are read** — once the start of the latest completed assistant response is shown, `reading` mode does not show `Go to latest` merely because the answer is taller than the viewport.
2. **Passive pulses preserve settled reading** — status/revalidation events for that same latest completed assistant response keep the settled work ownership and do not re-enter active collapse deferral or mark the response unread.
3. **Manual pause remains distinct** — user-initiated scrolling still moves the viewport to `pausedByUser`, where new content below the visible position may surface the unread/latest affordance.

**Note** (commits `80ad3a5`, `49c0f7d`): Active-turn assistant work rendering now defers synthetic tool-only merge until settlement:
1. **Raw tool-call bubbles remain visible during the active turn** — consecutive tool-only assistant messages are rendered as separate entries while the current run is still responding.
2. **Synthetic tool-only merge now happens only after settlement** — merged tool-run bubbles remain a settled/history presentation and are no longer used as a live-turn optimization.
3. **Active-turn assistant entrance animation suppression is scoped to tool-only bubbles** (`49c0f7d`) — the final assistant text response may still animate normally once the turn settles.
4. **Active-turn structural shrink is treated as a forbidden regression source** — live tool-only merge/replacement during the active run is no longer allowed because it can shorten the rendered list above the viewport, create a temporary bottom vacuum, and amplify typing/repaint churn.

**Note** (commit `0b1e5a6`): Active-turn shrink healing now closes the remaining bottom-vacuum gap without fighting manual reading:
1. **Passive-follow active turns may heal shrink immediately** — when the user is still passively following the active turn, a non-animated bottom-anchor heal may run on content shrink to remove a temporary blank vacuum.
2. **Manual scroll-away still wins** — the active-turn shrink heal is gated behind auto-follow/manual-pause state so it does not yank the viewport back after the user leaves the bottom.
3. **Active-turn tool-chain size animation is disabled** — the tool-chain body no longer uses `AnimatedSize` while the session is actively responding, reducing shrink/reflow churn and typing lag.

### Key Files

- `lib/presentation/pages/chat_page.dart` — `_ScrollOwner` enum definition, `_currentScrollOwner` state field, `_setScrollOwner()` helper
- `lib/presentation/pages/chat_page/chat_page_runtime_support.dart` — `_handleScrollMetricsChanged` hardened gates, `_runLatestMessageReturnReveal` owner integration
- `lib/presentation/pages/chat_page/chat_page_scroll_coordinator.dart` — `_handleScrollChanged` user drag detection, `_runScrollToBottom` owner gates, `_loadOlderMessagesAndRestoreAnchor` owner integration
- `lib/presentation/pages/chat_page/chat_page_lifecycle.dart` — `_handleReturnToChat` PostFrameCallback deferral with mounted guard
- `lib/presentation/pages/chat_page/chat_page_timeline_builder.dart` — cache invalidation logging
- `test/widget/chat_page_test.dart` — 2 new regression tests for scroll stability and cache reuse

---

## ADR-029: Host-Discovered Quota and Rate-Limit Monitoring for OpenChamber Parity (2026-04-09, updated 2026-08-12)

**Status**: Accepted

**Related**: ADR-023 (Official OpenCode Contract-First Compatibility Policy), ADR-001 (Multi-Server Orchestration, Scoped Persistence, and Secure Credential Storage). Ref: issue #96.

### Context

CodeWalk requires visibility into model quotas and rate-limits to prevent silent task failures due to exhausted provider balances. Official OpenCode (ADR-023) still does not expose a unified real-time quota/rate-limit API for all backend providers; OpenChamber, as a community-driven server implementation, provides extended REST endpoints for this purpose. CodeWalk aims for functional parity with OpenChamber's monitoring capabilities while maintaining strict adherence to official OpenCode contracts as the primary source of truth. Since issue #96, OpenCode Go quota is read using the host's own `auth.json` API key against the OpenCode Go usage API (`GET https://opencode.ai/zen/go/v1/usage`, Bearer auth) — not client workspace IDs, auth cookies, or HTML scraping. That endpoint is not part of the official OpenCode API contract; it is consumed as an OpenChamber-parity surface and recorded here for historical clarity without being presented as official.

### Decision

1. **Server-Host-Only Quota Ownership** — The app never manages or stores provider credentials for quota checking. It relies entirely on the connected host's environment and discovered provider configurations.
2. **Strategy-Chain Transport** — Quota data is fetched using a tiered discovery strategy:
    - **OpenChamber REST** — Use `GET /api/quota/providers` and then `GET /api/quota/{providerId}` when those endpoints are available.
    - **Hidden Shell Fallback** — Create a hidden ephemeral OpenCode session, execute a Base64-encoded Node.js probe through `POST /session/:id/shell`, parse the final `CW_QUOTA_JSON:` line, and delete the probe session after completion.
3. **Popup-Only UI (Compact-First)** — The monitoring interface is restricted to the "Context usage" popup. It is hidden by default in compact/mobile layouts to preserve composer real-estate, appearing only on explicit user invocation.
4. **Grouped Providers with Pace/Progress Semantics** — UI displays providers grouped by parent organization (OpenAI, Anthropic, etc.) using progress bars that reflect both absolute remaining quota and "Pace" (usage rate over time) to warn of imminent rate-limiting.
5. **Auth Key Register** — `_supportedAuthKeys` is the single Dart-side register for shell fallback provider aliases and the `unsupportedConfigured` diagnostic filter. Adding a new shell probe requires updating both the dispatcher and this register.
6. **Explicit Feature-by-Feature Parity Opt-in** — Future OpenChamber features will not be auto-adopted. Each parity addition must be explicitly evaluated, documented via ADR, and gated behind feature-specific capability checks.
7. **Host-Owned OpenCode Go Usage Probe** — OpenCode Go quota is fetched inside the host-side shell probe using the host's `auth.json` `opencode-go` entry (accepting `key`, `access`, or `token` fields) against `GET https://opencode.ai/zen/go/v1/usage` with an `Authorization: Bearer` header, `Accept: application/json`, and a 15-second timeout. The probe parses the `usage` object's `rolling`, `weekly`, and `monthly` windows (`percent` used, optional `resetsAt`). No client workspace ID, no dashboard auth cookie, and no HTML scraping. Failures are classified as `authentication` (HTTP 401/403), `request_failed` (other non-OK HTTP status or transport errors), or `invalid_response` (unparseable payload or zero usable windows). Partial windows are tolerated: unparseable window entries are skipped, `resetsAt` is applied only when parseable, and only a payload with no usable windows is classified `invalid_response`. The Context usage popup shows a failure card keyed by this classification.
8. **One-Time Best-Effort Legacy Credential Purge** — At the start of quota loading, purge all legacy OpenCode Go dashboard credential keys (`opencode_go_workspace_id`, `opencode_go_auth_cookie`) from secure storage once per `QuotaProvider` instance. Matching covers exact keys and prefix matches (`<namespace>::<key>` and `<namespace>::<key>::...`), so serverId-scoped and orphaned profile keys are removed as well. The purge is best-effort (secure-storage errors are swallowed), gated by an in-memory instance flag, and never blocks quota fetching.

### Rationale

- **ADR-023 Priority** — Official OpenCode remains the primary contract. OpenChamber parity is additive and must never conflict with official lifecycle or API semantics.
- **Security** — By enforcing server-host ownership, the client avoids the risk of credential leakage and maintains the security boundaries established in ADR-001.
- **Resilience** — The strategy-chain ensures monitoring works across both official servers (via hidden shell fallback) and OpenChamber-enhanced servers (via REST).
- **UX** — Grouping and Pace semantics provide actionable insights rather than just raw numbers, helping users manage long-running agent tasks.
- **Host-owned OpenCode Go key (issue #96)** — The host's `auth.json` already carries the OpenCode Go API key that authorizes the usage API; probing with it keeps the client at zero provider credentials instead of reintroducing a dashboard cookie/workspace-ID opt-in.
- **Legacy purge** — The previous dashboard credential set is no longer used anywhere; a one-time best-effort purge removes it (including orphaned profile variants via prefix matching) without blocking quota loading.
- **Historical clarity** — `https://opencode.ai/zen/go/v1/usage` is consumed directly by the probe but is not part of the official OpenCode API contract; it is documented as an OpenChamber-parity surface so future readers do not mistake it for an official endpoint.

### Consequences

- ✅ Real-time visibility into provider limits prevents unexpected agent stalls.
- ✅ Near-zero-credential client: no provider credentials are stored; the `opencode-go` dashboard cookie/workspace-ID opt-in was removed (issue #96).
- ✅ OpenCode Go monitoring works on any host whose `auth.json` carries an `opencode-go` API key — no client workspace ID, auth cookie, or HTML scraping.
- ✅ One-time best-effort purge removes all legacy `opencode_go_workspace_id` / `opencode_go_auth_cookie` secure-storage keys via exact and prefix matching, including orphaned profile keys.
- ✅ Failure classification (`authentication` / `request_failed` / `invalid_response`) plus tolerated partial windows keeps OpenCode Go failures diagnosable without over-reporting.
- ✅ Graceful degradation between OpenChamber REST and official shell-only hosts.
- ⚠️ Potential performance impact when using shell fallback (process spawn overhead on server).
- ⚠️ UI density in the Context popup increases; requires careful MD3/Material You spacing.
- ⚠️ The OpenCode Go usage endpoint is not part of the official OpenCode API contract and may change or disappear without notice; it is an OpenChamber-parity surface only.
- ❌ No offline quota visibility; requires active server connection.

### Key Files

- `lib/data/datasources/quota_remote_datasource.dart` — Strategy-chain implementation (OpenChamber REST → shell fallback)
- `lib/data/datasources/quota_remote_datasource.part.js.dart` — Base64-encoded Node.js one-liner payload for shell-fallback quota probing (minified multi-provider JS encoded at compile time, decoded at runtime via `node -e "eval(Buffer.from('BASE64_PAYLOAD','base64').toString())"`); includes the host-owned OpenCode Go probe against `GET https://opencode.ai/zen/go/v1/usage`
- `lib/data/datasources/app_local_datasource.dart` — `clearOpenCodeGoDashboardCredentials()` legacy credential purge (exact + prefix matching)
- `lib/domain/entities/quota.dart` — Domain entities: `QuotaSnapshot`, `UsageWindow`, `PaceInfo`, `QuotaEntry`, `QuotaProviderGroup`
- `lib/presentation/providers/quota_provider.dart` — Polling, TTL cache, server-scoped state, provider grouping, Codex `providerId` guard that prevents single-window label collapse for Codex entries by preserving per-window granularity in grouped display, and the one-time legacy purge gate (`_clearLegacyOpenCodeGoCredentials`)
- `lib/presentation/utils/quota_pace_utils.dart` — Pure Dart pace calculation, window label inference, and formatting
- `lib/presentation/widgets/quota/quota_popup_section.dart` — Root quota widget embedded in the Context usage popup
- `lib/presentation/widgets/quota/quota_provider_group_row.dart` — Grouped provider expand/collapse row
- `lib/presentation/widgets/quota/quota_entry_row.dart` — Individual quota entry with severity color progress bar
- `lib/presentation/widgets/quota/pace_label.dart` — Desktop tooltip / mobile snackbar pace explanation
- `lib/presentation/pages/chat_page/chat_page_status_presenter.dart` — Hosts `_buildContextUsagePopover` which includes `QuotaPopupSection`
- `lib/core/di/injection_container.dart` — DI wiring for `QuotaRemoteDataSource` and `QuotaProvider`

### Provider Register

The following shell fallback probes are implemented by the strategy-chain. REST can return any provider supported by an OpenChamber-compatible host; the shell fallback covers the providers below from the host's `auth.json`, environment, or provider-specific local files as noted in code.

| # | Provider Key | Description | Group |
|---|-------------|-------------|-------|
| 1 | `anthropic` / `claude` | Anthropic Claude OAuth usage windows | Anthropic |
| 2 | `openrouter` | OpenRouter credit usage | OpenRouter |
| 3 | `openai` / `codex` / `chatgpt` | Codex / ChatGPT usage windows and credits | OpenAI |
| 4 | `google` / `google.oauth` | Gemini and Antigravity quota windows | Google |
| 5 | `github-copilot` / `copilot` | GitHub Copilot quota | GitHub |
| 6 | `github-copilot-addon` | GitHub Copilot add-on quota | GitHub |
| 7 | `opencode-go` | OpenCode Go rolling, weekly, and monthly usage via host `auth.json` API key against the OpenCode Go usage API (no client dashboard credentials) | OpenCode |
| 8 | `nano-gpt` | NanoGPT API usage and rate-limits | NanoGPT |
| 9 | `wafer` | Wafer API usage and rate-limits | Wafer |
| 10 | `kimi-for-coding` | Kimi for Coding API usage | Moonshot |
| 11 | `zhipuai-coding-plan` | ZhipuAI coding plan quota | ZhipuAI |
| 12 | `minimax-coding-plan` | MiniMax coding plan quota (international) | MiniMax |
| 13 | `minimax-cn-coding-plan` | MiniMax coding plan quota (China domestic, inverted remains semantics) | MiniMax |
| 14 | `zai-coding-plan` | ZAI coding plan quota | ZAI |
| 15 | `cursor` | Cursor usage, plan limits, and credits | Cursor |
| 16 | `ollama-cloud` | Ollama Cloud hosted model usage | Ollama |

`_supportedAuthKeys` also recognizes aliases for recent OpenCode provider additions (`snowflake-cortex`, `grok`/`xai`, and `cohere-north`) so they are not misreported as unknown configuration. Dedicated shell probes for those providers are not yet implemented; they become visible through REST only when the connected host supplies them.

### OpenCode Go Usage Probe (issue #96) — Host-Owned, Not Client Dashboard Credentials

Earlier revisions of this ADR carried a narrow opt-in exception that stored an OpenCode Go dashboard workspace ID and auth cookie client-side for quota probing. That exception is **removed**: since issue #96, the probe uses the host's own `auth.json` `opencode-go` API key (`key`, `access`, or `token` fields) against `GET https://opencode.ai/zen/go/v1/usage` with `Authorization: Bearer`. No client workspace ID, no auth cookie, and no HTML scraping of the dashboard.

**One-Time Best-Effort Legacy Purge** — To retire the previous design safely, quota loading performs a one-time, best-effort purge of all legacy secure-storage keys for the dashboard credential set:

- Key families removed: `opencode_go_workspace_id` and `opencode_go_auth_cookie` under the secure-storage namespace.
- Matching is exact plus prefix-based (`<namespace>::<key>` and `<namespace>::<key>::...`), which also covers serverId-scoped variants and orphaned profile keys left behind by deleted server profiles.
- Best-effort by design: secure-storage read/write failures are swallowed so quota loading stays functional; an in-memory flag ensures the purge runs at most once per `QuotaProvider` instance and never blocks fetching.

**Failure Classification** — The probe reports failures as `authentication` (HTTP 401/403), `request_failed` (other non-OK HTTP status or transport errors), or `invalid_response` (unparseable payload or zero usable windows). Partial windows are optional: entries that cannot be parsed are skipped, `resetsAt` is used only when parseable, and only a payload with no usable windows is classified `invalid_response`. The Context usage popup renders a failure card keyed by this classification.

**Unofficial Endpoint** — `https://opencode.ai/zen/go/v1/usage` is not part of the official OpenCode API contract (ADR-023). It is consumed directly by the host-side probe purely as an OpenChamber-parity surface; it may change or disappear without notice and must not be treated as a supported OpenCode endpoint.

### ADR-023 Compatibility

This feature is compliant with ADR-023. Official OpenCode remains the primary source for all agent contracts and core app behavior. OpenChamber is used exclusively as an optional parity source for the quota/rate-limit feature. In the absence of OpenChamber REST endpoints, the app falls back to a hidden ephemeral shell probe without PTY process lifecycle changes, ensuring no divergence from official server capabilities.

**OpenCode Go (issue #96)**: Official OpenCode still lacks a unified quota API. The OpenCode Go probe consumes the unofficial `https://opencode.ai/zen/go/v1/usage` endpoint from the host side using the host's own `auth.json` key — no client credential storage, no cookie exception, and no change to any official agent contract, lifecycle, or API semantic. This remains an isolated OpenChamber-parity surface under ADR-023, not an endorsed official endpoint.

### Post-Mortem: Shell Transport Truncation & API Proxying

During the implementation of the shell fallback, a critical flaw was discovered in the OpenCode `POST /session/:id/shell` endpoint. When multiline scripts using bash heredocs (`node <<'NODE' ... NODE`) or conditional blocks (`if ... fi`) were sent, the shell evaluation engine prematurely truncated the payload. This resulted in `unexpected end of file` or `SyntaxError` failures.

**Evolution of the Solution:**
1. **Initial Approach:** A full Node.js script was sent as a heredoc script to read `auth.json` and make `fetch()` HTTP calls to provider APIs (Anthropic, OpenRouter). Result: The script was truncated mid-way through.
2. **First Attempted Fix (Minimal JS):** The JavaScript was aggressively minimized into a one-liner without any `fetch()` logic, simply parsing `auth.json` and returning `usage: null` to prove the transport worked. Result: The transport worked (returned 5 raw results), but `QuotaProviderResult.hasVisibleData` relies on the `usage` object to group and display the providers. Because all providers returned `usage: null`, the interface showed "0 visible groups" and rendered nothing.
3. **Final Solution (Base64 One-Liner):** To restore the critical API-fetching logic without triggering the shell truncation bug, the full multi-provider JavaScript implementation was retained but minified aggressively. The entire JS string is now encoded into Base64 within Dart at compile time. The executed shell command is a strict one-liner:
   `node -e "eval(Buffer.from('BASE64_PAYLOAD','base64').toString())"`
   Result: The payload executes reliably on the host, properly queries remote provider APIs, formats the `hasVisibleData` structure, and bypasses the shell's AST parsing constraints entirely.

---

## ADR-030: OpenChamber-Driven Realtime Hardening and Permission Continuity (2026-04-18)

**Status**: Accepted

**Related**: ADR-003 (Realtime-First Sync), ADR-023 (OpenCode Contract), EXC-001 (Permission Auto-Approve)

### Context

High-latency or unstable connections during OpenChamber-driven sessions revealed edge cases in permission handling and session synchronization. Specifically, pending question/permission refreshes could race with active streams, user mutations (sends/deletes) were possible during confirmed realtime reconnect failures (risking state divergence), and pinned-session pruning occurred before authoritative session lists were fully loaded.

### Decision

1. **Safe Refresh Consolidation**: Merge pending question and permission refreshes into a single atomic lifecycle step that respects the active turn lock.
2. **Mutation Guard during Reconnect Failures**: Block user-initiated state mutations (send message, delete session, rename) when the realtime transport is in a confirmed `reconnecting` or `failed` state and the fallback polling path has not yet established a verified authoritative bridge.
3. **Authoritative Pruning Delay**: Delay the pruning of pinned or cached session references until the `loadSessions()` authoritative response is fully processed.
4. **Bounded One-Shot Reconnect Helpers**: Bounded the set of one-shot reconnect helpers to prevent memory growth during extended disconnection periods.

### Rationale

- Atomic refreshes prevent UI flickering and race conditions between competing permission/question events.
- Blocking mutations during confirmed disconnects prevents "ghost" state where the client accepts a change that the server never receives, protecting ADR-023 contract integrity.
- Authoritative pruning prevents "flickering" sessions where a pinned item disappears and reappears because the local cache was cleaned before the server confirmation arrived.
- Bounded helper sets ensure long-term stability in degraded network conditions.

### Consequences

- ✅ Improved stability during OpenChamber-driven high-latency sessions.
- ✅ Stronger ADR-023 compliance by preventing un-syncable local mutations.
- ✅ Eliminates UI flickering of pinned sessions during revalidation.
- ⚠️ Users see explicit "Connection unstable - actions disabled" state during reconnect failures.
- ❌ Mutation-only offline mode is intentionally not supported to preserve contract parity.

### Key Files

- `lib/presentation/providers/chat_provider/chat_provider_realtime_ops.dart`
- `lib/presentation/providers/chat_provider/chat_provider_session_ops.dart`
- `lib/presentation/providers/chat_provider/chat_provider_message_merge_ops.dart`

### ADR-023 Compatibility

This hardening is fully compliant with ADR-023. It enforces server-authoritative state by blocking local mutations when transport integrity is lost and ensures the client waits for authoritative server lists before modifying local visibility of pinned items.

---

## ADR-031: Historical Inline Revert via OpenCode Session Revert Endpoint (2026-05-21)

**Status**: Accepted

**Related**: ADR-023 (Official OpenCode Contract-First Compatibility Policy), ADR-020 (Session-Level SWR Cache), ADR-028 (Unified Scroll Ownership)

### Context

Users need the ability to rewind a conversation to a specific historical user message — undoing all subsequent turns (assistant responses, tool calls, follow-ups) and restoring the session state as it existed at that point. Without this capability, the only way to "undo" a conversation branch is to create a new session and re-prompt, losing all prior context and work.

OpenCode provides `POST /session/:id/revert` with a `messageID` body field. CodeWalk already used that endpoint for latest-turn Undo. Historical inline rewind extends the same official endpoint to any older server-confirmed user message, keeping the server authoritative for the revert boundary while reusing the existing refresh/reconcile path.

Key challenges:
- **In-flight operation protection**: Repeated rewind taps must not dispatch overlapping revert requests.
- **Local optimistic message guard**: Messages with `local_user_*` IDs are client-only artifacts that the server does not know about. They must not be exposed as rewind targets or sent to the server.
- **Composer draft restoration**: After a revert, the composer should restore the text that was present at the reverted-to user turn, enabling the user to continue from that point.
- **ADR-023 compliance**: The revert uses the official session revert endpoint; local visibility updates are an immediate reflection of the server revert boundary, not a replacement protocol.

### Decision

1. **Server-authoritative revert via `revertToTurn(messageId)`**: `ChatProvider.revertToTurn(String messageId)` calls the existing `RevertChatMessage` use case, which sends `POST /session/:id/revert` with the selected server-confirmed user `messageID`. The provider then applies `SessionRevert(messageId: messageId)`, queues composer draft restoration, refreshes the active session view, and reloads session insights.

2. **Inline historical user-message rewind trigger**: Each historical, server-confirmed user message in the chat timeline exposes a dedicated inline rewind action. The latest revertible user message keeps the existing inline Undo action. Assistant messages, non-user messages, and optimistic local user messages do not expose historical rewind.

3. **`_historyRevertInFlight` guard**: A boolean flag `_historyRevertInFlight` serializes calls to `revertToTurn`. While one revert call is in flight, subsequent `revertToTurn` requests return `false` without dispatching another server request. This narrowly prevents repeated-tap duplicate reverts without changing unrelated send, realtime, or revalidation behavior.

4. **`local_user_*` message guard**: The timeline builder only wires `onInlineRevertToHere` when the message is a `UserMessage`, is not the latest revertible message, and does not start with `local_user_`. The provider also rejects `local_user_*` IDs at the `revertToTurn` entry point so future callers cannot bypass the UI guard.

5. **Composer draft restoration**: After a successful revert, the provider restores the selected user message into the pending history composer sync via `_buildComposerDraftFromUserMessage`. The composer can then show the reverted prompt so the user can edit and resend from that point.

6. **Widget ownership**: `ChatMessageWidget` exposes an optional `onInlineRevertToHere` callback, includes that callback in its build-skip cache invalidation, and renders a distinct `settings_backup_restore` action labeled `Rewind and edit from here` when the callback is present and the latest Undo action is not shown.

7. **Permission remember companion fix**: For permission replies using `always`, CodeWalk sends `remember: true` in both the documented session-scoped reply body and the existing top-level legacy fallback. This implements ADR-023 EXC-001's durable-grant intent without changing question flows or non-`always` permission semantics.

### Rationale

- **Server-authoritative revert** follows ADR-023 contract-first policy by reusing `POST /session/:id/revert` instead of inventing client-only history truncation.
- **`_historyRevertInFlight`** prevents duplicate requests from repeated taps while keeping the change narrow and low risk.
- **`local_user_*` guard** is necessary because optimistic IDs are client-only artifacts. Sending them to the server would violate ADR-023 Pitfall P-001's ownership boundary.
- **Composer draft restoration** is a natural UX expectation: after rewinding, the user wants to continue from that point, not start from an empty composer.
- **Distinct inline action** avoids conflating latest-turn Undo with historical branch/rewind semantics.

### Consequences

- ✅ Users can rewind conversations to historical server-confirmed user messages through the official session revert endpoint.
- ✅ ADR-023 compliance maintained: the server owns the revert boundary and the client refreshes from that authoritative state.
- ✅ `_historyRevertInFlight` guard prevents duplicate historical revert requests.
- ✅ `local_user_*` messages are excluded in both UI wiring and provider entry-point validation.
- ✅ Composer draft restoration enables seamless continuation after rewind.
- ⚠ The revert operation is network-dependent; offline or disconnected sessions cannot be rewound until connectivity is restored.
- ⚠ `_historyRevertInFlight` adds another state flag to the chat provider; it must remain tightly scoped to revert dispatch unless a future ADR expands history-action serialization.
- ❌ Local-only message truncation (client-side rewind without server) is intentionally not supported to preserve ADR-023 contract integrity.

### ADR-023 Compatibility

This feature is fully compliant with ADR-023. The revert uses the official OpenCode `POST /session/:id/revert` endpoint as the server-authoritative history operation. The client never introduces a separate local-only rewind protocol. The `local_user_*` ID guard (Pitfall P-001) is respected in both timeline wiring and provider validation. No new API endpoints or contract deviations are introduced.

### Key Files

- `lib/presentation/providers/chat_provider.dart` — `revertToTurn`, `_historyRevertInFlight`, `local_user_*` guard, composer draft restoration, and refresh/insights reload after revert
- `lib/domain/usecases/revert_chat_message.dart` — use case boundary for `POST /session/:id/revert`
- `lib/data/datasources/chat_remote_datasource.dart` — session revert API call and permission `remember: true` reply payloads
- `lib/presentation/pages/chat_page/chat_page_timeline_builder.dart` — historical server-confirmed user-message callback wiring
- `lib/presentation/widgets/chat_message_widget.dart` — optional `onInlineRevertToHere` callback and rebuild cache invalidation
- `lib/presentation/widgets/chat_message/chat_message_content.dart` — inline rewind action rendering

---

## ADR-032: LaTeX Math Rendering with flutter_math_fork and Custom Markdown Delimiters (2026-05-26)

**Status**: Accepted

**Related**: ADR-007 (Modular Settings Architecture), ADR-004 (Chat Architecture with Slim Orchestrators and Decomposed Clusters)

### Context

CodeWalk v1.83.0 introduced LaTeX math rendering so that mathematical expressions in chat messages render as properly typeset formulas instead of raw LaTeX source text. This is essential for users working with LLMs on math-heavy topics (physics, engineering, statistics, formal methods).

Key challenges:
- **Library selection**: Most Dart math rendering libraries are either unmaintained, platform-dependent (WebView-based), or have limited LaTeX coverage. A pure-Dart solution is preferred to avoid WebView overhead and ensure consistent behavior across desktop and mobile.
- **Markdown delimiter integration**: Chat messages are parsed as Markdown. Math delimiters (`$...$` for inline, `$$...$$` for display) must be recognized before or alongside standard Markdown parsing without conflicting with existing syntax (code spans, emphasis, etc.).
- **Graceful fallback**: When rendering fails (unsupported LaTeX command, malformed input), the user should see a styled fallback rather than a broken widget or crash.
- **User toggle**: Math rendering is a visual preference. Some users prefer raw LaTeX for copy-paste or screen-reader compatibility. A toggle must exist in experience settings.
- **Performance**: Math rendering is computationally heavier than plain text. It must not block the chat timeline scroll or cause jank on long sessions with many expressions.

### Decision

1. **`flutter_math_fork` as the rendering engine**: Use the `flutter_math_fork` package — a pure-Dart port of KaTeX — for all LaTeX math rendering. This avoids WebView dependencies, works identically on all Flutter platforms, and provides broad LaTeX coverage aligned with KaTeX's well-tested subset.

2. **Custom Markdown delimiters**: Extend the Markdown parser to recognize `$...$` (inline math) and `$$...$$` (display/block math) as custom syntax elements. These delimiters are extracted before standard Markdown processing to prevent conflicts with code spans (`` ` ``) and emphasis (`*`/`_`). Inline math renders within the text flow; display math renders as a centered block.

3. **`MathExpressionWidget` with styled fallback**: A dedicated `MathExpressionWidget` wraps the `flutter_math_fork` render call. On successful parse, it renders the typeset formula. On parse failure, it displays the raw LaTeX source in a monospaced, subtly styled container (e.g., with a light background tint) so the user can still read and copy the expression without UI breakage.

4. **`showMathRendering` toggle in `ExperienceSettings`**: Add a boolean `showMathRendering` field to `ExperienceSettings` (ADR-007). When disabled, math delimiters are not parsed and `$...$` / `$$...$$` content renders as plain text. This gives users control over rendering overhead and raw-LaTeX visibility. The toggle persists via the existing `SettingsProvider` infrastructure.

### Rationale

- **`flutter_math_fork` over WebView-based solutions**: Pure-Dart rendering avoids the memory and latency overhead of embedding a WebView per math expression. It also works offline and on all Flutter targets (Android, iOS, macOS, Linux, Windows) without requiring an embedded browser engine.
- **Pre-extraction of delimiters**: Parsing math delimiters before standard Markdown prevents ambiguity (e.g., `$a_b$` must not trigger emphasis parsing on the underscore). This is the same strategy used by GitHub and MathJax integrations.
- **Styled fallback over silent failure**: Showing raw LaTeX in a styled container is better than a blank space, a red error box, or a crash. It preserves the information while signaling that rendering was not possible.
- **Toggle as experience setting**: Math rendering is a display preference (like font size or theme), not a data-layer concern. `ExperienceSettings` (ADR-007) is the natural home for this toggle.

### Consequences

- ✅ Users see properly typeset LaTeX math in chat messages, improving readability for math-heavy conversations.
- ✅ Pure-Dart rendering works on all Flutter platforms without WebView or network dependencies.
- ✅ Styled fallback ensures malformed LaTeX degrades gracefully instead of breaking the UI.
- ✅ `showMathRendering` toggle gives users control over rendering behavior and raw-LaTeX visibility.
- ⚠ `flutter_math_fork` is a community-maintained fork; if it becomes unmaintained, a migration path to another KaTeX/MathJax port or a WebView fallback may be needed.
- ⚠ Complex LaTeX expressions (e.g., TikZ, chemfig) outside KaTeX's subset will fall back to raw source. Users expecting full LaTeX coverage will see limitations.
- ⚠ Math rendering adds CPU cost per expression; on very long sessions with hundreds of formulas, scroll performance may need monitoring and possible lazy-render optimization.
- ❌ Does not support LaTeX rendering in code blocks or file previews — only in chat message Markdown content.

### Key Files

- `lib/presentation/widgets/math_expression_widget.dart` — `MathExpressionWidget` with `flutter_math_fork` rendering and styled fallback
- `lib/presentation/widgets/chat_message/` — integration of math delimiter parsing into chat message Markdown pipeline
- `lib/domain/settings/experience_settings.dart` — `showMathRendering` toggle field
- `lib/presentation/providers/settings_provider.dart` — toggle persistence and access via `SettingsProvider`

---

## ADR-033: Cloudflare Managed OAuth as Optional Desktop Reverse-Proxy Auth (ADR-023 Exception) (2026-05-27)

**Status**: Accepted

**Related**: ADR-023 (Official OpenCode Contract-First Compatibility Policy), ADR-001 (Multi-Server Orchestration and Secure Credential Storage), ADR-007 (Modular Settings Architecture)

### Context

Some CodeWalk desktop users deploy OpenCode behind a Cloudflare Access reverse proxy that requires Cloudflare Managed OAuth identity verification before any traffic reaches the OpenCode server. This is a deployment-specific authentication layer that is invisible to the OpenCode server itself — the server only sees the standard `Authorization: Basic <creds>` header after the reverse proxy has already validated the user's identity.

Currently, CodeWalk only supports official OpenCode Basic Auth (username/password via `Authorization: Basic` header). Users behind Cloudflare Access receive HTTP 401/403 responses from the proxy before reaching the server, with no mechanism in the app to complete the OAuth dance. This blocks them from using CodeWalk entirely unless they pre-authenticate in a browser and somehow transfer session tokens — a fragile, unsupported workflow.

Official OpenCode does not define a reverse-proxy authentication mechanism. The server is unaware of any upstream proxy auth; it only expects Basic Auth. Adding Cloudflare Managed OAuth support is therefore a client-side concern that does not modify any server API contract, but it does introduce a secondary auth layer that is not part of the official OpenCode specification — triggering ADR-023 review.

### Decision

1. **Optional Cloudflare Managed OAuth flow**: Add an opt-in Cloudflare Managed OAuth authentication capability for desktop and Android platforms. Before DCR or browser launch, both platforms bind a real ephemeral `HttpServer` on `127.0.0.1`; the effective bound port defines one exact `http://127.0.0.1:<port>/oauth/callback` redirect URI that is reused unchanged for DCR, authorization, callback validation, and token exchange. Desktop opens the system browser with `LaunchMode.externalApplication`. Android asks `MainActivity` to open a browser-owned native AndroidX Custom Tab and falls back only to an `ACTION_VIEW` external browser; it never uses `OAuthWebViewPage` or another embedded WebView. The browser performs the real loopback network request to the app-owned server on both platforms. When enabled per server profile, CodeWalk performs the Cloudflare Managed OAuth authorization code flow with PKCE S256. The resulting access token is sent as `Authorization: Bearer <access_token>` on requests whose origin matches the OAuth-enabled profile only. When a `registration_endpoint` is available, Dynamic Client Registration (DCR) is performed to obtain client credentials automatically.

2. **Profile-scoped configuration**: Each `ServerProfile` (ADR-001) gains an `oauthEnabled` (bool, default `false`) field. This single toggle controls whether the profile uses Cloudflare Managed OAuth or standard Basic Auth — the two modes are mutually exclusive within a profile. This preserves OpenCode Basic Auth for non-OAuth profiles without interference.

3. **Conditional export architecture**: The `OAuthService` is implemented via Dart conditional exports: `oauth_service_io.dart` provides the IO implementation used by desktop and Android (browser launch, real local redirect server, token exchange), and `oauth_service_stub.dart` provides the unsupported implementation for non-IO targets. The conditional export pattern selects the implementation at compile time; separate capability gating prevents unsupported platforms such as iOS from exposing the flow.

4. **Platform gating**: The Cloudflare Managed OAuth flow is gated behind `AppProvider.supportsCloudflareAccessOAuth`. On desktop (macOS/Windows/Linux) and Android, the flow is enabled and uses the same app-owned loopback `HttpServer`; desktop launches an external application and Android launches a native Custom Tab with external-browser fallback. iOS remains unsupported and the UI must not expose OAuth configuration there. Rationale: reverse-proxy deployments target desktop/server and Android environments; iOS Safari app-bound domain restrictions prevent the loopback redirect pattern.

5. **Secure credential storage and diagnostic redaction**: Access and refresh tokens are stored through `OAuthTokenStorage` backed by `flutter_secure_storage`, with keys scoped by `profileId + serverUrl`. No OAuth credentials are written to SharedPreferences, log output, or debug surfaces. Callback queries, authorization codes, PKCE verifiers, provider error descriptions, OAuth endpoint URLs, raw token/DCR bodies, access or refresh tokens, client secrets, and raw exception text must not appear in logs or user-facing errors. `OAuthCredential` encapsulates the token pair and expiry.

6. **Bearer token propagation**: Requests to the OAuth-enabled profile's origin include `Authorization: Bearer <access_token>` via the Dio interceptor. The interceptor matches the request origin against the OAuth profile's server URL — only matching requests receive the Bearer header. On profile switch or when `oauthEnabled` is false, the interceptor is removed. Cross-origin requests never include the OAuth token.

7. **OAuth callback flow**: The callback accepts only an exact `GET` request using HTTP, host `127.0.0.1`, the effective port of the bound server, raw path `/oauth/callback`, exactly one non-empty matching `state`, and exactly one non-empty authorization `code` xor one non-empty provider `error`. Unrelated raw paths are non-terminal and receive 404. The first valid or invalid callback on the expected path completes the flow exactly once; later callbacks receive 409. An accepted code is exchanged with the same redirect URI and PKCE verifier. On failure, the user sees a redacted error and can retry or disable `oauthEnabled` for that profile.

8. **Health checks and OAuth challenge detection**: Health check requests load cached OAuth tokens and record OAuth challenges (e.g., 401/403 from the proxy) to trigger re-authentication when needed.

9. **Mutual exclusivity of auth modes**: OAuth and Basic Auth are mutually exclusive profile modes in this PR. An OAuth-enabled profile uses Bearer token auth exclusively; a non-OAuth profile uses standard Basic Auth. This prevents auth-header conflicts and keeps each profile's auth boundary clean.

### ADR-023 Exception Declaration

This ADR constitutes an explicit ADR-023 exception per section 3 ("Explicit Divergence") of ADR-023.

**Deviation from official behavior**: Official OpenCode defines only Basic Auth for server authentication. Cloudflare Managed OAuth introduces a secondary, pre-Basic-Auth authentication layer that is not part of the official OpenCode API contract. The client sends a Bearer token for matching-origin requests that is consumed by an upstream reverse proxy, transparent to the OpenCode server.

**Why this is acceptable**:
- The OpenCode server contract is unchanged — CodeWalk still sends the standard `Authorization: Basic` header on non-OAuth profiles and follows all server API semantics.
- The OAuth Bearer token is consumed by an upstream reverse proxy, transparent to the OpenCode server.
- No new server endpoints, no modified request/response schemas, no altered lifecycle semantics.
- The feature is opt-in and profile-scoped; servers without Cloudflare Managed OAuth are completely unaffected.
- OAuth and Basic Auth are mutually exclusive per profile — no auth-header conflicts.

### Rationale

- **Reverse-proxy auth is a deployment reality**: Enterprise and self-hosted users commonly place services behind Cloudflare Access. CodeWalk must support this to be usable in those environments.
- **Cloudflare Managed OAuth (authorization code + PKCE S256)**: This is the standard Cloudflare Access OAuth mechanism — not cookie-based auth. Authorization code flow with PKCE S256 provides the strongest security guarantees for native/desktop applications (no client secret in the app, code verifier prevents interception).
- **DCR when available**: Dynamic Client Registration automates client credential provisioning when the Cloudflare IdP exposes a `registration_endpoint`, removing manual client ID entry.
- **Conditional export pattern**: Using Dart's conditional export (`oauth_service_io.dart` / `oauth_service_stub.dart`) provides compile-time platform resolution — cleaner than runtime platform checks scattered across call sites.
- **Platform scoping via `AppProvider`**: `AppProvider.supportsCloudflareAccessOAuth` centralizes platform capability detection, consistent with the app's provider architecture. Desktop platforms (macOS/Windows/Linux) and Android are supported; iOS remains gated out.
- **Profile-scoped mutual exclusivity**: Tying the feature to `oauthEnabled` on the server profile (ADR-001) and making OAuth/Basic Auth mutually exclusive prevents accidental activation and keeps the auth boundary clean per-server.
- **Secure storage alignment**: `OAuthTokenStorage` following ADR-001's `flutter_secure_storage` pattern with `profileId + serverUrl` scoped keys prevents the same class of credential-exposure issues that ADR-001 solved for Basic Auth.

### Consequences

- ✅ Desktop and Android share one loopback transport design: bind first, derive one redirect URI from the effective port, and reuse it through DCR, authorization, validation, and token exchange.
- ✅ Android authorization is browser-owned through a native AndroidX Custom Tab or `ACTION_VIEW` external-browser fallback; the OAuth path has no embedded WebView.
- ✅ No impact on servers without Cloudflare Managed OAuth — feature is fully opt-in and profile-scoped.
- ✅ OpenCode server contract is fully preserved on non-OAuth profiles — Basic Auth is always sent.
- ✅ Secure storage via `OAuthTokenStorage` prevents OAuth credential leakage via plaintext persistence.
- ✅ Platform gating via `AppProvider.supportsCloudflareAccessOAuth` exposes the real loopback flow on desktop and Android while keeping iOS unsupported.
- ✅ Mutual exclusivity of OAuth/Basic Auth per profile prevents auth-header conflicts.
- ✅ PKCE S256 protects against authorization code interception attacks.
- ⚠ Adds a second auth layer to the connection flow for OAuth-enabled profiles, increasing time-to-first-message (browser redirect + code exchange).
- ⚠ Requires maintaining a real local HTTP redirect server for `/oauth/callback` on desktop and Android; bind failures and device/browser policies that block loopback redirects must surface as retryable, redacted errors.
- ⚠ Automated CI and contributor real-device Android validation remain required; this ADR records the implemented design and does not claim successful Android runtime validation.
- ⚠ OAuth access token expiration requires re-authentication; health checks detect proxy challenges and re-trigger the flow gracefully.
- ❌ iOS does not support Cloudflare Managed OAuth (Safari app-bound domain restrictions prevent loopback redirect); users on iOS must use VPN or switch platforms.
- ❌ Cloudflare Managed OAuth configuration is specific to Cloudflare — other reverse-proxy solutions (Authelia, Tailscale, etc.) are not covered by this ADR and would require separate exceptions if needed.

### Risk Analysis

- **Medium auth-layer risk**: If the OAuth access token expires mid-session, requests will fail with 401/403 from the proxy. Mitigation: health checks load cached OAuth tokens and record OAuth challenges; the app detects proxy 401/403 responses (distinct from OpenCode 401), re-triggers the OAuth flow with a user-visible prompt, and replays the failed request after re-auth.
- **Low contract risk**: The OpenCode server API is unmodified. The Dio interceptor adds a Bearer token for matching-origin requests only, consumed upstream. Non-OAuth profiles are completely unaffected. If a future OpenCode version adds its own Bearer-based auth, the OAuth interceptor is scoped to the profile origin and will not conflict.
- **Low data-risk**: OAuth tokens are stored in `flutter_secure_storage` with keys scoped by `profileId + serverUrl`. Clearing a server profile removes all associated OAuth credentials.
- **Medium Android integration risk**: Custom Tab provider selection, `ACTION_VIEW` fallback, browser-to-app loopback routing, and Android network policy vary by device and browser. Mitigation: retain CI coverage for the Android build and callback contract, and require contributor validation on a real Android device before claiming runtime success; never fall back to an embedded WebView.
- **Low loopback bind risk**: The callback server binds to `127.0.0.1` on an ephemeral port before DCR or browser launch, so ordinary port collisions are avoided. Bind failures or loopback-blocking device/browser policies produce retryable, redacted errors.
- **Low callback-confusion risk**: An unrelated path must not terminate the flow, while malformed requests on the expected raw path are terminal. Exact method/scheme/host/effective-port/path checks, one matching state, code/error xor validation, and a single-use completion guard limit callback spoofing and races; post-completion requests receive 409.
- **Low diagnostic-disclosure risk**: OAuth failures can carry credentials and provider details. Mitigation: logs and errors retain only coarse step/status information and omit callback queries, codes, verifiers, provider descriptions, endpoint URLs, raw token/DCR bodies, tokens, client secrets, and raw exceptions. The credential-bearing `tool/qa/oauth_loopback_probe.dart` is not retained.

### Rollback / Feature-Flag Plan

- **Immediate user rollback**: Disable `oauthEnabled` in the server profile settings. The app immediately falls back to Basic Auth only for that profile. Clear stored OAuth credentials for the profile.
- **Product rollback**: Remove `oauthEnabled` from `ServerProfile`, the Dio Bearer interceptor, and the OAuth flow code. `OAuthTokenStorage` keys are cleaned up on next profile load when `oauthEnabled` is absent.
- **Feature flag**: `oauthEnabled` per-profile IS the feature flag. There is no global toggle — each server profile controls its own OAuth state independently.

### Regression Tests

- **Basic Auth non-regression**: Existing Basic Auth connection tests under `test/unit/network` must pass unchanged when `oauthEnabled` is `false` (default).
- **Profile isolation**: Enabling OAuth on profile A must not affect profile B's connection or credential state.
- **Interceptor scoping**: The Bearer token interceptor must only attach `Authorization: Bearer` to requests matching the OAuth profile's origin; cross-origin requests must not include the OAuth token.
- **Secure storage boundary**: OAuth credentials must not appear in SharedPreferences, log output, or debug surfaces. Keys must be scoped by `profileId + serverUrl`.
- **Platform gating**: `AppProvider.supportsCloudflareAccessOAuth` must return false for iOS and the UI must not expose OAuth configuration there. Android must return true and use the IO implementation with a real `127.0.0.1` callback server and browser-owned authorization, never an embedded WebView.
- **Redirect URI continuity**: Tests must verify that the server is bound before DCR and browser launch and that the exact redirect URI derived from its effective port is reused for DCR, authorization, callback validation, and token exchange.
- **Callback validation matrix**: Tests must require exact `GET`, HTTP, `127.0.0.1`, effective port, raw `/oauth/callback`, exactly one non-empty matching `state`, and exactly one non-empty `code` xor provider `error`. Encoded or unrelated paths must be non-terminal 404s; malformed expected-path callbacks must terminate; completion must be single-use and later callbacks must receive 409.
- **Diagnostic confidentiality**: Tests must ensure logs and errors omit callback queries, codes, PKCE verifiers, provider descriptions, endpoint URLs, raw token/DCR bodies, tokens, client secrets, and raw exceptions. Credential-bearing QA probes must not be added to the repository.
- **Android browser ownership**: Android build/tests must cover the `MainActivity` method-channel launch contract, native AndroidX Custom Tab selection, and `ACTION_VIEW`-only fallback with no WebView path. CI and contributor real-device Android validation are both required; passing unit tests alone is not runtime proof.
- **Health check OAuth awareness**: Health checks must load cached OAuth tokens and record OAuth challenges for re-auth triggering.
- **Profile deletion cleanup**: Deleting a server profile must remove all associated OAuth credentials from `OAuthTokenStorage`.
- **Mutual exclusivity**: An OAuth-enabled profile must not send Basic Auth headers, and a non-OAuth profile must not send Bearer OAuth tokens.

### Key Files

- `lib/core/auth/oauth_service.dart` — `OAuthService` public API with conditional export
- `lib/core/auth/oauth_service_io.dart` — shared desktop + Android IO implementation: binds the ephemeral `127.0.0.1` `HttpServer` before DCR/browser launch, reuses the exact redirect URI throughout the PKCE flow, launches desktop with `externalApplication`, invokes Android browser launch through the platform channel, validates callbacks, enforces single-use completion, redacts diagnostics, and exchanges the code
- `lib/core/auth/oauth_service_stub.dart` — unsupported implementation for non-IO targets
- `lib/core/auth/oauth_service_result.dart` — `OAuthServiceResult` type for flow outcomes
- `lib/core/auth/oauth_token_storage.dart` — `OAuthTokenStorage` backed by `flutter_secure_storage`, keys scoped by `profileId + serverUrl`
- `lib/core/auth/oauth_credential.dart` — `OAuthCredential` encapsulating access/refresh tokens and expiry
- `lib/core/network/dio_client.dart` — Bearer token interceptor management for matching OAuth profile origin, proxy-401/403 detection
- `lib/presentation/providers/app_provider.dart` — `supportsCloudflareAccessOAuth` desktop + Android gating with iOS excluded
- `android/app/src/main/kotlin/com/verseles/codewalk/MainActivity.kt` — native Android OAuth launcher using AndroidX Custom Tabs with `ACTION_VIEW` external-browser fallback only
- `android/app/build.gradle.kts` — AndroidX Browser dependency for native Custom Tabs
- Onboarding and settings pages — `oauthEnabled` toggle and configuration UI
- `test/unit/auth/oauth_service_io_test.dart` — exact callback-origin/path/query validation, single-use completion guard, redacted token-exchange errors, trusted Cloudflare host checks, HTTPS-only OAuth endpoint trust, and metadata-origin trust for the exact configured HTTPS origin or a trusted Cloudflare Access HTTPS origin
- `test/unit/auth/oauth_token_storage_test.dart` — secure OAuth credential storage and scoping
- Tests under `test/unit/network` — Bearer interceptor scoping, health check OAuth challenge detection, Basic Auth non-regression

---

## ADR-034: Density-Aware Spacing Tokens via `AppDensitySpacing` Static Helper (2026-05-30)

**Status**: Accepted

**Related**: ADR-014 (Centralized MD3 Design Tokens for Shapes and Brand Colors), ADR-007 (Modular Settings Architecture)

### Context

Spacing values (horizontal/vertical padding, gaps, content insets) for chrome and composer surfaces were hardcoded as magic `EdgeInsets`/`SizedBox` constants scattered across `chat_page_chrome.dart` and `chat_input_widget.dart`. These values did not respond to the user's `AppDensity` preference (`extraDense`/`dense`/`normal`/`spacious`/`extraSpacious`), meaning compact users saw the same spacing as default users and spacious users got no extra breathing room.

ADR-014 centralized **shape** tokens (`AppShapes`) and **brand color** tokens (`BrandColor`) as static constants, but these are density-agnostic — `AppShapes.extraSmall` is always `BorderRadius.circular(4)` regardless of user preference. Spacing is a fundamentally different token category because it must vary per density tier, making static constants insufficient.

### Decision

1. **`AppDensitySpacing` static helper class**: Introduce a private-constructor static class in `app_theme.dart` (alongside `AppTheme`) that provides density-parameterized spacing methods. Every method accepts `AppDensity density` and returns a `double` or `EdgeInsets` via Dart 3 switch expressions over the 5-tier `AppDensity` enum.

2. **Token categories**:
   - **Horizontal padding**: `horizontalPadding(density)` — composer rows, chrome edges
   - **Vertical padding**: `chipRowVerticalPadding(density)`, `inputRowVerticalPadding(density)` — composer chip/input rows
   - **Gaps**: `itemGap(density)`, `smallGap(density)`, `mediumGap(density)` — element spacing
   - **Content padding**: `textFieldContentPadding(density)`, `listTileContentPadding(density)` — inner widget insets
   - **Chrome-specific**: `appBarTitleSpacing(density)`, `syncChipRightPadding(density)`, `searchResultLabelPadding(density)`, `sectionHeaderPadding(density)`, `headerChipPadding(density)`, `overlayCardPadding(density)`
   - **Composer-specific**: `blockReasonInnerPadding(density)`
   - **Convenience builders**: `composerChipRowPadding(density)`, `composerPopoverRowPadding(density)`, `composerInputRowPadding(density)` — composed from primitive tokens

3. **Replace hardcoded constants**: All `EdgeInsets.fromLTRB(...)` and `SizedBox(width: ...)` magic numbers in chrome and composer surfaces must reference `AppDensitySpacing.*` methods instead.

4. **No `AppShapes`/`BrandColor` extension**: `AppDensitySpacing` is a separate class, not an extension of `AppShapes` or `BrandColor`, because shape and color tokens are density-agnostic constants while spacing tokens are density-parameterized functions.

### Rationale

- **Density-aware spacing is a user preference**: The `AppDensity` enum in `ExperienceSettings` (ADR-007) expresses the user's visual density preference. Spacing tokens must respond to it — static constants cannot.
- **Eliminates magic numbers**: ~25 hardcoded `EdgeInsets`/`SizedBox` literals across chrome and composer surfaces are replaced with named, density-aware references, making the spacing contract explicit and auditable.
- **Atomic scale adjustments**: Changing a spacing tier value (e.g., normal horizontal padding from 12 to 14) propagates automatically to all surfaces using that token.
- **Separate from ADR-014 shapes/colors**: Shapes (border radii) and brand colors are fixed design constants. Spacing is a density-responsive design variable. Combining them would create a class with conflicting semantics (some static, some parameterized).
- **Static helper over instance**: A private-constructor static class follows the same pattern as `AppShapes` and keeps the API simple — call sites pass `appDensity` from their build context or provider, with no DI or instantiation overhead.

### Consequences

- ✅ All chrome and composer spacing responds to the user's `AppDensity` preference — compact layouts are tighter, spacious layouts breathe more.
- ✅ Magic `EdgeInsets`/`SizedBox` constants eliminated from chrome and composer surfaces.
- ✅ Named spacing tokens make the design contract explicit and auditable.
- ✅ Atomic scale adjustments propagate to all consumers automatically.
- ✅ Follows the same centralized-token philosophy as ADR-014 for a new token category.
- ⚠ Every new density-sensitive surface must use `AppDensitySpacing` methods instead of inline constants; enforcement is by convention, not compiler-checked.
- ⚠ Adding new spacing tokens requires updating `AppDensitySpacing` with all 5 tiers and verifying downstream usage.
- ❌ Static helper cannot be hot-replaced by theme extensions or DI; density must always be passed as a parameter.

### Key Files

- `lib/presentation/theme/app_theme.dart` — `AppDensitySpacing` class definition
- `lib/presentation/pages/chat_page/chat_page_chrome.dart` — chrome surface spacing consumers
- `lib/presentation/widgets/chat_input_widget.dart` — composer surface spacing consumers
- `lib/domain/entities/experience_settings.dart` — `AppDensity` enum definition

---

## ADR-035: Message-Derived Selection Fallback with Explicit-Override Precedence (2026-05-30)

**Status**: Accepted

Related: historical Feature 7 workstream; `ROADMAP.md` is intentionally removed and current implemented behavior is tracked in `BEHAVIOR.md`.

### Context

When a user reopens an existing session, CodeWalk must restore the agent, model, and variant that were last active in that session. The existing `_sessionSelectionOverridesByKey` map only stores overrides created by explicit user actions — sessions without an explicit override fall back to global defaults, which may not reflect what was actually used. OpenChamber solves this with `restoreSessionStateFromMessages()` which reads `providerID`, `modelID`, and `agent` from the last assistant message metadata. Without a similar mechanism, reopening a session shows incorrect provider/model/agent until the server sends the first assistant message, creating a confusing UX mismatch.

### Decision

Implement a three-tier selection restoration hierarchy with explicit-override precedence:

1. **Explicit override** (highest priority): user-initiated selection changes stored in `_sessionSelectionOverridesByKey` with `isExplicit: true`. Never overridden by the fallback.
2. **Message-derived fallback** (middle priority): `_restoreSelectionFromMessages()` scans the LRU session message cache backwards for the last `AssistantMessage` with valid `providerId`/`modelId`/`mode`/`variant` metadata. Activated when:
   - No override exists for the session.
   - The existing override is stale (provider/model no longer in catalog, agent unresolvable).
   - The existing override was set non-explicitly (e.g. from config sync or session-switch continuity).
3. **Global defaults** (lowest priority): when both override and message scan fail, the current global selection remains unchanged.

Key design decisions:
- **LRU cache-first scanning**: `_restoreSelectionFromMessages` reads from `_cachedSessionMessages(sessionId)` (the SWR LRU cache, ADR-020), not from `_messages` directly, because during `selectSession()` the `_messages` list may still hold the previous session's data while `_currentSession` has already switched.
- **Neutral-message filtering**: `_isSelectionNeutralAssistantMessage` excludes summary and compaction assistant messages from the scan, since these are internal bookkeeping artifacts that do not represent real user-facing model/agent selections.
- **Override promotion**: when the message fallback successfully restores a selection, it persists the result as an explicit override (`_storeCurrentSessionSelectionOverride(isExplicit: true)`), so subsequent opens are cache-first without needing to rescan messages.
- **Non-explicit override demotion**: when `_applySessionSelectionOverride` encounters an `isExplicit: false` override (from config sync or continuity), it runs the message fallback which may supersede the non-explicit value.

### Rationale

- Without message-derived fallback, session reopen always shows global defaults instead of the last-used provider/model — a UX regression vs OpenChamber parity.
- The `isExplicit` flag prevents the fallback from undoing deliberate user choices while still recovering accurate state for non-explicit overrides.
- LRU cache-first scanning avoids a race condition where `_messages` still holds the previous session's data during the `selectSession()` transition.
- Override promotion makes the fallback a one-time cost: after the first successful scan, subsequent opens read the persisted override directly.
- Neutral-message filtering prevents summary/compaction artifacts from polluting the selection — these messages carry the model metadata of the compaction agent, not the user's chosen model.

### Consequences

- ✅ Reopened sessions show the correct agent/model/provider without waiting for the first server assistant message.
- ✅ OpenChamber parity for `restoreSessionStateFromMessages()`.
- ✅ Explicit user selections are never overridden by the fallback mechanism.
- ✅ Override promotion makes the message scan a one-time cost per session.
- ⚠ The LRU cache may be empty on first visit (cold start) — the fallback silently returns `false` and global defaults apply until the first assistant message arrives.
- ✅ Variant is now parsed from the server assistant message `variant` metadata field, enabling accurate model-variant restoration alongside provider/model/mode.
- ❌ The fallback scans backwards through all cached messages — for very long sessions with no metadata-bearing messages, this is O(n) with no early exit beyond the first match.

### Key Files

- `lib/presentation/providers/chat_provider/chat_provider_context_state_ops.dart` — `_applySessionSelectionOverride` with explicit-override precedence and fallback dispatch
- `lib/presentation/providers/chat_provider/chat_provider_selection_helpers.dart` — `_restoreSelectionFromMessages` (LRU cache-first backward scan), `_storeCurrentSessionSelectionOverride` (override promotion), `_isSelectionNeutralAssistantMessage`
- `lib/presentation/providers/chat_provider/chat_provider_message_state_ops.dart` — `_adoptSelectionFromAssistantMessage` (realtime adoption from streaming messages), `_isSelectionNeutralAssistantMessage` definition

## ADR-036: Userspace Tailscale Transport with Profile-Scoped Activation (2026-05-31)

**Status**: Accepted

### Context

Users operating behind restrictive firewalls or in zero-trust networks often cannot reach their OpenCode server directly. Tailscale provides secure overlay networking, but the standard approach requires a system-level Tailscale daemon (`tailscaled`) with root privileges — unsuitable for desktop GUI apps and impossible on Android without root. The app needs a built-in, per-profile transport option that works without system-level installation, integrates cleanly with the existing Dio HTTP stack (including SSE streaming and request cancellation), and does not interfere with regular HTTP connections for non-Tailscale profiles.

### Decision

Embed a `package:tailscale` userspace Tailscale node directly in the app process:

1. **One node per process**: a singleton `TailscaleNode` is initialized on first use and shared across the app lifecycle. Only one active Tailscale identity runs at a time.
2. **Profile-scoped activation**: `ServerProfile.tailscaleEnabled` (boolean, per-profile) controls whether the Tailscale transport is active for that profile. Only the currently active profile's Tailscale setting takes effect — switching profiles reconfigures the transport.
3. **Custom Dio `HttpClientAdapter`**: a dedicated adapter routes HTTP requests through the userspace Tailscale node when the feature is enabled. The adapter preserves SSE streaming (chunked transfer) and respects Dio `CancelToken` for request cancellation — critical for the chat SSE stream (ADR-018).
4. **Inactive Tailscale health returns unknown**: when `tailscaleEnabled` is `false`, the Tailscale health check does not report "unhealthy" — it returns an "unknown" status so the health dashboard does not show a false-negative for profiles that intentionally skip Tailscale.
5. **Unsupported platforms**: Web and Windows are excluded (no userspace networking support). On these platforms, `tailscaleEnabled` is ignored and standard HTTP is used unconditionally.
6. **Interactive auth UX**: `AppProvider` exposes reactive Tailscale auth state so the UI can respond to login and machine-authorization requirements without surprising the user:
   - `tailscaleNeedsLogin` — the node has no identity; user must authenticate.
   - `tailscaleNeedsMachineAuth` — the node is registered but the tailnet admin has not yet approved it.
   - `tailscaleAuthUrl` — the URL to present to the user for login/approval.
   - `tailscaleMessage` — human-readable status text from the Tailscale node.
   - `authenticateTailscale()` is the single entry point for manual auth: if the node is not running, it starts the transport first (`_applyTailscaleTransport`) then launches the auth URL; if already running, it launches the auth URL directly.
   - `_applyTailscaleTransport` no longer auto-launches auth URLs — the previous auto-launch caused double browser tabs when both the transport setup and the auth listener fired. Auth URL launch is now exclusively in `authenticateTailscale()` or the auth panel.
   - The onboarding wizard (`onboarding_wizard_page.dart`) and server settings (`servers_settings_section.dart`) include Tailscale auth panels that show per-state UI (needs-login prompt, machine-auth wait, connected confirmation).

### Rationale

- Userspace networking avoids the need for root/system-level `tailscaled` — essential for Android and sandboxed desktop environments.
- One node per process keeps memory and auth-state footprint minimal; multiple simultaneous Tailscale identities would require complex routing and credential isolation for no proven use case.
- Profile-scoped activation mirrors the existing pattern (ADR-001, ADR-033) and prevents cross-server credential leakage.
- A custom `HttpClientAdapter` integrates at Dio's transport layer without touching higher-level SSE/streaming logic — minimal blast radius.
- Returning "unknown" health for inactive Tailscale avoids misleading the user into thinking Tailscale is broken when it is simply not enabled for that profile.

### Consequences

- ✅ Secure overlay connectivity without system-level Tailscale installation.
- ✅ Per-profile opt-in matches existing credential-isolation patterns (ADR-001, ADR-033).
- ✅ SSE streaming and cancellation semantics preserved through the custom adapter.
- ✅ No false health alerts for profiles that do not use Tailscale.
- ✅ Vendored `package:tailscale` under `third_party/tailscale` isolates the dependency from pub ecosystem churn and gives full control over native-asset build hooks.
- ✅ Windows release builds succeed — `hook/build.dart` no-ops on Windows (where the Tailscale stub is used) so native-assets hooks cannot break the Windows toolchain.
- ⚠ Only one Tailscale identity is active at a time — switching profiles requires re-authentication if the new profile targets a different tailnet.
- ⚠ Vendored package requires manual updates when upstream `package:tailscale` changes.
- ❌ No Web or Windows support — userspace networking is unavailable on these platforms; Windows uses the stub only.
- ❌ Cannot coexist with a system-level `tailscaled` on the same machine (port/auth conflicts) — the user must choose one or the other.
- ⚠️ Re-authentication requires explicit user action via the auth panel (onboarding or settings); the app no longer auto-redirects to the browser, so a disconnected Tailscale node will stay disconnected until the user initiates auth.

### Key Files

- `lib/data/services/tailscale_service.dart` — `TailscaleNode` singleton, lifecycle, and health check
- `lib/data/models/server_profile.dart` — `tailscaleEnabled` field on `ServerProfile`
- `lib/data/network/tailscale_http_adapter.dart` — custom `HttpClientAdapter` with SSE streaming and cancellation support
- `lib/data/services/server_health_service.dart` — Tailscale health integration (unknown status when inactive)
- `third_party/tailscale/` — vendored `package:tailscale` with patched `hook/build.dart` (no-op on Windows)
- `lib/presentation/pages/onboarding/onboarding_wizard_page.dart` — Tailscale auth panel in onboarding flow
- `lib/presentation/pages/settings/servers_settings_section.dart` — Tailscale auth panel in server settings

---

## ADR-037: Chat Viewport and Scroll/Follow Synchronization Revamp (2026-06-05)

**Status**: Accepted

### Context

The chat viewport experienced race conditions where the screen bounced or jumped during streaming updates and SWR/REST status refreshes. The synchronization state was fragmented across ~12 boolean/enum flags, side-effects were executed inside the timeline builder, and transient REST status refreshes temporarily reported `busy` after `session.idle` completed, resetting settled states and re-triggering auto-scroll adjustments.

### Decision

Consolidate the viewport state and scroll follow behavior to stabilize synchronization:

1. **_ScrollFollowMode Enum**: Define `following`, `pausedByUser`, and `reading` modes in a single enum to coordinate scroll tracking.
2. **Turn-Scoped Reveal Guard**: Add `_lastRevealedAssistantMessageId` to `_ChatPageState` to lock the final assistant message of a turn from being re-revealed on subsequent status updates.
3. **Time-Windowed REST Status Guard**: Replace the one-shot `_sseSettledToIdleSessionIds` set with a time-windowed `_sseSettledAtBySessionId` map to suppress transient REST status busy pulses for 4 seconds after SSE completion.
4. **Move Sync Concerns out of Build**: Extract the synchronization calls (`_syncSessionScrollState`, `_syncResponseViewportPolicy`, etc.) from the timeline build phase and call them sequentially inside `_handleChatProviderChanged` listener.
5. **Robust Metric Snaps and Restores**: Simplify `_handleScrollMetricsChanged` to snap only during active responding updates, and add retry loops to `_consumeQueuedCachedViewportRestore` when scroll clients or layout are not yet ready.
6. **No Entrance Motion on Timeline Entries**: Remove entrance animation from main timeline entries to prevent layout-phase animation side-effects from conflicting with scroll synchronization. Passive auto-follow uses non-animated `jumpTo` with bounded retry instead of animated scrolls, ensuring immediate viewport positioning without animation-induced metric drift.

### Rationale

- Consolidating states into `_ScrollFollowMode` replaces fragmented boolean flags with a single state machine, preventing conflicting viewport states.
- Monotonic Turn-Scoped Reveal Guard blocks redundant scroll jumps once a turn has settled.
- Time-Windowed status merging provides defense-in-depth against transient SWR updates.
- Moving sync logic out of build phase prevents layout-phase rebuild races.
- Removing entrance animation from timeline entries eliminates a class of scroll metric drift where animation-driven size changes conflict with scroll snap/restore logic during streaming and passive auto-follow.

### Consequences

- ✅ Viewport and scroll synchronization remains stable during active stream updates and SWR refreshes.
- ✅ No layout shifts or scroll bounces occur on background resume or session switches.
- ✅ Pagination, search navigation, and file explorer viewport ownership are fully preserved.
- ✅ Main timeline entries render without entrance animation, eliminating animation-triggered scroll metric drift.
- ⚠ Deferring `setState` to post-frame callback is required when scroll changes trigger state updates during layout.

**Note** (commits `6bda4ac`, `89aef8e`): Reader-owned viewport state is now preserved when active incoming response updates arrive below the visible reading position:
1. **Passive auto-follow respects reading-mode viewport** — streaming response content that grows below the user's visible reading position no longer yanks the viewport downward; auto-follow only engages when the user is already at or near the bottom.
2. **Reader-owned scroll position is stable across active-turn content growth** — the viewport anchor is maintained while the user is reading earlier content, even as new tokens or tool-call bubbles append below.

### Key Files

- `lib/presentation/pages/chat_page.dart`
- `lib/presentation/pages/chat_page/chat_page_runtime_support.dart`
- `lib/presentation/pages/chat_page/chat_page_scroll_coordinator.dart`
- `lib/presentation/pages/chat_page/chat_page_timeline_builder.dart`
- `lib/presentation/pages/chat_page/chat_page_lifecycle.dart`
- `lib/presentation/providers/chat_provider.dart`
- Ref: e8ff8a78

---

## ADR-038: Disable On-Device STT Engines on Windows Desktop (2026-06-07)

**Status**: Superseded by ADR-044 for Windows runtime behavior; retained as historical mitigation context.

**Related**: ADR-006 (Speech Input Architecture with `SpeechInputService` and Platform Policy)

### Context

The Windows desktop build of CodeWalk is unusable for speech-to-text. Issue #43 reports that **all** STT engines close the application automatically when the user activates voice input:

> "Whenever I try to use the speech-to-text function on Windows, the application closes automatically. This happens whether I use the native option or other models like Whisper or ParaKeet."

The user-visible behavior is a hard crash with no error dialog, so the cause must be a native-side segfault that bypasses Dart's exception handling. Two distinct crash surfaces are in play:

1. **`record: ^6.0.0` → `record_windows: 1.0.7` (MediaFoundation).** All on-device engines (Sherpa, Moonshine, Parakeet, SenseVoice) use the `AudioRecorder` API for microphone capture. The upstream issue `llfbandit/record#453` documents an `EXCEPTION_ACCESS_VIOLATION_READ / 0x0` in `mtx_do_lock` (MediaFoundation mutex init) that takes down the host process. `record_windows 1.0.7` ships the most recent fix ("Crashes (on Flutter 3.35.1 only ?)"), but the issue is not fully closed across all Windows + Flutter + driver combinations.
2. **`speech_to_text: 7.3.0` (Native) on Windows.** The Windows implementation is documented as **beta** and uses the UWP Speech Recognition APIs. Failures during `speech.initialize()` or `speech.listen()` (privacy settings disabled, missing language pack, online speech recognition off) can segfault the process through the same COM/MediaFoundation surface.

Because the crash is in native code, **Dart `try/catch` cannot catch it** — the only safe mitigation is to prevent the buggy code path from being invoked on Windows.

### Decision

Disable the on-device STT engines (Sherpa, Moonshine, Parakeet, SenseVoice) on Windows desktop. The Native engine (UWP speech recognition) remains available; the chat input and settings UI must surface that the on-device engines are intentionally disabled on Windows and explain why.

1. **Centralized platform support table** — introduce `lib/presentation/utils/speech_engine_platform_support.dart` as the single source of truth for which engine works on which platform. Chat input (`_ChatInputWidgetState`) and the speech settings section (`_SpeechSettingsSectionState`) both delegate to this class instead of duplicating the platform check, so they cannot drift.
2. **Exclusions on Windows** — every engine that depends on `record` is reported as unsupported on Windows (`isMoonshineSupported`, `isParakeetSupported`, `isSenseVoiceSupported` → `false`; `isSherpaSupported` → `false` for the same reason, even though `sherpa_onnx` does ship a Windows build). Linux and macOS keep the full on-device engine set. Web still uses the Native path only.
3. **Auto-migrate existing Windows selections** — `SettingsProvider.initialize()` checks the persisted `speechToTextEngine`. If a Windows user has Sherpa/Moonshine/Parakeet/SenseVoice stored from a previous install, the value is migrated to `Native` and the change is persisted. This prevents a returning user from landing on a disabled engine after the next app launch.
4. **Updated UI copy** — `Settings > Speech` on Windows shows the existing `speechNativeSTTWorks` info card (now accurate, no false promise about a Sherpa fallback), a new `speechOnDeviceWindowsDisabled` warning card explaining the limitation and pointing the user to the Native engine, and the on-device engine radio tiles appear disabled with platform-specific hint text.
5. **i18n** — a new `speechOnDeviceWindowsDisabled` key is added to `englishTemplate` in `tool/i18n/arb_strings.dart`. All 13 non-English locale blocks have their stale `speechNativeSTTWorks` translation removed so they fall back to the new accurate English copy; translators can fill in proper localizations in a follow-up.

### Rationale

- The user impact (app closes) is more severe than the feature loss (no on-device STT on Windows). Native UWP speech recognition is a serviceable fallback and is the only STT path that does not depend on `record`.
- Centralizing the platform support table prevents future drift between the chat input and the settings UI when other engines or platforms are added.
- Auto-migrating existing Windows selections avoids a class of "I opened the app and it just doesn't speak anymore" support tickets, because the change is transparent — the user wakes up on Native instead of being silently switched during a settings change.
- The UI copy is the load-bearing piece for user trust: the on-device engines are not "broken on my machine", they are intentionally disabled because the underlying microphone plugin is the problem. The error card plus the disabled radio tiles make that explicit.
- Keeping `record: ^6.0.0` pinned in `pubspec.yaml` (rather than upgrading to `record 7.0.0` or `record_windows 2.0.0`) is intentional — both require Flutter 3.44/Dart 3.12 which is above the current `sdk: ^3.8.1` constraint, and the risk of a major-version audio regression on macOS/Linux outweighs the theoretical Windows benefit. The platform exclusion is the targeted mitigation.

### Consequences

- ✅ Windows users no longer experience a hard crash when activating voice input. The app stays responsive and surfaces a clear explanation in the settings.
- ✅ The chat input and settings UI cannot disagree about which engines work on which platform — both delegate to `SpeechEnginePlatformSupport`.
- ✅ Existing Windows users with on-device selections are silently migrated to Native on next launch, so the change is non-disruptive.
- ✅ Linux and macOS keep the full on-device engine set (Moonshine/Parakeet/SenseVoice/Sherpa) with no behavioral change.
- ⚠ On Windows, the only STT path is Native (UWP). If the OS speech privacy settings or online speech recognition are misconfigured, the user sees the existing `_buildUnavailableReason` hint and no transcription, but the app still does not crash.
- ⚠ Users who explicitly want on-device STT on Windows must wait for either `record_windows` to ship a stable fix or for an alternative microphone capture strategy (e.g., direct MediaFoundation bindings). The exclusion can be reverted by changing the `SpeechEnginePlatformSupport` flags and the Windows branch in `SettingsProvider`.
- ❌ On Windows, the on-device engine selection UI remains visible (so the user understands what is being disabled) but is non-interactive. The radio tiles, model management cards, and per-engine sub-cards all hide via the existing `_supports*` gates.
- ❌ The 13 non-English `speechNativeSTTWorks` translations are removed and fall back to English until translators update them. This is the expected behavior of the safe i18n workflow.

### Key Files

- `lib/presentation/utils/speech_engine_platform_support.dart` — new centralized platform support table
- `lib/presentation/widgets/chat_input_widget.dart` — chat input engine support delegates to the table
- `lib/presentation/pages/settings/sections/speech_settings_section.dart` — settings section delegates to the table + Windows info card
- `lib/presentation/providers/settings_provider.dart` — Windows STT selection auto-migration
- `lib/presentation/services/speech_input_service_stt.dart` — existing Windows-specific `_buildUnavailableReason` hint retained for Native init failures
- `lib/l10n/app_en.arb` + 13 locale ARBs — `speechOnDeviceWindowsDisabled` added; `speechNativeSTTWorks` updated; non-English translations removed for safe fallback
- `tool/i18n/arb_strings.dart` — source of truth updated, then `generate_arb.dart` + `flutter gen-l10n` regenerated
- `test/unit/presentation/speech_engine_platform_support_test.dart` — per-platform regression coverage (issue #43)
- `test/unit/providers/settings_provider_test.dart` — Windows migration regression coverage
- `BEHAVIOR.md` — new "Windows on-device STT is intentionally disabled" section + updated platform table
- `CODEBASE.md` — new "Speech-to-Text Platform Support" cluster section
- Ref: issue #43

---

## ADR-039: Real Windows STT Fix — Actionable Settings Links and Typed Microphone Preflight (2026-06-08)

**Status**: Accepted for actionable settings links and typed preflight; Windows engine policy superseded by ADR-044.

**Related**: ADR-006 (Speech Input Architecture), ADR-023 (Official OpenCode contract-first compatibility), ADR-038 (historical Windows mitigation — disable on-device engines).

### Context

ADR-038 mitigated the Windows STT hard crash by disabling the on-device engines (Sherpa, Moonshine, Parakeet, SenseVoice) and force-migrating saved Windows selections to Native. The user still cannot use third-party STT, and the Native error message is generic. Issue #43 explicitly requests (a) a real fix for third-party STT, (b) actionable links to open the relevant Windows settings, and (c) a runtime permission prompt if Windows supports it.

Research established three facts that shape the partial fix:

1. `record: ^6.0.0` → `record_windows: 1.0.7` (MediaFoundation) hard-crashes the host process with `EXCEPTION_ACCESS_VIOLATION_READ` (llfbandit/record#453). Dart `try/catch` cannot catch a native segfault, so re-enabling the current `record` code path is not safe.
2. `permission_handler_windows` does not implement a real microphone permission check or prompt for unpackaged Win32 apps; it returns a hardcoded `GRANTED`.
3. Windows does not show a runtime microphone permission prompt for unpackaged Win32 apps. The realistic flow is: probe capture, report the typed status (`allowed` / `denied` / `noInputDevice` / `deviceBusy` / `unknown`), and offer a one-tap link to the exact Settings page via `url_launcher`.

A full re-enable of the on-device engines on Windows requires a validated WASAPI capture backend (a new native C++ plugin that uses `IAudioClient` shared mode, never touches MediaFoundation, and is built and smoke-tested on a Windows host). Shipping that without a Windows CI gate risks reintroducing the very crash the user reported. The partial fix in this ADR ships the parts that are independently useful and well-tested on non-Windows: the actionable settings links, the typed microphone preflight, the `SpeechAudioCapture` lifecycle cleanup, and the architecture for adding the WASAPI backend later.

### Decision

Build on top of ADR-038 (still the runtime contract) and add the parts of the fix that are independently useful on Windows, while keeping the on-device engines disabled until a validated WASAPI capture backend lands.

1. **Actionable Windows settings helpers** — `WindowsSettingsLinks` wraps `url_launcher` with three official Microsoft Settings URIs: `ms-settings:privacy-microphone`, `ms-settings:privacy-speech`, and `ms-settings:speech`. The helpers no-op on non-Windows targets.
2. **Typed Windows microphone preflight** — `WindowsMicrophoneService.probe()` exposes `WindowsMicrophoneAccessStatus` (`allowed` / `denied` / `noInputDevice` / `deviceBusy` / `unknown` / `notSupported`) over a `codewalk/windows_microphone` MethodChannel. The probe fails soft: any `PlatformException` maps to `unknown`, any `MissingPluginException` maps to `notSupported`. The EventChannel surface (`codewalk/windows_microphone_stream`) raises `MicrophoneBackendUnavailableException` when the native side is missing so the engine can fall back to Native.
3. **Actionable Native STT preflight** — `SttSpeechInputService._buildUnavailableReason` probes the Windows microphone access status first and returns a specific reason with a stable reason key (`microphoneDenied` / `noInputDevice` / `deviceBusy` / `speechPrivacy`) that the UI can map to the correct settings link.
4. **Actionable composer snackbar** — the chat input failure path on Windows shows a snackbar with an action button whose target URI is picked from the typed `unavailableReasonKey` (`speechPrivacy` / `noInputDevice` → speech settings, `deviceBusy` / `microphoneDenied` / `generic` → microphone privacy). Non-Windows targets keep the existing copy.
5. **`SpeechAudioCapture` lifecycle cleanup** — the on-device engines no longer create their own `AudioRecorder` instances; the wrapper owns the recorder lifecycle end-to-end so the previously-leaked `AudioRecorder` is no longer reachable. This change is platform-neutral and fixes a latent leak that affected Linux/macOS too.
6. **Settings UI** — the Windows setup card in `Settings > Speech` is now actionable: three buttons (microphone, speech privacy, speech language) that launch the corresponding `ms-settings:` URI. On non-Windows the card is hidden.
7. **i18n** — new keys `speechOpenMicrophoneSettings`, `speechOpenSpeechPrivacy`, `speechOpenSpeechSettings`, `speechWindowsSetupHint` are added in English; non-English locales fall back to English (expected behavior of the safe i18n workflow).
8. **Regression coverage** — new unit tests cover `WindowsSettingsLinks` URIs and `WindowsMicrophoneService.probe()` (typed status parsing + `PlatformException` + `MissingPluginException` mapping). Existing tests assert that Windows still force-migrates on-device selections to Native so the user never lands on a crashing engine.
9. **On-device engine re-enable on Windows is deferred** — the WASAPI capture backend (a new C++ plugin using `IAudioClient` shared mode, no MediaFoundation) is the follow-up deliverable. Until it is built and validated on a Windows host, the on-device engines remain disabled on Windows and the actionable settings card is the user-facing remediation.

### Rationale

- The user's primary ask in issue #43 is the actionable settings links; this ADR ships them with full test coverage and no platform risk.
- The Native STT preflight is independently useful: even without re-enabling the on-device engines, the user gets a specific reason + one-tap remediation for every Windows failure mode.
- The `SpeechAudioCapture` lifecycle cleanup is a latent leak fix that is worth shipping on its own and unblocks the future WASAPI backend.
- Shipping a Windows C++ plugin without a Windows CI gate risks reintroducing the original crash. The follow-up is well-defined and can land once `release.yml`'s `windows-latest` job is wired into the regular CI feedback loop.

### Consequences

- ✅ The user can open the exact Windows settings page from `Settings > Speech` and from the chat input failure snackbar.
- ✅ The Native engine reports a specific reason (microphone privacy / no input device / device busy / speech privacy) on Windows; the user gets a one-tap action that opens the relevant Settings page.
- ✅ The on-device engines no longer leak the legacy `AudioRecorder` instance on Linux/macOS.
- ✅ Existing Windows users with on-device selections are still force-migrated to Native so they never land on a crashing engine.
- ⚠ The on-device engines (Sherpa, Moonshine, Parakeet, SenseVoice) are still disabled on Windows. A validated WASAPI capture backend is required to re-enable them; this is tracked as a follow-up to ADR-039.
- ⚠ The `ms-settings:` URIs are only resolvable on Windows 10/11. On other platforms the helpers return `false` so the UI can hide the action button.
- ❌ The non-English `speechNativeSTTWorks` translation remains removed and the new `speechOpen*` / `speechWindowsSetupHint` keys fall back to English until translators update them. This is the expected behavior of the safe i18n workflow.
- ❌ This ADR does not address `record 7.0.0` / `record_windows 2.0.0` upgrades (still blocked by the SDK constraint), MSIX packaging (out of scope), or the WASAPI capture backend (follow-up).

### Key Files

- `lib/presentation/utils/windows_settings_links.dart` — `url_launcher` wrappers for the three Microsoft Settings URIs
- `lib/presentation/services/windows_microphone_service.dart` — typed probe + EventChannel bridge + `MicrophoneBackendUnavailableException`
- `lib/presentation/services/speech_audio_capture.dart` — engine-side abstraction with end-to-end `AudioRecorder` lifecycle (Windows is currently a no-op stub for the on-device engines)
- `lib/presentation/services/speech_input_service_stt.dart` — Native STT preflight with `unavailableReasonKey`
- `lib/presentation/services/speech_input_service_{sherpa,moonshine,parakeet,sensevoice}_io.dart` — on-device engines now consume `SpeechAudioCapture` and no longer create their own `AudioRecorder`
- `lib/presentation/pages/settings/sections/speech_settings_section.dart` — actionable Windows setup card
- `lib/presentation/widgets/chat_input/chat_input_speech_controller.dart` — actionable snackbar on Windows; action target derived from `unavailableReasonKey`
- `lib/l10n/app_en.arb` + 13 locale ARBs — `speechOpen*` / `speechWindowsSetupHint` keys; `speechNativeSTTWorks` updated
- `tool/i18n/arb_strings.dart` — source of truth updated, then `generate_arb.dart` + `flutter gen-l10n` regenerated
- `test/unit/presentation/windows_settings_links_test.dart` — new helper unit tests
- `test/unit/services/windows_microphone_service_test.dart` — new probe unit tests (happy path + `PlatformException` + `MissingPluginException`)
- `BEHAVIOR.md` — Windows STT table updated; "Windows on-device STT is intentionally disabled (with actionable Windows settings links)" section
- Ref: issue #43, llfbandit/record#453, https://learn.microsoft.com/en-us/windows/apps/develop/launch/launch-settings, https://learn.microsoft.com/en-us/windows/win32/coreaudio/wasapi

---

## ADR-040: Client-Owned Per-Project Icon Discovery (2026-06-19, updated 2026-06-28, 2026-07-03)

**Status**: Accepted

**Related**: ADR-002 (Context Isolation), ADR-022 (Unified Project Context Controls), ADR-023 (Official OpenCode contract-first compatibility), issue #68, issue #73 (implemented).

### Context

The conversations sidebar and project selector currently use the same folder icon for every project. Users can only distinguish projects by text, which is slow when several project paths share similar names. OpenChamber provides a useful community reference: it discovers a project favicon on demand, stores icon bytes under app-owned storage, records icon metadata separately from the project path, and falls back to preset/folder icons when no favicon is found.

Official OpenCode docs expose project list and project lookup endpoints, but they do not define a project icon field or an icon-discovery endpoint. Under ADR-023, CodeWalk must not invent OpenCode project payload fields or rely on server-side favicon endpoints as if they were official OpenCode behavior. The icon feature is therefore a client-owned personalization layer.

### Decision

Implement project icons as local CodeWalk metadata, not as OpenCode project state:

1. **Discovery is render-triggered for open/active project icons only**: the icon is discovered when an open/active project is rendered via `ProjectIcon(autoDiscover: true)` (backed by `ProjectIconProvider.autoDiscoverIcon`), not via background scanning, file-watch events, or project-add polling. There is no user-initiated trigger — the previous explicit `ProjectIconDiscoveryButton` affordance was removed. Closed project history rows render display-only using the last cached icon and do not trigger discovery until they are reopened, so cold-render work stays bounded to rendered widgets and there is no filesystem watch.
2. **Discovery scope is universal local app-icon discovery with a web favicon fallback**: known app-icon locations are checked first — Tauri `src-tauri/icons/*`, Electron direct `build/icon.*`, Flutter / React Native / native Apple `AppIcon.appiconset/*.png`, Flutter Windows `windows/runner/resources/app_icon.ico`, Flutter Linux `linux/runner/resources/app_icon.png`, Android `mipmap-*/ic_launcher*.png`, and common `icon.*` / `app_icon.*` / `logo.*` assets — then fall back to `favicon.{ico,png,svg,jpg,jpeg,webp}` and other sized web icons. Discovery reads the local project filesystem only; no network favicon services. `build/icon.*` is probed directly so the generated `build` directory stays excluded from traversal. `.icns` and XML-style app icons are intentionally not rendered; supported formats remain PNG/JPEG/SVG/WebP/ICO with ICO normalized to PNG. Ranking is app-icon priority first, then quality/density, then shortest relative path so root-folder favicons win over deeply nested files.
3. **No network favicon services**: discovery reads the local project filesystem only. It does not call external services, parse remotes, or fetch GitHub/raw assets.
4. **Client-owned storage**: icon bytes and metadata live under CodeWalk app support storage, keyed by a stable project identity hash. OpenCode project responses remain unchanged.
5. **Supported formats and cap**: PNG, JPEG, SVG, WebP, and ICO are accepted with a 5 MB maximum. Empty, oversized, unreadable, or unsupported files (including `.icns` and XML-style app icons) fall back to the default icon. ICO is normalized to PNG at decode time.
6. **Flutter-native rendering**: CodeWalk should use a shared `ProjectIcon` widget backed by `ImageProvider`/local file bytes rather than adding an embedded HTTP route or custom URL scheme.
7. **Fallback first**: if no icon is configured or loading fails, render `Symbols.folder_open`. Preset icons, custom uploads, SVG recoloring, and `apple-touch-icon`/manifest parsing remain follow-ups.
8. **Search exclusions**: the walker must skip heavy/generated directories such as `.git`, `node_modules`, `dist`, `build`, `.dart_tool`, `.gradle`, `.next`, `.turbo`, `.cache`, `coverage`, `tmp`, `logs`, `ios/Pods`, and platform build output folders. The direct probe of `build/icon.*` is the only exception to the `build` exclusion.

### Rationale

- Keeping icon metadata local preserves the official OpenCode project contract and avoids an ADR-023 exception.
- On-demand scanning avoids surprising mobile users and avoids background filesystem work on remote or cloud-mounted directories.
- App-icon-first discovery (Tauri / Electron / Flutter / RN / native Apple / Android / common `icon.*` / `app_icon.*` / `logo.*`) makes the feature useful across desktop, mobile, and cross-platform projects where no web favicon exists, while the favicon fallback preserves validated OpenChamber behavior for web projects.
- A Flutter-native image path is simpler than an app-local HTTP route and works across desktop/mobile without an extra serving layer.
- Skipping `.icns` and XML-style app icons keeps the renderer surface bounded to the already-supported PNG/JPEG/SVG/WebP/ICO set, avoiding a custom decoder and keeping ICO normalization simple.
- Deferring uploads and presets keeps the feature testable and easy to roll back.

### Consequences

- ✅ Project identity in the sidebar can become more scannable without server support.
- ✅ The feature remains additive and local; OpenCode project APIs stay authoritative for project path/name/lifecycle only.
- ✅ Backward compatibility is straightforward because existing `Project` JSON does not need new server-originated fields.
- ✅ App-icon-first discovery makes icons useful for desktop, mobile, and cross-platform projects where no web favicon exists, while the favicon fallback still covers web projects.
- ⚠ Icon storage must be pruned when projects are forgotten/closed permanently or when metadata no longer points at a valid project identity.
- ⚠ Local filesystem traversal must stay off the UI isolate and must enforce depth/entry/byte limits to avoid jank.
- ⚠ Adding a new app-icon location requires updating the discovery priority list so app-icon matches keep winning over web favicons; ad-hoc per-file probes outside that list are discouraged.
- ⚠ Discovery is now render-triggered for open/active project icons via `ProjectIcon(autoDiscover: true)` and `ProjectIconProvider.autoDiscoverIcon`, using the existing local/remote discovery service. Closed project history rows remain display-only (using the last cached icon) until reopened, so cold-render is bounded to rendered widgets and not a background scan or file-watch event.
- ❌ Custom upload, icon presets, SVG recoloring, manifest parsing, and external favicon services remain intentionally out of scope; the patch changes the trigger model (user-initiated button → render-time for open/active projects) but not the local-only scope, app-support storage layer, OpenCode payload immunity, or supported-format set.

**Note** (issue #73): The ADR-023-compliant client-owned implementation is in place. Discovery is render-triggered for open/active project icons (`ProjectIcon(autoDiscover: true)` / `ProjectIconProvider.autoDiscoverIcon`) and stays display-only for closed history rows until reopened. Icon bytes and metadata live under app support storage, OpenCode project payloads remain unchanged, and no network favicon services were introduced. The dedicated `ProjectIconDiscoveryButton` was removed in favor of the render-time trigger.

**Note** (2026-06-28, historical): Project icon discovery was expanded from web/favicon-only to universal local app-icon discovery while preserving the ADR-023 contract. Discovery priority now checks known app-icon locations before web favicons: Tauri `src-tauri/icons/*`, Electron direct `build/icon.*`, Flutter / React Native / native Apple `AppIcon.appiconset/*.png`, Flutter Windows `windows/runner/resources/app_icon.ico`, Flutter Linux `linux/runner/resources/app_icon.png`, Android `mipmap-*/ic_launcher*.png`, common `icon.*` / `app_icon.*` / `logo.*` assets, then `favicon.*` and sized web icons. `build/icon.*` is probed directly without traversing the generated `build` directory. `.icns` and XML-style app icons are intentionally not rendered; supported formats remain PNG/JPEG/SVG/WebP/ICO with ICO normalized to PNG. Ranking is app-icon priority first, then quality/density, then shortest relative path. As of this update, local-only filesystem scope, app-support storage, OpenCode payload immunity, and the no-network-services / no-custom-uploads invariants were preserved; the user-initiated trigger model that applied at the time was later superseded by the 2026-07-03 render-triggered change below.

**Note** (2026-07-03): The trigger model changed from the explicit `ProjectIconDiscoveryButton` user-initiated affordance to render-triggered auto-discovery for open/active project icons. Discovery now runs only when an open/active project is rendered via `ProjectIcon(autoDiscover: true)` (backed by `ProjectIconProvider.autoDiscoverIcon`), not via background scanning, file-watch events, or project-add polling. Closed history rows render display-only with the last cached icon until reopened, so cold-render work is bounded to rendered widgets and not a global filesystem scan. The change preserves the local-only filesystem scope, app-support storage layer, OpenCode payload immunity (no new fields injected into OpenCode project responses), and the no-external-favicon-services invariant established by ADR-040; supported formats, app-icon + favicon priority, ranking, search exclusions, and ADR-023 compliance are unchanged. The dedicated `ProjectIconDiscoveryButton` user-initiated entry point was removed in favor of the render-time trigger.

### Key Files

- **Project icon models / store / discovery service** — local CodeWalk-owned models, icon byte + metadata persistence under app support storage, and bounded app-icon + favicon filesystem discovery (no OpenCode payload coupling, no network services).
- **`ProjectIconProvider`** — state owner orchestrating discovery and storage for the chat sidebar and selector surfaces.
- **`ProjectIcon`** — shared renderer with `Symbols.folder_open` fallback and `autoDiscover: true` for open/active projects. Discovery is render-triggered via `ProjectIconProvider.autoDiscoverIcon`; the previous `ProjectIconDiscoveryButton` user-initiated affordance was removed. Closed history rows render display-only with the last cached icon until reopened.
- **Chat sidebar / selector integration** — sidebar group entries and project selector surfaces consume `ProjectIconProvider` to render per-project icons.
- **Tests**: `test/unit/services/project_icon_*_test.dart`, `test/widget/project_icon_test.dart`.
- **CODEBASE.md** — maps the local project icon subsystem.
- Ref: issue #68, issue #73, OpenChamber `project-icon-routes.js`, OpenChamber `fs/search.js`, OpenChamber `projectMeta.ts`.

---

## ADR-041: Chat Stability Invariants for Delta Reconciliation and Final Reveal (2026-06-24)

**Status**: Accepted

**Related**: ADR-023 (Official OpenCode Contract-First Compatibility Policy), ADR-028 (Unified Scroll Ownership Model for Chat Timeline), ADR-037 (Chat Viewport and Scroll/Follow Synchronization Revamp), ADR-002 (Context Isolation), ADR-020 (Session-Level SWR Cache). Ref: issue #76.

### Context

Issue #76 surfaced residual jitter in the chat timeline under high-frequency delta events and viewport-bound reveal. Specifically: (a) assistant-message fallback reconciliation could regress against newer server snapshots because the merge had no monotonic tiebreaker; (b) stale fallback completions and metadata-only updates were sometimes allowed to overwrite authoritative completed state; (c) per-event rebuild notifications produced unnecessary layout churn under streaming load; (d) server-authoritative completed snapshots could be discarded when they arrived out-of-order with respect to local part updates; (e) the final-reveal scroll/FAB policy was sensitive to active incomplete assistant states and could either over-hide or over-reveal; (f) older-message prepend occasionally caused scroll extent flicker; (g) compaction decision equality used reference identity where value equality was required.

### Decision

Adopt the following client-side invariants for chat stability. All rules operate on existing OpenCode event shapes; no server contract changes are introduced.

1. **Monotonic local delta version for assistant fallback reconciliation.** Every assistant message with locally-applied `message.part.delta` updates gets a strictly increasing in-memory `deltaVersion` integer. Debounced fallback fetches capture the version at scheduling time; if another local delta advances the same message before the fallback returns, the fallback is stale and may not replace text/tool parts. The counter is bounded in memory per message id and is not a persisted protocol field.

2. **Stale fallback completion / metadata-only merge.** A stale fallback may still merge completion and metadata from a completed assistant snapshot, but it must preserve the currently-visible text/tool parts. The monotonic completion guard from ADR-023 Pitfall P-002 is preserved and extended: late incomplete events from draining fallback streams may never demote an already-completed message, and metadata-only merges may only add fields (never replace text or tool parts).

3. **16ms delta notification batching.** The chat provider applies each `message.part.delta` to in-memory state immediately, but coalesces listener notification with a 16ms timer. `session.idle` flushes any pending delta notification before terminal turn handling so the final state is visible before the composer leaves active-send state.

4. **Server-authoritative completed snapshots may reorder parts non-regressively.** When a non-stale server-authoritative completed snapshot arrives, the provider adopts the server's part order while preserving locally-visible non-regressive content: completed text is not shortened, completed/error tool calls are not reopened by late running snapshots, and already-represented text/reasoning parts are not appended as duplicates.

5. **Scroll/FAB final reveal policy.** Final-reveal scroll uses a 220ms animation and caps scroll-to-bottom passes at 3. The FAB (`Go to latest`) is hidden only when the **completed and settled** latest assistant message is visibly being read in the viewport. An **active incomplete** assistant message does not count as "read" and does not suppress the FAB while the user is not pinned to its tail. The viewport measurement is read fresh from render boxes; stale cached measurements are not used to hide the FAB.

6. **Older-message prepend microtask / double extent restore.** When older messages are prepended (top-scroll pagination or historical load), the chat page schedules the scroll-anchor restore in a microtask after the prepend is committed, then re-checks `maxScrollExtent` once the next frame lays out. If the second measurement differs from the first (e.g. late image decode), the restore offset is adjusted by the delta and the anchor message remains stable in the viewport. The restore runs at most twice per prepend to bound work; subsequent measurements are ignored until the next prepend.

7. **Compaction decision value equality.** Assistant-work compaction decisions are compared by value rather than by object identity. The `==`/`hashCode` overrides cover `shouldDeferLatestCollapse`, `latestRevealableAssistantMessageId`, and `settledLatestAssistantWorkGroupId`, preventing duplicate cache invalidation when independent rebuilds compute the same logical decision.

8. **Server-owned IDs and optimistic `local_user_*` contract preserved.** The invariants above never modify the server's ownership of message ids (`msg_*`) and never promote or rewrite an optimistic `local_user_*` id. Fallback reconciliation against the server uses the server id only; local optimistic ids remain client-only and continue to be excluded from any server-targeted payload (per ADR-023 Pitfall P-001).

### Rationale

- A monotonic local delta version is the simplest correct tiebreaker that survives concurrent streams, fallbacks, and reorderings without inventing a new protocol.
- The completion/metadata-only guard is a direct continuation of the ADR-023 Pitfall P-002 guard, extended to fallback paths where late completes were the regression source.
- 16ms is one frame at 60Hz and is the smallest batching window that meaningfully amortizes notify churn without becoming user-perceptible; bounded in-flight batches prevent starvation.
- Sticky terminal part state is necessary because users perceive "the tool result reverted" as a correctness bug even when the server is authoritative for a newer snapshot; preserving terminal state non-regressively is the lowest-risk compatibility policy.
- The 220ms / 3-pass final reveal keeps the animation responsive while preventing runaway reveal loops that have been a recurring source of viewport jitter (ADR-028, ADR-037). Separating completed/settled from active incomplete in the FAB policy removes the false-positive suppression that pinned the FAB unnecessarily during streaming.
- Double extent restore handles the recurring cause of scroll-anchor drift under older-message prepend: the first measurement happens before async image decode and the second corrects the offset without re-running pagination restore.
- Value equality for compaction decisions is the standard Dart fix for accidental identity-based comparisons and removes a class of duplicate-scheduling bugs that are otherwise hard to reproduce.
- Every rule is expressible inside the existing OpenCode event contract; no new endpoints, fields, or lifecycle semantics are introduced.

### Consequences

- ✅ Assistant message reconciliation is monotonic across fallback, streaming, and authoritative snapshot paths.
- ✅ Completed/settled assistant messages no longer flicker when stale fallback completions or metadata-only merges arrive late.
- ✅ Delta notifications produce ≤1 listener notify per message id per 16ms window, reducing streaming-frame churn.
- ✅ Server-authoritative completed snapshots may reorder parts while preserving the user's terminal text/tool state.
- ✅ Final reveal animates within 220ms, capped at 3 scroll passes, with no runaway reveal loops.
- ✅ FAB hides only when the latest completed/settled assistant message is fully visible; an active incomplete assistant does not falsely suppress the FAB.
- ✅ Older-message prepend keeps the anchor message stable through microtask + double extent restore.
- ✅ Compaction scheduler collapses duplicate value-equal decisions into a single decision.
- ⚠ The 16ms batch window is a tuned constant; platforms with very different frame cadences (120Hz, low-power mode) may need the batch window revisited.
- ⚠ Non-regressive part reorder is conservative: if a server snapshot is genuinely a downgrade of a tool result (e.g. retraction), the local sticky terminal state wins and the user must refresh to reconcile. This is the intentional safety choice.
- ⚠ Double extent restore is bounded at 2 measurements; pathological decode pipelines that settle later than one frame may still cause minor anchor drift.
- ❌ Late fallback completions that contradict a newer authoritative snapshot are intentionally rejected; refresh is the reconciliation path.

### ADR-023 Compatibility

This ADR is fully compliant with ADR-023. No OpenCode server contract is changed: the rules operate entirely on existing event shapes, message ids, and lifecycle semantics. Server-owned message ids (`msg_*`) remain authoritative; the optimistic `local_user_*` contract (ADR-023 Pitfall P-001) is preserved unchanged. No new endpoints, no new fields, no divergence from official OpenCode lifecycle semantics. All invariants are client-side reconstruction from existing event structure and are additive to the current merge / scroll / compaction layer.

### Key Files

- `lib/presentation/providers/chat_provider/chat_provider_message_merge_ops.dart` — monotonic delta-version tiebreaker, completion guard, non-regressive part reorder
- `lib/presentation/providers/chat_provider/chat_provider_event_reducer_session_ops.dart` — 16ms delta batching window, in-flight batch bound
- `lib/presentation/providers/chat_provider/chat_provider_message_state_ops.dart` — sticky terminal part state, local delta-version counters
- `lib/presentation/providers/chat_provider/chat_provider_compaction_ops.dart` — value-equality compaction decision `==`/`hashCode`
- `lib/presentation/pages/chat_page/chat_page_runtime_support.dart` — 220ms final reveal, 3-pass cap, viewport-measured FAB hiding
- `lib/presentation/pages/chat_page/chat_page_scroll_coordinator.dart` — older-message prepend microtask + double extent restore
- `lib/presentation/pages/chat_page/chat_page_fab_presenter.dart` — completed/settled visibility check; active incomplete is not "read"
- `test/unit/providers/chat_provider_realtime_test.dart` — regression coverage for monotonic merge and completion guard
- `test/widget/chat_page_test.dart` — regression coverage for final reveal, FAB visibility, and older-message prepend
- Ref: issue #76

---

## ADR-042: Global App Logs Toggle with Default-Off and Lazy Performance Instrumentation (2026-06-25)

**Status**: Accepted

**Related**: ADR-007 (Modular Settings Architecture for `ExperienceSettings`), ADR-023 (Official OpenCode Contract-First Compatibility Policy). Ref: issue #91.

### Context

CodeWalk accumulates in-memory app logs and emits performance instrumentation (operation timings, span contexts, payload captures) across the runtime. Some of this work is observable to the user through an App Logs surface; some is internal telemetry used for diagnostics. Both paths consume CPU and memory even when the user has not asked for that information.

Historically, a `performanceLoggingEnabled` flag existed in `ExperienceSettings` (ADR-007), but there was no user-facing App Logs toggle and the default for new installs and at startup was effectively "on" — app logs accumulated from first launch and some performance-instrumentation call sites still built diagnostic context before the logger could decide whether to emit a timing entry. New users therefore paid a cost for a feature they never asked to enable, and there was no clear way to turn the App Logs surface off without disabling diagnostic support entirely. Legacy installs may also have `performanceLoggingEnabled = true` persisted with no explicit `loggingEnabled` value, creating an ambiguous state once a unified logging toggle is introduced.

### Decision

1. **Global App Logs toggle (`loggingEnabled`) in `ExperienceSettings`** — Add a single user-facing boolean that controls whether the App Logs surface and its in-memory buffer are active. Default value is `false` for new installs and at startup, so a fresh launch does not accumulate logs unless the user explicitly opts in.

2. **Explicit user preference preserved** — When the user has explicitly set `loggingEnabled` (true or false), that value is persisted and restored verbatim on subsequent launches. The migration below only applies to legacy state where no explicit `loggingEnabled` is present.

3. **Legacy migration** — On settings hydration, if the persisted payload contains `performanceLoggingEnabled = true` and no `loggingEnabled` field, copy that intent forward by setting `loggingEnabled = true`. This honors the user's earlier opt-in to performance-related logging without silently flipping the new toggle on for users who never had a logging preference. `performanceLoggingEnabled` itself is left intact for backward compatibility with code that still reads it.

4. **Buffer clear on disable** — When `loggingEnabled` flips to `false` at runtime, the in-memory app log buffer is cleared immediately so the user does not see stale entries in the App Logs surface after opting out. The buffer remains empty while the toggle is off; future log emissions are dropped at the source.

5. **Lazy performance context while logging is off** — Performance instrumentation call sites that need diagnostic context (operation timing tags, safe IDs, payload sizes) pass a lazy `contextBuilder` callback. `AppLogger` invokes that callback only after the effective performance gate is still enabled, including after async work completes. The call sites continue to compile and run, but the per-call work of hashing IDs and allocating context maps is skipped while logging or performance logging is off. This keeps the hot path cheap for the default-off case without scattering broad conditional logic through call sites.

6. **Settings UI** — The settings surface exposes the new `loggingEnabled` toggle with a clear label that it controls the App Logs surface. The migration is transparent: legacy users who had performance logging on will see the toggle enabled after first launch on the new build.

### Rationale

- A single global toggle is simpler to reason about than two coupled flags and matches the user's mental model ("do I want app logs running or not?").
- Defaulting to off respects the mobile-first UX principle: background work the user did not request should not run by default, especially on battery-constrained devices.
- Preserving an explicit `loggingEnabled` choice is non-negotiable — silently overriding a value the user set would create a worse UX than the original problem.
- The legacy migration is one-directional and lossless: it only flips `loggingEnabled` on for users who had the older, narrower `performanceLoggingEnabled` flag on. Users with no logging history stay off.
- Clearing the buffer on disable avoids showing stale log entries after the user has decided they do not want logs; this is a predictable "off means off" UX guarantee.
- Lazy context builders are the smallest-blast-radius way to gate expensive performance-log context without scattering `if (loggingEnabled)` checks through every call site, and they keep the call sites statically analyzable.
- This change is entirely client-side: no OpenCode contract change, no new endpoints, no server payload modifications — fully compatible with ADR-023.

### Consequences

- ✅ New installs and startups default to App Logs off, eliminating background log accumulation and performance-instrumentation overhead for users who do not opt in.
- ✅ Users with an explicit `loggingEnabled` preference keep it verbatim across upgrades.
- ✅ Legacy users with `performanceLoggingEnabled = true` and no `loggingEnabled` get the new toggle flipped on, preserving their previous opt-in intent.
- ✅ Disabling `loggingEnabled` at runtime clears the in-memory buffer and prevents further log emissions from accumulating.
- ✅ Performance-log context at expensive call sites is gated by lazy context builders, so the default-off hot path stays cheap.
- ✅ No server contract change — fully ADR-023 compliant.
- ⚠ The migration is keyed on the legacy `performanceLoggingEnabled = true` condition; future renames of that flag require updating the migration check.
- ⚠ The effective performance gate still runs on every instrumented operation. This is intentional — it is cheaper than always building diagnostic context, but not free.
- ❌ Users who relied on implicit-on logging on first launch must explicitly enable the App Logs toggle to see logs.

### ADR-023 Compatibility

This ADR is fully compliant with ADR-023. It introduces no OpenCode server contract change, no new endpoints, and no modification to existing request/response schemas or lifecycle semantics. The toggle, the migration, the buffer-clear behavior, and the lazy performance instrumentation are all client-side concerns operating on local preference state. Server-authoritative behavior and event semantics are unchanged.

**Note** (issue #71): Extends the default-off app logging surface introduced in this ADR with structured task timing and aggregation — strictly client-side, no OpenCode contract change, fully ADR-023 compliant:
1. **`TaskHandle` abstraction** — a typed wrapper for instrumentation sites to start/finish structured task timings when app logging is enabled, capturing duration, status, tags, and metrics in the in-memory log buffer.
2. **Tags / phase metrics** — task timings emit structured tags such as `task:<name>`, `phase:start`, `phase:end`, and `status:<status>` plus metrics such as `taskId`, `parentTaskId`, `operation`, `elapsedMs`, and `context`.
3. **Tag filtering** — the App Logs surface gains a tag-based filter so users can narrow the view to a single category (e.g. `task:load_sessions`, `network:sse`, `cache:read`) without touching settings or restarting the session.
4. **Slowest tasks** — the existing bounded in-memory buffer powers a "slowest tasks" view for selected `task:*` tag scopes, kept coherent with `loggingEnabled` and cleared on disable alongside the existing buffer-clear behavior.
5. **Local-only, ADR-023 compliant** — `TaskHandle`, tags, tag filtering, and the slowest-tasks view are entirely client-side. No new endpoints, request/response schemas, payload fields, or lifecycle semantics on the OpenCode server. Preserves ADR-023 without requiring an exception.

### Key Files

- `lib/core/logging/app_logger.dart` — in-memory app log buffer, global emission gate, effective performance gate, clear-on-disable, and lazy `contextBuilder` support
- `lib/domain/entities/experience_settings.dart` — `loggingEnabled` field, default-off value, and legacy `performanceLoggingEnabled` → `loggingEnabled` migration
- `lib/presentation/providers/settings_provider.dart` — toggle persistence, AppLogger synchronization, and buffer-clear hook on disable
- `lib/presentation/pages/logs_page.dart` — `Enable app logging` toggle, disabled-state explanation, and re-enable action
- `lib/data/datasources/app_local_datasource_storage_helpers.dart` — lazy cache-performance context builders for large cache read/write/migration paths
- `lib/presentation/providers/chat_provider.dart` — lazy context builders for session/message performance paths
- `lib/presentation/providers/project_provider.dart` — lazy context builders for project/directory switch performance paths
- `test/unit/logging/app_logger_performance_test.dart` — global gate, effective performance gate, lazy context, and in-flight disable coverage
- `test/unit/domain/experience_settings_test.dart` — default-off, explicit preservation, and legacy migration coverage
- `test/widget/logs_page_test.dart` — LogsPage disabled/default/toggle behavior and performance filter coverage
- Ref: issue #91

---

## ADR-043: Files as a Shell-Gated Micro File Manager with Capability-Probed Mutations (ADR-023 Exception) (2026-07-02)

**Status**: Accepted

**Related**: ADR-008 (Context-Scoped File Explorer and Viewer with Quick Open and Diff-Aware Refresh), ADR-023 (Official OpenCode Contract-First Compatibility Policy), ADR-027 (Server-Hosted PTY Terminal with Embedded Client Rendering), ADR-029 (Host-Discovered Quota and Rate-Limit Monitoring for OpenChamber Parity), ADR-002 (Context Isolation), ADR-040 (Client-Owned Per-Project Icon Discovery), ADR-052 (Bounded Default-Off Autosave Addendum for the Focused File Editor). Ref: issue #89, issue #90.

**Scoped addendum**: ADR-052 supersedes only the explicit-save-only/autosave exclusion below. All other ADR-043 decisions, including the shell-backed mutation boundary and focused-editor save contract, remain accepted.

### Context

ADR-008 established the file explorer as a read/navigation/diff-refresh surface over the official OpenCode read-only file API: the tree, quick open, viewer, and diff-aware refresh are all purely observational. Issue #89 extends the same surface with a micro file manager: create file, create folder, rename, delete, copy path, and explicit refresh, exposed through file-tree context menus and a root "New" menu. Together they turn the explorer into a lightweight, scoped file manager that lives next to the chat conversation.

The official OpenCode server file API is read/search only — it has no first-class mutation endpoints. At the same time, mutations (especially deletes) are destructive and must be safely contained. Three constraints define the design space:

1. **No invented server contract.** CodeWalk must not synthesize a new mutation endpoint or call non-Official OpenCode routes as if they were official (ADR-023, §3 "Explicit Divergence"). All existing read paths and event semantics must continue to be authoritative.
2. **No local `dart:io` mutation.** The client cannot write to the project filesystem on its own; the server host owns the workspace, environment, and toolchain (ADR-027, ADR-029). A local mutation would also defeat the cross-platform, server-hosted model that ADR-027 already settled on for shell access.
3. **Strict containment.** Mutations must be confined to the active project root, must refuse the canonical filesystem root, must refuse unsafe leaf names, and must require an explicit delete confirmation. The capability to mutate must be probed and cached, and a safe read-only fallback must be the default when the probe fails.

ADR-029 already established a hidden ephemeral OpenCode shell session as a server-side execution channel for host-discovered quota probes. The same transport — `POST /session`, `POST /session/:id/shell`, and `DELETE /session/:id` — hosts the file-operation pipeline. The terminal in ADR-027 stays separate: file mutations are one-shot scripted calls with no PTY, no interactive streaming shell, and no terminal UI.

Issue #90 extends the same surface with a focused text/code editor and explicit save: the file viewer (ADR-008) is upgraded into a dirty-tracked editor with an explicit `Save` action that writes back to the host filesystem through the same shell pipeline. The save path reuses containment, ephemeral-session lifecycle, and capability probing — it is not a parallel mutation surface. ADR-008's viewer stays the read-only fallback when the capability is missing; issue #90 only adds a `Save` affordance and a draft state machine, never a new mutation channel.

### Decision

1. **Mutation layer is `WorkspaceFileOperationsServiceImpl`.** All four mutations (create file, create folder, rename, delete) plus a `getCapabilities` / `invalidateCapabilities` pair are exposed as an abstract `WorkspaceFileOperationsService` so the UI can be wired against a fake in tests (`FakeWorkspaceFileOperationsService` in `test/widget/chat_page_test.dart`). The impl is injected through DI and the file-tree context menu actions and the root "New" menu are gated on its capability result, not on raw feature flags.

2. **Hidden ephemeral OpenCode shell session per call.** Each operation creates, routes, and finally deletes an ephemeral session using the official directory query on every leg. `POST /session/:id/shell` receives one transport-safe pipeline, not a semicolon-delimited command: `printf <encoded-static-script> | <negotiated decoder> | <operation ENV> sh`. The static POSIX program is decoded into one `sh` process; dynamic arguments and content are environment data. The session stays filtered from realtime and is never a PTY, terminal UI, or interactive shell.

3. **`CW_FILE_OP_JSON:` sentinel protocol.** The static program emits a structured sentinel. Parsing examines official `parts[].state.output` and `parts[].state.error` values, selects the last valid sentinel, and maps absent/invalid responses to bounded generic operation errors (`malformedResponse` included). Failed-operation logs record only the operation code plus path/newPath hashes; never the shell message, command output, or stderr.

4. **Capability and decoder negotiation are cached per server + directory.** The probe resolves the canonical root with `pwd -P`, rejects `/`, and negotiates a decoder in order across GNU `base64 -d`, BSD `base64 -D`, `base64 --decode`, and `python3`. The selected decoder is cached with the capability result by `serverScopeKey::directory`; capability invalidation also invalidates decoder selection. Literal and canonical filesystem roots remain blocked before and inside the shell.

5. **Encoded static POSIX program, no PTY.** The prior `malformedResponse` failure was observed in CodeWalk v1.174.0 and isolated against local OpenCode 1.17.18, where `/shell` separated semicolon commands into isolated shells. Every operation therefore transports one encoded static POSIX program through the negotiated decoder pipeline. It retains `set -u`, validation, containment, and sentinel helpers, while dynamic content is carried as ordered 48 KiB environment chunks and streamed inside `sh`. Richer operations still require a future ADR.

6. **Strict project-root containment.** Every mutation:
   - Normalizes and trims the leaf name; rejects empty, `.`, `..`, anything containing `/`, `\`, NUL, LF, or CR (`invalidName`).
   - Resolves both `rootDirectory` and `parentDirectory` with `normalizeFilePath`; rejects empty or `/` roots (`outsideRoot`); rejects any parent that is not the root or under the root (`outsideRoot`).
   - Refuses to delete or rename the project root itself (`rootDeleteBlocked`) if a generated target/source ever equals the canonical root; invalid leaf-name validation blocks the ordinary direct-root cases before any shell call.
   - Quotes every interpolated path with the project's `_shQuote` (single-quote with `'\''` escapes) so names with spaces, quotes, or unicode never break the script.

7. **Invalid leaf names blocked at the client boundary.** `_normalizeLeafName` runs in the same `_prepareLeafOperation` (or its rename-specific path) before any shell call, so a bad name never produces a network request. The same rule applies in both client-side and server-side (`cw_validate_name` in the shell) — defense in depth, since the shell runs on the host.

8. **Delete confirmation.** `delete` shows an `AlertDialog` (`filesDeleteTitle(name)` + `filesDeleteConfirm(name)`) with explicit Cancel and Delete actions before the service is called. The action is also flagged `destructive: true` in the file-tree context menu (`FileTreeContextMenuAction.destructive`) so the renderer can apply a danger color and the menu item does not adopt the modal-Enter policy from ADR-024. Copy path and refresh are always available even when mutations are not, because they are pure read-side affordances.

9. **Open-tab / tree reconciliation after rename and delete.** After a successful rename, `_reconcileRenamedFileTreePath` rewrites every key in `tabsByPath`, `tabSelection.openPaths`, `tabSelection.activePath`, `selectedLinesByPath`, and `lastSelectedLineByPath` from the old path prefix to the new one, and prunes the old directory subtree from the tree cache. After a successful delete, `_reconcileDeletedFileTreePath` closes any open tab whose path matches the deleted entry and prunes the subtree from the tree cache. New file / new folder reuses the existing `_refreshFileTreeDirectory(force: true)` to refetch the parent directory, and the `onUpdated` callback drives a `setState` so the tree, the tabs, and the quick-open dialog all observe the change without an extra round-trip.

   Issue #104 correction (plan `6eb28f0a`, commits `dc48fefc`, `99fb5bf`, `56353ed`): confirmed deletes reconcile absolute, relative, and root-relative aliases before and after the forced authoritative parent refresh, so failed, stale, or racing relists cannot restore a row already deleted by the host. While a delete is pending, matching and descendant editors/saves plus overlapping tree mutations/creates are blocked until the host result; failure unlocks and preserves state, success removes the confirmed path.

10. **Read-only fallback is the default.** The file-tree context menu only shows the four mutation actions when `_fileMutationsSupported(fileState)` is true, i.e. when `fileState.fileOperationCapabilities?.shellFileOpsSupported == true`. The root "New" menu (the `PopupMenuButton` with `file_tree_menu_new_file` / `file_tree_menu_new_folder` items) is hidden in the same condition. If the capability probe returns `unavailable` or `outsideRoot`, the UI stays exactly as it was under ADR-008: tree, quick open, viewer, diff-aware refresh, copy path, and explicit refresh all work, but no mutation affordance is exposed. There is no client-side fallback path that bypasses the shell.

11. **Focused editor with explicit save via `writeFile`.** The file viewer is augmented with a `CodeEditor`-backed focused editor (`_buildFocusedFileEditor` in `chat_page_file_viewer.dart`) that tracks a per-tab draft (`_FileEditorDraftState` with `isDirty`, `isSaving`, `savedContent`, `saveErrorMessage`) and surfaces a single explicit `Save` action (also bound to `Ctrl+S` / `Cmd+S` via the editor's key handler). `_saveFileEditorDraft` calls `WorkspaceFileOperationsService.writeFile({serverScopeKey, rootDirectory, path, content})`, which routes through the same ephemeral shell session. The implementation takes the editor's UTF-8 text buffer and base64-encodes it inside the service (`contentBase64: base64Encode(utf8.encode(content))`), so the channel carries text content only — no arbitrary binary payloads. The script (`_buildWriteFileCommand`) runs the existing `cw_validate_name` + `cw_prepare_parent` helpers, refuses to write if the target equals the canonical project root (`rootDeleteBlocked`) or is unwritable (`permissionDenied`), then writes the body to a unique sibling temp directory (`tmpdir=$(mktemp -d "$parent/.cw-write.XXXXXX")`, `tmp="$tmpdir/content"`) — replacing the prior fixed `$parent/.cw-write-$$.tmp` so concurrent saves do not collide on a shared name — decodes it via `cw_decode_content` (prefers `base64` / `base64 --decode`, falls back to `python3`), preserves the target's mode with `cw_copy_mode "$target" "$tmp"` before `mv --`, and cleans up by `rm -f -- "$tmp"` followed by `rmdir -- "$tmpdir"` on both success and failure paths. The host-side atomic rename under the same parent already passed the root-containment case check. The mutation request is refused client-side when `path` is empty, contains NUL/LF/CR, contains a `..` segment, or canonicalizes to the project root (`outsideRoot` / `rootDeleteBlocked` / `invalidName`); the capability probe is the gate. `_runMutation` clears the capability cache on `unavailable` / `malformedResponse`, same as the four pre-existing operations, so transient transport failures auto-recover. Read-only fallback is enforced at the UI boundary (`_editorReadOnlyReason`) and at the service boundary: large files (`> 1024 * 1024` bytes) open read-only to keep editing responsive. Save gating is computed against the **current draft UTF-8 byte length**, not only against the original on-disk content — an oversize draft sets the static `saveErrorMessage = 'Draft is too large to save from the editor.'` (not an ARB key) and blocks the save without dispatching a shell call. Empty non-binary text files (`isBinary == false && content.isEmpty`) load as ready editor drafts with an empty `CodeEditor` instead of the previous empty placeholder, so the user can type immediately without an extra open action. `_editorDraftForContent` schedules the controller's `replaceSavedContent` via a post-frame callback (`WidgetsBinding.instance.addPostFrameCallback`) so the `CodeLineEditingController` is never mutated during the build phase. The add-to-chat affordance for the currently open file reads the **current draft text** from the editor when a draft is active (falling back to the saved content otherwise), so what is sent to chat always reflects what the user is looking at; dirty tabs block silent tab reloads — when a diff-driven `_reloadFileTab` would overwrite an open tab whose draft is still dirty, the reload is skipped and the draft gets an inline `saveErrorMessage = 'Unsaved changes; reload skipped.'` (a static message baked into `_reloadFileTab`, **not** an ARB key) so an unsaved draft never gets clobbered; save errors are surfaced as an inline error banner/decoration (e.g. `'Permission denied.'` mapping via `_fileOperationErrorLabel`) and through a non-blocking snackbar (`_showFileOperationSnackBar`). The dirty marker is the literal character `*` rendered next to the tab title via the `file_viewer_tab_dirty_<path>` `ValueKey`.

12. **Transport and editor correction** (plan `e05a3b68037a57c74e73552de66c09a2b7dc3d6a`; commits `729fec2`, `aa52638`, `0f580a8`). This supersedes earlier ADR-043 wording that described a direct multiline script, a single `CW_CONTENT_B64` variable, or a 1 MiB editor-save limit. `writeFile` uses the same encoded static-script pipeline; UTF-8 dynamic content is split into ordered 48 KiB environment entries and streamed in `sh`. Live OpenCode verification sets a 64 KiB UTF-8 editor/save cap; larger files are read-only.

### Rationale

- **Server-hosted, no client mutation.** The project directory lives on the OpenCode server host; running `dart:io` writes on the client would either silently fail (remote/dev/staging) or corrupt cross-device state. Routing mutations through a hidden shell session is the same architectural decision ADR-027 took for the terminal: keep the host authoritative.
- **Reuse the ADR-029 transport safely.** The official session lifecycle remains reliable, but the failure observed in CodeWalk v1.174.0 was isolated against local OpenCode 1.17.18, where `/shell` separated semicolon-delimited commands into isolated shells. Encoding the static program and passing dynamic values separately preserves the same host-owned transport without relying on command-string splitting behavior.
- **Official WorkspaceRoutingQuery preserves session scope.** Issue #104 showed the ephemeral session must be created with the active directory, not only execute the shell with it. Passing the same official routing directory on create, shell, and cleanup — and relying on OpenCode's stored `session.directory` for session-scoped calls — keeps file operations pinned to the active project without a custom endpoint or local `dart:io` path.
- **Sentinel protocol has an official-envelope boundary.** The `CW_FILE_OP_JSON:` prefix is parsed only from `parts[].state.output` / `error`; choosing the last valid sentinel tolerates surrounding output while bounded generic errors and failed-operation logs limited to the operation code plus path/newPath hashes prevent shell text from becoming an app contract or a disclosure path.
- **Capability probe keeps the UI honest.** A server that does not support ephemeral shell sessions (older OpenCode, hardened deployments, missing `/session/:id/shell`) returns 404 — the service maps that to `unavailable`, the cache drops, and the UI stays read-only. There is no silent "this button does nothing" state and no invented success path.
- **Strict containment matches the blast radius.** Project-root containment, root delete blocking, and invalid leaf-name rejection are tested at both the client (`_normalizeLeafName`, `_isPathUnderRoot`, `_isUnsafeRoot`) and the shell (`cw_validate_name`, `cw_prepare_parent`). A bad name never produces a network call; a path outside the root never reaches the shell.
- **No PTY keeps the blast radius small.** One encoded static POSIX program runs through a one-shot `POST /session/:id/shell`, has no terminal UX, and is always followed by `DELETE /session/:id` in `finally`. This remains distinct from ADR-027's terminal lifecycle and UI.
- **Read-only fallback is non-disruptive.** If the probe is unavailable, the user keeps the full ADR-008 surface — tree, viewer, diff-aware refresh, copy path, manual refresh — and only loses the four mutation affordances. There is no upgrade path that breaks an existing user.
- **Open-tab and tree reconciliation preserve the existing context.** Renaming or deleting a path while a tab is open would otherwise leave the viewer pointing at a stale path; the reconciliation helpers guarantee the tabs, the tree, the selected lines, and the quick-open cache stay coherent without forcing the user to re-open the file manually.
- **Pending-delete guards make destructive reconciliation authoritative.** Blocking matching and descendant editors/saves plus overlapping tree mutations/creates until the host result prevents racing writes or creates during delete; reconciling absolute, relative, and root-relative aliases before and after the forced parent refresh prevents stale relists from resurrecting a host-confirmed deletion, while failure unlocks and preserves state.
- **Editor + explicit save reuses the ADR-043 transport, not a new contract.** `writeFile` sends the same encoded static program, negotiated decoder, and sentinel. UTF-8 dynamic content is split into ordered 48 KiB environment entries and streamed by `sh`; no content is interpolated into a multiline command. No endpoint, request schema, or event semantic changes, and the same capability gate supplies the read-only fallback.
- **Temp directory under parent + atomic `mv` keeps the host authoritative.** Writing to `tmpdir=$(mktemp -d "$parent/.cw-write.XXXXXX")` / `tmp="$tmpdir/content"` and `mv -- "$tmp" "$target"` is a host-side atomic rename that reuses the project-root containment (`cw_prepare_parent` + `case "$parent" in "$root"|"$root"/*)`) the four pre-existing operations already enforce. The `mktemp -d` template gives every save a unique directory, so concurrent saves for the same target (or quick repeated saves) never collide on a fixed `$parent/.cw-write-$$.tmp` name; cleanup runs `rm -f -- "$tmp"` followed by `rmdir -- "$tmpdir"` so a failed atomic rename does not leave the temp directory behind. `cw_copy_mode "$target" "$tmp"` is invoked before `mv --` so the replacement file preserves the existing target's permission bits instead of inheriting whatever umask produced the decoded content; the editor's draft state (`isDirty`, `isSaving`, `savedContent`, `saveErrorMessage`) is a UI-only cache that never touches the project filesystem, so the host stays the only writer.
- **Negotiated decoding avoids shell and host assumptions.** Capability probing selects GNU `-d`, BSD `-D`, `--decode`, or `python3` once per server/directory and invalidates that choice with capabilities. The static program consumes the ordered environment chunks without heredocs or unquoted content interpolation.
- **64 KiB editor limit + dirty-tab gates keep saves honest.** Live OpenCode verification limits editable/savable UTF-8 content to 64 KiB; larger files are read-only. Dirty tabs still refuse silent reloads and retain an explicit save error, so neither a size violation nor a refresh silently loses a draft.
- **Current-draft UTF-8 gating is authoritative.** The 64 KiB limit applies to the current draft, not only the loaded file, so an oversize paste/type is rejected before a shell call.
- **Empty non-binary files open as drafts.** Treating `isBinary == false && content.isEmpty` as a ready-to-edit draft (empty `CodeEditor` with a `Save` action) instead of an empty placeholder removes an extra "open" step and matches user expectation: an empty text file is a buffer waiting for input, not a special empty state.
- **Post-frame controller mutation keeps the editor build-pure.** Routing `_editorDraftForContent` through `WidgetsBinding.instance.addPostFrameCallback` guarantees that `CodeLineEditingController.replaceSavedContent` runs after the current frame's build phase, avoiding a known class of "controller used during build" assertions and double-rebuild loops. The post-frame scheduling is unconditional for the draft path because the controller lifecycle is owned by the editor widget. The post-frame callback is additionally guarded by an active-draft identity check so a stale draft cannot race a newer tab/scroll sync, and `_editorDraftForContent` recreates a clean draft (replacing the prior one) when a reload changes the file's detected line-break style — preventing a stale LF-only buffer from leaking into a CRLF re-edit and vice versa.
- **`replaceSavedContent` stores `controller.text` after controller normalization.** After `CodeLineEditingController.replaceSavedContent` runs in the post-frame callback, the editor re-reads `controller.text` (which the controller has normalized to the active `CodeLineOptions.lineBreak`) and writes it back to the draft's `savedContent`. This guarantees `savedContent` always reflects the controller-canonical form, so subsequent dirty comparisons and the next save round-trip start from the same normalized text.
- **`_FileEditorDraftState` preserves LF / CRLF / CR.** The draft detects the file's line break on load (LF, CRLF, or CR) and instantiates the editor with `CodeLineOptions(lineBreak: <detected>)`; `_editorDraftForContent` re-detects on reload, so a CRLF file edited and saved round-trips with CRLF preserved end-to-end and never silently collapses to LF.
- **Add-to-chat reads the current draft.** Sourcing the add-to-chat payload from the editor's current text (when a draft is active) instead of the last-saved content keeps what the user is reading and what the chat receives coherent; the chat input never quotes a stale copy of the file while the user is still editing.
- **Gutter selection splits LF / CRLF / CR with `_splitFileEditorLines`.** The add-to-chat gutter action routes the selected range through `_splitFileEditorLines`, which splits on the file's detected line break (LF, CRLF, or CR) — never on a hardcoded `\n` — so gutter-attached ranges from CRLF / CR files are quoted line-by-line with no cross-line bleed or trailing-CR artifacts.
- **Dirty / saving editor drafts block close, reload, rename, and delete before server mutation.** The file-tab close path, the diff-aware `_reloadFileTab` path, and the file-tree context-menu rename / delete paths each refuse to run when the affected tab carries a draft with `isDirty || isSaving`; the rename and delete handlers additionally check both the **absolute** path of the target and the **original relative-path alias** stored on the draft (since the tree may show the path as relative while the service expects an absolute join) so a relative-path rename or delete that would silently skip the dirty tab is caught and surfaced to the user before any shell call is dispatched.
- **Open-files dialog refreshes after a pending capability probe completes.** The quick-open / open-files dialog subscribes to the shared `fileOperationCapabilitiesLoad` future keyed by `serverScopeKey` + directory; when the dialog opens before the capability probe resolves (or while a probe is in flight), it auto-refreshes its rows once the probe completes, so a dialog that initially rendered under "capability unknown" never lingers stale once `shellFileOpsSupported` is known.

### Consequences

- ✅ File explorer becomes a usable micro file manager: create file/folder, rename, delete, copy path, and explicit refresh are all reachable from the file-tree context menu and the root "New" menu.
- ✅ Mutations run on the OpenCode host, so the active project's environment, permissions, and toolchain stay authoritative — same model as ADR-027.
- ✅ No invented server contract: the implementation reuses `POST /session`, `POST /session/:id/shell`, and `DELETE /session/:id`. No new endpoints, no modified request/response schemas, no event semantic changes.
- ✅ Ephemeral file-operation session creation, shell execution, and cleanup all carry the official `WorkspaceRoutingQuery` directory; OpenCode's stored `session.directory` is preferred for session-scoped calls.
- ✅ Strict containment at both layers: bad leaf names are rejected before any network call; bad parents are rejected by the shell script via `pwd -P` + case check; the project root itself cannot be deleted.
- ✅ Capability probe + cache keeps the UI honest: servers without ephemeral shell support stay read-only without inventing a fake success path.
- ✅ Decoder negotiation is cached per server/directory and invalidated with capabilities, supporting GNU `-d`, BSD `-D`, `--decode`, and `python3` hosts.
- ✅ Official `parts[].state.output` / `error` parsing selects the last valid sentinel; failures are bounded and logs retain only operation codes plus path/newPath hashes.
- ✅ Open-tab and tree reconciliation preserve viewer state across rename and delete.
- ✅ Confirmed deletes reconcile absolute, relative, and root-relative aliases before and after forced parent refresh, so stale or racing relists cannot restore deleted rows.
- ✅ Pending deletes block matching/descendant editors/saves and overlapping tree mutations/creates until the host result; failure unlocks and preserves state, success removes the confirmed path.
- ✅ Read-only fallback is the default — users on servers without the shell endpoint keep every ADR-008 capability.
- ✅ The encoded-static-script pipeline is auditable and avoids the semicolon-command-splitting behavior isolated against local OpenCode 1.17.18 after the failure observed in CodeWalk v1.174.0; richer operations still require a future ADR.
- ✅ File viewer becomes a focused text/code editor with explicit save: `Save` writes the dirty draft back to the host through the same ephemeral shell transport; the draft state machine (`isDirty` / `isSaving` / `savedContent` / `saveErrorMessage`) keeps the tab coherent without holding any local copy of the file content beyond the editor buffer.
- ✅ `writeFile` uses `mktemp -d "$parent/.cw-write.XXXXXX"` / `tmp="$tmpdir/content"` instead of a fixed temp name, so concurrent or repeated saves no longer collide on a shared `$parent/.cw-write-$$.tmp`; `cw_copy_mode "$target" "$tmp"` preserves the target's mode bits across the atomic rename, and the `rm` + `rmdir` cleanup runs on both success and failure paths.
- ✅ Save gating uses the current draft UTF-8 byte length: content over 64 KiB is read-only / unsavable and never dispatches a shell call.
- ✅ Empty non-binary text files open as ready editor drafts, so the user can type immediately; add-to-chat for the open file always reads the current draft text, keeping the chat input coherent with what the user is editing.
- ✅ `_editorDraftForContent` schedules `replaceSavedContent` via a post-frame callback, keeping the `CodeLineEditingController` mutation outside the build phase; the post-frame callback is guarded by an active-draft identity check so a stale draft cannot race a newer tab/scroll sync, and `_editorDraftForContent` recreates a clean draft when a reload changes the file's detected line-break style.
- ✅ Editor drafts round-trip LF / CRLF / CR verbatim: line break is detected on load and round-tripped through `CodeLineOptions(lineBreak: ...)`, and `replaceSavedContent` stores `controller.text` after controller normalization so `savedContent` always reflects the controller-canonical form.
- ✅ Dirty / saving editor drafts block close, reload, rename, and delete before any server mutation; rename and delete additionally check both the absolute target path and the original relative-path alias stored on the draft, so a relative-path rename or delete that would silently skip a dirty tab is caught client-side.
- ✅ The add-to-chat gutter selection splits on the file's detected line break via `_splitFileEditorLines` (LF / CRLF / CR), so gutter-attached ranges from CRLF / CR files are quoted line-by-line with no cross-line bleed or trailing-CR artifacts.
- ✅ The open-files dialog refreshes after a pending capability probe completes via the shared `fileOperationCapabilitiesLoad` future keyed by `serverScopeKey` + directory, so a dialog opened before the probe resolves never lingers stale once `shellFileOpsSupported` is known.
- ⚠ Adds a second consumer of the ephemeral shell transport alongside ADR-029 — the realtime filter and 5s prune in `ChatTitleGenerator` are now load-bearing for both features. A regression in that filter would leak ephemeral sessions into the chat timeline.
- ⚠ The shell scripts are POSIX `sh` only; Windows hosts that route through `bash`/WSL are covered, but exotic shells (fish, nushell) are not validated. The MVP is intentionally minimal.
- ⚠ Each mutation is a full round-trip (`POST /session` → `POST /session/:id/shell` → `DELETE /session/:id`), which is slower than a hypothetical native mutation endpoint. Acceptable for the four operations, but bulk operations (move many files, large refactors) would need a different transport.
- ⚠ The capability cache is in-memory only; a process restart re-probes every directory. This is the correct behavior for a probe that may have changed server-side, but it does mean a fresh launch on a slow host pays a one-shot latency cost.
- ⚠ `writeFile` remains a full session round-trip. Dynamic content is transmitted as ordered 48 KiB environment entries and streamed inside `sh`; the 64 KiB UTF-8 cap is a verified compatibility boundary, not support for large editor saves.
- ❌ Servers without ephemeral shell support cannot enable file mutations. This is the intentional safe fallback; no client-side bypass path is provided.
- ❌ No move-across-directories, no permissions editor, no bulk operations, no multi-select, no undo. These are follow-ups behind a future ADR.
- ❌ No local `dart:io` mutation path. The client never writes to the project filesystem directly — the host is always authoritative.
- ⚠ The original explicit-save-only boundary is narrowed by ADR-052: manual `Save` remains available and authoritative, while bounded opt-in autosave is governed by that addendum. Client-side format-on-save, diff/merge view, and multi-cursor persistence remain follow-ups behind separate decisions.

### ADR-023 Exception Declaration

This ADR constitutes an explicit ADR-023 exception per section 3 ("Explicit Divergence") of ADR-023.

**Deviation from official behavior**: Official OpenCode defines the file API as read/search only. There is no first-class mutation endpoint. CodeWalk performs file mutations by reusing the official ephemeral shell transport (`POST /session`, `POST /session/:id/shell`, `DELETE /session/:id`) with a structured `CW_FILE_OP_JSON:` sentinel payload. This is a server-side shell-backed mutation that lives outside the official file API surface.

**Why this is acceptable**:
- The OpenCode file API is unchanged — CodeWalk still uses the official endpoints for every read, navigation, search, and diff path. No new mutation endpoints are invented, and no read payload is reinterpreted.
- The ephemeral shell transport is the same `POST /session` → `POST /session/:id/shell` → `DELETE /session/:id` pattern ADR-029 already uses for host-discovered quota probes. It is a documented, server-supported surface, not a custom OpenCode extension.
- The feature is capability-gated: `getCapabilities` runs a probe and the UI only exposes mutation affordances when the server reports `shellFileOpsSupported = true`. A server that does not support the transport stays read-only.
- The probe uses canonical `pwd -P` and the strict `case "$parent" in "$root"|"$root"/*) ;; *) cw_fail outsideRoot ;; esac` containment so the server-side script enforces the same project-root boundary the client checks. The script is auditable, single-purpose, and short.
- The implementation never writes to the project filesystem on the client; the host is always authoritative.

**Why this is not a free pass for additional divergences**: The exception is scoped to the four mutation operations, focused-editor `writeFile` save (issue #90), capability/decoder probe, and the bounded autosave scheduling policy in ADR-052. Save and autosave are in scope only as the same one-shot encoded static-program pipeline with `CW_FILE_OP_JSON:` and `shellFileOpsSupported`; neither adds an endpoint, request schema, or event semantic. Any new mutation, cross-directory move, bulk operation, format-on-save, diff/merge view, or read-side change must still be separately evaluated against ADR-023. Future shell growth must preserve the encoded static pipeline, containment, bounded parsing, and no-content logging.

### Risks

- **Medium containment risk.** The program runs with server permissions. Client and shell root/leaf validation, canonical-parent checks, and quoted path handling remain mandatory; weakening any of them can escape the project root.
- **Medium transport risk.** The failure observed in CodeWalk v1.174.0 was isolated against local OpenCode 1.17.18, where `/shell` separated semicolon commands into isolated shells. The encoded-static-script pipeline is mandatory; decoder negotiation must fail closed and capability invalidation must discard its cached decoder.
- **Low parsing/privacy risk.** Shell envelopes can contain arbitrary output. Only the last valid sentinel in `parts[].state.output` / `error` is trusted; generic bounded errors and failed-operation logs limited to the operation code plus path/newPath hashes prevent message or stderr disclosure.
- **Low lifecycle and UX risk.** Session cleanup stays in `finally`; pending-delete locks and alias reconciliation stay in force until the host result. Failure unlocks without discarding drafts or restoring a confirmed deletion.

### Rollback / Fallback Plan

- **Per-server fallback**: invalidate capabilities and the paired decoder cache, then re-probe. There is no persisted mutation state or per-server toggle; an unsupported or malformed transport fails closed to read-only.
- **Product rollback**: remove the mutation affordances. The UI immediately returns to ADR-008's read-only surface; no filesystem changes are made by rollback itself.
- **Service fallback**: `unavailable`, negotiated-decoder failure, canonical-root refusal, or malformed response leaves mutations unreachable. The next explicit capability lookup may retry from a clean cache.
- **Server-level fallback**: if the OpenCode server later exposes an official mutation endpoint, the service can be re-pointed at it without UI changes — the abstract `WorkspaceFileOperationsService` interface is the seam. The capability probe becomes a check for the new endpoint and the sentinel protocol is retired.
- **Feature flag**: there is no global feature flag; the per-directory capability probe is the de facto flag. A future product-level kill switch (per profile or per server) can be added without API changes.

### Regression Tests

Plan `e05a3b68037a57c74e73552de66c09a2b7dc3d6a` (commits `729fec2`, `aa52638`, `0f580a8`) adds/updates unit and widget coverage under `test/unit/presentation/workspace_file_operations_service_test.dart` and `test/widget/chat_page_test.dart` for:

- one encoded-static-script pipeline with no semicolon-split execution path;
- decoder negotiation/caching per server+directory for GNU `-d`, BSD `-D`, `--decode`, and `python3`, including invalidation with capabilities;
- ordered 48 KiB environment chunk streaming, last-valid-sentinel extraction from `parts[].state.output` / `error`, bounded errors, and failed-operation logs limited to the operation code plus path/newPath hashes;
- 64 KiB UTF-8 editor/save boundaries (including multibyte content), with larger files read-only; and
- unchanged containment, atomic sibling-temp write, mode preservation, pending-delete locks, and delete alias reconciliation.

The historical cases below are retained only where compatible; any statement describing direct multiline commands, a single content environment variable, legacy decoder behavior, or a 1 MiB editor/save cap is superseded by this update.

#### Issue #90 (`writeFile` focused editor save)

**Service unit tests** — `test/unit/presentation/workspace_file_operations_service_test.dart`:

- **`write file uses base64 content and returns target path`** — exercises the success path: the script contains `CW_PARENT_INPUT=…`, `CW_NAME=…`, the UTF-8 text `content` is base64-encoded into a `CW_CONTENT_B64='…'` shell variable (using `base64Encode(utf8.encode(content))`), the script invokes `cw_decode_content "$tmp"`, `mktemp -d "$parent/.cw-write.XXXXXX"` (asserted via `contains('mktemp -d')`), and `cw_copy_mode "$target" "$tmp"` (asserted via `contains(r'cw_copy_mode "$target" "$tmp"')`) followed by `mv -- "$tmp" "$target"`; the test also asserts the script no longer contains the fixed `r'.cw-write-$$.tmp'` pattern, and `result.path` is the correctly joined target.
- **`write file rejects paths outside root before shell calls`** — escapes one relative (`../outside.dart`) and one absolute (`/repo/ab/main.dart`) path under `/repo/a`, asserts both return `outsideRoot` and `shellCallCount == 0`.
- **`write file blocks project root before shell calls`** — writes to the project root itself (`path: '/repo/a'`), asserts `rootDeleteBlocked` with `shellCallCount == 0`.
- **`write file malformed operation invalidates capability cache`** — sends a malformed shell response on the `writeFile` call, then makes a `createFile` call that must succeed only because the capability cache was dropped and had to be re-probed; asserts the next capability command is a `pwd -P` re-probe.

**Widget tests** — `test/widget/chat_page_test.dart`:

- **`file editor saves dirty content from open files dialog`** — types into the open editor via `tester.widget<CodeEditor>(…).controller!.text = …`, asserts the dirty marker `file_viewer_tab_dirty_<path>` is present, sends the `Ctrl+S` key sequence, asserts the dirty marker is gone, `writeFileCallCount == 1`, the captured `path` and `content` match, and the `'File saved.'` snackbar confirmation is shown.
- **`file editor keeps dirty state when save fails`** — injects a `FakeWorkspaceFileOperationsService` with `writeFileResult = WorkspaceFileOperationResult(ok: false, code: permissionDenied, message: 'denied')`, taps the `file_viewer_save_button`, asserts `writeFileCallCount == 1`, the dirty marker `file_viewer_tab_dirty_<path>` is still present, the inline error `file_editor_save_error_<path>` widget is shown, and the human-readable `'Permission denied.'` label is rendered via `_fileOperationErrorLabel`.
- **`file editor opens empty text files as editable drafts`** — opens a `FileNode` whose `FileContent` has `isBinary: false` and an empty `content`, asserts the focused `CodeEditor` is rendered (not the empty placeholder), the editor's controller starts empty, and a subsequent keystroke produces a dirty draft that the `Save` action can persist (i.e. the empty file is a ready draft, not a special empty state).
- **`file editor preserves CRLF line endings when saving`** — opens a draft seeded with CRLF content, edits and saves it, and asserts the captured `writeFile` call's content round-trips with CRLF preserved (no silent collapse to LF), confirming `_FileEditorDraftState` detects CRLF on load, `CodeLineOptions(lineBreak: ...)` keeps CRLF through the editor, and `replaceSavedContent` stores the controller-normalized `controller.text`.
- **`file editor gutter selection adds current draft to chat context`** — selects a multi-line range from the gutter of an open file with an active dirty draft, asserts the emitted chat-context entries are split via `_splitFileEditorLines` on the file's detected line break (LF / CRLF / CR) and that each entry references the live draft text (not the last-saved content).
- **`file editor blocks closing dirty tabs`** — taps the tab close affordance on a dirty draft, asserts the tab stays open and the close is refused with the `Save changes before closing this file.` message, confirming close is gated on `isDirty || isSaving` before any server-side action.
- **`file tree rename blocks dirty relative editor drafts`** — opens a file via a relative path so the draft stores the relative-path alias, triggers a rename of that path from the file-tree context menu, asserts the rename is aborted client-side via `_blockPathMutationForActiveEditorDrafts` with the `Save changes before changing this path.` message and the draft + tab remain intact, confirming the alias check (absolute + original relative) catches relative-path renames that would otherwise bypass the dirty guard.

#### Older ADR-043 covered tests (retained)

- **Sentinel extraction** (`extractSentinelPayload`): the last `CW_FILE_OP_JSON:…` line is returned from a nested `parts`/`state.output` envelope, even when it is not the last line of the payload.
- **Malformed payload mapping**: non-JSON or non-`Map` sentinel payloads map to `WorkspaceFileOperationCode.malformedResponse`; `_runMutation` also clears the capability cache on `malformedResponse` so the next mutation re-probes.
- **Shell quoting** (`shellQuoteForTest`): single quotes are escaped with `'\''`, spaces are preserved, and `_shQuote` is the only path used for interpolation in the generated scripts.
- **Capability probe + cache** (`getCapabilities`): the first call hits the shell exactly once; the second call with the same `serverScopeKey` and directory re-uses the cached result and does not hit the shell again. The deleted-session list confirms the ephemeral session is torn down on the same call.
- **Invalid leaf names fail before any shell call**: `..`, names containing `/` or `\`, and NUL/newline-bearing names all return `invalidName` with `shellCallCount == 0`.
- **Root directory is unsafe**: `getCapabilities(directory: '/')` returns `shellFileOpsSupported: false`; `createFile(rootDirectory: '/', …)` returns `outsideRoot` with `shellCallCount == 0`.
- **Probe fails closed on canonical root**: a non-literal directory that the server's `pwd -P` resolves to `/` causes `getCapabilities` to return `shellFileOpsSupported: false`; the captured probe command contains `pwd -P` and the `if [ "$root" = / ]` guard.
- **Mutation script rejects canonical root** for non-literal roots: when the capability probe succeeds but a subsequent mutation's parent canonicalizes to `/`, the script's `cw_fail outsideRoot` branch fires (`contains(r'if [ "$root" = "/" ]; then cw_fail outsideRoot; fi')`).
- **Create-file round-trip** (`createFile`): a successful run captures both the probe and the operation, returns the correctly joined target path, and embeds the `_shQuote`-escaped name (`CW_NAME='John'\''s notes.dart'`) on the wire.
- **Malformed probe disables shell file operations**: a `null` shell payload on the first `getCapabilities` call clears the capability cache and returns `shellFileOpsSupported: false`.
- **File-tree context menu widget coverage** (`test/widget/chat_page_test.dart`, including the right-click / mobile long-press read-only menu test, the four-mutation enablement test, and the create-file / create-folder / rename / delete flows via `FakeWorkspaceFileOperationsService`): the four mutation actions appear only when `shellFileOpsSupported == true`, `copyPath` and `refresh` remain available otherwise, the root "New" `PopupMenuButton` is hidden when the capability is missing, rename/delete reconcile path-keyed tab state and refresh the affected directory, and the destructive-action flag is set on the delete menu item.

> **Implementation behavior (not covered by the regression tests above, but still true per Decisions 1–11 above):** `_reloadFileTab` blocks silent reloads of tabs whose draft `isDirty` is true and stamps the draft with the static `saveErrorMessage = 'Unsaved changes; reload skipped.'` (not an ARB key); large files (> 1 MiB) force read-only via `_editorReadOnlyReason`; the editor enforces the `_maxEditableFileLength = 1024 * 1024` ceiling and an oversize **current draft** sets the static `saveErrorMessage = 'Draft is too large to save from the editor.'` (also not an ARB key) and blocks the save; `cw_decode_content` falls back from `base64` to `python3` when neither `base64` nor `base64 --decode` is on the host; the temp path is `tmpdir=$(mktemp -d "$parent/.cw-write.XXXXXX")` / `tmp="$tmpdir/content"`, the `mv -- "$tmp" "$target"` is preceded by `cw_copy_mode "$target" "$tmp"` to preserve mode bits, and cleanup runs `rm -f -- "$tmp"` followed by `rmdir -- "$tmpdir"` so a failed atomic rename does not leave the temp directory behind; targets that are missing/directories return `missing`/`notDirectory` from the shell-side checks; the focused editor's tab title carries the literal `*` dirty marker via the `file_viewer_tab_dirty_<path>` `ValueKey`; empty non-binary text files (`isBinary == false && content.isEmpty`) load as ready editor drafts; `_editorDraftForContent` schedules the controller's `replaceSavedContent` via `WidgetsBinding.instance.addPostFrameCallback` so the `CodeLineEditingController` is never mutated during build; the file-tree context menu exposes `copyPath` and `refresh` even when the shell probe is unavailable; the add-to-chat affordance for the open file reads the current draft text (when a draft is active) instead of the last-saved content.

### Key Files

- `lib/presentation/services/workspace_file_operations_service.dart` — operation interface/implementation, encoded static-program pipeline, per-server/directory capability + decoder negotiation, `parts[].state` sentinel parsing, path refusal, atomic sibling-temp writes, mode preservation, and cleanup
- `lib/presentation/services/chat_title_generator.dart` — `ephemeralSessionIds` set, `ephemeralSessionTitle` constant, 5-second delayed prune (reused from ADR-009; now also load-bearing for `writeFile`)
- `lib/presentation/pages/chat_page/chat_page_file_runtime.dart` — file-tree context menu actions (`_fileTreeActionsForNode`, `_handleFileTreeAction`, `_handleRootFileTreeAction`), root "New" menu plumbing, mutation dispatch, delete confirmation dialog, post-mutation reconciliation (`_reconcileRenamedFileTreePath`, `_reconcileDeletedFileTreePath`), focused-editor draft state machine (`_FileEditorDraftState`, `_saveFileEditorDraft`, `_fileMutationsSupported`), and the dirty-tab silent-reload guard in `_reloadFileTab` (which sets the static `saveErrorMessage = 'Unsaved changes; reload skipped.'` when a reload would clobber a dirty draft)
- `lib/presentation/pages/chat_page/chat_page_file_viewer.dart` — focused `CodeEditor`, 64 KiB UTF-8 edit/save boundary, read-only reason, dirty/saving state, inline error, and explicit `Save`
- `lib/presentation/pages/chat_page/chat_page_file_explorer_controller.dart` — root "New" `PopupMenuButton` with `file_tree_menu_new_file` / `file_tree_menu_new_folder` keys, `file_tree_refresh_button`
- `lib/presentation/widgets/file_tree_context_menu.dart` — `FileTreeContextMenuAction`, `FileTreeContextMenuActionType` enum, `fileTreeActionIcon`, destructive-action marker
- `lib/core/utils/path_utils.dart` — `normalizeFilePath`, `joinParentPath` (used by the service for path normalization)
- `lib/core/di/injection_container.dart` — DI wiring for `WorkspaceFileOperationsServiceImpl`
- `lib/l10n/app_en.arb` + locale ARBs — `filesNewFile`, `filesNewFolder`, `filesRename`, `filesDelete`, `filesDeleteTitle`, `filesDeleteConfirm`, `filesCopyPath`, `filesRefresh`, `filesOperationUnavailable` keys
- `test/unit/presentation/workspace_file_operations_service_test.dart` — static-pipeline transport, decoder negotiation/cache invalidation, 48 KiB chunk ordering, sentinel/error parsing, 64 KiB UTF-8 boundary, containment, and atomic-write/mode regression coverage
- `test/widget/chat_page_test.dart` — file-tree context menu wiring for create/rename/delete, root "New" menu visibility, destructive-action flag, `FakeWorkspaceFileOperationsService` plumbing (incl. `writeFile` / `writeFileCallCount` / `lastContent`), and the issue #90 focused-editor suite: `Ctrl+S` save success clears the dirty marker, button-driven save failure retains the dirty marker and renders an inline error via `_fileOperationErrorLabel`.
- Ref: issue #89, issue #90

---

## ADR-044: Windows STT Final Fix — Runner-Owned WASAPI Microphone Backend and Re-Enabled On-Device Engines (2026-07-03)

**Status**: Accepted

**Related**: ADR-006 (Speech Input Architecture with `SpeechInputService` and Platform Policy), ADR-023 (Official OpenCode contract-first compatibility), ADR-038 (Disable On-Device STT Engines on Windows — on-device path now restored), ADR-039 (Real Windows STT Fix — partial fix; actionable settings + typed preflight).

### Context

ADR-038 disabled the on-device STT engines on Windows because `record: ^6.0.0` → `record_windows: 1.0.7` hard-crashes the host with `EXCEPTION_ACCESS_VIOLATION_READ` in MediaFoundation (llfbandit/record#453). ADR-039 shipped a partial fix: actionable `ms-settings:` links, a typed microphone preflight over `codewalk/windows_microphone`, end-to-end `SpeechAudioCapture` lifecycle cleanup, and the architecture for a follow-up WASAPI capture backend. The follow-up has now landed: a runner-owned C++ plugin captures audio through WASAPI `IAudioClient` shared mode, never touches MediaFoundation or `record_windows`, and is compiled on `windows-latest` in CI. The `speech_to_text_windows` Native (UWP) engine is still the documented beta path and remains a native segfault surface, so it is now disabled alongside the on-device path in ADR-038 — but for a different reason.

### Decision

Finalize the Windows STT story:

1. **Runner-owned WASAPI microphone backend.** A new native C++ plugin — `codewalk/windows_microphone` MethodChannel + `codewalk/windows_microphone_stream` EventChannel — implements capture via WASAPI `IAudioClient` shared mode. The Windows voice path uses no MediaFoundation and does not instantiate `record_windows`. The plugin is built by Flutter's normal `windows/runner` CMake target and surfaces typed statuses (`allowed` / `denied` / `noInputDevice` / `deviceBusy` / `unsupportedFormat` / `unknown` / `notSupported`) plus a PCM stream the on-device engines consume through `SpeechAudioCapture`.
2. **Disable Native (UWP) on Windows.** `SpeechEnginePlatformSupport` reports `isNativeSupported` → `false` on Windows because `speech_to_text_windows` is still beta and can segfault during `initialize()` / `listen()`. The actionable settings card and typed preflight from ADR-039 remain and still route the user to the correct Windows settings page when the OS-side configuration blocks capture.
3. **Re-enable the on-device engines on Windows.** Sherpa, Moonshine, Parakeet, and SenseVoice report supported on Windows via the central platform support table. They consume `SpeechAudioCapture` (which routes through the WASAPI backend on Windows) and no longer touch `record_windows`.
4. **Migrate saved `Native` selections to Parakeet on Windows; preserve saved on-device selections.** `SettingsProvider.initialize()` migrates a saved `Native` value on Windows to Parakeet (the recommended Windows desktop default); saved on-device selections are left untouched. macOS / Linux / Android migration behavior is unchanged.
5. **Windows CI build validates the runner compile.** The `windows_build` job in `.github/workflows/ci.yml` runs on `windows-latest` and executes `flutter build windows --debug` so C++ runner regressions are caught before they reach users.
6. **Manual Windows microphone smoke remains required.** Automated CI cannot exercise physical microphone capture reliably. Hardware validation still requires a manual on-host smoke run on Windows desktop before end-to-end STT can be claimed for a given device/driver combination.

### Rationale

- WASAPI `IAudioClient` shared mode is the documented Windows capture path and is independent of MediaFoundation — the segment of `record_windows` that segfaults. Owning the plugin removes the dependence on a third-party platform channel whose stability is not guaranteed.
- Disabling Native on Windows mirrors the same reasoning as ADR-038 for the on-device engines: a native-side segfault cannot be caught from Dart, and `speech_to_text_windows` is still beta.
- Re-enabling only the on-device engines keeps the fix targeted — Sherpa / Moonshine / Parakeet / SenseVoice are all the WASAPI backend needs to support, the native plugin stays small, and the existing model / settings paths are untouched.
- Migrating saved `Native` selections to Parakeet gives returning Windows users the recommended desktop default without an extra prompt; preserving on-device selections avoids surprising users who already chose an on-device engine — Windows on-device engines were only disabled in ADR-038 because of `record_windows`, so a saved on-device value is still valid once the WASAPI backend is in place.
- A runner compile in CI catches breakage early without pretending physical capture is validated; the manual smoke caveat keeps the engineering team honest about what `windows-latest` confidence is and is not.

### Consequences

- ✅ Windows users can use the on-device STT engines (Sherpa / Moonshine / Parakeet / SenseVoice) again, with capture handled by the runner-owned WASAPI plugin. No `record_windows`, no `speech_to_text_windows`.
- ✅ The Native (UWP) engine is disabled on Windows to remove the remaining segfault surface; the typed preflight and actionable settings card from ADR-039 remain for OS-side misconfiguration.
- ✅ Existing Windows users with a saved `Native` selection are migrated to Parakeet on next launch; saved on-device selections are preserved unchanged.
- ✅ The `windows-latest` CI job compiles the runner, closing the "no Windows build feedback" gap that ADR-039 called out as the blocker.
- ✅ macOS, Linux, Android, and web behavior is unchanged; only Windows platform tables and settings migrations move.
- ⚠ Manual on-host microphone smoke is still required before claiming Windows hardware validation; CI compile + MethodChannel probe ≠ real capture on a specific audio device/driver.
- ⚠ Saved `Native` selections migrate to Parakeet (not user-choice) to keep the migration transparent; if Parakeet is unavailable because the model download fails, the user lands on the existing model-download dialog instead of an opaque broken state.
- ⚠ The WASAPI plugin ships shared-mode capture only; exclusive mode and loopback capture remain follow-ups if a future use case needs them.
- ❌ The Native (UWP) engine cannot be re-enabled on Windows without addressing the upstream `speech_to_text_windows` beta / COM / MediaFoundation crash surface; Native is intentionally disabled and Parakeet is the canonical Windows desktop default.
- ❌ macOS / Linux still rely on `record` for on-device engine capture; a WASAPI-style isolation on those platforms is out of scope for this ADR.

### Key Files

- `windows/runner/CMakeLists.txt` + new C++ plugin sources — runner-owned WASAPI `IAudioClient` shared-mode capture, `codewalk/windows_microphone` MethodChannel, `codewalk/windows_microphone_stream` EventChannel
- `lib/presentation/services/windows_microphone_service.dart` — typed probe + EventChannel bridge, now backed by real native code
- `lib/presentation/services/speech_audio_capture.dart` — engine-side abstraction consuming the WASAPI stream on Windows
- `lib/presentation/utils/speech_engine_platform_support.dart` — `isNativeSupported` → `false` on Windows; on-device engines re-enabled
- `lib/presentation/services/speech_input_service_{sherpa,moonshine,parakeet,sensevoice}_io.dart` — Windows engine paths no longer guarded off
- `lib/presentation/providers/settings_provider.dart` — Windows saved `Native` → `Parakeet` migration; on-device selections preserved
- `lib/presentation/pages/settings/sections/speech_settings_section.dart` — actionable Windows setup card copy adjusted for the new engine set
- `.github/workflows/ci.yml` — `windows_build` job compiles the Flutter Windows runner with the WASAPI plugin
- `BEHAVIOR.md` — Windows STT table updated for WASAPI-backed on-device engines and Native disabled on Windows
- `test/unit/presentation/speech_engine_platform_support_test.dart` — Native disabled + on-device enabled on Windows
- `test/unit/services/windows_microphone_service_test.dart` — typed status parsing against the real native bridge (path update)
- `test/unit/providers/settings_provider_test.dart` — Windows `Native` → `Parakeet` migration
- Ref: issue #43, llfbandit/record#453, https://learn.microsoft.com/en-us/windows/win32/coreaudio/wasapi

---

## ADR-045: CodeWalk Refined Visual Layer Over Material Stack (2026-07-07)

**Status**: Accepted

**Related**: ADR-007 (Modular Settings Architecture for `ExperienceSettings`), ADR-013 (MD3 WindowSizeClass Responsive Breakpoint Strategy), ADR-014 (Centralized MD3 Design Tokens for Shapes and Brand Colors), ADR-023 (Official OpenCode Contract-First Compatibility Policy), ADR-034 (Density-Aware Spacing Tokens via `AppDensitySpacing`). Ref: issue #86.

### Context

Issue #86 asks for a less default-Material visual revamp of CodeWalk. The current look and feel is unmistakably out-of-the-box Material 3: standard `Card`/`ListTile`/`AppBar` chrome, default filled/input chip elevations, and the conventional MD3 tonal surface treatment. Users perceive this as visually generic and want a more refined, opinionated look while still keeping CodeWalk a first-class citizen in the OpenCode ecosystem.

Three constraints define the design space:

1. **No iOS imitation.** The app must remain recognizably CodeWalk / Material-flavored. Adopting a Cupertino or iOS-style chrome would (a) break Material You expectations on Android, (b) conflict with the existing Material Symbols iconography (ADR-012), and (c) create inconsistent mobile/desktop look-and-feel. The refined look stays inside the Material 3 widget vocabulary.
2. **No third-party design-system package.** Pulling in `forui`, `mix`, `shadcn`, `fluentui`, `macos_ui`, or similar would (a) introduce a non-First-Party Flutter dependency for visual primitives, (b) create ongoing version-compat risk against Flutter/Material upgrades, (c) increase build size on mobile, and (d) leak a separate design vocabulary into surfaces that must remain consistent with the rest of the app.
3. **Preserve mobile / desktop / web / accessibility invariants.** RTL, focus traversal, keyboard shortcuts, dynamic color, AMOLED mode, density preference, Material Symbols icons, and the existing `OpenCodeThemeTokens` preset palette (the `OpenCode` brand theme + presets) must all continue to work. The refined layer is additive, not a replacement.

The Material You / MD3 stack (ADR-013, ADR-014, ADR-034) is already the canonical theme/token model. The refined layer must live on top of it without breaking its contract.

### Decision

Adopt a **refined visual layer** on top of the existing Flutter Material / Material 3 stack. New installations default to `refined`; `classic` remains available as a reversible user preference and as the compatibility fallback for legacy persisted payloads missing the `visualStyle` key.

1. **Persisted `VisualStyle` enum in `ExperienceSettings`** — add a `VisualStyle` enum (`classic` | `refined`) and persist it through `SettingsProvider` via the existing ADR-007 contract. New installs default to `refined` via `ExperienceSettings.defaults()`, while legacy persisted settings payloads missing `visualStyle` resolve to `classic` so existing users keep the prior look unless they opt in. The `OpenCodeThemeTokens` preset palette, dynamic color (`DynamicColorBuilder`), AMOLED mode, density (`AppDensity`), RTL, focus traversal, keyboard policy (ADR-024), and Material Symbols icons (ADR-012) are all preserved unchanged.

2. **`AppVisualStyleTokens` ThemeExtension** — introduce a new `ThemeExtension<AppVisualStyleTokens>` class that carries refined-only visual adjustments: surface tonal steps (card, panel, composer, muted-control, selected), hairline divider and border widths, refined corner radii (a separate scale, distinct from `AppShapes`), refined shadow tokens, and separator/tint colors. The extension is registered on the `ThemeData` produced by `AppTheme.lightFrom(...)` and `AppTheme.darkFrom(...)` for both styles; `classic` resolves to its baseline values (so today’s look is unchanged when `VisualStyle.classic` is active) and `refined` resolves to the refined scale. The extension exposes an `isRefined` flag so widgets can branch on the resolved style without re-reading the persisted setting, and provides refined-only surface/radius/border-width/shadow/separator-tint paths that call sites opt into while Classic fallbacks remain the default.

3. **`AppTheme.lightFrom` / `AppTheme.darkFrom` dispatch on optional `visualStyle`** — `AppTheme.lightFrom(...)` and `AppTheme.darkFrom(...)` accept an optional `VisualStyle` parameter (defaulting to `classic`) and resolve the same Material 3 color scheme, typography, and `AppDensity` inputs for both styles; only the refined constants (radii, shadows, hairline weights, tonal offsets) diverge. Both factories delegate to a private `_buildTheme(...)` helper that owns the shared resolution logic and registers `AppVisualStyleTokens` on the produced `ThemeData`. The result is two `ThemeData` flavors built from the same source-of-truth tokens, with the switch happening once per factory call instead of being scattered across widgets. A `withResponsiveSnackBars(theme)` helper layers tokenized snack-bar treatment on top of the resolved `ThemeData` when `theme.visualStyleTokens.isRefined` is true, so snackbars join the refined token path in this pass.

4. **Scoped migration of high-visibility surfaces** — the refined layer is rolled out incrementally across the highest-visibility surfaces first, then lower-priority ones in follow-ups: composer (`chat_input_widget.dart`), chat message bubbles (`chat_message_widget.dart` / `chat_message_content.dart`), the chat page scaffold / status / timeline / composer regions, and the session list (`chat_session_list.dart`). High-impact widgets consume `Theme.of(context).visualStyleTokens` and branch on `visualTokens.isRefined` to take refined-only surface / radius / border-width / shadow / separator-tint paths while preserving the existing Classic fallbacks; the dispatch is therefore not a single chokepoint but a deliberate per-widget opt-in over a shared token source. The visual section in `appearance_settings_section.dart` exposes the `VisualStyle` selector as a Material 3 `SegmentedButton` (no live preview); the choice is discoverable, reversible without restart, and rendered alongside the existing density / dynamic-color / AMOLED / theme-preset controls.

5. **`main.dart` wires the persisted style at startup** — `MyApp` reads the persisted `VisualStyle` from `SettingsProvider` on first frame and passes it into `AppTheme.lightFrom(...)` / `AppTheme.darkFrom(...)`. Theme rebuilds on style change are scoped through `SettingsProvider` listener so a settings change propagates without losing transient UI state.

6. **`OpenCodeThemeTokens` preset palette stays authoritative** — the `OpenCode` brand theme and the other official theme presets remain the canonical color source for both `classic` and `refined`. Dynamic color (`DynamicColorBuilder`, `SettingsProvider.dynamicColorAvailable`) continues to override the seed when available; AMOLED continues to apply on top of either style. The refined layer only modulates surface treatment, radii, shadows, and tonal offsets — it does not invent new color seeds.

### Rationale

- **Lower-risk incremental layer over existing architecture.** Material 3 widgets are kept; no widgets are replaced, no third-party design system is adopted, and the existing `AppShapes` / `AppDensitySpacing` / `OpenCodeThemeTokens` contracts are preserved. The refined look is an additive `ThemeExtension`, so most surfaces opt in by reading the extension while the rest of the widget tree keeps working unchanged.
- **Reversible rollout.** Because the choice is persisted in `ExperienceSettings`, the refined layer can be rolled back by switching the new-install default back to `classic` while preserving user-selected values and the existing legacy missing-key fallback. No destructive migration, no API contract change, no schema migration beyond the new `VisualStyle` field.
- **Preserves official OpenCode compatibility.** The visual layer does not touch server contracts, model payloads, message lifecycle, or any behavior governed by ADR-023. The `OpenCodeThemeTokens` preset palette continues to be the brand source; refined is a presentation-only layering on top of it.
- **`ThemeExtension` is the canonical Flutter mechanism.** Adding an extension is the standard way to carry design tokens that vary by theme without forking `ThemeData`. It composes cleanly with `MaterialApp.theme` / `darkTheme`, density (ADR-034), and dynamic color, and it is tree-shakable: widgets that don’t read it pay zero cost.
- **Shared resolution in `_buildTheme`, per-widget opt-in elsewhere.** `AppTheme.lightFrom` / `AppTheme.darkFrom` / `_buildTheme` own the per-call dispatch (color scheme, typography, density, registered extension) so the Material 3 inputs and refined offsets stay co-located; high-impact widgets read the same `Theme.of(context).visualStyleTokens` they already use and branch on `visualTokens.isRefined` for refined-only color / radius / shadow paths, with Classic fallbacks preserved. This keeps the resolution path single-sourced while letting each surface choose its level of refinement.
- **Discoverable, non-disruptive UX.** The `VisualStyle` selector is exposed in the existing appearance settings section as a Material 3 `SegmentedButton` (no live preview) next to the other visual preferences (density, dynamic color, AMOLED, theme preset). The choice is committed immediately, is reversible, and does not require a restart.

### Consequences

- ✅ CodeWalk gains a more opinionated, less default-Material visual identity without leaving the Material 3 widget vocabulary.
- ✅ New installs default to `refined`; Classic remains available and legacy missing-key payloads keep Classic for compatibility; the choice is reversible per user without restart.
- ✅ `OpenCodeThemeTokens`, dynamic color, AMOLED, density, RTL, focus, keyboard policy, and Material Symbols icons all continue to work unchanged.
- ✅ `ThemeExtension` keeps the refined tokens tree-shakable, type-safe, and composable with the existing Material 3 theme.
- ✅ Shared `_buildTheme` resolution keeps the Material 3 inputs and refined offsets co-located; high-impact widgets opt into refined paths by reading `Theme.of(context).visualStyleTokens` and branching on `visualTokens.isRefined`, with Classic fallbacks preserved.
- ✅ Migration is incremental — high-visibility surfaces first, lower-priority surfaces follow behind the same `VisualStyle` switch; snackbars are tokenized via `withResponsiveSnackBars` when refined is active.
- ⚠ The refined layer is constrained by what Material 3 widgets can express. Component-level customization beyond what `ThemeData` / `ThemeExtension` / widget builders expose requires either wrapped widgets or follow-up work.
- ⚠ Future broader component / library work (e.g. custom scrollbars, custom navigation rails) remains a separate decision behind its own ADR — the refined layer is intentionally visual-only in this pass.
- ⚠ Lower-priority surfaces (settings sub-pages, dialogs, tooltips) keep the classic treatment in this pass and can be migrated later behind the same `VisualStyle` switch.
- ⚠ The visual section in `appearance_settings_section.dart` gains an extra `SegmentedButton` selector; the section's existing density / dynamic-color / AMOLED controls must stay coherent with the new selector.
- ❌ No third-party design-system package is added (`forui`, `mix`, `shadcn`, `fluentui`, `macos_ui`, or similar are intentionally rejected).
- ❌ No global `AppShapes` change — `AppShapes` remains the canonical shape scale; refined radii live in the new `AppVisualStyleTokens` extension.
- ❌ No icon replacement — Material Symbols (ADR-012) remain the only icon vocabulary for both styles.
- ❌ No blur / vibrancy / glass effects in this pass — refined stays within MD3 surface tonal vocabulary.
- ❌ No JSON user-supplied theme system in this pass — preset selection continues to use the existing `OpenCodeThemeTokens` palette; user themes are a follow-up behind their own ADR.

### ADR-023 Compatibility

This ADR is fully compliant with ADR-023. It introduces no OpenCode server contract change, no new endpoints, no modification to existing request/response schemas, and no change to message lifecycle, realtime event semantics, or model/agent/provider resolution. The refined layer is a presentation-only change: `VisualStyle` lives in `ExperienceSettings`, the visual tokens live in a Flutter `ThemeExtension`, and the theme is built once per `AppTheme.lightFrom` / `AppTheme.darkFrom` call (via the shared `_buildTheme` helper). Server-authoritative behavior and the official OpenCode client contract are untouched.

### Key Files

- `lib/domain/entities/experience_settings.dart` — `VisualStyle` enum (`classic` | `refined`) with `refined` as the new-install default and `classic` as the legacy missing-key fallback; persistence field
- `lib/presentation/providers/settings_provider.dart` — `VisualStyle` getter / setter; persistence migration; listener-driven theme rebuild hook
- `lib/presentation/theme/app_theme.dart` — `AppTheme.lightFrom(...)` / `AppTheme.darkFrom(...)` accept an optional `VisualStyle` (default `classic`); private `_buildTheme(...)` owns shared resolution and registers `AppVisualStyleTokens` on both light and dark `ThemeData`; `withResponsiveSnackBars(theme)` layers tokenized snack-bar treatment when `theme.visualStyleTokens.isRefined`
- `lib/presentation/theme/app_visual_style_tokens.dart` — new `ThemeExtension<AppVisualStyleTokens>` carrying refined surface tonal steps, hairline divider and border widths, refined radii, shadow tokens, and separator/tint colors; baseline values for `classic`, refined values for `refined`; exposes `isRefined` so widgets can branch on the resolved style
- `lib/presentation/pages/settings/sections/appearance_settings_section.dart` — `VisualStyle` `SegmentedButton` selector (no live preview); placement next to density / dynamic-color / AMOLED / theme-preset controls
- `lib/main.dart` — reads persisted `VisualStyle` from `SettingsProvider` and passes it into `AppTheme.lightFrom` / `AppTheme.darkFrom`; `MaterialApp.theme` rebuild on style change
- `lib/presentation/widgets/chat_input_widget.dart` — consumes `Theme.of(context).visualStyleTokens`, branches on `isRefined` for refined composer color / radius / hairline-border / tonal-offset paths while preserving Classic fallbacks
- `lib/presentation/widgets/chat_message/chat_message_content.dart` — refined bubble / block surface treatment (token-driven, with Classic fallback)
- `lib/presentation/widgets/chat_message_widget.dart` — refined message shell (token-driven, with Classic fallback)
- `lib/presentation/pages/chat_page.dart` (import owner) + `chat_page_scaffold.dart` + `chat_page_status_presenter.dart` + `chat_page_timeline_runtime.dart` + `chat_page_composer_widgets.dart` + composer parts — refined scaffold / status / timeline / composer region treatment (token-driven, with Classic fallback)
- `lib/presentation/widgets/chat_session_list.dart` — refined sidebar list treatment (token-driven, with Classic fallback)
- `test/unit/domain/experience_settings_test.dart` — `VisualStyle` default and serialization coverage
- `test/unit/providers/settings_provider_test.dart` — `VisualStyle` getter / setter and persistence migration coverage
- `test/unit/presentation/app_theme_test.dart` — `AppTheme.lightFrom` / `AppTheme.darkFrom` / `_buildTheme` dispatch and `AppVisualStyleTokens` registration coverage (including `withResponsiveSnackBars` Refined tokenization)
- `test/widget/settings_page_test.dart` — `VisualStyle` selector presence and persistence wiring in the appearance settings section
- `test/widget/chat_message_widget_test.dart`, `test/widget/chat_page_test.dart` — run as regression suites over the migrated widget paths; no new explicit refined assertions were added in this pass
- Ref: issue #86

---

## ADR-046: Client-Side Cloud TTS Provider Architecture (2026-07-08) ⚠️ SUPERSEDED by ADR-047

**Status**: Superseded

**Related**: ADR-006 (Speech Input Architecture with `SpeechInputService` and Platform Policy), ADR-007 (Modular Settings Architecture for `ExperienceSettings`), ADR-023 (Official OpenCode Contract-First Compatibility Policy).

**Superseded by**: ADR-047 (Experimental Direct Microsoft Edge/Bing Read Aloud TTS via Client WebSocket), which replaces the ADR-046 decision to block direct Microsoft Edge Read Aloud synthesis.

### Context

CodeWalk already exposes native read-aloud TTS for assistant messages, but users also need higher-quality generated voices from cloud providers. The implementation must preserve the native engine as the safe default, avoid storing provider secrets in normal settings payloads, and remain compatible with the official OpenCode client/server contract.

Cloud TTS introduces a different playback shape from native TTS: providers return generated audio bytes instead of driving the platform TTS engine directly. It also introduces privacy and reliability constraints because selected assistant text leaves the device and is sent to a configured third-party provider.

Microsoft Edge Speech is attractive as an experimental voice catalog, but the direct Edge Read Aloud synthesis path depends on an unofficial WebSocket transport with unstable Edge-specific headers and tokens. Shipping direct synthesis against that protocol would create a brittle dependency on a private browser transport rather than a stable provider API.

### Decision

Adopt a **client-side pluggable TTS backend architecture** for read-aloud, with native TTS remaining the default provider and cloud providers implemented as optional client-owned backends.

1. **Native read-aloud remains default.** `ReadAloudProvider.native` stays the default persisted provider in `ExperienceSettings`, so new and existing users keep platform-native TTS unless they explicitly choose another provider.
2. **Pluggable `TtsBackend` contract.** `ReadAloudService` routes read-aloud through provider-specific `TtsBackend` implementations. Backends declare whether they use the native engine or generated-audio playback through `TtsPlaybackMode`, allowing a single service to manage both `flutter_tts` lifecycle and generated audio playback.
3. **OpenAI-compatible cloud TTS.** The first active cloud backend is `ReadAloudProvider.openAiCompatible`, which sends sanitized assistant text to the configured OpenAI-compatible `/v1/audio/speech` endpoint, maps read-aloud rate to provider speed, receives generated audio bytes, and plays them through the generated-audio player path.
4. **Secrets only in secure storage.** OpenAI-compatible TTS API keys are stored only via `lib/core/auth/tts_api_key_storage.dart`, backed by `flutter_secure_storage` and namespaced by provider. API keys must not be serialized into `ExperienceSettings`, logs, normal preference payloads, or exported non-secret settings.
5. **Non-secret settings in `ExperienceSettings`.** Provider choice, voice ID/locale, model, base URL, response format, rate, pitch, and enablement remain ordinary non-secret read-aloud settings in `ExperienceSettings` so they can participate in the existing ADR-007 settings lifecycle.
6. **Sanitized assistant text boundary.** Cloud read-aloud uses `ReadAloudTextExtractor` to derive the spoken text from assistant message parts before sending it to a third-party provider, stripping markdown/code/table noise that is not useful speech content.
7. **Microsoft Edge Speech is experimental but blocked for direct synthesis.** `ReadAloudProvider.edgeExperimental` may expose voice-list discovery and settings UI as experimental, but direct synthesis is intentionally blocked in this build because the unofficial Edge Read Aloud WebSocket transport requires unstable headers/tokens. Users who need Edge-backed voices must use a stable OpenAI-compatible Edge proxy or choose another provider.

### Rationale

- Keeping native TTS as the default preserves offline/local behavior, platform accessibility expectations, and the least-surprise path for users who do not configure cloud credentials.
- A provider backend contract keeps the read-aloud UI and message controls independent from provider transport details, making future providers additive instead of special-cased in widgets.
- Generated-audio playback must be first-class because OpenAI-compatible `/v1/audio/speech` returns bytes, not a platform TTS session that can be paused/stopped through `flutter_tts`.
- Secure storage is the only acceptable location for provider API keys; `ExperienceSettings` is deliberately limited to non-secret provider configuration.
- Blocking direct Edge synthesis avoids shipping a feature that depends on a private, unstable browser protocol and could break without notice or require hardcoded transport tokens.
- The client-owned path keeps the OpenCode server out of user-selected third-party TTS traffic and avoids introducing a proxy responsibility the server contract does not define.

### Consequences

- ✅ Users keep native read-aloud by default while gaining an opt-in cloud TTS architecture.
- ✅ OpenAI-compatible providers can synthesize assistant-message audio through `/v1/audio/speech` without changing chat/session/model APIs.
- ✅ API keys remain outside `ExperienceSettings` and normal preference payloads, reducing accidental secret exposure.
- ✅ Provider settings are still durable and user-configurable through the existing settings architecture.
- ✅ Generated-audio playback supports byte-based provider responses with progress/completion handling separate from native TTS callbacks.
- ✅ Edge Speech can be explored safely as an experimental catalog/provider placeholder without relying on direct private WebSocket synthesis.
- ⚠ Cloud TTS sends sanitized assistant text from the client device to the configured third-party provider; users must understand the provider's privacy, retention, billing, and regional processing policies.
- ⚠ Provider availability, quota, latency, rate limits, response formats, and voice/model compatibility vary by provider and are surfaced as provider-specific errors.
- ⚠ Secure storage availability is platform-dependent; if secure storage fails, cloud TTS credentials cannot be read or written and the provider must fail closed.
- ⚠ Base URL configurability is powerful but risky: users can point the client at proxies or non-OpenAI-compatible services that may reject requests or mishandle data.
- ❌ CodeWalk does not proxy cloud TTS through the OpenCode server and does not store TTS API keys server-side.
- ❌ Direct Microsoft Edge Read Aloud WebSocket synthesis is intentionally not supported in this build.

### Risks and Mitigations

- **Third-party data exposure**: assistant text leaves the device for cloud TTS. Mitigation: make cloud TTS opt-in, keep native as default, show cloud TTS privacy copy in settings, and send only sanitized assistant text.
- **Credential leakage**: API keys could be accidentally serialized if future code treats them like normal settings. Mitigation: centralize key persistence in `TtsApiKeyStorage` and keep `ExperienceSettings` limited to non-secret fields.
- **Provider drift**: OpenAI-compatible providers may diverge in model, voice, format, or error semantics. Mitigation: keep the backend isolated, normalize known error categories, and avoid assuming provider-specific features outside the `/v1/audio/speech` contract.
- **Unstable Edge transport**: direct Edge synthesis depends on unofficial headers/tokens. Mitigation: block direct synthesis until a stable supported transport or proxy contract exists.

### ADR-023 Compatibility

This ADR is fully compliant with ADR-023. It introduces no OpenCode server contract change, no new OpenCode endpoints, no modification to existing OpenCode request/response schemas, and no change to message lifecycle, realtime event semantics, model/agent/provider resolution, or config mutation behavior.

Cloud TTS is a client-owned read-aloud feature: CodeWalk extracts sanitized assistant text from already-received message content and sends it directly from the client to the user-configured third-party TTS provider. The OpenCode server is not involved in synthesis, credential storage, provider routing, or generated-audio playback.

### Key Files

- `lib/domain/entities/experience_settings.dart` — `ReadAloudProvider` enum, native default, non-secret read-aloud provider/model/base URL/voice/format/rate/pitch persistence, and OpenAI-compatible defaults.
- `lib/core/auth/tts_api_key_storage.dart` — provider-namespaced secure storage for TTS API keys; the only accepted persistence path for cloud TTS secrets.
- `lib/presentation/services/read_aloud_service.dart` — provider routing, native/generated-audio playback state, secure API-key lookup, generated-audio lifecycle, and normalized read-aloud errors.
- `lib/presentation/services/tts/tts_backend.dart` — backend abstraction, playback modes, synthesis request/result model, voice options, callbacks, and provider error categories.
- `lib/presentation/services/tts/native_tts_backend.dart` — native `flutter_tts` backend and default local read-aloud path.
- `lib/presentation/services/tts/openai_compatible_tts_backend.dart` — OpenAI-compatible `/v1/audio/speech` request/response handling, voice defaults, generated-audio bytes, MIME mapping, and provider error mapping.
- `lib/presentation/services/tts/generated_tts_audio_player.dart` — byte-based generated-audio playback bridge over `audioplayers`.
- `lib/presentation/services/tts/edge_experimental_tts_backend.dart` — experimental Edge voice discovery with direct synthesis blocked because the unofficial transport is unstable.
- `lib/presentation/services/tts/read_aloud_text_extractor.dart` — assistant-message text extraction and markdown cleanup before cloud synthesis.
- `lib/presentation/pages/settings/sections/speech_settings_section.dart` — read-aloud provider selection, cloud TTS privacy copy, non-secret provider settings UI, and secure API-key entry flow.
- `lib/core/di/injection_container.dart` — registration of read-aloud backends and `TtsApiKeyStorage`.
- `lib/presentation/widgets/chat_message_widget.dart` — assistant-message read-aloud controls using sanitized text extraction and provider settings.
- `test/unit/auth/tts_api_key_storage_test.dart`, `test/unit/services/openai_compatible_tts_backend_test.dart`, `test/unit/services/edge_experimental_tts_backend_test.dart` — secure storage, OpenAI-compatible backend, and Edge experimental behavior coverage.

---

## ADR-047: Experimental Direct Microsoft Edge/Bing Read Aloud TTS via Client WebSocket (2026-07-08)

**Status**: Accepted

**Related**: ADR-006 (Speech Input Architecture with `SpeechInputService` and Platform Policy), ADR-007 (Modular Settings Architecture for `ExperienceSettings`), ADR-023 (Official OpenCode Contract-First Compatibility Policy), ADR-046 (superseded Edge direct-synthesis block), ADR-048 (adaptive first-run read-aloud defaults).

### Context

ADR-046 introduced the client-side cloud TTS architecture but intentionally blocked direct Microsoft Edge Read Aloud synthesis because it depended on an unofficial private WebSocket protocol. The new user requirement and implementation accept that risk for an explicitly experimental provider so CodeWalk can offer direct Microsoft Edge/Bing Read Aloud voices without an API key.

The feature must remain client-owned, and persisted user choice must remain authoritative once settings exist. ADR-048 narrows the first-run default rule: existing `ExperienceSettings` are never overwritten, while fresh installs may select Edge automatically when native TTS is unavailable or platform policy requires it. OpenAI-compatible TTS keeps its existing `/v1/audio/speech` behavior and secure API-key storage boundary, and ADR-023 compatibility must be preserved by avoiding any OpenCode server contract change.

Direct Edge/Bing synthesis sends sanitized assistant message text from the CodeWalk client to Microsoft. The implementation therefore needs a strict privacy boundary, no silent fallback to another provider, visible failure behavior, payload limits, and an easy rollback path if the private protocol changes or becomes unacceptable.

### Decision

Supersede ADR-046's direct Edge synthesis block and support **direct Microsoft Edge/Bing Read Aloud TTS experimentally** through a client-side WebSocket implementation that follows LobeHub/edge-tts protocol details.

1. **Adaptive first-run provider boundary.** Persisted `ExperienceSettings` remain authoritative and are never overwritten. For fresh installs, ADR-048 controls provider selection: native TTS is preferred when a runtime availability probe succeeds, while Linux and native-unavailable fresh installs may start on `ReadAloudProvider.edgeExperimental`.
2. **Edge remains experimental.** `ReadAloudProvider.edgeExperimental` is exposed as an experimental provider with settings copy that explains the unofficial private protocol, possible breakage/rate limits, and that message text is sent to Microsoft. Edge may be selected manually or by the ADR-048 first-run resolver only when no persisted settings exist.
3. **No silent fallback.** If Edge voice discovery, WebSocket connection, synthesis, parsing, rate limits, or playback fail, CodeWalk reports a visible read-aloud error and does not silently switch to native TTS or OpenAI-compatible TTS. Users must manually choose another provider.
4. **OpenAI-compatible provider unchanged.** The OpenAI-compatible backend continues to use the configured `/v1/audio/speech` endpoint and provider API key. API keys remain stored only through `TtsApiKeyStorage`/secure storage and must not enter `ExperienceSettings`, logs, normal preference payloads, or exported settings.
5. **Client-side Edge protocol boundary.** Edge/Bing synthesis is implemented in `edge_tts_protocol.dart` and `edge_tts_websocket.dart` using conditional imports. Native IO platforms perform a manual `HttpClient` WebSocket upgrade with Edge-style headers and edge-tts/LobeHub-compatible request/response framing. Web builds use a generic connector/stub boundary for build compatibility rather than introducing `dart:io` dependencies.
6. **Voice selection.** Settings expose an Edge voice picker populated from Microsoft Edge/Bing voices when discovery succeeds. The default Edge voice is `en-US-EmmaMultilingualNeural`.
7. **Payload limit and sanitization.** Edge synthesis sends only sanitized assistant text produced by the existing read-aloud text extractor, capped to 4096 bytes before transport. Tool metadata, hidden state, logs, credentials, and raw message internals are not sent.
8. **No server proxy or OpenCode contract change.** Edge/Bing Read Aloud traffic goes directly from the CodeWalk client to Microsoft. The OpenCode server is not involved in provider routing, synthesis, credential storage, request signing, or playback.
9. **Client-owned playback lifecycle and control state.** `ReadAloudService` exposes a preparation/loading state before actual playback starts, and chat message controls render that state as a loading indicator while synthesis or native preparation is in progress. App/window lifecycle transitions away from `resumed` do not automatically stop read-aloud playback; playback continues when the user switches windows/apps unless it is explicitly stopped by the user, a session/message change, or another read-aloud action. Long-pressing the read-aloud control opens `Settings > Speech` so provider, voice, and privacy settings remain discoverable from the control itself.

### Rationale

- The new product requirement values direct access to Microsoft Edge/Bing Read Aloud voices enough to accept private-protocol risk when the provider is clearly labeled experimental and automatic selection is limited to fresh-install/native-unavailable cases.
- Preferring native TTS whenever it is available preserves offline/local behavior and avoids surprising users with third-party data transfer on platforms with a working native engine.
- A client-side WebSocket implementation preserves ADR-023 because it does not require new OpenCode endpoints, schemas, proxy behavior, or server-side credential handling.
- No silent fallback keeps provider choice honest: if the user selected Edge, failures must be visible rather than quietly reading through another provider with different privacy and voice behavior.
- Conditional imports isolate platform-specific WebSocket mechanics and keep web/build targets compatible even when direct Edge synthesis is primarily an IO-platform capability.
- The 4096-byte cap reduces private-protocol fragility, bounds third-party data exposure, and prevents oversized synthesis payloads from entering the Edge transport.
- Keeping playback alive across app/window focus changes matches the user expectation that read-aloud behaves like media playback, while explicit stop paths preserve user/session/message ownership over when speech ends.
- A distinct preparation/loading state prevents ambiguous idle-looking controls during provider synthesis, native engine startup, or generated-audio buffering.

### Consequences

- ✅ Users can opt into direct Microsoft Edge/Bing Read Aloud voices without configuring an API key.
- ✅ Native read-aloud remains the safe preferred provider and manual rollback target on platforms with runtime native TTS availability; ADR-048 defines the Linux/native-unavailable fresh-install exceptions.
- ✅ OpenAI-compatible TTS behavior and secure API-key storage remain unchanged.
- ✅ ADR-023 compatibility is preserved: no OpenCode server endpoint, schema, lifecycle, event, model, agent, or config-contract changes.
- ✅ Edge voice selection is user-visible through an explicit picker, with `en-US-EmmaMultilingualNeural` as the default.
- ✅ Read-aloud playback continues across app/window switches unless explicitly stopped by user, session, or message actions.
- ✅ Message controls can show a loading indicator while speech is being prepared, and long-press gives a direct path to `Settings > Speech`.
- ⚠ Sanitized assistant text is sent directly from the client to Microsoft when Edge is selected; Microsoft's privacy, retention, region, quota, and availability policies apply outside CodeWalk's control.
- ⚠ The Edge/Bing Read Aloud WebSocket protocol is unofficial and private; headers, tokens, message framing, rate limits, or availability may change without notice.
- ⚠ Web support is a build-compatible generic connector boundary, not a guarantee that browser synthesis will work the same as native IO platforms.
- ⚠ Lifecycle changes must not become an implicit stop path again; any future automatic stop must be tied to explicit user/session/message ownership, not app focus alone.
- ❌ Edge/Bing Read Aloud is not a stable supported provider contract and must not be treated as reliable infrastructure.
- ❌ CodeWalk must not silently fall back from Edge to native or OpenAI-compatible TTS on provider failure.

### Risks and Mitigations

- **Private protocol drift**: Microsoft may change Edge/Bing headers, tokens, frame formats, voice endpoints, or throttling. Mitigation: isolate all protocol details in `edge_tts_protocol.dart` and `edge_tts_websocket.dart`, keep the provider labeled experimental, surface visible errors, and allow users to switch back to native TTS.
- **Third-party data exposure**: assistant text leaves the device for Microsoft when Edge is selected. Mitigation: limit automatic Edge selection to fresh installs with no persisted settings, show explicit privacy warning copy, send only sanitized assistant text, cap payloads at 4096 bytes, and exclude tool metadata, hidden state, logs, and credentials.
- **Silent provider mismatch**: automatic fallback could read private content through an unintended provider or confuse voice/privacy expectations. Mitigation: fail closed with a visible read-aloud error; fallback requires explicit user action in settings.
- **Platform transport variance**: IO and web WebSocket capabilities differ. Mitigation: use conditional imports, keep the IO manual upgrade isolated, keep the web connector build-compatible, and surface unsupported/runtime failures without changing provider selection.
- **Credential regression**: future changes might accidentally treat cloud provider secrets as normal settings. Mitigation: Edge uses no API key; OpenAI-compatible keys remain restricted to `TtsApiKeyStorage`/secure storage only.

### Rollback / Feature-Flag Plan

- **Immediate user rollback**: switch `Settings > Speech > Text-to-Speech provider` back to `System / Native` or `OpenAI-compatible`. Edge failures never trigger automatic fallback.
- **Product rollback**: hide or disable `ReadAloudProvider.edgeExperimental`, remove its backend registration, and restore a native-preferred resolver where runtime native TTS is available. Existing Edge selections should be treated as unavailable and prompt the user to choose another provider, preferably native; Linux/native-unavailable fresh installs should prompt instead of silently choosing Edge.
- **Protocol rollback**: leave OpenAI-compatible and native backends intact, remove or disable only the Edge WebSocket/voice-discovery path, and keep secure TTS API-key storage untouched.
- **No data migration required**: Edge stores only non-secret provider/voice preferences. OpenAI-compatible API keys remain in secure storage and are unaffected by Edge rollback.

### ADR-023 Compatibility

This ADR is compliant with ADR-023. CodeWalk still consumes OpenCode as an official client: no OpenCode server endpoint is added, no request/response schema changes, no realtime event semantics change, no session/message/model/agent lifecycle changes, and no server-side provider routing or proxying is introduced. The read-aloud loading state, app/window lifecycle playback continuity, message-control loading indicator, and long-press settings shortcut are purely client-side UI/service behavior.

Edge/Bing Read Aloud is a client-owned read-aloud feature. CodeWalk extracts sanitized text from already-received assistant message content and sends it directly from the client to Microsoft only when the experimental Edge provider is selected by the user or by the ADR-048 first-run resolver.

### Key Files

- `lib/presentation/services/tts/edge_experimental_tts_backend.dart` — experimental Edge provider backend, voice discovery, synthesis dispatch, no-silent-fallback error behavior.
- `lib/presentation/services/tts/edge_tts_protocol.dart` — Edge/Bing Read Aloud protocol framing, parsing, defaults, and payload-limit handling.
- `lib/presentation/services/tts/edge_tts_websocket.dart` — conditional WebSocket connector export boundary.
- `lib/presentation/services/tts/edge_tts_websocket_io.dart` — IO manual `HttpClient` WebSocket upgrade with Edge-style headers.
- `lib/presentation/services/tts/edge_tts_websocket_stub.dart` — web/build-compatible connector boundary.
- `lib/presentation/services/tts/read_aloud_text_extractor.dart` — sanitized assistant text extraction before cloud/Edge synthesis.
- `lib/presentation/pages/settings/sections/speech_settings_section.dart` — Edge provider warning, Edge voice picker, cloud privacy copy, and provider selection UI.
- `lib/presentation/pages/chat_page/chat_page_lifecycle.dart` — app/window lifecycle handling that does not stop read-aloud playback merely because the app leaves `resumed`.
- `lib/presentation/services/read_aloud_service.dart` — read-aloud playback orchestration, explicit stop ownership, and preparation/loading state before actual playback.
- `lib/presentation/widgets/chat_message_widget.dart` — message read-aloud control loading indicator and long-press shortcut to `Settings > Speech`.
- `lib/domain/entities/experience_settings.dart` — persists non-secret read-aloud provider/voice preferences only; adaptive resolution belongs to ADR-048 and `read_aloud_default_resolver.dart`.
- `lib/core/auth/tts_api_key_storage.dart` — unchanged secure-storage-only boundary for OpenAI-compatible API keys.
- `lib/core/di/injection_container.dart` — read-aloud backend registration including `ReadAloudProvider.edgeExperimental`.

---

## ADR-048: Adaptive First-Run Read-Aloud TTS Defaults (2026-07-08)

**Status**: Accepted

**Related**: ADR-007 (Modular Settings Architecture for `ExperienceSettings`), ADR-023 (Official OpenCode Contract-First Compatibility Policy), ADR-047 (Experimental Direct Microsoft Edge/Bing Read Aloud TTS via Client WebSocket).

### Context

CodeWalk now supports multiple read-aloud providers, including native platform TTS and the experimental direct Microsoft Edge/Bing Read Aloud backend. The previous ADR-047 wording treated native TTS as the universal default and stated that Edge is never enabled automatically, but the current implementation needs first-run defaults that avoid a broken read-aloud experience on platforms where native TTS is unavailable.

Existing persisted `ExperienceSettings` must never be overwritten. Fresh installs are detected only when `getExperienceSettingsJson()` is missing or blank. Linux fresh installs require a non-native default because `flutter_tts` native TTS is unavailable on Linux. Windows, macOS, and other supported platforms should still prefer native TTS when it is actually available at runtime.

Edge remains experimental, depends on a private/unofficial protocol, and sends sanitized assistant text to Microsoft only when Edge is the selected read-aloud provider. This defaulting behavior is client-owned and must not change any OpenCode server contract, endpoint, schema, event, provider/model contract, or ADR-023 behavior.

### Decision

Adopt an **adaptive first-run read-aloud provider resolver** while preserving persisted settings as authoritative user state.

1. **Never overwrite persisted settings.** If `getExperienceSettingsJson()` returns a non-blank payload, CodeWalk keeps the stored `ExperienceSettings` values, including read-aloud provider, voice, locale, rate, pitch, and related non-secret provider preferences.
2. **Fresh install detection.** Adaptive defaults run only when `getExperienceSettingsJson()` is missing or blank. Reinstalls, migrations, and existing profiles with persisted settings must not be re-defaulted.
3. **Linux fresh-install default.** Linux fresh installs choose `ReadAloudProvider.edgeExperimental` because `flutter_tts` native TTS is unavailable on Linux.
4. **Native-preferred runtime probe elsewhere.** Windows, macOS, and other supported platforms prefer `ReadAloudProvider.native` only when a runtime native availability probe succeeds. If native TTS is unavailable, fresh installs fall back to `ReadAloudProvider.edgeExperimental`.
5. **Locale-aware Edge voice resolution.** When Edge is selected by the fresh-install resolver, CodeWalk maps the app locale first, then the system locale, to an Edge voice/locale.
6. **Privacy and ADR-023 boundary.** Edge remains an experimental/private-protocol provider. Sanitized assistant text is sent to Microsoft only when Edge is selected, and no OpenCode server contract, endpoint, schema, realtime event, provider/model contract, or ADR-023 behavior changes.

### Rationale

- Preserving non-blank persisted `ExperienceSettings` protects explicit user choice and prevents migrations from silently changing privacy-sensitive provider behavior.
- Missing/blank `getExperienceSettingsJson()` is the narrowest durable signal for a fresh install, avoiding platform-specific heuristics that could affect existing users.
- Linux needs a working first-run provider because native `flutter_tts` is unavailable there; choosing native would create a broken default.
- Runtime probing keeps native as the preferred local/offline path on platforms where it actually works, while avoiding a nonfunctional native default when it does not.
- App-locale-first voice resolution respects the user's selected CodeWalk language before falling back to the operating system locale.
- Keeping all provider selection and synthesis client-side preserves ADR-023 compatibility.

### Consequences

- ✅ Fresh installs get a working read-aloud default instead of a broken native provider on Linux or native-unavailable runtimes.
- ✅ Existing users and migrated profiles keep their persisted `ExperienceSettings`; provider, voice, and locale choices are not overwritten.
- ✅ Native TTS remains preferred on Windows, macOS, and other supported platforms when runtime probing confirms availability.
- ✅ Edge voice defaults follow app locale first, then system locale, improving first-run voice fit.
- ✅ ADR-023 remains unchanged: no OpenCode server endpoint, schema, event, provider/model, or lifecycle contract changes.
- ⚠ Linux and other native-unavailable fresh installs may start on the experimental Edge provider, so privacy warning copy and provider switching must remain visible.
- ⚠ Edge uses an unofficial/private protocol and may break, throttle, or change behavior outside CodeWalk's control.
- ⚠ Runtime native probing and locale-to-Edge mapping become part of the settings defaulting contract and require regression coverage.
- ❌ CodeWalk can no longer assume `ReadAloudProvider.native` is the universal first-run default.
- ❌ Edge must not proxy through OpenCode or imply a stable server/provider contract.

### Key Files

- `lib/domain/entities/experience_settings.dart` — `ExperienceSettings` persistence for non-secret read-aloud values and default enum fields; adaptive resolution lives outside the entity.
- `lib/data/datasources/app_local_datasource.dart` — `getExperienceSettingsJson()` fresh-install signal.
- `lib/presentation/services/tts/read_aloud_default_resolver.dart` — adaptive first-run provider and Edge voice/locale resolution.
- `lib/presentation/providers/settings_provider.dart` — settings hydration and no-overwrite persistence boundary using the resolver output.
- `lib/core/di/injection_container.dart` — injects the native TTS availability probe into `SettingsProvider` for runtime first-run defaults.
- `lib/presentation/services/tts/native_tts_backend.dart` — runtime native TTS availability probing.
- `lib/presentation/services/tts/edge_experimental_tts_backend.dart` — experimental Edge backend and voice discovery.
- `lib/presentation/services/tts/read_aloud_text_extractor.dart` — sanitized assistant text boundary before Edge synthesis.
- `test/unit/services/read_aloud_default_resolver_test.dart` — adaptive default, native-probe, and locale mapping coverage.
- `test/unit/providers/settings_provider_test.dart` — settings hydration and no-overwrite integration coverage.

---

## ADR-049: Cross-Platform Attention Surfaces and Secure Background Continuity (2026-07-12)

**Status**: Accepted

**Related**: GitHub issue #98; ADR-001 (secure credential storage), ADR-003 (realtime/background lifecycle), ADR-017 (Android foreground monitoring), ADR-023 (Official OpenCode Contract-First Compatibility Policy), ADR-046/ADR-047/ADR-048 (read-aloud provider policy).

### Context

Issue #98 requires an optional cross-platform attention surface for completed or attention-required root sessions without turning CodeWalk into a separate server-side notification system. The feature must remain disabled by default, preserve strict multi-server and directory/session isolation, survive only the background cases that can be restored safely, and keep display and speech data bounded and encrypted.

Android overlays require `SYSTEM_ALERT_WINDOW` and a policy-compliant foreground service. Desktop requires an independent window/engine lifecycle, while iOS cannot provide an out-of-app overlay. Network constraints, Data Saver, host reachability, authentication, and tunnel lifecycle must not be conflated. The implementation must also preserve ADR-003's low-cost non-current-session policy and fully comply with ADR-023.

### Decision

1. **Default-off presentation mode.** Add an `Off` / `Bubble` / `Panel` attention-surface preference, defaulting to `Off`. `Bubble` and `Panel` are explicit user opt-ins; rollback is always available by returning the preference to `Off`, which stops attention presentation and removes any active surface. iOS supports the feature in-app only and never attempts an out-of-app overlay.

2. **Root-only, active-server attention across known contexts.** Evaluate attention only for root sessions on the active server across its known directory contexts. Every candidate, snapshot, display action, speech action, and final fetch is bound to the exact `(serverId, directory, rootSessionId)` identity; a display label, project fallback, descendant/subsession ID, or stale active context is never a substitute. Child sessions and inactive-server sessions do not independently produce attention surfaces.

3. **Narrow ADR-003 final-fetch exception.** Keep ADR-003's realtime-first and non-current-session filtering intact. The only exception is one bounded, directory-scoped final message fetch after an authoritative `session.idle` for the matching root session identity on the active server. The result is used only to produce the final attention display/speech snapshot; it neither applies background message diffs nor starts child-session, global, or unbounded polling. Fetch multiplicity, payload size, retained entries, and retention time are bounded.

4. **Encrypted bounded snapshots and explicit read-aloud.** Persist display and speech snapshots only as AES-256-GCM encrypted, size- and retention-bounded records scoped to the exact identity. They contain no credentials, OAuth material, Tailscale state, raw logs, or unbounded message history. Speech is never automatic: only an explicit user `Read` action invokes the currently configured native, experimental Edge, or OpenAI-compatible TTS provider. Existing secure-storage-only handling for OpenAI-compatible secrets remains mandatory; secrets never enter snapshots, normal preferences, overlays, logs, or exported settings.

5. **Android isolated overlay host.** Android `Bubble`/`Panel` requires user-granted `SYSTEM_ALERT_WINDOW` and a dedicated, non-exported `specialUse` foreground service. That service owns a narrow overlay-only `FlutterEngine` and `FlutterView`; it is separate from, and must not share lifecycle or responsibilities with, the existing `dataSync` foreground service. The manifest declaration, runtime permission flow, foreground-service notification, and service start behavior must satisfy current Android and Play policy requirements.

6. **Desktop isolated window behind an app-owned boundary.** Define an app-owned desktop attention-surface abstraction whose implementation creates a separate Flutter engine/window. Use `desktop_multi_window` **0.3.0** only after a compatibility gate validates supported desktop builds, startup, teardown, inter-window messaging, and no main-window lifecycle regression. No alternative window package or shared-main-engine shortcut is accepted without a new ADR decision.

7. **Separate host and network lifecycle.** Track host/profile lifecycle (configured server, authentication state, transport/tunnel availability, and reachable host) independently from network lifecycle (connectivity, metering, cellular Data Saver, and scheduling permission). A foreground service remains background work for cellular Data Saver purposes and must not claim a foreground exemption merely because Android requires an FGS notification. Delayed attention timers expose their deadline, remaining duration, and pause reason; constrained or unavailable lifecycle states pause time observably rather than silently consuming delayed time.

8. **Process-death fallback is intentionally narrow.** After process death, the service may restore only a plain/unauthenticated or Basic-authenticated host through the dedicated service fallback. OAuth and Tailscale-backed contexts are frozen after process death and shown as reopen-required; the service must not refresh OAuth, recreate a tunnel, infer credentials, or silently reconnect those contexts. Opening CodeWalk is required to re-establish their app-owned lifecycle.

9. **Platform and policy capability gates.** Wayland overlay/window-manager limitations and Google Play restrictions on `SYSTEM_ALERT_WINDOW` and `specialUse` foreground services are first-class availability constraints. If the required platform capability or policy approval is absent, the affected Bubble/Panel path remains unavailable and CodeWalk falls back to its normal in-app behavior or `Off`; it does not emulate an overlay through unsupported background execution.

### Rationale

- Default-off, explicit modes, and explicit Read preserve user agency for privacy-sensitive overlays and speech.
- Exact server/directory/root-session identity prevents multi-server or descendant-session attention from leaking into the wrong workspace.
- The single post-idle bounded fetch provides a reliable final snapshot without undoing ADR-003's cheap non-current-session handling.
- AES-256-GCM bounded storage protects transient display/speech content without creating a second durable chat archive or credential path.
- Separate Android and desktop engine/window ownership avoids coupling overlays to the primary app UI or the existing data-sync service.
- Keeping host, network, Data Saver, OAuth, and Tailscale states distinct makes degraded behavior honest and recoverable instead of silently attempting unsafe reconnection.

### Consequences

- ✅ Attention surfaces are opt-in, reversible, and default to `Off` on every platform.
- ✅ Final attention data remains scoped, bounded, encrypted, and limited to root sessions on the active server.
- ✅ Android overlay ownership is isolated from the existing `dataSync` service, and desktop windows are isolated behind an app-owned abstraction.
- ✅ TTS respects the configured provider but requires an explicit Read action; OpenAI-compatible secrets retain their secure-storage boundary.
- ✅ ADR-003 keeps its non-current-session performance policy except for the single bounded post-idle root-session fetch.
- ⚠ Android overlays require user permission, a visible foreground-service notification, OEM-compatible behavior, and ongoing Play-policy review.
- ⚠ Wayland compositors may not support the required window behavior consistently; feature availability must be reported rather than assumed.
- ⚠ OAuth and Tailscale attention cannot resume after process death until the user reopens CodeWalk.
- ⚠ Compatibility with `desktop_multi_window` 0.3.0 is a release gate, not an assumption.
- ❌ No automatic speech, inactive-server attention, child-session overlay, unbounded background history, OAuth refresh, or Tailscale reconnection is supported by this feature.
- ❌ An FGS is not treated as a cellular Data Saver foreground exemption.

### Full ADR-023 Compatibility

This ADR is fully compliant with ADR-023 and is **not** an ADR-023 exception. It adds no OpenCode server endpoint, request/response schema, server-side proxy, authentication contract, session/message mutation, agent/model/provider behavior, configuration mutation, or realtime-event semantic. CodeWalk continues to consume official server events and existing authoritative read paths only.

The bounded final root-session fetch is solely the explicit ADR-003 event-scope exception documented above: it occurs after official `session.idle`, uses the exact server/directory/session identity, and produces client-owned encrypted display/speech snapshots. It neither changes the OpenCode contract nor substitutes client state for server authority. Overlay presentation, desktop windows, Android service lifecycle, encryption, TTS dispatch, Data Saver handling, and process-death gating are client-owned behavior.

### Key Files / Planned Areas

- `lib/domain/entities/experience_settings.dart` — default-off `Off` / `Bubble` / `Panel` preference and non-secret attention settings.
- `lib/presentation/services/attention/` — planned identity validation, bounded AES-256-GCM snapshot store, lifecycle coordinator, delayed-time observability, and platform capability gates.
- `lib/presentation/providers/chat_provider/` — planned root-session `session.idle` coordination and the narrow ADR-003 final-fetch guard.
- `lib/presentation/services/read_aloud_service.dart` and `lib/presentation/services/tts/` — explicit Read-only dispatch through configured native, Edge, or OpenAI-compatible providers; no secret persistence changes.
- `lib/core/auth/` and `lib/data/datasources/` — secure key access and exact server/directory/session-scoped persistence boundaries.
- `android/app/src/main/AndroidManifest.xml` — `SYSTEM_ALERT_WINDOW`, `specialUse` FGS declaration, and non-exported service configuration.
- `android/app/src/main/kotlin/com/verseles/codewalk/` — planned dedicated overlay `specialUse` FGS, narrow Flutter engine/view host, and Android capability bridge; separate from the `dataSync` service.
- `lib/presentation/services/attention/desktop/` and `pubspec.yaml` — planned app-owned desktop window abstraction and `desktop_multi_window` 0.3.0 compatibility gate.
- `ios/Runner/` and in-app presentation widgets — in-app-only iOS capability path.
- `test/unit/`, `test/widget/`, and Android/desktop integration coverage — identity isolation, post-idle fetch bounds, encryption, pause observability, permission/policy gates, process-death fallback, and rollback-to-Off behavior.

---

## ADR-050: Fork of `desktop_multi_window` for Non-Activating Window Presentation (2026-08-01) ⚠️ SUPERSEDED by ADR-051

**Status**: Superseded

**Related**: GitHub issue #129; ADR-049 (cross-platform attention surfaces).

### Context

The desktop attention Bubble delivered by ADR-049 is a `desktop_multi_window` sub-window. Issue #129 requires that showing or refreshing it never move keyboard focus away from the application the user is working in.

Two mitigations were possible without touching the plugin and both were applied first: the child engine now marks itself frameless and skip-taskbar before `runApp`, and the host service only calls show on the hidden→visible transition, so snapshot refreshes no longer touch window state. Neither addresses the first presentation, which still activates.

There is no API for a non-activating show. `window_manager` 0.5.1 exposes `setAsFrameless`, `setAlwaysOnTop`, `setSkipTaskbar`, `isFocused` and `isVisible`, but no `setFocusable`. `desktop_multi_window` 0.3.0 exposes only `show`, `hide`, `invokeMethod` and `setWindowMethodHandler`, and its native `window_show` actively takes focus on all three platforms: `ShowWindow(hwnd_, SW_SHOW)` on Windows, `gtk_widget_show` on Linux, and `makeKeyAndOrderFront` plus `NSApp.activate(ignoringOtherApps: true)` on macOS. The only `NOACTIVATE` in the package is in the Windows resize path, not in presentation.

### Decision

Fork `MixinNetwork/flutter-plugins` and add `WindowController.showWithoutActivating()` to `desktop_multi_window`, consumed as a Git dependency pinned to a branch.

Per platform the new method maps to the conventional no-activate presentation:

- **Linux (GTK):** `gtk_window_set_accept_focus(FALSE)` before mapping the window; `show()` restores accept-focus so both entry points remain usable.
- **Windows:** add `WS_EX_NOACTIVATE` to the extended style, then `ShowWindow(SW_SHOWNOACTIVATE)`.
- **macOS:** `orderFrontRegardless()` without making the window key and without activating the application.

Pointer input continues to work in all three cases, so the Bubble stays interactive when the user clicks it deliberately, satisfying the acceptance criterion that explicit interaction must keep working.

Rejected alternative: replacing `desktop_multi_window` with app-owned windows in our own runners. The plugin carries roughly 3,900 lines of native code across 24 files, and most of that is secondary Flutter engine plumbing rather than window management. Owning it would concentrate maintenance in the two platforms this project cannot validate locally — macOS is absent from CI and Windows has a single job — for a gain limited to focus policy.

### Consequences

- The project no longer tracks published releases of `desktop_multi_window` automatically. This is a small change in practice: the dependency was already pinned to an exact version rather than a caret range, and the package has published only six versions in its lifetime, the latest being 0.3.0 on 2025-10-28.
- The fork tracks upstream `main`, which is version 0.3.1, so the project also picks up unreleased upstream changes.
- The patch is deliberately small and confined to the presentation entry points, so rebasing onto a future upstream release is cheap.
- Wayland remains a documented limitation: focus policy belongs to the compositor and a non-activating show may not be honoured everywhere. This is a limitation, not a defect.

### Exit Criteria

Submit the change upstream as a pull request. If it is accepted and released, drop the fork and return to the published package. If it is rejected, keep the fork and rebase it on each upstream release that matters to the project.

### Key Files

- `pubspec.yaml` — Git dependency pointing at the fork branch, with the reason recorded inline.
- `lib/presentation/services/session_attention/session_attention_host_service_io.dart` — `_showDesktopWindow` calls `showWithoutActivating` and skips redundant presentations.
- `lib/presentation/services/session_attention/session_overlay_entrypoint.dart` — frameless and skip-taskbar applied before `runApp`.
- Fork: `insign/flutter-plugins`, branch `feat/show-without-activating`.

---

## ADR-051: Removal of Desktop Attention Surfaces (2026-08-01)

**Status**: Accepted

**Related**: Supersedes ADR-050; narrows ADR-049; GitHub issues #98 and #129.

### Context

ADR-049 gave every platform an attention surface. On desktop that meant a `desktop_multi_window` child window rendering the Bubble or Panel. Making that window behave like an overlay rather than an ordinary window required, in sequence: hiding it from the taskbar, removing its frame, forcing always-on-top, suppressing redundant re-presentations, and finally forking the plugin (ADR-050) to add a non-activating show with native patches on Linux, Windows and macOS.

That cost bought a surface that duplicates what desktop already provides. The project initialises native notifications for Linux, macOS and Windows in `notification_service.dart`, ships a tray icon with tooltip and context menu in `desktop_tray_service_io.dart`, and, since the session tab strip landed, shows per-session error, question, completion and activity indicators in the top band of the window.

A self-drawn floating window is also a worse notification than the native one: it does not appear in the notification centre, does not respect Do Not Disturb or Focus modes, has no history, does not stack, and ignores the position the user configured at system level.

The calculus differs on Android, where the overlay is the only way to draw over other applications and the pattern is familiar to users, and on iOS, where the surface is in-app only.

### Decision

Remove Bubble and Panel from desktop entirely. Desktop reports `SessionAttentionHostKind.unsupported`, the preference is not offered there, and no attention window is created. Attention on desktop is carried by native notifications, the tray, and the session tab indicators.

Drop the `desktop_multi_window` dependency and delete the fork created in ADR-050. Android and iOS behaviour is unchanged.

### Consequences

- The project no longer depends on `desktop_multi_window`, and no longer maintains a fork with native code on three platforms. The native no-activate patches are discarded along with it.
- Desktop users lose a persistent floating list of sessions needing attention. This is the accepted trade: the same information is available from notifications, the tray, and the tab indicators, all of which integrate with the operating system.
- `SessionAttentionPresentation` remains in the settings model because Android and iOS still use it. Only the desktop producer and consumer are gone.
- ADR-049 stays valid for Android and iOS; its desktop window lifecycle section no longer applies.

### Key Files

- `pubspec.yaml` — `desktop_multi_window` removed.
- `lib/presentation/services/session_attention/session_attention_host_service_io.dart` — desktop capability, activation, snapshot and window helpers removed; desktop now falls through to unsupported.
- `lib/presentation/services/session_attention/session_overlay_entrypoint.dart` — desktop child entry point, window channel and `WindowListener` removed; the host app is Android-only.
- `lib/main.dart` — desktop child bootstrap removed.
- `lib/presentation/pages/settings/sections/behavior_settings_section.dart` — the control is hidden where the capability is unsupported.

---

## ADR-052: Bounded Default-Off Autosave Addendum for the Focused File Editor (2026-08-02)

**Status**: Accepted

**Related**: ADR-043 (Files as a Shell-Gated Micro File Manager with Capability-Probed Mutations), ADR-023 (Official OpenCode Contract-First Compatibility Policy), ADR-002 (Context Isolation), ADR-008 (Context-Scoped File Explorer and Viewer).

**Scope**: This is a narrowly scoped addendum to ADR-043. It supersedes only the explicit-save-only/autosave exclusion; the existing mutation transport, containment, capability gate, editor size boundary, and manual-save contract remain accepted.

### Context

ADR-043 shipped a focused editor whose dirty drafts could be persisted only through an explicit `Save` action and deliberately deferred autosave for separate evaluation. Autosave is now shipped, but it must not become a second mutation architecture or allow a delayed write to cross a server, project context, root, or file path while the user navigates.

The feature also spans debounce timers, context transitions, controlled lifecycle callbacks, tab close, authentication, and the existing multi-request ephemeral shell operation. These boundaries must remain conservative: an autosave may reduce friction, but it cannot promise durability across an operating-system hard kill, invent OpenCode behavior, or silently write a draft into a new context.

### Decision

1. **Autosave is opt-in and bounded.** The autosave preference defaults to off. When enabled, a dirty draft schedules one autosave after **30 seconds of inactivity**; edits during the window reset the timer. Autosave is not a bulk queue, a continuous stream, or a format-on-save feature.

2. **Manual save remains available.** The focused editor's explicit `Save` action and `Ctrl+S` / `Cmd+S` shortcut remain available regardless of the autosave preference. Manual save and autosave use the same draft state, dirty marker, size limit, error handling, and host-authoritative completion rules.

3. **Reuse the same shell-gated one-shot write pipeline.** An autosave calls `WorkspaceFileOperationsService.writeFile` through ADR-043's capability gate and encoded static POSIX program. It uses the existing official `POST /session`, `POST /session/:id/shell`, and `DELETE /session/:id` lifecycle, `CW_FILE_OP_JSON:` sentinel, negotiated decoder, containment checks, ordered content chunks, and atomic sibling-temp write. Autosave adds no custom OpenCode endpoint, request/response schema, or event semantic.

4. **Every write carries exact ownership.** The autosave ownership tuple is the exact `(serverId, context/directory, rootDirectory, path)` captured by the draft. A delayed callback must match all four values before dispatching or applying a result; a server/profile label, display project name, current active root, or descendant session is not a substitute. A successful result clears only the matching draft, and a failed or stale result cannot clear another context's dirty state.

5. **Flush only within the same server and only when enabled.** Leaving a context on the same server and controlled lifecycle callbacks may request a **best-effort** flush of enabled, dirty drafts owned by that same server/context. No cross-server flush is attempted. A disabled preference suppresses both the debounce and lifecycle flush; autosave never turns an unrelated server switch into a write opportunity.

6. **Coordinate close and in-flight work.** Tab close, root/context disposal, reload, rename, and delete coordinate with an in-flight save instead of disposing or retargeting its draft. The existing dirty/saving guards remain effective; a close is deferred or refused until the matching write resolves, and a failure retains the dirty draft. No fire-and-forget completion may mark a replacement tab clean.

7. **Cancellation and rearming are generation-scoped.** Disabling autosave cancels pending debounce and lifecycle work and invalidates its callbacks. Cancellation of a request already accepted by the host is best-effort and cannot undo a host write, but its stale completion cannot rearm or clear a disabled/replaced draft. Re-enabling creates a new generation and rearms a fresh 30-second debounce from the current dirty draft; it does not reuse a stale timer or silently flush a different context.

8. **A server switch aborts the multi-request mutation.** Switching servers invalidates the autosave generation and aborts the in-flight client orchestration of the ephemeral-session create/shell/cleanup mutation. Once the active profile/base changes, remaining old-origin shell and `DELETE` requests are aborted or skipped to avoid cross-profile auth/transport; they are never rerouted to the new server, and stale results are ignored. An already-created old ephemeral session may remain and be cleaned server-side later; the client does not send cleanup to the captured old server after the switch.

9. **Basic auth is exact-origin only.** A lifecycle or autosave request using Basic auth must use the captured profile's exact origin (scheme, host, and effective port) and the matching configured server identity. Redirects, origin changes, host-only matches, or reuse of credentials against another origin fail closed; a server ID alone does not authorize the request.

10. **Do not reset dirty root ownership eagerly.** If a dirty or saving draft survives a root/context transition, its original `rootDirectory` and path ownership remain attached until the matching write resolves, is aborted, or the draft is explicitly discarded. Resetting dirty-root metadata is deferred so a delayed save cannot resolve its path against the newly selected root; a new root receives a separate draft identity.

11. **Durability remains explicitly bounded.** The 30-second debounce and lifecycle flush are best-effort. A crash, process termination, OS hard kill, power loss, or lifecycle callback that never runs may lose changes that were not explicitly saved or completed by the host. Autosave is not advertised as a durability guarantee.

### Rationale

- Reusing ADR-043's one-shot shell pipeline preserves server authority and ADR-023 alignment without creating a custom OpenCode contract.
- A default-off 30-second debounce coalesces active typing while bounding shell-session creation, network traffic, and host writes.
- Exact server/context/root/path ownership plus generation checks prevent delayed callbacks from leaking drafts across profiles or saving into a newly selected root.
- Same-server lifecycle flushing captures common navigation and controlled shutdown paths without pretending that an app can observe every process death.
- Keeping manual `Save` independent preserves an immediate user-controlled durability path and a clear recovery action after an autosave failure.
- Disable cancellation and enable rearm make preference changes deterministic: old work cannot revive after disable, and enabling starts from current state rather than stale timer state.
- Exact-origin Basic-auth validation prevents a convenience lifecycle path from becoming a credential-forwarding path.

### Consequences

- ✅ Typing-heavy editor use can persist dirty drafts without abandoning the explicit manual-save path.
- ✅ Autosave remains default-off, capability-gated, host-authoritative, and bounded to the existing ADR-043 transport and 64 KiB editor/save boundary.
- ✅ Exact ownership, same-server filtering, generation invalidation, and deferred root reset protect multi-server and project-context isolation.
- ✅ Close, path mutation, disable, re-enable, and server-switch races have explicit coordination rules rather than relying on timer timing.
- ⚠ Every autosave is still a full ephemeral-session round trip and may take longer than the 30-second quiet period; the UI must keep the draft dirty until the matching host result.
- ⚠ Controlled lifecycle flushes are best-effort and may be skipped when authentication, origin, capability, connectivity, or process lifecycle conditions are not safe.
- ⚠ A host-side change made after the editor read is not automatically merged; autosave retains the existing write semantics and does not add conflict resolution.
- ❌ There is no cross-server flush, bulk/multi-file autosave, format-on-save, diff/merge workflow, or guarantee against hard-kill data loss.

### ADR-023 Compatibility

This addendum does not create or broaden an OpenCode contract exception. Autosave is a client-side scheduling and lifecycle policy over ADR-043's already scoped shell-backed `writeFile` exception. It uses the same official session and shell endpoints, the same request/response envelopes and `CW_FILE_OP_JSON:` sentinel, and the same server event semantics; no custom endpoint, schema, event, or server-side autosave behavior is introduced. Any future bulk mutation, conflict/merge protocol, or new server behavior requires a separate ADR-023 evaluation.

### Risks

- **Medium lifecycle/durability risk.** A hard kill or crash before the debounce or controlled lifecycle callback completes can lose a draft; explicit `Save` remains the recovery and durability path.
- **Medium isolation risk.** A missing ownership or generation check could write to the wrong root or clear a replacement draft; every dispatch and completion must validate the exact tuple.
- **Medium transport risk.** The existing multi-request shell pipeline can fail or be interrupted between legs; server switches must abort it rather than reroute it.
- **Low authentication risk.** Exact-origin Basic-auth checks reduce availability when a profile origin changes, but fail-closed behavior is preferred to credential reuse across origins.
- **Low conflict risk.** Autosave can persist a draft over an external host change because ADR-043 has no merge protocol; the feature deliberately does not invent one.

### Rollback / Fallback Plan

- **User rollback:** turn autosave off. Pending debounce and lifecycle work are cancelled/invalidated; manual `Save` remains unchanged.
- **Feature rollback:** remove the autosave scheduler and lifecycle coordinator only. ADR-043's explicit editor save, capability probe, read-only fallback, containment, and write pipeline remain in place.
- **Transport fallback:** `unavailable`, malformed response, decoder failure, origin mismatch, or unsafe ownership fails closed; no client-side or cross-server write path is attempted.
- **In-flight fallback:** disabling or switching servers invalidates callbacks and aborts remaining client orchestration. A host write that already completed is not rolled back by the client.
- **Durability fallback:** there is no persisted autosave queue to replay after restart; users retain the explicit `Save` action for changes that must survive process termination.

### Regression Tests

The addendum retains the existing named regression anchors from ADR-043 and applies autosave assertions at the same service/widget seams:

- **Service anchors** in `test/unit/presentation/workspace_file_operations_service_test.dart`: one encoded-static-script pipeline with no semicolon-split execution path; decoder negotiation/caching per server+directory with capability invalidation; ordered 48 KiB environment chunk streaming and last-valid-sentinel extraction; the 64 KiB UTF-8 editor/save boundary; and containment, atomic sibling-temp write, mode preservation, pending-delete locks, and delete alias reconciliation.
- **Widget anchors** in `test/widget/chat_page_test.dart`: `file editor saves dirty content from open files dialog`; `file editor keeps dirty state when save fails`; `file editor opens empty text files as editable drafts`; `file editor preserves CRLF line endings when saving`; `file editor gutter selection adds current draft to chat context`; `file editor blocks closing dirty tabs`; and `file tree rename blocks dirty relative editor drafts`.
- **Named seams to preserve:** `FakeWorkspaceFileOperationsService`, `writeFileCallCount`, `lastContent`, `file_viewer_tab_dirty_<path>`, `file_editor_save_error_<path>`, and `_blockPathMutationForActiveEditorDrafts`.
- **Autosave policy assertions:** default-off produces no write; the 30-second debounce coalesces edits; same-server leaving-context and controlled lifecycle flush only run when enabled; disable cancels and invalidates callbacks and enable rearms; exact server/context/root/path ownership prevents cross-server flush; server switching aborts multi-request mutation; Basic auth rejects non-exact origins; dirty root reset is deferred; and no completion clears a replacement draft after close or hard lifecycle interruption.

### Key Files

- `lib/presentation/services/workspace_file_operations_service.dart` — existing capability-gated one-shot write transport and ownership inputs.
- `lib/presentation/pages/chat_page/chat_page_file_runtime.dart` — draft lifecycle, autosave scheduling, context/root transitions, close coordination, and mutation guards.
- `lib/presentation/pages/chat_page/chat_page_file_viewer.dart` — editor dirty state, manual `Save`, debounce ownership, and save error presentation.
- `test/unit/presentation/workspace_file_operations_service_test.dart` — transport, containment, decoder, sentinel, and write regression anchors.
- `test/widget/chat_page_test.dart` — focused-editor, dirty-tab, path-mutation, and fake-service regression anchors.

---

## ADR-053: Client-Owned Configurable API Speech-to-Text (OpenAI / Groq / Custom OpenAI-Compatible) (2026-08-12)

**Status**: Accepted

**Related**: GitHub issue #97; ADR-006 (Speech Input Architecture with `SpeechInputService` and Platform Policy), ADR-007 (Modular Settings Architecture for `ExperienceSettings`), ADR-023 (Official OpenCode Contract-First Compatibility Policy), ADR-038/ADR-039/ADR-044 (platform STT policy and `SpeechEnginePlatformSupport`), ADR-046/ADR-047/ADR-048 (client-owned cloud TTS provider precedent).

### Context

On-device STT engines (Native, Sherpa, Moonshine, Parakeet, SenseVoice) require local models and are unavailable or weak on some platforms. Users need an opt-in cloud speech-to-text path that sends recorded microphone audio to a user-configured third-party provider.

The feature must remain client-owned: the OpenCode server must not be involved in transcription, credential storage, or provider routing (ADR-023). It must also protect provider secrets, preserve the existing native/on-device engine set and platform policy unchanged, and keep a bounded, honest failure model — cloud transcription failures must never silently fall back to another engine with different privacy behavior.

The design space is deliberately constrained: only OpenAI, Groq, and user-defined OpenAI-compatible endpoints are offered. Google Cloud Speech-to-Text and xAI are excluded because they do not expose an OpenAI-compatible `/audio/transcriptions` contract; any provider that does expose such a contract is reachable through the Custom preset.

### Decision

Adopt `SpeechToTextEngine.api` as an opt-in engine backed by `ApiSpeechInputService`, with two pinned presets, one configurable provider mode, and strict security/platform boundaries.

1. **Provider scope and pinned presets.** `SpeechApiProvider { openAi, groq, custom }` is the only provider surface. Presets are pinned: OpenAI (`https://api.openai.com/v1`, `gpt-4o-mini-transcribe`) and Groq (`https://api.groq.com/openai/v1`, `whisper-large-v3-turbo`). `setSpeechApiProvider()` resets base URL and model to the provider defaults, and the base URL field is editable only for `custom`. Google and xAI are not offered as presets (see Context); other OpenAI-compatible endpoints are configured through `custom`.

2. **Secure per-provider secrets.** API keys are stored only through `SttApiKeyStorage`, backed by `flutter_secure_storage` and namespaced per provider (`stt_api_key::openai|groq|custom`). Keys never enter `ExperienceSettings`, normal preference payloads, logs, or exported settings. The Custom preset makes the key optional; for OpenAI/Groq a missing key fails with a typed `apiKeyMissing` reason. Saving an empty value deletes the stored key; secure-storage failure fails closed (`apiKeyStorageUnavailable`).

3. **Custom endpoint transport policy.** Custom base URLs must be `https` for any remote host; plain `http` is accepted only for loopback hosts (`localhost`, `127.0.0.1`, `::1`), and the model must be non-empty. Any other configuration fails with `apiConfigInvalid`. This prevents API keys from being transmitted in plaintext to arbitrary hosts while still supporting local OpenAI-compatible proxies.

4. **Mobile/desktop only; Web excluded and migrated.** `SpeechEnginePlatformSupport.isApiSupported => !kIsWeb`. On web the engine tile is disabled, `ApiSpeechInputService.initialize()` fails with `webUnavailable`, and `SettingsProvider.initialize()` migrates a persisted `api` selection back to `native`. This avoids exposing provider keys in browser builds and avoids mixed-content restrictions on HTTPS-hosted web clients.

5. **Final-only WAV upload.** Microphone PCM is accumulated locally with speech-activity threshold, silence timeout, and a 2-minute max duration. When the recording finalizes (manual stop, silence, or timeout), the PCM is encoded to WAV and uploaded exactly once as a multipart file to `POST {baseUrl}/audio/transcriptions` with `model`, `response_format: json`, and an optional `language` hint derived from the app locale. There is no streaming or partial upload; the transcript is inserted at finalize.

6. **Factory service isolation per composer.** `ApiSpeechInputService` is registered in DI with `registerFactory`, not as a lazy singleton. Each composer resolves and caches its own instance and calls `configure()` from the current settings at every voice start; `configure()` also clears the in-memory API key. This prevents credential/config mixing between composers and stale-key reuse after settings changes.

7. **Local/native paths preserved.** Native and all on-device engines (Sherpa, Moonshine, Parakeet, SenseVoice) and the `SpeechEnginePlatformSupport` platform table are unchanged. The API engine is used only when explicitly selected; if it fails to initialize or transcribe, the typed reason is surfaced and no other engine is silently substituted (the API engine has no fallback candidates).

8. **Typed provider errors.** 401/403 → `apiKeyRejected`; 400/404/422 → `apiRequestInvalid`; 429 → `apiRateLimited`; 5xx → `apiUnavailable`; network → `apiNetwork`; malformed response → `apiInvalidResponse`; empty audio/transcript handled explicitly. Stable locale-independent reason keys are mapped to localized copy at the UI boundary.

### Rationale

- **Client-owned model follows the TTS precedent (ADR-046/047/048):** the client talks directly to the user-configured provider; the OpenCode server never sees audio or keys, so no server contract change and no ADR-023 exception is needed.
- **Pinned presets keep tested defaults and a small provider surface:** OpenAI and Groq are the only curated presets; every other provider must expose an OpenAI-compatible `/audio/transcriptions` endpoint and is configured through Custom. Google/xAI are excluded because they lack that compatible contract; a preset list of incompatible APIs would force per-provider adapters for no client-owned benefit.
- **Secure storage plus non-secret `ExperienceSettings` mirrors ADR-001 and ADR-046:** keys live in `flutter_secure_storage`; only provider, base URL, and model are ordinary settings.
- **HTTPS-only remote / HTTP-loopback-only enforcement** prevents key exfiltration over plaintext while supporting local OpenAI-compatible proxies.
- **Web exclusion** protects keys in browser builds and avoids mixed-content failures on HTTPS-hosted clients.
- **Final-only upload bounds third-party exposure:** one WAV per utterance, capped at 2 minutes, with visible privacy copy — the same bounded-data principle as ADR-046/047 payload limits.
- **Factory-per-composer isolation** makes credential/config mixing structurally impossible rather than relying on call-site discipline.
- **No silent fallback** keeps provider choice honest: a failed cloud transcription must be visible, not quietly replayed through a different engine with different privacy and accuracy behavior.

### Consequences

- ✅ Opt-in cloud STT with pinned OpenAI/Groq presets and any OpenAI-compatible Custom endpoint, on mobile and desktop.
- ✅ API keys stay in per-provider secure storage only — never in settings, logs, preferences, or exports; storage failure fails closed.
- ✅ Custom endpoints are restricted to HTTPS (remote) or HTTP loopback; keys are never sent in plaintext to arbitrary hosts.
- ✅ Web is excluded with automatic migration of saved `api` selections to `native`.
- ✅ Final-only WAV upload keeps third-party data transfer to one bounded request per utterance (silence timeout + 2-minute cap).
- ✅ Factory-registered `ApiSpeechInputService` isolates credentials/config per composer and re-reads keys at each session start.
- ✅ Native and on-device engines, platform tables, and fallback chains are unchanged; the API engine never silently falls back.
- ✅ Fully ADR-023 compliant: no OpenCode server endpoint, schema, event, or lifecycle change; transcription traffic is client→provider only.
- ⚠ Recorded microphone audio leaves the device for the configured provider when the API engine is active; settings show privacy copy and the user must opt in explicitly.
- ⚠ Custom endpoints may diverge from OpenAI semantics (model/format/error behavior); failures surface as typed provider errors.
- ⚠ Custom API keys are optional, so a misconfigured custom endpoint without a key may produce provider-side 401/403s that surface as `apiKeyRejected`.
- ⚠ Browser builds lose the cloud engine (migrated to native); users wanting cloud STT must use a native build.
- ❌ No streaming or partial transcriptions; transcription happens only after the recording finalizes.
- ❌ Google and xAI are not offered as presets; only OpenAI-compatible endpoints are supported, via Custom.
- ❌ CodeWalk does not proxy STT through the OpenCode server and never stores STT keys server-side.

### Security Consequences

- **Secrets:** per-provider keys in `flutter_secure_storage` only; provider-namespaced keys (`stt_api_key::<provider>`); in-memory key cleared on every `configure()`; save-empty deletes; secure-storage failure fails closed with a typed reason.
- **Transport:** `Authorization: Bearer` header is sent only to the validated endpoint — HTTPS for remote hosts, HTTP only for loopback — so keys cannot be sent in plaintext to arbitrary custom hosts.
- **Data:** only the final WAV (≤ 2 minutes) plus model/language hints are sent; no logs, tool metadata, chat content, or credentials accompany the request.
- **Isolation:** factory registration per composer prevents one composer's key/config from leaking into another; settings changes re-configure and clear state before the next start.

### Rollback / Fallback Plan

- **User rollback:** switch `Settings > Speech` engine back to Native or an on-device engine; the API engine has no fallback candidates, so selection is explicit and reversible.
- **Platform migration:** web builds auto-migrate persisted `api` selections to `native` on startup; the engine tile is disabled.
- **Feature rollback:** remove the `SpeechToTextEngine.api` tile and the `ApiSpeechInputService` factory registration; stored keys remain unused in secure storage until an explicit migration purges the `stt_api_key::` namespace. No settings-data migration is required.
- **Failure fallback:** any API STT failure shows the typed localized reason; `apiKeyStorageUnavailable`, `apiConfigInvalid`, and `webUnavailable` fail closed before any audio is captured or sent.

### ADR-023 Compatibility

This ADR is fully compliant with ADR-023 and is **not** an ADR-023 exception. It adds no OpenCode server endpoint, request/response schema, realtime event, session/message/model/agent lifecycle change, config mutation, or server-side proxy. API STT is a client-owned speech feature: CodeWalk captures microphone audio on the client, encodes it to WAV locally, and sends it directly from the client to the user-configured third-party provider only when `SpeechToTextEngine.api` is selected. The OpenCode server is not involved in capture, transcription, credential storage, provider routing, or result delivery — the same client-owned boundary already established for cloud TTS in ADR-046/ADR-047/ADR-048.

### Key Files

- `lib/domain/entities/experience_settings.dart` — `SpeechApiProvider` enum, pinned preset constants (`kDefaultOpenAiSttBaseUrl`/`kDefaultOpenAiSttModel`, `kDefaultGroqSttBaseUrl`/`kDefaultGroqSttModel`), and non-secret `speechApiProvider`/`speechApiBaseUrl`/`speechApiModel` persistence.
- `lib/core/auth/stt_api_key_storage.dart` — per-provider `flutter_secure_storage` key storage; the only accepted persistence path for STT secrets.
- `lib/presentation/services/speech_input_service_api.dart` — `ApiSpeechInputService` engine: endpoint validation, final-only WAV upload, typed provider errors, silence/2-minute finalization.
- `lib/core/di/injection_container.dart` — `registerFactory(ApiSpeechInputService)` for per-composer isolation.
- `lib/presentation/utils/speech_engine_platform_support.dart` — `isApiSupported => !kIsWeb`; all other engine flags unchanged.
- `lib/presentation/providers/settings_provider.dart` — `setSpeechApiProvider`/`setSpeechApiBaseUrl`/`setSpeechApiModel` preset pinning; web `api` → `native` migration.
- `lib/presentation/pages/settings/sections/speech_settings_section.dart` — engine tile, provider dropdown, base URL (custom-only editable), model, obscured key entry, privacy copy, and typed status.
- `lib/presentation/widgets/chat_input/chat_input_speech_controller.dart` — engine resolution (API has no fallback candidates), per-start `configure()`, and typed reason snackbars.
- `lib/presentation/widgets/chat_input_widget.dart` — per-composer `ApiSpeechInputService` instance caching.
- `lib/l10n/app_en.arb` + locale ARBs — `speechApi*` keys (provider, privacy, batch hint, max duration, language hint, typed errors).
- `test/unit/` — key storage, engine validation/transport, settings migration, and platform-support coverage.
- Ref: issue #97

---

## ADR-054: Experimental Test-Only Android Auto Notification Messaging (2026-08-12) ⚠️ SUPERSEDED by ADR-055

**Status**: Superseded — the release/debug gating decision (items 1–2) is superseded by ADR-055 (2026-08-13); the technical messaging/background/ADR-023 decisions (items 3–14) are preserved and carried forward unchanged in ADR-055.

**Related**: GitHub issue #99; ADR-003 (realtime/background lifecycle), ADR-017 (Android foreground monitoring), ADR-023 (Official OpenCode Contract-First Compatibility Policy), ADR-049 (attention surfaces and background continuity), ADR-053 (client-owned API STT as the speech-backend precedent).

### Context

Issue #99 requests an Android Auto notification messaging prototype: surfaced on the car display as a `MessagingStyle` notification with a voice reply action, without opening the Flutter UI. The user explicitly chose to proceed with this experimental prototype while accepting that Google Play's automotive (MF-5) eligibility is unresolved — the feature is therefore test-only and must never ship as a Play-distributed automotive experience without a separate eligibility review and ADR.

Android Auto messaging notifications impose strict constraints: templates-only rendering (no custom UI), a single supported voice-reply `RemoteInput` per notification, no processing/intermediate messages, and no custom microphone/STT/TTS — the car head unit owns capture and speech. Background Android conditions after process death are severely constrained, and OpenCode's official prompt endpoint (`POST /session/:id/prompt_async`) has no client-supplied idempotency key, leaving a residual duplicate-or-loss window at POST time. ADR-049's background attention boundary is read-only; sending an explicit voice reply is a background write that this prototype must gate separately.

### Decision

1. **Double default-off gating.** The feature requires both a default-off Dart feature flag (`lib/core/config/feature_flags.dart`) and a default-off user preference. It is active only when the flag is enabled in a debug/test build and the user has explicitly opted in. Release builds ship only shared inert Dart code: `kDebugMode` keeps the runtime disabled and the automotive descriptor is absent.

2. **Automotive notification descriptor in debug source set only.** The Android automotive notification descriptor (automotive `res/xml/automotive_app_desc.xml` + manifest wiring under `android/app/src/debug/`) lives exclusively in the debug source set and is never part of the release artifact. The shared Dart code (models, encrypted store, services) is compiled into release builds but stays inert there. There is no Play eligibility claim anywhere in the app, manifest, store listing, or metadata.

3. **`MessagingStyle` renders only the final assistant response.** The notification shows the settled final assistant message text for the root session via `NotificationCompat.MessagingStyle`; it never renders diffs, intermediate events, processing states, or child-session content.

4. **Exactly one `RemoteInput` semantic reply plus mark-as-read.** The notification exposes exactly one `RemoteInput` whose `setLabel` describes replying to the assistant; a separate mark-as-read action is local-only. No other actions, inputs, or affordances are added.

5. **Explicit non-goals.** No custom notification UI, no `CarAppService`/`androidx.car.app` templates, no processing/intermediate messages, no custom microphone/STT/TTS (the head unit owns capture and speech; ADR-053's client STT engines are not invoked from this surface), and no Play MF-5 eligibility claim.

6. **Accepted background envelope.** The feature is expected to work when the phone is powered on but the screen is locked/off, the Flutter UI is closed, and Android performs normal process recreation. The reply is persisted via the existing `flutter_local_notifications` `ActionBroadcastReceiver`/background callback (encrypted, bounded) before the existing WorkManager headless execution path is scheduled to send it. A foreground app is not required.

7. **Explicitly excluded conditions.** Powered-off device, explicit Android force-stop, pre-first-unlock (Direct Boot) device state, an unlimited realtime delivery guarantee, and prolonged offline execution are not supported. The feature fails closed outside the accepted envelope.

8. **Honest bounded latency.** Delivery rides WorkManager scheduling latency; the notification and settings copy state this honestly. No foreground service is added and no cellular Data Saver bypass is attempted (per ADR-049's Data Saver stance).

9. **Exact identity and bounded state.** Every persisted reply and reconciled message is bound to the exact root-session `(serverId, directory, rootSessionId)` identity on the active server only. Thread/reply state is persisted as bounded AES-256-GCM encrypted records containing no credentials, OAuth material, Tailscale state, or unbounded history (mirroring ADR-049's snapshot discipline).

10. **Post-process-death auth envelope.** After process death, only plain/no-auth and Basic-authenticated hosts may send replies. OAuth and Tailscale-backed contexts are reopen-required (frozen until the user opens CodeWalk); Data Saver pauses reply scheduling rather than bypassing it.

11. **Official contract send path.** Replies are sent via the official directory-scoped `POST /session/:id/prompt_async` with no `messageID` and no schema invention — preserving ADR-023. Delivery confirmation uses bounded reconciliation against official status/message reads only; no new endpoint, header, or event semantic is added.

12. **Mark-as-read is local only.** The mark-as-read action updates client-side local state only; it never mutates server state.

13. **Residual duplicate-or-loss window.** Because OpenCode's `prompt_async` has no idempotency key, a bounded duplicate-or-loss window exists at POST (e.g., reply persisted, send started, process dies). The client retries a bounded number of times and fails closed (never guessing or fabricating a second send) when the window cannot be resolved; the user is told the reply's delivery is not guaranteed in that edge.

14. **ADR-049 boundary change, narrowly scoped.** This ADR changes ADR-049's prior read-only background attention boundary only for this separately gated explicit voice-reply prototype: where ADR-049 permits a bounded post-idle fetch for display/speech snapshots but never a background write, ADR-054 adds exactly one explicit user-initiated reply send through the official contract. It does not broaden overlay behavior, add background writes beyond this single gated surface, or relax any ADR-049/ADR-003 boundary otherwise.

### Rationale

- Android Auto mandates template-based messaging UX; `MessagingStyle` + one `RemoteInput` is the only compliant shape, and skipping custom UI, car templates, and custom speech keeps the surface minimal and testable.
- The user accepted the unresolved MF-5 eligibility risk, so confining the automotive descriptor to the debug source set with a double default-off gate makes the prototype reversible and keeps releases clean: release artifacts contain the shared Dart code (models, encrypted store, services), but it remains inert behind `kDebugMode` and the default-off flag, with no automotive descriptor.
- Reusing the existing `ActionBroadcastReceiver`/WorkManager path avoids a new background-execution mechanism (ADR-017 remains the only FGS) and keeps latency honest and bounded.
- Exact root-session identity, bounded AES-256-GCM state, and the plain/Basic-only process-death envelope mirror ADR-049's security discipline; the official `prompt_async` path with bounded reconciliation preserves ADR-023.
- Fail-closed retries and an explicitly documented duplicate-or-loss window are the only honest response to OpenCode's missing idempotency key.

### Consequences

- ✅ Test-only Android Auto messaging prototype with compliant `MessagingStyle` + single reply `RemoteInput` + local mark-as-read.
- ✅ Double default-off gating and debug-only descriptor keep release builds and Play submissions clean: release artifacts carry shared inert Dart code, but `kDebugMode` disables it at runtime and no automotive descriptor ships.
- ✅ Reuses existing notification broadcast and WorkManager machinery; no new FGS, no Data Saver bypass, honest bounded latency.
- ✅ Preserves ADR-023 (official endpoint only, no new contract), ADR-003/ADR-049 boundaries except the single gated reply write, and ADR-049's identity/encryption discipline.
- ⚠ Residual duplicate-or-loss window at POST is inherent to OpenCode's missing idempotency key; bounded fail-closed retries limit but cannot eliminate it.
- ⚠ OAuth/Tailscale contexts cannot reply after process death until the user reopens CodeWalk; Data Saver pauses scheduling.
- ❌ Not eligible for Play automotive distribution; unresolved MF-5 eligibility is an accepted, explicitly tracked risk (issue #99).
- ❌ No custom UI, car-app templates, processing messages, custom STT/TTS, unlimited realtime, or background execution beyond the accepted envelope.

### Rollback / Cleanup

- **Feature rollback:** disable the Dart feature flag and/or the user preference; both are default-off, and disabling either stops the surface immediately.
- **Descriptor removal:** deleting the debug source-set automotive descriptor removes the Android Auto surface from all builds; no release artifact ever contains it (shared Dart code remains in release builds but stays inert).
- **Queue/data cleanup:** reply state and encrypted thread records are purged when the feature is disabled or the identity/session is removed; bounded retention applies while active.
- **Tests required:** process-death restore behavior, notification action/RemoteInput shape, prompt_async request contract (no `messageID`), auth gating (plain/Basic vs OAuth/Tailscale reopen-required), and Data Saver pause handling.

### ADR-023 Compatibility

This ADR is fully compliant with ADR-023 and is **not** an ADR-023 exception. It adds no OpenCode endpoint, request/response schema, realtime event, session/message mutation, authentication contract, or configuration mutation. Replies ride the official directory-scoped `POST /session/:id/prompt_async` exactly as the app's foreground send path does; confirmation uses bounded official status/message reconciliation only. All Android Auto presentation, gating, encryption, and scheduling are client-owned behavior.

### Key Files (Implemented)

- `lib/core/config/feature_flags.dart` — default-off Dart feature flag; the flag plus `kDebugMode` keeps the feature disabled at runtime in release builds.
- `lib/domain/entities/car_messaging.dart` — messaging entities/models (reply, message, thread state).
- `lib/data/car_messaging/` — bounded AES-256-GCM encrypted store (`car_messaging_store.dart`, `car_messaging_file_store*.dart`) for persisted replies and thread state.
- `lib/presentation/services/car_messaging/` — runtime (`car_messaging_runtime.dart`), action handler (`car_messaging_action_handler.dart`), notification construction (`car_messaging_notification.dart`), dispatch (`car_messaging_dispatch_worker.dart`), and gating (`car_messaging_gate.dart`).
- `lib/presentation/services/notification_service.dart` — `MessagingStyle` notification callback integration with exactly one reply `RemoteInput` and local mark-as-read action.
- `lib/presentation/services/android_background_alert_worker.dart` — WorkManager headless integration scheduling the official `prompt_async` send.
- `android/app/src/debug/` — automotive notification descriptor (`res/xml/automotive_app_desc.xml` + `AndroidManifest.xml`) in the debug source set only; never in `src/main/` or release artifacts.
- `test/unit/data/car_messaging_store_test.dart` — encrypted store coverage (process-death restore, bounded retention).
- `test/unit/services/car_messaging_*_test.dart` — notification/action shape, auth gating, dispatch worker, and manifest coverage.
- Ref: issue #99

---

## ADR-055: Production Android Auto Notification Messaging for Sideloaded APK Distribution (2026-08-13)

**Status**: Accepted

**Related**: GitHub issue #99; ADR-054 (superseded — release/debug gating portions), ADR-003 (realtime/background lifecycle), ADR-017 (Android foreground monitoring), ADR-023 (Official OpenCode Contract-First Compatibility Policy), ADR-049 (attention surfaces and background continuity), ADR-053 (client-owned API STT as the speech-backend precedent).

### Context

ADR-054 prototyped Android Auto notification messaging behind a double default-off gate and a debug-only automotive descriptor because Google Play automotive (MF-5) eligibility was unresolved and the feature was therefore treated as test-only. Two user clarifications remove that gating rationale:

1. **"Device off" means screen off/locked.** The phone remains powered on with the screen off/locked — which is inside ADR-054's accepted background envelope (process recreation, WorkManager headless path), not the excluded powered-off condition.
2. **Distribution is direct APK sideload, not Google Play.** Release APKs are installed by sideloading; there is no Play review, store listing, or MF-5 eligibility submission in the distribution path.

The Android Auto technical constraints from ADR-054 remain fully valid because they derive from Android Auto's rendering/input contract and OpenCode's official API — not from distribution: templates-only rendering, exactly one voice-reply `RemoteInput`, no custom UI/STT/TTS, constrained background execution after process death, and `prompt_async` without a client-supplied idempotency key.

### Decision

1. **Automotive descriptor ships in every release APK.** The automotive notification descriptor moves from `android/app/src/debug/` to the main source set — `android/app/src/main/res/xml/automotive_app_desc.xml` — wired in `android/app/src/main/AndroidManifest.xml`. The normal release APK, the only distributed artifact, includes the Android Auto messaging surface.

2. **Debug gating is removed.** Remove the `kDebugMode` runtime gate, the `CODEWALK_ANDROID_AUTO_MESSAGING` compile flag, and the `androidAutoMessagingEnabled` preference/UI toggle. Release builds are no longer inert carriers; car messaging is active behavior in release APKs.

3. **Automatic activation.** Car messaging runs automatically whenever Android background alerts are enabled (the existing background-alert master switch) and the technical gates pass (root-session identity available, supported auth envelope, bounded encrypted store operational). There is no separate automotive toggle.

4. **Preserved technical constraints (unchanged from ADR-054).** Plain/no-auth and Basic-authenticated hosts only after process death; OAuth/Tailscale-backed contexts are reopen-required; Data Saver pauses reply scheduling rather than bypassing it; replies persist in the bounded AES-256-GCM encrypted store; delivery rides honest WorkManager latency; replies are sent via the official directory-scoped `POST /session/:id/prompt_async` with no `messageID`; `MessagingStyle` renders only the settled final assistant response with exactly one reply `RemoteInput` plus local mark-as-read; no custom car UI, `CarAppService`/`androidx.car.app` templates, processing/intermediate messages, or custom microphone/STT/TTS; force-stop, powered-off, and pre-first-unlock states remain excluded and fail closed; no claim of Google Play automotive eligibility anywhere.

5. **Harmless preference cleanup.** The obsolete persisted `androidAutoMessagingEnabled` preference is ignored on load and dropped from the settings JSON on the next persist/save — no explicit migration or key removal, no user-visible effect.

6. **Rollback is not gated.** Rollback is descriptor/code removal or the existing background-alerts master switch — never hidden debug gates.

7. **Existing notification channel reuse.** `MessagingStyle` car notifications reuse the existing `codewalk_agent` notification channel — the same channel, with the same default importance/priority, used by standard completion alerts — so channel behavior (sound/importance/mute) is identical and independent of which producer (car messaging or standard completions) happens to create the channel first. The car alert replaces the standard notification only when a new car message is actually published; otherwise the standard completion fallback remains in place.

### Rationale

- **Sideload distribution removes the Play gate:** with direct APK sideload there is no Play review or MF-5 eligibility submission; keeping the descriptor debug-only would force users to install debug builds for no compliance benefit.
- **The clarified "device off" meaning is inside the accepted envelope:** screen off/locked with the phone powered on was always supported by ADR-054's background envelope; the powered-off exclusion is unchanged.
- **Automatic activation follows the existing master switch:** car messaging reuses the background-alerts switch users already understand, eliminating a second opt-in surface and a dead settings toggle.
- **Technical constraints are distribution-independent:** they come from Android Auto's templates/RemoteInput contract and OpenCode's missing idempotency key, so preserving them verbatim keeps ADR-023 compliance and the honest bounded-latency/fail-closed model.
- **Eligibility honesty is preserved:** sideloading removes Play review, but the app still makes no claim of Google Play automotive eligibility.

### Consequences

- ✅ Release APKs — the only distributed artifacts — include the Android Auto notification messaging surface.
- ✅ `kDebugMode` gating, the `CODEWALK_ANDROID_AUTO_MESSAGING` compile flag, and the `androidAutoMessagingEnabled` preference/UI toggle are removed.
- ✅ Car messaging activates automatically with Android background alerts when technical gates pass.
- ✅ All ADR-054 technical constraints preserved: plain/Basic-only post-process-death, OAuth/Tailscale frozen, Data Saver pause, encrypted bounded store, honest WorkManager latency, `prompt_async` without `messageID`, no custom car UI/templates/speech, excluded powered-off/force-stop/pre-first-unlock, no Play eligibility claim.
- ✅ Obsolete `androidAutoMessagingEnabled` preference is ignored on load and dropped from the settings JSON on the next persist/save; no user-visible effect.
- ✅ `MessagingStyle` car notifications reuse the existing `codewalk_agent` notification channel with the same default importance/priority as standard completion alerts, preserving users' existing Android channel sound/importance/mute settings regardless of which producer (car messaging or standard completions) creates the channel first.
- ✅ Rollback is simple: descriptor/code removal or the background-alerts master switch.
- ⚠ Residual duplicate-or-loss window at POST remains (OpenCode has no idempotency key); bounded fail-closed retries unchanged.
- ⚠ Release APKs now advertise the automotive messaging descriptor to any car system where installed; eligibility copy must stay accurate.
- ❌ Not eligible for (and does not claim eligibility for) Google Play automotive distribution; any future Play submission requires a separate eligibility review and ADR.

### Rollback / Cleanup

- **Master switch:** turning off Android background alerts stops car messaging immediately — no hidden debug gates.
- **Code/descriptor removal:** deleting the main-source-set automotive descriptor and the car-messaging code removes the surface from all builds.
- **Queue/data cleanup:** reply state and encrypted thread records are purged when the feature is disabled or the identity/session is removed; bounded retention applies while active.
- **Tests required:** descriptor presence in the main source set, release-build activation without flag/toggle, process-death restore, notification action/RemoteInput shape, `prompt_async` request contract (no `messageID`), auth gating (plain/Basic vs OAuth/Tailscale reopen-required), Data Saver pause handling, and `codewalk_agent` notification-channel reuse — same default importance/priority as standard completions, standard fallback retained unless a new car message is actually published.

### ADR-023 Compatibility

This ADR is fully compliant with ADR-023 and is **not** an ADR-023 exception — unchanged from ADR-054. It adds no OpenCode endpoint, request/response schema, realtime event, session/message mutation, authentication contract, or configuration mutation. Replies ride the official directory-scoped `POST /session/:id/prompt_async` exactly as the app's foreground send path does; confirmation uses bounded official status/message reconciliation only. All Android Auto presentation, encryption, and scheduling remain client-owned behavior.

### Key Files

- `android/app/src/main/res/xml/automotive_app_desc.xml` — automotive descriptor moved to the main source set (from `android/app/src/debug/`); shipped in every release APK.
- `android/app/src/main/AndroidManifest.xml` — descriptor wiring in the main manifest.
- `lib/presentation/services/car_messaging/` — runtime, action handler, notification construction, dispatch worker, and gating (gate source now = background alerts + technical gates).
- `lib/presentation/services/notification_service.dart` — `MessagingStyle` notification callback with exactly one reply `RemoteInput`, local mark-as-read, reusing the existing `codewalk_agent` notification channel.
- `lib/presentation/services/android_background_alert_worker.dart` — WorkManager headless integration scheduling the official `prompt_async` send.
- `lib/domain/entities/car_messaging.dart` — messaging entities/models (reply, message, thread state).
- `lib/data/car_messaging/` — bounded AES-256-GCM encrypted store for persisted replies and thread state.
- `lib/core/config/feature_flags.dart` — `CODEWALK_ANDROID_AUTO_MESSAGING` compile flag removed.
- `lib/domain/entities/experience_settings.dart` + settings UI — `androidAutoMessagingEnabled` preference and toggle removed; the obsolete persisted key is ignored on load and dropped from the settings JSON on the next persist/save.
- `test/unit/` — updated tests: descriptor/manifest presence in main source set, release activation without flag/toggle, encrypted store (process-death restore), notification/action shape, auth gating, dispatch worker, obsolete-preference ignored-on-load/dropped-on-persist, and `codewalk_agent` notification-channel reuse — same default importance/priority as standard completions, standard fallback retained unless a new car message is actually published.
- Ref: issue #99
