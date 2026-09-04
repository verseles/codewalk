# Code map of CodeWalk

## Project Snapshot

- Flutter client for OpenCode-compatible servers (ADR-023: contract-first compatibility policy).
- Architecture follows `presentation -> domain -> data` with `get_it` + `provider`.
- Multi-platform targets in repo: Android, Linux, macOS, Windows, Web.
- Chat stack is decomposed into orchestrators plus focused cluster modules.
- Material icon migration in UI is complete on `Symbols.*` (`material_symbols_icons`).
- Theme system follows Material You (MD3): user-controlled theme mode, dynamic color toggle, AMOLED dark toggle, brand color seeds, contrast level, and responsive window size classes.
- Visual style layer (issue #86): `VisualStyle` (`classic` / `refined`) persisted in `ExperienceSettings`, exposed via `SettingsProvider`, and propagated through `AppVisualStyleTokens` `ThemeExtension` so chat surfaces can consume shape/surface tokens while `OpenCodeThemeTokens` continue to drive markdown/syntax palettes. New installs default to `VisualStyle.refined`; legacy persisted JSON missing the `visualStyle` key falls back to `VisualStyle.classic` for backward compatibility.
- LaTeX math rendering (`$...$` and `$$...$$`) supported in chat messages via `flutter_math_fork` with custom markdown syntaxes and styled fallback on parse failure.
- Session attention adds encrypted completion snapshots, root-session aggregation, and Android, desktop, and iOS presentation hosts.
- Session tabs persist server-scoped open/closed session state and provide cross-project chat navigation with attention and busy indicators; per-session icon overrides (issue #138) replace the project icon with a Material Symbols preset per tab.

## Folder Structure

```text
codewalk/
├── ai-docs/                            # AI docs and engineering artifacts
│   ├── opencode_server.md              # Server contract local anchor (used by ADR-023)
│   ├── opencode_web.md                 # Web contract local anchor (used by ADR-023)
│   ├── opencode_config.md              # Config schema local anchor (used by ADR-023)
│   └── opencode_models.md              # Model/provider compatibility notes (used by ADR-023)
├── assets/
│   ├── images/                           # Source and generated launcher/tray icon assets used by `make icons`
│   ├── moonshine_models.json             # Moonshine STT model catalog
│   ├── parakeet_models.json              # Parakeet STT model catalog (id, label, download URL, lang)
│   ├── sherpa_models.json                # Sherpa STT model catalog
│   └── sensevoice_models.json            # SenseVoice STT model catalog (id, label, download URL, lang)
├── lib/                                # Application source
│   ├── main.dart                       # App bootstrap (DI, providers, shell)
│   ├── core/                           # Config, constants, DI, errors, logging, network
│   │   ├── auth/                        # OAuth module plus secure OAuth/TTS/STT-API credential storage
│   │   ├── i18n/                        # Locale registry, context bridge, localization helpers
│   │   ├── logging/                     # AppLogger plus a bounded local Android process/error diagnostic ring and method-channel normalizer
  │   │   ├── tailscale/                    # Tailscale transport: shared-identity service (IO/stub with logout/refresh parity), node state, peer model, Dio adapter with head timeout
│   │   └── utils/                       # Core utilities (path, timeline search)
│   ├── data/                           # Data layer: datasources, API/storage models, repositories
│   │   ├── datasources/                # Remote/local IO boundaries
│   │   │   └── app_local_datasource.dart # SharedPreferences-backed local state, including server-scoped session tabs and session-tab icon overrides
│   │   ├── session_attention/          # Encrypted completion snapshot store and conditional atomic file storage
│   │   └── car_messaging/              # Encrypted car-messaging thread/reply store with conditional atomic file storage and lock file (issue #99)
│   ├── domain/                         # Domain layer: entities, repository contracts, use cases
│   │   ├── entities/persisted_session_tabs_state.dart # Versioned open/closed session-tab payload models
│   │   ├── entities/session_tab_icon_overrides.dart # Versioned per-session session-tab icon override entities (issue #138)
│   │   ├── entities/session_attention_overlay/ # Session-attention identity, item, aggregate, and transport models
│   │   └── entities/car_messaging.dart # Bounded car-messaging thread/reply/state entities and limits (issue #99)
│   ├── l10n/                           # Canonical Flutter gen_l10n ARB files (14 locales) and generated delegates
│   │   ├── app_en.arb                  # English template ARB (1877 UI keys with metadata) — canonical source of truth
│   │   ├── app_*.arb                   # Translation ARBs (ar, bn, de, es, fr, hi, it, ja, ko, pt, ru, ur, zh) — canonical
│   │   └── generated/                  # Auto-generated AppLocalizations classes via flutter gen-l10n (do not edit)
│   └── presentation/                   # UI, state providers, runtime services
│       ├── pages/                      # App pages and page-level orchestration
│       │   ├── app_shell_page.dart
│       │   ├── onboarding_wizard_page.dart # First-run onboarding wizard (Welcome → Server Setup → Ready)
│       │   ├── chat_page.dart          # Chat orchestrator/facade
│       │   ├── chat_page_types_part.dart # Shared intents, configurations, and keys (incl. scoped Selector/Selector2 build keys used by desktop chat body to avoid full shell rebuilds on composer selection changes)
│       │   ├── chat_page_local_models_part.dart # Local UI state classes (part of chat_page.dart; see commit 8759defc)
│       │   ├── chat_page/              # ChatPage decomposed clusters (26 modules)
│       │   │   └── chat_page_session_tabs.dart # Cross-project session-tab activation, rollback, and close fallback
│       │   └── settings/               # Settings section pages plus shared section layout widgets
│       ├── providers/                  # App/Chat/Project/Settings state orchestration
│       │   ├── chat_provider.dart      # Chat provider orchestrator/facade with SessionActionTarget support for inactive-tab mutations
│       │   └── chat_provider/          # ChatProvider decomposed clusters (25 modules)
│       │       ├── chat_provider_target_ops.dart # SessionActionTarget helpers for exact server/directory scoped mutations and snapshot updates
│   │       └── chat_provider_session_tab_ops.dart # Session-tab load/write, icon-override load/apply, reconciliation, lifecycle hooks, and pinned-state cleanup on directory removal
│       ├── widgets/
│       │   ├── chat_message_widget.dart # StatefulWidget with build-skip cache for messages
│       │   ├── chat_message/            # ChatMessageWidget decomposed part renderers (consume visualStyleTokens — issue #86)
│       │   ├── chat_input_widget.dart  # Chat input orchestrator/facade
│       │   ├── chat_input/             # ChatInput decomposed clusters (11 modules; consume visualStyleTokens — issue #86)
│       │   ├── math_expression_widget.dart # LaTeX math renderer with parse-failure styled fallback
│       │   ├── codewalk_terminal_extra_keys.dart # Native Android/iOS terminal extra-key widget and controller
│       │   ├── session_attention_overlay/ # Shared bubble/panel overlay widget and controller
│       │   ├── project_context_menu.dart # ProjectContextMenuRegion with right-click, long-press, ContextMenu key, Shift+F10, semantics and destructive Close project
│       │   ├── session_context_menu.dart # Shared session popup/context menu with SessionMenuAction enum and buildUnifiedSessionMenuEntries
│   │       ├── session_tab_icon_picker.dart # Session-tab icon preset picker dialog (project icon or 12 Material Symbols presets)
│   │       └── session_tab_strip.dart # Responsive full-width session-tab strip with project/icon-preset, attention, busy, overflow, focus, and semantics support
│       ├── services/                   # Platform/runtime services (tray, notifications, STT, read-aloud/TTS, terminal, etc.)
│       │   ├── session_tab_icon_override_store.dart # Per-server persisted session-tab icon override store
│       │   ├── session_tab_icon_presets.dart # SessionTabIconPreset enum + localized preset labels
│       │   ├── session_attention/       # Attention coordinator, completion resolver, host contract/protocol, and platform entrypoints
│       │   ├── car_messaging/           # Android Auto notification messaging: action handler, gate, dispatch worker, notifier, runtime (issue #99)
│       │   └── tts/                    # Read-aloud TTS contracts, native/cloud backend adapters, executor, defaults, generated-audio player, and text extraction
│       │       ├── read_aloud_default_resolver.dart # Fresh-install read-aloud provider/voice default resolver
│       │       ├── edge_tts_protocol.dart # Edge/Bing Read Aloud URL, header, frame, SSML, voice-list, and MP3 frame helpers
│       │       ├── edge_tts_websocket.dart # Conditional Edge TTS websocket transport contract/export
│       │       ├── edge_tts_websocket_io.dart # `dart:io` websocket upgrade transport for native targets
│       │       ├── edge_tts_websocket_stub.dart # `web_socket_channel` transport for non-IO targets
│       │       ├── elevenlabs_tts_backend.dart # ElevenLabs cloud TTS voice discovery and generated MP3 synthesis
│       │       └── nvidia_nim_tts_backend.dart # NVIDIA Speech NIM cloud TTS voice discovery and generated WAV synthesis
│       ├── utils/ # Presentation helpers (incl. WindowSizeClass MD3 breakpoints, diff parser, file path detector, file path markdown, math markdown)
│       └── theme/                      # Material You theme: AppTheme, AppShapes, BrandColor seeds, AppSemanticColors, AppVisualStyleTokens (issue #86)
├── test/                               # Unit, widget, integration, presentation, support tests
├── tool/ci/                            # Analyzer budget, coverage gate, and session-overlay Android instrumentation scripts
├── tool/i18n/                          # ARB catalog sync/validation and code migration tooling (arb_strings.dart is generated from the ARBs)
├── .github/workflows/                  # CI and release workflows
├── .opencode/agents/                  # Repo-local OpenCode agents
├── android/ linux/ macos/ web/ windows/ # Platform runners/build configs
│   ├── android/app/build.gradle.kts      # Android build config and AndroidX Browser Custom Tabs dependency
│   ├── android/app/src/main/AndroidManifest.xml # Android package-visibility query for Custom Tabs; `com.google.android.gms.car.application` meta-data referencing `@xml/automotive_app_desc` (issue #99)
│   ├── android/app/src/main/kotlin/com/verseles/codewalk/
│       ├── MainActivity.kt              # Android session-overlay/system channel host, Android process-diagnostic method-channel query, composer clipboard content-URI resolver, native CustomTabs OAuth + Tailscale authorization launcher (`launchTailscaleAuthorization`/`closeTailscaleTab`), and activation forwarding
│       └── overlay/SessionOverlayService.kt # Android foreground overlay host and service-owned Flutter engine
│   ├── android/app/src/debug/           # Debug/test source-set used by session-overlay prototype instrumentation (issue #99 automotive descriptor moved to main source set)
│   └── windows/runner/                   # Windows runner sources (incl. `windows_microphone_plugin.{h,cpp}` runner-owned WASAPI bridge for on-device STT — see ADR-038)
├── android/app/src/main/res/drawable-*/ # Android notification small icons (`ic_stat_codewalk.png`)
├── linux/runner/resources/             # Linux launcher icon + desktop entry icon metadata
├── third_party/                         # Vendored Dart packages (path dependencies)
│   ├── tailscale/                        # Userspace Tailscale networking; Go native build hook via `hook/build.dart`
│   └── xterm/                            # xterm.js terminal emulator Dart port (Windows printable/AltGr fallback plus opt-in raw committed-text interception; defaults unchanged)
└── Makefile                            # Main development and validation commands
```

## Entry Points

```text
lib/main.dart                                # Runtime entry; DI (including the provider-routed TTS backend registry), providers, DynamicColorBuilder with user theme prefs (theme mode, dynamic color, AMOLED dark, brand seed, contrast, OpenCode preset, visual style); syncs dynamic color availability to SettingsProvider via postFrameCallback; passes `settingsProvider.visualStyle` into `AppTheme.lightFrom`/`darkFrom` alongside `OpenCodeThemeTokens` extensions
lib/presentation/pages/app_shell_page.dart   # Root shell; gates onboarding wizard, mounts ChatPage and desktop tray behavior; cold-start loading hint via `coldStartTailscaleHint()` mapping Tailscale bring-up state to localized status text while providers initialize; triggers startup/hourly update toast via `addPostFrameCallback` + `UpdateCheckResult` when `checkUpdatesOnOpen` is enabled; reacts to `UpdateInstallState` transitions with platform-aware snackbars (Android downloading progress, desktop installing spinner, done/retry states) and triggers `startInstall()`
lib/presentation/pages/onboarding_wizard_page.dart # First-run wizard shown when no server is configured
lib/presentation/pages/settings_page.dart     # Settings landing and responsive split/detail shell; navigates to section destinations grouped by category (setup, experience, input, support) with a searchable section list; input places `'tts'` (Text to speech) directly below `'speech'` (Speech to text); shows the shared update notice at the top when `SettingsProvider.updateCheckResult` contains a newer non-dismissed CodeWalk version
lib/presentation/pages/chat_page.dart         # Main chat/session/file UI entry; mounts the in-app session-attention overlay on iOS; uses WindowSizeClass for responsive layout; guards startup logic against no-active-server state; timeline empty state includes CTA to setup wizard; exposes buildComposerReceivingTips() for the localized composer status-tip catalog
  └── chat_page_local_models_part.dart # Local UI state classes (part of chat_page.dart; see commit 8759defc)
lib/presentation/services/session_attention/session_overlay_entrypoint.dart # Desktop child-window and Android service-engine Flutter entrypoints; builds the host ReadAloudService with native, Edge, OpenAI-compatible, ElevenLabs, and NVIDIA NIM TTS backends
android/app/src/main/kotlin/com/verseles/codewalk/MainActivity.kt # Android platform-channel host (session overlay, process-diagnostic method-channel query, composer clipboard, launches native OAuth/Tailscale auth in CustomTabs with `closeTailscaleTab` close signal) and activation handoff entrypoint
android/app/src/main/kotlin/com/verseles/codewalk/overlay/SessionOverlayService.kt # Android foreground-service overlay entrypoint
lib/presentation/pages/logs_page.dart           # In-app App Logs surface; gated by `SettingsProvider.loggingEnabled` (disabled by default) — renders `_LogsDisabledState` empty-state with enable action when off, otherwise filters by time range/level/search/performance, supports **tag filter chips** (common task/network/cache presets plus **custom tag** input dialog), copies filtered entries, surfaces `Slowest performance logs` modal or, when a `task:*` tag is selected, `Slowest tasks` modal; AppLogger/measurePerformance toggle persisted via SettingsProvider
.github/workflows/ci.yml                      # CI workflow entry
.github/workflows/release.yml                 # Release workflow entry
```

## Core Modules

```text
lib/core/di/injection_container.dart              # Registers datasources, repositories, usecases, providers, TailscaleService, WorkspaceFileOperationsService, TtsApiKeyStorage, SttApiKeyStorage, and ReadAloudService's native, Edge, OpenAI-compatible, ElevenLabs, and NVIDIA NIM TTS backends; registers ApiSpeechInputService as a factory (non-web only, `ApiSpeechInputService(apiKeyStorage: sl<SttApiKeyStorage>())`) so each composer resolves its own isolated instance; injects SettingsProvider's nativeReadAloudAvailabilityProbe from ReadAloudService.isProviderAvailable(ReadAloudProvider.native); wires tailscaleService into AppProvider factory; _loadLocalConfig applies tailscaleEnabled on active profile
lib/core/constants/app_constants.dart             # Shared persistence keys, including `AppConstants.sessionTabsStateKey` (`session_tabs_state`), `sessionTabIconOverridesKey` (`session_tab_icon_overrides`), and `androidProcessDiagnosticsKey` (`android_process_diagnostics_v1`); `opencodeGoWorkspaceIdKey`/`opencodeGoAuthCookieKey` remain only as legacy OpenCode Go purge targets (issue #96)
lib/core/i18n/app_locales.dart                     # Locale registry: 14 supported locales, resolution callback, native-name metadata, PT_BR normalization
lib/core/i18n/l10n_context.dart                    # BuildContext extension: `context.l10n` shorthand for AppLocalizations access
lib/core/i18n/l10n_bridge.dart                     # Static L10nBridge for context-free localization (tray, background services)
lib/core/utils/timeline_search_service.dart         # Client-side full-text search over timeline messages: extracts TextPart.text and ReasoningPart.text, performs case-insensitive matching with occurrence counting, and returns results ordered by message age
lib/core/network/dio_client.dart                  # HTTP client config, auth, base URL updates, Tailscale adapter swap; exposes `dio` (regular) and `sseDio` (dedicated SSE instance with isolated connection pool); Tailscale transport via applyTailscaleAdapter/removeTailscaleAdapter; createHealthCheckDio propagates active adapter to ephemeral Dio instances; OAuth auth ownership via setOAuthToken/clearOAuthToken/clearAuth; Basic Auth is scoped to the exact configured origin and is restored only for that origin when OAuth is cleared; sticky OpenCode `X-Session-Id` routing — echoes the `X-Session-Id` returned by the server on later requests (cleared on base URL change and on `clearAuth`)
lib/core/network/dio_sse_adapter.dart              # Conditional export: routes to IO or stub adapter
lib/core/network/dio_sse_adapter_io.dart           # IO platforms: configures IOHttpClientAdapter with separate HttpClient for SSE (2h idle, 4 max connections)
lib/core/network/dio_sse_adapter_stub.dart         # Web platform: no-op (browser manages connections natively)
lib/core/logging/android_process_diagnostics.dart  # Bounded local Android process/error diagnostic ring; normalizes native method-channel metadata and persists a capped local record list
lib/core/tailscale/tailscale_service.dart          # Conditional export barrel: routes to IO or stub TailscaleService via `export if (dart.library.io)`; re-exports TailscaleState
lib/core/tailscale/tailscale_service_io.dart       # IO implementation: shared-identity node lifecycle (`upForProfile`/`refreshStatus`/`logout`/`down` with generation guards), state + peer broadcast via StreamControllers, wraps `tailscale` Dart package; single shared state dir with legacy per-profile adoption, stable `codewalk-<os>` hostname; `dialTcp(host, port, {timeout})` via private `_TailscaleTcpConnectionAdapter`
lib/core/tailscale/tailscale_service_stub.dart     # Non-IO platforms: TailscaleService stub (state=unsupported, hasClient=false, httpClient/down/dialTcp throw UnsupportedError) with `upForProfile`/`refreshStatus`/`logout`/`nodes`/`dialTcp` parity
lib/core/tailscale/tailscale_tcp_connection.dart     # Tailscale TCP byte-stream contract (`TailscaleTcpConnection` input/write/close/done + `TailscaleTcpDial` typedef) decoupling upper layers from `package:tailscale`
lib/core/tailscale/tailscale_state.dart            # TailscaleNodeState enum (disconnected/connecting/connected/needsLogin/needsMachineAuth/error/unsupported) + TailscaleState Equatable model with authUrl, message, isConnected, requiresUserLogin
lib/core/tailscale/tailscale_peer.dart             # TailscalePeer Equatable projection (stableId/hostName/dnsName/tailscaleIPs/online/os) with ipv4, displayLabel, and defaultUrl helpers
lib/core/tailscale/tailscale_http_adapter.dart     # Dio HttpClientAdapter bridging Tailscale's http.Client to Dio; fetch() with head-only timeout (15s fallback), bodyless EOF handling, cancelFuture, redirect policy; used by applyTailscaleAdapter to swap default transport
lib/core/logging/app_logger.dart                   # Centralized logger: global `loggingEnabled` gate (default off), `_performanceLoggingEnabled` second gate, 1000-entry in-memory buffer exposed via ValueListenable, debug/info/warn/error recording with auth/secret redaction, sanitized metric serialization, safeContextId/safePathShape helpers, **structured task tracking** via `beginTask` returning a `TaskHandle` and `runTask<T>` wrapping sync/async bodies (zone-scoped parent task linking, phase tags `phase:start`/`phase:end`, status tags, `taskId`/`parentTaskId`/`elapsedMs` metrics, end/cancel), plus `runPerformanceTask`/`measurePerformance` with **lazy `contextBuilder`** callbacks so performance context is only computed when performance logging is enabled; `installGlobalHandlers()` wires FlutterError/PlatformDispatcher error capture and resets the session clock; `setLoggingEnabled(false)` clears the buffer
lib/core/auth/oauth_service.dart                   # Conditional export barrel: re-exports oauth_service_result.dart, routes to IO or stub via `export if (dart.library.io)`
lib/core/auth/oauth_service_io.dart                # OAuthService IO implementation (desktop + Android): Cloudflare Access Managed OAuth with PKCE (S256); binds one ephemeral 127.0.0.1 HttpServer callback before DCR and reuses the exact redirect URI; desktop launches the system browser, while Android delegates authorization to MainActivity's AndroidX Custom Tab with external-browser fallback; credential caching/refresh, OAuth metadata discovery, trusted endpoint validation, strict callback validation
lib/core/auth/oauth_service_stub.dart              # Non-IO platforms: OAuthService stub (isOAuthChallenge returns false, all other methods throw "not supported on this platform")
lib/core/auth/oauth_service_result.dart            # OAuthFlowResult model: ok/token/error/needsConsent/log fields for flow completion tracking
lib/core/auth/oauth_token_storage.dart             # Secure OAuth credential persistence: OAuthTokenStorageBackend interface, FlutterSecureOAuthTokenStorageBackend (flutter_secure_storage), OAuthTokenStorage with save/load/delete/hasValidCredential, cross-profile key scoping, OAuthTokenStorageException
lib/core/auth/tts_api_key_storage.dart             # Secure per-provider cloud TTS API-key persistence using flutter_secure_storage; trims empty values and scopes keys by ReadAloudProvider
lib/core/auth/stt_api_key_storage.dart             # Secure per-provider cloud STT API-key persistence using flutter_secure_storage (backend interface + FlutterSecure backend); scopes keys by SpeechApiProvider under the `stt_api_key::` secure-storage namespace, trims empty values, empty writes delete the key, storage failures map to SttApiKeyStorageException
lib/core/auth/oauth_credential.dart                # OAuthCredential model: accessToken, refreshToken, expiresAt, isExpired/isValid check (5-min buffer), JSON serialization (fromJson/toJson)
lib/data/datasources/app_remote_datasource.dart   # App bootstrap/config/providers/agents API access; app discovery retries scoped `/provider`, `/agent`, and `/config` calls with `directory`-only and then unscoped fallbacks when workspace-scoped queries fail; `/agent` parsing tolerates multiple upstream payload shapes; scoped discovery/config calls forward both `directory` and `workspace` when a project directory is active
lib/data/datasources/chat_remote_datasource.dart  # Chat/session/message/realtime API access; accepts optional `sseDio` for SSE stream isolation; sendMessage uses polling + provider-level SSE only (no per-send SSE) to prevent server-side abort on disconnect; provider `prompt_async` sends intentionally do not forward `messageId`; async completion fallback escalates to polling and uses stricter staleness guards when no-candidate/empty-baseline scenarios occur to prevent early finalization; bounds message-list tail fetches (`limit=120`); uses bounded per-session assistant-id cache (64-session cap + invalidation on unresolved completion); handles session-scoped permission replies with legacy fallback, sends `remember: true` for `always` replies, and preserves typed upstream error names/codes/details in surfaced failures; SSE backoff loop fix — streamAliveStart enforces 5-second threshold before resetting reconnect counter, ±20% jitter to prevent thundering-herd
  └── chat_remote_datasource_helpers.dart # Command, send, error, tool, and reasoning helpers (part of chat_remote_datasource.dart; see commit 8759defc); structured named error extraction (`_extractServerMessage`, `_extractValidationErrors`, `_extractNamedServerError`, `_extractTypedDetails`) preserves typed upstream error names/codes/details in surfaced failures
lib/data/datasources/project_remote_datasource.dart # Project/worktree/file API access; file-name search (`/find/file`), file-content search (`/find?pattern=`), and workspace symbol search (`/find/symbol`)
lib/data/datasources/app_local_datasource.dart    # Persistent settings, profiles, SharedPreferences-backed caches, credentials, favorite models, session composer drafts, per-agent selection memory, and server-scoped session-tab state plus session-tab icon overrides; `clearOpenCodeGoDashboardCredentials()` performs a best-effort secure-storage `readAll()` purge of legacy OpenCode Go workspace-id/auth-cookie keys (issue #96)
  └── app_local_datasource_storage_helpers.dart # Secure storage, scoped SharedPreferences keys, and large-cache helper wrappers (part of app_local_datasource.dart)
lib/data/repositories/*.dart                      # Domain repository implementations
lib/data/datasources/quota_remote_datasource.dart # Strategy-chain quota discovery: tries OpenChamber REST (`GET /api/quota/providers`) then falls back to a hidden ephemeral shell probe (`CW_QUOTA_JSON:`) for vanilla OpenCode hosts; OpenCode Go is probed through the host's `auth.json` Bearer key (issue #96)
  └── quota_remote_datasource.part.js.dart # JS payload generation part file: shared helpers + shell probes for Claude, OpenRouter, Codex, Google, GitHub Copilot, OpenCode Go, NanoGPT, Wafer, Kimi, ZhipuAI, MiniMax, MiniMax CN, z.ai, Cursor, and Ollama Cloud; the OpenCode Go probe reads the `opencode-go` Bearer key (`key`/`access`/`token`) from the host `auth.json` and calls `GET https://opencode.ai/zen/go/v1/usage` (rolling/weekly/monthly windows, 15s abort timeout, typed error codes `authentication`/`invalid_response`/`request_failed`); the legacy workspace-id/auth-cookie dashboard flow is removed (issue #96); `_supportedAuthKeys` also recognizes newer provider aliases for diagnostics
lib/domain/usecases/*.dart                        # Application use cases consumed by providers
lib/domain/entities/quota.dart                    # Quota domain entities: `QuotaSnapshot`, `UsageWindow`, `PaceInfo`, `QuotaEntry`, `QuotaProviderGroup`; `QuotaProviderResult` carries a typed `errorCode` (e.g. `authentication`/`invalid_response`/`request_failed`) parsed from result JSON (issue #96)
lib/domain/entities/persisted_session_tabs_state.dart # Versioned persisted open/closed session-tab payload and model entities
lib/domain/entities/session_tab_icon_overrides.dart # Versioned per-session icon override entities (issue #138): `SessionTabIconOverride` (serverId/directory/sessionId/presetId/updatedAtMs with identityKey and JSON round trip) and `SessionTabIconOverridesState` (versioned payload, 256-entry per-server dedup/compaction, encode/decode, `requiresCompaction`)
lib/domain/entities/car_messaging.dart # Bounded car-messaging entities (issue #99): `CarMessagingEntry`/`CarMessagingThread`/`CarMessagingReply`/`CarMessagingState` with `CarMessagingRole` and `CarMessagingReplyState` enums, JSON round trip, normalization caps (5 threads, 8 entries/thread, 5 queued replies, 1024 scalars), and 24h/30m retention constants
lib/presentation/providers/app_provider.dart      # Server profiles, health polling, local runtime state, OAuth challenge lifecycle, Tailscale transport orchestration; supportsTailscale (Android/iOS/Linux/macOS), _applyTailscaleTransport() drives shared-identity node lifecycle (upForProfile/auth URL launch/down), swaps Dio adapter via TailscaleHttpAdapter, propagates active adapter to health-check Dio via createHealthCheckDio; single-flight authenticate/logout/transport-retry with busy getters, Custom Tab launcher with native channel fallback + auto-close on connect, setup-debug timeline entries, Tailscale-first health gating (unknown while transport pending); tailscaleEnabled in addServerProfile/updateServerProfile CRUD; exposes reactive Tailscale state getters: tailscaleState, tailscaleNodeState, tailscaleAuthUrl, tailscaleMessage, tailscaleNeedsAuth, tailscaleNeedsMachineAuth, tailscalePeers/tailscaleHasPeers, and authenticateTailscale()/refreshTailscaleStatus()/logoutTailscale()/retryTailscaleTransport()/terminalAuthHeaders(Basic-first else cached OAuth Bearer)/openTerminalSocketOverTailscale(support/connected guards + dial) methods; guards health polling/connection when no active server profile is set; includes setup-debug state (SetupDebugEntry, SetupDebugSeverity) for OpenCode installation diagnostics with recordSetupDebugEvent(), exportSetupDebugReport(), clearSetupDebugData(); OAuth challenge tracking via hasOAuthChallenge/getOAuthChallengeHeaders, handleOAuthChallenge (creates OAuthService, runs PKCE flow, sets Dio token, verifies connection), clearOAuthCredential, isOAuthAuthenticated, and oauthEnabled cache-on-activate; supportsCloudflareAccessOAuth includes desktop (macOS/Windows/Linux) and Android, gates iOS out; production health checks probe `GET /global/health` and fall back to `GET /path` on `DioException` (`_checkServerHealth` records OAuth challenges from either response); constructor accepts optional `serverHealthProbe` and `localServerHealthProbe` test seams that bypass the production endpoints when supplied; owns the `SessionTabIconOverrideStore` and removes its per-server overrides on server profile deletion
lib/presentation/providers/project_provider.dart  # Project/worktree context selection and persistence; placeholder-root guards in persistence/restore paths (`_isPlaceholderRootProject`/`_isPlaceholderRootId`, sanitize + never persist/restore synthetic Global root); exposes file-name, file-content, and workspace-symbol search for Quick Open and composer mentions; `canCloseProject(projectId)` guards destructive close when only one open context remains
lib/presentation/providers/project_icon_provider.dart # Client-owned project icon orchestration (ADR-040, issue #73): loads cached icons from `ProjectIconStore`, runs discovery via `ProjectIconDiscoveryService`, and exposes per-project `iconFor`/`isLoading`/`isDiscovering` state; `loadStoredIcon(project)` resolves cached/default icons only (used by closed project rows), `autoDiscoverIcon(project)` triggers one-shot discovery after loading stored state (used by open/active project surfaces; tracks per-key attempts via `_autoDiscoveryAttemptedKeys` to avoid repeats), and `discoverIcon(project)` is the lower-level discovery/save operation invoked by `autoDiscoverIcon(project)` and retained for provider orchestration/testing (not a UI button trigger); OpenCode project payloads remain authoritative/unchanged
lib/presentation/services/project_icon_models.dart      # Shared models for the project icon subsystem: `ProjectIconFormat` enum (png/jpeg/svg/webp/ico), metadata/data/candidate/result types, `projectIconMaxBytes` (5 MB cap), `projectIconKeyFor(Project)` stable key derivation, and helpers for ICO→PNG storage normalization
lib/presentation/services/project_icon_store.dart       # Conditional factory barrel: routes `createProjectIconStore()` to IO or stub via `if (dart.library.io)`
lib/presentation/services/project_icon_store_base.dart  # Abstract `ProjectIconStore` contract: `readIcon`, `saveIcon`, and `deleteIcon` keyed by project icon key
lib/presentation/services/project_icon_store_io.dart    # IO implementation: stores icons under the CodeWalk app-support `project_icons/` directory with `{key}.{ext}` binaries and a shared `metadata.json`; ICO candidates are persisted as PNG bytes
lib/presentation/services/project_icon_store_stub.dart  # Non-IO platforms: no-op persistence stub used when app support filesystem access is unavailable
lib/presentation/services/project_icon_discovery_service.dart       # Conditional factory barrel: routes `createProjectIconDiscoveryService()` to IO or stub via `if (dart.library.io)`
lib/presentation/services/project_icon_discovery_service_base.dart  # Abstract `ProjectIconDiscoveryService` contract: `isSupported` flag, `discover(Project)` returning `ProjectIconDiscoveryResult`; never mutates the project or any global state
lib/presentation/services/project_icon_discovery_service_io.dart    # IO implementation: bounded IO icon discovery invoked by `ProjectIconProvider` auto-discovery, with existing local/remote file endpoint discovery and priority rules — Tauri `src-tauri/icons/*`, Electron direct `build/icon.*`, Flutter/React Native/native Apple `AppIcon.appiconset/*.png`, Flutter Windows `windows/runner/resources/app_icon.ico`, Flutter Linux `linux/runner/resources/app_icon.png`, Android `mipmap-*/ic_launcher*.png`, common app assets (`icon.*`, `app_icon.*`, `logo.*`), then web favicons/sized web icons; supports PNG/JPEG/SVG/WebP/ICO, 5 MB cap, shortest relative path ranking, skips heavy/generated dirs (`.git`, `node_modules`, `dist`, `build`, `.dart_tool`, `.gradle`, `.next`, `.turbo`, `.cache`, `coverage`, `tmp`, `logs`, `pods`, `ephemeral`) while checking `build/icon.*` directly without traversing build output, and converts ICO to PNG via the `image` package
lib/presentation/services/project_icon_discovery_service_stub.dart  # Non-IO platforms: returns `unsupportedPlatform`; `isSupported == false`
lib/presentation/providers/settings_provider.dart # Experience settings, theme mode, dynamic color, AMOLED dark toggle, brand seed, contrast, **Visual style**, nullable session-tab visibility override with platform/web defaults, provider-aware read-aloud settings (provider, voice id/locale, model, base URL, response format), cloud API STT settings (speechApiProvider/speechApiBaseUrl/speechApiModel with setSpeechApiProvider/setSpeechApiBaseUrl/setSpeechApiModel mutators), session-attention presentation/host lifecycle, fresh-install read-aloud defaults via nativeReadAloudAvailabilityProbe, composer tips visibility, sounds, update checks, complete OpenCode shared settings coverage, and debug logging toggles; exposes `dynamicColorAvailable`; manages update install lifecycle and logging preference sync
  └── settings_provider_opencode_defaults.dart # Extension for OpenCode shared defaults (part of settings_provider.dart; see commit 8759defc)
  └── settings_provider_update_install.dart # Extension for update check and install lifecycle (part of settings_provider.dart; see commit 8759defc)
lib/presentation/providers/quota_provider.dart # Host-discovered quota state: polls `QuotaRemoteDataSource`, TTL-based cache (60s) scoped per `serverId`, normalises raw data into `QuotaProviderGroup` list ordered by severity; `ensureLoaded()` for lazy UI-triggered fetch; Codex single-window label preserved using provider name instead of raw API label (guarded by `result.providerId != 'codex'`); exposes `hasOpenCodeGoFailure`/`openCodeGoErrorCode` from the OpenCode Go result and runs a one-shot best-effort `clearOpenCodeGoDashboardCredentials()` purge of legacy dashboard secrets before fetching (issue #96)
lib/presentation/utils/quota_pace_utils.dart # Pure Dart pace helpers: `predictedFinalPercent`, `PaceStatus` enum, window/label inference, and formatted `Pace xx%` / time-left strings
lib/presentation/widgets/settings_provenance_chip.dart # Shared provenance badge widget for `OpenCode-backed`, `CodeWalk-local`, and `CodeWalk exception` labels used by Behavior, Notifications, and Shortcuts settings surfaces
lib/presentation/widgets/settings_update_available_card.dart # Shared CodeWalk update card for Settings landing and About; renders installed/latest version info, release notes when requested, install/progress/retry controls, release-link fallback, and dismiss action
lib/presentation/widgets/searchable_dropdown_form_field.dart # Reusable FormField<T> searchable dropdown with modal bottom sheet picker; used by servers, speech, notifications, appearance, and behavior settings sections
lib/presentation/theme/opencode_web_theme_registry.dart # Generated local mirror of the official OpenCode Web built-in theme registry with 37 theme definitions (light/dark palette + overrides); regenerate via `tool/theme/generate_opencode_web_themes.py`
lib/presentation/theme/opencode_theme_presets.dart     # Theme registry bridge from OpenCode Web ids to Flutter `ColorScheme` plus `OpenCodeThemeTokens` ThemeExtension for markdown and syntax-aware surfaces
lib/presentation/theme/opencode_highlight_theme.dart   # Converts active `OpenCodeThemeTokens` into `flutter_highlight` TextStyle maps for chat code fences and the file viewer
lib/presentation/theme/brand_colors.dart              # BrandColor enum with 5 seed colors for non-dynamic-color themes
lib/presentation/theme/app_shapes.dart                # AppShapes class with centralized MD3 shape constants
lib/presentation/theme/app_theme.dart                 # Material You theme builder using AppShapes, color scheme, and `AppVisualStyleTokens` (issue #86); `lightFrom`/`darkFrom` accept an optional `visualStyle` parameter that defaults to `VisualStyle.classic` at the API level (so callers that omit it get classic), and runtime `main.dart` always passes `settingsProvider.visualStyle` to ensure the user-selected style wins; the chosen style is forwarded to `_buildTheme` which mounts `AppVisualStyleTokens.classic` or `AppVisualStyleTokens.refined` into the theme extensions alongside caller-supplied `OpenCodeThemeTokens`; `withResponsiveSnackBars` derives the snackbar shape from `theme.visualStyleTokens.controlRadius` when refined (and falls back to `AppShapes.borderLarge` when classic); also houses AppDensitySpacing (density-aware spacing for chrome/composer)
lib/presentation/theme/app_animations.dart            # Animation duration tokens; includes userBubble (130 ms) and assistantBubble (180 ms)
lib/presentation/theme/app_visual_style_tokens.dart   # `AppVisualStyleTokens` `ThemeExtension` for issue #86: surface colors (card/panel/composer/muted control/selected/separator/focus border/soft shadow), radius tokens (card/control/panel/dialog/bubble + `bubbleTightCornerRadius`), border widths, divider thickness, and `composerShadow`; `classic`/`refined` factories plus `copyWith`/`lerp`; `ThemeData.visualStyleTokens` extension getter (falls back to `AppVisualStyleTokens.classic` when no extension is registered)
lib/presentation/utils/window_size_class.dart         # WindowSizeClass enum with MD3 breakpoints + BuildContext extension
lib/presentation/utils/diff_parser.dart # Diff parser: DiffHunk model, groupIntoHunks(), annotateLineNumbers(), resolveDiffHighlightLanguage(), kDefaultCollapseThreshold
lib/presentation/utils/file_path_detector.dart # Regex-based file path detector: ~90 known extensions, :line:col suffix parsing, code-block exclusion, URL exclusion, Windows absolute paths
lib/presentation/utils/file_path_markdown.dart # Custom flutter_markdown_plus InlineSyntax (FilePathSyntax) and MarkdownElementBuilder (FilePathBuilder) for clickable file path spans
lib/presentation/utils/math_markdown.dart # Custom markdown syntaxes (InlineMathSyntax, BlockMathSyntax, SingleLineBlockMathSyntax) and builders (InlineMathBuilder, BlockMathBuilder) for `$...$` and `$$...$$` LaTeX math expressions
lib/presentation/utils/windows_settings_links.dart # URI helper class for Windows system settings links (microphone, speech privacy, speech settings)
lib/presentation/services/desktop_tray_service_io.dart # Desktop tray lifecycle; selects tray icon per OS (macOS template PNG, Windows ICO, Linux PNG)
lib/presentation/services/notification_service.dart    # Local notifications; Android uses `@drawable/ic_stat_codewalk` small icon and no longer drives foreground monitor state; exposes `clearNotificationsForSession()` for per-session notification dismissal
lib/presentation/services/event_feedback_dispatcher.dart  # Routes chat events to notification + sound feedback; includes `dismissForSession()` for reactive foreground notification cleanup when permissions/questions are resolved or sessions become idle
lib/presentation/services/android_foreground_monitor_service.dart # Android foreground service via MethodChannel; active only during temporary live monitoring for known background work
lib/presentation/services/android_background_alert_worker.dart # WorkManager-based background polling; 3m active probes, 5m tail probe, and low-data title-cached notification fetches; includes `removeNotifiedRequestIds()` static method to clear replied permission/question IDs from the persisted background snapshot; also dispatches car-messaging reply work (`carMessagingReplyTaskName`) through `CarMessagingDispatchWorker` and teardown via `CarMessagingRuntime` (issue #99)
lib/presentation/services/android_background_alert_logic.dart # Pure logic for tail probe scheduling, alert planning, and snapshot state
lib/presentation/services/android_battery_optimization_service.dart # Android battery optimization query/exemption request via MethodChannel
lib/presentation/services/permission_auto_approve_runtime.dart # Background permission auto-approve context and session ID resolution for Android background continuity
lib/presentation/services/car_messaging/car_messaging_notification.dart # Android Auto `MessagingStyle` notification spec builder, category/action constants, and identity-derived id/tag helpers
lib/presentation/services/car_messaging/car_messaging_action_handler.dart # Car reply/mark-read notification action handler with background response entrypoint and Workmanager reply-task scheduling
lib/presentation/services/car_messaging/car_messaging_dispatch_worker.dart # Queued car-reply dispatch to the server (`prompt_async`), completion publishing, and failure marking
lib/presentation/services/car_messaging/car_messaging_gate.dart # Pure background gate predicates: background-alert master switch, Data Saver pause, and server-profile eligibility (no debug/feature/preference gates)
lib/presentation/services/car_messaging/car_messaging_runtime.dart # Runtime teardown orchestration: notification cancellation, store clear, server/identity removal, and pending reply-work cancellation
lib/presentation/services/read_aloud_service.dart                # ReadAloudService: provider-routed read-aloud facade; exposes isProviderAvailable for runtime native TTS probes; generated-audio backends (including Edge experimental, ElevenLabs, and NVIDIA NIM) are routed through byte playback; loads per-provider secure cloud TTS API keys when needed; tracks idle/loading/playing/paused state and per-message playback
lib/presentation/services/tts/tts_backend.dart                   # TTS backend contract, request/result models, generated-audio result, voice metadata, normalized backend error kinds, and provider-aware `getVoices({apiKey, baseUrl, model})` configuration
lib/presentation/services/tts/tts_executor.dart                 # Provider backend selection, secure cloud-key lookup, serialized stop handling, and stale speech-job protection
lib/presentation/services/tts/native_tts_backend.dart            # Native flutter_tts backend with voice/language lookup and platform speech callbacks
lib/presentation/services/tts/read_aloud_default_resolver.dart   # Fresh-install read-aloud defaults: Linux selects Edge experimental; other platforms select native when runtime probe succeeds, otherwise Edge with locale-mapped voice
lib/presentation/services/tts/generated_tts_audio_player.dart    # audioplayers-backed byte playback adapter for generated cloud TTS audio
lib/presentation/services/tts/openai_compatible_tts_backend.dart # OpenAI-compatible `/audio/speech` backend with model/voice/base URL/format options and Dio error mapping
lib/presentation/services/tts/edge_experimental_tts_backend.dart # Experimental Microsoft Edge/Bing Read Aloud backend; user-selectable and used by fresh-install defaults when native TTS is unavailable; discovers voices, performs direct websocket synthesis, and returns generated MP3 audio bytes
lib/presentation/services/tts/elevenlabs_tts_backend.dart        # ElevenLabs cloud TTS backend; API-key voice discovery, model/base-URL synthesis, generated MP3 audio, character limits, and Dio error mapping
lib/presentation/services/tts/nvidia_nim_tts_backend.dart        # NVIDIA Speech NIM cloud TTS backend; API-key/base-URL voice discovery, model/language synthesis, generated WAV audio, character limits, and Dio error mapping
lib/presentation/services/tts/edge_tts_protocol.dart             # Edge/Bing Read Aloud protocol helpers for signed URLs, browser headers, SSML, frame parsing, voice catalog parsing, limits, and MP3 MIME/format constants
lib/presentation/services/tts/edge_tts_websocket.dart            # Conditional websocket abstraction used by the Edge backend
lib/presentation/services/tts/edge_tts_websocket_io.dart         # Native websocket transport using `dart:io` upgrade headers compatible with Edge/Bing Read Aloud
lib/presentation/services/tts/edge_tts_websocket_stub.dart       # Non-IO websocket transport using `web_socket_channel`
lib/presentation/services/tts/read_aloud_text_extractor.dart     # Assistant-message text extractor and Markdown sanitizer used before sending text to read-aloud providers
lib/presentation/services/session_export_service.dart # SessionExportService: serializes session history to Markdown and JSON for local export; omits local_user_* IDs from JSON per ADR-023
lib/presentation/services/session_tab_icon_override_store.dart # Per-server `SessionTabIconOverrideStore`: serialized load/save/delete of icon overrides via `AppLocalDataSource` with a per-server write queue (`_serialize`); `setPreset`/`removeIdentity`/`removeDirectory`/`removeServer` mutations with dedup + compaction, removed-server tombstoning, and `drain()` for test sync
lib/presentation/services/session_tab_icon_presets.dart # `SessionTabIconPreset` enum (12 Material Symbols presets with stable ids: code/terminal/bug/tasks/launch/idea/research/design/data/cloud/security/tools) plus `sessionTabIconPresetLabel(l10n, preset)` localized labels
lib/domain/entities/session_attention_overlay/session_attention_models.dart # Session-attention identity, priority, transport, aggregate, and durable snapshot payload models
lib/data/session_attention/session_attention_snapshot_store.dart # AES-GCM encrypted session-completion snapshot persistence with secure key storage and dismissal tombstones
lib/data/session_attention/session_attention_snapshot_file_store*.dart # Conditional atomic application-support file store (IO) and unsupported-platform stub
lib/data/car_messaging/car_messaging_store.dart # Encrypted car-messaging state store (issue #99): AES-GCM envelope with secure key storage, serialized access, thread/reply bounds, and retention pruning
lib/data/car_messaging/car_messaging_file_store*.dart # Conditional atomic application-support file store (IO with exclusive lock file, stale-lock recovery, atomic write) and unsupported-platform stub
lib/presentation/services/session_attention/session_attention_coordinator.dart # Tracks attention timing and monitoring availability
lib/presentation/services/session_attention/session_attention_completion_resolver.dart # Resolves completed root-session output into encrypted snapshots and publishes changes
lib/presentation/services/session_attention/session_attention_host_contract.dart # Cross-platform host capability and lifecycle contract
lib/presentation/services/session_attention/session_attention_host_protocol.dart # Versioned host snapshot and command protocol
lib/presentation/services/session_attention/session_attention_host_service*.dart # Conditional Android, desktop child-window, iOS in-app, and unsupported host implementation selection
lib/presentation/services/session_attention/session_overlay_entrypoint.dart # Flutter entrypoints and IPC bridge for desktop child and Android service hosts; constructs the overlay ReadAloudService with the complete native/cloud TTS backend registry
android/app/src/main/kotlin/com/verseles/codewalk/MainActivity.kt # Android system/platform channel host with process-diagnostic method-channel query; native OAuth launch via AndroidX Custom Tabs with ACTION_VIEW fallback; Tailscale auth via `launchTailscaleAuthorization` (Custom Tab with external-browser fallback) + `closeTailscaleTab` task-fronting close signal
android/app/src/main/res/xml/automotive_app_desc.xml # Automotive notification descriptor declaring `<uses name="notification"/>`, shipped in every release APK (issue #99)
lib/presentation/widgets/session_attention_overlay/session_attention_overlay.dart # Shared bubble/panel attention presentation
lib/presentation/widgets/session_attention_overlay/session_attention_overlay_controller.dart # In-app snapshot, read-aloud, and action controller used by ChatPage on iOS
lib/presentation/services/workspace_file_operations_service.dart # WorkspaceFileOperationsService (issues #89/#90): shell-gated `createFolder`/`createFile`/`rename`/`delete`/`writeFile` with capability probe and ephemeral `/session` lifecycle; server-bound cancellation/failure aborts the active remote operation before session teardown rather than only dropping the local wait; parses shell responses with the official OpenCode tool-state parser; `writeFile` transports UTF-8 content as 48 KiB environment chunks and uses a negotiated GNU/BSD/Python decoder pipeline to stage an atomic mode-preserving replacement; operation logs are privacy-safe; capabilities are cache-scoped per `serverScopeKey::directory`
lib/presentation/services/message_image_export_service.dart # MessageImageExportService: captures a RepaintBoundary widget as a PNG and invokes the platform share sheet; MessageImageExportResult enum (shared, tooTall, notLaidOut, failed); uses RenderRepaintBoundary.toImage() with _capturePixelRatio=2.5, capped at _maxCaptureHeight=4096 logical px
lib/presentation/services/moonshine_model_manager_io.dart # Desktop Moonshine model download/extract/delete flow using sherpa-onnx release archives + Silero VAD asset
lib/presentation/services/speech_input_service_moonshine_io.dart # Desktop Moonshine dictation backend; uses sherpa_onnx OfflineRecognizer + VoiceActivityDetector for on-device utterance recognition; consumes `SpeechAudioCapture`
lib/presentation/services/speech_input_service_stt.dart # STT abstraction backend (speech_to_text package) for iOS, macOS, Web, and supported native targets; Windows returns unavailable before touching speech_to_text_windows and exposes `unavailableReasonKey` for settings routing
lib/presentation/services/speech_input_service_api.dart # Cloud API STT backend (issue #97): OpenAI, Groq, or custom OpenAI-compatible `/audio/transcriptions` endpoint via Dio; encodes captured PCM16 as WAV (16 kHz mono, 2-minute max, configured 2–10 s silence stop, 500-threshold speech detection), loads the API key through `SttApiKeyStorage` (Bearer auth; optional for custom endpoints), sends the app locale as transcription hint, and emits stable unavailable-reason keys (`webUnavailable`/`apiConfigInvalid`/`apiKeyStorageUnavailable`/`apiKeyMissing`/`microphoneDenied`) plus typed provider failure reasons (`apiRequestInvalid`/`apiRateLimited`/`apiUnavailable`/`apiNetwork`/`apiInvalidResponse`/`emptyAudio`/`emptyTranscript`); session-epoch lifecycle (`cancelListening`/`cancelSession`/restart) prevents stale sessions from replacing active callbacks; `configure()` is called per start with provider/base URL/model
lib/presentation/services/speech_audio_capture.dart # Platform-neutral audio capture and recording lifecycle cleanup; prevents AudioRecorder leaks; Windows branch routes through `WindowsMicrophoneService` (runner-owned WASAPI bridge in `windows/runner/windows_microphone_plugin.{h,cpp}`) to avoid the record_windows MediaFoundation crash
lib/presentation/services/windows_microphone_service.dart # Dart-side bridge to the runner-owned WASAPI microphone plugin (`WindowsMicrophoneService.probe()` + `pcmStream()` + `stopStream()`); provides Windows microphone access probe and preflight status used by both `SpeechAudioCapture` and the speech settings preflight
lib/presentation/services/speech_input_service_parakeet.dart # Conditional export: routes to IO or stub Parakeet STT adapter
lib/presentation/services/speech_input_service_parakeet_io.dart # Desktop Parakeet STT backend; NeMo transducer for on-device transcription; consumes `SpeechAudioCapture`
lib/presentation/services/speech_input_service_parakeet_stub.dart # Non-IO platforms: no-op Parakeet stub
lib/presentation/services/parakeet_model_manager.dart # Conditional export: routes to IO or stub Parakeet model manager
lib/presentation/services/parakeet_model_manager_io.dart # Desktop Parakeet model download/extract/delete flow using NeMo release archives
lib/presentation/services/parakeet_model_manager_stub.dart # Non-IO platforms: disabled Parakeet model manager
lib/presentation/widgets/parakeet_model_download_dialog.dart # Parakeet model download/setup dialog shown when Parakeet is selected without a downloaded model
lib/presentation/services/speech_input_service_sensevoice.dart # Conditional export: routes to IO or stub SenseVoice STT adapter
lib/presentation/services/speech_input_service_sensevoice_io.dart # Desktop SenseVoice STT backend; sherpa_onnx offline recognizer for on-device transcription (strongest option for CJK + English); consumes `SpeechAudioCapture`
lib/presentation/services/speech_input_service_sensevoice_stub.dart # Non-IO platforms: no-op SenseVoice stub
lib/presentation/services/sensevoice_model_manager.dart # Conditional export: routes to IO or stub SenseVoice model manager
lib/presentation/services/sensevoice_model_manager_io.dart # Desktop SenseVoice model download/extract/delete flow using sherpa_onnx archives
lib/presentation/services/sensevoice_model_manager_stub.dart # Non-IO platforms: disabled SenseVoice model manager
lib/presentation/widgets/sensevoice_model_download_dialog.dart # SenseVoice model download/setup dialog shown when SenseVoice is selected without a downloaded model
lib/presentation/providers/chat_provider.dart     # SessionActionTarget-aware chat state/realtime/session facade; supports SessionActionTarget for inactive-tab scoped mutations and snapshot updates (issues #162/#163), cache-first per-session SWR restore, in-memory LRU message cache, persisted per-session snapshots, microtask coalescing, event dedup buffer, render gate, favorite models; drives timeline visibility, undo/redo availability, rejected-draft restoration, persisted per-session composer drafts, and per-agent provider/model/variant memory; project-switch SWR support via `onProjectScopeChanged(waitForRevalidation: false)` and `loadSessions(backgroundRevalidation: true)`; non-active contexts marked dirty by global events keep cache for immediate restore-on-return, while background revalidation refreshes state; active-session SWR uses limited-tail (delta-like) refresh with overlap merge and full-fetch fallback; message merge / refresh behavior has regression coverage protecting active tool/work visibility during optimistic echo replay and refresh/reconcile; includes `loadOlderMessages()` scaffold and keeps loadSessionInsights fire-and-forget on session switch; idle final-message reconcile can bypass abort-suppression only for targeted `session-idle-final-reconcile`; New Chat uses draft-first flow (`beginNewChatDraft`) with lazy session bootstrap on first send, and draft state is now context-scoped inside `_ChatContextSnapshot` to prevent cross-project leakage during fast switches; keeps provider-side optimistic user IDs on the local `local_user_*` contract for `prompt_async` sends and rejects them in `revertToTurn`; exposes guarded historical revert via `_historyRevertInFlight`; includes cross-scope helpers `visibleSessionsForScopeId` and `hasSnapshotForScopeId`; session-attention state (active + pending interaction + error + unread completion, scope-aware via `sessionAttentionFor` for the active context and `sessionAttentionForScope` for inactive snapshots) and active-response helpers live in `chat_provider_session_attention_ops.dart`; per-message local delta version counter (`_messageLocalDeltaVersionById`, LRU cap `_maxMessageLocalDeltaVersions`) backs monotonic fallback guards; `_scheduleDeltaNotification` (16 ms debounce via `_deltaNotifyDebounce`) batches `message.part.delta` rebuilds and `_flushDeltaNotification` drains on terminal events
lib/presentation/pages/onboarding_wizard_page.dart # 3-step onboarding wizard (Welcome, Server Setup, Ready); server form orders transport/auth toggles first (Tailscale, OAuth, Basic Auth) before URL/label fields; uses ServerSetupQuickGuide; includes a Tailscale toggle (`_tailscaleEnabled`), peer dropdown (`_buildTailscalePeerDropdown()`), and Tailscale auth panel (`_buildTailscaleAuthPanel()`) rendering per-state UI (needsLogin → auth button, needsMachineAuth → admin approval message, connected → success, error → retry) with busy guards; includes navigation to OpenCodeSetupDebugPage for troubleshooting; failure state (Step 2 when health check fails) keeps the user unblocked by exposing four recovery actions — degraded continue (`_continueWithSavedServer()` activates the saved server via `AppProvider.setActiveServer(blockUnhealthy: false)`), open server settings (`_openServerSettings()` → `ServerSettingsPage`), add another server (`_addAnotherServerAfterFailure()` resets the form and returns to Step 1), and setup debug (`_openSetupDebugPage()` → `OpenCodeSetupDebugPage`); each non-continue action records a setup debug event for diagnostics
lib/presentation/pages/opencode_setup_debug_page.dart # OpenCode setup debug surface for installation/diagnostics troubleshooting; displays environment report, setup timeline, captured logs, and exportable debug report
lib/presentation/pages/settings/sections/servers_settings_section.dart # Server profile CRUD; exports reusable ServerSetupQuickGuide widget; includes a Tailscale status card (`_buildTailscaleStatusCard()`) within the active-server details area, showing connection state with authenticate/retry/copy-login-URL actions (busy guards) and confirmed logout via `logoutTailscale()`; includes navigation to OpenCodeSetupDebugPage
lib/presentation/pages/settings/sections/speech_settings_section.dart # Speech-to-text settings UI only: STT engine/model controls, offline model management, silence timeout, and cloud STT API configuration with per-provider API-key management through `SttApiKeyStorage` (saved/removed/unavailable status)
lib/presentation/pages/settings/sections/text_to_speech_settings_section.dart # Read-aloud/Text-to-speech settings UI: native, Edge experimental, OpenAI-compatible, ElevenLabs, and NVIDIA NIM provider selection; secure per-provider API-key entry through `TtsApiKeyStorage`; remote voice/model discovery and pickers, custom model, speed/pitch controls, persisted voice-test phrase, and guarded automatic tests on discrete voice/model selection or model submission
lib/presentation/pages/settings/widgets/settings_section_layout.dart # Shared settings section layout (issue #102): `SettingsSectionIntro` (section title + description header with compact-layout title hiding) and semantic `SettingsGroupHeader` (semantics header for grouped option rows); used by settings sections
lib/presentation/pages/chat_page.dart             # Chat UI orchestration facade; WindowListener for desktop lifecycle; app/window lifecycle changes keep ReadAloudService playback untouched; guards startup (checkConnection/loadSessions) against no-active-server; holds scroll state (follow mode, current scroll owner, viewport restore targets); holds tool-chain expanded state map; _isSessionSwitchInFlight guard, _sessionCollapseHistoryCache / _sessionCollapseWorkCache per-session collapse maps; top-reach history loading is coordinated with anchor-preserving restore; workspace controller uses fast project-scope switch path; desktop chat body uses scoped Selector/Selector2 build keys (chat content, session panel, file pane, utility pane, composer controls) so composer selection changes skip full shell rebuilds; `_ChatPageState` constants gate scroll/FAB/final-reveal behavior — `_olderMessagesTopLoadThreshold` (72), `_olderMessagesTopLoadArmThreshold` (220), `_jumpToFirstFabThreshold` (360), `_scrollToBottomEpsilon` (1 px), `_maxScrollToBottomPasses` (3), `_scrollToBottomFirstPassDuration`/`_scrollToBottomNextPassDuration` (both `Duration.zero` for instant layout-anchor follow); final-assistant reveal constants `_finalAssistantRevealDuration` (220 ms), `_finalAssistantRevealAlignment` (0.4), `_maxFinalAssistantRevealAttempts` (8), `_returnLatestRevealAlignment` (0.0), `_maxReturnLatestRevealAttempts` (8); viewport helper `_isLatestAssistantMessageVisibleInViewport` resolves latest revealable assistant via reveal measurement/anchor keys and viewport geometry
  └── chat_page_local_models_part.dart # Local UI state classes (part of chat_page.dart; see commit 8759defc)
  └── chat_page/chat_page_session_tabs.dart # ChatPage extension for cross-project activation, rollback after failed navigation, and close fallback handling
  └── chat_page/chat_page_widgets.dart # UI components part of chat_page.dart: _ComposerStatusLanternText, _ComposerStatusLanternTextState, _DirectoryPickerSheet, _DirectoryPickerSheetState
lib/presentation/widgets/chat_input_widget.dart   # Composer/input orchestration facade; accepts appDensity parameter for density-aware spacing; speech controller resolves Native, Sherpa, Moonshine, Parakeet, SenseVoice, and cloud API backends and routes model-required setup dialogs accordingly; the API backend resolves its own lazy `ApiSpeechInputService` instance from the DI factory (per-composer isolation, issue #97) and disposes it via `cancelSession()`; consumes `theme.visualStyleTokens` (issue #86) for composer surface/control radius/border tokens
lib/presentation/widgets/chat_message_widget.dart # Message bubble with build-skip cache, cached MarkdownStyleSheet, provider-aware sanitized read-aloud controls with loading and pause/resume/stop states and Settings > Text to speech long-press routing, compact collapsed-copy variants, task navigation callbacks, inline undo/revert, clickable file paths, and Mermaid routing; consumes `theme.visualStyleTokens` (issue #86)
lib/presentation/widgets/mermaid_diagram_widget.dart # Renders ```mermaid fenced code blocks as visual diagrams via flutter_mermaid; copy-source button; styled source fallback on parse error via errorBuilder; horizontal scroll only (no vertical scroll); responsive layout
lib/presentation/widgets/math_expression_widget.dart # Renders `$...$` and `$$...$$` LaTeX math via flutter_math_fork with styled raw-source fallback on parse failure; inline and block display modes
lib/presentation/widgets/project_icon.dart # `ProjectIcon` widget renders cached `ProjectIconData` (PNG/JPEG/WebP via `Image.memory`, SVG via `flutter_svg`, ICO normalized to PNG) without recoloring stored artwork; falls back to tinted `Symbols.folder_open` when no icon is cached or rendering fails. `autoDiscover` flag (default `false`) opts open/active project surfaces into `ProjectIconProvider.autoDiscoverIcon` on mount/update via `addPostFrameCallback`; closed project rows leave it off and keep their stored/default icons until reopened
lib/presentation/widgets/session_diff_viewer.dart # Rich diff review surface: DiffViewMode enum (summary/unified/split), 3 view toggles, line number gutters, per-line syntax highlighting, lazy hunk collapse/expand keyed by file/hunk identity, selected-file preservation across diff refreshes, onFileTap jump action (wired at all 3 call sites)
lib/presentation/widgets/session_todo_list_widget.dart # Session task panel with progress bar and keyboard-aware collapse; compact mobile collapsed summaries use count-first wording (`x/y in progress`, `x/y done`)
lib/presentation/widgets/session_context_menu.dart # Shared session popup/context menu entries, row gesture wrapper, and dispatch helpers for main sidebar sessions and Recent sessions tiles; exposes SessionMenuAction enum and buildUnifiedSessionMenuEntries for unified tab/session menus (issues #162/#163)
lib/presentation/widgets/project_context_menu.dart # ProjectContextMenuRegion with right-click, long-press, ContextMenu key, Shift+F10, semantics and destructive Close project (issues #162/#163)
lib/presentation/widgets/session_tab_strip.dart # Responsive full-width session-tab strip with project icons, attention and busy visuals, horizontal overflow, selected-tab focus, and semantics; renders per-tab icon presets (issue #138) via `SessionTabIconPreset.fromId` with localized tooltips
lib/presentation/widgets/session_tab_icon_picker.dart # `showSessionTabIconPicker` dialog (fullscreen on compact layouts, AlertDialog on wide) returning `SessionTabIconSelection`; grid offers the project icon (via `ProjectIcon`, `autoDiscover: false`) plus the 12 `SessionTabIconPreset` tiles
lib/presentation/widgets/sidebar_selection_indicator.dart # Thin primary accent indicator reused by selected sidebar rows without painting row-wide backgrounds
lib/presentation/widgets/file_tree_context_menu.dart # Desktop secondary-click / mobile long-press context menu region (`FileTreeContextMenuActionType` newFile/newFolder/rename/delete/copyPath/refresh) wrapping `showMenu` with overlay-relative positioning; `fileTreeActionIcon` maps actions to Material Symbols (note_add/create_new_folder/drive_file_rename_outline/delete/content_copy/refresh_rounded); destructive styling on `delete`
lib/presentation/widgets/chat_session_list.dart    # Chat session list widget; responsive vertical tile padding, shared session context menu, transparent selected-row accent affordance; consumes `Theme.of(context).visualStyleTokens` (issue #86) for refined surfaces and rounded tile radius
lib/presentation/widgets/message_entrance_animation.dart # Entrance animation wrapper; `role` parameter selects user (130 ms) or assistant (180 ms) motion profile from AppAnimations
lib/presentation/widgets/chat_tour_showcase.dart   # Shared showcase wrapper for the first-use chat tour; provides MD3-compliant tooltip styling with consistent surface, shape, and action hierarchy using `showcaseview` package
lib/presentation/widgets/modal_primary_action_shortcuts.dart # Reusable keyboard shortcut wrapper for modal dialogs; maps Enter/NumpadEnter to a configurable primary action; used by model download dialogs, onboarding wizard, workspace controller, and session list
lib/presentation/widgets/quota/quota_popup_section.dart      # Root quota section embedded at the bottom of the Context usage popup; silent no-op when no data is available; renders `_OpenCodeGoFailureCard` (key `opencode-go-quota-failure-card`) mapping the typed errorCode to localized failure copy when OpenCode Go is configured but has no visible data; the legacy workspace/cookie connect-dashboard UI is removed (issue #96)
lib/presentation/widgets/quota/quota_provider_group_row.dart # Expandable provider-group row showing critical entry bar + Pace chip; Codex-specific rendering branch (`providerId == 'codex'`) renders provider name header + iterates all entries (defensive iteration) and defaults to expanded state via initState/didUpdateWidget
lib/presentation/widgets/quota/quota_entry_row.dart          # Individual quota entry: label, severity-colored progress bar, remaining/limit figures
lib/presentation/widgets/quota/pace_label.dart               # Pace % chip: desktop tooltip, mobile snackbar explanation
```

## Chat Architecture

### Orchestrators / Facades

```text
lib/presentation/pages/chat_page.dart
lib/presentation/pages/chat_page_types_part.dart   # Shared intents, configurations, and keys including `_ViewportBuildKey`, `_AssistantWorkCompactionDecision`, and scoped desktop Selector/Selector2 build-key typedefs so composer selection changes skip full ChatProvider rebuilds
lib/presentation/pages/chat_page_local_models_part.dart # Local UI state classes (part of chat_page.dart; see commit 8759defc); `_FileExplorerContextState` carries `WorkspaceFileOperationsCapabilities?` plus `fileOperationCapabilitiesLoading` flag and `fileOperationCapabilitiesLoad` Future (issue #90), `rootDirectory`, `directoryChildren`, `expandedDirectories`, `loadingDirectories`, `directoryErrors`, `tabsByPath`, `editorDraftsByPath` (issue #90), `FileTabSelectionState`, line-selection maps (`selectedLinesByPath`, `lastSelectedLineByPath`), `pendingScrollToLine`, `rootLoadScheduled`, and `treeError`; `_FileEditorDraftState` (issue #90) wraps a per-path `CodeLineEditingController.fromText` (built with `CodeLineOptions(lineBreak: ...)` so the original LF / CRLF / CR line-break style is preserved via `_detectTextLineBreak`) + `CodeScrollController`, tracks `savedContent`, `isSaving`, `saveErrorMessage`, exposes `isDirty`, and provides `markSavedContent`/`replaceSavedContent`/`dispose`; `resetForRoot(nextRootDirectory)` clears capabilities + tab selection + drafts on context switch (issues #89 and #90)
lib/presentation/providers/chat_provider.dart        # ChatProvider facade and owner of session-tab state, per-session icon overrides (issue #138), SessionActionTarget-scoped inactive-tab mutations via chat_provider_target_ops.dart (issues #162/#163), persistence orchestration, coalesced foreground-resume reconciliation, and disposal-safe realtime lifecycle
lib/presentation/widgets/chat_input_widget.dart
```

### `lib/presentation/pages/chat_page/` clusters (current, 26 files)

```text
chat_page_lifecycle.dart                           # App/window lifecycle, foreground policy, coalesced resume refresh with visible-state-preserving viewport restoration, background permission context, and file-editor autosave lifecycle handoff; coordinates pending per-path save work on lifecycle/close without owning the editor timer or save transport; does not stop read-aloud on lifecycle state changes
chat_page_scroll_coordinator.dart                  # Unified scroll ownership via `_ScrollOwner` enum (none, userDrag, paginationRestore, newMessage, streaming, returnReveal, contentShrinkSnap, searchResult); handles top-scroll older-history trigger and viewport anchor restoration; gates programmatic scrolls against user drag priority; `_loadOlderMessagesAndRestoreAnchor` settles prepend extent with `endOfFrame` plus a follow-up `Future.microtask` so the second sliver/layout pass is observed, then computes the final extent delta and `jumpTo` to keep the visible anchor stable (double-extent restore)
chat_page_workspace_controller.dart          # Project scope workspace controller with pre-clean and final sweep for close (issues #162/#163): ` _closeProjectContext` pre-cleans session tabs before `closeProject` and final-sweeps after to avoid snapshot races
chat_page_shortcuts.dart
chat_page_status_presenter.dart                    # Simplified active-server status presentation (`Online` / `Delayed` / `Offline`) and context-usage controls; consumes `theme.visualStyleTokens` (issue #86)
chat_page_selector_flow.dart               # ConstrainedBox wrapped in Flexible to prevent overflow at medium breakpoint
chat_page_scaffold.dart                          # Session selection reordered to close-first; _handleSessionSwitch() guard prevents concurrent switches; conversations sidebar renders transparent project/recent/session sections with shared selected-row accent affordance; Recent sessions tiles expose the shared session context menu; applies compact desktop spacing and passes responsive row spacing to ChatSessionList; session panel and utility pane are guarded by scoped Selector/Selector2 build keys so selection-only changes skip desktop shell rebuilds; consumes `Theme.of(context).visualStyleTokens` (issue #86)
chat_page_file_explorer_controller.dart        # File explorer plus Quick Open; supports Names and Contents modes backed by `/find/file` and `/find?pattern=`; desktop file pane wrapped in a scoped Selector build key so composer selection changes skip file-tree rebuilds; file explorer header exposes a forced-refresh refresh button, a Quick Open search button, and a New menu (`file_tree_new_button` => New File / New Folder) gated by `_fileMutationsSupported` (issue #89); `_resolveFileContextState` triggers `_ensureFileOperationCapabilities` to probe the shell-gated service and waits for directory loads before allowing header-driven New actions; root loading uses `_rootTreeCacheKey` with forced refresh on diff invalidation
chat_page_file_viewer.dart                       # File editor surface (issue #90): renders an `re_editor` `CodeEditor` with `re_highlight` language modes and per-file `CodeHighlightTheme`; binds edits to the per-path draft/autosave coordinator, whose debounce timer is canceled or handed off by close/lifecycle paths; manual Save and Ctrl/Cmd+S share the same active-save guard; retains dirty/in-flight close protection, read-only gating (`_editorReadOnlyReason`) for files exceeding `_maxEditableFileLength` (64 KiB UTF-8) or when shell file ops are unavailable/loading, inline save error banner, open-file scroll-to-line handling via `pendingScrollToLine`, and a clickable gutter (`file_editor_gutter_{path}`) with `_EditorLineSelectionPainter` that restores the persisted `selectedLinesByPath`/`lastSelectedLineByPath` selection across rebuilds via shift-click range toggle (`_handleGutterLineTap`)
chat_page_composer_status.dart                    # Resolves the fixed composer live-progress surface for latest busy tool/patch/reasoning activity using composer-specific compact labels via toolResolveComposerDescriptionLabel; falls back to the localized composer tip catalog when enabled
chat_page_command_query.dart                   # Composer slash and mention query source; `@` suggestions merge files, workspace symbols, and agents while preserving agent suggestions when remote search fails
chat_page_runtime_support.dart                   # Content-shrink snap hardened against competing scroll owners; _handleScrollMetricsChanged gates on return reveal, pagination restore, and scroll owner enum; per-session collapse state cache via _sessionCollapseHistoryCache
chat_page_chrome.dart                    # Session-tab chrome actions, incl. change-icon flow via `showSessionTabIconPicker` + `chatProvider.setSessionTabIconPreset` (issue #138)
chat_page_file_runtime.dart                   # File-tree mutation handlers (issue #89) + editor save pipeline (issue #90): resolves the absolute root directory from project/app providers, normalizes via `normalizeFilePath`/`fileBasename`, and reconciles absolute-vs-relative paths when calling `createFolder`/`createFile`/`rename`/`delete`; `_ensureFileOperationCapabilities` exposes the in-flight `fileOperationCapabilitiesLoad` Future so the open-files dialog (`_openOpenFilesDialog`) can `whenComplete` it to refresh the file-viewer panel once capabilities resolve; invalidates affected directory subtree caches after rename/delete; diff reconciliation (`_reconcileFileContextWithSessionDiff`) marks touched directories stale and triggers silent reloads of open file tabs via `_reloadFileTab`; `_reloadFileTab` blocks dirty editor drafts by skipping the content swap and setting the draft's `saveErrorMessage` to the static string `Unsaved changes; reload skipped.`; `_closeFileTab` blocks dirty drafts (`Save changes before closing this file.`) without removing the tab or draft; `_blockPathMutationForActiveEditorDrafts` blocks dirty or in-flight saves for the absolute and relative alias paths (`Save changes before changing this path.` / `Wait for the file save to finish before changing this path.`); editor save (`_saveFileEditorDraft`) gates on shell capabilities, dispatches `WorkspaceFileOperationsService.writeFile`, marks the draft clean on success or sets `saveErrorMessage` on failure, then refreshes the cached `_FileTabViewState`; rename/delete reconcile moves/prunes `editorDraftsByPath` and disposes removed drafts; dialogs: `_FileNameDialog` for create/rename, `_confirmDeleteFileTreeNode` deletion prompt, error-label mapping `_fileOperationErrorLabel(code)` against `WorkspaceFileOperationCode` and snackbar feedback; `FileTreeContextMenuRegion` wraps every node row with desktop secondary-click / mobile long-press handling dispatching new file/folder, rename, delete, copy-path (uses `Clipboard.setData` + snackbar), and refresh actions
chat_page_terminal_runtime.dart              # Terminal panel toggle, attach/detach lifecycle, mobile info sheet, panel height management, parent keyboard-inset propagation, and inline/maximized PTY reuse
chat_page_composer_widgets.dart                   # Reserved-height composer progress slot with in-place slide/fade updates so busy status changes do not move the timeline; consumes `Theme.of(context).visualStyleTokens` (issue #86)
chat_page_model_selector_runtime.dart        # New Chat action opens draft mode immediately via provider `beginNewChatDraft()`; child-thread selector labels are memoized and locked to sub-conversation metadata (model shown, variant shown only when explicit); brand-token Material icon overrides per providerId; `hidden` model-level filtering excludes `model.hidden` from selector and settings lists
chat_page_timeline_builder.dart              # Renders empty state with no-server CTA to wizard; passes `role` to MessageEntranceAnimation so each bubble uses the correct motion profile; composer stays enabled during draft-first New Chat (`currentSession != null || isDraftingNewChat`) and in sub-conversation sessions; sub-conversation model/agent selection remains session-context aware/locked; child-thread footer keeps `Return to main conversation` visible (stop behavior managed by composer); wires latest inline undo and historical server-confirmed user-message rewind while excluding `local_user_*` optimistic IDs; chat content shell, message viewport, and composer controls are guarded by scoped Selector build keys so composer selection changes rebuild only the affected subtree
chat_page_timeline_viewport.dart             # Extension `_ChatPageTimelineViewport` on `_ChatPageState` for timeline viewport management
chat_page_timeline_entries.dart              # Extension `_ChatPageTimelineEntries` on `_ChatPageState` for generating/handling timeline entry widgets
chat_page_timeline_runtime.dart              # Tool-chain expanded state key resolution (sessionId::messageId::startPartId); consumes `theme.visualStyleTokens` (issue #86) for tool-chain surfaces
chat_page_widgets.dart                       # UI components part of chat_page.dart: _ComposerStatusLanternText, _ComposerStatusLanternTextState, _DirectoryPickerSheet, _DirectoryPickerSheetState
chat_page_search.dart                   # Timeline full-text search: inline AppBar input with 300ms debounce, case-insensitive text/reasoning matching, message-level next/previous navigation, and transient TextSpan highlighting; uses dedicated _ScrollOwner.searchResult for scroll coordination
chat_page_mobile_overflow.dart                    # Renders pinned and overflow actions for mobile app bar, including display toggles, search, and terminal panel trigger
chat_page_session_tabs.dart                        # Cross-project session-tab activation, rollback, and close fallback; no longer pre-activates inactive tabs for context-menu actions and routes unified menu selections through SessionActionTarget (issues #162/#163)
```

### Chat message widgets

```text
lib/presentation/widgets/chat_message/chat_message_tool_part.dart   # Renders long tool outputs in a bounded internal scroll viewport; large diffs use lazy rendering so tool growth does not destabilize the outer chat timeline; task bubbles are compact, navigate to child thread via full-bubble tap, hide the task-only details row, prefer latest child-tool progress labels with command fallback while running, and show `N tool calls` when completed if child-session totals are available; consumes `theme.visualStyleTokens` (issue #86)
lib/presentation/widgets/chat_message/chat_message_content.dart     # Message bubble layout, copy/hold layers, inline undo/rewind, and provider-aware read-aloud controls that sanitize assistant text before routing to ReadAloudService, expose loading/pause/resume/stop states, and long-press to Settings > Text to speech; consumes `theme.visualStyleTokens` (issue #86)
lib/presentation/widgets/chat_message/chat_message_file_part.dart   # File attachment part renderer; consumes `theme.visualStyleTokens` for refined surface/border/radius tokens
lib/presentation/widgets/chat_message/chat_message_info_parts.dart  # Info-style message parts (e.g. tool headers, sub-step rows); consumes `theme.visualStyleTokens`
lib/presentation/widgets/chat_message/chat_message_text_part.dart   # Markdown renderer with code block tap builder; detects `language=="mermaid"` and routes to MermaidDiagramWidget via onMermaidCode callback; renders standard code blocks with syntax highlighting and copy action; wires math syntaxes (InlineMathSyntax, BlockMathSyntax, SingleLineBlockMathSyntax) and builders (InlineMathBuilder, BlockMathBuilder) when showMathRendering is enabled
lib/presentation/widgets/chat_message/chat_message_part_dispatch.dart # Reorders contiguous visible `task` tool runs so unfinished task bubbles stay last within each run while non-task grouping remains unchanged
lib/presentation/utils/tool_presentation.dart                      # Shared tool label/icon formatting reused by chat bubbles and the fixed composer live-progress surface
```

### `lib/presentation/providers/chat_provider/` clusters (current, 25 files)

```text
chat_provider_core.dart
chat_provider_session_ops.dart           # Implements undo/redo turn logic, guarded historical `revertToTurn`, revert boundary advancement, and composer draft restoration; session mutations (rename/share/fork/delete/archive/pin) accept SessionActionTarget for inactive-tab scoped execution (issues #162/#163)
chat_provider_lifecycle_ops.dart                 # Extension `ChatProviderLifecycleOps` on `ChatProvider`; coalesces foreground-resume work and exits safely when session-tab state is disposed
chat_provider_history_ops.dart                   # Extension `ChatProviderHistoryOps` on `ChatProvider` for history state/branching and revert support
chat_provider_realtime_ops.dart           # Realtime event handling; coalesces foreground-resume reconciliation, preserves visible session state during revalidation, and guards subscription restarts with disposal/generation checks; defers stale `session.idle` reconciliation until the active send stream settles so server-driven lifecycle stays authoritative across follow-up sends
chat_provider_realtime_aux_ops.dart                # Post-reconnect recovery with _postReconnectRecoveryInFlight guard and visible-state-preserving session revalidation; degraded mode preservation across background/foreground transitions
chat_provider_event_reducer_helpers.dart        # Shared event-info and session-merge helpers used by both the session-scoped reducer and the global event router (`_ChatProviderEventReducerHelpers`): `_eventInfoContainsAny`, `_mergeSessionFromEventInfo` (field-by-field copy based on `info` keys including `workspaceId`, `time`/`archivedAt`, `title`/`name`/`sessionTitle`, and `parentID`/`parentId`), and other low-level utilities shared across reducer parts
chat_provider_event_reducer_session_ops.dart    # Event-scope reducer for the active session stream (`_ChatProviderEventReducerSessionOps`): active session receives the full `message.created`/`updated`, `message.part.updated`/`delta`/`removed`, `message.removed`, `session.diff`, and `todo.updated` stream; non-current `message.*`/`session.diff`/`todo.updated` events break early so background message fallback fetches never fire for inactive sessions, while non-current `session.status`/`session.idle`/`session.error` plus `permission.*`/`question.*` events still flow and are summarized into status/unread/error/pending-interaction attention; v2 permission/question SSE aliases + `message.part.delta` (merged with `message.part.updated`) + `session.next.moved` (dirties current context and triggers session/status/active-session refresh); reconcile one-shot guard via `_messageStreamGeneration`, dedup key composition via `_composeEventDeduplicationKey`/`_recentEventIds`, reactive notification dismissal on `permission.replied`/`question.replied`/`question.rejected`/`session.idle` (current session) + `removeNotifiedRequestIds()` to sync background alert snapshot; live deltas advance `_messageLocalDeltaVersionById` and route through `_scheduleDeltaNotification`; `session.idle` flushes delta notifications and cancels pending per-message fallback timers for the idle session
chat_provider_event_reducer_global_ops.dart     # Global event router (`_ChatProviderEventReducerGlobalOps`) dispatches by target context — non-directory events dirty the active context, same-context events fall through `_tryApplyGlobalEventIncremental` then `_scheduleGlobalFallbackReconcile`, and inactive context snapshots are patched in-place by `_tryApplyGlobalEventToInactiveSnapshot` for `session.created`/`updated`/`deleted`/`status`/`idle`/`error` and `permission.*`/`question.*` shapes so dirty contexts revalidate on return
chat_provider_message_merge_ops.dart             # Debounced per-message fallback orchestration (`_scheduleDebouncedMessageFallback`, `_fetchMessageFallback`) carrying `expectedLocalDeltaVersion` so stale responses merge completion metadata only; non-current `message.*` events are gated by the event reducer before reaching `_fetchMessageFallback`, so realtime normally uses it only for current-session message resolution (applied via `_updateOrAddMessage`); `applyToCurrentSession` and the inactive branch writing to the per-session cached snapshot remain available for explicit fallback/cache use cases only; local user message reconcile helpers (`_shouldSkipLocalUserAppendAsDuplicateEcho`, `_mergeServerMessagesWithPendingLocalUsers`, `_mergeServerTailWithCachedMessages`, `_findOptimisticTailOverlap`, `_mergeServerMessagesWithActiveLocalTail`) for SWR overlap + optimistic-tail preservation with bounded tail fallback
message_reconciliation.dart                         # Non-regressive message snapshot reconciliation decisions for preserving newer visible timeline state
chat_provider_reconciliation_guard.dart             # Applies message reconciliation to visible state, logs decisions, and suppresses no-op writes
chat_provider_message_state_ops.dart             # Message state mutations; per-message local delta version (`_messageLocalDeltaVersion`, `_markLocalMessageDeltaAdvanced`) feeds monotonic fallback guards; non-overlapping delta appender (`_appendNonOverlappingDelta`) and incremental part merge (`_mergeIncrementalPartUpdate`); assistant non-regressive merge helpers (`_mergeAssistantCompletionMetadataOnly`, `_mergeCompletedAssistantUpdate`, `_mergeAssistantMessageUpdate`, `_mergeCompletionStatusOnly`) preserve completed snapshots and visible terminal tool states; auto-title scheduling guard skips subsessions
chat_provider_draft_part.dart                    # Loads/persists per-session composer drafts and manages rejected-draft envelopes; unconditional draft preservation across background transitions (removed foreground guards from _stashRejectedDraftForRetry)
chat_provider_selection_sync_ops.dart
chat_provider_selection_helpers.dart       # Selection helpers including `_restoreSelectionFromMessages()` — scans cached messages for the last non-summary AssistantMessage and restores its providerId/modelId/mode as the current selection; `_storeCurrentSessionSelectionOverride()` with `isExplicit` flag preservation
chat_provider_context_state_ops.dart        # Context-scoped override application; `_applySessionSelectionOverride()` delegates to message-derived fallback (`_restoreSelectionFromMessages()`) when no override exists, when override is stale, or when override is non-explicit (Feature 7)
chat_provider_preference_ops.dart                # Persists favorites/recent usage plus per-agent provider/model/variant memory
chat_provider_shortcut_cycle_ops.dart
chat_provider_auto_title_ops.dart               # Auto-title execution (main/root sessions only); runtime guard in `_runAutoTitlePass` skips subsessions
chat_provider_error_policy.dart
chat_provider_cache_persistence_ops.dart
chat_provider_abort_policy_ops.dart / chat_provider_session_attention_ops.dart
chat_provider_target_ops.dart                  # SessionActionTarget helpers for exact server/directory scoped mutations and snapshot updates (issues #162/#163): `_sessionForTarget`, `_isActiveTarget`, `_applySessionForTarget`, `_removeSessionForTarget`, and `_togglePinnedForTarget`
chat_provider_session_tab_ops.dart              # ChatProvider-owned generation-safe load/write, recency/order/tombstone/attention reconciliation, lifecycle hooks, and project-history cleanup; loads/applies `SessionTabIconOverrideStore` state per server, sets/removes per-session icon presets (issue #138), prunes overrides on session close/directory removal, and clears pinned state on directory cleanup (issues #162/#163)
```

### `lib/presentation/widgets/chat_input/` clusters (current, 11 modules)

```text
chat_input_state_machine.dart
chat_input_history_controller.dart             # Local command/prompt history and external draft restoration/clear support for undo/redo parity
chat_input_mentions_controller.dart
chat_input_commands_controller.dart
chat_input_suggestion_popover.dart             # Mention/slash/canned popover; renders file, workspace-symbol, and agent badges/icons; consumes `theme.visualStyleTokens` (issue #86) for refined surface tokens
chat_input_attachment_controller.dart          # Composer attachment picker/append flow; uses multi-select file_picker calls for supported image/PDF files, converts client-local bytes to data URLs, keeps image/PDF-specific fallbacks, dedupes chips, and preserves separate direct FileInputPart handling for server-side file:// paths
chat_input_external_drop_controller.dart       # External drop/paste flow via desktop_drop, pasteboard, and the Android composer clipboard content-URI MethodChannel; reads client-local bytes, gates shell/non-current routes, and routes accepted files through the shared data-URL attachment path
chat_input_external_files.dart                 # Shared external-attachment byte, name, MIME, and image-signature helpers
chat_input_send_controller.dart
chat_input_speech_controller.dart             # Speech start/stop orchestration: resolves the engine candidate chain from settings (API engine configured per start from `SettingsProvider` speechApiProvider/baseUrl/model via `ApiSpeechInputService.configure()`), maps stable `unavailableReasonKey` codes to localized messages, and special-cases the API backend in Windows microphone routing
```

### Speech-to-Text Platform Support

```text
lib/presentation/utils/speech_engine_platform_support.dart # Centralized per-engine platform support table; Native disabled on Windows (speech_to_text_windows crash, see ADR-044); on-device engines (Sherpa/Moonshine/Parakeet/SenseVoice) allowed on Windows via the runner-owned WASAPI bridge; cloud API STT allowed on all non-web platforms (isApiSupported => !kIsWeb, no browser builds to avoid exposing API keys)
```

Platform support rules (per `SpeechEnginePlatformSupport`):

- **Native** (`speech_to_text`): web + iOS/macOS/Android/Fuchsia; **Windows disabled** (speech_to_text_windows crash) and Linux excluded by design (Linux defaults to Parakeet).
- **Sherpa**: web excluded; Android excluded (slim APK); other IO platforms allowed.
- **Moonshine / Parakeet / SenseVoice**: Linux + macOS + **Windows** (uses the runner-owned `WindowsMicrophoneService` WASAPI bridge). Desktop-only because they bundle `sherpa_onnx` + downloadable models.
- **API** (cloud STT): all non-web platforms (Android/iOS/desktop); requires an API key from `SttApiKeyStorage` except for custom endpoints, and HTTPS for remote endpoints (localhost HTTP allowed).

On Windows, `SpeechAudioCapture` short-circuits to `WindowsMicrophoneService` (PCM16 mono 16 kHz only); the plugin captures via `windows/runner/windows_microphone_plugin.{h,cpp}`, which posts `kWindowsMicrophoneDrainMessage` (WM_APP + 0x43C) to the `FlutterWindow` so queued audio/error events drain on the window message loop without blocking the capture thread. The `FlutterWindow::OnCreate`/`OnDestroy` path owns plugin lifetime and forwards window messages through `WindowsMicrophonePlugin::HandleWindowMessage`.
For Windows STT failures, Native STT is no longer the Windows default; the speech settings preflight + chat input failure snackbar surface the Windows microphone status returned by `WindowsMicrophoneService.probe()` and map errors to Windows settings links via `WindowsSettingsLinks`.

### Terminal Workspace

```text
lib/data/datasources/terminal_remote_datasource.dart    # Server-side PTY datasource: createPty (POST /pty), resizePty (PUT /pty/:id), deletePty (DELETE /pty/:id); directory-scoped calls to server /pty contract
lib/data/models/pty_session_model.dart                  # PTY session model (id, title, command, args, cwd, status, pid) from server createPty response
lib/presentation/services/codewalk_terminal_controller.dart   # Owns xterm Terminal state, server-side PTY lifecycle (startShell/stop), WebSocket connect/disconnect, resize debouncing, cursor tracking, process-token concurrency guards, and teardown; `supportsRemoteTerminal` gates to IO-only (!kIsWeb); optional `authHeaderProvider`/`tailscaleSocketOpener` delegates via `configureTransport` with Tailscale-aware opener selection
lib/presentation/services/codewalk_terminal_socket.dart         # Conditional export: abstract `CodewalkTerminalSocketConnection` interface + `openCodewalkTerminalSocket()` factory
lib/presentation/services/codewalk_terminal_socket_io.dart      # IO implementation: `dart:io` WebSocket.connect with binary frames plus `openCodewalkTerminalSocketViaTailscaleImpl` RFC 6455 handshake/framing over dialed tailnet TCP
lib/presentation/services/codewalk_terminal_socket_stub.dart    # Non-IO platforms: throws UnsupportedError
lib/presentation/services/codewalk_terminal_url.dart            # WebSocket URL builder: converts HTTP(S) base URL to ws(s):// + `/pty/{ptyId}/connect` with directory and cursor query params
lib/presentation/widgets/codewalk_terminal_panel.dart           # Resizable terminal panel with reconnect/close/minimize/maximize controls and fallback state; on native Android/iOS with a positive parent keyboard inset, integrates the extra-key strip only for active terminals, owns focus/controller lifecycle, and reuses the same terminal/PTY across inline/maximized surfaces; configures `TerminalView` with mobile `deleteDetection` for backspace input support
lib/presentation/widgets/codewalk_terminal_extra_keys.dart      # Core native Android/iOS software-keyboard extra-key widget/controller: Escape, Tab, one-shot Ctrl/Alt across virtual/hardware/IME input, repeatable arrows, input-handler ownership and lifecycle reset, semantics, focus retention, and responsive horizontal scrolling
third_party/xterm/lib/src/terminal_view.dart                    # Vendored `TerminalView` opt-in raw committed-text interception callback; absent/false keeps the existing input and Windows printable/AltGr fallback behavior unchanged
lib/presentation/pages/chat_page/chat_page_terminal_runtime.dart # ChatPage extension for terminal toggle flow, project-scoped shell start, close/minimize/maximize actions, persisted panel height/maximize handling, and fallback info sheet; passes the parent keyboard inset because Scaffold consumes descendant `MediaQuery.viewInsets`, preserving maximize/restore and PTY reuse
lib/presentation/pages/chat_page/chat_page_timeline_builder.dart # Main chat workspace layout: renders terminal full-width below the constrained chat column and hides composer-adjacent controls on compact/mobile while terminal is visible
lib/domain/entities/experience_settings.dart                    # Shared experience settings: terminal state, nullable session-tab visibility override (resolved with platform/web defaults by SettingsProvider), provider-aware read-aloud settings (`ReadAloudProvider`, voice id/locale, model, base URL, response format), `SpeechToTextEngine.api` cloud STT engine with `SpeechApiProvider` (openAi/groq/custom) + base URL/model fields (defaults OpenAI `gpt-4o-mini-transcribe`, legacy `openai_compatible`/`cloud` engine keys map to `api`, trailing slashes trimmed on load), debug logging toggles, and **visual style**; `fromJson` keeps legacy visual/logging/read-aloud payloads compatible
lib/presentation/providers/settings_provider.dart               # In-memory + persisted mutators for terminal visibility, height, and maximize state
  └── settings_provider_opencode_defaults.dart # Shared defaults (part of settings_provider.dart; see commit 8759defc)
  └── settings_provider_update_install.dart # Update check / install lifecycle (part of settings_provider.dart; see commit 8759defc)
```

## Data & Domain Layers

```text
lib/domain/entities/       # Core business entities (chat, provider, project, worktree, settings with provider-aware read-aloud preferences, server_profile.dart with tailscaleEnabled/oauthEnabled flags, `chat_composer_draft.dart` for persisted session drafts; Model entity includes `hidden` field — excluded from selector and settings when true)
lib/domain/repositories/   # Repository contracts
lib/domain/usecases/       # Use case boundaries used by providers
lib/data/models/           # API/storage models and JSON adapters (includes provider_model.dart with `hidden` on ModelModel)
lib/data/repositories/     # Repository implementations (includes chat_repository.dart, reply_question.dart, reject_question.dart); sessionId removed from replyQuestion/rejectQuestion (ADR-023 contract compliance)
lib/data/datasources/      # Remote/local IO boundaries
lib/data/datasources/      # Remote/local IO boundaries, including SharedPreferences-backed local cache helpers
```

## Key API/DataSource locations

```text
lib/data/datasources/app_remote_datasource.dart
  - /path, /app (fallback), /app/init (fallback), /provider, /agent, /config; scoped discovery/config calls add both directory and workspace query params; implements directory-only and unscoped retries for discovery contracts; `/agent` parsing handles multiple upstream response formats

lib/data/datasources/app_local_datasource.dart
  - Server-scoped `AppConstants.sessionTabsStateKey` (`session_tabs_state`) persistence through `getSessionTabsStateJson` / `saveSessionTabsStateJson`, backed by the shared-preferences scoped-key helper
  - Server-scoped `AppConstants.sessionTabIconOverridesKey` (`session_tab_icon_overrides`) persistence through `getSessionTabIconOverridesJson` / `saveSessionTabIconOverridesJson` / `deleteSessionTabIconOverrides`, same scoped-key helper

lib/data/datasources/chat_remote_datasource.dart
  └── chat_remote_datasource_helpers.dart # Command, send, error, tool, and reasoning helpers (part of chat_remote_datasource.dart; see commit 8759defc)
  - /session, /session/{id}, /session/{id}/message, /session/{id}/shell
  - /session/status, /session/{id}/children, /session/{id}/todo, /session/{id}/diff
  - /session/{id}/abort, /session/{id}/revert, /session/{id}/unrevert, /session/{id}/init, /session/{id}/summarize
  - /event (provider-level SSE only; per-send SSE removed), /global/event
  - /permission, /permission/{requestId}/reply (legacy fallback), /session/{id}/permissions/{permissionId} (canonical, `remember: true` for `always` replies)
  - /question, /question/{requestId}/reply, /question/{requestId}/reject (replyQuestion/rejectQuestion no longer send sessionID query parameter — ADR-023 contract compliance)

lib/data/datasources/project_remote_datasource.dart
  - /project, /project/current
  - /experimental/worktree, /experimental/worktree/reset
  - /file, /file/content, /find/file, /find?pattern=, /find/symbol, /vcs

lib/data/datasources/quota_remote_datasource.dart
  └── quota_remote_datasource.part.js.dart # JS payload generation part file: shared helpers + implemented shell probes; `_supportedAuthKeys` is the auth-alias/unsupported-filter register
  - Strategy-chain: OpenChamber REST (`GET /api/quota/providers` -> `GET /api/quota/{provider}`) -> hidden ephemeral shell probe (`CW_QUOTA_JSON:`)
  - OpenCode Go probe: `GET https://opencode.ai/zen/go/v1/usage` with `Authorization: Bearer <key>`, where the key comes from the host `auth.json` (`opencode-go` entry, `key`/`access`/`token`); maps `usage.rolling/weekly/monthly` (`percent` + `resetsAt`) and returns typed `errorCode` (`authentication` on 401/403, `invalid_response` on unparseable payload, `request_failed` otherwise); legacy workspace-id/auth-cookie dashboard credentials flow removed (issue #96)
```

## Main Commands

```bash
make deps
make gen
make theme-sync
make theme-sync-check
make icons
make icons-check
make analyze
make test
make coverage
make check
dart tool/i18n/sync_arb_strings_from_arbs.dart  # Rebuild tool/i18n/arb_strings.dart from canonical lib/l10n/app_*.arb
dart tool/i18n/generate_arb.dart                # Validation-only: verify ARBs match the arb_strings.dart catalog (non-destructive)
flutter gen-l10n                                # Regenerate AppLocalizations delegates into lib/l10n/generated/
make web
make android
make desktop
make release V=patch|minor|major
python tool/release/changelog.py update X.Y.Z
python tool/release/changelog.py extract X.Y.Z --output release-notes.md
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter run -d linux
flutter run -d android
flutter run -d chrome
```

## Testing/Quality Gates

```text
test/unit/                             # Unit tests
test/unit/i18n/arb_catalog_sync_test.dart # ARB ⇄ arb_strings.dart catalog parity: exact keys/values, placeholders, plurals, and ICU apostrophe safety (issue #103)
test/unit/domain/session_attention_models_test.dart # Session-attention identity, priority, aggregate, and payload models
test/unit/data/session_attention_snapshot_store_test.dart # Encrypted snapshot round trips, nonce rotation, corruption recovery, atomic-write failures, and tombstones
test/unit/data/car_messaging_store_test.dart # Encrypted car-messaging store round trips, thread/reply bounds and retention pruning, key/file-store failure handling, and serialized access
test/unit/presentation/session_attention_coordinator_test.dart # Attention timing and monitoring-availability coverage
test/unit/presentation/session_attention_delay_coordinator_test.dart # Attention delay-state coverage
test/unit/presentation/session_attention_completion_resolver_test.dart # Completion snapshot resolution coverage
test/unit/presentation/session_attention_host_protocol_test.dart # Versioned host snapshot and command-protocol coverage
test/unit/domain/experience_settings_test.dart # `ExperienceSettings` JSON round-trip covers `visualStyle` and provider-aware read-aloud settings (`ReadAloudProvider`, voice/model/baseUrl/format); includes cloud API STT round-trip (`SpeechToTextEngine.api`, provider/base URL/model, no key in JSON) and legacy `openai_compatible`/trailing-slash normalization
test/unit/domain/persisted_session_tabs_state_test.dart # Versioned persisted open/closed session-tab payload round trips and invalid-input handling
test/unit/domain/session_tab_icon_overrides_test.dart # Icon override entity round trips, dedup/compaction ordering, and malformed/version-mismatch decode guards
test/unit/auth/                        # OAuth auth unit tests
test/unit/auth/oauth_service_io_test.dart # OAuth callback validation tests: exact method/origin/effective-port/raw-path/state/code-error cardinality decisions, non-terminal unrelated paths, single-use completion guard, generic token-exchange HTTP failure text, trusted Cloudflare Access host matching, HTTPS-only trusted OAuth endpoint checks, and metadata endpoint trust for the configured server origin or a trusted Cloudflare Access origin
test/unit/auth/oauth_token_storage_test.dart # OAuth token storage tests: save/load/delete credential, hasValidCredential, OAuthTokenStorageException backend error handling, cross-profile key isolation
test/unit/auth/tts_api_key_storage_test.dart # TTS API-key storage tests: trim/save/load/delete, per-provider isolation, secure-storage exception mapping
test/unit/auth/stt_api_key_storage_test.dart # STT API-key storage tests: per-provider key isolation, empty-write deletion, fail-closed secure-storage exception mapping
test/unit/network/dio_client_auth_test.dart # Dio auth ownership tests: setOAuthToken/clearOAuthToken interaction with exact-origin Basic Auth, clearAuth clears both, header restoration on OAuth clear preserves Basic Auth only for the configured origin, sticky OpenCode `X-Session-Id` echo (echoed on later requests, cleared on base URL change, cleared on `clearAuth`)
test/unit/core/tailscale/tailscale_http_adapter_test.dart # Tailscale Dio adapter: head-only timeout (configured + 15s fallback), bodyless EOF handling, cancel/error propagation
test/unit/core/tailscale/tailscale_peer_test.dart # TailscalePeer defaultUrl: default OpenCode port mapping and IPv6 bracketing
test/unit/providers/                   # ChatProvider split tests (9 files, parallelized with -j 12); `settings_provider_test.dart` covers visual style, provider-aware read-aloud preference persistence, and fresh-install read-aloud default/probe preservation behavior
  chat_provider_init_test.dart         #   12 tests — initialization, config sync, model/agent selection
  chat_provider_sync_test.dart         #   17 tests — deferred sync, cycle, scope, overrides, variant sync
  chat_provider_messaging_test.dart    #   15 tests — sessions, sendMessage, draft restore; delta-like SWR fallback coverage
  chat_provider_realtime_test.dart     #   21 tests — title gen (main sessions only), SSE, abort, reconciliation
  chat_provider_session_ops_test.dart  #   27 tests — rename/share/fork/delete, insights, undo/redo/revertToTurn parity (regression coverage), idle
  chat_provider_project_test.dart      #   13 tests — permissions, questions, project scope, favorites; project-switch SWR behavior + draft isolation + dirty-context cache retention
  chat_provider_concurrency_test.dart  #   26 tests — render gate, multi-session, abort suppression
  chat_provider_selection_fallback_test.dart # Message-derived selection fallback tests (Feature 7): override isExplicit semantics, _restoreSelectionFromMessages() recovery paths, stale override → message fallback, non-explicit override → message fallback precedence
  chat_provider_session_tabs_test.dart # Session-tab load, reconciliation, persistence, tombstone, attention, project-scope, and icon-override load/preset/remove coverage
  chat_provider_test_support.dart      #   Shared utilities (RecordingDioClient, buildChatProvider, testModel); FakeChatRepository.getSessionsDelay
test/unit/quota/                        # Quota/rate-limit unit tests (provider groups, TTL cache validation, shell fallback, pace utility); `quota_remote_datasource_test.dart` asserts the OpenCode Go probe (Bearer key from host `auth.json`, `/zen/go/v1/usage`, rolling/weekly/monthly mapping, typed `errCode`s, 15s abort timeout, no `Cookie:` header or `OPENCODE_GO_*` env vars) plus Node-executed JS behavior checks; `quota_provider_test.dart` covers the typed-errorCode failure card (`authentication`/`invalid_response`) and absence of the legacy reconnect UI (issue #96)
test/unit/datasources/app_local_datasource_impl_test.dart # Best-effort legacy OpenCode Go credential purge: `clearOpenCodeGoDashboardCredentials()` deletes workspace-id/auth-cookie keys (incl. `::active` and orphaned variants) via secure-storage `readAll()` while preserving other values and suffix-mismatch keys (issue #96)
test/unit/services/                     # Platform and runtime service unit tests:
  codewalk_terminal_controller_test.dart #   Terminal controller: server-side PTY lifecycle, WebSocket connectivity, resize debouncing, cursor tracking
  codewalk_terminal_url_test.dart        #   WebSocket terminal URL construction
  read_aloud_service_test.dart           #   Provider-routed read-aloud lifecycle, loading-before-playback state, generated-audio playback, secure API-key lookup, options, and message tracking
  read_aloud_default_resolver_test.dart  #   Fresh-install read-aloud provider selection and Edge locale voice fallback tests
  read_aloud_text_extractor_test.dart    #   Assistant text extraction and Markdown sanitization before TTS/cloud read-aloud
  openai_compatible_tts_backend_test.dart # OpenAI-compatible TTS request payload, response audio handling, and provider error mapping
  elevenlabs_tts_backend_test.dart       #   ElevenLabs voice parsing, model/voice request payload, generated MP3 handling, limits, and error mapping
  nvidia_nim_tts_backend_test.dart       #   NVIDIA NIM voice parsing, multipart synthesis/audio validation, limits, and error mapping
  tts_executor_test.dart                 #   Provider selection, per-provider API-key lookup, serialized stop handling, and speech-job cancellation guards
  edge_tts_protocol_test.dart            #   Edge/Bing Read Aloud URL signing, headers, SSML, frame parsing, MP3 audio frames, and input limits
  edge_experimental_tts_backend_test.dart #   Edge experimental voice parsing, direct websocket synthesis to generated MP3 audio bytes, error mapping, and stop/close behavior
  windows_microphone_service_test.dart   #   Windows microphone access probe and preflight status tests
  speech_input_service_api_test.dart     #   Cloud API STT backend: PCM16 WAV encoding, multipart upload + final transcription, rejected-credential mapping without leaking response details, silence-only skip, insecure custom-endpoint rejection, preset base-URL precedence, and session-epoch restart isolation
  session_tab_icon_override_store_test.dart #   Per-server override store serialization, dedup/compaction, and scoped-key persistence
  car_messaging_notification_test.dart #   Android Auto MessagingStyle notification spec, category/action constants, and id/tag derivation
  car_messaging_gate_test.dart        #   Background gate predicates, data-saver interaction, and server-profile eligibility
  car_messaging_action_handler_test.dart # Car reply/mark-read action handling, reply queueing, and Workmanager scheduling
  car_messaging_dispatch_worker_test.dart # Queued reply dispatch, completion publishing, and failure marking
  car_messaging_android_manifest_test.dart # Automotive descriptor assertions (main manifest references it; debug/profile do not)
test/unit/di/speech_service_registration_test.dart # DI isolation: `ApiSpeechInputService` factory returns distinct instances per composer (`isNot(same())`), with DI reset/teardown
test/unit/presentation/                 # Presentation-level service tests; includes `workspace_file_operations_service_test.dart` (issues #89 and #90) covering official tool-state parsing, malformed responses, shell quoting, capability probes, create/rename/delete session teardown, server-bound abort semantics, write-path validation, 48 KiB content chunking, and negotiated GNU/BSD/Python decoding; `app_theme_test.dart` (issue #86) covers `AppVisualStyleTokens.classic`/`refined` factories, theme-extension wiring through `AppTheme.lightFrom`/`darkFrom`, `withResponsiveSnackBars` shape switching, and the `ThemeData.visualStyleTokens` fallback getter
test/unit/presentation/chat_input_external_files_test.dart # Pure composer external-attachment byte, name/MIME, and image-signature helper coverage
test/widget/                           # Widget tests (includes icon assertions with Symbols.*, explicit compact/mobile collapsed-copy coverage for chat message and session todo surfaces, historical rewind action coverage, desktop/mobile spacing for ChatSessionList, toolbar undo/redo, slash-command parity, terminal mobile backspace simulation, Windows printable hardware key forwarding, Windows AltGr printable forwarding, AppShell update toast coverage in `app_shell_page_test.dart` with explicit teardown of ChatProvider/AppProvider/SettingsProvider in `finally` for clean run isolation, issue #86 Visual style coverage in `settings_page_test.dart` for the Appearance `SegmentedButton<VisualStyle>` (`settings_visual_style_segmented`) calling `setVisualStyle` and persisting `visualStyle: 'refined'`; `chat_message_widget_test.dart` and `chat_page_test.dart` were additionally run as regression suites to confirm no refined-surface regression on the chat surfaces, issue #89 file-tree coverage in `chat_page_test.dart` covering file-tree refresh, root New menu, new-file/new-folder dialogs, rename, delete confirmation + reconciliation, Quick Open lookup, and absolute/relative path resolution, and issue #90 editor coverage in `chat_page_test.dart` covering debounced autosave ownership/timing, per-path draft isolation, active-save coordination, lifecycle/close guards, CRLF save round-trip, current-draft Add-to-chat via gutter selection, dirty-state preservation on save failure, dirty relative-path rename blocker, and a `file editor opens empty text files as editable drafts` widget test that taps a known empty non-binary file and confirms the editor renders with the editable `CodeEditor`)
test/widget_test.dart                    # Focused composer attachment widget coverage for picker/drop data URLs, shell/non-current route gating, and Android content-URI clipboard bridging
  speech_settings_api_test.dart        #   API speech settings at mobile width: engine selection to `SpeechToTextEngine.api`, provider/API-key fields, and SttApiKeyStorage read/write via a fake backend
  session_attention_overlay_test.dart  # Shared bubble/panel ordering and action wiring, including disabled read-aloud
  session_tab_strip_test.dart           # Session-tab strip activation, icon-preset rendering, attention/busy visuals, overflow visibility, close fallback focus, and semantics coverage
  session_tab_icon_picker_test.dart     # Icon picker preset selection (incl. project-icon default), fullscreen/AlertDialog switching, and accessibility
  chat_message_widget_test.dart         #   Read-aloud button loading indicator and long-press Settings > Text to speech routing
  chat_page_test.dart                   #   ChatPage lifecycle regression keeps active/loading read-aloud alive across inactive/hidden/paused/resumed transitions and covers editor autosave timer/close cleanup; issue #122 integration coverage keeps mobile extra-key visibility and maximize/restore on the same PTY without overflow
test/widget/codewalk_terminal_extra_keys_test.dart # Issue #122 terminal key sequences, one-shot modifiers, repeat lifecycle, focus, semantics, visibility, and compact layout
test/widget/terminal_mobile_backspace_test.dart # Mobile IME backspace and raw modifier-input regressions, plus Windows printable and AltGr forwarding
third_party/xterm/test/src/terminal_view_test.dart # Opt-in raw committed-text callback consumption and unchanged fallback behavior
test/integration/                      # Integration tests; includes data-usage optimization and permission `remember` contract coverage in `opencode_server_integration_test.dart`, plus opt-in local OpenCode probe/create/write/read/delete coverage in `workspace_file_operations_live_test.dart`
test/presentation/                     # Presentation-focused tests (incl. window_size_class_test.dart)
test/support/                          # Test helpers/fakes; `mock_opencode_server.dart` includes extra counters for usage optimization tracking; `pump_localized_app.dart` wraps widgets with all l10n delegates for locale-aware tests; `FakeWorkspaceFileOperationsService` (test/support/fakes.dart) implements `WorkspaceFileOperationsService` with capability/result overrides, per-operation call counters + `onCreate*`/`onRename`/`onDelete`/`onWriteFile` hooks, and a `writeFileResult` override for issue #90 editor save testing
test/contract/                         # Contract tests; `chat_event_contract_test.dart` covers SSE event dispatch contract tests, including `session.idle` idle-trailing-error invariant (P-002), `message.created` fallback fetch dispatch, and `message.part.delta` stale-fallback monotonic-version merge coverage
tool/ci/check_analyze_budget.sh        # Analyzer issue budget gate (default: 186)
tool/ci/check_coverage.sh              # Coverage threshold gate (default: 35%)
tool/ci/run_session_overlay_instrumentation.sh # Android session-overlay instrumentation runner for the GitHub Actions API 34–36 matrix; bounded APK installs/test execution, semantic result validation, and runtime diagnostics
tool/release/changelog.py              # Changelog update/extract helper used by `make release` and GitHub Releases
.github/workflows/ci.yml               # CI executes analyze + tests + coverage gate; includes Go setup (actions/setup-go@v5) in quality, test_shards, and coverage jobs for Tailscale dep; `windows_build` job runs on `windows-latest` and executes `flutter build windows --debug` to validate the runner-owned WASAPI microphone bridge compiles
.github/workflows/session-overlay-prototype.yml # Session-overlay prototype workflow: Android compile plus API 34–36 runtime instrumentation, and desktop compile matrix
```

## Internationalization (i18n)

- Comprehensive localization with 14 supported languages: English (template), Arabic, Bengali, German, Spanish, French, Hindi, Italian, Japanese, Korean, Portuguese (Brazil), Russian, Urdu, and Chinese (Simplified).
- `lib/l10n/app_*.arb` (14 locales) are the canonical i18n source of truth, with English as the template (`app_en.arb`, 1877 UI keys).
- Generated `AppLocalizations` classes in `lib/l10n/generated/` provide type-safe translation accessors.
- UI code uses `context.l10n.keyName` via the `L10nContext` extension (`lib/core/i18n/l10n_context.dart`).
- Context-free services (tray, background tasks, notification planning) use the stabilized `L10nBridge.current` pattern (`lib/core/i18n/l10n_bridge.dart`) for context-free access to translations.
- The locale registry (`lib/core/i18n/app_locales.dart`) defines the 14 supported locales, RTL metadata, resolution callback, and PT_BR normalization.
- `L10nBridge.current` is set at app boot and on locale change via `LocaleProvider` in `lib/main.dart`, ensuring consistent translation availability across the entire application lifecycle.
- Non-translatable invariants: OpenCode wire event types, permission keys, tool state discriminators, REST paths, config key names, and `prompt_async` contract fields.
- To add new strings: edit the ARB files in `lib/l10n/` (add the key to `app_en.arb` and translations to the locale ARBs), run `dart tool/i18n/sync_arb_strings_from_arbs.dart` to rebuild `tool/i18n/arb_strings.dart`, then run `flutter gen-l10n` to regenerate the localization delegates.
- `dart tool/i18n/generate_arb.dart` is validation-only and non-destructive: it verifies every ARB matches the `arb_strings.dart` catalog (keys and values) and fails on mismatch instead of rewriting files.
- `test/unit/i18n/arb_catalog_sync_test.dart` enforces the catalog contract in CI: exact key/value parity between `arb_strings.dart` and the ARBs, placeholder and plural parity across all locales, and no over-escaped ICU apostrophes.
- Android background/overlay surfaces bootstrap their own locale outside the widget tree: the session-overlay engine resolves its locale via `resolveBackgroundAlertLocale` (`android_background_alert_logic.dart`) and the background alert worker calls `initializeBackgroundLocale()` (`android_background_alert_worker.dart`) before localizing notifications.
- To migrate remaining hardcoded strings: follow the `context.l10n` pattern; use `tool/i18n/migrate_code_v2.dart` as reference.

## Notes

- `make android` builds an arm64 APK, uses a monotonic installable build number aligned with release versioning (so repeated local uploads replace the previous installation without making later releases look like downgrades), and sends the artifact with `~/bin/hey`; use `HEY_CAPTION` to override the upload caption.
- `make web` builds the static Flutter web app into `build/web` with configurable `WEB_BASE_HREF` (default `/`) and verifies the expected entry files for Cloudflare Pages or static hosting upload.
- `make release V=patch|minor|major` requires a clean worktree, updates `CHANGELOG.md` through `tool/release/changelog.py`, bumps `pubspec.yaml`, commits, tags, and pushes.
- Android manifest declares `REQUEST_INSTALL_PACKAGES` permission and a `FileProvider` authority (`com.verseles.codewalk.fileprovider`) required for APK sideload installs via `open_filex`.
- Sensitive server credentials and cloud TTS/STT API keys (OpenAI-compatible, ElevenLabs, and NVIDIA NIM for TTS) are persisted through `flutter_secure_storage` (v10.0.0) via `AppLocalDataSource` / `TtsApiKeyStorage` / `SttApiKeyStorage`.
- Platform folders currently present: `android/`, `linux/`, `macos/`, `web/`, `windows/`.
- Linux keeps native STT disabled; new installs default to Parakeet while Sherpa, Moonshine, Parakeet, and SenseVoice remain explicit desktop-selectable alternatives.
- Android build targets Java 17 (`sourceCompatibility`, `targetCompatibility`, `jvmTarget`).
- Material Symbols are the default app icon set in UI surfaces; `SimpleIcons` remains intentional for brand/file-type icons and a few legacy Material `Icons.*` calls remain in focused quota/open/close controls.
- Cloudflare Access OAuth is supported on Android and desktop through a shared ephemeral 127.0.0.1 HttpServer callback bound before DCR and one exact redirect URI; desktop launches the system browser, while Android uses MainActivity's AndroidX Custom Tab with an external-browser fallback. iOS remains unsupported.
- `package:tailscale` (`third_party/tailscale/`, path dependency in `pubspec.yaml`) provides embedded userspace Tailscale networking via a Go native build hook (`hook/build.dart`). The hook skips Windows native asset registration to keep the package importable while runtime Tailscale support remains stubbed on Windows — preserving Windows release builds. Supports Android, iOS, Linux, macOS; excluded from Web/Windows platform declarations.

### Debug Logging (issue #91)

- **Global logging gate**: `AppLogger.loggingEnabled` defaults to `false` and gates every recording path (`debug`, `info`, `warn`, `error`, `runPerformanceTask`, `measurePerformance`, `recordPerformanceTask`, `beginTask`/`runTask`); `setLoggingEnabled(false)` also clears the in-memory buffer.
- **Performance gate**: `AppLogger.performanceLoggingEnabled` is the AND of the global gate and `_performanceLoggingEnabled`; performance timing is collected only when both are true.
- **Lazy performance context**: `runPerformanceTask` / `measurePerformance` accept a `contextBuilder` callback that is invoked only when a performance record is actually emitted, so safe context lookups (e.g. `AppLogger.safeContextId(scopeId)`) never run when performance logging is off.
- **Structured task tracking** (issue #71): `AppLogger.beginTask(name, tags, context)` returns a `TaskHandle` whose stopwatch drives phase entries; nested tasks link to the enclosing zone-scoped parent task via `parentTaskId`. `AppLogger.runTask<T>(name, body)` wraps sync/async work, routing the body through `runZoned` so child tasks auto-attach to the parent and surfaces errors as `status=error` task-end entries. Phase tags `phase:start`/`phase:end`, status tags (`status:ok`/`status:error`/`status:canceled`), and metrics (`taskId`, `parentTaskId`, `operation`, `phase`, `elapsedMs`, `context`) are emitted on every phase entry; `TaskHandle.end({status, extraContext})` / `.cancel({reason})` close the task with status-aware log level.
- **Instrumentation hotspots** (issue #71): realtime event reducer (`task:realtime_event`), settings persist flow (`task:settings_persist`), directory/project switch (`task:directory_switch`), notification cleanup/dismiss/tap scheduling (`task:notification_clear`, `task:notification_dismiss`, `task:notification_tap_schedule`), and SSE transport (`network:sse` tag from `DioClient`) are wrapped with `beginTask` / `runTask` or structured performance logging so they show up in `LogsPage` filters and the relevant slowest-entry modals.
- **Persistence**: `ExperienceSettings.loggingEnabled` and `ExperienceSettings.performanceLoggingEnabled` (both default false) are the source of truth; `SettingsProvider.initialize()` syncs them into `AppLogger`, and `setLoggingEnabled()` / `setPerformanceLoggingEnabled()` update settings, push to `AppLogger`, and persist.
- **`LogsPage`**: In-app logs surface gated by `SettingsProvider.loggingEnabled` — when off it renders `_LogsDisabledState` with an `Enable logging` action; toolbar disables `Measure performance` and the performance filter while the global gate is off. Tag filter row offers common task/network/cache presets and a custom-tag action that opens a tag dialog; selecting any `task:*` tag switches the toolbar `Slowest` action from `Slowest performance logs` to `Slowest tasks` modal.
- **Legacy migration**: `ExperienceSettings.fromJson` upgrades older payloads by treating a persisted `performanceLoggingEnabled: true` without an explicit `loggingEnabled` key as a diagnostic opt-in (it implies `loggingEnabled: true`).

### Direct Follow-up Send Flow

- **Provider send path**: `chat_provider.dart` routes new and follow-up turns through the same `sendMessage()` / `prompt_async` path; local queued-envelope drain and `Send now` orchestration were removed in featR g5.
- **Composer action swap**: `chat_input_widget.dart` shows `Stop` only when the session is responding and the composer has no sendable draft; once text/attachments exist, the primary action switches back to direct send.
- **Server-backed feedback**: `chat_page_composer_status.dart` and `chat_page_composer_widgets.dart` present reasoning/receiving/retrying state from the active turn without inventing a client-side queued lifecycle.

### Read-Aloud / TTS

- **Settings**: `ExperienceSettings` stores non-secret provider/model/base URL/voice/locale/format preferences; existing persisted settings are preserved; `TtsApiKeyStorage` stores cloud TTS API keys separately per provider in secure storage.
- **Flow**: `chat_message_content.dart` extracts sanitized assistant text with `ReadAloudTextExtractor`, calls `ReadAloudService.speak()` with `SettingsProvider` read-aloud options, exposes loading/pause/resume/stop controls, and opens Settings > Text to speech on read-aloud control long-press.
- **Lifecycle**: ChatPage app/window lifecycle transitions leave ReadAloudService active so read-aloud is not stopped by inactive/hidden/paused/resumed state changes.
- **First-run defaults**: `SettingsProvider` applies `ReadAloudDefaultResolver` only when no `ExperienceSettings` JSON exists; Linux fresh installs select Edge experimental because native `flutter_tts` is unavailable, Windows/macOS/others select native when `ReadAloudService.isProviderAvailable(ReadAloudProvider.native)` succeeds, and native-unavailable installs fall back to Edge with a locale-mapped voice.
- **Backends**: `ReadAloudService` routes native, OpenAI-compatible, Edge experimental, ElevenLabs, and NVIDIA NIM providers; the generated-audio backends use `TtsBackend` adapters plus `TtsAudioPlayer` byte playback, while native uses `flutter_tts`; all providers share idle/loading/playing/paused service state. `TtsBackend.getVoices` accepts optional API key, base URL, and model parameters for provider-specific voice discovery.
- **Edge experimental**: `EdgeExperimentalTtsBackend` discovers Microsoft Edge/Bing Read Aloud voices, synthesizes directly over conditional websocket transport, and returns generated MP3 bytes.
- **ElevenLabs**: `ElevenLabsTtsBackend` discovers voices through the ElevenLabs API and synthesizes model-selected speech as generated MP3 bytes.
- **NVIDIA NIM**: `NvidiaNimTtsBackend` discovers deployment voices and synthesizes model/language-selected speech through the configured NIM base URL as generated WAV bytes.

### Session Attention Overlay Workflow

- `ChatProvider` produces root-session attention candidates; `SessionAttentionCoordinator` tracks timing and availability.
- `SessionAttentionCompletionResolver` writes completed-response snapshots through `SessionAttentionSnapshotStore` and DI publishes host snapshots.
- Android uses `MainActivity` and `SessionOverlayService`; desktop uses a child-window IPC host; iOS mounts the shared overlay in `ChatPage`.
- `SessionAttentionOverlay` routes open, read, dismiss, presentation-toggle, and stop actions through its host/controller.

### Android Background Monitoring

- **Native foreground service** (`android/app/src/main/kotlin/com/verseles/codewalk/CodeWalkForegroundService.kt`):
  Owns the ongoing Android monitor notification and receives MethodChannel-driven updates.
- **Dart bridge** (`android_foreground_monitor_service.dart`): Calls `codewalk/system`
  channel methods (`updateForegroundNotification`, `stopForegroundService`) and keeps
  service state idempotent from Flutter side.
- **Runtime policy** (`settings_provider.dart` + `chat_page_lifecycle.dart`): Gates Android
  monitoring behind the master setting and known active work; disabling it cancels probes and stops the monitor notification.
- **Battery optimization UX** (`android_battery_optimization_service.dart` +
  `notifications_settings_section.dart`): Queries and requests optimization exemption from
  Settings to reduce background task interruptions on Android.
- **Permission auto-approve context** (`permission_auto_approve_runtime.dart` +
  `chat_page_lifecycle.dart`): Primes/clears `PermissionAutoApproveBackgroundContext` via
  `AndroidBackgroundAlertWorker.primePermissionAutoApproveContext()` /
  `clearPermissionAutoApproveContext()` to maintain permission continuity when app goes to
  background; controlled by `composerAutoApprovePermissions` setting; auto-drains visible
  permission requests with cooldown tracking and respects `isRespondingInteraction` guard.

### Favorite Models

- **Storage key**: `favoriteModelsKey` in `AppConstants` (`app_constants.dart`).
- **Local persistence**: `AppLocalDataSource` exposes `getFavoriteModelsJson` /
  `saveFavoriteModelsJson`; current provider loading stores favorites server-scoped so they are shared across projects on the same server.
- **Provider state**: `ChatProvider._favoriteModelKeys` list, getter `favoriteModelKeys`,
  query method `isModelFavorite`, and toggle method `toggleModelFavorite` (local-only, no
  remote sync). Loaded and persisted in `chat_provider_preference_ops.dart` alongside
  recents, usage counts, and variant map.
- **Model selector UI** (`chat_page_model_selector_runtime.dart`):
  - `_buildFavoriteModelEntries` builds the "Favorites" section from provider state.
  - `_modelSelectorTrailing` renders a star toggle + checkmark trailing widget for every
    model row (favorites, recents, and provider sections).
  - The bottom sheet shows Favorites > Recent > Provider sections; favorites are excluded
    from recents and provider groups to avoid duplicates.
  - Variant popover auto-fits width using `TextPainter` to measure the longest label.
- **Keyboard shortcut** (`chat_page_shortcuts.dart`): `_cycleRecentModel` now cycles
  favorites first, then recents (deduped), before falling back to the current provider's
  model list.

### Onboarding Wizard

- **Gate**: `AppShellPage` shows `OnboardingWizardPage` when no server profiles exist and
  `skipOnboardingWizard` is false; navigation back to the shell happens automatically via
  `Consumer2` rebuild when a profile is added.
- **Steps**: Welcome (connect or need-help paths) -> Server Setup (optional `ServerSetupQuickGuide`
  + connection form with URL/label/auth/AI-titles, plus a Tailscale toggle `_tailscaleEnabled` and
  Tailscale auth panel `_buildTailscaleAuthPanel()`) -> Ready (success or retry). The wizard stays
  visible through the Ready step and can persist a pending post-onboarding chat tour handoff.
- **Tailscale auth panel** (`_buildTailscaleAuthPanel()`): Renders per-state UI — `needsLogin`
  shows an authenticate button, `needsMachineAuth` shows an admin approval message, `connected`
  shows a success state. The toggle enables/disables Tailscale for the connecting server profile.
- **`ServerSetupQuickGuide`** (`servers_settings_section.dart`): Reusable stateless widget showing
  quick-start instructions and a copyable `opencode serve` command. Used by both the onboarding
  wizard and the Settings > Servers add/edit dialog.
- **Android loopback mapping**: Both the wizard and the servers section map `localhost`/`127.0.0.1`
  to `10.0.2.2` on Android emulator builds.
- **Skip persistence**: User can skip the wizard with an optional "Don't show again" checkbox,
  which calls `SettingsProvider.setSkipOnboardingWizard(true)`.

### Post-Onboarding Chat Tour

- **Purpose**: First-use showcase tour that activates after successful onboarding completion,
  guiding users through key UI elements before their first interaction.
- **Persistence**: `SettingsProvider.pendingPostOnboardingChatTour` flag controls handoff state;
  set during onboarding completion and cleared only after tour finishes or is dismissed.
- **Auto-start scheduling**: Tour auto-start is queued from settings changes and chat-route return
  (`didChangeDependencies` / `didPushNext` lifecycle) instead of being scheduled from every chat build.
- **Phases**: Two-phase tour flow (`intro` → `composer`) managed in `ChatPage` via
  `_PostOnboardingTourPhase` enum.
- **Tour targets**:
  - **Intro phase**: Drawer access (mobile), project context (sidebar), desktop sidebar menu,
    and New Chat button (`chat_page_chrome.dart`)
  - **Composer phase**: Chat input field and Send button (`chat_input_widget.dart`)
- **Implementation**: Uses `showcaseview` package with `ShowCaseWidget` wrapper in `ChatPage`;
  tour keys are `GlobalKey` instances passed to target widgets; responsive copy adapts to
  mobile/desktop layouts. Retries are run-token guarded so stale callbacks do not double-trigger
  after replay. Shared `ChatTourShowcase` widget provides MD3-compliant tooltip styling across
  all tour steps.
- **Replay action**:
  - **Primary**: Main Settings landing page includes a clearly reachable `Replay chat tour` action.
  - **Secondary**: Settings > About still offers the replay action as an alternative path.

### OpenCode Setup Debug Flow

- **Setup Debug State** (`app_provider.dart`): `SetupDebugSeverity` enum, `SetupDebugEntry` class,
  and provider state `_setupDebugEntries`, `_localSetupLogs`, `_localSetupInProgress`,
  `_localSetupMessage` capture installation/diagnostics events.
- **Recording**: `recordSetupDebugEvent()` captures events with source, message, severity, and
  timestamp; `exportSetupDebugReport()` generates a sanitized text report for clipboard sharing.
- **Navigation Entry Points**:
  - Onboarding wizard (step 1 quick-guide and step 3 local setup): "View setup debug" button
    opens `OpenCodeSetupDebugPage` via `_openSetupDebugPage()`.
  - Settings > Servers section: "Setup Debug" button in Local OpenCode Server card opens
    the debug page for troubleshooting managed local server issues.
- **Debug Page** (`opencode_setup_debug_page.dart`): Displays current status, environment
  diagnostics (OpenCode, Node.js, npm, Bun, WSL availability), timeline of setup events,
  captured logs, and manual troubleshooting tips; supports copy-to-clipboard and clear actions.

### Update Install Flow (Android + Desktop)

- **`UpdateCheckResult.apkUrl`** (`update_check_service.dart`): GitHub release asset URL for the `.apk`; populated when the release includes an APK asset matching the architecture filter.
- **`UpdateInstallState`** (`settings_provider.dart`): Enum tracking download/install lifecycle — `idle → downloading → installing → done | failed`.
- **Automatic checks while open** (`settings_provider.dart`): `checkUpdatesOnOpen` runs a silent startup check and schedules an hourly `Timer.periodic` check while the app stays open.
- **`SettingsProvider.startInstall()`**: Android downloads the APK to a temp file via Dio `saveFile`, then calls `OpenFilex.open()` to trigger the system installer; desktop runs the install script and marks `done|failed`. Guards against re-entry when already downloading/installing.
- **`SettingsProvider.restartDesktopApp()`**: Desktop-only relaunch helper used by snackbar action; attempts detached relaunch and then exits current process.
- **`AppShellPage` reactions**: Observes `installState` transitions; shows Android downloading progress snackbar, desktop installing indefinite snackbar, done snackbar with desktop `Restart` action, and failed retry snackbar; the update toast "Install" action calls `startInstall()`.
- **`SettingsUpdateAvailableCard` controls**: Shared by the Settings landing page and `AboutSettingsSection`; renders inline progress indicators and retry/install buttons reflecting `installState`, falls back to the release URL when direct install is unsupported, and delegates direct installs to `settings.startInstall()`.

### Performance & Animations

- **Performance Architecture**:
  - **ChatProvider microtask coalescing**: `_notifyScheduled` / `_scrollScheduled` flags gate `scheduleMicrotask` so that multiple state mutations within the same frame produce only one `notifyListeners()` / scroll-to-bottom call.
  - **Event dedup buffer**: `_recentEventIds` (circular `Queue<String>`) in ChatProvider stores recent event keys built by `_composeEventDeduplicationKey`.
  - **Render gate**: `_hasPendingRenderFlush` in ChatProvider suppresses `notifyListeners()` while the app is in background.
  - **ChatMessageWidget build-skip cache**: Converted from `StatelessWidget` to `StatefulWidget`; completed messages short-circuit `build()` by returning a cached widget tree.
  - **Per-session hydrated timeline cache**: ChatPage keeps `_sessionTimelineEntriesCache` to store grouped timeline presentation per session, enabling instant reopen without full visual rebuild.
  - **Scoped desktop chat body**: Chat content, session panel, file pane, utility pane, and composer model controls each rebuild only when their own build-key typedef (`_ChatContentBuildKey`, `_SessionPanelBuildKey`, `_FilePaneBuildKey`, `_DesktopUtilityPaneBuildKey`, `_ComposerSelectionBuildKey`) changes — composer provider/model/agent/variant selection no longer rebuilds the full desktop shell (`chat_page_types_part.dart`, `chat_page_scaffold.dart`, `chat_page_timeline_builder.dart`, `chat_page_file_explorer_controller.dart`).
  - **Instant reopen restore targets**: Reopening a cached session restores to the latest revealable assistant response for settled sessions, or anchors to the bottom for active sessions.

- **Chat Entrance Animations**:
  - **Staggered Message Entrance**: Tail message entrance is coordinated via `chat_page_timeline_builder.dart` and `message_entrance_animation.dart`.
  - **In-bubble Part Entrance**: Streamed part entrance is handled in-bubble via `chat_message_widget.dart`, `chat_message_part_dispatch.dart`, and `PartEntranceAnimation`.
  - **Animation tokens**: `AppAnimations` defines userBubble (130 ms) and assistantBubble (180 ms) motion profiles.
  - **Regression Coverage**: `test/widget/chat_message_widget_test.dart` ensures stable animation behavior and part-dispatch logic.

### OpenCode Custom Agents

- `.opencode/agents/opencodeNews.md` is a repo-local agent invoked via `@opencodeNews` to analyze OpenCode release impact on CodeWalk.

### Material You Design System

- **Theme control** (`main.dart`): `DynamicColorBuilder` resolves color scheme from platform
  dynamic color (when enabled and available) or from user-selected `BrandColor` seed. User
  preferences (`themeMode`, `useDynamicColor`, `useAmoledDark`, `customColorSeed`, `contrastLevel`,
  `checkUpdatesOnOpen`) are stored in `ExperienceSettings` and exposed via `SettingsProvider`. When `useAmoledDark` is
  enabled, `_applyAmoledDarkScheme()` overrides all surface colors to `Colors.black` in dark theme.
- **BrandColor** (`brand_colors.dart`): Enum with 5 curated seed colors (Indigo, Teal, Rose,
  Amber, Slate) used when dynamic color is unavailable or disabled.
- **AppShapes** (`app_shapes.dart`): Centralized MD3 shape constants consumed by `AppTheme`
  and individual widgets for consistent rounded corners.
- **WindowSizeClass** (`window_size_class.dart`): Enum (`compact`, `medium`, `expanded`,
  `large`, `extraLarge`) derived from MD3 breakpoints. `BuildContext.windowSizeClass` extension
  replaces hardcoded width checks in `ChatPage` and `SettingsPage`.
- **Settings UI** (`appearance_settings_section.dart`): Theme mode, color picker (brand colors
  + dynamic color toggle), contrast level cards, a Composer tips toggle, and a **Visual style**
  `SegmentedButton<VisualStyle>` (issue #86, `settings_visual_style_segmented` value key) with
  Classic/Refined segments that calls `settingsProvider.setVisualStyle` to persist the choice in
  the Appearance section. `about_settings_section.dart` contains a `SwitchListTile` for the `checkUpdatesOnOpen`
  toggle that controls startup update checks. Dynamic color availability is read from `settingsProvider.dynamicColorAvailable`
  (runtime signal set by `DynamicColorBuilder` in `main.dart`) instead of a heuristic; contrast
  slider is disabled when dynamic color is active. Composer tips visibility is shared with the
  Chat Display popover toggle through `settingsProvider.showComposerTips`.
- **Visual style layer (issue #86)**: `VisualStyle` (`classic` / `refined`) is persisted via
  `ExperienceSettings` (`visualStyleKey`/`visualStyleFromKey` for JSON) and exposed by
  `SettingsProvider.visualStyle` + `setVisualStyle()`. New installs default to
  `VisualStyle.refined`; legacy persisted JSON missing the `visualStyle` key falls back to
  `VisualStyle.classic` for backward compatibility. `main.dart` reads `settingsProvider.visualStyle`
  and forwards it to `AppTheme.lightFrom`/`darkFrom` (which still accept an optional `visualStyle`
  that defaults to `VisualStyle.classic` at the API level) together with the resolved `OpenCodeThemeTokens`,
  so markdown/syntax palettes stay OpenCode-backed while shape/surface/border tokens come from
  `AppVisualStyleTokens`. `AppVisualStyleTokens` is a `ThemeExtension` exposing surface colors,
  radii, divider/border widths, and a composer shadow with `classic`/`refined` factories plus
  `copyWith`/`lerp`; `ThemeData.visualStyleTokens` is the consumer-side extension getter (falls
  back to classic when absent). High-impact chat surfaces consume it via `theme.visualStyleTokens`
  or `Theme.of(context).visualStyleTokens`: `chat_input_widget.dart`, `chat_input/chat_input_suggestion_popover.dart`,
  `chat_message_widget.dart`, `chat_message/{chat_message_content,chat_message_tool_part,chat_message_file_part,chat_message_info_parts}.dart`,
  `chat_page/{chat_page_scaffold,chat_page_composer_widgets,chat_page_timeline_runtime,chat_page_status_presenter}.dart`,
  and `chat_session_list.dart`. Tests: `test/unit/domain/experience_settings_test.dart`,
  `test/unit/providers/settings_provider_test.dart`, `test/unit/presentation/app_theme_test.dart`,
  `test/widget/settings_page_test.dart`, `test/widget/chat_message_widget_test.dart`, and
  `test/widget/chat_page_test.dart`.

### LaTeX Math Rendering (v1.83.0)

- **New dependency**: `flutter_math_fork ^0.7.4` — pure Dart port of KaTeX for client-side math rendering.
- **Custom markdown syntaxes** (`lib/presentation/utils/math_markdown.dart`):
  - `InlineMathSyntax` — matches `$...$` inline expressions (requires at least one LaTeX token to reject currency and shell variables).
  - `BlockMathSyntax` — matches `$$...$$` block expressions on separate lines.
  - `SingleLineBlockMathSyntax` — matches `$$...$$` on a single line.
  - `InlineMathBuilder` / `BlockMathBuilder` — `MarkdownElementBuilder` implementations that render math via `MathExpressionWidget`.
- **Math rendering widget** (`lib/presentation/widgets/math_expression_widget.dart`): Renders LaTeX via `flutter_math_fork`'s `Math.tex`; falls back to styled monospace source view on parse failure. Supports inline (`MathStyle.text`, baseline-aligned) and block (`MathStyle.display`, centered in a Card) modes.
- **Setting**: `showMathRendering` (`ExperienceSettings`) with `setShowMathRendering()` on `SettingsProvider`; defaults to `true`. Toggle UI in Appearance settings (`settings_toggle_math_rendering`).
- **Chat pipeline integration** (`chat_message_text_part.dart`): Conditionally wires math syntaxes and builders into the markdown rendering chain when `showMathRendering` is enabled.

### Session Export Service

- **`SessionExportService`** (`lib/presentation/services/session_export_service.dart`): Serializes
  a full session timeline to Markdown and JSON for local export. The Markdown export renders
  messages with role headers, text content, tool calls, and reasoning blocks. The JSON export
  omits `local_user_*` IDs from user messages to comply with ADR-023 (contract-first compatibility).
  The service is scoped to the `presentation/services/` layer and consumed directly from provider-level
  export triggers or UI actions.

### Files Micro File Manager (issue #89)

- **Service** (`lib/presentation/services/workspace_file_operations_service.dart`): `WorkspaceFileOperationsService` exposes `getCapabilities` (per `serverScopeKey::directory` cache), `invalidateCapabilities`, and `createFile`/`createFolder`/`rename`/`delete`/`writeFile`. Each probe or mutation uses an ephemeral `/session` lifecycle and sends the shell request with the active project `directory` query; cancellation/failure aborts the server-bound operation before the ephemeral session is torn down. Shell output is interpreted by the official OpenCode tool-state parser rather than ad-hoc response traversal. The capability probe resolves the server-side working directory with `pwd -P` and records `shellFileOpsSupported`; empty/literal `/` roots are rejected before probing, canonical `pwd -P` `/` returns `outsideRoot`, and mutation results with `unavailable`/`malformedResponse` invalidate the cache. Logs retain privacy-safe operation diagnostics.
- **Result codes** (`WorkspaceFileOperationCode`): `ok`, `unavailable`, `invalidName`, `outsideRoot`, `rootDeleteBlocked` (root self-delete), `missing`, `alreadyExists`, `permissionDenied`, `notDirectory`, `failed`, `malformedResponse`. Delete additionally refuses the project root and reuses the cached capability result before running the script.
- **UI surface** (`lib/presentation/widgets/file_tree_context_menu.dart`, `chat_page_file_runtime.dart`, `chat_page_file_explorer_controller.dart`, `chat_page_local_models_part.dart`): `FileTreeContextMenuRegion` wraps each node row with desktop secondary-click / mobile long-press handling; `FileTreeContextMenuActionType` covers `newFile`/`newFolder`/`rename`/`delete`/`copyPath`/`refresh` (Material Symbols via `fileTreeActionIcon`). The file explorer header keeps the existing refresh and Quick Open controls, and adds the New menu (`file_tree_new_button`) with New File / New Folder entries only when `_fileMutationsSupported` (driven by `_FileExplorerContextState.fileOperationCapabilities`) reports `shellFileOpsSupported`; mutation handlers validate the name in a dialog, call the service with absolute/relative path reconciliation, then force-refresh the affected directory and surface `filesInvalidName`/`filesOutsideRoot`/`filesRootDeleteBlocked`/`filesPathMissing`/`filesAlreadyExists`/`filesPermissionDenied`/`filesOperationUnavailable`/`filesOperationFailed` snackbars (with success variants `filesFileCreated`/`filesFolderCreated`/`filesRenamed`/`filesDeleted`/`filesPathCopied`). Rename + delete reconcile open tabs and per-path line selection maps via `_replacePathPrefix`, prune the directory subtree, and reset `pendingScrollToLine` when the active tab was removed.
- **DI**: `WorkspaceFileOperationsService` registered as a lazy singleton in `injection_container.dart` (`WorkspaceFileOperationsServiceImpl(dio: sl<DioClient>().dio)`); the runtime checks `di.sl.isRegistered` before probing so the file pane degrades gracefully when the service is absent.
- **Tests**: `test/unit/presentation/workspace_file_operations_service_test.dart` covers official tool-state parsing, malformed responses, shell quoting, capability cache/probe generation, unsafe-root refusal, canonical-root guards, server-bound abort/teardown, and create-file session teardown. `test/integration/workspace_file_operations_live_test.dart` is an opt-in local OpenCode probe covering probe/create/write/read/delete. `test/support/fakes.dart` provides `FakeWorkspaceFileOperationsService` (capability + per-operation result overrides plus call counters and `onCreate*`/`onRename`/`onDelete` hooks) plus queued file-list responses for refresh race tests. `test/widget/chat_page_test.dart` covers the file-tree UI: header New menu, create dialogs, rename row reconciliation, delete confirmation, long-press menu behavior, in-flight forced refresh, and absolute-vs-relative path resolution.

### File Editor and Write Support (issue #90)

- **Editor library**: `re_editor ^0.10.0` (CodeEditor/CodeLineEditingController/CodeScrollController) and `re_highlight ^0.0.3` (Mode + per-language modes: bash, c, cpp, csharp, css, dart, dockerfile, go, java, javascript, json, kotlin, makefile, markdown, php, plaintext, powershell, python, ruby, rust, scss, shell, sql, swift, typescript, xml, yaml) added to `pubspec.yaml`; chat_page.dart imports the bundle and exposes `_resolveEditorLanguageMode(language)` / `_resolveHighlightLanguage(path:, mimeType:)` / `_resolveHighlightTheme(context)` helpers.
- **Service write path** (`workspace_file_operations_service.dart`): `WorkspaceFileOperationsService.writeFile({serverScopeKey, rootDirectory, path, content})` reuses `_preparePathOperation` validation (outside-root + root-blocked) and the ephemeral shell transport; server-bound cancellation/failure aborts the active remote operation before cleanup. UTF-8 content is base64-encoded into 48 KiB environment chunks; the shell negotiates GNU, BSD, or Python decoding before staging an atomic, mode-preserving replacement. Tool-state parsing and privacy-safe operation logging are shared with the remaining workspace mutations.
- **Draft state** (`chat_page_local_models_part.dart`): `_FileEditorDraftState` owns the `CodeLineEditingController.fromText` + `CodeScrollController` for a single path, tracks `savedContent`, dirty/error state, autosave debounce state, and the active save, and provides `markSavedContent` / `replaceSavedContent` / `dispose`. `_FileExplorerContextState.editorDraftsByPath` is the per-context map; `resetForRoot` and `dispose` cancel/dispose per-path drafts and pending timers, while `removeEditorDraft` disposes a single entry.
- **Editor UI** (`chat_page_file_viewer.dart`): Tab header gets a dirty marker `*` when `_fileDraftIsDirty`; the focused viewer wraps a `CodeEditor` styled with `CodeEditorStyle` (monospace font, theme colors, line number gutter) and a `CodeHighlightTheme` keyed on the resolved language with `_maxHighlightedFileLength` ceiling. Text edits feed the per-path debounced autosave; Save button (`file_viewer_save_button`) and `Ctrl/Cmd+S` use the same save coordinator. Close/lifecycle paths cancel or hand off the pending timer and do not discard dirty or in-flight work. `_editorReadOnlyReason` returns a string when (a) UTF-8 content exceeds `_maxEditableFileLength` (64 KiB) — files open read-only for responsiveness, (b) capabilities are still loading, or (c) `shellFileOpsSupported != true` — the resolved message (or `filesOperationUnavailable`) is shown in an inline read-only banner. Empty non-binary files (`content.isEmpty`) are **not** gated out by the size check, so they open directly as editable drafts. `_canSaveFileDraft` requires dirty + not saving + UTF-8 byte length within `_maxEditableFileLength` + supported shell ops. Save gating (`_canSaveFileDraft`) and the save pipeline both gate on the current draft's UTF-8 byte length via `_isEditorContentTooLarge(draft.controller.text)`; when the gate trips, the static `_draftTooLargeSaveMessage` (`Draft is too large to save from the editor.`) is shown inline and surfaces as a snackbar. `pendingScrollToLine` is a general open-file scroll-to-line target on `_FileExplorerContextState` — when set (e.g. by open-with-line), the viewer clears it and schedules a `makeCenterIfInvisible` on the draft's scroll controller after the first frame.
- **Draft source-of-truth sync**: `_editorDraftForContent` reuses a per-path draft and, when the incoming `content` differs from `draft.savedContent` and the draft is still clean, schedules a `WidgetsBinding.instance.addPostFrameCallback` that re-checks `mounted`, that the draft entry is the active one, that it is still clean, and that `savedContent` still mismatches before calling `replaceSavedContent(content)` so the controller tracks the latest server content without clobbering in-progress edits.
- **Selection-to-context** (`filesAddChat`): the selection action bar reads current editor text via `_currentFileEditorText(fileState, path, fallback: active.content)` and passes it into `_addSelectionToContext`, which splits the draft via `_splitFileEditorLines(content)` (`content.split(RegExp(r'\r\n|\r|\n'))`) to preserve LF / CRLF / CR line-break style, then groups the selected lines into contiguous `(start, end)` ranges and emits one `FileInputPart` per range. This keeps Add-to-chat aligned with what is in the draft instead of the cached tab content.
- **Save pipeline** (`chat_page_file_runtime.dart`): `_saveFileEditorDraft` is the shared manual/autosave path; it coalesces per-path saves, awaits an active save instead of short-circuiting, and allows close to perform a bounded follow-up save when newer edits arrive; only a clean draft short-circuits. It checks DI registration and `_fileMutationsSupported` (snackbars `filesOperationUnavailable` if unsupported); gates UTF-8 content at `_maxEditableFileLength` (64 KiB) and surfaces `_ChatPageFileViewer._draftTooLargeSaveMessage` (`Draft is too large to save from the editor.`) inline and via snackbar; sets `isSaving=true` + clears error; awaits `WorkspaceFileOperationsService.writeFile(serverScopeKey, rootDirectory, path, content)`; on failure sets `saveErrorMessage` via `_fileOperationErrorLabel(result.code)` and surfaces a snackbar; on success calls `markSavedContent`, updates the cached `_FileTabViewState` (preserving mimeType), and snackbars success. Close/lifecycle teardown cancels pending debounce timers and ignores stale completions when a draft is swapped or the page is unmounted.
- **Dirty-aware reconciliation**: `_reloadFileTab` blocks dirty editor drafts before a reload can swap content — paths with dirty drafts skip the swap and set `saveErrorMessage` to the static string `Unsaved changes; reload skipped.`; diff-aware silent reloads reach that same guard via `_reconcileFileContextWithSessionDiff`, which invokes `_reloadFileTab(silent: true)` per matched tab path. `_reconcileRenamedFileTreePath` remaps `editorDraftsByPath` keys via `_replacePathPrefix`; `_reconcileDeletedFileTreePath` removes and disposes drafts for the deleted path or subtree, and clears `tabSelection.activePath` if the active tab was removed. Close and path mutation guards preserve dirty drafts and coordinate with active saves.
- **Tests**: `test/unit/presentation/workspace_file_operations_service_test.dart` covers write-path validation, 48 KiB content chunking, negotiated GNU/BSD/Python decoder selection, and server-bound abort/teardown behavior. `test/integration/workspace_file_operations_live_test.dart` is an opt-in local OpenCode probe/create/write/read/delete integration test. `test/support/fakes.dart` adds `writeFileResult`, `writeFileCallCount`, and `onWriteFile` hook to `FakeWorkspaceFileOperationsService`. `test/widget/chat_page_test.dart` covers file-editor autosave timing, per-path draft isolation, active-save coordination, lifecycle/close guards, CRLF round-trip, current-draft Add-to-chat, dirty-state failure/rename guards, and editable empty text files.
