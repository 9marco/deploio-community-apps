The pgweb version can be set with the `PGWEB_VERSION` build argument.

## Configuration

`entrypoint.sh` converts `NINE_PG_<NAME>_*` (PostgreSQL Business) and `NINE_PGDB_<NAME>_*` (PostgreSQL Economy) [service variables](https://docs.nine.ch/docs/deplo-io/configuration/deploio-connecting-to-services) into [pgweb bookmarks](https://github.com/sosedoff/pgweb/wiki/Server-Connection-Bookmarks) in `/tmp/pgweb/bookmarks/`, one TOML file per referenced service.

`PGWEB_SESSIONS` is enabled so a single instance can serve every referenced database. Databases are not opened automatically: pick one from the bookmark dropdown in the connection window.

Bookmarks are written as a connection string, because pgweb only passes a bookmark's `url` through to the driver unchanged. Credentials are percent-encoded, and the files are created with `0600` permissions. When a CA certificate is provided, it is saved to `/tmp/deploio-ca/` and the connection uses `sslmode=verify-ca`, otherwise `sslmode=require`.

The database name is taken from the `DSN` variable when present, and falls back to the `postgres` default database. Use the database dropdown in pgweb to switch to another database on the same server.

Useful upstream settings, all set as environment variables:

| Variable               | Effect                                                                               |
| ---------------------- | ------------------------------------------------------------------------------------ |
| `PGWEB_BOOKMARKS_ONLY` | Only allow connections to the generated bookmarks, hiding the manual connection form |
| `PGWEB_SESSIONS`       | Set to an empty value to fall back to pgweb's single-connection mode                 |
| `PGWEB_URL_PREFIX`     | Serve the UI under a path prefix                                                     |

## Building and Running Locally

```shell
docker build --tag on-demand-pgweb .
```

Run with simulated Deploio environment variables:

```shell
docker run --rm --publish 8080:8080 \
  --env NINE_PG_MAIN_FQDN=db.example.com \
  --env NINE_PG_MAIN_PORT=5432 \
  --env NINE_PG_MAIN_USER=dbadmin \
  --env NINE_PG_MAIN_PASSWORD=secret \
  --env NINE_PG_MAIN_CA_CERT="$(cat ca.pem)" \
  on-demand-pgweb
```

The service name (`MAIN` above) becomes the bookmark name in the UI (prefixed with `DEPLOIO_PROJECT_NAME` if set). To inspect the generated configuration:

```shell
docker exec <container> sh -c 'cat "/tmp/pgweb/bookmarks/"*.toml'
```
