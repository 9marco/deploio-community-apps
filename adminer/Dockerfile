ARG ADMINER_VERSION=6

FROM adminer:${ADMINER_VERSION}

COPY --chmod=755 entrypoint.sh /deploio/entrypoint.sh
COPY --chmod=644 plugin.php /var/www/html/plugins-enabled/000-deploio.php
COPY --chmod=644 redis-tls.php /var/www/html/plugins/deploio-redis-tls.php

# The release script drops the type of the second parameter of
# SqlDriver::jushAutocomplete() from adminer.php, while the drivers in the
# source archive of the same release still declare it, so PHP rejects the
# declaration of the Redis driver. Widening the parameter again is compatible
# with both.
USER root
RUN sed -i 's/jushAutocomplete(array $tables, ?array $statements)/jushAutocomplete(array $tables, $statements)/' \
    /var/www/html/plugins/drivers/redis.php
USER adminer

EXPOSE 8080

ENTRYPOINT ["/deploio/entrypoint.sh"]
# The command of the image hard-codes the listen address of the built-in PHP
# server, which cannot read a port from the environment. entrypoint.sh builds
# the command from $PORT instead.
CMD []
