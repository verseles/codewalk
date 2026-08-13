// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get aboutGitHub => 'GitHub';

  @override
  String get appProviderCannotActivateUnhealthy =>
      'Невозможно активировать неисправный сервер';

  @override
  String get appProviderDesktopOnly =>
      'Управляемый локальный сервер доступен только на компьютере.';

  @override
  String get appProviderDetectingCommand => 'Обнаружение команды OpenCode...';

  @override
  String get appProviderErrorCannotActivateUnhealthy =>
      'Невозможно активировать неисправный сервер';

  @override
  String get appProviderErrorCloudflareOAuthNotSupported =>
      'Cloudflare Access OAuth не поддерживается на этой платформе';

  @override
  String get appProviderErrorInstallationFailed =>
      'Установка OpenCode не удалась.';

  @override
  String get appProviderErrorInvalidServerUrl => 'Неверный URL сервера';

  @override
  String get appProviderErrorLocalServerHealthCheckFailed =>
      'Локальный сервер запущен, но проверка работоспособности не пройдена.';

  @override
  String get appProviderErrorManagedDesktopOnly =>
      'Управляемый локальный сервер доступен только на компьютере.';

  @override
  String get appProviderErrorServerAlreadyExists =>
      'Сервер с таким URL уже существует';

  @override
  String get appProviderErrorServerProfileNotFound =>
      'Профиль сервера не найден';

  @override
  String get appProviderErrorServerUrlRequired => 'URL сервера обязателен';

  @override
  String get appProviderErrorTailscaleNotSupported =>
      'Tailscale не поддерживается на этой платформе';

  @override
  String appProviderExitedWithCode(int code) {
    return 'Локальный сервер завершил работу с кодом $code.';
  }

  @override
  String get appProviderFailedToStart =>
      'Не удалось запустить локальный сервер OpenCode.';

  @override
  String get appProviderInstallBinary => 'Установить бинарный файл';

  @override
  String get appProviderInstallBunOpenCode => 'Установить Bun + OpenCode';

  @override
  String get appProviderInstallSucceeded => 'Установка прошла успешно.';

  @override
  String appProviderInstallSucceededWithPath(String path) {
    return 'Установка прошла успешно. Команда OpenCode доступна по пути $path.';
  }

  @override
  String get appProviderInstallViaBun => 'Установить через Bun';

  @override
  String get appProviderInstallViaNpm => 'Установить через npm';

  @override
  String get appProviderInstallationFailed => 'Установка OpenCode не удалась.';

  @override
  String get appProviderInstalledSuccessfully =>
      'Требования OpenCode успешно установлены.';

  @override
  String get appProviderInstallingRequirements =>
      'Установка требований OpenCode...';

  @override
  String get appProviderInvalidServerUrl => 'Неверный URL сервера';

  @override
  String get appProviderLabelLocalOpenCodeManaged =>
      'Локальный OpenCode (управляемый)';

  @override
  String get appProviderLabelPrimaryServer => 'Основной сервер';

  @override
  String get appProviderLocalManaged => 'Локальный OpenCode (управляемый)';

  @override
  String get appProviderLocalServerStopped => 'Локальный сервер остановлен.';

  @override
  String get appProviderNotDetectedInstall =>
      'Команда OpenCode не обнаружена. Запустите установку из мастера настройки.';

  @override
  String appProviderNotDetectedRefresh(String appName) {
    return 'Команда OpenCode не обнаружена. Если вы только что установили ее, обновите проверки или перезапустите $appName, чтобы обновить PATH.';
  }

  @override
  String get appProviderOAuthNotSupported =>
      'Cloudflare Access OAuth не поддерживается на этой платформе';

  @override
  String get appProviderOpenCodeDetected => 'OpenCode обнаружен';

  @override
  String get appProviderOpenCodeNotDetected => 'OpenCode не обнаружен';

  @override
  String get appProviderPrimaryServer => 'Основной сервер';

  @override
  String get appProviderProfileNotFound => 'Профиль сервера не найден';

  @override
  String get appProviderRunDiagnostics =>
      'Запустите диагностику для проверки требований к локальному OpenCode.';

  @override
  String appProviderRunningAt(String url) {
    return 'Работает по адресу $url';
  }

  @override
  String get appProviderSetupDetectingOpenCode =>
      'Обнаружение команды OpenCode...';

  @override
  String get appProviderSetupInstallationSucceeded =>
      'Установка завершена успешно.';

  @override
  String appProviderSetupInstallationSucceededWithPath(String path) {
    return 'Установка завершена успешно. Команда OpenCode доступна по пути $path.';
  }

  @override
  String get appProviderSetupInstallingRequirements =>
      'Установка требований OpenCode...';

  @override
  String get appProviderSetupOpenCodeDetected => 'OpenCode обнаружен';

  @override
  String get appProviderSetupOpenCodeNotDetected => 'OpenCode не обнаружен';

  @override
  String get appProviderSetupOpenCodeNotDetectedInstall =>
      'Команда OpenCode не обнаружена. Запустите установку из мастера настройки.';

  @override
  String get appProviderSetupOpenCodeNotDetectedRefresh =>
      'Команда OpenCode не обнаружена. Если вы установили ее только что, обновите проверки или перезапустите CodeWalk, чтобы обновить PATH.';

  @override
  String get appProviderSetupRequirementsInstalled =>
      'Требования OpenCode успешно установлены.';

  @override
  String appProviderSetupUsingOpenCodeAt(String path) {
    return 'Используется команда OpenCode по пути $path';
  }

  @override
  String get appProviderStartingLocalServer => 'Запуск локального сервера...';

  @override
  String appProviderStatusLocalServerExitedWithCode(int code) {
    return 'Локальный сервер завершил работу с кодом $code.';
  }

  @override
  String get appProviderStatusLocalServerStopped =>
      'Локальный сервер остановлен.';

  @override
  String appProviderStatusRunningAt(String url) {
    return 'Работает по адресу $url';
  }

  @override
  String get appProviderStatusStartingLocalServer =>
      'Запуск локального сервера...';

  @override
  String get appProviderStatusStoppingLocalServer =>
      'Остановка локального сервера...';

  @override
  String get appProviderStoppingLocalServer =>
      'Остановка локального сервера...';

  @override
  String get appProviderTailscaleNotSupported =>
      'Tailscale не поддерживается на этой платформе';

  @override
  String appProviderUsingCommandAt(String path) {
    return 'Используется команда OpenCode по пути $path';
  }

  @override
  String get appShellDownloadingUpdate => 'Загрузка обновления…';

  @override
  String get appShellInstall => 'Установить';

  @override
  String get appShellInstallFailed => 'Установка не удалась';

  @override
  String get appShellInstallingUpdate => 'Установка обновления...';

  @override
  String get appShellRestart => 'Перезагрузить';

  @override
  String appShellUpdateAvailableResult(String latestVersion) {
    return 'Доступно обновление: v$latestVersion';
  }

  @override
  String get appShellUpdateInstalledRestartApp =>
      'Обновление установлено. Перезапустите приложение для применения.';

  @override
  String get appShellUpdateInstalledRestartRequired =>
      'Обновление установлено. Требуется перезапуск для применения новой версии.';

  @override
  String get attachmentCouldNotDecode =>
      'Данные вложения не могут быть декодированы.';

  @override
  String get attachmentCouldNotDownload => 'Не удалось скачать вложение.';

  @override
  String get attachmentCouldNotSave =>
      'Вложение не удалось сохранить на этом устройстве.';

  @override
  String get attachmentDownloadStarted => 'Загрузка вложения началась.';

  @override
  String get attachmentLocalNotFound =>
      'Локальное вложение не найдено на этом устройстве.';

  @override
  String get attachmentNoValidLocation =>
      'Вложение не указывает корректный путь.';

  @override
  String get attachmentNotAvailableOnPlatform =>
      'Действия с вложениями недоступны на этой платформе.';

  @override
  String get attachmentPathEmpty => 'Путь к вложению пуст.';

  @override
  String get attachmentPayloadEmpty => 'Полезная нагрузка вложения пуста.';

  @override
  String get attachmentSaveCanceled => 'Сохранение отменено.';

  @override
  String attachmentSavedAndOpened(String path) {
    return 'Вложение сохранено по пути $path и открыто.';
  }

  @override
  String attachmentSavedPath(String path) {
    return 'Вложение сохранено в $path.';
  }

  @override
  String attachmentSavedTo(String path) {
    return 'Вложение сохранено по пути $path.';
  }

  @override
  String get attachmentUnableToOpenLink =>
      'Не удалось открыть ссылку на вложение.';

  @override
  String get attachmentUnableToOpenLocal =>
      'Не удалось открыть локальное вложение.';

  @override
  String get behaviorAdvancedPermissionRule =>
      'Расширенное редактирование правил разрешений пока не включено в Настройки и отложено для последующей работы по достижению паритета.';

  @override
  String get behaviorAutomatic => 'Автоматически';

  @override
  String get behaviorAutomaticFallback => 'Автоматический откат';

  @override
  String get behaviorCellularDataSaver => 'Экономия mobile-данных';

  @override
  String get behaviorCellularDataSaverActive =>
      'Экономия мобильного трафика активна.';

  @override
  String get behaviorChatLevelShare =>
      'Используйте действие общего доступа на уровне чата, чтобы опубликовать одну сессию сейчас. Эта настройка меняет только политику общего доступа OpenCode по умолчанию.';

  @override
  String get behaviorCodeWalkReleaseChecks =>
      'Используйте раздел «О программе» для проверки релизов CodeWalk. Эта настройка лишь дублирует официальную конфигурацию `autoupdate` OpenCode.';

  @override
  String get behaviorControlsOfficialGlobal =>
      'Управляет официальной глобальной конфигурацией `share`, а не кнопкой общего доступа для отдельного чата.';

  @override
  String get behaviorControlsUpstreamOpenCode =>
      'Управляет обновлениями среды выполнения OpenCode, а не проверками обновлений приложения CodeWalk.';

  @override
  String get behaviorCustomDisplayName =>
      'Пользовательское имя, отображаемое в беседах вместо системного имени пользователя.';

  @override
  String behaviorCutsAutomaticMobile(int inSeconds) {
    return 'Сокращает автоматическое использование мобильных данных, останавливая фоновые загрузки и ограничивая автоматические обновления в фоновом режиме до одной серии каждые $inSeconds секунд.';
  }

  @override
  String get behaviorDataSaverActive =>
      'Активно сейчас при использовании мобильного интернета.';

  @override
  String get behaviorDataSaverAggressive => 'Агрессивный';

  @override
  String get behaviorDataSaverAggressiveDescription =>
      'Режим низкой пропускной способности: активным остается только поток видимого рабочего пространства, глобальные обновления приостановлены, а автоматические обновления растянуты во времени.';

  @override
  String get behaviorDataSaverCellularOnly =>
      'Применяется только при мобильном подключении.';

  @override
  String get behaviorDataSaverOff => 'Выкл.';

  @override
  String get behaviorDataSaverOffHint =>
      'Полный режим реального времени и автоматические обновления включены.';

  @override
  String get behaviorDataSaverStandard => 'Стандартный';

  @override
  String get behaviorDataSaverWaiting =>
      'Ожидание следующего окна синхронизации мобильных данных.';

  @override
  String get behaviorDisabled => 'Отключено';

  @override
  String get behaviorLightweightTasksLike =>
      'Используется для легких задач, таких как генерация заголовков.';

  @override
  String get behaviorManual => 'Вручную';

  @override
  String get behaviorNotify => 'Только уведомлять';

  @override
  String get behaviorOfficialOpenCodePermission =>
      'Официальная политика разрешений OpenCode настраивается в `opencode.json` с правилами allow/ask/deny для каждого инструмента. CodeWalk сохраняет официальные карточки запроса разрешений и добавляет одно одобренное исключение ADR-023: переключатель автоодобрения в редакторе безусловно отвечает `Always` и `remember: true` для создания постоянных разрешений в рамках сессии и поддерживает тот же путь непрерывности в рамках потока в фоновом воркере Android.';

  @override
  String get behaviorOpenCodeBackedDefaults =>
      'Значения по умолчанию на базе OpenCode';

  @override
  String get behaviorPermissionHandlingProvenance =>
      'Происхождение обработки разрешений';

  @override
  String get behaviorPermissionsVariantReasoning =>
      'Разрешения и паритет вариантов/рассуждений остаются разделенными до тех пор, пока их интерфейс не сможет безопасно сохранять расширенную конфигурацию.';

  @override
  String get behaviorPrimaryAgentAgent =>
      'Основной агент, используемый, когда агент не выбран явно.';

  @override
  String get behaviorRefreshDefaults => 'Обновить значения по умолчанию';

  @override
  String get behaviorSharedAcrossOpenCode =>
      'Доступно клиентам OpenCode через конфигурацию.';

  @override
  String get behaviorTheseValuesWrite =>
      'Эти значения записываются в `/config` на активном сервере и соответствуют официальной общей конфигурации OpenCode.';

  @override
  String get cannedAddTitle => 'Добавить быстрый ответ';

  @override
  String get cannedAppendAtCursor => 'Добавить в позицию курсора';

  @override
  String get cannedAppendAtCursorSubtitle =>
      'Выключено означает замену текущего текста в редакторе';

  @override
  String get cannedAttachFiles => 'Прикрепить файлы';

  @override
  String get cannedEditTitle => 'Редактировать быстрый ответ';

  @override
  String get cannedNewQuickReply => 'Новый быстрый ответ';

  @override
  String get cannedNoSuggestions => 'Нет предложений';

  @override
  String get cannedOffMeansReplace =>
      'Выключено означает замену текущего текста в редакторе';

  @override
  String get cannedQuickReply => 'Новый быстрый ответ';

  @override
  String get cannedReplace => 'Заменить';

  @override
  String get cannedScopeGlobalSubtitle =>
      'Отключить для элемента, предназначенного только для проекта';

  @override
  String get cannedScopeGlobalUnavailableSubtitle =>
      'Только для проекта — недоступно в текущем контексте';

  @override
  String get cannedSendAutomaticallySubtitle =>
      'Отправлять немедленно после вставки этого быстрого ответа';

  @override
  String get cannedSendImmediatelyInserting =>
      'Отправлять немедленно после вставки этого быстрого ответа';

  @override
  String get cannedTextLabel => 'Текст';

  @override
  String get chatActionNext => 'Далее';

  @override
  String get chatActiveServerUnhealthy =>
      'Активный сервер неисправен. Попытки отправки будут однократными и будут завершаться ошибкой до восстановления работоспособности.';

  @override
  String get chatActiveServerUnhealthyLabel => 'Активный сервер неисправен';

  @override
  String get chatAddServerToStart => 'Добавьте сервер, чтобы начать общение.';

  @override
  String get chatAppBarMoreActions => 'Другие действия';

  @override
  String get chatAppBarPinAction => 'Закрепить на панели приложения';

  @override
  String get chatAppBarPinDescription =>
      'Это действие останется видимым за пределами меню.';

  @override
  String get chatAppBarUnpinAction => 'Открепить от панели приложения';

  @override
  String get chatAppBarUnpinDescription =>
      'Это действие будет перемещено обратно в меню.';

  @override
  String chatBadgeConversationError(String title) {
    return 'Ошибка в беседе \"$title\".';
  }

  @override
  String chatBadgeConversationNeedsInput(String title) {
    return 'Беседа \"$title\" требует вашего ввода.';
  }

  @override
  String chatBadgeConversationNewReply(String title) {
    return 'В беседе \"$title\" появился новый ответ.';
  }

  @override
  String get chatBadgeDataSaverActive => 'Экономия мобильного трафика активна.';

  @override
  String get chatBadgeServerNeedsAttention =>
      'Подключение к серверу требует внимания.';

  @override
  String get chatBadgeSyncing => 'Синхронизация бесед...';

  @override
  String get chatBlockResponsePendingDescription =>
      'Ответ появится единым блоком, когда этот ход завершится.';

  @override
  String get chatBlockResponsePendingTitle => 'Генерация ответа';

  @override
  String get chatCachedConversationsYet => 'Кэшированных бесед пока нет';

  @override
  String get chatChangedFilesAvailable =>
      'Для этой сессии нет доступных измененных файлов.';

  @override
  String chatChildrenChatProviderCurrentSessionChildren(int length) {
    return 'Дочерние элементы: $length';
  }

  @override
  String get chatChooseAgent => 'Выбрать агента';

  @override
  String get chatChooseDirectory => 'Выбрать каталог';

  @override
  String get chatChooseEffort => 'Выбрать уровень effort';

  @override
  String get chatChooseFolderOpen =>
      'Выберите папку для открытия в качестве контекста проекта.';

  @override
  String get chatChooseModel => 'Выбрать модель';

  @override
  String get chatClose => 'Закрыть';

  @override
  String chatCloseProject(String project) {
    return 'Закрыть $project';
  }

  @override
  String get chatCollapseGroup => 'Свернуть группу';

  @override
  String get chatCommandDescriptionProject => 'Команда проекта';

  @override
  String get chatCommandSourceGeneric => 'команда';

  @override
  String get chatCommandSourceProject => 'проект';

  @override
  String get chatCompactContext => 'Сжать контекст';

  @override
  String get chatComposerHintShell => 'Команда терминала (Esc для выхода)';

  @override
  String get chatComposerPlaceholder => 'Введите ваш запрос...';

  @override
  String get chatConversation => 'Беседа';

  @override
  String get chatConversations => 'Беседы';

  @override
  String get chatConversationsPane => 'Беседы';

  @override
  String chatCostLabel(double cost) {
    return 'Стоимость: \\\$$cost';
  }

  @override
  String get chatCouldNotRefreshSession => 'Не удалось обновить эту беседу';

  @override
  String get chatCurrent => 'Использовать текущий';

  @override
  String chatDescriptionChildren(int count) {
    return 'Дочерние элементы: $count';
  }

  @override
  String get chatDescriptionCloseApp =>
      'Закрыть приложение в соответствии с системным поведением закрытия';

  @override
  String get chatDescriptionCycleModels => 'Переключить недавние модели';

  @override
  String get chatDescriptionCycleVariant => 'Переключить вариант модели';

  @override
  String get chatDescriptionDiffFilesZero => 'Измененные файлы: 0';

  @override
  String get chatDescriptionFocusInput => 'Фокус на вводе сообщения';

  @override
  String get chatDescriptionFocusOrCloseDrawer =>
      'Фокус на вводе (или закрытие панели, если открыта)';

  @override
  String get chatDescriptionForceExit => 'Принудительно выйти из приложения';

  @override
  String get chatDescriptionNewConversation => 'Новая беседа';

  @override
  String get chatDescriptionNextAgent => 'Следующий агент';

  @override
  String get chatDescriptionOpenProjects =>
      'Используйте эту кнопку, чтобы открыть проекты и беседы.';

  @override
  String get chatDescriptionOpenSettings => 'Открыть настройки';

  @override
  String get chatDescriptionPreviousAgent => 'Предыдущий агент';

  @override
  String get chatDescriptionProjectCommand => 'Команда проекта';

  @override
  String get chatDescriptionQuickOpen => 'Быстрое открытие файлов';

  @override
  String get chatDescriptionRefreshData => 'Обновить данные чата';

  @override
  String get chatDescriptionStopResponse =>
      'Остановить активный ответ (во время генерации)';

  @override
  String get chatDescriptionSwitchProject =>
      'Используйте эту кнопку, чтобы переключить папки проекта и контекст.';

  @override
  String get chatDescriptionVoiceInput =>
      'Запуск или остановка голосового ввода';

  @override
  String get chatDiffFiles => 'Измененные файлы: 0';

  @override
  String get chatDisplay => 'Отображение';

  @override
  String get chatDisplayToggles => 'Переключатели отображения';

  @override
  String get chatDoubleESCStop => 'Двойной ESC для остановки';

  @override
  String get chatEffortLockedSubConversation =>
      'Параметр effort заблокирован в суб-беседе';

  @override
  String get chatExpandGroup => 'Развернуть группу';

  @override
  String get chatExportCanceled => 'Экспорт сессии отменен';

  @override
  String get chatFailedToLoadDirectories => 'Не удалось загрузить каталоги';

  @override
  String get chatFailedToLoadFile => 'Не удалось загрузить файл';

  @override
  String get chatFailedToRefreshProviders =>
      'Не удалось обновить список провайдеров и моделей';

  @override
  String get chatFailedToRefreshSubConversations =>
      'Не удалось обновить суб-беседы. Пожалуйста, попробуйте еще раз.';

  @override
  String get chatFailedToStopResponse => 'Не удалось остановить текущий ответ';

  @override
  String get chatFileExplorerContents => 'Содержимое';

  @override
  String get chatFileExplorerNames => 'Имена';

  @override
  String get chatFilterActive => 'Активные';

  @override
  String get chatFilterAll => 'Все';

  @override
  String get chatFilterArchived => 'Архивные';

  @override
  String get chatFilterDirectories => 'Фильтровать каталоги';

  @override
  String get chatFilterSessions => 'Фильтровать сессии';

  @override
  String get chatForkFailed => 'Не удалось создать ответвление беседы';

  @override
  String get chatForked => 'Ответвление беседы создано';

  @override
  String get chatGoToFirst => 'Перейти к первому сообщению';

  @override
  String get chatGoToLatest => 'Перейти к последнему сообщению';

  @override
  String chatGroupMessageCountMessages(
    String compactionLabel,
    String messageCount,
  ) {
    return '$messageCount сообщений скрыто перед сжатием $compactionLabel';
  }

  @override
  String get chatHelloAssistant => 'Привет! Я ваш ИИ-ассистент';

  @override
  String get chatHelp => 'Чем я могу вам помочь?';

  @override
  String get chatHelpMessage =>
      'Используйте @ для упоминаний, ! для терминала, / для команд';

  @override
  String get chatHideConversationsSidebar => 'Скрыть боковую панель бесед';

  @override
  String get chatHideUtilitySidebar => 'Скрыть боковую панель утилит';

  @override
  String get chatHistoryCollapsed => 'Предыдущая история свернута';

  @override
  String get chatHistoryHideEarlier => 'Скрыть предыдущие сообщения';

  @override
  String chatHistoryMessagesHidden(int count, String label) {
    return '$count сообщений скрыто перед сжатием $label';
  }

  @override
  String get chatHistoryShowEarlier => 'Показать предыдущие сообщения';

  @override
  String get chatKeepWorking => 'Продолжить работу';

  @override
  String get chatLargeContentSkipped =>
      'Слишком большое или некорректное содержимое пропущено для стабильности.';

  @override
  String get chatLatestToolActivity =>
      'Последние действия инструментов остаются внутри этой ограниченной панели для стабильности окна просмотра чата.';

  @override
  String get chatLoadMore => 'Загрузить еще';

  @override
  String get chatLoadingProjectContext => 'Загрузка контекста проекта...';

  @override
  String get chatMainConversationUnavailable =>
      'Основная беседа пока недоступна.';

  @override
  String get chatParentConversationUnavailable =>
      'Родительская беседа пока недоступна.';

  @override
  String get chatMentionAgentSubtitle => 'агент';

  @override
  String get chatMentionFileSubtitle => 'файл';

  @override
  String get chatMentionSymbolSubtitle => 'символ';

  @override
  String get chatMessageAttachedFile => 'Прикрепленный файл';

  @override
  String get chatMessageDetails => 'Детали';

  @override
  String get chatMessageHide => 'Скрыть';

  @override
  String get chatMessageLess => 'Меньше';

  @override
  String get chatMessageMessagePartUnavailable => 'Часть сообщения недоступна';

  @override
  String get chatMessageMetadataAvailable => 'Метаданные недоступны';

  @override
  String chatMessageModelMessageModelId(String modelId) {
    return 'Модель: $modelId';
  }

  @override
  String get chatMessageMore => 'Больше';

  @override
  String get chatMessageOpenFile => 'Открыть файл';

  @override
  String chatMessageProviderMessageProviderId(String providerId) {
    return 'Провайдер: $providerId';
  }

  @override
  String get chatMessageRewindEdit => 'Вернуться назад и редактировать отсюда';

  @override
  String get chatMessageRunningTask => 'Выполнение задачи';

  @override
  String get chatMessageSaveFile => 'Сохранить файл';

  @override
  String get chatMessageShow => 'Показать';

  @override
  String get chatMessageShowLess => 'Показать меньше';

  @override
  String get chatMessageShowLessCompact => 'Меньше';

  @override
  String get chatMessageShowMore => 'Показать больше';

  @override
  String get chatMessageShowMoreCompact => 'Больше';

  @override
  String get chatMessageThinking => 'Размышление';

  @override
  String get chatMessageThinkingProcess => 'Процесс мышления';

  @override
  String get chatMessageToolCall => '1 вызов инструмента';

  @override
  String chatMessageToolCalls(int count) {
    return 'Вызовы инструментов: $count';
  }

  @override
  String get chatMessageToolCommand => 'Команда';

  @override
  String get chatMessageToolCommandTruncated =>
      'Предварительный просмотр команды обрезан для стабильности.';

  @override
  String get chatMessageToolDiffOmitted =>
      'Предварительный просмотр изменений пропущен: размер данных слишком велик для безопасного отображения на мобильном устройстве.';

  @override
  String get chatMessageToolInput => 'Ввод';

  @override
  String get chatMessageToolInputTruncated =>
      'Предварительный просмотр ввода обрезан для стабильности.';

  @override
  String get chatMessageToolOutputTruncated =>
      'Предварительный просмотр вывода инструмента обрезан для стабильности приложения.';

  @override
  String chatMessageToolQueuedCount(int count) {
    return 'В очереди: $count';
  }

  @override
  String chatMessageToolRunningCount(int count) {
    return 'Выполняется: $count';
  }

  @override
  String get chatMessageToolStatusInProgress => 'Выполняется';

  @override
  String get chatMessageToolStatusNeedsAttention => 'Требует внимания';

  @override
  String get chatMessageToolStatusQueued => 'В очереди';

  @override
  String get chatMessageYou => 'Вы';

  @override
  String get chatModelLockedSubConversation =>
      'Модель заблокирована в суб-беседе';

  @override
  String get chatNewChat => 'Новый чат';

  @override
  String get chatNewChatTourDescription => 'Начните новую беседу здесь.';

  @override
  String get chatNewChatTourTitle => 'Новый чат';

  @override
  String get chatNoConversationsInProject => 'В этом проекте нет бесед.';

  @override
  String get chatNoServerYet => 'Сервер еще не настроен';

  @override
  String get chatNoSessionSelected =>
      'Выберите или создайте беседу, чтобы начать общение';

  @override
  String get chatNoSubConversationFound =>
      'Суб-беседа для этой задачи не найдена.';

  @override
  String get chatOpenFiles => 'Открытые файлы';

  @override
  String get chatOpenProject => 'Открыть проект';

  @override
  String get chatOpenProjectFolder => 'Открыть папку проекта...';

  @override
  String get chatOpenProjectToLoad => 'Открыть проект для загрузки бесед.';

  @override
  String get chatOpenSidebar => 'Открыть боковую панель';

  @override
  String get chatPageStatusAutomaticCompactionExplanation =>
      'Автоматическое сжатие происходит по мере роста использования контекста.';

  @override
  String get chatPageStatusCompactNow => 'Сжать сейчас';

  @override
  String get chatPageStatusCompacting => 'Сжатие...';

  @override
  String get chatPageStatusCompactingContextNow => 'Сжатие контекста...';

  @override
  String get chatPageStatusContextCompacted => 'Контекст сжат';

  @override
  String get chatPageStatusContextUsage => 'Использование контекста';

  @override
  String get chatPageStatusCost => 'Стоимость';

  @override
  String get chatPageStatusFailedToCompactContext =>
      'Не удалось сжать контекст';

  @override
  String get chatPageStatusLimit => 'Лимит';

  @override
  String get chatPageStatusManageServers => 'Управление серверами';

  @override
  String get chatPageStatusSaver => 'Экономия';

  @override
  String get chatPageStatusServer => 'Сервер';

  @override
  String get chatPageStatusSwitchServer => 'Переключить сервер';

  @override
  String get chatPageStatusTokens => 'Токены';

  @override
  String get chatPageStatusUsage => 'Использование';

  @override
  String chatPageStatusUsagePercent(int usagePercent) {
    return '$usagePercent';
  }

  @override
  String get chatPermissionAutoApproveOff =>
      'Автоматическое одобрение разрешений выключено';

  @override
  String get chatPermissionAutoApproveOn =>
      'Автоматическое одобрение разрешений включено';

  @override
  String get chatProjectContext => 'Контекст проекта';

  @override
  String get chatProjectContext2 => 'Контекст проекта';

  @override
  String get chatRealtimeGlobalEvent => 'глобальное событие';

  @override
  String chatRealtimeGlobalEventReason(String reason) {
    return 'глобальное событие ($reason)';
  }

  @override
  String get chatRealtimeGlobalEventStale =>
      'глобальное событие (устаревшая генерация)';

  @override
  String chatRealtimeMessageStreamReason(String reason) {
    return 'поток сообщений ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEvent => 'событие в реальном времени';

  @override
  String chatRealtimeRealtimeEventReason(String reason) {
    return 'событие в реальном времени ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEventStale =>
      'событие в реальном времени (устаревшая генерация)';

  @override
  String get chatRealtimeReconnectingServerTry =>
      'Переподключение к серверу. Попробуйте еще раз через минуту.';

  @override
  String get chatReasoning => 'Рассуждение...';

  @override
  String get chatRecentSessions => 'Недавние сессии';

  @override
  String get chatRecentSessionsToggle => 'Недавние сессии';

  @override
  String get chatRedoLastTurn => 'Повторить последний отмененный ход';

  @override
  String get chatRedoNothing => 'В этой сессии нечего повторять';

  @override
  String get chatRefresh => 'Обновить';

  @override
  String get chatRefreshConversation => 'Не удалось обновить эту беседу';

  @override
  String get chatRefreshProjects => 'Обновить проекты';

  @override
  String get chatRefreshSessionDetails => 'Обновить детали сессии';

  @override
  String chatRemoveDisplayNameHistory(String displayName) {
    return 'Удалить $displayName из истории';
  }

  @override
  String get chatRetry => 'Повторить';

  @override
  String get chatRetry2 => 'Повторить';

  @override
  String get chatRetryRefresh => 'Повторить обновление';

  @override
  String get chatRetryingModelRequest =>
      'Повторная попытка запроса к модели...';

  @override
  String get chatReturnToMainConversation => 'Вернуться к основной беседе';

  @override
  String get chatReturnToParentConversation =>
      'Вернуться к родительской беседе';

  @override
  String get chatReviewChanges => 'Просмотр изменений';

  @override
  String get chatSearchConversations => 'Поиск бесед';

  @override
  String get chatSearchNextResult => 'Следующий результат';

  @override
  String get chatSearchNoResults => 'Нет результатов';

  @override
  String get chatSearchPreviousResult => 'Предыдущий результат';

  @override
  String chatSearchResultCount(int current, int total) {
    return 'Сообщение $current из $total';
  }

  @override
  String get chatSearchTimeline => 'Поиск по шкале времени';

  @override
  String get chatSelectDirectory => 'Выбрать каталог';

  @override
  String get chatSelectOrCreate =>
      'Выберите или создайте беседу, чтобы начать общение';

  @override
  String get chatSelectProjectBelow => 'Выберите проект ниже.';

  @override
  String get chatServerSelectedModel => 'Модель, выбранная сервером';

  @override
  String get chatSessionActions => 'Действия с сессией';

  @override
  String chatSessionChatSessionSession(String title) {
    return 'Сессия чата: $title';
  }

  @override
  String chatSessionConversationNextAction(String nextAction) {
    return 'Беседа $nextAction';
  }

  @override
  String get chatSessionConversations => 'Бесед нет';

  @override
  String get chatSessionCreateConversationStart =>
      'Создайте новую беседу, чтобы начать общение';

  @override
  String get chatSessionTabsToggle => 'Вкладки сессий';

  @override
  String chatSessionsLength(int length) {
    return '$length';
  }

  @override
  String get chatSetUpServer => 'Настроить сервер';

  @override
  String get chatSettings => 'Настройки';

  @override
  String get chatShortcutsCloseApp =>
      'Закрыть приложение в соответствии с системным поведением закрытия';

  @override
  String get chatShortcutsCycleModels => 'Переключить недавние модели';

  @override
  String get chatShortcutsCycleVariant => 'Переключить вариант модели';

  @override
  String get chatShortcutsFocusInput => 'Фокус на вводе сообщения';

  @override
  String get chatShortcutsFocusInputCloseDrawer =>
      'Фокус на вводе (или закрытие панели, если открыта)';

  @override
  String get chatShortcutsForceExit => 'Принудительно выйти из приложения';

  @override
  String get chatShortcutsNewConversation => 'Новая беседа';

  @override
  String get chatShortcutsNextAgent => 'Следующий агент';

  @override
  String get chatShortcutsOpenSettings => 'Открыть настройки';

  @override
  String get chatShortcutsPreviousAgent => 'Предыдущий агент';

  @override
  String get chatShortcutsQuickOpen => 'Быстрое открытие файлов';

  @override
  String get chatShortcutsRefreshChat => 'Обновить данные чата';

  @override
  String get chatShortcutsStartStopVoice =>
      'Запуск или остановка голосового ввода';

  @override
  String get chatShortcutsStopResponse =>
      'Остановить активный ответ (во время генерации)';

  @override
  String get chatSidebarAccess => 'Доступ к боковой панели';

  @override
  String get chatSortMostRecent => 'Сначала новые';

  @override
  String get chatSortOldest => 'Сначала старые';

  @override
  String get chatSortRecent => 'Недавние';

  @override
  String get chatSortSessions => 'Сортировать сессии';

  @override
  String get chatSortTitle => 'По названию';

  @override
  String get chatStartVoiceInput => 'Запустить голосовой ввод';

  @override
  String get chatStartingVoiceInput => 'Запуск голосового ввода';

  @override
  String get chatStatusBusy => 'Статус: Занят';

  @override
  String get chatStatusPatching => 'Применение патча';

  @override
  String chatStatusPatchingMultipleFiles(int count) {
    return 'Применение патча к $count файлам';
  }

  @override
  String get chatStatusPatchingOneFile => 'Применение патча к 1 файлу';

  @override
  String get chatStatusRetry => 'Статус: Повторная попытка';

  @override
  String chatStatusRetryCount(int count) {
    return 'Статус: Повторная попытка #$count';
  }

  @override
  String get chatStatusSubsession => 'Суб-сессия';

  @override
  String get chatStatusThinking => 'Размышление...';

  @override
  String get chatStopVoiceInput => 'Остановить голосовой ввод';

  @override
  String chatSyncLabel(String label) {
    return 'Синхронизация: $label';
  }

  @override
  String get chatTasks => 'Задачи';

  @override
  String get chatTasksAvailableSession =>
      'Для этой сессии нет доступных задач.';

  @override
  String get chatTipAcceptanceCriteria =>
      'Совет: Добавьте критерии приемки для крупных изменений';

  @override
  String get chatTipAskForPlan =>
      'Совет: Для больших задач сначала запросите план';

  @override
  String get chatTipBeSpecific =>
      'Совет: Будьте конкретны — более короткие запросы обрабатываются быстрее';

  @override
  String get chatTipBreakTasks =>
      'Совет: Разбивайте большие задачи на более мелкие запросы';

  @override
  String get chatTipCompareOptions =>
      'Совет: Запросите варианты, если компромиссы неясны';

  @override
  String get chatTipContextKnob =>
      'Совет: Нажмите на индикатор контекста, чтобы просмотреть подробности его использования';

  @override
  String get chatTipDefineVerification =>
      'Совет: Укажите, какие тесты или проверки должны пройти';

  @override
  String get chatTipLongPressSend =>
      'Совет: Долгое нажатие на Отправить для вставки новой строки';

  @override
  String get chatTipMentionFiles =>
      'Совет: Используйте @ для упоминания файлов в вашем запросе';

  @override
  String get chatTipNameRelevantFiles =>
      'Совет: Укажите важные файлы, экраны или команды';

  @override
  String get chatTipProvideContext =>
      'Совет: Предоставляйте контекст — вставляйте сообщения об ошибках и логи';

  @override
  String get chatTipRenameConversation =>
      'Совет: Нажмите на заголовок, чтобы переименовать беседу';

  @override
  String get chatTipRequestDocs =>
      'Совет: Просите обновить docs, когда поведение меняется';

  @override
  String get chatTipShareAttempts =>
      'Совет: Расскажите, что пробовали, и точную ошибку';

  @override
  String get chatTipShellCommands =>
      'Совет: Используйте ! в начале, чтобы выполнять команды терминала';

  @override
  String get chatTipSlashCommands =>
      'Совет: Используйте / для доступа к слэш-командам';

  @override
  String get chatTipStartWithGoal => 'Совет: Начните с конечной цели';

  @override
  String get chatTipStateConstraints =>
      'Совет: Укажите ограничения, которые агент должен сохранить';

  @override
  String get chatTipStepByStep =>
      'Совет: Запрашивайте пошаговые инструкции при отладке сложных проблем';

  @override
  String get chatTipUseFocusedAgents =>
      'Совет: Выберите фокусного агента для плана, ревью или сборки';

  @override
  String get chatToggleSidebars => 'Переключить боковые панели';

  @override
  String chatTokensLabel(int total) {
    return 'Токены: $total';
  }

  @override
  String get chatTourProjectsConversations =>
      'Используйте эту кнопку, чтобы открыть проекты и беседы.';

  @override
  String get chatTourSidebarProjectTools =>
      'Используйте это меню, чтобы показать боковую панель бесед и инструменты проекта.';

  @override
  String get chatTourSwitchFolders =>
      'Используйте эту кнопку, чтобы переключить папки проекта и контекст.';

  @override
  String get chatUndoLastTurn => 'Отменить последний ход';

  @override
  String get chatUndoNothing => 'В этой сессии нечего отменять';

  @override
  String get chatUseCurrent => 'Использовать текущий';

  @override
  String get chatWaitingForNetworkConnection =>
      'Ожидание сетевого подключения...';

  @override
  String get chatWelcomeMessage => 'Привет! Я ваш ИИ-ассистент.';

  @override
  String get chatWelcomeSubmessage => 'Чем я могу помочь вам сегодня?';

  @override
  String get chatWorkBoundedPanelExplanation =>
      'Последние действия инструментов остаются внутри этой ограниченной панели для стабильности окна просмотра чата.';

  @override
  String get chatWorkExpand => 'Развернуть';

  @override
  String get chatWorkHide => 'Скрыть';

  @override
  String get chatWorkMessageOne => '1 рабочее сообщение';

  @override
  String chatWorkMessagesMultiple(int count) {
    return '$count рабочих сообщений';
  }

  @override
  String get chatWorkShow => 'Показать';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonCopiedToClipboard => 'Скопировано в буфер обмена';

  @override
  String get commonDelete => 'Удалить';

  @override
  String get commonFile => 'Файл';

  @override
  String get commonReset => 'Сбросить';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get compactionAutomatic => 'автоматическое';

  @override
  String get compactionManual => 'ручное';

  @override
  String get composerAddAttachment => 'Добавить вложение';

  @override
  String get composerAttachFiles => 'Прикрепить файлы';

  @override
  String get composerCannedAppendAtCursor => 'Добавить в позицию курсора';

  @override
  String get composerCannedLabel => 'Ярлык (опционально)';

  @override
  String get composerCannedNoReplies => 'Быстрых ответов пока нет.';

  @override
  String get composerCannedReplace => 'Заменить';

  @override
  String get composerCannedSave => 'Сохранить';

  @override
  String get composerCannedScopeGlobal => 'Глобальный';

  @override
  String get composerCannedScopeProject => 'Только для проекта';

  @override
  String get composerCannedSendAutomatically => 'Отправлять автоматически';

  @override
  String get composerCannedText => 'Текст';

  @override
  String get composerChatInput => 'Ввод чата';

  @override
  String get composerDeleteAction => 'Удалить';

  @override
  String get composerDropHint => 'Перетащите изображения или PDF';

  @override
  String get composerPastedImageName => 'Вставленное изображение';

  @override
  String get composerEdit => 'Редактировать';

  @override
  String get composerExtras => 'Дополнительно';

  @override
  String get composerExtrasHide => 'Скрыть дополнительно';

  @override
  String get composerNewQuickReply => 'Новый быстрый ответ';

  @override
  String get composerSelectImages => 'Выбрать изображения';

  @override
  String get composerSelectPdf => 'Выбрать PDF';

  @override
  String get composerSend => 'Отправить';

  @override
  String get composerShellMode => 'Режим терминала';

  @override
  String get desktopWindowClose => 'Закрыть';

  @override
  String get desktopWindowMaximize => 'Развернуть';

  @override
  String get desktopWindowMinimize => 'Свернуть';

  @override
  String get desktopWindowRestore => 'Восстановить';

  @override
  String get dialogDownload => 'Скачать';

  @override
  String get dialogLanguage => 'Язык';

  @override
  String get dialogMoonshineModelSize => 'Размер модели';

  @override
  String get dialogMoonshineVoiceSetup => 'Настройка Moonshine';

  @override
  String get dialogParakeetModel => 'Модель Parakeet';

  @override
  String get dialogParakeetVoiceSetup => 'Настройка голоса Parakeet';

  @override
  String get dialogSenseVoiceModel => 'Модель SenseVoice';

  @override
  String get dialogSenseVoiceSetup => 'Настройка SenseVoice';

  @override
  String get dialogVoiceInputSetup => 'Настройка голосового ввода';

  @override
  String get errorAnErrorOccurred => 'Произошла ошибка';

  @override
  String get errorAuthRequired => 'Требуется авторизация';

  @override
  String get errorAuthRequiredDesc =>
      'Ошибка аутентификации. Переподключите провайдера и попробуйте снова.';

  @override
  String get errorConnectionFailed => 'Сбой подключения';

  @override
  String get errorConnectionFailedDesc =>
      'Не удается связаться с сервером. Проверьте соединение и статус сервера.';

  @override
  String get errorFormatAuthenticationFailedReconnect =>
      'Ошибка аутентификации. Переподключите провайдера и попробуйте снова.';

  @override
  String get errorFormatProviderTemporarilyUnavailable =>
      'Провайдер временно недоступен. Попробуйте позже.';

  @override
  String get errorFormatQuotaExceededCheck =>
      'Превышена квота. Проверьте тарифный план или баланс вашего провайдера.';

  @override
  String get errorFormatRateLimitExceeded =>
      'Превышен лимит запросов. Подождите немного и попробуйте снова.';

  @override
  String get errorFormatServerErrorPlease =>
      'Внутренняя ошибка сервера. Пожалуйста, попробуйте еще раз.';

  @override
  String get errorFormatServiceTemporarilyUnavailable =>
      'Служба временно недоступна. Сервер может перезапускаться — пожалуйста, попробуйте снова в ближайшее время.';

  @override
  String get errorFormatUnableReachServer =>
      'Не удается связаться с сервером. Проверьте соединение и статус сервера.';

  @override
  String get errorProviderUnavailable => 'Провайдер недоступен';

  @override
  String get errorProviderUnavailableDesc =>
      'Провайдер временно недоступен. Попробуйте позже.';

  @override
  String get errorQuotaExceeded => 'Превышена квота';

  @override
  String get errorQuotaExceededDesc =>
      'Превышена квота. Проверьте тарифный план или баланс вашего провайдера.';

  @override
  String get errorRateLimitExceeded => 'Превышен лимит запросов';

  @override
  String get errorRateLimitExceededDesc =>
      'Превышен лимит запросов. Подождите немного и попробуйте снова.';

  @override
  String get errorServerError => 'Ошибка сервера';

  @override
  String get errorServerErrorDesc =>
      'Внутренняя ошибка сервера. Пожалуйста, попробуйте еще раз.';

  @override
  String get errorServiceUnavailable => 'Служба недоступна';

  @override
  String get errorServiceUnavailableDesc =>
      'Служба временно недоступна. Сервер может перезапускаться — пожалуйста, попробуйте снова в ближайшее время.';

  @override
  String get fileActionAttachmentDataDecoded =>
      'Данные вложения не могут быть декодированы.';

  @override
  String get fileActionAttachmentPathEmpty => 'Путь к вложению пуст.';

  @override
  String get fileActionAttachmentPayloadEmpty =>
      'Полезная нагрузка вложения пуста.';

  @override
  String get fileActionAttachmentProvideValid =>
      'Вложение не указывает корректный путь.';

  @override
  String get fileActionAttachmentSavedDevice =>
      'Вложение не удалось сохранить на этом устройстве.';

  @override
  String fileActionAttachmentSavedOutputFile(String path) {
    return 'Вложение сохранено по пути $path и открыто.';
  }

  @override
  String fileActionAttachmentSavedOutputFile2(String path) {
    return 'Вложение сохранено по пути $path.';
  }

  @override
  String fileActionAttachmentSavedSavedPath(String savedPath) {
    return 'Вложение сохранено в $savedPath.';
  }

  @override
  String get fileActionLocalAttachmentFound =>
      'Локальное вложение не найдено на этом устройстве.';

  @override
  String get fileActionSaveCanceled => 'Сохранение отменено.';

  @override
  String get fileActionUnableOpenLocal =>
      'Не удалось открыть локальное вложение.';

  @override
  String get filesAddChat => 'Добавить в чат';

  @override
  String get filesAutosave => 'Автосохранение';

  @override
  String get filesAutosaveOn => 'Автосохранение включено';

  @override
  String get filesAutosaveOff => 'Автосохранение выключено';

  @override
  String get filesRedo => 'Повторить';

  @override
  String get filesUndo => 'Отменить';

  @override
  String get filesBinaryFilePreview =>
      'Предпросмотр бинарного файла недоступен.';

  @override
  String get filesClear => 'Очистить';

  @override
  String get filesContents => 'Содержимое';

  @override
  String get filesDuplicate => 'Дублировать';

  @override
  String get filesDuplicated => 'Файл продублирован';

  @override
  String get filesFileEmpty => 'Файл пуст.';

  @override
  String get filesAlreadyExists =>
      'Файл или папка с таким именем уже существуют.';

  @override
  String get filesCopyPath => 'Копировать путь';

  @override
  String get filesCreateFileTitle => 'Создать файл';

  @override
  String get filesCreateFolderTitle => 'Создать папку';

  @override
  String get filesDelete => 'Удалить';

  @override
  String filesDeleteConfirm(String name) {
    return 'Удалить $name? Это действие необратимо. Папки и их содержимое будут удалены.';
  }

  @override
  String filesDeleteTitle(String name) {
    return 'Удалить $name';
  }

  @override
  String get filesFilesFound => 'Файлы не найдены';

  @override
  String get filesFileCreated => 'Файл создан.';

  @override
  String get filesFolderCreated => 'Папка создана.';

  @override
  String get filesHideSidebar => 'Скрыть боковую панель файлов';

  @override
  String get filesInvalidName =>
      'Введите допустимое имя без разделителей пути.';

  @override
  String get filesNameHint => 'Имя';

  @override
  String get filesNew => 'Создать';

  @override
  String get filesNewFile => 'Новый файл';

  @override
  String get filesNewFolder => 'Новая папка';

  @override
  String get filesNames => 'Имена';

  @override
  String filesOpenFilesFileState(int length) {
    return 'Открытые файлы ($length)';
  }

  @override
  String get filesQuickOpen => 'Быстрое открытие';

  @override
  String get filesQuickOpenFile => 'Быстрое открытие файла';

  @override
  String get filesOperationFailed => 'Не удалось выполнить операцию с файлом.';

  @override
  String get filesOperationUnavailable =>
      'Операции с файлами недоступны для этого сервера.';

  @override
  String get filesOutsideRoot => 'Путь находится за пределами корня проекта.';

  @override
  String get filesPathCopied => 'Путь скопирован.';

  @override
  String get filesPathMissing => 'Путь не существует.';

  @override
  String get filesPermissionDenied => 'Отказано в доступе.';

  @override
  String get filesRefresh => 'Обновить файлы';

  @override
  String get filesRename => 'Переименовать';

  @override
  String filesRenameTitle(String name) {
    return 'Переименовать $name';
  }

  @override
  String get filesRenamed => 'Переименовано.';

  @override
  String get filesRootDeleteBlocked => 'Корень проекта не может быть удален.';

  @override
  String get filesSearchHint => 'Поиск файлов по имени или пути';

  @override
  String get filesDeleted => 'Удалено.';

  @override
  String get filesTitle => 'Файлы';

  @override
  String get forwardAction => 'Переслать';

  @override
  String get forwardAllFailed => 'Не удалось переслать ни в одну сессию';

  @override
  String get forwardCancel => 'Отмена';

  @override
  String get forwardDialogSubtitle => 'Выберите одну или несколько бесед';

  @override
  String get forwardDialogTitle => 'Переслать в…';

  @override
  String get forwardLoading => 'Загрузка сессий…';

  @override
  String get forwardNoOpenProjects => 'Нет открытых проектов с сессиями';

  @override
  String get forwardNoProviderModel =>
      'Выберите провайдера и модель перед пересылкой';

  @override
  String get forwardNoSessions => 'Нет недавних сессий';

  @override
  String forwardPartial(int success, int total) {
    return 'Переслано в $success из $total';
  }

  @override
  String forwardProvenanceLabel(String origin) {
    return 'Переслано из: $origin';
  }

  @override
  String get forwardRetry => 'Повторить';

  @override
  String get forwardSearchHint => 'Поиск';

  @override
  String forwardSelectedCount(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get forwardSend => 'Переслать';

  @override
  String get forwardServerOffline => 'Сервер недоступен';

  @override
  String get forwardShortcutHint => 'Ctrl+Shift+F';

  @override
  String forwardSuccess(int count) {
    return 'Переслано в $count сессий';
  }

  @override
  String get forwardUndo => 'Отменить';

  @override
  String get forwardUndoFailed => 'Не удалось отменить пересылку';

  @override
  String get logsAppLogs => 'Логи приложения';

  @override
  String get logsClear => 'Очистить логи';

  @override
  String get logsCloseSearch => 'Закрыть поиск';

  @override
  String get logsCopyFiltered => 'Копировать отфильтрованные логи';

  @override
  String get logsEnableLogging => 'Включить логи приложения';

  @override
  String get logsEnableLoggingAction => 'Включить логи';

  @override
  String get logsEnableLoggingDescription =>
      'Сохраняет диагностические логи в памяти. Оставляйте выключенным, если не устраняете проблему.';

  @override
  String get logsEntryContext => 'Контекст';

  @override
  String get logsEntryTags => 'Теги';

  @override
  String get logsFilterAll => 'Все';

  @override
  String get logsFilterByTag => 'Тег';

  @override
  String get logsLevel => 'Уровень';

  @override
  String get logsLoggingDisabledDescription =>
      'CodeWalk не собирает подробные логи приложения. Включайте логи только когда нужна диагностика.';

  @override
  String get logsLoggingDisabledTitle => 'Логи отключены';

  @override
  String get logsMeasurePerformance => 'Измерять производительность';

  @override
  String get logsMeasurePerformanceDescription =>
      'Записывает время дорогих операций приложения. Включайте только для диагностики задержек.';

  @override
  String get logsNoLogsYet => 'Логи пока не записаны.';

  @override
  String get logsNoMatchingLogs =>
      'Нет логов, соответствующих текущим фильтрам.';

  @override
  String get logsNoPerformanceData =>
      'Нет журналов производительности для текущих фильтров.';

  @override
  String get logsNoTaskData => 'Нет задач для текущих фильтров.';

  @override
  String logsPerformanceDuration(int elapsedMs) {
    return '$elapsedMs мс';
  }

  @override
  String get logsPerformanceFilter => 'Производительность';

  @override
  String logsPerformanceTileTitle(
    int elapsedMs,
    String operation,
    String status,
  ) {
    return 'ПРОИЗВОДИТЕЛЬНОСТЬ $operation | $elapsedMs мс | $status';
  }

  @override
  String get logsSearch => 'Закрыть поиск';

  @override
  String logsShowingOrderedLength(int length, int length2) {
    return 'Показано $length из $length2 записей';
  }

  @override
  String get logsSlowestPerformance =>
      'Самые медленные журналы производительности';

  @override
  String get logsSlowestTasks => 'Самые медленные задачи';

  @override
  String get logsTagCustomHint => 'Имя тега (например: task:select_session)';

  @override
  String get logsTagCustomAction => 'Своя...';

  @override
  String logsTaskDuration(int elapsedMs, String operation) {
    return '$operation — $elapsedMs мс';
  }

  @override
  String get logsTaskStatusCanceled => 'отменено';

  @override
  String get logsTaskStatusError => 'ошибка';

  @override
  String get logsTaskStatusOk => 'ok';

  @override
  String get logsTimeRange => 'Временной диапазон';

  @override
  String get mathExpressionLabel => 'Математика';

  @override
  String get mermaidCopySourceTooltip => 'Копировать исходный код';

  @override
  String get mermaidDiagramLabel => 'Диаграмма Mermaid';

  @override
  String get modelAuto => 'Авто';

  @override
  String get modelChooseAgent => 'Выбрать агента';

  @override
  String get modelFavorites => 'Избранное';

  @override
  String get modelFree => 'Бесплатно';

  @override
  String get modelLabelBaseEnglish => 'Base (английский)';

  @override
  String get modelLabelParakeet => 'Parakeet V3 (25 европейских языков)';

  @override
  String get modelLabelSenseVoice => 'SenseVoice (zh/en/ja/ko/yue)';

  @override
  String get modelLabelTinyEnglish => 'Tiny (английский)';

  @override
  String get modelLoadingModels => 'Загрузка моделей';

  @override
  String get modelModelsFound => 'Модели не найдены';

  @override
  String get modelRetryModels => 'Повторить загрузку моделей';

  @override
  String get modelSearchHint => 'Поиск модели или провайдера';

  @override
  String get msgBatterySettingsFailed =>
      'Не удалось открыть настройки оптимизации батареи Android.';

  @override
  String get msgBatterySettingsOpened =>
      'Настройки батареи Android открыты. Разрешите неограниченное использование батареи для CodeWalk.';

  @override
  String get msgClearUsernameNeedsConfigEdit =>
      'Очистка имени пользователя беседы OpenCode по-прежнему требует изменения конфигурации вне приложения.';

  @override
  String get msgCommandCopied => 'Команда скопирована';

  @override
  String get msgCopiedToClipboard => 'Скопировано в буфер обмена';

  @override
  String get msgEnterUsernameToSave =>
      'Введите имя пользователя, чтобы сохранить собственное название беседы OpenCode.';

  @override
  String get msgFailedToSendMessage =>
      'Не удалось отправить сообщение. Черновик сохранен для повторной попытки.';

  @override
  String get msgFailedToStartVoiceInput =>
      'Не удалось запустить голосовой ввод';

  @override
  String msgFilePathNotFound(String path) {
    return 'Файл не найден: $path';
  }

  @override
  String get msgFilteredLogsCopied =>
      'Отфильтрованные журналы скопированы в буфер обмена';

  @override
  String get msgInfoAgent => 'Агент';

  @override
  String get msgInfoCompaction => 'Сжатие';

  @override
  String msgInfoCost(String cost) {
    return 'Стоимость: \$$cost';
  }

  @override
  String get msgInfoMessageInfo => 'Информация о сообщении';

  @override
  String msgInfoModel(String modelId) {
    return 'Модель: $modelId';
  }

  @override
  String get msgInfoNoMetadata => 'Метаданные недоступны';

  @override
  String msgInfoPartDescriptionModel(String description, String model) {
    return '$description$model';
  }

  @override
  String get msgInfoPatch => 'Патч';

  @override
  String msgInfoProvider(String providerId) {
    return 'Провайдер: $providerId';
  }

  @override
  String get msgInfoRetry => 'Повторить';

  @override
  String get msgInfoSnapshot => 'Снимок';

  @override
  String msgInfoSubtaskPartAgent(String agent) {
    return 'Подзадача ($agent)';
  }

  @override
  String msgInfoTokens(int total) {
    return 'Токены: $total';
  }

  @override
  String get msgInfoUndoThisTurn => 'Отменить этот ход';

  @override
  String get msgInfoView => 'Просмотр';

  @override
  String get msgNoSystemSoundsFound =>
      'Системные звуки на этом устройстве не найдены.';

  @override
  String get msgNoValidFilesSelected => 'Не были выбраны корректные файлы';

  @override
  String get msgSomeSelectedFilesNotAttached =>
      'Некоторые выбранные файлы не удалось прикрепить.';

  @override
  String get msgReadAloud => 'Прочитать вслух';

  @override
  String get msgReadAloudNotAvailable =>
      'Синтез речи недоступен на этом устройстве.';

  @override
  String get msgSetupDebugCopied =>
      'Отладочные данные настройки OpenCode скопированы в буфер обмена';

  @override
  String get msgShareAsImage => 'Поделиться как изображением';

  @override
  String get msgShareAsImageFailed =>
      'Не удалось поделиться сообщением как изображением.';

  @override
  String get msgShareAsImageSubject => 'Сообщение CodeWalk';

  @override
  String get msgShareAsImageTooTall =>
      'Сообщение слишком длинное, чтобы делиться им как изображением.';

  @override
  String get msgStopReadAloud => 'Остановить чтение';

  @override
  String get msgSystemSoundPickerUnavailable =>
      'Выбор системного звука недоступен на этой платформе.';

  @override
  String get msgUpdatedButRefreshFailed =>
      'Настройки сервера обновлены, но не удалось обновить провайдеров чата.';

  @override
  String get msgVoiceInputUnavailable =>
      'Голосовой ввод недоступен на этом устройстве';

  @override
  String get notifAndroidBatteryOptimization => 'Оптимизация батареи Android';

  @override
  String get notifConversationUpdates => 'Обновления беседы';

  @override
  String get notifNotificationsArriveReopening =>
      'Если уведомления приходят только при открытии приложения, разрешите CodeWalk работать без ограничений оптимизации батареи.';

  @override
  String get notifResponseRunningKeep =>
      'Когда выполняется ответ, сохраняйте активность в реальном времени на короткое время после выхода из приложения.';

  @override
  String notifSelectedSoundLabel(String soundLabel) {
    return 'Выбрано: $soundLabel';
  }

  @override
  String get notificationAgentFinished => 'Агент завершил текущий ответ.';

  @override
  String get notificationConversationUpdates => 'Обновления беседы';

  @override
  String get notificationOpenToClear =>
      'Откройте эту беседу, чтобы очистить связанные уведомления.';

  @override
  String get notificationSession => 'Сессия';

  @override
  String get notificationSoundLoadFailed =>
      'Не удалось загрузить системные звуки Android';

  @override
  String get onboardingAIGeneratedTitles => 'Заголовки, созданные ИИ';

  @override
  String get onboardingAddServerLater =>
      'Вы можете добавить сервер позже в Настройки > Серверы.';

  @override
  String get onboardingAddedButHealthCheckFailed =>
      'Сервер добавлен, но проверка состояния не удалась. Возможно, он еще запускается.';

  @override
  String get onboardingAlmostInstallOpenCode =>
      'Почти готово. Сначала установите OpenCode, затем подключите CodeWalk к URL-адресу сервера.';

  @override
  String onboardingAppProviderLocalSetupLogsLength(int length, int length2) {
    return '$length строк логов настройки и $length2 событий настройки доступны на отдельном отладочном экране настройки.';
  }

  @override
  String get onboardingAuthenticate => 'Войти';

  @override
  String get onboardingAvailable => 'доступен';

  @override
  String get onboardingAvailableOnlyDesktop =>
      'Доступно только для десктопа (Linux/macOS/Windows).';

  @override
  String get onboardingBasicAuthTip =>
      'Включайте Basic Auth только если ваш сервер OpenCode защищен паролем.';

  @override
  String get onboardingChooseAnotherPath => 'Выбрать другой путь';

  @override
  String get onboardingChooseHowToSetup =>
      'Выберите способ настройки вашего сервера';

  @override
  String get onboardingClear => 'Очистить';

  @override
  String get onboardingCloudflareAuthFailed =>
      'Ошибка авторизации Cloudflare Access.';

  @override
  String get onboardingCodeWalkAppOpenCode =>
      'CodeWalk — это приложение. OpenCode — это движок, к которому оно подключается.';

  @override
  String get onboardingConnectRunningServer =>
      'Подключиться к работающему серверу';

  @override
  String get onboardingConnectionIssue => 'Проблема с подключением';

  @override
  String get onboardingConnectionSaved =>
      'Подключение к серверу успешно сохранено.';

  @override
  String get onboardingConnectionTips => 'Советы по подключению';

  @override
  String get onboardingConnectionUpdated =>
      'Подключение к серверу успешно обновлено.';

  @override
  String get onboardingContinue => 'Продолжить';

  @override
  String get onboardingContinueServerURL => 'Перейти к URL сервера';

  @override
  String get onboardingCopyLoginURL => 'Копировать URL входа';

  @override
  String get onboardingCouldNotVerify =>
      'Не удалось проверить подключение к серверу.';

  @override
  String get onboardingDefaultURLEmulator =>
      'URL по умолчанию, обратная петля эмулятора, авторизация и помощь в отладке.';

  @override
  String onboardingDesktopOnlyDiagnose(String appName) {
    return 'Только для десктопа: $appName может провести диагностику, установить и запустить OpenCode для вас.';
  }

  @override
  String get onboardingDetailedSetupEvents =>
      'Подробные события настройки были записаны для устранения неполадок.';

  @override
  String get onboardingDonShowAgain => 'Не показывать снова';

  @override
  String get onboardingDone => 'Готово';

  @override
  String get onboardingEditServer => 'Редактировать сервер';

  @override
  String get onboardingEditServerConnection =>
      'Редактировать подключение к серверу';

  @override
  String get onboardingEmulatorRemap =>
      'В эмуляторе Android адреса localhost и 127.0.0.1 автоматически перенаправляются на 10.0.2.2.';

  @override
  String get onboardingEnterServerUrl => 'Введите URL сервера';

  @override
  String get onboardingExisting => 'Использовать существующий';

  @override
  String get onboardingExplainInstallOpenCode =>
      'Объяснить, как установить OpenCode, запустить сервер и подключиться из CodeWalk.';

  @override
  String get onboardingFailed => 'Сбой';

  @override
  String get onboardingGoodOptionDesktop =>
      'Хороший первый вариант на десктопе';

  @override
  String get onboardingHealthCheckFailedMayBeStarting =>
      'Сбой проверки состояния сервера. Возможно, он еще запускается.';

  @override
  String get onboardingInstallBinary => 'Установить исполняемый файл';

  @override
  String get onboardingInstallBun => 'Установить через Bun';

  @override
  String get onboardingInstallBunOpenCode => 'Установить Bun + OpenCode';

  @override
  String get onboardingInstallNpm => 'Установить через npm';

  @override
  String get onboardingInstallRunOpenCode =>
      'Установите и запустите OpenCode прямо из CodeWalk на десктопе.';

  @override
  String get onboardingInvalidUrl => 'Некорректный URL';

  @override
  String get onboardingLabel => 'Ярлык (необязательно)';

  @override
  String get onboardingLabelHint => 'Мой сервер';

  @override
  String onboardingLatestOutputAppProvider(String localServerLastOutput) {
    return 'Последний вывод: $localServerLastOutput';
  }

  @override
  String get onboardingLetCodeWalkSet =>
      'Позволить CodeWalk настроить это локально';

  @override
  String get onboardingLocalServerSetup => 'Настройка локального сервера';

  @override
  String get onboardingManagedLocalServer => 'Управляемый локальный сервер';

  @override
  String get onboardingManagedLocalServer2 =>
      'Режим управляемого локального сервера доступен только на десктопных сборках (Linux/macOS/Windows).';

  @override
  String onboardingNeedsOpenCodeServer(String appName) {
    return 'Для работы $appName требуется сервер OpenCode.';
  }

  @override
  String get onboardingNotAvailable => 'недоступен';

  @override
  String get onboardingNotWritable => 'недоступен для записи';

  @override
  String get onboardingOpenCode => 'Что такое OpenCode?';

  @override
  String get onboardingOpenCodeRunningDevice =>
      'У меня уже запущен OpenCode на этом устройстве или в моей сети.';

  @override
  String get onboardingOpenCodeRunsLocally =>
      'OpenCode работает локально или на сервере и обеспечивает функции ИИ-кодинга в CodeWalk. Если OpenCode уже запущен, подключитесь к нему. Если нет, выберите один из пошаговых вариантов настройки ниже.';

  @override
  String get onboardingOpenTailscaleLogin =>
      'Не удалось открыть URL авторизации Tailscale.';

  @override
  String get onboardingPassword => 'Пароль';

  @override
  String get onboardingPasswordRequired => 'Введите пароль';

  @override
  String get onboardingPickSetupPath =>
      'Выберите способ настройки, соответствующий вашей конфигурации OpenCode.';

  @override
  String get onboardingPreconditionDirectoryNotWritable =>
      'Каталог установки недоступен для записи. Проверьте права доступа пользователя.';

  @override
  String get onboardingPreconditionInstallViaBunRecommendation =>
      'Разработчики OpenCode рекомендуют установку через Bun.';

  @override
  String get onboardingPreconditionNetworkFailed =>
      'Ошибка сетевого доступа. Проверьте подключение перед установкой OpenCode.';

  @override
  String get onboardingPreconditionNoRuntimeDetected =>
      'Среда выполнения не обнаружена. Установите исполняемый файл OpenCode напрямую или сначала настройте Bun.';

  @override
  String get onboardingPreconditionNodeNpmAvailable =>
      'Доступны Node + npm. Установите OpenCode через npm или установите Bun для рекомендуемого процесса.';

  @override
  String get onboardingPreconditionOpenCodeAlreadyAvailable =>
      'OpenCode уже доступен. Вы можете сразу использовать обнаруженную команду.';

  @override
  String get onboardingPreconditionWindowsPathLagHint =>
      ' В Windows обновите проверки после установки, так как обновления переменной PATH могут применяться с задержкой в уже открытых приложениях.';

  @override
  String get onboardingPreconditionWindowsWslRecommendation =>
      'Обнаружена сборка Windows. В документации OpenCode рекомендуется использовать WSL, но в качестве альтернативы можно использовать npm install.';

  @override
  String get onboardingReachable => 'доступен по сети';

  @override
  String get onboardingReady => 'Готово';

  @override
  String get onboardingRecommendedOrderTry =>
      'Рекомендуемый порядок: попробуйте «Установить Bun + OpenCode», если хотите, чтобы CodeWalk настроил все за вас. Используйте «Использовать существующий», если OpenCode уже установлен.';

  @override
  String get onboardingRefreshChecks => 'Обновить проверки';

  @override
  String get onboardingRunDiagnosticsToVerify =>
      'Запустите диагностику для проверки требований к локальному OpenCode.';

  @override
  String get onboardingSaveAndTest => 'Сохранить и протестировать';

  @override
  String get onboardingServerConnectedReady =>
      'Ваш сервер подключен и готов к работе.';

  @override
  String get onboardingServerConnection => 'Подключение к серверу';

  @override
  String get onboardingServerSettingsSaved =>
      'Настройки вашего сервера сохранены, статус состояния обновлен.';

  @override
  String get onboardingServerSetup => 'Настройка сервера';

  @override
  String get onboardingServerUpdated => 'Сервер обновлен';

  @override
  String get onboardingServerUrl => 'URL сервера';

  @override
  String get onboardingSetup => 'Настройка';

  @override
  String get onboardingSetupWizard => 'Мастер настройки';

  @override
  String get onboardingShowSetupSteps => 'Показать шаги настройки';

  @override
  String get onboardingShowSetupSteps2 => 'Показать шаги настройки';

  @override
  String get onboardingSkip => 'Пропустить пока';

  @override
  String get onboardingSkipSetup => 'Пропустить настройку?';

  @override
  String get onboardingStart => 'Запустить';

  @override
  String onboardingStartUsing(String appName) {
    return 'Начать использование $appName';
  }

  @override
  String get onboardingStarting => 'Запуск';

  @override
  String get onboardingStop => 'Остановить';

  @override
  String get onboardingStopped => 'Остановлен';

  @override
  String get onboardingStopping => 'Остановка';

  @override
  String onboardingSuggestedUrl(String url) {
    return 'Предлагаемый URL локального сервера OpenCode: $url';
  }

  @override
  String get onboardingTailscaleAdminApproval =>
      'Требуется одобрение администратора Tailscale';

  @override
  String get onboardingTailscaleAuthAfterSave =>
      'Авторизация в Tailscale произойдет после сохранения';

  @override
  String onboardingTailscaleAuthAfterSaveTest(String appName) {
    return 'После сохранения настроек и тестирования сервера $appName откроет окно входа в Tailscale, если устройство еще не авторизовано.';
  }

  @override
  String get onboardingTailscaleConnected => 'Tailscale подключен';

  @override
  String get onboardingTailscaleConnecting => 'Подключение к Tailscale';

  @override
  String get onboardingTailscaleConnectionFailed =>
      'Не удалось подключиться к Tailscale';

  @override
  String get onboardingTailscaleLoginRequired =>
      'Требуется авторизация в Tailscale';

  @override
  String get onboardingTailscaleOpenLoginUrl =>
      'Откройте URL входа, чтобы добавить устройство в сеть Tailscale. Если страница в браузере не открылась, скопируйте ссылку ниже.';

  @override
  String get onboardingTailscaleUnsupported => 'Tailscale не поддерживается';

  @override
  String get onboardingTestConnection => 'Проверить подключение';

  @override
  String get onboardingTesting => 'Тестирование...';

  @override
  String get onboardingUnreachable => 'недоступен по сети';

  @override
  String get onboardingUseBasicAuth => 'Использовать Basic Auth';

  @override
  String get onboardingUsername => 'Имя пользователя';

  @override
  String get onboardingUsernameRequired => 'Введите имя пользователя';

  @override
  String get onboardingUsesServerTitle =>
      'Использует агент заголовков на вашем сервере для именования бесед';

  @override
  String get onboardingUsingDetectedCommand =>
      'Используется обнаруженная команда OpenCode.';

  @override
  String get onboardingViewSetupDebug => 'Просмотр отладки настройки';

  @override
  String onboardingWelcomeTo(String appName) {
    return 'Добро пожаловать в $appName';
  }

  @override
  String get onboardingWindowsTipInstalling =>
      'Совет для Windows: после установки нажмите «Обновить проверки». Если обнаружение все еще не работает, перезапустите CodeWalk, чтобы обновить изменения в PATH.';

  @override
  String get onboardingWritable => 'доступен для записи';

  @override
  String get onboardingYoureAllSet => 'Все готово!';

  @override
  String get permissionAllowOnce => 'Разрешить один раз';

  @override
  String get permissionAlways => 'Всегда';

  @override
  String get permissionBack => 'Назад';

  @override
  String get permissionConfirmReject => 'Подтвердить отклонение';

  @override
  String get permissionReject => 'Отклонить';

  @override
  String get permissionReopen => 'Открыть заново';

  @override
  String get questionAnswerSelected => 'Ответ не выбран.';

  @override
  String get questionCommaSeparatedValues => 'Значения через запятую';

  @override
  String get questionQuestionGroupMarked =>
      'Группа вопросов отклонена. Вы можете продолжить общение и повторно открыть эту группу в любое время перед подтверждением.';

  @override
  String get questionQuestionRequest => 'Запрос вопроса';

  @override
  String get questionQuestionsProvidedSubmit =>
      'Вопросы не предоставлены. Вы можете отправить пустой ответ.';

  @override
  String get questionReviewAnswersSubmitting =>
      'Проверьте свои ответы перед отправкой.';

  @override
  String get quotaAuthCookie => 'Cookie авторизации';

  @override
  String get quotaConnect => 'Подключить';

  @override
  String get quotaForget => 'Забыть';

  @override
  String get quotaOpenCodeGoConnectDescription =>
      'Подключите дашборд использования, чтобы показывать скользящие, недельные и месячные лимиты.';

  @override
  String get quotaOpenCodeGoDetected => 'Обнаружен OpenCode Go';

  @override
  String get quotaOpenCodeGoNeedsReconnect =>
      'OpenCode Go нужно подключить повторно';

  @override
  String get quotaOpenCodeGoReconnectDescription =>
      'Обновите учетные данные дашборда, чтобы восстановить полосы использования.';

  @override
  String get quotaOpenCodeGoUsage => 'Использование OpenCode Go';

  @override
  String get quotaOpenDashboard => 'Открыть дашборд OpenCode';

  @override
  String get quotaPaceExplanation =>
      'Темп прогнозирует общий расход к концу текущего окна лимита на основе текущей скорости.';

  @override
  String quotaPacePercent(String percent) {
    return 'Темп $percent%';
  }

  @override
  String get quotaRateLimits => 'Лимиты использования';

  @override
  String get quotaReconnect => 'Подключить повторно';

  @override
  String get quotaRefreshing => 'Обновление...';

  @override
  String quotaResetsIn(String time) {
    return 'Сброс через $time';
  }

  @override
  String get quotaSaving => 'Сохранение...';

  @override
  String get quotaWorkspaceId => 'ID рабочей области';

  @override
  String get serverClearOAuth => 'Очистить OAuth';

  @override
  String get serverConnectionAttention =>
      'Подключение к серверу требует внимания.';

  @override
  String get serverHealthHealthy => 'Здоров';

  @override
  String get serverHealthUnhealthy => 'Неисправен';

  @override
  String get serverHealthUnknown => 'Неизвестно';

  @override
  String get serverOAuthAuthFailed => 'Ошибка авторизации OAuth';

  @override
  String get serverOAuthChip => 'OAuth';

  @override
  String get serverOAuthNotSupported =>
      'Cloudflare Access OAuth не поддерживается на этой платформе';

  @override
  String get serverReauthenticate => 'Повторно авторизоваться';

  @override
  String get serverTailscaleChip => 'Tailscale';

  @override
  String get serversActive => 'Активные';

  @override
  String get serversActiveServer => 'Активный сервер';

  @override
  String get serversAddLeastOpenCode =>
      'Добавьте хотя бы один сервер OpenCode, чтобы начать использовать приложение.';

  @override
  String get serversAddServer => 'Добавить сервер';

  @override
  String get serversCancel => 'Отмена';

  @override
  String get serversCannotActivateUnhealthy =>
      'Невозможно активировать неисправный сервер';

  @override
  String get serversCheckHealth => 'Проверить состояние';

  @override
  String get serversClearDefault => 'Сбросить по умолчанию';

  @override
  String serversCommandAppProviderLocalServerCommandPath(
    String localServerCommandPath,
  ) {
    return 'Команда: $localServerCommandPath';
  }

  @override
  String get serversCopy => 'Копировать';

  @override
  String get serversDefault => 'По умолчанию';

  @override
  String get serversDelete => 'Удалить';

  @override
  String get serversDeleteServer => 'Удалить сервер';

  @override
  String get serversDesktopModeExplanation =>
      'Десктопный режим позволяет запускать и управлять `opencode serve` напрямую из CodeWalk.';

  @override
  String get serversEdit => 'Редактировать';

  @override
  String get serversLocalOpenCodeServer => 'Локальный сервер OpenCode';

  @override
  String get serversManagedModeAvailable =>
      'Этот управляемый режим доступен только в десктопных сборках (Linux/macOS/Windows).';

  @override
  String get serversNoServersFound => 'Серверы не найдены';

  @override
  String get serversRefreshHealth => 'Обновить состояние';

  @override
  String serversRemoveProfileDisplayName(String displayName) {
    return 'Удалить \"$displayName\"?';
  }

  @override
  String get serversSearchActiveHint => 'Поиск активного сервера';

  @override
  String get serversServersConfigured => 'Серверы не настроены';

  @override
  String get serversSetActive => 'Сделать активным';

  @override
  String get serversSetDefault => 'Сделать по умолчанию';

  @override
  String get serversSetupDebug => 'Отладка настройки';

  @override
  String get serversSetupWizard => 'Мастер настройки';

  @override
  String get serversTailscaleAdminApprovalRequired =>
      'Требуется одобрение администратора Tailscale';

  @override
  String get serversTailscaleAuthRequired => 'Требуется авторизация Tailscale';

  @override
  String get serversTailscaleConnectExplanation =>
      'Tailscale подключится при использовании этого активного профиля.';

  @override
  String get serversTailscaleConnected => 'Tailscale подключен';

  @override
  String get serversTailscaleConnecting => 'Подключение к Tailscale';

  @override
  String get serversTailscaleConnectionFailed =>
      'Не удалось подключиться к Tailscale';

  @override
  String get serversTailscaleDisconnected => 'Tailscale отключен';

  @override
  String get serversTailscaleLoginExplanation =>
      'Откройте URL входа в Tailscale, чтобы добавить это устройство в вашу сеть Tailscale.';

  @override
  String get serversTailscaleTrafficExplanation =>
      'Трафик OpenCode для этого активного профиля маршрутизируется через Tailscale.';

  @override
  String get serversTailscaleUnsupported => 'Tailscale не поддерживается';

  @override
  String get serversUnhealthyActivateError =>
      'Этот сервер неисправен. Проверьте состояние или отредактируйте настройки перед активацией.';

  @override
  String get sessionActionArchived => 'архивировано';

  @override
  String get sessionActionDeleted => 'удалено';

  @override
  String get sessionActionForked => 'ответвлено';

  @override
  String get sessionActionPinned => 'закреплено';

  @override
  String get sessionActionUnarchived => 'разархивировано';

  @override
  String get sessionActionUnpinned => 'откреплено';

  @override
  String get sessionArchive => 'В архив';

  @override
  String get sessionCancelRename => 'Отменить переименование';

  @override
  String sessionChildrenCount(int count) {
    return 'Дочерние элементы: $count';
  }

  @override
  String get sessionCompactContext => 'Сжать контекст';

  @override
  String get sessionCopyLink => 'Копировать ссылку';

  @override
  String get sessionDelete => 'Удалить';

  @override
  String sessionDeleteConfirm(String title) {
    return 'Вы уверены, что хотите удалить беседу \"$title\"? Это действие нельзя отменить.';
  }

  @override
  String get sessionDeleteTitle => 'Удалить беседу';

  @override
  String get sessionDiffChangedFile => 'Измененный файл';

  @override
  String get sessionDiffContentNotCaptured =>
      'Содержимое файла не захвачено сервером';

  @override
  String sessionDiffFilesChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Изменено $count файлов',
      one: 'Изменен 1 файл',
    );
    return '$_temp0';
  }

  @override
  String sessionDiffFilesCount(int count) {
    return 'Измененные файлы: $count';
  }

  @override
  String sessionDiffLinesAddedRemoved(int added, int removed) {
    return '+$added строк добавлено -$removed строк удалено';
  }

  @override
  String sessionDiffLinesCollapsed(int count) {
    return '$count строк свернуто — нажмите, чтобы развернуть';
  }

  @override
  String get sessionDiffLoading => 'Загрузка измененных файлов…';

  @override
  String get sessionDiffReview => 'Просмотр изменений';

  @override
  String get sessionDiffSplit => 'Разделенный';

  @override
  String get sessionDiffSummary => 'Сводка';

  @override
  String get sessionDiffUnified => 'Объединенный';

  @override
  String get sessionExportAssistant => 'Ассистент';

  @override
  String get sessionExportCanceled => 'Экспорт сессии отменен';

  @override
  String get sessionExportDebugJson => 'Экспорт отладочного JSON';

  @override
  String get sessionExportDebugJsonErrorClipboard =>
      'Не удалось сохранить файл; отладочный JSON скопирован в буфер обмена';

  @override
  String get sessionExportDebugJsonSaved =>
      'Экспорт в отладочный JSON сохранен';

  @override
  String get sessionExportDebugJsonTitle =>
      'Экспортировать сессию в отладочный JSON';

  @override
  String get sessionExportError => 'Ошибка:';

  @override
  String get sessionExportInput => 'Ввод:';

  @override
  String get sessionExportMarkdown => 'Экспорт в Markdown';

  @override
  String get sessionExportMarkdownErrorClipboard =>
      'Не удалось сохранить файл; Markdown скопирован в буфер обмена';

  @override
  String get sessionExportMarkdownSaved => 'Экспорт в Markdown сохранен';

  @override
  String get sessionExportMarkdownTitle => 'Экспортировать сессию в Markdown';

  @override
  String get sessionExportOutput => 'Вывод:';

  @override
  String get sessionExportUntitled => 'Сессия без названия';

  @override
  String get sessionExportUser => 'Пользователь';

  @override
  String get sessionFailedRename => 'Не удалось переименовать беседу';

  @override
  String get sessionFailedUpdateArchive =>
      'Не удалось обновить статус архивирования';

  @override
  String get sessionFailedUpdateSharing =>
      'Не удалось обновить статус общего доступа';

  @override
  String get sessionFork => 'Создать ответвление';

  @override
  String get sessionForkFailed => 'Не удалось создать ответвление беседы';

  @override
  String get sessionForked => 'Ответвление беседы создано';

  @override
  String sessionHasError(String title) {
    return 'Ошибка в беседе \"$title\".';
  }

  @override
  String sessionHasNewReply(String title) {
    return 'В беседе \"$title\" появился новый ответ.';
  }

  @override
  String get sessionKeyboardShortcuts => 'Горячие клавиши';

  @override
  String sessionNeedsInput(String title) {
    return 'Беседа \"$title\" требует вашего ввода.';
  }

  @override
  String get sessionNoCachedConversations => 'Кэшированных бесед пока нет';

  @override
  String get sessionNoConversationsInProject => 'В этом проекте нет бесед.';

  @override
  String get sessionNotAvailable => 'Беседа еще не доступна для этого проекта';

  @override
  String get sessionOpenProjectToLoad => 'Открыть проект для загрузки бесед.';

  @override
  String get sessionPin => 'Закрепить';

  @override
  String get sessionRename => 'Переименовать';

  @override
  String get sessionRenameHint => 'Введите новое имя беседы';

  @override
  String get sessionRenameTitle => 'Переименовать беседу';

  @override
  String get sessionSaveTitle => 'Сохранить название';

  @override
  String get sessionShare => 'Поделиться сессией';

  @override
  String get sessionShareAction => 'Поделиться';

  @override
  String get sessionShareLinkCopied => 'Ссылка скопирована';

  @override
  String get sessionShareLinkUnavailable =>
      'Ссылка общего доступа недоступна для этой сессии';

  @override
  String get sessionShared => 'Общий доступ к беседе предоставлен';

  @override
  String get sessionSyncing => 'Синхронизация бесед...';

  @override
  String get sessionTitleHint => 'Название беседы';

  @override
  String get sessionUnarchive => 'Из архива';

  @override
  String get sessionUnpin => 'Открепить';

  @override
  String get sessionUnshare => 'Отменить общий доступ к сессии';

  @override
  String get sessionUnshareAction => 'Закрыть доступ';

  @override
  String get sessionUnshared => 'Общий доступ к беседе отменен';

  @override
  String get sessionViewTasks => 'Посмотреть задачи';

  @override
  String get settingsAboutCheckForUpdates => 'Проверить обновления';

  @override
  String get settingsAboutCheckOnOpen => 'Проверять обновления при запуске';

  @override
  String get settingsAboutCheckOnOpenDescription =>
      'Автоматически проверять обновления при запуске приложения';

  @override
  String get settingsAboutChecking => 'Проверка...';

  @override
  String get settingsAboutDescription =>
      'Версия, обновления, справка и данные приложения';

  @override
  String get settingsAboutDismiss => 'Закрыть';

  @override
  String settingsAboutDownloading(String percent) {
    return 'Загрузка... $percent%';
  }

  @override
  String get settingsAboutEraseAllData => 'Стереть все данные и перезапустить';

  @override
  String get settingsAboutInstallUpdate => 'Установить обновление';

  @override
  String get settingsAboutInstalling => 'Установка...';

  @override
  String settingsAboutLatestVersion(String version) {
    return 'v$version — последняя версия';
  }

  @override
  String get settingsAboutLoading => 'Загрузка...';

  @override
  String get settingsAboutReplayChatTour => 'Повторить знакомство с чатом';

  @override
  String get settingsAboutReplayChatTourDescription =>
      'Закрыть настройки и показать интерактивное руководство по чату';

  @override
  String get settingsAboutResetApp => 'Сбросить приложение';

  @override
  String get settingsAboutResetAppQuestion => 'Сбросить приложение?';

  @override
  String get settingsAboutResetAppWarning =>
      'Это сотрет все серверы, настройки и кэшированные данные. Это действие нельзя отменить.';

  @override
  String get settingsAboutRetryInstall => 'Повторить установку';

  @override
  String get settingsAboutTapToCheck => 'Нажмите для проверки новых версий';

  @override
  String get settingsAboutTitle => 'О программе';

  @override
  String get settingsAboutUpToDate => 'Установлена последняя версия';

  @override
  String settingsAboutUpdateAvailable(String version) {
    return 'Доступно обновление: v$version';
  }

  @override
  String get settingsAboutUpdateInstalled =>
      'Обновление установлено. Перезапустите приложение для применения.';

  @override
  String settingsAboutUpdateVersionSummary(
    String installedVersion,
    String latestVersion,
  ) {
    return 'Текущая: $installedVersion; доступна: v$latestVersion';
  }

  @override
  String get settingsAboutVersion => 'Версия';

  @override
  String settingsAboutVersionBuild(String buildNumber, String version) {
    return '$version (сборка $buildNumber)';
  }

  @override
  String get settingsAppearanceAmoledDark => 'AMOLED темный режим';

  @override
  String get settingsAppearanceAmoledDarkActive =>
      'Использовать чисто черные поверхности при активном темном режиме.';

  @override
  String get settingsAppearanceAmoledDarkInactive =>
      'Переключитесь в темный режим, чтобы включить поверхности AMOLED.';

  @override
  String get settingsAppearanceBrandColor => 'Фирменный цвет';

  @override
  String get settingsAppearanceBrandColorDynamicBlocked =>
      'Отключите цвета обоев, чтобы выбрать фирменный цвет.';

  @override
  String get settingsAppearanceBrandColorNormal =>
      'Выберите базовый цвет для палитры приложения.';

  @override
  String get settingsAppearanceBrandColorPresetBlocked =>
      'Переключитесь на CodeWalk Classic, чтобы выбрать фирменный цвет.';

  @override
  String get settingsAppearanceChatFontScale => 'Размер текста беседы';

  @override
  String get settingsAppearanceChatFontScaleDescription =>
      'Масштабирует текст сообщений чата и редактора поверх системного размера текста.';

  @override
  String get settingsAppearanceCodeWalkClassic => 'CodeWalk Classic';

  @override
  String get settingsAppearanceComposerTips => 'Подсказки в редакторе';

  @override
  String get settingsAppearanceComposerTipsDescription =>
      'Показывать или скрывать сменяющиеся подсказки, пока ассистент рассуждает.';

  @override
  String get settingsAppearanceContrast => 'Контрастность';

  @override
  String get settingsAppearanceContrastDynamicBlocked =>
      'Отключите цвета обоев, чтобы настроить контрастность.';

  @override
  String get settingsAppearanceContrastHigh => 'Высокая';

  @override
  String get settingsAppearanceContrastNormal =>
      'Настройте уровень контрастности цветовой схемы.';

  @override
  String get settingsAppearanceContrastPresetBlocked =>
      'Переключитесь на CodeWalk Classic, чтобы настроить контрастность.';

  @override
  String get settingsAppearanceContrastReduced => 'Сниженная';

  @override
  String get settingsAppearanceDark => 'Темная';

  @override
  String get settingsAppearanceDensity => 'Плотность';

  @override
  String get settingsAppearanceDensityDense => 'Высокая плотность';

  @override
  String get settingsAppearanceDensityDescription =>
      'Применить плотность расположения элементов и отступов в приложении.';

  @override
  String get settingsAppearanceDensityExtraDense => 'Очень высокая плотность';

  @override
  String get settingsAppearanceDensityExtraSpacious => 'Очень просторная';

  @override
  String get settingsAppearanceDensityNormal => 'Обычная';

  @override
  String get settingsAppearanceDensitySpacious => 'Просторная';

  @override
  String get settingsAppearanceDescription =>
      'Выбор темы, цветов, размера текста и отображения чата';

  @override
  String get settingsAppearanceFontSize => 'Размер текста';

  @override
  String get settingsAppearanceFontSizeDescription =>
      'Настраивает размер системного текста, текста бесед и текста терминала.';

  @override
  String get settingsAppearanceLight => 'Светлая';

  @override
  String get settingsAppearanceMathRendering => 'Отображение формул';

  @override
  String get settingsAppearanceMathRenderingDescription =>
      'Отображать математические выражения LaTeX (\\\$…\\\$ и \\\$\\\$…\\\$\\\$) в виде отформатированных формул в сообщениях чата.';

  @override
  String get settingsAppearanceNoPresets =>
      'Предустановленные палитры не найдены';

  @override
  String get settingsAppearanceOpenCodePresets => 'Предустановки OpenCode';

  @override
  String get settingsAppearancePresetHelper =>
      'Дублирует список встроенных тем официального веб-интерфейса OpenCode.';

  @override
  String get settingsAppearancePresetNote =>
      'Цвета темы теперь соответствуют официальному реестру OpenCode Web и также определяют оформление поверхностей разметки и кода.';

  @override
  String get settingsAppearancePresetPalette => 'Предустановленная палитра';

  @override
  String get settingsAppearanceSearchPreset =>
      'Поиск предустановленной палитры';

  @override
  String get settingsAppearanceSectionDescription =>
      'Настройте плотность элементов интерфейса и экраны сообщений под свой рабочий процесс.';

  @override
  String get settingsAppearanceSectionTitle => 'Внешний вид';

  @override
  String get settingsAppearanceSystem => 'Системная';

  @override
  String get settingsAppearanceSystemFontScale => 'Системный размер текста';

  @override
  String get settingsAppearanceSystemFontScaleDescription =>
      'Масштабирует весь текст оболочки приложения, включая меню, диалоги и боковые панели.';

  @override
  String get settingsAppearanceTaskList => 'Список задач';

  @override
  String get settingsAppearanceTaskListDescription =>
      'Показывать или скрывать виджет списка задач сессии.';

  @override
  String get settingsAppearanceTerminalFontSize => 'Размер текста терминала';

  @override
  String get settingsAppearanceTerminalFontSizeDescription =>
      'Изменяет размер шрифта встроенного терминала. Применяется немедленно к запущенным сессиям.';

  @override
  String get settingsAppearanceTheme => 'Тема';

  @override
  String get settingsAppearanceThemeDescription =>
      'Выберите светлый, темный или системный режим, а затем сохраните классическую палитру CodeWalk или переключитесь на предустановку OpenCode.';

  @override
  String get settingsAppearanceVisualStyle => 'Визуальный стиль';

  @override
  String get settingsAppearanceVisualStyleDescription =>
      'Выберите классический вид или более мягкие улучшенные поверхности.';

  @override
  String get settingsAppearanceVisualStyleClassic => 'Классический';

  @override
  String get settingsAppearanceVisualStyleRefined => 'Улучшенный';

  @override
  String get settingsAppearanceThinkingBubbles => 'Размышления';

  @override
  String get settingsAppearanceThinkingBubblesDescription =>
      'Показывать или скрывать блоки рассуждений в сообщениях ассистента.';

  @override
  String get settingsAppearanceTitle => 'Внешний вид';

  @override
  String get settingsAppearanceToolCallBubbles => 'Вызовы инструментов';

  @override
  String get settingsAppearanceToolCallBubblesDescription =>
      'Показывать или скрывать карточки выполнения инструментов в сообщениях ассистента.';

  @override
  String get settingsAppearanceWallpaperColors => 'Использовать цвета обоев';

  @override
  String get settingsAppearanceWallpaperNormal =>
      'Извлекать цветовую схему из обоев вашего устройства.';

  @override
  String get settingsAppearanceWallpaperPresetBlocked =>
      'Переключитесь на CodeWalk Classic, чтобы использовать цвета обоев.';

  @override
  String get settingsAppearanceWindowChrome => 'Вкладки окна';

  @override
  String get settingsAppearanceWindowChromeDescription =>
      'Выберите, как вкладки сессий сочетаются с заголовком окна на десктопе.';

  @override
  String get settingsAppearanceWindowChromeIntegrated => 'Встроенные вкладки';

  @override
  String get settingsAppearanceWindowChromeIntegratedDescription =>
      'Вкладки расположены вверху окна, системный заголовок скрыт.';

  @override
  String get settingsAppearanceWindowChromeSystem => 'Системное оформление';

  @override
  String get settingsAppearanceWindowChromeSystemDescription =>
      'Сохраняет системный заголовок и показывает вкладки под панелью приложения.';

  @override
  String get settingsBack => 'Назад';

  @override
  String get settingsBehaviorAutoupdateCaveat =>
      'Используйте раздел «О программе» для проверки релизов CodeWalk. Эта настройка лишь дублирует официальную конфигурацию `autoupdate` OpenCode.';

  @override
  String get settingsBehaviorAutoupdateHelp =>
      'Управляет обновлениями среды выполнения OpenCode, а не проверками обновлений приложения CodeWalk.';

  @override
  String get settingsBehaviorCellularDataSaver => 'Экономия мобильного трафика';

  @override
  String get settingsBehaviorChatRenderMode => 'Режим отображения чата';

  @override
  String get settingsBehaviorChatRenderModeBlock => 'Блок';

  @override
  String get settingsBehaviorChatRenderModeBlockDescription =>
      'Скрывает живой текст ассистента, рассуждения и карточки инструментов, пока текущий ход не будет показан единым блоком.';

  @override
  String get settingsBehaviorChatRenderModeDescription =>
      'Выберите, появляются ли ответы ассистента по мере передачи или раскрываются после завершения текущего хода.';

  @override
  String get settingsBehaviorChatRenderModeLive => 'В реальном времени';

  @override
  String get settingsBehaviorChatRenderModeLiveDescription =>
      'Показывает текст ассистента, рассуждения и активность инструментов по мере передачи событий OpenCode.';

  @override
  String get settingsBehaviorComposerSpellCheck =>
      'Проверка орфографии в редакторе';

  @override
  String get settingsBehaviorComposerSpellCheckDescription =>
      'Использовать встроенную проверку орфографии платформы, подсказки и автозамену в редакторе чата.';

  @override
  String get settingsBehaviorConfigDeferred =>
      'CodeWalk применит эту настройку OpenCode после завершения текущего ответа.';

  @override
  String settingsBehaviorConfigUpdateFailed(String field) {
    return 'Не удалось обновить OpenCode $field.';
  }

  @override
  String get settingsBehaviorConversationUsername =>
      'Имя пользователя для бесед';

  @override
  String get settingsBehaviorConversationUsernameHelp =>
      'Пользовательское имя, отображаемое в беседах вместо системного имени пользователя.';

  @override
  String get settingsBehaviorDataSaverActive =>
      'Активно сейчас при использовании мобильного интернета.';

  @override
  String get settingsBehaviorDataSaverCellularOnly =>
      'Применяется только при мобильном подключении.';

  @override
  String get settingsBehaviorDataSaverDescription =>
      'Сокращает автоматическое использование мобильных данных, останавливая фоновые загрузки и ограничивая автоматические обновления в фоновом режиме.';

  @override
  String get settingsBehaviorDataSaverWaiting =>
      'Ожидание следующего окна синхронизации мобильных данных.';

  @override
  String get settingsBehaviorDefaultAgent => 'Агент по умолчанию';

  @override
  String get settingsBehaviorDefaultAgentHelp =>
      'Основной агент, используемый, когда агент не выбран явно.';

  @override
  String get settingsBehaviorDefaultModel => 'Модель по умолчанию';

  @override
  String get settingsBehaviorDefaultModelHelp =>
      'Доступно клиентам OpenCode через конфигурацию.';

  @override
  String get settingsBehaviorDescription =>
      'Управление языком, поведением чата, данными и параметрами OpenCode по умолчанию';

  @override
  String get settingsBehaviorEnableDataSaver =>
      'Включить экономию мобильного трафика';

  @override
  String get settingsBehaviorMultiDeviceSync =>
      'Включить экспериментальную синхронизацию между устройствами';

  @override
  String get settingsBehaviorMultiDeviceSyncDescription =>
      'Синхронизировать выбор редактора (агент/модель/вариант) с активной конфигурацией сервера.';

  @override
  String get settingsBehaviorMultiDeviceSyncWarning =>
      'Может прервать текущие сессии при работе в нескольких сессиях одновременно.';

  @override
  String get settingsBehaviorNoAgents => 'Агенты не найдены';

  @override
  String get settingsBehaviorNoModels => 'Модели не найдены';

  @override
  String get settingsBehaviorOpenCodeAutoupdate => 'Автообновление OpenCode';

  @override
  String get settingsBehaviorOpenCodeDefaults =>
      'Значения по умолчанию на базе OpenCode';

  @override
  String get settingsBehaviorOpenCodeDefaultsDescription =>
      'Эти значения записываются в `/config` на активном сервере и соответствуют официальной общей конфигурации OpenCode.';

  @override
  String get settingsBehaviorOpenCodeSnapshots => 'Снимки OpenCode';

  @override
  String get settingsBehaviorOpenCodeSnapshotsDescription =>
      'Оставить включенными снимки на базе git для отмены/повтора действий и истории восстановления.';

  @override
  String get settingsBehaviorPermissionDeferred =>
      'Расширенное редактирование правил разрешений пока не включено в Настройки и отложено для последующей работы по достижению паритета.';

  @override
  String get settingsBehaviorPermissionProvenance =>
      'Происхождение обработки разрешений';

  @override
  String get settingsBehaviorPermissionProvenanceDescription =>
      'Официальная политика разрешений OpenCode настраивается в `opencode.json` с правилами allow/ask/deny для каждого инструмента. CodeWalk сохраняет официальные карточки запроса разрешений и добавляет одно одобренное исключение ADR-023: переключатель автоодобрения в редакторе безусловно отвечает `Always` и `remember: true` для создания постоянных разрешений в рамках сессии и поддерживает тот же путь непрерывности в рамках потока в фоновом воркере Android.';

  @override
  String get settingsBehaviorRefreshDefaults =>
      'Обновить значения по умолчанию';

  @override
  String get settingsBehaviorSaveUsername => 'Сохранить имя пользователя';

  @override
  String get settingsBehaviorSearchAutoupdate => 'Поиск режима автообновления';

  @override
  String get settingsBehaviorSearchDefaultAgent => 'Поиск агента по умолчанию';

  @override
  String get settingsBehaviorSearchDefaultModel => 'Поиск модели по умолчанию';

  @override
  String get settingsBehaviorSearchShareMode => 'Поиск режима общего доступа';

  @override
  String get settingsBehaviorSearchSmallModel => 'Поиск малой модели';

  @override
  String get settingsBehaviorShareMode =>
      'Режим общего доступа OpenCode по умолчанию';

  @override
  String get settingsBehaviorShareModeCaveat =>
      'Используйте действие общего доступа на уровне чата, чтобы опубликовать одну сессию сейчас. Эта настройка меняет только политику общего доступа OpenCode по умолчанию.';

  @override
  String get settingsBehaviorShareModeHelp =>
      'Управляет официальной глобальной конфигурацией `share`, а не кнопкой общего доступа для отдельного чата.';

  @override
  String get settingsBehaviorSmallModel => 'Малая модель';

  @override
  String get settingsBehaviorSmallModelAutoFallback => 'Автоматический откат';

  @override
  String get settingsBehaviorSmallModelFallbackActive =>
      'Автоматический откат OpenCode активен, так как `small_model` не задана.';

  @override
  String get settingsBehaviorSmallModelHelp =>
      'Используется для легких задач, таких как генерация заголовков.';

  @override
  String get settingsBehaviorSmallModelResetCaveat =>
      'Сброс `small_model` к автоматическому откату по-прежнему требует редактирования конфигурации вне приложения, поскольку обновления патчей `/config` не могут удалять ключи.';

  @override
  String get settingsBehaviorSnapshotCaveat =>
      'Это управляет хранилищем снимков OpenCode и поддержкой отмены/повтора, а не снимками локального кэша CodeWalk.';

  @override
  String get settingsBehaviorTitle => 'Поведение';

  @override
  String get settingsBehaviorUsernameFallback =>
      'OpenCode использует системное имя пользователя, так как `username` не задано.';

  @override
  String get settingsBehaviorUsernamePatchCaveat =>
      'Сброс `username` к системному значению по умолчанию по-прежнему требует редактирования конфигурации вне приложения, поскольку обновления патчей `/config` не могут удалять ключи.';

  @override
  String get settingsConfigRefreshFailed =>
      'Настройки сервера обновлены, но не удалось обновить провайдеров чата.';

  @override
  String get settingsConfigUpdateDeferred =>
      'CodeWalk применит эту настройку OpenCode после завершения текущего ответа.';

  @override
  String get settingsConversationUsername => 'Имя пользователя для бесед';

  @override
  String get settingsDefaultAgent => 'Агент по умолчанию';

  @override
  String get settingsDefaultModel => 'Модель по умолчанию';

  @override
  String get settingsLanguageDescription =>
      'Выберите язык, используемый CodeWalk. По умолчанию используется системный язык вашего устройства.';

  @override
  String get settingsLanguageEmptyText => 'Языки не найдены';

  @override
  String get settingsLanguageFieldHelper =>
      'Применяется немедленно и сохраняется после перезапуска.';

  @override
  String get settingsLanguageFieldLabel => 'Язык приложения';

  @override
  String get settingsLanguageSearchHint => 'Поиск языков';

  @override
  String get settingsLanguageSystemDefault => 'Системный по умолчанию';

  @override
  String get settingsLanguageTitle => 'Язык';

  @override
  String get settingsLogsDescription =>
      'Просмотр диагностики приложения и сведений об устранении неполадок';

  @override
  String get settingsLogsTitle => 'Журналы';

  @override
  String get settingsNoAgentsFound => 'Агенты не найдены';

  @override
  String get settingsNotificationsAgentSubtitle => 'Когда ответ завершен';

  @override
  String get settingsNotificationsAgentUpdates => 'Обновления агента';

  @override
  String get settingsNotificationsAnotherConversation => 'Другая беседа';

  @override
  String get settingsNotificationsAppInBackground =>
      'Приложение в фоновом режиме';

  @override
  String get settingsNotificationsBackgroundAlerts =>
      'Фоновые оповещения Android';

  @override
  String get settingsNotificationsBackgroundBehavior =>
      'Поведение в фоновом режиме';

  @override
  String get settingsNotificationsBackgroundBehaviorDescription =>
      'Выберите, как CodeWalk ведет себя после того, как приложение покидает передний план.';

  @override
  String get settingsNotificationsBackgroundDescription =>
      'Использовать экономичный фоновый мониторинг для завершения ответов, запросов разрешений, вопросов и ошибок, когда приложение не на экране.';

  @override
  String get settingsNotificationsBackgroundToggle =>
      'Фоновые оповещения на Android';

  @override
  String get settingsNotificationsBackgroundToggleDescription =>
      'Отключить все фоновые проверки Android и скрыть постоянное уведомление мониторинга.';

  @override
  String get settingsNotificationsBatteryDescription =>
      'Если уведомления приходят только при повторном открытии приложения, разрешите CodeWalk работать без оптимизации на этом устройстве.';

  @override
  String get settingsNotificationsBatteryDisabled =>
      'Оптимизация батареи отключена для CodeWalk.';

  @override
  String get settingsNotificationsBatteryEnabled =>
      'Оптимизация батареи включена. Некоторые устройства могут задерживать фоновые оповещения.';

  @override
  String get settingsNotificationsBatteryOptimization =>
      'Оптимизация батареи Android';

  @override
  String get settingsNotificationsBatteryUnknown =>
      'Не удалось прочитать статус оптимизации батареи.';

  @override
  String get settingsNotificationsChooseAudioFile => 'Выбрать аудиофайл';

  @override
  String get settingsNotificationsChooseSystemSound => 'Выбрать системный звук';

  @override
  String get settingsNotificationsCloseToTray => 'Закрывать в трей';

  @override
  String get settingsNotificationsCloseToTrayDescription =>
      'Сворачивать окно и продолжать работу в системном трее.';

  @override
  String get settingsNotificationsDescription =>
      'Выбор событий для уведомлений и способа их показа';

  @override
  String get settingsNotificationsDisableOptimization =>
      'Отключить оптимизацию';

  @override
  String get settingsNotificationsErrors => 'Ошибки';

  @override
  String get settingsNotificationsErrorsSubtitle =>
      'Когда сессия сообщает о сбое';

  @override
  String get settingsNotificationsJustClose => 'Просто закрывать';

  @override
  String get settingsNotificationsJustCloseDescription =>
      'Полностью завершать работу приложения.';

  @override
  String get settingsNotificationsKeepLive =>
      'Активность оповещений в течение 3 мин';

  @override
  String get settingsNotificationsKeepLiveDescription =>
      'Если ответ уже выполняется, сохранять активность в реальном времени в течение короткого времени после выхода из приложения.';

  @override
  String get settingsNotificationsLocal => 'Локально';

  @override
  String get settingsNotificationsMinimizeWhenClose =>
      'Сворачивать при закрытии';

  @override
  String get settingsNotificationsMinimizeWhenCloseDescription =>
      'Сворачивать на панель задач/док и продолжать работу.';

  @override
  String get settingsNotificationsNoCondition =>
      'Если ни одно условие не выбрано, оповещения разрешены в любом контексте.';

  @override
  String get settingsNotificationsNotify => 'Уведомлять';

  @override
  String get settingsNotificationsNotifyOnlyWhen => 'Уведомлять только когда';

  @override
  String get settingsNotificationsOpenBatterySettings =>
      'Открыть настройки батареи';

  @override
  String get settingsNotificationsPermissions => 'Разрешения и вопросы';

  @override
  String get settingsNotificationsPermissionsSubtitle =>
      'Когда инструменты запрашивают ваш ввод';

  @override
  String get settingsNotificationsPreview => 'Прослушать';

  @override
  String get settingsNotificationsRefreshStatus => 'Обновить статус';

  @override
  String get settingsNotificationsSearchSoundType => 'Поиск типа звука';

  @override
  String get settingsNotificationsSectionDescription =>
      'Управляйте тем, когда появляются оповещения и когда они могут воспроизводить звук.';

  @override
  String get settingsNotificationsSectionTitle => 'Уведомления';

  @override
  String settingsNotificationsSelectedSound(String label) {
    return 'Выбрано: $label';
  }

  @override
  String get settingsNotificationsServer => 'Сервер';

  @override
  String get settingsNotificationsSound => 'Звук';

  @override
  String get settingsNotificationsSoundBuiltInAlert => 'Встроенный сигнал';

  @override
  String get settingsNotificationsSoundBuiltInClick => 'Встроенный клик';

  @override
  String get settingsNotificationsSoundOff => 'Выкл.';

  @override
  String get settingsNotificationsSoundOnlyWhen => 'Звук только когда';

  @override
  String get settingsNotificationsSoundPickAudioFile => 'Выбрать аудиофайл';

  @override
  String get settingsNotificationsSoundPickFromSystem => 'Выбрать из системы';

  @override
  String get settingsNotificationsSoundSystemDefault =>
      'Системный по умолчанию';

  @override
  String get settingsNotificationsSoundType => 'Тип звука';

  @override
  String get settingsNotificationsSyncInfo =>
      'Некоторые переключатели категорий синхронизируются из /config на активном сервере.';

  @override
  String get settingsNotificationsSyncInfoLocal =>
      'Текущий сервер не предоставляет переключатели уведомлений в /config; активны локальные значения.';

  @override
  String get settingsNotificationsSystemSoundPickerTitle =>
      'Выбор системного звука';

  @override
  String get settingsNotificationsTitle => 'Уведомления';

  @override
  String get settingsNotificationsWhenClosing => 'При закрытии окна';

  @override
  String get settingsOpenCodeAutoUpdate => 'Автообновление OpenCode';

  @override
  String get settingsOpenCodeSharingDefault =>
      'Общий доступ OpenCode по умолчанию';

  @override
  String get settingsReadAloudEnabled => 'Прочитать вслух';

  @override
  String get settingsReadAloudEnabledDescription =>
      'Показывать кнопку чтения вслух в сообщениях ассистента.';

  @override
  String get settingsReadAloudPitch => 'Высота звука';

  @override
  String get settingsReadAloudPitchDescription => 'Настроить высоту голоса.';

  @override
  String get settingsReadAloudSectionDescription =>
      'Чтение ответов ассистента вслух. Настройка скорости, высоты звука и голоса.';

  @override
  String get settingsReadAloudSectionTitle => 'Преобразование текста в речь';

  @override
  String get settingsReadAloudSpeed => 'Скорость';

  @override
  String get settingsReadAloudSpeedDescription => 'Настроить скорость речи.';

  @override
  String get settingsReadAloudVoice => 'Голос';

  @override
  String get settingsReadAloudVoiceHint => 'Выберите голос для чтения вслух.';

  @override
  String get settingsSearchAutoUpdateMode => 'Поиск режима автообновления';

  @override
  String get settingsSearchDefaultAgent => 'Поиск агента по умолчанию';

  @override
  String get settingsSearchDefaultModel => 'Поиск модели по умолчанию';

  @override
  String get settingsSearchSharingMode => 'Поиск режима общего доступа';

  @override
  String get settingsSearchSmallModel => 'Поиск малой модели';

  @override
  String get settingsServersActive => 'Активный';

  @override
  String get settingsServersChooseActive => 'Выбрать активный сервер';

  @override
  String get settingsServersDefault => 'По умолчанию';

  @override
  String get settingsServersDescription =>
      'Подключение к OpenCode и управление серверами';

  @override
  String get settingsServersTitle => 'Серверы';

  @override
  String get settingsSessionAttentionSize => 'Размер пузырька';

  @override
  String get settingsSessionAttentionSizeExtraLarge => 'Очень большой';

  @override
  String get settingsSessionAttentionSizeExtraSmall => 'Очень маленький';

  @override
  String get settingsSessionAttentionSizeLarge => 'Большой';

  @override
  String get settingsSessionAttentionSizeSmall => 'Маленький';

  @override
  String get settingsSessionAttentionSizeStandard => 'Стандартный';

  @override
  String get settingsSetupWizard => 'Мастер настройки';

  @override
  String get settingsShortcutsDescription =>
      'Поиск и настройка сочетаний клавиш';

  @override
  String get settingsShortcutsEdit => 'Редактировать ярлык';

  @override
  String get settingsShortcutsKeyboard => 'Горячие клавиши';

  @override
  String get settingsShortcutsReset => 'Сбросить ярлык';

  @override
  String get settingsShortcutsSearch => 'Поиск горячих клавиш';

  @override
  String get settingsShortcutsTitle => 'Ярлыки';

  @override
  String get settingsSmallModel => 'Малая модель';

  @override
  String get settingsSmallModelResetExplanation =>
      'Сброс `small_model` к автоматическому откату по-прежнему требует редактирования конфигурации вне приложения, поскольку обновления патчей `/config` не могут удалять ключи.';

  @override
  String get settingsSmallModelUnsetExplanation =>
      'Автоматический откат OpenCode активен, так как `small_model` не задана.';

  @override
  String get settingsSoundPickerNotAvailable =>
      'Выбор системного звука недоступен на этой платформе.';

  @override
  String get settingsSpeechDescription =>
      'Настройка голосового ввода, офлайн-моделей и чтения вслух';

  @override
  String get settingsSpeechRefreshStatus => 'Обновить статус';

  @override
  String settingsSpeechSilenceTimeout(String value) {
    return 'Таймаут тишины: $value с';
  }

  @override
  String get settingsSpeechTitle => 'Преобразование речи в текст';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsGroupAlertTypes => 'Типы уведомлений';

  @override
  String get settingsGroupBackgroundBehavior => 'Работа в фоне';

  @override
  String get settingsGroupChatDisplay => 'Отображение чата';

  @override
  String get settingsGroupCurrentConnection => 'Текущее подключение';

  @override
  String get settingsGroupDataAndSync => 'Данные и синхронизация';

  @override
  String get settingsGroupDataReset => 'Данные и сброс';

  @override
  String get settingsGroupDelivery => 'Доставка';

  @override
  String get settingsGroupHelp => 'Справка';

  @override
  String get settingsGroupLanguageAndChat => 'Язык и чат';

  @override
  String get settingsGroupLayoutAndText => 'Макет и текст';

  @override
  String get settingsGroupOfflineModels => 'Офлайн-модели';

  @override
  String get settingsGroupOpenCodeDefaults => 'Параметры OpenCode по умолчанию';

  @override
  String get settingsGroupReadAloud => 'Чтение вслух';

  @override
  String get settingsGroupSavedServers => 'Сохраненные серверы';

  @override
  String get settingsGroupThemeAndColor => 'Тема и цвет';

  @override
  String get settingsGroupThisDevice => 'Это устройство';

  @override
  String get settingsGroupVersionUpdates => 'Версия и обновления';

  @override
  String get settingsGroupVoiceInput => 'Голосовой ввод';

  @override
  String get settingsNavigationGroupExperience => 'Опыт';

  @override
  String get settingsNavigationGroupInput => 'Ввод';

  @override
  String get settingsNavigationGroupSetup => 'Настройка';

  @override
  String get settingsNavigationGroupSupport => 'Справка и диагностика';

  @override
  String get settingsNavigationNoResults => 'Настройки не найдены';

  @override
  String get settingsNavigationSearchHint => 'Поиск настроек';

  @override
  String get settingsUsernameClearHint =>
      'Очистка имени пользователя беседы OpenCode по-прежнему требует изменения конфигурации вне приложения.';

  @override
  String get settingsUsernameEnterHint =>
      'Введите имя пользователя, чтобы сохранить собственное название беседы OpenCode.';

  @override
  String get settingsUsernameResetExplanation =>
      'Сброс `username` к системному значению по умолчанию по-прежнему требует редактирования конфигурации вне приложения, поскольку обновления патчей `/config` не могут удалять ключи.';

  @override
  String get settingsUsernameUnsetExplanation =>
      'OpenCode использует системное имя пользователя, так как `username` не задано.';

  @override
  String get setupDebugBun => 'Bun';

  @override
  String get setupDebugBun2 => 'Bun';

  @override
  String get setupDebugCapturedSetupDetails =>
      'Захваченные детали настройки пока отсутствуют';

  @override
  String get setupDebugCapturedSetupLogs => 'Захваченные журналы настройки';

  @override
  String get setupDebugClear => 'Очистить отладочную информацию';

  @override
  String get setupDebugClearSetupDebug => 'Очистить отладочную информацию';

  @override
  String get setupDebugCodeWalkCaptureEnough =>
      'Если CodeWalk не захватил достаточно контекста, проверьте официальные логи OpenCode и конечные точки состояния напрямую:';

  @override
  String get setupDebugCommandPath => 'Путь к команде';

  @override
  String get setupDebugCommandPath2 => 'Путь к команде';

  @override
  String get setupDebugCopy => 'Копировать отладочную информацию';

  @override
  String get setupDebugCopySetupDebug => 'Копировать отладочную информацию';

  @override
  String get setupDebugCurrentStatus => 'Текущий статус';

  @override
  String get setupDebugDiagnosticsLoading => 'Диагностика все еще загружается.';

  @override
  String get setupDebugEnvironment => 'Диагностика среды';

  @override
  String get setupDebugEnvironmentDiagnostics => 'Диагностика среды';

  @override
  String get setupDebugFocusedOpenCodeSetup => 'Настройка OpenCode';

  @override
  String get setupDebugInstallDir => 'Каталог установки';

  @override
  String get setupDebugInstallDirectory => 'Каталог установки';

  @override
  String get setupDebugLatestLocalServer =>
      'Последний вывод локального сервера';

  @override
  String get setupDebugLogs => 'Захваченные журналы настройки';

  @override
  String get setupDebugManual => 'Ручное устранение неполадок';

  @override
  String get setupDebugManualTroubleshooting => 'Ручное устранение неполадок';

  @override
  String get setupDebugNetwork => 'Сеть';

  @override
  String get setupDebugNetwork2 => 'Сеть';

  @override
  String get setupDebugNoDetails =>
      'Захваченные детали настройки пока отсутствуют';

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
  String get setupDebugOpenCodeSetupDebug => 'Отладка настройки OpenCode';

  @override
  String get setupDebugPlatform => 'Платформа';

  @override
  String get setupDebugPlatform2 => 'Платформа';

  @override
  String get setupDebugRunDiagnosticsTry =>
      'Запустите диагностику, попробуйте установить или выполнить настройку, чтобы зафиксировать здесь отладочные сведения для OpenCode.';

  @override
  String get setupDebugScreenCoversOpenCode =>
      'Этот экран охватывает только установку, диагностику и устранение неполадок локальной настройки OpenCode. Для общих проблем CodeWalk используйте логи приложения.';

  @override
  String get setupDebugServerOutput => 'Последний вывод локального сервера';

  @override
  String get setupDebugStatus => 'Текущий статус';

  @override
  String setupDebugTimeEntrySource(String source, String time) {
    return '$time - $source';
  }

  @override
  String get setupDebugTimeline => 'Хронология';

  @override
  String get setupDebugTimeline2 => 'Хронология';

  @override
  String get setupDebugTitle => 'Настройка OpenCode';

  @override
  String get setupDebugWSL => 'WSL';

  @override
  String get setupDebugWsl => 'WSL';

  @override
  String get shortcutCloseApp => 'Закрыть вкладку/приложение';

  @override
  String get shortcutCloseAppDesc =>
      'Закрыть текущую вкладку сеанса, если она доступна; иначе закрыть приложение согласно поведению платформы';

  @override
  String get shortcutFocusCloseDrawer => 'Фокусировать/закрыть панель';

  @override
  String get shortcutFocusCloseDrawerDesc =>
      'Фокусировать редактор по умолчанию или закрыть панель, если она открыта';

  @override
  String get shortcutFocusInput => 'Фокус на вводе';

  @override
  String get shortcutFocusInputDesc => 'Переместить фокус на ввод запроса';

  @override
  String get shortcutGroupApplication => 'Приложение';

  @override
  String get shortcutGroupGeneral => 'Общие';

  @override
  String get shortcutGroupModelAndAgent => 'Модель и агент';

  @override
  String get shortcutGroupNavigation => 'Навигация';

  @override
  String get shortcutGroupPrompt => 'Запрос';

  @override
  String get shortcutGroupSession => 'Сессия';

  @override
  String get shortcutNewConversation => 'Новая беседа';

  @override
  String get shortcutNewConversationDesc => 'Создать новую сессию чата';

  @override
  String get shortcutNextAgent => 'Следующий агент';

  @override
  String get shortcutNextAgentDesc =>
      'Переключиться на следующего доступного агента';

  @override
  String get shortcutNextRecentModel => 'Следующая недавняя модель';

  @override
  String get shortcutNextRecentModelDesc =>
      'Переключиться на недавно использовавшиеся модели';

  @override
  String get shortcutNextVariant => 'Следующий вариант';

  @override
  String get shortcutNextVariantDesc =>
      'Переключиться на доступные варианты модели';

  @override
  String get shortcutOpenSettings => 'Открыть настройки';

  @override
  String get shortcutOpenSettingsDesc => 'Открыть страницу настроек';

  @override
  String get shortcutPreviousAgent => 'Предыдущий агент';

  @override
  String get shortcutPreviousAgentDesc =>
      'Переключиться на предыдущего доступного агента';

  @override
  String get shortcutQuickOpenFiles => 'Быстрое открытие файлов';

  @override
  String get shortcutQuickOpenFilesDesc => 'Открыть быстрый поиск файлов';

  @override
  String get shortcutQuitApp => 'Выйти из приложения';

  @override
  String get shortcutQuitAppDesc => 'Принудительно закрыть приложение';

  @override
  String get shortcutRefreshData => 'Обновить данные';

  @override
  String get shortcutRefreshDataDesc => 'Обновить данные текущего чата';

  @override
  String get shortcutStopResponse => 'Остановить активный ответ';

  @override
  String get shortcutStopResponseDesc =>
      'Остановить активный ответ (во время генерации)';

  @override
  String get shortcutToggleVoiceInput => 'Переключить голосовой ввод';

  @override
  String get shortcutToggleVoiceInputDesc =>
      'Запустить или остановить преобразование речи в текст в редакторе';

  @override
  String get shortcutsApply => 'Применить';

  @override
  String shortcutsConflictConflict(String conflict) {
    return 'Конфликт с $conflict';
  }

  @override
  String get shortcutsKeyboardShortcuts => 'Горячие клавиши';

  @override
  String get shortcutsReset => 'Сбросить все';

  @override
  String get shortcutsSearchEditBindings =>
      'Ищите, редактируйте привязки клавиш и устраняйте конфликты перед сохранением.';

  @override
  String shortcutsSetShortcutWidget(String label) {
    return 'Задать ярлык: $label';
  }

  @override
  String get shortcutsTheseBindingsStored =>
      'Эти привязки хранятся в CodeWalk для текущего времени выполнения приложения и не изменяют горячие клавиши в `tui.json` OpenCode.';

  @override
  String get speechAutoStopSilence => 'Автоостановка при тишине';

  @override
  String get speechChooseRecognitionEngine =>
      'Выберите движок распознавания, таймаут тишины и параметры модели.';

  @override
  String speechDesktopOnly(String service) {
    return '$service доступна только на десктопе.';
  }

  @override
  String get speechDownload => 'Скачать';

  @override
  String get speechEngine => 'Движок';

  @override
  String get speechInstalledLanguages => 'Установленные языки';

  @override
  String get speechListeningStopsAutomatically =>
      'Распознавание останавливается автоматически после указанного количества секунд тишины.';

  @override
  String get speechMicPermissionDisabled =>
      'Разрешение на использование микрофона отключено.';

  @override
  String speechModelFilesIncomplete(String service) {
    return 'Файлы моделей $service неполные.';
  }

  @override
  String get speechMoonshine => 'Moonshine';

  @override
  String get speechMoonshineModelsDesktop => 'Модели Moonshine (десктоп)';

  @override
  String get speechMoonshineStaysDownloadable =>
      'Модели Moonshine загружаются отдельно и не входят в стандартный пакет приложения. Выберите одну модель для этого десктопного устройства и удалите ее позже, если потребуется освободить место.';

  @override
  String get speechNative => 'Встроенный';

  @override
  String get speechNativeSTTDisabled =>
      'Встроенный STT отключен на Linux в этом приложении. Parakeet используется в качестве движка по умолчанию для новых установок.';

  @override
  String get speechNativeSTTWorks =>
      'В Windows CodeWalk использует локальное распознавание речи на устройстве через WASAPI-бэкенд микрофона. Встроенное распознавание речи Windows отключено ради стабильности.';

  @override
  String get speechNativeStartsFaster =>
      'Встроенный запускается быстрее. Sherpa работает полностью на устройстве с более сложной настройкой и глубоким контролем над моделью.';

  @override
  String get speechOpenMicrophoneSettings => 'Открыть настройки микрофона';

  @override
  String get speechOpenSpeechPrivacy => 'Открыть конфиденциальность речи';

  @override
  String get speechOpenSpeechSettings => 'Открыть настройки речи';

  @override
  String get speechParakeet => 'Parakeet';

  @override
  String get speechParakeetModelsDesktop => 'Модели Parakeet (десктоп)';

  @override
  String get speechParakeetStaysDownloadable =>
      'Модели Parakeet загружаются отдельно и не входят в стандартный пакет приложения. В настоящее время доступна одна многоязычная модель, оптимизированная для 25 европейских языков.';

  @override
  String get speechPickLanguagePacks =>
      'Выберите языковые пакеты и скачайте/удалите модели для локального распознавания речи.';

  @override
  String get speechRemove => 'Удалить';

  @override
  String speechRuntimeFailed(String service) {
    return 'Не удалось инициализировать среду выполнения $service.';
  }

  @override
  String get speechSelectSherpaAbove =>
      'Выберите Sherpa выше, чтобы управлять языковыми пакетами и загружать модели.';

  @override
  String get speechSenseVoice => 'SenseVoice';

  @override
  String get speechSenseVoiceModelsDesktop => 'Модели SenseVoice (десктоп)';

  @override
  String get speechSenseVoiceStaysDownloadable =>
      'Модели SenseVoice загружаются отдельно и не входят в стандартный пакет приложения. Это лучший десктопный вариант для китайского, кантонского диалекта, японского, корейского и английского языков.';

  @override
  String get speechSherpa => 'Sherpa';

  @override
  String get speechSherpaExperimentalFail =>
      'Sherpa является экспериментальным и может давать сбои на некоторых устройствах. Используйте Встроенный для наиболее стабильной работы.';

  @override
  String get speechSherpaModelsLinux => 'Модели Sherpa (Linux)';

  @override
  String get speechSpeechText => 'Преобразование речи в текст';

  @override
  String speechUnavailableOnPlatform(String service) {
    return 'Распознавание речи $service недоступно на этой платформе.';
  }

  @override
  String get speechWindowsSetupHint =>
      'Голосовой ввод в Windows использует захват WASAPI CodeWalk с моделями на устройстве. Держите доступ к микрофону для настольных приложений включенным; кнопки ниже открывают настройки Windows для устранения неполадок.';

  @override
  String get statusConnected => 'Подключено';

  @override
  String get statusDelayed => 'Задержка';

  @override
  String get statusFailed => 'Сбой';

  @override
  String get statusOffline => 'Офлайн';

  @override
  String get statusOnline => 'Онлайн';

  @override
  String get statusReconnecting => 'Переподключение';

  @override
  String get statusStarting => 'Запуск';

  @override
  String get statusStopped => 'Остановлен';

  @override
  String get statusStopping => 'Остановка';

  @override
  String get statusSyncDelayed => 'Синхронизация отложена';

  @override
  String get tailscaleNoPeers => 'Узлы не найдены';

  @override
  String get tailscaleNotSupportedOnPlatform =>
      'Tailscale не поддерживается на этой платформе.';

  @override
  String get tailscaleNotSupportedOnWindows =>
      'Tailscale не поддерживается на Windows.';

  @override
  String get tailscalePeerOffline => 'офлайн';

  @override
  String get tailscaleSelectPeer => 'Выберите узел Tailscale';

  @override
  String get tailscaleWaitingAdminApproval =>
      'Этот узел Tailscale ожидает одобрения администратора.';

  @override
  String get terminalClose => 'Закрыть терминал';

  @override
  String terminalConnectingTo(String serverName) {
    return 'Подключение к терминалу $serverName...';
  }

  @override
  String terminalConnectionFailed(String error) {
    return 'Сбой подключения к терминалу: $error';
  }

  @override
  String get terminalDisconnected => 'Терминал отключен.';

  @override
  String terminalEmbeddedUnavailable(String serverName) {
    return 'Встроенный терминал еще не доступен в этой среде выполнения. Продолжайте использовать режим терминала в редакторе для разовых команд или откройте терминал из поддерживаемой среды выполнения CodeWalk для $serverName.';
  }

  @override
  String get terminalExtraKeyAlt => 'Клавиша Alt';

  @override
  String get terminalExtraKeyArrowDown => 'Стрелка вниз';

  @override
  String get terminalExtraKeyArrowLeft => 'Стрелка влево';

  @override
  String get terminalExtraKeyArrowRight => 'Стрелка вправо';

  @override
  String get terminalExtraKeyArrowUp => 'Стрелка вверх';

  @override
  String get terminalExtraKeyControl => 'Клавиша Control';

  @override
  String get terminalExtraKeyEscape => 'Клавиша Escape';

  @override
  String get terminalExtraKeyTab => 'Клавиша Tab';

  @override
  String get terminalExtraKeys => 'Дополнительные клавиши терминала';

  @override
  String get terminalHide => 'Скрыть терминал';

  @override
  String get terminalMaximize => 'Развернуть';

  @override
  String get terminalMinimize => 'Свернуть терминал';

  @override
  String get terminalNotAvailableYet =>
      'Встроенный терминал еще не доступен в этой среде выполнения.';

  @override
  String get terminalOpen => 'Открыть терминал';

  @override
  String get terminalOpenInfo => 'Показать информацию терминала';

  @override
  String get terminalOpenProjectFirst =>
      'Откройте папку проекта перед запуском терминала сервера.';

  @override
  String get terminalOpenToConnect =>
      'Откройте Терминал, чтобы подключиться к терминалу проекта на сервере.';

  @override
  String get terminalReconnect => 'Переподключить терминал';

  @override
  String get terminalRestoreSize => 'Восстановить размер';

  @override
  String get terminalSelectServer =>
      'Выберите активный сервер перед открытием Терминала.';

  @override
  String get terminalSessionClosed => 'Сессия терминала закрыта.';

  @override
  String get terminalTerminal => 'Терминал';

  @override
  String get terminalTitle => 'Терминал';

  @override
  String get terminalTryAgain => 'Попробовать снова';

  @override
  String get toolAwaitingInput => 'Ожидание ввода';

  @override
  String get toolEditing => 'Редактирование';

  @override
  String get toolEditingFiles => 'Редактирование файлов';

  @override
  String get toolFinding => 'Поиск';

  @override
  String get toolFindingFiles => 'Поиск файлов';

  @override
  String get toolPresentationAwaitingInput => 'Ожидание ввода';

  @override
  String get toolPresentationEditing => 'Редактирование';

  @override
  String get toolPresentationEditingFiles => 'Редактирование файлов';

  @override
  String get toolPresentationFinding => 'Поиск';

  @override
  String get toolPresentationFindingFiles => 'Поиск файлов';

  @override
  String get toolPresentationReading => 'Чтение';

  @override
  String get toolPresentationReadingFile => 'Чтение файла';

  @override
  String get toolPresentationRunning => 'Выполнение';

  @override
  String get toolPresentationRunningCommand => 'Выполнение команды';

  @override
  String toolPresentationRunningTool(String toolName) {
    return 'Выполнение $toolName';
  }

  @override
  String get toolPresentationSearching => 'Поиск';

  @override
  String get toolPresentationSearchingCode => 'Поиск по коду';

  @override
  String get toolPresentationSearchingWeb => 'Поиск в Интернете';

  @override
  String get toolPresentationTool => 'Инструмент';

  @override
  String get toolPresentationUpdatingTaskList => 'Обновление списка задач';

  @override
  String get toolPresentationUpdatingTasks => 'Обновление задач';

  @override
  String get toolPresentationWaitingInput => 'Ожидание вашего ввода';

  @override
  String get toolPresentationWriting => 'Запись';

  @override
  String get toolPresentationWritingFile => 'Запись файла';

  @override
  String get toolReading => 'Чтение';

  @override
  String get toolReadingFile => 'Чтение файла';

  @override
  String get toolRunning => 'Выполняется';

  @override
  String get toolRunningCommand => 'Выполнение команды';

  @override
  String get toolRunningTask => 'Выполнение задачи';

  @override
  String get toolSearching => 'Поиск';

  @override
  String get toolSearchingCode => 'Поиск по коду';

  @override
  String get toolSearchingWeb => 'Поиск в Интернете';

  @override
  String get toolUpdatingTaskList => 'Обновление списка задач';

  @override
  String get toolUpdatingTasks => 'Обновление задач';

  @override
  String get toolWaitingForInput => 'Ожидание вашего ввода';

  @override
  String get toolWriting => 'Запись';

  @override
  String get toolWritingFile => 'Запись файла';

  @override
  String get tourBack => 'Назад';

  @override
  String get tourSkip => 'Пропустить';

  @override
  String get trayQuit => 'Выйти';

  @override
  String get trayShow => 'Показать';

  @override
  String get useOAuthCloudflareAccess =>
      'Использовать OAuth (Cloudflare Access)';

  @override
  String get useOAuthCloudflareAccessSubtitle =>
      'Открывает браузер для Managed OAuth Cloudflare Access.';

  @override
  String get useOAuthCloudflareAccessUnsupported =>
      'Авторизация Cloudflare Access OAuth недоступна на этой платформе. Используйте Basic Auth вместо нее.';

  @override
  String get useTailscale => 'Использовать Tailscale';

  @override
  String get useTailscaleSubtitle =>
      'Маршрутизирует трафик через сеть Tailscale без общесистемного VPN.';

  @override
  String get useTailscaleUnsupported =>
      'Tailscale не поддерживается на этой платформе.';

  @override
  String get utilityTitle => 'Утилиты';

  @override
  String get workspaceBrowseDirs => 'Обзор каталогов';

  @override
  String get workspaceChooseFolderOpen =>
      'Выберите любую папку, чтобы открыть в качестве контекста проекта.';

  @override
  String workspaceCloseProject(String project) {
    return 'Закрыть $project';
  }

  @override
  String get workspaceClosedProjects => 'Закрытые проекты';

  @override
  String workspaceCurrentDirectory(String path) {
    return 'Текущий каталог: $path';
  }

  @override
  String get workspaceFilterDirs => 'Фильтровать каталоги';

  @override
  String get workspaceOpenFolder => 'Открыть папку';

  @override
  String get workspaceOpenProjectFolder => 'Открыть папку проекта';

  @override
  String get workspaceOpenProjects => 'Открытые проекты';

  @override
  String get workspaceProjectDirectory => 'Каталог проекта';

  @override
  String get workspaceProjectHint => '/repo/my-project';

  @override
  String workspaceRemoveFromHistory(String name) {
    return 'Удалить $name из истории';
  }

  @override
  String get settingsSessionAttentionTitle => 'Внимание к сеансам';

  @override
  String get settingsSessionAttentionDescription =>
      'Показывает состояние корневых сеансов в дополнительном пузыре или панели.';

  @override
  String get settingsSessionAttentionOff => 'Выключено';

  @override
  String get settingsSessionAttentionBubble => 'Пузырь';

  @override
  String get settingsSessionAttentionPanel => 'Панель';

  @override
  String get settingsSessionAttentionPrivacy =>
      'В Android включение запускает постоянную службу переднего плана. Текст ответов хранится в зашифрованном виде; облачный TTS отправляет текст только после нажатия «Читать».';

  @override
  String get settingsSessionAttentionUnavailable =>
      'Внимание к сеансам недоступно на этой платформе.';

  @override
  String get settingsSessionAttentionOpenSettings =>
      'Открыть настройки отображения';

  @override
  String get settingsSessionAttentionStop => 'Остановить внимание к сеансам';

  @override
  String get settingsSessionAttentionThirdPartyTtsWarning =>
      'После нажатия «Читать» текст ответа может быть отправлен настроенному стороннему поставщику TTS.';

  @override
  String get workspaceSuggestions => 'Предложения';

  @override
  String get sessionTabsGestureHintTitle =>
      'У вкладок сессий новые элементы управления';

  @override
  String get sessionTabsGestureHintBody =>
      'Двойной щелчок или двойное касание по вкладке закрывает ее. Щелкните правой кнопкой или коснитесь и удерживайте, чтобы открыть действия сессии. Вкладки можно отключить в переключателях отображения.';

  @override
  String get sessionTabsGestureHintAcknowledge => 'Понятно';

  @override
  String get sessionTabsGestureHintDisableTabs => 'Отключить вкладки';

  @override
  String get sessionTabRenameAction => 'Переименовать сессию';

  @override
  String sessionTabClosedMessage(String title) {
    return 'Вкладка \"$title\" закрыта';
  }

  @override
  String get sessionTabUndo => 'Отменить';

  @override
  String get sessionTabRestoreFailed => 'Не удалось восстановить вкладку.';

  @override
  String get sessionTabChangeIconAction => 'Сменить значок';

  @override
  String get sessionTabIconPickerTitle => 'Выбрать значок вкладки';

  @override
  String get sessionTabIconUseProjectIcon => 'Использовать значок проекта';

  @override
  String get sessionTabIconApplied => 'Значок вкладки обновлен.';

  @override
  String get sessionTabIconSaveFailed => 'Не удалось сохранить значок вкладки.';

  @override
  String get sessionTabIconPresetCode => 'Код';

  @override
  String get sessionTabIconPresetTerminal => 'Терминал';

  @override
  String get sessionTabIconPresetBug => 'Ошибка';

  @override
  String get sessionTabIconPresetTasks => 'Задачи';

  @override
  String get sessionTabIconPresetLaunch => 'Запуск';

  @override
  String get sessionTabIconPresetIdea => 'Идея';

  @override
  String get sessionTabIconPresetResearch => 'Исследование';

  @override
  String get sessionTabIconPresetDesign => 'Дизайн';

  @override
  String get sessionTabIconPresetData => 'Данные';

  @override
  String get sessionTabIconPresetCloud => 'Облако';

  @override
  String get sessionTabIconPresetSecurity => 'Безопасность';

  @override
  String get sessionTabIconPresetTools => 'Инструменты';

  @override
  String get workspaceNoActiveContext => 'Нет активного контекста';

  @override
  String get settingsAppearanceContrastLow => 'Низкий';

  @override
  String get settingsAppearanceContrastStandard => 'Стандартный';

  @override
  String get settingsAppearanceContrastMedium => 'Средний';

  @override
  String get settingsAppearanceContrastMediumHigh => 'Средне-высокий';

  @override
  String get settingsNotificationsSystemSoundsWebUnavailable =>
      'Недоступно в веб-версии.';

  @override
  String get settingsNotificationsSystemSoundsAndroid =>
      'Системные звуки уведомлений Android.';

  @override
  String get settingsNotificationsSystemSoundsFreedesktop =>
      'Звуки Freedesktop из /usr/share/sounds/freedesktop/stereo.';

  @override
  String get settingsNotificationsSystemSoundsPlatform =>
      'Поддерживается там, где операционная система предоставляет системные звуки.';

  @override
  String get serversQuickGuideTitle => 'Быстрая настройка';

  @override
  String get serversQuickGuideIntro =>
      'CodeWalk — это приложение. OpenCode — это движок, который должен быть запущен, чтобы это подключение работало.';

  @override
  String get serversQuickGuideStepInstallCli => '1. Установите CLI OpenCode.';

  @override
  String get serversQuickGuideRunPowerShell => '2. Выполните в PowerShell:';

  @override
  String get serversQuickGuideRunTerminal => '2. Выполните в терминале:';

  @override
  String get serversQuickGuideProtectPassword => 'Защитите доступ паролем';

  @override
  String get serversQuickGuideServerPassword => 'Пароль сервера';

  @override
  String get serversQuickGuideInstallOptions =>
      'Другие официальные способы установки: установочный скрипт, npm, bun, pnpm, Homebrew или бинарный файл из GitHub Releases.';

  @override
  String get serversQuickGuideVerifyHint =>
      'После запуска сервера убедитесь, что /global/health или /doc отвечают, прежде чем вставлять URL в CodeWalk.';

  @override
  String get shortcutsPressKeyCombination => 'Нажмите комбинацию клавиш сейчас';

  @override
  String get settingsProvenanceOpenCodeBacked => 'На базе OpenCode';

  @override
  String get settingsProvenanceCodeWalkLocal => 'Локально для CodeWalk';

  @override
  String get settingsProvenanceCodeWalkException => 'Исключение CodeWalk';

  @override
  String get shortcutsErrorInvalid => 'Недопустимое сочетание клавиш';

  @override
  String get shortcutsErrorUnsupportedKey => 'Неподдерживаемая клавиша';

  @override
  String shortcutsErrorConflict(String conflict) {
    return 'Конфликт с \"$conflict\"';
  }

  @override
  String get settingsSessionAttentionStopSaveFailed =>
      'Отслеживание сессий остановлено, но настройку не удалось сохранить.';

  @override
  String get settingsSessionAttentionEnableFailed =>
      'Не удалось включить отслеживание сессий.';

  @override
  String get settingsSessionAttentionSaveFailedStopped =>
      'Не удалось сохранить отслеживание сессий, поэтому оно остановлено.';

  @override
  String get settingsSessionAttentionStillRunning =>
      'Отслеживание сессий все еще работает. Попробуйте остановить его снова.';

  @override
  String get settingsSessionAttentionStopFailed =>
      'Не удалось остановить отслеживание сессий. Попробуйте еще раз.';

  @override
  String get settingsSessionAttentionCapabilityUnavailable =>
      'Возможность отслеживания сессий недоступна на хосте.';

  @override
  String get settingsServerFallbackProviderName => 'Настроено на сервере';

  @override
  String get composerStopResponse => 'Остановить ответ';

  @override
  String get composerSendMessageWhileResponding =>
      'Отправить сообщение во время ответа';

  @override
  String get composerSendMessage => 'Отправить сообщение';

  @override
  String get chatTourComposerDescription => 'Введите ваш запрос здесь.';

  @override
  String get chatTourSendDescription => 'Отправьте сообщение здесь.';

  @override
  String get composerAttachmentFallbackName => 'Вложение';

  @override
  String get composerContextFallbackName => 'Контекст';

  @override
  String get searchableDropdownSearchHint => 'Поиск';

  @override
  String get searchableDropdownEmptyText => 'Совпадений не найдено';

  @override
  String get speechApiKeyStorageUnavailable =>
      'Безопасное хранение ключа API TTS недоступно.';

  @override
  String get speechApiKeyRemoved => 'API-ключ удален.';

  @override
  String get speechApiKeySaved =>
      'API-ключ сохранен в защищенном хранилище на этом устройстве.';

  @override
  String get speechReadAloudTestText => 'Это тест синтеза речи CodeWalk.';

  @override
  String get speechNativeDisabledWindows =>
      'Отключено в Windows для стабильности. Используйте Parakeet или другой встроенный движок через захват WASAPI в CodeWalk.';

  @override
  String get speechNativeUnavailableLinux =>
      'Недоступно в Linux. Используйте Parakeet для голосового ввода.';

  @override
  String get speechNotAvailableOnPlatform => 'Недоступно на этой платформе.';

  @override
  String get speechSherpaUnavailableAndroid =>
      'Недоступно в сборках Android, оптимизированных под малый размер APK.';

  @override
  String get speechMoonshineDesktopOnlyHint =>
      'Доступно только на компьютере. На Android остаются только встроенные движки.';

  @override
  String get speechParakeetDesktopOnlyHint =>
      'Доступно только на компьютере. Использует офлайн-распознавание на нескольких языках.';

  @override
  String get speechSenseVoiceDesktopOnlyHint =>
      'Доступно только на компьютере. Лучше всего подходит для китайского, кантонского, японского, корейского и английского языков.';

  @override
  String get speechNativeSubtitle => 'Проще и быстрее запускается.';

  @override
  String get speechSherpaSubtitle =>
      'Тяжелее, экспериментальный, склонен к ошибкам. Часто точнее с загруженными моделями.';

  @override
  String get speechMoonshineSubtitle =>
      'Экспериментальный путь только для компьютера: офлайн-распознавание sherpa_onnx и загружаемые модели.';

  @override
  String get speechParakeetSubtitle =>
      'Офлайн-путь NeMo transducer только для компьютера с одной многоязычной загружаемой моделью.';

  @override
  String get speechSenseVoiceSubtitle =>
      'Офлайн-путь только для компьютера, оптимизированный для китайского, кантонского, японского, корейского и английского языков.';

  @override
  String get speechMoonshineModel => 'Модель Moonshine';

  @override
  String get speechSherpaLanguage => 'Язык Sherpa';

  @override
  String get speechSearchSherpaLanguage => 'Поиск языка Sherpa';

  @override
  String get speechNoLanguagePacksFound => 'Языковые пакеты не найдены';

  @override
  String get speechTextToSpeechProvider => 'Провайдер синтеза речи';

  @override
  String get speechProviderSystemNative => 'Системный / встроенный';

  @override
  String get speechProviderEdgeExperimental =>
      'Microsoft Edge Speech (экспериментально)';

  @override
  String get speechProviderOpenAiCompatible => 'Совместимый с OpenAI';

  @override
  String get speechEdgeExperimentalTitle =>
      'Microsoft Edge Speech — экспериментально';

  @override
  String get speechEdgeExperimentalDescription =>
      'Использует неофициальный сервис Edge Read Aloud напрямую с этого устройства. Текст сообщения отправляется в Microsoft при использовании озвучивания, и сервис может перестать работать, если Microsoft изменит закрытый протокол.';

  @override
  String get speechEdgeVoice => 'Голос Edge';

  @override
  String get speechEdgeVoiceListUnavailable =>
      'Используется голос Edge по умолчанию. Список голосов не удалось загрузить.';

  @override
  String get speechEdgeVoicesLoaded =>
      'Загружено из голосов Microsoft Edge Speech.';

  @override
  String get speechCloudTtsPrivacy => 'Конфиденциальность облачного TTS';

  @override
  String get speechCloudTtsPrivacyDescription =>
      'Облачный TTS отправляет текст выбранного сообщения ассистента настроенному провайдеру. API-ключи хранятся в защищенном хранилище на этом устройстве.';

  @override
  String get speechBaseUrl => 'Базовый URL';

  @override
  String get speechApiKey => 'API-ключ';

  @override
  String get speechApiKeySavedHelper =>
      'Ключ сохранен. Введите новое значение, чтобы заменить его, или оставьте пустым, чтобы удалить.';

  @override
  String get speechNoApiKeySaved => 'API-ключ не сохранен.';

  @override
  String get speechSaveApiKey => 'Сохранить API-ключ';

  @override
  String get speechModel => 'Модель';

  @override
  String get speechPitchNotSupported =>
      'Высота тона не поддерживается TTS, совместимым с OpenAI, и скрыта для этого провайдера.';

  @override
  String get speechTestVoice => 'Проверить голос';

  @override
  String get dialogMoonshineVoiceSetupDescription =>
      'Moonshine работает на устройстве через sherpa_onnx. Выберите модель один раз — она загрузится только на это настольное устройство.';

  @override
  String get dialogParakeetVoiceSetupDescription =>
      'Parakeet работает на устройстве через офлайн-распознавание sherpa_onnx. Загрузите модель один раз на это настольное устройство, чтобы включить многоязычное распознавание речи (STT).';

  @override
  String get dialogSenseVoiceSetupDescription =>
      'SenseVoice работает на устройстве через офлайн-распознавание sherpa_onnx. Он сильнее всего в китайском, кантонском, японском, корейском и английском языках.';

  @override
  String get dialogSherpaVoiceSetupDescription =>
      'Голосовой ввод Sherpa требует модель распознавания речи на устройстве. Выберите язык и загрузите модель один раз (~147 МБ).';

  @override
  String speechSilenceSeconds(String value) {
    return '$value сек.';
  }

  @override
  String speechModelInstalled(String modelId) {
    return 'Модель установлена ($modelId)';
  }

  @override
  String speechModelMissing(String modelId) {
    return 'Модель отсутствует ($modelId)';
  }

  @override
  String speechModelSizeMb(String sizeMb) {
    return '~$sizeMb МБ';
  }

  @override
  String speechSystemDefaultLanguage(String language) {
    return 'Системный ($language)';
  }

  @override
  String speechModelListLoadFailed(String error, String service) {
    return 'Не удалось загрузить список моделей $service: $error';
  }

  @override
  String speechDownloadFailed(String error) {
    return 'Ошибка загрузки: $error';
  }

  @override
  String speechFailedToRemoveModel(String error) {
    return 'Не удалось удалить модель: $error';
  }

  @override
  String speechBaseUrlExample(String url) {
    return 'Пример: $url';
  }

  @override
  String speechModelDefaultHelper(String model) {
    return 'По умолчанию: $model';
  }

  @override
  String get notificationPermissionOrQuestionNeedsInput =>
      'Для разрешения инструмента или вопроса требуется ваш ввод.';

  @override
  String get notificationPermissionNeedsInput =>
      'Для разрешения инструмента требуется ваш ввод.';

  @override
  String get notificationQuestionNeedsInput =>
      'Для вопроса инструмента требуется ваш ввод.';

  @override
  String get notificationSessionError => 'Сессия сообщила об ошибке.';

  @override
  String get notificationChannelErrors => 'Ошибки CodeWalk';

  @override
  String get notificationChannelErrorsDescription =>
      'Уведомления об ошибках CodeWalk';

  @override
  String get notificationChannelPermissions => 'Разрешения CodeWalk';

  @override
  String get notificationChannelPermissionsDescription =>
      'Уведомления о действиях, требующих вашего участия';

  @override
  String get notificationChannelAgent => 'Агент CodeWalk';

  @override
  String get notificationChannelAgentDescription =>
      'Уведомления о завершении работы агента CodeWalk';

  @override
  String get notificationActionOpen => 'Открыть';

  @override
  String get foregroundMonitorNotificationBody =>
      'Надежные фоновые уведомления активны';

  @override
  String get foregroundMonitorNotificationTitle =>
      'Фоновое отслеживание активно';

  @override
  String get foregroundMonitorNotificationOneSession =>
      'Отслеживается одна сессия';

  @override
  String foregroundMonitorNotificationSessionCount(int count) {
    return 'Отслеживается сессий: $count';
  }

  @override
  String sessionAttentionSemanticLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сессий требуют внимания',
      many: '$count сессий требуют внимания',
      few: '$count сессии требуют внимания',
      one: '1 сессия требует внимания',
    );
    return '$_temp0';
  }

  @override
  String get sessionAttentionOverlayPermissionRequired =>
      'Требуется разрешение на отображение поверх других приложений.';

  @override
  String get sessionAttentionIosInAppOnly =>
      'Отслеживание сессий доступно только внутри CodeWalk.';

  @override
  String get sessionAttentionOverlayPermissionGrantPrompt =>
      'Предоставьте разрешение на отображение поверх других приложений, затем попробуйте снова.';

  @override
  String get sessionAttentionAndroidStartFailed =>
      'Службе отслеживания сессий Android не удалось запуститься.';

  @override
  String chatMessageTruncatedChars(int count, String reason) {
    return '[обрезано $count символов] $reason';
  }

  @override
  String get chatMessageJustNow => 'Только что';

  @override
  String chatMessageMinutesAgo(int count) {
    return '$count мин назад';
  }

  @override
  String chatMessageHoursAgo(int count) {
    return '$count ч назад';
  }

  @override
  String chatMessageDaysAgo(int count) {
    return '$count дн. назад';
  }

  @override
  String chatMessageDateTime(int day, int hour, int minute, int month) {
    return '$day.$month $hour:$minute';
  }

  @override
  String get chatMessageYourMessage => 'Ваше сообщение';

  @override
  String get chatMessageAssistantMessage => 'Сообщение ассистента';

  @override
  String chatMessageStepStarted(int step) {
    return 'Шаг #$step начат';
  }

  @override
  String chatMessageStepStartedWithSnapshot(String snapshot, int step) {
    return 'Шаг #$step начат: $snapshot';
  }

  @override
  String chatMessageStepFinished(
    String cost,
    String reason,
    int step,
    int tokens,
  ) {
    return 'Шаг #$step завершен: $reason • токены $tokens • \$$cost';
  }

  @override
  String chatMessagePatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count патчей',
      many: '$count патчей',
      few: '$count патча',
      one: '1 патч',
    );
    return '$_temp0';
  }

  @override
  String get chatMessageToolRun => 'Запуск инструмента';

  @override
  String get chatMessageToolExecution => 'Выполнение инструмента';

  @override
  String chatMessageToolChainMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count еще',
      one: '+1 еще',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolChainExtraTypes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count типов',
      many: '+$count типов',
      few: '+$count типа',
      one: '+1 тип',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolAttentionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count требуют внимания',
      one: '1 требует внимания',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolDoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count готово',
      one: '1 готово',
    );
    return '$_temp0';
  }

  @override
  String get chatMessageToolCallsTitle => 'Вызовы инструментов';

  @override
  String get chatMessageDiffPreviewTruncated =>
      'Предпросмотр изменений обрезан для стабильности приложения.';

  @override
  String get chatMessageLargeMessageTruncated =>
      'Предпросмотр большого сообщения обрезан для стабильности приложения.';

  @override
  String get chatMessageInvalidLinkFormat => 'Недопустимый формат ссылки';

  @override
  String get chatMessageUnableToOpenLink => 'Не удалось открыть ссылку';

  @override
  String sessionTodoInProgressCompact(int current, int total) {
    return '$current/$total в работе';
  }

  @override
  String sessionTodoTaskProgress(String content, int index, int total) {
    return 'Задача $index/$total: $content';
  }

  @override
  String sessionTodoDoneCompact(int count, int total) {
    return '$count/$total готово';
  }

  @override
  String sessionTodoCompletedCount(int count, int total) {
    return 'Задач выполнено: $count/$total';
  }

  @override
  String sessionTodoTasksCount(int count) {
    return 'Задачи ($count)';
  }

  @override
  String questionStepOfReview(int current, int total) {
    return 'Шаг $current из $total — Просмотр';
  }

  @override
  String questionStepOfQuestion(int current, int total) {
    return 'Шаг $current из $total — Вопрос';
  }

  @override
  String get questionCustomAnswer => 'Свой ответ';

  @override
  String get questionSubmitAnswers => 'Отправить ответы';

  @override
  String get questionReviewAnswers => 'Просмотр ответов';

  @override
  String permissionRequestTitle(String permission) {
    return 'Запрос разрешения: $permission';
  }

  @override
  String get sessionTitleCannotBeEmpty => 'Название не может быть пустым';

  @override
  String get filesFailedToLoad => 'Не удалось загрузить файлы';

  @override
  String get filesFailedToSearch => 'Не удалось выполнить поиск файлов';

  @override
  String get filesNoOpenFilesHint =>
      'Открытых файлов пока нет. Начните вводить текст для поиска.';

  @override
  String get filesNoContentMatches => 'Совпадений по содержимому не найдено';

  @override
  String filesOpenFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count открытых файлов',
      many: '$count открытых файлов',
      few: '$count открытых файла',
      one: '1 открытый файл',
    );
    return '$_temp0';
  }

  @override
  String filesLinesSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Выбрано $count строк',
      many: 'Выбрано $count строк',
      few: 'Выбрано $count строки',
      one: 'Выбрана 1 строка',
    );
    return '$_temp0';
  }

  @override
  String get filesDraftTooLargeToSave =>
      'Черновик слишком велик, чтобы сохранить его из редактора.';

  @override
  String get filesSaveChangesBeforeClose =>
      'Сохраните изменения перед закрытием файла.';

  @override
  String get filesSaveChangesBeforePathChange =>
      'Сохраните изменения перед сменой пути.';

  @override
  String get filesWaitForSaveBeforePathChange =>
      'Дождитесь завершения сохранения файла перед сменой пути.';

  @override
  String get filesWaitForFileOperation =>
      'Дождитесь завершения операции с файлом.';

  @override
  String get filesLargeFileReadOnly =>
      'Большие файлы открываются только для чтения, чтобы редактирование оставалось отзывчивым.';

  @override
  String get filesCheckingWriteSupport => 'Проверка поддержки записи файлов...';

  @override
  String get filesActiveProjectRequired =>
      'Для операций с файлами нужна активная директория проекта.';

  @override
  String get filesReloadSkippedUnsavedChanges =>
      'Есть несохраненные изменения; перезагрузка пропущена.';

  @override
  String get filesFailedToLoadContent =>
      'Не удалось загрузить содержимое файла';

  @override
  String get filesFileSaved => 'Файл сохранен.';

  @override
  String get filesParentNotDirectory =>
      'Родительский элемент не является директорией.';

  @override
  String get filesMalformedResponse =>
      'Операция с файлом вернула некорректный ответ.';

  @override
  String get filesShellCommandDidNotComplete =>
      'Команда оболочки для операции с файлом не завершилась.';

  @override
  String get filesShellCommandNoResult =>
      'Команда оболочки для операции с файлом не вернула результат.';

  @override
  String get filesShellCommandTruncated =>
      'Команда оболочки для операции с файлом была обрезана сервером.';

  @override
  String get filesShellCommandSyntaxError =>
      'Команда оболочки для операции с файлом завершилась ошибкой синтаксиса.';

  @override
  String get filesShellUtilityNotFound =>
      'Не найдена необходимая утилита командной оболочки.';

  @override
  String get filesShellCommandFailed =>
      'Команда оболочки для операции с файлом завершилась ошибкой до выдачи результата.';

  @override
  String get attachmentSaveTitle => 'Сохранить вложение';

  @override
  String get attachmentBrowserSandboxLocalFile =>
      'Песочница браузера не позволяет открывать локальные вложения file:// напрямую.';

  @override
  String get attachmentLocalPathBrowserBlocked =>
      'Это вложение указывает на локальный путь, который нельзя открыть из браузера.';

  @override
  String terminalConnectedTo(String directory, String serverName) {
    return 'Подключено к $serverName в $directory';
  }

  @override
  String get terminalTransportUnavailable => 'Транспорт терминала недоступен.';

  @override
  String get chatSlashCommandNew => 'Создать новую сессию чата';

  @override
  String get chatSlashCommandModels => 'Открыть выбор модели';

  @override
  String get chatSlashCommandSessions => 'Открыть список диалогов';

  @override
  String get chatSlashCommandAgent => 'Открыть выбор агента';

  @override
  String get chatSlashCommandOpen => 'Быстрое открытие файла';

  @override
  String get chatSlashCommandHelp => 'Показать справку по командам';

  @override
  String get chatSlashCommandCompact => 'Сжать контекст текущей сессии';

  @override
  String get chatSlashCommandThinking =>
      'Показать или скрыть пузырьки размышлений';

  @override
  String get chatSlashCommandUndo =>
      'Отменить последний видимый ход пользователя';

  @override
  String get chatSlashCommandRedo => 'Повторить последний отмененный ход';

  @override
  String chatSessionSubConversationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count поддиалогов',
      many: '$count поддиалогов',
      few: '$count поддиалога',
      one: '1 поддиалог',
    );
    return '$_temp0';
  }

  @override
  String chatMessageWeeksAgo(int count) {
    return '$count нед. назад';
  }

  @override
  String chatMessageShortDate(int day, int month) {
    return '$day.$month';
  }

  @override
  String get chatProviderErrorLoadSessionStatus =>
      'Не удалось загрузить статус сессии';

  @override
  String get chatProviderErrorLoadSessionDetails =>
      'Не удалось загрузить часть данных сессии';

  @override
  String chatProviderErrorLoadSessionList(String error) {
    return 'Не удалось загрузить список сессий: $error';
  }

  @override
  String get chatProviderErrorCreateSession => 'Не удалось создать сессию';

  @override
  String get chatProviderErrorSelectProviderModelBeforeSend =>
      'Перед отправкой выберите подключенного провайдера или бесплатную модель OpenCode';

  @override
  String get chatProviderErrorStartMessageSend =>
      'Не удалось начать отправку сообщения';

  @override
  String get chatProviderErrorStopUnavailable =>
      'Остановка недоступна для текущей сессии';

  @override
  String get chatProviderErrorWaitForResponseFinish =>
      'Дождитесь завершения текущего ответа перед сжатием';

  @override
  String get chatProviderErrorCompactUnavailable =>
      'Сжатие контекста недоступно для текущей сессии';

  @override
  String get chatProviderErrorSelectModelBeforeCompact =>
      'Выберите модель перед сжатием контекста';

  @override
  String get chatProviderErrorCompactSessionContext =>
      'Не удалось сжать контекст сессии';

  @override
  String get chatProviderErrorNetwork =>
      'Ошибка сетевого подключения. Проверьте настройки сети';

  @override
  String get chatProviderErrorServer =>
      'Ошибка сервера. Повторите попытку позже';

  @override
  String get chatProviderErrorNotFound => 'Ресурс не найден';

  @override
  String get chatProviderErrorInvalidInput => 'Некорректные входные параметры';

  @override
  String get chatProviderErrorUnknown =>
      'Неизвестная ошибка. Повторите попытку позже';

  @override
  String get chatProviderErrorSessionFallback => 'Ошибка сессии';

  @override
  String get projectProviderErrorNoProjectContext =>
      'Контекст проекта недоступен на сервере';

  @override
  String projectProviderErrorInitializeFailed(String error) {
    return 'Не удалось инициализировать контекст проекта: $error';
  }

  @override
  String get projectProviderErrorSwitchProjectNotFound =>
      'Не удалось переключить проект: проект не найден';

  @override
  String get projectProviderErrorSwitchDirectoryEmpty =>
      'Не удалось переключить проект: директория пуста';

  @override
  String get projectProviderErrorAtLeastOneContext =>
      'Должен оставаться открытым хотя бы один контекст';

  @override
  String get projectProviderErrorReopenProjectNotFound =>
      'Не удалось заново открыть проект: проект не найден';

  @override
  String get projectProviderErrorOnlyClosedArchivable =>
      'Архивировать можно только закрытые проекты';

  @override
  String get projectProviderErrorArchiveProjectNotFound =>
      'Не удалось заархивировать проект: проект не найден';

  @override
  String get projectProviderErrorArchiveProjectPathInvalid =>
      'Не удалось заархивировать проект: путь проекта некорректен';

  @override
  String projectProviderErrorLoadWorkspaces(String error) {
    return 'Не удалось загрузить рабочие пространства: $error';
  }

  @override
  String get projectProviderErrorWorkspaceNameEmpty =>
      'Название рабочего пространства не может быть пустым';

  @override
  String projectProviderErrorCreateWorkspace(String error) {
    return 'Не удалось создать рабочее пространство: $error';
  }

  @override
  String projectProviderErrorResetWorkspace(String error) {
    return 'Не удалось сбросить рабочее пространство: $error';
  }

  @override
  String projectProviderErrorDeleteWorkspace(String error) {
    return 'Не удалось удалить рабочее пространство: $error';
  }

  @override
  String get projectProviderErrorDirectoryEmpty =>
      'Директория не может быть пустой';

  @override
  String projectProviderErrorListDirectories(String error) {
    return 'Не удалось получить список директорий: $error';
  }

  @override
  String projectProviderErrorValidateDirectory(String error) {
    return 'Не удалось проверить директорию: $error';
  }

  @override
  String get projectProviderErrorPathEmpty => 'Путь не может быть пустым';

  @override
  String projectProviderErrorListFiles(String error) {
    return 'Не удалось получить список файлов: $error';
  }

  @override
  String projectProviderErrorSearchFiles(String error) {
    return 'Не удалось выполнить поиск файлов: $error';
  }

  @override
  String projectProviderErrorContentSearchUnavailable(String error) {
    return 'Поиск по содержимому недоступен: $error';
  }

  @override
  String projectProviderErrorSearchSymbols(String error) {
    return 'Не удалось выполнить поиск символов: $error';
  }

  @override
  String projectProviderErrorReadFile(String error) {
    return 'Не удалось прочитать файл: $error';
  }

  @override
  String projectProviderErrorLoadProjectList(String error) {
    return 'Не удалось загрузить список проектов: $error';
  }

  @override
  String get workspaceProjectRemovedFromHistory => 'Проект удален из истории';

  @override
  String workspaceProjectContextOpened(String directory) {
    return 'Контекст проекта открыт: $directory';
  }

  @override
  String workspaceFailedToOpenProjectContext(String directory) {
    return 'Не удалось открыть контекст проекта: $directory';
  }

  @override
  String get chatAbortNotice => 'Что вы хотите сделать иначе?';

  @override
  String sessionTitleToday(String date, String time) {
    return 'Сегодня $time ($date)';
  }

  @override
  String sessionTitleYesterday(String date, String time) {
    return 'Вчера $time ($date)';
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
  String get sessionWeekdayMon => 'Пн';

  @override
  String get sessionWeekdayTue => 'Вт';

  @override
  String get sessionWeekdayWed => 'Ср';

  @override
  String get sessionWeekdayThu => 'Чт';

  @override
  String get sessionWeekdayFri => 'Пт';

  @override
  String get sessionWeekdaySat => 'Сб';

  @override
  String get sessionWeekdaySun => 'Вс';

  @override
  String get forwardTimeNow => 'сейчас';

  @override
  String forwardTimeMinutes(int count) {
    return '$count мин';
  }

  @override
  String forwardTimeHours(int count) {
    return '$count ч';
  }

  @override
  String forwardTimeDays(int count) {
    return '$count дн';
  }

  @override
  String forwardTimeWeeks(int count) {
    return '$count нед';
  }

  @override
  String get settingsBehaviorConfigFieldDefaultModel => 'модель по умолчанию';

  @override
  String get settingsBehaviorConfigFieldDefaultAgent => 'агент по умолчанию';

  @override
  String get settingsBehaviorConfigFieldSmallModel => 'малая модель';

  @override
  String get settingsBehaviorConfigFieldAutoUpdateMode =>
      'режим автообновления';

  @override
  String get settingsBehaviorConfigFieldSnapshotSetting =>
      'настройка снапшотов';

  @override
  String get settingsBehaviorConfigFieldConversationUsername =>
      'имя пользователя в диалоге';

  @override
  String get settingsBehaviorConfigFieldSharingDefault =>
      'настройка общего доступа по умолчанию';

  @override
  String get speechMicNoInputDevice => 'Устройство ввода микрофона недоступно.';

  @override
  String get speechMicDeviceBusy =>
      'Микрофон по умолчанию сейчас используется другим приложением.';

  @override
  String get speechMicUnsupportedFormat =>
      'Формат микрофона по умолчанию не поддерживается.';

  @override
  String get speechMicSpeechPrivacy =>
      'Возможно, отключены службы речи Windows (конфиденциальность речи, онлайн-распознавание речи или языковые пакеты).';

  @override
  String get speechMicBackendUnavailable =>
      'Бэкенд микрофона Windows недоступен в этой сборке.';

  @override
  String speechEngineFallbackNotice(String fallback, String reason) {
    return 'Выбранный STT-движок недоступен ($reason). Вместо него используется $fallback.';
  }

  @override
  String get oauthFlowSecureStorageUnavailable =>
      'Защищенное хранилище учетных данных недоступно для OAuth.';

  @override
  String get oauthFlowUnexpectedError =>
      'Поток OAuth неожиданно завершился ошибкой. Попробуйте еще раз.';

  @override
  String get oauthFlowNoEndpointsDiscovered =>
      'Точки OAuth не обнаружены. Включите Managed OAuth в Cloudflare Dashboard → Access → Applications → [это приложение].';

  @override
  String get oauthFlowTokenResponseMissingAccessToken =>
      'Ответ с токеном OAuth не содержал токен доступа.';

  @override
  String get oauthFlowProfileChanged =>
      'Профиль сервера изменился до завершения OAuth.';

  @override
  String get oauthFlowMetadataMissingEndpoints =>
      'В метаданных OAuth отсутствуют точки авторизации и получения токена.';

  @override
  String get oauthFlowCallbackNotCompleted =>
      'Обратный вызов авторизации не был завершен';

  @override
  String get oauthFlowProviderDeclined =>
      'Сервер авторизации отклонил запрос OAuth. Попробуйте еще раз.';

  @override
  String get oauthFlowCallbackValidationFailed =>
      'Не удалось проверить обратный вызов OAuth. Попробуйте еще раз.';

  @override
  String get oauthFlowCallbackServerStartFailed =>
      'Не удалось запустить локальный сервер обратного вызова OAuth.';

  @override
  String get oauthFlowSignInCanceled => 'Вход через OAuth отменен.';

  @override
  String get oauthFlowBrowserOpenFailed =>
      'Не удалось открыть системный браузер для входа через OAuth.';

  @override
  String get oauthFlowCallbackTimeout =>
      'Ни один обратный вызов авторизации не достиг приложения в течение 5 минут. Браузер должен был перенаправить на локальный адрес обратного вызова после согласия. Если вместо этого браузер показал ошибку подключения, это устройство или сеть блокирует переадресацию через loopback.';

  @override
  String oauthFlowTokenExchangeTransientFailure(int maxAttempts) {
    return 'Обмен токена не удался после $maxAttempts попыток из-за временной проблемы с сетью. Попробуйте еще раз.';
  }

  @override
  String oauthFlowTokenExchangeHttpFailure(int statusCode) {
    return 'Обмен токена не удался (HTTP $statusCode). Попробуйте еще раз.';
  }

  @override
  String get oauthFlowTokenExchangeUnexpectedFailure =>
      'Обмен токена неожиданно завершился ошибкой. Попробуйте еще раз.';

  @override
  String get oauthFlowTokenExchangeIncomplete =>
      'Обмен токена не завершился после отправки кода авторизации. Начните вход через OAuth заново.';

  @override
  String get speechReadAloudFailed => 'Не удалось озвучить текст.';

  @override
  String get speechReadAloudNoText => 'Нет текста для озвучивания.';

  @override
  String get speechEdgeTextTooLong =>
      'Microsoft Edge Speech может озвучить за раз не более 4096 байт.';

  @override
  String get speechEdgeMalformedAudio =>
      'Microsoft Edge Speech вернул поврежденные аудиоданные.';

  @override
  String get speechEdgeUnsupportedAudio =>
      'Microsoft Edge Speech вернул неподдерживаемые аудиоданные.';

  @override
  String get speechEdgeUnsupportedFrame =>
      'Microsoft Edge Speech вернул неподдерживаемый websocket-кадр.';

  @override
  String get speechEdgeSynthesisInterrupted =>
      'Microsoft Edge Speech завершился до окончания синтеза речи.';

  @override
  String get speechEdgeEmptyAudio =>
      'Microsoft Edge Speech вернул пустой аудиоответ.';

  @override
  String get speechEdgeTimedOut =>
      'Истекло время ожидания Microsoft Edge Speech.';

  @override
  String get speechEdgeUnreachable =>
      'Не удалось связаться с Microsoft Edge Speech.';

  @override
  String get speechApiKeyMissing =>
      'Добавьте API-ключ в Настройки > Речь, чтобы использовать этого TTS-провайдера.';

  @override
  String get speechProviderEmptyAudio =>
      'TTS-провайдер вернул пустой аудиоответ.';

  @override
  String get speechProviderRequestRejected =>
      'TTS-провайдер отклонил запрос на озвучивание.';

  @override
  String get speechApiKeyRejected => 'Провайдер отклонил API-ключ TTS.';

  @override
  String get speechProviderQuotaRateLimit =>
      'TTS-провайдер сообщил о превышении квоты или лимита запросов.';

  @override
  String get speechProviderTemporarilyUnavailable =>
      'TTS-провайдер временно недоступен.';

  @override
  String get speechProviderUnreachable =>
      'Не удалось связаться с TTS-провайдером.';

  @override
  String appProviderErrorFailedToStartProcess(String tool) {
    return 'Не удалось запустить процесс $tool.';
  }

  @override
  String appProviderErrorToolNotAvailable(String runtime, String tool) {
    return '$tool недоступен. Сначала установите $runtime.';
  }

  @override
  String appProviderErrorToolInstallFailed(int exitCode, String tool) {
    return 'Установка $tool не удалась: код выхода $exitCode.';
  }

  @override
  String appProviderErrorBunBootstrapFailed(int exitCode) {
    return 'Сбой загрузки Bun: код выхода $exitCode.';
  }

  @override
  String get appProviderErrorInstalledButNotFoundInPath =>
      'Установка OpenCode завершилась, но команда не найдена в PATH.';

  @override
  String get appProviderErrorInstalledButPathNotResolved =>
      'Установка OpenCode завершилась, но не удалось определить путь к команде.';

  @override
  String appProviderErrorConfiguredCommandNotFound(String tool) {
    return 'Настроенная команда не найдена, и $tool нет в PATH.';
  }

  @override
  String get appProviderErrorConfiguredCommandPathMissing =>
      'Путь к настроенной команде не существует.';

  @override
  String get appProviderErrorConfiguredCommandVersionCheckFailed =>
      'Настроенная команда существует, но проверка версии не удалась.';

  @override
  String get appProviderErrorConfiguredCommandExecutionFailed =>
      'Не удалось выполнить настроенную команду.';

  @override
  String get appProviderWslCheckWindowsOnly =>
      'Проверка WSL применяется только к Windows.';

  @override
  String get appProviderDesktopBuildRequired =>
      'Используйте настольную версию, чтобы настроить управляемый локальный сервер.';

  @override
  String get appProviderKnownInstallationDirectoryDetected =>
      'Обнаружено в известном каталоге установки.';

  @override
  String appProviderKnownInstallationPathRefreshHint(String appName) {
    return 'Обнаружено в известном каталоге установки. Возможно, потребуется обновить PATH: перезапустите $appName, если недавняя установка еще не обнаружена.';
  }

  @override
  String get appProviderErrorReleaseMetadataFetchFailed =>
      'Не удалось получить метаданные последнего релиза из GitHub.';

  @override
  String get appProviderErrorReleaseAssetListMissing =>
      'В метаданных последнего релиза не было списка файлов.';

  @override
  String get appProviderErrorNoCompatibleAsset =>
      'Совместимый бинарный файл OpenCode не найден.';

  @override
  String get appProviderErrorDownloadAssetFailed =>
      'Не удалось загрузить выбранный файл OpenCode.';

  @override
  String get appProviderErrorChecksumVerificationFailed =>
      'Не удалось проверить контрольную сумму загруженного файла.';

  @override
  String get appProviderErrorExtractArchiveFailed =>
      'Не удалось извлечь бинарный архив OpenCode.';

  @override
  String appProviderErrorExecutableNotFound(String tool) {
    return 'Не удалось найти исполняемый файл $tool в извлеченных файлах.';
  }

  @override
  String get chatNoResponseFromServer =>
      'Сервер не ответил. Попробуйте еще раз.';

  @override
  String get chatNoResponseFromModel =>
      'Модель не ответила. Попробуйте еще раз.';

  @override
  String get speechJobCancelled => 'Задача озвучивания была отменена.';

  @override
  String get speechEdgeCancelled => 'Microsoft Edge Speech был отменен.';

  @override
  String get sessionAttentionKindActive => 'Активно';

  @override
  String get sessionAttentionKindReceiving => 'Получение';

  @override
  String get sessionAttentionKindDelayed => 'Задержано';

  @override
  String get sessionAttentionKindCompleted => 'Завершено';

  @override
  String get sessionAttentionKindPendingInteraction => 'Ожидает взаимодействия';

  @override
  String get sessionAttentionKindError => 'Ошибка';

  @override
  String get sessionAttentionPauseCellularDataSaver =>
      'Активен режим экономии мобильных данных';

  @override
  String get sessionAttentionPauseOauthReopenRequired =>
      'Требуется вход через OAuth';

  @override
  String get sessionAttentionPauseTailscaleReopenRequired =>
      'Требуется подключение Tailscale';

  @override
  String get sessionAttentionPauseOffline => 'Офлайн';

  @override
  String get sessionAttentionPausePermissionRevoked => 'Разрешение отозвано';

  @override
  String get sessionAttentionPauseServiceStopped => 'Служба остановлена';

  @override
  String get sessionAttentionPauseHostUnavailable => 'Хост недоступен';

  @override
  String get errorRequestCancelled => 'Запрос отменён';

  @override
  String errorUnknownNetworkError(String error) {
    return 'Неизвестная сетевая ошибка: $error';
  }

  @override
  String get errorCertificateError => 'Ошибка сертификата';

  @override
  String get errorSessionBusy => 'Сеанс занят обработкой другого запроса.';

  @override
  String get errorRunShellCommandFailed =>
      'Не удалось выполнить команду оболочки';

  @override
  String get errorRunSlashCommandFailed => 'Не удалось выполнить слеш-команду';

  @override
  String get settingsBehaviorOpenCodeDefaultsLoadError =>
      'Не удалось загрузить значения по умолчанию на основе OpenCode с активного сервера.';

  @override
  String get sessionTabIconRemoveFailed =>
      'Не удалось удалить данные значка локальной вкладки сеанса';

  @override
  String get forwardUntitled => 'Без названия';

  @override
  String setupDebugLinuxLogsPath(String path) {
    return 'Журналы Linux: $path';
  }

  @override
  String setupDebugRunOpenCodeCommand(String command) {
    return 'Запустите OpenCode с помощью: $command';
  }

  @override
  String setupDebugServerHealthEndpoint(String endpoint) {
    return 'Работоспособность сервера: $endpoint';
  }

  @override
  String setupDebugServerDocsEndpoint(String endpoint) {
    return 'Документация сервера: $endpoint';
  }

  @override
  String get logsEntryError => 'Ошибка';

  @override
  String get logsEntryStack => 'Стек';

  @override
  String get setupDebugSourceDiagnostics => 'Диагностика';

  @override
  String get setupDebugSourceUseExisting => 'Использовать существующий';

  @override
  String get setupDebugSourceLocalServer => 'Локальный сервер';

  @override
  String get setupDebugSourceOnboarding => 'Онбординг';

  @override
  String get setupDebugSourceManualConnection => 'Ручное подключение';

  @override
  String setupDebugMessageDiagnosticsResult(
    String availability,
    String platform,
    String recommendation,
  ) {
    return '$availability на $platform. $recommendation';
  }

  @override
  String get setupDebugMessageDetectAttempt =>
      'Попытка обнаружить существующую команду OpenCode в текущем окружении.';

  @override
  String get setupDebugMessageInstallStarted =>
      'Установка OpenCode запущена из CodeWalk.';

  @override
  String setupDebugMessageStartLocalServer(String url) {
    return 'Запуск управляемого сервера OpenCode по адресу $url.';
  }

  @override
  String setupDebugMessageHealthyRunning(String url) {
    return 'Управляемый сервер OpenCode работает корректно по адресу $url.';
  }

  @override
  String get setupDebugMessageStoppingLocalServer =>
      'Остановка управляемого сервера OpenCode.';

  @override
  String get setupDebugMessageStoppedCleanly =>
      'Управляемый сервер OpenCode остановлен корректно.';

  @override
  String get setupDebugMessageExitedAfterRequestedStop =>
      'Управляемый сервер OpenCode завершил работу после запрошенной остановки.';

  @override
  String get setupDebugMessageOnboardingConnectExisting =>
      'Пользователь выбрал подключение к существующему серверу OpenCode.';

  @override
  String get setupDebugMessageOnboardingGuidedPath =>
      'Пользователь открыл путь управляемой настройки OpenCode.';

  @override
  String get setupDebugMessageOnboardingManagedLocal =>
      'Пользователь открыл управляемую локальную настройку OpenCode.';

  @override
  String get setupDebugMessageOnboardingOpenedServerSettings =>
      'Пользователь открыл настройки сервера после неудачной проверки работоспособности.';

  @override
  String get setupDebugMessageOnboardingAddAnotherServer =>
      'Пользователь выбрал добавление другого сервера после неудачной проверки работоспособности.';

  @override
  String setupDebugMessageTestingServerUrl(String url) {
    return 'Проверка URL сервера OpenCode $url из процесса настройки.';
  }

  @override
  String get chatProviderErrorSessionNotFound => 'Сессия не найдена';

  @override
  String get chatProviderErrorInvalidMessageFormat =>
      'Некорректный формат сообщения';

  @override
  String get chatProviderErrorNetworkShort => 'Ошибка сетевого подключения';

  @override
  String get chatProviderErrorUnknownShort => 'Неизвестная ошибка';

  @override
  String get terminalCreateFailed => 'Не удалось создать сессию терминала';

  @override
  String get terminalEndpointUnavailable =>
      'Конечная точка терминала недоступна';

  @override
  String get terminalInvalidDirectory => 'Недопустимый каталог терминала';

  @override
  String get terminalWebsocketUnavailable =>
      'Вебсокет терминала здесь недоступен.';

  @override
  String chatMessageToolChainCallsCompact(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count вызовов',
      many: '$count вызовов',
      few: '$count вызова',
      one: '1 вызов',
    );
    return '$_temp0';
  }

  @override
  String get errorConnectionTimeout => 'Время ожидания соединения истекло';

  @override
  String get errorClientError => 'Ошибка клиента';

  @override
  String get chatProviderErrorSendMessage => 'Не удалось отправить сообщение';

  @override
  String get speechApiEngine => 'API';

  @override
  String get speechApiEngineSubtitle =>
      'OpenAI, Groq или пользовательская конечная точка, совместимая с OpenAI.';

  @override
  String get speechApiProvider => 'Поставщик преобразования речи в текст';

  @override
  String get speechCloudSttPrivacy =>
      'Конфиденциальность облачного распознавания речи';

  @override
  String get speechCloudSttPrivacyDescription =>
      'Записанный звук с микрофона отправляется настроенному поставщику. Ключи API хранятся в защищённом хранилище этого устройства.';

  @override
  String get speechApiKeyOptional =>
      'Необязательно для пользовательских конечных точек.';

  @override
  String speechApiBatchHint(String provider) {
    return '$provider использует пакетную транскрипцию. Нажмите на микрофон ещё раз, чтобы остановить и транскрибировать.';
  }

  @override
  String get speechApiWebUnavailable =>
      'Распознавание речи через API недоступно в веб-версии.';

  @override
  String get speechApiConfigInvalid =>
      'Проверьте конечную точку и модель API речи. Удалённые конечные точки должны использовать HTTPS.';

  @override
  String get speechApiRequestInvalid =>
      'Конечная точка или модель речи была отклонена.';

  @override
  String get speechApiRateLimited =>
      'Поставщик речи сообщил о превышении квоты или лимита запросов.';

  @override
  String get speechApiUnavailable => 'Поставщик речи временно недоступен.';

  @override
  String get speechApiNetwork => 'Не удалось связаться с поставщиком речи.';

  @override
  String get speechApiInvalidResponse =>
      'Поставщик речи вернул недопустимый ответ.';

  @override
  String get speechApiEmptyAudio => 'Звук с микрофона не записан.';

  @override
  String get speechApiEmptyTranscript =>
      'Поставщик речи не вернул транскрипцию.';

  @override
  String get speechApiCustomProvider =>
      'Пользовательская, совместимая с OpenAI';

  @override
  String get speechApiMaxDuration =>
      'API-записи автоматически останавливаются через 2 минуты.';

  @override
  String get speechApiLanguageHint =>
      'Активный язык приложения отправляется как подсказка для транскрипции.';

  @override
  String get speechSttApiKeyStorageUnavailable =>
      'Защищённое хранилище ключей API речи недоступно.';

  @override
  String get speechSttApiKeyMissing =>
      'Добавьте ключ API речи в Настройки > Речь.';

  @override
  String get speechSttApiKeyRejected => 'Ключ API речи был отклонён.';

  @override
  String get carMessagingConversations => 'Беседы Android Auto';

  @override
  String get carMessagingReply => 'Ответить';

  @override
  String get carMessagingMarkRead => 'Отметить как прочитанное';

  @override
  String get carMessagingChannelDescription =>
      'Экспериментальные ответы на беседы CodeWalk';

  @override
  String get settingsAndroidAutoMessagingDescription =>
      'Экспериментальная поддержка тестовых сборок для финальных ответов и голосовых ответов. Не одобрено для распространения через Google Play.';

  @override
  String get carMessagingDeliveryFailedTitle => 'Не удалось отправить ответ';

  @override
  String get carMessagingDeliveryFailedBody =>
      'Не удалось доставить ваш голосовой ответ. Откройте CodeWalk, чтобы повторить попытку.';
}
