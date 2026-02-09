# Feature 010 - OpenCode Upstream Parity Baseline and Contract Freeze

## Goal
Establish a precise, implementation-ready parity contract between current CodeWalk and the latest OpenCode Server/Desktop/Web behavior so execution can be split safely across multiple features.

## Research Snapshot

- Analysis date: 2026-02-09
- Upstream repository snapshot: `anomalyco/opencode@24fd8c1` (`dev` branch, commit date 2026-02-09)
- Primary reference docs:
  - https://opencode.ai/docs/server/
  - https://opencode.ai/docs/models/
  - https://opencode.ai/docs/web/
  - https://github.com/anomalyco/opencode

## Source Evidence Collected

### 1. Server/API Surface (OpenCode)

- OpenAPI (`packages/sdk/openapi.json`) exposes **82 route paths**.
- Important route families beyond current CodeWalk usage:
  - Global scope: `/global/health`, `/global/event`, `/global/config`, `/global/dispose`
  - Session advanced: `/session/status`, `/session/{id}/children`, `/session/{id}/fork`, `/session/{id}/todo`, `/session/{id}/diff`, `/session/{id}/prompt_async`, `/session/{id}/command`, `/session/{id}/shell`, `/session/{id}/permissions/{permissionID}`
  - Interaction flow: `/permission`, `/permission/{requestID}/reply`, `/question`, `/question/{requestID}/reply`, `/question/{requestID}/reject`
  - Context/tooling: `/find/*`, `/file/*`, `/vcs`, `/lsp`, `/mcp/*`, `/experimental/worktree*`, `/pty*`

### 2. Event and Part Taxonomy (OpenCode v2 types)

Evidence from `packages/sdk/js/src/v2/gen/types.gen.ts`.

- Event coverage includes: `message.updated`, `message.part.updated`, `message.part.removed`, `session.status`, `session.error`, `session.created/updated/deleted`, `permission.asked/replied`, `question.asked/replied/rejected`, `todo.updated`, `session.diff`, `vcs.branch.updated`, `worktree.ready/failed`, etc.
- Part coverage includes:
  - `text`, `file`, `tool`, `reasoning`
  - `step-start`, `step-finish`, `snapshot`, `patch`
  - `subtask`, `agent`, `retry`, `compaction`
- Prompt payload supports `variant` (model variant/reasoning effort).

### 3. Desktop/Web Behavioral Parity Targets (OpenCode app)

Evidence from `packages/app/src/*` and `packages/app/e2e/*`.

- Multi-server management:
  - `context/server.tsx` + `components/dialog-select-server.tsx`
  - Supports list/add/edit/delete/default + periodic health checks.
- Model and variant control:
  - `context/models.tsx`, `context/local.tsx`, `components/prompt-input.tsx`
  - Supports provider/model switching and variant cycle in composer.
  - E2E: `e2e/thinking-level.spec.ts`, `e2e/models/model-picker.spec.ts`.
- Session lifecycle:
  - E2E: rename/archive/delete/share/unshare (`e2e/session/session.spec.ts`).
- Multi-project/workspace:
  - E2E: project switch/close + workspace create/rename/reset/delete/reorder (`e2e/projects/*.spec.ts`).

### 4. Official Docs Confirmation

- Server docs (`/docs/server`) confirm server mode route families and directory-scoped requests.
- Models docs (`/docs/models`) confirm:
  - model format: `provider/model`
  - variant format: `provider/model:variant`
  - model variants are used for “thinking effort” style controls.
- Web docs (`/docs/web`) explicitly link to server management in browser usage flow.

## Current CodeWalk Baseline (Gap Side)

### Endpoint Coverage (current Flutter client)

Current data sources use only this path set:

- `/path`, `/app`, `/app/init`
- `/provider`, `/config`
- `/project`, `/project/current`
- `/session`, `/session/{id}`, `/session/{id}/message`, `/session/{id}/message/{messageId}`
- `/session/{id}/share`, `/session/{id}/abort`, `/session/{id}/revert`, `/session/{id}/unrevert`, `/session/{id}/init`, `/session/{id}/summarize`
- `/event`

### State/UX Coverage

- Single server storage model (`server_host` + `server_port`) in `AppLocalDataSource` and `AppProvider`.
- No UI for model/provider switching in chat composer.
- No variant field in `ChatInput`/`ChatInputModel` payload.
- Event consumption handles only a narrow subset in `ChatRemoteDataSource.sendMessage()`:
  - `message.updated`, `message.part.updated`, `session.error`, `session.idle`, partial logging for removals.
- Session list actions are partially stubbed in UI:
  - rename dialog does not persist update call
  - share/unshare action is TODO in `chat_session_list.dart`.
- No global event orchestration (`/global/event`) and no server-scoped/project-scoped cache partitioning.

## Gap Matrix (Requested Scope)

| Requested area | Upstream reference state | Current CodeWalk state | Gap level | Planned features |
|---|---|---|---|---|
| Multi-server support | Full manager (add/edit/delete/default/health + persistence) | Single host/port only | Critical | 011, 015 |
| Receive messages + thinking + tools + related events | Broad event + part taxonomy, interactive permission/question flow | Partial event subset + partial part rendering | Critical | 013 |
| Change active model | Model/provider picker and persisted selection | Auto-select default only, no chooser UX | High | 012 |
| Change variant/reasoning effort | Variant cycle + payload `variant` | No variant state/payload/UI | High | 012 |
| Manage multiple sessions deeply | Rename/archive/share/fork/children/todo/diff/status | Basic list/create/delete/select | High | 014 |

## Proposed Implementation Principles

1. Build on v2 contract first (types/events/routes), then UX.
2. Keep compatibility fallbacks where practical (existing `/path`/legacy assumptions) but treat v2 as primary.
3. Partition persistent state by `server` and `directory` to prevent cross-context corruption.
4. Use event-first updates with targeted fetch fallback when stream payload is partial.
5. Expand test fixtures before heavy refactors to keep regression detection tight.

## Feature Decomposition Approved for ROADMAP.md

- Feature 010: parity baseline + contract freeze + migration checklist
- Feature 011: multi-server management and state partitioning
- Feature 012: model/provider picker + variant/reasoning controls
- Feature 013: event pipeline + part taxonomy + question/permission handling
- Feature 014: advanced session lifecycle management
- Feature 015: project/workspace multi-context parity
- Feature 016: hardening, QA, release readiness

## Contract Freeze (Signed)

Freeze date: 2026-02-09

This feature defines the parity contract baseline for the next delivery wave (features 011-016). This baseline is now considered locked and must be treated as implementation input, not a moving target, unless a new roadmap task explicitly updates it.

### 10.01 Target Snapshot Lock and Supported Range

Reference lock:

- Upstream source lock: `anomalyco/opencode@24fd8c1` (`dev`)
- OpenAPI source lock: `packages/sdk/openapi.json` from the same commit (82 route paths at snapshot time)
- Docs lock:
  - `https://opencode.ai/docs/server/`
  - `https://opencode.ai/docs/models/`
  - `https://opencode.ai/docs/web/`

Compatibility policy:

- Fully supported target: OpenCode servers that expose v2 route/event structures compatible with the locked sources above.
- Compatibility fallback target: older server-mode instances that still satisfy current critical bootstrap/session routes used by CodeWalk (`/path` or legacy `/app`, `/provider`, `/project/current`, `/session`, `/session/{id}/message`, `/event`).
- Unsupported target: instances missing any critical route above or returning incompatible payload shapes for core session/message entities.

Versioning note:

- OpenCode parity is commit/API-contract driven (not strict semver driven). CodeWalk therefore pins compatibility to upstream snapshot + schema behavior and keeps selective fallbacks for transition safety.

### 10.02 Required vs Optional Parity Matrix

#### Endpoint scope

| Surface | Required (parity wave) | Optional (post-wave) |
|---|---|---|
| App bootstrap/config | `/path`, `/provider`, `/config`, `/project`, `/project/current` (+ legacy `/app` fallback) | `/global/config`, `/global/dispose` |
| Core sessions/messages | `/session`, `/session/{id}`, `/session/{id}/message`, `/session/{id}/message/{messageId}`, `/event` | `/global/event` (deferred to feature 015 rollout stage) |
| Session lifecycle advanced | `/session/{id}/share`, `/session/{id}/abort`, `/session/{id}/revert`, `/session/{id}/unrevert`, `/session/{id}/init`, `/session/{id}/summarize`, `/session/status`, `/session/{id}/children`, `/session/{id}/fork`, `/session/{id}/todo`, `/session/{id}/diff` | `/session/{id}/command`, `/session/{id}/shell`, `/session/{id}/permissions/{permissionID}` |
| Interactive flows | `/permission`, `/permission/{requestID}/reply`, `/question`, `/question/{requestID}/reply`, `/question/{requestID}/reject` | Future extended decision trees not currently exercised by app/web parity tests |
| Context/tooling | `/find/*`, `/file/*`, `/vcs`, `/mcp/*` (read-only parity paths first) | `/lsp`, `/experimental/worktree*`, `/pty*` |

#### Event scope

| Category | Required (parity wave) | Optional (post-wave) |
|---|---|---|
| Message lifecycle | `message.updated`, `message.part.updated`, `message.part.removed`, `message.removed` | Low-value informational events unrelated to visible chat timeline |
| Session lifecycle | `session.created`, `session.updated`, `session.deleted`, `session.status`, `session.error`, `session.idle` | Rare maintenance/status events that do not impact visible UI state |
| Human-in-loop | `permission.asked`, `permission.replied`, `question.asked`, `question.replied`, `question.rejected` | Non-blocking advisory prompts without required user response |
| Work context | `todo.updated`, `session.diff`, `vcs.branch.updated`, `worktree.ready`, `worktree.failed` | Provider/internal diagnostics events not rendered in first parity wave |

#### Part taxonomy scope

| Category | Required (parity wave) | Optional (post-wave) |
|---|---|---|
| Already implemented core | `text`, `file`, `tool`, `reasoning`, `patch` | None |
| Must be completed in parity wave | `step-start`, `step-finish`, `snapshot`, `subtask`, `agent`, `retry`, `compaction` | Experimental part kinds introduced after snapshot |

#### UX scope

| Area | Required (parity wave) | Optional (post-wave) |
|---|---|---|
| Server management | Multi-server list/add/edit/delete/active/default/health | Advanced telemetry dashboards |
| Model controls | Provider/model picker + variant (reasoning effort) switching and persistence | Per-tool model overrides |
| Session operations | Rename/archive/share/unshare/delete/fork/children/todo/diff/status | Bulk operations and power-user batch flows |
| Workspace context | Project/workspace switching with directory-scoped isolation | Full worktree orchestration parity on day one |

### 10.04 Persisted State Migration Strategy

Current persisted keys (v1 flat storage):

- `server_host`, `server_port`
- `api_key`
- `selected_provider`, `selected_model`
- `current_session_id`, `last_session_id`
- `cached_sessions`, `cached_sessions_updated_at`
- `basic_auth_enabled`, `basic_auth_username`, `basic_auth_password`

Target persisted layout (v2 scoped storage):

- Global keys:
  - `storage_schema_version`
  - `server_profiles`
  - `active_server_id`
  - `default_server_id`
  - `migration_v1_to_v2_completed`
- Server-scoped keys:
  - `v2.server.<serverId>.auth.api_key`
  - `v2.server.<serverId>.auth.basic.*`
- Server + directory scoped keys:
  - `v2.server.<serverId>.dir.<directoryHash>.selected_provider`
  - `v2.server.<serverId>.dir.<directoryHash>.selected_model`
  - `v2.server.<serverId>.dir.<directoryHash>.selected_variant`
  - `v2.server.<serverId>.dir.<directoryHash>.current_session_id`
  - `v2.server.<serverId>.dir.<directoryHash>.cached_sessions`
  - `v2.server.<serverId>.dir.<directoryHash>.cached_sessions_updated_at`

Migration execution checklist:

1. Add schema version key and idempotent migration guard.
2. Build default server profile from v1 (`server_host`, `server_port`, auth keys).
3. Move model/session/cache keys into scoped namespace for the active directory context.
4. Keep one-release read fallback for v1 keys when v2 keys are missing.
5. Never delete v1 keys during first release containing migration.
6. Add telemetry/log marker for migration success/failure to support rollback diagnosis.
7. Remove v1 fallback only after at least one stable release cycle.

Rollback safety:

- If migration fails mid-flight, keep app operable in read-only fallback from v1 flat keys.
- Migration must be restart-safe and idempotent (safe to rerun without data duplication).

## Feature 010 Completion Checklist

- [x] 10.01 Snapshot lock + supported compatibility range defined
- [x] 10.02 Required vs Optional parity matrix defined
- [x] 10.03 `CODEBASE.md` integration taxonomy aligned with v2 baseline (see feature commit)
- [x] 10.04 Persisted-state migration strategy and rollback rules documented

## Open Risks to Resolve Early

1. Backward compatibility policy for older server responses vs strict v2 behavior.
2. SSE resilience strategy on mobile networks (drop/reconnect/pending updates).
3. Scope control: keep parity priorities focused on user-visible blockers first.
4. Migration safety for existing local storage keys when moving to multi-server storage.
