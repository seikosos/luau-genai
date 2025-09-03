local genai = require("genai")

local client = genai.new("<YOUR_API_KEY>", "https://generativelanguage.googleapis.com/v1beta/openai/")
-- ngl gemini better
local chat = client:chat("gemini-1.5-flash", { system_prompt = "" })
print(chat:say("Hello, world!"))

-- example for onemodule.lua

local genai = loadstring(game:HttpGet("https://raw.githubusercontent.com/seikosos/luau-genai/refs/heads/main/onemodule.lua"))()

local client = genai.new("<YOUR_API_KEY>", "https://generativelanguage.googleapis.com/v1beta/openai/")
-- ngl gemini better
local chat = client:chat("gemini-1.5-flash", { system_prompt = "" })
print(chat:say("Hello, world!"))
