ARG PGADMIN_VERSION=9.11

FROM dpage/pgadmin4:${PGADMIN_VERSION}

COPY --chmod=755 entrypoint.sh /deploio/entrypoint.sh
COPY --chmod=644 servers.py /deploio/servers.py

ENV PGADMIN_DISABLE_POSTFIX=true

EXPOSE 8080

ENTRYPOINT ["/deploio/entrypoint.sh"]
