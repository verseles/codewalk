// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get aboutGitHub => 'GitHub';

  @override
  String get appProviderCannotActivateUnhealthy => '상태가 좋지 않은 서버를 활성화할 수 없습니다.';

  @override
  String get appProviderDesktopOnly => '관리형 로컬 서버는 데스크톱에서만 사용할 수 있습니다.';

  @override
  String get appProviderDetectingCommand => 'OpenCode 명령 감지 중...';

  @override
  String get appProviderErrorCannotActivateUnhealthy =>
      '상태가 좋지 않은 서버를 활성화할 수 없습니다.';

  @override
  String get appProviderErrorCloudflareOAuthNotSupported =>
      '이 플랫폼에서는 Cloudflare Access OAuth를 지원하지 않습니다.';

  @override
  String get appProviderErrorInstallationFailed => 'OpenCode 설치에 실패했습니다.';

  @override
  String get appProviderErrorInvalidServerUrl => '유효하지 않은 서버 URL';

  @override
  String get appProviderErrorLocalServerHealthCheckFailed =>
      '로컬 서버가 시작되었지만 상태 확인을 통과하지 못했습니다.';

  @override
  String get appProviderErrorManagedDesktopOnly =>
      '관리형 로컬 서버는 데스크톱에서만 사용할 수 있습니다.';

  @override
  String get appProviderErrorServerAlreadyExists => '이 URL을 사용하는 서버가 이미 존재합니다.';

  @override
  String get appProviderErrorServerProfileNotFound => '서버 프로필을 찾을 수 없습니다.';

  @override
  String get appProviderErrorServerUrlRequired => '서버 URL이 필요합니다.';

  @override
  String get appProviderErrorTailscaleNotSupported =>
      '이 플랫폼에서는 Tailscale을 지원하지 않습니다.';

  @override
  String appProviderExitedWithCode(int code) {
    return '로컬 서버가 코드 $code번으로 종료되었습니다.';
  }

  @override
  String get appProviderFailedToStart => '로컬 OpenCode 서버를 시작하지 못했습니다.';

  @override
  String get appProviderInstallBinary => '바이너리 설치';

  @override
  String get appProviderInstallBunOpenCode => 'Bun + OpenCode 설치';

  @override
  String get appProviderInstallSucceeded => '설치에 성공했습니다.';

  @override
  String appProviderInstallSucceededWithPath(String path) {
    return '설치에 성공했습니다. OpenCode 명령은 $path에서 사용할 수 있습니다.';
  }

  @override
  String get appProviderInstallViaBun => 'Bun을 통해 설치';

  @override
  String get appProviderInstallViaNpm => 'npm을 통해 설치';

  @override
  String get appProviderInstallationFailed => 'OpenCode 설치에 실패했습니다.';

  @override
  String get appProviderInstalledSuccessfully =>
      'OpenCode 요구 사항이 성공적으로 설치되었습니다.';

  @override
  String get appProviderInstallingRequirements => 'OpenCode 요구 사항 설치 중...';

  @override
  String get appProviderInvalidServerUrl => '유효하지 않은 서버 URL';

  @override
  String get appProviderLabelLocalOpenCodeManaged => '로컬 OpenCode (관리형)';

  @override
  String get appProviderLabelPrimaryServer => '기본 서버';

  @override
  String get appProviderLocalManaged => '로컬 OpenCode (관리형)';

  @override
  String get appProviderLocalServerStopped => '로컬 서버가 중지되었습니다.';

  @override
  String get appProviderNotDetectedInstall =>
      'OpenCode 명령이 감지되지 않았습니다. 마법사에서 설치를 실행하십시오.';

  @override
  String appProviderNotDetectedRefresh(String appName) {
    return 'OpenCode 명령이 감지되지 않았습니다. 방금 설치한 경우 체크를 새로 고치거나 $appName을(를) 다시 열어 PATH를 다시 로드하십시오.';
  }

  @override
  String get appProviderOAuthNotSupported =>
      '이 플랫폼에서는 Cloudflare Access OAuth를 지원하지 않습니다.';

  @override
  String get appProviderOpenCodeDetected => 'OpenCode 감지됨';

  @override
  String get appProviderOpenCodeNotDetected => 'OpenCode 감지되지 않음';

  @override
  String get appProviderPrimaryServer => '기본 서버';

  @override
  String get appProviderProfileNotFound => '서버 프로필을 찾을 수 없습니다.';

  @override
  String get appProviderRunDiagnostics =>
      '로컬 OpenCode 요구 사항을 확인하려면 진단을 실행하십시오.';

  @override
  String appProviderRunningAt(String url) {
    return '$url에서 실행 중';
  }

  @override
  String get appProviderSetupDetectingOpenCode => 'OpenCode 명령 감지 중...';

  @override
  String get appProviderSetupInstallationSucceeded => '설치에 성공했습니다.';

  @override
  String appProviderSetupInstallationSucceededWithPath(String path) {
    return '설치에 성공했습니다. OpenCode 명령은 $path에서 사용할 수 있습니다.';
  }

  @override
  String get appProviderSetupInstallingRequirements => 'OpenCode 요구 사항 설치 중...';

  @override
  String get appProviderSetupOpenCodeDetected => 'OpenCode 감지됨';

  @override
  String get appProviderSetupOpenCodeNotDetected => 'OpenCode 감지되지 않음';

  @override
  String get appProviderSetupOpenCodeNotDetectedInstall =>
      'OpenCode 명령이 감지되지 않았습니다. 마법사에서 설치를 실행하십시오.';

  @override
  String get appProviderSetupOpenCodeNotDetectedRefresh =>
      'OpenCode 명령이 감지되지 않았습니다. 방금 설치한 경우 체크를 새로 고치거나 CodeWalk를 다시 열어 PATH를 다시 로드하십시오.';

  @override
  String get appProviderSetupRequirementsInstalled =>
      'OpenCode 요구 사항이 성공적으로 설치되었습니다.';

  @override
  String appProviderSetupUsingOpenCodeAt(String path) {
    return '$path에 있는 OpenCode 명령 사용 중';
  }

  @override
  String get appProviderStartingLocalServer => '로컬 서버 시작 중...';

  @override
  String appProviderStatusLocalServerExitedWithCode(int code) {
    return '로컬 서버가 코드 $code번으로 종료되었습니다.';
  }

  @override
  String get appProviderStatusLocalServerStopped => '로컬 서버가 중지되었습니다.';

  @override
  String appProviderStatusRunningAt(String url) {
    return '$url에서 실행 중';
  }

  @override
  String get appProviderStatusStartingLocalServer => '로컬 서버 시작 중...';

  @override
  String get appProviderStatusStoppingLocalServer => '로컬 서버 중지 중...';

  @override
  String get appProviderStoppingLocalServer => '로컬 서버 중지 중...';

  @override
  String get appProviderTailscaleNotSupported =>
      '이 플랫폼에서는 Tailscale을 지원하지 않습니다.';

  @override
  String appProviderUsingCommandAt(String path) {
    return '$path에 있는 OpenCode 명령 사용 중';
  }

  @override
  String get appShellDownloadingUpdate => '업데이트 다운로드 중';

  @override
  String get appShellInstall => '설치';

  @override
  String get appShellInstallFailed => '설치 실패';

  @override
  String get appShellInstallingUpdate => '업데이트 설치 중...';

  @override
  String get appShellRestart => '재시작';

  @override
  String appShellUpdateAvailableResult(String latestVersion) {
    return '업데이트 가능: v$latestVersion';
  }

  @override
  String get appShellUpdateInstalledRestartApp =>
      '업데이트가 설치되었습니다. 적용하려면 앱을 재시작하세요.';

  @override
  String get appShellUpdateInstalledRestartRequired =>
      '업데이트가 설치되었습니다. 새 버전을 적용하려면 재시작이 필요합니다.';

  @override
  String get attachmentCouldNotDecode => '첨부 파일 데이터를 디코딩할 수 없습니다.';

  @override
  String get attachmentCouldNotDownload => '첨부 파일을 다운로드할 수 없습니다.';

  @override
  String get attachmentCouldNotSave => '이 기기에 첨부 파일을 저장할 수 없습니다.';

  @override
  String get attachmentDownloadStarted => '첨부 파일 다운로드가 시작되었습니다.';

  @override
  String get attachmentLocalNotFound => '이 기기에서 로컬 첨부 파일을 찾을 수 없습니다.';

  @override
  String get attachmentNoValidLocation => '첨부 파일에 유효한 위치가 제공되지 않았습니다.';

  @override
  String get attachmentNotAvailableOnPlatform =>
      '이 플랫폼에서는 첨부 파일 작업을 사용할 수 없습니다.';

  @override
  String get attachmentPathEmpty => '첨부 파일 경로가 비어 있습니다.';

  @override
  String get attachmentPayloadEmpty => '첨부 파일 페이로드가 비어 있습니다.';

  @override
  String get attachmentSaveCanceled => '저장이 취소되었습니다.';

  @override
  String attachmentSavedAndOpened(String path) {
    return '첨부 파일을 $path에 저장하고 열었습니다.';
  }

  @override
  String attachmentSavedPath(String path) {
    return '첨부 파일을 $path에 저장했습니다.';
  }

  @override
  String attachmentSavedTo(String path) {
    return '첨부 파일을 $path에 저장했습니다.';
  }

  @override
  String get attachmentUnableToOpenLink => '첨부 파일 링크를 열 수 없습니다.';

  @override
  String get attachmentUnableToOpenLocal => '로컬 첨부 파일을 열 수 없습니다.';

  @override
  String get behaviorAdvancedPermissionRule => '고급 권한 규칙';

  @override
  String get behaviorAutomatic => '자동';

  @override
  String get behaviorAutomaticFallback => '자동 대체';

  @override
  String get behaviorCellularDataSaver => '모바일 데이터 절약';

  @override
  String get behaviorCellularDataSaverActive => '셀룰러 데이터 세이버가 활성화되었습니다.';

  @override
  String get behaviorChatLevelShare => '채팅 수준 공유';

  @override
  String get behaviorCodeWalkReleaseChecks => 'CodeWalk 릴리스 확인';

  @override
  String get behaviorControlsOfficialGlobal => 'OpenCode 공식 전역 설정 제어';

  @override
  String get behaviorControlsUpstreamOpenCode => '업스트림 OpenCode 설정 제어';

  @override
  String get behaviorCustomDisplayName => '사용자 지정 표시 이름';

  @override
  String behaviorCutsAutomaticMobile(int inSeconds) {
    return '백그라운드 다운로드를 중지하고 포그라운드 자동 새로고침을 $inSeconds초마다 한 번으로 제한하여 자동 모바일 데이터 사용량을 줄입니다.';
  }

  @override
  String get behaviorDataSaverActive => '현재 모바일 데이터에서 활성화되어 있습니다.';

  @override
  String get behaviorDataSaverAggressive => '공격적';

  @override
  String get behaviorDataSaverAggressiveDescription =>
      '저대역폭 모드: 표시 중인 작업 공간 스트림만 실시간으로 유지되고, 전역 업데이트는 일시 중지되며, 자동 새로고침 간격이 늘어납니다.';

  @override
  String get behaviorDataSaverCellularOnly => '모바일/셀룰러 연결 시에만 적용됩니다.';

  @override
  String get behaviorDataSaverOff => '끄기';

  @override
  String get behaviorDataSaverOffHint => '전체 실시간 업데이트와 자동 새로고침이 활성화됩니다.';

  @override
  String get behaviorDataSaverStandard => '표준';

  @override
  String get behaviorDataSaverWaiting => '다음 모바일 데이터 동기화 주기를 대기 중입니다.';

  @override
  String get behaviorDisabled => '비활성화됨';

  @override
  String get behaviorLightweightTasksLike => '다음과 같은 가벼운 작업';

  @override
  String get behaviorManual => '수동';

  @override
  String get behaviorNotify => '알림';

  @override
  String get behaviorOfficialOpenCodePermission =>
      '공식 OpenCode 권한 정책은 도구별 allow/ask/deny 규칙이 있는 `opencode.json`에서 구성됩니다. CodeWalk는 공식 권한 요청 카드를 유지하고 하나의 승인된 ADR-023 예외를 추가합니다: 컴포저 자동 승인 토글은 영구적인 세션 범위 권한을 생성하기 위해 무조건 `Always` 및 `remember: true`로 응답하며, Android 백그라운드 작업자에서도 동일한 스레드 범위 연속성 경로를 활성 상태로 유지합니다.';

  @override
  String get behaviorOpenCodeBackedDefaults => 'OpenCode 기반 기본값';

  @override
  String get behaviorPermissionHandlingProvenance => '권한 처리 출처';

  @override
  String get behaviorPermissionsVariantReasoning =>
      '권한 및 변형/추론 기능의 동등성은 고급 구성을 UI에서 안전하게 보존할 수 있을 때까지 분리되어 유지됩니다.';

  @override
  String get behaviorPrimaryAgentAgent =>
      '에이전트가 명시적으로 선택되지 않았을 때 사용되는 기본 에이전트입니다.';

  @override
  String get behaviorRefreshDefaults => '기본값 새로고침';

  @override
  String get behaviorSharedAcrossOpenCode => '구성을 통해 OpenCode 클라이언트 간에 공유됩니다.';

  @override
  String get behaviorTheseValuesWrite =>
      '이 값은 활성 서버의 `/config`에 기록되며 공식 OpenCode 공유 구성과 일치합니다.';

  @override
  String get cannedAddTitle => '빠른 답변 추가';

  @override
  String get cannedAppendAtCursor => '커서에 추가';

  @override
  String get cannedAppendAtCursorSubtitle => '끄기 = 현재 작성기 텍스트 바꾸기';

  @override
  String get cannedAttachFiles => '파일 첨부';

  @override
  String get cannedEditTitle => '빠른 답변 편집';

  @override
  String get cannedNewQuickReply => '새 빠른 답장';

  @override
  String get cannedNoSuggestions => '제안 없음';

  @override
  String get cannedOffMeansReplace => '비활성화 시 현재 컴포저 텍스트를 대체합니다';

  @override
  String get cannedQuickReply => '새 빠른 답장';

  @override
  String get cannedReplace => '바꾸기';

  @override
  String get cannedScopeGlobalSubtitle => '프로젝트 전용 항목의 경우 비활성화';

  @override
  String get cannedScopeGlobalUnavailableSubtitle => '현재 컨텍스트에서 프로젝트 전용 사용 불가';

  @override
  String get cannedSendAutomaticallySubtitle => '삽입 후 즉시 보내기';

  @override
  String get cannedSendImmediatelyInserting => '이 빠른 답장을 삽입한 후 즉시 전송';

  @override
  String get cannedTextLabel => '텍스트';

  @override
  String get chatActionNext => '다음';

  @override
  String get chatActiveServerUnhealthy =>
      '활성 서버 상태가 비정상입니다. 복구될 때까지 메시지 전송은 한 번만 시도되고 즉시 실패 처리됩니다.';

  @override
  String get chatActiveServerUnhealthyLabel => '활성 서버가 비정상입니다';

  @override
  String get chatAddServerToStart => '대화를 시작하려면 서버를 추가하세요.';

  @override
  String get chatAppBarMoreActions => '추가 작업';

  @override
  String get chatAppBarPinAction => '앱 바에 고정';

  @override
  String get chatAppBarPinDescription => '이 작업은 메뉴 외부에서 계속 표시됩니다.';

  @override
  String get chatAppBarUnpinAction => '앱 바에서 고정 해제';

  @override
  String get chatAppBarUnpinDescription => '이 작업은 메뉴 내부로 다시 이동합니다.';

  @override
  String chatBadgeConversationError(String title) {
    return '\"$title\"에 오류가 있습니다.';
  }

  @override
  String chatBadgeConversationNeedsInput(String title) {
    return '\"$title\"에 입력이 필요합니다.';
  }

  @override
  String chatBadgeConversationNewReply(String title) {
    return '\"$title\"에 새 답장이 있습니다.';
  }

  @override
  String get chatBadgeDataSaverActive => '데이터 절약 모드가 활성화되었습니다.';

  @override
  String get chatBadgeServerNeedsAttention => '서버 연결에 주의가 필요합니다.';

  @override
  String get chatBadgeSyncing => '대화 동기화 중...';

  @override
  String get chatBlockResponsePendingDescription =>
      '이 턴이 끝나면 답변이 단일 블록으로 표시됩니다.';

  @override
  String get chatBlockResponsePendingTitle => '응답 생성 중';

  @override
  String get chatCachedConversationsYet => '캐시된 대화가 없습니다';

  @override
  String get chatChangedFilesAvailable => '이 세션에서 변경된 파일을 사용할 수 없습니다.';

  @override
  String chatChildrenChatProviderCurrentSessionChildren(int length) {
    return '하위: $length';
  }

  @override
  String get chatChooseAgent => '에이전트 선택';

  @override
  String get chatChooseDirectory => '디렉토리 선택';

  @override
  String get chatChooseEffort => '노력 수준 선택';

  @override
  String get chatChooseFolderOpen => '프로젝트 컨텍스트로 열 폴더를 선택하세요.';

  @override
  String get chatChooseModel => '모델 선택';

  @override
  String get chatClose => '닫기';

  @override
  String chatCloseProject(String project) {
    return '$project 닫기';
  }

  @override
  String get chatCollapseGroup => '그룹 접기';

  @override
  String get chatCommandDescriptionProject => '프로젝트 명령';

  @override
  String get chatCommandSourceGeneric => '명령';

  @override
  String get chatCommandSourceProject => '프로젝트';

  @override
  String get chatCompactContext => '컨텍스트 압축';

  @override
  String get chatComposerHintShell => '셸 명령어 (Esc 종료)';

  @override
  String get chatComposerPlaceholder => '필요한 사항을 입력하세요...';

  @override
  String get chatConversation => '대화';

  @override
  String get chatConversations => '대화 목록';

  @override
  String get chatConversationsPane => '대화';

  @override
  String chatCostLabel(double cost) {
    return '비용: \$$cost';
  }

  @override
  String get chatCouldNotRefreshSession => '이 대화를 새로고침할 수 없습니다';

  @override
  String get chatCurrent => '현재 항목 사용';

  @override
  String chatDescriptionChildren(int count) {
    return '하위 항목: $count';
  }

  @override
  String get chatDescriptionCloseApp => '플랫폼 종료 동작을 사용하여 앱 닫기';

  @override
  String get chatDescriptionCycleModels => '최근 모델 순환';

  @override
  String get chatDescriptionCycleVariant => '모델 변형 순환';

  @override
  String get chatDescriptionDiffFilesZero => 'Diff 파일: 0';

  @override
  String get chatDescriptionFocusInput => '메시지 입력 창 포커스';

  @override
  String get chatDescriptionFocusOrCloseDrawer =>
      '입력 창 포커스 (또는 열려 있을 때 드로어 닫기)';

  @override
  String get chatDescriptionForceExit => '앱 강제 종료';

  @override
  String get chatDescriptionNewConversation => '새 대화';

  @override
  String get chatDescriptionNextAgent => '다음 에이전트';

  @override
  String get chatDescriptionOpenProjects => '이 버튼을 사용하여 프로젝트와 대화를 엽니다.';

  @override
  String get chatDescriptionOpenSettings => '설정 열기';

  @override
  String get chatDescriptionPreviousAgent => '이전 에이전트';

  @override
  String get chatDescriptionProjectCommand => '프로젝트 명령';

  @override
  String get chatDescriptionQuickOpen => '파일 빠른 열기';

  @override
  String get chatDescriptionRefreshData => '채팅 데이터 새로 고침';

  @override
  String get chatDescriptionStopResponse => '활성 응답 중지 (응답 중)';

  @override
  String get chatDescriptionSwitchProject => '이 버튼을 사용하여 프로젝트 폴더와 컨텍스트를 전환합니다.';

  @override
  String get chatDescriptionVoiceInput => '음성 입력 시작 또는 중지';

  @override
  String get chatDiffFiles => 'Diff 파일: 0';

  @override
  String get chatDisplay => '화면 표시';

  @override
  String get chatDisplayToggles => '화면 표시 토글';

  @override
  String get chatDoubleESCStop => 'ESC 두 번 눌러서 중지';

  @override
  String get chatEffortLockedSubConversation => '하위 대화에서 노력 수준이 잠김';

  @override
  String get chatExpandGroup => '그룹 펼치기';

  @override
  String get chatExportCanceled => '세션 내보내기 취소됨';

  @override
  String get chatFailedToLoadDirectories => '디렉토리를 로드하지 못했습니다';

  @override
  String get chatFailedToLoadFile => '파일을 로드하지 못했습니다';

  @override
  String get chatFailedToRefreshProviders => '공급자 및 모델을 새로고침하지 못했습니다';

  @override
  String get chatFailedToRefreshSubConversations =>
      '하위 대화를 새로고침하지 못했습니다. 다시 시도하세요.';

  @override
  String get chatFailedToStopResponse => '현재 응답 중지에 실패했습니다';

  @override
  String get chatFileExplorerContents => '내용';

  @override
  String get chatFileExplorerNames => '이름';

  @override
  String get chatFilterActive => '활성';

  @override
  String get chatFilterAll => '전체';

  @override
  String get chatFilterArchived => '보관됨';

  @override
  String get chatFilterDirectories => '디렉토리 필터';

  @override
  String get chatFilterSessions => '세션 필터';

  @override
  String get chatForkFailed => '대화 포크 실패';

  @override
  String get chatForked => '대화 포크됨';

  @override
  String get chatGoToFirst => '첫 메시지로 이동';

  @override
  String get chatGoToLatest => '최신 메시지로 이동';

  @override
  String chatGroupMessageCountMessages(
    String compactionLabel,
    String messageCount,
  ) {
    return '$compactionLabel 압축 전 $messageCount개 메시지 숨김';
  }

  @override
  String get chatHelloAssistant => '안녕하세요! 저는 AI 어시스턴트입니다';

  @override
  String get chatHelp => '무엇을 도와드릴까요?';

  @override
  String get chatHelpMessage => '멘션은 @, 쉘은 !, 명령은 /를 사용하세요';

  @override
  String get chatHideConversationsSidebar => '대화 사이드바 숨기기';

  @override
  String get chatHideUtilitySidebar => '유틸리티 사이드바 숨기기';

  @override
  String get chatHistoryCollapsed => '이전 기록이 접혀 있습니다';

  @override
  String get chatHistoryHideEarlier => '이전 메시지 숨기기';

  @override
  String chatHistoryMessagesHidden(int count, String label) {
    return '$label 압축 이전에 메시지 $count개 숨김';
  }

  @override
  String get chatHistoryShowEarlier => '이전 메시지 보기';

  @override
  String get chatKeepWorking => '계속 진행';

  @override
  String get chatLargeContentSkipped => '안정성을 위해 크거나 잘못된 형식의 콘텐츠를 건너뛰었습니다.';

  @override
  String get chatLatestToolActivity =>
      '채팅 뷰포트를 안정적으로 유지하기 위해 최신 도구 활동은 이 고정된 패널 내부에 유지됩니다.';

  @override
  String get chatLoadMore => '더 보기';

  @override
  String get chatLoadingProjectContext => '프로젝트 컨텍스트 로드 중...';

  @override
  String get chatMainConversationUnavailable => '메인 대화를 아직 사용할 수 없습니다.';

  @override
  String get chatParentConversationUnavailable => '상위 대화를 아직 사용할 수 없습니다.';

  @override
  String get chatMentionAgentSubtitle => '에이전트';

  @override
  String get chatMentionFileSubtitle => '파일';

  @override
  String get chatMentionSymbolSubtitle => '기호';

  @override
  String get chatMessageAttachedFile => '첨부 파일';

  @override
  String get chatMessageDetails => '세부 정보';

  @override
  String get chatMessageHide => '숨기기';

  @override
  String get chatMessageLess => '접기';

  @override
  String get chatMessageMessagePartUnavailable => '메시지 일부를 사용할 수 없습니다';

  @override
  String get chatMessageMetadataAvailable => '사용 가능한 메타데이터가 없습니다';

  @override
  String chatMessageModelMessageModelId(String modelId) {
    return '모델: $modelId';
  }

  @override
  String get chatMessageMore => '더보기';

  @override
  String get chatMessageOpenFile => '파일 열기';

  @override
  String chatMessageProviderMessageProviderId(String providerId) {
    return '제공자: $providerId';
  }

  @override
  String get chatMessageRewindEdit => '여기서부터 되돌려 편집하기';

  @override
  String get chatMessageRunningTask => '작업 실행 중';

  @override
  String get chatMessageSaveFile => '파일 저장';

  @override
  String get chatMessageShow => '보기';

  @override
  String get chatMessageShowQuestion => '질문 보기';

  @override
  String get chatMessageShowLess => '덜 보기';

  @override
  String get chatMessageShowLessCompact => '접기';

  @override
  String get chatMessageShowMore => '더 보기';

  @override
  String get chatMessageShowMoreCompact => '더보기';

  @override
  String get chatMessageThinking => '생각 중';

  @override
  String get chatMessageThinkingProcess => '생각 과정';

  @override
  String get chatMessageToolCall => '도구 호출 1개';

  @override
  String chatMessageToolCalls(int count) {
    return '도구 호출 $count개';
  }

  @override
  String get chatMessageToolCommand => '명령어';

  @override
  String get chatMessageToolCommandTruncated => '안정성을 위해 명령어 미리보기가 잘렸습니다.';

  @override
  String get chatMessageToolDiffOmitted =>
      'Diff 미리보기가 생략되었습니다: 편집 페이로드가 너무 큽니다.';

  @override
  String get chatMessageToolInput => '입력';

  @override
  String get chatMessageToolInputTruncated => '안정성을 위해 입력 미리보기가 잘렸습니다.';

  @override
  String get chatMessageToolOutputTruncated => '앱 안정성을 위해 큰 도구 출력이 잘렸습니다.';

  @override
  String chatMessageToolQueuedCount(int count) {
    return '$count개 대기 중';
  }

  @override
  String chatMessageToolRunningCount(int count) {
    return '$count개 실행 중';
  }

  @override
  String get chatMessageToolStatusInProgress => '진행 중';

  @override
  String get chatMessageToolStatusNeedsAttention => '주의 필요';

  @override
  String get chatMessageToolStatusQueued => '대기 중';

  @override
  String get chatMessageYou => '나';

  @override
  String get chatModelLockedSubConversation => '하위 대화에서 모델 잠김';

  @override
  String get chatNewChat => '새 대화';

  @override
  String get chatNewChatTourDescription => '여기서 새 대화를 시작합니다.';

  @override
  String get chatNewChatTourTitle => '새 대화';

  @override
  String get chatNoConversationsInProject => '이 프로젝트에 대화가 없습니다.';

  @override
  String get chatNoServerYet => '아직 설정된 서버가 없습니다';

  @override
  String get chatNoSessionSelected => '대화를 선택하거나 생성하세요';

  @override
  String get chatNoSubConversationFound => '이 작업에 대한 하위 대화를 찾을 수 없습니다.';

  @override
  String get chatOpenFiles => '열린 파일';

  @override
  String get chatOpenProject => '프로젝트 열기';

  @override
  String get chatOpenProjectFolder => '프로젝트 폴더 열기...';

  @override
  String get chatOpenProjectToLoad => '대화를 로드하려면 프로젝트를 여십시오.';

  @override
  String get chatOpenSidebar => '사이드바 열기';

  @override
  String get chatPageStatusAutomaticCompactionExplanation =>
      '컨텍스트 사용량이 늘어나면 자동으로 압축이 수행됩니다.';

  @override
  String get chatPageStatusCompactNow => '지금 압축';

  @override
  String get chatPageStatusCompacting => '압축 중...';

  @override
  String get chatPageStatusCompactingContextNow => '현재 컨텍스트 압축 중...';

  @override
  String get chatPageStatusContextCompacted => '컨텍스트 압축됨';

  @override
  String get chatPageStatusContextUsage => '컨텍스트 사용량';

  @override
  String get chatPageStatusCost => '비용';

  @override
  String get chatPageStatusFailedToCompactContext => '컨텍스트 압축 실패';

  @override
  String get chatPageStatusLimit => '제한';

  @override
  String get chatPageStatusManageServers => '서버 관리';

  @override
  String get chatPageStatusSaver => '절약';

  @override
  String get chatPageStatusServer => '서버';

  @override
  String get chatPageStatusSwitchServer => '서버 전환';

  @override
  String get chatPageStatusTokens => '토큰';

  @override
  String get chatPageStatusUsage => '사용량';

  @override
  String chatPageStatusUsagePercent(int usagePercent) {
    return '$usagePercent';
  }

  @override
  String get chatPermissionAutoApproveOff => '권한 자동 승인 꺼짐';

  @override
  String get chatPermissionAutoApproveOn => '권한 자동 승인 켜짐';

  @override
  String get chatProjectContext => '프로젝트 컨텍스트';

  @override
  String get chatProjectContext2 => '프로젝트 컨텍스트';

  @override
  String get chatRealtimeGlobalEvent => '글로벌 이벤트';

  @override
  String chatRealtimeGlobalEventReason(String reason) {
    return '글로벌 이벤트 ($reason)';
  }

  @override
  String get chatRealtimeGlobalEventStale => '글로벌 이벤트 (오래된 세대)';

  @override
  String chatRealtimeMessageStreamReason(String reason) {
    return '메시지 스트림 ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEvent => '실시간 이벤트';

  @override
  String chatRealtimeRealtimeEventReason(String reason) {
    return '실시간 이벤트 ($reason)';
  }

  @override
  String get chatRealtimeRealtimeEventStale => '실시간 이벤트 (오래된 세대)';

  @override
  String get chatRealtimeReconnectingServerTry => '서버에 재연결 중. 잠시 후 다시 시도하세요.';

  @override
  String get chatReasoning => '추론 중...';

  @override
  String get chatRecentSessions => '최근 세션';

  @override
  String get chatRecentSessionsToggle => '최근 세션';

  @override
  String get chatRedoLastTurn => '마지막 취소한 턴 다시 실행';

  @override
  String get chatRedoNothing => '이 세션에서 다시 실행할 작업이 없습니다';

  @override
  String get chatRefresh => '새로고침';

  @override
  String get chatRefreshConversation => '이 대화를 새로고침할 수 없습니다';

  @override
  String get chatRefreshProjects => '프로젝트 새로고침';

  @override
  String get chatRefreshSessionDetails => '세션 정보 새로고침';

  @override
  String chatRemoveDisplayNameHistory(String displayName) {
    return '기록에서 $displayName 제거';
  }

  @override
  String get chatRetry => '재시도';

  @override
  String get chatRetry2 => '재시도';

  @override
  String get chatRetryRefresh => '새로고침 재시도';

  @override
  String get chatRetryingModelRequest => '모델 요청 재시도 중...';

  @override
  String get chatReturnToMainConversation => '기본 대화로 돌아가기';

  @override
  String get chatReturnToParentConversation => '상위 대화로 돌아가기';

  @override
  String get chatReviewChanges => '변경 사항 검토';

  @override
  String get chatSearchConversations => '대화 검색';

  @override
  String get chatSearchNextResult => '다음 결과';

  @override
  String get chatSearchNoResults => '결과 없음';

  @override
  String get chatSearchPreviousResult => '이전 결과';

  @override
  String chatSearchResultCount(int current, int total) {
    return '메시지 $current / $total';
  }

  @override
  String get chatSearchTimeline => '타임라인 검색';

  @override
  String get chatSelectDirectory => '디렉토리 선택';

  @override
  String get chatSelectOrCreate => '대화를 시작하려면 대화를 선택하거나 새로 만드세요';

  @override
  String get chatSelectProjectBelow => '아래에서 프로젝트를 선택하세요.';

  @override
  String get chatServerSelectedModel => '서버 선택 모델';

  @override
  String get chatSessionActions => '세션 동작';

  @override
  String chatSessionChatSessionSession(String title) {
    return '채팅 세션: $title';
  }

  @override
  String chatSessionConversationNextAction(String nextAction) {
    return '대화 $nextAction';
  }

  @override
  String get chatSessionConversations => '대화 없음';

  @override
  String get chatSessionCreateConversationStart => '대화를 시작하려면 새 대화를 만드세요';

  @override
  String get chatSessionTabsToggle => '세션 탭';

  @override
  String chatSessionsLength(int length) {
    return '$length';
  }

  @override
  String get chatSetUpServer => '서버 설정';

  @override
  String get chatSettings => '설정';

  @override
  String get chatShortcutsCloseApp => '플랫폼 종료 동작을 사용하여 앱 닫기';

  @override
  String get chatShortcutsCycleModels => '최근 모델 순환';

  @override
  String get chatShortcutsCycleVariant => '모델 변형 순환';

  @override
  String get chatShortcutsFocusInput => '메시지 입력창에 포커스';

  @override
  String get chatShortcutsFocusInputCloseDrawer =>
      '입력창에 포커스(또는 열려 있는 경우 서랍 닫기)';

  @override
  String get chatShortcutsForceExit => '앱 강제 종료';

  @override
  String get chatShortcutsNewConversation => '새 대화';

  @override
  String get chatShortcutsNextAgent => '다음 에이전트';

  @override
  String get chatShortcutsOpenSettings => '설정 열기';

  @override
  String get chatShortcutsPreviousAgent => '이전 에이전트';

  @override
  String get chatShortcutsQuickOpen => '파일 빠르게 열기';

  @override
  String get chatShortcutsRefreshChat => '채팅 데이터 새로고침';

  @override
  String get chatShortcutsStartStopVoice => '음성 입력 시작 또는 중지';

  @override
  String get chatShortcutsStopResponse => '활성 응답 중지(응답 중일 때)';

  @override
  String get chatSidebarAccess => '사이드바 액세스';

  @override
  String get chatSortMostRecent => '가장 최근 순';

  @override
  String get chatSortOldest => '오래된 순';

  @override
  String get chatSortRecent => '최근 순';

  @override
  String get chatSortSessions => '세션 정렬';

  @override
  String get chatSortTitle => '제목 순';

  @override
  String get chatStartVoiceInput => '음성 입력 시작';

  @override
  String get chatStartingVoiceInput => '음성 입력 시작 중';

  @override
  String get chatStatusBusy => '상태: 바쁨';

  @override
  String get chatStatusPatching => '패치 중';

  @override
  String chatStatusPatchingMultipleFiles(int count) {
    return '$count개 파일 패치 중';
  }

  @override
  String get chatStatusPatchingOneFile => '1개 파일 패치 중';

  @override
  String get chatStatusRetry => '상태: 재시도';

  @override
  String chatStatusRetryCount(int count) {
    return '상태: 재시도 #$count';
  }

  @override
  String get chatStatusSubsession => '하위 세션';

  @override
  String get chatStatusThinking => '생각 중...';

  @override
  String get chatStopVoiceInput => '음성 입력 중지';

  @override
  String chatSyncLabel(String label) {
    return '동기화: $label';
  }

  @override
  String get chatTasks => '작업';

  @override
  String get chatTasksAvailableSession => '이 세션에서 사용할 수 있는 작업이 없습니다.';

  @override
  String get chatTipAcceptanceCriteria => '팁: 큰 변경에는 승인 기준을 추가하세요';

  @override
  String get chatTipAskForPlan => '팁: 큰 작업은 먼저 계획을 요청하세요';

  @override
  String get chatTipBeSpecific => '팁: 구체적으로 작성하세요 — 프롬프트가 짧을수록 답변이 빠릅니다';

  @override
  String get chatTipBreakTasks => '팁: 큰 작업은 작은 프롬프트로 나누세요';

  @override
  String get chatTipCompareOptions => '팁: 트레이드오프가 불명확하면 대안을 요청하세요';

  @override
  String get chatTipContextKnob => '팁: 컨텍스트 노브를 탭하여 사용 세부 정보를 확인하세요';

  @override
  String get chatTipDefineVerification => '팁: 통과해야 할 테스트나 체크를 알려 주세요';

  @override
  String get chatTipLongPressSend => '팁: 전송 버튼을 길게 눌러 줄바꿈을 삽입하세요';

  @override
  String get chatTipMentionFiles => '팁: 프롬프트에서 @를 사용하여 파일을 언급하세요';

  @override
  String get chatTipNameRelevantFiles => '팁: 관련 파일, 화면, 명령을 알려 주세요';

  @override
  String get chatTipProvideContext => '팁: 컨텍스트를 제공하세요 — 오류 메시지와 로그를 붙여넣으세요';

  @override
  String get chatTipRenameConversation => '팁: 제목을 탭하여 대화 이름을 변경하세요';

  @override
  String get chatTipRequestDocs => '팁: 동작이 바뀌면 docs 업데이트를 요청하세요';

  @override
  String get chatTipShareAttempts => '팁: 시도한 내용과 정확한 오류를 공유하세요';

  @override
  String get chatTipShellCommands => '팁: 시작 부분에 !를 사용하여 쉘 명령을 실행하세요';

  @override
  String get chatTipSlashCommands => '팁: /를 사용하여 슬래시 명령에 액세스하세요';

  @override
  String get chatTipStartWithGoal => '팁: 최종 목표부터 알려 주세요';

  @override
  String get chatTipStateConstraints => '팁: 에이전트가 지켜야 할 제약을 알려 주세요';

  @override
  String get chatTipStepByStep => '팁: 복잡한 문제 디버깅 시 단계별 설명을 요청하세요';

  @override
  String get chatTipUseFocusedAgents => '팁: 계획, 리뷰, 빌드에 맞는 에이전트를 선택하세요';

  @override
  String get chatToggleSidebars => '사이드바 토글';

  @override
  String chatTokensLabel(int total) {
    return '토큰: $total';
  }

  @override
  String get chatTourProjectsConversations => '이 버튼을 사용하여 프로젝트와 대화를 엽니다.';

  @override
  String get chatTourSidebarProjectTools =>
      '이 메뉴를 사용하여 대화 사이드바와 프로젝트 도구를 표시합니다.';

  @override
  String get chatTourSwitchFolders => '이 버튼을 사용하여 프로젝트 폴더와 컨텍스트를 전환합니다.';

  @override
  String get chatUndoLastTurn => '마지막 턴 실행 취소';

  @override
  String get chatUndoNothing => '이 세션에서 취소할 작업이 없습니다';

  @override
  String get chatUseCurrent => '현재 항목 사용';

  @override
  String get chatWaitingForNetworkConnection => '네트워크 연결 대기 중...';

  @override
  String get chatWelcomeMessage => '안녕하세요! 저는 당신의 AI 어시스턴트입니다.';

  @override
  String get chatWelcomeSubmessage => '오늘 무엇을 도와드릴까요?';

  @override
  String get chatWorkBoundedPanelExplanation =>
      '채팅 뷰포트를 안정적으로 유지하기 위해 최신 도구 활동은 이 고정된 패널 내부에 유지됩니다.';

  @override
  String get chatWorkExpand => '펼치기';

  @override
  String get chatWorkHide => '숨기기';

  @override
  String get chatWorkMessageOne => '작업 메시지 1개';

  @override
  String chatWorkMessagesMultiple(int count) {
    return '작업 메시지 $count개';
  }

  @override
  String get chatWorkShow => '표시';

  @override
  String get commonCancel => '취소';

  @override
  String get commonCopiedToClipboard => '클립보드에 복사됨';

  @override
  String get commonDelete => '삭제';

  @override
  String get commonFile => '파일';

  @override
  String get commonReset => '초기화';

  @override
  String get commonSave => '저장';

  @override
  String get compactionAutomatic => '자동';

  @override
  String get compactionManual => '수동';

  @override
  String get composerAddAttachment => '첨부파일 추가';

  @override
  String get composerAttachFiles => '파일 첨부';

  @override
  String get composerCannedAppendAtCursor => '커서 위치에 추가';

  @override
  String get composerCannedLabel => '라벨 (선택 사항)';

  @override
  String get composerCannedNoReplies => '등록된 빠른 답장이 없습니다.';

  @override
  String get composerCannedReplace => '대체';

  @override
  String get composerCannedSave => '저장';

  @override
  String get composerCannedScopeGlobal => '글로벌';

  @override
  String get composerCannedScopeProject => '프로젝트 전용';

  @override
  String get composerCannedSendAutomatically => '자동 전송';

  @override
  String get composerCannedText => '텍스트';

  @override
  String get composerChatInput => '채팅 입력';

  @override
  String get composerDeleteAction => '삭제';

  @override
  String get composerDropHint => '이미지나 PDF를 놓아 첨부';

  @override
  String get composerPastedImageName => '붙여넣은 이미지';

  @override
  String get composerEdit => '편집';

  @override
  String get composerExtras => '추가 기능';

  @override
  String get composerExtrasHide => '추가 기능 숨기기';

  @override
  String get composerNewQuickReply => '새 빠른 답장';

  @override
  String get composerSelectImages => '이미지 선택';

  @override
  String get composerSelectPdf => 'PDF 선택';

  @override
  String get composerSend => '전송';

  @override
  String get composerShellMode => '셸 모드';

  @override
  String get desktopWindowClose => '닫기';

  @override
  String get desktopWindowMaximize => '최대화';

  @override
  String get desktopWindowMinimize => '최소화';

  @override
  String get desktopWindowRestore => '복원';

  @override
  String get dialogDownload => '다운로드';

  @override
  String get dialogLanguage => '언어';

  @override
  String get dialogMoonshineModelSize => '모델 크기';

  @override
  String get dialogMoonshineVoiceSetup => 'Moonshine 음성 설정';

  @override
  String get dialogParakeetModel => 'Parakeet 모델';

  @override
  String get dialogParakeetVoiceSetup => 'Parakeet 음성 설정';

  @override
  String get dialogSenseVoiceModel => 'SenseVoice 모델';

  @override
  String get dialogSenseVoiceSetup => 'SenseVoice 설정';

  @override
  String get dialogVoiceInputSetup => '음성 입력 설정';

  @override
  String get errorAnErrorOccurred => '오류가 발생했습니다';

  @override
  String get errorAuthRequired => '인증 필요';

  @override
  String get errorAuthRequiredDesc => '인증에 실패했습니다. 공급자를 다시 연결하고 다시 시도하십시오.';

  @override
  String get errorConnectionFailed => '연결 실패';

  @override
  String get errorConnectionFailedDesc => '서버에 연결할 수 없습니다. 연결 및 서버 상태를 확인하십시오.';

  @override
  String get errorFormatAuthenticationFailedReconnect =>
      '인증에 실패했습니다. 제공자를 다시 연결하고 시도해 주세요.';

  @override
  String get errorFormatProviderTemporarilyUnavailable =>
      '제공자를 일시적으로 사용할 수 없습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get errorFormatQuotaExceededCheck =>
      '사용량이 초과되었습니다. 제공자 플랜 또는 결제 상태를 확인해 주세요.';

  @override
  String get errorFormatRateLimitExceeded =>
      '요청 빈도 제한이 초과되었습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get errorFormatServerErrorPlease => '서버 오류가 발생했습니다. 다시 시도해 주세요.';

  @override
  String get errorFormatServiceTemporarilyUnavailable =>
      '서비스를 일시적으로 사용할 수 없습니다. 서버가 시작 중일 수 있으니 잠시 후 다시 시도해 주세요.';

  @override
  String get errorFormatUnableReachServer =>
      '서버에 연결할 수 없습니다. 네트워크 연결 및 서버 상태를 확인해 주세요.';

  @override
  String get errorProviderUnavailable => '공급자 사용 불가';

  @override
  String get errorProviderUnavailableDesc =>
      '공급자를 일시적으로 사용할 수 없습니다. 잠시 후 다시 시도하십시오.';

  @override
  String get errorQuotaExceeded => '할당량 초과';

  @override
  String get errorQuotaExceededDesc =>
      '할당량이 초과되었습니다. 공급자 요금제 또는 결제 정보를 확인하십시오.';

  @override
  String get errorRateLimitExceeded => '요청 제한 초과';

  @override
  String get errorRateLimitExceededDesc =>
      '요청 제한이 초과되었습니다. 잠시 기다린 후 다시 시도하십시오.';

  @override
  String get errorServerError => '서버 오류';

  @override
  String get errorServerErrorDesc => '서버 오류가 발생했습니다. 다시 시도해 주세요.';

  @override
  String get errorServiceUnavailable => '서비스 사용 불가';

  @override
  String get errorServiceUnavailableDesc =>
      '서비스를 일시적으로 사용할 수 없습니다. 서버가 시작 중일 수 있습니다. 잠시 후 다시 시도하십시오.';

  @override
  String get fileActionAttachmentDataDecoded => '첨부파일 데이터를 디코딩할 수 없습니다.';

  @override
  String get fileActionAttachmentPathEmpty => '첨부파일 경로가 비어 있습니다.';

  @override
  String get fileActionAttachmentPayloadEmpty => '첨부파일 데이터 페이로드가 비어 있습니다.';

  @override
  String get fileActionAttachmentProvideValid => '첨부파일이 유효한 위치를 제공하지 않습니다.';

  @override
  String get fileActionAttachmentSavedDevice => '기기에 첨부파일을 저장할 수 없습니다.';

  @override
  String fileActionAttachmentSavedOutputFile(String path) {
    return '첨부파일이 $path에 저장되고 열렸습니다.';
  }

  @override
  String fileActionAttachmentSavedOutputFile2(String path) {
    return '첨부파일이 $path에 저장되었습니다.';
  }

  @override
  String fileActionAttachmentSavedSavedPath(String savedPath) {
    return '첨부파일이 $savedPath에 저장되었습니다.';
  }

  @override
  String get fileActionLocalAttachmentFound => '이 기기에서 로컬 첨부파일을 찾을 수 없습니다.';

  @override
  String get fileActionSaveCanceled => '저장이 취소되었습니다.';

  @override
  String get fileActionUnableOpenLocal => '로컬 첨부파일을 열 수 없습니다.';

  @override
  String get filesAddChat => '채팅에 추가';

  @override
  String get filesAutosave => '자동 저장';

  @override
  String get filesAutosaveOn => '자동 저장 켜짐';

  @override
  String get filesAutosaveOff => '자동 저장 꺼짐';

  @override
  String get filesRedo => '다시 실행';

  @override
  String get filesUndo => '실행 취소';

  @override
  String get filesBinaryFilePreview => '바이너리 파일 미리보기는 지원되지 않습니다.';

  @override
  String get filesClear => '지우기';

  @override
  String get filesContents => '콘텐츠';

  @override
  String get filesDuplicate => '복제';

  @override
  String get filesDuplicated => '파일이 복제되었습니다';

  @override
  String get filesFileEmpty => '파일이 비어 있습니다.';

  @override
  String get filesAlreadyExists => '이미 같은 이름의 파일 또는 폴더가 있습니다.';

  @override
  String get filesCopyPath => '경로 복사';

  @override
  String get filesCreateFileTitle => '파일 만들기';

  @override
  String get filesCreateFolderTitle => '폴더 만들기';

  @override
  String get filesDelete => '삭제';

  @override
  String filesDeleteConfirm(String name) {
    return '$name을(를) 삭제할까요? 되돌릴 수 없습니다. 폴더는 내용까지 삭제됩니다.';
  }

  @override
  String filesDeleteTitle(String name) {
    return '$name 삭제';
  }

  @override
  String get filesFilesFound => '파일을 찾을 수 없음';

  @override
  String get filesFileCreated => '파일이 생성되었습니다.';

  @override
  String get filesFolderCreated => '폴더가 생성되었습니다.';

  @override
  String get filesHideSidebar => '파일 사이드바 숨기기';

  @override
  String get filesInvalidName => '경로 구분 기호 없이 유효한 이름을 입력하세요.';

  @override
  String get filesNameHint => '이름';

  @override
  String get filesNew => '새로 만들기';

  @override
  String get filesNewFile => '새 파일';

  @override
  String get filesNewFolder => '새 폴더';

  @override
  String get filesNames => '이름';

  @override
  String filesOpenFilesFileState(int length) {
    return '열린 파일 ($length)';
  }

  @override
  String get filesQuickOpen => '빠른 열기';

  @override
  String get filesQuickOpenFile => '빠른 파일 열기';

  @override
  String get filesOperationFailed => '파일 작업에 실패했습니다.';

  @override
  String get filesOperationUnavailable => '이 서버에서는 파일 작업을 사용할 수 없습니다.';

  @override
  String get filesOutsideRoot => '경로가 프로젝트 루트를 벗어납니다.';

  @override
  String get filesPathCopied => '경로가 복사되었습니다.';

  @override
  String get filesPathMissing => '경로가 존재하지 않습니다.';

  @override
  String get filesPermissionDenied => '권한이 거부되었습니다.';

  @override
  String get filesRefresh => '파일 새로고침';

  @override
  String get filesRename => '이름 변경';

  @override
  String filesRenameTitle(String name) {
    return '$name 이름 변경';
  }

  @override
  String get filesRenamed => '이름이 변경되었습니다.';

  @override
  String get filesRootDeleteBlocked => '프로젝트 루트는 삭제할 수 없습니다.';

  @override
  String get filesSearchHint => '이름 또는 경로로 파일 검색';

  @override
  String get filesDeleted => '삭제되었습니다.';

  @override
  String get filesTitle => '파일';

  @override
  String get forwardAction => '전달';

  @override
  String get forwardAllFailed => '어떤 세션으로도 전달하지 못했습니다';

  @override
  String get forwardCancel => '취소';

  @override
  String get forwardDialogSubtitle => '대화를 하나 이상 선택하세요';

  @override
  String get forwardDialogTitle => '전달할 대상…';

  @override
  String get forwardLoading => '세션 로드 중…';

  @override
  String get forwardNoOpenProjects => '세션이 있는 열린 프로젝트가 없습니다';

  @override
  String get forwardNoProviderModel => '전달하기 전에 공급자와 모델을 선택하세요';

  @override
  String get forwardNoSessions => '최근 세션이 없습니다';

  @override
  String forwardPartial(int success, int total) {
    return '$total개 중 $success개로 전달됨';
  }

  @override
  String forwardProvenanceLabel(String origin) {
    return '전달 출처: $origin';
  }

  @override
  String get forwardRetry => '재시도';

  @override
  String get forwardSearchHint => '검색';

  @override
  String forwardSelectedCount(int count) {
    return '$count개 선택됨';
  }

  @override
  String get forwardSend => '전달';

  @override
  String get forwardServerOffline => '서버가 오프라인입니다';

  @override
  String get forwardShortcutHint => 'Ctrl+Shift+F';

  @override
  String forwardSuccess(int count) {
    return '$count개 세션으로 전달됨';
  }

  @override
  String get forwardUndo => '실행 취소';

  @override
  String get forwardUndoFailed => '전달을 실행 취소할 수 없습니다';

  @override
  String get logsAppLogs => '앱 로그';

  @override
  String get logsClear => '로그 지우기';

  @override
  String get logsCloseSearch => '검색 닫기';

  @override
  String get logsCopyFiltered => '필터링된 로그 복사';

  @override
  String get logsEnableLogging => '앱 로그 켜기';

  @override
  String get logsEnableLoggingAction => '로그 켜기';

  @override
  String get logsEnableLoggingDescription =>
      '메모리에 진단 로그를 수집합니다. 문제를 진단할 때가 아니면 꺼두세요.';

  @override
  String get logsEntryContext => '컨텍스트';

  @override
  String get logsEntryTags => '태그';

  @override
  String get logsFilterAll => '전체';

  @override
  String get logsFilterByTag => '태그';

  @override
  String get logsLevel => '로그 레벨';

  @override
  String get logsLoggingDisabledDescription =>
      'CodeWalk가 자세한 앱 로그를 수집하지 않습니다. 진단이 필요할 때만 로그를 켜세요.';

  @override
  String get logsLoggingDisabledTitle => '로그가 꺼져 있습니다';

  @override
  String get logsMeasurePerformance => '성능 측정';

  @override
  String get logsMeasurePerformanceDescription =>
      '앱의 비용이 큰 작업 시간을 기록합니다. 지연을 진단할 때만 켜세요.';

  @override
  String get logsNoLogsYet => '아직 캡처된 로그가 없습니다.';

  @override
  String get logsNoMatchingLogs => '현재 필터와 일치하는 로그가 없습니다.';

  @override
  String get logsNoPerformanceData => '현재 필터와 일치하는 성능 로그가 없습니다.';

  @override
  String get logsNoTaskData => '현재 필터와 일치하는 작업이 없습니다.';

  @override
  String logsPerformanceDuration(int elapsedMs) {
    return '$elapsedMs ms';
  }

  @override
  String get logsPerformanceFilter => '성능';

  @override
  String logsPerformanceTileTitle(
    int elapsedMs,
    String operation,
    String status,
  ) {
    return '성능 $operation | $elapsedMs ms | $status';
  }

  @override
  String get logsSearch => '로그 검색';

  @override
  String logsShowingOrderedLength(int length, int length2) {
    return '항목 $length2개 중 $length개 표시';
  }

  @override
  String get logsSlowestPerformance => '가장 느린 성능 로그';

  @override
  String get logsSlowestTasks => '가장 느린 작업';

  @override
  String get logsTagCustomHint => '태그 이름(예: task:select_session)';

  @override
  String get logsTagCustomAction => '사용자 지정...';

  @override
  String logsTaskDuration(int elapsedMs, String operation) {
    return '$operation — $elapsedMs ms';
  }

  @override
  String get logsTaskStatusCanceled => '취소됨';

  @override
  String get logsTaskStatusError => '오류';

  @override
  String get logsTaskStatusOk => '정상';

  @override
  String get logsTimeRange => '시간 범위';

  @override
  String get mathExpressionLabel => '수식';

  @override
  String get mermaidCopySourceTooltip => '소스 복사';

  @override
  String get mermaidDiagramLabel => 'Mermaid 다이어그램';

  @override
  String get modelAuto => '자동';

  @override
  String get modelChooseAgent => '에이전트 선택';

  @override
  String get modelFavorites => '즐겨찾기';

  @override
  String get modelFree => '무료';

  @override
  String get modelLabelBaseEnglish => '기본 (영어)';

  @override
  String get modelLabelParakeet => 'Parakeet V3 (25개 유럽 언어)';

  @override
  String get modelLabelSenseVoice => 'SenseVoice (zh/en/ja/ko/yue)';

  @override
  String get modelLabelTinyEnglish => 'Tiny (영어)';

  @override
  String get modelLoadingModels => '모델 로드 중';

  @override
  String get modelModelsFound => '모델을 찾을 수 없음';

  @override
  String get modelRetryModels => '모델 재시도';

  @override
  String get modelSearchHint => '모델 또는 제공자 검색';

  @override
  String get msgBatterySettingsFailed => 'Android 배터리 최적화 설정을 열 수 없습니다.';

  @override
  String get msgBatterySettingsOpened =>
      'Android 배터리 설정이 열렸습니다. CodeWalk에 대해 배터리 사용량 제한 없음으로 허용해 주세요.';

  @override
  String get msgClearUsernameNeedsConfigEdit =>
      'OpenCode 대화 사용자 이름을 지우려면 여전히 앱 외부에서 구성을 수정해야 합니다.';

  @override
  String get msgCommandCopied => '명령어가 복사되었습니다';

  @override
  String get msgCopiedToClipboard => '클립보드에 복사되었습니다';

  @override
  String get msgEnterUsernameToSave =>
      '사용자 정의 OpenCode 대화 이름을 저장하려면 사용자 이름을 입력하세요.';

  @override
  String get msgFailedToSendMessage => '메시지 전송에 실패했습니다. 재시도를 위해 초안이 유지됩니다.';

  @override
  String get msgFailedToStartVoiceInput => '음성 입력을 시작하지 못했습니다';

  @override
  String msgFilePathNotFound(String path) {
    return '파일을 찾을 수 없음: $path';
  }

  @override
  String get msgFilteredLogsCopied => '필터링된 로그가 클립보드에 복사되었습니다';

  @override
  String get msgInfoAgent => '에이전트';

  @override
  String get msgInfoCompaction => '압축';

  @override
  String msgInfoCost(String cost) {
    return '비용: \$$cost';
  }

  @override
  String get msgInfoMessageInfo => '메시지 정보';

  @override
  String msgInfoModel(String modelId) {
    return '모델: $modelId';
  }

  @override
  String get msgInfoNoMetadata => '사용 가능한 메타데이터가 없습니다';

  @override
  String msgInfoPartDescriptionModel(String description, String model) {
    return '$description$model';
  }

  @override
  String get msgInfoPatch => '패치';

  @override
  String msgInfoProvider(String providerId) {
    return '제공자: $providerId';
  }

  @override
  String get msgInfoRetry => '재시도';

  @override
  String get msgInfoSnapshot => '스냅샷';

  @override
  String msgInfoSubtaskPartAgent(String agent) {
    return '하위 작업 ($agent)';
  }

  @override
  String msgInfoTokens(int total) {
    return '토큰: $total';
  }

  @override
  String get msgInfoUndoThisTurn => '이 턴 취소';

  @override
  String get msgInfoView => '보기';

  @override
  String get msgNoSystemSoundsFound => '이 기기에서 발견된 시스템 소리가 없습니다.';

  @override
  String get msgNoValidFilesSelected => '선택된 유효한 파일이 없습니다';

  @override
  String get msgSomeSelectedFilesNotAttached => '선택한 일부 파일을 첨부할 수 없습니다.';

  @override
  String get msgReadAloud => '음성으로 읽기';

  @override
  String get msgReadAloudNotAvailable => '이 기기에서는 TTS(텍스트 음성 변환)를 사용할 수 없습니다.';

  @override
  String get msgSetupDebugCopied => 'OpenCode 설정 디버그 정보가 클립보드에 복사되었습니다';

  @override
  String get msgShareAsImage => '이미지로 공유';

  @override
  String get msgShareAsImageFailed => '메시지를 이미지로 공유할 수 없습니다.';

  @override
  String get msgShareAsImageSubject => 'CodeWalk 메시지';

  @override
  String get msgShareAsImageTooTall => '메시지가 너무 길어 이미지로 공유할 수 없습니다.';

  @override
  String get msgStopReadAloud => '읽기 중단';

  @override
  String get msgSystemSoundPickerUnavailable =>
      '이 플랫폼에서는 시스템 소리 선택기를 사용할 수 없습니다.';

  @override
  String get msgUpdatedButRefreshFailed =>
      '서버 설정을 업데이트했으나 채팅 제공자를 새로고침하지 못했습니다.';

  @override
  String get msgVoiceInputUnavailable => '이 기기에서는 음성 입력을 사용할 수 없습니다';

  @override
  String get notifAndroidBatteryOptimization => 'Android 배터리 최적화';

  @override
  String get notifConversationUpdates => '대화 업데이트';

  @override
  String get notifNotificationsArriveReopening =>
      '앱을 다시 열 때만 알림이 도착하는 경우, 이 기기에서 CodeWalk가 최적화 없이 실행되도록 허용해 주세요.';

  @override
  String get notifResponseRunningKeep =>
      '응답이 진행 중일 때 앱을 벗어난 후에도 잠시 동안 실시간 활성 상태를 유지합니다.';

  @override
  String notifSelectedSoundLabel(String soundLabel) {
    return '선택됨: $soundLabel';
  }

  @override
  String get notificationAgentFinished => '에이전트가 현재 응답을 마쳤습니다.';

  @override
  String get notificationConversationUpdates => '대화 업데이트';

  @override
  String get notificationOpenToClear => '관련 알림을 지우려면 이 대화를 여십시오.';

  @override
  String get notificationSession => '세션';

  @override
  String get notificationSoundLoadFailed => 'Android 시스템 사운드를 로드하지 못했습니다.';

  @override
  String get onboardingAIGeneratedTitles => 'AI 생성 제목';

  @override
  String get onboardingAddServerLater => '나중에 설정 > 서버에서 서버를 추가할 수 있습니다.';

  @override
  String get onboardingAddedButHealthCheckFailed =>
      '서버가 추가되었지만 상태 확인에 실패했습니다. 아직 시작 중일 수 있습니다.';

  @override
  String get onboardingAlmostInstallOpenCode =>
      '거의 완료되었습니다. 먼저 OpenCode를 설치한 다음 CodeWalk를 서버 URL에 연결하세요.';

  @override
  String onboardingAppProviderLocalSetupLogsLength(int length, int length2) {
    return '$length개의 설정 로그 줄과 $length2개의 설정 이벤트가 별도의 설정 디버그 화면에서 사용 가능합니다.';
  }

  @override
  String get onboardingAuthenticate => '인증';

  @override
  String get onboardingAvailable => '사용 가능';

  @override
  String get onboardingAvailableOnlyDesktop =>
      '데스크톱(Linux/macOS/Windows)에서만 사용할 수 있습니다.';

  @override
  String get onboardingBasicAuthTip =>
      'OpenCode 서버가 비밀번호로 보호되는 경우에만 기본 인증을 활성화하십시오.';

  @override
  String get onboardingChooseAnotherPath => '다른 경로 선택';

  @override
  String get onboardingChooseHowToSetup => '서버 설정 방법 선택';

  @override
  String get onboardingClear => '지우기';

  @override
  String get onboardingCloudflareAuthFailed => 'Cloudflare Access 인증에 실패했습니다.';

  @override
  String get onboardingCodeWalkAppOpenCode =>
      'CodeWalk는 앱이며, OpenCode는 앱이 연결되는 엔진입니다.';

  @override
  String get onboardingConnectRunningServer => '실행 중인 서버에 연결';

  @override
  String get onboardingConnectionIssue => '연결 문제';

  @override
  String get onboardingConnectionSaved => '서버 연결이 성공적으로 저장되었습니다.';

  @override
  String get onboardingConnectionTips => '연결 팁';

  @override
  String get onboardingConnectionUpdated => '서버 연결이 성공적으로 업데이트되었습니다.';

  @override
  String get onboardingContinue => '계속';

  @override
  String get onboardingContinueServerURL => '서버 URL로 진행';

  @override
  String get onboardingCopyLoginURL => '로그인 URL 복사';

  @override
  String get onboardingCouldNotVerify => '서버 연결을 확인할 수 없습니다.';

  @override
  String get onboardingDefaultURLEmulator =>
      '기본 URL, 에뮬레이터 루프백, 인증 및 디버그 도움말입니다.';

  @override
  String onboardingDesktopOnlyDiagnose(String appName) {
    return '데스크톱 전용: $appName은(는) 사용자를 대신하여 OpenCode를 진단, 설치 및 실행할 수 있습니다.';
  }

  @override
  String get onboardingDetailedSetupEvents => '문제 해결을 위해 상세 설정 이벤트가 캡처되었습니다.';

  @override
  String get onboardingDonShowAgain => '다시 보지 않기';

  @override
  String get onboardingDone => '완료';

  @override
  String get onboardingEditServer => '서버 편집';

  @override
  String get onboardingEditServerConnection => '서버 연결 편집';

  @override
  String get onboardingEmulatorRemap =>
      'Android 에뮬레이터에서 localhost 및 127.0.0.1은 자동으로 10.0.2.2로 리맵됩니다.';

  @override
  String get onboardingEnterServerUrl => '서버 URL 입력';

  @override
  String get onboardingExisting => '기존 서버 사용';

  @override
  String get onboardingExplainInstallOpenCode =>
      'OpenCode 설치, 서버 시작, 그리고 CodeWalk에서 연결하는 방법에 대한 설명입니다.';

  @override
  String get onboardingFailed => '실패';

  @override
  String get onboardingGoodOptionDesktop => '데스크톱에서 유용한 첫 번째 옵션';

  @override
  String get onboardingHealthCheckFailedMayBeStarting =>
      '서버 상태 확인에 실패했습니다. 아직 시작 중일 수 있습니다.';

  @override
  String get onboardingInstallBinary => '바이너리 설치';

  @override
  String get onboardingInstallBun => 'Bun을 통해 설치';

  @override
  String get onboardingInstallBunOpenCode => 'Bun + OpenCode 설치';

  @override
  String get onboardingInstallNpm => 'npm을 통해 설치';

  @override
  String get onboardingInstallRunOpenCode =>
      '데스크톱의 CodeWalk에서 직접 OpenCode를 설치하고 실행합니다.';

  @override
  String get onboardingInvalidUrl => '유효하지 않은 URL';

  @override
  String get onboardingLabel => '라벨 (선택 사항)';

  @override
  String get onboardingLabelHint => '내 서버';

  @override
  String onboardingLatestOutputAppProvider(String localServerLastOutput) {
    return '최신 출력: $localServerLastOutput';
  }

  @override
  String get onboardingLetCodeWalkSet => 'CodeWalk가 로컬에 자동으로 설정하도록 허용';

  @override
  String get onboardingLocalServerSetup => '로컬 서버 설정';

  @override
  String get onboardingManagedLocalServer => '관리형 로컬 서버';

  @override
  String get onboardingManagedLocalServer2 =>
      '관리형 로컬 서버 모드는 데스크톱 빌드(Linux/macOS/Windows)에서만 사용할 수 있습니다.';

  @override
  String onboardingNeedsOpenCodeServer(String appName) {
    return '$appName을(를) 사용하여 코드를 작성하려면 OpenCode 서버가 필요합니다.';
  }

  @override
  String get onboardingNotAvailable => '사용 불가';

  @override
  String get onboardingNotWritable => '쓰기 불가';

  @override
  String get onboardingOpenCode => 'OpenCode란 무엇인가요?';

  @override
  String get onboardingOpenCodeRunningDevice =>
      '이미 이 기기 또는 네트워크의 어딘가에서 OpenCode가 실행 중입니다.';

  @override
  String get onboardingOpenCodeRunsLocally =>
      'OpenCode는 로컬 또는 서버에서 실행되며 CodeWalk 내부의 AI 코딩 기능을 구동합니다. OpenCode가 이미 실행 중인 경우 연결하시고, 그렇지 않은 경우 아래 가이드 설정 경로 중 하나를 선택하세요.';

  @override
  String get onboardingOpenTailscaleLogin => 'Tailscale 로그인 URL을 열 수 없습니다.';

  @override
  String get onboardingPassword => '비밀번호';

  @override
  String get onboardingPasswordRequired => '비밀번호 입력';

  @override
  String get onboardingPickSetupPath => '현재 OpenCode 설정과 일치하는 설정 경로를 선택하십시오.';

  @override
  String get onboardingPreconditionDirectoryNotWritable =>
      '설치 디렉터리에 쓰기 권한이 없습니다. 사용자 권한을 확인하십시오.';

  @override
  String get onboardingPreconditionInstallViaBunRecommendation =>
      'OpenCode 관리자는 Bun을 통한 설치를 권장합니다.';

  @override
  String get onboardingPreconditionNetworkFailed =>
      '네트워크 액세스에 실패했습니다. OpenCode를 설치하기 전에 연결 상태를 확인하십시오.';

  @override
  String get onboardingPreconditionNoRuntimeDetected =>
      '런타임이 감지되지 않았습니다. OpenCode 바이너리를 직접 설치하거나 먼저 Bun을 부트스트랩하십시오.';

  @override
  String get onboardingPreconditionNodeNpmAvailable =>
      'Node 및 npm을 사용할 수 있습니다. npm을 통해 OpenCode를 설치하거나 권장하는 흐름에 따라 Bun을 설치하십시오.';

  @override
  String get onboardingPreconditionOpenCodeAlreadyAvailable =>
      'OpenCode를 이미 사용할 수 있습니다. 감지된 명령을 즉시 사용할 수 있습니다.';

  @override
  String get onboardingPreconditionWindowsPathLagHint =>
      ' Windows에서는 이미 열려 있는 앱에서 PATH 업데이트가 지연될 수 있으므로 설치 후 확인을 새로 고침하십시오.';

  @override
  String get onboardingPreconditionWindowsWslRecommendation =>
      'Windows 빌드가 감지되었습니다. OpenCode 문서에서는 WSL을 권장하지만, 대체 방안으로 npm install을 사용할 수 있습니다.';

  @override
  String get onboardingReachable => '연결 가능';

  @override
  String get onboardingReady => '준비됨';

  @override
  String get onboardingRecommendedOrderTry =>
      '권장 순서: CodeWalk가 모든 환경을 자동으로 구축하게 하려면 Bun + OpenCode 설치를 시도해 보세요. OpenCode가 이미 설치되어 있으면 기존 서버 사용을 선택하세요.';

  @override
  String get onboardingRefreshChecks => '검사 새로고침';

  @override
  String get onboardingRunDiagnosticsToVerify =>
      '로컬 OpenCode 요구 사항을 확인하려면 진단을 실행하십시오.';

  @override
  String get onboardingSaveAndTest => '저장 및 테스트';

  @override
  String get onboardingServerConnectedReady => '서버가 연결되어 사용할 준비가 되었습니다.';

  @override
  String get onboardingServerConnection => '서버 연결';

  @override
  String get onboardingServerSettingsSaved =>
      '서버 설정이 저장되었으며 상태 확인이 새로 고침되었습니다.';

  @override
  String get onboardingServerSetup => '서버 설정';

  @override
  String get onboardingServerUpdated => '서버가 업데이트되었습니다.';

  @override
  String get onboardingServerUrl => '서버 URL';

  @override
  String get onboardingSetup => '설정';

  @override
  String get onboardingSetupWizard => '설정 마법사';

  @override
  String get onboardingShowSetupSteps => '설정 단계 표시';

  @override
  String get onboardingShowSetupSteps2 => '설정 단계 표시';

  @override
  String get onboardingSkip => '지금은 건너뛰기';

  @override
  String get onboardingSkipSetup => '설정을 건너뛰시겠습니까?';

  @override
  String get onboardingStart => '시작';

  @override
  String onboardingStartUsing(String appName) {
    return '$appName 시작하기';
  }

  @override
  String get onboardingStarting => '시작 중';

  @override
  String get onboardingStop => '중지';

  @override
  String get onboardingStopped => '중지됨';

  @override
  String get onboardingStopping => '중지 중';

  @override
  String onboardingSuggestedUrl(String url) {
    return '제안된 로컬 OpenCode 서버 URL: $url';
  }

  @override
  String get onboardingTailscaleAdminApproval => 'Tailscale 관리자 승인 필요';

  @override
  String get onboardingTailscaleAuthAfterSave => '저장 후 Tailscale 인증이 진행됩니다.';

  @override
  String onboardingTailscaleAuthAfterSaveTest(String appName) {
    return '이 서버를 저장하고 테스트한 후, 이 기기가 아직 인증되지 않은 경우 $appName에서 Tailscale 로그인 페이지를 엽니다.';
  }

  @override
  String get onboardingTailscaleConnected => 'Tailscale 연결됨';

  @override
  String get onboardingTailscaleConnecting => 'Tailscale 연결 중';

  @override
  String get onboardingTailscaleConnectionFailed => 'Tailscale 연결 실패';

  @override
  String get onboardingTailscaleLoginRequired => 'Tailscale 로그인 필요';

  @override
  String get onboardingTailscaleOpenLoginUrl =>
      '로그인 URL을 열어 이 기기를 tailnet에 추가하십시오. 브라우저가 열리지 않으면 아래 URL을 복사하십시오.';

  @override
  String get onboardingTailscaleUnsupported => 'Tailscale 지원되지 않음';

  @override
  String get onboardingTestConnection => '연결 테스트';

  @override
  String get onboardingTesting => '테스트 중...';

  @override
  String get onboardingUnreachable => '연결 불가능';

  @override
  String get onboardingUseBasicAuth => '기본 인증 사용';

  @override
  String get onboardingUsername => '사용자 이름';

  @override
  String get onboardingUsernameRequired => '사용자 이름 입력';

  @override
  String get onboardingUsesServerTitle => '대화 이름을 지정할 때 서버의 타이틀 에이전트를 사용합니다';

  @override
  String get onboardingUsingDetectedCommand => '감지된 OpenCode 명령을 사용합니다.';

  @override
  String get onboardingViewSetupDebug => '설정 디버그 보기';

  @override
  String onboardingWelcomeTo(String appName) {
    return '$appName에 오신 것을 환영합니다';
  }

  @override
  String get onboardingWindowsTipInstalling =>
      'Windows 팁: 설치 후 검사 새로고침을 클릭하세요. 여전히 감지되지 않으면 CodeWalk를 다시 열어 PATH 변경 사항을 다시 로드하세요.';

  @override
  String get onboardingWritable => '쓰기 가능';

  @override
  String get onboardingYoureAllSet => '모든 준비가 완료되었습니다!';

  @override
  String get permissionAllowOnce => '한 번만 허용';

  @override
  String get permissionAlways => '항상 허용';

  @override
  String get permissionBack => '뒤로';

  @override
  String get permissionConfirmReject => '거부 확인';

  @override
  String get permissionReject => '거부';

  @override
  String get permissionReopen => '다시 열기';

  @override
  String get questionAnswerSelected => '선택된 대답이 없습니다.';

  @override
  String get questionCommaSeparatedValues => '쉼표로 구분된 값';

  @override
  String get questionQuestionGroupMarked =>
      '질문 그룹이 거부된 것으로 표시되었습니다. 대화를 계속 진행할 수 있으며, 확정하기 전에 언제든 이 질문 그룹을 다시 열 수 있습니다.';

  @override
  String get questionQuestionRequest => '질문 요청';

  @override
  String get questionQuestionsProvidedSubmit =>
      '제공된 질문이 없습니다. 빈 응답을 제출할 수 있습니다.';

  @override
  String get questionReviewAnswersSubmitting => '제출하기 전에 답변을 검토하세요.';

  @override
  String get quotaAuthCookie => '인증 쿠키';

  @override
  String get quotaConnect => '연결';

  @override
  String get quotaForget => '삭제';

  @override
  String get quotaOpenCodeGoConnectDescription =>
      '사용량 대시보드를 연결하여 롤링, 주간, 월간 한도를 표시합니다.';

  @override
  String get quotaOpenCodeGoDetected => 'OpenCode Go 감지됨';

  @override
  String get quotaOpenCodeGoNeedsReconnect => 'OpenCode Go 재연결 필요';

  @override
  String get quotaOpenCodeGoReconnectDescription =>
      '사용량 막대를 복원하려면 대시보드 자격 증명을 새로고침하세요.';

  @override
  String get quotaOpenCodeGoUsage => 'OpenCode Go 사용량';

  @override
  String get quotaOpenDashboard => 'OpenCode 대시보드 열기';

  @override
  String get quotaPaceExplanation =>
      '페이스는 현재 속도를 기준으로 현재 한도 기간이 끝날 때의 총 사용량을 예측합니다.';

  @override
  String quotaPacePercent(String percent) {
    return '페이스 $percent%';
  }

  @override
  String get quotaRateLimits => '사용 한도';

  @override
  String get quotaReconnect => '다시 연결';

  @override
  String get quotaRefreshing => '새로고침 중...';

  @override
  String quotaResetsIn(String time) {
    return '$time 후 재설정';
  }

  @override
  String get quotaSaving => '저장 중...';

  @override
  String get quotaWorkspaceId => '워크스페이스 ID';

  @override
  String get serverClearOAuth => 'OAuth 정보 지우기';

  @override
  String get serverConnectionAttention => '서버 연결에 주의가 필요합니다.';

  @override
  String get serverHealthHealthy => '정상';

  @override
  String get serverHealthUnhealthy => '비정상';

  @override
  String get serverHealthUnknown => '알 수 없음';

  @override
  String get serverOAuthAuthFailed => 'OAuth 인증 실패';

  @override
  String get serverOAuthChip => 'OAuth';

  @override
  String get serverOAuthNotSupported =>
      '이 플랫폼에서는 Cloudflare Access OAuth가 지원되지 않습니다';

  @override
  String get serverReauthenticate => '재인증';

  @override
  String get serverTailscaleChip => 'Tailscale';

  @override
  String get serversActive => '활성';

  @override
  String get serversActiveServer => '활성 서버';

  @override
  String get serversAddLeastOpenCode =>
      '앱 사용을 시작하려면 최소 하나의 OpenCode 서버를 추가하세요.';

  @override
  String get serversAddServer => '서버 추가';

  @override
  String get serversCancel => '취소';

  @override
  String get serversCannotActivateUnhealthy => '상태가 좋지 않은 서버를 활성화할 수 없음';

  @override
  String get serversCheckHealth => '상태 확인';

  @override
  String get serversClearDefault => '기본값 지우기';

  @override
  String serversCommandAppProviderLocalServerCommandPath(
    String localServerCommandPath,
  ) {
    return '명령: $localServerCommandPath';
  }

  @override
  String get serversCopy => '복사';

  @override
  String get serversDefault => '기본값';

  @override
  String get serversDelete => '삭제';

  @override
  String get serversDeleteServer => '서버 삭제';

  @override
  String get serversDesktopModeExplanation =>
      '데스크톱 모드는 CodeWalk에서 직접 `opencode serve`를 실행하고 관리할 수 있습니다.';

  @override
  String get serversEdit => '편집';

  @override
  String get serversLocalOpenCodeServer => '로컬 OpenCode 서버';

  @override
  String get serversManagedModeAvailable =>
      '이 관리 모드는 데스크톱 빌드(Linux/macOS/Windows)에서만 사용할 수 있습니다.';

  @override
  String get serversNoServersFound => '서버를 찾을 수 없음';

  @override
  String get serversRefreshHealth => '상태 새로고침';

  @override
  String serversRemoveProfileDisplayName(String displayName) {
    return '\"$displayName\"을(를) 제거하시겠습니까?';
  }

  @override
  String get serversSearchActiveHint => '활성 서버 검색';

  @override
  String get serversServersConfigured => '설정된 서버가 없습니다';

  @override
  String get serversSetActive => '활성으로 설정';

  @override
  String get serversSetDefault => '기본값으로 설정';

  @override
  String get serversSetupDebug => '설정 디버그';

  @override
  String get serversSetupWizard => '설정 마법사';

  @override
  String get serversTailscaleAdminApprovalRequired => 'Tailscale 관리자 승인 필요';

  @override
  String get serversTailscaleAuthRequired => 'Tailscale 인증 필요';

  @override
  String get serversTailscaleConnectExplanation =>
      '이 활성 프로필을 사용하면 Tailscale이 연결됩니다.';

  @override
  String get serversTailscaleConnected => 'Tailscale 연결됨';

  @override
  String get serversTailscaleConnecting => 'Tailscale 연결 중';

  @override
  String get serversTailscaleConnectionFailed => 'Tailscale 연결 실패';

  @override
  String get serversTailscaleDisconnected => 'Tailscale 연결 해제됨';

  @override
  String get serversTailscaleLoginExplanation =>
      '이 기기를 tailnet에 추가하려면 Tailscale 로그인 URL을 여세요.';

  @override
  String get serversTailscaleTrafficExplanation =>
      '이 활성 프로필의 OpenCode 트래픽은 Tailscale을 통해 라우팅됩니다.';

  @override
  String get serversTailscaleUnsupported => 'Tailscale 지원되지 않음';

  @override
  String get serversUnhealthyActivateError =>
      '이 서버의 상태가 좋지 않습니다. 활성화하기 전에 상태 확인을 하거나 설정을 편집하세요.';

  @override
  String get sessionActionArchived => '보관됨';

  @override
  String get sessionActionDeleted => '삭제됨';

  @override
  String get sessionActionForked => '포크됨';

  @override
  String get sessionActionPinned => '고정됨';

  @override
  String get sessionActionUnarchived => '보관 취소됨';

  @override
  String get sessionActionUnpinned => '고정 해제됨';

  @override
  String get sessionArchive => '보관';

  @override
  String get sessionCancelRename => '이름 변경 취소';

  @override
  String sessionChildrenCount(int count) {
    return '하위 대화: $count';
  }

  @override
  String get sessionCompactContext => '컨텍스트 압축';

  @override
  String get sessionCopyLink => '공유 링크 복사';

  @override
  String get sessionDelete => '삭제';

  @override
  String sessionDeleteConfirm(String title) {
    return '대화 \"$title\"을(를) 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String get sessionDeleteTitle => '대화 삭제';

  @override
  String get sessionDiffChangedFile => '변경된 파일';

  @override
  String get sessionDiffContentNotCaptured => '서버에 의해 파일 내용이 캡처되지 않았습니다';

  @override
  String sessionDiffFilesChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 파일 변경됨',
      one: '1개 파일 변경됨',
    );
    return '$_temp0';
  }

  @override
  String sessionDiffFilesCount(int count) {
    return 'Diff 파일: $count';
  }

  @override
  String sessionDiffLinesAddedRemoved(int added, int removed) {
    return '+$added줄 추가됨 -$removed줄 제거됨';
  }

  @override
  String sessionDiffLinesCollapsed(int count) {
    return '$count줄이 접혀 있음 — 탭하여 펼치기';
  }

  @override
  String get sessionDiffLoading => '변경된 파일 로드 중…';

  @override
  String get sessionDiffReview => '변경 사항 검토';

  @override
  String get sessionDiffSplit => '분할 보기';

  @override
  String get sessionDiffSummary => '요약';

  @override
  String get sessionDiffUnified => '통합 보기';

  @override
  String get sessionExportAssistant => '어시스턴트';

  @override
  String get sessionExportCanceled => '내보내기가 취소되었습니다';

  @override
  String get sessionExportDebugJson => '디버그 JSON 내보내기';

  @override
  String get sessionExportDebugJsonErrorClipboard =>
      '파일을 저장할 수 없습니다. 디버그 JSON이 클립보드에 복사되었습니다';

  @override
  String get sessionExportDebugJsonSaved => '디버그 JSON 내보내기가 저장되었습니다';

  @override
  String get sessionExportDebugJsonTitle => '세션을 디버그 JSON으로 내보내기';

  @override
  String get sessionExportError => '오류:';

  @override
  String get sessionExportInput => '입력:';

  @override
  String get sessionExportMarkdown => 'Markdown 내보내기';

  @override
  String get sessionExportMarkdownErrorClipboard =>
      '파일을 저장할 수 없습니다. Markdown이 클립보드에 복사되었습니다';

  @override
  String get sessionExportMarkdownSaved => 'Markdown 내보내기가 저장되었습니다';

  @override
  String get sessionExportMarkdownTitle => '세션을 Markdown으로 내보내기';

  @override
  String get sessionExportOutput => '출력:';

  @override
  String get sessionExportUntitled => '제목 없는 세션';

  @override
  String get sessionExportUser => '사용자';

  @override
  String get sessionFailedRename => '대화 이름 변경에 실패했습니다';

  @override
  String get sessionFailedUpdateArchive => '보관 상태 업데이트에 실패했습니다';

  @override
  String get sessionFailedUpdateSharing => '공유 상태 업데이트에 실패했습니다';

  @override
  String get sessionFork => '포크';

  @override
  String get sessionForkFailed => '대화 포크에 실패했습니다';

  @override
  String get sessionForked => '대화가 포크되었습니다';

  @override
  String sessionHasError(String title) {
    return '\"$title\"에 오류가 있습니다.';
  }

  @override
  String sessionHasNewReply(String title) {
    return '\"$title\"에 새 답변이 있습니다.';
  }

  @override
  String get sessionKeyboardShortcuts => '키보드 단축키';

  @override
  String sessionNeedsInput(String title) {
    return '\"$title\"이(가) 당신의 입력을 필요로 합니다.';
  }

  @override
  String get sessionNoCachedConversations => '아직 캐시된 대화가 없습니다';

  @override
  String get sessionNoConversationsInProject => '이 프로젝트에 대화가 없습니다.';

  @override
  String get sessionNotAvailable => '이 프로젝트에 사용할 수 있는 대화가 아직 없습니다';

  @override
  String get sessionOpenProjectToLoad => '프로젝트를 열어 대화를 로드하세요.';

  @override
  String get sessionPin => '고정';

  @override
  String get sessionRename => '이름 변경';

  @override
  String get sessionRenameHint => '새 대화 이름을 입력하세요';

  @override
  String get sessionRenameTitle => '대화 이름 변경';

  @override
  String get sessionSaveTitle => '제목 저장';

  @override
  String get sessionShare => '세션 공유';

  @override
  String get sessionShareAction => '공유';

  @override
  String get sessionShareLinkCopied => '공유 링크가 복사되었습니다';

  @override
  String get sessionShareLinkUnavailable => '이 세션에 공유 링크를 사용할 수 없습니다';

  @override
  String get sessionShared => '대화가 공유되었습니다';

  @override
  String get sessionSyncing => '대화 동기화 중...';

  @override
  String get sessionTitleHint => '대화 제목';

  @override
  String get sessionUnarchive => '보관 해제';

  @override
  String get sessionUnpin => '고정 해제';

  @override
  String get sessionUnshare => '세션 공유 해제';

  @override
  String get sessionUnshareAction => '공유 중지';

  @override
  String get sessionUnshared => '대화 공유가 해제되었습니다';

  @override
  String get sessionViewTasks => '작업 보기';

  @override
  String get settingsAboutCheckForUpdates => '업데이트 확인';

  @override
  String get settingsAboutCheckOnOpen => '앱 실행 시 업데이트 확인';

  @override
  String get settingsAboutCheckOnOpenDescription => '앱이 시작될 때 업데이트를 자동으로 확인합니다';

  @override
  String get settingsAboutChecking => '확인 중...';

  @override
  String get settingsAboutDescription => '버전, 업데이트, 도움말 및 앱 데이터';

  @override
  String get settingsAboutDismiss => '닫기';

  @override
  String settingsAboutDownloading(String percent) {
    return '다운로드 중... $percent%';
  }

  @override
  String get settingsAboutEraseAllData => '모든 데이터 지우고 재시작';

  @override
  String get settingsAboutInstallUpdate => '업데이트 설치';

  @override
  String get settingsAboutInstalling => '설치 중...';

  @override
  String settingsAboutLatestVersion(String version) {
    return 'v$version이(가) 최신 버전입니다';
  }

  @override
  String get settingsAboutLoading => '로드 중...';

  @override
  String get settingsAboutReplayChatTour => '채팅 둘러보기 다시 보기';

  @override
  String get settingsAboutReplayChatTourDescription =>
      '설정을 닫고 가이드 채팅 안내를 보여줍니다';

  @override
  String get settingsAboutResetApp => '앱 초기화';

  @override
  String get settingsAboutResetAppQuestion => '앱을 초기화하시겠습니까?';

  @override
  String get settingsAboutResetAppWarning =>
      '이렇게 하면 모든 서버, 설정 및 캐시된 데이터가 삭제됩니다. 이 작업은 되돌릴 수 없습니다.';

  @override
  String get settingsAboutRetryInstall => '설치 재시도';

  @override
  String get settingsAboutTapToCheck => '새 버전을 확인하려면 탭하세요';

  @override
  String get settingsAboutTitle => '정보';

  @override
  String get settingsAboutUpToDate => '최신 버전 상태입니다';

  @override
  String settingsAboutUpdateAvailable(String version) {
    return '업데이트 가능: v$version';
  }

  @override
  String get settingsAboutUpdateInstalled => '업데이트가 설치되었습니다. 적용하려면 앱을 재시작하세요.';

  @override
  String settingsAboutUpdateVersionSummary(
    String installedVersion,
    String latestVersion,
  ) {
    return '현재: $installedVersion; 사용 가능: v$latestVersion';
  }

  @override
  String get settingsAboutVersion => '버전';

  @override
  String settingsAboutVersionBuild(String buildNumber, String version) {
    return '$version (빌드 $buildNumber)';
  }

  @override
  String get settingsAppearanceAmoledDark => 'AMOLED 다크 모드';

  @override
  String get settingsAppearanceAmoledDarkActive =>
      '다크 모드가 활성화된 동안 완전한 검은색 배경을 사용합니다.';

  @override
  String get settingsAppearanceAmoledDarkInactive =>
      'AMOLED 배경을 활성화하려면 다크 모드로 전환하세요.';

  @override
  String get settingsAppearanceBrandColor => '브랜드 색상';

  @override
  String get settingsAppearanceBrandColorDynamicBlocked =>
      '브랜드 색상을 선택하려면 배경화면 색상 사용을 비활성화하세요.';

  @override
  String get settingsAppearanceBrandColorNormal => '앱 팔레트의 기준 색상을 선택합니다.';

  @override
  String get settingsAppearanceBrandColorPresetBlocked =>
      '브랜드 색상을 선택하려면 CodeWalk 클래식으로 전환하세요.';

  @override
  String get settingsAppearanceChatFontScale => '대화 텍스트 크기';

  @override
  String get settingsAppearanceChatFontScaleDescription =>
      '시스템 텍스트 크기에 더해 채팅 메시지와 작성기 텍스트의 크기를 조정합니다.';

  @override
  String get settingsAppearanceCodeWalkClassic => 'CodeWalk 클래식';

  @override
  String get settingsAppearanceComposerTips => '컴포저 팁';

  @override
  String get settingsAppearanceComposerTipsDescription =>
      '어시스턴트가 생각하는 동안 순환되는 팁의 표시 여부를 설정합니다.';

  @override
  String get settingsAppearanceContrast => '대비';

  @override
  String get settingsAppearanceContrastDynamicBlocked =>
      '대비를 조정하려면 배경화면 색상 사용을 비활성화하세요.';

  @override
  String get settingsAppearanceContrastHigh => '높음';

  @override
  String get settingsAppearanceContrastNormal => '색상 체계의 대비 수준을 조정합니다.';

  @override
  String get settingsAppearanceContrastPresetBlocked =>
      '대비를 조정하려면 CodeWalk 클래식으로 전환하세요.';

  @override
  String get settingsAppearanceContrastReduced => '낮춤';

  @override
  String get settingsAppearanceDark => '다크';

  @override
  String get settingsAppearanceDensity => '조밀도';

  @override
  String get settingsAppearanceDensityDense => '조밀함';

  @override
  String get settingsAppearanceDensityDescription =>
      '앱 전체에 걸쳐 간격 및 컴포넌트 조밀도를 적용합니다.';

  @override
  String get settingsAppearanceDensityExtraDense => '매우 조밀함';

  @override
  String get settingsAppearanceDensityExtraSpacious => '매우 넓음';

  @override
  String get settingsAppearanceDensityNormal => '보통';

  @override
  String get settingsAppearanceDensitySpacious => '넓음';

  @override
  String get settingsAppearanceDescription => '테마, 색상, 텍스트 크기 및 채팅 표시 선택';

  @override
  String get settingsAppearanceFontSize => '텍스트 크기';

  @override
  String get settingsAppearanceFontSizeDescription =>
      '시스템 텍스트, 대화 텍스트, 터미널 텍스트의 크기를 조정합니다.';

  @override
  String get settingsAppearanceLight => '라이트';

  @override
  String get settingsAppearanceMathRendering => '수식 렌더링';

  @override
  String get settingsAppearanceMathRenderingDescription =>
      '채팅 메시지에서 LaTeX 수학 표현식을 조판된 방정식으로 렌더링합니다.';

  @override
  String get settingsAppearanceNoPresets => '프리셋 팔레트를 찾을 수 없음';

  @override
  String get settingsAppearanceOpenCodePresets => 'OpenCode 프리셋';

  @override
  String get settingsAppearancePresetHelper =>
      '공식 OpenCode Web 기본 제공 테마 목록을 미러링합니다.';

  @override
  String get settingsAppearancePresetNote =>
      '테마 색상은 이제 공식 OpenCode Web 레지스트리를 따르며 마크다운 및 코드 영역에도 적용됩니다.';

  @override
  String get settingsAppearancePresetPalette => '프리셋 팔레트';

  @override
  String get settingsAppearanceSearchPreset => '프리셋 팔레트 검색';

  @override
  String get settingsAppearanceSectionDescription =>
      '작업 흐름에 맞게 시각적 조밀도 및 메시지 영역을 조정합니다.';

  @override
  String get settingsAppearanceSectionTitle => '화면 표시';

  @override
  String get settingsAppearanceSystem => '시스템';

  @override
  String get settingsAppearanceSystemFontScale => '시스템 텍스트 크기';

  @override
  String get settingsAppearanceSystemFontScaleDescription =>
      '메뉴, 대화상자, 사이드바를 포함한 앱 셸의 모든 텍스트 크기를 조정합니다.';

  @override
  String get settingsAppearanceTaskList => '작업 목록';

  @override
  String get settingsAppearanceTaskListDescription =>
      '세션 작업 목록 위젯의 표시 여부를 설정합니다.';

  @override
  String get settingsAppearanceTerminalFontSize => '터미널 텍스트 크기';

  @override
  String get settingsAppearanceTerminalFontSizeDescription =>
      '내장 터미널 글꼴 크기를 조정합니다. 실행 중인 세션에 즉시 적용됩니다.';

  @override
  String get settingsAppearanceTheme => '테마';

  @override
  String get settingsAppearanceThemeDescription =>
      '라이트, 다크 또는 시스템 모드를 선택한 다음 CodeWalk 클래식 팔레트를 유지하거나 OpenCode 프리셋으로 전환합니다.';

  @override
  String get settingsAppearanceVisualStyle => '시각 스타일';

  @override
  String get settingsAppearanceVisualStyleDescription =>
      '클래식 모양 또는 더 부드러운 리파인드 표면을 선택합니다.';

  @override
  String get settingsAppearanceVisualStyleClassic => '클래식';

  @override
  String get settingsAppearanceVisualStyleRefined => '리파인드';

  @override
  String get settingsAppearanceThinkingBubbles => '생각 과정 말풍선';

  @override
  String get settingsAppearanceThinkingBubblesDescription =>
      '어시스턴트 메시지에서 생각 과정 블록의 표시 여부를 설정합니다.';

  @override
  String get settingsAppearanceTitle => '화면 표시';

  @override
  String get settingsAppearanceToolCallBubbles => '도구 호출 말풍선';

  @override
  String get settingsAppearanceToolCallBubblesDescription =>
      '어시스턴트 메시지에서 도구 실행 카드의 표시 여부를 설정합니다.';

  @override
  String get settingsAppearanceWallpaperColors => '배경화면 색상 사용';

  @override
  String get settingsAppearanceWallpaperNormal => '기기 배경화면에서 색상 체계를 추출합니다.';

  @override
  String get settingsAppearanceWallpaperPresetBlocked =>
      '배경화면 색상을 사용하려면 CodeWalk 클래식으로 전환하세요.';

  @override
  String get settingsAppearanceWindowChrome => '창 탭';

  @override
  String get settingsAppearanceWindowChromeDescription =>
      '데스크톱에서 세션 탭과 제목 표시줄을 결합하는 방식을 선택합니다.';

  @override
  String get settingsAppearanceWindowChromeIntegrated => '통합 탭';

  @override
  String get settingsAppearanceWindowChromeIntegratedDescription =>
      '탭이 창 상단에 위치하고 시스템 제목 표시줄이 숨겨집니다.';

  @override
  String get settingsAppearanceWindowChromeSystem => '시스템 장식';

  @override
  String get settingsAppearanceWindowChromeSystemDescription =>
      '네이티브 제목 표시줄을 유지하고 탭을 앱 바 아래에 표시합니다.';

  @override
  String get settingsBack => '뒤로';

  @override
  String get settingsBehaviorAutoupdateCaveat =>
      'CodeWalk 릴리스 확인은 정보를 사용하세요. 이 설정은 공식 OpenCode `autoupdate` 구성만 미러링합니다.';

  @override
  String get settingsBehaviorAutoupdateHelp =>
      'CodeWalk 앱 업데이트 확인이 아닌 업스트림 OpenCode 런타임 업데이트를 제어합니다.';

  @override
  String get settingsBehaviorCellularDataSaver => '데이터 절약 모드';

  @override
  String get settingsBehaviorChatRenderMode => '채팅 렌더링 모드';

  @override
  String get settingsBehaviorChatRenderModeBlock => '블록';

  @override
  String get settingsBehaviorChatRenderModeBlockDescription =>
      '현재 턴을 단일 블록으로 표시할 수 있을 때까지 실시간 어시스턴트 텍스트, 추론, 도구 카드를 숨깁니다.';

  @override
  String get settingsBehaviorChatRenderModeDescription =>
      '어시스턴트 응답을 스트리밍 중 표시할지, 현재 턴이 끝난 후 표시할지 선택하세요.';

  @override
  String get settingsBehaviorChatRenderModeLive => '실시간';

  @override
  String get settingsBehaviorChatRenderModeLiveDescription =>
      'OpenCode가 이벤트를 스트리밍할 때 어시스턴트 텍스트, 추론, 도구 활동을 표시합니다.';

  @override
  String get settingsBehaviorComposerSpellCheck => '작성기 맞춤법 검사';

  @override
  String get settingsBehaviorComposerSpellCheckDescription =>
      '채팅 작성기에서 플랫폼 기본 맞춤법 검사, 제안, 자동 수정을 사용합니다.';

  @override
  String get settingsBehaviorConfigDeferred =>
      'CodeWalk는 현재 응답이 완료된 후 이 OpenCode 설정을 적용합니다.';

  @override
  String settingsBehaviorConfigUpdateFailed(String field) {
    return 'OpenCode $field을(를) 업데이트할 수 없습니다.';
  }

  @override
  String get settingsBehaviorConversationUsername => '대화 사용자 이름';

  @override
  String get settingsBehaviorConversationUsernameHelp =>
      '대화에서 시스템 사용자 이름 대신 표시할 사용자 지정 표시 이름입니다.';

  @override
  String get settingsBehaviorDataSaverActive => '현재 모바일 데이터에서 활성화되어 있습니다.';

  @override
  String get settingsBehaviorDataSaverCellularOnly => '모바일/셀룰러 연결 시에만 적용됩니다.';

  @override
  String get settingsBehaviorDataSaverDescription =>
      '백그라운드 다운로드를 중지하고 자동 포그라운드 새로고침을 제한하여 모바일 데이터 자동 사용량을 줄입니다.';

  @override
  String get settingsBehaviorDataSaverWaiting => '다음 모바일 데이터 동기화 주기를 대기 중입니다.';

  @override
  String get settingsBehaviorDefaultAgent => '기본 에이전트';

  @override
  String get settingsBehaviorDefaultAgentHelp =>
      '에이전트가 명시적으로 선택되지 않았을 때 사용되는 기본 에이전트입니다.';

  @override
  String get settingsBehaviorDefaultModel => '기본 모델';

  @override
  String get settingsBehaviorDefaultModelHelp =>
      '구성을 통해 OpenCode 클라이언트 간에 공유됩니다.';

  @override
  String get settingsBehaviorDescription =>
      '언어, 채팅 동작, 데이터 사용 및 OpenCode 기본값 관리';

  @override
  String get settingsBehaviorEnableDataSaver => '데이터 절약 모드 활성화';

  @override
  String get settingsBehaviorMultiDeviceSync => '실험적 다중 기기 동기화 활성화';

  @override
  String get settingsBehaviorMultiDeviceSyncDescription =>
      '컴포저 선택 사항(에이전트/모델/변형)을 활성 서버 구성과 동기화합니다.';

  @override
  String get settingsBehaviorMultiDeviceSyncWarning =>
      '동시에 둘 이상의 세션에서 작업할 때 진행 중인 세션이 중단될 수 있습니다.';

  @override
  String get settingsBehaviorNoAgents => '에이전트를 찾을 수 없음';

  @override
  String get settingsBehaviorNoModels => '모델을 찾을 수 없음';

  @override
  String get settingsBehaviorOpenCodeAutoupdate => 'OpenCode 자동 업데이트';

  @override
  String get settingsBehaviorOpenCodeDefaults => 'OpenCode 기반 기본값';

  @override
  String get settingsBehaviorOpenCodeDefaultsDescription =>
      '이 값은 활성 서버의 `/config`에 기록되며 공식 OpenCode 공유 구성과 일치합니다.';

  @override
  String get settingsBehaviorOpenCodeSnapshots => 'OpenCode 스냅샷';

  @override
  String get settingsBehaviorOpenCodeSnapshotsDescription =>
      '실행 취소/다시 실행 및 복구 기록을 위해 업스트림 git 기반 스냅샷 활성 상태를 유지합니다.';

  @override
  String get settingsBehaviorPermissionDeferred =>
      '고급 권한 규칙 편집은 현재 설정에서 제외되며 이후의 동등성 작업으로 연기됩니다.';

  @override
  String get settingsBehaviorPermissionProvenance => '권한 처리 출처';

  @override
  String get settingsBehaviorPermissionProvenanceDescription =>
      '공식 OpenCode 권한 정책은 도구별 allow/ask/deny 규칙이 있는 `opencode.json`에서 구성됩니다. CodeWalk는 공식 권한 요청 카드를 유지하고 하나의 승인된 ADR-023 예외를 추가합니다: 컴포저 자동 승인 토글은 영구적인 세션 범위 권한을 생성하기 위해 무조건 `Always` 및 `remember: true`로 응답하며, Android 백그라운드 작업자에서도 동일한 스레드 범위 연속성 경로를 활성 상태로 유지합니다.';

  @override
  String get settingsBehaviorRefreshDefaults => '기본값 새로고침';

  @override
  String get settingsBehaviorSaveUsername => '사용자 이름 저장';

  @override
  String get settingsBehaviorSearchAutoupdate => '자동 업데이트 모드 검색';

  @override
  String get settingsBehaviorSearchDefaultAgent => '기본 에이전트 검색';

  @override
  String get settingsBehaviorSearchDefaultModel => '기본 모델 검색';

  @override
  String get settingsBehaviorSearchShareMode => '공유 모드 검색';

  @override
  String get settingsBehaviorSearchSmallModel => '소형 모델 검색';

  @override
  String get settingsBehaviorShareMode => 'OpenCode 기본 공유 모드';

  @override
  String get settingsBehaviorShareModeCaveat =>
      '지금 하나의 세션을 게시하려면 채팅 수준의 공유 작업을 사용하세요. 이 설정은 OpenCode의 기본 공유 정책만 변경합니다.';

  @override
  String get settingsBehaviorShareModeHelp =>
      '개별 채팅의 공유 버튼이 아닌 공식 글로벌 `share` 구성을 제어합니다.';

  @override
  String get settingsBehaviorSmallModel => '소형 모델';

  @override
  String get settingsBehaviorSmallModelAutoFallback => '자동 폴백';

  @override
  String get settingsBehaviorSmallModelFallbackActive =>
      '`small_model`이 설정되지 않아 OpenCode 자동 폴백이 활성화되었습니다.';

  @override
  String get settingsBehaviorSmallModelHelp => '제목 생성과 같은 가벼운 작업에 사용됩니다.';

  @override
  String get settingsBehaviorSmallModelResetCaveat =>
      '`small_model`을 자동 폴백으로 재설정하려면 `/config` 패치 업데이트가 키를 삭제할 수 없기 때문에 앱 외부에서 구성을 수정해야 합니다.';

  @override
  String get settingsBehaviorSnapshotCaveat =>
      '이것은 CodeWalk 로컬 캐시 스냅샷이 아닌 OpenCode 스냅샷 저장소 및 실행 취소/다시 실행 지원을 제어합니다.';

  @override
  String get settingsBehaviorTitle => '동작';

  @override
  String get settingsBehaviorUsernameFallback =>
      '`username`이 설정되지 않아 OpenCode가 시스템 사용자 이름을 사용합니다.';

  @override
  String get settingsBehaviorUsernamePatchCaveat =>
      '`username`을 시스템 기본값으로 재설정하려면 `/config` 패치 업데이트가 키를 삭제할 수 없기 때문에 앱 외부에서 구성을 수정해야 합니다.';

  @override
  String get settingsConfigRefreshFailed =>
      '서버 설정을 업데이트했으나 채팅 제공자를 새로고침하지 못했습니다.';

  @override
  String get settingsConfigUpdateDeferred =>
      'CodeWalk는 현재 응답이 완료된 후 이 OpenCode 설정을 적용합니다.';

  @override
  String get settingsConversationUsername => '대화 사용자 이름';

  @override
  String get settingsDefaultAgent => '기본 에이전트';

  @override
  String get settingsDefaultModel => '기본 모델';

  @override
  String get settingsLanguageDescription =>
      'CodeWalk에서 사용할 언어를 선택하세요. 시스템 기본값은 기기 언어를 따릅니다.';

  @override
  String get settingsLanguageEmptyText => '검색된 언어가 없습니다';

  @override
  String get settingsLanguageFieldHelper => '즉시 적용되며 재시작 후에도 유지됩니다.';

  @override
  String get settingsLanguageFieldLabel => '앱 언어';

  @override
  String get settingsLanguageSearchHint => '언어 검색';

  @override
  String get settingsLanguageSystemDefault => '시스템 기본값';

  @override
  String get settingsLanguageTitle => '언어';

  @override
  String get settingsLogsDescription => '앱 진단 및 문제 해결 세부 정보 확인';

  @override
  String get settingsLogsTitle => 'Registros';

  @override
  String get settingsNoAgentsFound => '에이전트를 찾을 수 없음';

  @override
  String get settingsNotificationsAgentSubtitle => '응답이 완료되었을 때';

  @override
  String get settingsNotificationsAgentUpdates => '에이전트 업데이트';

  @override
  String get settingsNotificationsAnotherConversation => '다른 대화에 있을 때';

  @override
  String get settingsNotificationsAppInBackground => '앱이 백그라운드에 있을 때';

  @override
  String get settingsNotificationsBackgroundAlerts => 'Android 백그라운드 알림';

  @override
  String get settingsNotificationsBackgroundBehavior => '백그라운드 동작';

  @override
  String get settingsNotificationsBackgroundBehaviorDescription =>
      '앱이 포그라운드를 벗어난 후 CodeWalk가 동작하는 방식을 선택하세요.';

  @override
  String get settingsNotificationsBackgroundDescription =>
      '앱이 화면에 표시되지 않는 동안 낮은 데이터 백그라운드 모니터링을 사용하여 응답 완료, 권한 요청, 질문 및 오류를 확인합니다.';

  @override
  String get settingsNotificationsBackgroundToggle => 'Android 백그라운드 알림';

  @override
  String get settingsNotificationsBackgroundToggleDescription =>
      '모든 Android 백그라운드 확인을 끄고 지속적인 모니터링 알림을 숨깁니다.';

  @override
  String get settingsNotificationsBatteryDescription =>
      '앱을 다시 열 때만 알림이 도착하는 경우, 이 기기에서 CodeWalk가 최적화 없이 실행되도록 허용해 주세요.';

  @override
  String get settingsNotificationsBatteryDisabled =>
      'CodeWalk에 대한 배터리 최적화가 비활성화되어 있습니다.';

  @override
  String get settingsNotificationsBatteryEnabled =>
      '배터리 최적화가 활성화되어 있습니다. 일부 기기에서는 백그라운드 알림이 지연될 수 있습니다.';

  @override
  String get settingsNotificationsBatteryOptimization => 'Android 배터리 최적화';

  @override
  String get settingsNotificationsBatteryUnknown => '배터리 최적화 상태를 아직 읽을 수 없습니다.';

  @override
  String get settingsNotificationsChooseAudioFile => '오디오 파일 선택';

  @override
  String get settingsNotificationsChooseSystemSound => '시스템 소리 선택';

  @override
  String get settingsNotificationsCloseToTray => '트레이로 닫기';

  @override
  String get settingsNotificationsCloseToTrayDescription =>
      '창을 숨기고 시스템 트레이에서 계속 실행합니다.';

  @override
  String get settingsNotificationsDescription => '알림받을 이벤트와 방법 선택';

  @override
  String get settingsNotificationsDisableOptimization => '최적화 비활성화';

  @override
  String get settingsNotificationsErrors => '오류';

  @override
  String get settingsNotificationsErrorsSubtitle => '세션에 실패가 보고되었을 때';

  @override
  String get settingsNotificationsJustClose => '그냥 닫기';

  @override
  String get settingsNotificationsJustCloseDescription => '어플리케이션을 완전히 종료합니다.';

  @override
  String get settingsNotificationsKeepLive => '3분 동안 알림 활성 유지';

  @override
  String get settingsNotificationsKeepLiveDescription =>
      '응답이 이미 실행 중일 때 앱을 벗어난 후에도 잠시 동안 실시간 활성 상태를 유지합니다.';

  @override
  String get settingsNotificationsLocal => '로컬';

  @override
  String get settingsNotificationsMinimizeWhenClose => '닫을 때 최소화';

  @override
  String get settingsNotificationsMinimizeWhenCloseDescription =>
      '작업 표시줄/독으로 최소화하고 계속 실행합니다.';

  @override
  String get settingsNotificationsNoCondition =>
      '선택된 조건이 없으면 모든 상황에서 알림이 허용됩니다.';

  @override
  String get settingsNotificationsNotify => '알림';

  @override
  String get settingsNotificationsNotifyOnlyWhen => '알림 조건';

  @override
  String get settingsNotificationsOpenBatterySettings => '배터리 설정 열기';

  @override
  String get settingsNotificationsPermissions => '권한 및 질문';

  @override
  String get settingsNotificationsPermissionsSubtitle => '도구가 입력을 요청할 때';

  @override
  String get settingsNotificationsPreview => '미리보기';

  @override
  String get settingsNotificationsRefreshStatus => '상태 새로고침';

  @override
  String get settingsNotificationsSearchSoundType => '소리 종류 검색';

  @override
  String get settingsNotificationsSectionDescription =>
      '알림이 표시되는 시점과 알림음 재생 여부를 제어합니다.';

  @override
  String get settingsNotificationsSectionTitle => '알림';

  @override
  String settingsNotificationsSelectedSound(String label) {
    return '선택됨: $label';
  }

  @override
  String get settingsNotificationsServer => '서버';

  @override
  String get settingsNotificationsSound => '소리';

  @override
  String get settingsNotificationsSoundBuiltInAlert => '내장 알림음';

  @override
  String get settingsNotificationsSoundBuiltInClick => '내장 클릭음';

  @override
  String get settingsNotificationsSoundOff => '꺼짐';

  @override
  String get settingsNotificationsSoundOnlyWhen => '알림음 조건';

  @override
  String get settingsNotificationsSoundPickAudioFile => '오디오 파일 선택';

  @override
  String get settingsNotificationsSoundPickFromSystem => '시스템에서 선택';

  @override
  String get settingsNotificationsSoundSystemDefault => '시스템 기본값';

  @override
  String get settingsNotificationsSoundType => '소리 종류';

  @override
  String get settingsNotificationsSyncInfo =>
      '일부 카테고리의 켜짐/꺼짐 토글은 활성 서버의 `/config`에서 동기화됩니다.';

  @override
  String get settingsNotificationsSyncInfoLocal =>
      '현재 서버가 `/config`에서 알림 토글을 노출하지 않아 로컬 값이 활성화되어 있습니다.';

  @override
  String get settingsNotificationsSystemSoundPickerTitle => '시스템 소리 선택';

  @override
  String get settingsNotificationsTitle => '알림';

  @override
  String get settingsNotificationsWhenClosing => '창을 닫을 때';

  @override
  String get settingsOpenCodeAutoUpdate => 'OpenCode 자동 업데이트';

  @override
  String get settingsOpenCodeSharingDefault => 'OpenCode 공유 기본값';

  @override
  String get settingsReadAloudEnabled => '음성으로 읽기';

  @override
  String get settingsReadAloudEnabledDescription =>
      '어시스턴트 메시지에 음성으로 읽기 버튼을 표시합니다.';

  @override
  String get settingsReadAloudPitch => '음높이';

  @override
  String get settingsReadAloudPitchDescription => '목소리의 높낮이를 조정합니다.';

  @override
  String get settingsReadAloudSectionDescription =>
      '어시스턴트의 응답을 음성으로 읽습니다. 속도, 높낮이 및 목소리를 구성하세요.';

  @override
  String get settingsReadAloudSectionTitle => '텍스트 음성 변환 (TTS)';

  @override
  String get settingsReadAloudSpeed => '속도';

  @override
  String get settingsReadAloudSpeedDescription => '읽기 속도를 조정합니다.';

  @override
  String get settingsReadAloudVoice => '목소리';

  @override
  String get settingsReadAloudVoiceHint => '읽어주기에 사용할 목소리를 선택하세요.';

  @override
  String get settingsSearchAutoUpdateMode => '자동 업데이트 모드 검색';

  @override
  String get settingsSearchDefaultAgent => '기본 에이전트 검색';

  @override
  String get settingsSearchDefaultModel => '기본 모델 검색';

  @override
  String get settingsSearchSharingMode => '공유 모드 검색';

  @override
  String get settingsSearchSmallModel => '소형 모델 검색';

  @override
  String get settingsServersActive => '활성';

  @override
  String get settingsServersChooseActive => '활성 서버 선택';

  @override
  String get settingsServersDefault => '기본값';

  @override
  String get settingsServersDescription => 'OpenCode에 연결하고 서버 관리';

  @override
  String get settingsServersTitle => '서버';

  @override
  String get settingsSessionAttentionSize => '버블 크기';

  @override
  String get settingsSessionAttentionSizeExtraLarge => '아주 크게';

  @override
  String get settingsSessionAttentionSizeExtraSmall => '아주 작게';

  @override
  String get settingsSessionAttentionSizeLarge => '크게';

  @override
  String get settingsSessionAttentionSizeSmall => '작게';

  @override
  String get settingsSessionAttentionSizeStandard => '표준';

  @override
  String get settingsSetupWizard => '설정 마법사';

  @override
  String get settingsShortcutsDescription => '키보드 단축키 찾기 및 사용자 지정';

  @override
  String get settingsShortcutsEdit => '단축키 편집';

  @override
  String get settingsShortcutsKeyboard => '키보드 단축키';

  @override
  String get settingsShortcutsReset => '단축키 초기화';

  @override
  String get settingsShortcutsSearch => '단축키 검색';

  @override
  String get settingsShortcutsTitle => '단축키';

  @override
  String get settingsSmallModel => '소형 모델';

  @override
  String get settingsSmallModelResetExplanation =>
      '`/config` 패치 업데이트는 키를 제거할 수 없으므로 `small_model`을 자동 폴백으로 재설정하려면 앱 외부에서 구성을 편집해야 합니다.';

  @override
  String get settingsSmallModelUnsetExplanation =>
      '`small_model`이 설정되지 않았으므로 OpenCode 자동 폴백이 활성화됩니다.';

  @override
  String get settingsSoundPickerNotAvailable =>
      '시스템 사운드 선택기는 이 플랫폼에서 사용할 수 없습니다.';

  @override
  String get settingsSpeechDescription => '음성 입력, 오프라인 모델 및 소리내어 읽기 설정';

  @override
  String get settingsSpeechRefreshStatus => '상태 새로고침';

  @override
  String settingsSpeechSilenceTimeout(String value) {
    return '무음 제한 시간: $value초';
  }

  @override
  String get settingsSpeechTitle => '음성 인식 (STT)';

  @override
  String get settingsTitle => '설정';

  @override
  String get settingsGroupAlertTypes => '알림 유형';

  @override
  String get settingsGroupBackgroundBehavior => '백그라운드 동작';

  @override
  String get settingsGroupChatDisplay => '채팅 표시';

  @override
  String get settingsGroupCurrentConnection => '현재 연결';

  @override
  String get settingsGroupDataAndSync => '데이터 및 동기화';

  @override
  String get settingsGroupDataReset => '데이터 및 초기화';

  @override
  String get settingsGroupDelivery => '전달 방식';

  @override
  String get settingsGroupHelp => '도움말';

  @override
  String get settingsGroupLanguageAndChat => '언어 및 채팅';

  @override
  String get settingsGroupLayoutAndText => '레이아웃 및 텍스트';

  @override
  String get settingsGroupOfflineModels => '오프라인 모델';

  @override
  String get settingsGroupOpenCodeDefaults => 'OpenCode 기본값';

  @override
  String get settingsGroupReadAloud => '소리내어 읽기';

  @override
  String get settingsGroupSavedServers => '저장된 서버';

  @override
  String get settingsGroupThemeAndColor => '테마 및 색상';

  @override
  String get settingsGroupThisDevice => '이 기기';

  @override
  String get settingsGroupVersionUpdates => '버전 및 업데이트';

  @override
  String get settingsGroupVoiceInput => '음성 입력';

  @override
  String get settingsNavigationGroupExperience => '경험';

  @override
  String get settingsNavigationGroupInput => '입력';

  @override
  String get settingsNavigationGroupSetup => '설정';

  @override
  String get settingsNavigationGroupSupport => '도움말 및 진단';

  @override
  String get settingsNavigationNoResults => '설정 항목을 찾을 수 없음';

  @override
  String get settingsNavigationSearchHint => '설정 검색';

  @override
  String get settingsUsernameClearHint =>
      'OpenCode 대화 사용자 이름을 지우려면 여전히 앱 외부에서 구성을 수정해야 합니다.';

  @override
  String get settingsUsernameEnterHint =>
      '사용자 정의 OpenCode 대화 이름을 저장하려면 사용자 이름을 입력하세요.';

  @override
  String get settingsUsernameResetExplanation =>
      '`/config` 패치 업데이트는 키를 제거할 수 없으므로 `username`을 시스템 기본값으로 재설정하려면 앱 외부에서 구성을 편집해야 합니다.';

  @override
  String get settingsUsernameUnsetExplanation =>
      'OpenCode는 `username`이 설정되지 않았으므로 시스템 사용자 이름을 사용합니다.';

  @override
  String get setupDebugBun => 'Bun';

  @override
  String get setupDebugBun2 => 'Bun';

  @override
  String get setupDebugCapturedSetupDetails => '캡처된 설정 상세 정보가 아직 없습니다';

  @override
  String get setupDebugCapturedSetupLogs => '캡처된 설정 로그';

  @override
  String get setupDebugClear => '설정 디버그 지우기';

  @override
  String get setupDebugClearSetupDebug => '설정 디버그 지우기';

  @override
  String get setupDebugCodeWalkCaptureEnough =>
      'CodeWalk가 충분한 정보를 캡처하지 못한 경우, 공식 OpenCode 로그 및 헬스 엔드포인트를 직접 확인하세요.';

  @override
  String get setupDebugCommandPath => '명령어 경로';

  @override
  String get setupDebugCommandPath2 => '명령어 경로';

  @override
  String get setupDebugCopy => '설정 디버그 복사';

  @override
  String get setupDebugCopySetupDebug => '설정 디버그 복사';

  @override
  String get setupDebugCurrentStatus => '현재 상태';

  @override
  String get setupDebugDiagnosticsLoading => '진단 정보를 아직 로드하는 중입니다.';

  @override
  String get setupDebugEnvironment => '환경 진단';

  @override
  String get setupDebugEnvironmentDiagnostics => '환경 진단 정보';

  @override
  String get setupDebugFocusedOpenCodeSetup => 'OpenCode 설정';

  @override
  String get setupDebugInstallDir => '설치 디렉토리';

  @override
  String get setupDebugInstallDirectory => '설치 디렉토리';

  @override
  String get setupDebugLatestLocalServer => '최신 로컬 서버 출력';

  @override
  String get setupDebugLogs => '캡처된 설정 로그';

  @override
  String get setupDebugManual => '수동 문제 해결';

  @override
  String get setupDebugManualTroubleshooting => '수동 문제 해결';

  @override
  String get setupDebugNetwork => '네트워크';

  @override
  String get setupDebugNetwork2 => '네트워크';

  @override
  String get setupDebugNoDetails => '캡처된 설정 상세 정보가 아직 없습니다';

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
  String get setupDebugOpenCodeSetupDebug => 'OpenCode 설정 디버그';

  @override
  String get setupDebugPlatform => '플랫폼';

  @override
  String get setupDebugPlatform2 => '플랫폼';

  @override
  String get setupDebugRunDiagnosticsTry =>
      '여기서 OpenCode에 특화된 문제 해결 세부 정보를 캡처하려면 진단을 실행하거나, 설치 방법을 시도하거나, 설정 흐름을 진행해 보세요.';

  @override
  String get setupDebugScreenCoversOpenCode =>
      '이 화면은 OpenCode 설치, 진단 및 로컬 설정 문제 해결만 다룹니다. 일반적인 CodeWalk 런타임 오류는 앱 로그를 사용하세요.';

  @override
  String get setupDebugServerOutput => '최신 로컬 서버 출력';

  @override
  String get setupDebugStatus => '현재 상태';

  @override
  String setupDebugTimeEntrySource(String source, String time) {
    return '$time - $source';
  }

  @override
  String get setupDebugTimeline => '타임라인';

  @override
  String get setupDebugTimeline2 => '타임라인';

  @override
  String get setupDebugTitle => 'OpenCode 설정';

  @override
  String get setupDebugWSL => 'WSL';

  @override
  String get setupDebugWsl => 'WSL';

  @override
  String get shortcutCloseApp => '탭/애플리케이션 닫기';

  @override
  String get shortcutCloseAppDesc => '현재 세션 탭이 있으면 닫고, 그렇지 않으면 플랫폼 동작에 따라 앱 닫기';

  @override
  String get shortcutFocusCloseDrawer => '포커스/드로어 닫기';

  @override
  String get shortcutFocusCloseDrawerDesc =>
      '기본적으로 입력 창에 포커스, 또는 열려 있을 때 드로어 닫기';

  @override
  String get shortcutFocusInput => '입력 창 포커스';

  @override
  String get shortcutFocusInputDesc => '텍스트 입력 창으로 포커스 이동';

  @override
  String get shortcutGroupApplication => '애플리케이션';

  @override
  String get shortcutGroupGeneral => '일반';

  @override
  String get shortcutGroupModelAndAgent => '모델 및 에이전트';

  @override
  String get shortcutGroupNavigation => '내비게이션';

  @override
  String get shortcutGroupPrompt => '프롬프트';

  @override
  String get shortcutGroupSession => '세션';

  @override
  String get shortcutNewConversation => '새 대화';

  @override
  String get shortcutNewConversationDesc => '새 채팅 세션 생성';

  @override
  String get shortcutNextAgent => '다음 에이전트';

  @override
  String get shortcutNextAgentDesc => '다음 사용 가능한 에이전트로 전환';

  @override
  String get shortcutNextRecentModel => '다음 최근 모델';

  @override
  String get shortcutNextRecentModelDesc => '최근에 사용한 모델 간 전환';

  @override
  String get shortcutNextVariant => '다음 변형';

  @override
  String get shortcutNextVariantDesc => '사용 가능한 모델 변형 간 전환';

  @override
  String get shortcutOpenSettings => '설정 열기';

  @override
  String get shortcutOpenSettingsDesc => '설정 페이지 열기';

  @override
  String get shortcutPreviousAgent => '이전 에이전트';

  @override
  String get shortcutPreviousAgentDesc => '이전 사용 가능한 에이전트로 전환';

  @override
  String get shortcutQuickOpenFiles => '파일 빠른 열기';

  @override
  String get shortcutQuickOpenFilesDesc => '파일 빠른 검색 열기';

  @override
  String get shortcutQuitApp => '애플리케이션 종료';

  @override
  String get shortcutQuitAppDesc => '앱 강제 종료';

  @override
  String get shortcutRefreshData => '데이터 새로 고침';

  @override
  String get shortcutRefreshDataDesc => '현재 채팅 데이터 새로 고침';

  @override
  String get shortcutStopResponse => '응답 중지';

  @override
  String get shortcutStopResponseDesc => '활성 응답 중지 (응답 중)';

  @override
  String get shortcutToggleVoiceInput => '음성 입력 전환';

  @override
  String get shortcutToggleVoiceInputDesc => '에디터에서 음성 받아쓰기 시작 또는 중지';

  @override
  String get shortcutsApply => '적용';

  @override
  String shortcutsConflictConflict(String conflict) {
    return '$conflict과(와) 충돌';
  }

  @override
  String get shortcutsKeyboardShortcuts => '키보드 단축키';

  @override
  String get shortcutsReset => '모두 초기화';

  @override
  String get shortcutsSearchEditBindings => '저장하기 전에 단축키를 검색 및 편집하고 충돌을 해결하세요.';

  @override
  String shortcutsSetShortcutWidget(String label) {
    return '단축키 설정: $label';
  }

  @override
  String get shortcutsTheseBindingsStored =>
      '이 단축키 설정은 현재 앱 런타임의 CodeWalk에 저장되며, OpenCode `tui.json` 키 바인딩을 수정하지 않습니다.';

  @override
  String get speechAutoStopSilence => '자동 정지 무음 시간 제한';

  @override
  String get speechChooseRecognitionEngine =>
      '음성 인식 엔진, 무음 시간 제한 및 모델 옵션을 선택하세요.';

  @override
  String speechDesktopOnly(String service) {
    return '$service은(는) 데스크톱에서만 사용할 수 있습니다.';
  }

  @override
  String get speechDownload => '다운로드';

  @override
  String get speechEngine => '엔진';

  @override
  String get speechInstalledLanguages => '설치된 언어';

  @override
  String get speechListeningStopsAutomatically =>
      '지정한 초 동안 무음 상태가 지속되면 음성 인식이 자동으로 정지됩니다.';

  @override
  String get speechMicPermissionDisabled => '마이크 권한이 비활성화되어 있습니다.';

  @override
  String speechModelFilesIncomplete(String service) {
    return '$service 모델 파일이 불완전합니다.';
  }

  @override
  String get speechMoonshine => 'Moonshine';

  @override
  String get speechMoonshineModelsDesktop => 'Moonshine 모델 (데스크톱)';

  @override
  String get speechMoonshineStaysDownloadable =>
      'Moonshine은 앱 번들에 포함되지 않고 다운로드 가능한 상태로 유지됩니다. 이 데스크톱 기기에 맞게 하나의 모델을 선택하고, 공간을 확보하고 싶다면 나중에 제거하세요.';

  @override
  String get speechNative => '기본 제공 엔진';

  @override
  String get speechNativeSTTDisabled =>
      '이 앱의 Linux 환경에서는 네이티브 STT 기능이 비활성화되어 있습니다. 신규 설치의 경우 Parakeet가 기본 엔진입니다.';

  @override
  String get speechNativeSTTWorks =>
      'Windows에서는 CodeWalk가 WASAPI 마이크 백엔드를 통해 로컬 온디바이스 음성 인식을 사용합니다. 안정성을 위해 Windows 네이티브 음성 인식은 비활성화되어 있습니다.';

  @override
  String get speechNativeStartsFaster =>
      '네이티브 방식이 더 빠르게 시작됩니다. Sherpa는 비교적 무거운 구성과 심층적인 모델 제어 기능을 통해 기기 자체에서 완전히 작동합니다.';

  @override
  String get speechOpenMicrophoneSettings => '마이크 설정 열기';

  @override
  String get speechOpenSpeechPrivacy => '음성 개인 정보 보호 설정 열기';

  @override
  String get speechOpenSpeechSettings => '음성 설정 열기';

  @override
  String get speechParakeet => 'Parakeet';

  @override
  String get speechParakeetModelsDesktop => 'Parakeet 모델 (데스크톱)';

  @override
  String get speechParakeetStaysDownloadable =>
      'Parakeet는 앱 번들에 포함되지 않고 다운로드 가능한 상태로 유지됩니다. 현재 25개 유럽 언어에 최적화된 다국어 모델 하나를 제공하고 있습니다.';

  @override
  String get speechPickLanguagePacks =>
      '기기 내 음성 인식을 위해 언어 팩을 선택하고 모델을 다운로드하거나 제거하세요.';

  @override
  String get speechRemove => '제거';

  @override
  String speechRuntimeFailed(String service) {
    return '$service 런타임을 초기화하지 못했습니다.';
  }

  @override
  String get speechSelectSherpaAbove =>
      '언어 팩을 관리하고 모델을 다운로드하려면 위에서 Sherpa를 선택하세요.';

  @override
  String get speechSenseVoice => 'SenseVoice';

  @override
  String get speechSenseVoiceModelsDesktop => 'SenseVoice 모델 (데스크톱)';

  @override
  String get speechSenseVoiceStaysDownloadable =>
      'SenseVoice는 앱 번들에 포함되지 않고 다운로드 가능한 상태로 유지됩니다. 중국어, 광둥어, 일본어, 한국어, 영어에 대한 데스크톱 기준 가장 강력한 옵션입니다.';

  @override
  String get speechSherpa => 'Sherpa';

  @override
  String get speechSherpaExperimentalFail =>
      'Sherpa는 실험적 기능이며 일부 기기에서 작동하지 않을 수 있습니다. 가장 안정적인 동작을 원하시면 네이티브(Native) 방식을 권장합니다.';

  @override
  String get speechSherpaModelsLinux => 'Sherpa 모델 (Linux)';

  @override
  String get speechSpeechText => '음성 인식 (STT)';

  @override
  String speechUnavailableOnPlatform(String service) {
    return '$service 음성을 이 플랫폼에서 사용할 수 없습니다.';
  }

  @override
  String get speechWindowsSetupHint =>
      'Windows 음성 입력은 온디바이스 모델과 함께 CodeWalk WASAPI 캡처를 사용합니다. 데스크톱 앱의 마이크 액세스를 활성화된 상태로 유지하세요. 아래 버튼은 문제 해결을 위해 Windows 설정을 엽니다.';

  @override
  String get statusConnected => '연결됨';

  @override
  String get statusDelayed => '지연됨';

  @override
  String get statusFailed => '실패';

  @override
  String get statusOffline => '오프라인';

  @override
  String get statusOnline => '온라인';

  @override
  String get statusReconnecting => '재연결 중';

  @override
  String get statusStarting => '시작 중';

  @override
  String get statusStopped => '중지됨';

  @override
  String get statusStopping => '중지 중';

  @override
  String get statusSyncDelayed => '동기화 지연됨';

  @override
  String get tailscaleNoPeers => '연결된 기기(Peer)를 찾을 수 없음';

  @override
  String get tailscaleNotSupportedOnPlatform =>
      '이 플랫폼에서는 Tailscale을 지원하지 않습니다.';

  @override
  String get tailscaleNotSupportedOnWindows =>
      'Windows에서는 Tailscale을 지원하지 않습니다.';

  @override
  String get tailscalePeerOffline => '오프라인';

  @override
  String get tailscaleSelectPeer => 'Tailscale 기기(Peer) 선택';

  @override
  String get tailscaleWaitingAdminApproval =>
      '이 Tailscale 노드는 관리자 승인을 기다리고 있습니다.';

  @override
  String get terminalClose => '터미널 닫기';

  @override
  String terminalConnectingTo(String serverName) {
    return '$serverName 터미널에 연결 중...';
  }

  @override
  String terminalConnectionFailed(String error) {
    return '터미널 연결 실패: $error';
  }

  @override
  String get terminalDisconnected => '터미널 연결이 끊어졌습니다.';

  @override
  String terminalEmbeddedUnavailable(String serverName) {
    return '내장 터미널은 아직 이 런타임에서 사용할 수 없습니다. 일회성 명령에는 컴포저 쉘 모드를 계속 사용하거나 지원되는 CodeWalk 앱 런타임에서 $serverName의 터미널을 여세요.';
  }

  @override
  String get terminalExtraKeyAlt => 'Alt 키';

  @override
  String get terminalExtraKeyArrowDown => '아래쪽 화살표';

  @override
  String get terminalExtraKeyArrowLeft => '왼쪽 화살표';

  @override
  String get terminalExtraKeyArrowRight => '오른쪽 화살표';

  @override
  String get terminalExtraKeyArrowUp => '위쪽 화살표';

  @override
  String get terminalExtraKeyControl => 'Control 키';

  @override
  String get terminalExtraKeyEscape => 'Escape 키';

  @override
  String get terminalExtraKeyTab => 'Tab 키';

  @override
  String get terminalExtraKeys => '터미널 추가 키';

  @override
  String get terminalHide => '터미널 숨기기';

  @override
  String get terminalMaximize => '최대화';

  @override
  String get terminalMinimize => '터미널 최소화';

  @override
  String get terminalNotAvailableYet => '이 런타임에서는 임베디드 터미널을 아직 사용할 수 없습니다.';

  @override
  String get terminalOpen => '터미널 열기';

  @override
  String get terminalOpenInfo => '터미널 정보 열기';

  @override
  String get terminalOpenProjectFirst => '서버 터미널을 시작하기 전에 프로젝트 폴더를 여십시오.';

  @override
  String get terminalOpenToConnect => '터미널을 열어 서버 프로젝트 터미널에 연결하십시오.';

  @override
  String get terminalReconnect => '터미널 재연결';

  @override
  String get terminalRestoreSize => '크기 복원';

  @override
  String get terminalSelectServer => '터미널을 열기 전에 활성 서버를 선택하십시오.';

  @override
  String get terminalSessionClosed => '터미널 세션이 종료되었습니다.';

  @override
  String get terminalTerminal => '터미널';

  @override
  String get terminalTitle => '터미널';

  @override
  String get terminalTryAgain => '다시 시도';

  @override
  String get toolAwaitingInput => '입력 대기 중';

  @override
  String get toolEditing => '편집 중';

  @override
  String get toolEditingFiles => '파일 편집 중';

  @override
  String get toolFinding => '찾는 중';

  @override
  String get toolFindingFiles => '파일 찾는 중';

  @override
  String get toolPresentationAwaitingInput => '입력 대기 중';

  @override
  String get toolPresentationEditing => '편집 중';

  @override
  String get toolPresentationEditingFiles => '파일 편집 중';

  @override
  String get toolPresentationFinding => '찾는 중';

  @override
  String get toolPresentationFindingFiles => '파일 찾는 중';

  @override
  String get toolPresentationReading => '읽는 중';

  @override
  String get toolPresentationReadingFile => '파일 읽는 중';

  @override
  String get toolPresentationRunning => '실행 중';

  @override
  String get toolPresentationRunningCommand => '명령어 실행 중';

  @override
  String toolPresentationRunningTool(String toolName) {
    return '$toolName 실행 중';
  }

  @override
  String get toolPresentationSearching => '검색 중';

  @override
  String get toolPresentationSearchingCode => '코드 검색 중';

  @override
  String get toolPresentationSearchingWeb => '웹 검색 중';

  @override
  String get toolPresentationTool => '도구';

  @override
  String get toolPresentationUpdatingTaskList => '작업 목록 업데이트 중';

  @override
  String get toolPresentationUpdatingTasks => '작업 업데이트 중';

  @override
  String get toolPresentationWaitingInput => '입력 대기 중';

  @override
  String get toolPresentationWriting => '기록 중';

  @override
  String get toolPresentationWritingFile => '파일 기록 중';

  @override
  String get toolReading => '읽는 중';

  @override
  String get toolReadingFile => '파일 읽는 중';

  @override
  String get toolRunning => '실행 중';

  @override
  String get toolRunningCommand => '명령어 실행 중';

  @override
  String get toolRunningTask => '작업 실행 중';

  @override
  String get toolSearching => '검색 중';

  @override
  String get toolSearchingCode => '코드 검색 중';

  @override
  String get toolSearchingWeb => '웹 검색 중';

  @override
  String get toolUpdatingTaskList => '작업 목록 업데이트 중';

  @override
  String get toolUpdatingTasks => '작업 업데이트 중';

  @override
  String get toolWaitingForInput => '입력 대기 중';

  @override
  String get toolWriting => '기록 중';

  @override
  String get toolWritingFile => '파일 기록 중';

  @override
  String get tourBack => '뒤로';

  @override
  String get tourSkip => '건너뛰기';

  @override
  String get trayQuit => '종료';

  @override
  String get trayShow => '보이기';

  @override
  String get useOAuthCloudflareAccess => 'OAuth 사용 (Cloudflare Access)';

  @override
  String get useOAuthCloudflareAccessSubtitle =>
      'Cloudflare Access 관리형 OAuth 인증을 위해 브라우저를 엽니다.';

  @override
  String get useOAuthCloudflareAccessUnsupported =>
      '이 플랫폼에서는 Cloudflare Access OAuth를 사용할 수 없습니다. 대신 기본 인증을 사용하세요.';

  @override
  String get useTailscale => 'Tailscale 사용';

  @override
  String get useTailscaleSubtitle =>
      '시스템 VPN 없이 Tailscale 네트워크를 통해 트래픽을 라우팅합니다.';

  @override
  String get useTailscaleUnsupported => '이 플랫폼에서는 Tailscale이 지원되지 않습니다.';

  @override
  String get utilityTitle => '유틸리티';

  @override
  String get workspaceBrowseDirs => '디렉토리 찾아보기';

  @override
  String get workspaceChooseFolderOpen => '프로젝트 컨텍스트로 열 폴더를 선택하세요.';

  @override
  String workspaceCloseProject(String project) {
    return '$project 닫기';
  }

  @override
  String get workspaceClosedProjects => '닫힌 프로젝트';

  @override
  String workspaceCurrentDirectory(String path) {
    return '현재 디렉터리: $path';
  }

  @override
  String get workspaceFilterDirs => '디렉토리 필터';

  @override
  String get workspaceOpenFolder => '폴더 열기';

  @override
  String get workspaceOpenProjectFolder => '프로젝트 폴더 열기';

  @override
  String get workspaceOpenProjects => '열린 프로젝트';

  @override
  String get workspaceProjectDirectory => '프로젝트 디렉토리';

  @override
  String get workspaceProjectHint => '/repo/my-project';

  @override
  String workspaceRemoveFromHistory(String name) {
    return '기록에서 $name 제거';
  }

  @override
  String get settingsSessionAttentionTitle => '세션 알림';

  @override
  String get settingsSessionAttentionDescription =>
      '루트 세션 상태를 선택적 버블이나 패널에 표시합니다.';

  @override
  String get settingsSessionAttentionOff => '끄기';

  @override
  String get settingsSessionAttentionBubble => '버블';

  @override
  String get settingsSessionAttentionPanel => '패널';

  @override
  String get settingsSessionAttentionPrivacy =>
      'Android에서 사용하면 지속적인 포그라운드 서비스가 시작됩니다. 응답 텍스트는 암호화되어 저장되며 클라우드 TTS에는 읽기를 누른 후에만 전송됩니다.';

  @override
  String get settingsSessionAttentionUnavailable =>
      '이 플랫폼에서는 세션 알림을 사용할 수 없습니다.';

  @override
  String get settingsSessionAttentionOpenSettings => '표시 설정 열기';

  @override
  String get settingsSessionAttentionStop => '세션 알림 중지';

  @override
  String get settingsSessionAttentionThirdPartyTtsWarning =>
      '읽기를 누르면 응답 텍스트가 설정된 타사 TTS 제공업체로 전송될 수 있습니다.';

  @override
  String get workspaceSuggestions => '추천 프로젝트';

  @override
  String get sessionTabsGestureHintTitle => '세션 탭에 새 제어 기능이 추가되었습니다';

  @override
  String get sessionTabsGestureHintBody =>
      '탭을 두 번 클릭하거나 두 번 탭하면 닫힙니다. 오른쪽 클릭하거나 길게 누르면 세션 작업이 열립니다. 화면 표시 토글에서 탭을 비활성화할 수 있습니다.';

  @override
  String get sessionTabsGestureHintAcknowledge => '알겠습니다';

  @override
  String get sessionTabsGestureHintDisableTabs => '탭 사용 안 함';

  @override
  String get sessionTabRenameAction => '세션 이름 변경';

  @override
  String sessionTabClosedMessage(String title) {
    return '탭 \"$title\"이(가) 닫혔습니다';
  }

  @override
  String get sessionTabUndo => '실행 취소';

  @override
  String get sessionTabRestoreFailed => '탭을 복원할 수 없습니다.';

  @override
  String get sessionTabChangeIconAction => '아이콘 변경';

  @override
  String get sessionTabIconPickerTitle => '탭 아이콘 선택';

  @override
  String get sessionTabIconUseProjectIcon => '프로젝트 아이콘 사용';

  @override
  String get sessionTabIconApplied => '탭 아이콘이 업데이트되었습니다.';

  @override
  String get sessionTabIconSaveFailed => '탭 아이콘을 저장할 수 없습니다.';

  @override
  String get sessionTabIconPresetCode => '코드';

  @override
  String get sessionTabIconPresetTerminal => '터미널';

  @override
  String get sessionTabIconPresetBug => '버그';

  @override
  String get sessionTabIconPresetTasks => '작업';

  @override
  String get sessionTabIconPresetLaunch => '시작';

  @override
  String get sessionTabIconPresetIdea => '아이디어';

  @override
  String get sessionTabIconPresetResearch => '연구';

  @override
  String get sessionTabIconPresetDesign => '디자인';

  @override
  String get sessionTabIconPresetData => '데이터';

  @override
  String get sessionTabIconPresetCloud => '클라우드';

  @override
  String get sessionTabIconPresetSecurity => '보안';

  @override
  String get sessionTabIconPresetTools => '도구';

  @override
  String get workspaceNoActiveContext => '활성 컨텍스트 없음';

  @override
  String get settingsAppearanceContrastLow => '낮음';

  @override
  String get settingsAppearanceContrastStandard => '표준';

  @override
  String get settingsAppearanceContrastMedium => '중간';

  @override
  String get settingsAppearanceContrastMediumHigh => '중간 높음';

  @override
  String get settingsNotificationsSystemSoundsWebUnavailable =>
      '웹에서는 사용할 수 없습니다.';

  @override
  String get settingsNotificationsSystemSoundsAndroid => '시스템의 Android 알림음입니다.';

  @override
  String get settingsNotificationsSystemSoundsFreedesktop =>
      '/usr/share/sounds/freedesktop/stereo의 Freedesktop 소리입니다.';

  @override
  String get settingsNotificationsSystemSoundsPlatform =>
      '운영 체제가 시스템 소리를 제공하는 플랫폼에서 지원됩니다.';

  @override
  String get serversQuickGuideTitle => '빠른 설정';

  @override
  String get serversQuickGuideIntro =>
      'CodeWalk는 앱입니다. OpenCode는 이 연결이 작동하려면 실행 중이어야 하는 엔진입니다.';

  @override
  String get serversQuickGuideStepInstallCli => '1. OpenCode CLI 설치.';

  @override
  String get serversQuickGuideRunPowerShell => '2. PowerShell에서 실행:';

  @override
  String get serversQuickGuideRunTerminal => '2. 터미널에서 실행:';

  @override
  String get serversQuickGuideProtectPassword => '비밀번호로 액세스 보호';

  @override
  String get serversQuickGuideServerPassword => '서버 비밀번호';

  @override
  String get serversQuickGuideInstallOptions =>
      '기타 공식 설치 옵션: 설치 스크립트, npm, bun, pnpm, Homebrew 또는 GitHub Releases의 바이너리.';

  @override
  String get serversQuickGuideVerifyHint =>
      '서버를 시작한 후 /global/health 또는 /doc가 응답하는지 확인한 다음 URL을 CodeWalk에 붙여넣으세요.';

  @override
  String get shortcutsPressKeyCombination => '지금 키 조합을 누르세요';

  @override
  String get settingsProvenanceOpenCodeBacked => 'OpenCode 기반';

  @override
  String get settingsProvenanceCodeWalkLocal => 'CodeWalk 로컬';

  @override
  String get settingsProvenanceCodeWalkException => 'CodeWalk 예외';

  @override
  String get shortcutsErrorInvalid => '잘못된 단축키';

  @override
  String get shortcutsErrorUnsupportedKey => '지원하지 않는 단축키';

  @override
  String shortcutsErrorConflict(String conflict) {
    return '\"$conflict\"과(와) 충돌';
  }

  @override
  String get settingsSessionAttentionStopSaveFailed =>
      '세션 알림이 중지되었지만 설정을 저장하지 못했습니다.';

  @override
  String get settingsSessionAttentionEnableFailed => '세션 알림을 활성화할 수 없습니다.';

  @override
  String get settingsSessionAttentionSaveFailedStopped =>
      '세션 알림 설정을 저장하지 못해 중지되었습니다.';

  @override
  String get settingsSessionAttentionStillRunning =>
      '세션 알림이 아직 실행 중입니다. 다시 중지를 시도하세요.';

  @override
  String get settingsSessionAttentionStopFailed =>
      '세션 알림을 중지할 수 없습니다. 다시 시도하세요.';

  @override
  String get settingsSessionAttentionCapabilityUnavailable =>
      '세션 알림 호스트 기능을 사용할 수 없습니다.';

  @override
  String get settingsServerFallbackProviderName => '서버에서 구성됨';

  @override
  String get composerStopResponse => '응답 중지';

  @override
  String get composerSendMessageWhileResponding => '응답 실행 중 메시지 전송';

  @override
  String get composerSendMessage => '메시지 전송';

  @override
  String get chatTourComposerDescription => '요청을 여기에 입력하세요.';

  @override
  String get chatTourSendDescription => '메시지를 여기서 보내세요.';

  @override
  String get composerAttachmentFallbackName => '첨부 파일';

  @override
  String get composerContextFallbackName => '컨텍스트';

  @override
  String get searchableDropdownSearchHint => '검색';

  @override
  String get searchableDropdownEmptyText => '일치하는 항목 없음';

  @override
  String get speechApiKeyStorageUnavailable => '보안 TTS API 키 저장소를 사용할 수 없습니다.';

  @override
  String get speechApiKeyRemoved => 'API 키가 제거되었습니다.';

  @override
  String get speechApiKeySaved => 'API 키가 이 기기에 안전하게 저장되었습니다.';

  @override
  String get speechReadAloudTestText => '이것은 CodeWalk 텍스트 음성 변환 테스트입니다.';

  @override
  String get speechNativeDisabledWindows =>
      '안정성을 위해 Windows에서는 비활성화됩니다. CodeWalk WASAPI 캡처를 통해 Parakeet 또는 다른 기기 내 엔진을 사용하세요.';

  @override
  String get speechNativeUnavailableLinux =>
      'Linux에서는 사용할 수 없습니다. 음성 입력에는 Parakeet을 사용하세요.';

  @override
  String get speechNotAvailableOnPlatform => '이 플랫폼에서는 사용할 수 없습니다.';

  @override
  String get speechSherpaUnavailableAndroid =>
      '작은 APK 크기에 최적화된 Android 빌드에서는 사용할 수 없습니다.';

  @override
  String get speechMoonshineDesktopOnlyHint =>
      '데스크톱에서만 사용할 수 있습니다. Android는 기본 엔진만 지원합니다.';

  @override
  String get speechParakeetDesktopOnlyHint =>
      '데스크톱에서만 사용할 수 있습니다. 오프라인 다국어 인식을 사용합니다.';

  @override
  String get speechSenseVoiceDesktopOnlyHint =>
      '데스크톱에서만 사용할 수 있습니다. 중국어, 광둥어, 일본어, 한국어, 영어에 가장 적합합니다.';

  @override
  String get speechNativeSubtitle => '더 간단하고 빠르게 시작됩니다.';

  @override
  String get speechSherpaSubtitle =>
      '더 무겁고 실험적이며 버그가 발생하기 쉽습니다. 다운로드한 모델에서는 종종 더 정확합니다.';

  @override
  String get speechMoonshineSubtitle =>
      'sherpa_onnx 오프라인 인식과 다운로드 가능한 모델을 사용하는 데스크톱 전용 실험 경로입니다.';

  @override
  String get speechParakeetSubtitle =>
      '하나의 다국어 다운로드 모델을 제공하는 데스크톱 전용 오프라인 NeMo 트랜스듀서 경로입니다.';

  @override
  String get speechSenseVoiceSubtitle =>
      '중국어, 광둥어, 일본어, 한국어, 영어에 맞춘 데스크톱 전용 오프라인 경로입니다.';

  @override
  String get speechMoonshineModel => 'Moonshine 모델';

  @override
  String get speechSherpaLanguage => 'Sherpa 언어';

  @override
  String get speechSearchSherpaLanguage => 'Sherpa 언어 검색';

  @override
  String get speechNoLanguagePacksFound => '언어 팩을 찾을 수 없음';

  @override
  String get speechTextToSpeechProvider => '텍스트 음성 변환 제공자';

  @override
  String get speechProviderSystemNative => '시스템 / 기본';

  @override
  String get speechProviderEdgeExperimental => 'Microsoft Edge Speech (실험적)';

  @override
  String get speechProviderOpenAiCompatible => 'OpenAI 호환';

  @override
  String get speechProviderElevenLabs => 'ElevenLabs';

  @override
  String get speechProviderNvidiaNim => 'NVIDIA NIM';

  @override
  String get speechNimSpeedNotSupported =>
      '속도는 NVIDIA NIM TTS에서 지원되지 않으며 이 공급자에서는 숨겨집니다.';

  @override
  String get speechRemoteVoice => '음성';

  @override
  String get speechRemoteVoiceUnavailable => '선택한 음성은 더 이상 공급자 카탈로그에 없습니다.';

  @override
  String get speechRemoteVoiceListUnavailable =>
      '기본 음성이 사용 중입니다. 현재 음성 목록을 불러올 수 없습니다.';

  @override
  String get speechRemoteVoicesLoaded => '공급자 음성에서 불러왔습니다.';

  @override
  String get speechRemoteModel => '모델';

  @override
  String get speechRemoteModelListUnavailable =>
      '현재 모델 목록을 불러올 수 없습니다. 아래에서 사용자 지정 모델을 입력할 수 있습니다.';

  @override
  String get speechRemoteModelsLoaded => '공급자 모델에서 불러왔습니다.';

  @override
  String get speechRemoteModelUnavailable => '선택한 모델은 더 이상 공급자 카탈로그에 없습니다.';

  @override
  String get speechCustomModel => '사용자 지정 모델…';

  @override
  String get speechEdgeExperimentalTitle => 'Microsoft Edge Speech는 실험적입니다';

  @override
  String get speechEdgeExperimentalDescription =>
      '비공식 Edge 읽어주기 서비스를 이 기기에서 직접 사용합니다. 읽어주기를 사용하면 메시지 텍스트가 Microsoft로 전송되며, Microsoft가 비공개 프로토콜을 변경하면 서비스가 중단될 수 있습니다.';

  @override
  String get speechEdgeVoice => 'Edge 음성';

  @override
  String get speechEdgeVoiceUnavailable =>
      '선택한 목소리를 더 이상 사용할 수 없습니다. 기본 Edge 목소리를 사용합니다.';

  @override
  String get speechEdgeVoiceListUnavailable =>
      '기본 Edge 음성을 사용 중입니다. 지금은 음성 목록을 불러올 수 없습니다.';

  @override
  String get speechEdgeVoicesLoaded => 'Microsoft Edge Speech 음성에서 로드되었습니다.';

  @override
  String get speechCloudTtsPrivacy => '클라우드 TTS 개인정보 보호';

  @override
  String get speechCloudTtsPrivacyDescription =>
      '클라우드 TTS는 선택한 어시스턴트 메시지 텍스트를 설정된 제공자에게 전송합니다. API 키는 이 기기의 보안 저장소에 저장됩니다.';

  @override
  String get speechBaseUrl => '기본 URL';

  @override
  String get speechApiKey => 'API 키';

  @override
  String get speechApiKeySavedHelper =>
      '저장된 키가 있습니다. 새 값을 입력하여 교체하거나 빈 값을 저장하여 제거하세요.';

  @override
  String get speechNoApiKeySaved => '저장된 API 키가 없습니다.';

  @override
  String get speechSaveApiKey => 'API 키 저장';

  @override
  String get speechModel => '모델';

  @override
  String get speechPitchNotSupported =>
      '피치는 OpenAI 호환 TTS에서 지원되지 않으므로 이 제공자에서는 숨겨집니다.';

  @override
  String get speechPitchHiddenForProvider => '피치는 이 TTS 공급자에서 지원되지 않으며 숨겨집니다.';

  @override
  String get speechTestVoice => '음성 테스트';

  @override
  String get dialogMoonshineVoiceSetupDescription =>
      'Moonshine은 sherpa_onnx를 통해 기기에서 실행됩니다. 모델을 한 번 선택하고 이 데스크톱 기기에만 다운로드하세요.';

  @override
  String get dialogParakeetVoiceSetupDescription =>
      'Parakeet은 sherpa_onnx 오프라인 인식을 통해 기기에서 실행됩니다. 다국어 STT를 사용하려면 이 데스크톱 기기에 한 번 다운로드하세요.';

  @override
  String get dialogSenseVoiceSetupDescription =>
      'SenseVoice는 sherpa_onnx 오프라인 인식을 통해 기기에서 실행됩니다. 중국어, 광둥어, 일본어, 한국어, 영어에 가장 적합합니다.';

  @override
  String get dialogSherpaVoiceSetupDescription =>
      'Sherpa 음성 입력에는 기기 내 음성 모델이 필요합니다. 언어를 선택하고 한 번 다운로드하세요 (~147 MB).';

  @override
  String speechSilenceSeconds(String value) {
    return '$value초';
  }

  @override
  String speechModelInstalled(String modelId) {
    return '모델 설치됨 ($modelId)';
  }

  @override
  String speechModelMissing(String modelId) {
    return '모델 없음 ($modelId)';
  }

  @override
  String speechModelSizeMb(String sizeMb) {
    return '~$sizeMb MB';
  }

  @override
  String speechSystemDefaultLanguage(String language) {
    return '시스템 기본값 ($language)';
  }

  @override
  String speechModelListLoadFailed(String error, String service) {
    return '$service 모델 목록을 불러오지 못했습니다: $error';
  }

  @override
  String speechDownloadFailed(String error) {
    return '다운로드 실패: $error';
  }

  @override
  String speechFailedToRemoveModel(String error) {
    return '모델 제거 실패: $error';
  }

  @override
  String speechBaseUrlExample(String url) {
    return '예: $url';
  }

  @override
  String speechModelDefaultHelper(String model) {
    return '기본값: $model';
  }

  @override
  String get notificationPermissionOrQuestionNeedsInput =>
      '도구 권한 또는 질문에 대한 입력이 필요합니다.';

  @override
  String get notificationPermissionNeedsInput => '도구 권한에 대한 입력이 필요합니다.';

  @override
  String get notificationQuestionNeedsInput => '도구 질문에 대한 입력이 필요합니다.';

  @override
  String get notificationSessionError => '세션에서 오류가 보고되었습니다.';

  @override
  String get notificationChannelErrors => 'CodeWalk 오류';

  @override
  String get notificationChannelErrorsDescription => 'CodeWalk 오류 알림';

  @override
  String get notificationChannelPermissions => 'CodeWalk 권한';

  @override
  String get notificationChannelPermissionsDescription => 'CodeWalk 작업 필요 알림';

  @override
  String get notificationChannelAgent => 'CodeWalk 에이전트';

  @override
  String get notificationChannelAgentDescription => 'CodeWalk 에이전트 완료 알림';

  @override
  String get notificationActionOpen => '열기';

  @override
  String get foregroundMonitorNotificationBody => '안정적인 백그라운드 알림이 활성화되어 있습니다';

  @override
  String get foregroundMonitorNotificationTitle => '백그라운드 모니터링 활성화됨';

  @override
  String get foregroundMonitorNotificationOneSession => '세션 1개 모니터링 중';

  @override
  String foregroundMonitorNotificationSessionCount(int count) {
    return '$count개 세션 모니터링 중';
  }

  @override
  String sessionAttentionSemanticLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 세션에 주의가 필요합니다',
      one: '1개 세션에 주의가 필요합니다',
    );
    return '$_temp0';
  }

  @override
  String get sessionAttentionOverlayPermissionRequired =>
      '다른 앱 위에 표시 권한이 필요합니다.';

  @override
  String get sessionAttentionIosInAppOnly => '세션 알림은 CodeWalk 내에서만 사용할 수 있습니다.';

  @override
  String get sessionAttentionOverlayPermissionGrantPrompt =>
      '다른 앱 위에 표시 권한을 허용한 후 다시 시도하세요.';

  @override
  String get sessionAttentionAndroidStartFailed =>
      'Android 세션 알림 서비스를 시작할 수 없습니다.';

  @override
  String chatMessageTruncatedChars(int count, String reason) {
    return '[$count자 잘림] $reason';
  }

  @override
  String get chatMessageJustNow => '방금';

  @override
  String chatMessageMinutesAgo(int count) {
    return '$count분 전';
  }

  @override
  String chatMessageHoursAgo(int count) {
    return '$count시간 전';
  }

  @override
  String chatMessageDaysAgo(int count) {
    return '$count일 전';
  }

  @override
  String chatMessageDateTime(int day, int hour, int minute, int month) {
    return '$month/$day $hour:$minute';
  }

  @override
  String get chatMessageYourMessage => '내 메시지';

  @override
  String get chatMessageAssistantMessage => '어시스턴트 메시지';

  @override
  String chatMessageStepStarted(int step) {
    return '#$step 단계 시작됨';
  }

  @override
  String chatMessageStepStartedWithSnapshot(String snapshot, int step) {
    return '#$step 단계 시작됨: $snapshot';
  }

  @override
  String chatMessageStepFinished(
    String cost,
    String reason,
    int step,
    int tokens,
  ) {
    return '#$step 단계 완료: $reason • 토큰 $tokens개 • 비용 \$$cost';
  }

  @override
  String chatMessagePatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '패치 $count개',
      one: '패치 1개',
    );
    return '$_temp0';
  }

  @override
  String get chatMessageToolRun => '도구 실행';

  @override
  String get chatMessageToolExecution => '도구 실행';

  @override
  String chatMessageToolChainMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count개 더',
      one: '+1개 더',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolChainExtraTypes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '유형 +$count개',
      one: '유형 +1개',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolAttentionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개에 주의 필요',
      one: '1개에 주의 필요',
    );
    return '$_temp0';
  }

  @override
  String chatMessageToolDoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 완료',
      one: '1개 완료',
    );
    return '$_temp0';
  }

  @override
  String get chatMessageToolCallsTitle => '도구 호출';

  @override
  String get chatMessageDiffPreviewTruncated => '앱 안정성을 위해 Diff 미리보기가 잘렸습니다.';

  @override
  String get chatMessageLargeMessageTruncated => '앱 안정성을 위해 큰 메시지 미리보기가 잘렸습니다.';

  @override
  String get chatMessageInvalidLinkFormat => '잘못된 링크 형식';

  @override
  String get chatMessageUnableToOpenLink => '링크를 열 수 없습니다';

  @override
  String sessionTodoInProgressCompact(int current, int total) {
    return '$current/$total 진행 중';
  }

  @override
  String sessionTodoTaskProgress(String content, int index, int total) {
    return '작업 $index/$total $content';
  }

  @override
  String sessionTodoDoneCompact(int count, int total) {
    return '$count/$total 완료';
  }

  @override
  String sessionTodoCompletedCount(int count, int total) {
    return '작업 $count/$total개 완료됨';
  }

  @override
  String sessionTodoTasksCount(int count) {
    return '작업 ($count)';
  }

  @override
  String questionStepOfReview(int current, int total) {
    return '$total단계 중 $current단계 - 검토';
  }

  @override
  String questionStepOfQuestion(int current, int total) {
    return '$total단계 중 $current단계 - 질문';
  }

  @override
  String get questionCustomAnswer => '사용자 지정 답변';

  @override
  String get questionSubmitAnswers => '답변 제출';

  @override
  String get questionReviewAnswers => '답변 검토';

  @override
  String permissionRequestTitle(String permission) {
    return '권한 요청: $permission';
  }

  @override
  String get sessionTitleCannotBeEmpty => '제목은 비워둘 수 없습니다';

  @override
  String get filesFailedToLoad => '파일을 불러오지 못했습니다';

  @override
  String get filesFailedToSearch => '파일 검색에 실패했습니다';

  @override
  String get filesNoOpenFilesHint => '열린 파일이 없습니다. 검색하려면 입력하세요.';

  @override
  String get filesNoContentMatches => '일치하는 내용이 없습니다';

  @override
  String filesOpenFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '열린 파일 $count개',
      one: '열린 파일 1개',
    );
    return '$_temp0';
  }

  @override
  String filesLinesSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count줄 선택됨',
      one: '1줄 선택됨',
    );
    return '$_temp0';
  }

  @override
  String get filesDraftTooLargeToSave => '초안이 너무 커서 편집기에서 저장할 수 없습니다.';

  @override
  String get filesSaveChangesBeforeClose => '이 파일을 닫기 전에 변경 사항을 저장하세요.';

  @override
  String get filesSaveChangesBeforePathChange => '이 경로를 변경하기 전에 변경 사항을 저장하세요.';

  @override
  String get filesWaitForSaveBeforePathChange =>
      '이 경로를 변경하기 전에 파일 저장이 끝날 때까지 기다리세요.';

  @override
  String get filesWaitForFileOperation => '파일 작업이 끝날 때까지 기다리세요.';

  @override
  String get filesLargeFileReadOnly => '편집 응답성을 유지하기 위해 큰 파일은 읽기 전용으로 열립니다.';

  @override
  String get filesCheckingWriteSupport => '파일 쓰기 지원 확인 중...';

  @override
  String get filesActiveProjectRequired => '파일 작업에는 활성 프로젝트 디렉터리가 필요합니다.';

  @override
  String get filesReloadSkippedUnsavedChanges =>
      '저장하지 않은 변경 사항이 있어 다시 로드를 건너뜁니다.';

  @override
  String get filesFailedToLoadContent => '파일 내용을 불러오지 못했습니다';

  @override
  String get filesFileSaved => '파일이 저장되었습니다.';

  @override
  String get filesParentNotDirectory => '상위 항목이 디렉터리가 아닙니다.';

  @override
  String get filesMalformedResponse => '파일 작업에서 잘못된 응답이 반환되었습니다.';

  @override
  String get filesShellCommandDidNotComplete => '파일 작업 셸 명령이 완료되지 않았습니다.';

  @override
  String get filesShellCommandNoResult => '파일 작업 셸 명령이 결과를 반환하지 않았습니다.';

  @override
  String get filesShellCommandTruncated => '파일 작업 셸 명령이 서버에 의해 잘렸습니다.';

  @override
  String get filesShellCommandSyntaxError => '파일 작업 셸 명령이 구문 오류로 실패했습니다.';

  @override
  String get filesShellUtilityNotFound => '필요한 셸 유틸리티를 찾을 수 없습니다.';

  @override
  String get filesShellCommandFailed => '결과를 반환하기 전에 파일 작업 셸 명령이 실패했습니다.';

  @override
  String get attachmentSaveTitle => '첨부 파일 저장';

  @override
  String get attachmentBrowserSandboxLocalFile =>
      '브라우저 샌드박스로 인해 file:// 첨부 파일을 직접 열 수 없습니다.';

  @override
  String get attachmentLocalPathBrowserBlocked =>
      '이 첨부 파일은 브라우저에서 열 수 없는 로컬 경로를 가리킵니다.';

  @override
  String terminalConnectedTo(String directory, String serverName) {
    return '$directory의 $serverName에 연결됨';
  }

  @override
  String get terminalTransportUnavailable => '터미널 전송을 사용할 수 없습니다.';

  @override
  String get chatSlashCommandNew => '새 채팅 세션 만들기';

  @override
  String get chatSlashCommandModels => '모델 선택기 열기';

  @override
  String get chatSlashCommandSessions => '대화 목록 열기';

  @override
  String get chatSlashCommandAgent => '에이전트 선택기 열기';

  @override
  String get chatSlashCommandOpen => '파일 열기 빠른 작업';

  @override
  String get chatSlashCommandHelp => '명령 도움말 표시';

  @override
  String get chatSlashCommandCompact => '현재 세션 컨텍스트 압축';

  @override
  String get chatSlashCommandThinking => '생각 풍선 표시 전환';

  @override
  String get chatSlashCommandUndo => '마지막으로 표시된 사용자 턴 실행 취소';

  @override
  String get chatSlashCommandRedo => '실행 취소한 마지막 턴 다시 실행';

  @override
  String chatSessionSubConversationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '하위 대화 $count개',
      one: '하위 대화 1개',
    );
    return '$_temp0';
  }

  @override
  String chatMessageWeeksAgo(int count) {
    return '$count주 전';
  }

  @override
  String chatMessageShortDate(int day, int month) {
    return '$month/$day';
  }

  @override
  String get chatProviderErrorLoadSessionStatus => '세션 상태를 불러오지 못했습니다';

  @override
  String get chatProviderErrorLoadSessionDetails => '일부 세션 세부 정보를 불러오지 못했습니다';

  @override
  String chatProviderErrorLoadSessionList(String error) {
    return '세션 목록을 불러오지 못했습니다: $error';
  }

  @override
  String get chatProviderErrorCreateSession => '세션을 만들지 못했습니다';

  @override
  String get chatProviderErrorSelectProviderModelBeforeSend =>
      '메시지를 보내기 전에 연결된 공급자 또는 무료 OpenCode 모델을 선택하세요';

  @override
  String get chatProviderErrorStartMessageSend => '메시지 전송을 시작하지 못했습니다';

  @override
  String get chatProviderErrorStopUnavailable => '현재 세션에서는 중지를 사용할 수 없습니다';

  @override
  String get chatProviderErrorWaitForResponseFinish =>
      '컨텍스트를 압축하기 전에 현재 응답이 끝날 때까지 기다리세요';

  @override
  String get chatProviderErrorCompactUnavailable =>
      '현재 세션에서는 컨텍스트 압축을 사용할 수 없습니다';

  @override
  String get chatProviderErrorSelectModelBeforeCompact =>
      '컨텍스트를 압축하기 전에 모델을 선택하세요';

  @override
  String get chatProviderErrorCompactSessionContext => '세션 컨텍스트 압축에 실패했습니다';

  @override
  String get chatProviderErrorNetwork => '네트워크 연결에 실패했습니다. 네트워크 설정을 확인해 주세요';

  @override
  String get chatProviderErrorServer => '서버 오류가 발생했습니다. 나중에 다시 시도해 주세요';

  @override
  String get chatProviderErrorNotFound => '리소스를 찾을 수 없습니다';

  @override
  String get chatProviderErrorInvalidInput => '잘못된 입력 매개변수입니다';

  @override
  String get chatProviderErrorUnknown => '알 수 없는 오류가 발생했습니다. 나중에 다시 시도해 주세요';

  @override
  String get chatProviderErrorSessionFallback => '세션 오류';

  @override
  String get projectProviderErrorNoProjectContext =>
      '서버에서 프로젝트 컨텍스트를 사용할 수 없습니다';

  @override
  String projectProviderErrorInitializeFailed(String error) {
    return '프로젝트 컨텍스트를 초기화하지 못했습니다: $error';
  }

  @override
  String get projectProviderErrorSwitchProjectNotFound =>
      '프로젝트를 전환하지 못했습니다: 프로젝트를 찾을 수 없습니다';

  @override
  String get projectProviderErrorSwitchDirectoryEmpty =>
      '프로젝트를 전환하지 못했습니다: 디렉터리가 비어 있습니다';

  @override
  String get projectProviderErrorAtLeastOneContext =>
      '최소한 하나의 컨텍스트는 열려 있어야 합니다';

  @override
  String get projectProviderErrorReopenProjectNotFound =>
      '프로젝트를 다시 열지 못했습니다: 프로젝트를 찾을 수 없습니다';

  @override
  String get projectProviderErrorOnlyClosedArchivable => '닫힌 프로젝트만 보관할 수 있습니다';

  @override
  String get projectProviderErrorArchiveProjectNotFound =>
      '프로젝트를 보관하지 못했습니다: 프로젝트를 찾을 수 없습니다';

  @override
  String get projectProviderErrorArchiveProjectPathInvalid =>
      '프로젝트를 보관하지 못했습니다: 프로젝트 경로가 올바르지 않습니다';

  @override
  String projectProviderErrorLoadWorkspaces(String error) {
    return '작업 공간 목록을 불러오지 못했습니다: $error';
  }

  @override
  String get projectProviderErrorWorkspaceNameEmpty => '작업 공간 이름은 비어 있을 수 없습니다';

  @override
  String projectProviderErrorCreateWorkspace(String error) {
    return '작업 공간을 만들지 못했습니다: $error';
  }

  @override
  String projectProviderErrorResetWorkspace(String error) {
    return '작업 공간을 초기화하지 못했습니다: $error';
  }

  @override
  String projectProviderErrorDeleteWorkspace(String error) {
    return '작업 공간을 삭제하지 못했습니다: $error';
  }

  @override
  String get projectProviderErrorDirectoryEmpty => '디렉터리는 비어 있을 수 없습니다';

  @override
  String projectProviderErrorListDirectories(String error) {
    return '디렉터리 목록을 불러오지 못했습니다: $error';
  }

  @override
  String projectProviderErrorValidateDirectory(String error) {
    return '디렉터리 검증에 실패했습니다: $error';
  }

  @override
  String get projectProviderErrorPathEmpty => '경로는 비어 있을 수 없습니다';

  @override
  String projectProviderErrorListFiles(String error) {
    return '파일 목록을 불러오지 못했습니다: $error';
  }

  @override
  String projectProviderErrorSearchFiles(String error) {
    return '파일 검색에 실패했습니다: $error';
  }

  @override
  String projectProviderErrorContentSearchUnavailable(String error) {
    return '콘텐츠 검색을 사용할 수 없습니다: $error';
  }

  @override
  String projectProviderErrorSearchSymbols(String error) {
    return '기호 검색에 실패했습니다: $error';
  }

  @override
  String projectProviderErrorReadFile(String error) {
    return '파일을 읽지 못했습니다: $error';
  }

  @override
  String projectProviderErrorLoadProjectList(String error) {
    return '프로젝트 목록을 불러오지 못했습니다: $error';
  }

  @override
  String get workspaceProjectRemovedFromHistory => '프로젝트가 기록에서 제거되었습니다';

  @override
  String workspaceProjectContextOpened(String directory) {
    return '프로젝트 컨텍스트가 열렸습니다: $directory';
  }

  @override
  String workspaceFailedToOpenProjectContext(String directory) {
    return '프로젝트 컨텍스트를 열지 못했습니다: $directory';
  }

  @override
  String get chatAbortNotice => '어떤 점을 다르게 하시겠어요?';

  @override
  String sessionTitleToday(String date, String time) {
    return '오늘 $time ($date)';
  }

  @override
  String sessionTitleYesterday(String date, String time) {
    return '어제 $time ($date)';
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
  String get sessionWeekdayMon => '월';

  @override
  String get sessionWeekdayTue => '화';

  @override
  String get sessionWeekdayWed => '수';

  @override
  String get sessionWeekdayThu => '목';

  @override
  String get sessionWeekdayFri => '금';

  @override
  String get sessionWeekdaySat => '토';

  @override
  String get sessionWeekdaySun => '일';

  @override
  String get forwardTimeNow => '지금';

  @override
  String forwardTimeMinutes(int count) {
    return '$count분';
  }

  @override
  String forwardTimeHours(int count) {
    return '$count시간';
  }

  @override
  String forwardTimeDays(int count) {
    return '$count일';
  }

  @override
  String forwardTimeWeeks(int count) {
    return '$count주';
  }

  @override
  String get settingsBehaviorConfigFieldDefaultModel => '기본 모델';

  @override
  String get settingsBehaviorConfigFieldDefaultAgent => '기본 에이전트';

  @override
  String get settingsBehaviorConfigFieldSmallModel => '소형 모델';

  @override
  String get settingsBehaviorConfigFieldAutoUpdateMode => '자동 업데이트 모드';

  @override
  String get settingsBehaviorConfigFieldSnapshotSetting => '스냅샷 설정';

  @override
  String get settingsBehaviorConfigFieldConversationUsername => '대화 사용자 이름';

  @override
  String get settingsBehaviorConfigFieldSharingDefault => '공유 기본값';

  @override
  String get speechMicNoInputDevice => '사용 가능한 마이크 입력 장치가 없습니다.';

  @override
  String get speechMicDeviceBusy => '기본 마이크가 현재 다른 앱에서 사용 중입니다.';

  @override
  String get speechMicUnsupportedFormat => '기본 마이크 형식이 지원되지 않습니다.';

  @override
  String get speechMicSpeechPrivacy =>
      'Windows 음성 서비스가 비활성화되어 있을 수 있습니다(음성 개인 정보 보호, 온라인 음성 인식 또는 언어 팩).';

  @override
  String get speechMicBackendUnavailable =>
      '이 빌드에서는 Windows 마이크 백엔드를 사용할 수 없습니다.';

  @override
  String speechEngineFallbackNotice(String fallback, String reason) {
    return '선택한 STT 엔진을 사용할 수 없습니다($reason). 대신 $fallback을 사용합니다.';
  }

  @override
  String get oauthFlowSecureStorageUnavailable =>
      'OAuth에 사용할 안전한 자격 증명 저장소를 사용할 수 없습니다.';

  @override
  String get oauthFlowUnexpectedError => 'OAuth 흐름이 예기치 않게 실패했습니다. 다시 시도해 주세요.';

  @override
  String get oauthFlowNoEndpointsDiscovered =>
      'OAuth 엔드포인트를 찾을 수 없습니다. Cloudflare Dashboard → Access → Applications → [이 앱]에서 관리 OAuth를 사용하도록 설정하세요.';

  @override
  String get oauthFlowTokenResponseMissingAccessToken =>
      'OAuth 토큰 응답에 액세스 토큰이 포함되지 않았습니다.';

  @override
  String get oauthFlowProfileChanged => 'OAuth가 완료되기 전에 서버 프로필이 변경되었습니다.';

  @override
  String get oauthFlowMetadataMissingEndpoints =>
      'OAuth 메타데이터에 인증/토큰 엔드포인트가 없습니다.';

  @override
  String get oauthFlowCallbackNotCompleted => '인증 콜백이 완료되지 않았습니다';

  @override
  String get oauthFlowProviderDeclined =>
      '인증 서버가 OAuth 요청을 거부했습니다. 다시 시도해 주세요.';

  @override
  String get oauthFlowCallbackValidationFailed =>
      'OAuth 콜백 검증에 실패했습니다. 다시 시도해 주세요.';

  @override
  String get oauthFlowCallbackServerStartFailed =>
      '로컬 OAuth 콜백 서버를 시작하지 못했습니다.';

  @override
  String get oauthFlowSignInCanceled => 'OAuth 로그인이 취소되었습니다.';

  @override
  String get oauthFlowBrowserOpenFailed => 'OAuth 로그인을 위해 시스템 브라우저를 열 수 없습니다.';

  @override
  String get oauthFlowCallbackTimeout =>
      '5분 이내에 인증 콜백이 앱에 도달하지 못했습니다. 동의 후 브라우저가 로컬 콜백 주소로 리디렉션될 것으로 예상했습니다. 대신 브라우저에 연결 오류가 표시된 경우 이 기기 또는 네트워크에서 루프백 리디렉션을 차단하고 있는 것입니다.';

  @override
  String oauthFlowTokenExchangeTransientFailure(int maxAttempts) {
    return '일시적인 네트워크 문제로 $maxAttempts회 시도 후 토큰 교환에 실패했습니다. 다시 시도해 주세요.';
  }

  @override
  String oauthFlowTokenExchangeHttpFailure(int statusCode) {
    return '토큰 교환에 실패했습니다(HTTP $statusCode). 다시 시도해 주세요.';
  }

  @override
  String get oauthFlowTokenExchangeUnexpectedFailure =>
      '토큰 교환이 예기치 않게 실패했습니다. 다시 시도해 주세요.';

  @override
  String get oauthFlowTokenExchangeIncomplete =>
      '인증 코드가 전송된 후 토큰 교환이 완료되지 않았습니다. OAuth 로그인을 다시 시작해 주세요.';

  @override
  String get speechReadAloudFailed => '텍스트 음성 변환에 실패했습니다.';

  @override
  String get speechReadAloudNoText => '소리 내어 읽을 텍스트가 없습니다.';

  @override
  String get speechEdgeTextTooLong =>
      'Microsoft Edge Speech는 한 번에 최대 4096바이트까지 읽을 수 있습니다.';

  @override
  String get speechEdgeMalformedAudio =>
      'Microsoft Edge Speech가 잘못된 형식의 오디오 데이터를 반환했습니다.';

  @override
  String get speechEdgeUnsupportedAudio =>
      'Microsoft Edge Speech가 지원되지 않는 오디오 데이터를 반환했습니다.';

  @override
  String get speechEdgeUnsupportedFrame =>
      'Microsoft Edge Speech가 지원되지 않는 websocket 프레임을 반환했습니다.';

  @override
  String get speechEdgeSynthesisInterrupted =>
      'Microsoft Edge Speech가 합성이 완료되기 전에 종료되었습니다.';

  @override
  String get speechEdgeEmptyAudio => 'Microsoft Edge Speech가 빈 오디오 응답을 반환했습니다.';

  @override
  String get speechEdgeTimedOut => 'Microsoft Edge Speech 요청 시간이 초과되었습니다.';

  @override
  String get speechEdgeUnreachable => 'Microsoft Edge Speech에 연결할 수 없습니다.';

  @override
  String get speechApiKeyMissing => '이 TTS 공급자를 사용하려면 설정 > 음성에서 API 키를 추가하세요.';

  @override
  String get speechProviderEmptyAudio => 'TTS 공급자가 빈 오디오 응답을 반환했습니다.';

  @override
  String get speechProviderRequestRejected => 'TTS 공급자가 음성 요청을 거부했습니다.';

  @override
  String get speechApiKeyRejected => 'TTS API 키가 공급자에 의해 거부되었습니다.';

  @override
  String get speechProviderQuotaRateLimit => 'TTS 공급자가 할당량 또는 속도 제한에 도달했습니다.';

  @override
  String get speechReadAloudNoVoice => '이 TTS 공급자의 음성을 선택하세요.';

  @override
  String get speechProviderTextTooLong => '이 TTS 모델에는 텍스트가 너무 깁니다.';

  @override
  String get speechProviderInvalidAudio => 'TTS 공급자가 인식할 수 없는 오디오를 반환했습니다.';

  @override
  String get speechNimBaseUrlRequired =>
      '설정 > 텍스트 음성 변환 (TTS)에 NVIDIA NIM 배포 기본 URL을 입력하세요.';

  @override
  String get speechProviderTemporarilyUnavailable =>
      'TTS 공급자를 일시적으로 사용할 수 없습니다.';

  @override
  String get speechProviderUnreachable => 'TTS 공급자에 연결할 수 없습니다.';

  @override
  String appProviderErrorFailedToStartProcess(String tool) {
    return '$tool 프로세스를 시작하지 못했습니다.';
  }

  @override
  String appProviderErrorToolNotAvailable(String runtime, String tool) {
    return '$tool을(를) 사용할 수 없습니다. 먼저 $runtime을(를) 설치하세요.';
  }

  @override
  String appProviderErrorToolInstallFailed(int exitCode, String tool) {
    return '$tool 설치가 종료 코드 $exitCode로 실패했습니다.';
  }

  @override
  String appProviderErrorBunBootstrapFailed(int exitCode) {
    return 'Bun 부트스트랩이 종료 코드 $exitCode로 실패했습니다.';
  }

  @override
  String get appProviderErrorInstalledButNotFoundInPath =>
      'OpenCode 설치가 완료되었지만 PATH에서 명령을 찾을 수 없습니다.';

  @override
  String get appProviderErrorInstalledButPathNotResolved =>
      'OpenCode 설치가 완료되었지만 명령 경로를 확인할 수 없습니다.';

  @override
  String appProviderErrorConfiguredCommandNotFound(String tool) {
    return '구성된 명령을 찾을 수 없고 $tool이(가) PATH에 없습니다.';
  }

  @override
  String get appProviderErrorConfiguredCommandPathMissing =>
      '구성된 명령 경로가 존재하지 않습니다.';

  @override
  String get appProviderErrorConfiguredCommandVersionCheckFailed =>
      '구성된 명령은 존재하지만 버전 확인에 실패했습니다.';

  @override
  String get appProviderErrorConfiguredCommandExecutionFailed =>
      '구성된 명령을 실행할 수 없습니다.';

  @override
  String get appProviderWslCheckWindowsOnly => 'WSL 확인은 Windows에만 적용됩니다.';

  @override
  String get appProviderDesktopBuildRequired =>
      '관리형 로컬 서버를 구성하려면 데스크톱 빌드를 사용하세요.';

  @override
  String get appProviderKnownInstallationDirectoryDetected =>
      '알려진 설치 디렉터리에서 감지되었습니다.';

  @override
  String appProviderKnownInstallationPathRefreshHint(String appName) {
    return '알려진 설치 디렉터리에서 감지되었습니다. PATH를 새로 고쳐야 할 수 있습니다. 최근 설치가 아직 감지되지 않으면 $appName을(를) 다시 여세요.';
  }

  @override
  String get appProviderErrorReleaseMetadataFetchFailed =>
      'GitHub에서 최신 릴리스 메타데이터를 가져오지 못했습니다.';

  @override
  String get appProviderErrorReleaseAssetListMissing =>
      '최신 릴리스 메타데이터에 자산 목록이 포함되지 않았습니다.';

  @override
  String get appProviderErrorNoCompatibleAsset =>
      '호환되는 OpenCode 바이너리 자산을 찾을 수 없습니다.';

  @override
  String get appProviderErrorDownloadAssetFailed =>
      '선택한 OpenCode 자산을 다운로드하지 못했습니다.';

  @override
  String get appProviderErrorChecksumVerificationFailed =>
      '다운로드한 자산의 체크섬 검증에 실패했습니다.';

  @override
  String get appProviderErrorExtractArchiveFailed =>
      'OpenCode 바이너리 아카이브 압축 해제에 실패했습니다.';

  @override
  String appProviderErrorExecutableNotFound(String tool) {
    return '압축 해제된 파일에서 $tool 실행 파일을 찾을 수 없습니다.';
  }

  @override
  String get chatNoResponseFromServer => '서버에서 응답이 없습니다. 다시 시도하세요.';

  @override
  String get chatNoResponseFromModel => '모델에서 응답이 없습니다. 다시 시도하세요.';

  @override
  String get speechJobCancelled => '음성 작업이 취소되었습니다.';

  @override
  String get speechEdgeCancelled => 'Microsoft Edge Speech가 취소되었습니다.';

  @override
  String get sessionAttentionKindActive => '활성';

  @override
  String get sessionAttentionKindReceiving => '수신 중';

  @override
  String get sessionAttentionKindDelayed => '지연됨';

  @override
  String get sessionAttentionKindCompleted => '완료';

  @override
  String get sessionAttentionKindPendingInteraction => '상호작용 대기 중';

  @override
  String get sessionAttentionKindError => '오류';

  @override
  String get sessionAttentionPauseCellularDataSaver => '데이터 절약 모드가 활성화되었습니다.';

  @override
  String get sessionAttentionPauseOauthReopenRequired => 'OAuth 로그인 필요';

  @override
  String get sessionAttentionPauseTailscaleReopenRequired => 'Tailscale 연결 필요';

  @override
  String get sessionAttentionPauseOffline => '오프라인';

  @override
  String get sessionAttentionPausePermissionRevoked => '권한이 취소되었습니다';

  @override
  String get sessionAttentionPauseServiceStopped => '서비스가 중지되었습니다';

  @override
  String get sessionAttentionPauseHostUnavailable => '호스트를 사용할 수 없음';

  @override
  String get errorRequestCancelled => '요청이 취소되었습니다';

  @override
  String errorUnknownNetworkError(String error) {
    return '알 수 없는 네트워크 오류: $error';
  }

  @override
  String get errorCertificateError => '인증서 오류';

  @override
  String get errorSessionBusy => '세션이 다른 요청을 처리하는 중입니다.';

  @override
  String get errorRunShellCommandFailed => '셸 명령 실행에 실패했습니다';

  @override
  String get errorRunSlashCommandFailed => '슬래시 명령 실행에 실패했습니다';

  @override
  String get settingsBehaviorOpenCodeDefaultsLoadError =>
      '활성 서버에서 OpenCode 기반 기본값을 불러올 수 없습니다.';

  @override
  String get sessionTabIconRemoveFailed => '로컬 세션 탭 아이콘 데이터를 제거하지 못했습니다';

  @override
  String get forwardUntitled => '제목 없음';

  @override
  String setupDebugLinuxLogsPath(String path) {
    return 'Linux 로그: $path';
  }

  @override
  String setupDebugRunOpenCodeCommand(String command) {
    return '다음 명령으로 OpenCode 실행: $command';
  }

  @override
  String setupDebugServerHealthEndpoint(String endpoint) {
    return '서버 상태 확인: $endpoint';
  }

  @override
  String setupDebugServerDocsEndpoint(String endpoint) {
    return '서버 문서: $endpoint';
  }

  @override
  String get logsEntryError => '오류';

  @override
  String get logsEntryStack => '스택';

  @override
  String get setupDebugSourceDiagnostics => '진단';

  @override
  String get setupDebugSourceUseExisting => '기존 서버 사용';

  @override
  String get setupDebugSourceLocalServer => '로컬 서버';

  @override
  String get setupDebugSourceOnboarding => '온보딩';

  @override
  String get setupDebugSourceManualConnection => '수동 연결';

  @override
  String setupDebugMessageDiagnosticsResult(
    String availability,
    String platform,
    String recommendation,
  ) {
    return '$platform에서 $availability. $recommendation';
  }

  @override
  String get setupDebugMessageDetectAttempt =>
      '현재 환경에서 기존 OpenCode 명령을 감지하려고 시도합니다.';

  @override
  String get setupDebugMessageInstallStarted =>
      'CodeWalk에서 OpenCode 설치를 시작했습니다.';

  @override
  String setupDebugMessageStartLocalServer(String url) {
    return '관리형 OpenCode 서버를 $url에서 시작합니다.';
  }

  @override
  String setupDebugMessageHealthyRunning(String url) {
    return '관리형 OpenCode 서버가 정상이며 $url에서 실행 중입니다.';
  }

  @override
  String get setupDebugMessageStoppingLocalServer => '관리형 OpenCode 서버를 중지합니다.';

  @override
  String get setupDebugMessageStoppedCleanly =>
      '관리형 OpenCode 서버가 정상적으로 중지되었습니다.';

  @override
  String get setupDebugMessageExitedAfterRequestedStop =>
      '중지 요청 후 관리형 OpenCode 서버가 종료되었습니다.';

  @override
  String get setupDebugMessageOnboardingConnectExisting =>
      '사용자가 기존 OpenCode 서버에 연결하기로 선택했습니다.';

  @override
  String get setupDebugMessageOnboardingGuidedPath =>
      '사용자가 안내형 OpenCode 설정 경로를 열었습니다.';

  @override
  String get setupDebugMessageOnboardingManagedLocal =>
      '사용자가 관리형 로컬 OpenCode 설정을 열었습니다.';

  @override
  String get setupDebugMessageOnboardingOpenedServerSettings =>
      '상태 확인 실패 후 사용자가 서버 설정을 열었습니다.';

  @override
  String get setupDebugMessageOnboardingAddAnotherServer =>
      '상태 확인 실패 후 사용자가 다른 서버를 추가하기로 선택했습니다.';

  @override
  String setupDebugMessageTestingServerUrl(String url) {
    return '온보딩에서 OpenCode 서버 URL $url을 테스트합니다.';
  }

  @override
  String get chatProviderErrorSessionNotFound => '세션을 찾을 수 없습니다';

  @override
  String get chatProviderErrorInvalidMessageFormat => '잘못된 메시지 형식입니다';

  @override
  String get chatProviderErrorNetworkShort => '네트워크 연결에 실패했습니다';

  @override
  String get chatProviderErrorUnknownShort => '알 수 없는 오류';

  @override
  String get terminalCreateFailed => '터미널 세션을 만들지 못했습니다';

  @override
  String get terminalEndpointUnavailable => '터미널 엔드포인트를 사용할 수 없습니다';

  @override
  String get terminalInvalidDirectory => '잘못된 터미널 디렉터리입니다';

  @override
  String get terminalWebsocketUnavailable => '터미널 WebSocket을 여기서는 사용할 수 없습니다.';

  @override
  String chatMessageToolChainCallsCompact(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
      one: '1개',
    );
    return '$_temp0';
  }

  @override
  String get errorConnectionTimeout => '연결 시간 초과';

  @override
  String get errorClientError => '클라이언트 오류';

  @override
  String get chatProviderErrorSendMessage => '메시지 전송에 실패했습니다';

  @override
  String get speechApiEngine => 'API';

  @override
  String get speechApiEngineSubtitle =>
      'OpenAI, Groq 또는 OpenAI 호환 사용자 지정 엔드포인트.';

  @override
  String get speechApiProvider => '음성 텍스트 변환 제공업체';

  @override
  String get speechCloudSttPrivacy => '클라우드 음성 텍스트 변환 개인정보 보호';

  @override
  String get speechCloudSttPrivacyDescription =>
      '녹음된 마이크 오디오는 구성된 제공업체로 전송됩니다. API 키는 이 기기의 보안 저장소에 유지됩니다.';

  @override
  String get speechApiKeyOptional => '사용자 지정 엔드포인트의 경우 선택사항입니다.';

  @override
  String speechApiBatchHint(String provider) {
    return '$provider는 배치 변환을 사용합니다. 마이크를 다시 탭하여 중지하고 변환하세요.';
  }

  @override
  String get speechApiWebUnavailable => 'API 음성 텍스트 변환은 웹 빌드에서 사용할 수 없습니다.';

  @override
  String get speechApiConfigInvalid =>
      '음성 API 엔드포인트와 모델을 확인하세요. 원격 엔드포인트는 HTTPS를 사용해야 합니다.';

  @override
  String get speechApiRequestInvalid => '음성 엔드포인트 또는 모델이 거부되었습니다.';

  @override
  String get speechApiRateLimited => '음성 제공업체가 할당량 또는 속도 제한을 보고했습니다.';

  @override
  String get speechApiUnavailable => '음성 제공업체를 일시적으로 사용할 수 없습니다.';

  @override
  String get speechApiNetwork => '음성 제공업체에 연결할 수 없습니다.';

  @override
  String get speechApiInvalidResponse => '음성 제공업체가 잘못된 응답을 반환했습니다.';

  @override
  String get speechApiEmptyAudio => '마이크 오디오가 캡처되지 않았습니다.';

  @override
  String get speechApiEmptyTranscript => '음성 제공업체가 변환 결과를 반환하지 않았습니다.';

  @override
  String get speechApiCustomProvider => 'OpenAI 호환 사용자 지정';

  @override
  String get speechApiMaxDuration => 'API 녹음은 2분 후 자동으로 중지됩니다.';

  @override
  String get speechApiLanguageHint => '활성 앱 언어가 변환 힌트로 전송됩니다.';

  @override
  String get speechSttApiKeyStorageUnavailable =>
      '보안 음성 API 키 저장소를 사용할 수 없습니다.';

  @override
  String get speechSttApiKeyMissing => '설정 > 음성에서 음성 API 키를 추가하세요.';

  @override
  String get speechSttApiKeyRejected => '음성 API 키가 거부되었습니다.';

  @override
  String get carMessagingReply => '답장';

  @override
  String get carMessagingMarkRead => '읽음으로 표시';

  @override
  String get carMessagingDeliveryFailedTitle => '답장을 보내지 못했습니다';

  @override
  String get carMessagingDeliveryFailedBody =>
      '음성 답장을 전달하지 못했습니다. 다시 시도하려면 CodeWalk를 여세요.';
}
