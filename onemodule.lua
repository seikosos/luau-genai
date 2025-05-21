-- this is for lazy af people
-- this only adds openai and not anthropic provider

local cjson = game:GetService("HttpService")

local genai = {}
genai.utils = {}

local utils = genai.utils

---Https request with partial response functionality via callback as well as non-blocking via copas
---@param url string
---@param payload table?
---@param method string?
---@param headers table?
---@param callback function?
---@param exception_handler function?
---@return string|table body
function utils.send_request(url, payload, method, headers, callback, exception_handler)
    local req = {
        Url = url,
        Method = method or "GET",
        Headers = headers or {},
        Body = payload
    }

    if payload then
        req.Headers["Content-Length"] = tostring(#payload)
    end

    local success, response = pcall(getgenv().request, req)
    if not success then
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

    if content_type:find("application/json") then
        local success, parsed = pcall(function() return game:GetService("HttpService"):JSONDecode(body) end)
        if success then
            body = parsed
        else
            warn("Failed to decode JSON response.")
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
	self.schema = type(schema) == "string" and cjson:JSONDecode(schema) or schema
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

genai.Chat = {}
local Chat = genai.Chat
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
	self.usage.input = self.usage.input + input_tokens
	self.usage.output = self.usage.output + output_tokens
	return reply
end

---Caculate model pricing from input and output tokens in USD
---@return number
function Chat:get_cost()
	return utils.calc_token_cost(self.model, self.usage, self.client.provider.pricing)
end

-- "https://api.openai.com/v1/chat/completions"

genai.openai = {}
local openai = genai.openai

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
	local reply = response.choices[1].message.content
	local input_tokens = response.usage.prompt_tokens
	local output_tokens = response.usage.completion_tokens
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
	if status_code >= 300 then
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

local GenAI = {}
GenAI.__index = GenAI

---@param api_key? string
---@param endpoint string
function GenAI.new(api_key, endpoint)
	local self = setmetatable({}, GenAI)
	self._api_key = api_key
	self._endpoint = endpoint
	self.provider = self:_determine_provider({["openai"]=genai.openai})
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

	local reply, input_tokens, output_tokens =
		self.provider.extract_response_data(accumulator and accumulator.schema or response)
	reply = type(reply) == "table" and cjson:JSONEncode(reply) or reply -- ensure json output is string

	return reply, input_tokens, output_tokens
end

-- features:

---Create chat instance with automatic tracking of messages and tokens
---@param model string
---@param opts table? Containing **settings** and or **system_prompt**
---@return Chat
function GenAI:chat(model, opts)
	return genai.Chat.new(self, model, opts)
end

getgenv().genai = GenAI