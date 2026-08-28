> **This is a draft**

# deploio-community-apps

Examples and templates for running popular third-party applications (such as database management tools) on [Deploio](https://deplo.io/).

For language-specific application templates, see [ninech/deploio-examples](https://github.com/ninech/deploio-examples).

> [!IMPORTANT]
> Apps and configurations in this repository are not officially supported by Nine. If you have questions or feedback, join the [Deploio Community on Slack](https://join.slack.com/t/deploiocommunity/shared_invite/zt-3oaqwt312-_eBFFh7y_IyOEtlU4kvE9w)!

---

## Web Administration Tools for On-Demand Services

These applications configure themselves automatically from environment variables injected when [referencing an On-Demand service](https://docs.nine.ch/docs/deplo-io/configuration/deploio-connecting-to-services). A custom entrypoint maps the `NINE_<IDENTIFIER>_<NAME>_<KEY>` variables to each tool's configuration format, including credentials and CA certificates.

> [!WARNING]
> If you plan to use these apps in production, fork this repository to your own account. Commits pushed to `main` in this repository will trigger a new [build and release](https://docs.nine.ch/docs/deplo-io/getting-started-with-deploio#builds-and-releases) for deployed apps.

- [phpMyAdmin](#phpmyadmin)
- [pgAdmin](#pgadmin)
- [pgweb](#pgweb)
- [Redis Insight](#redis-insight)

Add services to an application using `--service <name>=<kind>/<target-name>`. The chosen name is used as the label in the app (e.g., `--service billing=postgres/prod-db` appears as `billing`). Services can be added or removed at any time with `nctl update application`.

Kinds are matched case-insensitively against the API resource kind:

| Service               | Kind               | App            |
| --------------------- | ------------------ | -------------- |
| MySQL (Business)      | `mysql`            | phpMyAdmin     |
| MySQL (Economy)       | `mysqldatabase`    | phpMyAdmin     |
| PostgreSQL (Business) | `postgres`         | pgAdmin, pgweb |
| PostgreSQL (Economy)  | `postgresdatabase` | pgAdmin, pgweb |
| Key-Value Store       | `keyvaluestore`    | Redis Insight  |

> [!NOTE]
> Service references are injected when a new release is created. To trigger a new release manually, run `nctl update app <name> --retry-release`.

### Prerequisites

The apps read configuration at runtime, requiring no API service accounts or build variables. Service references are configured using [`nctl`](https://docs.nine.ch/docs/nctl/):

```shell
nctl auth login
```

The examples below configure one service each. Replace service names, target databases, and credentials with your own, repeating `--service` for each database you want to administer.

### phpMyAdmin

For use with [On-Demand MySQL](https://docs.nine.ch/docs/on-demand-services/mysql/business):

```shell
nctl create application on-demand-phpmyadmin \
  --git-url=https://github.com/9marco/deploio-community-apps.git \
  --git-sub-path=phpmyadmin \
  --service=production=mysql/my-database \
  --basic-auth \
  --dockerfile \
  --size=micro \
  --replicas=1
```

### pgAdmin

For use with [On-Demand PostgreSQL](https://docs.nine.ch/docs/on-demand-services/postgresql/):

```shell
nctl create application on-demand-pgadmin \
  --git-url=https://github.com/9marco/deploio-community-apps.git \
  --git-sub-path=pgadmin \
  --service=production=postgres/my-database \
  --env=PGADMIN_DEFAULT_EMAIL=admin@example.com \
  --sensitive-env=PGADMIN_DEFAULT_PASSWORD=changeme \
  --basic-auth \
  --dockerfile \
  --size=micro \
  --replicas=1
```

> [!TIP]
> By default, pgAdmin stores configuration in an ephemeral SQLite database. To persist settings across restarts and deployments, configure [external database storage](https://www.pgadmin.org/docs/pgadmin4/latest/external_database.html) using the `CONFIG_DATABASE_URI` environment variable.

### pgweb

A lighter-weight alternative to pgAdmin for [On-Demand PostgreSQL](https://docs.nine.ch/docs/on-demand-services/postgresql/). It needs no login and keeps no state, but offers fewer administration features:

```shell
nctl create application on-demand-pgweb \
  --git-url=https://github.com/9marco/deploio-community-apps.git \
  --git-sub-path=pgweb \
  --service=production=postgres/my-database \
  --basic-auth \
  --dockerfile \
  --size=micro \
  --replicas=1
```

Each referenced service becomes a bookmark. Open the connection window and pick one from the dropdown to connect. To hide the manual connection form and allow the generated bookmarks only, add `--env=PGWEB_BOOKMARKS_ONLY=1`.

> [!NOTE]
> Connections are held in memory per browser session, so run pgweb with a single replica.

### Redis Insight

For use with [On-Demand Key-Value Store](https://docs.nine.ch/docs/on-demand-services/on-demand-key-value-store):

```shell
nctl create application on-demand-redis-insight \
  --git-url=https://github.com/9marco/deploio-community-apps.git \
  --git-sub-path=redis-insight \
  --service=cache=keyvaluestore/my-kvs \
  --env=RI_ACCEPT_TERMS_AND_CONDITIONS=true \
  --basic-auth \
  --dockerfile \
  --size=micro \
  --replicas=1
```

### Security

Because these apps connect automatically using the injected credentials without prompting for passwords, protect public access using [`--basic-auth`](https://docs.nine.ch/docs/deplo-io/configuration/deploio-basic-auth).
