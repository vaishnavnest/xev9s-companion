# Realtime Service & Architecture Notes

This document captures the design, protocol contracts, backend assumptions, and trade-offs for the real-time telemetry service in the XEV 9S Companion app (Android & Web).

---

## 1. WebSocket Endpoint & Handshake

### 1.1 Endpoint URI
- **URL Pattern**: `GET /ws?token={accessToken}&vehicleId={vehicleId}`
- **Scheme**: `ws://` (local development/mock) and `wss://` (production/staging)
- **Base URL**: Injected via `--dart-define=WS_BASE_URL=...` (defaults to `ws://localhost:4011` in local development).

### 1.2 Authentication via Query Parameter
- **Browser Limitation**: The browser-standard JavaScript `WebSocket` API does not permit custom HTTP request headers (such as `Authorization: Bearer <token>`) during the initial HTTP Upgrade handshake. Because XEV 9S Companion targets both Android and Web, authentication is transmitted via the `token` query parameter.
- **Backend Logging Recommendation**: Web servers, ingress proxies, and API gateways (e.g., NGINX, Cloudflare, AWS ALB) must be configured to **redact or sanitize** the `token` parameter from access and request logs to avoid credential leakage.
- **Handshake Rejection & Close Codes**:
  - If the token is invalid or expired at handshake time, the backend should reject the handshake with HTTP `401 Unauthorized` or immediately close the connection with WebSocket close code **`4001`** (or `4401`) and reason phrase `token_expired` or `unauthorized`.
  - The client automatically catches these close codes, invokes token refresh via the authenticated REST client, and reconnects with a fresh token.

---

## 2. Inbound Push Events & Schemas

The backend broadcasts JSON text frames matching the `WsEvent` envelope defined in `docs/openapi.yaml`:

```json
{
  "event": "<event_name>",
  "vehicleId": "<vehicle_id>",
  "timestamp": "2026-11-18T05:00:00.000Z",
  "data": { ... }
}
```

### 2.1 Supported Event Catalog

| Event Name | Payload Schema | Client Behavior |
|------------|----------------|-----------------|
| `vehicle.status` | `VehicleStatus` | Replaces active telemetry state if `lastUpdatedAt` is newer than current state. |
| `vehicle.location` | `VehicleLocation` | Updates active vehicle location in `vehicleLocationProvider` if `reportedAt` is newer. |
| `charging.updated` | `ChargingOverview` | Merges active charging state, power in kW, battery percentage, target percentage, schedule, and current session ID. Synchronizes with `vehicleStatusProvider` via `chargingViewProvider`. |
| `command.updated` | `Command` | Parsed safely; ready for UC-03 Remote Controls feedback. |
| `notification.created` | `Notification` | Parsed safely; ready for Push Alerts. |
| `connectivity.changed` | `ConnectivityStatus` | Updates vehicle connectivity (`ONLINE` / `OFFLINE`), toggles `isStale`, and nulls live-only fields (speed, charging power). |

### 2.2 Vehicle Location Event (`vehicle.location`)

The `vehicle.location` event transmits geospatial coordinates and status updates for the vehicle location tracking feature (UC-03):

```json
{
  "event": "vehicle.location",
  "vehicleId": "veh_9S0001",
  "timestamp": "2026-11-23T04:00:00.000Z",
  "data": {
    "vehicleId": "veh_9S0001",
    "latitude": 12.9716,
    "longitude": 77.5946,
    "description": "MG Road, Bengaluru",
    "vehicleState": "DRIVING",
    "reportedAt": "2026-11-23T04:00:00.000Z",
    "isCurrent": true
  }
}
```

#### Rules & Constraints:
- **Offline / Last-Known Rule (`isCurrent = false`):** When the vehicle is offline, `isCurrent` MUST be `false` (indicating a last-known position). The client marks existing position as not current immediately when `vehicleStatusProvider` transitions to offline, displaying the stale banner and muted marker.
- **Null Coordinates:** If the vehicle has never reported GPS coordinates, `latitude` and `longitude` are `null`. The client renders the neutral `EmptyState` ("Location unavailable") and never defaults null to `(0.0, 0.0)`.
- **Coordinate Validation:** Coordinates are only valid when `latitude` $\in [-90, 90]$ and `longitude` $\in [-180, 180]$. Out-of-range coordinates are rejected safely without crashing.
- **Ordering & Filtering:** Events for mismatched vehicles or with timestamps older than the currently held `reportedAt` are discarded.

### 2.3 Charging Update Event (`charging.updated`)

The `charging.updated` event transmits real-time telemetry updates for the active charging status (UC-04):

```json
{
  "event": "charging.updated",
  "vehicleId": "veh_9S0001",
  "timestamp": "2026-11-23T04:00:00.000Z",
  "data": {
    "state": "CHARGING",
    "batteryPercent": 65.0,
    "targetPercent": 80,
    "powerKw": 11.2,
    "sessionDurationSeconds": 1420,
    "schedule": {
      "enabled": true,
      "startTime": "22:00",
      "endTime": "06:00",
      "daysOfWeek": ["MON", "TUE", "WED", "THU", "FRI"]
    },
    "currentSessionId": "chs_mock_001"
  }
}
```

#### Rules & Constraints:
- **Consistency Rule:** Dashboard (`vehicleStatusProvider`) and Charging screen (`chargingOverviewProvider`) share live telemetry (`state`, `batteryPercent`, `powerKw`) harmonized via `chargingViewProvider` using timestamp-based reconciliation (newer timestamp wins).
- **Session Transition Invalidation:** When a session completes (`COMPLETED`) or gets interrupted (`INTERRUPTED`), or `currentSessionId` changes, `chargingSessionsProvider` is automatically invalidated so session history updates without user intervention.
- **Null Handling:** Null fields are parsed gracefully without throwing exceptions and presented as "-" in the UI.
- **Battery Dynamics Simulation:**
  - When a vehicle is actively driving (`DRIVING`), battery drains continuously (-0.1% per tick).
  - When actively charging (`CHARGING`), battery percentage increments smoothly (+0.2% per tick) and `sessionDurationSeconds` increments until `targetPercent` is reached.
  - Upon reaching `targetPercent`, the server transitions state to `COMPLETED`, stops charging power (`powerKw = 0.0`), and broadcasts both `charging.updated` and `vehicle.status`.
- **Broadcast Cadence:** While charging is active, `charging.updated` broadcasts every 3 seconds (synchronized with `vehicle.status`) to provide responsive real-time feedback.
- **UI Visual Synchronization:**
  - **Dynamic Progress Bar Color Tiers:** The 10-segment capsule progress bar dynamically shifts its color palette based on battery percentage ($\le 20\%$ Red warning, $21-40\%$ Amber caution, $41-75\%$ Turquoise/Teal normal, $> 75\%$ Emerald green optimal).
  - **Organic Power Surge Animation:** Active exclusively when `isCharging: true`, displaying an organic power surge flowing across the active segments with a pulsing charging tip.
  - **State-Aware Status Chip:** The status chip label, background, border, and indicator dot adapt to match the exact charging state (`Charging`, `Charging complete`, `Plugged in - not charging`, `Paused`, `Interrupted`, `Not plugged in`).

### 2.4 Unknown & Forward-Compatible Events
The client's JSON decoder is intentionally tolerant:
- Unknown event types map to `RealtimeEventType.unknown` without throwing an exception or disconnecting the socket.
- Malformed payloads are discarded cleanly and logged to debug output.

---

## 3. Vehicle Scoping & Filtering

- **Server-Side Filtering**: When the client connects with `?vehicleId={vehicleId}`, the backend message broker (e.g., Redis Pub/Sub, RabbitMQ, Kafka) should route only events scoped to that specific vehicle to the client socket.
- **Client-Side Defense in Depth**: Even if the backend emits events for multiple user vehicles on a single multiplexed connection, `VehicleStatusNotifier` verifies `event.vehicleId == currentSelectedVehicleId` and discards mismatched events.
- **Multi-Vehicle Support & Vehicle Switching**:
  - The default authenticated user has multiple associated vehicles:
    - `veh_mock_9s_01` ("My XEV 9S"): AWD Performance model, parked / connected.
    - `veh_mock_9s_02` ("Asha's City Cruiser"): Long Range RWD model, actively fast-charging at 48.5 kW in Koramangala.
  - When the user switches vehicles in the UI, `vehicleStatusProvider` and `realtimeServiceProvider` re-scope the connection to stream the selected vehicle's telemetry.

---

## 4. Heartbeats & Disconnect Handling

- **Ping / Pong Frames**:
  - The backend should transmit standard WebSocket `Ping` control frames every 30 seconds.
  - The client platform automatically replies with `Pong` control frames.
  - If the client detects no network activity within 45 seconds or if the underlying socket drops, the client enters exponential backoff reconnection.
- **Exponential Backoff Reconnect**:
  - Delays follow `1s, 2s, 4s, 8s, 16s, max 30s` with a 0-250ms random jitter to avoid thundering herd reconnection storms on server restarts.
  - State machine transitions: `connected` $\to$ `reconnecting` $\to$ `connected` (or `disconnected` on manual logout/vehicle unselect).
- **Synthetic Resync Signal**:
  - On every successful **reconnection**, the client emits an internal `onResync` signal.
  - Downstream providers (including `vehicleStatusProvider`) immediately initiate a fresh `GET /vehicles/{id}/status` REST call to catch up on any state changes that occurred during the disconnected window.

---

## 5. Architectural Rule: Single Source of Truth

To avoid race conditions and fragmented telemetry across features:
> **All screens read `vehicleStatusProvider`.**
> No screen or widget should ever call `GET /vehicles/{id}/status` directly or subscribe directly to the raw WebSocket stream.
> Both initial REST loads, background polling, and live push frames converge into `vehicleStatusProvider`.

---

## 6. Realtime Mode Trade-offs: WebSocket vs. Polling

The XEV 9S Companion app supports both modes via compile-time flag `--dart-define=REALTIME_MODE=ws|polling`:

| Metric / Dimension | WebSocket Mode (`ws`) | Polling Mode (`polling`) |
|--------------------|----------------------|--------------------------|
| **Latency** | Real-time (< 200 ms push delivery). | Latency bounded by poll interval (default 10s). |
| **Battery Consumption** | Low when idle (single persistent TCP socket with occasional ping/pong). | High if polling interval is short due to frequent radio wakeups (cellular radio state transitions from idle to full power). |
| **Data Usage** | Minimal: small binary framing and push-only payload when telemetry changes. | Moderate to high: repeated HTTP request/response headers transmitted on every tick even if nothing changed. |
| **Server & Gateway Load** | High memory usage for holding millions of concurrent idle connections; requires stateful gateway/load-balancer architecture. | High throughput CPU/request spikes; easily cached with HTTP `ETag` / `If-None-Match` and scales horizontally with stateless servers. |
| **Reliability on Cellular Networks** | Frequent reconnections when vehicle transitions across mobile cell towers, tunnels, and weak coverage areas. | Highly resilient to intermittent dropouts; each request is independent and idempotent. |
| **App Lifecycle Integration** | Kept active while foregrounded; disconnected on backgrounding or screen lock. | Automatically paused via `WidgetsBindingObserver` / `AppLifecycleListener` when app is backgrounded, triggering an immediate resync upon foregrounding. |

### Recommendation for Decision Log (UC-02)
- **Default to WebSocket (`ws`)** for live dashboard telemetry, instant charging status, and command completion events.
- **Fallback to Polling (`polling`)** in corporate networks that block WebSocket upgrades, or as a low-cost backend fallback during server scaling events.
