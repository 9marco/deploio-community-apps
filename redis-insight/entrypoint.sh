#!/bin/sh
set -eu

CA_DIR="/tmp/deploio-ca"
DOCS_URL="https://docs.nine.ch/docs/deplo-io/configuration/deploio-connecting-to-services"

export RI_APP_PORT="${PORT:-8080}"

echo "Configuring ${DEPLOIO_APP_NAME:-redis-insight} (release ${DEPLOIO_RELEASE_NAME:-unknown})"

rm -rf "${CA_DIR}"
mkdir -p "${CA_DIR}"

configured=0

for name in $(env | sed -n 's/^NINE_KVS_\([A-Z0-9_]*\)_FQDN=.*/\1/p'); do
    prefix="NINE_KVS_${name}_"
    label="$(echo "${name}" | tr 'A-Z_' 'a-z-')"
    display="${DEPLOIO_PROJECT_NAME:+${DEPLOIO_PROJECT_NAME} / }${label}"

    export "RI_REDIS_HOST_${name}=$(printenv "${prefix}FQDN")"
    export "RI_REDIS_PORT_${name}=$(printenv "${prefix}PORT" || echo 6379)"
    export "RI_REDIS_USERNAME_${name}=$(printenv "${prefix}USER" || echo default)"
    export "RI_REDIS_PASSWORD_${name}=$(printenv "${prefix}PASSWORD" || echo '')"
    export "RI_REDIS_ALIAS_${name}=${display}"
    export "RI_REDIS_TLS_${name}=true"

    configured=$((configured + 1))
    echo "Configured service: ${display}"

    certificate="$(printenv "${prefix}CA_CERT" || true)"
    [ -n "${certificate}" ] || continue

    file="${CA_DIR}/kvs-${label}.pem"
    printf '%s\n' "${certificate}" > "${file}"
    chmod 644 "${file}"

    export "RI_REDIS_TLS_CA_PATH_${name}=${file}"
done

[ "${configured}" -gt 0 ] ||
    echo "No Key-Value Store service references found, see ${DOCS_URL}"

exec /usr/src/app/docker-entry.sh "$@"
