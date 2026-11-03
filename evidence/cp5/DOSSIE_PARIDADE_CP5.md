# Dossiê de Paridade Visual — Seq 5.6 (#458, S10)

**Escopo:** Seq 5.6 / Issue #458 (V2-071H): toolbar, painel lateral, abas, composer, menus e mensagens da v2 comparados com a v1 `v1.265.1`, no celular (412×915) e no desktop (1280×800), em claro e escuro.
**Referência v1:** tag `v1.265.1` (commit `a046da262dd91dfa7d157c6f3264368f32535528`), somente leitura.
**Candidato:** o HEAD do commit que contém esta seção. O último commit de código é `60737be3` (teste de Configurações do item 2). As capturas foram medidas no neo (x86_64, Flutter 3.47.9), em clone limpo de `445e2468`, cujo código é idêntico ao atual, exceto pelo teste. Linha de base S4: `S4-5057601`.
**Evidências no repositório:** `evidence/cp5/surfaces-445e2468/` (`report.json` e 54 montagens). Checklist por superfície, decisões e linhas abertas: este arquivo e comentário de S10 na #458.
**Registros de validação** (captures, `make check`, arquitetura, localizações, prévias, hashes e smoke): #458 e #398 e Task Memory. Não ficam neste arquivo, para não mudar o SHA do candidato.

Este dossiê não aceita veredictos sem destino. Cada diferença restante tem um destino: uma issue `after-mvp`, uma decisão registrada do dono, ou uma causa de plataforma documentada.

---

## 1. Captura, validação e comparação

- Pares: 54 (13 cenários × 2 temas × 2 tamanhos, mais `s12` só no celular).
- Captures: 108 testes passam.
- Comparação estrita (`compare_parity.py`): status `complete`, 54 pares, 0 ausentes.
- `make check TEST_TIMEOUT=20m`: 4815 testes passaram, com 6 ignorados; análise com 335 problemas, dentro do orçamento de 337.
- `make v2-architecture`: 404 arquivos governados e 4 pacotes, sem violação.
- `generate_v2_localizations.py --check`: 15 arquivos, sem diferença.

## 2. Regra de conclusão por superfície

Uma superfície está concluída quando (a) seu grupo de teste passa, (b) o checklist está completo, (c) a diferença por região não piorou em relação ao S4 (`S4-5057601`) e (d) cada diferença restante está classificada.

Duas decisões do dono tratam a regra (c):
- **Decisão 1A (2026-11-02):** aceitou os pares `s8` mobile claro e escuro, que pioram a diferença de pixel (9,60 → 10,15 e 9,62 → 10,17).
- **Opção A (2026-11-03):** aceitou a geometria do painel lateral (+12 px no desktop, decisões 11 e 12) e a linha Desfazer no overflow compacto (+52 px, decisão 10) como consequência das decisões aprovadas. Ambas ficam como resíduos em #463.

## 3. Checklists por superfície

Itens: ordem dos controles, altura (±1 dp), padding (±2 dp), raio, glifo, texto, cor, corte e sobreposição.

### 3.1 Barra superior (toolbar) — concluída
- [x] Grupo `toolbarGroup` (densidades e overflow) passa.
- [x] Ordem e controles: decisão 10. Desfazer listado e desabilitado sem sessão viva.
- [x] Altura idêntica em 54 de 54 pares (|Δaltura| = 0).
- [x] Região contra S4: não comparável (54/54) → comparável, diferença média de 7,47%.
- [~] Diferença de pixel média de 7,47%. Destino #463.

### 3.2 Painel lateral — concluído, com geometria aceita (opção A)
- [x] Grupo `sidePanelGroup` passa (servidor com nuvem 16 dp e seta 18 dp; glifos Symbols).
- [x] Controles removidos conforme decisões 1A, 2A e 3A do dono (2026-11-02): linha de atualizar e configurações, link "Connect to a running server" e rótulo "Open projects". Destino: #462, itens 11 a 13.
- [x] Pixels nos 6 pares comparáveis: média 17,98%, contra 21,42% no S4 (melhorou). Destino #463.
- [~] Geometria: retângulo do painel em y=87 px na v1 e y=44 px na v2 (desktop). |Δaltura| média 25,2 → 34,9 px; nos 26 pares do desktop, 31 → 43 px. Aceito pelo dono (opção A) como consequência das decisões 11 e 12. Destino #463.
- [~] `s8` mobile: 9,62 → 10,17 (escuro) e 9,60 → 10,15 (claro). Aceito pela decisão 1A.

### 3.3 Abas — concluída
- [x] Grupo de valores em `v1_surface_parity_test.dart` (linhas 245 e 288) passa, sem `skip`: alturas e ordem por tamanho; menu de aba sem seleção; glifo com 8 dp.
- [x] Altura da faixa: 46,4 dp (compacto) e 43,2 dp (largo), decisão 13. Código em `session_tab_strip.dart:541`.
- [x] Alvo de toque da aba: 38,4 dp. Exceção de acessibilidade do dono (comentário 6592135781); acompanhamento em #464.
- [x] Ordem: aba ativa primeiro, decisão B do dono (2026-11-03).
- [x] Botão de fechar só na aba ativa.
- [x] Região contra S4: Δaltura média 6,5 → 1,5 px (melhorou).
- [~] Faixa de 43 px na v2 contra 43–46 px na v1 (8 pares, sem comparação de pixel). Destino #463.

### 3.4 Composer — concluído, com controles só-v2 classificados
- [x] Grupo `composerGroup` (linha 167 de `v1_surface_parity_test.dart`): botão de envio de 42 dp com glifo de 24 dp (decisão 7).
- [x] Parar: glifo `stop_rounded` de 24 dp, na cor de erro.
- [x] Chips Steer e Queue: forma stadium, sem borda (decisão 15).
- [x] Campo com a bolha refinada e dica de texto v2 mantidos (decisões do dono).
- [~] Altura: 118 px na v2 contra 50 px na v1 no estado vazio (`s1`, desktop e mobile). A diferença vem dos controles só-v2 (seletores de agente, modelo e variante, linha de chips e slot de status). Classificação: controle só-v2 com estilo v1. Destino #463.
- [x] Região contra S4: igual (Δaltura média 69,8 px nos dois).

### 3.5 Timeline (mensagens) — concluída
- [x] Grupo de valores em `v1_surface_parity_test.dart` (linhas 365 a 492): cabeçalho do usuário ("You" e hora, sem chip de duração), cabeçalho do assistente (hora e chip de duração), e ausência de cabeçalho sem hora, duração ou ação (decisão 16).
- [x] Rótulos relativos e de data da v1 omitidos: as chaves de l10n não existem na v2, e o dono aceitou a hora. Destino #462.
- [x] Ações do turno do usuário (desfazer e restaurar) à esquerda da bolha, como na v1, com os glifos `undo_rounded` e `settings_backup_restore`. Avançar e compartilhar ficam omitidos (#462). Decisão B do dono (2026-11-03).
- [~] Região: deslocamento de 2–3 px e altura dentro de 1 px (16 pares). Segue a faixa de abas. Destino #463.
- [x] Região contra S4: Δaltura média 47,5 → 0,5 px (melhorou).

### 3.6 Menus e overlays — concluída, com overflow aceito (opção A)
- [x] Grupo de valores do overflow (linha 537) e do menu de aba (linha 288) em `v1_surface_parity_test.dart`.
- [x] Menus de projeto: valores em `project_context_row_test.dart` e `project_contexts_test.dart`.
- [~] Menu de linha de sessão: glifos Symbols de 18 dp e rótulos com reticências, implementados na S6 (`e02a45e1`, `47e7f838`). Não há teste de valor desse menu no arquivo de paridade; residual registrado na seção 6.
- [x] Overlay: pixels 8,17% → 0,91% nos 4 pares comparáveis (melhorou).
- [~] Overflow compacto (`s12`): 208 px (S4) → 260 px. A linha extra é "Desfazer último turno", prescrita pela decisão 10 (v1 mostra 162 px, com 3 linhas). Aceito pelo dono (opção A). Destino #463.

---

## 4. Regiões contra a linha de base S4

Convenção: pares comparáveis são os de linha de base S4 com diferença de pixel abaixo de 100 %. A geometria usa todos os pares.

| Região | Pares | Comparáveis S4 → final | Diferença média S4 → final | Δaltura média S4 → final | Leitura |
| :--- | ---: | ---: | ---: | ---: | :--- |
| Toolbar | 54 | 0 → 54 | não comparável → 7,47% | 11,0 → 0,0 px | Melhorou; altura idêntica |
| Overlay | 14 | 4 → 4 | 8,17% → 0,91% | 13,4 → 20,9 px | Pixels melhoraram; geometria do `s12` piorou (aceito, opção A) |
| Painel lateral | 32 | 6 → 6 | 21,42% → 17,98% | 25,2 → 34,9 px | Pixels melhoraram; geometria piorou (aceito, opção A) |
| Composer | 36 | 0 → 0 | — | 69,8 → 69,8 px | Igual |
| Timeline | 16 | 0 → 0 | — | 47,5 → 0,5 px | Melhorou |
| Abas | 8 | 0 → 0 | — | 6,5 → 1,5 px | Melhorou |

## 5. Diferenças restantes e destino

| Diferença | Medida | Destino |
| :--- | :--- | :--- |
| Controles v1 sem função v2 (terminal, arquivos, busca, exibição, atalhos, economia de dados, tour, voz, anexos, ícones de projeto, linhas do painel, hora relativa, contador de abas, ícone da linha do tempo à esquerda) | 15 itens | #462 (`after-mvp`) |
| Glifo de trocar abas | controle só-v2, mantido com estilo v1 | Decisão 7: função mantida |
| Regra de Recentes, estilo da aba de rascunho, saudação e chips do novo chat | implementados | Commits `7f0e1f58` e `89f12cad` |
| Diferença de pixel na toolbar | 7,47% médio | #463 |
| Geometria do painel lateral | 31 → 43 px no desktop; faixa de 43 px na v1 | Aceito (opção A, 2026-11-03); #463 |
| Pixels do painel no `s8` mobile | 9,62 → 10,17 e 9,60 → 10,15 | Aceito (decisão 1A, 2026-11-02) |
| Overflow compacto (`s12`) | 208 → 260 px (linha Desfazer, decisão 10) | Aceito (opção A, 2026-11-03); #463 |
| Altura e deslocamento do composer | 118 px contra 50 px (estado vazio) | #463 (controles só-v2) |
| Faixa de abas e deslocamento da timeline | Δaltura de 1,5 px e 0,5 px | #463 |
| Menus de sessão e de projeto | geometria não piorou em relação ao S4 | Sem ação |
| Alvo de toque da aba | 38,4 dp | Exceção de acessibilidade do dono (comentário 6592135781); #464 |
| Alvo de toque da ação de turno (desfazer e restaurar) | 40 dp, igual à v1 | #464 (`after-mvp`) |

## 6. Decisões

1. **Gate item 3 (#458, comentário 6595560754): resolvido.** Os grupos de valores de abas, timeline e overflow estão em `v1_surface_parity_test.dart` (linhas 245, 288, 365–492 e 537–569), sem `skip`. O commit `1df27934` criou esses grupos, então a opção A do gate foi adotada.
2. **Regra (c) do painel lateral e do overflow compacto: decidido pelo dono em 2026-11-03 (opção A).** As diferenças de geometria ficam como resíduos em #463, com os números da seção 4.
3. **Alvo de toque da ação de turno (40 dp):** achado W1 da rodada 1 de `rvw_20261103T105717Z_2b94b2a4`. Não aplicado nesta linha, porque o objetivo é paridade com a v1 e acessibilidade está fora de escopo. O intercâmbio de dissidência com o helper `-F` concordou, sem mudança. Acompanhamento em #464.
4. **Menu de linha de sessão sem teste de valor no arquivo de paridade:** residual registrado. O gate item 3 cobre o grupo de menus (overflow e menu de aba), então este item não o bloqueia.
5. **Ações do turno do usuário:** à esquerda da bolha, como na v1 (decisão B do dono, comentário de 2026-11-03 10:36 na #458). O cabeçalho do usuário mantém só "You" e a hora.
6. **Teste de Configurações (gate item 2):** o teste "settings appearance has one visual style" (en e pt) passou a exigir, na mesma rolagem, modo de tema, seletor de paleta, densidade e contraste, além da ausência de controle de estilo e de "Refin". Commit `60737be3`. Revisão rodada 2 (`rvw_20261103T105717Z_2b94b2a4`): luna, sol-F e grok aprovam sem achados.

## 6.1 Goldens regenerados e motivo

Nenhum golden foi regenerado na S10: nenhum PNG muda nos commits da S10, e `make check` passou em `445e2468` com os goldens atuais. O comentário de 2026-11-03 10:36 na #458 menciona regeneração, mas os commits não a contêm. Regenerações anteriores:

| Commit | Motivo | Arquivos |
| :--- | :--- | :--- |
| `c5905b10` (S3) | Estilo visual único refinado (decisões 17 a 20) | `appearance/goldens/{desktop,mobile}_{light,dark}.png`; `sessions/goldens/command_picker_*`, `composer_input_*`, `live_work_*` |
| `ad19f5d0` (S8) | Glifos de envio e parada em 24 dp; chips Steer e Queue em stadium | `sessions/goldens/command_picker_mobile_{light,dark,ar_rtl}.png`, `composer_input_mobile_{light,dark,ar_rtl}.png` |
| `7208393f` (S8) | Regeneração no neo com a fonte Symbols carregada | `sessions/goldens/command_picker_mobile_{dark,ar_rtl}.png`, `composer_input_mobile_{dark,ar_rtl}.png` |
| `78c91962` (S9) | Cabeçalho da mensagem: "You" e hora; sem cabeçalho do assistente quando vazio | `sessions/goldens/live_{top,work,tail,work_open}_*.png`; `shared/goldens/{desktop,mobile}_*.png` (renderização rica, altura 524 px) |

---

## 7. Gate técnico da #458

A regra (c) da seção 2 não é atendida em medição. Ela está registrada como exceção aceita pelo owner em 2026-11-03 (opção A), não como atendida.

| Item | Estado | Evidência |
| :--- | :--- | :--- |
| 1. Busca do estilo clássico vazia | atendido | grep de `VisualStyle`, `visualStyle`, `isRefined`, `AppVisualStyleTokens.classic` e `settingsAppearanceVisualStyle` em `lib/app`, `lib/features`, `lib/shared`, `lib/platform`, `test/v2` e no gerador de l10n: 0 ocorrências |
| 2. Configurações: tema, paleta, densidade e contraste; sem controle de estilo nem "Refin" em en e pt | atendido | `test/v2/appearance/appearance_widget_test.dart`, testes "settings appearance has one visual style" em en e pt, commit `60737be3` |
| 3. Grupos de valores da v1 sem `skip` | atendido | `test/v2/sessions/v1_surface_parity_test.dart`: 0 ocorrências de `skip`; grupos de barra, painel, abas, composer, menus e timeline |
| 4. Testes focados, arquitetura, localizações e `make check` no SHA final | atendido no SHA final | registrado na #458 para o HEAD deste commit |
| 5. Critérios 40, 86 e D2 do #455 provados e marcados; 5.4c aceito | atendido | #455 marca os três critérios com teste e commit; #398: 5.4c "✅ accepted 2026-11-02 at `ef8ef7f7`"; #302: V2-071G marcado |
| 6. Revisões convergidas sem achado confirmado aberto | atendido | rodada 1 (`445e2468`): W1 não aplicado, dissidência do sol-F concordou; rodada 2 (`60737be3`): luna, sol-F e grok aprovam sem achados |
| 7. Árvore legada e `pubspec.yaml` intactos | atendido | `git diff --stat b436058e HEAD -- lib/presentation lib/domain lib/l10n test/widget pubspec.yaml` vazio |
| 8. Relatório sem ausentes, checklists, dossiê, goldens listados e after-mvp | atendido com exceção do owner | comparação 54 pares, 0 ausentes; checklists na seção 3; regra (c) aceita pelo owner (opção A, #463); goldens na seção 6.1; #462 e #464 abertos |
| 9. CI verde no SHA final | não exigido nesta fase | o CI do GitHub passa a ser exigido quando o owner autorizar o push |

---

*Dossiê de Seq 5.6 (#458, S10). Substitui o dossiê de 31 de outubro de 2026 (CP5 da Seq 5.5), que tinha veredictos sem destino.*
