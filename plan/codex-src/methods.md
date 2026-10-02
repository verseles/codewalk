# Codex app-server JSON-RPC method inventory

Generated locally with `codex app-server generate-json-schema [--experimental]` from codex-cli **0.159.3** (2026-10-02).
`stable` = present without `--experimental`; `EXPERIMENTAL` = only present with `--experimental` (requires `initialize.params.capabilities.experimentalApi=true`).
Note: individual *fields* of stable methods can also be experimental-gated.

## Client -> server requests (167 total, 104 stable)

| method | params type | gate |
|---|---|---|
| `initialize` | InitializeParams | stable |
| `server/diagnostics` | ServerDiagnosticsParams | EXPERIMENTAL |
| `userVerification/status` | UserVerificationStatusParams | EXPERIMENTAL |
| `userVerification/enroll` | UserVerificationEnrollParams | EXPERIMENTAL |
| `userVerification/delete` | UserVerificationDeleteParams | EXPERIMENTAL |
| `userVerification/verify` | UserVerificationVerifyParams | EXPERIMENTAL |
| `userVerification/cancel` | UserVerificationCancelParams | EXPERIMENTAL |
| `thread/start` | ThreadStartParams | stable |
| `thread/resume` | ThreadResumeParams | stable |
| `thread/fork` | ThreadForkParams | stable |
| `thread/archive` | ThreadArchiveParams | stable |
| `thread/delete` | ThreadDeleteParams | stable |
| `thread/unsubscribe` | ThreadUnsubscribeParams | stable |
| `thread/increment_elicitation` | ThreadIncrementElicitationParams | EXPERIMENTAL |
| `thread/decrement_elicitation` | ThreadDecrementElicitationParams | EXPERIMENTAL |
| `thread/name/set` | ThreadSetNameParams | stable |
| `thread/goal/set` | ThreadGoalSetParams | stable |
| `thread/goal/get` | ThreadGoalGetParams | stable |
| `thread/goal/clear` | ThreadGoalClearParams | stable |
| `thread/queue/add` | ThreadQueueAddParams | EXPERIMENTAL |
| `thread/queue/list` | ThreadQueueListParams | EXPERIMENTAL |
| `thread/queue/update` | ThreadQueueUpdateParams | EXPERIMENTAL |
| `thread/queue/delete` | ThreadQueueDeleteParams | EXPERIMENTAL |
| `thread/queue/reorder` | ThreadQueueReorderParams | EXPERIMENTAL |
| `thread/queue/start` | ThreadQueueStartParams | EXPERIMENTAL |
| `thread/metadata/update` | ThreadMetadataUpdateParams | stable |
| `thread/attachment/add` | ThreadAttachmentAddParams | stable |
| `thread/attachment/list` | ThreadAttachmentListParams | stable |
| `thread/attachment/remove` | ThreadAttachmentRemoveParams | stable |
| `thread/section/move` | ThreadSectionMoveParams | stable |
| `thread/settings/update` | ThreadSettingsUpdateParams | EXPERIMENTAL |
| `thread/memoryMode/set` | ThreadMemoryModeSetParams | EXPERIMENTAL |
| `memory/status` | MemoryStatusParams | EXPERIMENTAL |
| `memory/reset` | (none) | EXPERIMENTAL |
| `rollout/compress` | (none) | EXPERIMENTAL |
| `thread/unarchive` | ThreadUnarchiveParams | stable |
| `thread/compact/start` | ThreadCompactStartParams | stable |
| `thread/shellCommand` | ThreadShellCommandParams | stable |
| `thread/approveGuardianDeniedAction` | ThreadApproveGuardianDeniedActionParams | stable |
| `thread/backgroundTerminals/clean` | ThreadBackgroundTerminalsCleanParams | EXPERIMENTAL |
| `thread/backgroundTerminals/list` | ThreadBackgroundTerminalsListParams | EXPERIMENTAL |
| `thread/backgroundTerminals/terminate` | ThreadBackgroundTerminalsTerminateParams | EXPERIMENTAL |
| `thread/revert` | ThreadRevertParams | stable |
| `thread/list` | ThreadListParams | stable |
| `project/list` | ProjectListParams | EXPERIMENTAL |
| `project/read` | ProjectReadParams | EXPERIMENTAL |
| `project/create` | ProjectCreateParams | EXPERIMENTAL |
| `project/import` | ProjectImportParams | EXPERIMENTAL |
| `project/update` | ProjectUpdateParams | EXPERIMENTAL |
| `project/move` | ProjectMoveParams | EXPERIMENTAL |
| `project/delete` | ProjectDeleteParams | EXPERIMENTAL |
| `threadSection/list` | ThreadSectionListParams | stable |
| `threadSection/create` | ThreadSectionCreateParams | stable |
| `threadSection/update` | ThreadSectionUpdateParams | stable |
| `threadSection/delete` | ThreadSectionDeleteParams | stable |
| `thread/search` | ThreadSearchParams | EXPERIMENTAL |
| `thread/searchOccurrences` | ThreadSearchOccurrencesParams | EXPERIMENTAL |
| `thread/loaded/list` | ThreadLoadedListParams | stable |
| `thread/read` | ThreadReadParams | stable |
| `thread/turns/list` | ThreadTurnsListParams | stable |
| `thread/items/list` | ThreadItemsListParams | stable |
| `thread/inject_items` | ThreadInjectItemsParams | stable |
| `skills/list` | SkillsListParams | stable |
| `skills/extraRoots/set` | SkillsExtraRootsSetParams | stable |
| `hooks/list` | HooksListParams | stable |
| `marketplace/add` | MarketplaceAddParams | stable |
| `marketplace/remove` | MarketplaceRemoveParams | stable |
| `marketplace/upgrade` | MarketplaceUpgradeParams | stable |
| `plugin/list` | PluginListParams | stable |
| `plugin/search` | PluginSearchParams | EXPERIMENTAL |
| `plugin/installed` | PluginInstalledParams | stable |
| `plugin/reconcile` | PluginReconcileParams | stable |
| `plugin/read` | PluginReadParams | stable |
| `plugin/skill/read` | PluginSkillReadParams | stable |
| `plugin/share/save` | PluginShareSaveParams | stable |
| `plugin/share/updateTargets` | PluginShareUpdateTargetsParams | stable |
| `plugin/share/list` | PluginShareListParams | stable |
| `plugin/share/checkout` | PluginShareCheckoutParams | stable |
| `plugin/share/delete` | PluginShareDeleteParams | stable |
| `app/read` | AppsReadParams | stable |
| `app/list` | AppsListParams | stable |
| `app/installed` | AppsInstalledParams | stable |
| `fs/readFile` | FsReadFileParams | stable |
| `fs/writeFile` | FsWriteFileParams | stable |
| `fs/createDirectory` | FsCreateDirectoryParams | stable |
| `fs/getMetadata` | FsGetMetadataParams | stable |
| `fs/readDirectory` | FsReadDirectoryParams | stable |
| `fs/remove` | FsRemoveParams | stable |
| `fs/copy` | FsCopyParams | stable |
| `fs/watch` | FsWatchParams | stable |
| `fs/unwatch` | FsUnwatchParams | stable |
| `skills/config/write` | SkillsConfigWriteParams | stable |
| `plugin/install` | PluginInstallParams | stable |
| `plugin/uninstall` | PluginUninstallParams | stable |
| `turn/start` | TurnStartParams | stable |
| `turn/settings/update` | TurnSettingsUpdateParams | EXPERIMENTAL |
| `turn/steer` | TurnSteerParams | stable |
| `turn/interrupt` | TurnInterruptParams | stable |
| `thread/realtime/start` | ThreadRealtimeStartParams | EXPERIMENTAL |
| `thread/realtime/appendAudio` | ThreadRealtimeAppendAudioParams | EXPERIMENTAL |
| `thread/realtime/appendText` | ThreadRealtimeAppendTextParams | EXPERIMENTAL |
| `thread/realtime/appendSpeech` | ThreadRealtimeAppendSpeechParams | EXPERIMENTAL |
| `thread/realtime/stop` | ThreadRealtimeStopParams | EXPERIMENTAL |
| `thread/timeline/list` | ThreadTimelineListParams | EXPERIMENTAL |
| `thread/realtime/listVoices` | ThreadRealtimeListVoicesParams | EXPERIMENTAL |
| `review/start` | ReviewStartParams | stable |
| `model/list` | ModelListParams | stable |
| `account/gatewayOAuth/read` | (none) | stable |
| `account/gatewayOAuth/login` | (none) | stable |
| `account/gatewayOAuth/cancel` | (none) | stable |
| `modelProvider/capabilities/read` | ModelProviderCapabilitiesReadParams | stable |
| `experimentalFeature/list` | ExperimentalFeatureListParams | stable |
| `permissionProfile/list` | PermissionProfileListParams | stable |
| `experimentalFeature/enablement/set` | ExperimentalFeatureEnablementSetParams | stable |
| `remoteControl/enable` | (none) | EXPERIMENTAL |
| `remoteControl/disable` | (none) | EXPERIMENTAL |
| `remoteControl/status/read` | (none) | EXPERIMENTAL |
| `remoteControl/pairing/start` | RemoteControlPairingStartParams | EXPERIMENTAL |
| `remoteControl/pairing/status` | RemoteControlPairingStatusParams | EXPERIMENTAL |
| `remoteControl/client/list` | RemoteControlClientsListParams | EXPERIMENTAL |
| `remoteControl/client/revoke` | RemoteControlClientsRevokeParams | EXPERIMENTAL |
| `collaborationMode/list` | CollaborationModeListParams | EXPERIMENTAL |
| `mock/experimentalMethod` | MockExperimentalMethodParams | EXPERIMENTAL |
| `environment/add` | EnvironmentAddParams | EXPERIMENTAL |
| `environment/info` | EnvironmentInfoParams | EXPERIMENTAL |
| `environment/status` | EnvironmentStatusParams | EXPERIMENTAL |
| `mcpServer/oauth/login` | McpServerOauthLoginParams | stable |
| `config/mcpServer/reload` | (none) | stable |
| `mcpServerStatus/list` | ListMcpServerStatusParams | stable |
| `mcpServer/resource/read` | McpResourceReadParams | stable |
| `mcpServer/event/stream/start` | McpServerEventStreamStartParams | EXPERIMENTAL |
| `mcpServer/event/stream/stop` | McpServerEventStreamStopParams | EXPERIMENTAL |
| `mcpServer/tool/call` | McpServerToolCallParams | stable |
| `windowsSandbox/setupStart` | WindowsSandboxSetupStartParams | stable |
| `windowsSandbox/readiness` | (none) | stable |
| `account/login/start` | LoginAccountParams | stable |
| `account/bedrock/discover` | BedrockDiscoverParams | EXPERIMENTAL |
| `account/bedrock/setup` | BedrockSetupParams | EXPERIMENTAL |
| `account/login/cancel` | CancelLoginAccountParams | stable |
| `account/logout` | (none) | stable |
| `account/rateLimits/read` | (none) | stable |
| `account/rateLimitResetCredit/consume` | ConsumeAccountRateLimitResetCreditParams | stable |
| `account/usage/read` | (none) | stable |
| `account/workspaceMessages/read` | (none) | stable |
| `account/sendAddCreditsNudgeEmail` | SendAddCreditsNudgeEmailParams | stable |
| `feedback/upload` | FeedbackUploadParams | stable |
| `command/exec` | CommandExecParams | stable |
| `command/exec/write` | CommandExecWriteParams | stable |
| `command/exec/terminate` | CommandExecTerminateParams | stable |
| `command/exec/resize` | CommandExecResizeParams | stable |
| `process/spawn` | ProcessSpawnParams | EXPERIMENTAL |
| `process/writeStdin` | ProcessWriteStdinParams | EXPERIMENTAL |
| `process/kill` | ProcessKillParams | EXPERIMENTAL |
| `process/resizePty` | ProcessResizePtyParams | EXPERIMENTAL |
| `config/read` | ConfigReadParams | stable |
| `externalAgentConfig/detect` | ExternalAgentConfigDetectParams | stable |
| `externalAgentConfig/import` | ExternalAgentConfigImportParams | stable |
| `externalAgentConfig/import/recordHistory` | ExternalAgentConfigImportHistoryRecordParams | stable |
| `externalAgentConfig/import/readHistories` | (none) | stable |
| `config/value/write` | ConfigValueWriteParams | stable |
| `config/batchWrite` | ConfigBatchWriteParams | stable |
| `configRequirements/read` | (none) | stable |
| `account/read` | GetAccountParams | stable |
| `fuzzyFileSearch` | FuzzyFileSearchParams | stable |
| `fuzzyFileSearch/sessionStart` | FuzzyFileSearchSessionStartParams | EXPERIMENTAL |
| `fuzzyFileSearch/sessionUpdate` | FuzzyFileSearchSessionUpdateParams | EXPERIMENTAL |
| `fuzzyFileSearch/sessionStop` | FuzzyFileSearchSessionStopParams | EXPERIMENTAL |

## Client -> server notifications (1 total, 1 stable)

| method | params type | gate |
|---|---|---|
| `initialized` | (none) | stable |

## Server -> client requests (client MUST answer) (11 total, 10 stable)

| method | params type | gate |
|---|---|---|
| `item/commandExecution/requestApproval` | CommandExecutionRequestApprovalParams | stable |
| `item/fileChange/requestApproval` | FileChangeRequestApprovalParams | stable |
| `item/tool/requestUserInput` | ToolRequestUserInputParams | stable |
| `mcpServer/elicitation/request` | McpServerElicitationRequestParams | stable |
| `item/permissions/requestApproval` | PermissionsRequestApprovalParams | stable |
| `item/tool/call` | DynamicToolCallParams | stable |
| `account/chatgptAuthTokens/refresh` | ChatgptAuthTokensRefreshParams | stable |
| `attestation/generate` | AttestationGenerateParams | stable |
| `currentTime/read` | CurrentTimeReadParams | EXPERIMENTAL |
| `applyPatchApproval` | ApplyPatchApprovalParams | stable |
| `execCommandApproval` | ExecCommandApprovalParams | stable |

## Server -> client notifications (83 total, 83 stable)

| method | params type | gate |
|---|---|---|
| `error` | ErrorNotification | stable |
| `thread/started` | ThreadStartedNotification | stable |
| `thread/status/changed` | ThreadStatusChangedNotification | stable |
| `thread/archived` | ThreadArchivedNotification | stable |
| `thread/deleted` | ThreadDeletedNotification | stable |
| `thread/unarchived` | ThreadUnarchivedNotification | stable |
| `thread/closed` | ThreadClosedNotification | stable |
| `thread/reverted` | ThreadRevertedNotification | stable |
| `skills/changed` | SkillsChangedNotification | stable |
| `thread/name/updated` | ThreadNameUpdatedNotification | stable |
| `thread/attachment/updated` | ThreadAttachmentUpdatedNotification | stable |
| `thread/goal/updated` | ThreadGoalUpdatedNotification | stable |
| `thread/goal/cleared` | ThreadGoalClearedNotification | stable |
| `thread/queue/changed` | ThreadQueueChangedNotification | stable |
| `project/changed` | ProjectChangedNotification | stable |
| `thread/project/updated` | ThreadProjectUpdatedNotification | stable |
| `thread/environment/connected` | EnvironmentConnectionNotification | stable |
| `thread/environment/disconnected` | EnvironmentConnectionNotification | stable |
| `thread/settings/updated` | ThreadSettingsUpdatedNotification | stable |
| `thread/tokenUsage/updated` | ThreadTokenUsageUpdatedNotification | stable |
| `turn/started` | TurnStartedNotification | stable |
| `hook/started` | HookStartedNotification | stable |
| `turn/completed` | TurnCompletedNotification | stable |
| `hook/completed` | HookCompletedNotification | stable |
| `turn/diff/updated` | TurnDiffUpdatedNotification | stable |
| `turn/plan/updated` | TurnPlanUpdatedNotification | stable |
| `item/started` | ItemStartedNotification | stable |
| `item/autoApprovalReview/started` | ItemGuardianApprovalReviewStartedNotification | stable |
| `item/autoApprovalReview/completed` | ItemGuardianApprovalReviewCompletedNotification | stable |
| `autoApprovalReview/strictReviewRequired` | StrictReviewRequiredNotification | stable |
| `item/completed` | ItemCompletedNotification | stable |
| `item/agentMessage/delta` | AgentMessageDeltaNotification | stable |
| `item/plan/delta` | PlanDeltaNotification | stable |
| `command/exec/outputDelta` | CommandExecOutputDeltaNotification | stable |
| `process/outputDelta` | ProcessOutputDeltaNotification | stable |
| `process/exited` | ProcessExitedNotification | stable |
| `item/commandExecution/outputDelta` | CommandExecutionOutputDeltaNotification | stable |
| `item/commandExecution/terminalInteraction` | TerminalInteractionNotification | stable |
| `item/fileChange/outputDelta` | FileChangeOutputDeltaNotification | stable |
| `item/fileChange/patchUpdated` | FileChangePatchUpdatedNotification | stable |
| `serverRequest/resolved` | ServerRequestResolvedNotification | stable |
| `item/mcpToolCall/progress` | McpToolCallProgressNotification | stable |
| `mcpServer/oauthLogin/completed` | McpServerOauthLoginCompletedNotification | stable |
| `mcpServer/startupStatus/updated` | McpServerStatusUpdatedNotification | stable |
| `mcpServer/event/stream/notification` | McpServerEventStreamNotification | stable |
| `account/updated` | AccountUpdatedNotification | stable |
| `account/gatewayOAuth/changed` | GatewayOAuthChangedNotification | stable |
| `account/rateLimits/updated` | AccountRateLimitsUpdatedNotification | stable |
| `app/list/updated` | AppListUpdatedNotification | stable |
| `remoteControl/status/changed` | RemoteControlStatusChangedNotification | stable |
| `externalAgentConfig/import/progress` | ExternalAgentConfigImportProgressNotification | stable |
| `externalAgentConfig/import/completed` | ExternalAgentConfigImportCompletedNotification | stable |
| `fs/changed` | FsChangedNotification | stable |
| `item/reasoning/summaryTextDelta` | ReasoningSummaryTextDeltaNotification | stable |
| `item/reasoning/summaryPartAdded` | ReasoningSummaryPartAddedNotification | stable |
| `item/reasoning/textDelta` | ReasoningTextDeltaNotification | stable |
| `thread/compacted` | ContextCompactedNotification | stable |
| `model/rerouted` | ModelReroutedNotification | stable |
| `model/verification` | ModelVerificationNotification | stable |
| `modelProvider/authRecoveryStarted` | AuthRecoveryNotification | stable |
| `modelProvider/authRecoveryCompleted` | AuthRecoveryNotification | stable |
| `turn/moderationMetadata` | TurnModerationMetadataNotification | stable |
| `model/safetyBuffering/updated` | ModelSafetyBufferingUpdatedNotification | stable |
| `warning` | WarningNotification | stable |
| `guardianWarning` | GuardianWarningNotification | stable |
| `deprecationNotice` | DeprecationNoticeNotification | stable |
| `configWarning` | ConfigWarningNotification | stable |
| `fuzzyFileSearch/sessionUpdated` | FuzzyFileSearchSessionUpdatedNotification | stable |
| `fuzzyFileSearch/sessionCompleted` | FuzzyFileSearchSessionCompletedNotification | stable |
| `thread/realtime/started` | ThreadRealtimeStartedNotification | stable |
| `thread/realtime/itemAdded` | ThreadRealtimeItemAddedNotification | stable |
| `thread/realtime/item/started` | ThreadRealtimeItemStartedNotification | stable |
| `thread/realtime/item/transcript/delta` | ThreadRealtimeItemTranscriptDeltaNotification | stable |
| `thread/realtime/item/completed` | ThreadRealtimeItemCompletedNotification | stable |
| `thread/realtime/transcript/delta` | ThreadRealtimeTranscriptDeltaNotification | stable |
| `thread/realtime/transcript/done` | ThreadRealtimeTranscriptDoneNotification | stable |
| `thread/realtime/outputAudio/delta` | ThreadRealtimeOutputAudioDeltaNotification | stable |
| `thread/realtime/sdp` | ThreadRealtimeSdpNotification | stable |
| `thread/realtime/error` | ThreadRealtimeErrorNotification | stable |
| `thread/realtime/closed` | ThreadRealtimeClosedNotification | stable |
| `windows/worldWritableWarning` | WindowsWorldWritableWarningNotification | stable |
| `windowsSandbox/setupCompleted` | WindowsSandboxSetupCompletedNotification | stable |
| `account/login/completed` | AccountLoginCompletedNotification | stable |


## Legacy v1 requests present only in the generated TypeScript union

`generate-ts` additionally emits three legacy v1 client requests that are absent from the JSON-schema `oneOf`:
`getConversationSummary`, `gitDiffToRemote`, `getAuthStatus`. Do not build on them (v1 surface; see `codex-rs/docs/protocol_v1.md`).
Legacy v1 server requests `applyPatchApproval` / `execCommandApproval` still appear in `ServerRequest`; v2 clients receive
`item/fileChange/requestApproval` / `item/commandExecution/requestApproval` instead.

## Notable gaps vs. public docs (verified against this schema)

- `thread/rollback` is **absent** (removed in rust-v0.156.0, PR #44915) although learn.chatgpt.com still documents it as "deprecated".
- `collaborationMode/list`, `thread/queue/*`, `thread/settings/update`, `turn/settings/update`, `thread/search`,
  `thread/backgroundTerminals/*`, `process/*`, `remoteControl/*`, `fuzzyFileSearch/session*` are EXPERIMENTAL-only.
