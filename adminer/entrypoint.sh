#!/bin/sh
set -eu

CA_DIR="/tmp/deploio-ca"
DOCS_URL="https://docs.nine.ch/docs/deplo-io/configuration/deploio-connecting-to-services"

echo "Configuring ${DEPLOIO_APP_NAME:-adminer} (release ${DEPLOIO_RELEASE_NAME:-unknown})"

rm -rf "${CA_DIR}"
mkdir -p "${CA_DIR}"

configured=0

# MySQL (Business, Economy), PostgreSQL (Business, Economy), OpenSearch and
# the Key-Value Store
for identifier in MYSQL MYSQLDB PG PGDB OS KVS; do
    prefix="NINE_${identifier}_"

    for name in $(env | sed -n "s/^${prefix}\([A-Z0-9_]*\)_FQDN=.*/\1/p"); do
        label="$(echo "${name}" | tr 'A-Z_' 'a-z-')"
        display="${DEPLOIO_PROJECT_NAME:+${DEPLOIO_PROJECT_NAME} / }${label}"

        configured=$((configured + 1))
        echo "Configured service: ${display}"

        certificate="$(printenv "${prefix}${name}_CA_CERT" || true)"
        [ -n "${certificate}" ] || continue

        file="${CA_DIR}/$(echo "${identifier}_${name}" | tr 'A-Z_' 'a-z-').pem"
        printf '%s\n' "${certificate}" > "${file}"
        chmod 644 "${file}"

        export "${prefix}${name}_CA_FILE=${file}"
    done
done

[ "${configured}" -gt 0 ] ||
    echo "No service references found, see ${DOCS_URL}"

# Serve with the built-in PHP server like the image does, but on the port
# assigned by Deplo.io, which only the command line can carry.
[ "$#" -gt 0 ] || set -- php -S "[::]:${PORT:-8080}" -t /var/www/html

exec /usr/local/bin/entrypoint.sh docker-php-entrypoint "$@"
