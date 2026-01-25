ARG PGADMIN_VERSION=9.11
ARG NCTL_VERSION=1.13.1

FROM alpine:3.19 AS builder

ARG NCTL_VERSION
ARG NCTL_API_CLIENT_ID
ARG NCTL_API_CLIENT_SECRET
ARG ORGANIZATION
ARG PROJECT

ENV NCTL_API_CLIENT_ID=$NCTL_API_CLIENT_ID \
    NCTL_API_CLIENT_SECRET=$NCTL_API_CLIENT_SECRET \
    NCTL_ORGANIZATION=$ORGANIZATION \
    NCTL_PROJECT=$PROJECT

RUN apk add --no-cache curl tar openssl jq \
    && curl -sL "https://github.com/ninech/nctl/releases/download/v${NCTL_VERSION}/nctl_${NCTL_VERSION}_linux_amd64.tar.gz" \
       | tar xz -C /usr/local/bin nctl

ADD https://www.cloudflare.com/cdn-cgi/trace /cachebust
RUN nctl auth login \
    --organization="${NCTL_ORGANIZATION}" \
    --api-client-id="${NCTL_API_CLIENT_ID}" \
    --api-client-secret="${NCTL_API_CLIENT_SECRET}"

COPY --chmod=755 build.sh /
RUN /build.sh

FROM dpage/pgadmin4:${PGADMIN_VERSION}

COPY --from=builder /config/servers.json /pgadmin4/servers.json
COPY --from=builder /ssl/ /etc/pgadmin/ssl/
RUN chmod 644 /etc/pgadmin/ssl/*.pem 2>/dev/null || true

ENV PGADMIN_SERVER_JSON_FILE=/pgadmin4/servers.json \
    PGADMIN_DISABLE_POSTFIX=true \
    PGADMIN_CONFIG_DATA_DIR="'/tmp/pgadmin-data'" \
    PGADMIN_LISTEN_PORT=8080

EXPOSE 8080
