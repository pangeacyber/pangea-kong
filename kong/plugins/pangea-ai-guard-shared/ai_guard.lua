local cjson = require("cjson.safe")
local http = require("resty.http")
local translate = require("kong.plugins.pangea-ai-guard-shared.pangea-translator")

local internalError = {
	status = "Internal server error",
}

local AIGuard = {}

---@alias mode "request" | "response"

---@param config table plugin config -- response and request plugins share fields
---@param mode mode Are we running on a request or a response object
---@param raw_original_body string
---@param log_fields table additional log fields for AI Guard API
function AIGuard.run_ai_guard(config, mode, raw_original_body, log_fields)
	local exit_fn = kong.response.exit

	local original_body, err = cjson.decode(raw_original_body)
	if err then
		kong.log.inspect(raw_original_body)
		kong.log.err("Error decoding input body: " .. err)
		local message = {
			status = "Failed to decode JSON body",
			reason = err,
		}
		return exit_fn(400, message)
	end

	local translator_instance, err = translate.get_translator(config.upstream_llm.provider)
	if err ~= nil or translator_instance == nil then
		kong.log.err("Failed to get translator " .. err)
		return exit_fn(500, internalError)
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
		return exit_fn(500, internalError)
	end

	---@type JSONMessageMap, string?
	local messages, err = transformer[mode](original_body)
	if err ~= nil then
		kong.log.err("Failed to process message: " .. err)
		return exit_fn(500, internalError)
	end

	local ai_guard_request_body = {
		messages = messages.messages,
		log_fields = log_fields,
	}

	if config.recipe and config.recipe ~= ngx.null then
		ai_guard_request_body.recipe = config.recipe
	end

	local raw_ai_guard_request_body, err = cjson.encode(ai_guard_request_body)
	if err then
		kong.log.err("Error decoding request body: " .. err)
		return exit_fn(500, internalError)
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
		return exit_fn(500, internalError)
	end

	if res.status ~= 200 then
		kong.log.err("AI Guard returned error: ", res.status, " ", res.body)
		return exit_fn(500, internalError)
	end

	local response, err = cjson.decode(res.body)
	if err then
		kong.log.err("Error decoding Pangea AI Guard response: " .. err)
		return exit_fn(500, internalError)
	end

	if response.result.blocked then
		local message = {
			status = "Prompt has been rejected by AI Guard",
			reason = response.summary,
		}
		-- kong.log.warn("Detected unwanted prompt characteristics: ", name, " ", cjson.encode(response))
		return exit_fn(400, message)
	end

	local capabilities = translator_instance.capabilities or {}
	kong.log.inspect(capabilities)

	-- By default, we assume we _can_ redact, unless its been explicitly disabled
	local can_redact = capabilities.redaction
	if can_redact == nil then
		can_redact = true
	end

	if not can_redact then
		kong.log.debug("Skipping redaction step")
		return
	end

	kong.log.debug("Pangea AI Guard: content allowed")
	-- Now we need to check if anything has been redacted
	local prompt_messages = response.result.prompt_messages
	if #prompt_messages > 0 then
		local new_payload, updated = translate.rewrite_llm_message(original_body, messages, prompt_messages)
		if updated then
			kong.log.debug("Pangea AI Guard: required redaction")
			local raw_new_payload, err = cjson.encode(new_payload)
			if err ~= nil then
				kong.log.err("Failed to encode redacted payload: " .. err)
				return exit_fn(500, internalError)
			end
			return raw_new_payload
		end
	end
end

-- Needs to run the access phase
function AIGuard.get_log_fields(config)
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

return AIGuard
