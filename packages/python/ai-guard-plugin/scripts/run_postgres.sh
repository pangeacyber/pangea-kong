docker run -d --name kong-postgres \
  --network=kong-net \
  -p 5432:5432 \
  -e POSTGRES_USER=kong \
  -e POSTGRES_PASSWORD=kongpass \
  -e POSTGRES_DB=kong \
  postgres:latest