The Adminer version can be set with the `ADMINER_VERSION` build argument.

Adminer administers MySQL, PostgreSQL, OpenSearch and the Key-Value Store from a single app.

## Configuration

`plugin.php` is installed as `plugins-enabled/000-deploio.php` and reads the `NINE_MYSQL_<NAME>_*` (MySQL Business), `NINE_MYSQLDB_<NAME>_*` (MySQL Economy), `NINE_PG_<NAME>_*` (PostgreSQL Business), `NINE_PGDB_<NAME>_*` (PostgreSQL Economy), `NINE_OS_<NAME>_*` (OpenSearch) and `NINE_KVS_<NAME>_*` (Key-Value Store) [service variables](https://docs.nine.ch/docs/deplo-io/configuration/deploio-connecting-to-services) on each request.

Every reference becomes an entry of the server list rendered by the bundled [`login-servers`](https://www.adminer.org/plugins/) plugin, labelled `<project> / <reference> (<system>)`. The system is part of the label because the list replaces the driver field of the login form. The plugin also answers with the injected credentials, so the login form asks for a server and nothing else. Protect the application using [`--basic-auth`](https://docs.nine.ch/docs/deplo-io/configuration/deploio-basic-auth).

The Elasticsearch driver shipped with Adminer is loaded for OpenSearch, which it recognises by the distribution the cluster reports. Deplo.io injects no port for OpenSearch, so port 443 is used.

`redis-tls.php` is installed as `plugins/deploio-redis-tls.php` and loads the Redis driver for the Key-Value Store. The driver opens its connection with `fsockopen()`, which negotiates TLS for a `tls://` address but takes no stream context, ignores the default one and therefore always verifies the host name — which the certificate of an On-Demand service does not carry. The driver calls the function unqualified from the `Adminer` namespace, where a definition takes precedence over the one in the global namespace, so the file defines `Adminer\fsockopen()` and connects with `stream_socket_client()` and a certificate instead. `redis.php` is the only caller of `fsockopen()` in Adminer.

The Dockerfile also widens the second parameter of `jushAutocomplete()` in `redis.php` again. The release script drops its type from `adminer.php`, while the drivers in the source archive of the same release still declare it, which makes PHP reject the declaration of the driver.

`entrypoint.sh` writes CA certificates to `/tmp/deploio-ca/` before the server starts and exports their paths as `NINE_<IDENTIFIER>_<NAME>_CA_FILE`. It also builds the command of the built-in PHP server from `$PORT`, which the command of the image hard-codes.

### TLS

The certificate of an On-Demand service does not match the host name of the service, so host name verification is off everywhere:

| System          | Configuration                                                        | Result                                |
| --------------- | -------------------------------------------------------------------- | ------------------------------------- |
| PostgreSQL      | `sslmode=verify-ca`, certificate passed to libpq via `PGSSLROOTCERT` | encrypted, certificate chain verified |
| Key-Value Store | `verify_peer` on and `verify_peer_name` off in the stream context    | encrypted, certificate chain verified |
| MySQL           | `MYSQLI_CLIENT_SSL_DONT_VERIFY_SERVER_CERT`                          | encrypted, certificate not verified   |
| OpenSearch      | `verify_peer` off in the stream context                              | encrypted, certificate not verified   |

mysqli and the Elasticsearch driver take both the certificate and the host name check from a single flag, so a certificate that does not match the host name cannot be verified at all there. PostgreSQL and the Key-Value Store separate the two, the same way [pgAdmin](../pgadmin) is configured.

Without a CA certificate, PostgreSQL falls back to `sslmode=require` and the Key-Value Store connects encrypted without verifying anything.

### Selected database

PostgreSQL needs a database already when connecting, so the database of the injected `DSN` is used, falling back to the user name, which is the database name of an Economy service. MySQL, OpenSearch and the Key-Value Store select the database after connecting; the Key-Value Store lists the databases its `databases` configuration reports.

### Image options

The environment variables of the [official image](https://hub.docker.com/_/adminer) still apply, such as `ADMINER_DESIGN` to pick one of the bundled designs and `ADMINER_PLUGINS` to load further plugins. `ADMINER_DEFAULT_SERVER` has no effect, because the service list replaces the server field.

## Building and Running Locally

```shell
docker build --tag on-demand-adminer .
```

Run with simulated Deploio environment variables:

```shell
docker run --rm --publish 8080:8080 \
  --env NINE_PG_MAIN_FQDN=db.example.com \
  --env NINE_PG_MAIN_PORT=5432 \
  --env NINE_PG_MAIN_USER=dbadmin \
  --env NINE_PG_MAIN_PASSWORD=secret \
  --env NINE_PG_MAIN_CA_CERT="$(cat ca.pem)" \
  on-demand-adminer
```

The service name (`MAIN` above) becomes the server name in the login form (prefixed with `DEPLOIO_PROJECT_NAME` if set). Repeat the variables with another identifier and name to add more services.
