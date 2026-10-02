# Effect

- Source URL: https://opencode.ai/v2/docs/build/sdk/effect/
- Source file: https://github.com/anomalyco/opencode/blob/bb381e8bdd1ff22c7329e07c068ec0099031f382/services/www/src/docs/content/build/sdk/effect.mdx
- Fetched: 2026-10-02 (OpenCode V2 docs; branch `v2` @ `bb381e8bdd`; latest release at fetch time: 2.0.21)
- Note: content is the verbatim MDX source rendered at the URL above; MDX components (CodeTabs, Callout, Card, PlanTabs, table wrappers) were flattened to Markdown and docs-relative links made absolute. No text was summarized or omitted.

---
`@opencode/sdk/effect` is the Effect-native embedded SDK. Operations return typed Effects and Streams, and closing
the owning Scope releases the router, Location services, fibers, and plugin registrations.

```sh
bun add @opencode/sdk effect
```

## Create a host

Create the host inside `Effect.scoped`, then use its generated API groups or the `sessions` alias.

```ts
import { AbsolutePath, Location, OpenCode } from "@opencode/sdk/effect"
import { Effect } from "effect"

const program = Effect.scoped(
  Effect.gen(function* () {
    const opencode = yield* OpenCode.create()
    const session = yield* opencode.sessions.create({
      location: Location.Ref.make({ directory: AbsolutePath.make("/workspace") }),
    })
    yield* opencode.sessions.prompt({
      sessionID: session.id,
      text: "Review the current changes",
    })
    return session
  }),
)

const session = await Effect.runPromise(program)
```

The embedded host uses the same schema values, declared errors, request options, and Streams as
`@opencode/client/effect`.

```ts
const info = yield* opencode.server.info()
const sessions = yield* opencode.sessions.list()
```

## Stream events

Streaming endpoints return Effect `Stream` values. Fork consumers in the host Scope when they should run in the
background.

```ts
import { Effect, Stream } from "effect"

yield* opencode.events.subscribe().pipe(
  Stream.runForEach((event) => Effect.logInfo("OpenCode event", { type: event.type })),
  Effect.forkScoped,
)
```

## Customize

Customize your OpenCode instance by registering Effect plugins. Use the embedded
host to customize agents, models, tools, and other behavior:

```ts
import { Plugin } from "@opencode/plugin/effect"
import { Effect } from "effect"

const plugin = Plugin.define({
  id: "customize-agent",
  effect: (ctx) =>
    Effect.gen(function* () {
      const agent = ctx.agent
      yield* agent.transform((agents) => {
        agents.update("build", (agent) => {
          agent.description = "Builds features and fixes bugs for our team"
        })
      })
    }),
})

yield* opencode.plugin(plugin)
```

See the [full Effect plugins documentation](https://opencode.ai/v2/docs/build/plugins/effect) for plugin
hooks, transforms, tools, and the complete plugin context.

## Layer

Use `OpenCode.layer()` when the embedded host should be an application service.

```ts
import { OpenCode } from "@opencode/sdk/effect"
import { Effect } from "effect"

const program = Effect.gen(function* () {
  const opencode = yield* OpenCode.Service
  return yield* opencode.server.info()
})

const health = await Effect.runPromise(program.pipe(Effect.provide(OpenCode.layer())))
```
