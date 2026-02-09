CodeWalk é um projeto que visa permitir acessar agents de código de qualquer lugar, seja por desktop, seja pelo celular.

- Sempre que concluir uma tarefa, verifique se:
  - Essa mudança requer um novo test ou atualização de um existente

- Antes de seguir para uma outra tarefa, baseado na tarefa anterior:
  - Verifique se requer atualização em @./ADR.md ou sugerir criar uma nova
  - Verifique se requer atualização em @./CODEBASE.md
  - Verifique se @./ROADMAP.md precisa ser atualizado
  - Faça commit descritivo: titulo + detalhes


- Sempre que concluir qualquer tarefa, execute `make android` para que o usuario teste no celular.
- No upload via `tdl` (feito em `make android`), o `--caption` deve ser dinâmico e direto, descrevendo objetivamente o que foi alterado na última task.
- Evite caption genérico como "Ajustes mais recentes feitos"; prefira algo como "Corrigida altura da caixa Thinking Process".
