local genai = loadstring(game:HttpGet("https://raw.githubusercontent.com/seikosos/luau-genai/refs/heads/main/onemodule.lua"))()

local client = genai.new("<YOUR_API_KEY>", "openai::https://openrouter.ai/api/v1/chat/completions")

local chat = client:chat("cohere/north-mini-code:free", {system_prompt = ""})
print(chat:say("Hello, world!"))
