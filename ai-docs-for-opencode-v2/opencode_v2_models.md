# OpenCode v2 — Model and Agent Contract Anchor

> **Scope:** model/agent/catalog consumers authored for CodeWalk v2. The v1/retained reference implementation uses [the legacy model anchor](../ai-docs/opencode_models.md). This is pinned upstream evidence, not an implemented v2 selector or a live compatibility result.

## Provenance

| Source | Versioned evidence |
|---|---|
| Official model documentation | [Live page](https://opencode.ai/docs/models/), MDX [`services/site/src/docs/content/models.mdx`](https://github.com/anomalyco/opencode/blob/c0ad18b402eb2827fc1ee71c171b1177b3fc02d1/services/site/src/docs/content/models.mdx), rechecked 2026-11-22 |
| Official agent documentation | [Live page](https://opencode.ai/docs/agents/), MDX [`services/site/src/docs/content/agents.mdx`](https://github.com/anomalyco/opencode/blob/c0ad18b402eb2827fc1ee71c171b1177b3fc02d1/services/site/src/docs/content/agents.mdx) |
| Docs route | `/docs/` is the V2 root; `/v1/docs/` is the legacy set, and `/v2/docs/` only redirects to `/docs/`. MDX moved from `services/www/src/docs/content/` to `services/site/src/docs/content/` |
| Protocol/schema pin | `v2.3.2`, commit `c0ad18b402eb2827fc1ee71c171b1177b3fc02d1`, tagged 2026-11-18 |
| Frozen local snapshot | The 2026-10-02 capture in [`plan/opencode-v2-docs/`](../plan/opencode-v2-docs/INDEX.md) (docs commit `bb381e8b…`, protocol `v2.0.21`) remains history, not current documentation |

Native schemas/protocols outrank a historical summary or a list of recommended models. Runtime availability is project-specific; revalidate against the connected server/fixtures through SP-01 and the owning selection work item.

## Catalog and project availability

| Route | Pinned source meaning |
|---|---|
| `GET /api/model` | Location-scoped `Model.Info` snapshot ordered by release date within each type; the `types` query defaults to `chat`, the only type offered for sessions. It may precede initial plugin settlement |
| `GET /api/model/default` | Location-scoped model used when a session has no explicit selection; the result can be absent |
| `GET /api/agent` | Location-scoped currently registered `Agent.Info` entries |
| `GET /api/agent/{agentID}` | One registered agent, with native not-found semantics |

See the pinned [model protocol](https://github.com/anomalyco/opencode/blob/c0ad18b402eb2827fc1ee71c171b1177b3fc02d1/packages/protocol/src/groups/model.ts), [agent protocol](https://github.com/anomalyco/opencode/blob/c0ad18b402eb2827fc1ee71c171b1177b3fc02d1/packages/protocol/src/groups/agent.ts) and [location scoping](opencode_v2_server.md). The model group still annotates itself as experimental; preserve the exact version and compatibility evidence rather than assuming permanence from a generic endpoint index.

The official selector shows enabled models whose provider is available in the current project. Credentials/configuration in another project do not establish availability here. Preserve native identifiers and current metadata; do not derive a model list from the v1 `/provider.connected` route or a CodeWalk-specific static allowlist. Catalog/update events require a fresh native snapshot, not a hardcoded vendor/model roster. When the configured default is unavailable, the documented behavior is a fallback to the newest available supported model; a session that already selected a model keeps it.

## References and variants

The pinned [Model.Ref schema](https://github.com/anomalyco/opencode/blob/c0ad18b402eb2827fc1ee71c171b1177b3fc02d1/packages/schema/src/model.ts) is:

```ts
{ id: string, providerID: string, variant?: string }
```

Its text syntax is `provider/model#variant`; `#variant` is optional. Variant names come from the current model's catalog, not a universal `low`/`high`/`max` enumeration. Unknown variants produce native resolution errors. The configured root default retains provider/model, not necessarily the variant; a session's explicit model takes precedence and switching it does not rewrite the configuration file.

`Model.Info` exposes `id`, `modelID`, `providerID`, optional `canonical`, `type` and `family`, name, optional `compatibility` and `package`, optional `settings`/`headers`/`body` overlays, native `capabilities` (tools, optional freeform formats, input, output, optional temperature), `variants`, `time.released`, a `cost` array with per-million-token entries and optional context tier, `status` (`alpha`/`beta`/`deprecated`/`active`), `enabled`, and `limit` with context/input/output. Treat `type` as open-ended: `chat`, `decision`, `image`, `video` and future values share the same codec. These are versioned native fields, not reasons to fabricate missing usage/quota values; context limits and price metadata are not an API for remaining provider quota.

The pinned [Agent.Info schema](https://github.com/anomalyco/opencode/blob/c0ad18b402eb2827fc1ee71c171b1177b3fc02d1/packages/schema/src/agent.ts) exposes `id`, `name`, optional `model`, `request` (`settings`/`headers`/`body`), optional `system`, `description` and `color`, `mode` (`primary`/`subagent`/`all`), `hidden`, optional `steps`, and `permissions` as a `Permission.Ruleset`. There is no `permission` map in the native V2 payload any more: the ruleset is an ordered list of `{action, resource, effect}` rules where the last match wins. Preserve unknown values; permission interaction and automatic replies are owned by their separate contract and ADR work.

## Session-level selection

The pinned [session protocol](https://github.com/anomalyco/opencode/blob/c0ad18b402eb2827fc1ee71c171b1177b3fc02d1/packages/protocol/src/groups/session.ts) defines:

| Mutation | Payload / effect |
|---|---|
| `POST /api/session/{sessionID}/model` | `{model: Model.Ref}`; selects the model used by subsequent provider turns |
| `POST /api/session/{sessionID}/agent` | `{agent: Agent.ID}`; selects the agent used by subsequent provider turns |

Both answer `204 No Content`. Model/agent selection and prompt admission are distinct operations; do not carry the v1 per-send payload contract into v2. Reconcile selection outcomes and apply the desired selection to the intended session before send. A native model-switch event updates canonical state; a generic command ID is not proof that repeating a selection mutation is safe.

`session.model.selected`, `session.agent.selected`, `model.updated` and `agent.updated` are native inputs. Their schema/event provenance is in the [event dossier](../plan/12-opencode-v2-events-and-schemas.md) and the [official reference reducer](../plan/opencode-v2-src/client-solid-data.reference-reducer.ts). Multi-host/session identity belongs to the CodeWalk domain; never key a selection solely by a coincident native ID across hosts.

## Configuration semantics consumed by the selector

The current V2 docs define the configuration the catalog reflects; these are documentation facts at the 2.3.2 pin, not additional wire fields.

- `model` in `opencode.json`/`opencode.jsonc` sets the default for new work and becomes the catalog default only while it is enabled and its provider is available.
- `--model` selects a model for one CLI run; agents and commands may carry their own model. The session selection stays separate from the configured default.
- `OPENCODE_DISABLE_FREE_MODELS=1` removes zero-input-price `opencode`/`opencode-go` models from the catalog and defaults; explicitly selecting one then fails as `Model unavailable`.
- `providers.<id>.models.<id>.variants[]` replaces or extends catalog variants with `id`, `settings`, `headers` and `body`; `capabilities.reasoning` (`supported`, `toggle`, `effort`, `budget`) builds the reasoning variants. Provider values apply first, model values second, the selected variant last.
- `providers.<id>.models.<id>.modelID` gives an API model a friendlier catalog ID; unknown models fall back to text/image input, 200k context, 32k output, and `disabled: true` hides a model from the catalog.
- Agents are configured under `agents` (JSONC) or as Markdown files in `~/.config/opencode/agents/<name>.md` and `.opencode/agents/<name>.md`, where a nested path becomes part of the ID. `default_agent` selects the primary agent only when it exists, is visible and supports primary use; otherwise OpenCode uses `build`, then the first visible primary-capable agent.
- Built-in visible agents are `build` and `plan` (primary), `general` and `explore` (subagent). `compaction`, `title` and `summary` are hidden maintenance agents. V2 has no built-in `scout` agent.
- `steps` caps model steps and removes tools on the final step; `hidden` removes an agent from listings and the subagent catalog but is not a security control; `disabled` removes a built-in or custom agent at that point in configuration loading; `request` overlays headers/body per agent but the V2 session runner preserves them without sending them yet.

## Observed free models and attachment boundary

[A/B/C/E native 2.0.22 fixtures](../test/contract/fixtures/opencode/2.0.22/README.md)
record enabled zero-cost `opencode` models and successful real turns; catalog
availability/zero price does not guarantee a provider will authorize a request.
B records Fledge and E records Muse Spark provider.auth 403 free-tier failures;
these do not authorize credential/header workarounds or paid fallback.

[E attachment evidence](../test/contract/fixtures/opencode/2.0.22/e/README.md)
proves a PNG attachment-only marker recognized without tools. Official 2.0.21
and 2.3.2 projections forward PDF media, and E verifies PDF admission/native
history MIME; its declared PDF-capable free model failed provider authentication,
so PDF recognition remains unverified. Model capabilities, upstream attachment
forwarding and the approved CodeWalk PDF-disabled product policy are separate
facts. The policy remains unchanged pending a new product decision.

## Acceptance boundary

SP-01 establishes observed catalog/agent/model behavior on the connected version. `V2-054` owns race and session-targeting checks before the actual selector is accepted. Unknown/default/variant/availability cases remain typed and evidence-backed; the document does not certify plugin settlement, a model switch during send, or a fallback on an untested server. The 2.0.22 fixtures above are runtime evidence for that version only; the agent schema, routing and docs claims were read at the 2.3.2 pin and still need a runtime pass there.

- [Official V2 documentation](https://opencode.ai/docs/), [models](https://opencode.ai/docs/models/) and [agents](https://opencode.ai/docs/agents/).
- [Server anchor](opencode_v2_server.md) and [Web anchor](opencode_v2_web.md).
- [Implementation plan](../v2-plan.md), §§5.11, 6.4–6.10 and V2-054.
- [ADR registry](../ADR.md), ADR-023 principle and ADR-058 v2 implementation-line scope.
