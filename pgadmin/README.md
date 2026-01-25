The pgAdmin version tag can be overriden by setting `PGADMIN_VERSION` during the build phase.

## Building and Running the Container Locally

```shell
docker build \
  --build-arg NCTL_API_CLIENT_ID=$(nctl get apiserviceaccounts deploio-apps --print-client-id) \
  --build-arg NCTL_API_CLIENT_SECRET=$(nctl get apiserviceaccounts deploio-apps --print-client-secret) \
  --build-arg ORGANIZATION=customeridentifier \
  --tag on-demand-pgadmin .
```

```shell
docker run --rm --publish 8080:8080 --env PGADMIN_DEFAULT_EMAIL=admin@example.com --env PGADMIN_DEFAULT_PASSWORD=admin on-demand-pgadmin
```