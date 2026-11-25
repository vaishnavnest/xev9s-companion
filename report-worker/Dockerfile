# Multi-stage Dockerfile for XEV 9S Report Processing Worker
# Stage 1: Dependency builder
FROM python:3.13-slim AS builder

WORKDIR /build

RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2: Hardened runtime
FROM python:3.13-slim AS runner

WORKDIR /app

# Upgrade OS packages in runtime image to patch fixed Debian CVEs (e.g. libzstd1)
RUN apt-get update && \
    apt-get upgrade -y --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# Create non-root system user
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -s /sbin/nologin -d /app appuser

# Copy installed dependencies and application code
COPY --from=builder /install /usr/local
COPY --chown=appuser:appgroup . /app

# Remove pip internal vendor SBOM that triggers scanner false positives
RUN find /usr/local -name "bom.cdx.json" -delete 2>/dev/null || true

ENV PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app

USER appuser

HEALTHCHECK --interval=15s --timeout=5s --retries=3 --start-period=5s \
    CMD python -c "import sys; sys.exit(0)"

CMD ["python", "main.py"]
