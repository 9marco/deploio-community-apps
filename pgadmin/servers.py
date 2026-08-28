"""Generate pgAdmin servers.json and .pgpass from Deploio environment variables."""

import json
import os
import stat
import sys
from urllib.parse import unquote, urlsplit

IDENTIFIERS = ("PG", "PGDB")
KEYS = ("FQDN", "PORT", "USER", "PASSWORD", "CA_CERT", "DSN")

DEFAULT_PORT = 5432
DEFAULT_MAINTENANCE_DB = "postgres"

SSL_MODE_VERIFIED = "verify-ca"
SSL_MODE_ENCRYPTED = "require"

DOCS_URL = (
    "https://docs.nine.ch/docs/deplo-io/configuration/"
    "deploio-connecting-to-services"
)

# Relative to the pgAdmin user's storage directory
PASSFILE = "/.pgpass"


def discover(identifier):
    """Return {reference_name: {key: value}} for one service identifier."""
    services = {}
    prefix = "NINE_{}_".format(identifier)

    for variable, value in os.environ.items():
        if not variable.startswith(prefix):
            continue

        for key in sorted(KEYS, key=len, reverse=True):
            suffix = "_" + key
            if not variable.endswith(suffix):
                continue
            name = variable[len(prefix):-len(suffix)]
            if name:
                services.setdefault(name, {})[key] = value
            break

    return services


def maintenance_db(service):
    """Determine the default database to connect to."""
    dsn = service.get("DSN")
    if dsn:
        database = unquote(urlsplit(dsn).path).lstrip("/")
        if database:
            return database

    return service.get("USER") or DEFAULT_MAINTENANCE_DB


def port(service):
    try:
        return int(service["PORT"])
    except (KeyError, ValueError):
        return DEFAULT_PORT


def slug(identifier, name):
    return "{}-{}".format(identifier, name.replace("_", "-")).lower()


def label(name):
    readable = name.replace("_", "-").lower()
    project = os.environ.get("DEPLOIO_PROJECT_NAME")
    return "{} / {}".format(project, readable) if project else readable


def preprocess_username(username):
    """Mirror pgAdmin's internal username normalization for storage paths."""
    if not username or username[0].isdigit():
        username = "pga_user_" + username

    return username.replace("@", "_").replace("/", "slash").replace("\\", "slash")


def pgpass_field(value):
    """Escape colons and backslashes for .pgpass."""
    return value.replace("\\", "\\\\").replace(":", "\\:")


def collect():
    """Return referenced PostgreSQL services keyed by slug."""
    services = {}
    for identifier in IDENTIFIERS:
        for name, service in discover(identifier).items():
            if not service.get("FQDN"):
                print("Skipping {}/{}: no FQDN".format(identifier, name))
                continue
            service["label"] = label(name)
            services[slug(identifier, name)] = service

    return dict(sorted(services.items()))


def write_certificates(services, directory):
    paths = {}
    for name, service in services.items():
        pem = service.get("CA_CERT", "").strip()
        if not pem:
            continue

        path = os.path.join(directory, "{}.pem".format(name))
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(pem + "\n")
        os.chmod(path, 0o644)
        paths[name] = path

    return paths


def write_servers(services, certificates, path):
    servers = {}
    for index, (name, service) in enumerate(services.items(), start=1):
        verified = name in certificates
        parameters = {
            "sslmode": SSL_MODE_VERIFIED if verified else SSL_MODE_ENCRYPTED,
        }
        if verified:
            parameters["sslrootcert"] = certificates[name]
        if service.get("PASSWORD"):
            parameters["passfile"] = PASSFILE

        servers[str(index)] = {
            "Name": service["label"],
            "Group": "Servers",
            "Host": service["FQDN"],
            "Port": port(service),
            "Username": service.get("USER", ""),
            "MaintenanceDB": maintenance_db(service),
            "ConnectionParameters": parameters,
        }

    with open(path, "w", encoding="utf-8") as handle:
        json.dump({"Servers": servers}, handle, indent=2)

    return servers


def write_passfile(services, path):
    """Write .pgpass entries for passwordless authentication."""
    lines = []
    for service in services.values():
        password = service.get("PASSWORD")
        if not password:
            continue
        line = ":".join(pgpass_field(field) for field in (
            service["FQDN"],
            str(port(service)),
            "*",
            service.get("USER", ""),
            password,
        ))
        if line not in lines:
            lines.append(line)

    if not lines:
        return 0

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")
    # .pgpass requires 0600 permissions
    os.chmod(path, stat.S_IRUSR | stat.S_IWUSR)

    return len(lines)


def main(servers_json, data_dir, certificate_dir):
    services = collect()
    if not services:
        print("No PostgreSQL service references found, see " + DOCS_URL)

    os.makedirs(certificate_dir, exist_ok=True)
    certificates = write_certificates(services, certificate_dir)

    write_servers(services, certificates, servers_json)

    email = os.environ.get("PGADMIN_DEFAULT_EMAIL")
    if email:
        passfile = os.path.join(
            data_dir, "storage", preprocess_username(email), PASSFILE.lstrip("/")
        )
        write_passfile(services, passfile)

    for service in services.values():
        print("Configured service: {}".format(service["label"]))


if __name__ == "__main__":
    main(*sys.argv[1:4])
