local helpers = require("spec.helpers")
local http_mock = require("spec.helpers.http_mock")
local test_data = require("spec.pangea-ai-guard.test_data")

local translate = require("kong.plugins.pangea-ai-guard.pangea-translator")

local function default_transform_fn(message)
	return {
		role = message.role,
		content = "Transformed " .. message.content,
	}
end

local function transform_messages(messages, test_input)
	local transformed_messages = {}
	local transform_fn = test_input.transform_fn or default_transform_fn
	for _, message in ipairs(messages) do
		table.insert(transformed_messages, transform_fn(message))
	end

	return transformed_messages
end

for _, strategy in helpers.each_strategy() do
	describe("pangea-ai-guard [" .. strategy .. "]", function()
		describe("LLM transformation", function()
			assert:set_parameter("TableFormatLevel", -1)
			for _, test_input in ipairs(test_data) do
				local provider = test_input.provider
				local api_uri = test_input.api
				local type = test_input.type

				it(provider .. ":" .. api_uri .. " " .. type, function()
					local original_body = test_input.body
					local instance, err = translate.get_translator(provider)
					assert.falsy(err)

					local messages, err = instance[api_uri][type](original_body)
					assert.falsy(err)
					-- Pretend like we pass messages to AI Guard, get the response back,
					-- and extracted the messages
					local transformed_messages = transform_messages(messages.messages, test_input)

					local new_body, updated =
						translate.rewrite_llm_message(original_body, messages, transformed_messages)
					assert.is_true(updated)
					assert.are.same(test_input.transformed_body, new_body)
				end)
			end
		end)

		describe("openai integration", function()
			it("rewrite request", function() end)
			it("rewrite response", function() end)
			it("block request", function() end)
			it("block response", function() end)
		end)
	end)
end
