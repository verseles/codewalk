// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get aboutGitHub => 'GitHub';

  @override
  String get appProviderCannotActivateUnhealthy => '異常なサーバーを有効化できません';

  @override
  String get appProviderDesktopOnly => '管理対象ローカルサーバーはデスクトップでのみ利用可能です。';

  @override
  String get appProviderDetectingCommand => 'OpenCode コマンドを検出中...';

  @override
  String get appProviderErrorCannotActivateUnhealthy => '異常なサーバーを有効化できません';

  @override
  String get appProviderErrorCloudflareOAuthNotSupported =>
      'Cloudflare Access OAuth はこのプラットフォームではサポートされていません';

  @override
  String get appProviderErrorInstallationFailed => 'OpenCode のインストールに失敗しました。';

  @override
  String get appProviderErrorInvalidServerUrl => '無効なサーバー URL';

  @override
  String get appProviderErrorLocalServerHealthCheckFailed =>
      'ローカルサーバーは起動しましたが、ヘルスチェックに合格しませんでした。';

  @override
  String get appProviderErrorManagedDesktopOnly =>
      '管理対象ローカルサーバーはデスクトップでのみ利用可能です。';

  @override
  String get appProviderErrorServerAlreadyExists => 'この URL のサーバーは既に存在します';

  @override
  String get appProviderErrorServerProfileNotFound => 'サーバープロファイルが見つかりません';

  @override
  String get appProviderErrorServerUrlRequired => 'サーバー URL は必須です';

  @override
  String get appProviderErrorTailscaleNotSupported =>
      'Tailscale はこのプラットフォームではサポートされていません';

  @override
  String appProviderExitedWithCode(int code) {
    return 'ローカルサーバーがコード $code で終了しました。';
  }

  @override
  String get appProviderFailedToStart => 'ローカル OpenCode サーバーの起動に失敗しました。';

  @override
  String get appProviderInstallBinary => 'バイナリをインストール';

  @override
  String get appProviderInstallBunOpenCode => 'Bun + OpenCode をインストール';

  @override
  String get appProviderInstallSucceeded => 'インストールが成功しました。';

  @override
  String appProviderInstallSucceededWithPath(String path) {
    return 'インストールが成功しました。OpenCode コマンドは $path で利用可能です。';
  }

  @override
  String get appProviderInstallViaBun => 'Bun 経由でインストール';

  @override
  String get appProviderInstallViaNpm => 'npm 経由でインストール';

  @override
  String get appProviderInstallationFailed => 'OpenCode のインストールに失敗しました。';

  @override
  String get appProviderInstalledSuccessfully => 'OpenCode の要件が正常にインストールされました。';

  @override
  String get appProviderInstallingRequirements => 'OpenCode の要件をインストール中...';

  @override
  String get appProviderInvalidServerUrl => '無効なサーバー URL';

  @override
  String get appProviderLabelLocalOpenCodeManaged => 'ローカル OpenCode (管理対象)';

  @override
  String get appProviderLabelPrimaryServer => 'プライマリサーバー';

  @override
  String get appProviderLocalManaged => 'ローカル OpenCode (管理対象)';

  @override
  String get appProviderLocalServerStopped => 'ローカルサーバーは停止しています。';

  @override
  String get appProviderNotDetectedInstall =>
      'OpenCode コマンドが検出されませんでした。ウィザードからインストールを実行してください。';

  @override
  String appProviderNotDetectedRefresh(String appName) {
    return 'OpenCode コマンドが検出されませんでした。インストールしたばかりの場合は、チェックを更新するか $appName を再起動して PATH を再読み込みしてください。';
  }

  @override
  String get appProviderOAuthNotSupported =>
      'Cloudflare Access OAuth はこのプラットフォームではサポートされていません';

  @override
  String get appProviderOpenCodeDetected => 'OpenCode を検出しました';

  @override
  String get appProviderOpenCodeNotDetected => 'OpenCode が検出されませんでした';

  @override
  String get appProviderPrimaryServer => 'プライマリサーバー';

  @override
  String get appProviderProfileNotFound => 'サーバープロファイルが見つかりません';

  @override
  String get appProviderRunDiagnostics =>
      'ローカルの OpenCode 要件を確認するために診断を実行してください。';

  @override
  String appProviderRunningAt(String url) {
    return '$url で実行中';
  }

  @override
  String get appProviderSetupDetectingOpenCode => 'OpenCode コマンドを検出中...';

  @override
  String get appProviderSetupInstallationSucceeded => 'インストールが成功しました。';

  @override
  String appProviderSetupInstallationSucceededWithPath(String path) {
    return 'インストールが成功しました。OpenCode コマンドは $path で利用可能です。';
  }

  @override
  String get appProviderSetupInstallingRequirements =>
      'OpenCode の要件をインストール中...';

  @override
  String get appProviderSetupOpenCodeDetected => 'OpenCode を検出しました';

  @override
  String get appProviderSetupOpenCodeNotDetected => 'OpenCode が検出されませんでした';

  @override
  String get appProviderSetupOpenCodeNotDetectedInstall =>
      'OpenCode コマンドが検出されませんでした。ウィザードからインストールを実行してください。';

  @override
  String get appProviderSetupOpenCodeNotDetectedRefresh =>
      'OpenCode コマンドが検出されませんでした。インストールしたばかりの場合は、チェックを更新するか CodeWalk を再起動して PATH を再読み込みしてください。';

  @override
  String get appProviderSetupRequirementsInstalled =>
      'OpenCode の要件が正常にインストールされました。';

  @override
  String appProviderSetupUsingOpenCodeAt(String path) {
    return '$path の OpenCode コマンドを使用中';
  }

  @override
  String get appProviderStartingLocalServer => 'ローカルサーバーを起動中...';

  @override
  String appProviderStatusLocalServerExitedWithCode(int code) {
    return 'ローカルサーバーがコード $code で終了しました。';
  }

  @override
  String get appProviderStatusLocalServerStopped => 'ローカルサーバーは停止しています。';

  @override
  String appProviderStatusRunningAt(String url) {
    return '$url で実行中';
  }

  @override
  String get appProviderStatusStartingLocalServer => 'ローカルサーバーを起動中...';

  @override
  String get appProviderStatusStoppingLocalServer => 'ローカルサーバーを停止中...';

  @override
  String get appProviderStoppingLocalServer => 'ローカルサーバーを停止中...';

  @override
  String get appProviderTailscaleNotSupported =>
      'Tailscale はこのプラットフォームではサポートされていません';

  @override
  String appProviderUsingCommandAt(String path) {
    return '$path の OpenCode コマンドを使用中';
  }

  @override
  String get appShellDownloadingUpdate => 'アップデートをダウンロード中';

  @override
  String get appShellInstall => 'インストール';

  @override
  String get appShellInstallFailed => 'インストールに失敗しました';

  @override
  String get appShellInstallingUpdate => 'アップデートをインストール中...';

  @override
  String get appShellRestart => '再起動';

  @override
  String appShellUpdateAvailableResult(String latestVersion) {
    return 'アップデートあり: v$latestVersion';
  }

  @override
  String get appShellUpdateInstalledRestartApp =>
      'アップデートがインストールされました。アプリを再起動して適用してください。';

  @override
  String get appShellUpdateInstalledRestartRequired =>
      'アップデートがインストールされました。新バージョンを適用するには再起動が必要です。';

  @override
  String get attachmentCouldNotDecode => '添付ファイルデータをデコードできませんでした。';

  @override
  String get attachmentCouldNotDownload => '添付ファイルをダウンロードできませんでした。';

  @override
  String get attachmentCouldNotSave => '添付ファイルをこのデバイスに保存できませんでした。';

  @override
  String get attachmentDownloadStarted => '添付ファイルのダウンロードを開始しました。';

  @override
  String get attachmentLocalNotFound => 'ローカルの添付ファイルがこのデバイスで見つかりませんでした。';

  @override
  String get attachmentNoValidLocation => '添付ファイルに有効な場所が指定されていません。';

  @override
  String get attachmentNotAvailableOnPlatform =>
      '添付ファイルのアクションはこのプラットフォームでは利用できません。';

  @override
  String get attachmentPathEmpty => '添付ファイルのパスが空です。';

  @override
  String get attachmentPayloadEmpty => '添付ファイルのペイロードが空です。';

  @override
  String get attachmentSaveCanceled => '保存がキャンセルされました。';

  @override
  String attachmentSavedAndOpened(String path) {
    return '添付ファイルを $path に保存して開きました。';
  }

  @override
  String attachmentSavedPath(String path) {
    return '添付ファイルを $path に保存しました。';
  }

  @override
  String attachmentSavedTo(String path) {
    return '添付ファイルを $path に保存しました。';
  }

  @override
  String get attachmentUnableToOpenLink => '添付ファイルのリンクを開けません。';

  @override
  String get attachmentUnableToOpenLocal => 'ローカルの添付ファイルを開けません。';

  @override
  String get behaviorAdvancedPermissionRule => '高度な権限ルール';

  @override
  String get behaviorAutomatic => '自動';

  @override
  String get behaviorAutomaticFallback => '自動フォールバック';

  @override
  String get behaviorCellularDataSaver => 'モバイルデータセーバー';

  @override
  String get behaviorCellularDataSaverActive => 'データセーバーが有効です。';

  @override
  String get behaviorChatLevelShare => 'チャットレベル共有';

  @override
  String get behaviorCodeWalkReleaseChecks => 'CodeWalkリリースチェック';

  @override
  String get behaviorControlsOfficialGlobal => 'OpenCodeの公式グローバル設定を制御';

  @override
  String get behaviorControlsUpstreamOpenCode => 'アップストリームOpenCode設定を制御';

  @override
  String get behaviorCustomDisplayName => 'カスタム表示名';

  @override
  String behaviorCutsAutomaticMobile(int inSeconds) {
    return 'バックグラウンドダウンロードを停止し、フォアグラウンドの自動更新を$inSeconds秒ごとに1回のバーストに制限することで、自動モバイルデータ使用量を削減します。';
  }

  @override
  String get behaviorDataSaverActive => 'モバイルデータ通信で現在有効です。';

  @override
  String get behaviorDataSaverAggressive => '積極的';

  @override
  String get behaviorDataSaverAggressiveDescription =>
      '低帯域モード: 表示中のワークスペースのストリームのみがライブのままとなり、グローバル更新は一時停止され、自動更新の間隔が延長されます。';

  @override
  String get behaviorDataSaverCellularOnly => '接続がモバイルデータ通信の場合にのみ適用されます。';

  @override
  String get behaviorDataSaverOff => 'オフ';

  @override
  String get behaviorDataSaverOffHint => '完全なリアルタイム更新と自動更新が有効です。';

  @override
  String get behaviorDataSaverStandard => '標準';

  @override
  String get behaviorDataSaverWaiting => '次のモバイルデータ同期ウィンドウを待機しています。';

  @override
  String get behaviorDisabled => '無効';

  @override
  String get behaviorLightweightTasksLike => '次のような軽量タスク';

  @override
  String get behaviorManual => '手動';

  @override
  String get behaviorNotify => '通知';

  @override
  String get behaviorOfficialOpenCodePermission =>
      '公式の OpenCode 権限ポリシーは `opencode.json` でツールごとに許可/確認/拒否ルールが設定されています。CodeWalk は公式の権限要求カードを維持しつつ、承認済みの ADR-023 例外を1つ追加しています。コンポーザーの自動承認トグルは、永続的なセッションスコープ of the grants を作成するために、無条件で `Always` かつ `remember: true` を返し、Android バックグラウンドワーカーでも同じスレッドスコープの継続パスをアクティブに保ちます。';

  @override
  String get behaviorOpenCodeBackedDefaults => 'OpenCodeベースのデフォルト値';

  @override
  String get behaviorPermissionHandlingProvenance => '権限処理の来歴（プロブナンス）';

  @override
  String get behaviorPermissionsVariantReasoning =>
      '権限とバリアント/推論のパリティは、そのUIが高度な設定を安全に保存できるようになるまで、分離されたままになります。';

  @override
  String get behaviorPrimaryAgentAgent =>
      'エージェントが明示的に選択されていない場合に使用されるプライマリエージェント。';

  @override
  String get behaviorRefreshDefaults => 'デフォルト値を更新';

  @override
  String get behaviorSharedAcrossOpenCode => '設定を通じて OpenCode クライアント間で共有されます。';

  @override
  String get behaviorTheseValuesWrite =>
      'これらの値はアクティブなサーバーの `/config` に書き込まれ、公式の OpenCode 共有設定と一致します。';

  @override
  String get cannedAddTitle => '定型文を追加';

  @override
  String get cannedAppendAtCursor => 'カーソル位置に追加';

  @override
  String get cannedAppendAtCursorSubtitle => 'オフ = 現在のテキストを置き換え';

  @override
  String get cannedAttachFiles => 'ファイルを添付';

  @override
  String get cannedEditTitle => '定型文を編集';

  @override
  String get cannedNewQuickReply => '新しいクイック返信';

  @override
  String get cannedNoSuggestions => '提案はありません';

  @override
  String get cannedOffMeansReplace => 'オフにすると現在のコンポーザーのテキストを置き換えます';

  @override
  String get cannedQuickReply => '新規クイック返信';

  @override
  String get cannedReplace => '置き換え';

  @override
  String get cannedScopeGlobalSubtitle => 'プロジェクト専用の場合は無効化';

  @override
  String get cannedScopeGlobalUnavailableSubtitle =>
      '現在のコンテキストではプロジェクト専用は利用できません';

  @override
  String get cannedSendAutomaticallySubtitle => '挿入後すぐに送信';

  @override
  String get cannedSendImmediatelyInserting => 'このクイック返信を挿入した直後に送信';

  @override
  String get cannedTextLabel => 'テキスト';

  @override
  String get chatActionNext => '次へ';

  @override
  String get chatActiveServerUnhealthy =>
      'アクティブなサーバーのヘルス状態が不良です。回復するまで送信は1回だけ試行され、すぐに失敗します。';

  @override
  String get chatActiveServerUnhealthyLabel => 'アクティブなサーバーが異常です';

  @override
  String get chatAddServerToStart => 'チャットを開始するにはサーバーを追加してください。';

  @override
  String get chatAppBarMoreActions => 'その他のアクション';

  @override
  String get chatAppBarPinAction => 'アプリバーにピン留め';

  @override
  String get chatAppBarPinDescription => 'このアクションはメニューの外側に表示されたままになります。';

  @override
  String get chatAppBarUnpinAction => 'アプリバーからピン留めを解除';

  @override
  String get chatAppBarUnpinDescription => 'このアクションはメニュー内に戻ります。';

  @override
  String chatBadgeConversationError(String title) {
    return '「$title」にエラーがあります。';
  }

  @override
  String chatBadgeConversationNeedsInput(String title) {
    return '「$title」はあなたの入力を待っています。';
  }

  @override
  String chatBadgeConversationNewReply(String title) {
    return '「$title」に新しい返信があります。';
  }

  @override
  String get chatBadgeDataSaverActive => 'データ節約モードが有効です。';

  @override
  String get chatBadgeServerNeedsAttention => 'サーバー接続に注意が必要です。';

  @override
  String get chatBadgeSyncing => '会話を同期中...';

  @override
  String get chatBlockResponsePendingDescription =>
      'このターンが終了すると、回答が1つのブロックとして表示されます。';

  @override
  String get chatBlockResponsePendingTitle => '応答を生成中';

  @override
  String get chatCachedConversationsYet => 'キャッシュされた会話はまだありません';

  @override
  String get chatChangedFilesAvailable => 'このセッションで利用可能な変更されたファイルはありません。';

  @override
  String chatChildrenChatProviderCurrentSessionChildren(int length) {
    return '子: $length';
  }

  @override
  String get chatChooseAgent => 'エージェントを選択';

  @override
  String get chatChooseDirectory => 'ディレクトリを選択';

  @override
  String get chatChooseEffort => '努力レベルを選択';

  @override
  String get chatChooseFolderOpen => 'プロジェクトコンテキストとして開くフォルダーを選択してください。';

  @override
  String get chatChooseModel => 'モデルを選択';

  @override
  String get chatClose => '閉じる';

  @override
  String chatCloseProject(String project) {
    return '$project を閉じる';
  }

  @override
  String get chatCollapseGroup => 'グループを折りたたむ';

  @override
  String get chatCommandDescriptionProject => 'プロジェクトコマンド';

  @override
  String get chatCommandSourceGeneric => 'コマンド';

  @override
  String get chatCommandSourceProject => 'プロジェクト';

  @override
  String get chatCompactContext => 'コンテキストの圧縮';

  @override
  String get chatComposerHintShell => 'シェルコマンド（Escで終了）';

  @override
  String get chatComposerPlaceholder => '要件を入力...';

  @override
  String get chatConversation => '会話';

  @override
  String get chatConversations => '会話一覧';

  @override
  String get chatConversationsPane => '会話一覧';

  @override
  String chatCostLabel(double cost) {
    return 'コスト: \$$cost';
  }

  @override
  String get chatCouldNotRefreshSession => 'この会話を更新できませんでした';

  @override
  String get chatCurrent => '現在値を使用';

  @override
  String chatDescriptionChildren(int count) {
    return '子要素: $count';
  }

  @override
  String get chatDescriptionCloseApp => 'プラットフォームの終了動作を使用してアプリを閉じる';

  @override
  String get chatDescriptionCycleModels => '最近のモデルを切り替える';

  @override
  String get chatDescriptionCycleVariant => 'モデルバリアントを切り替える';

  @override
  String get chatDescriptionDiffFilesZero => '差分ファイル: 0';

  @override
  String get chatDescriptionFocusInput => 'メッセージ入力にフォーカス';

  @override
  String get chatDescriptionFocusOrCloseDrawer => '入力にフォーカス（開いている場合はドロワーを閉じる）';

  @override
  String get chatDescriptionForceExit => 'アプリを強制終了する';

  @override
  String get chatDescriptionNewConversation => '新しい会話';

  @override
  String get chatDescriptionNextAgent => '次のエージェント';

  @override
  String get chatDescriptionOpenProjects => 'このボタンを使用してプロジェクトや会話を開きます。';

  @override
  String get chatDescriptionOpenSettings => '設定を開く';

  @override
  String get chatDescriptionPreviousAgent => '前のエージェント';

  @override
  String get chatDescriptionProjectCommand => 'プロジェクトコマンド';

  @override
  String get chatDescriptionQuickOpen => 'ファイルをクイックオープン';

  @override
  String get chatDescriptionRefreshData => 'チャットデータを更新';

  @override
  String get chatDescriptionStopResponse => 'アクティブな応答を停止（応答中）';

  @override
  String get chatDescriptionSwitchProject =>
      'このボタンを使用してプロジェクトフォルダとコンテキストを切り替えます。';

  @override
  String get chatDescriptionVoiceInput => '音声入力を開始または停止';

  @override
  String get chatDiffFiles => '差分ファイル: 0';

  @override
  String get chatDisplay => '表示設定';

  @override
  String get chatDisplayToggles => '表示トグル';

  @override
  String get chatDoubleESCStop => 'ESCを2回押して停止';

  @override
  String get chatEffortLockedSubConversation => 'サブ会話で努力設定がロックされています';

  @override
  String get chatExpandGroup => 'グループを展開';

  @override
  String get chatExportCanceled => 'セッションのエクスポートがキャンセルされました';

  @override
  String get chatFailedToLoadDirectories => 'ディレクトリの読み込みに失敗しました';

  @override
  String get chatFailedToLoadFile => 'ファイルの読み込みに失敗しました';

  @override
  String get chatFailedToRefreshProviders => 'プロバイダーとモデルの更新に失敗しました';

  @override
  String get chatFailedToRefreshSubConversations => 'サブ会話の更新に失敗しました。再試行してください。';

  @override
  String get chatFailedToStopResponse => '現在のレスポンスの停止に失敗しました';

  @override
  String get chatFileExplorerContents => '内容';

  @override
  String get chatFileExplorerNames => '名前';

  @override
  String get chatFilterActive => 'アクティブ';

  @override
  String get chatFilterAll => 'すべて';

  @override
  String get chatFilterArchived => 'アーカイブ済み';

  @override
  String get chatFilterDirectories => 'ディレクトリをフィルター';

  @override
  String get chatFilterSessions => 'セッションをフィルター';

  @override
  String get chatForkFailed => '会話のフォークに失敗しました';

  @override
  String get chatForked => '会話をフォークしました';

  @override
  String get chatGoToFirst => '最初のメッセージへ移動';

  @override
  String get chatGoToLatest => '最新のメッセージへ移動';

  @override
  String chatGroupMessageCountMessages(
    String compactionLabel,
    String messageCount,
  ) {
    return '$compactionLabel圧縮前に$messageCount件のメッセージが非表示';
  }

  @override
  String get chatHelloAssistant => 'こんにちは！私はあなたのAIアシスタントです';

  @override
  String get chatHelp => 'どのようなご用件でしょうか？';

  @override
  String get chatHelpMessage => '@ でメンション、! でシェル、/ でコマンドを使用します';

  @override
  String get chatHideConversationsSidebar => '会話サイドバーを非表示';

  @override
  String get chatHideUtilitySidebar => 'ユーティリティサイドバーを非表示';

  @override
  String get chatHistoryCollapsed => '以前の履歴は折りたたまれています';

  @override
  String get chatHistoryHideEarlier => '以前のメッセージを非表示';

  @override
  String chatHistoryMessagesHidden(int count, String label) {
    return '$label の圧縮前に $count 件のメッセージが非表示になりました';
  }

  @override
  String get chatHistoryShowEarlier => '以前のメッセージを表示';

  @override
  String get chatKeepWorking => '作業を続ける';

  @override
  String get chatLargeContentSkipped =>
      '安定性のため、サイズの大きいコンテンツまたは不正な形式のコンテンツはスキップされました。';

  @override
  String get chatLatestToolActivity =>
      'チャットの表示領域を安定に保つため、最新のツールアクティビティはこの制限付きパネル内に留まります。';

  @override
  String get chatLoadMore => 'さらに読み込む';

  @override
  String get chatLoadingProjectContext => 'プロジェクトコンテキストを読み込み中...';

  @override
  String get chatMainConversationUnavailable => 'メインの会話はまだ利用できません。';

  @override
  String get chatParentConversationUnavailable => '親の会話はまだ利用できません。';

  @override
  String get chatMentionAgentSubtitle => 'エージェント';

  @override
  String get chatMentionFileSubtitle => 'ファイル';

  @override
  String get chatMentionSymbolSubtitle => '記号';

  @override
  String get chatMessageAttachedFile => '添付ファイル';

  @override
  String get chatMessageDetails => '詳細';

  @override
  String get chatMessageHide => '非表示';

  @override
  String get chatMessageLess => '閉じる';

  @override
  String get chatMessageMessagePartUnavailable => 'メッセージパーツが利用できません';

  @override
  String get chatMessageMetadataAvailable => 'メタデータはありません';

  @override
  String chatMessageModelMessageModelId(String modelId) {
    return 'モデル: $modelId';
  }

  @override
  String get chatMessageMore => 'もっと見る';

  @override
  String get chatMessageOpenFile => 'ファイルを開く';

  @override
  String chatMessageProviderMessageProviderId(String providerId) {
    return 'プロバイダー: $providerId';
  }

  @override
  String get chatMessageRewindEdit => 'ここから巻き戻して編集';

  @override
  String get chatMessageRunningTask => 'タスク実行中';

  @override
  String get chatMessageSaveFile => 'ファイルを保存';

  @override
  String get chatMessageShow => '表示';

  @override
  String get chatMessageShowLess => '表示を減らす';

  @override
  String get chatMessageShowLessCompact => '閉じる';

  @override
  String get chatMessageShowMore => 'もっと表示';

  @override
  String get chatMessageShowMoreCompact => 'もっと見る';

  @override
  String get chatMessageThinking => '思考中';

  @override
  String get chatMessageThinkingProcess => '思考プロセス';

  @override
  String get chatMessageToolCall => '1つのツール呼び出し';

  @override
  String chatMessageToolCalls(int count) {
    return '$countつのツール呼び出し';
  }

  @override
  String get chatMessageToolCommand => 'コマンド';

  @override
  String get chatMessageToolCommandTruncated => '安定性のためコマンドを切り詰めました。';

  @override
  String get chatMessageToolDiffOmitted => '差分は省略されました。ペイロードが大きすぎます。';

  @override
  String get chatMessageToolInput => '入力';

  @override
  String get chatMessageToolInputTruncated => '安定性のため入力を切り詰めました。';

  @override
  String get chatMessageToolOutputTruncated => 'アプリ安定性のため大きな出力を切り詰めました。';

  @override
  String chatMessageToolQueuedCount(int count) {
    return '$count キュー待ち';
  }

  @override
  String chatMessageToolRunningCount(int count) {
    return '$count 実行中';
  }

  @override
  String get chatMessageToolStatusInProgress => '進行中';

  @override
  String get chatMessageToolStatusNeedsAttention => '注意が必要';

  @override
  String get chatMessageToolStatusQueued => 'キュー処理待ち';

  @override
  String get chatMessageYou => 'あなた';

  @override
  String get chatModelLockedSubConversation => 'サブ会話でモデルがロックされています';

  @override
  String get chatNewChat => '新しいチャット';

  @override
  String get chatNewChatTourDescription => 'ここから新しい会話を開始します。';

  @override
  String get chatNewChatTourTitle => '新しいチャット';

  @override
  String get chatNoConversationsInProject => 'このプロジェクトには会話がありません。';

  @override
  String get chatNoServerYet => 'サーバーがまだ設定されていません';

  @override
  String get chatNoSessionSelected => '会話を選択または作成してください';

  @override
  String get chatNoSubConversationFound => 'このタスクのサブ会話は見つかりませんでした。';

  @override
  String get chatOpenFiles => '開いているファイル';

  @override
  String get chatOpenProject => 'プロジェクトを開く';

  @override
  String get chatOpenProjectFolder => 'プロジェクトフォルダーを開く...';

  @override
  String get chatOpenProjectToLoad => 'プロジェクトを開いて会話を読み込んでください。';

  @override
  String get chatOpenSidebar => 'サイドバーを開く';

  @override
  String get chatPageStatusAutomaticCompactionExplanation =>
      '自動圧縮は、コンテキストの使用量が増大したときに行われます。';

  @override
  String get chatPageStatusCompactNow => '今すぐ圧縮';

  @override
  String get chatPageStatusCompacting => '圧縮中...';

  @override
  String get chatPageStatusCompactingContextNow => 'コンテキストを圧縮中...';

  @override
  String get chatPageStatusContextCompacted => 'コンテキストが圧縮されました';

  @override
  String get chatPageStatusContextUsage => 'コンテキスト使用量';

  @override
  String get chatPageStatusCost => 'コスト';

  @override
  String get chatPageStatusFailedToCompactContext => 'コンテキストの圧縮に失敗しました';

  @override
  String get chatPageStatusLimit => '制限';

  @override
  String get chatPageStatusManageServers => 'サーバーを管理';

  @override
  String get chatPageStatusSaver => 'セーバー';

  @override
  String get chatPageStatusServer => 'サーバー';

  @override
  String get chatPageStatusSwitchServer => 'サーバーを切り替え';

  @override
  String get chatPageStatusTokens => 'トークン';

  @override
  String get chatPageStatusUsage => '使用量';

  @override
  String chatPageStatusUsagePercent(int usagePercent) {
    return '$usagePercent';
  }

  @override
  String get chatPermissionAutoApproveOff => '権限の自動承認がオフ';

  @override
  String get chatPermissionAutoApproveOn => '権限の自動承認がオン';

  @override
  String get chatProjectContext => 'プロジェクトコンテキスト';

  @override
  String get chatProjectContext2 => 'プロジェクトコンテキスト';

  @override
  String get chatRealtimeGlobalEvent => 'グローバルイベント';

  @override
  String chatRealtimeGlobalEventReason(String reason) {
    return 'グローバルイベント ($reason)';
  }

  @override
  String get chatRealtimeGlobalEventStale => 'グローバルイベント (古い世代)';

  @override
  String chatRealtimeMessageStreamReason(String reason) {
    return 'メッセージストリーム ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEvent => 'リアルタイムイベント';

  @override
  String chatRealtimeRealtimeEventReason(String reason) {
    return 'リアルタイムイベント ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEventStale => 'リアルタイムイベント (古い世代)';

  @override
  String get chatRealtimeReconnectingServerTry =>
      'サーバーに再接続中。しばらくしてからもう一度お試しください。';

  @override
  String get chatReasoning => '推論中...';

  @override
  String get chatRecentSessions => '最近のセッション';

  @override
  String get chatRecentSessionsToggle => '最近のセッション';

  @override
  String get chatRedoLastTurn => '元に戻した最後のターンをやり直す';

  @override
  String get chatRedoNothing => 'このセッションでやり直す操作はありません';

  @override
  String get chatRefresh => '更新';

  @override
  String get chatRefreshConversation => 'この会話を更新できませんでした';

  @override
  String get chatRefreshProjects => 'プロジェクトを更新';

  @override
  String get chatRefreshSessionDetails => 'セッションの詳細を更新';

  @override
  String chatRemoveDisplayNameHistory(String displayName) {
    return '履歴から$displayNameを削除';
  }

  @override
  String get chatRetry => '再試行';

  @override
  String get chatRetry2 => '再試行';

  @override
  String get chatRetryRefresh => '更新を再試行';

  @override
  String get chatRetryingModelRequest => 'モデルリクエストを再試行中...';

  @override
  String get chatReturnToMainConversation => 'メインの会話に戻る';

  @override
  String get chatReturnToParentConversation => '親の会話に戻る';

  @override
  String get chatReviewChanges => '変更を確認';

  @override
  String get chatSearchConversations => '会話を検索';

  @override
  String get chatSearchNextResult => '次の結果';

  @override
  String get chatSearchNoResults => '結果はありません';

  @override
  String get chatSearchPreviousResult => '前の結果';

  @override
  String chatSearchResultCount(int current, int total) {
    return 'メッセージ $current / $total';
  }

  @override
  String get chatSearchTimeline => 'タイムラインを検索';

  @override
  String get chatSelectDirectory => 'ディレクトリを選択';

  @override
  String get chatSelectOrCreate => 'チャットを開始するには会話を選択するか作成してください';

  @override
  String get chatSelectProjectBelow => '以下からプロジェクトを選択してください。';

  @override
  String get chatServerSelectedModel => 'サーバー選択モデル';

  @override
  String get chatSessionActions => 'セッションアクション';

  @override
  String chatSessionChatSessionSession(String title) {
    return 'チャットセッション: $title';
  }

  @override
  String chatSessionConversationNextAction(String nextAction) {
    return '会話 $nextAction';
  }

  @override
  String get chatSessionConversations => '会話はありません';

  @override
  String get chatSessionCreateConversationStart => '新しい会話を作成してチャットを開始してください';

  @override
  String get chatSessionTabsToggle => 'セッションタブ';

  @override
  String chatSessionsLength(int length) {
    return '$length';
  }

  @override
  String get chatSetUpServer => 'サーバーを設定';

  @override
  String get chatSettings => '設定';

  @override
  String get chatShortcutsCloseApp => 'プラットフォームの終了動作を使用してアプリを閉じる';

  @override
  String get chatShortcutsCycleModels => '最近のモデルを切り替える';

  @override
  String get chatShortcutsCycleVariant => 'モデルバリアントを切り替える';

  @override
  String get chatShortcutsFocusInput => 'メッセージ入力にフォーカス';

  @override
  String get chatShortcutsFocusInputCloseDrawer =>
      '入力にフォーカス（またはドロワーが開いている場合は閉じる）';

  @override
  String get chatShortcutsForceExit => 'アプリを強制終了';

  @override
  String get chatShortcutsNewConversation => '新しい会話';

  @override
  String get chatShortcutsNextAgent => '次のエージェント';

  @override
  String get chatShortcutsOpenSettings => '設定を開く';

  @override
  String get chatShortcutsPreviousAgent => '前のエージェント';

  @override
  String get chatShortcutsQuickOpen => 'ファイルを素早く開く';

  @override
  String get chatShortcutsRefreshChat => 'チャットデータを更新';

  @override
  String get chatShortcutsStartStopVoice => '音声入力の開始または停止';

  @override
  String get chatShortcutsStopResponse => 'アクティブな応答を停止（応答中）';

  @override
  String get chatSidebarAccess => 'サイドバーアクセス';

  @override
  String get chatSortMostRecent => '最新順';

  @override
  String get chatSortOldest => '古い順';

  @override
  String get chatSortRecent => '最近';

  @override
  String get chatSortSessions => 'セッションをソート';

  @override
  String get chatSortTitle => 'タイトル';

  @override
  String get chatStartVoiceInput => '音声入力を開始';

  @override
  String get chatStartingVoiceInput => '音声入力を開始中';

  @override
  String get chatStatusBusy => '状態: 実行中';

  @override
  String get chatStatusPatching => 'パッチ適用中';

  @override
  String chatStatusPatchingMultipleFiles(int count) {
    return '$count個のファイルをパッチ適用中';
  }

  @override
  String get chatStatusPatchingOneFile => '1つのファイルをパッチ適用中';

  @override
  String get chatStatusRetry => '状態: 再試行';

  @override
  String chatStatusRetryCount(int count) {
    return '状態: 再試行 #$count';
  }

  @override
  String get chatStatusSubsession => 'サブセッション';

  @override
  String get chatStatusThinking => '思考中...';

  @override
  String get chatStopVoiceInput => '音声入力を停止';

  @override
  String chatSyncLabel(String label) {
    return '同期: $label';
  }

  @override
  String get chatTasks => 'タスク';

  @override
  String get chatTasksAvailableSession => 'このセッションで利用可能なタスクはありません。';

  @override
  String get chatTipAcceptanceCriteria => 'ヒント: 大きな変更には受け入れ条件を追加しましょう';

  @override
  String get chatTipAskForPlan => 'ヒント: 大きなタスクでは先に計画を依頼しましょう';

  @override
  String get chatTipBeSpecific => 'ヒント: 具体的に — 短いプロンプトほど早く回答が得られます';

  @override
  String get chatTipBreakTasks => 'ヒント: 大きなタスクを小さなプロンプトに分割します';

  @override
  String get chatTipCompareOptions => 'ヒント: トレードオフが不明なら代替案を依頼しましょう';

  @override
  String get chatTipContextKnob => 'ヒント: コンテキストノブをタップして使用状況の詳細を表示します';

  @override
  String get chatTipDefineVerification => 'ヒント: 通すべきテストやチェックを伝えましょう';

  @override
  String get chatTipLongPressSend => 'ヒント: 送信を長押しして改行を挿入します';

  @override
  String get chatTipMentionFiles => 'ヒント: プロンプトで @ を使用してファイルに言及します';

  @override
  String get chatTipNameRelevantFiles => 'ヒント: 関連するファイル、画面、コマンドを伝えましょう';

  @override
  String get chatTipProvideContext => 'ヒント: コンテキストを提供 — エラーメッセージやログを貼り付けます';

  @override
  String get chatTipRenameConversation => 'ヒント: タイトルをタップして会話の名前を変更します';

  @override
  String get chatTipRequestDocs => 'ヒント: 挙動が変わるなら docs 更新を依頼しましょう';

  @override
  String get chatTipShareAttempts => 'ヒント: 試したことと正確なエラーを共有しましょう';

  @override
  String get chatTipShellCommands => 'ヒント: 行頭で ! を使用してシェルコマンドを実行します';

  @override
  String get chatTipSlashCommands => 'ヒント: / を使用してスラッシュコマンドにアクセスします';

  @override
  String get chatTipStartWithGoal => 'ヒント: 最終目標から始めましょう';

  @override
  String get chatTipStateConstraints => 'ヒント: エージェントが守る制約を伝えましょう';

  @override
  String get chatTipStepByStep => 'ヒント: 複雑な問題のデバッグ時はステップバイステップで依頼します';

  @override
  String get chatTipUseFocusedAgents => 'ヒント: 計画、レビュー、実装に合うエージェントを選びましょう';

  @override
  String get chatToggleSidebars => 'サイドバーを切り替え';

  @override
  String chatTokensLabel(int total) {
    return 'トークン: $total';
  }

  @override
  String get chatTourProjectsConversations => 'このボタンを使用してプロジェクトや会話を開きます。';

  @override
  String get chatTourSidebarProjectTools =>
      'このメニューを使用して会話サイドバーやプロジェクトツールを表示します。';

  @override
  String get chatTourSwitchFolders => 'このボタンを使用してプロジェクトフォルダやコンテキストを切り替えます。';

  @override
  String get chatUndoLastTurn => '最後のターンを元に戻す';

  @override
  String get chatUndoNothing => 'このセッションで元に戻す操作はありません';

  @override
  String get chatUseCurrent => '現在値を使用';

  @override
  String get chatWaitingForNetworkConnection => 'ネットワーク接続を待機中...';

  @override
  String get chatWelcomeMessage => 'こんにちは！私はあなたのAIアシスタントです。';

  @override
  String get chatWelcomeSubmessage => '今日はどのようなご用件ですか？';

  @override
  String get chatWorkBoundedPanelExplanation =>
      'チャットの表示領域を安定に保つため、最新のツールアクティビティはこの制限付きパネル内に留まります。';

  @override
  String get chatWorkExpand => '展開';

  @override
  String get chatWorkHide => '非表示';

  @override
  String get chatWorkMessageOne => '1件の作業メッセージ';

  @override
  String chatWorkMessagesMultiple(int count) {
    return '$count件の作業メッセージ';
  }

  @override
  String get chatWorkShow => '表示';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonCopiedToClipboard => 'クリップボードにコピーしました';

  @override
  String get commonDelete => '削除';

  @override
  String get commonFile => 'ファイル';

  @override
  String get commonReset => 'リセット';

  @override
  String get commonSave => '保存';

  @override
  String get compactionAutomatic => '自動';

  @override
  String get compactionManual => '手動';

  @override
  String get composerAddAttachment => '添付ファイルを追加';

  @override
  String get composerAttachFiles => 'ファイルを添付';

  @override
  String get composerCannedAppendAtCursor => 'カーソル位置に追加';

  @override
  String get composerCannedLabel => 'ラベル（任意）';

  @override
  String get composerCannedNoReplies => 'クイック返信はまだありません。';

  @override
  String get composerCannedReplace => '置換';

  @override
  String get composerCannedSave => '保存';

  @override
  String get composerCannedScopeGlobal => 'グローバル';

  @override
  String get composerCannedScopeProject => 'プロジェクト限定';

  @override
  String get composerCannedSendAutomatically => '自動送信';

  @override
  String get composerCannedText => 'テキスト';

  @override
  String get composerChatInput => 'チャット入力';

  @override
  String get composerDeleteAction => '削除';

  @override
  String get composerDropHint => '画像やPDFをドロップして添付';

  @override
  String get composerPastedImageName => '貼り付けた画像';

  @override
  String get composerEdit => '編集';

  @override
  String get composerExtras => 'その他';

  @override
  String get composerExtrasHide => 'その他を隠す';

  @override
  String get composerNewQuickReply => '新規クイック返信';

  @override
  String get composerSelectImages => '画像を選択';

  @override
  String get composerSelectPdf => 'PDF を選択';

  @override
  String get composerSend => '送信';

  @override
  String get composerShellMode => 'シェルモード';

  @override
  String get desktopWindowClose => '閉じる';

  @override
  String get desktopWindowMaximize => '最大化';

  @override
  String get desktopWindowMinimize => '最小化';

  @override
  String get desktopWindowRestore => '元のサイズに戻す';

  @override
  String get dialogDownload => 'ダウンロード';

  @override
  String get dialogLanguage => '言語';

  @override
  String get dialogMoonshineModelSize => 'モデルサイズ';

  @override
  String get dialogMoonshineVoiceSetup => 'Moonshine 音声セットアップ';

  @override
  String get dialogParakeetModel => 'Parakeet モデル';

  @override
  String get dialogParakeetVoiceSetup => 'Parakeet 音声セットアップ';

  @override
  String get dialogSenseVoiceModel => 'SenseVoice モデル';

  @override
  String get dialogSenseVoiceSetup => 'SenseVoice セットアップ';

  @override
  String get dialogVoiceInputSetup => '音声入力セットアップ';

  @override
  String get errorAnErrorOccurred => 'エラーが発生しました';

  @override
  String get errorAuthRequired => '認証が必要です';

  @override
  String get errorAuthRequiredDesc => '認証に失敗しました。プロバイダーを再接続して、もう一度お試しください。';

  @override
  String get errorConnectionFailed => '接続に失敗しました';

  @override
  String get errorConnectionFailedDesc => 'サーバーに接続できません。接続とサーバーの状態を確認してください。';

  @override
  String get errorFormatAuthenticationFailedReconnect =>
      '認証に失敗しました。プロバイダーを再接続して再試行してください。';

  @override
  String get errorFormatProviderTemporarilyUnavailable =>
      'プロバイダーが一時的に利用できません。しばらくしてから再試行してください。';

  @override
  String get errorFormatQuotaExceededCheck =>
      '制限（クォータ）を超過しました。プロバイダーのプランまたは請求情報を確認してください。';

  @override
  String get errorFormatRateLimitExceeded => 'レート制限を超過しました。しばらく待ってから再試行してください。';

  @override
  String get errorFormatServerErrorPlease => 'サーバーエラーが発生しました。もう一度お試しください。';

  @override
  String get errorFormatServiceTemporarilyUnavailable =>
      'サービスが一時的に利用できません。サーバーが起動中の可能性があります。しばらくしてから再試行してください。';

  @override
  String get errorFormatUnableReachServer =>
      'サーバーに接続できません。接続とサーバーのステータスを確認してください。';

  @override
  String get errorProviderUnavailable => 'プロバイダーを利用できません';

  @override
  String get errorProviderUnavailableDesc =>
      'プロバイダーが一時的に利用できません。しばらくしてからもう一度お試しください。';

  @override
  String get errorQuotaExceeded => 'クォータを超過しました';

  @override
  String get errorQuotaExceededDesc => 'クォータを超過しました。プロバイダーのプランまたは請求を確認してください。';

  @override
  String get errorRateLimitExceeded => 'レート制限を超過しました';

  @override
  String get errorRateLimitExceededDesc => 'レート制限を超過しました。しばらく待ってからもう一度お試しください。';

  @override
  String get errorServerError => 'サーバーエラー';

  @override
  String get errorServerErrorDesc => 'サーバーエラーが発生しました。もう一度お試しください。';

  @override
  String get errorServiceUnavailable => 'サービスを利用できません';

  @override
  String get errorServiceUnavailableDesc =>
      'サービスは一時的に利用できません。サーバーが起動中の可能性があります。しばらくしてからもう一度お試しください。';

  @override
  String get fileActionAttachmentDataDecoded => '添付ファイルデータをデコードできませんでした。';

  @override
  String get fileActionAttachmentPathEmpty => '添付ファイルのパスが空です。';

  @override
  String get fileActionAttachmentPayloadEmpty => '添付ファイルのペイロードが空です。';

  @override
  String get fileActionAttachmentProvideValid => '添付ファイルが有効な場所を指していません。';

  @override
  String get fileActionAttachmentSavedDevice => '添付ファイルをこのデバイスに保存できませんでした。';

  @override
  String fileActionAttachmentSavedOutputFile(String path) {
    return '添付ファイルを$pathに保存して開きました。';
  }

  @override
  String fileActionAttachmentSavedOutputFile2(String path) {
    return '添付ファイルを$pathに保存しました。';
  }

  @override
  String fileActionAttachmentSavedSavedPath(String savedPath) {
    return '添付ファイルを$savedPathに保存しました。';
  }

  @override
  String get fileActionLocalAttachmentFound => 'ローカルの添付ファイルがこのデバイスで見つかりませんでした。';

  @override
  String get fileActionSaveCanceled => '保存がキャンセルされました。';

  @override
  String get fileActionUnableOpenLocal => 'ローカルの添付ファイルを開けませんでした。';

  @override
  String get filesAddChat => 'チャットに追加';

  @override
  String get filesAutosave => '自動保存';

  @override
  String get filesAutosaveOn => '自動保存オン';

  @override
  String get filesAutosaveOff => '自動保存オフ';

  @override
  String get filesRedo => 'やり直す';

  @override
  String get filesUndo => '元に戻す';

  @override
  String get filesBinaryFilePreview => 'バイナリファイルのプレビューは利用できません。';

  @override
  String get filesClear => 'クリア';

  @override
  String get filesContents => 'コンテンツ';

  @override
  String get filesDuplicate => '複製';

  @override
  String get filesDuplicated => 'ファイルを複製しました';

  @override
  String get filesFileEmpty => 'ファイルは空です。';

  @override
  String get filesAlreadyExists => 'その名前のファイルまたはフォルダーは既に存在します。';

  @override
  String get filesCopyPath => 'パスをコピー';

  @override
  String get filesCreateFileTitle => 'ファイルを作成';

  @override
  String get filesCreateFolderTitle => 'フォルダーを作成';

  @override
  String get filesDelete => '削除';

  @override
  String filesDeleteConfirm(String name) {
    return '「$name」を削除しますか？この操作は元に戻せません。フォルダーは中身ごと削除されます。';
  }

  @override
  String filesDeleteTitle(String name) {
    return '「$name」を削除';
  }

  @override
  String get filesFilesFound => 'ファイルが見つかりません';

  @override
  String get filesFileCreated => 'ファイルを作成しました。';

  @override
  String get filesFolderCreated => 'フォルダーを作成しました。';

  @override
  String get filesHideSidebar => 'ファイルサイドバーを非表示';

  @override
  String get filesInvalidName => 'パス区切り文字を含まない有効な名前を入力してください。';

  @override
  String get filesNameHint => '名前';

  @override
  String get filesNew => '新規';

  @override
  String get filesNewFile => '新しいファイル';

  @override
  String get filesNewFolder => '新しいフォルダー';

  @override
  String get filesNames => '名前';

  @override
  String filesOpenFilesFileState(int length) {
    return '開いているファイル ($length)';
  }

  @override
  String get filesQuickOpen => 'クイックオープン';

  @override
  String get filesQuickOpenFile => 'ファイルをクイックオープン';

  @override
  String get filesOperationFailed => 'ファイル操作に失敗しました。';

  @override
  String get filesOperationUnavailable => 'このサーバーではファイル操作を利用できません。';

  @override
  String get filesOutsideRoot => 'パスがプロジェクトルートの外にあります。';

  @override
  String get filesPathCopied => 'パスをコピーしました。';

  @override
  String get filesPathMissing => 'パスが存在しません。';

  @override
  String get filesPermissionDenied => '権限がありません。';

  @override
  String get filesRefresh => 'ファイルを更新';

  @override
  String get filesRename => '名前を変更';

  @override
  String filesRenameTitle(String name) {
    return '「$name」の名前を変更';
  }

  @override
  String get filesRenamed => '名前を変更しました。';

  @override
  String get filesRootDeleteBlocked => 'プロジェクトのルートは削除できません。';

  @override
  String get filesSearchHint => '名前またはパスでファイルを検索';

  @override
  String get filesDeleted => '削除しました。';

  @override
  String get filesTitle => 'ファイル';

  @override
  String get forwardAction => '転送';

  @override
  String get forwardAllFailed => 'どのセッションにも転送できませんでした';

  @override
  String get forwardCancel => 'キャンセル';

  @override
  String get forwardDialogSubtitle => '1つ以上の会話を選択';

  @override
  String get forwardDialogTitle => '転送先…';

  @override
  String get forwardLoading => 'セッションを読み込み中…';

  @override
  String get forwardNoOpenProjects => 'セッションのある開いているプロジェクトがありません';

  @override
  String get forwardNoProviderModel => '転送する前にプロバイダーとモデルを選択してください';

  @override
  String get forwardNoSessions => '最近のセッションがありません';

  @override
  String forwardPartial(int success, int total) {
    return '$total件中$success件に転送しました';
  }

  @override
  String forwardProvenanceLabel(String origin) {
    return '転送元: $origin';
  }

  @override
  String get forwardRetry => '再試行';

  @override
  String get forwardSearchHint => '検索';

  @override
  String forwardSelectedCount(int count) {
    return '$count件選択中';
  }

  @override
  String get forwardSend => '転送';

  @override
  String get forwardServerOffline => 'サーバーがオフラインです';

  @override
  String get forwardShortcutHint => 'Ctrl+Shift+F';

  @override
  String forwardSuccess(int count) {
    return '$count件のセッションに転送しました';
  }

  @override
  String get forwardUndo => '元に戻す';

  @override
  String get forwardUndoFailed => '転送を元に戻せませんでした';

  @override
  String get logsAppLogs => 'アプリログ';

  @override
  String get logsClear => 'ログをクリア';

  @override
  String get logsCloseSearch => '検索を閉じる';

  @override
  String get logsCopyFiltered => 'コピーフィルター済みログ';

  @override
  String get logsEnableLogging => 'アプリログを有効化';

  @override
  String get logsEnableLoggingAction => 'ログを有効化';

  @override
  String get logsEnableLoggingDescription =>
      'メモリ内に診断ログを収集します。トラブルシュート時以外はオフのままにしてください。';

  @override
  String get logsEntryContext => 'コンテキスト';

  @override
  String get logsEntryTags => 'タグ';

  @override
  String get logsFilterAll => 'すべて';

  @override
  String get logsFilterByTag => 'タグ';

  @override
  String get logsLevel => 'レベル';

  @override
  String get logsLoggingDisabledDescription =>
      'CodeWalk は詳細なアプリログを収集していません。診断が必要な場合のみログを有効にしてください。';

  @override
  String get logsLoggingDisabledTitle => 'ログは無効です';

  @override
  String get logsMeasurePerformance => 'パフォーマンスを測定';

  @override
  String get logsMeasurePerformanceDescription =>
      '重いアプリ操作の所要時間を記録します。遅延診断時以外はオフにしてください。';

  @override
  String get logsNoLogsYet => 'ログはまだ記録されていません。';

  @override
  String get logsNoMatchingLogs => '現在のフィルタに一致するログはありません。';

  @override
  String get logsNoPerformanceData => '現在のフィルターに一致するパフォーマンスログはありません。';

  @override
  String get logsNoTaskData => '現在のフィルターに一致するタスクはありません。';

  @override
  String logsPerformanceDuration(int elapsedMs) {
    return '$elapsedMs ms';
  }

  @override
  String get logsPerformanceFilter => 'パフォーマンス';

  @override
  String logsPerformanceTileTitle(
    int elapsedMs,
    String operation,
    String status,
  ) {
    return 'パフォーマンス $operation | $elapsedMs ms | $status';
  }

  @override
  String get logsSearch => 'ログを検索';

  @override
  String logsShowingOrderedLength(int length, int length2) {
    return '$length2件中$length件のエントリを表示';
  }

  @override
  String get logsSlowestPerformance => '最も遅いパフォーマンスログ';

  @override
  String get logsSlowestTasks => '最も遅いタスク';

  @override
  String get logsTagCustomHint => 'タグ名（例: task:select_session）';

  @override
  String get logsTagCustomAction => 'カスタム...';

  @override
  String logsTaskDuration(int elapsedMs, String operation) {
    return '$operation — $elapsedMs ms';
  }

  @override
  String get logsTaskStatusCanceled => 'キャンセル済み';

  @override
  String get logsTaskStatusError => 'エラー';

  @override
  String get logsTaskStatusOk => 'ok';

  @override
  String get logsTimeRange => '時間範囲';

  @override
  String get mathExpressionLabel => '数式';

  @override
  String get mermaidCopySourceTooltip => 'ソースをコピー';

  @override
  String get mermaidDiagramLabel => 'Mermaidダイアグラム';

  @override
  String get modelAuto => '自動';

  @override
  String get modelChooseAgent => 'エージェントを選択';

  @override
  String get modelFavorites => 'お気に入り';

  @override
  String get modelFree => '無料';

  @override
  String get modelLabelBaseEnglish => 'ベース (英語)';

  @override
  String get modelLabelParakeet => 'Parakeet V3 (欧州25言語)';

  @override
  String get modelLabelSenseVoice => 'SenseVoice (zh/en/ja/ko/yue)';

  @override
  String get modelLabelTinyEnglish => 'Tiny (英語)';

  @override
  String get modelLoadingModels => 'モデルを読み込み中';

  @override
  String get modelModelsFound => 'モデルが見つかりません';

  @override
  String get modelRetryModels => 'モデル読み込みを再試行';

  @override
  String get modelSearchHint => 'モデルまたはプロバイダーを検索';

  @override
  String get msgBatterySettingsFailed => 'Android バッテリー最適化設定を開けませんでした。';

  @override
  String get msgBatterySettingsOpened =>
      'Android バッテリー設定が開かれました。CodeWalk のバッテリー使用制限を「制限なし」にしてください。';

  @override
  String get msgClearUsernameNeedsConfigEdit =>
      'OpenCode 会話ユーザー名をクリアするには、依然としてアプリ外で設定を編集する必要があります。';

  @override
  String get msgCommandCopied => 'コマンドがコピーされました';

  @override
  String get msgCopiedToClipboard => 'クリップボードにコピーされました';

  @override
  String get msgEnterUsernameToSave =>
      'カスタムの OpenCode 会話名を保存するにはユーザー名を入力してください。';

  @override
  String get msgFailedToSendMessage => 'メッセージの送信に失敗しました。下書きは再試行用に保存されます。';

  @override
  String get msgFailedToStartVoiceInput => '音声入力の開始に失敗しました';

  @override
  String msgFilePathNotFound(String path) {
    return 'ファイルが見つかりません: $path';
  }

  @override
  String get msgFilteredLogsCopied => 'フィルター済みログがクリップボードにコピーされました';

  @override
  String get msgInfoAgent => 'エージェント';

  @override
  String get msgInfoCompaction => '圧縮';

  @override
  String msgInfoCost(String cost) {
    return 'コスト: \$$cost';
  }

  @override
  String get msgInfoMessageInfo => 'メッセージ情報';

  @override
  String msgInfoModel(String modelId) {
    return 'モデル: $modelId';
  }

  @override
  String get msgInfoNoMetadata => 'メタデータはありません';

  @override
  String msgInfoPartDescriptionModel(String description, String model) {
    return '$description$model';
  }

  @override
  String get msgInfoPatch => 'パッチ';

  @override
  String msgInfoProvider(String providerId) {
    return 'プロバイダー: $providerId';
  }

  @override
  String get msgInfoRetry => '再試行';

  @override
  String get msgInfoSnapshot => 'スナップショット';

  @override
  String msgInfoSubtaskPartAgent(String agent) {
    return 'サブタスク ($agent)';
  }

  @override
  String msgInfoTokens(int total) {
    return 'トークン: $total';
  }

  @override
  String get msgInfoUndoThisTurn => 'このターンを元に戻す';

  @override
  String get msgInfoView => '表示';

  @override
  String get msgNoSystemSoundsFound => 'このデバイスでシステムサウンドが見つかりませんでした。';

  @override
  String get msgNoValidFilesSelected => '有効なファイルが選択されませんでした';

  @override
  String get msgSomeSelectedFilesNotAttached => '一部の選択したファイルを添付できませんでした。';

  @override
  String get msgReadAloud => '音声読み上げ';

  @override
  String get msgReadAloudNotAvailable => 'このデバイスでは音声合成（TTS）が利用できません。';

  @override
  String get msgSetupDebugCopied => 'OpenCode セットアップデバッグ情報がクリップボードにコピーされました';

  @override
  String get msgShareAsImage => '画像として共有';

  @override
  String get msgShareAsImageFailed => 'メッセージを画像として共有できませんでした。';

  @override
  String get msgShareAsImageSubject => 'CodeWalk メッセージ';

  @override
  String get msgShareAsImageTooTall => 'メッセージが長すぎるため、画像として共有できません。';

  @override
  String get msgStopReadAloud => '読み上げを停止';

  @override
  String get msgSystemSoundPickerUnavailable =>
      'システムサウンドピッカーはこのプラットフォームで利用できません。';

  @override
  String get msgUpdatedButRefreshFailed =>
      'サーバー設定を更新しましたが、チャットプロバイダーを更新できませんでした。';

  @override
  String get msgVoiceInputUnavailable => 'このデバイスでは音声入力が利用できません';

  @override
  String get notifAndroidBatteryOptimization => 'Androidバッテリー最適化';

  @override
  String get notifConversationUpdates => '会話の更新';

  @override
  String get notifNotificationsArriveReopening =>
      'アプリを再開したときにしか通知が届かない場合は、CodeWalk がこのデバイスで最適化なしで実行できるように許可してください。';

  @override
  String get notifResponseRunningKeep =>
      'レスポンスが実行されている場合、アプリを離れた後も短時間リアルタイム通信を有効に保ちます。';

  @override
  String notifSelectedSoundLabel(String soundLabel) {
    return '選択済み: $soundLabel';
  }

  @override
  String get notificationAgentFinished => 'エージェントが現在の応答を完了しました。';

  @override
  String get notificationConversationUpdates => '会話の更新';

  @override
  String get notificationOpenToClear => '関連する通知を消去するには、この会話を開いてください。';

  @override
  String get notificationSession => 'セッション';

  @override
  String get notificationSoundLoadFailed => 'Androidシステムサウンドの読み込みに失敗しました';

  @override
  String get onboardingAIGeneratedTitles => 'AI生成タイトル';

  @override
  String get onboardingAddServerLater => 'サーバーは後で [設定] > [サーバー] から追加できます。';

  @override
  String get onboardingAddedButHealthCheckFailed =>
      'サーバーが追加されましたが、ヘルスチェックに失敗しました。まだ起動中の可能性があります。';

  @override
  String get onboardingAlmostInstallOpenCode =>
      'あと少しです。まず OpenCode をインストールし、次に CodeWalk をサーバー URL に接続してください。';

  @override
  String onboardingAppProviderLocalSetupLogsLength(int length, int length2) {
    return '$length件のセットアップログ行と$length2件のセットアップイベントが別のセットアップデバッグ画面で利用できます。';
  }

  @override
  String get onboardingAuthenticate => '認証';

  @override
  String get onboardingAvailable => '利用可能';

  @override
  String get onboardingAvailableOnlyDesktop =>
      'デスクトップ（Linux/macOS/Windows）でのみ利用可能です。';

  @override
  String get onboardingBasicAuthTip =>
      'OpenCode サーバーがパスワードで保護されている場合のみ、基本認証を有効にしてください。';

  @override
  String get onboardingChooseAnotherPath => '別のパスを選択';

  @override
  String get onboardingChooseHowToSetup => 'サーバーのセットアップ方法を選択してください';

  @override
  String get onboardingClear => 'クリア';

  @override
  String get onboardingCloudflareAuthFailed => 'Cloudflare Access の認証に失敗しました。';

  @override
  String get onboardingCodeWalkAppOpenCode =>
      'CodeWalk はアプリであり、OpenCode は接続先となるエンジンです。';

  @override
  String get onboardingConnectRunningServer => '実行中のサーバーに接続';

  @override
  String get onboardingConnectionIssue => '接続の問題';

  @override
  String get onboardingConnectionSaved => 'サーバー接続が正常に保存されました。';

  @override
  String get onboardingConnectionTips => '接続のヒント';

  @override
  String get onboardingConnectionUpdated => 'サーバー接続が正常に更新されました。';

  @override
  String get onboardingContinue => '続行';

  @override
  String get onboardingContinueServerURL => 'サーバーURLへ進む';

  @override
  String get onboardingCopyLoginURL => 'ログインURLをコピー';

  @override
  String get onboardingCouldNotVerify => 'サーバー接続を確認できませんでした。';

  @override
  String get onboardingDefaultURLEmulator =>
      'デフォルトURL、エミュレータのループバック、認証、およびデバッグのヘルプ。';

  @override
  String onboardingDesktopOnlyDiagnose(String appName) {
    return 'デスクトップのみ: $appName は OpenCode の診断、インストール、実行を代行できます。';
  }

  @override
  String get onboardingDetailedSetupEvents =>
      'トラブルシューティング用に、詳細なセットアップイベントがキャプチャされました。';

  @override
  String get onboardingDonShowAgain => '再表示しない';

  @override
  String get onboardingDone => '完了';

  @override
  String get onboardingEditServer => 'サーバーを編集';

  @override
  String get onboardingEditServerConnection => 'サーバー接続を編集';

  @override
  String get onboardingEmulatorRemap =>
      'Android エミュレーターでは、localhost と 127.0.0.1 は自動的に 10.0.2.2 にリマップされます。';

  @override
  String get onboardingEnterServerUrl => 'サーバーの URL を入力';

  @override
  String get onboardingExisting => '既存のものを使用';

  @override
  String get onboardingExplainInstallOpenCode =>
      'OpenCode をインストールし、サーバーを起動し、CodeWalk から接続する方法を説明します。';

  @override
  String get onboardingFailed => '失敗';

  @override
  String get onboardingGoodOptionDesktop => 'デスクトップでの推奨される最初のオプション';

  @override
  String get onboardingHealthCheckFailedMayBeStarting =>
      'サーバーのヘルスチェックに失敗しました。まだ起動中の可能性があります。';

  @override
  String get onboardingInstallBinary => 'バイナリをインストール';

  @override
  String get onboardingInstallBun => 'Bun経由でインストール';

  @override
  String get onboardingInstallBunOpenCode => 'Bun + OpenCode をインストール';

  @override
  String get onboardingInstallNpm => 'npm経由でインストール';

  @override
  String get onboardingInstallRunOpenCode =>
      'デスクトップ上の CodeWalk から直接 OpenCode をインストールして実行します。';

  @override
  String get onboardingInvalidUrl => '無効な URL';

  @override
  String get onboardingLabel => 'ラベル（任意）';

  @override
  String get onboardingLabelHint => 'マイサーバー';

  @override
  String onboardingLatestOutputAppProvider(String localServerLastOutput) {
    return '最新の出力: $localServerLastOutput';
  }

  @override
  String get onboardingLetCodeWalkSet => 'CodeWalkにローカルでセットアップさせる';

  @override
  String get onboardingLocalServerSetup => 'ローカルサーバーのセットアップ';

  @override
  String get onboardingManagedLocalServer => '管理されたローカルサーバー';

  @override
  String get onboardingManagedLocalServer2 =>
      '管理ローカルサーバーモードはデスクトップビルド（Linux/macOS/Windows）でのみ利用可能です。';

  @override
  String onboardingNeedsOpenCodeServer(String appName) {
    return '$appName がコードの支援を行うには、OpenCode サーバーが必要です。';
  }

  @override
  String get onboardingNotAvailable => '利用不可';

  @override
  String get onboardingNotWritable => '書き込み不可';

  @override
  String get onboardingOpenCode => 'OpenCodeとは？';

  @override
  String get onboardingOpenCodeRunningDevice =>
      'このデバイスまたはネットワーク上のどこかで、すでに OpenCode を実行しています。';

  @override
  String get onboardingOpenCodeRunsLocally =>
      'OpenCode はローカルまたはサーバー上で実行され、CodeWalk 内の AI コーディング機能を強化します。すでに OpenCode が実行されている場合は、それに接続してください。実行されていない場合は、以下のガイド付きセットアップパスのいずれかを選択してください。';

  @override
  String get onboardingOpenTailscaleLogin => 'Tailscale ログイン URL を開けませんでした。';

  @override
  String get onboardingPassword => 'パスワード';

  @override
  String get onboardingPasswordRequired => 'パスワードを入力';

  @override
  String get onboardingPickSetupPath =>
      '現在の OpenCode セットアップに一致するセットアップパスを選択してください。';

  @override
  String get onboardingPreconditionDirectoryNotWritable =>
      'インストールディレクトリが書き込み禁止です。ユーザー権限を確認してください。';

  @override
  String get onboardingPreconditionInstallViaBunRecommendation =>
      'OpenCodeのメンテナーはBun経由でのインストールを推奨しています。';

  @override
  String get onboardingPreconditionNetworkFailed =>
      'ネットワークアクセスに失敗しました。OpenCodeをインストールする前に接続を確認してください。';

  @override
  String get onboardingPreconditionNoRuntimeDetected =>
      'ランタイムが検出されませんでした。OpenCodeバイナリを直接インストールするか、まずBunをセットアップしてください。';

  @override
  String get onboardingPreconditionNodeNpmAvailable =>
      'Nodeとnpmが利用可能です。npm経由でOpenCodeをインストールするか、推奨される手順のためにBunをインストールしてください。';

  @override
  String get onboardingPreconditionOpenCodeAlreadyAvailable =>
      'OpenCodeは既に利用可能です。検出されたコマンドをすぐに使用できます。';

  @override
  String get onboardingPreconditionWindowsPathLagHint =>
      ' Windowsでは、既に開いているアプリでPATHの更新が遅れる場合があるため、インストール後に確認を再実行してください。';

  @override
  String get onboardingPreconditionWindowsWslRecommendation =>
      'Windowsビルドが検出されました。OpenCodeのドキュメントではWSLが推奨されていますが、代替手段としてnpm installを使用することもできます。';

  @override
  String get onboardingReachable => '到達可能';

  @override
  String get onboardingReady => '準備完了';

  @override
  String get onboardingRecommendedOrderTry =>
      '推奨される順序: CodeWalk がすべてをブートストラップするようにしたい場合は [Bun + OpenCode をインストール] を試してください。OpenCode がすでにインストールされている場合は [既存のものを使用] を使用します。';

  @override
  String get onboardingRefreshChecks => '検出チェックを更新';

  @override
  String get onboardingRunDiagnosticsToVerify =>
      'ローカルの OpenCode 要件を確認するために診断を実行してください。';

  @override
  String get onboardingSaveAndTest => '保存してテスト';

  @override
  String get onboardingServerConnectedReady => 'サーバーが接続され、使用準備が整いました。';

  @override
  String get onboardingServerConnection => 'サーバー接続';

  @override
  String get onboardingServerSettingsSaved => 'サーバー設定が保存され、ヘルスチェックが更新されました。';

  @override
  String get onboardingServerSetup => 'サーバーセットアップ';

  @override
  String get onboardingServerUpdated => 'サーバーが更新されました';

  @override
  String get onboardingServerUrl => 'サーバーURL';

  @override
  String get onboardingSetup => 'セットアップ';

  @override
  String get onboardingSetupWizard => 'セットアップウィザード';

  @override
  String get onboardingShowSetupSteps => 'セットアップ手順を表示する';

  @override
  String get onboardingShowSetupSteps2 => 'セットアップ手順を表示';

  @override
  String get onboardingSkip => '今はスキップする';

  @override
  String get onboardingSkipSetup => 'セットアップをスキップしますか？';

  @override
  String get onboardingStart => '開始';

  @override
  String onboardingStartUsing(String appName) {
    return '$appName を使い始める';
  }

  @override
  String get onboardingStarting => '起動中';

  @override
  String get onboardingStop => '停止';

  @override
  String get onboardingStopped => '停止';

  @override
  String get onboardingStopping => '停止中';

  @override
  String onboardingSuggestedUrl(String url) {
    return '推奨されるローカル OpenCode サーバー URL: $url';
  }

  @override
  String get onboardingTailscaleAdminApproval => 'Tailscale 管理者の承認が必要です';

  @override
  String get onboardingTailscaleAuthAfterSave => '保存後に Tailscale の認証が行われます';

  @override
  String onboardingTailscaleAuthAfterSaveTest(String appName) {
    return 'このサーバーを保存してテストした後、このデバイスがまだ認証されていない場合は、$appName が Tailscale のログイン画面を開きます。';
  }

  @override
  String get onboardingTailscaleConnected => 'Tailscale 接続済み';

  @override
  String get onboardingTailscaleConnecting => 'Tailscale 接続中';

  @override
  String get onboardingTailscaleConnectionFailed => 'Tailscale 接続失敗';

  @override
  String get onboardingTailscaleLoginRequired => 'Tailscale へのログインが必要です';

  @override
  String get onboardingTailscaleOpenLoginUrl =>
      'ログイン URL を開いて、このデバイスを tailnet に追加してください。ブラウザが開かなかった場合は、以下の URL をコピーしてください。';

  @override
  String get onboardingTailscaleUnsupported => 'Tailscale 非サポート';

  @override
  String get onboardingTestConnection => '接続をテスト';

  @override
  String get onboardingTesting => 'テスト中...';

  @override
  String get onboardingUnreachable => '到達不能';

  @override
  String get onboardingUseBasicAuth => '基本認証（Basic Auth）を使用';

  @override
  String get onboardingUsername => 'ユーザー名';

  @override
  String get onboardingUsernameRequired => 'ユーザー名を入力';

  @override
  String get onboardingUsesServerTitle => 'サーバーのタイトルエージェントを使用して会話に名前を付けます';

  @override
  String get onboardingUsingDetectedCommand => '検出された OpenCode コマンドを使用しています。';

  @override
  String get onboardingViewSetupDebug => 'セットアップデバッグを表示';

  @override
  String onboardingWelcomeTo(String appName) {
    return '$appName へようこそ';
  }

  @override
  String get onboardingWindowsTipInstalling =>
      'Windowsのヒント: インストール後、[検出チェックを更新] をクリックします。それでも検出に失敗する場合は、CodeWalk を再起動して PATH の変更を再読み込みしてください。';

  @override
  String get onboardingWritable => '書き込み可能';

  @override
  String get onboardingYoureAllSet => '準備が整いました！';

  @override
  String get permissionAllowOnce => '1回のみ許可';

  @override
  String get permissionAlways => '常に許可';

  @override
  String get permissionBack => '戻る';

  @override
  String get permissionConfirmReject => '拒否の確認';

  @override
  String get permissionReject => '拒否';

  @override
  String get permissionReopen => '再開';

  @override
  String get questionAnswerSelected => '回答が選択されていません。';

  @override
  String get questionCommaSeparatedValues => 'カンマ区切り値';

  @override
  String get questionQuestionGroupMarked =>
      '質問グループが拒否としてマークされました。チャットを続け、確認する前であればいつでもこのグループを再開できます。';

  @override
  String get questionQuestionRequest => '質問リクエスト';

  @override
  String get questionQuestionsProvidedSubmit => '提供された質問はありません。空の回答を送信できます。';

  @override
  String get questionReviewAnswersSubmitting => '送信する前に回答を確認してください。';

  @override
  String get quotaAuthCookie => '認証クッキー';

  @override
  String get quotaConnect => '接続';

  @override
  String get quotaForget => '忘れる';

  @override
  String get quotaOpenCodeGoConnectDescription =>
      '使用量ダッシュボードに接続して、ローリング、週次、月次の制限を表示します。';

  @override
  String get quotaOpenCodeGoDetected => 'OpenCode Go を検出しました';

  @override
  String get quotaOpenCodeGoNeedsReconnect => 'OpenCode Go の再接続が必要です';

  @override
  String get quotaOpenCodeGoReconnectDescription =>
      '使用量バーを復元するには、ダッシュボードの認証情報を更新してください。';

  @override
  String get quotaOpenCodeGoUsage => 'OpenCode Go 使用量';

  @override
  String get quotaOpenDashboard => 'OpenCodeダッシュボードを開く';

  @override
  String get quotaPaceExplanation => 'ペースは現在の速度に基づき、現在の制限ウィンドウ終了時の合計使用量を予測します。';

  @override
  String quotaPacePercent(String percent) {
    return 'ペース $percent%';
  }

  @override
  String get quotaRateLimits => '利用制限';

  @override
  String get quotaReconnect => '再接続';

  @override
  String get quotaRefreshing => '更新中...';

  @override
  String quotaResetsIn(String time) {
    return '$time後にリセット';
  }

  @override
  String get quotaSaving => '保存中...';

  @override
  String get quotaWorkspaceId => 'ワークスペースID';

  @override
  String get serverClearOAuth => 'OAuth情報をクリア';

  @override
  String get serverConnectionAttention => 'サーバー接続に注意が必要です。';

  @override
  String get serverHealthHealthy => '正常';

  @override
  String get serverHealthUnhealthy => '異常';

  @override
  String get serverHealthUnknown => '不明';

  @override
  String get serverOAuthAuthFailed => 'OAuth認証に失敗しました';

  @override
  String get serverOAuthChip => 'OAuth';

  @override
  String get serverOAuthNotSupported =>
      'Cloudflare Access OAuth はこのプラットフォームではサポートされていません';

  @override
  String get serverReauthenticate => '再認証';

  @override
  String get serverTailscaleChip => 'Tailscale';

  @override
  String get serversActive => 'アクティブ';

  @override
  String get serversActiveServer => 'アクティブサーバー';

  @override
  String get serversAddLeastOpenCode =>
      'アプリの使用を開始するには、少なくとも1つの OpenCode サーバーを追加してください。';

  @override
  String get serversAddServer => 'サーバーを追加';

  @override
  String get serversCancel => 'キャンセル';

  @override
  String get serversCannotActivateUnhealthy => '異常なサーバーは有効にできません';

  @override
  String get serversCheckHealth => 'ヘルスチェック';

  @override
  String get serversClearDefault => 'デフォルトをクリア';

  @override
  String serversCommandAppProviderLocalServerCommandPath(
    String localServerCommandPath,
  ) {
    return 'コマンド: $localServerCommandPath';
  }

  @override
  String get serversCopy => 'コピー';

  @override
  String get serversDefault => 'デフォルト';

  @override
  String get serversDelete => '削除';

  @override
  String get serversDeleteServer => 'サーバーを削除';

  @override
  String get serversDesktopModeExplanation =>
      'デスクトップモードでは、CodeWalk から直接 `opencode serve` を起動および管理できます。';

  @override
  String get serversEdit => '編集';

  @override
  String get serversLocalOpenCodeServer => 'ローカル OpenCode サーバー';

  @override
  String get serversManagedModeAvailable =>
      'この管理モードはデスクトップビルド（Linux/macOS/Windows）でのみ利用可能です。';

  @override
  String get serversNoServersFound => 'サーバーが見つかりません';

  @override
  String get serversRefreshHealth => 'ヘルス状態を更新';

  @override
  String serversRemoveProfileDisplayName(String displayName) {
    return '\"$displayName\"を削除しますか？';
  }

  @override
  String get serversSearchActiveHint => 'アクティブサーバーを検索';

  @override
  String get serversServersConfigured => '設定されたサーバーはありません';

  @override
  String get serversSetActive => 'アクティブに設定';

  @override
  String get serversSetDefault => 'デフォルトに設定';

  @override
  String get serversSetupDebug => 'セットアップデバッグ';

  @override
  String get serversSetupWizard => 'セットアップウィザード';

  @override
  String get serversTailscaleAdminApprovalRequired => 'Tailscale 管理者の承認が必要です';

  @override
  String get serversTailscaleAuthRequired => 'Tailscale の認証が必要です';

  @override
  String get serversTailscaleConnectExplanation =>
      'このアクティブプロファイルが使用されると、Tailscale が接続します。';

  @override
  String get serversTailscaleConnected => 'Tailscale 接続済み';

  @override
  String get serversTailscaleConnecting => 'Tailscale 接続中';

  @override
  String get serversTailscaleConnectionFailed => 'Tailscale 接続に失敗しました';

  @override
  String get serversTailscaleDisconnected => 'Tailscale 切断済み';

  @override
  String get serversTailscaleLoginExplanation =>
      'Tailscale ログイン URL を開いて、このデバイスを tailnet に追加してください。';

  @override
  String get serversTailscaleTrafficExplanation =>
      'このアクティブプロファイルの OpenCode トラフィックは Tailscale 経由でルーティングされます。';

  @override
  String get serversTailscaleUnsupported => 'Tailscale はサポートされていません';

  @override
  String get serversUnhealthyActivateError =>
      'このサーバーは異常です。有効にする前にヘルスチェックを行うか、設定を編集してください。';

  @override
  String get sessionActionArchived => 'アーカイブ済み';

  @override
  String get sessionActionDeleted => '削除済み';

  @override
  String get sessionActionForked => 'フォーク済み';

  @override
  String get sessionActionPinned => 'ピン留め済み';

  @override
  String get sessionActionUnarchived => 'アーカイブ解除済み';

  @override
  String get sessionActionUnpinned => 'ピン留め解除済み';

  @override
  String get sessionArchive => 'アーカイブ';

  @override
  String get sessionCancelRename => '名前変更をキャンセル';

  @override
  String sessionChildrenCount(int count) {
    return 'サブ会話: $count';
  }

  @override
  String get sessionCompactContext => 'コンテキストを圧縮';

  @override
  String get sessionCopyLink => 'リンクをコピー';

  @override
  String get sessionDelete => '削除';

  @override
  String sessionDeleteConfirm(String title) {
    return '会話「$title」を削除してもよろしいですか？この操作は元に戻せません。';
  }

  @override
  String get sessionDeleteTitle => '会話を削除';

  @override
  String get sessionDiffChangedFile => '変更されたファイル';

  @override
  String get sessionDiffContentNotCaptured => 'ファイルコンテンツがサーバーによってキャプチャされませんでした';

  @override
  String sessionDiffFilesChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count個のファイルが変更されました',
      one: '1個のファイルが変更されました',
    );
    return '$_temp0';
  }

  @override
  String sessionDiffFilesCount(int count) {
    return '差分ファイル: $count';
  }

  @override
  String sessionDiffLinesAddedRemoved(int added, int removed) {
    return '+$added 行追加 -$removed 行削除';
  }

  @override
  String sessionDiffLinesCollapsed(int count) {
    return '$count 行が折りたたまれています — タップして展開';
  }

  @override
  String get sessionDiffLoading => '変更されたファイルを読み込み中…';

  @override
  String get sessionDiffReview => '変更を確認';

  @override
  String get sessionDiffSplit => '分割';

  @override
  String get sessionDiffSummary => '概要';

  @override
  String get sessionDiffUnified => '統合';

  @override
  String get sessionExportAssistant => 'アシスタント';

  @override
  String get sessionExportCanceled => 'エクスポートをキャンセルしました';

  @override
  String get sessionExportDebugJson => 'デバッグJSONをエクスポート';

  @override
  String get sessionExportDebugJsonErrorClipboard =>
      'ファイルを保存できませんでした。デバッグJSONをクリップボードにコピーしました';

  @override
  String get sessionExportDebugJsonSaved => 'デバッグJSONエクスポートを保存しました';

  @override
  String get sessionExportDebugJsonTitle => 'セッションをデバッグJSONとしてエクスポート';

  @override
  String get sessionExportError => 'エラー:';

  @override
  String get sessionExportInput => '入力:';

  @override
  String get sessionExportMarkdown => 'Markdownをエクスポート';

  @override
  String get sessionExportMarkdownErrorClipboard =>
      'ファイルを保存できませんでした。Markdownをクリップボードにコピーしました';

  @override
  String get sessionExportMarkdownSaved => 'Markdownエクスポートを保存しました';

  @override
  String get sessionExportMarkdownTitle => 'セッションをMarkdownとしてエクスポート';

  @override
  String get sessionExportOutput => '出力:';

  @override
  String get sessionExportUntitled => '無題のセッション';

  @override
  String get sessionExportUser => 'ユーザー';

  @override
  String get sessionFailedRename => '会話の名前変更に失敗しました';

  @override
  String get sessionFailedUpdateArchive => 'アーカイブ状態の更新に失敗しました';

  @override
  String get sessionFailedUpdateSharing => '共有状態の更新に失敗しました';

  @override
  String get sessionFork => 'フォーク';

  @override
  String get sessionForkFailed => '会話のフォークに失敗しました';

  @override
  String get sessionForked => '会話をフォークしました';

  @override
  String sessionHasError(String title) {
    return '「$title」にエラーがあります。';
  }

  @override
  String sessionHasNewReply(String title) {
    return '「$title」に新しい返信があります。';
  }

  @override
  String get sessionKeyboardShortcuts => 'キーボードショートカット';

  @override
  String sessionNeedsInput(String title) {
    return '「$title」はあなたの入力を必要としています。';
  }

  @override
  String get sessionNoCachedConversations => 'キャッシュされた会話はまだありません';

  @override
  String get sessionNoConversationsInProject => 'このプロジェクトには会話がありません。';

  @override
  String get sessionNotAvailable => 'このプロジェクトではまだ会話が利用できません';

  @override
  String get sessionOpenProjectToLoad => 'プロジェクトを開いて会話を読み込んでください。';

  @override
  String get sessionPin => 'ピン留め';

  @override
  String get sessionRename => '名前変更';

  @override
  String get sessionRenameHint => '新しい会話名を入力';

  @override
  String get sessionRenameTitle => '会話の名前変更';

  @override
  String get sessionSaveTitle => 'タイトルを保存';

  @override
  String get sessionShare => 'セッションを共有';

  @override
  String get sessionShareAction => '共有';

  @override
  String get sessionShareLinkCopied => '共有リンクがコピーされました';

  @override
  String get sessionShareLinkUnavailable => 'このセッションの共有リンクは利用できません';

  @override
  String get sessionShared => '会話を共有しました';

  @override
  String get sessionSyncing => '会話を同期中...';

  @override
  String get sessionTitleHint => '会話のタイトル';

  @override
  String get sessionUnarchive => 'アーカイブから戻す';

  @override
  String get sessionUnpin => 'ピン留めを外す';

  @override
  String get sessionUnshare => '共有を解除';

  @override
  String get sessionUnshareAction => '共有を解除';

  @override
  String get sessionUnshared => '会話の共有を解除しました';

  @override
  String get sessionViewTasks => 'タスクを表示';

  @override
  String get settingsAboutCheckForUpdates => 'アップデートを確認';

  @override
  String get settingsAboutCheckOnOpen => '起動時にアップデートを確認';

  @override
  String get settingsAboutCheckOnOpenDescription => 'アプリ起動時に自動的に確認します';

  @override
  String get settingsAboutChecking => '確認中...';

  @override
  String get settingsAboutDescription => 'バージョン、更新、ヘルプ、アプリのデータ';

  @override
  String get settingsAboutDismiss => '閉じる';

  @override
  String settingsAboutDownloading(String percent) {
    return 'ダウンロード中... $percent%';
  }

  @override
  String get settingsAboutEraseAllData => 'すべてのデータを消去して再起動';

  @override
  String get settingsAboutInstallUpdate => 'アップデートをインストール';

  @override
  String get settingsAboutInstalling => 'インストール中...';

  @override
  String settingsAboutLatestVersion(String version) {
    return 'v$version が最新バージョンです';
  }

  @override
  String get settingsAboutLoading => '読み込み中...';

  @override
  String get settingsAboutReplayChatTour => 'チャットツアーを再再生';

  @override
  String get settingsAboutReplayChatTourDescription =>
      '設定を閉じて、チャットのガイド付きチュートリアルを表示します';

  @override
  String get settingsAboutResetApp => 'アプリをリセット';

  @override
  String get settingsAboutResetAppQuestion => 'アプリをリセットしますか？';

  @override
  String get settingsAboutResetAppWarning =>
      'これにより、すべてのサーバー、設定、およびキャッシュデータが消去されます。この操作は取り消せません。';

  @override
  String get settingsAboutRetryInstall => 'インストールを再試行';

  @override
  String get settingsAboutTapToCheck => 'タップして新しいバージョンを確認';

  @override
  String get settingsAboutTitle => '情報';

  @override
  String get settingsAboutUpToDate => '最新の状態です';

  @override
  String settingsAboutUpdateAvailable(String version) {
    return 'アップデートが利用可能です: v$version';
  }

  @override
  String get settingsAboutUpdateInstalled =>
      'アップデートがインストールされました。適用するにはアプリを再起動してください。';

  @override
  String settingsAboutUpdateVersionSummary(
    String installedVersion,
    String latestVersion,
  ) {
    return '現在: $installedVersion; 利用可能: v$latestVersion';
  }

  @override
  String get settingsAboutVersion => 'バージョン';

  @override
  String settingsAboutVersionBuild(String buildNumber, String version) {
    return '$version (ビルド $buildNumber)';
  }

  @override
  String get settingsAppearanceAmoledDark => 'AMOLEDダークモード';

  @override
  String get settingsAppearanceAmoledDarkActive =>
      '使用する純粋な黒の画面をダークモードがアクティブな間に有効にします。';

  @override
  String get settingsAppearanceAmoledDarkInactive =>
      'AMOLED画面を有効にするには、ダークモードに切り替えてください。';

  @override
  String get settingsAppearanceBrandColor => 'ブランドカラー';

  @override
  String get settingsAppearanceBrandColorDynamicBlocked =>
      'ブランドカラーを選択するには、壁紙の色を無効にしてください。';

  @override
  String get settingsAppearanceBrandColorNormal => 'アプリパレットのシードカラーを選択します。';

  @override
  String get settingsAppearanceBrandColorPresetBlocked =>
      'ブランドカラーを選択するには、CodeWalk クラシックに切り替えてください。';

  @override
  String get settingsAppearanceChatFontScale => '会話の文字サイズ';

  @override
  String get settingsAppearanceChatFontScaleDescription =>
      'システムの文字サイズに加えて、チャットメッセージとコンポーザーのテキストを拡大縮小します。';

  @override
  String get settingsAppearanceCodeWalkClassic => 'CodeWalkクラシック';

  @override
  String get settingsAppearanceComposerTips => 'コンポーザーヒント';

  @override
  String get settingsAppearanceComposerTipsDescription =>
      'アシスタントが推論中に回転表示されるヒントの表示/非表示を切り替えます。';

  @override
  String get settingsAppearanceContrast => 'コントラスト';

  @override
  String get settingsAppearanceContrastDynamicBlocked =>
      'コントラストを調整するには、壁紙の色を無効にしてください。';

  @override
  String get settingsAppearanceContrastHigh => '高コントラスト';

  @override
  String get settingsAppearanceContrastNormal => 'カラースキームのコントラストレベルを調整します。';

  @override
  String get settingsAppearanceContrastPresetBlocked =>
      'コントラストを調整するには、CodeWalk クラシックに切り替えてください。';

  @override
  String get settingsAppearanceContrastReduced => '低コントラスト';

  @override
  String get settingsAppearanceDark => 'ダーク';

  @override
  String get settingsAppearanceDensity => '表示密度';

  @override
  String get settingsAppearanceDensityDense => '高密度';

  @override
  String get settingsAppearanceDensityDescription =>
      'アプリ全体の余白とコンポーネントの密度を適用します。';

  @override
  String get settingsAppearanceDensityExtraDense => '超高密度';

  @override
  String get settingsAppearanceDensityExtraSpacious => '超低密度';

  @override
  String get settingsAppearanceDensityNormal => '標準';

  @override
  String get settingsAppearanceDensitySpacious => '低密度';

  @override
  String get settingsAppearanceDescription => 'テーマ、配色、文字サイズ、チャット表示を選択';

  @override
  String get settingsAppearanceFontSize => '文字サイズ';

  @override
  String get settingsAppearanceFontSizeDescription =>
      'システムテキスト、会話テキスト、ターミナルの文字サイズを調整します。';

  @override
  String get settingsAppearanceLight => 'ライト';

  @override
  String get settingsAppearanceMathRendering => '数式レンダリング';

  @override
  String get settingsAppearanceMathRenderingDescription =>
      'チャットメッセージでLaTeX数式を組版済み方程式としてレンダリングします。';

  @override
  String get settingsAppearanceNoPresets => 'プリセットパレットが見つかりません';

  @override
  String get settingsAppearanceOpenCodePresets => 'OpenCodeプリセット';

  @override
  String get settingsAppearancePresetHelper =>
      '公式の OpenCode Web に組み込まれているテーマ一覧をミラーリングします。';

  @override
  String get settingsAppearancePresetNote =>
      'テーマカラーは公式の OpenCode Web レジストリに従うようになり、マークダウンやコードの表示面も駆動します。';

  @override
  String get settingsAppearancePresetPalette => 'プリセットパレット';

  @override
  String get settingsAppearanceSearchPreset => 'プリセットパレットを検索';

  @override
  String get settingsAppearanceSectionDescription =>
      'ワークフローに合わせて、表示密度やメッセージの表面を調整します。';

  @override
  String get settingsAppearanceSectionTitle => '外観';

  @override
  String get settingsAppearanceSystem => 'システム';

  @override
  String get settingsAppearanceSystemFontScale => 'システムの文字サイズ';

  @override
  String get settingsAppearanceSystemFontScaleDescription =>
      'メニュー、ダイアログ、サイドバーを含むアプリシェル全体の文字を拡大縮小します。';

  @override
  String get settingsAppearanceTaskList => 'タスク一覧';

  @override
  String get settingsAppearanceTaskListDescription =>
      'セッションタスク一覧ウィジェットの表示/非表示を切り替えます。';

  @override
  String get settingsAppearanceTerminalFontSize => 'ターミナルの文字サイズ';

  @override
  String get settingsAppearanceTerminalFontSizeDescription =>
      '組み込みターミナルのフォントサイズを変更します。実行中のセッションにすぐに適用されます。';

  @override
  String get settingsAppearanceTheme => 'テーマ';

  @override
  String get settingsAppearanceThemeDescription =>
      'ライト、ダーク、またはシステムモードを選択し、CodeWalk クラシックパレットを維持するか、OpenCode プリセットに切り替えます。';

  @override
  String get settingsAppearanceVisualStyle => 'ビジュアルスタイル';

  @override
  String get settingsAppearanceVisualStyleDescription =>
      'クラシック表示、またはより柔らかな洗練表示を選択します。';

  @override
  String get settingsAppearanceVisualStyleClassic => 'クラシック';

  @override
  String get settingsAppearanceVisualStyleRefined => '洗練';

  @override
  String get settingsAppearanceThinkingBubbles => '思考プロセスバブル';

  @override
  String get settingsAppearanceThinkingBubblesDescription =>
      'アシスタントメッセージ内の推論ブロック（思考プロセス）の表示/非表示を切り替えます。';

  @override
  String get settingsAppearanceTitle => '外観';

  @override
  String get settingsAppearanceToolCallBubbles => 'ツール呼び出しバブル';

  @override
  String get settingsAppearanceToolCallBubblesDescription =>
      'アシスタントメッセージ内のツール実行カードの表示/非表示を切り替えます。';

  @override
  String get settingsAppearanceWallpaperColors => '壁紙の色を使用する';

  @override
  String get settingsAppearanceWallpaperNormal => 'デバイスの壁紙からカラースキームを抽出します。';

  @override
  String get settingsAppearanceWallpaperPresetBlocked =>
      '壁紙の色を使用するには、CodeWalk クラシックに切り替えてください。';

  @override
  String get settingsAppearanceWindowChrome => 'ウィンドウのタブ';

  @override
  String get settingsAppearanceWindowChromeDescription =>
      'デスクトップでセッションタブとタイトルバーをどう組み合わせるか選びます。';

  @override
  String get settingsAppearanceWindowChromeIntegrated => '統合タブ';

  @override
  String get settingsAppearanceWindowChromeIntegratedDescription =>
      'タブがウィンドウ最上部に配置され、システムのタイトルバーは非表示になります。';

  @override
  String get settingsAppearanceWindowChromeSystem => 'システムの装飾';

  @override
  String get settingsAppearanceWindowChromeSystemDescription =>
      'ネイティブのタイトルバーを維持し、タブをアプリバーの下に表示します。';

  @override
  String get settingsBack => '戻る';

  @override
  String get settingsBehaviorAutoupdateCaveat =>
      'CodeWalk のリリース確認には「情報」を使用してください。この設定は公式の OpenCode `autoupdate` 設定をミラーリングしているだけです。';

  @override
  String get settingsBehaviorAutoupdateHelp =>
      '上流の OpenCode ランタイムのアップデートを制御します。CodeWalk アプリのアップデート確認ではありません。';

  @override
  String get settingsBehaviorCellularDataSaver => 'モバイルデータセーバー';

  @override
  String get settingsBehaviorChatRenderMode => 'チャット表示モード';

  @override
  String get settingsBehaviorChatRenderModeBlock => 'ブロック';

  @override
  String get settingsBehaviorChatRenderModeBlockDescription =>
      '現在のターンを1つのブロックとして表示できるまで、ライブのアシスタントテキスト、推論、ツールカードを非表示にします。';

  @override
  String get settingsBehaviorChatRenderModeDescription =>
      'アシスタントの応答をストリーム中に表示するか、現在のターンが完了した後に表示するかを選択します。';

  @override
  String get settingsBehaviorChatRenderModeLive => 'ライブ';

  @override
  String get settingsBehaviorChatRenderModeLiveDescription =>
      'OpenCode がイベントをストリームする際に、アシスタントのテキスト、推論、ツールのアクティビティを表示します。';

  @override
  String get settingsBehaviorComposerSpellCheck => 'コンポーザーのスペルチェック';

  @override
  String get settingsBehaviorComposerSpellCheckDescription =>
      'チャットコンポーザーでプラットフォーム標準のスペルチェック、候補、自動修正を使用します。';

  @override
  String get settingsBehaviorConfigDeferred =>
      'CodeWalk は、現在のレスポンスが終了した後にこの OpenCode 設定を適用します。';

  @override
  String settingsBehaviorConfigUpdateFailed(String field) {
    return 'OpenCode の $field を更新できませんでした。';
  }

  @override
  String get settingsBehaviorConversationUsername => '会話用ユーザー名';

  @override
  String get settingsBehaviorConversationUsernameHelp =>
      'システムユーザー名の代わりに会話内で表示されるカスタム表示名。';

  @override
  String get settingsBehaviorDataSaverActive => 'モバイルデータ通信で現在有効です。';

  @override
  String get settingsBehaviorDataSaverCellularOnly =>
      '接続がモバイルデータ通信の場合にのみ適用されます。';

  @override
  String get settingsBehaviorDataSaverDescription =>
      'バックグラウンドのダウンロードを停止し、フォアグラウンドの自動更新を制限することで、モバイルデータの自動使用を削減します。';

  @override
  String get settingsBehaviorDataSaverWaiting => '次のモバイルデータ同期ウィンドウを待機しています。';

  @override
  String get settingsBehaviorDefaultAgent => 'デフォルトエージェント';

  @override
  String get settingsBehaviorDefaultAgentHelp =>
      'エージェントが明示的に選択されていない場合に使用されるプライマリエージェント。';

  @override
  String get settingsBehaviorDefaultModel => 'デフォルトモデル';

  @override
  String get settingsBehaviorDefaultModelHelp =>
      '設定を通じて OpenCode クライアント間で共有されます。';

  @override
  String get settingsBehaviorDescription =>
      '言語、チャットの動作、データ使用、OpenCode のデフォルトを管理';

  @override
  String get settingsBehaviorEnableDataSaver => 'モバイルデータセーバーを有効にする';

  @override
  String get settingsBehaviorMultiDeviceSync => '試験的な複数デバイス同期を有効にする';

  @override
  String get settingsBehaviorMultiDeviceSyncDescription =>
      'コンポーザーの選択（エージェント/モデル/バリアント）をアクティブなサーバー設定と同期します。';

  @override
  String get settingsBehaviorMultiDeviceSyncWarning =>
      '同時に複数のセッションで作業している場合、進行中のセッションが中断される可能性があります。';

  @override
  String get settingsBehaviorNoAgents => 'エージェントが見つかりません';

  @override
  String get settingsBehaviorNoModels => 'モデルが見つかりません';

  @override
  String get settingsBehaviorOpenCodeAutoupdate => 'OpenCode自動アップデート';

  @override
  String get settingsBehaviorOpenCodeDefaults => 'OpenCodeベースのデフォルト値';

  @override
  String get settingsBehaviorOpenCodeDefaultsDescription =>
      'これらの値はアクティブなサーバーの `/config` に書き込まれ、公式の OpenCode 共有設定と一致します。';

  @override
  String get settingsBehaviorOpenCodeSnapshots => 'OpenCodeスナップショット';

  @override
  String get settingsBehaviorOpenCodeSnapshotsDescription =>
      '元に戻す/やり直しおよび回復履歴のために、上流の Git ベースのスナップショットを有効のままにします。';

  @override
  String get settingsBehaviorPermissionDeferred =>
      '高度な権限ルールの編集は、現時点では設定から除外され、今後のパリティ作業に延期されます。';

  @override
  String get settingsBehaviorPermissionProvenance => '権限処理の来歴（プロブナンス）';

  @override
  String get settingsBehaviorPermissionProvenanceDescription =>
      '公式の OpenCode 権限ポリシーは `opencode.json` でツールごとに許可/確認/拒否ルールが設定されています。CodeWalk は公式の権限要求カードを維持しつつ、承認済みの ADR-023 例外を1つ追加しています。コンポーザーの自動承認トグルは、永続的なセッションスコープの付与を作成するために、無条件で `Always` かつ `remember: true` を返し、Android バックグラウンドワーカーでも同じスレッドスコープの継続パスをアクティブに保ちます。';

  @override
  String get settingsBehaviorRefreshDefaults => 'デフォルト値を更新';

  @override
  String get settingsBehaviorSaveUsername => 'ユーザー名を保存';

  @override
  String get settingsBehaviorSearchAutoupdate => '自動アップデートモードを検索';

  @override
  String get settingsBehaviorSearchDefaultAgent => 'デフォルトエージェントを検索';

  @override
  String get settingsBehaviorSearchDefaultModel => 'デフォルトモデルを検索';

  @override
  String get settingsBehaviorSearchShareMode => '共有モードを検索';

  @override
  String get settingsBehaviorSearchSmallModel => 'スモールモデルを検索';

  @override
  String get settingsBehaviorShareMode => 'OpenCodeデフォルト共有設定';

  @override
  String get settingsBehaviorShareModeCaveat =>
      '現在ある1つのセッションを公開するには、チャットレベルの共有アクションを使用してください。この設定は OpenCode のデフォルトの共有ポリシーのみを変更します。';

  @override
  String get settingsBehaviorShareModeHelp =>
      '個々のチャットの共有ボタンではなく、公式のグローバル `share` 設定を制御します。';

  @override
  String get settingsBehaviorSmallModel => 'スモールモデル';

  @override
  String get settingsBehaviorSmallModelAutoFallback => '自動フォールバック';

  @override
  String get settingsBehaviorSmallModelFallbackActive =>
      '`small_model` が未設定のため、OpenCode の自動フォールバックが有効です。';

  @override
  String get settingsBehaviorSmallModelHelp => 'タイトル生成などの軽量なタスクに使用されます。';

  @override
  String get settingsBehaviorSmallModelResetCaveat =>
      '`/config` のパッチ更新ではキーを削除できないため、`small_model` を自動フォールバックに戻すには、アプリ外で設定を編集する必要があります。';

  @override
  String get settingsBehaviorSnapshotCaveat =>
      'これは OpenCode のスナップショット保存と元に戻す/やり直しのサポートを制御するものであり、CodeWalk のローカルキャッシュスナップショットではありません。';

  @override
  String get settingsBehaviorTitle => '動作';

  @override
  String get settingsBehaviorUsernameFallback =>
      '`username` が未設定のため、OpenCode はシステムユーザー名を使用します。';

  @override
  String get settingsBehaviorUsernamePatchCaveat =>
      '`/config` のパッチ更新ではキーを削除できないため、`username` をシステムデフォルトに戻すには、アプリ外で設定を編集する必要があります。';

  @override
  String get settingsConfigRefreshFailed =>
      'サーバー設定を更新しましたが、チャットプロバイダーを更新できませんでした。';

  @override
  String get settingsConfigUpdateDeferred =>
      'CodeWalk は、現在のレスポンスが終了した後にこの OpenCode 設定を適用します。';

  @override
  String get settingsConversationUsername => '会話ユーザー名';

  @override
  String get settingsDefaultAgent => 'デフォルトエージェント';

  @override
  String get settingsDefaultModel => 'デフォルトモデル';

  @override
  String get settingsLanguageDescription =>
      'CodeWalkで使用する言語を選択します。システムのデフォルトはデバイスの言語に従います。';

  @override
  String get settingsLanguageEmptyText => '言語が見つかりません';

  @override
  String get settingsLanguageFieldHelper => 'すぐに適用され、再起動後も保持されます。';

  @override
  String get settingsLanguageFieldLabel => 'アプリの言語';

  @override
  String get settingsLanguageSearchHint => '言語を検索';

  @override
  String get settingsLanguageSystemDefault => 'システムデフォルト';

  @override
  String get settingsLanguageTitle => '言語';

  @override
  String get settingsLogsDescription => 'アプリの診断とトラブルシューティングの詳細を確認';

  @override
  String get settingsLogsTitle => 'Registros';

  @override
  String get settingsNoAgentsFound => 'エージェントが見つかりません';

  @override
  String get settingsNotificationsAgentSubtitle => 'レスポンスが終了したとき';

  @override
  String get settingsNotificationsAgentUpdates => 'エージェントの更新';

  @override
  String get settingsNotificationsAnotherConversation => '別の会話があるとき';

  @override
  String get settingsNotificationsAppInBackground => 'アプリがバックグラウンドにあるとき';

  @override
  String get settingsNotificationsBackgroundAlerts => 'Androidバックグラウンドアラート';

  @override
  String get settingsNotificationsBackgroundBehavior => 'バックグラウンドの動作';

  @override
  String get settingsNotificationsBackgroundBehaviorDescription =>
      'アプリがフォアグラウンドから離れた後の CodeWalk の動作を選択します。';

  @override
  String get settingsNotificationsBackgroundDescription =>
      'アプリが画面に表示されていない間、レスポンス完了、権限要求、質問、およびエラーを低データ量のバックグラウンド監視で追跡します。';

  @override
  String get settingsNotificationsBackgroundToggle => 'Androidでのバックグラウンドアラート';

  @override
  String get settingsNotificationsBackgroundToggleDescription =>
      'すべての Android バックグラウンドチェックをオフにし、永続的な監視通知を非表示にします。';

  @override
  String get settingsNotificationsBatteryDescription =>
      'アプリを再開したときにしか通知が届かない場合は、CodeWalk がこのデバイスで最適化なしで実行できるように許可してください。';

  @override
  String get settingsNotificationsBatteryDisabled =>
      'CodeWalk のバッテリー最適化は無効になっています。';

  @override
  String get settingsNotificationsBatteryEnabled =>
      'バッテリー最適化が有効になっています。一部のデバイスでは、バックグラウンドアラートが遅れる場合があります。';

  @override
  String get settingsNotificationsBatteryOptimization => 'Androidバッテリー最適化';

  @override
  String get settingsNotificationsBatteryUnknown =>
      'バッテリー最適化のステータスをまだ読み取れませんでした。';

  @override
  String get settingsNotificationsChooseAudioFile => 'オーディオファイルを選択';

  @override
  String get settingsNotificationsChooseSystemSound => 'システムサウンドを選択';

  @override
  String get settingsNotificationsCloseToTray => 'トレイに閉じる';

  @override
  String get settingsNotificationsCloseToTrayDescription =>
      'ウィンドウを非表示にし、システムトレイで実行を続けます。';

  @override
  String get settingsNotificationsDescription => '通知するイベントと通知方法を選択';

  @override
  String get settingsNotificationsDisableOptimization => '最適化を無効にする';

  @override
  String get settingsNotificationsErrors => 'エラー';

  @override
  String get settingsNotificationsErrorsSubtitle => 'セッションが失敗を報告したとき';

  @override
  String get settingsNotificationsJustClose => 'そのまま閉じる';

  @override
  String get settingsNotificationsJustCloseDescription => 'アプリケーションを完全に終了します。';

  @override
  String get settingsNotificationsKeepLive => 'アラートを3分間維持';

  @override
  String get settingsNotificationsKeepLiveDescription =>
      'レスポンスが既に実行されている場合、アプリを離れた後も短時間リアルタイム通信を有効に保ちます。';

  @override
  String get settingsNotificationsLocal => 'ローカル';

  @override
  String get settingsNotificationsMinimizeWhenClose => '閉じるときに最小化';

  @override
  String get settingsNotificationsMinimizeWhenCloseDescription =>
      'タスクバー/ドックに最小化し、実行を続けます。';

  @override
  String get settingsNotificationsNoCondition =>
      '条件が選択されていない場合、すべての場合においてアラートが許可されます。';

  @override
  String get settingsNotificationsNotify => '通知する';

  @override
  String get settingsNotificationsNotifyOnlyWhen => '次のときのみ通知する';

  @override
  String get settingsNotificationsOpenBatterySettings => 'バッテリー設定を開く';

  @override
  String get settingsNotificationsPermissions => '権限と質問';

  @override
  String get settingsNotificationsPermissionsSubtitle => 'ツールが入力を要求したとき';

  @override
  String get settingsNotificationsPreview => 'プレビュー';

  @override
  String get settingsNotificationsRefreshStatus => 'ステータスを更新';

  @override
  String get settingsNotificationsSearchSoundType => 'サウンドの種類を検索';

  @override
  String get settingsNotificationsSectionDescription =>
      'アラートが表示されるタイミングと、サウンドを再生できるタイミングを制御します。';

  @override
  String get settingsNotificationsSectionTitle => '通知';

  @override
  String settingsNotificationsSelectedSound(String label) {
    return '選択済み: $label';
  }

  @override
  String get settingsNotificationsServer => 'サーバー';

  @override
  String get settingsNotificationsSound => 'サウンド';

  @override
  String get settingsNotificationsSoundBuiltInAlert => '内蔵アラート音';

  @override
  String get settingsNotificationsSoundBuiltInClick => '内蔵クリック音';

  @override
  String get settingsNotificationsSoundOff => 'オフ';

  @override
  String get settingsNotificationsSoundOnlyWhen => '次のときのみサウンドを鳴らす';

  @override
  String get settingsNotificationsSoundPickAudioFile => 'オーディオファイルを選択';

  @override
  String get settingsNotificationsSoundPickFromSystem => 'システムから選択';

  @override
  String get settingsNotificationsSoundSystemDefault => 'システムデフォルト';

  @override
  String get settingsNotificationsSoundType => 'サウンドの種類';

  @override
  String get settingsNotificationsSyncInfo =>
      '一部のカテゴリのオン/オフ設定は、アクティブなサーバーの /config と同期されます。';

  @override
  String get settingsNotificationsSyncInfoLocal =>
      '現在のサーバーは /config で通知設定を公開していません。ローカル値が有効です。';

  @override
  String get settingsNotificationsSystemSoundPickerTitle => 'システムサウンドを選択';

  @override
  String get settingsNotificationsTitle => '通知';

  @override
  String get settingsNotificationsWhenClosing => 'ウィンドウを閉じるとき';

  @override
  String get settingsOpenCodeAutoUpdate => 'OpenCode 自動更新';

  @override
  String get settingsOpenCodeSharingDefault => 'OpenCode 共有デフォルト';

  @override
  String get settingsReadAloudEnabled => '音声読み上げ';

  @override
  String get settingsReadAloudEnabledDescription =>
      'アシスタントメッセージに音声読み上げボタンを表示します。';

  @override
  String get settingsReadAloudPitch => 'ピッチ';

  @override
  String get settingsReadAloudPitchDescription => '音声のピッチを調整します。';

  @override
  String get settingsReadAloudSectionDescription =>
      'アシスタントの返答を読み上げます。速度、ピッチ、音声を構成します。';

  @override
  String get settingsReadAloudSectionTitle => '音声読み上げ（TTS）';

  @override
  String get settingsReadAloudSpeed => '速度';

  @override
  String get settingsReadAloudSpeedDescription => '話す速度を調整します。';

  @override
  String get settingsReadAloudVoice => '音声';

  @override
  String get settingsReadAloudVoiceHint => '読み上げ用の音声を選択します。';

  @override
  String get settingsSearchAutoUpdateMode => '自動更新モードを検索';

  @override
  String get settingsSearchDefaultAgent => 'デフォルトエージェントを検索';

  @override
  String get settingsSearchDefaultModel => 'デフォルトモデルを検索';

  @override
  String get settingsSearchSharingMode => '共有モードを検索';

  @override
  String get settingsSearchSmallModel => 'スモールモデルを検索';

  @override
  String get settingsServersActive => 'アクティブ';

  @override
  String get settingsServersChooseActive => 'アクティブなサーバーを選択';

  @override
  String get settingsServersDefault => 'デフォルト';

  @override
  String get settingsServersDescription => 'OpenCode に接続し、サーバーを管理';

  @override
  String get settingsServersTitle => 'サーバー';

  @override
  String get settingsSessionAttentionSize => 'バブルのサイズ';

  @override
  String get settingsSessionAttentionSizeExtraLarge => '特大';

  @override
  String get settingsSessionAttentionSizeExtraSmall => '極小';

  @override
  String get settingsSessionAttentionSizeLarge => '大';

  @override
  String get settingsSessionAttentionSizeSmall => '小';

  @override
  String get settingsSessionAttentionSizeStandard => '標準';

  @override
  String get settingsSetupWizard => 'セットアップウィザード';

  @override
  String get settingsShortcutsDescription => 'キーボードショートカットを検索・カスタマイズ';

  @override
  String get settingsShortcutsEdit => 'ショートカットを編集';

  @override
  String get settingsShortcutsKeyboard => 'キーボードショートカット';

  @override
  String get settingsShortcutsReset => 'ショートカットをリセット';

  @override
  String get settingsShortcutsSearch => 'ショートカットを検索';

  @override
  String get settingsShortcutsTitle => 'ショートカット';

  @override
  String get settingsSmallModel => 'スモールモデル';

  @override
  String get settingsSmallModelResetExplanation =>
      '`/config` パッチ更新ではキーを削除できないため、`small_model` を自動フォールバックに戻すにはアプリ外で設定を編集する必要があります。';

  @override
  String get settingsSmallModelUnsetExplanation =>
      '`small_model` が設定されていないため、OpenCode の自動フォールバックが有効です。';

  @override
  String get settingsSoundPickerNotAvailable =>
      'システムサウンドピッカーはこのプラットフォームでは利用できません。';

  @override
  String get settingsSpeechDescription => '音声入力、オフラインモデル、読み上げを設定';

  @override
  String get settingsSpeechRefreshStatus => 'ステータスを更新';

  @override
  String settingsSpeechSilenceTimeout(String value) {
    return '無音タイムアウト: $value秒';
  }

  @override
  String get settingsSpeechTitle => '音声文字変換';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsGroupAlertTypes => 'アラートの種類';

  @override
  String get settingsGroupBackgroundBehavior => 'バックグラウンド時の動作';

  @override
  String get settingsGroupChatDisplay => 'チャット表示';

  @override
  String get settingsGroupCurrentConnection => '現在の接続';

  @override
  String get settingsGroupDataAndSync => 'データと同期';

  @override
  String get settingsGroupDataReset => 'データとリセット';

  @override
  String get settingsGroupDelivery => '配信';

  @override
  String get settingsGroupHelp => 'ヘルプ';

  @override
  String get settingsGroupLanguageAndChat => '言語とチャット';

  @override
  String get settingsGroupLayoutAndText => 'レイアウトと文字';

  @override
  String get settingsGroupOfflineModels => 'オフラインモデル';

  @override
  String get settingsGroupOpenCodeDefaults => 'OpenCode のデフォルト';

  @override
  String get settingsGroupReadAloud => '読み上げ';

  @override
  String get settingsGroupSavedServers => '保存済みサーバー';

  @override
  String get settingsGroupThemeAndColor => 'テーマと配色';

  @override
  String get settingsGroupThisDevice => 'このデバイス';

  @override
  String get settingsGroupVersionUpdates => 'バージョンと更新';

  @override
  String get settingsGroupVoiceInput => '音声入力';

  @override
  String get settingsNavigationGroupExperience => '操作感';

  @override
  String get settingsNavigationGroupInput => '入力';

  @override
  String get settingsNavigationGroupSetup => 'セットアップ';

  @override
  String get settingsNavigationGroupSupport => 'ヘルプと診断';

  @override
  String get settingsNavigationNoResults => '設定が見つかりません';

  @override
  String get settingsNavigationSearchHint => '設定を検索';

  @override
  String get settingsUsernameClearHint =>
      'OpenCode 会話ユーザー名をクリアするには、依然としてアプリ外で設定を編集する必要があります。';

  @override
  String get settingsUsernameEnterHint =>
      'カスタムの OpenCode 会話名を保存するにはユーザー名を入力してください。';

  @override
  String get settingsUsernameResetExplanation =>
      '`/config` パッチ更新ではキーを削除できないため、`username` をシステムデフォルトに戻すにはアプリ外で設定を編集する必要があります。';

  @override
  String get settingsUsernameUnsetExplanation =>
      'OpenCode は `username` が設定されていないため、システムユーザー名を使用します。';

  @override
  String get setupDebugBun => 'Bun';

  @override
  String get setupDebugBun2 => 'Bun';

  @override
  String get setupDebugCapturedSetupDetails => 'キャプチャされたセットアップの詳細はありません';

  @override
  String get setupDebugCapturedSetupLogs => 'キャプチャされたセットアップログ';

  @override
  String get setupDebugClear => 'セットアップデバッグをクリア';

  @override
  String get setupDebugClearSetupDebug => 'セットアップデバッグをクリア';

  @override
  String get setupDebugCodeWalkCaptureEnough =>
      'CodeWalkが十分なコンテキストをキャプチャしなかった場合は、公式の OpenCode ログおよびヘルスエンドポイントを直接確認してください:';

  @override
  String get setupDebugCommandPath => 'コマンドパス';

  @override
  String get setupDebugCommandPath2 => 'コマンドパス';

  @override
  String get setupDebugCopy => 'セットアップデバッグをコピー';

  @override
  String get setupDebugCopySetupDebug => 'セットアップデバッグをコピー';

  @override
  String get setupDebugCurrentStatus => '現在のステータス';

  @override
  String get setupDebugDiagnosticsLoading => '診断情報をまだ読み込み中です。';

  @override
  String get setupDebugEnvironment => '環境診断';

  @override
  String get setupDebugEnvironmentDiagnostics => '環境診断';

  @override
  String get setupDebugFocusedOpenCodeSetup => 'OpenCodeセットアップにフォーカス';

  @override
  String get setupDebugInstallDir => 'インストールディレクトリ';

  @override
  String get setupDebugInstallDirectory => 'インストールディレクトリ';

  @override
  String get setupDebugLatestLocalServer => '最新のローカルサーバー出力';

  @override
  String get setupDebugLogs => 'キャプチャされたセットアップログ';

  @override
  String get setupDebugManual => '手動トラブルシューティング';

  @override
  String get setupDebugManualTroubleshooting => '手動トラブルシューティング';

  @override
  String get setupDebugNetwork => 'ネットワーク';

  @override
  String get setupDebugNetwork2 => 'ネットワーク';

  @override
  String get setupDebugNoDetails => 'キャプチャされたセットアップの詳細はありません';

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
  String get setupDebugOpenCodeSetupDebug => 'OpenCodeセットアップデバッグ';

  @override
  String get setupDebugPlatform => 'プラットフォーム';

  @override
  String get setupDebugPlatform2 => 'プラットフォーム';

  @override
  String get setupDebugRunDiagnosticsTry =>
      'OpenCode固有のトラブルシューティング詳細をここにキャプチャするために、診断を実行するか、インストール方法を試すか、セットアップフローを試行してください。';

  @override
  String get setupDebugScreenCoversOpenCode =>
      'この画面は OpenCode のインストール、診断、およびローカルセットアップのトラブルシューティングのみをカバーします。一般的な CodeWalk 実行時の問題については、[アプリログ] を使用してください。';

  @override
  String get setupDebugServerOutput => '最新のローカルサーバー出力';

  @override
  String get setupDebugStatus => '現在のステータス';

  @override
  String setupDebugTimeEntrySource(String source, String time) {
    return '$time - $source';
  }

  @override
  String get setupDebugTimeline => 'タイムライン';

  @override
  String get setupDebugTimeline2 => 'タイムライン';

  @override
  String get setupDebugTitle => 'OpenCodeセットアップにフォーカス';

  @override
  String get setupDebugWSL => 'WSL';

  @override
  String get setupDebugWsl => 'WSL';

  @override
  String get shortcutCloseApp => 'タブ/アプリを閉じる';

  @override
  String get shortcutCloseAppDesc =>
      '現在のセッションタブがある場合は閉じ、それ以外はプラットフォームの動作でアプリを閉じる';

  @override
  String get shortcutFocusCloseDrawer => 'フォーカス/ドロワーを閉じる';

  @override
  String get shortcutFocusCloseDrawerDesc =>
      'デフォルトで入力にフォーカス、または開いている場合はドロワーを閉じる';

  @override
  String get shortcutFocusInput => '入力にフォーカス';

  @override
  String get shortcutFocusInputDesc => 'テキスト入力にフォーカスを移動';

  @override
  String get shortcutGroupApplication => 'アプリケーション';

  @override
  String get shortcutGroupGeneral => '全般';

  @override
  String get shortcutGroupModelAndAgent => 'モデルとエージェント';

  @override
  String get shortcutGroupNavigation => 'ナビゲーション';

  @override
  String get shortcutGroupPrompt => 'プロンプト';

  @override
  String get shortcutGroupSession => 'セッション';

  @override
  String get shortcutNewConversation => '新しい会話';

  @override
  String get shortcutNewConversationDesc => '新しいチャットセッションを作成';

  @override
  String get shortcutNextAgent => '次のエージェント';

  @override
  String get shortcutNextAgentDesc => '次の利用可能なエージェントに切り替え';

  @override
  String get shortcutNextRecentModel => '次の最近のモデル';

  @override
  String get shortcutNextRecentModelDesc => '最近使用したモデルを切り替え';

  @override
  String get shortcutNextVariant => '次のバリアント';

  @override
  String get shortcutNextVariantDesc => '利用可能なモデルバリアントを切り替え';

  @override
  String get shortcutOpenSettings => '設定を開く';

  @override
  String get shortcutOpenSettingsDesc => '設定ページを開く';

  @override
  String get shortcutPreviousAgent => '前のエージェント';

  @override
  String get shortcutPreviousAgentDesc => '前の利用可能なエージェントに切り替え';

  @override
  String get shortcutQuickOpenFiles => 'ファイルをクイックオープン';

  @override
  String get shortcutQuickOpenFilesDesc => 'ファイルクイック検索を開く';

  @override
  String get shortcutQuitApp => 'アプリを終了';

  @override
  String get shortcutQuitAppDesc => 'アプリを強制終了';

  @override
  String get shortcutRefreshData => 'データを更新';

  @override
  String get shortcutRefreshDataDesc => '現在のチャットデータを更新';

  @override
  String get shortcutStopResponse => '応答を停止';

  @override
  String get shortcutStopResponseDesc => 'アクティブな応答を停止（応答中）';

  @override
  String get shortcutToggleVoiceInput => '音声入力を切り替え';

  @override
  String get shortcutToggleVoiceInputDesc => 'エディタで音声入力を開始または停止';

  @override
  String get shortcutsApply => '適用';

  @override
  String shortcutsConflictConflict(String conflict) {
    return '$conflictと競合';
  }

  @override
  String get shortcutsKeyboardShortcuts => 'キーボードショートカット';

  @override
  String get shortcutsReset => 'すべてリセット';

  @override
  String get shortcutsSearchEditBindings =>
      '保存する前に、検索、バインディングの編集、および競合の解決を行います。';

  @override
  String shortcutsSetShortcutWidget(String label) {
    return 'ショートカットを設定: $label';
  }

  @override
  String get shortcutsTheseBindingsStored =>
      'これらのバインディングは現在のアプリ実行時のために CodeWalk に保存され、OpenCode の `tui.json` キーバインドは編集しません。';

  @override
  String get speechAutoStopSilence => '自動停止の無音タイムアウト';

  @override
  String get speechChooseRecognitionEngine =>
      '認識エンジン、無音タイムアウト、およびモデルのオプションを選択します。';

  @override
  String speechDesktopOnly(String service) {
    return '$service はデスクトップでのみ利用可能です。';
  }

  @override
  String get speechDownload => 'ダウンロード';

  @override
  String get speechEngine => 'エンジン';

  @override
  String get speechInstalledLanguages => 'インストールされた言語';

  @override
  String get speechListeningStopsAutomatically =>
      '指定された秒数の無音状態が続いた後、リスニングは自動的に停止します。';

  @override
  String get speechMicPermissionDisabled => 'マイクの権限が無効です。';

  @override
  String speechModelFilesIncomplete(String service) {
    return '$service のモデルファイルが不完全です。';
  }

  @override
  String get speechMoonshine => 'Moonshine';

  @override
  String get speechMoonshineModelsDesktop => 'Moonshineモデル（デスクトップ）';

  @override
  String get speechMoonshineStaysDownloadable =>
      'Moonshine はアプリバンドルの外に置かれ、ダウンロード可能な状態になります。このデスクトップデバイス用にモデルを1つ選択し、後で容量を戻したい場合は削除してください。';

  @override
  String get speechNative => 'ネイティブ';

  @override
  String get speechNativeSTTDisabled =>
      'このアプリでは Linux 上のネイティブ STT が無効になっています。新規インストールでは Parakeet がデフォルトのエンジンになります。';

  @override
  String get speechNativeSTTWorks =>
      'Windows では、CodeWalk は WASAPI マイクバックエンドを通じてローカルのオンデバイス音声認識を使用します。安定性のため、Windows ネイティブの音声認識は無効になっています。';

  @override
  String get speechNativeStartsFaster =>
      'ネイティブの方が起動が早いです。Sherpa はより重いセットアップとより深いモデル制御を伴い、完全にデバイス上で動作します。';

  @override
  String get speechOpenMicrophoneSettings => 'マイク設定を開く';

  @override
  String get speechOpenSpeechPrivacy => '音声のプライバシー設定を開く';

  @override
  String get speechOpenSpeechSettings => '音声設定を開く';

  @override
  String get speechParakeet => 'Parakeet';

  @override
  String get speechParakeetModelsDesktop => 'Parakeetモデル（デスクトップ）';

  @override
  String get speechParakeetStaysDownloadable =>
      'Parakeet はアプリバンドルの外に置かれ、ダウンロード可能な状態になります。現在は、ヨーロッパの25言語向けに最適化された1つの多言語モデルが公開されています。';

  @override
  String get speechPickLanguagePacks =>
      'デバイス上での認識のために、言語パックを選択し、モデルをダウンロードまたは削除します。';

  @override
  String get speechRemove => '削除';

  @override
  String speechRuntimeFailed(String service) {
    return '$service ランタイムの初期化に失敗しました。';
  }

  @override
  String get speechSelectSherpaAbove =>
      '言語パックの管理やモデルのダウンロードを行うには、上で Sherpa を選択してください。';

  @override
  String get speechSenseVoice => 'SenseVoice';

  @override
  String get speechSenseVoiceModelsDesktop => 'SenseVoiceモデル（デスクトップ）';

  @override
  String get speechSenseVoiceStaysDownloadable =>
      'SenseVoice はアプリバンドルの外に置かれ、ダウンロード可能な状態になります。中国語、広東語、日本語、韓国語、および英語向けのデスクトップオプションとしては、ここが最も強力です。';

  @override
  String get speechSherpa => 'Sherpa';

  @override
  String get speechSherpaExperimentalFail =>
      'Sherpaは実験的なものであり、一部のデバイスで失敗する可能性があります。最も安定した動作を希望する場合は、ネイティブを優先してください。';

  @override
  String get speechSherpaModelsLinux => 'Sherpaモデル（Linux）';

  @override
  String get speechSpeechText => '音声文字変換';

  @override
  String speechUnavailableOnPlatform(String service) {
    return '$service 音声はこのプラットフォームでは利用できません。';
  }

  @override
  String get speechWindowsSetupHint =>
      'Windows の音声入力は、オンデバイスモデルとともに CodeWalk WASAPI キャプチャを使用します。デスクトップアプリのマイクアクセスを有効にしたままにしてください。下のボタンでトラブルシューティング用の Windows 設定が開きます。';

  @override
  String get statusConnected => '接続済み';

  @override
  String get statusDelayed => '遅延';

  @override
  String get statusFailed => '失敗';

  @override
  String get statusOffline => 'オフライン';

  @override
  String get statusOnline => 'オンライン';

  @override
  String get statusReconnecting => '再接続中';

  @override
  String get statusStarting => '起動中';

  @override
  String get statusStopped => '停止済み';

  @override
  String get statusStopping => '停止中';

  @override
  String get statusSyncDelayed => '同期遅延';

  @override
  String get tailscaleNoPeers => 'ピアが見つかりません';

  @override
  String get tailscaleNotSupportedOnPlatform =>
      'Tailscale はこのプラットフォームではサポートされていません。';

  @override
  String get tailscaleNotSupportedOnWindows =>
      'Tailscale は Windows ではサポートされていません。';

  @override
  String get tailscalePeerOffline => 'オフライン';

  @override
  String get tailscaleSelectPeer => 'Tailscale ピアを選択';

  @override
  String get tailscaleWaitingAdminApproval => 'この Tailscale ノードは管理者の承認待ちです。';

  @override
  String get terminalClose => 'ターミナルを閉じる';

  @override
  String terminalConnectingTo(String serverName) {
    return '$serverName ターミナルに接続中...';
  }

  @override
  String terminalConnectionFailed(String error) {
    return 'ターミナル接続に失敗しました: $error';
  }

  @override
  String get terminalDisconnected => 'ターミナルが切断されました。';

  @override
  String terminalEmbeddedUnavailable(String serverName) {
    return '組み込みターミナルはこのランタイムではまだ利用できません。単発コマンドにはコンポーザーのシェルモードを引き続き使用するか、サポートされている CodeWalk アアプリランタイムから $serverName のターミナルを開いてください。';
  }

  @override
  String get terminalExtraKeyAlt => 'Alt キー';

  @override
  String get terminalExtraKeyArrowDown => '下矢印';

  @override
  String get terminalExtraKeyArrowLeft => '左矢印';

  @override
  String get terminalExtraKeyArrowRight => '右矢印';

  @override
  String get terminalExtraKeyArrowUp => '上矢印';

  @override
  String get terminalExtraKeyControl => 'Control キー';

  @override
  String get terminalExtraKeyEscape => 'Escape キー';

  @override
  String get terminalExtraKeyTab => 'Tab キー';

  @override
  String get terminalExtraKeys => 'ターミナルの追加キー';

  @override
  String get terminalHide => 'ターミナルを隠す';

  @override
  String get terminalMaximize => '最大化';

  @override
  String get terminalMinimize => 'ターミナルを最小化';

  @override
  String get terminalNotAvailableYet => '埋め込みターミナルはこのランタイムではまだ利用できません。';

  @override
  String get terminalOpen => 'ターミナルを開く';

  @override
  String get terminalOpenInfo => 'ターミナル情報を開く';

  @override
  String get terminalOpenProjectFirst => 'サーバーターミナルを開始する前に、プロジェクトフォルダを開いてください。';

  @override
  String get terminalOpenToConnect => 'ターミナルを開いて、サーバープロジェクトターミナルに接続してください。';

  @override
  String get terminalReconnect => 'ターミナルを再接続';

  @override
  String get terminalRestoreSize => '元のサイズに戻す';

  @override
  String get terminalSelectServer => 'ターミナルを開く前に、アクティブなサーバーを選択してください。';

  @override
  String get terminalSessionClosed => 'ターミナルセッションが終了しました。';

  @override
  String get terminalTerminal => 'ターミナル';

  @override
  String get terminalTitle => 'ターミナル';

  @override
  String get terminalTryAgain => '再試行';

  @override
  String get toolAwaitingInput => '入力待ち';

  @override
  String get toolEditing => '編集中';

  @override
  String get toolEditingFiles => 'ファイルを編集中';

  @override
  String get toolFinding => '検索中';

  @override
  String get toolFindingFiles => 'ファイルを検索中';

  @override
  String get toolPresentationAwaitingInput => '入力待ち';

  @override
  String get toolPresentationEditing => '編集中';

  @override
  String get toolPresentationEditingFiles => 'ファイルを編集中';

  @override
  String get toolPresentationFinding => '検索中';

  @override
  String get toolPresentationFindingFiles => 'ファイルを検索中';

  @override
  String get toolPresentationReading => '読み込み中';

  @override
  String get toolPresentationReadingFile => 'ファイルを読み込み中';

  @override
  String get toolPresentationRunning => '実行中';

  @override
  String get toolPresentationRunningCommand => 'コマンドを実行中';

  @override
  String toolPresentationRunningTool(String toolName) {
    return '$toolName を実行中';
  }

  @override
  String get toolPresentationSearching => '検索中';

  @override
  String get toolPresentationSearchingCode => 'コードを検索中';

  @override
  String get toolPresentationSearchingWeb => 'Webを検索中';

  @override
  String get toolPresentationTool => 'ツール';

  @override
  String get toolPresentationUpdatingTaskList => 'タスク一覧を更新中';

  @override
  String get toolPresentationUpdatingTasks => 'タスク更新中';

  @override
  String get toolPresentationWaitingInput => '入力を待っています';

  @override
  String get toolPresentationWriting => '書き込み中';

  @override
  String get toolPresentationWritingFile => 'ファイルに書き込み中';

  @override
  String get toolReading => '読み込み中';

  @override
  String get toolReadingFile => 'ファイルを読み込み中';

  @override
  String get toolRunning => '実行中';

  @override
  String get toolRunningCommand => 'コマンドを実行中';

  @override
  String get toolRunningTask => 'タスクを実行中';

  @override
  String get toolSearching => '検索中';

  @override
  String get toolSearchingCode => 'コードを検索中';

  @override
  String get toolSearchingWeb => 'Webを検索中';

  @override
  String get toolUpdatingTaskList => 'タスク一覧を更新中';

  @override
  String get toolUpdatingTasks => 'タスク更新中';

  @override
  String get toolWaitingForInput => '入力を待っています';

  @override
  String get toolWriting => '書き込み中';

  @override
  String get toolWritingFile => 'ファイルに書き込み中';

  @override
  String get tourBack => '戻る';

  @override
  String get tourSkip => 'スキップ';

  @override
  String get trayQuit => '終了';

  @override
  String get trayShow => '表示';

  @override
  String get useOAuthCloudflareAccess => 'OAuth (Cloudflare Access) を使用';

  @override
  String get useOAuthCloudflareAccessSubtitle =>
      'ブラウザを開いて Cloudflare Access Managed OAuth を実行します。';

  @override
  String get useOAuthCloudflareAccessUnsupported =>
      'Cloudflare Access OAuth はこのプラットフォームでは利用できません。代わりに基本認証（Basic Auth）を使用してください。';

  @override
  String get useTailscale => 'Tailscaleを使用';

  @override
  String get useTailscaleSubtitle =>
      'システム VPN なしで Tailscale ネットワーク経由でトラフィックをルーティングします。';

  @override
  String get useTailscaleUnsupported => 'Tailscale はこのプラットフォームでサポートされていません。';

  @override
  String get utilityTitle => 'ユーティリティ';

  @override
  String get workspaceBrowseDirs => 'ディレクトリを参照';

  @override
  String get workspaceChooseFolderOpen => 'プロジェクトコンテキストとして開くフォルダーを選択してください。';

  @override
  String workspaceCloseProject(String project) {
    return '$project を閉じる';
  }

  @override
  String get workspaceClosedProjects => '閉じているプロジェクト';

  @override
  String workspaceCurrentDirectory(String path) {
    return '現在のディレクトリ: $path';
  }

  @override
  String get workspaceFilterDirs => 'ディレクトリをフィルター';

  @override
  String get workspaceOpenFolder => 'フォルダーを開く';

  @override
  String get workspaceOpenProjectFolder => 'プロジェクトフォルダーを開く';

  @override
  String get workspaceOpenProjects => '開いているプロジェクト';

  @override
  String get workspaceProjectDirectory => 'プロジェクトディレクトリ';

  @override
  String get workspaceProjectHint => '/repo/my-project';

  @override
  String workspaceRemoveFromHistory(String name) {
    return '履歴から $name を削除';
  }

  @override
  String get settingsSessionAttentionTitle => 'セッション通知';

  @override
  String get settingsSessionAttentionDescription =>
      'ルートセッションの状態を任意のバブルまたはパネルに表示します。';

  @override
  String get settingsSessionAttentionOff => 'オフ';

  @override
  String get settingsSessionAttentionBubble => 'バブル';

  @override
  String get settingsSessionAttentionPanel => 'パネル';

  @override
  String get settingsSessionAttentionPrivacy =>
      'Android で有効にすると、永続的なフォアグラウンドサービスが開始されます。応答テキストは暗号化して保存され、クラウド TTS には「読み上げ」を押した後にのみ送信されます。';

  @override
  String get settingsSessionAttentionUnavailable =>
      'このプラットフォームではセッション通知を利用できません。';

  @override
  String get settingsSessionAttentionOpenSettings => '表示設定を開く';

  @override
  String get settingsSessionAttentionStop => 'セッション通知を停止';

  @override
  String get settingsSessionAttentionThirdPartyTtsWarning =>
      '「読み上げ」を押すと、応答テキストが設定済みの外部 TTS プロバイダーに送信される場合があります。';

  @override
  String get workspaceSuggestions => '提案';

  @override
  String get sessionTabsGestureHintTitle => 'セッションタブに新しい操作が追加されました';

  @override
  String get sessionTabsGestureHintBody =>
      'ダブルクリックまたはダブルタップでタブを閉じます。右クリックまたは長押しでセッション操作を開きます。タブは表示トグルで無効にできます。';

  @override
  String get sessionTabsGestureHintAcknowledge => 'OK';

  @override
  String get sessionTabsGestureHintDisableTabs => 'タブを無効化';

  @override
  String get sessionTabRenameAction => 'セッション名を変更';

  @override
  String sessionTabClosedMessage(String title) {
    return 'タブ「$title」を閉じました';
  }

  @override
  String get sessionTabUndo => '元に戻す';

  @override
  String get sessionTabRestoreFailed => 'タブを復元できませんでした。';

  @override
  String get sessionTabChangeIconAction => 'アイコンを変更';

  @override
  String get sessionTabIconPickerTitle => 'タブのアイコンを選択';

  @override
  String get sessionTabIconUseProjectIcon => 'プロジェクトのアイコンを使用';

  @override
  String get sessionTabIconApplied => 'タブのアイコンを更新しました。';

  @override
  String get sessionTabIconSaveFailed => 'タブのアイコンを保存できませんでした。';

  @override
  String get sessionTabIconPresetCode => 'コード';

  @override
  String get sessionTabIconPresetTerminal => 'ターミナル';

  @override
  String get sessionTabIconPresetBug => 'バグ';

  @override
  String get sessionTabIconPresetTasks => 'タスク';

  @override
  String get sessionTabIconPresetLaunch => '起動';

  @override
  String get sessionTabIconPresetIdea => 'アイデア';

  @override
  String get sessionTabIconPresetResearch => '調査';

  @override
  String get sessionTabIconPresetDesign => 'デザイン';

  @override
  String get sessionTabIconPresetData => 'データ';

  @override
  String get sessionTabIconPresetCloud => 'クラウド';

  @override
  String get sessionTabIconPresetSecurity => 'セキュリティ';

  @override
  String get sessionTabIconPresetTools => 'ツール';

  @override
  String get workspaceNoActiveContext => 'アクティブなコンテキストがありません';

  @override
  String get settingsAppearanceContrastLow => '低';

  @override
  String get settingsAppearanceContrastStandard => '標準';

  @override
  String get settingsAppearanceContrastMedium => '中';

  @override
  String get settingsAppearanceContrastMediumHigh => '中高';

  @override
  String get settingsNotificationsSystemSoundsWebUnavailable =>
      'Web では利用できません。';

  @override
  String get settingsNotificationsSystemSoundsAndroid => 'システムの Android 通知音。';

  @override
  String get settingsNotificationsSystemSoundsFreedesktop =>
      '/usr/share/sounds/freedesktop/stereo の Freedesktop サウンド。';

  @override
  String get settingsNotificationsSystemSoundsPlatform =>
      'OS がシステムサウンドを公開しているプラットフォームで利用できます。';

  @override
  String get serversQuickGuideTitle => 'クイックセットアップ';

  @override
  String get serversQuickGuideIntro =>
      'CodeWalk はアプリ、OpenCode はエンジンです。この接続を利用するには OpenCode の起動が必要です。';

  @override
  String get serversQuickGuideStepInstallCli => '1. OpenCode CLI をインストール。';

  @override
  String get serversQuickGuideRunPowerShell => '2. PowerShell で実行:';

  @override
  String get serversQuickGuideRunTerminal => '2. ターミナルで実行:';

  @override
  String get serversQuickGuideProtectPassword => 'パスワードでアクセスを保護';

  @override
  String get serversQuickGuideServerPassword => 'サーバーパスワード';

  @override
  String get serversQuickGuideInstallOptions =>
      'その他の公式インストール方法: インストールスクリプト、npm、bun、pnpm、Homebrew、または GitHub Releases のバイナリ。';

  @override
  String get serversQuickGuideVerifyHint =>
      'サーバー起動後、URL を CodeWalk に貼り付ける前に /global/health または /doc が応答することを確認してください。';

  @override
  String get shortcutsPressKeyCombination => 'キーの組み合わせを押してください';

  @override
  String get settingsProvenanceOpenCodeBacked => 'OpenCode ベース';

  @override
  String get settingsProvenanceCodeWalkLocal => 'CodeWalk ローカル';

  @override
  String get settingsProvenanceCodeWalkException => 'CodeWalk 例外';

  @override
  String get shortcutsErrorInvalid => '無効なショートカット';

  @override
  String get shortcutsErrorUnsupportedKey => 'サポートされていないショートカットキー';

  @override
  String shortcutsErrorConflict(String conflict) {
    return '「$conflict」と競合';
  }

  @override
  String get settingsSessionAttentionStopSaveFailed =>
      'セッション通知は停止しましたが、設定を保存できませんでした。';

  @override
  String get settingsSessionAttentionEnableFailed => 'セッション通知を有効にできませんでした。';

  @override
  String get settingsSessionAttentionSaveFailedStopped =>
      'セッション通知を保存できず、停止しました。';

  @override
  String get settingsSessionAttentionStillRunning =>
      'セッション通知はまだ実行中です。もう一度停止してください。';

  @override
  String get settingsSessionAttentionStopFailed =>
      'セッション通知を停止できませんでした。もう一度お試しください。';

  @override
  String get settingsSessionAttentionCapabilityUnavailable =>
      'セッション通知ホストの機能を利用できません。';

  @override
  String get settingsServerFallbackProviderName => 'サーバーで設定';

  @override
  String get composerStopResponse => '応答を停止';

  @override
  String get composerSendMessageWhileResponding => '応答中にメッセージを送信';

  @override
  String get composerSendMessage => 'メッセージを送信';

  @override
  String get chatTourComposerDescription => 'ここにリクエストを入力します。';

  @override
  String get chatTourSendDescription => 'ここからメッセージを送信します。';

  @override
  String get composerAttachmentFallbackName => '添付ファイル';

  @override
  String get composerContextFallbackName => 'コンテキスト';

  @override
  String get searchableDropdownSearchHint => '検索';

  @override
  String get searchableDropdownEmptyText => '一致する項目はありません';

  @override
  String get speechApiKeyStorageUnavailable => 'セキュアな TTS APIキー保存を利用できません。';

  @override
  String get speechApiKeyRemoved => 'APIキーを削除しました。';

  @override
  String get speechApiKeySaved => 'APIキーをこのデバイスに安全に保存しました。';

  @override
  String get speechReadAloudTestText => 'これは CodeWalk の音声合成テストです。';

  @override
  String get speechNativeDisabledWindows =>
      '安定性のため Windows では無効です。CodeWalk WASAPI キャプチャ経由で Parakeet または他のオンデバイスエンジンを使用してください。';

  @override
  String get speechNativeUnavailableLinux =>
      'Linux では利用できません。音声入力には Parakeet を使用してください。';

  @override
  String get speechNotAvailableOnPlatform => 'このプラットフォームでは利用できません。';

  @override
  String get speechSherpaUnavailableAndroid =>
      'APK サイズを最適化した Android ビルドでは利用できません。';

  @override
  String get speechMoonshineDesktopOnlyHint =>
      'デスクトップのみで利用可能です。Android はネイティブのみです。';

  @override
  String get speechParakeetDesktopOnlyHint =>
      'デスクトップのみで利用可能です。オフラインの多言語認識を使用します。';

  @override
  String get speechSenseVoiceDesktopOnlyHint =>
      'デスクトップのみで利用可能です。中国語、広東語、日本語、韓国語、英語に最も強力です。';

  @override
  String get speechNativeSubtitle => 'よりシンプルで起動が速い。';

  @override
  String get speechSherpaSubtitle =>
      'より重く、実験的でバグが出やすい。ダウンロードしたモデルではより正確なことが多い。';

  @override
  String get speechMoonshineSubtitle =>
      'sherpa_onnx のオフライン認識とダウンロード可能なモデルを使う、デスクトップ限定の実験パス。';

  @override
  String get speechParakeetSubtitle =>
      '1つの多言語ダウンロード可能モデルを持つ、デスクトップ限定のオフライン NeMo transducer パス。';

  @override
  String get speechSenseVoiceSubtitle =>
      '中国語、広東語、日本語、韓国語、英語向けに調整されたデスクトップ限定のオフラインパス。';

  @override
  String get speechMoonshineModel => 'Moonshine モデル';

  @override
  String get speechSherpaLanguage => 'Sherpa 言語';

  @override
  String get speechSearchSherpaLanguage => 'Sherpa 言語を検索';

  @override
  String get speechNoLanguagePacksFound => '言語パックが見つかりません';

  @override
  String get speechTextToSpeechProvider => '音声合成プロバイダー';

  @override
  String get speechProviderSystemNative => 'システム / ネイティブ';

  @override
  String get speechProviderEdgeExperimental => 'Microsoft Edge Speech（実験的）';

  @override
  String get speechProviderOpenAiCompatible => 'OpenAI 互換';

  @override
  String get speechEdgeExperimentalTitle => 'Microsoft Edge Speech は実験的な機能です';

  @override
  String get speechEdgeExperimentalDescription =>
      'このデバイスから非公式の Edge 読み上げサービスを直接使用します。読み上げを利用するとメッセージテキストが Microsoft に送信され、Microsoft が非公開プロトコルを変更した場合はサービスが使えなくなる可能性があります。';

  @override
  String get speechEdgeVoice => 'Edge の音声';

  @override
  String get speechEdgeVoiceUnavailable =>
      '選択した音声は使用できなくなりました。默認の Edge 音声を使用します。';

  @override
  String get speechEdgeVoiceListUnavailable =>
      'デフォルトの Edge 音声を使用します。現在、音声リストを読み込めませんでした。';

  @override
  String get speechEdgeVoicesLoaded => 'Microsoft Edge Speech の音声から読み込みました。';

  @override
  String get speechCloudTtsPrivacy => 'クラウドTTSのプライバシー';

  @override
  String get speechCloudTtsPrivacyDescription =>
      'クラウドTTSは、選択したアシスタントメッセージのテキストを設定済みプロバイダーに送信します。APIキーはこのデバイスのセキュアストレージに保存されます。';

  @override
  String get speechBaseUrl => 'ベースURL';

  @override
  String get speechApiKey => 'APIキー';

  @override
  String get speechApiKeySavedHelper =>
      'キーは保存されています。新しい値を入力して置き換えるか、空の値を保存して削除します。';

  @override
  String get speechNoApiKeySaved => 'APIキーは保存されていません。';

  @override
  String get speechSaveApiKey => 'APIキーを保存';

  @override
  String get speechModel => 'モデル';

  @override
  String get speechPitchNotSupported =>
      'OpenAI 互換 TTS ではピッチをサポートしていないため、このプロバイダーでは非表示です。';

  @override
  String get speechTestVoice => '音声をテスト';

  @override
  String get dialogMoonshineVoiceSetupDescription =>
      'Moonshine は sherpa_onnx 経由でデバイス上で動作します。モデルを1つ選び、このデスクトップデバイスにのみダウンロードしてください。';

  @override
  String get dialogParakeetVoiceSetupDescription =>
      'Parakeet は sherpa_onnx のオフライン認識でデバイス上で動作します。多言語STTを有効にするには、このデスクトップデバイスに1回ダウンロードしてください。';

  @override
  String get dialogSenseVoiceSetupDescription =>
      'SenseVoice は sherpa_onnx のオフライン認識でデバイス上で動作します。中国語、広東語、日本語、韓国語、英語に最も強力です。';

  @override
  String get dialogSherpaVoiceSetupDescription =>
      'Sherpa 音声入力にはオンデバイスの音声モデルが必要です。言語を選択し、1回だけダウンロードしてください（約147 MB）。';

  @override
  String speechSilenceSeconds(String value) {
    return '$value 秒';
  }

  @override
  String speechModelInstalled(String modelId) {
    return 'モデルをインストール済み ($modelId)';
  }

  @override
  String speechModelMissing(String modelId) {
    return 'モデルがありません ($modelId)';
  }

  @override
  String speechModelSizeMb(String sizeMb) {
    return '~$sizeMb MB';
  }

  @override
  String speechSystemDefaultLanguage(String language) {
    return 'システムデフォルト（$language）';
  }

  @override
  String speechModelListLoadFailed(String error, String service) {
    return '$service のモデルリストの読み込みに失敗しました: $error';
  }

  @override
  String speechDownloadFailed(String error) {
    return 'ダウンロードに失敗しました: $error';
  }

  @override
  String speechFailedToRemoveModel(String error) {
    return 'モデルの削除に失敗しました: $error';
  }

  @override
  String speechBaseUrlExample(String url) {
    return '例: $url';
  }

  @override
  String speechModelDefaultHelper(String model) {
    return 'デフォルト: $model';
  }

  @override
  String get notificationPermissionOrQuestionNeedsInput =>
      'ツールの権限または質問への回答が必要です。';

  @override
  String get notificationPermissionNeedsInput => 'ツールの権限承認が必要です。';

  @override
  String get notificationQuestionNeedsInput => 'ツールの質問への回答が必要です。';

  @override
  String get notificationSessionError => 'セッションでエラーが報告されました。';

  @override
  String get notificationChannelErrors => 'CodeWalk エラー';

  @override
  String get notificationChannelErrorsDescription => 'CodeWalk エラーアラート';

  @override
  String get notificationChannelPermissions => 'CodeWalk 権限';

  @override
  String get notificationChannelPermissionsDescription => 'CodeWalk 操作要求アラート';

  @override
  String get notificationChannelAgent => 'CodeWalk エージェント';

  @override
  String get notificationChannelAgentDescription => 'CodeWalk エージェント完了アラート';

  @override
  String get notificationActionOpen => '開く';

  @override
  String get foregroundMonitorNotificationBody => 'バックグラウンドアラートが有効です';

  @override
  String get foregroundMonitorNotificationTitle => 'バックグラウンド監視が有効です';

  @override
  String get foregroundMonitorNotificationOneSession => '1つのセッションを監視中';

  @override
  String foregroundMonitorNotificationSessionCount(int count) {
    return '$count件のセッションを監視中';
  }

  @override
  String sessionAttentionSemanticLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のセッションが注意を要します',
      one: '1件のセッションが注意を要します',
    );
    return '$_temp0';
  }

  @override
  String get sessionAttentionOverlayPermissionRequired =>
      '「他のアプリの上に表示」権限が必要です。';

  @override
  String get sessionAttentionIosInAppOnly => 'セッション通知は CodeWalk 内でのみ利用できます。';

  @override
  String get sessionAttentionOverlayPermissionGrantPrompt =>
      '「他のアプリの上に表示」権限を許可してから、もう一度お試しください。';

  @override
  String get sessionAttentionAndroidStartFailed =>
      'Android セッション通知サービスを開始できませんでした。';

  @override
  String chatMessageTruncatedChars(int count, String reason) {
    return '[$count文字を切り詰め] $reason';
  }

  @override
  String get chatMessageJustNow => 'たった今';

  @override
  String chatMessageMinutesAgo(int count) {
    return '$count分前';
  }

  @override
  String chatMessageHoursAgo(int count) {
    return '$count時間前';
  }

  @override
  String chatMessageDaysAgo(int count) {
    return '$count日前';
  }

  @override
  String chatMessageDateTime(int day, int hour, int minute, int month) {
    return '$month/$day $hour:$minute';
  }

  @override
  String get chatMessageYourMessage => 'あなたのメッセージ';

  @override
  String get chatMessageAssistantMessage => 'アシスタントメッセージ';

  @override
  String chatMessageStepStarted(int step) {
    return 'ステップ #$step 開始';
  }

  @override
  String chatMessageStepStartedWithSnapshot(String snapshot, int step) {
    return 'ステップ #$step 開始: $snapshot';
  }

  @override
  String chatMessageStepFinished(
    String cost,
    String reason,
    int step,
    int tokens,
  ) {
    return 'ステップ #$step 終了: $reason • トークン $tokens • \$$cost';
  }

  @override
  String chatMessagePatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countパッチ',
      one: '1パッチ',
    );
    return '$_temp0';
  }

  @override
  String get chatMessageToolRun => 'ツールの実行';

  @override
  String get chatMessageToolExecution => 'ツール実行';

  @override
  String chatMessageToolChainMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count件',
      one: '+1件',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolChainExtraTypes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count種類',
      one: '+1種類',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolAttentionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件が注意を要します',
      one: '1件が注意を要します',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolDoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件完了',
      one: '1件完了',
    );
    return '$_temp0';
  }

  @override
  String get chatMessageToolCallsTitle => 'ツール呼び出し';

  @override
  String get chatMessageDiffPreviewTruncated => 'アプリ安定性のため差分プレビューを切り詰めました。';

  @override
  String get chatMessageLargeMessageTruncated =>
      'アプリ安定性のため大きなメッセージのプレビューを切り詰めました。';

  @override
  String get chatMessageInvalidLinkFormat => '無効なリンク形式です';

  @override
  String get chatMessageUnableToOpenLink => 'リンクを開けません';

  @override
  String sessionTodoInProgressCompact(int current, int total) {
    return '$current/$total 進行中';
  }

  @override
  String sessionTodoTaskProgress(String content, int index, int total) {
    return 'タスク $index/$total $content';
  }

  @override
  String sessionTodoDoneCompact(int count, int total) {
    return '$count/$total 完了';
  }

  @override
  String sessionTodoCompletedCount(int count, int total) {
    return 'タスク $count/$total 完了';
  }

  @override
  String sessionTodoTasksCount(int count) {
    return 'タスク ($count)';
  }

  @override
  String questionStepOfReview(int current, int total) {
    return 'ステップ $current/$total - 確認';
  }

  @override
  String questionStepOfQuestion(int current, int total) {
    return 'ステップ $current/$total - 質問';
  }

  @override
  String get questionCustomAnswer => 'カスタム回答';

  @override
  String get questionSubmitAnswers => '回答を送信';

  @override
  String get questionReviewAnswers => '回答を確認';

  @override
  String permissionRequestTitle(String permission) {
    return '権限リクエスト: $permission';
  }

  @override
  String get sessionTitleCannotBeEmpty => 'タイトルは空にできません';

  @override
  String get filesFailedToLoad => 'ファイルの読み込みに失敗しました';

  @override
  String get filesFailedToSearch => 'ファイルの検索に失敗しました';

  @override
  String get filesNoOpenFilesHint => '開いているファイルはまだありません。入力して検索してください。';

  @override
  String get filesNoContentMatches => '一致するコンテンツが見つかりません';

  @override
  String filesOpenFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件の開いているファイル',
      one: '1件の開いているファイル',
    );
    return '$_temp0';
  }

  @override
  String filesLinesSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count行が選択されました',
      one: '1行が選択されました',
    );
    return '$_temp0';
  }

  @override
  String get filesDraftTooLargeToSave => '下書きが大きすぎるため、エディターから保存できません。';

  @override
  String get filesSaveChangesBeforeClose => 'このファイルを閉じる前に変更を保存してください。';

  @override
  String get filesSaveChangesBeforePathChange => 'このパスを変更する前に変更を保存してください。';

  @override
  String get filesWaitForSaveBeforePathChange =>
      'このパスを変更する前に、ファイルの保存が終了するまでお待ちください。';

  @override
  String get filesWaitForFileOperation => 'ファイル操作が終了するまでお待ちください。';

  @override
  String get filesLargeFileReadOnly => '大きなファイルは編集の応答性を保つため読み取り専用で開きます。';

  @override
  String get filesCheckingWriteSupport => 'ファイル書き込みのサポートを確認中...';

  @override
  String get filesActiveProjectRequired => 'ファイル操作にはアクティブなプロジェクトディレクトリが必要です。';

  @override
  String get filesReloadSkippedUnsavedChanges => '未保存の変更があるため、再読み込みをスキップしました。';

  @override
  String get filesFailedToLoadContent => 'ファイルの内容の読み込みに失敗しました';

  @override
  String get filesFileSaved => 'ファイルを保存しました。';

  @override
  String get filesParentNotDirectory => '親要素がディレクトリではありません。';

  @override
  String get filesMalformedResponse => 'ファイル操作が無効な応答を返しました。';

  @override
  String get filesShellCommandDidNotComplete => 'ファイル操作のシェルコマンドが完了しませんでした。';

  @override
  String get filesShellCommandNoResult => 'ファイル操作のシェルコマンドが結果を返しませんでした。';

  @override
  String get filesShellCommandTruncated => 'ファイル操作のシェルコマンドがサーバーによって切り詰められました。';

  @override
  String get filesShellCommandSyntaxError => 'ファイル操作のシェルコマンドが構文エラーで失敗しました。';

  @override
  String get filesShellUtilityNotFound => '必要なシェルユーティリティが見つかりませんでした。';

  @override
  String get filesShellCommandFailed => 'ファイル操作のシェルコマンドが結果を返す前に失敗しました。';

  @override
  String get attachmentSaveTitle => '添付ファイルを保存';

  @override
  String get attachmentBrowserSandboxLocalFile =>
      'ブラウザのサンドボックスにより、file:// の添付ファイルを直接開けません。';

  @override
  String get attachmentLocalPathBrowserBlocked =>
      'この添付ファイルはブラウザから開けないローカルパスを指しています。';

  @override
  String terminalConnectedTo(String directory, String serverName) {
    return '$serverName の $directory に接続しました';
  }

  @override
  String get terminalTransportUnavailable => 'ターミナルのトランスポートを利用できません。';

  @override
  String get chatSlashCommandNew => '新しいチャットセッションを作成';

  @override
  String get chatSlashCommandModels => 'モデル選択を開く';

  @override
  String get chatSlashCommandSessions => '会話一覧を開く';

  @override
  String get chatSlashCommandAgent => 'エージェント選択を開く';

  @override
  String get chatSlashCommandOpen => 'ファイルをクイックオープン';

  @override
  String get chatSlashCommandHelp => 'コマンドのヘルプを表示';

  @override
  String get chatSlashCommandCompact => '現在のセッションのコンテキストを圧縮';

  @override
  String get chatSlashCommandThinking => '思考プロセスバブルの表示を切り替え';

  @override
  String get chatSlashCommandUndo => '最後に表示されたユーザーターンを元に戻す';

  @override
  String get chatSlashCommandRedo => '元に戻した最後のターンをやり直す';

  @override
  String chatSessionSubConversationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のサブ会話',
      one: '1つのサブ会話',
    );
    return '$_temp0';
  }

  @override
  String chatMessageWeeksAgo(int count) {
    return '$count週前';
  }

  @override
  String chatMessageShortDate(int day, int month) {
    return '$month/$day';
  }

  @override
  String get chatProviderErrorLoadSessionStatus => 'セッションの状態の読み込みに失敗しました';

  @override
  String get chatProviderErrorLoadSessionDetails => '一部のセッション詳細を読み込めませんでした';

  @override
  String chatProviderErrorLoadSessionList(String error) {
    return 'セッション一覧の読み込みに失敗しました: $error';
  }

  @override
  String get chatProviderErrorCreateSession => 'セッションの作成に失敗しました';

  @override
  String get chatProviderErrorSelectProviderModelBeforeSend =>
      '送信する前に、接続済みのプロバイダーまたは無料の OpenCode モデルを選択してください';

  @override
  String get chatProviderErrorStartMessageSend => 'メッセージ送信を開始できませんでした';

  @override
  String get chatProviderErrorStopUnavailable => '現在のセッションでは停止を利用できません';

  @override
  String get chatProviderErrorWaitForResponseFinish =>
      '圧縮する前に、現在の応答が終了するのを待ってください';

  @override
  String get chatProviderErrorCompactUnavailable =>
      '現在のセッションではコンテキストの圧縮を利用できません';

  @override
  String get chatProviderErrorSelectModelBeforeCompact =>
      'コンテキストを圧縮する前にモデルを選択してください';

  @override
  String get chatProviderErrorCompactSessionContext => 'セッションコンテキストの圧縮に失敗しました';

  @override
  String get chatProviderErrorNetwork => 'ネットワーク接続に失敗しました。ネットワーク設定を確認してください';

  @override
  String get chatProviderErrorServer => 'サーバーエラーです。後でもう一度お試しください';

  @override
  String get chatProviderErrorNotFound => 'リソースが見つかりません';

  @override
  String get chatProviderErrorInvalidInput => '入力パラメータが無効です';

  @override
  String get chatProviderErrorUnknown => '不明なエラーです。後でもう一度お試しください';

  @override
  String get chatProviderErrorSessionFallback => 'セッションエラー';

  @override
  String get projectProviderErrorNoProjectContext => 'サーバーからプロジェクトコンテキストがありません';

  @override
  String projectProviderErrorInitializeFailed(String error) {
    return 'プロジェクトコンテキストの初期化に失敗しました: $error';
  }

  @override
  String get projectProviderErrorSwitchProjectNotFound =>
      'プロジェクトの切り替えに失敗しました: プロジェクトが見つかりません';

  @override
  String get projectProviderErrorSwitchDirectoryEmpty =>
      'プロジェクトの切り替えに失敗しました: ディレクトリが空です';

  @override
  String get projectProviderErrorAtLeastOneContext =>
      '少なくとも1つのコンテキストを開いたままにする必要があります';

  @override
  String get projectProviderErrorReopenProjectNotFound =>
      'プロジェクトの再オープンに失敗しました: プロジェクトが見つかりません';

  @override
  String get projectProviderErrorOnlyClosedArchivable =>
      'アーカイブできるのは閉じているプロジェクトのみです';

  @override
  String get projectProviderErrorArchiveProjectNotFound =>
      'プロジェクトのアーカイブに失敗しました: プロジェクトが見つかりません';

  @override
  String get projectProviderErrorArchiveProjectPathInvalid =>
      'プロジェクトのアーカイブに失敗しました: プロジェクトのパスが無効です';

  @override
  String projectProviderErrorLoadWorkspaces(String error) {
    return 'ワークスペース一覧の読み込みに失敗しました: $error';
  }

  @override
  String get projectProviderErrorWorkspaceNameEmpty => 'ワークスペース名は空にできません';

  @override
  String projectProviderErrorCreateWorkspace(String error) {
    return 'ワークスペースの作成に失敗しました: $error';
  }

  @override
  String projectProviderErrorResetWorkspace(String error) {
    return 'ワークスペースのリセットに失敗しました: $error';
  }

  @override
  String projectProviderErrorDeleteWorkspace(String error) {
    return 'ワークスペースの削除に失敗しました: $error';
  }

  @override
  String get projectProviderErrorDirectoryEmpty => 'ディレクトリは空にできません';

  @override
  String projectProviderErrorListDirectories(String error) {
    return 'ディレクトリ一覧の取得に失敗しました: $error';
  }

  @override
  String projectProviderErrorValidateDirectory(String error) {
    return 'ディレクトリの検証に失敗しました: $error';
  }

  @override
  String get projectProviderErrorPathEmpty => 'パスは空にできません';

  @override
  String projectProviderErrorListFiles(String error) {
    return 'ファイル一覧の取得に失敗しました: $error';
  }

  @override
  String projectProviderErrorSearchFiles(String error) {
    return 'ファイルの検索に失敗しました: $error';
  }

  @override
  String projectProviderErrorContentSearchUnavailable(String error) {
    return 'コンテンツ検索を利用できません: $error';
  }

  @override
  String projectProviderErrorSearchSymbols(String error) {
    return 'シンボルの検索に失敗しました: $error';
  }

  @override
  String projectProviderErrorReadFile(String error) {
    return 'ファイルの読み込みに失敗しました: $error';
  }

  @override
  String projectProviderErrorLoadProjectList(String error) {
    return 'プロジェクト一覧の読み込みに失敗しました: $error';
  }

  @override
  String get workspaceProjectRemovedFromHistory => '履歴からプロジェクトを削除しました';

  @override
  String workspaceProjectContextOpened(String directory) {
    return 'プロジェクトコンテキストを開きました: $directory';
  }

  @override
  String workspaceFailedToOpenProjectContext(String directory) {
    return 'プロジェクトコンテキストを開けませんでした: $directory';
  }

  @override
  String get chatAbortNotice => 'どう変更しますか？';

  @override
  String sessionTitleToday(String date, String time) {
    return '今日 $time（$date）';
  }

  @override
  String sessionTitleYesterday(String date, String time) {
    return '昨日 $time（$date）';
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
  String get sessionWeekdayMon => '月';

  @override
  String get sessionWeekdayTue => '火';

  @override
  String get sessionWeekdayWed => '水';

  @override
  String get sessionWeekdayThu => '木';

  @override
  String get sessionWeekdayFri => '金';

  @override
  String get sessionWeekdaySat => '土';

  @override
  String get sessionWeekdaySun => '日';

  @override
  String get forwardTimeNow => 'たった今';

  @override
  String forwardTimeMinutes(int count) {
    return '$count分';
  }

  @override
  String forwardTimeHours(int count) {
    return '$count時間';
  }

  @override
  String forwardTimeDays(int count) {
    return '$count日';
  }

  @override
  String forwardTimeWeeks(int count) {
    return '$count週';
  }

  @override
  String get settingsBehaviorConfigFieldDefaultModel => 'デフォルトモデル';

  @override
  String get settingsBehaviorConfigFieldDefaultAgent => 'デフォルトエージェント';

  @override
  String get settingsBehaviorConfigFieldSmallModel => 'スモールモデル';

  @override
  String get settingsBehaviorConfigFieldAutoUpdateMode => '自動更新モード';

  @override
  String get settingsBehaviorConfigFieldSnapshotSetting => 'スナップショット設定';

  @override
  String get settingsBehaviorConfigFieldConversationUsername => '会話用ユーザー名';

  @override
  String get settingsBehaviorConfigFieldSharingDefault => '共有デフォルト';

  @override
  String get speechMicNoInputDevice => 'マイク入力デバイスがありません。';

  @override
  String get speechMicDeviceBusy => 'デフォルトのマイクは別のアプリで使用中です。';

  @override
  String get speechMicUnsupportedFormat => 'デフォルトのマイク形式がサポートされていません。';

  @override
  String get speechMicSpeechPrivacy =>
      'Windows の音声サービスが無効になっている可能性があります（音声プライバシー、オンライン音声認識、または言語パック）。';

  @override
  String get speechMicBackendUnavailable =>
      'このビルドでは Windows マイクバックエンドを利用できません。';

  @override
  String speechEngineFallbackNotice(String fallback, String reason) {
    return '選択した STT エンジンを利用できません（$reason）。代わりに $fallback を使用します。';
  }

  @override
  String get oauthFlowSecureStorageUnavailable =>
      'OAuth 用のセキュアな認証情報ストレージを利用できません。';

  @override
  String get oauthFlowUnexpectedError => 'OAuth フローが予期せず失敗しました。もう一度お試しください。';

  @override
  String get oauthFlowNoEndpointsDiscovered =>
      'OAuth エンドポイントが見つかりませんでした。Cloudflare Dashboard → Access → Applications → [このアプリ] で Managed OAuth を有効にしてください。';

  @override
  String get oauthFlowTokenResponseMissingAccessToken =>
      'OAuth トークン応答にアクセストークンが含まれていませんでした。';

  @override
  String get oauthFlowProfileChanged => 'OAuth が完了する前にサーバープロファイルが変更されました。';

  @override
  String get oauthFlowMetadataMissingEndpoints =>
      'OAuth メタデータに認証/トークンエンドポイントがありません。';

  @override
  String get oauthFlowCallbackNotCompleted => '認証コールバックが完了しませんでした';

  @override
  String get oauthFlowProviderDeclined =>
      '認証サーバーが OAuth リクエストを拒否しました。もう一度お試しください。';

  @override
  String get oauthFlowCallbackValidationFailed =>
      'OAuth コールバックの検証に失敗しました。もう一度お試しください。';

  @override
  String get oauthFlowCallbackServerStartFailed =>
      'ローカルの OAuth コールバックサーバーを起動できませんでした。';

  @override
  String get oauthFlowSignInCanceled => 'OAuth サインインがキャンセルされました。';

  @override
  String get oauthFlowBrowserOpenFailed => 'OAuth サインイン用にシステムブラウザを開けませんでした。';

  @override
  String get oauthFlowCallbackTimeout =>
      '5分以内に認証コールバックがアプリに届きませんでした。ブラウザは同意後にローカルのコールバックアドレスへリダイレクトされるはずです。代わりにブラウザに接続エラーが表示された場合は、このデバイスまたはネットワークがループバックリダイレクトをブロックしています。';

  @override
  String oauthFlowTokenExchangeTransientFailure(int maxAttempts) {
    return '一時的なネットワーク問題のため、$maxAttempts回試行しましたがトークン交換に失敗しました。もう一度お試しください。';
  }

  @override
  String oauthFlowTokenExchangeHttpFailure(int statusCode) {
    return 'トークン交換に失敗しました（HTTP $statusCode）。もう一度お試しください。';
  }

  @override
  String get oauthFlowTokenExchangeUnexpectedFailure =>
      'トークン交換が予期せず失敗しました。もう一度お試しください。';

  @override
  String get oauthFlowTokenExchangeIncomplete =>
      '認証コード送信後、トークン交換が完了しませんでした。OAuth サインインを再度開始してください。';

  @override
  String get speechReadAloudFailed => '音声合成に失敗しました。';

  @override
  String get speechReadAloudNoText => '読み上げるテキストがありません。';

  @override
  String get speechEdgeTextTooLong =>
      'Microsoft Edge Speech は一度に最大4096バイトまで読み上げられます。';

  @override
  String get speechEdgeMalformedAudio =>
      'Microsoft Edge Speech が不正な音声データを返しました。';

  @override
  String get speechEdgeUnsupportedAudio =>
      'Microsoft Edge Speech がサポートされていない音声データを返しました。';

  @override
  String get speechEdgeUnsupportedFrame =>
      'Microsoft Edge Speech がサポートされていない WebSocket フレームを返しました。';

  @override
  String get speechEdgeSynthesisInterrupted =>
      'Microsoft Edge Speech は合成が完了する前に終了しました。';

  @override
  String get speechEdgeEmptyAudio => 'Microsoft Edge Speech が空の音声応答を返しました。';

  @override
  String get speechEdgeTimedOut => 'Microsoft Edge Speech がタイムアウトしました。';

  @override
  String get speechEdgeUnreachable => 'Microsoft Edge Speech に接続できませんでした。';

  @override
  String get speechApiKeyMissing =>
      'この TTS プロバイダーを使用するには、[設定] > [音声] で APIキーを追加してください。';

  @override
  String get speechProviderEmptyAudio => 'TTS プロバイダーが空の音声応答を返しました。';

  @override
  String get speechProviderRequestRejected => 'TTS プロバイダーが音声リクエストを拒否しました。';

  @override
  String get speechApiKeyRejected => 'TTS の APIキーがプロバイダーに拒否されました。';

  @override
  String get speechProviderQuotaRateLimit => 'TTS プロバイダーがクォータまたはレート制限を報告しました。';

  @override
  String get speechProviderTemporarilyUnavailable => 'TTS プロバイダーが一時的に利用できません。';

  @override
  String get speechProviderUnreachable => 'TTS プロバイダーに接続できませんでした。';

  @override
  String appProviderErrorFailedToStartProcess(String tool) {
    return '$tool プロセスの起動に失敗しました。';
  }

  @override
  String appProviderErrorToolNotAvailable(String runtime, String tool) {
    return '$tool が利用できません。先に $runtime をインストールしてください。';
  }

  @override
  String appProviderErrorToolInstallFailed(int exitCode, String tool) {
    return '$tool のインストールが終了コード $exitCode で失敗しました。';
  }

  @override
  String appProviderErrorBunBootstrapFailed(int exitCode) {
    return 'Bun のブートストラップが終了コード $exitCode で失敗しました。';
  }

  @override
  String get appProviderErrorInstalledButNotFoundInPath =>
      'OpenCode のインストールは完了しましたが、コマンドが PATH に見つかりませんでした。';

  @override
  String get appProviderErrorInstalledButPathNotResolved =>
      'OpenCode のインストールは完了しましたが、コマンドパスを解決できませんでした。';

  @override
  String appProviderErrorConfiguredCommandNotFound(String tool) {
    return '構成されたコマンドが見つからず、$tool が PATH にありません。';
  }

  @override
  String get appProviderErrorConfiguredCommandPathMissing =>
      '構成されたコマンドのパスが存在しません。';

  @override
  String get appProviderErrorConfiguredCommandVersionCheckFailed =>
      '構成されたコマンドは存在しますが、バージョン確認に失敗しました。';

  @override
  String get appProviderErrorConfiguredCommandExecutionFailed =>
      '構成されたコマンドを実行できませんでした。';

  @override
  String get appProviderWslCheckWindowsOnly => 'WSL チェックは Windows にのみ適用されます。';

  @override
  String get appProviderDesktopBuildRequired =>
      '管理対象ローカルサーバーを構成するには、デスクトップビルドを使用してください。';

  @override
  String get appProviderKnownInstallationDirectoryDetected =>
      '既知のインストールディレクトリから検出されました。';

  @override
  String appProviderKnownInstallationPathRefreshHint(String appName) {
    return '既知のインストールディレクトリから検出されました。PATH の更新が必要になる場合があります。最近のインストールがまだ検出されない場合は、$appName を開き直してください。';
  }

  @override
  String get appProviderErrorReleaseMetadataFetchFailed =>
      'GitHub から最新リリースのメタデータを取得できませんでした。';

  @override
  String get appProviderErrorReleaseAssetListMissing =>
      '最新リリースのメタデータにアセットリストが含まれていませんでした。';

  @override
  String get appProviderErrorNoCompatibleAsset =>
      '互換性のある OpenCode バイナリアセットが見つかりませんでした。';

  @override
  String get appProviderErrorDownloadAssetFailed =>
      '選択した OpenCode アセットのダウンロードに失敗しました。';

  @override
  String get appProviderErrorChecksumVerificationFailed =>
      'ダウンロードしたアセットのチェックサム検証に失敗しました。';

  @override
  String get appProviderErrorExtractArchiveFailed =>
      'OpenCode バイナリアーカイブの解凍に失敗しました。';

  @override
  String appProviderErrorExecutableNotFound(String tool) {
    return '解凍されたファイル内に $tool 実行ファイルが見つかりませんでした。';
  }

  @override
  String get chatNoResponseFromServer => 'サーバーからの応答がありません。もう一度お試しください。';

  @override
  String get chatNoResponseFromModel => 'モデルからの応答がありません。もう一度お試しください。';

  @override
  String get speechJobCancelled => '音声ジョブがキャンセルされました。';

  @override
  String get speechEdgeCancelled => 'Microsoft Edge Speech がキャンセルされました。';

  @override
  String get sessionAttentionKindActive => 'アクティブ';

  @override
  String get sessionAttentionKindReceiving => '受信中';

  @override
  String get sessionAttentionKindDelayed => '遅延';

  @override
  String get sessionAttentionKindCompleted => '完了';

  @override
  String get sessionAttentionKindPendingInteraction => '操作待ち';

  @override
  String get sessionAttentionKindError => 'エラー';

  @override
  String get sessionAttentionPauseCellularDataSaver => 'データ節約モードが有効です。';

  @override
  String get sessionAttentionPauseOauthReopenRequired => 'OAuth サインインが必要です';

  @override
  String get sessionAttentionPauseTailscaleReopenRequired =>
      'Tailscale 接続が必要です';

  @override
  String get sessionAttentionPauseOffline => 'オフライン';

  @override
  String get sessionAttentionPausePermissionRevoked => '権限が取り消されました';

  @override
  String get sessionAttentionPauseServiceStopped => 'サービスが停止しました';

  @override
  String get sessionAttentionPauseHostUnavailable => 'ホストが利用できません';

  @override
  String get errorRequestCancelled => 'リクエストがキャンセルされました';

  @override
  String errorUnknownNetworkError(String error) {
    return '不明なネットワークエラー: $error';
  }

  @override
  String get errorCertificateError => '証明書エラー';

  @override
  String get errorSessionBusy => 'セッションは別のリクエストを処理中です。';

  @override
  String get errorRunShellCommandFailed => 'シェルコマンドの実行に失敗しました';

  @override
  String get errorRunSlashCommandFailed => 'スラッシュコマンドの実行に失敗しました';

  @override
  String get settingsBehaviorOpenCodeDefaultsLoadError =>
      'アクティブなサーバーから OpenCode ベースのデフォルトを読み込めませんでした。';

  @override
  String get sessionTabIconRemoveFailed => 'ローカルセッションのタブアイコンデータの削除に失敗しました';

  @override
  String get forwardUntitled => '無題';

  @override
  String setupDebugLinuxLogsPath(String path) {
    return 'Linux ログ: $path';
  }

  @override
  String setupDebugRunOpenCodeCommand(String command) {
    return 'OpenCode を起動: $command';
  }

  @override
  String setupDebugServerHealthEndpoint(String endpoint) {
    return 'サーバーのヘルスチェック: $endpoint';
  }

  @override
  String setupDebugServerDocsEndpoint(String endpoint) {
    return 'サーバードキュメント: $endpoint';
  }

  @override
  String get logsEntryError => 'エラー';

  @override
  String get logsEntryStack => 'スタック';

  @override
  String get setupDebugSourceDiagnostics => '診断';

  @override
  String get setupDebugSourceUseExisting => '既存のものを使用';

  @override
  String get setupDebugSourceLocalServer => 'ローカルサーバー';

  @override
  String get setupDebugSourceOnboarding => 'オンボーディング';

  @override
  String get setupDebugSourceManualConnection => '手動接続';

  @override
  String setupDebugMessageDiagnosticsResult(
    String availability,
    String platform,
    String recommendation,
  ) {
    return '$platform で $availability。$recommendation';
  }

  @override
  String get setupDebugMessageDetectAttempt =>
      '現在の環境から既存の OpenCode コマンドを検出しようとしています。';

  @override
  String get setupDebugMessageInstallStarted =>
      'CodeWalk から OpenCode のインストールを開始しました。';

  @override
  String setupDebugMessageStartLocalServer(String url) {
    return '管理対象の OpenCode サーバーを $url で起動しています。';
  }

  @override
  String setupDebugMessageHealthyRunning(String url) {
    return '管理対象の OpenCode サーバーは正常で、$url で実行中です。';
  }

  @override
  String get setupDebugMessageStoppingLocalServer =>
      '管理対象の OpenCode サーバーを停止しています。';

  @override
  String get setupDebugMessageStoppedCleanly =>
      '管理対象の OpenCode サーバーは正常に停止しました。';

  @override
  String get setupDebugMessageExitedAfterRequestedStop =>
      '停止要求後、管理対象の OpenCode サーバーが終了しました。';

  @override
  String get setupDebugMessageOnboardingConnectExisting =>
      'ユーザーは既存の OpenCode サーバーへの接続を選択しました。';

  @override
  String get setupDebugMessageOnboardingGuidedPath =>
      'ユーザーはガイド付きの OpenCode セットアップフローを開きました。';

  @override
  String get setupDebugMessageOnboardingManagedLocal =>
      'ユーザーは管理対象のローカル OpenCode セットアップを開きました。';

  @override
  String get setupDebugMessageOnboardingOpenedServerSettings =>
      'ヘルスチェック失敗後、ユーザーはサーバー設定を開きました。';

  @override
  String get setupDebugMessageOnboardingAddAnotherServer =>
      'ヘルスチェック失敗後、ユーザーは別のサーバーを追加することを選択しました。';

  @override
  String setupDebugMessageTestingServerUrl(String url) {
    return 'オンボーディングから OpenCode サーバー URL $url をテストしています。';
  }

  @override
  String get chatProviderErrorSessionNotFound => 'セッションが見つかりません';

  @override
  String get chatProviderErrorInvalidMessageFormat => '無効なメッセージ形式です';

  @override
  String get chatProviderErrorNetworkShort => 'ネットワーク接続に失敗しました';

  @override
  String get chatProviderErrorUnknownShort => '不明なエラー';

  @override
  String get terminalCreateFailed => 'ターミナルセッションを作成できませんでした';

  @override
  String get terminalEndpointUnavailable => 'ターミナルエンドポイントが利用できません';

  @override
  String get terminalInvalidDirectory => '無効なターミナルディレクトリです';

  @override
  String get terminalWebsocketUnavailable => 'ターミナル WebSocket はここでは利用できません。';

  @override
  String chatMessageToolChainCallsCompact(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count回',
      one: '1回',
    );
    return '$_temp0';
  }

  @override
  String get errorConnectionTimeout => '接続タイムアウト';

  @override
  String get errorClientError => 'クライアントエラー';

  @override
  String get chatProviderErrorSendMessage => 'メッセージの送信に失敗しました';

  @override
  String get speechApiEngine => 'API';

  @override
  String get speechApiEngineSubtitle =>
      'OpenAI、Groq、または OpenAI 互換のカスタムエンドポイント。';

  @override
  String get speechApiProvider => '音声文字起こしプロバイダー';

  @override
  String get speechCloudSttPrivacy => 'クラウド音声文字起こしのプライバシー';

  @override
  String get speechCloudSttPrivacyDescription =>
      '録音されたマイク音声は設定されたプロバイダーに送信されます。API キーはこのデバイスの安全なストレージに保管されます。';

  @override
  String get speechApiKeyOptional => 'カスタムエンドポイントでは省略可能です。';

  @override
  String speechApiBatchHint(String provider) {
    return '$provider はバッチ文字起こしを使用します。もう一度マイクをタップすると停止して文字起こしします。';
  }

  @override
  String get speechApiWebUnavailable => 'API 音声文字起こしはウェブ版では利用できません。';

  @override
  String get speechApiConfigInvalid =>
      '音声 API のエンドポイントとモデルを確認してください。リモートのエンドポイントは HTTPS を使用する必要があります。';

  @override
  String get speechApiRequestInvalid => '音声エンドポイントまたはモデルが拒否されました。';

  @override
  String get speechApiRateLimited => '音声プロバイダーがクォータまたはレート制限を報告しました。';

  @override
  String get speechApiUnavailable => '音声プロバイダーは一時的に利用できません。';

  @override
  String get speechApiNetwork => '音声プロバイダーに接続できませんでした。';

  @override
  String get speechApiInvalidResponse => '音声プロバイダーが無効な応答を返しました。';

  @override
  String get speechApiEmptyAudio => 'マイク音声がキャプチャされませんでした。';

  @override
  String get speechApiEmptyTranscript => '音声プロバイダーが文字起こしを返しませんでした。';

  @override
  String get speechApiCustomProvider => 'カスタム OpenAI 互換';

  @override
  String get speechApiMaxDuration => 'API 録音は 2 分後に自動的に停止します。';

  @override
  String get speechApiLanguageHint => 'アクティブなアプリの言語が文字起こしのヒントとして送信されます。';

  @override
  String get speechSttApiKeyStorageUnavailable => '音声 API キーの安全なストレージを利用できません。';

  @override
  String get speechSttApiKeyMissing => '設定 > 音声で音声 API キーを追加してください。';

  @override
  String get speechSttApiKeyRejected => '音声 API キーが拒否されました。';

  @override
  String get carMessagingReply => '返信';

  @override
  String get carMessagingMarkRead => '既読にする';

  @override
  String get carMessagingDeliveryFailedTitle => '返信を送信できませんでした';

  @override
  String get carMessagingDeliveryFailedBody =>
      '音声での返信を配信できませんでした。再試行するにはCodeWalkを開いてください。';
}
