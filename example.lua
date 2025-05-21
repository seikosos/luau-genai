local genai = require("genai")

local client = genai.new("<YOUR_API_KEY>", "https://api.deepinfra.com/v1/openai/chat/completions")
-- deep infra cuz openai completions support
local chat = client:chat("meta-llama/Meta-Llama-3-8B-Instruct", { system_prompt = "" })
print(chat:say("Hello, world!"))