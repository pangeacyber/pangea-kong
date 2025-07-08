local ai_guard = require("kong.plugins.pangea-ai-guard-shared.ai_guard")
local kong_utils = require("kong.tools.gzip")

-- Plugin class
local PangeaAIGuardRequestHandler = {
	-- Need to run BEFORE ai-proxy
	PRIORITY = 780,
	VERSION = "0.1.5",
}

local function get_raw_body()
	local encoding = kong.request.get_header("Content-Encoding")
	local raw_body = kong.request.get_raw_body()
	if encoding == "gzip" then
		raw_body = kong_utils.inflate_gzip(raw_body)
	end

	return raw_body
end

function PangeaAIGuardRequestHandler:access(config)
	-- local log_fields = ai_guard.get_log_fields(config)
	local raw_body = get_raw_body()

	local new_payload = ai_guard.run_ai_guard(config, "request", raw_body)
	if new_payload ~= nil then
		kong.service.request.set_raw_body(new_payload)
	end
end

return PangeaAIGuardRequestHandler
