# Feature 020 - Agent Selector in Composer (Model/Thinking Bar)

## Goal
Adicionar seletor explícito de agente no composer, ao lado de provider/model e thinking, com comportamento equivalente ao OpenCode Web.

## Why This Exists

Mesmo com seleção de provider/model/variant já implementada no CodeWalk, o usuário não consegue escolher rapidamente o agente principal (Build, Plan etc.) no mesmo ponto de decisão do envio. Isso reduz previsibilidade do resultado e quebra paridade com o fluxo web.

## Research Snapshot

- Data da pesquisa: 2026-02-10.
- Upstream analisado: `sst/opencode` commit `2c5760742bce473f215081d99afe9b3185af7b3a`.
- Servidor validado: `http://100.68.105.54:4096`.

## Upstream Evidence (Web)

### 1. Agent selector no composer

- `packages/app/src/components/prompt-input.tsx`
  - exibe `Select` de agente antes do seletor de modelo.
  - integra atalhos/comandos (`command.agent.cycle`).

### 2. Comandos de agente no catálogo

- `packages/app/src/pages/session/use-session-commands.tsx`
  - comandos `agent.cycle` e `agent.cycle.reverse`.
  - slash trigger `agent`.

### 3. UX assume seleção de agente + modelo

- `packages/app/src/components/prompt-input/submit.ts`
  - toast de validação quando agente/modelo não estão prontos (`modelAgentRequired`).
- `packages/app/src/i18n/br.ts`
  - strings explícitas para “Selecione um agente e modelo”.

## Live Server Verification (100.68.105.54:4096)

- `GET /agent` disponível (operationId `app.agents`).
- payload real retorna agentes com campos:
  - `name`
  - `mode` (`primary`, `subagent`, `all`)
  - `hidden`
  - `native`
- schema `Agent` no OpenAPI confirma metadados para filtragem e UI.

## Current CodeWalk Gap (Flutter)

- `lib/presentation/pages/chat_page.dart` possui chips de modelo e variant, mas não inclui seletor de agente.
- envio já suporta estrutura de payload com `agent/mode` no domínio de sessão, porém não há controle explícito no composer para o usuário.

## Scope

### In scope

- seletor de agente visível no composer junto de model/thinking.
- persistência por escopo (`server + directory`).
- fallback robusto quando agente indisponível.
- integração com envio e atalhos básicos.

### Out of scope

- editor avançado de configuração de agentes (ficará para features futuras de settings).

## Implementation Plan

### Phase A - Data contract and filtering

1. Carregar agentes via endpoint dedicado.
2. Definir regra de visibilidade:
   - excluir `hidden` por padrão,
   - priorizar `mode=primary` na UI principal,
   - manter compatibilidade para `mode=all`.
3. Definir ordenação estável (ex.: `build`, `plan`, demais alfabéticos).

### Phase B - Composer UI integration

1. Inserir chip/select de agente à esquerda de model/thinking.
2. Layout responsivo para mobile (evitar overflow).
3. Estados de loading/empty/error do seletor.

### Phase C - Persistence and payload

1. Persistir `selectedAgent` por contexto.
2. Restaurar seleção ao trocar projeto/servidor.
3. Garantir que envio use agente selecionado (ou fallback seguro).

### Phase D - Commands and accessibility

1. Adicionar ciclo de agente por ação rápida/atalho.
2. Semântica acessível (tooltip/aria/labels no Flutter semantics).
3. Logging mínimo para diagnóstico de seleção inválida.

### Phase E - Hardening

1. validar comportamento quando agente desaparece após reload.
2. sincronizar UI com sessão ativa sem refresh manual.

## Test Strategy

### Unit

- filtro de agentes (`hidden`, `mode`).
- persistência/restauração por contexto.
- fallback de seleção inválida.

### Widget

- render do seletor em mobile/desktop.
- mudança de agente refletindo estado visual.
- convivência sem regressão com modelo/variant.

### Integration

- `/agent` -> seleção -> envio de mensagem com agente esperado.
- troca de projeto mantém seleção isolada.

## Risks and Mitigations

1. Risco: lista de agentes mudar dinamicamente no servidor.
   - Mitigação: fallback automático para agente padrão válido.

2. Risco: overflow visual no composer em telas pequenas.
   - Mitigação: usar chips compactos e truncamento com tooltip.

3. Risco: divergência entre agente persistido e sessão atual.
   - Mitigação: validação a cada bootstrap de contexto.

## Definition of Done

- seletor de agente aparece no composer ao lado de model/thinking.
- escolha persiste e é restaurada por contexto.
- envio considera agente selecionado sem regressão de modelo/variant.
- testes cobrindo seleção, persistência e fallback.

## Source Links

- Upstream repo snapshot:
  - https://github.com/sst/opencode/tree/2c5760742bce473f215081d99afe9b3185af7b3a
- Evidências principais:
  - https://github.com/sst/opencode/blob/2c5760742bce473f215081d99afe9b3185af7b3a/packages/app/src/components/prompt-input.tsx
  - https://github.com/sst/opencode/blob/2c5760742bce473f215081d99afe9b3185af7b3a/packages/app/src/pages/session/use-session-commands.tsx
  - https://github.com/sst/opencode/blob/2c5760742bce473f215081d99afe9b3185af7b3a/packages/app/src/components/prompt-input/submit.ts
  - https://github.com/sst/opencode/blob/2c5760742bce473f215081d99afe9b3185af7b3a/packages/app/src/i18n/br.ts
- Server/OpenAPI (validado):
  - http://100.68.105.54:4096/doc
