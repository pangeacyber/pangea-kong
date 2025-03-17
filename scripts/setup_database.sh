#!/bin/bash

docker kill kong-plugin-container
docker container rm kong-plugin-container

docker run -d -it --network=kong-net -p 8010:8000 -p 8011:8001 -p 8012:8002 \
-e KONG_ADMIN_LISTEN=0.0.0.0:8001 \
-e KONG_DATABASE=postgres \
-e KONG_PG_HOST=kong-postgres \
-e KONG_PG_USER=kong \
-e KONG_PG_PASSWORD=kongpass \
--name kong-plugin-container \
kong_plugin kong migrations bootstrap