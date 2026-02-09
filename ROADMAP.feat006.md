# Feature 006 - OpenCode Server Mode API Refresh and Documentation Update

## Context

Features 001-005 completed the base (audit, licensing, rebrand, English standardization, docs cleanup). The CodeWalk client was originally built against an earlier version of the OpenCode API. The API has evolved significantly and there are drifts in endpoints, schemas, and event handling that affect functionality. The source of truth for the current API is the official TypeScript SDK at `anomalyco/opencode-sdk-js` (auto-generated via OpenAPI/Stainless) and the server documentation at `https://opencode.ai/docs/server`.

## Gap Matrix

### Endpoint Drifts

| Area | Client (current) | Server (current API) | Impact |
|------|-------------------|----------------------|--------|
| App info | `GET /path` + `GET /config` (2 calls) | `GET /app` (1 call, returns everything) | BREAKING - `/path` returns different schema |
| Providers | `GET /provider` -> `{providers, default}` | `GET /provider` -> `{all, default, connected}` | Parsing fails if field `providers` doesn't exist |
| Providers (alt) | - | `GET /config/providers` -> `{providers, default}` | Alternative endpoint with compatible schema |
| Summarize | `POST /session/:id/summarize` no body | Requires body `{providerID, modelID}` | 400 Bad Request |
| ChatInput | Sends field `agent` | Server expects field `mode` | Field ignored, default mode used |

### Schema Drifts

| Model | Client | Server | Impact |
|-------|--------|--------|--------|
| MessageTokens | `{input, output, total}` | `{input, output, reasoning, cache: {read, write}}` | Partial parsing, loses reasoning/cache data |
| AssistantMessage | No `summary` field | Has `summary?: boolean` | Info lost |
| Part types | text/file/tool/agent/reasoning/step_start/step_finish/snapshot | Adds `patch` type `{files, hash}` | Patch parts ignored silently |
| ToolStateCompleted | `title?`, `metadata?` (optional) | `title`, `metadata` (required) | Compatible (client accepts null) |
| ToolStateError | Has `title?`, `metadata?` | Only has `error`, `input`, `time` | Extra fields ignored |
| FilePartSource | Only `FileSource` | Adds `SymbolSource` | Symbol sources fail on parse |
| Event types | Only `message.updated`, `message.part.updated` | 15 types including `session.*`, `message.removed`, etc. | Important events lost |

### Issues in Current Code

| Issue | File | Description |
|-------|------|-------------|
| Hardcoded fallback provider | `app_remote_datasource.dart` | Moonshot AI hardcoded as fallback - should propagate error |
| getProject ignores projectId | `project_remote_datasource.dart` | Always calls `/project/current` regardless of param |
| Hardcoded fallback in initializeProviders | `chat_provider.dart` | Falls back to `moonshotai-cn` on error |

### New Endpoints (out of scope for 006, documented for future)

Endpoints available in the API but not implemented in the client: `/global/health`, `/global/event`, `/session/status`, `/session/:id/children`, `/session/:id/todo`, `/session/:id/fork`, `/session/:id/diff`, `/session/:id/permissions/:id`, `/find/*`, `/file/*`, `/mode`, `/agent`, `/command`, `/log`, `/mcp`, `/lsp`, `/formatter`, `/vcs`, `/instance/dispose`, `/provider/auth`, `/provider/:id/oauth/*`, `PATCH /config`, `/doc`, TUI control routes.

## Task List

- [x] 6.01 Build endpoint-by-endpoint gap matrix
- [x] 6.02 Update models/datasources/use cases for schema and endpoint drift
  - [x] 6.02a AppRemoteDataSource: Prefer `GET /path` with `GET /app` fallback
  - [x] 6.02b Provider response: Support new schema (`all` + `connected`)
  - [x] 6.02c Message/Part models: Update schemas (tokens, patch, summary, SymbolSource)
  - [x] 6.02d ChatInput: Map domain `mode` to API `agent` and support nested `model` payload
  - [x] 6.02e Session summarize: Add body with providerID/modelID
  - [x] 6.02f Event handling: Expand event types
  - [x] 6.02g Remove hardcoded fallback provider
  - [x] 6.02h Fix getProject (documented as intentional /project/current fallback)
  - [x] 6.02i Regenerate JSON serialization
- [x] 6.03 Update API documentation in CODEBASE.md
- [x] 6.04 Validate chat/session/provider flows against a real server instance - Completed on 2026-02-09 against `100.68.105.54:4096` after fixing request/response compatibility (`model` object payload, non-null part fields, `/path` app bootstrap, `{info,parts}` parsing)

## Implementation Notes

### 6.04 Real Server Validation (2026-02-09)

Target server: `http://100.68.105.54:4096`

Validated successfully:
- `GET /path` app bootstrap flow worked with HTTP 200 and was mapped into app info state (`hostname`, `path.cwd`, `path.root`).
- `GET /provider` returned current schema (`all`, `default`, `connected`) with HTTP 200.
- `GET /session` returned existing sessions with HTTP 200.
- Session lifecycle worked: `POST /session`, `GET /session/{id}`, `PATCH /session/{id}`, `DELETE /session/{id}` all returned HTTP 200.
- Message flow worked end-to-end after schema fixes: `POST /session/{id}/message` returned assistant payload and `GET /session/{id}/message/{messageID}` parsed correctly as assistant message.
- `POST /session/{id}/summarize` with `{providerID, modelID}` returned HTTP 200 (`true`).
- SSE endpoint `GET /event` responded HTTP 200 and emitted events (`server.connected`, `message.updated`, `message.part.updated`, `session.status`, `session.idle`).

Root-cause correction applied during validation:
- Initial blocker was not server runtime instability; it was request-shape drift in client serialization versus current OpenAPI (`model: {providerID, modelID}` expected, not flat `providerID/modelID`).
- Request parts also had null fields (notably `id: null`) that caused 400 validation errors; serializer was updated to omit nulls.
- Message detail parser was updated to handle `{info, parts}` response shape on `GET /session/{id}/message/{messageID}`.
