# Feature 018 - Prompt Power Features Parity (`@`, `!`, `/`)

## Goal
Trazer para o composer do CodeWalk os gatilhos de produtividade do OpenCode Web:

1. `@` para mencionar arquivos/agentes durante a digitação.
2. `!` no início do input para entrar em modo shell.
3. `/` no início do input para abrir catálogo de comandos (builtin + custom/skill/MCP).

## Why This Exists

No app atual, o input suporta texto/attachments/voz, mas não possui a gramática de prompt que acelera o fluxo avançado no OpenCode Web. Isso bloqueia casos de uso centrais (referenciar arquivo em contexto, executar shell rápido, acionar comandos de sessão sem sair do input).

## Research Snapshot

- Data da pesquisa: 2026-02-10.
- Upstream analisado: `sst/opencode` commit `2c5760742bce473f215081d99afe9b3185af7b3a`.
- Servidor validado: `http://100.68.105.54:4096`.

## Upstream Evidence (Web)

### 1. `@` mention com pill/token e navegação por teclado

- `packages/app/e2e/prompt/prompt-mention.spec.ts`
  - teste cobre `@<path>`, sugestão visível e inserção de pill (`[data-type="file"]`).
- `packages/app/src/components/prompt-input.tsx`
  - `handleInput` detecta `@` no cursor (`/@(\S*)$/`) e abre popover.
  - inserção converte seleção em parte estruturada (`file` ou `agent`).
- `packages/app/src/utils/prompt.ts`
  - parse/restore de partes com suporte a `value` iniciando por `@`.

### 2. `!` no começo ativa modo shell

- `packages/app/src/components/prompt-input.tsx`
  - em `keydown`, `!` na posição inicial muda `mode` para `shell`.
  - `Esc` e `Backspace` em input vazio saem do modo shell.
- `packages/app/src/components/prompt-input/submit.ts`
  - submit em shell usa rota dedicada de shell.

### 3. `/` no começo abre catálogo slash

- `packages/app/e2e/prompt/prompt-slash-open.spec.ts`
  - `/open` exibe comando `file.open` e abre diálogo.
- `packages/app/src/components/prompt-input.tsx`
  - detecta `^/(\S*)$` e ativa popover slash.
  - mistura comandos builtin (`command.options`) com comandos custom (`sync.data.command`).
- `packages/app/src/components/prompt-input/slash-popover.tsx`
  - badges por origem (`skill`, `mcp`, `custom`) e keybind no item.

### 4. Slash inclui comandos de skill/MCP/opencode

- `packages/app/src/context/global-sync/bootstrap.ts`
  - bootstrap chama `sdk.command.list()` para popular comandos dinâmicos.
- `packages/app/src/context/command.tsx`
  - `CommandOption` inclui `slash`, `source` e trigger por origem `slash`.

## Live Server Verification (100.68.105.54:4096)

- `GET /command` disponível e tipado no OpenAPI.
- Payload real validado contém `source` com valores como:
  - `command`
  - `skill`
- Schema `Command.source` também prevê `mcp`.
- `GET /agent` disponível e retorna lista de agentes com `mode` e `hidden`.
- Rotas relevantes no OpenAPI:
  - `/command`
  - `/agent`
  - `/session/{sessionID}/shell`
  - `/session/{sessionID}/command`

## Current CodeWalk Gap (Flutter)

- `lib/presentation/widgets/chat_input_widget.dart`
  - input multiline sem tokenizer de partes `@`.
  - sem modo shell (`!`) e sem slash popover (`/`).
- envio hoje é majoritariamente texto + attachments, sem camada de comandos inline no composer.

## Scope

### In scope

- tokenizer/parsing de prompt para `@` + slash.
- modo shell com estado visual e histórico separado.
- popover de slash com comandos builtin e dinâmicos do servidor.
- integração com payload de envio e rotas corretas.

### Out of scope

- implementar terminal completo/PTY no composer.
- reescrever pipeline de attachments já entregue.

## Implementation Plan

### Phase A - Prompt grammar engine

1. Introduzir estado de composer:
   - `mode: normal | shell`
   - `popover: none | mention | slash`
2. Criar parser incremental para:
   - detectar `@` no cursor (não apenas no início da linha)
   - detectar `/` apenas quando o conteúdo aplicável começa com slash
3. Definir modelo interno para menções:
   - `FileMentionPart`
   - `AgentMentionPart`

### Phase B - `@` mention UX

1. Fonte de arquivos via `/find/file` (scoped por `directory`).
2. Fonte de agentes via `/agent` (filtrando hidden conforme regra de UX).
3. Inserção de pill/token preservando cursor e edição subsequente.
4. Suporte teclado: `ArrowUp/Down`, `Tab`, `Enter`, `Esc`.

### Phase C - shell mode (`!`)

1. `!` no offset 0 troca para `shell`.
2. Placeholder e estilo visual dedicados ao modo shell.
3. Submit em shell encaminha para endpoint de shell da sessão.
4. Histórico separado (normal vs shell).

### Phase D - slash command (`/`)

1. Comandos builtin do app (new/open/model/agent/mcp/etc).
2. Comandos dinâmicos de `/command` com badges por `source`.
3. Seleção de comando:
   - builtin: dispara ação direta.
   - custom/skill/mcp: preenche prefixo `/<cmd> ` no input para edição antes do envio.

### Phase E - hardening

1. idempotência de popover ao alternar foco/composição IME.
2. fallback para empty-state e falha de rede.
3. métricas simples de uso por trigger.

## Test Strategy

### Unit

- parser de gatilhos (`@`, `/`, `!`) por posição de cursor.
- transições `normal <-> shell`.
- mapping de comandos por origem (`command|skill|mcp`).

### Widget

- popover `@` abre/fecha corretamente e insere token.
- `!` no início ativa shell e `Esc` retorna ao normal.
- slash lista comandos e dispara ação esperada.

### Integration

- menção de arquivo real via backend.
- execução shell em sessão real e resposta tratada.
- slash custom vindo de `/command` preenchendo input e enviando com sucesso.

## Risks and Mitigations

1. Risco: conflito com IME/teclado mobile.
   - Mitigação: isolar handlers de Enter/Tab/Esc e manter testes em Android.

2. Risco: ambiguidade entre texto literal e token de menção.
   - Mitigação: representação explícita de partes no estado do composer.

3. Risco: catálogo slash muito grande degradar UX.
   - Mitigação: debounce + limite de itens + ranking por prefixo.

## Definition of Done

- `@`, `!`, `/` funcionam no composer com comportamento consistente.
- comandos custom/skill/MCP visíveis no slash quando servidor suportar.
- modo shell operacional com rota dedicada e feedback de erro.
- testes unit/widget/integration cobrindo fluxos críticos.

## Source Links

- Upstream repo snapshot:
  - https://github.com/sst/opencode/tree/2c5760742bce473f215081d99afe9b3185af7b3a
- Evidências principais:
  - https://github.com/sst/opencode/blob/2c5760742bce473f215081d99afe9b3185af7b3a/packages/app/e2e/prompt/prompt-mention.spec.ts
  - https://github.com/sst/opencode/blob/2c5760742bce473f215081d99afe9b3185af7b3a/packages/app/e2e/prompt/prompt-slash-open.spec.ts
  - https://github.com/sst/opencode/blob/2c5760742bce473f215081d99afe9b3185af7b3a/packages/app/src/components/prompt-input.tsx
  - https://github.com/sst/opencode/blob/2c5760742bce473f215081d99afe9b3185af7b3a/packages/app/src/components/prompt-input/slash-popover.tsx
  - https://github.com/sst/opencode/blob/2c5760742bce473f215081d99afe9b3185af7b3a/packages/app/src/context/global-sync/bootstrap.ts
  - https://github.com/sst/opencode/blob/2c5760742bce473f215081d99afe9b3185af7b3a/packages/app/src/utils/prompt.ts
- Server/OpenAPI (validado):
  - http://100.68.105.54:4096/doc
- OpenCode docs:
  - https://opencode.ai/docs/agents
  - https://opencode.ai/docs/commands
