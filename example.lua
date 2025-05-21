local genai = require("genai")

local client = genai.new("<YOUR_API_KEY>", "https://generativelanguage.googleapis.com/v1beta/openai/")
-- ngl gemini better
local chat = client:chat("meta-llama/Meta-Llama-3.1-8B-Instruct", { system_prompt = "" })
print(chat:say("Hello, world!"))