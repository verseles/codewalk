# Dossiê de Evidências e Checklist de Paridade Visual — Checkpoint 5 (CP5)

**Data de Execução:** 31 de Outubro de 2026  
**Execução:** `run_20261031_cp5`  
**Escopo:** Seq 5.5 / Issue #302 — Paridade Visual e de Plataforma (CP5)  
**Ambiente:**
- Host Orquestrador (`mercury`): Ubuntu 24.04 aarch64, Flutter 3.44.1, commit `7e2bea81662dbc55cf7548bced4dd83394a76385`
- Host de Teste (`neo`): Ubuntu 26.04.1 x86_64 (KVM, i7-13650HX, RTX 4060, Flutter 3.44.1 isolado, Android SDK / Emulator API 31)
- Servidor v1: endpoint OpenCode v1 (sem auth, probe de leitura verificado)
- Servidor v2: endpoint OpenCode v2 (HTTP Basic Auth sanitizado `[REDACTED_SECRET]`, probe de leitura verificado)
- Referência v1: tag `v1.265.1` (commit `a046da262dd91dfa7d157c6f3264368f32535528`)
- Candidato v2: `main` (commit `7e2bea81662dbc55cf7548bced4dd83394a76385`)

---

## 1. Pacotes de Visualização e Teste Gerados

| Plataforma | Pacote / Binário | Host / Dispositivo | Status |
| :--- | :--- | :--- | :--- |
| **Android v1 (baseline)** | `app-x86_64-profile.apk` (`com.verseles.codewalk`) | `neo` (Emulator Pixel 5, API 31) | ✅ Instalado e Capturado |
| **Android v2 (candidato)** | `app-x86_64-profile.apk` (`com.verseles.codewalk.v2preview`) | `neo` (Emulator Pixel 5, API 31) & Galaxy S25 target | ✅ Compilado com Flutter 3.44.1, Instalado e Capturado |
| **Linux Desktop v1** | `codewalk` bundle x86_64 (Xvfb + Secret Service) | `neo` (Linux x86_64) | ✅ Executado e Capturado |
| **Linux Desktop v2** | `codewalk-v2-preview` bundle x86_64 | `neo` (Linux x86_64) | ✅ Executado e Capturado (12 telas) |

---

## 2. Matriz de Paridade Visual e Comparação Automatizada

Processados 12 pares determinísticos completos cobrindo Mobile (412×915) e Desktop (1280×800) em temas Light e Dark, com renderização tipográfica legível (Roboto, MaterialSymbols e Monospace reais carregados via `FontLoader`):

| Cenário | Resolução | Tema | AE Total (Pixels) | % Diff Total | Header Diff % | Timeline Diff % | Composer Diff % | Montagem Pareada |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Short turn completed** | 412x915 | Light | 151.360 | 40,15% | 44,78% | 39,15% | 42,59% | [captures/s1_mobile_light_montage.png](captures/s1_mobile_light_montage.png) |
| **Short turn completed** | 412x915 | Dark | 151.374 | 40,15% | 44,78% | 39,15% | 42,60% | [captures/s1_mobile_dark_montage.png](captures/s1_mobile_dark_montage.png) |
| **Short turn completed** | 1280x800 | Light | 349.917 | 34,17% | 36,69% | 32,85% | 40,73% | [captures/s1_desktop_light_montage.png](captures/s1_desktop_light_montage.png) |
| **Short turn completed** | 1280x800 | Dark | 350.024 | 34,18% | 36,70% | 32,86% | 40,77% | [captures/s1_desktop_dark_montage.png](captures/s1_desktop_dark_montage.png) |
| **Rich timeline with code and reasoning** | 412x915 | Light | 229.164 | 60,79% | 44,20% | 66,19% | 42,59% | [captures/s2_mobile_light_montage.png](captures/s2_mobile_light_montage.png) |
| **Rich timeline with code and reasoning** | 412x915 | Dark | 229.189 | 60,80% | 44,20% | 66,20% | 42,60% | [captures/s2_mobile_dark_montage.png](captures/s2_mobile_dark_montage.png) |
| **Rich timeline with code and reasoning** | 1280x800 | Light | 501.073 | 48,93% | 34,94% | 51,79% | 40,73% | [captures/s2_desktop_light_montage.png](captures/s2_desktop_light_montage.png) |
| **Rich timeline with code and reasoning** | 1280x800 | Dark | 500.875 | 48,91% | 34,95% | 51,76% | 40,77% | [captures/s2_desktop_dark_montage.png](captures/s2_desktop_dark_montage.png) |
| **Empty session connected** | 412x915 | Light | 53.660 | 14,23% | 44,49% | 5,31% | 42,59% | [captures/s5_mobile_light_montage.png](captures/s5_mobile_light_montage.png) |
| **Empty session connected** | 412x915 | Dark | 53.666 | 14,24% | 44,49% | 5,31% | 42,60% | [captures/s5_mobile_dark_montage.png](captures/s5_mobile_dark_montage.png) |
| **Empty session connected** | 1280x800 | Light | 214.817 | 20,98% | 36,14% | 16,16% | 40,73% | [captures/s5_desktop_light_montage.png](captures/s5_desktop_light_montage.png) |
| **Empty session connected** | 1280x800 | Dark | 214.909 | 20,99% | 36,15% | 16,16% | 40,77% | [captures/s5_desktop_dark_montage.png](captures/s5_desktop_dark_montage.png) |

---

## 3. Classificação e Correções Realizadas por Bloco

### A. Cabeçalho (Header / AppBar)
- **Desvio Auditado:** Na v2 anterior, o AppBar exibia exclusivamente o `ServerSwitcher`, omitindo o título da sessão em navegações mobile e desktop. Além disso, o corpo da sessão repetia rótulos redundantes ("Live session" e linha de perfil do servidor), empurrando o conteúdo da timeline para baixo.
- **Correção Implementada:**
  - Integrado o título da sessão ativa com truncamento elíptico ao lado do `ServerSwitcher` (com suporte a modo compacto com dot de status em viewports reduzidas).
  - Compactação de cabeçalho no commit `e7b8ebeb`: removidas as linhas redundantes do cabeçalho de rolagem exclusivamente para sessões saudáveis e acionáveis no workspace, elevando a primeira mensagem em ~44px. Estados degradados, somente leitura, com falha ou páginas avulsas mantêm a identificação completa.
- **Status:** Corrigido e validado com 22/22 testes em `session_route_test.dart`, 24/24 na suíte de paridade e revisão formal aprovada por 3 revisores independentes.

### B. Linha do Tempo (Timeline)
- **Desvio Auditado:** Na v2 anterior, todas as mensagens (usuário e assistente) eram renderizadas como cards simétricos estendidos em 100% da largura da tela, com padding excessivo (16 px), gerando grande disparidade visual em relação às bolhas compactas do v1.
- **Correção Implementada:**
  - Mensagens do Usuário: alinhadas à direita (`Alignment.centerRight`), largura máxima contida (85% do viewport / 640 px), raio de canto assimétrico com canto inferior direito justo (4 px) e fundo `primaryContainer` translúcido.
  - Mensagens do Assistente: alinhadas à esquerda (`Alignment.centerLeft`), largura máxima (760 px) e raio com canto inferior esquerdo justo.
  - Densidade de Padding: ajustada para `EdgeInsets.fromLTRB(14, 10, 14, 10)`, reduzindo o espaço vertical ocioso e aproximando a densidade à experiência do v1.
- **Status:** Corrigido; diff no timeline mobile (S1) reduziu de 42,91% para 39,15%, e no cenário S2 reduziu de 70,13% para 66,19%.

### C. Compositor (Composer)
- **Desvio Auditado:** Padding externo excessivo no rodapé (`vertical: 16`), afastando o campo de texto da timeline e ampliando o diff visual com o v1.
- **Correção Implementada:**
  - Reduzido o padding vertical do container de rodapé para `vertical: tight ? 2 : 6` e horizontal para `12`, eliminando altura vazia.
  - Preservados os controles essenciais de protocolo OpenCode v2 (seletores de agente/modelo e chips de entrega Steer/Queue) e a reatividade do botão Stop/Send.
- **Status:** Corrigido; diff do composer mantido estabilizado em 42,59% no mobile e 40,73% no desktop.

---

## 4. Lista Objetiva das Lacunas Restantes por Bloco

As lacunas a seguir representam divergências intencionais de arquitetura ou evoluções de contrato entre v1 e v2, registradas para avaliação do proprietário sem aplicação de novas alterações antes do sign-off:

1. **Cabeçalho (Header / AppBar):**
   - **Controles de Modelo no Topo (Desktop):** No v1 desktop, botões de atalho rápido de modelo residiam na barra superior; na v2 esses seletores foram consolidados no compositor e no drawer de configurações.
   - **Indicador de Latência:** O v1 continha medição numérica de ping em milissegundos no tooltip de conexão; a v2 adota semântica visual unificada de dot colorido e badge de estado.
2. **Linha do Tempo (Timeline):**
   - **Quebra e Destaque de Código:** O v1 utilizava blocos de código com bordas estritas de 8px e highlight.js legado; a v2 renderiza blocos via motor nativo do Flutter com cores dinâmicas Material 3 `SurfaceVariant`.
   - **Agrupamento de Execuções e Ferramentas:** Chamadas de ferramentas e sub-execuções na v2 são agrupadas em blocos retráteis/colapsáveis ("Finished work" / "Tool calls"), enquanto no v1 eram renderizadas sequencialmente em linhas estáticas.
   - **Metadados de Resposta:** Na v2, tempo decorrido de geração e contadores de tokens aparecem em subtítulo discreto sob a mensagem; no v1 ficavam restritos ao menu de detalhes.
3. **Compositor (Composer):**
   - **Chips de Controle de Protocolo v2:** A v2 apresenta chips interativos de entrega (`Steer` / `Queue`) e seletores de agente/modelo integrados à área do compositor; esses seletores não existiam no protocolo v1.
   - **Botão de Envio/Parada:** O v1 possuía botão flutuante circular elevado; a v2 adota `IconButton` integrado com animação de troca dinâmica entre Send e Stop reativo.

---

## 5. Auditoria de Defeitos de Layout e Regressões

- **Overflows:** 0 ocorrências detectadas em toda a suíte (24 testes de tela completa executados sem exceções).
- **Responsividade:** O layout adapta-se fluidamente de 412 px (largura mobile retrato) a 1280 px (desktop estendido).
- **Temas:** Suporte determinístico verificado em Light e Dark modes sem inversão de contraste.
- **Contratos:** Preservados scroll, outbox de rascunhos, foco do teclado e atalhos de navegação.

---

## 6. Checklist de Paridade para Sign-off do CP5

- [x] P0: Preflight, verificação de proveniência e integridade dos ambientes `mercury` e `neo`.
- [x] P1: Primeiro par determinístico v1 × v2 capturado, medido e validado com dados populados.
- [x] P2: Suíte de paridade com fontes e ícones reais legíveis (Roboto + MaterialSymbols) comprovados por OCR.
- [x] P3: Comparador determinístico estrito (`compare_parity.py`) com validação de dimensões e 10 unit tests aprovados.
- [x] P4: Classificação e documentação dos desvios visuais por blocos (Header, Timeline, Composer).
- [x] P5: Entrega completa das evidências e do candidato para avaliação do proprietário.
- [ ] **Portão Humano (Sign-off Formal do Proprietário):** Pendente inspeção e aceite explícito do proprietário para o CP5; beta v2.0.0-beta.1 NÃO publicado.

---
*Dossiê gerado e preservado em `evidence/cp5/`.*
