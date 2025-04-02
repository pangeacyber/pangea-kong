local cjson = require "cjson"
local OpenAiTranslator = require "kong.plugins.pangea-ai-guard.pangea-translator.translators.openai"
local PlainTextTranslator = require "kong.plugins.pangea-ai-guard.pangea-translator.translators.plaintext"

local function get_translator_str_input(input)
    return PlainTextTranslator.new(input)
end

local function split_llm_hint(llm_hint)
    if not llm_hint then
        return nil, nil
    end

    local provider, model = llm_hint:match("^([^:]+):?(.*)$")
    return provider, model
end

local function validate_schema(input, schema)
    -- TODO: Implement JSON Schema validation
    -- For now, we'll just do basic type checking
    if not input or type(input) ~= "table" then
        return false, "Input must be a table"
    end

    if schema.required then
        for _, field in ipairs(schema.required) do
            if not input[field] then
                return false, string.format("Missing required field: %s", field)
            end
        end
    end

    return true
end

local function get_translator_with_hint(input, llm_hint)
    local provider = split_llm_hint(llm_hint)

    if not provider then
        return nil
    end

    if provider == "plaintext" and type(input) == "string" then
        return get_translator_str_input(input)
    elseif provider == "openai" then
        local success, err = validate_schema(input, OpenAiTranslator.schema())
        if success then
            return OpenAiTranslator.new(input)
        end
        kong.log.warn("Not " .. llm_hint .. ": " .. err)
        return nil
    end

    kong.log.warn(llm_hint .. " not supported")
    return nil
end

local function get_translator(input, llm_hint)
    if llm_hint and llm_hint ~= "" then
        return get_translator_with_hint(input, llm_hint)
    end

    if type(input) == "string" then
        return get_translator_str_input(input)
    end

    -- Try OpenAI format
    local success, err = validate_schema(input, OpenAiTranslator.schema())
    if success then
        return OpenAiTranslator.new(input)
    end

    -- Default to plain text
    return get_translator_str_input(cjson.encode(input))
end

return {
    get_translator = get_translator,
    get_translator_with_hint = get_translator_with_hint,
    split_llm_hint = split_llm_hint
}
