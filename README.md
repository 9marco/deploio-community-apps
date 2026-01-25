> **This is a draft**

# deploio-community-apps

This repository is a showcase of public third-party image integrations and custom application examples, highlighting how standard software and customer-specific configurations can be operated with [Deploio](https://deplo.io/).

Refer to https://github.com/ninech/deploio-examples for programming language specific examples.

> [!IMPORTANT]
> Apps and configurations in this repository are not officially supported by Nine. If you have any questions, do not hesitate to join our [Deploio Community on Slack](https://join.slack.com/t/deploiocommunity/shared_invite/zt-3oaqwt312-_eBFFh7y_IyOEtlU4kvE9w)!

---

## Web Administration Tools for [On-Demand Services](https://docs.nine.ch/docs/on-demand-services/)

The following Deploio applications use the [`nctl`](https://docs.nine.ch/docs/nctl/) command-line tool and its option for machine-readable output, [authenticated via an API service account](https://docs.nine.ch/docs/nctl/#log-in-with-an-api-service-account), to automatically pre-configure the list of available services with the required CA certificates, as part of the Deploio build and release pipeline.

> [!WARNING]
> If you plan on using these apps with your production environment, it is recommended that you create a fork in your own account, as commits pushed to the main branch of this repository will trigger a new [build and release](https://docs.nine.ch/docs/deplo-io/getting-started-with-deploio#builds-and-releases) for all running apps.

- [phpMyAdmin](#phpmyadmin)
- [pgAdmin](#pgadmin)
- [Redis Insight](#redis-insight)

If you add or remove an On-Demand service, simply trigger a rebuild of the application in Deploio, for the configuration to be automatically updated.

You can optionally specify a project for each of the following apps via the `PROJECT` build environment variable to filter for resources in a specific project.

```
  --build-env=PROJECT=customeridentifier-sub-project
```

### Prerequisites

In order for the build environment in Deploio to be able to list and access parameters of your On-Demand services, you will need to create an API service account, either in [Cockpit](https://cockpit.nine.ch/en/customer/api_service_accounts) or with [`nctl`](https://docs.nine.ch/docs/nctl/).


```shell
nctl create apiserviceaccount deploio-apps \
  --project customeridentifier \
  --organization-access
```

To create an API service account that can access all parts of the organization, you will need to create it in the 'default' project, matching your customer identifier. Otherwise, you can also restrict it to a specific project.

```shell
nctl create apiserviceaccount deploio-apps \
  --project customeridentifier-sub-project
```

Finally, make sure that `nctl` running on your machine is authenticated with your personal account.

```shell
nctl auth login
```

### phpMyAdmin

To be used with [On-Demand MySQL (Business Tier)](https://docs.nine.ch/docs/on-demand-services/mysql/business).

```shell
nctl create application on-demand-phpmyadmin \
  --git-url=https://github.com/9marco/deploio-community-apps.git \
  --git-sub-path=phpmyadmin \
  --sensitive-build-env=NCTL_API_CLIENT_ID=$(nctl get apiserviceaccounts deploio-apps --print-client-id) \
  --sensitive-build-env=NCTL_API_CLIENT_SECRET=$(nctl get apiserviceaccounts deploio-apps --print-client-secret) \
  --build-env=ORGANIZATION=customeridentifier \ # change me
  --basic-auth \
  --dockerfile \
  --size=mini
```

### pgAdmin

To be used with [On-Demand PostgreSQL (Business Tier)](https://docs.nine.ch/docs/on-demand-services/postgresql/).

```shell
nctl create application on-demand-pgadmin \
  --git-url=https://github.com/9marco/deploio-community-apps.git \
  --git-sub-path=pgadmin \
  --sensitive-build-env=NCTL_API_CLIENT_ID=$(nctl get apiserviceaccounts deploio-apps --print-client-id) \
  --sensitive-build-env=NCTL_API_CLIENT_SECRET=$(nctl get apiserviceaccounts deploio-apps --print-client-secret) \
  --build-env=ORGANIZATION=customeridentifier \       # change me
  --env=PGADMIN_DEFAULT_EMAIL=admin@example.com \     # change me
  --sensitive-env=PGADMIN_DEFAULT_PASSWORD=changeme \ # change me
  --basic-auth \
  --dockerfile \
  --size=mini
```

> [!TIP]
> Unlike PhpMyAdmin, pgAdmin does not persist its settings in a schema by default, but in a SQLite database on ephemeral storage. To persist your settings across restarts and deployments, you will need to manually create a schema and set an additional environment variable `CONFIG_DATABASE_URI` according to https://www.pgadmin.org/docs/pgadmin4/latest/external_database.html. Deploio applications are automatically redeployed when environment variables are changed, so that they can take effect.

### Redis Insight

To be used with [On-Demand Key-Value Store](https://docs.nine.ch/docs/on-demand-services/on-demand-key-value-store).

```shell
nctl create application on-demand-redis-insight \
  --git-url=https://github.com/9marco/deploio-community-apps.git \
  --git-sub-path=redis-insight \
  --sensitive-build-env=NCTL_API_CLIENT_ID=$(nctl get apiserviceaccounts deploio-apps --print-client-id) \
  --sensitive-build-env=NCTL_API_CLIENT_SECRET=$(nctl get apiserviceaccounts deploio-apps --print-client-secret) \
  --build-env=ORGANIZATION=customeridentifier \ # change me
  --basic-auth \
  --dockerfile \
  --size=mini
```

---

[Deploio](https://deplo.io/) is a great fit for deploying and running custom-built apps, but it's also flexible enough to host standard software like phpMyAdmin.
Almost any configuration or adjustment exceeding environment variables and standard mechanisms can be achieved by adding additional Docker layers via Deploio's own support for [Dockerfiles](https://docs.nine.ch/docs/deplo-io/dockerfile-build).

Web apps in this repository operate as [stateless services](https://12factor.net/processes), meaning that they do not persist data locally. This ensures they remain compatible with Deploio's ephemeral container architecture.
For any requirements involving persistent state, [a database](https://docs.nine.ch/docs/on-demand-services/) or [object storage](https://docs.nine.ch/docs/category/object-storage) should be utilized.

## Concepts

The following concepts outline various ways in which third-party images can be used with Deploio, ranging from basic image aliasing to more advanced build pipelines and operation tools.

* Image Aliasing: Deploy any standard image capable of serving web requests, by using a simple `FROM` statement in your Dockerfile to pull directly from an existing registry.
* Environment Configuration: Customize standard images by using supported environment variables defined at the application or project level.
* Custom Docker Layers: Extend base images by adding additional Docker image layers to include custom configuration files and code, allowing for anything up to a fully customized entrypoint.
* Advanced Jobs: Leverage the full capabilities of Deploio by adding [deploy jobs](https://docs.nine.ch/docs/deplo-io/configuration/deploio-deploy-jobs) to finalize successful deployments or [worker jobs](https://docs.nine.ch/docs/deplo-io/configuration/deploio-worker-jobs) for running background processes in a sidecar.
