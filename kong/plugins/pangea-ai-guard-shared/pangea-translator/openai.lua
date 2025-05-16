local Model = require("kong.plugins.pangea-ai-guard-shared.pangea-translator.model")

local role_transform = {
	["developer"] = Model.PangeaRoles.PromptRoleSystem,
	["system"] = Model.PangeaRoles.PromptRoleSystem,
	["user"] = Model.PangeaRoles.PromptRoleUser,
	["assistant"] = Model.PangeaRoles.PromptRoleLlm,
}

local function prepare_chat_completions_request(request)
	if type(request) ~= "table" then
		return nil, "Invalid llm request"
	end

	local streaming = request.stream
	if streaming then
		return nil, "Streaming responses are not supported"
	end

	local ret = Model.NewJSONMessageMap()

	for idx, message in ipairs(request.messages) do
		local role = message.role
		local content = message.content
		role = role_transform[role] or role

		-- Content is either a string OR an array of objects
		if type(content) == "string" then
			ret:add_message(content, role, { "messages", idx, "content" })
		elseif type(content) == "table" then
			for jdx, part in ipairs(content) do
				if part.type == "text" then
					ret:add_message(part.text, role, { "messages", idx, "content", jdx, "text" })
				end
			end
		end
	end

	return ret
end

local function prepare_chat_completions_response(response)
	if type(response) ~= "table" then
		return nil, "Invalid response object"
	end

	if response.object ~= "chat.completion" then
		return nil, "Invalid response object"
	end

	local ret = Model.NewJSONMessageMap()

	for idx, choice in ipairs(response.choices) do
		local role = choice.message.role
		local content = choice.message.content
		role = role_transform[role] or role

		if content then
			ret:add_message(content, role, { "choices", idx, "message", "content" })
		end
	end

	return ret
end

local function prepare_completions_request(request)
	if type(request) ~= "table" then
		return nil, "Invalid llm request"
	end

	local streaming = request.stream
	if streaming then
		return nil, "Streaming responses are not supported"
	end

	local ret = Model.NewJSONMessageMap()

	local prompt = request.prompt
	if type(prompt) == "string" then
		ret:add_message(prompt, "user", { "prompt" })
	elseif type(prompt) == "table" then
		for idx, message in ipairs(prompt) do
			ret:add_message(message, "user", { "prompt", idx })
		end
	end

	return ret
end

local function prepare_completions_response(response)
	if type(response) ~= "table" then
		return nil, "Invalid response object"
	end

	if response.object ~= "text_completion" then
		return nil, "Invalid response object"
	end

	local ret = Model.NewJSONMessageMap()

	for idx, choice in ipairs(response.choices) do
		local content = choice.text

		if content then
			ret:add_message(content, "assistant", { "choices", idx, "text" })
		end
	end

	return ret
end

local OpenAiTranslator = {
	["/v1/chat/completions"] = {
		["request"] = prepare_chat_completions_request,
		["response"] = prepare_chat_completions_response,
	},
	["/v1/completions"] = {
		["request"] = prepare_completions_request,
		["response"] = prepare_completions_response,
	},
}

return OpenAiTranslator
