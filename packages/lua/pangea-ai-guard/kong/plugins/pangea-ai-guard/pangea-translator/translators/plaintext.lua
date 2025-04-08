local base = require "kong.plugins.pangea-ai-guard.pangea-translator.translators.base"
local model = require "kong.plugins.pangea-ai-guard.pangea-translator.translators.model"

local PlainTextTranslator = setmetatable({}, { __index = base })
PlainTextTranslator.__index = PlainTextTranslator

VERSION = "0.0.1"

---@diagnostic disable-next-line: duplicate-set-field
function PlainTextTranslator.new(input)
    local self = setmetatable(base.new(input), PlainTextTranslator)
    self._is_text = true
    return self
end

---@diagnostic disable-next-line: duplicate-set-field
function PlainTextTranslator:name()
    return "plaintext"
end

---@diagnostic disable-next-line: duplicate-set-field
function PlainTextTranslator:schema()
    return {
        type = "object",
        properties = {
            text = { type = "string" }
        },
        required = { "text" }
    }
end

---@diagnostic disable-next-line: duplicate-set-field
function PlainTextTranslator:get_model_and_version()
    return self:name(), VERSION
end

---@diagnostic disable-next-line: duplicate-set-field
function PlainTextTranslator:get_pangea_messages()
    local text = self._input.text or self._input
    return model.PangeaAiInput.new({
        {
            role = "user",
            content = text
        }
    }, self:name(), VERSION)
end

return PlainTextTranslator
