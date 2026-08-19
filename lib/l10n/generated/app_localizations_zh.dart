// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get aboutGitHub => 'GitHub';

  @override
  String get appProviderCannotActivateUnhealthy => '无法激活不健康的服务器';

  @override
  String get appProviderDesktopOnly => '托管本地服务器仅在桌面端可用。';

  @override
  String get appProviderDetectingCommand => '正在检测 OpenCode 命令...';

  @override
  String get appProviderErrorCannotActivateUnhealthy => '无法激活不健康的服务器';

  @override
  String get appProviderErrorCloudflareOAuthNotSupported =>
      '此平台不支持 Cloudflare Access OAuth';

  @override
  String get appProviderErrorInstallationFailed => 'OpenCode 安装失败。';

  @override
  String get appProviderErrorInvalidServerUrl => '无效的服务器 URL';

  @override
  String get appProviderErrorLocalServerHealthCheckFailed =>
      '本地服务器已启动，但健康检查未通过。';

  @override
  String get appProviderErrorManagedDesktopOnly => '托管本地服务器仅在桌面端可用。';

  @override
  String get appProviderErrorServerAlreadyExists => '使用此 URL 的服务器已存在';

  @override
  String get appProviderErrorServerProfileNotFound => '找不到服务器配置文件';

  @override
  String get appProviderErrorServerUrlRequired => '服务器 URL 是必填项';

  @override
  String get appProviderErrorTailscaleNotSupported => '此平台不支持 Tailscale';

  @override
  String appProviderExitedWithCode(int code) {
    return '本地服务器已退出，退出代码为 $code。';
  }

  @override
  String get appProviderFailedToStart => '启动本地 OpenCode 服务器失败。';

  @override
  String get appProviderInstallBinary => '安装二进制文件';

  @override
  String get appProviderInstallBunOpenCode => '安装 Bun + OpenCode';

  @override
  String get appProviderInstallSucceeded => '安装成功。';

  @override
  String appProviderInstallSucceededWithPath(String path) {
    return '安装成功。OpenCode 命令位于 $path。';
  }

  @override
  String get appProviderInstallViaBun => '通过 Bun 安装';

  @override
  String get appProviderInstallViaNpm => '通过 npm 安装';

  @override
  String get appProviderInstallationFailed => 'OpenCode 安装失败。';

  @override
  String get appProviderInstalledSuccessfully => 'OpenCode 要求已成功安装。';

  @override
  String get appProviderInstallingRequirements => '正在安装 OpenCode 要求...';

  @override
  String get appProviderInvalidServerUrl => '无效的服务器 URL';

  @override
  String get appProviderLabelLocalOpenCodeManaged => '本地 OpenCode (托管)';

  @override
  String get appProviderLabelPrimaryServer => '主服务器';

  @override
  String get appProviderLocalManaged => '本地 OpenCode (托管)';

  @override
  String get appProviderLocalServerStopped => '本地服务器已停止。';

  @override
  String get appProviderNotDetectedInstall => '未检测到 OpenCode 命令。请从向导运行安装。';

  @override
  String appProviderNotDetectedRefresh(String appName) {
    return '未检测到 OpenCode 命令。如果您刚刚安装，请刷新检查或重新打开 $appName 以重新加载 PATH。';
  }

  @override
  String get appProviderOAuthNotSupported => '此平台不支持 Cloudflare Access OAuth';

  @override
  String get appProviderOpenCodeDetected => '已检测到 OpenCode';

  @override
  String get appProviderOpenCodeNotDetected => '未检测到 OpenCode';

  @override
  String get appProviderPrimaryServer => '主服务器';

  @override
  String get appProviderProfileNotFound => '找不到服务器配置文件';

  @override
  String get appProviderRunDiagnostics => '运行诊断以验证本地 OpenCode 要求。';

  @override
  String appProviderRunningAt(String url) {
    return '运行于 $url';
  }

  @override
  String get appProviderSetupDetectingOpenCode => '正在检测 OpenCode 命令...';

  @override
  String get appProviderSetupInstallationSucceeded => '安装成功。';

  @override
  String appProviderSetupInstallationSucceededWithPath(String path) {
    return '安装成功。OpenCode 命令位于 $path。';
  }

  @override
  String get appProviderSetupInstallingRequirements => '正在安装 OpenCode 要求...';

  @override
  String get appProviderSetupOpenCodeDetected => '已检测到 OpenCode';

  @override
  String get appProviderSetupOpenCodeNotDetected => '未检测到 OpenCode';

  @override
  String get appProviderSetupOpenCodeNotDetectedInstall =>
      '未检测到 OpenCode 命令。请从向导运行安装。';

  @override
  String get appProviderSetupOpenCodeNotDetectedRefresh =>
      '未检测到 OpenCode 命令。如果您刚刚安装，请刷新检查或重新打开 CodeWalk 以重新加载 PATH。';

  @override
  String get appProviderSetupRequirementsInstalled => 'OpenCode 要求已成功安装。';

  @override
  String appProviderSetupUsingOpenCodeAt(String path) {
    return '正在使用位于 $path 的 OpenCode 命令';
  }

  @override
  String get appProviderStartingLocalServer => '正在启动本地服务器...';

  @override
  String appProviderStatusLocalServerExitedWithCode(int code) {
    return '本地服务器已退出，退出代码为 $code。';
  }

  @override
  String get appProviderStatusLocalServerStopped => '本地服务器已停止。';

  @override
  String appProviderStatusRunningAt(String url) {
    return '运行于 $url';
  }

  @override
  String get appProviderStatusStartingLocalServer => '正在启动本地服务器...';

  @override
  String get appProviderStatusStoppingLocalServer => '正在停止本地服务器...';

  @override
  String get appProviderStoppingLocalServer => '正在停止本地服务器...';

  @override
  String get appProviderTailscaleNotSupported => '此平台不支持 Tailscale';

  @override
  String appProviderUsingCommandAt(String path) {
    return '正在使用位于 $path 的 OpenCode 命令';
  }

  @override
  String get appShellDownloadingUpdate => '正在下载更新';

  @override
  String get appShellInstall => '安装';

  @override
  String get appShellInstallFailed => '安装失败';

  @override
  String get appShellInstallingUpdate => '正在安装更新...';

  @override
  String get appShellRestart => '重启';

  @override
  String appShellUpdateAvailableResult(String latestVersion) {
    return '有可用更新: v$latestVersion';
  }

  @override
  String get appShellUpdateInstalledRestartApp => '更新已安装。请重启应用以生效。';

  @override
  String get appShellUpdateInstalledRestartRequired => '更新已安装。需要重启以应用新版本。';

  @override
  String get attachmentCouldNotDecode => '无法解码附件数据。';

  @override
  String get attachmentCouldNotDownload => '无法下载附件。';

  @override
  String get attachmentCouldNotSave => '无法在此设备上保存附件。';

  @override
  String get attachmentDownloadStarted => '附件下载已开始。';

  @override
  String get attachmentLocalNotFound => '在此设备上找不到本地附件。';

  @override
  String get attachmentNoValidLocation => '附件未提供有效位置。';

  @override
  String get attachmentNotAvailableOnPlatform => '附件操作在此平台上不可用。';

  @override
  String get attachmentPathEmpty => '附件路径为空。';

  @override
  String get attachmentPayloadEmpty => '附件有效负载为空。';

  @override
  String get attachmentSaveCanceled => '保存已取消。';

  @override
  String attachmentSavedAndOpened(String path) {
    return '附件已保存至 $path 并打开。';
  }

  @override
  String attachmentSavedPath(String path) {
    return '附件已保存至 $path。';
  }

  @override
  String attachmentSavedTo(String path) {
    return '附件已保存至 $path。';
  }

  @override
  String get attachmentUnableToOpenLink => '无法打开附件链接。';

  @override
  String get attachmentUnableToOpenLocal => '无法打开本地附件。';

  @override
  String get behaviorAdvancedPermissionRule => '高级权限规则';

  @override
  String get behaviorAutomatic => '自动';

  @override
  String get behaviorAutomaticFallback => '自动回退';

  @override
  String get behaviorCellularDataSaver => '移动数据节省';

  @override
  String get behaviorCellularDataSaverActive => '蜂窝数据节省模式已开启。';

  @override
  String get behaviorChatLevelShare => '聊天级别共享';

  @override
  String get behaviorCodeWalkReleaseChecks => 'CodeWalk版本检查';

  @override
  String get behaviorControlsOfficialGlobal => '控制OpenCode官方全局设置';

  @override
  String get behaviorControlsUpstreamOpenCode => '控制上游OpenCode设置';

  @override
  String get behaviorCustomDisplayName => '自定义显示名称';

  @override
  String behaviorCutsAutomaticMobile(int inSeconds) {
    return '通过停止后台下载并将前台自动刷新限制为每$inSeconds秒一次突发，减少自动移动数据使用。';
  }

  @override
  String get behaviorDataSaverActive => '当前已在移动数据网络上激活。';

  @override
  String get behaviorDataSaverAggressive => '激进';

  @override
  String get behaviorDataSaverAggressiveDescription =>
      '低带宽模式：仅可见工作区流保持实时，全局更新暂停，自动刷新间隔延长。';

  @override
  String get behaviorDataSaverCellularOnly => '仅在蜂窝/移动网络连接时适用。';

  @override
  String get behaviorDataSaverOff => '关闭';

  @override
  String get behaviorDataSaverOffHint => '已启用完整的实时更新和自动刷新。';

  @override
  String get behaviorDataSaverStandard => '标准';

  @override
  String get behaviorDataSaverWaiting => '正在等待下一个移动数据同步窗口。';

  @override
  String get behaviorDisabled => '已禁用';

  @override
  String get behaviorLightweightTasksLike => '轻量级任务如';

  @override
  String get behaviorManual => '手动';

  @override
  String get behaviorNotify => '通知';

  @override
  String get behaviorOfficialOpenCodePermission =>
      '官方 OpenCode 权限策略在 `opencode.json` 中配置，针对每个工具有 允许/询问/拒绝 规则。CodeWalk 保留了官方的权限请求卡片，并添加了一个经批准的 ADR-023 异常：编辑器（composer）自动批准开关无条件回复 `Always` 且 `remember: true`，以创建持久的会话范围授权，并在 Android 后台工作进程中保持相同的线程范围连续性路径处于活动状态。';

  @override
  String get behaviorOpenCodeBackedDefaults => 'OpenCode 支持的默认设置';

  @override
  String get behaviorPermissionHandlingProvenance => '权限处理来源';

  @override
  String get behaviorPermissionsVariantReasoning =>
      '权限与变体/推理对齐在 UI 能够安全保留高级配置之前将保持分离。';

  @override
  String get behaviorPrimaryAgentAgent => '在未显式选择智能体时使用的主要智能体。';

  @override
  String get behaviorRefreshDefaults => '刷新默认值';

  @override
  String get behaviorSharedAcrossOpenCode => '通过配置在 OpenCode 客户端之间共享。';

  @override
  String get behaviorTheseValuesWrite =>
      '这些值会写入活动服务器上的 `/config` 并与官方 OpenCode 共享配置匹配。';

  @override
  String get cannedAddTitle => '添加快捷回复';

  @override
  String get cannedAppendAtCursor => '在光标处追加';

  @override
  String get cannedAppendAtCursorSubtitle => '关闭 = 替换当前编辑器文本';

  @override
  String get cannedAttachFiles => '附加文件';

  @override
  String get cannedEditTitle => '编辑快捷回复';

  @override
  String get cannedNewQuickReply => '新快速回复';

  @override
  String get cannedNoSuggestions => '无建议';

  @override
  String get cannedOffMeansReplace => '关闭表示替换当前编辑器文本';

  @override
  String get cannedQuickReply => '新建快速回复';

  @override
  String get cannedReplace => '替换';

  @override
  String get cannedScopeGlobalSubtitle => '禁用为仅项目项';

  @override
  String get cannedScopeGlobalUnavailableSubtitle => '当前上下文中仅项目不可用';

  @override
  String get cannedSendAutomaticallySubtitle => '插入此快速回复后立即发送';

  @override
  String get cannedSendImmediatelyInserting => '插入此快速回复后立即发送';

  @override
  String get cannedTextLabel => '文本';

  @override
  String get chatActionNext => '下一步';

  @override
  String get chatActiveServerUnhealthy => '活动服务器处于亚健康状态。在恢复之前，发送将尝试一次并快速失败。';

  @override
  String get chatActiveServerUnhealthyLabel => '当前服务器状态异常';

  @override
  String get chatAddServerToStart => '添加服务器以开始聊天。';

  @override
  String get chatAppBarMoreActions => '更多操作';

  @override
  String get chatAppBarPinAction => '固定到应用栏';

  @override
  String get chatAppBarPinDescription => '此操作将保持在菜单外可见。';

  @override
  String get chatAppBarUnpinAction => '从应用栏取消固定';

  @override
  String get chatAppBarUnpinDescription => '此操作将移回菜单中。';

  @override
  String chatBadgeConversationError(String title) {
    return '“$title”出现错误。';
  }

  @override
  String chatBadgeConversationNeedsInput(String title) {
    return '“$title”需要您的输入。';
  }

  @override
  String chatBadgeConversationNewReply(String title) {
    return '“$title”有新回复。';
  }

  @override
  String get chatBadgeDataSaverActive => '移动数据节省模式已开启。';

  @override
  String get chatBadgeServerNeedsAttention => '服务器连接需要注意。';

  @override
  String get chatBadgeSyncing => '正在同步会话...';

  @override
  String get chatBlockResponsePendingDescription => '本轮结束后，答案将以单个块的形式显示。';

  @override
  String get chatBlockResponsePendingTitle => '正在生成回复';

  @override
  String get chatCachedConversationsYet => '暂无缓存的对话';

  @override
  String get chatChangedFilesAvailable => '此会话没有可用的更改文件。';

  @override
  String chatChildrenChatProviderCurrentSessionChildren(int length) {
    return '子项: $length';
  }

  @override
  String get chatChooseAgent => '选择代理';

  @override
  String get chatChooseDirectory => '选择目录';

  @override
  String get chatChooseEffort => '选择努力程度';

  @override
  String get chatChooseFolderOpen => '选择一个文件夹作为项目上下文打开。';

  @override
  String get chatChooseModel => '选择模型';

  @override
  String get chatClose => '关闭';

  @override
  String chatCloseProject(String project) {
    return '关闭 $project';
  }

  @override
  String get chatCollapseGroup => '折叠分组';

  @override
  String get chatCommandDescriptionProject => '项目命令';

  @override
  String get chatCommandSourceGeneric => '命令';

  @override
  String get chatCommandSourceProject => '项目';

  @override
  String get chatCompactContext => '紧凑上下文';

  @override
  String get chatComposerHintShell => 'Shell命令（按Esc退出）';

  @override
  String get chatComposerPlaceholder => '输入您的需求...';

  @override
  String get chatConversation => '会话';

  @override
  String get chatConversations => '会话';

  @override
  String get chatConversationsPane => '会话';

  @override
  String chatCostLabel(double cost) {
    return '费用：\$$cost';
  }

  @override
  String get chatCouldNotRefreshSession => '无法刷新此对话';

  @override
  String get chatCurrent => '使用当前';

  @override
  String chatDescriptionChildren(int count) {
    return '子项：$count';
  }

  @override
  String get chatDescriptionCloseApp => '使用平台关闭行为关闭应用';

  @override
  String get chatDescriptionCycleModels => '循环切换近期模型';

  @override
  String get chatDescriptionCycleVariant => '循环切换模型变体';

  @override
  String get chatDescriptionDiffFilesZero => '差异文件：0';

  @override
  String get chatDescriptionFocusInput => '聚焦消息输入框';

  @override
  String get chatDescriptionFocusOrCloseDrawer => '聚焦输入框（或在打开时关闭侧边栏）';

  @override
  String get chatDescriptionForceExit => '强制退出应用';

  @override
  String get chatDescriptionNewConversation => '新会话';

  @override
  String get chatDescriptionNextAgent => '下一个代理';

  @override
  String get chatDescriptionOpenProjects => '使用此按钮打开您的项目和会话。';

  @override
  String get chatDescriptionOpenSettings => '打开设置';

  @override
  String get chatDescriptionPreviousAgent => '上一个代理';

  @override
  String get chatDescriptionProjectCommand => '项目命令';

  @override
  String get chatDescriptionQuickOpen => '快速打开文件';

  @override
  String get chatDescriptionRefreshData => '刷新聊天数据';

  @override
  String get chatDescriptionStopResponse => '停止当前响应（响应时）';

  @override
  String get chatDescriptionSwitchProject => '使用此按钮切换项目文件夹和上下文。';

  @override
  String get chatDescriptionVoiceInput => '开始或停止语音输入';

  @override
  String get chatDiffFiles => '差异文件：0';

  @override
  String get chatDisplay => '显示';

  @override
  String get chatDisplayToggles => '显示开关';

  @override
  String get chatDoubleESCStop => '双击ESC停止';

  @override
  String get chatEffortLockedSubConversation => '子对话中已锁定努力程度';

  @override
  String get chatExpandGroup => '展开分组';

  @override
  String get chatExportCanceled => '会话导出已取消';

  @override
  String get chatFailedToLoadDirectories => '加载目录失败';

  @override
  String get chatFailedToLoadFile => '加载文件失败';

  @override
  String get chatFailedToRefreshProviders => '刷新提供程序和模型失败';

  @override
  String get chatFailedToRefreshSubConversations => '刷新子对话失败，请重试。';

  @override
  String get chatFailedToStopResponse => '无法停止当前响应';

  @override
  String get chatFileExplorerContents => '内容';

  @override
  String get chatFileExplorerNames => '名称';

  @override
  String get chatFilterActive => '活跃';

  @override
  String get chatFilterAll => '全部';

  @override
  String get chatFilterArchived => '已归档';

  @override
  String get chatFilterDirectories => '过滤目录';

  @override
  String get chatFilterSessions => '筛选会话';

  @override
  String get chatForkFailed => '派生会话失败';

  @override
  String get chatForked => '已派生会话';

  @override
  String get chatGoToFirst => '转到第一条消息';

  @override
  String get chatGoToLatest => '转到最新消息';

  @override
  String chatGroupMessageCountMessages(
    String compactionLabel,
    String messageCount,
  ) {
    return '$compactionLabel压缩前隐藏了$messageCount条消息';
  }

  @override
  String get chatHelloAssistant => '你好！我是你的 AI 助手';

  @override
  String get chatHelp => '我能帮您做点什么？';

  @override
  String get chatHelpMessage => '使用 @ 提及，! 运行 shell，/ 运行命令';

  @override
  String get chatHideConversationsSidebar => '隐藏会话侧边栏';

  @override
  String get chatHideUtilitySidebar => '隐藏实用工具侧边栏';

  @override
  String get chatHistoryCollapsed => '先前的历史记录已折叠';

  @override
  String get chatHistoryHideEarlier => '隐藏较早的消息';

  @override
  String chatHistoryMessagesHidden(int count, String label) {
    return '在 $label 压缩前已隐藏 $count 条消息';
  }

  @override
  String get chatHistoryShowEarlier => '显示较早的消息';

  @override
  String get chatKeepWorking => '继续工作';

  @override
  String get chatLargeContentSkipped => '为了稳定性，已跳过超大或格式错误的内容。';

  @override
  String get chatLatestToolActivity => '最新的工具活动将保留在此受限面板内，以保持聊天视口稳定。';

  @override
  String get chatLoadMore => '加载更多';

  @override
  String get chatLoadingProjectContext => '正在加载项目上下文...';

  @override
  String get chatMainConversationUnavailable => '主对话尚不可用。';

  @override
  String get chatParentConversationUnavailable => '父会话尚不可用。';

  @override
  String get chatMentionAgentSubtitle => '智能体';

  @override
  String get chatMentionFileSubtitle => '文件';

  @override
  String get chatMentionSymbolSubtitle => '符号';

  @override
  String get chatMessageAttachedFile => '已附加文件';

  @override
  String get chatMessageDetails => '详情';

  @override
  String get chatMessageHide => '隐藏';

  @override
  String get chatMessageLess => '收起';

  @override
  String get chatMessageMessagePartUnavailable => '消息部分不可用';

  @override
  String get chatMessageMetadataAvailable => '无可用元数据';

  @override
  String chatMessageModelMessageModelId(String modelId) {
    return '模型: $modelId';
  }

  @override
  String get chatMessageMore => '更多';

  @override
  String get chatMessageOpenFile => '打开文件';

  @override
  String chatMessageProviderMessageProviderId(String providerId) {
    return '提供者: $providerId';
  }

  @override
  String get chatMessageRewindEdit => '从此处回退并编辑';

  @override
  String get chatMessageRunningTask => '正在运行的任务';

  @override
  String get chatMessageSaveFile => '保存文件';

  @override
  String get chatMessageShow => '显示';

  @override
  String get chatMessageShowQuestion => '查看问题';

  @override
  String get chatMessageShowLess => '显示较少';

  @override
  String get chatMessageShowLessCompact => '收起';

  @override
  String get chatMessageShowMore => '显示更多';

  @override
  String get chatMessageShowMoreCompact => '更多';

  @override
  String get chatMessageThinking => '思考中';

  @override
  String get chatMessageThinkingProcess => '思考过程';

  @override
  String get chatMessageToolCall => '1 次工具调用';

  @override
  String chatMessageToolCalls(int count) {
    return '$count 次工具调用';
  }

  @override
  String get chatMessageToolCommand => '命令';

  @override
  String get chatMessageToolCommandTruncated => '命令预览已截断以保持稳定性。';

  @override
  String get chatMessageToolDiffOmitted => '差异预览已省略：编辑负载过大，无法在移动端安全渲染。';

  @override
  String get chatMessageToolInput => '输入';

  @override
  String get chatMessageToolInputTruncated => '输入预览已截断以保持稳定性。';

  @override
  String get chatMessageToolOutputTruncated => '大型工具输出预览已截断以保持应用稳定性。';

  @override
  String chatMessageToolQueuedCount(int count) {
    return '$count 排队中';
  }

  @override
  String chatMessageToolRunningCount(int count) {
    return '$count 运行中';
  }

  @override
  String get chatMessageToolStatusInProgress => '进行中';

  @override
  String get chatMessageToolStatusNeedsAttention => '需要注意';

  @override
  String get chatMessageToolStatusQueued => '已排队';

  @override
  String get chatMessageYou => '您';

  @override
  String get chatModelLockedSubConversation => '模型在子对话中已锁定';

  @override
  String get chatNewChat => '新聊天';

  @override
  String get chatNewChatTourDescription => '在此处开始新会话。';

  @override
  String get chatNewChatTourTitle => '新聊天';

  @override
  String get chatNoConversationsInProject => '此项目中没有会话。';

  @override
  String get chatNoServerYet => '尚未配置服务器';

  @override
  String get chatNoSessionSelected => '选择或创建一个对话开始聊天';

  @override
  String get chatNoSubConversationFound => '未找到此任务的子对话。';

  @override
  String get chatOpenFiles => '打开的文件';

  @override
  String get chatOpenProject => '打开项目';

  @override
  String get chatOpenProjectFolder => '打开项目文件夹...';

  @override
  String get chatOpenProjectToLoad => '打开项目以加载会话。';

  @override
  String get chatOpenSidebar => '打开侧边栏';

  @override
  String get chatPageStatusAutomaticCompactionExplanation =>
      '随着上下文用量的增加，将自动进行压缩。';

  @override
  String get chatPageStatusCompactNow => '立即压缩';

  @override
  String get chatPageStatusCompacting => '正在压缩...';

  @override
  String get chatPageStatusCompactingContextNow => '正在压缩上下文...';

  @override
  String get chatPageStatusContextCompacted => '上下文已压缩';

  @override
  String get chatPageStatusContextUsage => '上下文使用';

  @override
  String get chatPageStatusCost => '费用';

  @override
  String get chatPageStatusFailedToCompactContext => '无法压缩上下文';

  @override
  String get chatPageStatusLimit => '限额';

  @override
  String get chatPageStatusManageServers => '管理服务器';

  @override
  String get chatPageStatusSaver => '节省';

  @override
  String get chatPageStatusServer => '服务器';

  @override
  String get chatPageStatusSwitchServer => '切换服务器';

  @override
  String get chatPageStatusTokens => '令牌';

  @override
  String get chatPageStatusUsage => '使用';

  @override
  String chatPageStatusUsagePercent(int usagePercent) {
    return '$usagePercent';
  }

  @override
  String get chatPermissionAutoApproveOff => '权限自动批准已关闭';

  @override
  String get chatPermissionAutoApproveOn => '权限自动批准已开启';

  @override
  String get chatProjectContext => '项目上下文';

  @override
  String get chatProjectContext2 => '项目上下文';

  @override
  String get chatRealtimeGlobalEvent => '全局事件';

  @override
  String chatRealtimeGlobalEventReason(String reason) {
    return '全局事件 ($reason)';
  }

  @override
  String get chatRealtimeGlobalEventStale => '全局事件 (过时代)';

  @override
  String chatRealtimeMessageStreamReason(String reason) {
    return '消息流 ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEvent => '实时事件';

  @override
  String chatRealtimeRealtimeEventReason(String reason) {
    return '实时事件 ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEventStale => '实时事件 (过时代)';

  @override
  String get chatRealtimeReconnectingServerTry => '正在重新连接服务器。请稍后重试。';

  @override
  String get chatReasoning => '推理中...';

  @override
  String get chatRecentSessions => '最近会话';

  @override
  String get chatRecentSessionsToggle => '最近会话';

  @override
  String get chatRedoLastTurn => '重做上一步';

  @override
  String get chatRedoNothing => '此会话中没有可重做的操作';

  @override
  String get chatRefresh => '刷新';

  @override
  String get chatRefreshConversation => '无法刷新此对话';

  @override
  String get chatRefreshProjects => '刷新项目';

  @override
  String get chatRefreshSessionDetails => '刷新会话详情';

  @override
  String chatRemoveDisplayNameHistory(String displayName) {
    return '从历史记录中移除$displayName';
  }

  @override
  String get chatRetry => '重试';

  @override
  String get chatRetry2 => '重试';

  @override
  String get chatRetryRefresh => '重试刷新';

  @override
  String get chatRetryingModelRequest => '正在重试模型请求...';

  @override
  String get chatReturnToMainConversation => '返回主会话';

  @override
  String get chatReturnToParentConversation => '返回父会话';

  @override
  String get chatReviewChanges => '审查更改';

  @override
  String get chatSearchConversations => '搜索会话';

  @override
  String get chatSearchNextResult => '下一个结果';

  @override
  String get chatSearchNoResults => '无结果';

  @override
  String get chatSearchPreviousResult => '上一个结果';

  @override
  String chatSearchResultCount(int current, int total) {
    return '第 $current 条消息，共 $total 条';
  }

  @override
  String get chatSearchTimeline => '搜索时间线';

  @override
  String get chatSelectDirectory => '选择目录';

  @override
  String get chatSelectOrCreate => '选择或创建一个会话以开始聊天';

  @override
  String get chatSelectProjectBelow => '在下方选择一个项目。';

  @override
  String get chatServerSelectedModel => '服务器选择的模型';

  @override
  String get chatSessionActions => '会话操作';

  @override
  String chatSessionChatSessionSession(String title) {
    return '聊天会话: $title';
  }

  @override
  String chatSessionConversationNextAction(String nextAction) {
    return '对话 $nextAction';
  }

  @override
  String get chatSessionConversations => '无对话';

  @override
  String get chatSessionCreateConversationStart => '创建一个新对话以开始聊天';

  @override
  String get chatSessionTabsToggle => '会话标签页';

  @override
  String chatSessionsLength(int length) {
    return '$length';
  }

  @override
  String get chatSetUpServer => '设置服务器';

  @override
  String get chatSettings => '设置';

  @override
  String get chatShortcutsCloseApp => '使用平台关闭行为关闭应用';

  @override
  String get chatShortcutsCycleModels => '轮换最近使用的模型';

  @override
  String get chatShortcutsCycleVariant => '轮换模型变体';

  @override
  String get chatShortcutsFocusInput => '聚焦消息输入';

  @override
  String get chatShortcutsFocusInputCloseDrawer => '聚焦输入（或在打开时关闭抽屉）';

  @override
  String get chatShortcutsForceExit => '强制退出应用';

  @override
  String get chatShortcutsNewConversation => '新对话';

  @override
  String get chatShortcutsNextAgent => '下一个智能体';

  @override
  String get chatShortcutsOpenSettings => '打开设置';

  @override
  String get chatShortcutsPreviousAgent => '上一个智能体';

  @override
  String get chatShortcutsQuickOpen => '快速打开文件';

  @override
  String get chatShortcutsRefreshChat => '刷新聊天数据';

  @override
  String get chatShortcutsStartStopVoice => '开始或停止语音输入';

  @override
  String get chatShortcutsStopResponse => '停止当前响应（正在响应时）';

  @override
  String get chatSidebarAccess => '侧边栏访问';

  @override
  String get chatSortMostRecent => '最新';

  @override
  String get chatSortOldest => '最早';

  @override
  String get chatSortRecent => '最近';

  @override
  String get chatSortSessions => '排序会话';

  @override
  String get chatSortTitle => '标题';

  @override
  String get chatStartVoiceInput => '开始语音输入';

  @override
  String get chatStartingVoiceInput => '正在启动语音输入';

  @override
  String get chatStatusBusy => '状态：忙碌';

  @override
  String get chatStatusPatching => '正在打补丁';

  @override
  String chatStatusPatchingMultipleFiles(int count) {
    return '正在为 $count 个文件打补丁';
  }

  @override
  String get chatStatusPatchingOneFile => '正在为 1 个文件打补丁';

  @override
  String get chatStatusRetry => '状态：重试';

  @override
  String chatStatusRetryCount(int count) {
    return '状态：重试 #$count';
  }

  @override
  String get chatStatusSubsession => '子会话';

  @override
  String get chatStatusThinking => '正在思考...';

  @override
  String get chatStopVoiceInput => '停止语音输入';

  @override
  String chatSyncLabel(String label) {
    return '同步: $label';
  }

  @override
  String get chatTasks => '任务';

  @override
  String get chatTasksAvailableSession => '此会话没有可用的任务。';

  @override
  String get chatTipAcceptanceCriteria => '提示：大型变更加入验收标准';

  @override
  String get chatTipAskForPlan => '提示：大任务先请求计划';

  @override
  String get chatTipBeSpecific => '提示：请具体一些 — 简短的提示词能获得更快的回答';

  @override
  String get chatTipBreakTasks => '提示：将大任务分解为更小的提示词';

  @override
  String get chatTipCompareOptions => '提示：权衡不清时请求替代方案';

  @override
  String get chatTipContextKnob => '提示：点击上下文旋钮查看使用详情';

  @override
  String get chatTipDefineVerification => '提示：说明哪些测试或检查必须通过';

  @override
  String get chatTipLongPressSend => '提示：长按发送键插入新行';

  @override
  String get chatTipMentionFiles => '提示：在提示词中使用 @ 来提及文件';

  @override
  String get chatTipNameRelevantFiles => '提示：说明相关文件、界面或命令';

  @override
  String get chatTipProvideContext => '提示：提供上下文 — 粘贴错误消息和日志';

  @override
  String get chatTipRenameConversation => '提示：点击标题重命名对话';

  @override
  String get chatTipRequestDocs => '提示：行为变化时请求更新文档';

  @override
  String get chatTipShareAttempts => '提示：分享已尝试的内容和准确错误';

  @override
  String get chatTipShellCommands => '提示：在开头使用 ! 来运行 shell 命令';

  @override
  String get chatTipSlashCommands => '提示：使用 / 访问斜杠命令';

  @override
  String get chatTipStartWithGoal => '提示：先说明最终目标';

  @override
  String get chatTipStateConstraints => '提示：说明代理必须保留的约束';

  @override
  String get chatTipStepByStep => '提示：在调试复杂问题时要求逐步进行';

  @override
  String get chatTipUseFocusedAgents => '提示：为计划、评审或构建选择专注代理';

  @override
  String get chatToggleSidebars => '切换侧边栏';

  @override
  String chatTokensLabel(int total) {
    return 'Token：$total';
  }

  @override
  String get chatTourProjectsConversations => '使用此按钮打开您的项目和对话。';

  @override
  String get chatTourSidebarProjectTools => '使用此菜单显示对话侧边栏和项目工具。';

  @override
  String get chatTourSwitchFolders => '使用此按钮切换项目文件夹和上下文。';

  @override
  String get chatUndoLastTurn => '撤销上一步';

  @override
  String get chatUndoNothing => '此会话中没有可撤销的操作';

  @override
  String get chatUseCurrent => '使用当前';

  @override
  String get chatWaitingForNetworkConnection => '等待网络连接...';

  @override
  String get chatWelcomeMessage => '您好！我是您的AI助手。';

  @override
  String get chatWelcomeSubmessage => '今天我能为您做些什么？';

  @override
  String get chatWorkBoundedPanelExplanation => '最新的工具活动将保持在此限定面板内，以保持聊天视口稳定。';

  @override
  String get chatWorkExpand => '展开';

  @override
  String get chatWorkHide => '隐藏';

  @override
  String get chatWorkMessageOne => '1 条工作消息';

  @override
  String chatWorkMessagesMultiple(int count) {
    return '$count 条工作消息';
  }

  @override
  String get chatWorkShow => '显示';

  @override
  String get commonCancel => '取消';

  @override
  String get commonCopiedToClipboard => '已复制到剪贴板';

  @override
  String get commonDelete => '删除';

  @override
  String get commonFile => '文件';

  @override
  String get commonReset => '重置';

  @override
  String get commonSave => '保存';

  @override
  String get compactionAutomatic => '自动';

  @override
  String get compactionManual => '手动';

  @override
  String get composerAddAttachment => '添加附件';

  @override
  String get composerAttachFiles => '附加文件';

  @override
  String get composerCannedAppendAtCursor => '在光标处追加';

  @override
  String get composerCannedLabel => '标签（可选）';

  @override
  String get composerCannedNoReplies => '暂无快速回复。';

  @override
  String get composerCannedReplace => '替换';

  @override
  String get composerCannedSave => '保存';

  @override
  String get composerCannedScopeGlobal => '全局';

  @override
  String get composerCannedScopeProject => '仅项目';

  @override
  String get composerCannedSendAutomatically => '自动发送';

  @override
  String get composerCannedText => '文本';

  @override
  String get composerChatInput => '聊天输入';

  @override
  String get composerDeleteAction => '删除';

  @override
  String get composerDropHint => '拖放图片或 PDF 以附加';

  @override
  String get composerPastedImageName => '粘贴的图片';

  @override
  String get composerEdit => '编辑';

  @override
  String get composerExtras => '附加功能';

  @override
  String get composerExtrasHide => '隐藏更多';

  @override
  String get composerNewQuickReply => '新建快速回复';

  @override
  String get composerSelectImages => '选择图片';

  @override
  String get composerSelectPdf => '选择 PDF';

  @override
  String get composerSend => '发送';

  @override
  String get composerShellMode => 'Shell 模式';

  @override
  String get desktopWindowClose => '关闭';

  @override
  String get desktopWindowMaximize => '最大化';

  @override
  String get desktopWindowMinimize => '最小化';

  @override
  String get desktopWindowRestore => '还原';

  @override
  String get dialogDownload => '下载';

  @override
  String get dialogLanguage => '语言';

  @override
  String get dialogMoonshineModelSize => '模型大小';

  @override
  String get dialogMoonshineVoiceSetup => 'Moonshine 语音设置';

  @override
  String get dialogParakeetModel => 'Parakeet 模型';

  @override
  String get dialogParakeetVoiceSetup => 'Parakeet 语音设置';

  @override
  String get dialogSenseVoiceModel => 'SenseVoice 模型';

  @override
  String get dialogSenseVoiceSetup => 'SenseVoice 设置';

  @override
  String get dialogVoiceInputSetup => '语音输入设置';

  @override
  String get errorAnErrorOccurred => '发生了一个错误';

  @override
  String get errorAuthRequired => '需要身份验证';

  @override
  String get errorAuthRequiredDesc => '身份验证失败。请重新连接提供商并重试。';

  @override
  String get errorConnectionFailed => '连接失败';

  @override
  String get errorConnectionFailedDesc => '无法连接到服务器。请检查网络连接和服务器状态。';

  @override
  String get errorFormatAuthenticationFailedReconnect => '身份验证失败。请重新连接提供商并重试。';

  @override
  String get errorFormatProviderTemporarilyUnavailable => '提供商暂时不可用。请稍后重试。';

  @override
  String get errorFormatQuotaExceededCheck => '用量配额已超。请检查您的提供商方案或账单。';

  @override
  String get errorFormatRateLimitExceeded => '已达到速率限制。请稍等片刻后重试。';

  @override
  String get errorFormatServerErrorPlease => '服务器错误。请重试。';

  @override
  String get errorFormatServiceTemporarilyUnavailable =>
      '服务暂时不可用。服务器可能正在启动，请稍后重试。';

  @override
  String get errorFormatUnableReachServer => '无法连接到服务器。请检查网络连接和服务器状态。';

  @override
  String get errorProviderUnavailable => '提供商不可用';

  @override
  String get errorProviderUnavailableDesc => '提供商暂时不可用。请稍后再试。';

  @override
  String get errorQuotaExceeded => '配额已超限';

  @override
  String get errorQuotaExceededDesc => '配额已超限。请检查您的提供商计划或账单。';

  @override
  String get errorRateLimitExceeded => '速率限制已超限';

  @override
  String get errorRateLimitExceededDesc => '速率限制已超限。请稍等片刻后重试。';

  @override
  String get errorServerError => '服务器错误';

  @override
  String get errorServerErrorDesc => '服务器错误。请重试。';

  @override
  String get errorServiceUnavailable => '服务不可用';

  @override
  String get errorServiceUnavailableDesc => '服务暂时不可用。服务器可能正在启动，请稍后再试。';

  @override
  String get fileActionAttachmentDataDecoded => '无法解码附件数据。';

  @override
  String get fileActionAttachmentPathEmpty => '附件路径为空。';

  @override
  String get fileActionAttachmentPayloadEmpty => '附件有效负载为空。';

  @override
  String get fileActionAttachmentProvideValid => '附件未提供有效位置。';

  @override
  String get fileActionAttachmentSavedDevice => '附件无法在此设备上保存。';

  @override
  String fileActionAttachmentSavedOutputFile(String path) {
    return '附件已保存到$path并打开。';
  }

  @override
  String fileActionAttachmentSavedOutputFile2(String path) {
    return '附件已保存到$path。';
  }

  @override
  String fileActionAttachmentSavedSavedPath(String savedPath) {
    return '附件已保存到$savedPath。';
  }

  @override
  String get fileActionLocalAttachmentFound => '在此设备上未找到本地附件。';

  @override
  String get fileActionSaveCanceled => '保存已取消。';

  @override
  String get fileActionUnableOpenLocal => '无法打开本地附件。';

  @override
  String get filesAddChat => '添加到聊天';

  @override
  String get filesAutosave => '自动保存';

  @override
  String get filesAutosaveOn => '自动保存已开启';

  @override
  String get filesAutosaveOff => '自动保存已关闭';

  @override
  String get filesRedo => '重做';

  @override
  String get filesUndo => '撤销';

  @override
  String get filesBinaryFilePreview => '二进制文件预览不可用。';

  @override
  String get filesClear => '清除';

  @override
  String get filesContents => '内容';

  @override
  String get filesDuplicate => '复制';

  @override
  String get filesDuplicated => '文件已复制';

  @override
  String get filesFileEmpty => '文件为空。';

  @override
  String get filesAlreadyExists => '已存在同名的文件或文件夹。';

  @override
  String get filesCopyPath => '复制路径';

  @override
  String get filesCreateFileTitle => '新建文件';

  @override
  String get filesCreateFolderTitle => '新建文件夹';

  @override
  String get filesDelete => '删除';

  @override
  String filesDeleteConfirm(String name) {
    return '确定删除 $name 吗？此操作无法撤消。文件夹及其内容将一并删除。';
  }

  @override
  String filesDeleteTitle(String name) {
    return '删除 $name';
  }

  @override
  String get filesFilesFound => '未找到文件';

  @override
  String get filesFileCreated => '文件已创建。';

  @override
  String get filesFolderCreated => '文件夹已创建。';

  @override
  String get filesHideSidebar => '隐藏文件侧边栏';

  @override
  String get filesInvalidName => '请输入不含路径分隔符的有效名称。';

  @override
  String get filesNameHint => '名称';

  @override
  String get filesNew => '新建';

  @override
  String get filesNewFile => '新建文件';

  @override
  String get filesNewFolder => '新建文件夹';

  @override
  String get filesNames => '名称';

  @override
  String filesOpenFilesFileState(int length) {
    return '打开的文件 ($length)';
  }

  @override
  String get filesQuickOpen => '快速打开';

  @override
  String get filesQuickOpenFile => '快速打开文件';

  @override
  String get filesOperationFailed => '文件操作失败。';

  @override
  String get filesOperationUnavailable => '此服务器不支持文件操作。';

  @override
  String get filesOutsideRoot => '该路径位于项目根目录之外。';

  @override
  String get filesPathCopied => '路径已复制。';

  @override
  String get filesPathMissing => '路径不存在。';

  @override
  String get filesPermissionDenied => '权限被拒绝。';

  @override
  String get filesRefresh => '刷新文件';

  @override
  String get filesRename => '重命名';

  @override
  String filesRenameTitle(String name) {
    return '重命名 $name';
  }

  @override
  String get filesRenamed => '已重命名。';

  @override
  String get filesRootDeleteBlocked => '无法删除项目根目录。';

  @override
  String get filesSearchHint => '按名称或路径搜索文件';

  @override
  String get filesDeleted => '已删除。';

  @override
  String get filesTitle => '文件';

  @override
  String get forwardAction => '转发';

  @override
  String get forwardAllFailed => '无法转发到任何会话';

  @override
  String get forwardCancel => '取消';

  @override
  String get forwardDialogSubtitle => '选择一个或多个对话';

  @override
  String get forwardDialogTitle => '转发到…';

  @override
  String get forwardLoading => '正在加载会话…';

  @override
  String get forwardNoOpenProjects => '没有包含会话的打开项目';

  @override
  String get forwardNoProviderModel => '转发前请先选择提供商和模型';

  @override
  String get forwardNoSessions => '没有最近的会话';

  @override
  String forwardPartial(int success, int total) {
    return '已转发到 $total 个会话中的 $success 个';
  }

  @override
  String forwardProvenanceLabel(String origin) {
    return '转发自：$origin';
  }

  @override
  String get forwardRetry => '重试';

  @override
  String get forwardSearchHint => '搜索';

  @override
  String forwardSelectedCount(int count) {
    return '已选择 $count 项';
  }

  @override
  String get forwardSend => '转发';

  @override
  String get forwardServerOffline => '服务器离线';

  @override
  String get forwardShortcutHint => 'Ctrl+Shift+F';

  @override
  String forwardSuccess(int count) {
    return '已转发到 $count 个会话';
  }

  @override
  String get forwardUndo => '撤销';

  @override
  String get forwardUndoFailed => '无法撤销转发';

  @override
  String get logsAppLogs => '应用日志';

  @override
  String get logsClear => '清除日志';

  @override
  String get logsCloseSearch => '关闭搜索';

  @override
  String get logsCopyFiltered => '复制已过滤的日志';

  @override
  String get logsEnableLogging => '启用应用日志';

  @override
  String get logsEnableLoggingAction => '启用日志';

  @override
  String get logsEnableLoggingDescription => '在内存中收集诊断日志。除非排查问题，否则保持关闭。';

  @override
  String get logsEntryContext => '上下文';

  @override
  String get logsEntryTags => '标签';

  @override
  String get logsFilterAll => '全部';

  @override
  String get logsFilterByTag => '标签';

  @override
  String get logsLevel => '级别';

  @override
  String get logsLoggingDisabledDescription =>
      'CodeWalk 未收集详细应用日志。仅在需要诊断时启用日志。';

  @override
  String get logsLoggingDisabledTitle => '日志已关闭';

  @override
  String get logsMeasurePerformance => '测量性能';

  @override
  String get logsMeasurePerformanceDescription => '捕获应用高开销操作的耗时。除非诊断卡顿，否则保持关闭。';

  @override
  String get logsNoLogsYet => '尚未捕获日志。';

  @override
  String get logsNoMatchingLogs => '没有符合当前过滤条件的日志。';

  @override
  String get logsNoPerformanceData => '没有符合当前筛选条件的性能日志。';

  @override
  String get logsNoTaskData => '没有符合当前筛选条件的任务。';

  @override
  String logsPerformanceDuration(int elapsedMs) {
    return '$elapsedMs 毫秒';
  }

  @override
  String get logsPerformanceFilter => '性能';

  @override
  String logsPerformanceTileTitle(
    int elapsedMs,
    String operation,
    String status,
  ) {
    return '性能 $operation | $elapsedMs 毫秒 | $status';
  }

  @override
  String get logsSearch => '搜索日志';

  @override
  String logsShowingOrderedLength(int length, int length2) {
    return '显示$length2条中的$length条';
  }

  @override
  String get logsSlowestPerformance => '最慢的性能日志';

  @override
  String get logsSlowestTasks => '最慢的任务';

  @override
  String get logsTagCustomHint => '标签名称（例如：task:select_session）';

  @override
  String get logsTagCustomAction => '自定义...';

  @override
  String logsTaskDuration(int elapsedMs, String operation) {
    return '$operation — $elapsedMs 毫秒';
  }

  @override
  String get logsTaskStatusCanceled => '已取消';

  @override
  String get logsTaskStatusError => '错误';

  @override
  String get logsTaskStatusOk => '正常';

  @override
  String get logsTimeRange => '时间范围';

  @override
  String get mathExpressionLabel => '数学';

  @override
  String get mermaidCopySourceTooltip => '复制源码';

  @override
  String get mermaidDiagramLabel => 'Mermaid 图表';

  @override
  String get modelAuto => '自动';

  @override
  String get modelChooseAgent => '选择智能体';

  @override
  String get modelFavorites => '收藏夹';

  @override
  String get modelFree => '免费';

  @override
  String get modelLabelBaseEnglish => '基础 (英语)';

  @override
  String get modelLabelParakeet => 'Parakeet V3 (25 种欧洲语言)';

  @override
  String get modelLabelSenseVoice => 'SenseVoice (zh/en/ja/ko/yue)';

  @override
  String get modelLabelTinyEnglish => 'Tiny (英语)';

  @override
  String get modelLoadingModels => '正在加载模型';

  @override
  String get modelModelsFound => '未找到模型';

  @override
  String get modelRetryModels => '重试加载模型';

  @override
  String get modelSearchHint => '搜索模型或提供商';

  @override
  String get msgBatterySettingsFailed => '无法打开 Android 电池优化设置。';

  @override
  String get msgBatterySettingsOpened =>
      'Android 电池设置已打开。请允许 CodeWalk 使用不受限制的电池。';

  @override
  String get msgClearUsernameNeedsConfigEdit => '清除 OpenCode 对话用户名仍需在应用外部编辑配置。';

  @override
  String get msgCommandCopied => '命令已复制';

  @override
  String get msgCopiedToClipboard => '已复制到剪贴板';

  @override
  String get msgEnterUsernameToSave => '输入用户名以保存自定义的 OpenCode 对话名称。';

  @override
  String get msgFailedToSendMessage => '发送消息失败。草稿已保留以供重试。';

  @override
  String get msgFailedToStartVoiceInput => '启动语音输入失败';

  @override
  String msgFilePathNotFound(String path) {
    return '未找到文件：$path';
  }

  @override
  String get msgFilteredLogsCopied => '已过滤的日志已复制到剪贴板';

  @override
  String get msgInfoAgent => '智能体';

  @override
  String get msgInfoCompaction => '压缩';

  @override
  String msgInfoCost(String cost) {
    return '费用: \$$cost';
  }

  @override
  String get msgInfoMessageInfo => '消息信息';

  @override
  String msgInfoModel(String modelId) {
    return '模型: $modelId';
  }

  @override
  String get msgInfoNoMetadata => '无可用元数据';

  @override
  String msgInfoPartDescriptionModel(String description, String model) {
    return '$description$model';
  }

  @override
  String get msgInfoPatch => '补丁';

  @override
  String msgInfoProvider(String providerId) {
    return '提供商: $providerId';
  }

  @override
  String get msgInfoRetry => '重试';

  @override
  String get msgInfoSnapshot => '快照';

  @override
  String msgInfoSubtaskPartAgent(String agent) {
    return '子任务 ($agent)';
  }

  @override
  String msgInfoTokens(int total) {
    return 'Token数: $total';
  }

  @override
  String get msgInfoUndoThisTurn => '撤销此轮';

  @override
  String get msgInfoView => '查看';

  @override
  String get msgNoSystemSoundsFound => '在此设备上未找到系统声音。';

  @override
  String get msgNoValidFilesSelected => '未选择有效的文件';

  @override
  String get msgSomeSelectedFilesNotAttached => '部分所选文件无法附加。';

  @override
  String get msgReadAloud => '朗读';

  @override
  String get msgReadAloudNotAvailable => '此设备上文字转语音不可用。';

  @override
  String get msgSetupDebugCopied => 'OpenCode 设置调试信息已复制到剪贴板';

  @override
  String get msgShareAsImage => '作为图片分享';

  @override
  String get msgShareAsImageFailed => '无法将消息作为图片分享。';

  @override
  String get msgShareAsImageSubject => 'CodeWalk 消息';

  @override
  String get msgShareAsImageTooTall => '消息太长，无法作为图片分享。';

  @override
  String get msgStopReadAloud => '停止朗读';

  @override
  String get msgSystemSoundPickerUnavailable => '此平台不支持系统声音选择器。';

  @override
  String get msgUpdatedButRefreshFailed => '已更新服务器设置，但无法刷新聊天提供商。';

  @override
  String get msgVoiceInputUnavailable => '此设备上语音输入不可用';

  @override
  String get notifAndroidBatteryOptimization => 'Android 电池优化';

  @override
  String get notifConversationUpdates => '对话更新';

  @override
  String get notifNotificationsArriveReopening =>
      '如果通知仅在重新打开应用时到达，请允许 CodeWalk 在此设备上无优化运行。';

  @override
  String get notifResponseRunningKeep => '当响应正在运行时，离开应用后短时间内保持实时状态激活。';

  @override
  String notifSelectedSoundLabel(String soundLabel) {
    return '已选择: $soundLabel';
  }

  @override
  String get notificationAgentFinished => '代理已完成当前响应。';

  @override
  String get notificationConversationUpdates => '会话更新';

  @override
  String get notificationOpenToClear => '打开此会话以清除相关通知。';

  @override
  String get notificationSession => '会话';

  @override
  String get notificationSoundLoadFailed => '无法加载 Android 系统声音';

  @override
  String get onboardingAIGeneratedTitles => 'AI 生成的标题';

  @override
  String get onboardingAddServerLater => '您稍后可以在 设置 > 服务器 中添加服务器。';

  @override
  String get onboardingAddedButHealthCheckFailed => '已添加服务器，但健康检查失败。它可能仍在启动中。';

  @override
  String get onboardingAlmostInstallOpenCode =>
      '您就快完成了。请先安装 OpenCode，然后将 CodeWalk 连接 to 服务器 URL。';

  @override
  String onboardingAppProviderLocalSetupLogsLength(int length, int length2) {
    return '$length行设置日志和$length2个设置事件可在单独的设置调试屏幕中查看。';
  }

  @override
  String get onboardingAuthenticate => '认证';

  @override
  String get onboardingAvailable => '可用';

  @override
  String get onboardingAvailableOnlyDesktop => '仅在桌面端（Linux/macOS/Windows）可用。';

  @override
  String get onboardingBasicAuthTip => '仅当您的 OpenCode 服务器受密码保护时才启用基本身份验证。';

  @override
  String get onboardingChooseAnotherPath => '选择其他路径';

  @override
  String get onboardingChooseHowToSetup => '选择如何设置您的服务器';

  @override
  String get onboardingClear => '清除';

  @override
  String get onboardingCloudflareAuthFailed => 'Cloudflare Access 身份验证失败。';

  @override
  String get onboardingCodeWalkAppOpenCode => 'CodeWalk 是应用，OpenCode 是它连接的引擎。';

  @override
  String get onboardingConnectRunningServer => '连接到正在运行的服务器';

  @override
  String get onboardingConnectionIssue => '连接问题';

  @override
  String get onboardingConnectionSaved => '服务器连接保存成功。';

  @override
  String get onboardingConnectionTips => '连接提示';

  @override
  String get onboardingConnectionUpdated => '服务器连接更新成功。';

  @override
  String get onboardingContinue => '继续';

  @override
  String get onboardingContinueServerURL => '继续前往服务器 URL';

  @override
  String get onboardingCopyLoginURL => '复制登录 URL';

  @override
  String get onboardingCouldNotVerify => '无法验证服务器连接。';

  @override
  String get onboardingDefaultURLEmulator => '默认 URL、模拟器回环、身份验证和调试帮助。';

  @override
  String onboardingDesktopOnlyDiagnose(String appName) {
    return '仅限桌面：$appName 可以为您诊断、安装和运行 OpenCode。';
  }

  @override
  String get onboardingDetailedSetupEvents => '已捕获详细的设置事件以进行排障。';

  @override
  String get onboardingDonShowAgain => '不再显示';

  @override
  String get onboardingDone => '完成';

  @override
  String get onboardingEditServer => '编辑服务器';

  @override
  String get onboardingEditServerConnection => '编辑服务器连接';

  @override
  String get onboardingEmulatorRemap =>
      '在 Android 模拟器上，localhost 和 127.0.0.1 会自动映射到 10.0.2.2。';

  @override
  String get onboardingEnterServerUrl => '输入服务器 URL';

  @override
  String get onboardingExisting => '使用现有';

  @override
  String get onboardingExplainInstallOpenCode =>
      '解释如何安装 OpenCode、启动服务器，然后从 CodeWalk 连接。';

  @override
  String get onboardingFailed => '失败';

  @override
  String get onboardingGoodOptionDesktop => '桌面端不错的首选';

  @override
  String get onboardingHealthCheckFailedMayBeStarting => '服务器健康检查失败。它可能仍在启动中。';

  @override
  String get onboardingInstallBinary => '安装二进制文件';

  @override
  String get onboardingInstallBun => '通过 Bun 安装';

  @override
  String get onboardingInstallBunOpenCode => '安装 Bun + OpenCode';

  @override
  String get onboardingInstallNpm => '通过 npm 安装';

  @override
  String get onboardingInstallRunOpenCode => '在桌面端直接从 CodeWalk 安装并运行 OpenCode。';

  @override
  String get onboardingInvalidUrl => '无效的 URL';

  @override
  String get onboardingLabel => '标签（可选）';

  @override
  String get onboardingLabelHint => '我的服务器';

  @override
  String onboardingLatestOutputAppProvider(String localServerLastOutput) {
    return '最新输出: $localServerLastOutput';
  }

  @override
  String get onboardingLetCodeWalkSet => '让 CodeWalk 在本地进行设置';

  @override
  String get onboardingLocalServerSetup => '本地服务器设置';

  @override
  String get onboardingManagedLocalServer => '托管的本地服务器';

  @override
  String get onboardingManagedLocalServer2 =>
      '托管本地服务器模式仅在桌面构建版本（Linux/macOS/Windows）上可用。';

  @override
  String onboardingNeedsOpenCodeServer(String appName) {
    return '$appName 需要一个 OpenCode 服务器才能为您提供代码帮助。';
  }

  @override
  String get onboardingNotAvailable => '不可用';

  @override
  String get onboardingNotWritable => '不可写';

  @override
  String get onboardingOpenCode => '什么是 OpenCode？';

  @override
  String get onboardingOpenCodeRunningDevice => '我已经在此设备或网络中的其他地方运行了 OpenCode。';

  @override
  String get onboardingOpenCodeRunsLocally =>
      'OpenCode 在本地或服务器上运行，并为 CodeWalk 内部的 AI 编程功能提供支持。如果 OpenCode 已经运行，请连接到它。如果未运行，请选择以下引导设置路径之一。';

  @override
  String get onboardingOpenTailscaleLogin => '无法打开 Tailscale 登录 URL。';

  @override
  String get onboardingPassword => '密码';

  @override
  String get onboardingPasswordRequired => '输入密码';

  @override
  String get onboardingPickSetupPath => '选择与您当前的 OpenCode 设置匹配的设置路径。';

  @override
  String get onboardingPreconditionDirectoryNotWritable => '安装目录不可写。请检查用户权限。';

  @override
  String get onboardingPreconditionInstallViaBunRecommendation =>
      'OpenCode 维护者推荐通过 Bun 安装。';

  @override
  String get onboardingPreconditionNetworkFailed =>
      '网络访问失败。在安装 OpenCode 之前，请检查网络连接。';

  @override
  String get onboardingPreconditionNoRuntimeDetected =>
      '未检测到运行环境。请直接安装 OpenCode 二进制文件，或者先引导安装 Bun。';

  @override
  String get onboardingPreconditionNodeNpmAvailable =>
      'Node + npm 可用。通过 npm 安装 OpenCode，或者安装 Bun 以使用推荐流程。';

  @override
  String get onboardingPreconditionOpenCodeAlreadyAvailable =>
      'OpenCode 已可用。您可以立即使用检测到的命令。';

  @override
  String get onboardingPreconditionWindowsPathLagHint =>
      ' 在 Windows 上，安装后请重新检查，因为已打开的应用中 PATH 变量 of 更新可能会有延迟。';

  @override
  String get onboardingPreconditionWindowsWslRecommendation =>
      '检测到 Windows 版本。OpenCode 文档推荐使用 WSL，但也可以使用 npm install 作为备用方案。';

  @override
  String get onboardingReachable => '可达';

  @override
  String get onboardingReady => '就绪';

  @override
  String get onboardingRecommendedOrderTry =>
      '推荐顺序：如果您希望 CodeWalk 为您引导一切，请尝试“安装 Bun + OpenCode”。如果已安装 OpenCode，请使用“使用现有”。';

  @override
  String get onboardingRefreshChecks => '刷新检查';

  @override
  String get onboardingRunDiagnosticsToVerify => '运行诊断以验证本地 OpenCode 要求。';

  @override
  String get onboardingSaveAndTest => '保存并测试';

  @override
  String get onboardingServerConnectedReady => '您的服务器已连接并可以使用。';

  @override
  String get onboardingServerConnection => '服务器连接';

  @override
  String get onboardingServerSettingsSaved => '您的服务器设置已保存，健康检查已刷新。';

  @override
  String get onboardingServerSetup => '服务器设置';

  @override
  String get onboardingServerUpdated => '服务器已更新';

  @override
  String get onboardingServerUrl => '服务器 URL';

  @override
  String get onboardingSetup => '设置';

  @override
  String get onboardingSetupWizard => '设置向导';

  @override
  String get onboardingShowSetupSteps => '向我显示设置步骤';

  @override
  String get onboardingShowSetupSteps2 => '显示设置步骤';

  @override
  String get onboardingSkip => '暂时跳过';

  @override
  String get onboardingSkipSetup => '跳过设置？';

  @override
  String get onboardingStart => '开始';

  @override
  String onboardingStartUsing(String appName) {
    return '开始使用 $appName';
  }

  @override
  String get onboardingStarting => '正在启动';

  @override
  String get onboardingStop => '停止';

  @override
  String get onboardingStopped => '已停止';

  @override
  String get onboardingStopping => '正在停止';

  @override
  String onboardingSuggestedUrl(String url) {
    return '建议的本地 OpenCode 服务器 URL：$url';
  }

  @override
  String get onboardingTailscaleAdminApproval => '需要 Tailscale 管理员批准';

  @override
  String get onboardingTailscaleAuthAfterSave => '保存后将进行 Tailscale 身份验证';

  @override
  String onboardingTailscaleAuthAfterSaveTest(String appName) {
    return '在您保存并测试此服务器后，如果此设备尚未通过身份验证，$appName 将打开 Tailscale 登录页面。';
  }

  @override
  String get onboardingTailscaleConnected => 'Tailscale 已连接';

  @override
  String get onboardingTailscaleConnecting => 'Tailscale 正在连接';

  @override
  String get onboardingTailscaleConnectionFailed => 'Tailscale 连接失败';

  @override
  String get onboardingTailscaleLoginRequired => '需要登录 Tailscale';

  @override
  String get onboardingTailscaleOpenLoginUrl =>
      '打开登录 URL 将此设备添加到您的 tailnet。如果浏览器未打开，请复制下面的 URL。';

  @override
  String get onboardingTailscaleUnsupported => '不支持 Tailscale';

  @override
  String get onboardingTestConnection => '测试连接';

  @override
  String get onboardingTesting => '正在测试...';

  @override
  String get onboardingUnreachable => '不可达';

  @override
  String get onboardingUseBasicAuth => '使用基本身份验证';

  @override
  String get onboardingUsername => '用户名';

  @override
  String get onboardingUsernameRequired => '输入用户名';

  @override
  String get onboardingUsesServerTitle => '使用您服务器的标题智能体为会话命名';

  @override
  String get onboardingUsingDetectedCommand => '使用检测到的 OpenCode 命令。';

  @override
  String get onboardingViewSetupDebug => '查看设置调试';

  @override
  String onboardingWelcomeTo(String appName) {
    return '欢迎使用 $appName';
  }

  @override
  String get onboardingWindowsTipInstalling =>
      'Windows 提示：安装后，单击“刷新检查”。如果检测仍然失败，请重新打开 CodeWalk 以重新加载 PATH 更改。';

  @override
  String get onboardingWritable => '可写';

  @override
  String get onboardingYoureAllSet => '一切就绪！';

  @override
  String get permissionAllowOnce => '仅允许一次';

  @override
  String get permissionAlways => '总是允许';

  @override
  String get permissionBack => '返回';

  @override
  String get permissionConfirmReject => '确认拒绝';

  @override
  String get permissionReject => '拒绝';

  @override
  String get permissionReopen => '重新打开';

  @override
  String get questionAnswerSelected => '未选择答案。';

  @override
  String get questionCommaSeparatedValues => '逗号分隔值';

  @override
  String get questionQuestionGroupMarked =>
      '问题组已被标记为拒绝。在确认之前，您可以继续聊天并随时重新打开此组。';

  @override
  String get questionQuestionRequest => '问题请求';

  @override
  String get questionQuestionsProvidedSubmit => '未提供问题。您可以提交空响应。';

  @override
  String get questionReviewAnswersSubmitting => '在提交前核对您的答案。';

  @override
  String get quotaAuthCookie => '认证 Cookie';

  @override
  String get quotaConnect => '连接';

  @override
  String get quotaForget => '忘记';

  @override
  String get quotaOpenCodeGoConnectDescription => '连接用量仪表板以显示滚动、每周和每月限制。';

  @override
  String get quotaOpenCodeGoDetected => '已检测到 OpenCode Go';

  @override
  String get quotaOpenCodeGoNeedsReconnect => 'OpenCode Go 需要重新连接';

  @override
  String get quotaOpenCodeGoReconnectDescription => '刷新仪表板凭据以恢复用量条。';

  @override
  String get quotaOpenCodeGoUsage => 'OpenCode Go 用量';

  @override
  String get quotaOpenDashboard => '打开 OpenCode 仪表板';

  @override
  String get quotaPaceExplanation => '节奏会根据当前速率预测当前限制窗口结束时的总用量。';

  @override
  String quotaPacePercent(String percent) {
    return '节奏 $percent%';
  }

  @override
  String get quotaRateLimits => '用量限制';

  @override
  String get quotaReconnect => '重新连接';

  @override
  String get quotaRefreshing => '正在刷新...';

  @override
  String quotaResetsIn(String time) {
    return '将在 $time 后重置';
  }

  @override
  String get quotaSaving => '正在保存...';

  @override
  String get quotaWorkspaceId => '工作区 ID';

  @override
  String get serverClearOAuth => '清除 OAuth';

  @override
  String get serverConnectionAttention => '服务器连接需要注意。';

  @override
  String get serverHealthHealthy => '正常';

  @override
  String get serverHealthUnhealthy => '异常';

  @override
  String get serverHealthUnknown => '未知';

  @override
  String get serverOAuthAuthFailed => 'OAuth 身份验证失败';

  @override
  String get serverOAuthChip => 'OAuth';

  @override
  String get serverOAuthNotSupported => '此平台不支持 Cloudflare Access OAuth';

  @override
  String get serverReauthenticate => '重新进行身份验证';

  @override
  String get serverTailscaleChip => 'Tailscale';

  @override
  String get serversActive => '活动';

  @override
  String get serversActiveServer => '活动服务器';

  @override
  String get serversAddLeastOpenCode => '添加至少一个 OpenCode 服务器以开始使用该应用。';

  @override
  String get serversAddServer => '添加服务器';

  @override
  String get serversCancel => '取消';

  @override
  String get serversCannotActivateUnhealthy => '无法激活不健康的服务器';

  @override
  String get serversCheckHealth => '检查运行状况';

  @override
  String get serversClearDefault => '清除默认值';

  @override
  String serversCommandAppProviderLocalServerCommandPath(
    String localServerCommandPath,
  ) {
    return '命令: $localServerCommandPath';
  }

  @override
  String get serversCopy => '复制';

  @override
  String get serversDefault => '默认';

  @override
  String get serversDelete => '删除';

  @override
  String get serversDeleteServer => '删除服务器';

  @override
  String get serversDesktopModeExplanation =>
      '桌面模式可以直接从 CodeWalk 启动和管理 `opencode serve`。';

  @override
  String get serversEdit => '编辑';

  @override
  String get serversLocalOpenCodeServer => '本地 OpenCode 服务器';

  @override
  String get serversManagedModeAvailable =>
      '此托管模式仅在桌面构建版本（Linux/macOS/Windows）上可用。';

  @override
  String get serversNoServersFound => '未找到服务器';

  @override
  String get serversRefreshHealth => '刷新运行状况';

  @override
  String serversRemoveProfileDisplayName(String displayName) {
    return '删除\"$displayName\"？';
  }

  @override
  String get serversSearchActiveHint => '搜索活动服务器';

  @override
  String get serversServersConfigured => '未配置服务器';

  @override
  String get serversSetActive => '设为活动';

  @override
  String get serversSetDefault => '设为默认';

  @override
  String get serversSetupDebug => '设置调试';

  @override
  String get serversSetupWizard => '设置向导';

  @override
  String get serversTailscaleAdminApprovalRequired => '需要 Tailscale 管理员批准';

  @override
  String get serversTailscaleAuthRequired => '需要 Tailscale 身份验证';

  @override
  String get serversTailscaleConnectExplanation => '使用此活动配置文件时，Tailscale 将连接。';

  @override
  String get serversTailscaleConnected => 'Tailscale 已连接';

  @override
  String get serversTailscaleConnecting => 'Tailscale 正在连接';

  @override
  String get serversTailscaleConnectionFailed => 'Tailscale 连接失败';

  @override
  String get serversTailscaleDisconnected => 'Tailscale 已断开';

  @override
  String get serversTailscaleLoginExplanation =>
      '打开 Tailscale 登录 URL 将此设备添加到您的 tailnet。';

  @override
  String get serversTailscaleTrafficExplanation =>
      '此活动配置文件的 OpenCode 流量通过 Tailscale 路由。';

  @override
  String get serversTailscaleUnsupported => '不支持 Tailscale';

  @override
  String get serversUnhealthyActivateError => '此服务器不健康。请在激活前检查运行状况或编辑设置。';

  @override
  String get sessionActionArchived => '已归档';

  @override
  String get sessionActionDeleted => '已删除';

  @override
  String get sessionActionForked => '已派生';

  @override
  String get sessionActionPinned => '已置顶';

  @override
  String get sessionActionUnarchived => '已取消归档';

  @override
  String get sessionActionUnpinned => '已取消置顶';

  @override
  String get sessionArchive => '归档';

  @override
  String get sessionCancelRename => '取消重命名';

  @override
  String sessionChildrenCount(int count) {
    return '子对话：$count';
  }

  @override
  String get sessionCompactContext => '压缩上下文';

  @override
  String get sessionCopyLink => '复制共享链接';

  @override
  String get sessionDelete => '删除';

  @override
  String sessionDeleteConfirm(String title) {
    return '确定要删除对话“$title”吗？此操作无法撤消。';
  }

  @override
  String get sessionDeleteTitle => '删除对话';

  @override
  String get sessionDiffChangedFile => '已更改的文件';

  @override
  String get sessionDiffContentNotCaptured => '服务器未捕获文件内容';

  @override
  String sessionDiffFilesChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个文件已更改',
      one: '1 个文件已更改',
    );
    return '$_temp0';
  }

  @override
  String sessionDiffFilesCount(int count) {
    return '差异文件：$count';
  }

  @override
  String sessionDiffLinesAddedRemoved(int added, int removed) {
    return '新增 +$added 行，删除 -$removed 行';
  }

  @override
  String sessionDiffLinesCollapsed(int count) {
    return '已折叠 $count 行 — 点击以展开';
  }

  @override
  String get sessionDiffLoading => '正在加载更改的文件…';

  @override
  String get sessionDiffReview => '审查更改';

  @override
  String get sessionDiffSplit => '分栏';

  @override
  String get sessionDiffSummary => '摘要';

  @override
  String get sessionDiffUnified => '统一';

  @override
  String get sessionExportAssistant => '助手';

  @override
  String get sessionExportCanceled => '会话导出已取消';

  @override
  String get sessionExportDebugJson => '导出调试JSON';

  @override
  String get sessionExportDebugJsonErrorClipboard => '无法保存文件；调试JSON已复制到剪贴板';

  @override
  String get sessionExportDebugJsonSaved => '调试JSON导出已保存';

  @override
  String get sessionExportDebugJsonTitle => '将会话导出为调试JSON';

  @override
  String get sessionExportError => '错误：';

  @override
  String get sessionExportInput => '输入：';

  @override
  String get sessionExportMarkdown => '导出Markdown';

  @override
  String get sessionExportMarkdownErrorClipboard => '无法保存文件；Markdown已复制到剪贴板';

  @override
  String get sessionExportMarkdownSaved => 'Markdown导出已保存';

  @override
  String get sessionExportMarkdownTitle => '将会话导出为Markdown';

  @override
  String get sessionExportOutput => '输出：';

  @override
  String get sessionExportUntitled => '无标题会话';

  @override
  String get sessionExportUser => '用户';

  @override
  String get sessionFailedRename => '重命名对话失败';

  @override
  String get sessionFailedUpdateArchive => '更新归档状态失败';

  @override
  String get sessionFailedUpdateSharing => '更新共享状态失败';

  @override
  String get sessionFork => '派生';

  @override
  String get sessionForkFailed => '复制对话失败';

  @override
  String get sessionForked => '对话已复制';

  @override
  String sessionHasError(String title) {
    return '“$title”有错误。';
  }

  @override
  String sessionHasNewReply(String title) {
    return '“$title”有新的回复。';
  }

  @override
  String get sessionKeyboardShortcuts => '键盘快捷键';

  @override
  String sessionNeedsInput(String title) {
    return '“$title”需要您的输入。';
  }

  @override
  String get sessionNoCachedConversations => '暂无缓存的对话';

  @override
  String get sessionNoConversationsInProject => '此项目中没有对话。';

  @override
  String get sessionNotAvailable => '此项目暂不可用该对话';

  @override
  String get sessionOpenProjectToLoad => '打开项目以加载对话。';

  @override
  String get sessionPin => '固定';

  @override
  String get sessionRename => '重命名';

  @override
  String get sessionRenameHint => '输入新的对话名称';

  @override
  String get sessionRenameTitle => '重命名对话';

  @override
  String get sessionSaveTitle => '保存标题';

  @override
  String get sessionShare => '共享会话';

  @override
  String get sessionShareAction => '分享';

  @override
  String get sessionShareLinkCopied => '共享链接已复制';

  @override
  String get sessionShareLinkUnavailable => '此会话的共享链接不可用';

  @override
  String get sessionShared => '对话已共享';

  @override
  String get sessionSyncing => '正在同步对话...';

  @override
  String get sessionTitleHint => '对话标题';

  @override
  String get sessionUnarchive => '取消归档';

  @override
  String get sessionUnpin => '取消固定';

  @override
  String get sessionUnshare => '取消共享会话';

  @override
  String get sessionUnshareAction => '取消分享';

  @override
  String get sessionUnshared => '对话已取消共享';

  @override
  String get sessionViewTasks => '查看任务';

  @override
  String get settingsAboutCheckForUpdates => '检查更新';

  @override
  String get settingsAboutCheckOnOpen => '打开时检查更新';

  @override
  String get settingsAboutCheckOnOpenDescription => '应用启动时自动检查';

  @override
  String get settingsAboutChecking => '正在检查...';

  @override
  String get settingsAboutDescription => '版本、更新、帮助和应用数据';

  @override
  String get settingsAboutDismiss => '忽略';

  @override
  String settingsAboutDownloading(String percent) {
    return '正在下载... $percent%';
  }

  @override
  String get settingsAboutEraseAllData => '清除所有数据并重启';

  @override
  String get settingsAboutInstallUpdate => '安装更新';

  @override
  String get settingsAboutInstalling => '正在安装...';

  @override
  String settingsAboutLatestVersion(String version) {
    return 'v$version 是最新版本';
  }

  @override
  String get settingsAboutLoading => '加载中...';

  @override
  String get settingsAboutReplayChatTour => '重放聊天向导';

  @override
  String get settingsAboutReplayChatTourDescription => '关闭设置并显示向导聊天演示';

  @override
  String get settingsAboutResetApp => '重置应用';

  @override
  String get settingsAboutResetAppQuestion => '重置应用？';

  @override
  String get settingsAboutResetAppWarning => '这将清除所有服务器、设置和缓存的数据。此操作无法撤销。';

  @override
  String get settingsAboutRetryInstall => '重试安装';

  @override
  String get settingsAboutTapToCheck => '点击以检查新版本';

  @override
  String get settingsAboutTitle => '关于';

  @override
  String get settingsAboutUpToDate => '已是最新版本';

  @override
  String settingsAboutUpdateAvailable(String version) {
    return '有可用更新: v$version';
  }

  @override
  String get settingsAboutUpdateInstalled => '更新已安装。重启应用以应用更改。';

  @override
  String settingsAboutUpdateVersionSummary(
    String installedVersion,
    String latestVersion,
  ) {
    return '当前: $installedVersion; 可用: v$latestVersion';
  }

  @override
  String get settingsAboutVersion => '版本';

  @override
  String settingsAboutVersionBuild(String buildNumber, String version) {
    return '$version (构建号 $buildNumber)';
  }

  @override
  String get settingsAppearanceAmoledDark => 'AMOLED 深色模式';

  @override
  String get settingsAppearanceAmoledDarkActive => '在深色模式处于活动状态时使用纯黑表面。';

  @override
  String get settingsAppearanceAmoledDarkInactive => '切换到深色模式以启用 AMOLED 表面。';

  @override
  String get settingsAppearanceBrandColor => '品牌颜色';

  @override
  String get settingsAppearanceBrandColorDynamicBlocked => '禁用壁纸颜色以选择品牌颜色。';

  @override
  String get settingsAppearanceBrandColorNormal => '为应用调色板选择种子颜色。';

  @override
  String get settingsAppearanceBrandColorPresetBlocked =>
      '切换到 CodeWalk 经典以选择品牌颜色。';

  @override
  String get settingsAppearanceChatFontScale => '对话文字大小';

  @override
  String get settingsAppearanceChatFontScaleDescription =>
      '在系统文字大小之上缩放聊天消息和输入框文字。';

  @override
  String get settingsAppearanceCodeWalkClassic => 'CodeWalk 经典';

  @override
  String get settingsAppearanceComposerTips => 'Composer 提示';

  @override
  String get settingsAppearanceComposerTipsDescription => '在助手进行推理时显示或隐藏循环提示。';

  @override
  String get settingsAppearanceContrast => '对比度';

  @override
  String get settingsAppearanceContrastDynamicBlocked => '禁用壁纸颜色以调节对比度。';

  @override
  String get settingsAppearanceContrastHigh => '较高';

  @override
  String get settingsAppearanceContrastNormal => '调节配色方案的对比度级别。';

  @override
  String get settingsAppearanceContrastPresetBlocked =>
      '切换到 CodeWalk 经典以调节对比度。';

  @override
  String get settingsAppearanceContrastReduced => '较低';

  @override
  String get settingsAppearanceDark => '深色';

  @override
  String get settingsAppearanceDensity => '密度';

  @override
  String get settingsAppearanceDensityDense => '高密度';

  @override
  String get settingsAppearanceDensityDescription => '在整个应用中应用间距和组件密度。';

  @override
  String get settingsAppearanceDensityExtraDense => '极高密度';

  @override
  String get settingsAppearanceDensityExtraSpacious => '极宽松';

  @override
  String get settingsAppearanceDensityNormal => '标准';

  @override
  String get settingsAppearanceDensitySpacious => '宽松';

  @override
  String get settingsAppearanceDescription => '选择主题、颜色、文字大小和聊天显示方式';

  @override
  String get settingsAppearanceFontSize => '文字大小';

  @override
  String get settingsAppearanceFontSizeDescription => '调整系统文字、对话文字和终端文字的大小。';

  @override
  String get settingsAppearanceLight => '浅色';

  @override
  String get settingsAppearanceMathRendering => '数学公式渲染';

  @override
  String get settingsAppearanceMathRenderingDescription =>
      '在聊天消息中将 LaTeX 数学表达式渲染为排版公式。';

  @override
  String get settingsAppearanceNoPresets => '未找到预设调色板';

  @override
  String get settingsAppearanceOpenCodePresets => 'OpenCode 预设';

  @override
  String get settingsAppearancePresetHelper => '镜像官方 OpenCode Web 内置主题列表。';

  @override
  String get settingsAppearancePresetNote =>
      '主题颜色现在遵循官方 OpenCode Web 注册表，并同时驱动 markdown/代码表面。';

  @override
  String get settingsAppearancePresetPalette => '预设调色板';

  @override
  String get settingsAppearanceSearchPreset => '搜索预设调色板';

  @override
  String get settingsAppearanceSectionDescription => '调整工作流的视觉密度 and 消息表面。';

  @override
  String get settingsAppearanceSectionTitle => '外观';

  @override
  String get settingsAppearanceSystem => '系统';

  @override
  String get settingsAppearanceSystemFontScale => '系统文字大小';

  @override
  String get settingsAppearanceSystemFontScaleDescription =>
      '缩放应用外壳中的所有文字，包括菜单、对话框和侧边栏。';

  @override
  String get settingsAppearanceTaskList => '任务列表';

  @override
  String get settingsAppearanceTaskListDescription => '显示或隐藏会话任务列表小部件。';

  @override
  String get settingsAppearanceTerminalFontSize => '终端文字大小';

  @override
  String get settingsAppearanceTerminalFontSizeDescription =>
      '调整嵌入式终端字体大小。立即应用于正在运行的会话。';

  @override
  String get settingsAppearanceTheme => '主题';

  @override
  String get settingsAppearanceThemeDescription =>
      '选择浅色、深色或系统模式，然后保留 CodeWalk 经典调色板或切换到 OpenCode 预设。';

  @override
  String get settingsAppearanceVisualStyle => '视觉样式';

  @override
  String get settingsAppearanceVisualStyleDescription => '选择经典外观，或更柔和的精致界面。';

  @override
  String get settingsAppearanceVisualStyleClassic => '经典';

  @override
  String get settingsAppearanceVisualStyleRefined => '精致';

  @override
  String get settingsAppearanceThinkingBubbles => '思考气泡';

  @override
  String get settingsAppearanceThinkingBubblesDescription => '在助手消息中显示或隐藏推理块。';

  @override
  String get settingsAppearanceTitle => '外观';

  @override
  String get settingsAppearanceToolCallBubbles => '工具调用气泡';

  @override
  String get settingsAppearanceToolCallBubblesDescription =>
      '在助手消息中显示或隐藏工具执行卡片。';

  @override
  String get settingsAppearanceWallpaperColors => '使用壁纸颜色';

  @override
  String get settingsAppearanceWallpaperNormal => '从您的设备壁纸中提取配色方案。';

  @override
  String get settingsAppearanceWallpaperPresetBlocked =>
      '切换到 CodeWalk 经典以使用壁纸颜色。';

  @override
  String get settingsAppearanceWindowChrome => '窗口标签页';

  @override
  String get settingsAppearanceWindowChromeDescription =>
      '选择桌面端会话标签页与标题栏的组合方式。';

  @override
  String get settingsAppearanceWindowChromeIntegrated => '集成标签页';

  @override
  String get settingsAppearanceWindowChromeIntegratedDescription =>
      '标签页位于窗口顶部，系统标题栏被隐藏。';

  @override
  String get settingsAppearanceWindowChromeSystem => '系统装饰';

  @override
  String get settingsAppearanceWindowChromeSystemDescription =>
      '保留原生标题栏，并在应用栏下方显示标签页。';

  @override
  String get settingsBack => '返回';

  @override
  String get settingsBehaviorAutoupdateCaveat =>
      '使用“关于”来进行 CodeWalk 版本检查。此设置仅镜像了官方 OpenCode 的 `autoupdate` 配置。';

  @override
  String get settingsBehaviorAutoupdateHelp =>
      '控制上游 OpenCode 运行时更新，而不是 CodeWalk 应用的更新检查。';

  @override
  String get settingsBehaviorCellularDataSaver => '蜂窝数据节省程序';

  @override
  String get settingsBehaviorChatRenderMode => '聊天渲染模式';

  @override
  String get settingsBehaviorChatRenderModeBlock => '块模式';

  @override
  String get settingsBehaviorChatRenderModeBlockDescription =>
      '在当前回合能以单个块显示之前，隐藏实时助手文本、推理内容和工具卡片。';

  @override
  String get settingsBehaviorChatRenderModeDescription =>
      '选择助手回复是流式显示，还是在当前回合结束后显示。';

  @override
  String get settingsBehaviorChatRenderModeLive => '实时';

  @override
  String get settingsBehaviorChatRenderModeLiveDescription =>
      '在 OpenCode 流式传输事件时显示助手文本、推理和工具活动。';

  @override
  String get settingsBehaviorComposerSpellCheck => '输入框拼写检查';

  @override
  String get settingsBehaviorComposerSpellCheckDescription =>
      '在聊天输入框中使用平台原生拼写检查、建议和自动更正。';

  @override
  String get settingsBehaviorConfigDeferred =>
      'CodeWalk 将在当前响应结束后应用此 OpenCode 设置。';

  @override
  String settingsBehaviorConfigUpdateFailed(String field) {
    return '无法更新 OpenCode $field。';
  }

  @override
  String get settingsBehaviorConversationUsername => '会话用户名';

  @override
  String get settingsBehaviorConversationUsernameHelp =>
      '会话中显示的自定义显示名称，而不是系统用户名。';

  @override
  String get settingsBehaviorDataSaverActive => '当前已在移动数据上激活。';

  @override
  String get settingsBehaviorDataSaverCellularOnly => '仅在连接为蜂窝/移动网络时适用。';

  @override
  String get settingsBehaviorDataSaverDescription =>
      '通过停止后台下载并限制前台自动刷新，减少自动移动数据的使用。';

  @override
  String get settingsBehaviorDataSaverWaiting => '正在等待下一个移动数据同步窗口。';

  @override
  String get settingsBehaviorDefaultAgent => '默认 agent';

  @override
  String get settingsBehaviorDefaultAgentHelp => '在未明确选择 agent 时使用的主要 agent。';

  @override
  String get settingsBehaviorDefaultModel => '默认模型';

  @override
  String get settingsBehaviorDefaultModelHelp => '通过配置在 OpenCode 客户端之间共享。';

  @override
  String get settingsBehaviorDescription => '管理语言、聊天行为、数据使用和 OpenCode 默认设置';

  @override
  String get settingsBehaviorEnableDataSaver => '启用蜂窝数据节省程序';

  @override
  String get settingsBehaviorMultiDeviceSync => '启用实验性多设备同步';

  @override
  String get settingsBehaviorMultiDeviceSyncDescription =>
      '将 composer 选择（agent/model/variant）与活动服务器配置同步。';

  @override
  String get settingsBehaviorMultiDeviceSyncWarning =>
      '在同时进行多个会话时，可能会中止正在进行的会话。';

  @override
  String get settingsBehaviorNoAgents => '未找到 agent';

  @override
  String get settingsBehaviorNoModels => '未找到模型';

  @override
  String get settingsBehaviorOpenCodeAutoupdate => 'OpenCode 自动更新';

  @override
  String get settingsBehaviorOpenCodeDefaults => '由 OpenCode 支持的默认设置';

  @override
  String get settingsBehaviorOpenCodeDefaultsDescription =>
      '这些值会写入活动服务器上的 `/config`，并与官方 OpenCode 共享配置匹配。';

  @override
  String get settingsBehaviorOpenCodeSnapshots => 'OpenCode 快照';

  @override
  String get settingsBehaviorOpenCodeSnapshotsDescription =>
      '保持启用上游基于 git 的快照，以支持撤销/重做和恢复历史记录。';

  @override
  String get settingsBehaviorPermissionDeferred =>
      '高级权限规则编辑目前不在“设置”中，并推迟到以后的对等性工作。';

  @override
  String get settingsBehaviorPermissionProvenance => '权限处理凭证';

  @override
  String get settingsBehaviorPermissionProvenanceDescription =>
      '官方 OpenCode 权限策略在 `opencode.json` 中配置，每个工具有允许/询问/拒绝规则。CodeWalk 保留了官方的权限请求卡，并添加了一个经过批准的 ADR-023 例外：composer 自动批准切换无条件地以 `Always` 和 `remember: true` 进行回复，以创建持久的会话范围授权，并在 Android 后台工作进程中保持相同的线程范围连续性路径处于活动状态。';

  @override
  String get settingsBehaviorRefreshDefaults => '刷新默认值';

  @override
  String get settingsBehaviorSaveUsername => '保存用户名';

  @override
  String get settingsBehaviorSearchAutoupdate => '搜索自动更新模式';

  @override
  String get settingsBehaviorSearchDefaultAgent => '搜索默认 agent';

  @override
  String get settingsBehaviorSearchDefaultModel => '搜索默认模型';

  @override
  String get settingsBehaviorSearchShareMode => '搜索共享模式';

  @override
  String get settingsBehaviorSearchSmallModel => '搜索小型模型';

  @override
  String get settingsBehaviorShareMode => 'OpenCode 默认共享方式';

  @override
  String get settingsBehaviorShareModeCaveat =>
      '使用聊天级别的共享操作现在发布一个会话。此设置仅会更改 OpenCode 的默认共享策略。';

  @override
  String get settingsBehaviorShareModeHelp =>
      '控制官方全局的 `share` 配置，而不是单个聊天的共享按钮。';

  @override
  String get settingsBehaviorSmallModel => '小型模型';

  @override
  String get settingsBehaviorSmallModelAutoFallback => '自动回退';

  @override
  String get settingsBehaviorSmallModelFallbackActive =>
      '由于未设置 `small_model`，OpenCode 自动回退已激活。';

  @override
  String get settingsBehaviorSmallModelHelp => '用于轻量级任务，例如标题生成。';

  @override
  String get settingsBehaviorSmallModelResetCaveat =>
      '将 `small_model` 重置为自动回退仍需要从应用外部编辑配置，因为 `/config` 补丁更新无法移除键。';

  @override
  String get settingsBehaviorSnapshotCaveat =>
      '这控制的是 OpenCode 快照存储和撤销/重做支持，而不是 CodeWalk 本地缓存快照。';

  @override
  String get settingsBehaviorTitle => '行为';

  @override
  String get settingsBehaviorUsernameFallback =>
      '由于未设置 `username`，OpenCode 将使用系统用户名。';

  @override
  String get settingsBehaviorUsernamePatchCaveat =>
      '将 `username` 重置为系统默认值仍需要从应用外部编辑配置，因为 `/config` 补丁更新无法移除键。';

  @override
  String get settingsConfigRefreshFailed => '已更新服务器设置，但无法刷新聊天提供商。';

  @override
  String get settingsConfigUpdateDeferred =>
      'CodeWalk 将在当前响应完成后应用此 OpenCode 设置。';

  @override
  String get settingsConversationUsername => '对话用户名';

  @override
  String get settingsDefaultAgent => '默认智能体';

  @override
  String get settingsDefaultModel => '默认模型';

  @override
  String get settingsLanguageDescription => '选择 CodeWalk 使用的语言。系统默认会遵循您的设备语言。';

  @override
  String get settingsLanguageEmptyText => '未找到语言';

  @override
  String get settingsLanguageFieldHelper => '立即生效并跨重启持久化。';

  @override
  String get settingsLanguageFieldLabel => '应用语言';

  @override
  String get settingsLanguageSearchHint => '搜索语言';

  @override
  String get settingsLanguageSystemDefault => '系统默认';

  @override
  String get settingsLanguageTitle => '语言';

  @override
  String get settingsLogsDescription => '查看应用诊断和故障排查详情';

  @override
  String get settingsLogsTitle => 'Registros';

  @override
  String get settingsNoAgentsFound => '未找到智能体';

  @override
  String get settingsNotificationsAgentSubtitle => '当响应结束时';

  @override
  String get settingsNotificationsAgentUpdates => 'Agent 更新';

  @override
  String get settingsNotificationsAnotherConversation => '另一个会话';

  @override
  String get settingsNotificationsAppInBackground => '应用在后台';

  @override
  String get settingsNotificationsBackgroundAlerts => 'Android 后台警报';

  @override
  String get settingsNotificationsBackgroundBehavior => '后台行为';

  @override
  String get settingsNotificationsBackgroundBehaviorDescription =>
      '选择 CodeWalk 在应用离开前台后的行为方式。';

  @override
  String get settingsNotificationsBackgroundDescription =>
      '在应用未处于屏幕前端时，对响应完成、权限请求、问题和错误使用低数据后台监控。';

  @override
  String get settingsNotificationsBackgroundToggle => 'Android 后台警报';

  @override
  String get settingsNotificationsBackgroundToggleDescription =>
      '关闭所有 Android 后台检查并隐藏持久的监控通知。';

  @override
  String get settingsNotificationsBatteryDescription =>
      '如果通知仅在重新打开应用时到达，请允许 CodeWalk 在此设备上不受优化限制运行。';

  @override
  String get settingsNotificationsBatteryDisabled => '已为 CodeWalk 禁用电池优化。';

  @override
  String get settingsNotificationsBatteryEnabled => '已启用电池优化。某些设备可能会延迟后台警报。';

  @override
  String get settingsNotificationsBatteryOptimization => 'Android 电池优化';

  @override
  String get settingsNotificationsBatteryUnknown => '尚无法读取电池优化状态。';

  @override
  String get settingsNotificationsChooseAudioFile => '选择音频文件';

  @override
  String get settingsNotificationsChooseSystemSound => '选择系统声音';

  @override
  String get settingsNotificationsCloseToTray => '关闭至系统托盘';

  @override
  String get settingsNotificationsCloseToTrayDescription => '隐藏窗口并继续在系统托盘中运行。';

  @override
  String get settingsNotificationsDescription => '选择要提醒您的事件及提醒方式';

  @override
  String get settingsNotificationsDisableOptimization => '禁用优化';

  @override
  String get settingsNotificationsErrors => '错误';

  @override
  String get settingsNotificationsErrorsSubtitle => '当会话报告失败时';

  @override
  String get settingsNotificationsJustClose => '直接关闭';

  @override
  String get settingsNotificationsJustCloseDescription => '完全退出应用程序。';

  @override
  String get settingsNotificationsKeepLive => '保持警报活跃 3 分钟';

  @override
  String get settingsNotificationsKeepLiveDescription =>
      '当响应已在运行时，在退出应用后简短保持实时连接活跃。';

  @override
  String get settingsNotificationsLocal => '本地';

  @override
  String get settingsNotificationsMinimizeWhenClose => '关闭时最小化';

  @override
  String get settingsNotificationsMinimizeWhenCloseDescription =>
      '最小化到任务栏/程序坞并继续运行。';

  @override
  String get settingsNotificationsNoCondition => '如果未选择任何条件，则在任何上下文中均允许警报。';

  @override
  String get settingsNotificationsNotify => '通知';

  @override
  String get settingsNotificationsNotifyOnlyWhen => '仅当以下情况时通知';

  @override
  String get settingsNotificationsOpenBatterySettings => '打开电池设置';

  @override
  String get settingsNotificationsPermissions => '权限与问题';

  @override
  String get settingsNotificationsPermissionsSubtitle => '当工具请求您的输入时';

  @override
  String get settingsNotificationsPreview => '预览';

  @override
  String get settingsNotificationsRefreshStatus => '刷新状态';

  @override
  String get settingsNotificationsSearchSoundType => '搜索声音类型';

  @override
  String get settingsNotificationsSectionDescription => '控制提醒出现的时间以及何时可以播放声音。';

  @override
  String get settingsNotificationsSectionTitle => '通知';

  @override
  String settingsNotificationsSelectedSound(String label) {
    return '已选择: $label';
  }

  @override
  String get settingsNotificationsServer => '服务器';

  @override
  String get settingsNotificationsSound => '声音';

  @override
  String get settingsNotificationsSoundBuiltInAlert => '内置警报声';

  @override
  String get settingsNotificationsSoundBuiltInClick => '内置咔哒声';

  @override
  String get settingsNotificationsSoundOff => '关闭';

  @override
  String get settingsNotificationsSoundOnlyWhen => '仅当以下情况时播放声音';

  @override
  String get settingsNotificationsSoundPickAudioFile => '选择音频文件';

  @override
  String get settingsNotificationsSoundPickFromSystem => '从系统中选择';

  @override
  String get settingsNotificationsSoundSystemDefault => '系统默认';

  @override
  String get settingsNotificationsSoundType => '声音类型';

  @override
  String get settingsNotificationsSyncInfo => '某些类别的开关已与活动服务器上的 /config 同步。';

  @override
  String get settingsNotificationsSyncInfoLocal =>
      '当前服务器未在 /config 中暴露通知开关；本地值处于活动状态。';

  @override
  String get settingsNotificationsSystemSoundPickerTitle => '选择系统声音';

  @override
  String get settingsNotificationsTitle => '通知';

  @override
  String get settingsNotificationsWhenClosing => '当关闭窗口时';

  @override
  String get settingsOpenCodeAutoUpdate => 'OpenCode 自动更新';

  @override
  String get settingsOpenCodeSharingDefault => 'OpenCode 默认共享';

  @override
  String get settingsReadAloudEnabled => '朗读';

  @override
  String get settingsReadAloudEnabledDescription => '在助手消息上显示朗读按钮。';

  @override
  String get settingsReadAloudPitch => '音调';

  @override
  String get settingsReadAloudPitchDescription => '调整语音音调。';

  @override
  String get settingsReadAloudSectionDescription => '朗读助手响应。配置语速、音调和语音。';

  @override
  String get settingsReadAloudSectionTitle => '文字转语音';

  @override
  String get settingsReadAloudSpeed => '语速';

  @override
  String get settingsReadAloudSpeedDescription => '调整说话语速。';

  @override
  String get settingsReadAloudVoice => '语音';

  @override
  String get settingsReadAloudVoiceHint => '选择用于朗读的语音。';

  @override
  String get settingsSearchAutoUpdateMode => '搜索自动更新模式';

  @override
  String get settingsSearchDefaultAgent => '搜索默认智能体';

  @override
  String get settingsSearchDefaultModel => '搜索默认模型';

  @override
  String get settingsSearchSharingMode => '搜索共享模式';

  @override
  String get settingsSearchSmallModel => '搜索小模型';

  @override
  String get settingsServersActive => '活动';

  @override
  String get settingsServersChooseActive => '选择活动服务器';

  @override
  String get settingsServersDefault => '默认';

  @override
  String get settingsServersDescription => '连接 OpenCode 并管理您的服务器';

  @override
  String get settingsServersTitle => '服务器';

  @override
  String get settingsSessionAttentionSize => '气泡大小';

  @override
  String get settingsSessionAttentionSizeExtraLarge => '特大';

  @override
  String get settingsSessionAttentionSizeExtraSmall => '特小';

  @override
  String get settingsSessionAttentionSizeLarge => '大';

  @override
  String get settingsSessionAttentionSizeSmall => '小';

  @override
  String get settingsSessionAttentionSizeStandard => '标准';

  @override
  String get settingsSetupWizard => '设置向导';

  @override
  String get settingsShortcutsDescription => '查找和自定义键盘快捷键';

  @override
  String get settingsShortcutsEdit => '编辑快捷键';

  @override
  String get settingsShortcutsKeyboard => '键盘快捷键';

  @override
  String get settingsShortcutsReset => '重置快捷键';

  @override
  String get settingsShortcutsSearch => '搜索快捷键';

  @override
  String get settingsShortcutsTitle => '快捷键';

  @override
  String get settingsSmallModel => '小模型';

  @override
  String get settingsSmallModelResetExplanation =>
      '将 `small_model` 重置回自动回退仍需在应用外编辑配置，因为 `/config` 补丁更新无法删除键。';

  @override
  String get settingsSmallModelUnsetExplanation =>
      '由于未设置 `small_model`，OpenCode 自动回退已激活。';

  @override
  String get settingsSoundPickerNotAvailable => '系统声音选择器在此平台上不可用。';

  @override
  String get settingsSpeechDescription => '设置语音输入、离线模型和朗读';

  @override
  String get settingsSpeechRefreshStatus => '刷新状态';

  @override
  String settingsSpeechSilenceTimeout(String value) {
    return '静音超时: $value秒';
  }

  @override
  String get settingsSpeechTitle => '语音转文本';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsGroupAlertTypes => '提醒类型';

  @override
  String get settingsGroupBackgroundBehavior => '后台行为';

  @override
  String get settingsGroupChatDisplay => '聊天显示';

  @override
  String get settingsGroupCurrentConnection => '当前连接';

  @override
  String get settingsGroupDataAndSync => '数据与同步';

  @override
  String get settingsGroupDataReset => '数据与重置';

  @override
  String get settingsGroupDelivery => '投递方式';

  @override
  String get settingsGroupHelp => '帮助';

  @override
  String get settingsGroupLanguageAndChat => '语言与聊天';

  @override
  String get settingsGroupLayoutAndText => '布局与文字';

  @override
  String get settingsGroupOfflineModels => '离线模型';

  @override
  String get settingsGroupOpenCodeDefaults => 'OpenCode 默认设置';

  @override
  String get settingsGroupReadAloud => '朗读';

  @override
  String get settingsGroupSavedServers => '已保存的服务器';

  @override
  String get settingsGroupThemeAndColor => '主题与颜色';

  @override
  String get settingsGroupThisDevice => '此设备';

  @override
  String get settingsGroupVersionUpdates => '版本与更新';

  @override
  String get settingsGroupVoiceInput => '语音输入';

  @override
  String get settingsNavigationGroupExperience => '体验';

  @override
  String get settingsNavigationGroupInput => '输入';

  @override
  String get settingsNavigationGroupSetup => '设置';

  @override
  String get settingsNavigationGroupSupport => '帮助与诊断';

  @override
  String get settingsNavigationNoResults => '未找到设置';

  @override
  String get settingsNavigationSearchHint => '搜索设置';

  @override
  String get settingsUsernameClearHint => '清除 OpenCode 会话用户名后，仍需在应用外部编辑配置。';

  @override
  String get settingsUsernameEnterHint => '输入用户名以保存自定义 OpenCode 会话名称。';

  @override
  String get settingsUsernameResetExplanation =>
      '将 `username` 重置回系统默认值仍需在应用外编辑配置，因为 `/config` 补丁更新无法删除键。';

  @override
  String get settingsUsernameUnsetExplanation =>
      'OpenCode 使用系统用户名，因为 `username` 未设置。';

  @override
  String get setupDebugBun => 'Bun';

  @override
  String get setupDebugBun2 => 'Bun';

  @override
  String get setupDebugCapturedSetupDetails => '尚无捕获的设置详情';

  @override
  String get setupDebugCapturedSetupLogs => '已捕获的设置日志';

  @override
  String get setupDebugClear => '清除设置调试信息';

  @override
  String get setupDebugClearSetupDebug => '清除设置调试';

  @override
  String get setupDebugCodeWalkCaptureEnough =>
      '如果 CodeWalk 未捕获到足够的上下文，请直接检查官方 OpenCode 日志和运行状况端点：';

  @override
  String get setupDebugCommandPath => '命令路径';

  @override
  String get setupDebugCommandPath2 => '命令路径';

  @override
  String get setupDebugCopy => '复制设置调试信息';

  @override
  String get setupDebugCopySetupDebug => '复制设置调试';

  @override
  String get setupDebugCurrentStatus => '当前状态';

  @override
  String get setupDebugDiagnosticsLoading => '诊断仍在加载中。';

  @override
  String get setupDebugEnvironment => '环境诊断';

  @override
  String get setupDebugEnvironmentDiagnostics => '环境诊断';

  @override
  String get setupDebugFocusedOpenCodeSetup => '专注于 OpenCode 设置';

  @override
  String get setupDebugInstallDir => '安装目录';

  @override
  String get setupDebugInstallDirectory => '安装目录';

  @override
  String get setupDebugLatestLocalServer => '最新本地服务器输出';

  @override
  String get setupDebugLogs => '捕获的设置日志';

  @override
  String get setupDebugManual => '手动问题排查';

  @override
  String get setupDebugManualTroubleshooting => '手动排障';

  @override
  String get setupDebugNetwork => '网络';

  @override
  String get setupDebugNetwork2 => '网络';

  @override
  String get setupDebugNoDetails => '暂未捕获到设置详情';

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
  String get setupDebugOpenCodeSetupDebug => 'OpenCode 设置调试';

  @override
  String get setupDebugPlatform => '平台';

  @override
  String get setupDebugPlatform2 => '平台';

  @override
  String get setupDebugRunDiagnosticsTry =>
      '运行诊断、尝试安装方法或尝试设置流程，以在此处捕获 OpenCode 特定的排障详情。';

  @override
  String get setupDebugScreenCoversOpenCode =>
      '此屏幕仅涵盖 OpenCode 安装、诊断 and 本地设置排障。一般 CodeWalk 运行时问题请使用“应用日志”。';

  @override
  String get setupDebugServerOutput => '最新本地服务器输出';

  @override
  String get setupDebugStatus => '当前状态';

  @override
  String setupDebugTimeEntrySource(String source, String time) {
    return '$time - $source';
  }

  @override
  String get setupDebugTimeline => '时间线';

  @override
  String get setupDebugTimeline2 => '时间线';

  @override
  String get setupDebugTitle => '聚焦于 OpenCode 设置';

  @override
  String get setupDebugWSL => 'WSL';

  @override
  String get setupDebugWsl => 'WSL';

  @override
  String get shortcutCloseApp => '关闭标签页/应用';

  @override
  String get shortcutCloseAppDesc => '如果当前会话标签页可用则将其关闭，否则按平台行为关闭应用';

  @override
  String get shortcutFocusCloseDrawer => '聚焦/关闭侧边栏';

  @override
  String get shortcutFocusCloseDrawerDesc => '默认聚焦输入框，或在打开时关闭侧边栏';

  @override
  String get shortcutFocusInput => '聚焦输入框';

  @override
  String get shortcutFocusInputDesc => '将焦点移动到文本输入框';

  @override
  String get shortcutGroupApplication => '应用';

  @override
  String get shortcutGroupGeneral => '通用';

  @override
  String get shortcutGroupModelAndAgent => '模型与代理';

  @override
  String get shortcutGroupNavigation => '导航';

  @override
  String get shortcutGroupPrompt => '提示词';

  @override
  String get shortcutGroupSession => '会话';

  @override
  String get shortcutNewConversation => '新会话';

  @override
  String get shortcutNewConversationDesc => '创建一个新的聊天会话';

  @override
  String get shortcutNextAgent => '下一个代理';

  @override
  String get shortcutNextAgentDesc => '切换到下一个可用代理';

  @override
  String get shortcutNextRecentModel => '下一个近期模型';

  @override
  String get shortcutNextRecentModelDesc => '在最近使用的模型之间切换';

  @override
  String get shortcutNextVariant => '下一个变体';

  @override
  String get shortcutNextVariantDesc => '在可用的模型变体之间切换';

  @override
  String get shortcutOpenSettings => '打开设置';

  @override
  String get shortcutOpenSettingsDesc => '打开设置页面';

  @override
  String get shortcutPreviousAgent => '上一个代理';

  @override
  String get shortcutPreviousAgentDesc => '切换到上一个可用代理';

  @override
  String get shortcutQuickOpenFiles => '快速打开文件';

  @override
  String get shortcutQuickOpenFilesDesc => '打开文件快速搜索';

  @override
  String get shortcutQuitApp => '退出应用';

  @override
  String get shortcutQuitAppDesc => '强制退出应用';

  @override
  String get shortcutRefreshData => '刷新数据';

  @override
  String get shortcutRefreshDataDesc => '刷新当前聊天数据';

  @override
  String get shortcutStopResponse => '停止响应';

  @override
  String get shortcutStopResponseDesc => '停止当前响应（响应时）';

  @override
  String get shortcutToggleVoiceInput => '切换语音输入';

  @override
  String get shortcutToggleVoiceInputDesc => '在编辑器中开始或停止语音听写';

  @override
  String get shortcutsApply => '应用';

  @override
  String shortcutsConflictConflict(String conflict) {
    return '与$conflict冲突';
  }

  @override
  String get shortcutsKeyboardShortcuts => '键盘快捷键';

  @override
  String get shortcutsReset => '全部重置';

  @override
  String get shortcutsSearchEditBindings => '在保存前进行搜索、编辑绑定并解决冲突。';

  @override
  String shortcutsSetShortcutWidget(String label) {
    return '设置快捷键: $label';
  }

  @override
  String get shortcutsTheseBindingsStored =>
      '这些绑定存储在 CodeWalk 中用于当前应用运行时，不会修改 OpenCode `tui.json` 按键绑定。';

  @override
  String get speechAutoStopSilence => '自动停止静音超时';

  @override
  String get speechChooseRecognitionEngine => '选择识别引擎、静音超时和模型选项。';

  @override
  String speechDesktopOnly(String service) {
    return '$service 仅在桌面端可用。';
  }

  @override
  String get speechDownload => '下载';

  @override
  String get speechEngine => '引擎';

  @override
  String get speechInstalledLanguages => '已安装的语言';

  @override
  String get speechListeningStopsAutomatically => '静音达到此秒数后将自动停止聆听。';

  @override
  String get speechMicPermissionDisabled => '麦克风权限已禁用。';

  @override
  String speechModelFilesIncomplete(String service) {
    return '$service 模型文件不完整。';
  }

  @override
  String get speechMoonshine => 'Moonshine';

  @override
  String get speechMoonshineModelsDesktop => 'Moonshine 模型（桌面端）';

  @override
  String get speechMoonshineStaysDownloadable =>
      'Moonshine 保持可下载状态，不包含在应用包中。为此桌面设备选择一个模型，如果日后需要收回空间，可以将其删除。';

  @override
  String get speechNative => '原生';

  @override
  String get speechNativeSTTDisabled =>
      '在此应用的 Linux 系统上已禁用原生 STT。Parakeet 是新安装的默认引擎。';

  @override
  String get speechNativeSTTWorks =>
      '在 Windows 上，CodeWalk 通过其 WASAPI 麦克风后端使用本地设备端语音识别。为保持稳定性，Windows 原生语音识别已禁用。';

  @override
  String get speechNativeStartsFaster =>
      '原生引擎启动更快。Sherpa 完全在设备上运行，具有更繁重的设置和更深度的模型控制。';

  @override
  String get speechOpenMicrophoneSettings => '打开麦克风设置';

  @override
  String get speechOpenSpeechPrivacy => '打开语音隐私设置';

  @override
  String get speechOpenSpeechSettings => '打开语音设置';

  @override
  String get speechParakeet => 'Parakeet';

  @override
  String get speechParakeetModelsDesktop => 'Parakeet 模型（桌面端）';

  @override
  String get speechParakeetStaysDownloadable =>
      'Parakeet 保持可下载状态，不包含在应用包中。它目前提供一个针对 25 种欧洲语言优化的多语言模型。';

  @override
  String get speechPickLanguagePacks => '选择语言包并下载/删除模型以进行设备端识别。';

  @override
  String get speechRemove => '移除';

  @override
  String speechRuntimeFailed(String service) {
    return '$service 运行时初始化失败。';
  }

  @override
  String get speechSelectSherpaAbove => '在上方选择 Sherpa 以管理语言包并下载模型。';

  @override
  String get speechSenseVoice => 'SenseVoice';

  @override
  String get speechSenseVoiceModelsDesktop => 'SenseVoice 模型（桌面端）';

  @override
  String get speechSenseVoiceStaysDownloadable =>
      'SenseVoice 保持可下载状态，不包含在应用包中。它是此处针对中文、粤语、日语、韩语和英语最强劲的桌面端选项。';

  @override
  String get speechSherpa => 'Sherpa';

  @override
  String get speechSherpaExperimentalFail =>
      'Sherpa 是实验性的，在某些设备上可能会失败。如果您希望获得最稳定的行为，请首选“原生”。';

  @override
  String get speechSherpaModelsLinux => 'Sherpa 模型（Linux）';

  @override
  String get speechSpeechText => '语音转文本';

  @override
  String speechUnavailableOnPlatform(String service) {
    return '$service 语音在此平台上不可用。';
  }

  @override
  String get speechWindowsSetupHint =>
      'Windows 语音输入使用 CodeWalk WASAPI 采集和设备端模型。请保持桌面应用可访问麦克风；下方按钮会打开 Windows 设置以进行故障排查。';

  @override
  String get statusConnected => '已连接';

  @override
  String get statusDelayed => '延迟';

  @override
  String get statusFailed => '失败';

  @override
  String get statusOffline => '离线';

  @override
  String get statusOnline => '在线';

  @override
  String get statusReconnecting => '重新连接';

  @override
  String get statusStarting => '正在启动';

  @override
  String get statusStopped => '已停止';

  @override
  String get statusStopping => '正在停止';

  @override
  String get statusSyncDelayed => '同步延迟';

  @override
  String get tailscaleNoPeers => '未找到对等节点';

  @override
  String get tailscaleNotSupportedOnPlatform => '此平台不支持 Tailscale。';

  @override
  String get tailscaleNotSupportedOnWindows => 'Windows 不支持 Tailscale。';

  @override
  String get tailscalePeerOffline => '离线';

  @override
  String get tailscaleSelectPeer => '选择一个 Tailscale 对等节点';

  @override
  String get tailscaleWaitingAdminApproval => '此 Tailscale 节点正在等待管理员批准。';

  @override
  String get terminalClose => '关闭终端';

  @override
  String terminalConnectingTo(String serverName) {
    return '正在连接到 $serverName 终端...';
  }

  @override
  String terminalConnectionFailed(String error) {
    return '终端连接失败：$error';
  }

  @override
  String get terminalDisconnected => '终端已断开连接。';

  @override
  String terminalEmbeddedUnavailable(String serverName) {
    return '此运行时尚不支持嵌入式终端。请继续使用撰写器的 shell 模式执行一次性命令，或从支持的 CodeWalk 应用运行时打开 $serverName 的终端。';
  }

  @override
  String get terminalExtraKeyAlt => 'Alt 键';

  @override
  String get terminalExtraKeyArrowDown => '向下箭头';

  @override
  String get terminalExtraKeyArrowLeft => '向左箭头';

  @override
  String get terminalExtraKeyArrowRight => '向右箭头';

  @override
  String get terminalExtraKeyArrowUp => '向上箭头';

  @override
  String get terminalExtraKeyControl => 'Control 键';

  @override
  String get terminalExtraKeyEscape => 'Escape 键';

  @override
  String get terminalExtraKeyTab => 'Tab 键';

  @override
  String get terminalExtraKeys => '终端附加键';

  @override
  String get terminalHide => '隐藏终端';

  @override
  String get terminalMaximize => '最大化';

  @override
  String get terminalMinimize => '最小化终端';

  @override
  String get terminalNotAvailableYet => '嵌入式终端在此运行时中尚不可用。';

  @override
  String get terminalOpen => '打开终端';

  @override
  String get terminalOpenInfo => '打开终端信息';

  @override
  String get terminalOpenProjectFirst => '在启动服务器终端之前，请先打开项目文件夹。';

  @override
  String get terminalOpenToConnect => '打开终端以连接到服务器项目终端。';

  @override
  String get terminalReconnect => '重新连接终端';

  @override
  String get terminalRestoreSize => '还原大小';

  @override
  String get terminalSelectServer => '在打开终端之前，请选择一个活动服务器。';

  @override
  String get terminalSessionClosed => '终端会话已关闭。';

  @override
  String get terminalTerminal => '终端';

  @override
  String get terminalTitle => '终端';

  @override
  String get terminalTryAgain => '重试';

  @override
  String get toolAwaitingInput => '等待输入';

  @override
  String get toolEditing => '编辑中';

  @override
  String get toolEditingFiles => '正在编辑文件';

  @override
  String get toolFinding => '查找中';

  @override
  String get toolFindingFiles => '正在查找文件';

  @override
  String get toolPresentationAwaitingInput => '等待输入';

  @override
  String get toolPresentationEditing => '正在编辑';

  @override
  String get toolPresentationEditingFiles => '正在编辑文件';

  @override
  String get toolPresentationFinding => '正在查找';

  @override
  String get toolPresentationFindingFiles => '正在查找文件';

  @override
  String get toolPresentationReading => '正在读取';

  @override
  String get toolPresentationReadingFile => '正在读取文件';

  @override
  String get toolPresentationRunning => '正在运行';

  @override
  String get toolPresentationRunningCommand => '正在运行命令';

  @override
  String toolPresentationRunningTool(String toolName) {
    return '正在运行 $toolName';
  }

  @override
  String get toolPresentationSearching => '正在搜索';

  @override
  String get toolPresentationSearchingCode => '正在搜索代码';

  @override
  String get toolPresentationSearchingWeb => '正在搜索网页';

  @override
  String get toolPresentationTool => '工具';

  @override
  String get toolPresentationUpdatingTaskList => '正在更新任务列表';

  @override
  String get toolPresentationUpdatingTasks => '正在更新任务';

  @override
  String get toolPresentationWaitingInput => '等待您的输入';

  @override
  String get toolPresentationWriting => '正在写入';

  @override
  String get toolPresentationWritingFile => '正在写入文件';

  @override
  String get toolReading => '读取中';

  @override
  String get toolReadingFile => '正在读取文件';

  @override
  String get toolRunning => '运行中';

  @override
  String get toolRunningCommand => '正在运行命令';

  @override
  String get toolRunningTask => '正在运行任务';

  @override
  String get toolSearching => '搜索中';

  @override
  String get toolSearchingCode => '正在搜索代码';

  @override
  String get toolSearchingWeb => '正在搜索网页';

  @override
  String get toolUpdatingTaskList => '正在更新任务列表';

  @override
  String get toolUpdatingTasks => '正在更新任务';

  @override
  String get toolWaitingForInput => '等待您的输入';

  @override
  String get toolWriting => '写入中';

  @override
  String get toolWritingFile => '正在写入文件';

  @override
  String get tourBack => '返回';

  @override
  String get tourSkip => '跳过';

  @override
  String get trayQuit => '退出';

  @override
  String get trayShow => '显示';

  @override
  String get useOAuthCloudflareAccess => '使用 OAuth (Cloudflare Access)';

  @override
  String get useOAuthCloudflareAccessSubtitle =>
      '打开浏览器以进行 Cloudflare Access 托管式 OAuth。';

  @override
  String get useOAuthCloudflareAccessUnsupported =>
      '此平台不支持 Cloudflare Access OAuth。请改用基本身份验证。';

  @override
  String get useTailscale => '使用 Tailscale';

  @override
  String get useTailscaleSubtitle => '在没有系统 VPN 的情况下通过 Tailscale 网络路由流量。';

  @override
  String get useTailscaleUnsupported => '此平台不支持 Tailscale。';

  @override
  String get utilityTitle => '实用工具';

  @override
  String get workspaceBrowseDirs => '浏览目录';

  @override
  String get workspaceChooseFolderOpen => '选择任意文件夹作为项目上下文打开。';

  @override
  String workspaceCloseProject(String project) {
    return '关闭 $project';
  }

  @override
  String get workspaceClosedProjects => '关闭的项目';

  @override
  String workspaceCurrentDirectory(String path) {
    return '当前目录：$path';
  }

  @override
  String get workspaceFilterDirs => '过滤目录';

  @override
  String get workspaceOpenFolder => '打开文件夹';

  @override
  String get workspaceOpenProjectFolder => '打开项目文件夹';

  @override
  String get workspaceOpenProjects => '打开的项目';

  @override
  String get workspaceProjectDirectory => '项目目录';

  @override
  String get workspaceProjectHint => '/repo/my-project';

  @override
  String workspaceRemoveFromHistory(String name) {
    return '从历史记录中移除 $name';
  }

  @override
  String get settingsSessionAttentionTitle => '会话提醒';

  @override
  String get settingsSessionAttentionDescription => '在可选气泡或面板中显示根会话状态。';

  @override
  String get settingsSessionAttentionOff => '关闭';

  @override
  String get settingsSessionAttentionBubble => '气泡';

  @override
  String get settingsSessionAttentionPanel => '面板';

  @override
  String get settingsSessionAttentionPrivacy =>
      '在 Android 上启用后会启动持久前台服务。回复文本将加密存储；只有按下“朗读”后，云端 TTS 才会发送文本。';

  @override
  String get settingsSessionAttentionUnavailable => '此平台不支持会话提醒。';

  @override
  String get settingsSessionAttentionOpenSettings => '打开显示设置';

  @override
  String get settingsSessionAttentionStop => '停止会话提醒';

  @override
  String get settingsSessionAttentionThirdPartyTtsWarning =>
      '按下“朗读”时，回复文本可能会发送到已配置的第三方 TTS 提供商。';

  @override
  String get workspaceSuggestions => '建议';

  @override
  String get sessionTabsGestureHintTitle => '会话标签页新增了控制功能';

  @override
  String get sessionTabsGestureHintBody =>
      '双击标签页可将其关闭。右键单击或长按可打开会话操作。您可以在“显示开关”中禁用标签页。';

  @override
  String get sessionTabsGestureHintAcknowledge => '知道了';

  @override
  String get sessionTabsGestureHintDisableTabs => '禁用标签页';

  @override
  String get sessionTabRenameAction => '重命名会话';

  @override
  String sessionTabClosedMessage(String title) {
    return '标签页“$title”已关闭';
  }

  @override
  String get sessionTabUndo => '撤销';

  @override
  String get sessionTabRestoreFailed => '无法恢复标签页。';

  @override
  String get sessionTabChangeIconAction => '更改图标';

  @override
  String get sessionTabIconPickerTitle => '选择标签页图标';

  @override
  String get sessionTabIconUseProjectIcon => '使用项目图标';

  @override
  String get sessionTabIconApplied => '标签页图标已更新。';

  @override
  String get sessionTabIconSaveFailed => '无法保存标签页图标。';

  @override
  String get sessionTabIconPresetCode => '代码';

  @override
  String get sessionTabIconPresetTerminal => '终端';

  @override
  String get sessionTabIconPresetBug => '缺陷';

  @override
  String get sessionTabIconPresetTasks => '任务';

  @override
  String get sessionTabIconPresetLaunch => '启动';

  @override
  String get sessionTabIconPresetIdea => '灵感';

  @override
  String get sessionTabIconPresetResearch => '研究';

  @override
  String get sessionTabIconPresetDesign => '设计';

  @override
  String get sessionTabIconPresetData => '数据';

  @override
  String get sessionTabIconPresetCloud => '云端';

  @override
  String get sessionTabIconPresetSecurity => '安全';

  @override
  String get sessionTabIconPresetTools => '工具';

  @override
  String get workspaceNoActiveContext => '无活动上下文';

  @override
  String get settingsAppearanceContrastLow => '低';

  @override
  String get settingsAppearanceContrastStandard => '标准';

  @override
  String get settingsAppearanceContrastMedium => '中';

  @override
  String get settingsAppearanceContrastMediumHigh => '中高';

  @override
  String get settingsNotificationsSystemSoundsWebUnavailable => 'Web 端不可用。';

  @override
  String get settingsNotificationsSystemSoundsAndroid => '使用 Android 系统通知声音。';

  @override
  String get settingsNotificationsSystemSoundsFreedesktop =>
      '使用 /usr/share/sounds/freedesktop/stereo 中的 Freedesktop 声音。';

  @override
  String get settingsNotificationsSystemSoundsPlatform => '在操作系统提供系统声音的平台上受支持。';

  @override
  String get serversQuickGuideTitle => '快速设置';

  @override
  String get serversQuickGuideIntro =>
      'CodeWalk 是应用，OpenCode 是需要先运行、此连接才能工作的引擎。';

  @override
  String get serversQuickGuideStepInstallCli => '1. 安装 OpenCode CLI。';

  @override
  String get serversQuickGuideRunPowerShell => '2. 在 PowerShell 中运行：';

  @override
  String get serversQuickGuideRunTerminal => '2. 在您的终端中运行：';

  @override
  String get serversQuickGuideProtectPassword => '使用密码保护访问';

  @override
  String get serversQuickGuideServerPassword => '服务器密码';

  @override
  String get serversQuickGuideInstallOptions =>
      '其他官方安装方式：安装脚本、npm、bun、pnpm、Homebrew，或 GitHub Releases 中的二进制文件。';

  @override
  String get serversQuickGuideVerifyHint =>
      '启动服务器后，请先确认 /global/health 或 /doc 有响应，再将 URL 粘贴到 CodeWalk 中。';

  @override
  String get shortcutsPressKeyCombination => '现在请按下组合键';

  @override
  String get settingsProvenanceOpenCodeBacked => 'OpenCode 后端';

  @override
  String get settingsProvenanceCodeWalkLocal => 'CodeWalk 本地';

  @override
  String get settingsProvenanceCodeWalkException => 'CodeWalk 异常';

  @override
  String get shortcutsErrorInvalid => '无效的快捷键';

  @override
  String get shortcutsErrorUnsupportedKey => '不支持的快捷键';

  @override
  String shortcutsErrorConflict(String conflict) {
    return '与“$conflict”冲突';
  }

  @override
  String get settingsSessionAttentionStopSaveFailed => '会话关注已停止，但设置无法保存。';

  @override
  String get settingsSessionAttentionEnableFailed => '无法启用会话关注。';

  @override
  String get settingsSessionAttentionSaveFailedStopped => '会话关注设置无法保存，已停止。';

  @override
  String get settingsSessionAttentionStillRunning => '会话关注仍在运行。请再次尝试停止。';

  @override
  String get settingsSessionAttentionStopFailed => '无法停止会话关注。请重试。';

  @override
  String get settingsSessionAttentionCapabilityUnavailable => '会话关注的主机能力不可用。';

  @override
  String get settingsServerFallbackProviderName => '在服务器上配置';

  @override
  String get composerStopResponse => '停止响应';

  @override
  String get composerSendMessageWhileResponding => '响应运行中发送消息';

  @override
  String get composerSendMessage => '发送消息';

  @override
  String get chatTourComposerDescription => '在此输入您的请求。';

  @override
  String get chatTourSendDescription => '在此发送您的消息。';

  @override
  String get composerAttachmentFallbackName => '附件';

  @override
  String get composerContextFallbackName => '上下文';

  @override
  String get searchableDropdownSearchHint => '搜索';

  @override
  String get searchableDropdownEmptyText => '未找到匹配项';

  @override
  String get speechApiKeyStorageUnavailable => '安全存储 TTS API 密钥的功能不可用。';

  @override
  String get speechApiKeyRemoved => 'API 密钥已移除。';

  @override
  String get speechApiKeySaved => 'API 密钥已安全保存到此设备。';

  @override
  String get speechReadAloudTestText => '这是 CodeWalk 的文字转语音测试。';

  @override
  String get speechNativeDisabledWindows =>
      '出于稳定性考虑，Windows 上已禁用。请通过 CodeWalk WASAPI 采集使用 Parakeet 或其他设备端引擎。';

  @override
  String get speechNativeUnavailableLinux => 'Linux 上不可用。请使用 Parakeet 进行语音输入。';

  @override
  String get speechNotAvailableOnPlatform => '此平台不可用。';

  @override
  String get speechSherpaUnavailableAndroid => '在针对小 APK 体积优化的 Android 构建中不可用。';

  @override
  String get speechMoonshineDesktopOnlyHint => '仅桌面端可用。Android 端保持仅限原生。';

  @override
  String get speechParakeetDesktopOnlyHint => '仅桌面端可用。使用离线多语言识别。';

  @override
  String get speechSenseVoiceDesktopOnlyHint => '仅桌面端可用。对中文、粤语、日语、韩语和英语支持最佳。';

  @override
  String get speechNativeSubtitle => '启动更简单、更快速。';

  @override
  String get speechSherpaSubtitle => '较笨重、实验性且容易出问题。使用下载的模型通常更准确。';

  @override
  String get speechMoonshineSubtitle =>
      '仅限桌面端的实验性路径，使用 sherpa_onnx 离线识别和可下载模型。';

  @override
  String get speechParakeetSubtitle =>
      '仅限桌面端的离线 NeMo transducer 路径，配有一个可下载的多语言模型。';

  @override
  String get speechSenseVoiceSubtitle => '仅限桌面端的离线路径，针对中文、粤语、日语、韩语和英语优化。';

  @override
  String get speechMoonshineModel => 'Moonshine 模型';

  @override
  String get speechSherpaLanguage => 'Sherpa 语言';

  @override
  String get speechSearchSherpaLanguage => '搜索 Sherpa 语言';

  @override
  String get speechNoLanguagePacksFound => '未找到语言包';

  @override
  String get speechTextToSpeechProvider => '文字转语音提供商';

  @override
  String get speechProviderSystemNative => '系统 / 原生';

  @override
  String get speechProviderEdgeExperimental => 'Microsoft Edge 语音（实验）';

  @override
  String get speechProviderOpenAiCompatible => 'OpenAI 兼容';

  @override
  String get speechProviderElevenLabs => 'ElevenLabs';

  @override
  String get speechProviderNvidiaNim => 'NVIDIA NIM';

  @override
  String get speechNimSpeedNotSupported => '速度不受 NVIDIA NIM TTS 支持，因此对此提供商隐藏。';

  @override
  String get speechRemoteVoice => '语音';

  @override
  String get speechRemoteVoiceUnavailable => '所选语音在提供商的目录中不再可用。';

  @override
  String get speechRemoteVoiceListUnavailable => '正在使用默认语音。当前无法加载语音列表。';

  @override
  String get speechRemoteVoicesLoaded => '已从提供商的语音中加载。';

  @override
  String get speechRemoteModel => '模型';

  @override
  String get speechRemoteModelListUnavailable => '当前无法加载模型列表。你可以在下方输入自定义模型。';

  @override
  String get speechRemoteModelsLoaded => '已从提供商的模型中加载。';

  @override
  String get speechRemoteModelUnavailable => '所选模型在提供商的目录中不再可用。';

  @override
  String get speechCustomModel => '自定义模型…';

  @override
  String get speechEdgeExperimentalTitle => 'Microsoft Edge 语音为实验功能';

  @override
  String get speechEdgeExperimentalDescription =>
      '直接从此设备使用非官方的 Edge 朗读服务。使用朗读时，消息文本会发送给 Microsoft；如果 Microsoft 更改私有协议，该服务可能会失效。';

  @override
  String get speechEdgeVoice => 'Edge 语音';

  @override
  String get speechEdgeVoiceUnavailable => '所选语音不再可用。正在使用默认 Edge 语音。';

  @override
  String get speechEdgeVoiceListUnavailable => '正在使用默认 Edge 语音。目前无法加载语音列表。';

  @override
  String get speechEdgeVoicesLoaded => '已从 Microsoft Edge 语音加载。';

  @override
  String get speechCloudTtsPrivacy => '云端 TTS 隐私';

  @override
  String get speechCloudTtsPrivacyDescription =>
      '云端 TTS 会将选定的助手消息文本发送到配置的提供商。API 密钥存储在此设备的安全存储中。';

  @override
  String get speechBaseUrl => '基础 URL';

  @override
  String get speechApiKey => 'API 密钥';

  @override
  String get speechApiKeySavedHelper => '已保存密钥。输入新值以替换，或保存空值以移除。';

  @override
  String get speechNoApiKeySaved => '未保存 API 密钥。';

  @override
  String get speechSaveApiKey => '保存 API 密钥';

  @override
  String get speechModel => '模型';

  @override
  String get speechPitchNotSupported => 'OpenAI 兼容 TTS 不支持音高，因此该提供商已隐藏此选项。';

  @override
  String get speechPitchHiddenForProvider => '音调不受此 TTS 提供商支持，因此被隐藏。';

  @override
  String get speechTestVoice => '测试语音';

  @override
  String get speechReadAloudTestPhraseLabel => '语音测试短语';

  @override
  String get speechReadAloudTestPhraseHint => '留空则使用默认测试短语。';

  @override
  String get dialogMoonshineVoiceSetupDescription =>
      'Moonshine 通过 sherpa_onnx 在设备端运行。只需选择一次模型，并仅为此桌面设备下载。';

  @override
  String get dialogParakeetVoiceSetupDescription =>
      'Parakeet 通过 sherpa_onnx 离线识别在设备端运行。为此桌面设备下载一次，即可启用多语言语音转文字（STT）。';

  @override
  String get dialogSenseVoiceSetupDescription =>
      'SenseVoice 通过 sherpa_onnx 离线识别在设备端运行。对中文、粤语、日语、韩语和英语支持最佳。';

  @override
  String get dialogSherpaVoiceSetupDescription =>
      'Sherpa 语音输入需要设备端语音模型。请选择您的语言并下载一次（约 147 MB）。';

  @override
  String speechSilenceSeconds(String value) {
    return '$value 秒';
  }

  @override
  String speechModelInstalled(String modelId) {
    return '模型已安装（$modelId）';
  }

  @override
  String speechModelMissing(String modelId) {
    return '模型缺失（$modelId）';
  }

  @override
  String speechModelSizeMb(String sizeMb) {
    return '约 $sizeMb MB';
  }

  @override
  String speechSystemDefaultLanguage(String language) {
    return '系统默认（$language）';
  }

  @override
  String speechModelListLoadFailed(String error, String service) {
    return '无法加载 $service 模型列表：$error';
  }

  @override
  String speechDownloadFailed(String error) {
    return '下载失败：$error';
  }

  @override
  String speechFailedToRemoveModel(String error) {
    return '移除模型失败：$error';
  }

  @override
  String speechBaseUrlExample(String url) {
    return '示例：$url';
  }

  @override
  String speechModelDefaultHelper(String model) {
    return '默认：$model';
  }

  @override
  String get notificationPermissionOrQuestionNeedsInput => '工具权限或问题需要您的输入。';

  @override
  String get notificationPermissionNeedsInput => '工具权限需要您的输入。';

  @override
  String get notificationQuestionNeedsInput => '工具问题需要您的输入。';

  @override
  String get notificationSessionError => '某个会话报告了错误。';

  @override
  String get notificationChannelErrors => 'CodeWalk 错误';

  @override
  String get notificationChannelErrorsDescription => 'CodeWalk 错误提醒';

  @override
  String get notificationChannelPermissions => 'CodeWalk 权限';

  @override
  String get notificationChannelPermissionsDescription => 'CodeWalk 操作待处理提醒';

  @override
  String get notificationChannelAgent => 'CodeWalk 代理';

  @override
  String get notificationChannelAgentDescription => 'CodeWalk 代理完成提醒';

  @override
  String get notificationActionOpen => '打开';

  @override
  String get foregroundMonitorNotificationBody => '可靠的后台提醒已启用';

  @override
  String get foregroundMonitorNotificationTitle => '后台监控已启用';

  @override
  String get foregroundMonitorNotificationOneSession => '正在监控 1 个会话';

  @override
  String foregroundMonitorNotificationSessionCount(int count) {
    return '正在监控 $count 个会话';
  }

  @override
  String sessionAttentionSemanticLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个会话需要关注',
      one: '1 个会话需要关注',
    );
    return '$_temp0';
  }

  @override
  String get sessionAttentionOverlayPermissionRequired => '需要“在其他应用上层显示”权限。';

  @override
  String get sessionAttentionIosInAppOnly => '会话关注仅在 CodeWalk 应用内可用。';

  @override
  String get sessionAttentionOverlayPermissionGrantPrompt =>
      '请授予在其他应用上层显示的权限，然后重试。';

  @override
  String get sessionAttentionAndroidStartFailed => 'Android 会话关注服务无法启动。';

  @override
  String chatMessageTruncatedChars(int count, String reason) {
    return '[已截断 $count 个字符] $reason';
  }

  @override
  String get chatMessageJustNow => '刚刚';

  @override
  String chatMessageMinutesAgo(int count) {
    return '$count 分钟前';
  }

  @override
  String chatMessageHoursAgo(int count) {
    return '$count 小时前';
  }

  @override
  String chatMessageDaysAgo(int count) {
    return '$count 天前';
  }

  @override
  String chatMessageDateTime(int day, int hour, int minute, int month) {
    return '$month月$day日 $hour:$minute';
  }

  @override
  String get chatMessageYourMessage => '您的消息';

  @override
  String get chatMessageAssistantMessage => '助手消息';

  @override
  String chatMessageStepStarted(int step) {
    return '步骤 #$step 已开始';
  }

  @override
  String chatMessageStepStartedWithSnapshot(String snapshot, int step) {
    return '步骤 #$step 已开始：$snapshot';
  }

  @override
  String chatMessageStepFinished(
    String cost,
    String reason,
    int step,
    int tokens,
  ) {
    return '步骤 #$step 已完成：$reason • tokens $tokens • \$$cost';
  }

  @override
  String chatMessagePatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个补丁',
      one: '1 个补丁',
    );
    return '$_temp0';
  }

  @override
  String get chatMessageToolRun => '工具运行';

  @override
  String get chatMessageToolExecution => '工具执行';

  @override
  String chatMessageToolChainMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count 更多',
      one: '+1 更多',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolChainExtraTypes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count 种类型',
      one: '+1 种类型',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolAttentionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项需要关注',
      one: '1 项需要关注',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolDoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项完成',
      one: '1 项完成',
    );
    return '$_temp0';
  }

  @override
  String get chatMessageToolCallsTitle => '工具调用';

  @override
  String get chatMessageDiffPreviewTruncated => '为保证应用稳定性，Diff 预览已被截断。';

  @override
  String get chatMessageLargeMessageTruncated => '为保证应用稳定性，大消息预览已被截断。';

  @override
  String get chatMessageInvalidLinkFormat => '无效的链接格式';

  @override
  String get chatMessageUnableToOpenLink => '无法打开链接';

  @override
  String sessionTodoInProgressCompact(int current, int total) {
    return '进行中 $current/$total';
  }

  @override
  String sessionTodoTaskProgress(String content, int index, int total) {
    return '任务 $index/$total $content';
  }

  @override
  String sessionTodoDoneCompact(int count, int total) {
    return '已完成 $count/$total';
  }

  @override
  String sessionTodoCompletedCount(int count, int total) {
    return '已完成 $count/$total 个任务';
  }

  @override
  String sessionTodoTasksCount(int count) {
    return '任务（$count）';
  }

  @override
  String questionStepOfReview(int current, int total) {
    return '第 $current 步，共 $total 步 - 查看';
  }

  @override
  String questionStepOfQuestion(int current, int total) {
    return '第 $current 步，共 $total 步 - 问题';
  }

  @override
  String get questionCustomAnswer => '自定义答案';

  @override
  String get questionSubmitAnswers => '提交答案';

  @override
  String get questionReviewAnswers => '查看答案';

  @override
  String permissionRequestTitle(String permission) {
    return '权限请求：$permission';
  }

  @override
  String get sessionTitleCannotBeEmpty => '标题不能为空';

  @override
  String get filesFailedToLoad => '加载文件失败';

  @override
  String get filesFailedToSearch => '搜索文件失败';

  @override
  String get filesNoOpenFilesHint => '还没有打开的文件。输入以搜索。';

  @override
  String get filesNoContentMatches => '未找到匹配的内容';

  @override
  String filesOpenFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个打开的文件',
      one: '1 个打开的文件',
    );
    return '$_temp0';
  }

  @override
  String filesLinesSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选择 $count 行',
      one: '已选择 1 行',
    );
    return '$_temp0';
  }

  @override
  String get filesDraftTooLargeToSave => '草稿过大，无法从编辑器保存。';

  @override
  String get filesSaveChangesBeforeClose => '关闭此文件前请保存更改。';

  @override
  String get filesSaveChangesBeforePathChange => '更改此路径前请保存更改。';

  @override
  String get filesWaitForSaveBeforePathChange => '更改此路径前请等待文件保存完成。';

  @override
  String get filesWaitForFileOperation => '请等待文件操作完成。';

  @override
  String get filesLargeFileReadOnly => '大文件以只读方式打开，以保持编辑响应流畅。';

  @override
  String get filesCheckingWriteSupport => '正在检查文件写入支持...';

  @override
  String get filesActiveProjectRequired => '文件操作需要活动项目目录。';

  @override
  String get filesReloadSkippedUnsavedChanges => '存在未保存的更改；已跳过重新加载。';

  @override
  String get filesFailedToLoadContent => '加载文件内容失败';

  @override
  String get filesFileSaved => '文件已保存。';

  @override
  String get filesParentNotDirectory => '父级不是目录。';

  @override
  String get filesMalformedResponse => '文件操作返回了无效响应。';

  @override
  String get filesShellCommandDidNotComplete => '文件操作的 shell 命令未执行完成。';

  @override
  String get filesShellCommandNoResult => '文件操作的 shell 命令未返回结果。';

  @override
  String get filesShellCommandTruncated => '文件操作的 shell 命令被服务器截断。';

  @override
  String get filesShellCommandSyntaxError => '文件操作的 shell 命令因语法错误而失败。';

  @override
  String get filesShellUtilityNotFound => '找不到所需的 shell 实用工具。';

  @override
  String get filesShellCommandFailed => '文件操作的 shell 命令在返回结果前失败。';

  @override
  String get attachmentSaveTitle => '保存附件';

  @override
  String get attachmentBrowserSandboxLocalFile => '浏览器沙盒阻止直接打开本地 file:// 附件。';

  @override
  String get attachmentLocalPathBrowserBlocked => '此附件指向一个本地路径，无法从浏览器中打开。';

  @override
  String terminalConnectedTo(String directory, String serverName) {
    return '已连接到 $directory 中的 $serverName';
  }

  @override
  String get terminalTransportUnavailable => '终端传输不可用。';

  @override
  String get chatSlashCommandNew => '创建新的聊天会话';

  @override
  String get chatSlashCommandModels => '打开模型选择器';

  @override
  String get chatSlashCommandSessions => '打开会话列表';

  @override
  String get chatSlashCommandAgent => '打开智能体选择器';

  @override
  String get chatSlashCommandOpen => '打开文件快速操作';

  @override
  String get chatSlashCommandHelp => '显示命令帮助';

  @override
  String get chatSlashCommandCompact => '压缩当前会话上下文';

  @override
  String get chatSlashCommandThinking => '切换思考气泡';

  @override
  String get chatSlashCommandUndo => '撤销上一条可见的用户消息';

  @override
  String get chatSlashCommandRedo => '重做上一个已撤销的操作';

  @override
  String chatSessionSubConversationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个子对话',
      one: '1 个子对话',
    );
    return '$_temp0';
  }

  @override
  String chatMessageWeeksAgo(int count) {
    return '$count 周前';
  }

  @override
  String chatMessageShortDate(int day, int month) {
    return '$month/$day';
  }

  @override
  String get chatProviderErrorLoadSessionStatus => '加载会话状态失败';

  @override
  String get chatProviderErrorLoadSessionDetails => '部分会话详情无法加载';

  @override
  String chatProviderErrorLoadSessionList(String error) {
    return '加载会话列表失败：$error';
  }

  @override
  String get chatProviderErrorCreateSession => '创建会话失败';

  @override
  String get chatProviderErrorSelectProviderModelBeforeSend =>
      '发送前请先选择已连接的提供商或免费的 OpenCode 模型';

  @override
  String get chatProviderErrorStartMessageSend => '开始发送消息失败';

  @override
  String get chatProviderErrorStopUnavailable => '当前会话无法停止';

  @override
  String get chatProviderErrorWaitForResponseFinish => '请等待当前响应完成后再进行压缩';

  @override
  String get chatProviderErrorCompactUnavailable => '当前会话无法压缩上下文';

  @override
  String get chatProviderErrorSelectModelBeforeCompact => '压缩上下文前请先选择模型';

  @override
  String get chatProviderErrorCompactSessionContext => '压缩会话上下文失败';

  @override
  String get chatProviderErrorNetwork => '网络连接失败。请检查网络设置';

  @override
  String get chatProviderErrorServer => '服务器错误。请稍后重试';

  @override
  String get chatProviderErrorNotFound => '找不到资源';

  @override
  String get chatProviderErrorInvalidInput => '输入参数无效';

  @override
  String get chatProviderErrorUnknown => '未知错误。请稍后重试';

  @override
  String get chatProviderErrorSessionFallback => '会话错误';

  @override
  String get projectProviderErrorNoProjectContext => '服务器上没有可用的项目上下文';

  @override
  String projectProviderErrorInitializeFailed(String error) {
    return '初始化项目上下文失败：$error';
  }

  @override
  String get projectProviderErrorSwitchProjectNotFound => '切换项目失败：找不到项目';

  @override
  String get projectProviderErrorSwitchDirectoryEmpty => '切换项目失败：目录为空';

  @override
  String get projectProviderErrorAtLeastOneContext => '至少必须保留一个打开的上下文';

  @override
  String get projectProviderErrorReopenProjectNotFound => '重新打开项目失败：找不到项目';

  @override
  String get projectProviderErrorOnlyClosedArchivable => '只有已关闭的项目才能归档';

  @override
  String get projectProviderErrorArchiveProjectNotFound => '归档项目失败：找不到项目';

  @override
  String get projectProviderErrorArchiveProjectPathInvalid => '归档项目失败：项目路径无效';

  @override
  String projectProviderErrorLoadWorkspaces(String error) {
    return '加载工作区失败：$error';
  }

  @override
  String get projectProviderErrorWorkspaceNameEmpty => '工作区名称不能为空';

  @override
  String projectProviderErrorCreateWorkspace(String error) {
    return '创建工作区失败：$error';
  }

  @override
  String projectProviderErrorResetWorkspace(String error) {
    return '重置工作区失败：$error';
  }

  @override
  String projectProviderErrorDeleteWorkspace(String error) {
    return '删除工作区失败：$error';
  }

  @override
  String get projectProviderErrorDirectoryEmpty => '目录不能为空';

  @override
  String projectProviderErrorListDirectories(String error) {
    return '列出目录失败：$error';
  }

  @override
  String projectProviderErrorValidateDirectory(String error) {
    return '验证目录失败：$error';
  }

  @override
  String get projectProviderErrorPathEmpty => '路径不能为空';

  @override
  String projectProviderErrorListFiles(String error) {
    return '列出文件失败：$error';
  }

  @override
  String projectProviderErrorSearchFiles(String error) {
    return '搜索文件失败：$error';
  }

  @override
  String projectProviderErrorContentSearchUnavailable(String error) {
    return '内容搜索不可用：$error';
  }

  @override
  String projectProviderErrorSearchSymbols(String error) {
    return '搜索符号失败：$error';
  }

  @override
  String projectProviderErrorReadFile(String error) {
    return '读取文件失败：$error';
  }

  @override
  String projectProviderErrorLoadProjectList(String error) {
    return '加载项目列表失败：$error';
  }

  @override
  String get workspaceProjectRemovedFromHistory => '项目已从历史记录中移除';

  @override
  String workspaceProjectContextOpened(String directory) {
    return '项目上下文已打开：$directory';
  }

  @override
  String workspaceFailedToOpenProjectContext(String directory) {
    return '打开项目上下文失败：$directory';
  }

  @override
  String get chatAbortNotice => '您想做出哪些不同的操作？';

  @override
  String sessionTitleToday(String date, String time) {
    return '今天 $time（$date）';
  }

  @override
  String sessionTitleYesterday(String date, String time) {
    return '昨天 $time（$date）';
  }

  @override
  String sessionTitleWeekday(String date, String time, String weekday) {
    return '$weekday $time（$date）';
  }

  @override
  String sessionTitleDateAndTime(String date, String time) {
    return '$date $time';
  }

  @override
  String get sessionWeekdayMon => '周一';

  @override
  String get sessionWeekdayTue => '周二';

  @override
  String get sessionWeekdayWed => '周三';

  @override
  String get sessionWeekdayThu => '周四';

  @override
  String get sessionWeekdayFri => '周五';

  @override
  String get sessionWeekdaySat => '周六';

  @override
  String get sessionWeekdaySun => '周日';

  @override
  String get forwardTimeNow => '刚刚';

  @override
  String forwardTimeMinutes(int count) {
    return '$count 分钟';
  }

  @override
  String forwardTimeHours(int count) {
    return '$count 小时';
  }

  @override
  String forwardTimeDays(int count) {
    return '$count 天';
  }

  @override
  String forwardTimeWeeks(int count) {
    return '$count 周';
  }

  @override
  String get settingsBehaviorConfigFieldDefaultModel => '默认模型';

  @override
  String get settingsBehaviorConfigFieldDefaultAgent => '默认智能体';

  @override
  String get settingsBehaviorConfigFieldSmallModel => '小型模型';

  @override
  String get settingsBehaviorConfigFieldAutoUpdateMode => '自动更新模式';

  @override
  String get settingsBehaviorConfigFieldSnapshotSetting => '快照设置';

  @override
  String get settingsBehaviorConfigFieldConversationUsername => '会话用户名';

  @override
  String get settingsBehaviorConfigFieldSharingDefault => '默认共享方式';

  @override
  String get speechMicNoInputDevice => '没有可用的麦克风输入设备。';

  @override
  String get speechMicDeviceBusy => '默认麦克风正被其他应用占用。';

  @override
  String get speechMicUnsupportedFormat => '不支持默认麦克风格式。';

  @override
  String get speechMicSpeechPrivacy => 'Windows 语音服务可能已被禁用（语音隐私、在线语音识别或语言包）。';

  @override
  String get speechMicBackendUnavailable => '此构建中不可用 Windows 麦克风后端。';

  @override
  String speechEngineFallbackNotice(String fallback, String reason) {
    return '所选 STT 引擎不可用（$reason）。将改用 $fallback。';
  }

  @override
  String get oauthFlowSecureStorageUnavailable => 'OAuth 的安全凭据存储不可用。';

  @override
  String get oauthFlowUnexpectedError => 'OAuth 流程意外失败。请重试。';

  @override
  String get oauthFlowNoEndpointsDiscovered =>
      '未发现 OAuth 端点。请在 Cloudflare Dashboard → Access → Applications → [此应用] 中启用托管 OAuth。';

  @override
  String get oauthFlowTokenResponseMissingAccessToken => 'OAuth 令牌响应不包含访问令牌。';

  @override
  String get oauthFlowProfileChanged => 'OAuth 完成前服务器配置文件已更改。';

  @override
  String get oauthFlowMetadataMissingEndpoints => 'OAuth 元数据缺少授权/令牌端点。';

  @override
  String get oauthFlowCallbackNotCompleted => '授权回调未完成';

  @override
  String get oauthFlowProviderDeclined => '授权服务器拒绝了 OAuth 请求。请重试。';

  @override
  String get oauthFlowCallbackValidationFailed => 'OAuth 回调验证失败。请重试。';

  @override
  String get oauthFlowCallbackServerStartFailed => '本地 OAuth 回调服务器启动失败。';

  @override
  String get oauthFlowSignInCanceled => 'OAuth 登录已取消。';

  @override
  String get oauthFlowBrowserOpenFailed => '无法为 OAuth 登录打开系统浏览器。';

  @override
  String get oauthFlowCallbackTimeout =>
      '5 分钟内未收到授权回调。浏览器应在授权同意后重定向到本地回调地址。如果浏览器反而显示连接错误，则说明此设备或网络阻止了回环重定向。';

  @override
  String oauthFlowTokenExchangeTransientFailure(int maxAttempts) {
    return '由于临时网络问题，令牌交换在 $maxAttempts 次尝试后失败。请重试。';
  }

  @override
  String oauthFlowTokenExchangeHttpFailure(int statusCode) {
    return '令牌交换失败（HTTP $statusCode）。请重试。';
  }

  @override
  String get oauthFlowTokenExchangeUnexpectedFailure => '令牌交换意外失败。请重试。';

  @override
  String get oauthFlowTokenExchangeIncomplete =>
      '授权代码发送后令牌交换未完成。请重新开始 OAuth 登录。';

  @override
  String get speechReadAloudFailed => '文字转语音失败。';

  @override
  String get speechReadAloudNoText => '没有可朗读的文本。';

  @override
  String get speechEdgeTextTooLong => 'Microsoft Edge 语音一次最多可读取 4096 字节。';

  @override
  String get speechEdgeMalformedAudio => 'Microsoft Edge 语音返回了格式错误的音频数据。';

  @override
  String get speechEdgeUnsupportedAudio => 'Microsoft Edge 语音返回了不支持的音频数据。';

  @override
  String get speechEdgeUnsupportedFrame =>
      'Microsoft Edge 语音返回了不支持的 websocket 帧。';

  @override
  String get speechEdgeSynthesisInterrupted => 'Microsoft Edge 语音在合成完成前结束。';

  @override
  String get speechEdgeEmptyAudio => 'Microsoft Edge 语音返回了空音频响应。';

  @override
  String get speechEdgeTimedOut => 'Microsoft Edge 语音超时。';

  @override
  String get speechEdgeUnreachable => '无法访问 Microsoft Edge 语音。';

  @override
  String get speechApiKeyMissing => '请在 设置 > 语音 中添加 API 密钥以使用此 TTS 提供商。';

  @override
  String get speechProviderEmptyAudio => 'TTS 提供商返回了空音频响应。';

  @override
  String get speechProviderRequestRejected => 'TTS 提供商拒绝了语音请求。';

  @override
  String get speechApiKeyRejected => 'TTS API 密钥被提供商拒绝。';

  @override
  String get speechProviderQuotaRateLimit => 'TTS 提供商报告了配额或速率限制。';

  @override
  String get speechReadAloudNoVoice => '为此 TTS 提供商选择语音。';

  @override
  String get speechProviderTextTooLong => '此 TTS 模型的文本过长。';

  @override
  String get speechProviderInvalidAudio => 'TTS 提供商返回了无法识别的音频。';

  @override
  String get speechNimBaseUrlRequired =>
      '在 设置 > 文字转语音 中输入 NVIDIA NIM 部署的基本 URL。';

  @override
  String get speechProviderTemporarilyUnavailable => 'TTS 提供商暂时不可用。';

  @override
  String get speechProviderUnreachable => '无法访问 TTS 提供商。';

  @override
  String appProviderErrorFailedToStartProcess(String tool) {
    return '无法启动 $tool 进程。';
  }

  @override
  String appProviderErrorToolNotAvailable(String runtime, String tool) {
    return '$tool 不可用。请先安装 $runtime。';
  }

  @override
  String appProviderErrorToolInstallFailed(int exitCode, String tool) {
    return '$tool 安装失败，退出代码为 $exitCode。';
  }

  @override
  String appProviderErrorBunBootstrapFailed(int exitCode) {
    return 'Bun 引导失败，退出代码为 $exitCode。';
  }

  @override
  String get appProviderErrorInstalledButNotFoundInPath =>
      'OpenCode 安装已完成，但在 PATH 中未找到命令。';

  @override
  String get appProviderErrorInstalledButPathNotResolved =>
      'OpenCode 安装已完成，但无法解析命令路径。';

  @override
  String appProviderErrorConfiguredCommandNotFound(String tool) {
    return '未找到配置的命令，且 $tool 不在 PATH 中。';
  }

  @override
  String get appProviderErrorConfiguredCommandPathMissing => '配置的命令路径不存在。';

  @override
  String get appProviderErrorConfiguredCommandVersionCheckFailed =>
      '配置的命令存在，但版本检查失败。';

  @override
  String get appProviderErrorConfiguredCommandExecutionFailed => '无法执行配置的命令。';

  @override
  String get appProviderWslCheckWindowsOnly => 'WSL 检查仅适用于 Windows。';

  @override
  String get appProviderDesktopBuildRequired => '请使用桌面版配置托管本地服务器。';

  @override
  String get appProviderKnownInstallationDirectoryDetected => '已从已知的安装目录中检测到。';

  @override
  String appProviderKnownInstallationPathRefreshHint(String appName) {
    return '已从已知的安装目录中检测到。PATH 可能需要刷新；如果尚未检测到最近的安装，请重新打开 $appName。';
  }

  @override
  String get appProviderErrorReleaseMetadataFetchFailed =>
      '从 GitHub 获取最新版本元数据失败。';

  @override
  String get appProviderErrorReleaseAssetListMissing => '最新版本元数据中未包含资产列表。';

  @override
  String get appProviderErrorNoCompatibleAsset => '未找到兼容的 OpenCode 二进制资产。';

  @override
  String get appProviderErrorDownloadAssetFailed => '下载所选 OpenCode 资产失败。';

  @override
  String get appProviderErrorChecksumVerificationFailed => '已下载资产的校验和验证失败。';

  @override
  String get appProviderErrorExtractArchiveFailed => '解压 OpenCode 二进制压缩包失败。';

  @override
  String appProviderErrorExecutableNotFound(String tool) {
    return '在解压的文件中找不到 $tool 可执行文件。';
  }

  @override
  String get chatNoResponseFromServer => '服务器无响应，请重试。';

  @override
  String get chatNoResponseFromModel => '模型无响应，请重试。';

  @override
  String get speechJobCancelled => '语音任务已取消。';

  @override
  String get speechEdgeCancelled => 'Microsoft Edge 语音已取消。';

  @override
  String get sessionAttentionKindActive => '活动';

  @override
  String get sessionAttentionKindReceiving => '接收中';

  @override
  String get sessionAttentionKindDelayed => '延迟';

  @override
  String get sessionAttentionKindCompleted => '已完成';

  @override
  String get sessionAttentionKindPendingInteraction => '等待交互';

  @override
  String get sessionAttentionKindError => '错误';

  @override
  String get sessionAttentionPauseCellularDataSaver => '移动数据节省模式已开启。';

  @override
  String get sessionAttentionPauseOauthReopenRequired => '需要 OAuth 登录';

  @override
  String get sessionAttentionPauseTailscaleReopenRequired => '需要 Tailscale 连接';

  @override
  String get sessionAttentionPauseOffline => '离线';

  @override
  String get sessionAttentionPausePermissionRevoked => '权限已被撤销';

  @override
  String get sessionAttentionPauseServiceStopped => '服务已停止';

  @override
  String get sessionAttentionPauseHostUnavailable => '主机不可用';

  @override
  String get errorRequestCancelled => '请求已取消';

  @override
  String errorUnknownNetworkError(String error) {
    return '未知网络错误: $error';
  }

  @override
  String get errorCertificateError => '证书错误';

  @override
  String get errorSessionBusy => '会话正忙于处理另一个请求。';

  @override
  String get errorRunShellCommandFailed => '运行 shell 命令失败';

  @override
  String get errorRunSlashCommandFailed => '运行斜杠命令失败';

  @override
  String get settingsBehaviorOpenCodeDefaultsLoadError =>
      '无法从活动服务器加载 OpenCode 支持的默认设置。';

  @override
  String get sessionTabIconRemoveFailed => '删除本地会话标签图标数据失败';

  @override
  String get forwardUntitled => '无标题';

  @override
  String setupDebugLinuxLogsPath(String path) {
    return 'Linux 日志: $path';
  }

  @override
  String setupDebugRunOpenCodeCommand(String command) {
    return '使用以下命令运行 OpenCode: $command';
  }

  @override
  String setupDebugServerHealthEndpoint(String endpoint) {
    return '服务器健康检查: $endpoint';
  }

  @override
  String setupDebugServerDocsEndpoint(String endpoint) {
    return '服务器文档: $endpoint';
  }

  @override
  String get logsEntryError => '错误';

  @override
  String get logsEntryStack => '堆栈';

  @override
  String get setupDebugSourceDiagnostics => '诊断';

  @override
  String get setupDebugSourceUseExisting => '使用现有';

  @override
  String get setupDebugSourceLocalServer => '本地服务器';

  @override
  String get setupDebugSourceOnboarding => '引导设置';

  @override
  String get setupDebugSourceManualConnection => '手动连接';

  @override
  String setupDebugMessageDiagnosticsResult(
    String availability,
    String platform,
    String recommendation,
  ) {
    return '在 $platform 上 $availability。$recommendation';
  }

  @override
  String get setupDebugMessageDetectAttempt => '正在尝试从当前环境检测现有的 OpenCode 命令。';

  @override
  String get setupDebugMessageInstallStarted => '已从 CodeWalk 开始安装 OpenCode。';

  @override
  String setupDebugMessageStartLocalServer(String url) {
    return '正在 $url 启动受管的 OpenCode 服务器。';
  }

  @override
  String setupDebugMessageHealthyRunning(String url) {
    return '受管的 OpenCode 服务器状态正常，正在 $url 运行。';
  }

  @override
  String get setupDebugMessageStoppingLocalServer => '正在停止受管的 OpenCode 服务器。';

  @override
  String get setupDebugMessageStoppedCleanly => '受管的 OpenCode 服务器已正常停止。';

  @override
  String get setupDebugMessageExitedAfterRequestedStop =>
      '收到停止请求后，受管的 OpenCode 服务器已退出。';

  @override
  String get setupDebugMessageOnboardingConnectExisting =>
      '用户选择了连接到现有的 OpenCode 服务器。';

  @override
  String get setupDebugMessageOnboardingGuidedPath => '用户打开了 OpenCode 引导式设置流程。';

  @override
  String get setupDebugMessageOnboardingManagedLocal =>
      '用户打开了受管的本地 OpenCode 设置。';

  @override
  String get setupDebugMessageOnboardingOpenedServerSettings =>
      '健康检查失败后，用户打开了服务器设置。';

  @override
  String get setupDebugMessageOnboardingAddAnotherServer =>
      '健康检查失败后，用户选择了添加另一台服务器。';

  @override
  String setupDebugMessageTestingServerUrl(String url) {
    return '正在测试来自引导流程的 OpenCode 服务器 URL $url。';
  }

  @override
  String get chatProviderErrorSessionNotFound => '未找到会话';

  @override
  String get chatProviderErrorInvalidMessageFormat => '消息格式无效';

  @override
  String get chatProviderErrorNetworkShort => '网络连接失败';

  @override
  String get chatProviderErrorUnknownShort => '未知错误';

  @override
  String get terminalCreateFailed => '创建终端会话失败';

  @override
  String get terminalEndpointUnavailable => '终端端点不可用';

  @override
  String get terminalInvalidDirectory => '终端目录无效';

  @override
  String get terminalWebsocketUnavailable => '此处无法使用终端 WebSocket。';

  @override
  String chatMessageToolChainCallsCompact(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 次',
      one: '1 次',
    );
    return '$_temp0';
  }

  @override
  String get errorConnectionTimeout => '连接超时';

  @override
  String get errorClientError => '客户端错误';

  @override
  String get chatProviderErrorSendMessage => '发送消息失败';

  @override
  String get speechApiEngine => 'API';

  @override
  String get speechApiEngineSubtitle => 'OpenAI、Groq 或自定义 OpenAI 兼容端点。';

  @override
  String get speechApiProvider => '语音转文本提供商';

  @override
  String get speechCloudSttPrivacy => '云语音转文本隐私';

  @override
  String get speechCloudSttPrivacyDescription =>
      '录制的麦克风音频会发送到已配置的提供商。API 密钥会安全存储在此设备上。';

  @override
  String get speechApiKeyOptional => '自定义端点可省略。';

  @override
  String speechApiBatchHint(String provider) {
    return '$provider 使用批量转录。再次点按麦克风以停止并转录。';
  }

  @override
  String get speechApiWebUnavailable => 'API 语音转文本在 Web 版本上不可用。';

  @override
  String get speechApiConfigInvalid => '请检查语音 API 端点和模型。远程端点必须使用 HTTPS。';

  @override
  String get speechApiRequestInvalid => '语音端点或模型被拒绝。';

  @override
  String get speechApiRateLimited => '语音提供商报告了配额或速率限制。';

  @override
  String get speechApiUnavailable => '语音提供商暂时不可用。';

  @override
  String get speechApiNetwork => '无法连接到语音提供商。';

  @override
  String get speechApiInvalidResponse => '语音提供商返回了无效响应。';

  @override
  String get speechApiEmptyAudio => '未捕获到麦克风音频。';

  @override
  String get speechApiEmptyTranscript => '语音提供商未返回转录内容。';

  @override
  String get speechApiCustomProvider => '自定义 OpenAI 兼容';

  @override
  String get speechApiMaxDuration => 'API 录音将在 2 分钟后自动停止。';

  @override
  String get speechApiLanguageHint => '应用当前语言会作为转录提示发送。';

  @override
  String get speechSttApiKeyStorageUnavailable => '安全语音 API 密钥存储不可用。';

  @override
  String get speechSttApiKeyMissing => '请在设置 > 语音中添加语音 API 密钥。';

  @override
  String get speechSttApiKeyRejected => '语音 API 密钥被拒绝。';

  @override
  String get carMessagingReply => '回复';

  @override
  String get carMessagingMarkRead => '标记为已读';

  @override
  String get carMessagingDeliveryFailedTitle => '无法发送回复';

  @override
  String get carMessagingDeliveryFailedBody => '无法发送您的语音回复。打开 CodeWalk 重试。';
}
