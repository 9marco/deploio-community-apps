ARG PGWEB_VERSION=0.17.0

FROM sosedoff/pgweb:${PGWEB_VERSION}

COPY --chmod=755 entrypoint.sh /deploio/entrypoint.sh

# Serve every referenced database from one instance instead of a single
# connection fixed at startup.
ENV PGWEB_SESSIONS=1

EXPOSE 8080

ENTRYPOINT ["/deploio/entrypoint.sh"]
