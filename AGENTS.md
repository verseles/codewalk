CodeWalk é um projeto que visa permitir acessar agents de código de qualquer lugar, seja por desktop, seja pelo celular.

- Toda implementação deve ser pensada para mobile e desktop. Preferencialmente de maneira unificada e responsiva. Prioridade para UX no mobile.

- Sempre que concluir uma tarefa, verifique se:
  - Essa mudança requer um novo test ou atualização de um existente

- Antes de seguir para uma outra tarefa, baseado na tarefa anterior:
  1. Execute `make precommit` e logo em seguida notifique o usuário usando play_notification
  2. Verifique se requer atualização em @./ADR.md ou sugerir criar uma nova
  3. Verifique se requer atualização em @./CODEBASE.md
  4. Verifique se @./ROADMAP.md precisa ser atualizado
  5. Faça commit descritivo: titulo + detalhes

Observe a ordem acima! make android deve ser executado logo após concluída as modificações de código. Pode inclusive ser chamada em background. Alterar arquivos md e fazer commit não são impedimentos para executar make android. Execute o mais rápido possível após conclusão da parte de código da tarefa.

- Sempre que concluir qualquer tarefa, execute `make precommit` para que o usuario teste no celular.
- No upload via `tdl` (feito em `make android` vindo de `make precommit`), o `--caption` deve ser dinâmico e direto, descrevendo objetivamente o que foi alterado na última task.
- Evite caption genérico como "Ajustes mais recentes feitos"; prefira algo como "Corrigida altura da caixa Thinking Process".
- Após concluir a tarefa é importante executar logo `make precommit` para que o usuario teste no celular para que as outras tarefas continuem enquanto o usuário já vai testando a implementação.
- Se sua tarefa mais recente envolveu apenas arquivos estáticos como texto/markdown não é necessário nem
`make android`, nem `make check` e nem `make precommit`.
- Se sua tarefa mais recente envolveu mudanças reais no código, rode `make precommit` para avaliar novos tests e enviar o apk diretamente para o celular do dev.
- Se ao realizar commit, você já tiver executado `make precommit`, não é necessário executar novamente. Se nada no código mudou desde a execução, não é necessário executar novamente. Resumindo, `make android` gera o apk e envia para o celular do dev, `make check` executa os testes, e `make precommit` executa os testes e envia o apk diretamente para o celular do dev. Avalie o melhor comando para sua situação.

## Liberação de nova tag / release
- Quando solicitado, "minor", "patch", ou "major":
  - atualize arquivos relevantes com a nova versão
  - atualize o arquivo CHANGELOG.md com a nova versão e data. Liste o título dos commits desde a última tag.
  - faça push
  - adicione a tag no git
    - E faça watch a cada 60s da pipeline de release @.github/workflows/release.yml
    - A cada resultado atualize o usuário com informações
    - Caso qualquer etapa do workflow de release falhe, cancele a pipeline por completo
      - Analise os erros e decida:
        - corrigir sozinho e repetir o presente fluxo
        - avisar o usuário e parar para aguardar instruções
