# Open Decisions Log

Cross-stream decision log between the Flutter app and backend teams.

## Decision Table

| # | Decision needed | Options | Proposed default | Owner | Status | Decided value | Date |
|---|----------------|---------|-----------------|-------|--------|---------------|------|
| 1 | Real-time updates transport | WebSocket, long-polling, SSE | WebSocket with REST as fallback | TBD | Proposed | — | — |
| 2 | Charging target allowed range | 10–100%, 20–100%, 50–100% | 20–100% | TBD | Proposed | — | — |
| 3 | Pagination style | page+pageSize, cursor-based, offset+limit | page + pageSize (max 100), per OpenAPI spec | TBD | Proposed | — | — |
| 4 | Token lifetime and refresh | Short-lived access + refresh, long-lived access only | 15 min access token; refresh via POST /auth/refresh | TBD | Proposed | — | — |
| 5 | Backend base URL and port | 8080, 3000, 443 with reverse proxy | http://localhost:8080/api/v1 | TBD | Proposed | — | — |
| 6 | Vehicle pairing code format | 6-digit numeric, 8-char alphanumeric, QR code | 6-digit numeric code | TBD | Proposed | — | — |
| 7 | Default low-battery threshold | 10%, 15%, 20%, 25% | 20% | TBD | Proposed | — | — |

## How a decision gets applied

1. Both sides discuss in this table or the associated PR.
2. Once agreed, change **Status** to `Agreed`, fill **Decided value** and **Date**.
3. In the **same pull request**, update:
   - `docs/openapi.yaml` — descriptions, constraints, and examples.
   - Dart constants or config in the Flutter app (e.g., `AppConfig`, validation rules).
4. The PR description must reference the decision number (e.g., "Implements Decision #2").

## Where the OpenAPI file uses `[assumption]`

These items in `docs/openapi.yaml` are marked `[assumption]` and need backend confirmation:

| Line | Endpoint / Component | Text |
|------|---------------------|------|
| 120 | `POST /auth/refresh` | Exchange a refresh token for a new access token [assumption] |
| 445 | `DELETE /vehicles/{vehicleId}/charging/schedule` | Remove the charging schedule [assumption] |
| 732 | `GET /notifications/unread-count` | Unread notification count [assumption] |
| 751 | `POST /notifications/read-all` | Mark all notifications as read [assumption] |
| 911 | `GET /ws` | WebSocket upgrade for live updates [assumption - transport not specified in source] |
| 1256 | `components/securitySchemes/ServiceKey` | Shared service credential between backend and simulator [assumption] |
| 1261 | `components/securitySchemes/OperatorKey` | Platform-operator credential for scenario control [assumption] |
| 1327 | `components/parameters/IdempotencyKey` | Client-generated unique key to prevent duplicate command submission on retry [assumption] |
| 1865 | `schemas/SetChargingTargetRequest/targetPercent` | Allowed range is an [assumption]; agree final limits across streams |
