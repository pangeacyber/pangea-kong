local package_version = "0.1.0"
local rockspec_revision = "1"

package = "kong-pangea-ai-guard"
version = package_version .. "-" .. rockspec_revision
source = {
	url = "git+ssh://git@github.com/pangeacyber/pangea-kong.git",
}

description = {
	summary = "Kong Gateway plugin to integrate Pangea AI Guard",
	homepage = "https://pangea.cloud",
	license = "MIT",
}

build = {
	type = "builtin",
	modules = {
		["kong.plugins.pangea-ai-guard.handler"] = "kong/plugins/pangea-ai-guard/handler.lua",
		["kong.plugins.pangea-ai-guard.schema"] = "kong/plugins/pangea-ai-guard/schema.lua",
		["kong.plugins.pangea-ai-guard.pangea-translator.model"] = "kong/plugins/pangea-ai-guard/pangea-translator/model.lua",
		["kong.plugins.pangea-ai-guard.pangea-translator.openai"] = "kong/plugins/pangea-ai-guard/pangea-translator/openai.lua",
		["kong.plugins.pangea-ai-guard.pangea-translator.azureai"] = "kong/plugins/pangea-ai-guard/pangea-translator/azureai.lua",
		["kong.plugins.pangea-ai-guard.pangea-translator.cohere"] = "kong/plugins/pangea-ai-guard/pangea-translator/cohere.lua",
		["kong.plugins.pangea-ai-guard.pangea-translator.kong"] = "kong/plugins/pangea-ai-guard/pangea-translator/kong.lua",
	},
}
