# ==============================================================================
# Stage 1: Build the Flutter Web application
# ==============================================================================
FROM ubuntu:24.04 AS builder

# Install system dependencies required for Flutter
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    xz-utils \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Flutter version must match ci.yml (flutter-version: '3.50.0')
ARG FLUTTER_VERSION=3.50.0
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${PATH}"

# Download and install Flutter SDK
RUN curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz \
    | tar -xJ -C /opt \
    && git config --global --add safe.directory '*' \
    && flutter config --no-analytics \
    && flutter config --enable-web \
    && flutter --version \
    && flutter precache --web

WORKDIR /app

# Copy dependency manifests first for layer caching
# (pubspec.lock is NOT in .dockerignore so this is deterministic)
COPY pubspec.yaml pubspec.lock ./

# Fetch dependencies
RUN flutter pub get

# Copy source code and assets
COPY . .

# Build arguments for API endpoint injection at compile time
ARG API_BASE_URL=http://localhost:8000/api/v1
ARG WS_BASE_URL=ws://localhost:8000/ws

# Compile Flutter web release bundle
# Output is generated in /app/build/web/
RUN flutter build web --release \
    --dart-define=API_BASE_URL=${API_BASE_URL} \
    --dart-define=WS_BASE_URL=${WS_BASE_URL}

# ==============================================================================
# Stage 2: Serve compiled assets via non-root Nginx (Trivy DS-0002 compliant)
# ==============================================================================
# nginxinc/nginx-unprivileged is the official non-root variant of Nginx.
# It runs as uid 101 (nginx) with no root access — satisfies Trivy DS-0002.
# It listens on port 8080 internally (not 80, which requires root).
FROM nginxinc/nginx-unprivileged:1.27-alpine-slim AS runner

# Copy compiled Flutter web assets from builder stage
COPY --from=builder /app/build/web /usr/share/nginx/html

# Copy custom nginx configuration (handles SPA routing + healthcheck endpoint)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Healthcheck for Docker and Kubernetes orchestrators
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/healthz || exit 1

# nginx-unprivileged listens on 8080 (non-privileged port, no root needed)
EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
