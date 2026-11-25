import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/app_map.dart';
import '../../vehicles/selected_vehicle_provider.dart';
import '../application/trip_detail_provider.dart';
import '../domain/trip_detail.dart';
import 'trips_view_model.dart';

/// Trip detail page (/trips/:tripId) displaying route map, markers, and summary (UC-06).
class TripDetailPage extends ConsumerStatefulWidget {
  const TripDetailPage({
    super.key,
    required this.tripId,
  });

  final String tripId;

  @override
  ConsumerState<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends ConsumerState<TripDetailPage> {
  final AppMapController _mapController = AppMapController(autoFollow: false);
  Timer? _elapsedTicker;
  DateTime _now = DateTime.now();
  String? _fittedTripKey;

  @override
  void initState() {
    super.initState();
    _elapsedTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _elapsedTicker?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _navigateBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/trips');
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleId = ref.watch(selectedVehicleProvider);
    final isWide = MediaQuery.of(context).size.width >= 720;

    if (vehicleId == null || vehicleId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Trip Details'),
          leading: IconButton(
            key: const Key('trip_detail_back_button'),
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _navigateBack(context),
          ),
        ),
        body: EmptyState(
          icon: Icons.directions_car_outlined,
          title: 'No vehicle selected',
          message: 'Select a vehicle to view trip details.',
          actionLabel: 'Back to Trips',
          onAction: () => context.go('/trips'),
        ),
      );
    }

    final key = TripDetailKey(vehicleId: vehicleId, tripId: widget.tripId);
    final detailAsync = ref.watch(tripDetailProvider(key));
    final mapRoute = ref.watch(tripRouteForMapProvider(key));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Details'),
        leading: IconButton(
          key: const Key('trip_detail_back_button'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => _navigateBack(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isWide ? 1000 : double.infinity,
          ),
          child: AsyncValueView<TripDetailState>(
            value: detailAsync,
            onRetry: () => ref.read(tripDetailProvider(key).notifier).refresh(),
            data: (state) {
              if (state.isNotFound || state.detail == null) {
                return EmptyState(
                  key: const Key('trip_not_found_state'),
                  icon: Icons.search_off_rounded,
                  title: 'Trip not found',
                  message:
                      'This trip could not be found or is no longer available.',
                  actionLabel: 'Back to Trips',
                  onAction: () => context.go('/trips'),
                );
              }

              final detail = state.detail!;
              return RefreshIndicator(
                onRefresh: () =>
                    ref.read(tripDetailProvider(key).notifier).refresh(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (detail.isOngoing) _buildOngoingBanner(context, detail),
                    _buildMapSection(context, detail, mapRoute),
                    const SizedBox(height: 16),
                    _buildSummaryCard(context, detail),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOngoingBanner(BuildContext context, TripDetail detail) {
    final theme = Theme.of(context);
    final elapsedText =
        TripsViewModel.liveElapsedLabel(detail.elapsedAt(_now));
    return Container(
      key: const Key('trip_ongoing_banner'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.directions_car_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Trip in progress',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 20,
            runSpacing: 6,
            children: [
              Text(
                'So far: $elapsedText',
                key: const Key('trip_ongoing_elapsed'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (detail.distanceKm != null)
                Text(
                  'Distance so far: ${TripsViewModel.distanceLabel(detail.distanceKm)}',
                  style: theme.textTheme.bodyMedium,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection(
    BuildContext context,
    TripDetail detail,
    TripMapRouteData? mapRoute,
  ) {
    final points = mapRoute?.points ?? const [];
    if (points.isEmpty) {
      return Card(
        key: const Key('trip_route_unavailable_card'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.map_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                'Route unavailable',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'No GPS route points were recorded for this trip.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final polyline =
        points.map((p) => LatLng(p.latitude, p.longitude)).toList();

    final markers = <AppMapMarker>[];
    final startPoint = detail.startLocation.hasCoordinates
        ? LatLng(
            detail.startLocation.latitude!,
            detail.startLocation.longitude!,
          )
        : polyline.first;
    markers.add(
      AppMapMarker(
        point: startPoint,
        title: 'Start: ${TripsViewModel.locationLabel(detail.startLocation)}',
        child: Tooltip(
          message:
              'Start: ${TripsViewModel.locationLabel(detail.startLocation)}',
          child: Container(
            key: const Key('trip_start_marker'),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );

    if (detail.isOngoing) {
      markers.add(
        AppMapMarker(
          point: polyline.last,
          isLive: false,
          title: 'Vehicle now',
          child: Tooltip(
            message: 'Vehicle now',
            child: Container(
              key: const Key('trip_ongoing_end_marker'),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.directions_car_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      );
    } else if (detail.endLocation != null &&
        detail.endLocation!.hasCoordinates) {
      markers.add(
        AppMapMarker(
          point: LatLng(
            detail.endLocation!.latitude!,
            detail.endLocation!.longitude!,
          ),
          title: 'End: ${TripsViewModel.locationLabel(detail.endLocation)}',
          child: Tooltip(
            message:
                'End: ${TripsViewModel.locationLabel(detail.endLocation)}',
            child: Container(
              key: const Key('trip_end_marker'),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.flag_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      );
    } else if (polyline.length > 1) {
      markers.add(
        AppMapMarker(
          point: polyline.last,
          title: 'End',
          child: Tooltip(
            message: 'End',
            child: Container(
              key: const Key('trip_end_marker'),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.flag_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      );
    }

    final fitSignature = '${detail.tripId}:${polyline.length}';
    if (_fittedTripKey != fitSignature) {
      _fittedTripKey = fitSignature;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.fitBounds(polyline);
        }
      });
    }

    final bounds = mapRoute?.bounds;
    final initialCenter = bounds != null
        ? LatLng(bounds.centerLat, bounds.centerLng)
        : polyline.first;

    return SizedBox(
      height: 300,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AppMap(
          key: const Key('trip_detail_map'),
          center: initialCenter,
          zoom: 14.0,
          polyline: polyline,
          markers: markers,
          controller: _mapController,
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, TripDetail detail) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('trip_summary_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Trip Summary',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                StatusChip(
                  label: detail.isOngoing ? 'Ongoing' : 'Completed',
                  type: detail.isOngoing
                      ? ChipStatusType.warning
                      : ChipStatusType.success,
                  icon: detail.isOngoing
                      ? Icons.directions_car_rounded
                      : Icons.check_circle_outline_rounded,
                ),
              ],
            ),
            const Divider(height: 24),
            _SummaryRow(
              label: 'Start location',
              value: TripsViewModel.locationLabel(detail.startLocation),
            ),
            _SummaryRow(
              label: 'End location',
              value: detail.endLocation == null
                  ? Formatters.nullPlaceholder
                  : TripsViewModel.locationLabel(detail.endLocation),
            ),
            _SummaryRow(
              label: 'Started',
              value: TripsViewModel.startedAtLabel(detail.startedAt),
            ),
            _SummaryRow(
              label: 'Ended',
              value: TripsViewModel.endedAtLabel(detail),
            ),
            _SummaryRow(
              label: 'Duration',
              value: TripsViewModel.detailDurationLabel(detail),
            ),
            _SummaryRow(
              label: 'Distance',
              value: detail.isOngoing
                  ? Formatters.nullPlaceholder
                  : TripsViewModel.distanceLabel(detail.distanceKm),
            ),
            _SummaryRow(
              label: 'Average speed',
              value: TripsViewModel.averageSpeedLabel(detail.averageSpeedKmh),
            ),
            _SummaryRow(
              label: 'Battery',
              value: TripsViewModel.batteryRangeLabel(detail),
            ),
            _SummaryRow(
              label: 'Energy used',
              value: detail.isOngoing
                  ? Formatters.nullPlaceholder
                  : TripsViewModel.energyLabel(detail.energyConsumedKwh),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
