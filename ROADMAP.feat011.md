# Feature 011 - Multi-Server Management and Health Orchestration

## Goal
Implement first-class support for multiple OpenCode servers in CodeWalk, with safe switching, default server selection, connectivity health monitoring, and strict server-scoped state isolation.

## Why This Exists

The current app stores a single `host:port` pair and binds all runtime state to one server. Upstream OpenCode desktop/web already supports:

- Multiple server entries.
- Active server switching.
- Default server selection.
- Health status checks and health-aware server ordering.

This feature builds the foundation for all parity work that depends on context switching.

## Research Snapshot

- Upstream commit: `anomalyco/opencode@24fd8c1` (2026-02-09).
- Primary files reviewed:
  - `packages/app/src/context/server.tsx`
  - `packages/app/src/components/dialog-select-server.tsx`
  - `packages/app/src/components/status-popover.tsx`
  - `packages/app/src/utils/server-health.ts`
  - `packages/app/e2e/app/server-default.spec.ts`

## Upstream Behavior (Reference)

### Server state model

- `server.tsx` persists:
  - server `list`
  - active server
  - per-server open projects metadata
  - `currentSidecarUrl`
- URL normalization:
  - adds `http://` when missing
  - strips trailing slashes

### Health checks

- `server-health.ts` checks `/global/health`.
- Retries transient network errors.
- Timeout defaults to 3 seconds.
- Periodic health refresh every 10 seconds in UI contexts.

### UX capabilities

- Server dialog supports: add, edit, remove, set as default, clear default.
- Prevents selecting servers explicitly marked unhealthy.
- Status popover prioritizes active + healthy servers.
- Web default server persisted in local storage.

## Current CodeWalk Baseline (Gap)

- Single server config only:
  - `AppProvider` tracks `_serverHost` + `_serverPort`.
  - `AppLocalDataSource` stores `server_host` + `server_port`.
- No server list, no default server concept, no active-server switcher.
- No health polling endpoint (`/global/health`) integration.
- All caches currently implicit/global (sessions/model selections not partitioned by server).

## Scope

### In scope

- Multi-server profile persistence and migration from single-host keys.
- Active/default server switching.
- Server health checks + periodic refresh.
- Server management UI and actions.
- Server-scoped cache partitioning strategy.
- Automated tests for server management and switching.

### Out of scope

- OAuth/provider auth UX (covered in later features).
- Deep session/workspace logic (covered in Features 014/015).

## Implementation Blueprint

### 1. Data model and storage migration

Introduce `ServerProfile`:

- `id` (stable UUID/local id)
- `url` (normalized)
- `label` (display alias, optional)
- `basicAuthEnabled`
- `basicAuthUsername`
- `basicAuthPassword`
- `createdAt`, `updatedAt`

New persisted object:

- `server_profiles` (list)
- `active_server_id`
- `default_server_id`

Migration path:

1. On first boot with new code:
   - if old keys `server_host` and `server_port` exist and no profiles exist:
     - create one profile from old data.
     - set it as active and default.
2. Keep old keys read-only for one compatibility cycle.
3. Stop writing old keys after migration success.

### 2. Network orchestration

Create server-switch use case in app layer:

- update `DioClient` base URL when active server changes.
- apply server-specific auth headers.
- trigger lightweight health check and bootstrap refresh.

Health check strategy:

- Primary: `GET /global/health`.
- Fallback for older servers: `GET /path` success implies reachable.

### 3. UI additions

Add server manager screen/dialog:

- list entries with health badge (`healthy`, `unknown`, `unhealthy`).
- actions:
  - add server
  - edit server URL/auth
  - remove server
  - set default
  - set active
- validation:
  - URL normalization + duplicate prevention
  - optional online check before save

Add compact server switch control in app shell/top bar:

- current server name.
- quick switch menu.
- entry point to full manager.

### 4. State isolation

Define storage namespace by server id:

- sessions cache key becomes `cached_sessions::<serverId>::<projectOrDir>`
- current session key becomes `current_session_id::<serverId>::<projectOrDir>`
- selected provider/model keys become server-scoped (and later directory-scoped where needed)

No data from server A can appear when server B is active.

## API Contract Notes

- Health check:
  - `GET /global/health` (v2 preferred)
  - `GET /path` fallback
- Existing app bootstrap endpoints remain:
  - `/path`, `/provider`, `/config`

## Test Strategy

### Unit tests

- URL normalization and duplicate detection.
- migration from old host/port keys into profile list.
- active/default selection rules.

### Widget tests

- server manager list rendering with mixed health states.
- add/edit/remove/default flows.
- blocked selection behavior when server is unhealthy.

### Integration tests (mock server)

- switch between two mock servers and verify:
  - base URL update.
  - sessions list changes to matching server.
  - cached data stays isolated.

## Manual QA Checklist

1. Add 3 servers (reachable, unreachable, invalid URL).
2. Set default server and restart app.
3. Switch active server repeatedly while loading sessions.
4. Remove active server and verify fallback selection.
5. Verify auth credentials remain attached only to intended server.

## Risks and Mitigations

1. Risk: cache contamination across servers.
   - Mitigation: explicit key namespacing and migration tests.
2. Risk: switch races (in-flight requests from previous server).
   - Mitigation: request generation token/cancel on switch.
3. Risk: broken legacy behavior after migration.
   - Mitigation: one-time migration fallback and telemetry/log assertions.

## Execution Plan (mapped to ROADMAP tasks)

- `11.01` Data/storage + migration + app provider refactor.
- `11.02` Server manager UI and health indicators.
- `11.03` Server-scoped cache partitioning.
- `11.04` Unit/widget/integration test additions.

## Definition of Done

- App can persist and manage multiple servers.
- User can switch active server with visible health.
- Default server survives restart.
- No session/model cache leakage across servers.
- Automated tests cover core server-management paths.

## Source Links

- https://github.com/anomalyco/opencode
- https://opencode.ai/docs/server/

