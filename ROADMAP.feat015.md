# Feature 015 - Project/Workspace Context Parity

## Goal
Support robust multi-project and workspace/worktree workflows in CodeWalk, with strict directory-scoped request routing and state isolation comparable to OpenCode desktop/web behavior.

## Why This Exists

OpenCode server mode is directory-aware and upstream clients actively switch project/workspace contexts. Current CodeWalk has a basic project provider but does not provide full multi-context orchestration.

## Research Snapshot

- Upstream commit: `anomalyco/opencode@24fd8c1`.
- Primary files reviewed:
  - `packages/app/e2e/projects/workspaces.spec.ts`
  - `packages/app/e2e/projects/projects-switch.spec.ts`
  - `packages/app/e2e/projects/projects-close.spec.ts`
  - `packages/app/src/context/global-sync.tsx`
  - `packages/app/src/context/global-sync/child-store.ts`
  - `packages/app/src/context/global-sync/event-reducer.ts`
  - `packages/sdk/js/src/v2/gen/types.gen.ts` (`/global/event`, worktree endpoints)
- Local baseline reviewed:
  - `lib/presentation/providers/project_provider.dart`
  - `lib/data/datasources/project_remote_datasource.dart`
  - current use of `directory` query in chat/app datasources.

## Upstream Behavior (Reference)

### Context orchestration model

- Global stream + per-directory child stores.
- Store caches keyed by workspace/directory via persisted namespaces.
- Directory pin/eviction logic prevents unlimited memory growth.

### Project/workspace UX (e2e)

- switch between projects.
- close projects from sidebar/header.
- enable workspace mode.
- create/rename/reset/delete/reorder workspaces.

### Relevant APIs

- `GET /project`, `GET /project/current`, `PATCH /project/{projectID}`
- `GET /global/event`
- `POST/GET/DELETE /experimental/worktree`
- `POST /experimental/worktree/reset`

## Current CodeWalk Baseline (Gap)

- Project provider can load list/current and switch simple current project.
- No advanced workspace/worktree operations in UI.
- No global event stream reducer architecture.
- Request `directory` is partially supported in some datasources, not treated as a primary orchestration axis.
- Cache keys are not fully partitioned by server+directory combinations.

## Scope

### In scope

- Project switcher UX with explicit active context.
- Workspace/worktree operation support where server supports it.
- Directory-scoped request consistency and state isolation.
- Global + per-directory synchronization strategy.
- Automated tests for context switching and isolation.

### Out of scope

- Full upstream drag-and-drop workspace ordering in first iteration.
- Non-core project customization not needed for chat parity.

## Implementation Blueprint

### 1. Context key strategy

Define canonical context key:

- `contextKey = <serverId>::<directory>`

All caches and transient stores should be keyed by context key.

### 2. Routing and data loading

Ensure all relevant requests pass `directory` when context is set:

- app bootstrap (`/path`, `/provider`, `/config`).
- sessions/messages/actions.
- permission/question/status queries once introduced.

### 3. Workspace/worktree operations

Add service/use cases for:

- list worktrees.
- create worktree.
- reset worktree.
- remove worktree.

Expose UI actions in project/session navigation region.

### 4. Event and sync model

Introduce a sync coordinator:

- subscribes to global events.
- routes directory-scoped events to correct context store.
- invalidates only affected context caches.

### 5. Project provider evolution

Evolve `ProjectProvider` from single current project holder to:

- list of open contexts.
- active context selection.
- close/remove context behavior.

## API Contract Notes

- `directory` query parameter is central to safe multi-context behavior.
- Worktree endpoints are currently under `/experimental/worktree*`; feature should gate UI based on endpoint support.

## Test Strategy

### Unit tests

- context key generation and cache partitioning.
- state transitions when switching active project/workspace.

### Widget tests

- project switcher updates visible sessions.
- workspace create/reset/delete actions update UI.

### Integration tests

- two directories with distinct session sets:
  - switch contexts repeatedly and verify isolation.
- create/reset/delete workspace behavior with mock server support.

## Manual QA Checklist

1. Open two projects and switch back/forth with active chat loaded.
2. Verify session list and selected model remain tied to context.
3. Create workspace from project, send chat there, switch out and back.
4. Reset workspace and validate expected state cleanup.
5. Remove workspace and ensure navigation fallback is stable.

## Risks and Mitigations

1. Risk: stale events applied to wrong context.
   - Mitigation: event router with strict directory matching.
2. Risk: memory growth from too many context stores.
   - Mitigation: LRU/TTL eviction strategy inspired by upstream.
3. Risk: unsupported worktree endpoints on some servers.
   - Mitigation: capability probing and feature flags in UI.

## Execution Plan (mapped to ROADMAP tasks)

- `15.01` project switcher and current-context UX.
- `15.02` workspace/worktree operations integration.
- `15.03` directory scoping audit and enforcement.
- `15.04` global + child sync architecture.
- `15.05` context-isolation test suite.

## Definition of Done

- Users can switch project/workspace contexts without state leakage.
- Directory-scoped requests are consistent across all chat/session operations.
- Workspace operations are functional where supported.
- Automated tests validate isolation and context transitions.

## Source Links

- https://github.com/anomalyco/opencode
- https://opencode.ai/docs/server/

