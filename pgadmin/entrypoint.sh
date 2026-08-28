#!/bin/sh
set -eu

DATA_DIR="/tmp/pgadmin"
CA_DIR="/tmp/deploio-ca"
SERVERS_JSON="${DATA_DIR}/servers.json"

mkdir -p "${DATA_DIR}"
rm -rf "${CA_DIR}"
mkdir -p "${CA_DIR}"

# Upstream inlines PGADMIN_CONFIG_* into config_distro.py as Python expressions
export PGADMIN_CONFIG_DATA_DIR="'${DATA_DIR}'"
export PGADMIN_LISTEN_PORT="${PORT:-8080}"

echo "Configuring ${DEPLOIO_APP_NAME:-pgadmin} (release ${DEPLOIO_RELEASE_NAME:-unknown})"

/venv/bin/python3 /deploio/servers.py "${SERVERS_JSON}" "${DATA_DIR}" "${CA_DIR}"

export PGADMIN_SERVER_JSON_FILE="${SERVERS_JSON}"
export PGADMIN_REPLACE_SERVERS_ON_STARTUP=True

exec /entrypoint.sh "$@"
