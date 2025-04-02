-- FieldMapping represents a mapping between Pangea and input fields
local FieldMapping = {
    PangeaPath = "",  -- Path in Pangea response
    InputPath = "",   -- Path in original input
}

-- PangeaAiInput represents the input structure for Pangea AI
local PangeaAiInput = {
    messages = {},    -- Array of messages
    model = "",       -- Model name
    version = "",     -- Model version
}

-- Constants for roles
local PangeaRoles = {
  PromptRoleSystem = "system",
  PromptRoleUser = "user",
  PromptRoleLlm = "assistant"
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

return {
    FieldMapping = FieldMapping,
    PangeaAiInput = PangeaAiInput,
    PangeaRoles = PangeaRoles
}
