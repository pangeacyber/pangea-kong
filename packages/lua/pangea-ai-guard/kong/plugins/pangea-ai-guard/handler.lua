local cjson = require "cjson"
local http = require "resty.http"
local translator = require "kong.plugins.pangea-ai-guard.pangea-translator.translate"

local DEFAULT_PANGEA_DOMAIN = "aws.us.pangea.cloud"


-- Rule class
local Rule = {}
Rule.__index = Rule

function Rule.new(rule)
    local self = setmetatable({}, Rule)
    self.rule = rule
    self.host = rule.host
    self.endpoint = rule.endpoint
    self.prefix = rule.prefix
    self.protos = rule.protocols
    self.ports = rule.ports
    self.parser = rule.parser
    self.allow_failure = rule.allow_on_error or false
    return self
end

function Rule:match(host, endpoint, port, protocol, prefix)
    if host ~= self.host then
        return false
    end
    if self.endpoint and endpoint ~= self.endpoint then
        return false
    end
    if self.prefix and prefix ~= self.prefix then
        return false
    end
    if self.protos and not self.protos[protocol] then
        return false
    end
    if self.ports and not self.ports[tostring(port)] then
        return false
    end
    return true
end

function Rule:operation_params(op, service)
    service = service or "ai_guard"
    local svc = self.rule[service]
    if not svc then
        kong.log.info("PangeaPlugin: Rule:operation_params service not found")
        return nil
    end
    local info = svc[op] and svc[op].parameters
    if not info or info.enabled == false then
        kong.log.info("PangeaPlugin: Rule:operation_params operation or parameters not found")
        return nil
    end
    return info
end

-- Configuration class
local PangeaKongConfig = {}
PangeaKongConfig.__index = PangeaKongConfig

function PangeaKongConfig.new(config)
    local self = setmetatable({}, PangeaKongConfig)
    self.domain = config.pangea_domain or DEFAULT_PANGEA_DOMAIN
    self.insecure = config.insecure or false
    self.header_recipe_map = config.headers or {}
    self.rules = {}

    for _, rule in ipairs(config.rules or {}) do
        if rule.host then
            local endpoint = rule.endpoint
            local prefix = rule.prefix
            if endpoint and prefix then
                table.insert(self.rules, Rule.new(rule))
            end
        end
    end

    return self
end

function PangeaKongConfig:match_rule()
    local proto = kong.request.get_forwarded_scheme()
    local host = kong.request.get_forwarded_host()
    local port = kong.request.get_forwarded_port()
    local endpoint = kong.request.get_forwarded_path()
    local prefix = kong.request.get_forwarded_prefix()

    if prefix and endpoint:sub(1, #prefix) == prefix then
        endpoint = endpoint:sub(#prefix + 1)
    end

    for _, rule in ipairs(self.rules) do
        if rule:match(host, endpoint, port, proto, prefix) then
            return rule
        end
    end

    return nil
end

-- Load configuration
local function load_config()
    kong.log.debug("PangeaPlugin: load_config")
    local config_file = os.getenv("PANGEA_KONG_CONFIG_FILE") or "/etc/pangea_kong_config.json"
    local file = io.open(config_file, "r")

    kong.log.debug("PangeaPlugin: load_config. ", "config_file: ", config_file)
    if file then
        local content = file:read("*all")
        file:close()
        local config = cjson.decode(content)
        kong.log.debug("PangeaPlugin: load_config. ", "config: ", cjson.encode(config))
        return PangeaKongConfig.new(config)
    end

    -- Default config
    local default_config = {
        pangea_domain = DEFAULT_PANGEA_DOMAIN,
        rules = {
            {
                host = "localhost",
                endpoint = "/v1/chat/completions",
                allow_on_error = false,
                protocols = {https = true},
                ports = {["443"] = true},
                audit_values = {
                    model = "openai"
                },
                ai_guard = {
                    request = {
                        parameters = {
                            recipe = "pangea_prompt_guard"
                        }
                    },
                    response = {}
                }
            }
        }
    }
    return PangeaKongConfig.new(default_config)
end

-- Plugin class
local PangeaAIGuardHandler = {
    PRIORITY = 1000,
    VERSION = "0.0.1",
}

-- PangeaAIGuardHandler.__index = PangeaAIGuardHandler

function PangeaAIGuardHandler:init()
    kong.log.debug("PangeaPlugin: PangeaAIGuardHandler.init")
    -- local self = setmetatable({}, Plugin)
    self.token = os.getenv("PANGEA_AI_GUARD_TOKEN")
    if self.token == nil or self.token == "" then
        error("PangeaAIGuardHandler.init ERROR: PANGEA_AI_GUARD_TOKEN environment variables is required")
    end
    self.config = load_config()
end

function PangeaAIGuardHandler:init_worker()
  PangeaAIGuardHandler:init()
end

function PangeaAIGuardHandler:access()
    local allow_failure = false
    kong.log.debug("PangeaPlugin: PangeaAIGuardHandler:access (start)")

    local rule = self.config:match_rule()
    if not rule then
        kong.log.info("PangeaPlugin: No rule matched ", kong.request.get_host(), kong.request.get_path(), ", allowing")
        return
    end

    allow_failure = rule.allow_failure
    local op = rule:operation_params("request")

    if not op then
        kong.log.info("PangeaPlugin: No work for 'request', allowing")
        return
    end

    -- Get recipe from header or config
    local recipe = kong.request.get_header("x-pangea-aig-recipe")
    if recipe and recipe[1] then
        op.recipe = recipe[1]
    end

    -- Get request body
    local body = kong.request.get_raw_body()
    if not body then
        kong.log.err("Failed to get request body")
        if not allow_failure then
            return kong.response.error(400, "Failed to get request body")
        end
        return
    end

    -- Prepare log fields
    local log_fields = {
        model = string.format('{"provider": "%s"}', rule.parser or ""),
        extra_info = string.format('{"api": "%s"}', kong.request.get_forwarded_path())
    }
    op.log_fields = log_fields

    -- Process request
    local success, payload = pcall(cjson.decode, body)
    if not success then
        kong.log.info("PangeaPlugin: JSON parse failed: ", payload)
        payload = body
    end

    kong.log.debug("PangeaPlugin: PangeaAIGuardHandler:access. ", "payload: ", cjson.encode(payload))

    -- Handle translation if needed
    local translator_instance
    if rule.parser then
        translator_instance = translator.get_translator(payload, rule.parser)
      if translator_instance then
        local model, model_version = translator_instance:get_model_and_version()
        model_version = model_version or "null"
        log_fields.model = string.format('{"provider": "%s", "model": "%s", "version": %s}',
            rule.parser, model, model_version)
        payload = translator_instance:get_pangea_messages()
      else
        kong.log.err("PangeaPlugin: PangeaAIGuardHandler:access. ", "translator_instance not found for ", rule.parser)
      end
    end

    -- Make request to Pangea AI Guard
    local body = {
      messages = payload,
      recipe = op.recipe,
      log_fields = op.log_fields
    }
    local url = "https://ai-guard." .. self.config.domain .. "/v1/text/guard"
    kong.log.debug("PangeaPlugin: PangeaAIGuardHandler:access", "Making request to ", url, ". body: ", cjson.encode(body))

    local httpc = http.new()
    local res, err = httpc:request_uri(url, {
        method = "POST",
        body = cjson.encode(body),
        headers = {
            ["Authorization"] = "Bearer " .. self.token,
            ["Content-Type"] = "application/json"
        }
    })

    if not res then
        kong.log.err("Failed to call AI Guard: ", err)
        if not allow_failure then
            return kong.response.error(400, "Failed to call AI Guard")
        end
        return
    end

    if res.status ~= 200 then
        kong.log.err("AI Guard returned error: ", res.status, " ", res.body)
        if not allow_failure then
            return kong.response.error(400, "AI Guard service error")
        end
        return
    end

    local response = cjson.decode(res.body)
    kong.log.debug("PangeaPlugin: PangeaAIGuardHandler:access", "AI Guard response: ", cjson.encode(response))

    local new_prompt = response.result.prompt_text or response.result.prompt_messages
    kong.log.debug("PangeaPlugin: PangeaAIGuardHandler:access", "new_prompt: ", cjson.encode(new_prompt))

    if response.result.blocked then
        for name, result in pairs(response.result.detectors) do
            if result.detected then
                kong.log.warn("Detected unwanted prompt characteristics: ", name, " ", cjson.encode(response))
                return kong.response.error(400, "Prompt has been rejected: " .. response.summary)
            end
        end
    else
        kong.log.debug("PangeaPlugin: Prompt allowed")
        if new_prompt then
            if rule.parser and translator_instance then
                new_prompt = translator_instance:transformed_original_input(new_prompt)
            end
            kong.service.request.set_raw_body(cjson.encode(new_prompt))
        end
    end
end

return PangeaAIGuardHandler
