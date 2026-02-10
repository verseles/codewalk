# Feature 019 - File Explorer and Viewer Parity

## Goal
Implementar paridade de exploração de arquivos com o OpenCode Web:

1. árvore de arquivos com ícones e expansão por diretórios,
2. busca rápida/fuzzy para abrir arquivos,
3. leitura de conteúdo diretamente na UI em abas.

## Why This Exists

Atualmente o CodeWalk já suporta seleção de diretório/projeto e operações de workspace, mas não oferece um explorer de arquivos completo com leitura fluida dentro da própria interface de sessão.

## Research Snapshot

- Data da pesquisa: 2026-02-10.
- Upstream analisado: `sst/opencode` commit `2c5760742bce473f215081d99afe9b3185af7b3a`.
- Servidor validado: `http://100.68.105.54:4096`.

## Upstream Evidence (Web)

### 1. File viewer e abertura de arquivo via palette

- `packages/app/e2e/files/file-viewer.spec.ts`
  - abre arquivo real (`package.json`) e valida conteúdo renderizado.
- `packages/app/src/components/dialog-select-file.tsx`
  - diálogo central de busca/abertura com categorias e items de arquivo.

### 2. File tree navegável

- `packages/app/e2e/files/file-tree.spec.ts`
  - fluxo de expandir pastas e abrir arquivo na aba.
- `packages/app/src/components/file-tree.tsx`
  - componente de árvore com expansão/colapso e integração com tabs.

### 3. Busca fuzzy

- `packages/app/package.json` inclui dependência `fuzzysort`.
- `packages/app/src/components/dialog-select-directory.tsx` e `settings-keybinds.tsx`
  - evidenciam uso de fuzzy/ranking para encontrar itens rapidamente.
- `dialog-select-file.tsx`
  - usa `file.searchFiles(query)` e combina com sessões/comandos.

### 4. Camada de dados de arquivos e invalidação

- `packages/app/src/context/file.tsx`
  - operações de listar (`file.list`), ler (`file.read`) e buscar (`find.files`).
  - integra invalidação por watcher para manter dados atualizados.

## Live Server Verification (100.68.105.54:4096)

- `GET /file` disponível e retorna lista de `FileNode` (`file`/`directory`).
- `GET /file/content` disponível e retorna conteúdo (`text`/`binary`).
- `GET /find/file` disponível com `query`, `dirs`, `type`, `limit`.
- `GET /path` retorna `directory` ativo para escopo de exploração.

Observação de pesquisa: os endpoints suportam os blocos fundamentais para árvore + busca + viewer sem necessidade de rotas extras.

## Current CodeWalk Gap (Flutter)

- não existe painel dedicado de árvore de arquivos no chat principal.
- não existe busca rápida de arquivo estilo palette com abertura em abas.
- não existe viewer de conteúdo de arquivo integrado ao fluxo de conversa.

## Scope

### In scope

- painel/diálogo de exploração de arquivos com ícones por tipo.
- busca rápida com ranking e limite.
- abertura e visualização de arquivo dentro da UI.
- sincronização com contexto (`server + directory`).

### Out of scope

- editor completo de arquivos (esta feature é leitura/navegação).
- terminal/PTY embutido no mesmo escopo.

## Implementation Plan

### Phase A - Domain/Data foundation

1. Formalizar `FileNode`, `FileContent`, `FileTabState` no provider.
2. Encapsular chamadas:
   - `/file`
   - `/file/content`
   - `/find/file`
3. Definir cache + política de invalidação por contexto.

### Phase B - Explorer UI

1. Criar painel de árvore com expand/collapse lazy.
2. Exibir ícones por extensão/tipo (arquivo, pasta, binário, etc).
3. Permitir abrir arquivo via toque/click e manter seleção ativa.

### Phase C - Quick open / fuzzy

1. Criar diálogo de busca com foco em produtividade.
2. Ranking por prefixo + contains + fallback alfabético.
3. Atalhos para abrir resultado sem navegação manual na árvore.

### Phase D - File viewer

1. Render de texto com monoespaçada, seleção e scroll persistido.
2. Estado para binário/erro/arquivo vazio.
3. Estrutura de tabs para múltiplos arquivos abertos.

### Phase E - Sync + hardening

1. Invalidar apenas arquivos afetados por refresh/eventos.
2. Preservar tabs em troca de sessão quando escopo permitir.
3. Tratar falhas de rede com retry discreto.

## Test Strategy

### Unit

- normalização de caminho e cache keys por contexto.
- ranking da busca de arquivos.
- reducer de tabs (open/close/active).

### Widget

- expandir árvore e abrir arquivo.
- buscar e selecionar item no quick-open.
- render do viewer para texto/binário/erro.

### Integration

- `/file` + `/file/content` fim-a-fim com servidor real/mock.
- troca de projeto/directory não mistura árvore/tabs antigas.
- atualização incremental sem exigir refresh manual.

## Risks and Mitigations

1. Risco: diretórios grandes degradarem performance.
   - Mitigação: paginação/lazy list + debounce + limite no quick-open.

2. Risco: mistura de estado entre contextos.
   - Mitigação: chavear armazenamento por `serverId::directory`.

3. Risco: leitura de arquivo binário quebrar UI.
   - Mitigação: detectar tipo e usar fallback explícito.

## Definition of Done

- usuário consegue explorar árvore, buscar fuzzy e abrir arquivos sem sair da conversa.
- viewer renderiza conteúdo textual com estabilidade e fallback para binário.
- estados de tabs e árvore respeitam contexto atual.
- cobertura de testes para fluxos principais de navegação e leitura.

## Source Links

- Upstream repo snapshot:
  - https://github.com/sst/opencode/tree/2c5760742bce473f215081d99afe9b3185af7b3a
- Evidências principais:
  - https://github.com/sst/opencode/blob/2c5760742bce473f215081d99afe9b3185af7b3a/packages/app/e2e/files/file-viewer.spec.ts
  - https://github.com/sst/opencode/blob/2c5760742bce473f215081d99afe9b3185af7b3a/packages/app/e2e/files/file-tree.spec.ts
  - https://github.com/sst/opencode/blob/2c5760742bce473f215081d99afe9b3185af7b3a/packages/app/src/components/dialog-select-file.tsx
  - https://github.com/sst/opencode/blob/2c5760742bce473f215081d99afe9b3185af7b3a/packages/app/src/components/file-tree.tsx
  - https://github.com/sst/opencode/blob/2c5760742bce473f215081d99afe9b3185af7b3a/packages/app/src/context/file.tsx
- Server/OpenAPI (validado):
  - http://100.68.105.54:4096/doc
