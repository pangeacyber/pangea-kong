-- FieldMapping represents a mapping between Pangea and input fields
local FieldMapping = {
	PangeaPath = "", -- Path in Pangea response
	InputPath = "", -- Path in original input
}

-- PangeaAiInput represents the input structure for Pangea AI
local PangeaAiInput = {
	messages = {}, -- Array of messages
	model = "", -- Model name
	version = "", -- Model version
}

-- Constants for roles
local PangeaRoles = {
	PromptRoleSystem = "system",
	PromptRoleUser = "user",
	PromptRoleLlm = "assistant",
}

-- Helper function to create a new FieldMapping
function FieldMapping.new(pangea_path, input_path)
	local self = setmetatable({}, { __index = FieldMapping })
	self.PangeaPath = pangea_path
	self.InputPath = input_path
	return self
end

-- Helper function to create a new PangeaAiInput
function PangeaAiInput.new(messages, model, version)
	local self = setmetatable({}, { __index = PangeaAiInput })
	self.messages = messages or {}
	self.model = model or ""
	self.version = version or ""
	return self
end

---@class JSONMessageMap
local JSONMessageMap = {
	messages = {},
	lookup = {},
}

---@alias PathElement string | integer

---@param content string
---@param role string
---@param path PathElement[]
function JSONMessageMap:add_message(content, role, path)
	-- TODO: Remove the "content" field -- we should be able to pass in the original table and the path instead
	-- Getting the content from the path instead seems a bit more robust to me
	table.insert(self.messages, {
		content = content,
		role = role,
	})
	table.insert(self.lookup, path)
end

-- TODO: I think this is a bit funky, but it's the most straight forward way I found to
-- keep my type-checker happy
function NewJSONMessageMap()
	local self = {
		messages = {},
		lookup = {},
	}
	setmetatable(self, { __index = JSONMessageMap })
	return self
end

return {
	FieldMapping = FieldMapping,
	PangeaAiInput = PangeaAiInput,
	PangeaRoles = PangeaRoles,
	NewJSONMessageMap = NewJSONMessageMap,
}
