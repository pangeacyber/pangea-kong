local Model = require("kong.plugins.pangea-ai-guard.pangea-translator.model")

local role_transform = {
	["model"] = Model.PangeaRoles.PromptRoleLlm,

	__index = function(val)
		return val
	end,
}

local function prepare_chat_completions_request(request)
	if type(request) ~= "table" then
		return nil, "Invalid llm request"
	end

	local ret = Model.NewJSONMessageMap()

	local system = request.system_instructions
	if system ~= nil then
		for idx, part in ipairs(system.parts) do
			local text = part.text
			if text ~= nil then
				ret:add_message(text, "system", { "system_instructions", "parts", idx, "text" })
			end
		end
	end

	for idx, content in ipairs(request.contents) do
		local role = role_transform(content.role)
		for jdx, part in ipairs(content.parts) do
			local text = part.text
			if text ~= nil then
				ret:add_message(text, role, { "contents", idx, "parts", jdx, "text" })
			end
		end
	end

	return ret
end

local function prepare_chat_completions_response(response)
	if type(response) ~= "table" then
		return nil, "Invalid llm request"
	end

	local ret = Model.NewJSONMessageMap()

	for idx, candidate in ipairs(response.candidates) do
		for jdx, content in ipairs(candidate.content) do
			local role = role_transform(content.role) or Model.PangeaRoles.PromptRoleLlm
			for kdx, part in ipairs(content.parts) do
				local text = part.text
				if text ~= nil then
					ret:add_message(text, role, { "candidates", idx, "content", jdx, "parts", kdx, "text" })
				end
			end
		end
	end

	return ret
end

return {
	-- NOTE: The full API includes the model and the action in it,
	-- which we'll ignore for now -- these paths are really strictly informational
	-- for our config, rather than needing to be strictly "accurate" to the upstream API
	-- Seems like gemini and vertex use the same API format, so this can be shared between them
	["/v1/models"] = {
		["request"] = prepare_chat_completions_request,
		["response"] = prepare_chat_completions_response,
	},

	-- Alias? This is arguably more accurate than an API endpoint
	["generateContent"] = {
		["request"] = prepare_chat_completions_request,
		["response"] = prepare_chat_completions_response,
	},
}
