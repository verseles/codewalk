# Feature 022 - Settings Parity (Notifications, Sounds, Shortcuts)

## Goal
Entregar paridade de configurações com foco em:

1. notificações do sistema por categoria (agente, permissões, erros),
2. sons por categoria (agente, permissões, erros),
3. tela dedicada de atalhos com grupos, busca e resolução de conflitos.

## Why This Exists

O app atual tem página de settings orientada principalmente a servidor. Faltam controles de experiência contínua que existem no OpenCode Web e são centrais para operação diária (atenção do usuário, feedback sonoro e produtividade por atalhos).

## Research Snapshot

- Data da pesquisa: 2026-02-10.
- Upstream analisado: `sst/opencode` commit `2c5760742bce473f215081d99afe9b3185af7b3a`.
- Servidor validado: `http://100.68.105.54:4096`.

## Upstream Evidence (Web)

### 1. Notificações por categoria

- `packages/app/src/components/settings-general.tsx`
  - toggles para:
    - `settings-notifications-agent`
    - `settings-notifications-permissions`
    - `settings-notifications-errors`
- `packages/app/e2e/settings/settings.spec.ts`
  - valida persistência dessas opções em storage.

### 2. Sons por categoria

- `packages/app/src/components/settings-general.tsx`
  - selects para:
    - `settings-sounds-agent`
    - `settings-sounds-permissions`
    - `settings-sounds-errors`
  - preview de áudio (`playDemoSound`) ao destacar/selecionar.

### 3. Tela de atalhos extensa

- `packages/app/src/components/dialog-settings.tsx`
  - aba dedicada `Shortcuts`.
- `packages/app/src/components/settings-keybinds.tsx`
  - agrupamento por domínio (`General`, `Session`, `Navigation`, `Model and agent`, `Terminal`, `Prompt`).
  - busca fuzzy (`fuzzysort`).
  - reset global.
  - detecção de conflito de keybind.
- `packages/app/e2e/settings/settings-keybinds.spec.ts`
  - suíte ampla cobrindo edição/reset/clear de atalhos.

### 4. Strings BR alinhadas ao pedido do usuário

- `packages/app/src/i18n/br.ts`
  - possui exatamente as frases solicitadas para notificações e sons.

## Live Server Verification (100.68.105.54:4096)

- OpenAPI inclui bloco de `config` (`/config`, `/global/config`) apto para persistir preferências do cliente quando necessário.
- endpoints de eventos (`/event`, `/global/event`) já disponíveis para gatilhar notificações/sons quando estados relevantes ocorrerem.

## Current CodeWalk Gap (Flutter)

- `lib/presentation/pages/server_settings_page.dart` é centrada em gerenciamento de servidores.
- não existem toggles de notificação por categoria.
- não existe matriz de sons por categoria.
- não existe tela dedicada para gerenciamento completo de atalhos com busca/conflito.

## Scope

### In scope

- settings de UX operacional (notificações, sons, atalhos).
- persistência local e, quando necessário, sincronização com escopo ativo.
- feedback sonoro/notificação conectado aos eventos já tratados no app.

### Out of scope

- reimplementar todas as abas de settings do upstream de uma vez.
- engine de automação avançada de keymap além do necessário para paridade inicial.

## Implementation Plan

### Phase A - Settings architecture

1. Criar módulo de preferências de experiência (notifications/sounds/shortcuts).
2. Definir storage versionado e migração de estado legado.
3. Isolar chaves por escopo quando houver impacto de contexto.

### Phase B - Notifications

1. Implementar toggles:
   - agente completo/atenção,
   - permissão necessária,
   - erro.
2. Integrar com canal de notificações do sistema por plataforma.
3. Aplicar fallback silencioso quando permissão de notificação não estiver disponível.

### Phase C - Sounds

1. Implementar seleção de som por categoria.
2. Adicionar preview controlado (anti-spam áudio).
3. Tratar indisponibilidade de áudio (web/autoplay/mobile restrictions).

### Phase D - Shortcuts center

1. Tela dedicada com grupos de atalhos.
2. Busca fuzzy por nome/comando/keybind.
3. Edição interativa de teclas, limpeza, reset global.
4. Detecção e bloqueio de conflitos de binding.

### Phase E - Event integration and observability

1. Acionar notificação/som em eventos relevantes já consumidos.
2. Registrar logs mínimos para diagnósticos (permissão negada, conflito, áudio indisponível).

## Test Strategy

### Unit

- serialização/migração de settings.
- detecção de conflitos de keybind.
- seleção/normalização de sounds por categoria.

### Widget

- toggles de notificação e selects de sons.
- busca/edição/reset na tela de atalhos.

### Integration

- persistência após restart.
- disparo correto de notificação/som com eventos simulados.
- cenário de permissão negada sem crash.

## Risks and Mitigations

1. Risco: diferenças de plataforma para notificações/som.
   - Mitigação: camada adapter por plataforma + fallback previsível.

2. Risco: conflitos de atalhos quebrarem usabilidade.
   - Mitigação: validação pré-save + mensagens explícitas.

3. Risco: excesso de complexidade em primeira entrega.
   - Mitigação: rollout incremental por bloco (notifications -> sounds -> shortcuts).

## Definition of Done

- usuário configura notificações e sons por categoria.
- tela de atalhos permite busca, edição e reset com verificação de conflito.
- preferências persistem corretamente e reagem aos eventos de sessão.
- testes cobrem fluxos críticos de configuração e persistência.

## Source Links

- Upstream repo snapshot:
  - https://github.com/sst/opencode/tree/2c5760742bce473f215081d99afe9b3185af7b3a
- Evidências principais:
  - https://github.com/sst/opencode/blob/2c5760742bce473f215081d99afe9b3185af7b3a/packages/app/src/components/settings-general.tsx
  - https://github.com/sst/opencode/blob/2c5760742bce473f215081d99afe9b3185af7b3a/packages/app/src/components/settings-keybinds.tsx
  - https://github.com/sst/opencode/blob/2c5760742bce473f215081d99afe9b3185af7b3a/packages/app/src/components/dialog-settings.tsx
  - https://github.com/sst/opencode/blob/2c5760742bce473f215081d99afe9b3185af7b3a/packages/app/src/i18n/br.ts
  - https://github.com/sst/opencode/blob/2c5760742bce473f215081d99afe9b3185af7b3a/packages/app/e2e/settings/settings.spec.ts
  - https://github.com/sst/opencode/blob/2c5760742bce473f215081d99afe9b3185af7b3a/packages/app/e2e/settings/settings-keybinds.spec.ts
- Server/OpenAPI (validado):
  - http://100.68.105.54:4096/doc
