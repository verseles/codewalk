# Feature 014 - Advanced Session Lifecycle Management

## Goal
Bring CodeWalk session lifecycle behavior close to OpenCode parity, extending from basic CRUD to rename/archive/share/fork/children/todo/diff/status workflows with reliable UX and test coverage.

## Why This Exists

Current app supports create/select/delete basics, but key session management actions are either missing or incomplete:

- rename UI exists but does not persist update.
- share/unshare is TODO in session list widget.
- no fork/children/todo/diff/status UX.
- no robust filtering/search/sorting controls for larger histories.

## Research Snapshot

- Upstream commit: `anomalyco/opencode@24fd8c1`.
- Primary files reviewed:
  - `packages/app/e2e/session/session.spec.ts`
  - `packages/app/src/components/session/session-header.tsx`
  - `packages/app/src/components/dialog-fork.tsx`
  - `packages/sdk/js/src/v2/gen/types.gen.ts` (session endpoints)
- Local baseline reviewed:
  - `lib/presentation/widgets/chat_session_list.dart`
  - `lib/presentation/providers/chat_provider.dart`
  - `lib/data/datasources/chat_remote_datasource.dart`

## Upstream Behavior (Reference)

### Lifecycle actions covered in upstream e2e

- rename session.
- archive session.
- delete session.
- share and unshare session.

### Additional session APIs in v2

- `GET /session/status`
- `GET /session/{id}/children`
- `GET /session/{id}/todo`
- `GET /session/{id}/diff`
- `POST /session/{id}/fork`
- `PATCH /session/{id}` supports title and archive timestamp updates.
- `POST /session/{id}/share` and `DELETE /session/{id}/share`.

## Current CodeWalk Baseline (Gap)

- Rename path:
  - dialog exists in `chat_session_list.dart`, but no call to `updateSession`.
- Share path:
  - `_shareSession` method is TODO.
- Archive path:
  - no exposed UI action.
- Session metadata refresh is simplistic; no status/todo/diff surfaces.
- Session listing is minimal with no search/filter/limit controls.

## Scope

### In scope

- Complete rename/archive/share/unshare/delete flows.
- Add fork session entry point.
- Add optional children/todo/diff/status panels or lightweight views.
- Improve session list UX for larger histories.
- Add optimistic updates and rollback behavior.

### Out of scope

- Full desktop-level titlebar navigation parity.
- Full command palette session management parity.

## Implementation Blueprint

### 1. Repository/use case completion

Ensure use cases exist and are wired for:

- `updateSession` (title/archive updates).
- `shareSession` / `unshareSession`.
- `forkSession` (new use case required).
- `getSessionChildren`, `getSessionTodo`, `getSessionDiff`, `getSessionStatus`.

### 2. Session list + header UX

Add actionable menu items:

- rename (persisted).
- archive/unarchive.
- share/unshare with copy-link affordance.
- delete with confirmation.
- fork from selected message (if message context is available).

### 3. Optimistic state handling

On action trigger:

- apply local optimistic change.
- rollback if request fails.
- show explicit error toast/message.

### 4. Session metadata surfaces

Add lightweight session details panel/tab:

- status (`idle`, `busy`, `retry`).
- todo list count/items.
- diff summary.
- children sessions list count.

## API Contract Notes

- Archive can be represented by `PATCH /session/{id}` with:
  - `time: { archived: <epoch_ms> }`
- Unarchive by clearing archived time depending server behavior (validate contract).
- Share URL lives under session share payload (`share.url`).

## Test Strategy

### Unit tests

- action reducers/handlers for rename/archive/share/unshare.
- optimistic update rollback on failure.

### Widget tests

- session menu actions trigger expected provider calls.
- renamed title and shared icon state update in list.
- archive action removes session from active list (if archived sessions hidden).

### Integration tests

- extend mock server to validate:
  - patch title/archive flows.
  - share/unshare response mapping.
  - fork returns new session and navigation target.

## Manual QA Checklist

1. Rename session; reload app; verify title persists.
2. Share session; copy link; unshare; verify icon/state updates.
3. Archive a session and ensure active list behavior is correct.
4. Delete current session and verify fallback selection.
5. Fork a session/message and verify new branch session appears.

## Risks and Mitigations

1. Risk: inconsistent session ordering after updates.
   - Mitigation: central sort comparator and deterministic reinsert.
2. Risk: archive/share state drift between client and server.
   - Mitigation: refetch session after action success for canonical state.
3. Risk: user confusion on archive visibility.
   - Mitigation: clear filter labels and optional archived view toggle.

## Execution Plan (mapped to ROADMAP tasks)

- `14.01` end-to-end rename/archive/share/unshare/delete.
- `14.02` fork + children/todo/diff/status support.
- `14.03` session list scalability improvements (search/filter/sort).
- `14.04` session history/timeline consistency work.
- `14.05` integration coverage for lifecycle matrix.

## Definition of Done

- Core lifecycle actions work reliably and persist correctly.
- Session metadata features (status/todo/diff/children) are accessible.
- UX remains stable with larger session histories.
- Integration tests cover success and failure paths.

## Source Links

- https://github.com/anomalyco/opencode
- https://opencode.ai/docs/server/

