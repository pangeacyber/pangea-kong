local OpenAiTranslator = require("kong.plugins.pangea-ai-guard.pangea-translator.openai")

return {
	["/v1/messages"] = {

		-- Anthropic is similar to OpenAI API format, except they have a special spot for "system" prompts
		["request"] = function(request)
			local ret, err = OpenAiTranslator["/v1/chat/completions"].request(request)
			if err ~= nil or ret == nil then
				return ret, err
			end

			local system = request.system
			if system == nil then
				return ret
			end

			if type(system) == "string" then
				ret:add_message(system, "system", { "system" })
			elseif type(system) == "table" then
				for idx, content in ipairs(system) do
					if content.type == "text" then
						ret:add_message(content.text, "system", { "system", idx, "text" })
					end
				end
			end

			return ret
		end,

		["response"] = OpenAiTranslator["/v1/chat/completions"].response,
	},
}
