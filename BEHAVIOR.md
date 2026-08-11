# Behavior Specification

> How CodeWalk behaves from the user's perspective.
> Only documents **current, implemented** behavior. Planned features live in GitHub Issues.

---

## Internationalization (i18n)

### Language selection

- **Given** the user is in Settings > Behavior
- **When** the user opens the Language selector
- **Then** the app shows `System default` plus all 14 supported languages with native script display names
- **Then** selecting a language applies immediately and persists across app restarts
- **Then** selecting `System default` makes CodeWalk follow the device locale

### Locale fallback

- **Given** the device locale is a regional variant (e.g. `pt_BR`)
- **When** CodeWalk resolves the active locale
- **Then** `pt_BR` falls back to the `pt` (Brazilian Portuguese) locale
- **Then** unsupported locales fall back to English

### Supported locales

- `ar` (Arabic — RTL), `bn` (Bengali), `de` (German), `en` (English), `es` (Spanish), `fr` (French), `hi` (Hindi), `it` (Italian), `ja` (Japanese), `ko` (Korean), `pt` (Brazilian Portuguese), `ru` (Russian), `zh` (Simplified Chinese), `ur` (Urdu — RTL)

### Quota/rate-limit popover static UI copy is localized

- **Given** the user has selected a non-English locale in `Settings > Behavior`
- **When** the user opens the quota details from the `Context usage` status
- **Then** static UI copy in the popover is rendered in the active locale, including the `Rate limits` section title, loading state, the `OpenCode Go detected` setup card and its `Connect`/`Reconnect` actions, the `Pace` chip and its desktop tooltip / mobile snackbar, and the reset/refresh action labels
- **Then** provider names (e.g. `opencode-go`, `minimax-coding-plan`, `minimax-cn-coding-plan`, `cursor`, `ollama-cloud`, `Snowflake Cortex`, `Grok/xAI`, `Cohere North`) stay untranslated as server-defined identifiers
- **Then** window labels (rolling, weekly, monthly) and all server-originated quota values, units, and percentage figures stay untranslated (ADR-023 compliance)

### Non-translatable invariants

- OpenCode wire event types, permission key names, tool state values, `prompt_async` contract fields, REST paths, config key names, model/provider/agent identifiers, and server-originated content remain untranslated (ADR-023 compliance)

---

## Onboarding

### First launch shows setup wizard

- **Given** the app is opened for the first time (no servers configured)
- **When** the app starts
- **Then** a setup wizard is displayed requiring the user to configure at least one OpenCode server

### First-run setup choices adapt to local-server capability

- **Given** the first-run welcome step is visible
- **When** the runtime supports CodeWalk-managed local OpenCode setup
- **Then** the single primary action prioritizes managed local setup; connecting to an existing server remains secondary, and guided setup steps remain available
- **When** the runtime does not support managed local setup
- **Then** the single primary action prioritizes guided setup steps; connecting to an existing server remains secondary, and no disabled managed-local option is shown
- **Then** the welcome step keeps the CodeWalk/OpenCode relationship and its detailed explanation visible or discoverable
- **Then** server-management entry points outside first run, including Settings, retain the complete shared setup chooser

### Successful onboarding stays in the wizard through Ready

- **Given** the user finishes server setup successfully during onboarding
- **When** the connection is saved and the wizard advances to the final success state
- **Then** the onboarding flow remains visible through the `Ready` step instead of dismissing immediately when the first server profile is created
- **Then** the user gets an explicit action to continue into the main chat experience

### First-run managed local setup only completes while running

- **Given** the user chooses managed local setup during first-run onboarding
- **When** the local server is stopped or startup fails
- **Then** onboarding remains on local setup and cannot complete
- **When** startup succeeds, or an already-running local server continues
- **Then** the wizard goes through `Ready` before it can complete, revalidating that the server is still running around completion
- **Then** only that final successful first-run completion arms the post-onboarding chat tour; completing the same flow from Settings does not
- **When** the user goes back from `Ready`
- **Then** the wizard returns to local setup
- **Then** a delayed startup result cannot override navigation the user made after starting it

### Managed local OpenCode prefers the native Windows architecture

- **Given** CodeWalk manages the local OpenCode runtime on Windows ARM64
- **When** the OpenCode release publishes a Windows ARM64 CLI archive
- **Then** CodeWalk installs `opencode-windows-arm64.zip` instead of the x64 archive
- **When** the native ARM64 CLI archive is unavailable
- **Then** CodeWalk falls back to `opencode-windows-x64.zip`
- **Then** Windows x64, macOS, and Linux keep their existing platform-specific archive preferences, and Desktop application installers are never selected as managed CLI runtimes

### Successful onboarding can trigger a first-use chat tour

- **Given** the user leaves onboarding from the successful `Ready` step
- **When** the main chat screen opens for that first post-onboarding session
- **Then** the app starts a guided first-use tour that introduces how to open project/sidebar controls, start a new chat, use the chat input, and send a message
- **Then** the tour adapts its first step to the current layout, using drawer/sidebar access on compact screens and the relevant project/sidebar control on larger layouts
- **Then** the app keeps the one-time handoff armed while the chat surface is still mounting, instead of silently consuming the tour just because the targets were late to appear or a transient dismiss interrupted the first run
- **Then** the tour is only marked as seen after the user explicitly skips it or completes the full walkthrough
- **Then** the handoff runs only once for that successful onboarding completion unless a later onboarding success arms it again

### Chat tour can be replayed from the chat screen

- **Given** the user is already on the main chat screen
- **When** the user opens `Display toggles` from the chat app bar and chooses `Replay chat tour`
- **Then** the app restarts the same guided tour from the chat surface without requiring onboarding or data reset

### Chat tour can be replayed from Settings

- **Given** the user opens the main `Settings` screen from chat
- **When** the user taps the landing-page `Replay chat tour` action
- **Then** the app closes settings, re-arms the same replay flow, and returns to chat so the guided tour can start again without onboarding or data reset

### Chat tour can also be replayed from Settings > About

- **Given** the user cannot easily find the replay shortcut from the chat app bar
- **When** the user opens `Settings` > `About` and taps `Replay chat tour`
- **Then** the app closes settings, re-arms the same replay flow, and returns to chat so the guided tour can start again without onboarding or data reset

### First launch explains the OpenCode relationship

- **Given** the first-run setup wizard is visible
- **When** the welcome step is rendered
- **Then** the UI explains that CodeWalk is the client and OpenCode is the server or engine it needs before chat can work
- **Then** the setup paths describe whether the user should connect to an existing server, follow guided setup steps, or let CodeWalk manage a local desktop install

### OpenCode setup troubleshooting is separate from app logs

- **Given** the user is troubleshooting OpenCode installation or setup
- **When** the user opens the dedicated setup debug surface from onboarding or server settings
- **Then** the app shows OpenCode-specific diagnostics, setup events, and captured setup logs
- **Then** this surface remains separate from the general `App Logs` screen used for CodeWalk runtime logs

### Failed onboarding/server setup health checks are diagnostic, not blocking

- **Given** the user finishes the server-setup form during onboarding (or re-tests an existing saved profile) and the active health check fails (server unreachable, server still starting, wrong URL/port/auth, etc.)
- **When** the wizard advances to the final `Connection issue` step
- **Then** the saved profile is kept in `serverProfiles` and remains available for editing, activation, or removal from `Settings > Servers` after the wizard closes
- **Then** the failure screen treats the failed health check as diagnostic, not a trap: the wizard stays open and exposes a primary continue action plus dedicated recovery paths so the user always has a way out
- **Then** the screen shows the captured connection error (or a generic `Server connection could not be verified.` fallback) and a reminder that a server can also be added later from `Settings > Servers`

- **Given** the onboarding failure screen is visible
- **When** the user taps the primary `Start using <AppName>` action (or `Done` when the wizard is opened from `Settings`)
- **Then** the wizard activates the saved profile as the active server using `setActiveServer(blockUnhealthy: false)` and completes onboarding without re-prompting for the same URL
- **Then** the app enters a degraded/no-healthy-server state: settings, setup debug, and other non-server-backed surfaces remain reachable, and chat remains limited (composer blocked, server status reports `Offline`) until the active server becomes healthy

- **Given** the onboarding failure screen is visible
- **When** the user taps `Add Server`
- **Then** the form resets to the platform default URL suggestion and the wizard returns to the server-setup step so the user can configure another server profile
- **Then** the previously failed profile is not deleted or replaced — it stays in `serverProfiles` and can still be edited, retried, or removed later from `Settings > Servers`

- **Given** the onboarding failure screen is visible
- **When** the user taps `Open settings`
- **Then** the wizard pushes `Settings > Servers` so the user can edit the failed profile, add a different server, or remove it
- **Then** returning from `Settings > Servers` brings the user back to the failure screen with the failure context preserved

- **Given** the onboarding failure screen is visible
- **When** the user taps `Try again`
- **Then** the wizard returns to the server-setup step and re-runs the health check against the saved profile without creating a duplicate server profile

- **Given** the onboarding failure screen is visible
- **When** the user taps `Choose another path`
- **Then** the wizard returns to the welcome step so the user can pick a different setup path (connect to a running server, follow guided local setup, or let CodeWalk manage a local desktop install)

- **Given** the onboarding failure screen is visible
- **When** the user taps `View setup debug`
- **Then** the dedicated OpenCode setup debug surface opens so the user can inspect platform diagnostics, setup events, and captured setup logs without leaving the failure context

- **Given** the user activates an unhealthy saved profile from the onboarding failure screen
- **When** the app is now in the degraded/no-healthy-server state
- **Then** the user is never trapped: chat-side composer and send actions remain blocked and the reason is surfaced (matches `Server goes offline during use`), but the user can still open `Settings > Servers`, add another server, retry the saved profile, or return to setup debug from the degraded chat surface
- **Then** chat functionality returns automatically as soon as the active server's health check reports a healthy status — no re-onboarding or app restart is required

### No server = no functionality

- **Given** no server profile is configured (zero saved profiles)
- **When** the user tries to access any feature
- **Then** the app blocks access — configuring a server is a prerequisite for all functionality
- **Then** this hard block only applies when there are no saved profiles; a saved but unhealthy profile no longer blocks access and instead lets the user enter a degraded state (see `Failed onboarding/server setup health checks are diagnostic, not blocking` and `Server goes offline during use`)

### No-server chat state is stable and actionable

- **Given** no server is configured and the chat screen is visible (for example, onboarding was skipped/dismissed)
- **When** the screen initializes
- **Then** startup connection checks are skipped (no transient connection-error flicker)
- **Then** the main area shows a dedicated empty state with `No server configured yet`
- **Then** a `Set up server` button opens the setup wizard directly in the server-connection flow

### Degraded chat state with a saved-but-unhealthy server is actionable

- **Given** at least one server profile is saved and currently active, but its health check is unhealthy (for example, after the user continues from the onboarding failure screen with `Start using <AppName>`)
- **When** the chat screen initializes or becomes active
- **Then** startup connection checks still run but do not flash a transient error state during the normal health probe window
- **Then** the active server status control shows `Offline` so the user can tell why chat is limited
- **Then** the main chat area still surfaces the existing scoped recovery path (`Settings > Servers`, add another server, retry, view setup debug) instead of leaving the user in a dead end

---

## Servers

### Multiple server profiles

- **Given** the user is in server settings
- **When** the user adds a new server profile (local, remote, work, etc.)
- **Then** the profile is saved and the user can switch between profiles at any time

### Automatic health checks

- **Given** server profiles are configured
- **When** the app is active
- **Then** by default the app checks each server's health every 10 seconds and shows a visual online/offline indicator
- **Then** when standard `Cellular data saver` is active on mobile data, automatic foreground health checks slow to one burst every 1 minute and prioritize the active server only
- **Then** when aggressive `Cellular data saver` is active on mobile data, automatic foreground health checks use the aggressive 30-second cadence and still prioritize the active server only

### Cellular data saver indicator

- **Given** `Cellular data saver` is enabled and the current connection is mobile/cellular
- **When** throttling is active
- **Then** the mobile hamburger button shows a low-priority saver badge when no higher-priority alert/loading badge is active
- **Then** the server status control also shows a compact `Saver` chip so the throttled state stays visible after opening the drawer/sidebar
- **Then** when the mobile drawer is opened while that saver badge is active, a compact notice above `Conversations` explains that cellular data saver is active and links to `Settings` > `Behavior`

### Active server status is simplified to Online / Delayed / Offline

- **Given** the active server status control is visible in the chat chrome
- **When** active server health changes
- **Then** the control shows `Online` with a green indicator when the active server health check is healthy
- **Then** the control shows `Delayed` with an orange indicator only while the active server health is still unknown
- **Then** the control shows `Offline` with a red indicator when the active server health check is unhealthy
- **Then** reconnect/degraded chat sync state is reported through the dedicated sync indicator or hamburger loading state instead of overriding a healthy active server summary
- **Then** the closed control and expanded server menu derive the active server status from the same `ServerHealthStatus` source
- **Then** the compact status text is rendered immediately after the server name instead of being pushed to a far-right metadata slot

### Unhealthy server warning waits for confirmation

- **Given** the active server becomes unhealthy or resume-time connectivity is still settling
- **When** warning-only UI is evaluated
- **Then** the app keeps the short foreground grace window for stale resume probes
- **Then** the unhealthy snackbar waits an additional 5-second debounce before appearing
- **Then** if the server recovers before those windows finish, the unhealthy snackbar is not shown

### Foreground resume sync warnings are debounced

- **Given** the app returns to the foreground after mobile or desktop backgrounding
- **When** the previous realtime signal is stale or the realtime subscription is restarting
- **Then** CodeWalk keeps the chat sync status out of `Reconnecting` / `Sync delayed` for the configured resume grace period, defaulting to 5 seconds and clamped to 0-30 seconds
- **Then** a fresh realtime signal during that grace window cancels the pending warning and keeps chat sync `Online`
- **Then** if the grace period elapses without a fresh realtime signal, the existing delayed/degraded sync behavior is allowed to surface
- **Then** backgrounding the app again cancels the pending resume warning so it cannot fire after the app has left the foreground

### Server goes offline during use

- **Given** the active server goes offline while the user is chatting
- **When** the connection is lost
- **Then** the composer input is blocked and the reason is displayed to the user
- **Then** the user cannot send messages until the connection is restored

### Cloudflare Access OAuth is supported on desktop and Android

- **Given** a user on desktop or Android configures a server profile protected by Cloudflare Access Managed OAuth
- **When** the user enables Cloudflare Access OAuth for that profile
- **Then** CodeWalk binds a real ephemeral local callback on `127.0.0.1` before Dynamic Client Registration or browser launch
- **Then** the same exact redirect URI, including its ephemeral port and callback path, is reused for registration, authorization, callback validation, and token exchange
- **Then** desktop opens authorization in the external system browser
- **Then** Android opens authorization in a browser-owned AndroidX Custom Tab and falls back only to an external browser when Custom Tabs are unavailable
- **Then** closing the Android Custom Tab before the callback promptly cancels that OAuth attempt, while the `ACTION_VIEW` external-browser fallback has no close signal and retains the existing callback timeout
- **Then** OAuth uses authorization code + PKCE authentication
- **Then** the callback accepts only an exact GET request for the expected origin, port, and raw path
- **Then** the callback requires one non-empty matching state and exactly one non-empty authorization code or provider error
- **Then** unrelated callback paths are non-terminal and callback completion is single-use
- **Then** OAuth credentials are stored in platform secure storage scoped to that server profile and URL
- **Then** if the OAuth-enabled profile is removed, disabled, or changes URL while authorization is in flight, the stale result is discarded and its credential is neither retained nor applied
- **Then** Cloudflare OAuth and OpenCode Basic Auth are mutually exclusive profile modes in this release
- **Then** logs and errors do not expose OAuth secrets or raw provider/token responses
- **Then** iOS and web users do not get this OAuth flow and should use Basic Auth or another supported access path

### Cloudflare Access OAuth challenge recovery

- **Given** an OAuth-enabled server profile receives a Cloudflare Access 401/403 challenge
- **When** CodeWalk detects the challenge during health or connection checks
- **Then** the profile records the challenge and the user can re-authenticate from server settings
- **Then** successful re-authentication updates only the matching profile and does not leak tokens to other profiles or hosts

### Tailscale transport is profile-scoped

- **Given** a user configures a server profile on Android, iOS, Linux, or macOS
- **When** the user enables Tailscale for that profile
- **Then** CodeWalk routes OpenCode API and SSE traffic through the embedded userspace Tailscale node instead of requiring a system VPN
- **Then** Basic Auth or Cloudflare Access OAuth can still own authentication because Tailscale only owns transport
- **Then** inactive Tailscale profiles report unknown health instead of starting additional Tailscale nodes
- **Then** when Tailscale requires login or machine approval, onboarding and server settings show the Tailscale authentication URL and let the user copy it
- **Then** tapping the Tailscale authenticate action opens that URL in the external browser when the platform can launch it
- **Then** if the authentication URL cannot be opened, the app keeps the URL visible and shows an actionable failure message instead of silently blocking the flow
- **Then** Windows and web users do not get a broken Tailscale toggle

### Offline startup reloads initial data automatically after recovery

- **Given** an active server is configured but the app starts while that server is unreachable
- **When** connectivity and backend availability return while the chat screen remains active
- **Then** the app automatically retries the initial bootstrap flow without requiring pull-to-refresh or app restart
- **Then** the project list, sidebar session state, and initial session data reload from the recovered server state
- **Then** reconnect flapping is debounced so repeated short connection changes do not trigger duplicate bootstrap reloads

---

## Sessions

### Session lifecycle

- **Given** a connected server
- **When** the user interacts with sessions
- **Then** the user can **create**, **rename**, **archive**, **fork**, and **delete** sessions

### Active session header exposes official session actions

- **Given** an existing session is open in chat
- **When** the user opens the `Session actions` menu from the active session header
- **Then** the app exposes labeled actions for share/unshare, copy share link when available, view tasks, review changes, undo, redo, and compact context
- **Then** task and review actions open a dedicated session-details surface without requiring slash commands or sidebar knowledge
- **Then** unavailable actions are disabled instead of invoking broken flows

### Archiving a root session hides descendant sessions from the active list

- **Given** the active Conversations filter is `Active` and a root session has child/subsessions
- **When** the user archives that root session
- **Then** the root session disappears from the active list immediately
- **Then** descendant sessions of that archived root are also hidden from the active list so they do not remain orphaned as top-level rows

### New Chat opens as draft immediately

- **Given** a connected server and the chat screen is open
- **When** the user taps `New Chat` (or uses the equivalent shortcut/command)
- **Then** the composer opens immediately in a draft state without waiting for remote session creation
- **Then** the session is created lazily on the first send action
- **Then** if `New Chat` is tapped from the mobile Conversations drawer, the drawer closes so the clean draft composer is visible immediately

### New Chat draft is not replaced by background refreshes

- **Given** the user is in `New Chat` draft mode (no active session selected yet)
- **When** session snapshots, SWR revalidation, or realtime events from other sessions arrive
- **Then** draft mode remains active and the app does not auto-switch back to another session
- **Then** draft mode remains visible until the user sends the first message or explicitly selects another session

### New Chat draft skips the select-or-create empty state

- **Given** `New Chat` draft mode is active
- **When** the chat timeline is rendered
- **Then** the app does not show `Select or create a conversation to start chatting`
- **Then** the draft-ready chat view remains visible so the user can start typing/sending immediately

### Fork creates an independent copy

- **Given** an existing session with conversation history
- **When** the user forks the session
- **Then** a new independent session is created as a full copy of the session at the moment of the fork action — changes to either session do not affect the other

### Sessions are scoped to a project

- **Given** the user has multiple projects/folders
- **When** the user switches to a different project
- **Then** the visible session list changes to show only sessions belonging to that project

### Project context picker is folder-first

- **Given** the user opens the project context picker (`Choose Directory`)
- **When** the user interacts with context options
- **Then** the UI uses project/folder language only (no workspace distinction in this flow)
- **Then** the action `Open project folder...` allows opening any folder as project context, including non-Git folders
- **Then** `Open project folder...` presents directory browsing as the primary action while keeping manual path entry available
- **Then** the path that will be opened is shown before confirmation, so the user can verify the full project directory instead of only a folder name
- **Then** inline fuzzy folder suggestions backed by OpenCode directory search preserve and select the full path when tapped
- **Then** tapping a project row switches/reopens that context immediately and closes the picker without requiring a secondary open action
- **Then** removing a closed project from history hides that exact project path from the closed-project history across reloads until the user explicitly reopens or re-enters that path again
- **Then** selector actions are serialized so repeated rapid taps do not trigger overlapping switch/reopen/close/archive operations

### Per-project icons are local and auto-discovered

- **Given** the user opens a project context or an already-open project row is shown in the sidebar or project context picker
- **When** CodeWalk renders that open project context
- **Then** CodeWalk scans that project's local directory tree for common application icons before web favicons, including Tauri `src-tauri/icons/*`, Electron `build/icon.*`, Flutter/React Native/native iOS/macOS `AppIcon.appiconset/*.png`, Flutter Windows `windows/runner/resources/app_icon.ico`, Flutter Linux `linux/runner/resources/app_icon.png`, Android `mipmap-*/ic_launcher*.png`, and common `icon.*`/`app_icon.*`/`logo.*` assets
- **Then** web favicon fallbacks include `favicon.ico`, `favicon.png`, `favicon.svg`, `favicon.jpg`, `favicon.jpeg`, `favicon.webp`, and common sized web icons under the project root, `web`, `public`, or `static`
- **Then** generated/heavy folders such as `.git`, `node_modules`, `dist`, `build`, `.dart_tool`, `.gradle`, `.next`, `.turbo`, `.cache`, `coverage`, `tmp`, `logs`, `Pods`, and platform build output folders are skipped
- **Then** `build/icon.*` is checked as a direct Electron build-resource candidate without traversing generated `build` output
- **Then** if multiple icons are found, known app-icon paths win over generic app assets, which win over web favicons; within the same priority, higher-resolution/density names and then the shortest relative path win
- **Then** supported icons up to 5 MB are copied into CodeWalk app support storage and rendered in project rows, recent-session project chips, and the project-context header
- **Then** ICO files are stored as PNG after local decoding; PNG, JPEG, SVG, and WebP bytes are stored as local app data without external network calls
- **Then** CodeWalk does not show a manual `Find project icon` action; closed project history rows keep the stored/default icon until reopened
- **Then** when no supported icon is found, the icon is unreadable/oversized, discovery is unavailable on the platform, or rendering fails, CodeWalk keeps the default `Symbols.folder_open` fallback
- **Then** OpenCode project payloads remain unchanged; icon metadata is CodeWalk-local personalization only

### Quick Open searches names and contents

- **Given** a connected server and an active project context
- **When** the user opens Quick Open from the chat chrome or shortcut
- **Then** the dialog offers `Names` and `Contents` search modes
- **Then** `Names` searches file and directory names through the OpenCode file search endpoint
- **Then** `Contents` searches file text through the OpenCode content search endpoint and shows path, line number, and matching line preview
- **Then** selecting a content result opens the matched file path while preserving the visible line context in the result subtitle

### File viewer edits and saves text files

- **Given** a connected server, an active project context, and shell-gated file operations supported for the project root
- **When** the user opens a non-binary text file from the file tree, Quick Open, or a tapped assistant file path
- **Then** the open-files surface renders a focused code editor with line numbers, syntax highlighting, tabbed open files, and the same desktop/mobile dialog behavior as the file viewer
- **Then** editing a file marks its tab dirty with `*` and enables the viewer `Save` action
- **Then** pressing the `Save` action or `Ctrl+S` / `Cmd+S` writes the active dirty file through the shell-gated workspace file operation service scoped to the active project directory, using one negotiated single-pipeline shell transport rather than a local client filesystem write
- **Then** global autosave is off by default and can be toggled by the user
- **Given** a dirty draft and autosave enabled
- **When** the draft has not changed for 30 seconds
- **Then** CodeWalk debounces and saves the draft automatically
- **Given** autosave is enabled and a draft is dirty
- **When** the editor loses focus, a dirty file is closed, or the app is controlled inactive, paused, minimized, or disposed
- **Then** CodeWalk flushes the eligible draft
- **Given** a dirty file has an in-flight save
- **When** the user closes it
- **Then** closing waits for that save to finish
- **Given** autosave is disabled
- **When** the setting changes
- **Then** pending debounce timers and lifecycle follow-ups are canceled
- **When** autosave is enabled again
- **Then** eligible dirty drafts are rearmed for autosave
- **Given** a draft is being saved
- **When** the user leaves its context
- **Then** the save remains bound to its owning server profile, project, root, and path
- **Then** leaving to another context on the same server flushes safely, while leaving to another server never writes the draft there
- **Given** the project root is reset while a draft is dirty or a save is in flight
- **When** the reset is requested
- **Then** the root reset is deferred until the draft is no longer dirty and the save has completed
- **Given** a file mutation is in progress
- **When** the server profile changes
- **Then** the mutation aborts, and Basic Auth remains bound to its request origin so credentials cannot leak to another server
- **Then** a successful save preserves the file's LF, CRLF, or CR line-ending style, clears the dirty marker, updates the open tab's saved content, shows a save confirmation, and remains visible after closing and reopening the file
- **Then** save content is UTF-8 encoded, base64 chunked across the shell transport, and decoded with the cached supported shell decoder for the active project root before the server-side atomic replace completes
- **Then** a failed save keeps the dirty marker, keeps the user's draft in the editor, and surfaces an actionable bounded operation error inline and via snackbar
- **Then** selecting editor gutter lines and choosing Add to chat sends the current draft text for the selected line ranges, including LF, CRLF, and CR files
- **Then** when autosave is enabled, closing a dirty open tab flushes its draft, waits for any in-flight save, and closes it
- **Then** when autosave is disabled, closing a dirty open tab is blocked; manual retry and diff-aware refresh of a dirty tab are also blocked so unsaved edits are not overwritten
- **Then** a confirmed successful delete runs in the active project directory, removes the deleted file or folder row from the tree immediately, and does not let failed, stale, or racing relists restore that row
- **Then** while a delete is pending, matching and descendant editors become read-only and overlapping create, rename, delete, and save actions for the same path subtree are blocked to prevent data loss
- **Then** failed delete, create, rename, and save operations keep the current draft or tree state and surface actionable bounded errors instead of silently reverting or dropping state
- **Then** rename and delete actions for a file or containing folder are blocked while a matching editor draft is dirty or saving, including relative and absolute file-tree path aliases
- **Then** empty non-binary text files open as blank editable drafts and can become dirty before the first save
- **Then** binary files keep their existing non-editing fallback state
- **Then** files or editor drafts larger than 64 KiB UTF-8 open read-only or become unsaveable so editing stays responsive, while servers without supported shell file operations keep the existing safe fallback behavior

### Composer mentions include workspace symbols

- **Given** the user types `@` in the composer
- **When** mention suggestions are queried
- **Then** the suggestion list can include file paths, workspace symbols, and agents
- **Then** symbol suggestions show a distinct symbol badge/icon and the source path when available
- **Then** if file or symbol search fails, local agent suggestions remain available

### Conversations are grouped by project context

- **Given** the user has conversations from multiple project directories
- **When** the Conversations sidebar is rendered
- **Then** the sidebar shows a dedicated `Projects` section above the conversations list with one row per open project
- **Then** each project row shows a conversation count derived from that project's visible sessions (active scope or cached snapshot)
- **Then** tapping a project row switches context directly from the sidebar (no modal required)
- **Then** when snapshot data exists, the sidebar shows compact session previews for that project; when not available, it shows a "Open project to load conversations" hint
- **Then** inactive project snapshots are patched by global `session.created`, `session.updated`, and `session.deleted` events so remote session renames and count changes can appear before the user returns to that project

### Conversations sidebar uses one continuous surface

- **Given** the Conversations sidebar is rendered
- **When** server status, sidebar header controls, recent sessions, project groups, and session rows are shown
- **Then** those blocks do not paint nested card or row-wide container backgrounds over the sidebar background
- **Then** the server switcher uses a low-emphasis filled surface without a default outline, keeping the active server name and Online/Delayed/Offline state visible
- **Then** the sidebar settings control uses an icon-only action without a solid default background while preserving tooltip, focus, hover, pressed, and tap affordances
- **Then** selected project, selected session, and current recent-session rows remain visible through a thin primary accent indicator plus foreground text/icon emphasis
- **Then** unread and busy state indicators remain visible as compact foreground badges instead of row-wide fills or outlines

### Sidebar hides diff-stat pseudo summaries

- **Given** the Conversations sidebar is rendered for a session whose backend summary payload only contains diff stats such as `additions` and `deletions`
- **When** the session row subtitle is shown
- **Then** the sidebar suppresses that pseudo-summary instead of rendering `additions: ...` / `deletions: ...`

### Sidebar session search is a compact expandable button

- **Given** the Conversations sidebar is rendered
- **When** the sidebar loads
- **Then** session search is collapsed by default and rendered as a magnifying-glass `IconButton` in the header row next to the project-context and new-chat buttons
- **Then** session filtering and sorting are exposed through one compact header menu with a current-state badge (for example `A/R`) and a tooltip/menu that spell out the full filter and sort labels
- **Then** the old persistent `TextField` and separate filter/sort chip row below the header are removed, saving vertical space

- **Given** the user taps the search icon button
- **When** the button is pressed
- **Then** the "Conversations" title cross-fades into an inline `TextField` with `hintText` "Search conversations" and a prefix search icon
- **Then** sidebar header action buttons are hidden while search is expanded so the search field can use the full header width
- **Then** the `TextField` auto-focuses so the user can start typing immediately
- **Then** a clear (✕) button appears as a suffix when text is present and clears the query + collapses the field back to the title
- **Then** pressing the `Escape` key clears the query and collapses the field

- **Given** the user types a search query
- **When** the query text changes
- **Then** the session list filters immediately by title and summary (case-insensitive), reusing the existing `ChatProvider.setSessionSearchQuery` path
- **Then** the active session filter and sort order continue to apply while the expanded search field owns the full header width

- **Given** an active search query is present
- **When** the user taps outside the field or presses Enter/Submit
- **Then** the keyboard is dismissed but the search field and its active query remain visible, keeping the filter active
- **Then** the field only collapses back to the title when the query is explicitly cleared (via ✕ or `Escape`)

- **Given** a search query was persisted from a previous session
- **When** the sidebar rebuilds (e.g. project switch or app restart)
- **Then** the search field is restored in its expanded state with the active query visible and the session list already filtered

### Recent unread root sessions are highlighted temporarily

- **Given** a root session is out of focus and receives a completed assistant reply
- **When** that reply becomes unread in the current client
- **Then** the root session row receives a subtle theme-aware highlight for up to one hour
- **Then** recent-session title text for that unread root reply also switches to a theme-aware emphasized color during that same one-hour window
- **Then** child/subsessions do not receive that temporary row highlight

### Only root sessions notify for final assistant completions

- **Given** a session finishes a final assistant response and notification feedback is evaluated
- **When** that session is a main/root session
- **Then** the app may emit the normal completion notification or sound according to the user's notification settings
- **When** that session is a child/subsession (`parentId` is present)
- **Then** the app does not emit a final-response completion notification or sound for that child session

### Recent sessions quick access is enabled by default when available

- **Given** a new installation or a context whose display toggles were never customized
- **When** the Conversations sidebar is rendered and recent root sessions exist
- **Then** the `Recent sessions` section is enabled by default and appears above the project groups
- **Then** if there are no recent root sessions yet, the section stays hidden instead of rendering an empty section

- **Given** the user disables `Recent sessions` in `Display Toggles`
- **When** the Conversations sidebar is rendered
- **Then** the sidebar hides that section even when recent root sessions are available

- **Given** the `Recent sessions` section is visible
- **When** the Conversations sidebar is rendered
- **Then** the sidebar shows a `Recent sessions` section above the project groups with up to 5 recent root sessions from currently open/cached project contexts
- **Then** each recent row stays on one compact line with only the session title and a right-aligned project chip so the user can identify the source project quickly
- **Then** any recent row whose session is still busy shows the same sweep-style running indicator used by the composer, including sessions from other open/cached project contexts
- **Then** if the currently open session also appears in `Recent sessions`, that row uses the same selected accent indicator and foreground emphasis as the project session list below it

### Recent session tabs

- **Given** the active server has session candidates across its known project contexts
- **When** recent session tabs are reconciled
- **Then** the strip normally contains recent non-archived root sessions from that server, keyed by normalized project directory and session ID; child sessions and sessions from other servers are excluded
- **Then** normal eligibility uses the later of the official session update and successful local open time within a rolling 3-hour window, while selected and busy/retry sessions remain eligible
- **Then** when opening a project that was not open, if no session from that project survives the normal eligibility rules, the strip adds only the most recent non-archived, non-suppressed root session from that project as a fallback
- **Then** other tabs and project contexts remain unchanged, and local suppression continues to apply
- **Then** persisted tab order remains stable through selection, title, status, and attention changes; newly eligible or explicitly reopened tabs append to the end
- **Then** explicitly closing a tab only writes local suppression, never archives, deletes, or mutates the OpenCode session, and ordinary refresh/replay does not resurrect it; a successful explicit reopen or strictly newer authoritative interaction can append it again

- **Given** the user closes a session tab
- **When** the closed tab is active or inactive
- **Then** closing the active tab selects the tab to its right, then the tab to its left; closing the sole active tab enters a local `New Chat` draft, while closing an inactive tab does not navigate
- **Then** CodeWalk shows a localized 3-second `Snackbar` with `Undo`

- **Given** the user presses `Undo` on the closed-tab `Snackbar`
- **When** the closed tab can be restored
- **Then** only that local tab is restored at its original position, without navigating back or mutating the OpenCode session

- **Given** the user activates a tab for another project context
- **When** that context is closed or not current
- **Then** CodeWalk switches or reopens the project cache-first, waits boundedly for authoritative target session data, and restores the prior coherent project/session with an error if the target is unavailable

- **Given** the session-tab display toggle is enabled and tabs are nonempty
- **When** the chat surface is rendered
- **Then** on desktop with integrated window chrome configured, the strip is rendered in the integrated desktop chrome; otherwise it appears below the app bar on compact and expanded layouts
- **Then** tabs default to enabled on every platform when there is no override, and an explicit `Display Toggles` choice, including `false`, persists
- **Then** the strip height is 20% smaller, with smaller gaps and shoulders; active tabs have an 8px top radius and inactive tabs have a 5px top radius

- **Given** a selected tab represents the current session
- **When** the chat surface is rendered
- **Then** the selected tab shows the session title and context-usage control, and the duplicate compact session header is hidden
- **Then** the compact session header remains visible when tabs are disabled or no selected tab represents the current session

- **Given** the tab strip is rendered
- **When** the user swipes, uses the wheel or trackpad, or the app scrolls programmatically
- **Then** horizontal scrolling remains available while the scrollbar is completely hidden visually

- **Given** a tab is selected at startup or after selection, insertion, or reorder changes its horizontal position
- **When** the tab strip updates
- **Then** the selected tab is brought into the viewport

- **Given** a session tab has attention or activity state
- **When** its leading indicator is rendered
- **Then** visual priority is error, question, then completion, while busy/retry remains an independent status indicator; closed projects use their cached/default icon without discovery
- **Then** the strip supports horizontal overflow, ensures the selected tab is visible, exposes the full title in a tooltip and semantics, reports selected and busy/retry status semantics, and keeps tab widths larger while remaining responsive to available space

- **Given** a session tab is visible
- **When** the user double-clicks/double-taps or middle-clicks it
- **Then** only that local tab closes; the OpenCode session is not archived, deleted, or otherwise mutated
- **When** the user right-clicks or touch-and-holds it
- **Then** the current session actions menu opens, including `Rename session`; an inactive tab is activated first
- **When** the user invokes the semantic session-actions action, `Context Menu`, or `Shift+F10`
- **Then** the same current session actions menu opens
- **When** the user presses `Delete` or invokes the semantic dismiss action
- **Then** only that local tab closes
- **Then** there is no visible close button on a tab

- **Given** new session tabs become eligible while the tab gesture hint is enabled
- **When** the chat is active
- **Then** one dialog per batch aggregates and deduplicates the new tabs, explains the close and session-action gestures and `Display Toggles`, and offers `Don't show again`
- **Then** the dialog offers `Disable tabs` beside `Got it`, and `Disable tabs` uses the same `Display Toggles` override
- **Then** selecting `Don't show again` persists its dismissal independently of `Disable tabs`
- **When** a hint request is pending while the chat is inactive
- **Then** the request is shown when the chat becomes active again

### Sidebar session actions are available from row gestures

- **Given** a session row is visible in the main Conversations list
- **When** the user opens the trailing menu, right-clicks the row on desktop, or long-presses the row on mobile
- **Then** the same session menu opens with pin/unpin, rename, share/unshare, copy link when available, archive/unarchive, fork, and delete actions
- **Then** dismissing that menu does not select or open the session row

- **Given** a row is visible in `Recent sessions`
- **When** the user right-clicks the row on desktop, uses the keyboard context-menu action, or long-presses/touch-holds the row
- **Then** the row exposes the same session actions and dispatch behavior as the main Conversations list
- **Then** recent rows do not show a visible trailing three-dot menu

### Project paths preserve the trailing folders in the sidebar

- **Given** a project path is too long to fit in its sidebar row subtitle
- **When** the project group subtitle is truncated
- **Then** the trailing path segments remain visible and the ellipsis appears at the start of the rendered path instead of the end

### Session pinning is context-scoped and sort-stable

- **Given** the user is viewing conversations in a specific server + project context
- **When** the user pins or unpins a session from the conversations list
- **Then** pin state is persisted locally for that exact context only (no cross-server/cross-project leakage)
- **Then** pinned sessions are always ordered before unpinned sessions, independent of the selected sort mode (recent, oldest, or title)
- **Then** standard list filters (for example active vs archived) still apply first; pinning only changes ordering within the currently visible set

### Auto-generated session titles

- **Given** a new session with no custom title
- **When** each new message is added to the conversation
- **Then** the app automatically generates (or re-generates) a title based on the conversation content
- **Then** title generation stops once the session has accumulated 3 or more user messages **and** 3 or more assistant messages — sufficient context has been established by that point
- **Then** dynamic title generation runs only for main/root sessions; subsessions (child sessions with `parentId`) do not trigger auto-title updates

### Session reopening is cache-first

- **Given** the user already opened a session recently in the same server+project scope
- **When** the user switches back to that session
- **Then** cached messages are rendered immediately without waiting for a full network reload
- **Then** the chat timeline reuses the cached grouped/hydrated presentation for that session instead of visually rebuilding settled history from scratch
- **Then** if the selected existing session has no in-memory messages yet, the chat surface shows a subtle loading indicator instead of the generic `Hello! I am your AI assistant` empty state until hydration finishes
- **Then** if that cached session is still actively processing, the viewport lands directly at the bottom immediately, with no visible reopen animation
- **Then** if that cached session is already settled, the viewport restores directly to the latest assistant response instead of replaying a reopen bottom-snap or reveal thrash
- **Then** the app revalidates the session in background (SWR) and merges newer server state when available
- **Then** native builds store large cached chat payloads in the file-backed cache, not in `SharedPreferences`; legacy large payloads left in `SharedPreferences` are returned immediately when read and drained to the file-backed cache in the background

### Project switching is cache-first and non-blocking

- **Given** the user switches project/directory context and that context has cached sessions
- **When** the switch is triggered from the project context picker (open/reopen/close/switch)
- **Then** project-scope transitions are serialized, and pointer input in the chat area is blocked immediately while a transition is active
- **Then** the chat area keeps one visual tree/root `Stack` during the transition, preserving its visual state while transition layers are applied
- **Then** the `Loading project context...` overlay appears only if the transition remains active after 150 ms; fast or cache-complete transitions finish without a loading flash
- **Then** the new context renders immediately from cached scope data without waiting for network revalidation
- **Then** session list revalidation runs in background and refreshes to server state when the response arrives
- **Then** if background revalidation fails, the cached visible state remains stable (no forced blank/loading fallback)
- **Given** the target context has provider, model, agent, or variant choices, or composer catalogs
- **When** that context is opened or restored
- **Then** choices and catalogs are scoped by server plus project/directory and restored immediately from that context's own snapshot/cache
- **Then** fresh server data revalidates catalogs in background, while stale or offline catalogs preserve the target context's selection instead of applying a fallback or another project's catalog
- **Given** project selection or open-context state must be persisted
- **When** the user changes context
- **Then** persistence is write-behind and does not keep the visual transition blocker active
- **Given** Android background permission auto-approval is eligible
- **When** the project or lifecycle context changes
- **Then** the auto-approve context follows the latest project/lifecycle context, remains disabled while the app is foreground, and rejects stale-context work
- **Then** when returning to a recently visited project that was marked dirty by global events, the previously cached session list remains visible immediately and is revalidated in background
- **Then** the fast project path detaches message, event, and global-event subscriptions with generation guards and cancels them in parallel with a 100 ms bound; the cached snapshot is restored and notified before that cancellation bound is awaited
- **Then** slow/server-backed transitions keep the normal subscription teardown path
- **Then** project-switch transition teardown uses bounded cancellation time, so the `Loading project context...` blocker is brief and does not wait for long stream cancellation timeouts

### Active session SWR prefers delta-like refresh

- **Given** the active session already has cached messages visible
- **When** background revalidation runs after project/session switch
- **Then** the client first fetches a limited recent tail window (delta-like refresh) instead of full history
- **Then** the fetched tail is merged non-regressively with the visible local timeline: completed or locally newer assistant content must not lose visible text, reasoning, terminal tool state, or completion status because of a shorter/stale snapshot
- **Then** if the fetched tail has no safe overlap with local cache, the client immediately promotes the recent server tail plus a bounded safe local tail, marks older history as incomplete, and automatically falls back to a full fetch to guarantee correctness
- **Then** explicit `message.removed` and `message.part.removed` realtime events remain authoritative over stale fallback or refresh snapshots, so recently removed messages/parts are not resurrected by delayed HTTP fetches

### Realtime event scope follows the active session

- **Given** realtime events are connected for the current server and project context
- **When** an event targets the active/open session
- **Then** the active session receives the full realtime path, including message snapshots, part deltas, diffs, todos, status, permissions, questions, errors, and final idle signals
- **When** the selected session is not actually visible because the chat route is inactive
- **Then** final-completion feedback is treated like background attention instead of being cleared as if the user were viewing the chat
- **When** an event targets another session in the same project context
- **Then** CodeWalk keeps only summarized/alertable state hot for that session: deduplicated busy/retry/idle status by type, pending permission/question prompts (including v2 aliases), critical error attention, and root-session final-completion unread attention
- **Then** non-active sessions do not trigger realtime fallback fetches for full message payloads, and `session.diff` / `todo.updated` payloads are deferred until the session becomes active
- **When** a global event targets a cached but inactive project context
- **Then** the cached project snapshot is patched only for session list/status/error/final-completion attention and pending permission/question state
- **Then** a `session.status` transition to idle may surface the same client-side completion feedback as terminal `session.idle`, while later no-op idle replays do not re-alert that same completed turn
- **Then** unsupported or detailed inactive-context events only mark that context dirty, so returning to the project renders cache immediately and revalidates through SWR instead of reconciling every background event live
- **When** the user opens a non-active session
- **Then** cached content appears first when available, followed by active-session revalidation and session insights loading for authoritative messages, diffs, todos, and status

### OpenCode global events preserve server-owned routing and state

- **Given** CodeWalk receives an official nested `/global/event` frame
- **When** the outer envelope includes `directory`, `project`, or `workspace`
- **Then** those outer values identify the authoritative project context for routing, even if the nested payload repeats a different value
- **Then** flat per-instance events and global `server.connected` / `server.heartbeat` frames without outer context remain accepted
- **When** `session.next.revert.staged`, `session.next.revert.cleared`, or `session.next.revert.committed` targets the visible session, or omits a usable session ID
- **Then** CodeWalk serializes a server-authoritative session and message refresh instead of deleting or fabricating messages locally
- **When** a revert event identifies another session
- **Then** CodeWalk refreshes session metadata without replacing the visible session timeline
- **Then** aggressive cellular data saver can reconcile an active-session revert from the per-instance stream without enabling the global stream or adding a status fetch
- **When** `catalog.updated` arrives in a burst
- **Then** CodeWalk keeps the current provider/model catalog visible and coalesces the burst into the existing single provider refresh path

### New Chat draft state is isolated per project context

- **Given** the user starts `New Chat` draft mode in project A (no active session yet)
- **When** the user switches to project B
- **Then** project B must not inherit draft mode from project A
- **Then** project B restores its own cached/current session state via project-switch SWR
- **Then** when the user returns to project A, draft mode is restored only for project A

### Long-session revalidation avoids forced viewport jumps

- **Given** a cached session is visible and background revalidation finishes
- **When** newer server messages are applied
- **Then** the timeline updates in place without clearing to an empty skeleton first
- **Then** collapsed history groups keep their per-session expansion state during switch and revalidation
- **Then** historical assistant work/tool-call groups return collapsed after session return or revalidation (manual expansion is not restored)
- **Then** the latest completed assistant work/tool-call run stays visible inside a bounded internal panel while it remains the newest run, so regrouping does not yank the main chat viewport
- **Then** an already-selected empty session keeps its empty placeholder visible during background refresh (no loading skeleton blink)
- **Then** returning from background or focus with no new chat content restores a settled cached session to the latest assistant response and an active cached session to the bottom, without a second jump
- **Then** if refreshed settled content arrives during resume revalidation, the queued cached restore waits for that refresh to finish and then reveals the newest assistant response once instead of bottom-snapping first
- **Then** passive refreshes, realtime part updates, and status-only busy/retry reconciliation must not start a second auto-scroll owner while the active turn already owns the viewport
- **Then** overlapping active-session refresh requests join the in-flight refresh instead of completing early, so resume/open viewport restoration waits for the actual message revalidation before it runs
- **Then** a transient `idle` status pulse must not settle the current session while a send is still initializing or an assistant message remains incomplete locally
- **Then** unsupported global `message.*` fallback reconcile must refresh the visible timeline only when the event explicitly targets the current session; unrelated sessions/projects may dirty caches and lists but must not move or settle the visible chat
- **Then** duplicate `message.*` events from the session and global SSE streams are deduplicated regardless of which stream arrives first, while distinct payload mutations for the same message/part id are still applied
- **Then** reopening a cached session does not replay old-history entrance/loading motion before newer delta content is merged

### Older history loads on demand at top reach

- **Given** a conversation has older messages not yet loaded in the current viewport
- **When** the user scrolls to the top threshold of the chat timeline
- **Then** the app loads older message batches incrementally
- **Then** the viewport anchor is restored after prepend so reading position stays stable (no sudden jump)

---

## Chat

### Assistant responses can render live or as a block

- **Given** a connected server and an active session
- **When** the user sends a message
- **Then** the message is sent to the OpenCode server and the assistant's response streams back via SSE
- **Then** `Settings > Behavior > Chat render mode` defaults to `Live`, rendering assistant text, reasoning, and tool activity in real time as events arrive
- **Then** when chat render mode is `Block`, the OpenCode stream remains active but incomplete assistant text, reasoning, and tool cards for the current turn stay hidden behind a compact generation placeholder
- **Then** block mode reveals the assistant turn after that turn settles, including the final text and any completed tool or reasoning entries
- **Then** if a response is cancelled or finishes with an error, partial or error content is revealed instead of remaining hidden
- **Given** the user is viewing `Settings > Behavior > Chat render mode`
- **When** the user selects `Live` or `Block`
- **Then** the `SegmentedButton` selection and matching description update immediately
- **Then** the provider state and persisted value match the visible selection
- **Then** leaving and returning, app resume or a session-attention capability refresh, and fresh provider/app hydration do not revert the selection

### First send from draft bootstraps a session automatically

- **Given** `New Chat` is in draft state (no active session yet)
- **When** the user sends the first message
- **Then** the client creates a new session automatically and sends that message in the same action

### User can cancel a response

- **Given** the assistant is actively streaming a response
- **When** the user taps the cancel/stop button
- **Then** the response generation stops and the partial response remains visible

### Sending while processing uses direct follow-up sends

- **Given** the assistant is actively streaming a response and the user has typed a new prompt
- **When** the user taps the primary composer action
- **Then** the app sends that prompt immediately through the normal async send path without locally batching or draining other drafts
- **Then** the app does not auto-abort the active response as part of that send action

### Busy-state UI does not invent local queue lifecycle

- **Given** the assistant is actively streaming a response
- **When** the user interacts with the composer and timeline
- **Then** the app does not show a client-invented `Queued` message state for follow-up prompts
- **Then** the app does not expose a `Send now` action or any local queue-dispatch control
- **Then** busy/idle feedback comes from the active server-backed lifecycle rather than local queue bookkeeping

### Stop remains an explicit abort action

- **Given** the assistant is actively streaming a response and the composer has no pending draft to send
- **When** the user taps `Stop`
- **Then** the app calls the session abort endpoint for the active session
- **Then** the current response stops and any partial assistant output remains visible

### Failed send returns message to composer

- **Given** the user sends a message
- **When** the send fails (network error, server error, etc.)
- **Then** the message text is returned to the composer input — the user's text is never lost

### Undo and redo reflect immediately in the current client

- **Given** the active session has at least one persisted user turn
- **Then** the latest visible revertible user bubble exposes an inline `Undo this turn` action that triggers the same undo flow as the toolbar and `/undo`
- **Then** older visible persisted user bubbles expose an inline `Rewind and edit from here` action that reverts the session to that historical user turn and restores that prompt text into the composer
- **Then** optimistic local user bubbles whose IDs start with `local_user_` never expose historical rewind because the server has not confirmed those message IDs
- **When** the user triggers `Undo` from the toolbar or `/undo` from the composer
- **Then** the current client immediately hides the reverted user turn and every later turn from the visible timeline without waiting for another client or a manual refresh
- **Then** the reverted user prompt is restored into the composer so the user can edit or resend it locally
- **When** the user sends a new prompt after `Undo` instead of triggering `Redo`
- **Then** the client treats that send as a replacement branch immediately: the abandoned reverted tail stays hidden, `Redo` is no longer available for that branch, and stale refreshes must not resurrect the reverted tail visually
- **When** the user triggers `Redo` from the toolbar or `/redo`
- **Then** the visible timeline immediately restores the next reverted turn (or all reverted turns when the revert boundary is fully cleared)
- **Then** a full redo clears the composer draft that had been restored by undo
- **Then** toolbar and slash-command wording stays explicit about operating on the last turn so the inline bubble action, toolbar actions, and composer actions describe the same behavior
- **Then** timeline visibility and undo/redo availability are driven by the server-authoritative session revert boundary, aligned with official OpenCode Web semantics

### Composer drafts persist per session

- **Given** the user types an unsent composer draft in a session
- **When** the user switches to another session in the same server/project context and later returns
- **Then** the original session restores its own locally persisted draft text, shell mode, and supported attachments
- **Then** sessions with no saved draft reopen with an empty composer
- **Then** transient drafts restored after a rejected send or undo/redo history action keep priority over the persisted session draft until that transient state is consumed

### Composer uses native spell check by default

- **Given** the chat composer is visible in a new installation or in settings without a saved spell-check preference
- **When** the user types in the composer input
- **Then** CodeWalk enables Flutter's native platform text correction path for that composer field: autocorrect, suggestions, and spell check are enabled where the platform supports them
- **Then** CodeWalk does not send composer text to any external correction service
- **When** the user turns off `Composer spell check` in `Settings > Behavior`
- **Then** the composer disables autocorrect, suggestions, and spell check for that field only
- **Then** other technical inputs keep their existing behavior and are not changed by this setting

### Composer extras menu includes canned answers and attachments

- **Given** the user is composing a message
- **When** the user taps the `+` extras button on the left side of the composer bubble
- **Then** the app opens or closes the inline extras popover above the input without changing the current keyboard/focus state
- **Then** if the keyboard is already open, tapping `+` keeps it open; if the keyboard is already closed, tapping `+` keeps it closed
- **Then** the extras popover stays compact, starts directly with the action row, and avoids redundant title lines above the actions or canned-answer list
- **Then** the extras popover shows a top action row with quick actions such as `New quick reply` and `Attach files`, leaving room for future actions
- **Then** attachment entry is opened from that extras popover instead of a separate attachment button near the model controls
- **Then** selecting an item inserts canned text according to item mode: `Append at cursor` inserts at current selection, `Replace` overwrites composer text
- **Then** if that canned answer has an agent, model, or variant override, the app applies the override to the visible composer selection after insertion and before any automatic send
- **Then** if that canned answer has `Send automatically` enabled, the app sends the resulting composer message immediately after insertion and after any saved agent/model/variant override is successfully applied
- **Then** if an explicit saved agent, model, or variant override cannot be applied in the current server/model context, the app keeps the inserted text in the composer, shows a warning, and blocks automatic send so the user can review manually
- **Then** in sub-conversations where model/agent controls are locked, canned-answer agent/model/variant overrides are also locked; text insertion still works, but automatic send is blocked when the saved quick reply depends on a locked override
- **Then** long-pressing a canned item opens edit/delete actions
- **Then** add/edit supports an optional label, required text, insertion mode, optional `Send automatically`, scope mode (`Global` or `Project-only`), optional agent override, optional model override, and optional variant override
- **Then** the add/edit surface uses a fullscreen editor on compact screens and a large scrollable dialog on wider screens so all options remain reachable
- **Then** global items are available across all contexts, while project-only items are restricted to the active `serverId::scopeId` context
- **Then** global canned answers are indicated inline with a globe icon instead of a standalone textual `Global` subtitle line
- **Then** canned answers with saved agent, model, or variant routing show compact trailing indicators in the extras popover
- **Then** each canned-answer row stays on a single line and shows only one primary text source: the optional label when present, otherwise the canned text truncated with ellipsis

### Optimistic user message ID uses local prefix — never server format

- **Given** the user sends a message in an active session
- **When** the client appends the optimistic user bubble and dispatches `prompt_async`
- **Then** the client assigns the optimistic message a `local_user_<timestamp>_<seq>` ID — it intentionally does NOT use a server-format ID (`msg_*` or similar)
- **Then** the `messageId` field is NOT forwarded in the `prompt_async` send payload — the server assigns its own canonical ID
- **Then** if the server returns a fully completed assistant payload directly in the `prompt_async` HTTP response, the client accepts that payload immediately instead of waiting for the fallback polling path
- **Then** duplicate detection for the server echo uses a content-signature match (normalized text), gated by the `local_user_` prefix check
- **Then** server-echo replay replaces the matching optimistic bubble when the canonical server user message is known, so the prompt does not appear twice
- **Then** reconciliation must never hide in-flight tool/work output or block the final assistant reveal

> **INVARIANT — do not violate**: The `local_user_*` prefix and the absence of `messageId` in the send payload are load-bearing contracts.
> Changing the prefix to any server-format value (e.g. `msg_*`) or forwarding `messageId` in the payload causes the SSE event stream to fail reconciliation for all turns after the first — assistant responses are received and audio/notifications fire, but the UI update is silently discarded and the UI stays stuck on the previous state.
> Active refresh/reconcile must preserve visible tool/work output for the current turn until the final assistant response is available.
> This regression was introduced and reverted in commit `b0660a2`. See ADR-023 "Known Pitfalls" for the full incident analysis.

### Assistant file paths open the file viewer

- **Given** an assistant message contains a whole inline-code file path such as `lib/main.dart:42`
- **When** the user taps that inline-code span
- **Then** the app opens the file viewer for that path and scrolls to the referenced line instead of copying the text
- **Then** ordinary inline code snippets and fenced code blocks remain copyable

### Message image sharing exports PNG files

- **Given** a chat message is visible
- **When** the user chooses `Share as image`
- **Then** the app captures the message bubble as a PNG file and opens the platform share sheet
- **Then** share controls are hidden during capture so they do not appear in the exported image
- **Then** oversized messages show the message-too-long failure instead of attempting an unsafe capture
- **Then** Windows shares only the PNG file payload, without subject/text fallback, so image-capable share targets receive an image file instead of text
- **Then** non-Windows platforms preserve the localized share subject

### Mermaid fenced blocks render as diagrams

- **Given** an assistant message contains a fenced code block with language `mermaid`
- **When** the message is rendered
- **Then** the fenced block is displayed as a visual diagram inside a dedicated card with a `Mermaid Diagram` header
- **Then** the diagram adapts its size to the screen width (compact/expanded)
- **Then** a copy-source button is shown in the header so the user can copy the raw Mermaid text
- **Then** non-mermaid fenced code blocks continue to render as syntax-highlighted code (no regression)

### Mermaid diagram parse failures show a styled source fallback

- **Given** a mermaid fenced block contains invalid or unsupported syntax
- **When** the diagram renderer fails to parse the source
- **Then** the raw Mermaid source is displayed in a styled monospace block instead of an error message
- **Then** the copy-source button remains available

### Mermaid diagrams avoid scroll lock

- **Given** a mermaid diagram is rendered inside a chat message
- **When** the user drags vertically over the diagram area
- **Then** touch gestures pass through to the parent chat scroll, avoiding scroll lock
- **Then** horizontal scrolling within the diagram remains available when the diagram is wider than the viewport

### LaTeX math expressions render as typeset equations

- **Given** an assistant message contains an inline math expression `$...$` with LaTeX command tokens (e.g. `\frac`, `\sum`, `\sqrt`)
- **Then** the expression is rendered as a visual typeset equation using flutter_math_fork (pure Dart KaTeX port)
- **Then** the inline math renders in text style (baseline-aligned, smaller) inside a subtle background chip
- **Given** an assistant message contains a block math expression `$$...$$` on separate lines or on a single line
- **Then** the expression is rendered as a centered display-style equation inside a card with a `Math` header, matching the Mermaid diagram card pattern
- **Then** horizontal scrolling is available when the equation is wider than the viewport

### LaTeX math rendering avoids false positives

- **Given** an assistant message contains currency values like `$5` or `$100`
- **Then** these are not matched as math expressions and render as plain text
- **Given** an assistant message contains shell variables like `$PATH` or `$HOME`
- **Then** these are not matched as math expressions and render as plain text
- **Given** math expressions appear inside fenced code blocks or inline code
- **Then** the markdown parser's code-block and inline-code rules take priority, so the delimiters render as literal text

### LaTeX math parse failures show a styled source fallback

- **Given** a LaTeX expression contains invalid or unsupported syntax
- **Then** the raw expression source is displayed in a styled monospace block instead of an error message
- **Then** for inline math, the fallback text is styled in a smaller monospace font with error coloring
- **Then** for block math, the fallback shows the raw source in a code-view container matching the Mermaid fallback pattern

### Math rendering toggle

- **Given** the user disables `Math rendering` in `Settings > Appearance`
- **Then** `$...$` and `$$...$$` delimiters render as literal text without math processing
- **Given** the user re-enables `Math rendering`
- **Then** math expressions in all messages are rendered as typeset equations on next rebuild

### Tool call work groups collapse after completion

- **Given** the assistant executes tool calls during a response (file reads, commands, etc.)
- **When** tool updates are still arriving for the active response
- **Then** manual expansion of a visible tool call or tool-call chain is preserved while the response is still streaming
- **Then** if a single visible tool block grows into a multi-tool chain during that same active response, the user-open state is carried into the grouped view instead of snapping shut
- **Then** collapsed multi-tool chains surface an active progress summary (for example `1 running • 1 queued`) while the response is still in flight
- **Then** the composer status slot surfaces the latest live tool, patch, or reasoning activity in a fixed position so the newest progress stays visible without shifting the main chat viewport
- **Then** real in-flight reasoning text remains visible as an inline Thinking bubble in the main timeline and subagent timelines; status-only reasoning markers stay in the fixed composer slot and are not rendered as Thinking bubbles
- **Then** when the official `session.idle` signal arrives for the current session, the composer status slot stops showing active progress even if fallback delivery streams are still draining internally
- **Then** completed tool badges use an explicit success-green treatment so finished work stays visually distinct from queued, active, and error states
- **Then** when a contiguous visible run contains multiple `task` tool bubbles, settled task bubbles render before still-active running or queued task bubbles without crossing the surrounding text/reasoning boundaries of that same assistant message
- **Then** a running `task` tool bubble prefers the latest internal child-session tool label inline when task metadata or cached child-session messages expose it; otherwise it falls back to the latest extracted command, and finally to `Running task`
- **Then** a completed `task` tool bubble shows `N tool calls` when child-session totals are available, so finished work stays compact while still hinting at the amount of internal activity
- **When** the assistant finishes the complete response
- **Then** tool-call chains and tool-detail sections start collapsed by default
- **Then** collapse never happens while the assistant is still streaming
- **Then** content shrink from active tool/work regrouping, collapse deferral, or status-marker filtering must not trigger outer chat snap-back while that same response is still active
- **Then** manual expansion is temporary and is not restored after return/revalidation
- **Then** when the final completed assistant-work group is compacted for the finished response, that completed group is shown collapsed by default even if a streaming-era tool block was manually expanded earlier in the turn
- **Then** the user can manually re-expand any collapsed work group by tapping its Details toggle
- **Then** once manually expanded, a completed tool-call group stays expanded during normal timeline rebuilds (scroll state updates, background refresh, and other parent re-renders) so the user can keep reading without involuntary collapse
- **Then** automatic collapse is only applied when collapse mode is activated for that rendered group, not on every subsequent rebuild
- **Then** once a completed turn has settled, transient realtime status pulses do not auto re-open or rapidly re-collapse that same work group
- **Then** the rendered identity of a settled assistant-work group is anchored to the final completed assistant turn, not to volatile intermediate work message ids, so same-turn passive refreshes reuse the existing grouped surface instead of remounting it
- **Then** passive status-only or background refresh pulses must not re-enter active-response collapse deferral for an already settled turn unless a newer revealable assistant message actually exists
- **Then** long tool output is rendered inside a bounded inner viewport with its own scrollbar so tool growth does not keep stretching the outer chat timeline while the user is reading
- **Then** when tool output continues updating inside that bounded viewport, the inner scroll may follow the latest tail only while the user is already near the bottom of that tool output; it must not yank the main chat viewport

### Empty assistant-work groups disappear after display filtering

- **Given** `Display toggles` hides all visible items inside an assistant work/tool group
- **When** the timeline is rebuilt from cache or fresh grouping
- **Then** that now-empty group is omitted entirely instead of rendering an empty shell
- **Then** display-toggle state participates in timeline cache reuse so stale filtered groups are not resurrected

### Review changes display can be hidden

- **Given** the active session has changed files available for review
- **When** `Review changes` is enabled in `Display toggles`
- **Then** the timeline or desktop utility pane shows the review-changes file list when that surface is otherwise eligible to render it
- **Then** the inline compact/mobile review block starts collapsed and expands only after the user taps it
- **Then** refreshes and passive session updates preserve the selected file and manually expanded/collapsed diff hunks whenever their file/hunk identity still exists
- **When** the user disables `Review changes` in `Display toggles`
- **Then** the review-changes file list block is hidden without clearing or mutating the session diff data

- **Given** the active session has changed files available for review
- **When** the user opens `Review changes` from the session action menu
- **Then** the session details dialog renders the review section before tasks so the changed files are the first focused content
- **Then** subsequent insight refreshes do not reset the selected file or hunk expansion state unless the underlying file or hunk no longer exists

### Sub-conversation threads keep a full composer with parent return

- **Given** the user opens a child thread from a subtask/task bubble in the main conversation
- **When** that source bubble represents a `task` tool with a matching child session
- **Then** the entire task bubble surface acts as the navigation affordance instead of rendering a dedicated `View` button
- **When** the child thread is active (`parentId` is set)
- **Then** the full chat composer remains available inside the child thread, including text send, slash input, attachments, and voice input
- **Then** a dedicated `Return to parent conversation` control remains visible so the user can navigate back exactly one level at any time
- **Then** when that child thread is actively responding, the same composer stop behavior remains available without leaving the child thread
- **Then** agent/model/variant selectors remain non-interactive in the child thread
- **Then** the locked model chip reflects the child-thread metadata (not the parent selection)
- **Then** the variant chip is shown only when an explicit child-thread variant is known

### Sub-conversation navigation is deterministic

- **Given** assistant output contains a `SubtaskPart` or `task` tool bubble in a root or nested sub-conversation
- **When** the user taps `Open sub-conversation`
- **Then** navigation prefers explicit child-session IDs from the part payload
- **Then** if explicit IDs are unavailable, fallback mapping uses anchor order for the same part type (`SubtaskPart`→subtask anchors, `task` tool→task anchors) against child sessions sorted by creation time
- **Then** if no mapping can be resolved, the app keeps the current session and shows non-blocking feedback
- **Then** nested task/subtask surfaces retain their normal tap/click affordance and may open direct children at any available depth
- **Then** references to ancestors or other non-child sessions are rejected rather than creating a navigation loop

### Compact mobile collapsed copy is concise

- **Given** the app is rendered on a compact viewport (mobile width)
- **When** reasoning and tool-call boxes are collapsed
- **Then** headers/toggles use short labels (`Thinking`, `Show`, `Hide`, `More`, `Less`) to reduce visual noise
- **Then** collapsed tool-call groups use count-first summaries (for example, `2 calls`) and hide secondary helper subtext in the collapsed state
- **Then** expanded content and desktop wording remain unchanged

### UI remains fluid during streaming

- **Given** the assistant is streaming a long response
- **When** text, code blocks, or tool calls render incrementally
- **Then** the UI remains smooth without stuttering, freezing, or perceptible lag

### New chat content updates progressively

- **Given** the chat timeline receives new tail messages in the active session
- **When** those entries are rendered
- **Then** main timeline entries appear directly without entrance transitions or stagger
- **Then** existing history remains stable when reopening or switching sessions and does not replay arrival motion

### Streamed tool parts render without slide motion

- **Given** an assistant bubble is already visible and new tool/patch parts are appended during streaming
- **When** those parts arrive
- **Then** they fade in directly in their final position without any slide motion

### Reduced-motion accessibility disables entrance motion

- **Given** the platform or app accessibility settings request reduced motion (`disableAnimations`)
- **When** new messages or streamed parts are rendered
- **Then** entrance motion is skipped and content appears immediately without slide transitions

### Main timeline messages appear without motion

- **Given** the user is viewing the main chat timeline
- **When** a new user, assistant, permission, retry, or grouped timeline entry is appended
- **Then** the entry appears directly in its final position without slide, fade, scale, stagger, or other entrance motion
- **Then** automatic bottom-follow keeps the newest entry anchored without animated scroll transitions

### Tool-only busy turns keep live follow behavior

- **Given** the active session is still busy/retrying during a multi-step tool turn
- **When** the latest assistant chunk is completed but the turn still emits tool/patch updates
- **Then** the chat keeps active follow/reveal behavior for that same turn
- **Then** idle/background status snapshots without live tool/patch updates do not trigger autonomous jumps
- **Then** provider-side passive updates (refresh merges, realtime part deltas, and status pulses) must defer to the runtime viewport owner instead of causing a visible extra scroll-to-bottom correction for that same turn
- **Then** when the user is still passively following the active turn, growth from tool/reasoning/text updates keeps the viewport visually pinned to bottom without per-delta jump churn
- **Then** tool-only assistant messages stay as raw bubbles while the active turn is still responding; they are not live-merged into a synthetic grouped bubble mid-turn
- **Then** tool-only assistant messages may merge/collapse only after the final assistant message arrives and the turn settles
- **Then** active-turn tool/work rendering must not structurally shrink the visible timeline in a way that creates a temporary blank vacuum at the bottom while the user is still passively following the turn
- **Then** if a future optimization would merge, compact, or replace active-turn tool-only messages before settlement, it must be rejected unless it proves it cannot create viewport shrink/reflow or typing-lag regressions
- **Then** if active-turn content still shrinks while passive follow is enabled, the runtime may perform an immediate non-animated bottom-anchor heal to remove the bottom vacuum, but only while the user has not manually scrolled away
- **Then** active-turn tool-chain body size transitions must not animate while the session is still responding if that animation would introduce shrink/reflow churn or typing lag

### Recoverable current-session refresh failures stay scoped

- **Given** the user is already inside a selected session
- **When** that session refresh fails before any messages load
- **Then** the chat surface shows a scoped recovery card for that session instead of replacing the whole chat view with the old global `Retry` takeover
- **Then** the scoped recovery actions keep the user in context with `Keep working` and `Retry refresh`

### Final response is revealed from the beginning

- **Given** a response finishes after tool/work messages
- **When** the final assistant message becomes available
- **Then** the chat reveals the **start** of the final assistant message (not the end)
- **Then** if the whole final assistant message already fits in the current viewport, the chat does not perform an extra reposition
- **Then** otherwise the reveal lands with the start of the final assistant message around 40% of the viewport height so reading starts near the middle of the screen instead of hard at the top
- **Then** a final assistant message revealed this way is considered read even when its full body extends below the viewport, so the `Go to latest` affordance is not shown solely because the viewport is no longer pinned to the bottom

### Post-completion reading remains stable

- **Given** the final assistant response is already visible
- **When** the user is reading without sending new input
- **Then** the chat does not perform autonomous jump/scroll corrections
- **Then** passive status/revalidation updates for that same revealed final response keep the viewport in read `reading` mode without showing unread/latest affordances
- **Then** if a newer active response update or new message arrives below the visible reading position, the viewport stays anchored where the user was reading and only the unread/latest affordance updates
- **Then** auto-follow resumes only after explicit user intent (e.g., sending a new message or tapping `Go to latest`)
- **Then** once the final response settles, shrink-correction may clean up empty space below the last message, but only after the active-turn viewport owner has been released

### Assistant message reconciliation is non-regressive

- **Given** an assistant message has already been applied locally (live stream or earlier fallback)
- **When** a duplicate, stale, or out-of-order event for the same assistant message arrives
- **Then** the client never regresses visible text, completion flags, or metadata — newer authoritative events only add missing completion/order data, never rewrite earlier committed content
- **Then** if the incoming payload is identical to the local copy or older than the local delta version, the client ignores it without disturbing the visible message

### Fallback healing uses local delta versions

- **Given** the realtime stream misses events and the client falls back to polling/fetch healing
- **When** the fallback path emits a candidate replacement for an existing assistant message
- **Then** the client compares the fallback against the local monotonic delta version captured when the fallback was scheduled
- **Then** a fallback may replace content only if no newer local delta has advanced the same message since scheduling
- **Then** out-of-order or stale fallback payloads cannot regress the visible message

### Completed `message.created` duplicate fallback is skipped

- **Given** a fallback or replay path emits a `message.created` event for an assistant message
- **When** that assistant message already exists locally with completion metadata
- **Then** the client skips the duplicate `message.created` and does not insert a second copy
- **Then** a subsequent `message.updated` for the same authoritative message can still apply authoritative completed order and metadata on top of the existing entry

### Stale fallbacks merge completion and metadata only

- **Given** a fallback payload arrives with an older revision or stale order
- **When** the client reconciles that fallback against the local copy
- **Then** only completion flags and authoritative metadata such as completion timestamp, model/provider, cost, tokens, mode, summary, or error are merged
- **Then** earlier text or tool content is not overwritten by the stale fallback

### Streaming deltas are batched around one frame

- **Given** the assistant is streaming text, reasoning, or tool deltas
- **When** multiple delta notifications arrive within the same frame window
- **Then** the client coalesces them so only one rebuild per frame is performed
- **Then** the batching window is approximately one frame (~16 ms) so the UI stays smooth without per-delta rebuild churn

### Session idle flushes pending deltas and ends active composer state

- **Given** the server emits `session.idle` for the active session
- **When** the client processes that signal
- **Then** any pending streaming delta notifications are flushed and applied
- **Then** the active composer state (streaming/processing indicator) ends and the composer returns to its idle appearance
- **Then** the flush happens even if fallback delivery streams are still draining internally

### Final assistant reveal animation is bounded

- **Given** the final assistant message becomes available after a tool/work phase
- **When** the chat reveals that final message
- **Then** the reveal animation lasts approximately 220 ms
- **Then** the reveal uses at most three scroll-to-bottom passes to land at the reveal position
- **Then** if the whole final message already fits in the viewport, no extra reposition is performed

### Jump-to-latest FAB hides while the latest reply is being read

- **Given** the user is reading the chat timeline
- **When** the latest completed/settled assistant message is visibly being read
- **Then** the `Go to latest` FAB stays hidden
- **Then** if the user manually scrolls away during an active turn, the FAB remains available so the user can return to the bottom

### Older-message prepends preserve the viewport with a microtask heal

- **Given** the user scrolls to the top threshold of the chat timeline
- **When** older message batches are prepended
- **Then** the viewport anchor is restored using a microtask plus a double-extent adjustment
- **Then** the reading position stays stable with no visible jump into old history or snap-back churn

### Compaction decisions are value-equal

- **Given** the client evaluates whether to apply a fallback compaction decision
- **When** the decision is compared to the local state
- **Then** the comparison is value-equal on `shouldDeferLatestCollapse`, `latestRevealableAssistantMessageId`, and `settledLatestAssistantWorkGroupId`
- **Then** reapplying the same logical compaction does not change visible state
- **Then** only decisions with different relevant fields invalidate the local timeline cache

---

## Composer

### Composer status tips include agent prompting guidance

- **Given** the assistant is thinking or receiving a response and composer tips are enabled
- **When** the fixed composer status slot falls back to a tip
- **Then** CodeWalk rotates localized short tips that cover both composer controls and general agent prompting practices
- **Then** the agent guidance includes starting with the end goal, naming relevant files/screens/commands, stating constraints, asking for a plan on large tasks, defining expected tests/checks, sharing prior attempts/errors, requesting alternatives, asking for docs updates when behavior changes, adding acceptance criteria, and choosing focused agents for planning/review/build work
- **Then** disabling composer tips keeps the same status slot but shows the static reasoning fallback instead of rotating guidance

### Microphone button visual behavior

- **Given** the composer input is visible
- **When** voice input is idle (not listening)
- **Then** the microphone button uses a transparent background, preserving the composer bubble look
- **When** voice input is active (or starting)
- **Then** the microphone button background turns red to indicate active capture
- **Then** the button is visually aligned with the right edge curvature of the composer input

### Message history navigation

- **Given** the user has sent previous messages in the session
- **When** the user presses the up/down arrow key in the desktop composer
- **Then** normal multiline editor movement takes priority first — explicit newlines and soft-wrapped lines consume ArrowUp/ArrowDown while the caret can still move vertically inside the current draft/history entry
- **Then** once the caret is already on the first visual line (`ArrowUp`) or last visual line (`ArrowDown`), the composer resumes sent-message history navigation
- **Then** the composer cycles through previously sent messages
- **Then** for single-line history entries, if the cursor is not already at the start/end boundary, the first key press moves it there; the second press continues cycling
- **Then** ArrowUp/ArrowDown with modifier keys (`Shift`, `Ctrl`, `Alt`, `Meta`) stay with the text field's default editing behavior and do not trigger history navigation

### File and agent mentions with @

- **Given** the user is typing in the composer
- **When** the user types `@`
- **Then** a mention picker appears with two types of suggestions: project files and available agents
- **Then** file results are fetched live from the server's project file search API (up to 12 results per query)
- **Then** agent results come from the locally cached agent list provided by the server

### Slash commands with /

- **Given** the user is typing in the composer
- **When** the user types `/`
- **Then** a command picker appears with available slash commands
- **Then** selecting a builtin command from that picker runs the local action immediately
- **Then** selecting a non-builtin command inserts the slash-command prefix into the composer so the user can add optional arguments before sending

The following commands are always available (builtin):

| Command | Action |
|---------|--------|
| `/new` | Start a new conversation |
| `/model` | Open the model selector |
| `/models` | Open the model selector |
| `/sessions` | Open the conversations surface |
| `/agent` | Open the agent selector |
| `/open` | Quick-open a project file |
| `/help` | Show available commands |
| `/compact` | Compact (summarize) the current session context |
| `/thinking` | Toggle Thinking bubbles |
| `/undo` | Undo the last visible user turn |
| `/redo` | Redo the last undone turn |

Additional commands may be provided by the connected OpenCode server and merged into the picker alongside the builtins.

- **Given** the user sends a slash command from the composer
- **When** the command name matches a builtin slash command
- **Then** CodeWalk runs the local builtin action instead of sending a normal chat prompt

- **Given** the user sends a non-builtin slash command from the composer
- **When** the command is dispatched
- **Then** CodeWalk executes it through the OpenCode slash-command API (`POST /session/:id/command`) instead of the normal prompt send path
- **Then** the typed slash command remains visible as the initiating user turn while the server response renders in the conversation

### Terminal workspace

- **Given** the user is in the chat workspace with an active OpenCode server connection
- **When** the user taps the AppBar terminal button
- **Then** CodeWalk toggles an embedded terminal panel inside the chat workspace instead of reusing the composer input mode
- **Then** CodeWalk creates or reconnects to a server-hosted PTY terminal rooted in the active project directory on the OpenCode host and renders it inside the embedded panel
- **Then** `Close terminal` fully closes the panel and terminates the active server PTY session, while `Minimize terminal` hides the panel without stopping that session
- **Then** `Maximize terminal` moves the same terminal session into a full-screen overlay that covers the AppBar, conversations/sidebar area, composer, and desktop panes while respecting the platform safe area and soft-keyboard insets
- **Then** `Restore terminal size`, `Escape`, or the mobile system back gesture returns the same terminal session to the inline panel at the saved panel height without reconnecting or resetting the PTY
- **Then** on Windows, printable hardware keyboard input, including AltGr characters from international layouts, is forwarded to the terminal session instead of being dropped after focus
- **Given** the user is on a compact/mobile chat layout
- **When** the embedded terminal is open
- **Then** CodeWalk hides the composer input area until the terminal is minimized or closed so the terminal can use the available screen space
- **Then** mobile soft-keyboard Backspace sends a terminal backspace instead of being ignored while editing the current shell input
- **Given** an active embedded terminal has the software keyboard open on Android or iOS
- **When** the terminal input controls appear above the keyboard
- **Then** CodeWalk shows localized, accessible keys for `Escape`, `Tab`, one-shot `Ctrl` and `Alt`, and all four arrow directions while keeping terminal focus and the keyboard input connection active
- **Then** on Android, reconnect, maximize/restore, close, and minimize respond to the first quick, stationary touch even if the IME cancels the normal tap sequence; holds past the long-press threshold, drags, background transitions, and a normally completed tap never trigger a recovery action
- **Then** `Ctrl` and `Alt` can be armed independently, apply together when both are selected, and clear after the next terminal input that produces output; empty IME updates and physical modifier keys do not consume them
- **Then** tapping an arrow sends one movement, while holding it repeats the same resolved movement until release or cancellation
- **Then** the controls scroll horizontally on narrow screens, respect the platform safe area, and disappear when the keyboard closes, the terminal becomes inactive, or the terminal surface is replaced
- **Then** desktop and web terminal input remain unchanged and never show the mobile extra-key strip
- **Given** the user is on an unsupported platform
- **When** the user taps the same terminal button
- **Then** CodeWalk opens an informational sheet explaining that the embedded server terminal is unavailable there and points the user to composer shell mode instead
- **Then** composer shell mode remains a separate one-shot command path backed by `POST /session/:id/shell`

### Host quota / rate-limit monitoring

- **Given** the user opens the `Context usage` popup from the chat status bar
- **When** quota data is available from the connected host
- **Then** usage, token, cost, and limit metrics are shown in a compact two-column grid
- **Then** the `Compact now` action fills the popup width so tapping anywhere on that action row triggers compaction
- **Then** CodeWalk shows a `Provider Quotas` section at the bottom of that popup after the `Compact now` action
- **Then** providers are grouped by parent organisation; each group shows a severity-colored progress bar for the most constrained sub-quota and a `Pace` chip that shows the predicted percentage of the window that will be consumed at the current usage rate
- **Then** tapping a provider group row expands it to reveal individual quota entries (requests, tokens, cost, etc.) each with its own bar and remaining figure
- **Then** on desktop, hovering the `Pace` chip shows a tooltip explaining the prediction; on mobile, tapping it shows a dismissible snackbar
- **Given** the host exposes OpenChamber-compatible REST endpoints (`GET /api/quota/providers`)
- **When** the popup is opened (or every 60 seconds in background)
- **Then** CodeWalk fetches live quota data from those endpoints without any client-side credentials
- **Then** any provider returned by the REST endpoint can appear in the popup, including newer host-side providers such as Snowflake Cortex, Grok/xAI, or Cohere North when the connected server supplies them
- **Given** the host does not expose OpenChamber endpoints
- **When** quota data is requested
- **Then** CodeWalk falls back to a hidden ephemeral shell session that probes `CW_QUOTA_JSON` without appearing in the user's conversation list
- **Given** the host's OpenCode `auth.json` has an `opencode-go` key and dashboard credentials are available from either the host environment or CodeWalk's secure server-scoped storage
- **When** the `Provider Quotas` popup is opened
- **Then** CodeWalk shows rolling, weekly, and monthly usage bars for the `OpenCode Go` provider
- **Given** OpenCode Go is configured but dashboard credentials are missing or expired
- **When** the `Provider Quotas` popup is opened
- **Then** CodeWalk shows an `OpenCode Go detected` setup card with a `Connect` or `Reconnect` action
- **Then** the setup dialog can open `https://opencode.ai/auth`, save the workspace ID and auth cookie in secure storage, refresh the quota probe, and forget saved credentials later
- **Then** if neither path returns data, the `Provider Quotas` section is silently omitted from the popup
- **Then** outside the explicit OpenCode Go dashboard opt-in, the client never stores, manages, or forwards provider credentials; quota ownership stays on the server host by default
- **Given** the host has configured credentials for `NanoGPT`, `Wafer.ai`, `GitHub Copilot Add-on`, `Kimi for Coding`, `Zhipu AI Coding Plan`, `MiniMax Coding Plan`, `z.ai`, `Cursor`, or `Ollama Cloud`
- **When** the `Provider Quotas` popup is opened
- **Then** CodeWalk displays their respective usage windows, rate limits, and remaining credits
- **Then** `minimax-cn-coding-plan` uses inverted remains semantics to calculate utilized percentage (`used = total - remaining`)
- **Then** both `minimax-coding-plan` and `minimax-cn-coding-plan` fall back to the API's `current_*_remaining_percent` field when `current_*_total_count` is `0` (Coding Plan rate-limit has no hard count cap), so the popup filter never hides the row
- **Then** the fallback computes `usedPercent = max(0, min(100, 100 - remainingPercent))` to keep the value in the standard 0–100 range
- **Then** `cursor` falls back to querying the local Cursor SQLite database on macOS hosts if environment tokens are missing
- **Then** `ollama-cloud` parses HTML scraping safely, falling back to a descriptive error if the HTML format changes
- **Then** newer provider aliases for Snowflake Cortex, Grok/xAI, and Cohere North are recognized by the shell fallback diagnostics so they are not shown as unknown configuration
- **Then** those newer providers only produce visible quota rows through REST until a dedicated shell probe is implemented

---

## Attachments

### Image and PDF attachments

- **Given** the user is composing a message
- **When** the user attaches an image or PDF
- **Then** the file is attached to the message and sent along with the text
- **Then** when the selected model supports both image and PDF inputs, `Attach files` opens a single multi-select picker for supported image/PDF files
- **Then** the type-specific image and PDF pickers remain available as direct fallbacks
- **Then** every valid selected file is shown as its own composer chip before send
- **Then** if the platform only returns one selected file, that file is still attached safely
- **Then** if a mixed selection includes unsupported or unreadable files, valid files stay attached and the composer shows feedback that some files could not be attached

### Model capability gating

- **Given** the selected model does not support vision
- **When** the user tries to attach an image
- **Then** the attachment option is disabled or shows clear feedback that the model cannot process images

---

## Voice Input

### Speech-to-text in the composer

- **Given** the user activates voice input
- **When** the user speaks
- **Then** the speech is converted to text and inserted into the composer input
- **Then** keyboard shortcut activation uses the same start/stop flow as the microphone button
- **Then** if the composer is disabled, keyboard shortcut activation is ignored and voice input does not start

### Cross-platform support

- **Given** any supported platform (Android, Linux, macOS, Windows, Web)
- **When** the user activates voice input
- **Then** the STT feature works on all platforms where the device has a microphone

The app uses a platform-aware speech engine strategy with automatic fallback where supported:

| Platform | Primary engine | Notes |
|----------|---------------|-------|
| Android | Native (system speech recognizer) | Sherpa/Moonshine runtimes excluded from Android build; Native only |
| Linux | Sherpa ONNX or Moonshine via sherpa_onnx | On-device models are downloaded on demand; Native not supported on Linux |
| macOS | Native (system speech recognizer) | Falls back to Sherpa ONNX if native unavailable; Moonshine is an optional desktop engine |
| iOS | Native (system speech recognizer) | Native only in the current app build |
| Windows | Parakeet or another on-device engine via CodeWalk WASAPI capture | Native Windows speech recognition is disabled for stability; model setup is shown when the selected on-device model is missing; Windows settings links remain available for microphone troubleshooting |
| Web | Native (system speech recognizer) | Browser speech only |

### Windows STT uses on-device engines through CodeWalk WASAPI capture

- **Given** the user is on Windows desktop
- **When** the user opens `Settings > Speech` or uses the voice input button
- **Then** `Native` is disabled with an explanation that CodeWalk avoids Native Windows speech recognition for stability
- **Then** `Sherpa`, `Moonshine`, `Parakeet`, and `SenseVoice` are selectable when their model/runtime path is supported
- **Then** Windows microphone capture for those on-device engines uses the runner-owned WASAPI backend, not `record_windows`
- **Then** the engine card shows a Windows setup card with troubleshooting buttons: "Open microphone settings" (`ms-settings:privacy-microphone`), "Open speech privacy" (`ms-settings:privacy-speech`), and "Open speech settings" (`ms-settings:speech`)
- **When** the app loads existing settings on Windows and finds a previously saved `Native` selection
- **Then** the selection is migrated to `Parakeet` automatically so startup never lands on the unsafe Native engine
- **When** the app loads existing settings on Windows and finds a previously saved Sherpa/Moonshine/Parakeet/SenseVoice selection
- **Then** the on-device selection is preserved
- **When** the selected on-device model is missing
- **Then** voice input opens the matching model setup/download flow instead of falling back to Native
- **When** the Windows WASAPI microphone backend reports microphone denied, no input device, device busy, unsupported format, missing backend, or an unknown failure
- **Then** the user sees a non-crashing unavailable state and the composer snackbar exposes the most relevant Windows settings action
- **When** voice input fails in the composer on Windows
- **Then** the snackbar action maps typed reasons to Windows Settings: speech settings for `noInputDevice`, microphone privacy for `microphoneDenied`, `deviceBusy`, `unsupportedFormat`, `backendUnavailable`, or `generic`

---

## Interactive Prompts

### Permission requests

- **Given** the server needs user approval to perform an action (e.g., execute a command, write a file)
- **When** the server sends a permission request
- **Then** an interactive card appears in the chat with three response options:
- **Allow Once** — approves the action for this single occurrence
- **Always** — approves the action permanently for this session
- **Reject** — denies the action
- **Then** the server waits for the user's response before proceeding
- **Then** the owning session always shows its own permission card
- **Then** when the user is viewing the main/root session of that same thread, descendant sub-session permission cards are mirrored there as well with a source badge that identifies where they came from
- **Then** switching to an unrelated session does not surface that request there
- **When** the user allows (once or always), the server continues the operation
- **Then** the resolved permission request is removed from the local pending state immediately
- **When** the user rejects, the server receives a rejection and the session pauses — the assistant stops and waits for the user to send a new message before continuing

### Composer permission auto-approve toggle

- **Given** the user is in a main/root conversation with the composer controls visible
- **When** the composer is rendered
- **Then** a permission auto-approve toggle is shown to the left of the agent selector
- **Then** the toggle defaults to enabled and persists when the user turns it off
- **When** the toggle is enabled and the current thread receives a permission request
- **Then** the app automatically replies with `Always` when that permission request exposes remembered approval, otherwise it falls back to `Allow Once`
- **Then** mirrored descendant/sub-session permission requests shown in the root thread are auto-approved as part of that same thread scope
- **Then** on Android, the background worker keeps that same thread-scoped permission auto-approve path alive while the app is backgrounded, instead of waiting for foreground return
- **Then** when the active server or project scope changes, the Android background auto-approve context is cleared before the transition finishes so that permission replies cannot leak into the next scope
- **Then** if background auto-approve fails, the permission notification and inline card still remain as the visible/manual fallback path
- **Then** question prompts are never auto-answered by this toggle and still require a human choice
- **Then** the existing inline permission cards remain available as the visible/manual fallback path

### Question prompts

- **Given** the server needs the user to choose between options
- **When** the server sends a question prompt
- **Then** an interactive card appears with the question and selectable options
- **Then** the server waits for the user's response before proceeding
- **Then** the owning session always shows its own question card
- **Then** when the user is viewing the main/root session of that same thread, descendant sub-session question cards are mirrored there as well with a source badge that identifies where they came from
- **Then** switching to an unrelated session does not surface that question there
- **When** the user replies or rejects the question
- **Then** the resolved question request is removed from the local pending state immediately

---

## File Explorer

### Project tree file management

- **Given** the user opens the file explorer panel
- **When** the project tree loads
- **Then** the user sees the file/folder structure of the current project
- **Then** slow root and directory loads show inline skeleton rows instead of a blocking centered spinner
- **Then** per-directory load failures stay localized to the expanded directory and expose a retry action without replacing the whole tree
- **When** the active server and project directory support shell-backed file operations
- **Then** desktop secondary-click and mobile long-press open row actions for `New file`, `New folder`, `Rename`, `Delete`, `Copy path`, and `Refresh files` as applicable
- **Then** the file explorer header exposes a root-level `New` menu for creating files or folders at the project root
- **Then** create, rename, delete, and save mutations run in hidden ephemeral OpenCode shell sessions scoped to the active project root, validate leaf names, use one negotiated single-pipeline transport per mutation, cache the supported decoder per active project root, parse official shell tool output/error completion states, extract the final `CW_FILE_OP_JSON:` sentinel result, refresh affected tree caches, and reconcile open file tabs
- **Then** delete requires confirmation before mutating the server filesystem
- **Then** failed delete operations surface bounded actionable diagnostic detail when available instead of only the generic failure label
- **Then** diagnostics for failed mutations log only the operation code and hashed path identifiers; raw shell stderr and filesystem paths are not logged
- **Then** mutating actions are hidden when the shell probe is unavailable, the current directory is missing, or the project root is `/`; read-only actions remain available

### File preview

- **Given** the file explorer is open
- **When** the user taps a file
- **Then** a preview/visualization of the file content is shown

---

## Task List

### Agent-controlled task list

- **Given** the AI agent is executing a multi-step task
- **When** the agent reports its task progress
- **Then** a task list is displayed in the session showing the agent's current and completed steps
- **Then** the task list is read-only for the user — it is controlled entirely by the server/agent

### Header progress indicator for tasks

- **Given** the current session has a visible task list
- **When** the task list is rendered in either collapsed or expanded mode
- **Then** a single thin, full-width progress bar appears directly below the task header (same position in both states)
- **Then** the progress value represents completed tasks divided by total tasks
- **Then** progress changes animate smoothly with an ease-in-out transition between values

### Compact mobile collapsed task summaries are count-first

- **Given** the session task panel is collapsed on a compact viewport (mobile width)
- **When** at least one task is in progress
- **Then** the header summary uses compact count-first text (`x/y in progress`) without including task content text
- **When** no task is in progress
- **Then** the header summary uses compact completion text (`x/y done`)

### Task snackbars without actions dismiss on tap

- **Given** the chat page shows a snackbar without an explicit action button
- **When** the user taps anywhere on that snackbar
- **Then** the snackbar dismisses immediately without waiting for timeout

### In-app snackbars adapt to viewport size

- **Given** CodeWalk shows an in-app snackbar/toast message
- **When** the viewport is compact/mobile-sized
- **Then** simple messages render as floating transient toast-style bars without a default close icon
- **Then** action buttons, when provided by the message, remain the explicit user action instead of duplicating a close affordance
- **When** the viewport is wide/desktop-sized
- **Then** floating snackbars use a constrained lateral layout instead of spanning across the full app width
- **Then** the same event is still rendered through a single snackbar path, not duplicated as both a toast and a persistent box

---

## Layout

### Mobile: chat-first with drawer

- **Given** the app is running on a mobile device (compact screen)
- **When** the user navigates the app
- **Then** the chat occupies the full screen, with the session list accessible via a lateral drawer

### Mobile app bar pinned actions

- **Given** the app is running on a mobile device (compact screen)
- **When** the user has app-bar actions pinned
- **Then** up to three pinned action icons are shown before the overflow menu
- **Then** persisted two-action pin lists remain unchanged after upgrade
- **Then** persisted oversized pin lists are normalized to the latest three actions
- **Then** pinning a fourth action drops the oldest pinned action and keeps the latest three visible

### Mobile back follows conversation hierarchy

- **Given** the app is running on mobile and the chat page owns the system back action
- **When** the current session is a sub-conversation
- **Then** the first back action returns to the immediate parent conversation; repeated back actions walk the hierarchy one level at a time
- **When** the current session is already the root conversation and the drawer is closed
- **Then** the next back action opens the conversations drawer
- **When** the drawer is already open
- **Then** the next back action sends the app to the background

### Mobile drawer status indicator (hamburger)

The hamburger icon has exactly one active state at a time:

- **Default (no badge)**: normal operation; no urgent or loading condition is active
- **Attention dot**: shown when another visible conversation in the current project needs attention because it has an error, is waiting for user input, or received a new unread assistant reply
- **Loading spinner**: shown only when all three conditions are true simultaneously:
  1. The app returned from background and is actively resynchronizing (`isForegroundResumeSyncing`)
  2. The sync state is recoverable (reconnecting, delayed, or degraded — not failed)
  3. The Android foreground service is NOT running
- **Red dot badge**: shown when an urgent condition persists beyond the grace period:
  - Active server health probe is `unhealthy` (including offline probe failures), OR
  - Recoverable sync alert has escalated (unresolved for too long)
- **Saver dot**: shown when `Cellular data saver` is actively throttling mobile network work and no higher-priority alert/attention/loading state is active

Transient connectivity blips that do not escalate are surfaced via loading/sync states, not as urgent red health alerts.

### Mobile drawer explains the active hamburger indicator

- **Given** the mobile drawer is open and the hamburger indicator is showing a dot or loading spinner
- **When** the `Conversations` section is rendered
- **Then** a compact notice appears above `Conversations` explaining the current active reason
- **Then** if the reason has a natural destination, tapping the notice opens the relevant settings section or conversation
- **Then** the notice has no close button and disappears automatically as soon as the hamburger indicator returns to its default no-badge state

### Desktop: split view

- **Given** the app is running on a desktop (expanded screen)
- **When** the user navigates the app
- **Then** the session list is always visible alongside the chat in a split-view layout

### Desktop conversations list is denser than mobile

- **Given** the Conversations sidebar is rendered on desktop
- **When** project groups and session rows are shown
- **Then** desktop uses compact spacing between project groups and conversation rows to increase visible item density
- **Then** conversation rows use floating attention badges instead of a dedicated leading session icon so more horizontal space stays available for the title and metadata
- **Then** mobile keeps its original touch-friendly spacing

### Desktop: system tray

- **Given** the app is running on Linux, macOS, or Windows
- **When** the app is open (foreground or background)
- **Then** a tray icon is shown in the system notification area
- **Then** the tray menu provides two actions: **Show** (bring the window to front) and **Quit** (force-quit the app, bypassing close-to-tray)

### Keyboard shortcuts

- **Given** a physical keyboard is connected (desktop or mobile with external keyboard)
- **When** the user presses a keyboard shortcut
- **Then** the corresponding action is executed (shortcuts work on desktop and on mobile with an external keyboard)

Most shortcuts use `mod` (Cmd on macOS, Ctrl on other platforms), with conflict-sensitive actions using explicit modifiers. Shortcuts are user-configurable in Settings:

| Shortcut | Action | Notes |
|----------|--------|-------|
| `mod+n` | New conversation | |
| `mod+r` | Refresh data | |
| `mod+l` | Focus composer input | |
| `alt+shift+s` / `option+shift+s` | Start or stop voice input | Requires Shift to avoid accidental STT activation on desktop |
| `mod+p` | Quick-open project file | |
| `mod+,` | Open Settings | |
| `mod+m` | Cycle recent/favorite models | |
| `mod+t` | Cycle model variants | |
| `alt+shift+j` / `option+shift+j` | Next agent | Avoids intercepting `Ctrl+J` line-feed input used by terminals and CLIs |
| `alt+shift+k` / `option+shift+k` | Previous agent | Avoids intercepting `Ctrl+J` line-feed input used by terminals and CLIs |
| `mod+w` | Close tab/application | When session tabs are enabled and the selected tab matches the current session/context, closes that local tab; otherwise preserves the platform app-close behavior |
| `Escape` | Restore full-screen terminal / close drawer / focus input | Double-press stops active response |
| `mod+q` | Force-exit app | On desktop, bypasses close-to-tray/minimize; on Android and iOS it exits the app surface |

- **Given** session tabs are enabled and the selected tab represents the current session in the active project context
- **When** the user presses `mod+w`
- **Then** exactly that local tab closes once, using the same right-neighbor, left-neighbor, `New Chat`, `Snackbar`, and `Undo` behavior as tab gestures, without mutating the OpenCode session
- **Then** dialogs and other routes keep priority and block the chat shortcut
- **When** tabs are disabled, no valid current tab exists, or the current context does not match the selected tab
- **Then** `mod+w` keeps the existing platform close/minimize/tray behavior; custom bindings apply to both paths, while `mod+q` remains an independent force-exit action

### Enter confirms safe modal primary actions

- **Given** a modal dialog has a single clear, non-destructive primary action
- **When** the user presses `Enter` or `NumpadEnter`
- **Then** the dialog may trigger that primary action without requiring a tap/click
- **Then** destructive confirmations, shortcut-capture dialogs, multiline canned-answer editing, and picker/search/selector bottom sheets remain excluded from this shortcut policy

### Single `Escape` restores composer focus when available

- **Given** no drawer, dialog, or composer popover owns the `Escape` key
- **When** the user presses `Escape` once and the composer is not currently focused
- **Then** the composer input becomes focused
- **Then** if the composer already owns focus, composer-level `Escape` handling keeps priority (for example popover close, shell exit, or double-`Escape` stop while responding)

### Mobile keyboard collapses the task panel

- **Given** the task list panel is expanded on mobile
- **When** the on-screen keyboard appears
- **Then** the task list panel automatically collapses to free space for the chat and composer
- **Then** when the keyboard is dismissed, the panel returns to its previous state (expanded or collapsed)

### Physical-keyboard send keeps composer focus

- **Given** the app is running with a physical keyboard available (desktop, or mobile with external keyboard)
- **When** the user sends a message from the composer
- **Then** the composer input keeps focus so the user can continue typing immediately

---

## Provider and Model Selection

### Selecting a provider and model

- **Given** the connected OpenCode server has providers configured (e.g., Claude, OpenAI, Gemini)
- **When** the user opens the model selector
- **Then** selectable entries are sourced directly from the server `/provider` catalog and limited to non-hidden, non-deprecated models from connected providers
- **Then** dynamic free OpenCode Zen models from provider `opencode` with zero input cost are also listed even when no provider credentials are configured, and they are marked as free
- **Then** similarly named providers such as `opencode-go` are listed only when the server reports them as connected
- **Then** the app restores the last successful provider/model catalog snapshot for the active server immediately and revalidates it in the background, so same-server project switches avoid showing an empty selector whenever possible
- **Then** the user can select any listed model to use for the current session; stale persisted, favorite, recent, remote, or message-derived selections outside this rule are ignored

### Model variants and reasoning effort

- **Given** the selected model supports variants (e.g., reasoning effort levels)
- **When** the user opens the variant selector
- **Then** the available variants are listed and one can be selected for the session

### Favorite models

- **Given** the user stars a model in the model selector
- **When** the model selector is opened again
- **Then** starred models appear in a **Favorites** section above recent models
- **Then** favorites are persisted locally per server, shared across projects on that same server, and not shared across different servers

### Recent model cycling

- **Given** the user has previously selected models in the session
- **When** the user presses `mod+m`
- **Then** the app cycles through favorite models first, then recent models, applying the selection immediately

### Alt+Tab-style shortcut cycling (model, agent, variant)

- **Given** the user is using keyboard cycling shortcuts (`mod+m`, `alt+shift+j`, `alt+shift+k`, `mod+t`)
- **When** the user triggers one of these shortcuts
- **Then** the first trigger behaves like Alt+Tab and switches to the previously used item in that domain (model, agent, or variant)
- **Then** if the user triggers again within 3 seconds, cycling continues through a burst snapshot in recency order
- **Then** the snapshot prioritizes the two most recent items first, but is **not limited to two** — third and later candidates are reachable with repeated quick presses
- **Then** if the user waits more than 3 seconds between triggers, the burst session resets and the next trigger starts again from the previous-item hop
- **Then** shortcut keybindings themselves do not change; only cycling behavior changes

### Agent selection

- **Given** the connected server provides agents (specialized AI configurations)
- **When** the user opens the agent selector or types `/agent`
- **Then** all available agents are listed and one can be selected
- **When** the user presses `alt+shift+j` / `alt+shift+k`
- **Then** the app cycles forward/backward through the available agents

### Agent changes restore the last compatible local model choice

- **Given** the user previously used a specific provider/model/variant combination with an agent in the current server/project context
- **When** the user switches back to that agent later
- **Then** the app restores the last compatible local provider/model selection remembered for that agent
- **Then** the remembered variant is restored only when that variant still exists for the restored model
- **Then** explicit remote/session-scoped selections still take precedence over this local per-agent memory

---

## Settings

### Settings pickers are searchable

- **Given** the user opens a settings select field (for example theme presets, OpenCode-backed defaults, sound type, active server, or Sherpa language)
- **When** the user taps the field
- **Then** the app opens a searchable picker with a search input inside the picker surface
- **Then** typing filters the available options locally so long lists are faster to navigate on mobile and desktop

### Theme selection

- **Given** the user is in settings
- **When** the user selects a theme
- **Then** the app supports light, dark, and AMOLED themes, plus Material You dynamic color from the system wallpaper
- **Then** the `OpenCode Presets` picker mirrors the official OpenCode Web built-in theme registry rather than the older limited docs list

### Visual style selection

- **Given** the user opens `Settings` > `Appearance`
- **When** the user changes `Visual style` between `Classic` and `Refined`
- **Then** the setting applies immediately and persists in `ExperienceSettings` across app restarts
- **Then** new installations start with `Refined` selected by default
- **Then** older persisted settings that do not contain a `visualStyle` key continue to open in `Classic` for compatibility
- **Then** selecting `Classic` preserves the existing Material 3 surface treatment
- **Then** `Refined` applies quieter CodeWalk-specific surface, radius, separator, tint, and shadow tokens to the app theme, chat composer, message bubbles, timeline status cards, snackbars, and sidebar/session rows
- **Then** changing `Visual style` does not change the selected color palette, OpenCode preset, dynamic color preference, AMOLED dark preference, density, text scale, locale, or OpenCode server behavior

### OpenCode presets recolor markdown and code surfaces

- **Given** the user has an OpenCode preset active
- **When** chat markdown or the file viewer renders inline code, fenced code blocks, or syntax-highlighted files
- **Then** those surfaces use theme-aware colors derived from the active OpenCode Web theme instead of a generic brightness-only fallback
- **Then** changing the preset updates those markdown/code colors without requiring an app restart

### Text size controls in Appearance

- **Given** the user opens `Settings` > `Appearance` and scrolls to the `Text size` card
- **When** the card is visible
- **Then** the app exposes three independent sliders: `System`, `Conversation`, and `Terminal`
- **Then** each slider shows its current value in percent (`%`) and the actual point size for the terminal slider
- **When** the user moves the `System` slider
- **Then** all CodeWalk UI text scales proportionally using a single global `MediaQuery` text scaler (Material `TextScaler.linear`) installed in the app shell
- **Then** the value is clamped to the safe range `80%–160%` and the slider is reset to the closest valid value if the user drags past the limits
- **When** the user moves the `Conversation` slider
- **Then** only chat timeline messages and the composer input scale by that factor, multiplied on top of the system scale
- **Then** settings, sidebar, and other surfaces outside the chat viewport are not affected
- **Then** the value is clamped to the safe range `80%–160%`
- **When** the user moves the `Terminal` slider
- **Then** the embedded terminal font size updates live and the value is clamped to the safe range `9–22 pt`
- **Then** the new terminal font size persists across sessions and the next time the terminal is opened
- **When** any of the three sliders is moved
- **Then** the new value is persisted to `ExperienceSettings` and survives app restart
- **Then** the change is applied without restarting the active response, the active server, or the embedded terminal stream
- **When** the app reads a stored value that is outside the supported range (for example a stale JSON snapshot)
- **Then** the value is clamped to the safe min/max on load so the UI never receives an illegal scale

### Local persistence

- **Given** the user changes any setting
- **When** the setting is saved
- **Then** it persists locally (survives app restart) via SharedPreferences / SecureStorage

### Shared settings show provenance explicitly

- **Given** the user opens Settings sections that mix OpenCode-compatible behavior with CodeWalk-specific behavior
- **When** provenance context matters for maintenance or cross-client expectations
- **Then** the UI labels the surface as `OpenCode-backed`, `CodeWalk-local`, or `CodeWalk exception`
- **Then** those labels describe ownership only; they do not imply full editing support for every OpenCode config file

### OpenCode-backed defaults cover the completed shared settings slice

- **Given** the user opens `Behavior` settings
- **When** the shared defaults card loads successfully from `/config`
- **Then** the user can edit the completed OpenCode-backed settings in CodeWalk: default model, default agent, small model, autoupdate, share, username, and snapshot
- **Then** these changes are written back to `/config` only when the server is idle, so active responses are not aborted by config mutation timing

### Permission handling provenance is documented in settings

- **Given** the user opens `Behavior` settings
- **When** the permissions provenance card is visible
- **Then** the app explains that official OpenCode permission policy is file-based (`opencode.json`) rather than fully edited from the GUI
- **Then** the card also identifies the composer permission auto-approve toggle as the approved CodeWalk exception covered by ADR-023

### Cellular data saver is documented in Behavior settings

- **Given** the user opens `Behavior` settings
- **When** the cellular data saver card is visible
- **Then** the app exposes a `CodeWalk exception` toggle that defaults to enabled
- **Then** the card explains that mobile/cellular connections suppress automatic background network work and throttle automatic foreground refreshes
- **Then** standard cellular saver uses the 1-minute foreground cadence
- **Then** aggressive cellular saver keeps automatic work scoped to the visible chat session, skips inactive session/context refreshes, does not subscribe to `/global/event`, pauses the project event stream while the visible session is idle, and uses a 30-second retained automatic cadence while manual actions remain immediate

### Keyboard shortcuts are CodeWalk-local

- **Given** the user opens `Shortcuts` settings on a platform that supports the section
- **When** the shortcuts screen is rendered
- **Then** the UI labels the bindings as `CodeWalk-local`
- **Then** editing those bindings updates CodeWalk runtime preferences only and does not write OpenCode `tui.json` keybinds

### Automatic update checks while app is open

- **Given** `Check for updates on open` is enabled
- **When** the app remains open
- **Then** a silent update check runs at startup and repeats every 1 hour while the app process is alive
- **Then** the automatic check never shows a manual spinner/up-to-date confirmation; it only surfaces UI when a newer, non-dismissed version is found

### Settings landing update notice

- **Given** a newer, non-dismissed CodeWalk version was found by an update check
- **When** the user opens the main `Settings` screen
- **Then** CodeWalk shows a visible but non-blocking update notice at the top of the Settings landing list, before setup, tour replay, and section rows
- **Then** the notice shows the installed version/build and the available version when package metadata is available
- **Then** Android and desktop users get the same install/progress/retry/dismiss controls used by `Settings` > `About`
- **Then** web or unsupported direct-install cases open the release page when a release URL is available
- **Then** the notice is not shown when no newer version is known or when the user dismissed that version
- **Then** temporary update-check failures remain silent and do not block Settings

### Desktop update install snackbars

- **Given** an update install is started on desktop (Linux, macOS, Windows)
- **When** the installer script is running
- **Then** the app shows an indefinite loading snackbar (`Installing update...`) until the install state settles
- **Then** on success, the app shows a completion warning snackbar with a `Restart` action so the user can relaunch into the new version
- **Then** on Windows, the initial install step stages the downloaded update without modifying the running install directory
- **Then** on Windows, the `Restart` action starts an updater helper, closes CodeWalk, applies the staged update after the old process exits, and relaunches CodeWalk from the updated install path

### Snackbars are always manually dismissible

- **Given** the app shows any snackbar
- **When** the snackbar is visible
- **Then** it always includes a close (`X`) affordance so the user can dismiss it immediately without waiting for timeout
- **Then** existing semantic actions (for example `Retry`, `Restart`, or `Install`) remain available alongside the dismiss affordance

---

## Session Attention

### Opt-in presentation modes

- **Given** Session attention is `Off` by default
- **When** the user selects `Bubble` or `Panel` in Settings
- **Then** Android requests display-over-other-apps permission before starting a non-exported `specialUse` foreground service, desktop reuses one always-on-top mini-window, and iOS renders the same controls only inside CodeWalk
- **Then** stopping the host or revoking Android overlay permission persists the mode back to `Off`

### Root-session aggregation and privacy

- **Given** multiple projects on the active server have root sessions needing attention
- **When** status, completion, permission/question, or error state changes
- **Then** CodeWalk publishes one immutable, revisioned aggregate ordered as error, pending interaction, completed, delayed, receiving, then active
- **Then** child sessions, archived sessions, inactive servers, reasoning parts, tool payloads, credentials, and full transcripts are excluded
- **Then** completion previews are fetched with `limit=20`, retried at 500 ms, 1.5 s, and 3 s, truncated by Unicode scalar count, and stored only in an AES-256-GCM authenticated snapshot with its key in platform secure storage

### Bubble and Panel actions

- **Given** one or more attention items exist
- **When** Bubble is active
- **Then** a compact semantic control shows the highest-priority state and item count; expanding shows the scrollable Panel
- **When** the user chooses Open, Read/Stop reading, Dismiss, Collapse/Expand, or Stop session attention
- **Then** the command targets the exact server, directory, root session, and snapshot; passive updates never navigate or speak
- **Then** Open removes the consumed snapshot after successful navigation, Dismiss writes an encrypted tombstone, and Read uses the configured TTS backend only after the explicit action

### Android overlay composition and bounds

- **Given** Bubble or Panel is visible over another Android app
- **Then** the Flutter surface and host window are transparent outside the rounded Material content instead of drawing an opaque rectangular background
- **Then** the protected overlay keeps `FLAG_SECURE`; screenshots, screen recording, and device mirroring may therefore show the protected area as black even though normal on-device composition is transparent
- **Then** Bubble uses a `96 x 96dp` base host with user scale applied, while the native host floors each dimension at `56dp` so the `48dp` Bubble and its reserved expand-control area stay inside bounds; Panel remains `360 x 240dp`, and both are constrained to usable display bounds with a `16dp` edge margin
- **Then** Android content is top-centered, dragging persists normalized position, and rotation or display changes re-clamp the overlay without bypassing permission or lock-screen gates
- **Given** the Android overlay does not reach a non-zero layout within 5 seconds, or reaches that layout but does not render its first Flutter frame within the following 5 seconds
- **Then** only the overlay window is removed; the foreground service remains available for a later valid snapshot or lifecycle transition

### Background and transport limits

- **Given** cellular Data Saver suppresses automatic background work or monitoring becomes unavailable
- **When** a session remains busy
- **Then** delayed timing is paused and resumes only after a valid directory-scoped observation; suppressed intervals are never counted
- **Given** Android background transport uses plain HTTP/HTTPS or Basic auth
- **Then** the existing low-data worker may continue monitoring according to Data Saver policy
- **Given** the server requires OAuth or Tailscale after process death
- **Then** background network work is not attempted, the last encrypted snapshot is preserved, and the user must reopen CodeWalk

---

## Notifications

> The OpenCode server does not support traditional push notifications. The app uses platform-native techniques to deliver background alerts reliably while minimizing battery impact.

### Background alerts (Android)

- **Given** the app is running on Android and `Background alerts on Android` is enabled
- **When** the app goes to background without a known active response
- **Then** the app relies on sparse WorkManager checks only; it does not start an immediate fast probe just because the screen was left
- **When** the app goes to background with a known active response
- **Then** the app may keep realtime alive briefly, schedule low-data probes every 3 minutes, and run one 5-minute tail probe after the active work settles
- **Then** the worker fetches only the minimum data needed for completion, error, permission, and question alerts; session metadata is fetched only when needed to label a notification or suppress child-session completion alerts
- **Then** completion, error, permission, and question alerts are scoped per session so one recently-alerted session does not suppress a different session in the same category
- **When** `Cellular data saver` is active on mobile data
- **Then** Android background network checks are suppressed entirely, including periodic probes, active-response probes, and tail probes
- **When** the user disables Android background alerts in Settings
- **Then** no Android background checks run and the persistent monitor notification is removed
- **Then** notifications are intended to fire only while the app is in the background; while in foreground, the user receives real-time updates directly in the chat UI

### Background alerts (Desktop)

- **Given** the app is running on Linux, macOS, or Windows
- **When** background alerts would be relevant
- **Then** the system tray icon serves as the always-present indicator; local notifications may be shown through the OS notification system

### Notification taps open the target session

- **Given** a local notification contains a session payload
- **When** the user clicks or taps that notification
- **Then** CodeWalk brings the app window to the front when the platform supports app activation
- **Then** the app selects the payload session, switching project directory first when the payload includes a different directory
- **Then** the consumed notification is dismissed, and selecting that same session also clears other tracked notifications for the session

### Server offline does NOT notify

- **Given** the active server goes offline
- **When** the app detects the disconnection
- **Then** no notification is sent — server availability is not the app's responsibility. The user sees the status when they open the app.

### Android persistent notification

- **Given** the app is running on Android
- **When** a known active response is being temporarily monitored after the app moves to background
- **Then** a persistent notification is shown in the notification drawer for that temporary live-monitor window only
- **When** Android background alerts are disabled or there is no active live-monitor window
- **Then** the persistent monitor notification is not shown

---

## Background and Lifecycle

### Android foreground service

- **Given** the app is running on Android during a long operation
- **When** the app goes to background while a known response is still active and temporary live monitoring is enabled
- **Then** a foreground service keeps the app alive for that short monitoring window
- **Then** the foreground service is not used as an always-on idle monitor

### Battery optimization prompt

- **Given** the app is running on Android
- **When** battery optimization may interfere with background operation
- **Then** the app prompts the user to disable battery optimization

### Automatic reconnection on resume

- **Given** the app was in background
- **When** the user returns to the app
- **Then** the app automatically reconnects to the server and resynchronizes state (missed messages, updated sessions, etc.)
- **Then** transient resume-time probe failures use a short confirmation window before unhealthy/disconnected warning UI is shown, so false alerts do not flash while connectivity is still settling
- **Then** pending question and permission refreshes merge with live SSE updates during reconnect/resume instead of wiping newer in-memory prompts that arrived while the HTTP refresh was in flight
- **Then** when standard `Cellular data saver` is active on mobile data, resume-time automatic sync is limited to one immediate foreground burst and idle realtime may stay paused afterward until the next 1-minute window or an explicit user action
- **Then** when aggressive `Cellular data saver` is active on mobile data, resume-time automatic sync refreshes only the visible session and visible pending interactions, skips inactive session/context refreshes, and idle realtime may stay paused afterward until the next 30-second automatic tick or an explicit user action

### No duplicate refresh on resume

- **Given** the app resumes from background
- **When** both lifecycle and reconnect triggers fire
- **Then** only one refresh cycle executes — no duplicate network calls

---

## Speech Input

### New Linux installs default to Parakeet when Native is unavailable

- **Given** the app is opened on Linux for the first time with default settings
- **When** speech-to-text settings are initialized
- **Then** the app selects `Parakeet` as the default engine instead of `Sherpa`
- **Then** explicit existing non-native user selections remain unchanged

### Desktop can use Parakeet for offline multilingual speech-to-text

- **Given** the user opens `Settings` > `Speech to text` on Linux, macOS, or Windows
- **When** the user selects the `Parakeet` engine
- **Then** the settings screen shows a dedicated Parakeet model card with install status, download, remove, and refresh actions
- **Then** the app keeps Parakeet downloadable and out of the shipped app bundle

### First Parakeet use prompts model download

- **Given** the user starts voice input with `Parakeet` selected and no local Parakeet model installed
- **When** the composer starts speech input
- **Then** the app opens a blocking `Parakeet Voice Setup` dialog instead of failing silently
- **Then** after the download finishes successfully, the app retries the speech-input start flow automatically

### Parakeet stays desktop-only

- **Given** the app runs on Android, iOS, or Web
- **When** speech-engine availability is evaluated from persisted settings
- **Then** `Parakeet` is treated as unavailable and the app falls back to a supported engine instead of exposing a broken selection

### Desktop can use SenseVoice for CJK-focused offline speech-to-text

- **Given** the user opens `Settings` > `Speech to text` on Linux, macOS, or Windows
- **When** the user selects the `SenseVoice` engine
- **Then** the settings screen shows a dedicated SenseVoice model card with install status, download, remove, and refresh actions
- **Then** the app presents SenseVoice as the strongest built-in option for Chinese, Cantonese, Japanese, Korean, and English

### First SenseVoice use prompts model download

- **Given** the user starts voice input with `SenseVoice` selected and no local SenseVoice model installed
- **When** the composer starts speech input
- **Then** the app opens a blocking `SenseVoice Setup` dialog instead of failing silently
- **Then** after the download finishes successfully, the app retries the speech-input start flow automatically

### SenseVoice stays desktop-only

- **Given** the app runs on Android, iOS, or Web
- **When** speech-engine availability is evaluated from persisted settings
- **Then** `SenseVoice` is treated as unavailable and the app falls back to a supported engine instead of exposing a broken selection

---

## Text-to-Speech (TTS)

### Read-aloud button in assistant messages

- **Given** the user is viewing an assistant message
- **When** the read-aloud setting is enabled (Settings > Speech)
- **Then** a read-aloud button (volume_up icon) appears in the assistant message header
- **Then** tapping the button reads the sanitized assistant message text aloud using the selected TTS provider
- **Then** while the selected provider is preparing or loading audio for that message, the read-aloud control shows an inline loading indicator instead of the play/stop icon
- **Then** long-pressing the read-aloud control opens Settings > Speech
- **Then** provider failures are shown to the user instead of silently falling back to a different provider

### Toggle playback off

- **Given** read-aloud is actively playing
- **When** the user taps the read-aloud button on the playing message
- **Then** playback stops

### Auto-stop behavior

- **Given** read-aloud is actively playing
- **When** the user sends a new message or switches sessions
- **Then** playback stops automatically
- **When** the user switches app/window focus or the app enters a non-resumed lifecycle state
- **Then** CodeWalk does not explicitly stop read-aloud playback

### TTS settings

- **Given** the user opens Settings > Speech
- **When** the Text to speech section is visible
- **Then** the user can select `System / Native`, `Microsoft Edge Speech (experimental)`, or `OpenAI-compatible`
- **Then** the user can enable/disable read-aloud and test the selected voice
- **Then** the user can adjust speaking speed (0.0–1.0)
- **Then** voice pitch (0.5–2.0) is shown only for the native provider

### First-run TTS defaults

- **Given** no persisted `ExperienceSettings` JSON exists
- **When** settings initialize on Linux
- **Then** read-aloud defaults to `Microsoft Edge Speech (experimental)` because native `flutter_tts` is unavailable on Linux
- **When** settings initialize on a platform where native TTS is available
- **Then** read-aloud defaults to `System / Native`
- **When** settings initialize on a non-Linux platform where native TTS is unavailable
- **Then** read-aloud falls back to `Microsoft Edge Speech (experimental)`
- **Then** app locale, followed by system locale, selects the closest default Edge voice/locale
- **Given** persisted `ExperienceSettings` JSON already exists
- **When** settings initialize
- **Then** startup defaults do not overwrite the user's stored read-aloud provider, voice, or locale

### Native TTS provider

- **Given** `System / Native` is selected
- **When** the platform exposes TTS voices
- **Then** Settings > Speech shows a native voice picker
- **Then** selected voice locale metadata is preserved when speaking instead of forcing a hard-coded locale

### OpenAI-compatible TTS provider

- **Given** `OpenAI-compatible` is selected
- **When** the user configures read-aloud settings
- **Then** Settings > Speech exposes base URL, model, voice, and API key controls
- **Then** the API key is saved only in secure storage on the device
- **Then** the API key is not persisted in `ExperienceSettings` JSON
- **When** a message is read aloud with this provider
- **Then** CodeWalk calls the configured `/v1/audio/speech` endpoint with the sanitized message text and plays the returned audio bytes
- **Then** missing, invalid, rate-limited, network, or provider errors are mapped to user-visible read-aloud errors

### Microsoft Edge Speech experimental provider

- **Given** `Microsoft Edge Speech (experimental)` is selected
- **When** Settings > Speech renders provider-specific options
- **Then** CodeWalk shows a warning that Edge Speech is experimental, uses an unofficial Edge Read Aloud protocol, and sends message text to Microsoft
- **Then** Settings > Speech shows an Edge voice picker when Microsoft voice discovery is available
- **Then** CodeWalk can synthesize normal-length sanitized assistant text through the direct Edge/Bing Read Aloud websocket path and play the returned MP3 audio
- **Then** text over the Edge request size limit is rejected with a read-aloud error instead of being sent partially
- **When** direct Edge synthesis fails because Microsoft changes or rejects the private protocol
- **Then** CodeWalk reports a user-visible read-aloud error and does not silently switch to native TTS

### Cloud TTS privacy

- **Given** a cloud TTS provider is selected
- **When** the user reads an assistant message aloud
- **Then** the selected assistant message text is sent to the configured third-party provider
- **Then** API keys are never sent to OpenCode servers, stored in normal settings JSON, or shown in logs

### Read-aloud disabled

- **Given** read-aloud is disabled in settings
- **When** viewing assistant messages
- **Then** read-aloud buttons are not shown

### Markdown stripping

- **Given** a message contains Markdown formatting
- **When** the message is read aloud
- **Then** fenced code blocks, Markdown tables, links, images, headings, blockquote/list markers, and formatting markers are stripped or reduced so only natural text is spoken

---

## Debug Logging

### App logging is opt-in and default off

- **Given** CodeWalk is installed for the first time
- **When** the user opens `App Logs`
- **Then** app logging is disabled by default
- **Then** CodeWalk does not collect runtime app log entries until the user enables `Enable app logging`
- **Then** the logs screen clearly states that logging is disabled and offers an `Enable logging` action
- **When** the user enables `Enable app logging`
- **Then** CodeWalk starts collecting in-memory diagnostic app logs for the current runtime session
- **When** the user disables `Enable app logging`
- **Then** CodeWalk clears the current in-memory app log buffer and stops collecting new normal or performance log entries
- **Then** search, export, slowest-performance, and performance-filter controls stop exposing disabled logging data until logging is re-enabled
- **Given** an existing installation already has an explicit `loggingEnabled` preference
- **When** CodeWalk starts after upgrade
- **Then** that explicit preference is preserved
- **Given** an existing installation enabled the older `Measure performance` diagnostic preference before the global logging toggle existed
- **When** CodeWalk migrates settings with no explicit `loggingEnabled` key
- **Then** CodeWalk treats that performance logging opt-in as a diagnostic opt-in and enables app logging so the existing preference keeps working

### Performance logging is opt-in and persisted

- **Given** CodeWalk is installed for the first time
- **When** the user opens `App Logs`
- **Then** performance measurement is disabled by default
- **Then** the `Measure performance` switch is unavailable while app logging is globally disabled
- **When** the user enables `Measure performance` on the logs screen
- **Then** CodeWalk persists that choice and starts recording timing entries for selected expensive operations
- **Then** timing entries are only collected while both `Enable app logging` and `Measure performance` are enabled
- **Then** disabling the same option stops new performance timing entries while preserving existing captured logs until the log buffer is cleared or rotated
- **Then** captured timing entries include chat/session load, message load, large cache reads/writes, legacy cache migration, session snapshot restore/write, HTTP requests, project/directory switch, chat selection changes, selection persistence, ChatProvider listener dispatch, and chat settlement/viewport scans

### Performance logs are filterable

- **Given** performance measurement has captured entries
- **When** the user enables the `Performance` filter on the logs screen
- **Then** the list shows only performance-tagged log entries that also match the active time, level, and search filters
- **Then** each performance entry shows the operation name, elapsed time, status, tags, and safe context fields

### Slowest performance logs summarize bottlenecks

- **Given** performance measurement has captured entries with durations
- **When** the user opens `Slowest performance logs`
- **Then** CodeWalk shows matching performance entries ordered from slowest to fastest using the active log filters

### Debug log entries carry tags and metrics

- **Given** app logging is enabled
- **When** the code calls `AppLogger.debug/info/warn/error(...)` with optional `tags:` and `metrics:` arguments
- **Then** every captured `LogEntry` stores `tags` as an immutable `Set<String>` and `metrics` as an immutable `Map<String, Object?>` alongside the existing level, message, error, and stack trace
- **Then** sensitive metric keys (`authorization`, `token`, `password`, `secret`, `cookie`, `apikey`, `api_key`) are redacted to `***` and arbitrary text metric values flow through the same Basic/Bearer sanitizer used for messages
- **Then** the rendered log tile surfaces the sorted tag list and the optional `context` sub-map from `metrics` so producers can group entries without changing the message format
- **Then** the underlying `developer.log` message is prefixed with `[tag1 tag2] ` so `flutter logs` / `adb logcat` can also filter by tag

### Task timing emits start and end events with shared taskId

- **Given** app logging is enabled
- **When** the code calls `AppLogger.beginTask(name, {tags, context})` and then `task.end()` (directly or via `runTask` / `runPerformanceTask` / `measurePerformance` / `recordPerformanceTask`)
- **Then** a `phase:start` debug entry is recorded at `beginTask` time carrying the auto-generated `taskId`, the normalized `task:<name>` tag, the producer-supplied tags, and an immutable `context` map merged into `metrics`
- **Then** a matching `phase:end` entry is recorded at `end` time carrying the same `taskId`, a `status:<status>` tag, the `elapsedMs` metric, the merged context, and a level that escalates with status (`debug` for `ok`, `warn` for `canceled`, `error` for `error`)
- **Then** the same `taskId` appears on both start and end entries so the logs page and exports can correlate them even when other entries interleave
- **Then** `runPerformanceTask` and `measurePerformance` capture a single end entry under the `performance` tag with `elapsedMs`, `operation`, and `status` metrics, and only emit when `Measure performance` is enabled
- **Then** tasks started inside another task's zone inherit a `parent:<taskId>` tag in their entry tags so nested instrumentation can be traced

### Logs page can filter by tag, including custom tags

- **Given** app logging is enabled and tags are present in captured entries
- **When** the user opens `App Logs`
- **Then** the toolbar exposes a third filter row labelled with the localized tag-filter text containing `FilterChip`s for the built-in tags `task:select_session`, `task:load_messages`, `task:load_sessions`, `task:hydrate_cache`, `task:realtime_event`, `network:http`, `network:sse`, `cache:read`, `cache:write`
- **Then** a custom-tag action chip opens a dialog whose submitted text is added to the active tag set so the user can filter by any tag a producer emitted (`task:custom_name`, `chat:settlement`, `notification:tap`, etc.)
- **Then** entries are kept when any of their tags intersect the active set, the level and time filters still apply, and the search box also matches against the rendered tag list and the serialized metrics payload

### Logs page shows slowest tasks for selected task tags

- **Given** the user has selected at least one tag starting with `task:` in the logs toolbar
- **When** the user opens the timer action in the app bar
- **Then** a bottom sheet lists every captured `phase:end` entry (non-performance) whose tags intersect the selected task tags and that has an `elapsedMs` metric, ordered from slowest to fastest
- **Then** each row shows the normalized task name, the localized duration label, and the localized task status (`ok` / `canceled` / `error`)
- **Then** when no `task:` tag is selected but performance entries exist, the same timer action opens the slowest-performance sheet; the action stays disabled while logging is disabled or when the buffer holds no qualifying entries for the active filters

### Exported logs include tags and metrics

- **Given** the user has applied (or left default) filters on `App Logs`
- **When** the user triggers the export action in the toolbar
- **Then** each exported line includes the entry's sorted tags and a JSON-encoded `Metrics` block alongside the timestamp, level, message, error, and stack trace
- **When** an exported entry is restored through `LogEntry.fromJson`
- **Then** the original `tags` set and `metrics` map are restored so round-tripping between exports and offline analysis preserves the task timing payload (`taskId`, `status`, `elapsedMs`, `operation`, `parentTaskId`, `context`)

---

## Message Reconciliation

The visible message collection is monotonic during normal updates. Asynchronous
server snapshots, HTTP fallbacks, active-session refreshes and cache hydration
that replace the visible list go through a shared rule instead of guarding
themselves. Explicit resets and targeted realtime/local mutations remain
authoritative dedicated paths.

An update carries its provenance (origin) and what it claims to be (kind). The
rule is: an update may never remove a message that is newer than everything the
update itself carries. When it would, the newer tail is preserved and merged
back in timeline order, and a warning is logged naming the origin, the kind and
the preserved identifiers.

Two kinds bypass the rule because dropping messages is their purpose: an
authoritative removal from the server, and a reset such as a session switch or
cache eviction. Everything else — full snapshots and partial deltas alike — is
judged.

Updates that produce no effective change do not write to the collection at all,
because rebuilding with identical content still moves the reading anchor on
some layouts.

Reconciliation decisions are logged permanently at debug level, and at warning
level when a regression is actually blocked. Only identifiers and counts are
recorded, never message content.

## Subagent Event Scope

Subagents finish silently from the point of view of the session being read.

A child session reaching idle, or failing, never marks unread on its parent,
never raises an attention surface there, and never moves the parent's scroll.
Only the session actually on screen may own the reading anchor: passive
auto-scroll is refused for any session id that is not the current one.

The subagent's own screen keeps receiving and rendering its events normally.
A message genuinely added to the main timeline still triggers unread as before.

## Subagent Navigation

Opening a subagent from a task part prefers the child session id carried by the
part metadata or the official completed-output `<task id="...">` envelope.
When the part does not carry one and there is exactly one child candidate, that
candidate is used.

The same resolver and visible task/subtask affordances apply inside every
subagent level. Each navigation step resolves only children of the session
currently on screen, and desktop/mobile back returns only to that session's
immediate `parentId`; repeated references outside the direct child set are
rejected with non-blocking feedback instead of creating a loop.

Otherwise the Nth task part is paired with the Nth child session by start time,
but only when the number of task parts equals the number of candidates. With
concurrent subagents those two sequences diverge, and pairing them anyway is
what opened the wrong sibling.

When the association is ambiguous, nothing is opened and the user is told no
sub-conversation was found. Opening some other subagent is worse than opening
none.

## Android Attention Overlay

The external overlay exists to follow work while the user is away from
CodeWalk. Actual app visibility drives hiding: resumed and transient
inactive-but-still-visible states keep the overlay detached, while
background/hidden states allow it when there are still eligible items. Realtime
transport holds do not drive overlay visibility. A visibility change republishes
the attention snapshot immediately rather than waiting for the next unrelated
update.

The overlay also stays hidden when there are no items and while the device is
locked.

Its Flutter engine is hosted by a Service, which never receives an Activity
lifecycle. The engine is therefore told explicitly that the app is resumed when
the view attaches and paused when it detaches; without that the framework
ignores pointer events and every control appears dead.

Dragging and tapping are distinct: the native touch listener only consumes
events once movement passes the touch slop, so a plain tap always reaches the
Flutter widgets underneath.

The Bubble's size is a five-level user preference, persisted with the rest of
the experience settings and defaulting to a factor of 0.7 of its base size. The
scale applies to the Bubble only — the Panel keeps fixed dimensions so its
summary stays legible — and a floor is enforced so the smallest setting still
leaves a usable touch target.

## Composer External Files

Images and PDFs reach the composer three ways — the file picker, dragging them
onto it, and pasting — and all three end at the same attachment pipeline. The
accepted formats, the model's allowed modalities, deduplication, draft
persistence and the "some items were ignored" message therefore behave
identically no matter how the file arrived.

Dragging is offered on desktop and web, where the host can hand over external
files; mobile keeps the picker. The drop zone highlights only when the composer
can actually accept a file, so it never looks receptive while disabled, in
shell mode, or when the selected model supports neither images nor PDFs.

Pasting reads the clipboard for file references first and for raw image bytes
second, so a screenshot with no filename still becomes an attachment. Its name
is localised and its extension comes from the image's own signature rather than
a guess. The paste keystroke is not consumed: text pasting proceeds untouched,
and any attachable file found is added alongside it.

Files whose extension is not one the composer accepts are counted as skipped
rather than inspected, so arbitrary content is never classified as an image.

## Block Render Mode

Block mode exists to avoid showing half-written content, not to withhold a
whole turn. While a session is responding it hides only the block still being
written; every block that has reached a terminal state of its own is published
immediately and keeps its chronological position.

An assistant message counts as terminal once it is completed or has errored.
Because the server reports tool parts individually, a finished tool appears
without waiting for the final text — including one that ended in error.

The compact placeholder stays after the blocks already published, for as long
as generation continues, and disappears when the last block lands. Live mode is
unaffected and keeps rendering text, reasoning and tools as they stream.

## Empty Project Draft

Opening a project that has no sessions puts CodeWalk straight into a local New
Chat draft, so the composer is usable immediately instead of waiting behind a
"New chat" button. Nothing is created remotely by opening a project: the
session is still created lazily on the first send.

The draft is entered only after an authoritative load reports the context
empty, never during loading, a transient error, or an unresolved context
switch. It never replaces an existing session or a draft already in place.

A missing server outranks it: with no server configured the setup call to
action is shown instead, because there is nothing to draft into.

## Anti-behaviors

> Things that must **never** happen, regardless of circumstances.

### Never lose user messages

The app must never silently discard a user's message. If sending fails, the message text returns to the composer input.

### Never freeze the UI

All operations (streaming, sync, network) are asynchronous. The UI must never become unresponsive, even during heavy operations.

### Never expose tokens or credentials

Server tokens, API keys, and credentials must never appear in logs, error screens, exports, or any user-visible surface.

### Never auto-approve permissions outside the approved exception

Permission requests from the server must require explicit user action unless the user has the ADR-023-approved composer auto-approve toggle enabled. Outside that exception, the app must never approve automatically.

### Never leak pending prompts across sessions

Permission and question cards must remain owned by their originating session. The app may mirror descendant thread prompts into the active main/root session for visibility, but it must never surface pending interactions in unrelated sessions.

### Never show false aborts

When a connection drops and reconnects (especially on mobile background/resume), the app must not display false "message aborted" errors from stale SSE events.

### Never accept mutating actions during confirmed reconnect failure

If realtime transport failures have already pushed the app into a confirmed reconnect cycle, mutating actions such as sending a message, replying to a permission/question, or compacting context must fail fast with explicit user feedback instead of pretending the action was accepted.

### Never corrupt state on rapid actions

If the user taps rapidly (double-tap on sessions, fast project switching), the app processes one transition at a time. Concurrent transitions must never corrupt state or cause navigation errors.

### Never block project context switches on remote refresh

Switching project/directory context must complete from local scope snapshots when available. Server revalidation may run after the transition, but it must not keep the UI stuck in a transition/loading state.

### Never cancel responses on session switch

If the assistant is streaming a response and the user switches to a different session, cancelling the local message subscription does not abort the server-side `prompt_async` response. The in-flight response is preserved, and the user can return to the original session and see the completed response.

### Never collapse work groups during streaming

Tool call work groups must only collapse after the assistant has fully completed its response **and** the final response is visible. Premature collapse causes visual flicker, aggressive auto-scroll, and hidden active work.

### Never flicker settled work groups on sync jitter

After a tool/work group settles for a completed turn, transient realtime sync/status jitter must not cause rapid open/close loops or repeated remount flashes.

The grouped surface for that settled turn must keep the same rendered identity across same-turn passive refreshes, and passive status pulses must not temporarily treat that settled turn as active again unless a newer revealable assistant message exists.

### Never misread viewport shrink as top-history intent

Top-history loading must only trigger from real upward user scrolling. Content shrink from collapse, re-layout, or other viewport-clamp side effects must never be interpreted as intent to load older messages, because that causes jumps into old history and then snap-back recovery.

### Never let passive busy-turn updates fight the viewport owner

During an active busy/retry turn, only one viewport owner may control the outer chat scroll position. Passive refresh merges, realtime part deltas, status pulses, and collapse/re-layout side effects must never stack a second autonomous scroll correction on top of the active-turn follow/reveal policy, because that causes the classic up/down bounce regression.

Passive updates for the same already revealed final assistant response must also stay in read `reading` mode instead of promoting the viewport to `pausedByUser`/unread or re-entering active-response collapse deferral.

### Never show stale data after resume

When the app returns from background, it must refresh the current session to show the latest state. However, refresh must not re-inject stale abort data that was already handled.

### Never break layout with keyboard

On mobile, the on-screen keyboard must never cause overflow, clipping, or layout breakage. Fixed minimum heights must account for the keyboard-reduced viewport.

### Errors: only show blocking ones

The user should see error feedback only when the error prevents them from continuing (send failed, server unreachable). Non-blocking warnings from the server (partial timeouts, transient issues) should be silent.
