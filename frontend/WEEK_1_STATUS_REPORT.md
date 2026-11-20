# 📱 XEV 9S Companion — Week 1 Frontend Status Report

**Reporting Period:** November 16, 2026 – November 20, 2026  
**Application:** XEV 9S Mobile & Web Companion Application  
**Target Platforms:** Android Mobile (API 26+) & Web (Chrome / Modern Browsers)  
**Technology Stack:** Flutter 3.50.0 / Dart 3.14.0, Riverpod 2.x, GoRouter, Dio, Flutter Secure Storage  
**Overall Status:** 🟢 **On Track / Healthy** (All Week 1 frontend milestones completed, CI pipeline green, line coverage > 70%)

---

## Executive Summary

During Week 1, the core client architecture, foundational user flows, and primary connected-vehicle interface for the **XEV 9S Companion** application were successfully designed, implemented, and verified.

Key achievements for the week:
1. **Established a scalable Clean Architecture** following a Feature-First modular structure with three distinct layers (*Presentation*, *Application*, *Data/Domain*).
2. **Built robust authentication & session management**, including secure token storage, reactive form validations, password visibility controls, and automatic session restoration.
3. **Implemented vehicle pairing & garage management**, with multi-vehicle switching, vehicle status cards, and the `selectedVehicleProvider` Single Source of Truth (SSoT).
4. **Delivered the Live Vehicle Dashboard**, offering real-time telemetry streaming (dual-mode WebSocket and REST Polling), battery State-of-Charge (SoC %) gauges, TPMS tire pressure readouts, quick vehicle controls, and automated stale-data banners.
5. **Integrated automated CI quality gates**, enforcing `flutter analyze` lint checks and a mandatory **70%+ line coverage** threshold with HTML report generation.

---

## Key Metrics at a Glance

| Metric | Status / Value | Notes |
|:---|:---:|:---|
| **Primary Platforms** | **Android & Web** | Responsive layouts optimized for both handheld mobile and desktop web |
| **Line Coverage** | **> 70% (Enforced)** | Monitored in CI via `lcov.info`; builds fail if below 70.0% |
| **Static Analysis** | **0 Warnings / Errors** | Passes strict `analysis_options.yaml` lint rules |
| **State Management** | **Riverpod 2.x** | Centralized SSoT with reactive `AsyncValue` data flows |
| **Realtime Telemetry Modes** | **2 Supported** | WebSocket (`ws://`, port 4011) + Polling (`http://`, port 4010) fallback |
| **Active Screens Built** | **6 Complete Screens** | Splash, Login, Register, Vehicles List, Add Vehicle, Live Dashboard |
| **Stubbed Feature Modules** | **7 Nav Scaffolds** | Charging, Controls, Location, Trips, Analytics, Notifications, Profile |

---

## Architecture & Code Organization

The application is structured under `frontend/xev9s_app/lib/` using a **Feature-First Clean Architecture**:

```
frontend/xev9s_app/lib/
├── app/                  # App initialization, MaterialApp, shell scaffold, and GoRouter
├── core/                 # App-wide infrastructure and utilities
│   ├── config/           # Compile-time environment configuration (AppConfig)
│   ├── constants/        # Application and error code constants
│   ├── network/          # Dio client, AuthInterceptor, ApiException, ApiResponse
│   ├── realtime/         # RealtimeService, WebSocket and Polling transports, Riverpod providers
│   ├── storage/          # FlutterSecureStorage token storage wrapper
│   ├── theme/            # AppTheme (Light & Dark EV themes, colors, typography)
│   └── utils/            # Formatters (distance, battery, relative time) and Validators
├── features/             # Modular feature packages
│   ├── auth/             # Splash, Login, Register, session controller, and repository
│   ├── dashboard/        # Live Dashboard page, metrics cards, view model
│   ├── vehicles/         # Vehicle list, pairing, switcher sheet, vehicle status SSoT
│   ├── charging/         # Charging overview & scheduler (scaffolded)
│   ├── controls/         # Remote door lock/climate controls (scaffolded)
│   ├── location/         # Vehicle map & GPS tracker (scaffolded)
│   ├── analytics/        # Energy & driving analytics (scaffolded)
│   ├── trips/            # Trip log & driving history (scaffolded)
│   ├── notifications/    # Push notifications & alert history (scaffolded)
│   └── profile/          # User profile settings (scaffolded)
└── shared/               # Reusable UI component library
    └── widgets/          # AsyncValueView, EmptyState, StaleBanner, StatusChip, etc.
```

---

## Detailed Features Implemented in Week 1

### 1. Foundation, Networking & Core Services

- **Compile-Time Configuration (`AppConfig`):**  
  Injects environment settings via `--dart-define`, allowing seamless transitions between development mocks, staging, and production:
  - `API_BASE_URL`: REST endpoint base URL (default: `http://localhost:4010` / emulator: `http://10.0.2.2:4010`).
  - `WS_BASE_URL`: WebSocket endpoint (default: `ws://localhost:4011`).
  - `REALTIME_MODE`: Live telemetry transport (`ws` or `polling`).
  - `POLL_INTERVAL_SECONDS`: Polling frequency when running in polling fallback mode.

- **Resilient Network Layer (`Dio`):**
  - **`ApiClient`**: Base HTTP client configured with timeouts, logging, and JSON parsing.
  - **`AuthInterceptor`**: Automatically injects `Authorization: Bearer <token>` into outgoing requests. Handles `401 Unauthorized` responses by clearing local session credentials and navigating to login.
  - **`ApiException` & `ApiErrorCodes`**: Strongly typed exceptions mapping API error payloads directly to user-friendly UI messages.

- **Secure Token Persistence (`TokenStorage`):**  
  Wrapper around `flutter_secure_storage` storing JWT access tokens and opaque refresh tokens with biometric/keystore encryption where available.

- **Theme & Design System (`AppTheme`):**  
  Modern dark/light themes tailored for connected electric vehicles:
  - Custom color palettes: Electric Cyan primary accents, Deep Onyx backgrounds, high-contrast battery indicators (Green, Amber, Red).
  - Consistent elevation, rounded card surfaces (16px), and legible typography hierarchy.

- **Shared Component Library (`shared/widgets/`):**
  - `AsyncValueView`: Standardized widget handling Riverpod `AsyncValue` (loading spinners, error views with retry triggers, and data display).
  - `EmptyState`: Visually clear illustrated placeholders with action buttons for empty vehicle lists or unselected dashboards.
  - `StaleBanner`: Prominent amber banner indicating telemetry data is stale or the vehicle is offline.
  - `StatusChip`: Context-aware colored status badges (`Online`, `Offline`, `Charging`, `Parked`).
  - `ConfirmDialog`: Reusable modal dialog for confirming critical actions.

---

### 2. User Authentication & Session Management

- **Splash Screen (`SplashPage`):**  
  Initial route that reads persisted credentials, validates active session state, and redirects users to `/dashboard` if authenticated or `/login` if unauthenticated.

- **Login Screen (`LoginPage`):**
  - Email and password input fields with live validation.
  - Password visibility toggle icon.
  - Submit button dynamically enabled only when all form inputs are valid.
  - Clear error feedback banners for invalid credentials or network timeouts.

- **Registration Screen (`RegisterPage`):**
  - Full Name, Email, Password, and Password Confirmation fields.
  - Real-time password matching validation and email format checks.
  - Seamless auto-navigation to login upon successful account creation.

- **Auth Controller (`AuthController`):**  
  Riverpod state notifier coordinating login, registration, token storage, and session termination.

---

### 3. Vehicle Management & Switcher

- **Vehicles Overview (`VehiclesPage`):**  
  Lists all vehicles associated with the authenticated account. Displays vehicle nicknames, VINs, connectivity status, and active selection state. Includes pull-to-refresh and empty-state onboarding.

- **Pair Vehicle (`AddVehiclePage`):**  
  Allows owners to pair a new XEV 9S by entering the Vehicle ID (VIN) and the 6-digit numeric pairing code. Validates pairing format before dispatching API requests.

- **Active Vehicle SSoT (`selectedVehicleProvider`):**  
  Application-wide Riverpod provider storing the currently selected vehicle ID. Automatically selects the primary vehicle on initial login and updates all telemetry screens immediately when switched.

- **Vehicle Switcher Sheet (`VehicleSwitcherSheet`):**  
  A bottom modal sheet triggered from the top app bar of any screen, allowing drivers to seamlessly switch active vehicles without leaving their current context.

---

### 4. Live Vehicle Dashboard

The primary screen (`DashboardPage` & `DashboardViewModel`) provides a real-time command center for the vehicle:

```
┌──────────────────────────────────────────────┐
│  Dashboard                     [Switch ⇄]    │
├──────────────────────────────────────────────┤
│  [● Live (WS)]             Updated 12s ago   │
├──────────────────────────────────────────────┤
│               ╭─────────────╮                │
│               │   ⚡ 78%    │                │
│               ╰─────────────╯                │
│                 342 km Range                 │
│             Status: Not Charging             │
├──────────────────────────────────────────────┤
│  [ 🔒 Lock / Unlock ]   [ ❄️ Climate Pre-con ]│
├──────────────────────────────────────────────┤
│  TPMS Pressure:                              │
│  FL: 36 PSI  │  FR: 36 PSI                   │
│  RL: 35 PSI  │  RR: 35 PSI                   │
├──────────────────────────────────────────────┤
│  Odometer: 14,250 km  │  Speed: 0 km/h (P)   │
│  Interior Temp: 22°C  │  Ambient Temp: 19°C  │
└──────────────────────────────────────────────┘
```

#### Key Dashboard Capabilities:
- **Hero State of Charge (SoC %):** Circular progress indicator displaying remaining battery percentage with dynamic color transitions (Green > 30%, Amber 15–30%, Red < 15%).
- **Range & Charging Status:** Real-time estimated driving range (km) and active charging state badge (`Not Connected`, `Connected`, `Charging`, `Paused`, `Completed`).
- **Real-Time Telemetry Streaming:**
  - **Dual Transport Engine:** Implemented via abstract `RealtimeService`:
    - `WebSocketRealtimeService`: Full-duplex WebSocket stream (`REALTIME_MODE=ws`) on port 4011. Authenticates via query parameter token handshake (`/ws?token=...&vehicleId=...`).
    - `PollingRealtimeService`: Automatic fallback REST polling (`REALTIME_MODE=polling`) fetching status at configurable intervals.
  - **Single Source of Truth:** `vehicleStatusProvider` centrally ingests inbound telemetry push events (`vehicle.status`, `charging.updated`, `connectivity.changed`), keeping the dashboard in continuous sync.
- **Freshness & Stale Detection:**
  - Relative time ticker updates every 30 seconds (e.g., "Updated just now", "Updated 2m ago").
  - `StaleBanner` displays automatically if telemetry packets stop arriving or the vehicle reports `OFFLINE`.
- **Vehicle Diagnostics & Telemetry Cards:**
  - **Tire Pressure Monitoring System (TPMS):** Live PSI / bar readouts for all four tires with warning thresholds.
  - **Driving Metrics:** Odometer reading, current speed, and driving gear mode (P, R, N, D).
  - **Climate Telemetry:** Cabin interior temperature compared to ambient outside temperature.
- **Quick Action Triggers:** One-tap action buttons for vehicle door lock/unlock and cabin climate preconditioning.
- **Pull-to-Refresh:** Full page pull-down refreshes telemetry directly from the REST API.

---

## Testing & Quality Assurance

### Automated Testing Coverage
The frontend includes comprehensive unit and widget tests mirroring the `lib/` directory structure under `test/`:

- **Core Tests:** `app_config_test.dart`, `api_client_test.dart`, `api_exception_test.dart`, `auth_interceptor_test.dart`, `token_storage_test.dart`, `formatters_test.dart`, `validators_test.dart`.
- **Realtime Tests:** `web_socket_realtime_service_test.dart`, `polling_realtime_service_test.dart`, `realtime_providers_test.dart`.
- **Auth Tests:** `auth_controller_test.dart`, `auth_repository_test.dart`, `login_page_test.dart`, `register_page_test.dart`.
- **Vehicle Tests:** `selected_vehicle_provider_test.dart`, `vehicles_controller_test.dart`, `vehicle_status_provider_test.dart`, `vehicle_repository_test.dart`, `vehicles_page_test.dart`, `add_vehicle_page_test.dart`, `vehicle_switcher_test.dart`.
- **Dashboard Tests:** `dashboard_page_test.dart`, `dashboard_view_model_test.dart`.
- **Widget Smoke Tests:** `widgets_test.dart` covering all shared components.

### Continuous Integration Quality Gate
Integrated in `.github/workflows/ci.yml`:
- **`flutter analyze`:** Enforces zero analyzer warnings and strict linting.
- **`flutter test --coverage`:** Executes the full test suite and outputs `coverage/lcov.info`.
- **Line Coverage Gate (≥ 70%):** Automated step parses line coverage; PRs failing to meet 70% are automatically blocked.
- **HTML Artifacts:** Generates and uploads full HTML coverage reports for review.

---

## Local Developer Experience & Mocking Toolchain

To allow frontend development and UI testing independently of backend or vehicle simulator readiness:

1. **REST Mock Server (Port 4010):** Prism mock or Python stateful mock (`scripts/mock_server.py`) serving OpenAPI example responses.
2. **WebSocket Mock Server (Port 4011):** Standalone WebSocket server (`scripts/mock-ws-server.js` / `scripts/mock_ws_server.py`) with interactive keyboard controls:
   - Press `o` → Simulate vehicle going offline (triggers stale banner).
   - Press `n` → Simulate vehicle returning online.
   - Press `c` → Toggle active vehicle charging state.
3. **CLI Data Injector (`scripts/inject.py`):** CLI tool to manually push arbitrary telemetry states (e.g., set battery to 15%, doors to unlocked, climate to active) to verify responsive UI reactions.
4. **VS Code Debugging:** Pre-configured `.vscode/launch.json` entries for:
   - `Web (mock)` — Launches Chrome against localhost mock servers.
   - `Android emulator (mock)` — Launches Android emulator routing host traffic via `10.0.2.2`.
5. **Containerized Web App:** Multi-stage `Dockerfile` compiling Flutter Web into an Alpine Nginx image with non-root security compliance (`USER nginx`).

---

## Week 2 Frontend Roadmap & Next Priorities

| Priority | Objective | Description |
|:---:|:---|:---|
| **1** | **Interactive Remote Controls (UC-03)** | Complete `controls_page.dart` with optimistic UI updates, lock confirmation dialogs, and climate target temperature sliders. |
| **2** | **Charging Management Screen (UC-02)** | Complete `charging_page.dart` with interactive charge limit slider (20%–100%), charging timer/schedule picker, and live kW power charging graphs. |
| **3** | **Vehicle Location & Map Tracking (UC-04)** | Complete `location_page.dart` displaying vehicle GPS coordinates, heading, street address lookup, and distance from user device. |
| **4** | **Push Notifications & Event Feed (UC-05)** | Build notifications history list with unread counter badges and alert filters (Critical, Charging, Security). |
| **5** | **Trip History & Analytics (UC-06)** | Build trip logs list with distance, duration, energy efficiency (Wh/km), and route summaries. |

---

*Status: Completed and verified against Week 1 frontend scope.*  
*Branch: `feature/vehicle-dashboard` | Date: November 20, 2026*
