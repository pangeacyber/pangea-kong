local typedefs = require("kong.db.schema.typedefs")
local Schema = require("kong.db.schema")

local translate = require("kong.plugins.pangea-ai-guard-shared.pangea-translator")

local secret = Schema.define {
	type = "string",
	referenceable = false,
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
						ai_guard_api_url = {
							type = "string",
							required = false,
							default = "https://ai-guard.aws.us.pangea.cloud/v1/text/guard",
							description = "AI Guard API URL",
						},
					},
					{
						ai_guard_api_key = secret {
							required = true,
							description = "Pangea AI Guard API Key",
						},
					},
					-- {
					-- 	ai_guard_vault_api_reference = {
					-- 		required = false,
					-- 		type = "record",
					-- 		description = "A Pangea Vault Key which contains the AI Guard API Token",
					-- 		fields = {
					-- 			{
					-- 				vault_id = {
					-- 					type = "string",
					-- 					required = true,
					-- 					description = "A Pangea Vault ID containing the AI Guard API Key",
					-- 				},
					-- 			},
					-- 			{
					-- 				vault_api_key = secret {
					-- 					required = true,
					-- 					description = "Pangea vault API Token",
					-- 				},
					-- 			},
					-- 		},
					-- 	},
					-- },
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
								if api_uri_transformers ~= nil then
									return true
								end

								local allowed_values = {}
								local idx = 0
								for k, _ in pairs(instance) do
									idx = idx + 1
									allowed_values[idx] = k
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
