import type { BetaMessage } from '@anthropic-ai/sdk/resources/beta/messages/messages.mjs';
import type { BetaRawMessageStreamEvent } from '@anthropic-ai/sdk/resources/beta/messages/messages.mjs';
import type { BetaUsage } from '@anthropic-ai/sdk/resources/beta/messages/messages.mjs';
import type { CallToolResult } from '@modelcontextprotocol/sdk/types.js';
import type { ElicitResult } from '@modelcontextprotocol/sdk/types.js';
import type { JSONRPCMessage } from '@modelcontextprotocol/sdk/types.js';
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import type { MessageParam } from '@anthropic-ai/sdk/resources';
import type { Readable } from 'stream';
import type { ToolAnnotations } from '@modelcontextprotocol/sdk/types.js';
import type { UUID } from 'crypto';
import type { Writable } from 'stream';
import * as z from 'zod/v4';
import type { ZodRawShape } from 'zod/v3';
import type { ZodRawShape as ZodRawShape_2 } from 'zod/v4';
export declare class AbortError extends Error {
}
export declare type AccountInfo = {
    email?: string;
    organization?: string;
    subscriptionType?: string;
    tokenSource?: string;
    apiKeySource?: string;
    apiProvider?: 'firstParty' | 'bedrock' | 'vertex' | 'foundry' | 'anthropicAws' | 'anthropicGoogleCloud' | 'mantle' | 'gateway';
};
export declare type AgentDefinition = {
    description: string;
    tools?: string[];
    disallowedTools?: string[];
    prompt: string;
    model?: string;
    mcpServers?: AgentMcpServerSpec[];
    criticalSystemReminder_EXPERIMENTAL?: string;
    skills?: string[];
    initialPrompt?: string;
    maxTurns?: number;
    background?: boolean;
    omitClaudeMd?: boolean;
    memory?: 'user' | 'project' | 'local';
    effort?: ('low' | 'medium' | 'high' | 'xhigh' | 'max') | number;
    permissionMode?: PermissionMode;
    observer?: string;
    observerMessage?: string;
};
export declare type AgentInfo = {
    name: string;
    description: string;
    model?: string;
};
export declare type AgentMcpServerSpec = string | Record<string, McpServerConfigForProcessTransport>;
export declare type AnyZodRawShape = ZodRawShape | ZodRawShape_2;
export declare type ApiKeySource = 'ANTHROPIC_API_KEY' | 'apiKeyHelper' | '/login managed key' | 'none' | 'user' | 'project' | 'org' | 'temporary' | 'oauth';
export declare type AsyncHookJSONOutput = {
    async: true;
    asyncTimeout?: number;
};
export declare type BackgroundTaskSummary = {
    id: string;
    type: string;
    status: string;
    description: string;
    command?: string;
    agent_type?: string;
    server?: string;
    tool?: string;
    name?: string;
};
export declare type BaseHookInput = {
    session_id: string;
    transcript_path: string;
    cwd: string;
    prompt_id?: string;
    permission_mode?: string;
    agent_id?: string;
    agent_type?: string;
    effort?: {
        level: string;
    };
};
export declare type BaseOutputFormat = {
    type: OutputFormatType;
};
export declare type CanUseTool = (toolName: string, input: Record<string, unknown>, options: {
    signal: AbortSignal;
    suggestions?: PermissionUpdate[];
    blockedPath?: string;
    mcpServer?: {
        name: string;
        source: string;
    };
    decisionReason?: string;
    title?: string;
    displayName?: string;
    description?: string;
    defaultToNo?: boolean;
    suppressAlwaysAllowRule?: boolean;
    toolUseID: string;
    agentID?: string;
    requestId: string;
    matchedAskRule?: {
        source: string;
        toolName: string;
        ruleContent?: string;
    };
}) => Promise<PermissionResult | null>;
export declare type ClaimOptions = {
    cwd: string;
    env?: Record<string, string>;
    additionalDirectories?: string[];
    model?: string;
    permissionMode?: PermissionMode;
    maxThinkingTokens?: number | null;
    settings?: Parameters<Query['applyFlagSettings']>[0];
    appendSystemPrompt?: string;
    title?: string;
    agents?: Record<string, AgentDefinition>;
};
export declare type ConfigChangeHookInput = BaseHookInput & {
    hook_event_name: 'ConfigChange';
    source: 'user_settings' | 'project_settings' | 'local_settings' | 'policy_settings' | 'skills';
    file_path?: string;
};
export declare type ConfigScope = 'local' | 'user' | 'project';
declare type ControlErrorResponse = {
    subtype: 'error';
    request_id: string;
    error: string;
    pending_permission_requests?: SDKControlRequest[];
    pending_user_dialog_requests?: SDKControlRequest[];
};
declare type ControlResponse = {
    subtype: 'success';
    request_id: string;
    response?: Record<string, unknown>;
    pending_permission_requests?: SDKControlRequest[];
    pending_user_dialog_requests?: SDKControlRequest[];
};
declare namespace coreTypes {
    export {
        SandboxCredentialsConfig,
        SandboxFilesystemConfig,
        SandboxIgnoreViolations,
        SandboxNetworkConfig,
        SandboxSettings,
        NonNullableUsage,
        HOOK_EVENTS,
        EXIT_REASONS,
        SYSTEM_PROMPT_DYNAMIC_BOUNDARY,
        AccountInfo,
        AgentDefinition,
        AgentInfo,
        AgentMcpServerSpec,
        ApiKeySource,
        AsyncHookJSONOutput,
        BackgroundTaskSummary,
        BaseHookInput,
        BaseOutputFormat,
        ConfigChangeHookInput,
        ConfigScope,
        CwdChangedHookInput,
        CwdChangedHookSpecificOutput,
        DirectoryAddedHookInput,
        ElicitationHookInput,
        ElicitationHookSpecificOutput,
        ElicitationResultHookInput,
        ElicitationResultHookSpecificOutput,
        ExitReason,
        FastModeDisabledReason,
        FastModeState,
        FileChangedHookInput,
        FileChangedHookSpecificOutput,
        HookEvent,
        HookInput,
        HookJSONOutput,
        HookPermissionDecision,
        InstructionsLoadedHookInput,
        JsonSchemaOutputFormat,
        McpClaudeAIProxyServerConfig,
        McpHttpServerConfig,
        McpSSEServerConfig,
        McpSdkServerConfig,
        McpServerConfigForProcessTransport,
        McpServerProvenance,
        McpServerStatusConfig,
        McpServerStatus,
        McpServerToolPolicy,
        McpSetServersResult,
        McpStdioServerConfig,
        MessageDisplayHookInput,
        MessageDisplayHookSpecificOutput,
        ModelInfo,
        ModelUsage,
        NotificationHookInput,
        NotificationHookSpecificOutput,
        OutputFormat,
        OutputFormatType,
        PermissionBehavior,
        PermissionDecisionClassification,
        PermissionDeniedHookInput,
        PermissionDeniedHookSpecificOutput,
        PermissionMode,
        PermissionRequestHookInput,
        PermissionRequestHookSpecificOutput,
        PermissionResult,
        PermissionRuleValue,
        PermissionUpdateDestination,
        PermissionUpdate,
        PostCompactHookInput,
        PostModelSwitchHookInput,
        PostModelSwitchHookSpecificOutput,
        PostToolBatchHookInput,
        PostToolBatchHookSpecificOutput,
        PostToolBatchToolCall,
        PostToolUseFailureHookInput,
        PostToolUseFailureHookSpecificOutput,
        PostToolUseHookInput,
        PostToolUseHookSpecificOutput,
        PreCompactHookInput,
        PreModelSwitchHookInput,
        PreModelSwitchHookSpecificOutput,
        PreToolUseHookInput,
        PreToolUseHookSpecificOutput,
        RewindFilesResult,
        SDKAPIRetryMessage,
        SDKActiveGoalMessage,
        SDKAssistantMessageError,
        SDKAssistantMessage,
        SDKAuthStatusMessage,
        SDKBackgroundTasksChangedMessage,
        SDKCommandsChangedMessage,
        SDKCompactBoundaryMessage,
        SDKContextUsageCategory,
        SDKContextUsage,
        SDKControlRequestProgressMessage,
        SDKConversationResetMessage,
        SDKDeferredToolUse,
        SDKElicitationCompleteMessage,
        SDKFilesPersistedEvent,
        SDKHookProgressMessage,
        SDKHookResponseMessage,
        SDKHookStartedMessage,
        SDKInformationalMessage,
        SDKLocalCommandOutputMessage,
        SDKMcpResourceLink,
        SDKMemoryRecallMessage,
        SDKMessageOrigin,
        SDKMessage,
        SDKMirrorErrorMessage,
        SDKModelRefusalFallbackMessage,
        SDKModelRefusalNoFallbackMessage,
        SDKNotificationMessage,
        SDKPartialAssistantMessage,
        SDKPermissionDenial,
        SDKPermissionDeniedMessage,
        SDKPluginInstallMessage,
        SDKPromptSuggestionMessage,
        SDKRateLimitEvent,
        SDKRateLimitInfo,
        SDKResultError,
        SDKResultMessage,
        SDKResultSuccess,
        SDKSessionInfo,
        SDKSessionStateChangedMessage,
        SDKSettingsParseError,
        SDKStartupFailureReason,
        SDKStatusMessage,
        SDKStatus,
        SDKSystemMessage,
        SDKTaskNotificationMessage,
        SDKTaskProgressMessage,
        SDKTaskStartedMessage,
        SDKTaskUpdatedMessage,
        SDKThinkingTokensMessage,
        SDKToolProgressMessage,
        SDKToolUseSummaryMessage,
        SDKUsageReport,
        SDKUserMessageReplay,
        SDKUserMessage,
        SDKWorkerShuttingDownMessage,
        SdkBeta,
        SdkPluginConfig,
        SessionCronSummary,
        SessionEndHookInput,
        SessionStartHookInput,
        SessionStartHookSpecificOutput,
        SettingSource,
        SetupHookInput,
        SetupHookSpecificOutput,
        SlashCommand,
        StopFailureHookInput,
        StopHookInput,
        StopHookSpecificOutput,
        SubagentStartHookInput,
        SubagentStartHookSpecificOutput,
        SubagentStopHookInput,
        SubagentStopHookSpecificOutput,
        SyncHookJSONOutput,
        TaskCompletedHookInput,
        TaskCreatedHookInput,
        TeammateIdleHookInput,
        TerminalReason,
        ThinkingAdaptive,
        ThinkingConfig,
        ThinkingDisabled,
        ThinkingEnabled,
        UserPromptExpansionHookInput,
        UserPromptExpansionHookSpecificOutput,
        UserPromptSubmitHookInput,
        UserPromptSubmitHookSpecificOutput,
        WorktreeCreateHookInput,
        WorktreeCreateHookSpecificOutput,
        WorktreeRemoveHookInput
    }
}
export declare function createSdkMcpServer(_options: CreateSdkMcpServerOptions): McpSdkServerConfigWithInstance;
declare type CreateSdkMcpServerOptions = {
    name: string;
    version?: string;
    instructions?: string;
    tools?: Array<SdkMcpToolDefinition<any>>;
    alwaysLoad?: boolean;
    timeout?: number;
};
export declare type CwdChangedHookInput = BaseHookInput & {
    hook_event_name: 'CwdChanged';
    old_cwd: string;
    new_cwd: string;
};
export declare type CwdChangedHookSpecificOutput = {
    hookEventName: 'CwdChanged';
    watchPaths?: string[];
};
export declare function deleteSession(_sessionId: string, _options?: SessionMutationOptions): Promise<void>;
export declare type DirectoryAddedHookInput = BaseHookInput & {
    hook_event_name: 'DirectoryAdded';
    directory: string;
    source: 'slash_command' | 'register_repo_root';
};
export declare type EffortLevel = 'low' | 'medium' | 'high' | 'xhigh' | 'max';
export declare type ElicitationHookInput = BaseHookInput & {
    hook_event_name: 'Elicitation';
    mcp_server_name: string;
    message: string;
    mode?: 'form' | 'url';
    url?: string;
    elicitation_id?: string;
    requested_schema?: Record<string, unknown>;
};
export declare type ElicitationHookSpecificOutput = {
    hookEventName: 'Elicitation';
    action?: 'accept' | 'decline' | 'cancel';
    content?: Record<string, unknown>;
};
export declare type ElicitationRequest = {
    serverName: string;
    message: string;
    mode?: 'form' | 'url';
    url?: string;
    elicitationId?: string;
    requestedSchema?: Record<string, unknown>;
    title?: string;
    displayName?: string;
    description?: string;
};
export declare type ElicitationResult = ElicitResult;
export declare type ElicitationResultHookInput = BaseHookInput & {
    hook_event_name: 'ElicitationResult';
    mcp_server_name: string;
    elicitation_id?: string;
    mode?: 'form' | 'url';
    action: 'accept' | 'decline' | 'cancel';
    content?: Record<string, unknown>;
};
export declare type ElicitationResultHookSpecificOutput = {
    hookEventName: 'ElicitationResult';
    action?: 'accept' | 'decline' | 'cancel';
    content?: Record<string, unknown>;
};
export declare const EXIT_REASONS: readonly ['clear', 'resume', 'logout', 'prompt_input_exit', 'other'];
export declare type ExitReason = 'clear' | 'resume' | 'logout' | 'prompt_input_exit' | 'other';
export declare type FastModeDisabledReason = 'free' | 'preference' | 'extra_usage_disabled' | 'network_error' | 'unknown' | 'not_first_party' | 'disabled_by_env' | 'model_not_allowed' | 'sdk_opt_in_required' | 'pending';
export declare type FastModeState = 'off' | 'cooldown' | 'on';
export declare type FileChangedHookInput = BaseHookInput & {
    hook_event_name: 'FileChanged';
    file_path: string;
    event: 'change' | 'add' | 'unlink';
};
export declare type FileChangedHookSpecificOutput = {
    hookEventName: 'FileChanged';
    watchPaths?: string[];
};
export declare function filterEscalatingDefaultMode(_resolved: ResolvedSettings): Settings;
export declare function foldSessionSummary(prev: SessionSummaryEntry | undefined, key: SessionKey, entries: SessionStoreEntry[], options?: {
    mtime?: number;
}): SessionSummaryEntry;
export declare function forkSession(_sessionId: string, _options?: ForkSessionOptions): Promise<ForkSessionResult>;
export declare type ForkSessionOptions = SessionMutationOptions & {
    upToMessageId?: string;
    title?: string;
};
export declare type ForkSessionResult = {
    sessionId: string;
};
export declare function getSessionInfo(_sessionId: string, _options?: GetSessionInfoOptions): Promise<SDKSessionInfo | undefined>;
export declare type GetSessionInfoOptions = {
    dir?: string;
    sessionStore?: SessionStore;
};
export declare function getSessionMessages(_sessionId: string, _options?: GetSessionMessagesOptions): Promise<SessionMessage[]>;
export declare type GetSessionMessagesOptions = {
    dir?: string;
    limit?: number;
    offset?: number;
    includeSystemMessages?: boolean;
    sessionStore?: SessionStore;
};
export declare function getSubagentMessages(_sessionId: string, _agentId: string, _options?: GetSubagentMessagesOptions): Promise<SessionMessage[]>;
export declare type GetSubagentMessagesOptions = {
    dir?: string;
    limit?: number;
    offset?: number;
    sessionStore?: SessionStore;
};
export declare const HOOK_EVENTS: readonly ['PreToolUse', 'PostToolUse', 'PostToolUseFailure', 'PostToolBatch', 'Notification', 'UserPromptSubmit', 'UserPromptExpansion', 'SessionStart', 'SessionEnd', 'Stop', 'StopFailure', 'SubagentStart', 'SubagentStop', 'PreCompact', 'PostCompact', 'PreModelSwitch', 'PostModelSwitch', 'PermissionRequest', 'PermissionDenied', 'Setup', 'TeammateIdle', 'TaskCreated', 'TaskCompleted', 'Elicitation', 'ElicitationResult', 'ConfigChange', 'WorktreeCreate', 'WorktreeRemove', 'InstructionsLoaded', 'CwdChanged', 'FileChanged', 'DirectoryAdded', 'MessageDisplay'];
export declare type HookCallback = (input: HookInput, toolUseID: string | undefined, options: {
    signal: AbortSignal;
}) => Promise<HookJSONOutput>;
export declare interface HookCallbackMatcher {
    matcher?: string;
    hooks: HookCallback[];
    timeout?: number;
}
export declare type HookEvent = 'PreToolUse' | 'PostToolUse' | 'PostToolUseFailure' | 'PostToolBatch' | 'Notification' | 'UserPromptSubmit' | 'UserPromptExpansion' | 'SessionStart' | 'SessionEnd' | 'Stop' | 'StopFailure' | 'SubagentStart' | 'SubagentStop' | 'PreCompact' | 'PostCompact' | 'PreModelSwitch' | 'PostModelSwitch' | 'PermissionRequest' | 'PermissionDenied' | 'Setup' | 'TeammateIdle' | 'TaskCreated' | 'TaskCompleted' | 'Elicitation' | 'ElicitationResult' | 'ConfigChange' | 'WorktreeCreate' | 'WorktreeRemove' | 'InstructionsLoaded' | 'CwdChanged' | 'FileChanged' | 'DirectoryAdded' | 'MessageDisplay';
export declare type HookInput = PreToolUseHookInput | PostToolUseHookInput | PostToolUseFailureHookInput | PostToolBatchHookInput | PermissionDeniedHookInput | NotificationHookInput | UserPromptSubmitHookInput | UserPromptExpansionHookInput | SessionStartHookInput | SessionEndHookInput | StopHookInput | StopFailureHookInput | SubagentStartHookInput | SubagentStopHookInput | PreCompactHookInput | PostCompactHookInput | PreModelSwitchHookInput | PostModelSwitchHookInput | PermissionRequestHookInput | SetupHookInput | TeammateIdleHookInput | TaskCreatedHookInput | TaskCompletedHookInput | ElicitationHookInput | ElicitationResultHookInput | ConfigChangeHookInput | InstructionsLoadedHookInput | WorktreeCreateHookInput | WorktreeRemoveHookInput | CwdChangedHookInput | FileChangedHookInput | DirectoryAddedHookInput | MessageDisplayHookInput;
export declare type HookJSONOutput = AsyncHookJSONOutput | SyncHookJSONOutput;
export declare type HookPermissionDecision = 'allow' | 'deny' | 'ask' | 'defer';
export declare function importSessionToStore(_sessionId: string, _store: SessionStore, _options?: ImportSessionToStoreOptions): Promise<void>;
export declare type ImportSessionToStoreOptions = {
    dir?: string;
    includeSubagents?: boolean;
    batchSize?: number;
};
export declare type InferShape<T extends AnyZodRawShape> = {
    [K in keyof T]: T[K] extends {
        _output: infer O;
    } ? O : never;
} & {};
export declare class InMemorySessionStore implements SessionStore {
    private store;
    private mtimes;
    private summaries;
    private lastMtime;
    private keyToString;
    append(key: SessionKey, entries: SessionStoreEntry[]): Promise<void>;
    load(key: SessionKey): Promise<SessionStoreEntry[] | null>;
    listSessions(projectKey: string): Promise<Array<{
        sessionId: string;
        mtime: number;
    }>>;
    listSessionSummaries(projectKey: string): Promise<SessionSummaryEntry[]>;
    delete(key: SessionKey): Promise<void>;
    listSubkeys(key: {
        projectKey: string;
        sessionId: string;
    }): Promise<string[]>;
    getEntries(key: SessionKey): SessionStoreEntry[];
    get size(): number;
    clear(): void;
}
export declare type InstructionsLoadedHookInput = BaseHookInput & {
    hook_event_name: 'InstructionsLoaded';
    file_path: string;
    memory_type: 'User' | 'Project' | 'Local' | 'Managed';
    load_reason: 'session_start' | 'nested_traversal' | 'path_glob_match' | 'include' | 'compact';
    globs?: string[];
    trigger_file_path?: string;
    parent_file_path?: string;
};
export declare type JsonSchemaOutputFormat = {
    type: 'json_schema';
    schema: Record<string, unknown>;
};
export declare function listSessions(_options?: ListSessionsOptions): Promise<SDKSessionInfo[]>;
export declare type ListSessionsOptions = {
    dir?: string;
    limit?: number;
    offset?: number;
    includeWorktrees?: boolean;
    includeProgrammatic?: boolean;
    sessionStore?: SessionStore;
};
export declare function listSubagents(_sessionId: string, _options?: ListSubagentsOptions): Promise<string[]>;
export declare type ListSubagentsOptions = {
    dir?: string;
    sessionStore?: SessionStore;
};
export declare type McpClaudeAIProxyServerConfig = {
    type: 'claudeai-proxy';
    url: string;
    id: string;
    timeout?: number;
};
export declare type McpHttpServerConfig = {
    type: 'http';
    url: string;
    headers?: Record<string, string>;
    tools?: McpServerToolPolicy[];
    timeout?: number;
    alwaysLoad?: boolean;
};
export declare type McpSdkServerConfig = {
    type: 'sdk';
    name: string;
    timeout?: number;
};
export declare type McpSdkServerConfigWithInstance = McpSdkServerConfig & {
    instance: McpServer;
};
export declare type McpServerConfig = McpStdioServerConfig | McpSSEServerConfig | McpHttpServerConfig | McpSdkServerConfigWithInstance;
export declare type McpServerConfigForProcessTransport = McpStdioServerConfig | McpSSEServerConfig | McpHttpServerConfig | McpSdkServerConfig;
export declare type McpServerProvenance = {
    name: string;
    source: string;
};
export declare type McpServerStatus = {
    name: string;
    status: 'connected' | 'failed' | 'needs-auth' | 'pending' | 'disabled';
    serverInfo?: {
        name: string;
        version: string;
    };
    error?: string;
    config?: McpServerStatusConfig;
    scope?: string;
    source?: string;
    tools?: {
        name: string;
        description?: string;
        annotations?: {
            readOnly?: boolean;
            destructive?: boolean;
            openWorld?: boolean;
        };
        _meta?: Record<string, unknown>;
    }[];
};
export declare type McpServerStatusConfig = McpServerConfigForProcessTransport | McpClaudeAIProxyServerConfig;
export declare type McpServerToolPolicy = {
    name: string;
    permission_policy?: 'always_allow' | 'always_ask' | 'always_deny';
    org_max_permission?: 'allow' | 'ask' | 'blocked';
};
export declare type McpSetServersResult = {
    added: string[];
    removed: string[];
    errors: Record<string, string>;
};
export declare type McpSSEServerConfig = {
    type: 'sse';
    url: string;
    headers?: Record<string, string>;
    tools?: McpServerToolPolicy[];
    timeout?: number;
    alwaysLoad?: boolean;
};
export declare type McpStdioServerConfig = {
    type?: 'stdio';
    command: string;
    args?: string[];
    env?: Record<string, string>;
    timeout?: number;
    alwaysLoad?: boolean;
};
export declare type MessageDisplayHookInput = BaseHookInput & {
    hook_event_name: 'MessageDisplay';
    turn_id: string;
    message_id: string;
    index: number;
    final: boolean;
    delta: string;
};
export declare type MessageDisplayHookSpecificOutput = {
    hookEventName: 'MessageDisplay';
    displayContent?: string;
};
export declare type ModelInfo = {
    value: string;
    resolvedModel?: string;
    displayName: string;
    description: string;
    supportsEffort?: boolean;
    supportedEffortLevels?: ('low' | 'medium' | 'high' | 'xhigh' | 'max')[];
    supportsAdaptiveThinking?: boolean;
    supportsFastMode?: boolean;
    supportsAutoMode?: boolean;
};
export declare type ModelUsage = {
    inputTokens: number;
    outputTokens: number;
    thinkingTokens?: number;
    cacheReadInputTokens: number;
    cacheCreationInputTokens: number;
    webSearchRequests: number;
    costUSD: number;
    contextWindow: number;
    maxOutputTokens: number;
    canonicalModel?: string;
    provider?: string;
    costBasis?: 'list' | 'managed' | 'unknown';
};
export declare type NonNullableUsage = {
    [K in keyof BetaUsage]: K extends 'fallback_credit' ? BetaUsage[K] : NonNullable<BetaUsage[K]>;
};
export declare type NotificationHookInput = BaseHookInput & {
    hook_event_name: 'Notification';
    message: string;
    title?: string;
    notification_type: string;
};
export declare type NotificationHookSpecificOutput = {
    hookEventName: 'Notification';
    additionalContext?: string;
};
export declare type OnElicitation = (request: ElicitationRequest, options: {
    signal: AbortSignal;
    requestId: string;
}) => Promise<ElicitationResult | null>;
export declare type OnUserDialog = (request: UserDialogRequest, options: {
    signal: AbortSignal;
    requestId: string;
}) => Promise<UserDialogResult | null>;
export declare type Options = {
    abortController?: AbortController;
    additionalDirectories?: string[];
    projectConfigRoot?: string;
    agent?: string;
    agents?: Record<string, AgentDefinition>;
    allowedTools?: string[];
    canUseTool?: CanUseTool;
    continue?: boolean;
    cwd?: string;
    disallowedTools?: string[];
    toolAliases?: Record<string, string>;
    tools?: string[] | {
        type: 'preset';
        preset: 'claude_code';
    };
    env?: {
        [envVar: string]: string | undefined;
    };
    executable?: 'bun' | 'deno' | 'node';
    executableArgs?: string[];
    extraArgs?: Record<string, string | null>;
    fallbackModel?: string;
    enableFileCheckpointing?: boolean;
    toolConfig?: ToolConfig;
    forkSession?: boolean;
    betas?: SdkBeta[];
    hooks?: Partial<Record<HookEvent, HookCallbackMatcher[]>>;
    onElicitation?: OnElicitation;
    onUserDialog?: OnUserDialog;
    supportedDialogKinds?: string[];
    perTaskStopAffordance?: boolean;
    persistSession?: boolean;
    sessionStore?: SessionStore;
    sessionStoreFlush?: SessionStoreFlush;
    loadTimeoutMs?: number;
    includeHookEvents?: boolean;
    includePartialMessages?: boolean;
    forwardSubagentText?: boolean;
    verbatimPrompts?: boolean;
    thinking?: ThinkingConfig;
    effort?: EffortLevel;
    maxThinkingTokens?: number;
    maxTurns?: number;
    maxBudgetUsd?: number;
    taskBudget?: {
        total: number;
    };
    mcpServers?: Record<string, McpServerConfig>;
    model?: string;
    outputFormat?: OutputFormat;
    pathToClaudeCodeExecutable?: string;
    permissionMode?: PermissionMode;
    planModeInstructions?: string;
    allowDangerouslySkipPermissions?: boolean;
    permissionPromptToolName?: string;
    permissionPrompts?: 'host' | 'none';
    plugins?: SdkPluginConfig[];
    pluginDelivery?: 'argv' | 'initialize';
    promptSuggestions?: boolean;
    agentProgressSummaries?: boolean;
    resume?: string;
    sessionId?: string;
    resumeSessionAt?: string;
    resumeDropsTurn?: string;
    sandbox?: SandboxSettings;
    settings?: string | Settings;
    managedSettings?: Settings;
    settingSources?: SettingSource[];
    skills?: string[] | 'all';
    debug?: boolean;
    debugFile?: string;
    stderr?: (data: string) => void;
    strictMcpConfig?: boolean;
    systemPrompt?: string | string[] | {
        type: 'custom';
        prompt: string | string[];
        snapshot?: boolean;
    } | {
        type: 'preset';
        preset: 'claude_code';
        append?: string;
        excludeDynamicSections?: boolean;
        snapshot?: boolean;
    };
    title?: string;
    spawnClaudeCodeProcess?: (options: SpawnOptions) => SpawnedProcess;
};
export declare const ORG_POLICY_LIMIT_PREFIXES: readonly ['This service is disabled for your org'];
export declare type OutputFormat = JsonSchemaOutputFormat;
export declare type OutputFormatType = 'json_schema';
export declare type PermissionBehavior = 'allow' | 'deny' | 'ask';
export declare type PermissionDecisionClassification = 'user_temporary' | 'user_permanent' | 'user_reject';
export declare type PermissionDeniedHookInput = BaseHookInput & {
    hook_event_name: 'PermissionDenied';
    tool_name: string;
    tool_input: unknown;
    tool_use_id: string;
    reason: string;
    mcp_server?: McpServerProvenance;
};
export declare type PermissionDeniedHookSpecificOutput = {
    hookEventName: 'PermissionDenied';
    retry?: boolean;
};
export declare type PermissionMode = 'default' | 'acceptEdits' | 'bypassPermissions' | 'plan' | 'dontAsk' | 'auto';
export declare type PermissionRequestHookInput = BaseHookInput & {
    hook_event_name: 'PermissionRequest';
    tool_name: string;
    tool_input: unknown;
    permission_suggestions?: PermissionUpdate[];
    mcp_server?: McpServerProvenance;
};
export declare type PermissionRequestHookSpecificOutput = {
    hookEventName: 'PermissionRequest';
    decision: {
        behavior: 'allow';
        updatedInput?: Record<string, unknown>;
        updatedPermissions?: PermissionUpdate[];
    } | {
        behavior: 'deny';
        message?: string;
        interrupt?: boolean;
    };
};
export declare type PermissionResult = {
    behavior: 'allow';
    updatedInput?: Record<string, unknown>;
    updatedPermissions?: PermissionUpdate[];
    toolUseID?: string;
    decisionClassification?: PermissionDecisionClassification;
} | {
    behavior: 'deny';
    message: string;
    interrupt?: boolean;
    toolUseID?: string;
    decisionClassification?: PermissionDecisionClassification;
};
export declare type PermissionRuleValue = {
    toolName: string;
    ruleContent?: string;
};
export declare type PermissionUpdate = {
    type: 'addRules';
    rules: PermissionRuleValue[];
    behavior: PermissionBehavior;
    destination: PermissionUpdateDestination;
} | {
    type: 'replaceRules';
    rules: PermissionRuleValue[];
    behavior: PermissionBehavior;
    destination: PermissionUpdateDestination;
} | {
    type: 'removeRules';
    rules: PermissionRuleValue[];
    behavior: PermissionBehavior;
    destination: PermissionUpdateDestination;
} | {
    type: 'setMode';
    mode: PermissionMode;
    destination: PermissionUpdateDestination;
} | {
    type: 'addDirectories';
    directories: string[];
    destination: PermissionUpdateDestination;
} | {
    type: 'removeDirectories';
    directories: string[];
    destination: PermissionUpdateDestination;
};
export declare type PermissionUpdateDestination = 'userSettings' | 'projectSettings' | 'localSettings' | 'session' | 'cliArg';
export declare type PolicySettingsOrigin = 'helper' | 'remote' | 'plist' | 'hklm' | 'file' | 'parent' | 'hkcu';
export declare type PostCompactHookInput = BaseHookInput & {
    hook_event_name: 'PostCompact';
    trigger: 'manual' | 'auto';
    compact_summary: string;
};
export declare type PostModelSwitchHookInput = (BaseHookInput & {
    hook_event_name: 'PostModelSwitch';
}) & {
    from_model: string;
    to_model: string;
    requested_model: string | null;
    source: 'command' | 'picker' | 'sdk' | 'auto' | 'resume';
    context_tokens: number;
    prompt_cache_warm: boolean;
    cache_ttl: '5m' | '1h';
    estimated_cache_write_usd: number;
    pricing: 'configured' | 'catalog' | 'default';
};
export declare type PostModelSwitchHookSpecificOutput = {
    hookEventName: 'PostModelSwitch';
    additionalContext?: string;
};
export declare type PostToolBatchHookInput = BaseHookInput & {
    hook_event_name: 'PostToolBatch';
    tool_calls: PostToolBatchToolCall[];
};
export declare type PostToolBatchHookSpecificOutput = {
    hookEventName: 'PostToolBatch';
    additionalContext?: string;
};
export declare type PostToolBatchToolCall = {
    tool_name: string;
    tool_input: unknown;
    tool_use_id: string;
    tool_response?: unknown;
};
export declare type PostToolUseFailureHookInput = BaseHookInput & {
    hook_event_name: 'PostToolUseFailure';
    tool_name: string;
    tool_input: unknown;
    tool_use_id: string;
    error: string;
    is_interrupt?: boolean;
    duration_ms?: number;
    mcp_server?: McpServerProvenance;
};
export declare type PostToolUseFailureHookSpecificOutput = {
    hookEventName: 'PostToolUseFailure';
    additionalContext?: string;
};
export declare type PostToolUseHookInput = BaseHookInput & {
    hook_event_name: 'PostToolUse';
    tool_name: string;
    tool_input: unknown;
    tool_response: unknown;
    tool_use_id: string;
    duration_ms?: number;
    mcp_server?: McpServerProvenance;
};
export declare type PostToolUseHookSpecificOutput = {
    hookEventName: 'PostToolUse';
    additionalContext?: string;
    classifierContext?: string;
    updatedToolOutput?: unknown;
    updatedMCPToolOutput?: unknown;
};
export declare type PreCompactHookInput = BaseHookInput & {
    hook_event_name: 'PreCompact';
    trigger: 'manual' | 'auto';
    custom_instructions: string | null;
};
export declare type PreModelSwitchHookInput = (BaseHookInput & {
    hook_event_name: 'PreModelSwitch';
}) & {
    from_model: string;
    to_model: string;
    requested_model: string | null;
    source: 'command' | 'picker' | 'sdk';
    context_tokens: number;
    prompt_cache_warm: boolean;
    cache_ttl: '5m' | '1h';
    estimated_cache_write_usd: number;
    pricing: 'configured' | 'catalog' | 'default';
};
export declare type PreModelSwitchHookSpecificOutput = {
    hookEventName: 'PreModelSwitch';
    permissionDecision?: 'allow' | 'deny' | 'ask';
    permissionDecisionReason?: string;
};
export declare type PreToolUseHookInput = BaseHookInput & {
    hook_event_name: 'PreToolUse';
    tool_name: string;
    tool_input: unknown;
    tool_use_id: string;
    mcp_server?: McpServerProvenance;
};
export declare type PreToolUseHookSpecificOutput = {
    hookEventName: 'PreToolUse';
    permissionDecision?: HookPermissionDecision;
    permissionDecisionReason?: string;
    updatedInput?: Record<string, unknown>;
    additionalContext?: string;
};
export declare function prewarm(_params?: {
    options?: Options;
    initializeTimeoutMs?: number;
}): Promise<SpareProcess>;
export declare type ProvenanceEntry = {
    source: ResolvedSettingSource;
    path?: string;
    policyOrigin?: PolicySettingsOrigin;
};
export declare interface Query extends AsyncGenerator<SDKMessage, void> {
    interrupt(): Promise<SDKControlInterruptResponse | undefined>;
    setPermissionMode(mode: PermissionMode): Promise<void>;
    setMcpPermissionModeOverride(serverName: string, mode: 'default' | 'auto' | null): Promise<{
        warning?: string;
    }>;
    setModel(model?: string): Promise<void>;
    setMaxThinkingTokens(maxThinkingTokens: number | null, thinkingDisplay?: 'summarized' | 'omitted' | 'highlights' | null): Promise<void>;
    applyFlagSettings(settings: {
        [K in keyof Settings]?: K extends 'effortLevel' ? EffortLevel | null : Settings[K] | null;
    }): Promise<void>;
    updateSettings(source: 'localSettings' | 'userSettings', settings: Record<string, unknown>): Promise<void>;
    initializationResult(): Promise<SDKControlInitializeResponse>;
    reinitialize(): Promise<SDKControlInitializeResponse>;
    supportedCommands(): Promise<SlashCommand[]>;
    supportedModels(): Promise<ModelInfo[]>;
    supportedAgents(): Promise<AgentInfo[]>;
    mcpServerStatus(): Promise<McpServerStatus[]>;
    getContextUsage(opts?: {
        detail?: 'summary' | 'full';
    }): Promise<SDKControlGetContextUsageResponse>;
    usage_EXPERIMENTAL_MAY_CHANGE_DO_NOT_RELY_ON_THIS_API_YET(opts?: {
        skipBehaviors?: boolean;
    }): Promise<SDKControlGetUsageResponse>;
    readFile(path: string, options?: {
        maxBytes?: number;
        encoding?: 'utf-8' | 'base64';
    }): Promise<SDKControlReadFileResponse | null>;
    reloadPlugins(options?: {
        holdOnCacheImpact?: boolean;
    }): Promise<SDKControlReloadPluginsResponse>;
    reloadSkills(): Promise<SDKControlReloadSkillsResponse>;
    reloadOutputStyles(): Promise<SDKControlReloadOutputStylesResponse>;
    accountInfo(): Promise<AccountInfo>;
    rewindFiles(userMessageId: string, options?: {
        dryRun?: boolean;
    }): Promise<RewindFilesResult>;
    seedReadState(path: string, mtime: number): Promise<void>;
    reconnectMcpServer(serverName: string): Promise<void>;
    toggleMcpServer(serverName: string, enabled: boolean): Promise<void>;
    readMcpResource(serverName: string, uri: string): Promise<SDKControlMcpReadResourceResponse>;
    setMcpServers(servers: Record<string, McpServerConfig>): Promise<McpSetServersResult>;
    streamInput(stream: AsyncIterable<SDKUserMessage>): Promise<void>;
    stopTask(taskId: string): Promise<void>;
    backgroundTasks(toolUseId?: string): Promise<boolean>;
    close(): void;
}
export declare function query(_params: {
    prompt: string | AsyncIterable<SDKUserMessage>;
    options?: Options;
}): Query;
export declare function renameSession(_sessionId: string, _title: string, _options?: SessionMutationOptions): Promise<void>;
export declare type ResolvedSettings = {
    effective: Settings;
    provenance: Partial<Record<keyof Settings, ProvenanceEntry>>;
    sources: Array<{
        source: ResolvedSettingSource;
        settings: Settings;
        path?: string;
        policyOrigin?: PolicySettingsOrigin;
    }>;
};
export declare type ResolvedSettingSource = SettingSource | 'managed' | 'flag';
export declare function resolveSettings(_opts?: ResolveSettingsOptions): Promise<ResolvedSettings>;
export declare type ResolveSettingsOptions = {
    cwd?: string;
    settingSources?: SettingSource[];
    managedSettings?: Settings;
    serverManagedSettings?: Settings;
};
export declare type RewindFilesResult = {
    canRewind: boolean;
    error?: string;
    filesChanged?: string[];
    insertions?: number;
    deletions?: number;
    skippedLinks?: number;
};
export declare type SandboxCredentialsConfig = NonNullable<z.infer<ReturnType<typeof SandboxCredentialsConfigSchema>>>;
declare const SandboxCredentialsConfigSchema: () => z.ZodOptional<z.ZodObject<{
    files: z.ZodOptional<z.ZodArray<z.ZodPreprocess<z.ZodObject<{
        path: z.ZodString;
        mode: z.ZodEnum<{
            deny: "deny";
            mask: "mask";
        }>;
        extract: z.ZodOptional<z.ZodString>;
        onExtractNoMatch: z.ZodOptional<z.ZodEnum<{
            deny: "deny";
            error: "error";
            warn: "warn";
        }>>;
        decode: z.ZodOptional<z.ZodEnum<{
            jwt: "jwt";
        }>>;
        maskClaims: z.ZodOptional<z.ZodArray<z.ZodString>>;
        maskDuplicates: z.ZodOptional<z.ZodBoolean>;
        injectHosts: z.ZodOptional<z.ZodArray<z.ZodString>>;
    }, z.core.$strip>, unknown>>>;
    envVars: z.ZodOptional<z.ZodArray<z.ZodPreprocess<z.ZodObject<{
        name: z.ZodString;
        mode: z.ZodEnum<{
            deny: "deny";
            mask: "mask";
        }>;
        extract: z.ZodOptional<z.ZodString>;
        onExtractNoMatch: z.ZodOptional<z.ZodEnum<{
            deny: "deny";
            error: "error";
            warn: "warn";
        }>>;
        decode: z.ZodOptional<z.ZodEnum<{
            jwt: "jwt";
        }>>;
        maskClaims: z.ZodOptional<z.ZodArray<z.ZodString>>;
        injectHosts: z.ZodOptional<z.ZodArray<z.ZodString>>;
    }, z.core.$strip>, unknown>>>;
    allowPlaintextInject: z.ZodOptional<z.ZodBoolean>;
    awsPairs: z.ZodOptional<z.ZodArray<z.ZodObject<{
        accessKeyIdVar: z.ZodString;
        secretAccessKeyVar: z.ZodString;
        sessionTokenVar: z.ZodOptional<z.ZodString>;
    }, z.core.$strip>>>;
    sigv4: z.ZodOptional<z.ZodObject<{
        streaming: z.ZodOptional<z.ZodEnum<{
            deny: "deny";
            passthrough: "passthrough";
        }>>;
        presigned: z.ZodOptional<z.ZodEnum<{
            deny: "deny";
            passthrough: "passthrough";
        }>>;
        sigv4a: z.ZodOptional<z.ZodEnum<{
            deny: "deny";
            passthrough: "passthrough";
        }>>;
    }, z.core.$strip>>;
}, z.core.$strip>>;
export declare type SandboxFilesystemConfig = NonNullable<z.infer<ReturnType<typeof SandboxFilesystemConfigSchema>>>;
declare const SandboxFilesystemConfigSchema: () => z.ZodOptional<z.ZodObject<{
    allowWrite: z.ZodOptional<z.ZodArray<z.ZodString>>;
    denyWrite: z.ZodOptional<z.ZodArray<z.ZodString>>;
    denyRead: z.ZodOptional<z.ZodArray<z.ZodString>>;
    allowRead: z.ZodOptional<z.ZodArray<z.ZodString>>;
    allowManagedReadPathsOnly: z.ZodOptional<z.ZodBoolean>;
    disabled: z.ZodOptional<z.ZodBoolean>;
}, z.core.$strip>>;
export declare type SandboxIgnoreViolations = NonNullable<SandboxSettings['ignoreViolations']>;
export declare type SandboxNetworkConfig = NonNullable<z.infer<ReturnType<typeof SandboxNetworkConfigSchema>>>;
declare const SandboxNetworkConfigSchema: () => z.ZodOptional<z.ZodObject<{
    allowedDomains: z.ZodOptional<z.ZodArray<z.ZodString>>;
    deniedDomains: z.ZodOptional<z.ZodArray<z.ZodString>>;
    strictAllowlist: z.ZodOptional<z.ZodBoolean>;
    allowManagedDomainsOnly: z.ZodOptional<z.ZodBoolean>;
    allowUnixSockets: z.ZodOptional<z.ZodArray<z.ZodString>>;
    allowAllUnixSockets: z.ZodOptional<z.ZodBoolean>;
    allowLocalBinding: z.ZodOptional<z.ZodBoolean>;
    allowMachLookup: z.ZodOptional<z.ZodArray<z.ZodString>>;
    httpProxyPort: z.ZodOptional<z.ZodNumber>;
    socksProxyPort: z.ZodOptional<z.ZodNumber>;
    tlsTerminate: z.ZodOptional<z.ZodObject<{
        caCertPath: z.ZodOptional<z.ZodString>;
        caKeyPath: z.ZodOptional<z.ZodString>;
    }, z.core.$strip>>;
}, z.core.$strip>>;
export declare type SandboxSettings = z.infer<ReturnType<typeof SandboxSettingsSchema>>;
declare const SandboxSettingsSchema: () => z.ZodObject<{
    enabled: z.ZodOptional<z.ZodBoolean>;
    failIfUnavailable: z.ZodOptional<z.ZodBoolean>;
    autoAllowBashIfSandboxed: z.ZodOptional<z.ZodBoolean>;
    allowUnsandboxedCommands: z.ZodOptional<z.ZodBoolean>;
    network: z.ZodOptional<z.ZodObject<{
        allowedDomains: z.ZodOptional<z.ZodArray<z.ZodString>>;
        deniedDomains: z.ZodOptional<z.ZodArray<z.ZodString>>;
        strictAllowlist: z.ZodOptional<z.ZodBoolean>;
        allowManagedDomainsOnly: z.ZodOptional<z.ZodBoolean>;
        allowUnixSockets: z.ZodOptional<z.ZodArray<z.ZodString>>;
        allowAllUnixSockets: z.ZodOptional<z.ZodBoolean>;
        allowLocalBinding: z.ZodOptional<z.ZodBoolean>;
        allowMachLookup: z.ZodOptional<z.ZodArray<z.ZodString>>;
        httpProxyPort: z.ZodOptional<z.ZodNumber>;
        socksProxyPort: z.ZodOptional<z.ZodNumber>;
        tlsTerminate: z.ZodOptional<z.ZodObject<{
            caCertPath: z.ZodOptional<z.ZodString>;
            caKeyPath: z.ZodOptional<z.ZodString>;
        }, z.core.$strip>>;
    }, z.core.$strip>>;
    filesystem: z.ZodOptional<z.ZodObject<{
        allowWrite: z.ZodOptional<z.ZodArray<z.ZodString>>;
        denyWrite: z.ZodOptional<z.ZodArray<z.ZodString>>;
        denyRead: z.ZodOptional<z.ZodArray<z.ZodString>>;
        allowRead: z.ZodOptional<z.ZodArray<z.ZodString>>;
        allowManagedReadPathsOnly: z.ZodOptional<z.ZodBoolean>;
        disabled: z.ZodOptional<z.ZodBoolean>;
    }, z.core.$strip>>;
    credentials: z.ZodOptional<z.ZodObject<{
        files: z.ZodOptional<z.ZodArray<z.ZodPreprocess<z.ZodObject<{
            path: z.ZodString;
            mode: z.ZodEnum<{
                deny: "deny";
                mask: "mask";
            }>;
            extract: z.ZodOptional<z.ZodString>;
            onExtractNoMatch: z.ZodOptional<z.ZodEnum<{
                deny: "deny";
                error: "error";
                warn: "warn";
            }>>;
            decode: z.ZodOptional<z.ZodEnum<{
                jwt: "jwt";
            }>>;
            maskClaims: z.ZodOptional<z.ZodArray<z.ZodString>>;
            maskDuplicates: z.ZodOptional<z.ZodBoolean>;
            injectHosts: z.ZodOptional<z.ZodArray<z.ZodString>>;
        }, z.core.$strip>, unknown>>>;
        envVars: z.ZodOptional<z.ZodArray<z.ZodPreprocess<z.ZodObject<{
            name: z.ZodString;
            mode: z.ZodEnum<{
                deny: "deny";
                mask: "mask";
            }>;
            extract: z.ZodOptional<z.ZodString>;
            onExtractNoMatch: z.ZodOptional<z.ZodEnum<{
                deny: "deny";
                error: "error";
                warn: "warn";
            }>>;
            decode: z.ZodOptional<z.ZodEnum<{
                jwt: "jwt";
            }>>;
            maskClaims: z.ZodOptional<z.ZodArray<z.ZodString>>;
            injectHosts: z.ZodOptional<z.ZodArray<z.ZodString>>;
        }, z.core.$strip>, unknown>>>;
        allowPlaintextInject: z.ZodOptional<z.ZodBoolean>;
        awsPairs: z.ZodOptional<z.ZodArray<z.ZodObject<{
            accessKeyIdVar: z.ZodString;
            secretAccessKeyVar: z.ZodString;
            sessionTokenVar: z.ZodOptional<z.ZodString>;
        }, z.core.$strip>>>;
        sigv4: z.ZodOptional<z.ZodObject<{
            streaming: z.ZodOptional<z.ZodEnum<{
                deny: "deny";
                passthrough: "passthrough";
            }>>;
            presigned: z.ZodOptional<z.ZodEnum<{
                deny: "deny";
                passthrough: "passthrough";
            }>>;
            sigv4a: z.ZodOptional<z.ZodEnum<{
                deny: "deny";
                passthrough: "passthrough";
            }>>;
        }, z.core.$strip>>;
    }, z.core.$strip>>;
    ignoreViolations: z.ZodOptional<z.ZodRecord<z.ZodString, z.ZodArray<z.ZodString>>>;
    enableWeakerNestedSandbox: z.ZodOptional<z.ZodBoolean>;
    enableWeakerNetworkIsolation: z.ZodOptional<z.ZodBoolean>;
    allowAppleEvents: z.ZodOptional<z.ZodBoolean>;
    excludedCommands: z.ZodOptional<z.ZodArray<z.ZodString>>;
    ripgrep: z.ZodOptional<z.ZodObject<{
        command: z.ZodString;
        args: z.ZodOptional<z.ZodArray<z.ZodString>>;
    }, z.core.$strip>>;
    bwrapPath: z.ZodCatch<z.ZodOptional<z.ZodPreprocess<z.ZodString, unknown>>>;
    socatPath: z.ZodCatch<z.ZodOptional<z.ZodPreprocess<z.ZodString, unknown>>>;
}, z.core.$loose>;
export declare type SDKActiveGoalMessage = {
    type: 'active_goal';
    value: {
        condition: string;
        iterations: number;
        set_at: number;
        tokens_at_start: number;
        last_reason?: string;
    } | null;
    uuid: UUID;
    session_id: string;
};
export declare type SDKAPIRetryMessage = {
    type: 'system';
    subtype: 'api_retry';
    attempt: number;
    max_retries: number;
    retry_delay_ms: number;
    error_status: number | null;
    error: SDKAssistantMessageError;
    no_response?: {
        waited_ms: number;
        retry_wait_ms: number;
    };
    uuid: UUID;
    session_id: string;
};
export declare type SDKAssistantMessage = {
    type: 'assistant';
    message: BetaMessage;
    parent_tool_use_id: string | null;
    error?: SDKAssistantMessageError;
    uuid: UUID;
    session_id: string;
    request_id?: string;
    user_message_uuid?: string;
    user_message_uuids?: string[];
    resume_reason?: string;
    resumed_from_incomplete_thinking?: true;
    supersedes?: UUID[];
    aborted?: true;
    subagent_type?: string;
    task_description?: string;
    timestamp?: string;
    context_usage?: SDKContextUsage;
    usage_report?: SDKUsageReport;
};
export declare type SDKAssistantMessageError = 'authentication_failed' | 'oauth_org_not_allowed' | 'account_on_hold' | 'verification_required' | 'billing_error' | 'rate_limit' | 'overloaded' | 'invalid_request' | 'model_not_found' | 'server_error' | 'unknown' | 'max_output_tokens' | 'cloud_credential_error';
export declare type SDKAuthStatusMessage = {
    type: 'auth_status';
    isAuthenticating: boolean;
    output: string[];
    error?: string;
    uuid: UUID;
    session_id: string;
};
export declare type SDKBackgroundTasksChangedMessage = {
    type: 'system';
    subtype: 'background_tasks_changed';
    tasks: {
        task_id: string;
        task_type: string;
        description: string;
        ambient?: boolean;
    }[];
    uuid: UUID;
    session_id: string;
};
export declare type SdkBeta = 'context-1m-2025-08-07';
export declare type SDKCommandsChangedMessage = {
    type: 'system';
    subtype: 'commands_changed';
    commands: SlashCommand[];
    uuid: UUID;
    session_id: string;
};
export declare type SDKCompactBoundaryMessage = {
    type: 'system';
    subtype: 'compact_boundary';
    compact_metadata: {
        trigger: 'manual' | 'auto';
        pre_tokens: number;
        post_tokens?: number;
        duration_ms?: number;
        preserved_segment?: {
            head_uuid: UUID;
            anchor_uuid: UUID;
            tail_uuid: UUID;
        };
        preserved_messages?: {
            anchor_uuid: UUID;
            uuids: UUID[];
        };
    };
    uuid: UUID;
    session_id: string;
};
export declare type SDKContextUsage = {
    model: string;
    total_tokens: number;
    raw_max_tokens: number;
    percentage: number;
    over_limit?: {
        tokens_over: number;
        kind: 'hard_limit' | 'compaction_window';
    };
    categories: SDKContextUsageCategory[];
    mcp_tools: {
        name: string;
        server_name: string;
        tokens: number;
    }[];
    memory_files: {
        path: string;
        type: string;
        tokens: number;
    }[];
    agents: {
        agent_type: string;
        source: string;
        tokens: number;
    }[];
    skills?: {
        name: string;
        source: string;
        plugin_name?: string;
        tokens: number;
    }[];
};
export declare type SDKContextUsageCategory = {
    name: string;
    tokens: number;
    kind: 'used' | 'free' | 'buffer' | 'deferred';
};
declare type SDKControlApplyFlagSettingsRequest = {
    subtype: 'apply_flag_settings';
    settings: Record<string, unknown>;
};
declare type SDKControlBackgroundTasksRequest = {
    subtype: 'background_tasks';
    tool_use_id?: string;
};
declare type SDKControlCancelAsyncMessageRequest = {
    subtype: 'cancel_async_message';
    message_uuid: string;
};
declare type SDKControlCancelRequest = {
    type: 'control_cancel_request';
    request_id: string;
};
declare type SDKControlElicitationRequest = {
    subtype: 'elicitation';
    mcp_server_name: string;
    message: string;
    mode?: 'form' | 'url';
    url?: string;
    elicitation_id?: string;
    requested_schema?: Record<string, unknown>;
    title?: string;
    display_name?: string;
    description?: string;
};
declare type SDKControlFileSuggestionsRequest = {
    subtype: 'file_suggestions';
    query: string;
};
declare type SDKControlGetBinaryVersionRequest = {
    subtype: 'get_binary_version';
};
declare type SDKControlGetContextUsageRequest = {
    subtype: 'get_context_usage';
    detail?: 'summary' | 'full';
};
export declare type SDKControlGetContextUsageResponse = {
    categories: {
        name: string;
        tokens: number;
        color: string;
        isDeferred?: boolean;
        kind: 'used' | 'free' | 'buffer' | 'deferred';
    }[];
    totalTokens: number;
    maxTokens: number;
    rawMaxTokens: number;
    percentage: number;
    gridRows: {
        color: string;
        isFilled: boolean;
        categoryName: string;
        tokens: number;
        percentage: number;
        squareFullness: number;
    }[][];
    model: string;
    memoryFiles: {
        path: string;
        type: string;
        tokens: number;
    }[];
    mcpTools: {
        name: string;
        serverName: string;
        tokens: number;
        isLoaded?: boolean;
    }[];
    deferredBuiltinTools?: {
        name: string;
        tokens: number;
        isLoaded: boolean;
    }[];
    systemTools?: {
        name: string;
        tokens: number;
    }[];
    systemPromptSections?: {
        name: string;
        tokens: number;
    }[];
    agents: {
        agentType: string;
        source: string;
        tokens: number;
    }[];
    slashCommands?: {
        totalCommands: number;
        includedCommands: number;
        tokens: number;
    };
    skills?: {
        totalSkills: number;
        includedSkills: number;
        tokens: number;
        skillFrontmatter: {
            name: string;
            source: string;
            tokens: number;
        }[];
    };
    autoCompactThreshold?: number;
    isAutoCompactEnabled: boolean;
    messageBreakdown?: {
        toolCallTokens: number;
        toolResultTokens: number;
        attachmentTokens: number;
        assistantMessageTokens: number;
        userMessageTokens: number;
        redirectedContextTokens: number;
        unattributedTokens: number;
        toolCallsByType: {
            name: string;
            callTokens: number;
            resultTokens: number;
        }[];
        attachmentsByType: {
            name: string;
            tokens: number;
        }[];
    };
    apiUsage: {
        input_tokens: number;
        output_tokens: number;
        cache_creation_input_tokens: number;
        cache_read_input_tokens: number;
    } | null;
};
declare type SDKControlGetHooksListingRequest = {
    subtype: 'get_hooks_listing';
};
declare type SDKControlGetHooksListingResponse = {
    events: {
        name: string;
        summary: string;
        supportsMatcher: boolean;
        hookCount: number;
    }[];
    hooks: {
        event: string;
        matcher: string;
        source: string;
        sourceLabel: string;
        pluginName?: string;
        type: string;
        displayText: string;
        commandText: string;
        contentLabel: string;
        condition?: string;
        timeout?: number;
        statusMessage?: string;
        runsOnce?: boolean;
        runsInBackground?: boolean;
        disabled?: true;
        editable?: {
            matcher: string;
            config: Record<string, unknown>;
            headersRedacted?: true;
        };
    }[];
    eventCatalog: {
        name: string;
        summary: string;
        supportsMatcher: boolean;
    }[];
    policy: {
        disabledByPolicy: boolean;
        managedOnly: boolean;
        pluginOnly: boolean;
        allDisabled: boolean;
        policyHookCount: number;
        policyUnreadable?: true;
    };
    safeMode?: {
        managedHooksStillApply: boolean;
        exitHint: string;
    };
    bareMode?: {
        exitHint: string;
    };
    errors?: coreTypes.SDKSettingsParseError[];
};
declare type SDKControlGetSessionCostRequest = {
    subtype: 'get_session_cost';
};
declare type SDKControlGetSettingsRequest = {
    subtype: 'get_settings';
};
declare type SDKControlGetTaskOutputRequest = {
    subtype: 'get_task_output';
    task_id: string;
};
declare type SDKControlGetTaskOutputResponse = {
    output: string;
    total_bytes: number;
    truncated: boolean;
};
declare type SDKControlGetUsageRequest = {
    subtype: 'get_usage';
    skip_behaviors?: boolean;
};
export declare type SDKControlGetUsageResponse = {
    session: {
        total_cost_usd: number;
        total_api_duration_ms: number;
        total_duration_ms: number;
        total_lines_added: number;
        total_lines_removed: number;
        model_usage: Record<string, coreTypes.ModelUsage>;
    };
    subscription_type: string | null;
    rate_limits_available: boolean;
    rate_limits: {
        five_hour?: {
            utilization: number | null;
            resets_at: string | null;
        } | null;
        seven_day?: {
            utilization: number | null;
            resets_at: string | null;
        } | null;
        seven_day_oauth_apps?: {
            utilization: number | null;
            resets_at: string | null;
        } | null;
        seven_day_opus?: {
            utilization: number | null;
            resets_at: string | null;
        } | null;
        seven_day_sonnet?: {
            utilization: number | null;
            resets_at: string | null;
        } | null;
        model_scoped?: {
            display_name: string;
            utilization: number | null;
            resets_at: string | null;
        }[];
        extra_usage?: {
            is_enabled: boolean;
            monthly_limit: number | null;
            used_credits: number | null;
            utilization: number | null;
            currency?: string | null;
        } | null;
    } | null;
    behaviors: {
        day: {
            request_count: number;
            session_count: number;
            behaviors: {
                key: 'cache_miss' | 'long_context' | 'subagent_heavy' | 'high_parallel' | 'cron';
                pct: number;
                count: number;
            }[];
            agents: {
                name: string;
                pct: number;
            }[];
            skills: {
                name: string;
                pct: number;
            }[];
            plugins: {
                name: string;
                pct: number;
            }[];
            mcp_servers: {
                name: string;
                pct: number;
            }[];
        };
        week: {
            request_count: number;
            session_count: number;
            behaviors: {
                key: 'cache_miss' | 'long_context' | 'subagent_heavy' | 'high_parallel' | 'cron';
                pct: number;
                count: number;
            }[];
            agents: {
                name: string;
                pct: number;
            }[];
            skills: {
                name: string;
                pct: number;
            }[];
            plugins: {
                name: string;
                pct: number;
            }[];
            mcp_servers: {
                name: string;
                pct: number;
            }[];
        };
    } | null;
};
declare type SDKControlInitializeRequest = {
    subtype: 'initialize';
    hooks?: Partial<Record<coreTypes.HookEvent, SDKHookCallbackMatcher[]>>;
    sdkMcpServers?: string[];
    sdkMcpServerConfigs?: Record<string, {
        timeout?: number;
    }>;
    sdkMcpServerManifests?: Record<string, {
        initializeResult: Record<string, unknown>;
        toolsListResult?: Record<string, unknown>;
    }>;
    sdkMcpServerManifestsOrigin?: 'host_per_send';
    jsonSchema?: Record<string, unknown>;
    systemPrompt?: string[];
    appendSystemPrompt?: string;
    systemPromptSnapshot?: boolean;
    planModeInstructions?: string;
    toolAliases?: Record<string, string>;
    excludeDynamicSections?: boolean;
    agents?: Record<string, coreTypes.AgentDefinition>;
    title?: string;
    skills?: string[];
    promptSuggestions?: boolean;
    agentProgressSummaries?: boolean;
    forwardSubagentText?: boolean;
    supportedDialogKinds?: string[];
    perTaskStopAffordance?: boolean;
    plugins?: coreTypes.SdkPluginConfig[];
};
export declare type SDKControlInitializeResponse = {
    commands: coreTypes.SlashCommand[];
    agents: coreTypes.AgentInfo[];
    output_style: string;
    available_output_styles: string[];
    models: coreTypes.ModelInfo[];
    account: coreTypes.AccountInfo;
    hooks_applied?: boolean;
    plugins_applied?: boolean;
    sdk_mcp_manifests_parked?: Record<string, 'parked' | 'already_connected' | 'protocol_version_mismatch' | 'malformed' | 'not_honoured'>;
    fast_mode_state?: coreTypes.FastModeState;
    fast_mode_disabled_reason?: coreTypes.FastModeDisabledReason;
};
declare type SDKControlInterruptRequest = {
    subtype: 'interrupt';
    cancel_queued?: boolean;
};
export declare type SDKControlInterruptResponse = {
    still_queued: string[];
    cancelled?: string[];
};
declare type SDKControlListModelsRequest = {
    subtype: 'list_models';
};
declare type SDKControlListPermissionRulesRequest = {
    subtype: 'list_permission_rules';
};
export declare type SDKControlListPermissionRulesResponse = {
    state: SDKControlPermissionRulesState;
};
declare type SDKControlMcpCallRequest = {
    subtype: 'mcp_call';
    tool: string;
    arguments?: Record<string, unknown>;
    expires_at?: string;
    timeout_ms?: number;
    input_files?: {
        name: string;
        lane_path: string;
    }[];
    output_files?: {
        name: string;
        lane_path: string;
        if_match?: string;
    }[];
};
declare type SDKControlMcpMessageRequest = {
    subtype: 'mcp_message';
    server_name: string;
    message: JSONRPCMessage;
};
declare type SDKControlMcpReadResourceRequest = {
    subtype: 'mcp_read_resource';
    serverName: string;
    uri: string;
};
export declare type SDKControlMcpReadResourceResponse = {
    contents: {
        uri: string;
        mimeType?: string;
        text?: string;
        blob?: string;
        _meta?: Record<string, unknown>;
    }[];
};
declare type SDKControlMcpReconnectRequest = {
    subtype: 'mcp_reconnect';
    serverName: string;
};
declare type SDKControlMcpSetServersRequest = {
    subtype: 'mcp_set_servers';
    servers: Record<string, coreTypes.McpServerConfigForProcessTransport>;
};
declare type SDKControlMcpStatusRequest = {
    subtype: 'mcp_status';
};
declare type SDKControlMcpToggleRequest = {
    subtype: 'mcp_toggle';
    serverName: string;
    enabled: boolean;
};
declare type SDKControlPermissionRequest = {
    subtype: 'can_use_tool';
    tool_name: string;
    mcp_server?: coreTypes.McpServerProvenance;
    input: Record<string, unknown>;
    permission_suggestions?: coreTypes.PermissionUpdate[];
    blocked_path?: string;
    decision_reason?: string;
    decision_reason_type?: 'rule' | 'mode' | 'subcommandResults' | 'permissionPromptTool' | 'hook' | 'asyncAgent' | 'sandboxOverride' | 'workingDir' | 'safetyCheck' | 'classifier' | 'other';
    classifier_approvable?: boolean;
    suppress_always_allow_rule?: boolean;
    default_to_no?: boolean;
    matched_ask_rule?: {
        source: string;
        tool_name: string;
        rule_content?: string;
    };
    title?: string;
    display_name?: string;
    tool_use_id: string;
    agent_id?: string;
    description?: string;
    requires_user_interaction?: boolean;
};
export declare type SDKControlPermissionRulesState = {
    rules: SDKPermissionRuleEntry[];
    workspaceDirectories: SDKPermissionWorkspaceDirectory[];
    originalCwd: string;
    managedOnly: boolean;
    errors?: coreTypes.SDKSettingsParseError[];
};
declare type SDKControlReadFileRequest = {
    subtype: 'read_file';
    path: string;
    max_bytes?: number;
    encoding?: 'utf-8' | 'base64';
};
export declare type SDKControlReadFileResponse = {
    contents: string;
    absPath: string;
    truncated?: boolean;
    encoding?: 'base64';
};
declare type SDKControlRegisterRepoRootRequest = {
    subtype: 'register_repo_root';
    directory: string;
    reload_claude_md?: boolean;
    reload_plugins?: boolean;
    reload_skills?: boolean;
};
declare type SDKControlReloadOutputStylesRequest = {
    subtype: 'reload_output_styles';
};
export declare type SDKControlReloadOutputStylesResponse = {
    available_output_styles: string[];
};
declare type SDKControlReloadPluginsRequest = {
    subtype: 'reload_plugins';
    hold_on_cache_impact?: boolean;
};
export declare type SDKControlReloadPluginsResponse = {
    commands: coreTypes.SlashCommand[];
    agents: coreTypes.AgentInfo[];
    plugins: {
        name: string;
        path: string;
        source?: string;
        version?: string;
    }[];
    mcpServers: coreTypes.McpServerStatus[];
    error_count: number;
    held?: boolean;
    cache_impact?: {
        mcp_servers_added: string[];
        mcp_servers_removed: string[];
        lsp_tool_change: ('adds' | 'may-add' | 'removes' | 'may-remove') | null;
    };
};
declare type SDKControlReloadSkillsRequest = {
    subtype: 'reload_skills';
};
export declare type SDKControlReloadSkillsResponse = {
    skills: coreTypes.SlashCommand[];
};
declare type SDKControlRenameSessionRequest = {
    subtype: 'rename_session';
    title: string;
    source?: 'remote' | 'host';
    session_id?: string;
};
export declare type SDKControlRequest = {
    type: 'control_request';
    request_id: string;
    request: SDKControlRequestInner;
};
declare type SDKControlRequestInner = SDKControlInterruptRequest | SDKControlPermissionRequest | SDKControlInitializeRequest | SDKControlSetPermissionModeRequest | SDKControlSetModelRequest | SDKControlSetMaxThinkingTokensRequest | SDKControlRenameSessionRequest | SDKControlSetColorRequest | SDKControlMcpStatusRequest | SDKControlGetContextUsageRequest | SDKControlGetSessionCostRequest | SDKControlListModelsRequest | SDKControlGetUsageRequest | SDKControlGetBinaryVersionRequest | SDKControlMcpCallRequest | SDKControlFileSuggestionsRequest | SDKHookCallbackRequest | SDKControlMcpMessageRequest | SDKControlRewindFilesRequest | SDKControlCancelAsyncMessageRequest | SDKControlReadFileRequest | SDKControlSeedReadStateRequest | SDKControlMcpSetServersRequest | SDKControlRegisterRepoRootRequest | SDKControlReloadPluginsRequest | SDKControlReloadSkillsRequest | SDKControlReloadOutputStylesRequest | SDKControlMcpReconnectRequest | SDKControlMcpToggleRequest | SDKControlStopTaskRequest | SDKControlBackgroundTasksRequest | SDKControlGetTaskOutputRequest | SDKControlApplyFlagSettingsRequest | SDKControlGetSettingsRequest | SDKControlGetHooksListingRequest | SDKControlUpdateSettingsRequest | SDKControlElicitationRequest | SDKControlRequestUserDialogRequest | SDKControlListPermissionRulesRequest | SDKControlMcpReadResourceRequest;
export declare type SDKControlRequestProgressMessage = {
    type: 'system';
    subtype: 'control_request_progress';
    request_id: string;
    status: 'started' | 'api_retry';
    attempt?: number;
    max_retries?: number;
    retry_delay_ms?: number;
    error_status?: number | null;
    uuid: UUID;
    session_id: string;
};
declare type SDKControlRequestUserDialogRequest = {
    subtype: 'request_user_dialog';
    dialog_kind: string;
    payload: Record<string, unknown>;
    tool_use_id?: string;
};
export declare type SDKControlResponse = {
    type: 'control_response';
    response: ControlResponse | ControlErrorResponse;
};
declare type SDKControlRewindFilesRequest = {
    subtype: 'rewind_files';
    user_message_id: string;
    dry_run?: boolean;
};
declare type SDKControlSeedReadStateRequest = {
    subtype: 'seed_read_state';
    path: string;
    mtime: number;
};
declare type SDKControlSetColorRequest = {
    subtype: 'set_color';
    color: string;
};
declare type SDKControlSetMaxThinkingTokensRequest = {
    subtype: 'set_max_thinking_tokens';
    max_thinking_tokens?: number | null;
    thinking_display?: ('summarized' | 'omitted' | 'highlights') | null;
};
declare type SDKControlSetModelRequest = {
    subtype: 'set_model';
    model?: string | null;
};
declare type SDKControlSetPermissionModeRequest = {
    subtype: 'set_permission_mode';
    mode: coreTypes.PermissionMode;
};
declare type SDKControlStopTaskRequest = {
    subtype: 'stop_task';
    task_id: string;
};
declare type SDKControlUpdateSettingsRequest = {
    subtype: 'update_settings';
    source: 'localSettings' | 'userSettings';
    settings: Record<string, unknown>;
};
export declare type SDKConversationResetMessage = {
    type: 'conversation_reset';
    new_conversation_id: UUID;
    uuid: UUID;
    session_id: string;
    trigger?: 'clear' | 'plan_mode_exit' | 'fresh_session' | 'onboarding';
    user_message_uuid?: string;
    timestamp?: string;
};
export declare type SDKDeferredToolUse = {
    id: string;
    name: string;
    input: Record<string, unknown>;
};
export declare type SDKElicitationCompleteMessage = {
    type: 'system';
    subtype: 'elicitation_complete';
    mcp_server_name: string;
    elicitation_id: string;
    uuid: UUID;
    session_id: string;
};
export declare type SDKFilesPersistedEvent = {
    type: 'system';
    subtype: 'files_persisted';
    files: {
        filename: string;
        file_id: string;
    }[];
    failed: {
        filename: string;
        error: string;
    }[];
    processed_at: string;
    uuid: UUID;
    session_id: string;
};
declare type SDKHookCallbackMatcher = {
    matcher?: string;
    hookCallbackIds: string[];
    timeout?: number;
};
declare type SDKHookCallbackRequest = {
    subtype: 'hook_callback';
    callback_id: string;
    input: coreTypes.HookInput;
    tool_use_id?: string;
};
export declare type SDKHookProgressMessage = {
    type: 'system';
    subtype: 'hook_progress';
    hook_id: string;
    hook_name: string;
    hook_event: string;
    stdout: string;
    stderr: string;
    output: string;
    uuid: UUID;
    session_id: string;
};
export declare type SDKHookResponseMessage = {
    type: 'system';
    subtype: 'hook_response';
    hook_id: string;
    hook_name: string;
    hook_event: string;
    output: string;
    stdout: string;
    stderr: string;
    exit_code?: number;
    outcome: 'success' | 'error' | 'cancelled';
    uuid: UUID;
    session_id: string;
};
export declare type SDKHookStartedMessage = {
    type: 'system';
    subtype: 'hook_started';
    hook_id: string;
    hook_name: string;
    hook_event: string;
    uuid: UUID;
    session_id: string;
};
export declare type SDKInformationalMessage = {
    type: 'system';
    subtype: 'informational';
    content: string;
    level: 'info' | 'notice' | 'suggestion' | 'warning';
    tool_use_id?: string;
    prevent_continuation?: boolean;
    uuid: UUID;
    session_id: string;
};
declare type SDKKeepAliveMessage = {
    type: 'keep_alive';
};
export declare type SDKLocalCommandOutputMessage = {
    type: 'system';
    subtype: 'local_command_output';
    content: string;
    uuid: UUID;
    session_id: string;
};
export declare type SDKMcpResourceLink = {
    uri: string;
    name: string;
    title?: string;
    description?: string;
    mimeType?: string;
    size?: number;
    annotations?: Record<string, unknown>;
};
export declare type SdkMcpToolDefinition<Schema extends AnyZodRawShape = AnyZodRawShape> = {
    name: string;
    description: string;
    inputSchema: Schema;
    annotations?: ToolAnnotations;
    _meta?: Record<string, unknown>;
    handler: (args: InferShape<Schema>, extra: unknown) => Promise<CallToolResult>;
};
export declare type SDKMemoryRecallMessage = {
    type: 'system';
    subtype: 'memory_recall';
    mode: 'select' | 'synthesize';
    memories: {
        path: string;
        scope: 'personal' | 'team' | 'organization';
        content?: string;
    }[];
    uuid: UUID;
    session_id: string;
};
export declare type SDKMessage = SDKAssistantMessage | SDKUserMessage | SDKUserMessageReplay | SDKResultMessage | SDKSystemMessage | SDKPartialAssistantMessage | SDKCompactBoundaryMessage | SDKStatusMessage | SDKAPIRetryMessage | SDKControlRequestProgressMessage | SDKModelRefusalFallbackMessage | SDKModelRefusalNoFallbackMessage | SDKLocalCommandOutputMessage | SDKHookStartedMessage | SDKHookProgressMessage | SDKHookResponseMessage | SDKPluginInstallMessage | SDKToolProgressMessage | SDKAuthStatusMessage | SDKTaskNotificationMessage | SDKTaskStartedMessage | SDKTaskUpdatedMessage | SDKTaskProgressMessage | SDKBackgroundTasksChangedMessage | SDKThinkingTokensMessage | SDKSessionStateChangedMessage | SDKWorkerShuttingDownMessage | SDKCommandsChangedMessage | SDKNotificationMessage | SDKFilesPersistedEvent | SDKToolUseSummaryMessage | SDKMemoryRecallMessage | SDKRateLimitEvent | SDKElicitationCompleteMessage | SDKPermissionDeniedMessage | SDKPromptSuggestionMessage | SDKMirrorErrorMessage | SDKInformationalMessage | SDKConversationResetMessage;
export declare type SDKMessageOrigin = {
    kind: 'human';
} | {
    kind: 'channel';
    server: string;
} | {
    kind: 'peer';
    from: string;
    fromMode?: 'bypass' | 'prompting';
    name?: string;
    fromSession?: string;
    senderTaskId?: string;
    body?: string;
    verifiedPeerPid?: number;
} | {
    kind: 'task-notification';
    subkind?: 'scheduled-trigger' | 'peer-send-message' | 'projects-relay' | 'session-inbox';
    fireReason?: string;
} | {
    kind: 'coordinator';
} | {
    kind: 'unclassified';
} | {
    kind: 'observer';
    from: string;
    senderTaskId: string;
} | {
    kind: 'auto-continuation';
} | {
    kind: 'observer-activity';
};
export declare type SDKMirrorErrorMessage = {
    type: 'system';
    subtype: 'mirror_error';
    error: string;
    key: {
        projectKey: string;
        sessionId: string;
        subpath?: string;
    };
    uuid: UUID;
    session_id: string;
};
export declare type SDKModelRefusalFallbackMessage = {
    type: 'system';
    subtype: 'model_refusal_fallback';
    trigger: 'refusal';
    direction: 'retry' | 'revert' | 'sticky';
    scope?: 'session' | 'local';
    original_model: string;
    fallback_model: string;
    request_id: string | null;
    api_refusal_category?: string | null;
    api_refusal_explanation?: string | null;
    retracted_message_uuids?: string[];
    refused_user_message_uuid?: string | null;
    content: string;
    uuid: UUID;
    session_id: string;
};
export declare type SDKModelRefusalNoFallbackMessage = {
    type: 'system';
    subtype: 'model_refusal_no_fallback';
    original_model: string;
    request_id: string | null;
    api_refusal_category?: string | null;
    api_refusal_explanation?: string | null;
    refused_user_message_uuid?: string | null;
    content: string;
    uuid: UUID;
    session_id: string;
};
export declare type SDKNotificationMessage = {
    type: 'system';
    subtype: 'notification';
    key: string;
    text: string;
    priority: 'low' | 'medium' | 'high' | 'immediate';
    color?: string;
    timeout_ms?: number;
    uuid: UUID;
    session_id: string;
};
export declare type SDKPartialAssistantMessage = {
    type: 'stream_event';
    event: BetaRawMessageStreamEvent;
    parent_tool_use_id: string | null;
    uuid: UUID;
    session_id: string;
    ttft_ms?: number;
    user_message_uuid?: string;
    user_message_uuids?: string[];
    resume_reason?: string;
};
export declare type SDKPermissionDenial = {
    tool_name: string;
    tool_use_id: string;
    tool_input: Record<string, unknown>;
};
export declare type SDKPermissionDeniedMessage = {
    type: 'system';
    subtype: 'permission_denied';
    tool_name: string;
    tool_use_id: string;
    agent_id?: string;
    decision_reason_type?: string;
    decision_reason?: string;
    message: string;
    uuid: UUID;
    session_id: string;
};
export declare type SDKPermissionRuleDescription = {
    prefix: string;
    emphasis?: string;
    suffix?: string;
};
export declare type SDKPermissionRuleEntry = {
    behavior: 'allow' | 'deny' | 'ask';
    source: 'userSettings' | 'projectSettings' | 'localSettings' | 'flagSettings' | 'policySettings' | 'cliArg' | 'command' | 'session' | 'toolsNarrowing' | 'mcpServerPolicy' | 'hostCredential';
    rule: string;
    description?: SDKPermissionRuleDescription;
    editability: 'persistent' | 'session' | 'readonly';
    notInEffect?: boolean;
};
export declare type SDKPermissionWorkspaceDirectory = {
    path: string;
    source: string;
};
export declare type SdkPluginConfig = {
    type: 'local';
    path: string;
    skipMcpDiscovery?: boolean;
};
export declare type SDKPluginInstallMessage = {
    type: 'system';
    subtype: 'plugin_install';
    status: 'started' | 'installed' | 'failed' | 'completed';
    name?: string;
    error?: string;
    uuid: UUID;
    session_id: string;
};
export declare type SDKPromptSuggestionMessage = {
    type: 'prompt_suggestion';
    suggestion: string;
    uuid: UUID;
    session_id: string;
};
export declare type SDKRateLimitEvent = {
    type: 'rate_limit_event';
    rate_limit_info: SDKRateLimitInfo;
    uuid: UUID;
    session_id: string;
};
export declare type SDKRateLimitInfo = {
    status: 'allowed' | 'allowed_warning' | 'rejected';
    resetsAt?: number;
    rateLimitType?: 'five_hour' | 'seven_day' | 'seven_day_opus' | 'seven_day_sonnet' | 'seven_day_overage_included' | 'overage';
    utilization?: number;
    overageStatus?: 'allowed' | 'allowed_warning' | 'rejected';
    overageResetsAt?: number;
    overageDisabledReason?: 'overage_not_provisioned' | 'org_level_disabled' | 'org_level_disabled_until' | 'out_of_credits' | 'seat_tier_level_disabled' | 'member_level_disabled' | 'seat_tier_zero_credit_limit' | 'group_zero_credit_limit' | 'member_zero_credit_limit' | 'org_service_level_disabled' | 'no_limits_configured' | 'fetch_error' | 'unknown';
    isUsingOverage?: boolean;
    overageInUse?: boolean;
    surpassedThreshold?: number;
    limitScope?: 'service' | 'channel' | 'group_pool';
    errorCode?: 'credits_required';
    canUserPurchaseCredits?: boolean;
    hasChargeableSavedPaymentMethod?: boolean;
};
export declare type SDKResultError = {
    type: 'result';
    subtype: 'error_during_execution' | 'error_max_turns' | 'error_max_budget_usd' | 'error_max_structured_output_retries';
    duration_ms: number;
    duration_api_ms: number;
    is_error: boolean;
    num_turns: number;
    stop_reason: string | null;
    total_cost_usd: number;
    usage: NonNullableUsage;
    modelUsage: Record<string, ModelUsage>;
    permission_denials: SDKPermissionDenial[];
    queued_turn_count?: number;
    errors: string[];
    startup_failure_reason?: SDKStartupFailureReason;
    user_message_uuid?: string;
    user_message_uuids?: string[];
    resume_reason?: string;
    terminal_reason?: TerminalReason;
    result_index?: number;
    fast_mode_state?: FastModeState;
    fast_mode_disabled_reason?: FastModeDisabledReason;
    origin?: SDKMessageOrigin;
    uuid: UUID;
    session_id: string;
};
export declare type SDKResultMessage = SDKResultSuccess | SDKResultError;
export declare type SDKResultSuccess = {
    type: 'result';
    subtype: 'success';
    duration_ms: number;
    duration_api_ms: number;
    ttft_ms?: number;
    ttft_stream_ms?: number;
    time_to_request_ms?: number;
    user_message_uuid?: string;
    user_message_uuids?: string[];
    resume_reason?: string;
    local_command?: string;
    request_sent_wall_ms?: number;
    first_content_frame_ms?: number;
    first_stream_post_ms?: number;
    first_stream_post_ack_ms?: number;
    first_stream_post_queue_wait_ms?: number;
    first_stream_post_queued_behind?: 'durable_post' | 'ephemeral_post' | 'retry_backoff' | 'hold' | 'none';
    first_stream_post_wall_ms?: number;
    first_text_post_ms?: number;
    first_text_post_queue_wait_ms?: number;
    first_text_post_queued_behind?: 'durable_post' | 'ephemeral_post' | 'retry_backoff' | 'hold' | 'none';
    first_text_post_wall_ms?: number;
    time_to_request_from_spawn_ms?: number;
    warm_spare_claimed?: boolean;
    time_origin_ms?: number;
    is_error: boolean;
    api_error_status?: number | null;
    num_turns: number;
    result: string;
    stop_reason: string | null;
    total_cost_usd: number;
    usage: NonNullableUsage;
    modelUsage: Record<string, ModelUsage>;
    permission_denials: SDKPermissionDenial[];
    queued_turn_count?: number;
    structured_output?: unknown;
    deferred_tool_use?: SDKDeferredToolUse;
    terminal_reason?: TerminalReason;
    result_index?: number;
    fast_mode_state?: FastModeState;
    fast_mode_disabled_reason?: FastModeDisabledReason;
    origin?: SDKMessageOrigin;
    uuid: UUID;
    session_id: string;
};
export declare type SDKSessionInfo = {
    sessionId: string;
    summary: string;
    lastModified: number;
    fileSize?: number;
    customTitle?: string;
    firstPrompt?: string;
    gitBranch?: string;
    cwd?: string;
    tag?: string;
    createdAt?: number;
};
export declare type SDKSessionStateChangedMessage = {
    type: 'system';
    subtype: 'session_state_changed';
    state: 'idle' | 'running' | 'requires_action';
    uuid: UUID;
    session_id: string;
};
export declare type SDKSettingsParseError = {
    file?: string;
    path: string;
    message: string;
};
export declare type SDKStartupFailureReason = 'org_pin_api_key_conflict' | 'provider_not_allowed' | 'org_verify_failed' | 'org_pin_mismatch' | 'managed_settings_invalid' | 'remote_settings_required_unavailable' | 'gateway_signin_required' | 'gateway_access_denied' | 'proxy_invalid' | 'temp_dir_unusable' | 'cwd_unavailable' | 'shell_tool_missing' | 'session_held_by_background' | 'worktree_resume_refused' | 'worktree_unverified' | 'cli_version_too_old' | 'bypass_root';
export declare type SDKStatus = 'compacting' | 'requesting' | null;
export declare type SDKStatusMessage = {
    type: 'system';
    subtype: 'status';
    status: SDKStatus;
    permissionMode?: PermissionMode;
    compact_result?: 'success' | 'failed';
    compact_error?: string;
    uuid: UUID;
    session_id: string;
};
export declare type SDKSystemMessage = {
    type: 'system';
    subtype: 'init';
    agents?: string[];
    apiKeySource: ApiKeySource;
    betas?: string[];
    claude_code_version: string;
    cwd: string;
    tools: string[];
    mcp_servers: {
        name: string;
        status: string;
        source?: string;
    }[];
    model: string;
    permissionMode: PermissionMode;
    slash_commands: string[];
    terminal_slash_commands?: string[];
    output_style: string;
    skills: string[];
    plugins: {
        name: string;
        path: string;
        version?: string;
    }[];
    plugin_errors?: {
        plugin: string;
        type: string;
        message: string;
        path?: string;
    }[];
    fast_mode_state?: FastModeState;
    fast_mode_disabled_reason?: FastModeDisabledReason;
    effort?: ('low' | 'medium' | 'high' | 'xhigh' | 'max') | null;
    view_mode?: 'focus' | 'default';
    capabilities?: string[];
    uuid: UUID;
    session_id: string;
};
export declare type SDKTaskNotificationMessage = {
    type: 'system';
    subtype: 'task_notification';
    task_id: string;
    tool_use_id?: string;
    status: 'completed' | 'failed' | 'stopped';
    reason?: 'worker_restart';
    output_file: string;
    summary: string;
    usage?: {
        total_tokens: number;
        tool_uses: number;
        duration_ms: number;
    };
    resource_links?: SDKMcpResourceLink[];
    skip_transcript?: boolean;
    ambient?: boolean;
    uuid: UUID;
    session_id: string;
};
export declare type SDKTaskProgressMessage = {
    type: 'system';
    subtype: 'task_progress';
    task_id: string;
    tool_use_id?: string;
    description: string;
    subagent_type?: string;
    usage: {
        total_tokens: number;
        tool_uses: number;
        duration_ms: number;
    };
    last_tool_name?: string;
    summary?: string;
    uuid: UUID;
    session_id: string;
};
export declare type SDKTaskStartedMessage = {
    type: 'system';
    subtype: 'task_started';
    task_id: string;
    tool_use_id?: string;
    description: string;
    subagent_type?: string;
    is_backgrounded?: boolean;
    spawn_depth?: number;
    task_type?: string;
    workflow_name?: string;
    prompt?: string;
    skip_transcript?: boolean;
    ambient?: boolean;
    uuid: UUID;
    session_id: string;
};
export declare type SDKTaskUpdatedMessage = {
    type: 'system';
    subtype: 'task_updated';
    task_id: string;
    patch: {
        status?: 'pending' | 'running' | 'completed' | 'failed' | 'killed' | 'paused';
        description?: string;
        end_time?: number;
        total_paused_ms?: number;
        error?: string;
        is_backgrounded?: boolean;
    };
    uuid: UUID;
    session_id: string;
};
export declare type SDKThinkingTokensMessage = {
    type: 'system';
    subtype: 'thinking_tokens';
    estimated_tokens: number;
    estimated_tokens_delta: number;
    user_message_uuid?: string;
    uuid: UUID;
    session_id: string;
};
export declare type SDKToolProgressMessage = {
    type: 'tool_progress';
    tool_use_id: string;
    tool_name: string;
    parent_tool_use_id: string | null;
    elapsed_time_seconds: number;
    task_id?: string;
    uuid: UUID;
    session_id: string;
    heartbeat?: boolean;
    subagent_type?: string;
    subagent_retry?: {
        agent_id: string;
        attempt: number;
        max_retries: number;
        retry_delay_ms: number;
        error_status: number | null;
        error_category: string;
    };
};
export declare type SDKToolUseSummaryMessage = {
    type: 'tool_use_summary';
    summary: string;
    preceding_tool_use_ids: string[];
    uuid: UUID;
    session_id: string;
};
export declare type SDKUsageReport = {
    session: {
        total_cost_usd: number;
        total_api_duration_ms: number;
        total_duration_ms: number;
        total_lines_added: number;
        total_lines_removed: number;
        model_usage: Record<string, ModelUsage>;
    };
    rate_limits: {
        limits: {
            kind: string;
            group: string;
            percent: number;
            resets_at: string | null;
            scope?: {
                model?: {
                    display_name: string;
                } | null;
                surface?: {
                    display_name: string;
                } | null;
            } | null;
            severity: string;
            is_active: boolean;
        }[] | null;
        extra_usage?: {
            is_enabled: boolean;
            monthly_limit: number | null;
            used_credits: number | null;
            utilization: number | null;
            currency?: string | null;
        } | null;
    } | null;
};
export declare type SDKUserMessage = {
    type: 'user';
    message: MessageParam;
    parent_tool_use_id: string | null;
    isSynthetic?: boolean;
    tool_use_result?: unknown;
    priority?: 'now' | 'next' | 'later';
    origin?: SDKMessageOrigin;
    shouldQuery?: boolean;
    timestamp?: string;
    client_composed?: true;
    uuid?: UUID;
    pasted_content?: MessageParam['content'][];
    inline_pastes?: string[];
    session_id?: string;
    subagent_type?: string;
    task_description?: string;
};
export declare type SDKUserMessageReplay = {
    type: 'user';
    message: MessageParam;
    parent_tool_use_id: string | null;
    isSynthetic?: boolean;
    tool_use_result?: unknown;
    priority?: 'now' | 'next' | 'later';
    origin?: SDKMessageOrigin;
    shouldQuery?: boolean;
    timestamp?: string;
    client_composed?: true;
    uuid: UUID;
    session_id: string;
    isReplay: true;
    file_attachments?: unknown[];
};
export declare type SDKWorkerShuttingDownMessage = {
    type: 'system';
    subtype: 'worker_shutting_down';
    reason: string;
    uuid: UUID;
    session_id: string;
};
export declare type SessionCronSummary = {
    id: string;
    schedule: string;
    recurring: boolean;
    prompt: string;
};
export declare type SessionEndHookInput = BaseHookInput & {
    hook_event_name: 'SessionEnd';
    reason: ExitReason;
};
export declare type SessionKey = {
    projectKey: string;
    sessionId: string;
    subpath?: string;
};
export declare type SessionMessage = {
    type: 'user' | 'assistant' | 'system';
    uuid: string;
    session_id: string;
    message: unknown;
    parent_tool_use_id: string | null;
    parent_agent_id: string | null;
};
export declare type SessionMutationOptions = {
    dir?: string;
    sessionStore?: SessionStore;
};
export declare type SessionStartHookInput = BaseHookInput & {
    hook_event_name: 'SessionStart';
    source: 'startup' | 'resume' | 'clear' | 'compact' | 'fork';
    agent_type?: string;
    model?: string;
    session_title?: string;
    seconds_since_last_response?: number;
    context_tokens?: number;
    prompt_cache_likely_expired?: boolean;
    estimated_cache_write_usd?: number;
};
export declare type SessionStartHookSpecificOutput = {
    hookEventName: 'SessionStart';
    additionalContext?: string;
    initialUserMessage?: string;
    sessionTitle?: string;
    watchPaths?: string[];
    reloadSkills?: boolean;
};
export declare type SessionStore = {
    append(key: SessionKey, entries: SessionStoreEntry[]): Promise<void>;
    load(key: SessionKey): Promise<SessionStoreEntry[] | null>;
    listSessions?(projectKey: string): Promise<Array<{
        sessionId: string;
        mtime: number;
    }>>;
    listSessionSummaries?(projectKey: string): Promise<SessionSummaryEntry[]>;
    delete?(key: SessionKey): Promise<void>;
    listSubkeys?(key: {
        projectKey: string;
        sessionId: string;
    }): Promise<string[]>;
};
export declare type SessionStoreEntry = {
    type: string;
    uuid?: string;
    timestamp?: string;
    [k: string]: unknown;
};
export declare type SessionStoreFlush = 'batched' | 'eager';
export declare type SessionSummaryEntry = {
    sessionId: string;
    mtime: number;
    data: Record<string, unknown>;
};
export declare interface Settings {
    $schema?: string;
    apiKeyHelper?: string;
    proxyAuthHelper?: string;
    awsCredentialExport?: string;
    awsAuthRefresh?: string;
    gcpAuthRefresh?: string;
    processWrapper?: string;
    policyHelper?: {
        path: string;
        timeoutMs?: number;
        refreshIntervalMs?: 0 | number;
    };
    fileSuggestion?: {
        type: 'command';
        command: string;
    };
    respectGitignore?: boolean;
    cleanupPeriodDays?: number;
    desktopSessionCleanupPeriodDays?: number;
    syncClaudeAiSkills?: boolean;
    syncClaudeAiPlugins?: boolean;
    skillListingMaxDescChars?: number;
    skillListingBudgetFraction?: number;
    wslInheritsWindowsSettings?: boolean;
    env?: {
        [k: string]: string;
    };
    attribution?: boolean | {
        commit?: string;
        pr?: string;
        sessionUrl?: boolean;
        [k: string]: unknown;
    };
    includeCoAuthoredBy?: boolean;
    includeGitInstructions?: boolean;
    permissions?: {
        allow?: string[];
        deny?: string[];
        ask?: string[];
        defaultMode?: 'acceptEdits' | 'auto' | 'bypassPermissions' | 'default' | 'dontAsk' | 'plan';
        disableBypassPermissionsMode?: 'disable';
        blockReadsOutsideWorkingDirectories?: boolean;
        additionalDirectories?: string[];
        [k: string]: unknown;
    };
    model?: string;
    fallbackModel?: string[];
    availableModels?: string[];
    enforceAvailableModels?: boolean;
    availableModelsMatch?: 'prefix' | 'exact';
    deniedModels?: string[];
    modelOverrides?: {
        [k: string]: string;
    };
    modelPicker?: {
        options: {
            model: string;
            label?: string;
            description?: string;
            behavesAs?: string;
        }[];
        replaceBuiltInOptions?: boolean;
    };
    modelPricing?: {
        multiplier?: number;
        overrides?: {
            [k: string]: {
                input: number;
                output: number;
                cacheRead: number;
                cacheWrite: number;
            };
        };
    };
    enableAllProjectMcpServers?: boolean;
    enabledMcpjsonServers?: string[];
    disabledMcpjsonServers?: string[];
    disableClaudeAiConnectors?: boolean;
    skillOverrides?: {
        [k: string]: 'on' | 'name-only' | 'user-invocable-only' | 'off';
    };
    disableBundledSkills?: boolean;
    managedMcpServers?: {
        [k: string]: {
            [k: string]: unknown;
        };
    };
    allowedMcpServers?: {
        serverName?: string;
        serverCommand?: [string, ...string[]];
        serverUrl?: string;
    }[];
    deniedMcpServers?: {
        serverName?: string;
        serverCommand?: [string, ...string[]];
        serverUrl?: string;
    }[];
    hooks?: {
        [k: string]: {
            matcher?: string;
            hooks: ({
                type: 'command';
                command: string;
                args?: string[];
                if?: string;
                shell?: 'bash' | 'powershell';
                timeout?: number;
                statusMessage?: string;
                once?: boolean;
                async?: boolean;
                asyncRewake?: boolean;
            } | {
                type: 'prompt';
                prompt: string;
                if?: string;
                timeout?: number;
                model?: string;
                continueOnBlock?: boolean;
                statusMessage?: string;
                once?: boolean;
            } | {
                type: 'agent';
                prompt: string;
                if?: string;
                timeout?: number;
                model?: string;
                statusMessage?: string;
                once?: boolean;
            } | {
                type: 'http';
                url: string;
                if?: string;
                timeout?: number;
                headers?: {
                    [k: string]: string;
                };
                allowedEnvVars?: string[];
                statusMessage?: string;
                once?: boolean;
            } | {
                type: 'mcp_tool';
                server: string;
                tool: string;
                input?: {
                    [k: string]: unknown;
                };
                if?: string;
                timeout?: number;
                statusMessage?: string;
                once?: boolean;
            })[];
        }[];
    };
    worktree?: {
        symlinkDirectories?: string[];
        sparsePaths?: string[];
        baseRef?: 'fresh' | 'head';
        bgIsolation?: 'worktree' | 'none';
        location?: string;
    };
    disableAllHooks?: boolean;
    disableAgentView?: boolean;
    disableRemoteControl?: boolean;
    disableWorkflows?: boolean;
    disableArtifact?: boolean;
    enableArtifact?: boolean;
    enableWorkflows?: boolean;
    workflowSizeGuideline?: 'unrestricted' | 'small' | 'medium' | 'large';
    workflowKeywordTriggerEnabled?: boolean;
    disableSkillShellExecution?: boolean;
    defaultShell?: 'bash' | 'powershell';
    bashEditDiffEnabled?: boolean;
    bashOutputMaxChars?: number;
    taskOutputMaxChars?: number;
    respondToBashCommands?: boolean;
    allowManagedHooksOnly?: boolean;
    allowedHttpHookUrls?: string[];
    httpHookAllowedEnvVars?: string[];
    allowManagedPermissionRulesOnly?: boolean;
    allowManagedMcpServersOnly?: boolean;
    allowAllClaudeAiMcps?: boolean;
    allowClaudeInChromeWithManagedMcp?: boolean;
    strictPluginOnlyCustomization?: boolean | ('skills' | 'agents' | 'hooks' | 'mcp')[];
    statusLine?: {
        type: 'command';
        command: string;
        padding?: number;
        refreshInterval?: number;
        hideVimModeIndicator?: boolean;
    };
    prUrlTemplate?: string;
    footerLinksRegexes?: ({
        type: 'regex';
        pattern: string;
        url: string;
        label?: string;
        [k: string]: unknown;
    } | {
        type: string;
        [k: string]: unknown;
    })[];
    subagentStatusLine?: {
        type: 'command';
        command: string;
    };
    enabledPlugins?: {
        [k: string]: string[] | boolean | {
            [k: string]: unknown;
        };
    };
    prependPlugins?: string[];
    appendPlugins?: string[];
    extraKnownMarketplaces?: {
        [k: string]: {
            source: {
                source: 'url';
                url: string;
                headers?: {
                    [k: string]: string;
                };
                headersHelper?: string;
            } | {
                source: 'github';
                repo: string;
                ref?: string;
                path?: string;
                sparsePaths?: string[];
                skipLfs?: boolean;
            } | {
                source: 'git';
                url: string;
                ref?: string;
                path?: string;
                sparsePaths?: string[];
                skipLfs?: boolean;
            } | {
                source: 'npm';
                package: string;
                version?: string;
                registry?: string;
            } | {
                source: 'file';
                path: string;
            } | {
                source: 'directory';
                path: string;
            } | {
                source: 'skills-dir';
            } | {
                source: 'hostPattern';
                hostPattern: string;
            } | {
                source: 'pathPattern';
                pathPattern: string;
            } | {
                source: 'settings';
                name: string;
                plugins: {
                    name: string;
                    source: string | {
                        source: 'npm';
                        package: string;
                        version?: string;
                        registry?: string;
                    } | {
                        source: 'url';
                        url: string;
                        ref?: string;
                        sha?: string;
                    } | {
                        source: 'github';
                        repo: string;
                        ref?: string;
                        sha?: string;
                    } | {
                        source: 'git-subdir';
                        url: string;
                        path: string;
                        ref?: string;
                        sha?: string;
                    } | {
                        source: 'archive';
                        url: string;
                        sha256?: string;
                    } | {
                        source: 'command';
                        command: string;
                        timeout?: number;
                        mode?: 'copy' | 'link';
                    } | {
                        source: 'unsupported';
                        error?: string;
                    };
                    description?: string;
                    version?: string;
                    strict?: boolean;
                    headers?: {
                        [k: string]: string;
                    };
                    headersHelper?: string;
                }[];
                owner?: {
                    name: string;
                    email?: string;
                    url?: string;
                };
            };
            installLocation?: string;
            autoUpdate?: boolean;
        };
    };
    additionalMarketplaces?: {
        [k: string]: {
            source: {
                source: 'url';
                url: string;
                headers?: {
                    [k: string]: string;
                };
                headersHelper?: string;
            } | {
                source: 'github';
                repo: string;
                ref?: string;
                path?: string;
                sparsePaths?: string[];
                skipLfs?: boolean;
            } | {
                source: 'git';
                url: string;
                ref?: string;
                path?: string;
                sparsePaths?: string[];
                skipLfs?: boolean;
            } | {
                source: 'npm';
                package: string;
                version?: string;
                registry?: string;
            } | {
                source: 'file';
                path: string;
            } | {
                source: 'directory';
                path: string;
            } | {
                source: 'skills-dir';
            } | {
                source: 'hostPattern';
                hostPattern: string;
            } | {
                source: 'pathPattern';
                pathPattern: string;
            } | {
                source: 'settings';
                name: string;
                plugins: {
                    name: string;
                    source: string | {
                        source: 'npm';
                        package: string;
                        version?: string;
                        registry?: string;
                    } | {
                        source: 'url';
                        url: string;
                        ref?: string;
                        sha?: string;
                    } | {
                        source: 'github';
                        repo: string;
                        ref?: string;
                        sha?: string;
                    } | {
                        source: 'git-subdir';
                        url: string;
                        path: string;
                        ref?: string;
                        sha?: string;
                    } | {
                        source: 'archive';
                        url: string;
                        sha256?: string;
                    } | {
                        source: 'command';
                        command: string;
                        timeout?: number;
                        mode?: 'copy' | 'link';
                    } | {
                        source: 'unsupported';
                        error?: string;
                    };
                    description?: string;
                    version?: string;
                    strict?: boolean;
                    headers?: {
                        [k: string]: string;
                    };
                    headersHelper?: string;
                }[];
                owner?: {
                    name: string;
                    email?: string;
                    url?: string;
                };
            };
            installLocation?: string;
            autoUpdate?: boolean;
        };
    };
    strictKnownMarketplaces?: ({
        source: 'url';
        url: string;
        headers?: {
            [k: string]: string;
        };
        headersHelper?: string;
    } | {
        source: 'github';
        repo: string;
        ref?: string;
        path?: string;
        sparsePaths?: string[];
        skipLfs?: boolean;
    } | {
        source: 'git';
        url: string;
        ref?: string;
        path?: string;
        sparsePaths?: string[];
        skipLfs?: boolean;
    } | {
        source: 'npm';
        package: string;
        version?: string;
        registry?: string;
    } | {
        source: 'file';
        path: string;
    } | {
        source: 'directory';
        path: string;
    } | {
        source: 'skills-dir';
    } | {
        source: 'hostPattern';
        hostPattern: string;
    } | {
        source: 'pathPattern';
        pathPattern: string;
    } | {
        source: 'settings';
        name: string;
        plugins: {
            name: string;
            source: string | {
                source: 'npm';
                package: string;
                version?: string;
                registry?: string;
            } | {
                source: 'url';
                url: string;
                ref?: string;
                sha?: string;
            } | {
                source: 'github';
                repo: string;
                ref?: string;
                sha?: string;
            } | {
                source: 'git-subdir';
                url: string;
                path: string;
                ref?: string;
                sha?: string;
            } | {
                source: 'archive';
                url: string;
                sha256?: string;
            } | {
                source: 'command';
                command: string;
                timeout?: number;
                mode?: 'copy' | 'link';
            } | {
                source: 'unsupported';
                error?: string;
            };
            description?: string;
            version?: string;
            strict?: boolean;
            headers?: {
                [k: string]: string;
            };
            headersHelper?: string;
        }[];
        owner?: {
            name: string;
            email?: string;
            url?: string;
        };
    })[];
    allowedMarketplaces?: ({
        source: 'url';
        url: string;
        headers?: {
            [k: string]: string;
        };
        headersHelper?: string;
    } | {
        source: 'github';
        repo: string;
        ref?: string;
        path?: string;
        sparsePaths?: string[];
        skipLfs?: boolean;
    } | {
        source: 'git';
        url: string;
        ref?: string;
        path?: string;
        sparsePaths?: string[];
        skipLfs?: boolean;
    } | {
        source: 'npm';
        package: string;
        version?: string;
        registry?: string;
    } | {
        source: 'file';
        path: string;
    } | {
        source: 'directory';
        path: string;
    } | {
        source: 'skills-dir';
    } | {
        source: 'hostPattern';
        hostPattern: string;
    } | {
        source: 'pathPattern';
        pathPattern: string;
    } | {
        source: 'settings';
        name: string;
        plugins: {
            name: string;
            source: string | {
                source: 'npm';
                package: string;
                version?: string;
                registry?: string;
            } | {
                source: 'url';
                url: string;
                ref?: string;
                sha?: string;
            } | {
                source: 'github';
                repo: string;
                ref?: string;
                sha?: string;
            } | {
                source: 'git-subdir';
                url: string;
                path: string;
                ref?: string;
                sha?: string;
            } | {
                source: 'archive';
                url: string;
                sha256?: string;
            } | {
                source: 'command';
                command: string;
                timeout?: number;
                mode?: 'copy' | 'link';
            } | {
                source: 'unsupported';
                error?: string;
            };
            description?: string;
            version?: string;
            strict?: boolean;
            headers?: {
                [k: string]: string;
            };
            headersHelper?: string;
        }[];
        owner?: {
            name: string;
            email?: string;
            url?: string;
        };
    })[];
    blockedMarketplaces?: ({
        source: 'url';
        url: string;
        headers?: {
            [k: string]: string;
        };
        headersHelper?: string;
    } | {
        source: 'github';
        repo: string;
        ref?: string;
        path?: string;
        sparsePaths?: string[];
        skipLfs?: boolean;
    } | {
        source: 'git';
        url: string;
        ref?: string;
        path?: string;
        sparsePaths?: string[];
        skipLfs?: boolean;
    } | {
        source: 'npm';
        package: string;
        version?: string;
        registry?: string;
    } | {
        source: 'file';
        path: string;
    } | {
        source: 'directory';
        path: string;
    } | {
        source: 'skills-dir';
    } | {
        source: 'hostPattern';
        hostPattern: string;
    } | {
        source: 'pathPattern';
        pathPattern: string;
    } | {
        source: 'settings';
        name: string;
        plugins: {
            name: string;
            source: string | {
                source: 'npm';
                package: string;
                version?: string;
                registry?: string;
            } | {
                source: 'url';
                url: string;
                ref?: string;
                sha?: string;
            } | {
                source: 'github';
                repo: string;
                ref?: string;
                sha?: string;
            } | {
                source: 'git-subdir';
                url: string;
                path: string;
                ref?: string;
                sha?: string;
            } | {
                source: 'archive';
                url: string;
                sha256?: string;
            } | {
                source: 'command';
                command: string;
                timeout?: number;
                mode?: 'copy' | 'link';
            } | {
                source: 'unsupported';
                error?: string;
            };
            description?: string;
            version?: string;
            strict?: boolean;
            headers?: {
                [k: string]: string;
            };
            headersHelper?: string;
        }[];
        owner?: {
            name: string;
            email?: string;
            url?: string;
        };
    })[];
    disableCommandPluginSources?: boolean;
    disableSideloadFlags?: boolean;
    pluginSuggestionMarketplaces?: string[];
    forceLoginMethod?: 'claudeai' | 'console' | 'gateway';
    forceLoginGatewayUrl?: string;
    gatewayInternalNetworks?: string[];
    parentSettingsBehavior?: 'first-wins' | 'merge';
    managedSourcesBehavior?: 'first-wins' | 'merge';
    forceLoginOrgUUID?: string | string[];
    allowedProviders?: ('anthropic' | 'customEndpoint' | 'bedrock' | 'vertex' | 'foundry' | 'anthropicAws' | 'mantle' | 'gateway')[];
    forceRemoteSettingsRefresh?: boolean;
    otelHeadersHelper?: string;
    outputStyle?: string;
    viewMode?: 'default' | 'verbose' | 'focus';
    language?: string;
    skipWebFetchPreflight?: boolean;
    sandbox?: {
        enabled?: boolean;
        failIfUnavailable?: boolean;
        autoAllowBashIfSandboxed?: boolean;
        allowUnsandboxedCommands?: boolean;
        network?: {
            allowedDomains?: string[];
            deniedDomains?: string[];
            strictAllowlist?: boolean;
            allowManagedDomainsOnly?: boolean;
            allowUnixSockets?: string[];
            allowAllUnixSockets?: boolean;
            allowLocalBinding?: boolean;
            allowMachLookup?: string[];
            httpProxyPort?: number;
            socksProxyPort?: number;
            tlsTerminate?: {
                caCertPath?: string;
                caKeyPath?: string;
            };
        };
        filesystem?: {
            allowWrite?: string[];
            denyWrite?: string[];
            denyRead?: string[];
            allowRead?: string[];
            allowManagedReadPathsOnly?: boolean;
            disabled?: boolean;
        };
        credentials?: {
            files?: {
                path: string;
                mode: 'deny' | 'mask';
                extract?: string;
                onExtractNoMatch?: 'warn' | 'deny' | 'error';
                decode?: 'jwt';
                maskClaims?: string[];
                maskDuplicates?: boolean;
                injectHosts?: string[];
            }[];
            envVars?: {
                name: string;
                mode: 'deny' | 'mask';
                extract?: string;
                onExtractNoMatch?: 'warn' | 'deny' | 'error';
                decode?: 'jwt';
                maskClaims?: string[];
                injectHosts?: string[];
            }[];
            allowPlaintextInject?: boolean;
            awsPairs?: {
                accessKeyIdVar: string;
                secretAccessKeyVar: string;
                sessionTokenVar?: string;
            }[];
            sigv4?: {
                streaming?: 'deny' | 'passthrough';
                presigned?: 'deny' | 'passthrough';
                sigv4a?: 'deny' | 'passthrough';
            };
        };
        ignoreViolations?: {
            [k: string]: string[];
        };
        enableWeakerNestedSandbox?: boolean;
        enableWeakerNetworkIsolation?: boolean;
        allowAppleEvents?: boolean;
        excludedCommands?: string[];
        ripgrep?: {
            command: string;
            args?: string[];
        };
        bwrapPath?: string;
        socatPath?: string;
        [k: string]: unknown;
    };
    feedbackSurveyRate?: number;
    feedbackDrafts?: 'notify' | 'quiet' | 'off';
    spinnerTipsEnabled?: boolean;
    spinnerVerbs?: {
        mode: 'append' | 'replace';
        verbs: string[];
    };
    spinnerTipsOverride?: {
        excludeDefault?: boolean;
        tips?: (string | {
            [k: string]: unknown;
        })[];
        tipsFile?: string;
        label?: string;
        [k: string]: unknown;
    };
    syntaxHighlightingDisabled?: boolean;
    maxProseWidth?: number;
    spellcheck?: {
        enabled?: boolean;
        checker?: string;
        language?: string;
        color?: string;
        [k: string]: unknown;
    };
    terminalTitleFromRename?: boolean;
    promptCacheTtl?: '5m' | '1h';
    subagentPromptCacheTtl?: '5m' | '1h';
    alwaysThinkingEnabled?: boolean;
    effortLevel?: 'low' | 'medium' | 'high' | 'xhigh';
    maxEffortLevel?: 'low' | 'medium' | 'high' | 'xhigh' | 'max';
    modelSettings?: {
        [k: string]: {
            effortLevel?: 'low' | 'medium' | 'high' | 'xhigh';
            maxEffortLevel?: 'low' | 'medium' | 'high' | 'xhigh' | 'max';
            [k: string]: unknown;
        };
    };
    ultracode?: boolean;
    autoCompactWindow?: number;
    advisorModel?: string;
    fastMode?: boolean;
    fastModePerSessionOptIn?: boolean;
    promptSuggestionEnabled?: boolean;
    emojiCompletionEnabled?: boolean;
    showClearContextOnPlanAccept?: boolean;
    askUserQuestionTimeout?: '60s' | '5m' | '10m' | 'never';
    dialogExpiry?: '60s' | '5m' | '10m' | 'never';
    agent?: string;
    companyAnnouncements?: string[];
    pluginConfigs?: {
        [k: string]: {
            mcpServers?: {
                [k: string]: {
                    [k: string]: string | number | boolean | string[];
                };
            };
            options?: {
                [k: string]: string | number | boolean | string[];
            };
        } | {
            [k: string]: unknown;
        };
    };
    remote?: {
        defaultEnvironmentId?: string;
    };
    autoUpdatesChannel?: 'latest' | 'stable' | 'rc';
    minimumVersion?: string;
    requiredMinimumVersion?: string;
    requiredMaximumVersion?: string;
    plansDirectory?: string;
    tui?: 'default' | 'fullscreen';
    voice?: {
        enabled?: boolean;
        mode?: 'hold' | 'tap';
        autoSubmit?: boolean;
    };
    channelsEnabled?: boolean;
    allowedChannelPlugins?: {
        marketplace: string;
        plugin: string;
    }[];
    prefersReducedMotion?: boolean;
    timeFormat?: ('auto' | '12-hour' | '24-hour' | '24-hour-utc') | string;
    timeZone?: string;
    autoMemoryEnabled?: boolean;
    autoMemoryDirectory?: string;
    autoDreamEnabled?: boolean;
    showThinkingSummaries?: boolean;
    skipDangerousModePermissionPrompt?: boolean;
    disableAutoMode?: 'disable';
    sshConfigs?: {
        id: string;
        name: string;
        sshHost: string;
        sshPort?: number;
        sshIdentityFile?: string;
        startDirectory?: string;
    }[];
    claudeMd?: string;
    claudeMdExcludes?: string[];
    pluginTrustMessage?: string;
    theme?: ('auto' | 'dark' | 'light' | 'light-daltonized' | 'dark-daltonized' | 'light-ansi' | 'dark-ansi') | string;
    editorMode?: 'normal' | 'vim';
    keybindingFlavor?: 'classic' | 'readline';
    vimInsertModeRemaps?: {
        [k: string]: unknown;
    };
    verbose?: boolean;
    preferredNotifChannel?: 'auto' | 'iterm2' | 'terminal_bell' | 'iterm2_with_bell' | 'kitty' | 'ghostty' | 'notifications_disabled';
    autoCompactEnabled?: boolean;
    precomputeCompactionEnabled?: boolean;
    switchModelsOnFlag?: boolean;
    autoContinueAtUsageLimit?: boolean;
    autoScrollEnabled?: boolean;
    wheelScrollAccelerationEnabled?: boolean;
    fileCheckpointingEnabled?: boolean;
    showTurnDuration?: boolean;
    showMessageTimestamps?: boolean;
    terminalProgressBarEnabled?: boolean;
    todoFeatureEnabled?: boolean;
    teammateMode?: 'auto' | 'tmux' | 'iterm2' | 'in-process';
    remoteControlAtStartup?: boolean;
    isolatePeerMachines?: boolean;
    daemonColdStart?: 'transient' | 'ask';
    crossSessionInbound?: 'accept' | 'hold' | 'refuse';
    autoUploadSessions?: boolean;
    inputNeededNotifEnabled?: boolean;
    agentPushNotifEnabled?: boolean;
    disableDeepLinkRegistration?: 'disable';
    voiceEnabled?: boolean;
    defaultView?: 'chat' | 'transcript';
    [k: string]: unknown;
}
export declare type SettingSource = 'user' | 'project' | 'local';
export declare type SetupHookInput = BaseHookInput & {
    hook_event_name: 'Setup';
    trigger: 'init' | 'maintenance';
};
export declare type SetupHookSpecificOutput = {
    hookEventName: 'Setup';
    additionalContext?: string;
};
export declare type SlashCommand = {
    name: string;
    description: string;
    argumentHint: string;
    aliases?: string[];
    builtin?: boolean;
};
export declare interface SpareProcess extends AsyncDisposable {
    claim(params: {
        prompt: string | AsyncIterable<SDKUserMessage>;
        options: ClaimOptions;
    }): Query;
    readonly claimed: Promise<{
        cwd: string;
        sessionId: string;
        parkedMs?: number;
        sdkMcpSettled: boolean;
    }>;
    readonly exited: Promise<void>;
    close(): void;
}
export declare interface SpawnedProcess {
    stdin: Writable;
    stdout: Readable;
    readonly killed: boolean;
    readonly exitCode: number | null;
    readonly signalCode?: NodeJS.Signals | null;
    kill(signal: NodeJS.Signals): boolean;
    on(event: 'exit', listener: (code: number | null, signal: NodeJS.Signals | null) => void): void;
    on(event: 'error', listener: (error: Error) => void): void;
    once(event: 'exit', listener: (code: number | null, signal: NodeJS.Signals | null) => void): void;
    once(event: 'error', listener: (error: Error) => void): void;
    off(event: 'exit', listener: (code: number | null, signal: NodeJS.Signals | null) => void): void;
    off(event: 'error', listener: (error: Error) => void): void;
}
export declare interface SpawnOptions {
    command: string;
    args: string[];
    cwd?: string;
    env: {
        [envVar: string]: string | undefined;
    };
    signal: AbortSignal;
}
export declare function startup(_params?: {
    options?: Options;
    initializeTimeoutMs?: number;
}): Promise<WarmQuery>;
declare type StdoutMessage = coreTypes.SDKMessage | coreTypes.SDKActiveGoalMessage | SDKControlResponse | SDKControlRequest | SDKControlCancelRequest | SDKKeepAliveMessage;
export declare type StopFailureHookInput = BaseHookInput & {
    hook_event_name: 'StopFailure';
    error: SDKAssistantMessageError;
    error_details?: string;
    last_assistant_message?: string;
};
export declare type StopHookInput = BaseHookInput & {
    hook_event_name: 'Stop';
    stop_hook_active: boolean;
    last_assistant_message?: string;
    background_tasks?: BackgroundTaskSummary[];
    session_crons?: SessionCronSummary[];
};
export declare type StopHookSpecificOutput = {
    hookEventName: 'Stop';
    additionalContext?: string;
};
export declare type SubagentStartHookInput = BaseHookInput & {
    hook_event_name: 'SubagentStart';
    agent_id: string;
    agent_type: string;
};
export declare type SubagentStartHookSpecificOutput = {
    hookEventName: 'SubagentStart';
    additionalContext?: string;
};
export declare type SubagentStopHookInput = BaseHookInput & {
    hook_event_name: 'SubagentStop';
    stop_hook_active: boolean;
    agent_id: string;
    agent_transcript_path: string;
    agent_type: string;
    last_assistant_message?: string;
    background_tasks?: BackgroundTaskSummary[];
    session_crons?: SessionCronSummary[];
};
export declare type SubagentStopHookSpecificOutput = {
    hookEventName: 'SubagentStop';
    additionalContext?: string;
};
export declare type SyncHookJSONOutput = {
    continue?: boolean;
    suppressOutput?: boolean;
    stopReason?: string;
    decision?: 'approve' | 'block';
    systemMessage?: string;
    terminalSequence?: string;
    reason?: string;
    hookSpecificOutput?: PreToolUseHookSpecificOutput | UserPromptSubmitHookSpecificOutput | UserPromptExpansionHookSpecificOutput | SessionStartHookSpecificOutput | SetupHookSpecificOutput | PreModelSwitchHookSpecificOutput | PostModelSwitchHookSpecificOutput | SubagentStartHookSpecificOutput | PostToolUseHookSpecificOutput | PostToolUseFailureHookSpecificOutput | PostToolBatchHookSpecificOutput | StopHookSpecificOutput | SubagentStopHookSpecificOutput | PermissionDeniedHookSpecificOutput | NotificationHookSpecificOutput | PermissionRequestHookSpecificOutput | ElicitationHookSpecificOutput | ElicitationResultHookSpecificOutput | CwdChangedHookSpecificOutput | FileChangedHookSpecificOutput | WorktreeCreateHookSpecificOutput | MessageDisplayHookSpecificOutput;
};
export declare const SYSTEM_PROMPT_DYNAMIC_BOUNDARY = "__SYSTEM_PROMPT_DYNAMIC_BOUNDARY__";
export declare function tagSession(_sessionId: string, _tag: string | null, _options?: SessionMutationOptions): Promise<void>;
export declare type TaskCompletedHookInput = BaseHookInput & {
    hook_event_name: 'TaskCompleted';
    task_id: string;
    task_subject: string;
    task_description?: string;
    teammate_name?: string;
    team_name?: string;
};
export declare type TaskCreatedHookInput = BaseHookInput & {
    hook_event_name: 'TaskCreated';
    task_id: string;
    task_subject: string;
    task_description?: string;
    teammate_name?: string;
    team_name?: string;
};
export declare type TeammateIdleHookInput = BaseHookInput & {
    hook_event_name: 'TeammateIdle';
    teammate_name: string;
    team_name: string;
};
export declare type TerminalReason = 'blocking_limit' | 'rapid_refill_breaker' | 'prompt_too_long' | 'image_error' | 'model_error' | 'api_error' | 'malformed_tool_use_exhausted' | 'aborted_streaming' | 'aborted_tools' | 'stop_hook_prevented' | 'hook_stopped' | 'tool_deferred' | 'max_turns' | 'background_requested' | 'completed' | 'budget_exhausted' | 'structured_output_retry_exhausted' | 'tool_deferred_unavailable' | 'turn_setup_failed';
export declare type ThinkingAdaptive = {
    type: 'adaptive';
    display?: 'summarized' | 'omitted';
};
export declare type ThinkingConfig = ThinkingAdaptive | ThinkingEnabled | ThinkingDisabled;
export declare type ThinkingDisabled = {
    type: 'disabled';
};
export declare type ThinkingEnabled = {
    type: 'enabled';
    budgetTokens?: number;
    display?: 'summarized' | 'omitted';
};
export declare function tool<Schema extends AnyZodRawShape>(_name: string, _description: string, _inputSchema: Schema, _handler: (args: InferShape<Schema>, extra: unknown) => Promise<CallToolResult>, _extras?: {
    annotations?: ToolAnnotations;
    searchHint?: string;
    alwaysLoad?: boolean;
}): SdkMcpToolDefinition<Schema>;
export declare type ToolConfig = {
    askUserQuestion?: {
        previewFormat?: 'markdown' | 'html';
    };
};
export declare interface Transport {
    write(data: string): void | Promise<void>;
    close(): void;
    isReady(): boolean;
    readMessages(): AsyncGenerator<StdoutMessage, void, unknown>;
    expectControlResponse?(requestId: string): void;
    markDelivered?(message: object): void;
    endInput(): void;
    waitForExit?(): Promise<void>;
    [Symbol.dispose]?(): void;
}
export declare const USAGE_LIMIT_ERROR_PREFIXES: readonly ["You've hit your", "You've reached your", "You're out of usage credits", 'Your org is out of usage · add funds to continue', 'Your org is out of usage · contact your admin', "Your seat type doesn't include usage credits", "Your seat type doesn't include usage", 'Your usage allocation has been disabled by your admin', "Your group's usage limit is set to $0", 'Fable 5 requires usage credits', "You're out of extra usage", "Your seat type doesn't include extra usage"];
export declare const USAGE_TRANSITION_PREFIXES: readonly ["You're now using usage credits", "You're now using your usage allocation", 'Now using your usage allocation', 'Now using usage credits', "You're now using extra usage", 'Now using extra usage'];
export declare const USAGE_WARNING_PREFIXES: readonly ["You've used", "You're close to"];
export declare type UserDialogRequest = {
    dialogKind: string;
    payload: Record<string, unknown>;
    toolUseID?: string;
};
export declare type UserDialogResult = {
    behavior: 'completed';
    result: unknown;
} | {
    behavior: 'cancelled';
};
export declare type UserPromptExpansionHookInput = BaseHookInput & {
    hook_event_name: 'UserPromptExpansion';
    expansion_type: 'slash_command' | 'mcp_prompt';
    command_name: string;
    command_args: string;
    command_source?: string;
    prompt: string;
};
export declare type UserPromptExpansionHookSpecificOutput = {
    hookEventName: 'UserPromptExpansion';
    additionalContext?: string;
    suppressOriginalPrompt?: boolean;
};
export declare type UserPromptSubmitHookInput = BaseHookInput & {
    hook_event_name: 'UserPromptSubmit';
    prompt: string;
    source?: 'user' | 'sdk' | 'system' | 'loop_wakeup' | 'schedule_wakeup' | 'poll_event';
    session_title?: string;
};
export declare type UserPromptSubmitHookSpecificOutput = {
    hookEventName: 'UserPromptSubmit';
    additionalContext?: string;
    sessionTitle?: string;
    suppressOriginalPrompt?: boolean;
};
export declare interface WarmQuery extends AsyncDisposable {
    query(prompt: string | AsyncIterable<SDKUserMessage>): Query;
    close(): void;
}
export declare type WorktreeCreateHookInput = BaseHookInput & {
    hook_event_name: 'WorktreeCreate';
    name: string;
};
export declare type WorktreeCreateHookSpecificOutput = {
    hookEventName: 'WorktreeCreate';
    worktreePath: string;
};
export declare type WorktreeRemoveHookInput = BaseHookInput & {
    hook_event_name: 'WorktreeRemove';
    worktree_path: string;
};
export { }
