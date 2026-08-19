# Contract Matrix

CodeWalk follows ADR-023: official OpenCode docs/source are the primary contract. OpenChamber is a mandatory community reference for bug investigation, behavior corrections, and feature cloning — it shares CodeWalk’s goals and is built on the same OpenCode foundation using JS/TS. It must never override official OpenCode on protocol or lifecycle semantics.

## Source Priority

1. `ADR.md` (especially ADR-023 and related ADRs)
2. `BEHAVIOR.md`
3. `ai-docs/opencode_server.md`
4. `ai-docs/opencode_web.md`
5. `ai-docs/opencode_models.md`
6. Official OpenCode docs/source
7. OpenChamber — mandatory for bug fixes, regressions, and feature cloning; non-authoritative for protocol/lifecycle semantics

## Decision Rules

- Follow official OpenCode lifecycle and payload semantics first.
- Keep legacy compatibility fallbacks explicit and temporary.
- Do not introduce **new protocol behavior** from OpenChamber alone — official contract applies.
- **Always check OpenChamber first** when investigating a bug or planning a feature: if it already has a working fix or similar feature, clone and adapt the approach to Dart/Flutter.
- Prefer capability-gated UI for official-but-optional server surfaces.
- Treat drift around `prompt_async`, SSE reconciliation, and config mutation as high risk.

## Matrix

| Surface | Official source | CodeWalk current status | Relevant files | Risk if wrong | Next action |
| --- | --- | --- | --- | --- | --- |
| Async session send lifecycle (`/session/:id/prompt_async`) | Official OpenCode contract in `ai-docs/opencode_server.md` | Implemented. Provider intentionally omits `messageId` and relies on server-assigned canonical IDs. | `lib/presentation/providers/chat_provider.dart`, `lib/data/datasources/chat_remote_datasource.dart` | Critical: later turns can silently fail reconciliation. | Keep protected by dedicated contract tests. |
| Optimistic local user ID contract (`local_user_*`) | ADR-023 pitfall guidance plus current CodeWalk behavior | Implemented and load-bearing for duplicate echo suppression. | `lib/presentation/providers/chat_provider.dart`, `lib/presentation/providers/chat_provider/chat_provider_message_merge_ops.dart` | Critical: optimistic/server echo merge breaks. | Keep explicit in tests and comments; do not normalize to server-like IDs. |
| Global/session realtime semantics (`/event`, `/global/event`) | Official OpenCode contract in `ai-docs/opencode_server.md` | Implemented with provider-level SSE and fallback completion watch. Nested global envelopes preserve authoritative outer context metadata; `session.next.revert.*` triggers serialized server-authoritative reconciliation; `catalog.updated` coalesces provider/model refreshes. | `lib/data/models/chat_realtime_model.dart`, `lib/data/datasources/chat_remote_datasource.dart`, `lib/presentation/providers/chat_provider/chat_provider_realtime_ops.dart`, `lib/presentation/providers/chat_provider/chat_provider_event_reducer_helpers.dart`, `lib/presentation/providers/chat_provider/chat_provider_event_reducer_session_ops.dart`, `lib/presentation/providers/chat_provider/chat_provider_event_reducer_global_ops.dart`, `test/unit/models/chat_realtime_model_test.dart`, `test/unit/providers/chat_provider_realtime_test.dart`, `test/contract/chat_event_contract_test.dart` | High: wrong-context mutation, stale revert state, refresh storms, dropped assistant updates, or scroll regressions. | Keep outer-context precedence, cross-stream deduplication, serialized refresh, and server-authoritative state protected by contract and concurrency tests. |
| Session status map (`/session/status`) | Official OpenCode contract in `ai-docs/opencode_server.md` | Implemented and used to defer risky config sync while busy. | `lib/data/datasources/chat_remote_datasource.dart`, `lib/presentation/providers/chat_provider/chat_provider_selection_helpers.dart` | High: false aborts and config timing regressions. | Keep selection/config deferral covered by tests. |
| Config sync (`GET/PATCH /config`) | Official OpenCode contract in `ai-docs/opencode_server.md`; timing constrained by ADR-019 | Implemented. PATCH calls are deferred while active processing remains unsafe. | `lib/data/datasources/app_remote_datasource.dart`, `lib/presentation/providers/chat_provider/chat_provider_selection_helpers.dart`, `test/unit/providers/chat_provider_sync_test.dart` | High: server processing can be interrupted. | Keep ADR-019 behavior in the contract test suite. |
| Providers, agents, models, variants (`/provider`, `/agent`, `/config`) | Official OpenCode contract in `ai-docs/opencode_server.md` and `ai-docs/opencode_models.md` | Implemented for provider/model/agent selection and variant sync. | `lib/data/datasources/app_remote_datasource.dart`, `lib/presentation/providers/chat_provider.dart`, `lib/presentation/providers/settings_provider.dart` | Medium: mismatched defaults or unsupported model rendering. | Maintain capability-aware UI and avoid hardcoded assumptions beyond official config. |
| Provider auth and OAuth (`/provider/auth`, OAuth authorize/callback) | Official OpenCode contract in `ai-docs/opencode_server.md` | Not currently consumed by the client. | `lib/data/datasources/app_remote_datasource.dart` | Medium: connection UX remains manual where official auth helpers exist. | Treat as a later capability-gated addition after core contract work. |
| Session action surfaces (`share`, `diff`, `todo`, `revert`, `unrevert`, `init`, `summarize`) | Official OpenCode contract in `ai-docs/opencode_server.md` | Data/domain/provider support is largely present. Historical persisted user messages now expose inline rewind/edit through the existing `/session/:id/revert` path, while broader action UI exposure remains partial. | `lib/data/datasources/chat_remote_datasource.dart`, `lib/domain/usecases/get_session_diff.dart`, `lib/domain/usecases/get_session_todo.dart`, `lib/domain/usecases/revert_chat_message.dart`, `lib/domain/usecases/unrevert_chat_messages.dart`, `lib/domain/usecases/summarize_chat_session.dart`, `lib/presentation/providers/chat_provider.dart`, `lib/presentation/pages/chat_page/chat_page_timeline_builder.dart` | Medium: hidden capabilities and fragmented review flow. | Continue building discoverable UI on top of existing official support before adding new protocol surfaces. |
| Slash command surfaces (`GET /command`, `POST /session/:id/command`) | Official OpenCode contract in `ai-docs/opencode_server.md` | Implemented. Suggestions load from `/command`; sends route to `/session/:id/command` with `command`/`arguments` strings and an optional `provider/model` string. | `lib/presentation/pages/chat_page/chat_page_command_query.dart`, `lib/data/datasources/chat_remote_datasource.dart`, `lib/data/datasources/chat_remote_datasource_helpers.dart`, `test/unit/datasources/chat_remote_datasource_command_test.dart` | Medium: drift if command sends fall back to chat payload semantics or omit required empty arguments. | Keep this path explicit, preserve the official wire shape with contract tests, and avoid conflating command sends with `prompt_async`. |
| Project, file, search, and VCS (`/project`, `/project/current`, `/file`, `/file/content`, `/find/file`, `/find`, `/find/symbol`, `/vcs`) | Official OpenCode contract in `ai-docs/opencode_server.md` | Implemented for current project, file listing/reading, fuzzy file search, file-content search, workspace symbol lookup, and VCS detection. | `lib/data/datasources/project_remote_datasource.dart`, `lib/presentation/pages/chat_page/chat_page_file_explorer_controller.dart`, `lib/presentation/pages/chat_page/chat_page_command_query.dart` | Medium: weak search/discovery if capability map is unclear. | Keep capability-aware UX; `/file/status` remains unused and should be gated before surfacing. |
| Experimental worktrees (`/experimental/worktree`) | Official OpenCode experimental contract in local docs | Implemented in datasource/domain, with UI opportunities still limited. | `lib/data/datasources/project_remote_datasource.dart`, `lib/data/models/worktree_model.dart` | Medium: experimental surface can drift faster than stable APIs. | Keep behind explicit UX framing and capability checks. |
| PTY / terminal runtime | CodeWalk ADR-027 plus client implementation; not documented in current local OpenCode server snapshot | Implemented in the client, but the local server doc snapshot does not currently list PTY endpoints. | `lib/data/datasources/terminal_remote_datasource.dart`, `lib/presentation/services/codewalk_terminal_socket.dart`, `lib/presentation/widgets/codewalk_terminal_panel.dart` | Medium: doc/source mismatch could hide transport drift. | Verify against live `/doc` or upstream source before broadening terminal UX assumptions. |
| App/path bootstrap (`/path`) with legacy `/app` and `/app/init` fallback | Official OpenCode uses `/path`; legacy compatibility remains in client | Implemented with explicit fallback for older servers. | `lib/data/datasources/app_remote_datasource.dart` | Medium: silent legacy behavior can outlive its support window. | Keep the fallback documented and define supported server window before removing it. |
| Permissions/questions | Official OpenCode docs explicitly list `/session/:id/permissions/:permissionID`; local docs do not describe current question endpoints | CodeWalk uses the documented session-scoped permission reply route first and includes `remember: true` for `always` replies; the existing top-level legacy fallback remains for mixed server generations. Question reply/reject flows remain top-level. | `lib/data/datasources/chat_remote_datasource.dart`, `lib/presentation/widgets/permission_request_card.dart` | High: likely drift or mixed-version compatibility area. | Verify against live `/doc` and upstream source before broader route migrations; keep clearly marked as needs verification. |
| Advanced official surfaces (`/mcp`, `/lsp`, `/formatter`, `/experimental/tool`, `/file/status`) | Official OpenCode contract in `ai-docs/opencode_server.md` | Not yet consumed or only weakly represented in the UI. | `lib/data/datasources/app_remote_datasource.dart`, `lib/data/datasources/project_remote_datasource.dart`, settings/UI layers | Medium: missed product value if never surfaced; drift if surfaced without capability gating. | Treat as later capability-gated work after contract hardening and core UX cleanup. |

## Confirmed Safe to Build On

- `prompt_async` plus provider-level SSE remains the correct baseline for CodeWalk.
- Model/provider/agent selection already follows official config-backed surfaces.
- `GET /command` and `POST /session/:id/command` are already aligned in the client.
- Session action APIs are already mostly wired at the data/domain/provider level.
- Project/file/VCS/worktree surfaces are real foundations, not speculative product ideas.

## Needs Contract Hardening First

- `local_user_*` optimistic ID rules and `messageId` omission from `prompt_async`
- SSE reconciliation and session-authoritative status transitions
- Deferred `PATCH /config` behavior while the server is busy
- Permission/question route migration details beyond the documented session-scoped permission reply and existing legacy fallback
- PTY endpoint assumptions that are implemented client-side but under-documented in the local official snapshot

## OpenChamber — Bug Fix and Feature Cloning Reference

OpenChamber (https://github.com/openchamber/openchamber) runs on the same OpenCode foundation as CodeWalk and pursues identical goals using JS/TS. It is the closest community analog to CodeWalk.

**Mandatory uses**:
- Investigate OpenChamber when debugging a regression — it may have already fixed the root cause.
- Review OpenChamber before implementing a new feature — it may have a proven pattern to clone.
- Use OpenChamber as a UX and behavior reference when official OpenCode docs are silent on UX details.

**Limitations** (non-negotiable):
- Must not redefine CodeWalk’s protocol or lifecycle assumptions.
- Must not override official OpenCode API/event semantics.
- Dart/Flutter adaptation is always required; do not copy JS/TS patterns verbatim.

**OpenChamber-Only UX inspiration** (useful after official compatibility is confirmed):
- richer diff/review surfaces
- quota grouping/provenance clarity
- stronger multi-device continuity affordances
- broader workspace control panels
- advanced Git/GitHub workflows
