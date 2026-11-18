# 📁 Frontend Project Structure — XEV 9S Companion App

```
frontend/
├── requirements.txt                        ← Human-readable dependency reference
├── STRUCTURE.md                            ← This file
└── xev9s_app/
    ├── pubspec.yaml                        ← Dart/Flutter deps config
    ├── pubspec.lock                        ← Locked dependency versions
    ├── analysis_options.yaml               ← Lint rules
    ├── .metadata
    ├── .flutter-plugins-dependencies
    ├── xev9s_app.iml
    ├── README.md
    │
    ├── lib/                                ← Main app source
    │   ├── main.dart                       ← Entry point
    │   │
    │   ├── app/
    │   │   ├── app.dart                    ← MaterialApp root widget
    │   │   ├── app_shell.dart              ← Nav shell / bottom nav scaffold
    │   │   └── router.dart                 ← go_router route definitions
    │   │
    │   ├── core/                           ← App-wide infrastructure
    │   │   ├── config/
    │   │   │   └── app_config.dart         ← --dart-define env vars (API_BASE_URL, WS_BASE_URL, etc.)
    │   │   ├── constants/
    │   │   │   └── app_constants.dart
    │   │   ├── network/
    │   │   │   ├── api_client.dart         ← Dio HTTP client setup
    │   │   │   ├── api_exception.dart      ← Typed API error model
    │   │   │   ├── api_response.dart       ← Generic response wrapper
    │   │   │   ├── auth_interceptor.dart   ← JWT injection + 401 handling
    │   │   │   └── error_codes.dart        ← Known API error code constants
    │   │   ├── realtime/
    │   │   │   ├── realtime_service.dart           ← Abstract realtime interface
    │   │   │   ├── web_socket_realtime_service.dart ← WebSocket (ws://) transport
    │   │   │   ├── polling_realtime_service.dart    ← REST polling transport
    │   │   │   └── realtime_providers.dart          ← Riverpod providers for realtime
    │   │   ├── storage/
    │   │   │   └── token_storage.dart      ← flutter_secure_storage wrapper
    │   │   ├── theme/
    │   │   │   └── app_theme.dart          ← ThemeData (light/dark)
    │   │   └── utils/
    │   │       ├── formatters.dart         ← Date, number, distance formatters
    │   │       └── validators.dart         ← Form input validators
    │   │
    │   ├── features/                       ← Feature-first modules
    │   │   ├── analytics/
    │   │   │   └── presentation/
    │   │   │       └── analytics_page.dart
    │   │   │
    │   │   ├── auth/
    │   │   │   ├── application/
    │   │   │   │   ├── auth_controller.dart  ← Login/logout/register logic
    │   │   │   │   ├── auth_session.dart     ← Session state model
    │   │   │   │   └── user_summary.dart     ← Logged-in user DTO
    │   │   │   ├── data/
    │   │   │   │   └── auth_repository.dart  ← Auth API calls
    │   │   │   └── presentation/
    │   │   │       ├── auth_page.dart        ← Auth gate / redirect logic
    │   │   │       ├── login_page.dart
    │   │   │       ├── register_page.dart
    │   │   │       └── splash_page.dart
    │   │   │
    │   │   ├── charging/
    │   │   │   └── presentation/
    │   │   │       └── charging_page.dart
    │   │   │
    │   │   ├── controls/
    │   │   │   └── presentation/
    │   │   │       └── controls_page.dart    ← Remote lock/unlock/preconditioning
    │   │   │
    │   │   ├── dashboard/
    │   │   │   └── presentation/
    │   │   │       ├── dashboard_page.dart
    │   │   │       └── dashboard_view_model.dart
    │   │   │
    │   │   ├── location/
    │   │   │   └── presentation/
    │   │   │       └── location_page.dart
    │   │   │
    │   │   ├── notifications/
    │   │   │   └── presentation/
    │   │   │       └── notifications_page.dart
    │   │   │
    │   │   ├── profile/
    │   │   │   └── presentation/
    │   │   │       └── profile_page.dart
    │   │   │
    │   │   ├── trips/
    │   │   │   └── presentation/
    │   │   │       └── trips_page.dart
    │   │   │
    │   │   └── vehicles/
    │   │       ├── selected_vehicle_provider.dart  ← Active vehicle Riverpod provider
    │   │       ├── application/
    │   │       │   ├── vehicles_controller.dart        ← Vehicle list management
    │   │       │   └── vehicle_status_provider.dart    ← Central SSoT for live status
    │   │       ├── data/
    │   │       │   ├── vehicle_repository.dart         ← Vehicle REST API calls
    │   │       │   └── vehicle_status_repository.dart  ← Status REST API calls
    │   │       ├── domain/
    │   │       │   ├── association_status.dart   ← Enum: ASSOCIATED / PENDING / etc.
    │   │       │   ├── realtime_event.dart        ← Parsed WS event model
    │   │       │   ├── vehicle_connectivity.dart  ← ONLINE / OFFLINE enum
    │   │       │   ├── vehicle_status.dart        ← Full live-status model
    │   │       │   └── vehicle_summary.dart       ← List-item summary model
    │   │       └── presentation/
    │   │           ├── add_vehicle_page.dart
    │   │           ├── vehicles_page.dart
    │   │           ├── vehicle_card.dart
    │   │           └── vehicle_switcher_sheet.dart
    │   │
    │   └── shared/
    │       └── widgets/                    ← Reusable UI components
    │           ├── async_value_view.dart   ← AsyncValue loading/error/data switcher
    │           ├── confirm_dialog.dart
    │           ├── empty_state.dart
    │           ├── error_view.dart
    │           ├── loading_view.dart
    │           ├── stale_banner.dart       ← "Data may be outdated" banner
    │           └── status_chip.dart        ← Coloured status pill widget
    │
    ├── test/                               ← Unit & widget tests (mirrors lib/)
    │   ├── widget_test.dart
    │   ├── app/
    │   │   └── router_test.dart
    │   ├── core/
    │   │   ├── config/
    │   │   │   └── app_config_test.dart
    │   │   ├── network/
    │   │   │   ├── api_client_test.dart
    │   │   │   ├── api_exception_test.dart
    │   │   │   ├── api_response_test.dart
    │   │   │   ├── auth_interceptor_test.dart
    │   │   │   └── error_codes_test.dart
    │   │   ├── realtime/
    │   │   │   ├── web_socket_realtime_service_test.dart
    │   │   │   ├── polling_realtime_service_test.dart
    │   │   │   └── realtime_providers_test.dart
    │   │   ├── storage/
    │   │   │   └── token_storage_test.dart
    │   │   └── utils/
    │   │       ├── formatters_test.dart
    │   │       └── validators_test.dart
    │   ├── features/
    │   │   ├── auth/
    │   │   │   ├── application/
    │   │   │   │   └── auth_controller_test.dart
    │   │   │   ├── data/
    │   │   │   │   └── auth_repository_test.dart
    │   │   │   ├── domain/
    │   │   │   │   └── auth_models_test.dart
    │   │   │   └── presentation/
    │   │   │       ├── login_page_test.dart
    │   │   │       └── register_page_test.dart
    │   │   ├── dashboard/
    │   │   │   └── presentation/
    │   │   │       ├── dashboard_page_test.dart
    │   │   │       └── dashboard_view_model_test.dart
    │   │   ├── profile/
    │   │   │   └── presentation/
    │   │   │       └── profile_page_test.dart
    │   │   └── vehicles/
    │   │       ├── selected_vehicle_provider_test.dart
    │   │       ├── application/
    │   │       │   ├── vehicles_controller_test.dart
    │   │       │   └── vehicle_status_provider_test.dart
    │   │       ├── data/
    │   │       │   ├── vehicle_repository_test.dart
    │   │       │   └── vehicle_status_repository_test.dart
    │   │       ├── domain/
    │   │       │   ├── realtime_event_test.dart
    │   │       │   ├── vehicle_models_test.dart
    │   │       │   └── vehicle_status_test.dart
    │   │       └── presentation/
    │   │           ├── add_vehicle_page_test.dart
    │   │           ├── vehicles_page_test.dart
    │   │           └── vehicle_switcher_test.dart
    │   └── shared/
    │       └── widgets/
    │           └── widgets_test.dart
    │
    ├── web/                                ← Web target static assets
    │   ├── index.html
    │   ├── manifest.json
    │   ├── favicon.png
    │   └── icons/
    │       ├── Icon-192.png
    │       ├── Icon-512.png
    │       ├── Icon-maskable-192.png
    │       └── Icon-maskable-512.png
    │
    ├── android/                            ← Android target
    │   ├── app/
    │   │   └── src/
    │   │       └── main/
    │   │           ├── kotlin/com/xev9s/xev9s_app/MainActivity.kt
    │   │           └── AndroidManifest.xml
    │   ├── gradle/wrapper/
    │   │   └── gradle-wrapper.properties
    │   ├── build.gradle / settings.gradle.kts
    │   └── gradle.properties
    │
    ├── windows/                            ← Windows desktop target
    │   └── flutter/ephemeral/
    │       └── .plugin_symlinks/
    │
    └── coverage/
        └── lcov.info                       ← Test coverage report (lcov format)
```

---

## Architecture Notes

### Pattern: Feature-First + Clean Architecture
Each feature under `lib/features/<name>/` follows a 3-layer split:
| Layer | Folder | Responsibility |
|-------|--------|----------------|
| **Presentation** | `presentation/` | Widgets, pages, view-models |
| **Application** | `application/` | Controllers, state providers (Riverpod) |
| **Data / Domain** | `data/` + `domain/` | Repository impl + pure domain models |

### State Management: Riverpod
- `vehicle_status_provider.dart` is the **Single Source of Truth** for all live vehicle data.
- All screens read from `vehicleStatusProvider`; no screen fetches status independently.

### Realtime Transport
Controlled by the `REALTIME_MODE` dart-define at build time:
- `ws` → `WebSocketRealtimeService` (default, port 4011)
- `polling` → `PollingRealtimeService` (REST every N seconds, port 4010)
