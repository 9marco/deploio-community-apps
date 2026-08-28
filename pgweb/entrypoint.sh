#!/bin/sh
set -eu

CA_DIR="/tmp/deploio-ca"
BOOKMARKS_DIR="/tmp/pgweb/bookmarks"
DOCS_URL="https://docs.nine.ch/docs/deplo-io/configuration/deploio-connecting-to-services"

DEFAULT_PORT=5432
DEFAULT_DATABASE=postgres

# Bookmarks hold connection credentials, so keep them readable by pgweb only.
umask 077

# Percent-encode a URL component. Operating on the raw bytes keeps the result
# correct for non-ASCII and other characters awk would otherwise split on.
urlencode() {
    printf '%s' "$1" | od -An -v -tu1 | LC_ALL=C awk '
        BEGIN {
            unreserved = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" \
                         "abcdefghijklmnopqrstuvwxyz" \
                         "0123456789-._~"
            for (i = 1; i <= length(unreserved); i++) {
                safe[substr(unreserved, i, 1)] = 1
            }
        }
        {
            for (i = 1; i <= NF; i++) {
                character = sprintf("%c", $i)
                printf "%s", (character in safe) ? character : sprintf("%%%02X", $i)
            }
        }
    '
}

# Extract the database name from a connection string. The value stays
# percent-encoded because it is put back into a URL unchanged.
dsn_database() {
    _remainder="${1#*://}"
    case "${_remainder}" in
    */*) ;;
    *) return 0 ;;
    esac

    _path="${_remainder#*/}"
    _path="${_path%%\?*}"
    printf '%s' "${_path%%#*}"
}

echo "Configuring ${DEPLOIO_APP_NAME:-pgweb} (release ${DEPLOIO_RELEASE_NAME:-unknown})"

rm -rf "${CA_DIR}" "${BOOKMARKS_DIR}"
mkdir -p "${CA_DIR}" "${BOOKMARKS_DIR}"

configured=0

for identifier in PG PGDB; do
    prefix="NINE_${identifier}_"

    for name in $(env | sed -n "s/^${prefix}\([A-Z0-9_]*\)_FQDN=.*/\1/p"); do
        slug="$(echo "${identifier}_${name}" | tr 'A-Z_' 'a-z-')"
        label="$(echo "${name}" | tr 'A-Z_' 'a-z-')"

        fqdn="$(printenv "${prefix}${name}_FQDN")"
        if [ -z "${fqdn}" ]; then
            echo "Skipping ${identifier}/${name}: no FQDN"
            continue
        fi

        port="$(printenv "${prefix}${name}_PORT" || echo '')"
        user="$(printenv "${prefix}${name}_USER" || echo '')"
        password="$(printenv "${prefix}${name}_PASSWORD" || echo '')"
        certificate="$(printenv "${prefix}${name}_CA_CERT" || echo '')"
        dsn="$(printenv "${prefix}${name}_DSN" || echo '')"

        [ -n "${port}" ] || port="${DEFAULT_PORT}"

        database="$(dsn_database "${dsn}")"
        [ -n "${database}" ] || database="${DEFAULT_DATABASE}"

        if [ -n "${certificate}" ]; then
            file="${CA_DIR}/${slug}.pem"
            printf '%s\n' "${certificate}" > "${file}"
            chmod 644 "${file}"
            parameters="sslmode=verify-ca&sslrootcert=${file}"
        else
            parameters="sslmode=require"
        fi

        # pgweb lists bookmarks by file name, so the file name is the label
        # shown in the connection dropdown.
        bookmark="${DEPLOIO_PROJECT_NAME:+${DEPLOIO_PROJECT_NAME} - }${label}"
        if [ -e "${BOOKMARKS_DIR}/${bookmark}.toml" ]; then
            # Same reference name used for a Business and an Economy service
            bookmark="${bookmark} (${slug})"
        fi

        # Bookmarks only pass their "url" through to the driver untouched, so
        # TLS settings have to travel as connection string parameters.
        printf 'url = "postgres://%s:%s@%s:%s/%s?%s"\n' \
            "$(urlencode "${user}")" \
            "$(urlencode "${password}")" \
            "${fqdn}" \
            "${port}" \
            "${database}" \
            "${parameters}" \
            > "${BOOKMARKS_DIR}/${bookmark}.toml"

        configured=$((configured + 1))
        echo "Configured service: ${bookmark}"
    done
done

[ "${configured}" -gt 0 ] ||
    echo "No PostgreSQL service references found, see ${DOCS_URL}"

# PGWEB_BOOKMARKS_DIR is not read by released versions, so pass the flag.
exec /usr/bin/pgweb \
    --bind=0.0.0.0 \
    --listen="${PORT:-8080}" \
    --bookmarks-dir="${BOOKMARKS_DIR}" \
    "$@"
