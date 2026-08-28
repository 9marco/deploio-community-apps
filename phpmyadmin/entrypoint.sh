#!/bin/sh
set -eu

CA_DIR="/tmp/deploio-ca"
DOCS_URL="https://docs.nine.ch/docs/deplo-io/configuration/deploio-connecting-to-services"

export APACHE_PORT="${PORT:-8080}"

echo "Configuring ${DEPLOIO_APP_NAME:-phpmyadmin} (release ${DEPLOIO_RELEASE_NAME:-unknown})"

rm -rf "${CA_DIR}"
mkdir -p "${CA_DIR}"

configured=0

for identifier in MYSQL MYSQLDB; do
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
    echo "No MySQL service references found, see ${DOCS_URL}"

exec /docker-entrypoint.sh "$@"
