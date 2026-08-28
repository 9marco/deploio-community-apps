The phpMyAdmin version can be set with the `PHPMYADMIN_VERSION` build argument.

## Configuration

`config.user.inc.php` reads `NINE_MYSQL_<NAME>_*` (MySQL Business) and `NINE_MYSQLDB_<NAME>_*` (MySQL Economy) [service variables](https://docs.nine.ch/docs/deplo-io/configuration/deploio-connecting-to-services) dynamically on each request to populate `$cfg['Servers']`.

Servers use `auth_type = 'config'` to authenticate directly with injected credentials. Protect the application using [`--basic-auth`](https://docs.nine.ch/docs/deplo-io/configuration/deploio-basic-auth).

`entrypoint.sh` writes CA certificates to `/tmp/deploio-ca/` before Apache starts. When present, SSL is enabled and configured with the CA certificate.

## Building and Running Locally

```shell
docker build --tag on-demand-phpmyadmin .
```

Run with simulated Deploio environment variables:

```shell
docker run --rm --publish 8080:8080 \
  --env NINE_MYSQL_MAIN_FQDN=db.example.com \
  --env NINE_MYSQL_MAIN_PORT=3306 \
  --env NINE_MYSQL_MAIN_USER=dbadmin \
  --env NINE_MYSQL_MAIN_PASSWORD=secret \
  --env NINE_MYSQL_MAIN_CA_CERT="$(cat ca.pem)" \
  on-demand-phpmyadmin
```

The service name (`MAIN` above) becomes the server name in the UI (prefixed with `DEPLOIO_PROJECT_NAME` if set).
