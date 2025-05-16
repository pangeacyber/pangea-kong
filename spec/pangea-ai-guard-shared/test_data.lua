return {
	-- Each test case is described like in annotated example below,
	-- and is designed to the pangea-translate module
	-- Note that many of the upstream request / response formats are identical
	-- to OpenAI -- we don't have a separate test case for them in that scenario
	{
		-- Name of the provider (Optional, will use the 'name' if not provided)
		provider = "openai",

		-- Name of the API to test
		api = "/v1/chat/completions",

		-- Request or response
		type = "request",

		-- (Parsed) JSON input, like what would be passed to the original API
		-- Adding some random fields that aren't used as a sanity check here to make sure they are preserved as well,
		-- but for other tests doesn't need to be the full thing, only the subset used to extract 'messages' from
		body = {
			model = "gpt-4",
			temperature = 0.8,
			top_p = 1,
			messages = {
				{
					role = "system",
					content = "System Message 1",
				},
				{
					role = "user",
					content = {
						{ type = "text", text = "User Message 1" },
						{ type = "text", text = "User Message 2" },
					},
				},
				{
					role = "assistant",
					content = "Assistant Message 1",
				},
			},
		},

		-- The input after the transformed messages are added
		-- Verify that we correctly map message transformations
		-- You can customize how messages are transformed, but by default `Transformed ` is added
		-- to the start of each message
		transformed_body = {
			model = "gpt-4",
			temperature = 0.8,
			top_p = 1,
			messages = {
				{ role = "system", content = "Transformed System Message 1" },
				{
					role = "user",
					content = {
						{ type = "text", text = "Transformed User Message 1" },
						{ type = "text", text = "Transformed User Message 2" },
					},
				},
				{ role = "assistant", content = "Transformed Assistant Message 1" },
			},
		},
	},
	{
		provider = "openai",
		api = "/v1/chat/completions",
		type = "response",
		body = {
			id = "chatcmpl-BUhm9e8b1WyYSOdGloNhg7zYLpYEk",
			object = "chat.completion",
			choices = {
				{
					index = 0,
					finish_reason = "stop",
					lobprobs = nil,
					message = {
						role = "assistant",
						content = "Assistant Message 1",
						refusal = nil,
						annotations = {},
					},
				},
				{
					index = 0,
					finish_reason = "stop",
					lobprobs = nil,
					message = {
						role = "assistant",
						content = "Assistant Message 2",
						refusal = nil,
						annotations = {},
					},
				},
			},
		},
		transformed_body = {
			id = "chatcmpl-BUhm9e8b1WyYSOdGloNhg7zYLpYEk",
			object = "chat.completion",
			choices = {
				{
					index = 0,
					finish_reason = "stop",
					lobprobs = nil,
					message = {
						role = "assistant",
						content = "Transformed Assistant Message 1",
						refusal = nil,
						annotations = {},
					},
				},
				{
					index = 0,
					finish_reason = "stop",
					lobprobs = nil,
					message = {
						role = "assistant",
						content = "Transformed Assistant Message 2",
						refusal = nil,
						annotations = {},
					},
				},
			},
		},
	},
	{
		provider = "openai",
		api = "/v1/completions",
		type = "request",
		body = {
			prompt = "User Message 1",
		},
		transformed_body = {
			prompt = "Transformed User Message 1",
		},
	},
	{
		provider = "openai",
		api = "/v1/completions",
		type = "response",
		body = {
			object = "text_completion",
			choices = {
				{
					index = 0,
					text = "Assistant Message 1",
				},
				{
					index = 1,
					text = "Assistant Message 2",
				},
			},
		},
		transformed_body = {
			object = "text_completion",
			choices = {
				{
					index = 0,
					text = "Transformed Assistant Message 1",
				},
				{
					index = 1,
					text = "Transformed Assistant Message 2",
				},
			},
		},
	},
	{
		provider = "anthropic",
		api = "/v1/messages",
		type = "request",
		body = {
			system = "System Message 1",
			messages = {
				{
					role = "user",
					content = "User Message 1",
				},
				{
					role = "assistant",
					content = "Assistant Message 1",
				},
			},
		},
		transformed_body = {
			system = "Transformed System Message 1",
			messages = {
				{
					role = "user",
					content = "Transformed User Message 1",
				},
				{
					role = "assistant",
					content = "Transformed Assistant Message 1",
				},
			},
		},
	},
	{
		provider = "cohere",
		api = "/v2/chat",
		type = "response",
		body = {
			message = {
				content = {
					{
						type = "text",
						role = "assistant",
						text = "Assistant Message 1",
					},
					{
						type = "text",
						role = "assistant",
						text = "Assistant Message 2",
					},
				},
			},
		},
		transformed_body = {
			message = {
				content = {
					{
						type = "text",
						role = "assistant",
						text = "Transformed Assistant Message 1",
					},
					{
						type = "text",
						role = "assistant",
						text = "Transformed Assistant Message 2",
					},
				},
			},
		},
	},
}
