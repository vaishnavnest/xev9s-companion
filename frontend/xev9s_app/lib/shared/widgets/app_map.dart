import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/config/app_config.dart';

export 'package:latlong2/latlong.dart' show LatLng;

/// Riverpod provider for injecting the map [TileProvider].
/// In production, defaults to [NetworkTileProvider]. In widget tests,
/// can be overridden with a no-network / fake tile provider.
final mapTileProviderProvider = Provider<TileProvider>((ref) {
  return NetworkTileProvider();
});

/// Pure logic controller managing auto-follow state, camera navigation,
/// and zoom levels for [AppMap].
class AppMapController extends ChangeNotifier {
  AppMapController({bool autoFollow = true}) : _isAutoFollow = autoFollow;

  bool _isAutoFollow;

  /// Whether the map automatically centers on position updates.
  /// Stops following once the user manually pans or drags the map.
  bool get isAutoFollow => _isAutoFollow;

  void Function(LatLng? target)? _recenterCallback;
  VoidCallback? _zoomInCallback;
  VoidCallback? _zoomOutCallback;

  /// Invoked when a manual user pan gesture is detected on the map.
  void onUserPan() {
    if (_isAutoFollow) {
      _isAutoFollow = false;
      notifyListeners();
    }
  }

  /// Re-enables auto-follow mode and recenters the camera to [target].
  void recenter([LatLng? target]) {
    _isAutoFollow = true;
    notifyListeners();
    _recenterCallback?.call(target);
  }

  /// Triggers a step zoom in on the map.
  void zoomIn() {
    _zoomInCallback?.call();
  }

  /// Triggers a step zoom out on the map.
  void zoomOut() {
    _zoomOutCallback?.call();
  }

  /// Internal attachment of active map handlers.
  void attach({
    required void Function(LatLng? target) onRecenter,
    required VoidCallback onZoomIn,
    required VoidCallback onZoomOut,
  }) {
    _recenterCallback = onRecenter;
    _zoomInCallback = onZoomIn;
    _zoomOutCallback = onZoomOut;
  }

  /// Detaches active map handlers when unmounted.
  void detach() {
    _recenterCallback = null;
    _zoomInCallback = null;
    _zoomOutCallback = null;
  }
}

/// Description of a marker to place on [AppMap].
class AppMapMarker {
  const AppMapMarker({
    required this.point,
    this.isLive = true,
    this.title,
    this.onTap,
    this.child,
  });

  /// Geographic coordinates of the marker.
  final LatLng point;

  /// Whether this marker represents live/connected telemetry.
  /// When false, rendered using a muted grey style to indicate offline/last-known.
  final bool isLive;

  /// Optional accessibility label or tooltip.
  final String? title;

  /// Optional tap callback.
  final VoidCallback? onTap;

  /// Optional custom marker widget override.
  final Widget? child;
}

/// Reusable map component wrapping [FlutterMap] with OpenStreetMap tiles,
/// camera auto-follow logic, on-screen controls, and accessibility semantics.
class AppMap extends ConsumerStatefulWidget {
  const AppMap({
    super.key,
    required this.center,
    this.zoom = 15.0,
    this.markers = const [],
    this.polyline = const [],
    this.controller,
    this.interactive = true,
  });

  final LatLng center;
  final double zoom;
  final List<AppMapMarker> markers;
  final List<LatLng> polyline;
  final AppMapController? controller;
  final bool interactive;

  @override
  ConsumerState<AppMap> createState() => _AppMapState();
}

class _AppMapState extends ConsumerState<AppMap>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late final AppMapController _effectiveController;
  late final AnimationController _animController;
  bool _internalControllerCreated = false;

  static const double _minZoom = 3.0;
  static const double _maxZoom = 18.0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    if (widget.controller != null) {
      _effectiveController = widget.controller!;
    } else {
      _effectiveController = AppMapController();
      _internalControllerCreated = true;
    }

    _effectiveController.attach(
      onRecenter: (target) => _animateTo(target ?? widget.center),
      onZoomIn: _handleZoomIn,
      onZoomOut: _handleZoomOut,
    );
  }

  @override
  void didUpdateWidget(covariant AppMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.detach();
      if (widget.controller != null) {
        _effectiveController = widget.controller!;
        _internalControllerCreated = false;
      } else {
        _effectiveController = AppMapController();
        _internalControllerCreated = true;
      }
      _effectiveController.attach(
        onRecenter: (target) => _animateTo(target ?? widget.center),
        onZoomIn: _handleZoomIn,
        onZoomOut: _handleZoomOut,
      );
    }

    // Auto-follow position changes when auto-follow is active
    if (widget.center != oldWidget.center && _effectiveController.isAutoFollow) {
      _animateTo(widget.center);
    }
  }

  @override
  void dispose() {
    _effectiveController.detach();
    if (_internalControllerCreated) {
      _effectiveController.dispose();
    }
    _animController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _animateTo(LatLng target, {double? zoom}) {
    if (!mounted) return;
    final currentZoom = _mapController.camera.zoom;
    final targetZoom = (zoom ?? currentZoom).clamp(_minZoom, _maxZoom);

    final latTween = LatLngTween(
      begin: _mapController.camera.center,
      end: target,
    );
    final zoomTween = Tween<double>(begin: currentZoom, end: targetZoom);

    final animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.fastOutSlowIn,
    );

    void listener() {
      _mapController.move(
        latTween.evaluate(animation),
        zoomTween.evaluate(animation),
      );
    }

    _animController.reset();
    _animController.addListener(listener);
    _animController.forward().whenComplete(() {
      _animController.removeListener(listener);
    });
  }

  void _handleZoomIn() {
    final current = _mapController.camera.zoom;
    final next = (current + 1.0).clamp(_minZoom, _maxZoom);
    _animateTo(_mapController.camera.center, zoom: next);
  }

  void _handleZoomOut() {
    final current = _mapController.camera.zoom;
    final next = (current - 1.0).clamp(_minZoom, _maxZoom);
    _animateTo(_mapController.camera.center, zoom: next);
  }

  Widget _buildDefaultMarker(BuildContext context, AppMapMarker marker) {
    if (marker.child != null) return marker.child!;

    final theme = Theme.of(context);
    if (marker.isLive) {
      return Tooltip(
        message: marker.title ?? 'Live vehicle position',
        child: Container(
          key: const ValueKey('live_marker'),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
            border: Border.all(color: Colors.white, width: 2.5),
          ),
          child: const Icon(
            Icons.navigation_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      );
    }

    return Tooltip(
      message: marker.title ?? 'Last known position (offline)',
      child: Container(
        key: const ValueKey('offline_marker'),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.grey.shade600,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.white70, width: 2.5),
        ),
        child: const Icon(
          Icons.location_off_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tileProvider = ref.watch(mapTileProviderProvider);
    final theme = Theme.of(context);

    return Semantics(
      label: 'Map showing vehicle location',
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.center,
              initialZoom: widget.zoom.clamp(_minZoom, _maxZoom),
              minZoom: _minZoom,
              maxZoom: _maxZoom,
              interactionOptions: InteractionOptions(
                flags: widget.interactive
                    ? InteractiveFlag.all
                    : InteractiveFlag.none,
              ),
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) {
                  _effectiveController.onUserPan();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: AppConfig.mapTileUrl,
                userAgentPackageName: AppConfig.mapUserAgentPackageName,
                tileProvider: tileProvider,
              ),
              if (widget.polyline.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: widget.polyline,
                      strokeWidth: 4.0,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              if (widget.markers.isNotEmpty)
                MarkerLayer(
                  markers: widget.markers.map((m) {
                    return Marker(
                      point: m.point,
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: m.onTap,
                        child: _buildDefaultMarker(context, m),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '© OpenStreetMap contributors',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          if (widget.interactive)
            Positioned(
              right: 16,
              top: 16,
              child: ListenableBuilder(
                listenable: _effectiveController,
                builder: (context, _) {
                  final isPanned = !_effectiveController.isAutoFollow;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Re-center button
                      Semantics(
                        label: 'Re-centre map',
                        button: true,
                        child: Tooltip(
                          message: 'Re-centre map',
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Material(
                              shape: const CircleBorder(),
                              elevation: isPanned ? 4 : 2,
                              color: isPanned
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.surface,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _effectiveController
                                    .recenter(widget.center),
                                child: Center(
                                  child: Icon(
                                    Icons.my_location_rounded,
                                    size: 22,
                                    color: isPanned
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Zoom In (+)
                      Semantics(
                        label: 'Zoom in',
                        button: true,
                        child: Tooltip(
                          message: 'Zoom in',
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Material(
                              shape: const CircleBorder(),
                              elevation: 2,
                              color: theme.colorScheme.surface,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _effectiveController.zoomIn,
                                child: Center(
                                  child: Icon(
                                    Icons.add_rounded,
                                    size: 24,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Zoom Out (-)
                      Semantics(
                        label: 'Zoom out',
                        button: true,
                        child: Tooltip(
                          message: 'Zoom out',
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Material(
                              shape: const CircleBorder(),
                              elevation: 2,
                              color: theme.colorScheme.surface,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _effectiveController.zoomOut,
                                child: Center(
                                  child: Icon(
                                    Icons.remove_rounded,
                                    size: 24,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
