// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get aboutGitHub => 'GitHub';

  @override
  String get appProviderCannotActivateUnhealthy =>
      'Não é possível ativar um servidor não saudável';

  @override
  String get appProviderDesktopOnly =>
      'O servidor local gerenciado está disponível apenas no desktop.';

  @override
  String get appProviderDetectingCommand => 'Detectando comando OpenCode...';

  @override
  String get appProviderErrorCannotActivateUnhealthy =>
      'Não é possível ativar um servidor não saudável';

  @override
  String get appProviderErrorCloudflareOAuthNotSupported =>
      'Cloudflare Access OAuth não é suportado nesta plataforma';

  @override
  String get appProviderErrorInstallationFailed =>
      'A instalação do OpenCode falhou.';

  @override
  String get appProviderErrorInvalidServerUrl => 'URL do servidor inválida';

  @override
  String get appProviderErrorLocalServerHealthCheckFailed =>
      'O servidor local iniciou, mas a verificação de integridade não passou.';

  @override
  String get appProviderErrorManagedDesktopOnly =>
      'O servidor local gerenciado está disponível apenas no desktop.';

  @override
  String get appProviderErrorServerAlreadyExists =>
      'Um servidor com esta URL já existe';

  @override
  String get appProviderErrorServerProfileNotFound =>
      'Perfil de servidor não encontrado';

  @override
  String get appProviderErrorServerUrlRequired =>
      'A URL do servidor é obrigatória';

  @override
  String get appProviderErrorTailscaleNotSupported =>
      'Tailscale não é suportado nesta plataforma';

  @override
  String appProviderExitedWithCode(int code) {
    return 'O servidor local saiu com o código $code.';
  }

  @override
  String get appProviderFailedToStart =>
      'Falha ao iniciar o servidor OpenCode local.';

  @override
  String get appProviderInstallBinary => 'Instalar binário';

  @override
  String get appProviderInstallBunOpenCode => 'Instalar Bun + OpenCode';

  @override
  String get appProviderInstallSucceeded => 'Instalação bem-sucedida.';

  @override
  String appProviderInstallSucceededWithPath(String path) {
    return 'Instalação bem-sucedida. Comando OpenCode disponível em $path.';
  }

  @override
  String get appProviderInstallViaBun => 'Instalar via Bun';

  @override
  String get appProviderInstallViaNpm => 'Instalar via npm';

  @override
  String get appProviderInstallationFailed =>
      'A instalação do OpenCode falhou.';

  @override
  String get appProviderInstalledSuccessfully =>
      'Requisitos do OpenCode instalados com sucesso.';

  @override
  String get appProviderInstallingRequirements =>
      'Instalando requisitos do OpenCode...';

  @override
  String get appProviderInvalidServerUrl => 'URL do servidor inválida';

  @override
  String get appProviderLabelLocalOpenCodeManaged =>
      'OpenCode Local (Gerenciado)';

  @override
  String get appProviderLabelPrimaryServer => 'Servidor primário';

  @override
  String get appProviderLocalManaged => 'OpenCode Local (Gerenciado)';

  @override
  String get appProviderLocalServerStopped => 'O servidor local está parado.';

  @override
  String get appProviderNotDetectedInstall =>
      'O comando OpenCode não foi detectado. Execute a instalação a partir do assistente.';

  @override
  String appProviderNotDetectedRefresh(String appName) {
    return 'O comando OpenCode não foi detectado. Se você o instalou há pouco tempo, atualize as verificações ou reabra o $appName para recarregar o PATH.';
  }

  @override
  String get appProviderOAuthNotSupported =>
      'Cloudflare Access OAuth não é suportado nesta plataforma';

  @override
  String get appProviderOpenCodeDetected => 'OpenCode detectado';

  @override
  String get appProviderOpenCodeNotDetected => 'OpenCode não detectado';

  @override
  String get appProviderPrimaryServer => 'Servidor primário';

  @override
  String get appProviderProfileNotFound => 'Perfil de servidor não encontrado';

  @override
  String get appProviderRunDiagnostics =>
      'Execute diagnósticos para verificar os requisitos locais do OpenCode.';

  @override
  String appProviderRunningAt(String url) {
    return 'Rodando em $url';
  }

  @override
  String get appProviderSetupDetectingOpenCode =>
      'Detectando comando OpenCode...';

  @override
  String get appProviderSetupInstallationSucceeded =>
      'Instalação bem-sucedida.';

  @override
  String appProviderSetupInstallationSucceededWithPath(String path) {
    return 'Instalação bem-sucedida. Comando OpenCode disponível em $path.';
  }

  @override
  String get appProviderSetupInstallingRequirements =>
      'Instalando requisitos do OpenCode...';

  @override
  String get appProviderSetupOpenCodeDetected => 'OpenCode detectado';

  @override
  String get appProviderSetupOpenCodeNotDetected => 'OpenCode não detectado';

  @override
  String get appProviderSetupOpenCodeNotDetectedInstall =>
      'O comando OpenCode não foi detectado. Execute a instalação a partir do assistente.';

  @override
  String get appProviderSetupOpenCodeNotDetectedRefresh =>
      'O comando OpenCode não foi detectado. Se você o instalou há pouco tempo, atualize as verificações ou reabra o CodeWalk para recarregar o PATH.';

  @override
  String get appProviderSetupRequirementsInstalled =>
      'Requisitos do OpenCode instalados com sucesso.';

  @override
  String appProviderSetupUsingOpenCodeAt(String path) {
    return 'Usando comando OpenCode em $path';
  }

  @override
  String get appProviderStartingLocalServer => 'Iniciando servidor local...';

  @override
  String appProviderStatusLocalServerExitedWithCode(int code) {
    return 'O servidor local saiu com o código $code.';
  }

  @override
  String get appProviderStatusLocalServerStopped =>
      'O servidor local está parado.';

  @override
  String appProviderStatusRunningAt(String url) {
    return 'Rodando em $url';
  }

  @override
  String get appProviderStatusStartingLocalServer =>
      'Iniciando servidor local...';

  @override
  String get appProviderStatusStoppingLocalServer =>
      'Parando servidor local...';

  @override
  String get appProviderStoppingLocalServer => 'Parando servidor local...';

  @override
  String get appProviderTailscaleNotSupported =>
      'Tailscale não é suportado nesta plataforma';

  @override
  String appProviderUsingCommandAt(String path) {
    return 'Usando comando OpenCode em $path';
  }

  @override
  String get appShellDownloadingUpdate => 'Baixando atualização';

  @override
  String get appShellInstall => 'Instalar';

  @override
  String get appShellInstallFailed => 'Falha na instalação';

  @override
  String get appShellInstallingUpdate => 'Instalando atualização...';

  @override
  String get appShellRestart => 'Reiniciar';

  @override
  String appShellUpdateAvailableResult(String latestVersion) {
    return 'Atualização disponível: v$latestVersion';
  }

  @override
  String get appShellUpdateInstalledRestartApp =>
      'Atualização instalada. Reinicie o aplicativo para aplicar.';

  @override
  String get appShellUpdateInstalledRestartRequired =>
      'Atualização instalada. Reinicialização necessária para aplicar a nova versão.';

  @override
  String get attachmentCouldNotDecode =>
      'Não foi possível decodificar os dados do anexo.';

  @override
  String get attachmentCouldNotDownload => 'Não foi possível baixar o anexo.';

  @override
  String get attachmentCouldNotSave =>
      'Não foi possível salvar o anexo neste dispositivo.';

  @override
  String get attachmentDownloadStarted => 'O download do anexo começou.';

  @override
  String get attachmentLocalNotFound =>
      'O anexo local não foi encontrado neste dispositivo.';

  @override
  String get attachmentNoValidLocation =>
      'O anexo não fornece um local válido.';

  @override
  String get attachmentNotAvailableOnPlatform =>
      'As ações de anexo não estão disponíveis nesta plataforma.';

  @override
  String get attachmentPathEmpty => 'O caminho do anexo está vazio.';

  @override
  String get attachmentPayloadEmpty => 'A carga útil do anexo está vazia.';

  @override
  String get attachmentSaveCanceled => 'Salvamento cancelado.';

  @override
  String attachmentSavedAndOpened(String path) {
    return 'Anexo salvo em $path e aberto.';
  }

  @override
  String attachmentSavedPath(String path) {
    return 'Anexo salvo em $path.';
  }

  @override
  String attachmentSavedTo(String path) {
    return 'Anexo salvo em $path.';
  }

  @override
  String get attachmentUnableToOpenLink =>
      'Não foi possível abrir o link do anexo.';

  @override
  String get attachmentUnableToOpenLocal =>
      'Não foi possível abrir o anexo local.';

  @override
  String get behaviorAdvancedPermissionRule => 'Regra de permissão avançada';

  @override
  String get behaviorAutomatic => 'Automático';

  @override
  String get behaviorAutomaticFallback => 'Fallback automático';

  @override
  String get behaviorCellularDataSaver => 'Economia de dados móveis';

  @override
  String get behaviorCellularDataSaverActive =>
      'O economizador de dados móveis está ativo.';

  @override
  String get behaviorChatLevelShare => 'Compartilhamento em nível de chat';

  @override
  String get behaviorCodeWalkReleaseChecks =>
      'Verificações de versão do CodeWalk';

  @override
  String get behaviorControlsOfficialGlobal =>
      'Controla as configurações globais oficiais do OpenCode';

  @override
  String get behaviorControlsUpstreamOpenCode =>
      'Controla as configurações do OpenCode upstream';

  @override
  String get behaviorCustomDisplayName => 'Nome de exibição personalizado';

  @override
  String behaviorCutsAutomaticMobile(int inSeconds) {
    return 'Reduz o uso automático de dados móveis parando downloads em segundo plano e limitando as atualizações automáticas em primeiro plano a uma rajada a cada $inSeconds segundos.';
  }

  @override
  String get behaviorDataSaverActive => 'Ativo agora em dados móveis.';

  @override
  String get behaviorDataSaverAggressive => 'Agressivo';

  @override
  String get behaviorDataSaverAggressiveDescription =>
      'Modo de baixa largura de banda: apenas o fluxo do workspace visível permanece ao vivo, as atualizações globais são pausadas e as atualizações automáticas ficam espaçadas.';

  @override
  String get behaviorDataSaverCellularOnly =>
      'Aplica-se apenas quando a conexão é celular/móvel.';

  @override
  String get behaviorDataSaverOff => 'Desligado';

  @override
  String get behaviorDataSaverOffHint =>
      'Tempo real completo e atualizações automáticas estão habilitados.';

  @override
  String get behaviorDataSaverStandard => 'Padrão';

  @override
  String get behaviorDataSaverWaiting =>
      'Aguardando a próxima janela de sincronização de dados móveis.';

  @override
  String get behaviorDisabled => 'Desativado';

  @override
  String get behaviorLightweightTasksLike => 'Tarefas leves como';

  @override
  String get behaviorManual => 'Manual';

  @override
  String get behaviorNotify => 'Notificar';

  @override
  String get behaviorOfficialOpenCodePermission =>
      'A política oficial de permissão do OpenCode é configurada no `opencode.json` com regras allow/ask/deny por ferramenta. O CodeWalk mantém os cards oficiais de solicitação de permissão e adiciona uma exceção ADR-023 aprovada: o toggle de auto-aprovação do composer responde com `Always` e `remember: true` incondicionalmente para criar concessões duráveis com escopo de sessão, e mantém o mesmo caminho de continuidade com escopo de thread ativo no worker Android em segundo plano.';

  @override
  String get behaviorOpenCodeBackedDefaults => 'Padrões baseados no OpenCode';

  @override
  String get behaviorPermissionHandlingProvenance =>
      'Procedência do tratamento de permissões';

  @override
  String get behaviorPermissionsVariantReasoning =>
      'As permissões e a paridade de variantes/raciocínio permanecem separadas até que a UI possa preservar configurações avançadas com segurança.';

  @override
  String get behaviorPrimaryAgentAgent =>
      'Agente principal usado quando nenhum agente é escolhido explicitamente.';

  @override
  String get behaviorRefreshDefaults => 'Atualizar padrões';

  @override
  String get behaviorSharedAcrossOpenCode =>
      'Compartilhado entre clientes OpenCode por meio da configuração.';

  @override
  String get behaviorTheseValuesWrite =>
      'Esses valores são gravados em `/config` no servidor ativo e correspondem à configuração global compartilhada do OpenCode.';

  @override
  String get cannedAddTitle => 'Adicionar resposta rápida';

  @override
  String get cannedAppendAtCursor => 'Anexar ao cursor';

  @override
  String get cannedAppendAtCursorSubtitle =>
      'Desligado = substituir texto atual';

  @override
  String get cannedAttachFiles => 'Anexar arquivos';

  @override
  String get cannedEditTitle => 'Editar resposta rápida';

  @override
  String get cannedNewQuickReply => 'Nova resposta rápida';

  @override
  String get cannedNoSuggestions => 'Nenhuma sugestão';

  @override
  String get cannedOffMeansReplace =>
      'Desativado significa substituir o texto atual do composer';

  @override
  String get cannedQuickReply => 'Nova resposta rápida';

  @override
  String get cannedReplace => 'Substituir';

  @override
  String get cannedScopeGlobalSubtitle =>
      'Desativar para item apenas do projeto';

  @override
  String get cannedScopeGlobalUnavailableSubtitle =>
      'Apenas projeto indisponível neste contexto';

  @override
  String get cannedSendAutomaticallySubtitle =>
      'Enviar imediatamente após inserir';

  @override
  String get cannedSendImmediatelyInserting =>
      'Enviar imediatamente após inserir esta resposta rápida';

  @override
  String get cannedTextLabel => 'Texto';

  @override
  String get chatActionNext => 'Próximo';

  @override
  String get chatActiveServerUnhealthy =>
      'O servidor ativo não está saudável. Os envios tentarão uma vez e falharão rapidamente até a recuperação.';

  @override
  String get chatActiveServerUnhealthyLabel =>
      'Servidor ativo não está saudável';

  @override
  String get chatAddServerToStart =>
      'Adicione um servidor para começar a conversar.';

  @override
  String get chatAppBarMoreActions => 'Mais ações';

  @override
  String get chatAppBarPinAction => 'Fixar na barra do app';

  @override
  String get chatAppBarPinDescription =>
      'Esta ação permanecerá visível fora do menu.';

  @override
  String get chatAppBarUnpinAction => 'Desafixar da barra do app';

  @override
  String get chatAppBarUnpinDescription =>
      'Esta ação voltará para dentro do menu.';

  @override
  String chatBadgeConversationError(String title) {
    return '\"$title\" tem um erro.';
  }

  @override
  String chatBadgeConversationNeedsInput(String title) {
    return '\"$title\" precisa da sua intervenção.';
  }

  @override
  String chatBadgeConversationNewReply(String title) {
    return '\"$title\" tem uma nova resposta.';
  }

  @override
  String get chatBadgeDataSaverActive =>
      'A economia de dados móveis está ativa.';

  @override
  String get chatBadgeServerNeedsAttention =>
      'A conexão do servidor precisa de atenção.';

  @override
  String get chatBadgeSyncing => 'Sincronizando conversas...';

  @override
  String get chatBlockResponsePendingDescription =>
      'A resposta aparecerá como um único bloco quando este turno terminar.';

  @override
  String get chatBlockResponsePendingTitle => 'Gerando resposta';

  @override
  String get chatCachedConversationsYet => 'Nenhuma conversa em cache ainda';

  @override
  String get chatChangedFilesAvailable =>
      'Nenhum arquivo alterado está disponível para esta sessão.';

  @override
  String chatChildrenChatProviderCurrentSessionChildren(int length) {
    return 'Filhos: $length';
  }

  @override
  String get chatChooseAgent => 'Selecionar agente';

  @override
  String get chatChooseDirectory => 'Escolher diretório';

  @override
  String get chatChooseEffort => 'Escolher esforço';

  @override
  String get chatChooseFolderOpen =>
      'Escolha uma pasta para abrir como contexto do projeto.';

  @override
  String get chatChooseModel => 'Escolher modelo';

  @override
  String get chatClose => 'Fechar';

  @override
  String chatCloseProject(String project) {
    return 'Fechar $project';
  }

  @override
  String get chatCollapseGroup => 'Recolher grupo';

  @override
  String get chatCommandDescriptionProject => 'Comando do projeto';

  @override
  String get chatCommandSourceGeneric => 'comando';

  @override
  String get chatCommandSourceProject => 'projeto';

  @override
  String get chatCompactContext => 'Compactar Contexto';

  @override
  String get chatComposerHintShell => 'Comando shell (Esc para sair)';

  @override
  String get chatComposerPlaceholder => 'Digite suas necessidades...';

  @override
  String get chatConversation => 'Conversa';

  @override
  String get chatConversations => 'Conversas';

  @override
  String get chatConversationsPane => 'Conversas';

  @override
  String chatCostLabel(double cost) {
    return 'Custo: \$$cost';
  }

  @override
  String get chatCouldNotRefreshSession =>
      'Não foi possível atualizar esta conversa';

  @override
  String get chatCurrent => 'Usar atual';

  @override
  String chatDescriptionChildren(int count) {
    return 'Filhos: $count';
  }

  @override
  String get chatDescriptionCloseApp =>
      'Fechar o aplicativo usando o comportamento de fechamento da plataforma';

  @override
  String get chatDescriptionCycleModels => 'Alternar modelos recentes';

  @override
  String get chatDescriptionCycleVariant => 'Alternar variante do modelo';

  @override
  String get chatDescriptionDiffFilesZero => 'Arquivos diff: 0';

  @override
  String get chatDescriptionFocusInput => 'Focar entrada de mensagem';

  @override
  String get chatDescriptionFocusOrCloseDrawer =>
      'Focar entrada (ou fechar painel quando aberto)';

  @override
  String get chatDescriptionForceExit => 'Forçar saída do aplicativo';

  @override
  String get chatDescriptionNewConversation => 'Nova conversa';

  @override
  String get chatDescriptionNextAgent => 'Próximo agente';

  @override
  String get chatDescriptionOpenProjects =>
      'Use este botão para abrir seus projetos e conversas.';

  @override
  String get chatDescriptionOpenSettings => 'Abrir configurações';

  @override
  String get chatDescriptionPreviousAgent => 'Agente anterior';

  @override
  String get chatDescriptionProjectCommand => 'Comando do projeto';

  @override
  String get chatDescriptionQuickOpen => 'Abertura rápida de arquivos';

  @override
  String get chatDescriptionRefreshData => 'Atualizar dados do chat';

  @override
  String get chatDescriptionStopResponse =>
      'Parar resposta ativa (enquanto responde)';

  @override
  String get chatDescriptionSwitchProject =>
      'Use este botão para alternar pastas de projeto e contexto.';

  @override
  String get chatDescriptionVoiceInput => 'Iniciar ou parar entrada de voz';

  @override
  String get chatDiffFiles => 'Arquivos de diff: 0';

  @override
  String get chatDisplay => 'Exibição';

  @override
  String get chatDisplayToggles => 'Opções de exibição';

  @override
  String get chatDoubleESCStop => 'Duplo ESC para parar';

  @override
  String get chatEffortLockedSubConversation =>
      'Esforço bloqueado na subconversa';

  @override
  String get chatExpandGroup => 'Expandir grupo';

  @override
  String get chatExportCanceled => 'Exportação de sessão cancelada';

  @override
  String get chatFailedToLoadDirectories => 'Falha ao carregar diretórios';

  @override
  String get chatFailedToLoadFile => 'Falha ao carregar o arquivo';

  @override
  String get chatFailedToRefreshProviders =>
      'Falha ao atualizar provedores e modelos';

  @override
  String get chatFailedToRefreshSubConversations =>
      'Falha ao atualizar subconversas. Tente novamente.';

  @override
  String get chatFailedToStopResponse =>
      'Falha ao interromper a resposta atual';

  @override
  String get chatFileExplorerContents => 'Conteúdos';

  @override
  String get chatFileExplorerNames => 'Nomes';

  @override
  String get chatFilterActive => 'Ativas';

  @override
  String get chatFilterAll => 'Todas';

  @override
  String get chatFilterArchived => 'Arquivadas';

  @override
  String get chatFilterDirectories => 'Filtrar diretórios';

  @override
  String get chatFilterSessions => 'Filtrar sessões';

  @override
  String get chatForkFailed => 'Falha ao bifurcar conversa';

  @override
  String get chatForked => 'Conversa bifurcada';

  @override
  String get chatGoToFirst => 'Ir para primeira mensagem';

  @override
  String get chatGoToLatest => 'Ir para última mensagem';

  @override
  String chatGroupMessageCountMessages(
    String compactionLabel,
    String messageCount,
  ) {
    return '$messageCount mensagens ocultas antes da compactação $compactionLabel';
  }

  @override
  String get chatHelloAssistant => 'Olá! Eu sou seu assistente de IA';

  @override
  String get chatHelp => 'Como posso ajudar você?';

  @override
  String get chatHelpMessage =>
      'Use @ para menções, ! para shell, / para comandos';

  @override
  String get chatHideConversationsSidebar => 'Ocultar barra de Conversas';

  @override
  String get chatHideUtilitySidebar => 'Ocultar barra de Utilidades';

  @override
  String get chatHistoryCollapsed => 'O histórico anterior está recolhido';

  @override
  String get chatHistoryHideEarlier => 'Ocultar mensagens anteriores';

  @override
  String chatHistoryMessagesHidden(int count, String label) {
    return '$count mensagens ocultas antes da compactação $label';
  }

  @override
  String get chatHistoryShowEarlier => 'Mostrar mensagens anteriores';

  @override
  String get chatKeepWorking => 'Continuar trabalhando';

  @override
  String get chatLargeContentSkipped =>
      'Conteúdo grande ou malformado foi ignorado para estabilidade.';

  @override
  String get chatLatestToolActivity =>
      'A atividade de ferramenta mais recente permanece dentro deste painel delimitado para manter a visualização do chat estável.';

  @override
  String get chatLoadMore => 'Carregar mais';

  @override
  String get chatLoadingProjectContext => 'Carregando contexto do projeto...';

  @override
  String get chatMainConversationUnavailable =>
      'A conversa principal ainda não está disponível.';

  @override
  String get chatParentConversationUnavailable =>
      'A conversa anterior ainda não está disponível.';

  @override
  String get chatMentionAgentSubtitle => 'agente';

  @override
  String get chatMentionFileSubtitle => 'arquivo';

  @override
  String get chatMentionSymbolSubtitle => 'símbolo';

  @override
  String get chatMessageAttachedFile => 'Arquivo anexado';

  @override
  String get chatMessageDetails => 'Detalhes';

  @override
  String get chatMessageHide => 'Ocultar';

  @override
  String get chatMessageLess => 'Menos';

  @override
  String get chatMessageMessagePartUnavailable =>
      'Parte da mensagem indisponível';

  @override
  String get chatMessageMetadataAvailable => 'Nenhum metadado disponível';

  @override
  String chatMessageModelMessageModelId(String modelId) {
    return 'Modelo: $modelId';
  }

  @override
  String get chatMessageMore => 'Mais';

  @override
  String get chatMessageOpenFile => 'Abrir arquivo';

  @override
  String chatMessageProviderMessageProviderId(String providerId) {
    return 'Provedor: $providerId';
  }

  @override
  String get chatMessageRewindEdit => 'Rebobinar e editar a partir daqui';

  @override
  String get chatMessageRunningTask => 'Executando tarefa';

  @override
  String get chatMessageSaveFile => 'Salvar arquivo';

  @override
  String get chatMessageShow => 'Mostrar';

  @override
  String get chatMessageShowLess => 'Mostrar menos';

  @override
  String get chatMessageShowLessCompact => 'Menos';

  @override
  String get chatMessageShowMore => 'Mostrar mais';

  @override
  String get chatMessageShowMoreCompact => 'Mais';

  @override
  String get chatMessageThinking => 'Pensando';

  @override
  String get chatMessageThinkingProcess => 'Processo de Pensamento';

  @override
  String get chatMessageToolCall => '1 chamada de ferramenta';

  @override
  String chatMessageToolCalls(int count) {
    return '$count chamadas de ferramenta';
  }

  @override
  String get chatMessageToolCommand => 'Comando';

  @override
  String get chatMessageToolCommandTruncated =>
      'Visualização do comando truncada.';

  @override
  String get chatMessageToolDiffOmitted =>
      'Visualização diff omitida: carga muito grande.';

  @override
  String get chatMessageToolInput => 'Entrada';

  @override
  String get chatMessageToolInputTruncated =>
      'Visualização da entrada truncada.';

  @override
  String get chatMessageToolOutputTruncated =>
      'Visualização truncada para estabilidade.';

  @override
  String chatMessageToolQueuedCount(int count) {
    return '$count na fila';
  }

  @override
  String chatMessageToolRunningCount(int count) {
    return '$count em execução';
  }

  @override
  String get chatMessageToolStatusInProgress => 'Em progresso';

  @override
  String get chatMessageToolStatusNeedsAttention => 'Precisa de atenção';

  @override
  String get chatMessageToolStatusQueued => 'Na fila';

  @override
  String get chatMessageYou => 'Você';

  @override
  String get chatModelLockedSubConversation =>
      'Modelo bloqueado na subconversa';

  @override
  String get chatNewChat => 'Nova Conversa';

  @override
  String get chatNewChatTourDescription => 'Inicie uma nova conversa aqui.';

  @override
  String get chatNewChatTourTitle => 'Nova conversa';

  @override
  String get chatNoConversationsInProject => 'Nenhuma conversa neste projeto.';

  @override
  String get chatNoServerYet => 'Nenhum servidor configurado ainda';

  @override
  String get chatNoSessionSelected => 'Selecione ou crie uma conversa';

  @override
  String get chatNoSubConversationFound => 'Nenhuma subconversa encontrada.';

  @override
  String get chatOpenFiles => 'Abrir Arquivos';

  @override
  String get chatOpenProject => 'Abrir projeto';

  @override
  String get chatOpenProjectFolder => 'Abrir pasta do projeto...';

  @override
  String get chatOpenProjectToLoad =>
      'Abra um projeto para carregar conversas.';

  @override
  String get chatOpenSidebar => 'Abrir barra lateral';

  @override
  String get chatPageStatusAutomaticCompactionExplanation =>
      'A compactação automática acontece à medida que o uso do contexto cresce.';

  @override
  String get chatPageStatusCompactNow => 'Compactar agora';

  @override
  String get chatPageStatusCompacting => 'Compactando...';

  @override
  String get chatPageStatusCompactingContextNow =>
      'Compactando contexto agora...';

  @override
  String get chatPageStatusContextCompacted => 'Contexto compactado';

  @override
  String get chatPageStatusContextUsage => 'Uso do contexto';

  @override
  String get chatPageStatusCost => 'Custo';

  @override
  String get chatPageStatusFailedToCompactContext =>
      'Falha ao compactar contexto';

  @override
  String get chatPageStatusLimit => 'Limite';

  @override
  String get chatPageStatusManageServers => 'Gerenciar servidores';

  @override
  String get chatPageStatusSaver => 'Economia';

  @override
  String get chatPageStatusServer => 'Servidor';

  @override
  String get chatPageStatusSwitchServer => 'Trocar servidor';

  @override
  String get chatPageStatusTokens => 'Tokens';

  @override
  String get chatPageStatusUsage => 'Uso';

  @override
  String chatPageStatusUsagePercent(int usagePercent) {
    return '$usagePercent';
  }

  @override
  String get chatPermissionAutoApproveOff =>
      'Aprovação automática de permissão desativada';

  @override
  String get chatPermissionAutoApproveOn =>
      'Aprovação automática de permissão ativada';

  @override
  String get chatProjectContext => 'Contexto do Projeto';

  @override
  String get chatProjectContext2 => 'Contexto do projeto';

  @override
  String get chatRealtimeGlobalEvent => 'evento global';

  @override
  String chatRealtimeGlobalEventReason(String reason) {
    return 'evento global ($reason)';
  }

  @override
  String get chatRealtimeGlobalEventStale => 'evento global (geração obsoleta)';

  @override
  String chatRealtimeMessageStreamReason(String reason) {
    return 'fluxo de mensagens ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEvent => 'evento em tempo real';

  @override
  String chatRealtimeRealtimeEventReason(String reason) {
    return 'evento em tempo real ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEventStale =>
      'evento em tempo real (geração obsoleta)';

  @override
  String get chatRealtimeReconnectingServerTry =>
      'Reconectando ao servidor. Tente novamente em um momento.';

  @override
  String get chatReasoning => 'Raciocinando...';

  @override
  String get chatRecentSessions => 'Sessões recentes';

  @override
  String get chatRecentSessionsToggle => 'Sessões recentes';

  @override
  String get chatRedoLastTurn => 'Refazer último turno desfeito';

  @override
  String get chatRedoNothing => 'Nada para refazer nesta sessão';

  @override
  String get chatRefresh => 'Atualizar';

  @override
  String get chatRefreshConversation =>
      'Não foi possível atualizar esta conversa';

  @override
  String get chatRefreshProjects => 'Atualizar projetos';

  @override
  String get chatRefreshSessionDetails => 'Atualizar detalhes da sessão';

  @override
  String chatRemoveDisplayNameHistory(String displayName) {
    return 'Remover $displayName do histórico';
  }

  @override
  String get chatRetry => 'Tentar novamente';

  @override
  String get chatRetry2 => 'Reintentar';

  @override
  String get chatRetryRefresh => 'Tentar atualizar novamente';

  @override
  String get chatRetryingModelRequest => 'Repetindo a solicitação do modelo...';

  @override
  String get chatReturnToMainConversation => 'Voltar à conversa principal';

  @override
  String get chatReturnToParentConversation => 'Voltar à conversa anterior';

  @override
  String get chatReviewChanges => 'Revisar alterações';

  @override
  String get chatSearchConversations => 'Buscar conversas';

  @override
  String get chatSearchNextResult => 'Próximo resultado';

  @override
  String get chatSearchNoResults => 'Nenhum resultado';

  @override
  String get chatSearchPreviousResult => 'Resultado anterior';

  @override
  String chatSearchResultCount(int current, int total) {
    return 'Mensagem $current de $total';
  }

  @override
  String get chatSearchTimeline => 'Buscar na timeline';

  @override
  String get chatSelectDirectory => 'Selecionar diretório';

  @override
  String get chatSelectOrCreate =>
      'Selecione ou crie uma conversa para começar';

  @override
  String get chatSelectProjectBelow => 'Selecione um projeto abaixo.';

  @override
  String get chatServerSelectedModel => 'Modelo selecionado pelo servidor';

  @override
  String get chatSessionActions => 'Ações da sessão';

  @override
  String chatSessionChatSessionSession(String title) {
    return 'Sessão de chat: $title';
  }

  @override
  String chatSessionConversationNextAction(String nextAction) {
    return 'Conversa $nextAction';
  }

  @override
  String get chatSessionConversations => 'Nenhuma conversa';

  @override
  String get chatSessionCreateConversationStart =>
      'Crie uma nova conversa para começar a chatear';

  @override
  String get chatSessionTabsToggle => 'Abas de sessões';

  @override
  String chatSessionsLength(int length) {
    return '$length';
  }

  @override
  String get chatSetUpServer => 'Configurar servidor';

  @override
  String get chatSettings => 'Configurações';

  @override
  String get chatShortcutsCloseApp =>
      'Fechar aplicativo usando comportamento da plataforma';

  @override
  String get chatShortcutsCycleModels => 'Ciclar modelos recentes';

  @override
  String get chatShortcutsCycleVariant => 'Ciclar variante do modelo';

  @override
  String get chatShortcutsFocusInput => 'Focar entrada de mensagem';

  @override
  String get chatShortcutsFocusInputCloseDrawer =>
      'Focar entrada (ou fechar gaveta quando aberta)';

  @override
  String get chatShortcutsForceExit => 'Forçar saída do aplicativo';

  @override
  String get chatShortcutsNewConversation => 'Nova conversa';

  @override
  String get chatShortcutsNextAgent => 'Próximo agente';

  @override
  String get chatShortcutsOpenSettings => 'Abrir configurações';

  @override
  String get chatShortcutsPreviousAgent => 'Agente anterior';

  @override
  String get chatShortcutsQuickOpen => 'Abrir arquivos rapidamente';

  @override
  String get chatShortcutsRefreshChat => 'Atualizar dados do chat';

  @override
  String get chatShortcutsStartStopVoice => 'Iniciar ou parar entrada de voz';

  @override
  String get chatShortcutsStopResponse =>
      'Parar resposta ativa (enquanto responde)';

  @override
  String get chatSidebarAccess => 'Acesso à barra lateral';

  @override
  String get chatSortMostRecent => 'Mais Recentes';

  @override
  String get chatSortOldest => 'Mais Antigas';

  @override
  String get chatSortRecent => 'Recentes';

  @override
  String get chatSortSessions => 'Ordenar sessões';

  @override
  String get chatSortTitle => 'Título';

  @override
  String get chatStartVoiceInput => 'Iniciar entrada de voz';

  @override
  String get chatStartingVoiceInput => 'Iniciando entrada de voz';

  @override
  String get chatStatusBusy => 'Status: Ocupado';

  @override
  String get chatStatusPatching => 'Aplicando patch';

  @override
  String chatStatusPatchingMultipleFiles(int count) {
    return 'Aplicando patch em $count arquivos';
  }

  @override
  String get chatStatusPatchingOneFile => 'Aplicando patch em 1 arquivo';

  @override
  String get chatStatusRetry => 'Status: Repetir';

  @override
  String chatStatusRetryCount(int count) {
    return 'Status: Repetir #$count';
  }

  @override
  String get chatStatusSubsession => 'Subsessão';

  @override
  String get chatStatusThinking => 'Pensando...';

  @override
  String get chatStopVoiceInput => 'Parar entrada de voz';

  @override
  String chatSyncLabel(String label) {
    return 'Sincronização: $label';
  }

  @override
  String get chatTasks => 'Tarefas';

  @override
  String get chatTasksAvailableSession =>
      'Nenhuma tarefa disponível para esta sessão.';

  @override
  String get chatTipAcceptanceCriteria =>
      'Dica: Adicione critérios de aceite em mudanças maiores';

  @override
  String get chatTipAskForPlan =>
      'Dica: Peça um plano primeiro em tarefas grandes';

  @override
  String get chatTipBeSpecific =>
      'Dica: Seja específico — prompts curtos recebem respostas mais rápidas';

  @override
  String get chatTipBreakTasks =>
      'Dica: Divida tarefas grandes em prompts menores';

  @override
  String get chatTipCompareOptions =>
      'Dica: Peça alternativas quando houver tradeoffs';

  @override
  String get chatTipContextKnob =>
      'Dica: Toque no botão de contexto para ver detalhes de uso';

  @override
  String get chatTipDefineVerification =>
      'Dica: Diga quais testes ou checagens devem passar';

  @override
  String get chatTipLongPressSend =>
      'Dica: Pressione e segure Enviar para inserir uma nova linha';

  @override
  String get chatTipMentionFiles =>
      'Dica: Use @ para mencionar arquivos em seu prompt';

  @override
  String get chatTipNameRelevantFiles =>
      'Dica: Cite arquivos, telas ou comandos relevantes';

  @override
  String get chatTipProvideContext =>
      'Dica: Forneça contexto — cole mensagens de erro e logs';

  @override
  String get chatTipRenameConversation =>
      'Dica: Toque no título para renomear uma conversa';

  @override
  String get chatTipRequestDocs =>
      'Dica: Peça atualização de docs quando comportamento mudar';

  @override
  String get chatTipShareAttempts => 'Dica: Conte o que tentou e o erro exato';

  @override
  String get chatTipShellCommands =>
      'Dica: Use ! no início para executar comandos shell';

  @override
  String get chatTipSlashCommands =>
      'Dica: Use / para acessar comandos de barra';

  @override
  String get chatTipStartWithGoal => 'Dica: Comece pelo objetivo final';

  @override
  String get chatTipStateConstraints =>
      'Dica: Informe restrições que o agente deve preservar';

  @override
  String get chatTipStepByStep =>
      'Dica: Peça passo a passo ao depurar problemas complexos';

  @override
  String get chatTipUseFocusedAgents =>
      'Dica: Escolha um agente focado para plano, revisão ou build';

  @override
  String get chatToggleSidebars => 'Alternar barras laterais';

  @override
  String chatTokensLabel(int total) {
    return 'Tokens: $total';
  }

  @override
  String get chatTourProjectsConversations =>
      'Use este botão para abrir seus projetos e conversas.';

  @override
  String get chatTourSidebarProjectTools =>
      'Use este menu para mostrar a barra lateral de conversas e ferramentas de projeto.';

  @override
  String get chatTourSwitchFolders =>
      'Use este botão para trocar pastas de projeto e contexto.';

  @override
  String get chatUndoLastTurn => 'Desfazer último turno';

  @override
  String get chatUndoNothing => 'Nada para desfazer nesta sessão';

  @override
  String get chatUseCurrent => 'Usar atual';

  @override
  String get chatWaitingForNetworkConnection => 'Aguardando conexão de rede...';

  @override
  String get chatWelcomeMessage => 'Olá! Sou seu assistente de IA.';

  @override
  String get chatWelcomeSubmessage => 'Como posso ajudar você hoje?';

  @override
  String get chatWorkBoundedPanelExplanation =>
      'A atividade mais recente da ferramenta permanece dentro deste painel limitado para manter a visualização do chat estável.';

  @override
  String get chatWorkExpand => 'Expandir';

  @override
  String get chatWorkHide => 'Ocultar';

  @override
  String get chatWorkMessageOne => '1 mensagem de trabalho';

  @override
  String chatWorkMessagesMultiple(int count) {
    return '$count mensagens de trabalho';
  }

  @override
  String get chatWorkShow => 'Mostrar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonCopiedToClipboard => 'Copiado para a área de transferência';

  @override
  String get commonDelete => 'Excluir';

  @override
  String get commonFile => 'Arquivo';

  @override
  String get commonReset => 'Redefinir';

  @override
  String get commonSave => 'Salvar';

  @override
  String get compactionAutomatic => 'automático';

  @override
  String get compactionManual => 'manual';

  @override
  String get composerAddAttachment => 'Adicionar anexo';

  @override
  String get composerAttachFiles => 'Anexar arquivos';

  @override
  String get composerCannedAppendAtCursor => 'Anexar no cursor';

  @override
  String get composerCannedLabel => 'Rótulo (opcional)';

  @override
  String get composerCannedNoReplies => 'Nenhuma resposta rápida ainda.';

  @override
  String get composerCannedReplace => 'Substituir';

  @override
  String get composerCannedSave => 'Salvar';

  @override
  String get composerCannedScopeGlobal => 'Global';

  @override
  String get composerCannedScopeProject => 'Apenas do projeto';

  @override
  String get composerCannedSendAutomatically => 'Enviar automaticamente';

  @override
  String get composerCannedText => 'Texto';

  @override
  String get composerChatInput => 'Entrada de chat';

  @override
  String get composerDeleteAction => 'Excluir';

  @override
  String get composerDropHint => 'Solte imagens ou PDFs para anexar';

  @override
  String get composerPastedImageName => 'Imagem colada';

  @override
  String get composerEdit => 'Editar';

  @override
  String get composerExtras => 'Extras';

  @override
  String get composerExtrasHide => 'Ocultar extras';

  @override
  String get composerNewQuickReply => 'Nova resposta rápida';

  @override
  String get composerSelectImages => 'Selecionar Imagens';

  @override
  String get composerSelectPdf => 'Selecionar PDF';

  @override
  String get composerSend => 'Enviar';

  @override
  String get composerShellMode => 'Modo shell';

  @override
  String get desktopWindowClose => 'Fechar';

  @override
  String get desktopWindowMaximize => 'Maximizar';

  @override
  String get desktopWindowMinimize => 'Minimizar';

  @override
  String get desktopWindowRestore => 'Restaurar';

  @override
  String get dialogDownload => 'Baixar';

  @override
  String get dialogLanguage => 'Idioma';

  @override
  String get dialogMoonshineModelSize => 'Tamanho do modelo';

  @override
  String get dialogMoonshineVoiceSetup => 'Configuração de Voz Moonshine';

  @override
  String get dialogParakeetModel => 'Modelo Parakeet';

  @override
  String get dialogParakeetVoiceSetup => 'Configuração de Voz Parakeet';

  @override
  String get dialogSenseVoiceModel => 'Modelo SenseVoice';

  @override
  String get dialogSenseVoiceSetup => 'Configuração SenseVoice';

  @override
  String get dialogVoiceInputSetup => 'Configuração de Entrada de Voz';

  @override
  String get errorAnErrorOccurred => 'Ocorreu um erro';

  @override
  String get errorAuthRequired => 'Autenticação necessária';

  @override
  String get errorAuthRequiredDesc =>
      'A autenticação falhou. Reconecte o provedor e tente novamente.';

  @override
  String get errorConnectionFailed => 'Falha na conexão';

  @override
  String get errorConnectionFailedDesc =>
      'Não foi possível contactar o servidor. Verifique a conexão e o status do servidor.';

  @override
  String get errorFormatAuthenticationFailedReconnect =>
      'Falha na autenticação. Reconecte o provedor e tente novamente.';

  @override
  String get errorFormatProviderTemporarilyUnavailable =>
      'Provedor temporariamente indisponível. Tente novamente em breve.';

  @override
  String get errorFormatQuotaExceededCheck =>
      'Cota excedida. Verifique o plano ou cobrança do seu provedor.';

  @override
  String get errorFormatRateLimitExceeded =>
      'Limite de taxa excedido. Aguarde um momento e tente novamente.';

  @override
  String get errorFormatServerErrorPlease =>
      'Erro no servidor. Por favor, tente novamente.';

  @override
  String get errorFormatServiceTemporarilyUnavailable =>
      'Serviço temporariamente indisponível. O servidor pode estar iniciando — por favor, tente novamente em breve.';

  @override
  String get errorFormatUnableReachServer =>
      'Não foi possível alcançar o servidor. Verifique a conexão e o status do servidor.';

  @override
  String get errorProviderUnavailable => 'Provedor indisponível';

  @override
  String get errorProviderUnavailableDesc =>
      'Provedor temporariamente indisponível. Tente novamente em breve.';

  @override
  String get errorQuotaExceeded => 'Cota excedida';

  @override
  String get errorQuotaExceededDesc =>
      'Cota excedida. Verifique o plano do seu provedor ou faturamento.';

  @override
  String get errorRateLimitExceeded => 'Limite de taxa excedido';

  @override
  String get errorRateLimitExceededDesc =>
      'Limite de taxa excedido. Aguarde um momento e tente novamente.';

  @override
  String get errorServerError => 'Erro no servidor';

  @override
  String get errorServerErrorDesc =>
      'Erro no servidor. Por favor, tente novamente.';

  @override
  String get errorServiceUnavailable => 'Serviço indisponível';

  @override
  String get errorServiceUnavailableDesc =>
      'Serviço temporariamente indisponível. O servidor pode estar iniciando — por favor, tente novamente em breve.';

  @override
  String get fileActionAttachmentDataDecoded =>
      'Os dados do anexo não puderam ser decodificados.';

  @override
  String get fileActionAttachmentPathEmpty => 'O caminho do anexo está vazio.';

  @override
  String get fileActionAttachmentPayloadEmpty =>
      'A carga útil (payload) do anexo está vazia.';

  @override
  String get fileActionAttachmentProvideValid =>
      'O anexo não fornece um local válido.';

  @override
  String get fileActionAttachmentSavedDevice =>
      'O anexo não pôde ser salvo neste dispositivo.';

  @override
  String fileActionAttachmentSavedOutputFile(String path) {
    return 'Anexo salvo em $path e aberto.';
  }

  @override
  String fileActionAttachmentSavedOutputFile2(String path) {
    return 'Anexo salvo em $path.';
  }

  @override
  String fileActionAttachmentSavedSavedPath(String savedPath) {
    return 'Anexo salvo em $savedPath.';
  }

  @override
  String get fileActionLocalAttachmentFound =>
      'O anexo local não foi encontrado neste dispositivo.';

  @override
  String get fileActionSaveCanceled => 'Salvar cancelado.';

  @override
  String get fileActionUnableOpenLocal =>
      'Não foi possível abrir o anexo local.';

  @override
  String get filesAddChat => 'Adicionar ao chat';

  @override
  String get filesAutosave => 'Salvamento automático';

  @override
  String get filesAutosaveOn => 'Salvamento automático ativado';

  @override
  String get filesAutosaveOff => 'Salvamento automático desativado';

  @override
  String get filesRedo => 'Refazer';

  @override
  String get filesUndo => 'Desfazer';

  @override
  String get filesBinaryFilePreview =>
      'A visualização de arquivo binário não está disponível.';

  @override
  String get filesClear => 'Limpar';

  @override
  String get filesContents => 'Conteúdo';

  @override
  String get filesDuplicate => 'Duplicar';

  @override
  String get filesDuplicated => 'Arquivo duplicado';

  @override
  String get filesFileEmpty => 'O arquivo está vazio.';

  @override
  String get filesAlreadyExists =>
      'Já existe um arquivo ou pasta com esse nome.';

  @override
  String get filesCopyPath => 'Copiar caminho';

  @override
  String get filesCreateFileTitle => 'Criar arquivo';

  @override
  String get filesCreateFolderTitle => 'Criar pasta';

  @override
  String get filesDelete => 'Excluir';

  @override
  String filesDeleteConfirm(String name) {
    return 'Excluir $name? Esta ação não pode ser desfeita. As pastas e seus conteúdos serão excluídos.';
  }

  @override
  String filesDeleteTitle(String name) {
    return 'Excluir $name';
  }

  @override
  String get filesFilesFound => 'Nenhum arquivo encontrado';

  @override
  String get filesFileCreated => 'Arquivo criado.';

  @override
  String get filesFolderCreated => 'Pasta criada.';

  @override
  String get filesHideSidebar => 'Ocultar barra de Arquivos';

  @override
  String get filesInvalidName =>
      'Digite um nome válido sem separadores de caminho.';

  @override
  String get filesNameHint => 'Nome';

  @override
  String get filesNew => 'Novo';

  @override
  String get filesNewFile => 'Novo arquivo';

  @override
  String get filesNewFolder => 'Nova pasta';

  @override
  String get filesNames => 'Nomes';

  @override
  String filesOpenFilesFileState(int length) {
    return 'Arquivos abertos ($length)';
  }

  @override
  String get filesQuickOpen => 'Abertura Rápida';

  @override
  String get filesQuickOpenFile => 'Abertura rápida de arquivo';

  @override
  String get filesOperationFailed => 'A operação de arquivo falhou.';

  @override
  String get filesOperationUnavailable =>
      'As operações de arquivo não estão disponíveis para este servidor.';

  @override
  String get filesOutsideRoot => 'O caminho está fora da raiz do projeto.';

  @override
  String get filesPathCopied => 'Caminho copiado.';

  @override
  String get filesPathMissing => 'O caminho não existe.';

  @override
  String get filesPermissionDenied => 'Permissão negada.';

  @override
  String get filesRefresh => 'Atualizar arquivos';

  @override
  String get filesRename => 'Renomear';

  @override
  String filesRenameTitle(String name) {
    return 'Renomear $name';
  }

  @override
  String get filesRenamed => 'Renomeado.';

  @override
  String get filesRootDeleteBlocked =>
      'A raiz do projeto não pode ser excluída.';

  @override
  String get filesSearchHint => 'Buscar arquivos por nome ou caminho';

  @override
  String get filesDeleted => 'Excluído.';

  @override
  String get filesTitle => 'Arquivos';

  @override
  String get forwardAction => 'Encaminhar';

  @override
  String get forwardAllFailed =>
      'Não foi possível encaminhar para nenhuma sessão';

  @override
  String get forwardCancel => 'Cancelar';

  @override
  String get forwardDialogSubtitle => 'Selecione uma ou várias conversas';

  @override
  String get forwardDialogTitle => 'Encaminhar para…';

  @override
  String get forwardLoading => 'Carregando sessões…';

  @override
  String get forwardNoOpenProjects => 'Nenhum projeto aberto com sessões';

  @override
  String get forwardNoProviderModel =>
      'Selecione um provedor e modelo antes de encaminhar';

  @override
  String get forwardNoSessions => 'Nenhuma sessão recente';

  @override
  String forwardPartial(int success, int total) {
    return 'Encaminhado para $success de $total';
  }

  @override
  String forwardProvenanceLabel(String origin) {
    return 'Encaminhado de: $origin';
  }

  @override
  String get forwardRetry => 'Tentar novamente';

  @override
  String get forwardSearchHint => 'Buscar';

  @override
  String forwardSelectedCount(int count) {
    return '$count selecionadas';
  }

  @override
  String get forwardSend => 'Encaminhar';

  @override
  String get forwardServerOffline => 'Servidor offline';

  @override
  String get forwardShortcutHint => 'Ctrl+Shift+F';

  @override
  String forwardSuccess(int count) {
    return 'Encaminhado para $count sessões';
  }

  @override
  String get forwardUndo => 'Desfazer';

  @override
  String get forwardUndoFailed => 'Não foi possível desfazer o encaminhamento';

  @override
  String get logsAppLogs => 'Logs do App';

  @override
  String get logsClear => 'Limpar logs';

  @override
  String get logsCloseSearch => 'Fechar busca';

  @override
  String get logsCopyFiltered => 'Copiar logs filtrados';

  @override
  String get logsEnableLogging => 'Ativar logs do app';

  @override
  String get logsEnableLoggingAction => 'Ativar logs';

  @override
  String get logsEnableLoggingDescription =>
      'Coleta logs de diagnóstico em memória. Mantenha desligado, exceto ao solucionar problemas.';

  @override
  String get logsEntryContext => 'Contexto';

  @override
  String get logsEntryTags => 'Tags';

  @override
  String get logsFilterAll => 'Todos';

  @override
  String get logsFilterByTag => 'Tag';

  @override
  String get logsLevel => 'Nível';

  @override
  String get logsLoggingDisabledDescription =>
      'O CodeWalk não está coletando logs detalhados do app. Ative logs apenas quando precisar diagnosticar problemas.';

  @override
  String get logsLoggingDisabledTitle => 'Logs desativados';

  @override
  String get logsMeasurePerformance => 'Medir desempenho';

  @override
  String get logsMeasurePerformanceDescription =>
      'Captura tempos de operações caras do app. Deixe desligado, exceto ao diagnosticar lentidão.';

  @override
  String get logsNoLogsYet => 'Nenhum log capturado ainda.';

  @override
  String get logsNoMatchingLogs => 'Nenhum log corresponde aos filtros atuais.';

  @override
  String get logsNoPerformanceData =>
      'Nenhum log de desempenho corresponde aos filtros atuais.';

  @override
  String get logsNoTaskData => 'Nenhuma tarefa corresponde aos filtros atuais.';

  @override
  String logsPerformanceDuration(int elapsedMs) {
    return '$elapsedMs ms';
  }

  @override
  String get logsPerformanceFilter => 'Desempenho';

  @override
  String logsPerformanceTileTitle(
    int elapsedMs,
    String operation,
    String status,
  ) {
    return 'DESEMPENHO $operation | $elapsedMs ms | $status';
  }

  @override
  String get logsSearch => 'Buscar logs';

  @override
  String logsShowingOrderedLength(int length, int length2) {
    return 'Mostrando $length de $length2 entradas';
  }

  @override
  String get logsSlowestPerformance => 'Logs de desempenho mais lentos';

  @override
  String get logsSlowestTasks => 'Tarefas mais lentas';

  @override
  String get logsTagCustomHint => 'Nome da tag (ex.: task:select_session)';

  @override
  String get logsTagCustomAction => 'Personalizada...';

  @override
  String logsTaskDuration(int elapsedMs, String operation) {
    return '$operation — $elapsedMs ms';
  }

  @override
  String get logsTaskStatusCanceled => 'cancelada';

  @override
  String get logsTaskStatusError => 'erro';

  @override
  String get logsTaskStatusOk => 'ok';

  @override
  String get logsTimeRange => 'Intervalo de tempo';

  @override
  String get mathExpressionLabel => 'Matemática';

  @override
  String get mermaidCopySourceTooltip => 'Copiar código fonte';

  @override
  String get mermaidDiagramLabel => 'Diagrama Mermaid';

  @override
  String get modelAuto => 'Automático';

  @override
  String get modelChooseAgent => 'Escolher agente';

  @override
  String get modelFavorites => 'Favoritos';

  @override
  String get modelFree => 'Grátis';

  @override
  String get modelLabelBaseEnglish => 'Base (Inglês)';

  @override
  String get modelLabelParakeet => 'Parakeet V3 (25 idiomas europeus)';

  @override
  String get modelLabelSenseVoice => 'SenseVoice (zh/en/ja/ko/yue)';

  @override
  String get modelLabelTinyEnglish => 'Tiny (Inglês)';

  @override
  String get modelLoadingModels => 'Carregando modelos';

  @override
  String get modelModelsFound => 'Nenhum modelo encontrado';

  @override
  String get modelRetryModels => 'Tentar modelos novamente';

  @override
  String get modelSearchHint => 'Buscar modelo ou provedor';

  @override
  String get msgBatterySettingsFailed =>
      'Não foi possível abrir as configurações de otimização de bateria do Android.';

  @override
  String get msgBatterySettingsOpened =>
      'Configurações de bateria do Android abertas. Permita bateria irrestrita para o CodeWalk.';

  @override
  String get msgClearUsernameNeedsConfigEdit =>
      'Limpar o nome de usuário da conversa do OpenCode ainda requer editar a config fora do app.';

  @override
  String get msgCommandCopied => 'Comando copiado';

  @override
  String get msgCopiedToClipboard => 'Copiado para a área de transferência';

  @override
  String get msgEnterUsernameToSave =>
      'Digite um nome de usuário para salvar um nome de conversa personalizado do OpenCode.';

  @override
  String get msgFailedToSendMessage =>
      'Falha ao enviar mensagem. Rascunho mantido para nova tentativa.';

  @override
  String get msgFailedToStartVoiceInput => 'Falha ao iniciar entrada de voz';

  @override
  String msgFilePathNotFound(String path) {
    return 'Arquivo não encontrado: $path';
  }

  @override
  String get msgFilteredLogsCopied =>
      'Logs filtrados copiados para a área de transferência';

  @override
  String get msgInfoAgent => 'Agente';

  @override
  String get msgInfoCompaction => 'Compactação';

  @override
  String msgInfoCost(String cost) {
    return 'Custo: \$$cost';
  }

  @override
  String get msgInfoMessageInfo => 'Informações da Mensagem';

  @override
  String msgInfoModel(String modelId) {
    return 'Modelo: $modelId';
  }

  @override
  String get msgInfoNoMetadata => 'Nenhum metadado disponível';

  @override
  String msgInfoPartDescriptionModel(String description, String model) {
    return '$description$model';
  }

  @override
  String get msgInfoPatch => 'Patch';

  @override
  String msgInfoProvider(String providerId) {
    return 'Provedor: $providerId';
  }

  @override
  String get msgInfoRetry => 'Tentativa';

  @override
  String get msgInfoSnapshot => 'Instantânea';

  @override
  String msgInfoSubtaskPartAgent(String agent) {
    return 'Subtarefa ($agent)';
  }

  @override
  String msgInfoTokens(int total) {
    return 'Tokens: $total';
  }

  @override
  String get msgInfoUndoThisTurn => 'Desfazer este turno';

  @override
  String get msgInfoView => 'Ver';

  @override
  String get msgNoSystemSoundsFound =>
      'Nenhum som do sistema foi encontrado neste dispositivo.';

  @override
  String get msgNoValidFilesSelected => 'Nenhum arquivo válido foi selecionado';

  @override
  String get msgSomeSelectedFilesNotAttached =>
      'Alguns arquivos selecionados não puderam ser anexados.';

  @override
  String get msgReadAloud => 'Ler em voz alta';

  @override
  String get msgReadAloudNotAvailable =>
      'Conversão de texto em fala não disponível neste dispositivo.';

  @override
  String get msgSetupDebugCopied => 'Debug de configuração do OpenCode copiado';

  @override
  String get msgShareAsImage => 'Compartilhar como imagem';

  @override
  String get msgShareAsImageFailed =>
      'Não foi possível compartilhar a mensagem como imagem.';

  @override
  String get msgShareAsImageSubject => 'Mensagem do CodeWalk';

  @override
  String get msgShareAsImageTooTall =>
      'A mensagem é muito longa para ser compartilhada como imagem.';

  @override
  String get msgStopReadAloud => 'Parar leitura';

  @override
  String get msgSystemSoundPickerUnavailable =>
      'Seletor de som do sistema não está disponível nesta plataforma.';

  @override
  String get msgUpdatedButRefreshFailed =>
      'Configuração do servidor atualizada, mas não foi possível atualizar os provedores de chat.';

  @override
  String get msgVoiceInputUnavailable =>
      'Entrada de voz indisponível neste dispositivo';

  @override
  String get notifAndroidBatteryOptimization =>
      'Otimização de bateria do Android';

  @override
  String get notifConversationUpdates => 'Atualizações de conversa';

  @override
  String get notifNotificationsArriveReopening =>
      'Se as notificações só chegarem ao reabrir o app, permita que o CodeWalk seja executado sem otimização de bateria neste dispositivo.';

  @override
  String get notifResponseRunningKeep =>
      'Quando uma resposta estiver em execução, mantenha o tempo real ativo brevemente após sair do app.';

  @override
  String notifSelectedSoundLabel(String soundLabel) {
    return 'Selecionado: $soundLabel';
  }

  @override
  String get notificationAgentFinished => 'O agente terminou a resposta atual.';

  @override
  String get notificationConversationUpdates => 'Atualizações da conversa';

  @override
  String get notificationOpenToClear =>
      'Abra esta conversa para limpar as notificações relacionadas.';

  @override
  String get notificationSession => 'Sessão';

  @override
  String get notificationSoundLoadFailed =>
      'Falha ao carregar os sons do sistema Android';

  @override
  String get onboardingAIGeneratedTitles => 'Títulos gerados por IA';

  @override
  String get onboardingAddServerLater =>
      'Você pode adicionar um servidor mais tarde em Configurações > Servidores.';

  @override
  String get onboardingAddedButHealthCheckFailed =>
      'Servidor adicionado, mas a verificação de integridade falhou. Ele ainda pode estar iniciando.';

  @override
  String get onboardingAlmostInstallOpenCode =>
      'Você está quase lá. Instale o OpenCode primeiro, depois conecte o CodeWalk à URL do servidor.';

  @override
  String onboardingAppProviderLocalSetupLogsLength(int length, int length2) {
    return '$length linhas de log de configuração e $length2 eventos de configuração estão disponíveis na tela de depuração de configuração separada.';
  }

  @override
  String get onboardingAuthenticate => 'Autenticar';

  @override
  String get onboardingAvailable => 'disponível';

  @override
  String get onboardingAvailableOnlyDesktop =>
      'Disponível apenas para desktop (Linux/macOS/Windows).';

  @override
  String get onboardingBasicAuthTip =>
      'Ative o Basic Auth apenas se o seu servidor OpenCode estiver protegido por senha.';

  @override
  String get onboardingChooseAnotherPath => 'Escolher outro caminho';

  @override
  String get onboardingChooseHowToSetup =>
      'Escolha como configurar seu servidor';

  @override
  String get onboardingClear => 'Limpar';

  @override
  String get onboardingCloudflareAuthFailed =>
      'A autenticação do Cloudflare Access falhou.';

  @override
  String get onboardingCodeWalkAppOpenCode =>
      'CodeWalk é o app. OpenCode é o motor ao qual ele se conecta.';

  @override
  String get onboardingConnectRunningServer =>
      'Conectar a um servidor em execução';

  @override
  String get onboardingConnectionIssue => 'Problema de conexão';

  @override
  String get onboardingConnectionSaved =>
      'Conexão com o servidor salva com sucesso.';

  @override
  String get onboardingConnectionTips => 'Dicas de conexão';

  @override
  String get onboardingConnectionUpdated =>
      'Conexão com o servidor atualizada com sucesso.';

  @override
  String get onboardingContinue => 'Continuar';

  @override
  String get onboardingContinueServerURL => 'Continuar para URL do servidor';

  @override
  String get onboardingCopyLoginURL => 'Copiar URL de login';

  @override
  String get onboardingCouldNotVerify =>
      'Não foi posible verificar a conexão com o servidor.';

  @override
  String get onboardingDefaultURLEmulator =>
      'URL padrão, loopback do emulador, autenticação e ajuda de depuração.';

  @override
  String onboardingDesktopOnlyDiagnose(String appName) {
    return 'Apenas desktop: o $appName pode diagnosticar, instalar e executar o OpenCode para você.';
  }

  @override
  String get onboardingDetailedSetupEvents =>
      'Eventos de configuração detalhados foram capturados para solução de problemas.';

  @override
  String get onboardingDonShowAgain => 'Não mostrar novamente';

  @override
  String get onboardingDone => 'Concluído';

  @override
  String get onboardingEditServer => 'Editar servidor';

  @override
  String get onboardingEditServerConnection => 'Editar conexão do servidor';

  @override
  String get onboardingEmulatorRemap =>
      'No emulador Android, localhost e 127.0.0.1 são remapeados para 10.0.2.2 automaticamente.';

  @override
  String get onboardingEnterServerUrl => 'Digite a URL do servidor';

  @override
  String get onboardingExisting => 'Usar existente';

  @override
  String get onboardingExplainInstallOpenCode =>
      'Explica como instalar o OpenCode, iniciar o servidor e depois conectar a partir do CodeWalk.';

  @override
  String get onboardingFailed => 'Falhou';

  @override
  String get onboardingGoodOptionDesktop => 'Boa primeira opção no desktop';

  @override
  String get onboardingHealthCheckFailedMayBeStarting =>
      'A verificação de integridade do servidor falhou. Ele ainda pode estar iniciando.';

  @override
  String get onboardingInstallBinary => 'Instalar binário';

  @override
  String get onboardingInstallBun => 'Instalar via Bun';

  @override
  String get onboardingInstallBunOpenCode => 'Instalar Bun + OpenCode';

  @override
  String get onboardingInstallNpm => 'Instalar via npm';

  @override
  String get onboardingInstallRunOpenCode =>
      'Instale e execute o OpenCode diretamente do CodeWalk no desktop.';

  @override
  String get onboardingInvalidUrl => 'URL inválida';

  @override
  String get onboardingLabel => 'Rótulo (opcional)';

  @override
  String get onboardingLabelHint => 'Meu servidor';

  @override
  String onboardingLatestOutputAppProvider(String localServerLastOutput) {
    return 'Última saída: $localServerLastOutput';
  }

  @override
  String get onboardingLetCodeWalkSet =>
      'Deixar o CodeWalk configurar localmente';

  @override
  String get onboardingLocalServerSetup => 'Configuração do servidor local';

  @override
  String get onboardingManagedLocalServer => 'Servidor local gerenciado';

  @override
  String get onboardingManagedLocalServer2 =>
      'O modo de servidor local gerenciado está disponível apenas em builds de desktop (Linux/macOS/Windows).';

  @override
  String onboardingNeedsOpenCodeServer(String appName) {
    return 'O $appName precisa de um servidor OpenCode antes de poder ajudar com o seu código.';
  }

  @override
  String get onboardingNotAvailable => 'não disponível';

  @override
  String get onboardingNotWritable => 'não gravável';

  @override
  String get onboardingOpenCode => 'O que é o OpenCode?';

  @override
  String get onboardingOpenCodeRunningDevice =>
      'Já tenho o OpenCode rodando neste dispositivo ou em algum lugar da minha rede.';

  @override
  String get onboardingOpenCodeRunsLocally =>
      'O OpenCode roda localmente ou em um servidor e alimenta os recursos de codificação por IA dentro do CodeWalk. Se o OpenCode já estiver rodando, conecte-se a ele. Caso contrário, escolha um dos caminhos de configuração guiada abaixo.';

  @override
  String get onboardingOpenTailscaleLogin =>
      'Não foi possível abrir a URL de login do Tailscale.';

  @override
  String get onboardingPassword => 'Senha';

  @override
  String get onboardingPasswordRequired => 'Digite a senha';

  @override
  String get onboardingPickSetupPath =>
      'Escolha o caminho de configuração que corresponde à sua configuração atual do OpenCode.';

  @override
  String get onboardingPreconditionDirectoryNotWritable =>
      'O diretório de instalação não permite gravação. Verifique as permissões de usuário.';

  @override
  String get onboardingPreconditionInstallViaBunRecommendation =>
      'A instalação via Bun é recomendada pelos mantenedores do OpenCode.';

  @override
  String get onboardingPreconditionNetworkFailed =>
      'Falha no acesso à rede. Verifique a conectividade antes de instalar o OpenCode.';

  @override
  String get onboardingPreconditionNoRuntimeDetected =>
      'Nenhum ambiente de execução detectado. Instale o binário do OpenCode diretamente ou inicialize o Bun primeiro.';

  @override
  String get onboardingPreconditionNodeNpmAvailable =>
      'Node + npm estão disponíveis. Instale o OpenCode via npm ou instale o Bun para o fluxo recomendado.';

  @override
  String get onboardingPreconditionOpenCodeAlreadyAvailable =>
      'O OpenCode já está disponível. Você pode usar o comando detectado imediatamente.';

  @override
  String get onboardingPreconditionWindowsPathLagHint =>
      ' No Windows, atualize as verificações após a instalação porque as atualizações do PATH podem sofrer atrasos em aplicativos que já estão abertos.';

  @override
  String get onboardingPreconditionWindowsWslRecommendation =>
      'Compilação do Windows detectada. O WSL é recomendado pela documentação do OpenCode, mas o npm install pode ser usado como alternativa.';

  @override
  String get onboardingReachable => 'alcançável';

  @override
  String get onboardingReady => 'Pronto';

  @override
  String get onboardingRecommendedOrderTry =>
      'Ordem recomendada: tente Instalar Bun + OpenCode se quiser que o CodeWalk prepare tudo para você. Use Existente se o OpenCode já estiver instalado.';

  @override
  String get onboardingRefreshChecks => 'Atualizar verificações';

  @override
  String get onboardingRunDiagnosticsToVerify =>
      'Execute diagnósticos para verificar os requisitos locais do OpenCode.';

  @override
  String get onboardingSaveAndTest => 'Salvar e testar';

  @override
  String get onboardingServerConnectedReady =>
      'Seu servidor está conectado e pronto para uso.';

  @override
  String get onboardingServerConnection => 'Conexão do servidor';

  @override
  String get onboardingServerSettingsSaved =>
      'As configurações do servidor foram salvas e as verificações de integridade foram atualizadas.';

  @override
  String get onboardingServerSetup => 'Configuração do servidor';

  @override
  String get onboardingServerUpdated => 'Servidor atualizado';

  @override
  String get onboardingServerUrl => 'URL do servidor';

  @override
  String get onboardingSetup => 'Configuração';

  @override
  String get onboardingSetupWizard => 'Assistente de configuração';

  @override
  String get onboardingShowSetupSteps => 'Mostrar os passos de configuração';

  @override
  String get onboardingShowSetupSteps2 => 'Mostrar passos de configuração';

  @override
  String get onboardingSkip => 'Pular por enquanto';

  @override
  String get onboardingSkipSetup => 'Pular configuração?';

  @override
  String get onboardingStart => 'Iniciar';

  @override
  String onboardingStartUsing(String appName) {
    return 'Começar a usar o $appName';
  }

  @override
  String get onboardingStarting => 'Iniciando';

  @override
  String get onboardingStop => 'Parar';

  @override
  String get onboardingStopped => 'Parado';

  @override
  String get onboardingStopping => 'Parando';

  @override
  String onboardingSuggestedUrl(String url) {
    return 'URL sugerida para o servidor OpenCode local: $url';
  }

  @override
  String get onboardingTailscaleAdminApproval =>
      'Aprovação do administrador do Tailscale necessária';

  @override
  String get onboardingTailscaleAuthAfterSave =>
      'O Tailscale irá autenticar após salvar';

  @override
  String onboardingTailscaleAuthAfterSaveTest(String appName) {
    return 'Depois de salvar e testar este servidor, o $appName abrirá o login do Tailscale se este dispositivo ainda não estiver autenticado.';
  }

  @override
  String get onboardingTailscaleConnected => 'Tailscale conectado';

  @override
  String get onboardingTailscaleConnecting => 'Tailscale conectando';

  @override
  String get onboardingTailscaleConnectionFailed =>
      'Falha na conexão do Tailscale';

  @override
  String get onboardingTailscaleLoginRequired =>
      'Login do Tailscale necessário';

  @override
  String get onboardingTailscaleOpenLoginUrl =>
      'Abra a URL de login para adicionar este dispositivo à sua tailnet. Se o navegador não abrir, copie a URL abaixo.';

  @override
  String get onboardingTailscaleUnsupported => 'Tailscale não suportado';

  @override
  String get onboardingTestConnection => 'Testar conexão';

  @override
  String get onboardingTesting => 'Testando...';

  @override
  String get onboardingUnreachable => 'inalcançável';

  @override
  String get onboardingUseBasicAuth => 'Usar autenticação básica';

  @override
  String get onboardingUsername => 'Usuário';

  @override
  String get onboardingUsernameRequired => 'Digite o usuário';

  @override
  String get onboardingUsesServerTitle =>
      'Usa o agente de título do seu servidor para nomear conversas';

  @override
  String get onboardingUsingDetectedCommand =>
      'Usando o comando OpenCode detectado.';

  @override
  String get onboardingViewSetupDebug => 'Visualizar depuração de configuração';

  @override
  String onboardingWelcomeTo(String appName) {
    return 'Bem-vindo ao $appName';
  }

  @override
  String get onboardingWindowsTipInstalling =>
      'Dica para Windows: após instalar, clique em Atualizar verificações. Se a detecção ainda falhar, reabra o CodeWalk para recarregar as alterações de PATH.';

  @override
  String get onboardingWritable => 'gravável';

  @override
  String get onboardingYoureAllSet => 'Está tudo pronto!';

  @override
  String get permissionAllowOnce => 'Permitir Uma Vez';

  @override
  String get permissionAlways => 'Sempre';

  @override
  String get permissionBack => 'Voltar';

  @override
  String get permissionConfirmReject => 'Confirmar Rejeição';

  @override
  String get permissionReject => 'Rejeitar';

  @override
  String get permissionReopen => 'Reabrir';

  @override
  String get questionAnswerSelected => 'Nenhuma resposta selecionada.';

  @override
  String get questionCommaSeparatedValues => 'Valores separados por vírgula';

  @override
  String get questionQuestionGroupMarked =>
      'Grupo de perguntas marcado como rejeitado. Você pode continuar chateando e reabrir este grupo a qualquer momento antes de confirmar.';

  @override
  String get questionQuestionRequest => 'Solicitação de pergunta';

  @override
  String get questionQuestionsProvidedSubmit =>
      'Nenhuma pergunta fornecida. Você pode enviar uma resposta vazia.';

  @override
  String get questionReviewAnswersSubmitting =>
      'Revise suas respostas antes de enviar.';

  @override
  String get quotaAuthCookie => 'Cookie de autenticação';

  @override
  String get quotaConnect => 'Conectar';

  @override
  String get quotaForget => 'Esquecer';

  @override
  String get quotaOpenCodeGoConnectDescription =>
      'Conecte o dashboard de uso para mostrar limites móveis, semanais e mensais.';

  @override
  String get quotaOpenCodeGoDetected => 'OpenCode Go detectado';

  @override
  String get quotaOpenCodeGoNeedsReconnect => 'OpenCode Go precisa reconectar';

  @override
  String get quotaOpenCodeGoReconnectDescription =>
      'Atualize as credenciais do dashboard para restaurar as barras de uso.';

  @override
  String get quotaOpenCodeGoUsage => 'Uso do OpenCode Go';

  @override
  String get quotaOpenDashboard => 'Abrir dashboard OpenCode';

  @override
  String get quotaPaceExplanation =>
      'O ritmo prevê o uso total ao fim da janela de limite atual com base na taxa atual.';

  @override
  String quotaPacePercent(String percent) {
    return 'Ritmo $percent%';
  }

  @override
  String get quotaRateLimits => 'Cotas';

  @override
  String get quotaReconnect => 'Reconectar';

  @override
  String get quotaRefreshing => 'Atualizando...';

  @override
  String quotaResetsIn(String time) {
    return 'Redefine em $time';
  }

  @override
  String get quotaSaving => 'Salvando...';

  @override
  String get quotaWorkspaceId => 'ID do Workspace';

  @override
  String get serverClearOAuth => 'Limpar OAuth';

  @override
  String get serverConnectionAttention =>
      'A conexão do servidor precisa de atenção.';

  @override
  String get serverHealthHealthy => 'Saudável';

  @override
  String get serverHealthUnhealthy => 'Não saudável';

  @override
  String get serverHealthUnknown => 'Desconhecido';

  @override
  String get serverOAuthAuthFailed => 'Falha na autenticação OAuth';

  @override
  String get serverOAuthChip => 'OAuth';

  @override
  String get serverOAuthNotSupported =>
      'Cloudflare Access OAuth não é suportado nesta plataforma';

  @override
  String get serverReauthenticate => 'Reautenticar';

  @override
  String get serverTailscaleChip => 'Tailscale';

  @override
  String get serversActive => 'Ativo';

  @override
  String get serversActiveServer => 'Servidor Ativo';

  @override
  String get serversAddLeastOpenCode =>
      'Adicione pelo menos um servidor OpenCode para começar a usar o app.';

  @override
  String get serversAddServer => 'Adicionar Servidor';

  @override
  String get serversCancel => 'Cancelar';

  @override
  String get serversCannotActivateUnhealthy =>
      'Não é possível ativar um servidor não saudável';

  @override
  String get serversCheckHealth => 'Verificar saúde';

  @override
  String get serversClearDefault => 'Limpar Padrão';

  @override
  String serversCommandAppProviderLocalServerCommandPath(
    String localServerCommandPath,
  ) {
    return 'Comando: $localServerCommandPath';
  }

  @override
  String get serversCopy => 'Copiar';

  @override
  String get serversDefault => 'Padrão';

  @override
  String get serversDelete => 'Excluir';

  @override
  String get serversDeleteServer => 'Excluir servidor';

  @override
  String get serversDesktopModeExplanation =>
      'O modo desktop pode iniciar e gerenciar `opencode serve` diretamente do CodeWalk.';

  @override
  String get serversEdit => 'Editar';

  @override
  String get serversLocalOpenCodeServer => 'Servidor OpenCode Local';

  @override
  String get serversManagedModeAvailable =>
      'Este modo gerenciado está disponível apenas em builds de desktop (Linux/macOS/Windows).';

  @override
  String get serversNoServersFound => 'Nenhum servidor encontrado';

  @override
  String get serversRefreshHealth => 'Atualizar saúde';

  @override
  String serversRemoveProfileDisplayName(String displayName) {
    return 'Remover \"$displayName\"?';
  }

  @override
  String get serversSearchActiveHint => 'Pesquisar servidor ativo';

  @override
  String get serversServersConfigured => 'Nenhum servidor configurado';

  @override
  String get serversSetActive => 'Definir como ativo';

  @override
  String get serversSetDefault => 'Definir como padrão';

  @override
  String get serversSetupDebug => 'Depuração de Configuração';

  @override
  String get serversSetupWizard => 'Assistente de Configuração';

  @override
  String get serversTailscaleAdminApprovalRequired =>
      'Aprovação do administrador Tailscale necessária';

  @override
  String get serversTailscaleAuthRequired =>
      'Autenticação Tailscale necessária';

  @override
  String get serversTailscaleConnectExplanation =>
      'O Tailscale conectará quando este perfil ativo for usado.';

  @override
  String get serversTailscaleConnected => 'Tailscale conectado';

  @override
  String get serversTailscaleConnecting => 'Tailscale conectando';

  @override
  String get serversTailscaleConnectionFailed => 'Conexão Tailscale falhou';

  @override
  String get serversTailscaleDisconnected => 'Tailscale desconectado';

  @override
  String get serversTailscaleLoginExplanation =>
      'Abra o URL de login do Tailscale para adicionar este dispositivo ao seu tailnet.';

  @override
  String get serversTailscaleTrafficExplanation =>
      'O tráfego do OpenCode para este perfil ativo é roteado através do Tailscale.';

  @override
  String get serversTailscaleUnsupported => 'Tailscale não suportado';

  @override
  String get serversUnhealthyActivateError =>
      'Este servidor não está saudável. Verifique a saúde ou edite as configurações antes de ativar.';

  @override
  String get sessionActionArchived => 'arquivada';

  @override
  String get sessionActionDeleted => 'excluída';

  @override
  String get sessionActionForked => 'bifurcada';

  @override
  String get sessionActionPinned => 'fixada';

  @override
  String get sessionActionUnarchived => 'desarquivada';

  @override
  String get sessionActionUnpinned => 'desafixada';

  @override
  String get sessionArchive => 'Arquivar';

  @override
  String get sessionCancelRename => 'Cancelar renomeação';

  @override
  String sessionChildrenCount(int count) {
    return 'Subconversas: $count';
  }

  @override
  String get sessionCompactContext => 'Compactar contexto';

  @override
  String get sessionCopyLink => 'Copiar Link';

  @override
  String get sessionDelete => 'Excluir';

  @override
  String sessionDeleteConfirm(String title) {
    return 'Tem certeza de que deseja excluir a conversa \"$title\"? Esta ação não pode ser desfeita.';
  }

  @override
  String get sessionDeleteTitle => 'Excluir Conversa';

  @override
  String get sessionDiffChangedFile => 'Arquivo alterado';

  @override
  String get sessionDiffContentNotCaptured =>
      'Conteúdo do arquivo não capturado pelo servidor';

  @override
  String sessionDiffFilesChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arquivos alterados',
      one: '1 arquivo alterado',
    );
    return '$_temp0';
  }

  @override
  String sessionDiffFilesCount(int count) {
    return 'Arquivos diff: $count';
  }

  @override
  String sessionDiffLinesAddedRemoved(int added, int removed) {
    return '+$added linhas adicionadas -$removed linhas removidas';
  }

  @override
  String sessionDiffLinesCollapsed(int count) {
    return '$count linhas colapsadas — toque para expandir';
  }

  @override
  String get sessionDiffLoading => 'Carregando arquivos alterados…';

  @override
  String get sessionDiffReview => 'Revisar alterações';

  @override
  String get sessionDiffSplit => 'Dividido';

  @override
  String get sessionDiffSummary => 'Resumo';

  @override
  String get sessionDiffUnified => 'Unificado';

  @override
  String get sessionExportAssistant => 'Assistente';

  @override
  String get sessionExportCanceled => 'Exportação cancelada';

  @override
  String get sessionExportDebugJson => 'Exportar JSON de depuração';

  @override
  String get sessionExportDebugJsonErrorClipboard =>
      'Não foi possível salvar; JSON de depuração copiado para área de transferência';

  @override
  String get sessionExportDebugJsonSaved =>
      'Exportação JSON de depuração salva';

  @override
  String get sessionExportDebugJsonTitle =>
      'Exportar sessão como JSON de depuração';

  @override
  String get sessionExportError => 'Erro:';

  @override
  String get sessionExportInput => 'Entrada:';

  @override
  String get sessionExportMarkdown => 'Exportar Markdown';

  @override
  String get sessionExportMarkdownErrorClipboard =>
      'Não foi possível salvar; Markdown copiado para área de transferência';

  @override
  String get sessionExportMarkdownSaved => 'Exportação Markdown salva';

  @override
  String get sessionExportMarkdownTitle => 'Exportar sessão como Markdown';

  @override
  String get sessionExportOutput => 'Saída:';

  @override
  String get sessionExportUntitled => 'Sessão sem título';

  @override
  String get sessionExportUser => 'Usuário';

  @override
  String get sessionFailedRename => 'Falha ao renomear conversa';

  @override
  String get sessionFailedUpdateArchive =>
      'Falha ao atualizar estado de arquivamento';

  @override
  String get sessionFailedUpdateSharing =>
      'Falha ao atualizar estado de compartilhamento';

  @override
  String get sessionFork => 'Bifurcar';

  @override
  String get sessionForkFailed => 'Falha ao bifurcar conversa';

  @override
  String get sessionForked => 'Conversa bifurcada';

  @override
  String sessionHasError(String title) {
    return '\"$title\" tem um erro.';
  }

  @override
  String sessionHasNewReply(String title) {
    return '\"$title\" tem uma nova resposta.';
  }

  @override
  String get sessionKeyboardShortcuts => 'Atalhos de teclado';

  @override
  String sessionNeedsInput(String title) {
    return '\"$title\" precisa de sua entrada.';
  }

  @override
  String get sessionNoCachedConversations => 'Nenhuma conversa em cache';

  @override
  String get sessionNoConversationsInProject =>
      'Nenhuma conversa neste projeto.';

  @override
  String get sessionNotAvailable =>
      'A conversa ainda não está disponível para este projeto';

  @override
  String get sessionOpenProjectToLoad =>
      'Abra o projeto para carregar conversas.';

  @override
  String get sessionPin => 'Fixar';

  @override
  String get sessionRename => 'Renomear';

  @override
  String get sessionRenameHint => 'Digite o novo nome da conversa';

  @override
  String get sessionRenameTitle => 'Renomear Conversa';

  @override
  String get sessionSaveTitle => 'Salvar título';

  @override
  String get sessionShare => 'Compartilhar sessão';

  @override
  String get sessionShareAction => 'Compartilhar';

  @override
  String get sessionShareLinkCopied => 'Link de compartilhamento copiado';

  @override
  String get sessionShareLinkUnavailable =>
      'Link indisponível para esta sessão';

  @override
  String get sessionShared => 'Conversação compartilhada';

  @override
  String get sessionSyncing => 'Sincronizando conversas...';

  @override
  String get sessionTitleHint => 'Título da conversa';

  @override
  String get sessionUnarchive => 'Desarquivar';

  @override
  String get sessionUnpin => 'Desafixar';

  @override
  String get sessionUnshare => 'Parar de compartilhar';

  @override
  String get sessionUnshareAction => 'Parar de compartilhar';

  @override
  String get sessionUnshared => 'Conversação não compartilhada';

  @override
  String get sessionViewTasks => 'Ver tarefas';

  @override
  String get settingsAboutCheckForUpdates => 'Verificar atualizações';

  @override
  String get settingsAboutCheckOnOpen => 'Verificar atualizações ao abrir';

  @override
  String get settingsAboutCheckOnOpenDescription =>
      'Verificar automaticamente quando o app iniciar';

  @override
  String get settingsAboutChecking => 'Verificando...';

  @override
  String get settingsAboutDescription =>
      'Versão, atualizações, ajuda e dados do app';

  @override
  String get settingsAboutDismiss => 'Dispensar';

  @override
  String settingsAboutDownloading(String percent) {
    return 'Baixando... $percent%';
  }

  @override
  String get settingsAboutEraseAllData => 'Apagar todos os dados e reiniciar';

  @override
  String get settingsAboutInstallUpdate => 'Instalar atualização';

  @override
  String get settingsAboutInstalling => 'Instalando...';

  @override
  String settingsAboutLatestVersion(String version) {
    return 'v$version é a versão mais recente';
  }

  @override
  String get settingsAboutLoading => 'Carregando...';

  @override
  String get settingsAboutReplayChatTour => 'Repetir tour do chat';

  @override
  String get settingsAboutReplayChatTourDescription =>
      'Fechar configurações e mostrar o guia do chat';

  @override
  String get settingsAboutResetApp => 'Redefinir app';

  @override
  String get settingsAboutResetAppQuestion => 'Redefinir app?';

  @override
  String get settingsAboutResetAppWarning =>
      'Isso apagará todos os servidores, configurações e dados em cache. Esta ação não pode ser desfeita.';

  @override
  String get settingsAboutRetryInstall => 'Tentar instalar novamente';

  @override
  String get settingsAboutTapToCheck => 'Toque para buscar novas versões';

  @override
  String get settingsAboutTitle => 'Sobre';

  @override
  String get settingsAboutUpToDate => 'Você está em dia';

  @override
  String settingsAboutUpdateAvailable(String version) {
    return 'Atualização disponível: v$version';
  }

  @override
  String get settingsAboutUpdateInstalled =>
      'Atualização instalada. Reinicie o app para aplicar.';

  @override
  String settingsAboutUpdateVersionSummary(
    String installedVersion,
    String latestVersion,
  ) {
    return 'Atual: $installedVersion; disponível: v$latestVersion';
  }

  @override
  String get settingsAboutVersion => 'Versão';

  @override
  String settingsAboutVersionBuild(String buildNumber, String version) {
    return '$version (compilação $buildNumber)';
  }

  @override
  String get settingsAppearanceAmoledDark => 'Modo escuro AMOLED';

  @override
  String get settingsAppearanceAmoledDarkActive =>
      'Usar superfícies pretas puras enquanto o modo escuro estiver ativo.';

  @override
  String get settingsAppearanceAmoledDarkInactive =>
      'Mude para o modo escuro para habilitar superfícies AMOLED.';

  @override
  String get settingsAppearanceBrandColor => 'Cor da marca';

  @override
  String get settingsAppearanceBrandColorDynamicBlocked =>
      'Desative as cores do papel de parede para escolher uma cor da marca.';

  @override
  String get settingsAppearanceBrandColorNormal =>
      'Escolha uma cor semente para a paleta do app.';

  @override
  String get settingsAppearanceBrandColorPresetBlocked =>
      'Mude para CodeWalk Clássico para escolher uma cor da marca.';

  @override
  String get settingsAppearanceChatFontScale => 'Tamanho do texto da conversa';

  @override
  String get settingsAppearanceChatFontScaleDescription =>
      'Ajusta o texto das mensagens do chat e do composer acima do tamanho do texto do sistema.';

  @override
  String get settingsAppearanceCodeWalkClassic => 'CodeWalk Clássico';

  @override
  String get settingsAppearanceComposerTips => 'Dicas do composer';

  @override
  String get settingsAppearanceComposerTipsDescription =>
      'Mostrar ou ocultar dicas rotativas enquanto o assistente está raciocinando.';

  @override
  String get settingsAppearanceContrast => 'Contraste';

  @override
  String get settingsAppearanceContrastDynamicBlocked =>
      'Desative as cores do papel de parede para ajustar o contraste.';

  @override
  String get settingsAppearanceContrastHigh => 'Alto';

  @override
  String get settingsAppearanceContrastNormal =>
      'Ajuste o nível de contraste do esquema de cores.';

  @override
  String get settingsAppearanceContrastPresetBlocked =>
      'Mude para CodeWalk Clássico para ajustar o contraste.';

  @override
  String get settingsAppearanceContrastReduced => 'Reduzido';

  @override
  String get settingsAppearanceDark => 'Escuro';

  @override
  String get settingsAppearanceDensity => 'Densidade';

  @override
  String get settingsAppearanceDensityDense => 'Densa';

  @override
  String get settingsAppearanceDensityDescription =>
      'Aplica espaçamento e densidade de componentes em todo o app.';

  @override
  String get settingsAppearanceDensityExtraDense => 'Extra Densa';

  @override
  String get settingsAppearanceDensityExtraSpacious => 'Extra Espaçosa';

  @override
  String get settingsAppearanceDensityNormal => 'Normal';

  @override
  String get settingsAppearanceDensitySpacious => 'Espaçosa';

  @override
  String get settingsAppearanceDescription =>
      'Escolha temas, cores, tamanho do texto e exibição do chat';

  @override
  String get settingsAppearanceFontSize => 'Tamanho do texto';

  @override
  String get settingsAppearanceFontSizeDescription =>
      'Ajusta o tamanho do texto do sistema, da conversa e do terminal.';

  @override
  String get settingsAppearanceLight => 'Claro';

  @override
  String get settingsAppearanceMathRendering => 'Renderização de matemática';

  @override
  String get settingsAppearanceMathRenderingDescription =>
      'Renderizar expressões matemáticas LaTeX como equações tipografadas nas mensagens de chat.';

  @override
  String get settingsAppearanceNoPresets => 'Nenhuma paleta encontrada';

  @override
  String get settingsAppearanceOpenCodePresets => 'Presets OpenCode';

  @override
  String get settingsAppearancePresetHelper =>
      'Espelha a lista oficial de temas integrados do OpenCode Web.';

  @override
  String get settingsAppearancePresetNote =>
      'As cores do tema agora seguem o registro oficial do OpenCode Web e também orientam as superfícies de markdown/código.';

  @override
  String get settingsAppearancePresetPalette => 'Paleta predefinida';

  @override
  String get settingsAppearanceSearchPreset => 'Buscar paleta predefinida';

  @override
  String get settingsAppearanceSectionDescription =>
      'Ajuste a densidade visual e as superfícies de mensagem para o seu fluxo de trabalho.';

  @override
  String get settingsAppearanceSectionTitle => 'Aparência';

  @override
  String get settingsAppearanceSystem => 'Sistema';

  @override
  String get settingsAppearanceSystemFontScale => 'Tamanho do texto do sistema';

  @override
  String get settingsAppearanceSystemFontScaleDescription =>
      'Ajusta todo o texto do app, incluindo menus, diálogos e barras laterais.';

  @override
  String get settingsAppearanceTaskList => 'Lista de tarefas';

  @override
  String get settingsAppearanceTaskListDescription =>
      'Mostrar ou ocultar o widget de lista de tarefas da sessão.';

  @override
  String get settingsAppearanceTerminalFontSize =>
      'Tamanho do texto do terminal';

  @override
  String get settingsAppearanceTerminalFontSizeDescription =>
      'Redimensiona a fonte do terminal embutido. Aplica-se imediatamente às sessões em execução.';

  @override
  String get settingsAppearanceTheme => 'Tema';

  @override
  String get settingsAppearanceThemeDescription =>
      'Escolha entre modo claro, escuro ou sistema, depois mantenha a paleta clássica do CodeWalk ou mude para um preset OpenCode.';

  @override
  String get settingsAppearanceVisualStyle => 'Estilo visual';

  @override
  String get settingsAppearanceVisualStyleDescription =>
      'Escolha a aparência clássica ou superfícies refinadas mais suaves.';

  @override
  String get settingsAppearanceVisualStyleClassic => 'Clássico';

  @override
  String get settingsAppearanceVisualStyleRefined => 'Refinado';

  @override
  String get settingsAppearanceThinkingBubbles => 'Balões de pensamento';

  @override
  String get settingsAppearanceThinkingBubblesDescription =>
      'Mostrar ou ocultar blocos de raciocínio nas mensagens do assistente.';

  @override
  String get settingsAppearanceTitle => 'Aparência';

  @override
  String get settingsAppearanceToolCallBubbles =>
      'Balões de chamada de ferramenta';

  @override
  String get settingsAppearanceToolCallBubblesDescription =>
      'Mostrar ou ocultar cartões de execução de ferramentas nas mensagens do assistente.';

  @override
  String get settingsAppearanceWallpaperColors =>
      'Usar cores do papel de parede';

  @override
  String get settingsAppearanceWallpaperNormal =>
      'Extrair esquema de cores do papel de parede do dispositivo.';

  @override
  String get settingsAppearanceWallpaperPresetBlocked =>
      'Mude para CodeWalk Clássico para usar cores do papel de parede.';

  @override
  String get settingsAppearanceWindowChrome => 'Abas da janela';

  @override
  String get settingsAppearanceWindowChromeDescription =>
      'Escolha como as abas de sessão e a barra de título se combinam no desktop.';

  @override
  String get settingsAppearanceWindowChromeIntegrated => 'Abas integradas';

  @override
  String get settingsAppearanceWindowChromeIntegratedDescription =>
      'As abas ficam no topo da janela e a barra de título do sistema fica oculta.';

  @override
  String get settingsAppearanceWindowChromeSystem => 'Decoração do sistema';

  @override
  String get settingsAppearanceWindowChromeSystemDescription =>
      'Mantém a barra de título nativa e mostra as abas abaixo da barra do app.';

  @override
  String get settingsBack => 'Voltar';

  @override
  String get settingsBehaviorAutoupdateCaveat =>
      'Use a seção Sobre para verificações de versão do CodeWalk. Esta configuração apenas espelha a config `autoupdate` oficial do OpenCode.';

  @override
  String get settingsBehaviorAutoupdateHelp =>
      'Controla as atualizações de runtime do OpenCode upstream, não as verificações de atualização do app CodeWalk.';

  @override
  String get settingsBehaviorCellularDataSaver => 'Economia de dados móveis';

  @override
  String get settingsBehaviorChatRenderMode => 'Modo de renderização do chat';

  @override
  String get settingsBehaviorChatRenderModeBlock => 'Bloco';

  @override
  String get settingsBehaviorChatRenderModeBlockDescription =>
      'Oculta o texto ao vivo do assistente, o raciocínio e os cards de ferramentas até que o turno atual possa ser mostrado como um único bloco.';

  @override
  String get settingsBehaviorChatRenderModeDescription =>
      'Escolha se as respostas do assistente aparecem conforme transmitidas ou são reveladas após o término do turno atual.';

  @override
  String get settingsBehaviorChatRenderModeLive => 'Ao vivo';

  @override
  String get settingsBehaviorChatRenderModeLiveDescription =>
      'Mostra o texto do assistente, o raciocínio e a atividade de ferramentas conforme o OpenCode transmite os eventos.';

  @override
  String get settingsBehaviorComposerSpellCheck => 'Corretor do composer';

  @override
  String get settingsBehaviorComposerSpellCheckDescription =>
      'Usa o corretor ortográfico, sugestões e autocorreção nativos da plataforma no composer do chat.';

  @override
  String get settingsBehaviorConfigDeferred =>
      'O CodeWalk aplicará esta configuração do OpenCode após a resposta atual terminar.';

  @override
  String settingsBehaviorConfigUpdateFailed(String field) {
    return 'Não foi possível atualizar o $field do OpenCode.';
  }

  @override
  String get settingsBehaviorConversationUsername =>
      'Nome de usuário da conversa';

  @override
  String get settingsBehaviorConversationUsernameHelp =>
      'Nome de exibição personalizado mostrado nas conversas em vez do nome do sistema.';

  @override
  String get settingsBehaviorDataSaverActive => 'Ativo agora em dados móveis.';

  @override
  String get settingsBehaviorDataSaverCellularOnly =>
      'Aplica-se apenas quando a conexão for celular/móvel.';

  @override
  String get settingsBehaviorDataSaverDescription =>
      'Reduz o uso automático de dados móveis interrompendo downloads em segundo plano e limitando as atualizações automáticas em primeiro plano.';

  @override
  String get settingsBehaviorDataSaverWaiting =>
      'Aguardando a próxima janela de sincronização de dados móveis.';

  @override
  String get settingsBehaviorDefaultAgent => 'Agente padrão';

  @override
  String get settingsBehaviorDefaultAgentHelp =>
      'Agente principal usado quando nenhum agente é escolhido explicitamente.';

  @override
  String get settingsBehaviorDefaultModel => 'Modelo padrão';

  @override
  String get settingsBehaviorDefaultModelHelp =>
      'Compartilhado entre clientes OpenCode via config.';

  @override
  String get settingsBehaviorDescription =>
      'Controle idioma, comportamento do chat, uso de dados e padrões do OpenCode';

  @override
  String get settingsBehaviorEnableDataSaver =>
      'Habilitar economia de dados móveis';

  @override
  String get settingsBehaviorMultiDeviceSync =>
      'Habilitar sincronização experimental entre dispositivos';

  @override
  String get settingsBehaviorMultiDeviceSyncDescription =>
      'Sincroniza a seleção do composer (agente/modelo/variante) com a config do servidor ativo.';

  @override
  String get settingsBehaviorMultiDeviceSyncWarning =>
      'Pode abortar sessões em andamento ao trabalhar em mais de uma sessão ao mesmo tempo.';

  @override
  String get settingsBehaviorNoAgents => 'Nenhum agente encontrado';

  @override
  String get settingsBehaviorNoModels => 'Nenhum modelo encontrado';

  @override
  String get settingsBehaviorOpenCodeAutoupdate =>
      'Atualização automática do OpenCode';

  @override
  String get settingsBehaviorOpenCodeDefaults => 'Padrões do OpenCode';

  @override
  String get settingsBehaviorOpenCodeDefaultsDescription =>
      'Esses valores gravam em `/config` no servidor ativo e correspondem à config oficial do OpenCode.';

  @override
  String get settingsBehaviorOpenCodeSnapshots => 'Snapshots do OpenCode';

  @override
  String get settingsBehaviorOpenCodeSnapshotsDescription =>
      'Manter snapshots git habilitados para histórico de desfazer/refazer e recuperação.';

  @override
  String get settingsBehaviorPermissionDeferred =>
      'A edição avançada de regras de permissão fica fora das Configurações por enquanto e é adiada para trabalho futuro de paridade.';

  @override
  String get settingsBehaviorPermissionProvenance =>
      'Procedência do tratamento de permissões';

  @override
  String get settingsBehaviorPermissionProvenanceDescription =>
      'A política oficial de permissão do OpenCode é configurada no `opencode.json` com regras allow/ask/deny por ferramenta. O CodeWalk mantém os cards oficiais de solicitação de permissão e adiciona uma exceção ADR-023 aprovada: o toggle de auto-aprovação do composer responde com `Always` e `remember: true` incondicionalmente para criar concessões duráveis com escopo de sessão. O mesmo caminho de continuidade com escopo de thread permanece ativo no worker Android em segundo plano.';

  @override
  String get settingsBehaviorRefreshDefaults => 'Atualizar padrões';

  @override
  String get settingsBehaviorSaveUsername => 'Salvar nome de usuário';

  @override
  String get settingsBehaviorSearchAutoupdate => 'Buscar modo de atualização';

  @override
  String get settingsBehaviorSearchDefaultAgent => 'Buscar agente padrão';

  @override
  String get settingsBehaviorSearchDefaultModel => 'Buscar modelo padrão';

  @override
  String get settingsBehaviorSearchShareMode =>
      'Buscar modo de compartilhamento';

  @override
  String get settingsBehaviorSearchSmallModel => 'Buscar modelo pequeno';

  @override
  String get settingsBehaviorShareMode =>
      'Padrão de compartilhamento do OpenCode';

  @override
  String get settingsBehaviorShareModeCaveat =>
      'Use a ação de compartilhar no chat para publicar uma sessão agora. Esta configuração apenas altera a política de compartilhamento padrão do OpenCode.';

  @override
  String get settingsBehaviorShareModeHelp =>
      'Controla a config global oficial `share`, não o botão de compartilhar de um chat individual.';

  @override
  String get settingsBehaviorSmallModel => 'Modelo pequeno';

  @override
  String get settingsBehaviorSmallModelAutoFallback => 'Fallback automático';

  @override
  String get settingsBehaviorSmallModelFallbackActive =>
      'O fallback automático do OpenCode está ativo porque `small_model` não está definido.';

  @override
  String get settingsBehaviorSmallModelHelp =>
      'Usado para tarefas leves como geração de títulos.';

  @override
  String get settingsBehaviorSmallModelResetCaveat =>
      'Redefinir `small_model` de volta ao fallback automático ainda requer editar a config fora do app.';

  @override
  String get settingsBehaviorSnapshotCaveat =>
      'Isso controla o armazenamento de snapshots e suporte a undo/redo do OpenCode, não os snapshots de cache local do CodeWalk.';

  @override
  String get settingsBehaviorTitle => 'Comportamento';

  @override
  String get settingsBehaviorUsernameFallback =>
      'O OpenCode usa o nome de usuário do sistema porque `username` não está definido.';

  @override
  String get settingsBehaviorUsernamePatchCaveat =>
      'Redefinir `username` de volta ao padrão do sistema ainda requer editar a config fora do app porque atualizações de patch `/config` não podem remover chaves.';

  @override
  String get settingsConfigRefreshFailed =>
      'Configuração do servidor atualizada, mas não foi possível atualizar os provedores de chat.';

  @override
  String get settingsConfigUpdateDeferred =>
      'O CodeWalk aplicará esta configuração do OpenCode após o término da resposta atual.';

  @override
  String get settingsConversationUsername => 'Nome de usuário da conversa';

  @override
  String get settingsDefaultAgent => 'Agente padrão';

  @override
  String get settingsDefaultModel => 'Modelo padrão';

  @override
  String get settingsLanguageDescription =>
      'Escolha o idioma usado pelo CodeWalk. O padrão do sistema segue o idioma do dispositivo.';

  @override
  String get settingsLanguageEmptyText => 'Nenhum idioma encontrado';

  @override
  String get settingsLanguageFieldHelper =>
      'Aplica imediatamente e persiste após reiniciar.';

  @override
  String get settingsLanguageFieldLabel => 'Idioma do app';

  @override
  String get settingsLanguageSearchHint => 'Pesquisar idiomas';

  @override
  String get settingsLanguageSystemDefault => 'Padrão do sistema';

  @override
  String get settingsLanguageTitle => 'Idioma';

  @override
  String get settingsLogsDescription =>
      'Revise os diagnósticos do app e os detalhes de solução de problemas';

  @override
  String get settingsLogsTitle => 'Registros';

  @override
  String get settingsNoAgentsFound => 'Nenhum agente encontrado';

  @override
  String get settingsNotificationsAgentSubtitle =>
      'Quando uma resposta termina';

  @override
  String get settingsNotificationsAgentUpdates => 'Atualizações do agente';

  @override
  String get settingsNotificationsAnotherConversation => 'Outra conversa';

  @override
  String get settingsNotificationsAppInBackground => 'App em segundo plano';

  @override
  String get settingsNotificationsBackgroundAlerts =>
      'Alertas em segundo plano Android';

  @override
  String get settingsNotificationsBackgroundBehavior =>
      'Comportamento em segundo plano';

  @override
  String get settingsNotificationsBackgroundBehaviorDescription =>
      'Escolha como o CodeWalk se comporta depois que o app sai do primeiro plano.';

  @override
  String get settingsNotificationsBackgroundDescription =>
      'Usa monitoramento de baixo consumo de dados em segundo plano para conclusões de resposta, solicitações de permissão, perguntas e erros enquanto o app não está na tela.';

  @override
  String get settingsNotificationsBackgroundToggle =>
      'Alertas em segundo plano no Android';

  @override
  String get settingsNotificationsBackgroundToggleDescription =>
      'Desativa todas as verificações em segundo plano do Android e oculta a notificação persistente do monitor.';

  @override
  String get settingsNotificationsBatteryDescription =>
      'Se as notificações só chegam ao reabrir o app, permita que o CodeWalk execute sem otimização neste dispositivo.';

  @override
  String get settingsNotificationsBatteryDisabled =>
      'A otimização de bateria está desativada para o CodeWalk.';

  @override
  String get settingsNotificationsBatteryEnabled =>
      'A otimização de bateria está ativada. Alguns dispositivos podem atrasar os alertas em segundo plano.';

  @override
  String get settingsNotificationsBatteryOptimization =>
      'Otimização de bateria do Android';

  @override
  String get settingsNotificationsBatteryUnknown =>
      'Ainda não foi possível ler o status de otimização de bateria.';

  @override
  String get settingsNotificationsChooseAudioFile =>
      'Escolher arquivo de áudio';

  @override
  String get settingsNotificationsChooseSystemSound =>
      'Escolher som do sistema';

  @override
  String get settingsNotificationsCloseToTray => 'Fechar para bandeja';

  @override
  String get settingsNotificationsCloseToTrayDescription =>
      'Ocultar janela e continuar executando na bandeja do sistema.';

  @override
  String get settingsNotificationsDescription =>
      'Escolha quais eventos alertam você e como';

  @override
  String get settingsNotificationsDisableOptimization => 'Desativar otimização';

  @override
  String get settingsNotificationsErrors => 'Erros';

  @override
  String get settingsNotificationsErrorsSubtitle =>
      'Quando uma sessão relata uma falha';

  @override
  String get settingsNotificationsJustClose => 'Apenas fechar';

  @override
  String get settingsNotificationsJustCloseDescription =>
      'Sair completamente do aplicativo.';

  @override
  String get settingsNotificationsKeepLive => 'Manter alertas ativos por 3 min';

  @override
  String get settingsNotificationsKeepLiveDescription =>
      'Quando uma resposta já está em execução, mantém o tempo real ativo brevemente após sair do app.';

  @override
  String get settingsNotificationsLocal => 'Local';

  @override
  String get settingsNotificationsMinimizeWhenClose => 'Minimizar ao fechar';

  @override
  String get settingsNotificationsMinimizeWhenCloseDescription =>
      'Minimizar para a barra de tarefas/dock e continuar executando.';

  @override
  String get settingsNotificationsNoCondition =>
      'Se nenhuma condição for selecionada, os alertas são permitidos em qualquer contexto.';

  @override
  String get settingsNotificationsNotify => 'Notificar';

  @override
  String get settingsNotificationsNotifyOnlyWhen => 'Notificar apenas quando';

  @override
  String get settingsNotificationsOpenBatterySettings =>
      'Abrir configurações de bateria';

  @override
  String get settingsNotificationsPermissions => 'Permissões e perguntas';

  @override
  String get settingsNotificationsPermissionsSubtitle =>
      'Quando ferramentas solicitam sua entrada';

  @override
  String get settingsNotificationsPreview => 'Pré-visualizar';

  @override
  String get settingsNotificationsRefreshStatus => 'Atualizar status';

  @override
  String get settingsNotificationsSearchSoundType => 'Buscar tipo de som';

  @override
  String get settingsNotificationsSectionDescription =>
      'Controle quando os alertas aparecem e quando podem reproduzir som.';

  @override
  String get settingsNotificationsSectionTitle => 'Notificações';

  @override
  String settingsNotificationsSelectedSound(String label) {
    return 'Selecionado: $label';
  }

  @override
  String get settingsNotificationsServer => 'Servidor';

  @override
  String get settingsNotificationsSound => 'Som';

  @override
  String get settingsNotificationsSoundBuiltInAlert => 'Alerta integrado';

  @override
  String get settingsNotificationsSoundBuiltInClick => 'Clique integrado';

  @override
  String get settingsNotificationsSoundOff => 'Desativado';

  @override
  String get settingsNotificationsSoundOnlyWhen => 'Som apenas quando';

  @override
  String get settingsNotificationsSoundPickAudioFile =>
      'Escolher arquivo de áudio';

  @override
  String get settingsNotificationsSoundPickFromSystem => 'Escolher do sistema';

  @override
  String get settingsNotificationsSoundSystemDefault => 'Padrão do sistema';

  @override
  String get settingsNotificationsSoundType => 'Tipo de som';

  @override
  String get settingsNotificationsSyncInfo =>
      'Alguns toggles de categoria são sincronizados do /config no servidor ativo.';

  @override
  String get settingsNotificationsSyncInfoLocal =>
      'O servidor atual não expõe toggles de notificação no /config; os valores locais estão ativos.';

  @override
  String get settingsNotificationsSystemSoundPickerTitle =>
      'Escolher som do sistema';

  @override
  String get settingsNotificationsTitle => 'Notificações';

  @override
  String get settingsNotificationsWhenClosing => 'Ao fechar a janela';

  @override
  String get settingsOpenCodeAutoUpdate => 'Atualização automática do OpenCode';

  @override
  String get settingsOpenCodeSharingDefault =>
      'Padrão de compartilhamento do OpenCode';

  @override
  String get settingsReadAloudEnabled => 'Ler em voz alta';

  @override
  String get settingsReadAloudEnabledDescription =>
      'Mostrar botão para ler em voz alta nas mensagens do assistente.';

  @override
  String get settingsReadAloudPitch => 'Tom';

  @override
  String get settingsReadAloudPitchDescription => 'Ajustar o tom de voz.';

  @override
  String get settingsReadAloudSectionDescription =>
      'Ler respostas do assistente em voz alta. Configure velocidade, tom e voz.';

  @override
  String get settingsReadAloudSectionTitle => 'Conversão de texto em fala';

  @override
  String get settingsReadAloudSpeed => 'Velocidade';

  @override
  String get settingsReadAloudSpeedDescription => 'Ajustar a taxa de fala.';

  @override
  String get settingsReadAloudVoice => 'Voz';

  @override
  String get settingsReadAloudVoiceHint => 'Selecione uma voz para leitura.';

  @override
  String get settingsSearchAutoUpdateMode =>
      'Buscar modo de atualização automática';

  @override
  String get settingsSearchDefaultAgent => 'Buscar agente padrão';

  @override
  String get settingsSearchDefaultModel => 'Buscar modelo padrão';

  @override
  String get settingsSearchSharingMode => 'Buscar modo de compartilhamento';

  @override
  String get settingsSearchSmallModel => 'Buscar modelo pequeno';

  @override
  String get settingsServersActive => 'Ativo';

  @override
  String get settingsServersChooseActive => 'Escolher servidor ativo';

  @override
  String get settingsServersDefault => 'Padrão';

  @override
  String get settingsServersDescription =>
      'Conecte-se ao OpenCode e gerencie seus servidores';

  @override
  String get settingsServersTitle => 'Servidores';

  @override
  String get settingsSessionAttentionSize => 'Tamanho da Bubble';

  @override
  String get settingsSessionAttentionSizeExtraLarge => 'Extra grande';

  @override
  String get settingsSessionAttentionSizeExtraSmall => 'Extra pequeno';

  @override
  String get settingsSessionAttentionSizeLarge => 'Grande';

  @override
  String get settingsSessionAttentionSizeSmall => 'Pequeno';

  @override
  String get settingsSessionAttentionSizeStandard => 'Padrão';

  @override
  String get settingsSetupWizard => 'Assistente de configuração';

  @override
  String get settingsShortcutsDescription =>
      'Encontre e personalize os atalhos de teclado';

  @override
  String get settingsShortcutsEdit => 'Editar atalho';

  @override
  String get settingsShortcutsKeyboard => 'Atalhos de teclado';

  @override
  String get settingsShortcutsReset => 'Redefinir atalho';

  @override
  String get settingsShortcutsSearch => 'Buscar atalhos';

  @override
  String get settingsShortcutsTitle => 'Atalhos';

  @override
  String get settingsSmallModel => 'Modelo pequeno';

  @override
  String get settingsSmallModelResetExplanation =>
      'Redefinir `small_model` de volta para o fallback automático ainda requer edição da configuração fora do aplicativo porque as atualizações de patch `/config` não podem remover chaves.';

  @override
  String get settingsSmallModelUnsetExplanation =>
      'O fallback automático do OpenCode está ativo porque `small_model` não está definido.';

  @override
  String get settingsSoundPickerNotAvailable =>
      'O seletor de sons do sistema não está disponível nesta plataforma.';

  @override
  String get settingsSpeechDescription =>
      'Configure entrada de voz, modelos offline e leitura em voz alta';

  @override
  String get settingsSpeechRefreshStatus => 'Atualizar status';

  @override
  String settingsSpeechSilenceTimeout(String value) {
    return 'Tempo de silêncio: ${value}s';
  }

  @override
  String get settingsSpeechTitle => 'Fala para texto';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get settingsGroupAlertTypes => 'Tipos de alerta';

  @override
  String get settingsGroupBackgroundBehavior =>
      'Comportamento em segundo plano';

  @override
  String get settingsGroupChatDisplay => 'Exibição do chat';

  @override
  String get settingsGroupCurrentConnection => 'Conexão atual';

  @override
  String get settingsGroupDataAndSync => 'Dados e sincronização';

  @override
  String get settingsGroupDataReset => 'Dados e redefinição';

  @override
  String get settingsGroupDelivery => 'Entrega';

  @override
  String get settingsGroupHelp => 'Ajuda';

  @override
  String get settingsGroupLanguageAndChat => 'Idioma e chat';

  @override
  String get settingsGroupLayoutAndText => 'Layout e texto';

  @override
  String get settingsGroupOfflineModels => 'Modelos offline';

  @override
  String get settingsGroupOpenCodeDefaults => 'Padrões do OpenCode';

  @override
  String get settingsGroupReadAloud => 'Leitura em voz alta';

  @override
  String get settingsGroupSavedServers => 'Servidores salvos';

  @override
  String get settingsGroupThemeAndColor => 'Tema e cor';

  @override
  String get settingsGroupThisDevice => 'Este dispositivo';

  @override
  String get settingsGroupVersionUpdates => 'Versão e atualizações';

  @override
  String get settingsGroupVoiceInput => 'Entrada de voz';

  @override
  String get settingsNavigationGroupExperience => 'Experiência';

  @override
  String get settingsNavigationGroupInput => 'Entrada';

  @override
  String get settingsNavigationGroupSetup => 'Configuração';

  @override
  String get settingsNavigationGroupSupport => 'Ajuda e diagnóstico';

  @override
  String get settingsNavigationNoResults => 'Nenhuma configuração encontrada';

  @override
  String get settingsNavigationSearchHint => 'Pesquisar configurações';

  @override
  String get settingsUsernameClearHint =>
      'Limpar o nome de usuário da conversa do OpenCode ainda requer a edição da configuração fora do aplicativo.';

  @override
  String get settingsUsernameEnterHint =>
      'Digite um nome de usuário para salvar um nome de conversa personalizado do OpenCode.';

  @override
  String get settingsUsernameResetExplanation =>
      'Redefinir `username` de volta para o padrão do sistema ainda requer edição da configuração fora do aplicativo porque as atualizações de patch `/config` não podem remover chaves.';

  @override
  String get settingsUsernameUnsetExplanation =>
      'O OpenCode usa o nome de usuário do sistema porque `username` não está definido.';

  @override
  String get setupDebugBun => 'Bun';

  @override
  String get setupDebugBun2 => 'Bun';

  @override
  String get setupDebugCapturedSetupDetails =>
      'Nenhum detalhe de configuração capturado ainda';

  @override
  String get setupDebugCapturedSetupLogs => 'Logs de configuração capturados';

  @override
  String get setupDebugClear => 'Limpar debug de configuração';

  @override
  String get setupDebugClearSetupDebug => 'Limpar depuração de configuração';

  @override
  String get setupDebugCodeWalkCaptureEnough =>
      'Se o CodeWalk não capturar contexto suficiente, verifique os logs oficiais do OpenCode e os endpoints de saúde diretamente:';

  @override
  String get setupDebugCommandPath => 'Caminho do comando';

  @override
  String get setupDebugCommandPath2 => 'Caminho do comando';

  @override
  String get setupDebugCopy => 'Copiar debug de configuração';

  @override
  String get setupDebugCopySetupDebug => 'Copiar depuração de configuração';

  @override
  String get setupDebugCurrentStatus => 'Estado atual';

  @override
  String get setupDebugDiagnosticsLoading =>
      'Os diagnósticos ainda estão carregando.';

  @override
  String get setupDebugEnvironment => 'Diagnóstico do ambiente';

  @override
  String get setupDebugEnvironmentDiagnostics => 'Diagnóstico do ambiente';

  @override
  String get setupDebugFocusedOpenCodeSetup =>
      'Focado na configuração do OpenCode';

  @override
  String get setupDebugInstallDir => 'Diretório de instalação';

  @override
  String get setupDebugInstallDirectory => 'Diretório de instalação';

  @override
  String get setupDebugLatestLocalServer => 'Última saída do servidor local';

  @override
  String get setupDebugLogs => 'Logs de configuração capturados';

  @override
  String get setupDebugManual => 'Solução de problemas manual';

  @override
  String get setupDebugManualTroubleshooting => 'Solução de problemas manual';

  @override
  String get setupDebugNetwork => 'Rede';

  @override
  String get setupDebugNetwork2 => 'Rede';

  @override
  String get setupDebugNoDetails =>
      'Nenhum detalhe de configuração capturado ainda';

  @override
  String get setupDebugNode => 'Node.js';

  @override
  String get setupDebugNodeJs => 'Node.js';

  @override
  String get setupDebugNpm => 'npm';

  @override
  String get setupDebugNpm2 => 'npm';

  @override
  String get setupDebugOpenCode => 'OpenCode';

  @override
  String get setupDebugOpenCode2 => 'OpenCode';

  @override
  String get setupDebugOpenCodeSetupDebug =>
      'Depuração de Configuração do OpenCode';

  @override
  String get setupDebugPlatform => 'Plataforma';

  @override
  String get setupDebugPlatform2 => 'Plataforma';

  @override
  String get setupDebugRunDiagnosticsTry =>
      'Execute diagnósticos, tente um método de instalação ou tente um fluxo de configuração para capturar detalhes específicos de solução de problemas do OpenCode aqui.';

  @override
  String get setupDebugScreenCoversOpenCode =>
      'Esta tela cobre apenas a instalação, diagnósticos e solução de problemas de configuração local do OpenCode. Use os Logs do App para problemas gerais de execução del CodeWalk.';

  @override
  String get setupDebugServerOutput => 'Última saída do servidor local';

  @override
  String get setupDebugStatus => 'Status atual';

  @override
  String setupDebugTimeEntrySource(String source, String time) {
    return '$time - $source';
  }

  @override
  String get setupDebugTimeline => 'Linha do tempo';

  @override
  String get setupDebugTimeline2 => 'Linha do tempo';

  @override
  String get setupDebugTitle => 'Focado na configuração do OpenCode';

  @override
  String get setupDebugWSL => 'WSL';

  @override
  String get setupDebugWsl => 'WSL';

  @override
  String get shortcutCloseApp => 'Fechar aba/aplicativo';

  @override
  String get shortcutCloseAppDesc =>
      'Fechar a aba da sessão atual quando disponível; caso contrário, fechar o aplicativo usando o comportamento da plataforma';

  @override
  String get shortcutFocusCloseDrawer => 'Focar/fechar painel';

  @override
  String get shortcutFocusCloseDrawerDesc =>
      'Focar entrada por padrão, ou fechar painel quando aberto';

  @override
  String get shortcutFocusInput => 'Focar entrada';

  @override
  String get shortcutFocusInputDesc => 'Mover o foco para a entrada de texto';

  @override
  String get shortcutGroupApplication => 'Aplicativo';

  @override
  String get shortcutGroupGeneral => 'Geral';

  @override
  String get shortcutGroupModelAndAgent => 'Modelo e agente';

  @override
  String get shortcutGroupNavigation => 'Navegação';

  @override
  String get shortcutGroupPrompt => 'Prompt';

  @override
  String get shortcutGroupSession => 'Sessão';

  @override
  String get shortcutNewConversation => 'Nova conversa';

  @override
  String get shortcutNewConversationDesc => 'Criar uma nova sessão de chat';

  @override
  String get shortcutNextAgent => 'Próximo agente';

  @override
  String get shortcutNextAgentDesc =>
      'Alternar para o próximo agente disponível';

  @override
  String get shortcutNextRecentModel => 'Próximo modelo recente';

  @override
  String get shortcutNextRecentModelDesc =>
      'Alternar entre os modelos usados recentemente';

  @override
  String get shortcutNextVariant => 'Próxima variante';

  @override
  String get shortcutNextVariantDesc =>
      'Alternar entre as variantes de modelo disponíveis';

  @override
  String get shortcutOpenSettings => 'Abrir configurações';

  @override
  String get shortcutOpenSettingsDesc => 'Abrir a página de configurações';

  @override
  String get shortcutPreviousAgent => 'Agente anterior';

  @override
  String get shortcutPreviousAgentDesc =>
      'Alternar para o agente anterior disponível';

  @override
  String get shortcutQuickOpenFiles => 'Abertura rápida de arquivos';

  @override
  String get shortcutQuickOpenFilesDesc => 'Abrir busca rápida de arquivos';

  @override
  String get shortcutQuitApp => 'Sair do aplicativo';

  @override
  String get shortcutQuitAppDesc => 'Forçar a saída do aplicativo';

  @override
  String get shortcutRefreshData => 'Atualizar dados';

  @override
  String get shortcutRefreshDataDesc => 'Atualizar os dados do chat atual';

  @override
  String get shortcutStopResponse => 'Parar resposta';

  @override
  String get shortcutStopResponseDesc =>
      'Parar resposta ativa (enquanto responde)';

  @override
  String get shortcutToggleVoiceInput => 'Alternar entrada de voz';

  @override
  String get shortcutToggleVoiceInputDesc =>
      'Iniciar ou parar o ditado de voz no editor';

  @override
  String get shortcutsApply => 'Aplicar';

  @override
  String shortcutsConflictConflict(String conflict) {
    return 'Conflito com $conflict';
  }

  @override
  String get shortcutsKeyboardShortcuts => 'Atalhos de teclado';

  @override
  String get shortcutsReset => 'Restaurar tudo';

  @override
  String get shortcutsSearchEditBindings =>
      'Pesquisar, editar atalhos e resolver conflitos antes de salvar.';

  @override
  String shortcutsSetShortcutWidget(String label) {
    return 'Definir atalho: $label';
  }

  @override
  String get shortcutsTheseBindingsStored =>
      'Esses atalhos são armazenados no CodeWalk para a execução atual do app e não editam os atalhos de teclado do `tui.json` do OpenCode.';

  @override
  String get speechAutoStopSilence =>
      'Tempo limite de silêncio para parada automática';

  @override
  String get speechChooseRecognitionEngine =>
      'Escolha o mecanismo de reconhecimento, o tempo limite de silêncio e as opções de modelo.';

  @override
  String speechDesktopOnly(String service) {
    return '$service está disponível apenas na versão desktop.';
  }

  @override
  String get speechDownload => 'Baixar';

  @override
  String get speechEngine => 'Mecanismo';

  @override
  String get speechInstalledLanguages => 'Idiomas instalados';

  @override
  String get speechListeningStopsAutomatically =>
      'A escuta para automaticamente após esta quantidade de segundos de silêncio.';

  @override
  String get speechMicPermissionDisabled =>
      'A permissão do microfone está desativada.';

  @override
  String speechModelFilesIncomplete(String service) {
    return 'Os arquivos de modelo do $service estão incompletos.';
  }

  @override
  String get speechMoonshine => 'Moonshine';

  @override
  String get speechMoonshineModelsDesktop => 'Modelos Moonshine (desktop)';

  @override
  String get speechMoonshineStaysDownloadable =>
      'O Moonshine permanece disponível para download fora do pacote do app. Escolha um modelo para este dispositivo desktop e remova-o mais tarde se quiser recuperar o espaço.';

  @override
  String get speechNative => 'Nativo';

  @override
  String get speechNativeSTTDisabled =>
      'O STT nativo está desabilitado no Linux neste app. O Parakeet é o mecanismo padrão para novas instalações.';

  @override
  String get speechNativeSTTWorks =>
      'No Windows, o CodeWalk usa reconhecimento de fala local no dispositivo por meio do backend de microfone WASAPI. O reconhecimento de fala nativo do Windows está desabilitado por estabilidade.';

  @override
  String get speechNativeStartsFaster =>
      'O Nativo inicia mais rápido. O Sherpa é executado totalmente no dispositivo, com uma configuração mais pesada e maior controle do modelo.';

  @override
  String get speechOpenMicrophoneSettings => 'Abrir configurações do microfone';

  @override
  String get speechOpenSpeechPrivacy => 'Abrir privacidade de fala';

  @override
  String get speechOpenSpeechSettings => 'Abrir configurações de fala';

  @override
  String get speechParakeet => 'Parakeet';

  @override
  String get speechParakeetModelsDesktop => 'Modelos Parakeet (desktop)';

  @override
  String get speechParakeetStaysDownloadable =>
      'O Parakeet permanece disponível para download fora do pacote do app. Atualmente, ele disponibiliza um modelo multilíngue otimizado para 25 idiomas europeus.';

  @override
  String get speechPickLanguagePacks =>
      'Escolha os pacotes de idiomas e baixe/remova modelos para reconhecimento local no dispositivo.';

  @override
  String get speechRemove => 'Remover';

  @override
  String speechRuntimeFailed(String service) {
    return 'O tempo de execução do $service falhou ao inicializar.';
  }

  @override
  String get speechSelectSherpaAbove =>
      'Selecione Sherpa acima para gerenciar pacotes de idiomas e baixar modelos.';

  @override
  String get speechSenseVoice => 'SenseVoice';

  @override
  String get speechSenseVoiceModelsDesktop => 'Modelos SenseVoice (desktop)';

  @override
  String get speechSenseVoiceStaysDownloadable =>
      'O SenseVoice permanece disponível para download fora do pacote do app. É a opção de desktop mais robusta aqui para chinês, cantonês, japonês, coreano e inglês.';

  @override
  String get speechSherpa => 'Sherpa';

  @override
  String get speechSherpaExperimentalFail =>
      'O Sherpa é experimental e pode falhar em alguns dispositivos. Prefira o Nativo se desejar o comportamento mais estável.';

  @override
  String get speechSherpaModelsLinux => 'Modelos Sherpa (Linux)';

  @override
  String get speechSpeechText => 'Fala para texto';

  @override
  String speechUnavailableOnPlatform(String service) {
    return 'A fala do $service não está disponível nesta plataforma.';
  }

  @override
  String get speechWindowsSetupHint =>
      'A entrada de voz no Windows usa a captura WASAPI do CodeWalk com modelos no dispositivo. Mantenha habilitado o acesso ao microfone para apps de desktop; os botões abaixo abrem as configurações do Windows para solução de problemas.';

  @override
  String get statusConnected => 'Conectado';

  @override
  String get statusDelayed => 'Atrasado';

  @override
  String get statusFailed => 'Falhou';

  @override
  String get statusOffline => 'Offline';

  @override
  String get statusOnline => 'Online';

  @override
  String get statusReconnecting => 'Reconectando';

  @override
  String get statusStarting => 'Iniciando';

  @override
  String get statusStopped => 'Parado';

  @override
  String get statusStopping => 'Parando';

  @override
  String get statusSyncDelayed => 'Sincronização atrasada';

  @override
  String get tailscaleNoPeers => 'Nenhum par (peer) encontrado';

  @override
  String get tailscaleNotSupportedOnPlatform =>
      'O Tailscale não é suportado nesta plataforma.';

  @override
  String get tailscaleNotSupportedOnWindows =>
      'O Tailscale não é suportado no Windows.';

  @override
  String get tailscalePeerOffline => 'offline';

  @override
  String get tailscaleSelectPeer => 'Selecione um par Tailscale';

  @override
  String get tailscaleWaitingAdminApproval =>
      'Este nó do Tailscale está aguardando aprovação do administrador.';

  @override
  String get terminalClose => 'Fechar terminal';

  @override
  String terminalConnectingTo(String serverName) {
    return 'Conectando ao terminal do $serverName...';
  }

  @override
  String terminalConnectionFailed(String error) {
    return 'Falha na conexão do terminal: $error';
  }

  @override
  String get terminalDisconnected => 'Terminal desconectado.';

  @override
  String terminalEmbeddedUnavailable(String serverName) {
    return 'Terminal incorporado ainda não está disponível neste tempo de execução. Continue usando o modo shell do compositor para comandos únicos ou abra o terminal de um tempo de execução do aplicativo CodeWalk suportado para $serverName.';
  }

  @override
  String get terminalExtraKeyAlt => 'Tecla Alt';

  @override
  String get terminalExtraKeyArrowDown => 'Seta para baixo';

  @override
  String get terminalExtraKeyArrowLeft => 'Seta para a esquerda';

  @override
  String get terminalExtraKeyArrowRight => 'Seta para a direita';

  @override
  String get terminalExtraKeyArrowUp => 'Seta para cima';

  @override
  String get terminalExtraKeyControl => 'Tecla Control';

  @override
  String get terminalExtraKeyEscape => 'Tecla Escape';

  @override
  String get terminalExtraKeyTab => 'Tecla Tab';

  @override
  String get terminalExtraKeys => 'Teclas extras do terminal';

  @override
  String get terminalHide => 'Ocultar terminal';

  @override
  String get terminalMaximize => 'Maximizar';

  @override
  String get terminalMinimize => 'Minimizar terminal';

  @override
  String get terminalNotAvailableYet =>
      'O terminal incorporado ainda não está disponível neste tempo de execução.';

  @override
  String get terminalOpen => 'Abrir terminal';

  @override
  String get terminalOpenInfo => 'Abrir informações do terminal';

  @override
  String get terminalOpenProjectFirst =>
      'Abra uma pasta de projeto antes de iniciar o terminal do servidor.';

  @override
  String get terminalOpenToConnect =>
      'Abra o Terminal para se conectar ao terminal do projeto do servidor.';

  @override
  String get terminalReconnect => 'Reconectar terminal';

  @override
  String get terminalRestoreSize => 'Restaurar tamanho';

  @override
  String get terminalSelectServer =>
      'Selecione um servidor ativo antes de abrir o Terminal.';

  @override
  String get terminalSessionClosed => 'Sessão de terminal encerrada.';

  @override
  String get terminalTerminal => 'Terminal';

  @override
  String get terminalTitle => 'Terminal';

  @override
  String get terminalTryAgain => 'Tentar novamente';

  @override
  String get toolAwaitingInput => 'Aguardando entrada';

  @override
  String get toolEditing => 'Editando';

  @override
  String get toolEditingFiles => 'Editando arquivos';

  @override
  String get toolFinding => 'Buscando';

  @override
  String get toolFindingFiles => 'Buscando arquivos';

  @override
  String get toolPresentationAwaitingInput => 'Esperando entrada';

  @override
  String get toolPresentationEditing => 'Editando';

  @override
  String get toolPresentationEditingFiles => 'Editando arquivos';

  @override
  String get toolPresentationFinding => 'Buscando';

  @override
  String get toolPresentationFindingFiles => 'Buscando arquivos';

  @override
  String get toolPresentationReading => 'Lendo';

  @override
  String get toolPresentationReadingFile => 'Lendo arquivo';

  @override
  String get toolPresentationRunning => 'Executando';

  @override
  String get toolPresentationRunningCommand => 'Executando comando';

  @override
  String toolPresentationRunningTool(String toolName) {
    return 'Executando $toolName';
  }

  @override
  String get toolPresentationSearching => 'Buscando';

  @override
  String get toolPresentationSearchingCode => 'Buscando código';

  @override
  String get toolPresentationSearchingWeb => 'Buscando na web';

  @override
  String get toolPresentationTool => 'Ferramenta';

  @override
  String get toolPresentationUpdatingTaskList => 'Atualizando lista de tarefas';

  @override
  String get toolPresentationUpdatingTasks => 'Atualizando tarefas';

  @override
  String get toolPresentationWaitingInput => 'Esperando sua entrada';

  @override
  String get toolPresentationWriting => 'Escrevendo';

  @override
  String get toolPresentationWritingFile => 'Escrevendo arquivo';

  @override
  String get toolReading => 'Lendo';

  @override
  String get toolReadingFile => 'Lendo arquivo';

  @override
  String get toolRunning => 'Executando';

  @override
  String get toolRunningCommand => 'Executando comando';

  @override
  String get toolRunningTask => 'Executando tarefa';

  @override
  String get toolSearching => 'Pesquisando';

  @override
  String get toolSearchingCode => 'Pesquisando código';

  @override
  String get toolSearchingWeb => 'Pesquisando na web';

  @override
  String get toolUpdatingTaskList => 'Atualizando lista de tarefas';

  @override
  String get toolUpdatingTasks => 'Atualizando tarefas';

  @override
  String get toolWaitingForInput => 'Aguardando sua entrada';

  @override
  String get toolWriting => 'Escrevendo';

  @override
  String get toolWritingFile => 'Escrevendo arquivo';

  @override
  String get tourBack => 'Voltar';

  @override
  String get tourSkip => 'Pular';

  @override
  String get trayQuit => 'Sair';

  @override
  String get trayShow => 'Mostrar';

  @override
  String get useOAuthCloudflareAccess => 'Usar OAuth (Cloudflare Access)';

  @override
  String get useOAuthCloudflareAccessSubtitle =>
      'Abre o navegador para OAuth Gerenciado do Cloudflare Access.';

  @override
  String get useOAuthCloudflareAccessUnsupported =>
      'O OAuth do Cloudflare Access não está disponível nesta plataforma. Use a Autenticação Básica em seu lugar.';

  @override
  String get useTailscale => 'Usar Tailscale';

  @override
  String get useTailscaleSubtitle =>
      'Roteia o tráfego pela rede Tailscale sem uma VPN do sistema.';

  @override
  String get useTailscaleUnsupported =>
      'O Tailscale não é suportado nesta plataforma.';

  @override
  String get utilityTitle => 'Utilitário';

  @override
  String get workspaceBrowseDirs => 'Navegar diretórios';

  @override
  String get workspaceChooseFolderOpen =>
      'Escolha qualquer pasta para abrir como contexto do projeto.';

  @override
  String workspaceCloseProject(String project) {
    return 'Fechar $project';
  }

  @override
  String get workspaceClosedProjects => 'Projetos fechados';

  @override
  String workspaceCurrentDirectory(String path) {
    return 'Diretório atual: $path';
  }

  @override
  String get workspaceFilterDirs => 'Filtrar diretórios';

  @override
  String get workspaceOpenFolder => 'Abrir pasta';

  @override
  String get workspaceOpenProjectFolder => 'Abrir pasta do projeto';

  @override
  String get workspaceOpenProjects => 'Projetos abertos';

  @override
  String get workspaceProjectDirectory => 'Diretório do projeto';

  @override
  String get workspaceProjectHint => '/repo/meu-projeto';

  @override
  String workspaceRemoveFromHistory(String name) {
    return 'Remover $name do histórico';
  }

  @override
  String get settingsSessionAttentionTitle => 'Atenção de sessões';

  @override
  String get settingsSessionAttentionDescription =>
      'Mostra o estado das sessões raiz em uma bolha ou painel opcional.';

  @override
  String get settingsSessionAttentionOff => 'Desativado';

  @override
  String get settingsSessionAttentionBubble => 'Bolha';

  @override
  String get settingsSessionAttentionPanel => 'Painel';

  @override
  String get settingsSessionAttentionPrivacy =>
      'No Android, ativar isto inicia um serviço persistente em primeiro plano. O texto das respostas é armazenado com criptografia; a TTS na nuvem só envia texto depois que você toca em Ler.';

  @override
  String get settingsSessionAttentionUnavailable =>
      'A atenção de sessões não está disponível nesta plataforma.';

  @override
  String get settingsSessionAttentionOpenSettings =>
      'Abrir configurações de exibição';

  @override
  String get settingsSessionAttentionStop => 'Parar atenção de sessões';

  @override
  String get settingsSessionAttentionThirdPartyTtsWarning =>
      'Ao tocar em Ler, o texto da resposta pode ser enviado ao provedor de TTS de terceiros configurado.';

  @override
  String get workspaceSuggestions => 'Sugestões';

  @override
  String get sessionTabsGestureHintTitle =>
      'As abas de sessão têm novos controles';

  @override
  String get sessionTabsGestureHintBody =>
      'Clique duas vezes ou toque duas vezes em uma aba para fechá-la. Clique com o botão direito ou toque e segure para abrir as ações da sessão. Você pode desativar as abas em Display Toggles.';

  @override
  String get sessionTabsGestureHintAcknowledge => 'Entendi';

  @override
  String get sessionTabsGestureHintDisableTabs => 'Desativar abas';

  @override
  String get sessionTabRenameAction => 'Renomear sessão';

  @override
  String sessionTabClosedMessage(String title) {
    return 'Aba \"$title\" fechada';
  }

  @override
  String get sessionTabUndo => 'Desfazer';

  @override
  String get sessionTabRestoreFailed => 'Não foi possível restaurar a aba.';

  @override
  String get sessionTabChangeIconAction => 'Alterar ícone';

  @override
  String get sessionTabIconPickerTitle => 'Escolher ícone da aba';

  @override
  String get sessionTabIconUseProjectIcon => 'Usar ícone do projeto';

  @override
  String get sessionTabIconApplied => 'Ícone da aba atualizado.';

  @override
  String get sessionTabIconSaveFailed =>
      'Não foi possível salvar o ícone da aba.';

  @override
  String get sessionTabIconPresetCode => 'Código';

  @override
  String get sessionTabIconPresetTerminal => 'Terminal';

  @override
  String get sessionTabIconPresetBug => 'Bug';

  @override
  String get sessionTabIconPresetTasks => 'Tarefas';

  @override
  String get sessionTabIconPresetLaunch => 'Lançamento';

  @override
  String get sessionTabIconPresetIdea => 'Ideia';

  @override
  String get sessionTabIconPresetResearch => 'Pesquisa';

  @override
  String get sessionTabIconPresetDesign => 'Design';

  @override
  String get sessionTabIconPresetData => 'Dados';

  @override
  String get sessionTabIconPresetCloud => 'Nuvem';

  @override
  String get sessionTabIconPresetSecurity => 'Segurança';

  @override
  String get sessionTabIconPresetTools => 'Ferramentas';

  @override
  String get workspaceNoActiveContext => 'Sem contexto ativo';

  @override
  String get settingsAppearanceContrastLow => 'Baixo';

  @override
  String get settingsAppearanceContrastStandard => 'Padrão';

  @override
  String get settingsAppearanceContrastMedium => 'Médio';

  @override
  String get settingsAppearanceContrastMediumHigh => 'Médio alto';

  @override
  String get settingsNotificationsSystemSoundsWebUnavailable =>
      'Não disponível na web.';

  @override
  String get settingsNotificationsSystemSoundsAndroid =>
      'Sons de notificação do Android, fornecidos pelo sistema.';

  @override
  String get settingsNotificationsSystemSoundsFreedesktop =>
      'Sons Freedesktop de /usr/share/sounds/freedesktop/stereo.';

  @override
  String get settingsNotificationsSystemSoundsPlatform =>
      'Compatível onde o sistema operacional expõe sons do sistema.';

  @override
  String get serversQuickGuideTitle => 'Configuração rápida';

  @override
  String get serversQuickGuideIntro =>
      'CodeWalk é o app. O OpenCode é o motor que precisa estar em execução antes que esta conexão funcione.';

  @override
  String get serversQuickGuideStepInstallCli => '1. Instale o CLI do OpenCode.';

  @override
  String get serversQuickGuideRunPowerShell => '2. Execute no PowerShell:';

  @override
  String get serversQuickGuideRunTerminal => '2. Execute no seu terminal:';

  @override
  String get serversQuickGuideProtectPassword => 'Proteja o acesso com senha';

  @override
  String get serversQuickGuideServerPassword => 'Senha do servidor';

  @override
  String get serversQuickGuideInstallOptions =>
      'Outras opções oficiais de instalação: script de instalação, npm, bun, pnpm, Homebrew ou um binário dos GitHub Releases.';

  @override
  String get serversQuickGuideVerifyHint =>
      'Após iniciar o servidor, confirme se /global/health ou /doc responde antes de colar a URL no CodeWalk.';

  @override
  String get shortcutsPressKeyCombination =>
      'Pressione a combinação de teclas agora';

  @override
  String get settingsProvenanceOpenCodeBacked => 'Baseado no OpenCode';

  @override
  String get settingsProvenanceCodeWalkLocal => 'Local do CodeWalk';

  @override
  String get settingsProvenanceCodeWalkException => 'Exceção do CodeWalk';

  @override
  String get shortcutsErrorInvalid => 'Atalho inválido';

  @override
  String get shortcutsErrorUnsupportedKey => 'Tecla de atalho não suportada';

  @override
  String shortcutsErrorConflict(String conflict) {
    return 'Conflita com \"$conflict\"';
  }

  @override
  String get settingsSessionAttentionStopSaveFailed =>
      'A atenção de sessões foi interrompida, mas a configuração não pôde ser salva.';

  @override
  String get settingsSessionAttentionEnableFailed =>
      'Não foi possível ativar a atenção de sessões.';

  @override
  String get settingsSessionAttentionSaveFailedStopped =>
      'Não foi possível salvar a atenção de sessões e ela foi interrompida.';

  @override
  String get settingsSessionAttentionStillRunning =>
      'A atenção de sessões ainda está em execução. Tente interrompê-la novamente.';

  @override
  String get settingsSessionAttentionStopFailed =>
      'Não foi possível interromper a atenção de sessões. Tente novamente.';

  @override
  String get settingsSessionAttentionCapabilityUnavailable =>
      'O recurso de host da atenção de sessões está indisponível.';

  @override
  String get settingsServerFallbackProviderName => 'Configurado no servidor';

  @override
  String get composerStopResponse => 'Parar resposta';

  @override
  String get composerSendMessageWhileResponding =>
      'Enviar mensagem enquanto a resposta está em execução';

  @override
  String get composerSendMessage => 'Enviar mensagem';

  @override
  String get chatTourComposerDescription => 'Digite sua solicitação aqui.';

  @override
  String get chatTourSendDescription => 'Envie sua mensagem aqui.';

  @override
  String get composerAttachmentFallbackName => 'Anexo';

  @override
  String get composerContextFallbackName => 'Contexto';

  @override
  String get searchableDropdownSearchHint => 'Buscar';

  @override
  String get searchableDropdownEmptyText =>
      'Nenhuma correspondência encontrada';

  @override
  String get speechApiKeyStorageUnavailable =>
      'O armazenamento seguro da chave de API TTS está indisponível.';

  @override
  String get speechApiKeyRemoved => 'Chave de API removida.';

  @override
  String get speechApiKeySaved =>
      'Chave de API salva com segurança neste dispositivo.';

  @override
  String get speechReadAloudTestText =>
      'Este é um teste de conversão de texto em fala do CodeWalk.';

  @override
  String get speechNativeDisabledWindows =>
      'Desabilitado no Windows por estabilidade. Use o Parakeet ou outro mecanismo local por meio da captura WASAPI do CodeWalk.';

  @override
  String get speechNativeUnavailableLinux =>
      'Indisponível no Linux. Use o Parakeet para entrada de fala.';

  @override
  String get speechNotAvailableOnPlatform => 'Não disponível nesta plataforma.';

  @override
  String get speechSherpaUnavailableAndroid =>
      'Indisponível em builds do Android otimizadas para APK pequeno.';

  @override
  String get speechMoonshineDesktopOnlyHint =>
      'Disponível apenas no desktop. O Android permanece apenas com o mecanismo nativo.';

  @override
  String get speechParakeetDesktopOnlyHint =>
      'Disponível apenas no desktop. Usa reconhecimento multilíngue offline.';

  @override
  String get speechSenseVoiceDesktopOnlyHint =>
      'Disponível apenas no desktop. Mais eficaz para chinês, cantonês, japonês, coreano e inglês.';

  @override
  String get speechNativeSubtitle => 'Início mais simples e rápido.';

  @override
  String get speechSherpaSubtitle =>
      'Mais pesado, experimental e propenso a bugs. Frequentemente mais preciso com modelos baixados.';

  @override
  String get speechMoonshineSubtitle =>
      'Caminho experimental apenas para desktop, usando reconhecimento offline do sherpa_onnx e modelos para download.';

  @override
  String get speechParakeetSubtitle =>
      'Caminho offline NeMo transducer apenas para desktop, com um modelo multilíngue para download.';

  @override
  String get speechSenseVoiceSubtitle =>
      'Caminho offline apenas para desktop, ajustado para chinês, cantonês, japonês, coreano e inglês.';

  @override
  String get speechMoonshineModel => 'Modelo Moonshine';

  @override
  String get speechSherpaLanguage => 'Idioma do Sherpa';

  @override
  String get speechSearchSherpaLanguage => 'Buscar idioma do Sherpa';

  @override
  String get speechNoLanguagePacksFound =>
      'Nenhum pacote de idiomas encontrado';

  @override
  String get speechTextToSpeechProvider =>
      'Provedor de conversão de texto em fala';

  @override
  String get speechProviderSystemNative => 'Sistema / Nativo';

  @override
  String get speechProviderEdgeExperimental =>
      'Microsoft Edge Speech (experimental)';

  @override
  String get speechProviderOpenAiCompatible => 'Compatível com OpenAI';

  @override
  String get speechEdgeExperimentalTitle =>
      'O Microsoft Edge Speech é experimental';

  @override
  String get speechEdgeExperimentalDescription =>
      'Usa o serviço não oficial Edge Read Aloud diretamente deste dispositivo. O texto das mensagens é enviado à Microsoft ao usar a leitura em voz alta, e o serviço pode parar de funcionar se a Microsoft alterar o protocolo privado.';

  @override
  String get speechEdgeVoice => 'Voz do Edge';

  @override
  String get speechEdgeVoiceListUnavailable =>
      'Usando a voz padrão do Edge. A lista de vozes não pôde ser carregada no momento.';

  @override
  String get speechEdgeVoicesLoaded =>
      'Carregado das vozes do Microsoft Edge Speech.';

  @override
  String get speechCloudTtsPrivacy => 'Privacidade do TTS em nuvem';

  @override
  String get speechCloudTtsPrivacyDescription =>
      'O TTS em nuvem envia o texto da mensagem do assistente selecionada ao provedor configurado. As chaves de API são armazenadas em armazenamento seguro neste dispositivo.';

  @override
  String get speechBaseUrl => 'URL base';

  @override
  String get speechApiKey => 'Chave de API';

  @override
  String get speechApiKeySavedHelper =>
      'Uma chave está salva. Digite um novo valor para substituí-la ou salve um valor vazio para removê-la.';

  @override
  String get speechNoApiKeySaved => 'Nenhuma chave de API salva.';

  @override
  String get speechSaveApiKey => 'Salvar chave de API';

  @override
  String get speechModel => 'Modelo';

  @override
  String get speechPitchNotSupported =>
      'O tom não é suportado pelo TTS compatível com OpenAI e fica oculto para este provedor.';

  @override
  String get speechTestVoice => 'Testar voz';

  @override
  String get dialogMoonshineVoiceSetupDescription =>
      'O Moonshine roda no dispositivo por meio do sherpa_onnx. Escolha um modelo uma vez e baixe-o apenas para este dispositivo desktop.';

  @override
  String get dialogParakeetVoiceSetupDescription =>
      'O Parakeet roda no dispositivo com reconhecimento offline do sherpa_onnx. Baixe-o uma vez para este dispositivo desktop para habilitar o STT multilíngue.';

  @override
  String get dialogSenseVoiceSetupDescription =>
      'O SenseVoice roda no dispositivo com reconhecimento offline do sherpa_onnx. É mais eficaz para chinês, cantonês, japonês, coreano e inglês.';

  @override
  String get dialogSherpaVoiceSetupDescription =>
      'A entrada de voz do Sherpa requer um modelo de fala no dispositivo. Selecione seu idioma e baixe-o uma vez (~147 MB).';

  @override
  String speechSilenceSeconds(String value) {
    return '$value segundos';
  }

  @override
  String speechModelInstalled(String modelId) {
    return 'Modelo instalado ($modelId)';
  }

  @override
  String speechModelMissing(String modelId) {
    return 'Modelo ausente ($modelId)';
  }

  @override
  String speechModelSizeMb(String sizeMb) {
    return '~$sizeMb MB';
  }

  @override
  String speechSystemDefaultLanguage(String language) {
    return 'Padrão do sistema ($language)';
  }

  @override
  String speechModelListLoadFailed(String error, String service) {
    return 'Falha ao carregar a lista de modelos do $service: $error';
  }

  @override
  String speechDownloadFailed(String error) {
    return 'Falha no download: $error';
  }

  @override
  String speechFailedToRemoveModel(String error) {
    return 'Falha ao remover o modelo: $error';
  }

  @override
  String speechBaseUrlExample(String url) {
    return 'Exemplo: $url';
  }

  @override
  String speechModelDefaultHelper(String model) {
    return 'Padrão: $model';
  }

  @override
  String get notificationPermissionOrQuestionNeedsInput =>
      'Uma permissão de ferramenta ou pergunta precisa da sua intervenção.';

  @override
  String get notificationPermissionNeedsInput =>
      'Uma permissão de ferramenta precisa da sua intervenção.';

  @override
  String get notificationQuestionNeedsInput =>
      'Uma pergunta de ferramenta precisa da sua intervenção.';

  @override
  String get notificationSessionError => 'Uma sessão relatou um erro.';

  @override
  String get notificationChannelErrors => 'Erros do CodeWalk';

  @override
  String get notificationChannelErrorsDescription =>
      'Alertas de erros do CodeWalk';

  @override
  String get notificationChannelPermissions => 'Permissões do CodeWalk';

  @override
  String get notificationChannelPermissionsDescription =>
      'Alertas de ação necessária do CodeWalk';

  @override
  String get notificationChannelAgent => 'Agente do CodeWalk';

  @override
  String get notificationChannelAgentDescription =>
      'Alertas de conclusão do agente do CodeWalk';

  @override
  String get notificationActionOpen => 'Abrir';

  @override
  String get foregroundMonitorNotificationBody =>
      'Alertas confiáveis em segundo plano estão ativos';

  @override
  String get foregroundMonitorNotificationTitle =>
      'Monitoramento em segundo plano ativo';

  @override
  String get foregroundMonitorNotificationOneSession =>
      'Monitorando uma sessão';

  @override
  String foregroundMonitorNotificationSessionCount(int count) {
    return 'Monitorando $count sessões';
  }

  @override
  String sessionAttentionSemanticLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessões precisam de atenção',
      one: '1 sessão precisa de atenção',
    );
    return '$_temp0';
  }

  @override
  String get sessionAttentionOverlayPermissionRequired =>
      'A permissão de exibição sobre outros apps é necessária.';

  @override
  String get sessionAttentionIosInAppOnly =>
      'A atenção de sessões está disponível apenas dentro do CodeWalk.';

  @override
  String get sessionAttentionOverlayPermissionGrantPrompt =>
      'Conceda a permissão de exibição sobre outros apps e tente novamente.';

  @override
  String get sessionAttentionAndroidStartFailed =>
      'O serviço de atenção de sessões do Android não pôde ser iniciado.';

  @override
  String chatMessageTruncatedChars(int count, String reason) {
    return '[truncado $count caracteres] $reason';
  }

  @override
  String get chatMessageJustNow => 'Agora mesmo';

  @override
  String chatMessageMinutesAgo(int count) {
    return '$count min atrás';
  }

  @override
  String chatMessageHoursAgo(int count) {
    return '$count h atrás';
  }

  @override
  String chatMessageDaysAgo(int count) {
    return '$count d atrás';
  }

  @override
  String chatMessageDateTime(int day, int hour, int minute, int month) {
    return '$month/$day $hour:$minute';
  }

  @override
  String get chatMessageYourMessage => 'Sua mensagem';

  @override
  String get chatMessageAssistantMessage => 'Mensagem do assistente';

  @override
  String chatMessageStepStarted(int step) {
    return 'Etapa iniciada #$step';
  }

  @override
  String chatMessageStepStartedWithSnapshot(String snapshot, int step) {
    return 'Etapa iniciada #$step: $snapshot';
  }

  @override
  String chatMessageStepFinished(
    String cost,
    String reason,
    int step,
    int tokens,
  ) {
    return 'Etapa concluída #$step: $reason • tokens $tokens • \$$cost';
  }

  @override
  String chatMessagePatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count patches',
      one: '1 patch',
    );
    return '$_temp0';
  }

  @override
  String get chatMessageToolRun => 'Execução de ferramenta';

  @override
  String get chatMessageToolExecution => 'Execução de ferramenta';

  @override
  String chatMessageToolChainMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count a mais',
      one: '+1 a mais',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolChainExtraTypes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count tipos',
      one: '+1 tipo',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolAttentionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count precisam de atenção',
      one: '1 precisa de atenção',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolDoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count concluídas',
      one: '1 concluída',
    );
    return '$_temp0';
  }

  @override
  String get chatMessageToolCallsTitle => 'Chamadas de ferramentas';

  @override
  String get chatMessageDiffPreviewTruncated =>
      'Pré-visualização de diff truncada para a estabilidade do app.';

  @override
  String get chatMessageLargeMessageTruncated =>
      'Pré-visualização de mensagem grande truncada para a estabilidade do app.';

  @override
  String get chatMessageInvalidLinkFormat => 'Formato de link inválido';

  @override
  String get chatMessageUnableToOpenLink => 'Não foi possível abrir o link';

  @override
  String sessionTodoInProgressCompact(int current, int total) {
    return '$current/$total em andamento';
  }

  @override
  String sessionTodoTaskProgress(String content, int index, int total) {
    return 'Tarefa $index/$total $content';
  }

  @override
  String sessionTodoDoneCompact(int count, int total) {
    return '$count/$total concluídas';
  }

  @override
  String sessionTodoCompletedCount(int count, int total) {
    return 'Tarefas $count/$total concluídas';
  }

  @override
  String sessionTodoTasksCount(int count) {
    return 'Tarefas ($count)';
  }

  @override
  String questionStepOfReview(int current, int total) {
    return 'Etapa $current de $total - Revisão';
  }

  @override
  String questionStepOfQuestion(int current, int total) {
    return 'Etapa $current de $total - Pergunta';
  }

  @override
  String get questionCustomAnswer => 'Resposta personalizada';

  @override
  String get questionSubmitAnswers => 'Enviar respostas';

  @override
  String get questionReviewAnswers => 'Revisar respostas';

  @override
  String permissionRequestTitle(String permission) {
    return 'Solicitação de permissão: $permission';
  }

  @override
  String get sessionTitleCannotBeEmpty => 'O título não pode ficar vazio';

  @override
  String get filesFailedToLoad => 'Falha ao carregar arquivos';

  @override
  String get filesFailedToSearch => 'Falha ao buscar arquivos';

  @override
  String get filesNoOpenFilesHint =>
      'Nenhum arquivo aberto ainda. Digite para buscar.';

  @override
  String get filesNoContentMatches =>
      'Nenhuma correspondência de conteúdo encontrada';

  @override
  String filesOpenFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arquivos abertos',
      one: '1 arquivo aberto',
    );
    return '$_temp0';
  }

  @override
  String filesLinesSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count linhas selecionadas',
      one: '1 linha selecionada',
    );
    return '$_temp0';
  }

  @override
  String get filesDraftTooLargeToSave =>
      'O rascunho é grande demais para ser salvo pelo editor.';

  @override
  String get filesSaveChangesBeforeClose =>
      'Salve as alterações antes de fechar este arquivo.';

  @override
  String get filesSaveChangesBeforePathChange =>
      'Salve as alterações antes de alterar este caminho.';

  @override
  String get filesWaitForSaveBeforePathChange =>
      'Aguarde o salvamento do arquivo terminar antes de alterar este caminho.';

  @override
  String get filesWaitForFileOperation =>
      'Aguarde a operação de arquivo terminar.';

  @override
  String get filesLargeFileReadOnly =>
      'Arquivos grandes abrem somente leitura para manter a edição responsiva.';

  @override
  String get filesCheckingWriteSupport =>
      'Verificando suporte de gravação do arquivo...';

  @override
  String get filesActiveProjectRequired =>
      'As operações de arquivo exigem um diretório de projeto ativo.';

  @override
  String get filesReloadSkippedUnsavedChanges =>
      'Alterações não salvas; recarga ignorada.';

  @override
  String get filesFailedToLoadContent =>
      'Falha ao carregar o conteúdo do arquivo';

  @override
  String get filesFileSaved => 'Arquivo salvo.';

  @override
  String get filesParentNotDirectory => 'O pai não é um diretório.';

  @override
  String get filesMalformedResponse =>
      'A operação de arquivo retornou uma resposta inválida.';

  @override
  String get filesShellCommandDidNotComplete =>
      'O comando shell da operação de arquivo não foi concluído.';

  @override
  String get filesShellCommandNoResult =>
      'O comando shell da operação de arquivo não retornou resultado.';

  @override
  String get filesShellCommandTruncated =>
      'O comando shell da operação de arquivo foi truncado pelo servidor.';

  @override
  String get filesShellCommandSyntaxError =>
      'O comando shell da operação de arquivo falhou com erro de sintaxe.';

  @override
  String get filesShellUtilityNotFound =>
      'Um utilitário shell necessário não foi encontrado.';

  @override
  String get filesShellCommandFailed =>
      'O comando shell da operação de arquivo falhou antes de retornar um resultado.';

  @override
  String get attachmentSaveTitle => 'Salvar anexo';

  @override
  String get attachmentBrowserSandboxLocalFile =>
      'O sandbox do navegador impede a abertura direta de anexos locais file://.';

  @override
  String get attachmentLocalPathBrowserBlocked =>
      'Este anexo aponta para um caminho local que não pode ser aberto no navegador.';

  @override
  String terminalConnectedTo(String directory, String serverName) {
    return 'Conectado a $serverName em $directory';
  }

  @override
  String get terminalTransportUnavailable =>
      'O transporte do terminal está indisponível.';

  @override
  String get chatSlashCommandNew => 'Criar uma nova sessão de chat';

  @override
  String get chatSlashCommandModels => 'Abrir seletor de modelos';

  @override
  String get chatSlashCommandSessions => 'Abrir lista de conversas';

  @override
  String get chatSlashCommandAgent => 'Abrir seletor de agentes';

  @override
  String get chatSlashCommandOpen => 'Ação rápida de abertura de arquivo';

  @override
  String get chatSlashCommandHelp => 'Mostrar ajuda de comandos';

  @override
  String get chatSlashCommandCompact => 'Compactar o contexto da sessão atual';

  @override
  String get chatSlashCommandThinking => 'Alternar balões de pensamento';

  @override
  String get chatSlashCommandUndo =>
      'Desfazer o último turno visível do usuário';

  @override
  String get chatSlashCommandRedo => 'Refazer o último turno desfeito';

  @override
  String chatSessionSubConversationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subconversas',
      one: '1 subconversa',
    );
    return '$_temp0';
  }

  @override
  String chatMessageWeeksAgo(int count) {
    return '$count sem atrás';
  }

  @override
  String chatMessageShortDate(int day, int month) {
    return '$month/$day';
  }

  @override
  String get chatProviderErrorLoadSessionStatus =>
      'Falha ao carregar o status da sessão';

  @override
  String get chatProviderErrorLoadSessionDetails =>
      'Alguns detalhes da sessão não puderam ser carregados';

  @override
  String chatProviderErrorLoadSessionList(String error) {
    return 'Falha ao carregar a lista de sessões: $error';
  }

  @override
  String get chatProviderErrorCreateSession => 'Falha ao criar a sessão';

  @override
  String get chatProviderErrorSelectProviderModelBeforeSend =>
      'Selecione um provedor conectado ou um modelo OpenCode gratuito antes de enviar';

  @override
  String get chatProviderErrorStartMessageSend =>
      'Falha ao iniciar o envio da mensagem';

  @override
  String get chatProviderErrorStopUnavailable =>
      'A parada está indisponível para a sessão atual';

  @override
  String get chatProviderErrorWaitForResponseFinish =>
      'Aguarde a resposta atual terminar antes de compactar';

  @override
  String get chatProviderErrorCompactUnavailable =>
      'A compactação de contexto está indisponível para a sessão atual';

  @override
  String get chatProviderErrorSelectModelBeforeCompact =>
      'Selecione um modelo antes de compactar o contexto';

  @override
  String get chatProviderErrorCompactSessionContext =>
      'Falha ao compactar o contexto da sessão';

  @override
  String get chatProviderErrorNetwork =>
      'Falha na conexão de rede. Verifique as configurações de rede';

  @override
  String get chatProviderErrorServer =>
      'Erro no servidor. Tente novamente mais tarde';

  @override
  String get chatProviderErrorNotFound => 'Recurso não encontrado';

  @override
  String get chatProviderErrorInvalidInput => 'Parâmetros de entrada inválidos';

  @override
  String get chatProviderErrorUnknown =>
      'Erro desconhecido. Tente novamente mais tarde';

  @override
  String get chatProviderErrorSessionFallback => 'Erro de sessão';

  @override
  String get projectProviderErrorNoProjectContext =>
      'Nenhum contexto de projeto disponível no servidor';

  @override
  String projectProviderErrorInitializeFailed(String error) {
    return 'Falha ao inicializar o contexto do projeto: $error';
  }

  @override
  String get projectProviderErrorSwitchProjectNotFound =>
      'Falha ao alternar de projeto: projeto não encontrado';

  @override
  String get projectProviderErrorSwitchDirectoryEmpty =>
      'Falha ao alternar de projeto: o diretório está vazio';

  @override
  String get projectProviderErrorAtLeastOneContext =>
      'Pelo menos um contexto deve permanecer aberto';

  @override
  String get projectProviderErrorReopenProjectNotFound =>
      'Falha ao reabrir o projeto: projeto não encontrado';

  @override
  String get projectProviderErrorOnlyClosedArchivable =>
      'Somente projetos fechados podem ser arquivados';

  @override
  String get projectProviderErrorArchiveProjectNotFound =>
      'Falha ao arquivar o projeto: projeto não encontrado';

  @override
  String get projectProviderErrorArchiveProjectPathInvalid =>
      'Falha ao arquivar o projeto: o caminho do projeto é inválido';

  @override
  String projectProviderErrorLoadWorkspaces(String error) {
    return 'Falha ao carregar workspaces: $error';
  }

  @override
  String get projectProviderErrorWorkspaceNameEmpty =>
      'O nome do workspace não pode ficar vazio';

  @override
  String projectProviderErrorCreateWorkspace(String error) {
    return 'Falha ao criar o workspace: $error';
  }

  @override
  String projectProviderErrorResetWorkspace(String error) {
    return 'Falha ao redefinir o workspace: $error';
  }

  @override
  String projectProviderErrorDeleteWorkspace(String error) {
    return 'Falha ao excluir o workspace: $error';
  }

  @override
  String get projectProviderErrorDirectoryEmpty =>
      'O diretório não pode ficar vazio';

  @override
  String projectProviderErrorListDirectories(String error) {
    return 'Falha ao listar diretórios: $error';
  }

  @override
  String projectProviderErrorValidateDirectory(String error) {
    return 'Falha ao validar o diretório: $error';
  }

  @override
  String get projectProviderErrorPathEmpty => 'O caminho não pode ficar vazio';

  @override
  String projectProviderErrorListFiles(String error) {
    return 'Falha ao listar arquivos: $error';
  }

  @override
  String projectProviderErrorSearchFiles(String error) {
    return 'Falha ao buscar arquivos: $error';
  }

  @override
  String projectProviderErrorContentSearchUnavailable(String error) {
    return 'Busca de conteúdo indisponível: $error';
  }

  @override
  String projectProviderErrorSearchSymbols(String error) {
    return 'Falha ao buscar símbolos: $error';
  }

  @override
  String projectProviderErrorReadFile(String error) {
    return 'Falha ao ler o arquivo: $error';
  }

  @override
  String projectProviderErrorLoadProjectList(String error) {
    return 'Falha ao carregar a lista de projetos: $error';
  }

  @override
  String get workspaceProjectRemovedFromHistory =>
      'Projeto removido do histórico';

  @override
  String workspaceProjectContextOpened(String directory) {
    return 'Contexto do projeto aberto: $directory';
  }

  @override
  String workspaceFailedToOpenProjectContext(String directory) {
    return 'Falha ao abrir o contexto do projeto: $directory';
  }

  @override
  String get chatAbortNotice => 'O que você quer fazer de diferente?';

  @override
  String sessionTitleToday(String date, String time) {
    return 'Hoje $time ($date)';
  }

  @override
  String sessionTitleYesterday(String date, String time) {
    return 'Ontem $time ($date)';
  }

  @override
  String sessionTitleWeekday(String date, String time, String weekday) {
    return '$weekday $time ($date)';
  }

  @override
  String sessionTitleDateAndTime(String date, String time) {
    return '$date $time';
  }

  @override
  String get sessionWeekdayMon => 'Seg';

  @override
  String get sessionWeekdayTue => 'Ter';

  @override
  String get sessionWeekdayWed => 'Qua';

  @override
  String get sessionWeekdayThu => 'Qui';

  @override
  String get sessionWeekdayFri => 'Sex';

  @override
  String get sessionWeekdaySat => 'Sáb';

  @override
  String get sessionWeekdaySun => 'Dom';

  @override
  String get forwardTimeNow => 'agora';

  @override
  String forwardTimeMinutes(int count) {
    return '$count min';
  }

  @override
  String forwardTimeHours(int count) {
    return '$count h';
  }

  @override
  String forwardTimeDays(int count) {
    return '$count d';
  }

  @override
  String forwardTimeWeeks(int count) {
    return '$count sem';
  }

  @override
  String get settingsBehaviorConfigFieldDefaultModel => 'modelo padrão';

  @override
  String get settingsBehaviorConfigFieldDefaultAgent => 'agente padrão';

  @override
  String get settingsBehaviorConfigFieldSmallModel => 'modelo pequeno';

  @override
  String get settingsBehaviorConfigFieldAutoUpdateMode =>
      'modo de atualização automática';

  @override
  String get settingsBehaviorConfigFieldSnapshotSetting =>
      'configuração de snapshot';

  @override
  String get settingsBehaviorConfigFieldConversationUsername =>
      'nome de usuário da conversa';

  @override
  String get settingsBehaviorConfigFieldSharingDefault =>
      'padrão de compartilhamento';

  @override
  String get speechMicNoInputDevice =>
      'Nenhum dispositivo de entrada de microfone está disponível.';

  @override
  String get speechMicDeviceBusy =>
      'O microfone padrão está em uso por outro aplicativo no momento.';

  @override
  String get speechMicUnsupportedFormat =>
      'O formato do microfone padrão não é suportado.';

  @override
  String get speechMicSpeechPrivacy =>
      'Os serviços de fala do Windows podem estar desativados (privacidade de fala, reconhecimento de fala online ou pacotes de idiomas).';

  @override
  String get speechMicBackendUnavailable =>
      'O backend de microfone do Windows não está disponível nesta compilação.';

  @override
  String speechEngineFallbackNotice(String fallback, String reason) {
    return 'Mecanismo de STT selecionado indisponível ($reason). Usando $fallback em seu lugar.';
  }

  @override
  String get oauthFlowSecureStorageUnavailable =>
      'O armazenamento seguro de credenciais está indisponível para OAuth.';

  @override
  String get oauthFlowUnexpectedError =>
      'O fluxo de OAuth falhou inesperadamente. Tente novamente.';

  @override
  String get oauthFlowNoEndpointsDiscovered =>
      'Nenhum endpoint de OAuth encontrado. Ative o OAuth Gerenciado em Cloudflare Dashboard → Access → Applications → [este app].';

  @override
  String get oauthFlowTokenResponseMissingAccessToken =>
      'A resposta do token OAuth não incluiu um access token.';

  @override
  String get oauthFlowProfileChanged =>
      'O perfil do servidor mudou antes de o OAuth ser concluído.';

  @override
  String get oauthFlowMetadataMissingEndpoints =>
      'Os metadados do OAuth não incluem os endpoints de autorização/token.';

  @override
  String get oauthFlowCallbackNotCompleted =>
      'O callback de autorização não foi concluído';

  @override
  String get oauthFlowProviderDeclined =>
      'O servidor de autorização recusou a solicitação de OAuth. Tente novamente.';

  @override
  String get oauthFlowCallbackValidationFailed =>
      'A validação do callback de OAuth falhou. Tente novamente.';

  @override
  String get oauthFlowCallbackServerStartFailed =>
      'O servidor de callback de OAuth local falhou ao iniciar.';

  @override
  String get oauthFlowSignInCanceled => 'O login do OAuth foi cancelado.';

  @override
  String get oauthFlowBrowserOpenFailed =>
      'Não foi possível abrir o navegador do sistema para o login do OAuth.';

  @override
  String get oauthFlowCallbackTimeout =>
      'Nenhum callback de autorização chegou ao app em 5 minutos. Esperava-se que o navegador redirecionasse para o endereço de callback local após o consentimento. Se o navegador mostrou um erro de conexão, este dispositivo ou rede bloqueia redirecionamentos de loopback.';

  @override
  String oauthFlowTokenExchangeTransientFailure(int maxAttempts) {
    return 'A troca de token falhou após $maxAttempts tentativas devido a um problema temporário de rede. Tente novamente.';
  }

  @override
  String oauthFlowTokenExchangeHttpFailure(int statusCode) {
    return 'A troca de token falhou (HTTP $statusCode). Tente novamente.';
  }

  @override
  String get oauthFlowTokenExchangeUnexpectedFailure =>
      'A troca de token falhou inesperadamente. Tente novamente.';

  @override
  String get oauthFlowTokenExchangeIncomplete =>
      'A troca de token não foi concluída após o envio do código de autorização. Inicie o login do OAuth novamente.';

  @override
  String get speechReadAloudFailed => 'A conversão de texto em fala falhou.';

  @override
  String get speechReadAloudNoText => 'Não há texto para ler em voz alta.';

  @override
  String get speechEdgeTextTooLong =>
      'O Microsoft Edge Speech pode ler até 4096 bytes por vez.';

  @override
  String get speechEdgeMalformedAudio =>
      'O Microsoft Edge Speech retornou dados de áudio malformados.';

  @override
  String get speechEdgeUnsupportedAudio =>
      'O Microsoft Edge Speech retornou dados de áudio não suportados.';

  @override
  String get speechEdgeUnsupportedFrame =>
      'O Microsoft Edge Speech retornou um quadro websocket não suportado.';

  @override
  String get speechEdgeSynthesisInterrupted =>
      'O Microsoft Edge Speech terminou antes de a síntese ser concluída.';

  @override
  String get speechEdgeEmptyAudio =>
      'O Microsoft Edge Speech retornou uma resposta de áudio vazia.';

  @override
  String get speechEdgeTimedOut => 'O Microsoft Edge Speech expirou.';

  @override
  String get speechEdgeUnreachable =>
      'Não foi possível alcançar o Microsoft Edge Speech.';

  @override
  String get speechApiKeyMissing =>
      'Adicione uma chave de API em Configurações > Fala para usar este provedor de TTS.';

  @override
  String get speechProviderEmptyAudio =>
      'O provedor de TTS retornou uma resposta de áudio vazia.';

  @override
  String get speechProviderRequestRejected =>
      'O provedor de TTS rejeitou a solicitação de fala.';

  @override
  String get speechApiKeyRejected =>
      'A chave de API de TTS foi rejeitada pelo provedor.';

  @override
  String get speechProviderQuotaRateLimit =>
      'O provedor de TTS relatou um limite de cota ou taxa.';

  @override
  String get speechProviderTemporarilyUnavailable =>
      'O provedor de TTS está temporariamente indisponível.';

  @override
  String get speechProviderUnreachable =>
      'Não foi possível alcançar o provedor de TTS.';

  @override
  String appProviderErrorFailedToStartProcess(String tool) {
    return 'Falha ao iniciar o processo de $tool.';
  }

  @override
  String appProviderErrorToolNotAvailable(String runtime, String tool) {
    return '$tool não está disponível. Instale o $runtime primeiro.';
  }

  @override
  String appProviderErrorToolInstallFailed(int exitCode, String tool) {
    return 'A instalação de $tool falhou com o código de saída $exitCode.';
  }

  @override
  String appProviderErrorBunBootstrapFailed(int exitCode) {
    return 'A inicialização do Bun falhou com o código de saída $exitCode.';
  }

  @override
  String get appProviderErrorInstalledButNotFoundInPath =>
      'A instalação do OpenCode foi concluída, mas o comando não foi encontrado no PATH.';

  @override
  String get appProviderErrorInstalledButPathNotResolved =>
      'A instalação do OpenCode foi concluída, mas não foi possível resolver o caminho do comando.';

  @override
  String appProviderErrorConfiguredCommandNotFound(String tool) {
    return 'O comando configurado não foi encontrado e $tool não está no PATH.';
  }

  @override
  String get appProviderErrorConfiguredCommandPathMissing =>
      'O caminho do comando configurado não existe.';

  @override
  String get appProviderErrorConfiguredCommandVersionCheckFailed =>
      'O comando configurado existe, mas a verificação de versão falhou.';

  @override
  String get appProviderErrorConfiguredCommandExecutionFailed =>
      'Não foi possível executar o comando configurado.';

  @override
  String get appProviderWslCheckWindowsOnly =>
      'A verificação de WSL se aplica apenas ao Windows.';

  @override
  String get appProviderDesktopBuildRequired =>
      'Use uma versão desktop para configurar um servidor local gerenciado.';

  @override
  String get appProviderKnownInstallationDirectoryDetected =>
      'Detectado a partir de um diretório de instalação conhecido.';

  @override
  String appProviderKnownInstallationPathRefreshHint(String appName) {
    return 'Detectado a partir de um diretório de instalação conhecido. O PATH pode precisar ser atualizado; reabra o $appName se uma instalação recente ainda não foi detectada.';
  }

  @override
  String get appProviderErrorReleaseMetadataFetchFailed =>
      'Falha ao buscar os metadados da versão mais recente no GitHub.';

  @override
  String get appProviderErrorReleaseAssetListMissing =>
      'Os metadados da versão mais recente não incluíam a lista de recursos.';

  @override
  String get appProviderErrorNoCompatibleAsset =>
      'Nenhum recurso binário compatível do OpenCode foi encontrado.';

  @override
  String get appProviderErrorDownloadAssetFailed =>
      'Falha ao baixar o recurso do OpenCode selecionado.';

  @override
  String get appProviderErrorChecksumVerificationFailed =>
      'A verificação de checksum do recurso baixado falhou.';

  @override
  String get appProviderErrorExtractArchiveFailed =>
      'Falha ao extrair o arquivo binário do OpenCode.';

  @override
  String appProviderErrorExecutableNotFound(String tool) {
    return 'Não foi possível encontrar o executável de $tool nos arquivos extraídos.';
  }

  @override
  String get chatNoResponseFromServer =>
      'Sem resposta do servidor. Tente novamente.';

  @override
  String get chatNoResponseFromModel =>
      'Sem resposta do modelo. Tente novamente.';

  @override
  String get speechJobCancelled => 'O trabalho de fala foi cancelado.';

  @override
  String get speechEdgeCancelled => 'O Microsoft Edge Speech foi cancelado.';

  @override
  String get sessionAttentionKindActive => 'Ativo';

  @override
  String get sessionAttentionKindReceiving => 'Recebendo';

  @override
  String get sessionAttentionKindDelayed => 'Atrasado';

  @override
  String get sessionAttentionKindCompleted => 'Concluído';

  @override
  String get sessionAttentionKindPendingInteraction => 'Interação pendente';

  @override
  String get sessionAttentionKindError => 'Erro';

  @override
  String get sessionAttentionPauseCellularDataSaver =>
      'O economizador de dados móveis está ativo';

  @override
  String get sessionAttentionPauseOauthReopenRequired =>
      'É necessário entrar com OAuth';

  @override
  String get sessionAttentionPauseTailscaleReopenRequired =>
      'É necessária a conexão com o Tailscale';

  @override
  String get sessionAttentionPauseOffline => 'Offline';

  @override
  String get sessionAttentionPausePermissionRevoked => 'Permissão revogada';

  @override
  String get sessionAttentionPauseServiceStopped => 'Serviço interrompido';

  @override
  String get sessionAttentionPauseHostUnavailable => 'Host indisponível';

  @override
  String get errorRequestCancelled => 'Solicitação cancelada';

  @override
  String errorUnknownNetworkError(String error) {
    return 'Erro de rede desconhecido: $error';
  }

  @override
  String get errorCertificateError => 'Erro de certificado';

  @override
  String get errorSessionBusy =>
      'A sessão está ocupada processando outra solicitação.';

  @override
  String get errorRunShellCommandFailed =>
      'Falha ao executar o comando de shell';

  @override
  String get errorRunSlashCommandFailed =>
      'Falha ao executar o comando de barra';

  @override
  String get settingsBehaviorOpenCodeDefaultsLoadError =>
      'Não foi possível carregar os padrões baseados no OpenCode do servidor ativo.';

  @override
  String get sessionTabIconRemoveFailed =>
      'Falha ao remover os dados do ícone da aba de sessão local';

  @override
  String get forwardUntitled => 'Sem título';

  @override
  String setupDebugLinuxLogsPath(String path) {
    return 'Registros do Linux: $path';
  }

  @override
  String setupDebugRunOpenCodeCommand(String command) {
    return 'Execute o OpenCode com: $command';
  }

  @override
  String setupDebugServerHealthEndpoint(String endpoint) {
    return 'Saúde do servidor: $endpoint';
  }

  @override
  String setupDebugServerDocsEndpoint(String endpoint) {
    return 'Documentação do servidor: $endpoint';
  }

  @override
  String get logsEntryError => 'Erro';

  @override
  String get logsEntryStack => 'Pilha';

  @override
  String get setupDebugSourceDiagnostics => 'Diagnóstico';

  @override
  String get setupDebugSourceUseExisting => 'Usar existente';

  @override
  String get setupDebugSourceLocalServer => 'Servidor local';

  @override
  String get setupDebugSourceOnboarding => 'Onboarding';

  @override
  String get setupDebugSourceManualConnection => 'Conexão manual';

  @override
  String setupDebugMessageDiagnosticsResult(
    String availability,
    String platform,
    String recommendation,
  ) {
    return '$availability em $platform. $recommendation';
  }

  @override
  String get setupDebugMessageDetectAttempt =>
      'Tentando detectar um comando OpenCode existente no ambiente atual.';

  @override
  String get setupDebugMessageInstallStarted =>
      'Instalação do OpenCode iniciada pelo CodeWalk.';

  @override
  String setupDebugMessageStartLocalServer(String url) {
    return 'Iniciando o servidor OpenCode gerenciado em $url.';
  }

  @override
  String setupDebugMessageHealthyRunning(String url) {
    return 'O servidor OpenCode gerenciado está saudável e em execução em $url.';
  }

  @override
  String get setupDebugMessageStoppingLocalServer =>
      'Interrompendo o servidor OpenCode gerenciado.';

  @override
  String get setupDebugMessageStoppedCleanly =>
      'O servidor OpenCode gerenciado foi interrompido corretamente.';

  @override
  String get setupDebugMessageExitedAfterRequestedStop =>
      'O servidor OpenCode gerenciado foi encerrado após uma parada solicitada.';

  @override
  String get setupDebugMessageOnboardingConnectExisting =>
      'O usuário escolheu se conectar a um servidor OpenCode existente.';

  @override
  String get setupDebugMessageOnboardingGuidedPath =>
      'O usuário abriu o caminho guiado de configuração do OpenCode.';

  @override
  String get setupDebugMessageOnboardingManagedLocal =>
      'O usuário abriu a configuração local gerenciada do OpenCode.';

  @override
  String get setupDebugMessageOnboardingOpenedServerSettings =>
      'O usuário abriu as configurações do servidor após uma verificação de saúde com falha.';

  @override
  String get setupDebugMessageOnboardingAddAnotherServer =>
      'O usuário escolheu adicionar outro servidor após uma verificação de saúde com falha.';

  @override
  String setupDebugMessageTestingServerUrl(String url) {
    return 'Testando a URL do servidor OpenCode $url durante a configuração inicial.';
  }

  @override
  String get chatProviderErrorSessionNotFound => 'Sessão não encontrada';

  @override
  String get chatProviderErrorInvalidMessageFormat =>
      'Formato de mensagem inválido';

  @override
  String get chatProviderErrorNetworkShort => 'Falha na conexão de rede';

  @override
  String get chatProviderErrorUnknownShort => 'Erro desconhecido';

  @override
  String get terminalCreateFailed => 'Falha ao criar a sessão do terminal';

  @override
  String get terminalEndpointUnavailable =>
      'O endpoint do terminal não está disponível';

  @override
  String get terminalInvalidDirectory => 'Diretório do terminal inválido';

  @override
  String get terminalWebsocketUnavailable =>
      'O websocket do terminal não está disponível aqui.';

  @override
  String chatMessageToolChainCallsCompact(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chamadas',
      one: '1 chamada',
    );
    return '$_temp0';
  }

  @override
  String get errorConnectionTimeout => 'Tempo de conexão esgotado';

  @override
  String get errorClientError => 'Erro do cliente';

  @override
  String get chatProviderErrorSendMessage => 'Falha ao enviar mensagem';

  @override
  String get speechApiEngine => 'API';

  @override
  String get speechApiEngineSubtitle =>
      'OpenAI, Groq ou um endpoint personalizado compatível com OpenAI.';

  @override
  String get speechApiProvider => 'Provedor de fala para texto';

  @override
  String get speechCloudSttPrivacy =>
      'Privacidade do reconhecimento de fala em nuvem';

  @override
  String get speechCloudSttPrivacyDescription =>
      'O áudio do microfone gravado é enviado ao provedor configurado. As chaves de API permanecem no armazenamento seguro deste dispositivo.';

  @override
  String get speechApiKeyOptional => 'Opcional para endpoints personalizados.';

  @override
  String speechApiBatchHint(String provider) {
    return '$provider usa transcrição em lote. Toque no microfone novamente para parar e transcrever.';
  }

  @override
  String get speechApiWebUnavailable =>
      'O reconhecimento de fala por API não está disponível na versão web.';

  @override
  String get speechApiConfigInvalid =>
      'Verifique o endpoint e o modelo da API de fala. Endpoints remotos devem usar HTTPS.';

  @override
  String get speechApiRequestInvalid =>
      'O endpoint ou o modelo de fala foi rejeitado.';

  @override
  String get speechApiRateLimited =>
      'O provedor de fala informou uma cota ou limite de taxa.';

  @override
  String get speechApiUnavailable =>
      'O provedor de fala está temporariamente indisponível.';

  @override
  String get speechApiNetwork =>
      'Não foi possível alcançar o provedor de fala.';

  @override
  String get speechApiInvalidResponse =>
      'O provedor de fala retornou uma resposta inválida.';

  @override
  String get speechApiEmptyAudio => 'Nenhum áudio do microfone foi capturado.';

  @override
  String get speechApiEmptyTranscript =>
      'O provedor de fala não retornou nenhuma transcrição.';

  @override
  String get speechApiCustomProvider => 'Personalizado compatível com OpenAI';

  @override
  String get speechApiMaxDuration =>
      'As gravações da API param automaticamente após 2 minutos.';

  @override
  String get speechApiLanguageHint =>
      'O idioma ativo do aplicativo é enviado como dica de transcrição.';

  @override
  String get speechSttApiKeyStorageUnavailable =>
      'O armazenamento seguro da chave de API de fala está indisponível.';

  @override
  String get speechSttApiKeyMissing =>
      'Adicione uma chave de API de fala em Configurações > Fala.';

  @override
  String get speechSttApiKeyRejected => 'A chave de API de fala foi rejeitada.';

  @override
  String get carMessagingReply => 'Responder';

  @override
  String get carMessagingMarkRead => 'Marcar como lida';

  @override
  String get carMessagingDeliveryFailedTitle =>
      'Não foi possível enviar a resposta';

  @override
  String get carMessagingDeliveryFailedBody =>
      'Sua resposta por voz não pôde ser entregue. Abra o CodeWalk para tentar novamente.';
}
