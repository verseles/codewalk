/**
 * API surface definition for @anthropic-ai/claude-agent-sdk/bridge.
 *
 * This file is the source of truth for the /bridge export's public types.
 * It imports ONLY from agentSdkTypes.ts so the compiled .d.ts has exactly
 * one import to rewrite (./agentSdkTypes → ./sdk) for the flat package layout.
 *
 * Compiled by scripts/build-ant-sdk-typings.sh; see build-agent-sdk.sh for the
 * copy into the package. Runtime code is in agentSdkBridge.ts (separate file,
 * bun-built to bridge.mjs).
 *
 * The two type definitions below are copied from src/bridge/sessionHandle.ts.
 * Keep in sync — sessionHandle.ts is the implementation source of truth;
 * this file exists to produce a clean .d.ts without walking the implementation
 * import graph.
 */
import type { PermissionMode, SDKControlRequest, SDKControlResponse, SDKMessage } from './agentSdkTypes.js';
/**
 * Session state reported to the CCR /worker endpoint.
 * @alpha
 */
export type SessionState = 'idle' | 'running' | 'requires_action';
/**
 * Per-session bridge transport handle.
 *
 * Auth is instance-scoped — the JWT lives in this handle's closure, not a
 * process-wide env var, so multiple handles can coexist without stomping
 * each other.
 * @alpha
 */
export type BridgeSessionHandle = {
    readonly sessionId: string;
    /**
     * Live SSE event-stream high-water mark. Updates as the underlying
     * transport receives frames. Persist this and pass back as
     * `initialSequenceNum` on re-attach so the server resumes instead of
     * replaying full history.
     */
    getSequenceNum(): number;
    /**
     * Worker epoch the current transport is writing as. Callers that
     * reconnect for a token refresh (not a cold re-attach) pass this back
     * via `reconnectTransport({epoch})` so the handle reuses the epoch
     * instead of calling registerWorker again.
     */
    getEpoch(): number | undefined;
    /** True once the write path (CCRClient initialize) is ready. */
    isConnected(): boolean;
    /** Write a single SDKMessage. `session_id` is injected automatically. */
    write(msg: SDKMessage): void;
    /** Signal turn boundary — claude.ai stops the "working" spinner. */
    sendResult(): void;
    /** Forward a permission request (`can_use_tool`) to claude.ai. */
    sendControlRequest(req: SDKControlRequest): void;
    /** Forward a permission response back through the bridge. */
    sendControlResponse(res: SDKControlResponse): void;
    /**
     * Tell claude.ai to dismiss a pending permission prompt (e.g. caller
     * aborted the turn locally before the user answered).
     */
    sendControlCancelRequest(requestId: string): void;
    /**
     * Swap the underlying transport in place with a fresh JWT (and epoch).
     * Carries the SSE sequence number so the server resumes the stream.
     * Call this when the poll loop re-dispatches work for the same session
     * with a fresh secret (JWT is 4h; backend mints a new one every dispatch).
     *
     * Throws if `createV2ReplTransport` fails (registerWorker error, etc).
     * Caller should treat that as a close and drop this handle.
     */
    reconnectTransport(opts: {
        ingressToken: string;
        apiBaseUrl: string;
        /** Omit to reuse the current transport's epoch (token-refresh reconnect); provide to override. */
        epoch?: number;
    }): Promise<void>;
    /**
     * PUT /worker state. Multi-session workers: `running` on turn start,
     * `requires_action` on permission prompt, `idle` on turn end. Daemon
     * callers don't need this — user watches the REPL locally.
     */
    reportState(state: SessionState): void;
    /** PUT /worker external_metadata (branch, dir shown on claude.ai). */
    reportMetadata(metadata: Record<string, unknown>): void;
    /**
     * POST /worker/events/{id}/delivery. Populates CCR's processing_at /
     * processed_at columns. `received` is auto-fired internally; this
     * surfaces `processing` (turn start) and `processed` (turn end).
     */
    reportDelivery(eventId: string, status: 'processing' | 'processed'): void;
    /** Drain the write queue. Call before close() when delivery matters. */
    flush(): Promise<void>;
    close(): void;
};
/** @alpha */
export type AttachBridgeSessionOptions = {
    /**
     * Session ID (`cse_*` form). Comes from `WorkResponse.data.id` in the
     * poll-loop path, or from whatever created the session.
     */
    sessionId: string;
    /** Worker JWT. Comes from `decodeWorkSecret(work.secret).session_ingress_token`. */
    ingressToken: string;
    /** `WorkSecret.api_base_url` or wherever the session ingress lives. */
    apiBaseUrl: string;
    /**
     * Worker epoch if already known (e.g. from a `/bridge` call that bumps
     * epoch server-side). Omit to have `createV2ReplTransport` call
     * `registerWorker` itself — correct for poll-loop callers where the
     * work secret doesn't carry epoch.
     */
    epoch?: number;
    /**
     * SSE sequence-number high-water mark from a prior handle or persisted
     * state. Seeds the first SSE connect's `from_sequence_num` so the server
     * resumes instead of replaying full history. Omit (→ 0) for genuinely
     * fresh attach.
     */
    initialSequenceNum?: number;
    /**
     * CCRClient heartbeat interval seed. Defaults to 20s. The server-advised
     * interval (ccr_heartbeat_policy) overrides this after the first heartbeat.
     */
    heartbeatIntervalMs?: number;
    /**
     * When true, the bridge only forwards events outbound (local → CCR). The
     * SSE read stream is not opened — no inbound events are received. Control
     * requests that arrive via the write-path ACK channel reply with an error
     * instead of false-success. onInboundMessage is never called. Use for
     * mirror-mode attachments where the remote UI should see the session but
     * not be able to drive it.
     */
    outboundOnly?: boolean;
    /**
     * User message typed on claude.ai. Echoes of outbound writes and
     * re-deliveries of prompts already forwarded are filtered before this
     * fires. May be async (e.g. attachment resolution).
     */
    onInboundMessage?: (msg: SDKMessage) => void | Promise<void>;
    /**
     * `control_response` from claude.ai — the user answered a `can_use_tool`
     * prompt sent via `sendControlRequest`. Caller correlates by `request_id`.
     * Return `false` when the response is rejected (malformed/forged) so the
     * prompt stays eligible for initialize re-delivery; void = accepted.
     */
    onPermissionResponse?: (res: SDKControlResponse) => boolean | void;
    /** `interrupt` control_request from claude.ai. Already auto-replied-to. */
    onInterrupt?: () => void;
    /**
     * `stop_task` control_request from claude.ai — per-task Stop from the
     * client's tasks panel. Resolve = stopped (hosts should treat a task the
     * process no longer tracks or that already finished as stopped and
     * resolve, so the client prunes the stale row — but NOT a live paused or
     * pending task, nor an ambiguous name matching several live tasks: those
     * should reject so the user sees an accurate
     * refusal); reject = error control_response with the
     * rejection's message. Omit if the host has no task registry — the CLI
     * then answers with a "not supported in this context" error.
     */
    onStopTask?: (taskId: string) => Promise<void>;
    /**
     * `background_tasks` from claude.ai — the client's Ctrl+B. With a
     * toolUseId, background the single foreground task that tool_use block
     * started and return whether one was found; without, background every
     * foreground task and return true. May answer asynchronously (e.g. by
     * delegating to `Query.backgroundTasks()`); a rejection is sent as an
     * error reply. Omit if the host has no task registry — the CLI then
     * answers with a "not supported in this context" error.
     */
    onBackgroundTasks?: (toolUseId: string | undefined) => boolean | Promise<boolean>;
    onSetModel?: (model: string | undefined) => {
        ok: true;
        notices?: string[];
    } | {
        ok: false;
        error: string;
    } | void | Promise<{
        ok: true;
        notices?: string[];
    } | {
        ok: false;
        error: string;
    }>;
    onSetMaxThinkingTokens?: (tokens: number | null | undefined, thinkingDisplay?: 'summarized' | 'omitted' | 'highlights' | null) => {
        ok: true;
    } | {
        ok: false;
        error: string;
    } | void | Promise<{
        ok: true;
    } | {
        ok: false;
        error: string;
    } | void>;
    /**
     * `set_permission_mode` from claude.ai. Return an error verdict to send
     * an error control_response (vs silently false-succeeding). Omit if
     * the caller doesn't support permission modes — the shared handler
     * returns a "not supported in this context" error.
     */
    onSetPermissionMode?: (mode: PermissionMode) => {
        ok: true;
    } | {
        ok: false;
        error: string;
    };
    /** `rename_session` from claude.ai. Return an error verdict to reject. */
    onRenameSession?: (title: string) => {
        ok: true;
    } | {
        ok: false;
        error: string;
    };
    /**
     * Transport died permanently. 401 = JWT expired (re-attach with fresh
     * secret), 4090 = epoch superseded (no longer the active worker),
     * 4091 = CCRClient init failed, 4092 = codeless close (defensive
     * fallback — cause unknown), 4093 = presence heartbeats kept failing
     * while the SSE stream stayed healthy (transport self-heal candidate),
     * 4094 = worker credential expired or rejected on the request path
     * (heartbeat/write auth exhaustion — re-attach with a fresh secret,
     * like 401), 403/404 = permanent SSE HTTP rejection. Transient
     * disconnects (503, network blips) retry indefinitely inside
     * SSETransport and do NOT fire this.
     */
    onClose?: (code?: number) => void;
};
/**
 * Attach to an existing bridge session. Creates the v2 transport
 * (SSETransport + CCRClient), wires ingress routing and control dispatch,
 * returns a handle scoped to this one session.
 *
 * Throws if `createV2ReplTransport` fails (registerWorker error, etc).
 *
 * ALPHA STABILITY. This is a separate versioning universe from the main
 * `query()` surface: breaking changes here do NOT bump the package major.
 * @alpha
 */
export declare function attachBridgeSession(opts: AttachBridgeSessionOptions): Promise<BridgeSessionHandle>;
/**
 * Worker credentials from `POST /v1/code/sessions/{id}/bridge`.
 * Each call bumps `worker_epoch` server-side — the call IS the worker register.
 * @alpha
 */
export type RemoteCredentials = {
    worker_jwt: string;
    api_base_url: string;
    expires_in: number;
    worker_epoch: number;
};
/**
 * Terminal failure from `fetchRemoteCredentials` — retrying with the same
 * inputs is guaranteed to fail. Server-minted reasons arrive as 403 with
 * `error.resource` set to `"untrusted_device"` (token missing/revoked —
 * enroll) or `"session_stale_relogin"` (OAuth session older than the
 * freshness window — re-authenticate). `"invalid_session_id"` is
 * client-minted: the session id failed validation (`/^[a-zA-Z0-9_-]+$/`)
 * before any request was sent. `"request_rejected"` is any other
 * authoritative non-retryable 4xx (the server answered; neither time nor a
 * new credential changes the request). `"malformed_response"` is a 2xx this
 * client could not parse — the mint SUCCEEDED server-side (each call bumps
 * `worker_epoch`), so retrying epoch-bumps per attempt; not transient, not
 * an authoritative denial.
 * @alpha
 */
export type CredentialsFailure = {
    terminal: true;
    reason: 'untrusted_device' | 'session_stale_relogin' | 'invalid_session_id';
} | {
    terminal: true;
    reason: 'request_rejected';
    /** HTTP status, for the debug trail and user-facing hints. */
    status: number;
    /**
     * 403 only: who wrote the rejection, from response headers — the
     * origin (`request-id: req_…`), a Cloudflare edge before it, or a hop
     * that never reached Anthropic. Attribution for telemetry/copy; not a
     * verdict on ownership.
     */
    source?: 'origin' | 'nonorigin_cf' | 'nonorigin_other';
} | {
    terminal: true;
    reason: 'malformed_response';
    /** HTTP status, for the debug trail and user-facing hints. */
    status: number;
};
/**
 * Non-terminal classified rejection: the OAuth bearer itself was rejected
 * (401). Retrying with the SAME credential is pointless, but a DIFFERENT
 * credential can succeed (post-re-authentication) — distinct from
 * `CredentialsFailure` (`terminal: true`) and from null, which is reserved
 * for transient transport-shaped failures (network error / timeout / 5xx).
 * @alpha
 */
export type CredentialsRejection = {
    terminal: false;
    reason: 'oauth_rejected';
};
/**
 * Type guard for `fetchRemoteCredentials` results.
 * @alpha
 */
export declare function isCredentialsFailure(r: RemoteCredentials | CredentialsFailure | CredentialsRejection | null): r is CredentialsFailure;
/**
 * Type guard for the non-terminal classified 401 rejection. Accepts
 * `unknown`: callers hand it unions whose success arm is a plain string
 * (session ids), and it narrows structurally.
 * @alpha
 */
export declare function isCredentialsRejection(r: unknown): r is CredentialsRejection;
/**
 * Git source/outcome context attached to a v2 code session on create.
 * @alpha
 */
export type CodeSessionGitContext = {
    gitRepoUrl: string;
    branch: string;
    /**
     * The repo's default branch, when authoritatively known. LOAD-BEARING
     * for branch continuity: when absent, `branch` is omitted from
     * `outcomes.branches` entirely (the classification never acts on a
     * guess), so the remote session works on a runner-generated branch
     * instead of `branch`, with only a debug-level signal. Callers that
     * want the session to check out AND push to `branch` must supply
     * this — read `git symbolic-ref refs/remotes/origin/HEAD`, or run
     * `git remote set-head origin -a` to repair a missing symref.
     */
    defaultBranch?: string;
};
/**
 * Caller-owned dedupe state for createCodeSession's branch-drop debug
 * signal: create one object per logical create (outside your retry
 * loop) and pass it to every attempt so the drop logs once per
 * decision. Omit it to log on every attempt.
 * @alpha
 */
export declare type BranchDropLogDedup = {
    lastKey?: string | null;
};
/**
 * Terminal failure from `POST /v1/code/sessions` — retrying with the same
 * inputs fails identically. `reason` distinguishes the recognized
 * `session_grouping_id` rejection family (`"grouping_rejected"` — the
 * caller may retry without the grouping) from any other authoritative
 * non-retryable 4xx (`"request_rejected"`) and from a 2xx this client
 * could not parse (`"malformed_response"` — the create SUCCEEDED
 * server-side, so a retry would orphan one session per attempt).
 * @alpha
 */
export type CreateSessionFailure = {
    terminal: true;
    reason: 'grouping_rejected' | 'request_rejected' | 'malformed_response';
    status: number;
    detail: string | undefined;
};
/**
 * Type guard for `createCodeSession` results. Matches only `terminal: true`
 * failures — a `CredentialsRejection` (`terminal: false`) does not match.
 * @alpha
 */
export declare function isCreateSessionFailure(r: string | CreateSessionFailure | CredentialsRejection | null): r is CreateSessionFailure;
/**
 * `POST /v1/code/sessions` — create a fresh CCR session. Returns the `cse_*`
 * session id on success, a classified `CreateSessionFailure` (terminal —
 * don't retry; see its `reason`), a `CredentialsRejection` when the OAuth
 * bearer was rejected (retry only with a NEW credential), or null on
 * transient transport-shaped failures (network error / timeout / 5xx).
 *
 * Callers supply their own OAuth token — this is a thin HTTP wrapper with no
 * implicit auth, so it works from any process (not just the CLI).
 * @alpha
 */
export declare function createCodeSession(baseUrl: string, accessToken: string, title: string, timeoutMs: number, tags?: string[], gitContext?: CodeSessionGitContext, cwd?: string, model?: string, sessionGroupingId?: string, dropLogDedup?: BranchDropLogDedup): Promise<string | CreateSessionFailure | CredentialsRejection | null>;
/**
 * `POST /v1/code/sessions/{id}/bridge` — mint a worker JWT for the session.
 * Returns credentials, a `CredentialsFailure` for terminal failures (don't
 * retry — see `CredentialsFailure.reason` for remediation), a
 * `CredentialsRejection` when the OAuth bearer was rejected (retry only
 * with a NEW credential), or null on transient transport-shaped failure. The call IS the worker register (bumps epoch
 * server-side), so pass `epoch: creds.worker_epoch` to `attachBridgeSession`
 * to skip a redundant register.
 *
 * `trustedDeviceToken` sets the `X-Trusted-Device-Token` header. Required
 * when the server's `sessions_elevated_auth_enforcement` flag is on
 * (bridge sessions are SecurityTier=ELEVATED). See anthropics/anthropic#274559.
 * @alpha
 */
export declare function fetchRemoteCredentials(sessionId: string, baseUrl: string, accessToken: string, timeoutMs: number, trustedDeviceToken?: string): Promise<RemoteCredentials | CredentialsFailure | CredentialsRejection | null>;
