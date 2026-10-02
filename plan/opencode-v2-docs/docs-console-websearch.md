# Websearch

- Source URL: https://opencode.ai/v2/docs/console/websearch/
- Source file: https://github.com/anomalyco/opencode/blob/bb381e8bdd1ff22c7329e07c068ec0099031f382/services/www/src/docs/content/console/websearch.mdx
- Fetched: 2026-10-02 (OpenCode V2 docs; branch `v2` @ `bb381e8bdd`; latest release at fetch time: 2.0.21)
- Note: content is the verbatim MDX source rendered at the URL above; MDX components (CodeTabs, Callout, Card, PlanTabs, table wrappers) were flattened to Markdown and docs-relative links made absolute. No text was summarized or omitted.

_Hosted websearch for OpenCode through Console._

---
Console provides hosted Websearch to connected OpenCode v2 users. A workspace owner or admin enables it once for the workspace, without giving members a separate search provider key.

Each successful search costs **$0.01** and counts toward the workspace balance and member spending limits.

## Enable

1. Sign in to the [Console](https://opencode.ai/console) as a workspace owner or admin.
2. Open **Settings** > **General**.
3. Turn on **Hosted web search**.

Each member then connects OpenCode to the workspace with `/connect`.

```text
/connect
```

OpenCode loads **OpenCode Web Search** from the workspace's managed configuration. Members do not need to set `websearch.provider` or add a provider API key.

## Search

Ask OpenCode for current information in a prompt. Searches run from OpenCode rather than from an interactive page in Console.

```text
Find the latest Bun release and summarize the changes with source links.
```

The hosted provider searches the public web and returns up to eight results. OpenCode uses the results to answer the prompt and cite sources.

See the [Websearch guide](https://opencode.ai/v2/docs/websearch) to configure permissions or disable the tool.

## Billing

Console charges **$0.01** after a search returns a valid result set. Failed and rate-limited searches are not charged.

Websearch appears separately from model usage in **Usage**, **My Activity**, member activity, invoices, and CSV exports. Workspace and member monthly spending limits include Websearch charges.

## Privacy

Hosted Websearch has zero data retention. Console and its hosted search provider process each query and its results without storing their contents.
