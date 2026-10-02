# CodeWalk v1 — Inventory for the v2 / multi-harness rewrite

> Snapshot of **CodeWalk 1.265.0** (`pubspec.yaml:19`, HEAD `14fbf519`, 2026-10-02): a Flutter client for **OpenCode v1.x** server mode.
> Companion: `plan/01-codewalk-v1-opencode-contract.md`, which lists every endpoint, event, payload and model.
> Sources: `lib/` (code is authoritative), `CODEBASE.md`, `BEHAVIOR.md`, `ADR.md`, `CONTRACT_MATRIX.md`, `README.md`, `Makefile`, `pubspec.yaml`/`pubspec.lock`, `install.sh`/`install.ps1`, `ai-docs/`.
> Path aliases:
> - `P/` = `lib/presentation/`
> - `PC/` = `lib/presentation/pages/chat_page/`
> - `CP/` = `lib/presentation/providers/chat_provider/`
> - `CI/` = `lib/presentation/widgets/chat_input/`
> - `CM/` = `lib/presentation/widgets/chat_message/`
> - `D/` = `lib/data/`
> - `DM/` = `lib/domain/`
> - `C/` = `lib/core/`
>
> **(inferred)** marks conclusions that neither the code nor the docs state directly.

---

## 0. Executive summary

- **Size.** About 158 k hand-written Dart LOC in 448 files, plus 107 k generated l10n LOC, plus about 34 k LOC of vendored packages (`xterm`, `tailscale` with Go). The presentation layer is **83 %** of the code. 204 test files, 113 k test LOC, about 2 460 test cases.
- **Two god objects hold most of the behavior:**
  - `ChatProvider`: ~22.8 k LOC across `P/providers/chat_provider.dart` and 26 `part`/extension files.
  - `ChatPage`: ~27.5 k LOC across `P/pages/chat_page.dart` and 29 parts.
  - Each is one Dart class split with `part of` + private extensions, so all state is shared, mutable and private.
- **OpenCode leaks everywhere.** Domain entities mirror the v1 wire schema one to one: 12 part types, `ToolState`, `SessionRevert`, `idle|busy|retry`.
  - Realtime events reach the presentation layer as raw `ChatEvent{type, properties: Map}`. The reducers in `CP/` parse raw OpenCode JSON with data-layer models (`ChatSessionModel.fromJson`, `MessagePartModel.fromJson`, …).
  - The UI switches on OpenCode tool names (`bash`, `read`, `edit`, `apply_patch`, `task`, `todowrite`, … in `P/utils/tool_presentation.dart:96-311`).
  - 26 presentation files talk to `Dio` directly.
- **A large share of the realtime and chat code exists to work around v1 gaps.** No SSE replay, `prompt_async` returns no message id, events lack full state, no pagination cursors, no file-write API, no titles API, no usage API, no push. See §3. With a server that offers sequenced/replayable events, ids returned on send, cursors and typed errors, most of the 17 k LOC in `CP/` can be deleted (inferred).
- **Managed install** exists only on desktop (Linux/macOS/Windows). It runs `opencode serve --hostname 127.0.0.1 --port 4096` and installs via npm, bun, the bun bootstrap, or a GitHub binary from `anomalyco/opencode`. Android is always "remote server only" (plain URL, Basic auth, Cloudflare Access OAuth, or embedded Tailscale).
- **Not in v1:**
  - skills
  - MCP status, LSP/diagnostics, formatter status
  - provider login/OAuth (`/provider/auth`)
  - worktree UI (data layer only)
  - URI deep links
  - iOS build (no `ios/` folder, even though the docs describe iOS paths)
  - a message queue (deliberately removed; follow-ups are sent directly)
- **Permission auto-approve is ON by default** (`DM/entities/experience_settings.dart:910`). It replies `always` + `remember:true` to every permission in the current thread, child sessions included. This is ADR-023 exception EXC-001. Questions are never auto-answered.

---

## 1. Architecture overview

### 1.1 Targets

| Target | Status | Notes |
|---|---|---|
| Android | shipped (signed arm64 APK via CI; `make android`) | foreground services, WorkManager, overlay, Android Auto |
| Linux / Windows / macOS | shipped (tar.gz / zip). Releases ship `linux-x64`, `macos-arm64`, `windows-x64` only (per `release.yml`) | tray, window chrome, managed local OpenCode, desktop self-update. The macOS release is sandboxed (`macos/Runner/Release.entitlements`), which probably breaks managed install and script updates (inferred) |
| Web | shipped at `codewalk.verseles.com` (`web-pages.yml`) | needs `opencode serve --cors <origin>` (README). SSE uses Dio's browser adapter (`C/network/dio_sse_adapter_stub.dart`). No PTY, no API STT |
| iOS | **not built** (no `ios/` dir) | iOS branches exist in Dart (session attention in-app host, etc.) |

### 1.2 Layers (clean-architecture style, leaky in practice)

```
lib/main.dart (413)            bootstrap: zone guard, logger, window_manager, Workmanager registration, DI, MultiProvider
lib/core/        32 files  5.5k  DI, network (Dio + SSE Dio), auth (OAuth/secure storage), tailscale, logging, i18n, constants, feature flags
lib/data/        44 files 14.7k  datasources (remote/local), models (hand-written + 3 json_serializable .g.dart), repositories, file caches
lib/domain/      53 files  6.7k  entities, 3 repository interfaces, 31 thin use cases (1 class per repository method)
lib/presentation 317 files 130.5k  pages (41.2k), providers (31.1k), services (25.9k), widgets (24.4k), utils (3.5k), theme (4.4k)
```

- **Use cases are pass-through.** Example: `DM/usecases/send_chat_message.dart` (38 LOC) just calls the repository. The repository maps `Exception` to `Failure` and returns `Either` (`dartz`).
- **Repository interfaces** (the most natural adapter seam):
  - `DM/repositories/chat_repository.dart`: 25 methods
  - `DM/repositories/app_repository.dart`: 6 methods
  - `DM/repositories/project_repository.dart`: 14 methods
- **Large parts of the feature set bypass the domain layer.** They use `DioClient` or `Dio` directly from presentation (§5.2):
  - terminal, quota, file mutations, titles, slash commands, config/settings, background workers, overlay, car messaging, project icons

### 1.3 State management

- `provider` 6.1.5 with `ChangeNotifier`. Eight root providers are wired in `lib/main.dart:141-168`: `AppProvider`, `ProjectProvider`, `ProjectIconProvider`, `ChatProvider`, `QuotaProvider`, `DesktopWindowChromeController`, `SettingsProvider`, `LocaleProvider`.
- `ChatProvider`, the central hub, is spread over these files:
  - `P/providers/chat_provider.dart` (5 867 LOC)
  - `P/providers/chat_provider_types_part.dart`, `P/providers/chat_provider_draft_part.dart`
  - 27 files in `CP/`: event reducers (global/session/helpers), message merge/state, realtime/realtime_aux, lifecycle, history, session tabs (2 366), session attention, selection helpers/sync, cache persistence, auto-title, abort and error policy, shortcut cycle, target, context state, reconciliation (`message_reconciliation.dart`, `message_timeline_order.dart`, `chat_provider_reconciliation_guard.dart`).
- `ChatProvider` implementation notes:
  - Notifications are coalesced by microtask (`P/providers/chat_provider.dart:773-844`). Realtime updates are batched at 16 ms on mobile/web and 120 ms on desktop (`:752-936`).
  - UI rebuilds are gated while the app is in the background (`:768-791`).
  - Many generation counters cancel stale async work.
- Other god objects:
  - `AppProvider`: `P/providers/app_provider.dart`, 2 663 LOC. Holds server profiles, health checks, OAuth, Tailscale, managed local server, setup debug.
  - `SettingsProvider`: `P/providers/settings_provider*.dart`, 3 483 LOC.
  - `ProjectProvider`: 1 547 LOC.
- `DirectProvider`/`DirectSelector` (`P/widgets/direct_provider.dart`) provides scoped subscriptions.

### 1.4 Dependency injection

- `get_it` 9.2.1. Registration lives in `C/di/injection_container.dart` (677 LOC):
  - `DioClient`
  - 7 datasources/services: App/Chat/Project/Quota/Terminal remote, AppLocal, `WorkspaceFileOperationsService`
  - 3 repositories and 31 use cases
  - providers registered as factories
  - TTS backends, STT engines, model managers, `TailscaleService`, `ChatTitleGenerator` (`OpenCodeTitleGenerator`), update and release services
- The service locator is also called from widgets: 56 `sl<…>` references in 15 presentation files. Example: `PC/chat_page_command_query.dart:104` reads `di.sl<DioClient>().dio` directly.

### 1.5 Routing / navigation

- `MaterialApp(home: AppShellPage)` (`lib/main.dart:276-328`).
- Navigation is imperative: `Navigator.push`/`pop` with `P/utils/app_page_route.dart`, about 113 `Navigator.of` / `Navigator.push` / `AppPageRoute(` references. There are no named routes, no router package, and **no URI deep links**: the Android manifest has only MAIN/LAUNCHER, `singleTop`.
- `AppShellPage` (`P/pages/app_shell_page.dart`) shows the onboarding wizard first when no server exists, then `ChatPage`.
- Notification taps carry a JSON payload `{category, action, sessionId, serverId, directory, …}` (`P/services/notification_service.dart:23-80`). On tap, `chat_page.dart:1851-2040` switches server, then directory, then session.

### 1.6 Persistence and cache

| Store | What | Where |
|---|---|---|
| `shared_preferences` (guarded) | settings, profiles metadata, selection blob, pins, tabs, drafts index; rejects values > 2 MB and skips no-op writes | `D/datasources/app_local_datasource.dart` (2 266), `app_local_datasource_storage_helpers.dart`; ADR-016 |
| File-backed payload store | large payloads: session message snapshots, provider catalog (~4.7 MB × scopes), drafts, canned answers | `D/cache/chat_cache_payload_store_io.dart`; limits per ADR-016: 2 MB payload, 512 K per entry |
| `flutter_secure_storage` | Basic-auth passwords, OAuth tokens (`C/auth/oauth_token_storage.dart`), TTS/STT API keys | ADR-001/033/046/053 |
| Encrypted snapshots (AES-GCM, `cryptography`) | session-attention completion previews; Android Auto queue | `D/session_attention/*`, `D/car_messaging/*` |
| In-memory SWR | LRU of 20 sessions' messages; 8 retained context snapshots; persisted message snapshots (8, 7-day TTL); session list cache 3-day TTL | `P/providers/chat_provider.dart:691-717`; ADR-020 |

- **Scoping key** everywhere: `serverId::directory` (ADR-002). Background, overlay and car features use the triple `(serverId, directory, rootSessionId)`.
- **Native pre-engine cleanup**: `android/.../CodeWalkApplication.kt` purges oversized prefs before Flutter starts. Its key list must stay in sync with the Dart list.

### 1.7 Localization

- `flutter gen-l10n`; config in `l10n.yaml`.
- 14 ARB locales: en, pt, es, de, fr, it, ru, zh, ja, ko, hi, bn, ar, ur (RTL for ar and ur). `app_en.arb` has 1 935 keys. Generated output is `lib/l10n/generated/` (15 files, 107 k LOC).
- `C/i18n/l10n_bridge.dart` gives context-free strings to background isolates, the tray and the data layer.
- Content from the server is never translated (BEHAVIOR §i18n).

### 1.8 Native and platform code

- **Android Kotlin** (1 572 LOC):
  - `MainActivity.kt` (590): method channels, OAuth/Tailscale Custom Tabs, clipboard, process diagnostics.
  - `CodeWalkForegroundService.kt` (109): `dataSync` FGS.
  - `overlay/SessionOverlayService.kt` (720): `specialUse` FGS, `TYPE_APPLICATION_OVERLAY`, runs its own FlutterEngine with Dart entry `sessionOverlayAndroidMain`.
  - `CodeWalkApplication.kt` (153): prefs purge.
- **Android permissions:** ACCESS_NETWORK_STATE, FOREGROUND_SERVICE(+DATA_SYNC, +SPECIAL_USE), INTERNET, POST_NOTIFICATIONS, RECORD_AUDIO, REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, REQUEST_INSTALL_PACKAGES, SYSTEM_ALERT_WINDOW, WAKE_LOCK.
- **Channels:**
  - `codewalk/system` (6 uses: FGS control, battery, …)
  - `codewalk/session_overlay_host`
  - `codewalk/composer_clipboard`
  - `codewalk/windows_microphone_stream` (EventChannel)
  - a Windows probe channel
- **Windows:** `windows/runner/windows_microphone_plugin.cpp` (588 LOC), a WASAPI capture used for STT (ADR-044).
- **Vendored packages:**
  - `third_party/xterm`: 19.1 k Dart; terminal rendering, with AltGr fixes.
  - `third_party/tailscale`: 15.4 k Dart + 5.7 k Go; userspace tailnet node with a native build hook.
- **Extra Dart entrypoints** (`@pragma('vm:entry-point')`):
  - WorkManager dispatcher `codewalkBackgroundAlertDispatcher` (`P/services/android_background_alert_worker.dart:37-46`)
  - overlay engine `sessionOverlayAndroidMain` (`P/services/session_attention/session_overlay_entrypoint.dart`)
  - car-messaging reply worker

### 1.9 Notable packages (constraint → resolved, from `pubspec.yaml` / `pubspec.lock`)

| Package | Version | Used for |
|---|---|---|
| dio | ^5.9.2 → 5.11.0 | all HTTP + SSE (streamed `ResponseBody`); two instances (regular + SSE) |
| http | ^1.4.0 → 1.6.0 | Tailscale `http.Client` bridge only (`C/tailscale/tailscale_http_adapter.dart`) |
| web_socket_channel | ^3.0.3 | PTY socket on web/IO; a hand-rolled RFC6455 client is used over Tailscale TCP |
| provider | ^6.1.1 → 6.1.5+1 | state management |
| get_it | ^9.2.1 | DI / service locator |
| dartz | ^0.10.1 | `Either<Failure,T>` in repositories and use cases |
| equatable | ^2.0.5 → 2.1.0 | value equality on entities (used by the reconciliation diffing) |
| json_annotation / json_serializable / build_runner | 4.12 / ^6.14 / ^2.15 | only 3 generated models; most parsing is hand-written |
| shared_preferences / flutter_secure_storage | 2.5.5 / 10.3.1 | persistence / secrets |
| connectivity_plus | 6.1.5 | cellular detection for Data Saver |
| flutter_markdown_plus, markdown | 1.0.12, 7.3.1 | message rendering (custom syntaxes for math, HTML subset, file paths) |
| flutter_math_fork | 0.7.4 | LaTeX (ADR-032) |
| flutter_mermaid | 0.1.0 | Mermaid diagrams |
| flutter_highlight / highlight / re_editor / re_highlight | 0.7.0 / 0.7.0 / 0.10.0 / 0.0.3 | code highlighting, file editor |
| xterm (vendored) | 4.0.0 | terminal view |
| tailscale (vendored) | 0.3.1 | embedded tailnet (ADR-036) |
| workmanager | 0.10.9 | Android background polling |
| flutter_local_notifications | 22.3.0 | notifications, Android Auto `MessagingStyle` |
| speech_to_text, sherpa_onnx, record | 7.3.0 (pinned), 1.13.7, 7.1.1 | STT (native + on-device Sherpa/Moonshine/Parakeet/SenseVoice/Nemotron) |
| flutter_tts, audioplayers | 4.2.5, 6.8.1 | TTS / sounds |
| tray_manager, window_manager | 0.5.3, 0.5.2 | desktop tray / window chrome |
| file_picker, cross_file, desktop_drop, pasteboard | 12.2.0, 0.3.5+5, 0.8.4, 0.5.0 | attachments (picker, drag-drop, paste) |
| share_plus, open_filex, url_launcher, path_provider, package_info_plus | 13.2.1, 4.7.0, 6.3.2, 2.1.6, 10.2.1 | share/export, APK install, links, dirs, version |
| dynamic_color, material_ui, material_symbols_icons, simple_icons (git), flutter_svg, image | 2.1.0, 1.1.1, 4.2960.0, 16.23.0, 2.3.0, 4.9.2 | Material You, icons, project icons |
| showcaseview | 5.1.0 | chat tour |
| crypto, cryptography | 3.0.7, 2.9.0 | sha256 ids; AES-GCM snapshots |
| archive | 4.2.0 | STT model archives |

---

## 2. Feature inventory

The "OpenCode dependency" column gives v1 endpoints and events; the full list is in file 01. "Client-only" means no server involvement.

### 2.1 Connection, servers and auth

| Feature | Behavior | Key files | OpenCode dependency | Notes / v1 hacks |
|---|---|---|---|---|
| Server profiles (multi-server) | Add/edit/delete; active and default; one searchable list with OAuth/Tailscale badges | `P/providers/app_provider.dart`, `P/pages/settings/sections/servers_settings_section.dart`, `DM/entities/server_profile.dart` | none | Fields: `url`, Basic user/pass, `oauthEnabled`, `tailscaleEnabled`, `aiGeneratedTitlesEnabled` (ADR-001). Data scoped by `serverId::directory`. A profile is "an OpenCode base URL"; there is no harness type |
| Health checks | Online / Delayed / Offline; unhealthy warning after a grace period | `app_provider.dart:2188-2305, 2493-2530` | `GET /global/health`, falling back to `GET /path` | Polls every 10 s (data saver: 30 s / 1 min). `version` is not read |
| Basic auth | `Authorization: Basic`, bound to the exact origin | `C/network/dio_client.dart:101-121, 326-346` | the server password (e.g. `OPENCODE_SERVER_PASSWORD`) | — |
| Cloudflare Access OAuth | PKCE + DCR, loopback callback on `127.0.0.1`; system browser on desktop, Custom Tab on Android | `C/auth/oauth_service_io.dart` (1 224), `oauth_token_storage.dart` | reverse proxy, not OpenCode | ADR-033 (ADR-023 exception). No web or iOS. No background alerts for OAuth profiles |
| Tailscale transport | In-process tailnet node; Dio adapter; peer picker; login URL | `C/tailscale/*`, `third_party/tailscale` | none | ADR-036. Not on Windows or web. No background or car features over Tailscale |
| Cellular Data Saver | Off / Standard / Aggressive; throttles sync; Aggressive drops `/global/event` and pauses idle SSE | `P/services/cellular_data_saver_service.dart` | changes SSE usage | Default on (`FeatureFlags.cellularDataSaver`) |
| Sticky routing | Echoes the `X-Session-Id` response header | `dio_client.dart:52, 348-358` | (inferred: proxy/cloud stickiness) | Undocumented |

### 2.2 Onboarding and managed OpenCode install (desktop)

| Feature | Behavior | Key files | OpenCode dependency | Notes |
|---|---|---|---|---|
| Setup wizard | Step 0 chooser ("Let CodeWalk set it up" / "Connect running server" / "Show setup steps") → 1 server form + Test → 2 Ready / Connection issue (continue degraded, retry, settings, debug) → 3 local setup | `P/pages/onboarding_wizard_page.dart` (2 451), `P/pages/app_shell_page.dart:322-345` | health probe only | ADR-011 says 3 steps; the code has 4. On Android, `localhost` is rewritten to `10.0.2.2` (`onboarding_wizard_page.dart:762-781`). Shows a copyable `opencode serve --hostname 0.0.0.0 --port 4096`, optionally prefixed with `OPENCODE_SERVER_PASSWORD=…` (`servers_settings_section.dart:914-957`) |
| Chat tour | Two-phase showcase after the first successful setup; replayable | `P/widgets/chat_tour_showcase.dart` | none | — |
| **Managed local OpenCode** | Diagnose / install / start / stop a local server; creates the profile "Local OpenCode (Managed)" at `http://127.0.0.1:4096` | `P/services/local_opencode_server_runtime_io.dart` (1 280; interface `_types.dart:1-30`; stub for web/mobile), `app_provider.dart:1500-2058` | spawns the `opencode` CLI | **Desktop only** (`isSupported` is false on web/Android/iOS, runtime `:75-85`). Details below |
| Setup debug page | Environment table (opencode/node/npm/bun/WSL/network/writable), setup timeline, captured logs, sanitized export | `P/pages/opencode_setup_debug_page.dart` | doc hints for `GET /global/health`, `GET /doc`, `~/.local/share/opencode/log/` | Read-only |

**Managed install, exact mechanics** (runtime file = `local_opencode_server_runtime_io.dart`)

- **Detection** (`:175-261, 611-705`):
  - Runs `<configured path> --version`, then `which`/`where opencode`.
  - Then checks known paths: `~/.codewalk/local-opencode/bin/opencode{,.cmd,.exe}`, `~/.bun/bin/opencode*`, and `%APPDATA%\npm\opencode*` on Windows.
  - Probes `node`, `npm`, `bun`, and `wsl` (Windows).
  - Network probe: `GET https://api.github.com`, 4 s timeout (`:814-828`).
  - Write probe: `~/.codewalk/local-opencode/.write_probe`.
  - Runs at **every desktop app start** (`app_provider.dart:316`).
  - The detected path is stored in prefs key `local_opencode_command`.
- **Install methods:**
  - `npm install -g opencode-ai` (`:324-370`).
  - `bun install -g opencode-ai` (`:372-422`).
  - Bun bootstrap, then the bun install (`:424-467`):
    - Unix: `bash -lc 'curl -fsSL https://bun.sh/install | bash'`
    - Windows: `powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "irm bun.sh/install.ps1 | iex"`
  - Binary download (`:469-609`):
    1. `GET https://api.github.com/repos/anomalyco/opencode/releases/latest` (`:61-62`).
    2. Pick the asset `opencode-{linux,darwin,windows}-{x64,arm64}[-baseline][-musl].{tar.gz,zip}` by `Abi.current()`.
    3. Optional SHA-256 check, only if GitHub exposes a `digest`.
    4. Extract (`tar`/`unzip`/`Expand-Archive`) to `~/.codewalk/local-opencode/<ver>/`.
    5. Copy to `~/.codewalk/local-opencode/bin/`.
  - No update or version check (reinstall overwrites), no cleanup of old versions, not added to PATH.
- **Start** (`:100-172`): `Process.start(<opencode>, ['serve','--hostname','127.0.0.1','--port','4096'])`.
  - No password, `--cors`, working directory or env.
  - `runInShell` only for `.cmd`/`.bat`.
  - Health is polled every 400 ms for up to 12 s.
  - **No port-conflict check**: a foreign server on 4096 passes the health check (inferred race).
- **Stop:** SIGTERM, wait 3 s, then SIGKILL. No restart method.
  - Stopped only from `AppProvider.dispose()`, so the server is likely orphaned on quit (inferred).
  - Killing a Windows `.cmd` shim may leave the server running (inferred).
- **Logs:** only the last stdout/stderr line is kept (sanitized); install log is capped at 120 lines; no log file.
- **`install.sh` / `install.ps1` / `uninstall.*` install CodeWalk itself, not OpenCode.**
  - Source: `GET https://api.github.com/repos/verseles/codewalk/releases/latest`, assets `codewalk-{linux,macos}-{x64,arm64}.tar.gz` / `codewalk-windows-{x64,arm64}.zip`.
  - Installs to `$XDG_DATA_HOME/codewalk-app` + `~/.local/bin/codewalk` + `.desktop`; `~/Applications/CodeWalk.app` on macOS; `%LOCALAPPDATA%\CodeWalk` + PATH + Start Menu on Windows.
  - `install.ps1` has stage/apply modes used by self-update.
  - Entry point: `install.cat/verseles/codewalk`.

### 2.3 Projects and context

| Feature | Behavior | Key files | OpenCode dependency | Notes |
|---|---|---|---|---|
| Project/folder picker | One dialog: open, closed, server-searched folders; directory browser; manual path; Windows drives/UNC | `PC/chat_page_selector_flow.dart`, `P/providers/project_provider.dart`, `P/utils/project_directory_search.dart` | `/project`, `/project/current`, `/file?path=.`, `/vcs` | Scope transitions are serialized (ADR-002) |
| Cache-first project switch | Instant render from snapshot, revalidate in background | `PC/chat_page_workspace_controller.dart`, `CP/chat_provider_cache_persistence_ops.dart` | `/session`, SSE resubscribe | ADR-020/021/022 |
| Project icons / tab colors | Icon/favicon auto-discovery from the repo; palette tint | `P/providers/project_icon_provider.dart`, `P/services/project_icon_discovery_service_io.dart` (896) | `/file`, `/find/file`, `/file/content` | ADR-040, client-owned |
| Worktrees | **No UI** | `P/providers/project_provider.dart:477-600`, `D/datasources/project_remote_datasource.dart:111-176` | `/experimental/worktree` (GET/POST/DELETE, `/reset`) | Dormant |

### 2.4 Sessions

| Feature | Behavior | Key files | OpenCode dependency | Notes |
|---|---|---|---|---|
| List, grouping, filter, sort, search | Grouped by project, children nested; Active/Archived/All; recent/oldest/title; compact search | `P/widgets/chat_session_list.dart`, `PC/chat_page_scaffold.dart` | `GET /session?directory` (**unbounded**), `/session/status`, `session.*` events | Pseudo summaries that only contain diff stats are hidden |
| Create (lazy), rename, delete, archive | Draft "New chat" creates the session on first send; inline rename; archiving a root hides its children | `CP/chat_provider_session_ops.dart`, `P/widgets/session_title_inline_editor.dart`, `P/widgets/session_context_menu.dart` (1 255) | `POST/PATCH/DELETE /session[/:id]`; archive = `PATCH {time:{archived}}` | Pending-rename guard against stale `session.updated` |
| Fork / share / unshare | Menu actions; copy share link | `DM/usecases/fork_chat_session.dart`, `share_…`, `unshare_…` | `/session/:id/fork`, `/share` | — |
| Compact | `/compact`, menu, "Compact now" in the context popover | `DM/usecases/summarize_chat_session.dart`, `PC/chat_page_status_presenter.dart` | `POST /session/:id/summarize {providerID, modelID}` | — |
| Pins, recent sessions, unread highlight | Pins per server+project; 5 recent roots; 1 h unread highlight | `CP/chat_provider_target_ops.dart`, `CP/chat_provider_session_attention_ops.dart` | `session.idle` / status | Read state is local only |
| Session tabs and Ctrl+Tab switcher | Browser-like tabs (3 h window, pinned region, project groups, icons, undo close); hold-to-cycle MRU overlay | `P/widgets/app_tab_strip.dart` (1 118), `P/widgets/session_tab_strip.dart`, `CP/chat_provider_session_tab_ops.dart` (2 366), `PC/chat_page_session_tabs.dart`, `PC/chat_page_tab_switcher.dart` | none (persisted per server) | Large client-side subsystem |
| Auto titles | Re-titles progressively until 3+3 messages; ≤6 words; per-profile toggle | `P/services/chat_title_generator.dart`, `CP/chat_provider_auto_title_ops.dart` | **hidden session** `_title_gen` + `POST /session/:id/message {agent:"title"}` → wait for `session.idle` (15 s) → GET → DELETE → `PATCH` title | ADR-009. Hidden-session filtering is needed in 4+ places |
| Cache-first reopen (SWR) + bounded history | Instant render; newest 50 (+1 sentinel) first; older pages at top; resident cap 500 | `CP/chat_provider_history_ops.dart`, `CP/chat_provider_lifecycle_ops.dart`, `P/providers/chat_provider.dart:4613-4700` | `GET /session/:id/message?limit=N` | **No cursor**: older pages re-fetch `resident+51` |
| Session details: todos and review changes | Todo panel; diff viewer (summary / unified / split) | `P/widgets/session_todo_list_widget.dart`, `P/widgets/session_diff_viewer.dart` (1 324), `P/utils/diff_parser.dart` | `/session/:id/todo`, `/session/:id/diff[?messageID]`, `todo.updated`, `session.diff` | The unscoped diff returns `[]`, so up to 25 calls are made, one per user turn (`chat_provider.dart:737-740, 2270-2302`) |
| Session export | Markdown / JSON | `P/services/session_export_service.dart` | messages | `local_user_*` ids are dropped |

### 2.5 Chat timeline and streaming

| Feature | Behavior | Key files | OpenCode dependency | Notes |
|---|---|---|---|---|
| Send | Optimistic `local_user_<µs>_<seq>` bubble; text + attachments | `P/providers/chat_provider.dart:4761-5303`, `D/datasources/chat_remote_datasource.dart:851-1785` | `POST /session/:id/prompt_async` (no `messageID`, client `prt_*` part ids) | ADR-023 P-001 invariant. Echo matched by content (`CP/chat_provider_message_merge_ops.dart`) |
| Streaming render | Live (default) or Block mode | `PC/chat_page_timeline_builder.dart` (1 352), `PC/chat_page_timeline_entries.dart`, `PC/chat_page_timeline_runtime.dart`, `DM/entities/experience_settings.dart` (`ChatRenderMode`) | `message.part.delta` / `message.part.updated` + HTTP re-fetches | Batch 16 ms mobile / 120 ms desktop |
| Part rendering | text (markdown), reasoning ("thinking" toggle), tool (per-tool card), file, patch, agent, subtask, snapshot, retry, compaction; step-start and step-finish hidden; todo tool hidden | `CM/chat_message_part_dispatch.dart`, `CM/chat_message_tool_part.dart` (1 067), `CM/chat_message_text_part.dart`, `CM/chat_message_file_part.dart`, `CM/chat_message_info_parts.dart`, `P/utils/tool_presentation.dart` | v1 Part schema; tool names `bash`, `read`, `write`, `edit`, `apply_patch`, `patch`, `glob`, `grep`, `webfetch`, `question`, `todowrite`, `todoread`, `task` | Unknown part types become `text` (`D/models/chat_message_model.dart:698`) |
| Tool work groups | Raw while streaming; collapse into a summary card after settle; details dialog | `PC/chat_page_timeline_runtime.dart`, ADR-025 | `session.idle` | Many viewport invariants |
| In-progress message handling | Busy indicator, composer status slot ("latest tool/reasoning"), elapsed chip, final-answer reveal | `PC/chat_page_composer_status.dart`, `P/utils/reasoning_status_parser.dart`, `P/utils/chat_assistant_settlement.dart`, `CP/chat_provider_session_attention_ops.dart:404-470` | `time.completed` absent; `session.status` | Heuristic "busy" (file 01 §6) |
| Follow-up while busy | Send immediately through the same path; no local queue, no "Send now", no auto-abort | `CI/chat_input_send_controller.dart`, BEHAVIOR "Sending while processing…" | `prompt_async` (server queues) | The old queue was intentionally removed (ADR-003/005) |
| Empty-send "continue" | Double-tap an empty Send to send `continue` | `P/widgets/chat_input_widget.dart` | `prompt_async` | — |
| Stop / abort | Stop button; partial output kept | `P/providers/chat_provider.dart:5305-5400`, `CP/chat_provider_abort_policy_ops.dart`, `P/utils/chat_abort_message.dart` | `POST /session/:id/abort` | Abort-like `session.error` suppressed for 8 s. Matches the server text "What you want to do different?". Adds a synthetic `msg_inline_abort_*` |
| Undo / redo / rewind-and-edit | Toolbar, `/undo`, `/redo`, inline "Undo this turn" / "Rewind and edit from here"; restores the prompt to the composer; replacement branch | `CP/chat_provider_history_ops.dart`, `CP/chat_provider_session_ops.dart` | `POST /session/:id/revert {messageID}`, `/unrevert`; `session.revert` field; `session.next.revert.*` | ADR-031. Never on `local_user_*` |
| Errors and retry | Inline server error, retry parts and status; scoped recovery card; only blocking errors surface | `P/utils/chat_server_error_formatter.dart`, `CP/chat_provider_error_policy.dart`, `CM/chat_message_info_parts.dart` | `session.error`, `retry` status (`attempt`, `next`), `RetryPart` | Synthetic `msg_inline_server_error_*`. String/status classification |
| Subagents (task tool) | Tap a task/subtask bubble to open the child session (full composer, "Return to parent", model chips locked); only synchronous display | `PC/chat_page_timeline_builder.dart:1085-1352`, `PC/chat_page_runtime_support.dart:466-570`, `DM/usecases/get_session_children.dart` | `/session/:id/children`, `parentID`, task tool `metadata.sessionId`, `<task id="…">` in output | **Heuristic resolver**: metadata keys → `<task id>` regex → single candidate → Nth task ↔ Nth child only when the counts match |
| Context / tokens / cost | Ring + popover: % of `model.limit.context`, tokens, cost; per-message info dialog | `PC/chat_page_status_presenter.dart:136-230`, `CM/chat_message_content.dart:756-811` | assistant `tokens`, `cost`; `StepFinishPart`; `/provider` limits | Client-side math. Cost sums **resident** messages only. Two different "total tokens" definitions |
| Markdown, LaTeX, Mermaid, HTML subset, code | Highlighted code with OpenCode theme presets; tables; file paths open the viewer | `CM/chat_message_text_part.dart`, `P/utils/math_markdown.dart`, `P/utils/basic_html_markdown.dart`, `P/widgets/mermaid_diagram_widget.dart`, `P/theme/opencode_web_theme_registry.dart` (2 657) | none | ADR-032 |
| Timeline search | App-bar search over loaded messages | `PC/chat_page_search.dart`, `C/utils/timeline_search_service.dart` | none | Loaded messages only |
| Message actions | Copy, share as PNG, forward to sessions (undo/retry), read aloud | `P/services/message_image_export_service.dart`, `P/services/forward_message_service.dart`, `P/widgets/forward_message_dialog.dart` | forward: `GET /session?roots&limit` + `prompt_async`; undo via revert | Forward is not described in BEHAVIOR.md |
| Viewport and scroll ownership | Single scroll owner; follow modes; jump FABs; prepend anchoring | `PC/chat_page_scroll_coordinator.dart`, `PC/chat_page_timeline_viewport.dart`, `PC/chat_page_runtime_support.dart` (2 022) | none | ADR-028/037/041/057. Major complexity hotspot |

### 2.6 Composer

| Feature | Behavior | Key files | OpenCode dependency | Notes |
|---|---|---|---|---|
| Slash commands | Built-ins handled locally: `/new /models /sessions /agent /open /help /compact /thinking /undo /redo`; server commands merged in | `PC/chat_page_model_selector_runtime.dart:1650-1738`, `PC/chat_page_command_query.dart`, `CI/chat_input_commands_controller.dart` | `GET /command` (no directory) + `GET /file?path=.opencode/commands` (client scan); send = `POST /session/:id/command {command, arguments, model:"p/m"}` | — |
| Skills | **None** | — | — | No code refers to skills |
| @ mentions | Files (12), workspace symbols (8), agents | `PC/chat_page_command_query.dart:4-95`, `CI/chat_input_mentions_controller.dart` | `/find/file`, `/find/symbol`, agent list | **Inserted as plain text `@value `**; no file/agent parts sent |
| Shell mode | `!` prefix → one-shot shell | `CI/chat_input_state_machine.dart`, `D/datasources/chat_remote_datasource_helpers.dart:5-68` | `POST /session/:id/shell {agent:"build", command}` | Agent is hard-coded |
| Attachments | Images/PDF: picker, drag-drop, paste (incl. raw clipboard images); 10 MB cap; capability-gated per model | `CI/chat_input_attachment_controller.dart`, `CI/chat_input_external_drop_controller.dart`, `CI/chat_input_external_files.dart` | `file` part with a `data:` URL; model `attachment` / `modalities` from `/provider` | — |
| File-viewer selection to chat | Send selected lines as context | `PC/chat_page_file_viewer.dart:1072-1080` | `file` part `url=file://path?start&end` + `source` | — |
| Canned answers | Global or project scope; append/replace; auto-send; agent/model/variant override | `DM/entities/canned_answer.dart`, `CI/chat_input_canned_controller.dart` (1 177) | none | — |
| Drafts and history | Per-session persisted drafts (text, attachments, shell mode); arrow-key history; spell check toggle | `P/providers/chat_provider_draft_part.dart`, `CI/chat_input_history_controller.dart` | none | Stored in the file cache |
| STT in composer | Mic button, many engines (§2.11) | `CI/chat_input_speech_controller.dart` | none | — |

### 2.7 Agents, models and variants

| Feature | Behavior | Key files | OpenCode dependency | Notes |
|---|---|---|---|---|
| Model selector | Connected, non-hidden, non-deprecated models + free Zen models (`opencode` provider with `cost.input==0`); sections Favorites → Recent → Provider; cached catalog | `PC/chat_page_model_selector_runtime.dart` (1 738), `D/datasources/app_remote_datasource.dart` | `GET /provider`; `catalog.updated` → reload | ADR-023 model rules |
| Variants (reasoning effort) | Per-model variant picker; "Auto" clears it; remembered per agent+model | same; `CP/chat_provider_selection_helpers.dart` | `models[].variants`; `variant` field in prompt | — |
| Favorites and recent cycling | Stars per server; `mod+m` / `mod+t` / `alt+shift+j/k` cycling | `CP/chat_provider_preference_ops.dart`, `CP/chat_provider_shortcut_cycle_ops.dart` | none | — |
| Agent selection | Primary agents; last model remembered per agent; fallback to the latest assistant message's model/agent | `CP/chat_provider_context_state_ops.dart`, ADR-035 | `GET /agent` (5 fields read) | — |
| OpenCode defaults editor | Default model, small model, default agent, username, snapshot, autoupdate, share | `P/providers/settings_provider_opencode_defaults.dart` | `GET/PATCH /config` | Deferred while busy (ADR-019): a v1 config write disposes the instance and aborts running turns |
| Multi-device selection sync (experimental, off) | Syncs composer selection across devices | `CP/chat_provider_selection_sync_ops.dart`, `CP/chat_provider_selection_helpers.dart:375-397` | `PATCH /config {agent:{__codewalk:{options:{codewalk:{…}}}}}` | **Hack**: a fake agent stores client state |
| Provider auth / login | **None** | — | `/provider/auth` unused | — |

### 2.8 Interactive prompts and tasks

| Feature | Behavior | Key files | OpenCode dependency | Notes |
|---|---|---|---|---|
| Permission cards | Reject / Always / Once; child-session prompts mirrored into the root with an origin badge | `P/widgets/permission_request_card.dart`, `P/providers/chat_provider.dart:2630-2679` | `permission.asked/updated/replied` (+ `.v2.*`); `GET /permission`; `POST /session/:sid/permissions/:pid {response, remember}`; legacy `/permission/:id/reply` | — |
| **Auto-approve ("YOLO")** | Toggle in the agent-menu footer, **default ON**; replies `always` + `remember:true` to every permission in the current thread (incl. subagents); continues in the Android background worker | `P/services/permission_auto_approve_runtime.dart`, `PC/chat_page_lifecycle.dart:240-509`, `P/services/android_background_alert_worker.dart:345-396, 600-631, 889-990` | same endpoints | ADR-023 EXC-001. Business logic lives in the **page** layer. No per-kind filtering. BEHAVIOR L1840 is stale (it says once/always depends on the request) |
| Question cards | Step-per-question wizard, single/multi choice, custom answer, review step; error state kept on failure | `P/widgets/question_request_card.dart` (831) | `question.*` (+ `.v2.*`); `GET /question`; `POST /question/:id/reply {answers}` / `reject` | Custom answers are split on commas into several answers (quirk, `:108-117`) |
| Todo / task list | Read-only panel + header progress; collapses with the keyboard | `P/widgets/session_todo_list_widget.dart` | `todo.updated`, `GET /session/:id/todo` | — |

### 2.9 Files, terminal and diff

| Feature | Behavior | Key files | OpenCode dependency | Notes |
|---|---|---|---|---|
| File tree / quick open | Lazy tree; search by name and by content | `PC/chat_page_file_explorer_controller.dart`, `P/utils/file_explorer_logic.dart` | `/file`, `/find/file`, `/find` | — |
| File viewer / editor | Tabs, highlighting, Ctrl+S, autosave (off by default, 30 s), 64 KiB cap, line-ending preservation | `PC/chat_page_file_viewer.dart` (1 523), `PC/chat_page_file_runtime.dart` (2 740) | read `/file/content` | ADR-043/052 |
| File mutations | New file/folder, rename, duplicate, delete, write | `P/services/workspace_file_operations_service.dart` (1 451), `P/widgets/file_tree_context_menu.dart` | **hidden session** + `POST /session/:id/shell` running an encoded script, 48 KiB env chunks, `CW_FILE_OP_JSON:` sentinel, then DELETE | ADR-043 (ADR-023 exception); capability probe per directory; read-only fallback |
| Terminal (PTY) | Embedded xterm; minimize, maximize, close; mobile extra keys | `P/services/codewalk_terminal_controller.dart`, `P/services/codewalk_terminal_socket_io.dart`, `P/widgets/codewalk_terminal_panel.dart`, `D/datasources/terminal_remote_datasource.dart` | `POST/PUT/DELETE /pty`, `WS /pty/:id/connect?directory&cursor` | ADR-027. Not in the local doc snapshot. Not on web |
| LSP / diagnostics, MCP, formatter | **None** | — | `/lsp`, `/mcp`, `/formatter` unused | — |

### 2.10 Usage, quotas and cost

| Feature | Behavior | Key files | OpenCode dependency | Notes |
|---|---|---|---|---|
| Provider quotas / rate limits | Grouped bars with pace (on-track / fast / too fast); 60 s TTL; desktop utility pane refreshes every 20 min | `P/providers/quota_provider.dart`, `D/datasources/quota_remote_datasource.dart` (+ `.part.js.dart` 1 742), `P/widgets/quota/*`, `P/utils/quota_pace_utils.dart` | OpenChamber `GET /api/quota/providers` + `/api/quota/:id`; otherwise **hidden session + `/shell`** running `node -e <base64 JS>` that reads the host's `~/.local/share/opencode/auth.json` (and Antigravity/Cursor files) and calls ~19 provider usage APIs (Anthropic OAuth usage, ChatGPT `wham/usage`, Copilot, Google, OpenRouter, OpenCode Go, xAI, …) | ADR-029. **Writes refreshed tokens back to host files** (xAI, Cursor). Needs `node` on the host |
| Context window and cost | See §2.5 | — | — | — |

### 2.11 Voice (client-only)

| Feature | Behavior | Key files | Notes |
|---|---|---|---|
| Speech-to-text | Engines: Native (`speech_to_text`), Sherpa, Moonshine, Parakeet, SenseVoice, Nemotron (on-device via `sherpa_onnx`, downloadable models), API (OpenAI / Groq / custom) | `P/services/speech_input_service*.dart`, `*_model_manager_io.dart`, `P/services/speech_model_residency_controller.dart`, `P/services/windows_microphone_service.dart`, `P/services/linux_microphone_capture_io.dart` | ADR-006/038/039/044/053. Platform matrix: `P/utils/speech_engine_platform_support.dart` |
| Text-to-speech / read aloud | Native, Edge (unofficial websocket), OpenAI-compatible, ElevenLabs, NVIDIA NIM; pause, resume, stop; cache | `P/services/read_aloud_service.dart`, `P/services/tts/*` | ADR-047/048. Keys stored in secure storage |

### 2.12 Notifications, background and attention

| Feature | Behavior | Key files | OpenCode dependency | Notes |
|---|---|---|---|---|
| In-app/local notifications | Categories agent / permissions / errors; sounds; root sessions only; tap opens the session; auto-dismiss when resolved | `P/services/notification_service.dart` (863), `P/services/event_feedback_dispatcher.dart`, `P/services/sound_service.dart` | `permission.*`, `question.*`, `session.error`, `session.idle`, busy→idle `session.status` | Server offline never notifies |
| **Android background monitoring** | Persistent FGS notification keeps the process alive; WorkManager polling: periodic 15 min plus a one-off chained probe every 3 min while busy and a 5 min tail | `P/services/android_background_alert_worker.dart` (1 645), `android_background_alert_logic.dart`, `android_foreground_monitor_service.dart`, `CodeWalkForegroundService.kt` | `GET /session/status`, `/session`, `/permission`, `/question` (+ auto-approve replies) | Task names `codewalk.android.background.alerts(.once)` / `codewalk.background.alerts.poll` (`:26-30, 144-152`). Only the **active** profile is monitored; **no OAuth/Tailscale** (`car_messaging_gate.dart:15-17`). Busy→idle completion detection may miss sessions absent from `/session/status` (inferred risk) |
| Session attention overlay (Android) | Bubble/panel over other apps (opt-in); Open / Read / Dismiss; encrypted previews | `P/services/session_attention/*` (overlay entrypoint 973), `SessionOverlayService.kt`, `P/widgets/session_attention_overlay/*` | its own `/global/event` SSE + polling + `GET …/message?limit=20` post-idle | ADR-049. Desktop variant removed (ADR-051) |
| Android Auto messaging | MessagingStyle with the final answer; voice reply | `P/services/car_messaging/*`, `D/car_messaging/*` | reply `POST /session/:root/prompt_async {parts:[text]}`; poll `…/message?limit=20` | ADR-055. No idempotency, so an ambiguous timeout is never re-sent |
| Desktop tray / close | Tray Show/Quit; close goes to tray, minimizes or quits | `P/services/desktop_tray_service_io.dart` | — | — |
| Resume/reconnect | One coalesced resync; resume grace; Android short hold | `CP/chat_provider_lifecycle_ops.dart`, `CP/chat_provider_realtime_ops.dart:125-192`, `PC/chat_page_lifecycle.dart` | SSE resubscribe + list refreshes | No `Last-Event-ID` replay upstream |

### 2.13 Settings, desktop, updates and misc

| Feature | Behavior | Key files | Notes |
|---|---|---|---|
| Settings shell | Groups: setup, experience, input, support; search down to individual controls; provenance chips (local vs OpenCode-backed) | `P/pages/settings_page.dart`, `P/pages/settings/sections/*`, `P/pages/settings/settings_search_catalog.dart` | Sections: Servers, Appearance, Behavior, Notifications, Speech, TTS, Shortcuts, About (+ Logs page) |
| Theming | System/light/dark, AMOLED, dynamic color, brand seeds, contrast, 37 OpenCode Web presets, Classic/Refined, 5 densities, text sizes | `P/theme/*` | `make theme-sync` regenerates the OpenCode Web theme registry |
| Keyboard shortcuts | 15 configurable actions; Escape and Enter policies | `PC/chat_page_shortcuts.dart`, `P/utils/shortcut_binding_codec.dart` | Client-local; never written to `tui.json` |
| Desktop chrome | Tabs integrated into the title bar, or system decorations | `P/services/desktop_window_chrome_service.dart`, `P/widgets/desktop_window_title_bar.dart` | — |
| Self-update | Checks hourly, at start and when Settings opens (≥20 min apart). Android downloads the APK and opens the installer. Desktop runs `curl -fsSL install.cat/verseles/codewalk \| sh` or PowerShell stage/apply | `P/services/update_check_service.dart`, `P/providers/settings_provider_update_install.dart` | `GET api.github.com/repos/verseles/codewalk/releases/latest`; takes the first `.apk` asset |
| Release history / What's new | Parses `CHANGELOG.md` from raw GitHub (strict format) | `P/services/release_history_service.dart`, `P/pages/settings/release_history_page.dart` | — |
| Logs | Off by default; perf timings; tags; export; secrets redacted | `P/pages/logs_page.dart`, `C/logging/app_logger.dart` (960) | ADR-042 |
| Deep links | **None** (only MAIN/LAUNCHER; notification payloads are routed internally) | `android/app/src/main/AndroidManifest.xml` | — |

---

## 3. Workarounds, polling, heuristics and caches that exist only because of OpenCode v1

"v2?" says whether the item could be deleted if the server offered native support. Removability is (inferred) in every row.

| # | Item | Where | v1 gap compensated | v2? |
|---|---|---|---|---|
| 1 | **Dual SSE** (`/event?directory` + `/global/event`) + FNV-hash dedup ring (256) | `D/datasources/chat_remote_datasource.dart:1787-1990`; `CP/chat_provider_event_reducer_helpers.dart:163-330` | directory-scoped instance bus vs. global bus; no event ids | Yes, with one sequenced stream |
| 2 | Reconnect backoff + 5 s health tick + 20 s stale ⇒ degraded mode, 30 s polling of sessions/active/permissions/questions | `chat_remote_datasource.dart:1827-1968`; `CP/chat_provider_realtime_ops.dart:49-123`; `CP/chat_provider_realtime_aux_ops.dart:350-503` | half-open TCP; heartbeat-only liveness | Partly |
| 3 | Post-reconnect full recovery (permissions, questions, active view, session list) | `CP/chat_provider_realtime_aux_ops.dart:400-461` | **no `Last-Event-ID` replay** (upstream #25657) | Yes, with replay |
| 4 | **Send-completion watcher**: status poll every 2 s ×90, assistant-id diffing by "known ids", completion poll every 1 s up to ×120, clock-skew leeway 5 s | `chat_remote_datasource.dart:921-1624`; `C/config/feature_flags.dart:22-30` | `prompt_async` returns no message/turn id; per-send SSE aborts the turn on disconnect | Yes |
| 5 | `message.updated/created` ignore `info` and re-GET the whole message; **every text delta schedules a 120 ms debounced re-GET**; per-message `deltaVersion` stale guard | `CP/chat_provider_event_reducer_session_ops.dart:550-770`; `CP/chat_provider_message_merge_ops.dart:25-194` | events not trusted as complete; lost/reordered deltas | Yes, with full-state or revisioned events |
| 6 | Delta overlap trimming; non-regressive part merge; completed never replaced by incomplete (P-002) | `CP/chat_provider_message_state_ops.dart:23-67, 180-520` | overlapping `part.updated` + `part.delta` | Yes, with revisions |
| 7 | **Optimistic `local_user_*` echo reconciliation** by text/attachment signature in fuzzy time windows (−2 s/+45 s, 5-10 min) | `CP/chat_provider_message_merge_ops.dart:197-338`; `CP/chat_provider_message_state_ops.dart:1083-1244`; `CP/message_reconciliation.dart`; `CP/message_timeline_order.dart` | client cannot send its own message id (P-001) | **Yes** (largest single simplification) |
| 8 | Fabricated `completedTime=now` on idle, abort or stream end; synthetic `msg_inline_abort_*` / `msg_inline_server_error_*` messages | `CP/chat_provider_message_state_ops.dart:568-605`; `CP/chat_provider_abort_policy_ops.dart` | server doesn't always finalize the message; abort arrives as an untyped error | Mostly |
| 9 | Abort suppression for 8 s using string matching ("abort", "cancel", **"retry"**, "What you want to do different?") | `CP/chat_provider_abort_policy_ops.dart:3-17`; `P/utils/chat_abort_message.dart` | untyped abort errors | Yes, with typed errors (the "retry" match is a latent bug) |
| 10 | Busy heuristics: tool-only tails, "settled revealable" tail beats a stale busy, REST busy ignored for 4 s after SSE idle, synthetic `session.idle` from busy→idle status | `CP/chat_provider_session_attention_ops.dart:404-470`; `P/utils/chat_assistant_settlement.dart`; `P/providers/chat_provider.dart:2157-2178`; `CP/chat_provider_event_reducer_helpers.dart:404-458` | REST and SSE status disagree; no authoritative turn object | Yes |
| 11 | History pagination by growing `limit` (O(n²) bytes); 200-message SWR tail diff-merge; full refetch on gap | `P/providers/chat_provider.dart:4613-4700`; `CP/chat_provider_lifecycle_ops.dart:152-410`; `CP/chat_provider_message_merge_ops.dart:507-822` | no `before`/`since` cursor | Yes |
| 12 | Global-event fallback reconciles (300 ms debounce) for unscoped or unsupported events; patches inactive context snapshots | `CP/chat_provider_event_reducer_global_ops.dart:38-176, 720-760` | thin or unscoped event payloads | Yes |
| 13 | `session.next.*` events trigger full refreshes (no reducers) | `CP/chat_provider_event_reducer_session_ops.dart:1006-1033` | v2-ish events not modelled | Write real reducers |
| 14 | Pending-question retry (5 s, 10 s), 15 s "recently resolved" grace, 256 permission tombstones, merge with live SSE | `CP/chat_provider_realtime_aux_ops.dart:513-800`; `P/providers/chat_provider.dart:379-413` | missed `question.asked` during gaps (#143) | Yes, with replay |
| 15 | Permission reply legacy fallback `/permission/:id/reply`; `/path`→`/app`→`/app/init`; `workspace`+`directory` → directory-only → unscoped retries; `/agent` with 4 payload shapes; `/provider` old and new schema | `chat_remote_datasource.dart:2059-2078`; `D/datasources/app_remote_datasource.dart:37-289`; `D/models/provider_model.dart:7-32` | server-version drift across v1 | **Delete** in a v2-only client |
| 16 | **Config-write deferral** (8 s after send + while busy) | `CP/chat_provider_selection_helpers.dart`, `P/providers/settings_provider_opencode_defaults.dart`; ADR-019 | `PATCH /config` disposes the instance and aborts sessions | Yes, if v2 config writes are safe |
| 17 | **Hidden-session piggy-backing**: titles (`_title_gen` + `title` agent), file ops (`/shell` scripts), quota (`/shell` + `node -e`); ephemeral-id filtering in reducers | `P/services/chat_title_generator.dart`; `P/services/workspace_file_operations_service.dart:664-743`; `D/datasources/quota_remote_datasource.dart:163-393`; `CP/chat_provider_event_reducer_global_ops.dart:14, 203` | no title, file-write or usage APIs | Yes if v2 has them; otherwise move them into a per-harness adapter |
| 18 | Selection sync through a fake `__codewalk` agent in `/config` (experimental) | `CP/chat_provider_selection_sync_ops.dart:92-140` | no per-client preference store | Yes |
| 19 | Diff "review changes" scan of up to 25 turns | `P/providers/chat_provider.dart:737-740, 2270-2330` | unscoped `/session/:id/diff` returns `[]` | Yes |
| 20 | Subagent child-session resolver (metadata keys / `<task id>` regex / positional pairing) | `PC/chat_page_timeline_builder.dart:1085-1352` | task part lacks a guaranteed child-session link | Yes, with an explicit link |
| 21 | Project slash commands scanned from `.opencode/commands` via `/file` | `PC/chat_page_command_query.dart:172-225` | `/command` incompleteness (inferred) | Probably |
| 22 | `PATCH /session {time:{archived}}`; archive cascade to children client-side | `D/models/chat_session_model.dart:553-571` | no archive endpoint / cascade | Depends on v2 |
| 23 | Android 3-detector stack (in-app SSE, foreground-service keep-alive, WorkManager polling with snapshot diffing) + overlay fallback poller + car reply poller | `P/services/android_background_alert_worker.dart`, `P/services/session_attention/*`, `P/services/car_messaging/*` | **no push / webhook**, no server-side unread or attention state, no idempotent prompt | Partly (Android constraints stay) |
| 24 | Context % and cost computed client-side from resident messages | `PC/chat_page_status_presenter.dart:136-230` | no session-level usage summary | Yes |
| 25 | Unknown part type rendered as `text`; tolerant multi-shape parsing everywhere | `D/models/chat_message_model.dart:670-700`; all `D/models/*` | schema drift | Replace with typed v2 models plus an explicit "unsupported part" UI |

Caches that are **not** v1 workarounds and are probably worth keeping: SWR session cache, file-backed payload store, notify batching, tab persistence, generation guards, health polling of non-active profiles.

---

## 4. Size metrics

| Area | Dart files | LOC |
|---|---|---|
| `lib/core` | 32 | 5 472 |
| `lib/data` (incl. 3 `.g.dart` + the 1 742-LOC JS-in-Dart part) | 44 | 14 695 |
| `lib/domain` | 53 | 6 672 |
| `lib/presentation` | 317 | 130 483 |
| ├ pages | 48 | 41 206 |
| ├ providers | 38 | 31 095 |
| ├ services | 132 | 25 904 |
| ├ widgets | 64 | 24 428 |
| ├ utils | 26 | 3 460 |
| └ theme | 9 | 4 390 |
| `lib/main.dart` | 1 | 413 |
| **Hand-written total** | **447 (+1 main)** | **≈157 700** |
| `lib/l10n/generated` | 15 | 107 385 |
| `third_party/xterm` / `third_party/tailscale` | — | 19 105 / 15 418 Dart + 5 740 Go |
| Android Kotlin | 4 | 1 572 |
| Windows C++ mic plugin | 1 | 588 |

**Hotspots**
- `ChatProvider`: 22 789 LOC in 30 files (main file + 26 `part` files + 2 standalone reconciliation helpers in `CP/`).
- `ChatPage`: 27 474 LOC in 30 files (main file + 27 in `PC/` + 2 `*_part.dart`).
- `chat_remote_datasource.dart` + helpers: 2 826.
- `AppProvider`: 2 663. `SettingsProvider`: 3 483. `onboarding_wizard_page.dart`: 2 451.
- `experience_settings.dart`: 2 195.
- `app_local_datasource.dart`: 2 266.

**Tests**
- 204 `*_test.dart` files (211 Dart files), 113 521 LOC, about 2 460 `test(` / `testWidgets(` calls.
- By folder: `test/unit` 148 files (providers 21, presentation 50, services 29, models 9, …), `test/widget` 46, `test/contract` 2 (`chat_event_contract_test.dart` 1 676 LOC, `opencode_contract_test.dart` 294), `test/integration` 2 (`opencode_server_integration_test.dart` 1 247), `test/web` 1, `test/presentation` 2.
- Fixtures: `test/support/mock_opencode_server.dart` (1 335 LOC, an in-process fake OpenCode server) and `test/support/fakes.dart` (2 986).
- CI (`.github/workflows/`): `ci.yml`, `release.yml`, `opencode-smoke.yml` (npm/bun install of `opencode-ai` on 3 OSes, on minor tags), `web-pages.yml`, `session-overlay-prototype.yml`.
- `make check` gates: analyze budget 337 issues, coverage gate 35 %.

---

## 5. Existing seams for a "harness adapter", and how much OpenCode leaks

### 5.1 Candidate seams

| Seam | Today | Adapter-readiness |
|---|---|---|
| `ChatRemoteDataSource` (abstract, 22 methods; `D/datasources/chat_remote_datasource.dart:20-204`) | sessions, messages, `sendMessage` stream, `subscribeEvents` / `subscribeGlobalEvents`, permissions, questions, abort, revert, init, summarize | **Closest to a harness port**, but its signatures use OpenCode-shaped models (`ChatInputModel`, `ChatEventModel` with an untyped map), `projectId` + `directory`, and two event streams |
| `ChatRepository` (domain, 25 methods) | maps to domain entities + `Either` | Good shape, but `ChatEvent{type, properties}` is a raw OpenCode event, and the entities are the v1 schema |
| `AppRepository` (6) / `ProjectRepository` (14) | catalog, agents, config / projects, files, search, worktrees | Reasonable capability groupings |
| `TerminalRemoteDataSource` (3) + `CodewalkTerminalSocket` | PTY REST + WS | Clean, small; capability-gated |
| `QuotaRemoteDataSource` | strategy chain (OpenChamber REST → shell probe) | Already a "strategy" pattern; usage should come from the harness |
| `ChatTitleGenerator` (abstract) / `OpenCodeTitleGenerator` | title via hidden session | A good pluggable seam (could become "harness-native titles or none") |
| `WorkspaceFileOperationsService` (+ capability probe) | file mutations through `/shell` | Has a capability check; swap in a native file-write adapter |
| `LocalOpencodeServerRuntime` (interface `start/diagnose/install/stop/dispose` + stdout/stderr/exit streams) | managed `opencode serve` | **Ready-made "HarnessRuntime" interface**; implementations are 100 % OpenCode-specific |
| `TtsBackend`, `SpeechInputService` | pluggable client backends | Pattern precedent for a provider registry |

### 5.2 Where OpenCode types and semantics leak into the UI

- **Raw event reduction lives in presentation.** `CP/chat_provider_event_reducer_*` parse OpenCode JSON with **data-layer** models: `ChatSessionModel.fromJson` (`global_ops.dart:201`, `session_ops.dart:154`), `SessionStatusModel.fromJson`, `MessagePartModel.fromJson` (`session_ops.dart:596`), `ChatPermissionRequestModel.fromJson`. 14 presentation files import `lib/data/*` (providers, services, pages, `chat_input_widget.dart`).
- **Event-type strings**: 169 references to `'session.*' / 'message.*' / 'permission.*' / 'question.*'` literals in 7 presentation files.
- **Domain = v1 wire schema**:
  - `DM/entities/chat_message.dart` has the 12 OpenCode part classes and `ToolState` pending/running/completed/error.
  - `SessionStatusType{idle,busy,retry}` (88 refs in 15 presentation files).
  - `ChatPermissionRequest{permission, patterns, always}` (40 refs in 13 files).
  - `SessionRevert{messageID, partID, snapshot, diff}`.
  - `ToolPart` 78 refs / 16 files; `ReasoningPart` 75 / 14; `SubtaskPart` 19 / 6.
- **Tool-name switch**: `P/utils/tool_presentation.dart:96-311` plus `CM/chat_message_tool_part.dart`, `PC/chat_page_timeline_*`, `PC/chat_page_composer_status.dart` hard-code OpenCode tool ids and their `input` / `metadata` keys. Claude Code (`Bash`, `Read`, `Edit`, `TodoWrite`, `Task`, …) and Codex (`shell`, `apply_patch`, …) use different names (inferred), so a normalization layer is needed.
- **Direct Dio from presentation** (26 files): `P/providers/{app,chat,settings}_provider.dart`, `P/pages/chat_page.dart`, `P/pages/onboarding_wizard_page.dart`, `PC/chat_page_command_query.dart` (via `di.sl<DioClient>()`), `P/services/{chat_title_generator, workspace_file_operations_service, android_background_alert_worker, session_attention/session_overlay_entrypoint, car_messaging/car_messaging_dispatch_worker, project_icon_discovery_service_io, …}`.
- **Business logic in pages**: auto-approve drain (`PC/chat_page_lifecycle.dart:240-509`), subagent resolver (`PC/chat_page_timeline_builder.dart`), slash command loading, notification-tap routing (`P/pages/chat_page.dart:1851-2040`), Android FGS policy (`PC/chat_page_lifecycle.dart:527-698`).
- **OpenCode-only concepts in the UX**:
  - agents with `mode` (primary/subagent)
  - variants
  - `!` shell → `/shell` with agent `build`
  - `/compact` → summarize
  - revert/unrevert snapshot semantics
  - share URLs
  - "free Zen models"
  - `opencode.ai` theme presets
  - the `serverId::directory` scope (a "project directory on the server host")
- **Optimistic-ID invariant** (`local_user_*` + never send `messageID`) is tied to v1 behavior. With a v2 that accepts client message ids, most of §3 #7 goes away, but ADR-023/041 and the contract tests would have to be rewritten.

### 5.3 Implications (inferred)

1. A v2 client should define a harness-neutral core:
   - **Session / Turn / Item** model: user message, assistant text, reasoning, tool call with normalized kind + raw payload, file change, subagent link, approval request, question.
   - **ordered event stream** with resume tokens
   - **capability flags**: pty, files.write, diff, revert, fork, share, todos, quotas, commands, mentions, variants, worktrees
2. Then write one adapter per harness. The OpenCode-v2 adapter replaces `D/datasources/*` plus the reducers. Codex, Claude Code and Pi adapters likely need a bridge process, because they are not HTTP servers like OpenCode (inferred).
3. Reuse the UI-only subsystems largely as they are: markdown/LaTeX/Mermaid, STT/TTS, theming, tabs, settings, notifications shell, Tailscale/OAuth transport, file viewer UI, xterm. The chat timeline/viewport code is reusable only after it is decoupled from the raw part types.

---

## 6. Open uncertainties

- Whether `session.next.*`, `permission.v2.*`, `question.v2.*` and `catalog.updated` match **OpenCode v2** semantics exactly. CodeWalk only routes them and does not model their payloads.
- Whether PTY (`/pty`, `/pty/:id/connect`), `/permission`, `/question*` and `GET /session?roots&start&search&limit` are official in v2. The local doc snapshot (`ai-docs/opencode_server.md`) does not list them.
- Background completion detection relies on `busy` → `idle` transitions in `GET /session/status`. If the server drops idle sessions from that map, completions may be missed (inferred; verify upstream).
- Web SSE through Dio's browser adapter: real streaming vs. buffered XHR progress was not verified.
- The per-chunk `utf8.decode` in the SSE parser (`chat_remote_datasource.dart:1861-1863`) may garble multi-byte characters split across chunks (inferred, untested).
- macOS sandbox impact on managed install and self-update (inferred from entitlements).
- `X-Session-Id` purpose: no OpenCode doc reference was found.
