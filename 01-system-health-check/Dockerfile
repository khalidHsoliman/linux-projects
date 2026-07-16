FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash bc procps hostname && \
    rm -rf /var/lib/apt/lists/*


ENV DISK_THRESHOLD=80 \
    MEM_THRESHOLD=80 \
    LOAD_THRESHOLD=2.0

WORKDIR /app
COPY health_check.sh /app/health_check.sh
RUN chmod +x /app/health_check.sh

ENTRYPOINT ["/app/health_check.sh"]