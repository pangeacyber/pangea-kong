
<a href="https://pangea.cloud?utm_source=github&utm_medium=gw-network" target="_blank" rel="noopener noreferrer">
  <img src="https://pangea-marketing.s3.us-west-2.amazonaws.com/pangea-color.svg" alt="Pangea Logo" height="40" />
</a>

[![documentation](https://img.shields.io/badge/documentation-pangea-blue?style=for-the-badge&labelColor=551B76)](https://pangea.cloud/docs/)


# Pangea Kong Plugin

The Pangea Kong Plugin is a powerful tool that enhances the functionality of the Kong API Gateway. It provides additional features and capabilities to help you manage and secure your APIs effectively. Pangea Kong Plugin main feature is to pre-process AI request using our [Pangea AI Guard](https://pangea.cloud/services/ai-guard/) service in order to eliminate PII, sensitive data, and malicious content from ingestion pipelines, LLM prompts and responses.


## Getting Started

To get started with the Pangea Kong Plugin, follow these steps:

### Prerequisites

1. Make sure you have the following prerequisites installed on your machine:

- [Docker](https://docs.docker.com/engine/install/)
- [Docker Compose](https://docs.docker.com/compose/install/)
- Curl

2. Get a Pangea token and its domain on the Pangea User Console. Token should [have access to][configure-a-pangea-service] the AI Guard service.


### Build

In order to build Pangea Kong Plugin image run:

```bash
docker build --no-cache . --tag kong_ai_guard_lua
```

### Setup

In order to run `kong_ai_guard_lua` image we should do some settings into `compose.yaml` file:

```yaml
services:
  kong-ai-guard:
    container_name: kong-ai-guard-container
    image: kong_ai_guard_lua
    volumes:
      - ./config/pangea_kong_config.json:/etc/pangea_kong_config.json
      - ./config/kong.yaml:/etc/kong/kong.yaml
    ports:
      - "8010:8000"
      - "8011:8001"
      - "8012:8002"
    environment:
      KONG_ADMIN_LISTEN: "0.0.0.0:8001"
      PANGEA_AI_GUARD_TOKEN: ${PANGEA_AI_GUARD_TOKEN}
      PANGEA_KONG_CONFIG_FILE: /etc/pangea_kong_config.json

      # Disable database and use declarative config
      KONG_DATABASE: "off"
      KONG_DECLARATIVE_CONFIG: /etc/kong/kong.yaml

      KONG_LOG_LEVEL: debug
```

#### Environment Variables

Environment variables should be set on section:

```yaml
services:
    pangea-kong-plugin:
        environment:
```

1. Pangea AI Guard Token: It is needed to make requests to Pangea AI Guard service. In order to load it on the plugin it's save directly in a environment variable called `PANGEA_AI_GUARD_TOKEN`. Do not write the token value directly into the`compose.yaml` file but load it from another environment variable in the local computer, also called `PANGEA_AI_GUARD_TOKEN`.
2. Set `PANGEA_KONG_CONFIG_FILE` to Pangea Kong Config file location. This file should be mounted in the `volumes` section of the `compose.yaml` file. In above example it is set to `/etc/pangea_kong_config.json` due to in `volumes` sections we have:
    ```yaml
        volumes:
            - ./config/pangea_kong_config.json:/etc/pangea_kong_config.json
    ```
    This means that `./config/pangea_kong_config.json` in our local machine is mounted into `/etc/pangea_kong_config.json` on the Pangea Plugin docker. The Pangea Kong Plugin configuration file will be documented in a later section.
3. Set `KONG_DATABASE` to "off" in order to run Kong without needed a database. More information [here](https://docs.konghq.com/gateway/latest/production/deployment-topologies/db-less-and-declarative-config/)
4. Set `KONG_DECLARATIVE_CONFIG` to `/etc/kong/kong.yaml`. This file is maped in the `volumes` section of the `compose.yaml` to a local file in `config/kong.yaml`. This config file will be explained later in this document.


#### Volumes

To allow docker to access a local file we should declare it on `volumes` section into the `compose.yaml` file.
```yaml
    volumes:
      - <origin>:<destination>
```
It is possible to map this origin from whatever location in our local machine to whatever destination into the docker but it is important to take care about location permissions. Also the `destination` path should be saved into the environment variable `PANGEA_KONG_CONFIG_FILE` so the plugin could load it.
In above example relative path `./config` make reference to the root directory where `compose.yaml` file is.


### Pangea Plugin Config File

```jsonc
{
  "pangea_domain": "aws.us.pangea.cloud",   // Pangea Domain got from Pangea Console
  "insecure": true,                         // Set to true to use http conections
  "rules": [
    {
      "host": "localhost",                  // Host that send the request to Kong AI gateway
      "endpoint": "/v1/chat/completions",   // Kong AI gateway endpoint used to send the request
      "prefix": "/dev",                     // Kong AI gateway endpoint prefix. It will be removed from the endpoint
      "protocols": ["http"],                // List of string with protocols allowed
      "ports": ["8000"],                    // List of string with ports allowed
      "allow_on_error": false,              // Whether or not request will reach the LLM in case AI Guard request fails
      "parser": "openai",                   // Parser name used to translate the LLM request to Pangea AI guard format. i.e.: 'openai'
      "ai_guard": {
        "request": {                        // Pangea AI Guard default parameters
          "parameters": {
            "recipe": "pangea_kong"         // Pangea AI Guard recipe
          }
        }
      }
    },
  ]
}
```

#### Parser name

Valid parser names are:

- openai
- claude
- azureai
- cohere


### Kong Config

Kong is running in database less mode and it load its configuration from a yaml file. In order to do it, the `KONG_DECLARATIVE_CONFIG` environment variable point to the file containing the settings (`KONG_DECLARATIVE_CONFIG: /etc/kong/kong.yaml`).

Here there is an explanation of each field that need to be set to setup Kong and Pangea AI Guard plugin.

```yaml
services:
- name: service_openai      # Declare a new service to handle OpenAI calls
  host: api.openai.com      # Set the OpenAI host
  port: 443                 # Set OpenAI port
  protocol: https           # Set OpenAI protocol
  routes:                   # Declare the Kong routes that will be re directed to OpenAI
    - name: openairoutes
      paths:                # All the routes under this prefixes will be redirected
          - /chatgpt/user
          - /chatgpt/dev

plugins:                    # Plugins to be enabled in this Kong instance
  - name: pangea-ai-guard   # Enable pangea-ai-guard plugin for all services
```


### Run

After building and setting up all previous stuff, it is ready to be run. It could be done with next command:
```bash
docker-compose up -d
```

### Test

To check it is running properly, run this next request:

```bash
curl -H "Accept: application/json" http://localhost:8010
```

and should return something like:

```json
{
  "message":"no Route matched with those values",
  "request_id":<request-id>
}
```


## Usage

In these examples is needed an Open AI Key. It was saved in an environment variable called `OPENAI_API_KEY`.

### Valid request

Request:
```bash
curl "http://localhost:8010/chatgpt/user/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "x-pangea-aig-recipe: kong_recipe" \
  -d '{
  "model": "gpt-3.5-turbo",
  "messages": [
    {"role": "system", "content": "you are a helpful assistant"},
    {"role": "user", "content": "Please echo back the following string <190.28.74.251>"}
  ]
}'
```

Response:
```json
{
  "id": "chatcmpl-BAdcAtVX2MKk4MkDg4GNnhMBrHl7h",
  "object": "chat.completion",
  "created": 1741875258,
  "model": "gpt-3.5-turbo-0125",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "<190.28.74.251>",
        "refusal": null,
        "annotations": []
      },
      "logprobs": null,
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 31,
    "completion_tokens": 10,
    "total_tokens": 41,
    "prompt_tokens_details": {
      "cached_tokens": 0,
      "audio_tokens": 0
    },
    "completion_tokens_details": {
      "reasoning_tokens": 0,
      "audio_tokens": 0,
      "accepted_prediction_tokens": 0,
      "rejected_prediction_tokens": 0
    }
  },
  "service_tier": "default",
  "system_fingerprint": null
}
```

#### Endpoint

Request was sent to endpoint `/chatgpt/user/v1/chat/completions`. Based on the Pangea Kong config file used, it had next rule:

```json
    {
      "host": "localhost",
      "endpoint": "/v1/chat/completions",
      "prefix": "/chatgpt/user",
      "allow_on_error": false,
      "parser": "openai",
      "ai_guard": {
        "request": {
          "parameters": {
            "recipe": "pangea_prompt_guard"
          }
        }
      }
    }
```

So in this case request matched the host, prefix and endpoint.
Then based on the Kong Config that it was set on `config/kong.yaml`:

```yaml
services:
- name: service_openai
  host: api.openai.com
  port: 443
  protocol: https
  routes:
    - name: openairoutes
      paths:
          - /chatgpt/user
          - /chatgpt/dev
```

It declare that path matching `/chatgpt/user` will be redirected to `"host":"api.openai.com"`, that is how, request was pre-processed by AI Guard and then forwarded to OpenAI with the payload modified.


### Rejected request

In this next example request send `x-pangea-aig-recipe` header with value `kong_recipe_invalid`. This will override Pangea AI Guard recipe and, as it is an invalid value, it will be rejected by AI Guard service. Also, as Pangea Plugin Config have set `allow_on_error` to `false`, it return an error.

```bash
curl "http://localhost:8010/chatgpt/user/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "x-pangea-aig-recipe: kong_recipe_invalid" \
  -d '{
  "model": "gpt-3.5-turbo",
  "messages": [
    {"role": "system", "content": "you are a helpful assistant"},
    {"role": "user", "content": "Please echo back the following string <190.28.74.251>"}
  ]
}'
```

Response:
```html
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <title>Error</title>
  </head>
  <body>
    <h1>Error</h1>
    <p>Prompt has been rejected.</p>
    <p>request_id: 9f893224b9b3994a6911881b6810725b</p>
  </body>
</html>
```


## Contributing

We welcome contributions from the community to improve and expand the capabilities of the Pangea Kong Plugin. If you would like to contribute, please follow the guidelines outlined in the CONTRIBUTING.md file.

## License

The Pangea Kong Plugin is released under the [MIT License](https://opensource.org/licenses/MIT). Feel free to use, modify, and distribute it according to the terms of the license.


[configure-a-pangea-service]: https://pangea.cloud/docs/getting-started/configure-services/#configure-a-pangea-service
