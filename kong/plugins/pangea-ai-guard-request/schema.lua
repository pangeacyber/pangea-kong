local typedefs = require("kong.db.schema.typedefs")
local Schema = require("kong.db.schema")

local translate = require("kong.plugins.pangea-ai-guard-shared.pangea-translator")

local secret = Schema.define {
	type = "string",
	referenceable = true,
	encrypted = true,
}

local PLUGIN_NAME = "pangea-ai-guard-request"

local schema = {
	name = PLUGIN_NAME,
	fields = {
		{
			protocols = typedefs.protocols_http,
		},
		{
			config = {
				type = "record",
				fields = {
					{
						ai_guard_api_base_url = {
							type = "string",
							required = false,
							default = "https://ai-guard.aws.us.pangea.cloud/v1beta/guard",
							description = "AI Guard API URL",
						},
					},
					{
						ai_guard_api_key = secret {
							required = true,
							description = "Pangea AI Guard API Key",
						},
					},
					{
						upstream_llm = {
							type = "record",
							required = true,
							fields = {
								{
									provider = {
										type = "string",
										required = true,
										description = "Provider name used to translate the LLM request to Pangea AI Guard format, e.g. 'openapi'",
										one_of = translate.list_available_translators(),
									},
								},
								{
									api_uri = {
										type = "string",
										required = true,
										description = "API URI for the route this plugin is applied to",
									},
								},
							},
							custom_validator = function(value)
								local instance, err = translate.get_translator(value.provider)
								if err ~= nil then
									return nil, err
								end

								local api_uri_transformers = instance[value.api_uri]
								if api_uri_transformers ~= nil and value.api_uri ~= "capabilities" then
									return true
								end

								local allowed_values = {}
								local idx = 0
								for k, _ in pairs(instance) do
									if k ~= "capabilities" then
										idx = idx + 1
										allowed_values[idx] = k
									end
								end

								return nil,
									string.format(
										"For provider '%s' allowed api_uris are '%s'",
										value.provider,
										table.concat(allowed_values, ", ")
									)
							end,
						},
					},
					{
						recipe = {
							type = "string",
							required = false,
							description = "AI Guard Recipe Name",
							default = ngx.null,
						},
					},
				},
			},
		},
	},
}

return schema
