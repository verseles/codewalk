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
| `.dart` (source) | 55 | Under `lib/` (excluding generated) |
| `.g.dart` (generated) | 4 | JSON serialization models |
| `.dart` (tests) | 11 | Test files (unit, widget, integration, support) |
| `.dart` (total) | 71 | All Dart files including .dart_tool |
| `.md` (markdown) | 15 | Docs + roadmap + CONTRIBUTING.md |
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

**Total: 23 endpoint operations used by client (including legacy fallbacks)**

### ChatInput Schema

`POST /session/{id}/message` body:

```
{ model: { providerID, modelID }, parts: [{type, text}|{type, mime, url}], agent?, system?, tools?, messageID?, noReply? }
```

> **Note:** Current server schema expects `agent`; client domain field `mode` is mapped to `agent` at request serialization.

### MessageTokens Schema

```
{ input: int, output: int, reasoning: int, cache: { read: int, write: int } }
```

### Supported Event Types (SSE `/event`)

| Event | Handled | Description |
|-------|---------|-------------|
| `message.updated` | Yes | Message info updated |
| `message.part.updated` | Yes | Part content updated |
| `message.removed` | Logged | Message removed from session |
| `message.part.removed` | Logged | Part removed from message |
| `session.updated` | Logged | Session metadata changed |
| `session.error` | Yes | Session error (closes stream) |
| `session.idle` | Yes | Session went idle (closes stream) |
| `session.deleted` | Logged | Session deleted |
| Others | Ignored | `file.edited`, `permission.updated`, `installation.updated`, etc. |

### Part Types

| Type | Supported | Fields |
|------|-----------|--------|
| `text` | Yes | `text`, `time?`, `synthetic?` |
| `file` | Yes | `url`, `mime`, `filename?`, `source?` (FileSource or SymbolSource) |
| `tool` | Yes | `callID`, `tool`, `state` |
| `reasoning` | Yes | `text`, `time?` |
| `patch` | Yes | `files: string[]`, `hash: string` |
| `step-start` | Parsed | Metadata only |
| `step-finish` | Parsed | `tokens`, `cost` |
| `snapshot` | Parsed | `snapshot: string` |

### API Endpoints Not Yet Implemented

Available in the server API but not used by the client: `/global/health`, `/global/event`, `/session/status`, `/session/:id/children`, `/session/:id/todo`, `/session/:id/fork`, `/session/:id/diff`, `/session/:id/permissions/:id`, `/find/*`, `/file/*`, `/mode`, `/agent`, `/command`, `/log`, `/mcp`, `/lsp`, `/formatter`, `/vcs`, `/instance/dispose`, `/provider/auth`, `/provider/:id/oauth/*`, `PATCH /config`, `/doc`, TUI control routes.

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

- **Total issues: 136** (reduced from 178 baseline)
  - Errors: 0
  - Warnings: 1 (`unused_local_variable` in test support)
  - Info: ~135 (deprecated API usage, unnecessary_underscores in tests)
- **Top issue categories:**
  - `deprecated_member_use` (~95): `withOpacity`, `surfaceVariant`
  - `overridden_fields` (~5): field overrides in model classes
  - `unnecessary_underscores` (~7): test parameter naming
- **CI Budget:** 186 issues maximum (enforced via `tool/ci/check_analyze_budget.sh`)

### flutter test

- **Result: 27 tests, all passed**
- **Coverage: 35% minimum** (enforced via `tool/ci/check_coverage.sh`)
- **Test structure:**
  - 12 tests: widget_test.dart (ChatInputWidget)
  - 3 tests: unit/providers/app_provider_test.dart
  - 6 tests: unit/providers/chat_provider_test.dart
  - 3 tests: widget/chat_page_test.dart
  - 3 tests: integration/opencode_server_integration_test.dart
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

67-line Makefile with 9 targets:

| Target | Description |
|--------|-------------|
| `help` | Show available targets (default) |
| `deps` | Install Flutter dependencies (`flutter pub get`) |
| `gen` | Run code generation (`dart run build_runner`) |
| `analyze` | Static analysis with budget check (186 max) |
| `test` | Run all tests |
| `coverage` | Generate coverage report with threshold check (35% min) |
| `check` | Full validation chain: deps → gen → analyze → test |
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
- Server host/port setup, API key/basic auth configuration
- Connection checks and error feedback

### Session Module
- Session list loading and caching
- Session selection and current session persistence
- Create/delete/update/share operations

### Chat Module
- Streaming send/receive flow (SSE via `/event`)
- Message list rendering and incremental updates
- Chat input and provider/model context
- Responsive shell with mobile drawer and desktop split-view layout
- Desktop shortcuts for new chat, refresh, and input focus

### Settings Module
- Runtime configuration and theme preferences
- Provider defaults and server details

## Chat System Details

### Core Entities
- `ChatMessage`: supports user and assistant messages with typed parts (`TextPart`, `FilePart`, `ToolPart`, `ReasoningPart`, `PatchPart`)
- `ChatSession`: session identity, metadata, optional share/summary info, path/workspace linkage
- `MessageTokens`: includes `input`, `output`, `reasoning`, `cacheRead`, `cacheWrite`
- `ProvidersResponse`: includes `providers`, `defaultModels`, `connected`

### Streaming Flow
- Uses SSE events (`/event`) for incremental message updates
- Client merges event updates with full message fetch when needed
- Handles transient errors and stream close/reconnect paths

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
│   │   ├── app_provider_test.dart            # AppProvider state management (3 tests)
│   │   └── chat_provider_test.dart           # ChatProvider state management (6 tests)
│   └── usecases/
│       └── chat_usecases_test.dart           # ChatUseCases domain logic
├── widget/
│   └── chat_page_test.dart                   # ChatPage responsive shell (3 tests)
├── integration/
│   └── opencode_server_integration_test.dart # Mock server SSE flow (3 tests)
└── support/
    ├── fakes.dart                             # Fake implementations for testing
    └── mock_opencode_server.dart              # Shelf-based mock OpenCode API server
```

### Test Support Infrastructure

**mock_opencode_server.dart:**
- Shelf-based HTTP server emulating OpenCode API
- Supports `/session`, `/session/{id}/message` endpoints
- SSE event stream simulation for real-time updates
- Controllable error injection for fault testing

**fakes.dart:**
- `FakeAppLocalDataSource`: In-memory SharedPreferences simulation
- `FakeAppRemoteDataSource`: Hardcoded app/path/provider responses
- `FakeChatRemoteDataSource`: In-memory session/message management
- `FakeProjectRemoteDataSource`: Static project list
- Used for isolated unit testing without network dependencies

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
| `Makefile` | Build automation (9 targets, 67 lines) |
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
