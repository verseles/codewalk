// Source: @anthropic-ai/claude-agent-sdk@0.3.287 sdk.d.ts (npm, published 2026-10-01). Key declarations WITH their JSDoc, extracted verbatim. Non-exported 'declare type' entries are wire-protocol types used on stdin/stdout.
// ====== SDKMessage
/**
 * Every conversational and informational message the CLI emits on its output stream, discriminated by type (and subtype for system/result messages). Consumers should ignore types and subtypes they do not recognize: the set grows over time.
 */
export declare type SDKMessage = SDKAssistantMessage | SDKUserMessage | SDKUserMessageReplay | SDKResultMessage | SDKSystemMessage | SDKPartialAssistantMessage | SDKCompactBoundaryMessage | SDKStatusMessage | SDKAPIRetryMessage | SDKControlRequestProgressMessage | SDKModelRefusalFallbackMessage | SDKModelRefusalNoFallbackMessage | SDKLocalCommandOutputMessage | SDKHookStartedMessage | SDKHookProgressMessage | SDKHookResponseMessage | SDKPluginInstallMessage | SDKToolProgressMessage | SDKAuthStatusMessage | SDKTaskNotificationMessage | SDKTaskStartedMessage | SDKTaskUpdatedMessage | SDKTaskProgressMessage | SDKBackgroundTasksChangedMessage | SDKThinkingTokensMessage | SDKSessionStateChangedMessage | SDKWorkerShuttingDownMessage | SDKCommandsChangedMessage | SDKNotificationMessage | SDKFilesPersistedEvent | SDKToolUseSummaryMessage | SDKMemoryRecallMessage | SDKRateLimitEvent | SDKElicitationCompleteMessage | SDKPermissionDeniedMessage | SDKPromptSuggestionMessage | SDKMirrorErrorMessage | SDKInformationalMessage | SDKConversationResetMessage;

// ====== StdoutMessage
/**
 * Everything the CLI writes to its output stream (stdout in stream-json mode): exactly one StdoutMessage per line, as a single JSON object. Besides the SDKMessage members this includes the control protocol - control requests the CLI originates, control responses to the client's requests, cancellations and keep-alives.
 */
declare type StdoutMessage = coreTypes.SDKMessage | coreTypes.SDKActiveGoalMessage | SDKControlResponse | SDKControlRequest | SDKControlCancelRequest | SDKKeepAliveMessage;

// ====== SDKSystemMessage
/**
 * Session metadata the CLI emits at the start of each turn, normally ahead of every other message of that turn: session_id, model, working directory, tools, MCP servers, slash commands, permission mode, and the capabilities list for feature detection.
 */
export declare type SDKSystemMessage = {
    type: 'system';
    subtype: 'init';
    agents?: string[];
    /**
     * Where the credential used for API requests came from: 'ANTHROPIC_API_KEY' (environment variable), 'apiKeyHelper' (the configured helper command), '/login managed key' (an API key created and stored by /login with an Anthropic Console account), or 'none' (no API key in use - e.g. claude.ai OAuth login, a bearer token, or a third-party cloud provider). 'user' | 'project' | 'org' | 'temporary' | 'oauth' are legacy members that current CLIs never emit; they remain only so the type stays backward compatible.
     */
    apiKeySource: ApiKeySource;

    betas?: string[];
    claude_code_version: string;
    cwd: string;
    tools: string[];
    mcp_servers: {
        name: string;
        status: string;
        /**
         * Where the server definition came from — same values as McpServerStatus.source (sdk | plugin | a config scope). Absent on CLIs that predate the field.
         */
        source?: string;
    }[];
    model: string;
    /**
     * Permission mode for controlling how tool executions are handled. 'default' - Standard behavior, prompts for dangerous operations. 'acceptEdits' - Auto-accept file edit operations. 'bypassPermissions' - Bypass all permission checks (requires allowDangerouslySkipPermissions). 'plan' - Planning mode, no actual tool execution. 'dontAsk' - Don't prompt for permissions, deny if not pre-approved. 'auto' - Use a model classifier to approve/deny permission prompts.
     */
    permissionMode: PermissionMode;
    slash_commands: string[];
    /**
     * Subset of slash_commands whose UX is bound to the local terminal (e.g. exit, statusline). Phone/remote UIs should hide these from command menus; desktop surfaces may keep them. Present only when non-empty; absent on CLIs that predate the field, and on sessions where no advertised command carries the tag.
     */
    terminal_slash_commands?: string[];
    output_style: string;
    skills: string[];
    plugins: {
        name: string;
        path: string;

        /**
         * The plugin's version as declared in its plugin.json manifest, emitted verbatim (plugin-author-controlled — validate before trusting). Omitted when the manifest declares no version.
         */
        version?: string;
    }[];
    /**
     * Plugin load-time errors. A plugin that did not load (an unmet dependency, a --plugin-dir entry that failed) is absent from `plugins[]`; a plugin that loaded without one of its components keeps its row and gets an entry here too. `plugin` is `name@marketplace`, or the positional `inline[N]` / `synced[N]` tag for a directory entry that failed before it had a name; `type` is a category from an open set (path-not-found, generic-error, manifest-validation-error, dependency-unsatisfied, hook-load-failed, …) — treat a value you do not recognize as a generic failure; `message` is display text. The key is omitted when there are no errors; CI can fail on `(plugin_errors?.length ?? 0) > 0`. A session whose frames are persisted server-side (a Remote Control worker) always omits this key — plugin diagnostics stay in the local log there, so an omitted key does not assert a clean load.
     */
    plugin_errors?: {
        plugin: string;
        type: string;
        message: string;
        /**
         * Present only when a --plugin-dir, SDK `plugins` or synced directory entry did not load at all: the path of that entry, resolved against the cwd (for a directory, the value its `plugins[]` row would have carried; for a .zip, the archive; a --plugin-url entry carries none). `plugin` is then the positional `inline[N]` / `synced[N]` tag, so a host that mounts several directories pairs the error to its own by this path.
         */
        path?: string;
    }[];

    fast_mode_state?: FastModeState;
    fast_mode_disabled_reason?: FastModeDisabledReason;

    /**
     * The effort level the session will send on its next request — after env overrides, session state, org caps and model-support downgrades; the same value get_settings reports as applied.effort. null when no effort parameter will be sent (a model without effort, CLAUDE_CODE_EFFORT_LEVEL=unset, or an internal numeric budget). Present on Remote Control bridge init frames (terminal- and Desktop/VS Code-hosted sessions); absent on hosts that do not publish it and on CLIs that predate the field. Re-emitted inits carry the current value — the newest frame wins.
     */
    effort?: ('low' | 'medium' | 'high' | 'xhigh' | 'max') | null;

    /**
     * Whether the session's transcript is in focus view ('focus': the model is told the user sees only its final message per turn, so clients may collapse each turn to the prompt and the final response; 'default' otherwise). Toggled by /focus, including over Remote Control. Present on Remote Control bridge init frames and on the per-turn init of headless stream-json runs (`claude rc` workers, -p, the SDK's subprocess transport); absent on hosts that do not publish it (the in-process engine) and on CLIs that predate the field. Re-emitted inits carry the current value — the newest frame wins.
     */
    view_mode?: 'focus' | 'default';
    /**
     * Protocol capabilities this CLI supports, so SDK consumers can feature-detect instead of version-sniffing. Open set — ignore unknown values; check each capability for exactly the behavior you use. 'interrupt_receipt_v1' = the interrupt control_response success payload carries still_queued (uuids of async user messages that survive the interrupt). 'interrupt_cancel_queued_v1' = the interrupt control_request honors cancel_queued:true (queued and pending-dispatch commands are cancelled alongside the abort, listed on the response's cancelled field; still_queued is then empty — including any uuid that was mid-fold at the interrupt instant, since this request also aborts and the fold never delivers it — except that a client driving a hosted session lists there what it can no longer recall: a send already in flight to that session, or the first prompt the session was created with). 'queued_notifications' = the CLI accepts inbound queued_notification stream messages and drains them via ReadNotifications (the cloud session backend reads this from the persisted init event to decide whether it may send them). Absent on older CLIs.
     */
    capabilities?: string[];

    uuid: UUID;
    session_id: string;
};

// ====== SDKAssistantMessage
/**
 * An assistant message. While a response streams the CLI emits one assistant message per completed content block, so several consecutive assistant messages can share message.id and each carries just that block in message.content; on those, message.stop_reason is null and message.usage is not final — the turn's stop reason and total usage arrive on the result message. parent_tool_use_id is non-null when the message was produced inside a subagent started by that tool_use.
 */
export declare type SDKAssistantMessage = {
    type: 'assistant';
    /**
     * Shaped like an Anthropic Messages API Message object (role "assistant"): id, model, content blocks (text, thinking, tool_use, ...), stop_reason and usage. When streamed, content typically holds the single block this message delivers and stop_reason is still null — see SDKAssistantMessage. See the Messages API reference for the block types.
     */
    message: BetaMessage;
    parent_tool_use_id: string | null;
    error?: SDKAssistantMessageError;
    uuid: UUID;

    session_id: string;
    request_id?: string;
    /**
     * Client uuid of the user message this turn is answering (submitMessage options.uuid), stamped on an assistant message each time that send changes — the turn's FIRST top-level assistant message (which may carry only a thinking block, or be a synthetic API-error message), and then, for a turn started by a synthetic (meta) prompt, the first assistant message after each queued user message folded in mid-turn (the fold takes the echo over); with --include-partial-messages the turn's first non-ping stream event is stamped too, independently (see SDKPartialAssistantMessage), so the same uuid may appear on both — either binds the reply to the send it answers without waiting for the result; the server keeps the first stamp it sees per uuid. A turn started by a typed prompt keeps that uuid for its whole turn, so it stamps once per frame kind. A meta turn's own uuid is stamped only when the host vouches it is the client event's own (on a hosted session, the uuid the session server persisted: delivered content such as a Slack owner ping, a Slack-bot observation or a client-injected synthetic turn), never for a prompt the CLI minted itself — except that the boot-time rescue turn re-running a turn a worker restart interrupted mid-way stamps the interrupted turn's own last user prompt (with resume_reason), the send that re-run answers; either way a user message folded into a meta turn takes the echo over from it (the rescue turn absorbing messages sent while the session was down; a bot-observation turn absorbing a human's post), and the first reply frame of each kind after that fold carries the folded message's uuid — the first reply that message got. Wrapper-level sibling — never inside `message.content` — so it is not replayed to the model. Absent on every other frame of the turn, on subagent frames (parent_tool_use_id set), on turns that neither had a client uuid nor folded a user message in, and from older producers.
     */
    user_message_uuid?: string;
    /**
     * Client uuids of every user message whose prompt this turn has consumed so far, in consumption order — all members of a prompt batch the host merged into this one turn (several messages sent close together run as one turn whose user_message_uuid is the LAST member's), then any user message folded into the turn before this frame — so a consumer that sent any of them can bind this reply to its own send by finding its uuid anywhere in the list. Always contains user_message_uuid; at most 64 entries. Present exactly when user_message_uuid is, on the same frames; absent from older producers (fall back to user_message_uuid).
     */
    user_message_uuids?: string[];
    /**
     * Why this frame's turn is the automatic re-run of a turn a worker restart interrupted (CLAUDE_CODE_RESUME_INTERRUPTED_TURN): the host's CLAUDE_CODE_RESUME_REASON when it set one (host_draining, checkpoint_restore, container_recreated, …), else 'interrupted_turn'. Stamped on the same reply frames as user_message_uuid (which on such a re-run names the interrupted turn's own last user prompt), so a consumer can tell the re-run's first reply from the interrupted attempt's. Absent on every other turn, on thinking_tokens frames, and from older producers.
     */
    resume_reason?: string;
    /**
     * This turn continued the preceding truncated assistant turn inside its trailing signed thinking block (max-output-tokens recovery). Its thinking signatures are cumulative over that preceding thinking-only turn, so a history replayed through the bridge must carry this flag back for the normalizer to keep the run's prefix on the wire. Wrapper-level sibling — never inside `message.content` — so it is not replayed to the model.
     */
    resumed_from_incomplete_thinking?: true;
    /**
     * Wire uuids of previously-delivered messages that this message replaces (refusal-fallback supersede). The list can include tombstoned tool_result frames from the refused leg, not only assistant frames. Evict the named messages on arrival and treat this frame as their canonical replacement. Idempotent with the end-of-turn model_refusal_fallback notice, whose retracted_message_uuids remains the complete audit record for the turn.
     */
    supersedes?: UUID[];
    /**
     * True when this assistant message was truncated by an interrupt/abort before the stream completed: stop_reason was never received and the content may end mid-word. Absent on normally completed messages.
     */
    aborted?: true;
    /**
     * Subagent type that produced this message.
     */
    subagent_type?: string;
    /**
     * Description of the subagent task that produced this message.
     */
    task_description?: string;

    /**
     * ISO timestamp of when this content block finished on the originating process. One API assistant turn may produce several assistant messages sharing a message.id, each with its own timestamp. Uses the originating host's clock, so it's for display only; do not order messages by this field. Older emitters omit it; consumers should fall back to receive time.
     */
    timestamp?: string;

    /**
     * Structured twin of the /context report, carried on the synthetic assistant message that delivers the markdown table. Present only on /context results from CLIs new enough to attach it; the markdown in message.content remains the canonical fallback. Wrapper-level sibling — never inside `message.content` — so it is not replayed to the model.
     */
    context_usage?: SDKContextUsage;
    /**
     * Structured twin of the /usage report, carried on the synthetic assistant message that delivers its text: the session totals, the plan's usage rows and extra-usage spend, for remote clients that render a card from data. Present only on /usage results from CLIs new enough to attach it and from claude.ai-subscriber sessions; the text in message.content remains the canonical fallback. Wrapper-level sibling — never inside `message.content` — so it is not replayed to the model.
     */
    usage_report?: SDKUsageReport;

};

// ====== SDKAssistantMessageError
export declare type SDKAssistantMessageError = 'authentication_failed' | 'oauth_org_not_allowed' | 'account_on_hold' | 'verification_required' | 'billing_error' | 'rate_limit' | 'overloaded' | 'invalid_request' | 'model_not_found' | 'server_error' | 'unknown' | 'max_output_tokens' | 'cloud_credential_error';

// ====== SDKUserMessage
/**
 * A user-role message. A client writes one to the CLI to submit a prompt (this starts a turn); the CLI emits them for user-role content it adds to the conversation itself, chiefly the tool_result blocks answering the assistant's tool_use blocks.
 */
export declare type SDKUserMessage = {
    type: 'user';
    /**
     * An Anthropic Messages API user message: a MessageParam with role "user" whose content is a string or an array of content blocks (text, image, document, tool_result, ...). See the Messages API reference for the block types.
     */
    message: MessageParam;
    parent_tool_use_id: string | null;
    isSynthetic?: boolean;
    /**
     * Structured tool output — the tool's full Output object, not the string content sent to the model. The shape is per-tool, keyed by the matching tool_use block's name (see the *Output types in toolTypes); MCP and dynamic tools carry their own shapes, so the field stays unknown-typed. For the Agent/Task tool the completed shape is the subagent's final report without the model-directed agentId/usage trailer, plus run totals — render from it instead of parsing the tool_result text. A call that stepped aside for a message the user sent (today a WebFetch or WebSearch call) carries `{ detachedToolCall: true }` in place of its Output: the call is still running, and its result reaches the model in a later turn.
     */
    tool_use_result?: unknown;
    priority?: 'now' | 'next' | 'later';
    origin?: SDKMessageOrigin;

    /**
     * When false, the message is appended to the transcript without triggering an assistant turn. It will be merged into the next user message that does query.
     */
    shouldQuery?: boolean;
    /**
     * ISO timestamp when the message was created on the originating process. Older emitters omit it; consumers should fall back to receive time.
     */
    timestamp?: string;

    /**
     * The client composed this turn from content the user did not type; the CLI delivers its text as written, with no `@path` file-mention expansion and no slash-command dispatch. On current CLIs the turn-start attachment pass is skipped as a whole: `@server:resource` MCP mentions are not expanded either, and the prompt is sent without the context the CLI normally attaches alongside it (nested `CLAUDE.md` and rules files, skill and tool listings, reminders); the pass the CLI runs between tool calls is unaffected.
     */
    client_composed?: true;

    uuid?: UUID;
    /**
     * Content the user pasted into the prompt rather than typed: each entry a string or an array of content blocks. The CLI appends the text of each entry after the typed text, in order, and may wrap it in `<pasted_content>` tags. Blocks other than text are ignored; send images and documents in `message.content`.
     */
    pasted_content?: MessageParam['content'][];
    /**
     * Text the user pasted that is still in `message.content` where they put it: each entry one paste. The prompt is not changed by the host; the CLI may wrap each entry in `<pasted_content>` tags where it still stands in the last text block. For a paste the host took out of `message`, use `pasted_content` instead.
     */
    inline_pastes?: string[];
    session_id?: string;
    /**
     * Subagent type that produced this message.
     */
    subagent_type?: string;
    /**
     * Description of the subagent task that produced this message.
     */
    task_description?: string;

};

// ====== SDKUserMessageReplay
export declare type SDKUserMessageReplay = {
    type: 'user';
    /**
     * An Anthropic Messages API user message: a MessageParam with role "user" whose content is a string or an array of content blocks (text, image, document, tool_result, ...). See the Messages API reference for the block types.
     */
    message: MessageParam;
    parent_tool_use_id: string | null;
    isSynthetic?: boolean;
    /**
     * Structured tool output — the tool's full Output object, not the string content sent to the model. The shape is per-tool, keyed by the matching tool_use block's name (see the *Output types in toolTypes); MCP and dynamic tools carry their own shapes, so the field stays unknown-typed. For the Agent/Task tool the completed shape is the subagent's final report without the model-directed agentId/usage trailer, plus run totals — render from it instead of parsing the tool_result text. A call that stepped aside for a message the user sent (today a WebFetch or WebSearch call) carries `{ detachedToolCall: true }` in place of its Output: the call is still running, and its result reaches the model in a later turn.
     */
    tool_use_result?: unknown;
    priority?: 'now' | 'next' | 'later';
    origin?: SDKMessageOrigin;

    /**
     * When false, the message is appended to the transcript without triggering an assistant turn. It will be merged into the next user message that does query.
     */
    shouldQuery?: boolean;
    /**
     * ISO timestamp when the message was created on the originating process. Older emitters omit it; consumers should fall back to receive time.
     */
    timestamp?: string;

    /**
     * The client composed this turn from content the user did not type; the CLI delivers its text as written, with no `@path` file-mention expansion and no slash-command dispatch. On current CLIs the turn-start attachment pass is skipped as a whole: `@server:resource` MCP mentions are not expanded either, and the prompt is sent without the context the CLI normally attaches alongside it (nested `CLAUDE.md` and rules files, skill and tool listings, reminders); the pass the CLI runs between tool calls is unaffected.
     */
    client_composed?: true;

    uuid: UUID;
    session_id: string;
    isReplay: true;
    file_attachments?: unknown[];
};

// ====== SDKMessageOrigin
/**
 * Provenance of a user-role message (peer session, team lead, channel). A host wrapping keyboard input must stamp {kind:'human'} explicitly — absent origin is treated as unattributed and fails closed at strict isHuman() trust gates.
 */
export declare type SDKMessageOrigin = {
    kind: 'human';
} | {

// ====== SDKPartialAssistantMessage
/**
 * An incremental streaming event for the assistant message being generated, emitted only when partial messages are requested (--include-partial-messages). The complete assistant message still follows as its own message.
 */
export declare type SDKPartialAssistantMessage = {
    type: 'stream_event';
    /**
     * One Anthropic Messages API streaming event (message_start, content_block_start, content_block_delta, content_block_stop, message_delta, message_stop) as defined for the streaming Messages API.
     */
    event: BetaRawMessageStreamEvent;
    parent_tool_use_id: string | null;
    uuid: UUID;
    session_id: string;
    ttft_ms?: number;

    /**
     * Client uuid of the user message this turn is answering (submitMessage options.uuid), stamped on a non-ping stream event each time that send changes: the turn's FIRST non-ping stream event (normally the frame that triggers the turn's initial ack), and, for a turn started by a synthetic (meta) prompt, the first non-ping stream event after each queued user message folded in mid-turn takes the echo over (see SDKAssistantMessage.user_message_uuid for the rule) — so a consumer can bind the reply stream to the send it answers without waiting for the result. A turn started by a typed prompt stamps only its first non-ping stream event; independently, its first complete assistant message is stamped as well (see SDKAssistantMessage.user_message_uuid), so the same uuid may appear on both. Absent on every other stream event of the turn, on turns that neither had a client uuid nor folded a user message in, and from older producers.
     */
    user_message_uuid?: string;
    /**
     * Client uuids of every user message whose prompt this turn has consumed so far, in consumption order — all members of a prompt batch the host merged into this one turn (several messages sent close together run as one turn whose user_message_uuid is the LAST member's), then any user message folded into the turn before this frame — so a consumer that sent any of them can bind this reply to its own send by finding its uuid anywhere in the list. Always contains user_message_uuid; at most 64 entries. Present exactly when user_message_uuid is, on the same frames; absent from older producers (fall back to user_message_uuid).
     */
    user_message_uuids?: string[];
    /**
     * Why this frame's turn is the automatic re-run of a turn a worker restart interrupted (CLAUDE_CODE_RESUME_INTERRUPTED_TURN): the host's CLAUDE_CODE_RESUME_REASON when it set one (host_draining, checkpoint_restore, container_recreated, …), else 'interrupted_turn'. Stamped on the same reply frames as user_message_uuid (which on such a re-run names the interrupted turn's own last user prompt), so a consumer can tell the re-run's first reply from the interrupted attempt's. Absent on every other turn, on thinking_tokens frames, and from older producers.
     */
    resume_reason?: string;
};

// ====== SDKResultSuccess
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
    /**
     * Cumulative estimated cost in USD for this query() call, covering the same query-pipeline calls as modelUsage and sharing its lifecycle: cumulative across turns in streaming-input sessions — each result carries the running total so far, so read the latest result rather than summing across results. Crash/startup-error results may carry zeroed values, a resumed or forked session continues from the total its transcript saved, when it has one (so the first result already carries the earlier turns; maxBudgetUsd counts only the spend since this query() call started or last /clear), and a mid-session /clear resets the running total. An estimate, not a billing statement.
     */
    total_cost_usd: number;
    /**
     * MAIN AGENT LOOP ONLY — excludes Task subagent, sidechain, and auxiliary model calls, and is per-turn in streaming-input sessions. Prefer modelUsage for token/cost accounting.
     */
    usage: NonNullableUsage;
    /**
     * Per-model totals for every model call made through the query pipeline during this query() call — main loop, Task subagents, sidechains, and internal calls such as compaction and Workflow agents. Cumulative across turns in streaming-input sessions: each result carries the running total so far, so read the latest result rather than summing across results. Internal helper calls outside the query pipeline (e.g. the permission classifier, token-count probes) are excluded; crash/startup-error results may carry zeroed usage, a resumed or forked session continues from the totals its transcript saved, when it has them (so the first result already carries the earlier turns), and a mid-session /clear resets the running total. The correct field for token/cost accounting; treat it as an estimate, not a billing statement.
     */
    modelUsage: Record<string, ModelUsage>;

    permission_denials: SDKPermissionDenial[];
    /**
     * User-initiated sends still waiting in the command queue when this result was produced. Greater than 0 means at least one more user turn (and result) follows without further input, barring cancellation; 0 means none is pending, or the session is ending (end_session or a shutdown latched mid-turn discards the backlog). Queued sends may coalesce into fewer turns, so this counts pending sends, not remaining results. System-generated queue entries are not counted. Absent on fatal startup results and on surfaces without a command queue.
     */
    queued_turn_count?: number;
    structured_output?: unknown;
    deferred_tool_use?: SDKDeferredToolUse;
    terminal_reason?: TerminalReason;
    /**
     * Delivery sequence of this result within the run: how many results the run numbered before this one, starting at 0, in the order the process writes them. A result held back while background work finishes is numbered when it is finally written, not when its text was produced; a result whose write fails still consumes its number, so a gap in a stream-json sequence means a result was lost. Distinct from num_turns, which counts model round-trips within one turn. Numbered by the process that hosts the run (`claude -p`, stream-json): a local client relaying a cloud session passes the cloud session's numbering through and its own locally built error results carry none; the in-process engine surface does not number yet. Absent from older producers.
     */
    result_index?: number;
    fast_mode_state?: FastModeState;
    fast_mode_disabled_reason?: FastModeDisabledReason;
    origin?: SDKMessageOrigin;
    uuid: UUID;
    session_id: string;
};

// ====== SDKResultError
export declare type SDKResultError = {
    type: 'result';
    subtype: 'error_during_execution' | 'error_max_turns' | 'error_max_budget_usd' | 'error_max_structured_output_retries';
    duration_ms: number;
    duration_api_ms: number;
    is_error: boolean;
    num_turns: number;
    stop_reason: string | null;
    /**
     * Cumulative estimated cost in USD for this query() call, covering the same query-pipeline calls as modelUsage and sharing its lifecycle: cumulative across turns in streaming-input sessions — each result carries the running total so far, so read the latest result rather than summing across results. Crash/startup-error results may carry zeroed values, a resumed or forked session continues from the total its transcript saved, when it has one (so the first result already carries the earlier turns; maxBudgetUsd counts only the spend since this query() call started or last /clear), and a mid-session /clear resets the running total. An estimate, not a billing statement.
     */
    total_cost_usd: number;
    /**
     * MAIN AGENT LOOP ONLY — excludes Task subagent, sidechain, and auxiliary model calls, and is per-turn in streaming-input sessions. Prefer modelUsage for token/cost accounting.
     */
    usage: NonNullableUsage;
    /**
     * Per-model totals for every model call made through the query pipeline during this query() call — main loop, Task subagents, sidechains, and internal calls such as compaction and Workflow agents. Cumulative across turns in streaming-input sessions: each result carries the running total so far, so read the latest result rather than summing across results. Internal helper calls outside the query pipeline (e.g. the permission classifier, token-count probes) are excluded; crash/startup-error results may carry zeroed usage, a resumed or forked session continues from the totals its transcript saved, when it has them (so the first result already carries the earlier turns), and a mid-session /clear resets the running total. The correct field for token/cost accounting; treat it as an estimate, not a billing statement.
     */
    modelUsage: Record<string, ModelUsage>;

    permission_denials: SDKPermissionDenial[];
    /**
     * User-initiated sends still waiting in the command queue when this result was produced. Greater than 0 means at least one more user turn (and result) follows without further input, barring cancellation; 0 means none is pending, or the session is ending (end_session or a shutdown latched mid-turn discards the backlog). Queued sends may coalesce into fewer turns, so this counts pending sends, not remaining results. System-generated queue entries are not counted. Absent on fatal startup results and on surfaces without a command queue.
     */
    queued_turn_count?: number;
    errors: string[];

    /**
     * Set on the zeroed error_during_execution result a stream-json run writes before exiting on a known startup failure; errors carries the same text as stderr. Failures that used to end with stderr alone write that result only when the host sets CLAUDE_CODE_STARTUP_FAILURE_RESULTS. Absent on every other result, on startup failures without a known cause, and from older producers.
     */
    startup_failure_reason?: SDKStartupFailureReason;
    /**
     * Client uuid of the user message that triggered this turn (submitMessage options.uuid), echoed back so a consumer can link this error result to the send it answers — the same join key the success variant echoes, carried alone (error turns have no request_sent_wall_ms to report). A delivery-failure result from the remote-session client echoes the failed send's queue key, which is client-minted when the host sent no uuid of its own. A synthetic/scheduled (meta) turn's own uuid is echoed only when the host vouches it is the client event's own (delivered content such as a Slack owner ping or a Slack-bot observation); a meta turn that folded queued user messages in mid-turn, vouched or not, echoes the LAST of them. Absent on turns that neither had a client uuid nor folded a user message in, on session-scoped failures with no single triggering send (a crashed worker's zeroed result), and from older producers.
     */
    user_message_uuid?: string;
    /**
     * Client uuids of every user message whose prompt this turn consumed, in consumption order — all members of a prompt batch the host merged into this one turn (several messages sent close together run as one turn whose user_message_uuid is the LAST member's), then any queued user message folded into the running turn between tool rounds, once taken off the queue — so a consumer that sent any of them can bind this result to its own send by finding its uuid anywhere in the list. Always contains user_message_uuid; at most 64 entries; can be longer than the list on the turn's first reply frame. Present when a headless turn that ran echoes user_message_uuid; absent on delivery-failure and zeroed results and from older producers (fall back to user_message_uuid).
     */
    user_message_uuids?: string[];
    /**
     * Why this turn was the automatic re-run of a turn a worker restart interrupted (CLAUDE_CODE_RESUME_INTERRUPTED_TURN): the host's CLAUDE_CODE_RESUME_REASON when it set one (host_draining, checkpoint_restore, container_recreated, …), else 'interrupted_turn'. Present on a headless re-run's result, success or error, with or without an echo (a re-run whose opener could not be vouched still carries the reason); absent on every other turn, on the Remote Control bridge's per-turn synthetic results, and from older producers.
     */
    resume_reason?: string;
    terminal_reason?: TerminalReason;
    /**
     * Delivery sequence of this result within the run: how many results the run numbered before this one, starting at 0, in the order the process writes them. A result held back while background work finishes is numbered when it is finally written, not when its text was produced; a result whose write fails still consumes its number, so a gap in a stream-json sequence means a result was lost. Distinct from num_turns, which counts model round-trips within one turn. Numbered by the process that hosts the run (`claude -p`, stream-json): a local client relaying a cloud session passes the cloud session's numbering through and its own locally built error results carry none; the in-process engine surface does not number yet. Absent from older producers.
     */
    result_index?: number;
    fast_mode_state?: FastModeState;
    fast_mode_disabled_reason?: FastModeDisabledReason;
    origin?: SDKMessageOrigin;
    uuid: UUID;
    session_id: string;
};

// ====== TerminalReason
/**
 * Why the query loop terminated. Unset when the loop was bypassed (local slash command).
 */
export declare type TerminalReason = 'blocking_limit' | 'rapid_refill_breaker' | 'prompt_too_long' | 'image_error' | 'model_error' | 'api_error' | 'malformed_tool_use_exhausted' | 'aborted_streaming' | 'aborted_tools' | 'stop_hook_prevented' | 'hook_stopped' | 'tool_deferred' | 'max_turns' | 'background_requested' | 'completed' | 'budget_exhausted' | 'structured_output_retry_exhausted' | 'tool_deferred_unavailable' | 'turn_setup_failed';

// ====== SDKPermissionDenial
export declare type SDKPermissionDenial = {
    tool_name: string;
    tool_use_id: string;
    tool_input: Record<string, unknown>;
};

// ====== SDKCompactBoundaryMessage
export declare type SDKCompactBoundaryMessage = {
    type: 'system';
    subtype: 'compact_boundary';
    compact_metadata: {
        trigger: 'manual' | 'auto';
        pre_tokens: number;
        post_tokens?: number;

        duration_ms?: number;

        /**
         * Relink info for messagesToKeep. Loaders splice the preserved segment at anchor_uuid (summary for suffix-preserving, boundary for prefix-preserving partial compact) so resume includes preserved content. Unset when compaction summarizes everything (no messagesToKeep).
         */
        preserved_segment?: {
            head_uuid: UUID;
            anchor_uuid: UUID;
            tail_uuid: UUID;
        };
        /**
         * Ordered messagesToKeep UUIDs. Supersedes preserved_segment — readers look up each UUID directly and relink uuids[i] to uuids[i-1] (uuids[0] to anchor_uuid) instead of walking the parentUuid chain. Unset when compaction summarizes everything.
         */
        preserved_messages?: {
            anchor_uuid: UUID;
            uuids: UUID[];

        };
    };

    uuid: UUID;
    session_id: string;

};

// ====== SDKStatusMessage
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

// ====== SDKStatus
export declare type SDKStatus = 'compacting' | 'requesting' | null;

// ====== SDKAPIRetryMessage
/**
 * Emitted when an API request fails with a retryable error and will be retried after a delay. error_status is null for connection errors (e.g. timeouts) that had no HTTP response.
 */
export declare type SDKAPIRetryMessage = {
    type: 'system';
    subtype: 'api_retry';
    attempt: number;
    max_retries: number;
    retry_delay_ms: number;
    error_status: number | null;
    error: SDKAssistantMessageError;
    /**
     * Present only when the API sent no response headers within the first-byte window (CLAUDE_STREAM_FIRST_BYTE_TIMEOUT_MS): waited_ms is how long the failed attempt waited for headers, retry_wait_ms how long the retry will wait for them. For this cause max_retries is its own cap (normally one retry), not the session budget.
     */
    no_response?: {
        waited_ms: number;
        retry_wait_ms: number;
    };
    uuid: UUID;
    session_id: string;
};

// ====== SDKRateLimitEvent
/**
 * Rate limit event emitted when rate limit info changes.
 */
export declare type SDKRateLimitEvent = {
    type: 'rate_limit_event';
    /**
     * Rate limit information for claude.ai subscription users.
     */
    rate_limit_info: SDKRateLimitInfo;
    uuid: UUID;
    session_id: string;
};

// ====== SDKRateLimitInfo
/**
 * Rate limit information for claude.ai subscription users.
 */
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

    /**
     * Which spend limit blocked the request when it is not the member's own cap: 'group_pool' means a pooled group budget shared by the member's team is used up (the denial otherwise looks like the member's own monthly cap). Absent on a plain member denial and from older CLIs.
     */
    limitScope?: 'service' | 'channel' | 'group_pool';
    errorCode?: 'credits_required';
    canUserPurchaseCredits?: boolean;
    hasChargeableSavedPaymentMethod?: boolean;
};

// ====== SDKUsageReport
/**
 * Structured twin of a /usage result, carried beside its text: the session's totals, the plan's usage rows as the server sent them and the extra-usage spend, and nothing else from the usage body (the get_usage control reply carries the rest). Experimental — the shape may change.
 */
export declare type SDKUsageReport = {
    /**
     * Cost and usage accumulated by the current session.
     */
    session: {
        total_cost_usd: number;
        total_api_duration_ms: number;
        total_duration_ms: number;
        total_lines_added: number;
        total_lines_removed: number;
        model_usage: Record<string, ModelUsage>;
    };
    /**
     * The plan's usage rows and extra-usage spend from the claude.ai usage endpoint; null when the CLI could not fetch them (no plan on this lane, or a token without the profile scope).
     */
    rate_limits: {
        /**
         * The server's usage rows (the usage endpoint's limits[]), as sent: which meters apply, their scope, labels, severity and order are the server's, so a client renders them verbatim and a new meter needs no client release. Empty when the server reported no meters; null when the body carried no rows at all (a server that predates them). Null too while the usage fetch is failing: the rows here are only ever the server's current reply, so neither the row the CLI builds from rate-limit response headers for its own screen nor its snapshot of an earlier reply appears here.
         */
        limits: {
            /**
             * The server's meter kind, e.g. 'session', 'weekly_all' or 'weekly_scoped'. Classify a row on this, never on a label.
             */
            kind: string;
            /**
             * The server's row group, e.g. 'session' or 'weekly'; rows render grouped under it, in the server's order.
             */
            group: string;
            /**
             * Share of the window used, 0-100.
             */
            percent: number;
            /**
             * ISO 8601 timestamp when the window resets.
             */
            resets_at: string | null;
            /**
             * What a scoped row is for, a model or a surface, with the server's display label.
             */
            scope?: {
                model?: {
                    display_name: string;
                } | null;
                surface?: {
                    display_name: string;
                } | null;
            } | null;
            /**
             * The server's reading of the row for a meter's colour, e.g. 'normal', 'warning' or 'critical'. Every row here is the server's, so a client never grades a row itself.
             */
            severity: string;
            /**
             * The server's headline pick: the row a single-value indicator shows.
             */
            is_active: boolean;
        }[] | null;
        /**
         * Extra-usage (overage) spend for the billing period, when the plan has it. Amounts are in minor units of `currency` (cents for USD); is_enabled is false while extra usage cannot cover sends.
         */
        extra_usage?: {
            is_enabled: boolean;
            monthly_limit: number | null;
            used_credits: number | null;
            utilization: number | null;
            currency?: string | null;
        } | null;
    } | null;
};

// ====== SDKControlGetUsageResponse
/**
 * Structured /usage data: session cost/usage totals plus claude.ai plan rate-limit utilization. Experimental — the shape may change.
 */
export declare type SDKControlGetUsageResponse = {
    /**
     * Cost and usage accumulated by the current session.
     */
    session: {
        total_cost_usd: number;
        total_api_duration_ms: number;
        total_duration_ms: number;
        total_lines_added: number;
        total_lines_removed: number;
        model_usage: Record<string, coreTypes.ModelUsage>;
    };
    /**
     * Claude.ai subscription type ('pro', 'max', 'team', 'enterprise') or null for API key / 3P provider sessions.
     */
    subscription_type: string | null;
    /**
     * False when plan rate limits do not apply (API key, Bedrock, Vertex, or missing profile scope) — rate_limits will be null.
     */
    rate_limits_available: boolean;
    /**
     * Plan rate-limit utilization windows from the claude.ai usage endpoint, or null when unavailable.
     */
    rate_limits: {
        five_hour?: {
            /**
             * Percentage of the window used, 0-100.
             */
            utilization: number | null;
            /**
             * ISO 8601 timestamp when the window resets.
             */
            resets_at: string | null;
        } | null;
        seven_day?: {
            /**
             * Percentage of the window used, 0-100.
             */
            utilization: number | null;
            /**
             * ISO 8601 timestamp when the window resets.
             */
            resets_at: string | null;
        } | null;
        seven_day_oauth_apps?: {
            /**
             * Percentage of the window used, 0-100.
             */
            utilization: number | null;
            /**
             * ISO 8601 timestamp when the window resets.
             */
            resets_at: string | null;
        } | null;
        seven_day_opus?: {
            /**
             * Percentage of the window used, 0-100.
             */
            utilization: number | null;
            /**
             * ISO 8601 timestamp when the window resets.
             */
            resets_at: string | null;
        } | null;
        seven_day_sonnet?: {
            /**
             * Percentage of the window used, 0-100.
             */
            utilization: number | null;
            /**
             * ISO 8601 timestamp when the window resets.
             */
            resets_at: string | null;
        } | null;
        /**
         * Per-model weekly windows from the server limits[] array, filtered by the overage-included-models allowlist. Additive: absent when nothing is known about them (an answer served from cached data, or rows the allowlist hides); an empty array means the endpoint itself answered and listed no per-model weekly window at all for this account, before the allowlist was applied.
         */
        model_scoped?: {
            /**
             * Server-supplied label for the model bucket (e.g. 'Fable').
             */
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
    /**
     * What's contributing to limits usage, from a scan of local transcripts on this machine (the same data the /usage dialog renders): behavioral characteristics plus per-skill/agent/plugin/MCP-server attribution. Approximate, excludes other devices and claude.ai. Null for non-claude.ai-subscriber sessions (mirrors the dialog) or when the scan fails.
     */
    behaviors: {
        /**
         * Last 24 hours.
         */
        day: {
            /**
             * API requests found in local transcripts for this window.
             */
            request_count: number;
            /**
             * Distinct sessions observed in this window.
             */
            session_count: number;
            /**
             * Behavioral characteristics of local usage. Categories overlap — this is not a partition, so percentages do not sum to 100.
             */
            behaviors: {
                key: 'cache_miss' | 'long_context' | 'subagent_heavy' | 'high_parallel' | 'cron';
                /**
                 * Share of the weighted local usage attributed to this behavior, 0-100.
                 */
                pct: number;
                /**
                 * Requests in this window exhibiting the behavior.
                 */
                count: number;
            }[];
            agents: {
                name: string;
                /**
                 * Share of the weighted local usage attributed to this item, 0-100.
                 */
                pct: number;
            }[];
            skills: {
                name: string;
                /**
                 * Share of the weighted local usage attributed to this item, 0-100.
                 */
                pct: number;
            }[];
            plugins: {
                name: string;
                /**
                 * Share of the weighted local usage attributed to this item, 0-100.
                 */
                pct: number;
            }[];
            mcp_servers: {
                name: string;
                /**
                 * Share of the weighted local usage attributed to this item, 0-100.
                 */
                pct: number;
            }[];
        };
        /**
         * Last 7 days.
         */
        week: {
            /**
             * API requests found in local transcripts for this window.
             */
            request_count: number;
            /**
             * Distinct sessions observed in this window.
             */
            session_count: number;
            /**
             * Behavioral characteristics of local usage. Categories overlap — this is not a partition, so percentages do not sum to 100.
             */
            behaviors: {
                key: 'cache_miss' | 'long_context' | 'subagent_heavy' | 'high_parallel' | 'cron';
                /**
                 * Share of the weighted local usage attributed to this behavior, 0-100.
                 */
                pct: number;
                /**
                 * Requests in this window exhibiting the behavior.
                 */
                count: number;
            }[];
            agents: {
                name: string;
                /**
                 * Share of the weighted local usage attributed to this item, 0-100.
                 */
                pct: number;
            }[];
            skills: {
                name: string;
                /**
                 * Share of the weighted local usage attributed to this item, 0-100.
                 */
                pct: number;
            }[];
            plugins: {
                name: string;
                /**
                 * Share of the weighted local usage attributed to this item, 0-100.
                 */
                pct: number;
            }[];
            mcp_servers: {
                name: string;
                /**
                 * Share of the weighted local usage attributed to this item, 0-100.
                 */
                pct: number;
            }[];
        };
    } | null;
};

// ====== SDKSessionStateChangedMessage
/**
 * Mirrors notifySessionStateChanged. 'idle' fires after heldBackResult flushes and the bg-agent do-while exits — authoritative turn-over signal.
 */
export declare type SDKSessionStateChangedMessage = {
    type: 'system';
    subtype: 'session_state_changed';
    state: 'idle' | 'running' | 'requires_action';
    uuid: UUID;
    session_id: string;
};

// ====== SDKTaskStartedMessage
export declare type SDKTaskStartedMessage = {
    type: 'system';
    subtype: 'task_started';
    task_id: string;
    tool_use_id?: string;
    description: string;
    /**
     * Subagent type for Task tool subagents.
     */
    subagent_type?: string;
    /**
     * Whether the task was registered in the background (true) or in the foreground with the spawning tool call blocking on it (false). A resumed subagent is always registered in the background. A later move to the background arrives as task_updated patch.is_backgrounded. Set for local_agent and local_bash tasks.
     */
    is_backgrounded?: boolean;
    /**
     * Nesting depth of a spawned subagent (local_agent) task: 1 for a top-level spawn, N+1 when spawned from inside a depth-N agent. Not set on other tasks.
     */
    spawn_depth?: number;
    task_type?: string;
    /**
     * meta.name from the workflow script (e.g. 'spec'). Only set when task_type is 'local_workflow'.
     */
    workflow_name?: string;
    prompt?: string;
    /**
     * Ambient/housekeeping task. Consumers should hide this from the inline transcript; it may still appear in a tasks panel.
     */
    skip_transcript?: boolean;
    /**
     * True for tasks that are not activity (every skip_transcript task, plus every live-update watcher, requested or auto-started); hosts should exclude them from activity indicators.
     */
    ambient?: boolean;
    uuid: UUID;
    session_id: string;
};

// ====== SDKTaskProgressMessage
export declare type SDKTaskProgressMessage = {
    type: 'system';
    subtype: 'task_progress';
    task_id: string;
    tool_use_id?: string;
    description: string;
    /**
     * Subagent type for Task tool subagents.
     */
    subagent_type?: string;
    usage: {
        total_tokens: number;
        tool_uses: number;
        duration_ms: number;
    };
    last_tool_name?: string;
    /**
     * A one-line status for the task's row. For a local_agent task it is the model-generated progress summary (only when the agentProgressSummaries option is on); for a backgrounded mcp_task it is the MCP server's own bounded status message, emitted once per change without any option. Render it when present regardless of task type.
     */
    summary?: string;

    uuid: UUID;
    session_id: string;
};

// ====== SDKTaskUpdatedMessage
export declare type SDKTaskUpdatedMessage = {
    type: 'system';
    subtype: 'task_updated';
    task_id: string;
    /**
     * Wire-safe subset of TaskState fields that changed. Excludes abortController, messages, result. Clients merge into their local task map.
     */
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

// ====== SDKTaskNotificationMessage
export declare type SDKTaskNotificationMessage = {
    type: 'system';
    subtype: 'task_notification';
    task_id: string;
    tool_use_id?: string;
    status: 'completed' | 'failed' | 'stopped';
    /**
     * Machine-readable cause, set only when the task did not end through an ordinary completion, failure, or stop. 'worker_restart': the worker process restarted and the resumed process found the task orphaned (always with status 'stopped').
     */
    reason?: 'worker_restart';
    output_file: string;
    summary: string;
    usage?: {
        total_tokens: number;
        tool_uses: number;
        duration_ms: number;
    };
    /**
     * CLI-owned: for a backgrounded MCP task (task_type mcp_task) that completed, the `resource_link` content blocks of its final result — the files it returned by reference — collected from the raw result before the CLI renders it as the text the model reads. A backgrounded task's tool_result is the placeholder text and its real result arrives as this notification, so this is where a host learns which files that tool call produced; join to the originating call via tool_use_id. Same fields and caps as tool_use_result.resourceLinks (at most 50 links, 64 KiB serialized), absent when the result had none or the task is any other type. Never populated from the server's _meta.
     */
    resource_links?: SDKMcpResourceLink[];
    skip_transcript?: boolean;
    /**
     * True for tasks that are not activity (every skip_transcript task, plus every live-update watcher, requested or auto-started); hosts should exclude them from activity indicators.
     */
    ambient?: boolean;
    uuid: UUID;
    session_id: string;
};

// ====== SDKBackgroundTasksChangedMessage
/**
 * The full set of live background tasks, emitted whenever membership changes (start, completion, kill, a foreground agent being backgrounded) or an entry's `ambient` flag flips. A level signal, unlike the task_started/task_notification edge bookends: consumers that only need 'is background work running' should replace their set with each payload rather than pairing edges, so a missed bookend cannot wedge a stale running indicator. Ordering relative to the bookends for the same transition is unspecified (in practice the level precedes them) and the payload carries ids only, so do not correlate it with the edge stream. The level is per-process: nothing is emitted at startup, so consumers must reset to the empty set whenever the session's CLI process (re)starts and let the next membership change repopulate it. A host that re-initializes an already-running process (a repeated `initialize` control request, e.g. after reconnecting) is sent a snapshot of the current set right behind the success response to that request, even when it is empty, so it need not wait for a change; CLIs that predate this send nothing there.
 */
export declare type SDKBackgroundTasksChangedMessage = {
    type: 'system';
    subtype: 'background_tasks_changed';
    /**
     * Every live background task after the change. REPLACE semantics: swap your set for this payload.
     */
    tasks: {
        task_id: string;
        task_type: string;
        description: string;
        /**
         * True for tasks that are not activity (every skip_transcript task, plus every live-update watcher, requested or auto-started); hosts should exclude them from activity indicators.
         */
        ambient?: boolean;
    }[];
    uuid: UUID;
    session_id: string;
};

// ====== SDKToolProgressMessage
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

// ====== SDKToolUseSummaryMessage
export declare type SDKToolUseSummaryMessage = {
    type: 'tool_use_summary';
    summary: string;
    preceding_tool_use_ids: string[];
    uuid: UUID;
    session_id: string;

};

// ====== SDKThinkingTokensMessage
/**
 * Live thinking-token estimate, digested from thinking_delta.estimated_tokens during the redacted-thinking phase (where the API otherwise streams only pings). estimated_tokens is the running total for the current thinking block; estimated_tokens_delta is the increment carried by this frame. Approximate progress for spinners/pills, not the authoritative billed output_tokens.
 */
export declare type SDKThinkingTokensMessage = {
    type: 'system';
    subtype: 'thinking_tokens';
    estimated_tokens: number;
    estimated_tokens_delta: number;
    /**
     * Client uuid of the user message that triggered this turn (submitMessage options.uuid), stamped on every thinking_tokens frame of a headless (stream-json / Agent SDK) turn so a consumer can attribute thinking progress to the send it answers before any reply frame arrives. On a synthetic/scheduled (meta) turn it names the last user message folded into the turn so far once one has been, else the turn's own uuid when the host vouches it is the client event's own (delivered content such as a Slack owner ping). Absent on turns that neither had a client uuid nor folded a user message in, on Remote Control (interactive terminal) sessions, and from older producers.
     */
    user_message_uuid?: string;
    uuid: UUID;
    session_id: string;
};

// ====== SDKNotificationMessage
/**
 * Loop-side text notification. Mirrors the interactive REPL notification queue (key/priority/timeout). JSX notifications are not emitted on this channel.
 */
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

// ====== SDKInformationalMessage
/**
 * Generic text banner emitted by the loop — non-error status lines, hook feedback (e.g. a UserPromptSubmit hook's block reason), slash-command output. Hosts render `content` as plaintext at the given level.
 */
export declare type SDKInformationalMessage = {
    type: 'system';
    subtype: 'informational';
    content: string;
    /**
     * Render level. 'info' shows only in transcript mode; 'notice' renders in inactive gray; 'suggestion' and 'warning' are more prominent.
     */
    level: 'info' | 'notice' | 'suggestion' | 'warning';
    /**
     * Dedupes progress messages for the same tool use.
     */
    tool_use_id?: string;
    /**
     * When true, execution stops after this message (e.g. a Stop hook denied continuation).
     */
    prevent_continuation?: boolean;
    uuid: UUID;
    session_id: string;
};

// ====== SDKPermissionDeniedMessage
/**
 * Emitted when a tool call is auto-denied without an interactive permission prompt (e.g. auto-mode classifier, dontAsk mode, headless-agent auto-deny, or a deny rule). With a permission prompt surface (stdio/SDK canUseTool), the 'ask' path surfaces via a can_use_tool control_request and this event covers the 'deny' short-circuit. Without one (bare -p / SDK query() with no canUseTool), 'ask' decisions are terminal, so this event also covers those implicit denials. Best-effort advisory: in rare races a denial can book without a frame or a frame can lack a booking twin — result.permission_denials is the authoritative record. Denials that resolve before canUseTool runs — PreToolUse hook denies, deny-rule overrides of hook allow/ask decisions, and file-tool calls (Read, Edit, Write) refused by a path-scoped deny rule — are not covered here, and neither is the MCP --permission-prompt-tool surface (the prompt tool is the host there).
 */
export declare type SDKPermissionDeniedMessage = {
    type: 'system';
    subtype: 'permission_denied';
    tool_name: string;
    tool_use_id: string;
    /**
     * Subagent ID when the denied tool call originated inside a subagent. Mirrors can_use_tool for host-side routing.
     */
    agent_id?: string;
    /**
     * Discriminator from PermissionDecisionReason (e.g. 'classifier', 'asyncAgent', 'mode', 'rule').
     */
    decision_reason_type?: string;

    /**
     * Human-readable reason from the deciding component, when available.
     */
    decision_reason?: string;
    /**
     * The rejection message returned to the model in the tool_result.
     */
    message: string;
    uuid: UUID;
    session_id: string;
};

// ====== SDKCommandsChangedMessage
/**
 * Fire-and-forget push of the full slash-command list after a mid-session change (e.g. skills discovered dynamically as the agent works in a subdirectory). Clients should REPLACE their cached command list with this payload; supportedCommands() tracks the latest push, so a re-fetch returns the same fresh list.
 */
export declare type SDKCommandsChangedMessage = {
    type: 'system';
    subtype: 'commands_changed';
    commands: SlashCommand[];
    uuid: UUID;
    session_id: string;
};

// ====== SDKConversationResetMessage
/**
 * Emitted by /clear, plan-mode exit, fresh-session, and onboarding flows. The surface should mount a fresh transcript under new_conversation_id and reset any cached session title. From internal QueryEvent 'conversation_reset'.
 */
export declare type SDKConversationResetMessage = {
    type: 'conversation_reset';
    new_conversation_id: UUID;
    uuid: UUID;
    session_id: string;
    /**
     * What discarded the conversation: 'clear' is the /clear command (or its /reset and /new aliases), 'plan_mode_exit' is leaving plan mode with the clear-context option, 'fresh_session' is a flow that starts a fresh session to implement an approved plan, 'onboarding' is an onboarding flow re-run inside an existing session. Informational: a consumer should reset on every conversation_reset frame whatever this says, and treat an absent (older emitter) or unrecognized value as an unspecified reset.
     */
    trigger?: 'clear' | 'plan_mode_exit' | 'fresh_session' | 'onboarding';
    /**
     * Only with trigger 'clear': the uuid of the user message whose /clear was executed (the client's own uuid for that message when it came from a Remote Control or stream-json client, otherwise the uuid the CLI assigned to the typed command). Lets a consumer match this frame to a /clear message it has already seen, wiping once whichever arrives first, instead of relying on arrival order. Absent for the other triggers, when that uuid is not a canonical UUID, and from older emitters.
     */
    user_message_uuid?: string;
    /**
     * When the reset happened, as an ISO 8601 string in UTC read from the clock of the process that performed it. Meant for display, such as the time on a "conversation cleared" row, not for ordering frames. Absent from older emitters; a consumer can fall back to the time it received the frame.
     */
    timestamp?: string;
};

// ====== SDKPromptSuggestionMessage
/**
 * Predicted next user prompt, emitted after each turn when promptSuggestions is enabled.
 */
export declare type SDKPromptSuggestionMessage = {
    type: 'prompt_suggestion';
    suggestion: string;
    uuid: UUID;
    session_id: string;
};

// ====== SDKAuthStatusMessage
export declare type SDKAuthStatusMessage = {
    type: 'auth_status';
    isAuthenticating: boolean;
    output: string[];
    error?: string;
    uuid: UUID;
    session_id: string;
};

// ====== SDKModelRefusalFallbackMessage
/**
 * Emitted when the primary model ends the stream with stop_reason "refusal" and the turn is retried once on a fallback model (direction: "retry"). When `scope` is "session" (or absent — older CLIs), the swap is made persistent for the session; when `scope` is "local", only that subagent/side-question response came from the fallback model and the session model is unchanged. "revert" and "sticky" are retained in the enum for SDK-consumer compat and are no longer emitted.
 */
export declare type SDKModelRefusalFallbackMessage = {
    type: 'system';
    subtype: 'model_refusal_fallback';
    trigger: 'refusal';
    direction: 'retry' | 'revert' | 'sticky';
    /**
     * 'session': the main thread fell back and the session model is swapped. 'local': a subagent / side-question (/btw) / background fork fell back — only that response came from the fallback model and the session model is unchanged. Absent from older CLIs (treat as 'session').
     */
    scope?: 'session' | 'local';
    original_model: string;
    fallback_model: string;
    request_id: string | null;
    /**
     * The refusal category ('cyber', 'bio', …): stop_details.category from the refused API response (client lane), or the fallback block's server-gated trigger.category (server lane). Open string — new categories ship on the wire ahead of schema updates. null when neither source carried a category (normal, not an error). Absent when emitted by an older CLI.
     */
    api_refusal_category?: string | null;

    /**
     * stop_details.explanation from the refused API response (client lane only — the server-lane trigger carries no explanation). Unstable human prose — display only, never parse. null/absent when the response carried none, and always null on server-lane banners.
     */
    api_refusal_explanation?: string | null;
    /**
     * Wire uuids of the messages this fallback retracted — the refused partial as the consumer received it (one uuid per normalized SDK message; multi-block messages carry per-block derived uuids) plus any tombstoned tool_results. Emitted AFTER the retraction, so this is a resolution-time eviction signal: remove these messages from transcript state on receipt. Eviction is idempotent — unknown or already-removed uuids are a no-op. Absent when emitted by an older CLI.
     */
    retracted_message_uuids?: string[];
    /**
     * UUID of the user message the refused request was for — the rewind target and composer prefill for edit-and-retry. This is the message's own uuid as delivered on the replay ack (not a per-block normalized uuid). null when the refused turn was not human-authored (e.g. a background task notification or auto-continuation — nothing to edit-and-retry) or otherwise cannot be identified; absent from older CLIs.
     */
    refused_user_message_uuid?: string | null;
    content: string;
    uuid: UUID;
    session_id: string;
};

// ====== SDKHookStartedMessage
export declare type SDKHookStartedMessage = {
    type: 'system';
    subtype: 'hook_started';
    hook_id: string;
    hook_name: string;
    hook_event: string;
    uuid: UUID;
    session_id: string;
};

// ====== SDKHookProgressMessage
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

// ====== SDKHookResponseMessage
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

// ====== SDKControlRequest
/**
 * Envelope for a control-protocol request, sent by either side on the same stream as the messages. The receiver normally answers with exactly one control_response carrying the same request_id (a few request types document when no answer is sent), and a requester ignores responses for request_ids it is not waiting on. Each request type's own documentation says which side sends it and what its success response carries.
 */
export declare type SDKControlRequest = {
    type: 'control_request';
    /**
     * Chosen by the sender, unique among its in-flight requests; the control_response (and any control_cancel_request) for this request echoes it.
     */
    request_id: string;
    request: SDKControlRequestInner;

};

// ====== SDKControlRequestInner
declare type SDKControlRequestInner = SDKControlInterruptRequest | SDKControlPermissionRequest | SDKControlInitializeRequest | SDKControlSetPermissionModeRequest | SDKControlSetModelRequest | SDKControlSetMaxThinkingTokensRequest | SDKControlRenameSessionRequest | SDKControlSetColorRequest | SDKControlMcpStatusRequest | SDKControlGetContextUsageRequest | SDKControlGetSessionCostRequest | SDKControlListModelsRequest | SDKControlGetUsageRequest | SDKControlGetBinaryVersionRequest | SDKControlMcpCallRequest | SDKControlFileSuggestionsRequest | SDKHookCallbackRequest | SDKControlMcpMessageRequest | SDKControlRewindFilesRequest | SDKControlCancelAsyncMessageRequest | SDKControlReadFileRequest | SDKControlSeedReadStateRequest | SDKControlMcpSetServersRequest | SDKControlRegisterRepoRootRequest | SDKControlReloadPluginsRequest | SDKControlReloadSkillsRequest | SDKControlReloadOutputStylesRequest | SDKControlMcpReconnectRequest | SDKControlMcpToggleRequest | SDKControlStopTaskRequest | SDKControlBackgroundTasksRequest | SDKControlGetTaskOutputRequest | SDKControlApplyFlagSettingsRequest | SDKControlGetSettingsRequest | SDKControlGetHooksListingRequest | SDKControlUpdateSettingsRequest | SDKControlElicitationRequest | SDKControlRequestUserDialogRequest | SDKControlListPermissionRulesRequest | SDKControlMcpReadResourceRequest;

// ====== SDKControlResponse
/**
 * Envelope for the single reply to a control_request, sent by whichever side received the request.
 */
export declare type SDKControlResponse = {
    type: 'control_response';
    response: ControlResponse | ControlErrorResponse;

};

// ====== ControlResponse
/**
 * The request was handled.
 */
declare type ControlResponse = {
    subtype: 'success';
    /**
     * The request_id of the control_request this answers.
     */
    request_id: string;
    /**
     * The success payload, shaped as documented for the answered request's subtype; absent or {} for requests that are merely acknowledged.
     */
    response?: Record<string, unknown>;
    /**
     * can_use_tool requests this CLI process has issued and not yet resolved, so a client joining an already-initialized session learns about in-flight prompts. Always present (possibly empty) on a success `initialize` response from Claude Code v2.1.268 or later; earlier versions could omit it, so treat absence as an older CLI rather than as "nothing pending". A prompt inherited from a previous worker of the same session can remain answerable without appearing here and without a control_cancel_request; session_state "requires_action" on the same reply signals one the CLI is holding, but not every inherited prompt is signalled.
     */
    pending_permission_requests?: SDKControlRequest[];
    /**
     * request_user_dialog requests this CLI process has issued and not yet resolved (sibling of pending_permission_requests, with the same inherited-prompt caveat), so a client joining an already-initialized session can re-arm in-flight dialogs. Always present (possibly empty) on a success `initialize` response from Claude Code v2.1.268 or later; earlier versions could omit it, so treat absence as an older CLI rather than as "nothing pending". Receivers must tolerate the same request_id also arriving as a live or replayed control_request frame and render it once.
     */
    pending_user_dialog_requests?: SDKControlRequest[];
};

// ====== ControlErrorResponse
/**
 * The request failed or was rejected (unknown subtype, invalid arguments, or an error while handling it).
 */
declare type ControlErrorResponse = {
    subtype: 'error';
    /**
     * The request_id of the control_request this answers.
     */
    request_id: string;
    /**
     * Human-readable failure description.
     */
    error: string;

    /**
     * can_use_tool requests this CLI process has issued and not yet resolved, so a client joining an already-initialized session learns about in-flight prompts. Always present (possibly empty) on a success `initialize` response from Claude Code v2.1.268 or later; earlier versions could omit it, so treat absence as an older CLI rather than as "nothing pending". A prompt inherited from a previous worker of the same session can remain answerable without appearing here and without a control_cancel_request; session_state "requires_action" on the same reply signals one the CLI is holding, but not every inherited prompt is signalled.
     */
    pending_permission_requests?: SDKControlRequest[];
    /**
     * request_user_dialog requests this CLI process has issued and not yet resolved (sibling of pending_permission_requests, with the same inherited-prompt caveat), so a client joining an already-initialized session can re-arm in-flight dialogs. Always present (possibly empty) on a success `initialize` response from Claude Code v2.1.268 or later; earlier versions could omit it, so treat absence as an older CLI rather than as "nothing pending". Receivers must tolerate the same request_id also arriving as a live or replayed control_request frame and render it once.
     */
    pending_user_dialog_requests?: SDKControlRequest[];
};

// ====== SDKControlCancelRequest
/**
 * Tells the other side that the sender no longer needs the answer to one of its own in-flight control_requests (for example a pending can_use_tool prompt after the turn was interrupted, or one that another client already answered). Either side may send it for a request it originated. The sender stops waiting at once and ignores any control_response that still arrives for that request_id; a receiver that can abort the work does so and may still reply (typically with an error), otherwise it simply completes the request. There is no reply to the cancel itself.
 */
declare type SDKControlCancelRequest = {
    type: 'control_cancel_request';
    /**
     * The request_id of the control_request being withdrawn.
     */
    request_id: string;
};

// ====== SDKKeepAliveMessage
/**
 * Liveness heartbeat with no payload. Either side may send it at any time (the CLI emits it periodically, for example while a long-running control request is in progress); receivers must ignore it.
 */
declare type SDKKeepAliveMessage = {
    type: 'keep_alive';
};

// ====== SDKControlInitializeRequest
/**
 * Initializes the SDK session with hooks, MCP servers, and agent configuration.
 */
declare type SDKControlInitializeRequest = {
    subtype: 'initialize';
    hooks?: Partial<Record<coreTypes.HookEvent, SDKHookCallbackMatcher[]>>;
    sdkMcpServers?: string[];
    /**
     * Settings for the SDK-hosted MCP servers named in sdkMcpServers, keyed by server name. Sent as a separate field so a CLI that predates it ignores it; entries whose name is not in sdkMcpServers, and values that do not match this shape, are ignored rather than rejected. Applied when the server is first registered.
     */
    sdkMcpServerConfigs?: Record<string, {
        /**
         * Per-server tool-call timeout in milliseconds. Overrides the MCP_TOOL_TIMEOUT environment variable for this server. Hard wall-clock limit per call; progress notifications do not extend it. Values below 1000ms are ignored (falls through to MCP_TOOL_TIMEOUT or the default). Applies when the server is first registered; changing it for an already-registered server has no effect until it is removed and re-added.
         */
        timeout?: number;
    }>;
    /**
     * Optional, keyed by sdk server name (each key should also appear in sdkMcpServers; other keys are ignored). Unlike sdkMcpServerConfigs — host-declared settings the CLI keeps for the server's lifetime, same shape inline on mcp_set_servers — this is a one-shot cache of the servers' own handshake output: sent on initialize only, consumed by the connect that follows it, never retained. MCP handshake results the host already obtained from its in-process servers by delivering initialize + notifications/initialized (+ tools/list) to them itself before writing this request. For each such server the CLI answers its own MCP client's initialize and first tools/list from these results and skips the notifications/initialized round trip, so registering N in-process servers costs no mcp_message control round trips before the first turn; tools/call and everything after the handshake still flow as mcp_message exactly as before. The host MUST keep answering mcp_message for every server as if this field were absent: a CLI that predates the field ignores it and performs the full per-server handshake over the control channel, and a newer CLI does the same for any server whose entry is missing or malformed, whose initializeResult.protocolVersion differs from the MCP protocol version the CLI's client requests, or that the CLI had already connected. Entries apply only to the connect that follows this initialize; they are never retained for later reconnects. Over a remote session transport the CLI uses the field only when sdkMcpServerManifestsOrigin is set (see that field); a host on the CLI's own stream-json stdio transport needs no marker. sdk_mcp_manifests_parked in the response reports what became of each entry. Absent (older hosts, the Python SDK, browser clients): unchanged behaviour.
     */
    sdkMcpServerManifests?: Record<string, {
        /**
         * The server's verbatim JSON-RPC `initialize` result object (protocolVersion, capabilities, serverInfo, instructions, ...), exactly as the in-process server produced it when the host initialized it with no client capabilities — not re-serialized or schema-parsed by the host.
         */
        initializeResult: Record<string, unknown>;
        /**
         * The server's verbatim JSON-RPC `tools/list` result object. Omit when the initialize result does not advertise the tools capability, when the listing is paginated (nextCursor present), or when it could not be captured — the CLI then lists over the control channel as before.
         */
        toolsListResult?: Record<string, unknown>;
    }>;
    /**
     * The host's statement that it composed this request's sdkMcpServerManifests for this very send, from its servers' current state. Needed only by a host that reaches the CLI over a remote session transport, where an unmarked sdkMcpServerManifests is not used (a recorded registration could be handed to a later worker). The CLI also refuses a marked manifest whose session-stream frame is more than five minutes old, so capture the manifests when writing the request, not earlier; and it may still decline them when remote manifests are switched off in that CLI, or on any session where the session service has not told the CLI in the last five minutes that only the account owning the session can send events to it. sdk_mcp_manifests_parked in the response says what became of each entry. A value this CLI does not know counts as no marker. A host on the CLI's own stream-json stdio transport may omit this field; a host writing to the stdin of a remote-session worker cannot use manifests at all.
     */
    sdkMcpServerManifestsOrigin?: 'host_per_send';
    jsonSchema?: Record<string, unknown>;
    systemPrompt?: string[];
    appendSystemPrompt?: string;
    /**
     * Record the conversation's system prompt once and reuse it verbatim on every later request and resume. Omitted or true (the default): the prompt is rendered on the first request, systemPrompt or appendSystemPrompt included, and the record is sent as-is afterwards — even when a later launch passes different text — until compaction. false: never record; the prompt is rendered fresh every request. No effect where system-prompt recording is not yet enabled.
     */
    systemPromptSnapshot?: boolean;
    /**
     * Custom workflow body for the plan-mode system reminder. Replaces the default code-implementation phases; the CLI still wraps it with the read-only enforcement preamble and the ExitPlanMode protocol footer.
     */
    planModeInstructions?: string;

    /**
     * Map of tool-name aliases applied before name resolution. When the model emits a tool_use whose name is a key in this map, the tool execution path resolves the mapped name instead. Single-hop (no chains). See Options.toolAliases.
     */
    toolAliases?: Record<string, string>;
    /**
     * When true, omit per-user dynamic sections (working directory, auto-memory path) from the cached system prompt and re-inject them as the first user message. Lets cross-user prompt caching hit on a static system prompt prefix. Tradeoff: the model sees this context slightly later in the prompt, so steering on the working directory and memory location is marginally less authoritative. Has no effect when a custom (non-preset) system prompt is in use.
     */
    excludeDynamicSections?: boolean;
    agents?: Record<string, coreTypes.AgentDefinition>;
    /**
     * Custom session title. When provided, the session uses this title and skips automatic title generation. Has no effect on the persisted title when resuming an existing session.
     */
    title?: string;
    /**
     * When provided, only skills whose names match an entry are loaded into the main session system prompt, matching the exact canonical name (e.g. "my-plugin:my-skill") or a ":name" suffix of it. Display names and aliases do not match. Omit to load every discovered skill. Applies to the main session only; subagents use AgentDefinition.skills, which additionally resolves display names and aliases.
     */
    skills?: string[];

    promptSuggestions?: boolean;
    agentProgressSummaries?: boolean;
    forwardSubagentText?: boolean;
    /**
     * Dialog kinds (request_user_dialog `dialog_kind` values) this consumer's onUserDialog can actually render. The CLI treats ABSENCE as 'cannot display' and fails closed: without the kind declared here, a dialog-gated flow degrades to its no-dialog behavior (for 'refusal_fallback_prompt', the classic refusal error) instead of parking a dialog the consumer may mishandle. First-attached-client-wins on multi-client sessions; later initializes do not change it.
     */
    supportedDialogKinds?: string[];
    /**
     * Declares that this consumer renders a per-task stop control wired to the `stop_task` control request, so the user can stop an individual background task. When declared, an interrupt on an open-input (interactive stream-json) session spares running background agents/workflows (Stop only aborts the turn). Closed-input exception: a one-shot run (string prompt / -p closes stdin) still kills hold-back tasks at the held-result release regardless of the declaration — with stdin closed, a stop_task control could never be delivered, so the fail-closed kill stands. ABSENCE also fails closed: the interrupt kills background tasks, since the user would otherwise have no way to stop a runaway one. First-attached-client-wins on multi-client sessions; later initializes do not change it.
     */
    perTaskStopAffordance?: boolean;

    /**
     * Plugins to load for the session, in the same shape as the SDK `plugins` option: the stdin form of one --plugin-dir flag per entry (--plugin-dir-no-mcp when skipMcpDiscovery is set), so the launch command line does not grow with the plugin count. Loaded only by a CLI launched with --await-initialize, which reads this request during startup before any plugin work. Without that flag, on a repeated initialize, or over a remote session transport the field loads nothing; plugins_applied in the response reports whether the listed plugins are in fact loaded.
     */
    plugins?: coreTypes.SdkPluginConfig[];

};

// ====== SDKControlInitializeResponse
/**
 * Response from session initialization with available commands, models, and account info.
 */
export declare type SDKControlInitializeResponse = {
    commands: coreTypes.SlashCommand[];
    agents: coreTypes.AgentInfo[];
    output_style: string;
    available_output_styles: string[];

    models: coreTypes.ModelInfo[];

    /**
     * Information about the logged in user's account.
     */
    account: coreTypes.AccountInfo;

    /**
     * Whether the `hooks` this initialize carried were registered: true on a session's first initialize, and on a repeated initialize from the process that owns the CLI's stdin (its set replaces the one registered earlier); false when a repeated initialize's hooks were ignored (a client joining a remote session another client configured). Absent when the request carried no hooks, and on CLIs that predate the field — those ignored `hooks` on every repeated initialize.
     */
    hooks_applied?: boolean;
    /**
     * Whether every plugin this initialize listed is loaded: true when each one is among the plugins the process loaded at launch (from `plugins` under --await-initialize, or from --plugin-dir), so a re-sent initialize naming the launch set also reads true; false otherwise. The `plugins` field never loads anything after launch. Absent when the request listed no plugins, and on CLIs that predate the field (those never read `plugins`).
     */
    plugins_applied?: boolean;

    /**
     * What became of each entry of this initialize's sdkMcpServerManifests, keyed by sdk server name, for the entries whose name is in sdkMcpServers. 'parked': kept for the connect that follows this reply, which answers the server's MCP initialize and first tools/list from it (a later failure to replay shows up as live mcp_message frames, as when no entry was sent). 'already_connected': this CLI already had a live client for the server. 'protocol_version_mismatch': initializeResult.protocolVersion is not the version this CLI's client requests. 'malformed': the entry is not of the documented shape, reported whether or not manifests were honoured (every name in sdkMcpServers gets this when the field itself is not an object). 'not_honoured': the CLI did not use the entry: manifests or remote manifests are switched off in this CLI, the session service has not told this remote-session worker in the last five minutes that only the account owning the session can send events to it, or the request reached such a worker other than over its session stream (nothing for the host to change in any of these cases); or it came over the session stream without sdkMcpServerManifestsOrigin or on a frame too old to trust (the host's to fix). Absent when the request carried no sdkMcpServerManifests or named no sdkMcpServers, and on CLIs that predate the field.
     */
    sdk_mcp_manifests_parked?: Record<string, 'parked' | 'already_connected' | 'protocol_version_mismatch' | 'malformed' | 'not_honoured'>;

    fast_mode_state?: coreTypes.FastModeState;
    fast_mode_disabled_reason?: coreTypes.FastModeDisabledReason;

};

// ====== SDKControlPermissionRequest
/**
 * Requests permission to use a tool with the given input.
 */
declare type SDKControlPermissionRequest = {
    subtype: 'can_use_tool';
    tool_name: string;
    mcp_server?: coreTypes.McpServerProvenance;
    input: Record<string, unknown>;
    permission_suggestions?: coreTypes.PermissionUpdate[];
    blocked_path?: string;
    /**
     * Human-readable reason the ask escalated, for the consent line of the host's dialog. For decision_reason_type "subcommandResults" (compound bash), this is the NESTED safety check's warning text — the wrapper itself has no text — preferring a check that requires manual approval (classifier_approvable false); treat it with the same display/policy care as a "safetyCheck" reason. May carry ANSI escapes; sanitize before rendering.
     */
    decision_reason?: string;
    /**
     * Structured discriminator for why auto-mode escalated. Lets SDK hosts make policy (e.g. auto-deny safetyCheck) without parsing decision_reason text. For compound bash commands this is "subcommandResults" even when a safetyCheck is nested inside — check classifier_approvable for that case, and see decision_reason: for this variant it carries the nested safety check's warning text.
     */
    decision_reason_type?: 'rule' | 'mode' | 'subcommandResults' | 'permissionPromptTool' | 'hook' | 'asyncAgent' | 'sandboxOverride' | 'workingDir' | 'safetyCheck' | 'classifier' | 'other';

    /**
     * Set when a safetyCheck is present anywhere in the decision reason (including nested inside subcommandResults for compound bash). false = at least one safety check requires manual approval (e.g. Windows path bypass, dangerous rm); true = all safety checks MAY be classifier-approved (e.g. sensitive-file paths). Absent when no safetyCheck is involved.
     */
    classifier_approvable?: boolean;
    /**
     * True when the dialog must not offer the persistent "don't ask again" row for this ask: accepting it would write a whole-tool allow rule broader than the ask's own verb (PermissionAskDecision.suppressAlwaysAllowRule). Hosts rendering approve options should omit any persistent-rule affordance when set.
     */
    suppress_always_allow_rule?: boolean;
    /**
     * True when the ask must not be approvable by a single stray keystroke (PermissionAskDecision.defaultToNo): a terminal-style prompt opens on its decline option and takes no digit shortcut. Hosts rendering approve options should not pre-select approve when set.
     */
    default_to_no?: boolean;
    /**
     * Set when a user-configured ask RULE (permissions.ask) forced this prompt but the ask carries the tool's own decision_reason — the ask-rule substitution keeps the richer tool-minted ask, so the rule rides here instead of decision_reason_type 'rule'. Hosts making policy on decision_reason_type (e.g. auto-deny safetyCheck) or running host-side auto-approval should treat asks carrying this field as rule-forced: the user's stated intent is a human prompt. Values are producer-authored but render-unsafe like decision_reason; sanitize before display.
     */
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
    /**
     * True when one-tap Approve/Deny must not be offered: the tool's approval card IS the user-interaction surface (Tool.requiresUserInteraction() — the user responds on the card itself), OR the pending ask is localDisplayOnly (its consent disclosure cannot ride this wire and only the local dialog renders it). Either way the user has to open the session to answer.
     */
    requires_user_interaction?: boolean;

};

// ====== SDKControlInterruptRequest
/**
 * Interrupts the currently running conversation turn.
 */
declare type SDKControlInterruptRequest = {
    subtype: 'interrupt';

    /**
     * When true, the interrupt also cancels every uuid-stamped main-thread command still in the queue or already dequeued for the imminent turn but not yet reachable by the abort (the first-command prewait window) — the same set the response would otherwise list under `still_queued`. Each is closed with a terminal 'cancelled' lifecycle and listed on the response's `cancelled` field. `still_queued` is then empty, except that a client driving a hosted session lists there what it can no longer recall (a send already in flight to that session, or the first prompt the session was created with) and, when the session's own sweep then cancels one of those or a send it had already delivered, follows up with a command_lifecycle 'cancelled' frame for it. (The isFoldInFlight guard cancel_async_message uses does not apply here: this request also aborts the running turn, so a fold-in-flight uuid is never delivered and is swept with the rest. A fold-in-flight uuid's queued_command attachment may already appear in the aborted turn's transcript if the abort landed after the fold's attachment yield — pre-existing leave-queued semantics; it never runs as its own turn.) Uuid-less commands (task notifications) still in the queue are also dequeued but cannot be listed; a uuid-less command already in the prewait window is unreachable by either cancel leg — the first-command prewait latch covers it (this request latches exactly like a plain interrupt; see still_queued): its turn starts aborted. When false or absent, queued commands survive the interrupt and are listed under `still_queued` — the interrupt_receipt_v1 contract is unchanged. A Stop-means-stop-everything client (a remote UI's Stop button) sets this true so one round-trip halts the session; a wrapper that wants per-uuid control leaves it false and follows up with cancel_async_message. Advertised by the `interrupt_cancel_queued_v1` capability on system/init; older CLIs ignore the field and behave as if false.
     */
    cancel_queued?: boolean;

};

// ====== SDKControlInterruptResponse
/**
 * Result of an interrupt operation. Advertised by the interrupt_receipt_v1 capability on system/init; older CLIs send an empty success response with no still_queued field.
 */
export declare type SDKControlInterruptResponse = {
    /**
     * Uuids of async user messages that survive this interrupt: commands still in the queue, plus any batch already dequeued for the imminent turn but not yet reachable by the abort. An interrupt — plain or cancel_queued:true — that lands during the FIRST-command prewait window (before the first turn of the session has armed a controller) is additionally LATCHED, scoped to the user-intent work pending at that instant — the batch already dequeued and parked for the imminent turn, plus the user-intent main-thread commands then in the queue (the work this list enumerates): the first turn to arm that carries any of that doomed work starts already aborted, exactly once, so the listed prewait batch is delivered into an immediately-aborted turn, its frames and result flowing through the normal abort path, instead of running to completion. A turn carrying none of it arms live and leaves the latch waiting: a system delivery turn (for example a replayed host event), or a prompt enqueued after the interrupt — post-interrupt work is never coalesced with the doomed work and never dies to the latch, so the Stop kills exactly what this receipt listed. The latch is released when the doomed work is retired without arming: if a parked prewait batch is entirely cancelled, the latch is released even when other queued commands remain (those arm and run normally); with nothing parked, it is released once none of the doomed commands remains queued — work enqueued after the interrupt neither holds it up nor is aborted by it. Survivors that ride any later turn run normally. These WILL run (subject to that latch) unless cancelled first (or unless the request set cancel_queued:true, in which case every uuid-stamped survivor this process holds is removed, emitted a terminal `cancelled` synchronously, and listed under `cancelled` instead — leaving here only what a client driving a hosted session can no longer recall: a send already in flight to that session, or the first prompt the session was created with; a send that client still holds on its own machine behind a send gate (it waits there until that session is ready to take it) has not gone out, so it is withdrawn and listed under `cancelled` like a queued one, and cancel_async_message can withdraw it too, while a plain interrupt leaves it held and lists it here). Cancellation granularity: uuids still in the queue are individually cancellable via cancel_async_message; once a batch is dequeued and coalesced into one turn, cancelling a NON-representative member uuid is a no-op (its content still runs), while cancelling the batch-representative uuid drops the WHOLE coalesced batch — in both cases the cancel response reports cancelled:false because the message was no longer in the queue. Coverage caveats: only uuid-STAMPED messages appear (a message enqueued without a uuid still runs but is never listed, so [] does not mean "nothing will run"); only main-thread messages are listed (subagent-addressed messages are out of scope); and the list may include internally-enqueued uuids the client never sent (cron triggers, auto-resume continuations) — ignore unknown uuids rather than treating them as an error. Ordering: on a clean interrupt this receipt is written before the interrupted turn result; a turn that crashes during interrupt handling emits its error result on a direct-write path that may precede the receipt. Snapshot is taken synchronously with abort processing — probing the queue after the interrupted result instead always loses the race against the drain loop, which starts the next queued turn immediately.
     */
    still_queued: string[];

    /**
     * Present only when the request set cancel_queued:true — uuids of main-thread commands cancelled by this interrupt: every survivor that would otherwise have appeared under `still_queued`, including any uuid that was mid-fold at the interrupt instant (this request also aborts, so the fold never delivers it). Each listed uuid has been removed (queue-resident) or marked cancel-pending (the first-command prewait window, closed by the drain loop's backstop) and emits a terminal 'cancelled' lifecycle synchronously at the first such interrupt (a repeat interrupt over the same parked batch re-lists the uuid idempotently without re-emitting); none will run. Same coverage caveats as `still_queued` (uuid-stamped main-thread only; internally-enqueued uuids may appear). Advertised by the `interrupt_cancel_queued_v1` capability.
     */
    cancelled?: string[];
};

// ====== SDKControlSetPermissionModeRequest
/**
 * Sets the permission mode for tool execution handling.
 */
declare type SDKControlSetPermissionModeRequest = {
    subtype: 'set_permission_mode';
    /**
     * Permission mode for controlling how tool executions are handled. 'default' - Standard behavior, prompts for dangerous operations. 'acceptEdits' - Auto-accept file edit operations. 'bypassPermissions' - Bypass all permission checks (requires allowDangerouslySkipPermissions). 'plan' - Planning mode, no actual tool execution. 'dontAsk' - Don't prompt for permissions, deny if not pre-approved. 'auto' - Use a model classifier to approve/deny permission prompts.
     */
    mode: coreTypes.PermissionMode;

};

// ====== SDKControlSetModelRequest
/**
 * Sets the model to use for subsequent conversation turns.
 */
declare type SDKControlSetModelRequest = {
    subtype: 'set_model';
    /**
     * Model to switch to. Omitted, null, or 'default' resets to the session default model.
     */
    model?: string | null;

};

// ====== SDKControlSetMaxThinkingTokensRequest
/**
 * Sets the maximum number of thinking tokens for extended thinking. When max_thinking_tokens is null, thinking resets to the session default: any mid-session budget override is cleared (back to the spawn-time budget, if one was set), and thinking stays off for sessions that have it disabled. When max_thinking_tokens is omitted, the budget is left as it is, so a request that only changes thinking_display can leave the field out. thinking_display optionally sets the thinking display mode for the rest of the session: a value replaces the session display mode, null clears that override so Claude Code's default display handling applies again, and when omitted the display mode from session start (--thinking-display) is kept. 'highlights' returns one short title per stretch of thinking instead of a prose summary. The API accepts it only from Claude Code sessions that Anthropic hosts; if the API rejects it, the session sends 'omitted' (no thinking text) in its place from then on. A request for 'highlights' gets an error reply after such a rejection, on Amazon Bedrock, Google Vertex AI or another provider to which Claude Code sends no first-party-only beta features, when experimental betas are off (CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS or organization policy), or on a Claude 3 model (except on Microsoft Foundry). The error names which of these it was; the display stays as it was, and max_thinking_tokens still applies when the request has it.
 */
declare type SDKControlSetMaxThinkingTokensRequest = {
    subtype: 'set_max_thinking_tokens';
    max_thinking_tokens?: number | null;
    thinking_display?: ('summarized' | 'omitted' | 'highlights') | null;
};

// ====== SDKControlApplyFlagSettingsRequest
/**
 * Merges the provided settings into the flag settings layer, updating the active configuration.
 */
declare type SDKControlApplyFlagSettingsRequest = {
    subtype: 'apply_flag_settings';
    settings: Record<string, unknown>;
};

// ====== SDKControlRewindFilesRequest
/**
 * Rewinds file changes made since a specific user message.
 */
declare type SDKControlRewindFilesRequest = {
    subtype: 'rewind_files';
    user_message_id: string;
    dry_run?: boolean;
};

// ====== SDKControlStopTaskRequest
/**
 * Stops a running task.
 */
declare type SDKControlStopTaskRequest = {
    subtype: 'stop_task';
    task_id: string;
};

// ====== SDKControlBackgroundTasksRequest
/**
 * Backgrounds in-flight foreground tasks (Bash commands and subagents). With tool_use_id, targets the single task started by that tool_use block; without it, backgrounds all foreground tasks — the control-request equivalent of pressing Ctrl+B in the terminal. Each blocking tool call returns immediately with a "running in the background" tool_result and the turn continues; the task keeps running and emits a task_notification when it settles.
 */
declare type SDKControlBackgroundTasksRequest = {
    subtype: 'background_tasks';
    /**
     * When set, backgrounds only the task whose originating tool_use block has this id. When omitted, backgrounds all foreground tasks (Ctrl+B semantics).
     */
    tool_use_id?: string;
};

// ====== SDKControlGetTaskOutputRequest
/**
 * Reads the end of one background shell or Monitor task's output: at most the last 8 KiB the command wrote, the same tail the terminal's /tasks detail view reads. Read-only and no model turn; a host polls it while the task runs, and can read it once more after the task ends. The output is whatever the command printed, escape sequences included: render it as plain text. Refused for a task_id that is neither a shell or Monitor task of this session nor shaped like one (an ended task's id whose file is gone reads as empty), and on a lane that redacts what it persists (a Remote Control bridge worker, a tenant worker).
 */
declare type SDKControlGetTaskOutputRequest = {
    subtype: 'get_task_output';
    /**
     * A shell or Monitor task of this session, running or ended: the task_id from task_started or background_tasks_changed.
     */
    task_id: string;
};

// ====== SDKControlGetTaskOutputResponse
/**
 * Success payload answering get_task_output.
 */
declare type SDKControlGetTaskOutputResponse = {
    /**
     * The end of the output, decoded as UTF-8; empty when the command has written nothing yet.
     */
    output: string;
    /**
     * The size of the whole output in bytes.
     */
    total_bytes: number;
    /**
     * Whether output holds only the end of a longer output (the last 8 KiB).
     */
    truncated: boolean;
};

// ====== SDKControlCancelAsyncMessageRequest
/**
 * Drops a pending async user message from the command queue by uuid. No-op if already dequeued for execution.
 */
declare type SDKControlCancelAsyncMessageRequest = {
    subtype: 'cancel_async_message';
    message_uuid: string;
};

// ====== SDKControlFileSuggestionsRequest
/**
 * Requests at-mention file autocomplete suggestions for a partial path prefix. Returns the same fuzzy-matched results the TUI shows.
 */
declare type SDKControlFileSuggestionsRequest = {
    subtype: 'file_suggestions';
    query: string;
};

// ====== SDKControlReadFileRequest
/**
 * Read a file from the session filesystem for the remote sidebar viewer. Path is resolved against cwd and gated by the same read-permission rules as the Read tool.
 */
declare type SDKControlReadFileRequest = {
    subtype: 'read_file';
    path: string;
    max_bytes?: number;
    /**
     * How to encode the bytes in `contents`. Defaults to utf-8 (lossy for binary); pass 'base64' to read images.
     */
    encoding?: 'utf-8' | 'base64';
};

// ====== SDKControlReadFileResponse
/**
 * File contents for the remote sidebar viewer.
 */
export declare type SDKControlReadFileResponse = {
    contents: string;
    absPath: string;
    truncated?: boolean;
    /**
     * Set when the request asked for base64. Absent means utf-8 — including when an older CLI ignored the request's encoding field.
     */
    encoding?: 'base64';
};

// ====== SDKControlRequestUserDialogRequest
/**
 * Requests the SDK consumer to render a tool-driven blocking dialog and return the user choice. Used by tools that previously rendered Ink JSX via setToolJSX with an onDone callback.
 */
declare type SDKControlRequestUserDialogRequest = {
    subtype: 'request_user_dialog';
    /**
     * Identifier for the dialog the host should render. Open string union — new kinds may be added without bumping the protocol. A kind is only sent in sessions where some attached client declared it in initialize.supportedDialogKinds (declare exactly the kinds you can render); on multi-client transports the request still reaches every attached client. A host that receives a kind it did not declare must not answer it (an error-subtype response is discarded and the dialog stays pending) — never with {behavior: "cancelled"}, which is a real settlement treated as the user dismissing the dialog. An unanswered dialog is cancelled by the CLI after its dialog deadline.
     */
    dialog_kind: string;
    /**
     * Dialog-specific data passed to the host renderer. Shape is defined per dialog_kind; the protocol transports it opaquely.
     */
    payload: Record<string, unknown>;
    tool_use_id?: string;
};

// ====== SDKControlElicitationRequest
/**
 * Requests the SDK consumer to handle an MCP elicitation (user input request).
 */
declare type SDKControlElicitationRequest = {
    subtype: 'elicitation';
    mcp_server_name: string;
    message: string;
    mode?: 'form' | 'url';
    url?: string;
    elicitation_id?: string;
    requested_schema?: Record<string, unknown>;
    /**
     * Permission-display title from the MCP server's _meta['anthropic/permissionDisplay']. Mirrors can_use_tool.title so SDK consumers can render elicitation-driven permission prompts with structured headers instead of parsing `message`.
     */
    title?: string;
    /**
     * Short tool/server label from _meta['anthropic/permissionDisplay'].displayName. Mirrors can_use_tool.display_name.
     */
    display_name?: string;
    /**
     * Permission-display subtitle from _meta['anthropic/permissionDisplay'].description. Mirrors can_use_tool.description.
     */
    description?: string;
};

// ====== SDKControlMcpStatusRequest
/**
 * Requests the current status of all MCP server connections.
 */
declare type SDKControlMcpStatusRequest = {
    subtype: 'mcp_status';
};

// ====== SDKControlGetUsageRequest
/**
 * Requests the structured /usage data: session cost/usage totals plus claude.ai plan rate-limit utilization when available. Experimental — the response shape may change.
 */
declare type SDKControlGetUsageRequest = {
    subtype: 'get_usage';
    /**
     * Skip the scan of local transcripts that produces the response's behaviors section (it is null in the answer). For callers that need only the plan rate limits, such as a usage meter; the scan reads every transcript touched in the last seven days.
     */
    skip_behaviors?: boolean;
};

// ====== SDKControlGetContextUsageRequest
/**
 * Requests a breakdown of current context window usage by category.
 */
declare type SDKControlGetContextUsageRequest = {
    subtype: 'get_context_usage';
    /**
     * 'full' counts each category with the token-count API; 'summary' answers from the last response's usage and local estimates without the per-category token-count calls. Defaults to 'full'.
     */
    detail?: 'summary' | 'full';
};

// ====== SDKControlRenameSessionRequest
/**
 * Sets the user-facing title for the current session.
 */
declare type SDKControlRenameSessionRequest = {
    subtype: 'rename_session';
    title: string;
    /**
     * Who chose the title: 'remote' (the default) for a rename made on claude.ai and relayed to this process, 'host' for one the user made in the hosting application (an IDE), which the CLI counts as a user rename.
     */
    source?: 'remote' | 'host';
    /**
     * The session the title is for. When given and this process has since moved to another session (/clear, an in-session resume), the request is refused instead of naming the new session.
     */
    session_id?: string;
};

// ====== SDKHookCallbackRequest
/**
 * Delivers a hook callback with its input data.
 */
declare type SDKHookCallbackRequest = {
    subtype: 'hook_callback';
    callback_id: string;
    input: coreTypes.HookInput;
    tool_use_id?: string;

};

// ====== PermissionResult
export declare type PermissionResult = {
    behavior: 'allow';
    updatedInput?: Record<string, unknown>;
    updatedPermissions?: PermissionUpdate[];
    toolUseID?: string;
    decisionClassification?: PermissionDecisionClassification;
} | {

// ====== PermissionUpdate
export declare type PermissionUpdate = {
    type: 'addRules';
    rules: PermissionRuleValue[];
    behavior: PermissionBehavior;
    destination: PermissionUpdateDestination;
} | {

// ====== PermissionUpdateDestination
export declare type PermissionUpdateDestination = 'userSettings' | 'projectSettings' | 'localSettings' | 'session' | 'cliArg';

// ====== PermissionMode
/**
 * Permission mode for controlling how tool executions are handled. 'default' - Standard behavior, prompts for dangerous operations. 'acceptEdits' - Auto-accept file edit operations. 'bypassPermissions' - Bypass all permission checks (requires allowDangerouslySkipPermissions). 'plan' - Planning mode, no actual tool execution. 'dontAsk' - Don't prompt for permissions, deny if not pre-approved. 'auto' - Use a model classifier to approve/deny permission prompts.
 */
export declare type PermissionMode = 'default' | 'acceptEdits' | 'bypassPermissions' | 'plan' | 'dontAsk' | 'auto';

// ====== CanUseTool
/**
 * Permission callback function for controlling tool usage.
 * Called before each tool execution to determine if it should be allowed.
 *
 * Return `null` ONLY after the consumer has already sent the
 * control_response out-of-band (e.g. a signed HTTP POST echoing
 * `requestId`); the SDK will skip its own transport write. Fail-closed: an
 * accidental null means no control_response is sent and the tool stays
 * blocked indefinitely — permission prompts have no park deadline.
 */
export declare type CanUseTool = (toolName: string, input: Record<string, unknown>, options: {
    /** Signaled if the operation should be aborted. */
    signal: AbortSignal;
    /**
     * Suggestions for updating permissions so that the user will not be
     * prompted again for this tool during this session.
     *
     * Typically if presenting the user an option 'always allow' or similar,
     * then this full set of suggestions should be returned as the
     * `updatedPermissions` in the PermissionResult.
     */
    suggestions?: PermissionUpdate[];
    /**
     * The file path that triggered the permission request, if applicable.
     * For example, when a Bash command tries to access a path outside allowed directories.
     */
    blockedPath?: string;
    /**
     * For `mcp__*` tools: the MCP server serving the tool and where its
     * definition came from. `source: 'sdk'` means one of the in-process
     * servers this SDK host registered (its `name` is the key you registered;
     * only the host can register one); any other value (`plugin`, `user`,
     * `project`, `local`, `dynamic`, `managed`, …) is a server from
     * configuration, whose `name` is the key as authored there — untrusted
     * text, escape it before display. Key trust decisions on `source`, not on
     * the name or the tool-name prefix. Absent for non-MCP tools and on CLIs
     * that predate the field.
     */
    mcpServer?: {
        name: string;
        source: string;
    };
    /** Explains why this permission request was triggered. */
    decisionReason?: string;
    /**
     * Full permission prompt sentence rendered by the bridge (e.g.
     * "Claude wants to read foo.txt"). Use this as the primary prompt
     * text when present instead of reconstructing from toolName+input.
     */
    title?: string;
    /**
     * Short noun phrase for the tool action (e.g. "Read file"), suitable
     * for button labels or compact UI.
     */
    displayName?: string;
    /**
     * Human-readable subtitle from the bridge (e.g. "Claude will have
     * read and write access to files in ~/Downloads").
     */
    description?: string;
    /**
     * The ask must not be approvable by a single stray keystroke: open the
     * prompt on its decline option and offer no one-key approve shortcut.
     */
    defaultToNo?: boolean;
    /**
     * The ask must not offer a persistent "don't ask again" choice: the
     * rule it would write grants more than this ask's own action.
     */
    suppressAlwaysAllowRule?: boolean;
    /**
     * Unique identifier for this specific tool call within the assistant message.
     * Multiple tool calls in the same assistant message will have different toolUseIDs.
     */
    toolUseID: string;
    /** If running within the context of a sub-agent, the sub-agent's ID. */
    agentID?: string;
    /**
     * The control_request envelope's `request_id`. A control_response sent
     * out-of-band (e.g. a signed HTTP POST instead of the SDK's WS write)
     * must echo this value for the worker to match it.
     */
    requestId: string;
    /**
     * Set when a user-configured ask RULE (permissions.ask) forced this
     * prompt while the ask carries the tool's own decisionReason. Hosts
     * making policy on the reason (e.g. auto-deny a safetyCheck) or
     * running host-side auto-approval should treat asks carrying this
     * field as rule-forced: the user's stated intent is a human prompt.
     */
    matchedAskRule?: {
        source: string;
        toolName: string;
        ruleContent?: string;
    };

}) => Promise<PermissionResult | null>;

// ====== Query
/**
 * Query interface with methods for controlling query execution.
 * Extends AsyncGenerator and has methods, so not serializable.
 */
export declare interface Query extends AsyncGenerator<SDKMessage, void> {
    /**
     * Control Requests
     * The following methods are control requests, and are only supported when
     * streaming input/output is used.
     */
    /**
     * Interrupt the current query execution. The query will stop processing
     * and return control to the caller. On CLIs advertising the
     * `interrupt_receipt_v1` capability (system/init `capabilities`) the
     * resolved value is the interrupt receipt — `still_queued` uuids of async
     * user messages that WILL still run unless cancelled first. Older CLIs
     * resolve to `undefined`.
     */
    interrupt(): Promise<SDKControlInterruptResponse | undefined>;
    /**
     * Change the permission mode for the current session.
     * Only available in streaming input mode.
     *
     * @param mode - The new permission mode to set
     */
    setPermissionMode(mode: PermissionMode): Promise<void>;
    /**
     * Pin (or clear, with mode:null) a per-MCP-server permission-mode
     * override. Tighten-only: only 'default' | 'auto' | null are accepted;
     * the override applies only when the session mode would already
     * auto-allow (bypassPermissions/auto), so it can never widen privilege.
     * Only available in streaming input mode.
     *
     * @param serverName - The MCP server name (must match the name the server
     *   was registered under)
     * @param mode - 'default' to force per-action prompts, 'auto' to route
     *   through the auto-mode classifier, or null to clear the override
     * @returns An object with an optional `warning` — set when `serverName`
     *   does not match any currently known MCP server. For a set, the
     *   override is stored regardless and applies once a server with that
     *   exact name connects; the warning is informational (typo detection).
     */
    setMcpPermissionModeOverride(serverName: string, mode: 'default' | 'auto' | null): Promise<{
        warning?: string;
    }>;

    /**
     * Change the model used for subsequent responses.
     * Only available in streaming input mode.
     *
     * @param model - The model identifier to use, or undefined to use the default
     */
    setModel(model?: string): Promise<void>;
    /**
     * Set the maximum number of thinking tokens the model is allowed to use
     * when generating its response. This can be used to limit the amount of
     * tokens the model uses for its response, which can help control cost and
     * latency.
     *
     * Use `null` to clear any previously set limit and allow the model to
     * use the default maximum thinking tokens.
     *
     * @deprecated Use the `thinking` option in `query()` instead. On Opus 4.6,
     * this is treated as on/off (0 = disabled, any other value = adaptive).
     * For explicit control, use `thinking: { type: 'adaptive' }` or
     * `thinking: { type: 'enabled', budgetTokens: N }`.
     *
     * @param maxThinkingTokens - Maximum tokens for thinking, or null to clear the limit
     * @param thinkingDisplay - Optional thinking display mode for the rest of
     * the session: a value replaces the session display mode, `null` clears
     * that override so Claude Code's default display handling applies again,
     * and when omitted the display mode from session start (`thinking.display`
     * / `--thinking-display`) is kept — a session started with thinking
     * disabled has none, so re-enabling without this param gets that default.
     * `'highlights'` (the API's one-line thinking titles) is honored by the API
     * only for Anthropic-hosted remote sessions; when the session cannot send it
     * to the API the promise rejects and the display stays as it was, while
     * `maxThinkingTokens` still applies.
     */
    setMaxThinkingTokens(maxThinkingTokens: number | null, thinkingDisplay?: 'summarized' | 'omitted' | 'highlights' | null): Promise<void>;
    /**
     * Merge settings into the flag settings layer. This is the inline `settings`
     * option of `query()`, applied mid-session. Flag settings sit above
     * user/project/local and below managed policy settings in precedence order.
     *
     * Successive calls shallow-merge top-level keys — a second call with
     * `{permissions: {...}}` replaces the entire `permissions` object from a
     * prior call. Pass `null` for a key to clear it from the flag layer and
     * fall back to lower-precedence sources (`undefined` is dropped by JSON
     * serialization and has no effect). Four keys instead reset session state
     * and restore neither a `query()` option nor a settings-file value.
     * `effortLevel` goes to the model's default effort, `model` to Claude Code's
     * default model (not `ANTHROPIC_MODEL` or `settings.model`), `agent` to no
     * main-thread agent, and `ultracode` to off with the current effort kept.
     * Only available in streaming input mode.
     *
     * `ultracode: true` or `false` turns ultracode on or off and leaves the
     * effort level alone. An `effortLevel` that moves the session to a
     * different level, sent without an `ultracode` key, also turns ultracode
     * off; send both keys to change the level and keep it on.
     *
     * @param settings - A partial settings object to merge into the flag
     * settings. `effortLevel` also accepts `'max'` (never written to settings
     * files, so the persisted {@link Settings.effortLevel} excludes it): it is
     * session-only, runs as `'high'` on a model without `'max'` support, and
     * runs no higher than the organization's effort limit for the model.
     */
    applyFlagSettings(settings: {
        [K in keyof Settings]?: K extends 'effortLevel' ? EffortLevel | null : Settings[K] | null;
    }): Promise<void>;
    /**
     * Merge settings into a settings FILE through the CLI's own writer — the
     * same path /config uses (canonical store root, gitignore upkeep,
     * hardened write) — and live-apply them. Unlike applyFlagSettings, which
     * only touches the session-scoped flag layer. The handler accepts only an
     * explicit key allowlist per file (localSettings: outputStyle; userSettings:
     * effortLevel, saved for the session's current model as /effort saves it,
     * without setting the running session's level) with string values — deletion is not
     * supported — and refuses remote transports and sessions whose
     * --setting-sources exclude the target source. Rejects with the gate's or
     * writer's error otherwise.
     */
    updateSettings(source: 'localSettings' | 'userSettings', settings: Record<string, unknown>): Promise<void>;
    /**
     * Get the full initialization result, including supported commands, models,
     * account info, and output style configuration: the first-connect answer,
     * or, on a Query returned by a pre-warmed spare's `claim()`, the claimed
     * session's.
     *
     * @returns The complete initialization response
     */
    initializationResult(): Promise<SDKControlInitializeResponse>;
    /**
     * Re-send the `initialize` control request to an already-running CLI.
     *
     * Use this after a transport gap (e.g. reattaching to a daemon whose
     * ring buffer evicted frames during a disconnect): the CLI's response
     * carries any `can_use_tool` / `request_user_dialog` control requests
     * the loop is still blocked on, and the SDK redelivers them to
     * `canUseTool` / `onUserDialog`. In-flight request_ids are deduped
     * SDK-side, but callbacks should be idempotent per request_id since a
     * request whose response was lost in the gap will be dispatched again.
     *
     * Over stdio the CLI also re-registers this query's hooks from the
     * re-sent request (the response reports `hooks_applied: true`; CLIs that
     * predate that field ignore hooks here) and resolves any hook callback it
     * was still waiting on itself — cancelling it at this host, denying a
     * pending PreToolUse with a retry notice and blocking a pending prompt —
     * since it cannot tell whether the re-sent callback ids still name the
     * same hooks. Expect one denied-then-retried tool call or one prompt to
     * re-send if the call races an unanswered hook.
     *
     * Unlike {@link Query.initializationResult}, this always sends a fresh request
     * rather than returning the cached result.
     *
     * @returns A fresh initialization response
     */
    reinitialize(): Promise<SDKControlInitializeResponse>;
    /**
     * Get the list of available skills for the current session.
     *
     * @returns Array of available skills with their names and descriptions
     */
    supportedCommands(): Promise<SlashCommand[]>;
    /**
     * Get the list of available models.
     *
     * @returns Array of model information including display names and descriptions
     */
    supportedModels(): Promise<ModelInfo[]>;
    /**
     * Get the list of available subagents for the current session.
     *
     * @returns Array of available agents with their names, descriptions, and configuration
     */
    supportedAgents(): Promise<AgentInfo[]>;
    /**
     * Get the current status of all configured MCP servers.
     *
     * @returns Array of MCP server statuses (connected, failed, needs-auth, pending)
     */
    mcpServerStatus(): Promise<McpServerStatus[]>;
    /**
     * Get a breakdown of current context window usage by category
     * (system prompt, tools, messages, MCP tools, memory files, etc.).
     *
     * `detail: 'full'` counts each category with the token-count API;
     * `'summary'` answers from the last response's usage and local estimates
     * without the per-category token-count calls. Defaults to `'full'`.
     *
     * @returns Context usage breakdown including token counts per category and total usage
     */
    getContextUsage(opts?: {
        detail?: 'summary' | 'full';
    }): Promise<SDKControlGetContextUsageResponse>;
    /**
     * Get the structured data behind the `/usage` command: session cost and
     * token usage totals plus claude.ai plan rate-limit utilization windows
     * (5-hour, 7-day, per-model) when available. `rate_limits_available` is
     * false (and `rate_limits` null) for API key, Bedrock, Vertex, and other
     * sessions where plan limits do not apply.
     *
     * `skipBehaviors: true` skips the scan of local transcripts that fills the
     * response's `behaviors` section (it is null in the answer), for callers
     * that need only the plan rate limits. Defaults to scanning.
     *
     * EXPERIMENTAL: this API is unstable and may change or be removed in any
     * release without notice — do not rely on it yet. The method name will
     * change when the API is stabilized.
     *
     * @returns Structured session cost/usage data and plan rate-limit utilization
     */
    usage_EXPERIMENTAL_MAY_CHANGE_DO_NOT_RELY_ON_THIS_API_YET(opts?: {
        skipBehaviors?: boolean;
    }): Promise<SDKControlGetUsageResponse>;

    /**
     * Read a file from the session's filesystem for the remote sidebar
     * viewer. Path is resolved against cwd and gated by the same
     * read-permission rules as the Read tool. Returns null on permission
     * denial, missing file, or transport error.
     *
     * @param path - File path (relative to cwd or absolute)
     * @param options - Optional maxBytes cap (default 1MB) and encoding
     *   (default utf-8; pass 'base64' for binary files like images)
     */
    readFile(path: string, options?: {
        maxBytes?: number;
        encoding?: 'utf-8' | 'base64';
    }): Promise<SDKControlReadFileResponse | null>;

    /**
     * Reload plugins from disk and return the refreshed commands, agents,
     * plugins, and MCP server status.
     *
     * With `holdOnCacheImpact`, the CLI first runs the check the interactive
     * /reload-plugins makes: when applying would change the session's tool
     * list while the conversation's prompt cache depends on it, nothing is
     * applied and the response carries `held: true` with `cache_impact`
     * describing what applying would change; call again without the option
     * to apply anyway.
     *
     * @returns The refreshed session components after plugin reload, or the
     * unchanged ones with `held: true` when the reload was held
     */
    reloadPlugins(options?: {
        holdOnCacheImpact?: boolean;
    }): Promise<SDKControlReloadPluginsResponse>;
    /**
     * Reload skills from disk and return the refreshed skill list.
     *
     * @returns The refreshed skill commands after reload
     */
    reloadSkills(): Promise<SDKControlReloadSkillsResponse>;
    /**
     * Re-read the output-style directories from disk and return the refreshed
     * style names. A style file written while the session runs is otherwise
     * invisible to it until the next session. Also drops the shared
     * markdown-file scan cache, so agents, skills and routines re-read their
     * directories on their next use.
     *
     * @returns The refreshed output style names (built-in and custom)
     */
    reloadOutputStyles(): Promise<SDKControlReloadOutputStylesResponse>;
    /**
     * Get information about the authenticated account.
     *
     * @returns Account information including email, organization, and subscription type
     */
    accountInfo(): Promise<AccountInfo>;
    /**
     * Rewind tracked files to their state at a specific user message.
     * Requires file checkpointing to be enabled via the `enableFileCheckpointing` option.
     *
     * @param userMessageId - UUID of the user message to rewind to
     * @param options - Options object with optional `dryRun` boolean to preview changes without modifying files
     * @returns Object with canRewind boolean, optional error message, and file change statistics
     */
    rewindFiles(userMessageId: string, options?: {
        dryRun?: boolean;
    }): Promise<RewindFilesResult>;
    /**
     * Seed the CLI's readFileState cache with a path+mtime entry. Use when
     * the client observed a Read that has since been removed from context
     * (e.g. by snip), so a subsequent Edit won't fail "file not read yet".
     * If the file changed on disk since the given mtime, the seed is skipped
     * and Edit will correctly require a fresh Read.
     *
     * @param path - Path to the file that was previously Read
     * @param mtime - File mtime (floored ms) at the time of the observed Read
     */
    seedReadState(path: string, mtime: number): Promise<void>;

    /**
     * Reconnect an MCP server by name.
     * Throws on failure.
     *
     * @param serverName - The name of the MCP server to reconnect
     */
    reconnectMcpServer(serverName: string): Promise<void>;
    /**
     * Enable or disable an MCP server by name.
     * Throws on failure.
     *
     * @param serverName - The name of the MCP server to toggle
     * @param enabled - Whether the server should be enabled
     */
    toggleMcpServer(serverName: string, enabled: boolean): Promise<void>;
    /**
     * Read one MCP Apps (SEP-1865) UI resource from a connected MCP server the
     * CLI itself dialed, so the host can render a tool's widget. `uri` must use
     * the `ui://` scheme, typically the `_meta.ui.resourceUri` a tool
     * declares. The contents are untrusted third-party HTML: render them
     * sandboxed. Requires a CLI that advertises `mcp_read_resource_v1` in
     * `system/init.capabilities`. Throws on failure.
     *
     * @param serverName - The server's name, as `mcpServerStatus()` reports it
     * @param uri - A `ui://` resource URI
     * @alpha
     */
    readMcpResource(serverName: string, uri: string): Promise<SDKControlMcpReadResourceResponse>;

    /**
     * Dynamically set the MCP servers for this session.
     * This replaces the current set of dynamically-added MCP servers with the provided set.
     * Servers that are removed will be disconnected, and new servers will be connected.
     *
     * Supports both process-based servers (stdio, sse, http) and SDK servers (in-process).
     * SDK servers are handled locally in the SDK process, while process-based servers
     * are managed by the CLI subprocess.
     *
     * Note: This only affects servers added dynamically via this method or the SDK.
     * Servers configured via settings files are not affected. Servers introduced
     * by plugins are also exempt: they are managed by the plugin system, so
     * omitting them from the payload does NOT remove them — they keep running
     * (unless enterprise policy denies the server) and are simply absent from
     * the result's `removed` list. In particular, `setMcpServers({})` no longer
     * guarantees a session has zero dynamic MCP surface when plugins are
     * loaded. Naming a plugin server explicitly in the payload still replaces
     * it (ownership is preserved CLI-side).
     *
     * @param servers - Record of server name to configuration. Pass an empty object to remove all dynamic servers (except plugin-owned ones, which are retained).
     * @returns Information about which servers were added, removed, and any connection errors
     */
    setMcpServers(servers: Record<string, McpServerConfig>): Promise<McpSetServersResult>;
    /**
     * Stream input messages to the query.
     * Used internally for multi-turn conversations.
     *
     * @param stream - Async iterable of user messages to send
     */
    streamInput(stream: AsyncIterable<SDKUserMessage>): Promise<void>;
    /**
     * Stop a running task. A task_notification with status 'stopped' will be emitted.
     * @param taskId - The task ID from task_notification events
     */
    stopTask(taskId: string): Promise<void>;
    /**
     * Background in-flight foreground tasks (Bash commands and subagents).
     * With `toolUseId`, targets the single task started by that tool_use
     * block; without it, backgrounds all foreground tasks — equivalent to
     * pressing Ctrl+B in the terminal. Each blocking tool call returns
     * immediately with a "running in the background" tool_result and the
     * turn continues; the task keeps running and emits a task_notification
     * when it settles.
     * @param toolUseId - Optional tool_use block id to target a single task
     * @returns true when at least one task was backgrounded; false only
     *   when `toolUseId` was given and it matched no foreground task
     * @throws when background tasks are disabled for the session
     *   (`CLAUDE_CODE_DISABLE_BACKGROUND_TASKS`) — nothing is backgrounded
     */
    backgroundTasks(toolUseId?: string): Promise<boolean>;
    /**
     * Close the query and terminate the underlying process.
     * This forcefully ends the query, cleaning up all resources including
     * pending requests, MCP transports, and the CLI subprocess.
     *
     * Use this when you need to abort a query that is still running.
     * After calling close(), no further messages will be received.
     */
    close(): void;
}

// ====== Options
/**
 * Options for the query function.
 * Contains callbacks and other non-serializable fields.
 */
export declare type Options = {
    /**
     * Controller for cancelling the query. When aborted, the query will stop
     * and clean up resources.
     */
    abortController?: AbortController;
    /**
     * Additional directories Claude can access beyond the current working directory.
     * Paths should be absolute.
     */
    additionalDirectories?: string[];
    /**
     * The trusted checkout `cwd` is a worktree of. Project settings (hooks,
     * permissions), `.mcp.json`, the `.claude` config trees (commands, agents,
     * skills, workflows, routines, output-styles; a routine cannot be
     * activated with it)
     * and `CLAUDE_PROJECT_DIR` come from here instead of `cwd`, so whatever
     * the branch checked out in `cwd` carries is not what the session runs.
     * Absolute path.
     */
    projectConfigRoot?: string;
    /**
     * Agent name for the main thread. When specified, the agent's system prompt,
     * tool restrictions, and model will be applied to the main conversation.
     * The agent must be defined either in the `agents` option or in settings.
     *
     * This is equivalent to the `--agent` CLI flag.
     *
     * @example
     * ```typescript
     * agent: 'code-reviewer',
     * agents: {
     *   'code-reviewer': {
     *     description: 'Reviews code for best practices',
     *     prompt: 'You are a code reviewer...'
     *   }
     * }
     * ```
     */
    agent?: string;
    /**
     * Programmatically define custom subagents that can be invoked via the Agent tool.
     * Keys are agent names, values are agent definitions.
     *
     * @example
     * ```typescript
     * agents: {
     *   'test-runner': {
     *     description: 'Runs tests and reports results',
     *     prompt: 'You are a test runner...',
     *     tools: ['Read', 'Grep', 'Glob', 'Bash']
     *   }
     * }
     * ```
     */
    agents?: Record<string, AgentDefinition>;
    /**
     * List of tool names that are auto-allowed without prompting for permission.
     * These tools will execute automatically without asking the user for approval.
     * To restrict which tools are available, use the `tools` option instead.
     *
     * Note: passing `'Skill'` here is deprecated — use the `skills` option instead.
     */
    allowedTools?: string[];
    /**
     * Custom permission handler for controlling tool usage. Called before each
     * tool execution to determine if it should be allowed, denied, or prompt the user.
     */
    canUseTool?: CanUseTool;
    /**
     * Continue the most recent conversation in the current directory instead of starting a new one.
     * Mutually exclusive with `resume`.
     */
    continue?: boolean;
    /**
     * Current working directory for the session. Defaults to `process.cwd()`.
     */
    cwd?: string;
    /**
     * List of tool names that are disallowed. These tools will be removed
     * from the model's context and cannot be used, even if they would
     * otherwise be allowed.
     */
    disallowedTools?: string[];
    /**
     * Map of tool-name aliases applied before name resolution. When the
     * model emits a `tool_use` whose name is a key in this map, the tool
     * execution path resolves the mapped name instead.
     *
     * This lets SDK consumers redirect built-in tool names to their own
     * tools. For example, a host that runs Bash inside a remote sandbox via
     * an MCP tool can set `{ Bash: 'mcp__workspace__bash' }` so that if the
     * model emits `Bash` (e.g. because a skill document instructed it to),
     * the call is routed to the MCP tool instead of failing as unknown.
     *
     * The redirect is single-hop: an alias that points at another aliased
     * name resolves that target literally rather than following a chain, so
     * cycles like `{A: 'B', B: 'A'}` cannot loop.
     *
     * `toolAliases` is complementary to `disallowedTools`, not a replacement
     * for it: the alias only affects name-based lookup of model-emitted
     * `tool_use` blocks, whereas `disallowedTools` also blocks harness-internal
     * direct calls that hold the tool object without a name lookup.
     *
     * @example
     * ```typescript
     * toolAliases: { Bash: 'mcp__workspace__bash' }
     * ```
     */
    toolAliases?: Record<string, string>;
    /**
     * Specify the base set of available built-in tools.
     * - `string[]` - Array of specific tool names (e.g., `['Bash', 'Read', 'Edit']`)
     * - `[]` (empty array) - Disable all built-in tools
     * - `{ type: 'preset'; preset: 'claude_code' }` - Use all default Claude Code tools
     *
     * Note: native builds may provide search via Bash `find`/`grep` instead of the
     * dedicated Grep/Glob tools. List Grep/Glob here or in `allowedTools` to get them.
     */
    tools?: string[] | {
        type: 'preset';
        preset: 'claude_code';
    };
    /**
     * Environment variables for the Claude Code process.
     *
     * When set, this value REPLACES the subprocess environment entirely — it is
     * not merged with `process.env`. Spread `process.env` yourself if the
     * subprocess still needs inherited variables like `PATH`, `HOME`, or
     * `ANTHROPIC_API_KEY`. When omitted, the subprocess inherits `process.env`.
     *
     * SDK consumers can identify their app/library to include in the User-Agent header by setting:
     * - `CLAUDE_AGENT_SDK_CLIENT_APP` - Your app/library identifier (e.g., "my-app/1.0.0", "my-library/2.1")
     *
     * @example
     * ```typescript
     * env: { ...process.env, CLAUDE_AGENT_SDK_CLIENT_APP: 'my-app/1.0.0' }
     * ```
     */
    env?: {
        [envVar: string]: string | undefined;
    };
    /**
     * JavaScript runtime to use for executing Claude Code.
     * Auto-detected if not specified.
     */
    executable?: 'bun' | 'deno' | 'node';
    /**
     * Additional arguments to pass to the JavaScript runtime executable.
     */
    executableArgs?: string[];
    /**
     * Additional CLI arguments to pass to Claude Code.
     * Keys are argument names (without --), values are argument values.
     * Use `null` for boolean flags.
     */
    extraArgs?: Record<string, string | null>;
    /**
     * Fallback model(s) to use if the primary model is overloaded or
     * unavailable. Accepts a comma-separated list to try each in order. The
     * primary model is re-tried at the start of each user turn, so a temporary
     * outage doesn't permanently demote the session.
     */
    fallbackModel?: string;
    /**
     * Enable file checkpointing to track file changes during the session.
     * When enabled, files can be rewound to their state at any user message
     * using `Query.rewindFiles()`.
     *
     * File checkpointing creates backups of files before they are modified,
     * allowing you to restore them to previous states.
     */
    enableFileCheckpointing?: boolean;
    /**
     * Per-tool configuration for built-in tools.
     *
     * @example
     * ```typescript
     * toolConfig: {
     *   askUserQuestion: { previewFormat: 'html' }
     * }
     * ```
     */
    toolConfig?: ToolConfig;
    /**
     * When true, resumed sessions will fork to a new session ID rather than
     * continuing the previous session. Use with `resume`.
     */
    forkSession?: boolean;
    /**
     * Enable beta features. Currently supported:
     * - `'context-1m-2025-08-07'` - Enable 1M token context window (Sonnet 4/4.5 only)
     *
     * @see https://platform.claude.com/docs/en/api/beta-headers
     */
    betas?: SdkBeta[];
    /**
     * Hook callbacks for responding to various events during execution.
     * Hooks can modify behavior, add context, or implement custom logic.
     *
     * @example
     * ```typescript
     * hooks: {
     *   PreToolUse: [{
     *     hooks: [async (input) => ({ continue: true })]
     *   }]
     * }
     * ```
     */
    hooks?: Partial<Record<HookEvent, HookCallbackMatcher[]>>;
    /**
     * Callback for handling MCP elicitation requests.
     * Called when an MCP server requests user input (form fields, URL auth, etc.)
     * and no hook handles the request first.
     *
     * If not provided, elicitation requests that aren't handled by hooks will
     * be declined automatically.
     *
     * @example
     * ```typescript
     * onElicitation: async (request) => {
     *   if (request.mode === 'url') {
     *     // Handle URL-based auth
     *     return { action: 'accept' }
     *   }
     *   // Provide form values
     *   return { action: 'accept', content: { name: 'Test' } }
     * }
     * ```
     */
    onElicitation?: OnElicitation;
    /**
     * Callback for handling `request_user_dialog` control requests — blocking
     * dialogs the CLI asks the host to render. Each `dialogKind` defines its
     * own payload and result shape.
     *
     * When the host answers `{behavior: 'cancelled'}` — the required answer
     * for an unrecognized `dialogKind` — the CLI applies the dialog's default
     * behavior. If the callback is not provided at all, the SDK sends no
     * answer: on a multi-client session another attached client may be the
     * declared renderer, and an auto-reply from this one would settle the
     * dialog out from under it. An unanswered dialog is bounded by the CLI's
     * park deadline.
     */
    onUserDialog?: OnUserDialog;
    /**
     * Dialog kinds this consumer's `onUserDialog` can actually render
     * (`request_user_dialog` `dialog_kind` values, e.g.
     * 'refusal_fallback_prompt'). Declare only kinds your UI genuinely
     * displays and answers. Providing `onUserDialog` alone does NOT opt the
     * consumer into receiving dialogs — the CLI only emits a dialog kind
     * declared here.
     *
     * The CLI fails closed on absence: a dialog kind not declared here is
     * never emitted to this session — the flow behind it degrades to its
     * no-dialog behavior instead (for 'refusal_fallback_prompt', the classic
     * refusal error message ends the turn). Omitting the option entirely
     * means no dialogs are emitted, even with `onUserDialog` wired.
     *
     * Requires `onUserDialog`; passing a non-empty list without the callback
     * throws at option intake. On multi-client (remote) sessions the first
     * attached client's declaration wins for the worker's lifetime, and the
     * winning declaration is persisted to worker metadata so it survives
     * worker restarts (restored as a default that the next epoch's first
     * explicit declaration overrides).
     */
    supportedDialogKinds?: string[];
    /**
     * Declares that this consumer renders a per-task stop control wired to
     * the `stop_task` control request, so the user can stop an individual
     * background task.
     *
     * When declared, an interrupt on an open-input (interactive
     * stream-json) session spares running background agents/workflows —
     * Stop only aborts the current turn, and tasks are stopped one at a
     * time through the consumer's own affordance. Closed-input exception:
     * on a one-shot run (the string `prompt` form and `-p`, which close
     * stdin), hold-back tasks are still killed when the held result is
     * released, regardless of this declaration — with stdin closed, a
     * `stop_task` control could never be delivered, so the fail-closed
     * kill stands. The CLI also fails closed on absence: without the
     * declaration, an interrupt kills background tasks, because a spared
     * runaway task would otherwise be unstoppable from this consumer short
     * of ending the session. First-attached-client
     * wins on multi-client sessions; later initializes do not change it.
     */
    perTaskStopAffordance?: boolean;

    /**
     * When false, disables session persistence to disk. Sessions will not be
     * saved to ~/.claude/projects/ and cannot be resumed later. Useful for
     * ephemeral or automated workflows where session history is not needed.
     *
     * @default true
     */
    persistSession?: boolean;
    /**
     * Mirror session transcripts to an external store. When set, the subprocess
     * still writes to CLAUDE_CONFIG_DIR (set it to /tmp for ephemeral local copy)
     * AND emits entries to this adapter via dual-write.
     *
     * Cannot be used with persistSession: false -- local writes are required
     * for the mirror to function (the mirror hook fires after local write success).
     *
     * Default: undefined (no mirroring, today's behavior).
     * @alpha
     */
    sessionStore?: SessionStore;
    /**
     * Controls how aggressively transcript entries are flushed to
     * {@link Options.sessionStore}. Defaults to `'batched'`. Ignored when
     * `sessionStore` is not set.
     *
     * @alpha
     */
    sessionStoreFlush?: SessionStoreFlush;
    /**
     * Timeout for each `sessionStore.load()` / `sessionStore.listSubkeys()` call
     * during resume materialization. If the adapter doesn't settle within this
     * window the query fails with a clear error instead of hanging the iterator
     * forever (the deferred-spawn path otherwise has no upper bound).
     *
     * @default 60_000
     * @alpha
     */
    loadTimeoutMs?: number;
    /**
     * Include hook lifecycle events in the output stream.
     * When true, `hook_started`, `hook_progress`, and `hook_response` system
     * messages will be emitted for all hook event types (PreToolUse, PostToolUse,
     * Stop, etc.). SessionStart and Setup hook events are always emitted
     * regardless of this setting.
     *
     * @default false
     */
    includeHookEvents?: boolean;
    /**
     * Include partial/streaming message events in the output.
     * When true, `SDKPartialAssistantMessage` events will be emitted during streaming.
     */
    includePartialMessages?: boolean;
    /**
     * Forward subagent text and thinking blocks as assistant/user messages with
     * `parent_tool_use_id` set. By default, only tool_use/tool_result blocks from
     * subagents are emitted (enough for a heartbeat counter). When true, the full
     * subagent conversation is forwarded so consumers can render a nested transcript.
     */
    forwardSubagentText?: boolean;
    /**
     * Send every user message with `client_composed: true`, so the CLI delivers
     * the prompt text as written: no `@path` file-mention expansion and no
     * slash-command dispatch. Use when prompt text is assembled from content
     * the end user did not type. Covers string prompts, streamed messages and
     * `Query.streamInput()`. While the option is on there is no per-message
     * opt-out; for per-turn control, leave it off and set `client_composed: true`
     * on individual streamed messages instead.
     *
     * On current CLIs a turn delivered this way also skips the CLI's turn-start
     * attachment pass as a whole: `@server:resource` MCP mentions are not
     * expanded either, and the prompt is sent without the context the CLI
     * normally attaches alongside it (nested `CLAUDE.md` and rules files, skill
     * and tool listings, and the CLI's other per-turn reminders). The pass the
     * CLI runs between tool calls is unaffected, so most of that context arrives
     * after the turn's first tool call rather than with the prompt. Narrowing
     * the skip to `@path` expansion and slash-command dispatch alone is
     * CLI-side follow-up work.
     *
     * Requires Claude Code 2.1.248 or later; older CLIs ignore the field.
     *
     * @default false
     */
    verbatimPrompts?: boolean;
    /**
     * Controls Claude's thinking/reasoning behavior.
     *
     * - `{ type: 'adaptive' }` — Claude decides when and how much to think (Opus 4.6+).
     *   This is the default for models that support it.
     * - `{ type: 'enabled', budgetTokens: number }` — Fixed thinking token budget (older models)
     * - `{ type: 'disabled' }` — No extended thinking
     *
     * When set, takes precedence over the deprecated `maxThinkingTokens`.
     *
     * @see https://platform.claude.com/docs/en/build-with-claude/adaptive-thinking
     */
    thinking?: ThinkingConfig;
    /**
     * Controls how much effort Claude puts into its response.
     * Works with adaptive thinking to guide thinking depth.
     *
     * @see https://platform.claude.com/docs/en/build-with-claude/effort
     */
    effort?: EffortLevel;
    /**
     * Maximum number of tokens the model can use for its thinking/reasoning process.
     * Helps control cost and latency for complex tasks.
     *
     * @deprecated Use `thinking` instead. On Opus 4.6, this is treated as on/off
     * (0 = disabled, any other value = adaptive). For explicit control, use
     * `thinking: { type: 'adaptive' }` or `thinking: { type: 'enabled', budgetTokens: N }`.
     */
    maxThinkingTokens?: number;
    /**
     * Maximum number of conversation turns before the query stops.
     * A turn consists of a user message and assistant response.
     */
    maxTurns?: number;
    /**
     * Maximum budget in USD for the query. The query will stop if this
     * budget is exceeded, returning an `error_max_budget_usd` result.
     */
    maxBudgetUsd?: number;
    /**
     * API-side task budget in tokens. When set, the model is made aware of
     * its remaining token budget so it can pace tool use and wrap up before
     * the limit. Sent as `output_config.task_budget` with the
     * `task-budgets-2026-03-13` beta header.
     * @alpha
     */
    taskBudget?: {
        total: number;
    };
    /**
     * MCP (Model Context Protocol) server configurations.
     * Keys are server names, values are server configurations.
     *
     * @example
     * ```typescript
     * mcpServers: {
     *   'my-server': {
     *     command: 'node',
     *     args: ['./my-mcp-server.js']
     *   }
     * }
     * ```
     */
    mcpServers?: Record<string, McpServerConfig>;
    /**
     * Claude model to use. Defaults to the CLI default model.
     * Examples: 'claude-sonnet-5', 'claude-opus-4-8', 'claude-fable-5'
     */
    model?: string;
    /**
     * Output format configuration for structured responses.
     * When specified, the agent will return structured data matching the schema.
     *
     * @example
     * ```typescript
     * outputFormat: {
     *   type: 'json_schema',
     *   schema: { type: 'object', properties: { result: { type: 'string' } } }
     * }
     * ```
     */
    outputFormat?: OutputFormat;
    /**
     * Path to the Claude Code executable. Uses the built-in executable if not specified.
     */
    pathToClaudeCodeExecutable?: string;
    /**
     * Permission mode for the session. When omitted, Claude Code picks the
     * starting mode as it does for `claude -p`: a `permissions.defaultMode`
     * from the settings the session loads, else `'auto'` where that is the
     * default (and `'default'` where auto mode is unavailable). Pass
     * `'default'` to keep manual approvals through `canUseTool` (on a cloud
     * create or attach, `'default'` leaves the session's own mode).
     * - `'default'` - Standard permission behavior, prompts for dangerous operations
     * - `'acceptEdits'` - Auto-accept file edit operations
     * - `'bypassPermissions'` - Bypass all permission checks (requires `allowDangerouslySkipPermissions`)
     * - `'plan'` - Planning mode, no execution of tools
     * - `'dontAsk'` - Don't prompt for permissions, deny if not pre-approved
     * - `'auto'` - A model classifier approves or denies each call, prompting through `canUseTool` when it cannot decide
     */
    permissionMode?: PermissionMode;
    /**
     * Custom workflow instructions for plan mode. When `permissionMode` is
     * `'plan'`, this string replaces the default code-implementation workflow
     * body in the plan-mode system reminder. The CLI still wraps it with the
     * read-only enforcement preamble and the ExitPlanMode protocol footer.
     */
    planModeInstructions?: string;
    /**
     * Must be set to `true` when using `permissionMode: 'bypassPermissions'`.
     * This is a safety measure to ensure intentional bypassing of permissions.
     */
    allowDangerouslySkipPermissions?: boolean;
    /**
     * MCP tool name to use for permission prompts. When set, permission requests
     * will be routed through this MCP tool instead of the default handler.
     */
    permissionPromptToolName?: string;
    /**
     * Who answers permission prompts. `'host'` (default): this process, through
     * `canUseTool` or `permissionPromptToolName`. `'none'`: nobody — the
     * permission mode (including auto mode's classifier), rules and hooks still
     * decide, and anything that would otherwise prompt is denied immediately
     * with a message telling Claude the session has no approval surface;
     * `canUseTool` is never called.
     */
    permissionPrompts?: 'host' | 'none';
    /**
     * Load plugins for this session. Plugins provide custom commands, agents,
     * skills, and hooks that extend Claude Code's capabilities.
     *
     * Currently only local plugins are supported via the 'local' type.
     *
     * @example
     * ```typescript
     * plugins: [
     *   { type: 'local', path: './my-plugin' },
     *   { type: 'local', path: '/absolute/path/to/plugin' }
     * ]
     * ```
     */
    plugins?: SdkPluginConfig[];
    /**
     * How `plugins` reach the Claude Code process.
     * - `'argv'` (default) - One `--plugin-dir <path>` flag per plugin. Works
     *   with any Claude Code version, but the command line grows with the
     *   plugin count and Windows refuses to start a process whose command line
     *   exceeds 32,767 characters.
     * - `'initialize'` - The list is sent over stdin in the initialize request
     *   and Claude Code is started with `--await-initialize`, so the command
     *   line does not depend on the plugin count. Loading is otherwise
     *   identical. Requires Claude Code 2.1.261 or newer (the binary bundled
     *   with this SDK qualifies); an older binary exits at startup with an
     *   unknown-option error. `initializationResult().plugins_applied` reports
     *   whether every listed plugin is loaded in the process.
     */
    pluginDelivery?: 'argv' | 'initialize';

    /**
     * Enable prompt suggestions. When true, the agent emits a `prompt_suggestion`
     * message after each turn with a predicted next user prompt.
     *
     * Delivery semantics:
     * - At most one `prompt_suggestion` per turn; arrives after the `result` message.
     * - Consumers must keep iterating the stream after `result` to receive it.
     * - Suppressed on the first turn, after API errors, in plan mode, by the
     *   `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false` env var, and when the user
     *   has `promptSuggestionEnabled: false` in settings.json (the env var wins
     *   over the setting).
     * - Also suppressed while the account is near or at its plan usage limit.
     *   `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=true` keeps them on in the
     *   near-limit case; at the limit they stay off.
     * - Suggestions piggyback on the parent's prompt cache, making them nearly free.
     */
    promptSuggestions?: boolean;
    /**
     * Enable periodic AI-generated progress summaries for running subagents. When
     * true, the subagent's conversation is forked every ~30s to produce a short
     * present-tense description (e.g. "Analyzing authentication module"), emitted
     * on `task_progress` events via the `summary` field. The fork reuses the
     * subagent's model and prompt cache, so cost is typically minimal.
     *
     * Applies to both foreground and background subagents. Defaults to false.
     */
    agentProgressSummaries?: boolean;

    /**
     * Session ID to resume. Loads the conversation history from the specified session.
     */
    resume?: string;
    /**
     * Use a specific session ID for the conversation instead of an auto-generated one.
     * Must be a valid UUID. Cannot be used with `continue` or `resume` unless
     * `forkSession` is also set (to specify a custom ID for the forked session).
     */
    sessionId?: string;
    /**
     * When resuming, only resume messages up to and including the message with this UUID.
     * Use with `resume`. This allows you to resume from a specific point in the conversation.
     * Accepts any chain-entry UUID — typically `SDKAssistantMessage.uuid`, but
     * end-turn tool sessions and transcript-only appends need a later entry's
     * UUID (see `resumeDropsTurn` for the fork-point guidance).
     */
    resumeSessionAt?: string;
    /**
     * With `resumeSessionAt`: declares the prompt UUID of the turn this
     * truncating resume intends to discard. The CLI validates at fork time
     * that every entry past the `resumeSessionAt` point is attributable to
     * that turn, and refuses the resume (an `error_during_execution` result
     * whose message starts with `Resume rejected by --resume-drops-turn:`)
     * when the discarded range contains anything else — e.g. a queued user
     * message or task notification the session absorbed mid-turn that the
     * caller's view of the conversation had not yet observed. Omit to keep
     * the unvalidated truncation behavior.
     *
     * Consumers MUST map a refusal (match on the message prefix above) to
     * their rewind-recovery path — clear the pending fork target and resume
     * plainly, keeping the evidence — not retry: the refusal is
     * deterministic, so re-sending the same fork request fails forever.
     *
     * End-turn tool sessions (`outputFormat: {type: 'json_schema'}`, or any
     * MCP tool using `_meta['claude/endTurn']`): a completed turn there ends
     * on a successful tool_result carrier — with no trailing assistant
     * message — followed by a `structured_output` attachment holding the
     * turn's actual output (the carrier's data is a placeholder). Fork at
     * the LAST entry of the turn being kept — the `structured_output`
     * attachment when present, else the carrier — not the last assistant
     * UUID; `resumeSessionAt` accepts any chain UUID. Forking earlier
     * leaves the carrier or attachment in the discarded range, and the
     * validator deliberately refuses: both are the kept turn's own payload,
     * and dropping either would discard kept-turn output (the attachment is
     * its sole persisted copy) or leave its tool_use dangling.
     *
     * The same fork-past-your-appends rule applies to plain (non-synthetic)
     * `shouldQuery: false` transcript appends (e.g. CCD bash mode): they
     * persist as bare user entries, so a fork point that leaves one in the
     * discarded range refuses. Fork at or after your own last append.
     *
     * PRINT/HEADLESS LANE ONLY: the pair is consumed exclusively by the
     * headless boot path (print-mode CLI, Agent SDK, ProcessTransport). An
     * interactive `claude --resume` boot and background-job worker boots
     * ignore both options — the resume loads the full chain with no
     * truncation, no guard, and no error — so callers must not pass the
     * pair outside print mode and expect an armed guard (rejecting it on
     * those lanes is tracked follow-up work).
     *
     * General rule subsuming all of the above: fork at the KEPT turn's last
     * chain entry, whatever it is — `resumeSessionAt` accepts any chain
     * UUID. This also covers interrupted turns that completed one or more
     * tools before Esc: the completed (non-error) tool_result in the tail
     * is kept-turn payload and deliberately refuses at an assistant-UUID
     * fork point, while the marker / cancel-batch entries after it are
     * skippable — so fork at the last entry and the refusal never fires.
     */
    resumeDropsTurn?: string;
    /**
     * Sandbox settings for command execution isolation.
     *
     * When enabled, commands are executed in a sandboxed environment that restricts
     * filesystem and network access. This provides an additional security layer.
     *
     * **Important:** Filesystem and network restrictions are configured via permission
     * rules, not via these sandbox settings:
     * - Filesystem access: Use `Read` and `Edit` permission rules
     * - Network access: Use `WebFetch` permission rules
     *
     * These sandbox settings control sandbox behavior (enabled, auto-allow, etc.),
     * while the actual access restrictions come from your permission configuration.
     *
     * **Dependency check:** When `enabled: true` is passed via this option,
     * `failIfUnavailable` defaults to `true` — if sandbox dependencies are missing
     * (e.g. `bubblewrap` on Linux) or the platform is unsupported, `query()` will
     * emit an error result and exit rather than silently running commands
     * unsandboxed. Set `failIfUnavailable: false` to allow graceful degradation.
     *
     * @example Enable sandboxing with auto-allow
     * ```typescript
     * sandbox: {
     *   enabled: true,
     *   autoAllowBashIfSandboxed: true
     * }
     * ```
     *
     * @example Configure network options (not restrictions)
     * ```typescript
     * sandbox: {
     *   enabled: true,
     *   network: {
     *     allowLocalBinding: true,
     *     allowUnixSockets: ['/var/run/docker.sock']
     *   }
     * }
     * ```
     *
     * @see https://code.claude.com/docs/en/settings#sandbox-settings
     */
    sandbox?: SandboxSettings;
    /**
     * Additional settings to apply. Accepts either a path to a settings JSON file
     * or a settings object. These are loaded into the "flag settings" layer,
     * which has the highest priority among user-controlled settings.
     *
     * Equivalent to the `--settings` CLI flag.
     *
     * @example Inline settings object
     * ```typescript
     * settings: { model: 'claude-sonnet-5', permissions: { allow: ['Bash(*)'] } }
     * ```
     *
     * @example Path to settings file
     * ```typescript
     * settings: '/path/to/settings.json'
     * ```
     */
    settings?: string | Settings;
    /**
     * Policy-tier settings supplied by the spawning parent process. When an
     * IT-controlled managed-settings tier (server / MDM / managed-settings.json)
     * exists on the user's machine, these are **dropped by default** — they only
     * layer in if that admin opts in via `parentSettingsBehavior: 'merge'` in
     * their managed settings (a gateway-mode session that Claude Desktop's Code
     * tab launches merges them by default; `'first-wins'` in the highest-priority
     * managed source turns that off). Even when opted in, the value is filtered
     * restrictive-only: permissive arrays (`permissions.allow`,
     * `additionalDirectories`, …) that would widen an existing admin lock are
     * silently dropped; the only-listed-allowed lists (`allowedMcpServers`,
     * `availableModels`, `strictKnownMarketplaces`) apply only where the admin
     * tier sets none, while denylists (`deniedMcpServers`,
     * `blockedMarketplaces`) are kept and union with the admin's. With no admin
     * tier present, these apply as the sole policy tier (still filtered
     * restrictive-only — non-allowlisted keys are dropped regardless).
     *
     * Intended for embedding applications (e.g. desktop apps) that derive
     * lockdown settings from their own enterprise configuration and need to
     * enforce them on the spawned subprocess without writing root-owned files.
     *
     * @example
     * ```typescript
     * managedSettings: {
     *   sandbox: { network: { allowManagedDomainsOnly: true } }
     * }
     * ```
     */
    managedSettings?: Settings;
    /**
     * Control which filesystem settings to load.
     * - `'user'` - Global user settings (`~/.claude/settings.json`)
     * - `'project'` - Project settings (`.claude/settings.json`)
     * - `'local'` - Local settings (`.claude/settings.local.json`)
     *
     * When omitted, all sources are loaded (matches CLI defaults).
     * Pass `[]` to disable filesystem settings (SDK isolation mode).
     * Must include `'project'` to load CLAUDE.md files.
     */
    settingSources?: SettingSource[];
    /**
     * Skills to enable for the main session. This is the single place to turn
     * skills on; you do not need to add `'Skill'` to `allowedTools` yourself
     * when using this option.
     *
     * - omitted (default): no SDK auto-configuration. The CLI's own defaults
     *   still apply, so this is **not** "skills off."
     * - `'all'`: enable every discovered skill.
     * - `string[]`: enable only the listed skills. Names match the SKILL.md
     *   `name` / directory name, or `plugin:skill` for plugin-qualified skills.
     *
     * This is a context filter, not a sandbox: unlisted skills are hidden from
     * the model's listing and rejected by the Skill tool, but their files
     * remain on disk and are reachable via Read/Bash. Do not store secrets in
     * skill files.
     *
     * @example
     * ```typescript
     * skills: 'all'
     * skills: ['pdf', 'docx']
     * ```
     */
    skills?: string[] | 'all';
    /**
     * Enable debug mode for the Claude Code process.
     * When true, enables verbose debug logging (equivalent to `--debug` CLI flag).
     * Debug logs are written to a file (see `debugFile` option) or to stderr.
     *
     * You can also capture debug output via the `stderr` callback.
     */
    debug?: boolean;
    /**
     * Write debug logs to a specific file path.
     * Implicitly enables debug mode. Equivalent to `--debug-file <path>` CLI flag.
     */
    debugFile?: string;
    /**
     * Callback for stderr output from the Claude Code process.
     * Useful for debugging and logging.
     */
    stderr?: (data: string) => void;
    /**
     * Only use MCP servers passed via the `mcpServers` option (and servers
     * declared by explicitly-passed agent definitions in `agents`), ignoring
     * all other MCP configurations: project `.mcp.json`, user settings,
     * plugins, and on-disk agent frontmatter — including subagent frontmatter
     * MCP. Maps to the CLI `--strict-mcp-config` flag.
     */
    strictMcpConfig?: boolean;
    /**
     * System prompt configuration.
     * - `string` - Use a custom system prompt
     * - `string[]` - Use a custom system prompt as an array of blocks; include
     *   `SYSTEM_PROMPT_DYNAMIC_BOUNDARY` as a standalone element to mark the
     *   split between the static (globally-cacheable) prefix and the dynamic
     *   (session-specific) suffix. Blocks before the marker are eligible for
     *   cross-session prompt caching; blocks after it are not.
     * - `{ type: 'preset', preset: 'claude_code' }` - Use Claude Code's default system prompt
     * - `{ type: 'preset', preset: 'claude_code', append: '...' }` - Use default prompt with appended instructions
     * - `{ type: 'preset', preset: 'claude_code', excludeDynamicSections: true }` -
     *   Strip per-user dynamic sections (working directory, auto-memory, git
     *   status) from the system prompt so it stays static and cacheable across
     *   users. The stripped content is re-injected as the first user message so
     *   the model still has access to it.
     *
     *   Use this when many users in your fleet share the same system prompt and
     *   you want the prompt-caching prefix to hit cross-user. Tradeoffs:
     *   - The working-directory, memory-path, and git-status context is
     *     marginally less authoritative for steering the model (it appears in
     *     a user message instead of the system prompt).
     *   - The first user message becomes slightly larger.
     *   - Has no effect when `systemPrompt` is a string (custom prompt).
     *
     * @example Custom prompt
     * ```typescript
     * systemPrompt: 'You are a helpful coding assistant.'
     * ```
     *
     * @example Custom prompt with cache boundary
     * ```typescript
     * import { SYSTEM_PROMPT_DYNAMIC_BOUNDARY } from '@anthropic-ai/claude-agent-sdk'
     * systemPrompt: [
     *   staticInstructions,
     *   SYSTEM_PROMPT_DYNAMIC_BOUNDARY,
     *   sessionContext,
     * ]
     * ```
     *
     * @example Default with additions
     * ```typescript
     * systemPrompt: {
     *   type: 'preset',
     *   preset: 'claude_code',
     *   append: 'Always explain your reasoning.'
     * }
     * ```
     *
     * @example Cacheable prompt for multi-user fleets
     * ```typescript
     * systemPrompt: {
     *   type: 'preset',
     *   preset: 'claude_code',
     *   excludeDynamicSections: true,
     * }
     * ```
     *
     * `snapshot` — whether the conversation's system prompt is recorded once (in
     * the session transcript) and reused verbatim on every later request and
     * `resume` / `continue`, instead of being rendered fresh each time.
     * **Recommended: `snapshot: true`.** A system prompt that changes
     * mid-conversation (a CLI upgrade between launches, a flag flip, a different
     * `append`) invalidates the prompt prefix and, with extended thinking,
     * discards the model's earlier reasoning; a recorded prompt cannot change
     * until the conversation is compacted. (It also keeps the API prompt-cache
     * prefix stable.)
     *
     * How it interacts with `append` (and a custom `prompt`):
     * - **Omitted or `snapshot: true` (the default):** Claude Code renders its
     *   prompt with your `append` (or your custom `prompt`) on the
     *   conversation's first request, sends that, and records it; every later
     *   request and `resume` / `continue` sends the record as-is — a different
     *   `append` or `prompt` passed on a later launch of the same session is
     *   ignored until compaction or a new session.
     * - **`snapshot: false`:** never record; render fresh every request — for
     *   iterating on prompt text, or a host that must change its append within
     *   a session.
     * A bare string / `string[]` prompt follows the default; use
     * `{ type: 'custom', prompt, snapshot: false }` to opt it out.
     * With a recorded prompt, a mid-session model switch or `set_settings`
     * agent/system-prompt change does not change the prompt either; it takes
     * effect at the next compaction or in a new session. System-prompt
     * recording is rolling out: where it is not yet enabled for the account
     * (and on Bedrock / Vertex / Foundry today) `snapshot` is accepted and has no
     * effect, so it is safe to set now.
     *
     * @example Recommended: preset with an append, recorded for the conversation
     * ```typescript
     * systemPrompt: {
     *   type: 'preset',
     *   preset: 'claude_code',
     *   append: 'Always explain your reasoning.',
     *   snapshot: true,
     * }
     * ```
     *
     * @example Custom prompt, recorded for the conversation
     * ```typescript
     * systemPrompt: { type: 'custom', prompt: 'You are a release bot.', snapshot: true }
     * ```
     */
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
    /**
     * Custom title for a new session. When provided, the session uses this title
     * instead of auto-generating one from the first user message.
     *
     * When resuming via `resume` or `continue`, the resumed session's persisted
     * title takes precedence — use `renameSession()` to retitle an existing
     * session.
     */
    title?: string;

    /**
     * Custom function to spawn the Claude Code process.
     * Use this to run Claude Code in VMs, containers, or remote environments.
     *
     * When provided, this function is called instead of the default local spawn.
     * The default behavior checks if the executable exists before spawning.
     *
     * @example
     * ```typescript
     * spawnClaudeCodeProcess: (options) => {
     *   // Custom spawn logic for VM execution
     *   // options contains: command, args, cwd, env, signal
     *   // `signal` is forwarded — it aborts only AFTER the SDK's
     *   // stdin-EOF + ~2 s grace window, so passing it to spawn()/your
     *   // VM API is safe (force-kill fires after the graceful chance).
     *   return myVMProcess; // Must satisfy SpawnedProcess interface
     * }
     * ```
     */
    spawnClaudeCodeProcess?: (options: SpawnOptions) => SpawnedProcess;
};

// ====== SlashCommand
/**
 * Information about an available skill (invoked via /command syntax).
 */
export declare type SlashCommand = {
    /**
     * Skill name (without the leading slash)
     */
    name: string;
    /**
     * Description of what the skill does
     */
    description: string;
    /**
     * Hint for skill arguments (e.g., "<file>")
     */
    argumentHint: string;
    /**
     * Alternate names that resolve to this command (e.g., /cost and /stats both resolve to /usage)
     */
    aliases?: string[];
    /**
     * True when the command is Claude Code's own; absent for a command defined by a user, project, plugin or MCP server. Rows can share a name: when a marked row carries it, /name runs that one, and an unmarked row is the one /name runs only when no marked row shares its name. The marker describes the row's name, not its aliases: a typed alias runs a command that has it as its name, when one exists, whatever this marker says.
     */
    builtin?: boolean;
};

// ====== ModelInfo
/**
 * Information about an available model.
 */
export declare type ModelInfo = {
    /**
     * Model identifier to use in API calls
     */
    value: string;
    /**
     * Canonical wire model id this row's `value` resolves to (e.g. 'sonnet' → 'claude-sonnet-5'). Lets hosts match a persisted explicit id against the alias row that covers it.
     */
    resolvedModel?: string;
    /**
     * Human-readable display name
     */
    displayName: string;
    /**
     * Description of the model's capabilities
     */
    description: string;
    /**
     * Whether this model supports effort levels
     */
    supportsEffort?: boolean;
    /**
     * Available effort levels for this model
     */
    supportedEffortLevels?: ('low' | 'medium' | 'high' | 'xhigh' | 'max')[];
    /**
     * Whether this model supports adaptive thinking (Claude decides when and how much to think)
     */
    supportsAdaptiveThinking?: boolean;
    /**
     * Whether this model supports fast mode
     */
    supportsFastMode?: boolean;
    /**
     * Whether this model supports auto mode
     */
    supportsAutoMode?: boolean;

};

// ====== AgentInfo
/**
 * Information about an available subagent that can be invoked via the Task tool.
 */
export declare type AgentInfo = {
    /**
     * Agent type identifier (e.g., "Explore")
     */
    name: string;
    /**
     * Description of when to use this agent
     */
    description: string;
    /**
     * Model this agent uses: an alias or model ID, or 'inherit' for the parent's model. If omitted, uses the default subagent model when one is configured, else the parent's model
     */
    model?: string;
};

// ====== AccountInfo
/**
 * Information about the logged in user's account.
 */
export declare type AccountInfo = {
    email?: string;
    organization?: string;
    subscriptionType?: string;
    tokenSource?: string;
    apiKeySource?: string;
    /**
     * Active API backend. Anthropic OAuth login only applies when "firstParty"; for 3P providers the other fields are absent and auth is external (AWS creds, gcloud ADC, etc.). "gateway" means the CLI is authenticated against an enterprise gateway.
     */
    apiProvider?: 'firstParty' | 'bedrock' | 'vertex' | 'foundry' | 'anthropicAws' | 'anthropicGoogleCloud' | 'mantle' | 'gateway';
};

// ====== McpServerStatus
/**
 * Status information for an MCP server connection.
 */
export declare type McpServerStatus = {
    /**
     * Server name as configured
     */
    name: string;
    /**
     * Current connection status
     */
    status: 'connected' | 'failed' | 'needs-auth' | 'pending' | 'disabled';
    /**
     * Server information (available when connected)
     */
    serverInfo?: {
        name: string;
        version: string;
    };
    /**
     * Error message (available when status is 'failed')
     */
    error?: string;

    /**
     * Server configuration (includes URL for HTTP/SSE servers)
     */
    config?: McpServerStatusConfig;
    /**
     * Configuration scope (e.g., project, user, local, claudeai, managed)
     */
    scope?: string;
    /**
     * Where the server definition came from: sdk (an in-process server the SDK host registered — only the host can register one), plugin (a server a plugin ships or registers at runtime), or the config scope (user, project, local, dynamic, managed, enterprise, claudeai, agent). Key trust on this, not on the name. Absent on CLIs that predate the field.
     */
    source?: string;
    /**
     * Tools provided by this server (available when connected)
     */
    tools?: {
        name: string;
        description?: string;
        annotations?: {
            readOnly?: boolean;
            destructive?: boolean;
            openWorld?: boolean;
        };
        /**
         * The MCP Apps (SEP-1865) members of the tool's `_meta`, for a host that renders the tool's `ui://` resource, under the keys the server used: `ui` (an object: `resourceUri`, a `ui://` string; `visibility`, an array of 'model' | 'app'; and any other member the server sent) and the deprecated flat `ui/resourceUri` (a `ui://` string). Validated and size-bounded; every other `_meta` key is withheld. Present only on a tool that declares one, from CLIs that advertise `mcp_tool_ui_meta_v1`.
         */
        _meta?: Record<string, unknown>;
    }[];

};

// ====== ModelUsage
export declare type ModelUsage = {
    inputTokens: number;
    outputTokens: number;
    /**
     * Thinking tokens, already counted inside outputTokens. Counts only turns run on CLI versions that record this field: absent when none did, and partial for a resumed session that began on an older version.
     */
    thinkingTokens?: number;
    cacheReadInputTokens: number;
    cacheCreationInputTokens: number;
    webSearchRequests: number;
    costUSD: number;
    contextWindow: number;
    maxOutputTokens: number;
    /**
     * Canonical model id used for the pricing lookup (e.g. 'claude-opus-4-7'). May differ from the raw model string this entry is keyed by (provider-specific ids, aliases).
     */
    canonicalModel?: string;
    /**
     * API provider that served this model (e.g. 'firstParty', 'bedrock', 'vertex', 'foundry', 'anthropicAws', 'mantle', 'gateway').
     */
    provider?: string;
    /**
     * Which price table the most recent request for this model was priced at: Claude Code's built-in list prices ('list'), the organization's managed-settings modelPricing rates or multiplier ('managed'), or neither ('unknown' — no pricing row and no built-in price matched the model ID, so costUSD is a guess at the default model's rate). Overwritten per request like canonicalModel, so a consumer that differences the cumulative costUSD per turn gets that turn's basis. Absent until this process has priced a request for the model (e.g. right after --resume) and on builds that predate the field; treat as 'list'.
     */
    costBasis?: 'list' | 'managed' | 'unknown';
};

// ====== RewindFilesResult
/**
 * Result of a rewindFiles operation.
 */
export declare type RewindFilesResult = {
    canRewind: boolean;
    error?: string;
    filesChanged?: string[];
    insertions?: number;
    deletions?: number;
    /**
     * Count of tracked files NOT restored or deleted because a symlink, hard link, or other non-regular file was detected at the tracked path, its parent directory no longer resolves to where it pointed when the checkpoint was taken, or its backup could not be safely read. Only populated by a real (non-dryRun) rewind — on a dryRun response the field is never set and the preview counts do not reflect link-safety refusals. Absent or 0 on a real rewind means no link-safety refusals occurred; other per-file failures (for example a missing backup file) are not counted here; they are reported in telemetry, and when every differing file fails to restore the rewind itself fails (canRewind: false).
     */
    skippedLinks?: number;
};

// ====== SDKSessionInfo
/**
 * Session metadata returned by listSessions and getSessionInfo.
 */
export declare type SDKSessionInfo = {
    /**
     * Unique session identifier (UUID).
     */
    sessionId: string;
    /**
     * Display title for the session: custom title, auto-generated summary, or first prompt.
     */
    summary: string;
    /**
     * Last modified time in integer milliseconds since epoch.
     */
    lastModified: number;
    /**
     * File size in bytes. Only populated for local JSONL storage.
     */
    fileSize?: number;
    /**
     * User-set session title via /rename.
     */
    customTitle?: string;
    /**
     * First meaningful user prompt in the session.
     */
    firstPrompt?: string;
    /**
     * Git branch at the end of the session.
     */
    gitBranch?: string;
    /**
     * Working directory for the session.
     */
    cwd?: string;
    /**
     * User-set session tag.
     */
    tag?: string;
    /**
     * Creation time in integer milliseconds since epoch, extracted from the first entry's timestamp.
     */
    createdAt?: number;
};

// ====== ThinkingConfig
/**
 * Controls Claude's thinking/reasoning behavior. When set, takes precedence over the deprecated maxThinkingTokens.
 */
export declare type ThinkingConfig = ThinkingAdaptive | ThinkingEnabled | ThinkingDisabled;

// ====== EffortLevel
/**
 * Effort level for controlling how much thinking/reasoning Claude applies.
 *
 * @see https://platform.claude.com/docs/en/build-with-claude/effort
 */
export declare type EffortLevel = 'low' | 'medium' | 'high' | 'xhigh' | 'max';

// ====== USAGE_LIMIT_ERROR_PREFIXES
/**
 * Messages meaning "a usage limit was genuinely reached" — the error-path
 * outputs of getLimitReachedText (rateLimitMessages.ts) and
 * getFableCreditsRequiredContent (api/errors.ts).
 *
 * @alpha
 */
export declare const USAGE_LIMIT_ERROR_PREFIXES: readonly ["You've hit your", "You've reached your", "You're out of usage credits", 'Your org is out of usage · add funds to continue', 'Your org is out of usage · contact your admin', "Your seat type doesn't include usage credits", "Your seat type doesn't include usage", 'Your usage allocation has been disabled by your admin', "Your group's usage limit is set to $0", 'Fable 5 requires usage credits', "You're out of extra usage", "Your seat type doesn't include extra usage"];

// ====== USAGE_WARNING_PREFIXES
/**
 * Approaching-limit warnings (severity:'warning'). Footer/toast only; these
 * never arrive as API errors. ("Approaching …" early warnings are
 * deliberately unregistered — they render in the footer without
 * <RateLimitMessage> styling; see the generator-coverage tests.)
 *
 * @alpha
 */
export declare const USAGE_WARNING_PREFIXES: readonly ["You've used", "You're close to"];

// ====== USAGE_TRANSITION_PREFIXES
/**
 * Overage-transition notifications ("now drawing from credits"). Toast only;
 * these never arrive as API errors.
 *
 * @alpha
 */
export declare const USAGE_TRANSITION_PREFIXES: readonly ["You're now using usage credits", "You're now using your usage allocation", 'Now using your usage allocation', 'Now using usage credits', "You're now using extra usage", 'Now using extra usage'];

// ====== Transport
/**
 * Transport interface for Claude Code SDK communication
 * Abstracts the communication layer to support both process and WebSocket transports
 */
export declare interface Transport {
    /**
     * Write data to the transport
     * May be async for network-based transports
     */
    write(data: string): void | Promise<void>;
    /**
     * Close the transport connection and clean up resources
     * This also closes stdin if still open (eliminating need for endInput)
     */
    close(): void;
    /**
     * Check if transport is ready for communication
     */
    isReady(): boolean;
    /**
     * Read and parse messages from the transport
     * Each transport handles its own protocol and error checking
     */
    readMessages(): AsyncGenerator<StdoutMessage, void, unknown>;
    /**
     * Register a request_id whose control_response the caller will await
     * out-of-band via Query.awaitControlResponse. Transports that see
     * per-frame source (multi-client fan-out) SHOULD drop non-worker
     * control_responses matching this id — only the worker may answer.
     */
    expectControlResponse?(requestId: string): void;
    /**
     * Called by Query immediately before it yields `message` to the SDK
     * consumer. Transports that keep a consumer-facing delivery cursor
     * (BrowserSSETransport's getLastSequenceNum()) advance it here, so the
     * cursor covers exactly the messages the consumer was handed — not ones
     * still buffered between the transport and the consumer.
     */
    markDelivered?(message: object): void;
    /**
     * End the input stream
     */
    endInput(): void;
    /**
     * Await the underlying subprocess's exit. Only meaningful for
     * subprocess-backed transports (ProcessTransport); WebSocket / SSE /
     * in-process transports leave this undefined. Query.performCleanup()
     * awaits it (bounded) so .return() / asyncDispose don't resolve while
     * the child is still draining the stdin EOF that close() just sent.
     */
    waitForExit?(): Promise<void>;
    /**
     * Optional Disposable support. All built-in transports implement this
     * (delegating to close()), so `using transport = new ProcessTransport(...)`
     * works. Kept optional on the interface to avoid a breaking change for
     * external `implements Transport` consumers.
     */
    [Symbol.dispose]?(): void;
}

