local OpenAiTranslator = require "kong.plugins.pangea-ai-guard.pangea-translator.translators.openai"

local AzureTranslator = setmetatable({}, { __index = OpenAiTranslator })
AzureTranslator.__index = AzureTranslator

---@diagnostic disable-next-line: duplicate-set-field
function AzureTranslator.new(input)
  local self = setmetatable(OpenAiTranslator.new(input), AzureTranslator)
  return self
end

---@diagnostic disable-next-line: duplicate-set-field
function AzureTranslator:name()
  return "azureai"
end

return AzureTranslator