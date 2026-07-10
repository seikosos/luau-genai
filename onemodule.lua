-- ++++++++ WAX BUNDLED DATA BELOW ++++++++ --

-- Will be used later for getting flattened globals
local ImportGlobals

-- Holds direct closure data (defining this before the DOM tree for line debugging etc)
local ClosureBindings = {
    function()local wax,script,require=ImportGlobals(1)local ImportGlobals return (function(...)if not table.unpack then table.unpack = unpack end

return require("./genai")

end)() end,
    function()local wax,script,require=ImportGlobals(2)local ImportGlobals return (function(...)---@module "genai.features"
local features = {}

features.Chat = require("./chat")

return features

end)() end,
    function()local wax,script,require=ImportGlobals(3)local ImportGlobals return (function(...)local utils = require(script.Parent.Parent.utils)

---@class Chat Accumulating chat history and usage
---@field client table
---@field model string
---@field settings table?
---@field usage table
---@field history table
---@field system_prompt string?
local Chat = {}
Chat.__index = Chat

---@param client table
---@param model string
---@param opts table? Containing **settings** and or **system_prompt**
function Chat.new(client, model, opts)
	local self = setmetatable({}, Chat)

	self.client = client
	self.model = model
	self.settings = opts and opts.settings or {}
	self.usage = { input = 0, output = 0 }
	self.history = {}
	self.system_prompt = opts and opts.system_prompt

	-- insert system prompt into chat history at the start if provided
	local system_message = self.client.provider.construct_system_message(self.system_prompt)
	if system_message then -- some providers use system message as top-level arg
		table.insert(self.history, system_message)
	end

	return self
end

---Wrap message construction
---@param user_prompt string
---@return string reply Full response text whether streamed or not
function Chat:say(user_prompt)
	table.insert(self.history, self.client.provider.construct_user_message(user_prompt))
	local reply, input_tokens, output_tokens = self.client:call(self)
	table.insert(self.history, self.client.provider.construct_assistant_message(reply))
	self.usage.input = self.usage.input + (input_tokens or 0)
	self.usage.output = self.usage.output + (input_tokens or 0)
	return reply
end

---Caculate model pricing from input and output tokens in USD
---@return number
function Chat:get_cost()
	return utils.calc_token_cost(self.model, self.usage, self.client.provider.pricing)
end

return Chat

end)() end,
    function()local wax,script,require=ImportGlobals(4)local ImportGlobals return (function(...)local cjson = game:GetService("HttpService")
local utils = require("./utils")
local providers = require("./providers")
local features = require("./features")

---Client for interacting with specified API endpoint
---@class GenAI
---@field _api_key string?
---@field _endpoint string
---@field provider table|nil
---@field _determine_provider function
local GenAI = {}
GenAI.__index = GenAI

---@param api_key? string
---@param endpoint string
function GenAI.new(api_key, endpoint)
	local self = setmetatable({}, GenAI)
	self._api_key = api_key
	self._endpoint = endpoint
	self.provider = self:_determine_provider(providers)
	return self
end

---Check endpoint for occurance of ai provider name
---@param providers table Collection of GenAI provider modules
---@return table? provider_module Collection of functions determining input and output structure
function GenAI:_determine_provider(providers)
	local provider = nil
	local endpoint = self._endpoint
	for provider_name, provider_module in pairs(providers) do
		if endpoint:find(provider_name) then provider = provider_module end
	end
	assert(provider, "GenAI provider could not be determined from provided endpoint")
	self._endpoint = self:check_if_openai_compatible(endpoint)
	return provider
end

---Check if the endpoint starts with 'openai::' for API compatibility
---@param endpoint string
---@return string endpoint
function GenAI:check_if_openai_compatible(endpoint)
	local prefix, url = endpoint:match("^(.-)::(.+)$")
	return (prefix == "openai") and url or endpoint
end

---Prepare streaming requirements if set to stream
---@param processor function? Display of streamed text chunks
---@return table? accumulator Schema storing full streamed response
---@return function? callback Streaming handler
function GenAI:_setup_stream(processor)
	local accumulator = nil
	local callback = nil

	if processor then
		accumulator = utils.Accumulator.new(cjson:JSONDecode(self.provider.response_schema))
		local handler = self.provider.create_stream_handler(accumulator, processor)
		callback = utils.create_sse_callback({ self.provider.stream_pattern, handler })
	end

	return accumulator, callback
end

---Prepare API call payload and streaming options
---@param opts table Payload including model settings and chat history
---@return table headers
---@return table payload
---@return function? callback Streaming handler
---@return table? accumulator Schema storing full streamed response
---@return boolean async Whether to use non-blocking https via copas
function GenAI:_prepare_response_requirements(opts)
	local headers = self.provider.construct_headers(self._api_key)
	local payload = self.provider.construct_payload(opts)
	local accumulator, callback = self:_setup_stream(opts.settings.stream)
	local async = opts.settings and opts.settings.async or false
	return headers, payload, callback, accumulator, async
end

---Execute API call to specified GenAI model with all payload and settings
---@param opts table Payload including model settings and chat history
---@return string reply
---@return number input_tokens
---@return number output_tokens
function GenAI:call(opts)
	local headers, payload, callback, accumulator, async = self:_prepare_response_requirements(opts)

	local response = utils.send_request(
		self._endpoint,
		cjson:JSONEncode(payload),
		"POST",
		headers,
		callback,
		self.provider.handle_exceptions
	)

	local reply, input_tokens, output_tokens = self.provider.extract_response_data(response)
	reply = type(reply) == "table" and cjson:JSONEncode(reply) or reply -- ensure json output is string

	return reply, input_tokens, output_tokens
end

-- features:

---Create chat instance with automatic tracking of messages and tokens
---@param model string
---@param opts table? Containing **settings** and or **system_prompt**
---@return Chat
function GenAI:chat(model, opts)
	return features.Chat.new(self, model, opts)
end

return GenAI

end)() end,
    function()local wax,script,require=ImportGlobals(5)local ImportGlobals return (function(...)---@module "genai.providers"
local providers = {}

providers.openai = require("./openai")
providers.anthropic = require("./anthropic")

return providers

end)() end,
    function()local wax,script,require=ImportGlobals(6)local ImportGlobals return (function(...)-- "https://api.anthropic.com/v1/messages"

---@module "genai.providers.anthropic"
local anthropic = {}

---Return nil as system prompt is provided in top-level payload
---@param system_prompt string
---@return nil
function anthropic.construct_system_message(system_prompt)
	return nil
end

---Package user prompt
---@param user_prompt string
---@return table
function anthropic.construct_user_message(user_prompt)
	local user_message = { role = "user", content = user_prompt }
	return user_message
end

---Package AI reply
---@param reply string
---@return table
function anthropic.construct_assistant_message(reply)
	local assistant_message = { role = "assistant", content = reply }
	return assistant_message
end

---Construct the request headers
---@param api_key string?
---@return table headers
function anthropic.construct_headers(api_key)
	local headers = {
		["x-api-key"] = tostring(api_key),
		["anthropic-version"] = "2023-06-01", -- https://docs.anthropic.com/en/api/versioning
		["content-type"] = "application/json",
	}

	return headers
end

---Abstract structuring json responses
---@param opts table {title: string, description: string, schema: table}
---@return table? response_format
local function construct_json_schema(opts)
	if opts then
		return {
			{
				name = opts.title,
				description = opts.description,
				input_schema = {
					type = "object",
					properties = opts.schema,
				},
			},
		}
	end
end

---Packaging AI settings
---@param opts table
---@return table
function anthropic.construct_payload(opts)
	local payload = {
		model = opts.model,
		messages = opts.history,
		system = opts.system_prompt,
		-- basic settings:
		max_tokens = opts.settings.max_tokens or 1024, -- required
		temperature = opts.settings.temperature,
		stream = opts.settings.stream and true or nil,
		-- advanced settings:
		top_k = opts.settings.top_k,
		top_p = opts.settings.top_p,
		metadata = opts.settings.metadata, -- only user_id
		stop_sequence = opts.settings.stop_sequence, -- broken
		tools = opts.settings.tools or construct_json_schema(opts.settings.json), -- allow json abstraction
		tool_choice = opts.settings.json and { type = "any" } or opts.settings.tool_choice, -- if json force any
	}

	return payload
end

---Extracting reply and tokens from client response
---@param response table
---@return string reply
---@return number input_tokens
---@return number output_tokens
function anthropic.extract_response_data(response)
	local reply = response.content[1].text or response.content[1].input -- plain text or tool use
	local input_tokens = response.usage.input_tokens
	local output_tokens = response.usage.output_tokens
	return reply, input_tokens, output_tokens
end

---Closure processing and accumulating streamed response chunk objects
---@param accumulator table Schema storing full streamed response
---@param processor function Display of streamed text chunks
---@return function handler
function anthropic.create_stream_handler(accumulator, processor)
	---Parse and process provider specific chunked responses structure for text and token usage
	---@param obj table JSON from string chunk
	return function(obj)
		-- errors:
		if obj.type == "error" and obj.error then
			local err_msg = string.format("%s: %s", obj.error.type, obj.error.message)
			error(err_msg)

		-- text:
		elseif obj.type == "content_block_delta" and obj.delta then
			local text = obj.delta.text or obj.delta.partial_json
			accumulator.schema.content[1].text = accumulator.schema.content[1].text .. text
			processor(text)

		-- input_tokens:
		elseif obj.type == "message_start" and obj.message and obj.message.usage and obj.message.usage.input_tokens then
			local input_tokens = obj.message.usage.input_tokens
			accumulator.schema.usage.input_tokens = accumulator.schema.usage.input_tokens + input_tokens

		-- output_tokens:
		elseif obj.type == "message_delta" and obj.usage and obj.usage.output_tokens then
			local output_tokens = obj.usage.output_tokens
			accumulator.schema.usage.output_tokens = accumulator.schema.usage.output_tokens + output_tokens
		end
	end
end

---Handle various status codes returned by the API
---@param response table
---@param status_code number
function anthropic.handle_exceptions(response, status_code)
	if status_code >= 300 then
		local err_msg = string.format("%d %s: %s", status_code or "", response.error.type, response.error.message)
		error(err_msg)
	end
end

---Lua pattern match for provider specific stream chunk data json
---@type string
anthropic.stream_pattern = "^data:%s*(.*)"

---Data structure to accumulate stream for centralized parsing
---@type table
anthropic.response_schema = {
	content = { { text = "" } },
	usage = {
		input_tokens = 0,
		output_tokens = 0,
	},
}

---All model input and output pricing per million tokens
---@type table
anthropic.pricing = {
	["claude-3-5-haiku-20241022"] = {
		input = 1,
		output = 5,
	},
	["claude-3-5-sonnet-20241022"] = {
		input = 3,
		output = 15,
	},
}

return anthropic

end)() end,
    function()local wax,script,require=ImportGlobals(7)local ImportGlobals return (function(...)-- "https://api.openai.com/v1/chat/completions"

---@module "genai.providers.openai"
local openai = {}

---Package system prompt
---@param system_prompt string
---@return table|nil
function openai.construct_system_message(system_prompt)
	local system_message = nil
	if system_prompt then system_message = { role = "system", content = system_prompt } end
	return system_message
end

---Package user prompt
---@param user_prompt string
---@return table
function openai.construct_user_message(user_prompt)
	local user_message = { role = "user", content = user_prompt }
	return user_message
end

---Package AI reply
---@param reply string
---@return table
function openai.construct_assistant_message(reply)
	local assistant_message = { role = "assistant", content = reply }
	return assistant_message
end

---Construct the request headers
---@param api_key string?
---@return table headers
function openai.construct_headers(api_key)
	local headers = {
		["Content-Type"] = "application/json",
		["Authorization"] = "Bearer " .. tostring(api_key),
	}
	return headers
end

---Abstract structuring json responses
---@param opts table {title: string, description: string, schema: table}
---@return table? response_format
local function construct_json_schema(opts)
	if opts then
		return {
			type = "json_schema",
			json_schema = {
				schema = {
					type = "object",
					properties = opts.schema,
				},
				name = opts.title,
				description = opts.description,
			},
		}
	end
end

---Package AI settings
---@param opts table
---@return table
function openai.construct_payload(opts)
	local do_stream = opts.settings.stream and true or nil

	local payload = {
		model = opts.model,
		messages = opts.history,
		-- basic settings:
		stream = do_stream,
		stream_options = do_stream and { include_usage = true } or nil,
		-- TODO: add advanced settings
		response_format = opts.settings.response_format or construct_json_schema(opts.settings.json),
	}

	return payload
end

---Extract reply and tokens from client response
---@param response table
---@return string reply
---@return number input_tokens
---@return number output_tokens
function openai.extract_response_data(response)
	if not response or not response.choices or #response.choices == 0 then return nil, nil, nil end
	local choice = table.remove(response.choices, 1)
	local reply = choice.message.content
	local input_tokens = response.usage and response.usage.prompt_tokens or 0
	local output_tokens = response.usage and response.usage.completion_tokens or 0
	return reply, input_tokens, output_tokens
end

---Closure processing and accumulating streamed response chunk objects
---@param accumulator table Schema storing full streamed response
---@param processor function Display of streamed text chunks
---@return function handler
function openai.create_stream_handler(accumulator, processor)
	---Parse and process provider specific chunked responses structure for text and token usage
	---@param obj table JSON from string chunk
	return function(obj)
		-- errors:
		if obj.type == "error" and obj.error then
			local err_msg = string.format("%s: %s", obj.error.type, obj.error.message)
			error(err_msg)

		-- text:
		elseif
			obj.object == "chat.completion.chunk"
			and obj.choices
			and #obj.choices > 0
			and obj.choices[1].delta
			and obj.choices[1].delta.content
		then
			local text = obj.choices[1].delta.content
			accumulator.schema.choices[1].message.content = accumulator.schema.choices[1].message.content .. text
			processor(text)

		-- input_tokens:
		elseif
			obj.object == "chat.completion.chunk"
			and obj.usage
			and type(obj.usage) == "table"
			and obj.usage.prompt_tokens
		then
			local input_tokens = obj.usage.prompt_tokens
			accumulator.schema.usage.prompt_tokens = accumulator.schema.usage.prompt_tokens + input_tokens

		-- output_tokens:
		elseif
			obj.object == "chat.completion.chunk"
			and obj.usage
			and type(obj.usage) == "table"
			and obj.usage.completion_tokens
		then
			local output_tokens = obj.usage.completion_tokens
			accumulator.schema.usage.completion_tokens = accumulator.schema.usage.completion_tokens + output_tokens
		end
	end
end

---Handle various status codes returned by the API
---@param response table
---@param status_code number
function openai.handle_exceptions(response, status_code)
	if response and response.error and response.error.type and response.error.message then
		local err_msg = string.format("%d %s: %s", status_code, response.error.type, response.error.message)
		error(err_msg)
	end
end

---Lua pattern match for provider specific stream chunk data json
---@type string
openai.stream_pattern = "^data:%s*(.*)"

---Data structure to accumulate stream for centralized parsing
---@type table
openai.response_schema = {
	choices = {
		{ message = { content = "" } },
	},
	usage = {
		prompt_tokens = 0,
		completion_tokens = 0,
	},
}

openai.pricing = {
	["gpt-4o-mini"] = {
		input = 0.15,
		output = 0.6,
	},
	["gpt-4o"] = {
		input = 5,
		output = 15,
	},
	["gpt-4o-2024-11-20"] = {
		input = 2.5,
		output = 15,
	},
}

return openai

end)() end,
    function()local wax,script,require=ImportGlobals(8)local ImportGlobals return (function(...)local cjson = game:GetService("HttpService")
local RunService = game:GetService("RunService")

---@module "genai.utils"
local utils = {}

---Https request with partial response functionality via callback as well as non-blocking via copas
---@param url string
---@param payload table?
---@param method string?
---@param headers table?
---@param callback function?
---@param exception_handler function?
---@return string|table body
function utils.send_request(url, payload, method, headers, callback, exception_handler)
	local success, response
	local req = {
		Url = url,
		Method = method or "GET",
		Headers = headers or {},
		Body = payload
	}
	
	if payload then
		req.Headers["Content-Length"] = tostring(#payload)
	end
	
	if RunService:IsStudio() then
		success, response = pcall(function()
			return cjson:RequestAsync(req)
		end)
	else
		success, response = pcall(getgenv().request, req)
	end
	
	if not success or not response then
		if exception_handler then
			return exception_handler(nil, 0)
		else
			error("Request failed: " .. tostring(response))
		end
	end

	local body = response.Body or ""
	local status_code = response.StatusCode or 0
	local content_type = response.Headers and response.Headers["Content-Type"] or ""

	if callback then
		callback(body)
	end

	if type(body) == "string" and body:sub(1, 1) == "{" or body:sub(1, 1) == "[" then
		local success, parsed = pcall(function() return game:GetService("HttpService"):JSONDecode(body) end)
		if success then
			body = parsed
		end
	end

	if exception_handler then
		exception_handler(body, status_code)
	else
		assert(status_code == 200, body)
	end

	return body
end

---Storage for full stream response
---@class Accumulator
---@field schema table Provider specific non-streamed response matching schema
local Accumulator = {}
Accumulator.__index = Accumulator

---@param schema string Encoded provider specific schema table
function Accumulator.new(schema)
	local self = setmetatable({}, Accumulator)
	self.schema = cjson:JSONDecode(schema)
	return self
end

utils.Accumulator = Accumulator

---Closure to parse SSE via callback
---@param opts table
---@return function chunk_callback
function utils.create_sse_callback(opts)
	local pattern, handler = table.unpack(opts)

	local buffer = ""

	---Callback to parse chunks from SSE
	---@param chunk string
	local function chunk_callback(chunk)
		if not chunk then return end
		buffer = buffer .. chunk

		while true do
			local newline_pos = buffer:find("\n")
			if not newline_pos then break end

			local line = buffer:sub(1, newline_pos - 1)
			buffer = buffer:sub(newline_pos + 1)

			local json_str = line:match(pattern)
			if json_str then
				local ok, obj = pcall(function() return game:GetService("HttpService"):JSONDecode(json_str) end)
				if ok and obj then handler(obj) end
			end
		end
	end
	return chunk_callback
end

---Caculate model pricing from input and output tokens in USD
---@param model string
---@param usage table
---@param pricing table
---@return number
function utils.calc_token_cost(model, usage, pricing)
	local model_pricing = pricing[model]

	if model_pricing then
		local one_mil = 1000000
		local input_cost = usage.input * (model_pricing.input / one_mil)
		local output_cost = usage.output * (model_pricing.output / one_mil)
		return input_cost + output_cost
	else
		return 0
	end
end

return utils

end)() end
} -- [RefId] = Closure

-- Holds the actual DOM data
local ObjectTree = {
    {
        1,
        2,
        {
            "NullFire-Genai"
        },
        {
            {
                8,
                2,
                {
                    "utils"
                }
            },
            {
                5,
                2,
                {
                    "providers"
                },
                {
                    {
                        7,
                        2,
                        {
                            "openai"
                        }
                    },
                    {
                        6,
                        2,
                        {
                            "anthropic"
                        }
                    }
                }
            },
            {
                2,
                2,
                {
                    "features"
                },
                {
                    {
                        3,
                        2,
                        {
                            "chat"
                        }
                    }
                }
            },
            {
                4,
                2,
                {
                    "genai"
                }
            }
        }
    }
}

-- Line offsets for debugging (only included when minifyTables is false)
local LineOffsets = {
    8,
    13,
    21,
    76,
    190,
    199,
    366,
    551
}

-- Misc AOT variable imports
local WaxVersion = "0.4.1"
local EnvName = "genai"

-- ++++++++ RUNTIME IMPL BELOW ++++++++ --

-- Localizing certain libraries and built-ins for runtime efficiency
local string, task, setmetatable, error, next, table, unpack, coroutine, script, type, require, pcall, tostring, tonumber, _VERSION =
      string, task, setmetatable, error, next, table, unpack, coroutine, script, type, require, pcall, tostring, tonumber, _VERSION

local table_insert = table.insert
local table_remove = table.remove
local table_freeze = table.freeze or function(t) return t end -- lol

local coroutine_wrap = coroutine.wrap

local string_sub = string.sub
local string_match = string.match
local string_gmatch = string.gmatch

-- The Lune runtime has its own `task` impl, but it must be imported by its builtin
-- module path, "@lune/task"
if _VERSION and string_sub(_VERSION, 1, 4) == "Lune" then
    local RequireSuccess, LuneTaskLib = pcall(require, "@lune/task")
    if RequireSuccess and LuneTaskLib then
        task = LuneTaskLib
    end
end

local task_defer = task and task.defer

-- If we're not running on the Roblox engine, we won't have a `task` global
local Defer = task_defer or function(f, ...)
    coroutine_wrap(f)(...)
end

-- ClassName "IDs"
local ClassNameIdBindings = {
    [1] = "Folder",
    [2] = "ModuleScript",
    [3] = "Script",
    [4] = "LocalScript",
    [5] = "StringValue",
}

local RefBindings = {} -- [RefId] = RealObject

local ScriptClosures = {}
local ScriptClosureRefIds = {} -- [ScriptClosure] = RefId
local StoredModuleValues = {}
local ScriptsToRun = {}

-- wax.shared __index/__newindex
local SharedEnvironment = {}

-- We're creating 'fake' instance refs soley for traversal of the DOM for require() compatibility
-- It's meant to be as lazy as possible
local RefChildren = {} -- [Ref] = {ChildrenRef, ...}

-- Implemented instance methods
local InstanceMethods = {
    GetFullName = { {}, function(self)
        local Path = self.Name
        local ObjectPointer = self.Parent

        while ObjectPointer do
            Path = ObjectPointer.Name .. "." .. Path

            -- Move up the DOM (parent will be nil at the end, and this while loop will stop)
            ObjectPointer = ObjectPointer.Parent
        end

        return Path
    end},

    GetChildren = { {}, function(self)
        local ReturnArray = {}

        for Child in next, RefChildren[self] do
            table_insert(ReturnArray, Child)
        end

        return ReturnArray
    end},

    GetDescendants = { {}, function(self)
        local ReturnArray = {}

        for Child in next, RefChildren[self] do
            table_insert(ReturnArray, Child)

            for _, Descendant in next, Child:GetDescendants() do
                table_insert(ReturnArray, Descendant)
            end
        end

        return ReturnArray
    end},

    FindFirstChild = { {"string", "boolean?"}, function(self, name, recursive)
        local Children = RefChildren[self]

        for Child in next, Children do
            if Child.Name == name then
                return Child
            end
        end

        if recursive then
            for Child in next, Children do
                -- Yeah, Roblox follows this behavior- instead of searching the entire base of a
                -- ref first, the engine uses a direct recursive call
                return Child:FindFirstChild(name, true)
            end
        end
    end},

    FindFirstAncestor = { {"string"}, function(self, name)
        local RefPointer = self.Parent
        while RefPointer do
            if RefPointer.Name == name then
                return RefPointer
            end

            RefPointer = RefPointer.Parent
        end
    end},

    -- Just to implement for traversal usage
    WaitForChild = { {"string", "number?"}, function(self, name)
        return self:FindFirstChild(name)
    end},
}

-- "Proxies" to instance methods, with err checks etc
local InstanceMethodProxies = {}
for MethodName, MethodObject in next, InstanceMethods do
    local Types = MethodObject[1]
    local Method = MethodObject[2]

    local EvaluatedTypeInfo = {}
    for ArgIndex, TypeInfo in next, Types do
        local ExpectedType, IsOptional = string_match(TypeInfo, "^([^%?]+)(%??)")
        EvaluatedTypeInfo[ArgIndex] = {ExpectedType, IsOptional}
    end

    InstanceMethodProxies[MethodName] = function(self, ...)
        if not RefChildren[self] then
            error("Expected ':' not '.' calling member function " .. MethodName, 2)
        end

        local Args = {...}
        for ArgIndex, TypeInfo in next, EvaluatedTypeInfo do
            local RealArg = Args[ArgIndex]
            local RealArgType = type(RealArg)
            local ExpectedType, IsOptional = TypeInfo[1], TypeInfo[2]

            if RealArg == nil and not IsOptional then
                error("Argument " .. RealArg .. " missing or nil", 3)
            end

            if ExpectedType ~= "any" and RealArgType ~= ExpectedType and not (RealArgType == "nil" and IsOptional) then
                error("Argument " .. ArgIndex .. " expects type \"" .. ExpectedType .. "\", got \"" .. RealArgType .. "\"", 2)
            end
        end

        return Method(self, ...)
    end
end

local function CreateRef(className, name, parent)
    -- `name` and `parent` can also be set later by the init script if they're absent

    -- Extras
    local StringValue_Value

    -- Will be set to RefChildren later aswell
    local Children = setmetatable({}, {__mode = "k"})

    -- Err funcs
    local function InvalidMember(member)
        error(member .. " is not a valid (virtual) member of " .. className .. " \"" .. name .. "\"", 3)
    end
    local function ReadOnlyProperty(property)
        error("Unable to assign (virtual) property " .. property .. ". Property is read only", 3)
    end

    local Ref = {}
    local RefMetatable = {}

    RefMetatable.__metatable = false

    RefMetatable.__index = function(_, index)
        if index == "ClassName" then -- First check "properties"
            return className
        elseif index == "Name" then
            return name
        elseif index == "Parent" then
            return parent
        elseif className == "StringValue" and index == "Value" then
            -- Supporting StringValue.Value for Rojo .txt file conv
            return StringValue_Value
        else -- Lastly, check "methods"
            local InstanceMethod = InstanceMethodProxies[index]

            if InstanceMethod then
                return InstanceMethod
            end
        end

        -- Next we'll look thru child refs
        for Child in next, Children do
            if Child.Name == index then
                return Child
            end
        end

        -- At this point, no member was found; this is the same err format as Roblox
        InvalidMember(index)
    end

    RefMetatable.__newindex = function(_, index, value)
        -- __newindex is only for props fyi
        if index == "ClassName" then
            ReadOnlyProperty(index)
        elseif index == "Name" then
            name = value
        elseif index == "Parent" then
            -- We'll just ignore the process if it's trying to set itself
            if value == Ref then
                return
            end

            if parent ~= nil then
                -- Remove this ref from the CURRENT parent
                RefChildren[parent][Ref] = nil
            end

            parent = value

            if value ~= nil then
                -- And NOW we're setting the new parent
                RefChildren[value][Ref] = true
            end
        elseif className == "StringValue" and index == "Value" then
            -- Supporting StringValue.Value for Rojo .txt file conv
            StringValue_Value = value
        else
            -- Same err as __index when no member is found
            InvalidMember(index)
        end
    end

    RefMetatable.__tostring = function()
        return name
    end

    setmetatable(Ref, RefMetatable)

    RefChildren[Ref] = Children

    if parent ~= nil then
        RefChildren[parent][Ref] = true
    end

    return Ref
end

-- Create real ref DOM from object tree
local function CreateRefFromObject(object, parent)
    local RefId = object[1]
    local ClassNameId = object[2]
    local Properties = object[3] -- Optional
    local Children = object[4] -- Optional

    local ClassName = ClassNameIdBindings[ClassNameId]

    local Name = Properties and table_remove(Properties, 1) or ClassName

    local Ref = CreateRef(ClassName, Name, parent) -- 3rd arg may be nil if this is from root
    RefBindings[RefId] = Ref

    if Properties then
        for PropertyName, PropertyValue in next, Properties do
            Ref[PropertyName] = PropertyValue
        end
    end

    if Children then
        for _, ChildObject in next, Children do
            CreateRefFromObject(ChildObject, Ref)
        end
    end

    return Ref
end

local RealObjectRoot = CreateRef("Folder", "[" .. EnvName .. "]")
for _, Object in next, ObjectTree do
    CreateRefFromObject(Object, RealObjectRoot)
end

-- Now we'll set script closure refs and check if they should be ran as a BaseScript
for RefId, Closure in next, ClosureBindings do
    local Ref = RefBindings[RefId]

    ScriptClosures[Ref] = Closure
    ScriptClosureRefIds[Ref] = RefId

    local ClassName = Ref.ClassName
    if ClassName == "LocalScript" or ClassName == "Script" then
        table_insert(ScriptsToRun, Ref)
    end
end

local function LoadScript(scriptRef)
    local ScriptClassName = scriptRef.ClassName

    -- First we'll check for a cached module value (packed into a tbl)
    local StoredModuleValue = StoredModuleValues[scriptRef]
    if StoredModuleValue and ScriptClassName == "ModuleScript" then
        return unpack(StoredModuleValue)
    end

    local Closure = ScriptClosures[scriptRef]

    local function FormatError(originalErrorMessage)
        originalErrorMessage = tostring(originalErrorMessage)

        local VirtualFullName = scriptRef:GetFullName()

        -- Check for vanilla/Roblox format
        local OriginalErrorLine, BaseErrorMessage = string_match(originalErrorMessage, "[^:]+:(%d+): (.+)")

        if not OriginalErrorLine or not LineOffsets then
            return VirtualFullName .. ":*: " .. (BaseErrorMessage or originalErrorMessage)
        end

        OriginalErrorLine = tonumber(OriginalErrorLine)

        local RefId = ScriptClosureRefIds[scriptRef]
        local LineOffset = LineOffsets[RefId]

        local RealErrorLine = OriginalErrorLine - LineOffset + 1
        if RealErrorLine < 0 then
            RealErrorLine = "?"
        end

        return VirtualFullName .. ":" .. RealErrorLine .. ": " .. BaseErrorMessage
    end

    -- If it's a BaseScript, we'll just run it directly!
    if ScriptClassName == "LocalScript" or ScriptClassName == "Script" then
        local RunSuccess, ErrorMessage = xpcall(Closure, function(msg)
            return debug.traceback(msg, 2)
        end)
        if not RunSuccess then
            error(FormatError(ErrorMessage), 0)
        end
    else
        local PCallReturn = {xpcall(Closure, function(msg)
            return debug.traceback(msg, 2)
        end)}

        local RunSuccess = table_remove(PCallReturn, 1)
        if not RunSuccess then
            local ErrorMessage = table_remove(PCallReturn, 1)
            error(FormatError(ErrorMessage), 0)
        end

        StoredModuleValues[scriptRef] = PCallReturn
        return unpack(PCallReturn)
    end
end

-- We'll assign the actual func from the top of this output for flattening user globals at runtime
-- Returns (in a tuple order): wax, script, require
function ImportGlobals(refId)
    local ScriptRef = RefBindings[refId]

    local function RealCall(f, ...)
        local PCallReturn = {xpcall(f, function(msg)
            return debug.traceback(msg, 2)
        end, ...)}

        local CallSuccess = table_remove(PCallReturn, 1)
        if not CallSuccess then
            error(PCallReturn[1], 3)
        end

        return unpack(PCallReturn)
    end

    -- `wax.shared` index
    local WaxShared = table_freeze(setmetatable({}, {
        __index = SharedEnvironment,
        __newindex = function(_, index, value)
            SharedEnvironment[index] = value
        end,
        __len = function()
            return #SharedEnvironment
        end,
        __iter = function()
            return next, SharedEnvironment
        end,
    }))

    local Global_wax = table_freeze({
        -- From AOT variable imports
        version = WaxVersion,
        envname = EnvName,

        shared = shared,

        -- "Real" globals instead of the env set ones
        script = script,
        require = require,
    })

    local Global_script = ScriptRef

    local function Global_require(module, ...)
        local ModuleArgType = type(module)

        local ErrorNonModuleScript = "Attempted to call require with a non-ModuleScript"
        local ErrorSelfRequire = "Attempted to call require with self"

        if ModuleArgType == "table" and RefChildren[module]  then
            if module.ClassName ~= "ModuleScript" then
                error(ErrorNonModuleScript, 2)
            elseif module == ScriptRef then
                error(ErrorSelfRequire, 2)
            end

            return LoadScript(module)
        elseif ModuleArgType == "string" and string_sub(module, 1, 1) ~= "@" then
            -- The control flow on this SUCKS

            if #module == 0 then
                error("Attempted to call require with empty string", 2)
            end

            local CurrentRefPointer = ScriptRef

            if string_sub(module, 1, 1) == "/" then
                CurrentRefPointer = RealObjectRoot
            elseif string_sub(module, 1, 2) == "./" then
                module = string_sub(module, 3)
            end

            local PreviousPathMatch
            for PathMatch in string_gmatch(module, "([^/]*)/?") do
                local RealIndex = PathMatch
                if PathMatch == ".." then
                    RealIndex = "Parent"
                end

                -- Don't advance dir if it's just another "/" either
                if RealIndex ~= "" then
                    local ResultRef = CurrentRefPointer:FindFirstChild(RealIndex)
                    if not ResultRef then
                        local CurrentRefParent = CurrentRefPointer.Parent
                        if CurrentRefParent then
                            ResultRef = CurrentRefParent:FindFirstChild(RealIndex)
                        end
                    end

                    if ResultRef then
                        CurrentRefPointer = ResultRef
                    elseif PathMatch ~= PreviousPathMatch and PathMatch ~= "init" and PathMatch ~= "init.server" and PathMatch ~= "init.client" then
                        error("Virtual script path \"" .. module .. "\" not found", 2)
                    end
                end

                -- For possible checks next cycle
                PreviousPathMatch = PathMatch
            end

            if CurrentRefPointer.ClassName ~= "ModuleScript" then
                error(ErrorNonModuleScript, 2)
            elseif CurrentRefPointer == ScriptRef then
                error(ErrorSelfRequire, 2)
            end

            return LoadScript(CurrentRefPointer)
        end

        return RealCall(require, module, ...)
    end

    -- Now, return flattened globals ready for direct runtime exec
    return Global_wax, Global_script, Global_require
end

for _, ScriptRef in next, ScriptsToRun do
    Defer(LoadScript, ScriptRef)
end

-- AoT adjustment: Load init module (MainModule behavior)
return LoadScript(RealObjectRoot:GetChildren()[1])