local http = require("resty.http")

local kong_utils = require("kong.tools.gzip")
local ai_plugin_ctx = require("kong.llm.plugin.ctx")

local get_global_ctx, set_global_ctx = ai_plugin_ctx.get_global_accessors("pangea-ai-guard-response")

local ai_guard = require("kong.plugins.pangea-ai-guard-shared.ai_guard")

-- Plugin class
local PangeaAIGuardResponseHandler = {
	-- Set priority low so that this runs after ai-proxy (and our request handler)
	PRIORITY = 760,
	VERSION = "0.1.0",
}

local function convert_llm_response(config, res)
	local encoding = res.headers["Content-Encoding"]
	local raw_body = res.body
	if encoding == "gzip" then
		raw_body = kong_utils.inflate_gzip(raw_body)
	end

	if config.upstream_llm.provider ~= "kong" then
		return raw_body
	end

	-- Manually convert to the kong ai-proxy format here
	local service = kong.router.get_service()
	if not service then
		return nil, "Failed to retrieve current service"
	end

	local ai_proxy_plugin = nil
	for plugin, err in kong.db.plugins:each_for_service { id = service.id } do
		if not plugin then
			return nil, err
		end
		if plugin.name == "ai-proxy" then
			ai_proxy_plugin = plugin
		end
	end

	if ai_proxy_plugin == nil then
		-- If the language type is "kong", this should be true
		return nil, "Failed to retrieve ai-proxy config"
	end

	local conf = ai_proxy_plugin.config

	local kong_ai_driver = require("kong.llm.drivers." .. conf.model.provider)
	local kong_response_body, err = kong_ai_driver.from_format(raw_body, conf.model, conf.route_type)
	if err ~= nil then
		return nil, "Failed to parse body: " .. err
	end

	return kong_response_body
end

local function manual_upstream_request()
	local httpc = http.new()

	local ok, err = httpc:connect {
		scheme = ngx.var.upstream_scheme,
		host = ngx.ctx.balancer_data.host,
		port = ngx.ctx.balancer_data.port,
		ssl_server_name = ngx.ctx.balancer_data.host,
	}
	if err ~= nil then
		return nil, err
	end

	if not ok then
		return nil, "Failed to connect to upstream"
	end

	local headers = kong.request.get_headers()
	headers["transfer-encoding"] = nil
	headers["content-length"] = nil

	if ngx.var.upstream_host == "" then
		headers["host"] = nil
	else
		headers["host"] = ngx.var.upstream_host
	end

	local request_body = kong.request.get_raw_body()

	local res, err = httpc:request {
		method = kong.request.get_method(),
		path = ngx.var.upstream_uri,
		headers = headers,
		body = request_body,
	}
	if err ~= nil then
		return nil, err
	end

	local reader = res.body_reader
	local body_chunks = {}
	if reader then
		repeat
			local chunk, err = reader(8192)
			if err then
				return nil, err
			end
			if chunk then
				table.insert(body_chunks, chunk)
			end
		until not chunk
	end

	res.body = table.concat(body_chunks)
	return res
end

-- Here we shortcut the request in the access phase
-- This solution isn't ideal, but it's the only real way to keep our
-- plugin composeable with Kong's own ai-proxy
-- Ideally this would be in the response() phase -- in terms of nginx (openresty) internals
-- I think these are basically the same thing -- with the only exception being that this can
-- have weird side-effects depending on other plugins enabled
function PangeaAIGuardResponseHandler:access(config)
	kong.service.request.enable_buffering()

	kong.ctx.plugin.log_fields = ai_guard.get_log_fields(config)
	kong.log.debug("Shortcutting by making upstream request in access() phase")
	local res, err = manual_upstream_request()
	if err ~= nil or not res then
		return kong.response.exit(500, { status = "Internal server error" })
	end
	if res.status ~= 200 then
		-- Upstream LLM error, we won't touch it
		return kong.response.exit(res.status, res.body, res.headers)
	end

	local response, err = convert_llm_response(config, res)
	if err ~= nil then
		kong.log.debug("Internal server error")
		return kong.response.exit(500, { status = "Internal server error" })
	end

	res.headers["content-length"] = nil
	res.headers["content-encoding"] = nil
	res.headers["content-type"] = "application/json"

	local updated_response = ai_guard.run_ai_guard(config, "response", response, kong.ctx.plugin.log_fields)
	if updated_response ~= nil then
		response = updated_response
	end

	return kong.response.exit(res.status, response, res.headers)
end

-- function PangeaAIGuardResponseHandler:header_filter(config)
-- 	-- We don't know if we need to clear this or not -- but we might
-- 	kong.response.clear_header("Content-Length")
-- end

-- function PangeaAIGuardResponseHandler:body_filter(config) end

-- function PangeaAIGuardResponseHandler:response(config)
-- 	kong.log.debug("========== AAAAAAAAAA ==========")
-- 	-- kong.log.inspect(ngx.arg[1])
-- 	-- kong.log.inspect(ngx.arg[2])
-- 	-- ai_guard.run_ai_guard(config, "response", kong.ctx.plugin.log_fields)
-- end

return PangeaAIGuardResponseHandler
