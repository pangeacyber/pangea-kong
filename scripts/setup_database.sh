#!/bin/bash
CONTAINER_NAME = "pangea-kong-container"

docker kill "$CONTAINER_NAME"
docker container rm "$CONTAINER_NAME"

docker run -d -it --network=kong-net -p 8010:8000 -p 8011:8001 -p 8012:8002 \
-e KONG_ADMIN_LISTEN=0.0.0.0:8001 \
-e KONG_DATABASE=postgres \
-e KONG_PG_HOST=kong-postgres \
-e KONG_PG_USER=kong \
-e KONG_PG_PASSWORD=kongpass \
--name "$CONTAINER_NAME" \
pangea_kong_plugin kong migrations bootstrap