# Feature 021 - Session Title Visibility and Quick Rename Parity

## Goal
Melhorar a experiência de título de sessão para:

1. exibir sempre o título atual de forma clara,
2. permitir renomeação rápida (inline/menu),
3. reduzir ambiguidade de títulos automáticos no estilo `Today ...`.

## Why This Exists

O feedback do usuário indica que o app mostra títulos pouco úteis em vários pontos (ex.: `Today ...`) e dificulta o ajuste rápido do nome da conversa ativa. Isso impacta navegação e rastreabilidade de sessões.

## Research Snapshot

- Data da pesquisa: 2026-02-10.
- Upstream analisado: `sst/opencode` commit `2c5760742bce473f215081d99afe9b3185af7b3a`.
- Servidor validado: `http://100.68.105.54:4096`.

## Upstream Evidence (Web)

### 1. Header da sessão com título editável

- `packages/app/src/pages/session/message-timeline.tsx`
  - renderiza título no header (`h1`).
  - `double click` abre modo inline edit.
  - menu de opções inclui `Rename`.

### 2. Fluxo de edição e persistência

- `packages/app/src/pages/session.tsx`
  - controla estado `title.draft/editing/saving`.
  - `saveTitleEditor` chama `session.update({ title })`.
  - sincroniza lista local imediatamente após sucesso.

### 3. Contrato de API para rename

- OpenAPI: `/session/{sessionID}` `PATCH`
  - aceita `title` no corpo e retorna sessão atualizada.

## Live Server Verification (100.68.105.54:4096)

- `GET /session?directory=...` retorna sessões com títulos reais.
- foi observado na prática mistura de títulos descritivos e títulos automáticos (`Today HH:mm`).
- `PATCH /session/{sessionID}` está exposto para atualização de título.

## Current CodeWalk Gap (Flutter)

- existe rename via menu na lista (`ChatSessionList`), mas não há experiência inline robusta no contexto principal da conversa.
- exibição do título ainda não é consistente/central em todos os layouts.
- fallback temporal atual pode permanecer ambíguo por longos períodos.

## Scope

### In scope

- visibilidade forte do título da sessão ativa no fluxo principal.
- rename rápido com UX inline (ou equivalente de baixa fricção).
- sincronização imediata lista/header após rename.
- padronização de fallback para títulos automáticos.

### Out of scope

- geração automática de títulos por IA (sem ação do usuário).

## Implementation Plan

### Phase A - Display contract

1. Definir pontos oficiais de exibição do título (mobile/desktop).
2. Garantir truncamento correto + tooltip/expansão quando necessário.
3. Evitar duplicidade visual confusa entre cards/header.

### Phase B - Inline rename

1. Adicionar ação de rename no próprio header da conversa.
2. Suportar teclado (`Enter` salvar, `Esc` cancelar).
3. Estado otimista com rollback em falha de API.

### Phase C - Fallback title strategy

1. Revisar geração de fallback para manter contexto temporal claro.
2. Exibir formato absoluto quando o relativo ficar ambíguo.
3. Evitar `Today ...` como identificador único por longos períodos.

### Phase D - Sync and refreshless behavior

1. Atualizar header e lista sem refresh manual.
2. Integrar com event stream e reconciliar conflitos.

## Test Strategy

### Unit

- geração de fallback e formatação temporal.
- transições de estado do rename (idle/editing/saving/error).

### Widget

- render do título em layouts mobile/desktop.
- rename inline completo com salvar/cancelar.

### Integration

- update de título via API e refletido em lista + header.
- restauração de estado em troca de sessão/projeto.

## Risks and Mitigations

1. Risco: conflito entre update local e evento remoto.
   - Mitigação: merge por timestamp e priorização de update confirmado.

2. Risco: UX poluída por duplicidade de cabeçalho.
   - Mitigação: unificar área principal de título e simplificar cards redundantes.

3. Risco: fallback inconsistente por locale/timezone.
   - Mitigação: normalizar formatter com timezone/localização explícita.

## Definition of Done

- sessão ativa sempre exibe título claro nas telas principais.
- usuário consegue renomear rapidamente sem sair do contexto.
- fallback temporal é legível e não ambíguo.
- testes cobrem render, edição e sincronização.

## Source Links

- Upstream repo snapshot:
  - https://github.com/sst/opencode/tree/2c5760742bce473f215081d99afe9b3185af7b3a
- Evidências principais:
  - https://github.com/sst/opencode/blob/2c5760742bce473f215081d99afe9b3185af7b3a/packages/app/src/pages/session/message-timeline.tsx
  - https://github.com/sst/opencode/blob/2c5760742bce473f215081d99afe9b3185af7b3a/packages/app/src/pages/session.tsx
- Server/OpenAPI (validado):
  - http://100.68.105.54:4096/doc
