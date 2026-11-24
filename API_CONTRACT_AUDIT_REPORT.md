# Comprehensive API & JSON Contract Audit Report
**Project:** XEV 9S Connected Vehicle Companion Platform  
**Scope:** Frontend (`frontend/xev9s_app`), Backend (`backend/app`), Simulator (`simulator`), and API Specification (`docs/openapi.yaml`)  
**Date:** November 2026  
**Status:** Audit Completed (No existing files modified)

---

## 1. Executive Summary

A comprehensive architectural and schema audit was performed across the **FastAPI Backend**, the **Flutter Frontend**, the **Vehicle Simulator**, and the **OpenAPI 3.0.3 Specification (`openapi.yaml`)**.

### Primary Findings
1. **Frontend and OpenAPI are Closely Aligned**: The Flutter app was implemented strictly against the `openapi.yaml` specification (using camelCase, standardized envelopes, strongly typed enums, and dedicated modular REST endpoints).
2. **Backend Suffers from Severe Architectural Divergence**: The current FastAPI backend implementation was developed with an ad-hoc schema differing significantly from both `openapi.yaml` and the Flutter client:
   - **Zero Envelope Support**: The frontend expects every response inside `{ success, data, meta, error }`. The backend returns bare JSON objects, causing **all** frontend API requests to throw `AppError.malformedResponse`.
   - **Case Convention Clashes**: Frontend and OpenAPI use `camelCase` keys and `UPPER_SNAKE_CASE` enums. The backend uses `snake_case` keys and lowercase string enums across models.
   - **Route & HTTP Method Mismatches**: Key endpoints differ in URL paths, path parameters, and HTTP methods (e.g., `/auth/me` vs `/users/me`, `/vehicles/associate` vs `/vehicles`, `/vehicles/{id}/telemetry/latest` vs `/vehicles/{id}/status`).
   - **Missing Subsystems**: Backend lacks endpoints for Remote Commands, Charging management, User Profile editing, Vehicle Location, Trips, Analytics, and Notifications.
   - **WebSocket Protocol Incompatibility**: Frontend connects to `/ws?token=...&vehicleId=...` expecting event envelopes (`{ event: "vehicle.status", ... }`). Backend serves `/ws/vehicles/{vehicle_id}`, expects auth in the first socket message, and broadcasts raw snake_case telemetry payloads.
   - **MQTT Simulator Topic Divergence**: Simulator and Backend use `xev9s/vehicles/{id}/telemetry` rather than `openapi.yaml`'s contracted `vehicle/{id}/telemetry`.

---

## 2. Global Architectural & Protocol Incompatibilities

| Architectural Dimension | OpenAPI 3.0.3 Contract (`openapi.yaml`) | Flutter Client (`xev9s_app`) | FastAPI Backend (`backend/app`) | Runtime Impact |
| :--- | :--- | :--- | :--- | :--- |
| **Response Envelope** | Required: `{ success: bool, data: T?, meta: Meta?, error: ApiError? }` | Enforced in `ApiClient._send`. Throws if `data['success'] != true`. | None. Handlers return bare dictionaries/models (`UserResponse`, `TokenResponse`, etc.). | **Critical Blocking**: 100% of REST requests fail in frontend with `AppError.malformedResponse`. |
| **Error Format** | `{ success: false, data: null, error: { code, message, details, retryable } }` | Parsed via `AppError.fromApiResponseError(errorJson)`. | Standard FastAPI error: `{"detail": "Error message"}`. | Frontend cannot parse structured error codes or form field validation errors. |
| **JSON Field Casing** | `camelCase` (e.g. `accessToken`, `vehicleId`, `batteryPercent`) | `camelCase` throughout all domain models and JSON converters. | `snake_case` (e.g. `access_token`, `vehicle_id`, `battery_percentage`). | `FormatException` on required fields during JSON deserialization. |
| **Enum Casing** | `UPPER_SNAKE_CASE` (e.g. `PARKED`, `DRIVING`, `LOCKED`, `ACTIVE`) | `UPPER_SNAKE_CASE` string values parsed into Dart enums. | Lowercase strings (e.g. `"parked"`, `"driving"`, booleans `is_locked`). | Enums deserialize to `.unknown` or throw format exceptions. |
| **Base URL Prefix** | `/api/v1` (e.g., `http://localhost:8080/api/v1`) | `AppConfig.apiBaseUrl` expects full path prefix or mock root. | No prefix mounted on FastAPI app (`/auth`, `/vehicles`, `/ws`). | Requests route to `404 Not Found` if frontend targets `/api/v1`. |
| **WebSocket Path & Auth** | `GET /ws` with query params `?token=...&vehicleId=...` | Connects to `ws://.../ws?token=...&vehicleId=...` | `WS /ws/vehicles/{vehicle_id}`. Receives JSON `{"token": "..."}` as first frame. | Frontend handshake fails (404 Not Found or immediate socket closure code 1008). |
| **WebSocket Framing** | `{ event, vehicleId, timestamp, data }` | Listens for `RealtimeEvent` with `event` string. | Sends bare `TelemetryResponse` without `event` key. | All WebSocket events discarded as `RealtimeEventType.unknown`. |
| **MQTT Telemetry Topic** | `vehicle/{vehicleId}/telemetry` | N/A (Client uses WebSocket) | `xev9s/vehicles/+/telemetry` (subscribed) / simulator publishes to `xev9s/vehicles/...` | Diverges from OpenAPI specification topic contract. |

---

## 3. Endpoint-by-Endpoint Detailed Comparison

### 3.1. Authentication & Profile

#### 1. User Registration (`POST /auth/register`)
- **OpenAPI (`RegisterRequest` -> `AuthResponse`):**
  - Request Body: `{ name: string, email: string, password: string }`
  - Response: `{ success: true, data: { accessToken, refreshToken, tokenType, expiresIn, user: { userId, name, email } } }`
- **Frontend (`ApiAuthRepository.register`):**
  - Sends: `{ "name": name, "email": email, "password": password }`
  - Expects: `AuthSession` with `accessToken`, `refreshToken`, `expiresIn`, `user` inside `data`.
- **Backend (`register_user` in `routes/auth.py`):**
  - Expects `UserCreate`: `{ full_name: string, email: string, password: string, confirm_password: string }`
  - Returns `UserResponse`: `{ id: string, email: string, full_name: string, is_active: bool, created_at: datetime }`
- **Conflicts & Errors:**
  1. **Field Name Mismatch**: Frontend sends `name`, Backend requires `full_name`.
  2. **Missing Field in Request**: Backend validation fails with `422 Unprocessable Entity` because `confirm_password` is required by backend but omitted by frontend & OpenAPI.
  3. **Response Semantic Mismatch**: Backend returns the created user entity (`UserResponse`) without tokens. OpenAPI and Frontend expect immediate authentication tokens (`AuthTokens`) and automatic session login on registration.
  4. **Missing Envelope**: Backend response lacks `{ success, data, meta, error }`.

---

#### 2. User Login (`POST /auth/login`)
- **OpenAPI (`LoginRequest` -> `AuthResponse`):**
  - Request Body: `{ identifier: string, password: string }`
  - Response: `{ success: true, data: { accessToken, refreshToken, tokenType: "Bearer", expiresIn: int, user: { userId, name, email } } }`
- **Frontend (`ApiAuthRepository.login`):**
  - Sends: `{ "identifier": identifier, "password": password }`
  - Expects: `AuthSession` from `data`.
- **Backend (`login_user` in `routes/auth.py`):**
  - Expects `UserLogin`: `{ email: string, password: string }`
  - Returns `TokenResponse`: `{ access_token: string, refresh_token: string, token_type: "bearer", expires_in: int }`
- **Conflicts & Errors:**
  1. **Request Field Mismatch**: Frontend sends `identifier` (supports email/username). Backend requires `email`. Backend fails with `422 Unprocessable Entity`.
  2. **Missing User in Response**: Frontend `AuthSession.fromJson` strictly requires `json['user']` (`userId`, `name`, `email`). Backend `TokenResponse` does not include `user`. Deserialization throws `FormatException: Missing or invalid required field: user`.
  3. **Snake_case vs CamelCase in Tokens**: Backend sends `access_token`, `refresh_token`, `expires_in`. Frontend requires `accessToken`, `refreshToken`, `expiresIn`.
  4. **Missing Envelope**: Backend response lacks `{ success, data, meta, error }`.

---

#### 3. Refresh Token (`POST /auth/refresh`)
- **OpenAPI (`RefreshRequest` -> `AuthResponse`):**
  - Request Body: `{ refreshToken: string }`
  - Response: `AuthResponse` (`accessToken`, `refreshToken`, `expiresIn`, `user`)
- **Frontend (`AuthInterceptor` / `Dio`):**
  - Sends: `{ "refreshToken": "..." }`
- **Backend (`refresh_access_token` in `routes/auth.py`):**
  - Expects `RefreshTokenRequest`: `{ refresh_token: string }`
  - Returns `TokenResponse`: `{ access_token, refresh_token, token_type, expires_in }`
- **Conflicts & Errors:**
  1. **Request Key Name Mismatch**: Frontend sends `refreshToken` (camelCase). Backend requires `refresh_token` (snake_case). Returns `422 Unprocessable Entity`.
  2. **Response Field Casing**: Backend returns snake_case tokens without `user`.
  3. **Missing Envelope**: Backend response lacks `{ success, data, meta, error }`.

---

#### 4. User Logout (`POST /auth/logout`)
- **OpenAPI (`LogoutRequest` -> `EmptyResponse`):**
  - Request Body: Optional `{ refreshToken?: string }`
  - Response: `{ success: true, data: null, meta: ... }`
- **Frontend (`ApiAuthRepository.logout`):**
  - Sends: `{ "refreshToken": "..." }`
- **Backend (`logout_user` in `routes/auth.py`):**
  - Expects `RefreshTokenRequest`: Mandatory `{ refresh_token: string }`
  - Returns: `{"message": "Logged out successfully"}`
- **Conflicts & Errors:**
  1. **Request Key Name Mismatch**: Frontend sends `refreshToken`. Backend expects `refresh_token`.
  2. **Mandatory vs Optional**: OpenAPI marks body optional; backend marks `RefreshTokenRequest` body mandatory.
  3. **Missing Envelope**: Returns `{"message": ...}` instead of `{ success: true, data: null }`.

---

#### 5. Current User Profile (`GET /users/me`)
- **OpenAPI:** Path: `GET /users/me`. Response: `ProfileResponse` wrapping `UserProfile` (`userId`, `name`, `email`, `createdAt`, `vehicles`).
- **Frontend (`ApiAuthRepository.currentUser`):**
  - Calls: `GET /users/me`.
  - Expects: `UserSummary` (`userId`, `name`, `email`) in `data`.
- **Backend (`routes/auth.py`):**
  - Path: `GET /auth/me` (**Wrong URL path**).
  - Returns `UserResponse`: `{ id: string, email: string, full_name: string, is_active: bool, created_at: datetime }`
- **Conflicts & Errors:**
  1. **Path Not Found**: Frontend calls `/users/me`. Backend has `/auth/me`. HTTP `404 Not Found`.
  2. **ID Field Name Mismatch**: Backend returns `id`. Frontend & OpenAPI expect `userId`.
  3. **Name Field Name Mismatch**: Backend returns `full_name`. Frontend & OpenAPI expect `name`.
  4. **Missing Profile Management**: Backend completely lacks `PATCH /users/me`, `GET /users/me/preferences`, and `PUT /users/me/preferences`.

---

### 3.2. Vehicles Subsystem

#### 1. Vehicle List (`GET /vehicles`)
- **OpenAPI:** `GET /vehicles` -> `VehicleListResponse` where `data` is `VehicleSummary[]`:
  - Each item: `{ vehicleId, name, model, identifier, associationStatus, connectivity }`
- **Frontend (`ApiVehicleRepository.listVehicles`):**
  - Expects: `data` to be a `List<dynamic>` of items matching `VehicleSummary.fromJson`.
- **Backend (`get_my_vehicles` in `routes/vehicles.py`):**
  - Returns `VehicleListResponse`: `{ "vehicles": [VehicleResponse] }`
  - Each `VehicleResponse`: `{ vehicle_id, model, association_status, associated_at }`
- **Conflicts & Errors:**
  1. **Data Structure Mismatch**: Backend nests vehicles under `{"vehicles": [...]}` without the API envelope. Frontend expects `data` to be the List directly. In `ApiClient._send`, `data['success']` is missing, and in repository, parsing fails with `FormatException: Expected JSON list for VehicleList`.
  2. **Missing Required Fields**:
     - Frontend `VehicleSummary.fromJson` requires `name` (null check throws `Missing required field: name`).
     - Requires `identifier` (VIN-like string). Backend model has no `identifier` property.
     - Requires `associationStatus` in camelCase. Backend returns `association_status`.
     - Key `vehicle_id` vs `vehicleId`.

---

#### 2. Vehicle Association (`POST /vehicles` vs `POST /vehicles/associate`)
- **OpenAPI:**
  - Path: `POST /vehicles`
  - Request: `AssociateVehicleRequest`: `{ vehicleIdentifier: string, pairingCode: string, name?: string }`
  - Response: `VehicleListResponse` (updated array of `VehicleSummary`)
- **Frontend (`ApiVehicleRepository.associateVehicle`):**
  - Path: `POST /vehicles`
  - Body: `{ "vehicleIdentifier": ..., "pairingCode": ..., "name": ... }`
- **Backend (`associate_vehicle` in `routes/vehicles.py`):**
  - Path: `POST /vehicles/associate` (**Path divergence**)
  - Body `VehicleAssociationRequest`: `{ vehicle_id: string, pairing_code: string }`
  - Status code: `201 Created`
  - Response: `{"vehicles": [...]}`
- **Conflicts & Errors:**
  1. **Endpoint Path Mismatch**: Frontend calls `POST /vehicles`. Backend listens at `POST /vehicles/associate`. Calling `POST /vehicles` results in `405 Method Not Allowed`.
  2. **Field Name Mismatch**:
     - `vehicleIdentifier` (Frontend/OpenAPI) vs `vehicle_id` (Backend).
     - `pairingCode` (Frontend/OpenAPI) vs `pairing_code` (Backend).
     - Backend has `model_config = ConfigDict(extra="forbid")`, so passing `name` or `vehicleIdentifier` triggers `422 Unprocessable Entity`.
  3. **Response Envelope & Format**: Returns `{"vehicles": [...]}` without envelope.

---

#### 3. Vehicle Status & Telemetry (`GET /vehicles/{id}/status`)
- **OpenAPI:**
  - Path: `GET /vehicles/{vehicleId}/status`
  - Response: `VehicleStatusResponse` (`data: VehicleStatus`)
  - Schema `VehicleStatus`:
    - `vehicleId: string`
    - `vehicleState: "PARKED" | "DRIVING" | "CHARGING" | "OFFLINE" | "UNKNOWN"`
    - `connectivity: "ONLINE" | "OFFLINE" | "UNKNOWN"`
    - `battery: { percent: float?, level: "NORMAL" | "WARNING" | ... }`
    - `range: { estimatedKm: float? }`
    - `odometerKm: float?`
    - `speedKmh: float?`
    - `lockState: "LOCKED" | "UNLOCKED" | "UNKNOWN"`
    - `preconditioningState: "ACTIVE" | "INACTIVE" | "UNKNOWN"`
    - `charging: { state: "NOT_CONNECTED" | "CONNECTED" | "CHARGING" | ..., powerKw: float? }`
    - `lastUpdatedAt: ISO-8601 string`
    - `isStale: bool`
- **Frontend (`ApiVehicleStatusRepository.getStatus`):**
  - Calls: `GET /vehicles/$vehicleId/status`
  - Expects: `VehicleStatus.fromJson` exactly as structured above.
- **Backend (`get_latest_telemetry` in `routes/telemetry.py`):**
  - Path: `GET /vehicles/{vehicle_id}/telemetry/latest` (**Wrong Path**)
  - Returns `TelemetryResponse`:
    - Flat structure with snake_case keys:
    - `vehicle_id`, `timestamp`, `battery_percentage`, `estimated_range_km`, `speed_kph`, `odometer_km`, `latitude`, `longitude`, `operating_state` (lowercase string), `is_locked` (boolean), `charging_status` (lowercase string), `charging_power_kw` (float), `cabin_preconditioning_active` (boolean), `received_at`.
- **Conflicts & Errors:**
  1. **Endpoint Path Mismatch**: Frontend calls `/vehicles/{id}/status`. Backend serves `/vehicles/{id}/telemetry/latest`. Result: `404 Not Found`.
  2. **Flat vs Nested Hierarchy**: Frontend/OpenAPI group fields into nested objects (`battery`, `range`, `charging`). Backend outputs a single flat dictionary.
  3. **Field Naming & Key Conflicts**:
     - `vehicleId` vs `vehicle_id`
     - `lastUpdatedAt` vs `timestamp` / `received_at`
     - `speedKmh` vs `speed_kph`
     - `range.estimatedKm` vs `estimated_range_km`
     - `battery.percent` vs `battery_percentage`
     - `charging.powerKw` vs `charging_power_kw`
  4. **Type & Enum Conflicts**:
     - `lockState`: Enum (`LOCKED`/`UNLOCKED`) vs `is_locked` (boolean `true`/`false`).
     - `preconditioningState`: Enum (`ACTIVE`/`INACTIVE`) vs `cabin_preconditioning_active` (boolean).
     - `vehicleState`: Uppercase enum (`PARKED`, `DRIVING`) vs `operating_state` (lowercase `"parked"`).
     - `connectivity`: Required in frontend (`VehicleStatus.fromJson` throws `Missing required field: connectivity` if missing). Backend has no `connectivity` field in `TelemetryResponse`.
     - `isStale`: Required in OpenAPI and parsed in frontend. Backend omits `isStale`.

---

#### 4. Vehicle Telemetry History (`GET /vehicles/{id}/telemetry`)
- **OpenAPI:**
  - Path: `GET /vehicles/{vehicleId}/telemetry`
  - Query parameters: `from` (ISO-8601), `to` (ISO-8601), `limit` (int), `sort` (string)
  - Response: `TelemetryListResponse` (`data: TelemetryRecord[]`, `meta: Meta`)
- **Backend (`get_telemetry_history` in `routes/telemetry.py`):**
  - Path: `GET /vehicles/{vehicle_id}/telemetry/history`
  - Query parameters: `start_time`, `end_time`, `limit`
  - Response: `{"telemetry": [...], "count": int}`
- **Conflicts & Errors:**
  1. **Path Divergence**: `/telemetry` vs `/telemetry/history`.
  2. **Query Parameter Names**: `from` / `to` vs `start_time` / `end_time`.
  3. **Response Schema**: Bare dictionary `{telemetry, count}` with snake_case records vs `TelemetryListResponse`.

---

### 3.3. Remote Vehicle Commands (UC-05)

- **OpenAPI Endpoints:**
  - `POST /vehicles/{vehicleId}/commands` (Body: `{ commandType: "LOCK" | "UNLOCK" | "START_CLIMATE" | "STOP_CLIMATE" }`, Header: `Idempotency-Key`)
  - `GET /vehicles/{vehicleId}/commands/{commandId}`
  - `GET /vehicles/{vehicleId}/commands` (Query: `page`, `pageSize`, `status`, `commandType`, `from`, `to`, `sort`)
- **Frontend (`ApiCommandRepository`):** Fully implemented, sends `commandType`, parses `Command` (`commandId`, `vehicleId`, `commandType`, `status`, `requestedAt`, `completedAt`, `failureReason`, `resultingState`).
- **Backend Status:** **COMPLETELY UNIMPLEMENTED**.
  - No commands router exists in `backend/app/routes/`.
  - All command actions in frontend fail with `404 Not Found`.

---

### 3.4. Charging Management (UC-04)

- **OpenAPI Endpoints:**
  - `GET /vehicles/{vehicleId}/charging` -> `ChargingOverview` (`state`, `batteryPercent`, `targetPercent`, `powerKw`, `sessionDurationSeconds`, `schedule`, `currentSessionId`)
  - `PUT /vehicles/{vehicleId}/charging/target` (Body: `{ targetPercent: int }`)
  - `PUT /vehicles/{vehicleId}/charging/schedule` (Body: `ChargingSchedule`)
  - `DELETE /vehicles/{vehicleId}/charging/schedule`
  - `GET /vehicles/{vehicleId}/charging/sessions` (Paginated list)
  - `GET /vehicles/{vehicleId}/charging/sessions/{sessionId}`
- **Frontend (`ApiChargingRepository`):** Fully implemented against all OpenAPI endpoints above.
- **Backend Status:** **COMPLETELY UNIMPLEMENTED**.
  - No charging router exists in `backend/app/routes/`.
  - All charging screens and mutations in frontend fail with `404 Not Found`.

---

### 3.5. Location Service (UC-03)

- **OpenAPI:** `GET /vehicles/{vehicleId}/location` -> `VehicleLocationResponse` (`data: VehicleLocation`: `{ vehicleId, latitude, longitude, description, vehicleState, reportedAt, isCurrent }`).
- **Frontend (`ApiLocationRepository`):** Implemented, calls `GET /vehicles/$vehicleId/location`.
- **Backend Status:** **UNIMPLEMENTED AS A STANDALONE ENDPOINT**.
  - Backend only has `latitude` and `longitude` fields embedded inside `TelemetryPayload`. No `/vehicles/{id}/location` endpoint exists.
  - Frontend location page throws `404 Not Found`.

---

### 3.6. WebSocket Realtime Communication

```
OpenAPI Spec Contract:
Client -> GET /ws?token={accessToken}&vehicleId={vehicleId}
Server -> Realtime Stream:
          {
            "event": "vehicle.status" | "vehicle.location" | "charging.updated" | ...,
            "vehicleId": "veh_9S0001",
            "timestamp": "2026-11-16T09:30:00Z",
            "data": { ... }
          }
```

```
Backend Implementation:
Server -> Route: /ws/vehicles/{vehicle_id}
Client must send initial JSON text: {"token": "<accessToken>"}
Server broadcasts on MQTT ingest:
          {
            "vehicle_id": "veh_9S0001",
            "timestamp": "2026-11-16T09:30:00Z",
            "battery_percentage": 64.0,
            "speed_kph": 0.0,
            ...
          }
```

#### Detailed WebSocket Conflicts:
1. **Connection URL & Parameter Handling:**
   - Frontend (`WebSocketRealtimeService`) connects to:
     `$wsBaseUrl/ws?token=<token>&vehicleId=<vehicleId>`
   - Backend router (`websocket_router` in `backend/app/routes/websocket.py`):
     `@router.websocket("/ws/vehicles/{vehicle_id}")`
   - **Result:** Connection to `/ws` is rejected with HTTP `404 Not Found`.
2. **Authentication Flow:**
   - Frontend supplies the token in the initial HTTP query parameters (standard browser WebSocket handshake).
   - Backend accepts the connection first, then blocks awaiting an in-band JSON message: `credentials = await websocket.receive_json()`.
   - Because the frontend does not send an auth frame after connecting, the backend connection times out or sits idle until closed.
3. **Message Serialization & Dispatch:**
   - Frontend `RealtimeEvent.fromJson` expects:
     - `event`: String matching `vehicle.status`, `charging.updated`, etc.
     - `vehicleId`: CamelCase vehicle identifier.
     - `data`: Typed nested object.
   - Backend `notify_websocket_clients` broadcasts `TelemetryResponse` directly:
     - No `event` property.
     - Key is `vehicle_id` (snake_case).
     - Flat telemetry attributes.
   - **Result:** Even if connected, every incoming message in the frontend is parsed as `RealtimeEventType.unknown` with an empty `vehicleId`, causing all UI listeners to ignore the update.

---

### 3.7. Vehicle Simulator & MQTT Broker Ingest

- **OpenAPI Contract:**
  - Topic: `vehicle/{vehicleId}/telemetry` (QoS 1)
  - Schema: `TelemetryIngest` (`batteryPercent`, `rangeKm`, `speedKmh`, `odometerKm`, `location: { latitude, longitude }`, `vehicleState`, `lockState`, `charging`, `preconditioningState`)
- **Backend & Simulator Implementation:**
  - Subscribed Topic: `xev9s/vehicles/+/telemetry`
  - Published Topic: `xev9s/vehicles/{vehicle_id}/telemetry`
  - Payload Schema (`simulator.telemetry.generator.TelemetryPayload` & `backend.app.schemas.telemetry.TelemetryPayload`):
    - `battery_percentage`, `estimated_range_km`, `speed_kph`, `odometer_km`, `latitude`, `longitude`, `operating_state`, `is_locked`, `charging_status`, `charging_power_kw`, `cabin_preconditioning_active`.
- **Conflicts:**
  1. Simulator and Backend communicate properly with each other over `xev9s/vehicles/...`, but violate the topic hierarchy specified in OpenAPI (`vehicle/{vehicleId}/telemetry`).
  2. Ingest payload uses snake_case flat properties rather than OpenAPI's `TelemetryIngest` structure.

---

### 3.8. Operations & Health Checks

| Metric / Check | OpenAPI 3.0.3 Contract | FastAPI Backend | Conflict |
| :--- | :--- | :--- | :--- |
| **Liveness Probe** | `GET /health/live` -> `HealthStatus` | `GET /health` -> `{"status": "healthy"}` | Path mismatch (`/health/live` vs `/health`). Response lacks schema. |
| **Readiness Probe** | `GET /health/ready` -> `HealthStatus` | `GET /health/database` -> `{"database": "connected"}` | Path mismatch (`/health/ready` vs `/health/database`). |
| **Metrics** | `GET /metrics` (Prometheus text) | None (Missing) | Endpoint missing in backend. |

---

## 4. Comprehensive JSON Field Name & Type Conflict Matrix

The following table documents every model, field, and naming conflict between the OpenAPI Specification, the Frontend, and the Backend:

| Entity / Context | Field Name in OpenAPI | Field Name in Frontend | Field Name in Backend | Conflict Description |
| :--- | :--- | :--- | :--- | :--- |
| **Response Envelope** | `success` | `success` | *(None)* | Missing in Backend. Frontend throws `AppError.malformedResponse`. |
| **Response Envelope** | `data` | `data` | *(None)* | Missing in Backend. Raw payload returned at root. |
| **Response Envelope** | `meta` | `meta` | *(None)* | Missing in Backend (`requestId`, `timestamp`, `pagination`). |
| **Response Envelope** | `error` | `error` | *(None)* | Backend returns `{"detail": ...}` on HTTPException. |
| **User Register Req** | `name` | `name` | `full_name` | Key mismatch: `name` vs `full_name`. |
| **User Register Req** | *(None)* | *(None)* | `confirm_password` | Backend requires `confirm_password`; frontend does not send it. |
| **User Login Req** | `identifier` | `identifier` | `email` | Key mismatch: `identifier` vs `email`. |
| **User Summary** | `userId` | `userId` | `id` | Key mismatch: `userId` vs `id`. |
| **User Summary** | `name` | `name` | `full_name` | Key mismatch: `name` vs `full_name`. |
| **Auth Tokens** | `accessToken` | `accessToken` | `access_token` | Casing mismatch: camelCase vs snake_case. |
| **Auth Tokens** | `refreshToken` | `refreshToken` | `refresh_token` | Casing mismatch: camelCase vs snake_case. |
| **Auth Tokens** | `tokenType` | `tokenType` | `token_type` | Casing mismatch: camelCase vs snake_case. |
| **Auth Tokens** | `expiresIn` | `expiresIn` | `expires_in` | Casing mismatch: camelCase vs snake_case. |
| **Auth Tokens** | `user` | `user` | *(None)* | Missing in Backend `TokenResponse`. Frontend crashes on login. |
| **Refresh Req** | `refreshToken` | `refreshToken` | `refresh_token` | Casing mismatch: camelCase vs snake_case. |
| **Logout Req** | `refreshToken` | `refreshToken` | `refresh_token` | Casing mismatch: camelCase vs snake_case. |
| **Vehicle Summary** | `vehicleId` | `vehicleId` | `vehicle_id` | Casing mismatch: `vehicleId` vs `vehicle_id`. |
| **Vehicle Summary** | `name` | `name` | *(None)* | Missing in Backend model. Frontend parser throws format error. |
| **Vehicle Summary** | `identifier` | `identifier` | *(None)* | Missing in Backend model (VIN-like code). |
| **Vehicle Summary** | `associationStatus` | `associationStatus` | `association_status` | Casing mismatch. |
| **Vehicle Summary** | `connectivity` | `connectivity` | *(None)* | Missing in Backend model. |
| **Vehicle Assoc Req** | `vehicleIdentifier` | `vehicleIdentifier` | `vehicle_id` | Key name mismatch: `vehicleIdentifier` vs `vehicle_id`. |
| **Vehicle Assoc Req** | `pairingCode` | `pairingCode` | `pairing_code` | Casing mismatch. |
| **Vehicle Assoc Req** | `name` | `name` | *(Forbidden)* | Backend `extra="forbid"` rejects request if `name` is sent. |
| **Telemetry / Status** | `vehicleState` | `vehicleState` | `operating_state` | Name mismatch (`vehicleState` vs `operating_state`) & Casing (`PARKED` vs `"parked"`). |
| **Telemetry / Status** | `battery.percent` | `battery.percent` | `battery_percentage` | Hierarchy & Name mismatch: nested `battery.percent` vs flat `battery_percentage`. |
| **Telemetry / Status** | `battery.level` | `battery.level` | *(None)* | Backend lacks severity classification (`NORMAL`, `WARNING`). |
| **Telemetry / Status** | `range.estimatedKm` | `range.estimatedKm` | `estimated_range_km` | Hierarchy & Name mismatch: nested `range.estimatedKm` vs flat `estimated_range_km`. |
| **Telemetry / Status** | `speedKmh` | `speedKmh` | `speed_kph` | Unit abbreviation mismatch: `speedKmh` vs `speed_kph`. |
| **Telemetry / Status** | `odometerKm` | `odometerKm` | `odometer_km` | Casing mismatch. |
| **Telemetry / Status** | `lockState` | `lockState` | `is_locked` | Type mismatch: String enum (`LOCKED`/`UNLOCKED`) vs boolean (`true`/`false`). |
| **Telemetry / Status** | `preconditioningState`| `preconditioningState`| `cabin_preconditioning_active` | Type mismatch: String enum (`ACTIVE`/`INACTIVE`) vs boolean (`true`/`false`). |
| **Telemetry / Status** | `charging.state` | `charging.state` | `charging_status` | Hierarchy & Casing mismatch: nested `charging.state` (uppercase) vs flat string. |
| **Telemetry / Status** | `charging.powerKw`| `charging.powerKw`| `charging_power_kw` | Hierarchy & Casing mismatch. |
| **Telemetry / Status** | `lastUpdatedAt` | `lastUpdatedAt` | `timestamp` / `received_at` | Field name mismatch. Frontend throws if `lastUpdatedAt` is absent. |
| **Telemetry / Status** | `isStale` | `isStale` | *(None)* | Missing in Backend. |
| **Location** | `reportedAt` | `reportedAt` | `timestamp` | Field name mismatch. |
| **Location** | `isCurrent` | `isCurrent` | *(None)* | Missing in Backend. |
| **WebSocket Event** | `event` | `event` | *(None)* | Backend omits event identifier. |
| **WebSocket Event** | `vehicleId` | `vehicleId` | `vehicle_id` | Casing mismatch. |
| **WebSocket Event** | `data` | `data` | *(None)* | Backend omits data container. |

---

## 5. Summary of Missing Features in Backend

To achieve feature parity with the OpenAPI Specification and support the Frontend client without errors, the following backend components must be implemented:

1. **API Response Envelope Middleware**:
   - Automatically wraps successful responses in `{ "success": true, "data": ..., "meta": { "requestId": ..., "timestamp": ... }, "error": null }`.
   - Custom exception handler to transform `HTTPException` and validation errors into `{ "success": false, "data": null, "meta": ..., "error": { "code": ..., "message": ..., "details": ..., "retryable": ... } }`.
2. **Profile & Preferences Module**:
   - `GET /users/me` (replacing `/auth/me`).
   - `PATCH /users/me`.
   - `GET /users/me/preferences` & `PUT /users/me/preferences`.
3. **Vehicle Location Endpoint**:
   - `GET /vehicles/{vehicleId}/location`.
4. **Remote Vehicle Commands Module**:
   - `POST /vehicles/{vehicleId}/commands` (with Idempotency-Key support).
   - `GET /vehicles/{vehicleId}/commands`.
   - `GET /vehicles/{vehicleId}/commands/{commandId}`.
5. **Charging Management Module**:
   - `GET /vehicles/{vehicleId}/charging`.
   - `PUT /vehicles/{vehicleId}/charging/target`.
   - `PUT /vehicles/{vehicleId}/charging/schedule`.
   - `DELETE /vehicles/{vehicleId}/charging/schedule`.
   - `GET /vehicles/{vehicleId}/charging/sessions` & session details.
6. **Trips, Analytics, Notifications, Reports Modules**:
   - Endpoints specified in `docs/openapi.yaml` for trip history, driving analytics, in-app notifications, and PDF/CSV report generation.
7. **WebSocket Realtime Refactoring**:
   - Mount at `/ws`.
   - Read token from query parameters (`?token=...&vehicleId=...`).
   - Emit framed `WsEvent` messages with `{ "event": ..., "vehicleId": ..., "timestamp": ..., "data": ... }`.
