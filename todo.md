# Grupos de flow

Agrupamento das 22 issues abertas consultadas em 26/09/2026, por afinidade de
código e testes. GitHub Issues continua sendo a fonte de status e critérios de
aceitação; este documento registra a composição dos grupos.

## G1 — Rate Limits: dados, Pace e atualização

Afinidade alta.

- [#206 — Pace do xAI](https://github.com/verseles/codewalk/issues/206)
- [#209 — Refresh periódico na sidebar desktop](https://github.com/verseles/codewalk/issues/209)
- [#214 — Rótulo da janela do Codex](https://github.com/verseles/codewalk/issues/214)

Código: `quota_remote_datasource.part.js.dart`, `quota_provider.dart`,
`quota_pace_utils.dart` e `quota_popup_section.dart`.
Testes compartilhados: `test/unit/quota/`.

Ordem: dados/duração das janelas → Pace → refresh enquanto visível.
Usar a duração real; uma janela isolada não é necessariamente semanal.

## G2 — Renderização de mensagens

Afinidade alta.

- [#191 — Tela branca/cinza com Mermaid + LaTeX](https://github.com/verseles/codewalk/issues/191)
- [#194 — Contraste do Mermaid em light/dark](https://github.com/verseles/codewalk/issues/194)
- [#215 — Tabelas arredondadas e cabeçalho destacado](https://github.com/verseles/codewalk/issues/215)

Código: `chat_message_text_part.dart`, `chat_message_widget.dart`,
`mermaid_diagram_widget.dart` e `math_markdown.dart`.

Ordem: reproduzir/corrigir a tela branca → contraste → tabelas.
Validar conteúdo misto, temas claro/escuro e telas pequenas/grandes.

## G3 — Navegação e estrutura do workspace

Afinidade alta a média. Entregue em `v1.255.0`; as quatro issues foram encerradas
em 26/09/2026 com autorização do usuário, após CI e release verdes.

- [#202 — Abertura de projetos unificada com fuzzy](https://github.com/verseles/codewalk/issues/202)
- [#204 — Resize/hide das sidebars imediatamente reativos](https://github.com/verseles/codewalk/issues/204)
- [#205 — Acessos preservados com Conversations oculta](https://github.com/verseles/codewalk/issues/205)
- [#212 — Settings e abas visíveis mas inacessíveis](https://github.com/verseles/codewalk/issues/212)

Código: `chat_page.dart`, `chat_page_types_part.dart`,
`chat_page_chrome.dart`, `chat_page_scaffold.dart`,
`chat_page_selector_flow.dart`, `chat_page_workspace_controller.dart` e
`desktop_window_title_bar.dart`.

Ordem proposta: reatividade → seletor unificado → acessos alternativos →
navegação de Settings. Decidir a UX da #212 antes da implementação; se Settings
como aba exigir arquitetura própria, reconsiderar sua inclusão neste grupo.
Preservar mobile, atalhos, isolamento de contexto e desempenho do chat.

## G4 — Settings: simplificação visual e conteúdo

Afinidade média.

- [#201 — Reduzir bordas do modo Refinado](https://github.com/verseles/codewalk/issues/201)
- [#203 — Unificar servidores ativos e salvos](https://github.com/verseles/codewalk/issues/203)
- [#208 — Apresentar Sherpa como estável](https://github.com/verseles/codewalk/issues/208)

Código: `servers_settings_section.dart`, demais seções de Settings,
`speech_settings_section.dart` e arquivos de tradução.

Ordem: composição de Servers → limpeza visual → Sherpa e traduções.
A #208 é um complemento pequeno de apresentação/localização; não implica
alterar o motor de voz ou compartilhar a causa das outras issues.

## G5 — Atualização do aplicativo

Afinidade média.

- [#207 — ANNOUNCE desde a versão anteriormente instalada](https://github.com/verseles/codewalk/issues/207)
- [#211 — Defender bloqueia a atualização interna](https://github.com/verseles/codewalk/issues/211)

Código: `settings_provider_update_install.dart`, `update_check_service.dart`,
`app_shell_page.dart` e `install.ps1`.

Compartilhar a investigação do ciclo de atualização, com validações
independentes. A #211 exige evidência no Windows; não presumir falso positivo e
não bloquear a entrega dos anúncios pela reprodução do instalador.

## Flows independentes

| Issue | Fronteira de trabalho |
| --- | --- |
| [#213 — Cores das abas](https://github.com/verseles/codewalk/issues/213) | Extração/cache de paleta, ProjectIconProvider, tab strips e preferência persistida. |
| [#210 — Ctrl/Cmd+S](https://github.com/verseles/codewalk/issues/210) | Escopo de foco e atalho do diálogo em chat_page_file_viewer.dart. |
| [#197 — Web fica offline](https://github.com/verseles/codewalk/issues/197) | Lifecycle, health checks e reconexão no navegador. |
| [#193 — Limpeza da raiz](https://github.com/verseles/codewalk/issues/193) | Auditoria de referências, build e scripts antes de remover arquivos. |
| [#164 — OpenCode v2](https://github.com/verseles/codewalk/issues/164) | Pesquisa de compatibilidade e decisão arquitetural. |
| [#181 — Telemetria](https://github.com/verseles/codewalk/issues/181) | Pesquisa e definição de dados/consentimento antes da implementação. |

## Verificação de aceite

[#179 — Ordem das mensagens no Android](https://github.com/verseles/codewalk/issues/179)
já possui correção no main (`3279f283`, `90082887`, `d1df53a6`) e testes de
regressão, conforme código e comentário na issue. O último comentário consultado
pede confirmação ao autor; verificar o comportamento antes de propor nova
implementação ou encerrar a issue.

Cobertura: 15 issues nos cinco grupos + 6 independentes + 1 verificação = 22.
