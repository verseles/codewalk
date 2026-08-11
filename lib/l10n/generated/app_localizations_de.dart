// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get aboutGitHub => 'GitHub';

  @override
  String get appProviderCannotActivateUnhealthy =>
      'Ein fehlerhafter Server kann nicht aktiviert werden';

  @override
  String get appProviderDesktopOnly =>
      'Der verwaltete lokale Server ist nur auf dem Desktop verfügbar.';

  @override
  String get appProviderDetectingCommand => 'OpenCode-Befehl wird erkannt...';

  @override
  String get appProviderErrorCannotActivateUnhealthy =>
      'Ein fehlerhafter Server kann nicht aktiviert werden';

  @override
  String get appProviderErrorCloudflareOAuthNotSupported =>
      'Cloudflare Access OAuth wird auf dieser Plattform nicht unterstützt';

  @override
  String get appProviderErrorInstallationFailed =>
      'OpenCode-Installation fehlgeschlagen.';

  @override
  String get appProviderErrorInvalidServerUrl => 'Ungültige Server-URL';

  @override
  String get appProviderErrorLocalServerHealthCheckFailed =>
      'Der lokale Server wurde gestartet, aber der Integritätstest ist fehlgeschlagen.';

  @override
  String get appProviderErrorManagedDesktopOnly =>
      'Der verwaltete lokale Server ist nur auf dem Desktop verfügbar.';

  @override
  String get appProviderErrorServerAlreadyExists =>
      'Ein Server mit dieser URL existiert bereits';

  @override
  String get appProviderErrorServerProfileNotFound =>
      'Serverprofil nicht gefunden';

  @override
  String get appProviderErrorServerUrlRequired => 'Server-URL ist erforderlich';

  @override
  String get appProviderErrorTailscaleNotSupported =>
      'Tailscale wird auf dieser Plattform nicht unterstützt';

  @override
  String appProviderExitedWithCode(int code) {
    return 'Der lokale Server wurde mit dem Code $code beendet.';
  }

  @override
  String get appProviderFailedToStart =>
      'Fehler beim Starten des lokalen OpenCode-Servers.';

  @override
  String get appProviderInstallBinary => 'Binärdatei installieren';

  @override
  String get appProviderInstallBunOpenCode => 'Bun + OpenCode installieren';

  @override
  String get appProviderInstallSucceeded => 'Installation erfolgreich.';

  @override
  String appProviderInstallSucceededWithPath(String path) {
    return 'Installation erfolgreich. OpenCode-Befehl verfügbar unter $path.';
  }

  @override
  String get appProviderInstallViaBun => 'Über Bun installieren';

  @override
  String get appProviderInstallViaNpm => 'Über npm installieren';

  @override
  String get appProviderInstallationFailed =>
      'OpenCode-Installation fehlgeschlagen.';

  @override
  String get appProviderInstalledSuccessfully =>
      'OpenCode-Anforderungen erfolgreich installiert.';

  @override
  String get appProviderInstallingRequirements =>
      'OpenCode-Anforderungen werden installiert...';

  @override
  String get appProviderInvalidServerUrl => 'Ungültige Server-URL';

  @override
  String get appProviderLabelLocalOpenCodeManaged =>
      'Lokales OpenCode (verwaltet)';

  @override
  String get appProviderLabelPrimaryServer => 'Primärer Server';

  @override
  String get appProviderLocalManaged => 'Lokales OpenCode (verwaltet)';

  @override
  String get appProviderLocalServerStopped => 'Der lokale Server ist gestoppt.';

  @override
  String get appProviderNotDetectedInstall =>
      'OpenCode-Befehl wurde nicht erkannt. Führen Sie die Installation über den Assistenten aus.';

  @override
  String appProviderNotDetectedRefresh(String appName) {
    return 'OpenCode-Befehl wurde nicht erkannt. Falls Sie ihn gerade erst installiert haben, aktualisieren Sie die Prüfungen oder starten Sie $appName neu, um den PATH neu zu laden.';
  }

  @override
  String get appProviderOAuthNotSupported =>
      'Cloudflare Access OAuth wird auf dieser Plattform nicht unterstützt';

  @override
  String get appProviderOpenCodeDetected => 'OpenCode erkannt';

  @override
  String get appProviderOpenCodeNotDetected => 'OpenCode nicht erkannt';

  @override
  String get appProviderPrimaryServer => 'Primärer Server';

  @override
  String get appProviderProfileNotFound => 'Serverprofil nicht gefunden';

  @override
  String get appProviderRunDiagnostics =>
      'Führen Sie eine Diagnose aus, um die lokalen OpenCode-Anforderungen zu überprüfen.';

  @override
  String appProviderRunningAt(String url) {
    return 'Läuft unter $url';
  }

  @override
  String get appProviderSetupDetectingOpenCode =>
      'OpenCode-Befehl wird erkannt...';

  @override
  String get appProviderSetupInstallationSucceeded =>
      'Installation erfolgreich.';

  @override
  String appProviderSetupInstallationSucceededWithPath(String path) {
    return 'Installation erfolgreich. OpenCode-Befehl verfügbar unter $path.';
  }

  @override
  String get appProviderSetupInstallingRequirements =>
      'OpenCode-Anforderungen werden installiert...';

  @override
  String get appProviderSetupOpenCodeDetected => 'OpenCode erkannt';

  @override
  String get appProviderSetupOpenCodeNotDetected => 'OpenCode nicht erkannt';

  @override
  String get appProviderSetupOpenCodeNotDetectedInstall =>
      'OpenCode-Befehl wurde nicht erkannt. Führen Sie die Installation über den Assistenten aus.';

  @override
  String get appProviderSetupOpenCodeNotDetectedRefresh =>
      'OpenCode-Befehl wurde nicht erkannt. Falls Sie ihn gerade erst installiert haben, aktualisieren Sie die Prüfungen oder starten Sie CodeWalk neu, um den PATH neu zu laden.';

  @override
  String get appProviderSetupRequirementsInstalled =>
      'OpenCode-Anforderungen erfolgreich installiert.';

  @override
  String appProviderSetupUsingOpenCodeAt(String path) {
    return 'OpenCode-Befehl unter $path wird verwendet';
  }

  @override
  String get appProviderStartingLocalServer =>
      'Lokaler Server wird gestartet...';

  @override
  String appProviderStatusLocalServerExitedWithCode(int code) {
    return 'Der lokale Server wurde mit dem Code $code beendet.';
  }

  @override
  String get appProviderStatusLocalServerStopped =>
      'Der lokale Server ist gestoppt.';

  @override
  String appProviderStatusRunningAt(String url) {
    return 'Läuft unter $url';
  }

  @override
  String get appProviderStatusStartingLocalServer =>
      'Lokaler Server wird gestartet...';

  @override
  String get appProviderStatusStoppingLocalServer =>
      'Lokaler Server wird gestoppt...';

  @override
  String get appProviderStoppingLocalServer =>
      'Lokaler Server wird gestoppt...';

  @override
  String get appProviderTailscaleNotSupported =>
      'Tailscale wird auf dieser Plattform nicht unterstützt';

  @override
  String appProviderUsingCommandAt(String path) {
    return 'OpenCode-Befehl unter $path wird verwendet';
  }

  @override
  String get appShellDownloadingUpdate => 'Update wird heruntergeladen';

  @override
  String get appShellInstall => 'Installieren';

  @override
  String get appShellInstallFailed => 'Installation fehlgeschlagen';

  @override
  String get appShellInstallingUpdate => 'Update wird installiert...';

  @override
  String get appShellRestart => 'Neu starten';

  @override
  String appShellUpdateAvailableResult(String latestVersion) {
    return 'Update verfügbar: v$latestVersion';
  }

  @override
  String get appShellUpdateInstalledRestartApp =>
      'Update installiert. Starten Sie die App neu, um es anzuwenden.';

  @override
  String get appShellUpdateInstalledRestartRequired =>
      'Update installiert. Ein Neustart ist erforderlich, um die neue Version anzuwenden.';

  @override
  String get attachmentCouldNotDecode =>
      'Anhangsdaten konnten nicht dekodiert werden.';

  @override
  String get attachmentCouldNotDownload =>
      'Anhang konnte nicht heruntergeladen werden.';

  @override
  String get attachmentCouldNotSave =>
      'Anhang konnte auf diesem Gerät nicht gespeichert werden.';

  @override
  String get attachmentDownloadStarted => 'Download des Anhangs gestartet.';

  @override
  String get attachmentLocalNotFound =>
      'Lokaler Anhang wurde auf diesem Gerät nicht gefunden.';

  @override
  String get attachmentNoValidLocation =>
      'Anhang bietet keinen gültigen Speicherort.';

  @override
  String get attachmentNotAvailableOnPlatform =>
      'Anhangsaktionen sind auf dieser Plattform nicht verfügbar.';

  @override
  String get attachmentPathEmpty => 'Anhangspfad ist leer.';

  @override
  String get attachmentPayloadEmpty => 'Anhangs-Payload ist leer.';

  @override
  String get attachmentSaveCanceled => 'Speichern abgebrochen.';

  @override
  String attachmentSavedAndOpened(String path) {
    return 'Anhang unter $path gespeichert und geöffnet.';
  }

  @override
  String attachmentSavedPath(String path) {
    return 'Anhang unter $path gespeichert.';
  }

  @override
  String attachmentSavedTo(String path) {
    return 'Anhang unter $path gespeichert.';
  }

  @override
  String get attachmentUnableToOpenLink =>
      'Link zum Anhang konnte nicht geöffnet werden.';

  @override
  String get attachmentUnableToOpenLocal =>
      'Lokaler Anhang konnte nicht geöffnet werden.';

  @override
  String get behaviorAdvancedPermissionRule => 'Erweiterte Berechtigungsregel';

  @override
  String get behaviorAutomatic => 'Automatisch';

  @override
  String get behaviorAutomaticFallback => 'Automatischer Fallback';

  @override
  String get behaviorCellularDataSaver => 'Mobiler Datensparmodus';

  @override
  String get behaviorCellularDataSaverActive => 'Datensparmodus ist aktiv.';

  @override
  String get behaviorChatLevelShare => 'Chat-Level-Freigabe';

  @override
  String get behaviorCodeWalkReleaseChecks => 'CodeWalk-Versionsprüfungen';

  @override
  String get behaviorControlsOfficialGlobal =>
      'Steuert offizielle globale OpenCode-Einstellungen';

  @override
  String get behaviorControlsUpstreamOpenCode =>
      'Steuert Upstream-OpenCode-Einstellungen';

  @override
  String get behaviorCustomDisplayName => 'Benutzerdefinierter Anzeigename';

  @override
  String behaviorCutsAutomaticMobile(int inSeconds) {
    return 'Reduziert automatische mobile Datennutzung durch Stoppen von Hintergrund-Downloads und Drosselung automatischer Vordergrund-Aktualisierungen auf einen Burst alle $inSeconds Sekunden.';
  }

  @override
  String get behaviorDataSaverActive => 'Jetzt auf mobilen Daten aktiv.';

  @override
  String get behaviorDataSaverAggressive => 'Aggressive';

  @override
  String get behaviorDataSaverAggressiveDescription =>
      'Low-bandwidth mode: only the visible workspace stream stays live, global updates are paused, and automatic refreshes are stretched.';

  @override
  String get behaviorDataSaverCellularOnly =>
      'Gilt nur, wenn die Verbindung mobil ist.';

  @override
  String get behaviorDataSaverOff => 'Off';

  @override
  String get behaviorDataSaverOffHint =>
      'Full realtime and automatic refreshes are enabled.';

  @override
  String get behaviorDataSaverStandard => 'Standard';

  @override
  String get behaviorDataSaverWaiting =>
      'Warten auf das nächste Synchronisationsfenster für mobile Daten.';

  @override
  String get behaviorDisabled => 'Deaktiviert';

  @override
  String get behaviorLightweightTasksLike => 'Leichte Aufgaben wie';

  @override
  String get behaviorManual => 'Manuell';

  @override
  String get behaviorNotify => 'Benachrichtigen';

  @override
  String get behaviorOfficialOpenCodePermission =>
      'Die offizielle OpenCode-Berechtigungsrichtlinie ist in `opencode.json` mit Erlauben/Fragen/Ablehnen-Regeln pro Tool konfiguriert. CodeWalk behält die offiziellen Berechtigungsanforderungskarten bei und fügt eine genehmigte ADR-023-Ausnahme hinzu: Der Composer-Schalter für automatische Genehmigung antwortet bedingungslos mit `Always` und `remember: true` unconditionally to create durable session-scoped grants, und hält denselben threadbezogenen Kontinuitätspfad im Android-Hintergrund-Worker aktiv.';

  @override
  String get behaviorOpenCodeBackedDefaults =>
      'OpenCode-gestützte Standardwerte';

  @override
  String get behaviorPermissionHandlingProvenance =>
      'Provenienz der Rechtebehandlung';

  @override
  String get behaviorPermissionsVariantReasoning =>
      'Berechtigungen und Varianten-/Begründungs-Parität bleiben getrennt, bis ihre Benutzeroberfläche erweiterte Konfigurationen sicher bewahren kann.';

  @override
  String get behaviorPrimaryAgentAgent =>
      'Primärer Agent, der verwendet wird, wenn kein Agent explizit ausgewählt ist.';

  @override
  String get behaviorRefreshDefaults => 'Standardwerte aktualisieren';

  @override
  String get behaviorSharedAcrossOpenCode =>
      'Wird über die Konfiguration mit anderen OpenCode-Clients geteilt.';

  @override
  String get behaviorTheseValuesWrite =>
      'Diese Werte werden in `/config` auf dem aktiven Server geschrieben und entsprechen der offiziellen geteilten OpenCode-Konfiguration.';

  @override
  String get cannedAddTitle => 'Schnellantwort hinzufügen';

  @override
  String get cannedAppendAtCursor => 'An Cursor anhängen';

  @override
  String get cannedAppendAtCursorSubtitle => 'Aus = aktuellen Text ersetzen';

  @override
  String get cannedAttachFiles => 'Dateien anhängen';

  @override
  String get cannedEditTitle => 'Schnellantwort bearbeiten';

  @override
  String get cannedNewQuickReply => 'Neue Schnellantwort';

  @override
  String get cannedNoSuggestions => 'Keine Vorschläge';

  @override
  String get cannedOffMeansReplace =>
      'Aus bedeutet, dass der aktuelle Text des Composers ersetzt wird';

  @override
  String get cannedQuickReply => 'Neue Schnellantwort';

  @override
  String get cannedReplace => 'Ersetzen';

  @override
  String get cannedScopeGlobalSubtitle =>
      'Deaktivieren für projektweites Element';

  @override
  String get cannedScopeGlobalUnavailableSubtitle =>
      'Nur-Projekt im aktuellen Kontext nicht verfügbar';

  @override
  String get cannedSendAutomaticallySubtitle => 'Sofort nach Einfügen senden';

  @override
  String get cannedSendImmediatelyInserting =>
      'Sofort nach dem Einfügen dieser Schnellantwort senden';

  @override
  String get cannedTextLabel => 'Text';

  @override
  String get chatActionNext => 'Weiter';

  @override
  String get chatActiveServerUnhealthy =>
      'Der aktive Server ist fehlerhaft. Sendeversuche werden einmal durchgeführt und schlagen bis zur Wiederherstellung schnell fehl.';

  @override
  String get chatActiveServerUnhealthyLabel =>
      'Aktiver Server ist nicht verfügbar';

  @override
  String get chatAddServerToStart =>
      'Fügen Sie einen Server hinzu, um mit dem Chatten zu beginnen.';

  @override
  String get chatAppBarMoreActions => 'Weitere Aktionen';

  @override
  String get chatAppBarPinAction => 'An App-Leiste anheften';

  @override
  String get chatAppBarPinDescription =>
      'Diese Aktion bleibt außerhalb des Menüs sichtbar.';

  @override
  String get chatAppBarUnpinAction => 'Von App-Leiste lösen';

  @override
  String get chatAppBarUnpinDescription =>
      'Diese Aktion wird wieder in das Menü verschoben.';

  @override
  String chatBadgeConversationError(String title) {
    return '\"$title\" hat einen Fehler.';
  }

  @override
  String chatBadgeConversationNeedsInput(String title) {
    return '\"$title\" benötigt Ihre Eingabe.';
  }

  @override
  String chatBadgeConversationNewReply(String title) {
    return '\"$title\" hat eine neue Antwort.';
  }

  @override
  String get chatBadgeDataSaverActive => 'Mobiler Datensparmodus ist aktiv.';

  @override
  String get chatBadgeServerNeedsAttention =>
      'Serververbindung benötigt Aufmerksamkeit.';

  @override
  String get chatBadgeSyncing => 'Konversationen werden synchronisiert...';

  @override
  String get chatBlockResponsePendingDescription =>
      'The answer will appear as a single block when this turn finishes.';

  @override
  String get chatBlockResponsePendingTitle => 'Generating response';

  @override
  String get chatCachedConversationsYet =>
      'Noch keine zwischengespeicherten Konversationen';

  @override
  String get chatChangedFilesAvailable =>
      'Für diese Sitzung sind keine geänderten Dateien verfügbar.';

  @override
  String chatChildrenChatProviderCurrentSessionChildren(int length) {
    return 'Kinder: $length';
  }

  @override
  String get chatChooseAgent => 'Agent auswählen';

  @override
  String get chatChooseDirectory => 'Verzeichnis auswählen';

  @override
  String get chatChooseEffort => 'Aufwand wählen';

  @override
  String get chatChooseFolderOpen =>
      'Wählen Sie einen Ordner aus, der als Projektkontext geöffnet werden soll.';

  @override
  String get chatChooseModel => 'Modell auswählen';

  @override
  String get chatClose => 'Schließen';

  @override
  String chatCloseProject(String project) {
    return '$project schließen';
  }

  @override
  String get chatCollapseGroup => 'Gruppe einklappen';

  @override
  String get chatCommandDescriptionProject => 'Projektbefehl';

  @override
  String get chatCommandSourceGeneric => 'Befehl';

  @override
  String get chatCommandSourceProject => 'Projekt';

  @override
  String get chatCompactContext => 'Kompakter Kontext';

  @override
  String get chatComposerHintShell => 'Shell-Befehl (Esc zum Beenden)';

  @override
  String get chatComposerPlaceholder => 'Gib deine Wünsche ein...';

  @override
  String get chatConversation => 'Konversation';

  @override
  String get chatConversations => 'Konversationen';

  @override
  String get chatConversationsPane => 'Konversationen';

  @override
  String chatCostLabel(double cost) {
    return 'Kosten: \$$cost';
  }

  @override
  String get chatCouldNotRefreshSession =>
      'Konversation konnte nicht aktualisiert werden';

  @override
  String get chatCurrent => 'Aktuelle verwenden';

  @override
  String chatDescriptionChildren(int count) {
    return 'Unterelemente: $count';
  }

  @override
  String get chatDescriptionCloseApp =>
      'App mit dem Standard-Schließverhalten der Plattform schließen';

  @override
  String get chatDescriptionCycleModels =>
      'Kürzlich verwendete Modelle durchlaufen';

  @override
  String get chatDescriptionCycleVariant => 'Modellvariante durchlaufen';

  @override
  String get chatDescriptionDiffFilesZero => 'Diff-Dateien: 0';

  @override
  String get chatDescriptionFocusInput => 'Nachrichteneingabe fokussieren';

  @override
  String get chatDescriptionFocusOrCloseDrawer =>
      'Eingabe fokussieren (oder Seitenleiste schließen, falls offen)';

  @override
  String get chatDescriptionForceExit => 'Beenden der App erzwingen';

  @override
  String get chatDescriptionNewConversation => 'Neue Konversation';

  @override
  String get chatDescriptionNextAgent => 'Nächster Agent';

  @override
  String get chatDescriptionOpenProjects =>
      'Verwenden Sie diese Schaltfläche, um Ihre Projekte und Konversationen zu öffnen.';

  @override
  String get chatDescriptionOpenSettings => 'Einstellungen öffnen';

  @override
  String get chatDescriptionPreviousAgent => 'Vorheriger Agent';

  @override
  String get chatDescriptionProjectCommand => 'Projektbefehl';

  @override
  String get chatDescriptionQuickOpen => 'Dateien schnell öffnen';

  @override
  String get chatDescriptionRefreshData => 'Chat-Daten aktualisieren';

  @override
  String get chatDescriptionStopResponse =>
      'Aktive Antwort stoppen (während der Antwort)';

  @override
  String get chatDescriptionSwitchProject =>
      'Verwenden Sie diese Schaltfläche, um Projektordner und Kontext zu wechseln.';

  @override
  String get chatDescriptionVoiceInput => 'Spracheingabe starten oder stoppen';

  @override
  String get chatDiffFiles => 'Diff-Dateien: 0';

  @override
  String get chatDisplay => 'Anzeige';

  @override
  String get chatDisplayToggles => 'Anzeige-Optionen';

  @override
  String get chatDoubleESCStop => 'Doppelt ESC zum Stoppen';

  @override
  String get chatEffortLockedSubConversation =>
      'Aufwand in Unterkonversation gesperrt';

  @override
  String get chatExpandGroup => 'Gruppe ausklappen';

  @override
  String get chatExportCanceled => 'Sitzungsexport abgebrochen';

  @override
  String get chatFailedToLoadDirectories =>
      'Verzeichnisse konnten nicht geladen werden';

  @override
  String get chatFailedToLoadFile => 'Datei konnte nicht geladen werden';

  @override
  String get chatFailedToRefreshProviders =>
      'Anbieter und Modelle konnten nicht aktualisiert werden';

  @override
  String get chatFailedToRefreshSubConversations =>
      'Unterkonversationen konnten nicht aktualisiert werden.';

  @override
  String get chatFailedToStopResponse =>
      'Aktuelle Antwort konnte nicht gestoppt werden';

  @override
  String get chatFileExplorerContents => 'Inhalte';

  @override
  String get chatFileExplorerNames => 'Namen';

  @override
  String get chatFilterActive => 'Aktiv';

  @override
  String get chatFilterAll => 'Alle';

  @override
  String get chatFilterArchived => 'Archiviert';

  @override
  String get chatFilterDirectories => 'Verzeichnisse filtern';

  @override
  String get chatFilterSessions => 'Sitzungen filtern';

  @override
  String get chatForkFailed => 'Abzweigen der Konversation fehlgeschlagen';

  @override
  String get chatForked => 'Konversation abgezweigt';

  @override
  String get chatGoToFirst => 'Zur ersten Nachricht gehen';

  @override
  String get chatGoToLatest => 'Zur neuesten Nachricht gehen';

  @override
  String chatGroupMessageCountMessages(
    String compactionLabel,
    String messageCount,
  ) {
    return '$messageCount Nachrichten ausgeblendet vor $compactionLabel Komprimierung';
  }

  @override
  String get chatHelloAssistant => 'Hallo! Ich bin Ihr KI-Assistent';

  @override
  String get chatHelp => 'Wie kann ich Ihnen helfen?';

  @override
  String get chatHelpMessage =>
      'Verwenden Sie @ für Erwähnungen, ! für Shell, / für Befehle';

  @override
  String get chatHideConversationsSidebar =>
      'Konversations-Seitenleiste ausblenden';

  @override
  String get chatHideUtilitySidebar => 'Dienstprogramm-Seitenleiste ausblenden';

  @override
  String get chatHistoryCollapsed => 'Der vorherige Verlauf ist eingeklappt';

  @override
  String get chatHistoryHideEarlier => 'Frühere Nachrichten ausblenden';

  @override
  String chatHistoryMessagesHidden(int count, String label) {
    return '$count Nachrichten vor $label-Kompaktierung ausgeblendet';
  }

  @override
  String get chatHistoryShowEarlier => 'Frühere Nachrichten anzeigen';

  @override
  String get chatKeepWorking => 'Weiterarbeiten';

  @override
  String get chatLargeContentSkipped =>
      'Große oder fehlerhafte Inhalte wurden aus Stabilitätsgründen übersprungen.';

  @override
  String get chatLatestToolActivity =>
      'Die neueste Tool-Aktivität bleibt in diesem begrenzten Panel, um das Chat-Sichtfeld stabil zu halten.';

  @override
  String get chatLoadMore => 'Mehr laden';

  @override
  String get chatLoadingProjectContext => 'Projektkontext wird geladen...';

  @override
  String get chatMainConversationUnavailable =>
      'Hauptkonversation noch nicht verfügbar.';

  @override
  String get chatParentConversationUnavailable =>
      'Die übergeordnete Unterhaltung ist noch nicht verfügbar.';

  @override
  String get chatMentionAgentSubtitle => 'Agent';

  @override
  String get chatMentionFileSubtitle => 'Datei';

  @override
  String get chatMentionSymbolSubtitle => 'Symbol';

  @override
  String get chatMessageAttachedFile => 'Angehängte Datei';

  @override
  String get chatMessageDetails => 'Details';

  @override
  String get chatMessageHide => 'Ausblenden';

  @override
  String get chatMessageLess => 'Weniger';

  @override
  String get chatMessageMessagePartUnavailable =>
      'Nachrichtenteil nicht verfügbar';

  @override
  String get chatMessageMetadataAvailable => 'Keine Metadaten verfügbar';

  @override
  String chatMessageModelMessageModelId(String modelId) {
    return 'Modell: $modelId';
  }

  @override
  String get chatMessageMore => 'Mehr';

  @override
  String get chatMessageOpenFile => 'Datei öffnen';

  @override
  String chatMessageProviderMessageProviderId(String providerId) {
    return 'Anbieter: $providerId';
  }

  @override
  String get chatMessageRewindEdit => 'Ab hier zurückspulen und bearbeiten';

  @override
  String get chatMessageRunningTask => 'Aufgabe wird ausgeführt';

  @override
  String get chatMessageSaveFile => 'Datei speichern';

  @override
  String get chatMessageShow => 'Anzeigen';

  @override
  String get chatMessageShowLess => 'Weniger anzeigen';

  @override
  String get chatMessageShowLessCompact => 'Weniger';

  @override
  String get chatMessageShowMore => 'Mehr anzeigen';

  @override
  String get chatMessageShowMoreCompact => 'Mehr';

  @override
  String get chatMessageThinking => 'Denkt nach';

  @override
  String get chatMessageThinkingProcess => 'Denkprozess';

  @override
  String get chatMessageToolCall => '1 Toolaufruf';

  @override
  String chatMessageToolCalls(int count) {
    return '$count Toolaufrufe';
  }

  @override
  String get chatMessageToolCommand => 'Befehl';

  @override
  String get chatMessageToolCommandTruncated =>
      'Befehlsvorschau aus Stabilitätsgründen gekürzt.';

  @override
  String get chatMessageToolDiffOmitted =>
      'Diff ausgelassen – Bearbeitung zu groß für mobile Darstellung.';

  @override
  String get chatMessageToolInput => 'Eingabe';

  @override
  String get chatMessageToolInputTruncated =>
      'Eingabevorschau aus Stabilitätsgründen gekürzt.';

  @override
  String get chatMessageToolOutputTruncated =>
      'Große Ausgabe aus Stabilitätsgründen gekürzt.';

  @override
  String chatMessageToolQueuedCount(int count) {
    return '$count warten';
  }

  @override
  String chatMessageToolRunningCount(int count) {
    return '$count laufen';
  }

  @override
  String get chatMessageToolStatusInProgress => 'Wird ausgeführt';

  @override
  String get chatMessageToolStatusNeedsAttention => 'Erfordert Aufmerksamkeit';

  @override
  String get chatMessageToolStatusQueued => 'In der Warteschlange';

  @override
  String get chatMessageYou => 'Sie';

  @override
  String get chatModelLockedSubConversation =>
      'Modell in Unterhaltung gesperrt';

  @override
  String get chatNewChat => 'Neuer Chat';

  @override
  String get chatNewChatTourDescription =>
      'Starten Sie hier eine neue Konversation.';

  @override
  String get chatNewChatTourTitle => 'Neuer Chat';

  @override
  String get chatNoConversationsInProject =>
      'Keine Konversationen in diesem Projekt.';

  @override
  String get chatNoServerYet => 'Noch kein Server konfiguriert';

  @override
  String get chatNoSessionSelected => 'Wähle oder erstelle eine Konversation';

  @override
  String get chatNoSubConversationFound => 'Keine Unterkonversation gefunden.';

  @override
  String get chatOpenFiles => 'Offene Dateien';

  @override
  String get chatOpenProject => 'Projekt öffnen';

  @override
  String get chatOpenProjectFolder => 'Projektordner öffnen...';

  @override
  String get chatOpenProjectToLoad =>
      'Projekt öffnen, um Konversationen zu laden.';

  @override
  String get chatOpenSidebar => 'Seitenleiste öffnen';

  @override
  String get chatPageStatusAutomaticCompactionExplanation =>
      'Automatische Komprimierung erfolgt bei zunehmender Kontextnutzung.';

  @override
  String get chatPageStatusCompactNow => 'Jetzt komprimieren';

  @override
  String get chatPageStatusCompacting => 'Wird komprimiert...';

  @override
  String get chatPageStatusCompactingContextNow =>
      'Kontext wird jetzt komprimiert...';

  @override
  String get chatPageStatusContextCompacted => 'Kontext komprimiert';

  @override
  String get chatPageStatusContextUsage => 'Kontextnutzung';

  @override
  String get chatPageStatusCost => 'Kosten';

  @override
  String get chatPageStatusFailedToCompactContext =>
      'Kontext konnte nicht komprimiert werden';

  @override
  String get chatPageStatusLimit => 'Limit';

  @override
  String get chatPageStatusManageServers => 'Server verwalten';

  @override
  String get chatPageStatusSaver => 'Sparmodus';

  @override
  String get chatPageStatusServer => 'Server';

  @override
  String get chatPageStatusSwitchServer => 'Server wechseln';

  @override
  String get chatPageStatusTokens => 'Token';

  @override
  String get chatPageStatusUsage => 'Nutzung';

  @override
  String chatPageStatusUsagePercent(int usagePercent) {
    return '$usagePercent';
  }

  @override
  String get chatPermissionAutoApproveOff =>
      'Automatische Genehmigung ist deaktiviert';

  @override
  String get chatPermissionAutoApproveOn =>
      'Automatische Genehmigung ist aktiviert';

  @override
  String get chatProjectContext => 'Projektkontext';

  @override
  String get chatProjectContext2 => 'Projektkontext';

  @override
  String get chatRealtimeGlobalEvent => 'globales Ereignis';

  @override
  String chatRealtimeGlobalEventReason(String reason) {
    return 'globales Ereignis ($reason)';
  }

  @override
  String get chatRealtimeGlobalEventStale =>
      'globales Ereignis (veraltete Generation)';

  @override
  String chatRealtimeMessageStreamReason(String reason) {
    return 'Nachrichtenstrom ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEvent => 'Echtzeit-Ereignis';

  @override
  String chatRealtimeRealtimeEventReason(String reason) {
    return 'Echtzeit-Ereignis ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEventStale =>
      'Echtzeit-Ereignis (veraltete Generation)';

  @override
  String get chatRealtimeReconnectingServerTry =>
      'Wiederverbindung mit dem Server. Versuchen Sie es in einem Moment erneut.';

  @override
  String get chatReasoning => 'Denkt nach...';

  @override
  String get chatRecentSessions => 'Letzte Sitzungen';

  @override
  String get chatRecentSessionsToggle => 'Letzte Sitzungen';

  @override
  String get chatRedoLastTurn =>
      'Letzten rückgängig gemachten Schritt wiederholen';

  @override
  String get chatRedoNothing => 'Nichts zu wiederholen in dieser Sitzung';

  @override
  String get chatRefresh => 'Aktualisieren';

  @override
  String get chatRefreshConversation =>
      'Konversation konnte nicht aktualisiert werden';

  @override
  String get chatRefreshProjects => 'Projekte aktualisieren';

  @override
  String get chatRefreshSessionDetails => 'Sitzungsdetails aktualisieren';

  @override
  String chatRemoveDisplayNameHistory(String displayName) {
    return '$displayName aus Verlauf entfernen';
  }

  @override
  String get chatRetry => 'Wiederholen';

  @override
  String get chatRetry2 => 'Wiederholen';

  @override
  String get chatRetryRefresh => 'Aktualisierung wiederholen';

  @override
  String get chatRetryingModelRequest => 'Modellanfrage wird wiederholt...';

  @override
  String get chatReturnToMainConversation =>
      'Zur Hauptkonversation zurückkehren';

  @override
  String get chatReturnToParentConversation =>
      'Zur übergeordneten Unterhaltung zurückkehren';

  @override
  String get chatReviewChanges => 'Änderungen überprüfen';

  @override
  String get chatSearchConversations => 'Konversationen suchen';

  @override
  String get chatSearchNextResult => 'Nächstes Ergebnis';

  @override
  String get chatSearchNoResults => 'Keine Ergebnisse';

  @override
  String get chatSearchPreviousResult => 'Vorheriges Ergebnis';

  @override
  String chatSearchResultCount(int current, int total) {
    return 'Nachricht $current von $total';
  }

  @override
  String get chatSearchTimeline => 'Timeline durchsuchen';

  @override
  String get chatSelectDirectory => 'Verzeichnis auswählen';

  @override
  String get chatSelectOrCreate =>
      'Wählen oder erstellen Sie eine Konversation, um mit dem Chatten zu beginnen';

  @override
  String get chatSelectProjectBelow => 'Wählen Sie unten ein Projekt aus.';

  @override
  String get chatServerSelectedModel => 'Vom Server ausgewähltes Modell';

  @override
  String get chatSessionActions => 'Sitzungsaktionen';

  @override
  String chatSessionChatSessionSession(String title) {
    return 'Chat-Sitzung: $title';
  }

  @override
  String chatSessionConversationNextAction(String nextAction) {
    return 'Konversation $nextAction';
  }

  @override
  String get chatSessionConversations => 'Keine Konversationen';

  @override
  String get chatSessionCreateConversationStart =>
      'Erstellen Sie eine neue Konversation, um mit dem Chatten zu beginnen';

  @override
  String get chatSessionTabsToggle => 'Sitzungs-Tabs';

  @override
  String chatSessionsLength(int length) {
    return '$length';
  }

  @override
  String get chatSetUpServer => 'Server einrichten';

  @override
  String get chatSettings => 'Einstellungen';

  @override
  String get chatShortcutsCloseApp =>
      'App mit Plattform-Schließverhalten schließen';

  @override
  String get chatShortcutsCycleModels =>
      'Zuletzt verwendete Modelle durchlaufen';

  @override
  String get chatShortcutsCycleVariant => 'Modellvariante durchlaufen';

  @override
  String get chatShortcutsFocusInput => 'Nachrichteneingabe fokussieren';

  @override
  String get chatShortcutsFocusInputCloseDrawer =>
      'Eingabe fokussieren (oder Drawer schließen, wenn offen)';

  @override
  String get chatShortcutsForceExit => 'App-Beenden erzwingen';

  @override
  String get chatShortcutsNewConversation => 'Neue Konversation';

  @override
  String get chatShortcutsNextAgent => 'Nächster Agent';

  @override
  String get chatShortcutsOpenSettings => 'Einstellungen öffnen';

  @override
  String get chatShortcutsPreviousAgent => 'Vorheriger Agent';

  @override
  String get chatShortcutsQuickOpen => 'Dateien schnell öffnen';

  @override
  String get chatShortcutsRefreshChat => 'Chat-Daten aktualisieren';

  @override
  String get chatShortcutsStartStopVoice =>
      'Spracheingabe starten oder stoppen';

  @override
  String get chatShortcutsStopResponse =>
      'Aktive Antwort stoppen (während der Antwort)';

  @override
  String get chatSidebarAccess => 'Seitenleiste öffnen';

  @override
  String get chatSortMostRecent => 'Neueste';

  @override
  String get chatSortOldest => 'Älteste';

  @override
  String get chatSortRecent => 'Kürzlich';

  @override
  String get chatSortSessions => 'Sitzungen sortieren';

  @override
  String get chatSortTitle => 'Titel';

  @override
  String get chatStartVoiceInput => 'Spracheingabe starten';

  @override
  String get chatStartingVoiceInput => 'Spracheingabe wird gestartet';

  @override
  String get chatStatusBusy => 'Status: Beschäftigt';

  @override
  String get chatStatusPatching => 'Patchen';

  @override
  String chatStatusPatchingMultipleFiles(int count) {
    return '$count Dateien werden gepatcht';
  }

  @override
  String get chatStatusPatchingOneFile => '1 Datei wird gepatcht';

  @override
  String get chatStatusRetry => 'Status: Wiederholen';

  @override
  String chatStatusRetryCount(int count) {
    return 'Status: Wiederholen #$count';
  }

  @override
  String get chatStatusSubsession => 'Unter-Sitzung';

  @override
  String get chatStatusThinking => 'Nachdenken...';

  @override
  String get chatStopVoiceInput => 'Spracheingabe stoppen';

  @override
  String chatSyncLabel(String label) {
    return 'Synchronisierung: $label';
  }

  @override
  String get chatTasks => 'Aufgaben';

  @override
  String get chatTasksAvailableSession =>
      'Für diese Sitzung sind keine Aufgaben verfügbar.';

  @override
  String get chatTipAcceptanceCriteria =>
      'Tipp: Fügen Sie Akzeptanzkriterien für größere Änderungen hinzu';

  @override
  String get chatTipAskForPlan =>
      'Tipp: Fragen Sie bei großen Aufgaben zuerst nach einem Plan';

  @override
  String get chatTipBeSpecific =>
      'Tipp: Seien Sie spezifisch — kürzere Prompts erhalten schnellere Antworten';

  @override
  String get chatTipBreakTasks =>
      'Tipp: Teilen Sie große Aufgaben in kleinere Prompts auf';

  @override
  String get chatTipCompareOptions =>
      'Tipp: Fragen Sie nach Alternativen, wenn Tradeoffs unklar sind';

  @override
  String get chatTipContextKnob =>
      'Tipp: Tippen Sie auf den Kontext-Knopf, um Nutzungsdetails zu sehen';

  @override
  String get chatTipDefineVerification =>
      'Tipp: Sagen Sie, welche Tests oder Checks bestehen sollen';

  @override
  String get chatTipLongPressSend =>
      'Tipp: Drücken Sie lange auf Senden, um eine neue Zeile einzufügen';

  @override
  String get chatTipMentionFiles =>
      'Tipp: Verwenden Sie @, um Dateien in Ihrem Prompt zu erwähnen';

  @override
  String get chatTipNameRelevantFiles =>
      'Tipp: Nennen Sie relevante Dateien, Screens oder Befehle';

  @override
  String get chatTipProvideContext =>
      'Tipp: Geben Sie Kontext an — fügen Sie Fehlermeldungen und Logs ein';

  @override
  String get chatTipRenameConversation =>
      'Tipp: Tippen Sie auf den Titel, um eine Konversation umzubenennen';

  @override
  String get chatTipRequestDocs =>
      'Tipp: Bitten Sie um Doku-Updates, wenn sich Verhalten ändert';

  @override
  String get chatTipShareAttempts =>
      'Tipp: Teilen Sie mit, was Sie versucht haben und welcher Fehler erschien';

  @override
  String get chatTipShellCommands =>
      'Tipp: Verwenden Sie ! am Anfang, um Shell-Befehle auszuführen';

  @override
  String get chatTipSlashCommands =>
      'Tipp: Verwenden Sie /, um auf Slash-Befehle zuzugreifen';

  @override
  String get chatTipStartWithGoal => 'Tipp: Beginnen Sie mit dem Endziel';

  @override
  String get chatTipStateConstraints =>
      'Tipp: Nennen Sie Einschränkungen, die der Agent bewahren muss';

  @override
  String get chatTipStepByStep =>
      'Tipp: Fragen Sie nach Schritt-für-Schritt beim Debuggen komplexer Probleme';

  @override
  String get chatTipUseFocusedAgents =>
      'Tipp: Wählen Sie einen fokussierten Agenten für Plan, Review oder Build';

  @override
  String get chatToggleSidebars => 'Seitenleisten umschalten';

  @override
  String chatTokensLabel(int total) {
    return 'Token: $total';
  }

  @override
  String get chatTourProjectsConversations =>
      'Verwenden Sie diese Schaltfläche, um Ihre Projekte und Konversationen zu öffnen.';

  @override
  String get chatTourSidebarProjectTools =>
      'Verwenden Sie dieses Menü, um die Konversations-Seitenleiste und Projekt-Tools anzuzeigen.';

  @override
  String get chatTourSwitchFolders =>
      'Verwenden Sie diese Schaltfläche, um Projektordner und Kontext zu wechseln.';

  @override
  String get chatUndoLastTurn => 'Letzten Schritt rückgängig machen';

  @override
  String get chatUndoNothing => 'Nichts rückgängig zu machen in dieser Sitzung';

  @override
  String get chatUseCurrent => 'Aktuelle verwenden';

  @override
  String get chatWaitingForNetworkConnection =>
      'Warten auf Netzwerkverbindung...';

  @override
  String get chatWelcomeMessage => 'Hallo! Ich bin dein KI-Assistent.';

  @override
  String get chatWelcomeSubmessage => 'Wie kann ich dir heute helfen?';

  @override
  String get chatWorkBoundedPanelExplanation =>
      'Die neueste Tool-Aktivität bleibt in diesem begrenzten Panel, um das Chat-Sichtfeld stabil zu halten.';

  @override
  String get chatWorkExpand => 'Erweitern';

  @override
  String get chatWorkHide => 'Ausblenden';

  @override
  String get chatWorkMessageOne => '1 Arbeitsnachricht';

  @override
  String chatWorkMessagesMultiple(int count) {
    return '$count Arbeitsnachrichten';
  }

  @override
  String get chatWorkShow => 'Anzeigen';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonCopiedToClipboard => 'In die Zwischenablage kopiert';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonFile => 'Datei';

  @override
  String get commonReset => 'Zurücksetzen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get compactionAutomatic => 'automatisch';

  @override
  String get compactionManual => 'manuel';

  @override
  String get composerAddAttachment => 'Anhang hinzufügen';

  @override
  String get composerAttachFiles => 'Dateien anhängen';

  @override
  String get composerCannedAppendAtCursor => 'Am Cursor anhängen';

  @override
  String get composerCannedLabel => 'Label (optional)';

  @override
  String get composerCannedNoReplies => 'Noch keine Schnellantworten.';

  @override
  String get composerCannedReplace => 'Ersetzen';

  @override
  String get composerCannedSave => 'Speichern';

  @override
  String get composerCannedScopeGlobal => 'Global';

  @override
  String get composerCannedScopeProject => 'Nur Projekt';

  @override
  String get composerCannedSendAutomatically => 'Automatisch senden';

  @override
  String get composerCannedText => 'Text';

  @override
  String get composerChatInput => 'Chateingabe';

  @override
  String get composerDeleteAction => 'Löschen';

  @override
  String get composerDropHint => 'Bilder oder PDFs zum Anhängen ablegen';

  @override
  String get composerPastedImageName => 'Eingefügtes Bild';

  @override
  String get composerEdit => 'Bearbeiten';

  @override
  String get composerExtras => 'Extras';

  @override
  String get composerExtrasHide => 'Extras ausblenden';

  @override
  String get composerNewQuickReply => 'Neue Schnellantwort';

  @override
  String get composerSelectImages => 'Bilder auswählen';

  @override
  String get composerSelectPdf => 'PDF auswählen';

  @override
  String get composerSend => 'Senden';

  @override
  String get composerShellMode => 'Shell-Modus';

  @override
  String get desktopWindowClose => 'Schließen';

  @override
  String get desktopWindowMaximize => 'Maximieren';

  @override
  String get desktopWindowMinimize => 'Minimieren';

  @override
  String get desktopWindowRestore => 'Wiederherstellen';

  @override
  String get dialogDownload => 'Herunterladen';

  @override
  String get dialogLanguage => 'Sprache';

  @override
  String get dialogMoonshineModelSize => 'Modellgröße';

  @override
  String get dialogMoonshineVoiceSetup => 'Moonshine-Spracheinrichtung';

  @override
  String get dialogParakeetModel => 'Parakeet-Modell';

  @override
  String get dialogParakeetVoiceSetup => 'Parakeet-Spracheinrichtung';

  @override
  String get dialogSenseVoiceModel => 'SenseVoice-Modell';

  @override
  String get dialogSenseVoiceSetup => 'SenseVoice-Einrichtung';

  @override
  String get dialogVoiceInputSetup => 'Spracheingabe-Einrichtung';

  @override
  String get errorAnErrorOccurred => 'Ein Fehler ist aufgetreten';

  @override
  String get errorAuthRequired => 'Authentifizierung erforderlich';

  @override
  String get errorAuthRequiredDesc =>
      'Authentifizierung fehlgeschlagen. Verbinden Sie den Anbieter erneut und versuchen Sie es noch einmal.';

  @override
  String get errorConnectionFailed => 'Verbindung fehlgeschlagen';

  @override
  String get errorConnectionFailedDesc =>
      'Der Server konnte nicht erreicht werden. Überprüfen Sie die Verbindung und den Serverstatus.';

  @override
  String get errorFormatAuthenticationFailedReconnect =>
      'Authentifizierung fehlgeschlagen. Verbinden Sie den Anbieter neu und versuchen Sie es erneut.';

  @override
  String get errorFormatProviderTemporarilyUnavailable =>
      'Anbieter vorübergehend nicht verfügbar. Versuchen Sie es in Kürze erneut.';

  @override
  String get errorFormatQuotaExceededCheck =>
      'Kontingent überschritten. Überprüfen Sie Ihren Anbietertarif oder Ihre Abrechnung.';

  @override
  String get errorFormatRateLimitExceeded =>
      'Ratenlimit überschritten. Warten Sie einen Moment und versuchen Sie es erneut.';

  @override
  String get errorFormatServerErrorPlease =>
      'Serverfehler. Bitte versuchen Sie es erneut.';

  @override
  String get errorFormatServiceTemporarilyUnavailable =>
      'Dienst vorübergehend nicht verfügbar. Der Server startet möglicherweise gerade — bitte versuchen Sie es in Kürze erneut.';

  @override
  String get errorFormatUnableReachServer =>
      'Server kann nicht erreicht werden. Überprüfen Sie die Verbindung und den Serverstatus.';

  @override
  String get errorProviderUnavailable => 'Anbieter nicht verfügbar';

  @override
  String get errorProviderUnavailableDesc =>
      'Anbieter vorübergehend nicht verfügbar. Versuchen Sie es in Kürze erneut.';

  @override
  String get errorQuotaExceeded => 'Kontingent überschritten';

  @override
  String get errorQuotaExceededDesc =>
      'Kontingent überschritten. Überprüfen Sie Ihren Anbieterplan oder Ihre Abrechnung.';

  @override
  String get errorRateLimitExceeded => 'Ratenbegrenzung überschritten';

  @override
  String get errorRateLimitExceededDesc =>
      'Ratenbegrenzung überschritten. Warten Sie einen Moment und versuchen Sie es erneut.';

  @override
  String get errorServerError => 'Serverfehler';

  @override
  String get errorServerErrorDesc =>
      'Serverfehler. Bitte versuchen Sie es erneut.';

  @override
  String get errorServiceUnavailable => 'Dienst nicht verfügbar';

  @override
  String get errorServiceUnavailableDesc =>
      'Dienst vorübergehend nicht verfügbar. Der Server fährt möglicherweise gerade hoch – bitte versuchen Sie es in Kürze erneut.';

  @override
  String get fileActionAttachmentDataDecoded =>
      'Anhangsdaten konnten nicht decodiert werden.';

  @override
  String get fileActionAttachmentPathEmpty => 'Anhangspfad ist leer.';

  @override
  String get fileActionAttachmentPayloadEmpty => 'Anhangs-Payload ist leer.';

  @override
  String get fileActionAttachmentProvideValid =>
      'Anhang stellt keinen gültigen Speicherort bereit.';

  @override
  String get fileActionAttachmentSavedDevice =>
      'Anhang konnte auf diesem Gerät nicht gespeichert werden.';

  @override
  String fileActionAttachmentSavedOutputFile(String path) {
    return 'Anhang in $path gespeichert und geöffnet.';
  }

  @override
  String fileActionAttachmentSavedOutputFile2(String path) {
    return 'Anhang in $path gespeichert.';
  }

  @override
  String fileActionAttachmentSavedSavedPath(String savedPath) {
    return 'Anhang in $savedPath gespeichert.';
  }

  @override
  String get fileActionLocalAttachmentFound =>
      'Lokaler Anhang wurde auf diesem Gerät nicht gefunden.';

  @override
  String get fileActionSaveCanceled => 'Speichern abgebrochen.';

  @override
  String get fileActionUnableOpenLocal =>
      'Der lokale Anhang konnte nicht geöffnet werden.';

  @override
  String get filesAddChat => 'Zum Chat hinzufügen';

  @override
  String get filesAutosave => 'Automatisch speichern';

  @override
  String get filesAutosaveOn => 'Automatisches Speichern an';

  @override
  String get filesAutosaveOff => 'Automatisches Speichern aus';

  @override
  String get filesRedo => 'Wiederholen';

  @override
  String get filesUndo => 'Rückgängig';

  @override
  String get filesBinaryFilePreview =>
      'Vorschau der Binärdatei ist nicht verfügbar.';

  @override
  String get filesClear => 'Löschen';

  @override
  String get filesContents => 'Inhalt';

  @override
  String get filesDuplicate => 'Duplizieren';

  @override
  String get filesDuplicated => 'Datei dupliziert';

  @override
  String get filesFileEmpty => 'Datei ist leer.';

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
  String get filesFilesFound => 'Keine Dateien gefunden';

  @override
  String get filesFileCreated => 'File created.';

  @override
  String get filesFolderCreated => 'Folder created.';

  @override
  String get filesHideSidebar => 'Dateien-Seitenleiste ausblenden';

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
  String get filesNames => 'Namen';

  @override
  String filesOpenFilesFileState(int length) {
    return 'Offene Dateien ($length)';
  }

  @override
  String get filesQuickOpen => 'Schnelles Öffnen';

  @override
  String get filesQuickOpenFile => 'Datei schnell öffnen';

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
  String get filesRefresh => 'Dateien aktualisieren';

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
  String get filesSearchHint => 'Dateien nach Name oder Pfad suchen';

  @override
  String get filesDeleted => 'Deleted.';

  @override
  String get filesTitle => 'Dateien';

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
  String get logsAppLogs => 'App-Protokolle';

  @override
  String get logsClear => 'Protokolle löschen';

  @override
  String get logsCloseSearch => 'Suche schließen';

  @override
  String get logsCopyFiltered => 'Gefilterte Protokolle kopieren';

  @override
  String get logsEnableLogging => 'App-Logging aktivieren';

  @override
  String get logsEnableLoggingAction => 'Logging aktivieren';

  @override
  String get logsEnableLoggingDescription =>
      'Sammelt Diagnose-Logs im Arbeitsspeicher. Lassen Sie dies außer zur Fehlersuche deaktiviert.';

  @override
  String get logsEntryContext => 'Kontext';

  @override
  String get logsEntryTags => 'Tags';

  @override
  String get logsFilterAll => 'Alle';

  @override
  String get logsFilterByTag => 'Tag';

  @override
  String get logsLevel => 'Ebene';

  @override
  String get logsLoggingDisabledDescription =>
      'CodeWalk sammelt keine detaillierten App-Logs. Aktivieren Sie Logging nur, wenn Sie Diagnosedaten benötigen.';

  @override
  String get logsLoggingDisabledTitle => 'Logging ist deaktiviert';

  @override
  String get logsMeasurePerformance => 'Leistung messen';

  @override
  String get logsMeasurePerformanceDescription =>
      'Erfasst Zeitmessungen für teure App-Operationen. Nur zur Diagnose von Verzögerungen aktivieren.';

  @override
  String get logsNoLogsYet => 'Noch keine Logs erfasst.';

  @override
  String get logsNoMatchingLogs =>
      'Keine Logs entsprechen den aktuellen Filtern.';

  @override
  String get logsNoPerformanceData =>
      'Keine Leistungslogs entsprechen den aktuellen Filtern.';

  @override
  String get logsNoTaskData =>
      'Keine Aufgaben entsprechen den aktuellen Filtern.';

  @override
  String logsPerformanceDuration(int elapsedMs) {
    return '$elapsedMs ms';
  }

  @override
  String get logsPerformanceFilter => 'Leistung';

  @override
  String logsPerformanceTileTitle(
    int elapsedMs,
    String operation,
    String status,
  ) {
    return 'LEISTUNG $operation | $elapsedMs ms | $status';
  }

  @override
  String get logsSearch => 'Protokolle suchen';

  @override
  String logsShowingOrderedLength(int length, int length2) {
    return 'Zeige $length von $length2 Einträgen';
  }

  @override
  String get logsSlowestPerformance => 'Langsamste Leistungslogs';

  @override
  String get logsSlowestTasks => 'Langsamste Aufgaben';

  @override
  String get logsTagCustomHint => 'Tag-Name (z. B.: task:select_session)';

  @override
  String get logsTagCustomAction => 'Benutzerdefiniert...';

  @override
  String logsTaskDuration(int elapsedMs, String operation) {
    return '$operation — $elapsedMs ms';
  }

  @override
  String get logsTaskStatusCanceled => 'abgebrochen';

  @override
  String get logsTaskStatusError => 'Fehler';

  @override
  String get logsTaskStatusOk => 'ok';

  @override
  String get logsTimeRange => 'Zeitraum';

  @override
  String get mathExpressionLabel => 'Mathematik';

  @override
  String get mermaidCopySourceTooltip => 'Quelle kopieren';

  @override
  String get mermaidDiagramLabel => 'Mermaid-Diagramm';

  @override
  String get modelAuto => 'Auto';

  @override
  String get modelChooseAgent => 'Agenten auswählen';

  @override
  String get modelFavorites => 'Favoriten';

  @override
  String get modelFree => 'Kostenlos';

  @override
  String get modelLabelBaseEnglish => 'Basis (Englisch)';

  @override
  String get modelLabelParakeet => 'Parakeet V3 (25 europäische Sprachen)';

  @override
  String get modelLabelSenseVoice => 'SenseVoice (zh/en/ja/ko/yue)';

  @override
  String get modelLabelTinyEnglish => 'Tiny (Englisch)';

  @override
  String get modelLoadingModels => 'Modelle werden geladen';

  @override
  String get modelModelsFound => 'Keine Modelle gefunden';

  @override
  String get modelRetryModels => 'Modelle erneut versuchen';

  @override
  String get modelSearchHint => 'Modell oder Anbieter suchen';

  @override
  String get msgBatterySettingsFailed =>
      'Android-Akkuoptimierungseinstellungen konnten nicht geöffnet werden.';

  @override
  String get msgBatterySettingsOpened =>
      'Android-Akkueinstellungen geöffnet. Erlauben Sie eine uneingeschränkte Akkunutzung für CodeWalk.';

  @override
  String get msgClearUsernameNeedsConfigEdit =>
      'Das Löschen des OpenCode-Konversations-Benutzernamens erfordert weiterhin das Bearbeiten der Konfiguration außerhalb der App.';

  @override
  String get msgCommandCopied => 'Befehl kopiert';

  @override
  String get msgCopiedToClipboard => 'In die Zwischenablage kopiert';

  @override
  String get msgEnterUsernameToSave =>
      'Geben Sie einen Benutzernamen ein, um einen benutzerdefinierten OpenCode-Konversationsnamen zu speichern.';

  @override
  String get msgFailedToSendMessage =>
      'Nachricht konnte nicht gesendet werden. Entwurf für erneuten Versuch gespeichert.';

  @override
  String get msgFailedToStartVoiceInput =>
      'Spracheingabe konnte nicht gestartet werden';

  @override
  String msgFilePathNotFound(String path) {
    return 'Datei nicht gefunden: $path';
  }

  @override
  String get msgFilteredLogsCopied =>
      'Gefilterte Protokolle in die Zwischenablage kopiert';

  @override
  String get msgInfoAgent => 'Agent';

  @override
  String get msgInfoCompaction => 'Kompaktierung';

  @override
  String msgInfoCost(double cost) {
    return 'Kosten: \\\$$cost';
  }

  @override
  String get msgInfoMessageInfo => 'Nachrichten-Info';

  @override
  String msgInfoModel(String modelId) {
    return 'Modell: $modelId';
  }

  @override
  String get msgInfoNoMetadata => 'Keine Metadaten verfügbar';

  @override
  String msgInfoPartDescriptionModel(String description, String model) {
    return '$description$model';
  }

  @override
  String get msgInfoPatch => 'Patch';

  @override
  String msgInfoProvider(String providerId) {
    return 'Anbieter: $providerId';
  }

  @override
  String get msgInfoRetry => 'Wiederholen';

  @override
  String get msgInfoSnapshot => 'Snapshot';

  @override
  String msgInfoSubtaskPartAgent(String agent) {
    return 'Teilaufgabe ($agent)';
  }

  @override
  String msgInfoTokens(int total) {
    return 'Token: $total';
  }

  @override
  String get msgInfoUndoThisTurn => 'Diesen Schritt rückgängig machen';

  @override
  String get msgInfoView => 'Ansehen';

  @override
  String get msgNoSystemSoundsFound =>
      'Auf diesem Gerät wurde kein Systemsound gefunden.';

  @override
  String get msgNoValidFilesSelected =>
      'Es wurden keine gültigen Dateien ausgewählt';

  @override
  String get msgSomeSelectedFilesNotAttached =>
      'Einige ausgewählte Dateien konnten nicht angehängt werden.';

  @override
  String get msgReadAloud => 'Vorlesen';

  @override
  String get msgReadAloudNotAvailable =>
      'Text-zu-Sprache ist auf diesem Gerät nicht verfügbar.';

  @override
  String get msgSetupDebugCopied =>
      'OpenCode-Einrichtungsdiagnose in die Zwischenablage kopiert';

  @override
  String get msgShareAsImage => 'Als Bild teilen';

  @override
  String get msgShareAsImageFailed =>
      'Nachricht konnte nicht als Bild geteilt werden.';

  @override
  String get msgShareAsImageSubject => 'CodeWalk-Nachricht';

  @override
  String get msgShareAsImageTooTall =>
      'Die Nachricht ist zu lang, um sie als Bild zu teilen.';

  @override
  String get msgStopReadAloud => 'Vorlesen stoppen';

  @override
  String get msgSystemSoundPickerUnavailable =>
      'Die Auswahl von Systemsounds ist auf dieser Plattform nicht verfügbar.';

  @override
  String get msgUpdatedButRefreshFailed =>
      'Servereinstellung aktualisiert, aber Chat-Anbieter konnten nicht neu geladen werden.';

  @override
  String get msgVoiceInputUnavailable =>
      'Spracheingabe ist auf diesem Gerät nicht verfügbar';

  @override
  String get notifAndroidBatteryOptimization => 'Android-Akkuoptimierung';

  @override
  String get notifConversationUpdates => 'Konversations-Updates';

  @override
  String get notifNotificationsArriveReopening =>
      'Wenn Benachrichtigungen nur beim erneuten Öffnen der App eingehen, erlauben Sie CodeWalk, ohne Optimierung auf diesem Gerät zu laufen.';

  @override
  String get notifResponseRunningKeep =>
      'Wenn eine Antwort ausgeführt wird, halten Sie die Echtzeit kurzzeitig aktiv, nachdem Sie die App verlassen haben.';

  @override
  String notifSelectedSoundLabel(String soundLabel) {
    return 'Ausgewählt: $soundLabel';
  }

  @override
  String get notificationAgentFinished =>
      'Der Agent hat die aktuelle Antwort beendet.';

  @override
  String get notificationConversationUpdates => 'Konversations-Updates';

  @override
  String get notificationOpenToClear =>
      'Öffnen Sie diese Konversation, um zugehörige Benachrichtigungen zu löschen.';

  @override
  String get notificationSession => 'Sitzung';

  @override
  String get notificationSoundLoadFailed =>
      'Android-Systemtöne konnten nicht geladen werden';

  @override
  String get onboardingAIGeneratedTitles => 'KI-generierte Titel';

  @override
  String get onboardingAddServerLater =>
      'Sie können einen Server später unter Einstellungen > Server hinzufügen.';

  @override
  String get onboardingAddedButHealthCheckFailed =>
      'Server hinzugefügt, aber der Integritätstest ist fehlgeschlagen. Er fährt möglicherweise noch hoch.';

  @override
  String get onboardingAlmostInstallOpenCode =>
      'Sie haben es fast geschafft. Installieren Sie zuerst OpenCode und verbinden Sie dann CodeWalk mit der Server-URL.';

  @override
  String onboardingAppProviderLocalSetupLogsLength(int length, int length2) {
    return '$length Setup-Protokollzeilen und $length2 Setup-Ereignisse sind im separaten Setup-Debug-Bildschirm verfügbar.';
  }

  @override
  String get onboardingAuthenticate => 'Authentifizieren';

  @override
  String get onboardingAvailable => 'verfügbar';

  @override
  String get onboardingAvailableOnlyDesktop =>
      'Nur auf dem Desktop verfügbar (Linux/macOS/Windows).';

  @override
  String get onboardingBasicAuthTip =>
      'Aktivieren Sie die Basis-Authentifizierung nur, wenn Ihr OpenCode-Server passwortgeschützt ist.';

  @override
  String get onboardingChooseAnotherPath => 'Anderen Pfad wählen';

  @override
  String get onboardingChooseHowToSetup =>
      'Wählen Sie, wie Sie Ihren Server einrichten möchten';

  @override
  String get onboardingClear => 'Löschen';

  @override
  String get onboardingCloudflareAuthFailed =>
      'Authentifizierung bei Cloudflare Access fehlgeschlagen.';

  @override
  String get onboardingCodeWalkAppOpenCode =>
      'CodeWalk ist die App. OpenCode ist die Engine, mit der sie sich verbindet.';

  @override
  String get onboardingConnectRunningServer =>
      'Mit einem laufenden Server verbinden';

  @override
  String get onboardingConnectionIssue => 'Verbindungsproblem';

  @override
  String get onboardingConnectionSaved =>
      'Serververbindung erfolgreich gespeichert.';

  @override
  String get onboardingConnectionTips => 'Verbindungstipps';

  @override
  String get onboardingConnectionUpdated =>
      'Serververbindung erfolgreich aktualisiert.';

  @override
  String get onboardingContinue => 'Weiter';

  @override
  String get onboardingContinueServerURL => 'Weiter zur Server-URL';

  @override
  String get onboardingCopyLoginURL => 'Login-URL kopieren';

  @override
  String get onboardingCouldNotVerify =>
      'Serververbindung konnte nicht verifiziert werden.';

  @override
  String get onboardingDefaultURLEmulator =>
      'Standard-URL, Emulator-Loopback, Authentifizierung und Fehlerbehebungshilfe.';

  @override
  String onboardingDesktopOnlyDiagnose(String appName) {
    return 'Nur Desktop: $appName kann OpenCode für Sie diagnostizieren, installieren und ausführen.';
  }

  @override
  String get onboardingDetailedSetupEvents =>
      'Detaillierte Einrichtungsereignisse wurden zur Fehlerbehebung erfasst.';

  @override
  String get onboardingDonShowAgain => 'Nicht mehr anzeigen';

  @override
  String get onboardingDone => 'Fertig';

  @override
  String get onboardingEditServer => 'Server bearbeiten';

  @override
  String get onboardingEditServerConnection => 'Serververbindung bearbeiten';

  @override
  String get onboardingEmulatorRemap =>
      'Im Android-Emulator werden localhost und 127.0.0.1 automatisch auf 10.0.2.2 umgeleitet.';

  @override
  String get onboardingEnterServerUrl => 'Server-URL eingeben';

  @override
  String get onboardingExisting => 'Vorhandenes verwenden';

  @override
  String get onboardingExplainInstallOpenCode =>
      'Erklären Sie, wie Sie OpenCode installieren, den Server starten und dann eine Verbindung von CodeWalk aus herstellen.';

  @override
  String get onboardingFailed => 'Fehlgeschlagen';

  @override
  String get onboardingGoodOptionDesktop => 'Gute erste Option auf dem Desktop';

  @override
  String get onboardingHealthCheckFailedMayBeStarting =>
      'Integritätstest des Servers fehlgeschlagen. Er fährt möglicherweise noch hoch.';

  @override
  String get onboardingInstallBinary => 'Binärdatei installieren';

  @override
  String get onboardingInstallBun => 'Über Bun installieren';

  @override
  String get onboardingInstallBunOpenCode => 'Bun + OpenCode installieren';

  @override
  String get onboardingInstallNpm => 'Über npm installieren';

  @override
  String get onboardingInstallRunOpenCode =>
      'Installieren und führen Sie OpenCode direkt aus CodeWalk auf dem Desktop aus.';

  @override
  String get onboardingInvalidUrl => 'Ungültige URL';

  @override
  String get onboardingLabel => 'Label (optional)';

  @override
  String get onboardingLabelHint => 'Mein Server';

  @override
  String onboardingLatestOutputAppProvider(String localServerLastOutput) {
    return 'Neueste Ausgabe: $localServerLastOutput';
  }

  @override
  String get onboardingLetCodeWalkSet => 'CodeWalk es lokal einrichten lassen';

  @override
  String get onboardingLocalServerSetup => 'Lokale Server-Einrichtung';

  @override
  String get onboardingManagedLocalServer => 'Verwalteter lokaler Server';

  @override
  String get onboardingManagedLocalServer2 =>
      'Der verwaltete lokale Servermodus ist nur auf Desktop-Builds verfügbar (Linux/macOS/Windows).';

  @override
  String onboardingNeedsOpenCodeServer(String appName) {
    return '$appName benötigt einen OpenCode-Server, bevor es Ihnen mit Ihrem Code helfen kann.';
  }

  @override
  String get onboardingNotAvailable => 'nicht verfügbar';

  @override
  String get onboardingNotWritable => 'nicht beschreibbar';

  @override
  String get onboardingOpenCode => 'Was ist OpenCode?';

  @override
  String get onboardingOpenCodeRunningDevice =>
      'Ich habe OpenCode bereits auf diesem Gerät oder irgendwo in meinem Netzwerk laufen.';

  @override
  String get onboardingOpenCodeRunsLocally =>
      'OpenCode läuft lokal oder auf einem Server und treibt die KI-Codierungsfunktionen in CodeWalk an. Wenn OpenCode bereits läuft, verbinden Sie sich damit. Wenn nicht, wählen Sie einen der geführten Einrichtungpfade unten.';

  @override
  String get onboardingOpenTailscaleLogin =>
      'Tailscale-Login-URL konnte nicht geöffnet werden.';

  @override
  String get onboardingPassword => 'Passwort';

  @override
  String get onboardingPasswordRequired => 'Passwort eingeben';

  @override
  String get onboardingPickSetupPath =>
      'Wählen Sie den Einrichtungspfad, der Ihrem aktuellen OpenCode-Setup entspricht.';

  @override
  String get onboardingPreconditionDirectoryNotWritable =>
      'Installationsverzeichnis ist nicht beschreibbar. Überprüfen Sie die Benutzerberechtigungen.';

  @override
  String get onboardingPreconditionInstallViaBunRecommendation =>
      'Die Installation über Bun wird von den OpenCode-Maintainern empfohlen.';

  @override
  String get onboardingPreconditionNetworkFailed =>
      'Netzwerkzugriff fehlgeschlagen. Überprüfen Sie die Verbindung, bevor Sie OpenCode installieren.';

  @override
  String get onboardingPreconditionNoRuntimeDetected =>
      'Keine Laufzeitumgebung erkannt. Installieren Sie das OpenCode-Binary direkt oder richten Sie zuerst Bun ein.';

  @override
  String get onboardingPreconditionNodeNpmAvailable =>
      'Node + npm sind verfügbar. Installieren Sie OpenCode über npm oder installieren Sie Bun für den empfohlenen Ablauf.';

  @override
  String get onboardingPreconditionOpenCodeAlreadyAvailable =>
      'OpenCode ist bereits verfügbar. Sie können den erkannten Befehl sofort verwenden.';

  @override
  String get onboardingPreconditionWindowsPathLagHint =>
      ' Unter Windows sollten Sie die Prüfungen nach der Installation aktualisieren, da PATH-Aktualisierungen in bereits geöffneten Anwendungen verzögert sein können.';

  @override
  String get onboardingPreconditionWindowsWslRecommendation =>
      'Windows-Build erkannt. WSL wird in den OpenCode-Dokumenten empfohlen, aber npm install kann als Ausweichlösung verwendet werden.';

  @override
  String get onboardingReachable => 'erreichbar';

  @override
  String get onboardingReady => 'Bereit';

  @override
  String get onboardingRecommendedOrderTry =>
      'Empfohlene Reihenfolge: Versuchen Sie „Bun + OpenCode installieren“, wenn CodeWalk alles für Sie einrichten soll. Verwenden Sie „Vorhandenes verwenden“, wenn OpenCode bereits installiert ist.';

  @override
  String get onboardingRefreshChecks => 'Prüfungen aktualisieren';

  @override
  String get onboardingRunDiagnosticsToVerify =>
      'Führen Sie eine Diagnose aus, um die lokalen OpenCode-Anforderungen zu überprüfen.';

  @override
  String get onboardingSaveAndTest => 'Speichern und testen';

  @override
  String get onboardingServerConnectedReady =>
      'Ihr Server ist verbunden und einsatzbereit.';

  @override
  String get onboardingServerConnection => 'Serververbindung';

  @override
  String get onboardingServerSettingsSaved =>
      'Ihre Servereinstellungen wurden gespeichert und die Integritätstests wurden aktualisiert.';

  @override
  String get onboardingServerSetup => 'Server-Einrichtung';

  @override
  String get onboardingServerUpdated => 'Server aktualisiert';

  @override
  String get onboardingServerUrl => 'Server-URL';

  @override
  String get onboardingSetup => 'Einrichtung';

  @override
  String get onboardingSetupWizard => 'Einrichtungsassistent';

  @override
  String get onboardingShowSetupSteps => 'Zeige mir die Einrichtungsschritte';

  @override
  String get onboardingShowSetupSteps2 => 'Einrichtungsschritte anzeigen';

  @override
  String get onboardingSkip => 'Vorerst überspringen';

  @override
  String get onboardingSkipSetup => 'Einrichtung überspringen?';

  @override
  String get onboardingStart => 'Start';

  @override
  String onboardingStartUsing(String appName) {
    return 'Beginnen Sie mit der Nutzung von $appName';
  }

  @override
  String get onboardingStarting => 'Startet';

  @override
  String get onboardingStop => 'Stopp';

  @override
  String get onboardingStopped => 'Gestoppt';

  @override
  String get onboardingStopping => 'Stoppt';

  @override
  String onboardingSuggestedUrl(String url) {
    return 'Vorgeschlagene lokale OpenCode-Server-URL: $url';
  }

  @override
  String get onboardingTailscaleAdminApproval =>
      'Administrator-Genehmigung für Tailscale erforderlich';

  @override
  String get onboardingTailscaleAuthAfterSave =>
      'Tailscale wird nach dem Speichern authentifiziert';

  @override
  String onboardingTailscaleAuthAfterSaveTest(String appName) {
    return 'Nachdem Sie diesen Server gespeichert und getestet haben, öffnet $appName den Tailscale-Login, falls dieses Gerät noch nicht authentifiziert ist.';
  }

  @override
  String get onboardingTailscaleConnected => 'Tailscale verbunden';

  @override
  String get onboardingTailscaleConnecting => 'Tailscale verbindet';

  @override
  String get onboardingTailscaleConnectionFailed =>
      'Tailscale-Verbindung fehlgeschlagen';

  @override
  String get onboardingTailscaleLoginRequired => 'Tailscale-Login erforderlich';

  @override
  String get onboardingTailscaleOpenLoginUrl =>
      'Öffnen Sie die Login-URL, um dieses Gerät zu Ihrem Tailnet hinzuzufügen. Wenn sich der Browser nicht geöffnet hat, kopieren Sie die unten stehende URL.';

  @override
  String get onboardingTailscaleUnsupported => 'Tailscale nicht unterstützt';

  @override
  String get onboardingTestConnection => 'Verbindung testen';

  @override
  String get onboardingTesting => 'Teste...';

  @override
  String get onboardingUnreachable => 'nicht erreichbar';

  @override
  String get onboardingUseBasicAuth => 'Basic Auth verwenden';

  @override
  String get onboardingUsername => 'Benutzername';

  @override
  String get onboardingUsernameRequired => 'Benutzername eingeben';

  @override
  String get onboardingUsesServerTitle =>
      'Verwendet den Titel-Agenten Ihres Servers, um Konversationen zu benennen';

  @override
  String get onboardingUsingDetectedCommand =>
      'Verwendung des erkannten OpenCode-Befehls.';

  @override
  String get onboardingViewSetupDebug => 'Einrichtungsdiagnose anzeigen';

  @override
  String onboardingWelcomeTo(String appName) {
    return 'Willkommen bei $appName';
  }

  @override
  String get onboardingWindowsTipInstalling =>
      'Tipp für Windows: Klicken Sie nach der Installation auf „Prüfungen aktualisieren“. Wenn die Erkennung immer noch fehlschlägt, öffnen Sie CodeWalk erneut, um PATH-Änderungen zu laden.';

  @override
  String get onboardingWritable => 'beschreibbar';

  @override
  String get onboardingYoureAllSet => 'Alles bereit!';

  @override
  String get permissionAllowOnce => 'Einmalig erlauben';

  @override
  String get permissionAlways => 'Immer';

  @override
  String get permissionBack => 'Zurück';

  @override
  String get permissionConfirmReject => 'Ablehnung bestätigen';

  @override
  String get permissionReject => 'Ablehnen';

  @override
  String get permissionReopen => 'Wieder öffnen';

  @override
  String get questionAnswerSelected => 'Keine Antwort ausgewählt.';

  @override
  String get questionCommaSeparatedValues => 'Kommagetrennte Werte';

  @override
  String get questionQuestionGroupMarked =>
      'Fragegruppe als abgelehnt markiert. Sie können weiterchatten und diese Gruppe jederzeit vor der Bestätigung wieder öffnen.';

  @override
  String get questionQuestionRequest => 'Frageanforderung';

  @override
  String get questionQuestionsProvidedSubmit =>
      'Keine Fragen bereitgestellt. Sie können eine leere Antwort übermitteln.';

  @override
  String get questionReviewAnswersSubmitting =>
      'Überprüfen Sie Ihre Antworten vor dem Absenden.';

  @override
  String get quotaAuthCookie => 'Authentifizierungs-Cookie';

  @override
  String get quotaConnect => 'Verbinden';

  @override
  String get quotaForget => 'Vergessen';

  @override
  String get quotaOpenCodeGoConnectDescription =>
      'Verbinden Sie das Nutzungs-Dashboard, um gleitende, wöchentliche und monatliche Limits anzuzeigen.';

  @override
  String get quotaOpenCodeGoDetected => 'OpenCode Go erkannt';

  @override
  String get quotaOpenCodeGoNeedsReconnect =>
      'OpenCode Go muss neu verbunden werden';

  @override
  String get quotaOpenCodeGoReconnectDescription =>
      'Aktualisieren Sie die Dashboard-Anmeldedaten, um die Nutzungsbalken wiederherzustellen.';

  @override
  String get quotaOpenCodeGoUsage => 'OpenCode-Go-Nutzung';

  @override
  String get quotaOpenDashboard => 'OpenCode-Dashboard öffnen';

  @override
  String get quotaPaceExplanation =>
      'Das Tempo prognostiziert die Gesamtnutzung am Ende des aktuellen Limitfensters anhand der aktuellen Rate.';

  @override
  String quotaPacePercent(String percent) {
    return 'Tempo $percent%';
  }

  @override
  String get quotaRateLimits => 'Nutzungslimits';

  @override
  String get quotaReconnect => 'Neu verbinden';

  @override
  String get quotaRefreshing => 'Aktualisierung...';

  @override
  String quotaResetsIn(String time) {
    return 'Wird in $time zurückgesetzt';
  }

  @override
  String get quotaSaving => 'Wird gespeichert...';

  @override
  String get quotaWorkspaceId => 'Arbeitsbereich-ID';

  @override
  String get serverClearOAuth => 'OAuth löschen';

  @override
  String get serverConnectionAttention =>
      'Serververbindung erfordert Aufmerksamkeit.';

  @override
  String get serverHealthHealthy => 'Verfügbar';

  @override
  String get serverHealthUnhealthy => 'Nicht verfügbar';

  @override
  String get serverHealthUnknown => 'Unbekannt';

  @override
  String get serverOAuthAuthFailed => 'OAuth-Authentifizierung fehlgeschlagen';

  @override
  String get serverOAuthChip => 'OAuth';

  @override
  String get serverOAuthNotSupported =>
      'Cloudflare Access OAuth wird auf dieser Plattform nicht unterstützt';

  @override
  String get serverReauthenticate => 'Erneut authentifizieren';

  @override
  String get serverTailscaleChip => 'Tailscale';

  @override
  String get serversActive => 'Aktiv';

  @override
  String get serversActiveServer => 'Aktiver Server';

  @override
  String get serversAddLeastOpenCode =>
      'Fügen Sie mindestens einen OpenCode-Server hinzu, um die App zu nutzen.';

  @override
  String get serversAddServer => 'Server hinzufügen';

  @override
  String get serversCancel => 'Abbrechen';

  @override
  String get serversCannotActivateUnhealthy =>
      'Ein fehlerhafter Server kann nicht aktiviert werden';

  @override
  String get serversCheckHealth => 'Status prüfen';

  @override
  String get serversClearDefault => 'Standard löschen';

  @override
  String serversCommandAppProviderLocalServerCommandPath(
    String localServerCommandPath,
  ) {
    return 'Befehl: $localServerCommandPath';
  }

  @override
  String get serversCopy => 'Kopieren';

  @override
  String get serversDefault => 'Standard';

  @override
  String get serversDelete => 'Löschen';

  @override
  String get serversDeleteServer => 'Server löschen';

  @override
  String get serversDesktopModeExplanation =>
      'Der Desktop-Modus kann `opencode serve` direkt von CodeWalk aus starten und verwalten.';

  @override
  String get serversEdit => 'Bearbeiten';

  @override
  String get serversLocalOpenCodeServer => 'Lokaler OpenCode-Server';

  @override
  String get serversManagedModeAvailable =>
      'Dieser verwaltete Modus ist nur auf Desktop-Builds verfügbar (Linux/macOS/Windows).';

  @override
  String get serversNoServersFound => 'Keine Server gefunden';

  @override
  String get serversRefreshHealth => 'Status aktualisieren';

  @override
  String serversRemoveProfileDisplayName(String displayName) {
    return '\"$displayName\" entfernen?';
  }

  @override
  String get serversSearchActiveHint => 'Aktiven Server durchsuchen';

  @override
  String get serversServersConfigured => 'Keine Server konfiguriert';

  @override
  String get serversSetActive => 'Als aktiv festlegen';

  @override
  String get serversSetDefault => 'Als Standard festlegen';

  @override
  String get serversSetupDebug => 'Einrichtungsdiagnose';

  @override
  String get serversSetupWizard => 'Einrichtungsassistent';

  @override
  String get serversTailscaleAdminApprovalRequired =>
      'Tailscale-Admin-Genehmigung erforderlich';

  @override
  String get serversTailscaleAuthRequired =>
      'Tailscale-Authentifizierung erforderlich';

  @override
  String get serversTailscaleConnectExplanation =>
      'Tailscale wird verbunden, wenn dieses aktive Profil verwendet wird.';

  @override
  String get serversTailscaleConnected => 'Tailscale verbunden';

  @override
  String get serversTailscaleConnecting => 'Tailscale verbindet';

  @override
  String get serversTailscaleConnectionFailed =>
      'Tailscale-Verbindung fehlgeschlagen';

  @override
  String get serversTailscaleDisconnected => 'Tailscale getrennt';

  @override
  String get serversTailscaleLoginExplanation =>
      'Öffnen Sie die Tailscale-Anmelde-URL, um dieses Gerät zu Ihrem Tailnet hinzuzufügen.';

  @override
  String get serversTailscaleTrafficExplanation =>
      'Der OpenCode-Datenverkehr für dieses aktive Profil wird über Tailscale geleitet.';

  @override
  String get serversTailscaleUnsupported => 'Tailscale nicht unterstützt';

  @override
  String get serversUnhealthyActivateError =>
      'Dieser Server ist fehlerhaft. Überprüfen Sie den Zustand oder bearbeiten Sie die Einstellungen vor der Aktivierung.';

  @override
  String get sessionActionArchived => 'archiviert';

  @override
  String get sessionActionDeleted => 'gelöscht';

  @override
  String get sessionActionForked => 'geforkt';

  @override
  String get sessionActionPinned => 'angeheftet';

  @override
  String get sessionActionUnarchived => 'dearchiviert';

  @override
  String get sessionActionUnpinned => 'gelöst';

  @override
  String get sessionArchive => 'Archivieren';

  @override
  String get sessionCancelRename => 'Umbenennen abbrechen';

  @override
  String sessionChildrenCount(int count) {
    return 'Unterkonversationen: $count';
  }

  @override
  String get sessionCompactContext => 'Kontext komprimieren';

  @override
  String get sessionCopyLink => 'Link kopieren';

  @override
  String get sessionDelete => 'Löschen';

  @override
  String sessionDeleteConfirm(String title) {
    return 'Möchtest du die Konversation \"$title\" wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.';
  }

  @override
  String get sessionDeleteTitle => 'Konversation löschen';

  @override
  String get sessionDiffChangedFile => 'Geänderte Datei';

  @override
  String get sessionDiffContentNotCaptured =>
      'Dateiinhalt nicht vom Server erfasst';

  @override
  String sessionDiffFilesChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien geändert',
      one: '1 Datei geändert',
    );
    return '$_temp0';
  }

  @override
  String sessionDiffFilesCount(int count) {
    return 'Diff-Dateien: $count';
  }

  @override
  String sessionDiffLinesAddedRemoved(int added, int removed) {
    return '+$added Zeilen hinzugefügt -$removed Zeilen entfernt';
  }

  @override
  String sessionDiffLinesCollapsed(int count) {
    return '$count Zeilen ausgeblendet — Tippen zum Aufklappen';
  }

  @override
  String get sessionDiffLoading => 'Loading changed files…';

  @override
  String get sessionDiffReview => 'Änderungen überprüfen';

  @override
  String get sessionDiffSplit => 'Geteilt';

  @override
  String get sessionDiffSummary => 'Zusammenfassung';

  @override
  String get sessionDiffUnified => 'Einheitlich';

  @override
  String get sessionExportAssistant => 'Assistent';

  @override
  String get sessionExportCanceled => 'Export abgebrochen';

  @override
  String get sessionExportDebugJson => 'Als Debug-JSON exportieren';

  @override
  String get sessionExportDebugJsonErrorClipboard =>
      'Datei konnte nicht gespeichert werden; Debug-JSON in Zwischenablage';

  @override
  String get sessionExportDebugJsonSaved => 'Debug-JSON-Export gespeichert';

  @override
  String get sessionExportDebugJsonTitle =>
      'Sitzung als Debug-JSON exportieren';

  @override
  String get sessionExportError => 'Fehler:';

  @override
  String get sessionExportInput => 'Eingabe:';

  @override
  String get sessionExportMarkdown => 'Als Markdown exportieren';

  @override
  String get sessionExportMarkdownErrorClipboard =>
      'Datei konnte nicht gespeichert werden; Markdown in Zwischenablage';

  @override
  String get sessionExportMarkdownSaved => 'Markdown-Export gespeichert';

  @override
  String get sessionExportMarkdownTitle => 'Sitzung als Markdown exportieren';

  @override
  String get sessionExportOutput => 'Ausgabe:';

  @override
  String get sessionExportUntitled => 'Unbenannte Sitzung';

  @override
  String get sessionExportUser => 'Benutzer';

  @override
  String get sessionFailedRename =>
      'Konversation konnte nicht umbenannt werden';

  @override
  String get sessionFailedUpdateArchive =>
      'Archivierungsstatus konnte nicht aktualisiert werden';

  @override
  String get sessionFailedUpdateSharing =>
      'Freigabestatus konnte nicht aktualisiert werden';

  @override
  String get sessionFork => 'Forken';

  @override
  String get sessionForkFailed => 'Konversation konnte nicht verzweigt werden';

  @override
  String get sessionForked => 'Konversation verzweigt';

  @override
  String sessionHasError(String title) {
    return '\"$title\" hat einen Fehler.';
  }

  @override
  String sessionHasNewReply(String title) {
    return '\"$title\" hat eine neue Antwort.';
  }

  @override
  String get sessionKeyboardShortcuts => 'Tastaturkurzbefehle';

  @override
  String sessionNeedsInput(String title) {
    return '\"$title\" benötigt deine Eingabe.';
  }

  @override
  String get sessionNoCachedConversations =>
      'Keine zwischengespeicherten Konversationen';

  @override
  String get sessionNoConversationsInProject =>
      'Keine Konversationen in diesem Projekt.';

  @override
  String get sessionNotAvailable =>
      'Die Konversation ist für dieses Projekt noch nicht verfügbar';

  @override
  String get sessionOpenProjectToLoad =>
      'Projekt öffnen, um Konversationen zu laden.';

  @override
  String get sessionPin => 'Anheften';

  @override
  String get sessionRename => 'Umbenennen';

  @override
  String get sessionRenameHint => 'Neuen Konversationsnamen eingeben';

  @override
  String get sessionRenameTitle => 'Konversation umbenennen';

  @override
  String get sessionSaveTitle => 'Titel speichern';

  @override
  String get sessionShare => 'Sitzung teilen';

  @override
  String get sessionShareAction => 'Teilen';

  @override
  String get sessionShareLinkCopied => 'Freigabe-Link kopiert';

  @override
  String get sessionShareLinkUnavailable =>
      'Teilen-Link für diese Sitzung nicht verfügbar';

  @override
  String get sessionShared => 'Konversation geteilt';

  @override
  String get sessionSyncing => 'Konversationen werden synchronisiert...';

  @override
  String get sessionTitleHint => 'Konversationstitel';

  @override
  String get sessionUnarchive => 'Dearchivieren';

  @override
  String get sessionUnpin => 'Anheften aufheben';

  @override
  String get sessionUnshare => 'Freigabe aufheben';

  @override
  String get sessionUnshareAction => 'Teilen aufheben';

  @override
  String get sessionUnshared => 'Konversation nicht mehr geteilt';

  @override
  String get sessionViewTasks => 'Aufgaben anzeigen';

  @override
  String get settingsAboutCheckForUpdates => 'Nach Updates suchen';

  @override
  String get settingsAboutCheckOnOpen => 'Beim Öffnen nach Updates suchen';

  @override
  String get settingsAboutCheckOnOpenDescription =>
      'Automatisch prüfen, wenn die App startet';

  @override
  String get settingsAboutChecking => 'Wird geprüft...';

  @override
  String get settingsAboutDescription => 'Version, Updates und Links';

  @override
  String get settingsAboutDismiss => 'Verwerfen';

  @override
  String settingsAboutDownloading(String percent) {
    return 'Wird heruntergeladen... $percent%';
  }

  @override
  String get settingsAboutEraseAllData => 'Alle Daten löschen und neu starten';

  @override
  String get settingsAboutInstallUpdate => 'Update installieren';

  @override
  String get settingsAboutInstalling => 'Wird installiert...';

  @override
  String settingsAboutLatestVersion(String version) {
    return 'v$version ist die neueste Version';
  }

  @override
  String get settingsAboutLoading => 'Wird geladen...';

  @override
  String get settingsAboutReplayChatTour => 'Chat-Tour wiederholen';

  @override
  String get settingsAboutReplayChatTourDescription =>
      'Einstellungen schließen und die geführte Chat-Tour anzeigen';

  @override
  String get settingsAboutResetApp => 'App zurücksetzen';

  @override
  String get settingsAboutResetAppQuestion => 'App zurücksetzen?';

  @override
  String get settingsAboutResetAppWarning =>
      'Dadurch werden alle Server, Einstellungen und zwischengespeicherten Daten gelöscht. Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get settingsAboutRetryInstall => 'Installation wiederholen';

  @override
  String get settingsAboutTapToCheck =>
      'Tippen, um nach neuen Versionen zu suchen';

  @override
  String get settingsAboutTitle => 'Über';

  @override
  String get settingsAboutUpToDate => 'Sie sind auf dem neuesten Stand';

  @override
  String settingsAboutUpdateAvailable(String version) {
    return 'Update verfügbar: v$version';
  }

  @override
  String get settingsAboutUpdateInstalled =>
      'Update installiert. Starten Sie die App neu, um es anzuwenden.';

  @override
  String settingsAboutUpdateVersionSummary(
    String installedVersion,
    String latestVersion,
  ) {
    return 'Aktuell: $installedVersion; verfügbar: v$latestVersion';
  }

  @override
  String get settingsAboutVersion => 'Version';

  @override
  String settingsAboutVersionBuild(String buildNumber, String version) {
    return '$version (Build $buildNumber)';
  }

  @override
  String get settingsAppearanceAmoledDark => 'AMOLED-Dunkelmodus';

  @override
  String get settingsAppearanceAmoledDarkActive =>
      'Verwenden Sie rein schwarze Oberflächen, während der Dunkelmodus aktiv ist.';

  @override
  String get settingsAppearanceAmoledDarkInactive =>
      'Wechseln Sie in den Dunkelmodus, um AMOLED-Oberflächen zu aktivieren.';

  @override
  String get settingsAppearanceBrandColor => 'Markenfarbe';

  @override
  String get settingsAppearanceBrandColorDynamicBlocked =>
      'Deaktivieren Sie Hintergrundbildfarben, um eine Markenfarbe auszuwählen.';

  @override
  String get settingsAppearanceBrandColorNormal =>
      'Wählen Sie eine Ausgangsfarbe für die App-Palette.';

  @override
  String get settingsAppearanceBrandColorPresetBlocked =>
      'Wechseln Sie zu CodeWalk Classic, um eine Markenfarbe auszuwählen.';

  @override
  String get settingsAppearanceChatFontScale => 'Conversation text size';

  @override
  String get settingsAppearanceChatFontScaleDescription =>
      'Scale the chat message and composer text on top of the system text size.';

  @override
  String get settingsAppearanceCodeWalkClassic => 'CodeWalk Classic';

  @override
  String get settingsAppearanceComposerTips => 'Composer-Tipps';

  @override
  String get settingsAppearanceComposerTipsDescription =>
      'Rotierende Tipps anzeigen oder ausblenden, während der Assistent nachdenkt.';

  @override
  String get settingsAppearanceContrast => 'Kontrast';

  @override
  String get settingsAppearanceContrastDynamicBlocked =>
      'Deaktivieren Sie Hintergrundbildfarben, um den Kontrast anzupassen.';

  @override
  String get settingsAppearanceContrastHigh => 'Hoch';

  @override
  String get settingsAppearanceContrastNormal =>
      'Passen Sie die Kontraststufe des Farbschemas an.';

  @override
  String get settingsAppearanceContrastPresetBlocked =>
      'Wechseln Sie zu CodeWalk Classic, um den Kontrast anzupassen.';

  @override
  String get settingsAppearanceContrastReduced => 'Reduziert';

  @override
  String get settingsAppearanceDark => 'Dunkel';

  @override
  String get settingsAppearanceDensity => 'Dichte';

  @override
  String get settingsAppearanceDensityDense => 'Kompakt';

  @override
  String get settingsAppearanceDensityDescription =>
      'Abstände und Komponentendichte in der gesamten App anwenden.';

  @override
  String get settingsAppearanceDensityExtraDense => 'Sehr kompakt';

  @override
  String get settingsAppearanceDensityExtraSpacious => 'Sehr geräumig';

  @override
  String get settingsAppearanceDensityNormal => 'Normal';

  @override
  String get settingsAppearanceDensitySpacious => 'Geräumig';

  @override
  String get settingsAppearanceDescription =>
      'Dichte und Sichtbarkeit von Timeline-Blasen';

  @override
  String get settingsAppearanceFontSize => 'Text size';

  @override
  String get settingsAppearanceFontSizeDescription =>
      'Adjust the size of system text, conversation text, and terminal text.';

  @override
  String get settingsAppearanceLight => 'Hell';

  @override
  String get settingsAppearanceMathRendering => 'Mathematik-Rendering';

  @override
  String get settingsAppearanceMathRenderingDescription =>
      'LaTeX-Mathematik-Ausdrücke als gesetzte Gleichungen in Chat-Nachrichten darstellen.';

  @override
  String get settingsAppearanceNoPresets =>
      'Keine voreingestellten Paletten gefunden';

  @override
  String get settingsAppearanceOpenCodePresets => 'OpenCode-Voreinstellungen';

  @override
  String get settingsAppearancePresetHelper =>
      'Spiegelt die offizielle integrierte Themenliste von OpenCode Web wider.';

  @override
  String get settingsAppearancePresetNote =>
      'Designfarben folgen nun dem offiziellen OpenCode Web-Register und steuern auch Markdown- und Code-Oberflächen.';

  @override
  String get settingsAppearancePresetPalette => 'Voreingestellte Palette';

  @override
  String get settingsAppearanceSearchPreset =>
      'Nach voreingestellter Palette suchen';

  @override
  String get settingsAppearanceSectionDescription =>
      'Passen Sie die visuelle Dichte und die Nachrichtenoberflächen an Ihren Workflow an.';

  @override
  String get settingsAppearanceSectionTitle => 'Erscheinungsbild';

  @override
  String get settingsAppearanceSystem => 'System';

  @override
  String get settingsAppearanceSystemFontScale => 'System text size';

  @override
  String get settingsAppearanceSystemFontScaleDescription =>
      'Scale all text in the app shell, including menus, dialogs, and sidebars.';

  @override
  String get settingsAppearanceTaskList => 'Aufgabenliste';

  @override
  String get settingsAppearanceTaskListDescription =>
      'Sitzungsaufgabenlisten-Widget anzeigen oder ausblenden.';

  @override
  String get settingsAppearanceTerminalFontSize => 'Terminal text size';

  @override
  String get settingsAppearanceTerminalFontSizeDescription =>
      'Resize the embedded terminal font. Applies immediately to running sessions.';

  @override
  String get settingsAppearanceTheme => 'Design';

  @override
  String get settingsAppearanceThemeDescription =>
      'Wählen Sie den hellen, dunklen oder Systemmodus, behalten Sie die klassische CodeWalk-Palette bei oder wechseln Sie zu einer OpenCode-Voreinstellung.';

  @override
  String get settingsAppearanceVisualStyle => 'Visueller Stil';

  @override
  String get settingsAppearanceVisualStyleDescription =>
      'Wählen Sie die klassische Optik oder weichere verfeinerte Oberflächen.';

  @override
  String get settingsAppearanceVisualStyleClassic => 'Klassisch';

  @override
  String get settingsAppearanceVisualStyleRefined => 'Verfeinert';

  @override
  String get settingsAppearanceThinkingBubbles => 'Denkblasen';

  @override
  String get settingsAppearanceThinkingBubblesDescription =>
      'Gedankengänge-Blöcke in Assistenten-Nachrichten anzeigen oder ausblenden.';

  @override
  String get settingsAppearanceTitle => 'Erscheinungsbild';

  @override
  String get settingsAppearanceToolCallBubbles => 'Toolaufruf-Blasen';

  @override
  String get settingsAppearanceToolCallBubblesDescription =>
      'Tool-Ausführungskarten in Assistenten-Nachrichten anzeigen oder ausblenden.';

  @override
  String get settingsAppearanceWallpaperColors =>
      'Hintergrundbildfarben verwenden';

  @override
  String get settingsAppearanceWallpaperNormal =>
      'Farbschema aus Ihrem Geräte-Hintergrundbild extrahieren.';

  @override
  String get settingsAppearanceWallpaperPresetBlocked =>
      'Wechseln Sie zu CodeWalk Classic, um Hintergrundbildfarben zu verwenden.';

  @override
  String get settingsAppearanceWindowChrome => 'Fenster-Tabs';

  @override
  String get settingsAppearanceWindowChromeDescription =>
      'Legen Sie fest, wie Sitzungs-Tabs und Titelleiste auf dem Desktop kombiniert werden.';

  @override
  String get settingsAppearanceWindowChromeIntegrated => 'Integrierte Tabs';

  @override
  String get settingsAppearanceWindowChromeIntegratedDescription =>
      'Die Tabs sitzen oben im Fenster und die Titelleiste des Systems wird ausgeblendet.';

  @override
  String get settingsAppearanceWindowChromeSystem => 'Systemdekoration';

  @override
  String get settingsAppearanceWindowChromeSystemDescription =>
      'Behält die native Titelleiste und zeigt die Tabs unter der App-Leiste.';

  @override
  String get settingsBack => 'Zurück';

  @override
  String get settingsBehaviorAutoupdateCaveat =>
      'Verwenden Sie „Über“ für CodeWalk-Release-Prüfungen. Diese Einstellung spiegelt nur die offizielle OpenCode-`autoupdate`-Konfiguration wider.';

  @override
  String get settingsBehaviorAutoupdateHelp =>
      'Steuert Upstream-OpenCode-Laufzeit-Updates, nicht CodeWalk-App-Update-Prüfungen.';

  @override
  String get settingsBehaviorCellularDataSaver => 'Mobile Dateneinsparung';

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
      'CodeWalk wird diese OpenCode-Einstellung anwenden, nachdem die aktuelle Antwort abgeschlossen ist.';

  @override
  String settingsBehaviorConfigUpdateFailed(String field) {
    return 'OpenCode-$field konnte nicht aktualisiert werden.';
  }

  @override
  String get settingsBehaviorConversationUsername =>
      'Konversations-Benutzername';

  @override
  String get settingsBehaviorConversationUsernameHelp =>
      'Benutzerdefinierter Anzeigename, der in Konversationen anstelle des System-Benutzernamens angezeigt wird.';

  @override
  String get settingsBehaviorDataSaverActive =>
      'Jetzt auf mobilen Daten aktiv.';

  @override
  String get settingsBehaviorDataSaverCellularOnly =>
      'Gilt nur, wenn die Verbindung mobil ist.';

  @override
  String get settingsBehaviorDataSaverDescription =>
      'Reduziert die automatische mobile Datennutzung, indem Hintergrund-Downloads gestoppt und automatische Vordergrund-Aktualisierungen gedrosselt werden.';

  @override
  String get settingsBehaviorDataSaverWaiting =>
      'Warten auf das nächste Synchronisationsfenster für mobile Daten.';

  @override
  String get settingsBehaviorDefaultAgent => 'Standard-Agent';

  @override
  String get settingsBehaviorDefaultAgentHelp =>
      'Primärer Agent, der verwendet wird, wenn kein Agent explizit ausgewählt ist.';

  @override
  String get settingsBehaviorDefaultModel => 'Standardmodell';

  @override
  String get settingsBehaviorDefaultModelHelp =>
      'Wird über die Konfiguration mit anderen OpenCode-Clients geteilt.';

  @override
  String get settingsBehaviorDescription =>
      'OpenCode-Standardwerte, Provenienz und Composer-Sync-Sicherheit';

  @override
  String get settingsBehaviorEnableDataSaver =>
      'Mobile Dateneinsparung aktivieren';

  @override
  String get settingsBehaviorMultiDeviceSync =>
      'Experimentelle Multi-Geräte-Synchronisierung aktivieren';

  @override
  String get settingsBehaviorMultiDeviceSyncDescription =>
      'Composer-Auswahl (Agent/Modell/Variante) mit der aktiven Serverkonfiguration synchronisieren.';

  @override
  String get settingsBehaviorMultiDeviceSyncWarning =>
      'Kann laufende Sitzungen abbrechen, wenn gleichzeitig in mehr als einer Sitzung gearbeitet wird.';

  @override
  String get settingsBehaviorNoAgents => 'Keine Agenten gefunden';

  @override
  String get settingsBehaviorNoModels => 'Keine Modelle gefunden';

  @override
  String get settingsBehaviorOpenCodeAutoupdate =>
      'Automatische OpenCode-Aktualisierung';

  @override
  String get settingsBehaviorOpenCodeDefaults =>
      'OpenCode-gestützte Standardwerte';

  @override
  String get settingsBehaviorOpenCodeDefaultsDescription =>
      'Diese Werte werden in `/config` auf dem aktiven Server geschrieben und entsprechen der offiziellen geteilten OpenCode-Konfiguration.';

  @override
  String get settingsBehaviorOpenCodeSnapshots => 'OpenCode-Snapshots';

  @override
  String get settingsBehaviorOpenCodeSnapshotsDescription =>
      'Git-gestützte Upstream-Snapshots für Rückgängig/Wiederholen und den Wiederherstellungsverlauf aktiviert lassen.';

  @override
  String get settingsBehaviorPermissionDeferred =>
      'Die erweiterte Bearbeitung von Berechtigungsregeln bleibt vorerst außerhalb der Einstellungen und wird auf spätere Paritätsarbeiten verschoben.';

  @override
  String get settingsBehaviorPermissionProvenance =>
      'Provenienz der Rechtebehandlung';

  @override
  String get settingsBehaviorPermissionProvenanceDescription =>
      'Die offizielle OpenCode-Berechtigungsrichtlinie ist in `opencode.json` mit Erlauben/Fragen/Ablehnen-Regeln pro Tool konfiguriert. CodeWalk behält die offiziellen Berechtigungsanforderungskarten bei und fügt eine genehmigte ADR-023-Ausnahme hinzu: Der Composer-Schalter für automatische Genehmigung antwortet bedingungslos mit `Always` und `remember: true` unconditionally to create durable session-scoped grants, und hält denselben threadbezogenen Kontinuitätspfad im Android-Hintergrund-Worker aktiv.';

  @override
  String get settingsBehaviorRefreshDefaults => 'Standardwerte aktualisieren';

  @override
  String get settingsBehaviorSaveUsername => 'Benutzername speichern';

  @override
  String get settingsBehaviorSearchAutoupdate =>
      'Nach automatischem Update-Modus suchen';

  @override
  String get settingsBehaviorSearchDefaultAgent => 'Standard-Agent suchen';

  @override
  String get settingsBehaviorSearchDefaultModel => 'Standardmodell suchen';

  @override
  String get settingsBehaviorSearchShareMode => 'Freigabemodus suchen';

  @override
  String get settingsBehaviorSearchSmallModel => 'Kleines Modell suchen';

  @override
  String get settingsBehaviorShareMode => 'OpenCode-Standardfreigabe';

  @override
  String get settingsBehaviorShareModeCaveat =>
      'Verwenden Sie die Freigabeaktion auf Chat-Ebene, um jetzt eine Sitzung zu veröffentlichen. Diese Einstellung ändert nur die Standardfreigaberichtlinie von OpenCode.';

  @override
  String get settingsBehaviorShareModeHelp =>
      'Steuert die offizielle globale `share`-Konfiguration, nicht den Freigabe-Button für einen einzelnen Chat.';

  @override
  String get settingsBehaviorSmallModel => 'Kleines Modell';

  @override
  String get settingsBehaviorSmallModelAutoFallback => 'Automatischer Fallback';

  @override
  String get settingsBehaviorSmallModelFallbackActive =>
      'Der automatische OpenCode-Fallback ist aktiv, da `small_model` nicht festgelegt ist.';

  @override
  String get settingsBehaviorSmallModelHelp =>
      'Verwendet für leichtgewichtige Aufgaben wie die Titelgenerierung.';

  @override
  String get settingsBehaviorSmallModelResetCaveat =>
      'Das Zurücksetzen von `small_model` auf den automatischen Fallback erfordert weiterhin das Bearbeiten der Konfiguration außerhalb der App, da `/config`-Patch-Updates keine Schlüssel entfernen können.';

  @override
  String get settingsBehaviorSnapshotCaveat =>
      'Dies steuert den OpenCode-Snapshot-Speicher und die Rückgängig/Wiederholen-Unterstützung, nicht die lokalen Cache-Snapshots von CodeWalk.';

  @override
  String get settingsBehaviorTitle => 'Verhalten';

  @override
  String get settingsBehaviorUsernameFallback =>
      'OpenCode verwendet den System-Benutzernamen, da `username` nicht festgelegt ist.';

  @override
  String get settingsBehaviorUsernamePatchCaveat =>
      'Das Zurücksetzen von `username` auf den Systemstandard erfordert weiterhin das Bearbeiten der Konfiguration außerhalb der App, da `/config`-Patch-Updates keine Schlüssel entfernen können.';

  @override
  String get settingsConfigRefreshFailed =>
      'Servereinstellung aktualisiert, aber Chat-Anbieter konnten nicht neu geladen werden.';

  @override
  String get settingsConfigUpdateDeferred =>
      'CodeWalk wird diese OpenCode-Einstellung anwenden, nachdem die aktuelle Antwort abgeschlossen ist.';

  @override
  String get settingsConversationUsername => 'Konversations-Benutzername';

  @override
  String get settingsDefaultAgent => 'Standardagent';

  @override
  String get settingsDefaultModel => 'Standardmodell';

  @override
  String get settingsLanguageDescription =>
      'Wählen Sie die von CodeWalk verwendete Sprache. Die Systemvorgabe folgt Ihrer Gerätesprache.';

  @override
  String get settingsLanguageEmptyText => 'Keine Sprachen gefunden';

  @override
  String get settingsLanguageFieldHelper =>
      'Wird sofort angewendet und bleibt auch nach Neustarts bestehen.';

  @override
  String get settingsLanguageFieldLabel => 'App-Sprache';

  @override
  String get settingsLanguageSearchHint => 'Sprachen suchen';

  @override
  String get settingsLanguageSystemDefault => 'Systemvorgabe';

  @override
  String get settingsLanguageTitle => 'Sprache';

  @override
  String get settingsLogsDescription =>
      'Laufzeitdiagnose und Fehlerbehebungsdaten';

  @override
  String get settingsLogsTitle => 'Registros';

  @override
  String get settingsNoAgentsFound => 'Keine Agenten gefunden';

  @override
  String get settingsNotificationsAgentSubtitle =>
      'Wenn eine Antwort abgeschlossen ist';

  @override
  String get settingsNotificationsAgentUpdates => 'Agenten-Updates';

  @override
  String get settingsNotificationsAnotherConversation => 'Andere Konversation';

  @override
  String get settingsNotificationsAppInBackground => 'App im Hintergrund';

  @override
  String get settingsNotificationsBackgroundAlerts =>
      'Android-Hintergrundbenachrichtigungen';

  @override
  String get settingsNotificationsBackgroundBehavior => 'Hintergrundverhalten';

  @override
  String get settingsNotificationsBackgroundBehaviorDescription =>
      'Wählen Sie, wie sich CodeWalk verhält, wenn die App den Vordergrund verlässt.';

  @override
  String get settingsNotificationsBackgroundDescription =>
      'Verwenden Sie eine datensparende Hintergrundüberwachung für Antwortabschlüsse, Berechtigungsanfragen, Fragen und Fehler, wenn die App nicht auf dem Bildschirm ist.';

  @override
  String get settingsNotificationsBackgroundToggle =>
      'Hintergrundbenachrichtigungen auf Android';

  @override
  String get settingsNotificationsBackgroundToggleDescription =>
      'Schalten Sie alle Android-Hintergrundprüfungen aus und blenden Sie die dauerhafte Überwachungsbenachrichtigung aus.';

  @override
  String get settingsNotificationsBatteryDescription =>
      'Wenn Benachrichtigungen nur beim erneuten Öffnen der App eingehen, erlauben Sie CodeWalk, ohne Optimierung auf diesem Gerät zu laufen.';

  @override
  String get settingsNotificationsBatteryDisabled =>
      'Die Akkuoptimierung ist für CodeWalk deaktiviert.';

  @override
  String get settingsNotificationsBatteryEnabled =>
      'Die Akkuoptimierung ist aktiviert. Einige Geräte verzögern möglicherweise Hintergrundbenachrichtigungen.';

  @override
  String get settingsNotificationsBatteryOptimization =>
      'Android-Akkuoptimierung';

  @override
  String get settingsNotificationsBatteryUnknown =>
      'Akkuoptimierungsstatus konnte noch nicht gelesen werden.';

  @override
  String get settingsNotificationsChooseAudioFile => 'Audiodatei auswählen';

  @override
  String get settingsNotificationsChooseSystemSound => 'Systemsound auswählen';

  @override
  String get settingsNotificationsCloseToTray => 'In die Taskleiste schließen';

  @override
  String get settingsNotificationsCloseToTrayDescription =>
      'Fenster ausblenden und in der Systemleiste weiterlaufen lassen.';

  @override
  String get settingsNotificationsDescription =>
      'Benachrichtigungs- und Soundeinstellungen pro Kategorie';

  @override
  String get settingsNotificationsDisableOptimization =>
      'Optimierung deaktivieren';

  @override
  String get settingsNotificationsErrors => 'Fehler';

  @override
  String get settingsNotificationsErrorsSubtitle =>
      'Wenn eine Sitzung einen Fehler meldet';

  @override
  String get settingsNotificationsJustClose => 'Einfach schließen';

  @override
  String get settingsNotificationsJustCloseDescription =>
      'Die Anwendung vollständig beenden.';

  @override
  String get settingsNotificationsKeepLive =>
      'Benachrichtigungen für 3 Min. aktiv halten';

  @override
  String get settingsNotificationsKeepLiveDescription =>
      'Wenn bereits eine Antwort läuft, halten Sie die Echtzeit nach dem Verlassen der App kurzzeitig aktiv.';

  @override
  String get settingsNotificationsLocal => 'Lokal';

  @override
  String get settingsNotificationsMinimizeWhenClose =>
      'Beim Schließen minimieren';

  @override
  String get settingsNotificationsMinimizeWhenCloseDescription =>
      'In die Taskleiste/das Dock minimieren und weiterlaufen lassen.';

  @override
  String get settingsNotificationsNoCondition =>
      'Wenn keine Bedingung ausgewählt ist, sind Benachrichtigungen in jedem Kontext zulässig.';

  @override
  String get settingsNotificationsNotify => 'Benachrichtigen';

  @override
  String get settingsNotificationsNotifyOnlyWhen => 'Benachrichtigen nur wenn';

  @override
  String get settingsNotificationsOpenBatterySettings =>
      'Akkueinstellungen öffnen';

  @override
  String get settingsNotificationsPermissions => 'Berechtigungen und Fragen';

  @override
  String get settingsNotificationsPermissionsSubtitle =>
      'Wenn Tools Ihre Eingabe anfordern';

  @override
  String get settingsNotificationsPreview => 'Vorschau';

  @override
  String get settingsNotificationsRefreshStatus => 'Status aktualisieren';

  @override
  String get settingsNotificationsSearchSoundType => 'Nach Soundtyp suchen';

  @override
  String get settingsNotificationsSectionDescription =>
      'Steuern Sie, wann Benachrichtigungen angezeigt und wann Töne abgespielt werden können.';

  @override
  String get settingsNotificationsSectionTitle => 'Benachrichtigungen';

  @override
  String settingsNotificationsSelectedSound(String label) {
    return 'Ausgewählt: $label';
  }

  @override
  String get settingsNotificationsServer => 'Server';

  @override
  String get settingsNotificationsSound => 'Sound';

  @override
  String get settingsNotificationsSoundBuiltInAlert => 'Integrierter Alarm';

  @override
  String get settingsNotificationsSoundBuiltInClick => 'Integrierter Klick';

  @override
  String get settingsNotificationsSoundOff => 'Aus';

  @override
  String get settingsNotificationsSoundOnlyWhen => 'Sound nur wenn';

  @override
  String get settingsNotificationsSoundPickAudioFile => 'Audiodatei auswählen';

  @override
  String get settingsNotificationsSoundPickFromSystem => 'Vom System auswählen';

  @override
  String get settingsNotificationsSoundSystemDefault => 'Systemstandard';

  @override
  String get settingsNotificationsSoundType => 'Soundtyp';

  @override
  String get settingsNotificationsSyncInfo =>
      'Einige Kategorie-Ein/Aus-Schalter werden von `/config` auf dem aktiven Server synchronisiert.';

  @override
  String get settingsNotificationsSyncInfoLocal =>
      'Der aktuelle Server stellt keine Benachrichtigungsschalter in `/config` bereit; lokale Werte sind aktiv.';

  @override
  String get settingsNotificationsSystemSoundPickerTitle =>
      'Systemsound auswählen';

  @override
  String get settingsNotificationsTitle => 'Benachrichtigungen';

  @override
  String get settingsNotificationsWhenClosing => 'Beim Schließen des Fensters';

  @override
  String get settingsOpenCodeAutoUpdate => 'OpenCode Auto-Update';

  @override
  String get settingsOpenCodeSharingDefault => 'OpenCode Freigabe-Standard';

  @override
  String get settingsReadAloudEnabled => 'Vorlesen';

  @override
  String get settingsReadAloudEnabledDescription =>
      'Schaltfläche „Vorlesen“ bei Assistenten-Nachrichten anzeigen.';

  @override
  String get settingsReadAloudPitch => 'Tonhöhe';

  @override
  String get settingsReadAloudPitchDescription =>
      'Tonhöhe der Stimme anpassen.';

  @override
  String get settingsReadAloudSectionDescription =>
      'Assistenten-Antworten vorlesen. Geschwindigkeit, Tonhöhe und Stimme konfigurieren.';

  @override
  String get settingsReadAloudSectionTitle => 'Text zu Sprache';

  @override
  String get settingsReadAloudSpeed => 'Geschwindigkeit';

  @override
  String get settingsReadAloudSpeedDescription =>
      'Sprechgeschwindigkeit anpassen.';

  @override
  String get settingsReadAloudVoice => 'Stimme';

  @override
  String get settingsReadAloudVoiceHint => 'Stimme zum Vorlesen auswählen.';

  @override
  String get settingsSearchAutoUpdateMode => 'Auto-Update-Modus suchen';

  @override
  String get settingsSearchDefaultAgent => 'Standardagent suchen';

  @override
  String get settingsSearchDefaultModel => 'Standardmodell suchen';

  @override
  String get settingsSearchSharingMode => 'Freigabe-Modus suchen';

  @override
  String get settingsSearchSmallModel => 'Kleines Modell suchen';

  @override
  String get settingsServersActive => 'Aktiv';

  @override
  String get settingsServersChooseActive => 'Aktiven Server auswählen';

  @override
  String get settingsServersDefault => 'Standard';

  @override
  String get settingsServersDescription => 'OpenCode-Server und Health-Routing';

  @override
  String get settingsServersTitle => 'Server';

  @override
  String get settingsSessionAttentionSize => 'Bubble-Größe';

  @override
  String get settingsSessionAttentionSizeExtraLarge => 'Sehr groß';

  @override
  String get settingsSessionAttentionSizeExtraSmall => 'Sehr klein';

  @override
  String get settingsSessionAttentionSizeLarge => 'Groß';

  @override
  String get settingsSessionAttentionSizeSmall => 'Klein';

  @override
  String get settingsSessionAttentionSizeStandard => 'Standard';

  @override
  String get settingsSetupWizard => 'Einrichtungsassistent';

  @override
  String get settingsShortcutsDescription => 'Tragbare App-Tastenbelegungen';

  @override
  String get settingsShortcutsEdit => 'Kurzbefehl bearbeiten';

  @override
  String get settingsShortcutsKeyboard => 'Tastaturkurzbefehle';

  @override
  String get settingsShortcutsReset => 'Kurzbefehl zurücksetzen';

  @override
  String get settingsShortcutsSearch => 'Kurzbefehle suchen';

  @override
  String get settingsShortcutsTitle => 'Tastaturkurzbefehle';

  @override
  String get settingsSmallModel => 'Kleines Modell';

  @override
  String get settingsSmallModelResetExplanation =>
      'Das Zurücksetzen von `small_model` auf den automatischen Fallback erfordert weiterhin das Bearbeiten der Konfiguration außerhalb der App, da `/config`-Patch-Updates keine Schlüssel entfernen können.';

  @override
  String get settingsSmallModelUnsetExplanation =>
      'OpenCode-Automatischer Fallback ist aktiv, da `small_model` nicht gesetzt ist.';

  @override
  String get settingsSoundPickerNotAvailable =>
      'System-Tonauswahl ist auf dieser Plattform nicht verfügbar.';

  @override
  String get settingsSpeechDescription =>
      'Engine, Stille-Timeout und Modelloptionen';

  @override
  String get settingsSpeechRefreshStatus => 'Status aktualisieren';

  @override
  String settingsSpeechSilenceTimeout(String value) {
    return 'Stille-Timeout: ${value}s';
  }

  @override
  String get settingsSpeechTitle => 'Sprache zu Text';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsUsernameClearHint =>
      'Das Löschen des OpenCode-Konversations-Benutzernamens erfordert weiterhin das Bearbeiten der Konfiguration außerhalb der App.';

  @override
  String get settingsUsernameEnterHint =>
      'Geben Sie einen Benutzernamen ein, um einen benutzerdefinierten OpenCode-Konversationsnamen zu speichern.';

  @override
  String get settingsUsernameResetExplanation =>
      'Das Zurücksetzen von `username` auf den Systemstandard erfordert weiterhin das Bearbeiten der Konfiguration außerhalb der App, da `/config`-Patch-Updates keine Schlüssel entfernen können.';

  @override
  String get settingsUsernameUnsetExplanation =>
      'OpenCode verwendet den Systembenutzernamen, da `username` nicht gesetzt ist.';

  @override
  String get setupDebugBun => 'Bun';

  @override
  String get setupDebugBun2 => 'Bun';

  @override
  String get setupDebugCapturedSetupDetails =>
      'Noch keine Einrichtungsdetails erfasst';

  @override
  String get setupDebugCapturedSetupLogs => 'Erfasste Einrichtungsprotokolle';

  @override
  String get setupDebugClear => 'Einrichtungsdiagnose löschen';

  @override
  String get setupDebugClearSetupDebug => 'Einrichtungsdiagnose löschen';

  @override
  String get setupDebugCodeWalkCaptureEnough =>
      'Wenn CodeWalk nicht genügend Kontext erfasst hat, überprüfen Sie die offiziellen OpenCode-Protokolle und Health-Endpunkte direkt:';

  @override
  String get setupDebugCommandPath => 'Befehlspfad';

  @override
  String get setupDebugCommandPath2 => 'Befehlspfad';

  @override
  String get setupDebugCopy => 'Einrichtungsdiagnose kopieren';

  @override
  String get setupDebugCopySetupDebug => 'Einrichtungsdiagnose kopieren';

  @override
  String get setupDebugCurrentStatus => 'Aktueller Status';

  @override
  String get setupDebugDiagnosticsLoading => 'Diagnosen werden noch geladen.';

  @override
  String get setupDebugEnvironment => 'Umgebungsdiagnose';

  @override
  String get setupDebugEnvironmentDiagnostics => 'Umgebungsdiagnose';

  @override
  String get setupDebugFocusedOpenCodeSetup => 'Fokus auf OpenCode-Einrichtung';

  @override
  String get setupDebugInstallDir => 'Installationsverzeichnis';

  @override
  String get setupDebugInstallDirectory => 'Installationsverzeichnis';

  @override
  String get setupDebugLatestLocalServer => 'Letzte lokale Serverausgabe';

  @override
  String get setupDebugLogs => 'Erfasste Einrichtungsprotokolle';

  @override
  String get setupDebugManual => 'Manuelle Fehlerbehebung';

  @override
  String get setupDebugManualTroubleshooting => 'Manuelle Fehlerbehebung';

  @override
  String get setupDebugNetwork => 'Netzwerk';

  @override
  String get setupDebugNetwork2 => 'Netzwerk';

  @override
  String get setupDebugNoDetails => 'Noch keine Einrichtungsdetails erfasst';

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
  String get setupDebugOpenCodeSetupDebug => 'OpenCode-Einrichtungsdiagnose';

  @override
  String get setupDebugPlatform => 'Plattform';

  @override
  String get setupDebugPlatform2 => 'Plattform';

  @override
  String get setupDebugRunDiagnosticsTry =>
      'Führen Sie Diagnosen aus, versuchen Sie eine Installationsmethode oder starten Sie einen Einrichtungsfluss, um hier OpenCode-spezifische Fehlerbehebungsdetails zu erfassen.';

  @override
  String get setupDebugScreenCoversOpenCode =>
      'Dieser Bildschirm deckt nur die OpenCode-Installation, Diagnose und Fehlerbehebung bei der lokalen Einrichtung ab. Verwenden Sie App-Protokolle für allgemeine CodeWalk-Laufzeitprobleme.';

  @override
  String get setupDebugServerOutput => 'Letzte lokale Serverausgabe';

  @override
  String get setupDebugStatus => 'Aktueller Status';

  @override
  String setupDebugTimeEntrySource(String source, String time) {
    return '$time - $source';
  }

  @override
  String get setupDebugTimeline => 'Timeline';

  @override
  String get setupDebugTimeline2 => 'Timeline';

  @override
  String get setupDebugTitle => 'Fokus auf OpenCode-Einrichtung';

  @override
  String get setupDebugWSL => 'WSL';

  @override
  String get setupDebugWsl => 'WSL';

  @override
  String get shortcutCloseApp => 'Tab/Anwendung schließen';

  @override
  String get shortcutCloseAppDesc =>
      'Den aktuellen Sitzungstab schließen, wenn verfügbar; andernfalls die App mit dem Standardverhalten der Plattform schließen';

  @override
  String get shortcutFocusCloseDrawer => 'Seitenleiste fokussieren/schließen';

  @override
  String get shortcutFocusCloseDrawerDesc =>
      'Eingabe standardmäßig fokussieren oder Seitenleiste schließen, falls offen';

  @override
  String get shortcutFocusInput => 'Eingabe fokussieren';

  @override
  String get shortcutFocusInputDesc => 'Fokus auf die Texteingabe verschieben';

  @override
  String get shortcutGroupApplication => 'Anwendung';

  @override
  String get shortcutGroupGeneral => 'Allgemein';

  @override
  String get shortcutGroupModelAndAgent => 'Modell und Agent';

  @override
  String get shortcutGroupNavigation => 'Navigation';

  @override
  String get shortcutGroupPrompt => 'Prompt';

  @override
  String get shortcutGroupSession => 'Sitzung';

  @override
  String get shortcutNewConversation => 'Neue Konversation';

  @override
  String get shortcutNewConversationDesc => 'Eine neue Chat-Sitzung erstellen';

  @override
  String get shortcutNextAgent => 'Nächster Agent';

  @override
  String get shortcutNextAgentDesc =>
      'Zum nächsten verfügbaren Agenten wechseln';

  @override
  String get shortcutNextRecentModel => 'Nächstes kürzliches Modell';

  @override
  String get shortcutNextRecentModelDesc =>
      'Durch kürzlich verwendete Modelle wechseln';

  @override
  String get shortcutNextVariant => 'Nächste Variante';

  @override
  String get shortcutNextVariantDesc =>
      'Durch verfügbare Modellvarianten wechseln';

  @override
  String get shortcutOpenSettings => 'Einstellungen öffnen';

  @override
  String get shortcutOpenSettingsDesc => 'Einstellungsseite öffnen';

  @override
  String get shortcutPreviousAgent => 'Vorheriger Agent';

  @override
  String get shortcutPreviousAgentDesc =>
      'Zum vorherigen verfügbaren Agenten wechseln';

  @override
  String get shortcutQuickOpenFiles => 'Dateien schnell öffnen';

  @override
  String get shortcutQuickOpenFilesDesc => 'Dateischnellsuche öffnen';

  @override
  String get shortcutQuitApp => 'Anwendung beenden';

  @override
  String get shortcutQuitAppDesc => 'Beenden der App erzwingen';

  @override
  String get shortcutRefreshData => 'Daten aktualisieren';

  @override
  String get shortcutRefreshDataDesc =>
      'Daten des aktuellen Chats aktualisieren';

  @override
  String get shortcutStopResponse => 'Antwort stoppen';

  @override
  String get shortcutStopResponseDesc =>
      'Aktive Antwort stoppen (während der Antwort)';

  @override
  String get shortcutToggleVoiceInput => 'Spracheingabe umschalten';

  @override
  String get shortcutToggleVoiceInputDesc =>
      'Spracheingabe im Editor starten oder stoppen';

  @override
  String get shortcutsApply => 'Anwenden';

  @override
  String shortcutsConflictConflict(String conflict) {
    return 'Konflikt mit $conflict';
  }

  @override
  String get shortcutsKeyboardShortcuts => 'Tastaturkurzbefehle';

  @override
  String get shortcutsReset => 'Alle zurücksetzen';

  @override
  String get shortcutsSearchEditBindings =>
      'Suchen, Tastenzuordnungen bearbeiten und Konflikte vor dem Speichern lösen.';

  @override
  String shortcutsSetShortcutWidget(String label) {
    return 'Tastenkombination festlegen: $label';
  }

  @override
  String get shortcutsTheseBindingsStored =>
      'Diese Tastenbelegungen sind in CodeWalk für die aktuelle App-Laufzeit gespeichert und bearbeiten keine OpenCode `tui.json`-Tastaturbelegungen.';

  @override
  String get speechAutoStopSilence => 'Automatischer Stopp bei Stille';

  @override
  String get speechChooseRecognitionEngine =>
      'Wählen Sie die Erkennungs-Engine, das Stille-Timeout und die Modelloptionen.';

  @override
  String speechDesktopOnly(String service) {
    return '$service ist nur auf dem Desktop verfügbar.';
  }

  @override
  String get speechDownload => 'Herunterladen';

  @override
  String get speechEngine => 'Engine';

  @override
  String get speechInstalledLanguages => 'Installierte Sprachen';

  @override
  String get speechListeningStopsAutomatically =>
      'Das Zuhören stoppt automatisch nach so vielen Sekunden Stille.';

  @override
  String get speechMicPermissionDisabled =>
      'Mikrofonberechtigung ist deaktiviert.';

  @override
  String speechModelFilesIncomplete(String service) {
    return 'Modelldateien für $service sind unvollständig.';
  }

  @override
  String get speechMoonshine => 'Moonshine';

  @override
  String get speechMoonshineModelsDesktop => 'Moonshine-Modelle (Desktop)';

  @override
  String get speechMoonshineStaysDownloadable =>
      'Moonshine bleibt herunterladbar und außerhalb des App-Bundles. Wählen Sie ein Modell für dieses Desktop-Gerät und entfernen Sie es später, wenn Sie den Speicherplatz zurückhaben möchten.';

  @override
  String get speechNative => 'Nativ';

  @override
  String get speechNativeSTTDisabled =>
      'Natives STT ist unter Linux in dieser App deaktiviert. Parakeet ist die Standard-Engine für Neuinstallationen.';

  @override
  String get speechNativeSTTWorks =>
      'On Windows, CodeWalk uses local on-device speech recognition through its WASAPI microphone backend. Native Windows speech recognition is disabled for stability.';

  @override
  String get speechNativeStartsFaster =>
      'Nativ startet schneller. Sherpa läuft vollständig auf dem Gerät mit komplexerer Einrichtung und tieferer Modellsteuerung.';

  @override
  String get speechOpenMicrophoneSettings => 'Open microphone settings';

  @override
  String get speechOpenSpeechPrivacy => 'Open speech privacy';

  @override
  String get speechOpenSpeechSettings => 'Open speech settings';

  @override
  String get speechParakeet => 'Parakeet';

  @override
  String get speechParakeetModelsDesktop => 'Parakeet-Modelle (Desktop)';

  @override
  String get speechParakeetStaysDownloadable =>
      'Parakeet bleibt herunterladbar und außerhalb des App-Bundles. Es stellt derzeit ein mehrsprachiges Modell bereit, das für 25 europäische Sprachen optimiert ist.';

  @override
  String get speechPickLanguagePacks =>
      'Sprachpakete auswählen und Modelle für die geräteinterne Erkennung herunterladen/entfernen.';

  @override
  String get speechRemove => 'Entfernen';

  @override
  String speechRuntimeFailed(String service) {
    return 'Laufzeit für $service konnte nicht initialisiert werden.';
  }

  @override
  String get speechSelectSherpaAbove =>
      'Wählen Sie oben Sherpa aus, um Sprachpakete zu verwalten und Modelle herunterzuladen.';

  @override
  String get speechSenseVoice => 'SenseVoice';

  @override
  String get speechSenseVoiceModelsDesktop => 'SenseVoice-Modelle (Desktop)';

  @override
  String get speechSenseVoiceStaysDownloadable =>
      'SenseVoice bleibt herunterladbar und außerhalb des App-Bundles. Es ist die stärkste Desktop-Option hier für Chinesisch, Kantonesisch, Japanisch, Koreanisch und Englisch.';

  @override
  String get speechSherpa => 'Sherpa';

  @override
  String get speechSherpaExperimentalFail =>
      'Sherpa ist experimentell und kann auf einigen Geräten fehlschlagen. Bevorzugen Sie Nativ, wenn Sie das stabilste Verhalten wünschen.';

  @override
  String get speechSherpaModelsLinux => 'Sherpa-Modelle (Linux)';

  @override
  String get speechSpeechText => 'Sprache zu Text';

  @override
  String speechUnavailableOnPlatform(String service) {
    return '$service-Sprachausgabe ist auf dieser Plattform nicht verfügbar.';
  }

  @override
  String get speechWindowsSetupHint =>
      'Windows voice input uses CodeWalk WASAPI capture with on-device models. Keep microphone access for desktop apps enabled; the buttons below open Windows settings for troubleshooting.';

  @override
  String get statusConnected => 'Verbunden';

  @override
  String get statusDelayed => 'Verzögert';

  @override
  String get statusFailed => 'Fehlgeschlagen';

  @override
  String get statusOffline => 'Offline';

  @override
  String get statusOnline => 'Online';

  @override
  String get statusReconnecting => 'Wiederverbinden';

  @override
  String get statusStarting => 'Starten';

  @override
  String get statusStopped => 'Gestoppt';

  @override
  String get statusStopping => 'Stoppen';

  @override
  String get statusSyncDelayed => 'Sync verzögert';

  @override
  String get tailscaleNoPeers => 'Keine Peers gefunden';

  @override
  String get tailscaleNotSupportedOnPlatform =>
      'Tailscale wird auf dieser Plattform nicht unterstützt.';

  @override
  String get tailscaleNotSupportedOnWindows =>
      'Tailscale wird unter Windows nicht unterstützt.';

  @override
  String get tailscalePeerOffline => 'offline';

  @override
  String get tailscaleSelectPeer => 'Tailscale-Peer auswählen';

  @override
  String get tailscaleWaitingAdminApproval =>
      'Dieser Tailscale-Knoten wartet auf die Genehmigung durch den Administrator.';

  @override
  String get terminalClose => 'Terminal schließen';

  @override
  String terminalConnectingTo(String serverName) {
    return 'Verbindung zum Terminal von $serverName wird hergestellt...';
  }

  @override
  String terminalConnectionFailed(String error) {
    return 'Terminalverbindung fehlgeschlagen: $error';
  }

  @override
  String get terminalDisconnected => 'Terminal getrennt.';

  @override
  String terminalEmbeddedUnavailable(String serverName) {
    return 'Das eingebettete Terminal ist in dieser Laufzeit noch nicht verfügbar. Verwenden Sie weiterhin den Composer-Shell-Modus für Einmalbefehle oder öffnen Sie das Terminal von einer unterstützten CodeWalk-App-Laufzeit für $serverName.';
  }

  @override
  String get terminalExtraKeyAlt => 'Alt-Taste';

  @override
  String get terminalExtraKeyArrowDown => 'Pfeil nach unten';

  @override
  String get terminalExtraKeyArrowLeft => 'Pfeil nach links';

  @override
  String get terminalExtraKeyArrowRight => 'Pfeil nach rechts';

  @override
  String get terminalExtraKeyArrowUp => 'Pfeil nach oben';

  @override
  String get terminalExtraKeyControl => 'Strg-Taste';

  @override
  String get terminalExtraKeyEscape => 'Escape-Taste';

  @override
  String get terminalExtraKeyTab => 'Tabulatortaste';

  @override
  String get terminalExtraKeys => 'Terminal-Zusatztasten';

  @override
  String get terminalHide => 'Terminal ausblenden';

  @override
  String get terminalMaximize => 'Maximieren';

  @override
  String get terminalMinimize => 'Terminal minimieren';

  @override
  String get terminalNotAvailableYet =>
      'Das eingebettete Terminal ist in dieser Laufzeit noch nicht verfügbar.';

  @override
  String get terminalOpen => 'Terminal öffnen';

  @override
  String get terminalOpenInfo => 'Terminal-Info öffnen';

  @override
  String get terminalOpenProjectFirst =>
      'Öffnen Sie einen Projektordner, bevor Sie das Server-Terminal starten.';

  @override
  String get terminalOpenToConnect =>
      'Öffnen Sie das Terminal, um sich mit dem Server-Projekt-Terminal zu verbinden.';

  @override
  String get terminalReconnect => 'Terminal neu verbinden';

  @override
  String get terminalRestoreSize => 'Größe wiederherstellen';

  @override
  String get terminalSelectServer =>
      'Wählen Sie einen aktiven Server aus, bevor Sie das Terminal öffnen.';

  @override
  String get terminalSessionClosed => 'Terminal-Sitzung geschlossen.';

  @override
  String get terminalTerminal => 'Terminal';

  @override
  String get terminalTitle => 'Terminal';

  @override
  String get terminalTryAgain => 'Erneut versuchen';

  @override
  String get toolAwaitingInput => 'Wartet auf Eingabe';

  @override
  String get toolEditing => 'Bearbeitet';

  @override
  String get toolEditingFiles => 'Bearbeitet Dateien';

  @override
  String get toolFinding => 'Findet';

  @override
  String get toolFindingFiles => 'Findet Dateien';

  @override
  String get toolPresentationAwaitingInput => 'Wartet auf Eingabe';

  @override
  String get toolPresentationEditing => 'Bearbeitet';

  @override
  String get toolPresentationEditingFiles => 'Bearbeitet Dateien';

  @override
  String get toolPresentationFinding => 'Findet';

  @override
  String get toolPresentationFindingFiles => 'Findet Dateien';

  @override
  String get toolPresentationReading => 'Liest';

  @override
  String get toolPresentationReadingFile => 'Liest Datei';

  @override
  String get toolPresentationRunning => 'Wird ausgeführt';

  @override
  String get toolPresentationRunningCommand => 'Führt Befehl aus';

  @override
  String toolPresentationRunningTool(String toolName) {
    return 'Führt $toolName aus';
  }

  @override
  String get toolPresentationSearching => 'Sucht';

  @override
  String get toolPresentationSearchingCode => 'Sucht im Code';

  @override
  String get toolPresentationSearchingWeb => 'Sucht im Web';

  @override
  String get toolPresentationTool => 'Werkzeug';

  @override
  String get toolPresentationUpdatingTaskList =>
      'Aufgabenliste wird aktualisiert';

  @override
  String get toolPresentationUpdatingTasks => 'Aufgaben werden aktualisiert';

  @override
  String get toolPresentationWaitingInput => 'Wartet auf Ihre Eingabe';

  @override
  String get toolPresentationWriting => 'Schreibt';

  @override
  String get toolPresentationWritingFile => 'Schreibt Datei';

  @override
  String get toolReading => 'Liest';

  @override
  String get toolReadingFile => 'Liest Datei';

  @override
  String get toolRunning => 'Wird ausgeführt';

  @override
  String get toolRunningCommand => 'Führt Befehl aus';

  @override
  String get toolRunningTask => 'Aufgabe wird ausgeführt';

  @override
  String get toolSearching => 'Sucht';

  @override
  String get toolSearchingCode => 'Sucht im Code';

  @override
  String get toolSearchingWeb => 'Sucht im Web';

  @override
  String get toolUpdatingTaskList => 'Aufgabenliste wird aktualisiert';

  @override
  String get toolUpdatingTasks => 'Aufgaben werden aktualisiert';

  @override
  String get toolWaitingForInput => 'Wartet auf Ihre Eingabe';

  @override
  String get toolWriting => 'Schreibt';

  @override
  String get toolWritingFile => 'Schreibt Datei';

  @override
  String get tourBack => 'Zurück';

  @override
  String get tourSkip => 'Überspringen';

  @override
  String get trayQuit => 'Beenden';

  @override
  String get trayShow => 'Anzeigen';

  @override
  String get useOAuthCloudflareAccess => 'OAuth (Cloudflare Access) verwenden';

  @override
  String get useOAuthCloudflareAccessSubtitle =>
      'Öffnet einen Browser für Cloudflare Access Managed OAuth.';

  @override
  String get useOAuthCloudflareAccessUnsupported =>
      'Cloudflare Access OAuth ist auf dieser Plattform nicht verfügbar. Verwenden Sie stattdessen Basic Auth.';

  @override
  String get useTailscale => 'Tailscale verwenden';

  @override
  String get useTailscaleSubtitle =>
      'Leitet den Verkehr ohne ein System-VPN durch das Tailscale-Netzwerk.';

  @override
  String get useTailscaleUnsupported =>
      'Tailscale wird auf dieser Plattform nicht unterstützt.';

  @override
  String get utilityTitle => 'Dienstprogramm';

  @override
  String get workspaceBrowseDirs => 'Verzeichnisse durchsuchen';

  @override
  String get workspaceChooseFolderOpen =>
      'Wählen Sie einen beliebigen Ordner aus, der als Projektkontext geöffnet werden soll.';

  @override
  String workspaceCloseProject(String project) {
    return '$project schließen';
  }

  @override
  String get workspaceClosedProjects => 'Geschlossene Projekte';

  @override
  String workspaceCurrentDirectory(String path) {
    return 'Aktuelles Verzeichnis: $path';
  }

  @override
  String get workspaceFilterDirs => 'Verzeichnisse filtern';

  @override
  String get workspaceOpenFolder => 'Ordner öffnen';

  @override
  String get workspaceOpenProjectFolder => 'Projektordner öffnen';

  @override
  String get workspaceOpenProjects => 'Offene Projekte';

  @override
  String get workspaceProjectDirectory => 'Projektverzeichnis';

  @override
  String get workspaceProjectHint => '/repo/my-project';

  @override
  String workspaceRemoveFromHistory(String name) {
    return '$name aus dem Verlauf entfernen';
  }

  @override
  String get settingsSessionAttentionTitle => 'Sitzungsaufmerksamkeit';

  @override
  String get settingsSessionAttentionDescription =>
      'Zeigt den Status von Stammsitzungen optional als Blase oder Panel an.';

  @override
  String get settingsSessionAttentionOff => 'Aus';

  @override
  String get settingsSessionAttentionBubble => 'Blase';

  @override
  String get settingsSessionAttentionPanel => 'Panel';

  @override
  String get settingsSessionAttentionPrivacy =>
      'Unter Android startet dies einen dauerhaften Vordergrunddienst. Antworttext wird verschlüsselt gespeichert; Cloud-TTS sendet Text erst nach dem Tippen auf Lesen.';

  @override
  String get settingsSessionAttentionUnavailable =>
      'Sitzungsaufmerksamkeit ist auf dieser Plattform nicht verfügbar.';

  @override
  String get settingsSessionAttentionOpenSettings =>
      'Anzeigeeinstellungen öffnen';

  @override
  String get settingsSessionAttentionStop => 'Sitzungsaufmerksamkeit beenden';

  @override
  String get settingsSessionAttentionThirdPartyTtsWarning =>
      'Beim Tippen auf Lesen kann Antworttext an den konfigurierten externen TTS-Anbieter gesendet werden.';

  @override
  String get workspaceSuggestions => 'Vorschläge';

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
