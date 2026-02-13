# CodeWalk - Codebase Baseline Snapshot

> Captured: 2026-02-13
> Git baseline: `b6f8d7f fix(diff): render edit/patch tool diffs reliably` (main)
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
│   │   ├── config/    # Feature flags and runtime rollout switches
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
│   │   ├── pages/       # App Shell, Chat, Home, Logs, Server Settings
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
├── QA.feat016.release-readiness.md # Feature 016 parity QA matrix and defect triage
├── RELEASE_NOTES.md   # Release signoff notes and known limitations
├── install.sh         # Unix installer script
├── install.ps1        # Windows installer script
├── uninstall.sh       # Unix uninstaller script
├── uninstall.ps1      # Windows uninstaller script
└── Makefile           # Build automation and packaging gates
```

## File Counts

| Type | Count | Notes |
|------|-------|-------|
| `.dart` (source) | 104 | Under `lib/` (excluding generated) |
| `.g.dart` (generated) | 4 | JSON serialization models |
| `.dart` (tests) | 27 | Test files (unit, widget, integration, support) |
| `.dart` (total) | 135 | Repository files excluding build artifacts |
| `.md` (markdown) | 9 | Docs + roadmap + release artifacts |
| `.sh` (scripts) | 7 | CI validation + installer/uninstaller scripts |

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
| GET | `/session` | List sessions (`directory`, `search`, `roots`, `start`, `limit`) |
| GET | `/session/{id}` | Get session details |
| POST | `/session` | Create session |
| PATCH | `/session/{id}` | Update session |
| DELETE | `/session/{id}` | Delete session |
| POST | `/session/{id}/share` | Share session |
| DELETE | `/session/{id}/share` | Unshare session |
| POST | `/session/{id}/fork` | Fork session (`{messageID?}`) |
| GET | `/session/status` | Snapshot status map for all sessions |
| GET | `/session/{id}/children` | List forked child sessions |
| GET | `/session/{id}/todo` | List session todo items |
| GET | `/session/{id}/diff` | List session diff files (`messageID?`) |
| GET | `/session/{id}/message` | List messages |
| GET | `/session/{id}/message/{messageId}` | Get specific message |
| POST | `/session/{id}/message` | Send message (streaming via SSE) |
| POST | `/session/{id}/shell` | Execute shell-mode prompt command |
| GET | `/event` | SSE event stream |
| GET | `/global/event` | Global SSE event stream (cross-context sync) |
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
| PATCH | `/project/{id}` | Set current project |
| GET | `/experimental/worktree` | List worktrees |
| POST | `/experimental/worktree` | Create worktree |
| DELETE | `/experimental/worktree` | Delete worktree (`id` query) |
| POST | `/experimental/worktree/reset` | Reset worktree (`id` payload) |

**Total: 41 endpoint operations used by client (including legacy fallbacks)**

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
| Core sessions/messages | Implemented | `/session`, `/session/{id}`, `/session/{id}/message`, `/session/{id}/message/{messageId}`, `/event`, `/global/event` | Extended global orchestration routes not used by mobile client |
| Session lifecycle advanced | Implemented (Feature 014) | `/session/status`, `/session/{id}/children`, `/session/{id}/fork`, `/session/{id}/todo`, `/session/{id}/diff`, plus existing share/revert/abort/init/summarize paths | `/session/{id}/command`, `/session/{id}/shell`, `/session/{id}/permissions/{permissionID}` |
| Interactive flows | Implemented (Feature 013) | `/permission`, `/permission/{requestID}/reply`, `/question`, `/question/{requestID}/reply`, `/question/{requestID}/reject` | Extended decision workflows not covered by app parity tests |
| Tooling/context | Partial | `/find/file`, `/file/*`, `/vcs`, `/mcp/*` (priority subset) + `/experimental/worktree*` | `/lsp`, `/pty*` |

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

### Feature 014 Session Lifecycle Architecture (Implemented 2026-02-10)

- Added domain lifecycle entities and contracts:
  - `lib/domain/entities/chat_session.dart` (`archivedAt`, `shareUrl`, `parentId`, `SessionTodo`, `SessionDiff`)
  - `lib/domain/repositories/chat_repository.dart` (fork/status/children/todo/diff operations)
- Added lifecycle use cases:
  - `lib/domain/usecases/update_chat_session.dart`
  - `lib/domain/usecases/share_chat_session.dart`
  - `lib/domain/usecases/unshare_chat_session.dart`
  - `lib/domain/usecases/fork_chat_session.dart`
  - `lib/domain/usecases/get_session_status.dart`
  - `lib/domain/usecases/get_session_children.dart`
  - `lib/domain/usecases/get_session_todo.dart`
  - `lib/domain/usecases/get_session_diff.dart`
- Expanded data layer for lifecycle endpoints and models:
  - `lib/data/datasources/chat_remote_datasource.dart`
  - `lib/data/models/chat_session_model.dart`
  - `lib/data/models/session_lifecycle_model.dart`
  - `lib/data/repositories/chat_repository_impl.dart`
- Extended `ChatProvider` lifecycle orchestration:
  - optimistic rename/archive/share/delete with rollback
  - session insight hydration (`status`, `children`, `todo`, `diff`)
  - session list search/filter/sort/load-more state
  - reducer support for `todo.updated` and `session.diff`
- Updated lifecycle UI surfaces:
  - `lib/presentation/widgets/chat_session_list.dart` action menu (rename/share/archive/fork/delete)
  - `lib/presentation/pages/chat_page.dart` session controls and insight chips/panel

### Feature 015 Project/Workspace Context Architecture (Implemented 2026-02-10)

- Added project/worktree domain and remote contracts:
  - `lib/domain/entities/worktree.dart`
  - `lib/domain/repositories/project_repository.dart` (worktree methods)
  - `lib/data/models/worktree_model.dart`
  - `lib/data/datasources/project_remote_datasource.dart` (`/project/{id}`, `/experimental/worktree*`)
- Added global event stream use case and repository support:
  - `lib/domain/usecases/watch_global_chat_events.dart`
  - `lib/domain/repositories/chat_repository.dart` (`subscribeGlobalEvents`)
  - `lib/data/repositories/chat_repository_impl.dart`
  - `lib/data/datasources/chat_remote_datasource.dart` (`/global/event`)
- Expanded local persistence for project context scoping:
  - `lib/data/datasources/app_local_datasource.dart`
  - `lib/core/constants/app_constants.dart` (`currentProjectId`, `openProjectIds`)
- Evolved provider orchestration for deterministic context isolation:
  - `lib/presentation/providers/project_provider.dart` (open/close/reopen/switch + worktree actions)
  - `lib/presentation/providers/chat_provider.dart` (context snapshots, dirty-context invalidation, global event sync, resilient SSE teardown)
- Updated chat UI with project/workspace controls and active-context indicator:
  - `lib/presentation/pages/chat_page.dart`
  - Workspace creation dialog now accepts optional base-directory override to make project-folder targeting explicit.
  - Workspace creation now includes a server-backed directory browser (`/file`) and validates Git context (`/vcs`) before submit.
  - Directory picker now surfaces a git-only warning, and successful workspace creation force-switches context to the newly created directory.
- Added workspace operation telemetry in `ProjectProvider` so `create/reset/delete` failures and user-facing provider errors are emitted to the in-app Logs stream.

### Feature 016 Reliability and Release-Readiness Architecture (Implemented 2026-02-10)

- Added parity-wave release gate with explicit evidence contract:
  - automated coverage expansion (unit/widget/integration),
  - manual scenario matrix IDs `PAR-001`..`PAR-008`,
  - platform runtime/build smoke requirements and documented known limitations.
- Added release-readiness artifacts:
  - `QA.feat016.release-readiness.md` for matrix execution and defect triage,
  - `RELEASE_NOTES.md` for parity-wave signoff summary.
- Expanded parity-focused tests for:
  - server-scoped model selection restore across server switches,
  - question reject flow in provider + chat widget integration,
  - `/question/{id}/reject` integration coverage in mock server route contract.

### Feature 017 Realtime-First Refreshless Architecture (Implemented 2026-02-10)

- Added refreshless rollout guardrail:
  - `lib/core/config/feature_flags.dart` (`CODEWALK_REFRESHLESS_ENABLED`, default `true`)
- Expanded `ChatProvider` realtime orchestration:
  - sync state machine (`connected` / `reconnecting` / `delayed`)
  - lifecycle-aware stream policy (`setForegroundActive`) with background suspend and resume reconcile
  - degraded mode with slow scoped polling (`30s`) only when SSE health degrades
  - scoped reconcile queue replacing broad refresh patterns
  - broader incremental reducer support (`message.created`, `permission.updated`, `question.updated`) plus global-event incremental application
- Updated `ChatPage` UX to refreshless-first:
  - removed manual refresh affordances in target chat/context flows when feature flag is enabled
  - removed legacy 5-second active-screen refresh loop
  - added sync status indicator (`Connected`, `Reconnecting`, `Sync delayed`) in the app bar on non-mobile layouts
  - kept rollback path: manual refresh controls are conditionally available when feature flag is disabled
- Expanded coverage:
  - unit tests for degraded enter/recover, foreground resume reconcile, and global incremental updates
  - widget tests for reconnect behavior without periodic polling and refresh-control absence

### Feature 019 File Explorer and Viewer Parity (Implemented 2026-02-11)

- Added project-layer file domain/contracts for parity endpoints:
  - `lib/domain/entities/file_node.dart`
  - `lib/domain/repositories/project_repository.dart` (`listFiles`, `findFiles`, `readFileContent`)
  - `lib/data/models/file_node_model.dart`
  - `lib/data/models/file_content_model.dart`
  - `lib/data/datasources/project_remote_datasource.dart` (`/file`, `/find/file`, `/file/content`)
  - `lib/data/repositories/project_repository_impl.dart`
  - `lib/presentation/providers/project_provider.dart` (file list/search/read wrappers with provider-level error handling)
- Extended `ChatPage` with file explorer/viewer orchestration:
  - context-keyed explorer state, root/tree lazy loading, quick-open dialog, and tab lifecycle
  - builtin `/open` now invokes quick-open instead of placeholder snackbar
  - file viewer moved from chat header area into the `Files` surface (desktop pane + mobile Files dialog)
  - `N open files` action added in the `Files` header (between title and quick actions) to open tab management dialog
  - open-files dialog policy: fullscreen on compact/mobile, centered at ~70% viewport on larger screens
  - diff-aware tab reload + tree invalidation based on `session.diff`
- Added reusable ranking/reducer logic:
  - `lib/presentation/utils/file_explorer_logic.dart` (quick-open ranking + tab open/close/activate reducers)
- Expanded coverage:
  - `test/unit/utils/file_explorer_logic_test.dart`
  - `test/widget/chat_page_test.dart` cases for tree expand/open, quick-open, and viewer text/binary/error rendering

### Feature 018 Prompt Power Composer Architecture (Implemented 2026-02-10)

- Extended composer state machine in `ChatInputWidget`:
  - trigger-aware mode orchestration (`normal`/`shell`) with `!` activation at offset 0
  - popover orchestration for `@` mentions and `/` slash commands
  - suggestion popover rendered inline above the input row (without global overlay), keeping input + keyboard interaction stable on mobile and desktop
  - popover sizing uses a single cap rule for all layouts: up to `3x` input height, clamped by visible viewport after reserving input space; long lists scroll internally
  - composer `SafeArea` now ignores top inset to avoid unnecessary vertical growth while keyboard is open on Android
  - keyboard navigation and selection (`ArrowUp/Down`, `Enter`, `Tab`, `Esc`)
  - input focus persistence while mention/slash suggestions refresh
  - mention insertion normalizes trailing spacing to avoid token/punctuation glue on mobile
  - mention token chips rendered from prompt text
- Added contextual suggestion fetching in `ChatPage`:
  - mention sources from `/find/file` plus provider-managed agent cache loaded from `/agent`
  - slash catalog from builtin commands plus `/command` (with `source` badges)
  - builtin slash handlers (`/new`, `/model`, `/agent`, `/open`, `/help`) executed directly in UI context (`/agent` opens agent selector)
  - composer returned to scaffold-native keyboard inset handling (`resizeToAvoidBottomInset`) to keep input above mobile keyboard consistently
- Added shell send-path routing:
  - `ChatProvider.sendMessage(..., shellMode: true)` marks payload mode as shell
  - `ChatRemoteDataSource.sendMessage` routes shell-mode payloads to `POST /session/{id}/shell`
  - shell request contract currently uses `{agent: "build", command: "<text>"}` and returns assistant message payload
- Expanded coverage:
  - widget tests for shell-mode submit and `@`/`/` popover insertion flows
  - provider unit test for shell payload mode propagation

### ChatInput Schema

`POST /session/{id}/message` body:

```
{ model: { providerID, modelID }, variant?, parts: [{type, text}|{type, mime, url}], agent?, system?, tools?, messageID?, noReply? }
```

> **Note:** Current server schema expects `agent`; client domain field `mode` is mapped to `agent` at request serialization. `mode='shell'` is still reserved for shell route handling.

### MessageTokens Schema

```
{ input: int, output: int, reasoning: int, cache: { read: int, write: int } }
```

### SSE Event Taxonomy (`/event`)

| Event group | Current handling state | Parity contract classification |
|---|---|---|
| `message.created`, `message.updated`, `message.part.updated` | Handled with reducer + fallback fetch for partial payloads | Required |
| `message.removed`, `message.part.removed` | Fully handled in reducer | Required |
| `session.error`, `session.idle` | Fully handled in reducer | Required |
| `session.created`, `session.updated`, `session.deleted`, `session.status` | Fully handled in reducer | Required |
| `permission.asked`, `permission.updated`, `permission.replied` | Fully handled with pending queue sync | Required |
| `question.asked`, `question.updated`, `question.replied`, `question.rejected` | Fully handled with pending queue sync | Required |
| `todo.updated`, `session.diff` | Fully handled in reducer (session insight maps) | Required |
| `vcs.branch.updated`, `worktree.ready`, `worktree.failed` | Not handled | Required |
| Other diagnostic/low-impact events | Ignored | Optional |

### Message Part Taxonomy

| Part type | Current handling state | Parity contract classification |
|---|---|---|
| `text`, `file`, `tool`, `reasoning`, `patch` | Implemented | Required |
| `step-start`, `step-finish`, `snapshot` | Parsed; details accessible via assistant info menu | Required |
| `agent`, `subtask`, `retry`, `compaction` | Parsed + rendered as structured info blocks | Required |
| Unknown/future part types | Ignored defensively | Optional |

### API Endpoints Not Yet Implemented (Prioritized)

Required for parity wave:

- `/find/*` (except `/find/file`)
- `/mcp/*`

Deferred/optional after parity wave:

- `/global/config`
- `/global/dispose`
- `/session/:id/permissions/:id`
- `/session/:id/command`
- `/lsp`
- `/pty*`
- `/mode`
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

- **Total issues: 83**
  - Errors: 0
  - Warnings: 1 (`unnecessary_non_null_assertion`)
  - Info: 82 (mostly `unnecessary_underscores` in test parameter naming)
- **Top issue categories:**
  - `unnecessary_underscores` (majority): test parameter naming conventions
  - `unnecessary_non_null_assertion` (1): test assertion cleanup opportunity
- **CI Budget:** 186 issues maximum (enforced via `tool/ci/check_analyze_budget.sh`)

### flutter test

- **Result: 218 tests, all passed** (latest full run with coverage)
- **Coverage: 35% minimum** (enforced via `tool/ci/check_coverage.sh`)
- **Test structure:**
  - Unit: providers/usecases/models with migration, server/context-scope assertions, lifecycle optimistic-rollback, and project/worktree orchestration
  - Widget: responsive shell, app shell navigation, server settings, interaction cards, and session lifecycle action menu
  - Integration: mock-server coverage for SSE reconnect + permission/question flows + lifecycle/worktree endpoints + server-switch/context isolation
- **Test tags:** `requires_server`, `hardware` (defined in dart_test.yaml)

## CI/CD and Automation

### GitHub Actions Workflows

`codewalk` uses two GitHub Actions workflows:

1. `.github/workflows/ci.yml` for continuous integration on pushes/PRs.
2. `.github/workflows/release.yml` for GitHub Releases on version tags (`v*`) or manual dispatch.

`ci.yml` implements a complete CI/CD validation pipeline with 5 parallel jobs:

| Job | Platform | Timeout | Description |
|-----|----------|---------|-------------|
| **quality** | ubuntu-latest | 35min | Static analysis, tests with coverage, Codecov upload |
| **build-linux** | ubuntu-latest | 25min | Linux desktop release build |
| **build-web** | ubuntu-latest | 20min | Web release build |
| **build-android** | ubuntu-latest | 30min | APK arm64 release build with signing |
| **ci-status** | ubuntu-latest | 5min | Aggregate status reporter |

`release.yml` publishes installable artifacts and a GitHub Release with 6 jobs:

| Job | Platform | Timeout | Description |
|-----|----------|---------|-------------|
| **build-linux** | ubuntu-latest | 30min | Linux release build + `codewalk-linux-x64.tar.gz` |
| **build-windows** | windows-latest | 35min | Windows release build + `codewalk-windows-x64.zip` |
| **build-macos-arm64** | macos-15 | 35min | macOS arm64 release build + `codewalk-macos-arm64.tar.gz` |
| **build-macos-x64** | macos-15-intel | 35min | macOS x64 release build + `codewalk-macos-x64.tar.gz` |
| **build-android** | ubuntu-latest | 35min | Android arm64 release APK |
| **create-release** | ubuntu-latest | 10min | Downloads artifacts and publishes GitHub Release |

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

181-line Makefile with 13 targets:

| Target | Description |
|--------|-------------|
| `help` | Show available targets (default) |
| `deps` | Install Flutter dependencies (`flutter pub get`) |
| `gen` | Run code generation (`dart run build_runner`) |
| `icons` | Regenerate app icons for all supported platforms, including Linux Freedesktop metadata |
| `icons-check` | Validate icon assets, expected dimensions, and Linux desktop entry fields |
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
- Caption is dynamic by default (latest commit subject) and can be overridden via `TDL_CAPTION`

### Installation Scripts

**install.sh (Unix/Linux/macOS):**
- Detects platform (Linux/Darwin) and architecture (x86_64/arm64/aarch64)
- Fetches latest GitHub release via API
- Supports idempotent reruns (fresh install, update, or reinstall)
- Downloads tarball and extracts to user-local application data path
- Creates CLI link in `~/.local/bin/codewalk`
- Linux: registers Freedesktop desktop entry + icon in user scope
- macOS: if an app bundle exists, installs it to `~/Applications/CodeWalk.app`
- Persists installed version marker for future update/reinstall detection

**install.ps1 (Windows PowerShell):**
- Detects architecture (AMD64/ARM64)
- Fetches latest GitHub release via API
- Supports idempotent reruns (fresh install, update, or reinstall)
- Downloads ZIP, extracts to `%LOCALAPPDATA%\CodeWalk`
- Automatically adds to user PATH
- Creates Start Menu shortcut with executable icon
- Persists installed version marker for future update/reinstall detection
- Cleanup of temporary files

**uninstall.sh / uninstall.ps1:**
- Remove local installation folders and launcher integrations
- Linux: remove user desktop entry and icon cache references
- macOS: remove `~/Applications/CodeWalk.app`
- Windows: remove Start Menu shortcut and user PATH entry

## Dependencies

### Runtime

| Package | Version | Purpose |
|---------|---------|---------|
| flutter | SDK | Framework |
| cupertino_icons | ^1.0.8 | iOS-style icons |
| dio | ^5.4.0 | HTTP client |
| provider | ^6.1.1 | State management |
| shared_preferences | ^2.2.2 | Local storage |
| flutter_markdown_plus | ^1.0.7 | Markdown rendering |
| flutter_highlight | ^0.7.0 | Code syntax highlighting |
| file_picker | ^10.3.10 | File picker |
| speech_to_text | ^7.3.0 | Voice input dictation |
| url_launcher | ^6.2.2 | URL launcher |
| package_info_plus | ^9.0.0 | App version info |
| json_annotation | ^4.8.1 | JSON serialization annotations |
| equatable | ^2.0.5 | Value equality |
| dartz | ^0.10.1 | Functional programming (Either) |
| get_it | ^9.2.0 | Dependency injection |
| web | ^1.1.1 | Web API interop for browser notification bridge |
| dynamic_color | ^1.8.1 | Material You dynamic color schemes |
| flutter_local_notifications | ^20.0.0 | Cross-platform local notifications |
| audioplayers | ^6.5.1 | Sound playback for notification audio |
| simple_icons | git (381d0cb) | Simple Icons brand icons |

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
- Legacy migration creates a profile only when legacy server/auth keys exist; clean installs now keep an empty server list until the user adds one

### Session Module
- Session list loading and caching
- Session list controls: search/filter/sort/load-more windowing
- Session selection and current session persistence
- New-session creation now guarantees immediate focus on the created session and persists scoped `current_session_id`
- Last-session snapshot persistence (`session + messages`) scoped by `server + directory` for instant startup restore
- Stale-while-revalidate startup flow: cached last conversation renders immediately and message list revalidates silently in background
- Full lifecycle operations: create/delete/rename/archive/unarchive/share/unshare/fork
- Automatic AI title generation via `ch.at` after each user/assistant turn using up to the first 3 user + 3 assistant text messages, with per-session consolidation guard to stop after the 3+3 baseline is reached
- Session insights orchestration: status snapshot + children/todo/diff hydration
- Optimistic session mutations with rollback on API failure
- Server-scoped cache isolation to prevent cross-server leakage

### Chat Module
- Streaming send/receive flow (SSE via `/event`)
- Global context sync stream (`/global/event`) for cross-directory invalidation
- Realtime event reducer for `session.*`, `message.*`, `permission.*`, and `question.*`
- Message list rendering with incremental updates + targeted full-message fallback fetch
- Optimistic local user messages are reconciled with server-confirmed user messages to prevent duplicate visual bubbles
- Chat input and provider/model context
- Chat composer supports image/PDF attachments via `file_picker`, serializes `file` parts with `mime` + `url`, and hides the attachment action when the selected model does not advertise attachment/image/pdf input support
- Attachment menu options are modality-aware per model: when a model supports only image or only PDF, the composer sheet exposes only the supported option(s)
- Chat composer includes a microphone action (next to send) that runs speech-to-text via `speech_to_text` and writes live dictation into the same text input
- Send button has a secondary composer action: hold for 300ms inserts a newline at cursor/selection instead of sending, with a small corner icon indicator for discoverability
- Chat composer supports prompt power triggers: `@` contextual mentions (files/agents), leading `!` shell mode, and leading `/` slash command catalog with source badges
- Shell-mode sends use a dedicated server route (`/session/{id}/shell`) through datasource-level routing
- File explorer parity in chat:
  - server-backed tree listing (`/file`) with expandable directories and file-type icons
  - quick-open dialog (`Ctrl/Cmd+P` + `/open`, plus `Files` panel quick action) using ranked search from `/find/file`
  - file viewer tabs with states `loading`, `ready`, `empty`, `binary`, and `error` sourced from `/file/content`, now centered in the `Files` surface (not in chat header area)
  - `Open files` dialog with tab close controls (`X`) and adaptive sizing (mobile fullscreen, desktop centered ~70% viewport)
  - context-keyed explorer/tab state with diff-aware refresh to avoid cross-directory leakage
- In-app provider/model picker and reasoning-variant cycle controls
- In-app agent selector beside model/variant controls with ordered options (`build`, `plan`, then others), context-scoped persistence (`server + directory`) and safe fallback when persisted selection disappears
- Agent quick actions include desktop shortcut cycle (`Ctrl/Cmd+J`, `Shift` reverse) and builtin `/agent` command opening the selector
- In-chat permission/question cards with actionable replies
- Directory-scoped context snapshots and dirty-context refresh strategy
- Chat-first shell: `AppShellPage` mounts `ChatPage` as primary route; `Logs` and `Settings` open as secondary routes with native back navigation to chat
- Startup onboarding guard: when no server profile exists, `AppShellPage` routes directly to `Settings > Servers` (mobile and desktop)
- Responsive shell with mobile drawer and desktop split-view layout
- Sidebar top action row appears above `Conversations`: compact one-line `Logs` and `Settings` buttons open secondary routes while chat remains implicit as the primary area
- Desktop shortcuts for new chat, refresh, input focus, and agent cycle

### Settings Module
- Modular settings hub (`SettingsPage`) with responsive section navigation:
  - mobile: section list -> detail flow
  - desktop/web: split layout (left navigation + right content)
- Experience settings persistence (`experience_settings`) for:
  - notification controls by category (`agent`, `permissions`, `errors`)
    - sync from `/config` when server exposes compatible notification keys (`settings-notifications-*` or `notifications.*`)
    - fallback to local-only persistence when server config keys are unavailable
  - per-category split controls for `Notify` and `Sound` in the Notifications section (users can enable only one of them)
  - sound preference by category (configured in Notifications) with preview and fallback behavior
    - sound playback uses generated in-memory WAV tones via `audioplayers` for consistent output across platforms
  - notification payload includes `sessionId` for deep-link on notification tap back to the originating session
- editable shortcut bindings with conflict validation and reset
  - shortcuts section is available on desktop/web and hidden on mobile platforms
- dedicated Sounds section was removed after Notifications absorbed all per-category sound controls
- Server management moved into a dedicated `Servers` section:
  - add/edit/remove, active/default, health badges and activation guard
  - per-server privacy toggle `Enable AI generated titles` controls whether background title generation is allowed for that server profile
- Chat keyboard shortcuts are now resolved from persisted settings via runtime binding parsing
- Notification runtime adapters:
  - Android/Linux/macOS/Windows through `flutter_local_notifications`
  - Web through browser Notification API permission flow + click callback wiring

## Chat System Details

### Core Entities
- `ChatMessage`: supports user and assistant messages with typed parts (`TextPart`, `FilePart`, `ToolPart`, `ReasoningPart`, `PatchPart`, `AgentPart`, `StepStartPart`, `StepFinishPart`, `SnapshotPart`, `SubtaskPart`, `RetryPart`, `CompactionPart`)
- `ChatSession`: session identity, parent/directory linkage, archive/share metadata, optional summary and path info
- `SessionTodo` / `SessionDiff`: session insight entities used by lifecycle panel and reducer updates
- `MessageTokens`: includes `input`, `output`, `reasoning`, `cacheRead`, `cacheWrite`
- `ProvidersResponse`: includes `providers`, `defaultModels`, `connected`
- `Model`: includes optional `variants` metadata used for reasoning-effort controls
- `ChatEvent`: typed realtime event wrapper with session status and interactive request payloads

### Streaming Flow
- Uses SSE events (`/event`) for incremental message updates
- Uses `/global/event` for cross-context invalidation signals
- Send flow forwards active `directory` scope to `/event` and message fallback fetch
- `ChatRemoteDataSource.subscribeEvents()` maintains reconnect/backoff loop
- `ChatProvider` applies reducer transitions per event type
- Client merges event deltas with full message fetch when needed
- Send path records release-visible lifecycle logs (`info`/`warn`) for stream connect/fallback/poll completion diagnostics in `LogsPage`
- Send path includes watchdog polling fallback when stream is connected but no per-message events are emitted
- Provider startup guards cancel stale realtime subscriptions to avoid duplicate `/event` streams
- Subscription teardown uses bounded timeout to avoid server-switch deadlocks
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
│   │   ├── chat_provider_test.dart           # ChatProvider state + server/context-scoped cache behavior
│   │   ├── project_provider_test.dart        # ProjectProvider context/worktree orchestration
│   │   └── settings_provider_test.dart       # Experience settings persistence + shortcut conflict logic
│   ├── utils/
│   │   └── file_explorer_logic_test.dart     # Quick-open ranking and file-tab reducer behavior
│   └── usecases/
│       └── chat_usecases_test.dart           # ChatUseCases domain logic
├── widget/
│   ├── chat_page_test.dart                   # ChatPage responsive shell
│   ├── app_shell_page_test.dart              # Chat-first shell and sidebar Logs/Settings back-navigation flow
│   ├── chat_session_list_test.dart           # Session lifecycle menu actions (rename/share/archive/delete)
│   ├── interaction_cards_test.dart           # Permission/question UI action dispatch
│   ├── server_settings_page_test.dart        # Servers section rendering and unhealthy-switch guard through Settings route
│   └── settings_page_test.dart               # Modular Settings sections navigation and rendering
├── integration/
│   └── opencode_server_integration_test.dart # Mock server SSE/global-event flow + interaction/lifecycle/worktree endpoints + server-switch cache isolation
└── support/
    ├── fakes.dart                             # Fake implementations for testing
    └── mock_opencode_server.dart              # Shelf-based mock OpenCode API server
```

### Test Support Infrastructure

**mock_opencode_server.dart:**
- In-process `dart:io` HTTP server emulating OpenCode API
- Supports `/session`, `/session/{id}/message` endpoints
- Supports advanced lifecycle routes (`/session/status`, `/children`, `/todo`, `/diff`, `/fork`, `/share`, `PATCH /session/{id}`)
- Supports `/permission*` and `/question*` interaction endpoints
- Supports `/global/health` for server-health orchestration tests
- Supports `/global/event` and `/experimental/worktree*` routes for context/workspace parity tests
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

**Current coverage:** 65.11% in latest local CI-equivalent run (`7693/11816`), with 35% minimum enforced by CI

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

**Release documentation:**
- `RELEASE_NOTES.md` tracks parity-wave release signoff and known limitations.
- `QA.feat016.release-readiness.md` records executed QA matrix evidence.

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
| `QA.feat016.release-readiness.md` | Feature 016 QA matrix, platform smoke, and defect triage |
| `RELEASE_NOTES.md` | Release signoff checklist and known limitations |

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
- Automated APK builds with Telegram upload and dynamic caption defaults
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
- Replaced split provider/model controls with a single searchable model selector grouped by provider (bottom sheet), while keeping server-scoped selection persistence.
- Added selector UX refinements: provider groups are alphabetically ordered and up to 3 recent models are surfaced first on open; reasoning effort uses a separate anchored quick selector.
- Added typed model-variant parsing from `/provider` and variant-cycle UX for reasoning effort.
- Added `variant` serialization in outbound chat payloads for parity with OpenCode v2 prompt schema.
- Added server-scoped recent/frequent model usage tracking and restoration across launches.
- Expanded unit/widget/integration coverage for variant parsing, cycling, persistence, and payload assertions (40 tests passing).

**Feature 013 (completed):**
- Added resilient realtime reducer architecture for `session.*`, `message.*`, `permission.*`, `question.*`.
- Added interactive permission/question flows and message fallback fetch for partial event payloads.
- Hardened send-path diagnostics, directory-forwarding for stream/message fetch, and watchdog fallback for stalled event flows.

**Feature 014 (completed):**
- Added advanced session lifecycle operations (rename/archive/share/unshare/fork/delete) with optimistic updates + rollback.
- Added session insight hydration (`status`, `children`, `todo`, `diff`) and richer session list controls (search/filter/sort/load-more).

**Feature 015 (completed):**
- Added project/workspace context orchestration with deterministic `serverId::directory` snapshot isolation.
- Added worktree operations (`create/reset/delete/open`) and current-project switching via `/project` + `/experimental/worktree*`.
- Added explicit base-directory input when creating workspaces to avoid implicit folder targeting.
- Added dynamic directory picker and Git preflight validation to reduce create-workspace 400 errors on non-git paths.
- Added explicit git-only guidance in the picker and stronger auto-open behavior for newly created workspace contexts.
- Added explicit app-log telemetry for workspace lifecycle operations to improve production debugging from mobile.
- Added `/global/event` subscription for cross-context invalidation and resilient subscription teardown during server switches.
- Expanded tests for project/worktree/global-event/context isolation and raised total passing tests to 66.

**Feature 016 (completed):**
- Expanded parity regression coverage across unit/widget/integration suites (including server-scoped model restore and reject-question flows).
- Executed QA matrix `PAR-001..PAR-008` with artifacts in `/tmp/codewalk_feat016/20260210_022919`.
- Added release-readiness report (`QA.feat016.release-readiness.md`) and release notes (`RELEASE_NOTES.md`).
- Validated final release gates via `make precommit` and CI-equivalent local checks (coverage + Linux/Web builds), with logs in `/tmp/codewalk_feat016_gate/20260210_024416_precommit` and `/tmp/codewalk_feat016_gate/20260210_024255_ci`.
- Documented one reproducible host-environment limitation (Android emulator startup `-6`) with mitigation via build/artifact validation and APK upload path.
- Added post-release chat composer attachment flow (image/PDF), including model-capability-based button visibility and payload parity for `file` parts (`mime` + `url`).
- Refined post-release attachment UX so image/PDF options are filtered independently by model input modalities instead of relying only on generic attachment support.
- Added post-release voice input support with `speech_to_text`, including microphone button UX in the composer and Android manifest updates for speech recognition availability.
- Refined microphone UX feedback so the button switches to a red visual state while voice capture is actively listening.
- Added post-release secondary send-button behavior: hold for 300ms inserts newline and shows a corner indicator icon for this non-send action.
- Restored staged assistant progress feedback in chat list using provider realtime state (`ChatState.sending`, `session.status`, and in-progress `AssistantMessage` parts) to render `Thinking...`, `Receiving response...`, and `Retrying model request...` indicators until completion.
- Removed inline `Step started`/`Step finished` render blocks from assistant message body and exposed their details through the assistant header info menu (`Icons.info_outline`) to reduce visual noise.
- Enabled selectable message content for both assistant and user messages via a shared `SelectionArea`, removed inline `Copy` buttons, changed full-message copy to trigger only from double-tap/double-click on bubble background (text double-click keeps native word selection), and disabled in-app copy snackbar on Android in favor of native clipboard feedback.
- Updated top bar project-context selector visual hierarchy: removed rounded border container and moved the selector from right-side actions to the left-aligned app-bar title slot.
- Reworked project selector interaction into an adaptive dialog (`Dialog.fullscreen` on compact screens, centered `Dialog` on larger layouts) with top-level persistent actions and list-item close controls beside each project entry.

**Feature 021 (completed):**
- Added a shared session-title formatting contract (`SessionTitleFormatter`) to unify explicit title/fallback rendering across list and active-session surfaces.
- Replaced ambiguous relative-only fallback titles with relative + absolute date format (e.g. `Today HH:mm (M/D/YYYY)`), and reused the same strategy when creating new sessions.
- Added inline rename UX in active conversation headers (mobile + desktop) with keyboard support (`Enter` save, `Esc` cancel), touch-friendly edit controls, save/loading feedback, and inline validation/error state.
- Hardened rename synchronization in `ChatProvider`: no-op rename now succeeds without error noise, optimistic rename tracks pending local intent, stale/conflicting `session.updated` events are ignored while rename is pending, and rollback remains intact on API failure.
- Expanded tests with new unit/widget coverage for formatter behavior, inline editor interactions, header fallback rendering, inline rename flow, and pending-rename conflict handling in provider realtime events.
- Validation executed: targeted feature test matrix (`flutter test` on formatter/editor/provider/chat_page), full regression suite (`flutter test`), and static analysis (`flutter analyze --no-fatal-infos --no-fatal-warnings`).

**Feature 023 (completed):**
- Migrated deprecated Flutter color APIs across app UI (`withOpacity` -> `withValues`, `surfaceVariant` -> `surfaceContainerHighest`, `background` -> `surface`, `onBackground` -> `onSurface`).
- Migrated deprecated form-field initialization API in settings (`DropdownButtonFormField.value` -> `initialValue`).
- Fixed asynchronous `BuildContext` usage hotspots in `ChatPage` (`use_build_context_synchronously`).
- Reworked web notification bridge from deprecated `dart:html` to `package:web` + JS interop and removed window-focus compile error path.
- Replaced deprecated markdown package (`flutter_markdown`) with `flutter_markdown_plus`.
- Validation executed: `flutter analyze` (targeted issues removed), full tests (`make test`), and Android build/upload (`make android`).

**Backlog UX batch (completed):**
- Desktop composer shortcut behavior now sends on `Enter` and inserts newline on `Shift+Enter` without breaking mention/slash popover keyboard flows.
- On mobile, composer submit now uses keyboard `send` action and automatically hides keyboard focus after a successful send to maximize visible message area.
- Desktop sidebars (`Conversations`, `Files`, `Utility`) now support user-driven collapse/restore with persisted visibility via `ExperienceSettings.desktopPanes`.
- Composer input remains editable while assistant response is in progress; send stays blocked until completion.
- Send action now switches to `Stop` while response is active and triggers `/session/{id}/abort` through `AbortChatSession` use case wired into `ChatProvider`.
- Stop/abort now suppresses expected cancelation errors from realtime/session stream, preventing full-screen `Retry` fallback when the user intentionally interrupted the response.
- Post-stop send-path is now stable: provider keeps message list mutable after abort completion and ignores stale send-stream callbacks via generation guards, preventing transient `Failed to start message send` / `retry` fallback when sending immediately after `Stop`.
- Project context dialog now exposes archive action for closed project entries (local curation), independent of `worktree` APIs.
- `ProjectProvider` now persists archived closed-project IDs per server and filters them from the "Closed projects" section while keeping normal reopen/switch flows for active contexts.
- Expanded automated coverage for desktop shortcut send/newline behavior, persisted sidebar visibility toggles, stop/abort success path, and stop failure snackbar fallback.

**Tool diff rendering hardening (2026-02-13, commits b6f8d7f..082ea92):**
- `ToolState` parsing now normalizes non-string `output` payloads (map/list/scalar) into displayable text and extracts common diff keys (`diff`, `patch`, `unified_diff`).
- Tool output UI now falls back to structured tool `input` when `output` is empty, including direct `patch/diff` extraction for `apply_patch`.
- `edit` tool calls with `old_string`/`new_string` now generate a synthetic unified diff when upstream does not return textual output.
- Added regression coverage for parser normalization and input-fallback diff rendering in widget/unit tests.
- Fixed missing `color` field in Agent entity and model (commit 63d6155).
- Added colorized diff rendering in tool outputs with accessible text scaling (commit 52c6e8b).
- Consolidated feature roadmaps and improved diff text scaling accessibility (commit 082ea92).
