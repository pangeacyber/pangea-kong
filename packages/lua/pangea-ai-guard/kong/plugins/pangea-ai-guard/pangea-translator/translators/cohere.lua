-- Copyright 2021 Pangea Cyber Corporation
-- Author: Pangea Cyber Corporation
local Translator = require "kong.plugins.pangea-ai-guard.pangea-translator.translators.base"
local Model = require "kong.plugins.pangea-ai-guard.pangea-translator.translators.model"

local CohereTranslator = setmetatable({}, { __index = Translator })
CohereTranslator.__index = CohereTranslator

-- Constants
local COHERE_SCHEMA = {
  ["$schema"] = "http://json-schema.org/draft-2020-12/schema",
  title = "Cohere prompt input",
  description = "Accepts either an object with 'messages' or a direct array of messages.",
  oneOf = {
    { ["$ref"] = "#/components/schemas/messages" },
    { ["$ref"] = "#/components/schemas/llm_input" },
  },
  components = {
    schemas = {
      messages = {
        title = "Messages",
        description = "Cohere styled prompt input messages",
        type = "array",
        items = {
          type = "object",
          required = { "role", "content" },
          properties = {
            role = {
              type = "string",
              enum = { "assistant", "user", "system", "tool" },
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
                      text = { type = "string" },
                    },
                  },
                },
              }
            },
          },
        },
      },
      llm_input = {
        type = "object",
        description = "Cohere styled full prompt input messages",
        properties = {
          messages = {
            ["$ref"] = "#/components/schemas/messages",
          },
          model = {
            type = "string",
            description = "Cohere model ",
          },
        },
        required = { "messages", "model" },
        additionalProperties = true,
      },
    }
  },
}

-- Constructor
---@diagnostic disable-next-line: duplicate-set-field
function CohereTranslator.new(input)
  local self = setmetatable({}, CohereTranslator)
  self._input = input
  self._mappings = {}
  return self
end

-- Get model name and version
---@diagnostic disable-next-line: duplicate-set-field
function CohereTranslator:get_model_and_version()
  if type(self._input) == "table" and self._input.model then
    return self._input.model, self._input.version
  else
    return self:name(), nil
  end
end

-- Get translator name
---@diagnostic disable-next-line: duplicate-set-field
function CohereTranslator.name()
  return "cohere"
end

-- Get schema
---@diagnostic disable-next-line: duplicate-set-field
function CohereTranslator.schema()
  return COHERE_SCHEMA
end

-- Get target JSON path
---@diagnostic disable-next-line: duplicate-set-field
function CohereTranslator:_get_target_json_path(idx, prefix, content_field)
  prefix = prefix or "$"
  content_field = content_field or "content"
  return string.format("%s[%d].%s", prefix, idx, content_field)
end

-- Get Pangea messages
---@diagnostic disable-next-line: duplicate-set-field
function CohereTranslator:get_pangea_messages()
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

    if role == "system" then
      role = Model.PangeaRoles.PromptRoleSystem
    elseif role == "user" then
      role = Model.PangeaRoles.PromptRoleUser
    elseif role == "assistant" then
      role = Model.PangeaRoles.PromptRoleLlm
    end

    local content = prompt.content

    if type(content) == "string" then
      table.insert(pangea_prompt, {
        role = role,
        content = content
      })
      table.insert(self._mappings, {
        InputPath = string.format("%s[%d].content", prefix_path, idx),
        PangeaPath = self:_get_target_json_path(msg_count)
      })
      msg_count = msg_count + 1
    else
      for idx2, part in ipairs(content) do
        if part.type == "text" then
          table.insert(pangea_prompt, {
            role = role,
            content = part.text
          })
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

return CohereTranslator
