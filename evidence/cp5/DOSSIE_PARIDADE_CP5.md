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

Processados 12 pares determinísticos completos cobrindo Mobile (412×915) e Desktop (1280×800) em temas Light e Dark, com renderização tipográfica legível (Roboto, MaterialSymbols e Monospace reais carregados via `FontLoader`):

| Cenário | Resolução | Tema | AE Total (Pixels) | % Diff Total | Header Diff % | Timeline Diff % | Composer Diff % | Montagem Pareada |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Short turn completed** | 412x915 | Light | 162.203 | 43,03% | 44,78% | 42,91% | 42,59% | [captures/s1_mobile_light_montage.png](captures/s1_mobile_light_montage.png) |
| **Short turn completed** | 412x915 | Dark | 162.221 | 43,03% | 44,78% | 42,91% | 42,60% | [captures/s1_mobile_dark_montage.png](captures/s1_mobile_dark_montage.png) |
| **Short turn completed** | 1280x800 | Light | 367.310 | 35,87% | 36,69% | 35,01% | 40,73% | [captures/s1_desktop_light_montage.png](captures/s1_desktop_light_montage.png) |
| **Short turn completed** | 1280x800 | Dark | 367.424 | 35,88% | 36,70% | 35,02% | 40,77% | [captures/s1_desktop_dark_montage.png](captures/s1_desktop_dark_montage.png) |
| **Rich timeline with code and reasoning** | 412x915 | Light | 240.521 | 63,80% | 44,20% | 70,13% | 42,59% | [captures/s2_mobile_light_montage.png](captures/s2_mobile_light_montage.png) |
| **Rich timeline with code and reasoning** | 412x915 | Dark | 240.544 | 63,81% | 44,20% | 70,14% | 42,60% | [captures/s2_mobile_dark_montage.png](captures/s2_mobile_dark_montage.png) |
| **Rich timeline with code and reasoning** | 1280x800 | Light | 503.090 | 49,13% | 34,94% | 52,04% | 40,73% | [captures/s2_desktop_light_montage.png](captures/s2_desktop_light_montage.png) |
| **Rich timeline with code and reasoning** | 1280x800 | Dark | 502.887 | 49,11% | 34,95% | 52,01% | 40,77% | [captures/s2_desktop_dark_montage.png](captures/s2_desktop_dark_montage.png) |
| **Empty session connected** | 412x915 | Light | 54.498 | 14,46% | 44,49% | 5,60% | 42,59% | [captures/s5_mobile_light_montage.png](captures/s5_mobile_light_montage.png) |
| **Empty session connected** | 412x915 | Dark | 54.504 | 14,46% | 44,49% | 5,60% | 42,60% | [captures/s5_mobile_dark_montage.png](captures/s5_mobile_dark_montage.png) |
| **Empty session connected** | 1280x800 | Light | 215.654 | 21,06% | 36,14% | 16,26% | 40,73% | [captures/s5_desktop_light_montage.png](captures/s5_desktop_light_montage.png) |
| **Empty session connected** | 1280x800 | Dark | 215.746 | 21,07% | 36,15% | 16,27% | 40,77% | [captures/s5_desktop_dark_montage.png](captures/s5_desktop_dark_montage.png) |

---

## 3. Classificação e Correções Realizadas por Bloco

### A. Cabeçalho (Header / AppBar)
- **Desvio Auditado:** Na v2 anterior, o AppBar exibia exclusivamente o `ServerSwitcher`, omitindo o título da sessão em navegações mobile e desktop.
- **Correção Implementada:** Integrado o título da sessão ativa com truncamento elíptico ao lado do `ServerSwitcher` (com suporte a modo compacto com dot de status em viewports reduzidas para evitar overflow em telas compactas como 390/412 px). Preservada a chave de controle determinística `live-server` e o alinhamento de densidade visual com a barra de ações.
- **Status:** Corrigido e validado com 22/22 testes em `session_route_test.dart` e 24/24 na suíte de paridade.

### B. Linha do Tempo (Timeline)
- **Desvio Auditado:** Na v2 anterior, todas as mensagens (usuário e assistente) eram renderizadas como cards simétricos estendidos em 100% da largura da tela, com padding excessivo (16 px), gerando grande disparidade visual em relação às bolhas compactas do v1.
- **Correção Implementada:**
  - Mensagens do Usuário: alinhadas à direita (`Alignment.centerRight`), largura máxima contida (85% do viewport / 640 px), raio de canto assimétrico com canto inferior direito justo (4 px) e fundo `primaryContainer` translúcido.
  - Mensagens do Assistente: alinhadas à esquerda (`Alignment.centerLeft`), largura máxima (760 px) e raio com canto inferior esquerdo justo.
  - Densidade de Padding: ajustada para `EdgeInsets.fromLTRB(14, 10, 14, 10)`, reduzindo o espaço vertical ocioso e aproximando a densidade à experiência do v1.
- **Status:** Corrigido; diff no timeline desktop caiu de 60,76% para 52,04% (redução de ~8,7 pontos percentuais) no cenário S2.

### C. Compositor (Composer)
- **Desvio Auditado:** Padding externo excessivo no rodapé (`vertical: 16`), afastando o campo de texto da timeline e ampliando o diff visual com o v1.
- **Correção Implementada:**
  - Reduzido o padding vertical do container de rodapé para `vertical: tight ? 2 : 6` e horizontal para `12`, eliminando altura vazia.
  - Preservados os controles essenciais de protocolo OpenCode v2 (seletores de agente/modelo e chips de entrega Steer/Queue) e a reatividade do botão Stop/Send.
- **Status:** Corrigido; diff do composer caiu de 47,25% para 42,59% no mobile e de 42,76% para 40,73% no desktop.

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
