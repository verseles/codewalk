Title: Models

URL Source: https://opencode.ai/docs/models/

Markdown Content:
Configuring an LLM provider and model.

OpenCode uses the [AI SDK](https://ai-sdk.dev/) and [Models.dev](https://models.dev/) to support **75+ LLM providers** and it supports running local models.

* * *

## [Providers](https://opencode.ai/docs/models/#providers)

Most popular providers are preloaded by default. If you’ve added the credentials for a provider through the `/connect` command, they’ll be available when you start OpenCode.

Learn more about [providers](https://opencode.ai/docs/providers).

* * *

## [Select a model](https://opencode.ai/docs/models/#select-a-model)

Once you’ve configured your provider you can select the model you want by typing in:

`/models`

* * *

## [Recommended models](https://opencode.ai/docs/models/#recommended-models)

There are a lot of models out there, with new models coming out every week.

However, there are only a few of them that are good at both generating code and tool calling.

Here are several models that work well with OpenCode, in no particular order. (This is not an exhaustive list nor is it necessarily up to date):

*   GPT 5.2
*   GPT 5.1 Codex
*   Claude Opus 4.5
*   Claude Sonnet 4.5
*   Minimax M2.1
*   Gemini 3 Pro

* * *

## [Set a default](https://opencode.ai/docs/models/#set-a-default)

To set one of these as the default model, you can set the `model` key in your OpenCode config.

`{  "$schema": "https://opencode.ai/config.json",  "model": "lmstudio/google/gemma-3n-e4b"}`

Here the full ID is `provider_id/model_id`. For example, if you’re using [OpenCode Zen](https://opencode.ai/docs/zen), you would use `opencode/gpt-5.1-codex` for GPT 5.1 Codex.

If you’ve configured a [custom provider](https://opencode.ai/docs/providers#custom), the `provider_id` is key from the `provider` part of your config, and the `model_id` is the key from `provider.models`.

* * *

## [Configure models](https://opencode.ai/docs/models/#configure-models)

You can globally configure a model’s options through the config.

`{  "$schema": "https://opencode.ai/config.json",  "provider": {    "openai": {      "models": {        "gpt-5": {          "options": {            "reasoningEffort": "high",            "textVerbosity": "low",            "reasoningSummary": "auto",            "include": ["reasoning.encrypted_content"],          },        },      },    },    "anthropic": {      "models": {        "claude-sonnet-4-5-20250929": {          "options": {            "thinking": {              "type": "enabled",              "budgetTokens": 16000,            },          },        },      },    },  },}`

Here we’re configuring global settings for two built-in models: `gpt-5` when accessed via the `openai` provider, and `claude-sonnet-4-20250514` when accessed via the `anthropic` provider. The built-in provider and model names can be found on [Models.dev](https://models.dev/).

You can also configure these options for any agents that you are using. The agent config overrides any global options here. [Learn more](https://opencode.ai/docs/agents/#additional).

You can also define custom variants that extend built-in ones. Variants let you configure different settings for the same model without creating duplicate entries:

`{  "$schema": "https://opencode.ai/config.json",  "provider": {    "opencode": {      "models": {        "gpt-5": {          "variants": {            "high": {              "reasoningEffort": "high",              "textVerbosity": "low",              "reasoningSummary": "auto",            },            "low": {              "reasoningEffort": "low",              "textVerbosity": "low",              "reasoningSummary": "auto",            },          },        },      },    },  },}`

* * *

## [Variants](https://opencode.ai/docs/models/#variants)

Many models support multiple variants with different configurations. OpenCode ships with built-in default variants for popular providers.

### [Built-in variants](https://opencode.ai/docs/models/#built-in-variants)

OpenCode ships with default variants for many providers:

**Anthropic**:

*   `high` - High thinking budget (default)
*   `max` - Maximum thinking budget

**OpenAI**:

Varies by model but roughly:

*   `none` - No reasoning
*   `minimal` - Minimal reasoning effort
*   `low` - Low reasoning effort
*   `medium` - Medium reasoning effort
*   `high` - High reasoning effort
*   `xhigh` - Extra high reasoning effort

**Google**:

*   `low` - Lower effort/token budget
*   `high` - Higher effort/token budget

### [Custom variants](https://opencode.ai/docs/models/#custom-variants)

You can override existing variants or add your own:

`{  "$schema": "https://opencode.ai/config.json",  "provider": {    "openai": {      "models": {        "gpt-5": {          "variants": {            "thinking": {              "reasoningEffort": "high",              "textVerbosity": "low",            },            "fast": {              "disabled": true,            },          },        },      },    },  },}`

### [Cycle variants](https://opencode.ai/docs/models/#cycle-variants)

Use the keybind `variant_cycle` to quickly switch between variants. [Learn more](https://opencode.ai/docs/keybinds).

* * *

## [Loading models](https://opencode.ai/docs/models/#loading-models)

When OpenCode starts up, it checks for models in the following priority order:

1.   The `--model` or `-m` command line flag. The format is the same as in the config file: `provider_id/model_id`.

2.   The model list in the OpenCode config.

`{  "$schema": "https://opencode.ai/config.json",  "model": "anthropic/claude-sonnet-4-20250514"}` 
The format here is `provider/model`.

3.   The last used model.

4.   The first model using an internal priority.
