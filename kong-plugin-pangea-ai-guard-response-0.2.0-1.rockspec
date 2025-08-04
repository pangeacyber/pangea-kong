local package_version = "0.2.0"
local rockspec_revision = "1"

package = "kong-plugin-pangea-ai-guard-response"
version = package_version .. "-" .. rockspec_revision
source = {
	url = "git+ssh://git@github.com/pangeacyber/pangea-kong.git",
	tag = "v" .. package_version,
}

description = {
	summary = "Kong Gateway plugin to integrate Pangea AI Guard",
	detailed = [[
		kong-plugin-pangea-ai-guard-response is able to pass proxied LLM requests to Pangea AI Guard.
		It will respect the AI Guard when determining which actions to take, meaning it may decide to
		completely block any content, or it may redact content before passing it to the consumer.
		It does not need Kong AI Proxy or Kong AI Gateway to be configured, but it can work in
		conjunction with it.

		As a compatability note with other plugins, this "shortcircuits" the request in the access() phase,
		the result being that any other plugin which works in the access() phase after this one will be skipped.
	]],
	homepage = "https://github.com/pangeacyber/pangea-kong",
	license = "MIT",
}

dependencies = {
	"lua >= 5.1",
	"kong-plugin-pangea-ai-guard-shared == " .. package_version,
}

build = {
	type = "builtin",
	modules = {
		["kong.plugins.pangea-ai-guard-response.handler"] = "kong/plugins/pangea-ai-guard-response/handler.lua",
		["kong.plugins.pangea-ai-guard-response.schema"] = "kong/plugins/pangea-ai-guard-response/schema.lua",
	},
}
