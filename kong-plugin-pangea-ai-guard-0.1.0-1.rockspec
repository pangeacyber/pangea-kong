local package_version = "0.1.0"
local rockspec_revision = "1"

package = "kong-plugin-pangea-ai-guard"
version = package_version .. "-" .. rockspec_revision
source = {
	url = "git+ssh://git@github.com/pangeacyber/pangea-kong.git",
	tag = "v" .. package_version,
}

description = {
	summary = "Kong Gateway plugin to integrate Pangea AI Guard",
	detailed = [[
		kong-plugin-pangea-ai-guard is able to pass proxied LLM requests to Pangea AI Guard.
		Depending on the configuration, it can process both the request and response bodies
		to / from the LLM. It will respect the AI Guard when determing which actions to take,
		meaning it may decide to completely block any content, or it may redact content before
		passing it to the consumer. It does not need Kong AI Proxy or Kong AI Gateway to be
		configured, but it can work in conjunction with it.
	]],
	homepage = "https://github.com/pangeacyber/pangea-kong",
	license = "MIT",
}

dependences = {
	"lua >= 5.1",
}

build = {
	type = "builtin",
	modules = {
		["kong.plugins.pangea-ai-guard.handler"] = "kong/plugins/pangea-ai-guard/handler.lua",
		["kong.plugins.pangea-ai-guard.schema"] = "kong/plugins/pangea-ai-guard/schema.lua",
		["kong.plugins.pangea-ai-guard.pangea-translator.init"] = "kong/plugins/pangea-ai-guard/pangea-translator/init.lua",
		["kong.plugins.pangea-ai-guard.pangea-translator.model"] = "kong/plugins/pangea-ai-guard/pangea-translator/model.lua",
		-- List of llm modules -- be sure to keep up to date
		["kong.plugins.pangea-ai-guard.pangea-translator.anthropic"] = "kong/plugins/pangea-ai-guard/pangea-translator/anthropic.lua",
		["kong.plugins.pangea-ai-guard.pangea-translator.azureai"] = "kong/plugins/pangea-ai-guard/pangea-translator/azureai.lua",
		["kong.plugins.pangea-ai-guard.pangea-translator.cohere"] = "kong/plugins/pangea-ai-guard/pangea-translator/cohere.lua",
		["kong.plugins.pangea-ai-guard.pangea-translator.gemini"] = "kong/plugins/pangea-ai-guard/pangea-translator/gemini.lua",
		["kong.plugins.pangea-ai-guard.pangea-translator.kong"] = "kong/plugins/pangea-ai-guard/pangea-translator/kong.lua",
		["kong.plugins.pangea-ai-guard.pangea-translator.openai"] = "kong/plugins/pangea-ai-guard/pangea-translator/openai.lua",
	},
}
