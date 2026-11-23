import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/config/app_config.dart';
import '../../../core/realtime/realtime_providers.dart';
import '../../../core/realtime/realtime_service.dart';
import '../../../shared/widgets/app_map.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/stale_banner.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../vehicles/selected_vehicle_provider.dart';
import '../application/vehicle_location_provider.dart';
import '../domain/vehicle_location.dart';
import 'location_view_model.dart';

/// Screen displaying the active vehicle's geographic position, status,
/// and reverse-geocoded address (UC-03).
class LocationPage extends ConsumerStatefulWidget {
  const LocationPage({super.key});

  @override
  ConsumerState<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends ConsumerState<LocationPage> {
  Timer? _ticker;
  DateTime _now = DateTime.now();
  bool _isPanelCollapsed = false;
  late final AppMapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = AppMapController();
    // Refresh relative times and display state every 30 seconds
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Widget _buildConnectionIndicator(
    BuildContext context,
    RealtimeConnectionState connectionState,
  ) {
    final theme = Theme.of(context);

    if (AppConfig.realtimeMode == RealtimeMode.polling) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sync_rounded, size: 14, color: Colors.blueGrey),
          const SizedBox(width: 4),
          Text(
            'Polling',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.blueGrey),
          ),
        ],
      );
    }

    switch (connectionState) {
      case RealtimeConnectionState.connected:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Live',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.green.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case RealtimeConnectionState.connecting:
      case RealtimeConnectionState.reconnecting:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.amber.shade700,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Connecting...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.amber.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case RealtimeConnectionState.disconnected:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Offline',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        );
    }
  }

  Widget _buildInfoCard(
    BuildContext context,
    LocationViewModel vm,
    RealtimeConnectionState connectionState, {
    bool isWide = false,
  }) {
    final theme = Theme.of(context);

    return Semantics(
      label: vm.semanticsLabel,
      child: Card(
        elevation: 4,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isWide ? 16 : 20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Title + Status Chip + Collapse button (narrow)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      vm.headerTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (vm.location.isCurrent)
                    _buildConnectionIndicator(context, connectionState),
                  if (!isWide)
                    IconButton(
                      icon: Icon(
                        _isPanelCollapsed
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                      ),
                      tooltip: _isPanelCollapsed ? 'Expand panel' : 'Collapse panel',
                      onPressed: () {
                        setState(() {
                          _isPanelCollapsed = !_isPanelCollapsed;
                        });
                      },
                    ),
                ],
              ),
              if (!_isPanelCollapsed || isWide) ...[
                const SizedBox(height: 12),
                // Address description
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.place_rounded,
                      size: 20,
                      color: vm.location.isCurrent
                          ? theme.colorScheme.primary
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vm.displayAddress,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // State Chip and Relative Time
                Row(
                  children: [
                    StatusChip(
                      label: vm.vehicleStateLabel,
                      type: vm.vehicleStateType,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Tooltip(
                        message: vm.exactReportedTimeTooltip,
                        child: Text(
                          'Reported ${vm.relativeReportedTime}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                // Coordinates
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Coordinates',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        vm.formattedCoordinates,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedVehicleId = ref.watch(selectedVehicleProvider);

    // State E: No selected vehicle
    if (selectedVehicleId == null || selectedVehicleId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Location')),
        body: const Center(
          child: EmptyState(
            icon: Icons.directions_car_outlined,
            title: 'Select a vehicle',
            message: 'Please select or pair a vehicle to view its location.',
          ),
        ),
      );
    }

    final locationAsync = ref.watch(vehicleLocationProvider);
    final refreshError = ref.watch(vehicleLocationRefreshErrorProvider);
    final connectionStateAsync = ref.watch(realtimeConnectionStateProvider);
    final connectionState = connectionStateAsync.asData?.value ??
        RealtimeConnectionState.disconnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh location',
            onPressed: () {
              ref.read(vehicleLocationProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: AsyncValueView<VehicleLocation?>(
        value: locationAsync,
        onRetry: () => ref.read(vehicleLocationProvider.notifier).refresh(),
        data: (location) {
          if (location == null) {
            return const Center(
              child: EmptyState(
                icon: Icons.directions_car_outlined,
                title: 'Select a vehicle',
                message: 'Please select a vehicle to view its location.',
              ),
            );
          }

          // State C: No coordinates (null or out of range)
          // Assumption/Decision: Map is hidden and EmptyState is presented directly.
          if (!location.hasCoordinates) {
            return Center(
              child: EmptyState(
                icon: Icons.location_off_outlined,
                title: 'Location unavailable',
                message: "The vehicle hasn't reported a position yet",
                actionLabel: 'Retry',
                onAction: () {
                  ref.read(vehicleLocationProvider.notifier).refresh();
                },
              ),
            );
          }

          final vm = LocationViewModel(location: location, now: _now);
          final position = LatLng(location.latitude!, location.longitude!);

          final mapWidget = AppMap(
            key: ValueKey('map_${location.vehicleId}'),
            center: position,
            controller: _mapController,
            markers: [
              AppMapMarker(
                point: position,
                isLive: location.isCurrent,
                title: vm.headerTitle,
              ),
            ],
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;

              return Column(
                children: [
                  // State B: Stale / Offline Notice Banner
                  if (!location.isCurrent)
                    StaleBanner(message: vm.offlineNoticeMessage),
                  // State D: Retained data with background refresh failure message
                  if (refreshError != null)
                    Container(
                      width: double.infinity,
                      color: Colors.red.shade100,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 16,
                            color: Colors.red.shade900,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Couldn't refresh location",
                              style: TextStyle(
                                color: Colors.red.shade900,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Main Content Layout
                  Expanded(
                    child: isWide
                        ? Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: mapWidget,
                              ),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 360),
                                child: Container(
                                  padding: const EdgeInsets.all(16.0),
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerLow,
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: _buildInfoCard(
                                      context,
                                      vm,
                                      connectionState,
                                      isWide: true,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Stack(
                            children: [
                              Positioned.fill(child: mapWidget),
                              Positioned(
                                left: 16,
                                right: 16,
                                bottom: 16,
                                child: _buildInfoCard(
                                  context,
                                  vm,
                                  connectionState,
                                  isWide: false,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
