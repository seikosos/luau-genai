local cjson = game:GetService("HttpService")
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
	
	if RunService:IsServer() then
		success, response = pcall(function()
			return cjson:RequestAsync(req)
		end)
	else
		success, response = pcall(getgenv().request, req)
	end
	print(success, response.StatusCode)
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

	if content_type:find("application/json") or type(body) == "string" and body:sub(1, 1) == "{" or body:sub(1, 1) == "[" then
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
