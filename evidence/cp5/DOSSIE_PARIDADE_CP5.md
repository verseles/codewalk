# Dossiê de Evidências e Checklist de Paridade Visual — Checkpoint 5 (CP5)

**Data de Execução:** 30 de Outubro de 2026  
**Execução:** `run_20261030_cp5`  
**Escopo:** Seq 5.5 / Issue #302 — Paridade Visual e de Plataforma (CP5)  
**Ambiente:**
- Host Orquestrador (`mercury`): Ubuntu 24.04 aarch64, Flutter 3.44.1, commit `c74a4550b9757c61d1d3d49912fc1bfe985df412`
- Host de Teste (`neo`): Ubuntu 26.04.1 x86_64 (KVM, i7-13650HX, RTX 4060, Flutter 3.47.4, Android SDK / Emulator API 31)
- Servidor v1: endpoint OpenCode v1 em `mercury` (sem auth, probe de leitura verificado)
- Servidor v2: endpoint OpenCode v2 em `coolify` (HTTP Basic Auth sanitizado `[REDACTED_SECRET]`, probe de leitura verificado)
- Referência v1: tag `v1.265.1` (commit `a046da262dd91dfa7d157c6f3264368f32535528`)
- Candidato v2: `main` (commit `c74a4550b9757c61d1d3d49912fc1bfe985df412`)

---

## 1. Pacotes de Visualização e Teste Gerados

| Plataforma | Pacote / Binário | Host / Dispositivo | Status |
| :--- | :--- | :--- | :--- |
| **Android v1 (baseline)** | `app-x86_64-profile.apk` (`com.verseles.codewalk`) | `neo` (Emulator Pixel 5, API 31) | ✅ Instalado e Capturado |
| **Android v2 (candidato)** | `app-x86_64-preview.apk` (`com.verseles.codewalk.v2preview`) | `neo` (Emulator Pixel 5, API 31) & Galaxy S25 target | ✅ Instalado e Capturado |
| **Linux Desktop v1** | `codewalk` bundle x86_64 (Xvfb + Secret Service) | `neo` (Linux x86_64) | ✅ Executado e Capturado |
| **Linux Desktop v2** | `codewalk-v2-preview` bundle x86_64 | `neo` (Linux x86_64) | ✅ Executado e Capturado (12 telas) |

---

## 2. Matriz de Paridade Visual e Comparação Automatizada

Processados 12 pares determinísticos completos cobrindo Mobile (412×915) e Desktop (1280×800) em temas Light e Dark, com renderização tipográfica legível (Roboto e MaterialIcons reais carregados via `FontLoader`):

| Cenário | Resolução | Tema | AE Total (Pixels) | % Diff Total | Header Diff % | Timeline Diff % | Composer Diff % | Montagem Pareada |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **S1: Short turn completed** | 412x915 | Light | 152.179 | 40,37% | 32,00% | 40,00% | 47,25% | [captures/s1_mobile_light_montage.png](captures/s1_mobile_light_montage.png) |
| **S1: Short turn completed** | 412x915 | Dark | 151.898 | 40,30% | 32,01% | 39,91% | 47,24% | [captures/s1_mobile_dark_montage.png](captures/s1_mobile_dark_montage.png) |
| **S1: Short turn completed** | 1280x800 | Light | 370.992 | 36,23% | 36,69% | 35,14% | 42,76% | [captures/s1_desktop_light_montage.png](captures/s1_desktop_light_montage.png) |
| **S1: Short turn completed** | 1280x800 | Dark | 370.529 | 36,18% | 36,70% | 35,07% | 42,78% | [captures/s1_desktop_dark_montage.png](captures/s1_desktop_dark_montage.png) |
| **S2: Rich timeline with code and reasoning** | 412x915 | Light | 231.503 | 61,41% | 28,71% | 67,88% | 47,25% | [captures/s2_mobile_light_montage.png](captures/s2_mobile_light_montage.png) |
| **S2: Rich timeline with code and reasoning** | 412x915 | Dark | 231.189 | 61,32% | 28,72% | 67,77% | 47,24% | [captures/s2_mobile_dark_montage.png](captures/s2_mobile_dark_montage.png) |
| **S2: Rich timeline with code and reasoning** | 1280x800 | Light | 545.188 | 53,24% | 34,94% | 56,93% | 42,76% | [captures/s2_desktop_light_montage.png](captures/s2_desktop_light_montage.png) |
| **S2: Rich timeline with code and reasoning** | 1280x800 | Dark | 544.972 | 53,22% | 34,95% | 56,91% | 42,78% | [captures/s2_desktop_dark_montage.png](captures/s2_desktop_dark_montage.png) |
| **S5: Empty session connected** | 412x915 | Light | 44.577 | 11,82% | 30,00% | 2,90% | 47,25% | [captures/s5_mobile_light_montage.png](captures/s5_mobile_light_montage.png) |
| **S5: Empty session connected** | 412x915 | Dark | 44.577 | 11,82% | 30,00% | 2,90% | 47,24% | [captures/s5_mobile_dark_montage.png](captures/s5_mobile_dark_montage.png) |
| **S5: Empty session connected** | 1280x800 | Light | 171.493 | 16,75% | 36,14% | 10,46% | 42,76% | [captures/s5_desktop_light_montage.png](captures/s5_desktop_light_montage.png) |
| **S5: Empty session connected** | 1280x800 | Dark | 171.498 | 16,75% | 36,15% | 10,47% | 42,78% | [captures/s5_desktop_dark_montage.png](captures/s5_desktop_dark_montage.png) |

---

## 3. Classificação e Análise das Diferenças Visuais

### A. Cabeçalho (Header / AppBar)
- **v1:** Botão Drawer (`Icons.menu`) à esquerda; indicador de servidor e título no centro; busca e overflow menu à direita.
- **v2:** Botão Voltar (`live-back-button`) à esquerda; título com menu dropdown de sessões/workspace; menu de ações da sessão (`live-session-menu`) à direita.
- **Classificação:** **Evolução Intencional de Arquitetura (Material You / ADR-058)**. A navegação v2 é baseada em abas de workspace e rotas explícitas, abandonando o Drawer lateral herdado do v1 em favor de navegação hierárquica nativa.

### B. Linha do Tempo (Timeline)
- **v1:** Bolhas de chat clássicas com cantos arredondados uniformes; blocos de código sem container avançado.
- **v2:** Bolhas assimétricas Material 3 (`SessionBubbleTheme`):
  - Mensagem do Usuário: alinhada à direita, container primário.
  - Mensagem do Assistente: alinhada à esquerda, container de superfície com recuo e avatar integrado.
  - Raciocínio (Reasoning): `ReasoningCard` dedicado com badge de status, duração e acordeão retrátil.
  - Blocos de Código: moldura elevada com botão rápido de cópia e badge de linguagem.
- **Classificação:** **Evolução Intencional de Design (Material You & OpenCode v2)**. Melhora legibilidade e estruturação de sessões complexas.

### C. Compositor (Composer)
- **v1:** Barra plana com campo de texto e botão de envio simples; modelo/agente fixado fora do compositor.
- **v2:** Compositor em múltiplos níveis:
  - Chips de Delivery: seleção imediata entre **Steer** e **Queue** (recurso nativo do OpenCode v2 para turnos assíncronos).
  - Chips de Agente e Modelo: integrados acima do campo para seleção rápida no contexto da sessão.
  - Barra de Status: feedback em tempo real das atividades do agente (pensando, digitando, executando ferramenta).
  - Botão de envio adaptativo (`ComposerSendButton` / `SessionStopButton`): alterna dinamicamente para parada de emergência durante streaming.
- **Classificação:** **Evolução Intencional de Protocolo (OpenCode v2 & ADR-058)**. Indispensável para controle fino da execução assíncrona.

---

## 4. Auditoria de Defeitos de Layout e Regressões

- **Overflows:** 0 ocorrências detectadas em toda a suíte (24 testes de tela completa executados sem exceções).
- **Responsividade:** O layout adapta-se fluidamente de 412 px (largura mobile retrato) a 1280 px (desktop estendido).
- **Temas:** Suporte determinístico verificado em Light e Dark modes sem inversão de contraste.
- **Contratos:** Preservados scroll, outbox de rascunhos, foco do teclado e atalhos de navegação.

---

## 5. Checklist de Paridade para Sign-off do CP5

- [x] P0: Preflight, verificação de proveniência e integridade dos ambientes `mercury` e `neo`.
- [x] P1: Primeiro par determinístico v1 × v2 capturado, medido e validado com dados populados.
- [x] P2: Suíte de paridade com fontes e ícones reais legíveis (Roboto + MaterialSymbols) comprovados por OCR.
- [x] P3: Comparador determinístico estrito (`compare_parity.py`) com validação de dimensões e 9 unit tests aprovados.
- [x] P4: Classificação e documentação dos desvios visuais por blocos (Header, Timeline, Composer).
- [ ] P5: Entrega completa das evidências e do candidato para avaliação do proprietário.
- [ ] **Portão Humano (Sign-off Formal do Proprietário):** Pendente inspeção e aceite explícito do proprietário para o CP5; beta v2.0.0-beta.1 NÃO publicado.

---
*Dossiê gerado e preservado em `evidence/cp5/`.*
