local cjson = require("cjson.safe")
local http = require("resty.http")
local translate = require("kong.plugins.pangea-ai-guard.pangea-translator")

-- Is this safe to use? It's not part of the PDK but also like,
-- how else are you suppose to handle this?
local kong_utils = require("kong.tools.gzip")

-- Plugin class
local PangeaAIGuardHandler = {
	PRIORITY = 760,
	VERSION = "0.1.0",
}

local internalError = {
	status = "Internal server error",
}

local function get_raw_body_wrapper(ctx)
	return function()
		local encoding = ctx.get_header("Content-Encoding")
		local raw_body = ctx.get_raw_body()
		if encoding == "gzip" then
			raw_body = kong_utils.inflate_gzip(raw_body)
		end

		return raw_body
	end
end

local function run_ai_guard(config, vars)
	local raw_original_body = vars.get_raw_body()

	-- Process request
	local original_body, err = cjson.decode(raw_original_body)
	if err then
		kong.log.inspect(raw_original_body)
		kong.log.err("Error decoding input body: " .. err)
		local message = {
			status = "Failed to decode JSON body",
			reason = err,
		}
		return vars.exit(400, message)
	end

	local translator_instance, err = translate.get_translator(config.upstream_llm.provider)
	if err ~= nil or translator_instance == nil then
		kong.log.err("Failed to get translator " .. err)
		return kong.response.error(500)
	end

	local transformer = translator_instance[config.upstream_llm.api_uri]
	if transformer == nil then
		kong.log.debug(
			string.format(
				"Could not find transformer for provider '%s' for upstream uri '%s'",
				config.upstream_llm.provider,
				config.upstream_llm.api_uri
			)
		)
		return
	end

	---@type JSONMessageMap, string?
	local messages, err = transformer[vars.transform_fn_name](original_body)
	if err ~= nil then
		kong.log.err("Failed to process message: " .. err)
		return kong.exit(500, internalError)
	end

	local ai_guard_request_body = {
		messages = messages.messages,
		log_fields = kong.ctx.plugin.log_fields,
	}

	if vars.recipe and vars.recipe ~= ngx.null then
		ai_guard_request_body.recipe = vars.recipe
	end

	local raw_ai_guard_request_body, err = cjson.encode(ai_guard_request_body)
	if err then
		kong.log.err("Error decoding request body: " .. err)
		return kong.exit(500, internalError)
	end

	local url = config.ai_guard_api_url

	local httpc = http.new()
	local res, err = httpc:request_uri(url, {
		method = "POST",
		body = raw_ai_guard_request_body,
		headers = {
			["Authorization"] = "Bearer " .. config.ai_guard_api_key,
			["Content-Type"] = "application/json",
		},
	})

	if err then
		kong.log.err("Error making request to Pangea AI Guard: " .. err)
		return kong.exit(500, internalError)
	end

	if not res then
		kong.log.err("Failed to call AI Guard: ", err)
		return kong.exit(500, internalError)
	end

	if res.status ~= 200 then
		kong.log.err("AI Guard returned error: ", res.status, " ", res.body)
		return kong.exit(500, internalError)
	end

	local response, err = cjson.decode(res.body)
	if err then
		kong.log.err("Error decoding Pangea AI Guard response: " .. err)
		return kong.exit(500, internalError)
	end

	if response.result.blocked then
		for _, result in pairs(response.result.detectors) do
			if result.detected then
				local message = {
					status = "Prompt has been rejected by AI Guard",
					reason = response.summary,
				}
				-- kong.log.warn("Detected unwanted prompt characteristics: ", name, " ", cjson.encode(response))
				return vars.exit(400, message)
			end
		end
	else
		kong.log.debug("PangeaPlugin: Prompt allowed")
		local prompt_messages = response.result.prompt_messages
		if #prompt_messages > 0 then
			local new_payload, updated = translate.rewrite_llm_message(original_body, messages, prompt_messages)
			if updated then
				kong.log.debug("AI Guard rule requires original body to be transformed")
				vars.set_raw_body(cjson.encode(new_payload))
			else
				kong.log.debug("No transformations required for body")
			end
		end
	end
end

local function get_log_fields(config)
	-- Dont override? Keep AI Guard default for now
	-- local citations = {
	-- 	application = "Kong Gateway",
	-- }

	local model = {
		llm_provider = config.upstream_llm.provider,
	}

	local extra_info = {}

	local service = kong.router.get_service()
	if service then
		extra_info.kong_service = service.name
	end
	local route = kong.router.get_route()
	if route then
		extra_info.kong_route = route.name
	end

	local consumer = kong.client.get_consumer()
	if consumer then
		extra_info.kong_consumer_id = consumer.id
	end

	local source = {
		start_time = kong.request.get_start_time(),
		ip = kong.client.get_ip(),
		forwarded_for_ip = kong.client.get_forwarded_ip(),
		method = kong.request.get_method(),
		scheme = kong.request.get_scheme(),
		host = kong.request.get_host(),
		port = kong.request.get_port(),
		path = kong.request.get_path(),
		forwarded_scheme = kong.request.get_forwarded_scheme(),
		forwarded_host = kong.request.get_forwarded_host(),
		forwarded_port = kong.request.get_forwarded_port(),
		forwarded_path = kong.request.get_forwarded_path(),
	}

	return {
		-- citations = cjson.encode(citations),
		citations = "ai-guard",
		model = cjson.encode(model),
		extra_info = cjson.encode(extra_info),
		source = cjson.encode(source),
	}
end

function PangeaAIGuardHandler:access(config)
	-- Regarldess of which mode we are running in, we'll want to create the "log_fields" for AI Guard
	-- The response() phase loses certain information from the request PDK, so we'll calculate it here and store it
	kong.ctx.plugin.log_fields = get_log_fields(config)

	if config.guard_type == "both" or config.guard_type == "response" then
		-- Need this to be able to ready the body in the header_filter phase
		kong.service.request.enable_buffering()
	end
	if config.guard_type == "response" then
		return
	end

	local vars = {
		get_raw_body = get_raw_body_wrapper(kong.request),
		-- I don't know why it works like this
		-- The official request transformer plugin does it this way too though
		set_raw_body = kong.service.request.set_raw_body,
		recipe = config.request_recipe,
		transform_fn_name = "request",
		exit = kong.response.exit,
	}

	return run_ai_guard(config, vars)
end

function PangeaAIGuardHandler:response(config)
	if config.guard_type == "request" then
		return
	end

	-- Be sure to forward any errors from the downstream API
	local status = kong.response.get_status()
	if status ~= 200 then
		return
	end

	local vars = {
		get_raw_body = get_raw_body_wrapper(kong.service.response),
		-- In the `response` phase you can't use set_raw_body for some reason (probably an oversight)
		-- You CAN use kong.response.exit however, so we'll check if this has been set before returning
		set_raw_body = function(body)
			kong.response.clear_header("Content-Length")
			kong.response.clear_header("Content-Encoding")
			kong.ctx.plugin.response_body = body
		end,
		recipe = config.response_recipe,
		transform_fn_name = "response",
		exit = function(status, body)
			kong.response.clear_header("Content-Length")
			kong.response.clear_header("Content-Encoding")
			return kong.response.exit(status, body)
		end,
	}

	run_ai_guard(config, vars)

	local response_body = kong.ctx.plugin.response_body
	if response_body then
		return kong.response.exit(kong.response.get_status(), response_body, {
			["Content-Type"] = "application/json",
		})
	end
end

return PangeaAIGuardHandler
