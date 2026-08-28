The pgAdmin version can be set with the `PGADMIN_VERSION` build argument.

## Configuration

On startup, `entrypoint.sh` runs `servers.py` to convert `NINE_PG_<NAME>_*` (PostgreSQL Business) and `NINE_PGDB_<NAME>_*` (PostgreSQL Economy) [service variables](https://docs.nine.ch/docs/deplo-io/configuration/deploio-connecting-to-services) into a pgAdmin `servers.json` configuration.

Passwords are written to `.pgpass` in the pgAdmin user's storage directory for automatic authentication. When a CA certificate is provided, it is saved to `/tmp/deploio-ca/` and configured with `sslmode=verify-ca`.

## Building and Running Locally

```shell
docker build --tag on-demand-pgadmin .
```

Run with simulated Deploio environment variables:

```shell
docker run --rm --publish 8080:8080 \
  --env PGADMIN_DEFAULT_EMAIL=admin@example.com \
  --env PGADMIN_DEFAULT_PASSWORD=admin \
  --env NINE_PG_MAIN_FQDN=db.example.com \
  --env NINE_PG_MAIN_PORT=5432 \
  --env NINE_PG_MAIN_USER=dbadmin \
  --env NINE_PG_MAIN_PASSWORD=secret \
  --env NINE_PG_MAIN_CA_CERT="$(cat ca.pem)" \
  on-demand-pgadmin
```

The service name (`MAIN` above) becomes the server name in the UI (prefixed with `DEPLOIO_PROJECT_NAME` if set). To inspect the generated configuration:

```shell
docker exec <container> cat /tmp/pgadmin/servers.json
```
