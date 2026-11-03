# Dossiê de Paridade Visual — Seq 5.6 (#458, S10)

**Escopo:** Seq 5.6 / Issue #458 (V2-071H): toolbar, painel lateral, abas, composer, menus e mensagens da v2 comparados com a v1 `v1.265.1`, no celular (412×915) e no desktop (1280×800), em claro e escuro.
**Referência v1:** tag `v1.265.1` (commit `a046da262dd91dfa7d157c6f3264368f32535528`), somente leitura.
**Captura final medida:** `F-424a2ce8` no neo (x86_64, Flutter 3.47.9), em um clone do commit `424a2ce8` cuja árvore é idêntica à local. Em relação à execução `F-1d447467`, quatro regiões do painel lateral variaram 0,01 ponto (chips de padrão do rascunho e ordem de Recentes); a média total continua 63,22%. Os pares que ficam piores que o S4 são os mesmos de antes: `s8` mobile claro e escuro, aceitos pelo dono (decisão 1A).
**Evidências no repositório:** `evidence/cp5/surfaces-424a2ce8/` (`report.json` e 54 montagens do candidato `424a2ce8`). Checklist por superfície e linhas abertas: comentário de S10 na #458.
**Registros de validação** (captures, `make check`, arquitetura, localizações, prévias, hashes): #458 e #398 e Task Memory. Não ficam neste arquivo, para não mudar o SHA do candidato.

Este dossiê não declara nenhuma diferença como "intencional". Cada diferença restante tem um destino: uma issue `after-mvp` ou uma causa de plataforma documentada.

---

## 1. Captura e comparação

- Pares: 54 (13 cenários × 2 temas × 2 tamanhos, mais `s12` só no celular).
- Captures: 108 testes passam (`F-424a2ce8`).
- Comparação estrita (`compare_parity.py`): status `complete`, 54 pares, 0 ausentes.

## 2. Regra de conclusão por superfície

Uma superfície está concluída quando (a) seu grupo de teste passa, (b) o checklist está completo, (c) a diferença por região não piorou em relação ao S4 (`S4-5057601`) e (d) cada diferença restante está classificada. Duas superfícies não atendem (c) e não estão concluídas. Outras duas aguardam a decisão de gate item 3 (seção 6).

## 3. Checklists por superfície

Itens: ordem dos controles, altura (±1 dp), padding (±2 dp), raio, glifo, texto, cor, corte e sobreposição.

### 3.1 Barra superior (toolbar) — concluída, com diferença classificada

- [x] Grupo `toolbarGroup` (densidades e overflow) passa.
- [x] Ordem e controles: decisão 10. Desfazer listado e desabilitado sem sessão viva.
- [x] Altura: 44/46 dp idênticas em 54 de 54 pares.
- [x] Região contra S4: não comparável (54/54) → comparável, média 7,47%.
- [~] Diferença de pixel média de 7,47% (ver seção 5, destino #463).

### 3.2 Painel lateral — NÃO concluído (geometria piorou em relação ao S4)

- [x] Grupo `sidePanelGroup` passa (servidor com nuvem 16 dp e seta 18 dp; glifos Symbols).
- [x] Controles removidos conforme decisões 1A, 2A e 3A do dono (2026-11-02): linha de atualizar e configurações, link "Connect to a running server" e rótulo "Open projects". Destino: #462, itens 11 a 13.
- [~] Altura do cabeçalho: v1 87 px, v2 44 px (consequência das remoções aceitas).
- [x] Diferença de pixel nos 6 pares comparáveis: média 18,00%, contra 21,42% no S4 (melhorou). Destino #463.
- [ ] **Geometria contra o S4 piorou**: média de |Δaltura| 25,2 → 34,9 px. Não confirmei a causa; é provável que as remoções aceitas mudem as bordas da região. Decisão do dono: se a regra (c) aceita geometria alterada pelas remoções aprovadas.

### 3.3 Abas — classificada; grupo de valores pendente (gate item 3)

- [x] Altura da faixa: 46,4 dp (compacto) e 43,2 dp (largo), decisão 13. Código em `session_tab_strip.dart:541`.
- [x] Alvo de toque da aba: 38,4 dp dentro da faixa. Exceção de acessibilidade do dono (comentário 6592135781); causa de plataforma: alvo mínimo de 48 dp.
- [x] Ordem: aba ativa primeiro no grupo, decisão B do dono (2026-11-03).
- [x] Botão de fechar só na aba ativa.
- [~] Região: 43 px na v2 contra 43–46 px na v1 (8 pares, sem comparação de pixel). Destino #463.
- [x] Região contra S4: melhorou (Δaltura média 6,5 → 1,5 px).
- [ ] Grupo de valores em `v1_surface_parity_test.dart` ausente: os testes de valores estão em `session_tab_strip_test.dart` e `session_tab_menu_test.dart`. Decisão pendente (seção 6).

### 3.4 Composer — concluído, com controles só-v2 classificados

- [x] Grupo `composerGroup`: botão de envio de 42 dp com glifo de 24 dp (decisão 7).
- [x] Parar: glifo `stop_rounded` de 24 dp, na cor de erro.
- [x] Chips Steer e Queue: forma stadium, sem borda (decisão 15).
- [x] Campo com a bolha refinada e dica de texto v2 mantidos (decisões do dono).
- [~] Altura: 118–166 px na v2 contra 50–82 px na v1 (36 pares, sem comparação de pixel). Controles só-v2: seletores de agente, modelo e variante, a linha de chips e o slot de status. Classificação: controle só-v2. Destino #463.
- [x] Região contra S4: igual (Δaltura média 69,8 px nos dois).

### 3.5 Timeline (mensagens) — classificada; grupo de valores pendente (gate item 3)

- [x] Cabeçalho do usuário: rótulo "You" com semântica de cabeçalho, e hora; sem chip de duração (decisão 16).
- [x] Cabeçalho do assistente: hora no início, chip de duração no fim; sem cabeçalho quando não há hora, duração nem ação.
- [x] Rótulos relativos e de data da v1 omitidos: as chaves de l10n não existem na v2, e o dono aceitou a hora. Destino #462.
- [~] Região: deslocamento de 2–3 px e altura dentro de 1 px (16 pares). Segue a faixa de abas. Destino #463.
- [x] Região contra S4: melhorou (Δaltura média 47,5 → 0,5 px).
- [ ] Grupo de valores em `v1_surface_parity_test.dart` ausente: os testes estão em `session_message_info_test.dart` e `session_timeline_rendering_test.dart`. Decisão pendente (seção 6).

### 3.6 Menus e overlays — NÃO concluído (menu de overflow piorou em relação ao S4)

- [x] Menus de sessão: glifos Symbols, 18 dp, rótulos com reticências (S6).
- [x] Projetos: diferença média 0,91% nos 4 pares comparáveis, contra 8,17% no S4 (melhorou).
- [~] Sessões: deslocamento vertical de 13–19 px, mesma altura (4 pares). Destino #463.
- [ ] **Menu de overflow mobile (`s12`)**: v2 260 px, v1 162 px, S4 208 px. Piorou 52 px em relação ao S4. Destino #463, com a causa não confirmada.

---

## 4. Regiões contra a linha de base S4

| Região | Pares | Comparáveis S4 → final | Diferença média S4 → final | Δaltura média S4 → final | Leitura |
| :--- | ---: | ---: | ---: | ---: | :--- |
| Toolbar | 54 | 0 → 54 | não comparável → 7,47% | — | Melhorou (agora comparável) |
| Overlay | 14 | 4 → 4 | 8,17% → 0,91% | 13,4 → 20,9 px | Pixels melhoraram; geometria do `s12` piorou |
| Painel lateral | 32 | 6 → 6 | 21,42% → 18,00% | 25,2 → 34,9 px | Pixels melhoraram; geometria piorou (ver 3.2) |
| Composer | 36 | 0 → 0 | — | 69,8 → 69,8 px | Igual |
| Timeline | 16 | 0 → 0 | — | 47,5 → 0,5 px | Melhorou |
| Abas | 8 | 0 → 0 | — | 6,5 → 1,5 px | Melhorou |

## 5. Diferenças restantes e destino

| Diferença | Medida | Destino |
| :--- | :--- | :--- |
| Controles v1 sem função v2 (terminal, arquivos, busca, exibição, atalhos, economia de dados, tour, voz, anexos, ícones de projeto, linhas do painel, hora relativa) | 13 itens | Issue **#462** (`after-mvp`) |
| Diferença de pixel na toolbar | 7,47% médio | Issue **#463** |
| Geometria do painel lateral | +9,7 px médio contra o S4, por remoções aceitas | #462 (remoções) e #463 (geometria) |
| Altura e deslocamento do composer | 118–166 px contra 50–82 px | #463 (controles só-v2) |
| Faixa de abas e deslocamento da timeline | 2–3 px | #463 |
| Menu de overflow mobile | 260 px contra 162 px (S4: 208 px) | #463 |
| Menus de sessão | deslocamento de 13–19 px | #463 |
| Alvo de toque da aba | 38,4 dp | Plataforma: alvo mínimo de 48 dp (exceção de acessibilidade) |

## 6. Decisões pendentes

1. **Gate item 3 (#458, comentário 6595560754):** o grupo de valores de abas, menus e timeline não está em `v1_surface_parity_test.dart`. Opções: **A** criar esses grupos no arquivo de paridade, ou **B** ajustar o texto do gate para os testes de cada superfície. Recomendação: **B**.
2. **Painel lateral e menu de overflow:** a regra (c) não é atendida na geometria. O dono decide se aceita as remoções aprovadas como causa e se o menu `s12` precisa de ajuste antes do CP5.

## 6.1 Goldens regenerados e motivo

| Commit | Motivo | Arquivos |
| :--- | :--- | :--- |
| `c5905b10` (S3) | Estilo visual único refinado (decisões 17 a 20) | `appearance/goldens/{desktop,mobile}_{light,dark}.png`; `sessions/goldens/command_picker_*`, `composer_input_*`, `live_work_*` |
| `ad19f5d0` (S8) | Glifos de envio e parada em 24 dp; chips Steer e Queue em stadium | `sessions/goldens/command_picker_mobile_{light,dark,ar_rtl}.png`, `composer_input_mobile_{light,dark,ar_rtl}.png` |
| `7208393f` (S8) | Regeneração no neo com a fonte Symbols carregada | `sessions/goldens/command_picker_mobile_{dark,ar_rtl}.png`, `composer_input_mobile_{dark,ar_rtl}.png` |
| `78c91962` (S9) | Cabeçalho da mensagem: "You" e hora; sem cabeçalho do assistente quando vazio | `sessions/goldens/live_{top,work,tail,work_open}_*.png`; `shared/goldens/{desktop,mobile}_*.png` (renderização rica, altura 524 px) |

---

*Dossiê de Seq 5.6 (#458, S10). Substitui o dossiê de 31 de outubro de 2026 (CP5 da Seq 5.5), que usava veredictos "intencionais".*
