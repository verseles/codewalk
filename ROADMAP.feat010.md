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

## Open Risks to Resolve Early

1. Backward compatibility policy for older server responses vs strict v2 behavior.
2. SSE resilience strategy on mobile networks (drop/reconnect/pending updates).
3. Scope control: keep parity priorities focused on user-visible blockers first.
4. Migration safety for existing local storage keys when moving to multi-server storage.
