FROM debian:bookworm-slim

# Self-hosted Supermemory binary (https://supermemory.ai/docs/self-hosting/overview).
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates tini && \
    curl -fsSL https://supermemory.ai/install | bash && \
    rm -rf /var/lib/apt/lists/*

COPY supermemory/start.sh /app/start.sh
RUN chmod +x /app/start.sh

ENV SUPERMEMORY_DATA_DIR=/data
ENV PORT=6767

ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/app/start.sh"]
