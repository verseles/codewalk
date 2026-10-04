# OpenCode v2 — Model and Agent Contract Anchor

> **Scope:** model/agent/catalog consumers authored for CodeWalk v2. The v1/retained reference implementation uses [the legacy model anchor](opencode_models.md). This is pinned upstream evidence, not an implemented v2 selector or a live compatibility result.

## Provenance

| Source | Versioned evidence |
|---|---|
| Official model documentation | [Live page](https://opencode.ai/v2/docs/models/), [immutable MDX](https://github.com/anomalyco/opencode/blob/bb381e8bdd1ff22c7329e07c068ec0099031f382/services/www/src/docs/content/models.mdx), [preserved snapshot](../plan/opencode-v2-docs/docs-models.md), captured 2026-10-02 |
| Docs pin / recheck | `bb381e8bdd1ff22c7329e07c068ec0099031f382`; source existence rechecked 2026-10-03 |
| Protocol/schema pin | `v2.0.21`, commit `8a8bd622a3d7dc29ccf30ec17f84e363ed95ed72` |
| Exact protocol extract check | [Official model group](https://github.com/anomalyco/opencode/blob/8a8bd622a3d7dc29ccf30ec17f84e363ed95ed72/packages/protocol/src/groups/model.ts) and [local extract](../plan/opencode-v2-src/protocol-groups/model.ts) both have Git blob SHA `4b8ebee3491c8bbb054a6b089da0831eae5c59fc` |

Native schemas/protocols outrank a historical summary or a list of recommended models. Runtime availability is project-specific; revalidate against the connected server/fixtures through SP-01 and the owning selection work item.

## Catalog and project availability

| Route | Pinned source meaning |
|---|---|
| `GET /api/model` | Location-scoped `Model.Info` snapshot, ordered by release date; it may precede initial plugin settlement |
| `GET /api/model/default` | Location-scoped model used when a session has no explicit selection; the result can be absent |
| `GET /api/agent` | Location-scoped currently registered `Agent.Info` entries |
| `GET /api/agent/{agentID}` | One registered agent, with native not-found semantics |

See [model protocol](../plan/opencode-v2-src/protocol-groups/model.ts), [agent protocol](../plan/opencode-v2-src/protocol-groups/agent.ts) and [location scoping](opencode_v2_server.md). The model group describes its routes as experimental in the pinned definition; preserve the exact version and compatibility evidence rather than assuming permanence from a generic endpoint index.

The official selector shows enabled models whose provider is available in the current project. Credentials/configuration in another project do not establish availability here. Preserve native identifiers and current metadata; do not derive a model list from the v1 `/provider.connected` route or a CodeWalk-specific static allowlist. Catalog/update events require a fresh native snapshot, not a hardcoded vendor/model roster.

## References and variants

The pinned [Model.Ref schema](../plan/opencode-v2-src/schema/model.ts) is:

```ts
{ id: string, providerID: string, variant?: string }
```

Its text syntax is `provider/model#variant`; `#variant` is optional. Variant names come from the current model's catalog, not a universal `low`/`high`/`max` enumeration. Unknown variants produce native resolution errors. The configured root default retains provider/model, not necessarily the variant; a session's explicit model takes precedence and switching it does not rewrite the configuration file.

`Model.Info` exposes `id`, `modelID`, `providerID`, name, enabled/status, native capabilities, variants, release time, cost metadata and context/input/output limits. These are versioned native fields, not reasons to fabricate missing usage/quota values. Context limits and price metadata are not an API for remaining provider quota.

The pinned [Agent.Info schema](../plan/opencode-v2-src/schema/agent.ts) exposes id/name, optional model, request settings, mode (`primary`/`subagent`/`all`), hidden state, optional display metadata and permission rules. Follow native agent availability/mode semantics and preserve unknown values; permission policy/automatic replies are owned by their separate interaction contract and ADR work.

## Session-level selection

The pinned [session protocol](../plan/opencode-v2-src/protocol-groups/session.ts) defines:

| Mutation | Payload / effect |
|---|---|
| `POST /api/session/{sessionID}/model` | `{model: Model.Ref}`; selects the model used by subsequent provider turns |
| `POST /api/session/{sessionID}/agent` | `{agent: Agent.ID}`; selects the agent used by subsequent provider turns |

They have no-content success schemas. Model/agent selection and prompt admission are distinct operations; do not carry the v1 per-send payload contract into v2. Reconcile selection outcomes and apply the desired selection to the intended session before send. A native model-switch event updates canonical state; a generic command ID is not proof that repeating a selection mutation is safe.

`session.model.selected`, `session.agent.selected`, `model.updated`, `agent.updated` and related integration/provider events are native inputs. Their schema/event provenance is in the [event dossier](../plan/12-opencode-v2-events-and-schemas.md) and the [official reference reducer](../plan/opencode-v2-src/client-solid-data.reference-reducer.ts). Multi-host/session identity belongs to the CodeWalk domain; never key a selection solely by a coincident native ID across hosts.

## Observed free models and attachment boundary

[A/B/C/E native 2.0.22 fixtures](../test/contract/fixtures/opencode/2.0.22/README.md)
record enabled zero-cost `opencode` models and successful real turns; catalog
availability/zero price does not guarantee a provider will authorize a request.
B records Fledge and E records Muse Spark provider.auth 403 free-tier failures;
these do not authorize credential/header workarounds or paid fallback.

[E attachment evidence](../test/contract/fixtures/opencode/2.0.22/e/README.md)
proves a PNG attachment-only marker recognized without tools. Official 2.0.21
and 2.0.22 projection forwards PDF media, and E verifies PDF admission/native
history MIME; its declared PDF-capable free model failed provider authentication,
so PDF recognition remains unverified. Model capabilities, upstream attachment
forwarding and the approved CodeWalk PDF-disabled product policy are separate
facts. The policy remains unchanged pending a new product decision.

## Acceptance boundary

SP-01 establishes observed catalog/agent/model behavior on the connected version. `V2-054` owns race and session-targeting checks before the actual selector is accepted. Unknown/default/variant/availability cases remain typed and evidence-backed; the document does not certify plugin settlement, a model switch during send, or a fallback on an untested server.

- [Official agents snapshot](../plan/opencode-v2-docs/docs-agents.md) and [source snapshot index](../plan/opencode-v2-docs/INDEX.md).
- [Server anchor](opencode_v2_server.md) and [Web anchor](opencode_v2_web.md).
- [Implementation plan](../v2-plan.md), §§5.11, 6.4–6.10 and V2-054.
- [ADR registry](../ADR.md), ADR-023 principle and ADR-058 v2 implementation-line scope.
