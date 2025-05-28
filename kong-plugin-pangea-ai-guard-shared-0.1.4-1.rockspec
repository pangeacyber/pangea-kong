local package_version = "0.1.4"
local rockspec_revision = "1"

package = "kong-plugin-pangea-ai-guard-shared"
version = package_version .. "-" .. rockspec_revision
source = {
	url = "git+ssh://git@github.com/pangeacyber/pangea-kong.git",
	tag = "v" .. package_version,
}

description = {
	summary = "Kong Gateway plugin to integrate Pangea AI Guard",
	detailed = [[
		Implements the shared library for kong-plugin-ai-guard-request and kong-plugin-ai-guard-response,
		which will use Pangea AI Guard as a guardrails for LLM requests / responses.
	]],
	homepage = "https://github.com/pangeacyber/pangea-kong",
	license = "MIT",
}

dependencies = {
	"lua >= 5.1",
}

build = {
	type = "builtin",
	modules = {
		["kong.plugins.pangea-ai-guard-shared.ai_guard"] = "kong/plugins/pangea-ai-guard-shared/ai_guard.lua",
		["kong.plugins.pangea-ai-guard-shared.pangea-translator.init"] = "kong/plugins/pangea-ai-guard-shared/pangea-translator/init.lua",
		["kong.plugins.pangea-ai-guard-shared.pangea-translator.model"] = "kong/plugins/pangea-ai-guard-shared/pangea-translator/model.lua",
		-- List of llm modules -- be sure to keep up to date
		["kong.plugins.pangea-ai-guard-shared.pangea-translator.anthropic"] = "kong/plugins/pangea-ai-guard-shared/pangea-translator/anthropic.lua",
		["kong.plugins.pangea-ai-guard-shared.pangea-translator.azureai"] = "kong/plugins/pangea-ai-guard-shared/pangea-translator/azureai.lua",
		["kong.plugins.pangea-ai-guard-shared.pangea-translator.bedrock"] = "kong/plugins/pangea-ai-guard-shared/pangea-translator/bedrock.lua",
		["kong.plugins.pangea-ai-guard-shared.pangea-translator.cohere"] = "kong/plugins/pangea-ai-guard-shared/pangea-translator/cohere.lua",
		["kong.plugins.pangea-ai-guard-shared.pangea-translator.gemini"] = "kong/plugins/pangea-ai-guard-shared/pangea-translator/gemini.lua",
		["kong.plugins.pangea-ai-guard-shared.pangea-translator.kong"] = "kong/plugins/pangea-ai-guard-shared/pangea-translator/kong.lua",
		["kong.plugins.pangea-ai-guard-shared.pangea-translator.openai"] = "kong/plugins/pangea-ai-guard-shared/pangea-translator/openai.lua",
	},
}
