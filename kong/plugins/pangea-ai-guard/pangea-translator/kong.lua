local OpenAiTranslator = require("kong.plugins.pangea-ai-guard.pangea-translator.openai")

local KongAIProxyTranslator = {
	["/llm/v1/chat"] = {
		["request"] = OpenAiTranslator["/v1/chat/completions"].request,
		["response"] = OpenAiTranslator["/v1/chat/completions"].response,
	},
	["/llm/v1/completions"] = {
		["request"] = OpenAiTranslator["/v1/completions"].request,
		["response"] = OpenAiTranslator["/v1/completions"].response,
	},
}

return KongAIProxyTranslator
