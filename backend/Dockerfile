# ==============================================================================
# Stage 1: Build & install Python dependencies
# ==============================================================================
FROM python:3.13-slim AS builder

WORKDIR /build

# Install build dependencies for C-extensions (argon2, cffi, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy dependency manifest first for layer caching
COPY requirements.txt .

# Install dependencies into a separate local prefix
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ==============================================================================
# Stage 2: Minimal & secure runtime container
# ==============================================================================
FROM python:3.13-slim AS runner

WORKDIR /app

# Create a non-root system user and group for security (Trivy compliance)
RUN groupadd -r appuser && useradd -r -g appuser -d /app -s /sbin/nologin appuser

# Copy installed packages from builder stage
COPY --from=builder /install /usr/local

# Copy backend application source code into /app/backend to match import hierarchy
COPY . /app/backend

# Change ownership of /app to appuser
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Environment settings:
# - PYTHONDONTWRITEBYTECODE: prevent .pyc clutter
# - PYTHONUNBUFFERED: flush logs immediately to stdout (for Loki / Docker logs)
# - PYTHONPATH: ensures "from backend.app..." imports resolve correctly
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app

# Expose backend REST API port
EXPOSE 8000

# Container healthcheck probing FastAPI /health endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; res = urllib.request.urlopen('http://localhost:8000/health'); exit(0 if res.status == 200 else 1)" || exit 1

# Start the FastAPI application with Uvicorn
CMD ["uvicorn", "backend.app.main:app", "--host", "0.0.0.0", "--port", "8000"]
