local Model = require("kong.plugins.pangea-ai-guard-shared.pangea-translator.model")

local function prepare_converse_request(request)
	if type(request) ~= "table" then
		return nil, "Invalid llm request"
	end

	local ret = Model.NewJSONMessageMap()

	for idx, system_content in ipairs(request.system) do
		local text = system_content.text
		if text ~= nil then
			ret:add_message(text, "system", { "system", idx, "text" })
		end
	end

	for idx, message in ipairs(request.messages) do
		local role = message.role
		for jdx, content in ipairs(message.content) do
			local text = content.text
			if text ~= nil then
				ret:add_message(text, role, { "messages", idx, "content", jdx, "text" })
			end
		end
	end

	return ret
end

local function prepare_converse_response(response)
	if type(response) ~= "table" then
		return nil, "Invalid response object"
	end

	local ret = Model.NewJSONMessageMap()

	for idx, message in ipairs(response.output) do
		local role = message.role
		for jdx, content in ipairs(message.content) do
			local text = content.text
			if text ~= nil then
				ret:add_message(text, role, { "output", idx, "content", jdx, "text" })
			end
		end
	end

	return ret
end

return {
	["converse"] = {
		["request"] = prepare_converse_request,
		["response"] = prepare_converse_response,
	},
}
