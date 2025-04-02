local base = require "kong.plugins.pangea-ai-guard.pangea-translator.translators.base"
local model = require "kong.plugins.pangea-ai-guard.pangea-translator.model.model"

local PlainTextTranslator = setmetatable({}, { __index = base })
PlainTextTranslator.__index = PlainTextTranslator

VERSION = "0.0.1"

function PlainTextTranslator.new(input)
    local self = setmetatable(base.new(input), PlainTextTranslator)
    self._is_text = true
    return self
end

function PlainTextTranslator:name()
    return "plaintext"
end

function PlainTextTranslator:schema()
    return {
        type = "object",
        properties = {
            text = { type = "string" }
        },
        required = { "text" }
    }
end

function PlainTextTranslator:get_model_and_version()
    return self:name(), VERSION
end

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
