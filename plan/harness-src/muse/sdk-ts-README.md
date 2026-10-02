# `@muse-code/sdk`

The TypeScript SDK for Muse Code: a typed Node client for driving a Muse Code
agent over the Muse Session Protocol (MSP).

- Spawn a `muse serve` host, open and resume sessions, and send turns.
- Stream a turn's items and text deltas as async iterators; await the turn's
  server-authored outcome.
- Answer tool-approval requests with a handler you register — or register
  none and run under the server's own default-deny.
- A client-side fold keeps a live, typed view of the session — items, session
  state, pending commands — with gap recovery after dropped deliveries and
  safe same-command retry that can never double-submit.

**Zero runtime dependencies**: pure TypeScript over the Node standard
library. The MSP wire declarations are bundled into the package, so nothing
else is needed to typecheck against it.

## Install

```sh
npm install @muse-code/sdk
npm install -D @types/node   # required for TypeScript consumers
```

Node 20 or newer. `@types/node` is declared as an **optional peer
dependency**: a JavaScript consumer needs nothing, while a TypeScript
consumer installs it explicitly — without it the declarations that name
`ChildProcess`, `Readable` and friends do not resolve.

You also need the Muse Code CLI: a `muse` binary on `PATH`, or an explicit
path passed at spawn time.

**This package versions in lockstep with Muse Code**: the SDK version is the
Muse Code release it ships with — `@muse-code/sdk X.Y.Z` pairs with Muse Code
`X.Y.Z`. The stable MSP surface follows the product's compatibility posture:
evolution is additive, and a breaking change follows a documented deprecation
and changelog path. Surfaces marked experimental (`x-msp-openness`)
may change or be removed with a changelog entry and no deprecation window. Pin an
exact version, and read the changelog before moving off it.

## Use

```ts
import { MuseClient } from "@muse-code/sdk";

const client = await MuseClient.spawn({
  museBin: "muse",
  args: ["serve"],
  clientInfo: { name: "my-app", version: "1.0.0" },
});

const session = await client.startSession({ workspaceRoot: process.cwd() });

const turn = await session.sendUserTurn({
  input: [{ type: "text", text: "Summarize this repository." }],
});
for await (const item of turn.items()) console.log(item);
await turn.completed;

await client.close();
```

`turn.items()` replays what the session already holds before its live tail;
`turn.deltas()` is live-only. `turn.completed` settles on every exit, so an
awaited turn can never hang on a session that ended without an answer.

To approve tool use programmatically, register a handler on the session;
approval choices are server-minted, and a decision the request never offered
is refused and reported rather than sent:

```ts
session.onApproval(async (request) => ({
  choiceId: request.availableChoices[0].choiceId,
}));
```

Status: developer preview. The facade — spawn, session open/resume, turns,
approvals, and recovery after dropped deliveries — is complete and covered by
the conformance suites in the source repository.

## Documentation

- Guides, cookbook recipes, and the protocol reference:
  <https://meta-models.github.io/muse-code-sdk/>
- TypeScript API reference:
  <https://meta-models.github.io/muse-code-sdk/next/generated/sdk/>
- Source and issues: <https://github.com/meta-models/muse-code-sdk>
