# Behavior Specification

> How CodeWalk behaves from the user's perspective.
> Only documents **current, implemented** behavior. Planned features live in GitHub Issues.

This file covers CodeWalk 2 only. The v1 behavior sections live on the `v1` branch
(`git show origin/v1:BEHAVIOR.md`); issue #446 indexes them. They are a UX reference, not a
description of this code.

## OpenCode v2 compatibility

- **Given** a native OpenCode server on a stable 2.x version at or above 2.0.20
- **Then** the v2 session runtime can connect to every stable version from the minimum on; a newer server version is never flagged (#507)
- **Then** an uncertain prompt on a version other than 2.0.22 is never automatically replayed, and a history scan that cannot prove absence keeps it unresolved; observed pending or delivered prompts can still be reconciled
- **Then** unsupported major versions and prereleases are refused, and pairing-token renewal remains limited to the verified 2.0.22 contract

## Explicit v2 foundation

- **Given** CodeWalk is launched with `lib/main_v2.dart` as its explicit target
- **When** its root widget mounts
- **Then** an independent Material3 app opens into the chat workspace, with no destination bar or rail
- **Then** below 600 logical pixels the chat takes the window and the projects and sessions list lives in a drawer; from 600 the list stays beside the chat in a pane that can be hidden, fixed at 260 below 840 and resizable from there, 300 by default
- **Then** settings and servers open as secondary pages; their back button and the system back return to the workspace, and a page opened by a link with nothing under it goes to the workspace home

### V2 workspace

- **Given** the v2 workspace opens on its home
- **When** saved servers and their credentials have loaded
- **Then** it selects the server of the restored launch tab, else the last saved selection if it still exists, else the first saved server; one saved server needs no manual selection, and removing the active server selects another saved one
- **Then** no saved server shows a stable setup action leading to Servers; an unreadable server store offers Servers, and a saved server whose catalog fails keeps its failure reason, Retry and Servers
- **Then** a selected server with no open session shows the select-or-create chat state; New Chat opens its local draft without requiring verified endpoint commands
- **Then** each server remembers its last explicitly chosen real project, restoring it once when the first successful catalog contains it; the placeholder root and a temporary fallback when the chosen project leaves the rows never overwrite that choice
- **Then** rapid server or project choices save the last choice in order, and unreadable workspace state is kept untouched

- **Given** the v2 list has loaded sessions of a server
- **When** they belong to several projects
- **Then** only the sessions of one project show at a time, the first project the server returned by default; tapping another project header shows its sessions, and the sessions with no project are a project of their own
- **Then** a project the user tapped stays shown until it leaves the rows, and the choice is dropped when the list is cleared, as with a change of server
- **When** the user opens a session from the list or follows a `/s/<server>/<session>` link
- **Then** both land on the same route inside the workspace: the server is the saved profile with that id and the list follows it; the session is the loaded row with the same identity or, outside the loaded rows, one direct read of that server
- **Then** an unsaved server, a server that wants a login, a session the server no longer has and an unreadable session each have their own notice; the login and unreadable notices offer a retry, and a read answering another session is never opened in its place
- **Then** from 600 logical pixels the session opens beside the list; below that it takes the window and the list moves to a drawer, opened from the session's app bar
- **Then** the system back at the chat workspace opens the drawer when it is closed; with the drawer already open, or in a wide window without a drawer, it asks the platform to leave the app and keeps the workspace route
- **Then** an open session, its draft and its live connection stay through refreshes and searches of the list, a reload of the saved servers and a resize between compact and wide; choosing another server in the list closes it and shows that server's sessions
- **Then** the new-session shortcut opens the local draft of the selected server and project, and the settings shortcut opens settings over the current page

- **Given** the user opens conversations in this v2 app
- **When** the corresponding route is displayed
- **Then** the localized session catalog offers a server switcher and an action that opens the hosts page, alongside automatic server restoration on the workspace home
- **Then** loading server profiles, storage failure, missing credentials and a successful empty session read have distinct states; no session request starts before credentials finish loading
- **When** a server is selected or manually refreshed
- **Then** native Android/Linux reads use its current password or paired credential and preserve the authored endpoint, port and proxy prefix
- **Then** sessions retain server order, use complete host/harness/session identity and show a localized fallback for an empty title; a tap opens the session, falling back to read-only history when only that reader is available
- **Then** a long press, secondary click, context-menu key or Shift+F10 opens the row actions without selecting it; when both readers are available the menu also offers read-only history, visibly disabled during catalog loading, server unavailability or another history opening
- **Then** manual pagination requests 50 items per page, retaining at most 200 rows or ten accepted pages; empty or short pages with a continuation remain pageable and a local limit is explicitly identified
- **Then** refresh invalidates the old continuation, while transient failures can retain clearly marked previous results; authentication failure or a changed server/credential clears the catalog
- **Then** superseded, cancelled or disposed reads cannot publish old rows, errors or loading state; retries and pagination remain manual

### V2 workspace panes and shortcuts

- **Given** the workspace is at least 840 logical pixels wide
- **When** the user drags the conversations pane's divider
- **Then** its width follows the drag immediately within 160–500 logical pixels, saves when the drag ends and resets to 300 on a double tap; a narrower window reduces only the rendered width to keep at least 320 for chat, preserving the saved preference
- **Then** below 840 the medium layout keeps its fixed 260-pixel pane without changing that preference, and the header keeps its controls usable at the 160-pixel minimum, including RTL and enlarged text
- **When** the user hides the pane on a non-compact layout
- **Then** the toolbar keeps the server switcher, Settings and Project Context accessible; Project Context uses the drawer's picker and shows the chosen project's remembered conversation or workspace home, unless another navigation or server change took place while it was open
- **Then** showing the pane again restores its saved width, without replacing the conversation

- **Given** a physical keyboard reaches the workspace
- **When** a configured shortcut has an available handler
- **Then** `mod+N` opens the project's local New Chat draft, `mod+L` focuses the shown composer and `mod+R` refreshes the list and wakes the existing live views, keeping the draft and conversation open; it is a keyboard shortcut only, with no toolbar or menu action (#467)
- **Then** `mod+W` closes the shown eligible local tab with its usual neighbour, New Chat and Undo behavior, including when focus is in the toolbar or conversations pane; without an eligible tab it closes the window as the desktop close choice says (see V2 desktop window), else requests the ordinary platform close, while `mod+Q` always requests desktop app exit and stays unconsumed on mobile
- **Then** a single Escape closes an open overlay or drawer first, else focuses the available composer; the focused composer keeps its own Escape behavior, and dialogs, IME composition and ordinary editing retain priority
- **Then** Tab and Shift+Tab can leave the toolbar and return through the workspace controls

### V2 desktop window

- **Given** the app runs in a Linux desktop window with Integrated title bar on (the default)
- **When** the window manager hides its title bar (on GNOME the header bar, keeping the native frame, resize borders and snapping)
- **Then** a band at the top of every page replaces it: a free area that drags the window and maximizes or restores it on a double click, then Minimize, Maximize/Restore and Close at the right edge in every language
- **Then** on a workspace at least 600 logical pixels wide the session tab strip sits in that band, taking only its tabs' width and always leaving at least 48 logical pixels free to drag, with the toolbar below it; the tabs keep their own taps, menus and double tap; on any width the tabs stand on the strip's bottom edge, so the selected tab meets the page below with no gap (beta.21)
- **Then** on a compact window and on Settings, Servers, pairing and error pages the band holds only the free area and the controls; the compact strip stays in the page
- **Then** a window manager that refuses to hide its title bar keeps it, and no band shows
- **When** the user turns Integrated title bar off in Settings > Behavior
- **Then** the system title bar returns at once and the strip goes back below the toolbar; the choice persists as `cw2.settings.integratedWindowChrome` (absent when on)
- **When** the window is closed by the band's Close, the window manager (its close button, Alt+F4, the taskbar) or `mod+W` without a tab
- **Then** Settings > Behavior > When closing the window decides: Close (the default) quits CodeWalk, Minimize keeps it running minimized; the choice is read at that moment and persists as `cw2.settings.windowCloseAction` (`minimize`, absent for Close), and an unknown stored value means Close
- **Then** `mod+Q` and the update restart still quit, a second Close while the app is quitting is the same request, and there is no tray (#309)
- **Then** Android and the Web have no band, no window choices and no change in layout

### V2 server health and workspace status

- **Given** the v2 app is in the foreground with saved servers whose credentials have loaded
- **When** the health lane runs
- **Then** every saved server is checked with the read-only compatibility probe at most every 10 seconds on its own lane, never cancelling or borrowing a manual check from the Servers page; a resume rechecks at once, a server `Retry-After` delays the next check, and nothing is probed in the background or while the server catalog is reloading or an edit is pending
- **Then** a compatible answer shows Online; a server with no answer yet (first check pending, catalog reloading, or a check cancelled before any answer) shows a neutral Checking, which turns Delayed only when that first check stays unanswered for more than 5 seconds; a periodic, resume or network recheck keeps the last known status while it runs (#514, owner 2026-11-27); and a confirmed failure or a missing, unreadable or expired credential shows Offline with its localized reason and a way to recover (Retry, Servers or credential repair); a cancelled check never proves Offline, and a live stream that is reconnecting is shown separately from server health
- **Then** an open conversation whose active server is confirmed Offline says Offline in its status bar, with the reason in the composer's recovery card, never a Live label; an authentication failure keeps its own status, while a server the app cannot use for any other reason, an unsupported version included, reads as Offline: the app never predicts or argues about server versions (owner, 2026-11-10)
- **Then** a network signal prompts a fresh server check with a five-second connection timeout without using the device's Internet state as proof of server health; repeated same-route signals are bounded to one check per ten seconds, while a new route rechecks immediately; a reachable local or VPN server stays usable, and a failed or cancelled network feed cannot by itself mark a server Offline
- **Then** the server switcher in the list header shows the active server with that status and opens a searchable list of saved servers; the Servers page has the same search
- **Then** an Offline active server disables the composer with that reason instead of letting a message be sent

- **Given** the compact workspace shows its app bar
- **When** something needs the user's attention
- **Then** the hamburger carries one badge chosen in this order: the active server Offline after a 7-second resume grace (#503), the open conversation or the session list still syncing 10 seconds after that grace, a root conversation of the current project that failed, one that waits for input or approval, a downloaded verified Android update cached on disk (`updateReady`) or a newly discovered update (`updateAvailable`), a root conversation of the current project with an unread reply within the 1-hour `unreadEmphasis` window, and a resume sync in progress or a session list catching up or waiting to retry a failed read (a spinning ring); child/sub-agent sessions and unread replies older than 1 hour never badge the hamburger, real alert/notification dots render filled, and update badges render a download icon; the hamburger is where the list's own recovery shows, while the open conversation's shows in its status bar (owner, 2026-11-10), and no progress line runs under the tab strip while a conversation loads or syncs again on resume (beta.21); the drawer opens with a notice explaining that badge (plus a one-tap quick-install row at the top whenever a verified cached Android APK is waiting, even if a higher-priority alert owns the hamburger icon), and tapping the notice installs the cached update, opens Updates, opens the conversation it names, or opens Servers for the server alert
- **Then** a warning snackbar about an Offline active server appears only 5 seconds after the resume grace, once per outage, and is cancelled by recovery, a move to the background or a change of server or page
- **Then** Settings has its own button in the list header, including the compact drawer; it is absent from the compact app bar and overflow even when a Settings pin was saved on a wider layout, while the saved pin still appears on wide layouts
- **Then** Context usage and New Chat are pinned in the app bar by default (`Context usage` immediately to the left of `New Chat`) and up to four actions can be pinned from the overflow menu; compact offers Context usage, New Chat and Servers, while wide also offers Settings; existing installs that saved an earlier pin list receive a one-time atomic migration inserting Context usage left of New Chat (or first if New Chat is absent) and persisting the versioned list so unpinning persists across restarts; Refresh is gone because the list and the conversations recover by themselves (#467), and a Refresh pin saved by an earlier version is dropped; adding a fifth pin drops the oldest saved pin; Context usage stays hidden from the toolbar when no live session is active or the harness declares no usage capabilities, while its overflow entry stays listed (disabled for opening details, with its pin toggle active); Undo remains listed and disabled while no live session is shown
- **Then** inside an active session whose harness declares usage capabilities (`usage.context`, `usage.tokens`, `usage.cost`, or `usage.quota`), the toolbar context-usage knob renders a compact 20×20 circular meter with themed thresholds (`primary` below 65%, `tertiary` from 65% to 84%, `error` at 85% and above), `—` on a neutral track whenever usage is unknown (never showing unknown values as zero), and an indeterminate ring while compacting; tapping it opens the details surface (anchored popover from the wide knob, bounded dialog from the wide overflow, modal bottom sheet below 600 dp) showing Usage, Tokens (last completed assistant step strictly after the last completed compaction and strictly before any staged revert boundary), Cost (authoritative cumulative session total hydrated from the session record and updated live, or deduplicated per-step sum when complete history has no cumulative total, never double-counted), Limit (model context limit), five-field token breakdown, automatic-compaction explanation, a full-width `Compact now` action honoring `canCompact`/`compacting`, and either native quota windows when `usage.quota` is available or a harness-not-exposed notice otherwise (#294)

- **Given** the user edits a saved server on the Servers page
- **When** only its name changes
- **Then** the server keeps its identity, connection, credentials and checks, with no new probe or credential access
- **When** its URL changes (including a proxy path, or a return to an earlier URL)
- **Then** the server keeps its identity but gets a new binding revision: everything still running against the old URL is retired before the edit is saved, a reply or request the old URL never answered is never sent to the new one, saved tabs, drafts and queued messages stay on the device without acquiring the new URL, and the credential of the old origin is never copied to the new one
- **Then** a stale editor or an unknown save outcome is reconciled from storage before another save, and the failed form keeps its values
- **Then** a server can be marked as the local default; marking it never switches or probes the active server, and on start the workspace restores the launch tab's server, else the last active one, else a valid default, else the first saved server
- **Then** each server card (#505) shows its name with an Active badge and the overflow menu; one status line with the health dot, the harness and the server version when known ("Online · OpenCode 2.0.23"); the URL on one left-to-right selectable line; one quiet line with Default, the sign-in kind and a paired credential's expiry (local date with year, time in the user's clock format); and, only when there is one, the failure reason in the error color, followed by the upgrade instructions for a server below the minimum, and, while a delay the server asked for holds Check connection, until when it asked to wait (rounded up to the minute in UTC) or, for a wait of more than a day, that it is checked again when CodeWalk restarts. The status line wraps rather than hiding the version on large text. The active server's card uses the selected surface, no second status chip repeats the health, and a thin bar shows only during a manual check. Its overflow menu offers Edit, Set or Clear default and the existing actions without activating the card
- **Then** searching Settings for the server filter opens Servers with its filter focused and briefly highlighted, without copying the query; Back returns to Settings with the query kept

- **Given** a live conversation's server connection changed while it was open
- **When** the live view shows the failure
- **Then** it explains that the server connection changed and offers to reopen the conversation with the current settings, rather than a generic unavailable message

### V2 session tabs

- **Given** the user opens sessions in the v2 workspace
- **When** a session opens from the list, a link or a tab
- **Then** it adds a tab, or focuses its tab, keyed by its full identity (server, harness instance, session), so two servers with the same session id keep two tabs; the tab becomes the selected tab of its server
- **Then** a session the endpoint attributes to a parent never becomes a tab: opened from its parent's robot capsule, its tool-call card, a link or a restored route, it shows its conversation with no tab written, no selection changed and no tabs-full notice, while its live view stays warm beside its parent's, keeping the reader's place and the return path
- **Then** a strip below the app bar shows every tab of the server: pinned tabs first in their own scroll (an inactive pinned tab shows only its icon, the shown one its title), then the other tabs grouped by project in the order their projects first appear, keeping each group's order stable when switching tabs without promoting the shown tab or changing the saved order; it leaves the scroll offset unchanged when the shown tab is already completely visible, reveals off-screen tabs minimally in both LTR and RTL, and switches on a tap
- **Then** on a noncompact workspace the strip spans the sidebar and chat, and in the Linux desktop window band it sits above the toolbar (see V2 desktop window); on a compact workspace it remains above the chat
- **Then** each tab shows its custom icon, else the project's image supplied by the server, else the themed folder icon, replaced by a mark while its session fails, waits for an answer or has an unseen reply, with a small running badge while it works; pinned tabs, the recent-tab switcher, the New Chat draft and the Change icon preview use the same project image, without changing tab colors
- **Then** an inline `+` after each project's group opens or switches to that project and shows its local New Chat draft with the composer focused; nothing is created on the server until the first send, and a failed switch shows an error and no draft; on the workspace home the active draft shows as a selected New Chat placeholder in its project's group (in place of that `+`), with no menu, never saved as a tab, and replaced by the session its first send creates
- **Then** the open projects' recent root sessions become tabs automatically: the later of their server update and local open keeps them for three hours; the selected tab, a confirmed running or waiting session and a context-pinned session remain eligible, and unknown activity or a missing partial row never proves idleness or deletion
- **Then** existing tabs keep their saved order, new candidates append by recency while there is room, and opening a project without an eligible tab adds its most recent non-suppressed root session once
- **Then** switching tabs keeps each session's live connection and the reader's place in its timeline, including older history it paged in; content that arrived while a tab was hidden is marked on the jump control, and a turn that ended meanwhile is revealed from its start when the reader was at the bottom: up to 8 views stay open, the least recently shown closes first and reopens when shown again, and showing a tab of another server closes the views of the previous one
- **When** the user closes a tab — only the shown tab has a close control — with that control, a double tap or double click, a middle click, Delete on the focused tab, the screen reader's dismiss action or `mod+W`
- **Then** only a local suppression is saved: refreshes and repeated updates keep it closed; an explicit open, a pin or a strictly newer authoritative update can bring it back, while the first update observed after an unknown close only establishes its baseline
- **Then** closing a pinned tab removes its project pin first, and Undo restores the pin before the tab; a failed tab write compensates that pin once, and an unreadable or unloaded pin catalog refuses the close
- **Then** a shown tab hands over to the next tab in the strip's displayed order, else the previous one, else its project's local New Chat draft with the composer focused; closing a tab that is not shown never navigates, and navigating elsewhere before the close is saved wins
- **Then** a 3 s Undo puts the tab back in its place without navigating or taking the selection
- **When** the user long-presses a tab, right-clicks it (at the pointer), presses the Menu key or Shift+F10 on it, or uses its semantic action
- **Then** its menu opens without selecting the tab, with the conversation list's actions under the same availability (Pin or Unpin, History, Mark as viewed, Rename, Fork, Delete with confirmation), Change icon and a destructive `Close {project}`, which says that at least one context must remain open when it is the only one; server commands (Mark as viewed, Rename, Fork, Delete) appear only for a session of the shown list, so a tab of another project offers its local entries, and a tab whose session row is not loaded offers only Change icon and Close project; closing the shown project from its tab shows the project that takes its place
- **Then** Change icon picks one of the curated icons or the project icon; the choice is kept locally for that session (at most 512) across closes, expiry and restarts, and leaves with its session's authoritative deletion or a deletion accepted from CodeWalk, its project's closure or its server's removal; an unreadable record is kept untouched
- **When** the user wants a recent tab
- **Then** the strip's trailing button lists every tab of the server, the selected one first, then the most recently opened
- **Then** on desktop, holding Ctrl with Tab (Shift+Tab backwards, a held Tab keeps cycling) shows the same list and opens the highlighted tab when Ctrl is released; Escape, a tap on the strip or sheet, another session or the app leaving the foreground cancels it
- **When** the app restarts
- **Then** the tabs, their order and each server's selection come back the same however often they are read; opening on the workspace home returns once to the selected tab of the server whose tab was used last, while a link or a launch on another page stays where it is
- **Then** a tab an older build saved for a child is excluded once the loaded rows or a direct read prove it, without the removal notice, without being reported as deleted and without ending an open route; the server's selection moves to the next kept tab or clears, and a saved tab already known to be a child does not navigate on launch: a remaining primary tab of the same server is restored instead, or the list stays open when none remains; an absent saved row waits for its direct read before launch, and explicit New Chat or project navigation cancels a pending restore
- **Then** expiry and project closure may remove an unselected tab without making its session route read as missing; only a current server's authoritative not-found ends the view, including an answer arriving after the tab already closed locally, and releases its retained connection
- **Then** sessions merely absent from the loaded rows, unreadable or behind a login keep their tabs; known background-project rows need no full history read, tabs of a removed server leave with it, and a failed automatic tab write waits for later external input rather than immediately retrying itself
- **Then** at most 32 tabs are kept: a new one beyond that is refused with a notice instead of closing another; an unreadable saved record is kept untouched and no tab is saved over it

- **Given** the session tab strip is shown for the first time in this install
- **When** the strip appears above the chat
- **Then** a one-time hint explains that each tab has its own menu to pin it, change its icon or close it, and offers a filled "Don't show again" action
- **Then** "Don't show again" hides the hint for good and is persisted as `cw2.settings.tabsGestureHintDismissed`; it never returns, and hiding the strip hides the hint with it

### V2 sub-conversations

- **Given** a v2 session whose timeline shows a subagent call
- **When** the user expands the compact calls summary and taps that call's card (its own expand and copy controls keep their taps)
- **Then** only a direct child of the session on screen opens: the child the call itself named while it ran or when it ended, else the only child the server lists for the session, else the call paired with the children by creation time, but only when the whole history is in view, both counts match, every creation time is known and distinct and no call contradicts the pairing
- **Then** the chosen session is read first and opens only when it is exactly that child of the session on screen; a refused or contradictory name never falls back to another rule, a newer tap or any navigation meanwhile cancels the lookup, and when nothing can be told apart the session stays and a notice says no sub-conversation was found
- **Then** a child named only by a live progress update is forgotten when the stream reconnects or the history is read again, until the server names it again; a name carried by the call's final event or by the history stays
- **When** a sub-conversation is shown
- **Then** it keeps the full composer and Stop, a `Return to parent conversation` control stays visible above its timeline, and its model, agent and variant show the child's own choice, locked
- **Then** showing it creates no tab and selects none: the strip keeps its server's primary tabs with the parent's selected, and `mod+W` while a child is shown returns to its immediate parent instead of closing the window
- **Then** returning (the control, or the system back on a phone before the drawer/background order) goes to the immediate parent, one level at a time, and the parent shows the same rows where the reader left them, or its newest content when it was following, even after it grew meanwhile
- **When** a session has direct sub-agents or shell commands (live harness-observed shells when `shell.observe` is available, or timeline shell runs/calls)
- **Then** a robot capsule floats over the bottom end of the timeline, above the composer and status strip, without reserving a full-width row; its badge counts distinct active sub-agents (executing or human-waiting) plus running shells, a shell only once it has run 5 seconds, counted from when it was first seen running when it reports no start (a quicker command never shows in the capsule or its pop-in, even once its live record gives way to a timeline row, so the count does not flicker; #544), and the timeline keeps room for the capsule only while it shows, and disappears at zero while the capsule remains available for completed history; while that active count is above zero, a luminous `SweepGradient` border sweeps around its `StadiumBorder` outline (~2 s per turn, paused by `TickerMode`, falling back to a static `primary` border under reduced motion) and disappears whenever the count drops to zero or the view becomes stale/reconnecting (#525)
- **Then** the capsule and its pop-in follow the selected theme; timeline content stays scrollable beside the capsule and its last row can scroll clear of it; navigation buttons sit above it, or alongside it when the timeline is short
- **Then** its anchored 2-tab pop-in separates Active from Completed (opening on Completed only when nothing is active): Active lists active sub-agents (including unconfirmed statuses) and running shells; Completed lists completed sub-agents and deduplicated completed shells (keyed by opaque `shellId`, so a running shell never duplicates into Completed)
- **Then** opening a sub-agent row shows that child's full conversation; child permission requests and question forms can be answered from the parent, while the child's transcript details stay in the child and forms are never answered automatically
- **Then** when the harness verifies `shell.observe`, running shell rows show redacted command text, a 1-second elapsed timer active only while the pop-in is open and a shell runs, and open a bounded cursor-paged, credential-redacted output dialog (capped at 64 KiB, cancelled on close, handling 404 cleanly, never reading host `file`/`cwd`/`pid`); completed timeline shells open tool details; when the harness verifies `shell.stop`, running shells expose a single-flight Stop action (`DELETE /api/shell/:id`, dropping the row on 204/404); harnesses without `shell.observe` omit live shell rows, elapsed timers, and output paging, and harnesses without `shell.stop` omit the Stop control

### V2 project contexts

- **Given** a v2 server whose saved project contexts can be read
- **When** the session list is shown
- **Then** the list reads only the sessions of the active project context, using the official `directory` filter with the exact directory the server keys the project by; the directory is never normalized by the client
- **Then** a server without contexts starts in the project the user last used, else in the project of its most recent session (sessions recorded at `/` are skipped), else in the server's default location; a failed default-location read is not retried until the server changes
- **Then** each server keeps its own ordered open contexts (at most 32), the active one, a closed history (the 64 most recent), the pinned sessions of each open context (at most 512) and, for the drawer's order only, when each open context was last shown (#534: a device-clock stamp written when the active context changes, for the context left and the one shown, always later than the stamps kept; a stamp past what a date holds is ignored on read, and one more than a day ahead of the clock is dropped when the next is written); a change that would pass a bound is refused with a localized notice instead of evicting a user choice
- **Then** switching to an open context shows the rows last read for it at once, marked as previous results, while its head is read again; the other open contexts keep their first page warm through one background reader that reads one context at a time, coalesces server changes at least 10 s apart and stops after three failed passes until the next recovery (a return from the background, a network change, the server answering again) or `mod+R`
- **Then** closing a project drops its tabs, pins and remembered view locally in one saved change and never creates, archives, aborts or deletes a session on the server; the last open project cannot be closed and says that at least one context must remain open
- **Then** opening a session of another project from a preview or a link makes its project the active one
- **Then** switching projects from the drawer or the picker shows again what that project last showed: its last session, or its list or draft; closing the shown project shows the project that takes its place unless the user already navigated elsewhere
- **Then** a project whose authoritative, complete and successful read holds no session opens its local New Chat draft once; nothing is created on the server until the first send, and the draft never replaces a session or a draft already shown
- **Then** while the saved contexts cannot be read they are never overwritten, a notice says the projects could not be read or saved, and the list reads the whole server grouped by project as before

### V2 project drawer

- **Given** the v2 workspace shows the session list in the compact drawer or the medium/expanded pane
- **When** project contexts are available
- **Then** both places render the same tree on one continuous surface: the server switcher with the Settings button on one row 8 dp from the top, then transient notices (syncing, an update, the loading bar) below that row instead of above it (#533), the active project's title with its path (opening the project picker), a header row with the Conversations title, a collapsed search button, the project picker and New Chat, then the open projects: the active one first, the others below it by recency (#534)
- **Then** the search opens inline with the field focused and takes the whole header row (the other header controls step aside until it is cleared), filters the active project's rows by title as each character is typed, listing every match without the five-row window, keeps its query when the keyboard closes or the user taps outside, and only collapses when cleared with its clear button or Escape; a saved query reopens the field expanded with the list already filtered; the query is saved once typing pauses and when the list closes
- **Then** sessions in the active project are ordered by most recent update, with pinned sessions leading the list; only primary sessions are listed: a session the endpoint attributes to a parent is never a row, in any project list or search
- **Then** there is no Recent section (#534): below the active project, the other open projects follow by what happened last in each, the latest update of the conversations read for it (children included) or the moment it was last shown, whichever is later; a project with neither comes last, ties keep the opening order, and the saved opening order, the picker and the close handover do not change
- **Then** the active project lists its first five conversations, pinned ones leading, and the conversation on screen always among them (taking the fifth place when it would fall outside); Show more lists every conversation read and Show less returns to five; the choice resets when another server or project is shown; Load more appears once the whole list shows (expanded, searching, or nothing hidden) and opens the list so the new page shows
- **Then** each open project row shows its name, its path with the leading part elided so the trailing folders stay visible (always left-to-right, read whole by a screen reader), its conversation count, counting only the primary sessions its list shows (`N+` when only the first page was read, none before its first read) and a trailing menu of 32 dp on desktop and 40 dp on compact; the active project is followed by its rows and the others by up to three one-line previews from their last read, or a hint to open them; tapping the active project folds its rows away and tapping it again unfolds them, showing another server or project by any route drops the fold, and while the drawer search holds a term the rows show and a tap on the project does nothing; only the active project reports a folded or unfolded state to screen readers; a chevron centered on the row, beside the count, points up while the rows show (beta.21)
- **Then** the project menu, a long press, a secondary click, the Menu key, Shift+F10 or the semantic action open the single destructive `Close {project}` entry; opening the menu never switches projects
- **Then** the selected project carries a thin accent along the start edge with emphasized foreground text, while the shown session uses a subtle theme-consistent contrasted background fill with emphasized foreground text (without the start-edge accent); activity marks stay compact foreground badges, and a completed root reply not seen yet keeps a lighter highlight for one hour (never on child sessions)
- **Then** session rows are denser since #534: 8 dp of vertical padding on compact windows and 4 beside the chat, a title of at most two lines and a vertically centered 40 dp (compact) or 32 dp menu, so a one-line row is 56 or 40 dp tall; a project row keeps its place in the list's elements when the projects reorder; session rows never render diff-stat pseudo summaries
- **Then** a session row's menu offers Pin or Unpin for its project context; the pin is saved locally only for that server and project

### V2 project icons

- **Given** the selected server supplies an optional project image
- **When** a project row, grouped header, matching picker result or default session-tab icon is shown
- **Then** its existing icon slot shows that image, including SVG and supported raster formats; custom session icons and attention marks keep precedence
- **Then** a missing, invalid, oversized or unavailable image keeps the themed folder or source glyph, without blocking the project or its conversations; a harness without project images needs no extra capability or control
- **Then** project metadata is shared by the selected server's surfaces, refreshed on project updates, reconnection or explicit refresh, and discarded when its server binding changes; a project-only update does not reload session rows, and an unavailable metadata read keeps the last successful images
- **Then** images use a bounded memory cache; HTTPS image requests carry no server credentials, and a later rebuild can retry the same URL after its cached entry expires; image bytes are not saved with project identity or session-tab preferences

### V2 project picker

- **Given** the user opens the project picker from the project title
- **When** the picker is shown
- **Then** compact windows use a full-screen dialog and larger windows a centered dialog at most 560 dp wide
- **Then** one focused search field ranks the open and closed projects, the server's projects and a bounded server directory search (250 ms after typing, from the active project or the server default location, at most 50 results), deduplicated by exact path, with exact and prefix matches ahead of ordered fuzzy matches
- **Then** arrow keys and Ctrl+N/Ctrl+P move the highlighted result (wrapping, always kept in view), Enter or the keyboard's Go action opens it (or the typed absolute path when nothing matches), Tab completes the field to the highlighted path and Escape dismisses the picker; an unfinished IME composition never submits; a new query highlights its first result
- **Then** Browse directories switches to a folder browser inside the same dialog, resolving each entry against the location the server answered and offering `..` and Open folder for the folder shown
- **Then** Open folder accepts any absolute path, including POSIX paths, `C:/` drive roots and native UNC paths (a bare `C:` is not absolute), and opens the directory the server resolves it to; a typed path loses surrounding spaces while a path the server returned (found, browsed or Tab-completed) is used exactly; a folder the server rejects says it could not be opened, only while that query is still the one typed
- **Then** selecting a result opens or reopens that project immediately and closes the picker; a closed project can be removed from the history until it is opened again; late search or browse replies never replace newer ones; actions run one at a time and a change of server dismisses the picker

### V2 grouped session catalog

- **Given** the v2 session catalog has loaded sessions while the project contexts cannot be read
- **When** the server attributed them to projects
- **Then** the list groups them by the canonical directory the server reported, scoped by the endpoint host; the groups follow the order the server returned and the rows inside a group keep the server's order
- **Then** a session the server did not attribute to a project keeps a clearly marked group, and no project is invented for it
- **Then** the group header shows the reported directory with its last segment as the title, the path is always read left-to-right, and the header carries no count
- **Then** the grouping follows the rows the server just returned after a live re-read
- **Then** a session the endpoint moved to another location changes its group with the next re-read

### V2 session lineage

- **Given** the v2 session catalog has loaded sessions whose records name a parent session
- **When** the list is drawn
- **Then** a session whose record names a parent is a child and is never a row: not in a project's list, not in the grouped whole-server list, not in a preview and not in a search; the lineage comes only from the record's parent, a fork is never a child, and a parentage nobody proved is never treated as a child
- **Then** a group left with no primary row is not shown, and a project's conversation count names only the primary sessions its list shows
- **Then** a child is reached from its parent: the robot capsule and its pop-in, or the tool-call card in the timeline; deleting a parent still warns with the endpoint's count of its direct children
- **Then** a harness whose records never name a parent has no children, so nothing is hidden and no control is invented

### V2 session ownership label

- **Given** the v2 session catalog shows a row
- **When** the row carries an ownership the adapter proved
- **Then** the row shows that ownership's label — live shared, owned by this host, saved history or running elsewhere — under the title, in every locale and layout
- **Then** a row whose ownership is not proven, whose proof is older than the display window or already expired, and a list that is not the endpoint's current answer, omit the ownership subtitle instead of showing ownership unknown
- **Then** the list wakes up at the end of a proof's freshness window, without any server traffic, so a label never outlives the proof that showed it
- **Then** the label follows the rows the server just returned after a live re-read
- **Then** no ownership is inferred from the endpoint address, the port, the profile or the server's title, and the label never authorizes an action

### V2 session activity marks

- **Given** the v2 session catalog shows a row
- **When** the endpoint's own state proves an activity of that session
- **Then** the row shows every proved mark as an icon with a label, in this order: needs you, running, unread; the marks wrap in a narrow pane, are read by screen readers and are localized in every layout, and there is no harness badge
- **Then** running comes only from the endpoint's list of active sessions; needs you comes only from the pending permission and form lists of the open project group's directory, so a child's request marks the child row, never its parent, and a form addressed to no session marks none; unread is the endpoint's own idle marker
- **Then** a mark that was not observed is not shown: a part that could not be read, a row of a group other than the open one, and a list that is stale or behind the endpoint show no running or needs-you mark
- **Then** an execution start or a permission or form change re-reads only the activity, coalesced with the list's live re-read cadence; a re-read of the rows shows them at once and reads the activity after them, and a server switch during an activity read still reads the new server's activity
- **Then** while the app is in the foreground and a session's live pane shows it, the endpoint's view command is sent once per idle transition of that session, so its unread mark clears without the row action; a refused or lost view keeps the mark, says nothing and is not retried for that transition, and the manual mark as viewed stays
- **Then** a session whose pane is gone or whose app is in the background is not marked viewed; returning to the foreground with the pane still showing it sends the view

### V2 session row actions

- **Given** the v2 session catalog shows a row
- **When** the row's overflow control is opened
- **Then** it offers mark as viewed (only on a row the endpoint reports as unread), rename, fork from here and delete
- **Then** an action the connected endpoint's own version does not define is disabled and shows the reason, and a command already running for that row disables the control
- **Then** the unread marker is the endpoint's own: the session went idle and that transition was not seen yet
- **Then** a rename refuses an empty title locally, and the new title appears after the next authoritative read
- **Then** a delete asks for a confirmation that names the session, says the action cannot be undone and that a running turn is stopped, and warns with the real number of child sessions; the confirmation waits for that count
- **Then** a fork copies the whole session history, because a catalog row has no message position
- **Then** no command patches a row: the effect is observed by the next authoritative read, and a refused or uncertain command leaves the rows as the endpoint last answered them
- **Then** the command is checked again right before it is sent: a profile, a credential, an endpoint version, the currency of the rows or the row itself that changed while the dialog was open refuses the command
- **Then** a command whose answer was lost is reconciled by the next authoritative read and never sent again, and the list says that the command did not go through
- **Then** the unread marker follows the endpoint's own idle transitions: a session that finishes while the list is open is marked unread without a manual refresh

### V2 session creation

- **Given** the workspace has a selected saved server
- **When** the user starts New Chat from the workspace, drawer or shortcut
- **Then** the drawer closes and a local draft opens immediately, including from an open conversation; opening it sends no create and acquires no session, live lease, outbox entry or persisted tab
- **Then** the draft uses the selected project directory; without one, the user supplies an absolute directory before sending, and relative or overlong paths send nothing
- **Then** drafts keep their own text per server, harness and directory, including edits still waiting to be saved; returning to a project or reopening New Chat restores its latest text, and unreadable local records stay untouched
- **Then** catalog refreshes keep the draft visible; Settings and Back preserve its mode and text, while a different conversation leaves draft mode
- **Then** an unverified endpoint still permits a local draft; sending stays disabled with its reason until creation is available
- **When** the user sends the first message with verified command support, current credentials and a current catalog
- **Then** the draft shows the location's default agent (config `default_agent` when selectable, else `build`, else the first selectable agent), the model it runs with (its own, else the global default model) and its variant, or Auto when the model offers variants, with the same composer chips and menus as an open session; picking an agent brings the model it runs with, and picks stay local until the first send; a new draft discards defaults and picks from an earlier visit
- **Then** one create is sent with the directory and the shown agent, model and variant, after the defaults finish loading and a local attempt fence is saved; failure to save that fence sends nothing, and a second tap while sending does nothing
- **Then** the returned canonical session identity must pass a direct read before navigation; a title, time or newest catalog row never substitutes for it, and the create receipt never becomes a catalog row
- **Then** the captured message reaches that session once through the normal prompt outbox with the same local command identity; recorded admitted or uncertain input leaves the composer only if the user has not changed its text, and the workspace draft is consumed only after the outbox records it
- **Then** changing server, project or navigation invalidates the pending intent through creation, direct read and local outbox persistence, preventing any later automatic navigation or initial prompt POST; its text remains in its own draft, and a hidden draft cannot send from Settings
- **Then** once the prompt POST starts, navigation keeps its normal admission and reconciliation; reopening the workspace draft while its answer settles clears only the consumed text and preserves a later edit
- **Then** an unfinished fenced attempt keeps its workspace text and requires an explicit discard before another create; after the operation ends, even a fence left creating by a failed status write offers the uncertainty notice and discard without a restart
- **Then** creation and the bootstrap handoff are never replayed automatically, including after a restart; an uncertain recorded prompt keeps its text in the normal bounded outbox check under the existing verified same-command contract

### V2 live session catalog

- **Given** a saved server is selected in the v2 session catalog
- **When** the endpoint reports a session lifecycle change on its event stream
- **Then** the catalog re-reads the authoritative list from the head, up to the depth already loaded, and applies it as a whole; the event itself never becomes a row
- **Then** the re-read is silent: it shows no loading notice and marks nothing stale
- **Then** a burst of changes collapses into one re-read; the debounce and the minimum interval between re-reads bound the traffic, and the interval grows with consecutive failures
- **Then** a list that is catching up (a re-read in flight, a feed reconnecting) never adds a notice to the sidebar; row actions and the New Chat draft it holds say "Syncing conversations; try again in a moment.", or the read failure itself when the last read failed (#532)
- **Then** a failed re-read keeps the rows and the workspace notice at the top of the sidebar says "Syncing conversations..." (the list itself repeats no stale notice, #532), then tries again by itself after a wait that doubles with each failure, from 4 seconds up to about 2 minutes; a rate limit waits the longest, and a feed live period shorter than one whole longest wait counts as one failure whether it ends in a drop or in the feed's end, so a feed can never cycle faster than that wait, while the end of a feed that stayed live that long starts a new streak at one; a reconnect that lands during a re-read still gets its own read; nothing waits for a manual refresh (#467)
- **Then** a head read of the list that fails for a passing cause (connection, timeout, unavailable, rate limit) also tries again by itself with the same growing wait, which a retry, a recovery or a server-list reload never resets (only a success, another server, or a changed address or credential of the same server does); a server-list reload (opening Servers, pairing, a profile edit) that marked the rows as previous results or cancelled a read makes the list read again by itself when it ends: quietly, like a server change, for a list already loaded, and at once for one that failed or never loaded; a re-read cannot make the list current while its feed is down, so the list stays marked behind until the feed reconnects; a replaced credential that is usable reads the list again
- **When** the app returns from the background, the network changes, or the selected server answers again after it did not
- **Then** the list re-reads at once instead of waiting out its retry (a recovery that arrives during a read runs once that read is over, whatever its outcome, unless the credential was rejected), a list that failed to load reads again, a feed that could not open is opened again, the other open projects' reader restarts, and an open conversation the transport gave up on (degraded, or a connection, timeout, rate-limit or unavailable failure) reopens; when the trigger is the server answering again, it must have been confirmed Offline before, and only that server's conversations reopen; a rejected credential, a session gone from the server and a changed server are left for the user
- **Then** the automatic re-read obeys the same fence as a manual one: an expired or unreadable credential, a loading server list or a storage failure stops it, and a rejected credential clears the list and reports the authentication state exactly like a manual read
- **Then** a stream that ends ends the feed: the workspace notice says the conversations are syncing, the list re-reads by itself, and the successful read acquires a new feed
- **Then** the local-limit notice appears only when the server has more pages: a complete list of exactly 200 rows is not announced as truncated
- **Then** the endpoint keeps exactly one event stream: the catalog borrows the live session's stream, and a platform without the live transport keeps the catalog pull-only

### V2 live stream wake

- **Given** the app holds one or more open endpoint event streams
- **When** it returns to the foreground after being paused, hidden or detached, or the device's network route changes (a different Android transport set; on Linux a different NetworkManager primary connection or type)
- **Then** every open stream reconnects at once instead of waiting for its retry delay or stall watchdog, and the new stream hydrates from the authoritative reads; the wake itself sends, replays or creates nothing, and the reconnected stream keeps the policies of any other reconnect
- **Then** a return from the background alone keeps a ready stream that received anything, a heartbeat included, within the harness's quiet bound (OpenCode: 20 s, above its 15 s heartbeat, as its own client does on a return to the foreground), so a short trip away never reconnects; such a stream must hear from the server before that bound runs out or it reconnects then; a new network route always reconnects at once (#503)
- **Then** triggers within 300 ms collapse into one reconnect; becoming inactive (a notification shade, a focus change), the first route seen, an unchanged route and going offline never reconnect
- **Then** a stream stopped for authentication or an incompatible server stays stopped until the user retries, and a profile still being probed is left to finish its probe
- **Then** a platform without a network feed (iOS, macOS, Windows) reconnects only on a return from the background; a switch between two networks of the same Android transport may not be seen (#434), and the retry delay and the watchdog stay the floor

### V2 live session timeline viewport

- **Given** the v2 live session screen shows the resident timeline items
- **When** the screen opens
- **Then** the list lands on the newest content; the items stay in the server's order, the header scrolls with them, and nothing is invented
- **Then** a live update follows the newest content while the reader is at the bottom, whether it adds an item or makes one longer, and the follow is a single move, not an animation that trails the content; it does not wait for another screen update to happen
- **Then** a deliberate scroll by the user - a drag, a fling or a wheel - stops the follow, keeps the content where the reader put it, and offers a control to return to the newest content; a page key or a click on the scrollbar track, which move the list without any scroll direction, is the reader's too and the follow waits for it instead of cancelling it; scrolling a code block, a formula or a diagram sideways inside a row is not a scroll of the timeline
- **Then** a gesture that cannot move the list - a drag against the boundary, where the physics keep the offset where it is - is not the reader's intent: the follow goes on, and the content that arrived below is followed
- **Then** the reader's scroll keeps priority until the gesture ends: the follow resumes only when the reader's gesture ends at the bottom or the reader uses the control, even if the gesture started within the bottom
- **Then** content that arrives under a reader - a new item, or any resident item that changed, even far below the reader - marks the control, which returns to the newest content and resumes the follow; a removal, a taller header or a smaller viewport, such as an open keyboard, and the settle of a turn do not mark it
- **Then** a settled answer that does not fit the viewport is offered from its start, and it counts as read, so no control appears for it; when the next turn starts the timeline returns to the newest content; an answer that settled while the reader was elsewhere is never offered later
- **Then** the control sits at the end edge in both directions
- **Then** a second control returns to the first message: it appears above that one once the reader is at least 360 logical pixels away from the bottom and the follow is off, and it lands on the oldest row the window holds
- **Then** when an older page can still be read, that tap reads exactly one page and lands on its top, like the retained reference, waiting for the page to arrive and lay out before the landing; a reader's scroll or return to the newest content cancels the pending landing, while another press of the first-message control leaves it pending; reaching the top again pages further, and the window never pages the whole session at once
- **Then** an arrival or a growth of the extent under a reader away from the bottom recomputes that first-message control, so it appears or disappears without a scroll
- **Then** each item is rendered as before; the timeline adds only the scrolling behavior and the two controls

### V2 readable tool and shell results

- **Given** a v2 live or history timeline shows a tool call or a shell command the harness reported
- **When** the row is shown
- **Then** non-subagent tool calls and shell commands render as one lightweight compact line (at least 48 dp tall, no outer card or `Show`/`Details` button): kind icon, localized kind label (`Shell`, `Read`, `Edit`, `Write`, `Search`, `Fetch`, `Web search`, `Skill`, `Question`, or raw name for unclassified tools), optional redacted single-line primary target (`command`, `path`, `pattern`, `url`, `query`, `name`, `header`), and a compact status badge only when queued, running, failed, interrupted, timed out, or killed (clean success and shell exit `0` omit the badge; a backgrounded shell tool still running keeps `Running`); an exit without a code is never called a failure, and a non-finite exit (`Infinity`, `-Infinity`, `NaN`) is shown as reported
- **Then** tapping anywhere on the compact row opens a details dialog with the tool's status (including `Done` when inspecting), input, output and error text, or the shell's command and captured output; each value shows its first 4,000 characters or 40 lines and a Show more control for the rest, inside a scroll area of at most 300 logical pixels or 40% of the screen; oversized tool inputs or outputs (above 64 KiB JSON-escaped, 4,096 nodes, or 128 output parts — retaining primary target keys first) and oversized tool errors (above 8 KiB) keep redacted prefixes instead of degrading the session, and the dialog says when an output or error was shortened by the server or the client
- **Then** a file in a tool's output is named by its type only and never fetched; a shell's captured output is the part the harness sent (at most 64 KiB)
- **Then** credential-looking values - assignments, JSON properties and command flags named like a password, secret, token or key, authorization headers and variables, URL user info, private-key blocks and well-known token shapes - are replaced by `[redacted]` against the full source text before a value is cut and kept and again before it is shown; the rule is finite and best-effort
- **Then** a change in a tool's input, output or runtime facts, or in a shell's output or exit, is content that arrived, and an unchanged re-read is not; in the live timeline an open dialog shows the change
- **Then** an unknown shell status in history is one minimized unknown row; the rest of the page still shows
- **Then** harness-reported background shell completion reports (`Notice.shellReport`, e.g. OpenCode `<shell ...>` and `<background-result kind="shell" ...>` synthetic messages) render as compact shell rows with command, outcome/exit/timeout/killed badges and full redacted output in the details dialog, fold into activity stretches as commands, enrich matching shell entries in the robot capsule, and suppress duplicate echoes of user `!` shell runs that share a `ShellRun.shellId`; background shell tool output also strips host `PID:` / capture-file lines and OpenCode `Command cancelled` / `interrupted` shell failures project as interrupted; legacy v1-migrated tool names (`bash`, `apply_patch`, `task`) classify alongside v2 names

### V2 live session older history

- **Given** the v2 live session screen shows a session with more history than the newest page it opened with
- **When** the reader scrolls up to the top of the list (within 72 logical pixels, armed again only after moving more than 220 pixels away)
- **Then** one older page is read, 20 native messages at a time through the same continuation the opening read returned (halving the requested count automatically down to 1 if a page hits a response-size or projection budget), and a pill shows at the top while it is read; when a followed timeline's scrollable extent is at most 220 logical pixels after layout, a bounded post-layout fill probe reads up to 9 additional older pages (at most 200 native messages total) so the viewport fills without marking jump-to-newest or cancelling follow (resetting its page budget on an empty timeline or displaced pivot); the timeline's own jumps never ask for a page, and a second request while one is read does nothing
- **Then** the older rows appear above the rows the reader was reading, and the row the reader was reading keeps its place on the screen; an older page is history, not new content, so it never marks the control that returns to the newest content and never resumes the follow, while a live row that lands at the same time still does; an overlapping tail re-hydration preserves the resident older prefix, continuation cursor, and untrimmed coverage, while a disjoint re-hydration with no pending input replaces the stale window cleanly
- **Then** the window keeps at most 500 rows and never drops the newest to make room: a page that would pass the cap loses its own oldest rows, and paging stops there; it also stops once the window lost rows in front, because the next page would skip them
- **Then** when the window cannot page in more - it is full, it lost rows in front, or a live and current window is refused another page - the top of the list says that the local history limit was reached and offers the read-only history viewer; a window that loaded its whole history, or one paused while not live, offers nothing there
- **Then** a failed older page keeps the rows and the place and offers a retry at the top of the list without degrading the live session; routine child or manual refreshes coalesce without consuming the per-generation error-repair budget (3 strikes), which resets after 30 seconds of clean healthy hydration or a clean settled turn, and a genuinely live snapshot clears any stale degraded banner; closing the screen while a page is read never leaves a closed or failed state behind for the next screen

### V2 auxiliary read-only history

- **Given** a loaded session row is expanded in the v2 catalog
- **When** the user explicitly opens its history
- **Then** an auxiliary screen covers the shell navigation; Back returns to the existing catalog and selected profile without changing the router location or pending opaque session intent
- **Then** native reads use the current profile-bound credential and preserve the endpoint port and proxy prefix; an authenticated info probe observes the actual server version before every history page, and version drift invalidates the continuation until manual refresh
- **Then** server order and complete session/item identity are retained; each request reads at most 50 native messages, permits at most 500 projected items and retains at most 500 items or ten accepted pages, with an explicit local-limit notice beside pagination
- **Then** refresh and pagination remain manual; cancelled, superseded, expired-credential, reloaded-profile or disposed work cannot publish late history, and authentication rejection clears previous content
- **Then** plain text previews are limited to 2,000 Unicode code points and 16 lines; tool and shell rows follow the readable-results rules below; outcome and unknown entries stay minimized markers, without rendering raw metadata, fetching content references or executing actions
- **Then** live state and delivery remain explicitly unverified and the composer slot is inactive; this reader does not enable live events, sending, lifecycle mutations or approval responses
- **Then** compact/wide and localized layouts are technical coverage only; the final appearance/navigation parity with v1, full timeline and installed/MVP acceptance remain separate requirements

### V2 live session composer

- **Given** a live v2 session screen opened on native Android/Linux against a verified OpenCode 2.0.22 server, with device storage for the prompt ledger
- **When** the lease is live and current (not reconnecting, hydrating or stale)
- **Then** the composer sends plain text with steer by default; holding Send, a right click there, or the Menu key or Shift+F10 in the composer chooses steer or queue as the default for every later send, kept on the device; the Steer and Queue chips are gone
- **Then** each deliberate send is one new command; a second tap, or the same text while its send or automatic check is in flight, sends nothing, and the field is read-only until the send ends
- **Then** the field clears only once the prompt is recorded as admitted or not confirmed; refusals and rejections keep the text with finite localized copy and never show raw server reasons
- **Then** a send whose response was lost is checked once automatically under the same id; entries restored from an earlier run are checked only by the user (Check again); "Send again (may duplicate)" forgets the old command first and hands the text back if the new send does not go
- **Then** each prompt the harness holds but has not delivered yet (#486), this device's or another client's, queued or steering, is a user bubble pinned after everything else in the timeline (#502), oldest first, scrolling with it: nothing waits above the status bar; its fill is fainter than a sent prompt's and slowly breathes (held still with reduced motion), and screen readers hear it as queued or steering; once the harness delivers it (OpenCode: `session.inbox.delivered`) it becomes an ordinary prompt in the place history gives it, after everything that arrived while it waited, with no second copy; a cancelled prompt is never shown
- **Then** a waiting prompt offers no action: no Cancel, no Send now, no take-back to edit, by deliberate owner decision (#502); the code keeps a commented hook for a Cancel link at the bubble's bottom end, and the prompt ledger keeps its cancel and take-back paths behind it: a take-back that settles as cancelled puts the text into the session's draft after anything already there, once, never while a send runs or before the saved draft is read, and the ledger forgets it only after the draft store wrote the draft holding it (a draft the store refuses, unreadable or over 128 KiB, keeps it on screen only); a cancelled take-back is never evicted from a full ledger
- **Then** during the resume grace the composer stays as when live, once the session's revert state is known: the field, **+**, the mic and Send work and no hourglass or recovery shows, except while a pick taken in the grace waits to be switched, which holds Send like any switch; a prompt sent meanwhile stays in the field until the conversation is current again. If the refreshed view has a staged revert, the draft stays editable and the user must tap Send again. Otherwise the message goes out and then waits pinned after the conversation until the session reports it, as a queued prompt would (#503, #502); one the conversation is not current for within 7 seconds is not sent, keeps its text and shows the connection status
- **Then** a waiting prompt is found by conversation search; one this device sent shows its own text and attachments, also once delivered until a history read brings them, and what belongs to its message (such as its context) waits, leaves or joins the conversation with it
- **Then** a harness without a queue reports no waiting prompts and shows none; this device's sends that failed or are not confirmed keep their line above the status bar with Check again, Send again (may duplicate) and Discard; one the harness already lists as waiting keeps only Check again, since sending it again would duplicate it and forgetting it would not cancel it
- **Then** an unsent draft survives a reopened lease (and tabs and relaunches, see V2 session drafts and input history); an unreadable ledger disables sending with a re-read action; without storage, a verified version or on Web the screen explains that prompt sending is unavailable, without claiming the view is read-only while permission cards can still reply
- **Then** compact, landscape and wide layouts in all 14 locales (RTL for Arabic/Urdu) are technical widget coverage; installed native acceptance remains separate

### V2 session drafts and input history

- **Given** a v2 session open in the workspace on a device with storage
- **When** the user types in a session's composer
- **Then** the text is that session's draft, keyed by its full identity (server, harness instance, session): switching tabs, closing and reopening its tab (Undo included) and killing and relaunching the app bring it back; another session, or the same session id on another server, has its own
- **Then** the draft is saved within 0.5 s of typing and at once when the app leaves the foreground or the session's view closes; text typed before the saved draft was read wins over it
- **Then** an accepted send clears the field and the saved draft, also when the send ends after its tab closed, and a reopened tab still showing that prompt drops it; a refused or rejected send keeps both
- **Then** at most 32 drafts are kept, the one saved longest ago removed first; a draft above 128 KiB stays in the field and the last saved one is kept; a saved draft this version cannot read is never written over, and drafts recovered from v1 are left untouched
- **When** the user presses Up on the field's first line, or Down on its last, with a desktop keyboard and no modifier, selection or composition
- **Then** once the saved draft was read, Up shows the session's previous sent prompt (its own, trimmed, newest 100) and Down the next one; on a recalled prompt the first Up moves the caret to its start, and Down past the newest gives back what was being written
- **Then** a recalled prompt is not saved as the draft; editing it ends the browsing and makes it the draft; a phone has no recall gesture, as in v1

### V2 live session execution state

- **Given** an open native v2 session on a supported OpenCode 2.x server
- **When** the conversation status bar shows the session's execution
- **Then** retrying, stopping, interrupted by a server shutdown ("Interrupted; continuation not confirmed", never a claim of restart or resume), needing input and idle each have their own label, in the bar's order; the last outcome shows only while idle and never while an interruption is shown, when it is the previous turn's result
- **When** the server ends the running step as aborted (a shutdown or a Stop)
- **Then** the timeline shows "Response interrupted." after the partial output, live and in the history with one identity, without the server's message; it never becomes a turn outcome or changes the execution state, and a Stop also keeps its "Last turn interrupted" row
- **When** a run seen live in this screen reads idle with no new outcome (no outcome row, and no new result in the same read), for example after a restart with no report
- **Then** the status bar says only "The execution is not active; its outcome is unconfirmed." (or the shutdown label if a shutdown was seen) for that prompt; it never stops, sends or resumes anything, clears when a new run or outcome arrives or another prompt is sent, and is not repeated while the timeline already shows the interruption for the latest prompt; a cold open, a stale or reconnecting view and an unknown state never raise it
- **When** the server schedules a retry of the current step
- **Then** the label reads "Retrying in m:ss" (hours as h:mm:ss), counted down from the deadline the server reported and never longer than the server's own delay counted from arrival; a deadline already past, or one unknown after a reconnect, reads "Retrying" or the hydrated running state
- **Then** the count ticks once per second only while the screen is shown and the app is in the foreground, and catches up when it returns; the retry's error type is kept, its message is never shown
- **Then** the next step start of that execution returns it to running, and any execution end clears the wait
- **When** the session's direct sub-agent sessions run, including after the session itself went idle
- **Then** the status bar shows "Sub-agents running: n" instead of the session's own idle state; a sub-agent's start adds it, any end of its execution (a server shutdown too) removes it, and opening or reconnecting the session counts the ones the server lists as running
- **Then** only the children the session already follows are counted: direct children, within the existing per-session bound, never by watching them separately
- **Then** retry coverage is contract-derived (no natural 2.0.22 retry capture) and includes the 2x-text labels in Arabic and Portuguese; the sub-agent count replays the observed background-child capture; installed native/MVP acceptance remains separate

### V2 live session Stop

- **Given** an open native v2 session on a supported OpenCode 2.x server with a live, current, known-running or retrying execution
- **When** the composer draft is empty
- **Then** its trailing Send action becomes Stop; typing keeps Send, the delivery choice opens from Send (hold, right click, Menu key, Shift+F10), and Stop never clears the draft or partial output
- **Then** two unmodified Escape presses within 500 milliseconds while the input is focused also request Stop; the first shows a hint, and composing text, repeated keys and modifiers do not trigger it
- **When** Stop is deliberately requested
- **Then** exactly one session-scoped interrupt request is sent, without a body or resume query; it neither resumes parked input nor cancels inbox entries or other sessions
- **Then** the shared session lease fences duplicate requests across screens and temporarily disables competing composer mutations; Stop remains available without prompt-ledger storage
- **Then** an accepted `interrupted:true` means only that interruption was requested, while `false` is a confirmed idle no-op; neither response changes canonical execution state
- **Then** missing, malformed or lost responses show finite unconfirmed copy and never replay automatically; a later deliberate Stop is a new action against whatever execution is current
- **Then** the HTTP attempt is bounded to 20 seconds and the post-accept wait to 30 seconds; only an authoritative live, non-stale idle observation settles the wait, including after an unconfirmed result; a retry wait or a pending resume keeps it waiting
- **Then** reconnect hydration that merely reconstructs an earlier outcome does not settle a still-running request; a missed terminal followed by a running successor keeps the conservative bounded wait
- **Then** idle/refused notices describe that request, and stream/hydration remain the only source of execution and turn outcomes; closing, credential changes and lease release never initiate a remote Stop
- **Then** technical coverage includes compact/landscape/wide composers in 14 locales and storage-less compact/wide Stop; installed native/MVP acceptance and child controls remain separate

### V2 live session model and agent

- **Given** an open native v2 session on a supported OpenCode 2.x server
- **When** its live page opens
- **Then** while sending waits for the live view to become current, Send shows a static package hourglass and the status bar alone explains loading; the redundant sending-resumes notice is omitted
- **Then** Send shows an upward arrow, or a check with the tooltip `Idle` while the session idles and the field holds no text (beta.21, see the status bar's idle item), and the composer's open row shows one chip with the model and, after it, its variant, on a wash of the current agent's color (35% over the surface, beta.21), with black or white text for contrast; catalog labels name the session's own selection, and a missing half is the server default; a session without a model of its own names the model the server runs it on, as the server resolves it: the effective agent's own model (the configured `default_agent` when selectable, else `build`, else the first agent, for a session without an agent) when the location offers it, with its variant when that model lists it, else the location default from `GET /api/model/default`; while the model, agent or config read fails, or no default is known, it shows "Default"; the model's tooltip and semantics retain the whole selection and any pending, unconfirmed or changed-elsewhere status
- **Then** the session record supplies the selection, and `session.model.selected` / `session.agent.selected` keep it current; the model reference keeps its provider and variant together
- **Then** the location's models and agents are read once per live period with `GET /api/model` and `GET /api/agent` scoped to the session's directory, together with `GET /api/config`, `GET /api/model/default` and `GET /api/provider`, and again on an explicit refresh, when the pick opens, when the session moves to a different directory (`session.moved`), and when the server reports `model.updated`, `agent.updated`, `provider.updated`, `integration.updated`, `config.updated` (for that directory) or `credential.updated` / `credential.switched` (a directory-scoped report without a location is ignored, as in the official client); the last three reads only name things, so their failure never makes the pick unavailable; only enabled models, their variant ids (never their settings) and non-hidden primary or all-mode agents are offered, and a value the list does not hold stays visible as not offered here
- **Then** a missing route, required authentication, an unreadable or oversized answer, a failed read, an empty list or a session without a location is reported per half; when neither half can be offered for a reason a retry would not change, the chip stays as a non-interactive affordance whose tooltip and semantics give the reason, and nothing is faked
- **When** the user picks a model, a variant or an agent
- **Then** during the resume grace (see V2 conversation status bar) the chip and the pick stay usable while the stream comes back, if the session could switch when it was last live; a pick is switched once the stream is live again, also if that takes longer than the grace, and until then it holds Send and the next pick, as a switch waiting for its report does; nothing is sent meanwhile (#503)
- **Then** the pick closes and sends exactly one `POST /api/session/<session>/model` or `/agent`; one switch per session is in flight, that session's sends wait for it, and other sessions stay independent; the prompt never carries a selection
- **Then** an accepted switch shows at once and holds until the server reports a newer selection, and the next pick waits for that report, while the chip's tooltip and the pick say it is waiting for the server to confirm; a pick made while the session lost the ability to switch (the pick still open) sends nothing and says the change was not applied; a refused switch changes nothing and says so; a switch reported and then replaced by another client, before or after its answer, says it was changed elsewhere
- **Then** an uncertain answer is never resent: a switch the server already reported settles at once, otherwise one read of the session record settles it as applied or not applied; a failed read keeps it unconfirmed, and the session's sends wait until Check again, a newer server selection or a new pick settles it
- **Then** closing or releasing the lease never switches anything
- **Then** a sub-conversation's chip shows its inherited model and variant disabled, with a lock
- **Then** each mid-session switch of model or agent leaves a small note at that point of the conversation, live and in history (#426): "Agent switched to Plan" with the agent's color dot, or "Model switched to Beta high" with its variant, named from the session's catalog or by the reported id; OpenCode records each switch as a message (`agent-switched`, `model-switched`), and the live event (`session.agent.selected`, `session.model.selected`) makes the same item, so reading the history again never duplicates it; a harness that does not report switches shows no note
- **Then** the agent's color is the harness's own when it names one (OpenCode: the agent's configured six-digit hex; `#aaaaaa`, which its v1 migration writes for a theme name, means none); otherwise CodeWalk's: green for the default agent (a session without an agent of its own, or `build`), hot pink for `plan`, and for any other a palette color chosen by its id alone, so it keeps it across screens and projects; the new chat's chip follows the same rule
- **Then** technical coverage includes contract-derived loopback race tests, the chip in 14 locales at compact and wide sizes, 2x text at 360 dp, and the bottom sheet and dialog; no live 2.0.22 switch capture exists yet (#425), and installed native acceptance remains separate

### V2 model picker, favorites and recents

- **Given** an open native v2 session on a supported OpenCode 2.x server that can switch its selection
- **When** the user taps the composer's model chip, or runs `/model` or `/agent`
- **Then** all three open the same single pick (#485), with no visible title so the lists keep its room, though a screen reader still hears "Model and agent" as its name (beta.21): models and their variants first, agents and the permission mode in its footer; it opens as a bottom sheet below 600 dp and a dialog otherwise, with a search field; a search ignores case, punctuation and spacing ("gpt 6" finds "GPT-6.2") and lists every match once, best first (the name or id itself, its start, the start of its words, anywhere in it, every word with the provider id or name, then its letters in order; a favorite leads an equal match), each row naming its provider, and no match says "No models found" (#515)
- **Then** this server's **Favorites** come first, then this project's **Recent** models, then the other models grouped by provider, each model listed once (#515); a favorite or recent the session's location does not offer is not shown, a favorite is not repeated among the recents, and outside its provider's group a row names its provider; providers the harness ranks come first in its order (for OpenCode its Web client's: opencode-go, opencode, anthropic, github-copilot, openai, google, openrouter, vercel), then the others by name; inside a provider free models come first, then the newest release, then undated models in catalog order; a retired (`deprecated`) model is not offered anywhere, favorites, recents, search and `mod+m` included, unless the session runs it; of the dated releases of one family (per provider and price) only the newest are listed (releases of the same instant, such as one model in several regions, all stay), the older ones still found by a search; favorites, recents and the session's own model always show, and a model without a family or date stays listed; providers are named by `GET /api/provider` (`Provider.Info.name`), or by their id when the location does not name them, in this picker and in the new-chat picker
- **Then** a model is marked **Free** only when the catalog states one untiered price of zero (`Model.Info.cost`, USD per million tokens); a priced, tiered, empty, absent or unreadable price shows no badge, and an unreadable price never fails the catalog
- **Then** the star on a row adds or removes a favorite without picking the model, and is filled while the model is a favorite; in the bottom sheet (below 600 dp) the star is gone to leave the row its room: a long press on the row adds or removes the favorite without picking it, also while the session cannot switch right now (as the dialog's star), a favorite carries a yellow bar on its start edge (tuned to the theme), a two-second toast inside the sheet says "Added to favorites" or "Removed from favorites" once the record saved it (nothing when it could not; only the latest change is said), and a screen reader gets the same add or remove action on the row (#516); favorites are kept on this device per server (shared by its projects, at most 64 per server), and recents per server and project, newest first, at most eight
- **Then** a model joins the recents (followed by the model switched away from) only after a switch this view sent and the server took, including an unconfirmed switch once a later read or report on the same connection confirms it; a switch that was not sent, a refused or not-applied one, or one replaced by a newer pick records nothing, and stars or recents never send a switch
- **Then** a record that cannot be read is never overwritten: the stars stay disabled and the picker says favorites and recent models cannot be saved; a failed save changes nothing and says the same
- **When** the user picks a model or a variant
- **Then** tapping the session's current model keeps its variant and sends nothing; another model is switched to with the variant last used with it on this server, in any project or a new chat's draft, favorite or not (a record from before #547 answers with its newest project's), when the model still lists it, else with the server's default variant (#547); a model that lists variants has a compact variant menu on its own row, which picks that model with that variant; inside the open menu a known effort level shows an icon before its name (none and minimal, low, medium, high, xhigh as a filling clock, max as a thinking head, ultra as a celebrating person, matched ignoring case), while Auto and other variants keep an empty slot so the names align and the closed button stays text only (#526); and **Auto** is the one choice that clears a chosen variant, written "Auto" in every language like the untranslated variant ids beside it (#517); picking the current model and variant again only closes the pick
- **Then** the composer's chip shortens a long model name by an ordered table kept in one place for periodic review (#524): Claude's family names the model ("Opus 5.5"), GPT and Gemini 4 codenames keep their version ("6.2 Sol", "4 Neon"), "Flash Lite" becomes "Lite", "Muse Spark 1.3 Contributor" becomes "Spark 1.3", "(latest)" and active-parameter counts ("A22B") go, an `antigravity-` id becomes "AGY …", MiniMax, Kimi, DeepSeek ("DS") and Nemotron ("Nemo") lose their brand, "Highspeed" becomes "HS" and "Instruct" "IT"; a "Free" or "(free)" of its own (not "Freezer", "(Free Preview)" or a hyphenated id) leaves the text for a no-cost icon before the name, where an ellipsis never cuts it, and a separator a removed part leaves at an edge goes too; total parameter counts, "Preview" and snapshot dates stay, a name the table would empty stays whole, a default named `name#variant` keeps its variant as is (a `#` followed by spaces belongs to the name), and the chip's tooltip, its screen-reader label, the search and the pick keep the full name
- **Then** the composer's chip names no variant when none is chosen (Auto); a chosen variant the model no longer lists can still be cleared with Auto in the current model's menu
- **Then** technical coverage includes adapter price- and release-projection tests on the 2.0.22 fixture, pure pick-ordering and search-ranking tests, store persistence/bounds/unreadable tests, picker widget tests, and compact, RTL and wide picker goldens; installed native acceptance remains separate

### V2 model, agent and variant cycling

- **Given** an open native v2 session that can switch its selection, with the composer or another control of its page focused
- **When** the user presses `mod+m`, `mod+t`, `alt+shift+j` or `alt+shift+k` (the existing bindings, unchanged)
- **Then** `mod+m` moves through this server's favorite models, then this project's recent models, then the current provider's models, each with the variant last used with it as a pick takes it (#547); `mod+t` through Auto and the current model's variants; `alt+shift+j` and `alt+shift+k` through the agents forward and backward
- **Then** the first press goes back to the item used before the current one, like Alt+Tab; presses within 3 seconds continue through the order taken at the first press, most recent first and not limited to two; a longer pause starts over; without two remembered items the press steps through the items in order
- **Then** each press sends one ordinary switch through the session's selection fence; a press while a switch is pending or the lease cannot switch does nothing, and a sub-conversation offers no cycling
- **Then** the recents remember the item switched away from after the new one (models and agents per server and project, variants per model), so the first press can go back to it
- **Given** the user switches to an agent that last used another model in this project (on this server)
- **When** the server takes the agent switch without changing the model itself
- **Then** once the server has reported the agent switch and a next switch can be sent, that model is switched to as well, with its variant only when the model still lists it; a model the location no longer offers is not restored
- **Then** any model change seen since the agent switch began (by the server with the agent or by another client, even one set and then set back), a refused or not-yet-confirmed agent switch, a newer pick or a new connection cancels the restore; the agent left keeps the model it was using
- **Then** technical coverage includes the cycle state machine with an injected clock, controller tests for each domain and for the agent memory, and a `ctrl+m` composer shortcut test; installed native acceptance remains separate

### V2 in-app messages and safe Enter in dialogs

- **Given** the v2 app shows an in-app message (a copy confirmation, a failed action, an undo offer, a server warning)
- **When** it appears
- **Then** every v2 message goes through one snackbar path, so the same event is never shown twice as a toast and a box
- **Then** on a compact window it is a floating toast without a close icon; on a wide window it floats beside the end edge (at most 420 dp wide, 24 dp from the edge, on the left in right-to-left languages) with a close icon
- **Then** a message without an action closes as soon as it is tapped; a message with an action (Undo, Check again, Servers) keeps that action, and its text, duration and placement are unchanged
- **Given** the server edit dialog or the add-server screen is open with a physical keyboard
- **When** the user presses `Enter` or `NumpadEnter`
- **Then** a focused control that activates itself (Cancel, Check connection, a row) does so; otherwise the dialog's Save runs, only when Save itself is enabled
- **Then** delete confirmations, shortcut capture, pickers and selectors never map Enter to their action; renaming a session already confirms with Enter in its field
- **Then** technical coverage includes snackbar tests at compact and wide widths in both directions, a source check that keeps one snackbar path, and Enter, NumpadEnter and focused-Cancel dialog tests; installed native acceptance remains separate

### V2 loading indicators and code scrolling

- **Given** the v2 app shows progress whose amount is unknown (ADR-062, superseding ADR-056, #510)
- **When** it runs on Android, iOS, Web, Linux, macOS or Windows
- **Then** every platform renders the native continuous indeterminate animation across all sizes (including compact rings and updater indeterminate bars routed through `AppIndeterminateBar`), paused automatically when hidden by `TickerMode`, while reduced motion switches every platform to a static glyph or bar with zero scheduled frames
- **Then** screen readers receive a loading role and the indicator's label without a made-up percentage; unknown HTML progress follows the same rule, and HTML progress with a known value keeps its real value

- **Given** a fenced code block is wider than its viewport
- **When** the user reads it on desktop
- **Then** its horizontal scrollbar appears on hover, focus or scrolling and supports thumb dragging; unmodified Left/Right move by a bounded step and Home/End reach its limits, while modified selection shortcuts keep their meaning
- **Then** only overflowing code adds a tab stop and bottom gutter; each block keeps its offset through content changes and clamps it when the content shrinks
- **When** a vertical wheel reaches tall code inside a chat that can scroll
- **Then** the chat scrolls vertically, a diagonal wheel also moves the code horizontally, and mouse axis modifiers such as Shift keep their normal horizontal-wheel behavior
- **Then** standalone tall code keeps its own vertical wheel and mobile touch scrolling, and the code height remains bounded
- **Then** technical coverage includes cross-platform continuous animation, `TickerMode` pause/resume, reduced-motion static fallback and loading semantics tests, a source check forbidding direct unguarded indeterminate `CircularProgressIndicator`/`LinearProgressIndicator` use, HTML progress, and real parent-chat, mouse-thumb, keyboard, modifier, diagonal and standalone scroll tests; installed native acceptance remains separate

### V2 typed turn error cards

- **Given** a native v2 session on verified OpenCode 2.0.22 whose turn ended with `session.execution.failed`, live or in the read-only history
- **When** the timeline shows that failed turn
- **Then** its outcome row becomes one typed error card instead of the plain "Last turn failed" marker: authentication, rate limit, quota, context, provider, network, content filter, version or unknown, each with its own localized title, explanation and icon
- **Then** the category comes only from the exact error `type` (`provider.auth`, `provider.rate-limit`, `provider.quota`, `provider.free-limit`, `provider.go-limit`, `provider.budget-limit`, `provider.model-budget-limit`, `provider.content-filter`, `provider.transport`/`timeout`, the other `provider.*` types, `compaction.*`); permission, tool, unrecognized and future types use the unknown card; the HTTP status, the response body and the message text never pick a category and are never shown
- **Then** the server's message, when it is text, is shown as plain selectable text in a bounded scroll area, redacted and kept within 8 KiB with a note when it was shortened; no message shows "No details were reported.", so an unknown error never reads as nothing, zero or success
- **Then** an `aborted` end is an interruption, not an error: it keeps the plain failed marker without a card
- **Then** the history attaches the error carried directly on the `idle` row (OpenCode 2.3+) or, when absent, the error of the turn's last assistant message to the turn's failed `idle` row, so live and history show the same card; an error on an older page than its `idle` row keeps the plain marker, and a failed step no longer shows an unavailable-part marker
- **When** the card offers its one recovery
- **Then** a live card offers "Choose another model", which opens the model-and-agent sheet when that sheet can open now; a server-version card offers "Open servers" (that card is reserved for a canonical version error: no 2.0.22 error produces it); any other case, and every card in the read-only history, has no button; no recovery resends a prompt, signs in to a provider or retries on its own
- **Then** technical coverage includes every 2.0.22 type, the 4 captured `provider.auth` failures replayed live and from history with the same card, the captured `provider.invalid-output` history error, and the card at compact and wide sizes, right to left and with 2x text; the other types are schema-derived, and installed native acceptance remains separate

### V2 manual permission replies

- **Given** an open native v2 session on a supported OpenCode 2.x server whose lease holds a reply port
- **When** the session has a resident permission request
- **Then** the live footer shows one card per request with its native title and resources, and offers an action only for a choice OpenCode itself accepts: `once`; `always` only with a non-empty, in-bounds pattern preview; `reject` with or without a verbatim note
- **Then** a request whose native choices include anything else is shown without actions, because one non-native choice makes every reply for that request unsupported
- **Then** one deliberate tap is one `POST /api/session/<session>/permission/<request>/reply` on the same verified stream, carrying the native decision and, for a noted rejection, the text exactly as typed; an empty note disables its own send
- **Then** the per-request fence is shared by every screen of that session and keyed by session plus request id, so a second tap or another screen's tap sends nothing while one reply is in flight, while equal ids in different sessions stay independent
- **Then** a `204` is only an admission: no card is removed by it, only the stream or a hydration settles the request, and a lost, malformed or unlisted result stays unconfirmed with finite localized copy and is never replayed automatically
- **Then** a `404` from a reply indicates that the request was answered elsewhere or is gone (`livePermissionAnsweredElsewhere`), triggering a single state refresh and never resending automatically; reject-and-stop sends a note-less rejection without requesting an execution Stop
- **Then** a card stays mounted with its actions disabled while the lease is not live or current, so a typed note survives a reconnect or an explicit retry and is dropped only when the request leaves canonical state
- **Then** the patterns a persistent `always` would grant are shown in full, the footer partitions cards and composer with a usable composer floor (never overrunning a short body, the safe-area inset or a Stop control), and the read-only prompt line is not shown while only replies are available
- **Then** a resident request whose only native automatic choice is `once` is answered once without a tap on the same stream, only for a session whose lease is open and whose view is live and current, and only while its switch is on: once the session's own rules are read, that means their trailing allow-everything rule is in effect (nothing is answered while they are unread or being read again, and a known off answers nothing whatever the local mode); where the harness has no readable rules or the read failed, it means the local policy at Allow all (the default for a new install); forms, questions, plan approval, installation consent, project trust, `requiresInput` and any unknown or non-`once` choice stay manual
- **Then** a deliberate reply latches that session and request in the directory, so a later frame, a second screen or a closed and reopened session never answers it again, while the card stays available for a manual retry; the automatic path never sends `always`, a note or a wildcard
- **Then** a policy that cannot be read or parsed opens no approval at all, an unreadable per-session override blocks writes instead of being overwritten, and a mode only takes effect after it is persisted
- **Then** the live page has no permission control of its own: the switch in the single pick of model, agent and permissions is the only one (#494); a sub-conversation, whose pick is locked, has none yet (#495)
- **Then** the local mode, used only while the server's rules are not known, is written as a session override and takes effect only after the write; turning a watched, live session's switch on answers its already-resident eligible `once` requests at once through the same gate and fence, while turning it off never sends anything and does not revoke a reply already in flight
- **Then** where the harness exposes readable session rules (OpenCode), the switch is the session's allow-everything rule on the server (ADR-059 as amended for #494): turning it on reads the session's rules, stores a fingerprint record of CodeWalk's insertion (replacing a stale one), appends `{action:"*", resource:"*", effect:"allow"}` once through `PATCH /api/session/<session>` and shows on only after a new read confirms it; there is no confirmation dialog, and the switch carries no explanatory subtitle (owner, #518)
- **Then** CodeWalk's record of its insertion belongs to the server binding it was written through (the server, its full URL and its binding revision): after a URL edit the other server's identical rule is shown as set outside CodeWalk and never removed, and records written before this scoping are kept but never claimed
- **Then** a read or write that loses its server binding, or that was in flight while the server catalog was being reloaded, stops without sending anything more; the screen keeps its last known state, a change that was not sent is reported as not made, and one already sent keeps its receipt as unconfirmed until a fresh read
- **Then** turning it off reads the rules right before writing and removes the trailing allow-everything rule whoever added it (another device or client included), keeping every other rule, another client's deny rules included; a rule that is no longer last shows as off and can be turned on again; a refused write sends nothing more and is said under the switch, and an unknown outcome is checked by one read and never resent
- **Then** a session CodeWalk creates gets the rule before its first prompt while the default is on, waiting up to 3 s for the first read of its rules (a failed first read is retried within that wait); a session started in another client keeps the server's word and is written only when its switch is flipped
- **Then** the rules are read when the session is live and current (on open and after each reconnect, with one retry of a failed first read), around each change and on an explicit refresh; live `session.permissions` SSE stream events reconcile rules in real time (deferring re-read when busy); a failed or unreadable read makes the actions unavailable but keeps showing a rule already known to be in effect, a ruleset at the 1024-rule local bound is never extended, and unreadable overrides have no in-session repair surface yet
- **Then** sub-agent permission requests (SessionOwner with origin matching the parent) appear directly in the parent session's resident permission cards alongside the parent's own requests; cards are ordered with the parent's own requests first, followed by child requests grouped by sub-agent in order of first appearance, with child requests badged with a Sub-agent badge and arrow icon; manual replies post directly to the child session's reply endpoint `/api/session/<child>/permission/<request>/reply`; the reply fence, reply states, and note drafts are scoped per owning session; where the server's rules hold the switch, a child's request is answered automatically only when the child's own rules have been read and are in effect (a child whose rules are not read, or whose lease closed, stays manual), and only where the rules cannot be read the local precedence (fail-closed, explicit Ask on either parent or child vetoes auto-approval, child explicit mode override wins, otherwise the parent's effective mode), evaluated symmetrically when watched in the parent card or directly; watching both parent and child concurrently deduplicates replies via the shared `(owningSession, requestId)` fence so only one reply is sent; late 404 (first-reply-wins) is mapped to answered elsewhere and triggers a single state refresh
- **Then** technical coverage includes the card surface in 14 locales at compact and wide sizes, fence isolation across sessions, poisoned choices, note drafts, footer budget at short and hydrating bodies, and the slot-level `204`/`404`/`5xx` mappings; installed native acceptance remains separate

### V2 rich timeline rendering

- **Given** a v2 history or live timeline item with canonical text (`UserInput`, `AssistantText`, `Reasoning`, `Notice`)
- **When** the shared `SessionTimelineTile` builds its body
- **Then** `AssistantText` renders GFM Markdown with basic HTML (`b`, `i`, `u`, `br`, `sub`, `sup`, `progress`), LaTeX math (`$...$`, `$$...$$`), fenced code with syntax highlighting and a Mermaid diagram card with raw-source fallback; `UserInput`/`Reasoning`/`Notice` render the same Markdown/math/code without raw HTML (unsupported tags stay safe and never execute)
- **Then** the running text of the user's and the agent's messages (paragraphs, lists, quotes, tables and inline code, backticked file paths included) is one step larger than the app's body text, 16 sp instead of 14 sp (#489), and the Conversation text size multiplies it; fenced code blocks, headings, reasoning, notices, tool output and the composer keep their sizes
- **Then** a `progress` bar takes the full width of the message's column on a line of its own (#493), determinate, indeterminate or held still under reduced motion, with its label for screen readers
- **Then** tables match v1: a rounded themed border, a bold header row on the raised theme surface and intrinsic column widths; a table wider than the message scrolls horizontally inside its own bounds, and cells keep inline formatting and links
- **Then** images remain text without network or file I/O; tapping a Markdown link (including GFM autolinks, `http`/`https`, scheme-relative `//`, bare `www.` and `mailto:`) inside live or history timelines (messages, reasoning, light notices and subagent reports) opens it externally after scheme validation, while invalid or disallowed schemes (`javascript:`, `file:`, `data:`, relative paths) and failed launches show the localized "Unable to open link" snackbar; file paths keep their callbacks; `TurnOutcome` and `UnknownItem` stay minimized markers without exposing `raw` or fallback text; `ToolCall`, `ShellRun` and background shell reports (`Notice.shellReport`) follow the readable-results rules below
- **Then** sources above 64,000 runes fall back to plain truncated text with a localized notice; code blocks above 8,000 chars render as plain monospace; malformed math/Mermaid degrade to selectable raw source without crashing
- **Then** streaming re-parses are throttled (120 ms desktop, 48 ms mobile) and settle on completion; the 2,000-item history builds lazily without exception
- **Then** compact/wide, 14 locales with RTL, SelectionArea, semantics headers, 200% text scaling, reduced-motion static progress and VM goldens (mobile/desktop light/dark + ar RTL) are covered by widget tests; keyboard focus on overflowing code remains pending and is not claimed as passing
- **Then** `flutter analyze` passes with no new issues and focused v2 rendering/timeline/history/live tests pass; `dart run tool/ci/import_rules.dart` was not run for this stage (known >20 min, issue #375) with manual G4 verification (no legacy imports, no `part of`, new files <500 lines)

### V2 compaction notices

- **Given** a verified OpenCode 2.0.22 session compacts its context, including a compaction started from another client
- **When** history or the durable stream reports its state
- **Then** one canonical compaction notice keeps its identity from running to completed or failed; completion shows the complete summary, and failure uses the bounded, redacted error message; optional trigger (`automatic`/`requested`) and compaction token usage are preserved on `Notice.compaction` when reported (#520)
- **Then** every compaction notice (automatic or manual, live or history, including streaming in Block render mode) renders as a unified centered hairline divider with a 48 dp height—never a generic "Details" card: running shows a spinner (`Compacting context…`), completed shows `Context compacted` with its Markdown summary and optional trigger/usage counts collapsed until tapped, interrupted shows `Context compaction interrupted`, and failed shows an error-styled divider expanding the bounded redacted plain error text (#520)
- **Then** partial summary deltas, opaque provider state and the recent-context copy never appear in that notice; a future status stays an explicit unknown item
- **Then** replaying an old terminal never completes a newer notice with a known different event identity; a terminal whose target cannot be proven after hydration triggers a bounded authoritative re-read without a guessed duplicate or transient overwrite
- **Then** an admitted compaction leaves the pending list when its matching start is observed; HTTP admission alone never proves completion
- **Then** native zero-cost fixtures cover idle and busy admission, successful and failed terminal events and busy revert refusals; projection and stream-owner regressions cover duplicate delivery and hydration races; in-app undo, redo and compact controls remain separate work

### V2 subagent replies

- A harness-identified subagent reply appears as one collapsed line naming the agent when known. Consecutive replies share one line with the reply count. Any intervening conversation item ends the group.
- A failed reply is visible in the collapsed summary, with an icon and text. Counts refer to replies, including repeated replies from the same agent.
- Opening a group reveals its individual replies. Opening a reply shows the original report in Markdown in place. When the harness identifies a child and navigation is available, a separate action opens the verified direct child.
- If the agent name is unavailable or malformed, the reply uses a generic subagent label. The report text and any verified child link remain available when the history page runs out of space for optional labels.
- The same presentation applies to live and historical replies. A harness without structured replies keeps the normal notice presentation. User-authored text always remains a user message.

### V2 light notices

- **Given** the harness adds a reminder to the conversation, other than a recognized subagent reply, such as OpenCode's Plan mode notes when the agent switches (`synthetic` inbox rows), or a system note (#491)
- **When** the timeline shows it, from its admission on, live or from history
- **Then** it is a light line like the agent and model switch notes: an info mark and muted small text on one line with an ellipsis, centered, with no card and no error color; a tap opens the whole note, rendered as Markdown with links, file paths and code copy working (with its leading icon collapsing the expanded rich note so links and text selection never fight the toggle), and a second tap folds a plain note
- **Then** a text wholly inside one `<system-reminder>`, `<system-update>`, `<fork-notice>`, or background-job `<background-result>` envelope shows without the envelope; skill activations (`session.skill.activated` / history `skill`) and location moves (`session.moved` / history `location-switched` when the directory actually changed) render as quiet light lines (with `session.moved` also refreshing the session's location catalog); any other text, and anything the user typed, stays as written; the row's description and metadata are never shown
- **Then** the reminder is never pending input: the composer shows no waiting pill for it, a cancelled reminder stays as a stopped note, and one admitted again under the same ID starts over
- **Then** reminders never keep a finished turn's work open and stay in sight beside the folded work; a system note and an unknown part are light lines too, while context compaction notices always use their dedicated centered compaction divider (#520)

### V2 message action bar

- **Given** a user or agent message in the live or history timeline (#539, replacing the #492 menu)
- **Then** its text is always selectable: a long press on words, a double tap or a double click selects natively, with handles and the platform's selection menu; no message copies itself on a double tap any more, and a tap that only clears a selection does nothing else
- **When** the user taps the message where the tap has no other function (its words, its padding, or its row beside it), long presses a clean area (the padding, a line's empty end, or the row beside the bubble), presses the Menu key or Shift+F10 on the focused message (messages join keyboard traversal and show a focus outline), or right clicks the row beside it
- **Then** a horizontal bar of icons opens on the message's own side, half inside and half outside one of its edges: of the edges whose bar fits in the visible list, the one away from the finger or pointer that opened it (the top one when nothing did), else near the trigger inside the visible list for a message taller than it; it never covers the composer or the header, even as the list changes size
- **Then** the bar offers, in this order, Copy all text, Share as image (#540), Undo this turn, and a vertical three-dots menu with Rewind and edit from here and Fork from here; Forward (#542) and Read aloud (#541) follow Copy, in that order; an action that cannot run is left out, never shown dead, and the three dots hide when their menu would be empty
- **Then** Copy all copies the canonical text, Markdown kept, and says so; Undo this turn shows on the latest confirmed turn's prompt and its complete answers, and Rewind and edit from here on an older turn's, both only in the live view and while the session can revert (a session without the turn port cannot); Fork from here shows where the server can fork the listed session: on a prompt it copies the history before that prompt into a new session, opens it (unless the user moved elsewhere or opened a dialog meanwhile) and puts the prompt in its message box; on an answer it keeps the answer's whole turn, up to the next prompt; it is not offered while an undo is staged, nor for a session the list does not hold; an uncertain fork is never sent again and says the fork may exist
- **Then** a long press on a bar button, a mouse resting on it or the keyboard focus names it above the bar (below it when the list leaves no room above), without running it; screen readers get every action of the bar as actions on the message, and each button by its name
- **Then** with a mouse, resting on a message for 150 ms shows its bar and leaving both the message and the bar hides it 600 ms later, so the pointer can reach it; a click keeps it open
- **Then** one bar shows at a time; it closes on a tap outside it, Escape while the focus is on the message or the bar (from the bar the focus returns to the message; elsewhere Escape keeps its own use), a scroll, a move of the list that takes its edge out of view, a new selection, or once one of its actions runs; for a moment after a tap opens it, the bar lets a double tap's second tap through to the words, and its half past the message's edge takes taps without acting, so they reach no other message; a choice in the three-dots menu still runs when the list moved the message away meanwhile; a streaming answer offers Copy only, and a prompt still waiting offers no bar at all (#502), though its text is selectable
- **When** the user taps inline `code` in a message
- **Then** only that code is copied, with the same notice; code inside a link's text keeps opening the link, fenced code blocks keep their own copy button, and none of these, nor links, file paths, the elapsed chip or attachments, opens the bar

### V2 message image

- **Given** a whole message (a sent prompt, or a finished answer whose start history kept) and a platform that can take images (#540)
- **When** the user picks Share as image in its action bar
- **Then** the message alone (its card or its text with its clock, never the bar, the focus outline or the rest of the timeline) becomes a PNG on the theme's surface with a 16-pixel margin, at the screen's density up to 3x, smaller when needed to stay within 8192 by 4096 pixels and 12 million pixels in all; a message too tall even at half size says "Too long to share as an image" and copying still works
- **Then** on Android, macOS and Windows the system share sheet receives the file alone (no text that a target could take instead), written to a new file of its own in this app's share folder (two images of the same second never share one), whose images older than a day are removed on the next share; on Linux, whose share sheet takes no files, the button reads Save as image and the system save dialog writes the PNG where the user chooses, then says "Image saved"
- **Then** a streaming answer, a waiting prompt, a message shown only in part for its length (over 64,000 characters), a message with nothing to show and the Web offer no image; a failure says "The image could not be made" and never shares text instead

### V2 forward a message

- **Given** a sent prompt or a whole finished answer with text, in the live or history timeline of a conversation on the server the sessions list shows (#542)
- **When** the user picks Forward in its bar, or presses Ctrl+Shift+F (Cmd+Shift+F) on the focused message
- **Then** a dialog "Forward to…" shows the line the message will carry, `Forwarded from: project / title` in the app's language, over an italic three-line preview of the message, a search over titles and project names, and the open projects in the drawer's order (the listed conversations' projects without them), each with its 20 most recent top-level conversations (title and how long ago it changed), never the message's own conversation, a child, an archived one or another server's; a project still being read shows a spinner, and the dialog says when there is no open project, no other conversation, no match, or the list could not be read (with Retry, also when the first read fails, and in place of the spinner of an open project whose read failed); the user picks several, which the search never unpicks, sees how many, and Forward stays off with none picked or with the server offline, following the server's state as it changes
- **When** they tap Forward (pressed again before the results show, it starts nothing more)
- **Then** each picked conversation, once and in turn, receives the line, a blank line and the message as written (no attachments, tools or reasoning), on its own model and agent, queued behind any turn it is running; a pick that left the list meanwhile still goes and reports it is gone; each one opens for a moment without touching its tab, draft or composer, and with no screen on it, so none of its requests is answered on the user's behalf meanwhile, and waits up to 20 seconds while a model change, a stop or a staged undo holds its sends; the conversation is then read again from the server, so one archived or deleted meanwhile is reported gone before the list learns of it (a read that cannot tell reports it cannot receive it), and the holds and the live connection are checked again right before the post: a staged undo is never committed by a forward; the dialog cannot be dismissed meanwhile, and Stop ends the wait of the one in progress at once and leaves the rest unsent; an unexpected error fails only that conversation, and one during the post reports it Not confirmed; a window too short for it, as a phone on its side with the keyboard up, leaves the preview, then the title, out, and a phone opens its keyboard only when the search is tapped
- **Then** every conversation reports Queued, Sent, Not sent with the reason (gone or archived, still busy, too many open, cannot receive it, refused, offline), Stopped before sending, or Not confirmed when the server did not answer: that one is never sent again from here, and tapping it opens the conversation (closing a history shown over it), where its composer can check it; a conversation kept warm in a tab reads its queue again, so the forwarded prompt shows there; when all were sent the dialog closes with "Forwarded to N conversations"; otherwise it stays with Retry, which sends again only where nothing was sent; there is no Undo
- **Then** the app watches up to nine conversations per server, one more than its eight warm tabs, so a forward to a closed conversation always has room

### V2 read aloud

- **Given** Read aloud is on in Settings > Read aloud (`cw2.settings.readAloud`, on by default; API keys never stored there) and the device can use the chosen voice service (#541)
- **When** the user picks Read aloud in the bar of a sent prompt or a finished answer whose start history kept, in the live or history timeline
- **Then** the message's spoken text (Markdown and HTML markers, code blocks in Markdown or HTML, tables, images and math, as the timeline finds it, left out; link text kept, and inline code read as written, angle brackets included) goes to the chosen service and plays through the app's shared audio player, with a pill at the bottom start of the timeline: a spinner while the audio is prepared, then Pause or Resume, and Stop; the message's bar then offers Stop reading instead; a reading that plays to its end leaves no pill, even where the platform reports no duration, and reading it again starts over
- **Then** one reading plays at a time: a newer one wins over one still being prepared, another audio taking the player ends it (one started while a reading is prepared keeps the player, and that reading is never heard), and sending a prompt in that session (Continue included) or leaving its live or history view stops its reading; a reading stopped or replaced reports nothing and sends no text once stopped; the last 16 readings (up to 32 MiB) replay without asking the service again, until the service, voice, model, address, speed or app language changes; where the player plays from a file (iOS, macOS, Linux), the audio sits in one file in a folder of this run's own that only this user can read, removed when another audio or a stop replaces it, and the folder with the app
- **Then** Microsoft Edge (experimental, the default) needs no key and is marked as Microsoft's unofficial read-aloud service, splits text into chunks of at most 4096 bytes (64 KiB in all), retries once with the server's clock on a 403 (a refusal after that is the service's, never blamed on a key), and when a chosen voice gives no audio reads with the language's default voice for the rest of that message; OpenAI-compatible (default `https://api.openai.com`, `gpt-4o-mini-tts`, `alloy`, up to 4096 characters), ElevenLabs (up to 10,000) and NVIDIA NIM (its server address required, up to 2,000, no speed) use a key saved in the device's secure storage for that service at that address (a new address asks for its key, so a key never goes to another host) and an https address, or plain http only to this device, the local network or a tailnet (the address field says so otherwise); a request ends within 45 seconds in all, and a stop drops its connection at once; every cloud choice says the message text goes to that service
- **Then** a failure says why (no connection, a refused key, a busy service, too long, nothing to read, a refused request, not set up, unavailable here) with a Settings button that opens Settings > Read aloud, and never reads with another service instead; a player that cannot play the audio, or take a paused reading back, says so; a streaming answer, a waiting prompt and the Web offer no Read aloud, and the Web shows no Read aloud settings
- **Then** the settings page turns the action on and off, picks the service, a voice from the service's list (or the default for the app's language), the address and model where they apply, the key (saved or cleared, never shown again), the speed (shown as a multiplier: 0.5× to 2.0×, ElevenLabs 0.7× to 1.2×), and a test phrase that Test voice reads with the current choices; what the fields say applies when the user leaves them, before Test voice, the voice list or saving a key, and when leaving the page; while the test reads, its button stops it, and leaving the page ends it; a voice list that arrives after another service was picked is ignored; the device's own voice is not offered yet

### V2 message elapsed time and details

- **Given** a live or history timeline shows the parts (text, reasoning, tools) of an assistant message
- **When** the first part of that message is rendered
- **Then** a user turn's header shows only its clock time, with no sender label (screen readers still announce `You`) and no elapsed chip, and a user turn with no time has no header; an assistant header shows its clock time at the start and a compact elapsed chip at the end, from the harness's own message creation to completion (`200ms`, `3s`, `1m 5s`, `2h`), or `…` while the message runs or its times disagree; the chip keeps a 48-pixel target and opens the details either way; an assistant message with no time, duration or action has no header; nothing floats beside the bubble: a turn's undo (latest turn) or rewind-and-edit (older turns) lives in its message's action bar (#539), and history offers neither
- **Then** the details dialog lists the elapsed time, model, provider, the reported token total (only when input and output are known), cost in USD, and "Step started #1" / "Step finished #1: reason • tokens • cost" (a v2 message is one model step); with nothing known it says "No metadata available"; it scrolls, closes with its button, the barrier or Escape
- **Then** with Tokens per second on in the workspace Display menu (`cw2.settings.showTokensPerSecond`, on by default since #538 and stored only when turned off, not repeated in Appearance settings), the final completed answer of each completed turn ends with its speed and time as one faded run with no icons, `138tps 28s` (rounded speed, then the elapsed time), right after its last word when the answer ends in running text (a paragraph, an ATX heading, the end of a list item or quote) and on a line of its own below otherwise (code, a table, a rule, a setext heading, a link reference, HTML), never changing the answer's text; it is a quiet button (tap, Enter, a screen-reader node naming Message Info with the precise localized speed) that opens Message Info, and no other row of that message repeats the elapsed time (header, tool, reasoning, stretch or subagent rows); an answer over the rich render budget keeps its header elapsed chip, whose details include the turn speed; with Tokens per second off the elapsed chip stays in the header; the rate is the turn's `sum(output + reasoning tokens) / sum(streamed − (first token or start))` over every step, and it opens the same details, which add a Speed row; a turn still running, failed, interrupted, cut by the resident window or a later history page, or with any step lacking a streamed time or output tokens shows no rate, never one derived from completion time; a harness that reports no streaming times shows none
- **Then** live parts learn the model, agent and start of the running step when it starts, and its first-token and streamed times as they arrive; when the step ends or fails they receive the completion time, usage and finish reason; a retried step on the same message resets them to the new attempt
- **Then** history reads the same facts from the assistant record; an unexpected, oversized or malformed display value is unknown and never rejects the page

- **Given** the refined visual style
- **When** timeline cards render
- **Then** the agent's text has no card: no fill, no border and no inset of its own beside it, so it sits on the page; non-subagent tools, shell runs and reasoning render as compact lightweight rows without outer cards; subagent calls, notices and non-error outcomes keep borderless cards with slightly tighter vertical padding; the user's turn keeps its tinted bubble, right-aligned, with no outline (#488), shrinking horizontally to fit its content up to `min(640, 85% of the lane)` with no wide width floor while preserving a 48 dp hit-target height (#500); everything follows theme, density, text-size and width changes on rebuild
- **Then** below 600 dp wide, the live and history timelines keep a 12 dp side margin instead of 16 dp (8 dp before #536), so the agent's text uses the screen without touching its edge; wider screens keep 16 dp and the 760 dp reading width
- **Then** a search match is outlined just outside its row, so the outline never covers text that has no card

### V2 work groups, tool runs and loading

- **Given** an assistant turn in the live or history timeline uses reasoning, shell runs or non-subagent tools
- **When** those items form a contiguous non-text stretch
- **Then** every `AssistantText` — including intermediate text produced before later tool calls — stays visible in the conversation forever and is never swallowed into an activity stretch; `UserInput`, `Notice`, `TurnOutcome`, `UnknownItem` and subagent calls also remain outside stretches in chronological order
- **Then** by default (Expanded tools off in the Display menu, `cw2.settings.expandedTools`, #537) every stretch is its one-line summary from the start, also while it runs, with running and failed counts on the line, as the official clients do, and in Block render mode the calls that ended early are summaries too (a subagent call or a shell of unknown status stays on its own); a tap opens it step by step
- **Then** with Expanded tools on, while the live turn has no following visible `AssistantText` yet, the stretch stays open as individual compact single-line rows (without wrapping them in a second tool-run card)
- **Then** as soon as a following visible `AssistantText` begins arriving (even while streaming), or when the turn is settled (including in `SessionHistoryPage`) with no active items in the stretch, the stretch collapses into one quiet single-line summary (`Edited N files · Explored N files · N searches · Fetched N pages · Ran N commands · N skills · Thought · N steps`, omitting zero fragments), surfacing still-running counts and error-colored failure counts (`· 1 failed`) directly on the summary line; tapping expands or collapses the compact rows in place
- **Then** consecutive subagent calls share a compact summary in live and history. Any intervening item ends the group. The summary counts calls, shows running and queued activity, and flags failed and interrupted calls. It wraps when space is tight or text is enlarged, and has a tap target of at least 48 dp. A message that opens in the group keeps its elapsed chip accessible while collapsed, unless that message's final answer shows its speed and time (#538)
- **Then** expanding reveals each original call with its status, details and available child navigation. An open group stays open when scrolled out of view and back, or when older adjacent calls load
- **Then** a message that opens inside an activity stretch keeps its elapsed chip and details, unless its final answer shows its speed and time (#538): collapsed, the stretch header shows the first such message's chip outside its toggle target; expanded, each row that opens a message shows its own chip
- **Then** a call's input, output and error open in a details dialog on row tap, never inline; the dialog follows the call while it runs, opens at the top of each value, keeps a value's newest part in view only when the reader is already at its end, and closes with its button, the barrier or Escape
- **Then** a succeeded turn has no row of its own, live or in the read-only history; the header reports it; failed and interrupted turns keep their rows outside stretches
- **Then** once collapsed, a status pulse that briefly reports the session busy, or a rehydration of the same items, keeps the same stretch header and element; new streaming items in a trailing stretch reopen that tail
- **Then** opening a stretch or a reasoning row is the reader's: the timeline does not follow the growth it makes; what the reader opened survives rebuilds and passive refreshes, and a session shown again starts collapsed; searching a hidden reasoning item expands its stretch and opens its body automatically

- **Given** a reasoning part in the live or history timeline
- **When** it renders
- **Then** it shows as a single compact line (at least 48 dp tall): `Thinking: <heading>` (from its opening bold heading) or `Thinking…` while streaming, and `Thought · <duration>` (from harness part timestamps, never message-wide times) or `Thought` when complete; tapping expands or collapses the full Markdown body inside a bounded scroll container (capped at 40% of viewport height) with auto-follow while streaming

- **Given** a live session has no items
- **When** it is still being read (probing, connecting or hydrating)
- **Then** a quiet loader shows in the space below the header instead of the empty conversation; resident items show at once, without the loader, even while a re-read runs
- **When** a read of the session synced and reported no items
- **Then** the empty conversation (`Hello! I am your AI assistant` / `How can I help you today?`) shows in the space the header leaves; it scales down or steps aside in a short viewport and never pushes the header away; a first read that failed shows neither the loader nor the empty conversation

### V2 render mode and display filters

- **Given** the user picks Settings > Behavior > Chat render mode
- **When** it is Live (the default)
- **Then** the live timeline shows assistant text, reasoning and tool activity as they stream
- **When** it is Block and the session has a turn in flight
- **Then** that turn shows only the messages the harness reports ended, in order (compacting stretches only before already-published visible answers, never before held answers), then each tool or shell call that ended as compact rows; a `Generating response` placeholder holds the rest, also while a prompt waits for its first answer; content it holds is not an arrival and does not move the reader
- **Then** once the session settles the whole turn shows, with its stretches collapsed as in Live; earlier turns are never held; the choice persists under `cw2.settings.chatRenderMode` (`live` is not written; an unknown stored value keeps Live)

- **Given** the user turns off Settings > Appearance > Thinking bubbles or Tool call bubbles
- **When** the live timeline shows a turn
- **Then** the reasoning or the tool and shell calls leave the timeline before anything is grouped: an activity stretch shows only what remains, and a stretch with nothing left to show disappears (#108)
- **Then** the first item shown of a harness message keeps its elapsed chip and details; hidden items that arrive do not move the reader, and showing hidden items again or changing the render mode is not an arrival either, while content that arrived meanwhile (even while the session was hidden) is still followed or marked; the history page is unaffected
- **Then** the choices persist under `cw2.settings.showReasoning` and `cw2.settings.showToolCalls` (shown by default, only `false` is written)

### V2 session task list

- **Given** a live session receives a structured plan from a harness (`SessionState.plan` / `PlanSnapshot`, e.g., OpenCode v2 completed `todowrite` tool calls without querying `experimental.todo` config; advertised via `PlanCapabilities.observe`)
- **When** the panel is enabled in the workspace Display menu (`cw2.settings.showTaskList`, default `true`, not repeated in Appearance settings) and the current turn has a non-empty plan
- **Then** a read-only task list panel stays pinned at the top of the conversation (below any sub-conversation return breadcrumb or search bar and above the timeline), completely independent of `showToolCalls`
- **Then** collapsed and expanded states present distinct headers over one shared full-width animated 3 px progress bar (`completed / countedTotal`, where `cancelled` stays in the total and never increments `completed`, and `unknown` statuses render without distorting progress): collapsed shows the focal active task (`inProgress` first, then `pending`, then last `completed`) with a count-first summary (`2/5 Title` on phones, `Task 2/5 · Title` on wide screens), completed/cancelled summary when none are active, and a `+N` pill for additional parallel `inProgress` tasks; expanded shows `Tasks` and the `completed/total` chip (the count is not repeated in the title, #549), optional cancelled and `+N` pills (wrapping cleanly on narrow high-scale viewports), and a scrollable list of one-line rows that shows five tasks at a time (also capped at 28% of viewport height up to 220 dp), scrolled so the task in progress sits in the middle, two before and two after (in the middle of fewer rows when the window keeps the list shorter), and turning to the next one as it changes (#550); the panel opens expanded unless the user collapsed it; the list renders distinct status icons and typography (`completed` strikethrough, `inProgress` highlighted with a static RTL-mirrored `double_arrow` icon in both the collapsed header and expanded rows (#511), `pending`, `cancelled` italic with cancel icon, `unknown`)
- **Then** the panel remains visible during the turn and after the turn settles (including at 100% completed or cancelled, with no auto-hide timer), clears automatically as soon as an active next-turn user prompt or pending input supersedes the plan (draft, cancelled, and rejected inputs never clear; permission cards and question forms within the same turn keep the panel visible), restores the surviving pre-cut turn's plan during staged undo and the post-cut plan on Redo, and never resurrects a superseded plan past bounded timeline eviction
- **Then** tapping the header persists `cw2.settings.taskListCollapsed` (default `false`); an open software keyboard on compact viewports or tight/short viewports temporarily force-collapses the panel without mutating the saved preference (and extreme sub-140 dp viewports hide the panel so the composer never overflows); reduced motion disables size/progress animations and screen-reader semantics announce the header title, progress, cancelled count, and extra parallel count
- **Then** structured plan tool calls (`ToolKind.plan`, e.g., `todowrite` / `todoread`) are omitted from the live and history timelines, activity stretches, composer status, and conversation search; harnesses that never emit structured plans simply show no panel

### V2 composer input

- **Given** a live session's composer or a new chat's draft
- **When** it renders
- **Then** one rounded bubble without an outline holds the field and every control (#484): on a phone without focus it is a single line with **+**, the field ("Message"), the mic and the action; while anything inside it has focus on a phone, while a dictation runs, in a conversation or a new chat's draft (without the keyboard, the field growing with the words up to three lines, or keeping its own limit where it has the focus; #546), and always on a desktop, the field ("Type / for commands") sits on top and one row below holds **+**, the model chip, the mic and the action, which keep to the end; nothing sits above the field
- **Then** the action is a round Send (filled while there is text or staged attachments to send) or, while the session responds and both the field and attachments are empty, a round dark Stop
- **Then** on a touch-first platform or a window narrower than 600 dp that can dictate, while Send would only show the idle check (see V2 conversation status bar), the mic stands in its place, after 1.5 seconds of that, so a send whose work starts at once never moves it there and back (#545), and the check is neither shown, tapped nor focused; as soon as there is text or an attachment to send, work resumes, a send runs or the session stops being idle, the mic slides back beside the action in 220 ms (at once with reduced motion, toward the start edge right to left) and a dictation in flight keeps going (#501); with the mic off (no dictation on the platform, a send in flight, the server offline) the check keeps its place
- **Then** **+** opens the attachment menu (Image, File, Audio, Location) in live sessions and new chat drafts, disabled only while a send is in flight or the server is offline; the mic (voice) stays disabled on platforms without native dictation, with a tooltip saying why
- **Then** a closed field shows one line and keeps every line of the draft; it opens on the frame after it takes focus, including a field that already had focus when the composer was built
- **Then** the field uses the platform's native spell check, suggestions and autocorrection unless Settings > Behavior > Composer spell check is off; the choice persists under `cw2.settings.composerSpellCheck` (on by default, only `false` is written) and nothing is sent to another service
- **When** the on-screen keyboard opens
- **Then** the field and its Send stay whole above it, on a phone and in landscape

- **Given** a desktop or Web window with the field focused
- **When** the user presses Enter (or keypad Enter) without a modifier and outside an IME composition
- **Then** the text is sent and the field keeps its focus; an empty field sends nothing and gets no new line; Shift+Enter breaks the line; prompt recall and the double-Escape Stop keep working
- **When** the user clicks Send
- **Then** the field keeps its focus too; on a phone Enter keeps breaking the line

- **Given** an Android or iOS phone with the field focused
- **When** a message is sent
- **Then** the field lets go of the focus, so the keyboard closes and the composer folds (beta.21); a send that fails, or text typed while it was pending, keeps it; a double-tap Continue that is accepted lets go too, unless text was typed meanwhile

- **Given** a live session the server reports idle, with an empty field and no staged attachments
- **When** the user double-taps or double-clicks the empty Send
- **Then** the literal `continue` is sent once through the same outbox send; a single tap does nothing; it is not offered while the session runs, is stopping, has staged attachments, or reports no execution state, nor while the mic stands in for the check (#501), where holding Send to choose the delivery also waits until there is text
- **Then** the field stays editable while the continue is sent, and text typed meanwhile stays, also when the session's tab closes before the send ends

### V2 attachments (#473)

- **Given** a live session composer or a new chat draft
- **When** the user taps **+** (`composer-attach`)
- **Then** a compact menu offers **Image**, **File**, **Audio**, and **Location**
- **Then** picking files streams up to 100 MB per file (up to 8 attachments per message) into local content-addressed blob storage (`AttachmentBlobRepository`, 256 MB LRU with pin protection for active drafts and unsettled outbox records), sniffing MIME types from magic bytes instead of trusting filenames alone, and showing pending chips above the input field with thumbnails/icons, size, honest "Uploaded as file" notes when the active model lacks native image/PDF input and the harness supports staging uploads, and a remove button per chip
- **Then** picking **Location** opens a dialog with an optional "Use current location" action (when platform location services are available; denied or unavailable GPS stays non-blocking) alongside manual latitude (`-90..90`), longitude (`-180..180`), and optional label (`<=200` chars) inputs
- **Then** sending a message with attachments (with or without text) inlines eligible `image/png`, `image/jpeg`, `image/gif`, `image/webp` (unless the active model declares it does not read images; a session on its agent's or the location's default model uses that model's declared input), `application/pdf` (when the active model declares PDF input), and valid UTF-8 text (`<=256` KB) up to 20 MB per item and 20 MB total inline, and streams audio, larger files, or unsupported-modality files to `<tmp>/uploads/<uuid>/<sanitized>` via `POST /api/experimental/fs/write` (workspace code writes remain disabled) before sealing the outbox payload; a file sent this way records its size and SHA-256 so the sending device previews it from its own local copy
- **Then** sealed outbox payloads over 32 KB spill out-of-band to `PromptPayloadStore` (verified by SHA-256 and exact byte length) so same-ID reconciliation replays the exact sealed payload without re-uploading, and taking back a cancelled pending prompt restores both its display text and its staged attachments
- **Given** a user message with attachments in either the live timeline or the read-only history view
- **When** the bubble renders
- **Then** attachments appear above the message text inside the user bubble:
  - **Images**: bounded thumbnails loaded on demand through the session's `AttachmentFacet` (negotiating `X-OpenCode-Capabilities: experimental-media-uri` and falling back cleanly to inline/local cache), opening a fullscreen zoomable `InteractiveViewer` lightbox on tap, with retry on load failure and a safe fallback tile for images exceeding 25 megapixels or omitted bytes
  - **Files & PDFs**: card with MIME icon, sanitized basename, MIME type, and size; tapping fetches app-owned cached bytes and opens them with the OS viewer (never passing untrusted server paths), or reports preview unavailable when bytes cannot be retrieved on this device
  - **Audio**: inline player card with Play/Pause, progress scrubber (`Slider`), and `m:ss` clock (single active player across timelines), degrading honestly to a disabled card when playback is unsupported or bytes are unavailable on this device
  - **Location**: card with optional label, formatted coordinates, and optional accuracy; tapping launches a strictly numeric allowlisted map URI (`geo:` on Android, `https://www.openstreetmap.org/` elsewhere — never trusting URLs from labels or metadata), copying coordinates with a snackbar if no maps app handles it

### V2 voice input

- **Given** a live session's composer or a new chat's draft on Android, iOS, macOS or Web
- **When** the user taps the mic
- **Then** the platform's own speech recognizer listens (#307, native slice; CodeWalk sends no audio to a harness, though the platform's service may recognize on its vendor's servers); its first use asks for the microphone (on macOS, speech recognition first, then the microphone; never Bluetooth), and a refusal (on Android or macOS, or the browser's `not-allowed`/`service-not-allowed`) says "Allow microphone access to use voice input" and leaves the mic on to ask again
- **Then** the words heard so far go into the field at the cursor where the dictation began, each result taking the previous one's place, spaced from the text around them; the recognizer's final words stay; a second tap stops: the ball holds still and the mic takes no tap until the final words arrive or 3 seconds pass, even if the platform's stop fails or it reports the end first, and a stop while the microphone is still being asked for never starts listening; a session that runs out its wait stops the recognizer too
- **Then** while it listens the mic shows a red ball behind a filled icon in the color that reads on it (v1's active mic): the ball breathes slowly in silence and it and its halo swell with the voice, from the input level the platform reports, scaled to the room's quiet and the voice's peak; with reduced motion the ball holds still; the tooltip says "Stop voice input"
- **Then** the mic sliding between the idle check's place and its own (#501) never ends a dictation; an edit of the field while listening stops the dictation and keeps the user's text; a send ends it before the text is read, and a field that locks (a send in flight, the server offline) ends it too; words that arrive after the end never land; leaving the screen cancels it, and a page, sheet or dialog opened over the composer (the model picker included) ends it at its next words; the composer opening or closing does not
- **Then** silence or nothing understood ends quietly; a failure says "Voice input stopped unexpectedly", including one Android reports just after it stops listening; a recognizer that stops capturing without a final result still ends within 3 seconds; a device or browser without a recognizer says "Voice input isn't available on this device" and turns the mic off (a browser finds out on its first tap)
- **Given** Linux or Windows, or a draft while the server is offline or a send is in flight
- **Then** the mic stays off; on Linux and Windows its tooltip says "Voice input isn't available on this device", while a mic paused by a send or an offline server keeps "Voice input"

### V2 conversation status bar

- **Given** an open conversation, whether or not it can send prompts, a sub-agent's included
- **When** the conversation has a state to report
- **Then** one fixed-height line above the composer (or above the footer of a view without one) is the only place that reports it; nothing above the timeline does (#468, owner 2026-11-10); the top keeps only the permission mode control, and outside the workspace the session title and server
- **Then** the line shows one state at a time, the first that applies in this order (owner, 2026-11-10):
  1. The view is not live: the reason it could not open, Offline (an unusable server of any kind) or the authentication failure, connecting, loading, reconnecting, not kept up to date, gone from the server, or not up to date; for up to 7 seconds after the app returns from the background, a view that was live when it left does not report connecting, loading, reconnecting or not up to date while its stream comes back (the resume grace, #503), which a server confirmed Offline, a failure or a terminal state ends at once; a view opened cold has none
  2. A question or approval waits for the user: `Waiting for your answer`
  3. An interruption: a shutdown whose continuation is not confirmed, a run that vanished with no outcome, or a stop requested by another client (a Stop sent here reports itself beside the composer)
  4. A retry: `Retrying in m:ss`, counted down from the server's deadline, or `Retrying model request...` with no known deadline
  5. The work in flight: the last call of the message still in flight (its tool name) or its reasoning (by the `**Heading**` it opens with, else `Thinking...`); a call outside any message counts only while it runs; a shell command never shows here, as a run or a shell tool call, since the timeline and the sub-agents and shells capsule already show it: the line keeps what came before it (#521)
  6. Running sub-agents never show here, nor does a last turn's outcome while they run: the robot capsule counts them (#543)
  7. Otherwise, while the assistant works: after 2 seconds a tip about something the app does, rotated every 15 seconds (#548): holding Send to steer or queue, tapping a message for its actions, double-tapping the empty Send to continue, double-tapping a word to select it, starring or long-pressing a model to keep it on top, `/` commands, pinning actions to the top bar, and only where they apply: tabs from the Display menu while tabs are hidden, turning tips off in the Display menu, Escape twice to stop and switching models, variants and agents from the keyboard where there is one, and the voice that reads messages aloud where Read aloud is offered; the name of a menu or settings page in a tip is a link that opens the Display menu, Settings > Shortcuts or Settings > Read aloud, and a tip the line cuts keeps that link as a button in its whole text (More); tips about the Display menu, holding Send and pins need the app's preferences, and keyboard tips a physical keyboard or a desktop; or `Reasoning...` when Settings > Appearance > Composer tips is off; the choice persists under `cw2.settings.composerTips` (on by default, only `false` is written)
  8. A last turn that failed or was interrupted, unless the timeline already shows the interruption: `Last turn failed`, `Last turn interrupted`
  9. Idle: nothing in the line; the composer's Send shows a check instead of its arrow while the field is empty, with the same disabled look and the tooltip `Idle` (`Ocioso` in Portuguese), until the user types or work resumes (owner, beta.21); a success has no label of its own
- **Then** a live connection and a running session have no label: `Live` and `Running` never show
- **Then** states 1, 2, 3 and 8 are announced to screen readers and clear as soon as they no longer apply; work and tips are not announced and clear a second later, so a short gap between activities does not flash
- **Then** a label longer than the line keeps one line, ends in an ellipsis and offers a thin `More` at the end that opens the whole text; the line keeps its height, so the field does not move

### V2 composer commands

- **Given** a live session's composer or a new chat's draft
- **When** the field holds only `/` and a word
- **Then** a list of the local commands that match the word by name or description opens above the field: `/new`, `/model` (also `/models`), `/agent`, `/sessions`, `/help`, `/thinking`, `/undo`, `/redo` and `/compact`; command names read left to right in every language
- **Then** the list is at most 240 dp (or 30% of the window) tall and never taller than the room the composer leaves above its field; it scrolls and keeps the highlighted command in view, so with the on-screen keyboard open the field, its Send and the highlight stay visible; when not even one row fits, the list stays shut and the keys stay the field's, so no command runs unseen
- **Then** on a physical keyboard Up and Down move the highlight, Enter or Tab runs it, and Escape closes the list until the text changes; with a modifier or during an IME composition the keys keep their usual meaning
- **When** the user taps a command, picks it with the keyboard, or sends a builtin's name (any case) with Send or Enter
- **Then** the command runs locally, the field is cleared, and nothing is sent to the server; words after the name are ignored
- **Then** `/new` opens the New Chat draft; `/model` and `/agent` open the single pick of model, agent and permissions; `/sessions` opens the list drawer on a phone, or shows the hidden list pane on a wider window; `/help` lists the commands in a dialog that Enter closes; `/thinking` shows or hides reasoning (the Appearance switch) and says which
- **Then** `/undo`, `/redo` and `/compact` run the shown session's turn actions, and say they are not available in this version yet when no session is bound; on the New Chat draft the commands that need a conversation (`/model`, `/agent`, `/undo`, `/redo`, `/compact`) say to send a first message; a sub-conversation's `/model` says its model is its parent's
- **Then** any other `/word` is sent as an ordinary prompt; the server's own commands are not listed

### V2 agents and permission mode in the pick

- **Given** the single pick of a live session is open (#485, which replaced the floating agent menu)
- **Then** its footer shows the offered agents as one row of chips, each with its color dot (the same rule as the composer chip) and its description as tooltip; the current agent is selected, and an agent the location does not offer stays visible as not offered here; picking another agent closes the pick and uses the existing session-selection fence, and picking the current one only closes it; unreadable agent choices explain why instead of inventing a catalog
- **Then** the footer's switch is titled **Auto-approve** in every language, the switch itself saying on or off (#518), and shows the session's allow-everything rule once the server has said (on means the rule is in effect), and the acknowledged local Allow all / Ask mode while the rules are unread, unreadable or not exposed; it keeps the pick open, names how many of this session's permission requests wait for the user and stays disabled during a read or write; a refused, unconfirmed or changed-elsewhere rule write, or a failed local write, is said under the switch in the error color while the pick is open, the count of waiting requests beside it keeping the normal color (a snack bar once it is closed); opening the pick reads the rules again
- **Then** with no word from the server, an unreadable or unknown local policy says Unavailable and disables the switch
- **Then** the footer stays fixed below the list when the pick is at least 420 dp tall; on a shorter pick (a phone with the keyboard open, or large text) it follows the list's last row instead; the composer's chip carries no permission badge
- **Then** a harness without agents or a permission mode shows no such part, with no fake control

### V2 conversation search

- **Given** an open live session, on any harness
- **When** the user presses Ctrl/Cmd+F (Search conversation, configurable in Settings > Shortcuts), picks Search conversation in the ⋮ menu of a narrow window, or the search button on a wide window's toolbar (#462)
- **Then** a bar above the timeline takes the focus, or takes it back with its text selected when already open; it searches the conversation as loaded on this device, ignoring case: the user's messages, the answers and, while shown, the reasoning; tool calls and history not yet loaded are not searched
- **Then** matches run from the newest: the newest is first, its row is outlined and scrolled into view (the timeline stops following new content), and the bar says "1 of N", or "No results" with the arrows off
- **Then** Enter, F3 and ↑ go to the next older match, Shift+Enter, Shift+F3 and ↓ to the next newer one, wrapping at either end; F3 and Shift+F3 work from anywhere in the conversation while the bar is open, and content arriving meanwhile keeps the current match
- **Then** Escape in the field or ✕ closes the bar, removes the outline and gives the composer the focus
- **Then** it needs no harness capability: it reads the canonical items every harness gives

### V2 navigation intents and locale

- **Given** a `codewalk://s/<host>/<session>` link or `/s/<host>/<session>` route is opened
- **When** the host and session identifiers are valid
- **Then** navigation retains a pending session intent and displays the conversation placeholder
- **Then** identifiers remain opaque, including valid percent-encoded characters
- **Then** ordinary navigation to conversations, hosts or settings preserves the pending intent without guessing a profile or starting a session read; a new pairing or unsupported link replaces it

- **Given** a `codewalk://pair` link or `/pair` route is opened
- **When** its pairing intent is captured
- **Then** the pairing page consumes the original link once from private memory while the visible route remains `/pair`, without query parameters
- **Then** bare pairing links open the form; a supported `url` wrapper is validated and presents its destination for confirmation, while invalid or duplicate parameters never authorize a request

- **Given** a link is unsupported or its encoded path is malformed
- **When** navigation handles it
- **Then** an unsupported-link placeholder is shown without displaying the original link

- **Given** the v2 app resolves a device locale
- **When** that language is among its 14 supported locales
- **Then** its scoped UI copy uses that language, including right-to-left layout for Arabic and Urdu
- **Then** regional variants resolve by language and unsupported locale lists fall back to English

### V2 settings shell and local shortcuts

- **Given** the user opens `/settings` in the explicit v2 app
- **When** the viewport is below 840 logical pixels
- **Then** one bar on top holds the only back button and the only title (#551): the list, under "Settings", says it nowhere else, and its back button leaves Settings; selecting a section shows its name in that bar, whose back button returns to the list, and no section repeats its name or a second back row below it
- **Then** detail Back, system Back and the configured Escape action return to the list while retaining its search query
- **When** the viewport is at least 840 logical pixels
- **Then** a 320-pixel destination rail and detail appear side by side, with Appearance selected initially; the bar says "Settings" and leaves them, and the open section's name heads the detail once, in the same style for every section
- **Then** filtering matches localized destination titles, descriptions and groups without replacing the open wide detail
- **Then** resizing preserves selection, list search, detail form state and pending shortcut-capture choices
- **Then** Servers opens the existing hosts route; Help exposes App Logs, Version and updates (with the release history below the update controls) and About, while other unimplemented feature settings remain with their owning Issues
- **Then** About lists GitHub and a permanent Telegram entry (`https://t.me/codewalkapp`) that open in the external handler, with a snackbar when the link cannot be opened; Settings search finds About by GitHub or Telegram, Appearance by text size, math rendering, the thinking and tool call bubbles or composer tips, and Behavior by its render modes, language, composer spell check or, on a desktop window, its title bar and close choices

- **Given** the user opens Shortcuts
- **When** the local bindings are displayed or edited
- **Then** all 15 stable actions are inspectable and individually editable, including unavailable actions whose imported overrides may need conflict repair
- **Then** search matches both stored binding tokens and visible platform labels such as `Ctrl+,` and `Cmd+,`
- **Then** key capture supports bare Escape; Cancel or tapping the dialog barrier dismisses without applying
- **Then** an empty binding explicitly unassigns an action, whereas Reset removes its override and restores its default
- **Then** bindings persist as JSON at `cw2.settings.shortcuts`, preserving unknown fields, and malformed metadata is not automatically overwritten
- **Then** conflicts and invalid bindings stay inactive; load/save failures show a retry action without claiming the temporary choice is saved

- **Given** a shortcut reaches the v2 app's keyboard scope
- **When** its binding is valid, non-conflicting and has an available handler
- **Then** Open Settings navigates to `/settings`, and the configured Escape action performs Back only within a compact settings detail
- **Then** unavailable chat, model, voice, tab and native-exit effects are not executed or consumed
- **Then** synthesized and repeated key events do not invoke app actions; modals, composing text and ordinary/AltGraph editing retain priority
- **Then** `mod` resolves to Cmd on macOS and Ctrl elsewhere; explicit Ctrl+Tab remains Ctrl on every platform
- **Then** the Shortcuts destination is visible on desktop/Web and appears on mobile after physical keyboard input is detected in the current app instance
- **Then** these CodeWalk-local preferences never write OpenCode `tui.json` keybinds or server configuration

### V2 app language

- **Given** the user opens Settings > Behavior in the explicit v2 app
- **When** the Language field is opened
- **Then** "System default" plus the 14 catalog languages appear by native-script name in a searchable list, and the current choice is marked
- **Then** choosing a language applies it immediately to the whole app, including right-to-left layout for Arabic and Urdu, and keeps it after a restart
- **Then** the choice persists as its language code at `cw2.settings.locale`; "System default" removes the key and the device locale decides again
- **Then** a stored code outside the catalog is ignored on load instead of forcing an unsupported locale

### V2 appearance preferences

- **Given** the user opens Settings > Appearance in the explicit v2 app
- **When** appearance controls are displayed
- **Then** the user can choose system/light/dark mode, one of 37 consolidated OpenCode presets, or the classic palette with brand seeds and contrast
- **Then** the searchable preset picker and five density tiers work in compact and wide layouts; on narrow screens or enlarged text the segmented choices become fields that open the same searchable picker
- **Then** the controls use the scoped 14-language catalog, including right-to-left layout
- **Then** Session tabs can be turned off and on, persisted as `cw2.settings.showSessionTabs` (on by default); the choice explains that each tab has its own menu and turning tabs off also hides their first-use hint; the former Recent sessions choice is gone (#534) and its stored `cw2.settings.showRecentSessions` is no longer read or written
- **Then** with Session tabs off, a shown conversation heads the toolbar on every width instead of the project: its project's icon leads it and opens the project picker, and its title is the first non-empty one of the open view, an open project's row or its tab; the list, the New Chat draft, an untitled conversation and another server's conversation keep the project title, and a toolbar so crowded with actions that under 48 dp remain shows neither (#535)
- **Then** the chat's overflow opens Display, a sheet with the same thinking, tool call, composer tip and session tab choices, plus the Expanded tools, task list and Tokens per second switches that live only there, so the workspace can be reshaped without leaving the chat

- **Given** the user changes Settings > Appearance > Text size
- **When** the System or Conversation slider moves (80–160 %, 5 % steps)
- **Then** System multiplies the platform text scaler once for every app surface, and Conversation multiplies it again only inside timeline message cards (live and history) and the live and new-chat composer inputs; headers, chips, pills, drawers, settings and dialogs keep the System size
- **Then** highlighted code follows both sizes, and changes apply immediately without restarting the response
- **Then** the values persist under `cw2.settings.systemTextScale` and `cw2.settings.conversationTextScale` (100 % is not written) and a stored value outside the range is clamped on load

- **Given** the user turns off Settings > Appearance > Math rendering
- **When** a message contains `$...$` or `$$...$$`
- **Then** the delimiters render as literal text; turning it back on typesets them on the next rebuild; the choice persists under `cw2.settings.mathRendering` (on by default)

- **Given** any v2 settings select field (theme preset, density, narrow theme choices, App Logs operation filter)
- **When** the user opens it
- **Then** a dialog with a search field filters the options locally, shows "No matches found" when nothing matches, marks the current value and returns the tapped option; the dialog scrolls when the keyboard leaves too little room

- **Given** a preset or platform dynamic palette is available
- **When** the v2 app resolves its light and dark themes
- **Then** a selected preset takes precedence, followed by enabled dynamic colors for that brightness, followed by the brand seed with contrast
- **Then** brand-seed and contrast controls are disabled while a preset or available dynamic palette supplies the colors
- **Then** the dynamic-color toggle is shown when the platform supplies a palette and is disabled while a preset is selected
- **Then** AMOLED can be toggled in dark mode; it blacks the eight Material dark surface roles while preserving preset semantic tokens

- **Given** the explicit v2 app starts or the user changes appearance
- **When** its preferences are loaded or saved
- **Then** startup hydrates appearance before mounting the app, and accepted changes persist under the isolated `cw2.settings.*` namespace
- **Then** defaults are system mode, normal density, dynamic colors enabled, no selected preset or custom seed, standard contrast and AMOLED disabled; a new install (storage with no schema marker and nothing saved yet) starts on the GitHub preset instead, saved at once so it holds, while an existing install keeps what it had and a later choice of the default stays (#553)
- **Then** a stored `visualStyle` value is ignored on load, whatever it is (missing, classic, refined or invalid), and is never written or deleted; missing or invalid fields do not cause default values to be written over stored preferences
- **Then** nullable preset and seed selections can be cleared without altering unrelated settings
- **Then** a load/save failure keeps the app usable and shows an appearance-storage error with a retry action

### V2 endpoint profiles and compatibility

- **Given** the user opens `/hosts` in the explicit v2 app
- **When** native profile storage is available
- **Then** saved servers retain their labels, authored URLs, proxy paths and ports across restarts; passwords remain in the origin/profile-scoped credential vault, never in profile metadata
- **Then** each saved server keeps the harness chosen when it was added (OpenCode today); servers saved before that choice read as OpenCode, the kind is fixed when the server is added and never changes its binding (#504)
- **Then** one Add server action opens a single add screen, the `/pair` route on every width (a full page on compact windows, a dialog over the server list from 600 dp, where a tap beside it closes it, to the server list when a link opened it), which Pair again and Renew also open (#506): a harness picker on top (OpenCode selected; Codex listed but disabled as Coming soon), then a Pairing link | Manual switch that opens on the pairing link; the add screen never shows the server version, and a successful save closes it and returns to where it opened, or to the server list when a link opened it directly, even under a dialog over the app (#504); a pairing link arriving while the Manual form checks drops that check, whose late answer neither saves nor closes the screen, and shows the link mode
- **Then** each saved server keeps localized check and delete actions; an in-flight saved-server check shows progress and disables repeated checks
- **Then** a catalog read failure displays a retry action rather than claiming there are no saved servers; malformed records and future schemas are preserved

- **Given** the user enters an HTTP(S) endpoint and password in the Manual form
- **When** Save runs on an IO platform, which first checks the server (#504)
- **Then** a bounded, authenticated, read-only `/api/info` probe verifies OpenCode 2 without adopting response URLs or rewriting the authored port
- **Then** credentials, HTML responses, unrecognized data, unreachable servers and service starting/stopping/failure states have distinct localized outcomes
- **Then** only a restricted fallback to healthy OpenCode 1 JSON at `/global/health` opens a full-screen upgrade explainer with server upgrade guidance and the stable CodeWalk 1 download link
- **Then** a usable answer saves the server at once; every valid stable OpenCode 2 version from `2.0.20` on is compatible and shows no tested or untested marker (#507)
- **Then** a check that fails (wrong password, unreachable, starting, below `2.0.20` and the like) shows its reason and offers Save anyway, which saves that exact URL and password as an Offline server the health lane keeps checking; editing either field withdraws the offer, and an OpenCode 1 server or a check that never reached a server is never saved; a server that asks to wait more than a day is saved with that request kept, so the app does not check it before a restart and the screen promises no automatic check, and a Retry-After that holds Save stays on screen with its reason; leaving the screen during a check saves nothing (#504)
- **Then** the Manual form refuses, before any check, a name over 160 characters or with control characters and a password over 16384 characters or with control characters
- **Then** retry hints delay manual checks without automatic HTTP replay, and changed input or a superseding probe invalidates the previous save authorization

- **Given** a checked, usable endpoint is saved or deleted
- **When** persistence is interrupted or reports an uncertain result
- **Then** nonsecret, explicitly scoped creation/removal intents allow catalog recovery without scanning credentials or touching importer-owned records
- **Then** a committed save still succeeds when the subsequent list refresh fails; the error card retries only catalog loading
- **Then** an uncertain create must be reconciled before another identity is allocated, and a failed save requires a fresh connection check before retrying
- **Then** browser endpoint probing reports unsupported rather than attempting an unverified transport

### V2 pairing and credential recovery

- **Given** the user opens the add screen's pairing link mode from Hosts, a private deep link, or a native launch argument
- **When** a pairing link is pasted or obtained from a QR
- **Then** Android offers camera capture and Android/Linux offer PNG/JPEG image import; the user confirms the validated destination before any server request
- **Then** code, token and password values remain out of routes, status messages and diagnostics; input containing pairing material is masked
- **Then** a single JSON redemption verifies the received token before saving; expired/used or uncertain challenges require a new link rather than automatic replay
- **Then** if a token was received but verification or storage failed, it can be rechecked without redeeming the same challenge again

- **Given** a saved paired profile needs a new credential
- **When** the user selects Pair again, Renew token, or password repair
- **Then** Pair again and Renew token open the add screen in pairing link mode for that server, without the harness picker or the Manual form; password repair keeps its own dialog
- **Then** the profile ID, label, URL, port and proxy prefix remain unchanged; a repair link must match the exact selected endpoint
- **Then** password repair keeps URL and label read-only and sends the password only to the selected profile's endpoint
- **Then** renewal is manual and issues a successor only after verifying the connected server is OpenCode `2.0.22`
- **Then** declared expiry is displayed only for the known token format verified on `2.0.21`/`2.0.22`; opaque credentials have no invented expiry date
- **Then** expired or refused authentication offers Pair again without deleting profiles, credentials or local data

- **Given** a profile credential or pairing operation cannot be reconciled
- **When** the catalog is loaded or a save finishes asynchronously
- **Then** an unreadable credential is reported on its own profile while healthy profiles remain visible, and corrupt/future secure records never fall back to an older password
- **Then** a save from an obsolete pairing session does not clear a newer link or received token; a verification invalidated before persistence cannot start a replacement
- **Then** an already-started, authorized write can finish, with its outcome reconciled without blind rollback
- **Then** image decoding caps app-retained input and geometry, validates PNG/JPEG dimensions before raster allocation and waits for the decoding worker to exit after cancellation; these are not OS-cache or absolute-memory guarantees

### V2 diagnostics and release history

- **Given** the user opens Settings > App Logs
- **When** diagnostic collection has not been explicitly enabled
- **Then** collection is OFF and no event timestamps or diagnostic context are constructed
- **Then** the local choice persists under `cw2.settings.loggingEnabled`; an unreadable initial preference stays OFF, while a failed reload preserves already known intent
- **When** collection is enabled
- **Then** only finite operation/outcome/severity values, timestamps and bounded durations are retained in memory, with at most 1,000 events and 256 KiB of serialized data
- **Then** URLs, profile IDs, headers, credentials, raw payloads, messages, errors and stacks have no input path into this diagnostic buffer
- **Then** disabling clears the buffer immediately; failed preference saves show retry without claiming the choice is saved
- **Then** filters select operation, outcome and severity; explicit clipboard copy is limited to 64 KiB and reports failure or truncation without raw exception text
- **Then** changing consent invalidates pending copy-success feedback; contents already written to the operating-system clipboard cannot be revoked
- **Then** a committed profile removal is reported separately from a failed subsequent catalog refresh

- **Given** the user opens Settings > Version and updates (#519)
- **Then** the installed version and update controls come first and the release history follows below them in the same scroll; Settings search finds this one destination by update or history words
- **Then** the news card of the installed release, at the top of Settings and in About, has a small X at its top end that dismisses it at once, and its What's new and Our group buttons; once seen in Settings it stays until they close, is not announced in the workspace, and is gone from the next visit, as if dismissed (`cw2.updates.dismissedNewsTag`), even when Settings close while that is written (#552)
- **Then** the news card's What's new and About's Release history open it scrolled to the history heading, which stays in view while the history loads or an update card appears above it, until the user scrolls; selecting the destination itself opens it at the top, also when it is already open
- **When** native loading is available
- **Then** the public fixed GitHub changelog is read without profile authentication, redirects or automatic replay, with a 256 KiB body limit and bounded timeouts
- **Then** the isolated `cw2.releaseHistory.cache` stores a validated envelope of at most 512 KiB, with one-hour freshness and coalesced loading
- **Then** invalid, shortened, unavailable or unsavable refreshes preserve the previous saved copy and offer manual retry; a future cache timestamp cannot establish freshness
- **Then** strict stable-version headings, real calendar dates, duplicate detection and nonempty release content are checked; BOM/CRLF and original-language leading multiline announcements are preserved
- **Then** an empty announcement marker cannot replace valid cached notes; announcement-only releases containing text remain valid
- **Then** versions appear newest first in batches of 20, with highlighted announcements and expandable selectable plain-text notes
- **Then** opening or refreshing this page neither acknowledges update announcements nor installs an update
- **Then** v2 release-body entries from the updater catalog are merged with the permanent stable archive in SemVer order; stable archive entries win duplicates, while beta notes never add incompatible headings to `CHANGELOG.md`
- **Then** disposed or superseded loads cannot publish stale results; unsupported fetch platforms can still display a previously saved copy

- **Given** CodeWalk 2 runs on Android arm64, Linux x64 or Linux arm64
- **Then** automatic discovery defaults ON under `cw2.updates.checkOnOpen`, checks at startup and hourly while the process is alive, coalesces concurrent requests and reuses a successful result for one hour
- **Then** Settings entry independently checks at most every 20 minutes even when automatic discovery is disabled; explicit Check bypasses the successful-result cache, while successful silent checks show no up-to-date message
- **Then** HTTP 403/429 quota responses retain their retry deadline under `cw2.updates.retryAt` across restarts and block automatic, Settings and manual requests until expiry; malformed or implausible deadlines beyond 30 days use a valid reset header or a one-hour fallback instead of permanently disabling discovery
- **Then** failed silent checks preserve usable candidates/history; a later silent success clears a stale error without presenting a manual-success message
- **Then** the channel defaults to `stable`; explicit Beta opt-in persists under `cw2.updates.channel`, with unreadable preferences keeping stable
- **Then** public release discovery sends no profile credentials, reads the newest-first listing in pages of 20 and stops at the page holding a release created before `v2.0.0-beta.1`, within 50 pages, 2 MiB/page, 8 MiB total and a 30-second deadline, and rejects incomplete, invalid, redirected or non-identity responses
- **Then** when the saved catalog already holds the installed release, the listing stops at the page holding the installed tag, usually one request, and the saved catalog supplies the older history; this relies on releases being created in version order
- **Then** a failed check names its cause: GitHub's rate limit, an answer CodeWalk could not read (malformed, oversized, unexpected status or an exhausted listing), or otherwise the connection, including timeouts
- **Then** strict SemVer ordering, canonical major-2 tags, exact architecture assets and exact-tag GitHub URLs apply; Beta accepts `v2.0.0-beta.N` (`N >= 1`, `prerelease: true`) and stable major-2 releases above it, while stable never offers prereleases or v1 cohorts
- **Then** Settings and About show installed version/build and a dismissible update card; update dismissal persists per tag independently of installed-release news dismissal
- **Then** installed-release news shows the complete announcement with history/group actions when no visible update takes priority; startup/hourly update and news notices have independent per-version/process flags and foreground/modal guards
- **Then** the complete v2 API catalog supplies beta history and full announcements; its `cw2.updates.catalog` envelope is capped at 512 KiB, with invalid or oversized refreshes preserving the prior saved copy instead of truncating it
- **Then** installed-release intervals under `cw2.updates.installedRelease` retain unseen announcements across upgrades and offline launches; incomplete catalog coverage cannot acknowledge an interval
- **Then** a fresh v2 install establishes a baseline without a cumulative dialog; existing v2 evidence can show the installed release, without reading or importing v1 settings, profiles or credentials
- **Then** nonempty cumulative batches are acknowledged only by explicit Close with the checkbox checked; Back, barrier dismissal or unchecked Close retain the interval for a later process, while an empty covered interval needs no dialog
- **Then** cumulative acknowledgment does not dismiss the independent news toast/card; a dialog already shown suppresses duplicate news for its tags only in that process
- **Then** Android downloads the exact APK in-app into persistent non-backed-up storage (`noBackupFilesDir/updates`) with a metadata sidecar, validates its manifest, size, complete SHA-256 on download and again before installation, application/signer identity and strictly increasing versionCode, and commits the verified file through a native `PackageInstaller` session (`MODE_FULL_INSTALL`); on Android 8+ (API 26+) if `canRequestPackageInstalls()` is false it opens `Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES` for CodeWalk and continues directly into the session if granted on return (or reports `installerDenied` if still ungranted); on Android 12+ (API 31+) it declares `UPDATE_PACKAGES_WITHOUT_USER_ACTION` and sets `USER_ACTION_NOT_REQUIRED` so self-updates proceed without a confirmation prompt whenever the OS criteria hold (while Google Play Protect scanning and device policy remain system-controlled and are not bypassed); if the system returns `STATUS_PENDING_USER_ACTION` it launches the native confirmation `Intent.EXTRA_INTENT`; if the user cancels (`STATUS_FAILURE_ABORTED`, or dismisses the confirmation dialog) the update returns cleanly to `ready` (`Install`) with no error message; after a CodeWalk-initiated self-update replaces the package (`ACTION_MY_PACKAGE_REPLACED` matching the private 24-hour `cw2_apk_update` marker, never firing on external or ADB installs), it posts a local notification (`POST_NOTIFICATIONS` requested once on Android 13+ without blocking installation on denial) that reopens `MainActivity` on tap
- **Then** partial identity includes exact URL, size and digest; valid `Range`/`If-Range` responses resume, full responses restart, invalid partial/416 responses restart safely, and reconstructed bytes are hashed in full before installation
- **Then** transient failures retain resumable partials; explicit cancellation removes partials, any cached verified APK and the native update marker; filesystem and `STATUS_FAILURE_STORAGE` errors are reported as storage failures, and errors distinguish transport, HTTP, integrity, downgrade, size and installer failures
- **Then** an ordinary release check cannot cancel an active transfer; a verified cached Android APK that was postponed or whose installation failed survives the 24-hour partial cleanup and app restarts (restoring in `idle` so it does not block release/news notices, surfacing the hamburger download icon and drawer one-tap quick-install tile, and deleting itself automatically once installed, superseded by a newer verified download, explicitly cancelled, or corrupt), and retrying an installer or storage failure reopens the cached verified APK without downloading again
- **Then** global progress survives route changes; closing its presentation does not cancel the operation, and a completed Android installer handoff no longer blocks later notices
- **Then** Linux in-app installation is available only for the running managed v2 bundle with its packaged installer; it verifies exact-tag/architecture manifest and SHA-256 before running that trusted script with an exact tag/channel and migration disabled
- **Then** Linux partials, sidecars and installer temporaries stay in a private 0700 cache; links cannot redirect writes or APK cleanup, and stale owned partials/installer temporaries are removed after 24 hours without following links
- **Then** Linux uses staging/rollback, preserves user-data directories, bounds installer waiting and sends process-group termination signals on cancellation/timeout; no Linux package-signature guarantee is claimed
- **Then** Linux offers restart only after installation succeeds and the installed tag matches; drafts/preferences/metadata flush before relaunch, which starts in the user's home directory, inherits the desktop environment and requests exit of the old app
- **Then** Linux native startup preserves a usable working directory; if an older updater launches it from a removed installation directory, it recovers to the absolute home directory or `/` before Flutter starts, preserving access to the installed version and saved settings
- **Then** packaged Linux release validation covers both usable and removed working directories, startup version metadata and preferences retained on disk; applied Beta/theme selections require separate GUI evidence
- **Then** unsupported/older/unmanaged Linux installs retain a copyable exact-tag installer command, and changing channel clears a failed Linux retry target rather than offering a stale beta
- **When** the platform has no supported native update target (including Windows and macOS, which update through the desktop installer scripts `install.ps1` and `install.sh`)
- **Then** the update page offers no check/install route and the application does not construct Android APK cleanup on that platform

Session-detail routes retain their navigation placeholders; the conversation
catalog does not fetch history, attach live execution, send prompts or mutate sessions.
Locale changes exposed by the v2 controller persist under `cw2.settings.locale`;
other feature-specific settings controls and full rendering parity remain
in their owning Issues. Hosts, settings and appearance widget/golden tests cover mobile and desktop viewports on
the Flutter VM; they do not certify installed native targets.
