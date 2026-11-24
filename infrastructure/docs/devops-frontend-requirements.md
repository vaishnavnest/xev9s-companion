# DevOps Requirements: Frontend (XEV 9S Companion App)

This document specifies the infrastructure, runtime environments, build dependencies, CI/CD pipeline steps, and environment configuration required by DevOps/SRE to build, test, and release the Flutter frontend (`frontend/xev9s_app`) for **Android** and **Web**.

---

## 1. Runtime & Tooling Specifications

| Tool | Required Version | Purpose |
|------|------------------|---------|
| **Flutter SDK** | `3.50.0` (stable channel) | Core framework for Web and Android builds |
| **Dart SDK** | `3.14.0` (bundled with Flutter) | Language runtime and analyzer |
| **JDK (Java Development Kit)** | `OpenJDK 17` or `OpenJDK 21` | Required for Gradle Android builds |
| **Android SDK** | Compile SDK `34` or `35`, Min SDK `24` | Android OS targets |
| **Android Build Tools** | `34.0.0`+ | AAPT2, D8/R8 byte-code shrinker |
| **Node.js & npm** | `Node.js 20.x LTS` (npm 10+) | For Prism mock server (`@stoplight/prism-cli`) & OpenAPI linting (`@redocly/cli`) |
| **Docker** | `24.x`+ | For containerized web deployments (e.g., Nginx static serving) |

---

## 2. Compile-Time Configuration (`--dart-define`)

The Flutter app **strictly forbids hardcoded backend URLs**. Configuration values must be injected at build time using `--dart-define`:

| Variable Name | Description | Example Values |
|---------------|-------------|----------------|
| `API_BASE_URL` | Base URL for REST API calls | • Local Mock: `http://localhost:4010`<br>• Android Emulator (Local): `http://10.0.2.2:4010`<br>• Dev Cluster: `https://api.dev.xev9s.com/api/v1`<br>• Staging: `https://api.staging.xev9s.com/api/v1`<br>• Production: `https://api.xev9s.com/api/v1` |
| `WS_BASE_URL` | Base URL for WebSocket connections | • Local Mock: `ws://localhost:4010`<br>• Dev Cluster: `wss://api.dev.xev9s.com/ws`<br>• Production: `wss://api.xev9s.com/ws` |

> **Note on Prefixing:**
> - Prism Mock server serves routes at root (`/vehicles`, `/auth/login`).
> - Real backend environments mount endpoints with `/api/v1` prefix (`/api/v1/vehicles`).
> The `API_BASE_URL` variable must include `/api/v1` when targeting real backend servers.

---

## 3. Build & CI Pipeline Commands

All commands execute from `frontend/xev9s_app`:

### 3.1 Dependency Resolution & Verification
```bash
# Fetch pub dependencies
flutter pub get

# Static code analysis
flutter analyze

# Run unit and widget test suite with code coverage
flutter test --coverage
```
*Quality Gate Criteria:* `flutter analyze` must produce 0 errors/warnings. Test suite must pass with 100% success.

### 3.2 Web Build (Output: `build/web/`)
```bash
flutter build web \
  --release \
  --dart-define=API_BASE_URL=https://api.dev.xev9s.com/api/v1 \
  --dart-define=WS_BASE_URL=wss://api.dev.xev9s.com/ws
```

### 3.3 Android APK Build (Output: `build/app/outputs/flutter-apk/app-release.apk`)
```bash
flutter build apk \
  --release \
  --dart-define=API_BASE_URL=https://api.dev.xev9s.com/api/v1 \
  --dart-define=WS_BASE_URL=wss://api.dev.xev9s.com/ws
```

### 3.4 Android App Bundle (AAB - for Google Play / Internal App Sharing)
```bash
flutter build appbundle \
  --release \
  --dart-define=API_BASE_URL=https://api.xev9s.com/api/v1 \
  --dart-define=WS_BASE_URL=wss://api.xev9s.com/ws
```

---

## 4. Web Deployment (Container / Nginx)

For serving the Flutter Web build via Kubernetes or Docker:

### Recommended Dockerfile for Web
```dockerfile
# Stage 1: Build Web App
FROM ghcr.io/cirruslabs/flutter:3.50.0 AS build
WORKDIR /app
COPY frontend/xev9s_app/ .
RUN flutter pub get
ARG API_BASE_URL=https://api.dev.xev9s.com/api/v1
ARG WS_BASE_URL=wss://api.dev.xev9s.com/ws
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL} --dart-define=WS_BASE_URL=${WS_BASE_URL}

# Stage 2: Serve with Nginx
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY <<EOF /etc/nginx/conf.d/default.conf
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
}
EOF
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

---

## 5. Android Signing & Keystore Secrets

For release builds on CI/CD, the following secrets must be supplied via CI environment variables:

| Secret Key | Purpose |
|------------|---------|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded release `.jks` / `.keystore` file |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias name |
| `ANDROID_KEY_PASSWORD` | Key password |

---

## 6. Pipeline Caching Recommendations

To optimize CI build execution time (reduce from ~10m to <3m):
- Cache directory `~/.pub-cache` (keyed by `pubspec.lock`).
- Cache directory `~/.gradle/caches` and `~/.gradle/wrapper` for Android builds.
