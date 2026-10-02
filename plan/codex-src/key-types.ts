// Curated excerpt of Codex app-server protocol TypeScript bindings.
// Source: `codex app-server generate-ts --experimental --out <dir>` with codex-cli 0.159.3 (generated 2026-10-02).
// Boilerplate imports removed; types are verbatim otherwise. Regenerate per Codex version: the protocol evolves weekly.

// ---- InitializeParams.ts
export type InitializeParams = { clientInfo: ClientInfo, capabilities: InitializeCapabilities | null, };
// ---- ClientInfo.ts
export type ClientInfo = { name: string, title: string | null, version: string, };
// ---- InitializeCapabilities.ts
/**
 * Client-declared capabilities negotiated during initialize.
 */
export type InitializeCapabilities = {
/**
 * Use explicit gateway OAuth login instead of automatic browser authorization.
 * Applies to this app-server's gateway runtime; later connections cannot undo it.
 */
explicitGatewayOauth?: boolean,
/**
 * Opt into receiving experimental API methods and fields.
 */
experimentalApi: boolean,
/**
 * Opt into `attestation/generate` requests for upstream `x-oai-attestation`.
 */
requestAttestation: boolean,
/**
 * Legacy opt-in for the `openai/form` MCP extension.
 *
 * New clients should declare `openai/form` in [`Self::extensions`].
 */
mcpServerOpenaiFormElicitation?: boolean,
/**
 * Exact notification method names that should be suppressed for this
 * connection (for example `thread/started`).
 */
optOutNotificationMethods?: Array<string> | null,
/**
 * MCP extension settings declared by the app-server client.
 */
extensions?: { [key in string]?: JsonValue } | null, };
// ---- InitializeResponse.ts
export type InitializeResponse = { userAgent: string,
/**
 * Absolute path to the server's $CODEX_HOME directory.
 */
codexHome: AbsolutePathBuf,
/**
 * Platform family for the running app-server target, for example
 * `"unix"` or `"windows"`.
 */
platformFamily: string,
/**
 * Operating system for the running app-server target, for example
 * `"macos"`, `"linux"`, or `"windows"`.
 */
platformOs: string, };
// ---- v2/ThreadStartParams.ts
export type ThreadStartParams = { model?: string | null, modelProvider?: string | null,
/**
 * Allow a provider with an authoritative static model catalog to replace an unavailable
 * requested model with its default.
 */
allowProviderModelFallback?: boolean, serviceTier?: string | null | null, cwd?: string | null,
/**
 * Replace the thread's runtime workspace roots. Paths must be absolute.
 */
runtimeWorkspaceRoots?: Array<AbsolutePathBuf> | null, approvalPolicy?: AskForApproval | null,
/**
 * Override where approval requests are routed for review on this thread
 * and subsequent turns.
 */
approvalsReviewer?: ApprovalsReviewer | null, sandbox?: SandboxMode | null,
/**
 * Named profile id for this thread. Cannot be combined with `sandbox`.
 */
permissions?: string | null, config?: { [key in string]?: JsonValue } | null, serviceName?: string | null, baseInstructions?: string | null, developerInstructions?: string | null,
/**
 * @deprecated `friendly` and `pragmatic` no longer select a style.
 */
personality?: Personality | null,
/**
 * @deprecated Ignored. Use Ultra reasoning effort for proactive multi-agent behavior.
 */
multiAgentMode?: MultiAgentMode | null, ephemeral?: boolean | null,
/**
 * Persisted thread history contract to use for this new thread.
 */
historyMode?: ThreadHistoryMode | null, sessionStartSource?: ThreadStartSource | null,
/**
 * Optional client-supplied analytics source classification for this thread.
 */
threadSource?: ThreadSource | null,
/**
 * Optional project identity for this new thread. Durable threads persist
 * the assignment; ephemeral threads expose it only in live responses.
 */
projectId?: string | null,
/**
 * Initial Daybreak choice for this persistent thread. Omitted or null
 * leaves it unset. This does not select a turn's `cyberAccessProgram`
 * or grant access. Not supported for ephemeral threads.
 */
daybreakEnabled?: boolean | null,
/**
 * Optional sticky environments for this thread.
 *
 * Omitted selects the default environment when environment access is
 * enabled. Empty disables environment access for turns that do not
 * provide a turn override. Non-empty selects the first environment as the
 * current turn environment.
 */
environments?: Array<TurnEnvironmentParams> | null, dynamicTools?: Array<DynamicToolSpec> | null,
/**
 * Capability roots selected for this thread by the hosting platform.
 */
selectedCapabilityRoots?: Array<SelectedCapabilityRoot> | null,
/**
 * Test-only experimental field used to validate experimental gating and
 * schema filtering behavior in a stable way.
 */
mockExperimentalField?: string | null,
/**
 * If true, opt into emitting raw Responses API items on the event stream.
 * This is for internal use only (e.g. Codex Cloud).
 */
experimentalRawEvents?: boolean, };
// ---- v2/ThreadStartResponse.ts
export type ThreadStartResponse = { thread: Thread, model: string, modelProvider: string, serviceTier: string | null,
/**
 * Saved list of disabled plugin IDs. Does not yet filter plugin capabilities.
 */
disabledPluginIds: Array<string>, cwd: AbsolutePathBuf,
/**
 * Thread-scoped runtime workspace roots used to materialize
 * `:workspace_roots`.
 */
runtimeWorkspaceRoots: Array<AbsolutePathBuf>,
/**
 * Environment-native paths to instruction source files currently loaded for this thread.
 */
instructionSources: Array<LegacyAppPathString>, approvalPolicy: AskForApproval,
/**
 * Reviewer currently used for approval requests on this thread.
 */
approvalsReviewer: ApprovalsReviewer,
/**
 * Legacy sandbox policy retained for compatibility. Experimental clients
 * should prefer `activePermissionProfile` for profile provenance.
 */
sandbox: SandboxPolicy,
/**
 * Named or implicit built-in profile that produced the active
 * permissions, when known.
 */
activePermissionProfile: ActivePermissionProfile | null, reasoningEffort: ReasoningEffort | null,
/**
 * @deprecated Always `explicitRequestOnly`. Use `reasoningEffort` for Ultra behavior.
 */
multiAgentMode: MultiAgentMode, };
// ---- v2/Thread.ts
export type Thread = {
/**
 * Identifier for this thread. Codex-generated thread IDs are UUIDv7.
 */
id: string,
/**
 * Current environments for a loaded thread, in priority order, primary first.
 * `null` means the thread is not loaded or the server does not expose its selection.
 * An empty list means no environments are selected. This does not report connection status.
 */
environments: Array<ThreadEnvironment> | null,
/**
 * Optional implementation-specific thread data.
 */
extra: ThreadExtra | null,
/**
 * Session id shared by threads that belong to the same session tree.
 */
sessionId: string,
/**
 * Source thread id when this thread was created by forking another thread.
 */
forkedFromId: string | null,
/**
 * The ID of the parent thread. This will only be set if this thread is a subagent.
 */
parentThreadId: string | null,
/**
 * Usually the first user message in the thread, if available.
 */
preview: string,
/**
 * Whether the thread is ephemeral and should not be materialized on disk.
 */
ephemeral: boolean,
/**
 * The independently persisted section selected for this thread, if any.
 */
section: ThreadSection | null,
/**
 * Unix timestamp in seconds when the thread entered its current section.
 */
sectionEnteredAt: number | null,
/**
 * Canonical project assignment owned by app-server, if any.
 */
projectId: string | null,
/**
 * Persisted thread history contract selected when this thread was created.
 */
historyMode: ThreadHistoryMode,
/**
 * Model provider used for this thread (for example, 'openai').
 */
modelProvider: string,
/**
 * Current configured model when loaded, otherwise the latest persisted model.
 * Null when unavailable. This is not per-turn execution telemetry.
 */
model: string | null,
/**
 * Current configured reasoning effort when loaded, otherwise the latest persisted effort.
 * Null when unset or unavailable. This is not per-turn execution telemetry.
 */
reasoningEffort: ReasoningEffort | null,
/**
 * Unix timestamp (in seconds) when the thread was created.
 */
createdAt: number,
/**
 * Unix timestamp (in seconds) when the thread was last updated.
 */
updatedAt: number,
/**
 * Unix timestamp (in seconds) used for thread recency ordering.
 */
recencyAt: number | null,
/**
 * Current runtime status for the thread.
 */
status: ThreadStatus,
/**
 * [UNSTABLE] Path to the thread on disk.
 */
path: string | null,
/**
 * Working directory captured for the thread.
 */
cwd: AbsolutePathBuf,
/**
 * Version of the CLI that created the thread.
 */
cliVersion: string,
/**
 * Originator recorded when the thread was created, independent of its current client or executor.
 * Null when the recorded originator is unavailable.
 */
originator: string | null,
/**
 * Origin of the thread (CLI, VSCode, codex exec, codex app-server, etc.).
 */
source: SessionSource,
/**
 * Whether the app server accepts direct turn input for this loaded thread.
 * `None` means the capability is unavailable, such as for an unloaded stored thread.
 */
canAcceptDirectInput: boolean | null,
/**
 * Optional analytics source classification for this thread.
 */
threadSource: ThreadSource | null,
/**
 * Optional random unique nickname assigned to an AgentControl-spawned sub-agent.
 */
agentNickname: string | null,
/**
 * Optional role (agent_role) assigned to an AgentControl-spawned sub-agent.
 */
agentRole: string | null,
/**
 * Optional Git metadata captured when the thread was created.
 */
gitInfo: GitInfo | null,
/**
 * Optional user-facing thread title.
 */
name: string | null,
/**
 * Saved Daybreak choice, independent of turn execution. Null if unset.
 */
daybreakEnabled: boolean | null,
/**
 * Only populated on `thread/resume`, `thread/fork`, and `thread/read`
 * (when `includeTurns` is true) responses.
 * For all other responses and notifications returning a Thread,
 * the turns field will be an empty list.
 */
turns: Array<Turn>, };
// ---- v2/ThreadStatus.ts
export type ThreadStatus = { "type": "notLoaded" } | { "type": "idle" } | { "type": "systemError" } | { "type": "active", activeFlags: Array<ThreadActiveFlag>, };
// ---- v2/ThreadActiveFlag.ts
export type ThreadActiveFlag = "waitingOnApproval" | "waitingOnUserInput";
// ---- v2/ThreadResumeParams.ts
/**
 * There are three ways to resume a thread:
 * 1. By thread_id: load the thread from disk by thread_id and resume it.
 * 2. By history: instantiate the thread from memory and resume it.
 * 3. By path: load the thread from disk by path and resume it.
 *
 * For non-running threads, the precedence is: history > non-empty path > thread_id.
 * If using history or a non-empty path for a non-running thread, the thread_id
 * param will be ignored.
 *
 * If thread_id identifies a running thread, app-server rejoins that thread and
 * treats a non-empty path as a consistency check against the active rollout path.
 * Empty string path values are treated as absent.
 *
 * Prefer using thread_id whenever possible.
 */
export type ThreadResumeParams = { threadId: string,
/**
 * [UNSTABLE] FOR CODEX CLOUD - DO NOT USE.
 * If specified, the thread will be resumed with the provided history
 * instead of loaded from disk.
 */
history?: Array<ResponseItem> | null,
/**
 * [UNSTABLE] Specify the rollout path to resume from.
 * If specified for a non-running thread, the thread_id param will be ignored.
 * If thread_id identifies a running thread, the path must match the active
 * rollout path.
 */
path?: string | null,
/**
 * Configuration overrides for the resumed thread, if any.
 */
model?: string | null, modelProvider?: string | null, serviceTier?: string | null | null, cwd?: string | null,
/**
 * Replace the thread's runtime workspace roots. Paths must be absolute.
 */
runtimeWorkspaceRoots?: Array<AbsolutePathBuf> | null, approvalPolicy?: AskForApproval | null,
/**
 * Override where approval requests are routed for review on this thread
 * and subsequent turns.
 */
approvalsReviewer?: ApprovalsReviewer | null, sandbox?: SandboxMode | null,
/**
 * Named profile id for the resumed thread. Cannot be combined with
 * `sandbox`.
 */
permissions?: string | null, config?: { [key in string]?: JsonValue } | null, baseInstructions?: string | null, developerInstructions?: string | null,
/**
 * @deprecated `friendly` and `pragmatic` no longer select a style.
 * Changing this does not rewrite the thread's existing instructions.
 */
personality?: Personality | null,
/**
 * When true, return only thread metadata and live-resume state without
 * populating `thread.turns`. This is useful when the client plans to call
 * `thread/turns/list` immediately after resuming. Full-history hydration
 * is deprecated for paginated threads; use this with `thread/turns/list`
 * and `thread/items/list` instead.
 */
excludeTurns?: boolean,
/**
 * When present, include a `thread/turns/list` page in the resume response
 * so clients can bootstrap recent turns without a second request.
 */
initialTurnsPage?: ThreadResumeInitialTurnsPageParams | null, };
// ---- v2/ThreadForkParams.ts
/**
 * There are two ways to fork a thread:
 * 1. By thread_id: load the thread from disk by thread_id and fork it into a new thread.
 * 2. By path: load the thread from disk by path and fork it into a new thread.
 *
 * If using a non-empty path, the thread_id param will be ignored.
 * Empty string path values are treated as absent.
 *
 * Prefer using thread_id whenever possible.
 */
export type ThreadForkParams = { threadId: string,
/**
 * Optional last turn id to fork through, inclusive.
 *
 * When specified, turns after `last_turn_id` are omitted from the fork.
 * The referenced turn cannot be in progress.
 */
lastTurnId?: string | null,
/**
 * Optional turn id to fork before, excluding that turn and all later turns.
 * Cannot be combined with `last_turn_id`.
 */
beforeTurnId?: string | null,
/**
 * [UNSTABLE] Specify the rollout path to fork from.
 * If specified, the thread_id param will be ignored.
 */
path?: string | null,
/**
 * Configuration overrides for the forked thread, if any.
 */
model?: string | null, modelProvider?: string | null, serviceTier?: string | null | null, cwd?: string | null,
/**
 * Replace the thread's runtime workspace roots. Paths must be absolute.
 */
runtimeWorkspaceRoots?: Array<AbsolutePathBuf> | null, approvalPolicy?: AskForApproval | null,
/**
 * Override where approval requests are routed for review on this thread
 * and subsequent turns.
 */
approvalsReviewer?: ApprovalsReviewer | null, sandbox?: SandboxMode | null,
/**
 * Named profile id for the forked thread. Cannot be combined with
 * `sandbox`.
 */
permissions?: string | null, config?: { [key in string]?: JsonValue } | null, baseInstructions?: string | null, developerInstructions?: string | null, ephemeral?: boolean,
/**
 * Optional client-supplied analytics source classification for this forked thread.
 */
threadSource?: ThreadSource | null,
/**
 * When true, return only thread metadata and live fork state without
 * populating `thread.turns`. This is useful when the client plans to call
 * `thread/turns/list` immediately after forking. Full-history hydration
 * is deprecated for paginated threads; use this with `thread/turns/list`
 * and `thread/items/list` instead.
 */
excludeTurns?: boolean,
/**
 * When true, carry the source thread's current goal into the fork without
 * starting its initial automatic continuation. The next explicit turn owns
 * the goal lifecycle, and normal automatic continuation resumes after it.
 */
deferGoalContinuation?: boolean, };
// ---- v2/ThreadListParams.ts
export type ThreadListParams = {
/**
 * Opaque pagination cursor returned by a previous call.
 */
cursor?: string | null,
/**
 * Optional page size; defaults to a reasonable server-side value.
 */
limit?: number | null,
/**
 * Optional sort key; defaults to created_at.
 */
sortKey?: ThreadSortKey | null,
/**
 * Optional sort direction; defaults to descending (newest first).
 */
sortDirection?: SortDirection | null,
/**
 * Optional provider filter; when set, only sessions recorded under these
 * providers are returned. When present but empty, includes all providers.
 */
modelProviders?: Array<string> | null,
/**
 * Optional source filter; when set, only sessions from these source kinds
 * are returned. When omitted or empty, defaults to interactive sources.
 */
sourceKinds?: Array<ThreadSourceKind> | null,
/**
 * Optional originator allowlist, matching any supplied value exactly.
 * Supported by hosted backends only; the local app-server rejects a nonempty list.
 * Omitted or empty lists leave originators unrestricted.
 */
originators?: Array<string> | null,
/**
 * Optional archived filter; when set to true, only archived threads are returned.
 * If false or null, only non-archived threads are returned.
 */
archived?: boolean | null,
/**
 * Omit to include every section, set to `null` for unsectioned threads,
 * or provide a section ID to return only threads in that section.
 */
sectionId?: string | null,
/**
 * Omit to include every project, set to null for unassigned threads,
 * or provide a project ID to return only threads in that project.
 */
projectId?: string | null,
/**
 * Optional cwd filter or filters; when set, only threads whose session cwd
 * exactly matches one of these paths are returned.
 */
cwd?: string | Array<string> | null,
/**
 * If true, return from the state DB without scanning JSONL rollouts to
 * repair thread metadata. Omitted or false preserves scan-and-repair
 * behavior.
 */
useStateDbOnly?: boolean,
/**
 * Optional substring filter for the extracted thread title.
 */
searchTerm?: string | null,
/**
 * Optional direct parent thread filter. Mutually exclusive with `ancestorThreadId`.
 */
parentThreadId?: string | null,
/**
 * Optional ancestor thread filter. Returns spawned descendants at any depth, excluding the
 * ancestor itself. Mutually exclusive with `parentThreadId`.
 */
ancestorThreadId?: string | null, };
// ---- v2/ThreadRevertParams.ts
/**
 * Replace a paginated thread's durable history with the prefix before one turn.
 *
 * This only changes persisted conversation history. It does not revert local file changes.
 */
export type ThreadRevertParams = { threadId: string,
/**
 * Turn excluded from the replacement history, together with every later turn.
 */
beforeTurnId: string, };
// ---- v2/TurnStartParams.ts
export type TurnStartParams = { threadId: string,
/**
 * Replace this thread's disabled plugin IDs.
 * Omitted/null preserves the list; [] clears it.
 */
disabledPluginIds?: Array<string> | null, clientUserMessageId?: string | null, input: Array<UserInput>,
/**
 * Optional source classification for the caller that starts this turn.
 * Ignored when this request steers an already-active turn.
 */
turnTrigger?: string | null, toolOutput?: TurnToolOutput | null,
/**
 * Optional metadata to enrich Codex's ResponsesAPI turn metadata.
 *
 * Entries are flattened into the JSON string sent as
 * `client_metadata["x-codex-turn-metadata"]` on ResponsesAPI HTTP and websocket requests.
 *
 * They are not sent as top-level ResponsesAPI `client_metadata` keys, and reserved keys
 * such as `session_id`, `thread_id`, `turn_id`, and `window_id` cannot be overridden.
 */
responsesapiClientMetadata?: { [key in string]?: string } | null,
/**
 * Optional client-provided context fragments keyed by an opaque source identifier.
 */
additionalContext?: { [key in string]?: AdditionalContextEntry } | null,
/**
 * Optional environments for this turn and subsequent turns.
 *
 * Omitted uses the thread sticky environments. Empty disables
 * environment access for this turn. Non-empty selects the first
 * environment as the current turn environment for this turn.
 */
environments?: Array<TurnEnvironmentParams> | null,
/**
 * Override the working directory for this turn and subsequent turns.
 */
cwd?: string | null,
/**
 * Replace the thread's runtime workspace roots for this turn and
 * subsequent turns. Paths must be absolute.
 */
runtimeWorkspaceRoots?: Array<AbsolutePathBuf> | null,
/**
 * Override the approval policy for this turn and subsequent turns.
 */
approvalPolicy?: AskForApproval | null,
/**
 * Override where approval requests are routed for review on this turn and
 * subsequent turns.
 */
approvalsReviewer?: ApprovalsReviewer | null,
/**
 * Override the sandbox policy for this turn and subsequent turns.
 */
sandboxPolicy?: SandboxPolicy | null,
/**
 * Select a named permissions profile id for this turn and subsequent
 * turns. Cannot be combined with `sandboxPolicy`.
 */
permissions?: string | null,
/**
 * Override the model for this turn and subsequent turns.
 */
model?: string | null,
/**
 * Override the service tier for this turn and subsequent turns.
 */
serviceTier?: string | null | null,
/**
 * Override the service tier only when this request starts a new turn.
 * Use "default" for standard speed. Omitted or null inherits the thread's tier.
 * Does not change the thread's tier or a turn being steered.
 */
serviceTierForTurn?: string | null,
/**
 * Override the reasoning effort for this turn and subsequent turns.
 */
effort?: ReasoningEffort | null,
/**
 * Override the reasoning summary for this turn and subsequent turns.
 */
summary?: ReasoningSummary | null,
/**
 * @deprecated `friendly` and `pragmatic` no longer select a style.
 * Changing this does not rewrite the thread's existing instructions.
 */
personality?: Personality | null,
/**
 * Optional JSON Schema used to constrain the final assistant message for
 * this turn.
 */
outputSchema?: JsonValue | null,
/**
 * EXPERIMENTAL - Set a pre-set collaboration mode.
 * Takes precedence over model, reasoning_effort, and developer instructions if set.
 *
 * For `collaboration_mode.settings.developer_instructions`, `null` means
 * "use the built-in instructions for the selected mode".
 */
collaborationMode?: CollaborationMode | null,
/**
 * @deprecated Ignored. Use `effort: "ultra"` for proactive multi-agent behavior.
 */
multiAgentMode?: MultiAgentMode | null,
/**
 * EXPERIMENTAL - Request a workspace-authorized cyber program for this
 * turn. Omission preserves automatic behavior. This does not grant access.
 */
cyberAccessProgram?: CyberAccessProgram | null, };
// ---- v2/TurnStartResponse.ts
export type TurnStartResponse = { turn: Turn, };
// ---- v2/Turn.ts
export type Turn = {
/**
 * Identifier for this turn. Codex-generated turn IDs are UUIDv7.
 */
id: string,
/**
 * Thread items currently included in this turn payload.
 */
items: Array<ThreadItem>,
/**
 * Describes how much of `items` has been loaded for this turn.
 */
itemsView: TurnItemsView, status: TurnStatus,
/**
 * Error associated with a failed or interrupted turn.
 */
error: TurnError | null,
/**
 * Unix timestamp (in seconds) when the turn started.
 */
startedAt: number | null,
/**
 * Unix timestamp (in seconds) when the turn completed.
 */
completedAt: number | null,
/**
 * Duration between turn start and completion in milliseconds, if known.
 */
durationMs: number | null, };
// ---- v2/TurnStatus.ts
export type TurnStatus = "completed" | "interrupted" | "failed" | "inProgress";
// ---- v2/TurnError.ts
export type TurnError = { message: string, codexErrorInfo: CodexErrorInfo | null, additionalDetails: string | null,
/**
 * Optional public explanation and continuation instruction for a misalignment block.
 */
misalignment: MisalignmentErrorDetails | null, };
// ---- v2/CodexErrorInfo.ts
/**
 * This translation layer make sure that we expose codex error code in camel case.
 *
 * When an upstream HTTP status is available (for example, from the Responses API or a provider),
 * it is forwarded in `httpStatusCode` on the relevant `codexErrorInfo` variant.
 */
export type CodexErrorInfo = "contextWindowExceeded" | "sessionBudgetExceeded" | "usageLimitExceeded" | "rateLimitExceeded" | "flexUnavailable" | "serverOverloaded" | "cyberPolicy" | "misalignmentPolicyViolation" | "tooManyDenials" | { "httpConnectionFailed": { httpStatusCode: number | null, } } | { "responseStreamConnectionFailed": { httpStatusCode: number | null, } } | "internalServerError" | "unauthorized" | "badRequest" | "threadRollbackFailed" | "sandboxError" | { "responseStreamDisconnected": { httpStatusCode: number | null, } } | { "responseTooManyFailedAttempts": { httpStatusCode: number | null, } } | { "activeTurnNotSteerable": { turnKind: NonSteerableTurnKind, } } | "other";
// ---- v2/ErrorNotification.ts
export type ErrorNotification = { error: TurnError, willRetry: boolean, threadId: string, turnId: string, };
// ---- v2/UserInput.ts
export type UserInput = { "type": "text", text: string,
/**
 * UI-defined spans within `text` used to render or persist special elements.
 */
text_elements: Array<TextElement>, } | { "type": "image", detail?: ImageDetail, } & ({ url: string, } | { fileId: string, }) | { "type": "localImage", detail?: ImageDetail, path: string, } | { "type": "audio", url: string, } | { "type": "localAudio", path: string, } | { "type": "skill", name: string, path: string, } | { "type": "mention", name: string, path: string, };
// ---- v2/TextElement.ts
export type TextElement = {
/**
 * Byte range in the parent `text` buffer that this element occupies.
 */
byteRange: ByteRange,
/**
 * Optional human-readable placeholder for the element, displayed in the UI.
 */
placeholder: string | null, };
// ---- v2/TurnSteerParams.ts
export type TurnSteerParams = { threadId: string, clientUserMessageId?: string | null, input: Array<UserInput>,
/**
 * Optional metadata to enrich Codex's ResponsesAPI turn metadata.
 *
 * Entries are flattened into the JSON string sent as
 * `client_metadata["x-codex-turn-metadata"]` on ResponsesAPI HTTP and websocket requests.
 *
 * They are not sent as top-level ResponsesAPI `client_metadata` keys, and reserved keys
 * such as `session_id`, `thread_id`, `turn_id`, and `window_id` cannot be overridden.
 */
responsesapiClientMetadata?: { [key in string]?: string } | null,
/**
 * Optional client-provided context fragments keyed by an opaque source identifier.
 */
additionalContext?: { [key in string]?: AdditionalContextEntry } | null,
/**
 * Required active turn id precondition. The request fails when it does not
 * match the currently active turn.
 */
expectedTurnId: string, };
// ---- v2/TurnSteerResponse.ts
export type TurnSteerResponse = { turnId: string, };
// ---- v2/TurnInterruptParams.ts
export type TurnInterruptParams = { threadId: string, turnId: string, };
// ---- v2/TurnSettingsUpdateParams.ts
/**
 * Experimental settings changes for one running turn, not future turns.
 * Unsupported fields are rejected rather than silently ignored.
 * Any live task kind may accept publication. Child sessions and consumers of
 * frozen initial settings are unchanged.
 */
export type TurnSettingsUpdateParams = { threadId: string, turnId: string,
/**
 * Changes the active turn's reviewer without changing future thread settings.
 * Already captured steps and pending approvals retain their original reviewer.
 */
approvalsReviewer?: ApprovalsReviewer | null,
/**
 * Omission or `null` leaves the model unchanged.
 */
model?: string | null,
/**
 * Omission or `null` leaves the effort unchanged.
 */
effort?: ReasoningEffort | null,
/**
 * Omission or `null` leaves the summary preference unchanged.
 */
summary?: ReasoningSummary | null,
/**
 * `null` clears the requested tier; omission leaves it unchanged.
 */
serviceTier?: string | null | null, };
// ---- v2/ThreadSettingsUpdateParams.ts
export type ThreadSettingsUpdateParams = { threadId: string,
/**
 * Replace this thread's disabled plugin IDs.
 * Omitted/null preserves the list; [] clears it.
 */
disabledPluginIds?: Array<string> | null,
/**
 * Override the working directory for subsequent turns.
 */
cwd?: string | null,
/**
 * Override the approval policy for subsequent turns.
 */
approvalPolicy?: AskForApproval | null,
/**
 * Override where approval requests are routed for subsequent turns.
 */
approvalsReviewer?: ApprovalsReviewer | null,
/**
 * Override the sandbox policy for subsequent turns.
 */
sandboxPolicy?: SandboxPolicy | null,
/**
 * Select a named permissions profile id for subsequent turns. Cannot be
 * combined with `sandboxPolicy`.
 */
permissions?: string | null,
/**
 * Override the model for subsequent turns.
 */
model?: string | null,
/**
 * Override the service tier for subsequent turns. `null` clears the
 * current service tier; omission leaves it unchanged.
 */
serviceTier?: string | null | null,
/**
 * Override the reasoning effort for subsequent turns.
 */
effort?: ReasoningEffort | null,
/**
 * Override the reasoning summary for subsequent turns.
 */
summary?: ReasoningSummary | null,
/**
 * EXPERIMENTAL - Set a pre-set collaboration mode for subsequent turns.
 *
 * For `collaboration_mode.settings.developer_instructions`, `null` means
 * "use the built-in instructions for the selected mode".
 */
collaborationMode?: CollaborationMode | null,
/**
 * @deprecated Ignored. Use `effort: "ultra"` for proactive multi-agent behavior.
 */
multiAgentMode?: MultiAgentMode | null,
/**
 * @deprecated `friendly` and `pragmatic` no longer select a style.
 * Changing this does not rewrite the thread's existing instructions.
 */
personality?: Personality | null, };
// ---- v2/ThreadSettings.ts
export type ThreadSettings = {
/**
 * Saved list of disabled plugin IDs. Does not yet filter plugin capabilities.
 */
disabledPluginIds: Array<string>, cwd: AbsolutePathBuf, approvalPolicy: AskForApproval, approvalsReviewer: ApprovalsReviewer, sandboxPolicy: SandboxPolicy, activePermissionProfile: ActivePermissionProfile | null, model: string, modelProvider: string, serviceTier: string | null, effort: ReasoningEffort | null, summary: ReasoningSummary | null, collaborationMode: CollaborationMode,
/**
 * @deprecated Always `explicitRequestOnly`. Use `effort` for Ultra behavior.
 */
multiAgentMode: MultiAgentMode,
/**
 * @deprecated Reports the saved setting; `friendly` and `pragmatic` no longer select a style.
 */
personality: Personality | null, };
// ---- v2/AskForApproval.ts
export type AskForApproval = "untrusted" | "on-request" | { "granular": { sandbox_approval: boolean, rules: boolean, skill_approval: boolean, request_permissions: boolean, mcp_elicitations: boolean, } } | "never";
// ---- v2/ApprovalsReviewer.ts
/**
 * Configures who approval requests are routed to for review. Examples
 * include sandbox escapes, blocked network access, MCP approval prompts, and
 * ARC escalations. Defaults to `user`. `auto_review` uses a carefully
 * prompted subagent to gather relevant context and apply a risk-based
 * decision framework before approving or denying the request.
 */
export type ApprovalsReviewer = "user" | "auto_review" | "guardian_subagent";
// ---- v2/SandboxMode.ts
export type SandboxMode = "read-only" | "workspace-write" | "danger-full-access";
// ---- v2/SandboxPolicy.ts
export type SandboxPolicy = { "type": "dangerFullAccess" } | { "type": "readOnly", networkAccess: boolean, } | { "type": "externalSandbox", networkAccess: NetworkAccess, } | { "type": "workspaceWrite", writableRoots: Array<AbsolutePathBuf>, networkAccess: boolean, excludeTmpdirEnvVar: boolean, excludeSlashTmp: boolean, };
// ---- ReasoningEffort.ts
/**
 * See https://platform.openai.com/docs/guides/reasoning?api-mode=responses#get-started-with-reasoning
 */
export type ReasoningEffort = string;
// ---- ReasoningSummary.ts
/**
 * A summary of the reasoning performed by the model. This can be useful for
 * debugging and understanding the model's reasoning process.
 * See https://platform.openai.com/docs/guides/reasoning?api-mode=responses#reasoning-summaries
 */
export type ReasoningSummary = "auto" | "concise" | "detailed" | "none";
// ---- CollaborationMode.ts
/**
 * Collaboration mode for a Codex session.
 */
export type CollaborationMode = { mode: ModeKind, settings: Settings, };
// ---- ModeKind.ts
/**
 * Initial collaboration mode to use when the TUI starts.
 */
export type ModeKind = "plan" | "default";
// ---- Settings.ts
/**
 * Settings for a collaboration mode.
 */
export type Settings = { model: string, reasoning_effort: ReasoningEffort | null, developer_instructions: string | null, };
// ---- v2/CollaborationModeMask.ts
/**
 * EXPERIMENTAL - collaboration mode preset metadata for clients.
 */
export type CollaborationModeMask = { name: string, mode: ModeKind | null, model: string | null, reasoning_effort: ReasoningEffort | null | null, };
// ---- v2/ThreadItem.ts
export type ThreadItem = { "type": "userMessage", id: string, clientId: string | null, content: Array<UserInput>, } | { "type": "hookPrompt", id: string, fragments: Array<HookPromptFragment>, } | { "type": "agentMessage", id: string, text: string, phase: MessagePhase | null, memoryCitation: MemoryCitation | null, delivery: AgentMessageDelivery | null, questions: Array<AsyncUserInputQuestion> | null, } | { "type": "functionCallOutput", id: string, name: string, namespace: string | null, output: FunctionCallOutputBody, } | { "type": "plan", id: string, text: string, } | { "type": "reasoning", id: string, summary: Array<string>, content: Array<string>, } | { "type": "commandExecution", id: string,
/**
 * Trusted first-party plugin id when this command resolves to one plugin script.
 */
pluginId: string | null,
/**
 * Safe plugin-relative path when this command resolves to one plugin script.
 */
scriptPath: string | null,
/**
 * The command to be executed.
 */
command: string,
/**
 * The command's working directory.
 */
cwd: LegacyAppPathString,
/**
 * Identifier for the underlying PTY process (when available).
 */
processId: string | null, source: CommandExecutionSource, status: CommandExecutionStatus,
/**
 * A best-effort parsing of the command to understand the action(s) it will perform.
 * This returns a list of CommandAction objects because a single shell command may
 * be composed of many commands piped together.
 */
commandActions: Array<CommandAction>,
/**
 * The command's output, aggregated from stdout and stderr.
 */
aggregatedOutput: string | null,
/**
 * The command's exit code.
 */
exitCode: number | null,
/**
 * The duration of the command execution in milliseconds.
 */
durationMs: number | null, } | { "type": "fileChange", id: string, changes: Array<FileUpdateChange>, status: PatchApplyStatus, } | { "type": "mcpToolCall", id: string, server: string, tool: string, status: McpToolCallStatus, arguments: JsonValue, appContext: McpToolCallAppContext | null,
/**
 * Legacy compatibility field; prefer `mcpAppUi.resourceUri` when available.
 */
mcpAppResourceUri?: string,
/**
 * Presentation captured from the invoked descriptor; absent in older history.
 */
mcpAppUi: McpAppUi | null, pluginId: string | null, readOnlyHint: boolean | null, result: McpToolCallResult | null, error: McpToolCallError | null,
/**
 * The duration of the MCP tool call in milliseconds.
 */
durationMs: number | null, } | { "type": "dynamicToolCall", id: string, namespace: string | null, tool: string, arguments: JsonValue, status: DynamicToolCallStatus, contentItems: Array<DynamicToolCallOutputContentItem> | null, success: boolean | null,
/**
 * The duration of the dynamic tool call in milliseconds.
 */
durationMs: number | null, } | { "type": "collabAgentToolCall",
/**
 * Unique identifier for this collab tool call.
 */
id: string,
/**
 * Name of the collab tool that was invoked.
 */
tool: CollabAgentTool,
/**
 * Current status of the collab tool call.
 */
status: CollabAgentToolCallStatus,
/**
 * Thread ID of the agent issuing the collab request.
 */
senderThreadId: string,
/**
 * Thread ID of the receiving agent, when applicable. In case of spawn operation,
 * this corresponds to the newly spawned agent.
 */
receiverThreadIds: Array<string>,
/**
 * Prompt text sent as part of the collab tool call, when available.
 */
prompt: string | null,
/**
 * Model requested for the spawned agent, when applicable.
 */
model: string | null,
/**
 * Reasoning effort requested for the spawned agent, when applicable.
 */
reasoningEffort: ReasoningEffort | null,
/**
 * Last known status of the target agents, when available.
 */
agentsStates: { [key in string]?: CollabAgentState }, } | { "type": "subAgentActivity", id: string, kind: SubAgentActivityKind, agentThreadId: string, agentPath: string, } | { "type": "webSearch" } & WebSearchItem | { "type": "imageView", id: string, path: LegacyAppPathString, } | { "type": "sleep" } & SleepItem | { "type": "imageGeneration" } & ImageGenerationItem | { "type": "enteredReviewMode", id: string, review: string, } | { "type": "exitedReviewMode", id: string, review: string, } | { "type": "contextCompaction", id: string, };
// ---- v2/CommandExecutionStatus.ts
export type CommandExecutionStatus = "inProgress" | "completed" | "failed" | "declined";
// ---- v2/CommandExecutionSource.ts
export type CommandExecutionSource = "agent" | "userShell" | "unifiedExecStartup" | "unifiedExecInteraction";
// ---- v2/CommandAction.ts
export type CommandAction = { "type": "read", command: string, name: string, path: LegacyAppPathString, } | { "type": "listFiles", command: string, path: string | null, } | { "type": "search", command: string, query: string | null, path: string | null, } | { "type": "unknown", command: string, };
// ---- v2/FileUpdateChange.ts
export type FileUpdateChange = { path: string, kind: PatchChangeKind, diff: string, };
// ---- v2/PatchChangeKind.ts
export type PatchChangeKind = { "type": "add" } | { "type": "delete" } | { "type": "update", move_path: string | null, };
// ---- v2/PatchApplyStatus.ts
export type PatchApplyStatus = "inProgress" | "completed" | "failed" | "declined";
// ---- v2/McpToolCallStatus.ts
export type McpToolCallStatus = "inProgress" | "completed" | "failed";
// ---- v2/CollabAgentTool.ts
export type CollabAgentTool = "spawnAgent" | "sendInput" | "resumeAgent" | "wait" | "closeAgent" | "sendMessage" | "followupTask" | "interruptAgent" | "listAgents";
// ---- v2/CollabAgentToolCallStatus.ts
export type CollabAgentToolCallStatus = "inProgress" | "completed" | "failed" | "interrupted";
// ---- v2/CollabAgentState.ts
export type CollabAgentState = { status: CollabAgentStatus, message: string | null, };
// ---- v2/CollabAgentStatus.ts
export type CollabAgentStatus = "pendingInit" | "running" | "interrupted" | "completed" | "errored" | "shutdown" | "notFound";
// ---- v2/SubAgentActivityKind.ts
export type SubAgentActivityKind = "started" | "interacted" | "interrupted" | "completed";
// ---- WebSearchItem.ts
export type WebSearchItem = { id: string, query: string, action: WebSearchAction | null,
/**
 * Structured search results returned out-of-band by standalone web search.
 *
 * These stay as opaque JSON at the extension/app-server boundary so new
 * result fields and result types can pass through without a Codex release.
 */
results: Array<JsonValue> | null, };
// ---- MessagePhase.ts
/**
 * Classifies an assistant message as interim commentary or final answer text.
 *
 * Providers do not emit this consistently, so callers must treat `None` as
 * "phase unknown" and keep compatibility behavior for legacy models.
 */
export type MessagePhase = "commentary" | "final_answer";
// ---- v2/ItemStartedNotification.ts
export type ItemStartedNotification = { item: ThreadItem, threadId: string, turnId: string,
/**
 * Unix timestamp (in milliseconds) when this item lifecycle started.
 */
startedAtMs: number, };
// ---- v2/ItemCompletedNotification.ts
export type ItemCompletedNotification = { item: ThreadItem, threadId: string, turnId: string,
/**
 * Unix timestamp (in milliseconds) when this item lifecycle completed.
 */
completedAtMs: number, };
// ---- v2/TurnStartedNotification.ts
export type TurnStartedNotification = { threadId: string, turn: Turn, };
// ---- v2/TurnCompletedNotification.ts
export type TurnCompletedNotification = { threadId: string, turn: Turn, };
// ---- v2/AgentMessageDeltaNotification.ts
export type AgentMessageDeltaNotification = { threadId: string, turnId: string, itemId: string, delta: string, };
// ---- v2/ReasoningSummaryTextDeltaNotification.ts
export type ReasoningSummaryTextDeltaNotification = { threadId: string, turnId: string, itemId: string, delta: string, summaryIndex: number, };
// ---- v2/CommandExecutionOutputDeltaNotification.ts
export type CommandExecutionOutputDeltaNotification = { threadId: string, turnId: string, itemId: string, delta: string, };
// ---- v2/TerminalInteractionNotification.ts
export type TerminalInteractionNotification = { threadId: string, turnId: string, itemId: string, processId: string, stdin: string, };
// ---- v2/PlanDeltaNotification.ts
/**
 * EXPERIMENTAL - proposed plan streaming deltas for plan items. Clients should
 * not assume concatenated deltas match the completed plan item content.
 */
export type PlanDeltaNotification = { threadId: string, turnId: string, itemId: string, delta: string, };
// ---- v2/TurnPlanUpdatedNotification.ts
export type TurnPlanUpdatedNotification = { threadId: string, turnId: string, explanation: string | null, plan: Array<TurnPlanStep>, };
// ---- v2/TurnPlanStep.ts
export type TurnPlanStep = { step: string, status: TurnPlanStepStatus, };
// ---- v2/TurnPlanStepStatus.ts
export type TurnPlanStepStatus = "pending" | "inProgress" | "completed";
// ---- v2/TurnDiffUpdatedNotification.ts
/**
 * Notification that the turn-level unified diff has changed.
 * Contains the latest aggregated diff across all file changes in the turn.
 */
export type TurnDiffUpdatedNotification = { threadId: string, turnId: string, diff: string, };
// ---- v2/ThreadTokenUsageUpdatedNotification.ts
export type ThreadTokenUsageUpdatedNotification = { threadId: string, turnId: string, tokenUsage: ThreadTokenUsage, };
// ---- v2/ThreadTokenUsage.ts
export type ThreadTokenUsage = { total: TokenUsageBreakdown, last: TokenUsageBreakdown, modelContextWindow: number | null, };
// ---- v2/TokenUsageBreakdown.ts
export type TokenUsageBreakdown = { totalTokens: number, inputTokens: number, cachedInputTokens: number, cacheWriteInputTokens: number, outputTokens: number, reasoningOutputTokens: number, };
// ---- v2/CommandExecutionRequestApprovalParams.ts
export type CommandExecutionRequestApprovalParams = {
/**
 * Kind of action under review. Defaults to `command` for older servers.
 */
kind: CommandExecutionApprovalKind, threadId: string, turnId: string, itemId: string,
/**
 * Unix timestamp (in milliseconds) when this approval request started.
 */
startedAtMs: number,
/**
 * Unique identifier for this specific approval callback.
 *
 * For regular shell/unified_exec approvals, this is null.
 *
 * For zsh-exec-bridge subcommand approvals, multiple callbacks can belong to
 * one parent `itemId`, so `approvalId` is a distinct opaque callback id
 * (a UUID) used to disambiguate routing.
 * Stdin approvals also use a distinct callback id; inspect `kind` to distinguish them.
 */
approvalId?: string | null,
/**
 * Environment in which the command will run.
 */
environmentId: string | null,
/**
 * Optional explanatory reason (e.g. request for network access).
 */
reason?: string | null,
/**
 * Optional context for a managed-network approval prompt.
 */
networkApprovalContext?: NetworkApprovalContext | null,
/**
 * The command to be executed.
 */
command?: string | null,
/**
 * The command's working directory.
 */
cwd?: LegacyAppPathString | null,
/**
 * Best-effort parsed command actions for friendly display.
 */
commandActions?: Array<CommandAction> | null,
/**
 * Optional additional permissions requested for this command.
 */
additionalPermissions?: AdditionalPermissionProfile | null,
/**
 * Optional proposed execpolicy amendment to allow similar commands without prompting.
 */
proposedExecpolicyAmendment?: ExecPolicyAmendment | null,
/**
 * Optional proposed network policy amendments (allow/deny host) for future requests.
 */
proposedNetworkPolicyAmendments?: Array<NetworkPolicyAmendment> | null,
/**
 * Ordered list of decisions the client may present for this prompt.
 */
availableDecisions?: Array<CommandExecutionApprovalDecision> | null, };
// ---- v2/CommandExecutionRequestApprovalResponse.ts
export type CommandExecutionRequestApprovalResponse = { decision: CommandExecutionApprovalDecision, };
// ---- v2/CommandExecutionApprovalDecision.ts
export type CommandExecutionApprovalDecision = "accept" | "acceptForSession" | { "acceptWithExecpolicyAmendment": { execpolicy_amendment: ExecPolicyAmendment, } } | { "applyNetworkPolicyAmendment": { network_policy_amendment: NetworkPolicyAmendment, } } | "decline" | "cancel";
// ---- v2/FileChangeRequestApprovalParams.ts
export type FileChangeRequestApprovalParams = { threadId: string, turnId: string, itemId: string,
/**
 * Unix timestamp (in milliseconds) when this approval request started.
 */
startedAtMs: number,
/**
 * Optional explanatory reason (e.g. request for extra write access).
 */
reason?: string | null,
/**
 * [UNSTABLE] When set, the agent is asking the user to allow writes under this root
 * for the remainder of the session (unclear if this is honored today).
 */
grantRoot?: string | null, };
// ---- v2/FileChangeRequestApprovalResponse.ts
export type FileChangeRequestApprovalResponse = { decision: FileChangeApprovalDecision, };
// ---- v2/FileChangeApprovalDecision.ts
export type FileChangeApprovalDecision = "accept" | "acceptForSession" | "decline" | "cancel";
// ---- v2/ToolRequestUserInputParams.ts
/**
 * EXPERIMENTAL. Params sent with a request_user_input event.
 */
export type ToolRequestUserInputParams = { threadId: string, turnId: string, itemId: string, questions: Array<ToolRequestUserInputQuestion>, isBlocking: boolean,
/**
 * @deprecated Use `isBlocking` to decide whether the request should block.
 */
autoResolutionMs: number | null, };
// ---- v2/ToolRequestUserInputQuestion.ts
/**
 * EXPERIMENTAL. Represents one request_user_input question and its required options.
 */
export type ToolRequestUserInputQuestion = { id: string, header: string, question: string, isOther: boolean, isSecret: boolean, options: Array<ToolRequestUserInputOption> | null, };
// ---- v2/ToolRequestUserInputOption.ts
/**
 * EXPERIMENTAL. Defines a single selectable option for request_user_input.
 */
export type ToolRequestUserInputOption = { label: string, description: string, };
// ---- v2/ToolRequestUserInputResponse.ts
/**
 * EXPERIMENTAL. Response payload mapping question ids to answers.
 */
export type ToolRequestUserInputResponse = { answers: { [key in string]?: ToolRequestUserInputAnswer }, };
// ---- v2/ToolRequestUserInputAnswer.ts
/**
 * EXPERIMENTAL. Captures a user's answer to a request_user_input question.
 */
export type ToolRequestUserInputAnswer = { answers: Array<string>, };
// ---- v2/PermissionsRequestApprovalParams.ts
export type PermissionsRequestApprovalParams = { threadId: string, turnId: string, itemId: string, environmentId: string | null,
/**
 * Unix timestamp (in milliseconds) when this approval request started.
 */
startedAtMs: number, cwd: LegacyAppPathString, reason: string | null, permissions: RequestPermissionProfile, };
// ---- v2/PermissionsRequestApprovalResponse.ts
export type PermissionsRequestApprovalResponse = { permissions: GrantedPermissionProfile, scope: PermissionGrantScope,
/**
 * Review every subsequent command in this turn before normal sandboxed execution.
 */
strictAutoReview?: boolean, };
// ---- v2/ServerRequestResolvedNotification.ts
export type ServerRequestResolvedNotification = { threadId: string, requestId: RequestId, };
// ---- v2/GetAccountParams.ts
export type GetAccountParams = {
/**
 * When `true`, requests a proactive token refresh before returning.
 *
 * In managed auth mode this triggers the normal refresh-token flow. In
 * external auth mode this flag is ignored. Clients should refresh tokens
 * themselves and call `account/login/start` with `chatgptAuthTokens`.
 */
refreshToken?: boolean, };
// ---- v2/GetAccountResponse.ts
export type GetAccountResponse = { account: Account | null, requiresOpenaiAuth: boolean, workspaceRouting: WorkspaceRouting | null, };
// ---- v2/Account.ts
export type Account = { "type": "apiKey", } | { "type": "chatgpt", email: string | null, planType: PlanType, } | { "type": "amazonBedrock", usesCodexManagedCredentials: boolean, };
// ---- AuthMode.ts
/**
 * Authentication mode for OpenAI-backed providers.
 */
export type AuthMode = "apikey" | "chatgpt" | "chatgptAuthTokens" | "headers" | "agentIdentity" | "personalAccessToken" | "bedrockApiKey" | "bedrockAccessKeys";
// ---- v2/AccountUpdatedNotification.ts
export type AccountUpdatedNotification = { authMode: AuthMode | null, planType: PlanType | null, };
// ---- v2/LoginAccountParams.ts
export type LoginAccountParams = { "type": "apiKey", apiKey: string, } | { "type": "chatgpt", codexStreamlinedLogin?: boolean, useHostedLoginSuccessPage?: boolean, appBrand?: LoginAppBrand | null, } | { "type": "chatgptDeviceCode" } | { "type": "chatgptAuthTokens",
/**
 * Access token (JWT) supplied by the client.
 * This token is used for backend API requests and email extraction.
 */
accessToken: string,
/**
 * Workspace/account identifier supplied by the client.
 */
chatgptAccountId: string,
/**
 * Optional plan type supplied by the client.
 *
 * When `null`, Codex attempts to derive the plan type from access-token
 * claims. If unavailable, the plan defaults to `unknown`.
 */
chatgptPlanType?: string | null, } | { "type": "amazonBedrock", apiKey: string, region: string, } | { "type": "amazonBedrockAccessKeys", accessKeyId: string, secretAccessKey: string, sessionToken?: string | null, region: string, };
// ---- v2/LoginAccountResponse.ts
export type LoginAccountResponse = { "type": "apiKey", } | { "type": "chatgpt", loginId: string,
/**
 * URL the client should open in a browser to initiate the OAuth flow.
 */
authUrl: string, } | { "type": "chatgptDeviceCode", loginId: string,
/**
 * URL the client should open in a browser to complete device code authorization.
 */
verificationUrl: string,
/**
 * One-time code the user must enter after signing in.
 */
userCode: string, } | { "type": "chatgptAuthTokens", } | { "type": "amazonBedrock", };
// ---- v2/GetAccountRateLimitsResponse.ts
export type GetAccountRateLimitsResponse = {
/**
 * Backend permission for ordinary included usage, validated against the active account.
 * Null means unavailable; clients must not infer recovery from percentages or reset times.
 */
ordinaryUsageAllowed: boolean | null,
/**
 * Backward-compatible single-bucket view; mirrors the historical payload.
 */
rateLimits: RateLimitSnapshot,
/**
 * Multi-bucket view keyed by metered `limit_id` (for example, `codex`).
 */
rateLimitsByLimitId: { [key in string]?: RateLimitSnapshot } | null, rateLimitResetCredits: RateLimitResetCreditsSummary | null,
/**
 * Account associated with this usage snapshot, when supplied by the backend.
 */
accountId: string | null,
/**
 * Optional backend-owned banner from the same usage read. Its nested keys retain the
 * backend's snake_case contract; an absent banner leaves the client's existing UI unchanged.
 */
rateLimitUpsell: JsonValue | null, };
// ---- v2/RateLimitSnapshot.ts
export type RateLimitSnapshot = { limitId: string | null, limitName: string | null,
/**
 * Normal model whose display name and reasoning options describe this quota alias.
 */
normalModelSlug: string | null, primary: RateLimitWindow | null, secondary: RateLimitWindow | null, credits: CreditsSnapshot | null, individualLimit: SpendControlLimitSnapshot | null,
/**
 * Backend-reported spend-control state. `None` is unavailable, not a sparse-update recovery.
 */
spendControlReached: boolean | null, planType: PlanType | null, rateLimitReachedType: RateLimitReachedType | null, };
// ---- v2/RateLimitWindow.ts
export type RateLimitWindow = { usedPercent: number, windowDurationMins: number | null, resetsAt: number | null, };
// ---- v2/CreditsSnapshot.ts
export type CreditsSnapshot = { hasCredits: boolean, unlimited: boolean, balance: string | null, };
// ---- v2/RateLimitReachedType.ts
export type RateLimitReachedType = "rate_limit_reached" | "workspace_owner_credits_depleted" | "workspace_member_credits_depleted" | "workspace_owner_usage_limit_reached" | "workspace_member_usage_limit_reached";
// ---- PlanType.ts
export type PlanType = "free" | "go" | "plus" | "pro" | "prolite" | "promax" | "team" | "self_serve_business_prolite" | "self_serve_business_usage_based" | "business" | "ent26" | "enterprise_cbp_automation" | "enterprise_cbp_usage_based" | "enterprise" | "edu" | "edu_plus" | "edu_pro" | "unknown";
// ---- v2/AccountRateLimitsUpdatedNotification.ts
/**
 * Sparse rolling rate-limit update.
 *
 * Clients should merge available values into the most recent `account/rateLimits/read` response
 * or refetch that snapshot. Nullable account metadata may be unavailable in a rolling update and
 * does not clear a previously observed value.
 */
export type AccountRateLimitsUpdatedNotification = { rateLimits: RateLimitSnapshot, };
// ---- v2/ModelListParams.ts
export type ModelListParams = {
/**
 * Opaque pagination cursor returned by a previous call.
 */
cursor?: string | null,
/**
 * Optional page size; defaults to a reasonable server-side value.
 */
limit?: number | null,
/**
 * When true, include models that are hidden from the default picker list.
 */
includeHidden?: boolean | null, };
// ---- v2/ModelListResponse.ts
export type ModelListResponse = { data: Array<Model>,
/**
 * Opaque cursor to pass to the next call to continue after the last item.
 * If None, there are no more items to return.
 */
nextCursor: string | null, };
// ---- v2/Model.ts
export type Model = { id: string, model: string, upgrade: string | null, upgradeInfo: ModelUpgradeInfo | null, availabilityNux: ModelAvailabilityNux | null, displayName: string, description: string, modelSpecialty: string | null, hidden: boolean, supportedReasoningEfforts: Array<ReasoningEffortOption>, defaultReasoningEffort: ReasoningEffort, inputModalities: Array<InputModality>,
/**
 * @deprecated Always false; models no longer support personality selection.
 */
supportsPersonality: boolean,
/**
 * Multi-agent runtime declared by this model, when available.
 */
multiAgentVersion: MultiAgentVersion | null,
/**
 * Deprecated: use `serviceTiers` instead.
 */
additionalSpeedTiers: Array<string>, serviceTiers: Array<ModelServiceTier>,
/**
 * Catalog default service tier id for this model, when one is configured.
 */
defaultServiceTier: string | null,
/**
 * Null when the catalog does not provide access-program metadata.
 */
availableAccessPrograms: ModelAccessPrograms | null, isDefault: boolean, };
// ---- v2/ReasoningEffortOption.ts
export type ReasoningEffortOption = { reasoningEffort: ReasoningEffort, description: string, };
// ---- InputModality.ts
/**
 * Canonical user-input modality tags advertised by a model.
 */
export type InputModality = "text" | "image" | "audio";
// ---- FuzzyFileSearchParams.ts
export type FuzzyFileSearchParams = { query: string, roots: Array<string>, cancellationToken: string | null, };
// ---- FuzzyFileSearchResponse.ts
export type FuzzyFileSearchResponse = { files: Array<FuzzyFileSearchResult>, };
// ---- FuzzyFileSearchResult.ts
/**
 * Superset of [`codex_file_search::FileMatch`]
 */
export type FuzzyFileSearchResult = { root: string, path: string, match_type: FuzzyFileSearchMatchType, file_name: string, score: number, indices: Array<number> | null, };
// ---- v2/SkillsListParams.ts
export type SkillsListParams = {
/**
 * When empty, defaults to the current session working directory.
 */
cwds?: Array<string>,
/**
 * When true, bypass the skills cache and re-scan skills from disk.
 */
forceReload?: boolean, };
// ---- v2/SkillsListResponse.ts
export type SkillsListResponse = { data: Array<SkillsListEntry>, };
// ---- v2/SkillsListEntry.ts
export type SkillsListEntry = { cwd: string, skills: Array<SkillMetadata>, errors: Array<SkillErrorInfo>, };
// ---- v2/SkillMetadata.ts
export type SkillMetadata = { name: string, description: string,
/**
 * Legacy short_description from SKILL.md. Prefer SKILL.json interface.short_description.
 */
shortDescription?: string, interface?: SkillInterface, dependencies?: SkillDependencies, path: AbsolutePathBuf, scope: SkillScope, enabled: boolean,
/**
 * Owning plugin ID, matching `PluginSummary.id`, when known.
 */
pluginId: string | null, };
// ---- v2/SkillScope.ts
export type SkillScope = "user" | "repo" | "system" | "admin";
// ---- v2/ReviewStartParams.ts
export type ReviewStartParams = { threadId: string, target: ReviewTarget,
/**
 * Where to run the review: inline (default) on the current thread or
 * detached on a new thread (returned in `reviewThreadId`).
 * Detached delivery is deprecated and emits `deprecationNotice`.
 * Use `thread/start` followed by an inline review for a separate review thread.
 */
delivery?: ReviewDelivery | null, };
// ---- v2/ReviewTarget.ts
export type ReviewTarget = { "type": "uncommittedChanges" } | { "type": "baseBranch", branch: string, } | { "type": "commit", sha: string,
/**
 * Optional human-readable label (e.g., commit subject) for UIs.
 */
title: string | null, } | { "type": "custom", instructions: string, };
// ---- v2/ReviewDelivery.ts
export type ReviewDelivery = "inline" | "detached";
// ---- v2/ThreadQueueAddParams.ts
export type ThreadQueueAddParams = { threadId: string, input: Array<UserInput>, clientUserMessageId: string, };
// ---- v2/QueuedSubmission.ts
export type QueuedSubmission = { id: string, input: Array<UserInput>, clientUserMessageId: string, };
// ---- v2/ThreadQueueListResponse.ts
export type ThreadQueueListResponse = { data: Array<QueuedSubmission>,
/**
 * Opaque cursor for the next page, or `null` when no submissions remain.
 */
nextCursor: string | null, };
// ---- v2/ThreadQueueStartParams.ts
export type ThreadQueueStartParams = { threadId: string, queuedSubmissionId?: string | null, };
// ---- v2/ThreadShellCommandParams.ts
export type ThreadShellCommandParams = { threadId: string,
/**
 * Shell command string evaluated by the thread's configured shell.
 * Unlike `command/exec`, this intentionally preserves shell syntax
 * such as pipes, redirects, and quoting. This runs unsandboxed with full
 * access rather than inheriting the thread sandbox policy.
 */
command: string,
/**
 * Maximum execution time in milliseconds. Defaults to one hour when omitted
 * or null. Must be non-negative; zero requests an immediate timeout, not
 * unlimited execution. Does not affect the immediate RPC acknowledgement.
 */
timeoutMs?: number | null, };
// ---- v2/CommandExecParams.ts
/**
 * Run a standalone command (argv vector) in the server sandbox without
 * creating a thread or turn.
 *
 * The final `command/exec` response is deferred until the process exits and is
 * sent only after all `command/exec/outputDelta` notifications for that
 * connection have been emitted.
 */
export type CommandExecParams = {
/**
 * Command argv vector. Empty arrays are rejected.
 */
command: Array<string>,
/**
 * Optional client-supplied, connection-scoped process id.
 *
 * Required for `tty`, `streamStdin`, `streamStdoutStderr`, and follow-up
 * `command/exec/write`, `command/exec/resize`, and
 * `command/exec/terminate` calls. When omitted, buffered execution gets an
 * internal id that is not exposed to the client.
 */
processId?: string | null,
/**
 * Enable PTY mode.
 *
 * This implies `streamStdin` and `streamStdoutStderr`.
 */
tty?: boolean,
/**
 * Allow follow-up `command/exec/write` requests to write stdin bytes.
 *
 * Requires a client-supplied `processId`.
 */
streamStdin?: boolean,
/**
 * Stream stdout/stderr via `command/exec/outputDelta` notifications.
 *
 * Streamed bytes are not duplicated into the final response and require a
 * client-supplied `processId`.
 */
streamStdoutStderr?: boolean,
/**
 * Optional per-stream stdout/stderr capture cap in bytes.
 *
 * When omitted, the server default applies. Cannot be combined with
 * `disableOutputCap`.
 */
outputBytesCap?: number | null,
/**
 * Disable stdout/stderr capture truncation for this request.
 *
 * Cannot be combined with `outputBytesCap`.
 */
disableOutputCap?: boolean,
/**
 * Disable the timeout entirely for this request.
 *
 * Cannot be combined with `timeoutMs`.
 */
disableTimeout?: boolean,
/**
 * Optional timeout in milliseconds.
 *
 * When omitted, the server default applies. Cannot be combined with
 * `disableTimeout`.
 */
timeoutMs?: number | null,
/**
 * Optional working directory. Defaults to the server cwd.
 */
cwd?: string | null,
/**
 * Optional environment overrides merged into the server-computed
 * environment.
 *
 * Matching names override inherited values. Set a key to `null` to unset
 * an inherited variable.
 */
env?: { [key in string]?: string | null } | null,
/**
 * Optional initial PTY size in character cells. Only valid when `tty` is
 * true.
 */
size?: CommandExecTerminalSize | null,
/**
 * Optional sandbox policy for this command.
 *
 * Uses the same shape as thread/turn execution sandbox configuration and
 * defaults to the user's configured policy when omitted. Cannot be
 * combined with `permissionProfile`.
 */
sandboxPolicy?: SandboxPolicy | null,
/**
 * Optional active permissions profile id for this command.
 *
 * Defaults to the user's configured permissions when omitted. Cannot be
 * combined with `sandboxPolicy`.
 */
permissionProfile?: string | null, };
// ---- v2/CommandExecResponse.ts
/**
 * Final buffered result for `command/exec`.
 */
export type CommandExecResponse = {
/**
 * Process exit code.
 */
exitCode: number,
/**
 * Buffered stdout capture.
 *
 * Empty when stdout was streamed via `command/exec/outputDelta`.
 */
stdout: string,
/**
 * Buffered stderr capture.
 *
 * Empty when stderr was streamed via `command/exec/outputDelta`.
 */
stderr: string, };
// ---- v2/ThreadGoal.ts
export type ThreadGoal = { threadId: string, objective: string, status: ThreadGoalStatus, tokenBudget: number | null, tokensUsed: number, timeUsedSeconds: number, createdAt: number, updatedAt: number, };
// ---- v2/ThreadGoalStatus.ts
export type ThreadGoalStatus = "active" | "paused" | "blocked" | "usageLimited" | "budgetLimited" | "complete";
