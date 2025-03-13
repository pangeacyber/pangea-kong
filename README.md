
<a href="https://pangea.cloud?utm_source=github&utm_medium=gw-network" target="_blank" rel="noopener noreferrer">
  <img src="https://pangea-marketing.s3.us-west-2.amazonaws.com/pangea-color.svg" alt="Pangea Logo" height="40" />
</a>

[![documentation](https://img.shields.io/badge/documentation-pangea-blue?style=for-the-badge&labelColor=551B76)](https://pangea.cloud/docs/)
[![Discourse](https://img.shields.io/badge/Discourse-4A154B?style=for-the-badge&logo=discourse&logoColor=white)][Discourse]

[Discourse]: https://community.pangea.cloud

This repository provides integrations for network-related functionalities within the Pangea ecosystem, specifically for Kong API Gateway and LiteLLM services.

## Prerequisites

- Docker installed on your machine
- A PostgreSQL database for Kong (if using with a database)
- An AI backend to interact with LiteLLM or Kong AI Gateway

## Kong API Gateway Integration

### Repository

[GitHub - pangeacyber/pangea-kong](https://github.com/pangeacyber/pangea-kong)

### Build
```sh
docker build --no-cache . --tag kong_plugin
```

### Run
```sh
docker run --network=kong-net -d -it -p 8010:8000 -p 8011:8001 -p 8012:8002 \
  -e "KONG_DATABASE=postgres" \
  -e "KONG_PG_HOST=kong-database" \
  -e "KONG_PG_USER=kong"  \
  -e "KONG_PG_PASSWORD=kongpass" \
  -e "KONG_ADMIN_LISTEN=0.0.0.0:8001" \
  kong_plugin
```

**Note:** To run without a database, remove the DB environment variables and set the DB to `off` in the Dockerfile.

### Launch Kong PostgreSQL Image
```sh
docker run --rm --network=kong-net \
 -e "KONG_DATABASE=postgres" \
 -e "KONG_PG_HOST=kong-database" \
 -e "KONG_PG_PASSWORD=kongpass" \
kong/kong-gateway:3.9.0.1 kong migrations bootstrap
```

For more information:
- [Set up data store - Kong Gateway v3.9.x](https://docs.konghq.com/gateway/latest/kong-enterprise/datastore/)
- [Install Kong Gateway on Docker - v3.9.x](https://docs.konghq.com/gateway/latest/install/docker/)

### Useful Tests

```sh
curl http://localhost:8010/chatgpt/dev/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [
      { "role": "system", "content": "You are a helpful assistant." },
      { "role": "user", "content": "Please echo back the following string '10.10.10.100'?" }
    ]
  }'
```

## LiteLLM Integration

### Repository

[GitHub - pangeacyber/pangea-litellm](https://github.com/pangeacyber/pangea-litellm)

### Build
```sh
docker build --no-cache . --tag litellm_plugin
```

### Run
```sh
docker run -d -it -p 4000:4000 -p 8011:8001 -p 8012:8002 litellm_plugin
```

### Useful Tests

```sh
curl -X POST 'http://0.0.0.0:4000/chat/completions' \
-H 'Content-Type: application/json' \
-H 'Authorization: Bearer $OPENAI_API_KEY' \
-d '{
    "model": "openai/gpt-3.5-turbo",
    "messages": [
      { "role": "system", "content": "You are a helpful assistant." },
      { "role": "user", "content": "Please echo back the following string '10.10.10.100'?" }
    ]
}'
```

```sh
curl -X POST 'http://0.0.0.0:4000/chat/completions' \
-H 'Content-Type: application/json' \
-H 'X-Pangea-AIG-Recipe: foo' \
-H 'Authorization: Bearer $OPENAI_API_KEY' \
-d '{
    "model": "openai/gpt-3.5-turbo",
    "messages": [
      { "role": "system", "content": "You are a helpful assistant." },
      { "role": "user", "content": "Please echo back the following string '190.28.74.251'?" }
    ]
}'
```

## Notes

For both LiteLLM and Kong AI GW, you need an AI backend to interact with. If you only want to test Kong API Gateway, you can set up a simple local web server that echoes requests to stdout.

For further documentation, visit the [Pangea Documentation](https://pangea.cloud/docs/).

