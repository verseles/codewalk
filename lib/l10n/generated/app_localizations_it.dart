// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get aboutGitHub => 'GitHub';

  @override
  String get appProviderCannotActivateUnhealthy =>
      'Impossibile attivare un server non integro';

  @override
  String get appProviderDesktopOnly =>
      'Il server locale gestito è disponibile solo su desktop.';

  @override
  String get appProviderDetectingCommand => 'Rilevamento comando OpenCode...';

  @override
  String get appProviderErrorCannotActivateUnhealthy =>
      'Impossibile attivare un server non integro';

  @override
  String get appProviderErrorCloudflareOAuthNotSupported =>
      'Cloudflare Access OAuth non è supportato su questa piattaforma';

  @override
  String get appProviderErrorInstallationFailed =>
      'Installazione di OpenCode fallita.';

  @override
  String get appProviderErrorInvalidServerUrl => 'URL del server non valido';

  @override
  String get appProviderErrorLocalServerHealthCheckFailed =>
      'Il server locale è stato avviato ma il controllo di integrità non è passato.';

  @override
  String get appProviderErrorManagedDesktopOnly =>
      'Il server locale gestito è disponibile solo su desktop.';

  @override
  String get appProviderErrorServerAlreadyExists =>
      'Un server con questo URL esiste già';

  @override
  String get appProviderErrorServerProfileNotFound =>
      'Profilo server non trovato';

  @override
  String get appProviderErrorServerUrlRequired =>
      'L\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'URL del server è richiesto';

  @override
  String get appProviderErrorTailscaleNotSupported =>
      'Tailscale non è supportato su questa piattaforma';

  @override
  String appProviderExitedWithCode(int code) {
    return 'Il server locale è uscito con il codice $code.';
  }

  @override
  String get appProviderFailedToStart =>
      'Avvio del server OpenCode locale fallito.';

  @override
  String get appProviderInstallBinary => 'Installa binario';

  @override
  String get appProviderInstallBunOpenCode => 'Installa Bun + OpenCode';

  @override
  String get appProviderInstallSucceeded => 'Installazione riuscita.';

  @override
  String appProviderInstallSucceededWithPath(String path) {
    return 'Installazione riuscita. Comando OpenCode disponibile in $path.';
  }

  @override
  String get appProviderInstallViaBun => 'Installa tramite Bun';

  @override
  String get appProviderInstallViaNpm => 'Installa tramite npm';

  @override
  String get appProviderInstallationFailed =>
      'Installazione di OpenCode fallita.';

  @override
  String get appProviderInstalledSuccessfully =>
      'Requisiti OpenCode installati con successo.';

  @override
  String get appProviderInstallingRequirements =>
      'Installazione dei requisiti OpenCode...';

  @override
  String get appProviderInvalidServerUrl => 'URL del server non valido';

  @override
  String get appProviderLabelLocalOpenCodeManaged =>
      'OpenCode locale (gestito)';

  @override
  String get appProviderLabelPrimaryServer => 'Server primario';

  @override
  String get appProviderLocalManaged => 'OpenCode locale (gestito)';

  @override
  String get appProviderLocalServerStopped => 'Il server locale è fermo.';

  @override
  String get appProviderNotDetectedInstall =>
      'Comando OpenCode non rilevato. Esegui l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'installazione dal wizard.';

  @override
  String appProviderNotDetectedRefresh(String appName) {
    return 'Comando OpenCode non rilevato. Se lo hai installato poco fa, aggiorna i controlli o riapri $appName per ricaricare il PATH.';
  }

  @override
  String get appProviderOAuthNotSupported =>
      'Cloudflare Access OAuth non è supportato su questa piattaforma';

  @override
  String get appProviderOpenCodeDetected => 'OpenCode rilevato';

  @override
  String get appProviderOpenCodeNotDetected => 'OpenCode non rilevato';

  @override
  String get appProviderPrimaryServer => 'Server primario';

  @override
  String get appProviderProfileNotFound => 'Profilo server non trovato';

  @override
  String get appProviderRunDiagnostics =>
      'Esegui la diagnostica per verificare i requisiti locali di OpenCode.';

  @override
  String appProviderRunningAt(String url) {
    return 'In esecuzione su $url';
  }

  @override
  String get appProviderSetupDetectingOpenCode =>
      'Rilevamento comando OpenCode...';

  @override
  String get appProviderSetupInstallationSucceeded => 'Installazione riuscita.';

  @override
  String appProviderSetupInstallationSucceededWithPath(String path) {
    return 'Installazione riuscita. Comando OpenCode disponibile in $path.';
  }

  @override
  String get appProviderSetupInstallingRequirements =>
      'Installazione dei requisiti OpenCode...';

  @override
  String get appProviderSetupOpenCodeDetected => 'OpenCode rilevato';

  @override
  String get appProviderSetupOpenCodeNotDetected => 'OpenCode non rilevato';

  @override
  String get appProviderSetupOpenCodeNotDetectedInstall =>
      'Comando OpenCode non rilevato. Esegui l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'installazione dal wizard.';

  @override
  String get appProviderSetupOpenCodeNotDetectedRefresh =>
      'Comando OpenCode non rilevato. Se lo hai installato poco fa, aggiorna i controlli o riapri CodeWalk per ricaricare il PATH.';

  @override
  String get appProviderSetupRequirementsInstalled =>
      'Requisiti OpenCode installati con successo.';

  @override
  String appProviderSetupUsingOpenCodeAt(String path) {
    return 'Utilizzo del comando OpenCode in $path';
  }

  @override
  String get appProviderStartingLocalServer => 'Avvio del server locale...';

  @override
  String appProviderStatusLocalServerExitedWithCode(int code) {
    return 'Il server locale è uscito con il codice $code.';
  }

  @override
  String get appProviderStatusLocalServerStopped => 'Il server locale è fermo.';

  @override
  String appProviderStatusRunningAt(String url) {
    return 'In esecuzione su $url';
  }

  @override
  String get appProviderStatusStartingLocalServer =>
      'Avvio del server locale...';

  @override
  String get appProviderStatusStoppingLocalServer =>
      'Arresto del server locale...';

  @override
  String get appProviderStoppingLocalServer => 'Arresto del server locale...';

  @override
  String get appProviderTailscaleNotSupported =>
      'Tailscale non è supportato su questa piattaforma';

  @override
  String appProviderUsingCommandAt(String path) {
    return 'Utilizzo del comando OpenCode in $path';
  }

  @override
  String get appShellDownloadingUpdate => 'Download aggiornamento in corso';

  @override
  String get appShellInstall => 'Installa';

  @override
  String get appShellInstallFailed => 'Installazione non riuscita';

  @override
  String get appShellInstallingUpdate => 'Installazione aggiornamento...';

  @override
  String get appShellRestart => 'Riavvia';

  @override
  String appShellUpdateAvailableResult(String latestVersion) {
    return 'Aggiornamento disponibile: v$latestVersion';
  }

  @override
  String get appShellUpdateInstalledRestartApp =>
      'Aggiornamento installato. Riavvia l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'app per applicare.';

  @override
  String get appShellUpdateInstalledRestartRequired =>
      'Aggiornamento installato. È richiesto il riavvio per applicare la nuova versione.';

  @override
  String get attachmentCouldNotDecode =>
      'Impossibile decodificare i dati dell\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'allegato.';

  @override
  String get attachmentCouldNotDownload =>
      'Impossibile scaricare l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'allegato.';

  @override
  String get attachmentCouldNotSave =>
      'Impossibile salvare l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'allegato su questo dispositivo.';

  @override
  String get attachmentDownloadStarted => 'Download dellallegato iniziato.';

  @override
  String get attachmentLocalNotFound =>
      'Allegato locale non trovato su questo dispositivo.';

  @override
  String get attachmentNoValidLocation =>
      'L\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'allegato non fornisce una posizione valida.';

  @override
  String get attachmentNotAvailableOnPlatform =>
      'Le azioni sugli allegati non sono disponibili su questa piattaforma.';

  @override
  String get attachmentPathEmpty =>
      'Il percorso dell\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'allegato è vuoto.';

  @override
  String get attachmentPayloadEmpty =>
      'Il payload dell\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'allegato è vuoto.';

  @override
  String get attachmentSaveCanceled => 'Salvataggio annullato.';

  @override
  String attachmentSavedAndOpened(String path) {
    return 'Allegato salvato in $path e aperto.';
  }

  @override
  String attachmentSavedPath(String path) {
    return 'Allegato salvato in $path.';
  }

  @override
  String attachmentSavedTo(String path) {
    return 'Allegato salvato in $path.';
  }

  @override
  String get attachmentUnableToOpenLink =>
      'Impossibile aprire il link dell\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'allegato.';

  @override
  String get attachmentUnableToOpenLocal =>
      'Impossibile aprire l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'allegato locale.';

  @override
  String get behaviorAdvancedPermissionRule =>
      'Regola di autorizzazione avanzata';

  @override
  String get behaviorAutomatic => 'Automatico';

  @override
  String get behaviorAutomaticFallback => 'Fallback automatico';

  @override
  String get behaviorCellularDataSaver => 'Risparmio dati mobili';

  @override
  String get behaviorCellularDataSaverActive => 'Il risparmio dati è attivo.';

  @override
  String get behaviorChatLevelShare => 'Condivisione a livello chat';

  @override
  String get behaviorCodeWalkReleaseChecks => 'Controlli versione CodeWalk';

  @override
  String get behaviorControlsOfficialGlobal =>
      'Controlla le impostazioni globali ufficiali di OpenCode';

  @override
  String get behaviorControlsUpstreamOpenCode =>
      'Controlla le impostazioni OpenCode upstream';

  @override
  String get behaviorCustomDisplayName => 'Nome visualizzato personalizzato';

  @override
  String behaviorCutsAutomaticMobile(int inSeconds) {
    return 'Riduce l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'utilizzo automatico dei dati mobili fermando i download in background e limitando gli aggiornamenti automatici in primo piano a un burst ogni $inSeconds secondi.';
  }

  @override
  String get behaviorDataSaverActive => 'Attivo ora sui dati mobili.';

  @override
  String get behaviorDataSaverAggressive => 'Aggressive';

  @override
  String get behaviorDataSaverAggressiveDescription =>
      'Low-bandwidth mode: only the visible workspace stream stays live, global updates are paused, and automatic refreshes are stretched.';

  @override
  String get behaviorDataSaverCellularOnly =>
      'Si applica solo quando la connessione è cellulare/mobile.';

  @override
  String get behaviorDataSaverOff => 'Off';

  @override
  String get behaviorDataSaverOffHint =>
      'Full realtime and automatic refreshes are enabled.';

  @override
  String get behaviorDataSaverStandard => 'Standard';

  @override
  String get behaviorDataSaverWaiting =>
      'In attesa della prossima finestra di sincronizzazione dei dati mobili.';

  @override
  String get behaviorDisabled => 'Disabilitato';

  @override
  String get behaviorLightweightTasksLike => 'Attività leggere come';

  @override
  String get behaviorManual => 'Manuale';

  @override
  String get behaviorNotify => 'Notifica';

  @override
  String get behaviorOfficialOpenCodePermission =>
      'La politica ufficiale dei permessi di OpenCode è configurata in `opencode.json` con regole consenti/chiedi/nega per strumento. CodeWalk mantiene le schede ufficiali di richiesta di permesso e aggiunge un\'eccezione approvata ADR-023: l\'interruttore di approvazione automatica del composer risponde incondizionatamente con `Always` e `remember: true` per creare concessioni persistenti con ambito sessione, e mantiene attivo lo stesso percorso di continuità con ambito thread nel background worker di Android.';

  @override
  String get behaviorOpenCodeBackedDefaults =>
      'Impostazioni predefinite basate su OpenCode';

  @override
  String get behaviorPermissionHandlingProvenance =>
      'Provenienza della gestione dei permessi';

  @override
  String get behaviorPermissionsVariantReasoning =>
      'La parità dei permessi e della variante/ragionamento rimangono separate finché la loro interfaccia utente non consentirà di preservare in sicurezza la configurazione avanzata.';

  @override
  String get behaviorPrimaryAgentAgent =>
      'Agente primario utilizzato quando non viene scelto esplicitamente alcun agente.';

  @override
  String get behaviorRefreshDefaults => 'Aggiorna impostazioni predefinite';

  @override
  String get behaviorSharedAcrossOpenCode =>
      'Condiviso tra i client OpenCode tramite la configurazione.';

  @override
  String get behaviorTheseValuesWrite =>
      'Questi valori vengono scritti su `/config` nel server attivo e corrispondono alla configurazione condivisa ufficiale di OpenCode.';

  @override
  String get cannedAddTitle => 'Aggiungi risposta rapida';

  @override
  String get cannedAppendAtCursor => 'Aggiungi al cursore';

  @override
  String get cannedAppendAtCursorSubtitle =>
      'Off = sostituisce il testo corrente';

  @override
  String get cannedAttachFiles => 'Allega file';

  @override
  String get cannedEditTitle => 'Modifica risposta rapida';

  @override
  String get cannedNewQuickReply => 'Nuova risposta rapida';

  @override
  String get cannedNoSuggestions => 'Nessun suggerimento';

  @override
  String get cannedOffMeansReplace =>
      'Disattivato significa sostituire il testo corrente del composer';

  @override
  String get cannedQuickReply => 'Nuova risposta rapida';

  @override
  String get cannedReplace => 'Sostituisci';

  @override
  String get cannedScopeGlobalSubtitle =>
      'Disabilita per elemento solo progetto';

  @override
  String get cannedScopeGlobalUnavailableSubtitle =>
      'Solo progetto non disponibile in questo contesto';

  @override
  String get cannedSendAutomaticallySubtitle =>
      'Invia subito dopo l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'inserimento';

  @override
  String get cannedSendImmediatelyInserting =>
      'Invia immediatamente dopo aver inserito questa risposta rapida';

  @override
  String get cannedTextLabel => 'Testo';

  @override
  String get chatActionNext => 'Avanti';

  @override
  String get chatActiveServerUnhealthy =>
      'Il server attivo è in uno stato non integro. Gli invii verranno tentati una sola volta e falliranno rapidamente fino al ripristino.';

  @override
  String get chatActiveServerUnhealthyLabel => 'Il server attivo non è integro';

  @override
  String get chatAddServerToStart =>
      'Aggiungi un server per iniziare a chattare.';

  @override
  String get chatAppBarMoreActions => 'Altre azioni';

  @override
  String get chatAppBarPinAction => 'Aggiungi alla barra dell\'app';

  @override
  String get chatAppBarPinDescription =>
      'Questa azione rimarrà visibile all\'esterno del menu.';

  @override
  String get chatAppBarUnpinAction => 'Rimuovi dalla barra dell\'app';

  @override
  String get chatAppBarUnpinDescription =>
      'Questa azione tornerà all\'interno del menu.';

  @override
  String chatBadgeConversationError(String title) {
    return '\"$title\" ha un errore.';
  }

  @override
  String chatBadgeConversationNeedsInput(String title) {
    return '\"$title\" richiede il tuo intervento.';
  }

  @override
  String chatBadgeConversationNewReply(String title) {
    return '\"$title\" ha una nuova risposta.';
  }

  @override
  String get chatBadgeDataSaverActive =>
      'Il risparmio dati cellulare è attivo.';

  @override
  String get chatBadgeServerNeedsAttention =>
      'La connessione al server richiede attenzione.';

  @override
  String get chatBadgeSyncing => 'Sincronizzazione conversazioni...';

  @override
  String get chatBlockResponsePendingDescription =>
      'The answer will appear as a single block when this turn finishes.';

  @override
  String get chatBlockResponsePendingTitle => 'Generating response';

  @override
  String get chatCachedConversationsYet =>
      'Nessuna conversazione ancora memorizzata nella cache';

  @override
  String get chatChangedFilesAvailable =>
      'Nessun file modificato disponibile per questa sessione.';

  @override
  String chatChildrenChatProviderCurrentSessionChildren(int length) {
    return 'Figli: $length';
  }

  @override
  String get chatChooseAgent => 'Seleziona agente';

  @override
  String get chatChooseDirectory => 'Scegli directory';

  @override
  String get chatChooseEffort => 'Scegli impegno';

  @override
  String get chatChooseFolderOpen =>
      'Scegli una cartella da aprire come contesto del progetto.';

  @override
  String get chatChooseModel => 'Scegli modello';

  @override
  String get chatClose => 'Chiudi';

  @override
  String chatCloseProject(String project) {
    return 'Chiudi $project';
  }

  @override
  String get chatCollapseGroup => 'Comprimi gruppo';

  @override
  String get chatCommandDescriptionProject => 'Comando del progetto';

  @override
  String get chatCommandSourceGeneric => 'comando';

  @override
  String get chatCommandSourceProject => 'progetto';

  @override
  String get chatCompactContext => 'Compatta contesto';

  @override
  String get chatComposerHintShell => 'Comando shell (Esc per uscire)';

  @override
  String get chatComposerPlaceholder => 'Scrivi le tue esigenze...';

  @override
  String get chatConversation => 'Conversazione';

  @override
  String get chatConversations => 'Conversazioni';

  @override
  String get chatConversationsPane => 'Conversazioni';

  @override
  String chatCostLabel(double cost) {
    return 'Costo: \$$cost';
  }

  @override
  String get chatCouldNotRefreshSession =>
      'Impossibile aggiornare la conversazione';

  @override
  String get chatCurrent => 'Usa corrente';

  @override
  String chatDescriptionChildren(int count) {
    return 'Figli: $count';
  }

  @override
  String get chatDescriptionCloseApp =>
      'Chiudi l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'app usando il comportamento di chiusura della piattaforma';

  @override
  String get chatDescriptionCycleModels => 'Cicla modelli recenti';

  @override
  String get chatDescriptionCycleVariant => 'Cicla variante modello';

  @override
  String get chatDescriptionDiffFilesZero => 'File diff: 0';

  @override
  String get chatDescriptionFocusInput =>
      'Focus sull\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'input del messaggio';

  @override
  String get chatDescriptionFocusOrCloseDrawer =>
      'Focus sull\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'input (o chiudi il pannello se aperto)';

  @override
  String get chatDescriptionForceExit =>
      'Forza l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'uscita dall\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'app';

  @override
  String get chatDescriptionNewConversation => 'Nuova conversazione';

  @override
  String get chatDescriptionNextAgent => 'Prossimo agente';

  @override
  String get chatDescriptionOpenProjects =>
      'Usa questo pulsante per aprire i tuoi progetti e conversazioni.';

  @override
  String get chatDescriptionOpenSettings => 'Apri impostazioni';

  @override
  String get chatDescriptionPreviousAgent => 'Agente precedente';

  @override
  String get chatDescriptionProjectCommand => 'Comando progetto';

  @override
  String get chatDescriptionQuickOpen => 'Apertura rapida file';

  @override
  String get chatDescriptionRefreshData => 'Aggiorna dati chat';

  @override
  String get chatDescriptionStopResponse =>
      'Ferma risposta attiva (durante la risposta)';

  @override
  String get chatDescriptionSwitchProject =>
      'Usa questo pulsante per cambiare cartelle di progetto e contesto.';

  @override
  String get chatDescriptionVoiceInput => 'Avvia o ferma input vocale';

  @override
  String get chatDiffFiles => 'File diff: 0';

  @override
  String get chatDisplay => 'Visualizza';

  @override
  String get chatDisplayToggles => 'Controlli di visualizzazione';

  @override
  String get chatDoubleESCStop => 'Doppio ESC per interrompere';

  @override
  String get chatEffortLockedSubConversation =>
      'Impegno bloccato nella sottoconversazione';

  @override
  String get chatExpandGroup => 'Espandi gruppo';

  @override
  String get chatExportCanceled => 'Esportazione sessione annullata';

  @override
  String get chatFailedToLoadDirectories => 'Impossibile caricare le directory';

  @override
  String get chatFailedToLoadFile => 'Impossibile caricare il file';

  @override
  String get chatFailedToRefreshProviders =>
      'Aggiornamento provider e modelli fallito';

  @override
  String get chatFailedToRefreshSubConversations =>
      'Aggiornamento sottoconversazioni fallito. Riprova.';

  @override
  String get chatFailedToStopResponse =>
      'Impossibile arrestare la risposta corrente';

  @override
  String get chatFileExplorerContents => 'Contenuti';

  @override
  String get chatFileExplorerNames => 'Nomi';

  @override
  String get chatFilterActive => 'Attive';

  @override
  String get chatFilterAll => 'Tutte';

  @override
  String get chatFilterArchived => 'Archiviate';

  @override
  String get chatFilterDirectories => 'Filtra directory';

  @override
  String get chatFilterSessions => 'Filtra sessioni';

  @override
  String get chatForkFailed => 'Biforcazione conversazione fallita';

  @override
  String get chatForked => 'Conversazione biforcata';

  @override
  String get chatGoToFirst => 'Vai al primo messaggio';

  @override
  String get chatGoToLatest => 'Vai all\'ultimo messaggio';

  @override
  String chatGroupMessageCountMessages(
    String compactionLabel,
    String messageCount,
  ) {
    return '$messageCount messaggi nascosti prima della compressione $compactionLabel';
  }

  @override
  String get chatHelloAssistant => 'Ciao! Sono il tuo assistente IA';

  @override
  String get chatHelp => 'Come posso aiutarti?';

  @override
  String get chatHelpMessage =>
      'Usa @ per le menzioni, ! per la shell, / per i comandi';

  @override
  String get chatHideConversationsSidebar =>
      'Nascondi barra laterale Conversazioni';

  @override
  String get chatHideUtilitySidebar => 'Nascondi barra laterale Utilità';

  @override
  String get chatHistoryCollapsed => 'La cronologia precedente è compressa';

  @override
  String get chatHistoryHideEarlier => 'Nascondi i messaggi precedenti';

  @override
  String chatHistoryMessagesHidden(int count, String label) {
    return '$count messaggi nascosti prima della compattazione $label';
  }

  @override
  String get chatHistoryShowEarlier => 'Mostra i messaggi precedenti';

  @override
  String get chatKeepWorking => 'Continua a lavorare';

  @override
  String get chatLargeContentSkipped =>
      'Contenuto grande o malformato saltato per stabilità.';

  @override
  String get chatLatestToolActivity =>
      'L\'attività più recente dello strumento rimane all\'interno di questo riquadro limitato per mantenere stabile l\'area visibile della chat.';

  @override
  String get chatLoadMore => 'Carica altro';

  @override
  String get chatLoadingProjectContext =>
      'Caricamento del contesto del progetto in corso...';

  @override
  String get chatMainConversationUnavailable =>
      'Conversazione principale non ancora disponibile.';

  @override
  String get chatParentConversationUnavailable =>
      'La conversazione precedente non è ancora disponibile.';

  @override
  String get chatMentionAgentSubtitle => 'agente';

  @override
  String get chatMentionFileSubtitle => 'file';

  @override
  String get chatMentionSymbolSubtitle => 'simbolo';

  @override
  String get chatMessageAttachedFile => 'File allegato';

  @override
  String get chatMessageDetails => 'Dettagli';

  @override
  String get chatMessageHide => 'Nascondi';

  @override
  String get chatMessageLess => 'Meno';

  @override
  String get chatMessageMessagePartUnavailable =>
      'Parte del messaggio non disponibile';

  @override
  String get chatMessageMetadataAvailable => 'Nessun metadato disponibile';

  @override
  String chatMessageModelMessageModelId(String modelId) {
    return 'Modello: $modelId';
  }

  @override
  String get chatMessageMore => 'Altro';

  @override
  String get chatMessageOpenFile => 'Apri file';

  @override
  String chatMessageProviderMessageProviderId(String providerId) {
    return 'Provider: $providerId';
  }

  @override
  String get chatMessageRewindEdit => 'Riavvolgi e modifica da qui';

  @override
  String get chatMessageRunningTask => 'Attività in esecuzione';

  @override
  String get chatMessageSaveFile => 'Salva file';

  @override
  String get chatMessageShow => 'Mostra';

  @override
  String get chatMessageShowLess => 'Mostra meno';

  @override
  String get chatMessageShowLessCompact => 'Meno';

  @override
  String get chatMessageShowMore => 'Mostra più';

  @override
  String get chatMessageShowMoreCompact => 'Altro';

  @override
  String get chatMessageThinking => 'Sta pensando';

  @override
  String get chatMessageThinkingProcess => 'Processo di pensiero';

  @override
  String get chatMessageToolCall => '1 chiamata a strumento';

  @override
  String chatMessageToolCalls(int count) {
    return '$count chiamate a strumenti';
  }

  @override
  String get chatMessageToolCommand => 'Comando';

  @override
  String get chatMessageToolCommandTruncated => 'Anteprima comando troncata.';

  @override
  String get chatMessageToolDiffOmitted =>
      'Anteprima diff omessa: payload troppo grande.';

  @override
  String get chatMessageToolInput => 'Input';

  @override
  String get chatMessageToolInputTruncated => 'Anteprima input troncata.';

  @override
  String get chatMessageToolOutputTruncated =>
      'Anteprima troncata per stabilità.';

  @override
  String chatMessageToolQueuedCount(int count) {
    return '$count in coda';
  }

  @override
  String chatMessageToolRunningCount(int count) {
    return '$count in esecuzione';
  }

  @override
  String get chatMessageToolStatusInProgress => 'In corso';

  @override
  String get chatMessageToolStatusNeedsAttention => 'Richiede attenzione';

  @override
  String get chatMessageToolStatusQueued => 'In coda';

  @override
  String get chatMessageYou => 'Tu';

  @override
  String get chatModelLockedSubConversation =>
      'Modello bloccato nella sottoconversazione';

  @override
  String get chatNewChat => 'Nuova chat';

  @override
  String get chatNewChatTourDescription => 'Avvia una nuova conversazione qui.';

  @override
  String get chatNewChatTourTitle => 'Nuova chat';

  @override
  String get chatNoConversationsInProject =>
      'Nessuna conversazione in questo progetto.';

  @override
  String get chatNoServerYet => 'Nessun server ancora configurato';

  @override
  String get chatNoSessionSelected => 'Seleziona o crea una conversazione';

  @override
  String get chatNoSubConversationFound =>
      'Nessuna sottoconversazione trovata.';

  @override
  String get chatOpenFiles => 'File aperti';

  @override
  String get chatOpenProject => 'Apri progetto';

  @override
  String get chatOpenProjectFolder => 'Apri cartella del progetto...';

  @override
  String get chatOpenProjectToLoad =>
      'Apri un progetto per caricare le conversazioni.';

  @override
  String get chatOpenSidebar => 'Apri barra laterale';

  @override
  String get chatPageStatusAutomaticCompactionExplanation =>
      'La compattazione automatica avviene man mano che cresce l\'utilizzo del contesto.';

  @override
  String get chatPageStatusCompactNow => 'Compatta ora';

  @override
  String get chatPageStatusCompacting => 'Compattazione in corso...';

  @override
  String get chatPageStatusCompactingContextNow =>
      'Compattazione del contesto in corso...';

  @override
  String get chatPageStatusContextCompacted => 'Contesto compattato';

  @override
  String get chatPageStatusContextUsage => 'Utilizzo del contesto';

  @override
  String get chatPageStatusCost => 'Costo';

  @override
  String get chatPageStatusFailedToCompactContext =>
      'Impossibile compattare il contesto';

  @override
  String get chatPageStatusLimit => 'Limite';

  @override
  String get chatPageStatusManageServers => 'Gestisci server';

  @override
  String get chatPageStatusSaver => 'Risparmio';

  @override
  String get chatPageStatusServer => 'Server';

  @override
  String get chatPageStatusSwitchServer => 'Cambia server';

  @override
  String get chatPageStatusTokens => 'Token';

  @override
  String get chatPageStatusUsage => 'Utilizzo';

  @override
  String chatPageStatusUsagePercent(int usagePercent) {
    return '$usagePercent';
  }

  @override
  String get chatPermissionAutoApproveOff =>
      'Approvazione automatica dei permessi disattiva';

  @override
  String get chatPermissionAutoApproveOn =>
      'Approvazione automatica dei permessi attiva';

  @override
  String get chatProjectContext => 'Contesto del progetto';

  @override
  String get chatProjectContext2 => 'Contesto del progetto';

  @override
  String get chatRealtimeGlobalEvent => 'evento globale';

  @override
  String chatRealtimeGlobalEventReason(String reason) {
    return 'evento globale ($reason)';
  }

  @override
  String get chatRealtimeGlobalEventStale =>
      'evento globale (generazione non aggiornata)';

  @override
  String chatRealtimeMessageStreamReason(String reason) {
    return 'flusso di messaggi ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEvent => 'evento in tempo reale';

  @override
  String chatRealtimeRealtimeEventReason(String reason) {
    return 'evento in tempo reale ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEventStale =>
      'evento in tempo reale (generazione non aggiornata)';

  @override
  String get chatRealtimeReconnectingServerTry =>
      'Riconnessione al server. Riprovare tra un momento.';

  @override
  String get chatReasoning => 'Ragionamento...';

  @override
  String get chatRecentSessions => 'Sessioni recenti';

  @override
  String get chatRecentSessionsToggle => 'Sessioni recenti';

  @override
  String get chatRedoLastTurn => 'Ripristina ultimo turno annullato';

  @override
  String get chatRedoNothing => 'Nulla da ripristinare in questa sessione';

  @override
  String get chatRefresh => 'Aggiorna';

  @override
  String get chatRefreshConversation =>
      'Impossibile aggiornare questa conversazione';

  @override
  String get chatRefreshProjects => 'Aggiorna progetti';

  @override
  String get chatRefreshSessionDetails => 'Aggiorna dettagli sessione';

  @override
  String chatRemoveDisplayNameHistory(String displayName) {
    return 'Rimuovi $displayName dalla cronologia';
  }

  @override
  String get chatRetry => 'Riprova';

  @override
  String get chatRetry2 => 'Riprova';

  @override
  String get chatRetryRefresh => 'Riprova aggiornamento';

  @override
  String get chatRetryingModelRequest =>
      'Nuovo tentativo di richiesta del modello in corso...';

  @override
  String get chatReturnToMainConversation =>
      'Torna alla conversazione principale';

  @override
  String get chatReturnToParentConversation =>
      'Torna alla conversazione precedente';

  @override
  String get chatReviewChanges => 'Esamina modifiche';

  @override
  String get chatSearchConversations => 'Cerca conversazioni';

  @override
  String get chatSearchNextResult => 'Risultato successivo';

  @override
  String get chatSearchNoResults => 'Nessun risultato';

  @override
  String get chatSearchPreviousResult => 'Risultato precedente';

  @override
  String chatSearchResultCount(int current, int total) {
    return 'Messaggio $current di $total';
  }

  @override
  String get chatSearchTimeline => 'Cerca nella cronologia';

  @override
  String get chatSelectDirectory => 'Seleziona directory';

  @override
  String get chatSelectOrCreate =>
      'Seleziona o crea una conversazione per iniziare a chattare';

  @override
  String get chatSelectProjectBelow => 'Seleziona un progetto di seguito.';

  @override
  String get chatServerSelectedModel => 'Modello selezionato dal server';

  @override
  String get chatSessionActions => 'Azioni sessione';

  @override
  String chatSessionChatSessionSession(String title) {
    return 'Sessione di chat: $title';
  }

  @override
  String chatSessionConversationNextAction(String nextAction) {
    return 'Conversazione $nextAction';
  }

  @override
  String get chatSessionConversations => 'Nessuna conversazione';

  @override
  String get chatSessionCreateConversationStart =>
      'Crea una nuova conversazione per iniziare a chattare';

  @override
  String get chatSessionTabsToggle => 'Schede delle sessioni';

  @override
  String chatSessionsLength(int length) {
    return '$length';
  }

  @override
  String get chatSetUpServer => 'Configura server';

  @override
  String get chatSettings => 'Impostazioni';

  @override
  String get chatShortcutsCloseApp =>
      'Chiudi app usando il comportamento della piattaforma';

  @override
  String get chatShortcutsCycleModels => 'Cicla modelli recenti';

  @override
  String get chatShortcutsCycleVariant => 'Cicla variante modello';

  @override
  String get chatShortcutsFocusInput => 'Focus inserimento messaggio';

  @override
  String get chatShortcutsFocusInputCloseDrawer =>
      'Focus inserimento (o chiudi cassetto se aperto)';

  @override
  String get chatShortcutsForceExit =>
      'Forza l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'uscita dall\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'app';

  @override
  String get chatShortcutsNewConversation => 'Nuova conversazione';

  @override
  String get chatShortcutsNextAgent => 'Agente successivo';

  @override
  String get chatShortcutsOpenSettings => 'Apri impostazioni';

  @override
  String get chatShortcutsPreviousAgent => 'Agente precedente';

  @override
  String get chatShortcutsQuickOpen => 'Apertura rapida file';

  @override
  String get chatShortcutsRefreshChat => 'Aggiorna dati chat';

  @override
  String get chatShortcutsStartStopVoice => 'Avvia o ferma input vocale';

  @override
  String get chatShortcutsStopResponse =>
      'Ferma risposta attiva (durante la risposta)';

  @override
  String get chatSidebarAccess => 'Accesso barra laterale';

  @override
  String get chatSortMostRecent => 'Più recenti';

  @override
  String get chatSortOldest => 'Meno recenti';

  @override
  String get chatSortRecent => 'Recenti';

  @override
  String get chatSortSessions => 'Ordina sessioni';

  @override
  String get chatSortTitle => 'Titolo';

  @override
  String get chatStartVoiceInput => 'Avvia input vocale';

  @override
  String get chatStartingVoiceInput => 'Avvio input vocale';

  @override
  String get chatStatusBusy => 'Stato: Occupato';

  @override
  String get chatStatusPatching => 'Applicazione patch';

  @override
  String chatStatusPatchingMultipleFiles(int count) {
    return 'Patch di $count file';
  }

  @override
  String get chatStatusPatchingOneFile => 'Patch di 1 file';

  @override
  String get chatStatusRetry => 'Stato: Riprova';

  @override
  String chatStatusRetryCount(int count) {
    return 'Stato: Riprova #$count';
  }

  @override
  String get chatStatusSubsession => 'Sottosessione';

  @override
  String get chatStatusThinking => 'Pensando...';

  @override
  String get chatStopVoiceInput => 'Ferma input vocale';

  @override
  String chatSyncLabel(String label) {
    return 'Sincronizzazione: $label';
  }

  @override
  String get chatTasks => 'Attività';

  @override
  String get chatTasksAvailableSession =>
      'Nessuna attività disponibile per questa sessione.';

  @override
  String get chatTipAcceptanceCriteria =>
      'Suggerimento: Aggiungi criteri di accettazione per cambi grandi';

  @override
  String get chatTipAskForPlan =>
      'Suggerimento: Chiedi prima un piano per attività grandi';

  @override
  String get chatTipBeSpecific =>
      'Suggerimento: Sii specifico — prompt brevi ottengono risposte più veloci';

  @override
  String get chatTipBreakTasks =>
      'Suggerimento: Dividi compiti grandi in prompt più piccoli';

  @override
  String get chatTipCompareOptions =>
      'Suggerimento: Chiedi alternative quando i tradeoff non sono chiari';

  @override
  String get chatTipContextKnob =>
      'Suggerimento: Tocca la manopola del contesto per vedere i dettagli di utilizzo';

  @override
  String get chatTipDefineVerification =>
      'Suggerimento: Dì quali test o controlli devono passare';

  @override
  String get chatTipLongPressSend =>
      'Suggerimento: Premi a lungo Invia per inserire una nuova riga';

  @override
  String get chatTipMentionFiles =>
      'Suggerimento: Usa @ per menzionare file nel tuo prompt';

  @override
  String get chatTipNameRelevantFiles =>
      'Suggerimento: Indica file, schermate o comandi rilevanti';

  @override
  String get chatTipProvideContext =>
      'Suggerimento: Fornisci contesto — incolla messaggi di errore e log';

  @override
  String get chatTipRenameConversation =>
      'Suggerimento: Tocca il titolo per rinominare una conversazione';

  @override
  String get chatTipRequestDocs =>
      'Suggerimento: Chiedi aggiornamenti docs quando cambia il comportamento';

  @override
  String get chatTipShareAttempts =>
      'Suggerimento: Condividi cosa hai provato e il messaggio esatto';

  @override
  String get chatTipShellCommands =>
      'Suggerimento: Usa ! all\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'inizio per eseguire comandi shell';

  @override
  String get chatTipSlashCommands =>
      'Suggerimento: Usa / per accedere ai comandi slash';

  @override
  String get chatTipStartWithGoal =>
      'Suggerimento: Inizia con il risultato finale';

  @override
  String get chatTipStateConstraints =>
      'Suggerimento: Indica i vincoli da preservare';

  @override
  String get chatTipStepByStep =>
      'Suggerimento: Chiedi passo-passo durante il debug di problemi complessi';

  @override
  String get chatTipUseFocusedAgents =>
      'Suggerimento: Scegli un agente mirato per piano, review o build';

  @override
  String get chatToggleSidebars => 'Attiva/disattiva barre laterali';

  @override
  String chatTokensLabel(int total) {
    return 'Token: $total';
  }

  @override
  String get chatTourProjectsConversations =>
      'Usa questo pulsante per aprire i tuoi progetti e le tue conversazioni.';

  @override
  String get chatTourSidebarProjectTools =>
      'Usa questo menu per mostrare la barra laterale delle conversazioni e gli strumenti del progetto.';

  @override
  String get chatTourSwitchFolders =>
      'Usa questo pulsante per cambiare cartelle di progetto e contesto.';

  @override
  String get chatUndoLastTurn => 'Annulla ultimo turno';

  @override
  String get chatUndoNothing => 'Nulla da annullare in questa sessione';

  @override
  String get chatUseCurrent => 'Usa corrente';

  @override
  String get chatWaitingForNetworkConnection =>
      'In attesa di connessione di rete...';

  @override
  String get chatWelcomeMessage => 'Ciao! Sono il tuo assistente AI.';

  @override
  String get chatWelcomeSubmessage => 'Come posso aiutarti oggi?';

  @override
  String get chatWorkBoundedPanelExplanation =>
      'L\'attività più recente dello strumento rimane all\'interno di questo riquadro limitato per mantenere stabile l\'area visibile della chat.';

  @override
  String get chatWorkExpand => 'Espandi';

  @override
  String get chatWorkHide => 'Nascondi';

  @override
  String get chatWorkMessageOne => '1 messaggio di lavoro';

  @override
  String chatWorkMessagesMultiple(int count) {
    return '$count messaggi di lavoro';
  }

  @override
  String get chatWorkShow => 'Mostra';

  @override
  String get commonCancel => 'Annulla';

  @override
  String get commonCopiedToClipboard => 'Copiato negli appunti';

  @override
  String get commonDelete => 'Elimina';

  @override
  String get commonFile => 'File';

  @override
  String get commonReset => 'Ripristina';

  @override
  String get commonSave => 'Salva';

  @override
  String get compactionAutomatic => 'automatico';

  @override
  String get compactionManual => 'manuale';

  @override
  String get composerAddAttachment => 'Aggiungi allegato';

  @override
  String get composerAttachFiles => 'Allega file';

  @override
  String get composerCannedAppendAtCursor => 'Accoda al cursore';

  @override
  String get composerCannedLabel => 'Etichetta (opzionale)';

  @override
  String get composerCannedNoReplies => 'Nessuna risposta rapida presente.';

  @override
  String get composerCannedReplace => 'Sostituisci';

  @override
  String get composerCannedSave => 'Salva';

  @override
  String get composerCannedScopeGlobal => 'Globale';

  @override
  String get composerCannedScopeProject => 'Solo progetto';

  @override
  String get composerCannedSendAutomatically => 'Invia automaticamente';

  @override
  String get composerCannedText => 'Testo';

  @override
  String get composerChatInput => 'Input chat';

  @override
  String get composerDeleteAction => 'Elimina';

  @override
  String get composerDropHint => 'Rilascia immagini o PDF da allegare';

  @override
  String get composerPastedImageName => 'Immagine incollata';

  @override
  String get composerEdit => 'Modifica';

  @override
  String get composerExtras => 'Extra';

  @override
  String get composerExtrasHide => 'Nascondi extra';

  @override
  String get composerNewQuickReply => 'Nuova risposta rapida';

  @override
  String get composerSelectImages => 'Seleziona immagini';

  @override
  String get composerSelectPdf => 'Seleziona PDF';

  @override
  String get composerSend => 'Invia';

  @override
  String get composerShellMode => 'Modalità shell';

  @override
  String get desktopWindowClose => 'Chiudi';

  @override
  String get desktopWindowMaximize => 'Ingrandisci';

  @override
  String get desktopWindowMinimize => 'Riduci a icona';

  @override
  String get desktopWindowRestore => 'Ripristina';

  @override
  String get dialogDownload => 'Scarica';

  @override
  String get dialogLanguage => 'Lingua';

  @override
  String get dialogMoonshineModelSize => 'Dimensione modello';

  @override
  String get dialogMoonshineVoiceSetup => 'Configurazione voce Moonshine';

  @override
  String get dialogParakeetModel => 'Modello Parakeet';

  @override
  String get dialogParakeetVoiceSetup => 'Configurazione voce Parakeet';

  @override
  String get dialogSenseVoiceModel => 'Modello SenseVoice';

  @override
  String get dialogSenseVoiceSetup => 'Configurazione SenseVoice';

  @override
  String get dialogVoiceInputSetup => 'Configurazione input vocale';

  @override
  String get errorAnErrorOccurred => 'Si è verificato un errore';

  @override
  String get errorAuthRequired => 'Autenticazione richiesta';

  @override
  String get errorAuthRequiredDesc =>
      'Autenticazione fallita. Riconnetti il provider e riprova.';

  @override
  String get errorConnectionFailed => 'Connessione fallita';

  @override
  String get errorConnectionFailedDesc =>
      'Impossibile raggiungere il server. Controlla la connessione e lo stato del server.';

  @override
  String get errorFormatAuthenticationFailedReconnect =>
      'Autenticazione fallita. Riconnetti il provider e riprova.';

  @override
  String get errorFormatProviderTemporarilyUnavailable =>
      'Provider temporaneamente non disponibile. Riprova tra poco.';

  @override
  String get errorFormatQuotaExceededCheck =>
      'Quota superata. Controlla il piano del tuo provider o la fatturazione.';

  @override
  String get errorFormatRateLimitExceeded =>
      'Limite di frequenza superato. Attendi un momento e riprova.';

  @override
  String get errorFormatServerErrorPlease => 'Errore del server. Riprova.';

  @override
  String get errorFormatServiceTemporarilyUnavailable =>
      'Servizio temporaneamente non disponibile. Il server potrebbe essere in fase di avvio — riprova tra poco.';

  @override
  String get errorFormatUnableReachServer =>
      'Impossibile raggiungere il server. Controlla la connessione e lo stato del server.';

  @override
  String get errorProviderUnavailable => 'Provider non disponibile';

  @override
  String get errorProviderUnavailableDesc =>
      'Provider temporaneamente non disponibile. Riprova tra poco.';

  @override
  String get errorQuotaExceeded => 'Quota superata';

  @override
  String get errorQuotaExceededDesc =>
      'Quota superata. Controlla il piano del tuo provider o la fatturazione.';

  @override
  String get errorRateLimitExceeded => 'Limite di velocità superato';

  @override
  String get errorRateLimitExceededDesc =>
      'Limite di velocità superato. Attendi un momento e riprova.';

  @override
  String get errorServerError => 'Errore del server';

  @override
  String get errorServerErrorDesc => 'Errore del server. Per favore riprova.';

  @override
  String get errorServiceUnavailable => 'Servizio non disponibile';

  @override
  String get errorServiceUnavailableDesc =>
      'Servizio temporaneamente non disponibile. Il server potrebbe essere in fase di avvio — riprova tra poco.';

  @override
  String get fileActionAttachmentDataDecoded =>
      'Impossibile decodificare i dati dell\'allegato.';

  @override
  String get fileActionAttachmentPathEmpty =>
      'Il percorso dell\'allegato è vuoto.';

  @override
  String get fileActionAttachmentPayloadEmpty =>
      'Il payload dell\'allegato è vuoto.';

  @override
  String get fileActionAttachmentProvideValid =>
      'L\'allegato non fornisce una posizione valida.';

  @override
  String get fileActionAttachmentSavedDevice =>
      'Impossibile salvare l\'allegato su questo dispositivo.';

  @override
  String fileActionAttachmentSavedOutputFile(String path) {
    return 'Allegato salvato in $path e aperto.';
  }

  @override
  String fileActionAttachmentSavedOutputFile2(String path) {
    return 'Allegato salvato in $path.';
  }

  @override
  String fileActionAttachmentSavedSavedPath(String savedPath) {
    return 'Allegato salvato in $savedPath.';
  }

  @override
  String get fileActionLocalAttachmentFound =>
      'Allegato locale non trovato su questo dispositivo.';

  @override
  String get fileActionSaveCanceled => 'Salvataggio annullato.';

  @override
  String get fileActionUnableOpenLocal =>
      'Impossibile aprire l\'allegato locale.';

  @override
  String get filesAddChat => 'Aggiungi alla chat';

  @override
  String get filesAutosave => 'Salvataggio automatico';

  @override
  String get filesAutosaveOn => 'Salvataggio automatico attivo';

  @override
  String get filesAutosaveOff => 'Salvataggio automatico disattivato';

  @override
  String get filesRedo => 'Ripeti';

  @override
  String get filesUndo => 'Annulla';

  @override
  String get filesBinaryFilePreview =>
      'L\'anteprima del file binario non è disponibile.';

  @override
  String get filesClear => 'Cancella';

  @override
  String get filesContents => 'Contenuti';

  @override
  String get filesDuplicate => 'Duplica';

  @override
  String get filesDuplicated => 'File duplicato';

  @override
  String get filesFileEmpty => 'Il file è vuoto.';

  @override
  String get filesAlreadyExists =>
      'A file or folder with that name already exists.';

  @override
  String get filesCopyPath => 'Copy path';

  @override
  String get filesCreateFileTitle => 'Create file';

  @override
  String get filesCreateFolderTitle => 'Create folder';

  @override
  String get filesDelete => 'Delete';

  @override
  String filesDeleteConfirm(String name) {
    return 'Delete $name? This cannot be undone. Folders and their contents will be deleted.';
  }

  @override
  String filesDeleteTitle(String name) {
    return 'Delete $name';
  }

  @override
  String get filesFilesFound => 'Nessun file trovato';

  @override
  String get filesFileCreated => 'File created.';

  @override
  String get filesFolderCreated => 'Folder created.';

  @override
  String get filesHideSidebar => 'Nascondi barra laterale File';

  @override
  String get filesInvalidName => 'Enter a valid name without path separators.';

  @override
  String get filesNameHint => 'Name';

  @override
  String get filesNew => 'New';

  @override
  String get filesNewFile => 'New file';

  @override
  String get filesNewFolder => 'New folder';

  @override
  String get filesNames => 'Nomi';

  @override
  String filesOpenFilesFileState(int length) {
    return 'File aperti ($length)';
  }

  @override
  String get filesQuickOpen => 'Apertura rapida';

  @override
  String get filesQuickOpenFile => 'Apertura rapida file';

  @override
  String get filesOperationFailed => 'File operation failed.';

  @override
  String get filesOperationUnavailable =>
      'File operations are not available for this server.';

  @override
  String get filesOutsideRoot => 'The path is outside the project root.';

  @override
  String get filesPathCopied => 'Path copied.';

  @override
  String get filesPathMissing => 'Path does not exist.';

  @override
  String get filesPermissionDenied => 'Permission denied.';

  @override
  String get filesRefresh => 'Aggiorna file';

  @override
  String get filesRename => 'Rename';

  @override
  String filesRenameTitle(String name) {
    return 'Rename $name';
  }

  @override
  String get filesRenamed => 'Renamed.';

  @override
  String get filesRootDeleteBlocked => 'The project root cannot be deleted.';

  @override
  String get filesSearchHint => 'Cerca file per nome o percorso';

  @override
  String get filesDeleted => 'Deleted.';

  @override
  String get filesTitle => 'File';

  @override
  String get forwardAction => 'Forward';

  @override
  String get forwardAllFailed => 'Could not forward to any session';

  @override
  String get forwardCancel => 'Cancel';

  @override
  String get forwardDialogSubtitle => 'Select one or more conversations';

  @override
  String get forwardDialogTitle => 'Forward to…';

  @override
  String get forwardLoading => 'Loading sessions…';

  @override
  String get forwardNoOpenProjects => 'No open projects with sessions';

  @override
  String get forwardNoProviderModel =>
      'Select a provider and model before forwarding';

  @override
  String get forwardNoSessions => 'No recent sessions';

  @override
  String forwardPartial(int success, int total) {
    return 'Forwarded to $success of $total';
  }

  @override
  String forwardProvenanceLabel(String origin) {
    return 'Forwarded from: $origin';
  }

  @override
  String get forwardRetry => 'Retry';

  @override
  String get forwardSearchHint => 'Search';

  @override
  String forwardSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get forwardSend => 'Forward';

  @override
  String get forwardServerOffline => 'Server offline';

  @override
  String get forwardShortcutHint => 'Ctrl+Shift+F';

  @override
  String forwardSuccess(int count) {
    return 'Forwarded to $count sessions';
  }

  @override
  String get forwardUndo => 'Undo';

  @override
  String get forwardUndoFailed => 'Could not undo the forward';

  @override
  String get logsAppLogs => 'Log dell\'app';

  @override
  String get logsClear => 'Cancella log';

  @override
  String get logsCloseSearch => 'Chiudi ricerca';

  @override
  String get logsCopyFiltered => 'Copia log filtrati';

  @override
  String get logsEnableLogging => 'Attiva log app';

  @override
  String get logsEnableLoggingAction => 'Attiva log';

  @override
  String get logsEnableLoggingDescription =>
      'Raccoglie log diagnostici in memoria. Tienilo disattivato salvo quando risolvi problemi.';

  @override
  String get logsEntryContext => 'Contesto';

  @override
  String get logsEntryTags => 'Tag';

  @override
  String get logsFilterAll => 'Tutti';

  @override
  String get logsFilterByTag => 'Tag';

  @override
  String get logsLevel => 'Livello';

  @override
  String get logsLoggingDisabledDescription =>
      'CodeWalk non sta raccogliendo log dettagliati dell\'app. Attiva i log solo quando servono diagnosi.';

  @override
  String get logsLoggingDisabledTitle => 'Log disattivati';

  @override
  String get logsMeasurePerformance => 'Misura prestazioni';

  @override
  String get logsMeasurePerformanceDescription =>
      'Registra i tempi delle operazioni costose dell\'app. Lascialo disattivato salvo diagnosi di lentezza.';

  @override
  String get logsNoLogsYet => 'Nessun log acquisito finora.';

  @override
  String get logsNoMatchingLogs => 'Nessun log corrisponde ai filtri attuali.';

  @override
  String get logsNoPerformanceData =>
      'Nessun log di prestazioni corrisponde ai filtri attuali.';

  @override
  String get logsNoTaskData =>
      'Nessuna attività corrisponde ai filtri attuali.';

  @override
  String logsPerformanceDuration(int elapsedMs) {
    return '$elapsedMs ms';
  }

  @override
  String get logsPerformanceFilter => 'Prestazioni';

  @override
  String logsPerformanceTileTitle(
    int elapsedMs,
    String operation,
    String status,
  ) {
    return 'PRESTAZIONI $operation | $elapsedMs ms | $status';
  }

  @override
  String get logsSearch => 'Cerca log';

  @override
  String logsShowingOrderedLength(int length, int length2) {
    return 'Visualizzazione di $length di $length2 voci';
  }

  @override
  String get logsSlowestPerformance => 'Log di prestazioni più lenti';

  @override
  String get logsSlowestTasks => 'Attività più lente';

  @override
  String get logsTagCustomHint => 'Nome tag (es.: task:select_session)';

  @override
  String get logsTagCustomAction => 'Personalizzata...';

  @override
  String logsTaskDuration(int elapsedMs, String operation) {
    return '$operation — $elapsedMs ms';
  }

  @override
  String get logsTaskStatusCanceled => 'annullata';

  @override
  String get logsTaskStatusError => 'errore';

  @override
  String get logsTaskStatusOk => 'ok';

  @override
  String get logsTimeRange => 'Intervallo di tempo';

  @override
  String get mathExpressionLabel => 'Matematica';

  @override
  String get mermaidCopySourceTooltip => 'Copia sorgente';

  @override
  String get mermaidDiagramLabel => 'Diagramma Mermaid';

  @override
  String get modelAuto => 'Auto';

  @override
  String get modelChooseAgent => 'Scegli agente';

  @override
  String get modelFavorites => 'Preferiti';

  @override
  String get modelFree => 'Gratis';

  @override
  String get modelLabelBaseEnglish => 'Base (Inglese)';

  @override
  String get modelLabelParakeet => 'Parakeet V3 (25 lingue europee)';

  @override
  String get modelLabelSenseVoice => 'SenseVoice (zh/en/ja/ko/yue)';

  @override
  String get modelLabelTinyEnglish => 'Tiny (Inglese)';

  @override
  String get modelLoadingModels => 'Caricamento modelli in corso...';

  @override
  String get modelModelsFound => 'Nessun modello trovato';

  @override
  String get modelRetryModels => 'Riprova modelli';

  @override
  String get modelSearchHint => 'Cerca modello o provider';

  @override
  String get msgBatterySettingsFailed =>
      'Impossibile aprire le impostazioni di ottimizzazione della batteria di Android.';

  @override
  String get msgBatterySettingsOpened =>
      'Impostazioni della batteria di Android aperte. Consenti l\'uso illimitato della batteria per CodeWalk.';

  @override
  String get msgClearUsernameNeedsConfigEdit =>
      'La rimozione del nome utente della conversazione OpenCode richiede comunque la modifica della configurazione all\'esterno dell\'app.';

  @override
  String get msgCommandCopied => 'Comando copiato';

  @override
  String get msgCopiedToClipboard => 'Copiato negli appunti';

  @override
  String get msgEnterUsernameToSave =>
      'Inserisci un nome utente per salvare un nome personalizzato per la conversazione OpenCode.';

  @override
  String get msgFailedToSendMessage =>
      'Impossibile inviare il messaggio. Bozza salvata per riprovare.';

  @override
  String get msgFailedToStartVoiceInput =>
      'Impossibile avviare l\'input vocale';

  @override
  String msgFilePathNotFound(String path) {
    return 'File non trovato: $path';
  }

  @override
  String get msgFilteredLogsCopied => 'Log filtrati copiati negli appunti';

  @override
  String get msgInfoAgent => 'Agente';

  @override
  String get msgInfoCompaction => 'Compattazione';

  @override
  String msgInfoCost(double cost) {
    return 'Costo: \\\$$cost';
  }

  @override
  String get msgInfoMessageInfo => 'Informazioni messaggio';

  @override
  String msgInfoModel(String modelId) {
    return 'Modello: $modelId';
  }

  @override
  String get msgInfoNoMetadata => 'Nessun metadato disponibile';

  @override
  String msgInfoPartDescriptionModel(String description, String model) {
    return '$description$model';
  }

  @override
  String get msgInfoPatch => 'Patch';

  @override
  String msgInfoProvider(String providerId) {
    return 'Provider: $providerId';
  }

  @override
  String get msgInfoRetry => 'Riprova';

  @override
  String get msgInfoSnapshot => 'Istantanea';

  @override
  String msgInfoSubtaskPartAgent(String agent) {
    return 'Sottoattività ($agent)';
  }

  @override
  String msgInfoTokens(int total) {
    return 'Token: $total';
  }

  @override
  String get msgInfoUndoThisTurn => 'Annulla questo turno';

  @override
  String get msgInfoView => 'Visualizza';

  @override
  String get msgNoSystemSoundsFound =>
      'Nessun suono di sistema trovato su questo dispositivo.';

  @override
  String get msgNoValidFilesSelected => 'Nessun file valido selezionato';

  @override
  String get msgSomeSelectedFilesNotAttached =>
      'Non è stato possibile allegare alcuni file selezionati.';

  @override
  String get msgReadAloud => 'Leggi ad alta voce';

  @override
  String get msgReadAloudNotAvailable =>
      'La sintesi vocale non è disponibile su questo dispositivo.';

  @override
  String get msgSetupDebugCopied =>
      'Debug di configurazione di OpenCode copiato negli appunti';

  @override
  String get msgShareAsImage => 'Condividi come immagine';

  @override
  String get msgShareAsImageFailed =>
      'Impossibile condividere il messaggio come immagine.';

  @override
  String get msgShareAsImageSubject => 'Messaggio di CodeWalk';

  @override
  String get msgShareAsImageTooTall =>
      'Il messaggio è troppo lungo per essere condiviso come immagine.';

  @override
  String get msgStopReadAloud => 'Interrompi lettura';

  @override
  String get msgSystemSoundPickerUnavailable =>
      'Il selettore del suono di sistema non è disponibile su questa piattaforma.';

  @override
  String get msgUpdatedButRefreshFailed =>
      'Impostazione del server aggiornata, ma impossibile aggiornare i provider di chat.';

  @override
  String get msgVoiceInputUnavailable =>
      'L\'input vocale non è disponibile su questo dispositivo';

  @override
  String get notifAndroidBatteryOptimization =>
      'Ottimizzazione batteria Android';

  @override
  String get notifConversationUpdates => 'Aggiornamenti conversazione';

  @override
  String get notifNotificationsArriveReopening =>
      'Se le notifiche arrivano solo all\'apertura dell\'app, consenti a CodeWalk di funzionare senza ottimizzazione su questo dispositivo.';

  @override
  String get notifResponseRunningKeep =>
      'Quando una risposta è in esecuzione, mantieni attivo il tempo reale brevemente dopo aver chiuso l\'app.';

  @override
  String notifSelectedSoundLabel(String soundLabel) {
    return 'Selezionato: $soundLabel';
  }

  @override
  String get notificationAgentFinished =>
      'L\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'agente ha terminato la risposta corrente.';

  @override
  String get notificationConversationUpdates =>
      'Aggiornamenti della conversazione';

  @override
  String get notificationOpenToClear =>
      'Apri questa conversazione per cancellare le relative notifiche.';

  @override
  String get notificationSession => 'Sessione';

  @override
  String get notificationSoundLoadFailed =>
      'Caricamento dei suoni di sistema Android fallito';

  @override
  String get onboardingAIGeneratedTitles => 'Titoli generati da IA';

  @override
  String get onboardingAddServerLater =>
      'Puoi aggiungere un server in seguito in Impostazioni > Server.';

  @override
  String get onboardingAddedButHealthCheckFailed =>
      'Server aggiunto ma il controllo di integrità è fallito. Potrebbe essere ancora in fase di avvio.';

  @override
  String get onboardingAlmostInstallOpenCode =>
      'Ci sei quasi. Installa prima OpenCode, quindi connetti CodeWalk all\'URL del server.';

  @override
  String onboardingAppProviderLocalSetupLogsLength(int length, int length2) {
    return '$length righe di log di configurazione e $length2 eventi di configurazione sono disponibili nella schermata di debug di configurazione separata.';
  }

  @override
  String get onboardingAuthenticate => 'Autentica';

  @override
  String get onboardingAvailable => 'disponibile';

  @override
  String get onboardingAvailableOnlyDesktop =>
      'Disponibile solo su desktop (Linux/macOS/Windows).';

  @override
  String get onboardingBasicAuthTip =>
      'Abilita lautenticazione di base solo se il tuo server OpenCode è protetto da password.';

  @override
  String get onboardingChooseAnotherPath => 'Scegli un altro percorso';

  @override
  String get onboardingChooseHowToSetup =>
      'Scegli come configurare il tuo server';

  @override
  String get onboardingClear => 'Cancella';

  @override
  String get onboardingCloudflareAuthFailed =>
      'Autenticazione Cloudflare Access fallita.';

  @override
  String get onboardingCodeWalkAppOpenCode =>
      'CodeWalk è l\'applicazione. OpenCode è il motore a cui si connette.';

  @override
  String get onboardingConnectRunningServer =>
      'Connettiti a un server in esecuzione';

  @override
  String get onboardingConnectionIssue => 'Problema di connessione';

  @override
  String get onboardingConnectionSaved =>
      'Connessione al server salvata con successo.';

  @override
  String get onboardingConnectionTips => 'Suggerimenti per la connessione';

  @override
  String get onboardingConnectionUpdated =>
      'Connessione al server aggiornata con successo.';

  @override
  String get onboardingContinue => 'Continua';

  @override
  String get onboardingContinueServerURL => 'Continua all\'URL del server';

  @override
  String get onboardingCopyLoginURL => 'Copia URL di accesso';

  @override
  String get onboardingCouldNotVerify =>
      'Impossibile verificare la connessione al server.';

  @override
  String get onboardingDefaultURLEmulator =>
      'URL predefinito, loopback dell\'emulatore, autenticazione e supporto al debug.';

  @override
  String onboardingDesktopOnlyDiagnose(String appName) {
    return 'Solo desktop: $appName può diagnosticare, installare ed eseguire OpenCode per te.';
  }

  @override
  String get onboardingDetailedSetupEvents =>
      'Eventi di configurazione dettagliati sono stati acquisiti per la risoluzione dei problemi.';

  @override
  String get onboardingDonShowAgain =>
      'Don\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'t show again';

  @override
  String get onboardingDone => 'Fatto';

  @override
  String get onboardingEditServer => 'Modifica server';

  @override
  String get onboardingEditServerConnection => 'Modifica connessione server';

  @override
  String get onboardingEmulatorRemap =>
      'Sull\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'emulatore Android, localhost e 127.0.0.1 vengono rimappati automaticamente su 10.0.2.2.';

  @override
  String get onboardingEnterServerUrl =>
      'Inserisci l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'URL del server';

  @override
  String get onboardingExisting => 'Usa esistente';

  @override
  String get onboardingExplainInstallOpenCode =>
      'Spiega come installare OpenCode, avviare il server e connettersi da CodeWalk.';

  @override
  String get onboardingFailed => 'Fallito';

  @override
  String get onboardingGoodOptionDesktop => 'Buona prima opzione su desktop';

  @override
  String get onboardingHealthCheckFailedMayBeStarting =>
      'Controllo di integrità del server fallito. Potrebbe essere ancora in fase di avvio.';

  @override
  String get onboardingInstallBinary => 'Installa binario';

  @override
  String get onboardingInstallBun => 'Installa tramite Bun';

  @override
  String get onboardingInstallBunOpenCode => 'Installa Bun + OpenCode';

  @override
  String get onboardingInstallNpm => 'Installa tramite npm';

  @override
  String get onboardingInstallRunOpenCode =>
      'Installa ed esegui OpenCode direttamente da CodeWalk su desktop.';

  @override
  String get onboardingInvalidUrl => 'URL non valido';

  @override
  String get onboardingLabel => 'Etichetta (opzionale)';

  @override
  String get onboardingLabelHint => 'Il mio server';

  @override
  String onboardingLatestOutputAppProvider(String localServerLastOutput) {
    return 'Ultimo output: $localServerLastOutput';
  }

  @override
  String get onboardingLetCodeWalkSet =>
      'Lascia che CodeWalk esegua la configurazione locale';

  @override
  String get onboardingLocalServerSetup => 'Configurazione server locale';

  @override
  String get onboardingManagedLocalServer => 'Server locale gestito';

  @override
  String get onboardingManagedLocalServer2 =>
      'La modalità server locale gestito è disponibile solo per build desktop (Linux/macOS/Windows).';

  @override
  String onboardingNeedsOpenCodeServer(String appName) {
    return '$appName ha bisogno di un server OpenCode prima di poter aiutare con il tuo codice.';
  }

  @override
  String get onboardingNotAvailable => 'non disponibile';

  @override
  String get onboardingNotWritable => 'non scrivibile';

  @override
  String get onboardingOpenCode => 'Che cos\'è OpenCode?';

  @override
  String get onboardingOpenCodeRunningDevice =>
      'Ho già OpenCode in esecuzione su questo dispositivo o altrove nella mia rete.';

  @override
  String get onboardingOpenCodeRunsLocally =>
      'OpenCode viene eseguito localmente o su un server e alimenta le funzioni di programmazione dell\'IA in CodeWalk. Se OpenCode è già in esecuzione, connettiti ad esso. In caso contrario, seleziona uno dei percorsi di configurazione guidata di seguito.';

  @override
  String get onboardingOpenTailscaleLogin =>
      'Impossibile aprire l\'URL di accesso a Tailscale.';

  @override
  String get onboardingPassword => 'Password';

  @override
  String get onboardingPasswordRequired => 'Inserisci password';

  @override
  String get onboardingPickSetupPath =>
      'Scegli il percorso di configurazione che corrisponde alla tua attuale installazione di OpenCode.';

  @override
  String get onboardingPreconditionDirectoryNotWritable =>
      'La directory di installazione non è scrivibile. Controlla i permessi dell\'utente.';

  @override
  String get onboardingPreconditionInstallViaBunRecommendation =>
      'L\'installazione tramite Bun è consigliata dai manutentori di OpenCode.';

  @override
  String get onboardingPreconditionNetworkFailed =>
      'Accesso alla rete non riuscito. Controlla la connettività prima di installare OpenCode.';

  @override
  String get onboardingPreconditionNoRuntimeDetected =>
      'Nessun runtime rilevato. Installa direttamente il binario di OpenCode o avvia prima Bun.';

  @override
  String get onboardingPreconditionNodeNpmAvailable =>
      'Node + npm sono disponibili. Installa OpenCode tramite npm o installa Bun per la procedura consigliata.';

  @override
  String get onboardingPreconditionOpenCodeAlreadyAvailable =>
      'OpenCode è già disponibile. Puoi utilizzare immediatamente il comando rilevato.';

  @override
  String get onboardingPreconditionWindowsPathLagHint =>
      ' Su Windows, aggiorna i controlli dopo l\'installazione poiché gli aggiornamenti di PATH potrebbero richiedere tempo per applicarsi nelle app già aperte.';

  @override
  String get onboardingPreconditionWindowsWslRecommendation =>
      'Rilevata build di Windows. WSL è consigliato dalla documentazione di OpenCode, ma è possibile utilizzare npm install come alternativa.';

  @override
  String get onboardingReachable => 'raggiungibile';

  @override
  String get onboardingReady => 'Pronto';

  @override
  String get onboardingRecommendedOrderTry =>
      'Ordine consigliato: prova a installare Bun + OpenCode se desideri che CodeWalk configuri tutto automaticamente. Usa esistente se OpenCode è già installato.';

  @override
  String get onboardingRefreshChecks => 'Aggiorna controlli';

  @override
  String get onboardingRunDiagnosticsToVerify =>
      'Esegui la diagnostica per verificare i requisiti locali di OpenCode.';

  @override
  String get onboardingSaveAndTest => 'Salva e testa';

  @override
  String get onboardingServerConnectedReady =>
      'Il tuo server è connesso e pronto all\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'uso.';

  @override
  String get onboardingServerConnection => 'Connessione server';

  @override
  String get onboardingServerSettingsSaved =>
      'Le impostazioni del server sono state salvate e i controlli di integrità sono stati aggiornati.';

  @override
  String get onboardingServerSetup => 'Configurazione server';

  @override
  String get onboardingServerUpdated => 'Server aggiornato';

  @override
  String get onboardingServerUrl => 'URL del server';

  @override
  String get onboardingSetup => 'Configurazione';

  @override
  String get onboardingSetupWizard => 'Configurazione guidata';

  @override
  String get onboardingShowSetupSteps =>
      'Mostrami i passaggi di configurazione';

  @override
  String get onboardingShowSetupSteps2 => 'Mostra passaggi di configurazione';

  @override
  String get onboardingSkip => 'Salta per ora';

  @override
  String get onboardingSkipSetup => 'Saltare la configurazione?';

  @override
  String get onboardingStart => 'Avvia';

  @override
  String onboardingStartUsing(String appName) {
    return 'Inizia a usare $appName';
  }

  @override
  String get onboardingStarting => 'Avvio';

  @override
  String get onboardingStop => 'Interrompi';

  @override
  String get onboardingStopped => 'Fermato';

  @override
  String get onboardingStopping => 'Arresto';

  @override
  String onboardingSuggestedUrl(String url) {
    return 'URL del server OpenCode locale suggerito: $url';
  }

  @override
  String get onboardingTailscaleAdminApproval =>
      'Approvazione amministratore Tailscale richiesta';

  @override
  String get onboardingTailscaleAuthAfterSave =>
      'Tailscale si autenticherà dopo il salvataggio';

  @override
  String onboardingTailscaleAuthAfterSaveTest(String appName) {
    return 'Dopo aver salvato e testato questo server, $appName aprirà il login di Tailscale se questo dispositivo non è ancora autenticato.';
  }

  @override
  String get onboardingTailscaleConnected => 'Tailscale connesso';

  @override
  String get onboardingTailscaleConnecting => 'Connessione Tailscale in corso';

  @override
  String get onboardingTailscaleConnectionFailed =>
      'Connessione Tailscale fallita';

  @override
  String get onboardingTailscaleLoginRequired => 'Accesso Tailscale richiesto';

  @override
  String get onboardingTailscaleOpenLoginUrl =>
      'Apri l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'URL di login per aggiungere questo dispositivo alla tua tailnet. Se il browser non si è aperto, copia l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'URL qui sotto.';

  @override
  String get onboardingTailscaleUnsupported => 'Tailscale non supportato';

  @override
  String get onboardingTestConnection => 'Testa connessione';

  @override
  String get onboardingTesting => 'Test in corso...';

  @override
  String get onboardingUnreachable => 'non raggiungibile';

  @override
  String get onboardingUseBasicAuth => 'Usa autenticazione di base';

  @override
  String get onboardingUsername => 'Nome utente';

  @override
  String get onboardingUsernameRequired => 'Inserisci nome utente';

  @override
  String get onboardingUsesServerTitle =>
      'Uses your server\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'s title agent to name conversations';

  @override
  String get onboardingUsingDetectedCommand =>
      'Utilizzo del comando OpenCode rilevato.';

  @override
  String get onboardingViewSetupDebug => 'Visualizza debug configurazione';

  @override
  String onboardingWelcomeTo(String appName) {
    return 'Benvenuto in $appName';
  }

  @override
  String get onboardingWindowsTipInstalling =>
      'Suggerimento per Windows: dopo l\'installazione, fai clic su Aggiorna controlli. Se il rilevamento fallisce ancora, riapri CodeWalk per ricaricare le modifiche al PATH.';

  @override
  String get onboardingWritable => 'scrivibile';

  @override
  String get onboardingYoureAllSet => 'Sei a posto!';

  @override
  String get permissionAllowOnce => 'Consenti una volta';

  @override
  String get permissionAlways => 'Sempre';

  @override
  String get permissionBack => 'Indietro';

  @override
  String get permissionConfirmReject => 'Conferma rifiuto';

  @override
  String get permissionReject => 'Rifiuta';

  @override
  String get permissionReopen => 'Riapri';

  @override
  String get questionAnswerSelected => 'Nessuna risposta selezionata.';

  @override
  String get questionCommaSeparatedValues => 'Valori separati da virgole';

  @override
  String get questionQuestionGroupMarked =>
      'Gruppo di domande contrassegnato come rifiutato. Puoi continuare a chattare e riaprire questo gruppo in qualsiasi momento prima di confermare.';

  @override
  String get questionQuestionRequest => 'Richiesta domanda';

  @override
  String get questionQuestionsProvidedSubmit =>
      'Nessuna domanda fornita. È possibile inviare una risposta vuota.';

  @override
  String get questionReviewAnswersSubmitting =>
      'Esamina le tue risposte prima di inviarle.';

  @override
  String get quotaAuthCookie => 'Cookie di autenticazione';

  @override
  String get quotaConnect => 'Connetti';

  @override
  String get quotaForget => 'Dimentica';

  @override
  String get quotaOpenCodeGoConnectDescription =>
      'Connetti la dashboard di utilizzo per mostrare limiti mobili, settimanali e mensili.';

  @override
  String get quotaOpenCodeGoDetected => 'OpenCode Go rilevato';

  @override
  String get quotaOpenCodeGoNeedsReconnect =>
      'OpenCode Go deve essere riconnesso';

  @override
  String get quotaOpenCodeGoReconnectDescription =>
      'Aggiorna le credenziali della dashboard per ripristinare le barre di utilizzo.';

  @override
  String get quotaOpenCodeGoUsage => 'Utilizzo di OpenCode Go';

  @override
  String get quotaOpenDashboard => 'Apri dashboard di OpenCode';

  @override
  String get quotaPaceExplanation =>
      'Il ritmo prevede l\'utilizzo totale alla fine della finestra di limite corrente in base al tasso attuale.';

  @override
  String quotaPacePercent(String percent) {
    return 'Ritmo $percent%';
  }

  @override
  String get quotaRateLimits => 'Limiti di utilizzo';

  @override
  String get quotaReconnect => 'Riconnetti';

  @override
  String get quotaRefreshing => 'Aggiornamento...';

  @override
  String quotaResetsIn(String time) {
    return 'Si reimposta tra $time';
  }

  @override
  String get quotaSaving => 'Salvataggio in corso...';

  @override
  String get quotaWorkspaceId => 'ID area di lavoro';

  @override
  String get serverClearOAuth => 'Cancella OAuth';

  @override
  String get serverConnectionAttention =>
      'La connessione al server richiede attenzione.';

  @override
  String get serverHealthHealthy => 'Integro';

  @override
  String get serverHealthUnhealthy => 'Non integro';

  @override
  String get serverHealthUnknown => 'Sconosciuto';

  @override
  String get serverOAuthAuthFailed => 'Autenticazione OAuth fallita';

  @override
  String get serverOAuthChip => 'OAuth';

  @override
  String get serverOAuthNotSupported =>
      'Cloudflare Access OAuth non è supportato su questa piattaforma';

  @override
  String get serverReauthenticate => 'Riautentica';

  @override
  String get serverTailscaleChip => 'Tailscale';

  @override
  String get serversActive => 'Attivo';

  @override
  String get serversActiveServer => 'Server attivo';

  @override
  String get serversAddLeastOpenCode =>
      'Aggiungi almeno un server OpenCode per iniziare a utilizzare l\'app.';

  @override
  String get serversAddServer => 'Aggiungi server';

  @override
  String get serversCancel => 'Annulla';

  @override
  String get serversCannotActivateUnhealthy =>
      'Impossibile attivare un server non integro';

  @override
  String get serversCheckHealth => 'Controlla stato salute';

  @override
  String get serversClearDefault => 'Rimuovi predefinito';

  @override
  String serversCommandAppProviderLocalServerCommandPath(
    String localServerCommandPath,
  ) {
    return 'Comando: $localServerCommandPath';
  }

  @override
  String get serversCopy => 'Copia';

  @override
  String get serversDefault => 'Predefinito';

  @override
  String get serversDelete => 'Elimina';

  @override
  String get serversDeleteServer => 'Elimina server';

  @override
  String get serversDesktopModeExplanation =>
      'La modalità desktop può avviare e gestire `opencode serve` direttamente da CodeWalk.';

  @override
  String get serversEdit => 'Modifica';

  @override
  String get serversLocalOpenCodeServer => 'Server locale OpenCode';

  @override
  String get serversManagedModeAvailable =>
      'Questa modalità gestita è disponibile solo per build desktop (Linux/macOS/Windows).';

  @override
  String get serversNoServersFound => 'Nessun server trovato';

  @override
  String get serversRefreshHealth => 'Aggiorna stato salute';

  @override
  String serversRemoveProfileDisplayName(String displayName) {
    return 'Rimuovere \"$displayName\"?';
  }

  @override
  String get serversSearchActiveHint => 'Cerca server attivo';

  @override
  String get serversServersConfigured => 'Nessun server configurato';

  @override
  String get serversSetActive => 'Imposta come attivo';

  @override
  String get serversSetDefault => 'Imposta come predefinito';

  @override
  String get serversSetupDebug => 'Debug configurazione';

  @override
  String get serversSetupWizard => 'Configurazione guidata';

  @override
  String get serversTailscaleAdminApprovalRequired =>
      'Approvazione amministratore Tailscale richiesta';

  @override
  String get serversTailscaleAuthRequired =>
      'Autenticazione Tailscale richiesta';

  @override
  String get serversTailscaleConnectExplanation =>
      'Tailscale si connetterà quando questo profilo attivo viene utilizzato.';

  @override
  String get serversTailscaleConnected => 'Tailscale connesso';

  @override
  String get serversTailscaleConnecting => 'Tailscale in connessione';

  @override
  String get serversTailscaleConnectionFailed =>
      'Connessione Tailscale fallita';

  @override
  String get serversTailscaleDisconnected => 'Tailscale disconnesso';

  @override
  String get serversTailscaleLoginExplanation =>
      'Apri l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'URL di accesso Tailscale per aggiungere questo dispositivo al tuo tailnet.';

  @override
  String get serversTailscaleTrafficExplanation =>
      'Il traffico OpenCode per questo profilo attivo viene instradato attraverso Tailscale.';

  @override
  String get serversTailscaleUnsupported => 'Tailscale non supportato';

  @override
  String get serversUnhealthyActivateError =>
      'Questo server non è integro. Controlla lo stato o modifica le impostazioni prima di attivarlo.';

  @override
  String get sessionActionArchived => 'archiviata';

  @override
  String get sessionActionDeleted => 'eliminata';

  @override
  String get sessionActionForked => 'creato fork';

  @override
  String get sessionActionPinned => 'fissata';

  @override
  String get sessionActionUnarchived => 'non archiviata';

  @override
  String get sessionActionUnpinned => 'rimossa dai fissati';

  @override
  String get sessionArchive => 'Archivia';

  @override
  String get sessionCancelRename => 'Annulla rinomina';

  @override
  String sessionChildrenCount(int count) {
    return 'Sottoconversazioni: $count';
  }

  @override
  String get sessionCompactContext => 'Comprimi contesto';

  @override
  String get sessionCopyLink => 'Copia link';

  @override
  String get sessionDelete => 'Elimina';

  @override
  String sessionDeleteConfirm(String title) {
    return 'Vuoi davvero eliminare la conversazione \"$title\"? Questa azione non può essere annullata.';
  }

  @override
  String get sessionDeleteTitle => 'Elimina conversazione';

  @override
  String get sessionDiffChangedFile => 'File modificato';

  @override
  String get sessionDiffContentNotCaptured =>
      'Contenuto del file non acquisito dal server';

  @override
  String sessionDiffFilesChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file modificati',
      one: '1 file modificato',
    );
    return '$_temp0';
  }

  @override
  String sessionDiffFilesCount(int count) {
    return 'File diff: $count';
  }

  @override
  String sessionDiffLinesAddedRemoved(int added, int removed) {
    return '+$added righe aggiunte -$removed righe rimosse';
  }

  @override
  String sessionDiffLinesCollapsed(int count) {
    return '$count righe compresse — tocca per espandere';
  }

  @override
  String get sessionDiffLoading => 'Loading changed files…';

  @override
  String get sessionDiffReview => 'Esamina modifiche';

  @override
  String get sessionDiffSplit => 'Diviso';

  @override
  String get sessionDiffSummary => 'Riepilogo';

  @override
  String get sessionDiffUnified => 'Unificato';

  @override
  String get sessionExportAssistant => 'Assistente';

  @override
  String get sessionExportCanceled => 'Esportazione annullata';

  @override
  String get sessionExportDebugJson => 'Esporta JSON di debug';

  @override
  String get sessionExportDebugJsonErrorClipboard =>
      'Impossibile salvare; JSON di debug copiato negli appunti';

  @override
  String get sessionExportDebugJsonSaved =>
      'Esportazione JSON di debug salvata';

  @override
  String get sessionExportDebugJsonTitle =>
      'Esporta sessione come JSON di debug';

  @override
  String get sessionExportError => 'Errore:';

  @override
  String get sessionExportInput => 'Input:';

  @override
  String get sessionExportMarkdown => 'Esporta Markdown';

  @override
  String get sessionExportMarkdownErrorClipboard =>
      'Impossibile salvare; Markdown copiato negli appunti';

  @override
  String get sessionExportMarkdownSaved => 'Esportazione Markdown salvata';

  @override
  String get sessionExportMarkdownTitle => 'Esporta sessione come Markdown';

  @override
  String get sessionExportOutput => 'Output:';

  @override
  String get sessionExportUntitled => 'Sessione senza titolo';

  @override
  String get sessionExportUser => 'Utente';

  @override
  String get sessionFailedRename => 'Impossibile rinominare la conversazione';

  @override
  String get sessionFailedUpdateArchive =>
      'Impossibile aggiornare lo stato di archiviazione';

  @override
  String get sessionFailedUpdateSharing =>
      'Impossibile aggiornare lo stato di condivisione';

  @override
  String get sessionFork => 'Crea fork';

  @override
  String get sessionForkFailed => 'Fork della conversazione fallito';

  @override
  String get sessionForked => 'Conversazione biforcata';

  @override
  String sessionHasError(String title) {
    return '\"$title\" ha un errore.';
  }

  @override
  String sessionHasNewReply(String title) {
    return '\"$title\" ha una nuova risposta.';
  }

  @override
  String get sessionKeyboardShortcuts => 'Scorciatoie da tastiera';

  @override
  String sessionNeedsInput(String title) {
    return '\"$title\" richiede il tuo input.';
  }

  @override
  String get sessionNoCachedConversations => 'Nessuna conversazione in cache';

  @override
  String get sessionNoConversationsInProject =>
      'Nessuna conversazione in questo progetto.';

  @override
  String get sessionNotAvailable =>
      'La conversazione non è ancora disponibile per questo progetto';

  @override
  String get sessionOpenProjectToLoad =>
      'Apri il progetto per caricare le conversazioni.';

  @override
  String get sessionPin => 'Fissa';

  @override
  String get sessionRename => 'Rinomina';

  @override
  String get sessionRenameHint => 'Inserisci il nuovo nome della conversazione';

  @override
  String get sessionRenameTitle => 'Rinomina conversazione';

  @override
  String get sessionSaveTitle => 'Salva titolo';

  @override
  String get sessionShare => 'Condividi sessione';

  @override
  String get sessionShareAction => 'Condividi';

  @override
  String get sessionShareLinkCopied => 'Link di condivisione copiato';

  @override
  String get sessionShareLinkUnavailable =>
      'Link non disponibile per questa sessione';

  @override
  String get sessionShared => 'Conversazione condivisa';

  @override
  String get sessionSyncing => 'Sincronizzazione conversazioni...';

  @override
  String get sessionTitleHint => 'Titolo della conversazione';

  @override
  String get sessionUnarchive => 'Ripristina da archivio';

  @override
  String get sessionUnpin => 'Rimuovi';

  @override
  String get sessionUnshare => 'Non condividere più';

  @override
  String get sessionUnshareAction => 'Interrompi condivisione';

  @override
  String get sessionUnshared => 'Conversazione non più condivisa';

  @override
  String get sessionViewTasks => 'Vedi attività';

  @override
  String get settingsAboutCheckForUpdates => 'Controlla aggiornamenti';

  @override
  String get settingsAboutCheckOnOpen =>
      'Controlla aggiornamenti all\'apertura';

  @override
  String get settingsAboutCheckOnOpenDescription =>
      'Controlla automaticamente all\'avvio dell\'applicazione';

  @override
  String get settingsAboutChecking => 'Verifica in corso...';

  @override
  String get settingsAboutDescription =>
      'Versione, aggiornamenti e collegamenti';

  @override
  String get settingsAboutDismiss => 'Ignora';

  @override
  String settingsAboutDownloading(String percent) {
    return 'Download in corso... $percent%';
  }

  @override
  String get settingsAboutEraseAllData => 'Cancella tutti i dati e riavvia';

  @override
  String get settingsAboutInstallUpdate => 'Installa aggiornamento';

  @override
  String get settingsAboutInstalling => 'Installazione in corso...';

  @override
  String settingsAboutLatestVersion(String version) {
    return 'v$version è l\'ultima versione';
  }

  @override
  String get settingsAboutLoading => 'Caricamento in corso...';

  @override
  String get settingsAboutReplayChatTour => 'Riproduci tour della chat';

  @override
  String get settingsAboutReplayChatTourDescription =>
      'Chiudi le impostazioni e mostra la guida interattiva della chat';

  @override
  String get settingsAboutResetApp => 'Ripristina app';

  @override
  String get settingsAboutResetAppQuestion => 'Ripristinare l\'app?';

  @override
  String get settingsAboutResetAppWarning =>
      'Questo cancellerà tutti i server, le impostazioni e i dati memorizzati nella cache. Questa azione non può essere annullata.';

  @override
  String get settingsAboutRetryInstall => 'Riprova installazione';

  @override
  String get settingsAboutTapToCheck => 'Tocca per verificare nuove versioni';

  @override
  String get settingsAboutTitle => 'Informazioni';

  @override
  String get settingsAboutUpToDate =>
      'You\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'re up to date';

  @override
  String settingsAboutUpdateAvailable(String version) {
    return 'Aggiornamento disponibile: v$version';
  }

  @override
  String get settingsAboutUpdateInstalled =>
      'Aggiornamento installato. Riavvia l\'applicazione per applicarlo.';

  @override
  String settingsAboutUpdateVersionSummary(
    String installedVersion,
    String latestVersion,
  ) {
    return 'Attuale: $installedVersion; disponibile: v$latestVersion';
  }

  @override
  String get settingsAboutVersion => 'Versione';

  @override
  String settingsAboutVersionBuild(String buildNumber, String version) {
    return '$version (build $buildNumber)';
  }

  @override
  String get settingsAppearanceAmoledDark => 'Modalità scura AMOLED';

  @override
  String get settingsAppearanceAmoledDarkActive =>
      'Usa superfici completamente nere quando la modalità scura è attiva.';

  @override
  String get settingsAppearanceAmoledDarkInactive =>
      'Passa alla modalità scura per abilitare le superfici AMOLED.';

  @override
  String get settingsAppearanceBrandColor => 'Colore del brand';

  @override
  String get settingsAppearanceBrandColorDynamicBlocked =>
      'Disabilita i colori dello sfondo per scegliere un colore del brand.';

  @override
  String get settingsAppearanceBrandColorNormal =>
      'Scegli un colore iniziale per la tavolozza dell\'app.';

  @override
  String get settingsAppearanceBrandColorPresetBlocked =>
      'Passa a CodeWalk Classico per scegliere un colore del brand.';

  @override
  String get settingsAppearanceChatFontScale => 'Conversation text size';

  @override
  String get settingsAppearanceChatFontScaleDescription =>
      'Scale the chat message and composer text on top of the system text size.';

  @override
  String get settingsAppearanceCodeWalkClassic => 'CodeWalk Classico';

  @override
  String get settingsAppearanceComposerTips => 'Suggerimenti del composer';

  @override
  String get settingsAppearanceComposerTipsDescription =>
      'Mostra o nascondi i suggerimenti a rotazione mentre l\'assistente sta ragionando.';

  @override
  String get settingsAppearanceContrast => 'Contrasto';

  @override
  String get settingsAppearanceContrastDynamicBlocked =>
      'Disabilita i colori dello sfondo per regolare il contrasto.';

  @override
  String get settingsAppearanceContrastHigh => 'Elevato';

  @override
  String get settingsAppearanceContrastNormal =>
      'Regola il livello di contrasto dello schema colori.';

  @override
  String get settingsAppearanceContrastPresetBlocked =>
      'Passa a CodeWalk Classico per regolare il contrasto.';

  @override
  String get settingsAppearanceContrastReduced => 'Ridotto';

  @override
  String get settingsAppearanceDark => 'Scuro';

  @override
  String get settingsAppearanceDensity => 'Densità';

  @override
  String get settingsAppearanceDensityDense => 'Compatto';

  @override
  String get settingsAppearanceDensityDescription =>
      'Applica la spaziatura e la densità dei componenti in tutta l\'applicazione.';

  @override
  String get settingsAppearanceDensityExtraDense => 'Molto compatto';

  @override
  String get settingsAppearanceDensityExtraSpacious => 'Molto spazioso';

  @override
  String get settingsAppearanceDensityNormal => 'Normale';

  @override
  String get settingsAppearanceDensitySpacious => 'Spazioso';

  @override
  String get settingsAppearanceDescription =>
      'Densità e visibilità delle bolle sulla cronologia';

  @override
  String get settingsAppearanceFontSize => 'Text size';

  @override
  String get settingsAppearanceFontSizeDescription =>
      'Adjust the size of system text, conversation text, and terminal text.';

  @override
  String get settingsAppearanceLight => 'Chiaro';

  @override
  String get settingsAppearanceMathRendering => 'Rendering matematico';

  @override
  String get settingsAppearanceMathRenderingDescription =>
      'Mostra espressioni matematiche LaTeX come equazioni composte nei messaggi di chat.';

  @override
  String get settingsAppearanceNoPresets =>
      'Nessuna tavolozza predefinita trovata';

  @override
  String get settingsAppearanceOpenCodePresets => 'Preset OpenCode';

  @override
  String get settingsAppearancePresetHelper =>
      'Rispecchia l\'elenco dei temi integrati ufficiale di OpenCode Web.';

  @override
  String get settingsAppearancePresetNote =>
      'I colori del tema ora seguono il registro ufficiale di OpenCode Web e gestiscono anche le superfici markdown/codice.';

  @override
  String get settingsAppearancePresetPalette => 'Tavolozza predefinita';

  @override
  String get settingsAppearanceSearchPreset => 'Cerca tavolozza predefinita';

  @override
  String get settingsAppearanceSectionDescription =>
      'Regola la densità visiva e le superfici dei messaggi per il tuo flusso di lavoro.';

  @override
  String get settingsAppearanceSectionTitle => 'Aspetto';

  @override
  String get settingsAppearanceSystem => 'Sistema';

  @override
  String get settingsAppearanceSystemFontScale => 'System text size';

  @override
  String get settingsAppearanceSystemFontScaleDescription =>
      'Scale all text in the app shell, including menus, dialogs, and sidebars.';

  @override
  String get settingsAppearanceTaskList => 'Elenco attività';

  @override
  String get settingsAppearanceTaskListDescription =>
      'Mostra o nascondi il widget dell\'elenco attività della sessione.';

  @override
  String get settingsAppearanceTerminalFontSize => 'Terminal text size';

  @override
  String get settingsAppearanceTerminalFontSizeDescription =>
      'Resize the embedded terminal font. Applies immediately to running sessions.';

  @override
  String get settingsAppearanceTheme => 'Tema';

  @override
  String get settingsAppearanceThemeDescription =>
      'Scegli la modalità chiara, scura o di sistema, quindi mantieni la tavolozza classica di CodeWalk o passa a una predefinita di OpenCode.';

  @override
  String get settingsAppearanceVisualStyle => 'Stile visivo';

  @override
  String get settingsAppearanceVisualStyleDescription =>
      'Scegli lo stile classico o superfici più morbide e raffinate.';

  @override
  String get settingsAppearanceVisualStyleClassic => 'Classico';

  @override
  String get settingsAppearanceVisualStyleRefined => 'Rifinito';

  @override
  String get settingsAppearanceThinkingBubbles => 'Bolle di pensiero';

  @override
  String get settingsAppearanceThinkingBubblesDescription =>
      'Mostra o nascondi i blocchi di ragionamento nei messaggi dell\'assistente.';

  @override
  String get settingsAppearanceTitle => 'Aspetto';

  @override
  String get settingsAppearanceToolCallBubbles =>
      'Bolle di chiamata dello strumento';

  @override
  String get settingsAppearanceToolCallBubblesDescription =>
      'Mostra o nascondi le schede di esecuzione dello strumento nei messaggi dell\'assistente.';

  @override
  String get settingsAppearanceWallpaperColors => 'Usa i colori dello sfondo';

  @override
  String get settingsAppearanceWallpaperNormal =>
      'Estrai lo schema colori dallo sfondo del tuo dispositivo.';

  @override
  String get settingsAppearanceWallpaperPresetBlocked =>
      'Passa a CodeWalk Classico per utilizzare i colori dello sfondo.';

  @override
  String get settingsAppearanceWindowChrome => 'Schede della finestra';

  @override
  String get settingsAppearanceWindowChromeDescription =>
      'Scegli come combinare le schede di sessione e la barra del titolo sul desktop.';

  @override
  String get settingsAppearanceWindowChromeIntegrated => 'Schede integrate';

  @override
  String get settingsAppearanceWindowChromeIntegratedDescription =>
      'Le schede stanno in cima alla finestra e la barra del titolo di sistema è nascosta.';

  @override
  String get settingsAppearanceWindowChromeSystem => 'Decorazione di sistema';

  @override
  String get settingsAppearanceWindowChromeSystemDescription =>
      'Mantiene la barra del titolo nativa e mostra le schede sotto la barra dell’app.';

  @override
  String get settingsBack => 'Indietro';

  @override
  String get settingsBehaviorAutoupdateCaveat =>
      'Usa Informazioni per i controlli sulle versioni di CodeWalk. Questa impostazione rispecchia solo la configurazione ufficiale di `autoupdate` di OpenCode.';

  @override
  String get settingsBehaviorAutoupdateHelp =>
      'Controlla gli aggiornamenti di runtime di OpenCode a monte, non i controlli degli aggiornamenti dell\'app CodeWalk.';

  @override
  String get settingsBehaviorCellularDataSaver => 'Risparmio dati cellulare';

  @override
  String get settingsBehaviorChatRenderMode => 'Chat render mode';

  @override
  String get settingsBehaviorChatRenderModeBlock => 'Block';

  @override
  String get settingsBehaviorChatRenderModeBlockDescription =>
      'Hide live assistant text, reasoning, and tool cards until the current turn can be shown as one block.';

  @override
  String get settingsBehaviorChatRenderModeDescription =>
      'Choose whether assistant responses appear as they stream or reveal after the current turn settles.';

  @override
  String get settingsBehaviorChatRenderModeLive => 'Live';

  @override
  String get settingsBehaviorChatRenderModeLiveDescription =>
      'Show assistant text, reasoning, and tool activity as OpenCode streams events.';

  @override
  String get settingsBehaviorComposerSpellCheck => 'Composer spell check';

  @override
  String get settingsBehaviorComposerSpellCheckDescription =>
      'Use native platform spell check, suggestions, and autocorrect in the chat composer.';

  @override
  String get settingsBehaviorConfigDeferred =>
      'CodeWalk applicherà questa impostazione di OpenCode al termine della risposta corrente.';

  @override
  String settingsBehaviorConfigUpdateFailed(String field) {
    return 'Impossibile aggiornare il campo $field di OpenCode.';
  }

  @override
  String get settingsBehaviorConversationUsername =>
      'Nome utente della conversazione';

  @override
  String get settingsBehaviorConversationUsernameHelp =>
      'Nome visualizzato personalizzato mostrato nelle conversazioni al posto del nome utente di sistema.';

  @override
  String get settingsBehaviorDataSaverActive => 'Attivo ora sui dati mobili.';

  @override
  String get settingsBehaviorDataSaverCellularOnly =>
      'Si applica solo quando la connessione è cellulare/mobile.';

  @override
  String get settingsBehaviorDataSaverDescription =>
      'Riduce l\'uso automatico dei dati mobili interrompendo i download in background e limitando gli aggiornamenti automatici in primo piano.';

  @override
  String get settingsBehaviorDataSaverWaiting =>
      'In attesa della prossima finestra di sincronizzazione dei dati mobili.';

  @override
  String get settingsBehaviorDefaultAgent => 'Agente predefinito';

  @override
  String get settingsBehaviorDefaultAgentHelp =>
      'Agente primario utilizzato quando non viene scelto esplicitamente alcun agente.';

  @override
  String get settingsBehaviorDefaultModel => 'Modello predefinito';

  @override
  String get settingsBehaviorDefaultModelHelp =>
      'Condiviso tra i client OpenCode tramite la configurazione.';

  @override
  String get settingsBehaviorDescription =>
      'Impostazioni predefinite di OpenCode, provenienza e sicurezza di sincronizzazione del composer';

  @override
  String get settingsBehaviorEnableDataSaver =>
      'Abilita risparmio dati cellulare';

  @override
  String get settingsBehaviorMultiDeviceSync =>
      'Abilita la sincronizzazione multi-dispositivo sperimentale';

  @override
  String get settingsBehaviorMultiDeviceSyncDescription =>
      'Sincronizza la selezione del composer (agente/modello/variante) con la configurazione del server attivo.';

  @override
  String get settingsBehaviorMultiDeviceSyncWarning =>
      'Può interrompere le sessioni in corso quando si lavora in più di una sessione contemporaneamente.';

  @override
  String get settingsBehaviorNoAgents => 'Nessun agente trovato';

  @override
  String get settingsBehaviorNoModels => 'Nessun modello trovato';

  @override
  String get settingsBehaviorOpenCodeAutoupdate =>
      'Aggiornamento automatico di OpenCode';

  @override
  String get settingsBehaviorOpenCodeDefaults =>
      'Impostazioni predefinite basate su OpenCode';

  @override
  String get settingsBehaviorOpenCodeDefaultsDescription =>
      'Questi valori vengono scritti su `/config` nel server attivo e corrispondono alla configurazione condivisa ufficiale di OpenCode.';

  @override
  String get settingsBehaviorOpenCodeSnapshots => 'Istantanee di OpenCode';

  @override
  String get settingsBehaviorOpenCodeSnapshotsDescription =>
      'Mantieni abilitate le istantanee a monte supportate da git per l\'annullamento/ripristino e la cronologia di recupero.';

  @override
  String get settingsBehaviorPermissionDeferred =>
      'La modifica avanzata delle regole dei permessi rimane fuori dalle Impostazioni per ora ed è rimandata a un successivo lavoro di parità.';

  @override
  String get settingsBehaviorPermissionProvenance =>
      'Provenienza della gestione dei permessi';

  @override
  String get settingsBehaviorPermissionProvenanceDescription =>
      'La politica ufficiale dei permessi di OpenCode è configurata in `opencode.json` con regole consenti/chiedi/nega per strumento. CodeWalk mantiene le schede ufficiali di richiesta di permesso e aggiunge un\'eccezione approvata ADR-023 exception: l\'interruttore di approvazione automatica del composer risponde incondizionatamente con `Always` e `remember: true` per creare concessioni persistenti con ambito sessione, e mantiene attivo lo stesso percorso di continuità con ambito thread nel background worker di Android.';

  @override
  String get settingsBehaviorRefreshDefaults =>
      'Aggiorna impostazioni predefinite';

  @override
  String get settingsBehaviorSaveUsername => 'Salva nome utente';

  @override
  String get settingsBehaviorSearchAutoupdate =>
      'Cerca modalità di aggiornamento automatico';

  @override
  String get settingsBehaviorSearchDefaultAgent => 'Cerca agente predefinito';

  @override
  String get settingsBehaviorSearchDefaultModel => 'Cerca modello predefinito';

  @override
  String get settingsBehaviorSearchShareMode =>
      'Cerca modalità di condivisione';

  @override
  String get settingsBehaviorSearchSmallModel => 'Cerca modello piccolo';

  @override
  String get settingsBehaviorShareMode =>
      'Impostazione predefinita di condivisione di OpenCode';

  @override
  String get settingsBehaviorShareModeCaveat =>
      'Use the chat-level share action to publish one session now. This setting only changes OpenCode\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'s default sharing policy.';

  @override
  String get settingsBehaviorShareModeHelp =>
      'Controlla la configurazione ufficiale globale `share`, non il pulsante di condivisione per una singola chat.';

  @override
  String get settingsBehaviorSmallModel => 'Modello piccolo';

  @override
  String get settingsBehaviorSmallModelAutoFallback => 'Fallback automatico';

  @override
  String get settingsBehaviorSmallModelFallbackActive =>
      'Il fallback automatico di OpenCode è attivo perché `small_model` non è impostato.';

  @override
  String get settingsBehaviorSmallModelHelp =>
      'Utilizzato per attività leggere come la generazione del titolo.';

  @override
  String get settingsBehaviorSmallModelResetCaveat =>
      'Il ripristino di `small_model` al fallback automatico richiede comunque la modifica della configurazione all\'esterno dell\'app poiché gli aggiornamenti patch di `/config` non possono rimuovere le chiavi.';

  @override
  String get settingsBehaviorSnapshotCaveat =>
      'Questo controlla l\'archiviazione delle istantanee di OpenCode e il supporto per annulla/ripristina, non le istantanee della cache locale di CodeWalk.';

  @override
  String get settingsBehaviorTitle => 'Comportamento';

  @override
  String get settingsBehaviorUsernameFallback =>
      'OpenCode utilizza il nome utente di sistema perché `username` non è impostato.';

  @override
  String get settingsBehaviorUsernamePatchCaveat =>
      'Il ripristino di `username` al valore predefinito di sistema richiede comunque la modifica della configurazione all\'esterno dell\'app poiché gli aggiornamenti patch di `/config` non possono rimuovere le chiavi.';

  @override
  String get settingsConfigRefreshFailed =>
      'Impostazione del server aggiornata, ma impossibile aggiornare i provider di chat.';

  @override
  String get settingsConfigUpdateDeferred =>
      'CodeWalk applicherà questa impostazione di OpenCode al termine della risposta corrente.';

  @override
  String get settingsConversationUsername => 'Nome utente conversazione';

  @override
  String get settingsDefaultAgent => 'Agente predefinito';

  @override
  String get settingsDefaultModel => 'Modello predefinito';

  @override
  String get settingsLanguageDescription =>
      'Scegli la lingua utilizzata da CodeWalk. L\'impostazione predefinita di sistema segue la lingua del tuo dispositivo.';

  @override
  String get settingsLanguageEmptyText => 'Nessuna lingua trovata';

  @override
  String get settingsLanguageFieldHelper =>
      'Si applica immediatamente e persiste al riavvio.';

  @override
  String get settingsLanguageFieldLabel => 'Lingua dell\'applicazione';

  @override
  String get settingsLanguageSearchHint => 'Cerca lingue';

  @override
  String get settingsLanguageSystemDefault => 'Predefinita di sistema';

  @override
  String get settingsLanguageTitle => 'Lingua';

  @override
  String get settingsLogsDescription =>
      'Diagnostica di runtime e dati di risoluzione dei problemi';

  @override
  String get settingsLogsTitle => 'Registros';

  @override
  String get settingsNoAgentsFound => 'Nessun agente trovato';

  @override
  String get settingsNotificationsAgentSubtitle => 'Al termine di una risposta';

  @override
  String get settingsNotificationsAgentUpdates => 'Aggiornamenti dell\'agente';

  @override
  String get settingsNotificationsAnotherConversation =>
      'Un\'altra conversazione';

  @override
  String get settingsNotificationsAppInBackground => 'L\'app è in background';

  @override
  String get settingsNotificationsBackgroundAlerts =>
      'Avvisi in background Android';

  @override
  String get settingsNotificationsBackgroundBehavior =>
      'Comportamento in background';

  @override
  String get settingsNotificationsBackgroundBehaviorDescription =>
      'Scegli come si comporta CodeWalk quando l\'app non è in primo piano.';

  @override
  String get settingsNotificationsBackgroundDescription =>
      'Usa il monitoraggio in background a basso consumo di dati per il completamento delle risposte, le richieste di permessi, le domande e gli errori quando l\'app non è sullo schermo.';

  @override
  String get settingsNotificationsBackgroundToggle =>
      'Avvisi in background su Android';

  @override
  String get settingsNotificationsBackgroundToggleDescription =>
      'Disattiva tutti i controlli in background di Android e nascondi la notifica persistente del monitor.';

  @override
  String get settingsNotificationsBatteryDescription =>
      'Se notifiche arrivano solo all\'apertura dell\'app, consenti a CodeWalk di funzionare senza ottimizzazione su questo dispositivo.';

  @override
  String get settingsNotificationsBatteryDisabled =>
      'L\'ottimizzazione della batteria è disabilitata per CodeWalk.';

  @override
  String get settingsNotificationsBatteryEnabled =>
      'L\'ottimizzazione della batteria è abilitata. Alcuni dispositivi potrebbero ritardare gli avvisi in background.';

  @override
  String get settingsNotificationsBatteryOptimization =>
      'Ottimizzazione batteria Android';

  @override
  String get settingsNotificationsBatteryUnknown =>
      'Impossibile leggere ancora lo stato di ottimizzazione della batteria.';

  @override
  String get settingsNotificationsChooseAudioFile => 'Scegli file audio';

  @override
  String get settingsNotificationsChooseSystemSound =>
      'Scegli suono di sistema';

  @override
  String get settingsNotificationsCloseToTray =>
      'Riduci nella barra delle applicazioni';

  @override
  String get settingsNotificationsCloseToTrayDescription =>
      'Nascondi la finestra e continua l\'esecuzione nella barra di sistema.';

  @override
  String get settingsNotificationsDescription =>
      'Controlli di notifica e audio per categoria';

  @override
  String get settingsNotificationsDisableOptimization =>
      'Disabilita ottimizzazione';

  @override
  String get settingsNotificationsErrors => 'Errori';

  @override
  String get settingsNotificationsErrorsSubtitle =>
      'Quando una sessione segnala un errore';

  @override
  String get settingsNotificationsJustClose => 'Chiudi semplicemente';

  @override
  String get settingsNotificationsJustCloseDescription =>
      'Esci completamente dall\'applicazione.';

  @override
  String get settingsNotificationsKeepLive =>
      'Mantieni avvisi attivi per 3 min';

  @override
  String get settingsNotificationsKeepLiveDescription =>
      'Quando una risposta è già in esecuzione, mantieni attivo il tempo reale brevemente dopo aver chiuso l\'app.';

  @override
  String get settingsNotificationsLocal => 'Locale';

  @override
  String get settingsNotificationsMinimizeWhenClose =>
      'Riduci a icona alla chiusura';

  @override
  String get settingsNotificationsMinimizeWhenCloseDescription =>
      'Riduci a icona sulla barra delle applicazioni/dock e continua l\'esecuzione.';

  @override
  String get settingsNotificationsNoCondition =>
      'Se non viene selezionata alcuna condizione, gli avvisi sono consentiti in qualsiasi contesto.';

  @override
  String get settingsNotificationsNotify => 'Notifica';

  @override
  String get settingsNotificationsNotifyOnlyWhen => 'Notifica solo quando';

  @override
  String get settingsNotificationsOpenBatterySettings =>
      'Apri impostazioni batteria';

  @override
  String get settingsNotificationsPermissions => 'Permessi e domande';

  @override
  String get settingsNotificationsPermissionsSubtitle =>
      'Quando gli strumenti richiedono il tuo input';

  @override
  String get settingsNotificationsPreview => 'Anteprima';

  @override
  String get settingsNotificationsRefreshStatus => 'Aggiorna stato';

  @override
  String get settingsNotificationsSearchSoundType => 'Cerca tipo di suono';

  @override
  String get settingsNotificationsSectionDescription =>
      'Controlla quando vengono visualizzati gli avvisi e quando possono riprodurre audio.';

  @override
  String get settingsNotificationsSectionTitle => 'Notifiche';

  @override
  String settingsNotificationsSelectedSound(String label) {
    return 'Selezionato: $label';
  }

  @override
  String get settingsNotificationsServer => 'Server';

  @override
  String get settingsNotificationsSound => 'Suono';

  @override
  String get settingsNotificationsSoundBuiltInAlert => 'Avviso integrato';

  @override
  String get settingsNotificationsSoundBuiltInClick => 'Clic integrato';

  @override
  String get settingsNotificationsSoundOff => 'Disattivato';

  @override
  String get settingsNotificationsSoundOnlyWhen => 'Suona solo quando';

  @override
  String get settingsNotificationsSoundPickAudioFile => 'Scegli file audio';

  @override
  String get settingsNotificationsSoundPickFromSystem => 'Scegli dal sistema';

  @override
  String get settingsNotificationsSoundSystemDefault =>
      'Predefinito di sistema';

  @override
  String get settingsNotificationsSoundType => 'Tipo di suono';

  @override
  String get settingsNotificationsSyncInfo =>
      'Alcuni interruttori di attivazione/disattivazione di categoria sono sincronizzati da /config sul server attivo.';

  @override
  String get settingsNotificationsSyncInfoLocal =>
      'Il server corrente non espone gli interruttori di notifica in /config; i valori locali sono attivi.';

  @override
  String get settingsNotificationsSystemSoundPickerTitle =>
      'Scegli suono di sistema';

  @override
  String get settingsNotificationsTitle => 'Notifiche';

  @override
  String get settingsNotificationsWhenClosing => 'Alla chiusura della finestra';

  @override
  String get settingsOpenCodeAutoUpdate => 'Auto-aggiornamento OpenCode';

  @override
  String get settingsOpenCodeSharingDefault =>
      'Predefinito condivisione OpenCode';

  @override
  String get settingsReadAloudEnabled => 'Leggi ad alta voce';

  @override
  String get settingsReadAloudEnabledDescription =>
      'Mostra un pulsante per leggere ad alta voce i messaggi dell\'assistente.';

  @override
  String get settingsReadAloudPitch => 'Tonalità';

  @override
  String get settingsReadAloudPitchDescription =>
      'Regola la tonalità della voce.';

  @override
  String get settingsReadAloudSectionDescription =>
      'Leggi ad alta voce le risposte dell\'assistente. Configura velocità, tonalità e voce.';

  @override
  String get settingsReadAloudSectionTitle => 'Sintesi vocale';

  @override
  String get settingsReadAloudSpeed => 'Velocità';

  @override
  String get settingsReadAloudSpeedDescription =>
      'Regola la velocità del parlato.';

  @override
  String get settingsReadAloudVoice => 'Voce';

  @override
  String get settingsReadAloudVoiceHint =>
      'Seleziona una voce per la lettura ad alta voce.';

  @override
  String get settingsSearchAutoUpdateMode =>
      'Cerca modalità auto-aggiornamento';

  @override
  String get settingsSearchDefaultAgent => 'Cerca agente predefinito';

  @override
  String get settingsSearchDefaultModel => 'Cerca modello predefinito';

  @override
  String get settingsSearchSharingMode => 'Cerca modalità condivisione';

  @override
  String get settingsSearchSmallModel => 'Cerca modello piccolo';

  @override
  String get settingsServersActive => 'Attivo';

  @override
  String get settingsServersChooseActive => 'Scegli server attivo';

  @override
  String get settingsServersDefault => 'Predefinito';

  @override
  String get settingsServersDescription =>
      'Server OpenCode e instradamento dello stato di salute';

  @override
  String get settingsServersTitle => 'Server';

  @override
  String get settingsSessionAttentionSize => 'Dimensione della bolla';

  @override
  String get settingsSessionAttentionSizeExtraLarge => 'Molto grande';

  @override
  String get settingsSessionAttentionSizeExtraSmall => 'Molto piccolo';

  @override
  String get settingsSessionAttentionSizeLarge => 'Grande';

  @override
  String get settingsSessionAttentionSizeSmall => 'Piccolo';

  @override
  String get settingsSessionAttentionSizeStandard => 'Standard';

  @override
  String get settingsSetupWizard => 'Configurazione guidata';

  @override
  String get settingsShortcutsDescription =>
      'Associazioni di tasti dell\'applicazione portatile';

  @override
  String get settingsShortcutsEdit => 'Modifica scorciatoia';

  @override
  String get settingsShortcutsKeyboard => 'Scorciatoie da tastiera';

  @override
  String get settingsShortcutsReset => 'Ripristina scorciatoia';

  @override
  String get settingsShortcutsSearch => 'Cerca scorciatoie';

  @override
  String get settingsShortcutsTitle => 'Scorciatoie';

  @override
  String get settingsSmallModel => 'Modello piccolo';

  @override
  String get settingsSmallModelResetExplanation =>
      'Il ripristino di `small_model` al fallback automatico richiede comunque la modifica della configurazione all\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'esterno dell\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'app perché gli aggiornamenti patch `/config` non possono rimuovere chiavi.';

  @override
  String get settingsSmallModelUnsetExplanation =>
      'Il fallback automatico di OpenCode è attivo perché `small_model` non è impostato.';

  @override
  String get settingsSoundPickerNotAvailable =>
      'Il selettore dei suoni di sistema non è disponibile su questa piattaforma.';

  @override
  String get settingsSpeechDescription =>
      'Motore, timeout di silenzio e opzioni del modello';

  @override
  String get settingsSpeechRefreshStatus => 'Aggiorna stato';

  @override
  String settingsSpeechSilenceTimeout(String value) {
    return 'Timeout di silenzio: ${value}s';
  }

  @override
  String get settingsSpeechTitle => 'Trascrizione vocale';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsUsernameClearHint =>
      'La rimozione del nome utente della conversazione OpenCode richiede comunque la modifica della configurazione all\'esterno dell\'app.';

  @override
  String get settingsUsernameEnterHint =>
      'Inserisci un nome utente per salvare un nome personalizzato per la conversazione OpenCode.';

  @override
  String get settingsUsernameResetExplanation =>
      'Il ripristino di `username` al valore predefinito di sistema richiede comunque la modifica della configurazione all\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'esterno dell\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'app perché gli aggiornamenti patch `/config` non possono rimuovere chiavi.';

  @override
  String get settingsUsernameUnsetExplanation =>
      'OpenCode usa il nome utente di sistema perché `username` non è impostato.';

  @override
  String get setupDebugBun => 'Bun';

  @override
  String get setupDebugBun2 => 'Bun';

  @override
  String get setupDebugCapturedSetupDetails =>
      'Nessun dettaglio di configurazione ancora acquisito';

  @override
  String get setupDebugCapturedSetupLogs => 'Log di configurazione acquisiti';

  @override
  String get setupDebugClear => 'Cancella debug configurazione';

  @override
  String get setupDebugClearSetupDebug => 'Cancella debug configurazione';

  @override
  String get setupDebugCodeWalkCaptureEnough =>
      'Se CodeWalk non ha acquisito abbastanza contesto, controlla direttamente i log ufficiali e gli endpoint di integrità di OpenCode:';

  @override
  String get setupDebugCommandPath => 'Percorso del comando';

  @override
  String get setupDebugCommandPath2 => 'Percorso del comando';

  @override
  String get setupDebugCopy => 'Copia debug configurazione';

  @override
  String get setupDebugCopySetupDebug => 'Copia debug configurazione';

  @override
  String get setupDebugCurrentStatus => 'Stato attuale';

  @override
  String get setupDebugDiagnosticsLoading =>
      'La diagnostica è ancora in caricamento.';

  @override
  String get setupDebugEnvironment => 'Diagnostica dell\'ambiente';

  @override
  String get setupDebugEnvironmentDiagnostics => 'Diagnostica dell\'ambiente';

  @override
  String get setupDebugFocusedOpenCodeSetup =>
      'Configurazione mirata di OpenCode';

  @override
  String get setupDebugInstallDir => 'Directory di installazione';

  @override
  String get setupDebugInstallDirectory => 'Directory di installazione';

  @override
  String get setupDebugLatestLocalServer => 'Ultimo output del server locale';

  @override
  String get setupDebugLogs => 'Log di configurazione acquisiti';

  @override
  String get setupDebugManual => 'Risoluzione manuale dei problemi';

  @override
  String get setupDebugManualTroubleshooting =>
      'Risoluzione manuale dei problemi';

  @override
  String get setupDebugNetwork => 'Rete';

  @override
  String get setupDebugNetwork2 => 'Rete';

  @override
  String get setupDebugNoDetails =>
      'Nessun dettaglio di configurazione ancora acquisito';

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
      'Debug di configurazione di OpenCode';

  @override
  String get setupDebugPlatform => 'Piattaforma';

  @override
  String get setupDebugPlatform2 => 'Piattaforma';

  @override
  String get setupDebugRunDiagnosticsTry =>
      'Esegui la diagnostica, prova un metodo di installazione o tenta un flusso di configurazione per acquisire qui i dettagli di risoluzione dei problemi specifici di OpenCode.';

  @override
  String get setupDebugScreenCoversOpenCode =>
      'Questa schermata copre solo l\'installazione di OpenCode, la diagnostica e la risoluzione dei problemi di configurazione locale. Utilizza i log dell\'app per i problemi generali di runtime di CodeWalk.';

  @override
  String get setupDebugServerOutput => 'Ultimo output del server locale';

  @override
  String get setupDebugStatus => 'Stato attuale';

  @override
  String setupDebugTimeEntrySource(String source, String time) {
    return '$time - $source';
  }

  @override
  String get setupDebugTimeline => 'Cronologia';

  @override
  String get setupDebugTimeline2 => 'Cronologia';

  @override
  String get setupDebugTitle => 'Configurazione mirata di OpenCode';

  @override
  String get setupDebugWSL => 'WSL';

  @override
  String get setupDebugWsl => 'WSL';

  @override
  String get shortcutCloseApp => 'Chiudi scheda/applicazione';

  @override
  String get shortcutCloseAppDesc =>
      'Chiudi la scheda della sessione corrente quando disponibile; altrimenti chiudi l\'app secondo il comportamento della piattaforma';

  @override
  String get shortcutFocusCloseDrawer => 'Focus/chiudi pannello';

  @override
  String get shortcutFocusCloseDrawerDesc =>
      'Focus sull\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'input per impostazione predefinita, o chiudi il pannello se aperto';

  @override
  String get shortcutFocusInput => 'Focus sullinput';

  @override
  String get shortcutFocusInputDesc =>
      'Sposta il focus sull\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'input di testo';

  @override
  String get shortcutGroupApplication => 'Applicazione';

  @override
  String get shortcutGroupGeneral => 'Generale';

  @override
  String get shortcutGroupModelAndAgent => 'Modello e agente';

  @override
  String get shortcutGroupNavigation => 'Navigazione';

  @override
  String get shortcutGroupPrompt => 'Prompt';

  @override
  String get shortcutGroupSession => 'Sessione';

  @override
  String get shortcutNewConversation => 'Nuova conversazione';

  @override
  String get shortcutNewConversationDesc => 'Crea una nuova sessione di chat';

  @override
  String get shortcutNextAgent => 'Prossimo agente';

  @override
  String get shortcutNextAgentDesc => 'Cicla al prossimo agente disponibile';

  @override
  String get shortcutNextRecentModel => 'Prossimo modello recente';

  @override
  String get shortcutNextRecentModelDesc =>
      'Cicla tra i modelli usati recentemente';

  @override
  String get shortcutNextVariant => 'Prossima variante';

  @override
  String get shortcutNextVariantDesc =>
      'Cicla tra le varianti di modello disponibili';

  @override
  String get shortcutOpenSettings => 'Apri impostazioni';

  @override
  String get shortcutOpenSettingsDesc => 'Apri la pagina delle impostazioni';

  @override
  String get shortcutPreviousAgent => 'Agente precedente';

  @override
  String get shortcutPreviousAgentDesc =>
      'Cicla all\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'agente precedente disponibile';

  @override
  String get shortcutQuickOpenFiles => 'Apertura rapida file';

  @override
  String get shortcutQuickOpenFilesDesc => 'Apri la ricerca rapida dei file';

  @override
  String get shortcutQuitApp => 'Esci dallapplicazione';

  @override
  String get shortcutQuitAppDesc =>
      'Forza l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'uscita dall\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'app';

  @override
  String get shortcutRefreshData => 'Aggiorna dati';

  @override
  String get shortcutRefreshDataDesc => 'Aggiorna i dati della chat corrente';

  @override
  String get shortcutStopResponse => 'Ferma risposta';

  @override
  String get shortcutStopResponseDesc =>
      'Ferma risposta attiva (durante la risposta)';

  @override
  String get shortcutToggleVoiceInput => 'Attiva/disattiva input vocale';

  @override
  String get shortcutToggleVoiceInputDesc =>
      'Avvia o ferma il dettato vocale nelleditor';

  @override
  String get shortcutsApply => 'Applica';

  @override
  String shortcutsConflictConflict(String conflict) {
    return 'Conflitto con $conflict';
  }

  @override
  String get shortcutsKeyboardShortcuts => 'Scorciatoie da tastiera';

  @override
  String get shortcutsReset => 'Ripristina tutto';

  @override
  String get shortcutsSearchEditBindings =>
      'Cerca, modifica associazioni e risolvi i conflitti prima di salvare.';

  @override
  String shortcutsSetShortcutWidget(String label) {
    return 'Imposta scorciatoia: $label';
  }

  @override
  String get shortcutsTheseBindingsStored =>
      'Queste associazioni sono memorizzate in CodeWalk per il runtime dell\'app corrente e non modificano le associazioni di tasti `tui.json` di OpenCode.';

  @override
  String get speechAutoStopSilence =>
      'Timeout di silenzio con arresto automatico';

  @override
  String get speechChooseRecognitionEngine =>
      'Scegli il motore di riconoscimento vocale, il timeout di silenzio e le opzioni del modello.';

  @override
  String speechDesktopOnly(String service) {
    return '$service è disponibile solo su desktop.';
  }

  @override
  String get speechDownload => 'Scarica';

  @override
  String get speechEngine => 'Motore';

  @override
  String get speechInstalledLanguages => 'Lingue installate';

  @override
  String get speechListeningStopsAutomatically =>
      'L\'ascolto si interrompe automaticamente dopo questo numero di secondi di silenzio.';

  @override
  String get speechMicPermissionDisabled =>
      'L\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'autorizzazione del microfono è disabilitata.';

  @override
  String speechModelFilesIncomplete(String service) {
    return 'I file del modello di $service sono incompleti.';
  }

  @override
  String get speechMoonshine => 'Moonshine';

  @override
  String get speechMoonshineModelsDesktop => 'Modelli Moonshine (desktop)';

  @override
  String get speechMoonshineStaysDownloadable =>
      'Moonshine rimane scaricabile ed esterno al pacchetto dell\'app. Scegli un modello per questo dispositivo desktop e rimuovilo in seguito se desideri recuperare spazio.';

  @override
  String get speechNative => 'Nativo';

  @override
  String get speechNativeSTTDisabled =>
      'L\'STT nativo è disabilitato su Linux in questa app. Parakeet è il motore predefinito per le nuove installazioni.';

  @override
  String get speechNativeSTTWorks =>
      'On Windows, CodeWalk uses local on-device speech recognition through its WASAPI microphone backend. Native Windows speech recognition is disabled for stability.';

  @override
  String get speechNativeStartsFaster =>
      'L\'STT nativo si avvia più velocemente. Sherpa viene eseguito interamente sul dispositivo con una configurazione più pesante e un controllo più approfondito del modello.';

  @override
  String get speechOpenMicrophoneSettings => 'Open microphone settings';

  @override
  String get speechOpenSpeechPrivacy => 'Open speech privacy';

  @override
  String get speechOpenSpeechSettings => 'Open speech settings';

  @override
  String get speechParakeet => 'Parakeet';

  @override
  String get speechParakeetModelsDesktop => 'Modelli Parakeet (desktop)';

  @override
  String get speechParakeetStaysDownloadable =>
      'Parakeet rimane scaricabile ed esterno al pacchetto dell\'app. Attualmente espone un modello multilingue ottimizzato per 25 lingue europee.';

  @override
  String get speechPickLanguagePacks =>
      'Scegli i pacchetti di lingua e scarica/rimuovi i modelli per il riconoscimento sul dispositivo.';

  @override
  String get speechRemove => 'Rimuovi';

  @override
  String speechRuntimeFailed(String service) {
    return 'Inizializzazione del runtime di $service fallita.';
  }

  @override
  String get speechSelectSherpaAbove =>
      'Seleziona Sherpa sopra per gestire i pacchetti di lingua e scaricare i modelli.';

  @override
  String get speechSenseVoice => 'SenseVoice';

  @override
  String get speechSenseVoiceModelsDesktop => 'Modelli SenseVoice (desktop)';

  @override
  String get speechSenseVoiceStaysDownloadable =>
      'SenseVoice rimane scaricabile ed esterno al pacchetto dell\'app. È l\'opzione desktop più potente qui per cinese, cantonese, giapponese, coreano e inglese.';

  @override
  String get speechSherpa => 'Sherpa';

  @override
  String get speechSherpaExperimentalFail =>
      'Sherpa è sperimentale e può fallire su alcuni dispositivi. Preferisci Nativo se desideri il comportamento più stabile.';

  @override
  String get speechSherpaModelsLinux => 'Modelli Sherpa (Linux)';

  @override
  String get speechSpeechText => 'Trascrizione vocale';

  @override
  String speechUnavailableOnPlatform(String service) {
    return 'Il parlato di $service non è disponibile su questa piattaforma.';
  }

  @override
  String get speechWindowsSetupHint =>
      'Windows voice input uses CodeWalk WASAPI capture with on-device models. Keep microphone access for desktop apps enabled; the buttons below open Windows settings for troubleshooting.';

  @override
  String get statusConnected => 'Connesso';

  @override
  String get statusDelayed => 'Ritardato';

  @override
  String get statusFailed => 'Fallito';

  @override
  String get statusOffline => 'Offline';

  @override
  String get statusOnline => 'Online';

  @override
  String get statusReconnecting => 'Riconnessione';

  @override
  String get statusStarting => 'Avvio';

  @override
  String get statusStopped => 'Fermato';

  @override
  String get statusStopping => 'Arresto';

  @override
  String get statusSyncDelayed => 'Sincronizzazione ritardata';

  @override
  String get tailscaleNoPeers => 'Nessun nodo peer trovato';

  @override
  String get tailscaleNotSupportedOnPlatform =>
      'Tailscale non è supportato su questa piattaforma.';

  @override
  String get tailscaleNotSupportedOnWindows =>
      'Tailscale non è supportato su Windows.';

  @override
  String get tailscalePeerOffline => 'offline';

  @override
  String get tailscaleSelectPeer => 'Seleziona un nodo peer Tailscale';

  @override
  String get tailscaleWaitingAdminApproval =>
      'Questo nodo Tailscale è in attesa dell\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'approvazione dell\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'amministratore.';

  @override
  String get terminalClose => 'Chiudi terminale';

  @override
  String terminalConnectingTo(String serverName) {
    return 'Connessione al terminale di $serverName...';
  }

  @override
  String terminalConnectionFailed(String error) {
    return 'Connessione al terminale fallita: $error';
  }

  @override
  String get terminalDisconnected => 'Terminale scollegato.';

  @override
  String terminalEmbeddedUnavailable(String serverName) {
    return 'Il terminale integrato non è ancora disponibile su questo runtime. Continua a usare la modalità shell del compositore per comandi singoli o apri il terminale da un runtime dell\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'app CodeWalk supportato per $serverName.';
  }

  @override
  String get terminalExtraKeyAlt => 'Tasto Alt';

  @override
  String get terminalExtraKeyArrowDown => 'Freccia giù';

  @override
  String get terminalExtraKeyArrowLeft => 'Freccia sinistra';

  @override
  String get terminalExtraKeyArrowRight => 'Freccia destra';

  @override
  String get terminalExtraKeyArrowUp => 'Freccia su';

  @override
  String get terminalExtraKeyControl => 'Tasto Ctrl';

  @override
  String get terminalExtraKeyEscape => 'Tasto Esc';

  @override
  String get terminalExtraKeyTab => 'Tasto Tab';

  @override
  String get terminalExtraKeys => 'Tasti aggiuntivi del terminale';

  @override
  String get terminalHide => 'Nascondi terminale';

  @override
  String get terminalMaximize => 'Massimizza';

  @override
  String get terminalMinimize => 'Riduci a icona terminale';

  @override
  String get terminalNotAvailableYet =>
      'Il terminale integrato non è ancora disponibile su questo runtime.';

  @override
  String get terminalOpen => 'Apri terminale';

  @override
  String get terminalOpenInfo => 'Apri info terminale';

  @override
  String get terminalOpenProjectFirst =>
      'Apri una cartella di progetto prima di avviare il terminale del server.';

  @override
  String get terminalOpenToConnect =>
      'Apri il Terminale per connetterti al terminale del progetto del server.';

  @override
  String get terminalReconnect => 'Riconnetti terminale';

  @override
  String get terminalRestoreSize => 'Ripristina dimensioni';

  @override
  String get terminalSelectServer =>
      'Seleziona un server attivo prima di aprire il Terminale.';

  @override
  String get terminalSessionClosed => 'Sessione terminale chiusa.';

  @override
  String get terminalTerminal => 'Terminale';

  @override
  String get terminalTitle => 'Terminale';

  @override
  String get terminalTryAgain => 'Riprova';

  @override
  String get toolAwaitingInput => 'In attesa di input';

  @override
  String get toolEditing => 'Modifica in corso';

  @override
  String get toolEditingFiles => 'Modifica file in corso';

  @override
  String get toolFinding => 'Ricerca in corso';

  @override
  String get toolFindingFiles => 'Ricerca file in corso';

  @override
  String get toolPresentationAwaitingInput => 'In attesa di input';

  @override
  String get toolPresentationEditing => 'Modifica in corso';

  @override
  String get toolPresentationEditingFiles => 'Modifica file in corso';

  @override
  String get toolPresentationFinding => 'Ricerca in corso';

  @override
  String get toolPresentationFindingFiles => 'Ricerca file in corso';

  @override
  String get toolPresentationReading => 'Lettura in corso';

  @override
  String get toolPresentationReadingFile => 'Lettura file in corso';

  @override
  String get toolPresentationRunning => 'In esecuzione';

  @override
  String get toolPresentationRunningCommand => 'Esecuzione comando in corso';

  @override
  String toolPresentationRunningTool(String toolName) {
    return 'Esecuzione di $toolName';
  }

  @override
  String get toolPresentationSearching => 'Ricerca in corso';

  @override
  String get toolPresentationSearchingCode => 'Ricerca codice in corso';

  @override
  String get toolPresentationSearchingWeb => 'Ricerca sul web in corso';

  @override
  String get toolPresentationTool => 'Strumento';

  @override
  String get toolPresentationUpdatingTaskList =>
      'Aggiornamento elenco attività';

  @override
  String get toolPresentationUpdatingTasks => 'Aggiornamento attività in corso';

  @override
  String get toolPresentationWaitingInput => 'In attesa del tuo input';

  @override
  String get toolPresentationWriting => 'Scrittura in corso';

  @override
  String get toolPresentationWritingFile => 'Scrittura file in corso';

  @override
  String get toolReading => 'Lettura in corso';

  @override
  String get toolReadingFile => 'Lettura file in corso';

  @override
  String get toolRunning => 'In esecuzione';

  @override
  String get toolRunningCommand => 'Esecuzione comando in corso';

  @override
  String get toolRunningTask => 'Esecuzione attività in corso';

  @override
  String get toolSearching => 'Ricerca in corso';

  @override
  String get toolSearchingCode => 'Ricerca codice in corso';

  @override
  String get toolSearchingWeb => 'Ricerca sul web in corso';

  @override
  String get toolUpdatingTaskList => 'Aggiornamento elenco attività';

  @override
  String get toolUpdatingTasks => 'Aggiornamento attività in corso';

  @override
  String get toolWaitingForInput => 'In attesa del tuo input';

  @override
  String get toolWriting => 'Scrittura in corso';

  @override
  String get toolWritingFile => 'Scrittura file in corso';

  @override
  String get tourBack => 'Indietro';

  @override
  String get tourSkip => 'Salta';

  @override
  String get trayQuit => 'Esci';

  @override
  String get trayShow => 'Mostra';

  @override
  String get useOAuthCloudflareAccess => 'Usa OAuth (Cloudflare Access)';

  @override
  String get useOAuthCloudflareAccessSubtitle =>
      'Apre un browser per Cloudflare Access Managed OAuth.';

  @override
  String get useOAuthCloudflareAccessUnsupported =>
      'Cloudflare Access OAuth non è disponibile su questa piattaforma. Usa invece l\'autenticazione di base.';

  @override
  String get useTailscale => 'Usa Tailscale';

  @override
  String get useTailscaleSubtitle =>
      'Instrada il traffico attraverso la rete Tailscale senza una VPN di sistema.';

  @override
  String get useTailscaleUnsupported =>
      'Tailscale non è supportato su questa piattaforma.';

  @override
  String get utilityTitle => 'Utilità';

  @override
  String get workspaceBrowseDirs => 'Sfoglia directory';

  @override
  String get workspaceChooseFolderOpen =>
      'Scegli una cartella qualsiasi da aprire come contesto del progetto.';

  @override
  String workspaceCloseProject(String project) {
    return 'Chiudi $project';
  }

  @override
  String get workspaceClosedProjects => 'Progetti chiusi';

  @override
  String workspaceCurrentDirectory(String path) {
    return 'Directory corrente: $path';
  }

  @override
  String get workspaceFilterDirs => 'Filtra directory';

  @override
  String get workspaceOpenFolder => 'Apri cartella';

  @override
  String get workspaceOpenProjectFolder => 'Apri cartella del progetto';

  @override
  String get workspaceOpenProjects => 'Progetti aperti';

  @override
  String get workspaceProjectDirectory => 'Directory del progetto';

  @override
  String get workspaceProjectHint => '/repo/my-project';

  @override
  String workspaceRemoveFromHistory(String name) {
    return 'Rimuovi $name dalla cronologia';
  }

  @override
  String get settingsSessionAttentionTitle => 'Attenzione sessioni';

  @override
  String get settingsSessionAttentionDescription =>
      'Mostra lo stato delle sessioni radice in una bolla o in un pannello facoltativo.';

  @override
  String get settingsSessionAttentionOff => 'Disattivato';

  @override
  String get settingsSessionAttentionBubble => 'Bolla';

  @override
  String get settingsSessionAttentionPanel => 'Pannello';

  @override
  String get settingsSessionAttentionPrivacy =>
      'Su Android, l’attivazione avvia un servizio persistente in primo piano. Il testo delle risposte viene archiviato crittografato; il TTS cloud lo invia solo dopo aver premuto Leggi.';

  @override
  String get settingsSessionAttentionUnavailable =>
      'L’attenzione sessioni non è disponibile su questa piattaforma.';

  @override
  String get settingsSessionAttentionOpenSettings =>
      'Apri impostazioni di visualizzazione';

  @override
  String get settingsSessionAttentionStop => 'Arresta attenzione sessioni';

  @override
  String get settingsSessionAttentionThirdPartyTtsWarning =>
      'Premendo Leggi, il testo della risposta può essere inviato al provider TTS di terze parti configurato.';

  @override
  String get workspaceSuggestions => 'Suggerimenti';

  @override
  String get sessionTabsGestureHintTitle => 'Session tabs have new controls';

  @override
  String get sessionTabsGestureHintBody =>
      'Double-click or double-tap a tab to close it. Right-click or touch and hold to open session actions. You can disable tabs in Display Toggles.';

  @override
  String get sessionTabsGestureHintAcknowledge => 'Got it';

  @override
  String get sessionTabsGestureHintDisableTabs => 'Disable tabs';

  @override
  String get sessionTabRenameAction => 'Rename session';

  @override
  String sessionTabClosedMessage(String title) {
    return 'Tab \"$title\" closed';
  }

  @override
  String get sessionTabUndo => 'Undo';

  @override
  String get sessionTabRestoreFailed => 'Tab could not be restored.';
}
