#!/bin/sh
set -e

CONFIG="/config/config.inc.php"
SSL_DIR="/ssl"
SSL_DIR_APP="/etc/phpmyadmin/ssl"

mkdir -p "$(dirname "${CONFIG}")" "${SSL_DIR}"

if [ -n "${NCTL_PROJECT}" ]; then
    echo "Fetching MySQL from project: ${NCTL_PROJECT}"
    nctl get mysql --project="${NCTL_PROJECT}" -o json > /tmp/mysql.json
else
    echo "Fetching MySQL from all projects"
    nctl get mysql --all-projects -o json > /tmp/mysql.json
fi

# PHP config
cat > "${CONFIG}" << PHP
<?php
\$cfg['blowfish_secret'] = '$(openssl rand -hex 16)';
\$cfg['UploadDir'] = '';
\$cfg['SaveDir'] = '';
\$cfg['TempDir'] = '/tmp';
\$cfg['ZeroConf'] = true;
\$i = 0;
PHP

jq -r '.[] | [.metadata.namespace, .metadata.name, .status.atProvider.fqdn // "", .status.atProvider.caCert // ""] | @tsv' /tmp/mysql.json | \
while IFS=$(printf '\t') read -r PROJECT NAME HOST CA_B64; do
    [ -z "${HOST}" ] && echo "Skipping ${PROJECT}/${NAME} (not ready)" && continue

    echo "Adding: ${PROJECT}/${NAME}"

    SSL_LINES=""
    if [ -n "${CA_B64}" ]; then
        echo "${CA_B64}" | base64 -d > "${SSL_DIR}/ca-${PROJECT}-${NAME}.pem"
        SSL_LINES="\$cfg['Servers'][\$i]['ssl'] = true;
\$cfg['Servers'][\$i]['ssl_ca'] = '${SSL_DIR_APP}/ca-${PROJECT}-${NAME}.pem';
\$cfg['Servers'][\$i]['ssl_verify'] = false;" # CA certificate is self-signed
    fi

    cat >> "${CONFIG}" << PHP

\$i++;
\$cfg['Servers'][\$i]['verbose'] = '${PROJECT} / ${NAME}';
\$cfg['Servers'][\$i]['host'] = '${HOST}';
\$cfg['Servers'][\$i]['port'] = '3306';
\$cfg['Servers'][\$i]['auth_type'] = 'cookie';
\$cfg['Servers'][\$i]['compress'] = false;
\$cfg['Servers'][\$i]['AllowNoPassword'] = false;
${SSL_LINES}
PHP
done
