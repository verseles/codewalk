# CP5 — comparação visual v1 × v2: plano de execução

**Estado:** plano para execução futura. Este arquivo não autoriza iniciar uma etapa, fazer push, publicar beta ou declarar o CP5 aceito. O dono solicitará a execução em outro turno. Execute uma unidade por vez, conforme `AGENTS.md` e `v2-plan.md` §11.6.

**Objetivo:** identificar automaticamente as diferenças visuais da tela inteira do chat da v2 em relação à v1, corrigir os desvios pertencentes ao MVP e entregar evidências Android e Linux para o dono avaliar o CP5. A referência é a experiência da v1; protocolos, dados e armazenamento da v1 não são migrados para a v2.

## 1. Limites e evidência já obtida

- Linha: `main`, CP5/Seq 5.5, issue #302; mapear comportamento e decisões na issue #446. As etapas 5.4a–5.4c e o plano v2 definem o escopo. Não implementar itens `after-mvp` nem mudar o roteiro sem a decisão exigida em §11.6/§17.
- Tela autorizada: chat completo — estrutura, cabeçalho, timeline, composer, controles e menus que aparecem nesse contexto. Incluir Android e desktop Linux. Settings, onboarding e outras telas entram somente como caminho necessário para chegar ao chat, não como trabalho visual adicional.
- Referência v1: tag anotada `v1.265.1`, objeto `2adde8136c45badc2baa1eec7c9a44c91e28d368`, **commit apontado** `a046da262dd91dfa7d157c6f3264368f32535528`. Não confundir o objeto da tag com o commit. A referência v2 testada é `c74a4550b9757c61d1d3d49912fc1bfe985df412`; registrar o HEAD real ao iniciar e reavaliar se mudou.
- `neo`: Linux x86_64, i7-13650HX, RTX 4060 e KVM acessível. ADB, SDK Android e Flutter estão disponíveis; o emulador e a imagem Android 12/API 31 x86_64 foram instalados durante o smoke. A máquina de orquestração é ARM; não compilar APK nela. O CI hospedado não está na tailnet.
- O smoke comprovou: apps v1 e v2 abrem e produzem imagens iniciais no Android API 31 e no Linux x64; o emulador alcança os dois servidores. Não comprovou chat autenticado, paridade, funcionamento no Galaxy S25 ou no Linux ARM64.
- A v1 Android x86_64 foi compilada com Flutter 3.47.4 e cinco diferenças de lockfile em relação à tag. A prévia v2 foi compilada com Flutter 3.44.1. Essas imagens são diagnósticas; **não alegar comparação pixel a pixel controlada** até registrar e resolver as diferenças de engine, fonte, dependências e renderização.
- A v1 Linux precisou de Xvfb e Secret Service isolado. Uma captura inicial pegou a janela preta do Xvfb e outra tentativa teve timeout de keyring; apenas a captura final, associada ao PID da aplicação e não vazia, é válida.
- As evidências de smoke estão em `/tmp/opencode` local e no `neo`; são temporárias. Não tratá-las como único registro durável nem como prova de paridade. Nenhum dado pessoal ou credencial deve ser enviado ao CI ou versionado.

## 2. Regras para o executor

1. Ao receber autorização para executar, carregue as regras e a Task Memory conforme `AGENTS.md`; subagentes nunca acessam `.task-memory`. Consulte o estado ativo e a próxima ação antes de cada unidade. O snapshot da Task Memory acompanha cada commit CodeWalk pelo orquestrador.
2. Inspecione `BEHAVIOR.md`, ADR-023/ADR-058, `v2-plan.md` §11.6 e as issues #302/#446/#453/#454/#455/#398 antes de alterar comportamento. Preserve scroll, drafts, seletores, acessibilidade, interações e os contratos oficiais da implementação v2.
3. Trabalhe em `main` no workspace principal. Use cópias ou worktrees **isoladas** para construir a referência v1; não troque a branch ativa, não mescle árvores e não edite o código v1 como correção da v2. Preserve todas as alterações preexistentes; `goal-codewalk-cp5.txt` era um arquivo não rastreado do usuário no planejamento e não pertence a este trabalho.
4. Use apenas perfis, sessões, diretórios, dispositivos e processos de teste identificados como próprios. Não use conversas pessoais como fixture, não substitua apps instalados do usuário e não elimine dados ou processos cuja propriedade não seja comprovada. Sessões descartáveis novas devem ser explicitamente identificadas; não apague nada no servidor automaticamente.
5. Credenciais e URLs privadas entram somente em configuração local segura ou entrada protegida. Nunca as grave neste arquivo, no código, na Task Memory, em logs, capturas, nomes de arquivos, relatórios públicos ou CI. Não adicione CI à tailnet nem altere infraestrutura Coolify para esta tarefa.
6. Faça primeiro o menor caminho demonstrável de ponta a ponta. Um erro de ambiente ou fixture deve ser corrigido na preparação antes de classificá-lo como erro da v2. Após três tentativas fracassadas para a mesma causa, pare e registre a hipótese duvidosa.

## 3. P0 — preflight e proveniência

**Entrada:** pedido explícito do dono para executar esta unidade. **Saída:** fontes, ambiente e destino das evidências identificados; nenhuma comparação ainda é considerada aprovada.

```bash
source ~/paths
rtk git branch --show-current
rtk git status --short
rtk git rev-parse HEAD 'v1.265.1^{commit}'
export PATH="$HOME/flutter/bin:$PATH"
flutter --version --machine
```

1. Confirme `main`, ausência de operação Git em andamento, origem exata da v1 e SHA atual da v2. Se houver mudanças não relacionadas, não as sobrescreva; isole o estágio. Verifique as issues e a elegibilidade da linha CP5 pelo `gh-helper`.
2. Registre host, arquitetura, OS, versão/revisão Flutter e engine, hashes de `pubspec.lock`, binários e fixtures, modo de build, renderer, resolução física/lógica, DPR, escala de texto, fontes, tema, idioma, estado do teclado e hora. Não confunda a versão registrada no relatório do CI (Ubuntu 24.04) com o host real `neo` (Ubuntu 26.04.1 observado no smoke).
3. Use as URLs fornecidas pelo dono a partir da configuração local segura; a v1 não exige senha e a v2 exige autenticação. Faça apenas probes de leitura para comprovar alcance e versão. Uma resposta 401 sem autenticação prova rota, não login nem chat funcional.
4. Escolha um diretório privado e durável fora do repositório para as evidências desta execução, por exemplo `<EVIDENCE_ROOT>/codewalk-cp5/<RUN_ID>/`. `<EVIDENCE_ROOT>` e `<RUN_ID>` são parâmetros a definir, não caminhos existentes. Restrinja permissões; mantenha imagens, manifests e relatórios sintéticos separados das capturas reais. Não use `/tmp` como única cópia.
5. Gere um manifesto de proveniência dos pares e hashes. Ele descreve as imagens e não substitui GitHub Issues nem Task Memory como controle do trabalho. Interrompa o caminho dependente se versão, janela, perfil, dispositivo ou origem do binário não puder ser comprovada.

## 4. P1 — primeiro par de chat confiável

**Entrada:** P0 concluído. **Saída:** um par de tela completa v1/v2, no mesmo estado, repetível e com proveniência suficiente para interpretar as diferenças.

1. Comece com **um cenário**: chat conectado, um turno concluído com texto curto e composer vazio. Escolha idioma e tema iguais; capture primeiro Android API 31 em retrato e Linux x64 em janela larga. Não marque as capturas de onboarding do smoke como chat.
2. Prepare fontes e binários separados. Para comparação determinística, prefira construir os dois lados com a mesma revisão Flutter/engine e locks verificados. O CI da v2 fixa Flutter `3.44.1` na revisão `924134a44c189315be2148659913dda1671cbe99`; verifique se a v1 compila com esse SDK sem alteração inesperada de dependências. O dono permite atualizar o Flutter existente se for necessário; registre qualquer mudança e preserve a rastreabilidade. Se não houver combinação comum reproduzível, mantenha o par como **diagnóstico** e registre a diferença; não esconda o problema.
3. Use a v1 empacotada e o candidato v2 empacotado como referência adicional da experiência real. Versões diferentes de engine são propriedades dos binários reais; identifique essa diferença no manifesto e confirme com o par controlado antes de atribuir um desvio ao layout.
4. Inspecione antes de implementar: `v1.265.1:test/support/chat_page_test_harness.dart`, os testes v1 do chat e `test/v2/sessions/`, em particular `session_live_timeline_golden_test.dart` e `composer_input_golden_test.dart`. Os goldens atuais são da v2 e não estabelecem paridade com a v1. Monte **as telas reais** com fixtures sintéticas equivalentes em cada linha, sem importar dados ou protocolo v1 para v2. Não substitua a tela real por uma demonstração simplificada.
5. Fixe conteúdo, modelo/agente exibido, relógio, timestamps, idioma, tema, fonte, escala, viewport, foco, animações, scroll e estado de rede. Faça três capturas independentes do mesmo estado por versão e plataforma. Compare as repetições da mesma versão para medir ruído antes de comparar v1 × v2.
6. Não presuma que uma saída de modelo seja igual nos dois servidores. Use conteúdo sintético controlado para comparação estrita. Use os servidores reais em smoke separado, com sessões de teste independentes, somente para comprovar autenticação, alcance, interação e visualização; registre diferenças de conteúdo como tais. Nunca escreva em sessões pessoais.
7. Para inspeção visual e tipográfica, carregue explicitamente uma fonte real **legível** e equivalente nos dois lados; verifique nas imagens produzidas que textos e ícones são reconhecíveis. Capturas com Ahem, texto em blocos ou glifos ausentes servem apenas para regressão geométrica e não substituem as capturas legíveis nem o teste nativo. Preserve as séries Ahem existentes para seu propósito original.
8. Antes de capturar, comprove por estado e asserções que as duas telas mostram os mesmos itens e o mesmo cenário — inclusive mensagens, estado da sessão, navegação e scroll. Se um lado estiver vazio, carregando ou exibir conteúdo diferente do esperado, rejeite o par e corrija a fixture; não atribua a diferença ao produto.

Para reproduzir os binários no `neo`, obtenha primeiro fontes isoladas com as revisões de P0, fora da árvore sincronizada e sem copiar `.task-memory` ou `.env`. Estes comandos foram identificados no projeto; execute-os apenas no diretório da versão indicada, com o SDK definido e registrado no P1:

```bash
# Na cópia isolada da v1, no host x86_64; verificar mudanças no lock antes/depois.
source ~/paths
export PATH="$HOME/flutter/bin:$PATH"
flutter pub get
flutter build apk --profile --target-platform android-x64 --split-per-abi
make desktop

# Na cópia isolada da v2, no host x86_64.
source ~/paths
export PATH="$HOME/flutter/bin:$PATH"
make v2-linux-debug
make v2-linux-preview-package
make v2-android-preview
```

O APK x86_64 v1 usado no smoke saiu de `build/app/outputs/flutter-apk/app-x86_64-profile.apk`; o split v2 tem o mesmo nome **em sua própria árvore** e usa o pacote isolado `com.verseles.codewalk.v2preview`. O APK publicado da v1 é ARM64 e não substitui o split x86_64 do emulador. `make android` da v1 exige configuração de assinatura de release: não use esse alvo para gerar o artefato de teste. Trate qualquer alteração de lockfile como evidência de incompatibilidade a investigar, sem versionar a mudança da v1.

## 5. P2 — capturas nativas e catálogo de cenários

**Entrada:** primeiro par estável. **Saída:** catálogo e pares verificáveis para as áreas do chat; cada cenário tem ID, dados sintéticos, pré-condição, ação, resolução, plataforma, estado esperado e vínculo com #446.

Amplie nesta ordem, sem iniciar um novo bloco de correções automaticamente:

1. **Estrutura:** chat vazio/conectado, carregamento, cabeçalho, abas, painel/drawer e panes desktop; janelas larga e estreita.
2. **Timeline:** bolhas de usuário e resposta curta/longa, Markdown e código, raciocínio, grupos de ferramentas, erro e aviso. Registre estados expandido/recolhido quando aplicáveis ao MVP.
3. **Composer:** vazio, preenchido e multilinha; Send/Stop, status, foco e teclado; seletores de agente, modelo e variante, favoritos/recentes e picker de comandos aplicáveis.
4. **Interações:** permissões/formulários e ações de turno já incluídas nas linhas 5.4a–5.4c. Valide também que o controle responde; uma imagem não prova comportamento.
5. **Variações:** claro/escuro, retrato/landscape, largura compacta/desktop, texto ampliado e RTL nos cenários em que alteram o layout. API 31 cobre o piso Android 12; o Galaxy S25 e Linux ARM64 continuam verificações próprias, não substituídas pelo x86.

No Android, use um AVD descartável de propriedade do teste e identifique o serial antes de cada comando. O smoke existente usa o split x86_64 da prévia. Com um serial real, a captura nativa é:

```bash
source ~/paths
adb -s <SERIAL_DO_AVD> exec-out screencap -p > <CAPTURA_PNG>
```

No Linux, use janela Xvfb isolada, perfil `HOME`/XDG e Secret Service temporários. Confira que o PID, título/classe e geometria pertencem ao app antes de capturar; rejeite root window, imagem vazia ou janela de outro processo. Reaproveite `tool/ci/smoke_v2_linux_preview.py` e `tool/preview/preview_linux.py` como referências para isolamento e limpeza, mas não alegue que o smoke atual navega em chat autenticado. Não controle a sessão gráfica pessoal do dono.

Antes de persistir ou compartilhar imagens reais, inspecione e remova dados particulares e credenciais sem ocultar controles ou defeitos do chat. Mantenha capturas reais privadas. Salve somente fixtures sintéticas revisadas e seus manifests em arquivos de teste versionados.

## 6. P3 — comparar e classificar automaticamente

**Entrada:** pares íntegros com o mesmo cenário e geometria. **Saída:** relatório reproduzível com v1, v2, sobreposição, diff e lista ordenada de regiões divergentes.

1. Rejeite pares com tamanho, cenário ou metadados incompatíveis. Não redimensione, alinhe artificialmente ou recorte o chat para fazer o teste passar.
2. Reaproveite ImageMagick/Tesseract já presentes no `neo` quando adequados. Produza imagens lado a lado, overlay e heatmap, contagem/proporção de pixels alterados e caixas das regiões; OCR ajuda a localizar texto, não decide se o conteúdo está correto. Escreva um pequeno comparador/testes apenas se as ferramentas existentes não entregarem esse resultado; registre seus comandos reais após implementá-los.
3. Calibre o ruído por plataforma com as três repetições do P1. Classifique diferenças consistentes por área, recorrência e impacto: controle ausente/cortado primeiro, geometria repetida depois, cores e detalhes por último. Não adote um percentual arbitrário como aceite de CP5.
4. Masque somente áreas comprovadamente não determinísticas ou do sistema, com motivo, coordenadas, dono e imagem original preservada. Não mascare composer, textos, controles, clipping ou erro de layout. O relatório deve mostrar também a tela inteira sem máscara.
5. Para cada diferença, identifique cenário, bloco, provável arquivo, evidência v1/v2, linha da issue #446 e classificação: defeito visual do MVP, comportamento divergente, ruído ou fora de escopo. Não peça ao dono que catalogue cada defeito; revise os resultados automaticamente produzidos e investigue os ambíguos.
6. O comparador deve receber os diretórios de entrada e saída por parâmetros, sem caminhos absolutos fixos de uma máquina. Use referências relativas ao diretório do relatório ou registre um manifesto portátil; valide que todos os caminhos referenciados existem.
7. Falhe explicitamente, com saída não zero e diagnóstico, se faltar qualquer imagem ou cenário obrigatório, houver imagem vazia/malformada, dimensões ou metadados incompatíveis, falhar um comando de recorte/montagem/comparação ou a métrica não puder ser lida. No ImageMagick `compare`, código 1 pode significar imagens diferentes; código 2 ou erro de execução é falha. **Nunca converta erro em 0%**, nunca omita um par ausente silenciosamente e nunca apresente relatório incompleto como sucesso.
8. Teste o comparador com imagens sintéticas: pares iguais e diferentes, entrada ausente, PNG inválido, dimensões incompatíveis, ferramenta ausente ou com erro e saída de métrica inválida. Confirme sucesso apenas para entradas válidas e falha explícita para cada caso inválido.
9. Audite o dossiê e o relatório existentes em `evidence/cp5/` antes de reutilizá-los. Remova credenciais e URLs privadas antes de versionar; corrija caminhos antigos e desmarque conclusões ou itens de checklist que não tenham evidência. Não classifique uma diferença como intencional apenas por citar arquitetura ou protocolo: associe-a à decisão do dono e à linha aplicável de #446. Preserve separadamente os resultados de smoke realmente comprovados.

## 7. P4 — corrigir e revisar por bloco

**Entrada:** relatório reproduzível com uma causa confirmada dentro do escopo. **Saída:** um bloco corrigido, testes aprovados, commit e revisão convergida.

1. Escolha primeiro a causa de maior impacto; agrupe ocorrências causadas pelo mesmo componente. Inspecione a implementação v1 e v2 antes de editar. Corrija apenas a v2 e preserve os contratos de comportamento; não copie rotas ou armazenamento v1.
2. Acrescente ou atualize testes relevantes para o comportamento corrigido e compare novamente os pares afetados. Não regenere goldens v2 para esconder a diferença; atualize somente após compreender e revisar a mudança intencional.
3. Execute testes focados e `flutter analyze` nos caminhos alterados. No gate estável anterior ao primeiro commit do estágio, execute `make check` com Flutter no PATH. O teste completo já atingiu o limite padrão de 10 minutos neste workspace; se necessário, use `rtk make check TEST_TIMEOUT=20m` e registre o resultado. Não use `make precommit` para validação normal CodeWalk.
4. Inspecione o diff, stageie somente os arquivos do estágio e o snapshot obrigatório da Task Memory, e faça o commit local de fronteira conforme as regras vigentes. Carregue `reviewer`, use todos os helpers elegíveis e aplique apenas achados confirmados. MiniMax está excluído por decisão do dono até nova instrução. Revalide correções e faça re-review quando a mudança for significativa.
5. Atualize documentação de comportamento somente depois de código e revisão. Não crie `ROADMAP.md` ou `CODEBASE.md`. Não faça push, release, tag, publicação ou instalação em aparelho pessoal sem a autorização aplicável à execução. Registre o estado e pare no limite da unidade solicitada.

## 8. P5 — entrega e aceite humano

**Entrada:** estágio revisado, validação concluída e candidato rastreável ao SHA testado.

- Entregue um índice simples com cenários cobertos, pares v1/v2, diferenças corrigidas, diferenças restantes, limitações e proveniência. Verifique se o candidato empacotado corresponde ao commit validado.
- Execute smoke nativo nos ambientes disponíveis; mantenha explícitos API 31, Galaxy S25, Linux x64 e Linux ARM64. CI sem tailnet pode verificar fixtures e testes offline, mas não prova a conexão com os servidores privados.
- O dono avalia o candidato e o checklist visual CP5 em #302. Capturas, métricas, testes verdes ou opinião dos helpers não equivalem ao aceite. Mudanças de escopo ou destino em #446 seguem a decisão do dono.
- Após a unidade, registre evidências e próxima ação na Task Memory. Se CP5 não tiver aceite explícito, mantenha-o pendente e não avance automaticamente para beta.

## 9. Primeiro passo quando autorizado

Execute P0, registre o SHA atual e confirme o commit apontado por `v1.265.1`. Depois determine a combinação de Flutter/locks para P1 e produza **um único par comparável** antes de automatizar toda a matriz. Se uma premissa falhar, registre o que foi comprovado e interrompa apenas a etapa dependente; não apresente a ausência de evidência como sucesso.
