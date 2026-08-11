// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get aboutGitHub => 'GitHub';

  @override
  String get appProviderCannotActivateUnhealthy =>
      'Impossible d\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'activer un serveur en mauvaise santé';

  @override
  String get appProviderDesktopOnly =>
      'Le serveur local géré n\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'est disponible que sur ordinateur.';

  @override
  String get appProviderDetectingCommand =>
      'Détection de la commande OpenCode...';

  @override
  String get appProviderErrorCannotActivateUnhealthy =>
      'Impossible d\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'activer un serveur en mauvaise santé';

  @override
  String get appProviderErrorCloudflareOAuthNotSupported =>
      'Cloudflare Access OAuth n\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'est pas supporté sur cette plateforme';

  @override
  String get appProviderErrorInstallationFailed =>
      'L\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'installation d\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'OpenCode a échoué.';

  @override
  String get appProviderErrorInvalidServerUrl => 'URL du serveur invalide';

  @override
  String get appProviderErrorLocalServerHealthCheckFailed =>
      'Le serveur local a démarré mais le test de santé n\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'a pas été concluant.';

  @override
  String get appProviderErrorManagedDesktopOnly =>
      'Le serveur local géré n\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'est disponible que sur ordinateur.';

  @override
  String get appProviderErrorServerAlreadyExists =>
      'Un serveur avec cette URL existe déjà';

  @override
  String get appProviderErrorServerProfileNotFound =>
      'Profil de serveur introuvable';

  @override
  String get appProviderErrorServerUrlRequired =>
      'L\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'URL du serveur est requise';

  @override
  String get appProviderErrorTailscaleNotSupported =>
      'Tailscale n\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'est pas supporté sur cette plateforme';

  @override
  String appProviderExitedWithCode(int code) {
    return 'Le serveur local s\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'est arrêté avec le code $code.';
  }

  @override
  String get appProviderFailedToStart =>
      'Échec du démarrage du serveur OpenCode local.';

  @override
  String get appProviderInstallBinary => 'Installer le binaire';

  @override
  String get appProviderInstallBunOpenCode => 'Installer Bun + OpenCode';

  @override
  String get appProviderInstallSucceeded => 'Installation réussie.';

  @override
  String appProviderInstallSucceededWithPath(String path) {
    return 'Installation réussie. Commande OpenCode disponible à $path.';
  }

  @override
  String get appProviderInstallViaBun => 'Installer via Bun';

  @override
  String get appProviderInstallViaNpm => 'Installer via npm';

  @override
  String get appProviderInstallationFailed =>
      'L\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'installation d\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'OpenCode a échoué.';

  @override
  String get appProviderInstalledSuccessfully =>
      'Prérequis OpenCode installés avec succès.';

  @override
  String get appProviderInstallingRequirements =>
      'Installation des prérequis OpenCode...';

  @override
  String get appProviderInvalidServerUrl => 'URL du serveur invalide';

  @override
  String get appProviderLabelLocalOpenCodeManaged => 'OpenCode local (géré)';

  @override
  String get appProviderLabelPrimaryServer => 'Serveur principal';

  @override
  String get appProviderLocalManaged => 'OpenCode local (géré)';

  @override
  String get appProviderLocalServerStopped => 'Le serveur local est arrêté.';

  @override
  String get appProviderNotDetectedInstall =>
      'La commande OpenCode n\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'a pas été détectée. Lancez l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'installation depuis l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'assistant.';

  @override
  String appProviderNotDetectedRefresh(String appName) {
    return 'La commande OpenCode n\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'a pas été détectée. Si vous l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'avez installée il y a un instant, actualisez les tests ou redémarrez $appName pour recharger le PATH.';
  }

  @override
  String get appProviderOAuthNotSupported =>
      'Cloudflare Access OAuth n\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'est pas supporté sur cette plateforme';

  @override
  String get appProviderOpenCodeDetected => 'OpenCode détecté';

  @override
  String get appProviderOpenCodeNotDetected => 'OpenCode non détecté';

  @override
  String get appProviderPrimaryServer => 'Serveur principal';

  @override
  String get appProviderProfileNotFound => 'Profil de serveur introuvable';

  @override
  String get appProviderRunDiagnostics =>
      'Exécutez les diagnostics pour vérifier les prérequis locaux dOpenCode.';

  @override
  String appProviderRunningAt(String url) {
    return 'Lancé sur $url';
  }

  @override
  String get appProviderSetupDetectingOpenCode =>
      'Détection de la commande OpenCode...';

  @override
  String get appProviderSetupInstallationSucceeded => 'Installation réussie.';

  @override
  String appProviderSetupInstallationSucceededWithPath(String path) {
    return 'Installation réussie. Commande OpenCode disponible à $path.';
  }

  @override
  String get appProviderSetupInstallingRequirements =>
      'Installation des prérequis OpenCode...';

  @override
  String get appProviderSetupOpenCodeDetected => 'OpenCode détecté';

  @override
  String get appProviderSetupOpenCodeNotDetected => 'OpenCode non détecté';

  @override
  String get appProviderSetupOpenCodeNotDetectedInstall =>
      'La commande OpenCode n\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'a pas été détectée. Lancez l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'installation depuis l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'assistant.';

  @override
  String get appProviderSetupOpenCodeNotDetectedRefresh =>
      'La commande OpenCode n\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'a pas été détectée. Si vous l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'avez installée il y a un instant, actualisez les tests ou redémarrez CodeWalk pour recharger le PATH.';

  @override
  String get appProviderSetupRequirementsInstalled =>
      'Prérequis OpenCode installés avec succès.';

  @override
  String appProviderSetupUsingOpenCodeAt(String path) {
    return 'Utilisation de la commande OpenCode à $path';
  }

  @override
  String get appProviderStartingLocalServer => 'Démarrage du serveur local...';

  @override
  String appProviderStatusLocalServerExitedWithCode(int code) {
    return 'Le serveur local sest arrêté avec le code $code.';
  }

  @override
  String get appProviderStatusLocalServerStopped =>
      'Le serveur local est arrêté.';

  @override
  String appProviderStatusRunningAt(String url) {
    return 'Lancé sur $url';
  }

  @override
  String get appProviderStatusStartingLocalServer =>
      'Démarrage du serveur local...';

  @override
  String get appProviderStatusStoppingLocalServer =>
      'Arrêt du serveur local...';

  @override
  String get appProviderStoppingLocalServer => 'Arrêt du serveur local...';

  @override
  String get appProviderTailscaleNotSupported =>
      'Tailscale n\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'est pas supporté sur cette plateforme';

  @override
  String appProviderUsingCommandAt(String path) {
    return 'Utilisation de la commande OpenCode à $path';
  }

  @override
  String get appShellDownloadingUpdate => 'Téléchargement de la mise à jour';

  @override
  String get appShellInstall => 'Installer';

  @override
  String get appShellInstallFailed =>
      'Échec de l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'installation';

  @override
  String get appShellInstallingUpdate => 'Installation de la mise à jour...';

  @override
  String get appShellRestart => 'Redémarrer';

  @override
  String appShellUpdateAvailableResult(String latestVersion) {
    return 'Mise à jour disponible : v$latestVersion';
  }

  @override
  String get appShellUpdateInstalledRestartApp =>
      'Mise à jour installée. Redémarrez l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'application pour l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'appliquer.';

  @override
  String get appShellUpdateInstalledRestartRequired =>
      'Mise à jour installée. Un redémarrage est nécessaire pour appliquer la nouvelle version.';

  @override
  String get attachmentCouldNotDecode =>
      'Les données de la pièce jointe n\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'ont pas pu être décodées.';

  @override
  String get attachmentCouldNotDownload =>
      'La pièce jointe n\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'a pas pu être téléchargée.';

  @override
  String get attachmentCouldNotSave =>
      'La pièce jointe n\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'a pas pu être enregistrée sur cet appareil.';

  @override
  String get attachmentDownloadStarted =>
      'Téléchargement de la pièce jointe commencé.';

  @override
  String get attachmentLocalNotFound =>
      'La pièce jointe locale n\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'a pas été trouvée sur cet appareil.';

  @override
  String get attachmentNoValidLocation =>
      'La pièce jointe ne fournit pas d\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'emplacement valide.';

  @override
  String get attachmentNotAvailableOnPlatform =>
      'Les actions sur les pièces jointes ne sont pas disponibles sur cette plateforme.';

  @override
  String get attachmentPathEmpty => 'Le chemin de la pièce jointe est vide.';

  @override
  String get attachmentPayloadEmpty =>
      'La charge utile de la pièce jointe est vide.';

  @override
  String get attachmentSaveCanceled => 'Enregistrement annulé.';

  @override
  String attachmentSavedAndOpened(String path) {
    return 'Pièce jointe enregistrée dans $path et ouverte.';
  }

  @override
  String attachmentSavedPath(String path) {
    return 'Pièce jointe enregistrée dans $path.';
  }

  @override
  String attachmentSavedTo(String path) {
    return 'Pièce jointe enregistrée dans $path.';
  }

  @override
  String get attachmentUnableToOpenLink =>
      'Impossible d\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'ouvrir le lien de la pièce jointe.';

  @override
  String get attachmentUnableToOpenLocal =>
      'Impossible d\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'ouvrir la pièce jointe locale.';

  @override
  String get behaviorAdvancedPermissionRule =>
      'Règle d\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'autorisation avancée';

  @override
  String get behaviorAutomatic => 'Automatique';

  @override
  String get behaviorAutomaticFallback => 'Repli automatique';

  @override
  String get behaviorCellularDataSaver => 'Économiseur de données mobiles';

  @override
  String get behaviorCellularDataSaverActive =>
      'L\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'économiseur de données mobiles est actif.';

  @override
  String get behaviorChatLevelShare => 'Partage au niveau du chat';

  @override
  String get behaviorCodeWalkReleaseChecks =>
      'Vérifications de version CodeWalk';

  @override
  String get behaviorControlsOfficialGlobal =>
      'Contrôle les paramètres globaux officiels d\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'OpenCode';

  @override
  String get behaviorControlsUpstreamOpenCode =>
      'Contrôle les paramètres OpenCode en amont';

  @override
  String get behaviorCustomDisplayName =>
      'Nom d\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'affichage personnalisé';

  @override
  String behaviorCutsAutomaticMobile(int inSeconds) {
    return 'Réduit l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'utilisation automatique des données mobiles en arrêtant les téléchargements en arrière-plan et en limitant les actualisations automatiques au premier plan à une rafale toutes les $inSeconds secondes.';
  }

  @override
  String get behaviorDataSaverActive =>
      'Actif actuellement sur les données mobiles.';

  @override
  String get behaviorDataSaverAggressive => 'Aggressive';

  @override
  String get behaviorDataSaverAggressiveDescription =>
      'Low-bandwidth mode: only the visible workspace stream stays live, global updates are paused, and automatic refreshes are stretched.';

  @override
  String get behaviorDataSaverCellularOnly =>
      'S\'applique uniquement lorsque la connexion est mobile/cellulaire.';

  @override
  String get behaviorDataSaverOff => 'Off';

  @override
  String get behaviorDataSaverOffHint =>
      'Full realtime and automatic refreshes are enabled.';

  @override
  String get behaviorDataSaverStandard => 'Standard';

  @override
  String get behaviorDataSaverWaiting =>
      'En attente de la prochaine fenêtre de synchronisation des données mobiles.';

  @override
  String get behaviorDisabled => 'Désactivé';

  @override
  String get behaviorLightweightTasksLike => 'Tâches légères comme';

  @override
  String get behaviorManual => 'Manuel';

  @override
  String get behaviorNotify => 'Notifier';

  @override
  String get behaviorOfficialOpenCodePermission =>
      'La politique officielle de permissions d\'OpenCode est configurée dans `opencode.json` avec des règles autoriser/demander/refuser par outil. CodeWalk conserve les cartes officielles de demande de permission et ajoute une exception approuvée selon l\'ADR-023 : le bouton d\'approbation automatique de l\'éditeur de message répond par `Always` et `remember: true` de manière inconditionnelle pour créer des autorisations durables limitées à la session, et maintient le même chemin de continuité limité au thread actif dans le processus d\'arrière-plan Android.';

  @override
  String get behaviorOpenCodeBackedDefaults =>
      'Valeurs par défaut basées sur OpenCode';

  @override
  String get behaviorPermissionHandlingProvenance =>
      'Provenance de la gestion des permissions';

  @override
  String get behaviorPermissionsVariantReasoning =>
      'Les permissions et la parité variante/raisonnement restent séparées jusqu\'à ce que leur interface utilisateur puisse préserver la configuration avancée en toute sécurité.';

  @override
  String get behaviorPrimaryAgentAgent =>
      'Agent principal utilisé lorsqu\'aucun agent n\'est explicitement choisi.';

  @override
  String get behaviorRefreshDefaults => 'Actualiser les valeurs par défaut';

  @override
  String get behaviorSharedAcrossOpenCode =>
      'Partagé entre les clients OpenCode via la configuration.';

  @override
  String get behaviorTheseValuesWrite =>
      'Ces valeurs sont écrites dans `/config` sur le serveur actif et correspondent à la configuration partagée officielle d\'OpenCode.';

  @override
  String get cannedAddTitle => 'Ajouter une réponse rapide';

  @override
  String get cannedAppendAtCursor => 'Ajouter au curseur';

  @override
  String get cannedAppendAtCursorSubtitle =>
      'Désactivé = remplacer le texte actuel';

  @override
  String get cannedAttachFiles => 'Joindre des fichiers';

  @override
  String get cannedEditTitle => 'Modifier la réponse rapide';

  @override
  String get cannedNewQuickReply => 'Nouvelle réponse rapide';

  @override
  String get cannedNoSuggestions => 'Aucune suggestion';

  @override
  String get cannedOffMeansReplace =>
      'Désactivé signifie remplacer le texte actuel de l\'éditeur';

  @override
  String get cannedQuickReply => 'Nouvelle réponse rapide';

  @override
  String get cannedReplace => 'Remplacer';

  @override
  String get cannedScopeGlobalSubtitle =>
      'Désactiver pour élément de projet uniquement';

  @override
  String get cannedScopeGlobalUnavailableSubtitle =>
      'Projet uniquement non disponible dans ce contexte';

  @override
  String get cannedSendAutomaticallySubtitle =>
      'Envoyer immédiatement après insertion';

  @override
  String get cannedSendImmediatelyInserting =>
      'Envoyer immédiatement après l\'insertion de cette réponse rapide';

  @override
  String get cannedTextLabel => 'Texte';

  @override
  String get chatActionNext => 'Suivant';

  @override
  String get chatActiveServerUnhealthy =>
      'Le serveur actif a un problème de santé. Les envois essaieront une fois et échoueront rapidement jusqu\'au rétablissement.';

  @override
  String get chatActiveServerUnhealthyLabel =>
      'Le serveur actif est en mauvaise santé';

  @override
  String get chatAddServerToStart =>
      'Ajoutez un serveur pour commencer à discuter.';

  @override
  String get chatAppBarMoreActions => 'Plus d\'actions';

  @override
  String get chatAppBarPinAction => 'Épingler à la barre d\'application';

  @override
  String get chatAppBarPinDescription =>
      'Cette action restera visible en dehors du menu.';

  @override
  String get chatAppBarUnpinAction => 'Désépingler de la barre d\'application';

  @override
  String get chatAppBarUnpinDescription =>
      'Cette action retournera dans le menu.';

  @override
  String chatBadgeConversationError(String title) {
    return '\"$title\" a une erreur.';
  }

  @override
  String chatBadgeConversationNeedsInput(String title) {
    return '\"$title\" nécessite votre intervention.';
  }

  @override
  String chatBadgeConversationNewReply(String title) {
    return '\"$title\" a une nouvelle réponse.';
  }

  @override
  String get chatBadgeDataSaverActive =>
      'Léconomiseur de données mobiles est activé.';

  @override
  String get chatBadgeServerNeedsAttention =>
      'La connexion au serveur nécessite une attention particulière.';

  @override
  String get chatBadgeSyncing => 'Synchronisation des conversations...';

  @override
  String get chatBlockResponsePendingDescription =>
      'The answer will appear as a single block when this turn finishes.';

  @override
  String get chatBlockResponsePendingTitle => 'Generating response';

  @override
  String get chatCachedConversationsYet =>
      'Aucune conversation mise en cache pour le moment';

  @override
  String get chatChangedFilesAvailable =>
      'Aucun fichier modifié n\'est disponible pour cette session.';

  @override
  String chatChildrenChatProviderCurrentSessionChildren(int length) {
    return 'Enfants : $length';
  }

  @override
  String get chatChooseAgent =>
      'Sélectionner l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'agent';

  @override
  String get chatChooseDirectory => 'Choisir le répertoire';

  @override
  String get chatChooseEffort =>
      'Choisir l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'effort';

  @override
  String get chatChooseFolderOpen =>
      'Choisissez un dossier à ouvrir en tant que contexte du projet.';

  @override
  String get chatChooseModel => 'Choisir le modèle';

  @override
  String get chatClose => 'Fermer';

  @override
  String chatCloseProject(String project) {
    return 'Fermer $project';
  }

  @override
  String get chatCollapseGroup => 'Réduire le groupe';

  @override
  String get chatCommandDescriptionProject => 'Commande du projet';

  @override
  String get chatCommandSourceGeneric => 'commande';

  @override
  String get chatCommandSourceProject => 'projet';

  @override
  String get chatCompactContext => 'Compacter le contexte';

  @override
  String get chatComposerHintShell => 'Commande shell (Échap pour quitter)';

  @override
  String get chatComposerPlaceholder => 'Tapez vos besoins...';

  @override
  String get chatConversation => 'Conversation';

  @override
  String get chatConversations => 'Conversations';

  @override
  String get chatConversationsPane => 'Conversations';

  @override
  String chatCostLabel(double cost) {
    return 'Coût : \$$cost';
  }

  @override
  String get chatCouldNotRefreshSession =>
      'Impossible d\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'actualiser cette conversation';

  @override
  String get chatCurrent => 'Utiliser l\'actuel';

  @override
  String chatDescriptionChildren(int count) {
    return 'Enfants : $count';
  }

  @override
  String get chatDescriptionCloseApp =>
      'Fermer l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'application en utilisant le comportement de fermeture de la plateforme';

  @override
  String get chatDescriptionCycleModels => 'Faire défiler les modèles récents';

  @override
  String get chatDescriptionCycleVariant =>
      'Faire défiler les variantes de modèle';

  @override
  String get chatDescriptionDiffFilesZero => 'Fichiers diff : 0';

  @override
  String get chatDescriptionFocusInput =>
      'Focus sur l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'entrée du message';

  @override
  String get chatDescriptionFocusOrCloseDrawer =>
      'Focus sur l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'entrée (ou fermer le tiroir s\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'il est ouvert)';

  @override
  String get chatDescriptionForceExit =>
      'Forcer la sortie de l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'application';

  @override
  String get chatDescriptionNewConversation => 'Nouvelle conversation';

  @override
  String get chatDescriptionNextAgent => 'Agent suivant';

  @override
  String get chatDescriptionOpenProjects =>
      'Utilisez ce bouton pour ouvrir vos projets et conversations.';

  @override
  String get chatDescriptionOpenSettings => 'Ouvrir les paramètres';

  @override
  String get chatDescriptionPreviousAgent => 'Agent précédent';

  @override
  String get chatDescriptionProjectCommand => 'Commande de projet';

  @override
  String get chatDescriptionQuickOpen => 'Ouverture rapide de fichiers';

  @override
  String get chatDescriptionRefreshData => 'Actualiser les données du chat';

  @override
  String get chatDescriptionStopResponse =>
      'Arrêter la réponse active (pendant la réponse)';

  @override
  String get chatDescriptionSwitchProject =>
      'Utilisez ce bouton pour changer de dossier de projet et de contexte.';

  @override
  String get chatDescriptionVoiceInput =>
      'Démarrer ou arrêter la saisie vocale';

  @override
  String get chatDiffFiles => 'Fichiers modifiés : 0';

  @override
  String get chatDisplay => 'Affichage';

  @override
  String get chatDisplayToggles => 'Options d\'affichage';

  @override
  String get chatDoubleESCStop => 'Double Échap pour arrêter';

  @override
  String get chatEffortLockedSubConversation =>
      'Effort verrouillé dans la sous-conversation';

  @override
  String get chatExpandGroup => 'Développer le groupe';

  @override
  String get chatExportCanceled => 'Exportation de la session annulée';

  @override
  String get chatFailedToLoadDirectories =>
      'Échec du chargement des répertoires';

  @override
  String get chatFailedToLoadFile => 'Échec du chargement du fichier';

  @override
  String get chatFailedToRefreshProviders =>
      'Échec de l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'actualisation des fournisseurs et modèles';

  @override
  String get chatFailedToRefreshSubConversations =>
      'Échec de l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'actualisation. Veuillez réessayer.';

  @override
  String get chatFailedToStopResponse =>
      'Échec de l\'arrêt de la réponse actuelle';

  @override
  String get chatFileExplorerContents => 'Contenu';

  @override
  String get chatFileExplorerNames => 'Noms';

  @override
  String get chatFilterActive => 'Actives';

  @override
  String get chatFilterAll => 'Toutes';

  @override
  String get chatFilterArchived => 'Archivées';

  @override
  String get chatFilterDirectories => 'Filtrer les répertoires';

  @override
  String get chatFilterSessions => 'Filtrer les sessions';

  @override
  String get chatForkFailed => 'Échec de la bifurcation de la conversation';

  @override
  String get chatForked => 'Conversation bifurquée';

  @override
  String get chatGoToFirst => 'Aller au premier message';

  @override
  String get chatGoToLatest => 'Aller au dernier message';

  @override
  String chatGroupMessageCountMessages(
    String compactionLabel,
    String messageCount,
  ) {
    return '$messageCount messages masqués avant la compression $compactionLabel';
  }

  @override
  String get chatHelloAssistant => 'Bonjour ! Je suis votre assistant IA';

  @override
  String get chatHelp => 'Comment puis-je vous aider ?';

  @override
  String get chatHelpMessage =>
      'Utilisez @ pour les mentions, ! pour le shell, / pour les commandes';

  @override
  String get chatHideConversationsSidebar =>
      'Masquer la barre latérale des conversations';

  @override
  String get chatHideUtilitySidebar => 'Masquer la barre latérale utilitaire';

  @override
  String get chatHistoryCollapsed => 'L\'historique précédent est réduit';

  @override
  String get chatHistoryHideEarlier => 'Masquer les messages précédents';

  @override
  String chatHistoryMessagesHidden(int count, String label) {
    return '$count messages masqués avant la compaction de type $label';
  }

  @override
  String get chatHistoryShowEarlier => 'Afficher les messages précédents';

  @override
  String get chatKeepWorking => 'Continuer à travailler';

  @override
  String get chatLargeContentSkipped =>
      'Le contenu volumineux ou malformé a été ignoré pour des raisons de stabilité.';

  @override
  String get chatLatestToolActivity =>
      'L\'activité récente des outils reste à l\'intérieur de ce panneau délimité afin de maintenir la stabilité de la zone de visualisation.';

  @override
  String get chatLoadMore => 'Charger plus';

  @override
  String get chatLoadingProjectContext => 'Chargement du contexte du projet...';

  @override
  String get chatMainConversationUnavailable =>
      'La conversation principale n\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'est pas encore disponible.';

  @override
  String get chatParentConversationUnavailable =>
      'La conversation parente n\'est pas encore disponible.';

  @override
  String get chatMentionAgentSubtitle => 'agent';

  @override
  String get chatMentionFileSubtitle => 'fichier';

  @override
  String get chatMentionSymbolSubtitle => 'symbole';

  @override
  String get chatMessageAttachedFile => 'Fichier joint';

  @override
  String get chatMessageDetails => 'Détails';

  @override
  String get chatMessageHide => 'Masquer';

  @override
  String get chatMessageLess => 'Moins';

  @override
  String get chatMessageMessagePartUnavailable =>
      'Partie du message non disponible';

  @override
  String get chatMessageMetadataAvailable => 'Aucune métadonnée disponible';

  @override
  String chatMessageModelMessageModelId(String modelId) {
    return 'Modèle : $modelId';
  }

  @override
  String get chatMessageMore => 'Plus';

  @override
  String get chatMessageOpenFile => 'Ouvrir le fichier';

  @override
  String chatMessageProviderMessageProviderId(String providerId) {
    return 'Fournisseur : $providerId';
  }

  @override
  String get chatMessageRewindEdit =>
      'Revenir en arrière et modifier à partir d\'ici';

  @override
  String get chatMessageRunningTask => 'Tâche en cours d\'exécution';

  @override
  String get chatMessageSaveFile => 'Enregistrer le fichier';

  @override
  String get chatMessageShow => 'Afficher';

  @override
  String get chatMessageShowLess => 'Afficher moins';

  @override
  String get chatMessageShowLessCompact => 'Moins';

  @override
  String get chatMessageShowMore => 'Afficher plus';

  @override
  String get chatMessageShowMoreCompact => 'Plus';

  @override
  String get chatMessageThinking => 'Réfléchit';

  @override
  String get chatMessageThinkingProcess => 'Processus de réflexion';

  @override
  String get chatMessageToolCall => '1 appel d\'outil';

  @override
  String chatMessageToolCalls(int count) {
    return '$count appels d\'outil';
  }

  @override
  String get chatMessageToolCommand => 'Commande';

  @override
  String get chatMessageToolCommandTruncated =>
      'Aperçu de la commande tronqué.';

  @override
  String get chatMessageToolDiffOmitted =>
      'Aperçu du diff omis - charge trop volumineuse.';

  @override
  String get chatMessageToolInput => 'Entrée';

  @override
  String get chatMessageToolInputTruncated =>
      'Aperçu de l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'entrée tronqué.';

  @override
  String get chatMessageToolOutputTruncated =>
      'Aperçu tronqué pour la stabilité.';

  @override
  String chatMessageToolQueuedCount(int count) {
    return '$count en file d\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'attente';
  }

  @override
  String chatMessageToolRunningCount(int count) {
    return '$count en cours';
  }

  @override
  String get chatMessageToolStatusInProgress => 'En cours';

  @override
  String get chatMessageToolStatusNeedsAttention => 'Nécessite votre attention';

  @override
  String get chatMessageToolStatusQueued => 'En file d\'attente';

  @override
  String get chatMessageYou => 'Vous';

  @override
  String get chatModelLockedSubConversation =>
      'Modèle verrouillé dans la sous-conversation';

  @override
  String get chatNewChat => 'Nouvelle discussion';

  @override
  String get chatNewChatTourDescription =>
      'Commencez une nouvelle conversation ici.';

  @override
  String get chatNewChatTourTitle => 'Nouvelle discussion';

  @override
  String get chatNoConversationsInProject =>
      'Aucune conversation dans ce projet.';

  @override
  String get chatNoServerYet => 'Aucun serveur configuré pour le moment';

  @override
  String get chatNoSessionSelected => 'Sélectionnez ou créez une conversation';

  @override
  String get chatNoSubConversationFound => 'Aucune sous-conversation trouvée.';

  @override
  String get chatOpenFiles => 'Fichiers ouverts';

  @override
  String get chatOpenProject => 'Ouvrir le projet';

  @override
  String get chatOpenProjectFolder => 'Ouvrir le dossier du projet...';

  @override
  String get chatOpenProjectToLoad =>
      'Ouvrez un projet pour charger les conversations.';

  @override
  String get chatOpenSidebar => 'Ouvrir la barre latérale';

  @override
  String get chatPageStatusAutomaticCompactionExplanation =>
      'La compaction automatique se produit à mesure que l\'utilisation du contexte augmente.';

  @override
  String get chatPageStatusCompactNow => 'Compacter maintenant';

  @override
  String get chatPageStatusCompacting => 'Compaction...';

  @override
  String get chatPageStatusCompactingContextNow =>
      'Compaction du contexte en cours...';

  @override
  String get chatPageStatusContextCompacted => 'Contexte compacté';

  @override
  String get chatPageStatusContextUsage => 'Utilisation du contexte';

  @override
  String get chatPageStatusCost => 'Coût';

  @override
  String get chatPageStatusFailedToCompactContext =>
      'Échec de la compaction du contexte';

  @override
  String get chatPageStatusLimit => 'Limite';

  @override
  String get chatPageStatusManageServers => 'Gérer les serveurs';

  @override
  String get chatPageStatusSaver => 'Économiseur';

  @override
  String get chatPageStatusServer => 'Serveur';

  @override
  String get chatPageStatusSwitchServer => 'Changer de serveur';

  @override
  String get chatPageStatusTokens => 'Jetons';

  @override
  String get chatPageStatusUsage => 'Utilisation';

  @override
  String chatPageStatusUsagePercent(int usagePercent) {
    return '$usagePercent';
  }

  @override
  String get chatPermissionAutoApproveOff =>
      'Approbation automatique des permissions désactivée';

  @override
  String get chatPermissionAutoApproveOn =>
      'Approbation automatique des permissions activée';

  @override
  String get chatProjectContext => 'Contexte du projet';

  @override
  String get chatProjectContext2 => 'Contexte du projet';

  @override
  String get chatRealtimeGlobalEvent => 'événement global';

  @override
  String chatRealtimeGlobalEventReason(String reason) {
    return 'événement global ($reason)';
  }

  @override
  String get chatRealtimeGlobalEventStale =>
      'événement global (génération périmée)';

  @override
  String chatRealtimeMessageStreamReason(String reason) {
    return 'flux de messages ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEvent => 'événement en temps réel';

  @override
  String chatRealtimeRealtimeEventReason(String reason) {
    return 'événement en temps réel ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEventStale =>
      'événement en temps réel (génération périmée)';

  @override
  String get chatRealtimeReconnectingServerTry =>
      'Reconnexion au serveur. Veuillez réessayer dans un instant.';

  @override
  String get chatReasoning => 'Raisonnement...';

  @override
  String get chatRecentSessions => 'Sessions récentes';

  @override
  String get chatRecentSessionsToggle => 'Sessions récentes';

  @override
  String get chatRedoLastTurn => 'Rétablir le dernier tour annulé';

  @override
  String get chatRedoNothing => 'Rien à rétablir dans cette session';

  @override
  String get chatRefresh => 'Actualiser';

  @override
  String get chatRefreshConversation =>
      'Impossible d\'actualiser cette conversation';

  @override
  String get chatRefreshProjects => 'Actualiser les projets';

  @override
  String get chatRefreshSessionDetails =>
      'Actualiser les détails de la session';

  @override
  String chatRemoveDisplayNameHistory(String displayName) {
    return 'Supprimer $displayName de l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'historique';
  }

  @override
  String get chatRetry => 'Réessayer';

  @override
  String get chatRetry2 => 'Réessayer';

  @override
  String get chatRetryRefresh => 'Réessayer l\'actualisation';

  @override
  String get chatRetryingModelRequest =>
      'Nouvelle tentative de demande de modèle...';

  @override
  String get chatReturnToMainConversation =>
      'Retourner à la conversation principale';

  @override
  String get chatReturnToParentConversation =>
      'Retourner à la conversation parente';

  @override
  String get chatReviewChanges => 'Examiner les modifications';

  @override
  String get chatSearchConversations => 'Rechercher des conversations';

  @override
  String get chatSearchNextResult => 'Résultat suivant';

  @override
  String get chatSearchNoResults => 'Aucun résultat';

  @override
  String get chatSearchPreviousResult => 'Résultat précédent';

  @override
  String chatSearchResultCount(int current, int total) {
    return 'Message $current sur $total';
  }

  @override
  String get chatSearchTimeline => 'Rechercher dans la chronologie';

  @override
  String get chatSelectDirectory => 'Sélectionner le répertoire';

  @override
  String get chatSelectOrCreate =>
      'Sélectionnez ou créez une conversation pour commencer à discuter';

  @override
  String get chatSelectProjectBelow => 'Sélectionnez un projet ci-dessous.';

  @override
  String get chatServerSelectedModel => 'Modèle sélectionné par le serveur';

  @override
  String get chatSessionActions => 'Actions de session';

  @override
  String chatSessionChatSessionSession(String title) {
    return 'Session de chat : $title';
  }

  @override
  String chatSessionConversationNextAction(String nextAction) {
    return 'Conversation $nextAction';
  }

  @override
  String get chatSessionConversations => 'Aucune conversation';

  @override
  String get chatSessionCreateConversationStart =>
      'Créez une nouvelle conversation pour commencer à discuter';

  @override
  String get chatSessionTabsToggle => 'Onglets de session';

  @override
  String chatSessionsLength(int length) {
    return '$length';
  }

  @override
  String get chatSetUpServer => 'Configurer le serveur';

  @override
  String get chatSettings => 'Paramètres';

  @override
  String get chatShortcutsCloseApp =>
      'Fermer l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'application en utilisant le comportement de la plateforme';

  @override
  String get chatShortcutsCycleModels => 'Faire défiler les modèles récents';

  @override
  String get chatShortcutsCycleVariant => 'Faire défiler la variante du modèle';

  @override
  String get chatShortcutsFocusInput => 'Focus sur la saisie du message';

  @override
  String get chatShortcutsFocusInputCloseDrawer =>
      'Focus sur la saisie (ou fermer le tiroir s\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'il est ouvert)';

  @override
  String get chatShortcutsForceExit =>
      'Forcer la fermeture de l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'application';

  @override
  String get chatShortcutsNewConversation => 'Nouvelle conversation';

  @override
  String get chatShortcutsNextAgent => 'Agent suivant';

  @override
  String get chatShortcutsOpenSettings => 'Ouvrir les paramètres';

  @override
  String get chatShortcutsPreviousAgent => 'Agent précédent';

  @override
  String get chatShortcutsQuickOpen => 'Ouverture rapide des fichiers';

  @override
  String get chatShortcutsRefreshChat => 'Actualiser les données du chat';

  @override
  String get chatShortcutsStartStopVoice =>
      'Démarrer ou arrêter la saisie vocale';

  @override
  String get chatShortcutsStopResponse =>
      'Arrêter la réponse active (pendant la réponse)';

  @override
  String get chatSidebarAccess => 'Accès à la barre latérale';

  @override
  String get chatSortMostRecent => 'Les plus récentes';

  @override
  String get chatSortOldest => 'Les plus anciennes';

  @override
  String get chatSortRecent => 'Récentes';

  @override
  String get chatSortSessions => 'Trier les sessions';

  @override
  String get chatSortTitle => 'Titre';

  @override
  String get chatStartVoiceInput => 'Démarrer la saisie vocale';

  @override
  String get chatStartingVoiceInput => 'Démarrage de la saisie vocale';

  @override
  String get chatStatusBusy => 'État : Occupé';

  @override
  String get chatStatusPatching => 'Application de correctifs';

  @override
  String chatStatusPatchingMultipleFiles(int count) {
    return 'Correctifs sur $count fichiers';
  }

  @override
  String get chatStatusPatchingOneFile => 'Correctif sur 1 fichier';

  @override
  String get chatStatusRetry => 'État : Réessayer';

  @override
  String chatStatusRetryCount(int count) {
    return 'État : Réessayer #$count';
  }

  @override
  String get chatStatusSubsession => 'Sous-session';

  @override
  String get chatStatusThinking => 'Réflexion...';

  @override
  String get chatStopVoiceInput => 'Arrêter la saisie vocale';

  @override
  String chatSyncLabel(String label) {
    return 'Synchronisation : $label';
  }

  @override
  String get chatTasks => 'Tâches';

  @override
  String get chatTasksAvailableSession =>
      'Aucune tâche n\'est disponible pour cette session.';

  @override
  String get chatTipAcceptanceCriteria =>
      'Conseil : Ajoutez des critères de validation aux grands changements';

  @override
  String get chatTipAskForPlan =>
      'Conseil : Demandez un plan avant les grandes tâches';

  @override
  String get chatTipBeSpecific =>
      'Conseil : Soyez précis — les prompts courts obtiennent des réponses plus rapides';

  @override
  String get chatTipBreakTasks =>
      'Conseil : Divisez les grandes tâches en prompts plus petits';

  @override
  String get chatTipCompareOptions =>
      'Conseil : Demandez des options quand les compromis sont flous';

  @override
  String get chatTipContextKnob =>
      'Conseil : Appuyez sur le bouton de contexte pour voir les détails d\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'utilisation';

  @override
  String get chatTipDefineVerification =>
      'Conseil : Dites quels tests ou contrôles doivent passer';

  @override
  String get chatTipLongPressSend =>
      'Conseil : Appuyez longuement sur Envoyer pour insérer une nouvelle ligne';

  @override
  String get chatTipMentionFiles =>
      'Conseil : Utilisez @ pour mentionner des fichiers dans votre prompt';

  @override
  String get chatTipNameRelevantFiles =>
      'Conseil : Nommez les fichiers, écrans ou commandes utiles';

  @override
  String get chatTipProvideContext =>
      'Conseil : Fournissez du contexte — collez les messages d\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'erreur et les logs';

  @override
  String get chatTipRenameConversation =>
      'Conseil : Appuyez sur le titre pour renommer une conversation';

  @override
  String get chatTipRequestDocs =>
      'Conseil : Demandez une mise à jour des docs si le comportement change';

  @override
  String get chatTipShareAttempts =>
      'Conseil : Partagez vos essais et le message exact';

  @override
  String get chatTipShellCommands =>
      'Conseil : Utilisez ! au début pour exécuter des commandes shell';

  @override
  String get chatTipSlashCommands =>
      'Conseil : Utilisez / pour accéder aux commandes slash';

  @override
  String get chatTipStartWithGoal => 'Conseil : Commencez par le but final';

  @override
  String get chatTipStateConstraints =>
      'Conseil : Indiquez les contraintes à préserver';

  @override
  String get chatTipStepByStep =>
      'Conseil : Demandez étape par étape lors du débogage de problèmes complexes';

  @override
  String get chatTipUseFocusedAgents =>
      'Conseil : Choisissez un agent ciblé pour planifier, relire ou construire';

  @override
  String get chatToggleSidebars => 'Basculer les barres latérales';

  @override
  String chatTokensLabel(int total) {
    return 'Tokens : $total';
  }

  @override
  String get chatTourProjectsConversations =>
      'Utilisez ce bouton pour ouvrir vos projets et conversations.';

  @override
  String get chatTourSidebarProjectTools =>
      'Utilisez ce menu pour afficher la barre latérale des conversations et les outils du projet.';

  @override
  String get chatTourSwitchFolders =>
      'Utilisez ce bouton pour changer de dossier de projet et de contexte.';

  @override
  String get chatUndoLastTurn => 'Annuler le dernier tour';

  @override
  String get chatUndoNothing => 'Rien à annuler dans cette session';

  @override
  String get chatUseCurrent => 'Utiliser l\'actuel';

  @override
  String get chatWaitingForNetworkConnection =>
      'Attente de connexion réseau...';

  @override
  String get chatWelcomeMessage => 'Bonjour ! Je suis votre assistant IA.';

  @override
  String get chatWelcomeSubmessage =>
      'Comment puis-je vous aider aujourd\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'hui ?';

  @override
  String get chatWorkBoundedPanelExplanation =>
      'L\'activité récente des outils reste à l\'intérieur de ce panneau délimité afin de maintenir la stabilité de la zone de visualisation.';

  @override
  String get chatWorkExpand => 'Développer';

  @override
  String get chatWorkHide => 'Masquer';

  @override
  String get chatWorkMessageOne => '1 message de travail';

  @override
  String chatWorkMessagesMultiple(int count) {
    return '$count messages de travail';
  }

  @override
  String get chatWorkShow => 'Afficher';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonCopiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonFile => 'Fichier';

  @override
  String get commonReset => 'Réinitialiser';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get compactionAutomatic => 'automatique';

  @override
  String get compactionManual => 'manuel';

  @override
  String get composerAddAttachment => 'Ajouter une pièce jointe';

  @override
  String get composerAttachFiles => 'Joindre des fichiers';

  @override
  String get composerCannedAppendAtCursor => 'Ajouter au curseur';

  @override
  String get composerCannedLabel => 'Libellé (facultatif)';

  @override
  String get composerCannedNoReplies => 'Aucune réponse rapide pour le moment.';

  @override
  String get composerCannedReplace => 'Remplacer';

  @override
  String get composerCannedSave => 'Enregistrer';

  @override
  String get composerCannedScopeGlobal => 'Global';

  @override
  String get composerCannedScopeProject => 'Projet uniquement';

  @override
  String get composerCannedSendAutomatically => 'Envoyer automatiquement';

  @override
  String get composerCannedText => 'Texte';

  @override
  String get composerChatInput => 'Saisie de discussion';

  @override
  String get composerDeleteAction => 'Supprimer';

  @override
  String get composerDropHint => 'Déposez des images ou PDF à joindre';

  @override
  String get composerPastedImageName => 'Image collée';

  @override
  String get composerEdit => 'Modifier';

  @override
  String get composerExtras => 'Extras';

  @override
  String get composerExtrasHide => 'Masquer les extras';

  @override
  String get composerNewQuickReply => 'Nouvelle réponse rapide';

  @override
  String get composerSelectImages => 'Sélectionner des images';

  @override
  String get composerSelectPdf => 'Sélectionner un PDF';

  @override
  String get composerSend => 'Envoyer';

  @override
  String get composerShellMode => 'Mode Shell';

  @override
  String get desktopWindowClose => 'Fermer';

  @override
  String get desktopWindowMaximize => 'Agrandir';

  @override
  String get desktopWindowMinimize => 'Réduire';

  @override
  String get desktopWindowRestore => 'Restaurer';

  @override
  String get dialogDownload => 'Télécharger';

  @override
  String get dialogLanguage => 'Langue';

  @override
  String get dialogMoonshineModelSize => 'Taille du modèle';

  @override
  String get dialogMoonshineVoiceSetup => 'Configuration vocale Moonshine';

  @override
  String get dialogParakeetModel => 'Modèle Parakeet';

  @override
  String get dialogParakeetVoiceSetup => 'Configuration vocale Parakeet';

  @override
  String get dialogSenseVoiceModel => 'Modèle SenseVoice';

  @override
  String get dialogSenseVoiceSetup => 'Configuration SenseVoice';

  @override
  String get dialogVoiceInputSetup => 'Configuration de la saisie vocale';

  @override
  String get errorAnErrorOccurred => 'Une erreur est survenue';

  @override
  String get errorAuthRequired => 'Authentification requise';

  @override
  String get errorAuthRequiredDesc =>
      'L\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'authentification a échoué. Reconnectez le fournisseur et réessayez.';

  @override
  String get errorConnectionFailed => 'Échec de la connexion';

  @override
  String get errorConnectionFailedDesc =>
      'Impossible de joindre le serveur. Vérifiez la connexion et l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'état du serveur.';

  @override
  String get errorFormatAuthenticationFailedReconnect =>
      'L\'authentification a échoué. Reconnectez le fournisseur et réessayez.';

  @override
  String get errorFormatProviderTemporarilyUnavailable =>
      'Fournisseur temporairement indisponible. Réessayez dans quelques instants.';

  @override
  String get errorFormatQuotaExceededCheck =>
      'Quota dépassé. Vérifiez le forfait ou la facturation de votre fournisseur.';

  @override
  String get errorFormatRateLimitExceeded =>
      'Limite de débit dépassée. Attendez un moment et réessayez.';

  @override
  String get errorFormatServerErrorPlease =>
      'Erreur de serveur. Veuillez réessayer.';

  @override
  String get errorFormatServiceTemporarilyUnavailable =>
      'Service temporairement indisponible. Le serveur est peut-être en train de démarrer — veuillez réessayer dans quelques instants.';

  @override
  String get errorFormatUnableReachServer =>
      'Impossible de joindre le serveur. Vérifiez la connexion et le statut du serveur.';

  @override
  String get errorProviderUnavailable => 'Fournisseur indisponible';

  @override
  String get errorProviderUnavailableDesc =>
      'Fournisseur temporairement indisponible. Réessayez bientôt.';

  @override
  String get errorQuotaExceeded => 'Quota dépassé';

  @override
  String get errorQuotaExceededDesc =>
      'Quota dépassé. Vérifiez votre plan de fournisseur ou votre facturation.';

  @override
  String get errorRateLimitExceeded => 'Limite de débit dépassée';

  @override
  String get errorRateLimitExceededDesc =>
      'Limite de débit dépassée. Attendez un moment et réessayez.';

  @override
  String get errorServerError => 'Erreur du serveur';

  @override
  String get errorServerErrorDesc => 'Erreur du serveur. Veuillez réessayer.';

  @override
  String get errorServiceUnavailable => 'Service indisponible';

  @override
  String get errorServiceUnavailableDesc =>
      'Service temporairement indisponible. Le serveur est peut-être en train de démarrer — veuillez réessayer bientôt.';

  @override
  String get fileActionAttachmentDataDecoded =>
      'Les données de la pièce jointe n\'ont pas pu être décodées.';

  @override
  String get fileActionAttachmentPathEmpty =>
      'Le chemin de la pièce jointe est vide.';

  @override
  String get fileActionAttachmentPayloadEmpty =>
      'La charge utile de la pièce jointe est vide.';

  @override
  String get fileActionAttachmentProvideValid =>
      'La pièce jointe ne fournit pas un emplacement valide.';

  @override
  String get fileActionAttachmentSavedDevice =>
      'La pièce jointe n\'a pas pu être enregistrée sur cet appareil.';

  @override
  String fileActionAttachmentSavedOutputFile(String path) {
    return 'Pièce jointe enregistrée dans $path et ouverte.';
  }

  @override
  String fileActionAttachmentSavedOutputFile2(String path) {
    return 'Pièce jointe enregistrée dans $path.';
  }

  @override
  String fileActionAttachmentSavedSavedPath(String savedPath) {
    return 'Pièce jointe enregistrée dans $savedPath.';
  }

  @override
  String get fileActionLocalAttachmentFound =>
      'La pièce jointe locale n\'a pas été trouvée sur cet appareil.';

  @override
  String get fileActionSaveCanceled => 'Enregistrement annulé.';

  @override
  String get fileActionUnableOpenLocal =>
      'Impossible d\'ouvrir la pièce jointe locale.';

  @override
  String get filesAddChat => 'Ajouter au chat';

  @override
  String get filesAutosave => 'Enregistrement auto';

  @override
  String get filesAutosaveOn => 'Enregistrement auto activé';

  @override
  String get filesAutosaveOff => 'Enregistrement auto désactivé';

  @override
  String get filesRedo => 'Rétablir';

  @override
  String get filesUndo => 'Annuler';

  @override
  String get filesBinaryFilePreview =>
      'L\'aperçu du fichier binaire n\'est pas disponible.';

  @override
  String get filesClear => 'Effacer';

  @override
  String get filesContents => 'Contenus';

  @override
  String get filesDuplicate => 'Dupliquer';

  @override
  String get filesDuplicated => 'Fichier dupliqué';

  @override
  String get filesFileEmpty => 'Le fichier est vide.';

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
  String get filesFilesFound => 'Aucun fichier trouvé';

  @override
  String get filesFileCreated => 'File created.';

  @override
  String get filesFolderCreated => 'Folder created.';

  @override
  String get filesHideSidebar => 'Masquer la barre latérale des fichiers';

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
  String get filesNames => 'Noms';

  @override
  String filesOpenFilesFileState(int length) {
    return 'Fichiers ouverts ($length)';
  }

  @override
  String get filesQuickOpen => 'Ouverture rapide';

  @override
  String get filesQuickOpenFile => 'Ouverture rapide de fichier';

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
  String get filesRefresh => 'Actualiser les fichiers';

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
  String get filesSearchHint => 'Rechercher des fichiers par nom ou chemin';

  @override
  String get filesDeleted => 'Deleted.';

  @override
  String get filesTitle => 'Fichiers';

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
  String get logsAppLogs => 'Journaux de l\'application';

  @override
  String get logsClear => 'Effacer les journaux';

  @override
  String get logsCloseSearch => 'Fermer la recherche';

  @override
  String get logsCopyFiltered => 'Copier les journaux filtrés';

  @override
  String get logsEnableLogging => 'Activer les logs de l\'app';

  @override
  String get logsEnableLoggingAction => 'Activer les logs';

  @override
  String get logsEnableLoggingDescription =>
      'Collecte des logs de diagnostic en mémoire. Laissez désactivé sauf pour résoudre un problème.';

  @override
  String get logsEntryContext => 'Contexte';

  @override
  String get logsEntryTags => 'Tags';

  @override
  String get logsFilterAll => 'Tous';

  @override
  String get logsFilterByTag => 'Tag';

  @override
  String get logsLevel => 'Niveau';

  @override
  String get logsLoggingDisabledDescription =>
      'CodeWalk ne collecte pas de logs détaillés de l\'app. Activez les logs uniquement lorsque vous avez besoin d\'un diagnostic.';

  @override
  String get logsLoggingDisabledTitle => 'Logs désactivés';

  @override
  String get logsMeasurePerformance => 'Mesurer les performances';

  @override
  String get logsMeasurePerformanceDescription =>
      'Capture la durée des opérations coûteuses. Laissez désactivé sauf pour diagnostiquer une lenteur.';

  @override
  String get logsNoLogsYet => 'Aucun log capturé pour le moment.';

  @override
  String get logsNoMatchingLogs =>
      'Aucun log ne correspond aux filtres actuels.';

  @override
  String get logsNoPerformanceData =>
      'Aucun journal de performance ne correspond aux filtres actuels.';

  @override
  String get logsNoTaskData =>
      'Aucune tâche ne correspond aux filtres actuels.';

  @override
  String logsPerformanceDuration(int elapsedMs) {
    return '$elapsedMs ms';
  }

  @override
  String get logsPerformanceFilter => 'Performance';

  @override
  String logsPerformanceTileTitle(
    int elapsedMs,
    String operation,
    String status,
  ) {
    return 'PERFORMANCE $operation | $elapsedMs ms | $status';
  }

  @override
  String get logsSearch => 'Rechercher dans les journaux';

  @override
  String logsShowingOrderedLength(int length, int length2) {
    return 'Affichage de $length sur $length2 entrées';
  }

  @override
  String get logsSlowestPerformance => 'Journaux de performance les plus lents';

  @override
  String get logsSlowestTasks => 'Tâches les plus lentes';

  @override
  String get logsTagCustomHint => 'Nom du tag (ex. : task:select_session)';

  @override
  String get logsTagCustomAction => 'Personnalisé...';

  @override
  String logsTaskDuration(int elapsedMs, String operation) {
    return '$operation — $elapsedMs ms';
  }

  @override
  String get logsTaskStatusCanceled => 'annulée';

  @override
  String get logsTaskStatusError => 'erreur';

  @override
  String get logsTaskStatusOk => 'ok';

  @override
  String get logsTimeRange => 'Intervalle de temps';

  @override
  String get mathExpressionLabel => 'Mathématiques';

  @override
  String get mermaidCopySourceTooltip => 'Copier la source';

  @override
  String get mermaidDiagramLabel => 'Diagramme Mermaid';

  @override
  String get modelAuto => 'Auto';

  @override
  String get modelChooseAgent => 'Choisir l\'agent';

  @override
  String get modelFavorites => 'Favoris';

  @override
  String get modelFree => 'Gratuit';

  @override
  String get modelLabelBaseEnglish => 'Base (Anglais)';

  @override
  String get modelLabelParakeet => 'Parakeet V3 (25 langues européennes)';

  @override
  String get modelLabelSenseVoice => 'SenseVoice (zh/en/ja/ko/yue)';

  @override
  String get modelLabelTinyEnglish => 'Tiny (Anglais)';

  @override
  String get modelLoadingModels => 'Chargement des modèles...';

  @override
  String get modelModelsFound => 'Aucun modèle trouvé';

  @override
  String get modelRetryModels => 'Réessayer les modèles';

  @override
  String get modelSearchHint => 'Rechercher un modèle ou un fournisseur';

  @override
  String get msgBatterySettingsFailed =>
      'Impossible d\'ouvrir les paramètres d\'optimisation de la batterie d\'Android.';

  @override
  String get msgBatterySettingsOpened =>
      'Paramètres de la batterie Android ouverts. Autorisez une utilisation sans restriction de la batterie pour CodeWalk.';

  @override
  String get msgClearUsernameNeedsConfigEdit =>
      'Effacer le nom d\'utilisateur de la conversation OpenCode nécessite toujours de modifier la configuration en dehors de l\'application.';

  @override
  String get msgCommandCopied => 'Commande copiée';

  @override
  String get msgCopiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String get msgEnterUsernameToSave =>
      'Entrez un nom d\'utilisateur pour enregistrer un nom de conversation OpenCode personnalisé.';

  @override
  String get msgFailedToSendMessage =>
      'Échec de l\'envoi du message. Brouillon conservé pour réessayer.';

  @override
  String get msgFailedToStartVoiceInput =>
      'Échec du démarrage de la saisie vocale';

  @override
  String msgFilePathNotFound(String path) {
    return 'Fichier non trouvé : $path';
  }

  @override
  String get msgFilteredLogsCopied =>
      'Journaux filtrés copiés dans le presse-papiers';

  @override
  String get msgInfoAgent => 'Agent';

  @override
  String get msgInfoCompaction => 'Compaction';

  @override
  String msgInfoCost(double cost) {
    return 'Coût : \\\$$cost';
  }

  @override
  String get msgInfoMessageInfo => 'Informations du message';

  @override
  String msgInfoModel(String modelId) {
    return 'Modèle : $modelId';
  }

  @override
  String get msgInfoNoMetadata => 'Aucune métadonnée disponible';

  @override
  String msgInfoPartDescriptionModel(String description, String model) {
    return '$description$model';
  }

  @override
  String get msgInfoPatch => 'Correctif';

  @override
  String msgInfoProvider(String providerId) {
    return 'Fournisseur : $providerId';
  }

  @override
  String get msgInfoRetry => 'Réessayer';

  @override
  String get msgInfoSnapshot => 'Instantané';

  @override
  String msgInfoSubtaskPartAgent(String agent) {
    return 'Sous-tâche ($agent)';
  }

  @override
  String msgInfoTokens(int total) {
    return 'Jetons : $total';
  }

  @override
  String get msgInfoUndoThisTurn => 'Annuler ce tour';

  @override
  String get msgInfoView => 'Voir';

  @override
  String get msgNoSystemSoundsFound =>
      'Aucun son système n\'a été trouvé sur cet appareil.';

  @override
  String get msgNoValidFilesSelected =>
      'Aucun fichier valide n\'a été sélectionné';

  @override
  String get msgSomeSelectedFilesNotAttached =>
      'Certains fichiers sélectionnés n\'ont pas pu être joints.';

  @override
  String get msgReadAloud => 'Lire à voix haute';

  @override
  String get msgReadAloudNotAvailable =>
      'La synthèse vocale n\'est pas disponible sur cet appareil.';

  @override
  String get msgSetupDebugCopied =>
      'Débogage de la configuration d\'OpenCode copié dans le presse-papiers';

  @override
  String get msgShareAsImage => 'Partager sous forme d\'image';

  @override
  String get msgShareAsImageFailed =>
      'Impossible de partager le message sous forme d\'image.';

  @override
  String get msgShareAsImageSubject => 'Message CodeWalk';

  @override
  String get msgShareAsImageTooTall =>
      'Le message est trop long pour être partagé sous forme d\'image.';

  @override
  String get msgStopReadAloud => 'Arrêter la lecture';

  @override
  String get msgSystemSoundPickerUnavailable =>
      'Le sélecteur de son système n\'est pas disponible sur cette plateforme.';

  @override
  String get msgUpdatedButRefreshFailed =>
      'Paramètre du serveur mis à jour, mais impossible d\'actualiser les fournisseurs de discussion.';

  @override
  String get msgVoiceInputUnavailable =>
      'La saisie vocale n\'est pas disponible sur cet appareil';

  @override
  String get notifAndroidBatteryOptimization =>
      'Optimisation de la batterie Android';

  @override
  String get notifConversationUpdates => 'Mises à jour de la conversation';

  @override
  String get notifNotificationsArriveReopening =>
      'Si les notifications n\'arrivent que lors de la réouverture de l\'application, autorisez CodeWalk à s\'exécuter sans optimisation sur cet appareil.';

  @override
  String get notifResponseRunningKeep =>
      'Lorsqu\'une réponse est en cours d\'exécution, garder le temps réel actif brièvement après avoir quitté l\'application.';

  @override
  String notifSelectedSoundLabel(String soundLabel) {
    return 'Sélectionné : $soundLabel';
  }

  @override
  String get notificationAgentFinished =>
      'L\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'agent a terminé la réponse actuelle.';

  @override
  String get notificationConversationUpdates =>
      'Mises à jour de la conversation';

  @override
  String get notificationOpenToClear =>
      'Ouvrez cette conversation pour effacer les notifications associées.';

  @override
  String get notificationSession => 'Session';

  @override
  String get notificationSoundLoadFailed =>
      'Échec du chargement des sons système Android';

  @override
  String get onboardingAIGeneratedTitles => 'Titres générés par l\'IA';

  @override
  String get onboardingAddServerLater =>
      'Vous pouvez ajouter un serveur plus tard dans Paramètres > Serveurs.';

  @override
  String get onboardingAddedButHealthCheckFailed =>
      'Serveur ajouté mais le test de santé a échoué. Il est peut-être encore en train de démarrer.';

  @override
  String get onboardingAlmostInstallOpenCode =>
      'Vous y êtes presque. Installez d\'abord OpenCode, puis connectez CodeWalk à l\'URL du serveur.';

  @override
  String onboardingAppProviderLocalSetupLogsLength(int length, int length2) {
    return '$length lignes de journal de configuration et $length2 événements de configuration sont disponibles dans l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'écran de débogage de configuration séparé.';
  }

  @override
  String get onboardingAuthenticate => 'S\'authentifier';

  @override
  String get onboardingAvailable => 'disponible';

  @override
  String get onboardingAvailableOnlyDesktop =>
      'Disponible uniquement sur ordinateur (Linux/macOS/Windows).';

  @override
  String get onboardingBasicAuthTip =>
      'Activez lauthentification de base uniquement si votre serveur OpenCode est protégé par un mot de passe.';

  @override
  String get onboardingChooseAnotherPath => 'Choisir un autre chemin';

  @override
  String get onboardingChooseHowToSetup =>
      'Choisissez comment configurer votre serveur';

  @override
  String get onboardingClear => 'Effacer';

  @override
  String get onboardingCloudflareAuthFailed =>
      'L\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'authentification Cloudflare Access a échoué.';

  @override
  String get onboardingCodeWalkAppOpenCode =>
      'CodeWalk is the app. OpenCode is the engine it connects to.';

  @override
  String get onboardingConnectRunningServer =>
      'Se connecter à un serveur en cours d\'exécution';

  @override
  String get onboardingConnectionIssue => 'Problème de connexion';

  @override
  String get onboardingConnectionSaved =>
      'Connexion au serveur enregistrée avec succès.';

  @override
  String get onboardingConnectionTips => 'Conseils de connexion';

  @override
  String get onboardingConnectionUpdated =>
      'Connexion au serveur mise à jour avec succès.';

  @override
  String get onboardingContinue => 'Continuer';

  @override
  String get onboardingContinueServerURL => 'Continuer vers l\'URL du serveur';

  @override
  String get onboardingCopyLoginURL => 'Copier l\'URL de connexion';

  @override
  String get onboardingCouldNotVerify =>
      'Impossible de vérifier la connexion au serveur.';

  @override
  String get onboardingDefaultURLEmulator =>
      'URL par défaut, boucle locale de l\'émulateur, authentification et aide au débogage.';

  @override
  String onboardingDesktopOnlyDiagnose(String appName) {
    return 'Ordinateur uniquement : $appName peut diagnostiquer, installer et exécuter OpenCode pour vous.';
  }

  @override
  String get onboardingDetailedSetupEvents =>
      'Des événements de configuration détaillés ont été capturés pour le dépannage.';

  @override
  String get onboardingDonShowAgain =>
      'Don\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'t show again';

  @override
  String get onboardingDone => 'Terminé';

  @override
  String get onboardingEditServer => 'Modifier le serveur';

  @override
  String get onboardingEditServerConnection =>
      'Modifier la connexion au serveur';

  @override
  String get onboardingEmulatorRemap =>
      'Sur l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'émulateur Android, localhost et 127.0.0.1 sont automatiquement redirigés vers 10.0.2.2.';

  @override
  String get onboardingEnterServerUrl =>
      'Entrez l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'URL du serveur';

  @override
  String get onboardingExisting => 'Utiliser l\'existant';

  @override
  String get onboardingExplainInstallOpenCode =>
      'Expliquer comment installer OpenCode, démarrer le serveur, puis se connecter depuis CodeWalk.';

  @override
  String get onboardingFailed => 'Échec';

  @override
  String get onboardingGoodOptionDesktop =>
      'Bonne première option sur ordinateur';

  @override
  String get onboardingHealthCheckFailedMayBeStarting =>
      'Le test de santé du serveur a échoué. Il est peut-être encore en train de démarrer.';

  @override
  String get onboardingInstallBinary => 'Installer le binaire';

  @override
  String get onboardingInstallBun => 'Installer via Bun';

  @override
  String get onboardingInstallBunOpenCode => 'Installer Bun + OpenCode';

  @override
  String get onboardingInstallNpm => 'Installer via npm';

  @override
  String get onboardingInstallRunOpenCode =>
      'Installer et exécuter OpenCode directement depuis CodeWalk sur ordinateur.';

  @override
  String get onboardingInvalidUrl => 'URL invalide';

  @override
  String get onboardingLabel => 'Libellé (facultatif)';

  @override
  String get onboardingLabelHint => 'Mon serveur';

  @override
  String onboardingLatestOutputAppProvider(String localServerLastOutput) {
    return 'Dernière sortie : $localServerLastOutput';
  }

  @override
  String get onboardingLetCodeWalkSet =>
      'Laisser CodeWalk le configurer localement';

  @override
  String get onboardingLocalServerSetup => 'Configuration du serveur local';

  @override
  String get onboardingManagedLocalServer => 'Serveur local géré';

  @override
  String get onboardingManagedLocalServer2 =>
      'Le mode serveur local géré est disponible uniquement sur les builds de bureau (Linux/macOS/Windows).';

  @override
  String onboardingNeedsOpenCodeServer(String appName) {
    return '$appName a besoin d\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'un serveur OpenCode avant de pouvoir vous aider avec votre code.';
  }

  @override
  String get onboardingNotAvailable => 'non disponible';

  @override
  String get onboardingNotWritable => 'non accessible en écriture';

  @override
  String get onboardingOpenCode => 'Qu\'est-ce qu\'OpenCode ?';

  @override
  String get onboardingOpenCodeRunningDevice =>
      'J\'ai déjà OpenCode en cours d\'exécution sur cet appareil ou quelque part sur mon réseau.';

  @override
  String get onboardingOpenCodeRunsLocally =>
      'OpenCode s\'exécute localement ou sur un serveur et alimente les fonctionnalités de codage IA dans CodeWalk. Si OpenCode est déjà en cours d\'exécution, connectez-vous-y. Sinon, choisissez l\'un des parcours de configuration guidés ci-dessous.';

  @override
  String get onboardingOpenTailscaleLogin =>
      'Impossible d\'ouvrir l\'URL de connexion Tailscale.';

  @override
  String get onboardingPassword => 'Mot de passe';

  @override
  String get onboardingPasswordRequired => 'Entrez le mot de passe';

  @override
  String get onboardingPickSetupPath =>
      'Choisissez le chemin de configuration qui correspond à votre installation actuelle d\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'OpenCode.';

  @override
  String get onboardingPreconditionDirectoryNotWritable =>
      'Le répertoire d\'installation n\'est pas accessible en écriture. Vérifiez les permissions de l\'utilisateur.';

  @override
  String get onboardingPreconditionInstallViaBunRecommendation =>
      'L\'installation via Bun est recommandée par les mainteneurs d\'OpenCode.';

  @override
  String get onboardingPreconditionNetworkFailed =>
      'Échec de l\'accès réseau. Vérifiez la connectivité avant d\'installer OpenCode.';

  @override
  String get onboardingPreconditionNoRuntimeDetected =>
      'Aucun runtime détecté. Installez le binaire OpenCode directement ou initialisez Bun d\'abord.';

  @override
  String get onboardingPreconditionNodeNpmAvailable =>
      'Node + npm sont disponibles. Installez OpenCode via npm ou installez Bun pour le flux recommandé.';

  @override
  String get onboardingPreconditionOpenCodeAlreadyAvailable =>
      'OpenCode est déjà disponible. Vous pouvez utiliser la commande détectée immédiatement.';

  @override
  String get onboardingPreconditionWindowsPathLagHint =>
      ' Sur Windows, actualisez les vérifications après l\'installation car les mises à jour de PATH peuvent tarder à se propager dans les applications déjà ouvertes.';

  @override
  String get onboardingPreconditionWindowsWslRecommendation =>
      'Build Windows détecté. WSL est recommandé par la documentation d\'OpenCode, mais npm install peut être utilisé en dernier recours.';

  @override
  String get onboardingReachable => 'accessible';

  @override
  String get onboardingReady => 'Prêt';

  @override
  String get onboardingRecommendedOrderTry =>
      'Ordre recommandé : essayez Installer Bun + OpenCode si vous voulez que CodeWalk configure tout automatiquement. Utilisez l\'existant si OpenCode est déjà installé.';

  @override
  String get onboardingRefreshChecks => 'Actualiser les vérifications';

  @override
  String get onboardingRunDiagnosticsToVerify =>
      'Exécutez les diagnostics pour vérifier les prérequis locaux d\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'OpenCode.';

  @override
  String get onboardingSaveAndTest => 'Enregistrer et tester';

  @override
  String get onboardingServerConnectedReady =>
      'Votre serveur est connecté et prêt à l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'emploi.';

  @override
  String get onboardingServerConnection => 'Connexion au serveur';

  @override
  String get onboardingServerSettingsSaved =>
      'Vos paramètres de serveur ont été enregistrés et les tests de santé ont été actualisés.';

  @override
  String get onboardingServerSetup => 'Configuration du serveur';

  @override
  String get onboardingServerUpdated => 'Serveur mis à jour';

  @override
  String get onboardingServerUrl => 'URL du serveur';

  @override
  String get onboardingSetup => 'Configuration';

  @override
  String get onboardingSetupWizard => 'Assistant de configuration';

  @override
  String get onboardingShowSetupSteps =>
      'Montrez-moi les étapes de configuration';

  @override
  String get onboardingShowSetupSteps2 =>
      'Afficher les étapes de configuration';

  @override
  String get onboardingSkip => 'Passer pour l\'instant';

  @override
  String get onboardingSkipSetup => 'Passer la configuration ?';

  @override
  String get onboardingStart => 'Démarrer';

  @override
  String onboardingStartUsing(String appName) {
    return 'Commencer à utiliser $appName';
  }

  @override
  String get onboardingStarting => 'Démarrage';

  @override
  String get onboardingStop => 'Arrêter';

  @override
  String get onboardingStopped => 'Arrêté';

  @override
  String get onboardingStopping => 'Arrêt';

  @override
  String onboardingSuggestedUrl(String url) {
    return 'URL suggérée pour le serveur OpenCode local : $url';
  }

  @override
  String get onboardingTailscaleAdminApproval =>
      'Approbation de l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'administrateur Tailscale requise';

  @override
  String get onboardingTailscaleAuthAfterSave =>
      'Tailscale s\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'authentifiera après l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'enregistrement';

  @override
  String onboardingTailscaleAuthAfterSaveTest(String appName) {
    return 'Après avoir enregistré et testé ce serveur, $appName ouvrira la page de connexion Tailscale si cet appareil nest pas encore authentifié.';
  }

  @override
  String get onboardingTailscaleConnected => 'Tailscale connecté';

  @override
  String get onboardingTailscaleConnecting => 'Connexion Tailscale en cours';

  @override
  String get onboardingTailscaleConnectionFailed =>
      'Échec de la connexion Tailscale';

  @override
  String get onboardingTailscaleLoginRequired => 'Connexion Tailscale requise';

  @override
  String get onboardingTailscaleOpenLoginUrl =>
      'Ouvrez l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'URL de connexion pour ajouter cet appareil à votre tailnet. Si le navigateur ne s\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'est pas ouvert, copiez l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'URL ci-dessous.';

  @override
  String get onboardingTailscaleUnsupported => 'Tailscale non supporté';

  @override
  String get onboardingTestConnection => 'Tester la connexion';

  @override
  String get onboardingTesting => 'Test en cours...';

  @override
  String get onboardingUnreachable => 'inaccessible';

  @override
  String get onboardingUseBasicAuth =>
      'Utiliser l\'authentification de base (Basic Auth)';

  @override
  String get onboardingUsername => 'Nom d\'utilisateur';

  @override
  String get onboardingUsernameRequired => 'Entrez le nom d\'utilisateur';

  @override
  String get onboardingUsesServerTitle =>
      'Uses your server\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'s title agent to name conversations';

  @override
  String get onboardingUsingDetectedCommand =>
      'Utilisation de la commande OpenCode détectée.';

  @override
  String get onboardingViewSetupDebug => 'Voir le débogage de la configuration';

  @override
  String onboardingWelcomeTo(String appName) {
    return 'Bienvenue sur $appName';
  }

  @override
  String get onboardingWindowsTipInstalling =>
      'Astuce Windows : après l\'installation, cliquez sur Actualiser les vérifications. Si la détection échoue toujours, rouvrez CodeWalk pour recharger les modifications du PATH.';

  @override
  String get onboardingWritable => 'accessible en écriture';

  @override
  String get onboardingYoureAllSet => 'Tout est prêt !';

  @override
  String get permissionAllowOnce => 'Autoriser une fois';

  @override
  String get permissionAlways => 'Toujours';

  @override
  String get permissionBack => 'Retour';

  @override
  String get permissionConfirmReject => 'Confirmer le rejet';

  @override
  String get permissionReject => 'Rejeter';

  @override
  String get permissionReopen => 'Rouvrir';

  @override
  String get questionAnswerSelected => 'Aucune réponse sélectionnée.';

  @override
  String get questionCommaSeparatedValues =>
      'Valeurs séparées par des virgules';

  @override
  String get questionQuestionGroupMarked =>
      'Groupe de questions marqué comme rejeté. Vous pouvez continuer à discuter et rouvrir ce groupe à tout moment avant de confirmer.';

  @override
  String get questionQuestionRequest => 'Demande de question';

  @override
  String get questionQuestionsProvidedSubmit =>
      'Aucune question fournie. Vous pouvez soumettre une réponse vide.';

  @override
  String get questionReviewAnswersSubmitting =>
      'Vérifiez vos réponses avant de les soumettre.';

  @override
  String get quotaAuthCookie => 'Cookie d\'authentification';

  @override
  String get quotaConnect => 'Connecter';

  @override
  String get quotaForget => 'Oublier';

  @override
  String get quotaOpenCodeGoConnectDescription =>
      'Connectez le tableau de bord d\'utilisation pour afficher les limites glissantes, hebdomadaires et mensuelles.';

  @override
  String get quotaOpenCodeGoDetected => 'OpenCode Go détecté';

  @override
  String get quotaOpenCodeGoNeedsReconnect =>
      'OpenCode Go doit être reconnecté';

  @override
  String get quotaOpenCodeGoReconnectDescription =>
      'Actualisez les identifiants du tableau de bord pour restaurer les barres d\'utilisation.';

  @override
  String get quotaOpenCodeGoUsage => 'Utilisation d\'OpenCode Go';

  @override
  String get quotaOpenDashboard => 'Ouvrir le tableau de bord OpenCode';

  @override
  String get quotaPaceExplanation =>
      'Le rythme prédit l\'utilisation totale à la fin de la fenêtre de limite actuelle selon le taux actuel.';

  @override
  String quotaPacePercent(String percent) {
    return 'Rythme $percent%';
  }

  @override
  String get quotaRateLimits => 'Limites d\'utilisation';

  @override
  String get quotaReconnect => 'Reconnecter';

  @override
  String get quotaRefreshing => 'Actualisation...';

  @override
  String quotaResetsIn(String time) {
    return 'Réinitialisation dans $time';
  }

  @override
  String get quotaSaving => 'Enregistrement...';

  @override
  String get quotaWorkspaceId => 'ID de l\'espace de travail';

  @override
  String get serverClearOAuth => 'Effacer l\'OAuth';

  @override
  String get serverConnectionAttention =>
      'La connexion au serveur nécessite votre attention.';

  @override
  String get serverHealthHealthy => 'En bonne santé';

  @override
  String get serverHealthUnhealthy => 'En mauvaise santé';

  @override
  String get serverHealthUnknown => 'Inconnu';

  @override
  String get serverOAuthAuthFailed => 'Échec de l\'authentification OAuth';

  @override
  String get serverOAuthChip => 'OAuth';

  @override
  String get serverOAuthNotSupported =>
      'Cloudflare Access OAuth n\'est pas pris en charge sur cette plateforme';

  @override
  String get serverReauthenticate => 'Se réauthentifier';

  @override
  String get serverTailscaleChip => 'Tailscale';

  @override
  String get serversActive => 'Actif';

  @override
  String get serversActiveServer => 'Serveur actif';

  @override
  String get serversAddLeastOpenCode =>
      'Ajoutez au moins un serveur OpenCode pour commencer à utiliser l\'application.';

  @override
  String get serversAddServer => 'Ajouter un serveur';

  @override
  String get serversCancel => 'Annuler';

  @override
  String get serversCannotActivateUnhealthy =>
      'Impossible d\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'activer un serveur défectueux';

  @override
  String get serversCheckHealth => 'Vérifier la santé (Health Check)';

  @override
  String get serversClearDefault => 'Effacer par défaut';

  @override
  String serversCommandAppProviderLocalServerCommandPath(
    String localServerCommandPath,
  ) {
    return 'Commande : $localServerCommandPath';
  }

  @override
  String get serversCopy => 'Copier';

  @override
  String get serversDefault => 'Par défaut';

  @override
  String get serversDelete => 'Supprimer';

  @override
  String get serversDeleteServer => 'Supprimer le serveur';

  @override
  String get serversDesktopModeExplanation =>
      'Le mode bureau peut lancer et gérer `opencode serve` directement depuis CodeWalk.';

  @override
  String get serversEdit => 'Modifier';

  @override
  String get serversLocalOpenCodeServer => 'Serveur local OpenCode';

  @override
  String get serversManagedModeAvailable =>
      'Ce mode géré est disponible uniquement sur les builds de bureau (Linux/macOS/Windows).';

  @override
  String get serversNoServersFound => 'Aucun serveur trouvé';

  @override
  String get serversRefreshHealth => 'Actualiser l\'état de santé';

  @override
  String serversRemoveProfileDisplayName(String displayName) {
    return 'Supprimer \"$displayName\" ?';
  }

  @override
  String get serversSearchActiveHint => 'Rechercher un serveur actif';

  @override
  String get serversServersConfigured => 'Aucun serveur configuré';

  @override
  String get serversSetActive => 'Définir comme actif';

  @override
  String get serversSetDefault => 'Définir comme serveur par défaut';

  @override
  String get serversSetupDebug => 'Débogage de la configuration';

  @override
  String get serversSetupWizard => 'Assistant de configuration';

  @override
  String get serversTailscaleAdminApprovalRequired =>
      'Approbation de l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'administrateur Tailscale requise';

  @override
  String get serversTailscaleAuthRequired =>
      'Authentification Tailscale requise';

  @override
  String get serversTailscaleConnectExplanation =>
      'Tailscale se connectera lorsque ce profil actif sera utilisé.';

  @override
  String get serversTailscaleConnected => 'Tailscale connecté';

  @override
  String get serversTailscaleConnecting => 'Connexion à Tailscale…';

  @override
  String get serversTailscaleConnectionFailed =>
      'Échec de la connexion Tailscale';

  @override
  String get serversTailscaleDisconnected => 'Tailscale déconnecté';

  @override
  String get serversTailscaleLoginExplanation =>
      'Ouvrez l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'URL de connexion Tailscale pour ajouter cet appareil à votre tailnet.';

  @override
  String get serversTailscaleTrafficExplanation =>
      'Le trafic OpenCode pour ce profil actif est acheminé via Tailscale.';

  @override
  String get serversTailscaleUnsupported => 'Tailscale non pris en charge';

  @override
  String get serversUnhealthyActivateError =>
      'Ce serveur est défectueux. Vérifiez son état ou modifiez les paramètres avant de l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'activer.';

  @override
  String get sessionActionArchived => 'archivée';

  @override
  String get sessionActionDeleted => 'supprimée';

  @override
  String get sessionActionForked => 'bifurquée (forked)';

  @override
  String get sessionActionPinned => 'épinglée';

  @override
  String get sessionActionUnarchived => 'désarchivée';

  @override
  String get sessionActionUnpinned => 'désépinglée';

  @override
  String get sessionArchive => 'Archiver';

  @override
  String get sessionCancelRename => 'Annuler le renommage';

  @override
  String sessionChildrenCount(int count) {
    return 'Sous-conversations : $count';
  }

  @override
  String get sessionCompactContext => 'Compacter le contexte';

  @override
  String get sessionCopyLink => 'Copier le lien';

  @override
  String get sessionDelete => 'Supprimer';

  @override
  String sessionDeleteConfirm(String title) {
    return 'Voulez-vous vraiment supprimer la conversation \"$title\" ? Cette action est irréversible.';
  }

  @override
  String get sessionDeleteTitle => 'Supprimer la conversation';

  @override
  String get sessionDiffChangedFile => 'Fichier modifié';

  @override
  String get sessionDiffContentNotCaptured =>
      'Contenu du fichier non capturé par le serveur';

  @override
  String sessionDiffFilesChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers modifiés',
      one: '1 fichier modifié',
    );
    return '$_temp0';
  }

  @override
  String sessionDiffFilesCount(int count) {
    return 'Fichiers diff : $count';
  }

  @override
  String sessionDiffLinesAddedRemoved(int added, int removed) {
    return '+$added lignes ajoutées -$removed lignes supprimées';
  }

  @override
  String sessionDiffLinesCollapsed(int count) {
    return '$count lignes réduites — appuyez pour développer';
  }

  @override
  String get sessionDiffLoading => 'Loading changed files…';

  @override
  String get sessionDiffReview => 'Examiner les modifications';

  @override
  String get sessionDiffSplit => 'Scindé';

  @override
  String get sessionDiffSummary => 'Résumé';

  @override
  String get sessionDiffUnified => 'Unifié';

  @override
  String get sessionExportAssistant => 'Assistant';

  @override
  String get sessionExportCanceled => 'Exportation annulée';

  @override
  String get sessionExportDebugJson => 'Exporter en JSON de débogage';

  @override
  String get sessionExportDebugJsonErrorClipboard =>
      'Impossible de sauvegarder ; JSON de débogage copié dans le presse-papiers';

  @override
  String get sessionExportDebugJsonSaved =>
      'Exportation JSON de débogage sauvegardée';

  @override
  String get sessionExportDebugJsonTitle =>
      'Exporter la session en JSON de débogage';

  @override
  String get sessionExportError => 'Erreur :';

  @override
  String get sessionExportInput => 'Entrée :';

  @override
  String get sessionExportMarkdown => 'Exporter en Markdown';

  @override
  String get sessionExportMarkdownErrorClipboard =>
      'Impossible de sauvegarder ; Markdown copié dans le presse-papiers';

  @override
  String get sessionExportMarkdownSaved => 'Exportation Markdown sauvegardée';

  @override
  String get sessionExportMarkdownTitle => 'Exporter la session en Markdown';

  @override
  String get sessionExportOutput => 'Sortie :';

  @override
  String get sessionExportUntitled => 'Session sans titre';

  @override
  String get sessionExportUser => 'Utilisateur';

  @override
  String get sessionFailedRename => 'Échec du renommage de la conversation';

  @override
  String get sessionFailedUpdateArchive =>
      'Échec de la mise à jour de l\'état d\'archivage';

  @override
  String get sessionFailedUpdateSharing =>
      'Échec de la mise à jour de l\'état de partage';

  @override
  String get sessionFork => 'Bifurquer (Fork)';

  @override
  String get sessionForkFailed => 'Échec du fork de la conversation';

  @override
  String get sessionForked => 'Conversation forké';

  @override
  String sessionHasError(String title) {
    return '\"$title\" a une erreur.';
  }

  @override
  String sessionHasNewReply(String title) {
    return '\"$title\" a une nouvelle réponse.';
  }

  @override
  String get sessionKeyboardShortcuts => 'Raccourcis clavier';

  @override
  String sessionNeedsInput(String title) {
    return '\"$title\" a besoin de votre saisie.';
  }

  @override
  String get sessionNoCachedConversations => 'Aucune conversation en cache';

  @override
  String get sessionNoConversationsInProject =>
      'Aucune conversation dans ce projet.';

  @override
  String get sessionNotAvailable =>
      'La conversation n\'est pas encore disponible pour ce projet';

  @override
  String get sessionOpenProjectToLoad =>
      'Ouvrez le projet pour charger les conversations.';

  @override
  String get sessionPin => 'Épingler';

  @override
  String get sessionRename => 'Renommer';

  @override
  String get sessionRenameHint => 'Entrez le nouveau nom de la conversation';

  @override
  String get sessionRenameTitle => 'Renommer la conversation';

  @override
  String get sessionSaveTitle => 'Enregistrer le titre';

  @override
  String get sessionShare => 'Partager la session';

  @override
  String get sessionShareAction => 'Partager';

  @override
  String get sessionShareLinkCopied => 'Lien de partage copié';

  @override
  String get sessionShareLinkUnavailable =>
      'Lien de partage indisponible pour cette session';

  @override
  String get sessionShared => 'Conversation partagée';

  @override
  String get sessionSyncing => 'Synchronisation des conversations...';

  @override
  String get sessionTitleHint => 'Titre de la conversation';

  @override
  String get sessionUnarchive => 'Désarchiver';

  @override
  String get sessionUnpin => 'Désépingler';

  @override
  String get sessionUnshare => 'Ne plus partager la session';

  @override
  String get sessionUnshareAction => 'Ne plus partager';

  @override
  String get sessionUnshared => 'Conversation non partagée';

  @override
  String get sessionViewTasks => 'Voir les tâches';

  @override
  String get settingsAboutCheckForUpdates => 'Vérifier les mises à jour';

  @override
  String get settingsAboutCheckOnOpen =>
      'Vérifier les mises à jour à l\'ouverture';

  @override
  String get settingsAboutCheckOnOpenDescription =>
      'Vérifier automatiquement au démarrage de l\'application';

  @override
  String get settingsAboutChecking => 'Vérification...';

  @override
  String get settingsAboutDescription =>
      'Version, mises à jour, aide et données de l\'app';

  @override
  String get settingsAboutDismiss => 'Ignorer';

  @override
  String settingsAboutDownloading(String percent) {
    return 'Téléchargement... $percent%';
  }

  @override
  String get settingsAboutEraseAllData =>
      'Effacer toutes les données et redémarrer';

  @override
  String get settingsAboutInstallUpdate => 'Installer la mise à jour';

  @override
  String get settingsAboutInstalling => 'Installation...';

  @override
  String settingsAboutLatestVersion(String version) {
    return 'v$version est la version la plus récente';
  }

  @override
  String get settingsAboutLoading => 'Chargement...';

  @override
  String get settingsAboutReplayChatTour => 'Rejouer la visite guidée';

  @override
  String get settingsAboutReplayChatTourDescription =>
      'Fermer les paramètres et afficher la visite guidée du chat';

  @override
  String get settingsAboutResetApp => 'Réinitialiser l\'application';

  @override
  String get settingsAboutResetAppQuestion => 'Réinitialiser l\'application ?';

  @override
  String get settingsAboutResetAppWarning =>
      'Cela effacera tous les serveurs, paramètres et données mises en cache. Cette action est irréversible.';

  @override
  String get settingsAboutRetryInstall => 'Réessayer l\'installation';

  @override
  String get settingsAboutTapToCheck =>
      'Appuyez pour vérifier les nouvelles versions';

  @override
  String get settingsAboutTitle => 'À propos';

  @override
  String get settingsAboutUpToDate =>
      'You\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'re up to date';

  @override
  String settingsAboutUpdateAvailable(String version) {
    return 'Mise à jour disponible : v$version';
  }

  @override
  String get settingsAboutUpdateInstalled =>
      'Mise à jour installée. Redémarrez l\'application pour l\'appliquer.';

  @override
  String settingsAboutUpdateVersionSummary(
    String installedVersion,
    String latestVersion,
  ) {
    return 'Actuelle : $installedVersion; disponible : v$latestVersion';
  }

  @override
  String get settingsAboutVersion => 'Version';

  @override
  String settingsAboutVersionBuild(String buildNumber, String version) {
    return '$version (build $buildNumber)';
  }

  @override
  String get settingsAppearanceAmoledDark => 'Mode sombre AMOLED';

  @override
  String get settingsAppearanceAmoledDarkActive =>
      'Utiliser des surfaces d\'un noir pur lorsque le mode sombre est actif.';

  @override
  String get settingsAppearanceAmoledDarkInactive =>
      'Basculez en mode sombre pour activer les surfaces AMOLED.';

  @override
  String get settingsAppearanceBrandColor => 'Couleur de marque';

  @override
  String get settingsAppearanceBrandColorDynamicBlocked =>
      'Désactivez les couleurs du fond d\'écran pour choisir une couleur de marque.';

  @override
  String get settingsAppearanceBrandColorNormal =>
      'Choisissez une couleur de départ pour la palette de l\'application.';

  @override
  String get settingsAppearanceBrandColorPresetBlocked =>
      'Basculez vers CodeWalk Classique pour choisir une couleur de marque.';

  @override
  String get settingsAppearanceChatFontScale => 'Conversation text size';

  @override
  String get settingsAppearanceChatFontScaleDescription =>
      'Scale the chat message and composer text on top of the system text size.';

  @override
  String get settingsAppearanceCodeWalkClassic => 'CodeWalk Classique';

  @override
  String get settingsAppearanceComposerTips =>
      'Conseils de l\'éditeur de message';

  @override
  String get settingsAppearanceComposerTipsDescription =>
      'Afficher ou masquer les conseils rotatifs pendant que l\'assistant réfléchit.';

  @override
  String get settingsAppearanceContrast => 'Contraste';

  @override
  String get settingsAppearanceContrastDynamicBlocked =>
      'Désactivez les couleurs du fond d\'écran pour ajuster le contraste.';

  @override
  String get settingsAppearanceContrastHigh => 'Élevé';

  @override
  String get settingsAppearanceContrastNormal =>
      'Ajustez le niveau de contraste du schéma de couleurs.';

  @override
  String get settingsAppearanceContrastPresetBlocked =>
      'Basculez vers CodeWalk Classique pour ajuster le contraste.';

  @override
  String get settingsAppearanceContrastReduced => 'Réduit';

  @override
  String get settingsAppearanceDark => 'Sombre';

  @override
  String get settingsAppearanceDensity => 'Densité';

  @override
  String get settingsAppearanceDensityDense => 'Dense';

  @override
  String get settingsAppearanceDensityDescription =>
      'Appliquez l\'espacement et la densité des composants dans l\'application.';

  @override
  String get settingsAppearanceDensityExtraDense => 'Très dense';

  @override
  String get settingsAppearanceDensityExtraSpacious => 'Très espacé';

  @override
  String get settingsAppearanceDensityNormal => 'Normal';

  @override
  String get settingsAppearanceDensitySpacious => 'Espacé';

  @override
  String get settingsAppearanceDescription =>
      'Choisissez les thèmes, couleurs, taille du texte et affichage du chat';

  @override
  String get settingsAppearanceFontSize => 'Text size';

  @override
  String get settingsAppearanceFontSizeDescription =>
      'Adjust the size of system text, conversation text, and terminal text.';

  @override
  String get settingsAppearanceLight => 'Clair';

  @override
  String get settingsAppearanceMathRendering => 'Rendu mathématique';

  @override
  String get settingsAppearanceMathRenderingDescription =>
      'Afficher les expressions mathématiques LaTeX sous forme d\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'équations composées dans les messages.';

  @override
  String get settingsAppearanceNoPresets => 'Aucune palette prédéfinie trouvée';

  @override
  String get settingsAppearanceOpenCodePresets => 'Préréglages OpenCode';

  @override
  String get settingsAppearancePresetHelper =>
      'Reflète la liste des thèmes intégrés officielle d\'OpenCode Web.';

  @override
  String get settingsAppearancePresetNote =>
      'Les couleurs du thème suivent désormais le registre officiel d\'OpenCode Web et gèrent également les surfaces de code et de markdown.';

  @override
  String get settingsAppearancePresetPalette => 'Palette prédéfinie';

  @override
  String get settingsAppearanceSearchPreset =>
      'Rechercher une palette prédéfinie';

  @override
  String get settingsAppearanceSectionDescription =>
      'Ajustez la densité visuelle et les surfaces de message pour votre flux de travail.';

  @override
  String get settingsAppearanceSectionTitle => 'Apparence';

  @override
  String get settingsAppearanceSystem => 'Système';

  @override
  String get settingsAppearanceSystemFontScale => 'System text size';

  @override
  String get settingsAppearanceSystemFontScaleDescription =>
      'Scale all text in the app shell, including menus, dialogs, and sidebars.';

  @override
  String get settingsAppearanceTaskList => 'Liste de tâches';

  @override
  String get settingsAppearanceTaskListDescription =>
      'Afficher ou masquer le widget de la liste de tâches de la session.';

  @override
  String get settingsAppearanceTerminalFontSize => 'Terminal text size';

  @override
  String get settingsAppearanceTerminalFontSizeDescription =>
      'Resize the embedded terminal font. Applies immediately to running sessions.';

  @override
  String get settingsAppearanceTheme => 'Thème';

  @override
  String get settingsAppearanceThemeDescription =>
      'Choisissez le mode clair, sombre ou système, puis conservez la palette classique de CodeWalk ou passez à un préréglage OpenCode.';

  @override
  String get settingsAppearanceVisualStyle => 'Style visuel';

  @override
  String get settingsAppearanceVisualStyleDescription =>
      'Choisissez le style classique ou des surfaces raffinées plus douces.';

  @override
  String get settingsAppearanceVisualStyleClassic => 'Classique';

  @override
  String get settingsAppearanceVisualStyleRefined => 'Raffiné';

  @override
  String get settingsAppearanceThinkingBubbles => 'Bulles de réflexion';

  @override
  String get settingsAppearanceThinkingBubblesDescription =>
      'Afficher ou masquer les blocs de raisonnement dans les messages de l\'assistant.';

  @override
  String get settingsAppearanceTitle => 'Apparence';

  @override
  String get settingsAppearanceToolCallBubbles => 'Bulles d\'appel d\'outil';

  @override
  String get settingsAppearanceToolCallBubblesDescription =>
      'Afficher ou masquer les cartes d\'exécution d\'outil dans les messages de l\'assistant.';

  @override
  String get settingsAppearanceWallpaperColors =>
      'Utiliser les couleurs du fond d\'écran';

  @override
  String get settingsAppearanceWallpaperNormal =>
      'Extraire le schéma de couleurs du fond d\'écran de votre appareil.';

  @override
  String get settingsAppearanceWallpaperPresetBlocked =>
      'Basculez vers CodeWalk Classique pour utiliser les couleurs du fond d\'écran.';

  @override
  String get settingsAppearanceWindowChrome => 'Onglets de la fenêtre';

  @override
  String get settingsAppearanceWindowChromeDescription =>
      'Choisissez comment les onglets de session et la barre de titre sont combinés sur ordinateur.';

  @override
  String get settingsAppearanceWindowChromeIntegrated => 'Onglets intégrés';

  @override
  String get settingsAppearanceWindowChromeIntegratedDescription =>
      'Les onglets occupent le haut de la fenêtre et la barre de titre du système est masquée.';

  @override
  String get settingsAppearanceWindowChromeSystem => 'Décoration système';

  @override
  String get settingsAppearanceWindowChromeSystemDescription =>
      'Conserve la barre de titre native et affiche les onglets sous la barre d’application.';

  @override
  String get settingsBack => 'Retour';

  @override
  String get settingsBehaviorAutoupdateCaveat =>
      'Utilisez À propos pour les vérifications de version de CodeWalk. Ce paramètre reflète uniquement la configuration officielle `autoupdate` d\'OpenCode.';

  @override
  String get settingsBehaviorAutoupdateHelp =>
      'Contrôle les mises à jour du moteur d\'exécution OpenCode en amont, et non les vérifications de mise à jour de l\'application CodeWalk.';

  @override
  String get settingsBehaviorCellularDataSaver =>
      'Économiseur de données mobiles';

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
      'CodeWalk appliquera ce paramètre OpenCode après la fin de la réponse actuelle.';

  @override
  String settingsBehaviorConfigUpdateFailed(String field) {
    return 'Impossible de mettre à jour le champ OpenCode $field.';
  }

  @override
  String get settingsBehaviorConversationUsername =>
      'Nom d\'utilisateur de conversation';

  @override
  String get settingsBehaviorConversationUsernameHelp =>
      'Nom d\'affichage personnalisé affiché dans les conversations au lieu du nom d\'utilisateur système.';

  @override
  String get settingsBehaviorDataSaverActive =>
      'Actif actuellement sur les données mobiles.';

  @override
  String get settingsBehaviorDataSaverCellularOnly =>
      'S\'applique uniquement lorsque la connexion est mobile/cellulaire.';

  @override
  String get settingsBehaviorDataSaverDescription =>
      'Réduit l\'utilisation automatique des données mobiles en arrêtant les téléchargements en arrière-plan et en limitant les actualisations automatiques en premier plan.';

  @override
  String get settingsBehaviorDataSaverWaiting =>
      'En attente de la prochaine fenêtre de synchronisation des données mobiles.';

  @override
  String get settingsBehaviorDefaultAgent => 'Agent par défaut';

  @override
  String get settingsBehaviorDefaultAgentHelp =>
      'Agent principal utilisé lorsqu\'aucun agent n\'est explicitement choisi.';

  @override
  String get settingsBehaviorDefaultModel => 'Modèle par défaut';

  @override
  String get settingsBehaviorDefaultModelHelp =>
      'Partagé entre les clients OpenCode via la configuration.';

  @override
  String get settingsBehaviorDescription =>
      'Contrôlez la langue, le comportement du chat, l\'utilisation des données et les réglages par défaut d\'OpenCode';

  @override
  String get settingsBehaviorEnableDataSaver =>
      'Activer l\'économiseur de données mobiles';

  @override
  String get settingsBehaviorMultiDeviceSync =>
      'Activer la synchronisation multi-appareil expérimentale';

  @override
  String get settingsBehaviorMultiDeviceSyncDescription =>
      'Synchroniser la sélection de l\'éditeur (agent/modèle/variante) avec la configuration du serveur actif.';

  @override
  String get settingsBehaviorMultiDeviceSyncWarning =>
      'Peut interrompre les sessions en cours lors du travail dans plusieurs sessions en même temps.';

  @override
  String get settingsBehaviorNoAgents => 'Aucun agent trouvé';

  @override
  String get settingsBehaviorNoModels => 'Aucun modèle trouvé';

  @override
  String get settingsBehaviorOpenCodeAutoupdate =>
      'Mise à jour automatique d\'OpenCode';

  @override
  String get settingsBehaviorOpenCodeDefaults =>
      'Valeurs par défaut basées sur OpenCode';

  @override
  String get settingsBehaviorOpenCodeDefaultsDescription =>
      'Ces valeurs sont écrites dans `/config` sur le serveur actif et correspondent à la configuration partagée officielle d\'OpenCode.';

  @override
  String get settingsBehaviorOpenCodeSnapshots => 'Instantanés OpenCode';

  @override
  String get settingsBehaviorOpenCodeSnapshotsDescription =>
      'Garder les instantanés en amont basés sur git activés pour l\'annulation/rétablissement et l\'historique de récupération.';

  @override
  String get settingsBehaviorPermissionDeferred =>
      'L\'édition avancée des règles de permission reste en dehors des paramètres pour le moment et est reportée à des travaux de parité ultérieurs.';

  @override
  String get settingsBehaviorPermissionProvenance =>
      'Provenance de la gestion des permissions';

  @override
  String get settingsBehaviorPermissionProvenanceDescription =>
      'La politique officielle de permissions d\'OpenCode est configurée dans `opencode.json` avec des règles autoriser/demander/refuser par outil. CodeWalk conserve les cartes officielles de demande de permission et ajoute une exception approuvée selon l\'ADR-023 : le bouton d\'approbation automatique de l\'éditeur de message répond par `Always` et `remember: true` de manière inconditionnelle pour créer des autorisations durables limitées à la session, et maintient le même chemin de continuité limité au thread actif dans le processus d\'arrière-plan Android.';

  @override
  String get settingsBehaviorRefreshDefaults =>
      'Actualiser les valeurs par défaut';

  @override
  String get settingsBehaviorSaveUsername =>
      'Enregistrer le nom d\'utilisateur';

  @override
  String get settingsBehaviorSearchAutoupdate =>
      'Rechercher le mode de mise à jour automatique';

  @override
  String get settingsBehaviorSearchDefaultAgent =>
      'Rechercher l\'agent par défaut';

  @override
  String get settingsBehaviorSearchDefaultModel =>
      'Rechercher le modèle par défaut';

  @override
  String get settingsBehaviorSearchShareMode => 'Rechercher le mode de partage';

  @override
  String get settingsBehaviorSearchSmallModel => 'Rechercher un petit modèle';

  @override
  String get settingsBehaviorShareMode => 'Partage OpenCode par défaut';

  @override
  String get settingsBehaviorShareModeCaveat =>
      'Use the chat-level share action to publish one session now. This setting only changes OpenCode\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'s default sharing policy.';

  @override
  String get settingsBehaviorShareModeHelp =>
      'Contrôle la configuration globale officielle `share`, et non le bouton de partage pour une discussion individuelle.';

  @override
  String get settingsBehaviorSmallModel => 'Petit modèle';

  @override
  String get settingsBehaviorSmallModelAutoFallback => 'Repli automatique';

  @override
  String get settingsBehaviorSmallModelFallbackActive =>
      'Le repli automatique d\'OpenCode est actif car `small_model` n\'est pas défini.';

  @override
  String get settingsBehaviorSmallModelHelp =>
      'Utilisé pour des tâches légères comme la génération de titres.';

  @override
  String get settingsBehaviorSmallModelResetCaveat =>
      'Rétablir `small_model` au repli automatique nécessite toujours de modifier la configuration en dehors de l\'application car les mises à jour de correctifs `/config` ne peuvent pas supprimer de clés.';

  @override
  String get settingsBehaviorSnapshotCaveat =>
      'Cela contrôle le stockage des instantanés OpenCode et la prise en charge de l\'annulation/rétablissement, et non les instantanés du cache local de CodeWalk.';

  @override
  String get settingsBehaviorTitle => 'Comportement';

  @override
  String get settingsBehaviorUsernameFallback =>
      'OpenCode utilise le nom d\'utilisateur système car `username` n\'est pas défini.';

  @override
  String get settingsBehaviorUsernamePatchCaveat =>
      'Rétablir `username` à sa valeur par défaut du système nécessite toujours de modifier la configuration en dehors de l\'application car les mises à jour de correctifs `/config` ne peuvent pas supprimer de clés.';

  @override
  String get settingsConfigRefreshFailed =>
      'Paramètre du serveur mis à jour, mais impossible d\'actualiser les fournisseurs de discussion.';

  @override
  String get settingsConfigUpdateDeferred =>
      'CodeWalk appliquera ce paramètre OpenCode après la fin de la réponse actuelle.';

  @override
  String get settingsConversationUsername =>
      'Nom d\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'utilisateur de la conversation';

  @override
  String get settingsDefaultAgent => 'Agent par défaut';

  @override
  String get settingsDefaultModel => 'Modèle par défaut';

  @override
  String get settingsLanguageDescription =>
      'Choisissez la langue utilisée par CodeWalk. Par défaut, le système suit la langue de votre appareil.';

  @override
  String get settingsLanguageEmptyText => 'Aucune langue trouvée';

  @override
  String get settingsLanguageFieldHelper =>
      'S\'applique immédiatement et persiste après les redémarrages.';

  @override
  String get settingsLanguageFieldLabel => 'Langue de l\'application';

  @override
  String get settingsLanguageSearchHint => 'Rechercher des langues';

  @override
  String get settingsLanguageSystemDefault => 'Langue par défaut du système';

  @override
  String get settingsLanguageTitle => 'Langue';

  @override
  String get settingsLogsDescription =>
      'Consultez les diagnostics de l\'app et les détails de dépannage';

  @override
  String get settingsLogsTitle => 'Registros';

  @override
  String get settingsNoAgentsFound => 'Aucun agent trouvé';

  @override
  String get settingsNotificationsAgentSubtitle =>
      'Lorsqu\'une réponse se termine';

  @override
  String get settingsNotificationsAgentUpdates => 'Mises à jour de l\'agent';

  @override
  String get settingsNotificationsAnotherConversation =>
      'Une autre conversation';

  @override
  String get settingsNotificationsAppInBackground =>
      'Application en arrière-plan';

  @override
  String get settingsNotificationsBackgroundAlerts =>
      'Alertes en arrière-plan Android';

  @override
  String get settingsNotificationsBackgroundBehavior =>
      'Comportement en arrière-plan';

  @override
  String get settingsNotificationsBackgroundBehaviorDescription =>
      'Choisissez le comportement de CodeWalk après que l\'application a quitté le premier plan.';

  @override
  String get settingsNotificationsBackgroundDescription =>
      'Utilisez la surveillance en arrière-plan à faible consommation de données pour les fins de réponse, les demandes de permissions, les questions et les erreurs lorsque l\'application n\'est pas à l\'écran.';

  @override
  String get settingsNotificationsBackgroundToggle =>
      'Alertes en arrière-plan sur Android';

  @override
  String get settingsNotificationsBackgroundToggleDescription =>
      'Désactiver toutes les vérifications en arrière-plan Android et masquer la notification de surveillance persistante.';

  @override
  String get settingsNotificationsBatteryDescription =>
      'Si les notifications n\'arrivent que lors de la réouverture de l\'application, autorisez CodeWalk à s\'exécuter sans optimisation sur cet appareil.';

  @override
  String get settingsNotificationsBatteryDisabled =>
      'L\'optimisation de la batterie est désactivée pour CodeWalk.';

  @override
  String get settingsNotificationsBatteryEnabled =>
      'L\'optimisation de la batterie est activée. Certains appareils peuvent retarder les alertes en arrière-plan.';

  @override
  String get settingsNotificationsBatteryOptimization =>
      'Optimisation de la batterie Android';

  @override
  String get settingsNotificationsBatteryUnknown =>
      'Impossible de lire le statut d\'optimisation de la batterie pour le moment.';

  @override
  String get settingsNotificationsChooseAudioFile => 'Choisir un fichier audio';

  @override
  String get settingsNotificationsChooseSystemSound => 'Choisir un son système';

  @override
  String get settingsNotificationsCloseToTray => 'Fermer dans la barre d\'état';

  @override
  String get settingsNotificationsCloseToTrayDescription =>
      'Masquer la fenêtre et continuer l\'exécution dans la barre d\'état système.';

  @override
  String get settingsNotificationsDescription =>
      'Choisissez quels événements vous alertent et de quelle manière';

  @override
  String get settingsNotificationsDisableOptimization =>
      'Désactiver l\'optimisation';

  @override
  String get settingsNotificationsErrors => 'Erreurs';

  @override
  String get settingsNotificationsErrorsSubtitle =>
      'Lorsqu\'une session signale un échec';

  @override
  String get settingsNotificationsJustClose => 'Fermer simplement';

  @override
  String get settingsNotificationsJustCloseDescription =>
      'Quitter complètement l\'application.';

  @override
  String get settingsNotificationsKeepLive =>
      'Garder les alertes actives pendant 3 min';

  @override
  String get settingsNotificationsKeepLiveDescription =>
      'Lorsqu\'une réponse est déjà en cours, garder le temps réel actif brièvement après avoir quitté l\'application.';

  @override
  String get settingsNotificationsLocal => 'Local';

  @override
  String get settingsNotificationsMinimizeWhenClose =>
      'Minimiser lors de la fermeture';

  @override
  String get settingsNotificationsMinimizeWhenCloseDescription =>
      'Réduire dans la barre des tâches/dock et continuer l\'exécution.';

  @override
  String get settingsNotificationsNoCondition =>
      'Si aucune condition n\'est sélectionnée, les alertes sont autorisées dans tous les contextes.';

  @override
  String get settingsNotificationsNotify => 'Notifier';

  @override
  String get settingsNotificationsNotifyOnlyWhen => 'Notifier uniquement si';

  @override
  String get settingsNotificationsOpenBatterySettings =>
      'Ouvrir les paramètres de la batterie';

  @override
  String get settingsNotificationsPermissions => 'Permissions et questions';

  @override
  String get settingsNotificationsPermissionsSubtitle =>
      'Lorsque les outils demandent votre intervention';

  @override
  String get settingsNotificationsPreview => 'Aperçu';

  @override
  String get settingsNotificationsRefreshStatus => 'Actualiser le statut';

  @override
  String get settingsNotificationsSearchSoundType =>
      'Rechercher un type de son';

  @override
  String get settingsNotificationsSectionDescription =>
      'Contrôlez quand les alertes s\'affichent et quand elles peuvent émettre un son.';

  @override
  String get settingsNotificationsSectionTitle => 'Notifications';

  @override
  String settingsNotificationsSelectedSound(String label) {
    return 'Sélectionné : $label';
  }

  @override
  String get settingsNotificationsServer => 'Serveur';

  @override
  String get settingsNotificationsSound => 'Son';

  @override
  String get settingsNotificationsSoundBuiltInAlert => 'Alerte intégrée';

  @override
  String get settingsNotificationsSoundBuiltInClick => 'Clic intégré';

  @override
  String get settingsNotificationsSoundOff => 'Désactivé';

  @override
  String get settingsNotificationsSoundOnlyWhen => 'Son uniquement si';

  @override
  String get settingsNotificationsSoundPickAudioFile =>
      'Choisir un fichier audio';

  @override
  String get settingsNotificationsSoundPickFromSystem =>
      'Choisir depuis le système';

  @override
  String get settingsNotificationsSoundSystemDefault => 'Par défaut du système';

  @override
  String get settingsNotificationsSoundType => 'Type de son';

  @override
  String get settingsNotificationsSyncInfo =>
      'Certaines options d\'activation/désactivation de catégorie sont synchronisées depuis /config sur le serveur actif.';

  @override
  String get settingsNotificationsSyncInfoLocal =>
      'Le serveur actuel n\'expose pas d\'options de notification dans /config ; les valeurs locales sont actives.';

  @override
  String get settingsNotificationsSystemSoundPickerTitle =>
      'Choisir un son système';

  @override
  String get settingsNotificationsTitle => 'Notifications';

  @override
  String get settingsNotificationsWhenClosing =>
      'Lors de la fermeture de la fenêtre';

  @override
  String get settingsOpenCodeAutoUpdate => 'Mise à jour automatique OpenCode';

  @override
  String get settingsOpenCodeSharingDefault => 'Partage OpenCode par défaut';

  @override
  String get settingsReadAloudEnabled => 'Lire à voix haute';

  @override
  String get settingsReadAloudEnabledDescription =>
      'Afficher un bouton de lecture à voix haute sur les messages de l\'assistant.';

  @override
  String get settingsReadAloudPitch => 'Tonalité';

  @override
  String get settingsReadAloudPitchDescription =>
      'Ajuster la tonalité de la voix.';

  @override
  String get settingsReadAloudSectionDescription =>
      'Lire les réponses de l\'assistant à voix haute. Configurez la vitesse, la tonalité et la voix.';

  @override
  String get settingsReadAloudSectionTitle => 'Synthèse vocale';

  @override
  String get settingsReadAloudSpeed => 'Vitesse';

  @override
  String get settingsReadAloudSpeedDescription => 'Ajuster le débit de parole.';

  @override
  String get settingsReadAloudVoice => 'Voix';

  @override
  String get settingsReadAloudVoiceHint =>
      'Sélectionner une voix pour la lecture.';

  @override
  String get settingsSearchAutoUpdateMode =>
      'Rechercher le mode de mise à jour automatique';

  @override
  String get settingsSearchDefaultAgent =>
      'Rechercher l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'agent par défaut';

  @override
  String get settingsSearchDefaultModel => 'Rechercher le modèle par défaut';

  @override
  String get settingsSearchSharingMode => 'Rechercher le mode de partage';

  @override
  String get settingsSearchSmallModel => 'Rechercher le petit modèle';

  @override
  String get settingsServersActive => 'Actif';

  @override
  String get settingsServersChooseActive => 'Choisir le serveur actif';

  @override
  String get settingsServersDefault => 'Par défaut';

  @override
  String get settingsServersDescription =>
      'Connectez-vous à OpenCode et gérez vos serveurs';

  @override
  String get settingsServersTitle => 'Serveurs';

  @override
  String get settingsSessionAttentionSize => 'Taille de la bulle';

  @override
  String get settingsSessionAttentionSizeExtraLarge => 'Très grand';

  @override
  String get settingsSessionAttentionSizeExtraSmall => 'Très petit';

  @override
  String get settingsSessionAttentionSizeLarge => 'Grand';

  @override
  String get settingsSessionAttentionSizeSmall => 'Petit';

  @override
  String get settingsSessionAttentionSizeStandard => 'Standard';

  @override
  String get settingsSetupWizard => 'Assistant de configuration';

  @override
  String get settingsShortcutsDescription =>
      'Trouvez et personnalisez les raccourcis clavier';

  @override
  String get settingsShortcutsEdit => 'Modifier le raccourci';

  @override
  String get settingsShortcutsKeyboard => 'Raccourcis clavier';

  @override
  String get settingsShortcutsReset => 'Réinitialiser le raccourci';

  @override
  String get settingsShortcutsSearch => 'Rechercher des raccourcis';

  @override
  String get settingsShortcutsTitle => 'Raccourcis';

  @override
  String get settingsSmallModel => 'Petit modèle';

  @override
  String get settingsSmallModelResetExplanation =>
      'Réinitialiser `small_model` par défaut nécessite toujours de modifier la config en dehors de l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'application car les patchs `/config` ne peuvent pas supprimer de clés.';

  @override
  String get settingsSmallModelUnsetExplanation =>
      'Le repli automatique d\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'OpenCode est actif car `small_model` n\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'est pas défini.';

  @override
  String get settingsSoundPickerNotAvailable =>
      'Le sélecteur de sons système n\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'est pas disponible sur cette plateforme.';

  @override
  String get settingsSpeechDescription =>
      'Configurez la saisie vocale, les modèles hors ligne et la lecture à voix haute';

  @override
  String get settingsSpeechRefreshStatus => 'Actualiser le statut';

  @override
  String settingsSpeechSilenceTimeout(String value) {
    return 'Délai d\'inactivité de silence : ${value}s';
  }

  @override
  String get settingsSpeechTitle => 'Reconnaissance vocale';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsGroupAlertTypes => 'Types d\'alerte';

  @override
  String get settingsGroupBackgroundBehavior => 'Comportement en arrière-plan';

  @override
  String get settingsGroupChatDisplay => 'Affichage du chat';

  @override
  String get settingsGroupCurrentConnection => 'Connexion actuelle';

  @override
  String get settingsGroupDataAndSync => 'Données et synchronisation';

  @override
  String get settingsGroupDataReset => 'Données et réinitialisation';

  @override
  String get settingsGroupDelivery => 'Livraison';

  @override
  String get settingsGroupHelp => 'Aide';

  @override
  String get settingsGroupLanguageAndChat => 'Langue et chat';

  @override
  String get settingsGroupLayoutAndText => 'Disposition et texte';

  @override
  String get settingsGroupOfflineModels => 'Modèles hors ligne';

  @override
  String get settingsGroupOpenCodeDefaults => 'Réglages par défaut d\'OpenCode';

  @override
  String get settingsGroupReadAloud => 'Lecture à voix haute';

  @override
  String get settingsGroupSavedServers => 'Serveurs enregistrés';

  @override
  String get settingsGroupThemeAndColor => 'Thème et couleur';

  @override
  String get settingsGroupThisDevice => 'Cet appareil';

  @override
  String get settingsGroupVersionUpdates => 'Version et mises à jour';

  @override
  String get settingsGroupVoiceInput => 'Saisie vocale';

  @override
  String get settingsNavigationGroupExperience => 'Expérience';

  @override
  String get settingsNavigationGroupInput => 'Saisie';

  @override
  String get settingsNavigationGroupSetup => 'Configuration';

  @override
  String get settingsNavigationGroupSupport => 'Aide et diagnostic';

  @override
  String get settingsNavigationNoResults => 'Aucun réglage trouvé';

  @override
  String get settingsNavigationSearchHint => 'Rechercher des réglages';

  @override
  String get settingsUsernameClearHint =>
      'Effacer le nom d\'utilisateur de la conversation OpenCode nécessite toujours de modifier la configuration en dehors de l\'application.';

  @override
  String get settingsUsernameEnterHint =>
      'Entrez un nom d\'utilisateur pour enregistrer un nom de conversation OpenCode personnalisé.';

  @override
  String get settingsUsernameResetExplanation =>
      'Réinitialiser `username` par défaut nécessite toujours de modifier la config en dehors de l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'application car les patchs `/config` ne peuvent pas supprimer de clés.';

  @override
  String get settingsUsernameUnsetExplanation =>
      'OpenCode utilise le nom d\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'utilisateur du système car `username` n\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'est pas défini.';

  @override
  String get setupDebugBun => 'Bun';

  @override
  String get setupDebugBun2 => 'Bun';

  @override
  String get setupDebugCapturedSetupDetails =>
      'Aucun détail de configuration capturé pour le moment';

  @override
  String get setupDebugCapturedSetupLogs =>
      'Journaux de configuration capturés';

  @override
  String get setupDebugClear => 'Effacer le débogage de la configuration';

  @override
  String get setupDebugClearSetupDebug =>
      'Effacer le débogage de la configuration';

  @override
  String get setupDebugCodeWalkCaptureEnough =>
      'Si CodeWalk n\'a pas capturé assez de contexte, vérifiez directement les journaux officiels et les points de terminaison d\'état de santé d\'OpenCode :';

  @override
  String get setupDebugCommandPath => 'Chemin de la commande';

  @override
  String get setupDebugCommandPath2 => 'Chemin de la commande';

  @override
  String get setupDebugCopy => 'Copier le débogage de la configuration';

  @override
  String get setupDebugCopySetupDebug =>
      'Copier le débogage de la configuration';

  @override
  String get setupDebugCurrentStatus => 'Statut actuel';

  @override
  String get setupDebugDiagnosticsLoading =>
      'Les diagnostics sont encore en cours de chargement.';

  @override
  String get setupDebugEnvironment => 'Diagnostics de l\'environnement';

  @override
  String get setupDebugEnvironmentDiagnostics =>
      'Diagnostics de l\'environnement';

  @override
  String get setupDebugFocusedOpenCodeSetup =>
      'Axé sur la configuration d\'OpenCode';

  @override
  String get setupDebugInstallDir => 'Répertoire d\'installation';

  @override
  String get setupDebugInstallDirectory => 'Répertoire d\'installation';

  @override
  String get setupDebugLatestLocalServer => 'Dernière sortie du serveur local';

  @override
  String get setupDebugLogs => 'Journaux de configuration capturés';

  @override
  String get setupDebugManual => 'Dépannage manuel';

  @override
  String get setupDebugManualTroubleshooting => 'Dépannage manuel';

  @override
  String get setupDebugNetwork => 'Réseau';

  @override
  String get setupDebugNetwork2 => 'Réseau';

  @override
  String get setupDebugNoDetails =>
      'Aucun détail de configuration capturé pour le moment';

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
      'Débogage de la configuration d\'OpenCode';

  @override
  String get setupDebugPlatform => 'Plateforme';

  @override
  String get setupDebugPlatform2 => 'Plateforme';

  @override
  String get setupDebugRunDiagnosticsTry =>
      'Exécutez des diagnostics, essayez une méthode d\'installation ou tentez une procédure de configuration pour capturer ici les détails de dépannage spécifiques à OpenCode.';

  @override
  String get setupDebugScreenCoversOpenCode =>
      'Cet écran couvre uniquement l\'installation, les diagnostics et le dépannage de la configuration locale d\'OpenCode. Utilisez les journaux de l\'application pour les problèmes généraux d\'exécution de CodeWalk.';

  @override
  String get setupDebugServerOutput => 'Dernière sortie du serveur local';

  @override
  String get setupDebugStatus => 'Statut actuel';

  @override
  String setupDebugTimeEntrySource(String source, String time) {
    return '$time - $source';
  }

  @override
  String get setupDebugTimeline => 'Chronologie';

  @override
  String get setupDebugTimeline2 => 'Chronologie';

  @override
  String get setupDebugTitle => 'Axé sur la configuration d\'OpenCode';

  @override
  String get setupDebugWSL => 'WSL';

  @override
  String get setupDebugWsl => 'WSL';

  @override
  String get shortcutCloseApp => 'Fermer l\'onglet/l\'application';

  @override
  String get shortcutCloseAppDesc =>
      'Fermer l\'onglet de session actuel s\'il est disponible, sinon fermer l\'application selon le comportement de la plateforme';

  @override
  String get shortcutFocusCloseDrawer => 'Focus/fermer le tiroir';

  @override
  String get shortcutFocusCloseDrawerDesc =>
      'Focus sur l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'entrée par défaut, ou fermer le tiroir s\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'il est ouvert';

  @override
  String get shortcutFocusInput => 'Focus sur lentrée';

  @override
  String get shortcutFocusInputDesc =>
      'Déplacer le focus vers l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'entrée de texte';

  @override
  String get shortcutGroupApplication => 'Application';

  @override
  String get shortcutGroupGeneral => 'Général';

  @override
  String get shortcutGroupModelAndAgent => 'Modèle et agent';

  @override
  String get shortcutGroupNavigation => 'Navigation';

  @override
  String get shortcutGroupPrompt => 'Invite';

  @override
  String get shortcutGroupSession => 'Session';

  @override
  String get shortcutNewConversation => 'Nouvelle conversation';

  @override
  String get shortcutNewConversationDesc =>
      'Créer une nouvelle session de chat';

  @override
  String get shortcutNextAgent => 'Agent suivant';

  @override
  String get shortcutNextAgentDesc =>
      'Passer à l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'agent disponible suivant';

  @override
  String get shortcutNextRecentModel => 'Modèle récent suivant';

  @override
  String get shortcutNextRecentModelDesc =>
      'Passer d\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'un modèle récemment utilisé à l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'autre';

  @override
  String get shortcutNextVariant => 'Variante suivante';

  @override
  String get shortcutNextVariantDesc =>
      'Passer d\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'une variante de modèle disponible à l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'autre';

  @override
  String get shortcutOpenSettings => 'Ouvrir les paramètres';

  @override
  String get shortcutOpenSettingsDesc => 'Ouvrir la page des paramètres';

  @override
  String get shortcutPreviousAgent => 'Agent précédent';

  @override
  String get shortcutPreviousAgentDesc =>
      'Passer à l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'agent disponible précédent';

  @override
  String get shortcutQuickOpenFiles => 'Ouverture rapide de fichiers';

  @override
  String get shortcutQuickOpenFilesDesc =>
      'Ouvrir la recherche rapide de fichiers';

  @override
  String get shortcutQuitApp => 'Quitter lapplication';

  @override
  String get shortcutQuitAppDesc =>
      'Forcer la sortie de l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'application';

  @override
  String get shortcutRefreshData => 'Actualiser les données';

  @override
  String get shortcutRefreshDataDesc => 'Actualiser les données du chat actuel';

  @override
  String get shortcutStopResponse => 'Arrêter la réponse';

  @override
  String get shortcutStopResponseDesc =>
      'Arrêter la réponse active (pendant la réponse)';

  @override
  String get shortcutToggleVoiceInput => 'Basculer la saisie vocale';

  @override
  String get shortcutToggleVoiceInputDesc =>
      'Démarrer ou arrêter la saisie vocale dans léditeur';

  @override
  String get shortcutsApply => 'Appliquer';

  @override
  String shortcutsConflictConflict(String conflict) {
    return 'Conflit avec $conflict';
  }

  @override
  String get shortcutsKeyboardShortcuts => 'Raccourcis clavier';

  @override
  String get shortcutsReset => 'Tout réinitialiser';

  @override
  String get shortcutsSearchEditBindings =>
      'Recherchez, modifiez les affectations et résolvez les conflits avant d\'enregistrer.';

  @override
  String shortcutsSetShortcutWidget(String label) {
    return 'Définir le raccourci : $label';
  }

  @override
  String get shortcutsTheseBindingsStored =>
      'Ces affectations sont stockées dans CodeWalk pour la durée d\'exécution actuelle de l\'application et ne modifient pas les raccourcis clavier `tui.json` d\'OpenCode.';

  @override
  String get speechAutoStopSilence =>
      'Délai d\'inactivité de silence pour arrêt automatique';

  @override
  String get speechChooseRecognitionEngine =>
      'Choisissez le moteur de reconnaissance, le délai d\'inactivité de silence et les options de modèle.';

  @override
  String speechDesktopOnly(String service) {
    return '$service est disponible sur ordinateur uniquement.';
  }

  @override
  String get speechDownload => 'Télécharger';

  @override
  String get speechEngine => 'Moteur';

  @override
  String get speechInstalledLanguages => 'Langues installées';

  @override
  String get speechListeningStopsAutomatically =>
      'L\'écoute s\'arrête automatiquement après ce nombre de secondes de silence.';

  @override
  String get speechMicPermissionDisabled =>
      'L\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'autorisation du microphone est désactivée.';

  @override
  String speechModelFilesIncomplete(String service) {
    return 'Les fichiers du modèle $service sont incomplets.';
  }

  @override
  String get speechMoonshine => 'Moonshine';

  @override
  String get speechMoonshineModelsDesktop => 'Modèles Moonshine (ordinateur)';

  @override
  String get speechMoonshineStaysDownloadable =>
      'Moonshine reste téléchargeable et en dehors du paquet de l\'application. Choisissez un modèle pour cet ordinateur et supprimez-le plus tard si vous souhaitez libérer de l\'espace.';

  @override
  String get speechNative => 'Natif';

  @override
  String get speechNativeSTTDisabled =>
      'La transcription vocale native est désactivée sur Linux dans cette application. Parakeet est le moteur par défaut pour les nouvelles installations.';

  @override
  String get speechNativeSTTWorks =>
      'On Windows, CodeWalk uses local on-device speech recognition through its WASAPI microphone backend. Native Windows speech recognition is disabled for stability.';

  @override
  String get speechNativeStartsFaster =>
      'Le mode natif démarre plus rapidement. Sherpa s\'exécute entièrement sur l\'appareil avec une configuration plus lourde et un contrôle de modèle plus approfondi.';

  @override
  String get speechOpenMicrophoneSettings => 'Open microphone settings';

  @override
  String get speechOpenSpeechPrivacy => 'Open speech privacy';

  @override
  String get speechOpenSpeechSettings => 'Open speech settings';

  @override
  String get speechParakeet => 'Parakeet';

  @override
  String get speechParakeetModelsDesktop => 'Modèles Parakeet (ordinateur)';

  @override
  String get speechParakeetStaysDownloadable =>
      'Parakeet reste téléchargeable et en dehors du paquet de l\'application. Il expose actuellement un modèle multilingue optimisé pour 25 langues européennes.';

  @override
  String get speechPickLanguagePacks =>
      'Choisissez des packs de langues et téléchargez/supprimez des modèles pour la reconnaissance sur l\'appareil.';

  @override
  String get speechRemove => 'Supprimer';

  @override
  String speechRuntimeFailed(String service) {
    return 'Le runtime $service n\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'a pas pu s\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'initialiser.';
  }

  @override
  String get speechSelectSherpaAbove =>
      'Sélectionnez Sherpa ci-dessus pour gérer les packs de langues et télécharger des modèles.';

  @override
  String get speechSenseVoice => 'SenseVoice';

  @override
  String get speechSenseVoiceModelsDesktop => 'Modèles SenseVoice (ordinateur)';

  @override
  String get speechSenseVoiceStaysDownloadable =>
      'SenseVoice reste téléchargeable et en dehors du paquet de l\'application. C\'est l\'option sur ordinateur la plus performante ici pour le chinois, le cantonais, le japonais, le coréen et l\'anglais.';

  @override
  String get speechSherpa => 'Sherpa';

  @override
  String get speechSherpaExperimentalFail =>
      'Sherpa est expérimental et peut échouer sur certains appareils. Préférez le mode natif si vous souhaitez le comportement le plus stable.';

  @override
  String get speechSherpaModelsLinux => 'Modèles Sherpa (Linux)';

  @override
  String get speechSpeechText => 'Reconnaissance vocale';

  @override
  String speechUnavailableOnPlatform(String service) {
    return 'La parole $service n\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'est pas disponible sur cette plateforme.';
  }

  @override
  String get speechWindowsSetupHint =>
      'Windows voice input uses CodeWalk WASAPI capture with on-device models. Keep microphone access for desktop apps enabled; the buttons below open Windows settings for troubleshooting.';

  @override
  String get statusConnected => 'Connecté';

  @override
  String get statusDelayed => 'Retardé';

  @override
  String get statusFailed => 'Échec';

  @override
  String get statusOffline => 'Hors ligne';

  @override
  String get statusOnline => 'En ligne';

  @override
  String get statusReconnecting => 'Reconnexion';

  @override
  String get statusStarting => 'Démarrage';

  @override
  String get statusStopped => 'Arrêté';

  @override
  String get statusStopping => 'Arrêt';

  @override
  String get statusSyncDelayed => 'Synchronisation retardée';

  @override
  String get tailscaleNoPeers => 'Aucun pair trouvé';

  @override
  String get tailscaleNotSupportedOnPlatform =>
      'Tailscale n\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'est pas supporté sur cette plateforme.';

  @override
  String get tailscaleNotSupportedOnWindows =>
      'Tailscale n\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'est pas supporté sur Windows.';

  @override
  String get tailscalePeerOffline => 'hors ligne';

  @override
  String get tailscaleSelectPeer => 'Sélectionner un pair Tailscale';

  @override
  String get tailscaleWaitingAdminApproval =>
      'Ce nœud Tailscale est en attente de l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'approbation de l\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'administrateur.';

  @override
  String get terminalClose => 'Fermer le terminal';

  @override
  String terminalConnectingTo(String serverName) {
    return 'Connexion au terminal de $serverName...';
  }

  @override
  String terminalConnectionFailed(String error) {
    return 'Échec de la connexion au terminal : $error';
  }

  @override
  String get terminalDisconnected => 'Terminal déconnecté.';

  @override
  String terminalEmbeddedUnavailable(String serverName) {
    return 'Le terminal intégré n\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'est pas encore disponible sur ce runtime. Continuez à utiliser le mode shell du compositeur pour les commandes ponctuelles ou ouvrez le terminal depuis un runtime d\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'application CodeWalk supporté pour $serverName.';
  }

  @override
  String get terminalExtraKeyAlt => 'Touche Alt';

  @override
  String get terminalExtraKeyArrowDown => 'Flèche vers le bas';

  @override
  String get terminalExtraKeyArrowLeft => 'Flèche vers la gauche';

  @override
  String get terminalExtraKeyArrowRight => 'Flèche vers la droite';

  @override
  String get terminalExtraKeyArrowUp => 'Flèche vers le haut';

  @override
  String get terminalExtraKeyControl => 'Touche Contrôle';

  @override
  String get terminalExtraKeyEscape => 'Touche Échap';

  @override
  String get terminalExtraKeyTab => 'Touche Tabulation';

  @override
  String get terminalExtraKeys => 'Touches supplémentaires du terminal';

  @override
  String get terminalHide => 'Masquer le terminal';

  @override
  String get terminalMaximize => 'Maximiser';

  @override
  String get terminalMinimize => 'Réduire le terminal';

  @override
  String get terminalNotAvailableYet =>
      'Le terminal intégré n\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'est pas encore disponible sur ce runtime.';

  @override
  String get terminalOpen => 'Ouvrir le terminal';

  @override
  String get terminalOpenInfo => 'Ouvrir les infos du terminal';

  @override
  String get terminalOpenProjectFirst =>
      'Ouvrez un dossier de projet avant de démarrer le terminal du serveur.';

  @override
  String get terminalOpenToConnect =>
      'Ouvrez le Terminal pour vous connecter au terminal du projet du serveur.';

  @override
  String get terminalReconnect => 'Reconnecter le terminal';

  @override
  String get terminalRestoreSize => 'Restaurer la taille';

  @override
  String get terminalSelectServer =>
      'Sélectionnez un serveur actif avant d\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'\'ouvrir le Terminal.';

  @override
  String get terminalSessionClosed => 'Session de terminal fermée.';

  @override
  String get terminalTerminal => 'Terminal';

  @override
  String get terminalTitle => 'Terminal';

  @override
  String get terminalTryAgain => 'Réessayer';

  @override
  String get toolAwaitingInput => 'En attente de saisie';

  @override
  String get toolEditing => 'Modification en cours';

  @override
  String get toolEditingFiles => 'Modification des fichiers';

  @override
  String get toolFinding => 'Recherche en cours';

  @override
  String get toolFindingFiles => 'Recherche de fichiers';

  @override
  String get toolPresentationAwaitingInput => 'En attente de saisie';

  @override
  String get toolPresentationEditing => 'Modification en cours';

  @override
  String get toolPresentationEditingFiles => 'Modification des fichiers';

  @override
  String get toolPresentationFinding => 'Recherche en cours';

  @override
  String get toolPresentationFindingFiles => 'Recherche de fichiers';

  @override
  String get toolPresentationReading => 'Lecture en cours';

  @override
  String get toolPresentationReadingFile => 'Lecture du fichier';

  @override
  String get toolPresentationRunning => 'Exécution en cours';

  @override
  String get toolPresentationRunningCommand => 'Exécution de la commande';

  @override
  String toolPresentationRunningTool(String toolName) {
    return 'Exécution de $toolName';
  }

  @override
  String get toolPresentationSearching => 'Recherche en cours';

  @override
  String get toolPresentationSearchingCode => 'Recherche dans le code';

  @override
  String get toolPresentationSearchingWeb => 'Recherche sur le Web';

  @override
  String get toolPresentationTool => 'Outil';

  @override
  String get toolPresentationUpdatingTaskList =>
      'Mise à jour de la liste de tâches';

  @override
  String get toolPresentationUpdatingTasks => 'Mise à jour des tâches';

  @override
  String get toolPresentationWaitingInput => 'En attente de votre intervention';

  @override
  String get toolPresentationWriting => 'Écriture en cours';

  @override
  String get toolPresentationWritingFile => 'Écriture du fichier';

  @override
  String get toolReading => 'Lecture en cours';

  @override
  String get toolReadingFile => 'Lecture du fichier';

  @override
  String get toolRunning => 'Exécution en cours';

  @override
  String get toolRunningCommand => 'Exécution de la commande';

  @override
  String get toolRunningTask => 'Exécution de la tâche';

  @override
  String get toolSearching => 'Recherche en cours';

  @override
  String get toolSearchingCode => 'Recherche dans le code';

  @override
  String get toolSearchingWeb => 'Recherche sur le Web';

  @override
  String get toolUpdatingTaskList => 'Mise à jour de la liste de tâches';

  @override
  String get toolUpdatingTasks => 'Mise à jour des tâches';

  @override
  String get toolWaitingForInput => 'En attente de votre intervention';

  @override
  String get toolWriting => 'Écriture en cours';

  @override
  String get toolWritingFile => 'Écriture du fichier';

  @override
  String get tourBack => 'Retour';

  @override
  String get tourSkip => 'Passer';

  @override
  String get trayQuit => 'Quitter';

  @override
  String get trayShow => 'Afficher';

  @override
  String get useOAuthCloudflareAccess => 'Utiliser OAuth (Cloudflare Access)';

  @override
  String get useOAuthCloudflareAccessSubtitle =>
      'Ouvre un navigateur pour l\'authentification OAuth gérée de Cloudflare Access.';

  @override
  String get useOAuthCloudflareAccessUnsupported =>
      'L\'authentification OAuth de Cloudflare Access n\'est pas disponible sur cette plateforme. Utilisez l\'authentification de base (Basic Auth) à la place.';

  @override
  String get useTailscale => 'Utiliser Tailscale';

  @override
  String get useTailscaleSubtitle =>
      'Achemine le trafic via le réseau Tailscale sans VPN système.';

  @override
  String get useTailscaleUnsupported =>
      'Tailscale n\'est pas pris en charge sur cette plateforme.';

  @override
  String get utilityTitle => 'Utilitaire';

  @override
  String get workspaceBrowseDirs => 'Parcourir les répertoires';

  @override
  String get workspaceChooseFolderOpen =>
      'Choisissez n\'importe quel dossier à ouvrir en tant que contexte du projet.';

  @override
  String workspaceCloseProject(String project) {
    return 'Fermer $project';
  }

  @override
  String get workspaceClosedProjects => 'Projets fermés';

  @override
  String workspaceCurrentDirectory(String path) {
    return 'Répertoire actuel : $path';
  }

  @override
  String get workspaceFilterDirs => 'Filtrer les répertoires';

  @override
  String get workspaceOpenFolder => 'Ouvrir le dossier';

  @override
  String get workspaceOpenProjectFolder => 'Ouvrir le dossier du projet';

  @override
  String get workspaceOpenProjects => 'Projets ouverts';

  @override
  String get workspaceProjectDirectory => 'Répertoire du projet';

  @override
  String get workspaceProjectHint => '/repo/my-project';

  @override
  String workspaceRemoveFromHistory(String name) {
    return 'Retirer $name de l\'historique';
  }

  @override
  String get settingsSessionAttentionTitle => 'Attention aux sessions';

  @override
  String get settingsSessionAttentionDescription =>
      'Affiche l’état des sessions racines dans une bulle ou un panneau facultatif.';

  @override
  String get settingsSessionAttentionOff => 'Désactivé';

  @override
  String get settingsSessionAttentionBubble => 'Bulle';

  @override
  String get settingsSessionAttentionPanel => 'Panneau';

  @override
  String get settingsSessionAttentionPrivacy =>
      'Sur Android, l’activation démarre un service de premier plan persistant. Le texte des réponses est chiffré; la synthèse vocale cloud ne l’envoie qu’après un appui sur Lire.';

  @override
  String get settingsSessionAttentionUnavailable =>
      'L’attention aux sessions n’est pas disponible sur cette plateforme.';

  @override
  String get settingsSessionAttentionOpenSettings =>
      'Ouvrir les réglages d’affichage';

  @override
  String get settingsSessionAttentionStop => 'Arrêter l’attention aux sessions';

  @override
  String get settingsSessionAttentionThirdPartyTtsWarning =>
      'Après un appui sur Lire, le texte de la réponse peut être envoyé au fournisseur TTS tiers configuré.';

  @override
  String get workspaceSuggestions => 'Suggestions';

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
