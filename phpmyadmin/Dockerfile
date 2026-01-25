ARG PHPMYADMIN_VERSION=5.2
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

FROM phpmyadmin:${PHPMYADMIN_VERSION}

COPY --from=builder /config/config.inc.php /etc/phpmyadmin/config.user.inc.php
COPY --from=builder /ssl/ /etc/phpmyadmin/ssl/
RUN chmod 644 /etc/phpmyadmin/ssl/*.pem 2>/dev/null || true

ENV APACHE_PORT=8080

EXPOSE 8080
