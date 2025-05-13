local OpenAiTranslator = require("kong.plugins.pangea-ai-guard-shared.pangea-translator.openai")

-- The request format is close enough to OpenAI's that we can use it
-- CohereTranslator.prepare_messages_from_llm_request = OpenAiTranslator.prepare_messages_from_llm_request

-- The output differs from OpenAIs
local function prepare_messages_from_llm_response(response)
	if type(response) ~= "table" then
		return nil, "Invalid response object"
	end

	local messages = response.message
	if messages == nil or type(messages) ~= "table" then
		return nil, "Invalid response object"
	end

	local ret = {
		messages = {},
		lookup = {},
	}

	local role = messages.role
	for idx, content in ipairs(messages.content) do
		if content.type == "text" then
			table.insert(ret.messages, {
				content = content.text,
				role = role,
			})
			table.insert(ret.lookup, {
				"message",
				"content",
				idx,
				"text",
			})
		end
	end

	return ret
end

local CohereTranslator = {
	["/v2/chat"] = {
		["request"] = OpenAiTranslator["/v1/chat/completions"].request,
		["response"] = prepare_messages_from_llm_response,
	},
}

return CohereTranslator
