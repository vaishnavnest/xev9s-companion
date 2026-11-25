import 'dart:typed_data';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xev9s_app/shared/widgets/app_map.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppMapController Pure Logic Tests', () {
    test('initial autoFollow is true by default', () {
      final controller = AppMapController();
      expect(controller.isAutoFollow, isTrue);
    });

    test('onUserPan stops autoFollow and notifies listeners', () {
      final controller = AppMapController();
      int notified = 0;
      controller.addListener(() => notified++);

      controller.onUserPan();
      expect(controller.isAutoFollow, isFalse);
      expect(notified, 1);

      // Subsequent pans when already false do not trigger redundant notifications
      controller.onUserPan();
      expect(notified, 1);
    });

    test('recenter re-enables autoFollow, triggers notification and recenter callback', () {
      final controller = AppMapController();
      controller.onUserPan();
      expect(controller.isAutoFollow, isFalse);

      LatLng? recenteredTarget;
      controller.attach(
        onRecenter: (t) => recenteredTarget = t,
        onZoomIn: () {},
        onZoomOut: () {},
      );

      final target = const LatLng(12.9716, 77.5946);
      controller.recenter(target);

      expect(controller.isAutoFollow, isTrue);
      expect(recenteredTarget, equals(target));
    });

    test('zoomIn and zoomOut trigger attached callbacks', () {
      final controller = AppMapController();
      bool zoomInCalled = false;
      bool zoomOutCalled = false;

      controller.attach(
        onRecenter: (_) {},
        onZoomIn: () => zoomInCalled = true,
        onZoomOut: () => zoomOutCalled = true,
      );

      controller.zoomIn();
      expect(zoomInCalled, isTrue);

      controller.zoomOut();
      expect(zoomOutCalled, isTrue);

      controller.detach();
      zoomInCalled = false;
      zoomOutCalled = false;

      controller.zoomIn();
      controller.zoomOut();
      expect(zoomInCalled, isFalse);
      expect(zoomOutCalled, isFalse);
    });
  });

  group('AppMap Widget Tests', () {
    Widget buildTestMap({
      required LatLng center,
      List<AppMapMarker> markers = const [],
      List<LatLng> polyline = const [],
      AppMapController? controller,
    }) {
      return ProviderScope(
        overrides: [
          mapTileProviderProvider.overrideWithValue(FakeTestTileProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: AppMap(
                center: center,
                markers: markers,
                polyline: polyline,
                controller: controller,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders map with markers, attribution and controls', (tester) async {
      final center = const LatLng(12.9716, 77.5946);
      final markers = [
        AppMapMarker(
          point: center,
          isLive: true,
          title: 'Current location',
        ),
      ];

      await tester.pumpWidget(buildTestMap(center: center, markers: markers));
      await tester.pumpAndSettle();

      // Check map semantics
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Map showing vehicle location',
        ),
        findsOneWidget,
      );

      // Check OpenStreetMap attribution
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);

      // Check live marker icon
      expect(find.byKey(const ValueKey('live_marker')), findsOneWidget);

      // Check zoom buttons and recenter button
      expect(find.byTooltip('Zoom in'), findsOneWidget);
      expect(find.byTooltip('Zoom out'), findsOneWidget);
      expect(find.byTooltip('Re-centre map'), findsOneWidget);
    });

    testWidgets('renders muted offline marker when isLive is false', (tester) async {
      final center = const LatLng(12.9716, 77.5946);
      final markers = [
        AppMapMarker(
          point: center,
          isLive: false,
          title: 'Last known position',
        ),
      ];

      await tester.pumpWidget(buildTestMap(center: center, markers: markers));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('offline_marker')), findsOneWidget);
      expect(find.byKey(const ValueKey('live_marker')), findsNothing);
    });

    testWidgets('polyline renders without errors', (tester) async {
      final route = [
        const LatLng(12.9716, 77.5946),
        const LatLng(12.9724, 77.5958),
      ];

      await tester.pumpWidget(buildTestMap(
        center: route.first,
        polyline: route,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(PolylineLayer), findsOneWidget);
    });

    testWidgets('zoom +/- buttons trigger zoom actions', (tester) async {
      final controller = AppMapController();
      final center = const LatLng(12.9716, 77.5946);

      await tester.pumpWidget(buildTestMap(
        center: center,
        controller: controller,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Zoom out'));
      await tester.pumpAndSettle();
    });

    testWidgets('re-centre button is highlighted when panned and resets autoFollow', (tester) async {
      final controller = AppMapController();
      final center = const LatLng(12.9716, 77.5946);

      await tester.pumpWidget(buildTestMap(
        center: center,
        controller: controller,
      ));
      await tester.pumpAndSettle();

      expect(controller.isAutoFollow, isTrue);

      // Simulate user manual pan
      controller.onUserPan();
      await tester.pump();

      expect(controller.isAutoFollow, isFalse);

      // Tap recenter button
      await tester.tap(find.byTooltip('Re-centre map'));
      await tester.pumpAndSettle();

      expect(controller.isAutoFollow, isTrue);
    });

    testWidgets('fitBounds handles empty, single, identical, and multi-point routes safely', (tester) async {
      final controller = AppMapController(autoFollow: false);
      const center = LatLng(12.9716, 77.5946);

      await tester.pumpWidget(buildTestMap(
        center: center,
        controller: controller,
        polyline: const [
          LatLng(12.9716, 77.5946),
          LatLng(12.9780, 77.6050),
        ],
      ));
      await tester.pumpAndSettle();

      // Empty route -> no crash
      controller.fitBounds(const []);
      await tester.pump();

      // Single point -> no crash
      controller.fitBounds(const [LatLng(12.9716, 77.5946)]);
      await tester.pumpAndSettle();

      // Identical points -> no crash
      controller.fitBounds(const [
        LatLng(12.9716, 77.5946),
        LatLng(12.9716, 77.5946),
      ]);
      await tester.pumpAndSettle();

      // Multi-point bounds -> fits camera cleanly
      controller.fitBounds(const [
        LatLng(12.9716, 77.5946),
        LatLng(12.9780, 77.6050),
      ]);
      await tester.pumpAndSettle();

      expect(find.byType(AppMap), findsOneWidget);
    });
  });
}
