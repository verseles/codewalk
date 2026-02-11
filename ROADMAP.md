---
roadmap: "CodeWalk Solo Migration Roadmap"
created_on: "2026-02-09"
execution_mode: "feature-by-feature"
source_project: "https://github.com/easychen/openMode"
---

## Execution Protocol

1. Trigger command pattern: `implement feat XXX now` (example: `implement feat 006 now`).
2. During execution:
   - mark active tasks as `[~]`,
   - mark completed tasks as `[x]`,
   - mark blocked tasks as `[/]` with blocker reason.
3. Complete all tasks in `ROADMAP.featXXX.md` before moving to the next feature unless a blocker is explicit.
4. After full completion of a feature, summarize implementation in `ROADMAP.md` and keep only necessary long-form notes.

## Task List

### Feature 001: Baseline Audit, Safety Rails, and Deletion Policy
Description: Build an objective baseline of the current fork (code, docs, endpoints, tests, platform support) and define hard safety rails before touching implementation.

Completed a full baseline inventory of source/runtime/docs/platform state, defined deletion and retention policies for generated and markdown artifacts, and established rollback checkpoints plus dependency and acceptance-gate governance for all later features.
Commits: b9de67f, 7d7e6f6, 3640fb2, d307731, c96f53c

### Feature 002: Licensing Migration to AGPLv3 + Commercial (>500M Revenue)
Description: Replace MIT with a compliant AGPLv3 setup and add a separate commercial license track for organizations above the revenue threshold.

Completed legal migration from MIT to AGPLv3, added a dedicated commercial license track for organizations above the revenue threshold, published attribution/warranty notices, and validated dependency licensing compatibility with unresolved decisions documented.
Commits: 2b51dd3, f0bc342, 898889f, b5e1719, a25cb31

### Feature 003: Rebrand OpenMode -> CodeWalk (Code, Package IDs, Metadata)
Description: Rename all product-facing and package-level identifiers from OpenMode/open_mode to CodeWalk/codewalk across app runtime, build metadata, and distribution assets.

Completed product and package rebranding from OpenMode to CodeWalk across Flutter metadata, source imports, Android namespace/applicationId, and web manifest/title/PWA references, followed by smoke validation to catch rename regressions.
Commits: 9483801, ede3939, a519f8f, 63549d4

### Feature 004: Full English Standardization (UI, Code Comments, Docs)
Description: Translate all remaining non-English content to English, including user-facing strings, comments, logs, and technical documentation.

Completed English standardization for UI strings, runtime messaging, source comments, and retained technical docs. Automated language regression checks were intentionally marked as a wont-do based on product decision.
Commits: 1bc9184

### Feature 005: Documentation Restructure and Markdown Pruning
Description: Remove unnecessary markdown files, consolidate surviving docs, and rewrite README with explicit origin attribution to OpenMode.

Completed documentation triage and consolidation by classifying markdown assets, merging unique technical history into `CODEBASE.md`, rewriting `README.md` for the CodeWalk identity with origin attribution, and pruning redundant files without knowledge loss.
Commits: 8562850, 7c72e70, b219a2b, d02f486

### Feature 006: OpenCode Server Mode API Refresh and Documentation Update
Description: Align the client and internal API docs with the latest OpenCode Server Mode endpoints/schemas and close compatibility gaps.

Completed a full Server Mode compatibility refresh through endpoint gap mapping, model/datasource/use-case updates for schema drift, and replacement of obsolete integration docs with a versioned guide; validated live against `100.68.105.54:4096` across provider, session, event, and message paths including nested-model parsing fixes.
Commits: e994f39, bbadbe4, 78acc18, ad6470c

### Feature 007: Cross-Platform Desktop Enablement and Responsive UX
Description: Expand project target platforms beyond mobile and deliver a true cross experience for desktop/web/mobile with adaptive layouts and desktop-native interactions. (Visit file ROADMAP.feat007.md for full research details)

- [x] 7.01 Add desktop platforms (Windows/macOS/Linux) to Flutter project - Enabled desktop flags and generated `linux/`, `macos/`, `windows/` via Flutter tooling
- [x] 7.02 Implement responsive layout breakpoints (mobile drawer vs desktop split view) - `ChatPage` now adapts with mobile drawer (`<840`), split desktop (`>=840`), and large-desktop utility panel (`>=1200`)
- [x] 7.03 Add desktop input ergonomics (shortcuts, hover/focus polish, resize behavior) - Added `Ctrl/Cmd+N`, `Ctrl/Cmd+R`, `Ctrl/Cmd+L`, `Esc`; external input focus control; desktop hover/cursor polish in session list
- [/] 7.04 Validate build/run on each target and document platform-specific caveats - Linux/web validation passed (`flutter test`, `flutter build linux`, `flutter build web`, Linux runtime smoke). Blocked for full target matrix by host OS constraint (`flutter build windows` requires Windows host, `flutter build macos` requires macOS host)

### Feature 008: Manual QA Campaign and Stability Hardening
Description: Execute a structured manual test campaign across supported platforms and critical user journeys, then fix high-impact defects before automation is expanded.

Completed a structured QA campaign with defined matrix and scenario IDs, executed scripted smoke coverage against live server flows, fixed P1 defects (secure logging leak and Android AGP build blocker), and published release readiness with known limitations.
Commits: da2940b, cc5c78f

### Feature 009: Automated Test Suite and CI Quality Gates
Description: Build comprehensive automated tests (unit, widget, integration) and enforce quality gates in CI so future changes remain stable.

Implemented a layered automation baseline with unit tests for model parsing/use case delegation/provider state transitions, widget tests for responsive chat shell and send-message flow, and integration tests against a controllable local mock OpenCode server including session CRUD, app/provider bootstrap calls, SSE message updates, and 400 validation error mapping. Added CI workflow gates for phased static analysis budget, full test execution with coverage generation, and minimum coverage threshold enforcement scripts, plus a race-condition fix in chat SSE handling so pending message fetches are not dropped when the event stream closes.
Commits: 5125edd

### Feature 010: OpenCode Upstream Parity Baseline and Contract Freeze
Description: Consolidate the latest OpenCode Server/API/Desktop/Web behavior into a single compatibility contract for CodeWalk implementation planning. (Visit file ROADMAP.feat010.md for full research details)

Completed a signed parity contract baseline using a fixed upstream/docs/OpenAPI snapshot, defined Required vs Optional parity scope across endpoint/event/part/UX surfaces, aligned `CODEBASE.md` to the v2 taxonomy for implementation work, and documented a rollback-safe persisted-state migration strategy from flat keys to server/directory-scoped storage.

- [x] 10.01 Lock target reference snapshot (`opencode.ai` docs + upstream commit + OpenAPI) and define supported server versions/range
- [x] 10.02 Define parity matrix (`endpoint + event + part type + UX behavior`) with Required vs Optional scope
- [x] 10.03 Align local docs (`CODEBASE.md` integration section) with v2 route/event taxonomy before feature implementation begins
- [x] 10.04 Define migration strategy for persisted client state (server profiles, model selection, session cache)

### Feature 011: Multi-Server Management and Health Orchestration
Description: Implement first-class support for multiple OpenCode servers (desktop/mobile parity), including active/default server routing and health-aware switching. (Visit file ROADMAP.feat011.md for full research details)

Completed multi-server orchestration end-to-end with persisted `ServerProfile` migration from legacy host/port keys, health-aware activation/default selection, scoped runtime persistence (`serverId` + contextual scope) for chat/session/model state isolation, and full UI/server-switch integration from app bar and settings. Added unit/widget/integration coverage validating migration, duplicate normalization, unhealthy switch blocking, and cache isolation across active server switches.

- [x] 11.01 Introduce `ServerProfile` storage (list, add/edit/remove, active, default) replacing single `host/port` persistence
- [x] 11.02 Build server manager UI (`add`, `edit`, `delete`, `set default`, `health badge`, `connectivity validation`)
- [x] 11.03 Scope runtime state/caches per server (projects, sessions, model preferences, auth settings) to avoid cross-server pollution
- [x] 11.04 Add unit/widget/integration coverage for server switching, invalid server handling, and fallback behavior

### Feature 012: Model/Provider Switching and Variant (Reasoning Effort) Controls
Description: Bring model control parity with OpenCode Desktop/Web, including current-model changes and model variant/reasoning-effort changes. (Visit file ROADMAP.feat012.md for full research details)

Completed model-control parity foundations by adding provider/model picker controls in the composer area, variant/reasoning cycling with model-aware validation, and outbound payload parity through `variant` serialization for message sends. Extended server-scoped persistence to include variant maps plus recent/frequent model history and restore logic; expanded unit/widget/integration tests to cover parsing, selection, cycling, payload assertions, and no-variant backward compatibility.

- [x] 12.01 Add provider/model picker in chat composer flow and persist user selections
- [x] 12.02 Parse/provider model variants from `/provider` and expose current variant state in UI
- [x] 12.03 Add variant/reasoning-effort cycle action and include `variant` field in outbound prompt payloads
- [x] 12.04 Persist recent/frequent model usage (server-scoped) and restore safely across launches
- [x] 12.05 Add tests for model switch, variant switch, and backward compatibility when variants are absent

### Feature 013: Event Stream and Message-Part Parity (Messages, Thinking, Tools, Questions, Permissions)
Description: Expand real-time event handling to match OpenCode v2 event/part taxonomy and reliably render message lifecycle details. (Visit file ROADMAP.feat013.md for full research details)

Completed realtime parity foundations with resilient SSE subscription (`/event`) including reconnect/backoff handling, provider-level event reducer for session/message/status/permission/question flows, and fallback full-message fetch on partial/delta scenarios. Expanded part taxonomy parsing/rendering for step/snapshot/subtask/retry/compaction/agent/patch types, added interactive permission/question cards with response endpoints, and covered behavior through unit/widget/integration tests (including event-matrix + reconnect scenarios).

Applied a post-completion stabilization fix to forward `directory` scope through send-message streaming (`/event` and `/session/{id}/message/{messageId}` fetch fallback), resolving cases where responses stayed in thinking-only state when server routing required directory-scoped events.
Added an additional stabilization pass with release-visible send lifecycle logs in Logs tab and assistant-message-ID recovery via `/session/{id}/message` when stream events are unavailable, improving field diagnosis for intermittent SSE failures.
Added watchdog fallback for cases where `/event` stays connected without message events, and removed duplicate realtime subscriptions by fixing a provider-level race in event subscription startup.
Applied send-payload correction for normal prompts: stop sending `messageID` in standard message creation requests to prevent stale repeated assistant IDs from server immediate responses.
Hardened provider send setup with step logs and best-effort local selection persistence so storage-layer failures cannot block outbound send stream subscription.
Fixed a send-path crash triggered by fixed-length restored recent-model lists (`Unsupported operation: Cannot remove from a fixed-length list`) before repository dispatch.

- [x] 13.01 Harden SSE layer (reconnect, backoff, stale subscription guard, fetch fallback) for long-running sessions
- [x] 13.02 Support full high-value event set (`message.*`, `session.status`, `session.error`, `permission.*`, `question.*`) in provider state
- [x] 13.03 Expand part parsing/rendering coverage (`step-start`, `step-finish`, `snapshot`, `subtask`, `retry`, `compaction`, `agent`, `patch`)
- [x] 13.04 Add permission/question response UX for interactive tool flows
- [x] 13.05 Add integration tests with mocked event matrix and partial/delta update scenarios

### Feature 014: Advanced Session Lifecycle Management
Description: Upgrade session operations beyond basic CRUD to parity-level management for active and historical work.

Completed full session lifecycle parity implementation across domain/data/provider/UI layers: added end-to-end rename/archive/unarchive/share/unshare/delete with optimistic local updates + rollback, implemented fork/status/children/todo/diff capabilities with provider-level insight reconciliation, and expanded session list UX with search/filter/sort/load-more controls suitable for large histories. Also extended event reducer handling for `todo.updated` and `session.diff`, hardened session ordering/cache persistence behavior, and added lifecycle-focused unit/widget/integration tests with controlled server fixtures.

- [x] 14.01 Implement rename/archive/share/unshare/delete flows end-to-end (API + UI + optimistic update + rollback)
- [x] 14.02 Add session fork/children/todo/diff/status capabilities where supported by server
- [x] 14.03 Implement robust session list UX (sorting, filtering/search, scalable loading strategy)
- [x] 14.04 Add session timeline/history quality (state reconciliation across updates and navigation)
- [x] 14.05 Cover session lifecycle operations with integration tests against controlled server fixtures

### Feature 015: Project/Workspace Context Parity
Description: Support multi-project and workspace/worktree workflows using directory-aware API/event orchestration. (Visit file ROADMAP.feat015.md for full research details)

Completed project/workspace parity across domain/data/provider/UI layers with deterministic context isolation (`serverId::directory`), project switcher UX with active context controls (switch/close/reopen/refresh), worktree lifecycle operations (`create/reset/delete/open`), and directory-scoped routing for provider/session/message/event calls. Added global-context synchronization via `/global/event` with dirty-context invalidation and scoped snapshot restore, plus expanded unit/widget/integration coverage for project switching, worktree routes, global event ingestion, and server-scoped cache isolation under context transitions.
Applied a post-completion chat UX refinement so conversation view opens at the latest message and exposes a jump-to-latest FAB that is visually highlighted when new messages arrive while the user is reading older content.
Adjusted project-context switching to auto-open the last session per directory (with fallback to most recent when no stored selection exists), reducing empty-state friction during A/B project navigation.
Aligned main navigation with chat-first workflow by moving `Chat / Logs / Settings` controls to the top of the conversations sidebar and making `Logs`/`Settings` secondary routes with explicit back navigation to chat.
Refined the sidebar navigation style to match area semantics: removed explicit `Chat` action and kept a compact one-line row with actionable `Logs` and `Settings` buttons only.
Fixed a new-session UX regression where `New Chat` could create sessions without switching focus: directory-scoped session lists are now kept mutable and new-session creation explicitly persists/selects the newly created session.
Fixed a visual duplicate-send issue where a local optimistic user bubble and server-confirmed user message could appear together; confirmed messages now replace pending local bubbles when content/session/time match.
Unified provider/model controls into a single searchable selector grouped by provider, with compact closed-state label showing only the active model name.
Refined selection UX so model/provider uses searchable bottom sheet (with alphabetical providers + 3 recent models), while reasoning effort uses a fast anchored popup selector; also removed the outer border wrapper around both selector chips.
Clarified workspace creation UX by allowing users to choose an explicit base directory in the "Create workspace" dialog, instead of always using the current context directory implicitly.
Added explicit workspace-operation telemetry in app logs (`create/reset/delete` start/success/failure + provider error mirroring) to diagnose silent failures directly from the Logs tab.
Added dynamic folder browsing for workspace creation (server-backed directory picker via `/file`) with preflight Git validation (`/vcs`) to prevent non-git workspace attempts.
Added explicit git-only warning inside directory picker and reinforced post-create context switch so newly created workspaces open immediately.

- [x] 15.01 Implement project switcher UX with explicit current-context indicator and close/reopen behaviors
- [x] 15.02 Add workspace/worktree operations (`create`, `reset`, `delete`) where server exposes corresponding routes
- [x] 15.03 Adopt `directory` scoping consistently for requests and event routing to avoid cross-context bleed
- [x] 15.04 Introduce global-context sync strategy (`/global/event` + per-directory stores) with deterministic cache invalidation
- [x] 15.05 Add tests for project/workspace switching, context isolation, and stale-state race conditions

### Feature 016: Reliability Hardening, QA, and Release Readiness for Parity Wave
Description: Validate and harden all parity features with measurable quality gates before production rollout.

Completed parity hardening and release readiness by expanding regression coverage across unit/widget/integration suites (including server-scoped model restore and question-reject flows), executing the `PAR-001..PAR-008` QA matrix with reproducible artifacts, and finalizing architecture/release documentation (`ADR.md`, `CODEBASE.md`, `RELEASE_NOTES.md`, `QA.feat016.release-readiness.md`). Final rollout gates were validated via `make precommit`, coverage gate pass at 59.44%, and Linux/Web release builds, with one documented non-product host limitation (Android emulator startup failure code `-6`) mitigated by successful APK build/upload validation.
Applied a post-release chat composer enhancement: implemented image/PDF attachments in the input flow (`file_picker` + `file` parts with `mime`/`url`) and gated attachment UI visibility by selected model capabilities so unsupported models hide the attachment action.
Refined attachment capability handling to be modality-aware per model (`image` vs `pdf`), so the attachment sheet now shows only supported options instead of exposing unsupported file types.
Added voice-to-text input in the chat composer using `speech_to_text`, with a dedicated microphone action beside send and Android speech-recognition permission/query wiring for device compatibility.
Refined voice-input affordance so the microphone button turns red while listening is active, making recording state immediately visible before message send.
Enhanced composer send affordance with a secondary hold action: pressing send for 300ms inserts a newline instead of sending, plus a small corner icon to signal this behavior in the button UI.
Restored assistant progress feedback during response generation by showing staged indicators in the message list (`Thinking...`, `Receiving response...`, `Retrying model request...`) driven by send state, `session.status`, and in-progress assistant message parts.
Removed inline `Step started`/`Step finished` assistant blocks from the message body and moved their metadata to the assistant info menu (`i` icon) in the message header for a cleaner response flow.
Enabled selectable text for assistant and user messages through a unified `SelectionArea` around message content, removed dedicated inline copy buttons, changed full-message copy to trigger only on double-tap/double-click over the message bubble background (not on top of text), and suppressed in-app copy toast on Android to rely on native system feedback.
Refined the top app bar context selector by removing the rounded bordered chip style and moving the current directory selector to the left-aligned title area, making project context the primary top-bar highlight.
Replaced the project selector popup menu with an adaptive Android-style dialog: fullscreen on small screens and centered on larger screens, with permanent actions pinned at the top and per-project trailing close buttons directly in the project list.
Commits: d568f22, 47ecddb, 3081b2e, b65f7f6, afb63be

### Feature 017: Realtime-First Refreshless UX
Description: Remove manual refresh interactions and keep UI state continuously updated through SSE-driven sync with lifecycle-aware efficiency controls.

Completed refreshless realtime orchestration by introducing a feature-flagged SSE-first sync model (`CODEWALK_REFRESHLESS_ENABLED`) with provider-level sync states (`connected/reconnecting/delayed`), lifecycle-aware stream suspend/resume reconcile, degraded fallback polling only under stream-health degradation, and scoped reconcile queues replacing broad refresh calls. Removed manual refresh affordances from target chat/context flows when refreshless mode is enabled, surfaced sync status in UI, expanded reducer incremental coverage (`message.created`, `permission.updated`, `question.updated`, global incremental apply path), and validated behavior through full unit/widget/integration regression runs including reconnect, resume, degraded recovery, and no-manual-refresh flows.
Commits: f190e02

### Feature 018: Prompt Power Features Parity (`@`, `!`, `/`)
Description: Replicar no composer os gatilhos de produtividade do OpenCode Web: menção de arquivos/agentes com `@`, modo shell com `!` no início, e catálogo de comandos por `/` no começo do input.
Status: [x] Concluída

Concluída a paridade de gatilhos no composer com estado dedicado para shell (`!`), popovers contextuais para menções `@` (arquivos + agentes) e slash `/` (builtin + comandos remotos com `source`), incluindo navegação por teclado (`ArrowUp/Down`, `Enter`, `Tab`, `Esc`), inserção de tokens/prefixos no input, e ações builtin consistentes no contexto da chat page. O envio shell foi integrado ao fluxo de provider/datasource com roteamento para `POST /session/{id}/shell`, e a cobertura foi expandida com testes de widget para `@`/`!`/`/` e teste unitário de payload shell. Na sequência, a UX do composer foi estabilizada para mobile/desktop com preservação de foco do input durante digitação em sugestões, painel de sugestões crescendo para cima sem cobrir o input, input mantendo-se acima do teclado, e inserção de menção com espaço seguro antes de pontuação. O painel de sugestões foi simplificado para renderização inline imediatamente acima do input (sem overlay global), com altura máxima fixa de `3x` a altura do input em mobile/desktop, limitada pela área visível e com rolagem interna da lista para conjuntos grandes. Foi aplicado ajuste adicional específico de teclado Android para não deixar o painel cobrir o campo de texto: o cálculo de altura agora reserva espaço do input no viewport visível e remove padding superior desnecessário do composer.
Commits: e97544b, 094057a, 8be2d81, ef0a1e7, 53da769, 7ff7b71, 6d0ebe8, dfbda1b

### Feature 019: File Explorer and Viewer Parity
Description: Entregar navegação completa de arquivos com ícones, busca rápida, abertura em abas e visualização de conteúdo diretamente na UI, alinhado ao OpenCode Web.

Concluída a paridade de exploração/abertura/visualização de arquivos no chat principal com base nos endpoints `/file`, `/find/file` e `/file/content`: foi adicionada árvore expansível com ícones por tipo/extensão, quick open com ranking e atalho (`Ctrl/Cmd+P`), integração do comando builtin `/open`, viewer em abas com estados `loading/ready/empty/binary/error`, invalidação de nós/abas por `session.diff`, e fallback de resolução de path absoluto/relativo por contexto para manter robustez entre servidores. A fundação de dados foi formalizada no domínio/repositório de projeto (`FileNode`, `FileContent`) e a cobertura foi ampliada com testes unitários de ranking/reducer de tabs e testes de widget para árvore, quick open, renderização de conteúdo textual e fallbacks binário/erro.

### Feature 020: Agent Selector in Composer (Model/Thinking Bar)
Description: Incluir seletor explícito de agente (Build, Plan e demais permitidos) ao lado de provider/model e thinking, com persistência por contexto e integração de envio.

Concluída a entrega do seletor de agente no composer ao lado de model/variant com ordenação estável e labels consistentes, carregamento do contrato `/agent` na camada de app, persistência/restauração por escopo (`server + directory`) com fallback seguro para agentes válidos, integração completa da seleção no payload de prompt (`agent`) sem regressão de shell mode, comandos rápidos com ciclo por atalho (`Ctrl/Cmd+J`, reverso com `Shift`) e ação builtin `/agent`, além de cobertura ampliada em testes unit/widget/integration para seleção, persistência e payload.
Commits: bf20bde, c75df1d

### Feature 021: Session Title Visibility and Quick Rename Parity
Description: Melhorar a UX de sessão para sempre exibir título de conversa de forma clara e permitir renomeação rápida/inline sem fricção. (Visit file ROADMAP.feat021.md for full research details)

- [x] 21.01 Pesquisa e freeze de comportamento (display de título no header, rename inline/menu e contrato `session.update`)
- [x] 21.02 Garantir exibição consistente do título da sessão ativa nas áreas primárias da tela (mobile e desktop)
- [x] 21.03 Implementar renomeação inline com fluxo otimista + rollback em erro e sincronização imediata da lista de sessões
- [x] 21.04 Refinar fallback de títulos automáticos (`Today ...`) para reduzir ambiguidade e melhorar legibilidade temporal
- [x] 21.05 Cobrir render/rename/fallback com testes automatizados

### Feature 022: Settings Parity (Notifications, Sounds, Shortcuts)
Description: Expandir configurações para incluir notificações e sons por categoria (agente/permissões/erros) e uma tela dedicada de atalhos com busca e detecção de conflito. (Visit file ROADMAP.feat022.md for full research details)

- [x] 22.01 Pesquisa e freeze de escopo de settings (toggles, sound selectors, keybind groups/search/conflict)
- [x] 22.02 Implementar preferências de notificação por categoria com integração de plataforma (desktop/web/mobile) e persistência
- [x] 22.03 Implementar preferências de som por categoria com pré-escuta, persistência e fallback quando áudio não estiver disponível
- [x] 22.04 Implementar tela de atalhos dedicada com grupos, busca fuzzy, redefinição global e validação de conflitos
- [x] 22.05 Cobrir persistência e comportamento de settings com testes unit/widget/integration

Concluída a paridade de Settings com redesign estrutural da área para múltiplas seções escaláveis (Notifications, Shortcuts, Servers), migrando o antigo fluxo focado em servidores para um hub modular responsivo (mobile e desktop). Foi implementada persistência versionada de preferências de experiência, integração de notificações por categoria com fallback por plataforma, matriz de sons por categoria com pré-escuta, central dedicada de atalhos com captura de keybind, busca e validação de conflitos, além da adoção de atalhos dinâmicos no `ChatPage` com base nas preferências salvas. A entrega incluiu ajustes Android para compatibilidade do plugin de notificações (permission + desugaring) e ampliação de cobertura automatizada com testes unitários/widget para settings.
Aplicado ajuste pós-entrega para tornar `Shortcuts` exclusivo de desktop/web, sincronizar preferências de `Notifications` com `/config` quando o servidor expõe chaves compatíveis (fallback local quando ausente), e substituir o playback de som por geração/execução de áudio em memória para evitar cenários sem áudio em `SystemSound`.
Aplicado ajuste final de notificações para deep-link por sessão ao tocar a notificação (Android/desktop/web), título focado no formato `Finished: <título da sessão>`, suporte cross-platform explícito (Linux/macOS/Windows via plugin e Web Notification API), e novos controles independentes por tipo (`Notify` e `Sound`) para `agent`, `permissions/question` e `errors`.
Aplicado refinamento de UX em Settings removendo a seção separada `Sounds` (controles consolidados em `Notifications`) e eliminando bordas decorativas dos toggles `Notify`/`Sound`.

## Dependency Order

1. Feature 001 -> blocks all other features (baseline + safety rails)
2. Feature 002 -> should finish before publishing docs/release artifacts
3. Feature 003 -> should happen before broad documentation rewrites
4. Feature 004 -> should happen before final markdown pruning
5. Feature 005 -> should happen before API documentation refresh
6. Feature 006 -> should happen before desktop/manual/automation validation
7. Feature 007 -> should happen before full manual QA campaign
8. Feature 008 -> should happen before final CI quality thresholds
9. Feature 009 -> provides regression safety net for parity expansion
10. Feature 010 -> defines parity contract and scope boundaries for all upcoming implementation
11. Feature 011 -> depends on 010 and establishes server orchestration foundation
12. Feature 012 -> depends on 010/011 for model persistence and active-server context
13. Feature 013 -> depends on 010 and should land before advanced session UX
14. Feature 014 -> depends on 013 event fidelity and 012 model controls
15. Feature 015 -> depends on 011 + 013 to safely support multi-context orchestration
16. Feature 016 -> final hardening/release gate for features 011-015
17. Feature 017 -> depends on 013 + 015 + 016 to safely remove manual refresh controls
18. Feature 018 -> depends on 012 + 015 + 017 to add advanced prompt triggers over stable scoped context and realtime sync
19. Feature 019 -> depends on 015 + 017 + 018 for refreshless file navigation integrated with prompt/file-open flows
20. Feature 020 -> depends on 012 + 018 to align agent selection with model/thinking controls and prompt command grammar
21. Feature 021 -> depends on 014 + 017 to deliver consistent session-title UX over stable lifecycle and sync behavior
22. Feature 022 -> depends on 018 + 020 to expose complete command/agent-driven settings and shortcut management

## Legend

- [x] Done
- [~] In progress now
- [/] Partially done but blocked
- [!] Won't do (with reason)
- [ ] Not started

## Acceptance Gates

| Feature | Entry Gate | Exit Gate |
|---------|-----------|-----------|
| 001 | None | CODEBASE.md + Makefile + doc classification + ADR + gates defined |
| 002 | 001 complete | LICENSE AGPLv3 + LICENSE-COMMERCIAL.md + NOTICE + dep compatibility verified |
| 003 | 002 complete | All IDs renamed + `flutter analyze` no new errors + smoke test build |
| 004 | 003 complete | Zero CJK strings in `lib/` + `flutter analyze` clean |
| 005 | 004 complete | README rewritten + docs consolidated + no orphan MD files |
| 006 | 005 complete | Gap matrix closed + models updated + validated against real server |
| 007 | 006 complete | Desktop builds OK + responsive layout + keyboard shortcuts working |
| 008 | 007 complete | Test matrix executed + P0/P1 fixed + readiness report published |
| 009 | 008 complete | Unit/widget/integration tests + CI pipeline + coverage thresholds |
| 010 | 009 complete | Signed parity contract + endpoint/event/UX gap matrix + migration checklist |
| 011 | 010 complete | Multi-server profile management + active/default switching + server-scoped state isolation |
| 012 | 010, 011 complete | User can switch model/provider + switch variant/reasoning effort + payload parity validated |
| 013 | 010 complete | Stable SSE/event engine + expanded part rendering + interactive question/permission handling |
| 014 | 012, 013 complete | Session lifecycle parity (rename/archive/share/fork/etc.) with passing API/UI tests |
| 015 | 011, 013 complete | Reliable project/workspace context switching with directory-isolated state |
| 016 | 011-015 complete | QA signoff + docs/ADR/CODEBASE updates + release checklist complete |
| 017 | 013, 015, 016 complete | Refreshless UX with SSE-first sync, lifecycle-aware fallback, and validated no-manual-refresh flows |
| 018 | 012, 015, 017 complete | Composer supports `@` mentions + leading `!` shell mode + leading `/` slash commands with tested keyboard/mouse flows |
| 019 | 015, 017, 018 complete | File tree + fuzzy open + file viewer available with stable state sync and passing navigation/render tests |
| 020 | 012, 018 complete | Agent selector is first-class beside model/thinking, persisted per context, and reflected in outbound prompts |
| 021 | 014, 017 complete | Active session title is always visible and rename-inline flow updates state/UI reliably with rollback safety |
| 022 | 018, 020 complete | Settings include notification/sound categories and searchable shortcut management with persistence/conflict checks |

## Pending Backlog

- [x] Desktop: enter deve enviar mensagem, shift+enter quebrar linha
- [x] Desktop: botão em cada sidebar para ocultar o sidebar como opção
- [x] Mobile e desktop: input de texto não deve ficar bloqueado enquanto recebe mensagem, apenas não deve poder enviar antes de terminar de receber as respostas do servidor, ou clicar no botão stop pra abortar
- [ ] No desktop, pesquisar como usar microfone speech-to-text no linux. Pesquisar também se a API atual já funciona no mac/windows/iOS
- [x] Context Project / Workspace: opção para arquivar project fechado (ocultar da lista de fechados)
- [ ] Usar https://github.com/jlnrrg/simple_icons para exibir icones mais bonitos na lista de arquivos e na lista de providers/icone do modelo selecionado
- [ ] Desktop: seta pra cima edita a última mensagem enviada (via backend), mobile: touch & hold
- [ ] Manter o modelo selecionado sincronizado, atualmente o modelo selecionado no desktop, não é o mesmo selecionado no app mobile, o servidor backend deve passar essa informação
- [ ] Opções em Settings para decidir se app fica em background. Mobile: persistente notification, desktop: tray
- [ ] Ajustar popover de sugestões no Android para nunca cobrir o input com teclado aberto em todos os teclades/dispositivos (validar em device real com Gboard e Samsung Keyboard)
- [x] Transformar o botão `Send` em `Stop` enquanto o assistant estiver respondendo e integrar com `POST /session/{id}/abort` para interromper o pensamento/execução em andamento

Pronta para análise: backlog de ergonomia do composer/desktop concluído com Enter/Shift+Enter no desktop, sidebars recolhíveis com persistência por pane, input editável durante resposta e ação Stop integrada ao abort de sessão com cobertura automatizada.
Ajuste pós-entrega aplicado: ao acionar `Stop`, erros esperados de cancelamento (`The operation was aborted`/equivalentes) não derrubam mais a conversa para tela global de erro com `Retry`; a interrupção agora mantém o contexto para continuação imediata.
Ajuste pós-entrega complementar aplicado: corrigido erro ao enviar imediatamente após `Stop` (`Failed to start message send`/`retry`) causado por coleção de mensagens tornada imutável no fluxo de abort; o envio subsequente agora funciona sem exigir `Retry` manual.
- [ ] Aplicar ícones de app para Linux (GNOME/Freedesktop) e alinhar equivalentes para os demais OS (Windows/macOS)
- [ ] Emular `opencode serve` internamente como opção de servidor local (permitir ao CodeWalk iniciar e gerenciar um servidor OpenCode embutido sem depender de instância externa)
- [x] Adotar stale-while-revalidate e manter a última sessão em cache local para UX instantânea ao abrir o app (servidores remotos podem levar até ~10s para responder, causando lag perceptível na abertura da última conversa)

Pronta para análise: adicionada ação de arquivamento na seção de contextos fechados para ocultar projects fechados sem depender de `worktree`, com persistência por servidor para manter a curadoria da lista ao reiniciar/recarregar. Também foi implementado cache persistido da última sessão (sessão + mensagens) por escopo (`server + directory`) com restore instantâneo na abertura e revalidação silenciosa em background (SWR), preservando usabilidade mesmo com latência alta do servidor remoto. No mobile, o envio pelo teclado agora usa ação `send` e oculta o teclado/foco após submissão para liberar mais espaço da conversa.

## Code Quality and Technical Debt

### Feature 023: Critical Code Issues Resolution (2026-02-11)

Description: Corrigir problemas críticos de código identificados via análise estática e padrões, focando em APIs deprecated e anti-patterns que afetam compatibilidade e maintainability.

- [x] 023.01 Mapear e catalogar baseline atual (141 issues no `flutter analyze`: 79 `deprecated_member_use`, 5 `use_build_context_synchronously`, 1 erro de compilação em bridge web)
- [x] 023.02 Migrar todas as ocorrências de `withOpacity` para `withValues` (59 ocorrências em `lib/`)
- [x] 023.03 Migrar `surfaceVariant` para `surfaceContainerHighest` (11 ocorrências em múltiplos widgets/pages)
- [x] 023.04 Migrar `background` para `surface` e `onBackground` para `onSurface` em usos de `ColorScheme` (6 ocorrências totais)
- [x] 023.05 Migrar `value` para `initialValue` em `DropdownButtonFormField` (2 ocorrências em settings)
- [x] 023.06 Corrigir uso de BuildContext assíncrono (5 ocorrências em `chat_page.dart`)
- [x] 023.07 Atualizar dependências descontinuadas (`flutter_markdown_plus` para substituir `flutter_markdown`) e adicionar `web` como dependência direta
- [x] 023.08 Executar `flutter analyze` para validar remoção total dos problemas-alvo da feature (sem `deprecated_member_use`, sem erro em bridge web, sem `use_build_context_synchronously`)
- [x] 023.09 Executar testes completos para garantir não regressões (`make test` passando)
- [x] 023.10 Build Android via `make android` com upload (`tdl`) para validação em device

Pronta para análise: a feature removeu integralmente os problemas-alvo de deprecação/compatibilidade, reduziu o baseline de `flutter analyze` de 141 para 55 issues (residuais e fora do escopo da 023), eliminou o erro de compilação no bridge web e validou regressão com suíte completa de testes e build Android.
