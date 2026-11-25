# xev9s_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Trips (UC-06)

- **Status:** Implemented (`TripsPage` at `/trips`, `TripDetailPage` at `/trips/:tripId`, `tripsProvider`, `tripDetailProvider`, `tripRouteForMapProvider`, and `ApiTripRepository`).
- **Constants** (`lib/core/constants/app_constants.dart`):
  - `tripsPageSize = 20`
  - `routeMaxRenderPoints = 500`
  - `ongoingTripRefreshSeconds = 15`
  - `tripDatePresets = ['today', 'last_7_days', 'last_30_days']`
- **Privacy Note:** Trip GPS routes are personal location data. They are kept in memory only, never persisted or cached to disk, and coordinates/request bodies are never logged.

## Dev Mock Gateway & Driving Simulation

Because Prism (`4010`) only serves static YAML examples, a local Node dev gateway (`scripts/mock-gateway.js` on port `4012`) is provided for UC-06 Trips:
- **Fixtures:** 25 completed trips across multiple days, 1 ongoing trip (`trp_ongoing_01`), 1 trip with an empty route (`trp_empty_route`), and 1 trip with null energy and null end location (`trp_null_fields`). Supports `page`, `pageSize` / `page_size`, `status`, `from`, and `to`.
- **Proxying:** All non-trip requests are forwarded to Prism on `localhost:4010` with CORS enabled.
- **Run with:**
  ```powershell
  node scripts/mock-gateway.js
  flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4012 --dart-define=WS_BASE_URL=ws://localhost:4011/ws
  ```
- **WS Driving Simulation (`scripts/mock-ws-server.js`):** Press `d` in the mock WS terminal to emit `vehicle.status` `DRIVING`, followed automatically by `PARKED` after 20 seconds to trigger the trips list auto-refresh.
