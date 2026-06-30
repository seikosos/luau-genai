---@module "genai.providers"
local providers = {}

providers.openai = require("./openai")
providers.anthropic = require("./anthropic")

return providers
