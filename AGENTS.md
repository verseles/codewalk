CodeWalk é um projeto que visa permitir acessar agents de código de qualquer lugar, seja por desktop, seja pelo celular.

- Toda implementação deve ser pensada para mobile e desktop. Preferencialmente de maneira unificada e responsiva. Prioridade para UX no mobile.

- Sempre que concluir uma tarefa, verifique se:
  - Essa mudança requer um novo test ou atualização de um existente

- Antes de seguir para uma outra tarefa, baseado na tarefa anterior:
  1. Execute `make android` e logo em seguida notifique o usuário usando play_notification
  2. Verifique se requer atualização em @./ADR.md ou sugerir criar uma nova
  3. Verifique se requer atualização em @./CODEBASE.md
  4. Verifique se @./ROADMAP.md precisa ser atualizado
  5. Faça commit descritivo: titulo + detalhes

Observe a ordem acima! make android deve ser executado logo após concluída as modificações de código. Pode inclusive ser chamada em background. Alterar arquivos md e fazer commit não são impedimentos para executar make android. Execute o mais rápido possível após conclusão da parte de código da tarefa.

- Sempre que concluir qualquer tarefa, execute `make android` para que o usuario teste no celular.
- No upload via `tdl` (feito em `make android`), o `--caption` deve ser dinâmico e direto, descrevendo objetivamente o que foi alterado na última task.
- Evite caption genérico como "Ajustes mais recentes feitos"; prefira algo como "Corrigida altura da caixa Thinking Process".
- Após concluir a tarefa é importante executar logo `make android` para que o usuario teste no celular para que as outras tarefas continuem enquanto o usuário já vai testando a implementação.
- Após planejamento, criação de tests automatizados ou atualização de arquivos .md não é necessário executar `make android`, ele deve ser executado apenas ao finalizar tarefas solicitadas que modifiquem o código do app.
- `make precommit` não deve ser executado antes de commits que envolvam apenas arquivos estáticos (ou seja, mudanças que não alteram nem testes nem o aplicativo).
