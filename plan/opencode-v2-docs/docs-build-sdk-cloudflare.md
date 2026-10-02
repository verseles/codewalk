# Cloudflare

- Source URL: https://opencode.ai/v2/docs/build/sdk/cloudflare/
- Source file: https://github.com/anomalyco/opencode/blob/bb381e8bdd1ff22c7329e07c068ec0099031f382/services/www/src/docs/content/build/sdk/cloudflare.mdx
- Fetched: 2026-10-02 (OpenCode V2 docs; branch `v2` @ `bb381e8bdd`; latest release at fetch time: 2.0.21)
- Note: content is the verbatim MDX source rendered at the URL above; MDX components (CodeTabs, Callout, Card, PlanTabs, table wrappers) were flattened to Markdown and docs-relative links made absolute. No text was summarized or omitted.

---
Use `@opencode/sdk/workerd` inside a Cloudflare Durable Object. This profile uses the object's SQLite storage,
persists durable events for eviction recovery, and replaces unavailable local filesystem and process services.

```sh
bun add @opencode/sdk
```

Hold one host for the lifetime of the Durable Object instance instead of creating one for every request.

```ts
import { OpenCodeWorkerd } from "@opencode/sdk/workerd"
import myPlugin from "./my-plugin"

export class OpenCodeDO {
  private readonly opencode: Promise<OpenCodeWorkerd.Interface>

  constructor(state: DurableObjectState) {
    this.opencode = state.blockConcurrencyWhile(() =>
      OpenCodeWorkerd.create({
        storage: state.storage,
        config: { default_agent: "build" },
        plugins: [myPlugin],
      }),
    )
  }

  async fetch() {
    const opencode = await this.opencode
    return Response.json(await opencode.server.info())
  }
}
```

`blockConcurrencyWhile` keeps every Durable Object event out until the host is ready and resets the object if
initialization fails. The retained Promise gives request handlers direct access to the same host after startup.

```ts
constructor(state: DurableObjectState) {
  this.opencode = state.blockConcurrencyWhile(() =>
    OpenCodeWorkerd.create({ storage: state.storage }),
  )
}
```

Wrangler selects OpenCode's Workerd-safe implementations through the `workerd` package condition. Cloudflare may evict
a Durable Object without running cleanup, so correctness does not depend on `close()` being called.

```jsonc title="wrangler.jsonc"
{
  "compatibility_flags": ["nodejs_compat"]
}
```

## Customize

Customize your OpenCode instance by registering plugins bundled with your
Worker. Pass plugins to `OpenCodeWorkerd.create()` to customize agents, models,
tools, and other behavior:

```ts
import { Plugin } from "@opencode/plugin"
import { OpenCodeWorkerd } from "@opencode/sdk/workerd"

const plugin = Plugin.define({
  id: "customize-agent",
  async setup(ctx) {
    await ctx.agent.transform((agents) => {
      agents.update("build", (agent) => {
        agent.description = "Builds features and fixes bugs for our team"
      })
    })
  },
})

await OpenCodeWorkerd.create({
  storage: state.storage,
  config: { default_agent: "build" },
  plugins: [plugin],
})
```

See the [full plugins documentation](https://opencode.ai/v2/docs/build/plugins) for plugin hooks,
transforms, tools, and the complete plugin context.
