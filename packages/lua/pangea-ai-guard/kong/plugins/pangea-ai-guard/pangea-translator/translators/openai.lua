local Translator = require "kong.plugins.pangea-ai-guard.pangea-translator.translators.base"
local PangeaRoles = require "kong.plugins.pangea-ai-guard.pangea-translator.translators.model"

local OpenAiTranslator = setmetatable({}, { __index = Translator })
OpenAiTranslator.__index = OpenAiTranslator

-- OpenAI schema definition
local OPENAI_SCHEMA = {
  ["$schema"] = "http://json-schema.org/draft-2020-12/schema",
  title = "OpenAi-styled prompt input",
  description = "Accepts either an object with 'messages' or a direct array of messages.",
  oneOf = {
    { ["$ref"] = "#/components/schemas/messages" },
    { ["$ref"] = "#/components/schemas/llm_input" }
  },
  components = {
    schemas = {
      messages = {
        title = "OpenAi-styled messages input",
        description = "The OpenAi-styled messages input",
        type = "array",
        items = {
          type = "object",
          required = { "role", "content" },
          properties = {
            role = {
              type = "string",
              enum = { "developer", "system", "user", "assistant", "function", "tool" }
            },
            content = {
              oneOf = {
                { type = "string" },
                {
                  type = "array",
                  items = {
                    type = "object",
                    required = { "type", "text" },
                    properties = {
                      type = { type = "string", enum = { "text" } },
                      text = { type = "string" }
                    }
                  }
                }
              }
            }
          }
        }
      },
      llm_input = {
        title = "OpenAi-styled full prompt input",
        description = "The OpenAi-styled full prompt input",
        type = "object",
        properties = {
          model = {
            type = "string",
            description = "The model to use for generating completions"
          },
          messages = {
            ["$ref"] = "#/components/schemas/messages"
          },
          temperature = {
            type = "number",
            description = "Controls randomness of the output",
            minimum = 0
          },
          top_p = {
            type = "number",
            description = "Alternative to temperature for nucleus sampling",
            minimum = 0,
            maximum = 1
          },
          max_tokens = {
            type = "integer",
            description = "Maximum number of tokens to generate",
            minimum = 1
          },
          frequency_penalty = {
            type = "number",
            description = "Penalizes repeated tokens",
            minimum = 0
          },
          presence_penalty = {
            type = "number",
            description = "Penalizes repeating topics",
            minimum = 0
          },
          stop = {
            description = "Up to 4 sequences where the API will stop generating",
            oneOf = {
              { type = "string" },
              { type = "array", items = { type = "string" } },
              { type = "null" }
            }
          }
        },
        required = { "messages", "model" },
        additionalProperties = true
      }
    }
  }
}

---@diagnostic disable-next-line: duplicate-set-field
function OpenAiTranslator.new(input)
  local self = setmetatable(Translator.new(input), OpenAiTranslator)
  return self
end

---@diagnostic disable-next-line: duplicate-set-field
function OpenAiTranslator.name()
  return "openai"
end

---@diagnostic disable-next-line: duplicate-set-field
function OpenAiTranslator.schema()
  return OPENAI_SCHEMA
end

---@diagnostic disable-next-line: duplicate-set-field
function OpenAiTranslator:get_model_and_version()
  if type(self._input) == "table" and self._input.model then
    return self._input.model, self._input.version
  end
  return self:name(), nil
end

---@diagnostic disable-next-line: duplicate-set-field
function OpenAiTranslator:get_pangea_messages()
  local messages = self._input.messages
  if type(self._input) ~= "table" then
    error("PangeaTranslator ERROR: Input must be a table")
  end

  if not self._input.messages then
    error("PangeaTranslator ERROR: Input must contain messages")
  end

  if type(self._input.messages) ~= "table" then
    error("PangeaTranslator ERROR: Messages must be an array")
  end

  local pangea_prompt = {}
  local prefix_path = "$"

  local msg_count = 1
  for idx, prompt in ipairs(messages) do
    local role = prompt.role
    if role == "developer" or role == "system" then
      role = PangeaRoles.PromptRoleSystem
    elseif role == "user" then
      role = PangeaRoles.PromptRoleUser
    elseif role == "assistant" then
      role = PangeaRoles.PromptRoleLlm
    end

    local content = prompt.content
    if type(content) == "string" then
      table.insert(pangea_prompt, {
        role = role,
        content = content
      })
      -- Add mapping for this message
      table.insert(self._mappings, {
        InputPath = string.format("%s[%d].content", prefix_path, idx),
        PangeaPath = self:_get_target_json_path(msg_count)
      })
      msg_count = msg_count + 1
    elseif type(content) == "table" then
      for idx2, part in ipairs(content) do
        if part.type == "text" then
          table.insert(pangea_prompt, {
            role = role,
            content = part.text
          })
          -- Add mapping for this message part
          table.insert(self._mappings, {
            InputPath = string.format("%s[%d].content[%d].text", prefix_path, idx, idx2),
            PangeaPath = self:_get_target_json_path(msg_count)
          })
          msg_count = msg_count + 1
        end
      end
    end
  end

  return pangea_prompt
end

return OpenAiTranslator
