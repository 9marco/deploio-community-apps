ARG REDIS_INSIGHT_VERSION=3.8

FROM redis/redisinsight:${REDIS_INSIGHT_VERSION}

COPY --chmod=755 entrypoint.sh /deploio/entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/deploio/entrypoint.sh"]
CMD ["node", "redisinsight/api/dist/src/main"]
