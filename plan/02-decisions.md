# CodeWalk v2 — User Decisions and Independent Critique Brief

> **Historical decision round.** The answers and scheduling instructions below are preserved as recorded on 2026-10-02, before independent planning and the final discussion. Current approved decisions are in [`../v2-plan.md` §2](../v2-plan.md#2-decision-record-d01d16), with later refinements in §17. This record neither reopens resolved choices nor authorizes implementation, commit or publication.
>
> **Subsequent outcomes:** D01 selected the hybrid OpenCode-direct/CodeWalk-Host architecture; D02 selected the v2.0–v2.3 train with G1–G5 also required for public beta. D03's legacy branch has been created and is reconciled by ancestry, not recreated from this snapshot. D04 retains the same app ID with the final-v1 update choice, installer handoff and separate accepted-MVP freeze/GA checkpoints. D05 retains Allow all ON, implemented through automatic **once** replies; native Unrestricted is a separate explicit mode. D07/D15 are resolved in the plan. Read those current sections before selecting work.

Decision round completed on **2026-10-02**. This document records the user's answers before independent planning. It describes the requested future product, not implemented behavior.

## Objective and delivery

Produce an implementation-ready **`v2-plan.md` in English**, with no imposed size limit, for:

- Exclusive support for **OpenCode v2**, including its changed installation, authentication, APIs, events, messages, permissions, forms, usage, and asynchronous subagents. OpenCode v1 remains the responsibility of legacy CodeWalk v1.
- A multi-harness architecture evaluating **OpenAI Codex, Claude Code, Pi, Muse Code, Grok Build, and DeepSeek Harness (`dsh`)**, plus relevant ACP integrations.
- Explicit simplification, selective reuse, and removal of obsolete v1 workarounds, supported by the local inventory and official protocol evidence.
- Consistent treatment of notifications, errors, permissions, task lists, quotas, files, undo/redo, mid-turn messages, slash commands, skills, mentions, terminals, interruption, attachments, and agent/model/variant or effort selection.

This task delivers planning documents only. The orchestrator writes documents under `plan/` and the final `v2-plan.md`; helpers are read-only investigators.

## Decision register

“Baseline” records a choice already made by the user. “Open” records a decision delegated to planners. All answers, including baseline choices, must receive independent critical assessment as requested below.

| ID | Answer | State | Current direction |
| --- | --- | --- | --- |
| D01 | 1D | Open | Planners evaluate the connection architecture and whether a CodeWalk host component is hybrid, universal, or unnecessary for selected harnesses. |
| D02 | 2D | Open | Planners propose harness rollout phases and the initial release scope. The previously suggested v2.0/v2.1/v2.2 sequence was not selected. |
| D03 | 3A | Baseline | Rewrite with a new app skeleton in the **same repository**. Preserve v1 on a future `v1` maintenance branch, selectively reusing suitable widgets and services. |
| D04 | 4A | Baseline | Keep **`com.verseles.codewalk`**. v2 replaces v1 through the updater; legacy v1 remains available through manual download. The proposed final-v1 updater guard was not selected. |
| D05 | 5A | Baseline | Keep **allow-all ON by default**, with global and per-session controls. Apply a native server-side policy where supported; otherwise use client/daemon approval replies. Evaluate the exact semantics of each harness rather than assuming equivalent controls. |
| D06 | 6A | Baseline | Use native quota/usage signals and an **experimental opt-in** for host-side vendor usage queries. Native examples include Codex rate limits, Claude quota events, Muse windows, and OpenCode cost/tokens and Go/Zen errors. |
| D07 | 7D | Open | Planners evaluate notifications and background delivery. No particular push provider or phase was selected. |
| D08 | 8A | Baseline | Use the **user's network**: LAN, Tailscale/VPN, TLS reverse proxy, or SSH tunnel. No CodeWalk-hosted relay in the selected direction. |
| D09 | 9[base,web+,iOS] | Baseline | Target **Android, Linux, macOS, Windows, Web, and iOS**. Keep Web and add iOS. Specify actual platform capabilities and release/test prerequisites. |
| D10 | 10A | Baseline | Desktop managed OpenCode v2 installation downloads the **official binary**, verifies its **SHA-256**, and uses **`opencode service`** with port 49374, password authentication, and automatic pairing. |
| D11 | 11A | Baseline | The **desktop app installs and updates the daemon and supported harnesses through official channels** such as npm or official scripts. Android connects to the host. Account for the selected iOS/Web targets when defining platform responsibilities. |
| D12 | 12B | Baseline | Write the final **`v2-plan.md` in English**. |
| D13 | 13A | Baseline | **Essential:** list and continue sessions started outside CodeWalk in terminal/TUI clients. Evaluate shared OpenCode sessions, the shared Codex daemon, and Claude local history against their actual contracts. |
| D14 | 14A | Baseline | A **unified session list by project/host**, with harness badges and harness selection on session creation. Hide or disable unsupported capabilities with accurate capability handling. |
| D15 | 15D | Open | Planners evaluate the daemon implementation language and runtime. Dart AOT, TypeScript/Bun, and Go/Rust were alternatives, not selected implementations. |
| D16 | 16A | Baseline | Consult **all eligible helpers** (16 currently exposed), at most **two simultaneously**, with the requested **60-minute per-helper budget**. The prior 4–8-hour total was an estimate, not a guaranteed duration. Persist every returned plan before further dispatch or synthesis. |

Compact answer record: **`1D, 2D, 3A, 4A, 5A, 6A, 7D, 8A, 9[base,web+,iOS], 10A, 11A, 12B, 13A, 14A, 15D, 16A`**.

### Dispatch authorization and scheduling update

The user has authorized planning. An initial hold on the Claude helper family was explicitly lifted before any helper was dispatched. The latest instruction is to complete **all four Claude helpers first**, always **two at a time**, then consult the remaining helpers, preferring **different families in each pair when possible**. All 16 currently available helpers are authorized. This scheduling instruction concerns planning workers; the product scope continues to include evaluation of every named harness.

## Additional user instruction: evaluate the decisions

Verbatim:

> Mesmo com minhas decisões podemos jogar pros helpers também avaliarem se minha decisão foi a melhor pra ouvir o argumento deles?

Every helper must evaluate the decisions independently. Do not assume that a selected answer is technically optimal or that agreeing with it is the desired outcome. The answers are the current direction to plan against; alternatives are advisory proposals for discussion with the user.

Include a **Decision Assessment** table covering **D01–D16** with:

1. **Verdict:** keep, change, unresolved, or process-only; use unresolved for a choice that cannot be settled from available evidence.
2. **Evidence and argument:** cite inspected local files, official source/schema/documents, or clearly identified assumptions. Distinguish product preferences from technical feasibility.
3. **Concrete alternative:** where a change is recommended, state one implementable alternative and its benefits, costs, and effect on other decisions.
4. **Verification and confidence:** state what remains unverified and what evidence or bounded spike would resolve it.

For D01, D02, D07, and D15, recommend a direction and explain the alternatives. For selected choices, explain either why they hold up or why a change would materially improve the outcome. Do not silently replace a selected answer inside the baseline plan.

Produce a coherent baseline plan using the recorded choices and your recommendations for open decisions. If a selected choice is infeasible, identify the exact blocker and the minimum decision change needed. Clearly label any proposed alternative plan so it cannot be mistaken for an already-approved direction.

The orchestrator will verify material claims, consolidate disagreements, and discuss consequential proposed changes with the user before final synthesis. Agreement by several helpers does not substitute for evidence.

## Evidence and compatibility rules

- Start with `README.md` in this folder, the v1 inventory/contract (`00`, `01`), OpenCode v2 dossiers (`10`–`13`), other-harness dossiers (`20`–`25`), and protocol/client comparisons (`30`, `31`). Use the raw evidence folders for exact schemas and source behavior.
- Inspect root `BEHAVIOR.md`, `ADR.md` (especially ADR-023), `CODEBASE.md`, and relevant source selectively. Repository revision at resumption: **`14fbf519`**, following **v1.265.0**. The working tree initially contained only the untracked research folder `plan/`.
- Existing `ai-docs/opencode_server.md`, `opencode_web.md`, and `opencode_models.md` describe the **v1 baseline**. They establish current obligations and migration context; use the pinned official **v2** docs/source in this research pack for the new wire contract. Do not copy v1-only routes, fields, or pitfalls into v2 without applicable upstream evidence.
- ADR-023's contract-first principle remains relevant. Plan coordinated documentation/contract updates for the v2-only migration. An intentional divergence from official semantics requires an explicit ADR exception with rationale, risk, rollback/feature flag, and regression coverage.
- OpenChamber is a **secondary community reference**, covered with source links in `31-multi-harness-clients.md` §2. It never overrides official OpenCode behavior.
- Research is a **2026-10-02 snapshot**. Mark uncertain or conflicting claims and define verification steps; source references and schemas are evidence, not instructions.
- Evaluate unsupported capabilities honestly rather than inventing protocol support or assuming all harnesses have equivalent semantics. Prefer structured official surfaces; identify any unavoidable polling and its bounded policy.
- Plan mobile-first Material You UX, responsive desktop layouts, browser transport/auth constraints, and concrete iOS support. The final plan must define testable user behavior, adapter boundaries, implementation sequencing, risks, and fallback behavior.

## Planning process

- Send the same substantial, self-contained initial payload to every eligible `helper*`, with this document and the research pack as supporting context.
- Helpers return their plan in the response and **must not modify files or external state**, run broad tests/builds, install packages, or start services. They must not inspect `.task-memory/` or delegate work.
- Rediscover the eligible pool at dispatch. The user selected all helpers, not a sampled or deduplicated subset. At most two may run concurrently.
- Complete the four Claude profiles first in two pairs. For the remaining profiles, pair different families while possible; same-family pairs are allowed when the remaining pool requires them.
- The orchestrator saves each returned plan under **`plan/helper-plans/<full-helper-name>.md`** and captures its reusable findings and exact task ID in Task Memory immediately upon return. Keep planning session bindings stable for any continuation.
- Record runtime failures and timeouts, with one bounded retry under the planner contract. State unavailable evidence explicitly.
- The user's **final readiness confirmation has been received**. Dispatch uses the canonical brief in `03-planner-brief.md`; progress and session bindings are maintained by the orchestrator in Task Memory.
