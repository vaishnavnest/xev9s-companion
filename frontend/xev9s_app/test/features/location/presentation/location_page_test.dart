import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/core/network/error_codes.dart';
import 'package:xev9s_app/core/providers.dart';
import 'package:xev9s_app/core/realtime/realtime_providers.dart';
import 'package:xev9s_app/core/realtime/realtime_service.dart';
import 'package:xev9s_app/core/storage/token_storage.dart';
import 'package:xev9s_app/features/location/data/location_repository.dart';
import 'package:xev9s_app/features/location/domain/vehicle_location.dart';
import 'package:xev9s_app/features/location/presentation/location_page.dart';
import 'package:xev9s_app/features/vehicles/data/vehicle_status_repository.dart';
import 'package:xev9s_app/features/vehicles/domain/realtime_event.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';
import 'package:xev9s_app/features/vehicles/selected_vehicle_provider.dart';
import 'package:xev9s_app/shared/widgets/app_map.dart';
import 'package:xev9s_app/shared/widgets/empty_state.dart';
import 'package:xev9s_app/shared/widgets/error_view.dart';
import 'package:xev9s_app/shared/widgets/stale_banner.dart';

// Minimal 1x1 transparent PNG bytes for headless test tile rendering
final Uint8List kTransparentImage = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class FakeTestTileProvider extends TileProvider {
  FakeTestTileProvider({super.headers});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(kTransparentImage);
  }
}

class FakeLocationRepository implements LocationRepository {
  VehicleLocation? locationResult;
  AppError? error;
  int getLocationCalls = 0;
  Completer<VehicleLocation>? completer;

  @override
  Future<VehicleLocation> getLocation(String vehicleId) async {
    getLocationCalls++;
    if (completer != null) {
      return completer!.future;
    }
    if (error != null) throw error!;
    return locationResult!;
  }
}

class FakeRealtimeService implements RealtimeService {
  final eventsController = StreamController<RealtimeEvent>.broadcast();
  final stateController = StreamController<RealtimeConnectionState>.broadcast();
  final resyncController = StreamController<void>.broadcast();

  @override
  Stream<RealtimeEvent> get events => eventsController.stream;

  @override
  Stream<RealtimeConnectionState> get connectionState => stateController.stream;

  @override
  RealtimeConnectionState get currentConnectionState =>
      RealtimeConnectionState.connected;

  @override
  Stream<void> get onResync => resyncController.stream;

  @override
  Future<void> connect({String? vehicleId}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  void dispose() {
    eventsController.close();
    stateController.close();
    resyncController.close();
  }
}

class FakeTokenStorage implements TokenStorage {
  @override
  Future<String?> getAccessToken() async => 'test_token';
  @override
  Future<String?> getRefreshToken() async => 'test_refresh_token';
  @override
  Future<void> saveAccessToken(String token) async {}
  @override
  Future<void> saveRefreshToken(String token) async {}
  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {}
  @override
  Future<void> clearTokens() async {}
}

class FakeVehicleStatusRepository implements VehicleStatusRepository {
  @override
  Future<VehicleStatus> getStatus(String vehicleId) async {
    return VehicleStatus(
      vehicleId: vehicleId,
      connectivity: ConnectivityStatus.online,
      vehicleState: VehicleState.driving,
      isStale: false,
      lastUpdatedAt: DateTime.now(),
    );
  }
}

class FakeSelectedVehicleNotifier extends SelectedVehicleNotifier {
  FakeSelectedVehicleNotifier(this._initialId);
  final String? _initialId;

  @override
  String? build() => _initialId;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLocationRepository fakeRepository;
  late FakeRealtimeService fakeRealtimeService;
  late SharedPreferences prefs;

  final liveLocation = VehicleLocation(
    vehicleId: 'veh_9S0001',
    latitude: 12.9716,
    longitude: 77.5946,
    description: 'MG Road, Bengaluru',
    vehicleState: VehicleState.driving,
    reportedAt: DateTime.now().subtract(const Duration(minutes: 2)),
    isCurrent: true,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({'selected_vehicle_id': 'veh_9S0001'});
    prefs = await SharedPreferences.getInstance();

    fakeRepository = FakeLocationRepository()..locationResult = liveLocation;
    fakeRealtimeService = FakeRealtimeService();
  });

  tearDown(() {
    fakeRealtimeService.dispose();
  });

  Widget buildLocationPage({Size size = const Size(800, 600), String? selectedVehicleId}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
        locationRepositoryProvider.overrideWithValue(fakeRepository),
        vehicleStatusRepositoryProvider.overrideWithValue(FakeVehicleStatusRepository()),
        realtimeServiceProvider.overrideWithValue(fakeRealtimeService),
        mapTileProviderProvider.overrideWithValue(FakeTestTileProvider()),
        if (selectedVehicleId != null)
          selectedVehicleProvider.overrideWith(
            () => FakeSelectedVehicleNotifier(selectedVehicleId),
          ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: const LocationPage(),
        ),
      ),
    );
  }

  group('LocationPage Widget Tests', () {
    testWidgets('shows loading indicator when data is loading', (tester) async {
      fakeRepository.completer = Completer<VehicleLocation>();

      await tester.pumpWidget(buildLocationPage());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      fakeRepository.completer!.complete(liveLocation);
      await tester.pumpAndSettle();
    });

    testWidgets('shows ErrorView with retry button when initial load fails', (tester) async {
      fakeRepository.error = const AppError(
        code: ApiErrorCode.internalError,
        message: 'Server offline',
        retryable: true,
        httpStatus: 500,
      );

      await tester.pumpWidget(buildLocationPage());
      await tester.pumpAndSettle();

      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Tap Retry
      fakeRepository.error = null;
      fakeRepository.locationResult = liveLocation;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorView), findsNothing);
      expect(find.text('Current location'), findsOneWidget);
    });

    testWidgets('shows EmptyState when no vehicle is selected', (tester) async {
      await tester.pumpWidget(buildLocationPage(selectedVehicleId: ''));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Select a vehicle'), findsOneWidget);
    });

    testWidgets('current state (A) shows live marker, header "Current location", description and state chip', (tester) async {
      await tester.pumpWidget(buildLocationPage());
      await tester.pumpAndSettle();

      expect(find.text('Current location'), findsOneWidget);
      expect(find.text('MG Road, Bengaluru'), findsOneWidget);
      expect(find.text('Driving'), findsOneWidget);
      expect(find.byKey(const ValueKey('live_marker')), findsOneWidget);
      expect(find.text('12.97160, 77.59460'), findsOneWidget);
      expect(find.byType(StaleBanner), findsNothing);
    });

    testWidgets('last-known state (B) shows muted marker, offline banner and never uses "current" or "live"', (tester) async {
      final offlineLocation = liveLocation.copyWith(
        isCurrent: false,
        vehicleState: VehicleState.offline,
      );
      fakeRepository.locationResult = offlineLocation;

      await tester.pumpWidget(buildLocationPage());
      await tester.pumpAndSettle();

      expect(find.text('Last known position'), findsOneWidget);
      expect(find.text('Current location'), findsNothing);
      expect(find.byKey(const ValueKey('offline_marker')), findsOneWidget);
      expect(find.byKey(const ValueKey('live_marker')), findsNothing);

      // StaleBanner notice is displayed
      expect(find.byType(StaleBanner), findsOneWidget);
      expect(find.textContaining('Last known position - the vehicle is offline'), findsOneWidget);
    });

    testWidgets('no-coordinates state (C) shows "Location unavailable" and NO marker', (tester) async {
      final noCoords = const VehicleLocation(
        vehicleId: 'veh_9S0001',
        latitude: null,
        longitude: null,
        description: null,
        vehicleState: VehicleState.parked,
        isCurrent: true,
      );
      fakeRepository.locationResult = noCoords;

      await tester.pumpWidget(buildLocationPage());
      await tester.pumpAndSettle();

      expect(find.text('Location unavailable'), findsOneWidget);
      expect(find.text("The vehicle hasn't reported a position yet"), findsOneWidget);
      expect(find.byKey(const ValueKey('live_marker')), findsNothing);
      expect(find.byKey(const ValueKey('offline_marker')), findsNothing);
      expect(find.byType(AppMap), findsNothing);
    });

    testWidgets('null description shows "Address unavailable"', (tester) async {
      final nullDesc = liveLocation.copyWith(description: null);
      fakeRepository.locationResult = nullDesc;

      await tester.pumpWidget(buildLocationPage());
      await tester.pumpAndSettle();

      expect(find.text('Address unavailable'), findsOneWidget);
    });

    testWidgets('live event moves marker without displaying a loading spinner', (tester) async {
      await tester.pumpWidget(buildLocationPage());
      await tester.pumpAndSettle();

      expect(find.text('MG Road, Bengaluru'), findsOneWidget);

      final newTime = DateTime.now().add(const Duration(seconds: 10));
      fakeRealtimeService.eventsController.add(
        RealtimeEvent(
          type: RealtimeEventType.vehicleLocation,
          vehicleId: 'veh_9S0001',
          timestamp: newTime,
          rawData: {
            'vehicleId': 'veh_9S0001',
            'latitude': 12.9735,
            'longitude': 77.5975,
            'description': 'Residency Road, Bengaluru',
            'vehicleState': 'DRIVING',
            'reportedAt': newTime.toIso8601String(),
            'isCurrent': true,
          },
        ),
      );

      await tester.pump();
      // Verify no full-page loading spinner flashed
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('Residency Road, Bengaluru'), findsOneWidget);
    });

    testWidgets('narrow layout (< 720) renders collapsible bottom panel and map', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildLocationPage(size: const Size(400, 800)));
      await tester.pumpAndSettle();

      expect(find.byType(AppMap), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);

      // Collapse panel
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      expect(find.text('Coordinates'), findsNothing);

      // Expand panel
      await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
      await tester.pumpAndSettle();

      expect(find.text('Coordinates'), findsOneWidget);
    });

    testWidgets('wide layout (>= 720) renders side-by-side flex row', (tester) async {
      await tester.pumpWidget(buildLocationPage(size: const Size(900, 700)));
      await tester.pumpAndSettle();

      expect(find.byType(AppMap), findsOneWidget);
      expect(find.text('Coordinates'), findsOneWidget);
      // No collapse icon on wide layout
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
    });

    testWidgets('retained data with background refresh failure shows small error notice', (tester) async {
      await tester.pumpWidget(buildLocationPage());
      await tester.pumpAndSettle();

      expect(find.text('MG Road, Bengaluru'), findsOneWidget);

      fakeRepository.error = const AppError(
        code: ApiErrorCode.serviceUnavailable,
        message: 'Service unavailable',
        httpStatus: 503,
      );

      // Tap refresh in app bar
      await tester.tap(find.byTooltip('Refresh location'));
      await tester.pumpAndSettle();

      // Data is still shown
      expect(find.text('MG Road, Bengaluru'), findsOneWidget);
      // Warning banner is displayed
      expect(find.text("Couldn't refresh location"), findsOneWidget);
    });
  });
}
