local typedefs = require("kong.db.schema.typedefs")
local Schema = require("kong.db.schema")

local translate = require("kong.plugins.pangea-ai-guard.pangea-translator")
local openai = require("kong.plugins.pangea-ai-guard.pangea-translator.openai")

local secret = Schema.define {
	type = "string",
	referenceable = false,
	encrypted = true,
}

local guard_types = { "request", "response", "both" }

local PLUGIN_NAME = "pangea-ai-guard"

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
						guard_type = {
							type = "string",
							required = false,
							description = "Run AI Guard on LLM request or response",
							one_of = guard_types,
							default = "request",
						},
					},
					-- {
					-- 	parser = {
					-- 		type = "string",
					-- 		required = true,
					-- 		description = "Parser name used to translate the LLM request to Pangea AI Guard format, e.g. 'openapi'",
					-- 		one_of = translator.list_available_translators(),
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
						request_recipe = {
							type = "string",
							required = false,
							description = "Recipe to run AI Guard on input before reaching the LLM",
							default = ngx.null,
						},
					},
					{
						response_recipe = {
							type = "string",
							required = false,
							description = "Recipe to use when running AI Guard on the LLM response output",
							default = ngx.null,
						},
					},
				},
			},
		},
	},
	entity_checks = {
		{
			-- The 'conditional' entity checker causes weird problems where it
			-- seems like it mutates the schema, so we'll use this instead
			custom_entity_check = {
				field_sources = { "config.request_recipe", "config.guard_type" },
				fn = function(entity)
					local request_recipe = entity.config.request_recipe
					local guard_type = entity.config.guard_type
					if not request_recipe or request_recipe == ngx.null then
						return true
					end
					if not guard_type or guard_type == ngx.null then
						-- Not set, let the normal validator pick this up
						return true
					end

					if guard_type == "request" or guard_type == "both" then
						return true
					end

					return nil, "'request_recipe' should only be set if the 'guard_type' will use it"
				end,
			},
		},
		{
			custom_entity_check = {
				field_sources = { "config.response_recipe", "config.guard_type" },
				fn = function(entity)
					local response_recipe = entity.config.response_recipe
					local guard_type = entity.config.guard_type
					if not response_recipe or response_recipe == ngx.null then
						return true
					end
					if not guard_type or guard_type == ngx.null then
						-- Not set, let the normal validator pick this up
						return true
					end

					if guard_type == "response" or guard_type == "both" then
						return true
					end

					return nil, "'response_recipe' should only be set if the 'guard_type' will use it"
				end,
			},
		},
	},
	-- entity_checks = {
	-- 	{
	-- 		conditional = {
	-- 			if_field = "config.request_recipe",
	-- 			if_match = { ne = ngx.null },
	-- 			then_field = "config.guard_type",
	-- 			then_match = { one_of = { "request", "both" } },
	-- 			then_err = "'request_recipe' should only be set if the 'guard_type' will use it",
	-- 		},
	-- 	},
	-- 	{
	-- 		conditional = {
	-- 			if_field = "config.response_recipe",
	-- 			if_match = { ne = ngx.null },
	-- 			then_field = "config.guard_type",
	-- 			then_match = { one_of = { "response", "both" } },
	-- 			then_err = "'response_recipe' should only be set if the 'guard_type' will use it",
	-- 		},
	-- 	},
	-- },
}

return schema
