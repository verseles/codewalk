# CodeWalk - Regras Específicas do Projeto

> ⚠️ **Base**: Todas as regras de `/home/helio/MEGA/CONFIG/AGENTS.md` se aplicam. Este arquivo contém apenas especificidades do CodeWalk.

## Contexto do Projeto

CodeWalk é um projeto que visa permitir acessar agents de código de qualquer lugar, seja por desktop, seja pelo celular.

- **Toda implementação deve ser pensada para mobile e desktop**. Preferencialmente de maneira unificada e responsiva. **Prioridade para UX no mobile**.

## 🚀 Fluxo Específico: Build Android

- **Após concluir modificações de código**: Execute `make precommit` **imediatamente** (pode ser em background).
- **Ordem crucial**: `make precommit` deve ser executado logo após conclusão do código, ANTES de alterar arquivos .md ou fazer commit.
- **Se apenas arquivos estáticos (.md, texto) mudaram**: Não é necessário `make precommit`.

### Caption Dinâmica no Upload

- No upload via `tdl` (feito em `make android` vindo de `make precommit`), o `--caption` deve ser **dinâmico e direto**.
- **Evite**: "Ajustes mais recentes feitos"
- **Prefira**: "Corrigida altura da caixa Thinking Process"

## 📦 Liberação de Nova Tag / Release

Quando solicitado "minor", "patch", ou "major":

1. Atualize arquivos relevantes com a nova versão
2. Atualize `CHANGELOG.md` com a nova versão e data. Liste o título dos commits desde a última tag.
3. Faça push
4. Adicione a tag no git
5. **Watch da pipeline de release** `@.github/workflows/release.yml`:
   - Verificar a cada 60s
   - A cada resultado, atualize o usuário com informações
   - **Se qualquer etapa falhar**: Cancele a pipeline por completo
     - Analise os erros e decida:
       - Corrigir sozinho e repetir o presente fluxo
       - Avisar o usuário e parar para aguardar instruções
