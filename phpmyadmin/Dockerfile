ARG PHPMYADMIN_VERSION=5.2

FROM phpmyadmin:${PHPMYADMIN_VERSION}

COPY --chmod=755 entrypoint.sh /deploio/entrypoint.sh
COPY --chmod=644 config.user.inc.php /etc/phpmyadmin/config.user.inc.php

EXPOSE 8080

ENTRYPOINT ["/deploio/entrypoint.sh"]
CMD ["apache2-foreground"]
