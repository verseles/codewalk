# Feature 017 - Realtime-First Refreshless UX

## Goal
Eliminar a necessidade de botões de refresh manuais no app, adotando atualização contínua e eficiente com SSE (Server-Sent Events), com fallback controlado apenas quando necessário.

## Why This Exists

Hoje o app já consome streams de evento, mas ainda mantém affordances de refresh manual e alguns caminhos de atualização por recarga ampla. O objetivo desta feature é migrar para um modelo "event-first", reduzindo latência percebida e evitando uso excessivo de rede/bateria.

## Research Snapshot

- Data da pesquisa prática: 2026-02-10.
- Ambiente validado: servidor `http://100.68.105.54:4096`.
- Versão do servidor retornada por health check: `1.1.53`.
- SDK oficial analisado: `@opencode-ai/sdk@1.1.53`.

## Live Server Verification (Evidence)

### 1. Health endpoint

- `GET /global/health` respondeu `200` com payload:
  - `{"healthy":true,"version":"1.1.53"}`

### 2. Event streams

- `GET /event` respondeu:
  - `HTTP/1.1 200 OK`
  - `Content-Type: text/event-stream`
  - Evento inicial observado:
    - `data: {"type":"server.connected","properties":{}}`

- `GET /global/event` respondeu:
  - `HTTP/1.1 200 OK`
  - `Content-Type: text/event-stream`
  - Evento inicial observado:
    - `data: {"payload":{"type":"server.connected","properties":{}}}`

### 3. WebSocket scope

- OpenAPI exposto em `/doc` declara `"/pty/{ptyID}/connect"` com descrição de conexão WebSocket para PTY.
- Teste HTTP de upgrade para PTY sem sessão válida retornou erro de sessão não encontrada (o que confirma endpoint específico de PTY, não canal geral de atualização de chat/listas).

## Primary Source Findings

### OpenAPI do servidor (`/doc`)

- `/event` e `/global/event` estão tipados como `text/event-stream`.
- `"/pty/{ptyID}/connect"` é descrito como WebSocket para interação de terminal.

### SDK oficial `@opencode-ai/sdk@1.1.53`

- `Global.event()` usa `client.sse.get({ url: "/global/event" })`.
- `Event.subscribe()` usa `client.sse.get({ url: "/event" })`.
- Implementação de SSE do core inclui:
  - reconexão automática,
  - `Last-Event-ID`,
  - retry delay ajustável por `retry:`,
  - backoff exponencial com limite.

Conclusão técnica: atualização contínua do produto deve ser SSE-first; WebSocket não é o transporte principal para sincronização geral de UI.

## External Best Practices (Web Research)

1. MDN EventSource/SSE:
   - SSE é apropriado para push unidirecional servidor -> cliente.
   - O cliente deve tratar reconexão automaticamente.
2. Flutter app lifecycle:
   - Streams long-lived devem respeitar foreground/background para eficiência.
3. Android power/network guidance:
   - Evitar polling agressivo frequente; preferir trabalho orientado a evento e sincronização em janelas oportunas.

## Scope

### In scope

- Remover refresh manual da experiência principal de chat/contexto.
- Tornar streams SSE o mecanismo principal de atualização.
- Atualização incremental por evento (sem recarregar tudo sempre).
- Fallback por degradação de stream (não por padrão).
- Observabilidade para saúde da sincronização.

### Out of scope

- Reescrever protocolo do servidor.
- Migrar canais de PTY para a mesma camada de sync de chat/contexto.
- Introduzir WebSocket para estados que já são cobertos por SSE.

## Architecture Plan

### 1. Realtime data flow contract

- Manter duas assinaturas em foreground:
  - `/event?directory=<activeDirectory>`
  - `/global/event`
- Aplicar reducer de eventos para atualizar:
  - sessões,
  - mensagens,
  - status,
  - invalidação de contexto projeto/worktree.

### 2. Incremental updates over full reloads

- Substituir chamadas amplas de refresh por:
  - `upsert` local por ID,
  - invalidação seletiva por `contextKey`,
  - fetch pontual de detalhes somente quando necessário.

### 3. Lifecycle-aware subscriptions

- Foreground: streams ativos.
- Background: cancelar streams long-lived.
- Resume: reabrir streams + sincronização única curta para reconciliação.

### 4. Degraded mode

- Somente quando stream cair/reconectar repetidamente:
  - iniciar polling escopo-restrito com intervalo alto (20-60s),
  - encerrar polling ao restabelecer SSE saudável.
- Não usar polling de 1 segundo.

### 5. UX and controls

- Remover botão de refresh manual onde a atualização é automática.
- Exibir indicador discreto de estado de conexão:
  - `Connected`,
  - `Reconnecting`,
  - `Sync delayed`.

## Action Plan (Execution Phases)

### Phase A - Contract and reducer hardening

1. Inventariar eventos usados por tela/estado.
2. Garantir que cada evento tenha handler incremental.
3. Cobrir lacunas com fetch pontual mínimo.

### Phase B - Remove manual refresh dependencies

1. Refatorar pontos que chamam refresh amplo.
2. Trocar por mutate local + invalidação seletiva.
3. Confirmar paridade de comportamento.

### Phase C - Lifecycle and fallback policy

1. Implementar política foreground/background.
2. Implementar degraded mode com polling lento e temporário.
3. Registrar métricas de entrada/saída em degraded mode.

### Phase D - UX cleanup

1. Remover botões de refresh de chat/contexto.
2. Inserir status de sync.
3. Ajustar copy e estados vazios/erro.

### Phase E - Validation and rollout

1. Testes unitários para reducer + lifecycle.
2. Testes widget/integration para auto-update sem refresh manual.
3. Rollout controlado por feature flag com fallback rápido.

## Test Strategy

### Unit

- Reducer por tipo de evento.
- Reconciliação de contexto por `directory`.
- Transições de estado de conectividade.

### Widget

- UI atualiza automaticamente ao receber evento simulado.
- Botões de refresh ausentes nos fluxos cobertos.
- Estado visual de reconnect/degraded.

### Integration

- SSE conecta, recebe eventos, reconecta.
- App em resume sincroniza corretamente sem ação manual.
- Degraded mode entra/sai conforme saúde do stream.

## Observability and KPIs

1. `event_stream_connected` / `event_stream_reconnecting`.
2. Tempo médio para refletir mudança na UI após evento.
3. Taxa de fallback para polling.
4. Número de refresh manuais acionados (meta: zero nos fluxos cobertos).
5. Consumo de rede e impacto de bateria em sessão longa.

## Risks and Mitigations

1. Risco: evento perdido em reconexão.
   - Mitigação: `Last-Event-ID` + sync pontual pós-resume/reconnect.

2. Risco: atualização fora de ordem.
   - Mitigação: merge por timestamp/versão e idempotência em reducers.

3. Risco: degradar bateria em rede ruim.
   - Mitigação: polling somente em degradado, intervalos longos, cancelamento em background.

4. Risco: remoção de refresh antes de atingir estabilidade.
   - Mitigação: feature flag + rollout progressivo + rollback imediato.

## Definition of Done

- Botões de refresh removidos dos fluxos de chat/contexto alvo.
- Atualização automática confiável por SSE em foreground.
- Fallback de polling apenas em degradado e controlado.
- Testes automatizados cobrindo reconnect, resume e degradação.
- Métricas e logs suficientes para operação e diagnóstico.

## Source Links

- OpenAPI local do servidor (validado): `http://100.68.105.54:4096/doc`
- SDK oficial (v2):
  - https://unpkg.com/@opencode-ai/sdk@1.1.53/dist/v2/gen/sdk.gen.js
  - https://unpkg.com/@opencode-ai/sdk@1.1.53/dist/v2/gen/core/serverSentEvents.gen.js
  - https://unpkg.com/@opencode-ai/sdk@1.1.53/dist/v2/gen/types.gen.d.ts
- OpenCode docs:
  - https://opencode.ai/docs/server/
  - https://opencode.ai/docs/sdk/javascript
- SSE reference:
  - https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events
- Flutter lifecycle:
  - https://docs.flutter.dev/get-started/flutter-for/android-devs#how-do-i-listen-to-android-activity-lifecycle-events
- Android background/network efficiency:
  - https://developer.android.com/develop/background-work/background-tasks/optimize-battery

