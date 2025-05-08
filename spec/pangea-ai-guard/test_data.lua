return {
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
		provider = "bedrock",
		api = "converse",
		type = "request",

		body = {
			system = {
				{ text = "System Message 1" },
				{ text = "System Message 2" },
			},
			messages = {
				{
					role = "user",
					content = {
						{ text = "User Message 1" },
						{ text = "User Message 2" },
					},
				},
				{
					role = "assistant",
					content = {
						{ text = "Assistant Message 1" },
					},
				},
			},
		},
		transformed_body = {
			system = {
				{ text = "Transformed System Message 1" },
				{ text = "Transformed System Message 2" },
			},
			messages = {
				{
					role = "user",
					content = {
						{ text = "Transformed User Message 1" },
						{ text = "Transformed User Message 2" },
					},
				},
				{
					role = "assistant",
					content = {
						{ text = "Transformed Assistant Message 1" },
					},
				},
			},
		},
	},
	{
		provider = "bedrock",
		api = "converse",
		type = "response",
		body = {
			output = {
				{
					role = "assistant",
					content = {
						{ text = "Assistant Message 1" },
						{ text = "Assistant Message 2" },
					},
				},
			},
		},
		transformed_body = {
			output = {
				{
					role = "assistant",
					content = {
						{ text = "Transformed Assistant Message 1" },
						{ text = "Transformed Assistant Message 2" },
					},
				},
			},
		},
	},
}
