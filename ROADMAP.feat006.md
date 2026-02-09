# Feature 006 - OpenCode Server Mode API Refresh and Documentation Update

## Goal
Realign CodeWalk with the latest OpenCode Server Mode API contracts, update client integration code accordingly, and replace outdated API documentation with a current and testable integration guide.

## Scope
- Gap analysis: current client endpoints/models vs latest OpenCode docs
- Update models/datasources/use cases where contracts drifted
- Produce current Server Mode API documentation for this repo
- Validate core flows against a live server (`/doc` + runtime behavior)

## Out of Scope
- Non-Server-Mode features outside current app scope

## Current Findings (2026-02-09)
Current client usage includes endpoints such as:
- `/project`, `/project/current`
- `/path`, `/config`, `/provider`, `/app/init`
- `/session` and sub-routes, `/event`

Potential drifts vs latest docs:
- Global routes now documented as `/global/*` (`/global/init`, `/global/event`, `/global/health`).
- Provider response includes `all`, `connected`, `default` groups.
- `POST /session/:id/summarize` expects body with `providerID` and `modelID`.
- Session/message schemas include richer structures that may not match current model assumptions.

## Implementation Stages

### Stage 1 - Contract Snapshot and Diff
- Pull current OpenCode contract from:
  - docs website
  - live server `/doc` in target environment
- Generate endpoint and schema diff matrix.

### Stage 2 - Code Alignment
- Update datasource endpoint paths where required.
- Update models to parse current provider/session/message payloads.
- Remove brittle hardcoded provider fallback assumptions where possible.

### Stage 3 - Compatibility Layer and Error Strategy
- Define behavior when server version differs from expected contract.
- Add explicit feature/version checks or graceful degradation.

### Stage 4 - Documentation Rewrite
- Replace outdated API docs with:
  - endpoint matrix,
  - payload examples,
  - migration notes,
  - known caveats.

### Stage 5 - Verification
- Run manual API smoke tests for:
  - connection/init,
  - providers,
  - session CRUD,
  - streaming chat events.

## Deliverables
- Updated API client implementation
- New Server Mode API documentation (versioned and actionable)
- Contract diff matrix and migration notes

## Risks and Mitigations
- Risk: server docs and deployed server version mismatch.
  - Mitigation: use live `/doc` from actual server as runtime source of truth.
- Risk: SSE/event contract drift breaks chat streaming silently.
  - Mitigation: add explicit event parsing tests and fallback logging.

## Definition of Done
- Core chat/session/provider flows pass against latest target server
- Repo API docs accurately describe real behavior
- No known high-impact contract mismatch remains undocumented

## Research Log

### External Sources
- OpenCode Server Mode overview and endpoint index:
  - https://opencode.ai/docs/server
- OpenCode global routes (`/global/*`):
  - https://opencode.ai/docs/server/global
- OpenCode provider routes and response schema:
  - https://opencode.ai/docs/server/provider
- OpenCode session routes and summarize request shape:
  - https://opencode.ai/docs/server/session

### Key Takeaways
- Server docs show broad route coverage and active evolution.
- Last updated marker on docs server page indicates active maintenance (Sept 29, 2026).
- A contract diff is mandatory before code changes to avoid partial migrations.
