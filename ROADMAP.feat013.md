# Feature 013 - Event Stream and Message-Part Parity (Messages, Thinking, Tools, Questions, Permissions)

## Goal
Upgrade CodeWalk realtime behavior to OpenCode v2 event and part parity, covering robust SSE handling, richer part rendering, and interactive permission/question flows.

## Why This Exists

Current CodeWalk consumes only a narrow subset of events from `/event`. It misses key events and interactive workflows that upstream clients already handle, which limits fidelity for tools/thinking/session status.

## Research Snapshot

- Upstream commit: `anomalyco/opencode@24fd8c1`.
- Primary files reviewed:
  - `packages/sdk/js/src/v2/gen/types.gen.ts`
  - `packages/app/src/context/global-sync.tsx`
  - `packages/app/src/context/global-sync/event-reducer.ts`
  - `packages/app/src/pages/session/session-prompt-dock.tsx`
  - `packages/app/src/components/session/session-context-tab.tsx`
  - `packages/app/src/components/session/session-context-metrics.ts`
- Existing local implementation reviewed:
  - `lib/data/datasources/chat_remote_datasource.dart`
  - `lib/data/models/chat_message_model.dart`
  - `lib/presentation/widgets/chat_message_widget.dart`

## Upstream Behavior (Reference)

### Event taxonomy (high-value for CodeWalk)

- Message events:
  - `message.updated`
  - `message.part.updated`
  - `message.removed`
  - `message.part.removed`
- Session events:
  - `session.created/updated/deleted`
  - `session.status`
  - `session.error`
  - `session.idle`
  - `session.diff`
  - `todo.updated`
- Interaction events:
  - `permission.asked/replied`
  - `question.asked/replied/rejected`

### Part taxonomy

- currently core:
  - `text`, `file`, `tool`, `reasoning`
- additional:
  - `step-start`, `step-finish`, `snapshot`, `patch`
  - `subtask`, `agent`, `retry`, `compaction`

### Interaction UX

- Permission and question requests are rendered as actionable UI cards.
- User response flows are sent to permission/question endpoints.

## Current CodeWalk Baseline (Gap)

- `sendMessage()` SSE listener handles:
  - `message.updated`
  - `message.part.updated`
  - `session.error`
  - `session.idle`
  - logs/ignores many other events.
- No generalized event reducer/state machine.
- No user-facing permission/question prompt handling.
- Part parsing/rendering supports only a subset for display; many types are ignored/fallback.
- SSE resilience is basic (single stream lifecycle per send flow), not a global long-lived event engine.

## Scope

### In scope

- Realtime event pipeline redesign for robustness.
- High-value event support for session/message lifecycle.
- Expanded part parsing and rendering strategy.
- Permission/question interactive requests and responses.
- Integration tests with deterministic event streams.

### Out of scope

- Full parity for TUI-only events.
- PTY terminal event UX (can be staged later).

## Implementation Blueprint

### 1. Event architecture

Introduce dedicated event pipeline service:

- long-lived subscription with reconnect/backoff.
- generation token to discard stale streams.
- heartbeats/idle timeout handling.
- targeted fallback fetch (`/session/{id}/message/{messageId}`) when delta is partial.

Prefer provider-level event handling over send-call-local listeners.

### 2. Event reducer

Create reducer-like handler (in ChatProvider or new sync provider):

- update session list metadata on session events.
- apply message add/update/remove deterministically.
- apply part add/update/remove deterministically.
- maintain session status map.
- maintain pending permission/question queue by session.

### 3. Part parsing/rendering expansion

Extend domain/model for additional part types:

- `StepStartPart`, `StepFinishPart`, `SnapshotPart`, `SubtaskPart`, `RetryPart`, `CompactionPart`, `AgentPart`.

UI strategy:

- first phase:
  - render compact cards/chips for new part types.
  - avoid data loss by preserving unrendered raw metadata.
- second phase:
  - richer specialized rendering where value is clear.

### 4. Interactive permission/question flows

Add UI components for:

- permission request with actions: `once`, `always`, `reject`.
- question request with options and optional free-text answers.

Endpoints:

- preferred session-scoped permission response:
  - `POST /session/{sessionID}/permissions/{permissionID}`
- question response:
  - `POST /question/{requestID}/reply`
  - `POST /question/{requestID}/reject`

## API Contract Notes

OpenCode v2 supports:

- `Event` union with extensive typed events.
- `Part` union with broad part taxonomy.
- permission/question list + response endpoints.

Message prompt and command responses can emit partial events followed by finalized message state.

## Test Strategy

### Unit tests

- event parsing and reducer transitions.
- part deserialization for all supported part types.
- stale-event discard logic.

### Widget tests

- render mixed part timelines.
- permission/question cards show and dispatch expected actions.

### Integration tests

Use controllable mock event stream to validate:

1. out-of-order part updates.
2. message part removal.
3. session status transitions (`busy -> retry -> idle`).
4. permission/question ask + reply/reject flows.

## Manual QA Checklist

1. Send long task and verify tool + thinking + status updates in real time.
2. Trigger server-side error and confirm proper UI state recovery.
3. Trigger permission prompt and answer with each option.
4. Trigger question prompt and submit answers.
5. Validate no duplicate or missing parts after reconnect.

## Risks and Mitigations

1. Risk: duplicate message state from event+fetch race.
   - Mitigation: message version/order guard and idempotent reducer.
2. Risk: reconnect storms on unstable networks.
   - Mitigation: bounded exponential backoff.
3. Risk: unsupported unknown part breaks rendering.
   - Mitigation: generic fallback renderer + logging.

## Execution Plan (mapped to ROADMAP tasks)

- `13.01` SSE engine hardening and reconnect logic.
- `13.02` Event reducer support for target event groups.
- `13.03` Part model and renderer expansion.
- `13.04` Permission/question interactive UX.
- `13.05` Integration test matrix for event scenarios.

## Definition of Done

- Realtime stream remains stable across long sessions and temporary disconnects.
- High-value session/message events are reflected in UI state.
- Tool/thinking and expanded parts render without data loss.
- Permission/question requests are actionable in-app.
- Automated tests cover reducer and stream race conditions.

## Implementation Status

**Status**: Completed

Implemented in mobile client with:

- SSE subscription flow with reconnect/backoff in `ChatRemoteDataSource.subscribeEvents()`.
- Provider-level realtime reducer in `ChatProvider` for `session.*`, `message.*`, `permission.*`, and `question.*`.
- Fallback full-message fetch via `GetChatMessage` when delta/partial updates are received.
- Expanded part taxonomy parsing + rendering for `agent`, `step-start`, `step-finish`, `snapshot`, `subtask`, `retry`, `compaction`, and `patch`.
- Interactive permission/question cards with reply/reject endpoint integration.
- Integration test matrix updates for reconnect and permission/question endpoint flows.

Validation executed:

- `flutter test` (all tests passing).
- `flutter analyze --no-fatal-infos --no-fatal-warnings` (passes with infos only).

Post-completion stabilization:

- Fixed `directory` propagation in `sendMessage()` streaming path so both `/event` subscription and `/session/{id}/message/{messageId}` fallback fetch use the active project directory scope.
- Added integration coverage to enforce directory-scoped send streaming (`/event` + message fetch) and prevent regression where only interim thinking content appeared without final reply.
- Added release-visible send lifecycle logs (`info`/`warn`) for `send -> event stream -> fallback poll -> completion`.
- Hardened fallback when event stream is missing/closed: resolve assistant `messageID` from `/session/{id}/message` before polling completion.
- Added send watchdog fallback when `/event` stays open but no message events arrive, preventing stuck `sending/thinking` state.
- Fixed provider realtime subscription race to avoid duplicate `/event` subscriptions under concurrent initialization.
- Removed `messageID` from regular send payload path (`POST /session/{id}/message`) to avoid server-side stale immediate replies reusing previous assistant message IDs.
- Hardened provider send setup with stage-level logs and best-effort (non-blocking) selection persistence so local storage failures/timeouts do not prevent request dispatch.
- Fixed regression in model-usage tracking when restored recent-model list was fixed-length, which caused `Unsupported operation: Cannot remove from a fixed-length list` before request dispatch.

## Source Links

- https://github.com/anomalyco/opencode
- https://opencode.ai/docs/server/
