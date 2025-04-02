local PLUGIN_NAME = "pangea-ai-guard"

local schema = {
  name = PLUGIN_NAME,
  fields = {
    { config = {
        type = "record",
        fields = {
        },
      },
    },
  },
}

return schema
