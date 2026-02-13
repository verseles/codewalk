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

Completed baseline inventory, deletion/retention policies, rollback checkpoints, and dependency governance for subsequent features.
Commits: b9de67f, 7d7e6f6, 3640fb2, d307731, c96f53c

### Feature 002: Licensing Migration to AGPLv3 + Commercial (>500M Revenue)
Description: Replace MIT with a compliant AGPLv3 setup and add a separate commercial license track for organizations above the revenue threshold.

Completed legal migration to AGPLv3 with commercial license track, notices, and dependency license validation.
Commits: 2b51dd3, f0bc342, 898889f, b5e1719, a25cb31

### Feature 003: Rebrand OpenMode -> CodeWalk (Code, Package IDs, Metadata)
Description: Rename all product-facing and package-level identifiers from OpenMode/open_mode to CodeWalk/codewalk across app runtime, build metadata, and distribution assets.

Completed rebrand across app metadata, source imports, Android namespace/applicationId, and web manifest/title references.
Commits: 9483801, ede3939, a519f8f, 63549d4

### Feature 004: Full English Standardization (UI, Code Comments, Docs)
Description: Translate all remaining non-English content to English, including user-facing strings, comments, logs, and technical documentation.

Completed UI/runtime/comment English standardization; automated language regression checks intentionally marked as wont-do.
Commits: 1bc9184

### Feature 005: Documentation Restructure and Markdown Pruning
Description: Remove unnecessary markdown files, consolidate surviving docs, and rewrite README with explicit origin attribution to OpenMode.

Completed markdown triage, consolidation into `CODEBASE.md`, README rewrite with attribution, and redundant-doc pruning.
Commits: 8562850, 7c72e70, b219a2b, d02f486

### Feature 006: OpenCode Server Mode API Refresh and Documentation Update
Description: Align the client and internal API docs with the latest OpenCode Server Mode endpoints/schemas and close compatibility gaps.

Completed Server Mode compatibility refresh, schema-aligned models/use cases, and live validation against target server.
Commits: e994f39, bbadbe4, 78acc18, ad6470c

### Feature 007: Cross-Platform Desktop Enablement and Responsive UX
Description: Expand project target platforms beyond mobile and deliver a true cross experience for desktop/web/mobile with adaptive layouts and desktop-native interactions. (Visit file ROADMAP.feat007.md for full research details)

- [x] 7.01 Add desktop platforms (Windows/macOS/Linux) to Flutter project - Enabled desktop flags and generated `linux/`, `macos/`, `windows/` via Flutter tooling
- [x] 7.02 Implement responsive layout breakpoints (mobile drawer vs desktop split view) - `ChatPage` now adapts with mobile drawer (`<840`), split desktop (`>=840`), and large-desktop utility panel (`>=1200`)
- [x] 7.03 Add desktop input ergonomics (shortcuts, hover/focus polish, resize behavior) - Added `Ctrl/Cmd+N`, `Ctrl/Cmd+R`, `Ctrl/Cmd+L`, `Esc`; external input focus control; desktop hover/cursor polish in session list
- [/] 7.04 Validate build/run on each target and document platform-specific caveats - Linux/web validation passed (`flutter test`, `flutter build linux`, `flutter build web`, Linux runtime smoke). Blocked for full target matrix by host OS constraint (`flutter build windows` requires Windows host, `flutter build macos` requires macOS host)

### Feature 008: Manual QA Campaign and Stability Hardening
Description: Execute a structured manual test campaign across supported platforms and critical user journeys, then fix high-impact defects before automation is expanded.

Completed QA matrix execution, fixed P1 defects, and published release-readiness artifacts.
Commits: da2940b, cc5c78f

### Feature 009: Automated Test Suite and CI Quality Gates
Description: Build comprehensive automated tests (unit, widget, integration) and enforce quality gates in CI so future changes remain stable.

Completed baseline unit/widget/integration coverage, CI quality gates, coverage thresholds, and SSE race-condition stabilization.
Commits: 5125edd

### Feature 010: OpenCode Upstream Parity Baseline and Contract Freeze
Description: Consolidate the latest OpenCode Server/API/Desktop/Web behavior into a single compatibility contract for CodeWalk implementation planning.

Completed upstream parity contract freeze, Required/Optional scope matrix, and persisted-state migration strategy.

### Feature 011: Multi-Server Management and Health Orchestration
Description: Implement first-class support for multiple OpenCode servers (desktop/mobile parity), including active/default server routing and health-aware switching.

Completed multi-server profile orchestration with scoped persistence and switching coverage across unit/widget/integration tests.

### Feature 012: Model/Provider Switching and Variant (Reasoning Effort) Controls
Description: Bring model control parity with OpenCode Desktop/Web, including current-model changes and model variant/reasoning-effort changes.

Completed provider/model selector, variant handling and payload parity, plus scoped model-history persistence and tests.

### Feature 013: Event Stream and Message-Part Parity (Messages, Thinking, Tools, Questions, Permissions)
Description: Expand real-time event handling to match OpenCode v2 event/part taxonomy and reliably render message lifecycle details.

Completed resilient SSE/reducer parity, expanded part rendering, permission/question interactions, send-path fixes, and fallback/watchdog stabilization.

### Feature 014: Advanced Session Lifecycle Management
Description: Upgrade session operations beyond basic CRUD to parity-level management for active and historical work.

Completed rename/archive/share/unshare/delete/fork/status/todo/diff flows with optimistic updates, reconciliation, and lifecycle test coverage.

### Feature 015: Project/Workspace Context Parity
Description: Support multi-project and workspace/worktree workflows using directory-aware API/event orchestration.

Completed directory-scoped context orchestration, project/worktree UX, global event sync, and context-isolation test coverage.

### Feature 016: Reliability Hardening, QA, and Release Readiness for Parity Wave
Description: Validate and harden all parity features with measurable quality gates before production rollout.

Completed parity hardening, QA matrix validation, release docs updates, and chat-composer enhancements (attachments/voice/progress/selectors/settings refinements).
Commits: d568f22, 47ecddb, 3081b2e, b65f7f6, afb63be

### Feature 017: Realtime-First Refreshless UX
Description: Remove manual refresh interactions and keep UI state continuously updated through SSE-driven sync with lifecycle-aware efficiency controls.

Completed SSE-first refreshless orchestration with lifecycle-aware fallback polling and validated no-manual-refresh behavior.
Commits: f190e02

### Feature 018: Prompt Power Features Parity (`@`, `!`, `/`)
Description: Replicar no composer os gatilhos de produtividade do OpenCode Web: menção de arquivos/agentes com `@`, modo shell com `!` no início, e catálogo de comandos por `/` no começo do input.
Status: [x] Concluída

Concluída a paridade de `@`/`!`/`/` com navegação por teclado, shell payload dedicado e estabilização UX mobile/desktop do painel de sugestões.
Commits: e97544b, 094057a, 8be2d81, ef0a1e7, 53da769, 7ff7b71, 6d0ebe8, dfbda1b

### Feature 019: File Explorer and Viewer Parity
Description: Entregar navegação completa de arquivos com ícones, busca rápida, abertura em abas e visualização de conteúdo diretamente na UI, alinhado ao OpenCode Web.

Concluída a paridade de árvore/quick-open/viewer com integração de `/file`, `/find/file`, `/file/content`, estado de abas e cobertura automatizada.

### Feature 020: Agent Selector in Composer (Model/Thinking Bar)
Description: Incluir seletor explícito de agente (Build, Plan e demais permitidos) ao lado de provider/model e thinking, com persistência por contexto e integração de envio.

Concluída a entrega do seletor de agente com persistência por escopo, payload de prompt (`agent`), atalhos e cobertura de testes.
Commits: bf20bde, c75df1d

### Feature 021: Session Title Visibility and Quick Rename Parity
Description: Melhorar a UX de sessão para sempre exibir título de conversa de forma clara e permitir renomeação rápida/inline sem fricção.

Concluída a exibição consistente de título da sessão ativa com rename inline otimista, rollback e cobertura automatizada.

### Feature 022: Settings Parity (Notifications, Sounds, Shortcuts)
Description: Expandir configurações para incluir notificações e sons por categoria (agente/permissões/erros) e uma tela dedicada de atalhos com busca e detecção de conflito.

Concluída a paridade de Settings com notificações/som por categoria, atalhos pesquisáveis com conflito, deep-link de notificação e refinamentos UX.

### Feature 023: Critical Code Issues Resolution (2026-02-11)
Description: Corrigir problemas críticos de código identificados via análise estática e padrões, focando em APIs deprecated e anti-patterns que afetam compatibilidade e maintainability.

Concluída a remoção dos problemas-alvo de deprecação/compatibilidade, com validação por `flutter analyze`, testes completos e build Android.

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

- [ ] No desktop, pesquisar como usar microfone speech-to-text no linux. Pesquisar também se a API atual já funciona no mac/windows/iOS
- [ ] Manter o modelo selecionado sincronizado, atualmente o modelo selecionado no desktop, não é o mesmo selecionado no app mobile, o servidor backend deve passar essa informação
- [ ] Opções em Settings para decidir se app fica em background. Mobile: persistente notification, desktop: tray
- [ ] Ajustar popover de sugestões no Android para nunca cobrir o input com teclado aberto em todos os teclades/dispositivos (validar em device real com Gboard e Samsung Keyboard)
- [x] Aplicar ícones de app para Linux (GNOME/Freedesktop) e alinhar equivalentes para os demais OS (Windows/macOS)
- [ ] Emular `opencode serve` internamente como opção de servidor local (permitir ao CodeWalk iniciar e gerenciar um servidor OpenCode embutido sem depender de instância externa)
- [ ] Fazer atalhos de teclado funcionarem de verdade
- [ ] Exibir seção `Shortcuts` no mobile quando houver teclado físico conectado
- [x] A tool apply_patch deve ter cores apropriadas para linhas removidas (vermelho) e linhas adicionadas (verde)
- [ ] Verificar atualizações baseadas nos releases do GitHub usando a API pública do GitHub
- [ ] Inserir botão de fácil acesso para exibir/ocultar o Thinking (toggle rápido no header da mensagem ou área do composer)
- [ ] Adicionar opção em Settings para escolher densidade de todos os elementos do app (denso, normal, espaçoso)
- [ ] Refresh providers/model em background de forma assíncrona ao abrir o app
- [ ] Adicionar instruções básicas de como instalar e executar um servidor OpenCode na tela de adicionar servidor
- [ ] Limitar altura ao expandir conteúdo de uma tool call
- [ ] Personalizar título das tool calls mais comuns, e tratar respostas para aparência mais suave visando UX
- [ ] Condensar as chamas de tool calls em um collapsable quando a resposta final do assistente chegar
