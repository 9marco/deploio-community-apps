#!/bin/sh
set -e

CONFIG="/config/databases.json"

mkdir -p "$(dirname "${CONFIG}")"

if [ -n "${NCTL_PROJECT}" ]; then
    echo "Fetching KeyValueStore from project: ${NCTL_PROJECT}"
    nctl get keyvaluestore --project="${NCTL_PROJECT}" -o json > /tmp/redis.json
else
    echo "Fetching KeyValueStore from all projects"
    nctl get keyvaluestore --all-projects -o json > /tmp/redis.json
fi

# JSON config
echo '[' > "${CONFIG}"

FIRST=true

jq -r '.[] | [.metadata.namespace, .metadata.name, .status.atProvider.fqdn // ""] | @tsv' /tmp/redis.json | \
while IFS=$(printf '\t') read -r PROJECT NAME HOST; do
    [ -z "${HOST}" ] && echo "Skipping ${PROJECT}/${NAME} (not ready)" && continue

    echo "Adding: ${PROJECT}/${NAME}"

    TOKEN=$(nctl get keyvaluestore "${NAME}" --project="${PROJECT}" --print-token)
    CA_CERT=$(nctl get keyvaluestore "${NAME}" --project="${PROJECT}" --print-ca-cert)

    if [ "${FIRST}" = true ]; then
        FIRST=false
    else
        echo "," >> "${CONFIG}"
    fi

    CA_CERT_ESCAPED=$(echo "${CA_CERT}" | awk '{printf "%s\\n", $0}')

    cat >> "${CONFIG}" << JSON
{
  "compressor": "NONE",
  "id": "${PROJECT}-${NAME}",
  "host": "${HOST}",
  "port": 6379,
  "name": "${PROJECT} / ${NAME}",
  "db": 0,
  "username": "default",
  "password": "${TOKEN}",
  "connectionType": "STANDALONE",
  "nameFromProvider": null,
  "provider": "REDIS_COMMUNITY_EDITION",
  "lastConnection": null,
  "modules": [],
  "tls": true,
  "tlsServername": null,
  "verifyServerCert": false,
  "caCert": {
    "id": "${PROJECT}-${NAME}",
    "name": "${PROJECT}-${NAME}-ca",
    "certificate": "${CA_CERT_ESCAPED}"
  },
  "clientCert": null,
  "ssh": false,
  "sshOptions": null,
  "forceStandalone": false,
  "tags": []
}
JSON
done

echo ']' >> "${CONFIG}"
