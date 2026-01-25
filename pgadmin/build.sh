#!/bin/sh
set -e

CONFIG="/config/servers.json"
SSL_DIR="/ssl"
SSL_DIR_APP="/etc/pgadmin/ssl"

mkdir -p "$(dirname "${CONFIG}")" "${SSL_DIR}"

if [ -n "${NCTL_PROJECT}" ]; then
    echo "Fetching PostgreSQL from project: ${NCTL_PROJECT}"
    nctl get postgres --project="${NCTL_PROJECT}" -o json > /tmp/postgres.json
else
    echo "Fetching PostgreSQL from all projects"
    nctl get postgres --all-projects -o json > /tmp/postgres.json
fi

# JSON config
echo '{"Servers":{' > "${CONFIG}"

FIRST=true
INDEX=1

jq -r '.[] | [.metadata.namespace, .metadata.name, .status.atProvider.fqdn // "", .status.atProvider.caCert // ""] | @tsv' /tmp/postgres.json | \
while IFS=$(printf '\t') read -r PROJECT NAME HOST CA_B64; do
    [ -z "${HOST}" ] && echo "Skipping ${PROJECT}/${NAME} (not ready)" && continue

    echo "Adding: ${PROJECT}/${NAME}"

    # Comma separation
    if [ "${FIRST}" = true ]; then
        FIRST=false
    else
        echo "," >> "${CONFIG}"
    fi

    SSL_MODE="require" # CA certificate is self-signed
    SSL_ROOT=""
    if [ -n "${CA_B64}" ]; then
        echo "${CA_B64}" | base64 -d > "${SSL_DIR}/ca-${PROJECT}-${NAME}.pem"
        SSL_ROOT=",\"SSLRootCert\":\"${SSL_DIR_APP}/ca-${PROJECT}-${NAME}.pem\""
    fi

    cat >> "${CONFIG}" << JSON
"${INDEX}":{
  "Name":"${PROJECT} / ${NAME}",
  "Group":"Servers",
  "Host":"${HOST}",
  "Port":5432,
  "Username":"dbadmin",
  "MaintenanceDB":"postgres",
  "SSLMode":"${SSL_MODE}"${SSL_ROOT}
}
JSON

    INDEX=$((INDEX + 1))
done

echo '}}' >> "${CONFIG}"
