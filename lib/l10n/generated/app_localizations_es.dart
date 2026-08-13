// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get aboutGitHub => 'GitHub';

  @override
  String get appProviderCannotActivateUnhealthy =>
      'No se puede activar un servidor no saludable';

  @override
  String get appProviderDesktopOnly =>
      'El servidor local gestionado solo está disponible en escritorio.';

  @override
  String get appProviderDetectingCommand => 'Detectando comando OpenCode...';

  @override
  String get appProviderErrorCannotActivateUnhealthy =>
      'No se puede activar un servidor no saludable';

  @override
  String get appProviderErrorCloudflareOAuthNotSupported =>
      'Cloudflare Access OAuth no es compatible con esta plataforma';

  @override
  String get appProviderErrorInstallationFailed =>
      'La instalación de OpenCode falló.';

  @override
  String get appProviderErrorInvalidServerUrl => 'URL del servidor inválida';

  @override
  String get appProviderErrorLocalServerHealthCheckFailed =>
      'El servidor local se inició pero la comprobación de salud no pasó.';

  @override
  String get appProviderErrorManagedDesktopOnly =>
      'El servidor local gestionado solo está disponible en escritorio.';

  @override
  String get appProviderErrorServerAlreadyExists =>
      'Ya existe un servidor con esta URL';

  @override
  String get appProviderErrorServerProfileNotFound =>
      'Perfil de servidor no encontrado';

  @override
  String get appProviderErrorServerUrlRequired =>
      'La URL del servidor es obligatoria';

  @override
  String get appProviderErrorTailscaleNotSupported =>
      'Tailscale no es compatible con esta plataforma';

  @override
  String appProviderExitedWithCode(int code) {
    return 'El servidor local salió con el código $code.';
  }

  @override
  String get appProviderFailedToStart =>
      'Error al iniciar el servidor OpenCode local.';

  @override
  String get appProviderInstallBinary => 'Instalar binario';

  @override
  String get appProviderInstallBunOpenCode => 'Instalar Bun + OpenCode';

  @override
  String get appProviderInstallSucceeded => 'Instalación exitosa.';

  @override
  String appProviderInstallSucceededWithPath(String path) {
    return 'Instalación exitosa. Comando OpenCode disponible en $path.';
  }

  @override
  String get appProviderInstallViaBun => 'Instalar vía Bun';

  @override
  String get appProviderInstallViaNpm => 'Instalar vía npm';

  @override
  String get appProviderInstallationFailed =>
      'La instalación de OpenCode falló.';

  @override
  String get appProviderInstalledSuccessfully =>
      'Requisitos de OpenCode instalados con éxito.';

  @override
  String get appProviderInstallingRequirements =>
      'Instalando requisitos de OpenCode...';

  @override
  String get appProviderInvalidServerUrl => 'URL del servidor inválida';

  @override
  String get appProviderLabelLocalOpenCodeManaged =>
      'OpenCode Local (Gestionado)';

  @override
  String get appProviderLabelPrimaryServer => 'Servidor primario';

  @override
  String get appProviderLocalManaged => 'OpenCode Local (Gestionado)';

  @override
  String get appProviderLocalServerStopped =>
      'El servidor local está detenido.';

  @override
  String get appProviderNotDetectedInstall =>
      'No se detectó el comando OpenCode. Ejecute la instalación desde el asistente.';

  @override
  String appProviderNotDetectedRefresh(String appName) {
    return 'No se detectó el comando OpenCode. Si lo instaló hace un momento, refresque las comprobaciones o reabra $appName para recargar el PATH.';
  }

  @override
  String get appProviderOAuthNotSupported =>
      'Cloudflare Access OAuth no es compatible con esta plataforma';

  @override
  String get appProviderOpenCodeDetected => 'OpenCode detectado';

  @override
  String get appProviderOpenCodeNotDetected => 'OpenCode no detectado';

  @override
  String get appProviderPrimaryServer => 'Servidor primario';

  @override
  String get appProviderProfileNotFound => 'Perfil de servidor no encontrado';

  @override
  String get appProviderRunDiagnostics =>
      'Ejecute diagnósticos para verificar los requisitos locales de OpenCode.';

  @override
  String appProviderRunningAt(String url) {
    return 'Ejecutándose en $url';
  }

  @override
  String get appProviderSetupDetectingOpenCode =>
      'Detectando comando OpenCode...';

  @override
  String get appProviderSetupInstallationSucceeded => 'Instalación exitosa.';

  @override
  String appProviderSetupInstallationSucceededWithPath(String path) {
    return 'Instalación exitosa. Comando OpenCode disponible en $path.';
  }

  @override
  String get appProviderSetupInstallingRequirements =>
      'Instalando requisitos de OpenCode...';

  @override
  String get appProviderSetupOpenCodeDetected => 'OpenCode detectado';

  @override
  String get appProviderSetupOpenCodeNotDetected => 'OpenCode no detectado';

  @override
  String get appProviderSetupOpenCodeNotDetectedInstall =>
      'No se detectó el comando OpenCode. Ejecute la instalación desde el asistente.';

  @override
  String get appProviderSetupOpenCodeNotDetectedRefresh =>
      'No se detectó el comando OpenCode. Si lo instaló hace un momento, refresque las comprobaciones o reabra CodeWalk para recargar el PATH.';

  @override
  String get appProviderSetupRequirementsInstalled =>
      'Requisitos de OpenCode instalados con éxito.';

  @override
  String appProviderSetupUsingOpenCodeAt(String path) {
    return 'Usando comando OpenCode en $path';
  }

  @override
  String get appProviderStartingLocalServer => 'Iniciando servidor local...';

  @override
  String appProviderStatusLocalServerExitedWithCode(int code) {
    return 'El servidor local salió con el código $code.';
  }

  @override
  String get appProviderStatusLocalServerStopped =>
      'El servidor local está detenido.';

  @override
  String appProviderStatusRunningAt(String url) {
    return 'Ejecutándose en $url';
  }

  @override
  String get appProviderStatusStartingLocalServer =>
      'Iniciando servidor local...';

  @override
  String get appProviderStatusStoppingLocalServer =>
      'Deteniendo servidor local...';

  @override
  String get appProviderStoppingLocalServer => 'Deteniendo servidor local...';

  @override
  String get appProviderTailscaleNotSupported =>
      'Tailscale no es compatible con esta plataforma';

  @override
  String appProviderUsingCommandAt(String path) {
    return 'Usando comando OpenCode en $path';
  }

  @override
  String get appShellDownloadingUpdate => 'Descargando actualización';

  @override
  String get appShellInstall => 'Instalar';

  @override
  String get appShellInstallFailed => 'Instalación fallida';

  @override
  String get appShellInstallingUpdate => 'Instalando actualización...';

  @override
  String get appShellRestart => 'Reiniciar';

  @override
  String appShellUpdateAvailableResult(String latestVersion) {
    return 'Actualización disponible: v$latestVersion';
  }

  @override
  String get appShellUpdateInstalledRestartApp =>
      'Actualización instalada. Reinicia la aplicación para aplicar.';

  @override
  String get appShellUpdateInstalledRestartRequired =>
      'Actualización instalada. Se requiere reiniciar para aplicar la nueva versión.';

  @override
  String get attachmentCouldNotDecode =>
      'Los datos del archivo adjunto no pudieron ser decodificados.';

  @override
  String get attachmentCouldNotDownload =>
      'El archivo adjunto no pudo ser descargado.';

  @override
  String get attachmentCouldNotSave =>
      'El archivo adjunto no pudo ser guardado en este dispositivo.';

  @override
  String get attachmentDownloadStarted =>
      'Descarga del archivo adjunto iniciada.';

  @override
  String get attachmentLocalNotFound =>
      'El archivo adjunto local no se encontró en este dispositivo.';

  @override
  String get attachmentNoValidLocation =>
      'El archivo adjunto no proporciona una ubicación válida.';

  @override
  String get attachmentNotAvailableOnPlatform =>
      'Las acciones de archivos adjuntos no están disponibles en esta plataforma.';

  @override
  String get attachmentPathEmpty => 'La ruta del archivo adjunto está vacía.';

  @override
  String get attachmentPayloadEmpty =>
      'La carga útil del archivo adjunto está vacía.';

  @override
  String get attachmentSaveCanceled => 'Guardado cancelado.';

  @override
  String attachmentSavedAndOpened(String path) {
    return 'Archivo adjunto guardado en $path y abierto.';
  }

  @override
  String attachmentSavedPath(String path) {
    return 'Archivo adjunto guardado en $path.';
  }

  @override
  String attachmentSavedTo(String path) {
    return 'Archivo adjunto guardado en $path.';
  }

  @override
  String get attachmentUnableToOpenLink =>
      'No se puede abrir el enlace del archivo adjunto.';

  @override
  String get attachmentUnableToOpenLocal =>
      'No se puede abrir el archivo adjunto local.';

  @override
  String get behaviorAdvancedPermissionRule => 'Regla de permiso avanzada';

  @override
  String get behaviorAutomatic => 'Automático';

  @override
  String get behaviorAutomaticFallback => 'Respaldo automático';

  @override
  String get behaviorCellularDataSaver => 'Ahorro de datos móviles';

  @override
  String get behaviorCellularDataSaverActive =>
      'El ahorro de datos está activo.';

  @override
  String get behaviorChatLevelShare => 'Compartir a nivel de chat';

  @override
  String get behaviorCodeWalkReleaseChecks =>
      'Verificaciones de versión de CodeWalk';

  @override
  String get behaviorControlsOfficialGlobal =>
      'Controla la configuración global oficial de OpenCode';

  @override
  String get behaviorControlsUpstreamOpenCode =>
      'Controla la configuración de OpenCode ascendente';

  @override
  String get behaviorCustomDisplayName => 'Nombre para mostrar personalizado';

  @override
  String behaviorCutsAutomaticMobile(int inSeconds) {
    return 'Reduce el uso automático de datos móviles deteniendo las descargas en segundo plano y limitando las actualizaciones automáticas en primer plano a una ráfaga cada $inSeconds segundos.';
  }

  @override
  String get behaviorDataSaverActive => 'Activo ahora con datos móviles.';

  @override
  String get behaviorDataSaverAggressive => 'Agresivo';

  @override
  String get behaviorDataSaverAggressiveDescription =>
      'Modo de bajo ancho de banda: solo el flujo del espacio de trabajo visible permanece en vivo, las actualizaciones globales se pausan y las actualizaciones automáticas se espacian.';

  @override
  String get behaviorDataSaverCellularOnly =>
      'Solo se aplica cuando la conexión es celular/móvil.';

  @override
  String get behaviorDataSaverOff => 'Desactivado';

  @override
  String get behaviorDataSaverOffHint =>
      'El tiempo real completo y las actualizaciones automáticas están habilitados.';

  @override
  String get behaviorDataSaverStandard => 'Estándar';

  @override
  String get behaviorDataSaverWaiting =>
      'Esperando la próxima ventana de sincronización de datos móviles.';

  @override
  String get behaviorDisabled => 'Desactivado';

  @override
  String get behaviorLightweightTasksLike => 'Tareas ligeras como';

  @override
  String get behaviorManual => 'Manual';

  @override
  String get behaviorNotify => 'Notificar';

  @override
  String get behaviorOfficialOpenCodePermission =>
      'La política oficial de permisos de OpenCode se configura en `opencode.json` con reglas allow/ask/deny por herramienta. CodeWalk conserva las tarjetas oficiales de solicitud de permisos y añade una excepción ADR-023 aprobada: el interruptor de auto-aprobación del composer responde con `Always` y `remember: true` incondicionalmente para crear autorizaciones duraderas con ámbito de sesión, y mantiene el mismo canal de continuidad con ámbito de hilo activo en el worker Android en segundo plano.';

  @override
  String get behaviorOpenCodeBackedDefaults =>
      'Valores predeterminados basados en OpenCode';

  @override
  String get behaviorPermissionHandlingProvenance =>
      'Procedencia del manejo de permisos';

  @override
  String get behaviorPermissionsVariantReasoning =>
      'Los permisos y la paridad de variante/razonamiento se mantienen separados hasta que su interfaz de usuario pueda preservar la configuración avanzada de forma segura.';

  @override
  String get behaviorPrimaryAgentAgent =>
      'Agente principal utilizado cuando no se elige ningún agente explícitamente.';

  @override
  String get behaviorRefreshDefaults => 'Actualizar valores predeterminados';

  @override
  String get behaviorSharedAcrossOpenCode =>
      'Compartido entre clientes de OpenCode a través de la configuración.';

  @override
  String get behaviorTheseValuesWrite =>
      'Estos valores se escriben en `/config` en el servidor activo y coinciden con la configuración global compartida oficial de OpenCode.';

  @override
  String get cannedAddTitle => 'Agregar respuesta rápida';

  @override
  String get cannedAppendAtCursor => 'Añadir al cursor';

  @override
  String get cannedAppendAtCursorSubtitle =>
      'Desactivado = reemplazar texto actual';

  @override
  String get cannedAttachFiles => 'Adjuntar archivos';

  @override
  String get cannedEditTitle => 'Editar respuesta rápida';

  @override
  String get cannedNewQuickReply => 'Nueva respuesta rápida';

  @override
  String get cannedNoSuggestions => 'Sin sugerencias';

  @override
  String get cannedOffMeansReplace =>
      'Desactivado significa reemplazar el texto actual del editor';

  @override
  String get cannedQuickReply => 'Nueva respuesta rápida';

  @override
  String get cannedReplace => 'Reemplazar';

  @override
  String get cannedScopeGlobalSubtitle =>
      'Desactivar para elemento solo del proyecto';

  @override
  String get cannedScopeGlobalUnavailableSubtitle =>
      'Solo proyecto no disponible en este contexto';

  @override
  String get cannedSendAutomaticallySubtitle =>
      'Enviar inmediatamente después de insertar';

  @override
  String get cannedSendImmediatelyInserting =>
      'Enviar inmediatamente después de insertar esta respuesta rápida';

  @override
  String get cannedTextLabel => 'Texto';

  @override
  String get chatActionNext => 'Siguiente';

  @override
  String get chatActiveServerUnhealthy =>
      'El servidor activo no es saludable. Los envíos lo intentarán una vez y fallarán rápido hasta la recuperación.';

  @override
  String get chatActiveServerUnhealthyLabel =>
      'El servidor activo no está saludable';

  @override
  String get chatAddServerToStart =>
      'Agregue un servidor para comenzar a chatear.';

  @override
  String get chatAppBarMoreActions => 'Más acciones';

  @override
  String get chatAppBarPinAction => 'Fijar a la barra de la aplicación';

  @override
  String get chatAppBarPinDescription =>
      'Esta acción permanecerá visible fuera del menú.';

  @override
  String get chatAppBarUnpinAction => 'Desfijar de la barra de la aplicación';

  @override
  String get chatAppBarUnpinDescription =>
      'Esta acción volverá a colocarse dentro del menú.';

  @override
  String chatBadgeConversationError(String title) {
    return '\"$title\" tiene un error.';
  }

  @override
  String chatBadgeConversationNeedsInput(String title) {
    return '\"$title\" necesita su intervención.';
  }

  @override
  String chatBadgeConversationNewReply(String title) {
    return '\"$title\" tiene una nueva respuesta.';
  }

  @override
  String get chatBadgeDataSaverActive =>
      'El ahorro de datos móviles está activo.';

  @override
  String get chatBadgeServerNeedsAttention =>
      'La conexión del servidor necesita atención.';

  @override
  String get chatBadgeSyncing => 'Sincronizando conversaciones...';

  @override
  String get chatBlockResponsePendingDescription =>
      'La respuesta aparecerá como un solo bloque cuando termine este turno.';

  @override
  String get chatBlockResponsePendingTitle => 'Generando respuesta';

  @override
  String get chatCachedConversationsYet =>
      'Aún no hay conversaciones guardadas';

  @override
  String get chatChangedFilesAvailable =>
      'No hay archivos modificados disponibles para esta sesión.';

  @override
  String chatChildrenChatProviderCurrentSessionChildren(int length) {
    return 'Hijos: $length';
  }

  @override
  String get chatChooseAgent => 'Seleccionar agente';

  @override
  String get chatChooseDirectory => 'Elegir directorio';

  @override
  String get chatChooseEffort => 'Elegir esfuerzo';

  @override
  String get chatChooseFolderOpen =>
      'Elija una carpeta para abrir como contexto del proyecto.';

  @override
  String get chatChooseModel => 'Elegir modelo';

  @override
  String get chatClose => 'Cerrar';

  @override
  String chatCloseProject(String project) {
    return 'Cerrar $project';
  }

  @override
  String get chatCollapseGroup => 'Contraer grupo';

  @override
  String get chatCommandDescriptionProject => 'Comando del proyecto';

  @override
  String get chatCommandSourceGeneric => 'comando';

  @override
  String get chatCommandSourceProject => 'proyecto';

  @override
  String get chatCompactContext => 'Compactar Contexto';

  @override
  String get chatComposerHintShell => 'Comando de shell (Esc para salir)';

  @override
  String get chatComposerPlaceholder => 'Escribe tus necesidades...';

  @override
  String get chatConversation => 'Conversación';

  @override
  String get chatConversations => 'Conversaciones';

  @override
  String get chatConversationsPane => 'Conversaciones';

  @override
  String chatCostLabel(double cost) {
    return 'Costo: \$$cost';
  }

  @override
  String get chatCouldNotRefreshSession =>
      'No se pudo actualizar la conversación';

  @override
  String get chatCurrent => 'Usar actual';

  @override
  String chatDescriptionChildren(int count) {
    return 'Hijos: $count';
  }

  @override
  String get chatDescriptionCloseApp =>
      'Cerrar la aplicación usando el comportamiento de cierre de la plataforma';

  @override
  String get chatDescriptionCycleModels => 'Ciclar modelos recientes';

  @override
  String get chatDescriptionCycleVariant => 'Ciclar variante de modelo';

  @override
  String get chatDescriptionDiffFilesZero => 'Archivos diff: 0';

  @override
  String get chatDescriptionFocusInput => 'Enfocar entrada de mensaje';

  @override
  String get chatDescriptionFocusOrCloseDrawer =>
      'Enfocar entrada (o cerrar panel cuando está abierto)';

  @override
  String get chatDescriptionForceExit => 'Forzar salida de la aplicación';

  @override
  String get chatDescriptionNewConversation => 'Nueva conversación';

  @override
  String get chatDescriptionNextAgent => 'Siguiente agente';

  @override
  String get chatDescriptionOpenProjects =>
      'Use este botón para abrir sus proyectos y conversaciones.';

  @override
  String get chatDescriptionOpenSettings => 'Abrir ajustes';

  @override
  String get chatDescriptionPreviousAgent => 'Agente anterior';

  @override
  String get chatDescriptionProjectCommand => 'Comando de proyecto';

  @override
  String get chatDescriptionQuickOpen => 'Apertura rápida de archivos';

  @override
  String get chatDescriptionRefreshData => 'Refrescar datos del chat';

  @override
  String get chatDescriptionStopResponse =>
      'Detener respuesta activa (mientras responde)';

  @override
  String get chatDescriptionSwitchProject =>
      'Use este botón para cambiar carpetas de proyecto y contexto.';

  @override
  String get chatDescriptionVoiceInput => 'Iniciar o detener entrada de voz';

  @override
  String get chatDiffFiles => 'Archivos de diff: 0';

  @override
  String get chatDisplay => 'Visualización';

  @override
  String get chatDisplayToggles => 'Opciones de visualización';

  @override
  String get chatDoubleESCStop => 'Doble ESC para detener';

  @override
  String get chatEffortLockedSubConversation =>
      'Esfuerzo bloqueado en subconversación';

  @override
  String get chatExpandGroup => 'Expandir grupo';

  @override
  String get chatExportCanceled => 'Exportación de sesión cancelada';

  @override
  String get chatFailedToLoadDirectories => 'Error al cargar directorios';

  @override
  String get chatFailedToLoadFile => 'Error al cargar el archivo';

  @override
  String get chatFailedToRefreshProviders =>
      'Error al actualizar proveedores y modelos';

  @override
  String get chatFailedToRefreshSubConversations =>
      'Error al actualizar subconversaciones. Intenta de nuevo.';

  @override
  String get chatFailedToStopResponse => 'Error al detener la respuesta actual';

  @override
  String get chatFileExplorerContents => 'Contenidos';

  @override
  String get chatFileExplorerNames => 'Nombres';

  @override
  String get chatFilterActive => 'Activas';

  @override
  String get chatFilterAll => 'Todas';

  @override
  String get chatFilterArchived => 'Archivadas';

  @override
  String get chatFilterDirectories => 'Filtrar directorios';

  @override
  String get chatFilterSessions => 'Filtrar sesiones';

  @override
  String get chatForkFailed => 'Error al bifurcar conversación';

  @override
  String get chatForked => 'Conversación bifurcada';

  @override
  String get chatGoToFirst => 'Ir al primer mensaje';

  @override
  String get chatGoToLatest => 'Ir al último mensaje';

  @override
  String chatGroupMessageCountMessages(
    String compactionLabel,
    String messageCount,
  ) {
    return '$messageCount mensajes ocultos antes de la compactación $compactionLabel';
  }

  @override
  String get chatHelloAssistant => '¡Hola! Soy tu asistente de IA';

  @override
  String get chatHelp => '¿Cómo puedo ayudarte?';

  @override
  String get chatHelpMessage =>
      'Usa @ para menciones, ! para shell, / para comandos';

  @override
  String get chatHideConversationsSidebar => 'Ocultar barra de Conversaciones';

  @override
  String get chatHideUtilitySidebar => 'Ocultar barra de Utilidades';

  @override
  String get chatHistoryCollapsed => 'El historial anterior está colapsado';

  @override
  String get chatHistoryHideEarlier => 'Ocultar mensajes anteriores';

  @override
  String chatHistoryMessagesHidden(int count, String label) {
    return '$count mensajes ocultos antes de la compactación $label';
  }

  @override
  String get chatHistoryShowEarlier => 'Mostrar mensajes anteriores';

  @override
  String get chatKeepWorking => 'Seguir trabajando';

  @override
  String get chatLargeContentSkipped =>
      'Se omitió contenido grande o mal formado por estabilidad.';

  @override
  String get chatLatestToolActivity =>
      'La actividad de herramienta más reciente permanece dentro de este panel delimitado para mantener estable la vista del chat.';

  @override
  String get chatLoadMore => 'Cargar más';

  @override
  String get chatLoadingProjectContext => 'Cargando contexto del proyecto...';

  @override
  String get chatMainConversationUnavailable =>
      'La conversación principal no está disponible.';

  @override
  String get chatParentConversationUnavailable =>
      'La conversación superior aún no está disponible.';

  @override
  String get chatMentionAgentSubtitle => 'agente';

  @override
  String get chatMentionFileSubtitle => 'archivo';

  @override
  String get chatMentionSymbolSubtitle => 'símbolo';

  @override
  String get chatMessageAttachedFile => 'Archivo adjunto';

  @override
  String get chatMessageDetails => 'Detalles';

  @override
  String get chatMessageHide => 'Ocultar';

  @override
  String get chatMessageLess => 'Menos';

  @override
  String get chatMessageMessagePartUnavailable =>
      'Parte del mensaje no disponible';

  @override
  String get chatMessageMetadataAvailable => 'No hay metadatos disponibles';

  @override
  String chatMessageModelMessageModelId(String modelId) {
    return 'Modelo: $modelId';
  }

  @override
  String get chatMessageMore => 'Más';

  @override
  String get chatMessageOpenFile => 'Abrir archivo';

  @override
  String chatMessageProviderMessageProviderId(String providerId) {
    return 'Proveedor: $providerId';
  }

  @override
  String get chatMessageRewindEdit => 'Rebobinar y editar desde aquí';

  @override
  String get chatMessageRunningTask => 'Ejecutando tarea';

  @override
  String get chatMessageSaveFile => 'Guardar archivo';

  @override
  String get chatMessageShow => 'Mostrar';

  @override
  String get chatMessageShowLess => 'Mostrar menos';

  @override
  String get chatMessageShowLessCompact => 'Menos';

  @override
  String get chatMessageShowMore => 'Mostrar más';

  @override
  String get chatMessageShowMoreCompact => 'Más';

  @override
  String get chatMessageThinking => 'Pensando';

  @override
  String get chatMessageThinkingProcess => 'Proceso de pensamiento';

  @override
  String get chatMessageToolCall => '1 llamada a herramienta';

  @override
  String chatMessageToolCalls(int count) {
    return '$count llamadas a herramientas';
  }

  @override
  String get chatMessageToolCommand => 'Comando';

  @override
  String get chatMessageToolCommandTruncated =>
      'Vista previa del comando truncada.';

  @override
  String get chatMessageToolDiffOmitted =>
      'Vista previa de diff omitida por ser demasiado grande.';

  @override
  String get chatMessageToolInput => 'Entrada';

  @override
  String get chatMessageToolInputTruncated =>
      'Vista previa de entrada truncada.';

  @override
  String get chatMessageToolOutputTruncated =>
      'Vista previa truncada por estabilidad.';

  @override
  String chatMessageToolQueuedCount(int count) {
    return '$count en cola';
  }

  @override
  String chatMessageToolRunningCount(int count) {
    return '$count ejecutándose';
  }

  @override
  String get chatMessageToolStatusInProgress => 'En progreso';

  @override
  String get chatMessageToolStatusNeedsAttention => 'Necesita atención';

  @override
  String get chatMessageToolStatusQueued => 'En cola';

  @override
  String get chatMessageYou => 'Tú';

  @override
  String get chatModelLockedSubConversation =>
      'Modelo bloqueado en subconversación';

  @override
  String get chatNewChat => 'Nueva Conversación';

  @override
  String get chatNewChatTourDescription =>
      'Inicie una nueva conversación aquí.';

  @override
  String get chatNewChatTourTitle => 'Nueva conversación';

  @override
  String get chatNoConversationsInProject =>
      'No hay conversaciones en este proyecto.';

  @override
  String get chatNoServerYet => 'Aún no hay servidor configurado';

  @override
  String get chatNoSessionSelected => 'Selecciona o crea una conversación';

  @override
  String get chatNoSubConversationFound => 'No se encontró subconversación.';

  @override
  String get chatOpenFiles => 'Abrir Archivos';

  @override
  String get chatOpenProject => 'Abrir proyecto';

  @override
  String get chatOpenProjectFolder => 'Abrir carpeta del proyecto...';

  @override
  String get chatOpenProjectToLoad =>
      'Abra un proyecto para cargar conversaciones.';

  @override
  String get chatOpenSidebar => 'Abrir barra lateral';

  @override
  String get chatPageStatusAutomaticCompactionExplanation =>
      'La compactación automática ocurre a medida que crece el uso del contexto.';

  @override
  String get chatPageStatusCompactNow => 'Compactar ahora';

  @override
  String get chatPageStatusCompacting => 'Compactando...';

  @override
  String get chatPageStatusCompactingContextNow =>
      'Compactando contexto ahora...';

  @override
  String get chatPageStatusContextCompacted => 'Contexto compactado';

  @override
  String get chatPageStatusContextUsage => 'Uso del contexto';

  @override
  String get chatPageStatusCost => 'Costo';

  @override
  String get chatPageStatusFailedToCompactContext =>
      'Error al compactar contexto';

  @override
  String get chatPageStatusLimit => 'Límite';

  @override
  String get chatPageStatusManageServers => 'Gestionar servidores';

  @override
  String get chatPageStatusSaver => 'Ahorro';

  @override
  String get chatPageStatusServer => 'Servidor';

  @override
  String get chatPageStatusSwitchServer => 'Cambiar servidor';

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
      'Aprobación automática de permisos desactivada';

  @override
  String get chatPermissionAutoApproveOn =>
      'Aprobación automática de permisos activada';

  @override
  String get chatProjectContext => 'Contexto del Proyecto';

  @override
  String get chatProjectContext2 => 'Contexto del proyecto';

  @override
  String get chatRealtimeGlobalEvent => 'evento global';

  @override
  String chatRealtimeGlobalEventReason(String reason) {
    return 'evento global ($reason)';
  }

  @override
  String get chatRealtimeGlobalEventStale =>
      'evento global (generación obsoleta)';

  @override
  String chatRealtimeMessageStreamReason(String reason) {
    return 'flujo de mensajes ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEvent => 'evento en tiempo real';

  @override
  String chatRealtimeRealtimeEventReason(String reason) {
    return 'evento en tiempo real ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEventStale =>
      'evento en tiempo real (generación obsoleta)';

  @override
  String get chatRealtimeReconnectingServerTry =>
      'Reconectando al servidor. Intente de nuevo en un momento.';

  @override
  String get chatReasoning => 'Razonando...';

  @override
  String get chatRecentSessions => 'Sesiones recientes';

  @override
  String get chatRecentSessionsToggle => 'Sesiones recientes';

  @override
  String get chatRedoLastTurn => 'Rehacer último turno deshecho';

  @override
  String get chatRedoNothing => 'Nada que rehacer en esta sesión';

  @override
  String get chatRefresh => 'Actualizar';

  @override
  String get chatRefreshConversation =>
      'No se pudo actualizar esta conversación';

  @override
  String get chatRefreshProjects => 'Actualizar proyectos';

  @override
  String get chatRefreshSessionDetails => 'Actualizar detalles de sesión';

  @override
  String chatRemoveDisplayNameHistory(String displayName) {
    return 'Eliminar $displayName del historial';
  }

  @override
  String get chatRetry => 'Reintentar';

  @override
  String get chatRetry2 => 'Reintentar';

  @override
  String get chatRetryRefresh => 'Reintentar actualización';

  @override
  String get chatRetryingModelRequest => 'Reintentando solicitud de modelo...';

  @override
  String get chatReturnToMainConversation =>
      'Volver a la conversación principal';

  @override
  String get chatReturnToParentConversation =>
      'Volver a la conversación superior';

  @override
  String get chatReviewChanges => 'Revisar cambios';

  @override
  String get chatSearchConversations => 'Buscar conversaciones';

  @override
  String get chatSearchNextResult => 'Siguiente resultado';

  @override
  String get chatSearchNoResults => 'Sin resultados';

  @override
  String get chatSearchPreviousResult => 'Resultado anterior';

  @override
  String chatSearchResultCount(int current, int total) {
    return 'Mensaje $current de $total';
  }

  @override
  String get chatSearchTimeline => 'Buscar en la cronología';

  @override
  String get chatSelectDirectory => 'Seleccionar directorio';

  @override
  String get chatSelectOrCreate =>
      'Seleccione o cree una conversación para comenzar a chatear';

  @override
  String get chatSelectProjectBelow => 'Seleccione un proyecto a continuación.';

  @override
  String get chatServerSelectedModel => 'Modelo seleccionado por el servidor';

  @override
  String get chatSessionActions => 'Acciones de sesión';

  @override
  String chatSessionChatSessionSession(String title) {
    return 'Sesión de chat: $title';
  }

  @override
  String chatSessionConversationNextAction(String nextAction) {
    return 'Conversación $nextAction';
  }

  @override
  String get chatSessionConversations => 'Sin conversaciones';

  @override
  String get chatSessionCreateConversationStart =>
      'Cree una nueva conversación para comenzar a chatear';

  @override
  String get chatSessionTabsToggle => 'Pestañas de sesión';

  @override
  String chatSessionsLength(int length) {
    return '$length';
  }

  @override
  String get chatSetUpServer => 'Configurar servidor';

  @override
  String get chatSettings => 'Configuraciones';

  @override
  String get chatShortcutsCloseApp =>
      'Cerrar aplicación usando comportamiento de plataforma';

  @override
  String get chatShortcutsCycleModels => 'Ciclar modelos recientes';

  @override
  String get chatShortcutsCycleVariant => 'Ciclar variante de modelo';

  @override
  String get chatShortcutsFocusInput => 'Enfocar entrada de mensaje';

  @override
  String get chatShortcutsFocusInputCloseDrawer =>
      'Enfocar entrada (o cerrar cajón si está abierto)';

  @override
  String get chatShortcutsForceExit => 'Forzar salida de la aplicación';

  @override
  String get chatShortcutsNewConversation => 'Nueva conversación';

  @override
  String get chatShortcutsNextAgent => 'Siguiente agente';

  @override
  String get chatShortcutsOpenSettings => 'Abrir ajustes';

  @override
  String get chatShortcutsPreviousAgent => 'Agente anterior';

  @override
  String get chatShortcutsQuickOpen => 'Abrir archivos rápidamente';

  @override
  String get chatShortcutsRefreshChat => 'Actualizar datos de chat';

  @override
  String get chatShortcutsStartStopVoice => 'Iniciar o detener entrada de voz';

  @override
  String get chatShortcutsStopResponse =>
      'Detener respuesta activa (mientras responde)';

  @override
  String get chatSidebarAccess => 'Acceso a la barra lateral';

  @override
  String get chatSortMostRecent => 'Más Recientes';

  @override
  String get chatSortOldest => 'Más Antiguas';

  @override
  String get chatSortRecent => 'Recientes';

  @override
  String get chatSortSessions => 'Ordenar sesiones';

  @override
  String get chatSortTitle => 'Título';

  @override
  String get chatStartVoiceInput => 'Iniciar entrada de voz';

  @override
  String get chatStartingVoiceInput => 'Iniciando entrada de voz';

  @override
  String get chatStatusBusy => 'Estado: Ocupado';

  @override
  String get chatStatusPatching => 'Parcheando';

  @override
  String chatStatusPatchingMultipleFiles(int count) {
    return 'Parcheando $count archivos';
  }

  @override
  String get chatStatusPatchingOneFile => 'Parcheando 1 archivo';

  @override
  String get chatStatusRetry => 'Estado: Reintentar';

  @override
  String chatStatusRetryCount(int count) {
    return 'Estado: Reintento #$count';
  }

  @override
  String get chatStatusSubsession => 'Subsesión';

  @override
  String get chatStatusThinking => 'Pensando...';

  @override
  String get chatStopVoiceInput => 'Detener entrada de voz';

  @override
  String chatSyncLabel(String label) {
    return 'Sincronización: $label';
  }

  @override
  String get chatTasks => 'Tareas';

  @override
  String get chatTasksAvailableSession =>
      'No hay tareas disponibles para esta sesión.';

  @override
  String get chatTipAcceptanceCriteria =>
      'Consejo: Añade criterios de aceptación en cambios grandes';

  @override
  String get chatTipAskForPlan =>
      'Consejo: Pide un plan primero en tareas grandes';

  @override
  String get chatTipBeSpecific =>
      'Consejo: Sé específico — los mensajes cortos reciben respuestas más rápidas';

  @override
  String get chatTipBreakTasks =>
      'Consejo: Divide tareas grandes en mensajes más pequeños';

  @override
  String get chatTipCompareOptions =>
      'Consejo: Pide alternativas cuando los tradeoffs no estén claros';

  @override
  String get chatTipContextKnob =>
      'Consejo: Toca el botón de contexto para ver detalles de uso';

  @override
  String get chatTipDefineVerification =>
      'Consejo: Di qué pruebas o comprobaciones deben pasar';

  @override
  String get chatTipLongPressSend =>
      'Consejo: Mantén presionado Enviar para insertar una nueva línea';

  @override
  String get chatTipMentionFiles =>
      'Consejo: Usa @ para mencionar archivos en tu mensaje';

  @override
  String get chatTipNameRelevantFiles =>
      'Consejo: Nombra archivos, pantallas o comandos relevantes';

  @override
  String get chatTipProvideContext =>
      'Consejo: Proporciona contexto — pega mensajes de error y registros';

  @override
  String get chatTipRenameConversation =>
      'Consejo: Toca el título para renombrar una conversación';

  @override
  String get chatTipRequestDocs =>
      'Consejo: Pide actualizar docs cuando cambie el comportamiento';

  @override
  String get chatTipShareAttempts =>
      'Consejo: Comparte lo que intentaste y el error exacto';

  @override
  String get chatTipShellCommands =>
      'Consejo: Usa ! al principio para ejecutar comandos de shell';

  @override
  String get chatTipSlashCommands =>
      'Consejo: Usa / para acceder a comandos de barra';

  @override
  String get chatTipStartWithGoal => 'Consejo: Empieza por el objetivo final';

  @override
  String get chatTipStateConstraints =>
      'Consejo: Indica restricciones que el agente debe preservar';

  @override
  String get chatTipStepByStep =>
      'Consejo: Pide paso a paso al depurar problemas complejos';

  @override
  String get chatTipUseFocusedAgents =>
      'Consejo: Elige un agente enfocado para plan, revisión o build';

  @override
  String get chatToggleSidebars => 'Alternar barras laterales';

  @override
  String chatTokensLabel(int total) {
    return 'Tokens: $total';
  }

  @override
  String get chatTourProjectsConversations =>
      'Usa este botón para abrir tus proyectos y conversaciones.';

  @override
  String get chatTourSidebarProjectTools =>
      'Usa este menú para mostrar la barra lateral de conversaciones y herramientas de proyecto.';

  @override
  String get chatTourSwitchFolders =>
      'Usa este botón para cambiar carpetas de proyecto y contexto.';

  @override
  String get chatUndoLastTurn => 'Deshacer último turno';

  @override
  String get chatUndoNothing => 'Nada que deshacer en esta sesión';

  @override
  String get chatUseCurrent => 'Usar actual';

  @override
  String get chatWaitingForNetworkConnection => 'Esperando conexión de red...';

  @override
  String get chatWelcomeMessage => '¡Hola! Soy tu asistente de IA.';

  @override
  String get chatWelcomeSubmessage => '¿Cómo puedo ayudarte hoy?';

  @override
  String get chatWorkBoundedPanelExplanation =>
      'La actividad más reciente de la herramienta permanece dentro de este panel limitado para mantener estable la vista del chat.';

  @override
  String get chatWorkExpand => 'Expandir';

  @override
  String get chatWorkHide => 'Ocultar';

  @override
  String get chatWorkMessageOne => '1 mensaje de trabajo';

  @override
  String chatWorkMessagesMultiple(int count) {
    return '$count mensajes de trabajo';
  }

  @override
  String get chatWorkShow => 'Mostrar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonCopiedToClipboard => 'Copiado al portapapeles';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonFile => 'Archivo';

  @override
  String get commonReset => 'Restablecer';

  @override
  String get commonSave => 'Guardar';

  @override
  String get compactionAutomatic => 'automático';

  @override
  String get compactionManual => 'manual';

  @override
  String get composerAddAttachment => 'Agregar adjunto';

  @override
  String get composerAttachFiles => 'Adjuntar archivos';

  @override
  String get composerCannedAppendAtCursor => 'Agregar en el cursor';

  @override
  String get composerCannedLabel => 'Etiqueta (opcional)';

  @override
  String get composerCannedNoReplies => 'Aún no hay respuestas rápidas.';

  @override
  String get composerCannedReplace => 'Reemplazar';

  @override
  String get composerCannedSave => 'Guardar';

  @override
  String get composerCannedScopeGlobal => 'Global';

  @override
  String get composerCannedScopeProject => 'Solo del proyecto';

  @override
  String get composerCannedSendAutomatically => 'Enviar automáticamente';

  @override
  String get composerCannedText => 'Texto';

  @override
  String get composerChatInput => 'Entrada de chat';

  @override
  String get composerDeleteAction => 'Eliminar';

  @override
  String get composerDropHint => 'Suelta imágenes o PDF para adjuntar';

  @override
  String get composerPastedImageName => 'Imagen pegada';

  @override
  String get composerEdit => 'Editar';

  @override
  String get composerExtras => 'Extras';

  @override
  String get composerExtrasHide => 'Ocultar extras';

  @override
  String get composerNewQuickReply => 'Nueva respuesta rápida';

  @override
  String get composerSelectImages => 'Seleccionar Imágenes';

  @override
  String get composerSelectPdf => 'Seleccionar PDF';

  @override
  String get composerSend => 'Enviar';

  @override
  String get composerShellMode => 'Modo shell';

  @override
  String get desktopWindowClose => 'Cerrar';

  @override
  String get desktopWindowMaximize => 'Maximizar';

  @override
  String get desktopWindowMinimize => 'Minimizar';

  @override
  String get desktopWindowRestore => 'Restaurar';

  @override
  String get dialogDownload => 'Descargar';

  @override
  String get dialogLanguage => 'Idioma';

  @override
  String get dialogMoonshineModelSize => 'Tamaño del modelo';

  @override
  String get dialogMoonshineVoiceSetup => 'Configuración de Voz Moonshine';

  @override
  String get dialogParakeetModel => 'Modelo Parakeet';

  @override
  String get dialogParakeetVoiceSetup => 'Configuración de Voz Parakeet';

  @override
  String get dialogSenseVoiceModel => 'Modelo SenseVoice';

  @override
  String get dialogSenseVoiceSetup => 'Configuración SenseVoice';

  @override
  String get dialogVoiceInputSetup => 'Configuración de Entrada de Voz';

  @override
  String get errorAnErrorOccurred => 'Ocurrió un error';

  @override
  String get errorAuthRequired => 'Autenticación requerida';

  @override
  String get errorAuthRequiredDesc =>
      'La autenticación falló. Vuelva a conectar el proveedor e inténtelo de nuevo.';

  @override
  String get errorConnectionFailed => 'Conexión fallida';

  @override
  String get errorConnectionFailedDesc =>
      'No se puede contactar con el servidor. Compruebe la conexión y el estado del servidor.';

  @override
  String get errorFormatAuthenticationFailedReconnect =>
      'Autenticación fallida. Vuelva a conectar el proveedor e inténtelo de nuevo.';

  @override
  String get errorFormatProviderTemporarilyUnavailable =>
      'Proveedor temporalmente no disponible. Inténtelo de nuevo en breve.';

  @override
  String get errorFormatQuotaExceededCheck =>
      'Cupo excedido. Verifique el plan de su proveedor o la facturación.';

  @override
  String get errorFormatRateLimitExceeded =>
      'Límite de velocidad excedido. Espere un momento e inténtelo de nuevo.';

  @override
  String get errorFormatServerErrorPlease =>
      'Error del servidor. Por favor, inténtelo de nuevo.';

  @override
  String get errorFormatServiceTemporarilyUnavailable =>
      'Servicio temporalmente no disponible. El servidor podría estar iniciándose; inténtelo de nuevo en breve.';

  @override
  String get errorFormatUnableReachServer =>
      'No se puede establecer conexión con el servidor. Compruebe la conexión y el estado del servidor.';

  @override
  String get errorProviderUnavailable => 'Proveedor no disponible';

  @override
  String get errorProviderUnavailableDesc =>
      'El proveedor no está disponible temporalmente. Inténtelo de nuevo en breve.';

  @override
  String get errorQuotaExceeded => 'Cuota excedida';

  @override
  String get errorQuotaExceededDesc =>
      'Cuota excedida. Compruebe su plan de proveedor o facturación.';

  @override
  String get errorRateLimitExceeded => 'Límite de velocidad excedido';

  @override
  String get errorRateLimitExceededDesc =>
      'Límite de velocidad excedido. Espere un momento e inténtelo de nuevo.';

  @override
  String get errorServerError => 'Error del servidor';

  @override
  String get errorServerErrorDesc =>
      'Error del servidor. Por favor, inténtelo de nuevo.';

  @override
  String get errorServiceUnavailable => 'Servicio no disponible';

  @override
  String get errorServiceUnavailableDesc =>
      'Servicio temporalmente no disponible. El servidor puede estar iniciándose; por favor, inténtelo de nuevo en breve.';

  @override
  String get fileActionAttachmentDataDecoded =>
      'Los datos del adjunto no pudieron decodificarse.';

  @override
  String get fileActionAttachmentPathEmpty => 'La ruta del adjunto está vacía.';

  @override
  String get fileActionAttachmentPayloadEmpty =>
      'La carga útil del adjunto está vacía.';

  @override
  String get fileActionAttachmentProvideValid =>
      'El adjunto no proporciona una ubicación válida.';

  @override
  String get fileActionAttachmentSavedDevice =>
      'El adjunto no pudo guardarse en este dispositivo.';

  @override
  String fileActionAttachmentSavedOutputFile(String path) {
    return 'Adjunto guardado en $path y abierto.';
  }

  @override
  String fileActionAttachmentSavedOutputFile2(String path) {
    return 'Adjunto guardado en $path.';
  }

  @override
  String fileActionAttachmentSavedSavedPath(String savedPath) {
    return 'Adjunto guardado en $savedPath.';
  }

  @override
  String get fileActionLocalAttachmentFound =>
      'El adjunto local no se encontró en este dispositivo.';

  @override
  String get fileActionSaveCanceled => 'Guardado cancelado.';

  @override
  String get fileActionUnableOpenLocal => 'No se pudo abrir el adjunto local.';

  @override
  String get filesAddChat => 'Añadir al chat';

  @override
  String get filesAutosave => 'Guardado automático';

  @override
  String get filesAutosaveOn => 'Guardado automático activado';

  @override
  String get filesAutosaveOff => 'Guardado automático desactivado';

  @override
  String get filesRedo => 'Rehacer';

  @override
  String get filesUndo => 'Deshacer';

  @override
  String get filesBinaryFilePreview =>
      'La vista previa de archivos binarios no está disponible.';

  @override
  String get filesClear => 'Limpiar';

  @override
  String get filesContents => 'Contenido';

  @override
  String get filesDuplicate => 'Duplicar';

  @override
  String get filesDuplicated => 'Archivo duplicado';

  @override
  String get filesFileEmpty => 'El archivo está vacío.';

  @override
  String get filesAlreadyExists =>
      'Ya existe un archivo o carpeta con ese nombre.';

  @override
  String get filesCopyPath => 'Copiar ruta';

  @override
  String get filesCreateFileTitle => 'Crear archivo';

  @override
  String get filesCreateFolderTitle => 'Crear carpeta';

  @override
  String get filesDelete => 'Eliminar';

  @override
  String filesDeleteConfirm(String name) {
    return '¿Eliminar $name? Esta acción no se puede deshacer. Las carpetas se eliminarán con su contenido.';
  }

  @override
  String filesDeleteTitle(String name) {
    return 'Eliminar $name';
  }

  @override
  String get filesFilesFound => 'No se encontraron archivos';

  @override
  String get filesFileCreated => 'Archivo creado.';

  @override
  String get filesFolderCreated => 'Carpeta creada.';

  @override
  String get filesHideSidebar => 'Ocultar barra de Archivos';

  @override
  String get filesInvalidName =>
      'Introduzca un nombre válido sin separadores de ruta.';

  @override
  String get filesNameHint => 'Nombre';

  @override
  String get filesNew => 'Nuevo';

  @override
  String get filesNewFile => 'Nuevo archivo';

  @override
  String get filesNewFolder => 'Nueva carpeta';

  @override
  String get filesNames => 'Nombres';

  @override
  String filesOpenFilesFileState(int length) {
    return 'Archivos abiertos ($length)';
  }

  @override
  String get filesQuickOpen => 'Apertura Rápida';

  @override
  String get filesQuickOpenFile => 'Apertura rápida de archivo';

  @override
  String get filesOperationFailed => 'La operación de archivo falló.';

  @override
  String get filesOperationUnavailable =>
      'Las operaciones de archivo no están disponibles para este servidor.';

  @override
  String get filesOutsideRoot => 'La ruta está fuera de la raíz del proyecto.';

  @override
  String get filesPathCopied => 'Ruta copiada.';

  @override
  String get filesPathMissing => 'La ruta no existe.';

  @override
  String get filesPermissionDenied => 'Permiso denegado.';

  @override
  String get filesRefresh => 'Actualizar archivos';

  @override
  String get filesRename => 'Renombrar';

  @override
  String filesRenameTitle(String name) {
    return 'Renombrar $name';
  }

  @override
  String get filesRenamed => 'Renombrado.';

  @override
  String get filesRootDeleteBlocked =>
      'La raíz del proyecto no se puede eliminar.';

  @override
  String get filesSearchHint => 'Buscar archivos por nombre o ruta';

  @override
  String get filesDeleted => 'Eliminado.';

  @override
  String get filesTitle => 'Archivos';

  @override
  String get forwardAction => 'Reenviar';

  @override
  String get forwardAllFailed => 'No se pudo reenviar a ninguna sesión';

  @override
  String get forwardCancel => 'Cancelar';

  @override
  String get forwardDialogSubtitle => 'Seleccione una o más conversaciones';

  @override
  String get forwardDialogTitle => 'Reenviar a…';

  @override
  String get forwardLoading => 'Cargando sesiones…';

  @override
  String get forwardNoOpenProjects => 'No hay proyectos abiertos con sesiones';

  @override
  String get forwardNoProviderModel =>
      'Seleccione un proveedor y un modelo antes de reenviar';

  @override
  String get forwardNoSessions => 'No hay sesiones recientes';

  @override
  String forwardPartial(int success, int total) {
    return 'Reenviado a $success de $total';
  }

  @override
  String forwardProvenanceLabel(String origin) {
    return 'Reenviado desde: $origin';
  }

  @override
  String get forwardRetry => 'Reintentar';

  @override
  String get forwardSearchHint => 'Buscar';

  @override
  String forwardSelectedCount(int count) {
    return '$count seleccionadas';
  }

  @override
  String get forwardSend => 'Reenviar';

  @override
  String get forwardServerOffline => 'Servidor sin conexión';

  @override
  String get forwardShortcutHint => 'Ctrl+Shift+F';

  @override
  String forwardSuccess(int count) {
    return 'Reenviado a $count sesiones';
  }

  @override
  String get forwardUndo => 'Deshacer';

  @override
  String get forwardUndoFailed => 'No se pudo deshacer el reenvío';

  @override
  String get logsAppLogs => 'Registros de la App';

  @override
  String get logsClear => 'Limpiar registros';

  @override
  String get logsCloseSearch => 'Cerrar búsqueda';

  @override
  String get logsCopyFiltered => 'Copiar registros filtrados';

  @override
  String get logsEnableLogging => 'Activar registros de la app';

  @override
  String get logsEnableLoggingAction => 'Activar registros';

  @override
  String get logsEnableLoggingDescription =>
      'Recopila registros de diagnóstico en memoria. Manténgalo desactivado salvo al solucionar problemas.';

  @override
  String get logsEntryContext => 'Contexto';

  @override
  String get logsEntryTags => 'Etiquetas';

  @override
  String get logsFilterAll => 'Todos';

  @override
  String get logsFilterByTag => 'Etiqueta';

  @override
  String get logsLevel => 'Nivel';

  @override
  String get logsLoggingDisabledDescription =>
      'CodeWalk no está recopilando registros detallados de la app. Active los registros solo cuando necesite diagnóstico.';

  @override
  String get logsLoggingDisabledTitle => 'Registros desactivados';

  @override
  String get logsMeasurePerformance => 'Medir rendimiento';

  @override
  String get logsMeasurePerformanceDescription =>
      'Captura tiempos de operaciones costosas de la app. Déjelo apagado salvo al diagnosticar lentitud.';

  @override
  String get logsNoLogsYet => 'No hay registros capturados aún.';

  @override
  String get logsNoMatchingLogs =>
      'Ningún registro coincide con los filtros actuales.';

  @override
  String get logsNoPerformanceData =>
      'Ningún registro de rendimiento coincide con los filtros actuales.';

  @override
  String get logsNoTaskData =>
      'Ninguna tarea coincide con los filtros actuales.';

  @override
  String logsPerformanceDuration(int elapsedMs) {
    return '$elapsedMs ms';
  }

  @override
  String get logsPerformanceFilter => 'Rendimiento';

  @override
  String logsPerformanceTileTitle(
    int elapsedMs,
    String operation,
    String status,
  ) {
    return 'RENDIMIENTO $operation | $elapsedMs ms | $status';
  }

  @override
  String get logsSearch => 'Buscar registros';

  @override
  String logsShowingOrderedLength(int length, int length2) {
    return 'Mostrando $length de $length2 entradas';
  }

  @override
  String get logsSlowestPerformance => 'Registros de rendimiento más lentos';

  @override
  String get logsSlowestTasks => 'Tareas más lentas';

  @override
  String get logsTagCustomHint =>
      'Nombre de etiqueta (ej.: task:select_session)';

  @override
  String get logsTagCustomAction => 'Personalizada...';

  @override
  String logsTaskDuration(int elapsedMs, String operation) {
    return '$operation — $elapsedMs ms';
  }

  @override
  String get logsTaskStatusCanceled => 'cancelada';

  @override
  String get logsTaskStatusError => 'error';

  @override
  String get logsTaskStatusOk => 'ok';

  @override
  String get logsTimeRange => 'Rango de tiempo';

  @override
  String get mathExpressionLabel => 'Matemáticas';

  @override
  String get mermaidCopySourceTooltip => 'Copiar código fuente';

  @override
  String get mermaidDiagramLabel => 'Diagrama de Mermaid';

  @override
  String get modelAuto => 'Automático';

  @override
  String get modelChooseAgent => 'Elegir agente';

  @override
  String get modelFavorites => 'Favoritos';

  @override
  String get modelFree => 'Gratis';

  @override
  String get modelLabelBaseEnglish => 'Base (Inglés)';

  @override
  String get modelLabelParakeet => 'Parakeet V3 (25 idiomas europeos)';

  @override
  String get modelLabelSenseVoice => 'SenseVoice (zh/en/ja/ko/yue)';

  @override
  String get modelLabelTinyEnglish => 'Tiny (Inglés)';

  @override
  String get modelLoadingModels => 'Cargando modelos';

  @override
  String get modelModelsFound => 'No se encontraron modelos';

  @override
  String get modelRetryModels => 'Reintentar modelos';

  @override
  String get modelSearchHint => 'Buscar modelo o proveedor';

  @override
  String get msgBatterySettingsFailed =>
      'No se pudo abrir la configuración de optimización de batería de Android.';

  @override
  String get msgBatterySettingsOpened =>
      'Configuración de batería de Android abierta. Permita batería sin restricciones para CodeWalk.';

  @override
  String get msgClearUsernameNeedsConfigEdit =>
      'Limpiar el nombre de usuario de la conversación de OpenCode aún requiere editar la configuración fuera de la app.';

  @override
  String get msgCommandCopied => 'Comando copiado';

  @override
  String get msgCopiedToClipboard => 'Copiado al portapapeles';

  @override
  String get msgEnterUsernameToSave =>
      'Ingrese un nombre de usuario para guardar un nombre de conversación personalizado de OpenCode.';

  @override
  String get msgFailedToSendMessage =>
      'Error al enviar mensaje. Borrador conservado para reintentar.';

  @override
  String get msgFailedToStartVoiceInput => 'Error al iniciar entrada de voz';

  @override
  String msgFilePathNotFound(String path) {
    return 'Archivo no encontrado: $path';
  }

  @override
  String get msgFilteredLogsCopied =>
      'Registros filtrados copiados al portapapeles';

  @override
  String get msgInfoAgent => 'Agente';

  @override
  String get msgInfoCompaction => 'Compactación';

  @override
  String msgInfoCost(String cost) {
    return 'Costo: \$$cost';
  }

  @override
  String get msgInfoMessageInfo => 'Información del Mensaje';

  @override
  String msgInfoModel(String modelId) {
    return 'Modelo: $modelId';
  }

  @override
  String get msgInfoNoMetadata => 'No hay metadatos disponibles';

  @override
  String msgInfoPartDescriptionModel(String description, String model) {
    return '$description$model';
  }

  @override
  String get msgInfoPatch => 'Parche';

  @override
  String msgInfoProvider(String providerId) {
    return 'Proveedor: $providerId';
  }

  @override
  String get msgInfoRetry => 'Intento';

  @override
  String get msgInfoSnapshot => 'Instantánea';

  @override
  String msgInfoSubtaskPartAgent(String agent) {
    return 'Subtarea ($agent)';
  }

  @override
  String msgInfoTokens(int total) {
    return 'Tokens: $total';
  }

  @override
  String get msgInfoUndoThisTurn => 'Deshacer este turno';

  @override
  String get msgInfoView => 'Ver';

  @override
  String get msgNoSystemSoundsFound =>
      'No se encontró ningún sonido del sistema en este dispositivo.';

  @override
  String get msgNoValidFilesSelected => 'No se seleccionaron archivos válidos';

  @override
  String get msgSomeSelectedFilesNotAttached =>
      'No se pudieron adjuntar algunos archivos seleccionados.';

  @override
  String get msgReadAloud => 'Leer en voz alta';

  @override
  String get msgReadAloudNotAvailable =>
      'La síntesis de voz no está disponible en este dispositivo.';

  @override
  String get msgSetupDebugCopied =>
      'Debug de configuración de OpenCode copiado';

  @override
  String get msgShareAsImage => 'Compartir como imagen';

  @override
  String get msgShareAsImageFailed =>
      'No se pudo compartir el mensaje como imagen.';

  @override
  String get msgShareAsImageSubject => 'Mensaje de CodeWalk';

  @override
  String get msgShareAsImageTooTall =>
      'El mensaje es demasiado largo para ser compartido como imagen.';

  @override
  String get msgStopReadAloud => 'Detener lectura';

  @override
  String get msgSystemSoundPickerUnavailable =>
      'El selector de sonido del sistema no está disponible en esta plataforma.';

  @override
  String get msgUpdatedButRefreshFailed =>
      'Configuración del servidor actualizada, pero no se pudieron actualizar los proveedores de chat.';

  @override
  String get msgVoiceInputUnavailable =>
      'Entrada de voz no disponible en este dispositivo';

  @override
  String get notifAndroidBatteryOptimization =>
      'Optimización de batería de Android';

  @override
  String get notifConversationUpdates => 'Actualizaciones de conversación';

  @override
  String get notifNotificationsArriveReopening =>
      'Si las notificaciones solo llegan al abrir la aplicación, permita que CodeWalk se ejecute sin optimización de batería en este dispositivo.';

  @override
  String get notifResponseRunningKeep =>
      'Cuando una respuesta esté en curso, mantenga el tiempo real activo brevemente después de salir de la aplicación.';

  @override
  String notifSelectedSoundLabel(String soundLabel) {
    return 'Seleccionado: $soundLabel';
  }

  @override
  String get notificationAgentFinished =>
      'El agente terminó la respuesta actual.';

  @override
  String get notificationConversationUpdates =>
      'Actualizaciones de la conversación';

  @override
  String get notificationOpenToClear =>
      'Abra esta conversación para borrar las notificaciones relacionadas.';

  @override
  String get notificationSession => 'Sesión';

  @override
  String get notificationSoundLoadFailed =>
      'Error al cargar los sonidos del sistema Android';

  @override
  String get onboardingAIGeneratedTitles => 'Títulos generados por IA';

  @override
  String get onboardingAddServerLater =>
      'Puede añadir un servidor más tarde en Ajustes > Servidores.';

  @override
  String get onboardingAddedButHealthCheckFailed =>
      'Servidor añadido pero la comprobación de salud falló. Puede que aún se esté iniciando.';

  @override
  String get onboardingAlmostInstallOpenCode =>
      'Ya casi está. Instale OpenCode primero, luego conecte CodeWalk a la URL del servidor.';

  @override
  String onboardingAppProviderLocalSetupLogsLength(int length, int length2) {
    return '$length líneas de registro de configuración y $length2 eventos de configuración están disponibles en la pantalla de depuración de configuración separada.';
  }

  @override
  String get onboardingAuthenticate => 'Autenticar';

  @override
  String get onboardingAvailable => 'disponible';

  @override
  String get onboardingAvailableOnlyDesktop =>
      'Disponible solo en escritorio (Linux/macOS/Windows).';

  @override
  String get onboardingBasicAuthTip =>
      'Habilite la autenticación básica solo si su servidor OpenCode está protegido por contraseña.';

  @override
  String get onboardingChooseAnotherPath => 'Elegir otro camino';

  @override
  String get onboardingChooseHowToSetup => 'Elija cómo configurar su servidor';

  @override
  String get onboardingClear => 'Limpiar';

  @override
  String get onboardingCloudflareAuthFailed =>
      'La autenticación de Cloudflare Access falló.';

  @override
  String get onboardingCodeWalkAppOpenCode =>
      'CodeWalk es la aplicación. OpenCode es el motor al que se conecta.';

  @override
  String get onboardingConnectRunningServer =>
      'Conectarse a un servidor en ejecución';

  @override
  String get onboardingConnectionIssue => 'Problema de conexión';

  @override
  String get onboardingConnectionSaved =>
      'Conexión al servidor guardada con éxito.';

  @override
  String get onboardingConnectionTips => 'Consejos de conexión';

  @override
  String get onboardingConnectionUpdated =>
      'Conexión al servidor actualizada con éxito.';

  @override
  String get onboardingContinue => 'Continuar';

  @override
  String get onboardingContinueServerURL => 'Continuar a la URL del servidor';

  @override
  String get onboardingCopyLoginURL => 'Copiar URL de inicio de sesión';

  @override
  String get onboardingCouldNotVerify =>
      'No se pudo verificar la conexión al servidor.';

  @override
  String get onboardingDefaultURLEmulator =>
      'URL predeterminada, loopback del emulador, autenticación y ayuda de depuración.';

  @override
  String onboardingDesktopOnlyDiagnose(String appName) {
    return 'Solo escritorio: $appName puede diagnosticar, instalar y ejecutar OpenCode por usted.';
  }

  @override
  String get onboardingDetailedSetupEvents =>
      'Se capturaron eventos de configuración detallados para la solución de problemas.';

  @override
  String get onboardingDonShowAgain => 'No volver a mostrar';

  @override
  String get onboardingDone => 'Hecho';

  @override
  String get onboardingEditServer => 'Editar servidor';

  @override
  String get onboardingEditServerConnection => 'Editar conexión del servidor';

  @override
  String get onboardingEmulatorRemap =>
      'En el emulador de Android, localhost y 127.0.0.1 se reasignan a 10.0.2.2 automáticamente.';

  @override
  String get onboardingEnterServerUrl => 'Ingrese la URL del servidor';

  @override
  String get onboardingExisting => 'Usar existente';

  @override
  String get onboardingExplainInstallOpenCode =>
      'Explica cómo instalar OpenCode, iniciar el servidor y luego conectarse desde CodeWalk.';

  @override
  String get onboardingFailed => 'Falló';

  @override
  String get onboardingGoodOptionDesktop =>
      'Buena primera opción en escritorio';

  @override
  String get onboardingHealthCheckFailedMayBeStarting =>
      'La comprobación de salud del servidor falló. Puede que aún se esté iniciando.';

  @override
  String get onboardingInstallBinary => 'Instalar binario';

  @override
  String get onboardingInstallBun => 'Instalar mediante Bun';

  @override
  String get onboardingInstallBunOpenCode => 'Instalar Bun + OpenCode';

  @override
  String get onboardingInstallNpm => 'Instalar mediante npm';

  @override
  String get onboardingInstallRunOpenCode =>
      'Instale y ejecute el servidor de OpenCode directamente desde CodeWalk en el escritorio.';

  @override
  String get onboardingInvalidUrl => 'URL inválida';

  @override
  String get onboardingLabel => 'Etiqueta (opcional)';

  @override
  String get onboardingLabelHint => 'Mi servidor';

  @override
  String onboardingLatestOutputAppProvider(String localServerLastOutput) {
    return 'Última salida: $localServerLastOutput';
  }

  @override
  String get onboardingLetCodeWalkSet =>
      'Permitir que CodeWalk lo configure localmente';

  @override
  String get onboardingLocalServerSetup => 'Configuración del servidor local';

  @override
  String get onboardingManagedLocalServer => 'Servidor local gestionado';

  @override
  String get onboardingManagedLocalServer2 =>
      'El modo de servidor local gestionado está disponible solo en compilaciones de escritorio (Linux/macOS/Windows).';

  @override
  String onboardingNeedsOpenCodeServer(String appName) {
    return '$appName necesita un servidor OpenCode antes de poder ayudarle con su código.';
  }

  @override
  String get onboardingNotAvailable => 'no disponible';

  @override
  String get onboardingNotWritable => 'no escribible';

  @override
  String get onboardingOpenCode => '¿Qué es OpenCode?';

  @override
  String get onboardingOpenCodeRunningDevice =>
      'Ya tengo OpenCode ejecutándose en este dispositivo o en algún lugar de mi red.';

  @override
  String get onboardingOpenCodeRunsLocally =>
      'OpenCode se ejecuta localmente o en un servidor y potencia las funciones de codificación de IA dentro de CodeWalk. Si OpenCode ya se está ejecutando, conéctese a él. Si no, elija una de las rutas de configuración guiadas a continuación.';

  @override
  String get onboardingOpenTailscaleLogin =>
      'No se pudo abrir la URL de inicio de sesión de Tailscale.';

  @override
  String get onboardingPassword => 'Contraseña';

  @override
  String get onboardingPasswordRequired => 'Introduzca la contraseña';

  @override
  String get onboardingPickSetupPath =>
      'Elija la ruta de configuración que coincida con su configuración actual de OpenCode.';

  @override
  String get onboardingPreconditionDirectoryNotWritable =>
      'El directorio de instalación no tiene permisos de escritura. Compruebe los permisos de usuario.';

  @override
  String get onboardingPreconditionInstallViaBunRecommendation =>
      'Los mantenedores de OpenCode recomiendan la instalación a través de Bun.';

  @override
  String get onboardingPreconditionNetworkFailed =>
      'Error de acceso a la red. Compruebe la conectividad antes de instalar OpenCode.';

  @override
  String get onboardingPreconditionNoRuntimeDetected =>
      'No se detectó ningún entorno de ejecución. Instale el binario de OpenCode directamente o inicialice Bun primero.';

  @override
  String get onboardingPreconditionNodeNpmAvailable =>
      'Node y npm están disponibles. Instale OpenCode a través de npm o instale Bun para el flujo recomendado.';

  @override
  String get onboardingPreconditionOpenCodeAlreadyAvailable =>
      'OpenCode ya está disponible. Puede utilizar el comando detectado inmediatamente.';

  @override
  String get onboardingPreconditionWindowsPathLagHint =>
      ' En Windows, actualice las comprobaciones después de la instalación porque las actualizaciones de PATH pueden tardar en aplicarse en las aplicaciones ya abiertas.';

  @override
  String get onboardingPreconditionWindowsWslRecommendation =>
      'Se detectó una compilación de Windows. La documentación de OpenCode recomienda WSL, pero se puede usar npm install como alternativa.';

  @override
  String get onboardingReachable => 'alcanzable';

  @override
  String get onboardingReady => 'Listo';

  @override
  String get onboardingRecommendedOrderTry =>
      'Orden recomendado: intente Instalar Bun + OpenCode si desea que CodeWalk prepare todo por usted. Use Existente si OpenCode ya está instalado.';

  @override
  String get onboardingRefreshChecks => 'Actualizar comprobaciones';

  @override
  String get onboardingRunDiagnosticsToVerify =>
      'Ejecute diagnósticos para verificar los requisitos locales de OpenCode.';

  @override
  String get onboardingSaveAndTest => 'Guardar y probar';

  @override
  String get onboardingServerConnectedReady =>
      'Su servidor está conectado y listo para usar.';

  @override
  String get onboardingServerConnection => 'Conexión del servidor';

  @override
  String get onboardingServerSettingsSaved =>
      'Se guardaron los ajustes del servidor y se actualizaron las comprobaciones de salud.';

  @override
  String get onboardingServerSetup => 'Configuración del servidor';

  @override
  String get onboardingServerUpdated => 'Servidor actualizado';

  @override
  String get onboardingServerUrl => 'URL del servidor';

  @override
  String get onboardingSetup => 'Configuración';

  @override
  String get onboardingSetupWizard => 'Asistente de configuración';

  @override
  String get onboardingShowSetupSteps => 'Mostrar los pasos de configuración';

  @override
  String get onboardingShowSetupSteps2 => 'Mostrar pasos de configuración';

  @override
  String get onboardingSkip => 'Omitir por ahora';

  @override
  String get onboardingSkipSetup => '¿Omitir configuración?';

  @override
  String get onboardingStart => 'Iniciar';

  @override
  String onboardingStartUsing(String appName) {
    return 'Empezar a usar $appName';
  }

  @override
  String get onboardingStarting => 'Iniciando';

  @override
  String get onboardingStop => 'Detener';

  @override
  String get onboardingStopped => 'Detenido';

  @override
  String get onboardingStopping => 'Deteniendo';

  @override
  String onboardingSuggestedUrl(String url) {
    return 'URL sugerida del servidor OpenCode local: $url';
  }

  @override
  String get onboardingTailscaleAdminApproval =>
      'Se requiere aprobación del administrador de Tailscale';

  @override
  String get onboardingTailscaleAuthAfterSave =>
      'Tailscale se autenticará después de guardar';

  @override
  String onboardingTailscaleAuthAfterSaveTest(String appName) {
    return 'Después de guardar y probar este servidor, $appName abrirá el inicio de sesión de Tailscale si este dispositivo aún no está autenticado.';
  }

  @override
  String get onboardingTailscaleConnected => 'Tailscale conectado';

  @override
  String get onboardingTailscaleConnecting => 'Tailscale conectando';

  @override
  String get onboardingTailscaleConnectionFailed =>
      'Conexión de Tailscale fallida';

  @override
  String get onboardingTailscaleLoginRequired =>
      'Se requiere inicio de sesión en Tailscale';

  @override
  String get onboardingTailscaleOpenLoginUrl =>
      'Abra la URL de inicio de sesión para añadir este dispositivo a su tailnet. Si el navegador no se abrió, copie la URL a continuación.';

  @override
  String get onboardingTailscaleUnsupported => 'Tailscale no compatible';

  @override
  String get onboardingTestConnection => 'Probar conexión';

  @override
  String get onboardingTesting => 'Probando...';

  @override
  String get onboardingUnreachable => 'inalcanzable';

  @override
  String get onboardingUseBasicAuth => 'Usar autenticación básica';

  @override
  String get onboardingUsername => 'Usuario';

  @override
  String get onboardingUsernameRequired => 'Introduzca el usuario';

  @override
  String get onboardingUsesServerTitle =>
      'Utiliza el agente de títulos de su servidor para nombrar las conversaciones';

  @override
  String get onboardingUsingDetectedCommand =>
      'Usando el comando OpenCode detectado.';

  @override
  String get onboardingViewSetupDebug => 'Ver depuración de la configuración';

  @override
  String onboardingWelcomeTo(String appName) {
    return 'Bienvenido a $appName';
  }

  @override
  String get onboardingWindowsTipInstalling =>
      'Consejo para Windows: después de instalar, haga clic en Actualizar comprobaciones. Si la detección sigue fallando, vuelva a abrir CodeWalk para recargar los cambios de PATH.';

  @override
  String get onboardingWritable => 'escribible';

  @override
  String get onboardingYoureAllSet => '¡Todo listo!';

  @override
  String get permissionAllowOnce => 'Permitir Una Vez';

  @override
  String get permissionAlways => 'Siempre';

  @override
  String get permissionBack => 'Volver';

  @override
  String get permissionConfirmReject => 'Confirmar Rechazo';

  @override
  String get permissionReject => 'Rechazar';

  @override
  String get permissionReopen => 'Reabrir';

  @override
  String get questionAnswerSelected => 'Ninguna respuesta seleccionada.';

  @override
  String get questionCommaSeparatedValues => 'Valores separados por comas';

  @override
  String get questionQuestionGroupMarked =>
      'Grupo de preguntas marcado como rechazado. Puede continuar chateando y reabrir este grupo en cualquier momento antes de confirmar.';

  @override
  String get questionQuestionRequest => 'Solicitud de pregunta';

  @override
  String get questionQuestionsProvidedSubmit =>
      'No se proporcionaron preguntas. Puede enviar una respuesta vacía.';

  @override
  String get questionReviewAnswersSubmitting =>
      'Revise sus respuestas antes de enviarlas.';

  @override
  String get quotaAuthCookie => 'Cookie de autenticación';

  @override
  String get quotaConnect => 'Conectar';

  @override
  String get quotaForget => 'Olvidar';

  @override
  String get quotaOpenCodeGoConnectDescription =>
      'Conecta el panel de uso para mostrar límites móviles, semanales y mensuales.';

  @override
  String get quotaOpenCodeGoDetected => 'OpenCode Go detectado';

  @override
  String get quotaOpenCodeGoNeedsReconnect =>
      'OpenCode Go necesita reconectarse';

  @override
  String get quotaOpenCodeGoReconnectDescription =>
      'Actualiza las credenciales del panel para restaurar las barras de uso.';

  @override
  String get quotaOpenCodeGoUsage => 'Uso de OpenCode Go';

  @override
  String get quotaOpenDashboard => 'Abrir panel de OpenCode';

  @override
  String get quotaPaceExplanation =>
      'El ritmo predice el uso total al final de la ventana de límite actual según la tasa actual.';

  @override
  String quotaPacePercent(String percent) {
    return 'Ritmo $percent%';
  }

  @override
  String get quotaRateLimits => 'Límites de uso';

  @override
  String get quotaReconnect => 'Reconectar';

  @override
  String get quotaRefreshing => 'Actualizando...';

  @override
  String quotaResetsIn(String time) {
    return 'Se restablece en $time';
  }

  @override
  String get quotaSaving => 'Guardando...';

  @override
  String get quotaWorkspaceId => 'ID del Espacio de Trabajo';

  @override
  String get serverClearOAuth => 'Limpiar OAuth';

  @override
  String get serverConnectionAttention =>
      'La conexión al servidor necesita atención.';

  @override
  String get serverHealthHealthy => 'Saludable';

  @override
  String get serverHealthUnhealthy => 'No saludable';

  @override
  String get serverHealthUnknown => 'Desconocido';

  @override
  String get serverOAuthAuthFailed => 'Error de autenticación OAuth';

  @override
  String get serverOAuthChip => 'OAuth';

  @override
  String get serverOAuthNotSupported =>
      'Cloudflare Access OAuth no es compatible en esta plataforma';

  @override
  String get serverReauthenticate => 'Volver a autenticar';

  @override
  String get serverTailscaleChip => 'Tailscale';

  @override
  String get serversActive => 'Activo';

  @override
  String get serversActiveServer => 'Servidor Activo';

  @override
  String get serversAddLeastOpenCode =>
      'Añada al menos un servidor de OpenCode para empezar a usar la aplicación.';

  @override
  String get serversAddServer => 'Añadir Servidor';

  @override
  String get serversCancel => 'Cancelar';

  @override
  String get serversCannotActivateUnhealthy =>
      'No se puede activar un servidor no saludable';

  @override
  String get serversCheckHealth => 'Comprobar salud';

  @override
  String get serversClearDefault => 'Limpar Predeterminado';

  @override
  String serversCommandAppProviderLocalServerCommandPath(
    String localServerCommandPath,
  ) {
    return 'Comando: $localServerCommandPath';
  }

  @override
  String get serversCopy => 'Copiar';

  @override
  String get serversDefault => 'Predeterminado';

  @override
  String get serversDelete => 'Eliminar';

  @override
  String get serversDeleteServer => 'Eliminar servidor';

  @override
  String get serversDesktopModeExplanation =>
      'El modo escritorio puede iniciar y gestionar `opencode serve` directamente desde CodeWalk.';

  @override
  String get serversEdit => 'Editar';

  @override
  String get serversLocalOpenCodeServer => 'Servidor de OpenCode Local';

  @override
  String get serversManagedModeAvailable =>
      'Este modo gestionado está disponible solo en compilaciones de escritorio (Linux/macOS/Windows).';

  @override
  String get serversNoServersFound => 'No se encontraron servidores';

  @override
  String get serversRefreshHealth => 'Actualizar salud';

  @override
  String serversRemoveProfileDisplayName(String displayName) {
    return '¿Eliminar \"$displayName\"?';
  }

  @override
  String get serversSearchActiveHint => 'Buscar servidor activo';

  @override
  String get serversServersConfigured => 'No hay servidores configurados';

  @override
  String get serversSetActive => 'Establecer como activo';

  @override
  String get serversSetDefault => 'Establecer como predeterminado';

  @override
  String get serversSetupDebug => 'Depuración de la Configuración';

  @override
  String get serversSetupWizard => 'Asistente de Configuración';

  @override
  String get serversTailscaleAdminApprovalRequired =>
      'Aprobación del administrador de Tailscale requerida';

  @override
  String get serversTailscaleAuthRequired =>
      'Autenticación de Tailscale requerida';

  @override
  String get serversTailscaleConnectExplanation =>
      'Tailscale se conectará cuando se use este perfil activo.';

  @override
  String get serversTailscaleConnected => 'Tailscale conectado';

  @override
  String get serversTailscaleConnecting => 'Tailscale conectando';

  @override
  String get serversTailscaleConnectionFailed => 'Conexión Tailscale fallida';

  @override
  String get serversTailscaleDisconnected => 'Tailscale desconectado';

  @override
  String get serversTailscaleLoginExplanation =>
      'Abra la URL de inicio de sesión de Tailscale para agregar este dispositivo a su tailnet.';

  @override
  String get serversTailscaleTrafficExplanation =>
      'El tráfico de OpenCode para este perfil activo se enruta a través de Tailscale.';

  @override
  String get serversTailscaleUnsupported => 'Tailscale no compatible';

  @override
  String get serversUnhealthyActivateError =>
      'Este servidor no está saludable. Use verificar salud o editar configuración antes de activar.';

  @override
  String get sessionActionArchived => 'archivada';

  @override
  String get sessionActionDeleted => 'eliminada';

  @override
  String get sessionActionForked => 'bifurcada';

  @override
  String get sessionActionPinned => 'fijada';

  @override
  String get sessionActionUnarchived => 'desarchivada';

  @override
  String get sessionActionUnpinned => 'desfijada';

  @override
  String get sessionArchive => 'Archivar';

  @override
  String get sessionCancelRename => 'Cancelar renombrado';

  @override
  String sessionChildrenCount(int count) {
    return 'Subconversaciones: $count';
  }

  @override
  String get sessionCompactContext => 'Compactar contexto';

  @override
  String get sessionCopyLink => 'Copiar Enlace';

  @override
  String get sessionDelete => 'Eliminar';

  @override
  String sessionDeleteConfirm(String title) {
    return '¿Seguro que quieres eliminar la conversación \"$title\"? Esta acción no se puede deshacer.';
  }

  @override
  String get sessionDeleteTitle => 'Eliminar Conversación';

  @override
  String get sessionDiffChangedFile => 'Archivo cambiado';

  @override
  String get sessionDiffContentNotCaptured =>
      'Contenido del archivo no capturado por el servidor';

  @override
  String sessionDiffFilesChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos cambiados',
      one: '1 archivo cambiado',
    );
    return '$_temp0';
  }

  @override
  String sessionDiffFilesCount(int count) {
    return 'Archivos diff: $count';
  }

  @override
  String sessionDiffLinesAddedRemoved(int added, int removed) {
    return '+$added líneas añadidas -$removed líneas eliminadas';
  }

  @override
  String sessionDiffLinesCollapsed(int count) {
    return '$count líneas colapsadas — toque para expandir';
  }

  @override
  String get sessionDiffLoading => 'Cargando archivos modificados…';

  @override
  String get sessionDiffReview => 'Revisar cambios';

  @override
  String get sessionDiffSplit => 'Dividido';

  @override
  String get sessionDiffSummary => 'Resumen';

  @override
  String get sessionDiffUnified => 'Unificado';

  @override
  String get sessionExportAssistant => 'Asistente';

  @override
  String get sessionExportCanceled => 'Exportación cancelada';

  @override
  String get sessionExportDebugJson => 'Exportar JSON de depuración';

  @override
  String get sessionExportDebugJsonErrorClipboard =>
      'No se pudo guardar; JSON de depuración copiado al portapapeles';

  @override
  String get sessionExportDebugJsonSaved =>
      'Exportación JSON de depuración guardada';

  @override
  String get sessionExportDebugJsonTitle =>
      'Exportar sesión como JSON de depuración';

  @override
  String get sessionExportError => 'Error:';

  @override
  String get sessionExportInput => 'Entrada:';

  @override
  String get sessionExportMarkdown => 'Exportar Markdown';

  @override
  String get sessionExportMarkdownErrorClipboard =>
      'No se pudo guardar; Markdown copiado al portapapeles';

  @override
  String get sessionExportMarkdownSaved => 'Exportación Markdown guardada';

  @override
  String get sessionExportMarkdownTitle => 'Exportar sesión como Markdown';

  @override
  String get sessionExportOutput => 'Salida:';

  @override
  String get sessionExportUntitled => 'Sesión sin título';

  @override
  String get sessionExportUser => 'Usuario';

  @override
  String get sessionFailedRename => 'Error al renombrar conversación';

  @override
  String get sessionFailedUpdateArchive =>
      'Error al actualizar estado de archivado';

  @override
  String get sessionFailedUpdateSharing =>
      'Error al actualizar estado de compartir';

  @override
  String get sessionFork => 'Bifurcar';

  @override
  String get sessionForkFailed => 'Error al bifurcar conversación';

  @override
  String get sessionForked => 'Conversación bifurcada';

  @override
  String sessionHasError(String title) {
    return '\"$title\" tiene un error.';
  }

  @override
  String sessionHasNewReply(String title) {
    return '\"$title\" tiene una nueva respuesta.';
  }

  @override
  String get sessionKeyboardShortcuts => 'Atajos de teclado';

  @override
  String sessionNeedsInput(String title) {
    return '\"$title\" necesita tu entrada.';
  }

  @override
  String get sessionNoCachedConversations => 'No hay conversaciones en caché';

  @override
  String get sessionNoConversationsInProject =>
      'No hay conversaciones en este proyecto.';

  @override
  String get sessionNotAvailable =>
      'La conversación aún no está disponible para este proyecto';

  @override
  String get sessionOpenProjectToLoad =>
      'Abre el proyecto para cargar conversaciones.';

  @override
  String get sessionPin => 'Fijar';

  @override
  String get sessionRename => 'Renombrar';

  @override
  String get sessionRenameHint => 'Ingrese el nuevo nombre de la conversación';

  @override
  String get sessionRenameTitle => 'Renombrar Conversación';

  @override
  String get sessionSaveTitle => 'Guardar título';

  @override
  String get sessionShare => 'Compartir sesión';

  @override
  String get sessionShareAction => 'Compartir';

  @override
  String get sessionShareLinkCopied => 'Enlace de compartir copiado';

  @override
  String get sessionShareLinkUnavailable =>
      'Enlace no disponible para esta sesión';

  @override
  String get sessionShared => 'Conversación compartida';

  @override
  String get sessionSyncing => 'Sincronizando conversaciones...';

  @override
  String get sessionTitleHint => 'Título de la conversación';

  @override
  String get sessionUnarchive => 'Desarchivar';

  @override
  String get sessionUnpin => 'Desfijar';

  @override
  String get sessionUnshare => 'Dejar de compartir sesión';

  @override
  String get sessionUnshareAction => 'Dejar de compartir';

  @override
  String get sessionUnshared => 'Conversación dejada de compartir';

  @override
  String get sessionViewTasks => 'Ver tareas';

  @override
  String get settingsAboutCheckForUpdates => 'Buscar actualizaciones';

  @override
  String get settingsAboutCheckOnOpen => 'Buscar actualizaciones al abrir';

  @override
  String get settingsAboutCheckOnOpenDescription =>
      'Comprobar automáticamente cuando inicia la app';

  @override
  String get settingsAboutChecking => 'Comprobando...';

  @override
  String get settingsAboutDescription =>
      'Versión, actualizaciones, ayuda y datos de la app';

  @override
  String get settingsAboutDismiss => 'Descartar';

  @override
  String settingsAboutDownloading(String percent) {
    return 'Descargando... $percent%';
  }

  @override
  String get settingsAboutEraseAllData => 'Borrar todos los datos y reiniciar';

  @override
  String get settingsAboutInstallUpdate => 'Instalar actualización';

  @override
  String get settingsAboutInstalling => 'Instalando...';

  @override
  String settingsAboutLatestVersion(String version) {
    return 'v$version es la versión más reciente';
  }

  @override
  String get settingsAboutLoading => 'Cargando...';

  @override
  String get settingsAboutReplayChatTour => 'Repetir recorrido del chat';

  @override
  String get settingsAboutReplayChatTourDescription =>
      'Cerrar ajustes y mostrar la guía del chat';

  @override
  String get settingsAboutResetApp => 'Restablecer app';

  @override
  String get settingsAboutResetAppQuestion => '¿Restablecer app?';

  @override
  String get settingsAboutResetAppWarning =>
      'Esto borrará todos los servidores, ajustes y datos en caché. Esta acción no se puede deshacer.';

  @override
  String get settingsAboutRetryInstall => 'Reintentar instalación';

  @override
  String get settingsAboutTapToCheck => 'Toca para buscar nuevas versiones';

  @override
  String get settingsAboutTitle => 'Acerca de';

  @override
  String get settingsAboutUpToDate => 'Estás al día';

  @override
  String settingsAboutUpdateAvailable(String version) {
    return 'Actualización disponible: v$version';
  }

  @override
  String get settingsAboutUpdateInstalled =>
      'Actualización instalada. Reinicie la app para aplicarla.';

  @override
  String settingsAboutUpdateVersionSummary(
    String installedVersion,
    String latestVersion,
  ) {
    return 'Actual: $installedVersion; disponible: v$latestVersion';
  }

  @override
  String get settingsAboutVersion => 'Versión';

  @override
  String settingsAboutVersionBuild(String buildNumber, String version) {
    return '$version (compilación $buildNumber)';
  }

  @override
  String get settingsAppearanceAmoledDark => 'Modo oscuro AMOLED';

  @override
  String get settingsAppearanceAmoledDarkActive =>
      'Usar superficies negras puras mientras el modo oscuro esté activo.';

  @override
  String get settingsAppearanceAmoledDarkInactive =>
      'Cambie al modo oscuro para habilitar superficies AMOLED.';

  @override
  String get settingsAppearanceBrandColor => 'Color de marca';

  @override
  String get settingsAppearanceBrandColorDynamicBlocked =>
      'Desactive los colores del fondo de pantalla para elegir un color de marca.';

  @override
  String get settingsAppearanceBrandColorNormal =>
      'Elija un color semilla para la paleta de la app.';

  @override
  String get settingsAppearanceBrandColorPresetBlocked =>
      'Cambie a CodeWalk Clásico para elegir un color de marca.';

  @override
  String get settingsAppearanceChatFontScale =>
      'Tamaño del texto de la conversación';

  @override
  String get settingsAppearanceChatFontScaleDescription =>
      'Escala el texto de los mensajes del chat y del compositor además del tamaño de texto del sistema.';

  @override
  String get settingsAppearanceCodeWalkClassic => 'CodeWalk Clásico';

  @override
  String get settingsAppearanceComposerTips => 'Consejos del compositor';

  @override
  String get settingsAppearanceComposerTipsDescription =>
      'Mostrar u ocultar consejos rotativos mientras el asistente razona.';

  @override
  String get settingsAppearanceContrast => 'Contraste';

  @override
  String get settingsAppearanceContrastDynamicBlocked =>
      'Desactive los colores del fondo de pantalla para ajustar el contraste.';

  @override
  String get settingsAppearanceContrastHigh => 'Alto';

  @override
  String get settingsAppearanceContrastNormal =>
      'Ajuste el nivel de contraste del esquema de color.';

  @override
  String get settingsAppearanceContrastPresetBlocked =>
      'Cambie a CodeWalk Clásico para ajustar el contraste.';

  @override
  String get settingsAppearanceContrastReduced => 'Reducido';

  @override
  String get settingsAppearanceDark => 'Oscuro';

  @override
  String get settingsAppearanceDensity => 'Densidad';

  @override
  String get settingsAppearanceDensityDense => 'Densa';

  @override
  String get settingsAppearanceDensityDescription =>
      'Aplica espaciado y densidad de componentes en toda la app.';

  @override
  String get settingsAppearanceDensityExtraDense => 'Extra Densa';

  @override
  String get settingsAppearanceDensityExtraSpacious => 'Extra Espaciosa';

  @override
  String get settingsAppearanceDensityNormal => 'Normal';

  @override
  String get settingsAppearanceDensitySpacious => 'Espaciosa';

  @override
  String get settingsAppearanceDescription =>
      'Elige temas, colores, tamaño de texto y visualización del chat';

  @override
  String get settingsAppearanceFontSize => 'Tamaño del texto';

  @override
  String get settingsAppearanceFontSizeDescription =>
      'Ajusta el tamaño del texto del sistema, de la conversación y del terminal.';

  @override
  String get settingsAppearanceLight => 'Claro';

  @override
  String get settingsAppearanceMathRendering => 'Renderizado de matemáticas';

  @override
  String get settingsAppearanceMathRenderingDescription =>
      'Renderizar expresiones matemáticas LaTeX como ecuaciones tipografiadas en mensajes de chat.';

  @override
  String get settingsAppearanceNoPresets => 'No se encontraron paletas';

  @override
  String get settingsAppearanceOpenCodePresets => 'Presets OpenCode';

  @override
  String get settingsAppearancePresetHelper =>
      'Refleja la lista oficial de temas integrados de OpenCode Web.';

  @override
  String get settingsAppearancePresetNote =>
      'Los colores del tema ahora siguen el registro oficial de OpenCode Web.';

  @override
  String get settingsAppearancePresetPalette => 'Paleta predefinida';

  @override
  String get settingsAppearanceSearchPreset => 'Buscar paleta predefinida';

  @override
  String get settingsAppearanceSectionDescription =>
      'Ajuste la densidad visual y las superficies de mensaje para su flujo de trabajo.';

  @override
  String get settingsAppearanceSectionTitle => 'Apariencia';

  @override
  String get settingsAppearanceSystem => 'Sistema';

  @override
  String get settingsAppearanceSystemFontScale =>
      'Tamaño del texto del sistema';

  @override
  String get settingsAppearanceSystemFontScaleDescription =>
      'Escala todo el texto del shell de la aplicación, incluidos menús, diálogos y barras laterales.';

  @override
  String get settingsAppearanceTaskList => 'Lista de tareas';

  @override
  String get settingsAppearanceTaskListDescription =>
      'Mostrar u ocultar el widget de lista de tareas de la sesión.';

  @override
  String get settingsAppearanceTerminalFontSize =>
      'Tamaño del texto del terminal';

  @override
  String get settingsAppearanceTerminalFontSizeDescription =>
      'Cambia el tamaño de la fuente del terminal integrado. Se aplica de inmediato a las sesiones en ejecución.';

  @override
  String get settingsAppearanceTheme => 'Tema';

  @override
  String get settingsAppearanceThemeDescription =>
      'Elija entre modo claro, oscuro o sistema.';

  @override
  String get settingsAppearanceVisualStyle => 'Estilo visual';

  @override
  String get settingsAppearanceVisualStyleDescription =>
      'Elija el aspecto clásico o superficies refinadas más suaves.';

  @override
  String get settingsAppearanceVisualStyleClassic => 'Clásico';

  @override
  String get settingsAppearanceVisualStyleRefined => 'Refinado';

  @override
  String get settingsAppearanceThinkingBubbles => 'Burbujas de pensamiento';

  @override
  String get settingsAppearanceThinkingBubblesDescription =>
      'Mostrar u ocultar bloques de razonamiento en los mensajes del asistente.';

  @override
  String get settingsAppearanceTitle => 'Apariencia';

  @override
  String get settingsAppearanceToolCallBubbles =>
      'Burbujas de llamada de herramienta';

  @override
  String get settingsAppearanceToolCallBubblesDescription =>
      'Mostrar u ocultar tarjetas de ejecución de herramientas.';

  @override
  String get settingsAppearanceWallpaperColors =>
      'Usar colores del fondo de pantalla';

  @override
  String get settingsAppearanceWallpaperNormal =>
      'Extraer esquema de color del fondo de pantalla del dispositivo.';

  @override
  String get settingsAppearanceWallpaperPresetBlocked =>
      'Cambie a CodeWalk Clásico para usar colores del fondo de pantalla.';

  @override
  String get settingsAppearanceWindowChrome => 'Pestañas de la ventana';

  @override
  String get settingsAppearanceWindowChromeDescription =>
      'Elige cómo se combinan las pestañas de sesión y la barra de título en el escritorio.';

  @override
  String get settingsAppearanceWindowChromeIntegrated => 'Pestañas integradas';

  @override
  String get settingsAppearanceWindowChromeIntegratedDescription =>
      'Las pestañas van en la parte superior de la ventana y se oculta la barra de título del sistema.';

  @override
  String get settingsAppearanceWindowChromeSystem => 'Decoración del sistema';

  @override
  String get settingsAppearanceWindowChromeSystemDescription =>
      'Mantiene la barra de título nativa y muestra las pestañas debajo de la barra de la app.';

  @override
  String get settingsBack => 'Volver';

  @override
  String get settingsBehaviorAutoupdateCaveat =>
      'Use Acerca de para las verificaciones de versión de CodeWalk. Esta configuración solo refleja la config `autoupdate` oficial de OpenCode.';

  @override
  String get settingsBehaviorAutoupdateHelp =>
      'Controla las actualizaciones de runtime de OpenCode, no las verificaciones de actualización de CodeWalk.';

  @override
  String get settingsBehaviorCellularDataSaver => 'Ahorro de datos móviles';

  @override
  String get settingsBehaviorChatRenderMode => 'Modo de renderizado del chat';

  @override
  String get settingsBehaviorChatRenderModeBlock => 'Bloque';

  @override
  String get settingsBehaviorChatRenderModeBlockDescription =>
      'Oculta el texto en vivo del asistente, el razonamiento y las tarjetas de herramientas hasta que el turno actual pueda mostrarse como un solo bloque.';

  @override
  String get settingsBehaviorChatRenderModeDescription =>
      'Elija si las respuestas del asistente aparecen a medida que se transmiten o se revelan después de que el turno actual se estabilice.';

  @override
  String get settingsBehaviorChatRenderModeLive => 'En vivo';

  @override
  String get settingsBehaviorChatRenderModeLiveDescription =>
      'Muestra el texto del asistente, el razonamiento y la actividad de las herramientas mientras OpenCode transmite eventos.';

  @override
  String get settingsBehaviorComposerSpellCheck =>
      'Corrección ortográfica del compositor';

  @override
  String get settingsBehaviorComposerSpellCheckDescription =>
      'Usa la corrección ortográfica, las sugerencias y la autocorrección nativas de la plataforma en el compositor del chat.';

  @override
  String get settingsBehaviorConfigDeferred =>
      'CodeWalk aplicará esta configuración de OpenCode después de que termine la respuesta actual.';

  @override
  String settingsBehaviorConfigUpdateFailed(String field) {
    return 'No se pudo actualizar $field de OpenCode.';
  }

  @override
  String get settingsBehaviorConversationUsername =>
      'Nombre de usuario de conversación';

  @override
  String get settingsBehaviorConversationUsernameHelp =>
      'Nombre de visualización personalizado mostrado en las conversaciones en lugar del nombre del sistema.';

  @override
  String get settingsBehaviorDataSaverActive =>
      'Activo ahora en datos móviles.';

  @override
  String get settingsBehaviorDataSaverCellularOnly =>
      'Solo se aplica cuando la conexión es celular/móvil.';

  @override
  String get settingsBehaviorDataSaverDescription =>
      'Reduce el uso automático de datos móviles deteniendo descargas en segundo plano.';

  @override
  String get settingsBehaviorDataSaverWaiting =>
      'Esperando la próxima ventana de sincronización de datos móviles.';

  @override
  String get settingsBehaviorDefaultAgent => 'Agente predeterminado';

  @override
  String get settingsBehaviorDefaultAgentHelp =>
      'Agente principal usado cuando no se elige ningún agente explícitamente.';

  @override
  String get settingsBehaviorDefaultModel => 'Modelo predeterminado';

  @override
  String get settingsBehaviorDefaultModelHelp =>
      'Compartido entre clientes OpenCode a través de config.';

  @override
  String get settingsBehaviorDescription =>
      'Controla el idioma, el comportamiento del chat, el uso de datos y las opciones predeterminadas de OpenCode';

  @override
  String get settingsBehaviorEnableDataSaver =>
      'Habilitar ahorro de datos móviles';

  @override
  String get settingsBehaviorMultiDeviceSync =>
      'Habilitar sincronización multidispositivo experimental';

  @override
  String get settingsBehaviorMultiDeviceSyncDescription =>
      'Sincroniza la selección del compositor (agente/modelo/variante) con la configuración del servidor activo.';

  @override
  String get settingsBehaviorMultiDeviceSyncWarning =>
      'Puede abortar sesiones en curso al trabajar en más de una sesión al mismo tiempo.';

  @override
  String get settingsBehaviorNoAgents => 'No se encontraron agentes';

  @override
  String get settingsBehaviorNoModels => 'No se encontraron modelos';

  @override
  String get settingsBehaviorOpenCodeAutoupdate =>
      'Actualización automática de OpenCode';

  @override
  String get settingsBehaviorOpenCodeDefaults =>
      'Valores predeterminados de OpenCode';

  @override
  String get settingsBehaviorOpenCodeDefaultsDescription =>
      'Estos valores escriben en `/config` en el servidor activo y coinciden con la configuración oficial de OpenCode.';

  @override
  String get settingsBehaviorOpenCodeSnapshots => 'Instantáneas de OpenCode';

  @override
  String get settingsBehaviorOpenCodeSnapshotsDescription =>
      'Mantener instantáneas git habilitadas para historial de deshacer/rehacer y recuperación.';

  @override
  String get settingsBehaviorPermissionDeferred =>
      'La edición avanzada de reglas de permisos queda fuera de Configuración por ahora.';

  @override
  String get settingsBehaviorPermissionProvenance =>
      'Procedencia del manejo de permisos';

  @override
  String get settingsBehaviorPermissionProvenanceDescription =>
      'La política oficial de permisos de OpenCode se configura en `opencode.json` con reglas allow/ask/deny por herramienta. CodeWalk mantiene las tarjetas oficiales de solicitud de permiso y agrega una excepción ADR-023 aprobada: el toggle de auto-aprobación del composer responde con `Always` y `remember: true` incondicionalmente para crear concesiones duraderas con alcance de sesión.';

  @override
  String get settingsBehaviorRefreshDefaults => 'Actualizar valores';

  @override
  String get settingsBehaviorSaveUsername => 'Guardar nombre de usuario';

  @override
  String get settingsBehaviorSearchAutoupdate => 'Buscar modo de actualización';

  @override
  String get settingsBehaviorSearchDefaultAgent =>
      'Buscar agente predeterminado';

  @override
  String get settingsBehaviorSearchDefaultModel =>
      'Buscar modelo predeterminado';

  @override
  String get settingsBehaviorSearchShareMode => 'Buscar modo de compartir';

  @override
  String get settingsBehaviorSearchSmallModel => 'Buscar modelo pequeño';

  @override
  String get settingsBehaviorShareMode =>
      'Modo de compartir predeterminado de OpenCode';

  @override
  String get settingsBehaviorShareModeCaveat =>
      'Use la acción de compartir en el chat para publicar una sesión ahora. Esta configuración solo cambia la política de compartir predeterminada de OpenCode.';

  @override
  String get settingsBehaviorShareModeHelp =>
      'Controla la config global oficial `share`, no el botón de compartir de un chat individual.';

  @override
  String get settingsBehaviorSmallModel => 'Modelo pequeño';

  @override
  String get settingsBehaviorSmallModelAutoFallback => 'Respaldo automático';

  @override
  String get settingsBehaviorSmallModelFallbackActive =>
      'El respaldo automático de OpenCode está activo porque `small_model` no está configurado.';

  @override
  String get settingsBehaviorSmallModelHelp =>
      'Usado para tareas ligeras como generación de títulos.';

  @override
  String get settingsBehaviorSmallModelResetCaveat =>
      'Restablecer `small_model` al respaldo automático aún requiere editar la configuración fuera de la app.';

  @override
  String get settingsBehaviorSnapshotCaveat =>
      'Esto controla el almacenamiento de instantáneas de OpenCode, no las instantáneas de caché local de CodeWalk.';

  @override
  String get settingsBehaviorTitle => 'Comportamiento';

  @override
  String get settingsBehaviorUsernameFallback =>
      'OpenCode usa el nombre de usuario del sistema porque `username` no está configurado.';

  @override
  String get settingsBehaviorUsernamePatchCaveat =>
      'Restablecer `username` al valor predeterminado del sistema aún requiere editar la configuración fuera de la app.';

  @override
  String get settingsConfigRefreshFailed =>
      'Se actualizó el ajuste del servidor, pero no se pudieron actualizar los proveedores de chat.';

  @override
  String get settingsConfigUpdateDeferred =>
      'CodeWalk aplicará este ajuste de OpenCode después de que finalice la respuesta actual.';

  @override
  String get settingsConversationUsername =>
      'Nombre de usuario de conversación';

  @override
  String get settingsDefaultAgent => 'Agente predeterminado';

  @override
  String get settingsDefaultModel => 'Modelo predeterminado';

  @override
  String get settingsLanguageDescription =>
      'Elige el idioma que usa CodeWalk. El valor predeterminado del sistema sigue el idioma del dispositivo.';

  @override
  String get settingsLanguageEmptyText => 'No se encontraron idiomas';

  @override
  String get settingsLanguageFieldHelper =>
      'Se aplica de inmediato y se mantiene tras reiniciar.';

  @override
  String get settingsLanguageFieldLabel => 'Idioma de la app';

  @override
  String get settingsLanguageSearchHint => 'Buscar idiomas';

  @override
  String get settingsLanguageSystemDefault => 'Predeterminado del sistema';

  @override
  String get settingsLanguageTitle => 'Idioma';

  @override
  String get settingsLogsDescription =>
      'Revisa los diagnósticos de la app y los detalles de solución de problemas';

  @override
  String get settingsLogsTitle => 'Registros';

  @override
  String get settingsNoAgentsFound => 'No se encontraron agentes';

  @override
  String get settingsNotificationsAgentSubtitle =>
      'Cuando una respuesta termina';

  @override
  String get settingsNotificationsAgentUpdates => 'Actualizaciones del agente';

  @override
  String get settingsNotificationsAnotherConversation => 'Otra conversación';

  @override
  String get settingsNotificationsAppInBackground => 'App en segundo plano';

  @override
  String get settingsNotificationsBackgroundAlerts =>
      'Alertas en segundo plano de Android';

  @override
  String get settingsNotificationsBackgroundBehavior =>
      'Comportamiento en segundo plano';

  @override
  String get settingsNotificationsBackgroundBehaviorDescription =>
      'Elija cómo se comporta CodeWalk después de que la app sale del primer plano.';

  @override
  String get settingsNotificationsBackgroundDescription =>
      'Usa monitoreo de bajo consumo de datos en segundo plano.';

  @override
  String get settingsNotificationsBackgroundToggle =>
      'Alertas en segundo plano en Android';

  @override
  String get settingsNotificationsBackgroundToggleDescription =>
      'Desactiva todas las verificaciones en segundo plano de Android.';

  @override
  String get settingsNotificationsBatteryDescription =>
      'Si las notificaciones solo llegan al reabrir la app, permita que CodeWalk se ejecute sin optimización.';

  @override
  String get settingsNotificationsBatteryDisabled =>
      'La optimización de batería está desactivada para CodeWalk.';

  @override
  String get settingsNotificationsBatteryEnabled =>
      'La optimización de batería está activada. Algunos dispositivos pueden retrasar las alertas.';

  @override
  String get settingsNotificationsBatteryOptimization =>
      'Optimización de batería de Android';

  @override
  String get settingsNotificationsBatteryUnknown =>
      'Aún no se pudo leer el estado de optimización de batería.';

  @override
  String get settingsNotificationsChooseAudioFile => 'Elegir archivo de audio';

  @override
  String get settingsNotificationsChooseSystemSound =>
      'Elegir sonido del sistema';

  @override
  String get settingsNotificationsCloseToTray => 'Cerrar a la bandeja';

  @override
  String get settingsNotificationsCloseToTrayDescription =>
      'Ocultar ventana y seguir ejecutándose en la bandeja del sistema.';

  @override
  String get settingsNotificationsDescription =>
      'Elige qué eventos te notifican y cómo';

  @override
  String get settingsNotificationsDisableOptimization =>
      'Desactivar optimización';

  @override
  String get settingsNotificationsErrors => 'Errores';

  @override
  String get settingsNotificationsErrorsSubtitle =>
      'Cuando una sesión informa un fallo';

  @override
  String get settingsNotificationsJustClose => 'Solo cerrar';

  @override
  String get settingsNotificationsJustCloseDescription =>
      'Salir completamente de la aplicación.';

  @override
  String get settingsNotificationsKeepLive =>
      'Mantener alertas activas por 3 min';

  @override
  String get settingsNotificationsKeepLiveDescription =>
      'Cuando una respuesta ya está en ejecución, mantiene el tiempo real activo brevemente después de salir de la app.';

  @override
  String get settingsNotificationsLocal => 'Local';

  @override
  String get settingsNotificationsMinimizeWhenClose => 'Minimizar al cerrar';

  @override
  String get settingsNotificationsMinimizeWhenCloseDescription =>
      'Minimizar a la barra de tareas/dock y seguir ejecutándose.';

  @override
  String get settingsNotificationsNoCondition =>
      'Si no se selecciona ninguna condición, las alertas se permiten en cualquier contexto.';

  @override
  String get settingsNotificationsNotify => 'Notificar';

  @override
  String get settingsNotificationsNotifyOnlyWhen => 'Notificar solo cuando';

  @override
  String get settingsNotificationsOpenBatterySettings =>
      'Abrir configuración de batería';

  @override
  String get settingsNotificationsPermissions => 'Permisos y preguntas';

  @override
  String get settingsNotificationsPermissionsSubtitle =>
      'Cuando las herramientas solicitan su entrada';

  @override
  String get settingsNotificationsPreview => 'Previsualizar';

  @override
  String get settingsNotificationsRefreshStatus => 'Actualizar estado';

  @override
  String get settingsNotificationsSearchSoundType => 'Buscar tipo de sonido';

  @override
  String get settingsNotificationsSectionDescription =>
      'Controle cuándo aparecen las alertas y cuándo pueden reproducir sonido.';

  @override
  String get settingsNotificationsSectionTitle => 'Notificaciones';

  @override
  String settingsNotificationsSelectedSound(String label) {
    return 'Seleccionado: $label';
  }

  @override
  String get settingsNotificationsServer => 'Servidor';

  @override
  String get settingsNotificationsSound => 'Sonido';

  @override
  String get settingsNotificationsSoundBuiltInAlert => 'Alerta integrada';

  @override
  String get settingsNotificationsSoundBuiltInClick => 'Clic integrado';

  @override
  String get settingsNotificationsSoundOff => 'Desactivado';

  @override
  String get settingsNotificationsSoundOnlyWhen => 'Sonido solo cuando';

  @override
  String get settingsNotificationsSoundPickAudioFile =>
      'Elegir archivo de audio';

  @override
  String get settingsNotificationsSoundPickFromSystem => 'Elegir del sistema';

  @override
  String get settingsNotificationsSoundSystemDefault =>
      'Predeterminado del sistema';

  @override
  String get settingsNotificationsSoundType => 'Tipo de sonido';

  @override
  String get settingsNotificationsSyncInfo =>
      'Algunos interruptores se sincronizan desde /config en el servidor activo.';

  @override
  String get settingsNotificationsSyncInfoLocal =>
      'El servidor actual no expone interruptores de notificación en /config.';

  @override
  String get settingsNotificationsSystemSoundPickerTitle =>
      'Elegir sonido del sistema';

  @override
  String get settingsNotificationsTitle => 'Notificaciones';

  @override
  String get settingsNotificationsWhenClosing => 'Al cerrar la ventana';

  @override
  String get settingsOpenCodeAutoUpdate =>
      'Actualización automática de OpenCode';

  @override
  String get settingsOpenCodeSharingDefault =>
      'Predeterminado de intercambio de OpenCode';

  @override
  String get settingsReadAloudEnabled => 'Leer en voz alta';

  @override
  String get settingsReadAloudEnabledDescription =>
      'Mostrar un botón de lectura en voz alta en los mensajes del asistente.';

  @override
  String get settingsReadAloudPitch => 'Tono';

  @override
  String get settingsReadAloudPitchDescription => 'Ajustar el tono de la voz.';

  @override
  String get settingsReadAloudSectionDescription =>
      'Leer las respuestas del asistente en voz alta. Configure la velocidad, el tono y la voz.';

  @override
  String get settingsReadAloudSectionTitle => 'Síntesis de voz';

  @override
  String get settingsReadAloudSpeed => 'Velocidad';

  @override
  String get settingsReadAloudSpeedDescription =>
      'Ajustar la velocidad de habla.';

  @override
  String get settingsReadAloudVoice => 'Voz';

  @override
  String get settingsReadAloudVoiceHint =>
      'Seleccione una voz para la lectura.';

  @override
  String get settingsSearchAutoUpdateMode =>
      'Buscar modo de actualización automática';

  @override
  String get settingsSearchDefaultAgent => 'Buscar agente predeterminado';

  @override
  String get settingsSearchDefaultModel => 'Buscar modelo predeterminado';

  @override
  String get settingsSearchSharingMode => 'Buscar modo de intercambio';

  @override
  String get settingsSearchSmallModel => 'Buscar modelo pequeño';

  @override
  String get settingsServersActive => 'Activo';

  @override
  String get settingsServersChooseActive => 'Elegir servidor activo';

  @override
  String get settingsServersDefault => 'Predeterminado';

  @override
  String get settingsServersDescription =>
      'Conéctate a OpenCode y administra tus servidores';

  @override
  String get settingsServersTitle => 'Servidores';

  @override
  String get settingsSessionAttentionSize => 'Tamaño de la burbuja';

  @override
  String get settingsSessionAttentionSizeExtraLarge => 'Extra grande';

  @override
  String get settingsSessionAttentionSizeExtraSmall => 'Extra pequeño';

  @override
  String get settingsSessionAttentionSizeLarge => 'Grande';

  @override
  String get settingsSessionAttentionSizeSmall => 'Pequeño';

  @override
  String get settingsSessionAttentionSizeStandard => 'Estándar';

  @override
  String get settingsSetupWizard => 'Asistente de configuración';

  @override
  String get settingsShortcutsDescription =>
      'Encuentra y personaliza los atajos de teclado';

  @override
  String get settingsShortcutsEdit => 'Editar atajo';

  @override
  String get settingsShortcutsKeyboard => 'Atajos de teclado';

  @override
  String get settingsShortcutsReset => 'Restablecer atajo';

  @override
  String get settingsShortcutsSearch => 'Buscar atajos';

  @override
  String get settingsShortcutsTitle => 'Atajos';

  @override
  String get settingsSmallModel => 'Modelo pequeño';

  @override
  String get settingsSmallModelResetExplanation =>
      'Restablecer `small_model` al fallback automático aún requiere editar la configuración fuera de la aplicación porque las actualizaciones de parche `/config` no pueden eliminar claves.';

  @override
  String get settingsSmallModelUnsetExplanation =>
      'El fallback automático de OpenCode está activo porque `small_model` no está definido.';

  @override
  String get settingsSoundPickerNotAvailable =>
      'El selector de sonidos del sistema no está disponible en esta plataforma.';

  @override
  String get settingsSpeechDescription =>
      'Configura entrada de voz, modelos sin conexión y lectura en voz alta';

  @override
  String get settingsSpeechRefreshStatus => 'Actualizar estado';

  @override
  String settingsSpeechSilenceTimeout(String value) {
    return 'Tiempo de silencio: ${value}s';
  }

  @override
  String get settingsSpeechTitle => 'Voz a texto';

  @override
  String get settingsTitle => 'Configuración';

  @override
  String get settingsGroupAlertTypes => 'Tipos de alerta';

  @override
  String get settingsGroupBackgroundBehavior =>
      'Comportamiento en segundo plano';

  @override
  String get settingsGroupChatDisplay => 'Visualización del chat';

  @override
  String get settingsGroupCurrentConnection => 'Conexión actual';

  @override
  String get settingsGroupDataAndSync => 'Datos y sincronización';

  @override
  String get settingsGroupDataReset => 'Datos y restablecimiento';

  @override
  String get settingsGroupDelivery => 'Entrega';

  @override
  String get settingsGroupHelp => 'Ayuda';

  @override
  String get settingsGroupLanguageAndChat => 'Idioma y chat';

  @override
  String get settingsGroupLayoutAndText => 'Diseño y texto';

  @override
  String get settingsGroupOfflineModels => 'Modelos sin conexión';

  @override
  String get settingsGroupOpenCodeDefaults =>
      'Opciones predeterminadas de OpenCode';

  @override
  String get settingsGroupReadAloud => 'Leer en voz alta';

  @override
  String get settingsGroupSavedServers => 'Servidores guardados';

  @override
  String get settingsGroupThemeAndColor => 'Tema y color';

  @override
  String get settingsGroupThisDevice => 'Este dispositivo';

  @override
  String get settingsGroupVersionUpdates => 'Versión y actualizaciones';

  @override
  String get settingsGroupVoiceInput => 'Entrada de voz';

  @override
  String get settingsNavigationGroupExperience => 'Experiencia';

  @override
  String get settingsNavigationGroupInput => 'Entrada';

  @override
  String get settingsNavigationGroupSetup => 'Configuración';

  @override
  String get settingsNavigationGroupSupport => 'Ayuda y diagnóstico';

  @override
  String get settingsNavigationNoResults => 'No se encontraron ajustes';

  @override
  String get settingsNavigationSearchHint => 'Buscar ajustes';

  @override
  String get settingsUsernameClearHint =>
      'Borrar el nombre de usuario de la conversación de OpenCode todavía requiere editar la configuración fuera de la aplicación.';

  @override
  String get settingsUsernameEnterHint =>
      'Ingresa un nombre de usuario para guardar un nombre de conversación personalizado de OpenCode.';

  @override
  String get settingsUsernameResetExplanation =>
      'Restablecer `username` al valor predeterminado del sistema aún requiere editar la configuración fuera de la aplicación porque las actualizaciones de parche `/config` no pueden eliminar claves.';

  @override
  String get settingsUsernameUnsetExplanation =>
      'OpenCode usa el nombre de usuario del sistema porque `username` no está definido.';

  @override
  String get setupDebugBun => 'Bun';

  @override
  String get setupDebugBun2 => 'Bun';

  @override
  String get setupDebugCapturedSetupDetails =>
      'No hay detalles de configuración capturados aún';

  @override
  String get setupDebugCapturedSetupLogs =>
      'Registros de configuración capturados';

  @override
  String get setupDebugClear => 'Limpiar debug de configuración';

  @override
  String get setupDebugClearSetupDebug =>
      'Limpiar depuración de la configuración';

  @override
  String get setupDebugCodeWalkCaptureEnough =>
      'Si CodeWalk no captura suficiente contexto, verifique los registros de OpenCode y los puntos finales de salud directamente:';

  @override
  String get setupDebugCommandPath => 'Ruta del comando';

  @override
  String get setupDebugCommandPath2 => 'Ruta del comando';

  @override
  String get setupDebugCopy => 'Copiar debug de configuración';

  @override
  String get setupDebugCopySetupDebug =>
      'Copiar depuración de la configuración';

  @override
  String get setupDebugCurrentStatus => 'Estado actual';

  @override
  String get setupDebugDiagnosticsLoading =>
      'Los diagnósticos aún se están cargando.';

  @override
  String get setupDebugEnvironment => 'Diagnóstico del entorno';

  @override
  String get setupDebugEnvironmentDiagnostics => 'Diagnóstico del entorno';

  @override
  String get setupDebugFocusedOpenCodeSetup =>
      'Enfocado en la configuración de OpenCode';

  @override
  String get setupDebugInstallDir => 'Directorio de instalación';

  @override
  String get setupDebugInstallDirectory => 'Directorio de instalación';

  @override
  String get setupDebugLatestLocalServer => 'Última salida del servidor local';

  @override
  String get setupDebugLogs => 'Registros de configuración capturados';

  @override
  String get setupDebugManual => 'Solución de problemas manual';

  @override
  String get setupDebugManualTroubleshooting => 'Solución de problemas manual';

  @override
  String get setupDebugNetwork => 'Red';

  @override
  String get setupDebugNetwork2 => 'Red';

  @override
  String get setupDebugNoDetails =>
      'Aún no hay detalles de configuración capturados';

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
      'Depuración de la Configuración de OpenCode';

  @override
  String get setupDebugPlatform => 'Plataforma';

  @override
  String get setupDebugPlatform2 => 'Plataforma';

  @override
  String get setupDebugRunDiagnosticsTry =>
      'Ejecute diagnósticos, intente un método de instalación o intente un flujo de configuración para capturar detalles específicos de la solución de problemas de OpenCode aquí.';

  @override
  String get setupDebugScreenCoversOpenCode =>
      'Esta pantalla solo cubre la instalación de OpenCode, diagnósticos y solución de problemas de configuración local. Use Registros de la App para problemas generales de ejecución de CodeWalk.';

  @override
  String get setupDebugServerOutput => 'Última salida del servidor local';

  @override
  String get setupDebugStatus => 'Estado actual';

  @override
  String setupDebugTimeEntrySource(String source, String time) {
    return '$time - $source';
  }

  @override
  String get setupDebugTimeline => 'Línea de tiempo';

  @override
  String get setupDebugTimeline2 => 'Línea de tiempo';

  @override
  String get setupDebugTitle => 'Enfocado en la configuración de OpenCode';

  @override
  String get setupDebugWSL => 'WSL';

  @override
  String get setupDebugWsl => 'WSL';

  @override
  String get shortcutCloseApp => 'Cerrar pestaña/aplicación';

  @override
  String get shortcutCloseAppDesc =>
      'Cerrar la pestaña de sesión actual cuando esté disponible; de lo contrario, cerrar la aplicación usando el comportamiento de la plataforma';

  @override
  String get shortcutFocusCloseDrawer => 'Enfocar/cerrar panel';

  @override
  String get shortcutFocusCloseDrawerDesc =>
      'Enfocar entrada por defecto, o cerrar panel cuando está abierto';

  @override
  String get shortcutFocusInput => 'Enfocar entrada';

  @override
  String get shortcutFocusInputDesc => 'Mover el foco a la entrada de texto';

  @override
  String get shortcutGroupApplication => 'Aplicación';

  @override
  String get shortcutGroupGeneral => 'General';

  @override
  String get shortcutGroupModelAndAgent => 'Modelo y agente';

  @override
  String get shortcutGroupNavigation => 'Navegación';

  @override
  String get shortcutGroupPrompt => 'Prompter';

  @override
  String get shortcutGroupSession => 'Sesión';

  @override
  String get shortcutNewConversation => 'Nueva conversación';

  @override
  String get shortcutNewConversationDesc => 'Crear una nueva sesión de chat';

  @override
  String get shortcutNextAgent => 'Siguiente agente';

  @override
  String get shortcutNextAgentDesc => 'Ciclar al siguiente agente disponible';

  @override
  String get shortcutNextRecentModel => 'Siguiente modelo reciente';

  @override
  String get shortcutNextRecentModelDesc =>
      'Ciclar a través de los modelos usados recientemente';

  @override
  String get shortcutNextVariant => 'Siguiente variante';

  @override
  String get shortcutNextVariantDesc =>
      'Ciclar a través de las variantes de modelo disponibles';

  @override
  String get shortcutOpenSettings => 'Abrir ajustes';

  @override
  String get shortcutOpenSettingsDesc => 'Abrir la página de ajustes';

  @override
  String get shortcutPreviousAgent => 'Agente anterior';

  @override
  String get shortcutPreviousAgentDesc =>
      'Ciclar al agente anterior disponible';

  @override
  String get shortcutQuickOpenFiles => 'Apertura rápida de archivos';

  @override
  String get shortcutQuickOpenFilesDesc => 'Abrir búsqueda rápida de archivos';

  @override
  String get shortcutQuitApp => 'Salir de la aplicación';

  @override
  String get shortcutQuitAppDesc => 'Forzar la salida de la aplicación';

  @override
  String get shortcutRefreshData => 'Refrescar datos';

  @override
  String get shortcutRefreshDataDesc => 'Refrescar los datos del chat actual';

  @override
  String get shortcutStopResponse => 'Detener respuesta';

  @override
  String get shortcutStopResponseDesc =>
      'Detener respuesta activa (mientras responde)';

  @override
  String get shortcutToggleVoiceInput => 'Alternar entrada de voz';

  @override
  String get shortcutToggleVoiceInputDesc =>
      'Iniciar o detener dictado de voz en el editor';

  @override
  String get shortcutsApply => 'Aplicar';

  @override
  String shortcutsConflictConflict(String conflict) {
    return 'Conflicto con $conflict';
  }

  @override
  String get shortcutsKeyboardShortcuts => 'Atajos de teclado';

  @override
  String get shortcutsReset => 'Restaurar todo';

  @override
  String get shortcutsSearchEditBindings =>
      'Busque, edite combinaciones de teclas y resuelva conflictos antes de guardar.';

  @override
  String shortcutsSetShortcutWidget(String label) {
    return 'Establecer atajo: $label';
  }

  @override
  String get shortcutsTheseBindingsStored =>
      'Estas combinaciones de teclas se almacenan en CodeWalk para la ejecución actual de la aplicación y no editan los atajos de teclado `tui.json` de OpenCode.';

  @override
  String get speechAutoStopSilence =>
      'Tiempo de espera de silencio para parada automática';

  @override
  String get speechChooseRecognitionEngine =>
      'Elija el motor de reconocimiento, el tiempo de espera de silencio y las opciones de modelo.';

  @override
  String speechDesktopOnly(String service) {
    return '$service está disponible solo en escritorio.';
  }

  @override
  String get speechDownload => 'Descargar';

  @override
  String get speechEngine => 'Motor';

  @override
  String get speechInstalledLanguages => 'Idiomas instalados';

  @override
  String get speechListeningStopsAutomatically =>
      'La escucha se detiene automáticamente después de esta cantidad de segundos de silencio.';

  @override
  String get speechMicPermissionDisabled =>
      'El permiso del micrófono está desactivado.';

  @override
  String speechModelFilesIncomplete(String service) {
    return 'Los archivos del modelo de $service están incompletos.';
  }

  @override
  String get speechMoonshine => 'Moonshine';

  @override
  String get speechMoonshineModelsDesktop =>
      'Modelos de Moonshine (escritorio)';

  @override
  String get speechMoonshineStaysDownloadable =>
      'Moonshine permanece disponible para descargar fuera de la aplicación. Elija un modelo para este dispositivo de escritorio y elimínelo más tarde si desea recuperar el espacio.';

  @override
  String get speechNative => 'Nativo';

  @override
  String get speechNativeSTTDisabled =>
      'El STT nativo está desactivado en Linux en esta aplicación. Parakeet es el motor predeterminado para nuevas instalaciones.';

  @override
  String get speechNativeSTTWorks =>
      'En Windows, CodeWalk usa el reconocimiento de voz local en el dispositivo mediante su backend de micrófono WASAPI. El reconocimiento de voz nativo de Windows está deshabilitado por estabilidad.';

  @override
  String get speechNativeStartsFaster =>
      'El nativo se inicia más rápido. Sherpa se ejecuta completamente en el dispositivo con una configuración más pesada y un control de modelo más profundo.';

  @override
  String get speechOpenMicrophoneSettings =>
      'Abrir configuración del micrófono';

  @override
  String get speechOpenSpeechPrivacy => 'Abrir privacidad de voz';

  @override
  String get speechOpenSpeechSettings => 'Abrir configuración de voz';

  @override
  String get speechParakeet => 'Parakeet';

  @override
  String get speechParakeetModelsDesktop => 'Modelos de Parakeet (escritorio)';

  @override
  String get speechParakeetStaysDownloadable =>
      'Parakeet permanece disponible para descargar fuera de la aplicación. Actualmente ofrece un modelo multilingüe optimizado para 25 idiomas europeos.';

  @override
  String get speechPickLanguagePacks =>
      'Elija paquetes de idiomas y descargue/elimine modelos para el reconocimiento local en el dispositivo.';

  @override
  String get speechRemove => 'Eliminar';

  @override
  String speechRuntimeFailed(String service) {
    return 'El entorno de ejecución de $service no pudo inicializarse.';
  }

  @override
  String get speechSelectSherpaAbove =>
      'Seleccione Sherpa arriba para administrar los paquetes de idiomas y descargar modelos.';

  @override
  String get speechSenseVoice => 'SenseVoice';

  @override
  String get speechSenseVoiceModelsDesktop =>
      'Modelos de SenseVoice (escritorio)';

  @override
  String get speechSenseVoiceStaysDownloadable =>
      'SenseVoice permanece disponible para descargar fuera de la aplicación. Es la opción de escritorio más sólida aquí para chino, cantonés, japonés, coreano e inglés.';

  @override
  String get speechSherpa => 'Sherpa';

  @override
  String get speechSherpaExperimentalFail =>
      'Sherpa es experimental y puede fallar en algunos dispositivos. Prefiera Nativo si desea el comportamiento más estable.';

  @override
  String get speechSherpaModelsLinux => 'Modelos de Sherpa (Linux)';

  @override
  String get speechSpeechText => 'Voz a texto';

  @override
  String speechUnavailableOnPlatform(String service) {
    return 'El habla de $service no está disponible en esta plataforma.';
  }

  @override
  String get speechWindowsSetupHint =>
      'La entrada de voz en Windows usa la captura WASAPI de CodeWalk con modelos en el dispositivo. Mantenga habilitado el acceso al micrófono para las aplicaciones de escritorio; los botones de abajo abren la configuración de Windows para solucionar problemas.';

  @override
  String get statusConnected => 'Conectado';

  @override
  String get statusDelayed => 'Retrasado';

  @override
  String get statusFailed => 'Falló';

  @override
  String get statusOffline => 'Desconectado';

  @override
  String get statusOnline => 'Conectado';

  @override
  String get statusReconnecting => 'Reconectando';

  @override
  String get statusStarting => 'Iniciando';

  @override
  String get statusStopped => 'Detenido';

  @override
  String get statusStopping => 'Deteniendo';

  @override
  String get statusSyncDelayed => 'Sincronización retrasada';

  @override
  String get tailscaleNoPeers => 'No se encontraron pares (peers)';

  @override
  String get tailscaleNotSupportedOnPlatform =>
      'Tailscale no es compatible con esta plataforma.';

  @override
  String get tailscaleNotSupportedOnWindows =>
      'Tailscale no es compatible con Windows.';

  @override
  String get tailscalePeerOffline => 'desconectado';

  @override
  String get tailscaleSelectPeer => 'Seleccione un par de Tailscale';

  @override
  String get tailscaleWaitingAdminApproval =>
      'Este nodo de Tailscale está esperando la aprobación del administrador.';

  @override
  String get terminalClose => 'Cerrar terminal';

  @override
  String terminalConnectingTo(String serverName) {
    return 'Conectando al terminal de $serverName...';
  }

  @override
  String terminalConnectionFailed(String error) {
    return 'Conexión de terminal fallida: $error';
  }

  @override
  String get terminalDisconnected => 'Terminal desconectado.';

  @override
  String terminalEmbeddedUnavailable(String serverName) {
    return 'El terminal integrado no está disponible en este entorno todavía. Sigue usando el modo shell del compositor para comandos únicos o abre el terminal desde un entorno de aplicación CodeWalk compatible para $serverName.';
  }

  @override
  String get terminalExtraKeyAlt => 'Tecla Alt';

  @override
  String get terminalExtraKeyArrowDown => 'Flecha abajo';

  @override
  String get terminalExtraKeyArrowLeft => 'Flecha izquierda';

  @override
  String get terminalExtraKeyArrowRight => 'Flecha derecha';

  @override
  String get terminalExtraKeyArrowUp => 'Flecha arriba';

  @override
  String get terminalExtraKeyControl => 'Tecla Control';

  @override
  String get terminalExtraKeyEscape => 'Tecla Escape';

  @override
  String get terminalExtraKeyTab => 'Tecla Tabulador';

  @override
  String get terminalExtraKeys => 'Teclas adicionales del terminal';

  @override
  String get terminalHide => 'Ocultar terminal';

  @override
  String get terminalMaximize => 'Maximizar';

  @override
  String get terminalMinimize => 'Minimizar terminal';

  @override
  String get terminalNotAvailableYet =>
      'El terminal integrado aún no está disponible en este entorno de ejecución.';

  @override
  String get terminalOpen => 'Abrir terminal';

  @override
  String get terminalOpenInfo => 'Abrir información del terminal';

  @override
  String get terminalOpenProjectFirst =>
      'Abra una carpeta de proyecto antes de iniciar el terminal del servidor.';

  @override
  String get terminalOpenToConnect =>
      'Abra el Terminal para conectarse al terminal del proyecto del servidor.';

  @override
  String get terminalReconnect => 'Reconectar terminal';

  @override
  String get terminalRestoreSize => 'Restaurar tamaño';

  @override
  String get terminalSelectServer =>
      'Seleccione un servidor activo antes de abrir el Terminal.';

  @override
  String get terminalSessionClosed => 'Sesión de terminal cerrada.';

  @override
  String get terminalTerminal => 'Terminal';

  @override
  String get terminalTitle => 'Terminal';

  @override
  String get terminalTryAgain => 'Intentar de nuevo';

  @override
  String get toolAwaitingInput => 'Esperando entrada';

  @override
  String get toolEditing => 'Editando';

  @override
  String get toolEditingFiles => 'Editando archivos';

  @override
  String get toolFinding => 'Buscando';

  @override
  String get toolFindingFiles => 'Buscando archivos';

  @override
  String get toolPresentationAwaitingInput => 'Esperando entrada';

  @override
  String get toolPresentationEditing => 'Editando';

  @override
  String get toolPresentationEditingFiles => 'Editando archivos';

  @override
  String get toolPresentationFinding => 'Buscando';

  @override
  String get toolPresentationFindingFiles => 'Buscando archivos';

  @override
  String get toolPresentationReading => 'Leyendo';

  @override
  String get toolPresentationReadingFile => 'Leyendo archivo';

  @override
  String get toolPresentationRunning => 'Ejecutando';

  @override
  String get toolPresentationRunningCommand => 'Ejecutando comando';

  @override
  String toolPresentationRunningTool(String toolName) {
    return 'Ejecutando $toolName';
  }

  @override
  String get toolPresentationSearching => 'Buscando';

  @override
  String get toolPresentationSearchingCode => 'Buscando código';

  @override
  String get toolPresentationSearchingWeb => 'Buscando en la web';

  @override
  String get toolPresentationTool => 'Herramienta';

  @override
  String get toolPresentationUpdatingTaskList => 'Actualizando lista de tareas';

  @override
  String get toolPresentationUpdatingTasks => 'Actualizando tareas';

  @override
  String get toolPresentationWaitingInput => 'Esperando su entrada';

  @override
  String get toolPresentationWriting => 'Escribiendo';

  @override
  String get toolPresentationWritingFile => 'Escribiendo archivo';

  @override
  String get toolReading => 'Leyendo';

  @override
  String get toolReadingFile => 'Leyendo archivo';

  @override
  String get toolRunning => 'Ejecutando';

  @override
  String get toolRunningCommand => 'Ejecutando comando';

  @override
  String get toolRunningTask => 'Ejecutando tarea';

  @override
  String get toolSearching => 'Buscando';

  @override
  String get toolSearchingCode => 'Buscando código';

  @override
  String get toolSearchingWeb => 'Buscando en la web';

  @override
  String get toolUpdatingTaskList => 'Actualizando lista de tareas';

  @override
  String get toolUpdatingTasks => 'Actualizando tareas';

  @override
  String get toolWaitingForInput => 'Esperando su entrada';

  @override
  String get toolWriting => 'Escribiendo';

  @override
  String get toolWritingFile => 'Escribiendo archivo';

  @override
  String get tourBack => 'Volver';

  @override
  String get tourSkip => 'Saltar';

  @override
  String get trayQuit => 'Salir';

  @override
  String get trayShow => 'Mostrar';

  @override
  String get useOAuthCloudflareAccess => 'Usar OAuth (Cloudflare Access)';

  @override
  String get useOAuthCloudflareAccessSubtitle =>
      'Abre el navegador para el OAuth gestionado de Cloudflare Access.';

  @override
  String get useOAuthCloudflareAccessUnsupported =>
      'El OAuth de Cloudflare Access no está disponible en esta plataforma. Use Autenticación Básica en su lugar.';

  @override
  String get useTailscale => 'Usar Tailscale';

  @override
  String get useTailscaleSubtitle =>
      'Enruta el tráfico a través de la red Tailscale sin una VPN del sistema.';

  @override
  String get useTailscaleUnsupported =>
      'Tailscale no es compatible en esta plataforma.';

  @override
  String get utilityTitle => 'Utilidad';

  @override
  String get workspaceBrowseDirs => 'Explorar directorios';

  @override
  String get workspaceChooseFolderOpen =>
      'Elija cualquier carpeta para abrir como contexto del proyecto.';

  @override
  String workspaceCloseProject(String project) {
    return 'Cerrar $project';
  }

  @override
  String get workspaceClosedProjects => 'Proyectos cerrados';

  @override
  String workspaceCurrentDirectory(String path) {
    return 'Directorio actual: $path';
  }

  @override
  String get workspaceFilterDirs => 'Filtrar directorios';

  @override
  String get workspaceOpenFolder => 'Abrir carpeta';

  @override
  String get workspaceOpenProjectFolder => 'Abrir carpeta del proyecto';

  @override
  String get workspaceOpenProjects => 'Proyectos abiertos';

  @override
  String get workspaceProjectDirectory => 'Directorio del proyecto';

  @override
  String get workspaceProjectHint => '/repo/mi-proyecto';

  @override
  String workspaceRemoveFromHistory(String name) {
    return 'Eliminar $name del historial';
  }

  @override
  String get settingsSessionAttentionTitle => 'Atención de sesiones';

  @override
  String get settingsSessionAttentionDescription =>
      'Muestra el estado de las sesiones raíz en una burbuja o panel opcional.';

  @override
  String get settingsSessionAttentionOff => 'Desactivado';

  @override
  String get settingsSessionAttentionBubble => 'Burbuja';

  @override
  String get settingsSessionAttentionPanel => 'Panel';

  @override
  String get settingsSessionAttentionPrivacy =>
      'En Android, activar esto inicia un servicio persistente en primer plano. El texto de las respuestas se almacena cifrado; la TTS en la nube solo envía texto después de pulsar Leer.';

  @override
  String get settingsSessionAttentionUnavailable =>
      'La atención de sesiones no está disponible en esta plataforma.';

  @override
  String get settingsSessionAttentionOpenSettings =>
      'Abrir ajustes de visualización';

  @override
  String get settingsSessionAttentionStop => 'Detener atención de sesiones';

  @override
  String get settingsSessionAttentionThirdPartyTtsWarning =>
      'Al pulsar Leer, el texto de la respuesta puede enviarse al proveedor de TTS externo configurado.';

  @override
  String get workspaceSuggestions => 'Sugerencias';

  @override
  String get sessionTabsGestureHintTitle =>
      'Las pestañas de sesión tienen nuevos controles';

  @override
  String get sessionTabsGestureHintBody =>
      'Haga doble clic o doble toque en una pestaña para cerrarla. Haga clic con el botón derecho o mantenga pulsada una pestaña para abrir las acciones de sesión. Puede desactivar las pestañas en Opciones de visualización.';

  @override
  String get sessionTabsGestureHintAcknowledge => 'Entendido';

  @override
  String get sessionTabsGestureHintDisableTabs => 'Desactivar pestañas';

  @override
  String get sessionTabRenameAction => 'Renombrar sesión';

  @override
  String sessionTabClosedMessage(String title) {
    return 'Pestaña \"$title\" cerrada';
  }

  @override
  String get sessionTabUndo => 'Deshacer';

  @override
  String get sessionTabRestoreFailed => 'No se pudo restaurar la pestaña.';

  @override
  String get sessionTabChangeIconAction => 'Cambiar icono';

  @override
  String get sessionTabIconPickerTitle => 'Elegir icono de pestaña';

  @override
  String get sessionTabIconUseProjectIcon => 'Usar icono del proyecto';

  @override
  String get sessionTabIconApplied => 'Icono de pestaña actualizado.';

  @override
  String get sessionTabIconSaveFailed =>
      'No se pudo guardar el icono de la pestaña.';

  @override
  String get sessionTabIconPresetCode => 'Código';

  @override
  String get sessionTabIconPresetTerminal => 'Terminal';

  @override
  String get sessionTabIconPresetBug => 'Bug';

  @override
  String get sessionTabIconPresetTasks => 'Tareas';

  @override
  String get sessionTabIconPresetLaunch => 'Inicio';

  @override
  String get sessionTabIconPresetIdea => 'Idea';

  @override
  String get sessionTabIconPresetResearch => 'Investigación';

  @override
  String get sessionTabIconPresetDesign => 'Diseño';

  @override
  String get sessionTabIconPresetData => 'Datos';

  @override
  String get sessionTabIconPresetCloud => 'Nube';

  @override
  String get sessionTabIconPresetSecurity => 'Seguridad';

  @override
  String get sessionTabIconPresetTools => 'Herramientas';

  @override
  String get workspaceNoActiveContext => 'Sin contexto activo';

  @override
  String get settingsAppearanceContrastLow => 'Bajo';

  @override
  String get settingsAppearanceContrastStandard => 'Estándar';

  @override
  String get settingsAppearanceContrastMedium => 'Medio';

  @override
  String get settingsAppearanceContrastMediumHigh => 'Medio alto';

  @override
  String get settingsNotificationsSystemSoundsWebUnavailable =>
      'No disponible en la web.';

  @override
  String get settingsNotificationsSystemSoundsAndroid =>
      'Sonidos de notificación de Android del sistema.';

  @override
  String get settingsNotificationsSystemSoundsFreedesktop =>
      'Sonidos de Freedesktop desde /usr/share/sounds/freedesktop/stereo.';

  @override
  String get settingsNotificationsSystemSoundsPlatform =>
      'Compatible donde el sistema operativo expone sonidos del sistema.';

  @override
  String get serversQuickGuideTitle => 'Configuración rápida';

  @override
  String get serversQuickGuideIntro =>
      'CodeWalk es la aplicación. OpenCode es el motor que debe estar en ejecución para que esta conexión funcione.';

  @override
  String get serversQuickGuideStepInstallCli => '1. Instale OpenCode CLI.';

  @override
  String get serversQuickGuideRunPowerShell => '2. Ejecute en PowerShell:';

  @override
  String get serversQuickGuideRunTerminal => '2. Ejecute en su terminal:';

  @override
  String get serversQuickGuideProtectPassword =>
      'Proteger el acceso con contraseña';

  @override
  String get serversQuickGuideServerPassword => 'Contraseña del servidor';

  @override
  String get serversQuickGuideInstallOptions =>
      'Otras opciones oficiales de instalación: script de instalación, npm, bun, pnpm, Homebrew o un binario de GitHub Releases.';

  @override
  String get serversQuickGuideVerifyHint =>
      'Después de iniciar el servidor, confirme que /global/health o /doc responden antes de pegar la URL en CodeWalk.';

  @override
  String get shortcutsPressKeyCombination =>
      'Presione la combinación de teclas ahora';

  @override
  String get settingsProvenanceOpenCodeBacked => 'Respaldado por OpenCode';

  @override
  String get settingsProvenanceCodeWalkLocal => 'Local de CodeWalk';

  @override
  String get settingsProvenanceCodeWalkException => 'Excepción de CodeWalk';

  @override
  String get shortcutsErrorInvalid => 'Atajo inválido';

  @override
  String get shortcutsErrorUnsupportedKey => 'Tecla de atajo no compatible';

  @override
  String shortcutsErrorConflict(String conflict) {
    return 'Entra en conflicto con \"$conflict\"';
  }

  @override
  String get settingsSessionAttentionStopSaveFailed =>
      'La atención de sesión se detuvo, pero el ajuste no se pudo guardar.';

  @override
  String get settingsSessionAttentionEnableFailed =>
      'La atención de sesión no se pudo activar.';

  @override
  String get settingsSessionAttentionSaveFailedStopped =>
      'La atención de sesión no se pudo guardar y se detuvo.';

  @override
  String get settingsSessionAttentionStillRunning =>
      'La atención de sesión sigue en ejecución. Intente detenerla nuevamente.';

  @override
  String get settingsSessionAttentionStopFailed =>
      'La atención de sesión no se pudo detener. Intente de nuevo.';

  @override
  String get settingsSessionAttentionCapabilityUnavailable =>
      'La capacidad de atención de sesión del host no está disponible.';

  @override
  String get settingsServerFallbackProviderName => 'Configurado en el servidor';

  @override
  String get composerStopResponse => 'Detener respuesta';

  @override
  String get composerSendMessageWhileResponding =>
      'Enviar mensaje mientras la respuesta está en ejecución';

  @override
  String get composerSendMessage => 'Enviar mensaje';

  @override
  String get chatTourComposerDescription => 'Escriba su solicitud aquí.';

  @override
  String get chatTourSendDescription => 'Envíe su mensaje aquí.';

  @override
  String get composerAttachmentFallbackName => 'Adjunto';

  @override
  String get composerContextFallbackName => 'Contexto';

  @override
  String get searchableDropdownSearchHint => 'Buscar';

  @override
  String get searchableDropdownEmptyText => 'No se encontraron coincidencias';

  @override
  String get speechApiKeyStorageUnavailable =>
      'El almacenamiento seguro de la clave de API de TTS no está disponible.';

  @override
  String get speechApiKeyRemoved => 'Clave API eliminada.';

  @override
  String get speechApiKeySaved =>
      'Clave API guardada de forma segura en este dispositivo.';

  @override
  String get speechReadAloudTestText =>
      'Esta es una prueba de texto a voz de CodeWalk.';

  @override
  String get speechNativeDisabledWindows =>
      'Deshabilitado en Windows por estabilidad. Use Parakeet u otro motor en el dispositivo mediante la captura WASAPI de CodeWalk.';

  @override
  String get speechNativeUnavailableLinux =>
      'No disponible en Linux. Use Parakeet para la entrada de voz.';

  @override
  String get speechNotAvailableOnPlatform =>
      'No disponible en esta plataforma.';

  @override
  String get speechSherpaUnavailableAndroid =>
      'No disponible en compilaciones de Android optimizadas para un tamaño de APK reducido.';

  @override
  String get speechMoonshineDesktopOnlyHint =>
      'Disponible solo en escritorio. Android se mantiene solo con el nativo.';

  @override
  String get speechParakeetDesktopOnlyHint =>
      'Disponible solo en escritorio. Usa reconocimiento multilingüe sin conexión.';

  @override
  String get speechSenseVoiceDesktopOnlyHint =>
      'Disponible solo en escritorio. Más fuerte para chino, cantonés, japonés, coreano e inglés.';

  @override
  String get speechNativeSubtitle => 'Inicio más simple y rápido.';

  @override
  String get speechSherpaSubtitle =>
      'Más pesado, experimental y propenso a errores. A menudo más preciso con modelos descargados.';

  @override
  String get speechMoonshineSubtitle =>
      'Ruta experimental solo de escritorio que usa reconocimiento sin conexión de sherpa_onnx y modelos descargables.';

  @override
  String get speechParakeetSubtitle =>
      'Ruta sin conexión solo de escritorio del transducer NeMo con un modelo multilingüe descargable.';

  @override
  String get speechSenseVoiceSubtitle =>
      'Ruta sin conexión solo de escritorio afinada para chino, cantonés, japonés, coreano e inglés.';

  @override
  String get speechMoonshineModel => 'Modelo Moonshine';

  @override
  String get speechSherpaLanguage => 'Idioma de Sherpa';

  @override
  String get speechSearchSherpaLanguage => 'Buscar idioma de Sherpa';

  @override
  String get speechNoLanguagePacksFound =>
      'No se encontraron paquetes de idioma';

  @override
  String get speechTextToSpeechProvider => 'Proveedor de texto a voz';

  @override
  String get speechProviderSystemNative => 'Sistema / Nativo';

  @override
  String get speechProviderEdgeExperimental =>
      'Microsoft Edge Speech (experimental)';

  @override
  String get speechProviderOpenAiCompatible => 'Compatible con OpenAI';

  @override
  String get speechEdgeExperimentalTitle =>
      'Microsoft Edge Speech es experimental';

  @override
  String get speechEdgeExperimentalDescription =>
      'Usa el servicio no oficial Edge Read Aloud directamente desde este dispositivo. El texto de los mensajes se envía a Microsoft cuando usa la lectura en voz alta, y el servicio puede dejar de funcionar si Microsoft cambia el protocolo privado.';

  @override
  String get speechEdgeVoice => 'Voz de Edge';

  @override
  String get speechEdgeVoiceListUnavailable =>
      'Usando la voz predeterminada de Edge. La lista de voces no se pudo cargar en este momento.';

  @override
  String get speechEdgeVoicesLoaded =>
      'Cargadas desde las voces de Microsoft Edge Speech.';

  @override
  String get speechCloudTtsPrivacy => 'Privacidad de TTS en la nube';

  @override
  String get speechCloudTtsPrivacyDescription =>
      'El TTS en la nube envía el texto del mensaje del asistente seleccionado al proveedor configurado. Las claves API se almacenan en el almacenamiento seguro de este dispositivo.';

  @override
  String get speechBaseUrl => 'URL base';

  @override
  String get speechApiKey => 'Clave API';

  @override
  String get speechApiKeySavedHelper =>
      'Hay una clave guardada. Ingrese un valor nuevo para reemplazarla, o guarde un valor vacío para eliminarla.';

  @override
  String get speechNoApiKeySaved => 'No hay clave API guardada.';

  @override
  String get speechSaveApiKey => 'Guardar clave API';

  @override
  String get speechModel => 'Modelo';

  @override
  String get speechPitchNotSupported =>
      'El tono no es compatible con el TTS compatible con OpenAI y está oculto para este proveedor.';

  @override
  String get speechTestVoice => 'Probar voz';

  @override
  String get dialogMoonshineVoiceSetupDescription =>
      'Moonshine se ejecuta en el dispositivo mediante sherpa_onnx. Elija un modelo una vez y descárguelo solo para este dispositivo de escritorio.';

  @override
  String get dialogParakeetVoiceSetupDescription =>
      'Parakeet se ejecuta en el dispositivo mediante el reconocimiento sin conexión de sherpa_onnx. Descárguelo una vez para este dispositivo de escritorio para habilitar el STT multilingüe.';

  @override
  String get dialogSenseVoiceSetupDescription =>
      'SenseVoice se ejecuta en el dispositivo mediante el reconocimiento sin conexión de sherpa_onnx. Es más fuerte para chino, cantonés, japonés, coreano e inglés.';

  @override
  String get dialogSherpaVoiceSetupDescription =>
      'La entrada de voz de Sherpa requiere un modelo de voz en el dispositivo. Seleccione su idioma y descárguelo una vez (~147 MB).';

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
    return 'Modelo faltante ($modelId)';
  }

  @override
  String speechModelSizeMb(String sizeMb) {
    return '~$sizeMb MB';
  }

  @override
  String speechSystemDefaultLanguage(String language) {
    return 'Predeterminado del sistema ($language)';
  }

  @override
  String speechModelListLoadFailed(String error, String service) {
    return 'Error al cargar la lista de modelos de $service: $error';
  }

  @override
  String speechDownloadFailed(String error) {
    return 'Error en la descarga: $error';
  }

  @override
  String speechFailedToRemoveModel(String error) {
    return 'Error al eliminar el modelo: $error';
  }

  @override
  String speechBaseUrlExample(String url) {
    return 'Ejemplo: $url';
  }

  @override
  String speechModelDefaultHelper(String model) {
    return 'Predeterminado: $model';
  }

  @override
  String get notificationPermissionOrQuestionNeedsInput =>
      'Un permiso o una pregunta de herramienta necesita su intervención.';

  @override
  String get notificationPermissionNeedsInput =>
      'Un permiso de herramienta necesita su intervención.';

  @override
  String get notificationQuestionNeedsInput =>
      'Una pregunta de herramienta necesita su intervención.';

  @override
  String get notificationSessionError => 'Una sesión reportó un error.';

  @override
  String get notificationChannelErrors => 'Errores de CodeWalk';

  @override
  String get notificationChannelErrorsDescription =>
      'Alertas de error de CodeWalk';

  @override
  String get notificationChannelPermissions => 'Permisos de CodeWalk';

  @override
  String get notificationChannelPermissionsDescription =>
      'Alertas de acción requerida de CodeWalk';

  @override
  String get notificationChannelAgent => 'Agente de CodeWalk';

  @override
  String get notificationChannelAgentDescription =>
      'Alertas de finalización de agente de CodeWalk';

  @override
  String get notificationActionOpen => 'Abrir';

  @override
  String get foregroundMonitorNotificationBody =>
      'Las alertas confiables en segundo plano están activas';

  @override
  String get foregroundMonitorNotificationTitle =>
      'Monitoreo en segundo plano activo';

  @override
  String get foregroundMonitorNotificationOneSession =>
      'Monitoreando una sesión';

  @override
  String foregroundMonitorNotificationSessionCount(int count) {
    return 'Monitoreando $count sesiones';
  }

  @override
  String sessionAttentionSemanticLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sesiones necesitan atención',
      one: '1 sesión necesita atención',
    );
    return '$_temp0';
  }

  @override
  String get sessionAttentionOverlayPermissionRequired =>
      'Se requiere el permiso de mostrar sobre otras aplicaciones.';

  @override
  String get sessionAttentionIosInAppOnly =>
      'La atención de sesión solo está disponible dentro de CodeWalk.';

  @override
  String get sessionAttentionOverlayPermissionGrantPrompt =>
      'Otorgue el permiso de mostrar sobre otras aplicaciones y vuelva a intentarlo.';

  @override
  String get sessionAttentionAndroidStartFailed =>
      'El servicio de atención de sesión de Android no se pudo iniciar.';

  @override
  String chatMessageTruncatedChars(int count, String reason) {
    return '[truncado $count caracteres] $reason';
  }

  @override
  String get chatMessageJustNow => 'Justo ahora';

  @override
  String chatMessageMinutesAgo(int count) {
    return 'Hace ${count}m';
  }

  @override
  String chatMessageHoursAgo(int count) {
    return 'Hace ${count}h';
  }

  @override
  String chatMessageDaysAgo(int count) {
    return 'Hace ${count}d';
  }

  @override
  String chatMessageDateTime(int day, int hour, int minute, int month) {
    return '$month/$day $hour:$minute';
  }

  @override
  String get chatMessageYourMessage => 'Su mensaje';

  @override
  String get chatMessageAssistantMessage => 'Mensaje del asistente';

  @override
  String chatMessageStepStarted(int step) {
    return 'Paso iniciado #$step';
  }

  @override
  String chatMessageStepStartedWithSnapshot(String snapshot, int step) {
    return 'Paso iniciado #$step: $snapshot';
  }

  @override
  String chatMessageStepFinished(
    String cost,
    String reason,
    int step,
    int tokens,
  ) {
    return 'Paso finalizado #$step: $reason • tokens $tokens • \$$cost';
  }

  @override
  String chatMessagePatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parches',
      one: '1 parche',
    );
    return '$_temp0';
  }

  @override
  String get chatMessageToolRun => 'Ejecución de herramienta';

  @override
  String get chatMessageToolExecution => 'Ejecución de herramienta';

  @override
  String chatMessageToolChainMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count más',
      one: '+1 más',
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
      other: '$count necesitan atención',
      one: '1 necesita atención',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolDoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count completados',
      one: '1 completado',
    );
    return '$_temp0';
  }

  @override
  String get chatMessageToolCallsTitle => 'Llamadas a herramientas';

  @override
  String get chatMessageDiffPreviewTruncated =>
      'Vista previa del diff truncada por estabilidad de la aplicación.';

  @override
  String get chatMessageLargeMessageTruncated =>
      'Vista previa de mensaje grande truncada por estabilidad de la aplicación.';

  @override
  String get chatMessageInvalidLinkFormat => 'Formato de enlace inválido';

  @override
  String get chatMessageUnableToOpenLink => 'No se puede abrir el enlace';

  @override
  String sessionTodoInProgressCompact(int current, int total) {
    return '$current/$total en progreso';
  }

  @override
  String sessionTodoTaskProgress(String content, int index, int total) {
    return 'Tarea $index/$total $content';
  }

  @override
  String sessionTodoDoneCompact(int count, int total) {
    return '$count/$total completados';
  }

  @override
  String sessionTodoCompletedCount(int count, int total) {
    return 'Tareas $count/$total completadas';
  }

  @override
  String sessionTodoTasksCount(int count) {
    return 'Tareas ($count)';
  }

  @override
  String questionStepOfReview(int current, int total) {
    return 'Paso $current de $total - Revisión';
  }

  @override
  String questionStepOfQuestion(int current, int total) {
    return 'Paso $current de $total - Pregunta';
  }

  @override
  String get questionCustomAnswer => 'Respuesta personalizada';

  @override
  String get questionSubmitAnswers => 'Enviar respuestas';

  @override
  String get questionReviewAnswers => 'Revisar respuestas';

  @override
  String permissionRequestTitle(String permission) {
    return 'Solicitud de permiso: $permission';
  }

  @override
  String get sessionTitleCannotBeEmpty => 'El título no puede estar vacío';

  @override
  String get filesFailedToLoad => 'No se pudieron cargar los archivos';

  @override
  String get filesFailedToSearch => 'No se pudo buscar en los archivos';

  @override
  String get filesNoOpenFilesHint =>
      'Aún no hay archivos abiertos. Escriba para buscar.';

  @override
  String get filesNoContentMatches =>
      'No se encontraron coincidencias de contenido';

  @override
  String filesOpenFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos abiertos',
      one: '1 archivo abierto',
    );
    return '$_temp0';
  }

  @override
  String filesLinesSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count líneas seleccionadas',
      one: '1 línea seleccionada',
    );
    return '$_temp0';
  }

  @override
  String get filesDraftTooLargeToSave =>
      'El borrador es demasiado grande para guardarlo desde el editor.';

  @override
  String get filesSaveChangesBeforeClose =>
      'Guarde los cambios antes de cerrar este archivo.';

  @override
  String get filesSaveChangesBeforePathChange =>
      'Guarde los cambios antes de cambiar esta ruta.';

  @override
  String get filesWaitForSaveBeforePathChange =>
      'Espere a que termine el guardado del archivo antes de cambiar esta ruta.';

  @override
  String get filesWaitForFileOperation =>
      'Espere a que termine la operación de archivos.';

  @override
  String get filesLargeFileReadOnly =>
      'Los archivos grandes se abren en modo de solo lectura para mantener la edición fluida.';

  @override
  String get filesCheckingWriteSupport =>
      'Comprobando soporte de escritura de archivos...';

  @override
  String get filesActiveProjectRequired =>
      'Las operaciones de archivos requieren un directorio de proyecto activo.';

  @override
  String get filesReloadSkippedUnsavedChanges =>
      'Hay cambios sin guardar; se omitió la recarga.';

  @override
  String get filesFailedToLoadContent =>
      'No se pudo cargar el contenido del archivo';

  @override
  String get filesFileSaved => 'Archivo guardado.';

  @override
  String get filesParentNotDirectory =>
      'El directorio principal no es un directorio.';

  @override
  String get filesMalformedResponse =>
      'La operación de archivos devolvió una respuesta no válida.';

  @override
  String get filesShellCommandDidNotComplete =>
      'El comando de shell de la operación de archivos no se completó.';

  @override
  String get filesShellCommandNoResult =>
      'El comando de shell de la operación de archivos no devolvió ningún resultado.';

  @override
  String get filesShellCommandTruncated =>
      'El comando de shell de la operación de archivos fue truncado por el servidor.';

  @override
  String get filesShellCommandSyntaxError =>
      'El comando de shell de la operación de archivos falló con un error de sintaxis.';

  @override
  String get filesShellUtilityNotFound =>
      'No se encontró una utilidad de shell requerida.';

  @override
  String get filesShellCommandFailed =>
      'El comando de shell de la operación de archivos falló antes de devolver un resultado.';

  @override
  String get attachmentSaveTitle => 'Guardar archivo adjunto';

  @override
  String get attachmentBrowserSandboxLocalFile =>
      'El sandbox del navegador impide abrir archivos adjuntos locales file:// directamente.';

  @override
  String get attachmentLocalPathBrowserBlocked =>
      'Este archivo adjunto apunta a una ruta local que no se puede abrir desde el navegador.';

  @override
  String terminalConnectedTo(String directory, String serverName) {
    return 'Conectado a $serverName en $directory';
  }

  @override
  String get terminalTransportUnavailable =>
      'El transporte de terminal no está disponible.';

  @override
  String get chatSlashCommandNew => 'Crear una nueva sesión de chat';

  @override
  String get chatSlashCommandModels => 'Abrir selector de modelos';

  @override
  String get chatSlashCommandSessions => 'Abrir lista de conversaciones';

  @override
  String get chatSlashCommandAgent => 'Abrir selector de agente';

  @override
  String get chatSlashCommandOpen => 'Acción rápida para abrir archivos';

  @override
  String get chatSlashCommandHelp => 'Mostrar ayuda de comandos';

  @override
  String get chatSlashCommandCompact =>
      'Compactar el contexto de la sesión actual';

  @override
  String get chatSlashCommandThinking => 'Alternar burbujas de pensamiento';

  @override
  String get chatSlashCommandUndo =>
      'Deshacer el último turno visible del usuario';

  @override
  String get chatSlashCommandRedo => 'Rehacer el último turno deshecho';

  @override
  String chatSessionSubConversationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subconversaciones',
      one: '1 subconversación',
    );
    return '$_temp0';
  }

  @override
  String chatMessageWeeksAgo(int count) {
    return 'Hace ${count}w';
  }

  @override
  String chatMessageShortDate(int day, int month) {
    return '$month/$day';
  }

  @override
  String get chatProviderErrorLoadSessionStatus =>
      'No se pudo cargar el estado de la sesión';

  @override
  String get chatProviderErrorLoadSessionDetails =>
      'No se pudieron cargar algunos detalles de la sesión';

  @override
  String chatProviderErrorLoadSessionList(String error) {
    return 'No se pudo cargar la lista de sesiones: $error';
  }

  @override
  String get chatProviderErrorCreateSession => 'No se pudo crear la sesión';

  @override
  String get chatProviderErrorSelectProviderModelBeforeSend =>
      'Seleccione un proveedor conectado o un modelo gratuito de OpenCode antes de enviar';

  @override
  String get chatProviderErrorStartMessageSend =>
      'No se pudo iniciar el envío del mensaje';

  @override
  String get chatProviderErrorStopUnavailable =>
      'Detener no está disponible para la sesión actual';

  @override
  String get chatProviderErrorWaitForResponseFinish =>
      'Espere a que termine la respuesta actual antes de compactar';

  @override
  String get chatProviderErrorCompactUnavailable =>
      'La compactación de contexto no está disponible para la sesión actual';

  @override
  String get chatProviderErrorSelectModelBeforeCompact =>
      'Seleccione un modelo antes de compactar el contexto';

  @override
  String get chatProviderErrorCompactSessionContext =>
      'No se pudo compactar el contexto de la sesión';

  @override
  String get chatProviderErrorNetwork =>
      'Falló la conexión de red. Verifique la configuración de red';

  @override
  String get chatProviderErrorServer =>
      'Error del servidor. Inténtelo de nuevo más tarde';

  @override
  String get chatProviderErrorNotFound => 'Recurso no encontrado';

  @override
  String get chatProviderErrorInvalidInput =>
      'Parámetros de entrada no válidos';

  @override
  String get chatProviderErrorUnknown =>
      'Error desconocido. Inténtelo de nuevo más tarde';

  @override
  String get chatProviderErrorSessionFallback => 'Error de sesión';

  @override
  String get projectProviderErrorNoProjectContext =>
      'No hay contexto de proyecto disponible desde el servidor';

  @override
  String projectProviderErrorInitializeFailed(String error) {
    return 'No se pudo inicializar el contexto del proyecto: $error';
  }

  @override
  String get projectProviderErrorSwitchProjectNotFound =>
      'No se pudo cambiar de proyecto: proyecto no encontrado';

  @override
  String get projectProviderErrorSwitchDirectoryEmpty =>
      'No se pudo cambiar de proyecto: el directorio está vacío';

  @override
  String get projectProviderErrorAtLeastOneContext =>
      'Al menos un contexto debe permanecer abierto';

  @override
  String get projectProviderErrorReopenProjectNotFound =>
      'No se pudo reabrir el proyecto: proyecto no encontrado';

  @override
  String get projectProviderErrorOnlyClosedArchivable =>
      'Solo los proyectos cerrados se pueden archivar';

  @override
  String get projectProviderErrorArchiveProjectNotFound =>
      'No se pudo archivar el proyecto: proyecto no encontrado';

  @override
  String get projectProviderErrorArchiveProjectPathInvalid =>
      'No se pudo archivar el proyecto: la ruta del proyecto no es válida';

  @override
  String projectProviderErrorLoadWorkspaces(String error) {
    return 'No se pudieron cargar los espacios de trabajo: $error';
  }

  @override
  String get projectProviderErrorWorkspaceNameEmpty =>
      'El nombre del espacio de trabajo no puede estar vacío';

  @override
  String projectProviderErrorCreateWorkspace(String error) {
    return 'No se pudo crear el espacio de trabajo: $error';
  }

  @override
  String projectProviderErrorResetWorkspace(String error) {
    return 'No se pudo restablecer el espacio de trabajo: $error';
  }

  @override
  String projectProviderErrorDeleteWorkspace(String error) {
    return 'No se pudo eliminar el espacio de trabajo: $error';
  }

  @override
  String get projectProviderErrorDirectoryEmpty =>
      'El directorio no puede estar vacío';

  @override
  String projectProviderErrorListDirectories(String error) {
    return 'No se pudieron listar los directorios: $error';
  }

  @override
  String projectProviderErrorValidateDirectory(String error) {
    return 'No se pudo validar el directorio: $error';
  }

  @override
  String get projectProviderErrorPathEmpty => 'La ruta no puede estar vacía';

  @override
  String projectProviderErrorListFiles(String error) {
    return 'No se pudieron listar los archivos: $error';
  }

  @override
  String projectProviderErrorSearchFiles(String error) {
    return 'No se pudo buscar en los archivos: $error';
  }

  @override
  String projectProviderErrorContentSearchUnavailable(String error) {
    return 'Búsqueda de contenido no disponible: $error';
  }

  @override
  String projectProviderErrorSearchSymbols(String error) {
    return 'No se pudieron buscar los símbolos: $error';
  }

  @override
  String projectProviderErrorReadFile(String error) {
    return 'No se pudo leer el archivo: $error';
  }

  @override
  String projectProviderErrorLoadProjectList(String error) {
    return 'No se pudo cargar la lista de proyectos: $error';
  }

  @override
  String get workspaceProjectRemovedFromHistory =>
      'Proyecto eliminado del historial';

  @override
  String workspaceProjectContextOpened(String directory) {
    return 'Contexto del proyecto abierto: $directory';
  }

  @override
  String workspaceFailedToOpenProjectContext(String directory) {
    return 'No se pudo abrir el contexto del proyecto: $directory';
  }

  @override
  String get chatAbortNotice => '¿Qué desea hacer de manera diferente?';

  @override
  String sessionTitleToday(String date, String time) {
    return 'Hoy $time ($date)';
  }

  @override
  String sessionTitleYesterday(String date, String time) {
    return 'Ayer $time ($date)';
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
  String get sessionWeekdayMon => 'lun';

  @override
  String get sessionWeekdayTue => 'mar';

  @override
  String get sessionWeekdayWed => 'mié';

  @override
  String get sessionWeekdayThu => 'jue';

  @override
  String get sessionWeekdayFri => 'vie';

  @override
  String get sessionWeekdaySat => 'sáb';

  @override
  String get sessionWeekdaySun => 'dom';

  @override
  String get forwardTimeNow => 'ahora';

  @override
  String forwardTimeMinutes(int count) {
    return '${count}m';
  }

  @override
  String forwardTimeHours(int count) {
    return '${count}h';
  }

  @override
  String forwardTimeDays(int count) {
    return '${count}d';
  }

  @override
  String forwardTimeWeeks(int count) {
    return '${count}w';
  }

  @override
  String get settingsBehaviorConfigFieldDefaultModel => 'modelo predeterminado';

  @override
  String get settingsBehaviorConfigFieldDefaultAgent => 'agente predeterminado';

  @override
  String get settingsBehaviorConfigFieldSmallModel => 'modelo pequeño';

  @override
  String get settingsBehaviorConfigFieldAutoUpdateMode =>
      'modo de actualización automática';

  @override
  String get settingsBehaviorConfigFieldSnapshotSetting =>
      'configuración de instantáneas';

  @override
  String get settingsBehaviorConfigFieldConversationUsername =>
      'nombre de usuario de conversación';

  @override
  String get settingsBehaviorConfigFieldSharingDefault =>
      'configuración predeterminada de uso compartido';

  @override
  String get speechMicNoInputDevice =>
      'No hay ningún dispositivo de entrada de micrófono disponible.';

  @override
  String get speechMicDeviceBusy =>
      'Otra aplicación está usando actualmente el micrófono predeterminado.';

  @override
  String get speechMicUnsupportedFormat =>
      'El formato predeterminado del micrófono no es compatible.';

  @override
  String get speechMicSpeechPrivacy =>
      'Es posible que los servicios de voz de Windows estén deshabilitados (privacidad de voz, reconocimiento de voz en línea o paquetes de idioma).';

  @override
  String get speechMicBackendUnavailable =>
      'El backend de micrófono de Windows no está disponible en esta compilación.';

  @override
  String speechEngineFallbackNotice(String fallback, String reason) {
    return 'El motor de STT seleccionado no está disponible ($reason). Se usará $fallback en su lugar.';
  }

  @override
  String get oauthFlowSecureStorageUnavailable =>
      'El almacenamiento seguro de credenciales no está disponible para OAuth.';

  @override
  String get oauthFlowUnexpectedError =>
      'El flujo de OAuth falló inesperadamente. Inténtelo de nuevo.';

  @override
  String get oauthFlowNoEndpointsDiscovered =>
      'No se descubrieron puntos finales de OAuth. Habilite Managed OAuth en Cloudflare Dashboard → Access → Applications → [esta aplicación].';

  @override
  String get oauthFlowTokenResponseMissingAccessToken =>
      'La respuesta de token de OAuth no incluyó un token de acceso.';

  @override
  String get oauthFlowProfileChanged =>
      'El perfil del servidor cambió antes de que OAuth pudiera completarse.';

  @override
  String get oauthFlowMetadataMissingEndpoints =>
      'Los metadatos de OAuth no incluyen los puntos finales de autorización/token.';

  @override
  String get oauthFlowCallbackNotCompleted =>
      'La devolución de llamada de autorización no se completó';

  @override
  String get oauthFlowProviderDeclined =>
      'El servidor de autorización rechazó la solicitud de OAuth. Inténtelo de nuevo.';

  @override
  String get oauthFlowCallbackValidationFailed =>
      'La validación de la devolución de llamada de OAuth falló. Inténtelo de nuevo.';

  @override
  String get oauthFlowCallbackServerStartFailed =>
      'No se pudo iniciar el servidor local de devolución de llamada de OAuth.';

  @override
  String get oauthFlowSignInCanceled =>
      'El inicio de sesión con OAuth se canceló.';

  @override
  String get oauthFlowBrowserOpenFailed =>
      'No se pudo abrir el navegador del sistema para iniciar sesión con OAuth.';

  @override
  String get oauthFlowCallbackTimeout =>
      'Ninguna devolución de llamada de autorización llegó a la aplicación dentro de los 5 minutos. Se esperaba que el navegador redirigiera a la dirección de devolución de llamada local después del consentimiento. Si el navegador mostró un error de conexión en su lugar, este dispositivo o red bloquea las redirecciones de bucle local (loopback).';

  @override
  String oauthFlowTokenExchangeTransientFailure(int maxAttempts) {
    return 'El intercambio de tokens falló después de $maxAttempts intentos debido a un problema temporal de red. Inténtelo de nuevo.';
  }

  @override
  String oauthFlowTokenExchangeHttpFailure(int statusCode) {
    return 'El intercambio de tokens falló (HTTP $statusCode). Inténtelo de nuevo.';
  }

  @override
  String get oauthFlowTokenExchangeUnexpectedFailure =>
      'El intercambio de tokens falló inesperadamente. Inténtelo de nuevo.';

  @override
  String get oauthFlowTokenExchangeIncomplete =>
      'El intercambio de tokens no se completó después de enviar el código de autorización. Inicie sesión con OAuth nuevamente.';

  @override
  String get speechReadAloudFailed => 'La conversión de texto a voz falló.';

  @override
  String get speechReadAloudNoText => 'No hay texto para leer en voz alta.';

  @override
  String get speechEdgeTextTooLong =>
      'Microsoft Edge Speech puede leer hasta 4096 bytes a la vez.';

  @override
  String get speechEdgeMalformedAudio =>
      'Microsoft Edge Speech devolvió datos de audio no válidos.';

  @override
  String get speechEdgeUnsupportedAudio =>
      'Microsoft Edge Speech devolvió datos de audio no compatibles.';

  @override
  String get speechEdgeUnsupportedFrame =>
      'Microsoft Edge Speech devolvió un marco websocket no compatible.';

  @override
  String get speechEdgeSynthesisInterrupted =>
      'Microsoft Edge Speech terminó antes de completar la síntesis.';

  @override
  String get speechEdgeEmptyAudio =>
      'Microsoft Edge Speech devolvió una respuesta de audio vacía.';

  @override
  String get speechEdgeTimedOut =>
      'Microsoft Edge Speech agotó el tiempo de espera.';

  @override
  String get speechEdgeUnreachable =>
      'No se pudo acceder a Microsoft Edge Speech.';

  @override
  String get speechApiKeyMissing =>
      'Agregue una clave de API en Configuración > Speech para usar este proveedor de TTS.';

  @override
  String get speechProviderEmptyAudio =>
      'El proveedor de TTS devolvió una respuesta de audio vacía.';

  @override
  String get speechProviderRequestRejected =>
      'El proveedor de TTS rechazó la solicitud de voz.';

  @override
  String get speechApiKeyRejected =>
      'El proveedor rechazó la clave de API de TTS.';

  @override
  String get speechProviderQuotaRateLimit =>
      'El proveedor de TTS informó un límite de cuota o de frecuencia.';

  @override
  String get speechProviderTemporarilyUnavailable =>
      'El proveedor de TTS no está disponible temporalmente.';

  @override
  String get speechProviderUnreachable =>
      'No se pudo acceder al proveedor de TTS.';

  @override
  String appProviderErrorFailedToStartProcess(String tool) {
    return 'No se pudo iniciar el proceso de $tool.';
  }

  @override
  String appProviderErrorToolNotAvailable(String runtime, String tool) {
    return '$tool no está disponible. Instale $runtime primero.';
  }

  @override
  String appProviderErrorToolInstallFailed(int exitCode, String tool) {
    return 'La instalación de $tool falló con el código de salida $exitCode.';
  }

  @override
  String appProviderErrorBunBootstrapFailed(int exitCode) {
    return 'El arranque de Bun falló con el código de salida $exitCode.';
  }

  @override
  String get appProviderErrorInstalledButNotFoundInPath =>
      'La instalación de OpenCode finalizó, pero no se encontró el comando en el PATH.';

  @override
  String get appProviderErrorInstalledButPathNotResolved =>
      'La instalación de OpenCode finalizó, pero no se pudo resolver la ruta del comando.';

  @override
  String appProviderErrorConfiguredCommandNotFound(String tool) {
    return 'No se encontró el comando configurado y $tool no está en el PATH.';
  }

  @override
  String get appProviderErrorConfiguredCommandPathMissing =>
      'La ruta del comando configurado no existe.';

  @override
  String get appProviderErrorConfiguredCommandVersionCheckFailed =>
      'El comando configurado existe, pero falló la comprobación de versión.';

  @override
  String get appProviderErrorConfiguredCommandExecutionFailed =>
      'No se pudo ejecutar el comando configurado.';

  @override
  String get appProviderWslCheckWindowsOnly =>
      'La comprobación de WSL solo aplica a Windows.';

  @override
  String get appProviderDesktopBuildRequired =>
      'Use una compilación de escritorio para configurar un servidor local gestionado.';

  @override
  String get appProviderKnownInstallationDirectoryDetected =>
      'Detectado desde un directorio de instalación conocido.';

  @override
  String appProviderKnownInstallationPathRefreshHint(String appName) {
    return 'Detectado desde un directorio de instalación conocido. Es posible que el PATH deba actualizarse; reabra $appName si una instalación reciente aún no se detecta.';
  }

  @override
  String get appProviderErrorReleaseMetadataFetchFailed =>
      'No se pudieron obtener los metadatos de la última versión desde GitHub.';

  @override
  String get appProviderErrorReleaseAssetListMissing =>
      'Los metadatos de la última versión no incluían la lista de recursos.';

  @override
  String get appProviderErrorNoCompatibleAsset =>
      'No se encontró ningún recurso binario compatible de OpenCode.';

  @override
  String get appProviderErrorDownloadAssetFailed =>
      'No se pudo descargar el recurso de OpenCode seleccionado.';

  @override
  String get appProviderErrorChecksumVerificationFailed =>
      'Falló la verificación de la suma de comprobación del recurso descargado.';

  @override
  String get appProviderErrorExtractArchiveFailed =>
      'No se pudo extraer el archivo binario de OpenCode.';

  @override
  String appProviderErrorExecutableNotFound(String tool) {
    return 'No se encontró el ejecutable de $tool en los archivos extraídos.';
  }

  @override
  String get chatNoResponseFromServer =>
      'No hubo respuesta del servidor. Vuelva a intentarlo.';

  @override
  String get chatNoResponseFromModel =>
      'No hubo respuesta del modelo. Vuelva a intentarlo.';

  @override
  String get speechJobCancelled => 'El trabajo de voz se canceló.';

  @override
  String get speechEdgeCancelled => 'Microsoft Edge Speech se canceló.';

  @override
  String get sessionAttentionKindActive => 'Activo';

  @override
  String get sessionAttentionKindReceiving => 'Recibiendo';

  @override
  String get sessionAttentionKindDelayed => 'Retrasado';

  @override
  String get sessionAttentionKindCompleted => 'Completado';

  @override
  String get sessionAttentionKindPendingInteraction => 'Interacción pendiente';

  @override
  String get sessionAttentionKindError => 'Error';

  @override
  String get sessionAttentionPauseCellularDataSaver =>
      'El ahorro de datos móviles está activo';

  @override
  String get sessionAttentionPauseOauthReopenRequired =>
      'Se requiere iniciar sesión con OAuth';

  @override
  String get sessionAttentionPauseTailscaleReopenRequired =>
      'Se requiere conexión con Tailscale';

  @override
  String get sessionAttentionPauseOffline => 'Desconectado';

  @override
  String get sessionAttentionPausePermissionRevoked => 'Permiso revocado';

  @override
  String get sessionAttentionPauseServiceStopped => 'Servicio detenido';

  @override
  String get sessionAttentionPauseHostUnavailable => 'Host no disponible';

  @override
  String get errorRequestCancelled => 'Solicitud cancelada';

  @override
  String errorUnknownNetworkError(String error) {
    return 'Error de red desconocido: $error';
  }

  @override
  String get errorCertificateError => 'Error de certificado';

  @override
  String get errorSessionBusy =>
      'La sesión está ocupada procesando otra solicitud.';

  @override
  String get errorRunShellCommandFailed =>
      'No se pudo ejecutar el comando de shell';

  @override
  String get errorRunSlashCommandFailed =>
      'No se pudo ejecutar el comando de barra';

  @override
  String get settingsBehaviorOpenCodeDefaultsLoadError =>
      'No se pudieron cargar los valores predeterminados basados en OpenCode del servidor activo.';

  @override
  String get sessionTabIconRemoveFailed =>
      'No se pudieron eliminar los datos del icono de la pestaña de sesión local';

  @override
  String get forwardUntitled => 'Sin título';

  @override
  String setupDebugLinuxLogsPath(String path) {
    return 'Registros de Linux: $path';
  }

  @override
  String setupDebugRunOpenCodeCommand(String command) {
    return 'Ejecute OpenCode con: $command';
  }

  @override
  String setupDebugServerHealthEndpoint(String endpoint) {
    return 'Estado del servidor: $endpoint';
  }

  @override
  String setupDebugServerDocsEndpoint(String endpoint) {
    return 'Documentación del servidor: $endpoint';
  }

  @override
  String get logsEntryError => 'Error';

  @override
  String get logsEntryStack => 'Pila';

  @override
  String get setupDebugSourceDiagnostics => 'Diagnóstico';

  @override
  String get setupDebugSourceUseExisting => 'Usar existente';

  @override
  String get setupDebugSourceLocalServer => 'Servidor local';

  @override
  String get setupDebugSourceOnboarding => 'Incorporación';

  @override
  String get setupDebugSourceManualConnection => 'Conexión manual';

  @override
  String setupDebugMessageDiagnosticsResult(
    String availability,
    String platform,
    String recommendation,
  ) {
    return '$availability en $platform. $recommendation';
  }

  @override
  String get setupDebugMessageDetectAttempt =>
      'Se intenta detectar un comando OpenCode existente en el entorno actual.';

  @override
  String get setupDebugMessageInstallStarted =>
      'Instalación de OpenCode iniciada desde CodeWalk.';

  @override
  String setupDebugMessageStartLocalServer(String url) {
    return 'Iniciando el servidor OpenCode administrado en $url.';
  }

  @override
  String setupDebugMessageHealthyRunning(String url) {
    return 'El servidor OpenCode administrado está sano y en ejecución en $url.';
  }

  @override
  String get setupDebugMessageStoppingLocalServer =>
      'Deteniendo el servidor OpenCode administrado.';

  @override
  String get setupDebugMessageStoppedCleanly =>
      'El servidor OpenCode administrado se detuvo correctamente.';

  @override
  String get setupDebugMessageExitedAfterRequestedStop =>
      'El servidor OpenCode administrado se cerró tras una detención solicitada.';

  @override
  String get setupDebugMessageOnboardingConnectExisting =>
      'El usuario eligió conectarse a un servidor OpenCode existente.';

  @override
  String get setupDebugMessageOnboardingGuidedPath =>
      'El usuario abrió la ruta de configuración guiada de OpenCode.';

  @override
  String get setupDebugMessageOnboardingManagedLocal =>
      'El usuario abrió la configuración local administrada de OpenCode.';

  @override
  String get setupDebugMessageOnboardingOpenedServerSettings =>
      'El usuario abrió los ajustes del servidor después de una comprobación de estado fallida.';

  @override
  String get setupDebugMessageOnboardingAddAnotherServer =>
      'El usuario eligió añadir otro servidor después de una comprobación de estado fallida.';

  @override
  String setupDebugMessageTestingServerUrl(String url) {
    return 'Probando la URL del servidor OpenCode $url desde la incorporación.';
  }

  @override
  String get chatProviderErrorSessionNotFound => 'Sesión no encontrada';

  @override
  String get chatProviderErrorInvalidMessageFormat =>
      'Formato de mensaje no válido';

  @override
  String get chatProviderErrorNetworkShort => 'Falló la conexión de red';

  @override
  String get chatProviderErrorUnknownShort => 'Error desconocido';

  @override
  String get terminalCreateFailed => 'No se pudo crear la sesión de terminal';

  @override
  String get terminalEndpointUnavailable =>
      'El endpoint del terminal no está disponible';

  @override
  String get terminalInvalidDirectory => 'Directorio de terminal no válido';

  @override
  String get terminalWebsocketUnavailable =>
      'El websocket del terminal no está disponible aquí.';

  @override
  String chatMessageToolChainCallsCompact(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count llamadas',
      one: '1 llamada',
    );
    return '$_temp0';
  }

  @override
  String get errorConnectionTimeout => 'Se agotó el tiempo de conexión';

  @override
  String get errorClientError => 'Error del cliente';

  @override
  String get chatProviderErrorSendMessage => 'No se pudo enviar el mensaje';

  @override
  String get speechApiEngine => 'API';

  @override
  String get speechApiEngineSubtitle =>
      'OpenAI, Groq o un endpoint personalizado compatible con OpenAI.';

  @override
  String get speechApiProvider => 'Proveedor de voz a texto';

  @override
  String get speechCloudSttPrivacy =>
      'Privacidad del reconocimiento de voz en la nube';

  @override
  String get speechCloudSttPrivacyDescription =>
      'El audio del micrófono grabado se envía al proveedor configurado. Las claves de API se guardan en el almacenamiento seguro de este dispositivo.';

  @override
  String get speechApiKeyOptional => 'Opcional para endpoints personalizados.';

  @override
  String speechApiBatchHint(String provider) {
    return '$provider usa transcripción por lotes. Toca el micrófono de nuevo para detener y transcribir.';
  }

  @override
  String get speechApiWebUnavailable =>
      'El reconocimiento de voz por API no está disponible en la versión web.';

  @override
  String get speechApiConfigInvalid =>
      'Comprueba el endpoint y el modelo de la API de voz. Los endpoints remotos deben usar HTTPS.';

  @override
  String get speechApiRequestInvalid =>
      'El endpoint o el modelo de voz fue rechazado.';

  @override
  String get speechApiRateLimited =>
      'El proveedor de voz informó una cuota o un límite de tarifa.';

  @override
  String get speechApiUnavailable =>
      'El proveedor de voz no está disponible temporalmente.';

  @override
  String get speechApiNetwork => 'No se pudo conectar con el proveedor de voz.';

  @override
  String get speechApiInvalidResponse =>
      'El proveedor de voz devolvió una respuesta no válida.';

  @override
  String get speechApiEmptyAudio => 'No se capturó audio del micrófono.';

  @override
  String get speechApiEmptyTranscript =>
      'El proveedor de voz no devolvió ninguna transcripción.';

  @override
  String get speechApiCustomProvider => 'Personalizado compatible con OpenAI';

  @override
  String get speechApiMaxDuration =>
      'Las grabaciones de API se detienen automáticamente después de 2 minutos.';

  @override
  String get speechApiLanguageHint =>
      'El idioma activo de la aplicación se envía como sugerencia de transcripción.';

  @override
  String get speechSttApiKeyStorageUnavailable =>
      'El almacenamiento seguro de la clave de API de voz no está disponible.';

  @override
  String get speechSttApiKeyMissing =>
      'Añade una clave de API de voz en Ajustes > Voz.';

  @override
  String get speechSttApiKeyRejected => 'La clave de API de voz fue rechazada.';

  @override
  String get carMessagingConversations => 'Conversaciones de Android Auto';

  @override
  String get carMessagingReply => 'Responder';

  @override
  String get carMessagingMarkRead => 'Marcar como leído';

  @override
  String get carMessagingChannelDescription =>
      'Respuestas experimentales de conversaciones de CodeWalk';

  @override
  String get settingsAndroidAutoMessagingDescription =>
      'Compatibilidad experimental de builds de prueba para respuestas finales y respuestas por voz. No aprobado para distribución en Google Play.';

  @override
  String get carMessagingDeliveryFailedTitle =>
      'No se pudo enviar la respuesta';

  @override
  String get carMessagingDeliveryFailedBody =>
      'Tu respuesta de voz no se pudo entregar. Abre CodeWalk para volver a intentarlo.';
}
