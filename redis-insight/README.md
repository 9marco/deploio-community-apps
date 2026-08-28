The Redis Insight version can be set with the `REDIS_INSIGHT_VERSION` build argument.

## Configuration

`entrypoint.sh` maps `NINE_KVS_<NAME>_*` [service variables](https://docs.nine.ch/docs/deplo-io/configuration/deploio-connecting-to-services) into `RI_REDIS_*` environment variables for automatic database configuration.

TLS is enabled for all connections. When a CA certificate is provided, it is written to `/tmp/deploio-ca/` and passed as `RI_REDIS_TLS_CA_PATH_<NAME>`.

> [!NOTE]
> Redis Insight loads pre-configured databases only after the terms of service are accepted. Set `RI_ACCEPT_TERMS_AND_CONDITIONS=true` to automatically accept the terms and make databases immediately available.

## Building and Running Locally

```shell
docker build --tag on-demand-redis-insight .
```

Run with simulated Deploio environment variables:

```shell
docker run --rm --publish 8080:8080 \
  --env NINE_KVS_CACHE_FQDN=kvs.example.com \
  --env NINE_KVS_CACHE_PORT=6379 \
  --env NINE_KVS_CACHE_USER=default \
  --env NINE_KVS_CACHE_PASSWORD=secret \
  --env NINE_KVS_CACHE_CA_CERT="$(cat ca.pem)" \
  --env RI_ACCEPT_TERMS_AND_CONDITIONS=true \
  on-demand-redis-insight
```

The service name (`CACHE` above) becomes the database alias in the UI (prefixed with `DEPLOIO_PROJECT_NAME` if set).
