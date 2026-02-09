# CodeWalk - Codebase Baseline Snapshot

> Captured: 2026-02-09
> Git baseline: `7151d8d1e44545769fb3defa9a816448b5f4b40a` (main)
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
│   └── widget_test.dart # Single widget test
├── web/               # Web platform
│   ├── index.html
│   └── manifest.json
├── pubspec.yaml
├── analysis_options.yaml
└── Makefile
```

## File Counts

| Type | Count | Notes |
|------|-------|-------|
| `.dart` (source) | 53 | Under `lib/` and `test/` |
| `.g.dart` (generated) | 5 | JSON serialization models |
| `.dart` (total) | 58 | All Dart files |
| `.md` (markdown) | 15 | Docs + roadmap files |

## Legacy Naming References

All runtime/build/config references to `open_mode`/`OpenMode` were renamed to `codewalk`/`CodeWalk` in Feature 003. Remaining references exist only in historical documentation files (NOTICE, ADR.md, ROADMAP files, AI_CHAT_IMPLEMENTATION.md) as intentional attribution to the original project.

## API Endpoints

Extracted from `lib/data/datasources/*.dart`. Server base URL is configurable.

### AppRemoteDataSource (`app_remote_datasource.dart`)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/path` | Fetch path info |
| GET | `/config` | Fetch config info |
| POST | `/app/init` | Initialize application |
| GET | `/provider` | Get provider information |

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
| GET | `/session/{sessionId}/message` | List messages |
| GET | `/session/{sessionId}/message/{messageId}` | Get specific message |
| POST | `/session/{sessionId}/message` | Send message (streaming) |
| GET | `/event` | SSE event stream |
| POST | `/session/{sessionId}/abort` | Abort session |
| POST | `/session/{sessionId}/revert` | Revert message |
| POST | `/session/{sessionId}/unrevert` | Unrevert messages |
| POST | `/session/{sessionId}/init` | Initialize session |
| POST | `/session/{sessionId}/summarize` | Summarize session |

### ProjectRemoteDataSource (`project_remote_datasource.dart`)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/project` | List all projects |
| GET | `/project/current` | Get current project |

**Total: 21 endpoints**

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
| Windows | Absent | No `windows/` directory |
| macOS | Absent | No `macos/` directory |
| Linux | Absent | No `linux/` directory |

## Quality Baseline

### flutter analyze

- **Total issues: 167**
  - Errors: 0
  - Warnings: 3 (unused local variable, unused generated declarations)
  - Info: 164 (deprecated API usage, avoid_print, use_super_parameters)
- **Top issue categories:**
  - `deprecated_member_use` (~95): `withOpacity`, `background`, `surfaceVariant`, `onBackground`
  - `avoid_print` (~30): print statements in production code
  - `use_super_parameters` (~8): constructor parameters that could use super
  - `overridden_fields` (~5): field overrides in model classes

### flutter test

- **Result: 1 test, all passed**
- Single widget test: `ChatInputWidget renders and sends message`

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
