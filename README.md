# ❗❗❗❗❗❗
# THIS IS NOT THE ORIGINAL REPO
# VISIT THIS FOR THE ORIGINAL
# https://github.com/emilrueh/lua-genai

# this is just recoded to work on basicly all exploits






# Generative AI SDK for Lua

A developer-friendly Lua interface for working with various generative AI providers, abstracting away provider-specific payload structures and response parsing so that using multiple models is easy.

> ❤️ This is a work in progress so any help is highly appreciated!

## Features

- Structured JSON response abstraction layer
- Token usage tracking with cost calculation
- Open-source models via OpenAI compatibility

### Providers

- OpenAI: https://platform.openai.com/docs/overview

- Anthropic: https://docs.anthropic.com/en/home

- Anything OpenAI compatible e.g. **Perplexity, Together AI, etc.** by prefixing endpoint with openai and double colon e.g. `"openai::https://api.perplexity.ai/chat/completions"`

### Roadmap

- [ ] Audio models

- [ ] Image models

- [ ] Video models

## Installation

`luarocks install lua-genai`

### Dependencies

- [lua-cjson](https://github.com/openresty/lua-cjson)
- [luasec](https://github.com/brunoos/luasec)
- [copas](https://github.com/lunarmodules/copas)

## Usage

```lua
local genai = require("genai")

local client = genai.new("<YOUR_API_KEY>", "https://api.openai.com/v1/chat/completions")

local chat = client:chat("gpt-4o-mini")
print(chat:say("Hello, world!"))
```

> For deeper control you could use the `genai` client directly if needed

### System Prompt

```lua
local chat = client:chat("gpt-4o-mini", { system_prompt = "You are a fish." })
print(chat:say("What are you?"))
```

### JSON Response

```lua
local npc_schema = {
	name = { type = "string" },
	class = { type = "string" },
	level = { type = "integer" },
}

local json_object = {
	title = "NPC",
	description = "A non-player character's attributes.",
	schema = npc_schema,
}

local chat = client:chat("gpt-4o-mini", { settings = { json = json_object } })
print(chat:say("Create a powerful wizard called Torben."))
```

See `example.lua` for a small example
See `onemodule.lua` for this as one big module
