# Feature 012 - Model/Provider Switching and Variant (Reasoning Effort) Controls

## Goal
Enable users to change the active provider/model and the model variant (reasoning effort) in CodeWalk, with payload parity to OpenCode v2 and durable user preferences.

## Why This Exists

The current app auto-picks provider/model and does not expose model choice controls in chat UI. It also does not send `variant` in prompt payloads, which blocks “thinking effort” controls supported by upstream.

## Research Snapshot

- Upstream commit: `anomalyco/opencode@24fd8c1`.
- Primary files reviewed:
  - `packages/app/src/context/models.tsx`
  - `packages/app/src/context/local.tsx`
  - `packages/app/src/components/prompt-input.tsx`
  - `packages/app/src/components/prompt-input/submit.ts`
  - `packages/app/e2e/models/model-picker.spec.ts`
  - `packages/app/e2e/thinking-level.spec.ts`
  - `packages/sdk/js/src/v2/gen/types.gen.ts`
  - docs: https://opencode.ai/docs/models/

## Upstream Behavior (Reference)

### Model selection

- Provider list from `/provider` includes model metadata and visibility rules.
- UI allows model switching from prompt footer (`/model` command or picker).
- Recent models are persisted to support fast cycling.

### Variant/reasoning effort

- Variant is model-specific (`model.variants`).
- UI exposes `model-variant-cycle` action.
- Payload includes `variant` for:
  - `/session/{id}/message`
  - `/session/{id}/prompt_async`
  - `/session/{id}/command`

### Model metadata

- Model capabilities include reasoning support.
- Tooltip and context metrics show reasoning capability/tokens.

## Current CodeWalk Baseline (Gap)

- `ChatProvider` chooses default/first model but no selection UI in `chat_page.dart`.
- Domain `ChatInput` has no `variant` field.
- `ChatInputModel.toJson()` sends `model` and `agent` but never `variant`.
- Provider model parser (`provider_model.dart`) does not expose model variants.
- Local storage has `selected_provider`/`selected_model` but no robust multi-server-aware model preference strategy.

## Scope

### In scope

- Provider/model picker UI.
- Variant state + variant cycle UI action.
- Request payload parity (`variant` field).
- Persistence of selected/recent model and variant.
- Compatibility behavior when variant is unavailable.

### Out of scope

- Provider OAuth/auth flows.
- Advanced model visibility configuration panel parity (can be staged if needed).

## Implementation Blueprint

### 1. Domain and model schema updates

Update `lib/domain/entities/provider.dart`:

- Add model `variants` map (`Map<String, Map<String, dynamic>>?` or typed value object).

Update `lib/domain/entities/chat_session.dart`:

- Add `variant` to `ChatInput`.

Update `lib/data/models/provider_model.dart`:

- Parse `variants` from provider response.

Update `lib/data/models/chat_session_model.dart`:

- Parse/emit `variant` in `ChatInputModel`.
- Keep backward compatibility for servers ignoring this field.

### 2. Provider/model/variant state in ChatProvider

Add:

- `setSelectedProvider(String id)`
- `setSelectedModel(String id)`
- `setSelectedVariant(String? variant)`
- `cycleVariant()`

Selection rules:

1. if current model has variants:
   - cycle through variant keys, then default (`null`) state.
2. if no variants:
   - hide/disable variant control.

Persistence:

- selected provider/model per active server (and optionally per project/directory).
- selected variant per `provider/model` key.

### 3. UI controls

Composer/prompt area should include:

- provider/model selector (dialog/bottom sheet depending platform width).
- variant chip/button (visible only when model exposes variants).

Optional first phase:

- add controls to top of chat screen before embedding directly in input widget.

### 4. Send path integration

When sending message:

- include selected provider/model always.
- include selected variant when non-null.
- apply to all relevant send modes when introduced:
  - standard prompt
  - async prompt
  - command/shell style flows (future-ready interfaces).

## API Contract Notes

From OpenCode v2 types:

- Prompt body supports:
  - `model: { providerID, modelID }`
  - `variant?: string`

Model docs:

- canonical model format: `provider/model`
- canonical variant format: `provider/model:variant`

## Test Strategy

### Unit tests

- parse provider models with variants.
- variant cycle behavior (`null -> v1 -> v2 -> null`).
- request serialization includes/excludes `variant` correctly.

### Widget tests

- model picker opens and selection updates active model label.
- variant control appears only for models with variants.
- variant text updates after cycle.

### Integration tests

- mock server captures outbound body to assert `variant` presence.
- no regression when server returns models without `variants`.

## Manual QA Checklist

1. Switch provider and model; send message; verify response uses selected model.
2. Pick model with variants; cycle variant; send message; inspect payload logs.
3. Restart app and verify last model/variant is restored.
4. Switch server and ensure model preference isolation.

## Risks and Mitigations

1. Risk: invalid variant sent for selected model.
   - Mitigation: validate variant belongs to current model before send.
2. Risk: stale selected model after provider refresh.
   - Mitigation: fallback to default connected provider/model.
3. Risk: preference leakage across servers.
   - Mitigation: server-scoped keys.

## Execution Plan (mapped to ROADMAP tasks)

- `12.01` provider/model picker UI and state APIs.
- `12.02` variant parsing and availability logic.
- `12.03` variant cycle action and payload serialization.
- `12.04` persistence and restore flow.
- `12.05` automated test coverage.

## Definition of Done

- User can choose provider/model in-app.
- User can change reasoning effort via variant where supported.
- Prompt payloads include correct `variant`.
- Preferences are restored and correctly isolated by server context.
- Regression tests validate variant/no-variant behaviors.

## Implementation Status

Status: Completed (2026-02-09)

Implemented artifacts:

- Added typed variant support in provider/domain models and `variant` propagation in chat input serialization.
- Added server-scoped preference storage for selected variant map, recent model keys, and model usage counts.
- Expanded `ChatProvider` with provider/model setters, variant cycling, model-usage tracking, and restoration logic.
- Added composer-level model controls in `ChatPage` (provider picker, model picker, reasoning cycle chip).
- Added/updated tests covering variant parsing, request serialization, selection/cycle behavior, and integration payload checks.

Validation executed:

- `flutter test` (all tests passing)
- `flutter analyze --no-fatal-infos --no-fatal-warnings` (infos only)

## Source Links

- https://github.com/anomalyco/opencode
- https://opencode.ai/docs/models/
- https://opencode.ai/docs/server/
