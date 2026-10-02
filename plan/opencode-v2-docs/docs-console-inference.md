# Inference API

- Source URL: https://opencode.ai/v2/docs/console/inference/
- Source file: https://github.com/anomalyco/opencode/blob/bb381e8bdd1ff22c7329e07c068ec0099031f382/services/www/src/docs/content/console/inference.mdx
- Fetched: 2026-10-02 (OpenCode V2 docs; branch `v2` @ `bb381e8bdd`; latest release at fetch time: 2.0.21)
- Note: content is the verbatim MDX source rendered at the URL above; MDX components (CodeTabs, Callout, Card, PlanTabs, table wrappers) were flattened to Markdown and docs-relative links made absolute. No text was summarized or omitted.

_Call OpenAI, Anthropic, and Gemini-compatible models through Console inference with one authentication header._

---
Console inference serves OpenAI, Anthropic, and Gemini-compatible APIs from `https://opencode.ai/inference`. Send a
JSON `POST` request to the endpoint that matches the model's API family.

```bash
curl -X POST "https://opencode.ai/inference/openai/v1/chat/completions" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "kimi-k2.6",
    "messages": [{ "role": "user", "content": "Say hi" }]
  }'
```

## Authentication

Replace `<token>` with a service account key created in the [Console](https://opencode.ai/console). Paid models
require the header; free chat models can be called without it.

```text
Authorization: Bearer <token>
```

## Endpoints

| API                     | Path                                                      |
| ----------------------- | --------------------------------------------------------- |
| OpenAI Chat Completions | `/inference/openai/v1/chat/completions`                   |
| OpenAI Responses        | `/inference/openai/v1/responses`                          |
| Anthropic Messages      | `/inference/anthropic/v1/messages`                        |
| Gemini                  | `/inference/google/v1beta/models/<model>:generateContent` |

Each model is served by one API family. See the [model endpoints](https://opencode.ai/v2/docs/console/models#endpoints) table, or fetch the live
list:

```bash
curl https://opencode.ai/inference/v1/models
```

### OpenAI Chat Completions

Open models such as `kimi-k2.6`, `glm-5.1`, `minimax-m2.7`, and the free models use the Chat Completions API.

```bash
curl -X POST "https://opencode.ai/inference/openai/v1/chat/completions" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "glm-5.1",
    "messages": [{ "role": "user", "content": "Say hi" }]
  }'
```

### OpenAI Responses

GPT models use the Responses API.

```bash
curl -X POST "https://opencode.ai/inference/openai/v1/responses" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-5.5",
    "input": "Say hi"
  }'
```

### Anthropic Messages

Claude and Qwen models use the Messages API. `max_tokens` is required.

```bash
curl -X POST "https://opencode.ai/inference/anthropic/v1/messages" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-6",
    "max_tokens": 1024,
    "messages": [{ "role": "user", "content": "Say hi" }]
  }'
```

### Gemini

Gemini models take the model and method in the path. Replace `:generateContent` with `:streamGenerateContent` to
stream the response.

```bash
curl -X POST "https://opencode.ai/inference/google/v1beta/models/gemini-3.1-pro:generateContent" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{ "parts": [{ "text": "Say hi" }] }]
  }'
```
