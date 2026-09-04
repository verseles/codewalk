# Changelog

Release notes for tagged CodeWalk versions. GitHub Issues remain the canonical tracker for planned work and acceptance criteria.

## v1.223.1 - 2026-09-04

- docs(tabs): dialog close shares the tab-strip row (issue 167)
- refactor(tabs): hoist shared dialog close builder (issue 167)
- fix(tabs): dialog close shares the tab-strip row, slim side margins (issue 167)

## v1.223.0 - 2026-09-04

- docs(tabs): unify file editor tabs behavior and code map (issue 167)
- test(tabs): isolate file-tab close semantics assertion (issue 167)
- fix(tabs): keep close-button tap semantics and shrinkWrap hit area (issue 167)
- fix(tabs): harden dialog exits and tab a11y after review (issue 167)
- feat(tabs): unify file editor tabs with session tab strip (issue 167)

## v1.222.0 - 2026-09-04

- fix(terminal): route embedded terminal through Tailscale transport
- docs

## v1.221.1 - 2026-09-03

- fix(projects): never persist placeholder root as last project

## v1.221.0 - 2026-09-03

- feat(tailscale): setup reorder, Custom Tab login, logout, busy UX and cold-start hint
- fix(tailscale): reliable embedded login, single device identity and working probes

## v1.220.4 - 2026-09-03

- chore(android): accept Flutter migrator gradle flags
- fix(settings): restore live updates in all settings sections on Android release

## v1.220.3 - 2026-09-03

- fix(ci): build prototype macOS with CocoaPods too
- fix(ci): build macOS with CocoaPods instead of SPM
- fix(tests): install workmanager fake after singleton auto-select

## v1.220.2 - 2026-09-03

- ci: run coverage at -j 4
- fix(tests): keep settings tests hermetic under parallel load
- fix(macos): downgrade connectivity_plus to ^6.1.5

## v1.220.1 - 2026-09-03

- chore: ignore Eclipse/Buildship metadata
- feat: enable Impeller on Android and upgrade major dependencies
- fix(ci): remove unnecessary foundation import to fit analyze budget

## v1.220.0 - 2026-09-02

- fix(android): restore live UI updates in release builds

## v1.219.3 - 2026-09-01

- fix(android): disable Impeller to fix retained OpacityLayer ghosting (fixes #153, #175)

## v1.219.2 - 2026-09-01

- fix(android): ensure theme and update progress rebuild on Android (fixes #153, #175)

## v1.219.1 - 2026-08-31

- fix(app): correct Zone for WidgetsBinding and remove palliative Settings route provider (fixes #153, #175)
- chore(ci): raise analyze budget 335->337 to match current 337 infos

## v1.219.0 - 2026-08-31

- test(settings): add Selector-aware one-pump regression and align CI budget
- fix(settings): restore immediate reactivity for toggles and dropdowns (fixes #153, #175)

## v1.218.0 - 2026-08-31

- docs: update BEHAVIOR and CODEBASE for unified menus and Close project (#162, #163)
- fix: root scope close, no-snapshot rename, archive rollback and event race
- fix: address reviewer findings for unified menus and Close project
- feat: unify session context menus and add Close project (#162, #163)

## v1.217.0 - 2026-08-31

- fix(chat): preserve parent viewport when returning from subagent (fixes #172)

## v1.216.0 - 2026-08-27

- fix(settings): ensure final dispose drain and flush awaits in-flight encode (review #161)
- fix(review): address reviewer findings for #161 (dispose, cross-scope flush, isolate)
- perf(desktop): coalesce persistence and offload encode to fix jank (fixes #161)

## v1.215.1 - 2026-08-24

- fix(speech): cancel in-flight Linux mic probing when stop() arrives
- fix(speech): add multi-backend Linux microphone capture for STT

## v1.215.0 - 2026-08-22

- docs(chat): document bounded history window behavior and ADR-020 refinement (#160)
- feat(chat): bounded history window with sentinel chunked pagination (#160)

## v1.214.0 - 2026-08-22

- fix(chat): treat server+session as composer draft identity
- fix(chat): pin composer draft identity across switches and clears
- docs(adr): record Android FGS anti-regression boundary and persistence rules
- feat(chat): persist composer drafts per session across restarts

## v1.213.0 - 2026-08-21

- chore(chat): clear session-tab persistence generations on dispose
- fix(chat): retry failed flushed tab writes via generation passthrough
- fix(chat): address review findings on tab persistence and image decode
- fix(android): keep process alive in background and harden tab persistence

## v1.212.0 - 2026-08-19

- fix(chat): align slash command payload with OpenCode

## v1.211.1 - 2026-08-19

- fix(ci): use reliable Ubuntu mirror for Linux release build

## v1.211.0 - 2026-08-19

- test: scroll to Logs in settings before tapping (new tts section pushed it off-screen)
- docs: document Text to speech section, playback controls, and audio cache
- fix(tts): harden async guards found in review
- feat(tts): cache generated read-aloud audio in memory
- feat(tts): add pause/resume/stop read-aloud controls
- feat(tts): separate Text-to-Speech settings section with auto voice test
- feat(tts): localize TTS strings and flag missing saved models

## v1.210.0 - 2026-08-19

- feat(tts): add an ElevenLabs model picker with a dynamic `/v1/models` list and provider-reported character preflight
- feat(tts): add a curated NVIDIA NIM TTS model list
- fix(tts): map ElevenLabs speed to the API-valid 0.7-1.2 range

## v1.209.1 - 2026-08-18

- fix(tts): map ElevenLabs speed to the API-valid 0.7-1.2 range
- docs(codebase): map ElevenLabs and NVIDIA NIM TTS backends

## v1.209.0 - 2026-08-18

- docs(behavior): document ElevenLabs and NVIDIA NIM read-aloud providers
- test(tts): harden voice-picker race handling and lock key-save guard
- fix(tts): snapshot discovery key before the key-save write
- fix(tts): keep voice picker attached to in-flight discovery
- fix(tts): trigger remote voice discovery only on explicit submit
- fix(tts): address reviewer findings for cloud read-aloud providers
- feat(tts): add ElevenLabs and NVIDIA NIM read-aloud providers

## v1.208.0 - 2026-08-18

- fix(notifications): keep cached session title for background group summary
- fix(notifications): include session title in all OS notifications

## v1.207.0 - 2026-08-17

- fix(app): avoid rebuilding MaterialApp for unrelated settings

## v1.206.0 - 2026-08-17

- docs(behavior): document live settings updates and About update check
- fix(settings): keep settings UI live when a settings listener fails

## v1.205.0 - 2026-08-17

- fix(android): resume chat reliably and record bounded process diagnostics

## v1.204.0 - 2026-08-17

- feat(chat): add session tab draft flow

## v1.203.0 - 2026-08-17

- fix(chat): coalesce desktop persistence writes
- fix(chat): reduce desktop persistence jank

## v1.202.0 - 2026-08-16

- fix(tabs): stop inactive tabs from reserving the context-usage knob space
- feat(tabs): size session tab widths to titles between minimum and maximum

## v1.201.0 - 2026-08-16

- docs(behavior): document pending-question rehydration and view-question action
- fix(chat): drop invalidated pending-interaction loads from coalescing
- fix(chat): key pending-interaction coalescing by effective scope
- fix(chat): invalidate and coalesce pending-interaction loads per reviewer
- fix(chat): harden pending-question rehydration after review
- fix(chat): rehydrate pending question cards on session re-entry

## v1.200.2 - 2026-08-15

- fix(tts): mark aggregate completed-turn silence as non-retryable
- fix(tts): apply review corrections to Edge voice fallback
- fix(tts): recover from discontinued Edge voices and warn in settings

## v1.200.1 - 2026-08-15

- feat(settings): add search to read-aloud voice pickers

## v1.200.0 - 2026-08-15

- test(tts): pin splitter invariants and skip unspeakable chunks
- fix(tts): refine Edge TTS chunking and cancellation after re-review
- fix(tts): apply review corrections to Edge TTS error handling
- fix(tts): diagnose and recover from premature Edge TTS failures

## v1.199.3 - 2026-08-14

- fix(chat): compact inactive pinned tabs and fit the expanded selected one

## v1.199.2 - 2026-08-14

- fix(chat): restore cache-first session tab performance

## v1.199.1 - 2026-08-13

- fix(android): enable auto messaging in release

## v1.199.0 - 2026-08-13

- feat(android): add experimental auto messaging

## v1.198.0 - 2026-08-13

- feat(speech): add configurable API transcription
- fix(quota): validate OpenCode Go usage correctly
- feat(i18n): complete interface localization
- docs: sync ai-docs with latest OpenCode content
- feat(chat): customize session tab icons
- feat(chat): sync pinned session tabs
- perf(chat): replace title polling with SSE waiter
- feat(settings): clarify navigation and grouping
- fix(linux): preserve data across updates
- fix(terminal): recover Android IME-cancelled controls
- remove file
- fix(chat): support nested subagent navigation
- fix: complete queued client corrections

## v1.197.0 - 2026-08-09

- Merge pull request #126 from charleypeng/main
- fix(oauth): harden profile lifecycle and Android flow
- docs(CODEBASE): resolve merge descriptions for MainActivity
- Merge remote-tracking branch 'origin/main'
- Merge remote-tracking branch 'verseles/main'
- fix(oauth): secure Android loopback authorization
- plan: correct PR #126 Android OAuth flow
- fix(oauth): intercept the loopback redirect in the Android auth WebView
- fix(oauth): retry token exchange on transient network errors
- fix(oauth): run the Android consent flow in an in-app WebView
- feat(oauth): make PKCE flow failures self-diagnosing + add loopback probe tool
- fix(oauth): never leave the connection-test spinner hanging on OAuth failures
- fix(oauth): run in-app loopback redirect server on Android, drop flutter_appauth
- fix(oauth): use private-use URI scheme redirect on Android instead of loopback HTTP

## v1.196.2 - 2026-08-05

- fix(desktop): route integrated context usage popover

## v1.196.1 - 2026-08-04

- fix(desktop): restore integrated titlebar controls

## v1.196.0 - 2026-08-04

- fix(scope): smooth cached project transitions

## v1.195.1 - 2026-08-03

- fix(tabs): expire close snackbar

## v1.195.0 - 2026-08-02

- docs(tabs): describe refined tab behavior
- fix(tabs): restore unloaded session tabs
- fix(tabs): keep selected tab visible
- feat(tabs): refine navigation and recovery

## v1.194.0 - 2026-08-02

- docs(tabs): document gesture controls
- fix(tabs): preserve deferred and keyboard controls
- fix(tabs): expose session actions to keyboard
- feat(tabs): move session controls into tabs
- fix(tabs): limit newly opened project sessions
- fix(tabs): overlay session activity on project icons
- fix(tabs): straighten tab sides

## v1.193.0 - 2026-08-02

- fix(chat): harden block mode transitions
- fix(composer): harden external file attachments
- fix(android): harden session attention overlay
- fix(files): make autosave context-safe
- fix(files): harden duplicate and cached reloads
- fix(chat): harden subagent navigation and reconciliation
- fix(tabs): enlarge touch close targets
- fix(tabs): keep close actions accessible
- fix(desktop): preserve integrated chrome across routes
- docs(readme): add the capabilities shipped over the last two months
- docs(readme): merge the two feature lists into one written for users
- feat(chat): draft automatically when a project has no sessions

## v1.192.0 - 2026-08-01

- fix(chat): publish finished blocks while a Block-mode turn continues

## v1.191.0 - 2026-08-01

- feat(composer): attach images and PDFs by dragging or pasting
- feat(composer): show a collapse arrow while the extras popover is open
- chore(terminal): trace header control activations
- feat(terminal): acknowledge opening and fit the extra keys on narrow phones
- fix(files): honour dedicated clipboard keys in the file editor

## v1.190.0 - 2026-08-01

- fix(android): revive overlay taps, hide it in foreground, make it sizeable

## v1.189.0 - 2026-08-01

- feat(files): add undo, redo and autosave to the file editor
- fix(files): offer cut and paste in the file editor selection menu
- fix(files): give the file editor a selection toolbar

## v1.188.0 - 2026-08-01

- fix(files): revalidate file content when a tab is reopened
- feat(files): highlight every language the package ships with
- feat(files): duplicate a file from the micro file manager

## v1.187.0 - 2026-08-01

- fix(chat): stop stale payloads and subagent traffic from disturbing the timeline

## v1.186.0 - 2026-08-01

- fix(ui): refine tab silhouette, background and close affordance

## v1.185.0 - 2026-08-01

- fix(desktop): drop native registrations for the removed multi-window plugin

## v1.184.0 - 2026-08-01

- feat(desktop): remove the Bubble and Panel attention surfaces

## v1.183.0 - 2026-08-01

- feat(desktop): show the attention bubble without stealing focus
- feat(ui): give session tabs a real browser silhouette
- fix(desktop): keep window buttons flush against the trailing edge

## v1.182.0 - 2026-07-31

- fix(desktop): make the attention bubble frameless and stop focus theft

## v1.181.0 - 2026-07-31

- chore: ignore the local agent task checkpoint
- feat(desktop): move session tabs into the window title bar
- fix(ui): drop duplicated card wrappers from auxiliary sidebars

## v1.180.0 - 2026-07-30

- feat: add recent session tabs
- plan: implement recent session tabs
- delete roadmap done

## v1.179.0 - 2026-07-28

- chore(agent): [Step 3/3] Document mobile terminal extra keys
- chore(agent): [Step 2/3] Integrate mobile terminal extra keys
- chore(agent): [Step 1/3] Add mobile terminal input protocol
- plan: add mobile terminal extra keys

## v1.178.0 - 2026-07-18

- chore(agent): [Step 2/2] Document OpenCode compatibility
- chore(agent): [Step 1/2] Align OpenCode compatibility
- plan: align OpenCode v1.18.3 compatibility

## v1.177.0 - 2026-07-15

- docs: clarify OpenCode source investigation
- chore(agent): [Step 2/2] Prove and document watchdog behavior
- fix(android): publish overlay foreground readiness
- fix(android): stabilize overlay runtime matrix
- chore(agent): [Step 1/2] Bound first-frame watchdog
- plan: stabilize API 34 overlay first frame
- fix(android): launch overlay from its Dart library
- docs: constrain tester command execution
- fix(ci): preserve overlay runner shell state
- fix(ci): stabilize Android overlay instrumentation
- fix(android): guard overlay capture without BuildConfig
- chore(agent): [Step 3/3] Automate validation and document behavior
- chore(agent): [Step 2/3] Add overlay visual regression coverage
- chore(agent): [Step 1/3] Fix overlay composition and geometry
- plan: fix Android session overlay transparency

## v1.176.0 - 2026-07-13

- fix(ci): restore ADB startup for runtime matrix
- chore(agent): [Step 7/8] complete session attention integration
- chore(agent): [Step 6/8] implement desktop and iOS attention hosts
- chore(agent): [Step 5/8] implement Android overlay host and activation
- chore(agent): [Step 4/8] add reusable TTS and shared attention UI
- chore(agent): [Step 3/8] add encrypted snapshots and completion resolution
- chore(agent): [Step 2/8] add settings and attention domain state
- chore(agent): [Step 1/8] validate session attention prototypes
- fix(ci): apply compile-only Android prototype gate
- fix(ci): start ADB before Android emulator
- fix(ci): configure Android runtime jobs without APK build
- fix(ci): run Android overlay tests on Intel macOS
- fix(ci): defer Android emulator capability check
- fix(ci): accelerate Android overlay runtime tests
- fix(ci): prepare Gradle wrapper before emulator tests
- test(android): gate overlay service on API 34-36
- fix(ci): install Go in desktop prototype jobs
- fix(ci): validate prototypes on project Flutter
- fix(ci): provision prototype native toolchains
- chore(prototype): add session overlay platform gates
- plan: add cross-platform session attention overlay
- chore: remove obsolete planning files

## v1.175.0 - 2026-07-11

- chore(agent): [Step 4/5] document adaptive onboarding
- chore(agent): [Step 3/5] validate and review onboarding
- chore(agent): [Step 2/5] harden managed onboarding completion
- chore(agent): [Step 1/5] simplify first-run welcome
- plan: simplify first-run welcome

## v1.174.1 - 2026-07-11

- chore(agent): [Step 4/5] document negotiated shell file transport
- chore(agent): [Step 3/5] validate and bound shell file saves
- chore(agent): [Step 2/5] run file mutations in one shell pipeline
- chore(agent): [Step 1/5] parse official shell tool responses
- plan: harden workspace shell transport responses

## v1.174.0 - 2026-07-10

- chore(agent): [Step 4/5] document race-safe file operations
- chore(agent): [Step 3/5] validate and harden file operations
- chore(agent): [Step 2/5] add file save and delete regressions
- chore(agent): [Step 1/5] scope file mutations and reconcile deletes
- plan: fix workspace file save and delete

## v1.173.0 - 2026-07-09

- chore(agent): [Step 4/5] validate read-aloud playback UX changes
- chore(agent): [Step 3/5] document read-aloud playback UX changes
- chore(agent): [Step 2/5] add read-aloud button loading and settings shortcut
- chore(agent): [Step 1/5] preserve TTS playback across lifecycle changes
- plan: keep TTS playback across window switches

## v1.172.2 - 2026-07-08

- chore(agent): [Step 4/5] validate adaptive TTS defaults
- chore(agent): [Step 3/5] document adaptive TTS defaults
- chore(agent): [Step 2/5] wire adaptive TTS first-run defaults
- chore(agent): [Step 1/5] add adaptive TTS default resolver
- plan: adaptive TTS provider defaults

## v1.172.1 - 2026-07-08

- chore(agent): [Step 5/6] validate Edge TTS reviews
- chore(agent): [Step 4/6] document direct Edge TTS
- chore(agent): [Step 3/6] wire Edge TTS voices
- chore(agent): [Step 2/6] implement direct Edge websocket TTS
- chore(agent): [Step 1/6] add Edge TTS protocol primitives
- plan: implement direct Edge TTS

## v1.172.0 - 2026-07-08

- chore(agent): [Step 6/6] resolve cloud TTS reviews
- chore(agent): [Step 5/6] document cloud TTS
- chore(agent): [Step 4/6] wire read aloud UI
- chore(agent): [Step 3/6] add cloud TTS provider backends
- chore(agent): [Step 2/6] introduce TTS backends and audio playback
- chore(agent): [Step 1/6] add TTS provider settings and key storage
- plan: implement cloud TTS providers

## v1.171.1 - 2026-07-07

- fix(settings): default new installs to refined visual style

## v1.171.0 - 2026-07-07

- fix(docs): add refined visual layer ADR
- chore(agent): [Step 5/6] validate and document refined visual layer
- chore(agent): [Step 4/6] apply refined chat surfaces
- chore(agent): [Step 3/6] add visual style settings UI
- chore(agent): [Step 2/6] add visual style theme tokens
- chore(agent): [Step 1/6] add visual style persistence
- plan: implement CodeWalk refined visual layer

## v1.170.1 - 2026-07-07

- fix(chat): add quick-reply model routing

## v1.170.0 - 2026-07-07

- chore(agent): [Step 5/6] apply reviewer validation fixes
- chore(agent): [Step 4/6] document and localize quick-reply routing UI
- chore(agent): [Step 3/6] redesign quick-reply editor and override apply
- chore(agent): [Step 2/6] wire quick-reply selection plumbing
- chore(agent): [Step 1/6] extend canned answer routing metadata
- plan: implement quick-reply agent and thinking selection

## v1.169.0 - 2026-07-06

- chore(agent): [Step 7/8] document chat stability behavior
- chore(agent): [Step 6/8] apply reviewer chat stability fixes
- chore(agent): [Step 4/8] harden cross-stream event dedupe
- chore(agent): [Step 3/8] harden chat viewport resume ownership
- chore(agent): [Step 2/8] implement provider non-regressive refresh merge
- chore(agent): [Step 1/8] add chat stability regressions
- plan: fix chat stability regressions

## v1.168.1 - 2026-07-05

- fix(files): surface delete failure diagnostics

## v1.168.0 - 2026-07-05

- chore(agent): [Step 5/5] validate file editor delivery
- chore(agent): [Step 4/5] document file editor write support
- chore(agent): [Step 3/5] wire file editor save UX
- chore(agent): [Step 2/5] add safe file write operation
- chore(agent): [Step 1/5] add focused file editor
- plan: implement focused file editor

## v1.167.0 - 2026-07-03

- feat(project): auto-discover project icons

## v1.166.2 - 2026-07-03

- fix(project): stabilize ico project icons

## v1.166.1 - 2026-07-03

- fix(project): discover server favicons

## v1.166.0 - 2026-07-03

- docs(stt): document Windows WASAPI speech path
- fix(stt): preserve locale copy for Windows policy
- fix(stt): harden Windows capture failures
- fix(stt): route Windows voice through WASAPI
- plan: fix Windows speech-to-text crash

## v1.165.1 - 2026-07-03

- fix(sync): preserve active realtime and project contexts

## v1.165.0 - 2026-07-02

- docs(files): document shell-gated file manager
- fix(files): refresh stale file tree loads
- fix(files): close canonical root bypass
- fix(files): tighten file operation scope
- fix(files): fall back when file ops service is absent
- feat(files): add file tree management actions
- feat(files): add shell-gated file operations service
- plan: implement files micro manager

## v1.164.0 - 2026-07-02

- docs(chat): map scoped desktop rebuild selectors
- fix(chat): narrow desktop composer selection rebuilds
- plan: fix desktop composer selection stutter

## v1.163.0 - 2026-07-02

- docs: remove final plan artifact
- docs(chat): document connected model selector contract
- fix(chat): require selectable model before sending
- feat(chat): filter model selector by connected providers
- plan: dynamic connected model selector

## v1.162.0 - 2026-07-01

- docs(chat): map split reducer parts
- refactor(chat): split event reducer parts
- plan: split oversized Dart files

## v1.161.0 - 2026-07-01

- docs(agent): clarify Flutter PATH setup
- feat(data-saver): scope aggressive cellular sync
- plan: aggressive cellular data saver

## v1.160.0 - 2026-06-29

- feat(logging): add tagged task timing

## v1.159.2 - 2026-06-28

- fix(chat): restore session alerts and collapse review changes

## v1.159.1 - 2026-06-28

- feat(projects): discover app icons
- docs(agent): tune validation gates

## v1.159.0 - 2026-06-28

- feat(projects): discover per-project icons

## v1.158.0 - 2026-06-28

- fix(projects): clarify open folder flow

## v1.157.0 - 2026-06-27

- docs(web): document Cloudflare Pages deploy

## v1.156.0 - 2026-06-27

- fix(review): keep changes diff focused

## v1.155.0 - 2026-06-27

- fix(snackbar): adapt in-app toasts by viewport

## v1.154.1 - 2026-06-27

- fix(sidebar): close drawer for new chat

## v1.154.0 - 2026-06-27

- fix(sidebar): combine session filter controls (#79)

## v1.153.0 - 2026-06-26

- feat(composer): add native spell check toggle (#74)

## v1.152.0 - 2026-06-26

- fix(sidebar): lighten server header controls (#81)

## v1.151.0 - 2026-06-26

- fix(chat): preserve user-owned scroll position

## v1.150.2 - 2026-06-26

- fix(composer): keep multi-attachment part ids unique

## v1.150.1 - 2026-06-26

- fix(composer): tighten multi-attachment feedback

## v1.150.0 - 2026-06-26

- fix(composer): support multi-file attachment picks (#80)

## v1.149.0 - 2026-06-26

- fix(i18n): localize quota copy

## v1.148.3 - 2026-06-26

- test(sync): preserve resume grace health coverage
- test(sync): retry connected signal in coverage tests

## v1.148.2 - 2026-06-26

- test(sync): stabilize coverage timing checks
- fix(sync): keep resume restart quiet after background

## v1.148.1 - 2026-06-26

- fix(tailscale): recover connected status after up failure

## v1.148.0 - 2026-06-26

- fix: open embedded Tailscale login flow
- test: stabilize realtime resume grace validation

## v1.147.1 - 2026-06-25

- fix(composer): randomize across all receiving tips

## v1.147.0 - 2026-06-25

- feat(composer): expand agent prompt tips

## v1.146.0 - 2026-06-25

- docs(sync): document foreground resume grace
- fix(sync): debounce foreground resume warnings

## v1.145.0 - 2026-06-25

- fix(onboarding): unblock failed health checks

## v1.144.0 - 2026-06-25

- docs(logging): document global logging toggle
- fix(logging): recheck gate before lazy context
- fix(logging): lazy-build performance log context
- fix(logging): keep startup logging disabled by default
- fix(logging): preserve explicit diagnostic opt-ins
- feat(logging): add global logging toggle

## v1.143.0 - 2026-06-25

- fix(chat): scope inactive session events

## v1.142.0 - 2026-06-25

- fix(chat): align server status summary with health

## v1.141.1 - 2026-06-24

- fix(chat): harden fullscreen terminal restore

## v1.141.0 - 2026-06-24

- feat(chat/terminal): make maximize truly full-screen

## v1.140.0 - 2026-06-24

- feat(settings): add update release fallback
- docs(chat): document stability invariants
- fix(chat): stabilize final reveal scrolling
- fix(chat): guard assistant fallback reconciliation
- plan: issue 76 chat stability

## v1.139.0 - 2026-06-24

- feat(settings): surface CodeWalk update notice

## v1.138.1 - 2026-06-24

- Release maintenance.

## v1.138.0 - 2026-06-23

- fix(shortcuts): move agent cycling off Ctrl+J

## v1.137.0 - 2026-06-23

- fix(cache): use file-backed chat cache on native platforms

## v1.136.1 - 2026-06-23

- fix(logging): trace desktop performance bottlenecks

## v1.136.0 - 2026-06-23

- feat(logging): add opt-in performance tracing

## v1.135.0 - 2026-06-22

- fix: reduce Windows notification cleanup and STT shortcut risk

## v1.134.0 - 2026-06-22

- fix: harden message image sharing
- fix: share message images as PNG files on Windows (#55)

## v1.133.0 - 2026-06-22

- fix(notifications): focus app on notification taps

## v1.132.0 - 2026-06-20

- fix(chat): hide active block-render work runs
- feat(chat): add block response render mode (#72)

## v1.131.0 - 2026-06-20

- fix: constrain composer chip avatars
- fix: preserve composer permission hit target
- merge: integrate composer density controls
- fix: respect density in composer model controls

## v1.130.3 - 2026-06-20

- fix(sidebar): simplify recent session rows

## v1.130.2 - 2026-06-20

- fix(sidebar): align compact session actions

## v1.130.1 - 2026-06-20

- fix(sidebar): tighten recent session rows

## v1.130.0 - 2026-06-19

- fix(review): address sidebar menu findings
- feat(sidebar): add row menus and flatten session surfaces
- docs(sidebar): decide project icon discovery plan

## v1.129.0 - 2026-06-18

- fix(review): restore data saver realtime transitions
- feat: add aggressive data saver resume policy

## v1.128.0 - 2026-06-18

- fix(review): address group A release findings
- merge: integrate android cache payload hotfix
- fix(android): move chat cache payloads back to files
- docs: update behavior for group A UI changes
- feat(mobile): allow three pinned app bar actions
- fix(files): show file tree loading and retry states
- fix(chat): give session search the sidebar header
- feat(chat): grid context usage metrics
- fix(chat): widen compact context hit area

## v1.127.1 - 2026-06-17

- fix(chat): stabilize final response settlement

## v1.127.0 - 2026-06-17

- chore: remove obsolete Windows desktop build script
- Add Windows desktop build wrapper
- Stabilize final response reading viewport
- chore: refresh root docs and stale validation
- docs: prefer GitHub Issues over roadmap

## v1.126.1 - 2026-06-15

- Release maintenance for v1.126.1.
