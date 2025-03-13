#!/bin/bash

$CONTAINER_NAME = "pangea-kong-container"

docker kill $CONTAINER_NAME
docker container rm $CONTAINER_NAME

docker run -d -it --network=kong-net -p 8010:8000 -p 8011:8001 -p 8012:8002 \
-e KONG_ADMIN_LISTEN=0.0.0.0:8001 \
-e KONG_DATABASE=off \
-e KONG_DECLARATIVE_CONFIG_STRING='{"_format_version":"1.1", "services":[{"name":"test_service_openai","host":"api.openai.com","port":443,"protocol":"https", "routes":[{"name":"openairoutes","paths":["/chatgpt/user", "/chatgpt/dev"]}]}],"plugins":[{"name":"pangea_kong"}]}' \
--name $CONTAINER_NAME \
pangea_kong_plugin