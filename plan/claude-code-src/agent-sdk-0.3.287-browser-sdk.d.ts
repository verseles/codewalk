/**
 * API surface definition for @anthropic-ai/claude-agent-sdk/browser.
 *
 * This file is the source of truth for the browser export's public types.
 * It imports ONLY from agentSdkTypes.ts so the compiled .d.ts has exactly
 * one import to rewrite (./agentSdkTypes → ./sdk) for the flat package layout.
 *
 * Compiled by scripts/build-ant-sdk-typings.sh; see build-agent-sdk.sh for the
 * path rewrite and copy into the package.
 */
import type { CanUseTool, HookCallbackMatcher, HookEvent, McpServerConfig, OnElicitation, OnUserDialog, Query, SDKMessage, SDKUserMessage } from './agentSdkTypes.js';
export type { CanUseTool, ElicitationRequest, ElicitationResult, HookCallbackMatcher, HookEvent, McpSdkServerConfigWithInstance, McpServerConfig, OnElicitation, OnUserDialog, Query, SDKAssistantMessage, SDKMessage, SDKResultMessage, SDKSystemMessage, SDKUserMessage, UserDialogRequest, UserDialogResult, } from './agentSdkTypes.js';
export { createSdkMcpServer, tool } from './agentSdkTypes.js';
export type OAuthCredential = {
    type: 'oauth';
    token: string;
};
export type AuthMessage = {
    type: 'auth';
    credential: OAuthCredential;
};
export type WebSocketOptions = {
    url: string;
    headers?: Record<string, string>;
    authMessage?: AuthMessage;
};
export type SSEOptions = {
    /** SSE read endpoint, e.g. `…/v1/code/sessions/{id}/events/stream`. */
    streamUrl: string;
    /** POST write endpoint, e.g. `…/v1/code/sessions/{id}/events`. */
    sendUrl: string;
    /**
     * The CCR session ID — required to build the `AddClientEventFromClient`
     * request body that `sendUrl` expects.
     */
    sessionId: string;
    /**
     * Headers sent on both the SSE GET and every POST. Set `Authorization` and
     * `anthropic-client-platform` here — the SDK cannot determine the host
     * surface (web / iOS / Android / desktop) itself.
     */
    headers?: Record<string, string>;
    /**
     * Resume cursor for the first connect: the stream delivers only events
     * whose `sequence_num` is greater. For a consumer that seeded its
     * transcript from the REST event list — pass the highest `sequence_num` it
     * has already applied (for a query replacing an earlier one,
     * `getSseLastSequenceNum()` of that query, which only ever covers messages
     * it actually yielded). Omitted or 0 starts from the beginning of the
     * retained stream.
     */
    fromSequenceNum?: number;
    /**
     * Called when the server reports (`catch_up_truncated`) that it could not
     * replay every event after the resume cursor — the stream continues from a
     * later point, so re-fetch the gap from the REST event list and reseed.
     * Each occurrence is also counted in `getSseDropCounts()` under
     * `catch_up_truncated`. Exceptions thrown by the handler are contained.
     */
    onCatchUpTruncated?: () => void;
    /**
     * Called for each `delivery_update` frame: the worker's acknowledgement of
     * one event this session was sent (`event_id` — matches the `event_id` of
     * that event's own durable echo, see `getCcrEvent()`), with the raw server
     * status string — `"DELIVERY_STATUS_RECEIVED"`, `"DELIVERY_STATUS_PROCESSING"`
     * (the worker began the turn) or `"DELIVERY_STATUS_PROCESSED"` (that turn
     * ended); treat unknown values as informational — and the server
     * `timestamp` when present. Not durable: a reconnect does not replay
     * earlier updates. Malformed frames are counted in `getSseDropCounts()`
     * under `malformed_delivery_update`; handler exceptions are contained.
     */
    onDeliveryUpdate?: (update: {
        event_id: string;
        status: string;
        timestamp?: string;
    }) => void;
};
type BrowserQueryOptionsBase = {
    prompt: AsyncIterable<SDKUserMessage>;
    abortController?: AbortController;
    canUseTool?: CanUseTool;
    hooks?: Partial<Record<HookEvent, HookCallbackMatcher[]>>;
    mcpServers?: Record<string, McpServerConfig>;
    jsonSchema?: Record<string, unknown>;
    onElicitation?: OnElicitation;
    onUserDialog?: OnUserDialog;
    /**
     * When enabled, the remote CLI emits a `prompt_suggestion` message after
     * each turn's result. At most one per turn.
     */
    promptSuggestions?: boolean;
};
/**
 * Exactly one of `websocket` | `sse` must be provided. `sse` is the v1alpha2
 * path and is preferred for new integrations; `websocket` remains for
 * existing callers during the migration.
 */
export type BrowserQueryOptions = BrowserQueryOptionsBase & ({
    websocket: WebSocketOptions;
    sse?: never;
} | {
    sse: SSEOptions;
    websocket?: never;
});
/**
 * Create a Claude Code query in the browser over either SSE (preferred) or
 * WebSocket.
 *
 * @example
 * ```typescript
 * import { query } from '@anthropic-ai/claude-agent-sdk/browser'
 *
 * const messages = query({
 *   prompt: messageStream,
 *   sse: {
 *     streamUrl: 'https://api.example.com/v1/code/sessions/ID/events/stream',
 *     sendUrl: 'https://api.example.com/v1/code/sessions/ID/events',
 *     headers: { Authorization: `Bearer ${token}` },
 *   },
 * })
 * for await (const message of messages) {
 *   console.log(message)
 * }
 * ```
 */
export declare function query(options: BrowserQueryOptions): Query;
/**
 * Readiness sentinel for the peer-frame text-envelope guard
 * (userFrameRequiresWorkerSource): `true` means the SSE transport enforces
 * the full predicate on peer-authored `user` frames. The change enabling
 * `ccr_v2_subscribe_sse_web` in a consumer repo must assert this reads
 * `true` before flipping the flag.
 */
export declare const G4_TEXT_ENVELOPE_ARM_PORTED: boolean;
/**
 * Cumulative per-category dropped-frame counts for a query() created with
 * the `sse` transport — the aggregated receipt for the
 * `ccr_v2_subscribe_sse_web` enablement review (category → count only,
 * never frame contents). Returns undefined for WebSocket-transport queries.
 */
export declare function getSseDropCounts(query: Query): Readonly<Record<string, number>> | undefined;
/**
 * Resume cursor of a query() created with the `sse` transport: the highest
 * `sequence_num` of a durable message this query has yielded (or the
 * `fromSequenceNum` seed before any was). It is advanced immediately before
 * each message is yielded, so while the consumer handles message `m` it is
 * already `>= getCcrEvent(query, m).sequence_num`, and it never covers a
 * message the consumer was not handed — frames still buffered when the
 * consumer stops iterating, and durable events the SDK dropped or consumed
 * internally, do not advance it. So at any point — mid-stream, after a
 * `break`, or once the iterator has finished — it is where a REST catch-up
 * fetch or a replacement query()'s `fromSequenceNum` should resume (the
 * transport's own transparent reconnects use a separate internal wire
 * cursor). Per-message ordering still reads `getCcrEvent(query, message)`.
 * Returns undefined for WebSocket-transport queries and before any sequence
 * number is known.
 */
export declare function getSseLastSequenceNum(query: Query): number | undefined;
/**
 * The wire envelope of the durable CCR event (SSE `client_event` frame) that
 * delivered `message` on the `sse` query `query`: `sequence_num` is the
 * session-wide order the server assigned, `event_id` is unique per event,
 * `created_at` (RFC 3339 store time) and `source` (server-assigned channel,
 * e.g. `worker`) appear when the frame carries them. Provenance contract:
 * the transport records the envelope from the delivering frame, keyed by the
 * exact message object it yields, and never writes it onto the message; a
 * `ccr_event` field arriving inside any payload is a sender-authored claim
 * and is stripped, so this accessor is the only way to read an envelope.
 * Looked up by object identity — pass the message exactly as the query
 * yielded it. Returns undefined for anything that transport did not itself
 * yield from a durable frame: unsequenced ephemerals (`stream_event`,
 * `sources_changed`, live-only `system` status frames), messages of a
 * WebSocket-transport query, copies, and caller-constructed objects,
 * regardless of the fields they carry. `sequence_num` is dense over ALL of
 * the session's events, including control frames the SDK consumes
 * internally and frames it drops, so consecutive yielded messages need not
 * carry consecutive numbers.
 */
export declare function getCcrEvent(query: Query, message: SDKMessage): {
    event_id: string;
    sequence_num: number;
    created_at?: string;
    source?: string;
} | undefined;
