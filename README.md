# XEV 9S Companion App

A connected-vehicle companion app for the XEV 9S electric vehicle, built with Flutter for **Android** and **Web**. The app provides real-time vehicle status, charging management, trip history, remote commands, and notifications — all powered by a REST API defined in an OpenAPI 3.0.3 contract.

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Flutter | 3.50.0+ (stable) | Includes Dart 3.14.0 |
| Chrome | Latest | For web development |
| Android Studio | Latest | For Android emulator and SDK |
| Node.js | LTS (20+) | Required for the Prism mock server |

## Getting Started

```bash
# Clone the repository
git clone <repo-url>
cd xev9s-companion

# Install Flutter dependencies
cd frontend/xev9s_app
flutter pub get
```

## Running the Mock Backend

The mock backend uses [Prism](https://stoplight.io/open-source/prism) to serve the OpenAPI contract with example responses.

```powershell
# From the repo root — PowerShell
.\scripts\start-mock.ps1

# Or using bash
./scripts/start-mock.sh

# Or using npx directly
npx @stoplight/prism-cli mock docs/openapi.yaml -p 4010 --cors
```

The mock server starts at **`http://localhost:4010`**.

> **URL prefix:** Prism serves endpoints at the root (e.g., `http://localhost:4010/vehicles`), **not** under `/api/v1`. The real backend will use `http://localhost:8080/api/v1/vehicles`. The `API_BASE_URL` dart-define handles this difference.

## Running the App

Start the mock server first (see above), then in a separate terminal:

```bash
cd frontend/xev9s_app

# Chrome (web)
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4010

# Android emulator (10.0.2.2 maps to the host's localhost)
flutter run -d <emulator-id> --dart-define=API_BASE_URL=http://10.0.2.2:4010

# Real Android device (use your PC's LAN IP)
flutter run -d <device-id> --dart-define=API_BASE_URL=http://192.168.x.x:4010
```

VS Code users: use the pre-configured **"Web (mock)"** or **"Android emulator (mock)"** launch configurations in `.vscode/launch.json`.

## Configuration

| Variable | Purpose | Default |
|----------|---------|---------|
| `API_BASE_URL` | Base URL for all REST API calls | `http://localhost:4010` (mock) |
| `WS_BASE_URL` | Base URL for WebSocket connections | `ws://localhost:4010` |

These are injected at compile time via `--dart-define`. See `lib/core/config/app_config.dart` for details.

When pointing at the real backend, set `API_BASE_URL=http://localhost:8080/api/v1`.

## Testing

```bash
cd frontend/xev9s_app

# Static analysis
flutter analyze

# Run unit tests
flutter test

# Run tests with coverage
flutter test --coverage
```

## Project Structure

```
xev9s-companion/
├── docs/
│   ├── openapi.yaml          # API contract (source of truth)
│   └── open-decisions.md     # Cross-team decision log
├── scripts/
│   ├── start-mock.sh         # Start mock server (bash)
│   └── start-mock.ps1        # Start mock server (PowerShell)
├── frontend/
│   └── xev9s_app/
│       ├── lib/
│       │   ├── core/          # Cross-cutting: config, networking, errors
│       │   │   └── config/    # AppConfig (dart-define based)
│       │   ├── features/      # Feature-first modules (planned)
│       │   ├── shared/        # Shared widgets, utilities (planned)
│       │   └── app/           # App-level setup, routing (planned)
│       ├── test/              # Mirrors lib/ structure
│       └── pubspec.yaml
├── backend/                   # Backend service (separate)
├── simulator/                 # Vehicle simulator (separate)
└── package.json               # npm scripts (mock server)
```

## Branching and Pull Requests

- Feature branches: `feature/<name>` → merge into `dev`
- No direct commits to `main` or `dev`
- Release flow: `dev` → `main` via reviewed PR

## API Contract

- **OpenAPI spec:** [`docs/openapi.yaml`](docs/openapi.yaml)
- **Decision log:** [`docs/open-decisions.md`](docs/open-decisions.md)

**Rule:** Change the YAML first, then update the code. The OpenAPI file is the source of truth for the API contract. Every endpoint, schema, or constraint change must be reflected in `docs/openapi.yaml` before any Dart code is written.

## Known Limitations of the Mock Server

1. **No WebSocket support** — Prism cannot mock the `/ws` WebSocket endpoint. Real-time updates are not available with the mock.
2. **Static example data** — Prism returns the `example` values from the OpenAPI spec. Responses are not stateful (e.g., creating a resource does not persist it).
3. **No authentication** — Prism does not validate Bearer tokens. Any value (including `Bearer test`) is accepted.

## Troubleshooting

### CORS errors on web

Prism is started with the `--cors` flag which adds permissive CORS headers. If you still see CORS errors:
- Ensure the mock is running (`curl http://localhost:4010/vehicles`)
- Check that you are accessing the app via `localhost`, not `127.0.0.1` (or vice versa)

### `10.0.2.2` on Android emulator

The Android emulator maps `10.0.2.2` to the host machine's `localhost`. Use:
```
--dart-define=API_BASE_URL=http://10.0.2.2:4010
```

### "Connection refused" when the mock is not running

Start the mock server before launching the app:
```powershell
.\scripts\start-mock.ps1
```
Verify it is running: `curl http://localhost:4010/vehicles`

---

## Authentication & Vehicles (UC-01)

### Status & Implemented Features
The Authentication and Vehicle management flows (UC-01) are fully implemented, verified with 125 tests, and passing `flutter analyze` with 0 issues:

- **Authentication (`/login`, `/register`, `/splash`):**
  - Sign in with email/username and password.
  - Sign up with full name, email, and password meeting complexity standards (`>= 8` chars, uppercase, lowercase, digit, special character).
  - Clean error mapping to user-friendly messages for invalid credentials, duplicate email, rate limits, and network errors.
  - Automatic session startup check against `GET /users/me`.
  - Silent token refresh with single-flight locking on 401 `TOKEN_EXPIRED`.
  - Safe logout and session expiration banner handling. Passwords cleared from controllers and memory immediately on submit failure.
- **Vehicle Pairing & Switching (`/vehicles`, `/vehicles/add`, App Shell):**
  - List associated vehicles with connectivity status and model tags.
  - Auto-selects active vehicle when exactly one associated vehicle is available.
  - Association flow via VIN / identifier and in-vehicle 6-digit PIN (`AppConstants.pairingCodeLength = 6`).
  - Vehicle switcher bottom sheet / modal accessible across all shell screens.
  - Active vehicle persists across app restarts via `SharedPreferences`.
  - Clean unpairing / association state isolation.

### Session Lifecycle & Auth Flow

```mermaid
stateDiagram-v2
    [*] --> Splash: App Startup
    Splash --> CheckSession: Read TokenStorage
    
    state CheckSession {
        [*] --> NoToken: token is null
        [*] --> HasToken: token exists
        HasToken --> FetchUser: GET /users/me
        FetchUser --> ValidUser: 200 OK
        FetchUser --> TokenExpired: 401 TOKEN_EXPIRED
        TokenExpired --> SilentRefresh: POST /auth/refresh
        SilentRefresh --> ValidUser: Refresh Success
        SilentRefresh --> ExpiredSession: Refresh Fails
        FetchUser --> NetworkError: Timeout / No Connection
    }

    NoToken --> LoginPage: Redirect to /login
    ExpiredSession --> LoginPage: Redirect to /login (Session Expired)
    NetworkError --> Splash: Retry Error View
    
    ValidUser --> VehiclesCheck: User Authenticated
    
    state VehiclesCheck {
        [*] --> InspectList: GET /vehicles
        InspectList --> AutoSelect: 1 associated vehicle
        InspectList --> MultiVehicles: Multiple / None selected
    }
    
    AutoSelect --> Dashboard: Redirect to /home
    MultiVehicles --> VehiclesPage: Redirect to /vehicles
```

### Pairing Rules & Constants
Defined in `lib/core/constants/app_constants.dart`:
- `pairingCodeLength`: Exactly `6` digits. Must contain numeric digits only (`0-9`).
- `minPasswordLength`: `8` characters. Must include at least 1 uppercase, 1 lowercase, 1 number, and 1 special symbol (`!@#$%^&*(),.?":{}|<>`).
- `maxNameLength`: `100` characters.
- Token refresh proactively occurs on 401 `TOKEN_EXPIRED` or when less than `60` seconds remain before token expiry.

### Mock-Server Testing Commands
With Prism running at `http://localhost:4010`:

```bash
# 1. Register a new user
curl -X POST http://localhost:4010/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Aarav Sharma","email":"aarav@example.com","password":"Password123!"}'

# 2. Login
curl -X POST http://localhost:4010/auth/login \
  -H "Content-Type: application/json" \
  -d '{"identifier":"aarav@example.com","password":"Password123!"}'

# 3. Get Current User (Authenticated)
curl -X GET http://localhost:4010/users/me \
  -H "Authorization: Bearer mock-valid-token"

# 4. List Vehicles
curl -X GET http://localhost:4010/vehicles \
  -H "Authorization: Bearer mock-valid-token"

# 5. Pair Vehicle
curl -X POST http://localhost:4010/vehicles \
  -H "Authorization: Bearer mock-valid-token" \
  -H "Content-Type: application/json" \
  -d '{"identifier":"XEV9S-2026-0001","pairingCode":"123456","name":"Primary Vehicle"}'
```

