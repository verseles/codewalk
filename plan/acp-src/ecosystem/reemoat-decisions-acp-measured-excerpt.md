<!-- Raw extract from https://github.com/rends-east/reemoat/blob/568beecb2e4ff3acff1be75690f68af462b6a483/docs/DECISIONS.md lines 31711-33980 (AGPL-3.0). Measured ACP agent behaviour; evidence only. -->
### The agent process, its capabilities and subagent lineage

#### Q5.37 — Why is the ACP `fs` capability granted?

**Rule.** `session.ts` implements `fs/read_text_file` and `fs/write_text_file`
by calling `readFile`/`writeFile` **in the daemon's own process**, on a path the
agent chose, and the capability is granted.

**Why.** That was a write primitive running outside the sandbox, so a sandboxing
runtime had to decline. There is no sandbox: the agent could make the same call
itself, so refusing would confine nothing and only lose the
`source: "fs_write"` half of the duplicated `file_change` pair.

**Status.** Current

#### Q5.38 — Why is the gate that could decline `fs` kept even though nothing declines it?

**Rule.** `AcpClient` answers `methodNotFound` when the runtime declines — the
same thing an unimplemented method returns — and `LaunchOptions.fileIo` is
**required**, so deleting the argument at either call site is a type error
rather than a silent grant.

**Why.** Declaring a capability is a *statement to a party we do not trust*, and
a statement is not a gate: the two handlers used to be registered
unconditionally, so an agent could send the request regardless of what was
advertised and `session.ts` would run it. That is the seam a confining runtime
would use, and re-declining is cheap.

**Measured.** 2026-07-30: kimi made five reverse-RPC calls with `fs` enabled and
none with it disabled; claude never used it either way. `pnpm daemoncheck`
drives a real `AcpClient` over in-memory pipes and sends the forbidden request.

**Rejected.** The old assertion, which compared a `readonly` constant to its own
literal and stayed green with the gate removed.

**Status.** Current

#### Q5.39 — Why is an agent handle still a union when only one arm is produced?

**Rule.** An agent handle is a union whose second arm is read-only legacy. Only
the local arm is produced now; it is kept as a union rather than flattened to
`number` because `toHandle` still has to answer **no handle at all**, which is a
different fact from "pid 0".

**Why.** It had two arms while agents ran in containers: a host pid and a
process group inside one are different number spaces with different fences, and
stored in a single column they would be indistinguishable — with the cost of
confusing them being SIGKILL to whatever now holds that number. Rows written by
the multi-tenant daemon can still carry a container arm on disk; the reaper
reports such a handle as one it will not signal, which is the honest answer
rather than a guess at a number in somebody else's namespace.

**Status.** Current

#### Q5.40 — Why does the daemon carry only the parent link and never reorder to prove lineage?

**Rule.** A subagent is a tool call that started other tool calls, and the
daemon never reorders to prove it. The parent link is carried and nothing else
is: no depth, no synthesised parent, no buffering of a child until its parent is
seen, no validation against ids already seen. Arrival order stays seq order
stays delivery order.

**Why.** Each of those is a real temptation and each breaks something. Depth is
derived from the chain, and a stored copy disagrees with it the moment the
parent is evicted — the log evicts a *prefix*, so that is the common case. A
hold is an unbounded wait on the emit path. A "seen ids" set both grows without
bound and *drops a true edge* exactly when the parent has aged out.

**Status.** Current

#### Q5.41 — What three lineage rules must every reader of the event stream obey?

**Rule.** Written into `wire.ts` because nothing enforces them: a parent may be
absent and that is **normal**; a child may arrive first; and **every traversal
must be cycle-safe**.

**Why.** The daemon normalizes only self-reference, so two mutually-parented
calls are something a client will be sent.

**Status.** Current

#### Q5.42 — Why is `MAX_DEPTH` not the cycle bound?

**Rule.** A visited set per walk is the actual requirement, and a repeated
`toolCallId` is refused for the same reason.

**Why.** The third rule used to read "depth must be bounded by the client
(`MAX_DEPTH`)". `MAX_DEPTH` says when a walk stops *climbing* and says nothing
about how many hops it may take. Rebinding an id mid-pass is what let two live
entries point at each other.

**Measured.** `placeNodes` held `MAX_DEPTH` and still ran forever on a
two-element cycle — in both of its walks, on two `tool_call` events — inside
`EventList`'s `useMemo`, so an unrecoverable tab that came back on every reload
because the events are on disk. `pnpm webcheck` drives both shapes, and a
regression there does not print `FAIL` — it hangs the driver.

**Status.** Current

#### Q5.43 — Why is the parent id bounded at ingest rather than at the store?

**Rule.** The parent id is bounded at ingest — `MAX_PARENT_ID_CHARS`, 256, in
`acp/subagents.ts`.

**Why.** `truncateEvent` spreads the field through untouched on both arms by
design, so without a ceiling an agent-chosen string walks an event past the
per-event cap with nothing willing to shrink it.

**Status.** Current

#### Q5.44 — Why is the client's nesting layout decided by whether a call has children?

**Rule.** The client's **layout** is decided by whether a call has children —
never `kind === "think"`, never a title match.

**Why.** That is what makes kimi's degradation structural: its adapter filters
subagent events at the source, so no call ever has a child and every card is the
card it was. `pnpm webcheck` asserts the node tree on that path is unchanged —
keys and childlessness, which is what a driver with no DOM can honestly claim.

**Status.** Current

#### Q5.45 — What does the agent's own `subagent` flag decide, and where is it read from?

**Rule.** The flag decides whether the card is *drawn* as a delegation: the icon
takes `subagent || steps > 0` while nesting, the step badge and the running
headline still take children alone, and the badge is gated on `steps` so a
childless spawn does not claim "0 steps". The flag is read from the `tool_call`,
never merged from an update; `session.ts` copies only the parent edge onto an
update.

**Why.** claude drops `subagent: true` on the spawn's own completing update, so
an update silent about the flag must not be mistaken for one denying it. Reading
it only from the spawn is what avoids the flicker the old rule avoided by
ignoring the flag entirely.

**Measured.** 2026-08-01: three delegations of one trivial task rendered as two
robots and a brain. The odd one out was a delegate that answered from the model
alone, so it made no tool call to attribute, had no children ever, and fell
through to the kind icon — and claude's spawn is `kind: "think"`. "No step ever
arrives" is a case, not a transient.

**Status.** Current

### The event log

#### Q5.46 — Why is a session's log never truncated?

**Rule.** `DEFAULT_MAX_EVENTS` and `DEFAULT_MAX_BYTES` are `Infinity`. A
conversation keeps every event it ever produced, for as long as the session
exists.

**Why.** It was 5000 events / 8 MiB, evicting a **prefix**. A conversation
somebody was still working in had lost its beginning, mid-word, permanently —
and the client could not distinguish that from a conversation that started
there, so the first thing a reader concludes is that the *client* failed to load
it.

**Measured.** Session `s_a7b154a7` on the development machine reached
`dropped: 6144`, so its oldest surviving event was an agent `text` chunk
containing the two characters `" for"`.

**Status.** Current

#### Q5.47 — Why is the invariant "no truncation" rather than "a bigger window"?

**Rule.** There is no number that makes prefix eviction acceptable. `Infinity`
is the default rather than deleting the machinery: `REEMOAT_LOG_EVENTS` and
`REEMOAT_LOG_BYTES` still bound it for an operator who wants that, and
`daemoncheck` drives eviction with `maxEventsPerSession: 8`, so the path stays
exercised instead of becoming code nobody runs.

**Why.** The failure is not proportional to the bound: losing the first half of
a conversation is not half a loss, because the part that says what the work *is*
— the prompt, the plan, the constraints somebody typed once — is at the top, and
the top is what a prefix eviction takes first. A transcript you cannot trust to
be whole is one you keep a copy of somewhere else, which is this product gone.

**Status.** Current

#### Q5.48 — What did removing the log window cost, and where is the bound now?

**Rule.** The *attach* is bounded where the *history* used to be:
`ATTACH_REPLAY_MAX` replays the newest 2000 and sends
`lagged{reason: "backlog"}` naming the range it skipped. That is the one lagged
reason which is **not** a loss, and a client must never draw it as a hole — the
events are on disk, `GET /sessions/:id/events` serves them, and `store.ts` pages
them in.

**Why.** The window was not arbitrary; it was holding up the WS queue.
`StreamConnection.attach` drains its whole backlog into an 8000-item queue in
one synchronous block, and past that it collapses and reports
`lagged{slow_consumer}` — a lie about a client that was never given the chance
to be slow. Bounding the socket rather than the record is the right way round: a
socket is a live channel and a transcript is a record, and only the socket ever
had a reason not to carry an arbitrary amount at once.

**2000 was only ever under the *event* half of the queue, and the lie came back
through the byte half.** `enqueue` also collapses on `MAX_QUEUE_BYTES` (16 MiB),
and at the 128 KiB per-event ceiling a full replay is 250 MiB — so a large attach
collapsed on bytes and reported `slow_consumer` after all, with the whole drain
still synchronous and the first `send` callback not yet run. `gapPlan` files that
as a permanent "events lost" marker over a conversation the daemon holds intact.
`emit`/`enqueue` now take a `replaying` flag and `collapse` takes the reason as an
argument: a replay overflow is `backlog`, which the client already answers by
refetching from `GET /sessions/:id/events`, and it is not recorded in the window
that closes the socket `4003`.

**Rejected.** A byte-bounded replay floor — reading fewer events so the drain
cannot exceed the queue. It needs the events read twice to size them, and the
defect was never the collapse: it was the *frame*.

**Measured.** `daemoncheck` attaches at `since=0` over a real loopback socket
against 400 events of 48 KiB — a fifth of `ATTACH_REPLAY_MAX` and ~19 MiB, so the
fixture asserts as a measurement that only the byte ceiling can be what fired.
Exactly one `lagged` arrives, its reason is `backlog`, it names a range ending at
`lastSeq`, and `caught_up` still lands at the head. What is **not** asserted is the
second half — that a `backlog` collapse is not recorded toward the 4003 — because
one attach can only collapse once (`collapse` sets `cursor = head`, so the drain's
next `read` is empty), and a second needs real TCP backpressure, which Q6.28
already records as the untested path.

**Status.** Current

#### Q5.49 — Which two log bounds survive, and why are they a different act?

**Rule.** `truncateEvent` still shortens a single oversized event at 128 KiB and
says so in the text it leaves behind; `SqliteSessionStore.prune` removes an
inactive session untouched for 7 days, or one past the 200 cap — never a live or
daemon-ended one, never under 50 rows (Q2.222) — and removes it *entire*, with
its events.

**Why.** A local, visible cut is not the removal of something a person wrote.
The line is: a conversation is kept whole or not at all, never trimmed to a
suffix.

**Status.** Current

#### Q5.50 — Why does the emit path never await?

**Rule.** `SessionLog.append` is synchronous and so is `EventStore`. A
connection's listener is a synchronous array push and nothing more.

**Why.** That path runs inside the agent's RPC handler, so anything that blocks
there blocks the agent.

**Status.** Current

#### Q5.51 — Why does `EventStore` stay synchronous, `read` included?

**Rule.** `EventStore` stays synchronous, `read` included. If an async store is
ever needed, put it behind a write-behind buffer rather than making `append`
async.

**Why.** Node's SQLite bindings are synchronous, so async buys nothing — and it
costs the attach-is-one-synchronous-block argument below.

**Status.** Current

#### Q5.52 — Why is attach one synchronous block?

**Rule.** In `StreamConnection.attach` there is no `await` between
`log.read(since)` and `log.subscribe(...)`.

**Why.** That is the entire reason resume has no gaps and no duplicates: an
append lands strictly in the backlog or strictly through the listener.
Introducing an await there reopens the race, and the `seq <= cursor` filter
alone will not save you.

**Status.** Current

#### Q5.53 — Why does fan-out guard every listener individually?

**Rule.** `SessionLog.append` wraps each listener call in `try/catch` and evicts
the thrower.

**Why.** Unguarded, one broken connection aborts the loop and every *later*
listener silently misses that seq.

**Status.** Current

### Permissions and the registry

#### Q5.54 — Why does `settle()` resolve the agent before it logs?

**Rule.** Order is: `pending.delete` (the compare-and-swap) → record in
`resolved` → **resolve the agent's promise** → append → fan out.

**Why.** Appending first means a throw leaves the permission recorded as
answered while the agent's reverse-RPC is never answered — a permanent hang that
also switches off `status: "blocked"`, the one signal that would reveal it.

**Measured.** `pnpm daemoncheck` drives this against an agent that genuinely
waits — the turn does not end until the answer comes back — so the ordering is
asserted through its only observable consequence: the agent is handed the option
a human picked. Deleting `pending.delete` fails **twelve** cases including the
two-clients-at-once one; making the resolve a no-op fails **seventeen**. Both
measured, which is what makes those assertions coverage rather than decoration.

**Status.** Current

#### Q5.55 — Why were those driver counts first written as "ten" and "four", and why does the correction matter?

**Rule.** Driver reads are guarded — `waitingOn`, and one shared
`answerPermission` whose parse cannot throw — so a broken invariant produces a
red line and a count instead of a stack trace.

**Why.** The counts were truncated by a crash: the block read
`pendingPermissions[0]!.permissionId` and `body.error.code` unguarded, and a
non-null assertion is erased at runtime — so a regression printed some `FAIL`
lines and then died with a `TypeError`, with no failure total and with every
later section of the driver, the expired-id block and `/clear` included, never
executed at all. In a repository where the drivers are the whole safety net,
"four" was not a small blast radius, it was thirteen failures the crash got to
before the driver did.

**Measured.** "ten" and "four" corrected to twelve and seventeen.

**Status.** Current

#### Q5.56 — Why does the permission promise executor hold exactly one statement?

**Rule.** Only the resolve capture.

**Why.** A throw inside an executor rejects the promise, which would answer the
agent with an error while leaving the entry in `pending` — the session then
advertises `blocked` forever on something already refused.

**Status.** Current

#### Q5.57 — Why does the registry append permission events rather than `session.ts`?

**Rule.** The registry appends permission events, not `session.ts`.

**Why.** `Session`'s `EventQueue` drains only while a prompt generator is being
consumed, so an event pushed there outside a turn is stranded — logged after its
own resolution, or discarded by `queue.close()`.

**Status.** Current

#### Q5.58 — Why do agents spawn `detached` and get killed by process group?

**Rule.** `detached: true` on the spawn, and the kill is by process group. It
applies to the **login** pty as well.

**Why.** `claude-agent-acp` runs the `claude` CLI as its own child and cleans up
only via `process.on("exit")`, which does not run under SIGKILL. Killing the pid
alone strands a grandchild holding the session cwd. Verified, not theoretical.
`script` forks the CLI and the CLI may fork again, so a kill ladder that reaches
only `script` strands a pty for every login somebody walked away from. The rule
did not weaken when the agent moved into a container — it relocated (into
`setsid -w` and a pgid file, because signalling a `docker exec` client does not
reach inside) and has now relocated back.

**Status.** Current

#### Q5.59 — Why is every RPC that writes to agent stdin bounded?

**Rule.** Every RPC that writes to agent stdin carries a timeout.

**Why.** The SDK puts no timeout on those writes. In `doDispose` they sit
upstream of `client.close()`, the only code that ever sends SIGTERM/SIGKILL, so
an unbounded await there means an orphan.

**Status.** Current

### The agent's state on the snapshot

#### Q5.60 — Why are the agent's controls complete state on the snapshot rather than a delta or a log entry?

**Rule.** ACP's `current_mode_update` carries just the new mode id, so
`session.ts` merges it against what it holds before emitting `agent_config`, and
the complete state rides `SessionSnapshot`. The registry appends the event, not
`session.ts`.

**Why.** Otherwise every client needs a reducer of its own and disagrees with
the snapshot the moment it misses one. It rides the snapshot because
`session_started` lands in the log *after* the first `prompt` event: a client
reading the controls off the transcript alone would draw nothing until the
session's first reply, which is exactly when somebody wants to pick a mode. The
registry appends for the same reason it appends permission events — `Session`'s
queue drains only inside a turn.

**Status.** Current

#### Q5.61 — Why is "snapshot" not the same as "poll"?

**Rule.** `server.ts`'s `unsubWatch` sends a `{type:"snapshot"}` frame to every
attached client on every `touchSafe()`, so the snapshot is a *push* channel and
"snapshot-only" costs nothing in latency. `title`, `pinned` and `contextUsage`
are snapshot-only.

**Why.** State which does not belong in a transcript stays out of the log
entirely — a rename is not something the agent said, and a token count
superseded microseconds later is not narrative.

**Status.** Current

#### Q5.62 — Why is a streaming measurement fanned out only on the value a client can see?

**Rule.** `applyContextUsage` assigns the field on every update — a poller and a
fresh attach always read the exact number — and calls `touchSafe` only when the
whole percent, the window size or the cost changed. `usageWorthAnnouncing` is
pure and `pnpm daemoncheck` asserts it. `applyAgentConfig` still touches
unconditionally, because a mode change has no rate.

**Why.** `touchSafe()` builds a snapshot, writes a row and enqueues a frame *per
attached client*, on the agent's own synchronous emit path — so mirroring
`usage_update` unconditionally is thousands of frames per turn against an
8000-item outbound queue, which is not a slow consumer, it is us.

**Measured.** 2026-07-31 against claude-agent-acp 0.63.0: `usage_update` is
emitted from the `message_delta` handler (`acp-agent.js:2498`), i.e. on
essentially every output token.

**Status.** Current

#### Q5.63 — Why is a config option found by `category` and never by `id`?

**Rule.** A config option is found by ACP's `category`, never by `id`, and an
unknown or absent category renders as a plain labelled control rather than
disappearing. The *values* are not hardcoded either.

**Why.** Claude publishes reasoning effort as `effort` with values
`default|low|…|max`; kimi publishes the same concept as `thinking` with values
`off|…`. They share nothing but `category`, which exists for this and which the
spec says must not be required for correctness. claude drops `bypassPermissions`
from `availableModes` when it runs as root without `IS_SANDBOX`, so a fixed list
would offer a mode the agent rejects.

**Status.** Current

#### Q5.64 — Why are `/model`, `/effort` and `/mode` named by this client rather than by the agent?

**Rule.** `/model`, `/effort` and `/mode` are not commands any of the three agents
publishes — they are built from the controls, keyed on category, and the name is
ours precisely because the id is not portable. Read this before touching
`buildCommands`.

**Why.** An id-keyed table would give claude a `/effort` and kimi nothing,
silently, on one agent only.

**Status.** Current

#### Q5.65 — Why is a command list state, replaced whole, and kept off the poll?

**Rule.** Three claims, each of which was a live temptation. *Replaced whole*:
ACP defines `available_commands_update` as a full list and the adapter's own
comment tells clients to replace their cache. *State, not narrative*: nothing is
appended to the log, and it is not a `SessionEvent`. *Off the poll*: only
`commandsRevision`, a number, is on `SessionSnapshot`; the list is behind
`GET /sessions/:id/commands`. A client refetches on `!==` and never on `>`.

**Why.** Merging would keep offering a command the agent has withdrawn, and the
agent would then refuse the thing its own menu had offered. A logged list would
cost the operator's own first prompt to re-record something that never
accumulates, since the log evicts a **prefix**. The compiler *used* to be no help
on the event question: `estimateBytes` ended `default: return 192` and
`truncateEvent` ended `default: return event`, so a new event type carrying a
command list would have been accounted at 192 bytes against the byte budget and
never truncated, silently. Both `default` arms are gone now and every member of
the union has an explicit arm, so adding one is a compile error in both places —
see Q5's rule on the same subject. A
pending permission earns its 8 KiB on the snapshot because a blocked session has
to be answerable **from the list**; a command list is neither tiny nor needed to
answer *does anything anywhere need me*. A restart puts the revision back to 0
while a client still holds 5, and the answer there is to drop the list, not to
conclude the daemon is behind.

**Rejected.** Clamping the list to poll size — worse rather than cheaper, since
a menu with no `/compact` because it sorted seventeenth is not a smaller menu,
it is a wrong one; `truncateEvent`'s `agent_config` arm already names the
failure.

**Status.** Current

### Logins and the composer's keys

#### Q5.66 — Why is a login driven over HTTP rather than over the WebSocket?

**Rule.** Output is polled; a typed code is a `POST` whose response confirms it
landed. This is the read-only-WS rule rather than an exception to it.

**Why.** `ws.send()` into a half-open socket succeeds silently, and a one-time
login code is the worst possible message to lose that way — sent once,
unrecoverable, and impossible to notice missing from the other end.

**Status.** Current

#### Q5.67 — Why does the login probe run with the pasted credential in its environment?

**Rule.** The probe is executed with the stored credential merged into its
environment. `pnpm daemoncheck` drives every branch through
`LocalRuntimeOptions.exec`.

**Why.** The whole asymmetry rests on it: a clean `false` from
`claude auth status` is believed over a token somebody pasted, and "cannot tell"
falls back to the token. That is only honest if the CLI has *seen* the token —
and it had not, because `execFile` was called with no `env` and inherited the
daemon's, while a pasted credential lives in SQLite and was merged only at
spawn. So a wrong or expired token reported `loggedIn: true`: the Settings
screen said signed in and the first session answered `502 agent_auth_required`,
which is the exact failure this probe was added to prevent.

**Status.** Current

#### Q5.68 — Why is the login command a table lookup and never a request field?

**Rule.** There is no route, body field or header anywhere that names a program
to run.

**Why.** "A caller cannot run code of their choosing as the daemon" is therefore
a property of there being nothing to pass, not a validation somebody has to
remember to write — and it cannot be reopened by a convenience parameter later,
because there is nothing to add one to.

**Status.** Current

#### Q5.69 — Why is the IME guard the load-bearing half of "Enter sends"?

**Rule.** `shouldSend` is a pure function in `keys.ts` and checks for an
in-flight input-method composition before treating Enter as a send.

**Why.** With a Russian, Chinese, Japanese or Korean input method, Enter commits
the candidate being typed — the text is not in the box yet. A bare
`key === "Enter"` sends a half-finished word and swallows the keystroke meant to
finish it, on every message, for everyone on one of those layouts, and it is
invisible from a Latin keyboard. Being pure is the only way `webcheck` can
assert it with no DOM.

**Status.** Current

#### Q5.70 — Why does the command menu take Enter first, and why is Enter the only key it takes?

**Rule.** `composerKey` in `keys.ts` resolves the collision: the menu takes
Enter while open, `shouldSend` takes it otherwise, asserted in both states of
`menuOpen`. `completionKey` carries its **own** IME guard. Escape additionally
calls `stopPropagation`.

**Why.** The resolution used to be two blocks inside `Composer`'s `onKeyDown`
prop, and the documentation claimed `webcheck` asserted it — what `webcheck`
asserted was that the collision *exists*, which stays green with the two blocks
in either order, while reversing them sends a half-typed message instead of
completing a command. `completionKey` runs first, so without its own guard the
IME defect would simply move house: Enter would insert a command instead of
finishing a word. `useKeyboard` binds Escape on `window` to blur whatever has
focus, and dismissing a menu must not also dismiss the soft keyboard.

**Status.** Current

### Files, uploads and downloads

#### Q5.71 — Why is a downloaded file never rendered, and why are two mechanisms needed?

**Rule.** The daemon sends `application/octet-stream` — always, never sniffed,
never the mime the uploader declared, never derived from an extension — plus
`attachment`, `nosniff` and `no-store`; and the client re-types the `Blob` to
`application/octet-stream` before creating an object URL for it. Never
`window.open(blobUrl)`, never a `blob:` URL behind `target="_blank"` — an object
URL reaches an anchor only with `download`, and `webcheck.native-bridge.ts` pins
every `_blank` anchor to an address — never an `<iframe src=blobUrl>`.

**Why.** A `blob:` URL carries the *client's* type and inherits the *creating*
origin, so both halves are needed. The reason is stronger than the usual
stored-XSS one, and it used to be stated as `?token=`: `readCredential` accepted
a token in the query on any route, so any download opened in a tab carried a live
daemon token in `location.search` for script in a rendered response to read and
reach every route on that daemon with.

**That premise is now false and the rule is unchanged, which is the point of
recording it.** `readCredential` reads the query credential only on a request
carrying `upgrade: websocket` (Q1.45), so no download URL can carry one. What
still stands, and is the stronger reason, is that this route serves **any regular
file under a session's workspace**: a rendered HTML or SVG response executes on
the daemon's own origin whatever credential fetched it, where it can reach every
route with whatever the embedding page holds, and a `blob:` made from it inherits
that origin. On the client side the origin creating the blob is the one whose
`localStorage` holds `reemoat.credential`, with no CSP anywhere behind it.
`nosniff` is not redundant beside `attachment` — it also stops a proxy or a CDN in
front of the daemon re-typing the body — and `no-store` because the response is a
private file fetched under a bearer credential.

**Status.** Current

#### Q5.72 — Why is an oversized upload refused on the header first, and why is the body always cancelled?

**Rule.** A truthful `Content-Length` over the limit is refused before a byte is
read; the running byte counter in `Uploads.receive` is the backstop for chunked
bodies and for clients that lie. The body is always cancelled: unlink, then
rmdir, then cancel.

**Why.** That counter is the only bound on a request body anywhere in this
system — nothing in `src/`, the relay or the control plane configures one, and
the relay pipes bodies straight through. Refusing a *half-read* body destroys
the request stream, which through the relay destroys the HTTP/2 CONNECT stream
carrying it, and that surfaces at the browser as the relay's own
`502 tunnel_failed` instead of the 413 the daemon wrote. Cancelling matters more
than the order: the relay's per-stream window is granted on consumption, so a
reader that simply stops parks the sender at 256 KiB, and the next valve above
that is the tunnel's 8 MiB socket-buffer check — which closes the **whole tunnel
for that machine**, taking every other session on it.

**Status.** Current

#### Q5.73 — Which of the four upload refusals actually pins `cancelBody`?

**Rule.** The assertions that nothing was read (`pulled: 0`) are the
load-bearing ones; the mid-body pair assert the property rather than the call,
which is written at the cases themselves so nobody deletes a line believing it
is covered.

**Measured.** By deleting each `cancelBody` call in turn: removing the one after
the read loop — `too_large`, `quota` — changes nothing, because breaking out of
a `for await` calls the async iterator's `return()` and that cancels the stream
anyway. Removing the one on a refusal reached *before* the loop — `too_many`, an
unusable session id — fails immediately.

**Status.** Current

#### Q5.74 — Why must the two remover trees never nest?

**Rule.** `removeWorkspace` guards the codebase's original `rmSync` with
`containedIn(root, worktreeRoot)`; the upload sweep guards the second one with
the mirror. `daemon.ts` refuses to start if either root sits at or under the
other, `daemoncheck` asserts it in both directions, and the sweep additionally
`lstat`s each session directory for a symlink.

**Why.** If either root sat at or under the other, one remover could reach into
the other's tree and neither guard would mean what it says. The symlink refusal
is the same one `worktree.ts` makes, for the same reason, since an upload id is
guessable from a transcript.

**Status.** Current

### The store, its floors and the wire

#### Q5.75 — Why is the WebSocket read-only?

**Rule.** Everything that mutates state is an HTTP request.

**Why.** `ws.send()` into a half-open socket succeeds silently, so an answer
sent over the socket from a dying client would evaporate with no error anywhere.

**Status.** Current

#### Q5.76 — Why is status derived and never stored?

**Rule.** `ManagedSession.status` is computed on every read from `exitRecord` /
`stopRequested` / `pending.size` / `turn`. `snapshot()` returns a frozen plain
object with copied arrays.

**Why.** It cannot then drift from the pending map, and a frame built now and
serialized later must describe now.

**Status.** Current

#### Q5.77 — Why is size accounting null-safe on `FileChangeEvent.oldText`?

**Rule.** Size accounting treats `oldText` as nullable.

**Why.** It is `null` for every file the agent *creates*, which is the common
case, not an edge case.

**Status.** Current

#### Q5.78 — Why does a failed insert become a placeholder at the same seq rather than a hole?

**Rule.** A failed insert becomes a placeholder at the same seq, and the
placeholder is also what `append` returns, not the real event.

**Why.** `read` is `WHERE seq > ?`, so a hole cannot spin the attach loop — it
does something worse: `lagged` is derived from `firstSeq`/`lastSeq`, so a gap in
the *middle* of the log is invisible on the wire and no client can detect it.
Handing a live client the real text at seq 412 while a reconnecting client gets
a placeholder there makes the two disagree about what 412 *is*, undetectably.
Both losing it is better.

**Status.** Current

#### Q5.79 — Why can the store not append to itself?

**Rule.** `SessionLog.append` fans out only what its own call to `store.append`
returned. Degradation is reported through the placeholder and the `onDegraded`
callback, never by logging an extra event.

**Why.** A store-internal recursive append lands on disk and reaches no
subscriber.

**Status.** Current

#### Q5.80 — Why are `lastSeq` and `dropped` floors on the session row, raised at load?

**Rule.** `lastSeq`/`dropped` are floors on the session row, raised at load.

**Why.** A session whose events were pruned would otherwise restart at seq 1,
and a client resuming from a cursor it already holds would be clamped to 0 by
`attach` and replayed — receiving *different events under numbers it has already
seen*.

**Status.** Current

#### Q5.81 — Why is `gap` derived from `oldestAvailable()` and never from `firstSeq` alone?

**Rule.** `count > 0 ? firstSeq : lastSeq + 1` is the only form that stays
honest when the log is empty but the sequence is not, and both `attach` and
`GET /sessions/:id/events` have to use it or they disagree about the same
session.

**Why.** `firstSeq` is 0 when the table holds no row for a session, so
`since < firstSeq - 1` is `since < -1` — false for every cursor, on the one path
where *everything* was lost. That state is reachable twice over: a disk
rejecting every insert burns seqs and stores nothing, and a `remove()` that
deleted the events and threw before the session row leaves the floors behind
with no rows under them.

**Measured.** Stats `{firstSeq: 0, lastSeq: 500, count: 0}` answered a `since=0`
attach with `gap: false`, no backlog, `caught_up: 0`, then the next live event at
seq 501.

**Status.** Current

#### Q5.82 — Why are the floors asserted against the real store rather than the memory one?

**Rule.** `daemoncheck` drives `SqliteEventStore` directly: the round trip
across a reopen, eviction taking a strict *prefix* with `firstSeq = dropped + 1`
and the newest row never taken, the placeholder that lands at the same seq when
serialization throws, and `seedFloors`.

**Why.** Every registry case in `daemoncheck` backs its sessions with
`MemoryEventStore`, so `SqliteEventStore` — the thing that actually holds
somebody's conversation across a restart — was named by no driver at all.

**Measured.** A session whose rows are gone continues at seq 501 rather than
restarting at 1. Deleting the `seedFloors` call fails exactly those three cases,
which is the failure a client would otherwise meet as *different events under
numbers it has already seen*.

**Status.** Current

#### Q5.83 — Why does `doStop` use `exitRecord ??=`?

**Rule.** `doStop` assigns the exit record only if there is not one already.

**Why.** Stopping a restored session must not rewrite `daemon_restarted` as
`stopped`, which would erase the fact that a restart happened. `onStartFailed`
has always guarded itself this way; `doStop` did not.

**Status.** Current

#### Q5.84 — Why is orphan reaping fenced by `os.uptime()`?

**Rule.** Only a session created since the last boot may have its recorded pid
signalled.

**Why.** Pids wrap and a reboot resets them, so an older row names a number that
now belongs to somebody else.

**Status.** Current

### Resume, worktrees, git and the database on disk

#### Q5.85 — Why is resume `session/resume` and never `session/load`?

**Rule.** Resume is `session/resume`, never `session/load`.
`AcpClient.supportsSessionResume` reads `sessionCapabilities.resume`, and
`Session.resume` refuses an agent that lacks it before any network call.

**Why.** Load replays the whole message history back as `session/update`
notifications, and this daemon already holds that transcript — taking it again
would duplicate every event in the log. The rule turned out to be a *market*
constraint too: `loadSession` is the older, wider capability and
`sessionCapabilities.resume` the newer, narrower one, so "any ACP agent" is much
narrower than the ~30 entries in Zed's registry suggest. The honest gate on
making agents configurable is *how many implement
`sessionCapabilities.resume`*, not how many type references `AgentId` has.

**Measured.** 2026-07-30 against `gemini-cli` 0.53.0 — the ACP reference
implementation — `agentCapabilities` is
`{loadSession: true, promptCapabilities: …, mcpCapabilities: …}` with **no
`sessionCapabilities` key at all**. kimi advertises both: `loadSession: true`
*and* `sessionCapabilities: {list: {}, resume: {}}`.

**Status.** Current

#### Q5.86 — Why does worktree removal refuse by default and prune unconditionally?

**Rule.** The unpushed-commits check is ours, `@{upstream}` is not used because
it throws when unset, and `worktree prune --expire=now` runs on *every* removal
path including the ones that already failed. Nothing outside the managed
worktree root is ever `rm`ed, and a branch is never deleted unless it was
created here.

**Why.** `git worktree remove` already refuses on untracked files or tracked
modifications, but says nothing about unpushed commits. Pruning on every path is
what makes "leaves no stale metadata" true rather than hoped-for.

**Status.** Current

#### Q5.87 — Why does the unpushed-commits refusal not depend on the directory existing?

**Rule.** `countFromRepo` answers from `repoRoot`. `null` from these counts
means "could not tell" and must never be read as zero; only `--force` may skip
the question.

**Why.** The whole refusal block used to sit behind `status.exists`, and
`inspectWorkspace` returns early when the checkout is gone, so `commitsAhead`
and `unpushed` were both `null` and `--delete-branch` fell straight through to
`branch -D`. The commits are in the object database, not the checkout — a
directory somebody already `rm`ed is exactly when the branch is the *only* copy.

**Status.** Current

#### Q5.88 — Why are symlinks never content-diffed?

**Rule.** `lstat` first, always.

**Why.** `git diff --no-index` follows the link, so `ln -s ~/.ssh/id_rsa x`
would otherwise serve the target's bytes to anyone holding the bearer token.

**Status.** Current

#### Q5.89 — Why is `FileChange.symlink` only a hint, with `diffFile`'s own `lstat` as the guarantee?

**Rule.** The refusal to content-diff is decided in `diffFile` from the path
rather than from the listing. `daemoncheck` asserts both directions of the flag
*and* that the untracked link — the case the flag gets wrong — still diffs as
`kind: "symlink"` with no patch.

**Why.** The flag comes off the worktree mode of a porcelain-v2 `1`/`2`/`u`
record, and an **untracked** path is a `?` record carrying no mode at all — so a
symlink the agent just created is reported with `symlink: false`. Nothing
dangerous rests on it. A reader who found only the `true` case would reasonably
conclude the flag can be trusted.

**Status.** Current

#### Q5.90 — Why does the `--no-index` header rewrite replace with a function and never a string?

**Rule.** `() => rel` — a function replacement, which has no substitution
grammar.

**Why.** `String.replace(pattern, replacement)` expands `$&`, `` $` ``, `$'` and
`$$` in a string replacement, and the replacement here is a path the *agent*
chose.

**Measured.** A file named `a$&b.txt` rewrote to `--- a/atmp/wt/a$&b.txtb.txt` —
the absolute path the rewrite exists to remove, spliced back in, in the one
header that has to be right for `client diff … | git apply` to work. Asserted
against a real repository on a file actually named `a$&b.txt`: restoring the
string form fails one case and no other. The same fixture covers two things a
stub runner could never claim honestly — `--no-index` **exiting 1** being the
success path for a created file, and `--porcelain=v2` emitting `<new> <orig>`
where `diff --raw -z` emits `<src> <dst>`, so a shared "read two path tokens"
helper would invert every rename in exactly one of them.

**Status.** Current

#### Q5.91 — Why is the database directory chmodded rather than only the database file?

**Rule.** 0700 on the directory is the only form that holds.

**Why.** SQLite writes `-wal` and `-shm` beside the database on its own schedule
and they carry the same transcript bytes until a checkpoint folds them back —
with whatever the umask says. Chasing those files loses: they are recreated. And
`mkdirSync(mode)` applies its mode only to directories it actually created, so
an upgrade into an existing `~/.reemoat` keeps that directory's old bits.

**Status.** Current

#### Q5.94 — Why does the relay read the machine limit live rather than caching it like the signing keys?

**Rule.** No cache. `machineStanding` reads `user_machine_limits` and, only when
there is an ownership row and no override, `instance_settings` — on every proxied
request, beside the three reads `authorize` already makes.

**Why not `KEY_REFRESH_MS`.** That cache exists because a key-set miss is
reachable by an **unauthenticated** caller sending a random `kid`, so the read has
to be bounded without making rotation slow. Nothing below `verifySignature` can be
amplified that way: this read happens after the token has verified and after the
grant has been proved, alongside `machineById`, `activeUser` and `grantFor`, which
are already unconditional. The comparison is three statements becoming five, not
zero becoming one.

**Why a TTL would be wrong even if it were free.** In `external` mode the relay is
a separate **process** from the one that writes the row, so nothing can push an
invalidation — any window becomes the floor on "the admin raised my limit and it
still does not work", which is the support ticket this feature manufactures. This
repository has already paid once for a cache with no invalidation path: `app.ts`'s
SPA fallback held a copy of `index.html` taken at registration, `pnpm web:build`
rewrote `dist/` underneath it, and reloading on a session gave a blank page with
no error.

**The escape hatch, written down so nobody reaches for a timer.** If profiling
ever demands a cache, it is `PRAGMA data_version` — SQLite bumps it when *another
connection* commits, so the relay can invalidate on the API's write rather than on
a clock.

**Status.** Current

### Every number in one place

| | |
|---|---|
| Event log | **Unbounded per session — a conversation is never truncated.** 128 KiB per event stands (truncated at the store boundary, visibly: one oversized event shortened with `…[truncated N bytes]` left in it, not the removal of anything somebody wrote). `REEMOAT_LOG_EVENTS`/`REEMOAT_LOG_BYTES` still bound it for an operator who wants that, and `daemoncheck` drives eviction with `maxEventsPerSession: 8`, so the path stays exercised. What bounds the database is whole sessions instead — inactive ones idle 7 days, or past a cap of 200, pruned at startup, never under 50 rows and never a live or daemon-ended row (Q2.222): kept whole or not at all, never trimmed to a suffix |
| Sessions on disk | Inactive sessions idle 7 days, or past 200 of them, pruned at startup; never under 50 rows, never a live or daemon-ended one, every id reported (Q2.222). `GET /sessions` is unbounded by default and takes `?limit=`, which reorders blocked-first so a cut drops only rows nobody waits on — asserted at both ends of the rank: a pinned row beating other **terminal** rows on restored fixtures (`rowFor` hardcodes `status: "exited"`, so none of that fixture set is live), and a *blocked* row beating a pinned one where a session genuinely blocks, since a restored row can never hold a pending permission |
| Changes API | 2000 files, 512 KiB per diff, both reported as `truncated` rather than silently short |
| git calls | 5s structural, 10s list, 15s status/diff, **120s** `worktree add`. That line said "hooks, LFS smudge" at 30s while both were disabled on this path; they are live now, and a few hundred MB of LFS content would have 504'd the first session |
| WS outbound queue | 8000 events / 16 MiB, and **`ATTACH_REPLAY_MAX` 2000** under the *event* half only. The queue used to be sized above the log so a `since=0` attach could not overflow; with no log window there is nothing to be larger than, so the *attach* is bounded instead of the history. Past the cap the socket replays the newest 2000 and sends `lagged{reason:"backlog"}`, the one lagged reason that is not a loss: those events are on disk and `GET /sessions/:id/events` serves them. 2000 events can still be 250 MiB against a 16 MiB queue, so the byte ceiling collapses an attach too — and reports the same `backlog` (Q5.48) |
| `Session.EventQueue` | 2000, evicting only `agent_log`/`other`. Never plain drop-oldest: silently dropping `text` or `file_change` would produce a contiguous log that is missing content |
| Timeouts | start 45s, shutdown budget 20s, cancel-send 1s, session/close 2s, cancel grace 5s **on a dispose** and 1.5s on a turn somebody stopped (what follows the first is SIGKILL, and what follows the second is nothing), exit grace 3s, WS ping 20s, enrollment 15s |
| Tokens | 300s lifetime (control-plane default, floor 120s), 60s clock leeway either side. It used to be the revocation window; the relay's live grant check is now, so this bounds only a WebSocket already open |
| Enrollment codes | single-use, 1 hour. Burned early by **four** things, each recording *which* in `used_from` — minting the next code for that machine (`superseded`), revoking the machine (`revoked`), deleting the user who minted it (`user_deleted`) and **disabling** them (`user_disabled`, which `enable` does not undo); both people-shaped burns are Q1.42. One live code per machine is why "how many may somebody hold" is not a number |
| Relay streams | **1 MiB** h2 window per stream (`STREAM_WINDOW_BYTES` — raised from 256 KiB as the coupled half of `EVENTS_PAGE_BYTES`, Q6.104; three comments went on saying 256 and were corrected in Q5.101), 256 concurrent streams per tunnel, 64 per caller, 8 MiB connection window (`CONNECTION_WINDOW_BYTES`, its own constant — same number as the socket valve, different fact). The per-stream window **is** the flow control — granted on consumption, so a stalled client stops its sender there and nowhere else |
| Tunnel | 8 MiB socket-buffer valve (`MAX_TUNNEL_BUFFERED_BYTES`, should be unreachable; the windows exist to make it so), 20s ping / 2 misses, reconnect 1s→30s with **full** jitter — a relay restart reconnects a whole fleet at once, and ±20% would keep the herd synchronised. Backoff resets only after a tunnel has been up 60s (`TUNNEL_STABLE_AFTER_MS`) |
| Grants listing | 500 per page, 2000 max, with a `total` — the one admin list that grows as users × machines |
| Uploads | **100 MiB per file**, 10 per message, and a session keeps **1 GiB** *and* 100 of the files sent to it — two bounds because a byte cap cannot see a hundred thousand one-byte uploads and each of those is a directory. Past either, the oldest file already sent is dropped; files still waiting to be sent are never dropped and are all that can refuse (Q2.247). An agent's returned images roll on their own **200 / 256 MiB**. Plus **300 MiB per 5 minutes** per session (`UPLOAD_RATE_BYTES`), the one refusal here that expires on its own and the only one carrying `Retry-After`. 200 bytes of filename, 128 of mime, both clamped at ingest so `truncateEvent` never has to touch an attachment. Inline images 5 MiB raw *to* the agent (~6.8 MiB of base64 in one write to its stdin); **25 MiB *from* one** (`MAX_AGENT_IMAGE_BYTES` — its own constant since the per-file cap moved, sharing one having put a ~133 MiB string in the base64 pre-check on the emit path). Unconsumed uploads expire at 24h; a sent one stays until its session goes or its budget needs the room. Q5.101 |
| Downloads | 100 MiB, which **equals the upload cap by coincidence rather than by coupling** — this row said "deliberately not the upload number" and that was true at 25 MiB. Neither may be set by reading the other: that one bounds what a client may push onto disk against budgets outliving the request, this bounds a bearer-token-readable read of a whole workspace, where the cost of no bound is one of 256 tunnel streams held open for as long as somebody likes. The client refuses at the same number from `content-length`, before a `Blob` is resident on a phone |
| Permission payload | 8 KiB each for `rawInput` and `content`, clamped by `clampBlob`, and **8 KiB over `{title, options}` together** (`MAX_PERMISSION_SNAPSHOT_BYTES`) — a **refusal**, not a clip. Far below the per-event cap because all of it rides the snapshot, which `GET /sessions` returns for every session at once. **24 options**, `optionId` 256, both refusals. The two 200-character clips on `title` and an option `name` are gone: they cut a model-written answer on the one channel where kimi asks a question, breaking `askedQuestion`'s identity match against `rawInput` — Q2.214, Q7.82 |
| Session title | 120 characters accepted from a rename, 60 for the one derived from the first prompt. Bounded for the same reason as the row above: it rides the snapshot, which `GET /sessions` returns for sixty sessions every four seconds |
| Session nickname | 2–32 characters, one per machine; `NICKNAMES` holds 113, and past them a name takes the first free `-2`, `-3`. Q2.245 |
| Mentions in a message | 8 distinct names resolved into the daemon's note; the rest stay text. Q2.246 |
| Agent login | one run per agent (a second supersedes), 64 KiB of transcript, 10 minute TTL. Pasted credentials capped at 8 KiB, which is far above an OAuth token and far below an argv |
| Passwords | scrypt N=2^15 r=8 p=1 — ~51ms on the machine this was measured on (Node 26, 2026-08-07), against ~25ms at 2^14 and ~103ms at 2^16 — holding `128·N·r` = 32 MiB for the duration of each. `maxmem` is passed explicitly at **128 MiB**, because Node's default ceiling is 32 MiB and OpenSSL refuses *at* the boundary: measured, N=2^15 r=8 throws `memory limit exceeded` while N=2^14 succeeds, and a KDF that throws for some parameter sets looks like a wrong password on one deployment rather than a configuration error. 12–256 characters, NFKC and never trimmed; the maximum is not about KDF cost (scrypt passes the input through one PBKDF2 iteration, so bcrypt's folklore does not apply) but about not storing a string somebody else sized. **4 concurrent hashes, at most 2 of them public** (Q1.39); wait lists per lane, 32 authenticated and 16 public, then `503 overloaded` with `Retry-After: 1` |
| Sessions | 30 days absolute, 14 idle, `last_seen_at` written at most once per 15 minutes — the guard that makes idle expiry affordable at all, since the alternative is an fsync per request on a `synchronous = FULL` database in the process carrying every tunnel. 10 per user, the **oldest revoked** rather than the newest refused, evicted inside the mint's own transaction. Each records what it said about itself, clamped at ingest: 256 characters of `User-Agent`, 64 of address. A revoked row is kept **7 days** and swept at startup with its origin — short because no reader surfaces it (`listSessions` and the admin count both filter `revoked_at IS NULL`), non-zero because deleting on revoke would make the day something does read it unanswerable |
| Login throttle | **5 failures per 15 minutes per `<name, address>` pair** (Q1.37), then 30s doubling to a 15-minute ceiling, the *exponent* clamped at 30 so `Infinity` is unreachable. A second instance under `ADDRESS_THROTTLE` counts **30 per address** — looser because that key is shared by everybody who appears to be at one address, and 5 would make one person's bad afternoon an office lockout; a `429` reports the longer of the two blocks. A password change is `passwordChangeKey(userId)`, its own namespace. 10 000 keys per instance, and past it settled entries go first and then the map is cleared outright — which lets somebody buy one reset for ten thousand requests, stated rather than hidden, because an unbounded map keyed by a caller-chosen string is the worse failure. `MAX_KEY_CHARS` per composed key (325 today, derived from the builders' field caps so no built key is cut), 254 for a login identifier or a mail recipient, 120 for other name halves, 64 for an address. In memory: a restart clears it |
| Machines per user | **50 is the ceiling, not the limit.** It is the anti-abuse bound — creating one is reachable by anybody with a password, and each is a row plus an enrollment code plus a tunnel credential, against a `synchronous = FULL` file in the process carrying every tunnel. The *limit* is `machines.per_user`, a setting (env-seeded, database-owned) overridable per person in `user_machine_limits`, refused above the ceiling on both write paths and clamped again on read. **Unset resolves to 50**, which is the behaviour before the setting existed and deliberately not 0 — nothing seeds `instance_settings`, so a 0 default would take the whole fleet offline on deploy. Over the limit is **derived** from rank among `machine_owners` ordered by `(created_at, machine_id)`, never stored, so lowering switches off the newest and raising switches them back on with no recompute (Q1.51). Still counted with no revoked filter, which is why a revoke has to `releaseOwner` (Q1.43); `PUT …/owner` counts rows for *other* machines, so re-labelling one you already own is never your fifty-first — and it preserves `created_at` when the owner is unchanged, or an admin re-label would move a machine to the back of its own queue |
| Control-plane bodies | 64 KiB above THE LINE and 256 KiB below it. The two public routes are the only places in this service where somebody with **no credential** decides how many bytes it reads, and neither had ever bounded it; below the line there was no bound at all, on the reasoning that a caller past the gate has a credential — a statement about *who* is asking and not about *how much*, when every route calls `readJsonObject`, which buffers before it looks. Both answer `413 payload_too_large` in the envelope every client here parses, because `bodyLimit`'s default `onError` is `text/plain` and none of them can read it. `currentPassword`/`newPassword` are refused over 512 characters |
| Agent commands | 256 per session; 64 characters of name, 200 of description, 100 of hint — clamped at **ingest** in `session.ts`, like `MAX_PARENT_ID_CHARS`: the agent chooses the strings, the list rides no event so `truncateEvent` never sees it, and "bounded by what the agent sent" is not a bound. Measured 2026-08-03, claude publishes **100 commands / 18.7 KiB**, longest name 24, longest hint exactly 64, descriptions median 68 and max 1135. So 256 is for an MCP server publishing hundreds of prompts rather than for trimming a real list; the hint cap sits *above* the longest real one; the description cap is the only one that bites. **The name cap is a refusal and the other two are truncations** — `clip` appends `…[truncated N bytes]`, right for prose and wrong for a name, since a command is invoked by *sending* `/<name>`; dedup running on the unclipped name while the clipped one was stored made two long names collide with `dropped` reporting none. What is cut is *counted* into `dropped`, and the menu draws that count. Off the snapshot entirely; only `commandsRevision`, a number, rides the poll |
| Web client | 3 live sockets (LRU by most recently viewed), **16 MiB held per session and every event of it drawn** (`MAX_TRANSCRIPT_BYTES`, the **only** ceiling — the event count beside it is deleted, see Q3.114) — there is no render window under it, and the only cut is the newest `context_cleared`. History pages backwards at **5000** (`EVENTS_PAGE_LIMIT`) and **does not stop until it reaches the log's start, that cut, or those bytes** — there is no per-run budget and no control that offers to fetch more; `MAX_AUTO_HISTORY` (5000) is only where the loop yields the main thread. A page that fails is retried at 500ms and 2s, transport failures only, and `attachWanted` re-drives a run that gave up on the next poll a session list survives. What pays for it is `sameNode`. **60 sessions per machine per poll** — a pinned row that falls out of that window is invisible until the daemon's `listRank` keeps it, which is why pinned outranks live there. 4s list poll while visible, 15s re-probe for an unreachable machine, 1.5s reachability probe, token refreshed at `exp − 90s`, socket rotated at `exp − 60s`. 15s per request, except those that spawn a process — `POST /sessions`, `POST /sessions/:id/resume`, `POST /sessions/:id/config`, `GET /agents`, `/agent-auth/*` **and `POST /sessions/:id/prompt`** — each of which gets its own budget, its daemon chain plus `SLOW_ROUTE_MARGIN_MS` (30s) and never below `SLOW_ROUTE_FLOOR_MS` (90s): `POST /sessions` 215s, `/prompt` 150s, `GET /agents/capabilities` and the `/custom-agents` writes 290s, the rest 90s, each held above its chain by webcheck; the prompt is on that list unconditionally, because `request` is handed a method and a path and a deadline that depended on session state would be state leaking into the transport. A login transcript is polled every 700ms while its wizard is open, and one `GET /sessions/:id/commands` per session per revision change — for the open session only |
| Elicitation form | 24 fields, 24 options per field, **32 KiB** on the projected total, and an option value of 512 — all four **refusals**, because `clampBlob`'s `{truncated: true, bytes}` is fine above an Approve button and useless above a form. **Prose is carried whole** — the three character caps on `message`, a field title and a description were removed in Q2.214, because with several questions on one form the *question itself* is the field's description and a 300-character cap was a cap on it. Structure is refused; the byte total is the only bound left, and it is asserted against one enormous string as well as a thousand small ones. 32 KiB rather than a permission's 8 because the form does **not** ride the snapshot. An answer over 2048 characters is refused on the route and never cut, while the *log's* rendering of it is clipped, visibly. Measured 2026-08-06 against live claude: a two-question `AskUserQuestion` is 4 fields, 4 options each, longest value 19 characters, ~2.5 KiB, and the tool's own schema caps it at 4 questions — so every one of these bounds the pathological case rather than a real form |
| Auto-resume | 3 attempts per session per **daemon life** — in memory, so a restart tries again, deliberately: a restart is new information and refusing to retry would make the deploy that fixes the bug fix nothing. 2 agents starting at once, because each is a node subprocess with a `claude` grandchild. Backoff 2s→60s with **full** jitter, since the attempts start together and a narrow band keeps them synchronised. The failure on the snapshot is capped at 64 characters of code and 512 of message — an order tighter than a pending permission's 8 KiB, because unlike a permission nothing here has to be *acted on* from the list, only recognised |
| Shutdown | 20s for the graceful stops, then a **bounded** 3s parallel SIGKILL sweep, inside `daemon.ts`'s 25s hard exit. The sweep is a syscall per session rather than an exec, so the bound costs nothing — and it stays, because the reason a teardown is bounded does not depend on what it costs |
| Accounts on one computer | **10 per installation** (`MAX_ACCOUNTS`) — past it *Add account* is not drawn and the host refuses `account_limit`. A bound on this computer rather than on a control plane: every account is a webview, a keyring scope and, once set up, a daemon of about 136 MB from launch to quit, and ten is what a laptop is asked to keep alive (Q7.149) |

#### Q5.100 — Why do the containment predicates have a *resolved* form as well?

**Rule.** `paths.ts` exports `containedInResolved` / `atOrUnderResolved` beside
`containedIn` / `atOrUnder`: the same segment-wise comparison, with the resolving
already done. An async caller holding two `probeRealpath` answers uses those, and
does not write a prefix test of its own.

**Why.** The synchronous primitives resolve internally, so handing them a path
somebody else named puts a synchronous `realpath` back on a path this daemon did
not create — the one thing `stall.ts` exists to stop (Q5.29), and the reason
`probeRealpath` is the bounded form of `paths.ts`'s own `resolved()` in the first
place. The alternative is a call site comparing two already-resolved strings by
hand, which is a second containment implementation: there is exactly one
containment primitive file precisely because a third copy disagreed with both
others once and fail-closed (Q5.32).

**Status.** Current
#### Q5.101 — What had to move before an attachment could be 100 MiB?

**Rule.** `MAX_UPLOAD_BYTES` is 100 MiB, `MAX_SESSION_UPLOAD_BYTES` is 1 GiB, and
a session may spend `UPLOAD_RATE_BYTES` (300 MiB) per `UPLOAD_RATE_WINDOW_MS`
(5 minutes) before a `429 upload_rate_limited` with `Retry-After`.

**Why.** 25 MiB was the right line for a screenshot and the wrong one the moment
somebody wanted to hand an agent a recording, a heap dump or a database export —
all attachments to a conversation in every sense except the size the old comment
assumed ("below anything that is a transfer rather than an attachment").

**The transport was never the constraint, which is the finding.** Nothing in
`src/`, the relay or the control plane configures a body limit; the running
counter in `Uploads.receive` is the only bound on any request body anywhere in
this system, and the relay's numbers are h2 flow control granted on consumption
rather than caps. So the raise itself is two constants.

**Three things were coupled to it and each would have failed *silently*.**

*The agent's own images.* `keepAgentImage` sized its base64 pre-check as
`ceil(limit * 4 / 3)` against this constant, so 100 MiB would have admitted a
~133 MiB **string** into one `Buffer.from` — on the emit path, which must not
await and must not allocate like that. `MAX_AGENT_IMAGE_BYTES` is that half,
unhooked at **the same 25 MiB**, so the decoupling changes no behaviour. They were
always different questions: one is how large a file somebody chooses from a
picker, the other is how large a blob a model hands back already in memory.

*The client's own deadline.* `uploadDeadlines` capped `hardMs` at 300 s
"deliberately: that is the token lifetime" — and conceded in its own next sentence
that a request in flight does not die at `exp`. So the coupling was tidiness
rather than a property, and at the new size it aborted a **progressing** 100 MiB
upload at five minutes, i.e. anything under ~350 KiB/s, with no message, halfway
through, on exactly the slow links a large cap matters on. The ceiling is 45
minutes now, which is above `scaled` at the largest file this daemon takes
(~35 min at the assumed 50 KiB/s floor) — so the formula governs at every real
size and the cap bounds arithmetic rather than transfers. What notices a dead link
is still `stallMs`, thirty seconds, reset by every progress event.

*The session budget.* 100 MiB per session with 100 MiB per file is a second bound
one file exhausts, which has stopped being one. 1 GiB, ten files at the cap;
`MAX_UPLOADS_PER_SESSION` is untouched, the inode ceiling never having been under
pressure.

**The rate window is soft, and the word is doing work.** Nothing here is a
security boundary: anybody reaching this route holds a grant on this machine, and
an agent on it runs as you with no sandbox — somebody who wants to fill this disk
has a far shorter path than an upload form. What it bounds is **cost**, which went
up 4× per file in the same change, against ceilings that never refill for the life
of a session. Shaped on the control plane's `WRITE_THROTTLE` rather than on its
guessing policies, and for the reason that one gives: a limit against cost blocks
briefly and **does not escalate**, because the caller is not an attacker to be
discouraged, it is somebody whose next action should be a moment later.

Charged on bytes **actually written**, refused or not — an upload that streamed
90 MiB before hitting the per-file cap cost that, and exempting refusals would
make the cheapest way to spend this daemon's disk bandwidth a stream that is
always one byte too long. Checked *before* the body is read, beside the count
check, because a refusal that has already streamed 100 MiB has spent exactly what
it was refusing to spend. It cannot see the current upload's size — a chunked body
declares nothing — so one upload may finish past the limit and the next is the one
refused, which is the right way round for a cost bound.

**Two numbers stopped meaning what their comments said.** `MAX_DOWNLOAD_BYTES` is
also 100 MiB and its docblock said "deliberately a different number"; it now
coincides **by accident**, and neither may be set by reading the other — the
*reasons* were what differed and are unchanged. And `MAX_IMPORT_BYTES` (50 MiB) is
now the smaller of the two, reversing their old order; its rule file justified it
by quoting `MAX_UPLOAD_BYTES`'s own comment, and the real reason had to be written
out: an archive is **expanded onto disk** as up to `MAX_IMPORT_ENTRIES` files, each
a containment decision and an inode, while one streamed file is one `open` and one
counter.

**The ceiling nobody in this repository can see.** `deploy/` ships no reverse proxy
and `install.sh` recommends one twice. nginx defaults `client_max_body_size` to
**1 MB** and refuses with a 413 *before* the daemon receives the request, so the
chip shows a failure the daemon has no record of; Cloudflare's 100 MB is not
configurable at all. `deploy/README.md` names the values now, which it never did
even at 25 MiB.

**Three stale comments went with it**, each claiming the relay's per-stream window
is 256 KiB. It has been 1 MiB since Q6.104, and being wrong about it in a paragraph
that reads as a measurement is worse than not stating it — they name
`STREAM_WINDOW_BYTES` now.

**Measured** by the drivers rather than by a run: `daemoncheck` drives the running
counter against the real constant, streaming a shared 8 MiB buffer rather than
allocating the whole cap on the heap, and drives `uploadRateVerdict` — pure, so
the window is asserted at the real numbers without writing 300 MiB to a temp
directory, which is the only alternative and enough of a cost that it would have
gone unasserted instead.

**Status.** Current, amended by Q2.247: both upload budgets roll, and an agent's images have their own.


#### Q5.102 — Two callers unpack somebody else's archive. Why is there one unpacker?

**Rule.** `unpackArchive` is the middle of `importArchive`, extracted rather than
copied. `POST /fs/import` and `POST /plugins` both go through it, with their own
`ArchiveLimits`.

**Why.** Everything in that function is a containment rule: `..` refused rather
than normalised — normalising is how every surviving zip-slip works — `.git`
refused case-folded, backslashes never translated to slashes, absolute paths and
`C:` refused, and the size ceiling charged against what the **decompressor
produced** rather than against what a member declares. A second implementation of
that list is how one of the rules comes to be missing from one of them, which is
the argument `paths.ts` already wrote out for `containedIn` and the reason there
is exactly one containment primitive file.

**What is parameterised and what is not.** The *numbers* differ and are passed in:
`IMPORT_LIMITS` is somebody's whole source tree, `PLUGIN_LIMITS` is a manifest and
a file of JavaScript, and giving the second the first's headroom would mean the
bound that stops a zip bomb is 500 MiB for a thing never past a few hundred KiB.
Nothing in `safeMemberPath` is parameterised, because what a member path may *be*
does not depend on who is unpacking — a caller able to relax it would be a caller
able to accept `..`.

**What each caller keeps.** Where the result is published, what it is called, and
whether something is already there. Those genuinely differ, and nothing is shared
by pretending otherwise.

**Status.** Current

#### Q5.103 — An update that will not start must change nothing

**Rule.** If the newly installed version fails to start, the new directory is
removed, the row is left untouched, the previous version is started again, and the
refusal carries what the child actually said.

**Why.** The person installing is often not sitting in front of the machine — that
is the entire premise of this product — so the failure mode being designed against
is *a broken update leaves you with nothing*, discovered from a phone. Leaving the
plugin that was there is the only acceptable outcome, and it is only achievable
because the old version's directory is not removed until the new one is known to
run.

**Two defects this shape had while it was being built, both found by driving it.**
The failed start called `child.stop()` rather than `this.stop()` — and `stop()` is
what sets `stopping`, which is the only thing telling `onExit` a kill we asked for
from a crash. Without it the rollback **scheduled a restart for the plugin it was
in the middle of discarding**, which would have brought a broken update back to
life minutes after it was refused. And the surviving plugin's restart budget was
being spent by the rollback, so three refused updates left a working plugin that
would no longer start; it is returned before the restart now.

**What the refusal carries.** The child's last twenty lines of output, stdout as
well as stderr. "did not start within 10000ms" says nothing anybody can act on;
the `SyntaxError` their `server.js` threw says everything.

**Status.** Current

#### Q5.104 — What survives an update, and what is keyed on what

**Rule.** `plugin_data` is keyed on the plugin's **id** and never on its version.
An update replaces the row in `plugins` and touches nothing in `plugin_data`; an
uninstall drops both.

**Why.** This is the whole of what makes an update an update rather than a
reinstall. A board keeps its cards across `0.1.0` → `0.2.0` because no part of the
key mentions a version, and the demo plugin exists partly to make that
demonstrable in two commands.

**Why two tables rather than a JSON column on the row.** For the bound rather than
the shape: the per-plugin byte and key ceilings are enforced by counting rows, and
a blob makes "how many keys does this plugin hold" a parse. `checkPluginWrite`
lives beside the interface rather than inside the SQLite implementation, so the
memory implementation a driver uses refuses exactly what the real one refuses — a
quota that holds only where there is a file is a quota nothing drives.

**One arithmetic detail that is load-bearing.** The replaced value's length is
credited back before the new one is charged. Without it a plugin rewriting a
single key climbs to its own ceiling and stays there, which is the shape of every
settings pane written against this API.

**Status.** Current

#### Q5.105 — A root, compared against a path that does not exist yet

**Rule.** A component holding a root it will build paths under must resolve that
root **once**, at open, and keep the resolved form.

**Why.** `containedIn` resolves both sides and falls back to comparing as written
when `realpath` throws — which it does for every path about to be *created*. So a
caller keeping an unresolved root and joining onto it is comparing a resolved root
against an unresolved child, and the guard correctly answers no.

**Measured.** On macOS, where `/var` is a symlink to `/private/var`: the plugin
host refused to remove its own directory on **every** reinstall of a version it
already had — `refused to remove …/plugins/board/0.1.0, which is not under the
plugin root` — and the `rename` that followed then failed `ENOTEMPTY`. The symptom
was a warning nobody would have read and an install that worked the first time.

**Where this was already known.** `createWorkspace` solves the identical problem
for worktrees: it resolves the deepest component that exists and rebuilds the
not-yet-created leaves onto that answer, *or every `POST /sessions` throws
`outside_worktree_root` wherever the worktree root traverses a symlink*. That
sentence was in `files-paths-git.md` before this bug was written; the general form
is now stated at the primitive itself, and `worktree.ts`'s private twin of the
resolver is marked as the copy to delete next.

**Status.** Current

#### Q5.106 — A hook must never reach the emit path

**Rule.** Hook delivery is queued and drained on its own. Nothing on that path
awaits inside `SessionLog.append`, and the queue is bounded drop-oldest with the
drops reported.

**Why.** `append` is synchronous by contract and runs inside the agent's own RPC
handler — that is what makes gap-free attach true by construction. A hook that
blocked there would put a plugin between an agent and its transcript, and a plugin
that hangs would stop the session's events rather than its own screens.

**Why drop-oldest rather than drop-newest or unbounded.** Unbounded means a plugin
that stopped answering grows a queue for the life of the daemon. Between the two
directions, the newest events are the ones still worth acting on: a board catching
up cares about the turn that just ended, not the one from an hour ago.

**Why the drops are reported.** A plugin quietly missing half its events looks
exactly like a plugin with a bug in it, and the person who would investigate has
no way to tell the difference. It goes to `onWarning`.

**What crosses, and what deliberately does not.** A derived summary, never a
`StoredEvent`. The session event union is a wire three coding agents move, so
coupling a plugin to it would make every ACP change somebody else's breaking
change.

**Status.** Current

#### Q5.107 — A throwing observer is reported and kept

**Rule.** `SessionRegistry.watchSessions` guards each observer, reports a throw
through `onWarning`, and **does not evict it**.

**Why this is the opposite of the neighbouring rule, deliberately.**
`SessionLog.append` evicts a listener that throws, and is right to: there a
listener is one WebSocket, and evicting it costs that one socket its events while
every other listener carries on.

An observer here is a whole *subsystem*. Dropping the plugin host on one bad frame
would stop every hook on the machine for the life of the daemon, with nothing
anywhere saying so — the same shape of silent, permanent loss that the fan-out
guard's own comment warns about for sockets, one level larger.

**Asserted rather than assumed.** `daemoncheck` registers a throwing observer
**first**, so "the ones after it" is a real position rather than a hope about
iteration order, and checks that a second observer still sees every session, that
the thrower is called for each of them, and that each throw is reported.

**Status.** Current

#### Q5.108 — The bounds table says how many calls a plugin may be answering. What bounds the calls it makes?

**Question.** `MAX_INFLIGHT_INVOCATIONS` bounds host → child and is published in
both bounds tables. Nothing bounded child → host. Is that an omission or a
decision?

**Rule.** An omission. `MAX_INFLIGHT_HOST_CALLS` bounds it, and a call past the
bound is refused to the child rather than queued.

**Why.** The two directions are not symmetric in cost. Several host methods fork
git, so the fan-out is not "a plugin is chatty", it is one child process starting
one git per session at once, against a registry that holds up to sixty of them, on
the machine its owner is working on. No hostile plugin is needed to reach it:
asking about every session inside a single hook is the obvious line an author of a
task board writes, and the reference plugin in this repository is a task board.

**Why refused rather than queued.** The child asked for these now, and holding
them only moves the cost onto the invoke deadline the caller is already waiting
on — the same argument the inbound bound already makes one field over.

**Why the ceiling is higher than the inbound one.** This is a plugin doing its own
work, not tabs queueing on a slow child. A plugin that legitimately reads a
handful of sessions per hook should never meet the bound; what it stops is the
unbounded fan-out, not concurrency.

**Where the slot is released.** On both arms, and before the generation check. The
count is about this process's load rather than about who deserves an answer: a
superseded child's call still ran, and leaving its slot spent would bleed the
successor's budget one call per replaced generation.

**Status.** Current

#### Q5.109 — Which status does a message that never left the daemon get?

**Question.** An invocation whose payload does not fit one IPC frame is refused
before it is written to the child. `pluginErrorStatus` splits by whose problem it
is: a plugin that is off or broken is a `503`, and everything else is a `502`
because "something downstream of this daemon answered badly". Which half is this?

**Decision.** Neither, and it now has its own arm: `413`. Nothing downstream
answered, because nothing reached the child; the remedy is on the caller's side,
which is what `413` says. It is also already this daemon's word for the same fact
at `payload_too_large` and at both import ceilings, and it was already in the
shared error-status union.

**Why it mattered.** With no arm it took the `502` default, whose stated reason is
the one thing that is definitely not true here, while `docs/API.md` documented a
`503` — a third answer agreeing with neither. All three were reachable by a plugin
author reading a different source, which is the failure mode this function's own
docblock is about: the statuses exist so as not to mislead, since the code is what
a client should branch on.

**Status.** Current

#### Q5.110 — A view is bounded twice. Which bound actually fires?

**Question.** `PLUGIN_VIEW_LIMITS` says how large a view may be — blocks, rows,
columns, fields, text — and `MAX_PLUGIN_MESSAGE_BYTES` says how large a message
may be. The author's guide prints them two lines apart as though both applied.
Do they?

**Rule.** They do now. `clampView` ran in the **host**, which is one hop after the
child had already refused to send an oversized message — so the published view
bound could never fire, and the byte bound was the only real one. `fitView` runs
in the child, before the message is built: the counts apply first, and a byte cut
finishes the job when the counts alone are not enough.

**Why it was not a tidiness problem.** A view inside every documented limit came
back as "this plugin returned more than can be sent", and the clamp whose whole
purpose is to cut it never saw it. The bound a plugin author can read was
unenforceable, and the one that fired is the one the guide does not emphasise.

**Measured.** 2026-08-23, against a real forked child, the reference plugin and a
real store. Its board fits at 903 cards and does not at 904, while the store lets
a plugin keep 1000 keys and the session prune never touches them — so cards
outlive the sessions they name. A plugin doing exactly what the guide walks
through therefore reaches a screen that cannot be drawn, permanently, with nothing
in the interface able to shrink it: the only control that deletes a card belongs
to a session that by then no longer exists. Afterwards the same board is cut to
200 rows a column and fits at any number of cards.

**Why rows are the lever.** Every other dimension is bounded by a count small
enough to be irrelevant against 256 KiB — 24 blocks, 8 columns, 40 fields, 4000
characters. The number of rows a plugin holds is whatever its data grew to, so
that is the only thing worth cutting. The cap is halved until the message fits,
which is at most eight measurements and terminates at zero rows.

**Rejected.** Lowering `PLUGIN_VIEW_LIMITS` until the worst legal view fits. The
worst legal view is 24 blocks of 8 columns of 200 rows, which measures 4.9 MB —
making the counts guarantee the bytes would mean cutting them by a factor that
punishes every honest view for a shape nobody sends.

**Rejected.** Leaving the refusal and fixing the reference plugin instead. The
refusal is graceful and stays as the last resort, but the defect is in the daemon:
a bound published to plugin authors was enforced where it could not act. Fixing
the one plugin in this repository would have left the same wall in front of every
plugin that is not in it.

**Where the notice goes.** `noteClamp` moved to `protocol.ts` beside the clamp,
because a cut announced on one side of the channel and not the other is a cut
nobody is told about. The host still clamps and still notes; on an answer the
child has already fitted, both are no-ops.

**Status.** Current

#### Q5.111 — Nothing in the browser opens the archive on the market path. What is consent, then?

**Position.** Three things, and the third is new. The browser reads `plugin.json`
from `raw.githubusercontent.com` **at the pinned commit** and draws the disclosure
from that; the daemon compares its own `parseManifest` against what it was told and
refuses with `409 plugin_consent_broken` **before the plugin is started**; and the
client checks `consentBroken` against the row that came back, per machine.

**Why the middle one had to exist.** On the upload path the browser opened the very
bytes that were sent, so `consentBroken` after the fact is a check on a reader that
might be wrong about an archive it *read*. Here nothing local ever opens the
archive. The manifest at a commit and the tarball of that commit are the same
object by construction — but "by construction" is not a check, and this is the
screen where being wrong means somebody grants a capability they never saw. So the
machine refuses rather than reports, and it refuses early enough that no code ran.

**What is compared, and this is the part that decides whether it works.** Exactly
three fields — `scopes`, `net` and `contributes.hooks`. Not the manifest.
`parseManifest` **normalises**: it trims `name` and every action title, turns an
absent `description` into `null`, and synthesises an absent `contributes` into
`{screen: null, settings: false, actions: [], hooks: []}`. A plugin that simply did
not write a `contributes` block therefore does not match its own raw `plugin.json`
field for field, and a check that fired on that would fire on most plugins. An
alarm that cries wolf is an alarm people learn to click through, which would cost
more than having no alarm. The three that survive normalisation as plain string
arrays are also the three that decide what a plugin can *do* on the machine; a name
or a screen title differing is a cosmetic surprise.

**One direction only.** A plugin asking for *less* than it was shown is a person
who agreed to more than they had to, not a breach — so only what was gained is
reported. `consentBroken` in the client already had that rule and this is it on the
daemon.

**What a caller that sends no consent gets.** The archive is still validated and
the scopes still land on the row. `pnpm client plugin install` has no screen to
have shown anybody, and a route that refused it would break every script.

**Status.** Decided

#### Q5.112 — The daemon's own refusals were held to no vocabulary rule at all

**Rule.** Every sentence `hostable` can return in `src/acp/systems.ts` is pinned by
exact text; the whole matrix is swept into a partition of four templates by
`templateOf`; and each is run through `jargonIn` — a full stop, no wire vocabulary,
and, the half that is a relation rather than a word list, **a refusal about one system
may name that system and no other**, harnesses included.

**What was missing, which is the entry.** Q3.474 made the vocabulary a rule after
*"Codex accepts openai systems, and Moonshot is anthropic"* reached somebody's phone
under a greyed-out row, and `webcheck` grew a `noJargon` closure over the client's
mirror. The daemon's own strings got the rule written into their comments and nothing
else: `daemoncheck` asserted the routing *behaviour* and never the sentences. So that
exact string could have been put back into `hostable` and shipped, and all eight
offline drivers would have stayed green while it was drawn on a phone. **A gap in a
driver is worth an entry here for the same reason a gap in the code is** — a rule
enforced nowhere is a rule that is already half-broken, which is Q3.492's finding
stated about a checker instead of about a stylesheet.

**Why the predicate is duplicated rather than shared, which is the decision.** The two
drivers are separate processes over separate packages and neither can import the
other, so sharing means a third module written for two callers — and the honest reason
not to build one is that the *rules differ*. `webcheck`'s forbids the words
`anthropic` and `openai` outright, which this side cannot: they are the `displayName`
of two systems here, and *"Anthropic can only be reached by the CLI it ships with."*
is a correct sentence naming a company somebody has heard of. And this side has a rule
the client's cannot state — a refusal may not name a **harness**, because the daemon
has no display name for one and its id is a wire word, which is why `hostable`'s own
comment says the harness's name "is a name this side does not have" while the client's
mirror puts "Codex" or "Kimi Code" in front of the same sentence. A shared predicate
would have to be widened until it permitted both, which is weaker than either. This
repository's view that a copy is a second chance to be wrong is about tables that must
agree — `hostable`'s matrix is the one right here — and two predicates that are
*supposed* to differ are not that.

**Why the shared half is stated as a relation.** "Names a system other than the one it
is about" is case-insensitive, catches the recorded failure by construction (that
sentence named Moonshot **and** anthropic **and** openai), and does not have to guess
which spelling of a protocol name somebody reaches for next.

**And the predicate is driven against the string that really shipped**, because every
arm of the sweep is green today and a predicate that tested nothing would read exactly
the same.

**Status.** Current

#### Q5.113 — Four of five write routes in the systems section had no scope gate asserted

**Rule.** Every route the assembled-agents section serves is one row of
`sectionRoutes` — `(method, path shape, scope)` — read by **two** sweeps: the scope
gate, and the no-store 503. A route in one and not the other is the gap this closes,
and the table is what stops the next route arriving with no gate at all.

**What was missing, and how it was proved.** The scope gate was asserted at exactly
one route, `PATCH /custom-agents/:id`, in the middle of the editing block. `PUT
/systems/:system`, `DELETE /systems/:system`, `POST /custom-agents` and `DELETE
/custom-agents/:id` had none — each could be downgraded from `write` to `read` in
`src/server.ts`, singly or all four at once, with `daemoncheck` green. Not argued:
mutated and watched. The costliest of them is `PUT /systems/:system`, because that is
the route somebody pastes a vendor API key into — a read-only grant able to reach it
can replace the key every routed session on the machine signs its requests with, and
the `DELETE` beside it can take the key away. **A gap in a driver earns an entry here
for the same reason a gap in the code does**, which is Q5.112's finding about a
different section of the same file.

**What the sweep asserts, and all three halves are load-bearing.** It creates a preset
that really exists, then drives all seven routes with `tokenWith("u_reader",
["session:read"])` carrying bodies that would really land — a token on the `PUT`, the
four accepted fields on both preset writes — and asserts that the five write verbs
answer `403 insufficient_scope`, that both listings still answer `200`, and that
neither the preset store nor the key store moved. The positive half is not decoration:
a `write` that drifted onto either listing would take the assembly screen away from
every read-only grant on the machine while all five refusals went on passing. The
"nothing moved" half is what makes the first a claim about a write that was *refused*
rather than one that was malformed.

**What is still unswept, stated here because it is larger than what was fixed.**
`src/server.ts` serves 52 routes. `GET /health` is deliberately ungated —
unauthenticated liveness — and of the remaining 51, **15** have a scope assertion
anywhere in this repository, seven of them added by this work. No other driver covers
any of them: `webcheck`'s 403 pins are about how the *client* draws one. The sharpest
of the 36 left: `DELETE /sessions/:id/workspace`, the only `machine:admin` route
outside the plugin family, where a silent downgrade to `write` would let any grant
that can drive a session destroy somebody's worktree and the uncommitted work in it;
`PUT /agent-auth/:agent`, which is the same paste as `PUT /systems/:system` for a
different credential, and the seven `/agent-auth` routes beside it, one of which
spawns a pty as you and another types into it; `POST
/sessions/:id/permissions/:permissionId`, which is how an approval is granted, so a
read-only grant reaching it approves a command on somebody else's behalf; and `GET
/sessions/:id/stream`, which is a *second* code path for the same question because it
takes its token from the query string rather than the header, and where a read gate
failing open leaks a whole transcript. The shape that closes all 36 at once is this
one widened — one table of `(method, path, scope)` for the whole app, driven with a
reader, a writer and an admin, asserting a 403 for every token below a route's scope
and a non-403 for every token at or above it. That would also catch a route added with
no gate at all, which nothing catches today.

**Status.** Current for this section; the whole-app sweep is **not built**.

#### Q5.114 — Several assertions in `webcheck` did not assert

**Rule.** An assertion is evidence only once it has been **watched to fail**. Every
repair below was proved by mutating the product until the check went red and restoring
the file byte-identically afterwards, and the reason to state it as a rule rather than
as four repairs is that all four classes are available to every driver in this
repository.

Four ways a green check meant nothing, all in one file, all green against broken code:

- **An `indexOf` ordering comparison with no found-guard.** `refWrite < stateWrite`
  over `NewSession.tsx`, pinning that the ref is written before the state. Deleting
  `picksRef.current = updated;` outright — the edit that costs the most — makes the
  left side `-1`, which is less than every real position: the check printed `ok`,
  `typecheck` was clean, and the ref held its initial empty map for the component's
  whole life. Both operands are `>= 0` now. A missing needle must land on the *right*
  of the `<` or be guarded, and a sweep of all 23 such comparisons in the file found
  two more of the wrong shape — the `aria-modal` ordering in `Sheet.tsx`, which
  nothing else asserted the existence of, and `mayAddMachine(` before `<AddMachine`,
  which printed `ok (-1 < 1477)` the moment the identifier was renamed away.
- **`\b` written inside a double-quoted string.** In a JS string literal `\b` is the
  backspace escape, U+0008, not a word boundary — so `new RegExp("\bpicks\b")` asks
  for a control character no source slice can hold and matches nothing, ever. Two of
  the five forbidden identifiers in the closure-capture sweep were dead, and they were
  the two that mattered: the bare `picks` and `picked` a stale closure would capture.
  They are regex **literals** now, one escape layer closer to what they mean, with
  `.map(String)` so a failure names the offending pattern; a sweep of all 11
  `new RegExp` sites in the file found no other dead one.
- **A predicate with no negative control.** `noJargon` was only ever called where it
  answers `true`; replacing both of its character classes with `(?!)` — patterns that
  match nothing — left the whole section green. Three controls now, the discipline
  `daemoncheck` already keeps: the sentence `agents.ts`'s own docblock records as
  having shipped, one exercising only the second arm, and `null`. Of the file's four
  other local predicates, three were already driven both ways; this was the one that
  was not.
- **A comment block promising an assertion nobody wrote.** Nineteen lines of argument
  for a property, and beneath it the next comment block. The property is pinned two
  ways now — a behavioural pair over `sheetUpLabel` and `upFrom` for six pop-up
  routes, plus one narrow text pin on the ternary in `App.tsx`, because a composition
  inside a component body is unreachable from a driver with no DOM and neither pin
  catches the other's mutation. A script found 19 places where one comment block is
  immediately followed by another; the other 18 are stacked argument for the code
  below them.

And a fifth of the same family, arriving from a rename rather than from an operator:
two settings-route fixtures written `as never` still carried `agent: "claude"` after
that field became `system`, so `depthOf` read `undefined !== null`, answered the right
depth for the wrong reason, and would have gone on doing so through any further rename.
The cast is there because the literals are partial on purpose, and it suppresses
exactly the compiler error that would have said so. The repair is a parser-driven twin:
the four depths read off `parseSettingsRoute`'s own output rather than off a hand
literal, which is the only reading a cast cannot fake.

**And one proposed assertion was removed rather than repaired**, which is the other
half of the discipline. A junk route asserting depth 3 went red against *correct*
product code — `depthOf` reads `route.system !== null`, and `undefined !== null` is
true — but `parseSettingsRoute` writes that key unconditionally, so the state is
unreachable outside a hand-built literal in the driver itself. Keeping it would have
demanded defensive product code against a state the type forbids. A driver may not buy
its own coverage with a change to the product that nobody needs.

**Status.** Current


#### Q5.115 — One caps heading, fifteen copies, three constants that already owned it

**Rule.** The letter-spaced small-caps heading is `SETTINGS_HEADING`,
`MENU_HEADING` or `FIELD_LABEL`, and **which one is a colour decision, never a size
decision**. A call site composes layout onto it and never restates the type.

**Measured**, 2026-09-08: `uppercase` + `tracking-wider` + `font-semibold` appears
**15 times in 13 files**, in two sizes and four colours, while all three constants
that own it already existed and **nine** of those sites used none of them. Two files
— `gate/Gate.tsx` and `ForcedPasswordChange.tsx` — carried byte-identical local
`const label` declarations, and `SignIn.tsx` is the third member of that family and
did not even name it.

**Why it mattered.** `SETTINGS_HEADING`'s own docblock records that the string was
written out **fourteen times across five files** before the constant was extracted.
The count did not fall afterwards — it moved. That is the useful half: extracting a
constant does not retire an idiom, and nothing here had ever swept for the idiom, so
the second wave was invisible until somebody counted.

`FIELD_LABEL` is the one people re-typed rather than imported, and its 13px step is
deliberate and argued in three separate docblocks: a section heading is scanned, a
field's name is read off a form somebody is filling in from a phone.

**Three sites stay outside the constants and each now says why**, so the next sweep
does not "fix" them: `SessionBrowser`'s waiting-elsewhere band (`text-fg` — louder
than the rows under it, on purpose), `MachineSection`'s `RETIRE_HEADING`
(`text-danger`), and `MachineOffer`'s `or` (no `font-semibold`, because it is the
word between two doors rather than a heading) [⚠ deleted with the offer — Q1.650;
`webcheck.typography.ts`'s census is the current list]. ⚠ `RETIRE_HEADING` is spelled out
rather than composed for a real reason: `` `${SETTINGS_HEADING} text-danger` `` is a
**silent no-op**, two colours of one family resolved by Tailwind's alphabetical
emission rather than by the line — the same trap Q3 records for `items-center`
appended to `MENU_ROW`.

**Rejected: renaming `SETTINGS_HEADING`.** It now heads a gate field, a sign-in
field, a plugin's column and a key table, so the name is narrower than the reach.
The rename would break this file's own citation of the symbol, which `docscheck`
asserts, and buy nothing the widened docblock does not. `MENU_HEADING` had no
docblock at all and has one now.

**Status.** Current, amended by Q3.685: the idiom has two constants, and `FIELD_LABEL`
is sentence case outside it.


#### Q5.116 — The page gives up its credential before the host's origin moves

**The defect, which the screen's second entrance created rather than revealed.**
`host_set_server` moves the base **in the host process**, so from the instant it
returns every `host_cp` call goes to the *new* origin — while the page still holds
the old fleet's bearer in memory, and `location.assign("/")` has not happened yet.
In that window the four-second poll, `refreshConfig`, or any `cpFetch` already in
flight would hand **server A's session token to a host somebody has just typed
in**. While `ChooseServer` was only ever drawn at `server === null` there was no
credential and no window; as a settings screen there is both.

**The rule.** `cp.clearSession()` runs **before** `setNativeServer`, never after.
It is local, instant, cannot fail, and erases `credential#<old origin>` through
the same call `host_set_server` was about to make one line later. [⚠ amended by
Q7.148: it is `detachSession` now, the in-memory half, and neither side erases the
old origin's entry — a switch keeps that server signed in. The order is unchanged
and is still the rule; a refused switch re-adopts the copy it let go of.] [⚠ extended by
Q5.120: a signed-in account's server never moves now — `host_set_server` refuses
anything but a pending seat — so no path the app draws opens this window. The order
stays as the belt, and wherever a webview is rebound to another account the host
refuses the old document's commands instead.]

**Priced, because the safe-looking order is the wrong one.** Clearing first costs
one sign-in in the case where `setNativeServer` then fails on a full disk:
somebody is signed out of a server they are still pointed at. Clearing second
costs a credential disclosure to a host nobody has verified. The second is not a
trade.

**Asserted as source text, comparing two indices**, because it is invisible
otherwise — every other assertion about this screen stays green either way, the
request succeeds, and the only trace is a token in a stranger's log.

⚠ **And the fix has a second ordering inside it, which the first draft got
wrong.** Saving the address you are *already* on must give nothing up.
`host_set_server` returns early on a matching origin — writing no file, erasing no
credential — so the obvious place for that check is after it. That is too late:
`clearSession()` has already run, and re-typing your own server signs you out. The
host's early return protects the file and the keyring; it cannot protect a
decision this page took two lines earlier. So the no-op exit sits **above** the
clear, on exact equality against the canonical value the host already answered —
deliberately nothing cleverer, because a looser comparison would be a second
normalizer on the page, and two spellings of one origin is two credential keys.
Both indices are asserted.

#### Q5.117 — A cache is valid only if the thing it caches is there

**The defect.** `build-daemon.mjs` asked `existsSync(extracted)` — the *directory*
the Node runtime unpacks into — and reported *(cached)* on the strength of it. A
directory that had been emptied answered `true`, so the script handed back a tree
with no `bin/node`, and the failure surfaced two functions later as
`spawnSync … ENOENT` on a path whose own name says "cache". It reads as a corrupt
download. It is a check that was never a check.

**How it was poisoned, which is the part worth measuring.**
`Swatinem/rust-cache` treats every subdirectory of `target/` as a build profile
and cleans what it does not recognise before saving — and the runtime cache lived
at `target/node-cache` by an explicit decision, argued as *"`cargo clean` discards
it, which is the right trade for a 50 MB archive"*. So a **green** run saved the
directory with its 130 MB binary stripped out, and the **next** run restored the
shell and died. The run that broke was the first one to restore a cache the run
before it had poisoned, which is why nothing in the commit that went red had
anything to do with it.

There is a second way in with no CI involved: `run()` aborts the script on a
non-zero exit, so an interrupted `tar` leaves a partial directory that every later
run then trusts.

**The rule, in two halves that do not replace each other.** *Correctness*: the
question is asked of the **file about to be executed**, and a directory that
cannot answer it is removed rather than worked around — which makes this
self-healing against any pruner, any interrupted extraction, and anything else
that takes the contents without taking the name. *Cost*: the cache does not live
under `target/` at all, because that directory has an owner. The `cargo clean`
trade is reversed and said so at the constant: it was priced without knowing
another tool cleans there, and a runtime that survives `cargo clean` is a smaller
loss than a build that breaks every other run.

**What that leaves, and what pays for it.** Outside `target/` the runtime is no
longer covered by `rust-cache` at all, so CI would download 50 MB every run. It
gets an `actions/cache` step of its own, keyed on `NODE_VERSION` rather than on
the script's hash — the file changes far more often than the version does, and a
key that churns is a cache that never hits.

**And the path is now written down twice**, in the script and in the workflow. A
mismatch is silent in the direction that costs most — CI saves an empty path,
every run re-downloads, nothing is red — so `nativecheck` reads both off disk.
That is the `.dockerignore`/Dockerfile hazard `CLAUDE.md` already names, at a
smaller scale and with the same treatment.

#### Q5.118 — The invariants of an encrypted channel

**Question.** Phase 5 put a cryptographic protocol between the app and the daemon
and made the relay a carrier. Which of the rules it rests on are the ones that
would be quietly broken by a reasonable-looking change?

**Seven, and each was a decision before it was a rule.**

**The capability rides the first *transport* message, never the handshake
payload.** `Noise_IK`'s first message is encrypted to a static key alone: no
forward secrecy, and nothing stops an eavesdropper replaying it verbatim. A
capability in it would be replayable off the wire for its whole lifetime. After
`ee`/`se` both ephemerals are fresh. ⚠ This is **not** enforced in
`packages/protocol/src/noise.ts`, deliberately — that file implements the
specification, which allows a payload in every handshake message, and the
published vectors carry one in all four. Refusing it there would mean refusing the
vectors. The rule belongs to the layer that decides what to send.

**A tag failure ends the session and sends nothing.** There is no resynchronise
and there must not be: a `CipherState` whose nonce has diverged fails every later
frame, so "skip it and carry on" is a session that never works again while
appearing to try. Both ends take this view. The refusal is a closed stream rather
than a message, because below a failed handshake there is no key to send a message
under — an asymmetry worth naming, since every other refusal in this codebase can
say why.

**`RESPONSE_END` and `FAILED` are different frames.** The natural shape is one
"the stream ended" frame, and with one frame a daemon whose upstream died mid-body
is indistinguishable from one that finished — so the app resolves a short body as
if it were the answer. Two frames make *complete* and *gave up* different bytes.
This is Q6.103 surviving the rewrite. ⚠ And the delivery of it is part of the
rule: `fail()` must `end()` the stream rather than `destroy()` it, or the frame is
written and thrown away — which turns a `502 truncated` back into a transport
failure the client retries for ever. That was a real defect, found by the driver
and not by reading.

**The session pins its own capability onto every inner request.** The channel
proved which device is calling and the capability presented at `HELLO` was checked
against it; letting a request carry a *different* credential would mean the
binding held for the handshake and not for the traffic. It also retires `?token=`
on the last hop, because Node makes that request and can set a header.

**The relay names the mode and understands neither.** `RelayTunnel.open` takes
`encryption` with **no default**, so there is no spelling of that call that
produces an unencrypted stream. It used to write `"none"` itself, which made the
carrier the party that chose — and a carrier that can choose can choose the weaker
one.

**The daemon authenticates the machine by being able to answer at all.** There is
no name to check and no certificate: `IK`'s second message is sealed under a key
mixed from `ee` and `se`, so producing one requires the private half of the static
the initiator started with. Reaching `split()` *is* the check, which is why there
is no comparison to read in the client and why its absence is worth a paragraph.

**No second timer against Q5.24.** The three-party rule — the daemon closes 4401
past `exp + leeway`, the relay authorizes at open and never tears a live stream
down, the client rotates at `exp − 60s` — is unchanged. The pool's reuse margin
decides only whether an **idle** connection is handed out again; nothing tears a
live one down on a clock.

**Status.** Current. `.claude/rules/e2ee.md` is the area.


#### Q5.119 — an offline driver is offline in what it *runs*, not in what it asserts

**Question.** Reported from the development machine: *a node terminal keeps popping
up in my Dock for a second and disappearing — are we comparing node wrongly
somewhere?*

**Decision.** `daemoncheck`'s one `POST /sessions` with a real agent id now goes to
an app whose runtime reports every harness uninstalled, so nothing is spawned on any
machine.

**It is not a version comparison, and the measurement says what it is.** Every exec
on the machine was logged for the length of one `pnpm daemoncheck`: `kimi --version`,
`claude auth status`, about forty `grok --no-auto-update models`, and one
`node /opt/homebrew/bin/kimi acp` — followed one second later by a LaunchServices
registration named `kimi-code`. That registration is the Dock tile. A plain child
process gets none; kimi's ACP entry point registers as an application, so it gets one,
labelled from the node binary that is executing it. `firstVersion` is report-only by
its own docblock and decides nothing, and `agentCli` caches no miss — there is no
comparison anywhere that re-arms work.

⚠ **The defect was written down and then not fixed.** The line's own docblock
already said the assertion *"passed on a developer machine only by really spawning
`kimi` and completing an ACP handshake, inside the driver whose own header promises
no agent is involved, leaving a session and a worktree behind"*. Only the assertion
moved — from `201` to *"not refused for being outside the roots"* — while the request
still went to the shared fixture app, whose registry was built with no runtime and
therefore holds a real `LocalRuntime`. So it went on spawning, and on leaving a
worktree, for releases. **A driver that promises no agent may not be judged by what
it asserts; what it runs is the promise.**

**The assertion got stronger rather than weaker.** `create` resolves the cwd before
it asks whether the agent exists, so `503 agent_unavailable` is a *positive*
statement that the path was accepted and the request went on — where "not
`outside_roots`" was satisfied by every other way of failing too, including the ways
that have nothing to do with the roots. It is also the same answer in CI and on a
developer machine, which the old shape never was.

**What is left, and why it stays.** `availability()` still runs the real login
probes in the sections that build a bare `LocalRuntime` — `claude auth status`,
`grok models`. Those are Mach-O binaries that register nothing and draw no tile, and
one of those sections exists precisely to `report` what this machine answers. The
spawn that mattered was the ACP handshake, and it is gone.

#### Q5.120 — A command is bound to the document that sent it, and a signed-in account's server never moves

**The defect, which one webview holding two accounts creates.** Wherever a webview
is *rebound* — every switch in the single-webview arm, and forgetting the last
account in both arms (Q7.149) — its label outlives the document that was on it. A
host that resolved the account from the label alone would answer the previous
document about the next account, and three shapes of that were real before this
rule:

- a poll or a `cpFetch` in flight between the rebind and the reload hands account
  A's bearer, through `host_cp`, to account B's server — Q5.116's disclosure,
  crossing accounts;
- a sign-out's fire-and-forget `host_credential_clear` lands after the rebind and
  erases B's credential — the race Q7.148 recorded, crossing accounts;
- Android's Back (the activity answers it with `goBack()`) or a back/forward-cache
  restore revives A's document, and its `host_boot` would be handed B's credential,
  because the per-page-load hand-over had been reset.

**Rule 1 — every seat-scoped command presents the generation of the document that
sent it, or is refused `stale_document`.** `host_boot` issues one per page load,
sixteen random bytes; `lib.rs`'s `on_page_load(Started)` retires it
(`Host::page_loaded`), and so does every rebind (`Host::move_seat`). The page sends
it in the `reemoat-generation` invoke header (`GENERATION_HEADER` on both sides):
`native.ts`'s `invoke` adds it to every command but `host_boot` (`withGeneration`,
pure and driven), and answers the first `stale_document` with
`window.location.replace("/")` — once, so a burst of refused calls queues one
navigation. Each of the three shapes above is a document that is not the one its
seat belongs to now, and each is now the same refusal.

**Why a header.** It is the one field Tauri carries beside a command's arguments
without the command's signature seeing it, so no command gains an account parameter
(Q1.651). The comparison is plain equality: the page holds the value, so it binds a
document rather than authenticating one.

**`rebinding`, for the page load that trails.** Between a rebind and the new page
load `host_boot` answers `rebinding: true` with no generation and no credential. On
Android the page-load event is posted to the UI thread while the new document's
first call can arrive first on the bridge's, so the page asks again with a doubling
pause for `REBIND_PATIENCE_MS` (two seconds) before taking the answer as it stands —
a sign-in form over a document whose first command is refused and reloads it, which
is a recovery rather than a hang.

**Account moves use `location.replace`, never `assign`**, so Back cannot bring the
left account's document back to be refused again; `webcheck.native-bridge.ts`'s
navigation sweep admits `location.replace` with a root-relative literal.

**Rule 2 — `host_set_server` is refused unless the seat is pending**
(`pending_seat`). An account is its server (Q1.651); the only window whose server may
move is one nobody has signed in to — a first run, an account being added, or
`‹ Server` on a pending sign-in. So Q5.116's window — a live bearer in the page while
the host's base moves — is on no path the app draws now. `ChooseServer`'s `submit`
keeps its detach-then-set order byte for byte, as the belt for the day an entrance
holding a credential comes back, and Q5.116's index pins still hold on it.

**No `detachSession` on a switch, and that absence is asserted.** A document is one
account for its whole life. Where the host shows another webview, this page stays
alive and hidden with its session, sockets and poll; where it rebinds this one,
Rule 1 refuses whatever it still sends. A detach would strand a live hidden page
with no credential in the first case and guard nothing in the second.

**Defence in depth, not structure.** `host_cp` also refuses an `authorization`
header from a pending seat and on a probe override (Q1.651). The CSP lets the page
`fetch` anywhere, so these guard against a page that is *wrong* — a late poll, a
stale bearer — and not against a hostile one; `script-src 'self'` is still what
keeps a hostile one out.

**Asserted.** `nativecheck`: every seat-scoped command takes the `Webview` and the
`Request` and no account, origin or scope parameter; `host_boot` and
`host_account_confirm` are the only bodies that read a credential, and only the
first hands one to the page; the header's name matches on both sides; `host_set_server`'s
pending guard; `host_cp`'s two refusals. `webcheck`: the header on every invoke but
the first, the reload on `stale_document` once, no `detachSession` in
`switchAccount`, and the bootstrap's order.

⚠ **Closed by construction, measured on no device.** Whether a bfcache restore fires
`Started` does not matter to the rule — either the restore retires the generation
or the new document's did, and the old one's value matches neither — but whether
`tauri::ipc::Request` headers reach a command, and when `Started` fires on Android,
are Q7.149's spike items 14 and 9, and neither has been run.

**Status.** Current. Extends Q5.116 to a rebind, and closes the race Q7.148
recorded.

## Measured behaviour of the agents and the tools

### Q6.1 — Why did `session_started` land in the log *after* the first `prompt` event?

**Behaviour.** `Session`'s event queue drained only during a turn, so nothing
appended outside one reached the log until a prompt existed to drain it. The
started event was therefore ordered behind the first prompt.

**Consequence.** A client that read `agent`, `cwd` or `agentSessionId` off the
transcript alone saw none of them until after the session's first message.

**Handled by.** The registry compensates with its own `status` event at seq 1,
and by carrying `agent`/`cwd`/`agentSessionId` on the snapshot independently of
the log.

**Status.** Superseded by Q2.44. A `ManagedSession` drains the queue between
turns now, so the event is recorded when the agent is adopted — measured, a
session's first five rows are `workspace`, `status`, `agent_config`, `status`,
`session_started`, and `daemoncheck` pins that list. Both compensations stay,
because neither ever depended on the ordering: the snapshot carries the controls
because they are state with one current version and because a *restored* session
has no live agent to publish them at all.

### Q6.2 — Where does a pending permission's command text actually live?

**Behaviour.** In `content`, not `rawInput`. kimi's `tool_call` event arrives
with `rawInput: null`, and the command appears exactly once, as an ACP *text*
content block on the permission request — `"Requesting approval to Running: echo
hello"`.

**Consequence.** The original design joined `toolCallId` against the log to find
the command, which produced an approve button above an empty box every single
time, for the one agent that actually asks. Treating text blocks as decoration
is the trap.

**Handled by.** `PendingPermissionSnapshot` carries `rawInput` **and** `content`,
both clamped to 8 KiB by `clampBlob` — they ride the *snapshot*, which
`GET /sessions` returns for every session at once, so the per-event 128 KiB cap
is far too loose here. The log join is kept as the fallback, for an agent that
fills in the `tool_call` instead.

**Measured.** Against kimi.

### Q6.3 — Is a subagent's parent link present on every event that belongs to it?

**Behaviour.** No. The spawn arrives as a `tool_call` with `kind: "think"`,
`_meta.claudeCode.subagent === true`, and — on the *first* notification — the
literal title `"Task"`, because the model's own description has not finished
streaming. Its steps arrive as ordinary top-level `tool_call`s carrying
`_meta.claudeCode.parentToolUseId`, byte-for-byte the parent's `toolCallId`,
always after the parent. But **4 of 10 and 5 of 14 of a child's updates omit the
parent** — the `toolResponse`-bearing ones rebuild their metadata from the tool
*result* and do not re-derive lineage — and **the spawn loses `subagent: true` on
its own completing update**.

**Consequence.** Absence means "this event did not say", never "top level". A
renderer keyed on the flag flickers off at the end of every subagent; a daemon
reading an absent link as top-level scatters half the steps back into the
transcript, intermittently.

**Handled by.** Both fields are read first-non-null.

**Measured.** 2026-08-01 against claude 2.1.220 / claude-agent-acp 0.63.0.

### Q6.4 — Why does a subagent's own text and thinking never appear?

**Behaviour.** By omission. `claude-agent-acp` gates them on
`clientCapabilities._meta["subagent-transcript"]`, and `src/acp/client.ts` sends
no `_meta` at all, so the SDK is passed `forwardSubagentText: false` and never
emits them.

**Consequence.** What survives is what the subagent *did* and what it
*concluded*, the latter on the parent's completing update. The reason is budget,
not trust — the capability grants the agent permission to *say more*, not a write
primitive in the daemon's process — and the log is 5000 events / 8 MiB evicting a
**prefix**, so a second full conversation per delegate (claude runs three to five
at once) does not degrade into less detail, it evicts the operator's own prompt.

**Handled by.** `pnpm daemoncheck` asserts the absence.

### Q6.5 — Is `Task*` the Task tool?

**Behaviour.** No. `isTaskTool` in the adapter matches
`TaskCreate|TaskUpdate|TaskList|TaskGet` — the task-list tools that replace
`TodoWrite` in headless sessions — so `shouldEmitToolCall("Task")` is true and
the spawn is an ordinary tool call. On claude 2.1.220 the tool is named `Agent`;
the adapter maps both.

**Consequence.** A client that filters on the name `Task` believing it to be the
delegation tool filters the wrong thing.

### Q6.6 — Could a subagent's `TodoWrite` overwrite the main agent's plan?

**Behaviour.** It would, and it cannot reach it today. `TodoWrite` is suppressed
as a tool call and rebuilt as `sessionUpdate: "plan"` *inside* the loop that
stamps `parentToolUseId`, and `PlanEvent` has full-replacement semantics with no
entry ids — so a delegate's list would silently overwrite the main agent's.
Measured, it does not, because **subagents have no `TodoWrite`** ("not available
in this session's toolset") and a main-agent `plan` carries no `_meta` to
attribute. Note also that one `TodoWrite` emits a `plan` per streaming
refinement — **9 events for a 3-item list** — each a full replacement.

**Consequence.** Latent rather than live. Re-check if subagents gain the tool.

**Handled by.** `PlanEvent` deliberately has no parent field: there is nothing to
attribute it from.

**Measured.** 2026-08-01.

### Q6.7 — Does a running subagent emit any progress heartbeat?

**Behaviour.** No. The adapter *can* turn `tool_progress` into an `in_progress`
update carrying `elapsedTimeSeconds`/`subagentType`/`subagentRetry`; measured
across a deliberate 45s `sleep`, **zero arrived**.

**Consequence.** A running spawn sits at `pending` until it completes, and the
only progress signal is its steps arriving.

**Handled by.** Nothing budgets for a heartbeat that does not exist.

### Q6.8 — How deep does delegation actually nest?

**Behaviour.** Nested delegation exists but is flat. A subagent *can* spawn
another (`subagent: true`, parented to the outer one) — but every other call
still comes back parented to the **outermost** spawn, so no third level is
reachable.

**Consequence.** `MAX_DEPTH` is defensive, not load-bearing — and it is defensive
about *indent*, not about the graph. It was mistaken for the cycle bound once and
the cost was a hung tab.

**Handled by.** The visited sets in `placeNodes` are what actually bound the
walks.

### Q6.9 — Is `usage_update` a per-turn summary?

**Behaviour.** No — it fires on essentially every output token. ACP's
`usage_update` comes out of the `message_delta` handler guarded only by "the
total changed", so it is `agent_message_chunk`-class traffic. It carries
`{used, size}`: *occupancy of the context window right now*.
`TurnEndEvent.usage` is a different quantity — ACP's `Usage`, cumulative token
*counts* for one turn.

**Consequence.** Two fields called "usage" in one vocabulary. Merging them would
be wrong in both directions: one is state, one is narrative.

**Handled by.** The occupancy figure is state and rides the snapshot as
`contextUsage` — deliberately not named `usage`; the per-turn counts stay in the
log.

**Measured.** 2026-07-31 against claude-agent-acp 0.63.0
(`acp-agent.js` `message_delta` handler).

### Q6.10 — Why does one tool call arrive as five separate events?

**Behaviour.** A single `echo` produces five notifications, and every useful
field lands on a different one:

| event | title | rawInput | content |
|---|---|---|---|
| `tool_call` | `Terminal` | `{}` | — |
| `tool_call_update` | `echo hi-there` | `{command}` | — |
| `tool_call_update` | `echo hi-there` | `{command, description}` | `["Echo hi-there"]` |
| `tool_call_update` | — | — | — |
| `tool_call_update` *completed* | — | — | ``["```console\nhi-there\n```"]`` |

**Consequence.** A client that keeps only the newest update loses the command
*and* the description; one that keeps only the first loses the output; and one
that prefers the call's own `rawInput` gets `{}` for ever, because an empty
object is not null.

**Handled by.** `EventList` resolves each field separately — newest non-null
status and title, newest **non-empty** arguments (`hasInput`, the same emptiness
rule the rendering uses), and every content block **that says something of its
own**, in order. The output also arrives wrapped in a markdown fence and is
rendered in a `<pre>`, so the fence is stripped rather than shown as three
literal backticks.

**Measured.** 2026-07-31 against claude 0.63.0.

**Status.** Current

### Q6.10a — Five events is the small case. What does a streamed tool call look like?

**Behaviour.** The model types the tool's *arguments* into the content channel one
token at a time, and every block is a strict extension of the last. One `Write`
call: a `tool_call`, then **715** `tool_call_update`s whose single content block
grew from `{` to the finished input JSON, then that same JSON once more beside the
`rawInput` it belongs to, then `Wrote 2347 bytes to tictactoe.py` — the only block
that is a result.

**Consequence.** "Every content block concatenated" drew all 717, so a card showed
716 growing copies of the arguments it was already rendering above them, and the
real output was the last line under them. That is the screenshot this was reported
from. It is also most of the log: across every session on the development machine
those superseded blocks are **15.4% of all events and 55.8% of all bytes**.

**Handled by.** Two rules in `tail.ts`, and both are needed because each is blind
to what the other catches. `supersedes` drops a block that the next one strictly
extends — a draft of the block that follows it. `restatesInput` drops a block that
parses to the call's own `rawInput`, which `supersedes` cannot see because the
streamed copies are pretty-printed (`{"path": "x"`) and the final one is compact
(`{"path":"x"`), so neither extends the other. `restatesInput` runs as a pass over
the folded list rather than inside it, because the pretty-printed copy arrives
*before* the `rawInput` it restates and cannot be judged until the call is whole.

**Rejected — byte equality alone.** `block === JSON.stringify(rawInput)` catches
26 blocks in that database and misses 26 more, which are the pretty-printed ones.
An intermediate version of the comment on `restatesInput` claimed parsing "matched
nothing further"; that was measured on pairs sharing a single event and is false
across a folded call.

**Rejected — collapsing an exact repeat.** `supersedes` requires a **strict**
extension. A tool that prints the same line twice has printed it twice, and
folding that would be this client editing output rather than declining to draw a
draft of it.

**Also handled at the daemon**, which is where the bytes actually are. `Session`
**holds** an update that says nothing but "the arguments are one token longer" and
sends it only when the run ends — `toolDraft`, flushed by the next event for any
call, by `turn_end`, by `error` and by `doDispose`. So a run reaches the log as its
first block and its last, and the drafts between them are never written, never
replayed down a socket and never paged over the relay.

**Held rather than dropped**, and the distinction is what makes it safe: the last
block of a run is the only complete one, so a tool whose output really is
cumulative would lose it. What is never held is anything carrying news — a status
change, a title, arguments, locations or images go out at once. That last clause is
load-bearing rather than cautious: `EventList` draws `in_progress` as a spinning
`Loader` and `pending` as a static glyph, so holding the update that first says
`in_progress` would leave a thirty-second file write looking like it had not
started.

**The rule is now stated twice and that is deliberate.** `packages/web` cannot
import from `src/`, so `supersedes` and `Session.holdsToolDraft` are two copies.
They are not required to agree, and the drift that matters can only go one way: the
client's fold is the **guarantee** — every transcript already on disk carries the
full 715 and always will — while the daemon's is an optimisation on top. A daemon
that suppresses less costs bytes; one that suppressed *more* than the client can
fold would lose content, which is why it holds instead of dropping.

**Measured.** 2026-08-13, against `~/.reemoat/reemoat.db`: 14 360 events over
every session, of which 2212 are superseded prefixes; longest run 715; folding
every call through `mergeUpdates` takes 2332 drawn blocks to 68. Replaying the
daemon's rule over the same stored events: **14 360 → 12 174 events and 3.58 →
1.59 MiB, i.e. 15.2% of the events and 55.6% of the bytes**.

### Q6.11 — Where does a tool's printed output arrive, and why was it lost?

**Behaviour.** On `tool_call_update.content`. `emitDiffs` kept `type: "diff"`
blocks and dropped the rest, so everything a Bash tool printed died at the daemon
and no client could show it however it was written.

**Consequence.** An agent that announced a bare call and filled the arguments in
afterwards also lost them entirely, because `rawInput` was never copied on the
update arm.

**Handled by.** `session.ts` now also extracts the text blocks onto the event and
copies `rawInput` on the update arm. `type: "terminal"` is still dropped: it is a
live handle, not a value.

### Q6.12 — How many `file_change` events does one `Edit` produce?

**Behaviour.** Two, and only the first carries a `toolCallId`: one event with
`source: "diff"` and the tool call's id, then a second with `source: "fs_write"`
and `toolCallId: null`.

**Consequence.** The log join *does* have something to join against for a kimi
edit, and a client that gives up on seeing `toolCallId: null` gave up on the
wrong one of the two. Anything deduplicating `file_change` by path has to expect
the pair.

**Measured.** 2026-07-30 against kimi.

### Q6.13 — Why is there no `insecure_origin` reachability check any more?

**Behaviour.** An https page could not reach an http daemon: the request never
left the browser, so probing anyway marked a healthy daemon unreachable with no
way to tell why, and `insecure_origin` was the answer. Both the check and the
reason are gone — there is one route and it is the relay, which is the same
origin and the same scheme as the UI, so there is no longer a mismatch to have.

**Consequence.** The symptom is memorable and somebody will otherwise go looking
for the code that reported it. It is recorded for that reason alone.

### Q6.14 — What does `REEMOAT_CP_HOST` default to, and what does that imply?

**Behaviour.** `127.0.0.1`. The control plane now also serves the web UI.

**Consequence.** A phone reaching the UI at all means binding wider than
loopback.

### Q6.15 — When does `available_commands_update` arrive, and why was it discarded?

**Behaviour.** Always outside a turn. Both adapters schedule it with
`setTimeout(…, 0)` *after* answering `session/new` — claude at
`acp-agent.js:665,681,689,698`, kimi from its own
`scheduleAvailableCommandsUpdate` — so it is guaranteed to land before any prompt
exists to drain `EventQueue`.

**Consequence.** It fell into `onUpdate`'s `default:` arm, i.e. became an `other`
event, which that queue evicts *first* on overflow and no client renders.
`OtherUpdateEvent`'s own comment named "available commands" as a casualty; it is
the third update to be promoted out of that arm for this reason. Two races sit
under it. The notification can land between `Session.start` resolving and the
subscription being attached, into an empty listener set, so a session that
started quickly would lose the whole list intermittently. And in `AcpClient`,
`router.sessions.get(id)?.onUpdate(...)` **drops** an update for a session it has
not registered yet, with registration happening in the microtask after the
`session/new` result is parsed.

**Handled by.** `onStarted` reads once before subscribing. Against real claude
0.63.0 over a real pipe the transport closes the second window comfortably —
`Session.agentCommands` is empty the instant `start` resolves and holds the list
1ms later — but with both ends in one process and a `PassThrough` between them it
loses every time, which is why `daemoncheck` pushes on a delay and says so rather
than pinning an artefact of having no kernel in the way.

**Measured.** 2026-08-03; the transport window against real claude 0.63.0.

### Q6.16 — Can two published commands share a name?

**Behaviour.** Yes. Of the 100 claude publishes on a development machine with
plugins installed, two are called `review` — a user skill and a built-in.

**Consequence.** Typing `/review` could only ever reach one of them, and a menu
offering the same word twice with different descriptions is a menu that cannot be
acted on.

**Handled by.** `toCommands` keeps the first and counts the second into
`dropped`.

### Q6.17 — Do the two agents publish the same commands?

**Behaviour.** They publish opposite things. claude's list is the CLI's
`supportedCommands()` — dozens of skills, plugins and `mcp:*` entries, minus a
hardcoded denylist (`clear`, `cost`, `keybindings-help`, `login`, `logout`,
`output-style:new`, `release-notes`, `todos`) — and it **republishes mid-session**
via `commands_changed` as skills are discovered in a subdirectory. kimi publishes
six builtins (`compact`, `status`, `usage`, `mcp`, `tasks`, `help`) plus
discovered skills, and **never republishes**. claude publishes `/model` and
`/effort`; kimi publishes neither, and neither publishes `/mode`. `/clear` is not
in either list, and that is the adapter rather than the daemon: claude's
`getAvailableSlashCommands` filters the same fixed eight out before the list is
ever sent — typing it still works, because an unmatched name is sent as written.

**Consequence.** A client that fetches once and caches for ever is correct on
kimi and wrong on claude.

**Handled by.** `commandsRevision` exists exactly to prevent that. `/model`,
`/effort` and `/mode` are built from the config options instead, and a built
command shadows a published one. Restoring `/clear` was a measurement rather than
a hope: verified against the live agent, 100 published, 99 kept, and the only
loss is the duplicate in Q6.16.

### Q6.18 — How big is claude's published command list, really?

**Behaviour.** 100 commands and 18.7 KiB — not the "dozens" a first estimate
assumed. Descriptions run to 1135 characters (a skill's whole trigger paragraph)
against a median of 68. The longest hint is exactly 64.

**Consequence.** That number settles where the list lives: on the snapshot it
would be ~1.1 MB per `GET /sessions` poll, every four seconds, over the relay, to
a phone. The description cap is the only one of the four caps that bites in
practice, and the menu truncates prose in CSS — the byte cap bounds the
*payload*, not the row. The hint cap is 100 rather than 64, because a bound set
to the largest thing you have seen is a bound that clips the next one.

**Measured.** 2026-08-03 against claude 0.63.0, on a machine with plugins
installed.

### Q6.19 — What happens to an unrecognised slash command?

**Behaviour.** kimi intercepts it; claude forwards it. kimi's
`detectSlashIntent` parses the leading text block and answers an unrecognised
name with "Unknown ACP command: /foo" and `stopReason: "end_turn"` — the model
never sees it. claude passes the text to the CLI, which decides.

**Consequence.** The divergence is the agents' own and this client deliberately
does not paper over it: an unmatched `/foo` is sent as typed, because the cached
list can lag what the agent accepts and refusing to send is a worse failure than
one wasted turn.

### Q6.20 — Why does the daemon never call ACP's `session/authenticate`?

**Behaviour.** Agents advertise `authMethods` at `initialize` — Gemini offers
four (`oauth-personal`, `gemini-api-key`, `vertex-ai`, `gateway`) and expects the
client to pick one. This daemon picks none: `agents.ts` says *"both agents
authenticate out-of-band"* and `grep -rn authenticate src/` finds nothing. That
works for `claude` and `kimi`, which read credentials off disk. After a completed
Google sign-in, `gemini --acp` still answered `session/new` and then failed the
first prompt with `API_KEY_INVALID` — a working login that the session never
selected.

**Consequence.** Any future agent support has to decide whether to drive
`authenticate` or to keep inheriting from disk and accept the smaller agent set.
Today the choice is made by omission.

### Q6.21 — Why does `resolveLoginBinary` exist separately from `resolveAgent`?

**Behaviour.** `claude-agent-acp` resolves a `claude` that is not on PATH. The
adapter depends on `@anthropic-ai/claude-agent-sdk`, which ships the binary
inside a platform-specific package (`…-sdk-linux-arm64/claude`) with no `bin`
entry and resolves it internally.

**Consequence.** The adapter can work perfectly while `claude` is absent, and a
remedy naming `claude` cannot run — which is exactly what happened to a
documented one.

**Handled by.** `resolveLoginBinary`, which reads `CLAUDE_CODE_EXECUTABLE` first.
That variable is preserved through `agentEnv`'s strip for the same reason: it is
the documented override for *which* build the adapter drives, and a login must
drive that one or it writes credentials the session never reads.

[Amended 2026-09-04, Q4.114: the platform package is **excluded** now, through
`pnpm-workspace.yaml`'s overrides, so the adapter resolves nothing internally and
throws with `CLAUDE_CODE_EXECUTABLE` unset — the Behaviour above no longer holds.
What stands in its place: `resolveAgent` refuses the harness first, through
`cliFor` — an override, else `findOnPath` — so `describe()` fails with a sentence
rather than the adapter dying at spawn; `LocalRuntime.launch` writes the variable
on **every** spawn from the copy `agentCli` chose, `spawnPlan` being the decision;
and `resolveLoginBinary` is an existence test only — the copy that runs, for the
login, the logout, the probe and the session alike, is `agentCli`'s answer, which
is what keeps the Consequence from recurring by that route.]

### Q6.22 — Why does an agent login need `script`?

**Behaviour.** A daemon's stdin is never a TTY, and both agents' login flows are
interactive terminal programs that will not prompt without a pty. The two
`script` implementations differ: util-linux takes a shell string after `-qec`,
BSD takes argv after the typescript file, and getting it wrong does not fail
loudly (the BSD form on Linux writes a file called `claude` and records nothing).
macOS `script` has no `-e`, so it does not propagate the child's exit status.
Under a pty with stdin piped, `claude auth login` prints the authorize URL
wrapped in an OSC 8 hyperlink (`ESC ] 8 ;; <url> BEL <url> ESC ] 8 ;; BEL`) and
waits on `Paste code here if prompted >` — so it needs the input box and **no
inbound port**, its `redirect_uri` being `platform.claude.com` rather than
localhost. `kimi login` is a device-code flow: it prints a URL and a user code
and then polls by itself, so its input box is never used.
