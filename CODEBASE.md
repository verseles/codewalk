# CodeWalk - Codebase Baseline Snapshot

> Captured: 2026-02-09
> Git baseline: `57633fa8c113c2e53c77acb905e7cca627a29d0d` (main)
> Flutter: 3.38.9 (stable)

## Project Structure

```
codewalk/
├── android/           # Android platform (Kotlin)
│   ├── app/
│   ├── build.gradle.kts
│   ├── gradle/
│   └── settings.gradle.kts
├── assets/
│   └── images/        # App icons and images
├── lib/
│   ├── core/
│   │   ├── constants/ # API and app constants
│   │   ├── di/        # Dependency injection (get_it)
│   │   ├── errors/    # Exception and failure classes
│   │   ├── logging/   # Centralized logging with token sanitization
│   │   └── network/   # Dio HTTP client setup
│   ├── data/
│   │   ├── datasources/ # Remote and local data sources
│   │   ├── models/      # JSON-serializable models (.g.dart generated)
│   │   └── repositories/ # Repository implementations
│   ├── domain/
│   │   ├── entities/    # Core business entities
│   │   ├── repositories/ # Repository interfaces
│   │   └── usecases/    # Application use cases
│   ├── presentation/
│   │   ├── pages/       # Chat, Home, Server Settings
│   │   ├── providers/   # State management (Provider)
│   │   ├── theme/       # App theme configuration
│   │   └── widgets/     # Chat input, message, session list
│   └── main.dart
├── test/
│   ├── widget_test.dart        # Original widget test
│   ├── unit/                   # Unit tests (models, providers, usecases)
│   ├── widget/                 # Widget-specific tests
│   ├── integration/            # Integration tests with mock server
│   └── support/                # Fakes and mocks
├── tool/
│   └── ci/                     # CI validation scripts
│       ├── check_analyze_budget.sh
│       └── check_coverage.sh
├── .github/
│   └── workflows/
│       └── ci.yml              # CI/CD pipeline (quality, builds)
├── linux/             # Linux desktop runner
├── macos/             # macOS desktop runner
├── web/               # Web platform
│   ├── index.html
│   └── manifest.json
├── windows/           # Windows desktop runner
├── pubspec.yaml
├── analysis_options.yaml
├── dart_test.yaml     # Test tags configuration
├── .lcovrc            # LCOV coverage configuration
├── codecov.yml        # Codecov integration config
├── CONTRIBUTING.md    # Contribution guidelines
├── install.sh         # Unix installer script
├── install.ps1        # Windows installer script
└── Makefile           # Build automation (67 lines)
```

## File Counts

| Type | Count | Notes |
|------|-------|-------|
| `.dart` (source) | 69 | Under `lib/` (excluding generated) |
| `.g.dart` (generated) | 4 | JSON serialization models |
| `.dart` (tests) | 14 | Test files (unit, widget, integration, support) |
| `.dart` (total) | 83 | Tracked Dart files in repository (including tests and generated files) |
| `.md` (markdown) | 16 | Docs + roadmap + CONTRIBUTING.md |
| `.sh` (scripts) | 3 | CI validation + installer scripts |

## Legacy Naming References

All runtime/build/config references to `open_mode`/`OpenMode` were renamed to `codewalk`/`CodeWalk` in Feature 003. Remaining references exist only in historical documentation files (NOTICE, ADR.md, ROADMAP files) as intentional attribution to the original project.

## API Endpoints

Extracted from `lib/data/datasources/*.dart`. Server base URL is configurable.
Aligned with OpenCode Server Mode API (source: `opencode.ai/docs/server`, SDK: `anomalyco/opencode-sdk-js`).

### AppRemoteDataSource (`app_remote_datasource.dart`)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/path` | Fetch runtime path info (primary app bootstrap endpoint) |
| GET | `/app` | Fetch app info (legacy fallback for older servers) |
| POST | `/app/init` | Legacy initialization fallback (`/path` is primary readiness probe) |
| GET | `/provider` | Get providers (`{all, default, connected}`) |
| GET | `/config` | Fetch config info |
| GET | `/global/health` | Server health probe used by multi-server orchestration (with `/path` fallback) |

### ChatRemoteDataSource (`chat_remote_datasource.dart`)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/session` | List sessions |
| GET | `/session/{id}` | Get session details |
| POST | `/session` | Create session |
| PATCH | `/session/{id}` | Update session |
| DELETE | `/session/{id}` | Delete session |
| POST | `/session/{id}/share` | Share session |
| DELETE | `/session/{id}/share` | Unshare session |
| GET | `/session/{id}/message` | List messages |
| GET | `/session/{id}/message/{messageId}` | Get specific message |
| POST | `/session/{id}/message` | Send message (streaming via SSE) |
| GET | `/event` | SSE event stream |
| GET | `/permission` | List pending permission requests |
| POST | `/permission/{requestId}/reply` | Reply to permission request (`once`, `always`, `reject`) |
| GET | `/question` | List pending question requests |
| POST | `/question/{requestId}/reply` | Submit question answers |
| POST | `/question/{requestId}/reject` | Reject question request |
| POST | `/session/{id}/abort` | Abort session |
| POST | `/session/{id}/revert` | Revert message (`{messageID, partID?}`) |
| POST | `/session/{id}/unrevert` | Unrevert messages |
| POST | `/session/{id}/init` | Initialize session (`{messageID, providerID, modelID}`) |
| POST | `/session/{id}/summarize` | Summarize session (`{providerID, modelID}`) |

### ProjectRemoteDataSource (`project_remote_datasource.dart`)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/project` | List all projects |
| GET | `/project/current` | Get current project |

**Total: 29 endpoint operations used by client (including legacy fallbacks)**

### Feature 010 Parity Contract Baseline (Locked 2026-02-09)

- Upstream lock: `anomalyco/opencode@24fd8c1` (`dev`)
- OpenAPI lock: `packages/sdk/openapi.json` (82 route paths at lock time)
- Source references:
  - `https://opencode.ai/docs/server/`
  - `https://opencode.ai/docs/models/`
  - `https://opencode.ai/docs/web/`

Compatibility tiers:

- Fully supported: servers compatible with locked v2 route/event schemas.
- Fallback compatible: legacy server-mode responses that still satisfy core bootstrap/session paths (`/path` or `/app`, `/provider`, `/project/current`, `/session`, `/session/{id}/message`, `/event`).
- Unsupported: missing core paths or incompatible payload shapes for core entities.

### Route Taxonomy (v2 Contract)

| Family | Current client | Required in parity wave (Features 011-015) | Optional post-wave |
|---|---|---|---|
| App bootstrap/config | Partial | `/path`, `/provider`, `/config`, `/project`, `/project/current` (+ `/app` fallback) | `/global/config`, `/global/dispose` |
| Core sessions/messages | Partial | `/session`, `/session/{id}`, `/session/{id}/message`, `/session/{id}/message/{messageId}`, `/event` | `/global/event` |
| Session lifecycle advanced | Partial | `/session/status`, `/session/{id}/children`, `/session/{id}/fork`, `/session/{id}/todo`, `/session/{id}/diff`, plus existing share/revert/abort/init/summarize paths | `/session/{id}/command`, `/session/{id}/shell`, `/session/{id}/permissions/{permissionID}` |
| Interactive flows | Implemented (Feature 013) | `/permission`, `/permission/{requestID}/reply`, `/question`, `/question/{requestID}/reply`, `/question/{requestID}/reject` | Extended decision workflows not covered by app parity tests |
| Tooling/context | Mostly missing | `/find/*`, `/file/*`, `/vcs`, `/mcp/*` (priority subset) | `/lsp`, `/experimental/worktree*`, `/pty*` |

### Feature 013 Realtime Architecture (Implemented 2026-02-09)

- Added dedicated realtime domain and parsing models:
  - `lib/domain/entities/chat_realtime.dart`
  - `lib/data/models/chat_realtime_model.dart`
- Added realtime/interactions use cases:
  - `lib/domain/usecases/watch_chat_events.dart`
  - `lib/domain/usecases/get_chat_message.dart`
  - `lib/domain/usecases/list_pending_permissions.dart`
  - `lib/domain/usecases/reply_permission.dart`
  - `lib/domain/usecases/list_pending_questions.dart`
  - `lib/domain/usecases/reply_question.dart`
  - `lib/domain/usecases/reject_question.dart`
- Extended `ChatProvider` with provider-level reducer and interaction queues:
  - resilient `/event` subscription lifecycle with reconnect
  - state maps for `session.status`, pending permission, pending question
  - fallback full-message fetch on partial/delta events
- Added interaction UI widgets:
  - `lib/presentation/widgets/permission_request_card.dart`
  - `lib/presentation/widgets/question_request_card.dart`

### ChatInput Schema

`POST /session/{id}/message` body:

```
{ model: { providerID, modelID }, variant?, parts: [{type, text}|{type, mime, url}], agent?, system?, tools?, messageID?, noReply? }
```

> **Note:** Current server schema expects `agent`; client domain field `mode` is mapped to `agent` at request serialization.

### MessageTokens Schema

```
{ input: int, output: int, reasoning: int, cache: { read: int, write: int } }
```

### SSE Event Taxonomy (`/event`)

| Event group | Current handling state | Parity contract classification |
|---|---|---|
| `message.updated`, `message.part.updated` | Handled with reducer + fallback fetch for partial payloads | Required |
| `message.removed`, `message.part.removed` | Fully handled in reducer | Required |
| `session.error`, `session.idle` | Fully handled in reducer | Required |
| `session.created`, `session.updated`, `session.deleted`, `session.status` | Fully handled in reducer | Required |
| `permission.asked`, `permission.replied` | Fully handled with pending queue sync | Required |
| `question.asked`, `question.replied`, `question.rejected` | Fully handled with pending queue sync | Required |
| `todo.updated`, `session.diff`, `vcs.branch.updated`, `worktree.ready`, `worktree.failed` | Not handled | Required |
| Other diagnostic/low-impact events | Ignored | Optional |

### Message Part Taxonomy

| Part type | Current handling state | Parity contract classification |
|---|---|---|
| `text`, `file`, `tool`, `reasoning`, `patch` | Implemented | Required |
| `step-start`, `step-finish`, `snapshot` | Parsed + rendered as structured info blocks | Required |
| `agent`, `subtask`, `retry`, `compaction` | Parsed + rendered as structured info blocks | Required |
| Unknown/future part types | Ignored defensively | Optional |

### API Endpoints Not Yet Implemented (Prioritized)

Required for parity wave:

- `/session/status`
- `/session/:id/children`
- `/session/:id/todo`
- `/session/:id/fork`
- `/session/:id/diff`
- `/find/*`
- `/file/*`
- `/vcs`
- `/mcp/*`

Deferred/optional after parity wave:

- `/global/event`
- `/global/config`
- `/global/dispose`
- `/session/:id/permissions/:id`
- `/session/:id/command`
- `/session/:id/shell`
- `/lsp`
- `/experimental/worktree*`
- `/pty*`
- `/mode`
- `/agent`
- `/command`
- `/log`
- `/formatter`
- `/instance/dispose`
- `/provider/auth`
- `/provider/:id/oauth/*`
- `PATCH /config`
- `/doc`
- TUI control routes

## Non-English Content (CJK)

14 files under `lib/` contain Chinese comments and/or string literals:

| Layer | File |
|-------|------|
| core | `core/constants/api_constants.dart` |
| core | `core/errors/exceptions.dart` |
| core | `core/errors/failures.dart` |
| core | `core/network/dio_client.dart` |
| data | `data/datasources/app_local_datasource.dart` |
| data | `data/datasources/app_remote_datasource.dart` |
| data | `data/datasources/chat_remote_datasource.dart` |
| data | `data/datasources/project_remote_datasource.dart` |
| data | `data/models/chat_session_model.dart` |
| data | `data/models/project_model.dart` |
| data | `data/models/provider_model.dart` |
| data | `data/repositories/app_repository_impl.dart` |
| data | `data/repositories/chat_repository_impl.dart` |
| data | `data/repositories/project_repository_impl.dart` |

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Android | Present | Kotlin, full build config |
| Web | Present | PWA manifest, index.html |
| iOS | Absent | No `ios/` directory |
| Windows | Present | Runner/CMake files generated; builds only on Windows host |
| macOS | Present | Runner/Xcode files generated; builds only on macOS host |
| Linux | Present | Runner/CMake files generated; local build validated |

## Quality Baseline

### flutter analyze

- **Total issues: 101**
  - Errors: 0
  - Warnings: 0
  - Info: 101 (mostly deprecated API usage and lint modernization opportunities)
- **Top issue categories:**
  - `deprecated_member_use` (majority): `withOpacity`, `surfaceVariant`, old color roles
  - `overridden_fields` (~5): field overrides in model classes
  - `unnecessary_underscores` (~6): test parameter naming
- **CI Budget:** 186 issues maximum (enforced via `tool/ci/check_analyze_budget.sh`)

### flutter test

- **Result: 47 tests, all passed**
- **Coverage: 35% minimum** (enforced via `tool/ci/check_coverage.sh`)
- **Test structure:**
  - Unit: providers/usecases/models with migration and server-scope assertions
  - Widget: responsive shell, app shell navigation, server settings, and interaction cards
  - Integration: mock-server coverage for SSE reconnect + permission/question flows + error mapping + server-switch isolation
- **Test tags:** `requires_server`, `hardware` (defined in dart_test.yaml)

## CI/CD and Automation

### GitHub Actions Workflow

`.github/workflows/ci.yml` implements a complete CI/CD pipeline with 5 parallel jobs:

| Job | Platform | Timeout | Description |
|-----|----------|---------|-------------|
| **quality** | ubuntu-latest | 35min | Static analysis, tests with coverage, Codecov upload |
| **build-linux** | ubuntu-latest | 25min | Linux desktop release build |
| **build-web** | ubuntu-latest | 20min | Web release build |
| **build-android** | ubuntu-latest | 30min | APK arm64 release build with signing |
| **ci-status** | ubuntu-latest | 5min | Aggregate status reporter |

### Quality Gates

**Static Analysis (check_analyze_budget.sh):**
- Maximum 186 issues allowed
- Parses `flutter analyze` output
- Fails build if budget exceeded

**Code Coverage (check_coverage.sh):**
- Minimum 35% line coverage required
- Filters generated files (*.g.dart, generated_plugin_registrant.dart)
- Uses LCOV with branch coverage disabled (.lcovrc)
- Integrates with Codecov (codecov.yml: project 35%, patch 30%)

**Generated Code Verification:**
- Ensures `build_runner` output is committed
- Prevents drift between generated and versioned code

### Makefile Automation

158-line Makefile with 13 targets:

| Target | Description |
|--------|-------------|
| `help` | Show available targets (default) |
| `deps` | Install Flutter dependencies (`flutter pub get`) |
| `gen` | Run code generation (`dart run build_runner`) |
| `icons` | Regenerate app icons for all supported platforms |
| `icons-check` | Validate icon assets and expected dimensions |
| `analyze` | Static analysis with budget check (186 max) |
| `test` | Run all tests |
| `coverage` | Generate coverage report with threshold check (35% min) |
| `check` | Full validation chain: deps → gen → analyze → test |
| `desktop` | Build desktop binary for current host OS |
| `android` | Build APK + optional Telegram upload (tdl) |
| `precommit` | Complete pre-commit validation: check + android |
| `clean` | Clean build artifacts and reinstall dependencies |

**Telegram Integration:**
- If `tdl` is available, uploads APK to VerselesBot channel
- APK renamed to `codewalk.apk` before upload

### Installation Scripts

**install.sh (Unix/Linux/macOS):**
- Detects platform (Linux/Darwin) and architecture (x86_64/arm64/aarch64)
- Fetches latest GitHub release via API
- Downloads tarball, extracts to `~/.local/bin`
- Verifies PATH includes installation directory

**install.ps1 (Windows PowerShell):**
- Detects architecture (AMD64/ARM64)
- Fetches latest GitHub release via API
- Downloads ZIP, extracts to `%LOCALAPPDATA%\CodeWalk`
- Automatically adds to user PATH
- Cleanup of temporary files

## Dependencies

### Runtime

| Package | Version | Purpose |
|---------|---------|---------|
| flutter | SDK | Framework |
| cupertino_icons | ^1.0.8 | iOS-style icons |
| dio | ^5.4.0 | HTTP client |
| provider | ^6.1.1 | State management |
| shared_preferences | ^2.2.2 | Local storage |
| flutter_markdown | ^0.7.7+1 | Markdown rendering |
| flutter_highlight | ^0.7.0 | Code syntax highlighting |
| file_picker | ^10.3.10 | File picker |
| url_launcher | ^6.2.2 | URL launcher |
| package_info_plus | ^9.0.0 | App version info |
| json_annotation | ^4.8.1 | JSON serialization annotations |
| equatable | ^2.0.5 | Value equality |
| dartz | ^0.10.1 | Functional programming (Either) |
| get_it | ^9.2.0 | Dependency injection |

### Dev

| Package | Version | Purpose |
|---------|---------|---------|
| flutter_test | SDK | Testing framework |
| flutter_lints | ^6.0.0 | Lint rules |
| json_serializable | ^6.7.1 | JSON code generation |
| build_runner | ^2.4.7 | Code generation runner |
| flutter_launcher_icons | ^0.14.4 | App icon generation |

## Architecture

The project follows **Clean Architecture** with three layers:

1. **Domain** — entities, repository interfaces, use cases
2. **Data** — models (with JSON serialization), data sources (remote/local), repository implementations
3. **Presentation** — pages, providers (ChangeNotifier), widgets, theme

Dependency injection via `get_it`. HTTP via `dio`. State management via `provider`.

## Module Overview

### Logging System
- Centralized logging via `AppLogger` (lib/core/logging/app_logger.dart)
- Debug-only gate (no-op in release builds)
- Automatic sanitization of auth tokens (Basic Auth, Bearer)
- Severity levels: debug, info, warn, error
- Replaces direct `print()` calls (deprecated in codebase per CONTRIBUTING.md)

### Authentication and Server Config
- Multi-server profile management (`ServerProfile`) with active/default selection
- Per-server basic auth configuration and URL normalization
- Health-aware activation (`/global/health`, fallback `/path`)

### Session Module
- Session list loading and caching
- Session selection and current session persistence
- Create/delete/update/share operations
- Server-scoped cache isolation to prevent cross-server leakage

### Chat Module
- Streaming send/receive flow (SSE via `/event`)
- Realtime event reducer for `session.*`, `message.*`, `permission.*`, and `question.*`
- Message list rendering with incremental updates + targeted full-message fallback fetch
- Chat input and provider/model context
- In-app provider/model picker and reasoning-variant cycle controls
- In-chat permission/question cards with actionable replies
- Responsive shell with mobile drawer and desktop split-view layout
- Desktop shortcuts for new chat, refresh, and input focus

### Settings Module
- Runtime configuration and theme preferences
- Full server manager UI (add/edit/remove, default, active, health badges)

## Chat System Details

### Core Entities
- `ChatMessage`: supports user and assistant messages with typed parts (`TextPart`, `FilePart`, `ToolPart`, `ReasoningPart`, `PatchPart`, `AgentPart`, `StepStartPart`, `StepFinishPart`, `SnapshotPart`, `SubtaskPart`, `RetryPart`, `CompactionPart`)
- `ChatSession`: session identity, metadata, optional share/summary info, path/workspace linkage
- `MessageTokens`: includes `input`, `output`, `reasoning`, `cacheRead`, `cacheWrite`
- `ProvidersResponse`: includes `providers`, `defaultModels`, `connected`
- `Model`: includes optional `variants` metadata used for reasoning-effort controls
- `ChatEvent`: typed realtime event wrapper with session status and interactive request payloads

### Streaming Flow
- Uses SSE events (`/event`) for incremental message updates
- Send flow forwards active `directory` scope to `/event` and message fallback fetch
- `ChatRemoteDataSource.subscribeEvents()` maintains reconnect/backoff loop
- `ChatProvider` applies reducer transitions per event type
- Client merges event deltas with full message fetch when needed
- Send path records release-visible lifecycle logs (`info`/`warn`) for stream connect/fallback/poll completion diagnostics in `LogsPage`
- Send path includes watchdog polling fallback when stream is connected but no per-message events are emitted
- Provider startup guards cancel stale realtime subscriptions to avoid duplicate `/event` streams
- Standard prompt sends omit `messageID`; that field is reserved for explicit message-targeted workflows
- Provider send setup is wrapped with stage logs and non-blocking selection persistence so local storage issues cannot prevent network send dispatch
- Recent-model preference restoration keeps mutable lists for model-usage updates, avoiding fixed-length list mutation crashes during send setup
- Handles transient errors and stale subscription generation guards

## Test Infrastructure

### Test Organization

```
test/
├── widget_test.dart                          # Original ChatInputWidget test (12 tests)
├── unit/
│   ├── models/
│   │   ├── chat_message_model_test.dart      # Message model serialization
│   │   ├── chat_session_model_test.dart      # Session model serialization
│   │   └── provider_model_test.dart          # Provider model serialization
│   ├── providers/
│   │   ├── app_provider_test.dart            # AppProvider state management + migration/health/switch rules
│   │   └── chat_provider_test.dart           # ChatProvider state + server-scoped cache behavior
│   └── usecases/
│       └── chat_usecases_test.dart           # ChatUseCases domain logic
├── widget/
│   ├── chat_page_test.dart                   # ChatPage responsive shell
│   ├── app_shell_page_test.dart              # Bottom navigation + logs tab interaction
│   ├── interaction_cards_test.dart           # Permission/question UI action dispatch
│   └── server_settings_page_test.dart        # Multi-server manager rendering and unhealthy-switch guard
├── integration/
│   └── opencode_server_integration_test.dart # Mock server SSE flow/reconnect + interaction endpoints + server-switch cache isolation
└── support/
    ├── fakes.dart                             # Fake implementations for testing
    └── mock_opencode_server.dart              # Shelf-based mock OpenCode API server
```

### Test Support Infrastructure

**mock_opencode_server.dart:**
- Shelf-based HTTP server emulating OpenCode API
- Supports `/session`, `/session/{id}/message` endpoints
- Supports `/permission*` and `/question*` interaction endpoints
- Supports `/global/health` for server-health orchestration tests
- SSE event stream simulation for real-time updates and reconnect scenarios
- Controllable error injection for fault testing
- Captures outbound send payload for integration assertions (`variant`, etc.)

**fakes.dart:**
- `FakeAppLocalDataSource`: In-memory SharedPreferences simulation
- `FakeAppRemoteDataSource`: Hardcoded app/path/provider responses
- `FakeChatRemoteDataSource`: In-memory session/message management
- `FakeProjectRemoteDataSource`: Static project list
- Used for isolated unit testing without network dependencies

**tool/qa/feat008_smoke.sh (live smoke):**
- Verifies `/provider`, `/session`, `/event`, and two sequential `/session/{id}/message` turns in the same session
- Uses preferred defaults (`openai` + `gpt-5.1-codex-mini`, variant `low`) with fallback only if unavailable
- Fails when assistant returns `info.error`, when second turn reuses previous assistant ID, or when no non-empty text is produced

### Test Tags (dart_test.yaml)

- `requires_server`: Tests needing live OpenCode server connection
- `hardware`: Tests depending on specific device/platform features

Run specific tags: `flutter test --tags requires_server`

### Coverage Configuration

**.lcovrc:**
```ini
lcov_branch_coverage=0  # Disable branch coverage, focus on line coverage
```

**codecov.yml:**
- Project coverage target: 35% (±3% threshold)
- Patch coverage target: 30% (±10% threshold)
- Ignores: test/**, *.g.dart, generated_plugin_registrant.dart, lib/l10n/**

**Current coverage: 35% minimum enforced by CI**

## Contribution Standards (CONTRIBUTING.md)

### Workflow
1. Create feature branch from `main`
2. Run `make check` locally before committing
3. Submit PR with descriptive title and body
4. All CI checks must pass (quality, builds)

### Commit Convention
- Follow Conventional Commits specification
- Format: `type(scope): description`
- Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`
- Examples:
  - `feat(chat): add message retry on network error`
  - `fix(provider): prevent null state on load failure`
  - `docs(readme): update installation instructions`

### Coding Guidelines
- **Use `AppLogger`** instead of `print()` for all logging
- **No direct print() calls** in production code (deprecated)
- Run `make precommit` before every commit
- Ensure generated code (*.g.dart) is committed after changes
- Follow Clean Architecture layer separation
- Write tests for new features and bug fixes

### Quality Requirements
- Static analysis: max 186 issues (enforced by CI)
- Test coverage: minimum 35% (enforced by CI)
- All tests must pass
- Generated code must be up-to-date

### Issue Reporting
- Use descriptive titles
- Include reproduction steps for bugs
- Provide environment details (Flutter version, platform, device)
- Attach logs with sanitized credentials

## Version and Release

**Current version:** `1.0.1+2` (defined in pubspec.yaml)
- Version format: `MAJOR.MINOR.PATCH+BUILD`
- Android: versionName = 1.0.1, versionCode = 2
- Build artifacts uploaded via CI on successful builds

**Release artifacts:**
- Linux: tarball with binary
- Web: static site bundle
- Android: signed APK (arm64-v8a)

## Configuration Files Summary

| File | Purpose |
|------|---------|
| `analysis_options.yaml` | Flutter/Dart linter configuration |
| `dart_test.yaml` | Test tags (requires_server, hardware) |
| `.lcovrc` | LCOV coverage options (branch coverage disabled) |
| `codecov.yml` | Codecov integration (35% project, 30% patch) |
| `pubspec.yaml` | Dependency and version management |
| `Makefile` | Build automation (13 targets, 158 lines) |
| `.github/workflows/ci.yml` | CI/CD pipeline (5 jobs) |
| `CONTRIBUTING.md` | Contribution guidelines and standards |

## Recent Changes Since Previous Baseline

**Feature 009 (commits 5125edd, da2940b, cc5c78f):**
- Added comprehensive test suite (27 tests: unit, widget, integration)
- Implemented CI/CD pipeline with GitHub Actions
- Created quality gates (analyze budget 186, coverage 35%)
- Added centralized logging system (AppLogger)
- Expanded Makefile from 8 to 67 lines
- Created cross-platform installation scripts
- Added CONTRIBUTING.md with coding standards
- Reduced static analysis issues from 178 to 136

**Infrastructure improvements:**
- Mock OpenCode server for integration testing
- Fake data sources for isolated unit tests
- Coverage reporting with Codecov integration
- Automated APK builds with optional Telegram upload
- Generated code verification in CI

**Quality metrics evolution:**
- Tests: 1 → 27 (+2600%)
- Analyze issues: 178 → 136 (-24%)
- Coverage enforcement: none → 35% minimum
- CI jobs: none → 5 parallel jobs

**Feature 011 (completed):**
- Added multi-server persistence model with legacy migration from `server_host`/`server_port`.
- Added active/default server orchestration with health checks and safe-switch constraints.
- Refactored local persistence and chat provider state to server-scoped keys.
- Added server manager UX and app-bar quick switcher.
- Expanded tests for migration/switching/isolation and raised total passing tests to 35.

**Feature 012 (completed):**
- Added provider/model picker controls in chat composer flow with server-scoped persistence.
- Added typed model-variant parsing from `/provider` and variant-cycle UX for reasoning effort.
- Added `variant` serialization in outbound chat payloads for parity with OpenCode v2 prompt schema.
- Added server-scoped recent/frequent model usage tracking and restoration across launches.
- Expanded unit/widget/integration coverage for variant parsing, cycling, persistence, and payload assertions (40 tests passing).
