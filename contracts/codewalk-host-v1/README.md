# CodeWalk Host Protocol v1 — provisional contract

This directory defines an app-facing JSON projection of the accepted canonical
domain and separate CodeWalk Host Protocol (CHP) envelopes. It contains a Draft 7
schema, named definitions, hand-authored examples and offline Dart validation.
It implements no Host, adapter, server, authorization boundary or production
connection.

`revision.json` pins canonical model commit
`df3ed903c6c6ed6700ebb1b2fcbb2329db6c2e5e` and the provisional app-facing revision
`cw-canonical-1-provisional.1`. **Final G5 remains pending:** real Codex/Claude
recordings, their G2 mappings and reducer assertions must validate against the
same final revision, and the artifacts must meet the merge criterion. Synthetic
examples and review-branch publication do not establish those gates.

## Canonical payloads and transport envelopes

`schema.json` is self-contained. Every `$ref` points to `#/definitions/...`;
`$schema` and the documentary `$id` do not cause remote schema retrieval. Tests
use synchronous `JsonSchema.create` and `validate(...).isValid` from
`json_schema` 5.2.2. No reference provider or asynchronous network constructor
is used.

`definition-map.json` lists every definition and its actual domain type or
explicit edge-only composition. `examples/manifest.json` identifies every
example's exact definition, family, revision and `hand-authored` origin. A
canonical expectation validates its named `Canonical*` definition separately
from a CHP example validating a `Chp*` envelope and the `ChpFrame` union.

| Definition family | Canonical model |
|---|---|
| `CanonicalHarnessRef`, `CanonicalSessionRef`, `CanonicalProjectRef`, lineage and ownership | Existing identity/ownership codecs; full composite session identity, independent parent/fork lineage and explicit proof |
| `CanonicalDomainOwner`, source, event/item metadata and `CanonicalStreamPosition` | Explicit session/project/host/global/unknown ownership; source provenance and separate client stream ordering |
| `CanonicalTimelineItem`, `CanonicalSessionEvent` and named variants | Stable item/generation and typed events; explicit unknown item/event wrappers retaining canonical JSON data |
| State, interaction, approval, form, work and plan definitions | Independent lifecycles, native choice/scope and actual owner, typed form structures, independent child outcomes |
| Usage, quota, capability, error and operation definitions | Nullable source observations and restrictions; unknown values preserve data while domain policy denies unsupported operations |
| Command receipt, create result, session/page and snapshot definitions | Admission knowledge and independently bounded hydration collections, with opaque native references/cursors |
| Intent, file and terminal request definitions | Explicit edge compositions of existing port inputs; these shapes do not implement workspace/terminal capability or confinement |

Existing identity, ownership, stream, open-enum and canonical-value codecs define
their JSON representation. Other domain classes have no general production wire
codec: this contract defines the projection at the edge, and its parity helper
is restricted to synthetic tests. Later `harness_host` owns production DTO
mapping; core remains independent of transport.

CHP frames use `type`, `schemaVersion: 1` and `canonicalRevision`. Named frames
are `hello`, `event`, `subscribe`, `resync`, `ping`, `pong`, `command`, `receipt`,
`snapshot`, `capabilities`, `sessionPage` and `createResult`. Event envelopes
reference a complete canonical event; an optional routing `session` must agree
with its actual owner. Command envelopes carry the canonical original intent;
known operations constrain their intent to the corresponding typed port input.
Unknown operations can be retained as observations and must be denied before
mutation. JSON validity never grants execution authority.

## Preserved invariants

- IDs are exact nonempty opaque strings. URLs, native IDs alone and upstream
  project annotations do not establish identity. Project/host observations may
  omit their harness and then cannot establish known authority.
- Timestamps retain ISO time-zone information, including signed expanded years
  supported by the canonical Dart codec. Calendar semantics for expanded years
  are checked by that codec; schema shape alone does not establish them.
- Canonical stream and native aggregate sequences are nonnegative **BigInt
  decimal strings**, including values beyond uint64. Numeric values, signs,
  fractions, leading zeros and trailing whitespace/newlines are rejected.
  Native cursors remain opaque; aggregate skips and durable watermarks do not
  imply replay or missing public history.
- Open enum strings retain future values. Unknown support with `verified: true`
  remains a valid observation whose domain `isAvailable` is false. No wire
  `isAvailable` flag is accepted. Unknown item/event data remains explicitly
  unknown and cannot silently become assistant text or a supported mutation.
- Admission/delivery and execution completion remain separate. Duplicate
  receipts preserve the original admission knowledge; duplicate of uncertain
  admission stays uncertain. Uncertain create results carry no admitted handle.
- Offered approval IDs, order, note support and resolution scope are preserved.
  An `autoApprovable` observation does not itself authorize a reply. Actual
  canonical policy excludes forms, persistent/unknown choices and unverified
  ownership. Unknown values never invent a permissive choice.
- Missing usage stays absent/null; cumulative/partial observations retain source
  and merge identity. Quota percentages above 100 are valid. Child work retains
  its independent outcome even when a parent receives a completion notice.
- Reconnect subscriptions concern observation only. They carry no command
  replay. Verified replay still needs the exact operation/version/phase,
  original scope/payload, unresolved admission, reconciliation and no
  cancellation fence; a schema-valid command ID or error cannot establish it.

## Snapshots and semantic validation

Each `SnapshotValue<T>` contains `value` and its `boundary`; each
`SnapshotCollection<T>` contains `values`, `complete` and its own `boundary`.
A `CanonicalSessionSnapshot` preserves separate boundaries for info, execution,
timeline, pending input, interactions, work, plan, usage, selection and revert.
`readStart` is client causal bookkeeping captured **before that individual
read**, not a native watermark or an atomic response guarantee.

Draft 7 validates structure. It cannot compare arbitrary fields for equality
or prove freshness, authority, permission eligibility, native replay guarantees,
filesystem containment or reducer convergence. The Dart tests therefore label
separate semantic checks for matching owner/source/routing, snapshot
session/generation/info identities, read-time order, uncertain handles and
permission/capability policy. Actual core constructors supply those domain
checks. Production consumers must apply equivalent domain/port checks after
decoding; accepting JSON shape alone is insufficient.

## Revision and compatibility rules

1. `schemaVersion` selects the CHP envelope version. This directory currently
   accepts only version 1; unsupported versions must fail compatibility checks.
2. `canonicalRevision` identifies the exact app-facing canonical projection.
   Every frame and example-manifest entry must use the pinned revision. A
   different/missing revision is incompatible, never silently reinterpreted.
3. While provisional, a model/schema change increments the provisional revision
   and refreshes model provenance, definitions, examples and digest metadata.
   Revalidate all affected semantic and shape results. G2/G5 evidence cannot be
   carried across a changed revision without revalidation.
4. Final freeze requires matching real G2 and G5 evidence at one revision. Later
   incompatible changes need a new negotiated revision/version; preserve the
   published definition and its examples. Optional extensions are accepted only
   through defined extension/unknown containers, not arbitrary control fields.
5. Host implementation/distribution, retention, Origin/TLS/tickets, pairing and
   workspace security remain their v2.1/v2.2 producers. This schema does not
   validate native services, provider credentials or packaging.

From the repository root, after dependencies are resolved and the supported
Flutter/Dart toolchain is active:

In this prepared cloud workspace, first source
`/workspace/.cloud-tools/codewalk-env.sh`. Other environments use their usual
toolchain activation.

```sh
flutter analyze --no-pub test/contract/chp
flutter test --no-pub test/contract/chp --reporter expanded
```

Tests run on the VM, load only local artifacts, validate every manifest example,
reject meaningful malformed variants and compare projections with actual
canonical codecs/constructors. No native/provider model is called. Root gates
also cover this dev dependency and the retained legacy regression suite.
