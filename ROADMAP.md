---
roadmap: "CodeWalk Solo Migration Roadmap"
created_on: "2026-02-09"
execution_mode: "feature-by-feature"
source_project: "https://github.com/easychen/openMode"
---

## Execution Protocol

1. Trigger command pattern: `implement feat XXX now` (example: `implement feat 006 now`).
2. During execution:
   - mark active tasks as `[~]`,
   - mark completed tasks as `[x]`,
   - mark blocked tasks as `[/]` with blocker reason.
3. Complete all tasks in `ROADMAP.featXXX.md` before moving to the next feature unless a blocker is explicit.
4. After full completion of a feature, summarize implementation in `ROADMAP.md` and keep only necessary long-form notes.

## Task List

### Feature 001: Baseline Audit, Safety Rails, and Deletion Policy
Description: Build an objective baseline of the current fork (code, docs, endpoints, tests, platform support) and define hard safety rails before touching implementation.

Completed a full baseline inventory of source/runtime/docs/platform state, defined deletion and retention policies for generated and markdown artifacts, and established rollback checkpoints plus dependency and acceptance-gate governance for all later features.
Commits: b9de67f, 7d7e6f6, 3640fb2, d307731, c96f53c

### Feature 002: Licensing Migration to AGPLv3 + Commercial (>500M Revenue)
Description: Replace MIT with a compliant AGPLv3 setup and add a separate commercial license track for organizations above the revenue threshold.

Completed legal migration from MIT to AGPLv3, added a dedicated commercial license track for organizations above the revenue threshold, published attribution/warranty notices, and validated dependency licensing compatibility with unresolved decisions documented.
Commits: 2b51dd3, f0bc342, 898889f, b5e1719, a25cb31

### Feature 003: Rebrand OpenMode -> CodeWalk (Code, Package IDs, Metadata)
Description: Rename all product-facing and package-level identifiers from OpenMode/open_mode to CodeWalk/codewalk across app runtime, build metadata, and distribution assets.

Completed product and package rebranding from OpenMode to CodeWalk across Flutter metadata, source imports, Android namespace/applicationId, and web manifest/title/PWA references, followed by smoke validation to catch rename regressions.
Commits: 9483801, ede3939, a519f8f, 63549d4

### Feature 004: Full English Standardization (UI, Code Comments, Docs)
Description: Translate all remaining non-English content to English, including user-facing strings, comments, logs, and technical documentation.

Completed English standardization for UI strings, runtime messaging, source comments, and retained technical docs. Automated language regression checks were intentionally marked as a wont-do based on product decision.
Commits: 1bc9184

### Feature 005: Documentation Restructure and Markdown Pruning
Description: Remove unnecessary markdown files, consolidate surviving docs, and rewrite README with explicit origin attribution to OpenMode.

Completed documentation triage and consolidation by classifying markdown assets, merging unique technical history into `CODEBASE.md`, rewriting `README.md` for the CodeWalk identity with origin attribution, and pruning redundant files without knowledge loss.
Commits: 8562850, 7c72e70, b219a2b, d02f486

### Feature 006: OpenCode Server Mode API Refresh and Documentation Update
Description: Align the client and internal API docs with the latest OpenCode Server Mode endpoints/schemas and close compatibility gaps.

Completed a full Server Mode compatibility refresh through endpoint gap mapping, model/datasource/use-case updates for schema drift, and replacement of obsolete integration docs with a versioned guide; validated live against `100.68.105.54:4096` across provider, session, event, and message paths including nested-model parsing fixes.
Commits: e994f39, bbadbe4, 78acc18, ad6470c

### Feature 007: Cross-Platform Desktop Enablement and Responsive UX
Description: Expand project target platforms beyond mobile and deliver a true cross experience for desktop/web/mobile with adaptive layouts and desktop-native interactions. (Visit file ROADMAP.feat007.md for full research details)

- [x] 7.01 Add desktop platforms (Windows/macOS/Linux) to Flutter project - Enabled desktop flags and generated `linux/`, `macos/`, `windows/` via Flutter tooling
- [x] 7.02 Implement responsive layout breakpoints (mobile drawer vs desktop split view) - `ChatPage` now adapts with mobile drawer (`<840`), split desktop (`>=840`), and large-desktop utility panel (`>=1200`)
- [x] 7.03 Add desktop input ergonomics (shortcuts, hover/focus polish, resize behavior) - Added `Ctrl/Cmd+N`, `Ctrl/Cmd+R`, `Ctrl/Cmd+L`, `Esc`; external input focus control; desktop hover/cursor polish in session list
- [/] 7.04 Validate build/run on each target and document platform-specific caveats - Linux/web validation passed (`flutter test`, `flutter build linux`, `flutter build web`, Linux runtime smoke). Blocked for full target matrix by host OS constraint (`flutter build windows` requires Windows host, `flutter build macos` requires macOS host)

### Feature 008: Manual QA Campaign and Stability Hardening
Description: Execute a structured manual test campaign across supported platforms and critical user journeys, then fix high-impact defects before automation is expanded.

Completed a structured QA campaign with defined matrix and scenario IDs, executed scripted smoke coverage against live server flows, fixed P1 defects (secure logging leak and Android AGP build blocker), and published release readiness with known limitations.
Commits: da2940b, cc5c78f

### Feature 009: Automated Test Suite and CI Quality Gates
Description: Build comprehensive automated tests (unit, widget, integration) and enforce quality gates in CI so future changes remain stable.

Implemented a layered automation baseline with unit tests for model parsing/use case delegation/provider state transitions, widget tests for responsive chat shell and send-message flow, and integration tests against a controllable local mock OpenCode server including session CRUD, app/provider bootstrap calls, SSE message updates, and 400 validation error mapping. Added CI workflow gates for phased static analysis budget, full test execution with coverage generation, and minimum coverage threshold enforcement scripts, plus a race-condition fix in chat SSE handling so pending message fetches are not dropped when the event stream closes.
Commits: 5125edd

### Feature 010: OpenCode Upstream Parity Baseline and Contract Freeze
Description: Consolidate the latest OpenCode Server/API/Desktop/Web behavior into a single compatibility contract for CodeWalk implementation planning. (Visit file ROADMAP.feat010.md for full research details)

Completed a signed parity contract baseline using a fixed upstream/docs/OpenAPI snapshot, defined Required vs Optional parity scope across endpoint/event/part/UX surfaces, aligned `CODEBASE.md` to the v2 taxonomy for implementation work, and documented a rollback-safe persisted-state migration strategy from flat keys to server/directory-scoped storage.

- [x] 10.01 Lock target reference snapshot (`opencode.ai` docs + upstream commit + OpenAPI) and define supported server versions/range
- [x] 10.02 Define parity matrix (`endpoint + event + part type + UX behavior`) with Required vs Optional scope
- [x] 10.03 Align local docs (`CODEBASE.md` integration section) with v2 route/event taxonomy before feature implementation begins
- [x] 10.04 Define migration strategy for persisted client state (server profiles, model selection, session cache)

### Feature 011: Multi-Server Management and Health Orchestration
Description: Implement first-class support for multiple OpenCode servers (desktop/mobile parity), including active/default server routing and health-aware switching. (Visit file ROADMAP.feat011.md for full research details)

Completed multi-server orchestration end-to-end with persisted `ServerProfile` migration from legacy host/port keys, health-aware activation/default selection, scoped runtime persistence (`serverId` + contextual scope) for chat/session/model state isolation, and full UI/server-switch integration from app bar and settings. Added unit/widget/integration coverage validating migration, duplicate normalization, unhealthy switch blocking, and cache isolation across active server switches.

- [x] 11.01 Introduce `ServerProfile` storage (list, add/edit/remove, active, default) replacing single `host/port` persistence
- [x] 11.02 Build server manager UI (`add`, `edit`, `delete`, `set default`, `health badge`, `connectivity validation`)
- [x] 11.03 Scope runtime state/caches per server (projects, sessions, model preferences, auth settings) to avoid cross-server pollution
- [x] 11.04 Add unit/widget/integration coverage for server switching, invalid server handling, and fallback behavior

### Feature 012: Model/Provider Switching and Variant (Reasoning Effort) Controls
Description: Bring model control parity with OpenCode Desktop/Web, including current-model changes and model variant/reasoning-effort changes. (Visit file ROADMAP.feat012.md for full research details)

Completed model-control parity foundations by adding provider/model picker controls in the composer area, variant/reasoning cycling with model-aware validation, and outbound payload parity through `variant` serialization for message sends. Extended server-scoped persistence to include variant maps plus recent/frequent model history and restore logic; expanded unit/widget/integration tests to cover parsing, selection, cycling, payload assertions, and no-variant backward compatibility.

- [x] 12.01 Add provider/model picker in chat composer flow and persist user selections
- [x] 12.02 Parse/provider model variants from `/provider` and expose current variant state in UI
- [x] 12.03 Add variant/reasoning-effort cycle action and include `variant` field in outbound prompt payloads
- [x] 12.04 Persist recent/frequent model usage (server-scoped) and restore safely across launches
- [x] 12.05 Add tests for model switch, variant switch, and backward compatibility when variants are absent

### Feature 013: Event Stream and Message-Part Parity (Messages, Thinking, Tools, Questions, Permissions)
Description: Expand real-time event handling to match OpenCode v2 event/part taxonomy and reliably render message lifecycle details. (Visit file ROADMAP.feat013.md for full research details)

Completed realtime parity foundations with resilient SSE subscription (`/event`) including reconnect/backoff handling, provider-level event reducer for session/message/status/permission/question flows, and fallback full-message fetch on partial/delta scenarios. Expanded part taxonomy parsing/rendering for step/snapshot/subtask/retry/compaction/agent/patch types, added interactive permission/question cards with response endpoints, and covered behavior through unit/widget/integration tests (including event-matrix + reconnect scenarios).

Applied a post-completion stabilization fix to forward `directory` scope through send-message streaming (`/event` and `/session/{id}/message/{messageId}` fetch fallback), resolving cases where responses stayed in thinking-only state when server routing required directory-scoped events.
Added an additional stabilization pass with release-visible send lifecycle logs in Logs tab and assistant-message-ID recovery via `/session/{id}/message` when stream events are unavailable, improving field diagnosis for intermittent SSE failures.
Added watchdog fallback for cases where `/event` stays connected without message events, and removed duplicate realtime subscriptions by fixing a provider-level race in event subscription startup.
Applied send-payload correction for normal prompts: stop sending `messageID` in standard message creation requests to prevent stale repeated assistant IDs from server immediate responses.
Hardened provider send setup with step logs and best-effort local selection persistence so storage-layer failures cannot block outbound send stream subscription.
Fixed a send-path crash triggered by fixed-length restored recent-model lists (`Unsupported operation: Cannot remove from a fixed-length list`) before repository dispatch.

- [x] 13.01 Harden SSE layer (reconnect, backoff, stale subscription guard, fetch fallback) for long-running sessions
- [x] 13.02 Support full high-value event set (`message.*`, `session.status`, `session.error`, `permission.*`, `question.*`) in provider state
- [x] 13.03 Expand part parsing/rendering coverage (`step-start`, `step-finish`, `snapshot`, `subtask`, `retry`, `compaction`, `agent`, `patch`)
- [x] 13.04 Add permission/question response UX for interactive tool flows
- [x] 13.05 Add integration tests with mocked event matrix and partial/delta update scenarios

### Feature 014: Advanced Session Lifecycle Management
Description: Upgrade session operations beyond basic CRUD to parity-level management for active and historical work.

Completed full session lifecycle parity implementation across domain/data/provider/UI layers: added end-to-end rename/archive/unarchive/share/unshare/delete with optimistic local updates + rollback, implemented fork/status/children/todo/diff capabilities with provider-level insight reconciliation, and expanded session list UX with search/filter/sort/load-more controls suitable for large histories. Also extended event reducer handling for `todo.updated` and `session.diff`, hardened session ordering/cache persistence behavior, and added lifecycle-focused unit/widget/integration tests with controlled server fixtures.

- [x] 14.01 Implement rename/archive/share/unshare/delete flows end-to-end (API + UI + optimistic update + rollback)
- [x] 14.02 Add session fork/children/todo/diff/status capabilities where supported by server
- [x] 14.03 Implement robust session list UX (sorting, filtering/search, scalable loading strategy)
- [x] 14.04 Add session timeline/history quality (state reconciliation across updates and navigation)
- [x] 14.05 Cover session lifecycle operations with integration tests against controlled server fixtures

### Feature 015: Project/Workspace Context Parity
Description: Support multi-project and workspace/worktree workflows using directory-aware API/event orchestration. (Visit file ROADMAP.feat015.md for full research details)

Completed project/workspace parity across domain/data/provider/UI layers with deterministic context isolation (`serverId::directory`), project switcher UX with active context controls (switch/close/reopen/refresh), worktree lifecycle operations (`create/reset/delete/open`), and directory-scoped routing for provider/session/message/event calls. Added global-context synchronization via `/global/event` with dirty-context invalidation and scoped snapshot restore, plus expanded unit/widget/integration coverage for project switching, worktree routes, global event ingestion, and server-scoped cache isolation under context transitions.
Applied a post-completion chat UX refinement so conversation view opens at the latest message and exposes a jump-to-latest FAB that is visually highlighted when new messages arrive while the user is reading older content.
Adjusted project-context switching to auto-open the last session per directory (with fallback to most recent when no stored selection exists), reducing empty-state friction during A/B project navigation.
Aligned main navigation with chat-first workflow by moving `Chat / Logs / Settings` controls to the top of the conversations sidebar and making `Logs`/`Settings` secondary routes with explicit back navigation to chat.
Refined the sidebar navigation style to match area semantics: removed explicit `Chat` action and kept a compact one-line row with actionable `Logs` and `Settings` buttons only.
Fixed a new-session UX regression where `New Chat` could create sessions without switching focus: directory-scoped session lists are now kept mutable and new-session creation explicitly persists/selects the newly created session.
Fixed a visual duplicate-send issue where a local optimistic user bubble and server-confirmed user message could appear together; confirmed messages now replace pending local bubbles when content/session/time match.
Unified provider/model controls into a single searchable selector grouped by provider, with compact closed-state label showing only the active model name.
Refined selection UX so model/provider uses searchable bottom sheet (with alphabetical providers + 3 recent models), while reasoning effort uses a fast anchored popup selector; also removed the outer border wrapper around both selector chips.
Clarified workspace creation UX by allowing users to choose an explicit base directory in the "Create workspace" dialog, instead of always using the current context directory implicitly.
Added explicit workspace-operation telemetry in app logs (`create/reset/delete` start/success/failure + provider error mirroring) to diagnose silent failures directly from the Logs tab.
Added dynamic folder browsing for workspace creation (server-backed directory picker via `/file`) with preflight Git validation (`/vcs`) to prevent non-git workspace attempts.
Added explicit git-only warning inside directory picker and reinforced post-create context switch so newly created workspaces open immediately.

- [x] 15.01 Implement project switcher UX with explicit current-context indicator and close/reopen behaviors
- [x] 15.02 Add workspace/worktree operations (`create`, `reset`, `delete`) where server exposes corresponding routes
- [x] 15.03 Adopt `directory` scoping consistently for requests and event routing to avoid cross-context bleed
- [x] 15.04 Introduce global-context sync strategy (`/global/event` + per-directory stores) with deterministic cache invalidation
- [x] 15.05 Add tests for project/workspace switching, context isolation, and stale-state race conditions

### Feature 016: Reliability Hardening, QA, and Release Readiness for Parity Wave
Description: Validate and harden all parity features with measurable quality gates before production rollout.

Completed parity hardening and release readiness by expanding regression coverage across unit/widget/integration suites (including server-scoped model restore and question-reject flows), executing the `PAR-001..PAR-008` QA matrix with reproducible artifacts, and finalizing architecture/release documentation (`ADR.md`, `CODEBASE.md`, `RELEASE_NOTES.md`, `QA.feat016.release-readiness.md`). Final rollout gates were validated via `make precommit`, coverage gate pass at 59.44%, and Linux/Web release builds, with one documented non-product host limitation (Android emulator startup failure code `-6`) mitigated by successful APK build/upload validation.
Applied a post-release chat composer enhancement: implemented image/PDF attachments in the input flow (`file_picker` + `file` parts with `mime`/`url`) and gated attachment UI visibility by selected model capabilities so unsupported models hide the attachment action.
Refined attachment capability handling to be modality-aware per model (`image` vs `pdf`), so the attachment sheet now shows only supported options instead of exposing unsupported file types.
Added voice-to-text input in the chat composer using `speech_to_text`, with a dedicated microphone action beside send and Android speech-recognition permission/query wiring for device compatibility.
Enhanced composer send affordance with a secondary hold action: pressing send for 300ms inserts a newline instead of sending, plus a small corner icon to signal this behavior in the button UI.
Restored assistant progress feedback during response generation by showing staged indicators in the message list (`Thinking...`, `Receiving response...`, `Retrying model request...`) driven by send state, `session.status`, and in-progress assistant message parts.
Removed inline `Step started`/`Step finished` assistant blocks from the message body and moved their metadata to the assistant info menu (`i` icon) in the message header for a cleaner response flow.
Enabled selectable text for assistant and user messages, removed dedicated inline copy buttons, and added double-tap/double-click full-text copy behavior directly on each text block.
Commits: d568f22, 47ecddb, 3081b2e, b65f7f6, afb63be

## Dependency Order

1. Feature 001 -> blocks all other features (baseline + safety rails)
2. Feature 002 -> should finish before publishing docs/release artifacts
3. Feature 003 -> should happen before broad documentation rewrites
4. Feature 004 -> should happen before final markdown pruning
5. Feature 005 -> should happen before API documentation refresh
6. Feature 006 -> should happen before desktop/manual/automation validation
7. Feature 007 -> should happen before full manual QA campaign
8. Feature 008 -> should happen before final CI quality thresholds
9. Feature 009 -> provides regression safety net for parity expansion
10. Feature 010 -> defines parity contract and scope boundaries for all upcoming implementation
11. Feature 011 -> depends on 010 and establishes server orchestration foundation
12. Feature 012 -> depends on 010/011 for model persistence and active-server context
13. Feature 013 -> depends on 010 and should land before advanced session UX
14. Feature 014 -> depends on 013 event fidelity and 012 model controls
15. Feature 015 -> depends on 011 + 013 to safely support multi-context orchestration
16. Feature 016 -> final hardening/release gate for features 011-015

## Legend

- [x] Done
- [~] In progress now
- [/] Partially done but blocked
- [!] Won't do (with reason)
- [ ] Not started

## Acceptance Gates

| Feature | Entry Gate | Exit Gate |
|---------|-----------|-----------|
| 001 | None | CODEBASE.md + Makefile + doc classification + ADR + gates defined |
| 002 | 001 complete | LICENSE AGPLv3 + LICENSE-COMMERCIAL.md + NOTICE + dep compatibility verified |
| 003 | 002 complete | All IDs renamed + `flutter analyze` no new errors + smoke test build |
| 004 | 003 complete | Zero CJK strings in `lib/` + `flutter analyze` clean |
| 005 | 004 complete | README rewritten + docs consolidated + no orphan MD files |
| 006 | 005 complete | Gap matrix closed + models updated + validated against real server |
| 007 | 006 complete | Desktop builds OK + responsive layout + keyboard shortcuts working |
| 008 | 007 complete | Test matrix executed + P0/P1 fixed + readiness report published |
| 009 | 008 complete | Unit/widget/integration tests + CI pipeline + coverage thresholds |
| 010 | 009 complete | Signed parity contract + endpoint/event/UX gap matrix + migration checklist |
| 011 | 010 complete | Multi-server profile management + active/default switching + server-scoped state isolation |
| 012 | 010, 011 complete | User can switch model/provider + switch variant/reasoning effort + payload parity validated |
| 013 | 010 complete | Stable SSE/event engine + expanded part rendering + interactive question/permission handling |
| 014 | 012, 013 complete | Session lifecycle parity (rename/archive/share/fork/etc.) with passing API/UI tests |
| 015 | 011, 013 complete | Reliable project/workspace context switching with directory-isolated state |
| 016 | 011-015 complete | QA signoff + docs/ADR/CODEBASE updates + release checklist complete |
