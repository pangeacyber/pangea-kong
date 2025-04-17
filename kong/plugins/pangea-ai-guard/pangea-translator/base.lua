local Translator = {}
Translator.__index = Translator

VERSION = "0.0.1"

function Translator.new(input)
	local self = setmetatable({}, Translator)
	self._input = input
	self._mappings = {}
	self._is_text = false
	return self
end

function Translator:name()
	return "base"
end

function Translator:schema()
	return {}
end

function Translator:get_model_and_version()
	return self:name(), VERSION
end

function Translator:get_pangea_messages()
	error("Method not implemented")
end

function Translator:_get_target_json_path(index)
	return string.format("$[%d].content", index)
end

function Translator:original_input()
	return self._input
end

-- Helper function to parse JSON path
local function parse_json_path(path)
	local parts = {}
	for part in path:gmatch("[^%.%[%]]+") do
		table.insert(parts, part)
	end
	return parts
end

-- Helper function to get value from table using path
local function get_value_from_path(obj, path_parts)
	local current = obj
	for _, part in ipairs(path_parts) do
		part = tonumber(part) or part
		if type(current) ~= "table" then
			return nil
		end
		current = current[part]
		if current == nil then
			return nil
		end
	end
	return current
end

function Translator:_transformed_original_input(messages)
	-- Check if messages is a table with a messages key
	local messages_array = type(messages) == "table" and messages.messages or messages
	if not messages_array then
		error("Invalid messages format")
	end

	for idx, fieldMap in ipairs(self._mappings) do
		-- Parse the PangeaPath
		local pangea_parts = parse_json_path(fieldMap.PangeaPath)
		-- Remove the $ prefix if present
		if pangea_parts[1] == "$" then
			table.remove(pangea_parts, 1)
		end

		-- Find the value in messages using the PangeaPath
		local value = get_value_from_path(messages_array, pangea_parts)

		if not value then
			error(string.format("Could not extract a single value from path=%s", fieldMap.PangeaPath))
		end

		-- Parse the InputPath
		local input_parts = parse_json_path(fieldMap.InputPath)
		-- Remove the $ prefix if present
		if input_parts[1] == "$" then
			table.remove(input_parts, 1)
		end

		-- Update the value in the input
		local current = self._input.messages
		for i = 1, #input_parts - 1 do
			local part = tonumber(input_parts[i]) or input_parts[i]
			if not current[part] then
				current[part] = {}
			end
			current = current[part]
		end
		local part = tonumber(input_parts[#input_parts]) or input_parts[#input_parts]
		current[part] = value
	end

	return self._input
end

function Translator:transformed_original_input(messages, text)
	if not messages and not text then
		return self._input
	end

	-- For text based translator
	if self._is_text then
		if text then
			return text
		end
		if messages and #messages > 0 and messages[1].content then
			return messages[1].content
		end
	end

	-- For non-text translators
	if #self._mappings == 0 then
		if messages then
			return self._input
		else
			return text
		end
	else
		if messages then
			return self:_transformed_original_input(messages)
		else
			return text
		end
	end
end

function Translator:is_text()
	return self._is_text
end

return Translator
