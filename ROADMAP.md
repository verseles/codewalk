# ROADMAP — fila de trabalho do CodeWalk v2

> **Único arquivo que o owner precisa ler.** `avançar` executa a primeira linha aberta, de cima para baixo. Ao concluir, o agente apaga a linha; o git guarda o histórico. Os detalhes e o critério de pronto ficam em cada Issue. Comandos: [`AGENTS.md`](AGENTS.md).

Ordem aprovada pelo owner em 2026-11-05: UI/UX primeiro, depois o harness Codex, depois o que mexe no modelo de domínio.

## 1. UI/UX — lote 1

- [ ] #440 Estado offline visível
- [ ] #441 Aviso de turno interrompido por restart do servidor (inclui #423)
- [ ] #469 Timeline: agrupar o raciocínio, compactação e marcador final

## 2. Limpeza logo após o lote 1

- [ ] #476 Remover dependências e código Android nativo só da v1

## 3. UI/UX — restante

- [ ] #471 Validar no aparelho o download in-app do APK (ação do owner) e fechar
- [ ] #468 Chips de status do cabeçalho que não importam
- [ ] #467 Repensar o Refresh
- [ ] #470 Escolha Steer/Queue no composer
- [ ] #466 Settings com lugar fixo no celular
- [ ] #438 Editar servidor pareado
- [ ] #474 Janela desktop: barra integrada e comportamento ao fechar
- [ ] #462 Busca na timeline e controles que faltam na toolbar
- [ ] #426 Mostrar troca de modelo e agente na timeline
- [ ] #427 Catálogos atualizados e nome do modelo padrão
- [ ] #431 Polir a escolha de modelo e agente
- [ ] #464 Área de toque das ações da mensagem do usuário
- [ ] #417 Manter o scroll da lista de sessões
- [ ] #418 Manter o lugar de leitura da aba
- [ ] #447 Onboarding e tour de primeiro uso
- [ ] #451 Ícones de projeto e cores de abas
- [ ] #452 Sessões e catálogo instantâneos após reiniciar
- [ ] #301 Canned answers
- [ ] #448 Data saver no celular
- [ ] #449 Diagnósticos com tags e performance
- [ ] #444 Aviso quando o navegador não abre o link de atualização

## 4. Robustez da sessão

- [ ] #413 Re-hidratação ao vivo mescla página disjunta atrás das linhas residentes
- [ ] #414 Bloco do topo da timeline desloca as linhas
- [ ] #415 Teste do caminho de erro na leitura de histórico antigo
- [ ] #416 Limitar resultado de ferramenta acima de 64 KiB
- [ ] #432 Limitar mensagens de erro enormes de ferramenta
- [ ] #421 Reler atividade da sessão ao mudar o filtro
- [ ] #424 Restaurar o orçamento de reparo após hidratação
- [ ] #429 Segurar replays durante troca de modelo ou agente
- [ ] #428 Política única para IDs de seleção
- [ ] #434 Acordar streams em toda troca de rede
- [ ] #419 Apagar rascunhos de sessões e servidores removidos
- [ ] #420 Limitar armazenamento de rascunhos órfãos
- [ ] #293 Teste de corrida na troca de modelo durante o envio
- [ ] #425 Capturar troca real de modelo e agente no OpenCode 2.0.22
- [ ] #443 Atualizar o rodapé de fundação do `BEHAVIOR.md`

## 5. Codex: gates G1, G2 e G5

- [ ] #239 Contrato ao vivo do OpenCode v2 (#243, #244)
- [ ] #245 Gravações do Codex (G1)
- [ ] #246 Gravações do Claude Code (G1)
- [ ] #260 Validar o modelo canônico contra as gravações (#257)
- [ ] #266 Teste de dois adaptadores (G2)
- [ ] #265 Schema final do CHP (G5)
- [ ] #399 Versionar ou descartar a evidência de contrato solta
- [ ] #237 ADR-059: modos de permissão
- [ ] #238 ADR-060: transição v1 → v2

## 6. Funcionalidades que mexem no modelo

- [ ] #292 Comandos, skills, menções e anexos
- [ ] #473 Mostrar anexos na timeline
- [ ] #288 Arquivos (#289 leitura, #290 edição)
- [ ] #291 Terminal
- [ ] #286 Subagentes e bandeja de trabalho em segundo plano
- [ ] #287 Revert, fork e diff
- [ ] #294 Uso, contexto e erros
- [ ] #307 Voz: STT e leitura em voz alta
- [ ] #308 Exportar sessão e mensagem, encaminhar
- [ ] #309 Notificações e atenção, com sons
- [ ] #310 Instalação gerenciada do OpenCode
- [ ] #316 Cloudflare Access
- [ ] #317 Tailscale embutido
- [ ] #295 Servidor falso do OpenCode e checagem de drift (#297)
- [ ] #268 Pacote de transporte (#270, #271)

## 7. Saúde de engenharia

- [ ] #465 Falhas do `make check` em ARM64
- [ ] #456 Timeout do `make check` em ARM64
- [ ] #461 Teste de arquivo temporário com `.tmp` no caminho
- [ ] #460 Android: AGP, KGP e Gradle no limite do Flutter 3.47.9
- [ ] #459 macOS: alvo mínimo em conflito com o Flutter 3.47.9
- [ ] #457 Guarda de arquitetura com prefixo de import
- [ ] #445 `cut_beta`: recusar sem `.task-memory`
- [ ] #477 Piso de cobertura dos pacotes
- [ ] #433 Dividir os maiores arquivos da v2
- [ ] #411 Suíte golden do xterm vendorizado
- [ ] #410 Artefato novo do Task Memory escondido do `git add`

## 8. Plataformas e GA

- [ ] #252 Esqueleto do workspace, fechamento (#255)
- [ ] #247 Web (#358, #234)
- [ ] #248 iOS
- [ ] #249 macOS
- [ ] #250 Monitor Android em segundo plano
- [ ] #251 Ciclo do OpenCode gerenciado por sistema
- [ ] #313 Builds de plataforma no CI
- [ ] #312 Atualizador e tooling, fechamento
- [ ] #228 Transição v1: instaladores (#230, #231)
- [ ] #439 `make release` da v1 para o v1.266.0 final
- [ ] #435 Gate do CodeWalk 2 escondido por checagem silenciosa (v1)
- [ ] #437 Atualização desktop relata sucesso após falha (v1)
- [ ] #442 Explicar a troca para a v2 ao lado de uma v1 no Linux
- [ ] #232 Release v1.266.0
- [ ] #314 Acessibilidade e localização
- [ ] #315 Medição de performance e bateria
- [ ] #226 Conexão por WireGuard (relato de usuário)
- [ ] #181 Telemetria não invasiva
- [ ] #318 Documentação da v2.0
- [ ] #319 Cutover
- [ ] #320 Release 2.0.0

## 9. Depois da v2.0

- **v2.1:** #322, #323, #324, #325, #326, #327, #328, #329, #330, #331, #332, #333, #334, #335
- **v2.2:** #336, #337, #338, #339, #340
- **v2.3:** #341, #342, #343, #344
- **Backlog:** #345, #346, #347, #348, #349, #350, #351, #352, #353, #354

## Não voltam (decisão do owner ou limite da API)

- Paridade visual por pixel com a v1 (2026-11-05).
- Editor dos padrões do OpenCode, rótulos de origem e card de permissões: o OpenCode 2 não grava config (#450).
- Busca de símbolos no `@`: o OpenCode 2 removeu `GET /find/symbol`.
- Anexo de PDF para o OpenCode: desligado no escopo aprovado; converta a página em imagem.
- Task list e progresso de tarefas: o OpenCode 2 não tem todo.
- Share/copy link e "view tasks": sem rota no 2.0.22.
- Linhas do painel lateral removidas (Refresh + Settings, "Connect to a running server", "Open projects").
- Rótulos relativos de data na timeline, trocados por hora.
- Estilo clássico/refinado.
- "Arquivar" virou "Ocultar no CodeWalk", local.
- Títulos gerados pelo cliente: vêm do servidor.
- Importação de dados da v1.
- Motores de voz Moonshine, Nemotron e Edge experimental, salvo pedido do owner.
- Mecânicas só da v1 (SWR, IDs otimistas, reconciliação, os 25 workarounds).

## Índice de consulta

- **#446** é o ledger das 285 seções da v1: serve de índice para achar a UX de referência no branch `v1`. Não é tarefa.
