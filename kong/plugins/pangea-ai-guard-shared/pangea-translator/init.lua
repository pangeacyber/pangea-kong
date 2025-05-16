local translate = {}

function translate.list_available_translators()
	return {
		"anthropic",
		"azureai",
		"bedrock",
		"cohere",
		"gemini",
		"kong",
		"openai",
	}
end

---@class Transformer
---@field request fun(body: table): JSONMessageMap, string?
---@field response fun(body: table): JSONMessageMap, string?

---@alias Translator { [string]: Transformer }

---@param original table Must be the table passed in to prepare_messages_from_llm_*
---@param message_mapping JSONMessageMap AIGuardMessages returned by prepare_messages_from_llm_*
---@param new_messages table Returned by AI Guard, .result.prompt_messages
---@return table The new body
---@return boolean Indicates if any values have been updated in the body
function translate.rewrite_llm_message(original, message_mapping, new_messages)
	local updated = false
	if not new_messages then
		return original, updated
	end

	for idx, prompt_message in ipairs(new_messages) do
		local this_message_lookup = message_mapping.lookup[idx]
		local content = original

		-- Remove the last part, so we can directly assign it
		local last_part = table.remove(this_message_lookup)
		for _, part in ipairs(this_message_lookup) do
			content = content[part]
		end
		if content[last_part] ~= prompt_message.content then
			content[last_part] = prompt_message.content
			updated = true
		end
	end

	return original, updated
end

---@return Translator|nil
---@return string ...
function translate.get_translator(provider)
	local ok, translator = pcall(require, "kong.plugins.pangea-ai-guard-shared.pangea-translator." .. provider)
	if not ok then
		return nil, "Unknown translator '" .. provider .. "'"
	end

	return translator
end

return translate
